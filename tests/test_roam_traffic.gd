# File: res://tests/test_roam_traffic.gd
# Test headless xe chạy FreeRoam (RoamTraffic, plan Task 13).
#   A: MapData tự dựng ở z ~ 5000 (xa campus thật): hình vuông 160 m bốn đường chính hai chiều 10,5 m + một nhánh cụt
#      6 m. Làn bên phải, nối làn ở góc (rẽ không bao giờ đi lùi), quay đầu ở ngõ cụt, xe buýt chỉ trên đường cho xe
#      buýt, dừng 2,4-6,5 m sau người chơi rồi đi tiếp, xe ra ngoài 200 m bị đưa đi, xe mới xuất hiện cách 40-150 m,
#      đêm còn 30 %, build_car. Đếm khung vật lý (60 Hz): headless vẽ ~145 khung / giây.
#   B: FreeRoam thật: >= 15 xe trong 150 m quanh điểm spawn, mọi xe trên lòng đường, không làn / xe nào trong lô campus,
#      chi phí vật lý < 1,5 ms (đo trực tiếp, đám đông tạm tắt), xe máy người chơi tông xe -> xử lý va chạm sẵn có (mất
#      tốc), đêm còn <= 8 xe.
# Chạy:  godot --headless --path . --script tests/test_roam_traffic.gd
extends SceneTree

const W: float = 10.5
const CENTER := Vector3(0.0, 0.0, 5000.0)


## Chạy SAU mọi _physics_process khác: cùng mốc đầu khung (tín hiệu physics_frame) đo thời gian phía script mỗi bước vật lý.
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var done: bool = false
var frames: int = 0
var traffic: RoamTraffic
var stub_player: CharacterBody3D
var stub_roam: Node
var a_started: bool = false
var phase: String = ""
var t0: int = 0
var seen: Dictionary = {}
var last_pos: Dictionary = {}
var last_lane: Dictionary = {}
var lane_changes: int = 0
var watch: RoamTraffic.Vehicle
var roads: Array = []
var roam: Node3D
var b_phase: String = ""
var b_t0: int = 0
var b_frames: int = 0
var crashes: int = 0
var phys_with: float = 0.0
var phys_without: float = 0.0
var timing: bool = false
var _pt0: int = 0
var p_usec: int = 0
var p_n: int = 0


func _initialize() -> void:
	CharacterBuilder.ps2 = true      # mặc định của game là vice; test --script không có GameFX
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	if not _car_model_ok():
		return
	physics_frame.connect(_on_physics_a)   # nút thêm trong _initialize chưa vào cây: bắt đầu ở khung vật lý đầu tiên


func _start_a() -> void:
	var md := MapData.new()
	roads = _synthetic_roads()
	md.data = {"roads": roads}
	stub_player = CharacterBody3D.new()
	stub_player.set_script(load("res://tests/support/stub_mover.gd"))
	stub_player.collision_layer = 0
	root.add_child(stub_player)
	stub_player.global_position = CENTER
	stub_roam = Node.new()
	stub_roam.set_script(load("res://tests/support/stub_roam.gd"))
	root.add_child(stub_roam)
	traffic = RoamTraffic.new()
	root.add_child(traffic)
	var kinds: Array = []
	for k: int in range(10):
		kinds.append(RoamTraffic.Kind.MOTO if k < 6 else (RoamTraffic.Kind.CAR if k < 8 else RoamTraffic.Kind.BUS))
	traffic.setup(md, stub_player, {"roam": stub_roam, "kinds": kinds, "plot": PackedVector2Array(), "seed": 9})
	if not _lanes_ok():
		return
	phase = "run"
	t0 = frames


func _synthetic_roads() -> Array:
	var sq: Array = [[Vector2(-80.0, 5080.0), Vector2(80.0, 5080.0)], [Vector2(80.0, 5080.0), Vector2(80.0, 4920.0)],
		[Vector2(80.0, 4920.0), Vector2(-80.0, 4920.0)], [Vector2(-80.0, 4920.0), Vector2(-80.0, 5080.0)]]
	var out: Array = []
	for i: int in range(sq.size()):
		var a: Vector2 = sq[i][0]
		var b: Vector2 = sq[i][1]
		out.append({"id": i + 1, "name": "Vuông %d" % (i + 1), "class": "primary", "width": W, "lanes": 2, "oneway": false, "roundabout": false, "bridge": false, "region": "corridor", "points": [[a.x, a.y], [b.x, b.y]]})
	out.append({"id": 9, "name": "Nhánh cụt", "class": "residential", "width": 6.0, "lanes": 2, "oneway": false, "roundabout": false, "bridge": false, "region": "corridor", "points": [[0.0, 5080.0], [0.0, 5160.0]]})
	return out


func _car_model_ok() -> bool:
	var holder := Node3D.new()
	root.add_child(holder)
	var mi: MeshInstance3D = PropBuilder.build_car(holder, Color("#7FD8D2"), true) as MeshInstance3D
	var bb: AABB = mi.mesh.get_aabb() if mi and mi.mesh else AABB()
	print("  build_car: %s" % bb.size)
	var ok: bool = _check(mi != null and bb.size.x > 1.6 and bb.size.x < 2.1 and bb.size.y > 1.4 and bb.size.y < 1.7 and bb.size.z > 3.8 and bb.size.z < 4.1, "PropBuilder.build_car bakes a ~1.7 x 1.5 x 3.9 m car (got %s)" % bb.size)
	holder.queue_free()
	return ok


func _lanes_ok() -> bool:
	if not _check(traffic.lane_count() == 10, "8 square lanes + 2 stub lanes (got %d)" % traffic.lane_count()):
		return false
	var dead_end: int = -1
	for l: int in range(traffic.lane_count()):
		var pts: PackedVector2Array = traffic.lane_pts[l]
		if not _check((traffic.lane_exits[l] as Array).size() >= 1, "lane %d has no exit" % l):
			return false
		if pts[pts.size() - 1].y > 5150.0:
			dead_end = l
		var on_stub: bool = absf(pts[0].x) < 3.0 and absf(pts[pts.size() - 1].x) < 3.0
		var bus_ok: bool = (traffic.lane_kinds[l] & (1 << RoamTraffic.Kind.BUS)) != 0
		if not _check(bus_ok != on_stub, "buses use the 10.5 m primary square but not the 6 m residential stub (lane %d)" % l):
			return false
	if not _check(dead_end >= 0, "test setup: the stub's southbound lane ends at z ~ 5160"):
		return false
	var dx: Array = traffic.lane_exits[dead_end]
	var back: int = int((dx[0] as Array)[0])
	return _check(dx.size() == 1 and traffic.lane_road[back] == traffic.lane_road[dead_end] and float((dx[0] as Array)[1]) <= RoamTraffic.TURN_R * 0.5 + 0.01, "a dead end turns back onto the start of the same road's other lane")


## Mỗi xe vừa xuất hiện phải cách người chơi 40-150 m (lần lấp đầy đầu lúc setup được phép từ 20 m).
func _check_new_spawns() -> void:
	var c := Vector2(stub_player.global_position.x, stub_player.global_position.z)
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active:
			seen.erase(v)
			continue
		if seen.has(v):
			continue
		seen[v] = true
		if frames > 1:
			var d: float = v.pos.distance_to(c)
			_check(d >= RoamTraffic.SPAWN_MIN - 1.0 and d <= RoamTraffic.SPAWN_MAX + 1.0, "a vehicle appeared %.1f m from the player (40-150)" % d)


## Không xe nào đi lùi (rẽ phải ở ngã tư: điểm vào nằm sau cuối làn) và đếm số lần đổi làn.
func _check_motion() -> void:
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active:
			last_pos.erase(v)
			last_lane.erase(v)
			continue
		if last_pos.has(v):
			var mv: Vector2 = v.pos - (last_pos[v] as Vector2)
			if mv.length() < 2.0 and mv.dot(v.dir) < -0.02:
				_check(false, "a vehicle moved backwards by %.2f m (lane %d, turning %s)" % [-mv.dot(v.dir), v.lane, str(v.conn.size() == 3)])
				return
			if int(last_lane[v]) != v.lane:
				lane_changes += 1
		last_pos[v] = v.pos
		last_lane[v] = v.lane


func _lane_keeping_ok() -> bool:
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active or v.conn.size() == 3:
			continue
		var best_d: float = INF
		var best_rel := Vector2.ZERO
		var best_w: float = 0.0
		var near_end: bool = false
		for r: Dictionary in roads:
			var pts: PackedVector2Array = MapData.poly(r["points"])
			if v.pos.distance_to(pts[0]) < 10.0 or v.pos.distance_to(pts[pts.size() - 1]) < 10.0:
				near_end = true
			for i: int in range(pts.size() - 1):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(v.pos, pts[i], pts[i + 1])
				if q.distance_to(v.pos) < best_d:
					best_d = q.distance_to(v.pos)
					best_rel = v.pos - q
					best_w = float(r["width"])
		if near_end:
			continue
		if not _check(v.dir.cross(best_rel) > 0.0 and absf(best_rel.length() - best_w * 0.25) < 0.3, "a vehicle keeps to the right-hand lane (offset %.2f m, side %.2f, road %.1f m)" % [best_rel.length(), v.dir.cross(best_rel), best_w]):
			return false
	return true


func _pick_watch() -> RoamTraffic.Vehicle:
	for v: RoamTraffic.Vehicle in traffic.vehicles:
		if not v.active or v.conn.size() == 3 or v.speed < 2.0 or traffic.lane_len[v.lane] - v.s < 40.0:
			continue
		var clear: bool = true
		for o: RoamTraffic.Vehicle in traffic.vehicles:
			if o == v or not o.active:
				continue
			var rel: Vector2 = o.pos - v.pos
			if rel.dot(v.dir) > 0.0 and rel.dot(v.dir) < 35.0 and absf(rel.cross(v.dir)) < 3.0:
				clear = false
		if clear:
			return v
	return null


func _on_physics_a() -> void:
	if done:
		return
	if not a_started:
		a_started = true
		_start_a()
		return
	if phase == "":
		return
	frames += 1
	var t: int = frames - t0
	_check_new_spawns()
	_check_motion()
	match phase:
		"run":
			if t % 30 == 0 and not _lane_keeping_ok():
				return
			if t == 480:   # 8 s
				print("  lane changes during the run: %d" % lane_changes)
				if not _check(lane_changes >= 1, "vehicles must turn onto other lanes (lane changes %d in 8 s)" % lane_changes):
					return
				watch = _pick_watch()
				if not _check(watch != null, "test setup: a moving vehicle with 40 m of free lane ahead"):
					return
				stub_player.global_position = Vector3(watch.pos.x + watch.dir.x * 24.0, 0.0, watch.pos.y + watch.dir.y * 24.0)
				phase = "stop"
				t0 = frames
		"stop":
			if t == 300:   # 5 s: phanh 3,5 m/s² từ 9-13 m/s mất ~3,4 s
				var rel := Vector2(stub_player.global_position.x, stub_player.global_position.z) - watch.pos
				var gap: float = rel.dot(watch.dir) - watch.half_len - 0.4
				print("  stopped behind the player: speed %.2f, gap %.2f m, blocked by '%s'" % [watch.speed, gap, watch.blocked_by])
				if not _check(watch.speed < 0.1 and gap >= 2.4 and gap <= 6.5 and watch.blocked_by == "player", "a vehicle stops 2.4-6.5 m behind a player standing in its lane (speed %.2f, gap %.2f, '%s')" % [watch.speed, gap, watch.blocked_by]):
					return
				stub_player.global_position = CENTER
				phase = "go"
				t0 = frames
		"go":
			if t == 180:
				if not _check(watch.speed > 1.0, "the vehicle drives on once the lane is clear (speed %.2f)" % watch.speed):
					return
				stub_player.global_position = CENTER + Vector3(0.0, 0.0, 600.0)
				phase = "away"
				t0 = frames
		"away":
			if t == 120:
				print("  player 600 m away: %d active, recycled %d" % [traffic.active_count(), traffic.recycled])
				if not _check(traffic.active_count() == 0 and traffic.recycled >= 10, "vehicles beyond 200 m are parked and none appear without lanes in range (active %d, recycled %d)" % [traffic.active_count(), traffic.recycled]):
					return
				stub_player.global_position = CENTER
				phase = "back"
				t0 = frames
		"back":
			if t == 240:   # 4 s: 4 lần kiểm x 3 xe
				print("  back at the square: %d active" % traffic.active_count())
				if not _check(traffic.active_count() == 10, "vehicles refill around the player (active %d / 10)" % traffic.active_count()):
					return
				stub_roam.set("tod_preset", "night")
				phase = "night"
				t0 = frames
		"night":
			if t == 90:
				print("  night: %d active" % traffic.active_count())
				if not _check(traffic.active_count() >= 1 and traffic.active_count() <= 3, "night keeps 30 %% of the vehicles (active %d / 3)" % traffic.active_count()):
					return
				phase = ""
				traffic.queue_free()
				stub_player.queue_free()
				stub_roam.queue_free()
				_part_b_start()


func _part_b_start() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var tail := PhysTail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _phys_tail
	root.add_child(tail)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	b_phase = "settle"
	b_t0 = 0
	physics_frame.connect(_on_physics_b)


func _phys_tail() -> void:
	if timing:
		p_usec += Time.get_ticks_usec() - _pt0
		p_n += 1


func _on_carriageway(md: MapData, p: Vector2) -> bool:
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) <= 0 or bool(r.get("bridge", false)):
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		var hw: float = float(r.get("width", 6.0)) * 0.5 + 0.3
		for i: int in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) <= hw:
				return true
	return false


func _on_physics_b() -> void:
	_pt0 = Time.get_ticks_usec()
	if done:
		return
	b_frames += 1
	var t: int = b_frames - b_t0
	var tr: RoamTraffic = roam.get("traffic") as RoamTraffic
	match b_phase:
		"settle":
			if t == 150:
				if not _check(tr != null, "FreeRoam must expose a traffic node"):
					return
				var player: Node3D = roam.get("player")
				var c := Vector2(player.global_position.x, player.global_position.z)
				var plot: PackedVector2Array = RoamTraffic._campus_plot()
				var md: MapData = MapData.load_default()
				var n150: int = 0
				for v: RoamTraffic.Vehicle in tr.vehicles:
					if not v.active:
						continue
					if v.pos.distance_to(c) <= 150.0:
						n150 += 1
					if not _check(not Geometry2D.is_point_in_polygon(v.pos, plot), "a vehicle drives inside the campus plot at %s" % v.pos):
						return
					if not _check(v.pos.distance_to(c) > 2.0, "a vehicle sits on the player"):
						return
					if v.conn.size() != 3 and not _check(_on_carriageway(md, v.pos), "vehicle at %s is off the carriageway" % v.pos):
						return
				for l: int in range(tr.lane_count()):
					for p: Vector2 in (tr.lane_pts[l] as PackedVector2Array):
						if not _check(not Geometry2D.is_point_in_polygon(p, plot), "lane %d enters the campus plot at %s" % [l, p]):
							return
				print("  FreeRoam traffic: %d active, %d within 150 m, %d lanes" % [tr.active_count(), n150, tr.lane_count()])
				if not _check(n150 >= 15, "at least 15 vehicles within 150 m of the BE6 spawn (got %d)" % n150):
					return
				var crowd: Node = roam.get("pedestrians")
				if crowd:
					crowd.process_mode = Node.PROCESS_MODE_DISABLED   # đo riêng xe chạy
				p_usec = 0
				p_n = 0
				timing = true
				b_phase = "perf_with"
				b_t0 = b_frames
		"perf_with":
			if t == 1:   # bỏ mẫu của khung chuyển pha: nó gồm cả phép kiểm nặng của pha settle (~60 ms)
				p_usec = 0
				p_n = 0
			if t == 60:
				phys_with = float(p_usec) / float(maxi(1, p_n))
				tr.process_mode = Node.PROCESS_MODE_DISABLED
				p_usec = 0
				p_n = 0
				b_phase = "perf_without"
				b_t0 = b_frames
		"perf_without":
			if t == 1:   # bỏ mẫu của khung chuyển pha (tắt nút xe chạy gỡ các thân xe khỏi không gian vật lý)
				p_usec = 0
				p_n = 0
			if t == 60:
				phys_without = float(p_usec) / float(maxi(1, p_n))
				timing = false
				var cost_ms: float = (phys_with - phys_without) / 1000.0
				print("  traffic physics cost %.2f ms per physics frame (%.0f vs %.0f us)" % [cost_ms, phys_with, phys_without])
				if not _check(cost_ms < 1.5, "25 vehicles must cost < 1.5 ms per physics frame (got %.2f)" % cost_ms):
					return
				tr.process_mode = Node.PROCESS_MODE_INHERIT
				var crowd2: Node = roam.get("pedestrians")
				if crowd2:
					crowd2.process_mode = Node.PROCESS_MODE_INHERIT
				roam.call("mount_bike")
				b_phase = "bump_setup"
				b_t0 = b_frames
		"bump_setup":
			if t == 20:
				tr.set_physics_process(false)   # xe đứng yên làm vật cản
				var target_v: RoamTraffic.Vehicle = null
				for v2: RoamTraffic.Vehicle in tr.vehicles:
					if v2.active and v2.conn.size() != 3 and (target_v == null or v2.kind != RoamTraffic.Kind.MOTO):
						target_v = v2
				if not _check(target_v != null, "test setup: an active vehicle to bump"):
					return
				var bike: CharacterBody3D = roam.get("bike")
				var back: Vector2 = target_v.pos - target_v.dir * (target_v.half_len + 2.6)
				bike.global_position = Vector3(back.x, 0.3, back.y)
				bike.rotation = Vector3(0.0, atan2(-target_v.dir.x, -target_v.dir.y), 0.0)
				bike.velocity = Vector3.ZERO
				bike.set("current_speed_ms", 8.0)
				crashes = 0
				bike.connect("crash_occurred", func() -> void: crashes += 1)
				b_phase = "bump"
				b_t0 = b_frames
		"bump":
			var bk: Node3D = roam.get("bike")
			var bs: float = float(bk.get("current_speed_ms"))
			if crashes > 0 or t == 60:
				print("  bike bump: crashes %d, bike speed %.2f" % [crashes, bs])
				if not _check(crashes >= 1 and bs < 4.0, "the player's bike hitting a traffic vehicle uses the existing crash handling (crashes %d, speed %.2f)" % [crashes, bs]):
					return
				tr.set_physics_process(true)
				roam.call("set_time_of_day", "night")
				b_phase = "night"
				b_t0 = b_frames
		"night":
			if t == 90:
				var n: int = tr.active_count()
				print("  night traffic: %d active" % n)
				if not _check(n >= 1 and n <= roundi(25.0 * RoamTraffic.NIGHT_FACTOR), "night keeps 30 %% of the vehicles (active %d)" % n):
					return
				print("✅ SUCCESS: ROAM TRAFFIC (parts A + B)")
				done = true
				quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
