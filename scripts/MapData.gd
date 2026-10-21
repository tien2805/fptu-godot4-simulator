# File: res://scripts/MapData.gd
# Bộ nạp dữ liệu bản đồ thật (OSM -> assets/data/mapdata.json, do tools/osm_to_mapdata.py sinh ra).
# Hệ toạ độ: mét; x = đông, z = nam (Godot -Z = bắc), y = lên; gốc = trọng tâm campus FPTU.
# Không dùng GameFX / StageManager ở đây: file này được biên dịch trước autoload khi chạy test --script.
class_name MapData
extends RefCounted

const DEFAULT_PATH := "res://assets/data/mapdata.json"

static var _cached: MapData = null

## Raw parsed JSON (see the data contract in docs/superpowers/plans/2026-10-22-real-map-world.md).
var data: Dictionary = {}


## Cached loader: parses the shipped mapdata.json once per process.
## Returns null (and pushes an error) when the file is missing or malformed.
static func load_default() -> MapData:
	if _cached != null:
		return _cached
	var md: MapData = load_from(DEFAULT_PATH)
	if md != null:
		_cached = md
	return md


## Loads a map data file from any path. Not cached; returns null on error.
static func load_from(path: String) -> MapData:
	if not FileAccess.file_exists(path):
		push_error("MapData: file not found: %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("MapData: %s is not a JSON object (parse failed)" % path)
		return null
	var md := MapData.new()
	md.data = parsed
	return md


# --- Typed access ---------------------------------------------------------------

## Roads of a region ("" = all). Each: {id, name, class, width, lanes, oneway, roundabout, bridge, region, points}.
func roads(region: String = "") -> Array[Dictionary]:
	return _filter("roads", region)


## Buildings of a region ("" = all). Each: {id, name, display, kind, levels, height, style, region, area, outer, inner}.
func buildings(region: String = "") -> Array[Dictionary]:
	return _filter("buildings", region)


## Water bodies of a region ("" = all). kind "area" has `outer`, kind "line" has `points` + `width`.
func water(region: String = "") -> Array[Dictionary]:
	return _filter("water", region)


## Areas of a region ("" = all), optionally only one kind (park|pitch|parking|pool|water_park|campus|other).
func areas(region: String = "", kind: String = "") -> Array[Dictionary]:
	return _filter("areas", region, kind)


## Points of interest of a region ("" = all). Each: {name, display, kind, x, z, region}.
func pois(region: String = "") -> Array[Dictionary]:
	return _filter("pois", region)


## A landmark by key (polygon Array, [x, z] Array or the spawn Dictionary); null when absent.
func landmark(key: String) -> Variant:
	var lm: Variant = data.get("landmarks")
	if lm is Dictionary:
		return (lm as Dictionary).get(key)
	return null


# --- Geometry helpers -----------------------------------------------------------

## JSON [[x, z], ...] -> PackedVector2Array of Vector2(x, z).
static func poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i: int in range(points.size()):
		var p: Array = points[i]
		out[i] = Vector2(float(p[0]), float(p[1]))
	return out


## Map-plane point -> world position (x east, z south) at height y.
static func to_world(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## The BE6 -> FPTU route as a polyline. The shipped route keeps only the OSM way vertices
## (some straight stretches are > 800 m), so segments longer than `max_segment_m` are
## subdivided evenly; the shape is unchanged. Pass 0 or less for the raw vertices.
func route_points(max_segment_m: float = 20.0) -> PackedVector2Array:
	var raw: PackedVector2Array = poly(_route().get("points", []))
	if max_segment_m <= 0.0 or raw.size() < 2:
		return raw
	var out := PackedVector2Array()
	out.append(raw[0])
	for i: int in range(1, raw.size()):
		var a: Vector2 = raw[i - 1]
		var b: Vector2 = raw[i]
		var n: int = maxi(1, ceili(a.distance_to(b) / max_segment_m))
		for k: int in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n)))
	return out


## Route length in metres (the tool's measured length; falls back to the polyline length).
func route_length() -> float:
	var r: Dictionary = _route()
	if r.has("length_m"):
		return float(r["length_m"])
	var pts: PackedVector2Array = route_points(0.0)
	var total: float = 0.0
	for i: int in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


## Player spawn: origin from landmarks.spawn (y = 0), yaw_deg around +Y so that -Z faces the
## direction the tool chose (6 m outside the BE6 lobby door, facing away from the tower).
func spawn_transform() -> Transform3D:
	var sp: Variant = landmark("spawn")
	if not (sp is Dictionary):
		push_error("MapData: landmarks.spawn missing")
		return Transform3D.IDENTITY
	var d: Dictionary = sp
	var origin := Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))
	var basis := Basis(Vector3.UP, deg_to_rad(float(d.get("yaw_deg", 0.0))))
	return Transform3D(basis, origin)


## Axis-aligned bounds (map plane: x east, y = z south) of all geometry in a region:
## road points, building outers, area outers and water outlines. Zero Rect2 when empty.
func bounds(region: String) -> Rect2:
	var rect := Rect2()
	var started: bool = false
	var lists: Array = [
		[roads(region), "points"],
		[buildings(region), "outer"],
		[areas(region), "outer"],
		[water(region), "outer"],
		[water(region), "points"],
	]
	for entry: Array in lists:
		var items: Array[Dictionary] = entry[0]
		var key: String = entry[1]
		for item: Dictionary in items:
			var pts: Variant = item.get(key)
			if not (pts is Array):
				continue
			for p: Variant in (pts as Array):
				var v := Vector2(float(p[0]), float(p[1]))
				if started:
					rect = rect.expand(v)
				else:
					rect = Rect2(v, Vector2.ZERO)
					started = true
	return rect


# --- Internals --------------------------------------------------------------------

func _route() -> Dictionary:
	var r: Variant = data.get("route_be6_to_fptu")
	return r if r is Dictionary else {}


func _filter(key: String, region: String, kind: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src: Variant = data.get(key)
	if not (src is Array):
		return out
	for item: Variant in (src as Array):
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		if region != "" and str(d.get("region", "")) != region:
			continue
		if kind != "" and str(d.get("kind", "")) != kind:
			continue
		out.append(d)
	return out
