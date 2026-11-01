# File: res://scripts/story/lairs/LairCanal.gd
# The Day 6 level (plan 2026-11-01-w4-day6.md), code-built at the origin of the StoryCanal scene (world = local):
#   the shop      Trà Sữa Lọ's front room (CinePropsD6 "tea_shop"; the counter along X at z = 0.6, customers come in from
#                 the street on -Z, the player stands behind the counter), the street in front with a parked shipper bike;
#   the back room behind the shop's back door (room_xf: the CinePropsD6 backroom frame turned 180 degrees, so its shop door
#                 opens at (3, 0, 4)): the doll shelves, the music box, the vanity, the safe with the ledger (backroom_layout,
#                 the same as the cinematics), colliders for the walls and the furniture (the guard's sight lines);
#   the pier      behind the back room's pier door (-0.3, 0, 11), the player's speedboat moored at its end;
#   the course    the canal: a BikeRoute of COURSE_LEN m with gentle bends (half width HALF_W, the water at WATER_Y, the
#                 banks at y = 0): the water strip with the code water shader, the bank walls and tops, MultiMesh houses with
#                 lit windows and lantern strings, three low bridges (BRIDGES), the net poles (NETS), the moored sampan ramp
#                 and the broken pier wall (RAMP_S; the gap by the left bank), the fireworks barge (BARGE_S), the finish bank
#                 with the LỌ ACADEMY billboard (dark).
# A small pool of POOL_LIGHTS OmniLights follows `focus` (the boat / the player) along the lantern strings, re-placed at
# 4 Hz (no per-lamp lights). API: build(), world(local), route, mission_points(task), room_xf(), bank_xf(), tick(dt),
# hide_for_cine(on), back_door_open(on), turn_dolls(target, w), dolls_state(), safe_open(w), music_box_spin(angle),
# bridge_at(s) (-1 = none), course_events() (the set pieces by route distance for the chase and the guidance).
class_name LairCanal
extends Node3D

const WATER_Y: float = -1.0
const HALF_W: float = 11.0
const COURSE_LEN: float = 2100.0
const COURSE_Z0: float = 24.0
const SAMPLE_M: float = 10.0
const STRIP_M: float = 4.0
const CHUNK_M: float = 200.0
const ROOM_POS := Vector3(0.0, 0.0, 7.5)
const SHOP_STAND := Vector3(0.0, 0.0, 1.45)
const PIER_Z0: float = 11.0
const PIER_Z1: float = 21.0
## Low bridges by route distance; the deck's underside sits BRIDGE_CLEAR above the water line (a seated driver's head is
## ~1.9 m up: duck under it).
const BRIDGES: Array[float] = [330.0, 760.0, 1480.0]
const BRIDGE_CLEAR: float = 1.75
## Fishing nets: [s, side] (side -1 = the left half, +1 = the right half).
const NETS: Array = [[620.0, -1.0], [668.0, 1.0]]
const RAMP_S: float = 905.0
const RAMP_LEN: float = 6.0
const RAMP_D: float = 4.5
const GAP_D0: float = -HALF_W
const GAP_D1: float = -7.6
const PIER_TOP: float = 1.6
const BARGE_S: float = 1230.0
const BARGE_D: float = 7.5
const BANK_S: float = 1985.0
const BILLBOARD_S: float = 2010.0
const POOL_LIGHTS: int = 4
const LANTERN_M: float = 7.0
const WINDOW_SHADER := """
shader_type spatial;
render_mode unshaded;
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 2.2;
}
"""

var route: BikeRoute
var shop: Node3D
var room: Node3D
var room_items: Node3D
var shelves: Array[CineAnimD6] = []
var music_box: CineAnimD6
var safe: CineAnimD6
var vanity: Node3D
var ledger: Node3D
var back_door: MeshInstance3D
var back_door_leaf: MeshInstance3D
var back_door_body: StaticBody3D
var nets: Array[CineAnimD6] = []
var fireworks: CineAnimD6
var billboard: CineAnimD6
var ramp_node: Node3D
var pier_wall_node: Node3D
var bridge_nodes: Array[Node3D] = []
var moored_boat: Node3D
var lanterns: PackedVector3Array = []
var lights: Array[OmniLight3D] = []
var focus: Vector3 = Vector3(0.0, 0.0, 15.0)
var built: bool = false
var _light_t: float = 0.0
var _hidden: Array[Node3D] = []


func build() -> void:
	if built:
		return
	built = true
	route = BikeRoute.from_points(course_points(), HALF_W)
	_build_ground()
	_build_shop()
	_build_room()
	_build_pier()
	_build_course()
	_build_light_pool()


## World point of a level-local point (the level is built at the scene origin).
func world(local: Vector3) -> Vector3:
	return global_transform * local


## The canal centreline as Vector2(x, z) every SAMPLE_M m: straight off the pier, then gentle S-bends.
static func course_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	var t: float = 0.0
	while t <= COURSE_LEN + 0.01:
		var ramp: float = clampf(t / 140.0, 0.0, 1.0)
		ramp = ramp * ramp * (3.0 - 2.0 * ramp)
		out.append(Vector2(ramp * (28.0 * sin(t / 150.0) + 10.0 * sin(t / 60.0 + 1.0) - 10.0 * sin(1.0)), COURSE_Z0 + t))
		t += SAMPLE_M
	return out


# ---------------------------------------------------------------------------
# Frames
# ---------------------------------------------------------------------------
## The back room's stage frame (the cinematics' room frame: +Z toward the shop door).
func room_xf() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, PI), ROOM_POS)


## The finish bank's stage frame (the choice on the bank): origin on the right bank's edge at BANK_S, -Z toward the water.
func bank_xf() -> Transform3D:
	var p: Vector2 = route.world(BANK_S, HALF_W)
	var r: Vector2 = route.right(BANK_S)
	return global_transform * Transform3D(Basis(Vector3.UP, atan2(r.x, r.y)), Vector3(p.x, 0.0, p.y))


## Route heading at s as a yaw (characters / props face -Z at 0), smoothed across the 8 m segments.
func yaw_at(s: float) -> float:
	var t: Vector2 = route.tangent(s - 4.0) + route.tangent(s + 4.0)
	return atan2(-t.x, -t.y)


## A world point on the course: route distance s, lateral d (right +), height above the water line.
func course_pos(s: float, d: float, up: float = 0.0) -> Vector3:
	var p: Vector2 = route.world(s, d)
	return Vector3(p.x, WATER_Y + up, p.y)


func mission_points(task: String) -> Dictionary:
	match task:
		"shop":
			# over the player's head (below the 3.25 m ceiling): the cups, the queue and the player's back in one frame
			var cam := Transform3D(Basis.looking_at(Vector3(0.0, -2.05, -2.4).normalized(), Vector3.UP), world(Vector3(0.0, 3.05, 2.4)))
			return {"stand": world(SHOP_STAND), "yaw": 0.0, "door": world(Vector3(0.0, 0.0, -6.0)),
				"counter": world(Vector3(0.0, 0.0, -0.25)), "queue_dir": Vector3(0.0, 0.0, -1.0), "cam": cam,
				"cups": [world(CinePropsD6.shop_cup_pos(0)), world(CinePropsD6.shop_cup_pos(1)), world(CinePropsD6.shop_cup_pos(2)),
					world(CinePropsD6.shop_cup_pos(3))], "back_door": world(Vector3(CinePropsD6.SHOP_BACK_DOOR_X, 0.0, 3.6))}
		"backroom":
			var rx: Transform3D = room_xf()
			return {"start": rx * Vector3(CinePropsD6.ROOM_DOOR_X, 0.0, 2.6), "yaw": PI, "safe": rx * Vector3(2.9, 0.0, -2.2),
				"ledger": rx * Vector3(2.9, 0.55, -3.0), "music_box": rx * Vector3(0.0, 0.85, 0.4), "vanity": rx * Vector3(-2.4, 0.0, -2.3),
				"exit": rx * Vector3(CinePropsD6.PIER_DOOR_X, 0.0, -3.2),
				"patrol": [rx * Vector3(-2.6, 0.0, -1.8), rx * Vector3(1.6, 0.0, -1.8), rx * Vector3(1.6, 0.0, 1.9), rx * Vector3(-1.4, 0.0, 1.9)],
				"guard_start": rx * Vector3(-2.6, 0.0, -1.8), "room_xf": rx}
		"boat":
			return {"route": route, "start_s": 6.0, "rival_s": 34.0, "pier": world(Vector3(0.0, 0.0, PIER_Z1 - 1.0))}
	return {}


## The set pieces of the course by route distance (the chase spawns its events from it; tests read it).
func course_events() -> Array:
	var out: Array = []
	for s: float in BRIDGES:
		out.append({"kind": "bridge", "s": s})
	for n: Array in NETS:
		out.append({"kind": "net", "s": float(n[0]), "side": float(n[1])})
	out.append({"kind": "ramp", "s": RAMP_S})
	out.append({"kind": "barge", "s": BARGE_S})
	return out


## The low bridge whose deck covers s (within 2.2 m of its centre line), else -1.
func bridge_at(s: float) -> int:
	for i: int in BRIDGES.size():
		if absf(s - BRIDGES[i]) <= 2.2:
			return i
	return -1


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
func _build_ground() -> void:
	_solid(Vector3(44.0, 1.0, 26.0), Vector3(0.0, -0.5, -0.5))   # the street, the shop and the back room
	var g: MeshInstance3D = CineFX._box(self, "Street", Vector3(44.0, 1.0, 26.0), Vector3(0.0, -0.51, -0.5), CineFX._mat(Color("#2C2B2E"), 0.95))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	CineFX._box(self, "Pavement", Vector3(16.0, 0.08, 3.0), Vector3(0.0, 0.0, -5.6), CineFX._mat(Color("#6E6A66"), 0.9))
	# the shipper bike parked in front, the pink delivery box on its back
	var bike: Node3D = CineFX.build_prop("scooter", {})
	bike.position = Vector3(-3.0, 0.0, -6.4)
	bike.rotation.y = PI * 0.5
	add_child(bike)
	CineFX._box(self, "DeliveryBox", Vector3(0.5, 0.45, 0.5), Vector3(-2.6, 1.05, -6.4), CineFX._mat(CinePropsD6.PINK, 0.4))


func _build_shop() -> void:
	shop = CineFX.build_prop("tea_shop", {"name": "Shop"})
	add_child(shop)
	var hw: float = CinePropsD6.SHOP_W * 0.5
	var hd: float = CinePropsD6.SHOP_D * 0.5
	for sx: float in [-1.0, 1.0]:
		_solid(Vector3(0.2, 3.2, CinePropsD6.SHOP_D), Vector3(sx * hw, 1.6, 0.0))
		_solid(Vector3(hw - 0.8, 3.2, 0.2), Vector3(sx * (hw * 0.5 + 0.4), 1.6, -hd))
	_solid(Vector3(4.6, 1.0, 0.7), Vector3(0.0, 0.5, CinePropsD6.COUNTER_Z))
	_solid(Vector3(6.0, 1.0, 0.6), Vector3(-1.0, 0.5, hd - 0.4))
	var dl: float = CinePropsD6.SHOP_BACK_DOOR_X - 0.6 + hw
	_solid(Vector3(dl, 3.2, 0.2), Vector3(-hw + dl * 0.5, 1.6, hd))
	var dr: float = hw - CinePropsD6.SHOP_BACK_DOOR_X - 0.6
	_solid(Vector3(dr, 3.2, 0.2), Vector3(hw - dr * 0.5, 1.6, hd))
	back_door = shop.get_node_or_null("BackDoor") as MeshInstance3D
	back_door_leaf = CineFX._box(self, "BackDoorOpen", Vector3(0.05, 2.1, 1.1), Vector3(CinePropsD6.SHOP_BACK_DOOR_X - 0.55, 1.05, hd + 0.55), CineFX._mat(Color("#5A3A28"), 0.7))
	back_door_leaf.visible = false
	back_door_body = _solid(Vector3(1.2, 2.2, 0.2), Vector3(CinePropsD6.SHOP_BACK_DOOR_X, 1.1, hd))


func _build_room() -> void:
	var rx: Transform3D = Transform3D(Basis(Vector3.UP, PI), ROOM_POS)
	room = CineFX.build_prop("backroom", {"name": "BackRoom"})
	room.transform = rx
	add_child(room)
	room_items = Node3D.new()
	room_items.name = "RoomItems"
	room_items.transform = rx
	add_child(room_items)
	for it: Array in CinePropsD6.backroom_layout():
		var n: Node3D = CineFX.build_prop(String(it[0]), it[3])
		n.position = it[1]
		n.rotation.y = deg_to_rad(float(it[2]))
		room_items.add_child(n)
		var an: Variant = n.get_meta("anim_node") if n.has_meta("anim_node") else null
		match String(it[0]):
			"doll_shelf":
				shelves.append(an)
				_solid_local(rx, Vector3(0.5, 2.1, 1.95), it[1])
			"music_box":
				music_box = an
				_solid_local(rx, Vector3(0.8, 0.8, 0.6), Vector3(0.0, 0.4, 0.4))
			"safe":
				safe = an
				_solid_local(rx, Vector3(0.7, 0.9, 0.6), it[1] + Vector3(0.0, 0.45, 0.0))
			"vanity":
				vanity = n
				_solid_local(rx, Vector3(1.1, 1.9, 0.5), it[1] + Vector3(0.0, 0.95, 0.0))
	ledger = CineFX.build_prop("ledger", {"name": "Ledger"})
	ledger.position = Vector3(2.9, 0.55, -3.0)
	ledger.rotation.y = PI
	room_items.add_child(ledger)
	var hw: float = CinePropsD6.ROOM_W * 0.5
	var hd: float = CinePropsD6.ROOM_D * 0.5
	for sx: float in [-1.0, 1.0]:
		_solid_local(rx, Vector3(0.2, 3.0, CinePropsD6.ROOM_D), Vector3(sx * hw, 1.5, 0.0))
	for pair: Array in [[hd, CinePropsD6.ROOM_DOOR_X], [-hd, CinePropsD6.PIER_DOOR_X]]:
		var z: float = float(pair[0])
		var dx: float = float(pair[1])
		var l0: float = dx - 0.6 + hw
		var l1: float = hw - dx - 0.6
		_solid_local(rx, Vector3(l0, 3.0, 0.2), Vector3(-hw + l0 * 0.5, 1.5, z))
		_solid_local(rx, Vector3(l1, 3.0, 0.2), Vector3(hw - l1 * 0.5, 1.5, z))
	_solid_local(rx, Vector3(CinePropsD6.ROOM_W, 0.2, CinePropsD6.ROOM_D), Vector3(0.0, 3.1, 0.0))


func _build_pier() -> void:
	var wood: StandardMaterial3D = CineFX._mat(Color("#6B4E36"), 0.85)
	CineFX._box(self, "Pier", Vector3(5.0, 0.25, PIER_Z1 - PIER_Z0), Vector3(-0.3, -0.12, (PIER_Z0 + PIER_Z1) * 0.5), wood)
	_solid(Vector3(5.0, 0.4, PIER_Z1 - PIER_Z0), Vector3(-0.3, -0.2, (PIER_Z0 + PIER_Z1) * 0.5))
	for z: float in [PIER_Z0 + 1.0, PIER_Z0 + 5.0, PIER_Z1 - 0.5]:
		for sx: float in [-2.6, 2.0]:
			CineFX._cyl(self, "Post", 0.12, 0.14, 2.4, Vector3(sx, -1.0, z), wood)
	for k: int in 3:
		CinePropsD6.lantern(self, Vector3(-2.6 + 4.6 * float(k % 2), 1.6, PIER_Z0 + 2.0 + 3.5 * float(k)), Color("#FF7AC0"))
	moored_boat = CineFX.build_prop("speedboat", {"name": "MooredBoat", "color": Color("#F4F1EA"), "trim": Color("#F37021")})
	moored_boat.position = Vector3(3.6, WATER_Y, PIER_Z1 - 1.5)
	add_child(moored_boat)
	var basin := MeshInstance3D.new()
	basin.name = "Basin"
	var pm := PlaneMesh.new()
	pm.size = Vector2(36.0, COURSE_Z0 - 12.0)
	pm.subdivide_width = 12
	pm.subdivide_depth = 6
	basin.mesh = pm
	basin.material_override = CinePropsD6.water_material()
	basin.position = Vector3(0.0, WATER_Y, (COURSE_Z0 + 12.0) * 0.5)
	add_child(basin)
	for sx: float in [-1.0, 1.0]:   # the land beside the basin up to the canal's banks
		CineFX._box(self, "BasinBank", Vector3(24.0, 1.2, COURSE_Z0 - 12.0), Vector3(sx * 30.0, -0.6, (COURSE_Z0 + 12.0) * 0.5), CineFX._mat(Color("#3B3A36"), 0.95))
	CineFX._box(self, "BasinWall", Vector3(36.0, 1.4, 0.4), Vector3(0.0, WATER_Y - 0.2, 12.4), CineFX._mat(Color("#5E5A52"), 0.9))


func _build_course() -> void:
	var water_root := Node3D.new()
	water_root.name = "Water"
	add_child(water_root)
	var bank_mat: StandardMaterial3D = CineFX._mat(Color("#3B3A36"), 0.95)
	var wall_mat: StandardMaterial3D = CineFX._mat(Color("#5E5A52"), 0.9)
	var s0: float = 0.0
	while s0 < route.length - 0.1:
		var s1: float = minf(s0 + CHUNK_M, route.length)
		water_root.add_child(_strip("Water", s0, s1, -HALF_W - 1.5, HALF_W + 1.5, WATER_Y, WATER_Y, 5, CinePropsD6.water_material()))
		for side: float in [-1.0, 1.0]:
			add_child(_strip("BankTop", s0, s1, side * HALF_W, side * (HALF_W + 34.0), 0.0, 0.0, 1, bank_mat))
			add_child(_strip("BankWall", s0, s1, side * HALF_W, side * HALF_W, WATER_Y - 1.2, 0.0, 1, wall_mat, true))
		s0 = s1
	_build_houses()
	for i: int in BRIDGES.size():
		var b := Node3D.new()
		b.name = "Bridge%d" % i
		CinePropsD6.low_bridge(b, HALF_W * 2.0 + 2.0, BRIDGE_CLEAR)
		b.position = course_pos(BRIDGES[i], 0.0)
		b.rotation.y = yaw_at(BRIDGES[i])
		add_child(b)
		bridge_nodes.append(b)
	for n: Array in NETS:
		var fn: Node3D = CineFX.build_prop("fish_net", {"w": HALF_W + 1.0, "h": 2.6})
		fn.position = course_pos(float(n[0]), float(n[1]) * (HALF_W * 0.5 + 0.5))
		fn.rotation.y = yaw_at(float(n[0]))
		add_child(fn)
		nets.append(fn.get_meta("anim_node"))
	ramp_node = Node3D.new()
	ramp_node.name = "Ramp"
	CinePropsD6.sampan(ramp_node, true)
	ramp_node.position = course_pos(RAMP_S - RAMP_LEN * 0.5 - 6.0, RAMP_D)
	ramp_node.rotation.y = yaw_at(RAMP_S)
	add_child(ramp_node)
	pier_wall_node = Node3D.new()
	pier_wall_node.name = "PierWall"
	CinePropsD6.pier_wall(pier_wall_node, HALF_W - GAP_D1)
	pier_wall_node.position = course_pos(RAMP_S, (GAP_D1 + HALF_W) * 0.5)
	pier_wall_node.rotation.y = yaw_at(RAMP_S)
	add_child(pier_wall_node)
	var barge := Node3D.new()
	barge.name = "Barge"
	barge.position = course_pos(BARGE_S, BARGE_D)
	barge.rotation.y = yaw_at(BARGE_S)
	add_child(barge)
	CineFX._box(barge, "Deck", Vector3(4.0, 0.8, 12.0), Vector3(0.0, 0.1, 0.0), CineFX._mat(Color("#3A2E26"), 0.85))
	for k: int in 6:
		CineFX._cyl(barge, "Tube", 0.18, 0.18, 1.0, Vector3(-1.2 + 0.8 * float(k % 4), 0.95, -4.0 + 1.6 * float(k)), CineFX._mat(Color("#C0392B"), 0.6))
	CinePropsD6.text(barge, "Sign", "PHÁO HOA LỌ", 110, Color("#FFD43B"), Vector3(-2.05, 0.6, 0.0), true).rotation.y = -PI * 0.5
	fireworks = CineAnimD6.make("fireworks")
	barge.add_child(fireworks)
	billboard = CineAnimD6.make("billboard")
	var bp: Vector2 = route.world(BILLBOARD_S, -(HALF_W + 9.0))
	billboard.position = Vector3(bp.x, 0.0, bp.y)
	var r: Vector2 = route.right(BILLBOARD_S)
	billboard.rotation.y = atan2(-r.x, -r.y)   # the board's front (-Z) toward +right: across the canal
	add_child(billboard)
	# the finish bank: stalls of milk-tea baskets and a string of lanterns at the bank where the chase ends
	for k2: int in 5:
		var bpos: Vector2 = route.world(BANK_S - 30.0 + 12.0 * float(k2), HALF_W + 2.0)
		CineFX._box(self, "Stall", Vector3(2.0, 1.0, 1.2), Vector3(bpos.x, 0.5, bpos.y), CineFX._mat(Color.from_hsv(0.92 - 0.04 * float(k2), 0.55, 0.85), 0.8))
	var end_p: Vector2 = route.point(route.length - 1.0)
	CineFX._box(self, "EndWall", Vector3(HALF_W * 2.0 + 4.0, 2.4, 1.0), Vector3(end_p.x, WATER_Y + 0.5, end_p.y), wall_mat).rotation.y = yaw_at(route.length - 1.0)


## A strip along the route between lateral offsets d0 and d1 (heights y0 at d0, y1 at d1; `cols` quads across, `wall`:
## a vertical face from y0 to y1 at d0 with its normal toward the canal) for route [s0, s1].
func _strip(nm: String, s0: float, s1: float, d0: float, d1: float, y0: float, y1: float, cols: int, mat: Material, wall: bool = false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	var s: float = s0
	while true:
		var row: Array = []
		var rt: Vector2 = route.right(s - 2.0) + route.right(s + 2.0)
		rt = rt.normalized()
		var c: Vector2 = route.point(s)
		for k: int in cols + 1:
			var u: float = float(k) / float(cols)
			if wall:
				row.append(Vector3(c.x + rt.x * d0, lerpf(y0, y1, u), c.y + rt.y * d0))
			else:
				var d: float = lerpf(d0, d1, u)
				row.append(Vector3(c.x + rt.x * d, lerpf(y0, y1, u), c.y + rt.y * d))
		rows.append(row)
		if s >= s1 - 0.001:
			break
		s = minf(s + STRIP_M, s1)
	for i: int in rows.size() - 1:
		for k2: int in cols:
			var a: Vector3 = rows[i][k2]
			var b: Vector3 = rows[i][k2 + 1]
			var c2: Vector3 = rows[i + 1][k2]
			var d2: Vector3 = rows[i + 1][k2 + 1]
			for v: Vector3 in [a, b, d2, a, d2, c2]:
				st.add_vertex(v)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	return mi


## MultiMesh houses with lit windows along both banks, and the lantern strings (one MultiMesh each; emissive shader).
func _build_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6066
	var xfs: Array[Transform3D] = []
	var cols: Array[Color] = []
	var wins: Array[Transform3D] = []
	var wcols: Array[Color] = []
	var s: float = 40.0
	while s < route.length - 20.0:
		for side: float in [-1.0, 1.0]:
			if absf(s - BILLBOARD_S) < 22.0 and side < 0.0:
				continue
			var w: float = rng.randf_range(5.5, 8.0)
			var h: float = rng.randf_range(4.0, 11.0)
			var dep: float = rng.randf_range(6.0, 9.0)
			var d: float = side * (HALF_W + 3.0 + dep * 0.5 + rng.randf_range(0.0, 2.5))
			var p: Vector2 = route.world(s, d)
			var yaw: float = yaw_at(s) + (PI * 0.5 if side > 0.0 else -PI * 0.5)   # the front (-Z) toward the canal
			var b := Basis(Vector3.UP, yaw)
			xfs.append(Transform3D(b.scaled(Vector3(w, h, dep)), Vector3(p.x, h * 0.5, p.y)))
			cols.append(Color.from_hsv(rng.randf_range(0.02, 0.12), rng.randf_range(0.15, 0.4), rng.randf_range(0.35, 0.6)))
			var floors: int = int(h / 3.0)
			for f: int in floors:
				for k: int in 2:
					if rng.randf() < 0.55:
						var lp := Vector3((-0.25 + 0.5 * float(k)) * w, 1.6 + 3.0 * float(f), -dep * 0.5 - 0.03)
						wins.append(Transform3D(b, Vector3(p.x, 0.0, p.y) + b * lp))
						wcols.append(Color.from_hsv(rng.randf_range(0.08, 0.14), rng.randf_range(0.3, 0.7), rng.randf_range(0.7, 1.0)))
		s += rng.randf_range(8.0, 11.0)
	var house_mat := StandardMaterial3D.new()
	house_mat.vertex_color_use_as_albedo = true
	house_mat.roughness = 0.9
	var bm := BoxMesh.new()
	add_child(_multimesh("Houses", bm, xfs, cols, house_mat))
	var sh := Shader.new()
	sh.code = WINDOW_SHADER
	var wm := ShaderMaterial.new()
	wm.shader = sh
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 1.1)
	qm.flip_faces = true   # the quad faces +Z by default; the windows face -Z (the house front)
	add_child(_multimesh("Windows", qm, wins, wcols, wm))
	# lantern strings on both banks
	var lx: Array[Transform3D] = []
	var lc: Array[Color] = []
	var palette: Array[Color] = [Color("#FF4FA3"), Color("#FFD43B"), Color("#FF6A3D"), Color("#7AE2FF")]
	var s2: float = 6.0
	var i: int = 0
	while s2 < route.length:
		for side2: float in [-1.0, 1.0]:
			var p2: Vector2 = route.world(s2, side2 * (HALF_W + 0.8))
			var y: float = 2.7 - 0.3 * absf(sin(s2 * 0.45))
			lx.append(Transform3D(Basis.from_scale(Vector3(0.32, 0.4, 0.32)), Vector3(p2.x, y, p2.y)))
			lc.append(palette[i % palette.size()])
			lanterns.append(Vector3(p2.x, y, p2.y))
			i += 1
		s2 += LANTERN_M
	var sm := SphereMesh.new()
	sm.radial_segments = 8
	sm.rings = 4
	add_child(_multimesh("Lanterns", sm, lx, lc, wm))


func _multimesh(nm: String, mesh: Mesh, xfs: Array[Transform3D], cols: Array[Color], mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k: int in xfs.size():
		mm.set_instance_transform(k, xfs[k])
		mm.set_instance_color(k, cols[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _build_light_pool() -> void:
	for k: int in POOL_LIGHTS:
		var ol := OmniLight3D.new()
		ol.name = "PoolLight%d" % k
		ol.light_color = Color("#FFB0D8") if k % 2 == 0 else Color("#FFD9A0")
		ol.light_energy = 1.6
		ol.omni_range = 11.0
		ol.shadow_enabled = false
		add_child(ol)
		lights.append(ol)
	_place_lights()


func _solid(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Solid"
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	return body


func _solid_local(xf: Transform3D, size: Vector3, local: Vector3) -> void:
	var body: StaticBody3D = _solid(size, Vector3.ZERO)
	body.transform = Transform3D(xf.basis, xf * local)


# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	_light_t -= dt
	if _light_t <= 0.0:
		_light_t = 0.25
		_place_lights()


## The light pool on the POOL_LIGHTS lanterns nearest to `focus` (a linear scan of a few hundred points at 4 Hz).
func _place_lights() -> void:
	if lights.is_empty() or lanterns.is_empty():
		return
	var best: Array[int] = []
	var bd: Array[float] = []
	for k: int in lanterns.size():
		var d2: float = (lanterns[k] - focus).length_squared()
		if best.size() < POOL_LIGHTS:
			best.append(k)
			bd.append(d2)
			continue
		var worst: int = 0
		for j: int in bd.size():
			if bd[j] > bd[worst]:
				worst = j
		if d2 < bd[worst]:
			best[worst] = k
			bd[worst] = d2
	for i: int in lights.size():
		lights[i].position = lanterns[best[i]] + Vector3(0.0, -0.4, 0.0) if i < best.size() else focus


## The shop's back door: closed (the leaf in the frame, the collider on) or open (swung back, passable).
func back_door_open(on: bool) -> void:
	if back_door:
		back_door.visible = not on
	if back_door_leaf:
		back_door_leaf.visible = on
	if back_door_body:
		for c: Node in back_door_body.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = on


func is_back_door_open() -> bool:
	return back_door_leaf != null and back_door_leaf.visible


## Every doll turned by w (0 = backs to the room, 1 = facing `target`).
func turn_dolls(target: Vector3, w: float) -> void:
	for sh: CineAnimD6 in shelves:
		sh.aim_heads(target, w)


func dolls_state() -> String:
	return shelves[0].state if not shelves.is_empty() else ""


func safe_open(w: float) -> void:
	if safe:
		safe.set_open(w)


func music_box_spin(angle: float) -> void:
	if music_box:
		music_box.spin_to(angle)


## The level's own copies of what a cinematic brings (the back-room furniture, the moored boat) hidden while it plays.
func hide_for_cine(on: bool, _slot: String = "") -> void:
	if on:
		_hidden.clear()
		for n: Node3D in [room_items, moored_boat]:
			if n and n.visible:
				n.visible = false
				_hidden.append(n)
	else:
		for n2: Node3D in _hidden:
			if is_instance_valid(n2):
				n2.visible = true
		_hidden.clear()
