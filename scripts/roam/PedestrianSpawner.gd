# File: res://scripts/roam/PedestrianSpawner.gd
# Đám đông FreeRoam ba tầng quanh người chơi (hoặc xe khi đang cưỡi), spec vice-people-and-movement Phần 3 +
# "Amendment 2026-10-22":
#   gần (<= 35 m, tối đa 40): Pedestrian đủ vật lý + phản ứng va chạm;
#   giữa (35-90 m): Pedestrian không vật lý (lod_far), hoạt ảnh theo LOD khoảng cách sẵn có của RigAnimator;
#   xa (90-225 m, tối đa 200): người nộm CrowdImpostors (MultiMesh theo biến thể).
# Mục tiêu ban ngày theo khu quanh người chơi (PedWalkGraph.zone_at): campus 60 / dân cư 45 / đường 25 người đi đường
# trong 90 m và 150 / 120 / 60 người nộm; ban đêm (FreeRoam.tod_preset == "night") còn 30 %, cắt ngay khi đổi giờ.
# Người đi đường ra ngoài 95 m thành người nộm, người nộm vào trong 90 m thành người đi đường (khi còn dưới mục tiêu,
# hoặc khi đang trong tầm camera để không ai đứng hình trước mặt – quá mục tiêu + 8 thì chỉ trong 60 m, quá + 16 thì
# thôi), cùng wid + danh tính (preset, seed, female, profile, wseed). Dựng / lên tầng tối đa 2 người mỗi 0.25 s và tối đa
# một người mỗi khung (mỗi lần dựng ~15 ms), bù người ngoài tầm camera trước; quá mục tiêu thì bỏ người xa nhất ngoài tầm
# camera; người bị bỏ vào pool theo biến thể để dùng lại (pool đầy thì giải phóng người cũ nhất).
# Dịch chuyển > 120 m thì lấp đầy lại ngay.
# Một bong bóng thoại dùng chung (mỗi 4 s tối đa một câu); nước rút tông người -> người chơi chậm 0.2 s, xe tông -> xe
# mất 25 % tốc độ. Không dùng autoload ở đây.
class_name PedestrianSpawner
extends Node3D

signal pedestrian_hit(ped: Pedestrian, kind: String)

const PED_CAP: int = 80
const NEAR_CAP: int = 40
const NEAR_R: float = 35.0
const PROMOTE_R: float = 90.0
const DEMOTE_R: float = 95.0
const CULL_R: float = 225.0
const IMP_CAP: int = 200
const RING_MIN: float = 40.0
const RING_MAX: float = 85.0
const INITIAL_MIN: float = 12.0
const IMP_SPAWN_MIN: float = 150.0
## Mục tiêu ban ngày theo khu quanh người chơi (chỉ số = PedWalkGraph.ZONE_*): người đi đường trong PROMOTE_R / người nộm.
const PED_TARGET: Array[int] = [60, 45, 25]
const IMP_TARGET: Array[int] = [150, 120, 60]
## Kiểu đi của người mới theo khu nơi họ xuất hiện: xác suất [walk, jog, stroll].
const PROFILE_MIX: Array = [[0.9, 0.0, 0.1], [0.7, 0.15, 0.15], [0.85, 0.1, 0.05]]
const NIGHT_FACTOR: float = 0.3
const CHECK_EVERY: float = 0.25
const BUILDS_PER_CHECK: int = 2
const IMP_SPAWNS_PER_CHECK: int = 12
const TRIM_SLACK: int = 4
const VIEW_SPAWN_R: float = 70.0
## Người nộm trong tầm camera lên tầng cả khi đã đủ người, nhưng có trần (vd. chạy xe nhanh vào khu thưa): quá mục tiêu
## + VIEW_SOFT_OVER thì chỉ người nộm trong VIEW_NEAR_R, quá + VIEW_HARD_OVER thì thôi hẳn. Người nộm không được lên tầng
## vẫn là người nộm đi tiếp (không bỏ), nên đám đông không phình theo tốc độ xe.
const VIEW_NEAR_R: float = 60.0
const VIEW_SOFT_OVER: int = 2 * TRIM_SLACK
const VIEW_HARD_OVER: int = 4 * TRIM_SLACK
const TELEPORT_M: float = 120.0
const POOL_MAX: int = 24
const HOTSPOT_CLEAR: float = 3.0
const SPAWN_CLEAR: float = 8.0
const LINE_GAP_S: float = 4.0
const LINE_SHOW_S: float = 2.0
const PLAYER_SLOW_S: float = 0.2
const BIKE_SPEED_KEEP: float = 0.75
const LOG_MAX: int = 64

var graph: PedWalkGraph
var impostors: CrowdImpostors
var md: MapData
var player: Node3D
var bike: Node3D
var roam: Node
var night: bool = false
var spawned: int = 0
var recycled: int = 0
var promoted: int = 0
var demoted: int = 0
var pool_hits: int = 0              # lần dựng dùng lại người trong pool
var pool_evicted: int = 0           # người cũ nhất bị giải phóng vì pool đầy
var promotions: Array = []         # test: {wid, identity, from, to, via ("under" | "view")}
var demotions: Array = []          # test: {wid, identity, pos}
var _peds: Array = []
var _pool: Dictionary = {}         # v -> Array[Pedestrian] đã tách khỏi cây
## Mọi người trong pool, cũ trước. Biến thể gắn với khu (v = khu x 8 + k): pool đầy thì người cũ nhất bị giải phóng để
## người của khu mới vào, nếu không sau lần đổi khu đầu tiên pool nằm lì biến thể khu cũ và không bao giờ trúng nữa.
var _pool_order: Array = []
var _spot_probe: CapsuleShape3D     # capsule cỡ người đi đường cho phép kiểm chỗ đứng (free_spot_at)
var _no_rids: Array[RID] = []
var _by_zone: Array = [[], [], []] # khu -> biến thể của khu (CrowdImpostors.variants())
var _avoid: Array = []
var _rng := RandomNumberGenerator.new()
var _next_wid: int = 1
var _check_t: float = 0.0
var _tokens: int = 0                # lần dựng / lên tầng còn được phép, mỗi khung vật lý tối đa một
var _last_center: Vector3 = Vector3.INF
var _line_t: float = -99.0
var _bubble: Label3D
var _bubble_ped: Pedestrian
var _bubble_left: float = 0.0


func setup(map_data: MapData, player_node: Node3D, opts: Dictionary = {}) -> void:
	md = map_data
	player = player_node
	bike = opts.get("bike", null)
	roam = opts.get("roam", null)
	_avoid = opts.get("avoid", [])
	_rng.seed = int(opts.get("seed", 2026))
	_spot_probe = CapsuleShape3D.new()
	_spot_probe.radius = Pedestrian.RADIUS
	_spot_probe.height = Pedestrian.HEIGHT
	graph = PedWalkGraph.build(md)
	if graph.node_count() == 0:
		push_warning("PedestrianSpawner: đồ thị lối đi bộ rỗng, tắt người đi đường")
		set_physics_process(false)
		set_process(false)
		return
	graph.block_near(_avoid, HOTSPOT_CLEAR)
	for vt: Dictionary in CrowdImpostors.variants():
		(_by_zone[int(vt["zone"])] as Array).append(vt)
	impostors = CrowdImpostors.new()
	impostors.name = "Impostors"
	add_child(impostors)
	impostors.setup(graph, {"cap": IMP_CAP, "seed": int(opts.get("seed", 2026)) + 1})
	_bubble = Label3D.new()
	_bubble.name = "SpeechBubble"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 40
	_bubble.pixel_size = 0.005
	_bubble.outline_size = 10
	_bubble.modulate = Color(1.0, 1.0, 1.0)
	_bubble.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	_bubble.no_depth_test = true
	_bubble.visible = false
	add_child(_bubble)
	night = _is_night()
	_refill_all(_center())


func pedestrians() -> Array:
	return _peds


## Khu quanh điểm c (khu của nút đồ thị gần nhất trong 80 m; không có thì "đường").
func zone_at(c: Vector3) -> int:
	if graph == null:
		return PedWalkGraph.ZONE_ROAD
	var n: int = graph.nearest(c, 80.0)
	return graph.zone_at(n) if n >= 0 else PedWalkGraph.ZONE_ROAD


## Mục tiêu (người đi đường trong PROMOTE_R, người nộm) quanh c theo khu và ngày / đêm.
func targets_at(c: Vector3) -> Vector2i:
	var z: int = zone_at(c)
	var f: float = NIGHT_FACTOR if night else 1.0
	return Vector2i(maxi(1, roundi(float(PED_TARGET[z]) * f)), maxi(1, roundi(float(IMP_TARGET[z]) * f)))


func targets() -> Vector2i:
	return targets_at(_center())


## Câu càu nhàu của người đi đường (giới hạn: mỗi LINE_GAP_S giây một câu cho cả đám).
func request_line(ped: Pedestrian, kind: String) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _line_t < LINE_GAP_S or _bubble == null:
		return
	_line_t = now
	var lines: Array = Pedestrian.PED_LINES.get(kind, Pedestrian.PED_LINES["bump"])
	_bubble.text = String(lines[_rng.randi_range(0, lines.size() - 1)])
	_bubble_ped = ped
	_bubble_left = LINE_SHOW_S
	_bubble.visible = true


func _physics_process(delta: float) -> void:
	if _tokens > 0:
		_build_one(_center())
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY
	var center: Vector3 = _center()
	if _flat(center, _last_center) > TELEPORT_M:
		_reset_around(center)
		return
	_last_center = center
	if _is_night() != night:
		night = not night
		_trim_now(center)
	var t: Vector2i = targets_at(center)
	var want_p: int = mini(t.x, PED_CAP)
	# 1. người đi đường: kẹt / rơi -> bỏ; ra ngoài DEMOTE_R -> người nộm (cùng danh tính)
	for pv: Variant in _peds.duplicate():
		if not is_instance_valid(pv):
			_peds.erase(pv)
			continue
		var p: Pedestrian = pv
		if p.stuck_out:
			recycled += 1
			_release(p)
		elif _flat(p.global_position, center) > DEMOTE_R:
			_demote(p, center)
	# 2. người nộm ra ngoài CULL_R -> bỏ
	recycled += impostors.remove_where(func(q: Vector3) -> bool: return _flat(q, center) > CULL_R)
	# 3. đủ người đi đường: người nộm đã lọt vào trong PROMOTE_R mà ngoài tầm camera thì bỏ (người nộm trong tầm camera
	#    vẫn được _build_one đưa lên tầng, nên không ai đứng hình trước mặt người chơi)
	if _peds.size() >= want_p:
		recycled += impostors.remove_where(func(q: Vector3) -> bool: return _flat(q, center) < PROMOTE_R and not _in_view(q, CULL_R))
	# 4. quá mục tiêu (đổi khu, người nộm vừa lên tầng): bỏ người xa nhất NGOÀI tầm camera, không hạ thành người nộm
	if _peds.size() > want_p + TRIM_SLACK:
		_trim_out_of_view(center, mini(BUILDS_PER_CHECK, _peds.size() - want_p - TRIM_SLACK))
	# 5. người nộm: bớt người xa nhất khi quá mục tiêu, bù ở vòng ngoài
	if impostors.count() > t.y + TRIM_SLACK * 3:
		recycled += impostors.remove_farthest(center, impostors.count() - t.y)
	var made: int = 0
	var tries: int = 0
	while impostors.count() < t.y and made < IMP_SPAWNS_PER_CHECK and tries < IMP_SPAWNS_PER_CHECK * 3:
		tries += 1
		if _spawn_impostor(center, IMP_SPAWN_MIN, CULL_R - 5.0):
			made += 1
	_assign_tiers(center)
	_tokens = BUILDS_PER_CHECK   # các khung kế tiếp: mỗi khung tối đa một lần dựng / lên tầng


## Một lần dựng / lên tầng: người nộm gần nhất trong PROMOTE_R lên tầng khi còn dưới mục tiêu, hoặc khi đang trong tầm
## camera (trong PROMOTE_R tới mục tiêu + VIEW_SOFT_OVER, trong VIEW_NEAR_R tới + VIEW_HARD_OVER, rồi thôi); không có thì
## bù một người mới ở vòng RING_MIN..RING_MAX, ngoài tầm camera trước.
func _build_one(center: Vector3) -> void:
	_tokens -= 1
	var n: int = _peds.size()
	if n >= PED_CAP:
		return
	var want: int = mini(targets_at(center).x, PED_CAP)
	var under: bool = n < want
	var view_r: float = PROMOTE_R if n < want + VIEW_SOFT_OVER else (VIEW_NEAR_R if n < want + VIEW_HARD_OVER else 0.0)
	var got: Array = impostors.take_within(center, PROMOTE_R, 1, func(q: Vector3) -> bool:
		return under or (_flat(q, center) < view_r and _in_view(q, CULL_R)))
	if not got.is_empty():
		_promote(got[0], "under" if under else "view")
		return
	if under:
		for k: int in range(6):
			if _spawn_new(center, RING_MIN, RING_MAX, k < 4):
				return


func _process(delta: float) -> void:
	if _bubble == null or not _bubble.visible:
		return
	_bubble_left -= delta
	if _bubble_left <= 0.0 or not is_instance_valid(_bubble_ped) or not _bubble_ped.is_inside_tree():
		_bubble.visible = false
		return
	var top: Node3D = CharacterBuilder.head_top(_bubble_ped.model)
	_bubble.global_position = (top.global_position if top else _bubble_ped.global_position + Vector3(0.0, 1.9, 0.0)) + Vector3(0.0, 0.35, 0.0)


## Người trong pool đã tách khỏi cây: giải phóng khi spawner rời cây (đổi cảnh) để không rò Node.
func _exit_tree() -> void:
	for p: Variant in _pool_order:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_pool.clear()
	_pool_order.clear()


# ---------------------------------------------------------------------------
# LẤP ĐẦY / CẮT BỚT
# ---------------------------------------------------------------------------
func _refill_all(center: Vector3) -> void:
	_last_center = center
	var t: Vector2i = targets_at(center)
	var want_p: int = mini(t.x, PED_CAP)
	var tries: int = 0
	while _peds.size() < want_p and tries < want_p * 6:
		tries += 1
		_spawn_new(center, INITIAL_MIN, RING_MAX, false)
	tries = 0
	while impostors.count() < t.y and tries < t.y * 4:
		tries += 1
		_spawn_impostor(center, DEMOTE_R, CULL_R - 5.0)
	_assign_tiers(center)


## Dịch chuyển (về từ màn chơi, test): bỏ hết rồi lấp đầy quanh chỗ mới.
func _reset_around(center: Vector3) -> void:
	for pv: Variant in _peds.duplicate():
		if is_instance_valid(pv):
			_release(pv)
	_peds.clear()
	impostors.remove_where(func(_q: Vector3) -> bool: return true)
	night = _is_night()
	_refill_all(center)


## Đổi ngày / đêm: cắt ngay về mục tiêu mới, người xa nhất trước (đèn cả cảnh đổi cùng lúc nên không lộ).
## Sang đêm còn bỏ mọi người nộm trong PROMOTE_R: người nộm trong tầm camera ở đó đang chờ _build_one đưa lên tầng
## (bất kể mục tiêu), nên để lại thì ngay sau khi cắt số người đi đường lại vượt mục tiêu đêm.
func _trim_now(center: Vector3) -> void:
	var t: Vector2i = targets_at(center)
	var order: Array = _sorted_by_distance(center, true)
	for i: int in range(maxi(0, order.size() - t.x)):
		recycled += 1
		_release(order[i])
	if night:
		recycled += impostors.remove_where(func(q: Vector3) -> bool: return _flat(q, center) < PROMOTE_R)
	if impostors.count() > t.y:
		recycled += impostors.remove_farthest(center, impostors.count() - t.y)


## Bỏ tối đa n người xa nhất đang NGOÀI tầm camera (vào pool / giải phóng).
func _trim_out_of_view(center: Vector3, n: int) -> void:
	var cut: int = 0
	for p: Pedestrian in _sorted_by_distance(center, true):
		if cut >= n:
			return
		if not _in_view(p.global_position, CULL_R):
			recycled += 1
			_release(p)
			cut += 1


## 40 người gần nhất trong 35 m có vật lý và bóng đổ; còn lại là tầng giữa (Pedestrian.set_far).
func _assign_tiers(center: Vector3) -> void:
	var order: Array = _sorted_by_distance(center, false)
	for i: int in range(order.size()):
		var p: Pedestrian = order[i]
		p.set_far(i >= NEAR_CAP or _flat(p.global_position, center) > NEAR_R)


func _sorted_by_distance(center: Vector3, farthest_first: bool) -> Array:
	var pairs: Array = []
	for p: Pedestrian in _peds:
		pairs.append([_flat(p.global_position, center), p])
	if farthest_first:
		pairs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	else:
		pairs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return pairs.map(func(x: Array) -> Pedestrian: return x[1])


# ---------------------------------------------------------------------------
# NGƯỜI ĐI ĐƯỜNG / NGƯỜI NỘM
# ---------------------------------------------------------------------------
func _spawn_new(center: Vector3, r_min: float, r_max: float, avoid_view: bool) -> bool:
	var node: int = graph.random_point_ring(center, r_min, r_max, _rng)
	if node < 0:
		return false
	var p: Vector3 = graph.node_pos(node)
	if not _clear_of_avoid(p) or (avoid_view and _in_view(p, VIEW_SPAWN_R)):
		return false
	var spot: Variant = _free_spot(p)
	if not (spot is Vector3):
		return false
	_spawn_ped(node, node, spot, _new_identity(graph.zone_at(node)))
	return true


func _spawn_impostor(center: Vector3, r_min: float, r_max: float) -> bool:
	var node: int = graph.random_point_ring(center, r_min, r_max, _rng)
	if node < 0 or not _clear_of_avoid(graph.node_pos(node)):
		return false
	var ident: Dictionary = _new_identity(graph.zone_at(node))
	var sp: float = Pedestrian.speed_for(String(ident["profile"]), int(ident["wseed"]))
	return impostors.add({"wid": int(ident["wid"]), "identity": ident, "node": node, "prev": node, "pos": graph.node_pos(node), "speed": sp})


## Danh tính mới: một biến thể của khu (8 biến thể mỗi khu), kiểu đi theo PROFILE_MIX, wseed và wid riêng.
func _new_identity(zone: int) -> Dictionary:
	var list: Array = _by_zone[zone]
	var ident: Dictionary = (list[_rng.randi_range(0, list.size() - 1)] as Dictionary).duplicate()
	var mix: Array = PROFILE_MIX[zone]
	var r: float = _rng.randf()
	var profile: String = "walk" if r < float(mix[0]) else ("jog" if r < float(mix[0]) + float(mix[1]) else "stroll")
	if String(ident["preset"]) == "lecturer" and profile == "jog":
		profile = "walk"
	ident["profile"] = profile
	ident["wseed"] = _rng.randi() % 1000000
	ident["wid"] = _next_wid
	_next_wid += 1
	return ident


func _spawn_ped(node: int, prev: int, at: Vector3, ident: Dictionary) -> Pedestrian:
	var v: int = int(ident.get("v", -1))
	var p: Pedestrian = null
	var pool: Array = _pool.get(v, [])
	if not pool.is_empty():
		p = pool.pop_back()
		_pool_order.erase(p)
		pool_hits += 1
	else:
		p = Pedestrian.new()
		p.name = "Ped_%d" % spawned
	p.setup(graph, node, ident)
	p.prev_node = prev
	p.player = player
	p.bike = bike
	p.mounted_fn = _mounted
	p.crowd = _peds
	p.spawner = self
	if not p.hit.is_connected(_on_hit):
		p.hit.connect(_on_hit)
	add_child(p)
	p.global_position = at + Vector3(0.0, 0.05, 0.0)
	_peds.append(p)
	spawned += 1
	if player and player.get("cam_ray"):
		(player.get("cam_ray") as RayCast3D).add_exception(p)
	if bike and bike.get("spring_arm"):
		(bike.get("spring_arm") as SpringArm3D).add_excluded_object(p.get_rid())
	return p


## Người nộm -> người đi đường tại chỗ người nộm đứng, không được thì ở nút gần hơn trong hai nút của cạnh nó đang đi
## (nút đang tới / nút vừa rời), rồi nút còn lại; không có chỗ cho thân thật thì bỏ. via: "under" (dưới mục tiêu) /
## "view" (trong tầm camera) – ghi vào nhật ký cho test.
func _promote(st: Dictionary, via: String) -> void:
	var pos: Vector3 = st["pos"]
	var a: Vector3 = graph.node_pos(int(st["node"]))
	var b: Vector3 = graph.node_pos(int(st["prev"]))
	var tries: Array = [pos, a, b] if _flat(a, pos) <= _flat(b, pos) else [pos, b, a]
	var at: Variant = null
	for q: Vector3 in tries:
		at = _free_spot(q)
		if at is Vector3:
			break
	if not (at is Vector3):
		recycled += 1
		return
	var p: Pedestrian = _spawn_ped(int(st["node"]), int(st["prev"]), at, st["identity"])
	promoted += 1
	_log(promotions, {"wid": int(st["wid"]), "identity": p.identity, "from": pos, "to": p.global_position, "via": via})


func _demote(p: Pedestrian, center: Vector3) -> void:
	if _flat(p.global_position, center) < CULL_R:
		var st: Dictionary = {"wid": int(p.identity.get("wid", -1)), "identity": p.identity, "node": p.target_node, "prev": p.prev_node, "pos": p.global_position, "speed": p.walk_speed}
		if impostors.add(st):
			demoted += 1
			_log(demotions, {"wid": int(st["wid"]), "identity": p.identity, "pos": st["pos"]})
	_release(p)


## Bỏ một người đi đường khỏi đám: vào pool của biến thể (tách khỏi cây); pool đầy thì giải phóng người cũ nhất trong
## pool trước (FIFO). Người kẹt (stuck_out) hoặc không rõ biến thể thì giải phóng luôn.
func _release(p: Pedestrian) -> void:
	_peds.erase(p)
	if _bubble_ped == p and _bubble:
		_bubble.visible = false
	var v: int = int(p.identity.get("v", -1))
	if v < 0 or p.stuck_out:
		_free_ped(p)
		return
	if _pool_order.size() >= POOL_MAX:
		var old: Pedestrian = _pool_order.pop_front()
		(_pool[int(old.identity.get("v", -1))] as Array).erase(old)
		pool_evicted += 1
		_free_ped(old)
	remove_child(p)
	if not _pool.has(v):
		_pool[v] = []
	(_pool[v] as Array).append(p)
	_pool_order.append(p)


func _free_ped(p: Pedestrian) -> void:
	if player and player.get("cam_ray"):
		(player.get("cam_ray") as RayCast3D).remove_exception(p)
	if bike and bike.get("spring_arm"):
		(bike.get("spring_arm") as SpringArm3D).remove_excluded_object(p.get_rid())
	p.queue_free()


# ---------------------------------------------------------------------------
# PHỤ TRỢ
# ---------------------------------------------------------------------------
func _center() -> Vector3:
	if _mounted() and bike:
		return bike.global_position
	return player.global_position if player else Vector3.ZERO


func _mounted() -> bool:
	return roam != null and bool(roam.get("mounted"))


func _is_night() -> bool:
	return roam != null and String(roam.get("tod_preset")) == "night"


## Chỗ đứng cho một người đi đường tại (p.x, p.z): FreeRoam.free_spot_at với capsule cỡ người đi đường (r 0,28).
func _free_spot(p: Vector3) -> Variant:
	if roam and roam.has_method("free_spot_at"):
		return roam.call("free_spot_at", Vector3(p.x, 0.0, p.z), 0.0, _no_rids, _spot_probe)
	return Vector3(p.x, 0.0, p.z)


func _clear_of_avoid(p: Vector3) -> bool:
	for a: Variant in _avoid:
		var av: Vector3 = a
		if Vector2(p.x - av.x, p.z - av.z).length() < HOTSPOT_CLEAR + 0.5:
			return false
	if player and Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() < SPAWN_CLEAR:
		return false
	return true


func _in_view(p: Vector3, max_d: float) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	return cam.global_position.distance_to(p) < max_d and cam.is_position_in_frustum(p + Vector3(0.0, 1.0, 0.0))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _log(arr: Array, e: Dictionary) -> void:
	arr.append(e)
	if arr.size() > LOG_MAX:
		arr.pop_front()


func _on_hit(ped: Pedestrian, kind: String) -> void:
	if kind == "sprint" and player:
		player.set("slow_t", PLAYER_SLOW_S)
	elif kind == "bike" and bike:
		bike.set("current_speed_ms", float(bike.get("current_speed_ms")) * BIKE_SPEED_KEEP)
	pedestrian_hit.emit(ped, kind)
