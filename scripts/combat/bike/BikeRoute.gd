# File: res://scripts/combat/bike/BikeRoute.gd
# Road path of a bike chase (spec C-D1) on the map plane (x east, z south as Vector2(x, z)): a polyline with arc length s
# and a signed lateral offset d (positive = right of the travel direction). The AI places its targets with world(s, d)
# and finds the player with project(p, s_hint), which only searches a window around the last s so two close parallel
# legs never swap. nguyen_xien(md) builds the default Day 2 route from the real map data by road name; bridge_s is the
# route distance of the Rạch Hầm bridge's middle (find_bridge_s for any route; -1 = not on it).
class_name BikeRoute
extends RefCounted

const RESAMPLE_M: float = 8.0
const WINDOW_M: float = 60.0
const NX_NAME: String = "Nguyễn Xiển"
const DEFAULT_LEN: float = 2100.0
const BRIDGE_NAME: String = "Rạch Hầm"
const BRIDGE_MAX_D: float = 8.0

var pts := PackedVector2Array()
var cum := PackedFloat32Array()
var length: float = 0.0
var half_width: float = BikeCombatData.ROAD_HALF
var bridge_s: float = -1.0


## Route from points (Vector2(x, z), Vector3 or [x, z] arrays), resampled to <= RESAMPLE_M segments. Duplicates dropped.
static func from_points(points: Variant, half_w: float = BikeCombatData.ROAD_HALF) -> BikeRoute:
	var raw := PackedVector2Array()
	if points is PackedVector2Array:
		raw = points
	elif points is PackedVector3Array:
		for p3: Vector3 in points:
			raw.append(Vector2(p3.x, p3.z))
	elif points is Array:
		for p: Variant in points:
			if p is Vector2:
				raw.append(p)
			elif p is Vector3:
				raw.append(Vector2((p as Vector3).x, (p as Vector3).z))
			elif p is Array and (p as Array).size() >= 2:
				raw.append(Vector2(float(p[0]), float(p[1])))
	var r := BikeRoute.new()
	r.half_width = half_w
	for i: int in raw.size():
		if r.pts.is_empty():
			r.pts.append(raw[i])
			continue
		var a: Vector2 = r.pts[r.pts.size() - 1]
		var b: Vector2 = raw[i]
		var dist: float = a.distance_to(b)
		if dist < 0.05:
			continue
		var n: int = maxi(1, ceili(dist / RESAMPLE_M))
		for k: int in range(1, n + 1):
			r.pts.append(a.lerp(b, float(k) / float(n)))
	r.cum.resize(r.pts.size())
	for i: int in r.pts.size():
		r.cum[i] = 0.0 if i == 0 else r.cum[i - 1] + r.pts[i - 1].distance_to(r.pts[i])
	r.length = r.cum[r.cum.size() - 1] if r.cum.size() > 0 else 0.0
	return r


func valid() -> bool:
	return pts.size() >= 2 and length > 1.0


## Default Day 2 route: Nguyễn Xiển northbound from the south end of its dual carriageway, then the BE6 -> FPTU route from
## where it meets that carriageway (the two-way part, the Rạch Hầm bridge, then Nguyễn Văn Tăng as run-off), cut at
## max_len metres. null when the map has no such road.
static func nguyen_xien(md: MapData, max_len: float = DEFAULT_LEN) -> BikeRoute:
	if md == null:
		return null
	var carriage := PackedVector2Array()
	for r: Dictionary in md.roads():
		if String(r.get("name", "")) != NX_NAME or not bool(r.get("oneway", false)):
			continue
		var p: PackedVector2Array = MapData.poly(r.get("points", []))
		if p.size() >= 2 and p[0].y > p[p.size() - 1].y:   # z falls along it: northbound
			carriage = p
			break
	var route: PackedVector2Array = md.route_points(0.0)
	if carriage.size() < 2 or route.size() < 2:
		return null
	var join: Vector2 = carriage[carriage.size() - 1]
	var best: int = -1
	var best_d: float = 25.0
	for i: int in route.size():
		var d: float = route[i].distance_to(join)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return null
	var out := PackedVector2Array(carriage)
	var total: float = 0.0
	for i: int in range(1, out.size()):
		total += out[i - 1].distance_to(out[i])
	for i: int in range(best, route.size()):
		var a: Vector2 = out[out.size() - 1]
		var seg: float = a.distance_to(route[i])
		if total + seg > max_len:
			if seg > 0.01:
				out.append(a.lerp(route[i], (max_len - total) / seg))
			break
		out.append(route[i])
		total += seg
	var r: BikeRoute = from_points(out)
	r.bridge_s = find_bridge_s(md, r)
	return r


## Route distance of the middle of the Rạch Hầm bridge (a map road marked bridge whose name has BRIDGE_NAME), -1 when the
## route does not pass within BRIDGE_MAX_D m of it.
static func find_bridge_s(md: MapData, r: BikeRoute) -> float:
	if md == null or r == null or not r.valid():
		return -1.0
	for road: Dictionary in md.roads():
		if not bool(road.get("bridge", false)) or String(road.get("name", "")).find(BRIDGE_NAME) < 0:
			continue
		var pts: PackedVector2Array = MapData.poly(road.get("points", []))
		if pts.size() < 2:
			continue
		var mid: Vector2 = (pts[0] + pts[pts.size() - 1]) * 0.5
		var pr: Vector2 = r.project(mid)
		if absf(pr.y) <= BRIDGE_MAX_D:
			return pr.x
	return -1.0


func _seg(s: float) -> int:
	return clampi(cum.bsearch(s, true) - 1, 0, pts.size() - 2)


func point(s: float) -> Vector2:
	var i: int = _seg(s)
	var span: float = maxf(cum[i + 1] - cum[i], 1e-4)
	return pts[i].lerp(pts[i + 1], clampf((s - cum[i]) / span, 0.0, 1.0))


func tangent(s: float) -> Vector2:
	var i: int = _seg(s)
	return (pts[i + 1] - pts[i]).normalized()


## Right-hand normal of the travel direction (x east, z south: facing north, right = east).
func right(s: float) -> Vector2:
	var t: Vector2 = tangent(s)
	return Vector2(-t.y, t.x)


func world(s: float, d: float) -> Vector2:
	return point(s) + right(s) * d


## Closest point of the route to p as Vector2(s, d). s_hint >= 0 searches only segments within `window` metres of it.
func project(p: Vector2, s_hint: float = -1.0, window: float = WINDOW_M) -> Vector2:
	var i0: int = 0
	var i1: int = pts.size() - 2
	if s_hint >= 0.0:
		i0 = _seg(s_hint - window)
		i1 = _seg(s_hint + window)
	var best_d2: float = INF
	var best_s: float = 0.0
	var best_i: int = i0
	for i: int in range(i0, i1 + 1):
		var a: Vector2 = pts[i]
		var ab: Vector2 = pts[i + 1] - a
		var l2: float = maxf(ab.length_squared(), 1e-6)
		var u: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		var q: Vector2 = a + ab * u
		var d2: float = q.distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			best_s = cum[i] + sqrt(l2) * u
			best_i = i
	var t: Vector2 = (pts[best_i + 1] - pts[best_i]).normalized()
	var rel: Vector2 = p - point(best_s)
	return Vector2(best_s, rel.dot(Vector2(-t.y, t.x)))
