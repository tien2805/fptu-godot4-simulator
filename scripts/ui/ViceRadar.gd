# File: res://scripts/ui/ViceRadar.gd
# Radar tròn góc dưới trái kiểu HUD thập niên 80 (Task VC-4; từ lớp Radar của tests/preview_vice_lookdev.gd).
# Vẽ từ assets/data/mapdata.json (MapData): đường (3 bậc: lối đi / 1 làn / >= 2 làn), tuyến BE6 -> FPTU màu hồng,
# blip ({"pos": Vector2 bản đồ, "color": Color, "shape": "square" | "circle" | "diamond"}; ngoài tầm thì nằm ở mép),
# mũi tên người chơi ở tâm (phía trên = hướng camera), chữ N, viền hồng.
# Hiệu năng: chỉ mục lưới tĩnh của mọi đoạn đường dựng MỘT lần cho mỗi MapData (dùng chung giữa các radar); radar giữ
# danh sách đoạn trong CACHE_RADIUS m quanh tâm lần dựng gần nhất và chỉ dựng lại khi tâm đi xa hơn REBUILD_MOVE m, nên
# _draw chỉ biến đổi + cắt ~vài trăm đoạn theo vòng tròn rồi vẽ bằng 3 lệnh draw_multiline (< 1 ms). Vẽ lại tối đa
# REDRAW_HZ lần / giây khi tâm / hướng / blip đổi. last_draw_usec, draws, drawn_segments, cached_segments để test đo.
# Không dùng GameFX / StageManager (lớp class_name được test --script nạp trước autoload).
# Chỉ đường (plan 2026-10-30-d2-playtest-fixes.md, RouteGuide): guide_route (tuyến của màn đua / rượt, vẽ màu GUIDE thay cho
# tuyến BE6 khi được đặt; PackedVector2Array rỗng = tắt) và extra_blips (vẽ sau blips: chấm đỏ của địch, RouteGuide cập
# nhật 10 Hz bằng một mảng dùng lại).
class_name ViceRadar
extends Control

const CACHE_RADIUS: float = 400.0
const REBUILD_MOVE: float = 150.0
const REDRAW_HZ: float = 20.0
const CELL: float = 100.0
const BG := Color(0.04, 0.03, 0.1, 0.8)
const RIM := Color("#FF5FB0")
const ROAD_COLORS: Array[Color] = [Color(0.56, 0.52, 0.77, 0.75), Color("#B9B0EA"), Color("#E6DEFF")]
const ROAD_WIDTHS: Array[float] = [1.2, 2.0, 3.0]
const ROUTE := Color("#FF5FB0")
const INK := Color("#1B0F33")
const SEARCH_FILL := Color(0.3, 0.55, 1.0, 0.22)
const SEARCH_RIM := Color(0.45, 0.7, 1.0, 0.85)
const GUIDE := Color("#27E8FF")

var md: MapData:
	set(v):
		md = v
		_cache_center = Vector2(INF, INF)
		_dirty = true
var center: Vector2 = Vector2.ZERO:
	set(v):
		if not v.is_equal_approx(center):
			center = v
			_dirty = true
			_maybe_rebuild(false)
var yaw: float = 0.0:
	set(v):
		if not is_equal_approx(v, yaw):
			yaw = v
			_dirty = true
var range_m: float = 170.0
var blips: Array[Dictionary] = []:
	set(v):
		blips = v
		_dirty = true
var route: PackedVector2Array = PackedVector2Array():
	set(v):
		route = v
		_cache_center = Vector2(INF, INF)
		_dirty = true
## RouteGuide: the course of the chase / race, drawn in GUIDE instead of the BE6 route while set (empty = off).
var guide_route: PackedVector2Array = PackedVector2Array():
	set(v):
		guide_route = v
		_cache_center = Vector2(INF, INF)
		_maybe_rebuild(false)
		_dirty = true
## RouteGuide: extra blips drawn after `blips` (the enemies' red dots).
var extra_blips: Array[Dictionary] = []:
	set(v):
		extra_blips = v
		_dirty = true
var guide_draws: int = 0
## Phase W wanted search area (map x, map z, radius m); radius 0 = none. A translucent disc clipped to the radar.
var search: Vector3 = Vector3.ZERO:
	set(v):
		if not v.is_equal_approx(search):
			search = v
			_dirty = true
var search_draws: int = 0

var draws: int = 0
var last_draw_usec: int = 0
var drawn_segments: int = 0
var cached_segments: int = 0
var rebuilds: int = 0

## Chỉ mục tĩnh theo MapData (instance id -> {"a", "b", "k", "grid", "mark"}).
static var _indexes: Dictionary = {}
static var _stamp: int = 0

var _ca := PackedVector2Array()
var _cb := PackedVector2Array()
var _ck := PackedByteArray()
var _route_near := PackedVector2Array()   # cặp điểm (đoạn) của tuyến trong CACHE_RADIUS
var _guide_near := PackedVector2Array()   # ... của guide_route
var _cache_center := Vector2(INF, INF)
var _t: float = 0.0
var _dirty: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0 / REDRAW_HZ:
		return
	_t = 0.0
	if _dirty and is_visible_in_tree():
		_dirty = false
		queue_redraw()


## Dựng lại danh sách đoạn quanh tâm hiện tại (bắt buộc) rồi xếp một lần vẽ.
func refresh_now() -> void:
	_maybe_rebuild(true)
	_dirty = false
	queue_redraw()


## Toạ độ bản đồ (x, z) -> toạ độ trong radar: phía trên = hướng camera (yaw quanh +Y của Godot, yaw 0 nhìn -Z).
func to_radar(p: Vector2) -> Vector2:
	var r: float = minf(size.x, size.y) * 0.5
	var k: float = (r - 6.0) / range_m
	var d: Vector2 = (p - center) * k
	var cs: float = cos(yaw)
	var sn: float = sin(yaw)
	return size * 0.5 + Vector2(d.x * cs - d.y * sn, d.x * sn + d.y * cs)


static func _index_for(m: MapData) -> Dictionary:
	var id: int = m.get_instance_id()
	if _indexes.has(id):
		return _indexes[id]
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var k := PackedByteArray()
	var grid: Dictionary = {}
	for r: Dictionary in m.roads():
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		var lanes: int = int(r.get("lanes", 0))
		var kind: int = 2 if lanes >= 2 else (1 if lanes == 1 else 0)
		for i: int in range(pts.size() - 1):
			var p: Vector2 = pts[i]
			var q: Vector2 = pts[i + 1]
			var idx: int = a.size()
			a.append(p)
			b.append(q)
			k.append(kind)
			var lo := Vector2i(floori(minf(p.x, q.x) / CELL), floori(minf(p.y, q.y) / CELL))
			var hi := Vector2i(floori(maxf(p.x, q.x) / CELL), floori(maxf(p.y, q.y) / CELL))
			for cx: int in range(lo.x, hi.x + 1):
				for cz: int in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not grid.has(key):
						grid[key] = []
					(grid[key] as Array).append(idx)
	var mark := PackedInt32Array()
	mark.resize(a.size())
	var out: Dictionary = {"a": a, "b": b, "k": k, "grid": grid, "mark": mark}
	_indexes[id] = out
	return out


func _maybe_rebuild(force: bool) -> void:
	if md == null:
		return
	if not force and _cache_center.x != INF and center.distance_to(_cache_center) <= REBUILD_MOVE:
		return
	var ix: Dictionary = _index_for(md)
	var a: PackedVector2Array = ix["a"]
	var b: PackedVector2Array = ix["b"]
	var k: PackedByteArray = ix["k"]
	var grid: Dictionary = ix["grid"]
	var mark: PackedInt32Array = ix["mark"]
	_stamp += 1
	_ca.clear()
	_cb.clear()
	_ck.clear()
	var c0 := Vector2i(floori((center.x - CACHE_RADIUS) / CELL), floori((center.y - CACHE_RADIUS) / CELL))
	var c1 := Vector2i(floori((center.x + CACHE_RADIUS) / CELL), floori((center.y + CACHE_RADIUS) / CELL))
	var r2: float = CACHE_RADIUS * CACHE_RADIUS
	for cx: int in range(c0.x, c1.x + 1):
		for cz: int in range(c0.y, c1.y + 1):
			var cell: Variant = grid.get(Vector2i(cx, cz))
			if cell == null:
				continue
			for idx: int in (cell as Array):
				if mark[idx] == _stamp:
					continue
				mark[idx] = _stamp
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(center, a[idx], b[idx])
				if q.distance_squared_to(center) <= r2:
					_ca.append(a[idx])
					_cb.append(b[idx])
					_ck.append(k[idx])
	ix["mark"] = mark
	_route_near.clear()
	for i: int in range(route.size() - 1):
		var q2: Vector2 = Geometry2D.get_closest_point_to_segment(center, route[i], route[i + 1])
		if q2.distance_squared_to(center) <= r2:
			_route_near.append(route[i])
			_route_near.append(route[i + 1])
	_guide_near.clear()
	for i4: int in range(guide_route.size() - 1):
		var q4: Vector2 = Geometry2D.get_closest_point_to_segment(center, guide_route[i4], guide_route[i4 + 1])
		if q4.distance_squared_to(center) <= r2:
			_guide_near.append(guide_route[i4])
			_guide_near.append(guide_route[i4 + 1])
	cached_segments = _ca.size()
	_cache_center = center
	rebuilds += 1


## Cắt đoạn p-q (toạ độ radar) theo vòng tròn tâm c bán kính rr. Trả Vector4(x0, y0, x1, y1) của phần nằm trong,
## x0 = NAN khi đoạn nằm hẳn ngoài (Vector4 để không cấp phát mảng cho mỗi đoạn).
static func _clip(p: Vector2, q: Vector2, c: Vector2, rr: float) -> Vector4:
	var r2: float = rr * rr
	var fp: Vector2 = p - c
	if fp.length_squared() <= r2 and (q - c).length_squared() <= r2:
		return Vector4(p.x, p.y, q.x, q.y)
	var d: Vector2 = q - p
	var aa: float = d.dot(d)
	if aa < 1e-6:
		return Vector4(NAN, 0.0, 0.0, 0.0)
	var bb: float = 2.0 * fp.dot(d)
	var cc: float = fp.dot(fp) - r2
	var disc: float = bb * bb - 4.0 * aa * cc
	if disc <= 0.0:
		return Vector4(NAN, 0.0, 0.0, 0.0)
	var sq: float = sqrt(disc)
	var t1: float = maxf((-bb - sq) / (2.0 * aa), 0.0)
	var t2: float = minf((-bb + sq) / (2.0 * aa), 1.0)
	if t1 >= t2:
		return Vector4(NAN, 0.0, 0.0, 0.0)
	var a: Vector2 = p + d * t1
	var b: Vector2 = p + d * t2
	return Vector4(a.x, a.y, b.x, b.y)


func _draw() -> void:
	var t0: int = Time.get_ticks_usec()
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	draw_circle(c, r, BG)
	var k: float = (r - 6.0) / range_m
	var cs: float = cos(yaw)
	var sn: float = sin(yaw)
	var rr: float = r - 4.0
	# một mảng điểm (cặp = đoạn) cho mỗi bậc đường; biến cục bộ riêng vì mảng packed trong Array bị sao chép khi truy cập
	var l0 := PackedVector2Array()
	var l1 := PackedVector2Array()
	var l2 := PackedVector2Array()
	var drawn: int = 0
	for i: int in range(_ca.size()):
		var dp: Vector2 = (_ca[i] - center) * k
		var dq: Vector2 = (_cb[i] - center) * k
		var v: Vector4 = _clip(Vector2(c.x + dp.x * cs - dp.y * sn, c.y + dp.x * sn + dp.y * cs), Vector2(c.x + dq.x * cs - dq.y * sn, c.y + dq.x * sn + dq.y * cs), c, rr)
		if is_nan(v.x):
			continue
		drawn += 1
		match _ck[i]:
			0:
				l0.append(Vector2(v.x, v.y))
				l0.append(Vector2(v.z, v.w))
			1:
				l1.append(Vector2(v.x, v.y))
				l1.append(Vector2(v.z, v.w))
			_:
				l2.append(Vector2(v.x, v.y))
				l2.append(Vector2(v.z, v.w))
	if l0.size() >= 2:
		draw_multiline(l0, ROAD_COLORS[0], ROAD_WIDTHS[0], true)
	if l1.size() >= 2:
		draw_multiline(l1, ROAD_COLORS[1], ROAD_WIDTHS[1], true)
	if l2.size() >= 2:
		draw_multiline(l2, ROAD_COLORS[2], ROAD_WIDTHS[2], true)
	# tuyến BE6 -> FPTU (hồng, viền tối); khi có guide_route thì vẽ tuyến chỉ đường (xanh neon, dày hơn) thay vào
	var guiding: bool = guide_route.size() >= 2
	var near: PackedVector2Array = _guide_near if guiding else _route_near
	var rl := PackedVector2Array()
	var j: int = 0
	while j + 1 < near.size():
		var dp2: Vector2 = (near[j] - center) * k
		var dq2: Vector2 = (near[j + 1] - center) * k
		var v2: Vector4 = _clip(Vector2(c.x + dp2.x * cs - dp2.y * sn, c.y + dp2.x * sn + dp2.y * cs), Vector2(c.x + dq2.x * cs - dq2.y * sn, c.y + dq2.x * sn + dq2.y * cs), c, rr)
		if not is_nan(v2.x):
			rl.append(Vector2(v2.x, v2.y))
			rl.append(Vector2(v2.z, v2.w))
		j += 2
	if rl.size() >= 2:
		draw_multiline(rl, INK, 9.0 if guiding else 7.0, true)
		draw_multiline(rl, GUIDE if guiding else ROUTE, 5.0 if guiding else 4.0, true)
		if guiding:
			guide_draws += 1
	# Phase W: vòng tìm kiếm của truy nã (cắt theo đĩa radar)
	if search.z > 0.0:
		var sc: Vector2 = to_radar(Vector2(search.x, search.y))
		var sr: float = search.z * k
		var disc := PackedVector2Array()
		var rim_poly := PackedVector2Array()
		for i3: int in 48:
			var a3: float = TAU * float(i3) / 48.0
			disc.append(sc + Vector2(cos(a3), sin(a3)) * sr)
			rim_poly.append(c + Vector2(cos(a3), sin(a3)) * rr)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(disc, rim_poly):
			draw_colored_polygon(piece, SEARCH_FILL)
		if sc.distance_to(c) + sr <= rr:
			draw_arc(sc, sr, 0.0, TAU, 48, SEARCH_RIM, 2.0, true)
		search_draws += 1
	# blip (ngoài tầm: nằm ở mép)
	for bl: Dictionary in blips:
		var bp: Vector2 = to_radar(bl.get("pos", Vector2.ZERO))
		bp = c + (bp - c).limit_length(r - 10.0)
		var col: Color = bl.get("color", Color.WHITE)
		match String(bl.get("shape", "circle")):
			"square":
				draw_rect(Rect2(bp - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), col)
				draw_rect(Rect2(bp - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), INK, false, 2.0)
			"diamond":
				var dia := PackedVector2Array([bp + Vector2(0.0, -8.0), bp + Vector2(8.0, 0.0), bp + Vector2(0.0, 8.0), bp + Vector2(-8.0, 0.0)])
				draw_colored_polygon(dia, col)
				dia.append(dia[0])
				draw_polyline(dia, INK, 2.0, true)
			_:
				draw_circle(bp, 8.0, INK)
				draw_circle(bp, 6.0, col)
	# RouteGuide: chấm của địch (đỏ, viền tối; ngoài tầm thì nằm ở mép)
	for eb: Dictionary in extra_blips:
		if not bool(eb.get("on", true)):
			continue
		var ep: Vector2 = to_radar(eb.get("pos", Vector2.ZERO))
		ep = c + (ep - c).limit_length(r - 10.0)
		var er: float = float(eb.get("r", 6.0))
		draw_circle(ep, er + 2.0, INK)
		draw_circle(ep, er, eb.get("color", Color(1.0, 0.15, 0.12)))
	# người chơi: mũi tên trắng hướng lên
	var tri := PackedVector2Array([c + Vector2(0.0, -11.0), c + Vector2(8.0, 9.0), c + Vector2(0.0, 4.0), c + Vector2(-8.0, 9.0)])
	draw_colored_polygon(tri, Color.WHITE)
	tri.append(tri[0])
	draw_polyline(tri, INK, 1.5, true)
	# chữ N theo hướng bắc (-z bản đồ)
	var north: Vector2 = c + Vector2(sn, -cs) * (r - 12.0)
	draw_circle(north, 9.0, INK)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, north + Vector2(-5.0, 6.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_arc(c, r - 1.5, 0.0, TAU, 96, RIM, 4.0, true)
	drawn_segments = drawn
	draws += 1
	last_draw_usec = Time.get_ticks_usec() - t0
