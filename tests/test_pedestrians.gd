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

const PART_B: bool = false   # Task 10 bật
const PART_C: bool = false   # Task 12 bật

var done: bool = false
var frames: int = 0


func _initialize() -> void:
	if not _part_a():
		return
	if not PART_B and not PART_C:
		print("✅ SUCCESS: PEDESTRIANS (part A: walk graph)")
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
	var keep: int = g.neighbours(deg2).size()
	var t1: int = Time.get_ticks_msec()
	var g2: PedWalkGraph = PedWalkGraph.build(md)
	var ms2: int = Time.get_ticks_msec() - t1
	print("  cached rebuild: %d ms" % ms2)
	if not _check(ms2 < 200 and g2.node_count() == g.node_count(), "a second build must come from the cache (%d ms, %d nodes)" % [ms2, g2.node_count()]):
		return false
	g2.block_near([g2.node_pos(deg2)], 3.0)
	return _check(g2.neighbours(deg2).is_empty() and g.neighbours(deg2).size() == keep, "block_near on one copy must not cut another copy or the cache")


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
