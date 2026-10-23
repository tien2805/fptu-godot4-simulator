# File: res://scripts/roam/RoamTraffic.gd
# Xe chạy trong FreeRoam (spec vice-people-and-movement, "Amendment 2026-10-22"): mặc định 25 xe ban ngày (đêm 30 %) –
# xe máy có người lái bake (người PS2 ở Vice City), vài ô tô và xe buýt – chạy theo làn bên phải lòng đường MapData
# (lanes > 0; bỏ đường nội bộ "service", cầu và lô campus), xuất hiện cách người chơi 40-150 m (ngoài tầm camera trước),
# ra ngoài 200 m thì cất đi rồi dùng lại thân xe ở chỗ khác (không dựng lại). Hết làn thì rẽ sang một làn đi ngang trong
# 9 m (đường cong Bezier bậc hai, 60 % tốc độ), không có thì quay đầu sang làn kia của chính đường đó, không có nữa thì lấy
# ứng viên bị loại tốt nhất (ngược chiều gắt / gần hết làn), không có nữa thì cất xe. Nhìn trước: giảm tốc và dừng cách
# STOP_GAP sau xe khác, người đi đường, người chơi hoặc xe người chơi (kích thước vật cản theo hướng của nó). Hàng xe nối
# đuôi chỉ chờ; chỉ vòng xe chờ nhau (kẹt ngã tư) mới bỏ qua xe khác 2 s; chờ người / xe người chơi quá STUCK_S mà ngoài
# tầm camera thì cất xe. Chỗ xuất hiện tránh xe khác, người đi đường, người chơi và xe người chơi. Thân AnimatableBody3D
# nhóm "traffic_obstacle" (xe buýt thêm "slipstream_vehicle"): PlayerBike tông vào thì dùng xử lý va chạm sẵn có. Không
# dùng autoload ở đây.
class_name RoamTraffic
extends Node3D

enum Kind { MOTO, CAR, BUS }

const KIND_COUNT: Array[int] = [20, 3, 2]          # mặc định: 20 xe máy, 3 ô tô, 2 xe buýt
const KIND_SIZE: Array = [Vector3(0.7, 1.4, 1.9), Vector3(1.7, 1.5, 3.9), Vector3(2.5, 3.0, 7.5)]
const NIGHT_FACTOR: float = 0.3
const SPAWN_MIN: float = 40.0
const SPAWN_MAX: float = 150.0
const INITIAL_MIN: float = 20.0
const DESPAWN: float = 200.0
const LANE_STEP: float = 6.0
const MIN_LANE_LEN: float = 15.0
const EXIT_R: float = 9.0
const EXIT_MIN_LEFT: float = 8.0
const TURN_R: float = 4.0                         # rẽ bắt đầu ~TURN_R m trước điểm vào, vào làn mới TURN_R / 2 m sau nó
const PLOT_GROW: float = 3.0
const SEG_CELL: float = 16.0
const SPAWN_CELL: float = 32.0
const SPAWN_STEP: float = 10.0
const SPAWN_END_CLEAR: float = 8.0
const SPAWN_GAP: float = 14.0
const SPAWN_PEOPLE_GAP: float = 10.0               # chỗ xuất hiện: không người / xe người chơi trong 10 m trước mũi xe
const FALLBACK_SHORT: float = 100.0               # phạt xếp hạng lối ra dự phòng vào làn còn < EXIT_MIN_LEFT m
const WAIT_CHAIN: int = 8                         # số bước tối đa dò chuỗi xe chờ nhau tìm vòng kẹt
const SPAWNS_PER_CHECK: int = 3
const CHECK_EVERY: float = 0.5
const LOOK_EVERY: int = 3
const LOOK_BASE: float = 6.0
const LOOK_PER_MS: float = 1.6
const LAT_PAD: float = 0.5
const STOP_GAP: float = 3.0
const ACCEL: float = 2.5
const BRAKE: float = 7.0
const TURN_FACTOR: float = 0.6
const STUCK_S: float = 5.0
const GHOST_S: float = 2.0
const VIEW_R: float = 160.0
const SPEED_BY_CLASS: Dictionary = {"motorway": 13.0, "primary": 11.0, "secondary": 10.0, "tertiary": 9.0}
const SPEED_DEFAULT: float = 6.5
const BUS_CLASSES: Array[String] = ["motorway", "primary", "secondary", "tertiary"]
const CAR_PAINTS: Array[Color] = [Color("#F4A6C0"), Color("#7FD8D2"), Color("#FFF1B5"), Color("#AFCBFF"), Color("#F2F4F5"), Color("#3A3F44"), Color("#E57373")]
const HELMETS: Array[Color] = [Color("#E74C3C"), Color("#F1C40F"), Color("#FFFFFF"), Color("#0984E3"), Color("#2C3E50")]


class Vehicle:
	var body: AnimatableBody3D
	var idx: int = 0                     # chỉ số trong vehicles
	var kind: int = 0
	var lane: int = -1
	var s: float = 0.0
	var speed: float = 0.0
	var cruise: float = 8.0
	var limit: float = 99.0
	var half_len: float = 1.0
	var half_w: float = 0.4
	var exit: Array = []                 # lối ra đã chọn của làn hiện tại: [làn, s_vào, back]
	var turn_at: float = 0.0             # s bắt đầu rẽ = độ dài làn - back
	var conn: PackedVector2Array = PackedVector2Array()   # Bezier bậc hai [p0, điểm điều khiển, p2] khi đang rẽ
	var conn_t: float = 0.0
	var conn_len: float = 1.0
	var next_lane: int = -1
	var next_s: float = 0.0
	var active: bool = false
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2(0.0, -1.0)
	var blocked_by: String = ""      # "car" | "ped" | "player" | "bike" | ""
	var blocker: int = -1            # chỉ số xe đang chặn (blocked_by "car"), -1 = không (chỉ số, không giữ tham chiếu vòng)
	var stuck_t: float = 0.0
	var ghost_t: float = 0.0


var md: MapData
var player: Node3D
var bike: Node3D
var roam: Node
var peds_fn: Callable
var vehicles: Array = []                 # Array[Vehicle]
var lane_pts: Array = []                 # Array[PackedVector2Array]
var lane_cum: Array = []                 # Array[PackedFloat32Array] (độ dài cộng dồn tại mỗi đỉnh)
var lane_len := PackedFloat32Array()
var lane_speed := PackedFloat32Array()
var lane_kinds := PackedByteArray()      # bit 1 << Kind
var lane_road := PackedInt32Array()
var lane_exits: Array = []               # Array của Array[[lane, s]]
var recycled: int = 0
var night: bool = false
var _spawn_hash: Dictionary = {}         # Vector2i -> Array[[lane, s]]
var _rng := RandomNumberGenerator.new()
var _check_t: float = 0.0
var _frame: int = 0
var _rot: int = 0


func setup(map_data: MapData, player_node: Node3D, opts: Dictionary = {}) -> void:
	md = map_data
	player = player_node
	bike = opts.get("bike", null)
	roam = opts.get("roam", null)
	peds_fn = opts.get("peds_fn", Callable())
	_rng.seed = int(opts.get("seed", 77))
	_build_lanes(opts.get("plot", _campus_plot()))
	if lane_pts.is_empty():
		push_warning("RoamTraffic: không có làn xe nào, tắt xe chạy")
		set_physics_process(false)
		return
	var kinds: Array = opts.get("kinds", [])
	if kinds.is_empty():
		for k: int in range(KIND_COUNT.size()):
			for i: int in range(KIND_COUNT[k]):
				kinds.append(k)
	for kind: Variant in kinds:
		vehicles.append(_make_vehicle(int(kind)))
	night = _is_night()
	_fill_initial()


func bodies() -> Array:
	return vehicles.map(func(v: Vehicle) -> AnimatableBody3D: return v.body)


func active_count() -> int:
	return vehicles.filter(func(v: Vehicle) -> bool: return v.active).size()


func lane_count() -> int:
	return lane_pts.size()


static func _campus_plot() -> PackedVector2Array:
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var pr: Rect2 = FPTUCampusBuilder.plot_rect().grow(PLOT_GROW)
	var out := PackedVector2Array()
	for c: Vector2 in [pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]:
		var w: Vector3 = xf * Vector3(c.x, 0.0, c.y)
		out.append(Vector2(w.x, w.z))
	return out


# ===========================================================================
# XE
# ===========================================================================
func _make_vehicle(kind: int) -> Vehicle:
	var c := Vehicle.new()
	c.idx = vehicles.size()
	c.kind = kind
	var size: Vector3 = KIND_SIZE[kind]
	c.half_len = size.z * 0.5
	c.half_w = size.x * 0.5
	var b := AnimatableBody3D.new()
	b.name = "Vehicle_%d" % vehicles.size()
	b.add_to_group("traffic_obstacle")
	if kind == Kind.BUS:
		b.add_to_group("slipstream_vehicle")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	b.add_child(cs)
	match kind:
		Kind.MOTO:
			var paint: Color = FPTUCampusBuilder.BIKE_PAINTS[_rng.randi() % FPTUCampusBuilder.BIKE_PAINTS.size()]
			PropBuilder.build_scooter(b, Vector3.ZERO, 0.0, paint, {"baked": true, "name": "Scooter"})
			var ro: Dictionary = {"seed": _rng.randi(), "helmet_color": HELMETS[_rng.randi() % HELMETS.size()]}
			if _rng.randf() < 0.3:
				ro["backpack"] = true
			CharacterBuilder.build_baked_rider(b, Vector3(0.0, 0.32, 0.12), ro)
		Kind.CAR:
			PropBuilder.build_car(b, CAR_PAINTS[_rng.randi() % CAR_PAINTS.size()], true)
		Kind.BUS:
			PropBuilder.build_bus(b, _rng.randf() < 0.5, true)
	add_child(b)
	c.body = b
	_park(c)
	return c


## Cất xe: ẩn, tắt xử lý (thân bị gỡ khỏi không gian vật lý), đặt xa dưới đất.
func _park(c: Vehicle) -> void:
	c.active = false
	c.speed = 0.0
	c.blocked_by = ""
	c.blocker = -1
	c.body.visible = false
	c.body.process_mode = Node.PROCESS_MODE_DISABLED
	c.body.position = Vector3(0.0, -200.0, 0.0)


func _activate(c: Vehicle, l: int, s: float) -> void:
	c.lane = l
	c.s = s
	c.conn = PackedVector2Array()
	_choose_exit(c)
	var f: float = _rng.randf_range(0.85, 1.15) if c.kind == Kind.MOTO else (_rng.randf_range(0.9, 1.05) if c.kind == Kind.CAR else 0.8)
	c.cruise = lane_speed[l] * f
	c.speed = c.cruise * 0.6
	c.limit = 99.0
	c.stuck_t = 0.0
	c.ghost_t = 0.0
	c.blocked_by = ""
	c.blocker = -1
	c.active = true
	c.body.process_mode = Node.PROCESS_MODE_INHERIT
	c.body.visible = true
	_place(c, 1.0)


func _fill_initial() -> void:
	var c3: Vector3 = _center()
	var c2 := Vector2(c3.x, c3.z)
	var target: int = roundi(float(vehicles.size()) * (NIGHT_FACTOR if night else 1.0))
	var active: int = 0
	var people: Array = []
	_append_people(people)
	for c: Vehicle in vehicles:
		if active >= target:
			break
		var spot: Array = _random_spot(c2, INITIAL_MIN, SPAWN_MAX, c.kind, false, people)
		if spot.is_empty():
			continue
		_activate(c, int(spot[0]), float(spot[1]))
		active += 1


## Mỗi CHECK_EVERY: cất xe ra ngoài DESPAWN, đêm thì cất xe xa nhất cho còn 30 %, thiếu thì đưa xe đang cất ra (tối đa
## SPAWNS_PER_CHECK, xoay vòng điểm bắt đầu để mọi loại xe đều được dùng).
func _maintain() -> void:
	var c3: Vector3 = _center()
	var c2 := Vector2(c3.x, c3.z)
	night = _is_night()
	var target: int = roundi(float(vehicles.size()) * (NIGHT_FACTOR if night else 1.0))
	var live: Array = []
	for c: Vehicle in vehicles:
		if not c.active:
			continue
		if c.pos.distance_to(c2) > DESPAWN:
			_park(c)
			recycled += 1
		else:
			live.append(c)
	if live.size() > target:
		live.sort_custom(func(a: Vehicle, b: Vehicle) -> bool: return a.pos.distance_to(c2) > b.pos.distance_to(c2))
		for i: int in range(live.size() - target):
			_park(live[i])
			recycled += 1
		return
	var n: int = vehicles.size()
	var active: int = live.size()
	var made: int = 0
	var people: Array = []
	if active < target:
		_append_people(people)
	for k: int in range(n):
		if active >= target or made >= SPAWNS_PER_CHECK:
			break
		var c: Vehicle = vehicles[(_rot + k) % n]
		if c.active:
			continue
		var spot: Array = _random_spot(c2, SPAWN_MIN, SPAWN_MAX, c.kind, true, people)
		if spot.is_empty():
			continue
		_activate(c, int(spot[0]), float(spot[1]))
		active += 1
		made += 1
	_rot = (_rot + 7) % maxi(1, n)


func _physics_process(delta: float) -> void:
	_frame += 1
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = CHECK_EVERY
		_maintain()
	var obs: Array = []
	var gathered: bool = false
	for i: int in range(vehicles.size()):
		var c: Vehicle = vehicles[i]
		if not c.active:
			continue
		if (_frame + i) % LOOK_EVERY == 0:
			if not gathered:
				obs = _obstacles()
				gathered = true
			c.limit = _look_ahead(c, obs)
		var target: float = minf(c.cruise * (TURN_FACTOR if c.conn.size() == 3 else 1.0), c.limit)
		c.speed = move_toward(c.speed, target, (ACCEL if target > c.speed else BRAKE) * delta)
		if c.speed < 0.2 and _held(c):
			c.stuck_t += delta
			if c.stuck_t > STUCK_S:
				if c.blocked_by == "car":
					c.ghost_t = GHOST_S       # vòng xe chờ nhau ở ngã tư: bỏ qua xe khác 2 s (vẫn dừng trước người)
					c.stuck_t = 0.0
				elif not _in_view(Vector3(c.pos.x, 1.0, c.pos.y)):
					_park(c)                  # chờ người / xe người chơi quá lâu, ngoài tầm camera: cất xe
					recycled += 1
					continue
		else:
			c.stuck_t = 0.0
		c.ghost_t = maxf(0.0, c.ghost_t - delta)
		_advance(c, c.speed * delta)
		if c.active:
			_place(c, delta)


## Vật cản cho nhìn trước: [vị trí, nửa dài, nửa rộng, loại, xe, hướng]; hướng ZERO = vật cản tròn bán kính nửa dài.
func _obstacles() -> Array:
	var out: Array = []
	for c: Vehicle in vehicles:
		if c.active:
			out.append([c.pos, c.half_len, c.half_w, "car", c, c.dir])
	_append_people(out)
	return out


## Vật cản không phải xe: người đi đường, người chơi (đi bộ; khi đang lái là xe người chơi), xe người chơi đang đỗ.
func _append_people(out: Array) -> void:
	if peds_fn.is_valid():
		for p: Variant in peds_fn.call():
			if is_instance_valid(p) and (p as Node3D).is_inside_tree():
				var pn: Node3D = p
				out.append([Vector2(pn.global_position.x, pn.global_position.z), 0.3, 0.3, "ped", null, Vector2.ZERO])
	var mounted: bool = roam != null and bool(roam.get("mounted"))
	var who: Node3D = bike if mounted else player
	if who != null and who.is_inside_tree():
		out.append([Vector2(who.global_position.x, who.global_position.z), 1.0 if mounted else 0.4, 0.45 if mounted else 0.4, "player", null, _heading(who) if mounted else Vector2.ZERO])
	if not mounted and bike != null and bike.visible and bike.is_inside_tree():
		out.append([Vector2(bike.global_position.x, bike.global_position.z), 1.0, 0.45, "bike", null, _heading(bike)])   # xe người chơi đang đỗ


## Hướng mặt trước (-Z) của nút trên mặt phẳng (x, z).
static func _heading(n: Node3D) -> Vector2:
	var z: Vector3 = n.global_transform.basis.z
	var h := Vector2(-z.x, -z.z)
	return h.normalized() if h.length_squared() > 0.0001 else Vector2(0.0, -1.0)


## Xe đứng chờ có tính giờ kẹt không: chờ người / xe người chơi thì có; chờ xe khác chỉ khi chuỗi xe chờ nhau quay về chính
## nó (kẹt vòng ở ngã tư). Hàng xe nối đuôi thường (chuỗi dừng ở một xe đang chạy / một người) không tính, nên xe sau không
## bao giờ bỏ qua xe trước mà chồng lên nó.
func _held(c: Vehicle) -> bool:
	if c.blocked_by == "ped" or c.blocked_by == "player" or c.blocked_by == "bike":
		return true
	if c.blocked_by != "car":
		return false
	var b: int = c.blocker
	for k: int in range(WAIT_CHAIN):
		if b < 0:
			return false
		var o: Vehicle = vehicles[b]
		if o == c:
			return true
		if not o.active or o.blocked_by != "car":
			return false
		b = o.blocker
	return false


## Tốc độ cho phép theo khoảng hở tới vật cản gần nhất trong dải phía trước (dừng hẳn khi khe <= STOP_GAP). Vật cản có
## hướng (xe, xe người chơi) chiếm theo hình chữ nhật xoay: xe buýt đi ngang chắn bằng nửa dài 3,75 m chứ không phải nửa rộng.
func _look_ahead(c: Vehicle, obs: Array) -> float:
	var look: float = LOOK_BASE + c.speed * LOOK_PER_MS
	if c.conn.size() != 3 and not c.exit.is_empty():
		look = minf(look, maxf(c.turn_at - c.s, 0.0) + LOOK_BASE)   # sắp rẽ: không nhìn thẳng qua ngã tư tới lề bên kia
	var reach2: float = (look + 8.0) * (look + 8.0)
	var best: float = INF
	c.blocked_by = ""
	c.blocker = -1
	for o: Array in obs:
		if o[4] == c or (c.ghost_t > 0.0 and String(o[3]) == "car"):
			continue
		var rel: Vector2 = (o[0] as Vector2) - c.pos
		if rel.length_squared() > reach2:
			continue
		var fwd: float = rel.dot(c.dir)
		if fwd <= 0.0:
			continue
		var u: Vector2 = o[5]
		var ud: float = 1.0           # |hướng vật cản · hướng xe|, vật cản tròn: 1
		var uc: float = 0.0           # |hướng vật cản x hướng xe|, vật cản tròn: 0
		if u != Vector2.ZERO:
			ud = absf(u.dot(c.dir))
			uc = absf(u.cross(c.dir))
		var gap: float = fwd - c.half_len - (float(o[1]) * ud + float(o[2]) * uc)
		if gap > look:
			continue
		if absf(rel.cross(c.dir)) > c.half_w + float(o[1]) * uc + float(o[2]) * ud + LAT_PAD:
			continue
		if gap < best:
			best = gap
			c.blocked_by = String(o[3])
			c.blocker = (o[4] as Vehicle).idx if o[4] != null else -1
	if best == INF:
		return 99.0
	if best <= STOP_GAP:
		return 0.0
	return sqrt(BRAKE * (best - STOP_GAP))


func _advance(c: Vehicle, dist: float) -> void:
	if c.conn.size() == 3:
		c.conn_t += dist / c.conn_len
		if c.conn_t < 1.0:
			return
		dist = (c.conn_t - 1.0) * c.conn_len
		c.lane = c.next_lane
		c.s = c.next_s
		c.conn = PackedVector2Array()
		_choose_exit(c)
	var s0: float = c.s
	c.s += dist
	if c.s < c.turn_at:
		return
	if c.exit.is_empty():
		_park(c)
		recycled += 1
		return
	var ts: float = maxf(c.turn_at, s0)   # vào làn đã quá điểm bắt đầu rẽ (lối ra dự phòng vào gần cuối làn): rẽ ngay, không lùi
	var over: float = c.s - ts
	var nl: int = int(c.exit[0])
	var ns: float = float(c.exit[1])
	var p0: Vector2 = _lane_point(c.lane, ts)
	var d0: Vector2 = _lane_dir(c.lane, ts)
	var p2: Vector2 = _lane_point(nl, ns)
	var d2: Vector2 = _lane_dir(nl, ns)
	var chord: float = p0.distance_to(p2)
	var ctrl: Vector2 = p0 + d0 * chord * 0.5
	var den: float = d0.cross(d2)
	if absf(den) > 0.2:
		var a: float = (p2 - p0).cross(d2) / den   # giao của tia ra (p0, d0) và tia vào (p2, -d2)
		if a > 0.0 and a < chord * 1.5:
			ctrl = p0 + d0 * a
	c.conn = PackedVector2Array([p0, ctrl, p2])
	c.conn_len = maxf(0.5, (chord + p0.distance_to(ctrl) + ctrl.distance_to(p2)) * 0.5)
	c.conn_t = over / c.conn_len
	c.next_lane = nl
	c.next_s = ns


## Chọn lối ra của làn vừa vào (theo loại xe); rẽ bắt đầu ở turn_at = độ dài làn - back (không có lối ra: cuối làn).
func _choose_exit(c: Vehicle) -> void:
	c.exit = _pick_exit(c)
	c.turn_at = lane_len[c.lane] - (float(c.exit[2]) if not c.exit.is_empty() else 0.0)


func _pick_exit(c: Vehicle) -> Array:
	var opts: Array = []
	for ex: Array in lane_exits[c.lane]:
		if lane_kinds[int(ex[0])] & (1 << c.kind):
			opts.append(ex)
	if opts.is_empty():
		return []
	return opts[_rng.randi_range(0, opts.size() - 1)]


func _place(c: Vehicle, delta: float) -> void:
	if c.conn.size() == 3:
		var t: float = clampf(c.conn_t, 0.0, 1.0)
		var u: float = 1.0 - t
		c.pos = c.conn[0] * u * u + c.conn[1] * 2.0 * u * t + c.conn[2] * t * t
		var dv: Vector2 = (c.conn[1] - c.conn[0]) * 2.0 * u + (c.conn[2] - c.conn[1]) * 2.0 * t
		if dv.length_squared() > 0.0001:
			c.dir = dv.normalized()
	else:
		c.pos = _lane_point(c.lane, c.s)
		c.dir = _lane_dir(c.lane, c.s)
	var yaw: float = lerp_angle(c.body.rotation.y, atan2(-c.dir.x, -c.dir.y), minf(1.0, delta * 10.0))
	c.body.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(c.pos.x, MapBuilder.ROAD_Y, c.pos.y))


# ===========================================================================
# LÀN XE
# ===========================================================================
func _build_lanes(plot: PackedVector2Array) -> void:
	var road_i: int = 0
	for r: Dictionary in md.roads():
		road_i += 1
		var cls: String = String(r.get("class", ""))
		if int(r.get("lanes", 2)) <= 0 or bool(r.get("bridge", false)) or cls == "service":
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts.size() < 2:
			continue
		cls = String(MapBuilder.CLASS_ALIAS.get(cls, cls))
		var w: float = float(r.get("width", 6.0))
		var sp: float = float(SPEED_BY_CLASS.get(cls, SPEED_DEFAULT))
		var kinds: int = 1 << Kind.MOTO
		if w >= 6.0:
			kinds |= 1 << Kind.CAR
		if w >= 7.0 and BUS_CLASSES.has(cls):
			kinds |= 1 << Kind.BUS
		if bool(r.get("oneway", false)):
			_add_lane(pts, plot, sp, kinds, road_i)
		else:
			_add_lane(PedWalkGraph._offset(pts, w * 0.25), plot, sp, kinds, road_i)
			var rev: PackedVector2Array = pts.duplicate()
			rev.reverse()
			_add_lane(PedWalkGraph._offset(rev, w * 0.25), plot, sp, kinds, road_i)
	_link_lanes()
	_index_spawn_points()


## Lấy mẫu làn mỗi LANE_STEP m, cắt làn ở chỗ đi vào lô campus (mỗi đoạn ngoài lô thành một làn riêng).
func _add_lane(pts: PackedVector2Array, plot: PackedVector2Array, speed: float, kinds: int, road: int) -> void:
	var piece := PackedVector2Array()
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n: int = maxi(1, ceili(a.distance_to(b) / LANE_STEP))
		for k: int in range(0 if i == 0 else 1, n + 1):
			var p: Vector2 = a.lerp(b, float(k) / float(n))
			if plot.size() >= 3 and Geometry2D.is_point_in_polygon(p, plot):
				_commit_lane(piece, speed, kinds, road)
				piece = PackedVector2Array()
				continue
			piece.append(p)
	_commit_lane(piece, speed, kinds, road)


func _commit_lane(piece: PackedVector2Array, speed: float, kinds: int, road: int) -> void:
	if piece.size() < 2:
		return
	var cum := PackedFloat32Array([0.0])
	for i: int in range(1, piece.size()):
		cum.append(cum[i - 1] + piece[i - 1].distance_to(piece[i]))
	if cum[cum.size() - 1] < MIN_LANE_LEN:
		return
	lane_pts.append(piece)
	lane_cum.append(cum)
	lane_len.append(cum[cum.size() - 1])
	lane_speed.append(speed)
	lane_kinds.append(kinds)
	lane_road.append(road)


## Lối ra ở cuối mỗi làn: làn khác (khác đường) đi ngang trong EXIT_R, điểm vào còn >= EXIT_MIN_LEFT m, không ngược chiều
## gắt; không có thì quay đầu sang đầu làn kia của chính đường đó (ngõ cụt, mép lô campus); không có nữa thì lấy ứng viên bị
## loại gần nhất (ưu tiên loại vì ngược chiều hơn loại vì gần hết làn: đường một chiều, mép bản đồ). Mỗi lối ra [làn, s_vào, back]:
## rẽ bắt đầu back = TURN_R - (q - e)·hướng m trước cuối làn (rẽ phải ở ngã tư: q nằm SAU cuối làn vì làn OSM dừng ở tâm
## giao lộ) và vào làn mới TURN_R / 2 m sau q, nên đường cong luôn đi tới.
func _link_lanes() -> void:
	var seg_hash: Dictionary = {}
	for l: int in range(lane_pts.size()):
		var pts: PackedVector2Array = lane_pts[l]
		for i: int in range(pts.size() - 1):
			var bb := Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1])
			for cx: int in range(floori(bb.position.x / SEG_CELL), floori(bb.end.x / SEG_CELL) + 1):
				for cz: int in range(floori(bb.position.y / SEG_CELL), floori(bb.end.y / SEG_CELL) + 1):
					var key := Vector2i(cx, cz)
					if not seg_hash.has(key):
						seg_hash[key] = []
					(seg_hash[key] as Array).append(Vector2i(l, i))
	var reach: int = ceili(EXIT_R / SEG_CELL)
	for l: int in range(lane_pts.size()):
		var pts: PackedVector2Array = lane_pts[l]
		var e: Vector2 = pts[pts.size() - 1]
		var de: Vector2 = (e - pts[pts.size() - 2]).normalized()
		var best: Dictionary = {}     # làn -> [s_vào, khoảng cách, back]
		var uturn: Array = []
		var fallback: Array = []      # ứng viên bị loại tốt nhất [làn, s_vào, back, hạng]; hạng = khoảng cách (+ phạt gần hết làn)
		var c0 := Vector2i(floori(e.x / SEG_CELL), floori(e.y / SEG_CELL))
		for dx: int in range(-reach, reach + 1):
			for dz: int in range(-reach, reach + 1):
				for li: Vector2i in seg_hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
					var m: int = li.x
					if m == l:
						continue
					var mp: PackedVector2Array = lane_pts[m]
					var a: Vector2 = mp[li.y]
					var b: Vector2 = mp[li.y + 1]
					var q: Vector2 = Geometry2D.get_closest_point_to_segment(e, a, b)
					var d: float = q.distance_to(e)
					if d > EXIT_R:
						continue
					var back: float = clampf(TURN_R - (q - e).dot(de), 0.0, maxf(0.0, lane_len[l] - 1.0))
					var s: float = float((lane_cum[m] as PackedFloat32Array)[li.y]) + a.distance_to(q)
					var s_in: float = minf(s + TURN_R * 0.5, lane_len[m] - 1.0)
					if lane_road[m] == lane_road[l]:
						if li.y == 0 and uturn.is_empty():
							uturn = [m, s_in, back]
						continue
					var short: bool = lane_len[m] - s < EXIT_MIN_LEFT
					if short or de.dot((b - a).normalized()) < -0.3:
						var rank: float = d + (FALLBACK_SHORT if short else 0.0)
						if fallback.is_empty() or rank < float(fallback[3]):
							fallback = [m, s_in, back, rank]
						continue
					if not best.has(m) or d < float((best[m] as Array)[1]):
						best[m] = [s_in, d, back]
		var ex: Array = []
		for m: int in best.keys():
			var bm: Array = best[m]
			ex.append([m, float(bm[0]), float(bm[2])])
		if ex.is_empty() and not uturn.is_empty():
			ex.append(uturn)
		if ex.is_empty() and not fallback.is_empty():
			ex.append([int(fallback[0]), float(fallback[1]), float(fallback[2])])   # đừng biến mất ở cuối làn
		lane_exits.append(ex)


func _index_spawn_points() -> void:
	for l: int in range(lane_pts.size()):
		var s: float = 0.0
		while s < lane_len[l] - SPAWN_END_CLEAR:
			var p: Vector2 = _lane_point(l, s)
			var key := Vector2i(floori(p.x / SPAWN_CELL), floori(p.y / SPAWN_CELL))
			if not _spawn_hash.has(key):
				_spawn_hash[key] = []
			(_spawn_hash[key] as Array).append([l, s])
			s += SPAWN_STEP


func _seg_at(l: int, s: float) -> int:
	var cum: PackedFloat32Array = lane_cum[l]
	return clampi(cum.bsearch(s, true) - 1, 0, cum.size() - 2)


func _lane_point(l: int, s: float) -> Vector2:
	var pts: PackedVector2Array = lane_pts[l]
	var cum: PackedFloat32Array = lane_cum[l]
	var i: int = _seg_at(l, s)
	var seg: float = maxf(cum[i + 1] - cum[i], 0.001)
	return pts[i].lerp(pts[i + 1], clampf((s - cum[i]) / seg, 0.0, 1.0))


func _lane_dir(l: int, s: float) -> Vector2:
	var pts: PackedVector2Array = lane_pts[l]
	var i: int = _seg_at(l, s)
	return (pts[i + 1] - pts[i]).normalized()


## Chỗ xuất hiện ngẫu nhiên [làn, s] cách c2 từ r_min tới r_max (rải đều theo diện tích qua ô băm điểm mẫu), làn cho
## phép loại xe, cách xe đang chạy SPAWN_GAP, không người (people: vật cản _append_people) trong dải xe sẽ chiếm / phanh tới
## (_clear_of_people); avoid_view: 12 lần thử đầu bỏ chỗ trong tầm camera.
func _random_spot(c2: Vector2, r_min: float, r_max: float, kind: int, avoid_view: bool, people: Array = []) -> Array:
	for k: int in range(16):
		var ang: float = _rng.randf() * TAU
		var r: float = sqrt(_rng.randf_range(r_min * r_min, r_max * r_max))
		var q: Vector2 = c2 + Vector2(cos(ang), sin(ang)) * r
		var cell: Array = _spawn_hash.get(Vector2i(floori(q.x / SPAWN_CELL), floori(q.y / SPAWN_CELL)), [])
		if cell.is_empty():
			continue
		var cand: Array = cell[_rng.randi_range(0, cell.size() - 1)]
		var l: int = int(cand[0])
		if not (lane_kinds[l] & (1 << kind)):
			continue
		var p: Vector2 = _lane_point(l, float(cand[1]))
		var d: float = p.distance_to(c2)
		if d < r_min or d > r_max or not _clear_of_vehicles(p, SPAWN_GAP) or not _clear_of_people(people, p, _lane_dir(l, float(cand[1])), kind):
			continue
		if avoid_view and k < 12 and _in_view(Vector3(p.x, 1.0, p.y)):
			continue
		return [l, float(cand[1])]
	return []


func _clear_of_vehicles(p: Vector2, r: float) -> bool:
	for c: Vehicle in vehicles:
		if c.active and c.pos.distance_to(p) < r:
			return false
	return true


## Không người nào (vật cản _append_people, coi như tròn bán kính nửa dài) trong dải xe loại kind sẽ chiếm khi xuất hiện ở p
## theo hướng làn d: từ sau đuôi 1 m tới trước mũi SPAWN_PEOPLE_GAP m, rộng như dải nhìn trước (người trên vỉa hè không tính).
func _clear_of_people(people: Array, p: Vector2, d: Vector2, kind: int) -> bool:
	var size: Vector3 = KIND_SIZE[kind]
	for o: Array in people:
		var r: float = float(o[1])
		var rel: Vector2 = (o[0] as Vector2) - p
		var fwd: float = rel.dot(d)
		if fwd < -size.z * 0.5 - 1.0 - r or fwd > size.z * 0.5 + SPAWN_PEOPLE_GAP + r:
			continue
		if absf(rel.cross(d)) < size.x * 0.5 + r + LAT_PAD:
			return false
	return true


func _in_view(p: Vector3) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(p) < VIEW_R and cam.is_position_in_frustum(p)


func _center() -> Vector3:
	var mounted: bool = roam != null and bool(roam.get("mounted"))
	if mounted and bike:
		return bike.global_position
	return player.global_position if player else Vector3.ZERO


func _is_night() -> bool:
	return roam != null and String(roam.get("tod_preset")) == "night"
