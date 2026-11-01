# File: res://scripts/story/lairs/LairTower.gd
# The Lọ Academy tower of Day 7 (Phase D, plan 2026-11-01-w4-day7.md): a code-built level at the origin of its own scene
# (StoryTower). One "floor" per segment, each a cell of its own CELL_X metres apart along +X at y = 0 (side by side, never
# stacked: the bike AI and the gunmen find the floor with downward rays); show_floor(id) shows one cell and hides the rest
# (hidden cells cost nothing to draw; their static colliders stay, far away).
# Frame of every floor: x right, -z forward, floor y = 0, the cell's origin at its centre.
#   parking    the parking deck: a ring road (lane centre RING_R, between the core wall and the parapet) for Sói Xám's bike
#              duel; route(laps) is the ring sampled as a BikeRoute polyline, travel counter-clockwise seen from above;
#   warehouse  Alexander's floor: a 40 x 34 hall, shelving along the walls, low crate stacks (cover);
#   servers    Za Mẫn's floor: rack rows along the walls round an open duel square;
#   mannequins the showroom: a 14 x 56 corridor, tall display walls in a zigzag (occluders), mannequin groups (dressing),
#              three guard patrols, the lift at the far end;
#   gallery    the vase gallery: the laser corridor (6 m wide, z 48..12) into the hall (28 x 24, z 12..-12): twelve plinths
#              with antique vases (low cover; `vases`), wall speakers (`speakers`), two breakers (`breakers`), gold lights
#              (set_power), Lọ's sign on the back wall;
#   penthouse  the office with the exam-system rack (the typing);
#   roof       the helipad in the rain: a parapet, AC units, the helicopter hovering with its searchlight (`heli`,
#              `heli_light`; tick() turns the rotor and sweeps the light while the roof shows), a city far below.
# cover_root is the shown floor's cell (MissionLairFight scans its group "cover").
# Cost: static meshes and colliders, a few lights per floor (no shadows except the searchlight); tick() only touches the
# roof (rotor + sweep) while it shows.
class_name LairTower
extends Node3D

const CELL_X: float = 160.0
const FLOORS: Array[String] = ["parking", "warehouse", "servers", "mannequins", "gallery", "penthouse", "roof"]
const TASK_FLOOR: Dictionary = {"parking": "parking", "warehouse": "warehouse", "servers": "servers",
	"mannequins": "mannequins", "lasers": "gallery", "boss_guns": "gallery", "boss_dark": "gallery", "boss_saber": "roof",
	"typing": "penthouse"}
## Cinematic slots and the floor they are staged on (cine_xf).
const SLOT_FLOOR: Dictionary = {"cine_d7_monologue": "gallery", "seg_d7_phase2": "gallery", "seg_d7_finisher": "roof"}
## A slot's stage origin in its floor's frame (T4): seg_d7_phase2's 14 x 10 fight box puts its surface prop (a plinth) on the
## hall's plinth at (3, 0, 0) and its spare plinth on (-3, 0, 0): those two real plinths hide while it plays (hide_for_cine).
const SLOT_OFFSET: Dictionary = {"seg_d7_phase2": Vector3(0.4, 0.0, -0.75)}
## The real plinths a slot replaces with its own (floor-local x, z).
const CINE_PLINTHS: Dictionary = {"seg_d7_phase2": [Vector2(3.0, 0.0), Vector2(-3.0, 0.0)]}
const WALL_T: float = 0.4
# parking
const RING_R: float = 22.0
const RING_IN: float = 17.0
const RING_OUT: float = 27.0
const RING_SEGS: int = 36
const DECK_H: float = 4.4
# warehouse
const WH_W: float = 40.0
const WH_D: float = 34.0
const WH_H: float = 6.0
const WH_CRATES: Array = [[Vector3(-12.0, 0.0, 6.0), Vector3(2.4, 1.1, 1.2)], [Vector3(12.0, 0.0, 6.0), Vector3(2.4, 1.1, 1.2)],
	[Vector3(-6.0, 0.0, 12.0), Vector3(1.2, 1.1, 2.4)], [Vector3(6.0, 0.0, 12.0), Vector3(1.2, 1.1, 2.4)],
	[Vector3(-13.0, 0.0, -6.0), Vector3(1.2, 1.1, 2.4)], [Vector3(13.0, 0.0, -6.0), Vector3(1.2, 1.1, 2.4)]]
# servers
const SV_W: float = 26.0
const SV_D: float = 22.0
const SV_H: float = 3.6
# mannequins
const MN_W: float = 14.0
const MN_D: float = 56.0
const MN_H: float = 4.0
## Display walls: [centre, size] (tall: occluders, never cover).
const MN_WALLS: Array = [[Vector3(-3.0, 0.0, 15.0), Vector3(8.0, 2.6, 0.6)], [Vector3(3.0, 0.0, 6.0), Vector3(8.0, 2.6, 0.6)],
	[Vector3(-3.0, 0.0, -3.0), Vector3(8.0, 2.6, 0.6)], [Vector3(3.0, 0.0, -12.0), Vector3(8.0, 2.6, 0.6)],
	[Vector3(-3.0, 0.0, -19.0), Vector3(8.0, 2.6, 0.6)]]
const MN_GROUPS: Array[Vector3] = [Vector3(-4.5, 0.0, 19.0), Vector3(4.5, 0.0, 10.0), Vector3(-4.5, 0.0, 1.0),
	Vector3(4.5, 0.0, -8.0), Vector3(-4.5, 0.0, -15.0)]
## The first guard walks a short triangle in the left half of his band (the fix round: his full-width beat, and a
## there-and-back turn at its east end, swept the way in through the first gap). Turning south at its east corner and north
## into the wall at its west one, he has his back to the crossing for ~6 s of every lap: a careful player gets past unseen.
const MN_PATROLS: Array = [[Vector3(-1.5, 0.0, 11.0), [Vector3(-1.5, 0.0, 11.0), Vector3(-4.0, 0.0, 9.0), Vector3(-6.0, 0.0, 11.0)]],
	[Vector3(-4.5, 0.0, -0.5), [Vector3(-4.5, 0.0, -0.5), Vector3(5.0, 0.0, -0.5)]],
	[Vector3(4.5, 0.0, -16.0), [Vector3(4.5, 0.0, -16.0), Vector3(-5.0, 0.0, -16.0), Vector3(4.5, 0.0, -16.0), Vector3(4.5, 0.0, -22.0)]]]
# gallery
const GA_W: float = 28.0
const GA_D: float = 24.0
const GA_H: float = 4.6
const CORR_W: float = 6.0
const CORR_Z0: float = 12.0
const CORR_Z1: float = 48.0
const CORR_H: float = 3.2
## The laser corridor per difficulty (T5b, sim_day7): the second blink wall's lit share ...
const LASER_BLINK2_ON: float = 0.6
const LASER_BLINK2_ON_EASY: float = 0.5
## ... and Thường's two extra sweeps (z 37, z 20) with their periods.
const LASER_EXTRA_SWEEP_S: Array = [3.4, 3.0]
## Dễ: every sweep and blink wall runs this much slower (longer gaps, the same telegraphs): never harder than Thường.
const LASER_EASY_SLOW: float = 1.3
## Dễ: a blink wall's lit share of its period (Thường 0.55 / 0.6): ~0.6 s lit in every ~4 s, after the same 0.6 s warn.
const LASER_EASY_ON: float = 0.15
const PLINTH_XS: Array[float] = [-9.0, -3.0, 3.0, 9.0]
const PLINTH_ZS: Array[float] = [6.0, 0.0, -6.0]
const SPEAKERS: Array = [[Vector3(-13.75, 3.2, 8.0), PI * 0.5], [Vector3(-13.75, 3.2, -8.0), PI * 0.5],
	[Vector3(13.75, 3.2, 8.0), -PI * 0.5], [Vector3(13.75, 3.2, -8.0), -PI * 0.5], [Vector3(-6.0, 3.2, -11.75), 0.0],
	[Vector3(6.0, 3.2, -11.75), 0.0], [Vector3(-8.0, 3.2, 11.75), PI], [Vector3(8.0, 3.2, 11.75), PI]]
const BREAKERS: Array = [[Vector3(-13.75, 1.4, 2.5), PI * 0.5], [Vector3(13.75, 1.4, -3.5), -PI * 0.5]]
const GA_LIGHTS: Array[Vector3] = [Vector3(-7.0, 4.2, 5.0), Vector3(7.0, 4.2, 5.0), Vector3(-7.0, 4.2, -6.0), Vector3(7.0, 4.2, -6.0)]
# penthouse
const PH_W: float = 16.0
const PH_D: float = 12.0
const PH_H: float = 3.6
const EXAM_AT := Vector3(0.0, 0.0, -5.3)
# roof
const RF_HALF: float = 15.0
const HELI_AT := Vector3(0.0, 9.0, -13.0)
const SWEEP_S: float = 7.0
const SWEEP_M: float = 4.5

var cells: Dictionary = {}                 # floor id -> Node3D
var current_floor: String = ""
var cover_root: Node3D = null
## gallery: [{"node": Node3D (vase root), "plinth": StaticBody3D, "at": Vector3 (world, plinth foot)}]
var vases: Array[Dictionary] = []
var speakers: Array[Node3D] = []
var breakers: Array[Node3D] = []
var gallery_lights: Array[Light3D] = []
var power_on: bool = true
var heli: Node3D = null
var heli_rotor: Node3D = null
var heli_light: SpotLight3D = null
var rain: Array[CPUParticles3D] = []
var exam_server: Node3D = null
var _t: float = 0.0
var _mats: Dictionary = {}
var _cine_hidden: Array = []


func _init() -> void:
	name = "LairTower"


## Builds every floor (call once, before or after add_child); the parking deck shows.
func build() -> void:
	for i: int in FLOORS.size():
		var c := Node3D.new()
		c.name = "Floor_" + FLOORS[i].to_pascal_case()
		c.position = Vector3(CELL_X * i, 0.0, 0.0)
		add_child(c)
		cells[FLOORS[i]] = c
	_parking(cells["parking"])
	_warehouse(cells["warehouse"])
	_servers(cells["servers"])
	_mannequins(cells["mannequins"])
	_gallery(cells["gallery"])
	_penthouse(cells["penthouse"])
	_roof(cells["roof"])
	show_floor("parking")


static func floor_of(task: String) -> String:
	return String(TASK_FLOOR.get(task, "parking"))


## Only floor `id` visible; cover_root follows it.
func show_floor(id: String) -> void:
	if not cells.has(id):
		return
	current_floor = id
	for k: Variant in cells.keys():
		(cells[k] as Node3D).visible = String(k) == id
	cover_root = cells[id]
	for r: CPUParticles3D in rain:
		r.emitting = id == "roof"


## A floor-local point in world space.
func world(floor_id: String, local: Vector3) -> Vector3:
	var c: Node3D = cells.get(floor_id, null)
	return c.global_transform * local if c and c.is_inside_tree() else Vector3(CELL_X * FLOORS.find(floor_id), 0.0, 0.0) + local


## The frame of the shown floor (a cinematic staged on it, with drop_set).
func room_xf() -> Transform3D:
	return floor_xf(current_floor if current_floor != "" else "parking")


func floor_xf(floor_id: String) -> Transform3D:
	var c: Node3D = cells.get(floor_id, null)
	if c and c.is_inside_tree():
		return c.global_transform
	return Transform3D(Basis.IDENTITY, Vector3(CELL_X * maxi(0, FLOORS.find(floor_id)), 0.0, 0.0))


## The frame a cinematic slot is staged in (its floor, moved by SLOT_OFFSET), else the shown floor.
func cine_xf(slot: String) -> Transform3D:
	var xf: Transform3D = floor_xf(String(SLOT_FLOOR[slot])) if SLOT_FLOOR.has(slot) else room_xf()
	return xf.translated_local(SLOT_OFFSET.get(slot, Vector3.ZERO))


## The Day 7 timelines drop their carried sets here (drop_set) but bring what they animate themselves: while `slot` plays
## (on), the real pieces it replaces hide; off shows them again. seg_d7_phase2: the two plinths (and their vases) under its
## own; seg_d7_finisher: the hovering helicopter, its searchlight and the rain (the timeline flies its own on the cinematic
## clock: the paused tree would freeze these mid-air).
func hide_for_cine(on: bool, slot: String = "") -> void:
	if not on:
		for e: Array in _cine_hidden:
			if is_instance_valid(e[0]):
				(e[0] as Node3D).visible = bool(e[1])
				if e[0] is CPUParticles3D:
					(e[0] as CPUParticles3D).emitting = bool(e[2])
		_cine_hidden.clear()
		return
	var hide: Array[Node3D] = []
	for q: Vector2 in CINE_PLINTHS.get(slot, []):
		for v: Dictionary in vases:
			var at: Vector3 = v["at"]
			if Vector2(at.x, at.z).distance_to(q) < 0.1:
				hide.append(v["plinth"])
	if slot == "seg_d7_finisher":
		for n: Node3D in [heli, heli_light]:
			if n:
				hide.append(n)
		for r: CPUParticles3D in rain:
			hide.append(r)
	for n2: Node3D in hide:
		_cine_hidden.append([n2, n2.visible, (n2 as CPUParticles3D).emitting if n2 is CPUParticles3D else false])
		n2.visible = false
		if n2 is CPUParticles3D:
			(n2 as CPUParticles3D).emitting = false


## Hidden by hide_for_cine (tests): [node, was visible, was emitting].
func cine_hidden() -> Array:
	return _cine_hidden


## The vase gallery as a cinematic's carried set (XEM LẠI PHIM; the tower drops it and shows the real hall): the shell, the
## twelve plinths with their vases (plinth_<i>, vase seed i as _gallery builds them), the wall speakers, the breakers and
## the sign, for a stage whose origin sits at `origin` in the hall's frame. Plinths at the hall positions in `skip`
## (Vector2 x, z: the timeline brings its own there) and pieces off the 28 x 24 stage spot are left out.
## [[id, kind, stage pos, yaw deg, opts], ...]; the caller marks them "set".
static func cine_gallery_set(origin: Vector3 = Vector3.ZERO, skip: Array = []) -> Array:
	var out: Array = [["hall", "gallery_hall", origin, 0.0, {"width": GA_W, "depth": GA_D, "height": GA_H}]]
	var i: int = 0
	for z: float in PLINTH_ZS:
		for x: float in PLINTH_XS:
			if not skip.has(Vector2(x, z)):
				out.append(["plinth_%d" % i, "plinth", origin + Vector3(x, 0.0, z), 0.0, {"vase": i}])
			i += 1
	var walls: Array = []
	for s: Array in SPEAKERS:
		walls.append(["speaker", s, {}])
	for b: Array in BREAKERS:
		walls.append(["breaker", b, {"on": false}])
	for w: Array in walls:
		var at: Vector3 = origin + ((w[1] as Array)[0] as Vector3)
		if absf(at.x) < GA_W * 0.5 - 0.05 and absf(at.z) < GA_D * 0.5 - 0.05:
			out.append(["%s_%d" % [String(w[0]), out.size()], String(w[0]), at, rad_to_deg(float((w[1] as Array)[1])), w[2]])
	out.append(["sign", "academy_sign", origin + Vector3(0.0, 3.4, -GA_D * 0.5 + 0.15), 0.0, {"width": 7.0}])
	return out


## The gallery's gold lights on / off (the blackout of phase 2).
func set_power(on: bool) -> void:
	power_on = on
	for l: Light3D in gallery_lights:
		l.visible = on


func tick(delta: float) -> void:
	if current_floor != "roof" or heli == null:
		return
	_t += delta
	if heli_rotor:
		heli_rotor.rotation.y = fmod(heli_rotor.rotation.y + delta * 18.0, TAU)
	if heli_light:
		var c: Node3D = cells["roof"]
		var aim: Vector3 = c.global_transform * Vector3(sin(_t * TAU / SWEEP_S) * SWEEP_M, 0.0, cos(_t * TAU / (SWEEP_S * 1.7)) * SWEEP_M * 0.5)
		var from: Vector3 = heli_light.global_position
		if from.distance_squared_to(aim) > 0.01:
			heli_light.look_at(aim, Vector3.FORWARD)
	heli.position.y = HELI_AT.y + sin(_t * 1.3) * 0.25


# ---------------------------------------------------------------------------
# Mission points (world space)
# ---------------------------------------------------------------------------
func mission_points(task: String) -> Dictionary:
	var f: String = floor_of(task)
	var d: Dictionary = {"centre": world(f, Vector3.ZERO), "leash": 60.0, "floor": f}
	match task:
		"parking":
			var p0: Vector2 = ring_point(0.0)
			d["start"] = world(f, Vector3(p0.x, 0.0, p0.y))
			d["start_yaw"] = PI                    # along +z (the ring's travel direction at angle 0)
			d["route"] = route(16)
			d["leash"] = 90.0
		"warehouse":
			d["start"] = world(f, Vector3(0.0, 0.0, 13.0))
			d["start_yaw"] = 0.0
			d["boss_at"] = world(f, Vector3(0.0, 0.0, -8.0))
			d["boss_yaw"] = PI
			d["fork_at"] = world(f, Vector3(-7.0, 0.0, 10.0))
			d["fork_yaw"] = 0.0
			d["ammo"] = [world(f, Vector3(-15.0, 0.0, 12.0)), world(f, Vector3(15.0, 0.0, 12.0))]
			d["leash"] = 40.0
		"servers":
			d["start"] = world(f, Vector3(0.0, 0.0, 6.0))
			d["start_yaw"] = 0.0
			d["boss_at"] = world(f, Vector3(0.0, 0.0, -3.0))
			d["boss_yaw"] = PI
		"mannequins":
			d["start"] = world(f, Vector3(0.0, 0.0, 25.5))
			d["start_yaw"] = 0.0
			d["goal"] = world(f, Vector3(0.0, 0.0, -25.0))
			d["goal_r"] = 2.4
			var pats: Array = []
			for pr: Array in MN_PATROLS:
				var r: Array = []
				for q: Variant in pr[1]:
					r.append(world(f, q))
				pats.append([world(f, pr[0]), r])
			d["patrols"] = pats
		"lasers":
			d["start"] = world(f, Vector3(0.0, 0.0, CORR_Z1 - 1.5))
			d["start_yaw"] = 0.0
			d["goal"] = world(f, Vector3(0.0, 0.0, CORR_Z0 + 0.8))
			d["goal_r"] = 2.0
			d["lasers"] = laser_defs(f)
			d["leash"] = 70.0
		"boss_guns":
			d["start"] = world(f, Vector3(0.0, 0.0, 10.0))
			d["start_yaw"] = 0.0
			d["boss_at"] = world(f, Vector3(0.0, 0.0, -9.0))
			d["waves"] = [[world(f, Vector3(-10.0, 0.0, -8.0)), world(f, Vector3(10.0, 0.0, -8.0)), world(f, Vector3(2.6, 0.0, -10.5))],
				[world(f, Vector3(-6.0, 0.0, -10.5)), world(f, Vector3(6.0, 0.0, -10.5))]]   # T5: beside his desk (no crossfire from the side walls)
			d["ammo"] = [world(f, Vector3(-12.5, 0.0, 9.0)), world(f, Vector3(12.5, 0.0, 9.0)), world(f, Vector3(0.0, 0.0, 3.0))]
			d["leash"] = 30.0
		"boss_dark":
			d["start"] = world(f, Vector3(0.0, 0.0, 9.0))
			d["start_yaw"] = 0.0
			d["boss_at"] = world(f, Vector3(0.0, 0.0, -9.0))
			var br: Array = []
			for b: Array in BREAKERS:
				br.append(world(f, (b[0] as Vector3) * Vector3(1.0, 0.0, 1.0) + Vector3(-signf((b[0] as Vector3).x) * 0.9, 0.0, 0.0)))
			d["breakers"] = br
			d["leash"] = 30.0
		"boss_saber":
			d["start"] = world(f, Vector3(0.0, 0.0, 5.0))
			d["start_yaw"] = 0.0
			d["boss_at"] = world(f, Vector3(0.0, 0.0, -2.0))
			d["boss_yaw"] = PI
			d["leash"] = 20.0
		"typing":
			d["spot"] = world(f, EXAM_AT + Vector3(0.0, 0.0, 1.3))
			d["spot_yaw"] = 0.0
	return d


## The parking ring at angle a (radians): Vector2(x, z) floor-local.
static func ring_point(a: float, r: float = RING_R) -> Vector2:
	return Vector2(cos(a) * r, sin(a) * r)


## The ring as world (x, z) points for `laps` laps, every 10 degrees (BikeRoute.from_points).
func route(laps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var o: Vector3 = world("parking", Vector3.ZERO)
	var n: int = 36 * laps
	for i: int in n + 1:
		var p: Vector2 = ring_point(TAU * float(i) / 36.0)
		out.append(Vector2(o.x + p.x, o.z + p.y))
	return out


## The laser corridor (world): [{"a", "b" (ends; a == b in x/z = a vertical beam), "y0", "y1" (heights), "mode" (static |
## blink | sweep), "period", "on" (lit share of a blink period), "phase", "sweep" (offset of a sweep at its extremes)}].
func laser_defs(f: String = "gallery") -> Array:
	var hw: float = CORR_W * 0.5
	# T5b (sim_day7): Thường adds two sweeps (z 37, z 20) and holds the second blink wall longer; Dễ keeps the T1 corridor,
	# its sweeps and blink walls LASER_EASY_SLOW slower, the walls lit LASER_EASY_ON of the time (fix round: never harder)
	var on2: float = float(Difficulty.pick(LASER_BLINK2_ON, LASER_BLINK2_ON_EASY))
	var out: Array = []
	# 1-2: static half-width beams, a zigzag
	out.append({"a": world(f, Vector3(-hw, 0.0, 43.0)), "b": world(f, Vector3(0.7, 0.0, 43.0)), "y0": 0.45, "y1": 0.45, "mode": "static"})
	out.append({"a": world(f, Vector3(-hw, 0.0, 43.0)), "b": world(f, Vector3(0.7, 0.0, 43.0)), "y0": 1.3, "y1": 1.3, "mode": "static"})
	out.append({"a": world(f, Vector3(-0.7, 0.0, 39.0)), "b": world(f, Vector3(hw, 0.0, 39.0)), "y0": 0.45, "y1": 0.45, "mode": "static"})
	out.append({"a": world(f, Vector3(-0.7, 0.0, 39.0)), "b": world(f, Vector3(hw, 0.0, 39.0)), "y0": 1.3, "y1": 1.3, "mode": "static"})
	# 2b (Thường only, T5b): a sweep between the zigzag and the first blinking wall
	if not Difficulty.easy:
		out.append({"a": world(f, Vector3(0.0, 0.0, 37.0)), "b": world(f, Vector3(0.0, 0.0, 37.0)), "y0": 0.0, "y1": CORR_H,
			"mode": "sweep", "period": LASER_EXTRA_SWEEP_S[0], "phase": 0.5, "sweep": Vector3(hw - 0.35, 0.0, 0.0)})
	# 3: a blinking wall (full width, four beams)
	for k: int in 4:
		out.append({"a": world(f, Vector3(-hw, 0.0, 34.0)), "b": world(f, Vector3(hw, 0.0, 34.0)), "y0": 0.3 + 0.5 * k,
			"y1": 0.3 + 0.5 * k, "mode": "blink", "period": 3.2, "on": 0.55, "phase": 0.0})
	# 4: a sweeping vertical beam across the corridor
	out.append({"a": world(f, Vector3(0.0, 0.0, 28.5)), "b": world(f, Vector3(0.0, 0.0, 28.5)), "y0": 0.0, "y1": CORR_H,
		"mode": "sweep", "period": 3.6, "phase": 0.0, "sweep": Vector3(hw - 0.35, 0.0, 0.0)})
	# 5: a static diagonal, then a second blinking wall out of phase
	out.append({"a": world(f, Vector3(-hw, 0.0, 25.0)), "b": world(f, Vector3(hw - 1.6, 0.0, 22.0)), "y0": 0.9, "y1": 0.9, "mode": "static"})
	for k2: int in 4:
		out.append({"a": world(f, Vector3(-hw, 0.0, 18.0)), "b": world(f, Vector3(hw, 0.0, 18.0)), "y0": 0.3 + 0.5 * k2,
			"y1": 0.3 + 0.5 * k2, "mode": "blink", "period": 2.6, "on": on2, "phase": 1.3})
	# 5b (Thường only, T5b): a sweep between the diagonal and the second blinking wall
	if not Difficulty.easy:
		out.append({"a": world(f, Vector3(0.0, 0.0, 20.0)), "b": world(f, Vector3(0.0, 0.0, 20.0)), "y0": 0.0, "y1": CORR_H,
			"mode": "sweep", "period": LASER_EXTRA_SWEEP_S[1], "phase": 1.0, "sweep": Vector3(hw - 0.35, 0.0, 0.0)})
	# 6: two sweeping beams crossing before the hall
	out.append({"a": world(f, Vector3(0.0, 0.0, 15.0)), "b": world(f, Vector3(0.0, 0.0, 15.0)), "y0": 0.0, "y1": CORR_H,
		"mode": "sweep", "period": 4.2, "phase": 0.0, "sweep": Vector3(hw - 0.35, 0.0, 0.0)})
	out.append({"a": world(f, Vector3(0.0, 0.0, 15.0)), "b": world(f, Vector3(0.0, 0.0, 15.0)), "y0": 0.0, "y1": CORR_H,
		"mode": "sweep", "period": 4.2, "phase": 2.1, "sweep": Vector3(hw - 0.35, 0.0, 0.0)})
	if Difficulty.easy:
		for d: Dictionary in out:
			if d.has("period"):
				d["period"] = float(d["period"]) * LASER_EASY_SLOW
				d["phase"] = float(d["phase"]) * LASER_EASY_SLOW
			if d.has("on"):
				d["on"] = LASER_EASY_ON
	return out


# ---------------------------------------------------------------------------
# Build helpers
# ---------------------------------------------------------------------------
func _mat(key: String, col: Color, rough: float = 0.8) -> StandardMaterial3D:
	if not _mats.has(key):
		_mats[key] = CineFX._mat(col, rough)
	return _mats[key]


func _glow(key: String, col: Color, e: float) -> StandardMaterial3D:
	if not _mats.has(key):
		_mats[key] = CineFX._glow_mat(col, e)
	return _mats[key]


## A floor slab (visual + collider) of size (w, d) centred at the cell origin.
func _slab(c: Node3D, w: float, d: float, mat: Material) -> void:
	CineFX._box(c, "Floor", Vector3(w, 0.04, d), Vector3(0.0, 0.0, 0.0), mat)
	_solid(c, Vector3(w + 2.0, 0.4, d + 2.0), Vector3(0.0, -0.2, 0.0))


func _solid(c: Node3D, size: Vector3, at: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.position = at
	body.rotation.y = rot_y
	c.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	return body


## A wall: mesh + collider (size, centre at its middle height).
func _wall(c: Node3D, size: Vector3, at: Vector3, mat: Material, rot_y: float = 0.0) -> void:
	CineFX._box(c, "Wall", size, at, mat, Vector3(0.0, rot_y, 0.0))
	_solid(c, size, at, rot_y)


## Four walls round a w x d room of height h (a gap of `door` metres in the +z wall when door > 0).
func _room(c: Node3D, w: float, d: float, h: float, mat: Material, door: float = 0.0) -> void:
	_wall(c, Vector3(w, h, WALL_T), Vector3(0.0, h * 0.5, -d * 0.5 - WALL_T * 0.5), mat)
	if door > 0.0:
		var side: float = (w - door) * 0.5
		for sx: float in [-1.0, 1.0]:
			_wall(c, Vector3(side, h, WALL_T), Vector3(sx * (door * 0.5 + side * 0.5), h * 0.5, d * 0.5 + WALL_T * 0.5), mat)
	else:
		_wall(c, Vector3(w, h, WALL_T), Vector3(0.0, h * 0.5, d * 0.5 + WALL_T * 0.5), mat)
	for sx2: float in [-1.0, 1.0]:
		_wall(c, Vector3(WALL_T, h, d), Vector3(sx2 * (w * 0.5 + WALL_T * 0.5), h * 0.5, 0.0), mat)


## Low cover (group "cover", CoverMap.scan): a box body standing on the floor at `at`.
func _cover(c: Node3D, size: Vector3, at: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Cover"
	body.add_to_group("cover")
	body.position = at
	c.add_child(body)
	CineFX._box(body, "Box", size, Vector3(0.0, size.y * 0.5, 0.0), mat)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(cs)
	return body


func _omni(c: Node3D, at: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.position = at
	c.add_child(l)
	return l


func _ceiling(c: Node3D, w: float, d: float, h: float) -> void:
	CineFX._box(c, "Ceiling", Vector3(w, 0.2, d), Vector3(0.0, h + 0.1, 0.0), _mat("ceil", Color("#1C1A18"), 0.95))


# ---------------------------------------------------------------------------
# Floors
# ---------------------------------------------------------------------------
func _parking(c: Node3D) -> void:
	var concrete: StandardMaterial3D = _mat("concrete", Color("#55524D"), 0.9)
	_slab(c, 64.0, 64.0, _mat("asphalt", Color("#2E2D2B"), 0.95))
	CineFX._box(c, "Ceiling", Vector3(64.0, 0.3, 64.0), Vector3(0.0, DECK_H + 0.15, 0.0), _mat("deck_ceil", Color("#3B3935"), 0.95))
	# the core (a solid drum with the ramp stripes) and the parapet, as ring segments
	var core: MeshInstance3D = CineFX._cyl(c, "Core", RING_IN - 0.2, RING_IN - 0.2, DECK_H, Vector3(0.0, DECK_H * 0.5, 0.0), concrete)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stripe: StandardMaterial3D = _glow("stripe", Color("#F1C40F"), 0.9)
	var paint: StandardMaterial3D = _mat("lane_paint", Color("#D8D2C4"), 0.7)
	for i: int in RING_SEGS:
		var a: float = TAU * float(i) / float(RING_SEGS)
		var seg_in: float = TAU * RING_IN / float(RING_SEGS) + 0.15
		var seg_out: float = TAU * RING_OUT / float(RING_SEGS) + 0.15
		var pin: Vector2 = ring_point(a, RING_IN)
		var pout: Vector2 = ring_point(a, RING_OUT + 0.3)
		_solid(c, Vector3(0.5, DECK_H, seg_in), Vector3(pin.x, DECK_H * 0.5, pin.y), -a)
		_wall(c, Vector3(0.5, 1.1, seg_out), Vector3(pout.x, 0.55, pout.y), concrete, -a)
		if i % 2 == 0:
			var ps: Vector2 = ring_point(a, RING_IN + 0.05)
			CineFX._box(c, "Stripe", Vector3(0.08, 0.6, 1.2), Vector3(ps.x, 0.6, ps.y), stripe, Vector3(0.0, -a, 0.0))
		var pl: Vector2 = ring_point(a + 0.04, RING_R)
		CineFX._box(c, "Dash", Vector3(0.14, 0.02, 1.6), Vector3(pl.x, 0.03, pl.y), paint, Vector3(0.0, -a, 0.0))
	# corner pillars outside the parapet and sodium lights over the lane
	for q: Vector3 in [Vector3(-29.0, 0.0, -29.0), Vector3(29.0, 0.0, -29.0), Vector3(-29.0, 0.0, 29.0), Vector3(29.0, 0.0, 29.0)]:
		_wall(c, Vector3(1.0, DECK_H, 1.0), q + Vector3(0.0, DECK_H * 0.5, 0.0), concrete)
	for k: int in 8:
		var lp: Vector2 = ring_point(TAU * float(k) / 8.0, RING_R)
		_omni(c, Vector3(lp.x, DECK_H - 0.4, lp.y), Color("#FFB55A"), 1.4, 13.0)
		CineFX._box(c, "Lamp", Vector3(1.2, 0.06, 0.3), Vector3(lp.x, DECK_H - 0.05, lp.y), _glow("sodium", Color("#FFB55A"), 2.5))
	var sign: Node3D = CineFX.build_prop("academy_sign", {"width": 6.0, "text": "LỌ ACADEMY · BÃI XE B3"})
	sign.position = Vector3(0.0, 2.6, RING_IN - 0.1)
	sign.rotation.y = PI
	c.add_child(sign)


func _warehouse(c: Node3D) -> void:
	var wall: StandardMaterial3D = _mat("wh_wall", Color("#4A4F55"), 0.9)
	_slab(c, WH_W, WH_D, _mat("wh_floor", Color("#5C5A55"), 0.85))
	_room(c, WH_W, WH_D, WH_H, wall)
	_ceiling(c, WH_W, WH_D, WH_H)
	var shelf: StandardMaterial3D = _mat("shelf", Color("#2F4F7A"), 0.6)
	var box_mat: StandardMaterial3D = _mat("carton", Color("#B08550"), 0.85)
	for sx: float in [-1.0, 1.0]:
		for k: int in 3:
			var at := Vector3(sx * (WH_W * 0.5 - 1.0), 0.0, -10.0 + 10.0 * k)
			_wall(c, Vector3(1.4, 4.0, 6.0), at + Vector3(0.0, 2.0, 0.0), shelf)
			for lvl: int in 3:
				CineFX._box(c, "Cartons", Vector3(1.2, 0.7, 5.6), at + Vector3(0.0, 0.4 + 1.3 * lvl, 0.0), box_mat)
	var crate: StandardMaterial3D = _mat("crate", Color("#9A7444"), 0.85)
	for cr: Array in WH_CRATES:
		_cover(c, cr[1], cr[0], crate)
	for p: Vector3 in [Vector3(-10.0, 5.6, -8.0), Vector3(10.0, 5.6, -8.0), Vector3(-10.0, 5.6, 8.0), Vector3(10.0, 5.6, 8.0)]:
		_omni(c, p, Color("#FFF1D0"), 1.6, 18.0)
		CineFX._box(c, "Lamp", Vector3(2.0, 0.08, 0.4), p + Vector3(0.0, 0.3, 0.0), _glow("wh_lamp", Color("#FFF1D0"), 2.4))
	var sign: Node3D = CineFX.build_prop("academy_sign", {"width": 6.0, "text": "LỌ ACADEMY · KHO TÀI LIỆU"})
	sign.position = Vector3(0.0, 4.4, -WH_D * 0.5 + 0.15)
	c.add_child(sign)


func _servers(c: Node3D) -> void:
	var wall: StandardMaterial3D = _mat("sv_wall", Color("#2A2E35"), 0.9)
	_slab(c, SV_W, SV_D, _mat("sv_floor", Color("#3E444B"), 0.6))
	_room(c, SV_W, SV_D, SV_H, wall)
	_ceiling(c, SV_W, SV_D, SV_H)
	for sx: float in [-1.0, 1.0]:
		for k: int in 6:
			var r: Node3D = CineFX.build_prop("server_rack", {"seed": k + (1 if sx > 0.0 else 0)})
			r.position = Vector3(sx * (SV_W * 0.5 - 1.2), 0.0, -8.0 + 3.2 * k)
			r.rotation.y = deg_to_rad(-90.0 * sx)
			c.add_child(r)
			_solid(c, Vector3(1.0, 2.0, 0.6), r.position + Vector3(0.0, 1.0, 0.0), r.rotation.y)
	var strip: StandardMaterial3D = _glow("sv_strip", Color("#3BA7FF"), 1.8)
	for sx2: float in [-1.0, 1.0]:
		CineFX._box(c, "Strip", Vector3(0.05, 0.05, SV_D - 1.0), Vector3(sx2 * 6.0, 0.03, 0.0), strip)
	_omni(c, Vector3(0.0, 3.2, 0.0), Color("#8FB4FF"), 1.5, 16.0)
	_omni(c, Vector3(0.0, 3.2, -7.0), Color("#C9A0FF"), 0.9, 10.0)
	var sign: Node3D = CineFX.build_prop("academy_sign", {"width": 5.0, "text": "LỌ ACADEMY · PHÒNG MÁY"})
	sign.position = Vector3(0.0, 2.6, -SV_D * 0.5 + 0.15)
	c.add_child(sign)


func _mannequins(c: Node3D) -> void:
	var wall: StandardMaterial3D = _mat("mn_wall", Color("#E7E1D6"), 0.8)
	_slab(c, MN_W, MN_D, _mat("mn_floor", Color("#C9C2B5"), 0.4))
	_room(c, MN_W, MN_D, MN_H, wall)
	_ceiling(c, MN_W, MN_D, MN_H)
	var display: StandardMaterial3D = _mat("display", Color("#262229"), 0.5)
	for w: Array in MN_WALLS:
		var size: Vector3 = w[1]
		_wall(c, size, (w[0] as Vector3) + Vector3(0.0, size.y * 0.5, 0.0), display)
		CineFX._box(c, "Poster", Vector3(size.x - 1.0, 1.2, 0.02), (w[0] as Vector3) + Vector3(0.0, 1.6, size.z * 0.5 + 0.01),
			_glow("poster", Color("#FFD27A"), 0.6))
	for g: Vector3 in MN_GROUPS:
		var m: Node3D = CineFX.build_prop("mannequins", {"cols": 3, "rows": 2, "dx": 0.75, "dz": 0.7})
		m.position = g
		c.add_child(m)
		CineFX._box(c, "Riser", Vector3(2.6, 0.12, 1.8), g + Vector3(0.75, 0.06, 0.35), _mat("riser", Color("#F4F0E8"), 0.5))
	# the lift at the far end (the goal)
	CineFX._box(c, "LiftDoor", Vector3(2.4, 2.6, 0.08), Vector3(0.0, 1.3, -MN_D * 0.5 + 0.05), _mat("lift", Color("#B8BEC6"), 0.25))
	CineFX._box(c, "LiftSign", Vector3(0.8, 0.25, 0.04), Vector3(0.0, 2.9, -MN_D * 0.5 + 0.06), _glow("lift_sign", Color("#29C46A"), 2.0))
	for z: float in [20.0, 8.0, -4.0, -16.0]:
		_omni(c, Vector3(0.0, 3.6, z), Color("#FFF6E8"), 0.9, 11.0)


func _gallery(c: Node3D) -> void:
	var wall: StandardMaterial3D = _mat("ga_wall", Color("#16120F"), 0.7)
	var gold: StandardMaterial3D = _mat("ga_gold", Color("#B8892E"), 0.35)
	gold.metallic = 0.7
	# the hall (door gap toward the corridor in its +z wall)
	_slab(c, GA_W, GA_D, _mat("ga_floor", Color("#2A211A"), 0.25))
	_room(c, GA_W, GA_D, GA_H, wall, CORR_W)
	_ceiling(c, GA_W, GA_D, GA_H)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(c, "Trim", Vector3(0.05, 0.12, GA_D), Vector3(sx * (GA_W * 0.5 - 0.03), 3.0, 0.0), gold)
	# the corridor (lasers): floor, walls, ceiling
	var cl: float = CORR_Z1 - CORR_Z0
	var cz: float = (CORR_Z0 + CORR_Z1) * 0.5
	CineFX._box(c, "CorrFloor", Vector3(CORR_W, 0.04, cl), Vector3(0.0, 0.0, cz), _mat("corr_floor", Color("#151417"), 0.2))
	_solid(c, Vector3(CORR_W + 2.0, 0.4, cl + 2.0), Vector3(0.0, -0.2, cz))
	for sx2: float in [-1.0, 1.0]:
		_wall(c, Vector3(WALL_T, CORR_H, cl), Vector3(sx2 * (CORR_W * 0.5 + WALL_T * 0.5), CORR_H * 0.5, cz), wall)
		CineFX._box(c, "CorrStrip", Vector3(0.04, 0.04, cl), Vector3(sx2 * (CORR_W * 0.5 - 0.03), 0.08, cz), _glow("corr_strip", Color("#FF2030"), 1.2))
	_wall(c, Vector3(CORR_W, CORR_H, WALL_T), Vector3(0.0, CORR_H * 0.5, CORR_Z1 + WALL_T * 0.5), wall)
	CineFX._box(c, "CorrCeiling", Vector3(CORR_W, 0.2, cl), Vector3(0.0, CORR_H + 0.1, cz), _mat("ceil", Color("#1C1A18"), 0.95))
	_omni(c, Vector3(0.0, 2.8, 40.0), Color("#FF6070"), 0.6, 10.0)
	_omni(c, Vector3(0.0, 2.8, 24.0), Color("#FF6070"), 0.6, 10.0)
	# plinths with vases (low cover)
	var i: int = 0
	for z: float in PLINTH_ZS:
		for x: float in PLINTH_XS:
			var at := Vector3(x, 0.0, z)
			var body: StaticBody3D = _cover(c, Vector3(0.74, CinePropsD7.PLINTH_H, 0.74), at, _mat("plinth_col", Color("#1B1714"), 0.35))
			(body.get_node("Box") as MeshInstance3D).visible = false
			var pl: Node3D = CineFX.build_prop("plinth")
			body.add_child(pl)
			var v: Node3D = CineFX.build_prop("vase", {"seed": i, "h": 0.5 + 0.08 * float(i % 3)})
			v.position = Vector3(0.0, CinePropsD7.PLINTH_H, 0.0)
			body.add_child(v)
			vases.append({"node": v, "plinth": body, "at": at, "i": i})
			i += 1
	# speakers, breakers, the sign
	for s: Array in SPEAKERS:
		var sp: Node3D = CineFX.build_prop("speaker")
		sp.position = s[0]
		sp.rotation.y = float(s[1])
		c.add_child(sp)
		speakers.append(sp)
	for b: Array in BREAKERS:
		var bk: Node3D = CineFX.build_prop("breaker", {"on": false})
		bk.position = b[0]
		bk.rotation.y = float(b[1])
		c.add_child(bk)
		breakers.append(bk)
	var sign: Node3D = CineFX.build_prop("academy_sign", {"width": 7.0})
	sign.position = Vector3(0.0, 3.4, -GA_D * 0.5 + 0.15)
	c.add_child(sign)
	_wall(c, Vector3(3.0, 0.8, 1.2), Vector3(0.0, 0.4, -10.4), gold)
	# gold lights (the mains of the blackout) and a dim red floor glow that stays
	for p: Vector3 in GA_LIGHTS:
		gallery_lights.append(_omni(c, p, Color("#FFD68A"), 1.8, 14.0))
	for p2: Vector3 in [Vector3(-6.0, 4.5, 0.0), Vector3(6.0, 4.5, 0.0)]:
		CineFX._box(c, "Chandelier", Vector3(1.6, 0.3, 1.6), p2, _glow("chandelier", Color("#FFE2A0"), 1.6))
	_omni(c, Vector3(0.0, 0.6, 0.0), Color("#8A2030"), 0.25, 18.0)


func _penthouse(c: Node3D) -> void:
	var wall: StandardMaterial3D = _mat("ph_wall", Color("#201A14"), 0.6)
	_slab(c, PH_W, PH_D, _mat("ph_floor", Color("#3A2C20"), 0.3))
	_room(c, PH_W, PH_D, PH_H, wall)
	_ceiling(c, PH_W, PH_D, PH_H)
	exam_server = CineFX.build_prop("exam_server")
	exam_server.position = EXAM_AT
	c.add_child(exam_server)
	_solid(c, Vector3(1.1, 2.1, 0.8), EXAM_AT + Vector3(0.0, 1.05, 0.0))
	var desk: Node3D = CineFX.build_prop("desk")
	desk.position = EXAM_AT + Vector3(0.0, 0.0, 0.55)
	c.add_child(desk)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(c, "Window", Vector3(0.04, 2.4, PH_D - 2.0), Vector3(sx * (PH_W * 0.5 - 0.02), 1.6, 0.0), _glow("dawn_window", Color("#F2A86B"), 0.7))
	_omni(c, Vector3(0.0, 3.2, 0.0), Color("#FFD68A"), 1.4, 14.0)
	_omni(c, EXAM_AT + Vector3(0.0, 1.5, 1.2), Color("#3B7BFF"), 1.0, 5.0)


func _roof(c: Node3D) -> void:
	var concrete: StandardMaterial3D = _mat("roof", Color("#3A3C40"), 0.15)
	concrete.metallic_specular = 0.9   # wet
	_slab(c, RF_HALF * 2.0, RF_HALF * 2.0, concrete)
	var pad: StandardMaterial3D = _mat("pad", Color("#E8E2D0"), 0.4)
	var ring := MeshInstance3D.new()
	ring.name = "HelipadRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 5.6
	tm.outer_radius = 6.0
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = pad
	ring.scale = Vector3(1.0, 0.02, 1.0)
	ring.position = Vector3(0.0, 0.03, 0.0)
	c.add_child(ring)
	CineFX._box(c, "H1", Vector3(0.5, 0.02, 3.6), Vector3(-1.1, 0.03, 0.0), pad)
	CineFX._box(c, "H2", Vector3(0.5, 0.02, 3.6), Vector3(1.1, 0.03, 0.0), pad)
	CineFX._box(c, "H3", Vector3(1.7, 0.02, 0.5), Vector3(0.0, 0.03, 0.0), pad)
	var parapet: StandardMaterial3D = _mat("parapet", Color("#2B2D31"), 0.4)
	for sx: float in [-1.0, 1.0]:
		_wall(c, Vector3(RF_HALF * 2.0, 1.1, 0.4), Vector3(0.0, 0.55, sx * (RF_HALF + 0.2)), parapet)
		_wall(c, Vector3(0.4, 1.1, RF_HALF * 2.0), Vector3(sx * (RF_HALF + 0.2), 0.55, 0.0), parapet)
		CineFX._box(c, "Beacon", Vector3(0.2, 0.2, 0.2), Vector3(sx * RF_HALF, 1.3, -RF_HALF), _glow("beacon", Color("#FF2A2A"), 3.0))
	for q: Vector3 in [Vector3(-11.0, 0.0, 10.0), Vector3(11.0, 0.0, -10.0), Vector3(11.0, 0.0, 9.0)]:
		_wall(c, Vector3(2.4, 1.6, 1.6), q + Vector3(0.0, 0.8, 0.0), _mat("ac", Color("#9AA0A8"), 0.5))
	# the helicopter and its searchlight
	heli = CineFX.build_prop("helicopter")
	heli.position = HELI_AT
	heli.rotation.y = PI
	c.add_child(heli)
	heli_rotor = heli.get_node_or_null("Rotor") as Node3D
	heli_light = SpotLight3D.new()
	heli_light.name = "HeliLight"
	heli_light.light_color = Color(1.0, 0.97, 0.88)
	heli_light.light_energy = 9.0
	heli_light.spot_range = 24.0
	heli_light.spot_angle = 14.0
	heli_light.spot_attenuation = 0.6
	heli_light.shadow_enabled = true
	c.add_child(heli_light)
	heli_light.position = HELI_AT + Vector3(0.0, -1.1, 1.5)
	heli_light.rotation = Vector3(-PI * 0.4, 0.0, 0.0)
	_omni(c, Vector3(0.0, 6.0, 6.0), Color("#6B7FA8"), 0.7, 26.0)
	# the city far below (lit windows) and the rain
	var win: StandardMaterial3D = _glow("city", Color("#FFC27A"), 0.9)
	var tower: StandardMaterial3D = _mat("city_tower", Color("#0E1014"), 0.8)
	for k: int in 18:
		var a: float = TAU * float(k) / 18.0 + 0.2
		var dist: float = 70.0 + 30.0 * float(k % 3)
		var h: float = 30.0 + 12.0 * float((k * 7) % 4)
		var at := Vector3(cos(a) * dist, -60.0 + h * 0.5, sin(a) * dist)
		CineFX._box(c, "City", Vector3(14.0, h, 14.0), at, tower)
		CineFX._box(c, "CityWin", Vector3(14.2, h * 0.7, 2.0), at + Vector3(0.0, 0.0, 0.0), win)
	for k2: int in 2:
		var e := CPUParticles3D.new()
		e.name = "Rain"
		e.emitting = false
		e.amount = 260
		e.lifetime = 0.9
		e.local_coords = false
		e.direction = Vector3(0.1, -1.0, 0.05)
		e.spread = 4.0
		e.gravity = Vector3(0.0, -14.0, 0.0)
		e.initial_velocity_min = 9.0
		e.initial_velocity_max = 12.0
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		e.emission_box_extents = Vector3(RF_HALF, 0.2, RF_HALF * 0.5)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.02, 0.4)
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color = Color(0.75, 0.85, 1.0, 0.42)
		rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		rm.set_meta("vice_done", true)
		qm.material = rm
		e.mesh = qm
		e.position = Vector3(0.0, 9.0, -RF_HALF * 0.5 + RF_HALF * float(k2))
		c.add_child(e)
		rain.append(e)
