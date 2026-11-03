# File: res://tests/sim_side_takedown.gd
# Tuning harness for the free-roam takedown challenges (plan 2026-11-03-w5-side.md T5a). Not a regression test: it plays
# the real SideTakedown (a BikeChase in free mode, its waves of Bầy Sói riders) in FreeRoam at night with the Q6 sloppy bot
# of tests/sim_bike_chase_d2.gd on the real bike: 250-400 ms reaction delay on every decision (+0.3 s when late), 15 % of
# them wrong (a dodge the wrong way, a kick to the wrong side), reads 65 % of the telegraphs, a slow wander off the line.
# With no route in free mode the bot rides the Rạch Hầm roads (DriftCourse.rach_ham(), round its loop) from the start
# spot. A knock-off fails the attempt like in the game; the bot starts the challenge again from its spot until it wins
# (at most MAX_TRIES), so the number per seed is the fails before the win.
# Measurements per attempt: the result, the time, kicks / hits, the damage by cause; the share of combat time with at least
# one active rider on screen (the current camera's frame, within 160 m) and the longest stretch with none.
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_side_takedown.gd -- normal 1 4 all
#   (difficulty normal | easy, first seed, seeds, challenge td_soi | td_bay | all)
extends SceneTree

const BP: Dictionary = {"react": 0.65, "delay": 0.25, "delay_max": 0.4, "kick_p": 0.8, "wrong": 0.15, "wander": 1.1}
const MAX_TRIES: int = 8
const V_CAP: float = 22.0

var diff: String = "normal"
var seed0: int = 1
var seeds: int = 4
var which: String = "all"
var fr: Node
var bike: PlayerBike
var course: DriftCourse
var td: SideTakedown
var rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _s: float = 0.0
var _wander_ph: float = 0.0
var _seen: Dictionary = {}
var _reach_t: Dictionary = {}
var _brake_left: float = 0.0
var _shift_left: float = 0.0
var _shift: float = 0.0
var _ray_q := PhysicsRayQueryParameters3D.new()
var runs: Array[Dictionary] = []


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
	PlayerBike.sfx_dir = OS.get_cache_dir().replace("\\", "/").trim_suffix("/") + "/fptu_sim_td_no_sfx/"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	Difficulty.set_easy(diff == "easy")
	print("--- SIM SIDE TAKEDOWN (sloppy bot, %s, seeds %d..%d) ---" % [diff, seed0, seed0 + seeds - 1])
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	await _frames(30)
	if fr.has_method("set_time_of_day"):
		fr.call("set_time_of_day", "night")
	bike = fr.get("bike")
	course = DriftCourse.rach_ham()
	var ids: Array[String] = SideTakedown.ORDER if which == "all" else ([which] as Array[String])
	for cid: String in ids:
		for m: int in seeds:
			await _seed_run(cid, seed0 + m)
	_summary()
	_release()
	Difficulty.set_easy(false)
	quit(0)


## Attempts until a win (or MAX_TRIES): the fails before the win.
func _seed_run(cid: String, sd: int) -> void:
	rng.seed = sd * 7919 + (1 if diff == "easy" else 0)
	Difficulty.set_easy(diff == "easy")
	var fails: int = 0
	var won: bool = false
	var why: Array[String] = []
	var tries: int = 0
	var on_min: float = 1.0
	var off_max: float = 0.0
	var times: Array[String] = []
	while tries < MAX_TRIES and not won:
		tries += 1
		var r: Dictionary = await _attempt(cid)
		on_min = minf(on_min, float(r["on"]))
		off_max = maxf(off_max, float(r["off_max"]))
		times.append("%s %.0fs" % [String(r["end"]), float(r["t"])])
		if String(r["end"]) == "won":
			won = true
		else:
			fails += 1
			why.append(String(r["end"]))
	runs.append({"id": cid, "seed": sd, "fails": fails, "won": won, "on": on_min, "off_max": off_max})
	print("  %s %s seed %d: %s after %d fails %s (attempts %s), riders on screen >= %.0f %% of combat, longest none %.1f s" % [
		cid, diff, sd, "won" if won else "NOT WON", fails, str(why), ", ".join(PackedStringArray(times)), 100.0 * on_min, off_max])


func _attempt(cid: String) -> Dictionary:
	_reset_bot()
	var at: Vector2 = SideTakedown.start_at(cid)
	_s = course.s_near(at, 0.0)
	if course.point(_s).distance_to(at) > 8.0:
		_s = course.project_near(at, course.lap_s[0] + 50.0, 2000.0).x
	_place(_s)
	await _frames(5)
	td = SideTakedown.new()
	fr.add_child(td)
	td.setup({"roam": fr, "id": cid})
	td.auto_tick = false
	var end: Array = [""]
	td.finished.connect(func(_i: String, _r: Dictionary) -> void: end[0] = "won")
	td.failed.connect(func(_i: String, why: String) -> void: end[0] = why)
	var dmg: Dictionary = {}
	td.start()
	if td.chase and td.chase.combat:
		td.chase.combat.damaged.connect(func(amount: float, cause: String) -> void: dmg[cause] = float(dmg.get(cause, 0.0)) + amount)
	var n: int = 0
	var combat_t: float = 0.0
	var on_t: float = 0.0
	var off_run: float = 0.0
	var off_max: float = 0.0
	var vs: Vector2 = root.get_viewport().get_visible_rect().size
	var screen := Rect2(Vector2.ZERO, vs).grow(-12.0)
	while String(end[0]) == "" and n < int((SideTakedown.TIME_LIMIT_S + 5.0) * 60.0):
		await _frames(1)
		n += 1
		td.advance(1.0 / 60.0)
		if td.chase == null or td.chase.state != "running":
			_release()
			continue
		_bot(1.0 / 60.0)
		var act: int = 0
		var on: int = 0
		var cam: Camera3D = root.get_viewport().get_camera_3d()
		for b: Variant in td.chase.bikers:
			var e: BikerEnemy = b as BikerEnemy
			if e == null or not is_instance_valid(e) or not e.is_active():
				continue
			act += 1
			var p3: Vector3 = e.global_position + Vector3(0.0, 1.2, 0.0)
			if cam and not cam.is_position_behind(p3) and cam.global_position.distance_to(p3) < 160.0 and screen.has_point(cam.unproject_position(p3)):
				on += 1
		if act == 0:
			off_run = 0.0
			continue
		combat_t += 1.0 / 60.0
		if on > 0:
			on_t += 1.0 / 60.0
			off_run = 0.0
		else:
			off_run += 1.0 / 60.0
			off_max = maxf(off_max, off_run)
	_release()
	var kicks: int = td.chase.combat.kicks if td.chase and td.chase.combat else 0
	var hits: int = td.chase.combat.hits if td.chase and td.chase.combat else 0
	var dm: Array[String] = []
	for k: String in dmg.keys():
		dm.append("%s %.0f" % [k, float(dmg[k])])
	var out: Dictionary = {"end": String(end[0]) if String(end[0]) != "" else "stuck", "t": td.t, "on": on_t / maxf(combat_t, 0.01), "off_max": off_max}
	if OS.has_environment("SIM_VERBOSE"):
		print("    attempt %s: %s in %.0f s, downed %d/%d, kicks %d hit %d, enemy attacks %d (%d hit), dmg {%s}, result %s" % [cid, out["end"], td.t, td.downed, td.total, kicks, hits,
			td.chase.attack_starts if td.chase else 0, td.chase.attack_hits if td.chase else 0, ", ".join(dm), str(td.result)])
	td.stop()
	td.queue_free()
	td = null
	await _frames(60)
	return out


## The bike upright on the road at s, mounted, still.
func _place(s: float) -> void:
	var p: Vector2 = course.world(s, 0.0)
	var yaw: float = course.yaw_at(s)
	_ray_q.from = Vector3(p.x, 8.0, p.y)
	_ray_q.to = Vector3(p.x, -6.0, p.y)
	_ray_q.exclude = [bike.get_rid()]
	var hit: Dictionary = fr.get_world_3d().direct_space_state.intersect_ray(_ray_q)
	var fy: float = (hit["position"] as Vector3).y if not hit.is_empty() else 0.05
	var origin := Vector3(p.x, fy - SideRace.BIKE_FLOOR_OFFSET, p.y)
	if not bool(fr.get("mounted")):
		var pl: Node = fr.get("player")
		if bool(fr.get("bike_parked")):
			bike.global_position = origin
			bike.rotation = Vector3(0.0, yaw, 0.0)
		if pl and pl.has_method("teleport"):
			pl.call("teleport", origin + Vector3(0.0, SideRace.BIKE_FLOOR_OFFSET, 0.0), yaw)
		if fr.has_method("mount_bike"):
			fr.call("mount_bike")
	bike.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	bike.set("velocity", Vector3.ZERO)
	bike.current_speed_ms = 0.0


func _reset_bot() -> void:
	_t = 0.0
	_wander_ph = rng.randf_range(0.0, TAU)
	_seen.clear()
	_reach_t.clear()
	_brake_left = 0.0
	_shift_left = 0.0
	_shift = 0.0


func _roll(p: float) -> bool:
	return rng.randf() < p


func _delay() -> float:
	var d: float = rng.randf_range(float(BP["delay"]), float(BP["delay_max"]))
	if _roll(float(BP["wrong"]) * 0.5):
		d += 0.3
	return d


func _release() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro"]:
		Input.action_release(a)


## The sloppy bot of sim_bike_chase_d2 (telegraph reactions, kicks) riding the Rạch Hầm roads round the loop.
func _bot(dt: float) -> void:
	_t += dt
	var ch: BikeChase = td.chase
	var bp := Vector2(bike.global_position.x, bike.global_position.z)
	var loop_len: float = course.lap_s[1] - course.lap_s[0]
	_s = course.project_near(bp, _s).x
	if _s > course.lap_s[1] - 2.0:          # round the loop again (P_LAP is both ends of a lap)
		_s -= loop_len
	var spd: float = absf(bike.current_speed_ms)
	_brake_left -= dt
	_shift_left -= dt
	# reactions to telegraphs (a rider / stick / heavy winding up near the player)
	for b: Variant in ch.bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e == null or not is_instance_valid(e):
			continue
		if e.telegraphing() and e.kind != "thrower" and e.pos2.distance_to(ch.p_pos) < 8.0:
			if not _seen.has(e):
				_seen[e] = [_t, false, _roll(float(BP["react"])), _delay()]
			var sv: Array = _seen[e]
			if bool(sv[2]) and not bool(sv[1]) and _t - float(sv[0]) >= float(sv[3]):
				sv[1] = true
				var lat: float = (e.pos2 - bp).dot(course.right(_s))
				var wrong: bool = _roll(float(BP["wrong"]))
				if e.kind == "stick":
					_brake_left = 0.55 if not wrong else 0.0
				else:
					_shift = -signf(lat) * 2.2 * (-1.0 if wrong else 1.0)
					_shift_left = 0.55
		elif _seen.has(e) and not e.is_attacking():
			_seen.erase(e)
	# kicks
	if ch.combat.kick_cd <= 0.0 and not ch.combat.kicking():
		for sd: int in [-1, 1]:
			var tg: Node3D = ch.combat.kick_target(sd)
			if tg == null:
				continue
			_reach_t[tg] = float(_reach_t.get(tg, 0.0)) + dt
			if float(_reach_t[tg]) >= _delay():
				_reach_t.erase(tg)
				if _roll(float(BP["kick_p"])):
					ch.combat.kick(-sd if _roll(float(BP["wrong"])) else sd)
				break
	# steering along the road (a wander off the line, a dodge shift)
	var want_d: float = (sin(_t * 0.45 + _wander_ph) * 0.75 + sin(_t * 1.2 + _wander_ph * 1.7) * 0.25) * float(BP["wander"])
	if _shift_left > 0.0:
		want_d = _shift
	var look: float = 9.0 + spd * 0.35
	var sl: float = _s + look
	if sl > course.lap_s[1]:
		sl -= loop_len
	var hw: float = course.half_width_at(sl) - 0.8
	var tgt: Vector2 = course.world(sl, clampf(want_d, -hw, hw))
	var z: Vector3 = bike.global_transform.basis.z
	var f := Vector2(-z.x, -z.z).normalized()
	var to: Vector2 = (tgt - bp).normalized()
	var ang: float = atan2(f.x * to.y - f.y * to.x, f.dot(to))
	var steer: float = clampf(ang * 2.4, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if steer < -0.02:
		Input.action_press("steer_left", -steer)
	elif steer > 0.02:
		Input.action_press("steer_right", steer)
	var s8: float = _s + 8.0 if _s + 8.0 <= course.lap_s[1] else _s + 8.0 - loop_len
	var vt: float = minf(course.speed_at(s8), V_CAP)
	Input.action_release("gas")
	Input.action_release("brake")
	if _brake_left > 0.0:
		Input.action_press("brake", 0.7)
	elif spd < vt - 0.3:
		Input.action_press("gas")
	elif spd > vt + 1.5:
		Input.action_press("brake", clampf((spd - vt) / 6.0, 0.2, 1.0))


func _summary() -> void:
	for cid: String in SideTakedown.ORDER:
		var per: Array[int] = []
		var won: int = 0
		var onm: float = 1.0
		var offm: float = 0.0
		for r: Dictionary in runs:
			if String(r["id"]) != cid:
				continue
			per.append(int(r["fails"]))
			won += 1 if bool(r["won"]) else 0
			onm = minf(onm, float(r["on"]))
			offm = maxf(offm, float(r["off_max"]))
		if per.is_empty():
			continue
		var mean: float = 0.0
		for p: int in per:
			mean += float(p)
		mean /= float(per.size())
		print("SUMMARY %s %s: %d seeds, %d won, fails %s = %.2f mean; riders on screen >= %.0f %% of combat, longest none %.1f s" % [
			cid, diff, per.size(), won, str(per), mean, 100.0 * onm, offm])
