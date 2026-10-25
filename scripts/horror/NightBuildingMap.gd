# File: res://scripts/horror/NightBuildingMap.gd
# One floor of the campus building at night, built in code (spec B-D4), for the Night Building level.
# Layout (metres, floor y = 0, X east, Z south; a compact version of the real ring building):
#   courtyard x ±30, z ±15: paving and lawn halves, the golden toad, trees; seen through window walls (sill 0.9 m, glass to
#     2.6 m) from the ring corridor;
#   ring corridor 3 m wide around it (to x ±33, z ±18), centreline x ±31.5 / z ±16.5;
#   rooms 9 m deep outside the corridor (to x ±42, z ±27):
#     north  C1 (101) | C2 (102) | generator room (fuse box on the back wall) | C3 (103) | C4 (104)
#     south  toilet block A | C5 (105) | lobby (glass doors at z = 27, locked) | C6 (106) | toilet block B
#   the west and east wings are closed (stairs locked); 3 locker banks: west and east corridor walls, south corridor wall.
# Classrooms: three long desk rows in two blocks around a central aisle, a teacher's desk (under-desk hiding spot) in front
# of the whiteboard, a back cabinet (fuse candidate). Toilets: 4 stalls (hiding spots), a sink counter (battery candidate).
# Lights: emissive only (emergency fixtures, exit sign, fuse slots, the lock panel); the flashlight is the level's only
# light node. Each corridor side and each room is one emissive group (own material) the ScareDirector can flicker.
# Materials: the shared campus set (FPTUCampusBuilder.make_materials: terrazzo, lab floor, wall paint, desk, glass...) plus
# local flat / emissive materials; no image files beyond the existing campus textures.
# build(parent) returns the data the level needs (see the dictionary at the end of build()). Pure static, no autoloads.
class_name NightBuildingMap
extends RefCounted

const H: float = 3.6
const WALL_T: float = 0.2
const CY_X: float = 30.0
const CY_Z: float = 15.0
const COR_X: float = 33.0
const COR_Z: float = 18.0
const OUT_X: float = 42.0
const OUT_Z: float = 27.0
const CL_X: float = 31.5
const CL_Z: float = 16.5
const DOOR_W: float = 1.4
const DOOR_H: float = 2.3
const LOBBY_OPEN: float = 3.0
const GLASS_HALF: float = 2.4
const PORCH_Z: float = 33.0
## Walking out past this z (with the doors open) is the escape.
const EXIT_Z: float = 28.6
const PICK_R: float = 1.6
const FUSE_BOX_R: float = 1.6
const WORLD_LAYER: int = 1
## Rooms: side -1 = north (depth towards -Z), +1 = south; door = x of the corridor door (lobby: open front).
const ROOMS: Array = [
	{"id": "C1", "kind": "classroom", "side": -1, "x0": -42.0, "x1": -24.0, "door": -27.0, "label": "PHÒNG 101"},
	{"id": "C2", "kind": "classroom", "side": -1, "x0": -24.0, "x1": -8.0, "door": -12.0, "label": "PHÒNG 102"},
	{"id": "GEN", "kind": "generator", "side": -1, "x0": -8.0, "x1": 8.0, "door": 0.0, "label": "PHÒNG MÁY PHÁT"},
	{"id": "C3", "kind": "classroom", "side": -1, "x0": 8.0, "x1": 24.0, "door": 12.0, "label": "PHÒNG 103"},
	{"id": "C4", "kind": "classroom", "side": -1, "x0": 24.0, "x1": 42.0, "door": 27.0, "label": "PHÒNG 104"},
	{"id": "WCA", "kind": "toilet", "side": 1, "x0": -42.0, "x1": -24.0, "door": -27.0, "label": "NHÀ VỆ SINH"},
	{"id": "C5", "kind": "classroom", "side": 1, "x0": -24.0, "x1": -8.0, "door": -12.0, "label": "PHÒNG 105"},
	{"id": "LOBBY", "kind": "lobby", "side": 1, "x0": -8.0, "x1": 8.0, "door": 0.0, "label": "SẢNH"},
	{"id": "C6", "kind": "classroom", "side": 1, "x0": 8.0, "x1": 24.0, "door": 12.0, "label": "PHÒNG 106"},
	{"id": "WCB", "kind": "toilet", "side": 1, "x0": 24.0, "x1": 42.0, "door": 27.0, "label": "NHÀ VỆ SINH"},
]
## Stalker patrol loops (graph node names) and where each starts (index 0).
const PATROLS: Array = [
	["C1_back", "W_mid", "C2_back", "GEN_mid"],
	["C4_back", "E_mid", "C3_back", "GEN_box"],
	["WCA_mid", "W_mid", "C5_back", "LOBBY_cor"],
	["WCB_mid", "E_mid", "C6_back", "LOBBY_cor"],
]
const LOCKERS_PER_BANK: int = 8
const LOCKER_W: float = 0.6
const LOCKER_D: float = 0.5
const LOCKER_H: float = 1.9

static var _m: Dictionary = {}
static var _world: StaticBody3D = null
static var _mat_cache: Dictionary = {}


static func _mat(c: Color, rough: float = 0.85, emission: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, emission, metal]
	if emission <= 0.0 and _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	else:
		_mat_cache[key] = m
	return m


## A new emissive material (each light group owns one so the director can flicker it alone).
static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, center: Vector3, r: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi


static func _col(center: Vector3, size: Vector3, body: StaticBody3D = null) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	(body if body != null else _world).add_child(cs)
	return cs


static func _solid(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	_col(center, size)
	return _box(parent, center, size, mat)


static func _label(parent: Node3D, pos: Vector3, text: String, size: int, color: Color, rot_y: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = maxi(4, int(size * 0.2))
	l.modulate = color
	l.position = pos
	l.rotation.y = rot_y
	parent.add_child(l)
	return l


## A point of a room in its own frame: lx along X from the room centre, lz = depth from the corridor wall to the back wall.
static func room_pt(r: Dictionary, lx: float, lz: float, y: float = 0.0) -> Vector3:
	var cx: float = (float(r["x0"]) + float(r["x1"])) * 0.5
	var side: float = float(r["side"])
	return Vector3(cx + lx, y, side * (COR_Z + lz))


static func room_by_id(id: String) -> Dictionary:
	for r: Dictionary in ROOMS:
		if r["id"] == id:
			return r
	return {}


## Yaw whose -Z looks along dir.
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
static func build(parent: Node3D) -> Dictionary:
	_m = FPTUCampusBuilder.make_materials()
	var root := Node3D.new()
	root.name = "Building"
	parent.add_child(root)
	_world = StaticBody3D.new()
	_world.name = "World"
	_world.collision_layer = WORLD_LAYER
	_world.collision_mask = 0
	root.add_child(_world)
	var data: Dictionary = {
		"root": root, "graph": HorrorNavGraph.new(), "spots": [], "fuse_candidates": [], "battery_candidates": [],
		"light_groups": [], "rooms": [], "locker_banks": 0, "patrols": [], "exit_z": EXIT_Z,
		"start": {"pos": Vector3(0.0, 0.0, 23.5), "yaw": 0.0},
	}
	_build_env(root)
	_build_shell(root, data)
	_build_courtyard(root)
	_build_corridor_graph(data)
	for r: Dictionary in ROOMS:
		data["rooms"].append({"id": r["id"], "kind": r["kind"]})
		match String(r["kind"]):
			"classroom":
				_build_classroom(root, r, data)
			"toilet":
				_build_toilet(root, r, data)
			"generator":
				_build_generator(root, r, data)
			"lobby":
				_build_lobby(root, r, data)
	_build_lockers(root, data)
	_build_corridor_lights(root, data)
	var g: HorrorNavGraph = data["graph"]
	for loop: Array in PATROLS:
		var ids := PackedInt32Array()
		for nm: String in loop:
			var id: int = g.id_of(nm)
			if id < 0:
				push_error("NightBuildingMap: unknown patrol node " + nm)
				continue
			ids.append(id)
		data["patrols"].append(ids)
	data["start_node"] = g.id_of("LOBBY_mid")
	return data


static func _build_env(root: Node3D) -> void:
	var we := WorldEnvironment.new()
	we.name = "NightEnv"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.55)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.fog_density = 0.018
	we.environment = env
	root.add_child(we)


# --- walls -----------------------------------------------------------------
## A straight wall along X at z (x0..x1) or along Z at x (z0..z1), with door gaps [[a, b], ...] (lintel above DOOR_H),
## optional accent stripe on one side (+1 / -1 along the wall normal; 0 = none).
static func _wall_x(root: Node3D, z: float, x0: float, x1: float, gaps: Array = [], accent: int = 0, lintel_h: float = DOOR_H) -> void:
	var cuts: Array = _segments(x0, x1, gaps)
	for s: Vector2 in cuts:
		var len_w: float = s.y - s.x
		if len_w < 0.01:
			continue
		var c := Vector3((s.x + s.y) * 0.5, H * 0.5, z)
		_solid(root, c, Vector3(len_w, H, WALL_T), _m["wall_paint"])
		_box(root, Vector3(c.x, 0.06, z), Vector3(len_w, 0.12, WALL_T + 0.03), _mat(Color("#3E444B"), 0.7))
		if accent != 0:
			_box(root, Vector3(c.x, 1.1, z + accent * (WALL_T * 0.5 + 0.006)), Vector3(len_w, 0.09, 0.012), _mat(Color("#F37021"), 0.6))
	for gp: Variant in gaps:
		var g2: Array = gp
		var a: float = float(g2[0])
		var b: float = float(g2[1])
		_solid(root, Vector3((a + b) * 0.5, (lintel_h + H) * 0.5, z), Vector3(b - a, H - lintel_h, WALL_T), _m["wall_paint"])
		for e: float in [a, b]:
			_box(root, Vector3(e, lintel_h * 0.5, z), Vector3(0.08, lintel_h, WALL_T + 0.06), _mat(Color("#2B2F33"), 0.6))


static func _wall_z(root: Node3D, x: float, z0: float, z1: float, gaps: Array = [], accent: int = 0) -> void:
	var cuts: Array = _segments(z0, z1, gaps)
	for s: Vector2 in cuts:
		var len_w: float = s.y - s.x
		if len_w < 0.01:
			continue
		var c := Vector3(x, H * 0.5, (s.x + s.y) * 0.5)
		_solid(root, c, Vector3(WALL_T, H, len_w), _m["wall_paint"])
		_box(root, Vector3(x, 0.06, c.z), Vector3(WALL_T + 0.03, 0.12, len_w), _mat(Color("#3E444B"), 0.7))
		if accent != 0:
			_box(root, Vector3(x + accent * (WALL_T * 0.5 + 0.006), 1.1, c.z), Vector3(0.012, 0.09, len_w), _mat(Color("#F37021"), 0.6))
	for gp: Variant in gaps:
		var g2: Array = gp
		var a: float = float(g2[0])
		var b: float = float(g2[1])
		_solid(root, Vector3(x, (DOOR_H + H) * 0.5, (a + b) * 0.5), Vector3(WALL_T, H - DOOR_H, b - a), _m["wall_paint"])


static func _segments(a: float, b: float, gaps: Array) -> Array:
	var out: Array = []
	var cur: float = a
	var sorted: Array = gaps.duplicate()
	sorted.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	for gp: Variant in sorted:
		var g2: Array = gp
		out.append(Vector2(cur, float(g2[0])))
		cur = float(g2[1])
	out.append(Vector2(cur, b))
	return out


## Courtyard window wall along X (horizontal) or Z: sill, glass, header; collider full height; mullions in one MultiMesh.
static func _window_wall(root: Node3D, along_x: bool, fixed: float, a: float, b: float) -> void:
	var len_w: float = b - a
	var mid: float = (a + b) * 0.5
	var size_of := func(h: float, t: float) -> Vector3: return Vector3(len_w, h, t) if along_x else Vector3(t, h, len_w)
	var at := func(y: float) -> Vector3: return Vector3(mid, y, fixed) if along_x else Vector3(fixed, y, mid)
	_col(at.call(H * 0.5), size_of.call(H, WALL_T))
	_box(root, at.call(0.45), size_of.call(0.9, WALL_T), _m["wall_paint"])
	_box(root, at.call(3.1), size_of.call(1.0, WALL_T), _m["wall_paint"])
	_box(root, at.call(1.75), size_of.call(1.7, 0.04), _m["glass"])
	_box(root, at.call(0.92), size_of.call(0.06, WALL_T + 0.1), _mat(Color("#C9CDD1"), 0.3, 0.0, 0.6))
	var n: int = int(len_w / 2.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 1.7, 0.12) if along_x else Vector3(0.12, 1.7, 0.08)
	mm.mesh = bm
	mm.instance_count = n + 1
	for i: int in n + 1:
		var t: float = a + len_w * float(i) / float(n)
		var p: Vector3 = Vector3(t, 1.75, fixed) if along_x else Vector3(fixed, 1.75, t)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(Color("#C9CDD1"), 0.3, 0.0, 0.6)
	root.add_child(mmi)


static func _build_shell(root: Node3D, data: Dictionary) -> void:
	# floor collider (building + porch) and ceiling collider (keeps the third-person camera under the ceiling)
	_col(Vector3(0.0, -0.5, (PORCH_Z - OUT_Z - 1.0) * 0.5), Vector3(OUT_X * 2.0 + 2.0, 1.0, OUT_Z * 2.0 + 2.0 + (PORCH_Z - OUT_Z)))
	_col(Vector3(0.0, H + 0.2, 0.0), Vector3(OUT_X * 2.0 + 2.0, 0.4, OUT_Z * 2.0 + 2.0))
	# corridor floor and ceiling strips
	var terr: Material = _m["terrazzo"]
	var ceil_m: Material = _m["ceiling"]
	for sz: float in [-1.0, 1.0]:
		_box(root, Vector3(0.0, -0.05, sz * CL_Z), Vector3(COR_X * 2.0, 0.1, COR_Z - CY_Z), terr)
		_box(root, Vector3(0.0, H + 0.06, sz * CL_Z), Vector3(COR_X * 2.0, 0.12, COR_Z - CY_Z + 0.2), ceil_m)
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(sx * CL_X, -0.05, 0.0), Vector3(COR_X - CY_X, 0.1, CY_Z * 2.0), terr)
		_box(root, Vector3(sx * CL_X, H + 0.06, 0.0), Vector3(COR_X - CY_X + 0.2, 0.12, CY_Z * 2.0), ceil_m)
	# outer walls (lobby glass door gap in the south one)
	_wall_x(root, -OUT_Z, -OUT_X, OUT_X)
	_wall_x(root, OUT_Z, -OUT_X, OUT_X, [[-GLASS_HALF, GLASS_HALF]], 0, 2.6)
	_wall_z(root, -OUT_X, -OUT_Z, OUT_Z)
	_wall_z(root, OUT_X, -OUT_Z, OUT_Z)
	# corridor outer walls with the room doors (accent stripe on the corridor side)
	var north_gaps: Array = []
	var south_gaps: Array = []
	for r: Dictionary in ROOMS:
		var dx: float = float(r["door"])
		var gap: Array = [dx - LOBBY_OPEN, dx + LOBBY_OPEN] if r["kind"] == "lobby" else [dx - DOOR_W * 0.5, dx + DOOR_W * 0.5]
		if int(r["side"]) < 0:
			north_gaps.append(gap)
		else:
			south_gaps.append(gap)
	_wall_x(root, -COR_Z, -OUT_X, OUT_X, north_gaps, 1)
	_wall_x(root, COR_Z, -OUT_X, OUT_X, south_gaps, -1)
	_wall_z(root, -COR_X, -COR_Z, COR_Z, [], 1)
	_wall_z(root, COR_X, -COR_Z, COR_Z, [], -1)
	# room partitions
	for x: float in [-24.0, -8.0, 8.0, 24.0]:
		_wall_z(root, x, -OUT_Z, -COR_Z)
		_wall_z(root, x, COR_Z, OUT_Z)
	# courtyard window walls
	_window_wall(root, true, -CY_Z, -CY_X, CY_X)
	_window_wall(root, true, CY_Z, -CY_X, CY_X)
	_window_wall(root, false, -CY_X, -CY_Z, CY_Z)
	_window_wall(root, false, CY_X, -CY_Z, CY_Z)
	# locked stair doors in the closed wings
	for sx: float in [-1.0, 1.0]:
		var wx: float = sx * (COR_X - WALL_T * 0.5 - 0.02)
		_box(root, Vector3(wx, 1.1, -8.0), Vector3(0.06, 2.2, 1.2), _mat(Color("#5B4636"), 0.6))
		_label(root, Vector3(sx * (COR_X - 0.16), 2.45, -8.0), "CẦU THANG\nĐÃ KHÓA", 22, Color("#E8E2D0"), -sx * PI * 0.5)
	# porch outside the lobby
	_box(root, Vector3(0.0, -0.05, (OUT_Z + PORCH_Z) * 0.5), Vector3(16.0, 0.1, PORCH_Z - OUT_Z), _m["concrete"])
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(sx * 6.5, 0.35, 30.5), Vector3(1.6, 0.7, 1.6), _m["planter"])
	_cyl(root, Vector3(4.0, 1.5, 31.5), 0.05, 3.0, _m["steel"])
	_box(root, Vector3(4.0, 3.05, 31.5), Vector3(0.3, 0.15, 0.3), _glow(Color("#FFE2A8"), 1.6))


static func _build_courtyard(root: Node3D) -> void:
	_box(root, Vector3(-CY_X * 0.5, 0.02, 0.0), Vector3(CY_X, 0.04, CY_Z * 2.0), _m["paving"])
	_box(root, Vector3(CY_X * 0.5, 0.02, 0.0), Vector3(CY_X, 0.04, CY_Z * 2.0), _m["grass"])
	_box(root, Vector3(0.0, 0.045, 0.0), Vector3(3.0, 0.03, CY_Z * 2.0), _m["red_path"])
	var toad := Vector3(-12.0, 0.0, 2.0)
	_cyl(root, toad + Vector3(0.0, 0.6, 0.0), 1.5, 1.2, _m["granite"])
	var gold: Material = _m["gold"]
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.6
	body.mesh = sm
	body.material_override = gold
	body.position = toad + Vector3(0.0, 1.9, 0.0)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.62
	hm.height = 1.0
	head.mesh = hm
	head.material_override = gold
	head.position = toad + Vector3(0.0, 2.75, 0.55)
	root.add_child(head)
	for i: int in 4:
		var tp: Array[Vector3] = [Vector3(8.0, 0.0, -7.0), Vector3(19.0, 0.0, 6.0), Vector3(24.0, 0.0, -9.0), Vector3(5.0, 0.0, 9.0)]
		FPTUCampusBuilder.build_tropical_tree(root, tp[i], _m, 0.75, 700 + i)


# --- graph -----------------------------------------------------------------
static func _node(data: Dictionary, nm: String, p: Vector3) -> int:
	var g: HorrorNavGraph = data["graph"]
	return g.add_node(p, nm)


static func _link(data: Dictionary, a: String, b: String) -> void:
	var g: HorrorNavGraph = data["graph"]
	g.connect_nodes(g.id_of(a), g.id_of(b))


## Ring corridor centreline nodes (about every 4.5 m) with a node exactly in front of every door (alias "<room>_cor").
static func _build_corridor_graph(data: Dictionary) -> void:
	var g: HorrorNavGraph = data["graph"]
	var corners: Dictionary = {
		"NW": _node(data, "NW", Vector3(-CL_X, 0.0, -CL_Z)), "NE": _node(data, "NE", Vector3(CL_X, 0.0, -CL_Z)),
		"SW": _node(data, "SW", Vector3(-CL_X, 0.0, CL_Z)), "SE": _node(data, "SE", Vector3(CL_X, 0.0, CL_Z)),
	}
	for side: int in [-1, 1]:
		var xs: Array[float] = []
		var t: float = -CL_X + 4.5
		while t < CL_X - 1.0:
			xs.append(t)
			t += 4.5
		var doors: Dictionary = {}
		for r: Dictionary in ROOMS:
			if int(r["side"]) == side:
				doors[float(r["door"])] = String(r["id"])
		var merged: Array[float] = []
		for x: float in xs:
			var near_door: bool = false
			for dx: float in doors.keys():
				if absf(dx - x) < 1.6:
					near_door = true
			if not near_door:
				merged.append(x)
		for dx: float in doors.keys():
			merged.append(dx)
		merged.sort()
		var prefix: String = "N" if side < 0 else "S"
		var prev: int = int(corners[prefix + "W"])
		for x: float in merged:
			var id: int = g.add_node(Vector3(x, 0.0, side * CL_Z), "%s_%d" % [prefix, int(round(x))])
			if doors.has(x):
				g.names[String(doors[x]) + "_cor"] = id
			g.connect_nodes(prev, id)
			prev = id
		g.connect_nodes(prev, int(corners[prefix + "E"]))
	for sx: int in [-1, 1]:
		var prefix2: String = "W" if sx < 0 else "E"
		var prev2: int = int(corners["N" + prefix2])
		for k: int in range(1, 8):
			var z: float = -CL_Z + CL_Z * 2.0 * float(k) / 8.0
			var nm: String = prefix2 + "_mid" if k == 4 else "%s_%d" % [prefix2, k]
			var id2: int = g.add_node(Vector3(sx * CL_X, 0.0, z), nm)
			g.connect_nodes(prev2, id2)
			prev2 = id2
		g.connect_nodes(prev2, int(corners["S" + prefix2]))


## Room nodes from local points {key: [lx, lz]} and links [[a, b], ...] ("cor" = the corridor door node).
static func _room_nodes(data: Dictionary, r: Dictionary, pts: Dictionary, links: Array) -> void:
	var id: String = r["id"]
	for k: String in pts.keys():
		var p: Array = pts[k]
		_node(data, id + "_" + k, room_pt(r, float(p[0]), float(p[1])))
	for l: Variant in links:
		var la: Array = l
		_link(data, id + "_" + String(la[0]), id + "_" + String(la[1]))


static func _door_label(root: Node3D, r: Dictionary) -> void:
	var side: float = float(r["side"])
	var lx: float = float(r["door"]) - (float(r["x0"]) + float(r["x1"])) * 0.5
	var off: float = 1.3 if r["kind"] != "lobby" else LOBBY_OPEN + 1.0
	var p: Vector3 = room_pt(r, lx + off, -0.12, 2.25)
	_label(root, p, String(r["label"]), 26, Color("#F2EEE2"), 0.0 if side < 0 else PI)


## Floor, ceiling and one emissive fixture (its own light group) of a room.
static func _room_shell(root: Node3D, r: Dictionary, data: Dictionary, floor_mat: Material, fixture_energy: float = 0.9) -> void:
	var w: float = float(r["x1"]) - float(r["x0"])
	var c: Vector3 = room_pt(r, 0.0, 4.5)
	_box(root, Vector3(c.x, -0.05, c.z), Vector3(w, 0.1, OUT_Z - COR_Z), floor_mat)
	_box(root, Vector3(c.x, H + 0.06, c.z), Vector3(w, 0.12, OUT_Z - COR_Z), _m["ceiling"])
	var gm: StandardMaterial3D = _glow(Color("#CFF7DD"), fixture_energy)
	var fp: Vector3 = room_pt(r, 0.0, 1.2, H - 0.05)
	_box(root, fp, Vector3(0.7, 0.07, 0.22), gm)
	data["light_groups"].append({"pos": room_pt(r, 0.0, 4.5), "mat": gm, "energy": fixture_energy})
	_door_label(root, r)


## An open door leaf inside the room, folded against the corridor wall next to the doorway.
static func _door_leaf(root: Node3D, r: Dictionary) -> void:
	var lx: float = float(r["door"]) - (float(r["x0"]) + float(r["x1"])) * 0.5
	var away: float = 1.0 if lx >= 0.0 else -1.0   # on the side away from the room centre (never across the way in)
	_box(root, room_pt(r, lx + away * (DOOR_W * 0.5 + 0.05), 0.5, 1.05), Vector3(0.05, 2.1, 0.92), _m["wood"])


static func _build_classroom(root: Node3D, r: Dictionary, data: Dictionary) -> void:
	_room_shell(root, r, data, _m["lab_floor"])
	_door_leaf(root, r)
	var side: float = float(r["side"])
	var desk_top: Material = _m["desk_top"]
	var leg: Material = _m["desk_leg"]
	var bench: Material = _m["chair_blue"]
	for row_z: float in [2.2, 3.6, 5.0]:
		for sx: float in [-1.0, 1.0]:
			var cx: float = sx * 4.0
			_box(root, room_pt(r, cx, row_z, 0.74), Vector3(5.6, 0.04, 0.6), desk_top)
			_box(root, room_pt(r, cx, row_z + 0.27, 0.45), Vector3(5.4, 0.5, 0.03), leg)
			for ex: float in [-2.75, 2.75]:
				_box(root, room_pt(r, cx + ex, row_z, 0.37), Vector3(0.05, 0.72, 0.56), leg)
			_box(root, room_pt(r, cx, row_z - 0.55, 0.43), Vector3(5.4, 0.05, 0.34), bench)
			_col(room_pt(r, cx, row_z - 0.18, 0.38), Vector3(5.6, 0.76, 1.0))
	# teacher's desk (under-desk hiding spot): kneehole towards the back wall, modesty panel towards the students
	var dz: float = 7.3
	_box(root, room_pt(r, 0.0, dz, 0.74), Vector3(1.8, 0.05, 0.8), _m["wood"])
	_box(root, room_pt(r, 0.0, dz - 0.37, 0.52), Vector3(1.8, 0.44, 0.04), _m["wood"])
	for ex: float in [-0.88, 0.88]:
		_box(root, room_pt(r, ex, dz, 0.37), Vector3(0.04, 0.74, 0.8), _m["wood"])
	_col(room_pt(r, 0.0, dz, 0.38), Vector3(1.8, 0.76, 0.8))
	var out := Vector3(0.0, 0.0, side)
	var spot: HidingSpot = HidingSpot.make("desk", Transform3D(Basis(Vector3.UP, yaw_to(out)), room_pt(r, 0.0, dz)))
	spot.name = "Hide_desk_" + String(r["id"])
	root.add_child(spot)
	data["spots"].append(spot)
	# whiteboard on the back wall
	_box(root, room_pt(r, 0.0, 8.86, 1.65), Vector3(3.8, 1.25, 0.04), _mat(Color("#C9CDD1"), 0.3, 0.0, 0.6))
	_box(root, room_pt(r, 0.0, 8.84, 1.65), Vector3(3.6, 1.1, 0.04), _m["whiteboard"])
	_label(root, room_pt(r, 0.0, 8.8, 1.9), "KIỂM TRA CUỐI KỲ\nKHÔNG SỬ DỤNG TÀI LIỆU", 18, Color("#1F3F7A"), 0.0 if side < 0 else PI)
	# a faint moonlit window panel high on the back wall
	_box(root, room_pt(r, 5.0, 8.86, 2.6), Vector3(2.6, 0.9, 0.03), _glow(Color("#3A4E78"), 0.35))
	# back cabinet with the fuse candidate on top (left in odd rooms, right in even ones)
	var idx: int = int(String(r["id"]).substr(1))
	var fx: float = -6.3 if idx % 2 == 1 else 6.3
	_solid(root, room_pt(r, fx, 8.5, 0.4), Vector3(1.1, 0.8, 0.6), _m["desk_leg"])
	_room_nodes(data, r, {
		"door_in": [float(r["door"]) - (float(r["x0"]) + float(r["x1"])) * 0.5, 0.8], "front": [0.0, 0.8], "mid": [0.0, 3.6],
		"back": [0.0, 6.1], "back_l": [-5.0, 6.1], "back_r": [5.0, 6.1], "fuse": [fx, 7.6], "behind": [-1.6, 8.25],
		"desk": [0.0, 8.25]}, [["door_in", "front"], ["front", "mid"], ["mid", "back"], ["back", "back_l"], ["back", "back_r"],
		["back_l" if fx < 0.0 else "back_r", "fuse"], ["back_l", "behind"], ["behind", "desk"]])
	_link(data, String(r["id"]) + "_cor", String(r["id"]) + "_door_in")
	var g: HorrorNavGraph = data["graph"]
	# the desk node is the desk's way out (and the desk peek camera looks the other way): never a search stop
	g.set_no_wander(g.id_of(String(r["id"]) + "_desk"))
	g.set_no_wander(g.id_of(String(r["id"]) + "_behind"))
	data["fuse_candidates"].append({"room": r["id"], "pos": room_pt(r, fx, 8.5, 0.86), "reach": room_pt(r, fx, 7.6),
		"node": g.id_of(String(r["id"]) + "_fuse")})
	if r["id"] == "C3" or r["id"] == "C6":
		var bx: float = -7.0 if fx > 0.0 else 7.0
		data["battery_candidates"].append({"room": r["id"], "pos": room_pt(r, bx, 0.6, 0.05), "reach": room_pt(r, bx * 0.8, 0.8),
			"node": g.id_of(String(r["id"]) + "_front")})


static func _build_toilet(root: Node3D, r: Dictionary, data: Dictionary) -> void:
	_room_shell(root, r, data, _m["terrazzo"], 0.7)
	_door_leaf(root, r)
	var side: float = float(r["side"])
	var door_lx: float = float(r["door"]) - (float(r["x0"]) + float(r["x1"])) * 0.5
	var sgn: float = -signf(door_lx)          # stalls on the side away from the door
	var tile: Material = _mat(Color("#BFD3D6"), 0.4)
	var part: Material = _mat(Color("#6F8F94"), 0.5)
	var door_m: Material = _mat(Color("#567378"), 0.5)
	# tiled back wall band
	_box(root, room_pt(r, 0.0, 8.88, 1.0), Vector3(float(r["x1"]) - float(r["x0"]) - 0.2, 2.0, 0.02), tile)
	var x_lo: float = 0.0
	var x_hi: float = 0.0
	var g: HorrorNavGraph = data["graph"]
	var prev_front: String = ""
	for i: int in 4:
		var lx: float = sgn * (8.8 - 0.7 - 1.4 * float(i))
		if i == 0:
			x_hi = lx + sgn * 0.7
		x_lo = lx - sgn * 0.7
		# partition on the inner side of each stall
		_box(root, room_pt(r, lx - sgn * 0.7, 8.05, 1.15), Vector3(0.05, 2.0, 1.7), part)
		# front: two side pieces and the door (hinged on one side)
		for e: float in [-0.525, 0.525]:
			_box(root, room_pt(r, lx + e, 7.2, 1.15), Vector3(0.35, 2.0, 0.05), part)
		var hinge := Node3D.new()
		hinge.name = "StallDoor%d" % i
		hinge.position = room_pt(r, lx - 0.35, 7.2, 0.0)
		root.add_child(hinge)
		_box(hinge, Vector3(0.35, 1.125, 0.0), Vector3(0.7, 1.55, 0.04), door_m)
		# toilet bowl
		_box(root, room_pt(r, lx, 8.5, 0.22), Vector3(0.4, 0.44, 0.55), _mat(Color("#F4F5F6"), 0.25))
		var out := Vector3(0.0, 0.0, -side)
		var spot: HidingSpot = HidingSpot.make("stall", Transform3D(Basis(Vector3.UP, yaw_to(out)), room_pt(r, lx, 8.05)), hinge)
		spot.name = "Hide_stall_%s_%d" % [r["id"], i]
		root.add_child(spot)
		data["spots"].append(spot)
		var nm: String = "stall%d" % i
		var sid: int = _node(data, String(r["id"]) + "_" + nm, room_pt(r, lx, 6.75))
		g.set_no_wander(sid)   # on the stall's way out: routes pass, searches never stand here
		if prev_front != "":
			_link(data, String(r["id"]) + "_" + prev_front, String(r["id"]) + "_" + nm)
		prev_front = nm
	# one collider for the stall block
	var c0: float = minf(x_lo, x_hi)
	var c1: float = maxf(x_lo, x_hi)
	_col(room_pt(r, (c0 + c1) * 0.5, 8.05, 1.15), Vector3(c1 - c0, 2.3, 1.7))
	# sink counter and mirror on the door side
	var sx: float = -sgn * 3.2
	_solid(root, room_pt(r, sx, 8.55, 0.42), Vector3(3.6, 0.85, 0.6), _mat(Color("#D9DDE0"), 0.35))
	_box(root, room_pt(r, sx, 8.87, 1.6), Vector3(3.2, 0.9, 0.02), _mat(Color("#7E8C99"), 0.08, 0.0, 0.8))
	_room_nodes(data, r, {"door_in": [door_lx, 0.8], "mid": [0.0, 3.5], "sink": [sx, 7.4]},
		[["door_in", "mid"], ["mid", "sink"], ["mid", "stall3"]])
	_link(data, String(r["id"]) + "_cor", String(r["id"]) + "_door_in")
	data["battery_candidates"].append({"room": r["id"], "pos": room_pt(r, sx - sgn * 1.2, 8.45, 0.9), "reach": room_pt(r, sx - sgn * 1.2, 7.4),
		"node": g.id_of(String(r["id"]) + "_sink")})


static func _build_generator(root: Node3D, r: Dictionary, data: Dictionary) -> void:
	_room_shell(root, r, data, _m["concrete"], 0.6)
	_door_leaf(root, r)
	var steel: Material = _m["steel"]
	var dark: Material = _m["dark"]
	_solid(root, room_pt(r, -4.5, 5.0, 1.0), Vector3(4.0, 2.0, 3.0), _mat(Color("#3D5A3F"), 0.55, 0.0, 0.3))
	_box(root, room_pt(r, -4.5, 5.0, 2.05), Vector3(3.6, 0.1, 2.6), dark)
	_cyl(root, room_pt(r, -5.8, 5.6, 2.9), 0.16, 1.7, steel)
	_box(root, room_pt(r, -2.45, 4.2, 1.3), Vector3(0.05, 0.5, 0.8), dark)
	for k: int in 3:
		_box(root, room_pt(r, -2.42, 4.0 + 0.2 * k, 1.42), Vector3(0.02, 0.05, 0.05), _glow(Color("#FF3B30"), 1.4))
	_label(root, room_pt(r, -4.5, 3.48, 1.4), "MÁY PHÁT ĐIỆN DỰ PHÒNG", 20, Color("#E8E2D0"), 0.0)
	for k: int in 3:
		_cyl(root, room_pt(r, 4.8 + 0.7 * float(k % 2), 2.6 + 0.75 * float(k), 0.5), 0.3, 1.0, _mat(Color("#2F5DA8"), 0.6))
	_col(room_pt(r, 5.15, 3.35, 0.5), Vector3(1.4, 1.0, 2.2))
	# fuse box on the back wall: 3 slots, red until a fuse goes in
	var box_p: Vector3 = room_pt(r, 3.0, 8.75, 1.45)
	_box(root, box_p, Vector3(0.9, 1.1, 0.25), _mat(Color("#8A9097"), 0.4, 0.0, 0.5))
	_label(root, room_pt(r, 3.0, 8.6, 2.2), "HỘP CẦU CHÌ", 20, Color("#FFD34D"), 0.0 if float(r["side"]) < 0 else PI)
	var slots: Array = []
	for k: int in 3:
		var sm: StandardMaterial3D = _glow(Color("#FF3B30"), 1.6)
		_box(root, room_pt(r, 2.72 + 0.28 * float(k), 8.6, 1.45), Vector3(0.16, 0.42, 0.06), sm)
		slots.append(sm)
	_room_nodes(data, r, {"door_in": [0.0, 0.8], "mid": [0.0, 3.5], "box": [3.0, 7.6]}, [["door_in", "mid"], ["mid", "box"]])
	_link(data, "GEN_cor", "GEN_door_in")
	data["fuse_box"] = {"pos": room_pt(r, 3.0, 7.75), "yaw": yaw_to(Vector3(0.0, 0.0, -float(r["side"]))), "slots": slots}
	var g: HorrorNavGraph = data["graph"]
	data["battery_candidates"].append({"room": "GEN", "pos": room_pt(r, 5.15, 2.6, 1.05), "reach": room_pt(r, 3.8, 2.8),
		"node": g.id_of("GEN_mid")})


static func _build_lobby(root: Node3D, r: Dictionary, data: Dictionary) -> void:
	_room_shell(root, r, data, _m["terrazzo_lobby"], 0.6)
	_solid(root, room_pt(r, -5.0, 4.5, 0.55), Vector3(3.0, 1.1, 0.8), _mat(Color("#7A5235"), 0.55))
	_label(root, room_pt(r, -5.0, 4.08, 0.8), "LỄ TÂN", 20, Color("#E8E2D0"), PI)
	_solid(root, room_pt(r, 5.0, 5.0, 0.23), Vector3(2.4, 0.45, 0.5), _m["granite"])
	# glass doors (collider until unlocked), frame, exit sign, lock panel
	var body := StaticBody3D.new()
	body.name = "LobbyDoors"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	root.add_child(body)
	var shape: CollisionShape3D = _col(Vector3(0.0, 1.3, OUT_Z), Vector3(GLASS_HALF * 2.0, 2.6, 0.3), body)
	var panels: Array = []
	for sx: float in [-1.0, 1.0]:
		var pn := Node3D.new()
		pn.name = "GlassDoor" + ("L" if sx < 0 else "R")
		pn.position = Vector3(sx * GLASS_HALF * 0.5, 0.0, OUT_Z)
		root.add_child(pn)
		_box(pn, Vector3(0.0, 1.3, 0.0), Vector3(GLASS_HALF - 0.05, 2.5, 0.05), _m["glass_clear"])
		_box(pn, Vector3(-sx * (GLASS_HALF * 0.5 - 0.1), 1.1, -0.06), Vector3(0.04, 0.5, 0.04), _m["steel"])
		panels.append(pn)
	_box(root, Vector3(0.0, 2.65, OUT_Z), Vector3(GLASS_HALF * 2.0 + 0.2, 0.1, 0.3), _mat(Color("#2B2F33"), 0.6))
	var exit_m: StandardMaterial3D = _glow(Color("#2ECC71"), 2.2)
	_box(root, Vector3(0.0, 3.0, OUT_Z - 0.2), Vector3(1.4, 0.32, 0.06), exit_m)
	_label(root, Vector3(0.0, 3.0, OUT_Z - 0.25), "LỐI THOÁT", 26, Color("#E9FFF0"), PI)
	data["light_groups"].append({"pos": Vector3(0.0, 0.0, OUT_Z - 1.0), "mat": exit_m, "energy": 2.2})
	var lock_m: StandardMaterial3D = _glow(Color("#FF3B30"), 1.8)
	_box(root, Vector3(GLASS_HALF + 0.6, 1.4, OUT_Z - 0.13), Vector3(0.3, 0.4, 0.05), lock_m)
	var lock_l: Label3D = _label(root, Vector3(GLASS_HALF + 0.6, 1.8, OUT_Z - 0.16), "KHÓA", 22, Color("#FF6B5E"), PI)
	_room_nodes(data, r, {"in": [0.0, 1.5], "mid": [0.0, 5.0], "door": [0.0, 8.0]}, [["in", "mid"], ["mid", "door"]])
	_link(data, "LOBBY_cor", "LOBBY_in")
	data["doors"] = {"body": body, "shape": shape, "panels": panels, "lock_mat": lock_m, "lock_label": lock_l}
	var g: HorrorNavGraph = data["graph"]
	data["battery_candidates"].append({"room": "LOBBY", "pos": room_pt(r, -5.6, 4.5, 1.15), "reach": room_pt(r, -5.6, 3.4),
		"node": g.id_of("LOBBY_mid")})


## 3 locker banks of LOCKERS_PER_BANK hideable lockers: west / east corridor walls, south corridor wall west of C5.
static func _build_lockers(root: Node3D, data: Dictionary) -> void:
	var banks: Array = [
		{"origin": Vector3(-COR_X + WALL_T * 0.5 + LOCKER_D * 0.5, 0.0, 0.0), "along": Vector3(0, 0, 1), "out": Vector3(1, 0, 0)},
		{"origin": Vector3(COR_X - WALL_T * 0.5 - LOCKER_D * 0.5, 0.0, 0.0), "along": Vector3(0, 0, 1), "out": Vector3(-1, 0, 0)},
		{"origin": Vector3(-20.6, 0.0, COR_Z - WALL_T * 0.5 - LOCKER_D * 0.5), "along": Vector3(1, 0, 0), "out": Vector3(0, 0, -1)},
	]
	var body_m: Material = _mat(Color("#5C6F82"), 0.45, 0.0, 0.5)
	var door_m: Material = _mat(Color("#6E8499"), 0.4, 0.0, 0.5)
	var vent_m: Material = _mat(Color("#1C232B"), 0.6)
	var half: float = LOCKER_W * LOCKERS_PER_BANK * 0.5
	for b: Dictionary in banks:
		var o: Vector3 = b["origin"]
		var along: Vector3 = b["along"]
		var out: Vector3 = b["out"]
		var span: Vector3 = along * (LOCKER_W * LOCKERS_PER_BANK) + out * LOCKER_D
		var size := Vector3(absf(span.x), LOCKER_H, absf(span.z))
		_solid(root, o + Vector3(0.0, LOCKER_H * 0.5, 0.0), size, body_m)
		var yaw: float = yaw_to(out)
		var lx_sign: float = 1.0 if (Basis(Vector3.UP, yaw) * Vector3.RIGHT).dot(along) > 0.0 else -1.0
		for i: int in LOCKERS_PER_BANK:
			var c: Vector3 = o + along * (-half + LOCKER_W * (float(i) + 0.5))
			var hinge := Node3D.new()
			hinge.name = "LockerDoor%d" % i
			hinge.position = c + out * (LOCKER_D * 0.5 + 0.02) - along * (LOCKER_W * 0.5 - 0.03)
			hinge.rotation.y = yaw
			root.add_child(hinge)
			# in the hinge frame: -Z = out; the leaf runs along +along from the hinge
			_box(hinge, Vector3(0.27 * lx_sign, 0.95, 0.0), Vector3(0.54, 1.8, 0.03), door_m)
			for k: int in 3:
				_box(hinge, Vector3(0.27 * lx_sign, 1.55 + 0.07 * float(k), -0.017), Vector3(0.34, 0.025, 0.006), vent_m)
			var spot: HidingSpot = HidingSpot.make("locker", Transform3D(Basis(Vector3.UP, yaw), c), hinge)
			spot.name = "Hide_locker_%d_%d" % [int(data["locker_banks"]), i]
			root.add_child(spot)
			data["spots"].append(spot)
		data["locker_banks"] = int(data["locker_banks"]) + 1


## Emissive emergency fixtures on the corridor ceiling, one light group per side.
static func _build_corridor_lights(root: Node3D, data: Dictionary) -> void:
	var col := Color("#D8FFE6")
	for sz: float in [-1.0, 1.0]:
		var gm: StandardMaterial3D = _glow(col, 1.1)
		var x: float = -27.0
		while x <= 27.5:
			_box(root, Vector3(x, H - 0.04, sz * CL_Z), Vector3(0.6, 0.07, 0.2), gm)
			x += 9.0
		data["light_groups"].append({"pos": Vector3(0.0, 0.0, sz * CL_Z), "mat": gm, "energy": 1.1})
	for sx: float in [-1.0, 1.0]:
		var gm2: StandardMaterial3D = _glow(col, 1.1)
		for z: float in [-9.0, 0.0, 9.0]:
			_box(root, Vector3(sx * CL_X, H - 0.04, z), Vector3(0.2, 0.07, 0.6), gm2)
		data["light_groups"].append({"pos": Vector3(sx * CL_X, 0.0, 0.0), "mat": gm2, "energy": 1.1})
	# exit sign at the lobby opening, seen from the corridor
	var em: StandardMaterial3D = _glow(Color("#2ECC71"), 2.0)
	_box(root, Vector3(0.0, 3.0, COR_Z - 0.2), Vector3(1.4, 0.32, 0.06), em)
	_label(root, Vector3(0.0, 3.0, COR_Z - 0.25), "LỐI THOÁT", 26, Color("#E9FFF0"), PI)
	_label(root, Vector3(0.0, 3.0, COR_Z - 0.15), "LỐI THOÁT", 26, Color("#E9FFF0"), 0.0)
	data["light_groups"].append({"pos": Vector3(0.0, 0.0, COR_Z), "mat": em, "energy": 2.0})
