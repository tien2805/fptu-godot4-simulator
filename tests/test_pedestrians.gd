# File: res://tests/test_pedestrians.gd
# Test headless người đi đường FreeRoam (spec vice-people-and-movement, Phần 3).
#   A (Task 9):  đồ thị lối đi bộ từ mapdata: > 500 nút, không nút nào dưới nước / trong nhà OSM / trên lòng đường,
#                ba khu (campus / dân cư / đường) đủ nút, vòng quảng trường BE6, truy vấn random_point_ring / next_node,
#                lần dựng thứ hai lấy từ bộ nhớ đệm và block_near trên bản chép không cắt bản gốc.
#   B (Task 10): người đi đường trên đồ thị tự dựng: tốc độ theo kiểu đi, đi bộ + chạy bộ, va nhẹ -> STUMBLE, nước rút
#                -> KNOCKDOWN rồi đi lại trong 3 s, xe > 3 m/s -> KNOCKDOWN (tín hiệu "bike"), tầng giữa không va chạm.
#   C (Task 12): FreeRoam: mật độ theo khu (campus >= 40, dân cư >= 30, đường >= 15 người trong 80 m), trần từng tầng,
#                đêm còn 30 %, lên/xuống tầng giữ nguyên danh tính, tránh hotspot, xe tông người bị chậm lại, chi phí.
# Chạy:  godot --headless --path . --script tests/test_pedestrians.gd
extends SceneTree

const PART_B: bool = true   # Task 10 bật
const PART_C: bool = false   # Task 12 bật

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
