# File: res://tests/test_pedestrians.gd
# Test headless người đi đường FreeRoam (spec vice-people-and-movement, Phần 3).
#   A (Task 9):  đồ thị lối đi bộ từ mapdata: > 500 nút, không nút nào dưới nước / trong nhà OSM / trên lòng đường,
#                ba khu (campus / dân cư / đường) đủ nút, vòng quảng trường BE6, truy vấn random_point_ring / next_node,
#                lần dựng thứ hai lấy từ bộ nhớ đệm và block_near trên bản chép không cắt bản gốc.
#   B (Task 10): người đi đường trên đồ thị tự dựng: tốc độ theo kiểu đi, đi bộ + chạy bộ, va nhẹ -> STUMBLE, nước rút
#                -> KNOCKDOWN rồi đi lại trong 3 s, xe > 3 m/s -> KNOCKDOWN (tín hiệu "bike"), tầng giữa không va chạm.
#   C (Task 12): FreeRoam: mật độ theo khu (campus >= 40, dân cư >= 30, đường >= 15 người trong 80 m), trần từng tầng,
#                đêm còn 30 %, lên/xuống tầng giữ nguyên danh tính (cả đường "trong tầm camera" khi đã đủ người, có trần),
#                pool bỏ người cũ sau khi đổi khu, tránh hotspot, xe tông người bị chậm lại, chi phí.
# Chạy:  godot --headless --path . --script tests/test_pedestrians.gd
extends SceneTree

const PART_B: bool = true   # Task 10 bật
const PART_C: bool = true   # Task 12 bật

var done: bool = false
var frames: int = 0
var world_b: Node3D
var ped: Pedestrian
var jogger: Pedestrian
var statue: Pedestrian
var stub_player: CharacterBody3D
var stub_bike: CharacterBody3D
var mounted: bool = false
var b_started: bool = false
var b_phase: String = ""
var b_t0: int = 0
var b_hits: Array[String] = []
var jog_start: Vector3


func _initialize() -> void:
	if not _part_a():
		return
	if not PART_B and not PART_C:
		print("✅ SUCCESS: PEDESTRIANS (part A: walk graph)")
		done = true
		quit(0)
	if PART_B:
		physics_frame.connect(_on_physics_b)   # phần B đếm khung vật lý (60 Hz), bắt đầu khi gốc đã vào cây


func _part_b_start() -> void:
	var rig: Node3D = CharacterBuilder.build({"preset": "student", "seed": 4, "rigged": true, "animate": false})
	var sk: Skeleton3D = rig.get_meta("skeleton", null) as Skeleton3D
	var thigh: int = sk.find_bone("UpperLeg.L")
	var arm: int = sk.find_bone("UpperArm.L")
	CharacterBuilder.pose(rig, "phone_stand")
	var leg_deg: float = rad_to_deg(sk.get_bone_pose_rotation(thigh).angle_to(sk.get_bone_rest(thigh).basis.get_rotation_quaternion()))
	var arm_deg: float = rad_to_deg(sk.get_bone_pose_rotation(arm).angle_to(sk.get_bone_rest(arm).basis.get_rotation_quaternion()))
	rig.free()
	if not _check(leg_deg < 1.0 and arm_deg > 20.0, "phone_stand keeps the legs standing and raises the arms (thigh %.1f°, arm %.1f°)" % [leg_deg, arm_deg]):
		return
	for prof: String in Pedestrian.PROFILES.keys():
		var lim: Array = Pedestrian.PROFILES[prof]
		for s: int in range(20):
			var v: float = Pedestrian.speed_for(prof, s)
			if not _check(v >= float(lim[0]) and v <= float(lim[1]) and v == Pedestrian.speed_for(prof, s), "speed_for(%s, %d) = %.2f must be deterministic and inside %s" % [prof, s, v, str(lim)]):
				return
	world_b = Node3D.new()
	world_b.position = Vector3(0.0, 0.0, 5000.0)   # xa thế giới thật của phần A (không dựng gì ở đây)
	root.add_child(world_b)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200.0, 1.0, 200.0)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0.0, -0.5, 0.0)
	world_b.add_child(sb)
	# hai đường thẳng 60 m dọc trục X cách nhau 12 m (toạ độ bản đồ = thế giới của world_b): nút 0..10 và 11..21
	var line := PackedVector2Array()
	var line2 := PackedVector2Array()
	for i: int in range(11):
		line.append(Vector2(-30.0 + float(i) * 6.0, 5000.0))
		line2.append(Vector2(-30.0 + float(i) * 6.0, 5012.0))
	var g: PedWalkGraph = PedWalkGraph.from_lines([line, line2])
	stub_player = _stub("StubPlayer", Vector3(40.0, 0.0, 5000.0), 0.4)
	stub_bike = _stub("StubBike", Vector3(-40.0, 0.0, 5000.0), 0.6)
	ped = _ped(g, 5, {"preset": "student", "seed": 11}, Vector3(0.0, 0.05, 5000.0))
	ped.hit.connect(func(_p: Pedestrian, kind: String) -> void: b_hits.append(kind))
	jogger = _ped(g, 16, {"preset": "casual", "seed": 12, "profile": "jog", "wseed": 3}, Vector3(0.0, 0.05, 5012.0))
	jog_start = jogger.global_position
	b_phase = "walk"
	b_t0 = 0


func _ped(g: PedWalkGraph, node: int, ident: Dictionary, at: Vector3) -> Pedestrian:
	var p := Pedestrian.new()
	p.setup(g, node, ident)
	p.player = stub_player
	p.bike = stub_bike
	p.mounted_fn = func() -> bool: return mounted
	root.add_child(p)
	p.global_position = at
	return p


func _stub(name: String, at: Vector3, r: float) -> CharacterBody3D:
	var s := CharacterBody3D.new()
	s.name = name
	s.set_script(load("res://tests/support/stub_mover.gd"))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0.0, 0.85, 0.0)
	s.add_child(cs)
	s.collision_layer = 0   # chỉ đo khoảng cách, không đẩy người đi đường
	root.add_child(s)
	s.global_position = at
	return s


func _on_physics_b() -> void:
	if done:
		return
	if not b_started:
		b_started = true
		_part_b_start()
		return
	if b_phase == "":
		return
	frames += 1
	var t: int = frames - b_t0
	match b_phase:
		"walk":
			if t == 90:   # 1.5 s
				var moved: float = Vector2(ped.global_position.x, ped.global_position.z - 5000.0).length()
				var jogged: float = jogger.global_position.distance_to(jog_start)
				print("  pedestrian walked %.2f m in 1.5 s (state %d), jogger %.2f m" % [moved, ped.state, jogged])
				if not _check(moved > 1.2 and ped.state == Pedestrian.State.WALK, "a pedestrian must walk along the graph (moved %.2f m)" % moved):
					return
				if not _check(jogged > 2.9 and jogger.state == Pedestrian.State.WALK, "a jogger must cover > 2.9 m in 1.5 s (got %.2f m)" % jogged):
					return
				stub_player.set("speed_value", 3.0)
				stub_player.global_position = ped.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "bump"
				b_t0 = frames
		"bump":
			if t == 3:
				print("  bump -> state %d, hits %s" % [ped.state, b_hits])
				if not _check(ped.state == Pedestrian.State.STUMBLE and b_hits.size() == 1 and b_hits[0] == "bump", "a walking bump (3 m/s) must give STUMBLE and one 'bump' hit"):
					return
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
			if t == 80:   # 1.33 s: hết hồi 1 s và lảo đảo 0.8 s
				stub_player.set("speed_value", 7.0)
				stub_player.global_position = ped.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "sprint"
				b_t0 = frames
		"sprint":
			if t == 3:
				if not _check(ped.state == Pedestrian.State.KNOCKDOWN and b_hits.back() == "sprint", "a sprint hit (7 m/s) must give KNOCKDOWN"):
					return
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
			if t == 180:   # 3 s (ngã 1.2 s + đứng dậy 0.9 s)
				print("  after knockdown: state %d" % ped.state)
				if not _check(ped.state == Pedestrian.State.FLEE or ped.state == Pedestrian.State.WALK, "a knocked-down pedestrian walks again within 3 s (state %d)" % ped.state):
					return
				mounted = true
				stub_bike.set("speed_value", 6.0)
				# lệch 0,9 m dọc trục dài xe (Z) và 0,5 m ngang: tới gốc xe 1,03 m (> 0,93 m) nhưng tới trục capsule 0,74 m,
				# nên chỉ trúng khi đo tới trục (BIKE_HALF_AXIS)
				stub_bike.global_position = ped.global_position + Vector3(-0.5, 0.0, 0.9)
				b_phase = "bike"
				b_t0 = frames
		"bike":
			if t == 3:
				print("  bike hit -> state %d, hits %s" % [ped.state, b_hits])
				if not _check(ped.state == Pedestrian.State.KNOCKDOWN and b_hits.back() == "bike", "a bike hit above 3 m/s must give KNOCKDOWN with kind 'bike'"):
					return
				mounted = false
				stub_bike.global_position = Vector3(-40.0, 0.0, 5000.0)
				jogger.set_far(true)
				stub_player.set("speed_value", 7.0)
				stub_player.global_position = jogger.global_position + Vector3(0.65, 0.0, 0.0)
				b_phase = "mid"
				b_t0 = frames
		"mid":
			if t == 3:
				print("  mid-tier contact -> jogger hits %s, state %d" % [jogger.hits, jogger.state])
				if not _check(jogger.hits.is_empty() and jogger.state == Pedestrian.State.WALK and jogger.collision_layer == 0, "a mid-tier pedestrian (lod_far) makes no contact checks and is not solid (layer %d)" % jogger.collision_layer):
					return
				stub_player.global_position = Vector3(40.0, 0.0, 5000.0)
				# người đi đường trên nút bậc 0 (một điểm lẻ): phải tự báo stuck_out để spawner thu hồi
				var lone := PackedVector2Array([Vector2(20.0, 5024.0)])
				statue = _ped(PedWalkGraph.from_lines([lone]), 0, {"preset": "student", "seed": 13}, Vector3(20.0, 0.05, 5024.0))
				b_phase = "statue"
				b_t0 = frames
		"statue":
			if t == 10:
				print("  degree-0 pedestrian -> stuck_out %s" % statue.stuck_out)
				if not _check(statue.stuck_out, "a pedestrian on a degree-0 node must set stuck_out within a few frames"):
					return
				if not PART_C:
					print("✅ SUCCESS: PEDESTRIANS (parts A + B)")
					done = true
					quit(0)
				if PART_C:
					b_phase = ""
					_part_c_start()


const MIN_NEAR: Array[int] = [40, 30, 15]   # spec Amendment: người đi đường trong 80 m – campus / dân cư / đường
const ROAD_SPOT := Vector3(2058.0, 0.0, -71.0)   # giữa đường Nguyễn Xiển (hành lang)

## Nút chạy SAU mọi _physics_process khác: cùng mốc đầu khung (đặt ở đầu _on_physics_c, tín hiệu physics_frame phát trước
## khi các nút xử lý vật lý) đo thời gian phía script của từng bước vật lý. Performance.TIME_PHYSICS_PROCESS không dùng
## được: Godot chỉ cập nhật nó mỗi giây bằng bước chậm nhất trong giây đó.
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var roam: Node3D
var c_phase: String = ""
var c_t0: int = 0
var c_frames: int = 0
var phys_with: float = 0.0
var phys_without: float = 0.0
var timing: bool = false
var _pt0: int = 0
var p_usec: int = 0
var p_n: int = 0
var snap: Dictionary = {}           # wid -> identity của mọi người nộm trước khi tiến lại gần
var inject: Dictionary = {}         # wid -> identity của người nộm test thả trước camera
var day_t: Vector2i


func _part_c_start() -> void:
	for n: Node in [ped, jogger, statue, world_b, stub_player, stub_bike]:
		n.queue_free()
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n2: Node = s.new()
			n2.name = pair[0]
			root.add_child(n2)
	var tail := PhysTail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _phys_tail
	root.add_child(tail)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	c_phase = "settle"
	c_t0 = c_frames
	physics_frame.connect(_on_physics_c)


func _phys_tail() -> void:
	if timing:
		p_usec += Time.get_ticks_usec() - _pt0
		p_n += 1


func _sp() -> PedestrianSpawner:
	return roam.get("pedestrians") as PedestrianSpawner


func _player() -> Node3D:
	return roam.get("player") as Node3D


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _teleport(p: Vector3) -> void:
	var spot: Variant = roam.call("find_free_spot", Vector3(p.x, 0.0, p.z), 0.0, 8)
	var at: Vector3 = spot if spot is Vector3 else Vector3(p.x, 0.5, p.z)
	_player().call("teleport", at + Vector3(0.0, 0.05, 0.0), 0.0)


## Quay người chơi (teleport tại chỗ) về hướng (12 cung 30°) có nhiều nút lối đi bộ nhất ở MỌI vành [r_min, r_max]
## trong bands, để camera nhìn thẳng vào chỗ test thả người nộm.
func _aim_at_walk_nodes(bands: Array) -> void:
	var g: PedWalkGraph = _sp().graph
	var c: Vector3 = _player().global_position
	var counts: Array = []
	for _b: Variant in bands:
		var row: Array[int] = []
		row.resize(12)
		row.fill(0)
		counts.append(row)
	for i: int in range(g.node_count()):
		if g.neighbours(i).is_empty():
			continue
		var q: Vector3 = g.node_pos(i)
		var d: float = _flat(q, c)
		for k: int in range(bands.size()):
			if d >= float(bands[k][0]) and d <= float(bands[k][1]):
				var bin: int = posmod(floori((atan2(-(q.x - c.x), -(q.z - c.z)) + PI) / (TAU / 12.0)), 12)
				counts[k][bin] += 1
	var best: int = 0
	var best_n: int = -1
	for bin2: int in range(12):
		var m: int = 1 << 30
		for row2: Array[int] in counts:
			m = mini(m, row2[bin2])
		if m > best_n:
			best_n = m
			best = bin2
	_player().call("teleport", c, -PI + (float(best) + 0.5) * TAU / 12.0)


func _clear_impostors_within(r: float) -> void:
	var c: Vector3 = _player().global_position
	_sp().impostors.remove_where(func(q: Vector3) -> bool: return _flat(q, c) < r)


## Tối đa max_n nút lối đi bộ (có cạnh, cách nhau >= 4 m) cách người chơi r_min..r_max, trong tầm camera (lệch hướng
## nhìn < 25°) và có chỗ đứng cho người đi đường.
func _view_nodes(r_min: float, r_max: float, max_n: int) -> Array:
	var sp: PedestrianSpawner = _sp()
	var g: PedWalkGraph = sp.graph
	var c: Vector3 = _player().global_position
	var cam: Camera3D = root.get_camera_3d()
	var f3: Vector3 = -cam.global_basis.z
	var fwd := Vector2(f3.x, f3.z).normalized()
	var out: Array = []
	for i: int in range(g.node_count()):
		var q: Vector3 = g.node_pos(i)
		var d: float = _flat(q, c)
		if d < r_min or d > r_max or g.neighbours(i).is_empty():
			continue
		if Vector2(q.x - cam.global_position.x, q.z - cam.global_position.z).normalized().dot(fwd) < cos(deg_to_rad(25.0)):
			continue
		if not sp._in_view(q, PedestrianSpawner.CULL_R):
			continue
		var spread: bool = true
		for j: int in out:
			if _flat(g.node_pos(j), q) < 4.0:
				spread = false
		if not spread or not (sp._free_spot(q) is Vector3):
			continue
		out.append(i)
		if out.size() >= max_n:
			break
	return out


## Thả một người nộm danh tính mới (wid mới) ở nút nd, đang đi sang một nút kề; trả về wid (-1 nếu bị từ chối).
func _add_impostor(nd: int) -> int:
	var sp: PedestrianSpawner = _sp()
	var ident: Dictionary = sp._new_identity(sp.graph.zone_at(nd))
	var nb: Array = sp.graph.neighbours(nd)
	var st: Dictionary = {"wid": int(ident["wid"]), "identity": ident, "node": int(nb[0]) if not nb.is_empty() else nd, "prev": nd,
		"pos": sp.graph.node_pos(nd), "speed": Pedestrian.speed_for(String(ident["profile"]), int(ident["wseed"]))}
	if not sp.impostors.add(st):
		return -1
	inject[int(ident["wid"])] = ident.duplicate()
	return int(ident["wid"])


## Trần đường lên tầng "trong tầm camera" (gọi thẳng _build_one khi spawner tạm dừng, nên tất định): quá mục tiêu
## + VIEW_HARD_OVER thì người nộm trong tầm camera ở 25-55 m vẫn là người nộm (đi tiếp, không bỏ); quá + VIEW_SOFT_OVER
## (dưới + HARD) thì người nộm trong 60 m lên tầng, người nộm ở 70-85 m thì không.
func _cap_ok() -> bool:
	var sp: PedestrianSpawner = _sp()
	sp.set_physics_process(false)
	var c: Vector3 = _player().global_position
	var want: int = sp.targets().x
	var hard: int = want + PedestrianSpawner.VIEW_HARD_OVER
	var tries: int = 0
	while sp.pedestrians().size() < hard and tries < 600:
		tries += 1
		sp._spawn_new(c, PedestrianSpawner.INITIAL_MIN, PedestrianSpawner.RING_MAX, false)
	if not _check(sp.pedestrians().size() >= hard, "test setup: could not fill the crowd to target + %d (%d / %d)" % [PedestrianSpawner.VIEW_HARD_OVER, sp.pedestrians().size(), hard]):
		return false
	_clear_impostors_within(PedestrianSpawner.PROMOTE_R)
	var near: Array = _view_nodes(25.0, 55.0, 1)
	var far: Array = _view_nodes(70.0, 85.0, 1)
	if not _check(near.size() == 1 and far.size() == 1, "test setup: need in-view walk nodes 25-55 m and 70-85 m away (got %d, %d)" % [near.size(), far.size()]):
		return false
	var a: int = _add_impostor(near[0])
	var n0: int = sp.pedestrians().size()
	sp._tokens = 1
	sp._build_one(c)
	var kept_hard: bool = sp.impostors.wids().has(a) and sp.pedestrians().size() == n0
	while sp.pedestrians().size() > want + PedestrianSpawner.VIEW_SOFT_OVER + 1:
		sp._release(sp.pedestrians().back())
	var b: int = _add_impostor(far[0])
	sp._tokens = 2
	sp._build_one(c)
	sp._build_one(c)
	var via_a: String = ""
	for e: Dictionary in sp.promotions:
		if int(e["wid"]) == a:
			via_a = String(e.get("via", ""))
	var kept_b: bool = sp.impostors.wids().has(b)
	print("  in-view cap: at target + %d the impostor %.0f m away stayed (%s); at target + %d it was promoted (via %s) and the one %.0f m away stayed (%s)" % [
		n0 - want, _flat(sp.graph.node_pos(near[0]), c), kept_hard, PedestrianSpawner.VIEW_SOFT_OVER + 1, via_a, _flat(sp.graph.node_pos(far[0]), c), kept_b])
	sp.set_physics_process(true)
	return _check(kept_hard and via_a == "view" and kept_b, "in-view promotion is capped: none above target + %d, only within %.0f m above target + %d" % [
		PedestrianSpawner.VIEW_HARD_OVER, PedestrianSpawner.VIEW_NEAR_R, PedestrianSpawner.VIEW_SOFT_OVER])


func _same_identity(a: Dictionary, b: Dictionary) -> bool:
	for k: String in ["v", "preset", "seed", "female", "profile", "wseed", "wid"]:
		if str(a.get(k, "-")) != str(b.get(k, "-")):
			return false
	return true


## Mật độ theo khu, trần các tầng, tầng gần trong 35 m, không ai rơi, người nộm trong vòng 225 m.
func _density_ok(label: String) -> bool:
	var sp: PedestrianSpawner = _sp()
	var c: Vector3 = _player().global_position
	var zone: int = sp.zone_at(c)
	var peds: Array = sp.pedestrians()
	var n80: int = 0
	var near: int = 0
	for p: Pedestrian in peds:
		var d: float = _flat(p.global_position, c)
		if d <= 80.0:
			n80 += 1
		if not p.lod_far:
			near += 1
			if not _check(d <= PedestrianSpawner.NEAR_R + 4.0, "%s: a near-tier pedestrian is %.1f m away (near tier <= 35 m)" % [label, d]):
				return false
		if not _check(p.global_position.y > -1.0, "%s: a pedestrian fell through the world" % label):
			return false
	var imp: int = sp.impostors.count()
	print("  %s: zone %d, %d pedestrians within 80 m (%d total, %d near), %d impostors" % [label, zone, n80, peds.size(), near, imp])
	if not _check(n80 >= MIN_NEAR[zone], "%s: at least %d pedestrians within 80 m in zone %d (got %d)" % [label, MIN_NEAR[zone], zone, n80]):
		return false
	if not _check(peds.size() <= PedestrianSpawner.PED_CAP and near <= PedestrianSpawner.NEAR_CAP and imp <= PedestrianSpawner.IMP_CAP, "%s: tier caps (pedestrians %d / 80, near %d / 40, impostors %d / 200)" % [label, peds.size(), near, imp]):
		return false
	if not _check(imp >= int(float(sp.targets().y) * 0.6), "%s: impostors %d below 60 %% of the target %d" % [label, imp, sp.targets().y]):
		return false
	for q: Vector3 in sp.impostors.positions():
		if not _check(_flat(q, c) <= PedestrianSpawner.CULL_R + 5.0, "%s: an impostor %.0f m away (cull at 225 m)" % [label, _flat(q, c)]):
			return false
	return true


func _on_physics_c() -> void:
	_pt0 = Time.get_ticks_usec()
	if done:
		return
	c_frames += 1
	var t: int = c_frames - c_t0
	match c_phase:
		"settle":
			if t == 150:
				if not _check(_sp() != null, "FreeRoam must expose a pedestrians spawner"):
					return
				if not _check(_sp().zone_at(_player().global_position) == PedWalkGraph.ZONE_RESIDENTIAL, "the BE6 spawn is in the residential zone"):
					return
				if not _density_ok("BE6 spawn"):
					return
				for h: Variant in roam.get("hotspots"):
					var hn: Node3D = h
					for p: Pedestrian in _sp().pedestrians():
						if not _check(_flat(p.global_position, hn.global_position) >= 2.5, "pedestrian %.1f m from a hotspot (keep 3 m)" % _flat(p.global_position, hn.global_position)):
							return
				_teleport(ROAD_SPOT)
				c_phase = "road"
				c_t0 = c_frames
		"road":
			if t == 45:
				if not _check(_sp().zone_at(_player().global_position) == PedWalkGraph.ZONE_ROAD, "test setup: Nguyễn Xiển is in the road zone"):
					return
				if not _density_ok("Nguyễn Xiển"):
					return
				var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
				_teleport(FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y))
				c_phase = "campus"
				c_t0 = c_frames
		"campus":
			if t == 45:
				if not _check(_sp().zone_at(_player().global_position) == PedWalkGraph.ZONE_CAMPUS, "test setup: the courtyard is in the campus zone"):
					return
				if not _density_ok("campus courtyard"):
					return
				_sp().set_physics_process(false)   # dừng việc kiểm / dựng của spawner (con vẫn chạy): chỉ đo đám đông
				p_usec = 0
				p_n = 0
				timing = true
				c_phase = "perf_with"
				c_t0 = c_frames
		"perf_with":
			if t == 1:   # bỏ mẫu của khung chuyển pha: nó gồm cả phép kiểm mật độ nặng của pha campus
				p_usec = 0
				p_n = 0
			if t == 60:
				phys_with = float(p_usec) / float(maxi(1, p_n))
				_sp().process_mode = Node.PROCESS_MODE_DISABLED
				p_usec = 0
				p_n = 0
				c_phase = "perf_without"
				c_t0 = c_frames
		"perf_without":
			if t == 1:   # bỏ mẫu của khung chuyển pha (tắt spawner gỡ các thân người đi đường khỏi không gian vật lý)
				p_usec = 0
				p_n = 0
			if t == 60:
				phys_without = float(p_usec) / float(maxi(1, p_n))
				timing = false
				var cost_ms: float = (phys_with - phys_without) / 1000.0
				print("  crowd physics cost %.2f ms per physics frame (%.0f vs %.0f us)" % [cost_ms, phys_with, phys_without])
				if not _check(cost_ms < 5.0, "the crowd (40 near + 40 mid + impostors) must cost < 5 ms per physics frame (got %.2f)" % cost_ms):
					return
				_sp().process_mode = Node.PROCESS_MODE_INHERIT
				_sp().set_physics_process(true)
				# danh tính: chụp mọi người nộm, tiến 45 m về phía người nộm gần nhất (dưới ngưỡng dịch chuyển 120 m)
				var sp: PedestrianSpawner = _sp()
				var c: Vector3 = _player().global_position
				snap.clear()
				var best: Vector3 = Vector3.INF
				for i: int in range(sp.impostors.count()):
					var st: Dictionary = sp.impostors.state_at(i)
					snap[int(st["wid"])] = st["identity"]
					var q: Vector3 = st["pos"]
					if best == Vector3.INF or _flat(q, c) < _flat(best, c):
						best = q
				var u: Vector3 = Vector3(best.x - c.x, 0.0, best.z - c.z).normalized()
				sp.promotions.clear()
				sp.demotions.clear()
				roam.set_meta("pool0", sp.pool_hits)
				roam.set_meta("dir_u", u)
				_teleport(c + u * 45.0)
				c_phase = "promote"
				c_t0 = c_frames
		"promote":
			if t == 120:
				var sp2: PedestrianSpawner = _sp()
				var ok: int = 0
				for e: Dictionary in sp2.promotions:
					var wid: int = int(e["wid"])
					if not snap.has(wid):
						continue
					if not _check(_same_identity(e["identity"], snap[wid]), "a promoted walker keeps its identity (wid %d)" % wid):
						return
					var found: Pedestrian = null
					for p: Pedestrian in sp2.pedestrians():
						if int(p.identity.get("wid", -1)) == wid:
							found = p
					if found == null:
						continue   # đã bị bỏ trước lúc kiểm (ngoài tầm camera khi quá mục tiêu)
					if not _check(_same_identity(found.identity, snap[wid]), "the pedestrian of promoted wid %d has the impostor's identity" % wid):
						return
					var jump: float = (e["from"] as Vector3).distance_to(e["to"] as Vector3)
					if not _check(jump < 6.5, "promotion moved walker %d by %.1f m (keep < 6.5)" % [wid, jump]):
						return
					ok += 1
				print("  promotions checked: %d (log %d)" % [ok, sp2.promotions.size()])
				if not _check(ok >= 1, "walking 45 m toward the impostors must promote at least one of them"):
					return
				c_phase = "inview_wait"
				c_t0 = c_frames
		"inview_wait":
			# đường lên tầng "trong tầm camera": cần đủ người đi đường (không còn dưới mục tiêu) trước khi thả người nộm
			if _sp().pedestrians().size() >= _sp().targets().x:
				_aim_at_walk_nodes([[40.0, 52.0]])
				c_phase = "inview_aim"
				c_t0 = c_frames
			elif t >= 900:
				_check(false, "test setup: the campus crowd never reached its target (%d / %d)" % [_sp().pedestrians().size(), _sp().targets().x])
				return
		"inview_aim":
			if t == 3:
				var spa: PedestrianSpawner = _sp()
				if spa.pedestrians().size() < spa.targets().x:
					c_phase = "inview_wait"   # vừa có người bị hạ / bỏ: chờ đủ lại
					c_t0 = c_frames
					return
				_clear_impostors_within(PedestrianSpawner.PROMOTE_R)
				var picks: Array = _view_nodes(40.0, 52.0, 4)
				if not _check(picks.size() >= 3, "test setup: need >= 3 walk nodes 40-52 m in front of the camera (got %d)" % picks.size()):
					return
				inject.clear()
				for nd: int in picks:
					var wid: int = _add_impostor(nd)
					if not _check(wid >= 0, "test setup: impostors.add() refused an impostor"):
						return
				print("  in-view: %d impostors placed 40-52 m in front of the camera, pedestrians %d / target %d" % [inject.size(), spa.pedestrians().size(), spa.targets().x])
				c_phase = "inview"
				c_t0 = c_frames
		"inview":
			if t == 90:
				var spi: PedestrianSpawner = _sp()
				var okv: int = 0
				for wid: int in inject.keys():
					var e: Dictionary = {}
					for pe: Dictionary in spi.promotions:
						if int(pe["wid"]) == wid:
							e = pe
					if not _check(not e.is_empty(), "an impostor in the camera view (wid %d) must be promoted while the crowd is at its target" % wid):
						return
					if not _check(String(e.get("via", "")) == "view", "wid %d must be promoted through the in-view path (via %s)" % [wid, e.get("via", "")]):
						return
					if not _check(_same_identity(e["identity"], inject[wid]), "an in-view promotion keeps the identity (wid %d)" % wid):
						return
					var found: Pedestrian = null
					for p: Pedestrian in spi.pedestrians():
						if int(p.identity.get("wid", -1)) == wid:
							found = p
					if not _check(found != null and _same_identity(found.identity, inject[wid]), "the pedestrian of in-view wid %d exists with the impostor's identity" % wid):
						return
					okv += 1
				print("  in-view promotions: %d of %d (via view, same identity)" % [okv, inject.size()])
				_aim_at_walk_nodes([[25.0, 55.0], [70.0, 85.0]])
				c_phase = "cap"
				c_t0 = c_frames
		"cap":
			if t == 3:
				# pool sau lần đổi khu đường -> campus (pool đầy người khu đường): phải bỏ người cũ và được dùng lại
				var spi: PedestrianSpawner = _sp()
				var hits: int = spi.pool_hits - int(roam.get_meta("pool0"))
				print("  pool after the road -> campus change: %d reuses, %d evicted, %d pooled" % [hits, spi.pool_evicted, spi._pool_order.size()])
				if not _check(hits >= 1 and spi.pool_evicted >= 1 and spi._pool_order.size() <= PedestrianSpawner.POOL_MAX, "after a zone change the pool must evict old-zone walkers (FIFO) and be reused (reuses %d, evicted %d)" % [hits, spi.pool_evicted]):
					return
				if not _cap_ok():
					return
				var u2: Vector3 = roam.get_meta("dir_u")
				_teleport(_player().global_position - u2 * 110.0)
				c_phase = "demote"
				c_t0 = c_frames
		"demote":
			if t == 60:
				var sp3: PedestrianSpawner = _sp()
				var okd: int = 0
				for e2: Dictionary in sp3.demotions:
					var w2: int = int(e2["wid"])
					var idx: int = sp3.impostors.wids().find(w2)
					if idx < 0:
						continue   # đã ra ngoài 225 m
					if not _check(_same_identity(sp3.impostors.state_at(idx)["identity"], e2["identity"]), "a demoted walker keeps its identity as an impostor (wid %d)" % w2):
						return
					okd += 1
				print("  demotions checked: %d (log %d)" % [okd, sp3.demotions.size()])
				if not _check(okd >= 1, "walking 110 m away must demote at least one pedestrian into an impostor"):
					return
				day_t = sp3.targets()
				roam.call("set_time_of_day", "night")
				c_phase = "night"
				c_t0 = c_frames
		"night":
			if t == 30:
				var sp4: PedestrianSpawner = _sp()
				var nt: Vector2i = sp4.targets()
				print("  night: targets %s (day %s), pedestrians %d, impostors %d" % [nt, day_t, sp4.pedestrians().size(), sp4.impostors.count()])
				if not _check(nt.x == maxi(1, roundi(float(day_t.x) * 0.3)) and nt.y == maxi(1, roundi(float(day_t.y) * 0.3)), "night targets are 30 %% of the day targets"):
					return
				if not _check(sp4.pedestrians().size() <= nt.x and sp4.impostors.count() <= nt.y, "switching to night trims the crowd at once"):
					return
				roam.call("set_time_of_day", "morning")
				roam.call("mount_bike")
				c_phase = "bike_hit"
				c_t0 = c_frames
		"bike_hit":
			var bike: Node3D = roam.get("bike")
			if t == 30:
				var victim: Pedestrian = _sp().pedestrians()[0]
				victim.process_mode = Node.PROCESS_MODE_INHERIT
				victim.set_far(false)
				victim.global_position = bike.global_position - bike.global_basis.z * 0.9 + Vector3(0.0, 0.05, 0.0)
				bike.set("current_speed_ms", 6.0)
				roam.set_meta("victim", victim)
			if t == 34:
				var v: Pedestrian = roam.get_meta("victim")
				var bs: float = float(bike.get("current_speed_ms"))
				print("  bike hit: pedestrian state %d, bike speed %.2f" % [v.state, bs])
				if not _check(v.state == Pedestrian.State.KNOCKDOWN and bs <= 4.8, "a bike hit must knock the pedestrian down and cost the bike 25 %% of its speed (state %d, speed %.2f)" % [v.state, bs]):
					return
				print("✅ SUCCESS: PEDESTRIANS (parts A + B + C)")
				done = true
				quit(0)


func _part_a() -> bool:
	var md: MapData = MapData.load_default()
	var t0: int = Time.get_ticks_msec()
	var g: PedWalkGraph = PedWalkGraph.build(md)
	var ms: int = Time.get_ticks_msec() - t0
	print("  walk graph: %d nodes in %d ms" % [g.node_count(), ms])
	if not _check(g.node_count() > 500, "walk graph must have > 500 nodes (got %d)" % g.node_count()):
		return false
	if not _check(ms < 1500, "walk graph build must take < 1.5 s (took %d ms)" % ms):
		return false
	var water: Array = MapBuilder._water_polygons(md)
	var bld: Array = []
	for b: Dictionary in md.buildings():
		if not MapBuilder.is_msft(b):
			bld.append(MapData.poly(b.get("outer", [])))
	var roads: Array = []
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) > 0:
			roads.append([MapData.poly(r.get("points", [])), float(r.get("width", 6.0)) * 0.5])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for n: int in range(300):
		var i: int = rng.randi_range(0, g.node_count() - 1)
		var p := Vector2(g.node_pos(i).x, g.node_pos(i).z)
		for w: PackedVector2Array in water:
			if not _check(not Geometry2D.is_point_in_polygon(p, w), "node %d %s lies in water" % [i, p]):
				return false
		for poly: PackedVector2Array in bld:
			# chỉ đường campus tự vẽ được phép nằm trong đường viền OSM (nhà campus dựng riêng bằng FPTUCampusBuilder)
			if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly) and not _campus_node(p):
				if not _check(false, "node %d %s lies inside an OSM building" % [i, p]):
					return false
		for rd: Array in roads:
			var pts: PackedVector2Array = rd[0]
			for k: int in range(pts.size() - 1):
				var d: float = Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]).distance_to(p)
				if d < float(rd[1]) - 0.05 and not _campus_node(p):
					return _check(false, "node %d %s lies on a carriageway (%.2f m from the centreline, half width %.1f)" % [i, p, d, rd[1]])
	var spawn: Vector3 = md.spawn_transform().origin
	for ring: Vector2 in [Vector2(40.0, 80.0), Vector2(95.0, 220.0)]:
		var hits: int = 0
		for n: int in range(40):
			var j: int = g.random_point_ring(spawn, ring.x, ring.y, rng)
			if j >= 0:
				var d2: float = Vector2(g.node_pos(j).x - spawn.x, g.node_pos(j).z - spawn.z).length()
				if not _check(d2 >= ring.x and d2 <= ring.y, "random_point_ring returned a node %.1f m away (%.0f..%.0f)" % [d2, ring.x, ring.y]):
					return false
				hits += 1
		if not _check(hits >= 30, "random_point_ring found nodes %.0f..%.0f m from the BE6 spawn only %d / 40 times" % [ring.x, ring.y, hits]):
			return false
	var zc: Array = [0, 0, 0]
	for i2: int in range(g.node_count()):
		var z: int = g.zone_at(i2)
		zc[z] = int(zc[z]) + 1
		if z == PedWalkGraph.ZONE_CAMPUS and not _near_campus(Vector2(g.node_pos(i2).x, g.node_pos(i2).z)):
			return _check(false, "campus-zone node %d lies more than 60 m from the campus plot" % i2)
	print("  zones: campus %d, residential %d, road %d" % zc)
	if not _check(int(zc[0]) >= 50 and int(zc[1]) >= 50 and int(zc[2]) >= 50, "every zone needs >= 50 nodes (campus %d, residential %d, road %d)" % zc):
		return false
	var ns: int = g.nearest(spawn, 60.0)
	if not _check(ns >= 0 and g.zone_at(ns) == PedWalkGraph.ZONE_RESIDENTIAL, "the BE6 spawn must lie in the residential zone (nearest node %d)" % ns):
		return false
	var plaza: int = _be6_ring_nodes(g, md)
	print("  BE6 plaza ring: %d nodes" % plaza)
	if not _check(plaza >= 12, "the BE6 plaza ring must add >= 12 walk nodes 4-8 m outside the tower (got %d)" % plaza):
		return false
	var deg2: int = -1
	for i: int in range(g.node_count()):
		if g.neighbours(i).size() >= 2:
			deg2 = i
			break
	var a: int = int(g.neighbours(deg2)[0])
	for n: int in range(10):
		var nxt: int = g.next_node(deg2, a, rng)
		if not _check(nxt != a and g.neighbours(deg2).has(nxt), "next_node must pick a neighbour other than came_from"):
			return false
	if not _check(_campus_reaches_street(g), "the campus path network must reach a street node outside the plot (gates / links)"):
		return false
	var keep: int = g.neighbours(deg2).size()
	var t1: int = Time.get_ticks_msec()
	var g2: PedWalkGraph = PedWalkGraph.build(md)
	var ms2: int = Time.get_ticks_msec() - t1
	print("  cached rebuild: %d ms" % ms2)
	if not _check(ms2 < 200 and g2.node_count() == g.node_count(), "a second build must come from the cache (%d ms, %d nodes)" % [ms2, g2.node_count()]):
		return false
	g2.block_near([g2.node_pos(deg2)], 3.0)
	return _check(g2.neighbours(deg2).is_empty() and g.neighbours(deg2).size() == keep, "block_near on one copy must not cut another copy or the cache")


## Thành phần liên thông chứa một nút trong lô campus có tới được nút ngoài lô không; in số thành phần / nút bậc 0 theo khu.
func _campus_reaches_street(g: PedWalkGraph) -> bool:
	var comp := PackedInt32Array()
	comp.resize(g.node_count())
	comp.fill(-1)
	var sizes: Array[int] = []
	for s: int in range(g.node_count()):
		if comp[s] >= 0:
			continue
		var cid: int = sizes.size()
		var stack: Array[int] = [s]
		comp[s] = cid
		var n: int = 0
		while not stack.is_empty():
			var v: int = stack.pop_back()
			n += 1
			for w: int in g.neighbours(v):
				if comp[w] < 0:
					comp[w] = cid
					stack.append(w)
		sizes.append(n)
	var deg0: Array[int] = [0, 0, 0]
	for i: int in range(g.node_count()):
		if g.neighbours(i).is_empty():
			deg0[g.zone_at(i)] += 1
	var big: Array[int] = sizes.duplicate()
	big.sort()
	big.reverse()
	var campus_comp: int = -1
	for i2: int in range(g.node_count()):
		if _campus_node(Vector2(g.node_pos(i2).x, g.node_pos(i2).z)) and not g.neighbours(i2).is_empty():
			campus_comp = comp[i2]
			break
	var reaches: bool = false
	for i3: int in range(g.node_count()):
		if comp[i3] == campus_comp and not _campus_node(Vector2(g.node_pos(i3).x, g.node_pos(i3).z)):
			reaches = true
			break
	print("  components: %d (largest %s), campus component %d nodes, degree-0 campus/residential/road %s, closed loops %d" % [
		sizes.size(), str(big.slice(0, 4)), sizes[campus_comp] if campus_comp >= 0 else 0, str(deg0), g.closed_lines])
	return reaches


func _campus_node(p: Vector2) -> bool:
	var local: Vector3 = FPTUCampusBuilder.real_plot_transform().affine_inverse() * Vector3(p.x, 0.0, p.y)
	return FPTUCampusBuilder.plot_rect().grow(3.0).has_point(Vector2(local.x, local.z))


func _near_campus(p: Vector2) -> bool:
	var local: Vector3 = FPTUCampusBuilder.real_plot_transform().affine_inverse() * Vector3(p.x, 0.0, p.y)
	return FPTUCampusBuilder.plot_rect().grow(PedWalkGraph.CAMPUS_NEAR_M + 1.0).has_point(Vector2(local.x, local.z))


## Số nút cách đường viền toà BE6 từ 4 tới 8 m (vòng quảng trường dời 6 m ra ngoài).
func _be6_ring_nodes(g: PedWalkGraph, md: MapData) -> int:
	var be6: PackedVector2Array = MapData.poly(md.landmark("be6_outer"))
	var box := Rect2(be6[0], Vector2.ZERO)
	for q: Vector2 in be6:
		box = box.expand(q)
	box = box.grow(10.0)
	var n: int = 0
	for i: int in range(g.node_count()):
		var p := Vector2(g.node_pos(i).x, g.node_pos(i).z)
		if not box.has_point(p) or Geometry2D.is_point_in_polygon(p, be6):
			continue
		var d: float = INF
		for k: int in range(be6.size()):
			d = minf(d, Geometry2D.get_closest_point_to_segment(p, be6[k], be6[(k + 1) % be6.size()]).distance_to(p))
		if d > 4.0 and d < 8.0:
			n += 1
	return n


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
