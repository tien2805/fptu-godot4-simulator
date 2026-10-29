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
# Wave 3 (plan 2026-10-30-w3-day5.md T2, D5W-2): the hall's ceiling lamps (emissive panels in LAMP_ZS rows) and the cold
# light are the mains; set_power(false) kills them row by row from the stairs toward the room (POWER_ROW_S apart,
# `power_row(i)` per row for the clunk), the red emergency lights drop to a dim glow and the red floor strips, the rack
# LEDs and the four hall monitors (MONITORS) stay lit; set_power(true) is instant. flicker_face(secs, k) shows Za Mẩn's
# code-drawn face on the hall monitors, flickering, at strength k (dimmer with "Giảm hù dọa": the mission passes k).
# T3 (the rack domino): every hall rack row is built of RACK_SEG segments, each on a pivot at its aisle-side base edge
# (mesh, LEDs and collider ride it). The segment at the room end of each row carries a red "KHÔNG ĐƯỢC ĐỤNG" label and a
# shootable DominoTarget (a soft target of the weapons through StoryBasement.extra_targets): a bullet / pellet on it tips
# the row onto its aisle (RACK_TIP), segment after segment DOMINO_STEP_S apart, each falling in DOMINO_FALL_S (game time,
# so the mission's slow motion slows it); a fallen segment lies 2.2 m into the aisle, 1.0 m high (low cover).
# reset_racks(keep) stands the rows up again (retry), row_footprint(i, margin) is the fall's floor rectangle (local x, z).
# The side door (SIDE_DOOR, right wall at the cross aisle) is kicked open by kick_door() (wave 2), shut by reset_door().
class_name LairBasement
extends Node3D

signal power_row(row: int)
## T3 rack domino: a labelled rack was shot (the row starts to tip), a segment landed in the aisle, the whole row is down.
signal domino_shot(row: int)
signal rack_landed(row: int, seg: int)
signal row_fallen(row: int)

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
## W3 T3: wave 2 through the side door (the last spot is the pallet-shield guard), wave 3 from both ends (Thường).
const WAVE_DOOR: Array[Vector3] = [Vector3(11.0, 0.0, 18.5), Vector3(10.6, 0.0, 17.7), Vector3(10.6, 0.0, 19.3), Vector3(9.8, 0.0, 18.5)]
const WAVE_ENDS: Array[Vector3] = [Vector3(-9.5, 0.0, 30.5), Vector3(2.5, 0.0, 33.0), Vector3(11.0, 0.0, 18.5), Vector3(10.6, 0.0, 19.3)]
## W3 T4 (the burning countdown): where the breach guards come in (the hall in front of the room's mouth), the cut target,
## two low crates the player can fight from (built by MissionHack for the breaches only), the smoke spots.
const BREACH: Array[Vector3] = [Vector3(-1.5, 0.0, 7.6), Vector3(1.5, 0.0, 7.6), Vector3(0.0, 0.0, 9.6)]
const BREACH_DOOR := Vector3(0.0, 1.2, 5.2)
const HACK_COVER: Array = [[Vector3(2.4, 0.0, 0.9), Vector3(1.6, 1.1, 0.8)], [Vector3(-1.8, 0.0, 1.7), Vector3(1.2, 1.1, 1.2)]]
const SMOKE_PTS: Array[Vector3] = [Vector3(-3.6, 0.0, -2.4), Vector3(2.8, 0.0, -3.7)]
const AMMO: Array[Vector3] = [Vector3(-10.5, 0.0, 12.0), Vector3(10.5, 0.0, 14.0), Vector3(0.0, 0.0, 8.5)]
const DUEL_BOSS := Vector3(0.0, 0.0, -1.6)
const DUEL_PLAYER := Vector3(0.0, 0.0, 3.6)
## The mains: ceiling lamp rows (z, back of the hall first: the order they die in) and the panels of a row (x).
const LAMP_ZS: Array[float] = [31.0, 25.0, 19.0, 13.0, 7.0]
const LAMP_XS: Array[float] = [-9.5, -3.5, 3.5, 9.5]
const POWER_ROW_S: float = 0.14
const RED_ON: float = 1.3
const RED_DARK: float = 0.55
const COLD_ON: float = 0.55
## T3: rack segments, the side each row tips toward (+x / -x: onto its aisle), the domino timing (game seconds).
const RACK_SEG: float = 1.25
const RACK_TIP: Array[float] = [1.0, 1.0, -1.0, 1.0, -1.0, -1.0]
const RACK_H: float = 2.2
const RACK_D: float = 1.0
const DOMINO_STEP_S: float = 0.12
const DOMINO_FALL_S: float = 0.55
const T_LABEL: String = "KHÔNG ĐƯỢC ĐỤNG"
## The side door: the right wall at the cross aisle (local), its opening width.
const SIDE_DOOR := Vector3(HALL_HALF_W, 0.0, 18.5)
const SIDE_DOOR_W: float = 1.6
## Hall monitors on the low cabinets: [local position (screen centre), yaw].
const MONITORS: Array = [[Vector3(-4.0, 1.42, 7.0), 0.0], [Vector3(4.0, 1.42, 7.0), 0.0], [Vector3(-10.5, 1.32, 15.0), -PI * 0.5],
	[Vector3(10.0, 1.32, 22.0), PI * 0.5]]
const FACE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float face = 0.0;
uniform vec3 idle_col : source_color = vec3(0.08, 0.3, 0.85);
uniform vec3 face_col : source_color = vec3(0.35, 1.0, 0.55);
void fragment() {
	vec2 uv = vec2((UV.x * 2.0 - 1.0) * 1.6, 1.0 - UV.y * 2.0);
	float scan = 0.82 + 0.18 * sin(UV.y * 160.0);
	float head = abs(length(uv * vec2(1.0, 0.85)) - 0.8);
	float eyes = min(length(uv - vec2(-0.3, 0.22)), length(uv - vec2(0.3, 0.22)));
	float mouth = abs(length(uv - vec2(0.0, 0.1)) - 0.45) + step(-0.12, uv.y);
	float m = clamp(step(head, 0.05) + step(eyes, 0.11) + step(mouth, 0.045), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	EMISSION = mix(idle_col * 0.9, face_col * (0.15 + 3.2 * m), face) * scan;
}
"""

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
var _fire_opts: Dictionary = {"fire_from": 0.0}   # reused by tick() (no dictionary per update)
## The mains (T2): on, the lamp rows still lit (a cut in progress runs row by row), the lights.
var power_on: bool = true
var lamp_rows: Array = []                            # [MeshInstance3D per panel] per LAMP_ZS row
var rows_lit: int = 0
var reds: Array[OmniLight3D] = []
var cold: OmniLight3D
var monitors: Array[MeshInstance3D] = []
var face_mat: ShaderMaterial
var face_k: float = 0.0                              # the face strength while it flickers (0 = idle screens)
var _lamp_on: StandardMaterial3D
var _lamp_off: StandardMaterial3D
var _row_t: float = -1.0
var _face_t: float = 0.0
var _face_acc: float = 0.0
## T3: per row {"x", "z0", "z1", "dir", "segs" (pivots), "target" (DominoTarget), "t" (-1 = standing, else the fall clock),
## "landed" (segments down), "fallen"}.
var racks: Array[Dictionary] = []
var door: Node3D
var door_open: bool = false
var _door_t: float = -1.0


## The shootable label of a rack row: a soft target of the weapons (WeaponDirector.first_hit's capsule round its
## position); a bullet or a pellet tips the row.
class DominoTarget:
	extends Node3D
	var lair: LairBasement
	var row: int = 0

	func take_hit(info: Dictionary) -> String:
		var kind: String = String(info.get("kind", ""))
		if not (kind in ["bullet", "pellet", "blast"]) or is_down():
			return "none"
		lair.tip_row(row)
		return "stumble"

	func is_down() -> bool:
		return lair == null or float(lair.racks[row]["t"]) >= 0.0


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


## The mains on (instant) or off (row by row from the stairs, POWER_ROW_S apart; instant = all at once). The cold light
## dies with the first row, the red emergency lights dim to RED_DARK; the strips, LEDs and monitors stay lit.
func set_power(on: bool, instant: bool = false) -> void:
	power_on = on
	if on or instant:
		_row_t = -1.0
		for i: int in lamp_rows.size():
			_set_row(i, on)
		rows_lit = lamp_rows.size() if on else 0
	else:
		_row_t = 0.0
		_cut_row()
	if cold:
		cold.light_energy = COLD_ON if on else 0.0
	for r: OmniLight3D in reds:
		r.light_energy = RED_ON if on else RED_DARK


func _set_row(i: int, lit: bool) -> void:
	for mi: Variant in lamp_rows[i]:
		(mi as MeshInstance3D).material_override = _lamp_on if lit else _lamp_off


## The next lit row goes dark (from the back of the hall toward the room).
func _cut_row() -> void:
	var i: int = lamp_rows.size() - rows_lit
	if rows_lit <= 0 or i < 0:
		_row_t = -1.0
		return
	_set_row(i, false)
	rows_lit -= 1
	power_row.emit(i)
	if rows_lit <= 0:
		_row_t = -1.0


## Za Mẩn's face on the hall monitors for `secs`, flickering, at strength k (0..1).
func flicker_face(secs: float, k: float = 1.0) -> void:
	_face_t = secs
	face_k = clampf(k, 0.0, 1.0)
	_face_acc = 0.0
	if face_mat:
		face_mat.set_shader_parameter("face", face_k if secs > 0.0 else 0.0)


## Fires flicker at 20 Hz while lit, the power cut steps its rows, the face flickers, rows tip, the door swings
## (StoryBasement calls it every frame).
func tick(delta: float) -> void:
	for i: int in racks.size():
		if float(racks[i]["t"]) >= 0.0 and not bool(racks[i]["fallen"]):
			_tick_row(i, delta)
	if _door_t >= 0.0 and door:
		_door_t = minf(_door_t + delta, 0.25)
		door.rotation.y = lerpf(0.0, deg_to_rad(-105.0), ease(_door_t / 0.25, 0.4))
		if _door_t >= 0.25:
			_door_t = -1.0
	if _row_t >= 0.0:
		_row_t += delta
		if _row_t >= POWER_ROW_S:
			_row_t = 0.0
			_cut_row()
	if _face_t > 0.0:
		_face_t -= delta
		_face_acc += delta
		if _face_t <= 0.0:
			face_k = 0.0
			face_mat.set_shader_parameter("face", 0.0)
		elif _face_acc >= 0.08:
			_face_acc = 0.0
			var blip: float = fposmod(sin(_face_t * 91.7) * 4375.85, 1.0)
			face_mat.set_shader_parameter("face", face_k * (0.3 if blip < 0.3 else 1.0))
	if not fire_on:
		return
	_fire_t += delta
	_fire_acc += delta
	if _fire_acc < 0.05:
		return
	_fire_acc = 0.0
	for ap: CineAnimProp in fires:
		ap.cine_eval(_fire_t, _fire_opts)


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
	var red: StandardMaterial3D = CineFX._glow_mat(Color("#FF2A2A"), 2.4)
	for i: int in RACK_ROWS.size():
		var row: Array = RACK_ROWS[i]
		var x: float = float(row[0])
		var z0: float = float(row[1])
		var z1: float = float(row[2])
		var len_z: float = z1 - z0
		var n: int = maxi(1, roundi(len_z / RACK_SEG))
		var sl: float = len_z / float(n)
		var dir: float = RACK_TIP[i]
		var segs: Array = []
		for k: int in n:
			var piv := Node3D.new()
			piv.name = "RackSeg"
			piv.position = Vector3(x + dir * RACK_D * 0.5, 0.0, z0 + sl * (k + 0.5))
			add_child(piv)
			var c := Vector3(-dir * RACK_D * 0.5, RACK_H * 0.5, 0.0)
			CineFX._box(piv, "Rack", Vector3(RACK_D, RACK_H, sl - 0.02), c, cab)
			for sx3: float in [-1.0, 1.0]:
				for k2: int in 2:
					CineFX._box(piv, "Leds", Vector3(0.02, 0.05, sl - 0.3), c + Vector3(sx3 * 0.51, -0.3 + 0.6 * k2, 0.0), leds[(i + k + k2) % 3])
			var body := StaticBody3D.new()
			body.name = "Solid"
			piv.add_child(body)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(RACK_D, RACK_H, sl)
			cs.shape = bs
			cs.position = c
			body.add_child(cs)
			segs.append(piv)
		# the label on the room-end segment: a red band on the end face and the aisle face, the text, the target
		var first: Node3D = segs[0]
		var c0 := Vector3(-dir * RACK_D * 0.5, 0.0, 0.0)
		CineFX._box(first, "LabelBand", Vector3(RACK_D + 0.02, 0.22, 0.02), c0 + Vector3(0.0, 1.45, -sl * 0.5 - 0.01), red)
		CineFX._box(first, "LabelBand", Vector3(0.02, 0.22, sl - 0.1), Vector3(0.01 * dir, 1.45, 0.0), red)
		var lbl := Label3D.new()
		lbl.name = "Label"
		lbl.text = T_LABEL
		lbl.font_size = 40
		lbl.pixel_size = 0.0035
		lbl.modulate = Color("#FFF2F2")
		lbl.outline_modulate = Color(0.45, 0.0, 0.02)
		lbl.outline_size = 10
		lbl.position = c0 + Vector3(0.0, 1.72, -sl * 0.5 - 0.03)
		lbl.rotation.y = PI
		first.add_child(lbl)
		var tg := DominoTarget.new()
		tg.name = "DominoTarget"
		tg.lair = self
		tg.row = i
		add_child(tg)
		tg.position = Vector3(x, 0.15, z0 - 0.15)
		racks.append({"x": x, "z0": z0, "z1": z1, "dir": dir, "segs": segs, "target": tg, "t": -1.0, "landed": 0, "fallen": false})
	_build_door()
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
	# the mains: ceiling panels per row (emissive, no lights) and the red floor strips (always lit)
	_lamp_on = CineFX._glow_mat(Color("#DCE8FF"), 1.8)
	_lamp_off = CineFX._mat(Color("#1A1C20"), 0.9)
	for z: float in LAMP_ZS:
		var row: Array = []
		for x: float in LAMP_XS:
			row.append(CineFX._box(self, "Lamp", Vector3(1.4, 0.04, 0.24), Vector3(x, HALL_H - 0.03, z), _lamp_on))
		lamp_rows.append(row)
	rows_lit = lamp_rows.size()
	var strip: StandardMaterial3D = CineFX._glow_mat(Color("#FF2A2A"), 2.2)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(self, "EmergencyStrip", Vector3(0.03, 0.05, HALL_Z1 - ROOM_Z1 - 1.0), Vector3(sx * (HALL_HALF_W - 0.03), 0.35, (ROOM_Z1 + HALL_Z1) * 0.5), strip)
	# the hall monitors (Za Mẩn's face in the blackout)
	face_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FACE_SHADER
	face_mat.shader = sh
	var frame_mat: StandardMaterial3D = CineFX._mat(Color("#121316"), 0.5)
	for mo: Array in MONITORS:
		var root := Node3D.new()
		root.name = "HallMonitor"
		root.position = mo[0]
		root.rotation.y = float(mo[1])
		add_child(root)
		CineFX._box(root, "Bezel", Vector3(0.62, 0.4, 0.05), Vector3(0.0, 0.0, -0.03), frame_mat)
		CineFX._box(root, "Stand", Vector3(0.06, 0.24, 0.06), Vector3(0.0, -0.3, -0.04), frame_mat)
		var scr := MeshInstance3D.new()
		scr.name = "Screen"
		var qm := QuadMesh.new()
		qm.size = Vector2(0.56, 0.34)
		scr.mesh = qm
		scr.material_override = face_mat
		scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(scr)
		monitors.append(scr)
	for p: Vector3 in [Vector3(0.0, 3.3, 14.0), Vector3(0.0, 3.3, 28.0), Vector3(-9.0, 3.3, 21.0), Vector3(9.0, 3.3, 8.0)]:
		var red := OmniLight3D.new()
		red.name = "Emergency"
		red.light_color = Color("#FF2A2A")
		red.light_energy = RED_ON
		red.omni_range = 11.0
		red.shadow_enabled = false
		red.position = p
		add_child(red)
		lights.append(red)
		reds.append(red)
		CineFX._sphere(self, "Beacon", 0.1, p + Vector3(0.0, 0.15, 0.0), CineFX._glow_mat(Color("#FF2A2A"), 3.0))
	cold = OmniLight3D.new()
	cold.name = "Cold"
	cold.light_color = Color("#8FB4FF")
	cold.light_energy = COLD_ON
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


# ---------------------------------------------------------------------------
# T3: the rack domino and the side door
# ---------------------------------------------------------------------------
## Starts the domino of row i (false: already down or tipping).
func tip_row(i: int) -> bool:
	if i < 0 or i >= racks.size() or float(racks[i]["t"]) >= 0.0:
		return false
	racks[i]["t"] = 0.0
	racks[i]["landed"] = 0
	domino_shot.emit(i)
	return true


func _tick_row(i: int, delta: float) -> void:
	var r: Dictionary = racks[i]
	var t: float = float(r["t"]) + delta
	r["t"] = t
	var segs: Array = r["segs"]
	var dir: float = float(r["dir"])
	for k: int in segs.size():
		var u: float = clampf((t - DOMINO_STEP_S * k) / DOMINO_FALL_S, 0.0, 1.0)
		(segs[k] as Node3D).rotation.z = -dir * PI * 0.5 * u * u
		if u >= 1.0 and k >= int(r["landed"]):
			r["landed"] = k + 1
			rack_landed.emit(i, k)
	if int(r["landed"]) >= segs.size():
		r["fallen"] = true
		row_fallen.emit(i)


## Every row standing again except the rows in keep (left lying), instantly (a retry).
func reset_racks(keep: Array = []) -> void:
	for i: int in racks.size():
		var r: Dictionary = racks[i]
		var down: bool = i in keep
		r["t"] = DOMINO_FALL_S + DOMINO_STEP_S * (r["segs"] as Array).size() if down else -1.0
		r["fallen"] = down
		r["landed"] = (r["segs"] as Array).size() if down else 0
		for sg: Variant in r["segs"]:
			(sg as Node3D).rotation.z = -float(r["dir"]) * PI * 0.5 if down else 0.0


## Rows lying in the aisle now.
func fallen_rows() -> Array:
	var out: Array = []
	for i: int in racks.size():
		if bool(racks[i]["fallen"]):
			out.append(i)
	return out


## The floor rectangle (local x, z) a fallen row covers, grown by margin.
func row_footprint(i: int, margin: float = 0.0) -> Rect2:
	var r: Dictionary = racks[i]
	var x0: float = float(r["x"]) + float(r["dir"]) * RACK_D * 0.5
	var x1: float = x0 + float(r["dir"]) * RACK_H
	return Rect2(minf(x0, x1) - margin, float(r["z0"]) - margin, absf(x1 - x0) + margin * 2.0, float(r["z1"]) - float(r["z0"]) + margin * 2.0)


## Transform (world) and size of a fallen segment as a low cover box (CoverMap.add_box).
func seg_cover(i: int, k: int) -> Array:
	var r: Dictionary = racks[i]
	var segs: Array = r["segs"]
	var sl: float = (float(r["z1"]) - float(r["z0"])) / float(segs.size())
	var piv: Node3D = segs[k]
	var c: Vector3 = piv.position + Vector3(float(r["dir"]) * RACK_H * 0.5, RACK_D * 0.5, 0.0)   # the box centre
	return [global_transform * Transform3D(Basis(), c), Vector3(RACK_H, RACK_D, sl)]


func _build_door() -> void:
	var frame_mat: StandardMaterial3D = CineFX._mat(Color("#2A2E33"), 0.6)
	var x: float = SIDE_DOOR.x
	CineFX._box(self, "DoorFrame", Vector3(0.08, 2.3, 0.1), Vector3(x - 0.05, 1.15, SIDE_DOOR.z - SIDE_DOOR_W * 0.5 - 0.05), frame_mat)
	CineFX._box(self, "DoorFrame", Vector3(0.08, 2.3, 0.1), Vector3(x - 0.05, 1.15, SIDE_DOOR.z + SIDE_DOOR_W * 0.5 + 0.05), frame_mat)
	CineFX._box(self, "DoorFrame", Vector3(0.08, 0.1, SIDE_DOOR_W + 0.2), Vector3(x - 0.05, 2.33, SIDE_DOOR.z), frame_mat)
	CineFX._box(self, "DoorDark", Vector3(0.02, 2.25, SIDE_DOOR_W), Vector3(x - 0.01, 1.125, SIDE_DOOR.z), CineFX._mat(Color("#050507"), 1.0))
	door = Node3D.new()
	door.name = "SideDoor"
	door.position = Vector3(x - 0.08, 0.0, SIDE_DOOR.z - SIDE_DOOR_W * 0.5)   # hinge
	add_child(door)
	CineFX._box(door, "Panel", Vector3(0.06, 2.2, SIDE_DOOR_W - 0.04), Vector3(0.0, 1.1, SIDE_DOOR_W * 0.5), CineFX._mat(Color("#6B4A33"), 0.7))
	CineFX._box(door, "Sign", Vector3(0.02, 0.18, 0.5), Vector3(-0.04, 1.7, SIDE_DOOR_W * 0.5), CineFX._glow_mat(Color("#29C46A"), 1.6))


## The side door bursts open (wave 2 kicks it).
func kick_door() -> void:
	if door_open:
		return
	door_open = true
	_door_t = 0.0


func reset_door() -> void:
	door_open = false
	_door_t = -1.0
	if door:
		door.rotation.y = 0.0


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
			var wd: Array = []
			for q4: Vector3 in WAVE_DOOR:
				wd.append(world(q4))
			var we: Array = []
			for q5: Vector3 in WAVE_ENDS:
				we.append(world(q5))
			d["wave_door"] = wd
			d["wave_ends"] = we
			d["door"] = world(SIDE_DOOR + Vector3(-0.6, 0.0, 0.0))
			var am: Array = []
			for q3: Vector3 in AMMO:
				am.append(world(q3))
			d["ammo"] = am
		"hack":
			d["spot"] = world(TERMINAL_SPOT)
			d["spot_yaw"] = 0.0
			var br: Array = []
			for q6: Vector3 in BREACH:
				br.append(world(q6))
			d["breach"] = br
			d["breach_door"] = world(BREACH_DOOR)
			var hc: Array = []
			for c2: Array in HACK_COVER:
				hc.append([world(c2[0]), c2[1]])
			d["cover"] = hc
			var fp: Array = []
			for f2: Array in FIRES:
				fp.append(world(f2[0]))
			d["fires"] = fp
			var sp: Array = []
			for q7: Vector3 in SMOKE_PTS:
				sp.append(world(q7))
			d["smoke"] = sp
		"duel":
			d["start"] = world(DUEL_PLAYER)
			d["start_yaw"] = 0.0
			d["boss_at"] = world(DUEL_BOSS)
			d["boss_yaw"] = PI
	return d
