# File: res://scripts/story/lairs/LairBasement.gd
# The Day 5 server basement under a The Beverly tower (spec C-D5 / C-D8; plan 2026-10-26-phase-c-integration.md): a
# code-built interior at the world origin of its own scene (StoryBasement), like the Night Building.
# Frame: x right, -z toward the server room, floor y = 0. Two spaces:
#   - the SERVER ROOM: the cinematics' carried room (13 x 9.3 m, open toward +z, CinePropsC "server_room" + four racks a
#     side + the 50-monitor wall at (0, 0, -4.7)) at exactly the frame every Day 5 cinematic is staged in: they play with
#     xf = room_xf() and drop_set, so this room replaces their carried one. The terminal desk stands in it (the typing
#     battle); fires light up after the hack (the burning room of choice 2); the duel is fought here and in the front of the
#     hall;
#   - the SERVER HALL in front of it (24 x 30 m, z 4.5..34.5): three rows of tall racks with a cross aisle (occluders for
#     the stealth, never cover), low cabinets and crates (group "cover", CoverMap.scan), the stairs at the back (the
#     player's way in), red emergency lights and a dim cold light.
# The monitor wall is off until cine_d5_monitors, then frozen on the "Lọ Thần đã gặp sự cố" screen (set_wall). While a
# cinematic plays, hide_for_cine(true) hides what the timelines bring themselves (the monitor wall during the monitors
# beat, the terminal, the fires).
# Cost: static meshes and colliders; the fires flicker through CineAnimProp.cine_eval only while lit (tick(dt) at 20 Hz).
class_name LairBasement
extends Node3D

const ROOM_W: float = 13.0
const ROOM_D: float = 9.3
const ROOM_Z1: float = 4.5
const ROOM_H: float = 3.4
const HALL_HALF_W: float = 12.0
const HALL_Z1: float = 34.5
const HALL_H: float = 3.6
const WALL_T: float = 0.3
## Hall rack rows: [x, z0, z1] (1.0 m deep, 2.2 m tall), a cross aisle at z 17.5..19.5.
const RACK_ROWS: Array = [[-7.0, 10.0, 17.5], [-7.0, 19.5, 27.0], [0.0, 11.0, 17.5], [0.0, 19.5, 26.0], [7.0, 10.0, 17.5], [7.0, 19.5, 27.0]]
## Low cover: [local centre (floor), size].
const COVER: Array = [
	[Vector3(-4.0, 0.0, 7.0), Vector3(2.4, 1.1, 0.8)], [Vector3(4.0, 0.0, 7.0), Vector3(2.4, 1.1, 0.8)],
	[Vector3(-10.0, 0.0, 9.0), Vector3(0.8, 1.1, 2.4)], [Vector3(10.0, 0.0, 9.0), Vector3(0.8, 1.1, 2.4)],
	[Vector3(-10.5, 0.0, 15.0), Vector3(1.2, 1.0, 1.0)], [Vector3(10.5, 0.0, 16.0), Vector3(1.2, 1.0, 1.0)],
	[Vector3(-10.0, 0.0, 22.0), Vector3(1.0, 1.0, 1.0)], [Vector3(10.0, 0.0, 22.0), Vector3(1.0, 1.0, 1.0)],
	[Vector3(-4.5, 0.0, 30.0), Vector3(2.4, 1.1, 0.8)], [Vector3(4.5, 0.0, 30.0), Vector3(2.4, 1.1, 0.8)],
]
## The cine fires of cine_d5_choice (stage frame = this frame), lit after the hack.
const FIRES: Array = [[Vector3(-4.6, 0.0, -2.8), 1.0], [Vector3(4.5, 0.0, -1.7), 0.8], [Vector3(-4.5, 0.0, 0.6), 0.7], [Vector3(-2.6, 0.0, -3.9), 0.9]]
const TERMINAL := Vector3(3.6, 0.0, -2.9)            # the desk (laptop facing +z)
const TERMINAL_SPOT := Vector3(3.6, 0.0, -2.05)      # where the player types, facing -z

# ----- gameplay points -----
const START := Vector3(0.0, 0.0, 32.5)               # down the stairs, facing the room (-z)
const STEALTH_GOAL := Vector3(0.0, 0.0, 5.6)         # the room's mouth
const STEALTH_GOAL_R: float = 2.4
const PATROLS: Array = [
	[Vector3(-3.5, 0.0, 12.0), [Vector3(-3.5, 0.0, 12.0), Vector3(-3.5, 0.0, 26.0)]],
	[Vector3(3.5, 0.0, 26.0), [Vector3(3.5, 0.0, 26.0), Vector3(3.5, 0.0, 12.0)]],
	[Vector3(-10.0, 0.0, 18.5), [Vector3(-10.0, 0.0, 18.5), Vector3(10.0, 0.0, 18.5)]],
]
const FIGHT_START := Vector3(0.0, 0.0, 2.8)
const WAVE1: Array[Vector3] = [Vector3(-9.5, 0.0, 30.5), Vector3(9.5, 0.0, 30.5), Vector3(-2.5, 0.0, 33.0), Vector3(2.5, 0.0, 33.0)]
const WAVE2: Array[Vector3] = [Vector3(-10.5, 0.0, 24.0), Vector3(10.5, 0.0, 24.0), Vector3(0.0, 0.0, 31.5), Vector3(-6.0, 0.0, 32.0)]
const AMMO: Array[Vector3] = [Vector3(-10.5, 0.0, 12.0), Vector3(10.5, 0.0, 14.0), Vector3(0.0, 0.0, 8.5)]
const DUEL_BOSS := Vector3(0.0, 0.0, -1.6)
const DUEL_PLAYER := Vector3(0.0, 0.0, 3.6)

var wall: CineAnimProp
var terminal: Node3D
var laptop_screen: MeshInstance3D
var fires: Array[CineAnimProp] = []
var fire_on: bool = false
var core: Node3D                                     # the rack that sparks when the hack lands (the replay's focus)
var lights: Array[OmniLight3D] = []
var _hidden: Array[Node3D] = []
var _fire_t: float = 0.0
var _fire_acc: float = 0.0


func _init() -> void:
	name = "LairBasement"


## Builds the level (call once, before or after add_child).
func build() -> void:
	_room()
	_hall()
	_lights()


## The frame every Day 5 cinematic is staged in (pass with drop_set).
func room_xf() -> Transform3D:
	return global_transform


func world(local: Vector3) -> Vector3:
	return global_transform * local


# ---------------------------------------------------------------------------
func _room() -> void:
	var room: Node3D = CineFX.build_prop("server_room", {"width": ROOM_W, "depth": ROOM_D, "z1": ROOM_Z1, "height": ROOM_H})
	room.name = "ServerRoom"
	add_child(room)
	var zb: float = ROOM_Z1 - ROOM_D - 0.075
	_solid(Vector3(ROOM_W + 0.4, ROOM_H, WALL_T), Vector3(0.0, ROOM_H * 0.5, zb - WALL_T * 0.5 + 0.075))
	for sx: float in [-1.0, 1.0]:
		_solid(Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(sx * (ROOM_W * 0.5 + 0.075 + WALL_T * 0.5 - 0.075), ROOM_H * 0.5, ROOM_Z1 - ROOM_D * 0.5))
	for i: int in 4:
		var z: float = -3.4 + 1.15 * i
		for sx2: float in [-1.0, 1.0]:
			var r: Node3D = CineFX.build_prop("server_rack", {"seed": i + (1 if sx2 > 0.0 else 0)})
			add_child(r)
			r.position = Vector3(sx2 * 5.4, 0.0, z)
			r.rotation.y = deg_to_rad(-90.0 * sx2)
			_solid(Vector3(1.0, 2.0, 0.6), Vector3(sx2 * 5.4, 1.0, z))
			if i == 1 and sx2 > 0.0:
				core = r
	var wp: Node3D = CineFX.build_prop("monitor_wall", {"anim": true})
	wp.name = "MonitorWall"
	add_child(wp)
	wp.position = Vector3(0.0, 0.0, -4.7)
	wp.rotation.y = PI
	wall = wp.get_meta("anim_node") as CineAnimProp
	set_wall("off")
	terminal = Node3D.new()
	terminal.name = "Terminal"
	terminal.position = TERMINAL
	add_child(terminal)
	terminal.add_child(CineFX.build_prop("desk"))
	_solid(Vector3(1.5, 0.75, 0.75), TERMINAL + Vector3(0.0, 0.375, 0.0))
	var lap: Node3D = CineFX.build_prop("laptop")
	lap.position = Vector3(0.0, 0.75, -0.05)
	lap.rotation.y = PI
	terminal.add_child(lap)
	laptop_screen = MeshInstance3D.new()
	laptop_screen.name = "Glow"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.5, 0.3)
	laptop_screen.mesh = qm
	laptop_screen.material_override = CineFX._glow_mat(Color("#3BFF7A"), 1.6)
	laptop_screen.position = Vector3(0.0, 0.98, -0.12)
	terminal.add_child(laptop_screen)
	for f: Array in FIRES:
		var fp: Node3D = CineFX.build_prop("fire", {"anim": true, "spread": float(f[1]), "flames": 5})
		fp.position = f[0]
		add_child(fp)
		var ap: CineAnimProp = fp.get_meta("anim_node") as CineAnimProp
		ap.cine_eval(0.0, {"fire_from": 99.0})
		fp.visible = false
		fires.append(ap)


## The monitor wall state: "off" (before the monitors beat) or "error" (frozen on the crash screen after it).
func set_wall(st: String) -> void:
	if wall == null:
		return
	if st == "error":
		wall.cine_eval(10.0, {"face_at": 0.0, "freeze_at": 1.0})
	else:
		wall.cine_eval(0.0, {})


## The burning room (after the hack, choice 2 and the duel): the four fires lit (on) or out.
func set_fire(on: bool) -> void:
	fire_on = on
	for ap: CineAnimProp in fires:
		ap.get_parent().visible = on
		ap.cine_eval(_fire_t, {"fire_from": 0.0 if on else 99.0})


## Hides what a Day 5 cinematic brings itself: the terminal and the fires (every cinematic) and the monitor wall (only
## cine_d5_monitors, whose wall is not set dressing). false shows them again.
func hide_for_cine(on: bool, wall_too: bool = false) -> void:
	if on:
		_hidden.clear()
		var list: Array[Node3D] = [terminal]
		for ap: CineAnimProp in fires:
			list.append(ap.get_parent() as Node3D)
		if wall_too and wall:
			list.append(wall.get_parent() as Node3D)
		for n: Node3D in list:
			if n and n.visible:
				n.visible = false
				_hidden.append(n)
	else:
		for n2: Node3D in _hidden:
			if is_instance_valid(n2):
				n2.visible = true
		_hidden.clear()


## Fires flicker at 20 Hz while lit (StoryBasement calls it every frame).
func tick(delta: float) -> void:
	if not fire_on:
		return
	_fire_t += delta
	_fire_acc += delta
	if _fire_acc < 0.05:
		return
	_fire_acc = 0.0
	for ap: CineAnimProp in fires:
		ap.cine_eval(_fire_t, {"fire_from": 0.0})


func _hall() -> void:
	var floor_mat: StandardMaterial3D = CineFX._mat(Color("#4E545B"), 0.7)
	var wall_mat: StandardMaterial3D = CineFX._mat(Color("#33383F"), 0.9)
	var ceil_mat: StandardMaterial3D = CineFX._mat(Color("#22262B"), 0.95)
	var zc: float = (ROOM_Z1 + HALL_Z1) * 0.5
	var depth: float = HALL_Z1 - ROOM_Z1
	var w: float = HALL_HALF_W * 2.0
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = Vector3(w + 2.0, 0.4, HALL_Z1 + 8.0)
	fcs.shape = fbs
	fcs.position = Vector3(0.0, -0.2, (HALL_Z1 - 6.0) * 0.5)
	floor_body.add_child(fcs)
	CineFX._box(self, "HallFloor", Vector3(w, 0.02, depth), Vector3(0.0, 0.01, zc), floor_mat)
	CineFX._box(self, "HallCeiling", Vector3(w, 0.12, depth), Vector3(0.0, HALL_H + 0.06, zc), ceil_mat)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(self, "HallSide", Vector3(WALL_T, HALL_H, depth), Vector3(sx * (HALL_HALF_W + WALL_T * 0.5), HALL_H * 0.5, zc), wall_mat)
		_solid(Vector3(WALL_T, HALL_H, depth), Vector3(sx * (HALL_HALF_W + WALL_T * 0.5), HALL_H * 0.5, zc))
		# the front wall either side of the room's mouth
		var fw: float = HALL_HALF_W - ROOM_W * 0.5 - 0.15
		var fx: float = sx * (ROOM_W * 0.5 + 0.15 + fw * 0.5)
		CineFX._box(self, "HallFront", Vector3(fw, HALL_H, WALL_T), Vector3(fx, HALL_H * 0.5, ROOM_Z1 + WALL_T * 0.5), wall_mat)
		_solid(Vector3(fw, HALL_H, WALL_T), Vector3(fx, HALL_H * 0.5, ROOM_Z1 + WALL_T * 0.5))
		# the lintel above the mouth (the room is lower than the hall)
	CineFX._box(self, "Lintel", Vector3(ROOM_W + 0.3, HALL_H - ROOM_H, WALL_T), Vector3(0.0, ROOM_H + (HALL_H - ROOM_H) * 0.5, ROOM_Z1 + WALL_T * 0.5), wall_mat)
	CineFX._box(self, "HallBack", Vector3(w, HALL_H, WALL_T), Vector3(0.0, HALL_H * 0.5, HALL_Z1 + WALL_T * 0.5), wall_mat)
	_solid(Vector3(w, HALL_H, WALL_T), Vector3(0.0, HALL_H * 0.5, HALL_Z1 + WALL_T * 0.5))
	# the stairs the player came down (a doorway with steps going up behind it)
	CineFX._box(self, "Stairwell", Vector3(2.4, 2.4, 0.05), Vector3(0.0, 1.2, HALL_Z1 - 0.02), CineFX._mat(Color("#07080A"), 1.0))
	for k: int in 4:
		CineFX._box(self, "Step", Vector3(2.2, 0.18, 0.4), Vector3(0.0, 0.09 + 0.18 * k, HALL_Z1 - 0.3 - 0.4 * (3 - k)), CineFX._mat(Color("#5A6068"), 0.8))
	CineFX._box(self, "ExitSign", Vector3(0.6, 0.18, 0.04), Vector3(0.0, 2.7, HALL_Z1 - 0.05), CineFX._glow_mat(Color("#29C46A"), 2.0))
	# rack rows (tall: occluders, not cover)
	var cab: StandardMaterial3D = CineFX._mat(Color("#16171B"), 0.4)
	var leds: Array[StandardMaterial3D] = [CineFX._glow_mat(Color("#3BFF7A"), 2.5), CineFX._glow_mat(Color("#3BA7FF"), 2.5),
		CineFX._glow_mat(Color("#FFB23B"), 2.5)]
	for i: int in RACK_ROWS.size():
		var row: Array = RACK_ROWS[i]
		var x: float = float(row[0])
		var z0: float = float(row[1])
		var z1: float = float(row[2])
		var len_z: float = z1 - z0
		CineFX._box(self, "RackRow", Vector3(1.0, 2.2, len_z), Vector3(x, 1.1, (z0 + z1) * 0.5), cab)
		for sx3: float in [-1.0, 1.0]:
			for k2: int in 4:
				CineFX._box(self, "Leds", Vector3(0.02, 0.05, len_z - 0.6), Vector3(x + sx3 * 0.51, 0.6 + 0.4 * k2, (z0 + z1) * 0.5), leds[(i + k2) % 3])
		_solid(Vector3(1.0, 2.2, len_z), Vector3(x, 1.1, (z0 + z1) * 0.5))
	# low cover
	var steel: StandardMaterial3D = CineFX._mat(Color("#5B636D"), 0.45)
	for c: Array in COVER:
		var body := StaticBody3D.new()
		body.name = "Cabinet"
		body.add_to_group("cover")
		body.position = c[0]
		add_child(body)
		var size: Vector3 = c[1]
		CineFX._box(body, "Box", size, Vector3(0.0, size.y * 0.5, 0.0), steel)
		CineFX._box(body, "Vent", Vector3(size.x * 0.8, 0.08, size.z + 0.02), Vector3(0.0, size.y * 0.75, 0.0), CineFX._mat(Color("#2A2E33"), 0.6))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = Vector3(0.0, size.y * 0.5, 0.0)
		body.add_child(cs)


func _lights() -> void:
	for p: Vector3 in [Vector3(0.0, 3.3, 14.0), Vector3(0.0, 3.3, 28.0), Vector3(-9.0, 3.3, 21.0), Vector3(9.0, 3.3, 8.0)]:
		var red := OmniLight3D.new()
		red.name = "Emergency"
		red.light_color = Color("#FF2A2A")
		red.light_energy = 1.3
		red.omni_range = 11.0
		red.shadow_enabled = false
		red.position = p
		add_child(red)
		lights.append(red)
		CineFX._sphere(self, "Beacon", 0.1, p + Vector3(0.0, 0.15, 0.0), CineFX._glow_mat(Color("#FF2A2A"), 3.0))
	var cold := OmniLight3D.new()
	cold.name = "Cold"
	cold.light_color = Color("#8FB4FF")
	cold.light_energy = 0.55
	cold.omni_range = 20.0
	cold.shadow_enabled = false
	cold.position = Vector3(0.0, 3.4, 20.0)
	add_child(cold)
	lights.append(cold)


func _solid(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Solid"
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)


## World-space spots of a basement task (MissionLairFight / MissionHack / MissionDuel opts "points").
func mission_points(task: String) -> Dictionary:
	var d: Dictionary = {"centre": world(Vector3(0.0, 0.0, 15.0)), "leash": 60.0}
	match task:
		"stealth":
			d["start"] = world(START)
			d["start_yaw"] = 0.0                    # facing -z, toward the server room
			d["goal"] = world(STEALTH_GOAL)
			d["goal_r"] = STEALTH_GOAL_R
			var pats: Array = []
			for pr: Array in PATROLS:
				var route: Array = []
				for q: Variant in pr[1]:
					route.append(world(q))
				pats.append([world(pr[0]), route])
			d["patrols"] = pats
		"gunfight":
			d["start"] = world(FIGHT_START)
			d["start_yaw"] = PI                     # facing the hall (+z), where the guards come from
			var w1: Array = []
			for q1: Vector3 in WAVE1:
				w1.append(world(q1))
			var w2: Array = []
			for q2: Vector3 in WAVE2:
				w2.append(world(q2))
			d["waves"] = [w1, w2]
			var am: Array = []
			for q3: Vector3 in AMMO:
				am.append(world(q3))
			d["ammo"] = am
		"hack":
			d["spot"] = world(TERMINAL_SPOT)
			d["spot_yaw"] = 0.0
		"duel":
			d["start"] = world(DUEL_PLAYER)
			d["start_yaw"] = 0.0
			d["boss_at"] = world(DUEL_BOSS)
			d["boss_yaw"] = PI
	return d
