# File: res://scripts/MapBuilder.gd
# Dựng hình học thủ tục từ dữ liệu bản đồ thật (MapData <- assets/data/mapdata.json): đường, nhà, nước, khu đất,
# cây và bảng tên POI cho từng vùng (campus | corridor | vinhomes), có collider. Plan Task 3
# (docs/superpowers/plans/2026-10-22-real-map-world.md). Toạ độ: mét, x = đông, z = nam, y = lên.
# Không dùng GameFX / StageManager ở đây: file này được biên dịch trước autoload khi chạy test --script.
#
# OUTPUT TREE (build_region): Map_<region> (meta region) -> Ground, Areas_<kind>, AreaLines, Water, Banks,
#   Roads_<class> (+StaticBody3D), Kerbs (+body), RoadLines, Footways (+body), BridgeParts (+body),
#   Buildings/<B<id> | name> (MeshInstance3D, meta building_id, +StaticBody3D/ConcavePolygonShape3D, Label3D),
#   Trees/Trees_<variant> (MultiMeshInstance3D) (+TreeColliders), POIs (Label3D + POISigns/POIPlates).
#   Every direct child of the region root carries meta "region" too.
#
# FACADE UV CONTRACT (walls, see Task 2 tile table): every facade material has uv1_scale = (1, 1, 1); the repeats
#   are baked into the mesh UVs. u = distance along the edge / TILE_W[style] (restarts at 0 on every building edge,
#   so each facade starts on a whole bay). v = 0 at the roof edge and v = levels / TILE_STOREYS[style] at the
#   ground: the image bottom (floor line) lands exactly on the pavement and the image top (parapet band) on the
#   roof. One tile therefore covers TILE_STOREYS storeys of the building's own storey height (height / levels:
#   3.2 m towers, 3.6 m shophouse/mall); equivalent to the plan's "u = length / 3 m, v = levels" with
#   uv1_scale = (3 / TILE_W, 1 / TILE_STOREYS, 1) folded into the UVs. Roof uv = world (x, z) / 4 m.
#
# Y STACK: ground -0.03 | area planes 0.0..0.035 by kind | roads 0.05 | lane overlay +0.01 | footways 0.12
#   (dipping to 0.03 where they cross a carriageway) | kerb top 0.15 | water -0.3 (ground cut out around it,
#   banks down to -0.5) | bridges ramp to +6 m over 40 m with 0.9 m barriers, deck underside and pillars.
# ROAD RULES: one carriageway per way (oneway ways are single carriageways: edge lines only, no centre line);
#   roundabout pieces are plain ribbons; bridge == true raises the ribbon; lanes == 0 (footway/steps/path) =
#   1.5..2.5 m sidewalk ribbon without kerbs; kerbs are cut inside junction discs so no kerb crosses a junction.
# CORRIDOR EXTENT: region_shape("corridor") is the route polyline buffered by scope.corridor_radius (150 m),
#   never bounds("corridor") (whole OSM ways are tagged corridor, so that AABB spans 5 x 8 km).
class_name MapBuilder
extends RefCounted

# Task 2 tile table (= TILE_W / TILE_STOREYS in generate_city_textures.py)
const TILE_W: Dictionary = {"tower": 3.0, "beverly": 3.0, "mall": 6.0, "industrial": 6.0, "shophouse": 12.0}
const TILE_STOREYS: Dictionary = {"tower": 1, "beverly": 1, "mall": 1, "industrial": 1, "shophouse": 2}
const STOREY_M: float = 3.2
const NORMAL_MAPPED_STYLES: Array[String] = ["tower", "beverly"]

const GROUND_Y: float = -0.03
const ROAD_Y: float = 0.05
const OVERLAY_LIFT: float = 0.01
const FOOTWAY_Y: float = 0.12
const FOOTWAY_DIP_Y: float = 0.03
const KERB_ABOVE_ROAD: float = 0.10   # kerb top = ROAD_Y + 0.10 = 0.15
const KERB_W: float = 0.3
const KERB_MIN_ROAD_W: float = 5.0    # 4 m service lanes get no kerb
const WATER_Y: float = -0.3
const POOL_Y: float = 0.035
const BRIDGE_H: float = 6.0
const BRIDGE_RAMP_M: float = 40.0
const BARRIER_H: float = 0.9
const BARRIER_W: float = 0.3
const DECK_T: float = 0.7
const PILLAR_EVERY_M: float = 25.0
const OVERLAY_TILE_M: float = 4.0
const ROOF_TILE_M: float = 4.0
const WATER_TILE_M: float = 8.0
const RIBBON_STEP_M: float = 8.0
const FOOTWAY_STEP_M: float = 4.0
const TREE_M2: float = 250.0
const FOREST_M2: float = 120.0
const MAX_TREES_PER_REGION: int = 1500
const HASH_CELL: float = 64.0
const BIG_AREA_SKIP_M2: float = 300000.0   # district-level landuse polygons are just ground
const AREA_Y: Dictionary = {"other": 0.0, "campus": 0.005, "park": 0.01, "pitch": 0.02, "parking": 0.02, "pool": POOL_Y, "water_park": POOL_Y}
const CLASS_ALIAS: Dictionary = {"primary_link": "primary", "secondary_link": "secondary", "tertiary_link": "tertiary", "motorway_link": "motorway", "unclassified": "residential", "living_street": "residential"}
const INVALID_NAME_CHARS: Array[String] = [".", ":", "@", "/", "\"", "%"]

static var _mats: Dictionary = {}
static var _style_mats: Dictionary = {}
static var _tree_meshes: Array = []          # ArrayMesh variants: 3 baked FPTUCampusBuilder tropical trees
static var _hash_md: MapData = null
static var _seg_hash: Dictionary = {}        # Vector2i cell -> Array[Vector2i(carriageway index, segment index)]
static var _carriageways: Array = []         # [PackedVector2Array points, float width]
static var _discs: Array = []                # [Vector2 centre, float radius] junction discs (no kerb / no lines inside)
static var _disc_hash: Dictionary = {}       # Vector2i cell -> Array[int]
static var _max_disc_r: float = 0.0
static var _water_cache_md: MapData = null
static var _water_cache: Array = []          # PackedVector2Array polygons of every water body (all regions)


## A SurfaceTool plus its vertex count (SurfaceTool cannot be asked whether it is empty).
class Batch:
	var st: SurfaceTool
	var n: int = 0

	func _init() -> void:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)


# ===========================================================================
# PUBLIC API
# ===========================================================================

## Builds one region ("campus" | "corridor" | "vinhomes") under `parent` and returns its root Node3D.
## opts: colliders (true), roads (true), buildings (true), water (true), areas (true), trees (true), labels (true),
##       skip_building_ids ([]), skip_area_ids ([]: area ids drawn by someone else, e.g. the FPT plot that
##       FPTUCampusBuilder covers with its own grass), lod (0 full | 1 no labels/trees | 2 boxes only), y (0.0 ground offset).
static func build_region(parent: Node3D, md: MapData, region: String, opts: Dictionary = {}) -> Node3D:
	var t0: int = Time.get_ticks_msec()
	var o: Dictionary = _defaults(opts)
	var m: Dictionary = materials()
	var root := Node3D.new()
	root.name = "Map_" + region
	root.set_meta("region", region)
	if float(o["y"]) != 0.0:
		root.position.y = float(o["y"])
	parent.add_child(root)
	_prepare_road_index(md)
	var water_polys: Array = _water_polygons(md)
	_build_ground(root, md, region, water_polys, m)
	if bool(o["areas"]):
		_build_areas(root, md, region, water_polys, m, o)
	if bool(o["water"]):
		_build_water(root, md, region, m)
	if bool(o["roads"]):
		_build_roads(root, md, region, m, o)
	if bool(o["buildings"]):
		_build_buildings(root, md, region, m, o)
	if bool(o["labels"]) and int(o["lod"]) == 0:
		_build_pois(root, md, region, m)
	for c: Node in root.get_children():
		c.set_meta("region", region)
	root.set_meta("build_ms", Time.get_ticks_msec() - t0)
	return root


## The planar extent of a region: campus / vinhomes = disc of scope.*_radius (+40 m margin), corridor = the route
## polyline buffered by scope.corridor_radius. Ground planes and culling helpers use this, never bounds("corridor").
static func region_shape(md: MapData, region: String) -> Array:
	var scope: Dictionary = md.data.get("scope", {})
	match region:
		"campus":
			return [_disc_poly(Vector2.ZERO, float(scope.get("campus_radius", 700.0)) + 40.0, 64)]
		"vinhomes":
			var c: Array = scope.get("vinhomes_center", [0.0, 0.0])
			return [_disc_poly(Vector2(float(c[0]), float(c[1])), float(scope.get("vinhomes_radius", 900.0)) + 40.0, 64)]
		_:
			var r: float = float(scope.get("corridor_radius", 150.0)) + 40.0
			var pts: PackedVector2Array = md.route_points(0.0)
			if pts.size() < 2:
				return []
			var polys: Array = Geometry2D.offset_polyline(pts, r, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
			var out: Array = []
			for p: PackedVector2Array in polys:
				if not _is_hole_of_any(p, polys):
					out.append(p)
			return out


## True when the map-plane point lies inside region_shape(region).
static func region_contains(md: MapData, region: String, p: Vector2) -> bool:
	for poly: PackedVector2Array in region_shape(md, region):
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## One road ribbon (mitred joints) as a MeshInstance3D with children "Lines" (lane overlay), "Kerbs" and a
## StaticBody3D trimesh collider. opts: y (ROAD_Y), kerb (true), overlay (true), oneway (false), bridge (false),
## colliders (true), material (asphalt), lanes (2).
static func build_road(parent: Node3D, points: PackedVector2Array, width: float, opts: Dictionary = {}) -> MeshInstance3D:
	var m: Dictionary = materials()
	if points.size() < 2:
		return null
	var bridge: bool = bool(opts.get("bridge", false))
	var y: float = float(opts.get("y", ROAD_Y))
	var pts3: PackedVector3Array = _road_profile(points, bridge, y)
	var rb := Batch.new()
	_emit_ribbon(rb, pts3, width, 0.0, 0.0, 1.0, 1.0 / OVERLAY_TILE_M)
	var mat: Material = opts.get("material", m["asphalt"])
	var mi: MeshInstance3D = _commit(rb, mat, "Road")
	if mi == null:
		return null
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if bool(opts.get("overlay", true)):
		var ob := Batch.new()
		_emit_overlay(ob, pts3, width, bool(opts.get("oneway", false)))
		var omi: MeshInstance3D = _commit(ob, m["overlay"], "Lines")
		if omi:
			omi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(omi)
	var colliders: bool = bool(opts.get("colliders", true))
	if bridge:
		var bb := Batch.new()
		_emit_bridge_parts(bb, pts3, width)
		var bmi: MeshInstance3D = _commit(bb, m["barrier"], "BridgeParts")
		if bmi:
			mi.add_child(bmi)
			if colliders:
				_add_trimesh_collider(bmi)
	elif bool(opts.get("kerb", true)):
		var kb := Batch.new()
		_emit_kerbs(kb, pts3, width)
		var kmi: MeshInstance3D = _commit(kb, m["kerb"], "Kerbs")
		if kmi:
			mi.add_child(kmi)
			if colliders:
				_add_trimesh_collider(kmi)
	if colliders:
		_add_trimesh_collider(mi)
	return mi


## One building: walls (facade tile UVs, see header), flat roof (city_roof_flat.png), parapet, optional rooftop
## plant room, StaticBody3D with a ConcavePolygonShape3D of the whole mesh, Label3D with the display name.
static func build_building(parent: Node3D, b: Dictionary, opts: Dictionary = {}) -> Node3D:
	var o: Dictionary = _defaults(opts)
	var m: Dictionary = materials()
	var style: String = str(b.get("style", "shophouse"))
	var levels: int = maxi(1, int(b.get("levels", 2)))
	var height: float = float(b.get("height", 0.0))
	if height < 1.0:
		height = float(levels) * STOREY_M
	var outer: PackedVector2Array = _open(MapData.poly(b.get("outer", [])))
	if outer.size() < 3:
		return null
	var inners: Array = []
	for ring: Variant in b.get("inner", []):
		var r: PackedVector2Array = _open(MapData.poly(ring))
		if r.size() >= 3:
			inners.append(r)
	var tile_w: float = float(TILE_W.get(style, 12.0))
	var v_ground: float = float(levels) / float(TILE_STOREYS.get(style, 2))
	var mesh := ArrayMesh.new()
	# walls
	var wb := Batch.new()
	_emit_walls(wb, outer, 0.0, height, tile_w, v_ground, false)
	for r: PackedVector2Array in inners:
		_emit_walls(wb, r, 0.0, height, tile_w, v_ground, true)
	wb.st.generate_tangents()
	wb.st.commit(mesh)
	mesh.surface_set_name(0, "walls")
	mesh.surface_set_material(0, _mat_for_style(style))
	# roof
	var rb := Batch.new()
	for piece: PackedVector2Array in _subtract([outer], inners):
		_emit_polygon(rb, piece, height, Vector3.UP, 1.0 / ROOF_TILE_M)
	if rb.n == 0:
		_emit_polygon(rb, outer, height, Vector3.UP, 1.0 / ROOF_TILE_M)
	rb.st.commit(mesh)
	mesh.surface_set_name(1, "roof")
	mesh.surface_set_material(1, m["roof"])
	# parapet + rooftop plant room
	var pb := Batch.new()
	var ph: float = 0.4 if style in NORMAL_MAPPED_STYLES else 0.25
	_emit_parapet(pb, outer, height, ph, 0.3, false)
	for r: PackedVector2Array in inners:
		_emit_parapet(pb, r, height, ph, 0.3, true)
	if levels >= 10 and inners.is_empty():
		var c: Vector2 = _centroid(outer)
		if Geometry2D.is_point_in_polygon(c, outer):
			_emit_box(pb, Vector3(c.x, height + 1.3, c.y), Vector3(6.0, 2.6, 4.0))
	pb.st.commit(mesh)
	mesh.surface_set_name(2, "parapet")
	mesh.surface_set_material(2, m["parapet"])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = building_node_name(b)
	mi.set_meta("building_id", int(b.get("id", 0)))
	parent.add_child(mi)
	if bool(o["colliders"]):
		_add_trimesh_collider(mi)
	var text: String = str(b.get("display", ""))
	if text == "":
		text = str(b.get("name", ""))
	if bool(o["labels"]) and int(o["lod"]) == 0 and text != "":
		var c: Vector2 = _centroid(outer)
		var l := Label3D.new()
		l.text = text
		l.font_size = 48
		l.pixel_size = 0.05 if height > 20.0 else 0.025
		l.outline_size = 10
		l.modulate = Color(0.12, 0.10, 0.22)
		l.outline_modulate = Color(1.0, 1.0, 1.0, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(c.x, height + ph + 2.5, c.y)
		mi.add_child(l)
	return mi


## One water body: kind "area" -> polygon at WATER_Y, kind "line" -> buffered polyline; plus bank walls.
static func build_water(parent: Node3D, w: Dictionary) -> Node3D:
	var m: Dictionary = materials()
	var poly: PackedVector2Array = _water_polygon(w)
	if poly.size() < 3:
		return null
	var wb := Batch.new()
	_emit_polygon(wb, poly, WATER_Y, Vector3.UP, 1.0 / WATER_TILE_M)
	var mi: MeshInstance3D = _commit(wb, m["water"], "Water")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var bb := Batch.new()
	_emit_bank(bb, poly)
	var bmi: MeshInstance3D = _commit(bb, m["bank"], "Banks")
	if bmi:
		mi.add_child(bmi)
	return mi


## One area polygon (park = grass + trees, pitch = green + white outline, parking = dark + bay stripes,
## pool = blue plane + white kerb, campus/other = light plane). `m` = materials().
static func build_area(parent: Node3D, a: Dictionary, m: Dictionary, opts: Dictionary = {}) -> Node3D:
	var o: Dictionary = _defaults(opts)
	var poly: PackedVector2Array = _open(MapData.poly(a.get("outer", [])))
	if poly.size() < 3:
		return null
	var kind: String = str(a.get("kind", "other"))
	var tag: String = str(a.get("tag", ""))
	var key: String = _area_material_key(kind, tag)
	var y: float = float(AREA_Y.get(kind, 0.0))
	var b := Batch.new()
	_emit_polygon(b, poly, y, Vector3.UP, 1.0 / 6.0)
	var mi: MeshInstance3D = _commit(b, m[key], "Area_" + kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var lines := Batch.new()
	_emit_area_lines(lines, kind, poly, y)
	var lmi: MeshInstance3D = _commit(lines, m["line"], "AreaLines")
	if lmi:
		lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(lmi)
	if bool(o["trees"]) and int(o["lod"]) == 0:
		var density: float = _tree_density(kind, tag)
		if density > 0.0:
			var pts := PackedVector2Array()
			_sample_tree_points(poly, [poly], float(a.get("area", _abs_area(poly))) / density, int(a.get("id", 1)), pts)
			_build_trees(mi, pts, o)
	return mi


## Node name for a building: "BE6" for "Tòa BE6", the OSM name without spaces for other named buildings
## (invalid node-name characters replaced by "_"), "B<id>" for unnamed ones.
static func building_node_name(b: Dictionary) -> String:
	var n: String = str(b.get("name", "")).strip_edges()
	for prefix: String in ["Tòa nhà ", "Tòa "]:
		if n.begins_with(prefix):
			n = n.substr(prefix.length())
			break
	n = n.replace(" ", "")
	for ch: String in INVALID_NAME_CHARS:
		n = n.replace(ch, "_")
	if n == "":
		n = "B%d" % int(b.get("id", 0))
	return n


## Shared materials: campus keys reused from FPTUCampusBuilder.make_materials() (asphalt, line, yellow_line,
## white, dark, granite, concrete, pitch, leaf*, trunk) plus the map-specific ones (ground, park, other,
## campus_area, parking, pool, water, bank, kerb, sidewalk, roof, parapet, overlay, barrier, pole, sign_blue, box).
static func materials() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var m: Dictionary = _mats
	for k: String in ["asphalt", "line", "yellow_line", "white", "dark", "granite", "concrete", "pitch", "leaf", "leaf2", "leaf3", "trunk", "palm_trunk", "steel"]:
		m[k] = cm[k]
	var ground: StandardMaterial3D = _tex_mat("grass_lawn.png", Color("#7F8A4E"), true, 1.0 / 3.5, 0.95, "grass_lawn_n.png", 0.35)
	ground.albedo_color = Color(0.84, 0.82, 0.64)
	m["ground"] = ground
	var park: StandardMaterial3D = _tex_mat("grass_lawn.png", Color("#4A8036"), true, 1.0 / 3.0, 0.95, "grass_lawn_n.png", 0.45)
	park.albedo_color = Color(0.90, 1.0, 0.84)
	m["park"] = park
	var forest: StandardMaterial3D = _tex_mat("grass_lawn.png", Color("#3E7030"), true, 1.0 / 3.0, 0.95, "grass_lawn_n.png", 0.45)
	forest.albedo_color = Color(0.70, 0.86, 0.64)
	m["forest"] = forest
	var other: StandardMaterial3D = _tex_mat("sidewalk_tiles.png", Color("#B9B2A4"), true, 1.0 / 2.0, 0.9, "sidewalk_tiles_n.png", 0.4)
	other.albedo_color = Color(0.80, 0.78, 0.74)
	m["other"] = other
	var campus_area: StandardMaterial3D = _tex_mat("sidewalk_tiles.png", Color("#B4B2AC"), true, 1.0 / 2.0, 0.9, "sidewalk_tiles_n.png", 0.4)
	campus_area.albedo_color = Color(0.88, 0.87, 0.80)
	m["campus_area"] = campus_area
	m["sand"] = _plain(Color("#D9C79A"), 0.95)
	var parking: StandardMaterial3D = _tex_mat("asphalt_road_hd.png", Color("#3A3F46"), true, 0.12, 0.9, "asphalt_road_n.png", 0.5)
	parking.albedo_color = Color(0.82, 0.82, 0.86)
	m["parking"] = parking
	var pool: StandardMaterial3D = _plain(Color(0.42, 0.80, 0.90), 0.12)
	pool.metallic = 0.25
	m["pool"] = pool
	var water: StandardMaterial3D = _tex_mat("city_canal_water.png", Color(0.1, 0.55, 0.6), false, 1.0, 0.15)
	water.metallic = 0.3
	water.albedo_color = Color(0.9, 0.97, 1.0)
	m["water"] = water
	m["bank"] = _plain(Color(0.46, 0.42, 0.36), 0.95)
	m["kerb"] = _plain(Color(0.78, 0.77, 0.73), 0.9)
	m["sidewalk"] = _tex_mat("sidewalk_tiles.png", Color("#C3AF8C"), true, 1.0 / 1.6, 0.9, "sidewalk_tiles_n.png", 0.5)
	m["roof"] = _tex_mat("city_roof_flat.png", Color("#B9AEA8"), false, 1.0, 0.92)
	m["parapet"] = _plain(Color(0.90, 0.88, 0.84), 0.85)
	var overlay: StandardMaterial3D = _tex_mat("city_road_overlay.png", Color(1, 1, 1, 0), false, 1.0, 0.85)
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	overlay.alpha_scissor_threshold = 0.35
	m["overlay"] = overlay
	m["barrier"] = _plain(Color(0.74, 0.74, 0.72), 0.88)
	m["pole"] = _plain(Color(0.35, 0.37, 0.4), 0.45)
	m["sign_blue"] = _plain(Color(0.12, 0.38, 0.78), 0.5)
	m["box"] = _plain(Color(0.84, 0.80, 0.78), 0.9)
	return m


# ===========================================================================
# REGION PARTS
# ===========================================================================

static func _defaults(opts: Dictionary) -> Dictionary:
	var o: Dictionary = {"colliders": true, "roads": true, "buildings": true, "water": true, "areas": true, "trees": true, "labels": true, "skip_building_ids": [], "skip_area_ids": [], "lod": 0, "y": 0.0}
	for k: Variant in opts.keys():
		o[k] = opts[k]
	return o


static func _build_ground(root: Node3D, md: MapData, region: String, water_polys: Array, m: Dictionary) -> void:
	var pieces: Array = _subtract(region_shape(md, region), water_polys)
	var b := Batch.new()
	for piece: PackedVector2Array in pieces:
		_emit_polygon(b, piece, GROUND_Y, Vector3.UP, 1.0 / 8.0)
	var mi: MeshInstance3D = _commit(b, m["ground"], "Ground")
	if mi:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


static func _area_material_key(kind: String, tag: String) -> String:
	match kind:
		"park":
			return "forest" if tag == "forest" else "park"
		"pitch":
			return "pitch"
		"parking":
			return "parking"
		"pool", "water_park":
			return "pool"
		"campus":
			return "campus_area"
		_:
			match tag:
				"forest":
					return "forest"
				"meadow", "greenfield", "grass", "garden":
					return "park"
				"construction":
					return "sand"
				_:
					return "other"


static func _tree_density(kind: String, tag: String) -> float:
	if tag == "forest":
		return FOREST_M2
	if kind == "park":
		return TREE_M2
	return 0.0


static func _build_areas(root: Node3D, md: MapData, region: String, water_polys: Array, m: Dictionary, o: Dictionary) -> void:
	var batches: Dictionary = {}
	var lines := Batch.new()
	var tree_pts := PackedVector2Array()
	var lod: int = int(o["lod"])
	var skip_areas: Array = o["skip_area_ids"]
	for a: Dictionary in md.areas(region):
		if skip_areas.has(int(a.get("id", 0))):
			continue
		var kind: String = str(a.get("kind", "other"))
		var tag: String = str(a.get("tag", ""))
		var area_m2: float = float(a.get("area", 0.0))
		if kind == "other" and area_m2 > BIG_AREA_SKIP_M2:
			continue
		var poly: PackedVector2Array = _open(MapData.poly(a.get("outer", [])))
		if poly.size() < 3:
			continue
		var key: String = _area_material_key(kind, tag)
		var y: float = float(AREA_Y.get(kind, 0.0))
		var pieces: Array = [poly] if key == "pool" else _subtract([poly], water_polys)
		if not batches.has(key):
			batches[key] = Batch.new()
		var b: Batch = batches[key]
		for piece: PackedVector2Array in pieces:
			_emit_polygon(b, piece, y, Vector3.UP, 1.0 / 6.0)
		if lod < 2:
			_emit_area_lines(lines, kind, poly, y)
		if bool(o["trees"]) and lod == 0:
			var density: float = _tree_density(kind, tag)
			if density > 0.0:
				_sample_tree_points(poly, pieces, area_m2 / density, int(a.get("id", 1)), tree_pts)
	for key: String in batches.keys():
		var mi: MeshInstance3D = _commit(batches[key], m[key], "Areas_" + key)
		if mi:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
	var lmi: MeshInstance3D = _commit(lines, m["line"], "AreaLines")
	if lmi:
		lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lmi)
	if tree_pts.size() > MAX_TREES_PER_REGION:
		var keep := PackedVector2Array()
		var step: float = float(tree_pts.size()) / float(MAX_TREES_PER_REGION)
		for i: int in range(MAX_TREES_PER_REGION):
			keep.append(tree_pts[int(float(i) * step)])
		tree_pts = keep
	if tree_pts.size() > 0:
		_build_trees(root, tree_pts, o)


static func _emit_area_lines(lines: Batch, kind: String, poly: PackedVector2Array, y: float) -> void:
	match kind:
		"pitch":
			_emit_outline_strip(lines, poly, y + 0.01, 0.12)
		"pool", "water_park":
			_emit_outline_strip(lines, poly, y + 0.005, 0.45)
		"parking":
			_emit_parking_stripes(lines, poly, y + 0.01)


static func _build_water(root: Node3D, md: MapData, region: String, m: Dictionary) -> void:
	var wb := Batch.new()
	var bb := Batch.new()
	for w: Dictionary in md.water(region):
		var poly: PackedVector2Array = _water_polygon(w)
		if poly.size() < 3:
			continue
		_emit_polygon(wb, poly, WATER_Y, Vector3.UP, 1.0 / WATER_TILE_M)
		_emit_bank(bb, poly)
	var mi: MeshInstance3D = _commit(wb, m["water"], "Water")
	if mi:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var bmi: MeshInstance3D = _commit(bb, m["bank"], "Banks")
	if bmi:
		bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bmi)


static func _build_roads(root: Node3D, md: MapData, region: String, m: Dictionary, o: Dictionary) -> void:
	var by_class: Dictionary = {}
	var kerbs := Batch.new()
	var overlay := Batch.new()
	var foot := Batch.new()
	var bridge_parts := Batch.new()
	var lod: int = int(o["lod"])
	for r: Dictionary in md.roads(region):
		var pts2: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts2.size() < 2:
			continue
		var width: float = float(r.get("width", 6.0))
		var lanes: int = int(r.get("lanes", 2))
		if lanes <= 0:
			var w: float = clampf(width, 1.5, 2.5)
			var fp: PackedVector3Array = _footway_profile(pts2)
			_emit_ribbon(foot, fp, w, 0.0, 0.0, 1.0, 1.0 / OVERLAY_TILE_M)
			_emit_skirts(foot, fp, w, GROUND_Y - 0.05)
			continue
		var bridge: bool = bool(r.get("bridge", false))
		var pts3: PackedVector3Array = _road_profile(pts2, bridge, ROAD_Y)
		var cls: String = str(r.get("class", "residential"))
		cls = str(CLASS_ALIAS.get(cls, cls))
		if not by_class.has(cls):
			by_class[cls] = Batch.new()
		_emit_ribbon(by_class[cls], pts3, width, 0.0, 0.0, 1.0, 1.0 / OVERLAY_TILE_M)
		if lod >= 2:
			continue
		if bridge:
			_emit_bridge_parts(bridge_parts, pts3, width)
		elif width >= KERB_MIN_ROAD_W:
			_emit_kerbs(kerbs, pts3, width)
		if width >= KERB_MIN_ROAD_W and cls != "service":
			_emit_overlay(overlay, pts3, width, bool(r.get("oneway", false)))
	var colliders: bool = bool(o["colliders"])
	for cls: String in by_class.keys():
		var mi: MeshInstance3D = _commit(by_class[cls], m["asphalt"], "Roads_" + cls)
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		if colliders:
			_add_trimesh_collider(mi)
	var kmi: MeshInstance3D = _commit(kerbs, m["kerb"], "Kerbs")
	if kmi:
		root.add_child(kmi)
		if colliders:
			_add_trimesh_collider(kmi)
	var omi: MeshInstance3D = _commit(overlay, m["overlay"], "RoadLines")
	if omi:
		omi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(omi)
	var fmi: MeshInstance3D = _commit(foot, m["sidewalk"], "Footways")
	if fmi:
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fmi)
		if colliders:
			_add_trimesh_collider(fmi)
	var bmi: MeshInstance3D = _commit(bridge_parts, m["barrier"], "BridgeParts")
	if bmi:
		root.add_child(bmi)
		if colliders:
			_add_trimesh_collider(bmi)


static func _build_buildings(root: Node3D, md: MapData, region: String, m: Dictionary, o: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Buildings"
	root.add_child(holder)
	var skip: Array = o["skip_building_ids"]
	var lod: int = int(o["lod"])
	var boxes := Batch.new()
	for b: Dictionary in md.buildings(region):
		if skip.has(int(b.get("id", 0))):
			continue
		if lod >= 2:
			var outer: PackedVector2Array = _open(MapData.poly(b.get("outer", [])))
			if outer.size() < 3:
				continue
			var height: float = maxf(3.0, float(b.get("height", 7.2)))
			_emit_walls(boxes, outer, 0.0, height, 1.0, 1.0, false)
			_emit_polygon(boxes, outer, height, Vector3.UP, 0.25)
			continue
		build_building(holder, b, o)
	if lod >= 2:
		var mi: MeshInstance3D = _commit(boxes, m["box"], "BuildingBoxes")
		if mi:
			holder.add_child(mi)
			if bool(o["colliders"]):
				_add_trimesh_collider(mi)


static func _build_pois(root: Node3D, md: MapData, region: String, m: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "POIs"
	root.add_child(holder)
	var poles := Batch.new()
	var plates := Batch.new()
	for p: Dictionary in md.pois(region):
		var text: String = str(p.get("display", ""))
		if text == "":
			text = str(p.get("name", ""))
		if text == "":
			continue
		var pos := Vector3(float(p.get("x", 0.0)), 0.0, float(p.get("z", 0.0)))
		_emit_box(poles, pos + Vector3(0.0, 1.4, 0.0), Vector3(0.08, 2.8, 0.08))
		if str(p.get("kind", "")) == "bus_stop":
			_emit_box(plates, pos + Vector3(0.0, 2.55, 0.0), Vector3(0.7, 0.45, 0.06))
		var l := Label3D.new()
		l.text = text
		l.font_size = 36
		l.pixel_size = 0.02
		l.outline_size = 8
		l.modulate = Color(0.12, 0.10, 0.22)
		l.outline_modulate = Color(1.0, 1.0, 1.0, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = pos + Vector3(0.0, 3.3, 0.0)
		holder.add_child(l)
	var pmi: MeshInstance3D = _commit(poles, m["pole"], "POISigns")
	if pmi:
		holder.add_child(pmi)
	var bmi: MeshInstance3D = _commit(plates, m["sign_blue"], "POIPlates")
	if bmi:
		holder.add_child(bmi)


# ===========================================================================
# TREES (baked FPTUCampusBuilder trees in MultiMeshes)
# ===========================================================================

static func _ensure_tree_meshes() -> void:
	if not _tree_meshes.is_empty():
		return
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var tmp := Node3D.new()
	var protos: Array = []
	# royal palms (build_royal_palm) read as antennas at map distances, so parks only get the round canopies
	for v: Array in [[0.9, 11], [1.05, 23], [1.2, 37]]:
		protos.append(FPTUCampusBuilder.build_tropical_tree(tmp, Vector3.ZERO, cm, float(v[0]), int(v[1])))
	for t: Node3D in protos:
		_tree_meshes.append(_bake_node(t))
	tmp.free()


## Merges every MeshInstance3D under `node` (in the parent's frame) into one ArrayMesh, one surface per material,
## with the primitive meshes simplified first (trees are instanced hundreds of times).
static func _bake_node(node: Node3D) -> ArrayMesh:
	var by_mat: Dictionary = {}
	var order: Array = []
	var stack: Array = [[node, node.transform]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		for c: Node in n.get_children():
			if c is MeshInstance3D:
				var mi: MeshInstance3D = c
				var cxf: Transform3D = xf * mi.transform
				if mi.mesh is SphereMesh:
					(mi.mesh as SphereMesh).radial_segments = 10
					(mi.mesh as SphereMesh).rings = 5
				elif mi.mesh is CylinderMesh:
					(mi.mesh as CylinderMesh).radial_segments = 10
					(mi.mesh as CylinderMesh).rings = 1
				for si: int in range(mi.mesh.get_surface_count()):
					var mat: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si)
					if not by_mat.has(mat):
						var st := SurfaceTool.new()
						st.begin(Mesh.PRIMITIVE_TRIANGLES)
						by_mat[mat] = st
						order.append(mat)
					(by_mat[mat] as SurfaceTool).append_from(mi.mesh, si, cxf)
				stack.append([mi, cxf])
			elif c is Node3D:
				stack.append([c, xf * (c as Node3D).transform])
	var out := ArrayMesh.new()
	for mat: Material in order:
		var st: SurfaceTool = by_mat[mat]
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


static func _build_trees(root: Node3D, pts: PackedVector2Array, o: Dictionary) -> void:
	if pts.is_empty():
		return
	_ensure_tree_meshes()
	var holder := Node3D.new()
	holder.name = "Trees"
	root.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var groups: Array = []
	for _vi: int in range(_tree_meshes.size()):
		groups.append([])
	for p: Vector2 in pts:
		var vi: int = rng.randi_range(0, _tree_meshes.size() - 1)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2))
		(groups[vi] as Array).append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	for vi: int in range(groups.size()):
		var g: Array = groups[vi]
		if g.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _tree_meshes[vi]
		mm.instance_count = g.size()
		for i: int in range(g.size()):
			mm.set_instance_transform(i, g[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Trees_%d" % vi
		holder.add_child(mmi)
	if bool(o["colliders"]):
		var sb := StaticBody3D.new()
		sb.name = "TreeColliders"
		var shape := CylinderShape3D.new()
		shape.radius = 0.35
		shape.height = 6.0
		for p: Vector2 in pts:
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(p.x, 3.0, p.y)
			sb.add_child(cs)
		holder.add_child(sb)


## Rejection sampling of `count` tree positions inside `poly` (and inside one of `pieces`, i.e. not on water),
## at least 2.5 m away from any carriageway. Deterministic per area id.
static func _sample_tree_points(poly: PackedVector2Array, pieces: Array, count: float, seed_val: int, out: PackedVector2Array) -> void:
	var n: int = int(floor(count))
	if n <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var bb: Rect2 = _bbox(poly)
	var tries: int = n * 12
	var placed: int = 0
	while tries > 0 and placed < n:
		tries -= 1
		var p := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var in_piece: bool = pieces.is_empty()
		for piece: PackedVector2Array in pieces:
			if Geometry2D.is_point_in_polygon(p, piece):
				in_piece = true
				break
		if not in_piece:
			continue
		if _near_carriageway(p, 2.5):
			continue
		out.append(p)
		placed += 1


# ===========================================================================
# ROAD GEOMETRY
# ===========================================================================

## Resamples the polyline (<= RIBBON_STEP_M) and assigns y: `y` on the ground, plus the bridge ramp profile.
static func _road_profile(pts2: PackedVector2Array, bridge: bool, y: float) -> PackedVector3Array:
	var rs: PackedVector2Array = _resample(pts2, RIBBON_STEP_M)
	var out := PackedVector3Array()
	out.resize(rs.size())
	var total: float = 0.0
	for i: int in range(1, rs.size()):
		total += rs[i - 1].distance_to(rs[i])
	var s: float = 0.0
	for i: int in range(rs.size()):
		if i > 0:
			s += rs[i - 1].distance_to(rs[i])
		var h: float = 0.0
		if bridge:
			h = BRIDGE_H * clampf(minf(s, total - s) / BRIDGE_RAMP_M, 0.0, 1.0)
		out[i] = Vector3(rs[i].x, y + h, rs[i].y)
	return out


## Footway profile: FOOTWAY_Y, dipping under the asphalt where the path crosses a carriageway.
static func _footway_profile(pts2: PackedVector2Array) -> PackedVector3Array:
	var rs: PackedVector2Array = _resample(pts2, FOOTWAY_STEP_M)
	var out := PackedVector3Array()
	out.resize(rs.size())
	for i: int in range(rs.size()):
		var y: float = FOOTWAY_DIP_Y if _near_carriageway(rs[i], 0.6) else FOOTWAY_Y
		out[i] = Vector3(rs[i].x, y, rs[i].y)
	return out


## Per-vertex lateral offset (unit normal scaled for the mitre, clamped to 2x) of a 3D polyline in the xz plane.
static func _mitre_offsets(pts: PackedVector3Array) -> PackedVector2Array:
	var n: int = pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i: int in range(n):
		var d_prev := Vector2.ZERO
		var d_next := Vector2.ZERO
		if i > 0:
			d_prev = Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).normalized()
		if i < n - 1:
			d_next = Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).normalized()
		var d: Vector2 = (d_prev + d_next)
		if d.length_squared() < 1e-6:
			d = d_next if d_next.length_squared() > 0.0 else d_prev
		d = d.normalized()
		var nrm := Vector2(-d.y, d.x)
		var seg_d: Vector2 = d_next if d_next.length_squared() > 0.0 else d_prev
		var seg_n := Vector2(-seg_d.y, seg_d.x)
		var scale: float = 1.0 / maxf(0.5, nrm.dot(seg_n))
		out[i] = nrm * scale
	return out


## Ribbon quads along a 3D polyline (y per vertex), UV u = length * u_scale, v from v0 (left) to v1 (right).
static func _emit_ribbon(b: Batch, pts: PackedVector3Array, width: float, lift: float, v0: float, v1: float, u_scale: float) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var offs: PackedVector2Array = _mitre_offsets(pts)
	var half: float = width * 0.5
	var u: float = 0.0
	for i: int in range(n - 1):
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		var seg_len: float = Vector2(c.x - a.x, c.z - a.z).length()
		var oa := Vector3(offs[i].x, 0.0, offs[i].y) * half
		var oc := Vector3(offs[i + 1].x, 0.0, offs[i + 1].y) * half
		var up := Vector3(0.0, lift, 0.0)
		var la: Vector3 = a + oa + up
		var ra: Vector3 = a - oa + up
		var lc: Vector3 = c + oc + up
		var rc: Vector3 = c - oc + up
		var ua: float = u * u_scale
		var uc: float = (u + seg_len) * u_scale
		_quad(b, la, lc, rc, ra, Vector2(ua, v0), Vector2(uc, v0), Vector2(uc, v1), Vector2(ua, v1), Vector3.UP)
		u += seg_len


## Vertical skirts along both ribbon edges down to `y_bottom` plus end caps (raised footways look solid).
static func _emit_skirts(b: Batch, pts: PackedVector3Array, width: float, y_bottom: float) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var offs: PackedVector2Array = _mitre_offsets(pts)
	var half: float = width * 0.5
	for i: int in range(n - 1):
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		for side: float in [-1.0, 1.0]:
			var oa := Vector3(offs[i].x, 0.0, offs[i].y) * half * side
			var oc := Vector3(offs[i + 1].x, 0.0, offs[i + 1].y) * half * side
			var ea: Vector3 = a + oa
			var ec: Vector3 = c + oc
			var want := Vector3(oa.x, 0.0, oa.z)
			_quad(b, Vector3(ea.x, y_bottom, ea.z), Vector3(ec.x, y_bottom, ec.z), ec, ea, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), want)
	for end: int in [0, n - 1]:
		var p: Vector3 = pts[end]
		var o := Vector3(offs[end].x, 0.0, offs[end].y) * half
		var dir: Vector3 = (pts[1] - pts[0]) if end == 0 else (pts[n - 1] - pts[n - 2])
		var want: Vector3 = -dir if end == 0 else dir
		_quad(b, Vector3(p.x + o.x, y_bottom, p.z + o.z), Vector3(p.x - o.x, y_bottom, p.z - o.z), p - o, p + o, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), want)


## Kerb boxes (KERB_W wide, top at road y + KERB_ABOVE_ROAD) along both edges, with the runs inside junction
## discs left out and end caps where a run starts or stops.
static func _emit_kerbs(b: Batch, pts: PackedVector3Array, width: float) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var offs: PackedVector2Array = _mitre_offsets(pts)
	var half: float = width * 0.5
	var y_bottom: float = GROUND_Y - 0.05
	for side: float in [-1.0, 1.0]:
		var prev_open: bool = false
		for i: int in range(n - 1):
			var a: Vector3 = pts[i]
			var c: Vector3 = pts[i + 1]
			var oa := Vector3(offs[i].x, 0.0, offs[i].y) * side
			var oc := Vector3(offs[i + 1].x, 0.0, offs[i + 1].y) * side
			var ia: Vector3 = a + oa * half
			var ic: Vector3 = c + oc * half
			var xa: Vector3 = a + oa * (half + KERB_W)
			var xc: Vector3 = c + oc * (half + KERB_W)
			var runs: Array = _free_runs(Vector2(ia.x, ia.z), Vector2(ic.x, ic.z))
			var dir: Vector3 = c - a
			var last_t1: float = -1.0
			for run: Array in runs:
				var t0: float = run[0]
				var t1: float = run[1]
				var i0: Vector3 = ia.lerp(ic, t0)
				var i1: Vector3 = ia.lerp(ic, t1)
				var x0: Vector3 = xa.lerp(xc, t0)
				var x1: Vector3 = xa.lerp(xc, t1)
				var ti0 := Vector3(i0.x, i0.y + KERB_ABOVE_ROAD, i0.z)
				var ti1 := Vector3(i1.x, i1.y + KERB_ABOVE_ROAD, i1.z)
				var tx0 := Vector3(x0.x, x0.y + KERB_ABOVE_ROAD, x0.z)
				var tx1 := Vector3(x1.x, x1.y + KERB_ABOVE_ROAD, x1.z)
				var bx0 := Vector3(x0.x, y_bottom, x0.z)
				var bx1 := Vector3(x1.x, y_bottom, x1.z)
				var u0: float = t0 * dir.length() * 0.5
				var u1: float = t1 * dir.length() * 0.5
				# top
				_quad(b, ti0, ti1, tx1, tx0, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.3), Vector2(u0, 0.3), Vector3.UP)
				# inner face (towards the road)
				_quad(b, i0, i1, ti1, ti0, Vector2(u0, 0.5), Vector2(u1, 0.5), Vector2(u1, 0.4), Vector2(u0, 0.4), -oa)
				# outer face (down to below ground)
				_quad(b, bx0, bx1, tx1, tx0, Vector2(u0, 0.8), Vector2(u1, 0.8), Vector2(u1, 0.6), Vector2(u0, 0.6), oa)
				if t0 > 0.001 or i == 0 or not prev_open:
					_quad(b, Vector3(i0.x, y_bottom, i0.z), bx0, tx0, ti0, Vector2(0, 1), Vector2(0.3, 1), Vector2(0.3, 0.8), Vector2(0, 0.8), -dir)
				if t1 < 0.999 or i == n - 2:
					_quad(b, Vector3(i1.x, y_bottom, i1.z), bx1, tx1, ti1, Vector2(0, 1), Vector2(0.3, 1), Vector2(0.3, 0.8), Vector2(0, 0.8), dir)
				last_t1 = t1
			prev_open = last_t1 >= 0.999


## Lane overlay strip (city_road_overlay.png: 4 m along u x one carriageway across v) lifted OVERLAY_LIFT above
## the ribbon, cut inside junction discs. Two-way: full tile (edge lines + yellow centre dashes); oneway: the two
## edge bands only (v 0..0.45 and 0.55..1), so no centre line.
static func _emit_overlay(b: Batch, pts: PackedVector3Array, width: float, oneway: bool) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var offs: PackedVector2Array = _mitre_offsets(pts)
	var half: float = width * 0.5
	var u: float = 0.0
	var bands: Array = [[-1.0, 1.0, 0.0, 1.0]] if not oneway else [[-1.0, -0.1, 0.0, 0.45], [0.1, 1.0, 0.55, 1.0]]
	for i: int in range(n - 1):
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		var seg_len: float = Vector2(c.x - a.x, c.z - a.z).length()
		var oa := Vector3(offs[i].x, 0.0, offs[i].y) * half
		var oc := Vector3(offs[i + 1].x, 0.0, offs[i + 1].y) * half
		var runs: Array = _free_runs(Vector2(a.x, a.z), Vector2(c.x, c.z))
		for run: Array in runs:
			var t0: float = run[0]
			var t1: float = run[1]
			if t1 - t0 < 0.02:
				continue
			var p0: Vector3 = a.lerp(c, t0) + Vector3(0.0, OVERLAY_LIFT, 0.0)
			var p1: Vector3 = a.lerp(c, t1) + Vector3(0.0, OVERLAY_LIFT, 0.0)
			var o0: Vector3 = oa.lerp(oc, t0)
			var o1: Vector3 = oa.lerp(oc, t1)
			var u0: float = (u + seg_len * t0) / OVERLAY_TILE_M
			var u1: float = (u + seg_len * t1) / OVERLAY_TILE_M
			for band: Array in bands:
				var l: float = band[0]
				var r: float = band[1]
				var v0: float = band[2]
				var v1: float = band[3]
				_quad(b, p0 + o0 * l, p1 + o1 * l, p1 + o1 * r, p0 + o0 * r, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), Vector3.UP)
		u += seg_len


## Bridge extras: side barriers where the deck is up, deck underside, pillars every PILLAR_EVERY_M.
static func _emit_bridge_parts(b: Batch, pts: PackedVector3Array, width: float) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var offs: PackedVector2Array = _mitre_offsets(pts)
	var half: float = width * 0.5
	var s: float = 0.0
	var next_pillar: float = PILLAR_EVERY_M * 0.5
	for i: int in range(n - 1):
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		var seg_len: float = Vector2(c.x - a.x, c.z - a.z).length()
		var oa := Vector3(offs[i].x, 0.0, offs[i].y)
		var oc := Vector3(offs[i + 1].x, 0.0, offs[i + 1].y)
		var up: bool = a.y > ROAD_Y + 0.3 or c.y > ROAD_Y + 0.3
		if up:
			# deck underside
			var down := Vector3(0.0, -DECK_T, 0.0)
			_quad(b, a + oa * half + down, c + oc * half + down, c - oc * half + down, a - oa * half + down, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector3.DOWN)
			for side: float in [-1.0, 1.0]:
				var ia: Vector3 = a + oa * half * side
				var ic: Vector3 = c + oc * half * side
				var xa: Vector3 = a + oa * (half + BARRIER_W) * side
				var xc: Vector3 = c + oc * (half + BARRIER_W) * side
				var h := Vector3(0.0, BARRIER_H, 0.0)
				var want: Vector3 = oa * side
				_quad(b, ia, ic, ic + h, ia + h, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), -want)
				_quad(b, ia + h, ic + h, xc + h, xa + h, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector3.UP)
				_quad(b, xa + down, xc + down, xc + h, xa + h, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), want)
		# pillars
		var s_end: float = s + seg_len
		while next_pillar <= s_end and seg_len > 0.0:
			var t: float = (next_pillar - s) / seg_len
			var p: Vector3 = a.lerp(c, t)
			if p.y > ROAD_Y + 2.5:
				var top: float = p.y - DECK_T + 0.05
				var bottom: float = GROUND_Y - 0.5
				_emit_box(b, Vector3(p.x, (top + bottom) * 0.5, p.z), Vector3(1.4, top - bottom, 1.4))
			next_pillar += PILLAR_EVERY_M
		s = s_end


# ===========================================================================
# BUILDING GEOMETRY
# ===========================================================================

## Wall quads for one ring: u = edge length / tile_w (restarting per edge), v = 0 at y1 (roof) .. v_ground at y0.
## Outer rings face away from the ring interior, inner rings (courtyards) face into it.
static func _emit_walls(b: Batch, ring: PackedVector2Array, y0: float, y1: float, tile_w: float, v_ground: float, inward: bool) -> void:
	var sgn: float = 1.0 if _signed_area(ring) > 0.0 else -1.0
	var n: int = ring.size()
	for i: int in range(n):
		var a: Vector2 = ring[i]
		var c: Vector2 = ring[(i + 1) % n]
		var d: Vector2 = c - a
		var len: float = d.length()
		if len < 0.01:
			continue
		var left := Vector2(-d.y, d.x) / len
		var outward: Vector2 = -left * sgn
		if inward:
			outward = -outward
		var want := Vector3(outward.x, 0.0, outward.y)
		var u1: float = len / tile_w
		_quad(b, Vector3(a.x, y0, a.y), Vector3(c.x, y0, c.y), Vector3(c.x, y1, c.y), Vector3(a.x, y1, a.y), Vector2(0.0, v_ground), Vector2(u1, v_ground), Vector2(u1, 0.0), Vector2(0.0, 0.0), want)


## Parapet ring on the roof edge: outer face, top and inner face, `t` thick and `h` high.
static func _emit_parapet(b: Batch, ring: PackedVector2Array, y: float, h: float, t: float, inward: bool) -> void:
	var n: int = ring.size()
	if n < 3:
		return
	var sgn: float = 1.0 if _signed_area(ring) > 0.0 else -1.0
	# positive-area ring: interior is to the left of travel; the parapet sits on the building-mass side
	# (inside the outer ring, outside a courtyard ring)
	var inset: PackedVector2Array = _offset_ring(ring, t * sgn * (-1.0 if inward else 1.0))
	for i: int in range(n):
		var j: int = (i + 1) % n
		var a: Vector2 = ring[i]
		var c: Vector2 = ring[j]
		var d: Vector2 = c - a
		if d.length() < 0.01:
			continue
		var left := Vector2(-d.y, d.x).normalized()
		var outward: Vector2 = -left * sgn
		if inward:
			outward = -outward
		var want := Vector3(outward.x, 0.0, outward.y)
		var ai: Vector2 = inset[i]
		var ci: Vector2 = inset[j]
		var u1: float = d.length() * 0.25
		_quad(b, Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(c.x, y + h, c.y), Vector3(a.x, y + h, a.y), Vector2(0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(0, 0), want)
		_quad(b, Vector3(a.x, y + h, a.y), Vector3(c.x, y + h, c.y), Vector3(ci.x, y + h, ci.y), Vector3(ai.x, y + h, ai.y), Vector2(0, 0), Vector2(u1, 0), Vector2(u1, 0.1), Vector2(0, 0.1), Vector3.UP)
		_quad(b, Vector3(ai.x, y, ai.y), Vector3(ci.x, y, ci.y), Vector3(ci.x, y + h, ci.y), Vector3(ai.x, y + h, ai.y), Vector2(0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(0, 0), -want)


## Ring offset along the mitred vertex normals (positive = towards the "left" of travel for a positive-area ring).
static func _offset_ring(ring: PackedVector2Array, dist: float) -> PackedVector2Array:
	var n: int = ring.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i: int in range(n):
		var p: Vector2 = ring[i]
		var d_prev: Vector2 = (p - ring[(i - 1 + n) % n]).normalized()
		var d_next: Vector2 = (ring[(i + 1) % n] - p).normalized()
		var d: Vector2 = (d_prev + d_next)
		if d.length_squared() < 1e-6:
			d = d_next
		d = d.normalized()
		var nrm := Vector2(-d.y, d.x)
		var seg_n := Vector2(-d_next.y, d_next.x)
		var scale: float = 1.0 / maxf(0.5, nrm.dot(seg_n))
		out[i] = p + nrm * scale * dist
	return out


# ===========================================================================
# WATER / AREA GEOMETRY
# ===========================================================================

static func _water_polygon(w: Dictionary) -> PackedVector2Array:
	if str(w.get("kind", "area")) == "line":
		var pts: PackedVector2Array = MapData.poly(w.get("points", []))
		if pts.size() < 2:
			return PackedVector2Array()
		var half: float = maxf(1.0, float(w.get("width", 6.0)) * 0.5)
		var polys: Array = Geometry2D.offset_polyline(pts, half, Geometry2D.JOIN_ROUND, Geometry2D.END_SQUARE)
		var best := PackedVector2Array()
		var best_area: float = 0.0
		for p: PackedVector2Array in polys:
			var a: float = _abs_area(p)
			if a > best_area:
				best_area = a
				best = p
		return best
	return _open(MapData.poly(w.get("outer", [])))


## Every water body of the map as a polygon (cached per MapData): the ground and area planes are cut around them.
static func _water_polygons(md: MapData) -> Array:
	if _water_cache_md == md:
		return _water_cache
	_water_cache_md = md
	_water_cache = []
	for w: Dictionary in md.water():
		var p: PackedVector2Array = _water_polygon(w)
		if p.size() >= 3:
			_water_cache.append(p)
	return _water_cache


## Bank walls along a water outline from just above the ground down below the water surface, facing the water.
static func _emit_bank(b: Batch, poly: PackedVector2Array) -> void:
	var ring: PackedVector2Array = _open(poly)
	var n: int = ring.size()
	if n < 3:
		return
	var sgn: float = 1.0 if _signed_area(ring) > 0.0 else -1.0
	var y_top: float = GROUND_Y + 0.02
	var y_bot: float = WATER_Y - 0.2
	var u: float = 0.0
	for i: int in range(n):
		var a: Vector2 = ring[i]
		var c: Vector2 = ring[(i + 1) % n]
		var d: Vector2 = c - a
		var len: float = d.length()
		if len < 0.01:
			continue
		var left := Vector2(-d.y, d.x) / len
		var inward: Vector2 = left * sgn
		var want := Vector3(inward.x, 0.0, inward.y)
		_quad(b, Vector3(a.x, y_bot, a.y), Vector3(c.x, y_bot, c.y), Vector3(c.x, y_top, c.y), Vector3(a.x, y_top, a.y), Vector2(u * 0.25, 1), Vector2((u + len) * 0.25, 1), Vector2((u + len) * 0.25, 0), Vector2(u * 0.25, 0), want)
		u += len


## White strip along a polygon outline (pitch lines, pool kerb).
static func _emit_outline_strip(b: Batch, poly: PackedVector2Array, y: float, w: float) -> void:
	var ring: PackedVector2Array = _open(poly)
	if ring.size() < 3:
		return
	var pts := PackedVector3Array()
	pts.resize(ring.size() + 1)
	for i: int in range(ring.size()):
		pts[i] = Vector3(ring[i].x, y, ring[i].y)
	pts[ring.size()] = pts[0]
	_emit_ribbon(b, pts, w, 0.0, 0.0, 1.0, 1.0)


## Parking bay stripes perpendicular to the longest edge, every 2.5 m, only where fully inside the polygon.
static func _emit_parking_stripes(b: Batch, poly: PackedVector2Array, y: float) -> void:
	var ring: PackedVector2Array = _open(poly)
	var n: int = ring.size()
	if n < 3:
		return
	var best_i: int = 0
	var best_len: float = -1.0
	for i: int in range(n):
		var l: float = ring[i].distance_to(ring[(i + 1) % n])
		if l > best_len:
			best_len = l
			best_i = i
	var a: Vector2 = ring[best_i]
	var d: Vector2 = (ring[(best_i + 1) % n] - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	var c: Vector2 = _centroid(ring)
	if (c - a).dot(nrm) < 0.0:
		nrm = -nrm
	var bay: float = 5.0
	var count: int = int(best_len / 2.5)
	for k: int in range(count + 1):
		var p0: Vector2 = a + d * (float(k) * 2.5) + nrm * 0.4
		var p1: Vector2 = p0 + nrm * bay
		if not Geometry2D.is_point_in_polygon(p0, ring) or not Geometry2D.is_point_in_polygon(p1, ring):
			continue
		var pts := PackedVector3Array([Vector3(p0.x, y, p0.y), Vector3(p1.x, y, p1.y)])
		_emit_ribbon(b, pts, 0.12, 0.0, 0.0, 1.0, 1.0)


# ===========================================================================
# JUNCTION / CARRIAGEWAY INDEX
# ===========================================================================

## Spatial hash of every carriageway segment of the map plus the junction discs (kerb-free zones).
static func _prepare_road_index(md: MapData) -> void:
	if _hash_md == md:
		return
	_hash_md = md
	_seg_hash = {}
	_carriageways = []
	_discs = []
	_disc_hash = {}
	_max_disc_r = 0.0
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 0)) <= 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts.size() < 2:
			continue
		var ci: int = _carriageways.size()
		_carriageways.append([pts, float(r.get("width", 6.0))])
		for si: int in range(pts.size() - 1):
			for cell: Vector2i in _cells_of_box(_seg_box(pts[si], pts[si + 1]), 0.0):
				if not _seg_hash.has(cell):
					_seg_hash[cell] = []
				(_seg_hash[cell] as Array).append(Vector2i(ci, si))
	for ci: int in range(_carriageways.size()):
		var pts: PackedVector2Array = _carriageways[ci][0]
		var w: float = _carriageways[ci][1]
		var last: int = pts.size() - 1
		for k: int in range(pts.size()):
			var p: Vector2 = pts[k]
			var touching: Dictionary = {}
			for sv: Vector2i in _segments_near(p):
				if sv.x == ci:
					continue
				var op: PackedVector2Array = _carriageways[sv.x][0]
				if _dist_point_segment(p, op[sv.y], op[sv.y + 1]) <= 0.6:
					touching[sv.x] = true
			if touching.is_empty():
				continue
			var is_end: bool = (k == 0 or k == last)
			if is_end and touching.size() == 1 and _is_continuation(pts, k, w, int(touching.keys()[0])):
				continue
			var max_w: float = 0.0
			for oc: int in touching.keys():
				max_w = maxf(max_w, float(_carriageways[oc][1]))
			var rad: float = sqrt((w * 0.5) * (w * 0.5) + (max_w * 0.5) * (max_w * 0.5)) + KERB_W + 0.6
			_discs.append([p, rad])
			_max_disc_r = maxf(_max_disc_r, rad)
	for di: int in range(_discs.size()):
		var cell: Vector2i = _cell(_discs[di][0])
		if not _disc_hash.has(cell):
			_disc_hash[cell] = []
		(_disc_hash[cell] as Array).append(di)


## True when way `pts` ends at vertex k where carriageway `oc` of the same width continues it almost straight
## (the same street split into OSM ways): no junction disc there, the kerbs simply continue.
static func _is_continuation(pts: PackedVector2Array, k: int, w: float, oc: int) -> bool:
	var op: PackedVector2Array = _carriageways[oc][0]
	var ow: float = _carriageways[oc][1]
	if absf(ow - w) > 0.1 or op.size() < 2:
		return false
	var p: Vector2 = pts[k]
	var last: int = pts.size() - 1
	var o_end: int = -1
	if op[0].distance_to(p) <= 0.6:
		o_end = 0
	elif op[op.size() - 1].distance_to(p) <= 0.6:
		o_end = op.size() - 1
	if o_end < 0:
		return false
	var in_dir: Vector2 = (pts[last] - pts[last - 1]).normalized() if k == last else (pts[0] - pts[1]).normalized()
	var out_dir: Vector2 = (op[1] - op[0]).normalized() if o_end == 0 else (op[o_end - 1] - op[o_end]).normalized()
	return in_dir.dot(out_dir) > cos(deg_to_rad(25.0))


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / HASH_CELL)), int(floor(p.y / HASH_CELL)))


static func _seg_box(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(a.x - b.x), absf(a.y - b.y)))


static func _cells_of_box(box: Rect2, grow: float) -> Array:
	var c0: Vector2i = _cell(box.position - Vector2(grow, grow))
	var c1: Vector2i = _cell(box.end + Vector2(grow, grow))
	var out: Array = []
	for cx: int in range(c0.x, c1.x + 1):
		for cy: int in range(c0.y, c1.y + 1):
			out.append(Vector2i(cx, cy))
	return out


static func _segments_near(p: Vector2) -> Array:
	var c: Vector2i = _cell(p)
	var out: Array = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var key := Vector2i(c.x + dx, c.y + dy)
			if _seg_hash.has(key):
				out.append_array(_seg_hash[key])
	return out


## True when `p` lies on a carriageway ribbon (distance to the centreline <= width / 2 + margin).
static func _near_carriageway(p: Vector2, margin: float) -> bool:
	for sv: Vector2i in _segments_near(p):
		var cw: Array = _carriageways[sv.x]
		var pts: PackedVector2Array = cw[0]
		if _dist_point_segment(p, pts[sv.y], pts[sv.y + 1]) <= float(cw[1]) * 0.5 + margin:
			return true
	return false


## Parameter intervals [t0, t1] of segment a->b that lie OUTSIDE every junction disc.
static func _free_runs(a: Vector2, b: Vector2) -> Array:
	var d: Vector2 = b - a
	var len2: float = d.length_squared()
	if len2 < 1e-6:
		return []
	if _discs.is_empty():
		return [[0.0, 1.0]]
	var ivs: Array = []
	for cell: Vector2i in _cells_of_box(_seg_box(a, b), _max_disc_r):
		if not _disc_hash.has(cell):
			continue
		for di: int in _disc_hash[cell]:
			var c: Vector2 = _discs[di][0]
			var r: float = _discs[di][1]
			var f: Vector2 = a - c
			var bq: float = 2.0 * d.dot(f)
			var cq: float = f.length_squared() - r * r
			var disc: float = bq * bq - 4.0 * len2 * cq
			if disc <= 0.0:
				continue
			var sq: float = sqrt(disc)
			var t0: float = (-bq - sq) / (2.0 * len2)
			var t1: float = (-bq + sq) / (2.0 * len2)
			if t1 <= 0.0 or t0 >= 1.0:
				continue
			ivs.append([maxf(0.0, t0), minf(1.0, t1)])
	if ivs.is_empty():
		return [[0.0, 1.0]]
	ivs.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var runs: Array = []
	var cur: float = 0.0
	for iv: Array in ivs:
		if iv[0] > cur + 0.001:
			runs.append([cur, iv[0]])
		cur = maxf(cur, iv[1])
	if cur < 0.999:
		runs.append([cur, 1.0])
	return runs


static func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 < 1e-9:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ===========================================================================
# POLYGON HELPERS
# ===========================================================================

## Subtracts every cutter polygon from the pieces; a cutter fully inside a piece (which would leave a hole) is
## handled by splitting the piece along the vertical line through the cutter's bbox centre first, so every
## result is a simple polygon that Geometry2D.triangulate_polygon accepts.
static func _subtract(pieces: Array, cutters: Array) -> Array:
	var cur: Array = pieces.duplicate()
	for cutter: PackedVector2Array in cutters:
		if cutter.size() < 3:
			continue
		var cb: Rect2 = _bbox(cutter)
		var next: Array = []
		for piece: PackedVector2Array in cur:
			if piece.size() < 3:
				continue
			var pb: Rect2 = _bbox(piece)
			if not pb.intersects(cb):
				next.append(piece)
				continue
			var res: Array = Geometry2D.clip_polygons(piece, cutter)
			if res.is_empty():
				continue
			if _has_hole(res):
				var cx: float = cb.position.x + cb.size.x * 0.5
				var gb: Rect2 = pb.grow(10.0)
				for half: PackedVector2Array in [_rect_poly(gb.position.x, gb.position.y, cx, gb.end.y), _rect_poly(cx, gb.position.y, gb.end.x, gb.end.y)]:
					for part: PackedVector2Array in Geometry2D.intersect_polygons(piece, half):
						for r: PackedVector2Array in Geometry2D.clip_polygons(part, cutter):
							if r.size() >= 3:
								next.append(r)
			else:
				for r: PackedVector2Array in res:
					if r.size() >= 3:
						next.append(r)
		cur = next
	return cur


static func _has_hole(polys: Array) -> bool:
	for i: int in range(polys.size()):
		if _is_hole_of_any(polys[i], polys):
			return true
	return false


static func _is_hole_of_any(p: PackedVector2Array, polys: Array) -> bool:
	if p.size() < 1:
		return false
	for q: PackedVector2Array in polys:
		if q == p or q.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(p[0], q):
			return true
	return false


static func _rect_poly(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _disc_poly(c: Vector2, r: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(segments)
	for i: int in range(segments):
		var a: float = float(i) / float(segments) * TAU
		out[i] = c + Vector2(cos(a), sin(a)) * r
	return out


static func _triangulate(poly: PackedVector2Array) -> PackedInt32Array:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if idx.is_empty() and poly.size() >= 3:
		var d: PackedInt32Array = Geometry2D.triangulate_delaunay(poly)
		for k: int in range(0, d.size(), 3):
			var c: Vector2 = (poly[d[k]] + poly[d[k + 1]] + poly[d[k + 2]]) / 3.0
			if Geometry2D.is_point_in_polygon(c, poly):
				idx.append(d[k])
				idx.append(d[k + 1])
				idx.append(d[k + 2])
	return idx


## Triangulated horizontal polygon at height y with world-space UVs (uv = xz * uv_scale).
static func _emit_polygon(b: Batch, poly: PackedVector2Array, y: float, want: Vector3, uv_scale: float) -> void:
	var p: PackedVector2Array = _open(poly)
	if p.size() < 3:
		return
	var idx: PackedInt32Array = _triangulate(p)
	for k: int in range(0, idx.size(), 3):
		var a: Vector2 = p[idx[k]]
		var c: Vector2 = p[idx[k + 1]]
		var d: Vector2 = p[idx[k + 2]]
		_tri(b, Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), a * uv_scale, c * uv_scale, d * uv_scale, want)


static func _emit_box(b: Batch, centre: Vector3, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	var x0: float = centre.x - h.x
	var x1: float = centre.x + h.x
	var y0: float = centre.y - h.y
	var y1: float = centre.y + h.y
	var z0: float = centre.z - h.z
	var z1: float = centre.z + h.z
	var uv: Array = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	_quad(b, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), uv[0], uv[1], uv[2], uv[3], Vector3.UP)
	_quad(b, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), uv[0], uv[1], uv[2], uv[3], Vector3.DOWN)
	_quad(b, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), uv[0], uv[1], uv[2], uv[3], Vector3.BACK)
	_quad(b, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), uv[0], uv[1], uv[2], uv[3], Vector3.FORWARD)
	_quad(b, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), uv[0], uv[1], uv[2], uv[3], Vector3.RIGHT)
	_quad(b, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), uv[0], uv[1], uv[2], uv[3], Vector3.LEFT)


## Quad a-b-c-d as two triangles wound so that the face normal points along `want`.
static func _quad(b: Batch, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2, want: Vector3) -> void:
	_tri(b, p0, p1, p2, uv0, uv1, uv2, want)
	_tri(b, p0, p2, p3, uv0, uv2, uv3, want)


## One triangle whose front side faces `want`. Godot front faces wind CLOCKWISE as seen from the front
## (ArrayMesh docs), i.e. (b - a) x (c - a) points AWAY from the viewer, so the order is flipped when that
## cross product has a positive dot with `want`. The shading normal is the face normal along `want`.
static func _tri(b: Batch, p0: Vector3, p1: Vector3, p2: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, want: Vector3) -> void:
	var nrm: Vector3 = (p1 - p0).cross(p2 - p0)
	var l2: float = nrm.length_squared()
	if l2 < 1e-10:
		return
	var st: SurfaceTool = b.st
	if nrm.dot(want) > 0.0:
		st.set_normal(nrm / sqrt(l2))
		st.set_uv(uv0)
		st.add_vertex(p0)
		st.set_uv(uv2)
		st.add_vertex(p2)
		st.set_uv(uv1)
		st.add_vertex(p1)
	else:
		st.set_normal(-nrm / sqrt(l2))
		st.set_uv(uv0)
		st.add_vertex(p0)
		st.set_uv(uv1)
		st.add_vertex(p1)
		st.set_uv(uv2)
		st.add_vertex(p2)
	b.n += 3


static func _commit(b: Batch, mat: Material, name: String) -> MeshInstance3D:
	if b.n == 0:
		return null
	var mesh: ArrayMesh = b.st.commit()
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = name
	return mi


static func _add_trimesh_collider(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var shape: ConcavePolygonShape3D = mi.mesh.create_trimesh_shape()
	if shape == null:
		return
	var sb := StaticBody3D.new()
	sb.name = "Col"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	mi.add_child(sb)


static func _resample(pts: PackedVector2Array, max_seg: float) -> PackedVector2Array:
	if max_seg <= 0.0 or pts.size() < 2:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i: int in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var c: Vector2 = pts[i]
		var n: int = maxi(1, ceili(a.distance_to(c) / max_seg))
		for k: int in range(1, n + 1):
			out.append(a.lerp(c, float(k) / float(n)))
	return out


## Drops the repeated closing point of a closed ring.
static func _open(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() >= 2 and poly[0].distance_to(poly[poly.size() - 1]) < 0.01:
		return poly.slice(0, poly.size() - 1)
	return poly


static func _signed_area(ring: PackedVector2Array) -> float:
	var s: float = 0.0
	var n: int = ring.size()
	for i: int in range(n):
		var a: Vector2 = ring[i]
		var c: Vector2 = ring[(i + 1) % n]
		s += a.x * c.y - c.x * a.y
	return s * 0.5


static func _abs_area(ring: PackedVector2Array) -> float:
	return absf(_signed_area(_open(ring)))


static func _centroid(ring: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	if ring.is_empty():
		return c
	for p: Vector2 in ring:
		c += p
	return c / float(ring.size())


static func _bbox(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		r = r.expand(p)
	return r


# ===========================================================================
# MATERIALS
# ===========================================================================

static func _plain(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func _tex_mat(file: String, fallback: Color, triplanar: bool, scale: float, rough: float, normal_file: String = "", normal_scale: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var t: Texture2D = FPTUCampusBuilder.load_texture(file)
	if t:
		m.albedo_texture = t
		m.uv1_triplanar = triplanar
		m.uv1_scale = Vector3(scale, scale, scale) if triplanar else Vector3.ONE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if normal_file != "":
			var nt: Texture2D = FPTUCampusBuilder.load_texture(normal_file)
			if nt:
				m.normal_enabled = true
				m.normal_texture = nt
				m.normal_scale = normal_scale
	else:
		m.albedo_color = fallback
	m.roughness = rough
	return m


## Facade material per style (cached): city_<style>_facade.png (+ _n normal map for tower/beverly),
## uv1_scale = (1, 1, 1) because the tile repeats are baked into the wall UVs (see the header).
static func _mat_for_style(style: String) -> StandardMaterial3D:
	if _style_mats.has(style):
		return _style_mats[style]
	var s: String = style if TILE_W.has(style) else "shophouse"
	var fallback: Dictionary = {"tower": Color("#8FBFD6"), "beverly": Color("#F2E8DA"), "mall": Color("#F0A050"), "shophouse": Color("#F6D2A8"), "industrial": Color("#A8D8CC")}
	var m: StandardMaterial3D = _tex_mat("city_%s_facade.png" % s, fallback[s], false, 1.0, 0.45 if s in ["tower", "mall"] else 0.8, "city_%s_facade_n.png" % s if s in NORMAL_MAPPED_STYLES else "", 0.7)
	m.uv1_scale = Vector3.ONE
	m.metallic = 0.05
	_style_mats[style] = m
	return m
