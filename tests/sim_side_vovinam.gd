# File: res://tests/sim_side_vovinam.gd
# Tuning harness for the free-roam Vovinam street fights (plan 2026-11-03-w5-side.md T5b). Not a regression test: it
# plays the real SideVovinam (a MeleeFight, bare hands, its waves of club students and the master) in FreeRoam with a
# sloppy melee bot, the Q6 standard (plan 2026-10-29-w2-day2.md):
#   - reactions 250-400 ms after a tell (+0.3 s when late, half of the 15 % wrong ones), reads 65 % of the tells;
#   - a light wind-up is answered with the guard (held 0.45 s), a red heavy tell with a dodge-roll; 15 % of the answers are
#     wrong (the guard against a heavy, a dodge or nothing against a light);
#   - between tells it walks to the nearest opponent (3.5 m/s, facing him) and throws light punches in reach every
#     0.35-0.6 s, a heavy now and then (15 %), the finisher on a dazed one 65 % of the time.
# A knockout fails the attempt like in the game; the bot starts the fight again from its spot until it wins (at most
# MAX_TRIES), so the number per seed is the fails before the win.
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_side_vovinam.gd -- normal 1 4 all
#   (difficulty normal | easy, first seed, seeds, fight vo_hem | vo_cau | all)
extends SceneTree

const DT: float = 1.0 / 60.0
const READ_P: float = 0.65
const WRONG_P: float = 0.15
const HEAVY_P: float = 0.15
const FINISH_P: float = 0.65
const WALK: float = 3.5
const MAX_TRIES: int = 8
const TRY_CAP_S: float = 240.0

var diff: String = "normal"
var seed0: int = 1
var seeds: int = 4
var which: String = "all"
var fr: Node
var vo: SideVovinam
var rng := RandomNumberGenerator.new()
var runs: Array[Dictionary] = []
# bot state
var _last_st: Dictionary = {}       # enemy -> its last state
var _plan: Array = []               # [delay left, action, held]
var _atk_t: float = 0.0
var _counts: Dictionary = {}


func _initialize() -> void:
	Engine.max_fps = 0
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 1:
		diff = a[0]
	if a.size() >= 2:
		seed0 = int(a[1])
	if a.size() >= 3:
		seeds = int(a[2])
	if a.size() >= 4:
		which = a[3]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	Difficulty.set_easy(diff == "easy")
	print("--- SIM SIDE VOVINAM (sloppy melee bot, %s, seeds %d..%d) ---" % [diff, seed0, seed0 + seeds - 1])
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	await _frames(30)
	var ids: Array[String] = SideVovinam.ORDER if which == "all" else ([which] as Array[String])
	for fid: String in ids:
		for m: int in seeds:
			await _seed_run(fid, seed0 + m)
	_summary()
	Difficulty.set_easy(false)
	quit(0)


func _seed_run(fid: String, sd: int) -> void:
	rng.seed = sd * 7919 + (1 if diff == "easy" else 0)
	Difficulty.set_easy(diff == "easy")
	var fails: int = 0
	var won: bool = false
	var tries: int = 0
	var notes: Array[String] = []
	var hp_won: float = 0.0
	while tries < MAX_TRIES and not won:
		tries += 1
		var r: Dictionary = await _attempt(fid)
		notes.append("%s %.0fs kos %d hp %.0f" % [String(r["end"]), float(r["t"]), int(r["kos"]), float(r["hp"])])
		if String(r["end"]) == "won":
			won = true
			hp_won = float(r["hp"])
		else:
			fails += 1
	runs.append({"id": fid, "seed": sd, "fails": fails, "won": won, "hp": hp_won})
	print("  %s %s seed %d: %s after %d fails (attempts: %s)" % [fid, diff, sd, "won" if won else "NOT WON", fails, ", ".join(PackedStringArray(notes))])


func _attempt(fid: String) -> Dictionary:
	_last_st.clear()
	_plan.clear()
	_atk_t = 0.0
	_counts = {"tells": 0, "read": 0, "blocked": 0, "dodged": 0, "hit": 0, "perfect": 0}
	var pl: Node3D = fr.get("player")
	var at: Vector2 = SideVovinam.start_at(fid)
	if pl.has_method("teleport"):
		pl.call("teleport", Vector3(at.x, 0.5, at.y), rng.randf_range(-PI, PI))
	await _frames(20)
	vo = SideVovinam.new()
	fr.add_child(vo)
	vo.setup({"roam": fr, "id": fid})
	vo.auto_tick = false
	var end: Array = [""]
	vo.finished.connect(func(_i: String, _r: Dictionary) -> void: end[0] = "won")
	vo.failed.connect(func(_i: String, why: String) -> void: end[0] = why)
	vo.start()
	var c: PlayerCombat = vo.fight.combat if vo.fight else null
	var n: int = 0
	var hp_prev: float = c.hp if c else 0.0
	while String(end[0]) == "" and n < int(TRY_CAP_S * 60.0):
		await _frames(1)
		n += 1
		vo.advance(DT)
		if c == null or not is_instance_valid(c):
			break
		if c.hp < hp_prev - 0.01:
			_counts["hit"] = int(_counts["hit"]) + 1
		hp_prev = c.hp
		_bot(c)
	var out: Dictionary = {"end": String(end[0]) if String(end[0]) != "" else "stuck", "t": vo.t, "kos": vo.kos,
		"hp": c.hp if c and is_instance_valid(c) else 0.0}
	if OS.has_environment("SIM_VERBOSE"):
		print("    attempt %s: %s in %.0f s, KOs %d/%d, hp %.0f, tells %d (read %d), hits taken %d" % [fid, out["end"], vo.t, vo.kos, vo.total,
			float(out["hp"]), int(_counts["tells"]), int(_counts["read"]), int(_counts["hit"])])
	if c and is_instance_valid(c):
		c.block_override = null
		c.light_override = false
		c.heavy_override = false
		c.finisher_override = false
	vo.stop()
	vo.queue_free()
	vo = null
	await _frames(90)
	return out


func _roll(p: float) -> bool:
	return rng.randf() < p


func _react() -> float:
	var d: float = rng.randf_range(0.25, 0.4)
	if _roll(WRONG_P * 0.5):
		d += 0.3
	return d


func _bot(c: PlayerCombat) -> void:
	var pl: Node3D = fr.get("player")
	var foes: Array = vo.fight.alive() if vo.fight else []
	# the tells: a light wind-up or a red heavy tell entered near the player
	for e0: Variant in foes:
		var e: MeleeEnemy = e0 as MeleeEnemy
		if e == null or not is_instance_valid(e):
			continue
		var was: int = int(_last_st.get(e, -1))
		_last_st[e] = e.st
		if e.st == was or (e.st != MeleeEnemy.St.WINDUP and e.st != MeleeEnemy.St.TELEGRAPH):
			continue
		if StoryMission.flat(e.global_position, pl.global_position) > 4.0:
			continue
		_counts["tells"] = int(_counts["tells"]) + 1
		if not _roll(READ_P) or not _plan.is_empty():
			continue
		_counts["read"] = int(_counts["read"]) + 1
		var heavy: bool = e.st == MeleeEnemy.St.TELEGRAPH
		var act: String = "dodge" if heavy else "block"
		if _roll(WRONG_P):
			act = "block" if heavy else ("dodge" if _roll(0.5) else "none")
		_plan = [_react(), act, 0.0]
	if not _plan.is_empty():
		_plan[0] = float(_plan[0]) - DT
		if float(_plan[0]) <= 0.0:
			match String(_plan[1]):
				"block":
					c.block_override = true
					_plan[2] = float(_plan[2]) + DT
					if float(_plan[2]) > 0.45:
						c.block_override = null
						_plan.clear()
				"dodge":
					c.try_dodge()
					_plan.clear()
				_:
					_plan.clear()
		return
	c.block_override = null
	# the nearest opponent: walk up, face him, punch in reach
	var best: MeleeEnemy = null
	var bd: float = INF
	for e1: Variant in foes:
		var e2: MeleeEnemy = e1 as MeleeEnemy
		if e2 == null or not is_instance_valid(e2) or e2.is_down():
			continue
		var d: float = StoryMission.flat(e2.global_position, pl.global_position)
		if d < bd:
			bd = d
			best = e2
	if best == null:
		return
	var to := Vector3(best.global_position.x - pl.global_position.x, 0.0, best.global_position.z - pl.global_position.z)
	if c.state == PlayerCombat.St.IDLE and pl.has_method("teleport"):
		var step: float = minf(WALK * DT, maxf(bd - 1.4, 0.0))
		pl.call("teleport", pl.global_position + to.normalized() * step, StoryMission.yaw_of(to))
	_atk_t -= DT
	if _atk_t <= 0.0 and bd <= 2.2:
		_atk_t = rng.randf_range(0.35, 0.6)
		if best.is_dazed() and _roll(FINISH_P):
			c.finisher_override = true
		elif _roll(HEAVY_P):
			c.heavy_override = true
		else:
			c.light_override = true


func _summary() -> void:
	for fid: String in SideVovinam.ORDER:
		var per: Array[int] = []
		var won: int = 0
		var hp: Array[int] = []
		for r: Dictionary in runs:
			if String(r["id"]) != fid:
				continue
			per.append(int(r["fails"]))
			won += 1 if bool(r["won"]) else 0
			hp.append(int(round(float(r["hp"]))))
		if per.is_empty():
			continue
		var mean: float = 0.0
		for p: int in per:
			mean += float(p)
		mean /= float(per.size())
		print("SUMMARY %s %s: %d seeds, %d won, fails %s = %.2f mean, hp left on the win %s" % [fid, diff, per.size(), won, str(per), mean, str(hp)])
