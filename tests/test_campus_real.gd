# File: res://tests/test_campus_real.gd
# Test headless cho FPTUCampusBuilder v8 (campus đặt lên lô đất thật từ assets/data/mapdata.json):
#   - real_plot_transform() đưa 4 góc lô (hệ cục bộ u, v) về đúng 4 đỉnh campus_plot (sai số < 12 m mỗi góc)
#   - cổng chính cục bộ (MAIN_GATE_U, 0, 0) trùng campus_main_gate (< 2 m), cổng tây trùng campus_west_gate (< 3 m)
#   - sân trong vòng nhà (ring) 100..110 m × 48..52 m; hai đầu & mặt trước vòng nhà khớp footprint thật (< 6 m)
#   - bãi xe, sân bóng, HUTECH, cổng sau nằm đúng phía so với dữ liệu thật
#   - real_plot_transform_from() (dự phòng khi không có MapData) cho cùng kết quả
# Chạy:  godot --headless --path . --script tests/test_campus_real.gd   (in ✅ SUCCESS / ❌ FAILED, exit 0 / 1)
extends SceneTree

const CORNER_TOL: float = 12.0
const GATE_TOL: float = 2.0

var _failed: bool = false


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("❌ FAILED: " + msg)
		_failed = true
	return ok


func _nearest_vertex_dist(p: Vector3, plot: PackedVector2Array) -> float:
	var best: float = INF
	for v: Vector2 in plot:
		best = minf(best, Vector2(p.x, p.z).distance_to(v))
	return best


func _dist_to_edges(p: Vector3, plot: PackedVector2Array) -> float:
	var best: float = INF
	var q := Vector2(p.x, p.z)
	for i: int in range(plot.size() - 1):
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(q, plot[i], plot[i + 1])
		best = minf(best, q.distance_to(c))
	return best


func _local_bounds(inv: Transform3D, poly: PackedVector2Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v: Vector2 in poly:
		var l: Vector3 = inv * Vector3(v.x, 0.0, v.y)
		lo = Vector2(minf(lo.x, l.x), minf(lo.y, l.z))
		hi = Vector2(maxf(hi.x, l.x), maxf(hi.y, l.z))
	return Rect2(lo, hi - lo)


func _initialize() -> void:
	_run()
	if _failed:
		quit(1)
	else:
		quit(0)


func _run() -> void:
	var md: MapData = MapData.load_default()
	if not _check(md != null, "mapdata.json must load"):
		return
	var plot: PackedVector2Array = MapData.poly(md.landmark("campus_plot"))
	if not _check(plot.size() == 8, "campus plot has 8 vertices"):
		return
	var gate: Array = md.landmark("campus_main_gate")
	var west: Array = md.landmark("campus_west_gate")
	var gate_w := Vector2(float(gate[0]), float(gate[1]))
	var west_w := Vector2(float(west[0]), float(west[1]))

	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var ux: Vector3 = xf.basis * Vector3(1.0, 0.0, 0.0)
	var expect_ux := Vector3(cos(deg_to_rad(FPTUCampusBuilder.REAL_ROT_Y_DEG)), 0.0, -sin(deg_to_rad(FPTUCampusBuilder.REAL_ROT_Y_DEG)))
	_check(ux.distance_to(expect_ux) < 0.001, "local +u rotated by %.0f deg around Y" % FPTUCampusBuilder.REAL_ROT_Y_DEG)
	_check(is_equal_approx(xf.origin.y, 0.0), "transform stays on the ground plane")

	# 1. Hull match: 4 local corners -> within 12 m of a plot vertex
	var corners: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(FPTUCampusBuilder.PLOT_U, 0.0, 0.0),
		Vector3(FPTUCampusBuilder.PLOT_U, 0.0, FPTUCampusBuilder.PLOT_V),
		Vector3(0.0, 0.0, FPTUCampusBuilder.PLOT_V),
	]
	for c: Vector3 in corners:
		var w: Vector3 = xf * c
		var d: float = _nearest_vertex_dist(w, plot)
		print("  corner %s -> world (%.1f, %.1f), nearest plot vertex %.1f m" % [str(c), w.x, w.z, d])
		_check(d < CORNER_TOL, "plot corner %s must land within %.0f m of a campus_plot vertex (got %.1f)" % [str(c), CORNER_TOL, d])

	# 2. Gates
	var g: Vector3 = xf * FPTUCampusBuilder.main_gate_local()
	var dg: float = Vector2(g.x, g.z).distance_to(gate_w)
	print("  main gate -> (%.2f, %.2f) vs real %s: %.2f m" % [g.x, g.z, str(gate_w), dg])
	_check(dg < GATE_TOL, "main gate must land within 2 m of campus_main_gate")
	var wg: Vector3 = xf * FPTUCampusBuilder.west_gate_local()
	var dw: float = Vector2(wg.x, wg.z).distance_to(west_w)
	print("  west gate -> (%.2f, %.2f) vs real %s: %.2f m" % [wg.x, wg.z, str(west_w), dw])
	_check(dw < 3.0, "west gate must land within 3 m of campus_west_gate")
	var back: Vector3 = xf * FPTUCampusBuilder.back_gate_local()
	var db: float = _dist_to_edges(back, plot)
	print("  back gate -> (%.1f, %.1f): %.1f m from the plot boundary" % [back.x, back.z, db])
	_check(db < 6.0, "back gate sits on the plot boundary (< 6 m from the real edge)")

	# 3. Ring (courtyard) size 100..110 x 48..52; outer ring vs the real footprint
	var court: Rect2 = FPTUCampusBuilder.ring_courtyard_rect()
	print("  courtyard %s" % str(court))
	_check(court.size.x >= 100.0 and court.size.x <= 110.0, "ring length must be 100..110 m")
	_check(court.size.y >= 48.0 and court.size.y <= 52.0, "ring depth must be 48..52 m")
	var outer: Rect2 = FPTUCampusBuilder.ring_outer_rect()
	_check(outer.encloses(court), "outer ring encloses the courtyard")
	var inv: Transform3D = xf.affine_inverse()
	var rb: Rect2 = _local_bounds(inv, MapData.poly(md.landmark("campus_ring_outer")))
	print("  real ring outer in local frame: u %.1f..%.1f  v %.1f..%.1f" % [rb.position.x, rb.end.x, rb.position.y, rb.end.y])
	_check(absf(outer.position.x - rb.position.x) < 6.0 and absf(outer.end.x - rb.end.x) < 6.0, "ring ends match the real footprint along D1")
	_check(absf(outer.position.y - rb.position.y) < 6.0, "ring front face matches the real footprint")
	_check(FPTUCampusBuilder.plot_rect().encloses(outer), "ring lies inside the plot")

	# 4. Parking strip, pitch and HUTECH on the right side of the plot
	var park: Array = md.landmark("campus_parking_center")
	var pk: Vector3 = inv * Vector3(float(park[0]), 0.0, float(park[1]))
	var pl: Vector3 = FPTUCampusBuilder.parking_center_local()
	print("  real parking centre local (%.1f, %.1f) vs model (%.1f, %.1f)" % [pk.x, pk.z, pl.x, pl.z])
	_check(absf(pk.z - pl.z) < 8.0 and absf(pk.x - pl.x) < 20.0, "parking strip lies along the back (NE) edge near the real centre")
	_check(pl.z > FPTUCampusBuilder.RING_V1 and pl.z < FPTUCampusBuilder.PLOT_V, "parking strip is behind the ring, inside the plot")
	var pitch: Array = md.landmark("campus_pitch_center")
	var pc: Vector3 = inv * Vector3(float(pitch[0]), 0.0, float(pitch[1]))
	var pm: Vector3 = FPTUCampusBuilder.pitch_center_local()
	print("  real pitch centre local (%.1f, %.1f) vs model (%.1f, %.1f)" % [pc.x, pc.z, pm.x, pm.z])
	_check(pc.distance_to(pm) < 8.0, "pitch centre within 8 m of the real one")
	var ho: Vector3 = FPTUCampusBuilder.hutech_origin_local()
	_check(ho.z < FPTUCampusBuilder.ROAD_CENTER_V - 7.5, "HUTECH is across D1 (beyond the far kerb)")
	var hb: Rect2 = _local_bounds(inv, MapData.poly(md.landmark("hutech_building")))
	var hc: Vector3 = FPTUCampusBuilder.hutech_block_center_local()
	print("  real HUTECH block local u %.1f..%.1f v %.1f..%.1f; model block centre (%.1f, %.1f)" % [hb.position.x, hb.end.x, hb.position.y, hb.end.y, hc.x, hc.z])
	_check(hb.has_point(Vector2(hc.x, hc.z)), "HUTECH main block centre lies inside the real footprint")

	# 5. Interiors still attached to the ring (Lab 402 / room 311 / canteen / stair inside the right wing & front wing)
	var lab: Vector3 = FPTUCampusBuilder.lab402_room_center()
	_check(lab.x > outer.end.x - FPTUCampusBuilder.SIDE_D and lab.x < outer.end.x and lab.z > outer.position.y and lab.z < outer.position.y + FPTUCampusBuilder.SIDE_MODULE_W, "Lab 402 inside module 0 of the right wing")
	var r311: Vector3 = FPTUCampusBuilder.room311_center()
	_check(r311.z > outer.position.y and r311.z < court.position.y and r311.x > court.position.x and r311.x < court.end.x, "room 311 inside the front wing")
	var cc: Vector3 = FPTUCampusBuilder.canteen_center()
	_check(cc.x > court.position.x and cc.x < court.end.x and absf(cc.z - court.position.y) < 4.0, "canteen on the ground floor of the front wing")
	var sf: Vector3 = FPTUCampusBuilder.stair_foot()
	var st: Vector3 = FPTUCampusBuilder.stair_top()
	_check(sf.x > court.end.x and sf.x < outer.end.x and sf.z > st.z and st.z > outer.position.y, "atrium stair runs inside the right wing from the courtyard door towards D1")
	_check(FPTUCampusBuilder.FRONT_MODULES >= 6 and FPTUCampusBuilder.FRONT_MODULES <= 8, "front wing module count derived from the ring length (6..8)")

	# 6. Fallback without map data
	var xf2: Transform3D = FPTUCampusBuilder.real_plot_transform_from(FPTUCampusBuilder.REAL_MAIN_GATE_XZ)
	_check(xf2.origin.distance_to(xf.origin) < 0.5, "fallback constants reproduce the data-driven transform")

	if not _failed:
		print("✅ SUCCESS: CAMPUS V8 ON THE REAL PLOT OK (corners < %.0f m, gate %.2f m, courtyard %.0fx%.0f m)" % [CORNER_TOL, dg, court.size.x, court.size.y])
