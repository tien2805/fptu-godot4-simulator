# File: res://scripts/story/missions/MissionTowerStealth.gd
# Day 7 floor 4, the mannequin showroom (plan 2026-11-01-w4-day7.md T1 / T3): MissionSneak through LairTower's showroom
# (the tall display walls in a zigzag hide the player, mannequin groups stand between them, three guards patrol; the goal
# is the lift at the far end). Unseen = done {"spotted": false}; seen = every guard alerted, the beat ends at the lift once
# they are down; down = "TOANG!", retry = the patrol again, unalerted. The lift gets a BasementGuide goal arrow.
# points: start (+ start_yaw), goal, goal_r, patrols [[at, route]], centre, leash.
class_name MissionTowerStealth
extends MissionSneak

const T_LIFT: String = "Thang máy"

var guide: BasementGuide = null


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
	radio("Tầng này toàn ma-nơ-canh, guard đứng lẫn trong đó. Đi sau mấy vách trưng bày, target là thang máy cuối phòng.",
		"Lẻn tới thang máy cuối phòng, đừng để bị thấy.", 6.0)
