# File: res://scripts/roam/PedWalkGraph.gd
# Đồ thị lối đi bộ cho người đi đường FreeRoam, dựng từ MapData (một lần mỗi MapData, các lần sau chép): lề sau bó vỉa
# hai bên mỗi làn xe rộng >= MapBuilder.KERB_MIN_ROAD_W (đường một chiều chỉ lề phải: bên trái là dải phân cách của
# đường đôi), đường đi bộ (lanes == 0), vòng quảng trường quanh BE6, đường quanh toà nhà campus + sân trong + lối xuyên
# sảnh / lối sau + ba cổng. Bỏ điểm dưới / sát nước, trong nhà OSM, trên lòng đường, ngoài ba vùng đã dựng, (đường OSM)
# trong lô campus; nối các đường gần nhau (góc phố, băng qua đường). Nhà Microsoft và vật cản dựng thêm do
# PedestrianSpawner kiểm bằng vật lý.
# Mỗi nút mang khu (campus: trong 60 m quanh lô campus / dân cư: trong vùng Vinhomes / đường) cho PedestrianSpawner.
# Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name PedWalkGraph
extends RefCounted

const SAMPLE_M: float = 6.0
const VERGE_OFFSET: float = 0.45
const ROAD_CLEAR: float = 0.3
const WATER_CLEAR: float = 0.8
const LINK_R: float = 6.0
const MAX_LINKS: int = 3
const CELL: float = 16.0
const SEG_CELL: float = 32.0
const CAMPUS_LOOP_GROW: float = 5.0
const COURTYARD_INSET: float = 1.5
const BE6_PLAZA_M: float = 6.0
const REGIONS: Array[String] = ["vinhomes", "corridor", "campus"]
## Khu (mật độ + preset người đi đường): campus = trong vòng 60 m quanh lô campus; dân cư = trong vùng Vinhomes; còn lại = đường.
const ZONE_CAMPUS: int = 0
const ZONE_RESIDENTIAL: int = 1
const ZONE_ROAD: int = 2
const CAMPUS_NEAR_M: float = 60.0

static var _cache_md: MapData = null
static var _cache_graph: PedWalkGraph = null

var pos: PackedVector3Array = PackedVector3Array()
var adj: Array = []             # Array of Array[int]
var line_of: PackedInt32Array = PackedInt32Array()
var zone_of: PackedByteArray = PackedByteArray()
var _hash: Dictionary = {}      # Vector2i -> Array[int]


# ===========================================================================
# DỰNG
# ===========================================================================
## Đồ thị của md: dựng lần đầu (< 1,5 s); các lần sau (FreeRoam nạp lại sau mỗi màn) trả bản chép của đồ thị đã dựng –
## nút dùng chung, danh sách kề riêng, nên block_near trên bản chép không cắt đồ thị gốc.
static func build(md: MapData, _opts: Dictionary = {}) -> PedWalkGraph:
	if md == null:
		push_warning("PedWalkGraph: không có MapData")
		return PedWalkGraph.new()
	if md != _cache_md or _cache_graph == null:
		_cache_graph = _build_uncached(md)
		_cache_md = md
	return _cache_graph._copy()


static func _build_uncached(md: MapData) -> PedWalkGraph:
	var g := PedWalkGraph.new()
	var ctx: Dictionary = _context(md)
	var line_id: int = 0
	for r: Dictionary in md.roads():
		if bool(r.get("bridge", false)):
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts.size() < 2:
			continue
		var w: float = float(r.get("width", 6.0))
		if int(r.get("lanes", 2)) <= 0:
			g._add_line(pts, ctx, line_id, true, true, true)
			line_id += 1
		elif w >= MapBuilder.KERB_MIN_ROAD_W:
			var off: float = w * 0.5 + MapBuilder.KERB_W + VERGE_OFFSET
			g._add_line(_offset(pts, off), ctx, line_id, true, true, true)
			line_id += 1
			if not bool(r.get("oneway", false)):   # đường một chiều (nửa đường đôi): bên trái là dải phân cách
				g._add_line(_offset(pts, -off), ctx, line_id, true, true, true)
				line_id += 1
	var be6: Variant = md.landmark("be6_outer")
	if be6 is Array and (be6 as Array).size() >= 3:
		for ring: PackedVector2Array in Geometry2D.offset_polygon(MapData.poly(be6), BE6_PLAZA_M):
			var loop: PackedVector2Array = ring.duplicate()
			loop.append(ring[0])
			g._add_line(loop, ctx, line_id, true, true, true)
			line_id += 1
	for line: PackedVector2Array in _campus_lines():
		g._add_line(line, ctx, line_id, false, false, false)
		line_id += 1
	g._link(ctx)
	return g


## Đồ thị từ các polyline (Array[PackedVector2Array], toạ độ bản đồ) không lọc gì – cho test.
static func from_lines(lines: Array) -> PedWalkGraph:
	var g := PedWalkGraph.new()
	var id: int = 0
	for line: PackedVector2Array in lines:
		var prev: int = -1
		for p: Vector2 in line:
			var n: int = g._add_node(p, id)
			if prev >= 0:
				g._connect(prev, n)
			prev = n
		id += 1
	return g


## Bản chép: vị trí / khu / băm dùng chung (chỉ đọc), danh sách kề riêng.
func _copy() -> PedWalkGraph:
	var g := PedWalkGraph.new()
	g.pos = pos
	g.line_of = line_of
	g.zone_of = zone_of
	g._hash = _hash
	for a: Array in adj:
		g.adj.append(a.duplicate())
	return g


# ===========================================================================
# TRUY VẤN
# ===========================================================================
func zone_at(i: int) -> int:
	return zone_of[i]


func node_count() -> int:
	return pos.size()


func node_pos(i: int) -> Vector3:
	return pos[i]


func neighbours(i: int) -> Array:
	return adj[i]


## Nút kế tiếp từ `node` (vừa tới từ `came_from`): ngẫu nhiên trong các nút kề trừ nút vừa đi; ngõ cụt thì quay lại.
func next_node(node: int, came_from: int, rng: RandomNumberGenerator = null) -> int:
	var n: Array = adj[node]
	if n.is_empty():
		return node
	var choices: Array[int] = []
	for v: int in n:
		if v != came_from:
			choices.append(v)
	if choices.is_empty():
		return came_from if came_from >= 0 else int(n[0])
	if rng == null:
		return choices[randi() % choices.size()]
	return choices[rng.randi_range(0, choices.size() - 1)]


func nearest(p: Vector3, max_r: float = 30.0) -> int:
	var best: int = -1
	var best_d: float = max_r * max_r
	var c0: Vector2i = _cell(Vector2(p.x, p.z))
	var reach: int = ceili(max_r / CELL)
	for dx: int in range(-reach, reach + 1):
		for dz: int in range(-reach, reach + 1):
			for i: int in _hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
				var d: float = Vector2(pos[i].x - p.x, pos[i].z - p.z).length_squared()
				if d < best_d:
					best_d = d
					best = i
	return best


## Cắt mọi cạnh đi qua vùng bán kính r quanh các điểm (Array[Vector3]): nút bên trong thành cô lập, nên người đi đường
## (chỉ đi tới nút kề) không bao giờ đi vào hay lướt qua vùng đó (cột sáng hotspot, điểm spawn BE6). Chỉ quét các ô băm
## trong r + độ dài cạnh tối đa quanh mỗi điểm.
func block_near(points: Array, r: float) -> void:
	var reach: int = ceili((r + SAMPLE_M * 1.6) / CELL)
	for pt: Variant in points:
		var pv: Vector3 = pt
		var p2 := Vector2(pv.x, pv.z)
		var c0: Vector2i = _cell(p2)
		for dx: int in range(-reach, reach + 1):
			for dz: int in range(-reach, reach + 1):
				for i: int in _hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
					var a := Vector2(pos[i].x, pos[i].z)
					for e: int in (adj[i] as Array).duplicate():
						var b := Vector2(pos[e].x, pos[e].z)
						if Geometry2D.get_closest_point_to_segment(p2, a, b).distance_to(p2) < r:
							(adj[i] as Array).erase(e)
							(adj[e] as Array).erase(i)


## Nút ngẫu nhiên trong vành r_min..r_max quanh p, rẻ cả với vành rộng (người nộm ở 150-220 m): thử `tries` điểm rải đều
## theo diện tích, mỗi điểm lấy một nút của ô băm chứa nó nếu nút đó nằm trong vành. -1 nếu không trúng lần nào.
func random_point_ring(p: Vector3, r_min: float, r_max: float, rng: RandomNumberGenerator, tries: int = 12) -> int:
	for k: int in range(tries):
		var ang: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf_range(r_min * r_min, r_max * r_max))
		var cell: Array = _hash.get(_cell(Vector2(p.x + cos(ang) * r, p.z + sin(ang) * r)), [])
		if cell.is_empty():
			continue
		var i: int = int(cell[rng.randi_range(0, cell.size() - 1)])
		var d: float = Vector2(pos[i].x - p.x, pos[i].z - p.z).length()
		if d >= r_min and d <= r_max:
			return i
	return -1


# ===========================================================================
# NỘI BỘ
# ===========================================================================
func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _add_node(p: Vector2, line_id: int, zone: int = ZONE_ROAD) -> int:
	var id: int = pos.size()
	pos.append(Vector3(p.x, 0.0, p.y))
	adj.append([])
	line_of.append(line_id)
	zone_of.append(zone)
	var c: Vector2i = _cell(p)
	if not _hash.has(c):
		_hash[c] = []
	(_hash[c] as Array).append(id)
	return id


func _connect(a: int, b: int) -> void:
	if a == b or (adj[a] as Array).has(b):
		return
	(adj[a] as Array).append(b)
	(adj[b] as Array).append(a)


## Lấy mẫu polyline mỗi SAMPLE_M m; điểm hỏng cắt đường; hai điểm liền nhau chỉ nối khi trung điểm không ướt (kênh hẹp).
func _add_line(pts: PackedVector2Array, ctx: Dictionary, line_id: int, check_buildings: bool, check_roads: bool, outside_plot: bool) -> void:
	var prev: int = -1
	var prev_p := Vector2.ZERO
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n: int = maxi(1, ceili(a.distance_to(b) / SAMPLE_M))
		for s: int in range(0 if i == 0 else 1, n + 1):
			var p: Vector2 = a.lerp(b, float(s) / float(n))
			if not _ok(p, ctx, check_buildings, check_roads, outside_plot):
				prev = -1
				continue
			var id: int = _add_node(p, line_id, _zone(p, ctx))
			if prev >= 0 and prev_p.distance_to(p) <= SAMPLE_M * 1.6 and not _wet((prev_p + p) * 0.5, ctx):
				_connect(prev, id)
			prev = id
			prev_p = p


## Nối nút của các đường khác nhau trong LINK_R (góc phố, băng qua đường): mỗi nút tối đa MAX_LINKS, gần nhất trước,
## trung điểm đoạn nối không dưới nước / trong nhà OSM (trong lô campus không kiểm nhà OSM: nhà campus dựng riêng).
func _link(ctx: Dictionary) -> void:
	var plot: PackedVector2Array = ctx["plot"]
	for i: int in range(pos.size()):
		var p := Vector2(pos[i].x, pos[i].z)
		var best: Dictionary = {}    # line id -> [node, dist]
		var c0: Vector2i = _cell(p)
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				for j: int in _hash.get(Vector2i(c0.x + dx, c0.y + dz), []):
					if line_of[j] == line_of[i]:
						continue
					var d: float = p.distance_to(Vector2(pos[j].x, pos[j].z))
					if d > LINK_R:
						continue
					if not best.has(line_of[j]) or d < float((best[line_of[j]] as Array)[1]):
						best[line_of[j]] = [j, d]
		var links: Array = best.values()
		links.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
		var made: int = 0
		for l: Array in links:
			if made >= MAX_LINKS or (adj[i] as Array).size() >= MAX_LINKS + 2:
				break
			var j2: int = int(l[0])
			var mid: Vector2 = (p + Vector2(pos[j2].x, pos[j2].z)) * 0.5
			if _ok(mid, ctx, not Geometry2D.is_point_in_polygon(mid, plot), false, false):
				_connect(i, j2)
				made += 1


static func _ok(p: Vector2, ctx: Dictionary, check_buildings: bool, check_roads: bool, outside_plot: bool) -> bool:
	var inside: bool = false
	var shapes: Array = ctx["shapes"]
	var shape_box: Array = ctx["shape_box"]
	for i: int in range(shapes.size()):
		if (shape_box[i] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, shapes[i]):
			inside = true
			break
	if not inside or _wet(p, ctx):
		return false
	if check_buildings:
		for bi: int in MapBuilder._osm_hash.get(MapBuilder._cell(p), []):
			if (MapBuilder._osm_boxes[bi] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, MapBuilder._osm_polys[bi]):
				return false
	if outside_plot and Geometry2D.is_point_in_polygon(p, ctx["plot"]):
		return false
	if check_roads:
		var key := Vector2i(floori(p.x / SEG_CELL), floori(p.y / SEG_CELL))
		var segs: Array = ctx["segs"]
		for si: int in (ctx["seg_hash"] as Dictionary).get(key, []):
			var s: Array = segs[si]
			if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < float(s[2]) + ROAD_CLEAR:
				return false
	return true


## Trong nước hoặc cách mép nước dưới WATER_CLEAR: đa giác nước đã nở sẵn WATER_CLEAR, tra qua băm ô 64 m của MapBuilder.
static func _wet(p: Vector2, ctx: Dictionary) -> bool:
	var water: Array = ctx["water"]
	var water_box: Array = ctx["water_box"]
	for wi: int in (ctx["water_hash"] as Dictionary).get(MapBuilder._cell(p), []):
		if (water_box[wi] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, water[wi]):
			return true
	return false


static func _context(md: MapData) -> Dictionary:
	var ctx: Dictionary = {"water": [], "water_box": [], "water_hash": {}, "segs": [], "seg_hash": {}, "shapes": [], "shape_box": []}
	MapBuilder._prepare_osm_index(md)   # băm ô 64 m của nhà OSM, dùng chung với MapBuilder
	for w: PackedVector2Array in MapBuilder._water_polygons(md):
		for gw: PackedVector2Array in Geometry2D.offset_polygon(w, WATER_CLEAR):
			var wi: int = (ctx["water"] as Array).size()
			var bb: Rect2 = _bbox(gw)
			(ctx["water"] as Array).append(gw)
			(ctx["water_box"] as Array).append(bb)
			for c: Vector2i in MapBuilder._cells_of_box(bb, 0.0):
				if not (ctx["water_hash"] as Dictionary).has(c):
					ctx["water_hash"][c] = []
				(ctx["water_hash"][c] as Array).append(wi)
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) <= 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		var hw: float = float(r.get("width", 6.0)) * 0.5
		for i: int in range(pts.size() - 1):
			var si: int = (ctx["segs"] as Array).size()
			(ctx["segs"] as Array).append([pts[i], pts[i + 1], hw])
			var bb2: Rect2 = Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1]).grow(hw + ROAD_CLEAR)
			for cx: int in range(floori(bb2.position.x / SEG_CELL), floori(bb2.end.x / SEG_CELL) + 1):
				for cz: int in range(floori(bb2.position.y / SEG_CELL), floori(bb2.end.y / SEG_CELL) + 1):
					var key := Vector2i(cx, cz)
					if not (ctx["seg_hash"] as Dictionary).has(key):
						ctx["seg_hash"][key] = []
					(ctx["seg_hash"][key] as Array).append(si)
	for reg: String in REGIONS:
		for poly: PackedVector2Array in MapBuilder.region_shape(md, reg):
			(ctx["shapes"] as Array).append(poly)
			(ctx["shape_box"] as Array).append(_bbox(poly))
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var pr: Rect2 = FPTUCampusBuilder.plot_rect()
	var plot := PackedVector2Array()
	for c: Vector2 in [pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]:
		var w3: Vector3 = xf * Vector3(c.x, 0.0, c.y)
		plot.append(Vector2(w3.x, w3.z))
	ctx["plot"] = plot
	var near := PackedVector2Array()
	var pg: Rect2 = pr.grow(CAMPUS_NEAR_M)
	for c2: Vector2 in [pg.position, Vector2(pg.end.x, pg.position.y), pg.end, Vector2(pg.position.x, pg.end.y)]:
		var w4: Vector3 = xf * Vector3(c2.x, 0.0, c2.y)
		near.append(Vector2(w4.x, w4.z))
	ctx["campus_near"] = near
	ctx["vinhomes"] = MapBuilder.region_shape(md, "vinhomes")
	return ctx


static func _zone(p: Vector2, ctx: Dictionary) -> int:
	if Geometry2D.is_point_in_polygon(p, ctx["campus_near"]):
		return ZONE_CAMPUS
	for poly: PackedVector2Array in ctx["vinhomes"]:
		if Geometry2D.is_point_in_polygon(p, poly):
			return ZONE_RESIDENTIAL
	return ZONE_ROAD


## Lối đi campus (hệ cục bộ u dọc D1, v vào lô): đường hở quanh toà nhà – từ sau rào sân bóng theo giữa làn bãi xe sau lưng
## (tránh cột mái che và hai dãy xe), xuống mép Tây, dọc mặt trước, lên dải ĐN rồi dừng trước rào sân bóng; vòng sân
## trong; lối xuyên sảnh trước và lối sau (lệch 0,8 m khỏi cột mái dãy A) nối vòng ngoài với sân trong; ba cổng.
static func _campus_lines() -> Array:
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var out: Array = []
	var ro: Rect2 = FPTUCampusBuilder.ring_outer_rect()
	var u0: float = ro.position.x - CAMPUS_LOOP_GROW
	var u1: float = ro.end.x + CAMPUS_LOOP_GROW
	var v0: float = ro.position.y - CAMPUS_LOOP_GROW
	var vb: float = FPTUCampusBuilder.PARK_LANE_V
	var pitch_end: float = FPTUCampusBuilder.PITCH_CX + FPTUCampusBuilder.PITCH_LEN * 0.5 + 2.0
	out.append(_local_line([Vector2(pitch_end, vb), Vector2(u1, vb), Vector2(u1, v0), Vector2(u0, v0), Vector2(u0, ro.end.y)], xf))
	var court: Rect2 = FPTUCampusBuilder.ring_courtyard_rect().grow(-COURTYARD_INSET)
	out.append(_rect_loop(court, xf))
	var lu: float = FPTUCampusBuilder.lobby_u()
	out.append(_local_line([Vector2(lu, v0), Vector2(lu, court.position.y)], xf))
	var bu: float = FPTUCampusBuilder.back_gap_u() - 0.8
	out.append(_local_line([Vector2(bu, vb), Vector2(bu, court.end.y)], xf))
	for g: Vector3 in [FPTUCampusBuilder.main_gate_local(), FPTUCampusBuilder.west_gate_local()]:
		out.append(_local_line([Vector2(g.x, -2.0), Vector2(g.x, v0)], xf))
	var bg: Vector3 = FPTUCampusBuilder.back_gate_local()
	out.append(_local_line([Vector2(bg.x, bg.z + 2.0), Vector2(bg.x, vb)], xf))
	return out


static func _rect_loop(r: Rect2, xf: Transform3D) -> PackedVector2Array:
	return _local_line([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position], xf)


static func _local_line(pts: Array, xf: Transform3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		var w: Vector3 = xf * Vector3(p.x, 0.0, p.y)
		out.append(Vector2(w.x, w.z))
	return out


## Polyline dời sang PHẢI chiều đi (off > 0; hệ x đông / z nam: pháp tuyến (-dz, dx)) / trái (off < 0) theo pháp tuyến
## trung bình ở mỗi đỉnh (giới hạn mitre). RoamTraffic dùng off = +rộng/4 cho làn bên phải.
static func _offset(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = pts.size()
	for i: int in range(n):
		var d0: Vector2 = (pts[i] - pts[i - 1]).normalized() if i > 0 else (pts[1] - pts[0]).normalized()
		var d1: Vector2 = (pts[i + 1] - pts[i]).normalized() if i < n - 1 else d0
		var sum: Vector2 = d0 + d1
		var nrm: Vector2 = Vector2(-sum.y, sum.x).normalized() if sum.length() > 0.01 else Vector2(-d1.y, d1.x)
		var cos_half: float = maxf(0.35, nrm.dot(Vector2(-d1.y, d1.x)))
		out.append(pts[i] + nrm * off / cos_half)
	return out


static func _bbox(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		r = r.expand(p)
	return r
