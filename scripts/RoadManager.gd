# File: res://scripts/RoadManager.gd
# Màn 1 trên bản đồ thật (docs/superpowers/plans/2026-10-22-real-map-world.md, Task 6).
#   - Tuyến đường lái (RoadTrack/RoadPath) = lộ trình thật BE6 -> cổng chính FPTU trong assets/data/mapdata.json
#     (MapData.route_points): xuất phát ở điểm spawn trước sảnh BE6, ra đường nội khu rồi Đường Hải Đăng, theo
#     đúng lộ trình OSM (Cầu Vồng 5 - Nguyễn Xiển - Cầu Rạch Hầm - Nguyễn Văn Tăng - Đường số 12 - Hàng Tre -
#     D2B - vòng xoay - Đường D1) và về đích trên D1 ngay trước cổng chính (campus_main_gate); đường chạy thêm
#     OVERRUN_M sau vạch đích để xe có chỗ dừng. Polyline được bo cua (bán kính <= CORNER_R), lấy mẫu SAMPLE_M
#     một điểm, tay nắm Catmull-Rom; y = MapBuilder.ROAD_Y trừ các đoạn cầu (bridge == true) dùng đúng profile
#     dốc 6 m / 40 m của MapBuilder nên xe chạy trên mặt cầu MapBuilder dựng.
#   - Thế giới: MapBuilder dựng vùng corridor (lod 1), vinhomes (lod 2, các đường trên lộ trình dựng lại đủ bó
#     vỉa + vạch), campus (bỏ các nhà do FPTUCampusBuilder dựng, khu đất trong lô FPTU không vẽ polygon OSM);
#     FPTUCampusBuilder v8 đặt lên lô thật (real_plot_transform) + HUTECH đối diện; mặt đất 12 km
#     (WorldBoundaryShape3D y = 0 + PlaneMesh cắt lỗ theo vùng MapBuilder) dưới tất cả.
#   - Kẹp làn theo bề rộng đường thật từng đoạn: road_half_width / road_hard_limit của PlayerBike được cập nhật
#     theo offset (half_width_at / hard_limit_at); TrafficSpawner và RoadEvents hỏi cùng API (half_width_at,
#     is_oneway_at, oneway_ranges, route_marks).
#   - Thời gian: STAGE_TIME = 240 s (HUDManager đọc), vùng tên đường theo mốc thật, vạch đích trước cổng.
class_name RoadManager
extends Node3D

signal zone_changed(zone_name: String)
signal destination_reached()

## Giới hạn thời gian Màn 1 (giây thực): 07:05 -> 07:30 trong game. HUDManager.stage_duration_sec lấy từ đây.
## Kế hoạch ghi 240 s, nhưng quãng đua thật 5 544 m ở tốc độ tối đa 22,5 m/s (PlayerBike.max_speed_ms, không
## đổi) đã mất 246 s khi chạy hết ga không phanh; thêm cua, đèn đỏ Cầu Rạch Hầm và xe cộ, bot/người chơi trung
## bình cần ~270-285 s (trừ thưởng sát nút tối đa 12 s). 300 s giữ đúng tỉ lệ "ngân sách / chạy hết ga" của
## đường cũ (104 s / 84 s ≈ 1,24).
const STAGE_TIME: float = 300.0
const SAMPLE_M: float = 8.0           # bước lấy mẫu polyline (= MapBuilder.RIBBON_STEP_M)
const CORNER_R: float = 6.0           # bán kính bo cua tối đa
const OVERRUN_M: float = 70.0         # đường chạy thêm sau vạch đích (dọc D1)
const GROUND_SIZE: float = 12000.0
const GROUND_CELL: float = 1000.0
const GROUND_Y: float = -0.05
const SPAWN_ROAD_ID: int = 838402727  # đường nội khu trước sảnh BE6 (OSM way)
const SPAWN_LINK_ID: int = 853086643  # living street nối ra Đường Hải Đăng
const CAMPUS_SKIP_BUILDINGS: Array = [13698121, 605379726, 605379727, 605379728]
const DEFAULT_HALF_W: float = 3.0
const MIN_HALF_W: float = 2.5
const HARD_MARGIN: float = 1.5
const ROAD_MATCH_M: float = 7.0
const WIDTH_BLEND_RATE: float = 2.5   # m/s: tốc độ đổi bề rộng kẹp làn khi sang đoạn khác
const ROAD_GRID_CELL: float = 50.0    # ô lưới đoạn đường (_inside_carriageway)
const START_DETAIL_R: float = 280.0   # bán kính quanh spawn dựng mặt tiền đầy đủ cho các toà (vùng vinhomes lod 2)
const TREE_EVERY_M: float = 20.0      # khoảng cách hàng cây ven đường (xen kẽ hai bên)

@export var player_bike: CharacterBody3D

@onready var road_path: Path3D = $RoadTrack/RoadPath
@onready var scenery_root: Node3D = $SceneryRoot

var md: MapData
var total_track_length: float = 1.0        # = finish_offset: quãng đường đua (m)
var current_zone: String = ""
var has_finished: bool = false
var finish_offset: float = 1.0e9
var remaining_m: float = 0.0
var road_events: Node3D
var route_marks: Dictionary = {}           # offset (m) các mốc thật: hai_dang_end, cau_vong_5_start, nguyen_xien,
                                           # bridge_start, bridge_end, nvt_start, nvt_end, so12_start, d2b_start,
                                           # d2b_end, roundabout, d1_start, bus_stop, finish, end
var sections: Array = []                   # [{name, start, end}] các đoạn đường của lộ trình theo offset curve
var width_profile: Array = []              # [[offset_start, half_width, oneway, road_id]] tăng dần theo offset
var zones: Array = []                      # [[offset_start, tên vùng]]
var _polyline: PackedVector2Array = PackedVector2Array()   # polyline đã bo cua + lấy mẫu (xz)
var _heights: PackedFloat32Array = PackedFloat32Array()     # y từng điểm polyline
var _bridge_profiles: Array = []           # [[PackedVector2Array rs, PackedFloat32Array h]] từ MapBuilder resample
var _profile_idx: int = 0
var _road_grid: Dictionary = {}            # Vector2i ô -> Array[Vector2i(chỉ số đường trong _grid_roads, đoạn)]
var _grid_roads: Array = []                # [[PackedVector2Array points, float half_width]] (lanes > 0)


func _ready() -> void:
	md = MapData.load_default()
	_build_real_world_curve()
	_build_world()
	_place_player_at_start()
	_spawn_road_events()
	GameFX.upgrade_scene_visuals(get_parent(), "dawn")
	GameFX.music_play("ride", 0.3)


func _spawn_road_events() -> void:
	# Sự kiện bất ngờ trên đường (ổ gà, xe tải hỏng, chó, đèn đỏ, mưa, checkpoint hài) đặt theo route_marks
	if not player_bike:
		return
	var ev_script: Script = load("res://scripts/RoadEvents.gd")
	if ev_script == null:
		return
	road_events = ev_script.new()
	road_events.name = "RoadEvents"
	add_child(road_events)
	road_events.call("setup", road_path, player_bike, self)


# ===========================================================================
# TUYẾN ĐƯỜNG LÁI
# ===========================================================================
func _build_real_world_curve() -> void:
	var pts: PackedVector2Array
	if md != null:
		pts = _drivable_polyline()
	else:
		push_error("RoadManager: mapdata.json missing, falling back to a straight test road")
		pts = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, -2000.0)])
	pts = _fillet_corners(pts, CORNER_R)
	_bridge_profiles = _collect_bridge_profiles()
	pts = _insert_bridge_vertices(pts)
	pts = _resample(pts, SAMPLE_M)
	_polyline = pts
	_heights = PackedFloat32Array()
	_heights.resize(pts.size())
	for i: int in range(pts.size()):
		_heights[i] = MapBuilder.ROAD_Y + _bridge_height(pts[i])

	var curve := Curve3D.new()
	curve.up_vector_enabled = true
	curve.bake_interval = 0.5
	var n: int = pts.size()
	for i: int in range(n):
		var p := Vector3(pts[i].x, _heights[i], pts[i].y)
		var handle := Vector3.ZERO
		if i > 0 and i < n - 1:
			var prev := Vector3(pts[i - 1].x, _heights[i - 1], pts[i - 1].y)
			var next := Vector3(pts[i + 1].x, _heights[i + 1], pts[i + 1].y)
			handle = (next - prev) / 6.0   # Catmull-Rom (tension 0.5) -> tay nắm Bezier
		curve.add_point(p, -handle, handle)
	road_path.curve = curve

	var gate: Vector3 = FPTUCampusBuilder.real_plot_transform() * FPTUCampusBuilder.main_gate_local()
	finish_offset = curve.get_closest_offset(gate)
	total_track_length = finish_offset
	remaining_m = finish_offset
	_build_width_profile()
	_build_route_marks()
	print("RoadManager: real route curve %.0f m (finish at %.0f m, %d points, %d width runs)" % [curve.get_baked_length(), finish_offset, n, width_profile.size()])


## Polyline xz của tuyến lái: spawn -> đường nội khu BE6 -> living street -> Đường Hải Đăng -> lộ trình OSM
## (bỏ đoạn service 14 m cuối rẽ vào cổng) -> chạy thêm OVERRUN_M dọc D1.
func _drivable_polyline() -> PackedVector2Array:
	var raw: PackedVector2Array = md.route_points(0.0)
	var sp: Transform3D = md.spawn_transform()
	var spawn := Vector2(sp.origin.x, sp.origin.z)
	var out := PackedVector2Array()
	out.append(spawn)
	var resume_from: int = 0
	var road_a: Dictionary = _road_by_id(SPAWN_ROAD_ID)
	var road_b: Dictionary = _road_by_id(SPAWN_LINK_ID)
	if not road_a.is_empty() and not road_b.is_empty():
		var a_pts: PackedVector2Array = MapData.poly(road_a["points"])
		var b_pts: PackedVector2Array = MapData.poly(road_b["points"])
		# living street: đầu nào nằm trên đường nội khu là đầu nối
		if _closest_on_polyline(a_pts, b_pts[b_pts.size() - 1])["dist"] < _closest_on_polyline(a_pts, b_pts[0])["dist"]:
			b_pts.reverse()
		var junction: Vector2 = b_pts[0]
		var proj: Dictionary = _closest_on_polyline(a_pts, spawn)
		var p0: Vector2 = proj["point"]
		var dir: Vector2 = (junction - p0).normalized()
		var entry: Vector2 = p0 + dir * minf(30.0, p0.distance_to(junction) * 0.5)
		out.append(entry)
		out.append(junction)
		for i: int in range(1, b_pts.size()):
			out.append(b_pts[i])
		var k: int = int(_closest_on_polyline(raw, b_pts[b_pts.size() - 1])["seg"])
		resume_from = k + 1
	# lộ trình OSM; điểm cuối cùng là cổng (ngoài lòng đường) -> bỏ, đích = hình chiếu cổng lên D1
	for i: int in range(resume_from, raw.size() - 1):
		out.append(raw[i])
	return _extend_along_road(out, OVERRUN_M)


## Kéo dài polyline thêm `metres` dọc theo con đường (lanes > 0) gần điểm cuối nhất, theo chiều đi tiếp.
func _extend_along_road(pts: PackedVector2Array, metres: float) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	if out.size() < 2:
		return out
	var last: Vector2 = out[out.size() - 1]
	var prev: Vector2 = out[out.size() - 2]
	var heading: Vector2 = (last - prev).normalized()
	var best: Dictionary = {}
	var best_pts := PackedVector2Array()
	var best_score: float = 6.0
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 0)) <= 0:
			continue
		var rp: PackedVector2Array = MapData.poly(r.get("points", []))
		if rp.size() < 2:
			continue
		var c: Dictionary = _closest_on_polyline(rp, last)
		if float(c["dist"]) >= 6.0:
			continue
		# ưu tiên đường cùng hướng đi (đoạn service rẽ vào cổng cũng bắt đầu đúng điểm cuối lộ trình)
		var seg: int = int(c["seg"])
		var seg_dir: Vector2 = (rp[seg + 1] - rp[seg]).normalized()
		var score: float = float(c["dist"]) + (1.0 - absf(seg_dir.dot(heading))) * 10.0
		if score < best_score:
			best_score = score
			best = c
			best_pts = rp
	if best.is_empty():
		var d: Vector2 = (last - prev).normalized()
		out.append(last + d * metres)
		return out
	# chiều đi tiếp: đầu polyline nào xa `prev` hơn
	var seg: int = int(best["seg"])
	var forward: bool = best_pts[best_pts.size() - 1].distance_to(prev) > best_pts[0].distance_to(prev)
	var cur: Vector2 = best["point"]
	var left: float = metres
	var idx: int = seg + 1 if forward else seg
	while left > 0.0 and idx >= 0 and idx < best_pts.size():
		var nxt: Vector2 = best_pts[idx]
		var d: float = cur.distance_to(nxt)
		if d >= left:
			out.append(cur + (nxt - cur).normalized() * left)
			return out
		out.append(nxt)
		left -= d
		cur = nxt
		idx += 1 if forward else -1
	if left > 0.0 and out.size() >= 2:
		var d2: Vector2 = (out[out.size() - 1] - out[out.size() - 2]).normalized()
		out.append(out[out.size() - 1] + d2 * left)
	return out


func _road_by_id(id: int) -> Dictionary:
	for r: Dictionary in md.roads():
		if int(r.get("id", 0)) == id:
			return r
	return {}


## Điểm gần nhất trên polyline: {point, seg, t, dist, s (khoảng cách dọc polyline tới điểm đó)}.
static func _closest_on_polyline(pts: PackedVector2Array, p: Vector2) -> Dictionary:
	var best: Dictionary = {"point": pts[0] if pts.size() > 0 else p, "seg": 0, "t": 0.0, "dist": INF, "s": 0.0}
	var cum: float = 0.0
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		var d: float = c.distance_to(p)
		var seg_len: float = a.distance_to(b)
		if d < float(best["dist"]):
			var t: float = 0.0 if seg_len < 1e-6 else a.distance_to(c) / seg_len
			best = {"point": c, "seg": i, "t": t, "dist": d, "s": cum + t * seg_len}
		cum += seg_len
	return best


## Bo tròn các góc: thay đỉnh có góc rẽ >= 12° bằng cung tròn bán kính min(r_max, 0.4 x cạnh ngắn hơn).
static func _fillet_corners(pts: PackedVector2Array, r_max: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i: int in range(1, pts.size() - 1):
		var v: Vector2 = pts[i]
		var d_in: Vector2 = v - pts[i - 1]
		var d_out: Vector2 = pts[i + 1] - v
		var l_in: float = d_in.length()
		var l_out: float = d_out.length()
		if l_in < 0.01 or l_out < 0.01:
			continue
		d_in /= l_in
		d_out /= l_out
		var theta: float = d_in.angle_to(d_out)
		var a: float = absf(theta)
		var r: float = minf(r_max, 0.4 * minf(l_in, l_out))
		if a < deg_to_rad(12.0) or a > deg_to_rad(150.0) or r < 0.8:
			out.append(v)
			continue
		var t: float = r * tan(a * 0.5)
		var p_a: Vector2 = v - d_in * t
		var c: Vector2 = v + (d_out - d_in).normalized() * (r / cos(a * 0.5))
		var a0: float = (p_a - c).angle()
		var steps: int = maxi(2, ceili(a / deg_to_rad(12.0)))
		for k: int in range(steps + 1):
			var ang: float = a0 + theta * float(k) / float(steps)
			out.append(c + Vector2(cos(ang), sin(ang)) * r)
	out.append(pts[pts.size() - 1])
	return out


## Chia nhỏ các đoạn dài hơn `step` (giữ nguyên mọi đỉnh) – cùng thuật toán MapBuilder._resample.
static func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	if step <= 0.0 or pts.size() < 2:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i: int in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var c: Vector2 = pts[i]
		var n: int = maxi(1, ceili(a.distance_to(c) / step))
		for k: int in range(1, n + 1):
			out.append(a.lerp(c, float(k) / float(n)))
	return out


## Profile cầu của MapBuilder (bridge == true, lanes > 0): polyline lấy mẫu 8 m + độ cao từng đỉnh
## (BRIDGE_H x dốc tuyến tính BRIDGE_RAMP_M hai đầu). Mặt cầu MapBuilder nội suy tuyến tính giữa các đỉnh này.
func _collect_bridge_profiles() -> Array:
	var out: Array = []
	if md == null:
		return out
	for r: Dictionary in md.roads():
		if not bool(r.get("bridge", false)) or int(r.get("lanes", 0)) <= 0:
			continue
		var rs: PackedVector2Array = _resample(MapData.poly(r.get("points", [])), MapBuilder.RIBBON_STEP_M)
		if rs.size() < 2:
			continue
		var total: float = 0.0
		for i: int in range(1, rs.size()):
			total += rs[i - 1].distance_to(rs[i])
		var h := PackedFloat32Array()
		h.resize(rs.size())
		var s: float = 0.0
		for i: int in range(rs.size()):
			if i > 0:
				s += rs[i - 1].distance_to(rs[i])
			h[i] = MapBuilder.BRIDGE_H * clampf(minf(s, total - s) / MapBuilder.BRIDGE_RAMP_M, 0.0, 1.0)
		out.append([rs, h])
	return out


## Chèn hình chiếu các đỉnh profile cầu vào polyline tuyến (để curve có đỉnh đúng chỗ mặt cầu gãy khúc).
func _insert_bridge_vertices(pts: PackedVector2Array) -> PackedVector2Array:
	var inserts: Dictionary = {}   # seg -> Array[[t, point]]
	for bp: Array in _bridge_profiles:
		var rs: PackedVector2Array = bp[0]
		for v: Vector2 in rs:
			var c: Dictionary = _closest_on_polyline(pts, v)
			if float(c["dist"]) > 4.5:
				continue
			var seg: int = int(c["seg"])
			var t: float = float(c["t"])
			if t < 0.02 or t > 0.98:
				continue
			if not inserts.has(seg):
				inserts[seg] = []
			(inserts[seg] as Array).append([t, c["point"]])
	if inserts.is_empty():
		return pts
	var out := PackedVector2Array()
	for i: int in range(pts.size() - 1):
		out.append(pts[i])
		if inserts.has(i):
			var list: Array = inserts[i]
			list.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
			for e: Array in list:
				out.append(e[1])
	out.append(pts[pts.size() - 1])
	return out


## Độ cao mặt cầu (0 nếu không trên cầu) tại điểm xz – nội suy tuyến tính như mặt cầu MapBuilder.
func _bridge_height(p: Vector2) -> float:
	var best: float = 0.0
	for bp: Array in _bridge_profiles:
		var rs: PackedVector2Array = bp[0]
		var h: PackedFloat32Array = bp[1]
		var c: Dictionary = _closest_on_polyline(rs, p)
		if float(c["dist"]) > 4.5:
			continue
		var seg: int = int(c["seg"])
		var t: float = float(c["t"])
		best = maxf(best, lerpf(h[seg], h[seg + 1], t))
	return best


# ===========================================================================
# BỀ RỘNG ĐƯỜNG / MỘT CHIỀU THEO OFFSET
# ===========================================================================
func _build_width_profile() -> void:
	width_profile.clear()
	var curve: Curve3D = road_path.curve
	var roads: Array[Dictionary] = md.roads() if md != null else []
	var last_half: float = -1.0
	var last_oneway: bool = false
	var last_rid: int = -1
	var n: int = _polyline.size()
	for i: int in range(n):
		var p: Vector2 = _polyline[i]
		var off: float = curve.get_closest_offset(Vector3(p.x, _heights[i], p.y))
		# hướng tuyến tại mẫu: đường cắt ngang ở ngã ba/ngã tư (cũng cách 0 m) không được chọn thay đường đang đi
		var route_dir: Vector2 = (_polyline[mini(i + 1, n - 1)] - _polyline[maxi(i - 1, 0)]).normalized()
		var half: float = DEFAULT_HALF_W
		var oneway: bool = false
		var rid: int = 0
		var best_score: float = ROAD_MATCH_M
		for r: Dictionary in roads:
			if int(r.get("lanes", 0)) <= 0:
				continue
			var rp: PackedVector2Array = MapData.poly(r.get("points", []))
			if rp.size() < 2:
				continue
			# lọc nhanh theo bbox
			var bb: Rect2 = _bbox(rp).grow(ROAD_MATCH_M)
			if not bb.has_point(p):
				continue
			var c: Dictionary = _closest_on_polyline(rp, p)
			var d: float = float(c["dist"])
			if d >= ROAD_MATCH_M:
				continue
			var seg: int = int(c["seg"])
			var seg_dir: Vector2 = (rp[seg + 1] - rp[seg]).normalized()
			var score: float = d + (1.0 - absf(seg_dir.dot(route_dir))) * 10.0
			if score < best_score:
				best_score = score
				half = maxf(MIN_HALF_W, float(r.get("width", 6.0)) * 0.5)
				oneway = bool(r.get("oneway", false))
				rid = int(r.get("id", 0))
		if i == 0 or absf(half - last_half) > 0.01 or oneway != last_oneway or rid != last_rid:
			width_profile.append([off, half, oneway, rid])
			last_half = half
			last_oneway = oneway
			last_rid = rid
	# đoạn nối từ spawn ra đường (chưa khớp đường nào) dùng bề rộng mặc định
	if width_profile.is_empty():
		width_profile.append([0.0, DEFAULT_HALF_W, false, 0])


func _profile_entry(offset: float) -> Array:
	var n: int = width_profile.size()
	if n == 0:
		return [0.0, DEFAULT_HALF_W, false, 0]
	var i: int = clampi(_profile_idx, 0, n - 1)
	while i > 0 and float(width_profile[i][0]) > offset:
		i -= 1
	while i < n - 1 and float(width_profile[i + 1][0]) <= offset:
		i += 1
	_profile_idx = i
	return width_profile[i]


## Nửa bề rộng lòng đường (m) tại offset curve (đường 6 m -> 3,0; Nguyễn Xiển 8 m -> 4,0; D1 10,5 m -> 5,25).
func half_width_at(offset: float) -> float:
	return float(_profile_entry(offset)[1])


## Giới hạn cứng kẹp làn (m) tại offset: nửa bề rộng + HARD_MARGIN.
func hard_limit_at(offset: float) -> float:
	return half_width_at(offset) + HARD_MARGIN


## True khi đoạn đường tại offset là đường một chiều (không có xe ngược chiều).
func is_oneway_at(offset: float) -> bool:
	return bool(_profile_entry(offset)[2])


## Các đoạn một chiều [start, end] theo offset (m), tăng dần.
func oneway_ranges() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var total: float = road_path.curve.get_baked_length() if road_path and road_path.curve else 0.0
	for i: int in range(width_profile.size()):
		if not bool(width_profile[i][2]):
			continue
		var s: float = float(width_profile[i][0])
		var e: float = float(width_profile[i + 1][0]) if i + 1 < width_profile.size() else total
		if not out.is_empty() and absf(out[out.size() - 1].y - s) < 0.5:
			out[out.size() - 1] = Vector2(out[out.size() - 1].x, e)
		else:
			out.append(Vector2(s, e))
	return out


# ===========================================================================
# MỐC THẬT TRÊN TUYẾN (offset curve)
# ===========================================================================
func _build_route_marks() -> void:
	sections.clear()
	route_marks.clear()
	var curve: Curve3D = road_path.curve
	var end_off: float = curve.get_baked_length()
	route_marks["finish"] = finish_offset
	route_marks["end"] = end_off
	if md == null:
		return
	var raw: PackedVector2Array = md.route_points(0.0)
	var rroads: Array = (md.data.get("route_be6_to_fptu", {}) as Dictionary).get("roads", [])
	var cum: float = 0.0
	for entry: Variant in rroads:
		if not (entry is Array) or (entry as Array).size() < 2:
			continue
		var name: String = str(entry[0])
		var length: float = float(entry[1])
		var o0: float = _offset_of_raw_distance(raw, cum, curve)
		var o1: float = _offset_of_raw_distance(raw, cum + length, curve)
		sections.append({"name": name, "start": o0, "end": o1})
		cum += length
	route_marks["hai_dang_end"] = section_offset("Hải Đăng", true)
	route_marks["cau_vong_5_start"] = section_offset("Cầu Vồng 5")
	route_marks["nguyen_xien"] = section_offset("Nguyễn Xiển")
	route_marks["bridge_start"] = section_offset("Cầu Rạch Hầm")
	route_marks["bridge_end"] = section_offset("Cầu Rạch Hầm", true)
	route_marks["nvt_start"] = section_offset("Nguyễn Văn Tăng")
	route_marks["nvt_end"] = section_offset("Nguyễn Văn Tăng", true)
	route_marks["so12_start"] = section_offset("Đường số 12")
	route_marks["d2b_start"] = section_offset("D2B")
	route_marks["d2b_end"] = section_offset("D2B", true, true)
	route_marks["roundabout"] = section_offset("primary_link")
	route_marks["d1_start"] = section_offset("Đường D1")
	route_marks["bus_stop"] = _first_bus_stop_offset(curve)
	zones = [
		[0.0, "VINHOMES GRAND PARK · THE BEVERLY (BE6)"],
		[route_marks["hai_dang_end"], "VINHOMES GRAND PARK · D2A → N2 → ANH ĐÀO 5"],
		[route_marks["cau_vong_5_start"], "ĐƯỜNG CẦU VỒNG 5 (RA KHỎI VINHOMES)"],
		[route_marks["nguyen_xien"], "NGUYỄN XIỂN & CẦU RẠCH HẦM"],
		[route_marks["nvt_start"], "NGUYỄN VĂN TĂNG (THẲNG TẮP – LÁCH SÁT XE)"],
		[route_marks["so12_start"], "ĐƯỜNG SỐ 12 → HÀNG TRE (QUANH CO)"],
		[route_marks["d2b_start"], "ĐƯỜNG D2B – KHU CÔNG NGHỆ CAO SHTP"],
		[route_marks["roundabout"], "VÒNG XOAY D2B - D1 (RẼ PHẢI VÀO ĐƯỜNG D1)"],
		[route_marks["d1_start"], "ĐƯỜNG D1 – ĐH FPT (BÊN PHẢI) & HUTECH (BÊN TRÁI)"],
	]
	var cleaned: Array = []
	for z: Array in zones:
		if float(z[0]) >= 0.0:
			cleaned.append(z)
	cleaned.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	zones = cleaned


## Offset curve của đầu (hoặc cuối) đoạn đường có tên chứa `name_part` (lần đầu, hoặc lần cuối); -1 nếu không có
## hoặc điểm đó không nằm trên tuyến lái (đoạn đầu lộ trình OSM đã được thay bằng lối ra từ BE6).
func section_offset(name_part: String, at_end: bool = false, last: bool = false) -> float:
	var found: float = -1.0
	for s: Dictionary in sections:
		if str(s["name"]).findn(name_part) < 0:
			continue
		found = float(s["end"] if at_end else s["start"])
		if not last:
			break
	return found


func _offset_of_raw_distance(raw: PackedVector2Array, dist: float, curve: Curve3D) -> float:
	var p: Vector2 = _point_at_distance(raw, dist)
	var w := Vector3(p.x, MapBuilder.ROAD_Y + _bridge_height(p), p.y)
	var off: float = curve.get_closest_offset(w)
	if curve.sample_baked(off).distance_to(w) > 8.0:
		return -1.0
	return off


static func _point_at_distance(pts: PackedVector2Array, dist: float) -> Vector2:
	var left: float = maxf(0.0, dist)
	for i: int in range(1, pts.size()):
		var d: float = pts[i - 1].distance_to(pts[i])
		if left <= d:
			return pts[i - 1].lerp(pts[i], 0.0 if d < 1e-6 else left / d)
		left -= d
	return pts[pts.size() - 1] if pts.size() > 0 else Vector2.ZERO


## Offset của trạm xe buýt (POI bus_stop) đầu tiên nằm sát tuyến (< 25 m) trong 1,2 km đầu; -1 nếu không có.
func _first_bus_stop_offset(curve: Curve3D) -> float:
	var best: float = -1.0
	for p: Dictionary in md.pois():
		if str(p.get("kind", "")) != "bus_stop":
			continue
		var w := Vector3(float(p.get("x", 0.0)), MapBuilder.ROAD_Y, float(p.get("z", 0.0)))
		var off: float = curve.get_closest_offset(w)
		if off < 60.0 or off > 1200.0:
			continue
		if curve.sample_baked(off).distance_to(w) > 25.0:
			continue
		if best < 0.0 or off < best:
			best = off
	return best


static func _bbox(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		r = r.expand(p)
	return r


# ===========================================================================
# THẾ GIỚI
# ===========================================================================
func _build_world() -> void:
	_build_ground()
	if md == null:
		return
	var t0: int = Time.get_ticks_msec()
	_build_road_grid()
	var corridor_map: Node3D = MapBuilder.build_region(scenery_root, md, "corridor", {"labels": false, "lod": 1, "palms": GameFX.art_style == "vice", "palm_verge": 7.5})
	var vin_map: Node3D = MapBuilder.build_region(scenery_root, md, "vinhomes", {"lod": 2, "trees": false, "labels": false})
	var campus_map: Node3D = MapBuilder.build_region(scenery_root, md, "campus", {"skip_building_ids": CAMPUS_SKIP_BUILDINGS, "labels": false, "areas": false})
	_build_campus_areas(campus_map)
	var detail: Node3D = _dress_route_roads()
	for region_root: Node3D in [corridor_map, vin_map, campus_map]:
		if region_root:
			_cut_kerb_mesh(region_root.get_node_or_null("Kerbs") as MeshInstance3D, 1)
			_cut_kerb_mesh(region_root.get_node_or_null("RoadLines") as MeshInstance3D, 2)
	for road_mi: Node in detail.get_children():
		_cut_kerb_mesh(road_mi.get_node_or_null("Kerbs") as MeshInstance3D, 1)
		_cut_kerb_mesh(road_mi.get_node_or_null("Lines") as MeshInstance3D, 2)
	_detail_start_buildings()
	# Campus FPTU v8 trên lô đất thật + HUTECH đối diện (cùng hệ cục bộ -> cùng góc quay)
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	FPTUCampusBuilder.build_authentic_campus(scenery_root, xf.origin, FPTUCampusBuilder.REAL_ROT_Y_DEG, {"colliders": false, "palms": GameFX.art_style == "vice", "d1_palms": false})
	# draw_d1 = false: MapBuilder already draws the real Đường D1; HUTECH's own far-D1 strip would double the asphalt
	var hutech: Node3D = FPTUCampusBuilder.build_hutech(scenery_root, xf * FPTUCampusBuilder.hutech_origin_local(), FPTUCampusBuilder.make_materials(), false, false)
	if hutech:
		hutech.rotation_degrees.y = FPTUCampusBuilder.REAL_ROT_Y_DEG
	_build_finish_line()
	_build_bus_stop()
	_build_roadside_trees()
	print("RoadManager: world built in %d ms" % (Time.get_ticks_msec() - t0))


# ---------------------------------------------------------------------------
# Lưới đoạn đường (ô ROAD_GRID_CELL m) để hỏi nhanh "điểm này có nằm trong lòng đường nào không"
# ---------------------------------------------------------------------------
func _build_road_grid() -> void:
	_grid_roads.clear()
	_road_grid.clear()
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 0)) <= 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts.size() < 2:
			continue
		var ri: int = _grid_roads.size()
		_grid_roads.append([pts, float(r.get("width", 6.0)) * 0.5])
		for si: int in range(pts.size() - 1):
			var a: Vector2 = pts[si]
			var b: Vector2 = pts[si + 1]
			var x0: int = floori(minf(a.x, b.x) / ROAD_GRID_CELL) - 1
			var x1: int = floori(maxf(a.x, b.x) / ROAD_GRID_CELL) + 1
			var z0: int = floori(minf(a.y, b.y) / ROAD_GRID_CELL) - 1
			var z1: int = floori(maxf(a.y, b.y) / ROAD_GRID_CELL) + 1
			for cx: int in range(x0, x1 + 1):
				for cz: int in range(z0, z1 + 1):
					var key := Vector2i(cx, cz)
					if not _road_grid.has(key):
						_road_grid[key] = []
					(_road_grid[key] as Array).append(Vector2i(ri, si))


## True khi điểm cách tim một lòng đường (lanes > 0) không quá nửa bề rộng + margin (margin âm = lọt hẳn vào trong).
func _inside_carriageway(p: Vector2, margin: float) -> bool:
	return _carriageway_count(p, margin, 1) >= 1


## Số lòng đường (way khác nhau, lanes > 0) chứa điểm p (tới `needed` thì dừng đếm).
func _carriageway_count(p: Vector2, margin: float, needed: int) -> int:
	var key := Vector2i(floori(p.x / ROAD_GRID_CELL), floori(p.y / ROAD_GRID_CELL))
	if not _road_grid.has(key):
		return 0
	var seen: Dictionary = {}
	for sv: Vector2i in _road_grid[key]:
		if seen.has(sv.x):
			continue
		var road: Array = _grid_roads[sv.x]
		var pts: PackedVector2Array = road[0]
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[sv.y], pts[sv.y + 1])
		if c.distance_to(p) <= float(road[1]) + margin:
			seen[sv.x] = true
			if seen.size() >= needed:
				return seen.size()
	return seen.size()


## MapBuilder kẻ bó vỉa / vạch mép cho từng way; các làn D1 song song chỉ cách nhau 5 m (OSM) nên bó vỉa và vạch
## mép làn này chạy giữa làn kia. Bỏ các tam giác có trọng tâm nằm trong lòng đường của >= `min_count` way
## (bó vỉa: 1 – bó vỉa luôn nằm ngoài làn của chính nó; vạch sơn: 2 – vạch nằm trong làn của nó và một làn khác).
## Mesh và collider (nếu có) được dựng lại từ các tam giác còn lại.
func _cut_kerb_mesh(kerbs: MeshInstance3D, min_count: int = 1) -> void:
	if kerbs == null or kerbs.mesh == null or kerbs.mesh.get_surface_count() == 0:
		return
	var arrays: Array = kerbs.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var has_n: bool = arrays[Mesh.ARRAY_NORMAL] != null
	var has_uv: bool = arrays[Mesh.ARRAY_TEX_UV] != null
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if has_n else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if has_uv else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var indexed: bool = indices.size() > 0
	var tri_count: int = (indices.size() if indexed else verts.size()) / 3
	var keep_v := PackedVector3Array()
	var keep_n := PackedVector3Array()
	var keep_uv := PackedVector2Array()
	var removed: int = 0
	for t: int in range(tri_count):
		var i0: int = indices[t * 3] if indexed else t * 3
		var i1: int = indices[t * 3 + 1] if indexed else t * 3 + 1
		var i2: int = indices[t * 3 + 2] if indexed else t * 3 + 2
		var c: Vector3 = (verts[i0] + verts[i1] + verts[i2]) / 3.0
		if _carriageway_count(Vector2(c.x, c.z), -0.05, min_count) >= min_count:
			removed += 1
			continue
		for i: int in [i0, i1, i2]:
			keep_v.append(verts[i])
			if has_n:
				keep_n.append(normals[i])
			if has_uv:
				keep_uv.append(uvs[i])
	if removed == 0:
		return
	print("RoadManager: %s: %d / %d kerb triangles lay inside a carriageway, removed" % [kerbs.get_path(), removed, tri_count])
	var mat: Material = kerbs.mesh.surface_get_material(0)
	var col: Node = kerbs.get_node_or_null("Col")
	if keep_v.is_empty():
		kerbs.queue_free()
		return
	var mesh := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = keep_v
	if has_n:
		arr[Mesh.ARRAY_NORMAL] = keep_n
	if has_uv:
		arr[Mesh.ARRAY_TEX_UV] = keep_uv
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	kerbs.mesh = mesh
	if col:
		for cs: Node in col.get_children():
			if cs is CollisionShape3D:
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces(keep_v)
				(cs as CollisionShape3D).shape = shape


## Vùng vinhomes dựng ở lod 2 (hộp trơn); các toà quanh điểm spawn (cụm The Beverly, < START_DETAIL_R m) được
## dựng thêm mặt tiền đầy đủ bằng MapBuilder.build_building, nhô 6 cm ngoài hộp để không z-fight với hộp.
func _detail_start_buildings() -> void:
	var sp: Transform3D = md.spawn_transform()
	var spawn := Vector2(sp.origin.x, sp.origin.z)
	var holder := Node3D.new()
	holder.name = "StartBuildingsDetail"
	scenery_root.add_child(holder)
	for b: Dictionary in md.buildings("vinhomes"):
		# Microsoft tube houses are already drawn as clipped, chunked meshes (MapBuilder.msft_footprints): re-building them
		# from the raw outline would double them and push 11 of them onto side-street carriageways.
		if String(b.get("source", "osm")) == "msft":
			continue
		var outer: PackedVector2Array = MapData.poly(b.get("outer", []))
		if outer.size() >= 2 and outer[0].distance_to(outer[outer.size() - 1]) < 0.01:
			outer.remove_at(outer.size() - 1)
		if outer.size() < 3:
			continue
		var c := Vector2.ZERO
		for p: Vector2 in outer:
			c += p
		c /= float(outer.size())
		if c.distance_to(spawn) > START_DETAIL_R:
			continue
		var best := PackedVector2Array()
		var best_area: float = 0.0
		for poly: PackedVector2Array in Geometry2D.offset_polygon(outer, 0.06):
			var area: float = absf(_signed_area(poly))
			if area > best_area:
				best_area = area
				best = poly
		if best.size() < 3:
			continue
		var ring: Array = []
		for p: Vector2 in best:
			ring.append([p.x, p.y])
		ring.append([best[0].x, best[0].y])
		var b2: Dictionary = b.duplicate(true)
		b2["outer"] = ring
		b2["inner"] = []
		var height: float = float(b.get("height", 0.0))
		if height < 1.0:
			height = float(maxi(1, int(b.get("levels", 2)))) * MapBuilder.STOREY_M
		b2["height"] = height + 0.06
		MapBuilder.build_building(holder, b2, {"labels": false, "colliders": false, "lod": 0, "trees": false})


static func _signed_area(ring: PackedVector2Array) -> float:
	var a: float = 0.0
	for i: int in range(ring.size()):
		var p: Vector2 = ring[i]
		var q: Vector2 = ring[(i + 1) % ring.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Hàng cây ven đường dọc toàn tuyến (corridor lod 1 không có cây): 3 mẫu cây PropBuilder bake rồi MultiMesh,
## xen kẽ hai bên cách mép đường ~3 m, bỏ vị trí trúng lòng đường khác / nhà / mặt nước / cầu / lô campus & HUTECH.
func _build_roadside_trees() -> void:
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var tmp := Node3D.new()
	var meshes: Array = []
	for k: int in range(3):
		var mi: MeshInstance3D = PropBuilder.build_tree(tmp, Vector3.ZERO, cm, 1.0 + float(k) * 0.15, 11 + k * 7, true) as MeshInstance3D
		if mi and mi.mesh:
			meshes.append(mi.mesh)
	tmp.free()
	if meshes.is_empty():
		return
	var curve: Curve3D = road_path.curve
	var blds: Array = []   # [Rect2 bbox, PackedVector2Array poly]
	for b: Dictionary in md.buildings():
		var poly: PackedVector2Array = MapData.poly(b.get("outer", []))
		if poly.size() >= 3:
			blds.append([_bbox(poly).grow(1.5), poly])
	var waters: Array = []  # [Rect2 bbox, PackedVector2Array poly_or_line, float half_width (-1 = polygon)]
	for w: Dictionary in md.water():
		if w.has("outer"):
			var poly: PackedVector2Array = MapData.poly(w.get("outer", []))
			if poly.size() >= 3:
				waters.append([_bbox(poly).grow(3.0), poly, -1.0])
		elif w.has("points"):
			var line: PackedVector2Array = MapData.poly(w.get("points", []))
			if line.size() >= 2:
				waters.append([_bbox(line).grow(float(w.get("width", 6.0)) * 0.5 + 3.0), line, float(w.get("width", 6.0)) * 0.5 + 3.0])
	var bus_stop: float = float(route_marks.get("bus_stop", -1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var xforms: Array = [[], [], []]
	var side: float = 1.0
	var off: float = 40.0
	while off < finish_offset - 70.0:
		var hw: float = half_width_at(off)
		var xf: Transform3D = curve.sample_baked_with_rotation(off)
		var p3: Vector3 = xf.origin + xf.basis.x * (side * (hw + 3.0 + rng.randf_range(0.0, 1.2)))
		var p := Vector2(p3.x, p3.z)
		var ok: bool = p3.y < MapBuilder.ROAD_Y + 0.2 and absf(off - bus_stop) > 9.0
		if ok and _inside_carriageway(p, 1.5):
			ok = false
		if ok:
			var local: Vector3 = FPTUCampusBuilder.world_xz_to_local(p)
			if local.x > -20.0 and local.x < FPTUCampusBuilder.PLOT_U + 20.0 and local.z > -52.0 and local.z < FPTUCampusBuilder.PLOT_V + 20.0:
				ok = false
		if ok:
			for bl: Array in blds:
				if (bl[0] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, bl[1]):
					ok = false
					break
		if ok:
			for wt: Array in waters:
				if not (wt[0] as Rect2).has_point(p):
					continue
				if float(wt[2]) < 0.0:
					if Geometry2D.is_point_in_polygon(p, wt[1]):
						ok = false
						break
				elif float(_closest_on_polyline(wt[1], p)["dist"]) <= float(wt[2]):
					ok = false
					break
		if ok:
			var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(p.x, 0.0, p.y))
			(xforms[rng.randi() % meshes.size()] as Array).append(t)
		off += TREE_EVERY_M * rng.randf_range(0.8, 1.2)
		side = -side
	var holder := Node3D.new()
	holder.name = "RouteTrees"
	scenery_root.add_child(holder)
	for k: int in range(meshes.size()):
		var list: Array = xforms[k]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = list.size()
		for i: int in range(list.size()):
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "RouteTrees_%d" % k
		mmi.multimesh = mm
		holder.add_child(mmi)


## Mặt đất toàn cục: va chạm WorldBoundaryShape3D tại y = 0 + mặt cỏ 12 km tại GROUND_Y, khoét lỗ theo hình
## các vùng MapBuilder (vùng đã có Ground riêng khoét quanh mặt nước) để không che kênh rạch / không z-fight.
func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldGround"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	scenery_root.add_child(body)

	var holes: Array = []
	if md != null:
		for region: String in ["vinhomes", "corridor", "campus"]:
			holes.append_array(MapBuilder.region_shape(md, region))
	var hole_boxes: Array = []
	for h: PackedVector2Array in holes:
		hole_boxes.append(_bbox(h))
	var centre := Vector2(2000.0, -200.0)
	var half: float = GROUND_SIZE * 0.5
	var n: int = int(GROUND_SIZE / GROUND_CELL)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: int = 0
	for ix: int in range(n):
		for iz: int in range(n):
			var x0: float = centre.x - half + float(ix) * GROUND_CELL
			var z0: float = centre.y - half + float(iz) * GROUND_CELL
			var rect := Rect2(x0, z0, GROUND_CELL, GROUND_CELL)
			# ngược chiều kim đồng hồ theo quy ước Godot 2D (y xuống) -> lỗ do clip_polygons trả về là cùng chiều KĐH
			var pieces: Array = [PackedVector2Array([Vector2(x0, z0), Vector2(x0, z0 + GROUND_CELL), Vector2(x0 + GROUND_CELL, z0 + GROUND_CELL), Vector2(x0 + GROUND_CELL, z0)])]
			for hi: int in range(holes.size()):
				if not rect.intersects(hole_boxes[hi]):
					continue
				var next: Array = []
				for piece: PackedVector2Array in pieces:
					next.append_array(Geometry2D.clip_polygons(piece, holes[hi]))
				pieces = next
			# các vùng đều lớn hơn 1 ô nên clip không bao giờ sinh lỗ kín trong ô -> mọi mảnh đều là mặt đất
			for piece: PackedVector2Array in pieces:
				if piece.size() < 3:
					continue
				var idx: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
				for k: int in range(0, idx.size(), 3):
					_tri_up(st, piece[idx[k]], piece[idx[k + 1]], piece[idx[k + 2]])
					tris += 1
	if tris == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "WorldGrass"
	mi.mesh = st.commit()
	mi.material_override = MapBuilder.materials()["ground"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = GROUND_Y
	body.add_child(mi)


static func _tri_up(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	var pa := Vector3(a.x, 0.0, a.y)
	var pb := Vector3(b.x, 0.0, b.y)
	var pc := Vector3(c.x, 0.0, c.y)
	# mặt trước Godot cuộn theo chiều kim đồng hồ nhìn từ phía trước: (b-a)x(c-a) phải hướng XUỐNG
	if (pb - pa).cross(pc - pa).y > 0.0:
		var tmp: Vector3 = pb
		pb = pc
		pc = tmp
	st.set_normal(Vector3.UP)
	st.set_uv(a / 8.0)
	st.add_vertex(pa)
	st.set_uv(Vector2(pb.x, pb.z) / 8.0)
	st.add_vertex(pb)
	st.set_uv(Vector2(pc.x, pc.z) / 8.0)
	st.add_vertex(pc)


## Khu đất vùng campus (công viên, sân, bãi xe...) trừ các polygon nằm trong lô FPTU (FPTUCampusBuilder dựng).
func _build_campus_areas(parent: Node3D) -> void:
	if parent == null:
		return
	var plot: PackedVector2Array = MapData.poly(md.landmark("campus_plot") if md.landmark("campus_plot") is Array else [])
	var m: Dictionary = MapBuilder.materials()
	var holder := Node3D.new()
	holder.name = "CampusAreas"
	parent.add_child(holder)
	for a: Dictionary in md.areas("campus"):
		var poly: PackedVector2Array = MapData.poly(a.get("outer", []))
		if poly.size() < 3:
			continue
		if str(a.get("kind", "")) == "other" and float(a.get("area", 0.0)) > MapBuilder.BIG_AREA_SKIP_M2:
			continue
		if plot.size() >= 3:
			var c := Vector2.ZERO
			for p: Vector2 in poly:
				c += p
			c /= float(poly.size())
			if Geometry2D.is_point_in_polygon(c, plot):
				continue
		MapBuilder.build_area(holder, a, m, {"trees": true, "lod": 0, "colliders": false})


## Các đường của lộ trình nằm trong vùng vinhomes (lod 2 = ribbon trơn): dựng lại đủ bó vỉa, vạch, collider
## (nhô 4 mm trên ribbon lod 2, cùng vật liệu triplanar nên không thấy mối nối).
func _dress_route_roads() -> Node3D:
	var done: Dictionary = {}
	var holder := Node3D.new()
	holder.name = "RouteRoadsDetail"
	scenery_root.add_child(holder)
	for entry: Array in width_profile:
		var rid: int = int(entry[3])
		if rid == 0 or done.has(rid):
			continue
		done[rid] = true
		var r: Dictionary = _road_by_id(rid)
		if r.is_empty() or str(r.get("region", "")) != "vinhomes":
			continue
		var w: float = float(r.get("width", 6.0))
		MapBuilder.build_road(holder, MapData.poly(r.get("points", [])), w, {"y": MapBuilder.ROAD_Y + 0.004, "oneway": bool(r.get("oneway", false)), "kerb": w >= MapBuilder.KERB_MIN_ROAD_W, "overlay": w >= MapBuilder.KERB_MIN_ROAD_W, "bridge": bool(r.get("bridge", false)), "colliders": true})
	return holder


func _build_finish_line() -> void:
	var xf: Transform3D = road_path.curve.sample_baked_with_rotation(finish_offset)
	var w: float = half_width_at(finish_offset) * 2.0
	var finish := MeshInstance3D.new()
	var fin_mesh := BoxMesh.new()
	fin_mesh.size = Vector3(w, 0.04, 2.0)
	finish.mesh = fin_mesh
	var mat_fin := StandardMaterial3D.new()
	mat_fin.albedo_color = Color("#FFFFFF")
	mat_fin.emission_enabled = true
	mat_fin.emission = Color("#FFFFFF") * 0.5
	finish.material_override = mat_fin
	scenery_root.add_child(finish)
	finish.global_transform = xf
	finish.global_position = xf.origin + Vector3(0.0, 0.08, 0.0)
	var fin_lbl := Label3D.new()
	fin_lbl.text = "🏁 FINISH – CỔNG CHÍNH ĐH FPT (ĐƯỜNG D1)"
	fin_lbl.font_size = 48
	fin_lbl.outline_size = 14
	fin_lbl.modulate = Color("#F1C40F")
	fin_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fin_lbl.position = xf.origin + Vector3(0.0, 6.5, 0.0)
	scenery_root.add_child(fin_lbl)
	# Cổng chào đích hai bên đường (trụ cam FPT)
	var mat_post := StandardMaterial3D.new()
	mat_post.albedo_color = Color("#F37021")
	mat_post.emission_enabled = true
	mat_post.emission = Color("#F37021") * 0.4
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.18
		pm.bottom_radius = 0.22
		pm.height = 6.0
		post.mesh = pm
		post.material_override = mat_post
		scenery_root.add_child(post)
		post.global_position = xf.origin + xf.basis.x * (side * (w * 0.5 + 1.2)) + Vector3(0.0, 3.0, 0.0)


## Trạm VinBus / F-Bus gần xuất phát (POI bus_stop đầu tiên trên tuyến): trụ + bảng + ghế bên phải đường.
func _build_bus_stop() -> void:
	var off: float = float(route_marks.get("bus_stop", -1.0))
	if off < 0.0:
		return
	var xf: Transform3D = road_path.curve.sample_baked_with_rotation(off)
	var hw: float = half_width_at(off)
	var root := Node3D.new()
	root.name = "BusStop"
	scenery_root.add_child(root)
	root.global_transform = xf
	root.global_position = xf.origin + xf.basis.x * (hw + 1.6)
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var mat_blue := StandardMaterial3D.new()
	mat_blue.albedo_color = Color("#1E6FD9")
	var pole := MeshInstance3D.new()
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.05
	pmesh.bottom_radius = 0.06
	pmesh.height = 3.0
	pole.mesh = pmesh
	pole.material_override = cm["steel"]
	pole.position = Vector3(0.0, 1.5, 0.0)
	root.add_child(pole)
	var plate := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.9, 0.5, 0.06)
	plate.mesh = bmesh
	plate.material_override = mat_blue
	plate.position = Vector3(0.0, 2.7, 0.0)
	root.add_child(plate)
	var shelter := MeshInstance3D.new()
	var smesh := BoxMesh.new()
	smesh.size = Vector3(1.6, 0.08, 4.0)
	shelter.mesh = smesh
	shelter.material_override = cm["white"]
	shelter.position = Vector3(1.2, 2.6, 0.0)
	root.add_child(shelter)
	for z: float in [-1.7, 1.7]:
		var leg := MeshInstance3D.new()
		var lmesh := BoxMesh.new()
		lmesh.size = Vector3(0.08, 2.6, 0.08)
		leg.mesh = lmesh
		leg.material_override = cm["steel"]
		leg.position = Vector3(1.9, 1.3, z)
		root.add_child(leg)
	var bench := MeshInstance3D.new()
	var bmesh2 := BoxMesh.new()
	bmesh2.size = Vector3(0.45, 0.08, 2.4)
	bench.mesh = bmesh2
	bench.material_override = cm["white"]
	bench.position = Vector3(1.6, 0.5, 0.0)
	root.add_child(bench)
	var lbl := Label3D.new()
	lbl.text = "🚌 TRẠM VINBUS · TTTM VINCOM"
	lbl.font_size = 30
	lbl.outline_size = 8
	lbl.modulate = Color("#A5D6A7")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 3.4, 0.0)
	root.add_child(lbl)


func _place_player_at_start() -> void:
	if not player_bike or not road_path.curve:
		return
	var xf: Transform3D = road_path.curve.sample_baked_with_rotation(0.5)
	var fwd: Vector3 = -xf.basis.z
	fwd.y = 0.0
	player_bike.global_position = xf.origin + Vector3(0.0, 0.6, 0.0)
	if fwd.length_squared() > 0.001:
		player_bike.look_at(player_bike.global_position + fwd.normalized(), Vector3.UP)
	player_bike.set("road_half_width", half_width_at(0.0))
	player_bike.set("road_hard_limit", hard_limit_at(0.0))


# ===========================================================================
func _process(delta: float) -> void:
	if not player_bike or has_finished:
		return

	var offset: float = road_path.curve.get_closest_offset(player_bike.global_position)
	remaining_m = maxf(0.0, finish_offset - offset)

	# Kẹp làn theo bề rộng đường thật của đoạn hiện tại (đổi dần để không giật xe khi sang đoạn khác)
	var target_half: float = half_width_at(offset)
	var cur_half: float = float(player_bike.get("road_half_width"))
	var new_half: float = move_toward(cur_half, target_half, WIDTH_BLEND_RATE * delta)
	if absf(new_half - cur_half) > 0.0001:
		player_bike.set("road_half_width", new_half)
		player_bike.set("road_hard_limit", new_half + HARD_MARGIN)

	var new_zone: String = current_zone
	for z: Array in zones:
		if offset >= float(z[0]):
			new_zone = str(z[1])
	if new_zone != current_zone:
		current_zone = new_zone
		emit_signal("zone_changed", current_zone)

	if offset >= finish_offset:
		has_finished = true
		remaining_m = 0.0
		emit_signal("destination_reached")
