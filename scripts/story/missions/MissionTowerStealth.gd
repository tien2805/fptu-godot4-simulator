# File: res://scripts/story/missions/MissionTowerStealth.gd
# Day 7 floor 4, the mannequin showroom (plan 2026-11-01-w4-day7.md T1 / T3): MissionSneak through LairTower's showroom
# (the tall display walls in a zigzag hide the player, mannequin groups stand between them, three guards patrol; the goal
# is the lift at the far end). Unseen = done {"spotted": false}; seen = every guard alerted, the beat ends at the lift once
# they are down; down = "TOANG!", retry = the patrol again, unalerted. The lift gets a BasementGuide goal arrow.
# w5-day7 T1, the readability cuts (D7Beat, once per attempt, never once seen): the first guard's patrol at the start, the
# second guard when the player reaches the first gap (floor z < CUT_Z[1]), the third (the long beat by the lift) past the
# middle wall (z < CUT_Z[2]); under the 4 m ceiling: CUT_OPTS.
# points: start (+ start_yaw), goal, goal_r, patrols [[at, route]], centre, leash.
class_name MissionTowerStealth
extends MissionSneak

const T_LIFT: String = "Thang máy"
## Floor-local z the player passes for guard i's cut (guard 0: at the start).
const CUT_Z: Array[float] = [INF, 8.0, -4.0]
const CUT_OPTS: Dictionary = {"up": 1.6, "dist": 7.0}

var guide: BasementGuide = null
var beat_fx: D7Beat = null
## The patrol's guards in route order (this attempt's) and the cuts done this attempt.
var guards: Array[Node3D] = []
var cut_done: Array[bool] = [false, false, false]


func _start() -> void:
	place_player()
	make_fight({"start_alerted": false})
	var wave: Array = []
	var i: int = 0
	for p: Array in pts.get("patrols", []):
		wave.append(guard(i, p[0], p[1], {"sight_m": HorrorStalker.SIGHT, "fov_deg": FOV_DEG, "alerted": false}))
		i += 1
	fight.add_wave(wave)
	fight.spotted.connect(_on_spotted)
	fight.start()
	if pts.has("goal"):
		goal_marker(pts["goal"], float(pts.get("goal_r", 2.5)) * 0.6)
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	guide.watch(fight, 9.0)
	if pts.has("goal"):
		guide.set_goal(pts["goal"], T_LIFT)
	_reset_state()
	beat_fx = D7Beat.new()
	add_child(beat_fx)
	_fresh_cuts()
	radio("Tầng này toàn ma-nơ-canh, guard đứng lẫn trong đó. Đi sau mấy vách trưng bày, target là thang máy cuối phòng.",
		"Lẻn tới thang máy cuối phòng, đừng để bị thấy.", 6.0)


func _fresh_cuts() -> void:
	guards.clear()
	if fight:
		for e: Variant in fight.alive():
			if e is Node3D:
				guards.append(e)
	cut_done = [false, false, false]


## The player's floor-local z (the showroom runs along -z).
func floor_z() -> float:
	if player == null:
		return INF
	var lt: LairTower = level as LairTower
	return (lt.floor_xf("mannequins").affine_inverse() * player.global_position).z if lt else player.global_position.z


func _lair_tick(dt: float) -> void:
	super._lair_tick(dt)
	if state != "running" or spotted or beat_fx == null:
		return
	var z: float = floor_z()
	for i: int in mini(guards.size(), CUT_Z.size()):
		if cut_done[i] or z > CUT_Z[i]:
			continue
		var g: Node3D = guards[i]
		if g == null or not is_instance_valid(g) or not g.is_inside_tree():
			cut_done[i] = true
			continue
		if beat_fx.cut(g, CUT_OPTS):
			cut_done[i] = true
		elif CameraDirector.live() == null:
			cut_done[i] = true                 # no director (a bare test scene): nothing to wait for
		break


func _reset() -> void:
	super._reset()
	_fresh_cuts()
