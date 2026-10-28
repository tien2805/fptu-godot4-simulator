# File: res://scripts/roam/NightRoads.gd
# Q3 night roads of free roam (master plan 2026-10-29 Q3 "Night roads"; plan docs/superpowers/plans/2026-10-29-q3-look.md
# Task 4). FreeRoam builds it after its regions and switches it in set_time_of_day (set_night):
#   - street lamps: every SPACING_MAIN m on primary / secondary / tertiary / trunk ways and every SPACING_SIDE m on
#     residential ways, alternating kerbs, KERB_OUT m past the carriageway edge, arm over the road; not on bridges, not on
#     service lanes, not inside the campus plot (FPTUCampusBuilder dresses it), not on water, not on another carriageway
#     or inside a junction disc (MapBuilder road index), never closer than MIN_GAP m to another lamp, and never within
#     CINE_CLEAR m of a baked cinematic stage (CineStageBake.TABLE spots and centres: the stage searches and their bake
#     test see the same clutter as before, and no pole stands in a scene);
#   - per CELL m grid cell: one MultiMeshInstance3D of posts (MapBuilder "pole" material, always shown, visibility range),
#     one of lamp heads (their own emissive material: lit at night only) and one of light pools (unshaded additive radial
#     quads on the road under each head, the traffic LampPool idea; shown at night only, fading out by distance). A few
#     dozen draw calls in view, no per-lamp node;
#   - LIGHTS real OmniLight3D (no shadows) moved to the lamps nearest the camera at LIGHT_HZ (spatial hash, no allocation),
#     night only;
#   - at night the lane paint (night_line materials that ViceStyle made soft emitters) glows brighter (LINE_NIGHT_ENERGY,
#     still under the glow threshold) and the POI sign plates (MapBuilder "sign_blue") glow like neon; both go back to the
#     ViceStyle values by day and when the node leaves the tree (shared materials: no leak into other scenes).
# Night = the "night" preset only (dawn / sunset skies are bright; the traffic lamps already cover those).
class_name NightRoads
extends Node3D

const CELL: float = 160.0
const HASH: float = 40.0
const MAIN_CLASSES: Array[String] = ["primary", "secondary", "tertiary", "trunk"]
const SIDE_CLASSES: Array[String] = ["residential"]
const SPACING_MAIN: float = 30.0
const SPACING_SIDE: float = 42.0
const KERB_OUT: float = 0.6
const MIN_GAP: float = 14.0
const POLE_H: float = 7.4
const ARM: float = 1.8
const POOL_SIZE: float = 12.0
const POOL_IN: float = 3.2
const POOL_Y: float = MapBuilder.ROAD_Y + 0.035      # above the lane overlay (+0.01) like the traffic LampPool
const SODIUM := Color(1.0, 0.76, 0.45)
const POOL_COLOR := Color(1.0, 0.78, 0.5, 0.3)
const HEAD_ENERGY: float = 2.4                       # > the night glow threshold (1.4): lamp heads glow
const POST_RANGE: float = 420.0
const HEAD_RANGE: float = 650.0
const POOL_RANGE: float = 220.0
const POOL_FADE: float = 40.0
const LIGHTS: int = 4
const LIGHT_RANGE: float = 14.0
const LIGHT_ENERGY: float = 1.3
const LIGHT_HZ: float = 4.0
const LIGHT_NEAR: float = 70.0
const LINE_NIGHT_ENERGY: float = 0.8
const SIGN_NIGHT_ENERGY: float = 1.6
const SIGN_GLOW := Color(0.3, 0.6, 1.0)
const CINE_CLEAR: float = 45.0

var night: bool = false
var lamp_base: PackedVector3Array = PackedVector3Array()
var lamp_head: PackedVector3Array = PackedVector3Array()
var lamp_in: PackedVector3Array = PackedVector3Array()   # unit vector from the kerb toward the road centre
var posts: Array[MultiMeshInstance3D] = []
var heads: Array[MultiMeshInstance3D] = []
var pools: Array[MultiMeshInstance3D] = []
var lights: Array[OmniLight3D] = []
## Centre of each cell (same order as posts / heads / pools; the render budget test, the headless server has no AABBs).
var cell_centers: PackedVector3Array = PackedVector3Array()
var build_ms: float = 0.0
## Tests: a fixed viewer position instead of the current camera (null = camera).
var viewer_override: Variant = null
var head_mat: StandardMaterial3D
var pool_mat: StandardMaterial3D
var _hash: Dictionary = {}                  # Vector2i -> PackedInt32Array of lamp indices
var _t: float = 0.0
var _near_i: PackedInt32Array = PackedInt32Array()
var _near_d: PackedFloat32Array = PackedFloat32Array()
var _clear_pts: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	name = "NightRoads"
	_near_i.resize(LIGHTS)
	_near_d.resize(LIGHTS)


## Places the lamps of `regions` (deduplicated ways) and builds the cells. skip_poly: map-plane polygon without lamps
## (the campus plot).
func build(md: MapData, regions: Array, skip_poly: PackedVector2Array = PackedVector2Array()) -> void:
	var t0: int = Time.get_ticks_usec()
	if md == null:
		return
	MapBuilder._prepare_road_index(md)
	var water: Array = []
	for wp: PackedVector2Array in MapBuilder._water_polygons(md):
		water.append([wp, MapBuilder._bbox(wp)])
	var skip_box: Rect2 = MapBuilder._bbox(skip_poly) if skip_poly.size() >= 3 else Rect2()
	var seen: Dictionary = {}
	var taken: Dictionary = {}
	_clear_pts = cine_clear_points()
	for reg: String in regions:
		for r: Dictionary in md.roads(reg):
			var id: int = int(r.get("id", 0))
			if seen.has(id):
				continue
			seen[id] = true
			if int(r.get("lanes", 0)) <= 0 or bool(r.get("bridge", false)):
				continue
			var cls: String = str(r.get("class", "residential"))
			cls = str(MapBuilder.CLASS_ALIAS.get(cls, cls))
			var spacing: float = SPACING_MAIN if cls in MAIN_CLASSES else (SPACING_SIDE if cls in SIDE_CLASSES else 0.0)
			if spacing <= 0.0:
				continue
			_place_road(MapData.poly(r.get("points", [])), float(r.get("width", 6.0)), spacing, water, skip_poly, skip_box, taken)
	_build_cells()
	_build_lights()
	set_night(night)
	build_ms = float(Time.get_ticks_usec() - t0) / 1000.0


## Map-plane points lamps keep CINE_CLEAR m away from: every baked cinematic stage spot and its search centre.
static func cine_clear_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Variant in CineStageBake.TABLE.values():
		var e: Array = v
		if e.size() >= 10:
			out.append(Vector2(float(e[0]), float(e[2])))
			out.append(Vector2(float(e[8]), float(e[9])))
	return out


func lamp_count() -> int:
	return lamp_base.size()


func _place_road(pts: PackedVector2Array, width: float, spacing: float, water: Array, skip_poly: PackedVector2Array, skip_box: Rect2, taken: Dictionary) -> void:
	if pts.size() < 2:
		return
	var off: float = width * 0.5 + KERB_OUT
	var s_next: float = spacing * 0.5
	var acc: float = 0.0
	var side: float = 1.0
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var seg: Vector2 = pts[i + 1] - a
		var len: float = seg.length()
		if len < 0.01:
			continue
		var d: Vector2 = seg / len
		var nrm := Vector2(-d.y, d.x)
		while s_next <= acc + len:
			var q: Vector2 = a + d * (s_next - acc)
			var c: Vector2 = q + nrm * (off * side)
			if _lamp_ok(c, water, skip_poly, skip_box, taken):
				var cell := Vector2i(int(floor(c.x / HASH)), int(floor(c.y / HASH)))
				if not taken.has(cell):
					taken[cell] = []
				(taken[cell] as Array).append(c)
				var inward: Vector2 = -nrm * side
				lamp_base.append(Vector3(c.x, 0.0, c.y))
				lamp_in.append(Vector3(inward.x, 0.0, inward.y))
				lamp_head.append(Vector3(c.x + inward.x * ARM, POLE_H - 0.2, c.y + inward.y * ARM))
			side = -side
			s_next += spacing
		acc += len


func _lamp_ok(c: Vector2, water: Array, skip_poly: PackedVector2Array, skip_box: Rect2, taken: Dictionary) -> bool:
	if skip_poly.size() >= 3 and skip_box.has_point(c) and Geometry2D.is_point_in_polygon(c, skip_poly):
		return false
	for k: Vector2 in _clear_pts:
		if c.distance_squared_to(k) < CINE_CLEAR * CINE_CLEAR:
			return false
	var cell := Vector2i(int(floor(c.x / HASH)), int(floor(c.y / HASH)))
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			for o: Vector2 in taken.get(Vector2i(cell.x + dx, cell.y + dy), []):
				if c.distance_to(o) < MIN_GAP:
					return false
	for sv: Vector2i in MapBuilder._segments_near(c):
		var cw: Array = MapBuilder._carriageways[sv.x]
		var p: PackedVector2Array = cw[0]
		if MapBuilder._dist_point_segment(c, p[sv.y], p[sv.y + 1]) < float(cw[1]) * 0.5 + 0.3:
			return false
	var mc: Vector2i = MapBuilder._cell(c)
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			for di: int in MapBuilder._disc_hash.get(Vector2i(mc.x + dx, mc.y + dy), []):
				if c.distance_to(MapBuilder._discs[di][0]) < float(MapBuilder._discs[di][1]):
					return false
	for w: Array in water:
		if (w[1] as Rect2).has_point(c) and Geometry2D.is_point_in_polygon(c, w[0]):
			return false
	return true


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------
func _build_cells() -> void:
	var cells: Dictionary = {}
	for i: int in range(lamp_base.size()):
		var b: Vector3 = lamp_base[i]
		var key := Vector2i(int(floor(b.x / CELL)), int(floor(b.z / CELL)))
		if not cells.has(key):
			cells[key] = PackedInt32Array()
		var arr: PackedInt32Array = cells[key]
		arr.append(i)
		cells[key] = arr
		var hk := Vector2i(int(floor(b.x / HASH)), int(floor(b.z / HASH)))
		var ha: PackedInt32Array = _hash.get(hk, PackedInt32Array())
		ha.append(i)
		_hash[hk] = ha
	var post_mesh: ArrayMesh = _post_mesh()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.62, 0.12, 0.32)
	var pool_mesh := PlaneMesh.new()
	pool_mesh.size = Vector2(POOL_SIZE, POOL_SIZE)
	head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.2, 0.18, 0.16)
	head_mat.emission = SODIUM
	head_mat.emission_energy_multiplier = HEAD_ENERGY
	head_mat.emission_enabled = false
	head_mat.set_meta("vice_done", true)
	pool_mat = _pool_material()
	var pole_mat: Material = MapBuilder.materials().get("pole")
	for key: Vector2i in cells.keys():
		var idx: PackedInt32Array = cells[key]
		var post_xf: Array[Transform3D] = []
		var head_xf: Array[Transform3D] = []
		var pool_xf: Array[Transform3D] = []
		for i: int in idx:
			var inw: Vector3 = lamp_in[i]
			var z: Vector3 = inw.cross(Vector3.UP)
			var basis := Basis(inw, Vector3.UP, z)
			post_xf.append(Transform3D(basis, lamp_base[i]))
			head_xf.append(Transform3D(basis, lamp_head[i]))
			var pc: Vector3 = lamp_base[i] + inw * POOL_IN
			pool_xf.append(Transform3D(basis, Vector3(pc.x, POOL_Y, pc.z)))
		cell_centers.append(Vector3((float(key.x) + 0.5) * CELL, 0.0, (float(key.y) + 0.5) * CELL))
		posts.append(_mm(post_mesh, post_xf, pole_mat, POST_RANGE, 0.0, "Posts_%d_%d" % [key.x, key.y]))
		heads.append(_mm(head_mesh, head_xf, head_mat, HEAD_RANGE, 0.0, "Heads_%d_%d" % [key.x, key.y]))
		pools.append(_mm(pool_mesh, pool_xf, pool_mat, POOL_RANGE, POOL_FADE, "Pools_%d_%d" % [key.x, key.y]))


func _mm(mesh: Mesh, xfs: Array[Transform3D], mat: Material, range_end: float, fade: float, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_end = range_end
	if fade > 0.0:
		mi.visibility_range_end_margin = fade
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	return mi


## Pole (octagonal, tapered) + the arm over the road (+X) + a small bracket, one surface.
static func _post_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.11
	pole.height = POLE_H
	pole.radial_segments = 8
	pole.rings = 1
	st.append_from(pole, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, POLE_H * 0.5, 0.0)))
	var arm := BoxMesh.new()
	arm.size = Vector3(ARM + 0.1, 0.08, 0.1)
	st.append_from(arm, 0, Transform3D(Basis.IDENTITY, Vector3((ARM + 0.1) * 0.5, POLE_H - 0.1, 0.0)))
	var brace := BoxMesh.new()
	brace.size = Vector3(0.7, 0.05, 0.06)
	st.append_from(brace, 0, Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0.3, POLE_H - 0.45, 0.0)))
	return st.commit()


## Unshaded additive radial falloff (the traffic LampPool recipe), centred.
static func _pool_material() -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = POOL_COLOR
	m.albedo_texture = tex
	m.set_meta("vice_done", true)
	return m


func _build_lights() -> void:
	for i: int in range(LIGHTS):
		var l := OmniLight3D.new()
		l.name = "LampLight%d" % i
		l.light_color = SODIUM
		l.light_energy = LIGHT_ENERGY
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.light_specular = 0.3
		l.visible = false
		add_child(l)
		lights.append(l)


# ---------------------------------------------------------------------------
# Day / night
# ---------------------------------------------------------------------------
## Lamps on (pools, heads, near lights, brighter lane paint, glowing signs) or off.
func set_night(on: bool) -> void:
	night = on
	for p: MultiMeshInstance3D in pools:
		p.visible = on
	if head_mat:
		head_mat.emission_enabled = on
	if not on:
		for l: OmniLight3D in lights:
			l.visible = false
	else:
		_t = 0.0
		_update_lights()
	_shared_materials(on)


func _exit_tree() -> void:
	_shared_materials(false)


func _process(delta: float) -> void:
	if not night:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0 / LIGHT_HZ
	_update_lights()


func viewer_position() -> Variant:
	if viewer_override != null:
		return viewer_override
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	return cam.global_position if cam else null


## The LIGHTS lamps nearest the viewer within LIGHT_NEAR m get the real lights (a fixed-size insertion list, no allocation).
func _update_lights() -> void:
	var v: Variant = viewer_position()
	if v == null:
		return
	var p: Vector3 = v
	for k: int in range(LIGHTS):
		_near_i[k] = -1
		_near_d[k] = INF
	var hc := Vector2i(int(floor(p.x / HASH)), int(floor(p.z / HASH)))
	for dx: int in [-2, -1, 0, 1, 2]:
		for dy: int in [-2, -1, 0, 1, 2]:
			var key := Vector2i(hc.x + dx, hc.y + dy)
			if not _hash.has(key):
				continue
			var arr: PackedInt32Array = _hash[key]
			for i: int in arr:
				var h: Vector3 = lamp_head[i]
				var d: float = Vector2(h.x - p.x, h.z - p.z).length_squared()
				if d > LIGHT_NEAR * LIGHT_NEAR or d >= _near_d[LIGHTS - 1]:
					continue
				var k2: int = LIGHTS - 1
				while k2 > 0 and _near_d[k2 - 1] > d:
					_near_d[k2] = _near_d[k2 - 1]
					_near_i[k2] = _near_i[k2 - 1]
					k2 -= 1
				_near_d[k2] = d
				_near_i[k2] = i
	for k: int in range(LIGHTS):
		var l: OmniLight3D = lights[k]
		var i: int = _near_i[k]
		l.visible = i >= 0
		if i >= 0:
			l.global_position = lamp_head[i] + Vector3(0.0, -0.35, 0.0)


func lights_on() -> int:
	var c: int = 0
	for l: OmniLight3D in lights:
		if l.visible:
			c += 1
	return c


## Lane paint (night_line soft emitters) brighter and POI sign plates glowing at night; ViceStyle values otherwise.
static func _shared_materials(on: bool) -> void:
	var mats: Array = []
	for d: Dictionary in [MapBuilder._mats, FPTUCampusBuilder._materials_cache]:
		for k: String in ["overlay", "line", "yellow_line"]:
			var m: Variant = d.get(k)
			if m is BaseMaterial3D and not mats.has(m):
				mats.append(m)
	for m: BaseMaterial3D in mats:
		if m.has_meta("vice_soft_emitter") and m.has_meta(ViceStyle.NIGHT_LINE_META):
			m.emission_energy_multiplier = LINE_NIGHT_ENERGY if on else ViceStyle.NIGHT_LINE_ENERGY
	var sign: Variant = MapBuilder._mats.get("sign_blue")
	if sign is BaseMaterial3D:
		var s := sign as BaseMaterial3D
		if on:
			if not s.has_meta("night_sign"):
				s.set_meta("night_sign", s.emission_enabled)
			s.emission_enabled = true
			s.emission = SIGN_GLOW
			s.emission_energy_multiplier = SIGN_NIGHT_ENERGY
		elif s.has_meta("night_sign"):
			s.emission_enabled = bool(s.get_meta("night_sign"))
			s.remove_meta("night_sign")
