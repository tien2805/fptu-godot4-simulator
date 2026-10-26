# File: res://scripts/combat/bike/DriftCourse.gd
# The lap of the Day 2 drift duel (spec D2X-10, plan 2026-10-27-d2x-drift.md) as data: a closed racing line through
# hand-placed map points (x east, z south as Vector2(x, z)), smoothed with a centripetal Catmull-Rom spline and sampled
# every SAMPLE_M, with arc length s and a signed lateral offset d (+ = right of travel). Everything else is keyed to the
# control points: the gates (checkpoints, in order), the drift zones, the cone gates and slaloms, the cone islands of the
# hairpins, the barrier rows and the chevron signs; the rival's speed profile comes from the line's curvature.
# rach_ham(): the measured "Cầu Rạch Hầm" lap (about 1.28 km): the bridge deck -> Nguyễn Xiển north with chicane A -> the
# Y junction (Nguyễn Văn Tăng closed by a barrier) -> Nguyễn Xiển north-east to the open ground at its end -> the teardrop
# hairpin H1 round a cone island -> back south with the wide S of chicane B -> over the bridge -> the south-bank lot
# (slalom, hairpin H2, the sweeper) -> the finish on the bridge deck where it started. Static data only, no nodes.
class_name DriftCourse
extends RefCounted

const SAMPLE_M: float = 2.0
const WINDOW_M: float = 40.0
## Corner radius below which the rival drifts visibly (m).
const DRIFT_R: float = 30.0
## The rival's speed profile: top speed, lateral grip (v = sqrt(A_LAT x R)), braking and acceleration (m/s, m/s^2).
const RIVAL_V_TOP: float = 23.5
const RIVAL_A_LAT: float = 20.0
const RIVAL_BRAKE: float = 12.0
const RIVAL_ACCEL: float = 10.0
## ... and while the player is on his tail or ahead he drifts harder (fight profile).
const RIVAL_A_LAT_FIGHT: float = 30.0

## The lap's control points (map plane). Index comments name the features the tables below refer to.
const RACH_HAM_PTS: Array[Vector2] = [
	Vector2(2125.2, 153.0),    # 0  start / finish: bridge deck middle, northbound lane
	Vector2(2119.7, 133.5),    # 1  bridge north end
	Vector2(2108.0, 96.0),     # 2  Nguyễn Xiển north
	Vector2(2101.2, 71.5),     # 3  chicane A in (east lane)
	Vector2(2091.3, 52.7),     # 4  chicane A west flick
	Vector2(2090.0, 31.3),     # 5  chicane A east flick
	Vector2(2083.7, 12.5),     # 6  chicane A out (Số 19 / Số 21 crossing)
	Vector2(2062.0, -63.0),    # 7  Nguyễn Xiển north
	Vector2(2041.4, -135.5),   # 8  Y junction approach
	Vector2(2041.0, -150.0),   # 9  the bend right (Nguyễn Văn Tăng closed on the left)
	Vector2(2046.5, -163.0),   # 10
	Vector2(2056.0, -174.5),   # 11 Nguyễn Xiển north-east
	Vector2(2068.4, -186.9),   # 12
	Vector2(2087.6, -217.1),   # 13
	Vector2(2106.6, -258.3),   # 14
	Vector2(2120.0, -289.9),   # 15 Nguyễn Xiển north-east, past the lamp posts: the teardrop hairpin H1 (island (2137.9, -336.6))
	Vector2(2130.2, -313.8),   # 16
	Vector2(2137.5, -321.6),   # 17 swing right onto the open ground
	Vector2(2143.9, -327.6),   # 18
	Vector2(2146.2, -333.1),   # 19 east of the island, heading north
	Vector2(2146.3, -340.0),   # 20
	Vector2(2141.5, -344.9),   # 21 the top, heading west
	Vector2(2134.5, -345.0),   # 22
	Vector2(2129.6, -340.2),   # 23 west of the island, heading south
	Vector2(2127.3, -334.6),   # 24
	Vector2(2127.4, -325.9),   # 25 swing back
	Vector2(2126.9, -315.2),   # 26
	Vector2(2117.2, -291.3),   # 27 H1 out, southbound lane
	Vector2(2103.4, -259.7),   # 28
	Vector2(2084.4, -218.9),   # 29
	Vector2(2065.6, -189.1),   # 30
	Vector2(2054.0, -175.5),   # 31 Nguyễn Xiển south-west
	Vector2(2043.5, -166.5),   # 32
	Vector2(2036.0, -154.0),   # 33 the bend left onto Nguyễn Xiển south
	Vector2(2038.6, -135.2),   # 34
	Vector2(2059.3, -62.2),    # 35 Nguyễn Xiển south
	Vector2(2080.3, 14.0),     # 36
	Vector2(2094.6, 60.5),     # 37 chicane B approach (west lane)
	Vector2(2100.6, 82.0),     # 38 chicane B in
	Vector2(2104.6, 103.0),    # 39 chicane B: swing west into the open stretch
	Vector2(2115.0, 115.5),    # 40 chicane B: swing east
	Vector2(2114.2, 126.0),    # 41 chicane B out, straight onto the deck
	Vector2(2116.3, 134.5),    # 42 bridge north end, southbound
	Vector2(2127.3, 173.5),    # 43 bridge south end
	Vector2(2131.5, 187.0),    # 44 Nguyễn Xiển south of the bridge
	Vector2(2136.0, 201.0),    # 45 the left onto the south-bank lot
	Vector2(2145.0, 212.5),    # 46
	Vector2(2158.0, 215.0),    # 47 slalom in
	Vector2(2170.0, 212.0),    # 48 slalom
	Vector2(2182.0, 215.0),    # 49 slalom
	Vector2(2192.0, 213.5),    # 50 H2 in (cone island C2 at (2200, 203))
	Vector2(2203.5, 212.4),    # 51 H2 south-east
	Vector2(2209.0, 203.0),    # 52 H2 east
	Vector2(2204.5, 194.8),    # 53 H2 north-east
	Vector2(2194.0, 193.6),    # 54 H2 out, heading west
	Vector2(2165.0, 193.0),    # 55 the back straight
	Vector2(2147.0, 191.0),    # 56 the sweeper right
	Vector2(2136.5, 185.0),    # 57
	Vector2(2131.4, 175.5),    # 58 bridge south end, northbound
]
## Gates (checkpoints) at these control points, in order; the finish (the lap end) comes after the last one.
const RACH_HAM_GATES: Array[int] = [6, 11, 14, 21, 34, 41, 45, 54]
## Drift zones [first control point, last control point, label].
const RACH_HAM_ZONES: Array = [
	[3, 6, "CHICANE"], [8, 11, "CUA CHỮ Y"], [16, 27, "KẸP TÓC"], [31, 34, "CUA CHỮ Y"], [38, 41, "CHICANE"],
	[46, 50, "SLALOM"], [50, 54, "KẸP TÓC"], [55, 58, "CUA VÒNG"]]
## Cone gates: [control point, half width] (a cone each side of the racing line).
const RACH_HAM_CONE_GATES: Array = [[3, 2.4], [4, 2.4], [5, 2.4], [39, 2.6], [40, 2.6], [41, 2.4]]
## Slalom cones: [control point, lateral offset] (one cone beside the line: the line weaves round it).
const RACH_HAM_SLALOM: Array = [[47, 1.8], [48, -1.8], [49, 1.8], [55, -2.2], [17, 2.6], [25, -2.6]]
## Cone islands (hairpins): centre, radius of the cone ring.
const RACH_HAM_ISLANDS: Array = [[Vector2(2137.9, -336.6), 3.5], [Vector2(2200.0, 203.0), 3.0]]
## Barrier rows [from, to] (physical, block shortcuts): Nguyễn Văn Tăng's mouth at the Y junction, the median of the
## south-bank loop, the lot's south and east edges.
const RACH_HAM_BARRIERS: Array = [
	[Vector2(2027.2, -142.7), Vector2(2020.8, -150.5)],
	[Vector2(2152.0, 203.5), Vector2(2187.0, 203.5)],
	[Vector2(2140.0, 224.0), Vector2(2214.0, 224.0)],
	[Vector2(2218.0, 186.0), Vector2(2218.0, 220.0)],
]
## Chevron boards [position, control point whose travel direction they face]: on the two cone islands and on the barrier
## closing Nguyễn Văn Tăng.
const RACH_HAM_CHEVRONS: Array = [[Vector2(2137.9, -336.6), 16], [Vector2(2200.0, 203.0), 50], [Vector2(2024.0, -146.6), 33]]

var pts := PackedVector2Array()        # sampled racing line (closed: the last sample equals the first)
var cum := PackedFloat32Array()
var length: float = 0.0
var ctrl := PackedVector2Array()       # control points
var ctrl_s := PackedFloat32Array()     # arc length of each control point
var gates := PackedFloat32Array()      # s of each gate; the finish is `length`
var zones: Array = []                  # [s0, s1, label]
var cones: Array = []                  # Vector2 positions
var barriers: Array = []               # [Vector2, Vector2]
var chevrons: Array = []               # [Vector2, yaw]
var islands: Array = []                # [Vector2, radius]
var radius := PackedFloat32Array()     # corner radius at each sample (m, capped at 999)
var speed := PackedFloat32Array()      # the rival's profile speed at each sample (m/s)
var speed_fight := PackedFloat32Array()  # ... with RIVAL_A_LAT_FIGHT


static func rach_ham() -> DriftCourse:
	var c := DriftCourse.new()
	c.build(RACH_HAM_PTS, RACH_HAM_GATES, RACH_HAM_ZONES)
	for g: Array in RACH_HAM_CONE_GATES:
		var i: int = int(g[0])
		var s: float = c.ctrl_s[i]
		c.cones.append(c.world(s, float(g[1])))
		c.cones.append(c.world(s, -float(g[1])))
	for sl: Array in RACH_HAM_SLALOM:
		c.cones.append(c.world(c.ctrl_s[int(sl[0])], float(sl[1])))
	for isl: Array in RACH_HAM_ISLANDS:
		c.islands.append([isl[0], float(isl[1])])
		for k: int in 10:
			var a: float = TAU * float(k) / 10.0
			c.cones.append((isl[0] as Vector2) + Vector2(cos(a), sin(a)) * float(isl[1]))
	for b: Array in RACH_HAM_BARRIERS:
		c.barriers.append([b[0], b[1]])
	for ch: Array in RACH_HAM_CHEVRONS:
		c.chevrons.append([ch[0], c.yaw_at(c.ctrl_s[int(ch[1])])])   # the travel yaw there (the sign faces the rider)
	return c


## Samples the closed spline through `points`, then the gates, zones and the rival's speed profile.
func build(points: Array[Vector2], gate_idx: Array[int], zone_rows: Array) -> void:
	ctrl = PackedVector2Array(points)
	var n: int = ctrl.size()
	pts.clear()
	ctrl_s.resize(n)
	var total: float = 0.0
	pts.append(ctrl[0])
	cum.clear()
	cum.append(0.0)
	for i: int in n:
		ctrl_s[i] = total
		var p0: Vector2 = ctrl[(i - 1 + n) % n]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[(i + 1) % n]
		var p3: Vector2 = ctrl[(i + 2) % n]
		var seg: float = p1.distance_to(p2)
		var steps: int = maxi(2, ceili(seg / SAMPLE_M))
		for k: int in range(1, steps + 1):
			var q: Vector2 = _catmull(p0, p1, p2, p3, float(k) / float(steps))
			total += pts[pts.size() - 1].distance_to(q)
			pts.append(q)
			cum.append(total)
	length = total
	gates.clear()
	for gi: int in gate_idx:
		gates.append(ctrl_s[gi])
	zones.clear()
	for z: Array in zone_rows:
		zones.append([ctrl_s[int(z[0])], ctrl_s[int(z[1])], String(z[2])])
	_profile()


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


## Corner radius per sample (heading change over +/-4 m) and the rival's speed profiles: min(V_TOP, sqrt(a_lat x R)), then
## a braking pass backwards and an acceleration pass forwards (around the closed lap twice).
func _profile() -> void:
	var m: int = pts.size()
	radius.resize(m)
	for i: int in m:
		var s: float = cum[i]
		var ta: Vector2 = tangent(fposmod(s - 4.0, length))
		var tb: Vector2 = tangent(fposmod(s + 4.0, length))
		var ang: float = absf(ta.angle_to(tb))
		radius[i] = minf(999.0, 8.0 / maxf(ang, 1e-4))
	speed = _speeds(RIVAL_A_LAT)
	speed_fight = _speeds(RIVAL_A_LAT_FIGHT)


func _speeds(a_lat: float) -> PackedFloat32Array:
	var m: int = pts.size()
	var sp := PackedFloat32Array()
	sp.resize(m)
	for i: int in m:
		sp[i] = minf(RIVAL_V_TOP, sqrt(a_lat * radius[i]))
	for rep: int in 2:
		for i2: int in range(m - 2, -1, -1):
			var ds: float = cum[i2 + 1] - cum[i2]
			sp[i2] = minf(sp[i2], sqrt(sp[i2 + 1] * sp[i2 + 1] + 2.0 * RIVAL_BRAKE * ds))
		sp[m - 1] = minf(sp[m - 1], sp[0])
	for rep2: int in 2:
		for i3: int in range(1, m):
			var ds2: float = cum[i3] - cum[i3 - 1]
			sp[i3] = minf(sp[i3], sqrt(sp[i3 - 1] * sp[i3 - 1] + 2.0 * RIVAL_ACCEL * ds2))
		sp[0] = minf(sp[0], sp[m - 1])
	return sp


func _seg(s: float) -> int:
	return clampi(cum.bsearch(s, true) - 1, 0, pts.size() - 2)


## s wrapped onto the lap.
func wrap_s(s: float) -> float:
	return fposmod(s, length)


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
	var i: int = _seg(wrap_s(s))
	return radius[i]


func speed_at(s: float, fight: bool = false) -> float:
	var w: float = wrap_s(s)
	var i: int = _seg(w)
	var span: float = maxf(cum[i + 1] - cum[i], 1e-4)
	var sp: PackedFloat32Array = speed_fight if fight else speed
	return lerpf(sp[i], sp[i + 1], clampf((w - cum[i]) / span, 0.0, 1.0))


## The drift zone at s (index into zones), -1 outside.
func zone_at(s: float) -> int:
	for i: int in zones.size():
		var z: Array = zones[i]
		if s >= float(z[0]) and s <= float(z[1]):
			return i
	return -1


## Closest point of the line to p as Vector2(s, d) over the whole lap (s in 0 .. length).
func project_any(p: Vector2) -> Vector2:
	var best_d2: float = INF
	var best_i: int = 0
	var best_u: float = 0.0
	for i: int in pts.size() - 1:
		var r: Vector3 = _seg_closest(p, i)
		if r.z < best_d2:
			best_d2 = r.z
			best_i = i
			best_u = r.y
	return _result(p, best_i, best_u, 0.0)


## Closest point of the line to p as Vector2(s, d), searching only within `window` m of s_hint. s is unwrapped around
## s_hint, so it can go below 0 behind the start line or past `length` over the finish.
func project_near(p: Vector2, s_hint: float, window: float = WINDOW_M) -> Vector2:
	var n: int = pts.size() - 1
	var base: float = s_hint - wrap_s(s_hint)
	var c: int = _seg(wrap_s(s_hint))
	var steps: int = ceili(window / SAMPLE_M) + 1
	var best_d2: float = INF
	var best_i: int = c
	var best_u: float = 0.0
	var best_off: float = 0.0
	for k: int in range(-steps, steps + 1):
		var j: int = c + k
		var off: float = base
		if j < 0:
			j += n
			off -= length
		elif j >= n:
			j -= n
			off += length
		var r: Vector3 = _seg_closest(p, j)
		if r.z < best_d2:
			best_d2 = r.z
			best_i = j
			best_u = r.y
			best_off = off
	return _result(p, best_i, best_u, best_off)


func _result(p: Vector2, i: int, u: float, off: float) -> Vector2:
	var a: Vector2 = pts[i]
	var b: Vector2 = pts[i + 1]
	var t: Vector2 = (b - a).normalized()
	var q: Vector2 = a.lerp(b, u)
	return Vector2(off + cum[i] + (cum[i + 1] - cum[i]) * u, (p - q).dot(Vector2(-t.y, t.x)))


## Vector3(unused, u along segment i, squared distance) of the closest point of segment i to p.
func _seg_closest(p: Vector2, i: int) -> Vector3:
	var a: Vector2 = pts[i]
	var ab: Vector2 = pts[i + 1] - a
	var l2: float = maxf(ab.length_squared(), 1e-6)
	var u: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return Vector3(0.0, u, (a + ab * u).distance_squared_to(p))


## The tightest corner radius of the lap (tests).
func min_radius() -> float:
	var r: float = 999.0
	for v: float in radius:
		r = minf(r, v)
	return r
