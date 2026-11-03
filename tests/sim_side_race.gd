# File: res://tests/sim_side_race.gd
# Tuning harness for the free-roam side races with rivals (plan 2026-11-03-w5-side.md T1). Not a regression test: it
# plays the real SideRace (DriftCourse route, SideRaceRivals, RouteGuide) in FreeRoam at night with the Q6 sloppy bot of
# tests/sim_drift_race.gd on the real bike (the same driving model: 250-400 ms reactions, 15 % wrong or late, a slow
# wander, drifts most corners, nitro when it remembers; no kicks: the side races have none), one race per seed, and prints
# one line per race plus a summary.
# Measurements per race: the place, the time and rank; the farthest any rival got from the player along the path and the
# most one led by; the share of race time with at least one rival on screen (the current camera's frame, within 160 m)
# and the longest stretch with the rival just ahead (the guide's marked one) out of the frame while he leads; the cost of
# SideRace.advance (rivals and guide included): average and max ms per frame.
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_side_race.gd -- normal 1 4 dua_vong
#   (difficulty normal | easy, first seed, races, route dua_cau | dua_vong | dua_gp | all)
extends SceneTree

const WRONG_P: float = 0.15
const DRIFT_P: float = 0.8
const NITRO_P: float = 0.7
const MAX_S: float = 400.0

var diff: String = "normal"
var seed0: int = 1
var races: int = 4
var route: String = "all"
var fr: Node
var bike: PlayerBike
var race: SideRace
var course: DriftCourse
var rng := RandomNumberGenerator.new()
var results: Array[Dictionary] = []
var _pending: Array = []
var _t: float = 0.0
var _wander_ph: float = 0.0
var _corner_seen: int = -1
var _corner_drift: bool = false
var _drift_until: float = -1.0
var _nitro_hold: int = 0
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
		races = int(a[2])
	if a.size() >= 4:
		route = a[3]
	PlayerBike.sfx_dir = OS.get_cache_dir().replace("\\", "/").trim_suffix("/") + "/fptu_sim_race_no_sfx/"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	Difficulty.set_easy(diff == "easy")
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	await _frames(30)
	if fr.has_method("set_time_of_day"):
		fr.call("set_time_of_day", "night")
	bike = fr.get("bike")
	var ids: Array[String] = SideRace.ORDER if route == "all" else ([route] as Array[String])
	for rid: String in ids:
		for m: int in races:
			await _race(rid, seed0 + m)
	_summary()
	_release()
	Difficulty.set_easy(false)
	quit(0)


func _race(rid: String, sd: int) -> void:
	rng.seed = sd * 7919 + (1 if diff == "easy" else 0)
	Difficulty.set_easy(diff == "easy")
	course = SideRace.route_course(rid)
	race = SideRace.new()
	fr.add_child(race)
	race.setup({"roam": fr, "id": rid, "course": course})
	race.auto_tick = false
	var done: Array = [false]
	race.finished.connect(func(_i: String, _r: Dictionary) -> void: done[0] = true)
	race.failed.connect(func(_i: String, _r: String) -> void: done[0] = true)
	race.start()
	_reset_bot()
	var n: int = 0
	var gap_max: float = 0.0
	var lead_max: float = -INF
	var on_t: float = 0.0
	var race_t: float = 0.0
	var hid: float = 0.0
	var hid_max: float = 0.0
	var cost: Array[float] = []
	var cam_vs: Vector2 = root.get_viewport().get_visible_rect().size
	var screen := Rect2(Vector2.ZERO, cam_vs).grow(-12.0)
	while not bool(done[0]) and n < int(MAX_S * 60.0):
		await _frames(1)
		n += 1
		if race.state == "racing":
			_bot(1.0 / 60.0)
		else:
			_release()
		var t0: int = Time.get_ticks_usec()
		race.advance(1.0 / 60.0)
		cost.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if race.state != "racing" or race.rivals == null or race.t < 3.0:
			continue
		race_t += 1.0 / 60.0
		gap_max = maxf(gap_max, race.rivals.max_gap(race.s_p))
		var cam: Camera3D = root.get_viewport().get_camera_3d()
		var any_on: bool = false
		var near_off: bool = false
		var nr: DriftRival = race.rivals.near_rival(race.s_p)
		for r: DriftRival in race.rivals.rivals:
			if r.finished:
				continue
			lead_max = maxf(lead_max, r.s - race.s_p)
			var p3: Vector3 = r.global_position + Vector3(0.0, 1.2, 0.0)
			var on: bool = cam != null and not cam.is_position_behind(p3) and cam.global_position.distance_to(p3) < 160.0 and screen.has_point(cam.unproject_position(p3))
			any_on = any_on or on
			if r == nr and r.s > race.s_p + 2.0 and not on:
				near_off = true
		if any_on:
			on_t += 1.0 / 60.0
		hid = hid + 1.0 / 60.0 if near_off else 0.0
		hid_max = maxf(hid_max, hid)
	_release()
	var avg: float = 0.0
	var mx: float = 0.0
	for c: float in cost:
		avg += c
		mx = maxf(mx, c)
	avg /= maxf(float(cost.size()), 1.0)
	var res: Dictionary = race.result.duplicate()
	res["route"] = rid
	res["seed"] = sd
	res["gap_max"] = gap_max
	res["lead_max"] = lead_max
	res["on"] = on_t / maxf(race_t, 0.01)
	res["hid_max"] = hid_max
	res["cost_avg"] = avg
	res["cost_max"] = mx
	res["state"] = race.state
	results.append(res)
	print("  RACE %s %s seed %d: %s place %s/%s, time %s (raw %s), rank %s, resets %s | rivals: farthest %.1f m, most ahead %.1f m, on screen %.0f %%, the next rival out of the frame while ahead at most %.1f s, contacts %d, regroups %d, hops %d | cost avg %.3f ms, max %.3f ms" % [
		rid, diff, sd, race.state, str(res.get("place", "-")), str(res.get("of", "-")), str(res.get("time", "-")), str(res.get("raw", "-")),
		str(res.get("rank", "-")), str(res.get("resets", "-")), gap_max, lead_max, 100.0 * float(res["on"]), hid_max,
		race.rivals.contacts if race.rivals else 0, race.rivals.regroups if race.rivals else 0, race.rivals.hops if race.rivals else 0, avg, mx])
	race.stop()
	race.queue_free()
	await _frames(3)


func _reset_bot() -> void:
	_pending.clear()
	_corner_seen = -1
	_corner_drift = false
	_drift_until = -1.0
	_nitro_hold = 0
	_nitro_armed = false
	_wander_ph = rng.randf_range(0.0, TAU)


func _release() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro"]:
		Input.action_release(a)


func _delay() -> float:
	var d: float = rng.randf_range(0.25, 0.4)
	if rng.randf() < WRONG_P * 0.5:
		d += 0.3
	return d


func _later(action: String, arg: Variant = null) -> void:
	_pending.append([_t + _delay(), action, arg])


## The sloppy driver of sim_drift_race (steering with lag and wander, corners, drift, nitro), no kicks.
func _bot(dt: float) -> void:
	_t += dt
	var s: float = race.s_p
	var v: float = bike.current_speed_ms
	var wander: float = sin(_t * 0.5 + _wander_ph) * 0.6 + sin(_t * 1.3 + _wander_ph * 2.0) * 0.3
	var look: float = clampf(v * 0.45, 4.0, 12.0)
	var tgt: Vector2 = course.world(s + look, clampf(wander, -course.half_width_at(s + look) + 1.0, course.half_width_at(s + look) - 1.0))
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
	var ci: int = course.corner_at(s + v * 0.5)
	if ci >= 0 and ci != _corner_seen:
		_corner_seen = ci
		var will: bool = rng.randf() < DRIFT_P
		if rng.randf() < WRONG_P:
			will = not will
		_corner_drift = will
		if will:
			_later("drift_on", float(course.corners[ci][1]) + (8.0 if rng.randf() < WRONG_P else 0.0))
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
			"nitro":
				Input.action_press("nitro")
				_nitro_hold = 3


func _summary() -> void:
	var places: Array[int] = []
	var gm: float = 0.0
	var lm: float = -INF
	var onm: float = 1.0
	var hm: float = 0.0
	var ca: float = 0.0
	var cm: float = 0.0
	for r: Dictionary in results:
		places.append(int(r.get("place", 0)))
		gm = maxf(gm, float(r["gap_max"]))
		lm = maxf(lm, float(r["lead_max"]))
		onm = minf(onm, float(r["on"]))
		hm = maxf(hm, float(r["hid_max"]))
		ca = maxf(ca, float(r["cost_avg"]))
		cm = maxf(cm, float(r["cost_max"]))
	var avg_p: float = 0.0
	for p: int in places:
		avg_p += float(p)
	avg_p /= maxf(float(places.size()), 1.0)
	print("SUMMARY side races %s: %d races, places %s (avg %.2f); rivals farthest %.1f m, most ahead %.1f m, at least one on screen >= %.0f %% of every race, the next rival out of the frame while ahead at most %.1f s; cost avg <= %.3f ms, max %.3f ms" % [
		diff, results.size(), str(places), avg_p, gm, lm, 100.0 * onm, hm, ca, cm])
