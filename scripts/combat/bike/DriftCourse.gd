# File: res://scripts/combat/bike/DriftCourse.gd
# The Day 2 race "Rạch Hầm GP" against Sói Xám as data (Wave 2 Day 2 rework, plan 2026-10-29-w2-day2.md; it replaces the
# 2026-10-27 cone lap on open ground): ONE open racing path on real, lit roads, sampled every SAMPLE_M from a
# centripetal Catmull-Rom spline through map points (x east, z south as Vector2(x, z)), with arc length s and a signed
# lateral offset d (+ = right of travel). No wrap: s runs from the grid (0) to the finish line (`length`), then a short
# run-off over the bridge.
# rach_ham(): the grid mid-deck on the Rạch Hầm bridge, northbound -> Nguyễn Xiển north -> the Y junction (114 degree left
# onto Nguyễn Văn Tăng) -> the lap line at Đường số 20 -> LAPS laps of the real loop Nguyễn Văn Tăng (west) -> the hairpin
# onto Đỗ Thế Diện -> Đường số 20 -> back onto Nguyễn Văn Tăng -> out of the loop (left) after the last lap -> the Y
# junction -> Nguyễn Xiển south -> the finish line mid-deck where the race started (about 2.1 km; measured 2026-10-29: the
# line has 3-4 m clear on both sides, lamps 4-21 m off it, none within 45 m of the bridge).
# Keyed to the path: lap_s (the lap lines), corners (drift corners: [s0, s1, dir (+1 right), label]), gates (reset
# points every GATE_EVERY m), the prop data for DriftRaceProps (arches, arrows, crowds), the half width of the road, and
# the rival's speed profile from the curvature. Static data only, no nodes.
class_name DriftCourse
extends RefCounted

const SAMPLE_M: float = 2.0
const WINDOW_M: float = 40.0
const ANY_WINDOW_M: float = 220.0
const GATE_EVERY: float = 110.0
const LAPS: int = 2
## Corner radius below which a stretch is a drift corner (the rival drifts it visibly).
const DRIFT_R: float = 30.0
## The rival's speed profile: top speed, lateral grip (v = sqrt(A_LAT x R)), braking and acceleration (m/s, m/s^2).
## DriftRival scales it by its difficulty pace.
const RIVAL_V_TOP: float = 27.0
const RIVAL_A_LAT: float = 34.0
const RIVAL_BRAKE: float = 13.0
const RIVAL_ACCEL: float = 11.0
## ... while the player is on his tail or ahead he takes the corners harder (fight profile).
const RIVAL_A_LAT_FIGHT: float = 44.0
## Rounding of sharp vertices (m before and after the vertex; capped at 45 % of the neighbour segments).
const ROUND_M: float = 7.0
const ROUND_MIN_DEG: float = 28.0

## Named places (labels of the corners and the arches).
const P_GRID := Vector2(2123.5, 153.5)        # mid-deck of the Rạch Hầm bridge (grid and finish line)
const P_BRIDGE_N := Vector2(2118.0, 134.1)
const P_J1 := Vector2(2081.7, 12.8)           # Nguyễn Xiển / Đường Số 21
const P_Y := Vector2(2034.0, -155.0)          # the Y junction Nguyễn Xiển / Nguyễn Văn Tăng
const P_LAP := Vector2(1976.0, -107.0)        # Nguyễn Văn Tăng / Đường số 20: the lap line
const P_HAIRPIN := Vector2(1717.0, 38.0)      # Nguyễn Văn Tăng / Đỗ Thế Diện
const P_B := Vector2(1932.0, -159.0)          # Đỗ Thế Diện / Đường số 20
## The loop after the lap line (Nguyễn Văn Tăng west, the hairpin, Đỗ Thế Diện, to Đường số 20); the lap line closes it.
## The hairpin is a hand-placed arc of radius HAIRPIN_R (the bike's drift circle is 8.4 m) through the open plaza where
## Đỗ Thế Diện leaves Nguyễn Văn Tăng: in on the plaza's south side, round to the mouth of Đỗ Thế Diện (measured free).
const HAIRPIN_R: float = 10.0
const LOOP_PTS: Array[Vector2] = [Vector2(1946.0, -80.0), Vector2(1905.0, -44.0), Vector2(1825.0, 24.0), Vector2(1816.0, 30.0),
	Vector2(1803.0, 36.0), Vector2(1789.0, 40.0), Vector2(1775.0, 42.0), Vector2(1757.0, 43.0), Vector2(1745.0, 46.5),
	Vector2(1736.0, 48.6), Vector2(1727.07, 49.07), Vector2(1723.24, 48.31), Vector2(1720.00, 46.14), Vector2(1717.83, 42.90), Vector2(1717.07, 39.07), Vector2(1717.83, 35.24), Vector2(1720.00, 32.00),
	Vector2(1726.0, 25.5), Vector2(1774.0, -17.0), Vector2(1835.0, -71.0), Vector2(1883.0, -111.0), P_B, Vector2(1954.0, -133.0)]
const LOOP_SIDE_FROM: int = 13            # LOOP_PTS from this index on are Đỗ Thế Diện / Đường số 20 (6 m)
## Rounding (m before and after the vertex) of the junction corners: about the radius the junction has room for
## (out-in-out); other sharp vertices take ROUND_M.
const ROUND_AT: Array = [[P_Y, 16.0], [P_B, 11.0], [P_LAP, 9.5]]
## Half widths (m) of the roads: Nguyễn Xiển / Nguyễn Văn Tăng 8 m, Đỗ Thế Diện / Đường số 20 6 m, the deck between its
## parapets about 6 m.
const HW_MAIN: float = 4.0
const HW_SIDE: float = 3.0
const HW_DECK: float = 3.0
const RUNOFF_PTS: Array[Vector2] = [Vector2(2128.9, 173.0), Vector2(2134.5, 193.0)]
const CORNER_LABELS: Array = [[P_Y, "CUA CHỮ Y"], [P_HAIRPIN, "KẸP TÓC"], [P_B, "CUA SỐ 20"], [P_LAP, "VÀO VÒNG"]]

var pts := PackedVector2Array()        # sampled racing line (open), run-off included
var cum := PackedFloat32Array()
var hw := PackedFloat32Array()         # road half width at each sample
var length: float = 0.0                # the finish line (s)
var total: float = 0.0                 # the last sample (run-off end)
var ctrl := PackedVector2Array()       # control points after rounding
var ctrl_s := PackedFloat32Array()
var lap_s := PackedFloat32Array()      # s of each lap line crossing (LAPS of them) and of the loop exit
var gates := PackedFloat32Array()      # reset points, in order (the finish is `length`)
var corners: Array = []                # [s0, s1, dir (+1 right turn, -1 left), label]
var arches: Array = []                 # [s, label facing riders along +s, label on the back]
var arrows: Array = []                 # [s, turn dir, corner index]: yellow road arrows before each corner
var crowds: Array = []                 # [s, side (+1 right of travel), count]
var radius := PackedFloat32Array()     # corner radius at each sample (m, capped at 999)
var speed := PackedFloat32Array()      # the rival's profile speed at each sample (m/s)
var speed_fight := PackedFloat32Array()


static func rach_ham() -> DriftCourse:
	var c := DriftCourse.new()
	var raw: Array[Vector2] = [P_GRID, P_BRIDGE_N, P_J1, P_Y, P_LAP]
	var widths: Array[float] = [HW_DECK, HW_MAIN, HW_MAIN, HW_MAIN, HW_MAIN]
	var marks: Array[int] = []             # raw indices of the lap line crossings
	for lap: int in LAPS:
		marks.append(raw.size() - 1)
		for i: int in LOOP_PTS.size():
			raw.append(LOOP_PTS[i])
			widths.append(HW_MAIN if i < LOOP_SIDE_FROM else HW_SIDE)
		raw.append(P_LAP)
		widths.append(HW_MAIN)
	marks.append(raw.size() - 1)          # the loop exit
	var finish_i: int = raw.size() + 3
	for p: Vector2 in [P_Y, P_J1, P_BRIDGE_N, P_GRID]:
		raw.append(p)
		widths.append(HW_MAIN)
	widths[widths.size() - 2] = HW_DECK     # Nguyễn Xiển's last stretch is the deck: the bridge's north end to the grid
	widths[widths.size() - 1] = HW_DECK
	for p2: Vector2 in RUNOFF_PTS:
		raw.append(p2)
		widths.append(HW_DECK)
	c.build(raw, widths, marks, finish_i)
	return c


## Rounds the sharp vertices, samples the open spline, then laps, corners, gates, prop data and the rival's profile.
func build(raw: Array[Vector2], widths: Array[float], lap_marks: Array[int], finish_i: int) -> void:
	# rounding: each vertex turning more than ROUND_MIN_DEG becomes two points ROUND_M before and after it
	var rp: Array[Vector2] = []
	var rw: Array[float] = []
	var map_i: Array[int] = []            # raw index -> first rounded index
	for i: int in raw.size():
		map_i.append(rp.size())
		if i == 0 or i == raw.size() - 1:
			rp.append(raw[i])
			rw.append(widths[i])
			continue
		var a: Vector2 = raw[i - 1]
		var b: Vector2 = raw[i]
		var e: Vector2 = raw[i + 1]
		var t_in: Vector2 = (b - a).normalized()
		var t_out: Vector2 = (e - b).normalized()
		var ang: float = absf(t_in.angle_to(t_out))
		if rad_to_deg(ang) < ROUND_MIN_DEG:
			rp.append(b)
			rw.append(widths[i])
			continue
		var seg: float = minf(a.distance_to(b), b.distance_to(e))
		if seg < 10.0:                       # a hand-placed arc (the hairpin): kept as it is
			rp.append(b)
			rw.append(widths[i])
			continue
		var want: float = ROUND_M
		for ra: Array in ROUND_AT:
			if (ra[0] as Vector2).distance_to(b) < 1.0:
				want = float(ra[1])
		var r: float = minf(want, seg * 0.45)
		rp.append(b - t_in * r)
		rw.append(widths[i - 1] if i > 0 else widths[i])
		rp.append(b + t_out * r)
		rw.append(widths[i])
	ctrl = PackedVector2Array(rp)
	var n: int = ctrl.size()
	pts.clear()
	cum.clear()
	hw.clear()
	ctrl_s.resize(n)
	var acc: float = 0.0
	pts.append(ctrl[0])
	cum.append(0.0)
	hw.append(rw[0])
	for i: int in n - 1:
		ctrl_s[i] = acc
		var p0: Vector2 = ctrl[i - 1] if i > 0 else ctrl[0] * 2.0 - ctrl[1]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[i + 2] if i + 2 < n else ctrl[n - 1] * 2.0 - ctrl[n - 2]
		var steps: int = maxi(2, ceili(p1.distance_to(p2) / SAMPLE_M))
		for k: int in range(1, steps + 1):
			var q: Vector2 = _catmull(p0, p1, p2, p3, float(k) / float(steps))
			acc += pts[pts.size() - 1].distance_to(q)
			pts.append(q)
			cum.append(acc)
			hw.append(rw[i])
	ctrl_s[n - 1] = acc
	total = acc
	length = _raw_s(map_i, finish_i)
	lap_s.clear()
	for m: int in lap_marks:
		lap_s.append(_raw_s(map_i, m))
	_profile()
	_corners()
	gates.clear()
	var g: float = GATE_EVERY
	while g < length - 30.0:
		gates.append(g)
		g += GATE_EVERY
	_props()


## s of a raw point (its rounded twin pair: the midpoint of the two).
func _raw_s(map_i: Array[int], i: int) -> float:
	var a: int = map_i[i]
	var b: int = map_i[i + 1] - 1 if i + 1 < map_i.size() else ctrl.size() - 1
	return (ctrl_s[a] + ctrl_s[b]) * 0.5


## Centripetal Catmull-Rom (alpha 0.5): no cusps or loops on uneven point spacing.
static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t0: float = 0.0
	var t1: float = t0 + pow(maxf(p0.distance_to(p1), 0.01), 0.5)
	var t2: float = t1 + pow(maxf(p1.distance_to(p2), 0.01), 0.5)
	var t3: float = t2 + pow(maxf(p2.distance_to(p3), 0.01), 0.5)
	var tt: float = lerpf(t1, t2, t)
	var a1: Vector2 = p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	var a2: Vector2 = p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3: Vector2 = p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1: Vector2 = a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	var b2: Vector2 = a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


## Corner radius per sample (heading change over +/-4 m) and the rival's speed profiles: min(V_TOP, sqrt(a_lat x R)), then a
## braking pass backwards and an acceleration pass forwards (open path: from a standing start on the grid).
func _profile() -> void:
	var m: int = pts.size()
	radius.resize(m)
	for i: int in m:
		var s: float = cum[i]
		var ta: Vector2 = tangent(maxf(s - 4.0, 0.0))
		var tb: Vector2 = tangent(minf(s + 4.0, total))
		var ang: float = absf(ta.angle_to(tb))
		var span: float = minf(s + 4.0, total) - maxf(s - 4.0, 0.0)
		radius[i] = minf(999.0, span / maxf(ang, 1e-4))
	speed = _speeds(RIVAL_A_LAT)
	speed_fight = _speeds(RIVAL_A_LAT_FIGHT)


func _speeds(a_lat: float) -> PackedFloat32Array:
	var m: int = pts.size()
	var sp := PackedFloat32Array()
	sp.resize(m)
	for i: int in m:
		sp[i] = minf(RIVAL_V_TOP, sqrt(a_lat * radius[i]))
	for i2: int in range(m - 2, -1, -1):
		var ds: float = cum[i2 + 1] - cum[i2]
		sp[i2] = minf(sp[i2], sqrt(sp[i2 + 1] * sp[i2 + 1] + 2.0 * RIVAL_BRAKE * ds))
	for i3: int in range(1, m):
		var ds2: float = cum[i3] - cum[i3 - 1]
		sp[i3] = minf(sp[i3], sqrt(sp[i3 - 1] * sp[i3 - 1] + 2.0 * RIVAL_ACCEL * ds2))
	return sp


## Drift corners: stretches under DRIFT_R (gaps under 14 m merged), padded 12 m before and 6 m after, labelled by the
## nearest named place.
func _corners() -> void:
	corners.clear()
	var in_c: bool = false
	var s0: float = 0.0
	var s1: float = 0.0
	for i: int in pts.size():
		var tight: bool = radius[i] < DRIFT_R and cum[i] < length
		if tight and not in_c:
			if not corners.is_empty() and cum[i] - float(corners.back()[1]) < 12.0:   # padded windows overlap: one corner
				var last: Array = corners.pop_back()
				s0 = float(last[0])
			else:
				s0 = maxf(0.0, cum[i] - 12.0)
			in_c = true
		elif not tight and in_c:
			in_c = false
			s1 = minf(length, cum[i] + 6.0)
			corners.append([s0, s1, 0.0, ""])
	for c: Array in corners:
		var a: Vector2 = tangent(float(c[0]))
		var b: Vector2 = tangent(float(c[1]))
		c[2] = 1.0 if a.cross(b) > 0.0 else -1.0     # x east, z south: a positive cross is a right turn
		var mid: Vector2 = point((float(c[0]) + float(c[1])) * 0.5)
		var best: float = 40.0
		c[3] = "CUA GẮT"
		for lb: Array in CORNER_LABELS:
			var dd: float = (lb[0] as Vector2).distance_to(mid)
			if dd < best:
				best = dd
				c[3] = String(lb[1])


## Prop data: the arches (grid / finish, the Y junction, the lap line, the hairpin), the road arrows before every corner,
## the pack's spots on the outside of the corners and along the grid.
func _props() -> void:
	arches.clear()
	arrows.clear()
	crowds.clear()
	arches.append([0.0, "BẦY SÓI GP", "VỀ ĐÍCH"])
	arches.append([s_near(P_Y, 300.0) - 26.0, "CUA CHỮ Y", "VỀ CẦU RẠCH HẦM"])
	arches.append([lap_s[0] + 14.0, "VÒNG ĐUA", ""])
	arches.append([s_near(P_HAIRPIN, lap_s[0] + 300.0) - 30.0, "KẸP TÓC", ""])
	for ci: int in corners.size():
		var c: Array = corners[ci]
		for k: int in 3:
			arrows.append([float(c[0]) - 4.0 - 9.0 * float(k), float(c[2]), ci])
		var apex: float = (float(c[0]) + float(c[1])) * 0.5
		if apex < lap_s[1] + 30.0:           # one pack per place (lap 2 rides past the same people)
			crowds.append([apex, -float(c[2]), 7])
	crowds.append([30.0, 1.0, 6])
	crowds.append([30.0, -1.0, 6])
	crowds.append([lap_s[0] + 150.0, 1.0, 5])
	crowds.append([s_near(P_B, lap_s[0] + 500.0) - 120.0, -1.0, 5])


## s of the path sample nearest to p, searching within ANY_WINDOW_M of s_hint.
func s_near(p: Vector2, s_hint: float) -> float:
	return project_any(p, s_hint).x


func _seg(s: float) -> int:
	return clampi(cum.bsearch(s, true) - 1, 0, pts.size() - 2)


## s clamped onto the path (the old closed-lap API name).
func wrap_s(s: float) -> float:
	return clampf(s, 0.0, total)


func point(s: float) -> Vector2:
	var w: float = wrap_s(s)
	var i: int = _seg(w)
	var span: float = maxf(cum[i + 1] - cum[i], 1e-4)
	return pts[i].lerp(pts[i + 1], clampf((w - cum[i]) / span, 0.0, 1.0))


func tangent(s: float) -> Vector2:
	var i: int = _seg(wrap_s(s))
	return (pts[i + 1] - pts[i]).normalized()


## Right-hand normal of the travel direction (x east, z south: facing north, right = east).
func right(s: float) -> Vector2:
	var t: Vector2 = tangent(s)
	return Vector2(-t.y, t.x)


func world(s: float, d: float) -> Vector2:
	return point(s) + right(s) * d


## Map yaw (radians, Godot: 0 faces -Z) of the travel direction at s.
func yaw_at(s: float) -> float:
	var t: Vector2 = tangent(s)
	return atan2(-t.x, -t.y)


func radius_at(s: float) -> float:
	return radius[_seg(wrap_s(s))]


func half_width_at(s: float) -> float:
	return hw[_seg(wrap_s(s))]


func speed_at(s: float, fight: bool = false) -> float:
	var w: float = wrap_s(s)
	var i: int = _seg(w)
	var span: float = maxf(cum[i + 1] - cum[i], 1e-4)
	var sp: PackedFloat32Array = speed_fight if fight else speed
	return lerpf(sp[i], sp[i + 1], clampf((w - cum[i]) / span, 0.0, 1.0))


## The lap at s: 0 before the first lap line, 1..LAPS on the laps, LAPS + 1 on the way back to the finish.
func lap_at(s: float) -> int:
	for i: int in lap_s.size():
		if s < lap_s[i]:
			return i
	return lap_s.size()


## The drift corner at s (index into corners), -1 outside.
func corner_at(s: float) -> int:
	for i: int in corners.size():
		var c: Array = corners[i]
		if s >= float(c[0]) and s <= float(c[1]):
			return i
	return -1


## The old closed-lap name of corner_at (drift zones).
func zone_at(s: float) -> int:
	return corner_at(s)


## Closest point of the line to p as Vector2(s, d), searching only within `window` m of s_hint (the path crosses the same
## roads several times: never search it all).
func project_near(p: Vector2, s_hint: float, window: float = WINDOW_M) -> Vector2:
	var c: int = _seg(wrap_s(s_hint))
	var steps: int = ceili(window / SAMPLE_M) + 1
	var best_d2: float = INF
	var best_i: int = c
	var best_u: float = 0.0
	for j: int in range(maxi(0, c - steps), mini(pts.size() - 2, c + steps) + 1):
		var r: Vector2 = _seg_closest(p, j)
		if r.y < best_d2:
			best_d2 = r.y
			best_i = j
			best_u = r.x
	return _result(p, best_i, best_u)


## project_near over a wide window (after a teleport or far off the line).
func project_any(p: Vector2, s_hint: float = 0.0) -> Vector2:
	return project_near(p, s_hint, ANY_WINDOW_M)


func _result(p: Vector2, i: int, u: float) -> Vector2:
	var a: Vector2 = pts[i]
	var b: Vector2 = pts[i + 1]
	var t: Vector2 = (b - a).normalized()
	var q: Vector2 = a.lerp(b, u)
	return Vector2(cum[i] + (cum[i + 1] - cum[i]) * u, (p - q).dot(Vector2(-t.y, t.x)))


## Vector2(u along segment i, squared distance) of the closest point of segment i to p.
func _seg_closest(p: Vector2, i: int) -> Vector2:
	var a: Vector2 = pts[i]
	var ab: Vector2 = pts[i + 1] - a
	var l2: float = maxf(ab.length_squared(), 1e-6)
	var u: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return Vector2(u, (a + ab * u).distance_squared_to(p))


## The tightest corner radius of the race (tests).
func min_radius() -> float:
	var r: float = 999.0
	for i: int in pts.size():
		if cum[i] <= length:
			r = minf(r, radius[i])
	return r


## The rival's full-pace time from the grid to the finish (tests, tuning; standing start).
func pace_time(fight: bool = false) -> float:
	var t: float = 0.0
	var s: float = 0.0
	while s < length:
		t += SAMPLE_M / maxf(speed_at(s + 1.0, fight), 2.0)
		s += SAMPLE_M
	return t
