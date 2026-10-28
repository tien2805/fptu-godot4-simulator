# File: res://tests/sim_drift_race.gd
# Tuning harness for the Day 2 race with Sói Xám (Wave 2 Day 2 rework, plan 2026-10-29-w2-day2.md "Tuning"). Not a
# regression test: it plays the real race (DriftDuel on DriftCourse.rach_ham in FreeRoam at night, props on, intro off)
# with the Q6 SLOPPY BOT on the real bike, lets the race retry by itself after every loss (the grid or the lap 2 grid) and
# counts the fails until the win (a mission), then prints one line per mission and a summary.
# The sloppy bot (master plan Q6):
#   - 250-400 ms reaction delay on every decision (drift, kick, dodge, counter, nitro), the steering follows the line
#     with a 0.1 s lag and a slow lateral wander (it is never exactly on the line);
#   - 15 % of its decisions are wrong or late (the wrong kick side, a drift held too long or not at all, +0.3 s);
#   - it reads Sói Xám's telegraph only READ_P of the time (then dodges or counters, else it eats the kick);
#   - it drifts most corners but not all; nitro when it remembers to.
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_drift_race.gd -- normal 1 4
#   (difficulty normal | easy, first seed, missions)
extends SceneTree

const MAX_FAILS: int = 6
const READ_P: float = 0.65
const WRONG_P: float = 0.15
const DRIFT_P: float = 0.8
const KICK_P: float = 0.75
const NITRO_P: float = 0.7

var diff: String = "normal"
var seed0: int = 1
var missions: int = 4
var fr: Node
var bike: PlayerBike
var duel: DriftDuel
var course: DriftCourse
var rng := RandomNumberGenerator.new()
var results: Array[Dictionary] = []
# bot state
var _pending: Array = []                 # [fire at (game s), action, arg]
var _t: float = 0.0
var _wander_ph: float = 0.0
var _corner_seen: int = -1
var _corner_drift: bool = false
var _drift_until: float = -1.0
var _windup_seen: int = -1
var _kick_ready_t: float = -1.0
var _nitro_hold: int = 0
var _dodge_until: float = -1.0
var _dodge_side: float = 0.0
var _nitro_armed: bool = false
var _steer_hist := PackedFloat32Array()


func _initialize() -> void:
	Engine.max_fps = 0
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 1:
		diff = a[0]
	if a.size() >= 2:
		seed0 = int(a[1])
	if a.size() >= 3:
		missions = int(a[2])
	PlayerBike.sfx_dir = OS.get_cache_dir().replace("\\", "/").trim_suffix("/") + "/fptu_sim_race_no_sfx/"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	Difficulty.set_easy(diff == "easy")      # after GameFX loaded the owner's setting (it calls set_easy too)
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	await _frames(30)
	if fr.has_method("set_time_of_day"):
		fr.call("set_time_of_day", "night")
	bike = fr.get("bike")
	course = DriftCourse.rach_ham()
	for m: int in missions:
		await _mission(seed0 + m)
	_summary()
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro"]:
		Input.action_release(a)
	Difficulty.set_easy(false)
	quit(0)


func _mission(sd: int) -> void:
	rng.seed = sd * 7919 + (1 if diff == "easy" else 0)
	Difficulty.set_easy(diff == "easy")
	duel = DriftDuel.new()
	duel.name = "SimDuel"
	fr.add_child(duel)
	duel.setup({"roam": fr, "intro": false, "seed": 3131 + sd})
	var res: Dictionary = {"seed": sd, "fails": 0, "causes": [], "won": false, "race_s": 0.0}
	duel.lost.connect(func(r: String) -> void:
		res["fails"] = int(res["fails"]) + 1
		(res["causes"] as Array).append("%s@%s" % [r, "L2" if duel.lap2_reached else "L1"]))
	duel.won.connect(func(_h: String) -> void: res["won"] = true)
	duel.start()
	var n: int = 0
	var stab_min: float = 100.0
	_reset_bot()
	var game_t: float = 0.0
	while not bool(res["won"]) and int(res["fails"]) < MAX_FAILS and n < 60 * 60 * 12:
		if duel.state == "racing":
			_bot(1.0 / 60.0)
			stab_min = minf(stab_min, duel.combat.stability)
		else:
			_release()
			_reset_bot()
		await _frames(1)
		game_t += 1.0 / 60.0
		n += 1
		if OS.has_environment("RACE_TRACE") and n % 60 == 0 and duel.state == "racing":
			print("    t %.0f s_p %.0f d %.1f v %.1f gap %.0f band %.2f lap %d gate %d/%d rival s %.0f v %.1f st %.0f" % [duel.race_t, duel.s_p, duel.d_p, bike.current_speed_ms,
				duel.gap(), duel.rival.band, duel.lap, duel.gate_i, course.gates.size(), duel.rival.s, duel.rival.v, duel.combat.stability])
	_release()
	res["race_s"] = snappedf(duel.race_t, 0.1)
	res["game_s"] = snappedf(game_t, 0.1)
	res["his_kicks"] = "%d/%d" % [duel.rival.kick_hits, duel.rival.kicks]
	res["my_kicks"] = duel.rival.hits_total
	res["wobbles"] = duel.rival.wobbles
	res["corners"] = duel.corner_bonuses
	res["resets"] = duel.resets
	res["stab_min"] = int(stab_min)
	res["lead_s"] = snappedf(duel.lead_t, 0.1)
	res["gap"] = "%d..%d" % [int(duel.min_gap), int(duel.max_gap)]
	results.append(res)
	print("  MISSION %s seed %d: %s after %d fails %s; last race %.1f s (all %.0f s), his kicks %s, my kicks %d, wobbles %d, corner bonuses %d, resets %d, min stability %d, lead %.1f s, gap %s" % [
		diff, sd, "WON" if bool(res["won"]) else "GAVE UP", int(res["fails"]), str(res["causes"]), float(res["race_s"]), float(res["game_s"]),
		res["his_kicks"], int(res["my_kicks"]), int(res["wobbles"]), int(res["corners"]), int(res["resets"]), int(res["stab_min"]),
		float(res["lead_s"]), res["gap"]])
	duel.stop()
	duel.queue_free()
	await _frames(3)


func _reset_bot() -> void:
	_pending.clear()
	_corner_seen = -1
	_corner_drift = false
	_drift_until = -1.0
	_windup_seen = -1
	_kick_ready_t = -1.0
	_nitro_hold = 0
	_dodge_until = -1.0
	_nitro_armed = false
	_wander_ph = rng.randf_range(0.0, TAU)


func _release() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro"]:
		Input.action_release(a)


func _delay() -> float:
	var d: float = rng.randf_range(0.25, 0.4)
	if rng.randf() < WRONG_P * 0.5:
		d += 0.3                              # late
	return d


func _later(action: String, arg: Variant = null) -> void:
	_pending.append([_t + _delay(), action, arg])


func _bot(dt: float) -> void:
	_t += dt
	var r: DriftRival = duel.rival
	var s: float = duel.s_p
	var v: float = bike.current_speed_ms
	# ---- steering: the line ahead, a slow wander, a dodge offset, 0.15 s of lag ----
	var wander: float = sin(_t * 0.5 + _wander_ph) * 0.6 + sin(_t * 1.3 + _wander_ph * 2.0) * 0.3
	var dodge: float = _dodge_side * 2.5 if _t < _dodge_until else 0.0
	var look: float = clampf(v * 0.45, 4.0, 12.0)
	var tgt: Vector2 = course.world(s + look, clampf(wander + dodge, -course.half_width_at(s + look) + 1.0, course.half_width_at(s + look) - 1.0))
	var bp := Vector2(bike.global_position.x, bike.global_position.z)
	var z: Vector3 = bike.global_transform.basis.z
	var f := Vector2(-z.x, -z.z).normalized()
	var to: Vector2 = (tgt - bp).normalized()
	var ang: float = atan2(f.x * to.y - f.y * to.x, f.dot(to))
	_steer_hist.append(clampf(ang * 2.4, -1.0, 1.0))
	var st: float = _steer_hist[0] if _steer_hist.size() >= 6 else 0.0
	if _steer_hist.size() > 6:
		_steer_hist.remove_at(0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if st < -0.02:
		Input.action_press("steer_left", -st)
	elif st > 0.02:
		Input.action_press("steer_right", st)
	# ---- corners: decide on the way in (delayed), drift through or brake ----
	var ci: int = course.corner_at(s + v * 0.5)
	if ci >= 0 and ci != _corner_seen:
		_corner_seen = ci
		var will: bool = rng.randf() < DRIFT_P
		if rng.randf() < WRONG_P:
			will = not will                   # wrong: no drift where it would, or a drift held into the exit
		_corner_drift = will
		if will:
			_later("drift_on", float(course.corners[ci][1]) + (8.0 if rng.randf() < WRONG_P else 0.0))
	# the bike turns a 12.6 m circle at any speed above 7 m/s (8.4 m drifting), tighter only below it: a corner it cannot
	# drift is taken at the rival's pace when wide enough, else crawled
	var rr: float = minf(course.radius_at(s + 6.0), course.radius_at(s + 12.0))
	var vt: float = 40.0
	if rr < 30.0:
		if _corner_drift:
			vt = course.speed_at(s + 8.0) * 1.1
		else:
			vt = course.speed_at(s + 8.0) if rr >= 13.0 else 5.0
	Input.action_release("gas")
	Input.action_release("brake")
	if v < vt - 0.3:
		Input.action_press("gas")
	elif v > vt + 1.5:
		Input.action_press("brake", clampf((v - vt) / 6.0, 0.2, 1.0))
	if _drift_until > 0.0 and s < _drift_until and v > 8.0 and absf(ang) > 0.03:
		Input.action_press("drift")
	else:
		Input.action_release("drift")
	# ---- Sói Xám's telegraph: read it (READ_P) and dodge or counter, delayed ----
	if r.mode == "windup" and _windup_seen != r.kicks:
		_windup_seen = r.kicks
		if rng.randf() < READ_P:
			_later("dodge" if rng.randf() < 0.5 else "counter", -r.kick_side)
	# ---- kicks: him in reach -> a kick after the delay (sometimes the wrong side) ----
	var rel_s: float = r.s - s
	var rel_d: float = r.d - duel.d_p
	if absf(rel_s) < 1.6 and absf(rel_d) > 0.6 and absf(rel_d) < 2.6 and r.kickable():
		if _kick_ready_t < 0.0 and rng.randf() < KICK_P * dt * 4.0:
			_kick_ready_t = _t
			_later("kick", 1.0 if rel_d > 0.0 else -1.0)
	else:
		_kick_ready_t = -1.0
	# ---- nitro: a long straight with enough charge ----
	if _nitro_hold > 0:
		_nitro_hold -= 1
		if _nitro_hold == 0:
			Input.action_release("nitro")
	elif not _nitro_armed and bike.drift_charge >= PlayerBike.NITRO_MIN and course.radius_at(s + 25.0) > 150.0 and course.radius_at(s + 50.0) > 150.0 and not bike.nitro_active():
		_nitro_armed = true
		if rng.randf() < NITRO_P:
			_later("nitro")
	if course.radius_at(s + 25.0) < 150.0:
		_nitro_armed = false
	# ---- the delayed actions ----
	var i: int = 0
	while i < _pending.size():
		var e: Array = _pending[i]
		if _t < float(e[0]):
			i += 1
			continue
		_pending.remove_at(i)
		match String(e[1]):
			"drift_on":
				_drift_until = float(e[2])
			"kick":
				var side: float = float(e[2])
				if rng.randf() < WRONG_P:
					side = -side
				duel.combat.kick(int(side))
			"counter":
				var cs: float = float(e[2]) * -1.0       # toward him (he is on the -kick_side of the player... his side)
				var rd: float = r.d - duel.d_p
				cs = 1.0 if rd > 0.0 else -1.0
				if rng.randf() < WRONG_P:
					cs = -cs
				duel.combat.kick(int(cs))
			"dodge":
				var rd2: float = r.d - duel.d_p
				_dodge_side = -1.0 if rd2 > 0.0 else 1.0
				if rng.randf() < WRONG_P:
					_dodge_side = -_dodge_side
				_dodge_until = _t + 0.7
			"nitro":
				Input.action_press("nitro")
				_nitro_hold = 3


func _summary() -> void:
	var fails: Array[int] = []
	var won: int = 0
	var ok: int = 0
	for r: Dictionary in results:
		fails.append(int(r["fails"]))
		if bool(r["won"]):
			won += 1
		var f: int = int(r["fails"])
		if diff == "easy":
			ok += 1 if (bool(r["won"]) and f <= 1) else 0
		else:
			ok += 1 if (bool(r["won"]) and f >= 1 and f <= 3) else 0
	var avg: float = 0.0
	for f2: int in fails:
		avg += float(f2)
	avg /= float(maxi(1, fails.size()))
	print("SUMMARY race %s: %d missions, won %d, fails per mission %s (avg %.2f), on target %d / %d (Thường: 1-3 fails and done within 5 retries; Dễ: at most 1)" % [
		diff, results.size(), won, str(fails), avg, ok, results.size()])
