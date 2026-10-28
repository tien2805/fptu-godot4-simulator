# File: res://tests/test_drift_duel.gd
# Headless test of the Day 2 race with Sói Xám, "đua + đánh" (Wave 2 Day 2 rework, plan 2026-10-29-w2-day2.md).
# Part A, a flat arena under the course (no FreeRoam; the bike locked and moved along the path by the test):
#   the course data (an open path of about 2.1 km on real roads, 2 laps, the drift corners and their labels, the gates,
#   the rival's pace); the props (4 neon arches, a sign set per corner, the pack, the fireworks pool); the hooks (race
#   profile, nitro on, the kicks, all given back on stop); the countdown (a rev on each count at 0 / 1 / 2 s, Sói Xám
#   answering 0.5 s later, GO at 3 s, the music cue once at GO); a drifted corner charges nitro (x1.5 inside, + the bonus
#   on the way out); his kick (telegraph ring, the side warning, the counter window, the damage), a dodge, the player's 3
#   kicks make him wobble and lose speed for 2 s, a counter-kick is worth 2; the laps and gates; the losses (he crosses
#   first, knocked off) with the quick retry and the lap 2 checkpoint; off the course and the wrong way; the win with the
#   fireworks and the ending; Dễ numbers; the time scale left at 1.
# Part B, FreeRoam (crowd off): the racing line is clear of the real world, the pack stands on free ground, the traffic
#   is parked and comes back, MissionDriftDuel's music (the drift track on GO with fade 0, the old track faded over the
#   countdown; the chase-track fallback); test bots on the real bike: a good bot wins, a stopped bot is beaten; the
#   race's own cost is printed.
# Run:  godot --headless --path . --script tests/test_drift_duel.gd
extends SceneTree

const DT: float = 1.0 / 60.0

var fails: Array[String] = []
var arena: Node3D
var bike: PlayerBike
var duel: DriftDuel
var course: DriftCourse
var sig: Dictionary = {}
var drive_s: float = 0.0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  x ", msg)
	else:
		print("  ok ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST DRIFT DUEL (đua + đánh with Sói Xám, Rạch Hầm GP) ---")
	PlayerBike.sfx_dir = OS.get_cache_dir().replace("\\", "/").trim_suffix("/") + "/fptu_test_drift_no_sfx/"
	PlayerBike.clear_owner_sfx()
	Difficulty.set_easy(false)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _count(name: String) -> void:
	sig[name] = int(sig.get(name, 0)) + 1


## The test's "rider": the bike set on the path at s (lateral d) facing along it, moving at v.
func _drive_to(s: float, d: float = 0.0, v: float = 18.0, backwards: bool = false) -> void:
	drive_s = s
	var p: Vector2 = course.world(s, d)
	var y: Variant = duel.floor_at(Vector3(p.x, 0.0, p.y), 20.0, 20.0)
	bike.global_position = Vector3(p.x, (float(y) if y is float else 0.0) - DriftDuel.BIKE_FLOOR_OFFSET, p.y)
	bike.rotation = Vector3(0.0, course.yaw_at(s) + (PI if backwards else 0.0), 0.0)
	bike.current_speed_ms = v
	var t: Vector2 = course.tangent(s) * (-v if backwards else v)
	bike.velocity = Vector3(t.x, 0.0, t.y)


## Drive the player from drive_s to s_to at step m per frame (the race keeps ticking); stops early when the state leaves
## "racing".
func _ride(s_to: float, step: float, d: float = 0.0) -> void:
	var n: int = 0
	while drive_s < s_to and duel.state == "racing" and n < 20000:
		_drive_to(minf(drive_s + step, s_to), d, step * 60.0)
		await _frames(1)
		n += 1


func _run() -> void:
	await _frames(1)
	await _part_a()
	if arena and is_instance_valid(arena):
		arena.free()
	await _frames(2)
	if not OS.has_environment("DRIFT_SKIP_B"):
		await _part_b()
	_finish()


# ---------------------------------------------------------------------------
# PART A
# ---------------------------------------------------------------------------
func _part_a() -> void:
	course = DriftCourse.rach_ham()
	_check(course.length > 1900.0 and course.length < 2300.0, "the race is about 2.1 km (%.0f m)" % course.length)
	_check(course.lap_s.size() == DriftCourse.LAPS + 1 and course.lap_s[0] < course.lap_s[1] and course.lap_s[1] < course.lap_s[2] and course.lap_s[2] < course.length,
		"2 laps of the loop between the run out and home (lap lines %s)" % str(course.lap_s))
	var lap_len: float = course.lap_s[1] - course.lap_s[0]
	_check(lap_len > 600.0 and lap_len < 760.0, "one loop is %.0f m" % lap_len)
	_check(course.corners.size() >= 7, "%d drift corners" % course.corners.size())
	var labels: Array = []
	for c: Array in course.corners:
		if not labels.has(String(c[3])):
			labels.append(String(c[3]))
	_check(labels.has("CUA CHỮ Y") and labels.has("KẸP TÓC") and labels.has("CUA SỐ 20") and labels.has("VÀO VÒNG"), "the corners are named (%s)" % str(labels))
	_check(course.min_radius() > 7.0, "the tightest corner radius %.1f m (the bike's drift circle is 8.4 m)" % course.min_radius())
	var pace: float = course.pace_time()
	_check(pace > 65.0 and pace < 100.0, "the rival's full pace from the grid to the finish: %.1f s" % pace)
	var pr: Vector2 = course.project_near(course.world(300.0, 2.0), 290.0)
	_check(absf(pr.x - 300.0) < 0.5 and absf(pr.y - 2.0) < 0.05, "project_near: s and the lateral offset (%.2f, %.2f)" % [pr.x, pr.y])
	var pl: Vector2 = course.project_near(course.world(course.lap_s[1] + 100.0, 0.0), course.lap_s[1] + 90.0)
	_check(absf(pl.x - course.lap_s[1] - 100.0) < 0.5, "the windowed projection keeps the lap (lap 2, not lap 1, on the same road)")
	_check(course.lap_at(10.0) == 0 and course.lap_at(course.lap_s[0] + 5.0) == 1 and course.lap_at(course.lap_s[1] + 5.0) == 2 and course.lap_at(course.lap_s[2] + 5.0) == 3,
		"lap_at: grid run, lap 1, lap 2, home")
	_check(course.point(0.0).distance_to(course.point(course.length)) < 1.0, "the finish line is where the grid was (mid-deck)")
	var texts: Array[String] = [DriftDuel.T_START, DriftDuel.T_END, DriftDuel.T_GO, DriftDuel.T_LAP, DriftDuel.T_LAST_LAP, DriftDuel.T_HOME,
		DriftDuel.T_LEAD, DriftDuel.T_SECOND, DriftDuel.T_GAP_AHEAD, DriftDuel.T_GAP_BEHIND, DriftDuel.T_WIN, DriftDuel.T_LOSE_BEATEN,
		DriftDuel.T_LOSE_KNOCKED, DriftDuel.T_RETRY_LAP2, DriftDuel.T_OFF, DriftDuel.T_WRONG, DriftDuel.T_CORNER, DriftDuel.T_CORNER_BONUS,
		DriftDuel.T_KICK_HIT, DriftDuel.T_WOBBLE, DriftDuel.T_HE_KICKED, DriftDuel.T_DODGED, DriftDuel.T_TURN_LAP2, DriftDuel.T_TURN_HOME,
		DriftDuel.T_STAB, DriftDuel.T_KICKS, DriftDuel.T_RIDING, DriftDuel.T_NO_DISMOUNT, DriftRival.NAME, DriftRival.T_CLOSE,
		DriftRival.T_FAR, DriftRival.T_KICK, DriftRival.T_WOBBLE, DriftRival.T_BLOCK, NitroGauge.T_TITLE, NitroGauge.T_READY,
		NitroGauge.T_HINT, String(StoryMissions.beat("d2_drift")["objective"]), String(StoryMissions.beat("d2_drift")["title"])]
	texts.append_array(DriftRival.TAUNTS)
	for a: Array in course.arches:
		texts.append(String(a[1]))
		texts.append(String(a[2]))
	for z: Array in course.corners:
		texts.append(String(z[3]))
	var odd: Array = []
	for tx: String in texts:
		for i: int in tx.length():
			if tx.unicode_at(i) >= 0x2000:
				odd.append(tx)
				break
	_check(odd.is_empty(), "every race text is plain Vietnamese, no emoji or decorative symbols %s" % str(odd))
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(700.0, 1.0, 700.0)
	cs.shape = bs
	floor.add_child(cs)
	floor.position = Vector3(1915.0, -0.5, 10.0)
	arena.add_child(floor)
	bike = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
	arena.add_child(bike)
	bike.apply_speed_profile(PlayerBike.OWNER_PROFILE)
	bike.chase_cam.make_current()
	duel = DriftDuel.new()
	duel.name = "Duel"
	arena.add_child(duel)
	duel.setup({"bike": bike, "intro": false, "course": course})
	for n: String in ["countdown_started", "music_cue", "go", "won", "lost", "ended", "gate_passed", "reset_to_gate", "lap_started"]:
		duel.connect(n, func(_a: Variant = null) -> void: _count(n))
	duel.won.connect(func(how: String) -> void: sig["won_how"] = how)
	duel.lost.connect(func(r: String) -> void: sig["lost_reason"] = r)
	var laps_seen: Array = []
	duel.lap_started.connect(func(l: int) -> void: laps_seen.append(l))
	await _frames(2)
	var pp: DriftRaceProps = duel.props
	_check(pp != null and pp.arch_count == course.arches.size() and pp.arrow_groups.size() == course.corners.size(), "props: %d neon arches, a sign set per corner" % (pp.arch_count if pp else -1))
	_check(pp.member_count >= 40 and pp.lights.size() == DriftRaceProps.LIGHTS, "the Bầy Sói pack: %d with flares, %d flare lights" % [pp.member_count, pp.lights.size()])
	duel.start()
	_check(duel.state == "countdown" and bike.staged and bike.is_controls_locked, "start(): the countdown, the bike staged on the grid")
	_check(is_equal_approx(bike.max_speed_ms, float(DriftDuel.DUEL_PROFILE["max_speed_ms"])) and bike.nitro_enabled and duel.hud.visible and not duel.combat.enabled,
		"the race profile (100 km/h), nitro on, the HUD; no kicks before GO")
	_check(absf(duel.gap() - DriftDuel.RIVAL_GRID_AHEAD) < 0.5 and duel.rival.d < 0.0 and duel.d_p > 0.0, "the grid: Sói Xám on the left, 2.5 m ahead")
	# countdown: revs at 0 / 1 / 2 s, his answers 0.5 s later, GO at 3 s
	var revs0: int = bike.revs
	var times: Array = []
	var ans: Array = []
	var go_f: int = -1
	var last_r: int = bike.revs
	var last_a: int = duel.rival.revs
	for f: int in 200:
		await _frames(1)
		if bike.revs != last_r:
			times.append(f)
			last_r = bike.revs
		if duel.rival.revs != last_a:
			ans.append(f)
			last_a = duel.rival.revs
		if go_f < 0 and duel.state == "racing":
			go_f = f
			break
	_check(bike.revs - revs0 == 3 and times.size() == 3 and absf(float(times[1] - times[0]) - 60.0) <= 1.0 and absf(float(times[2] - times[0]) - 120.0) <= 1.0,
		"a rev on each count, 1 s apart (frames %s)" % str(times))
	_check(ans.size() == 3 and absf(float(ans[0] - times[0]) - 30.0) <= 1.0, "Sói Xám answers each count 0.5 s later (frames %s)" % str(ans))
	_check(go_f >= 0 and absf(float(go_f - times[0]) - 180.0) <= 1.0 and int(sig.get("go", 0)) == 1 and int(sig.get("music_cue", 0)) == 1, "GO 3 s after the first count, the music cue once with it (frame %d)" % go_f)
	_check(not bike.staged and duel.rival.racing and duel.combat.enabled and duel.rival.nitros == 1, "GO: he launches with a nitro burst, the kicks are on")
	bike.is_controls_locked = true
	# the first corner (the Y junction), drifted: x1.5 inside, the bonus on the way out
	duel.rival.kick_cd = 99.0
	drive_s = duel.s_p
	var c0: Array = course.corners[0]
	await _ride(float(c0[0]) - 2.0, 0.6)
	bike.drift_charge = 0.0
	duel.force_drift = 1
	var mult_in: float = 0.0
	while drive_s < float(c0[1]) + 3.0 and duel.state == "racing":
		_drive_to(drive_s + 0.5, 0.0, 30.0)
		await _frames(1)
		if course.corner_at(duel.s_p) == 0:
			mult_in = bike.drift_charge_mult
	duel.force_drift = 0
	await _frames(1)
	_check(is_equal_approx(mult_in, DriftDuel.CORNER_CHARGE_MULT) and duel.corner_bonuses == 1 and bike.drift_charge >= duel.corner_bonus - 0.01 and is_equal_approx(bike.drift_charge_mult, 1.0),
		"a drifted corner: charge x1.5 inside, +%d nitro on the way out (charge %.1f)" % [int(duel.corner_bonus), bike.drift_charge])
	_check(duel.popup_text == DriftDuel.T_CORNER_BONUS, "DRIFT ĐẸP! +NITRO")
	duel.force_drift = -1
	# his kick: alongside him on a straight
	var r: DriftRival = duel.rival
	var kicked: Array = []
	r.kicked_player.connect(func(side: int, hit: bool) -> void: kicked.append([side, hit]))
	await _alongside(1.6, 5)
	r.kick_cd = 0.0
	r.attack_chance = 1.0
	var st0: float = duel.combat.stability
	var saw: Dictionary = {}
	var n: int = 0
	while kicked.is_empty() and n < 400:
		await _alongside(1.6, 1)
		if r.mode == "windup":
			saw["ring"] = r.ring.visible
			saw["warn"] = duel.warn_side
			saw["tth"] = maxf(float(saw.get("tth", 0.0)), r.time_to_hit())
		n += 1
	_check(bool(saw.get("ring", false)) and int(saw.get("warn", 0)) == -1 and float(saw.get("tth", 0.0)) <= r.kick_windup + DriftRival.KICK_HIT_AT + 0.01,
		"his kick: a %.1f s telegraph (the red ring, BÊN TRÁI on the HUD), the counter window from time_to_hit" % r.kick_windup)
	_check(kicked.size() == 1 and bool(kicked[0][1]) and absf(st0 - duel.combat.stability - r.kick_dmg) < 0.01 and duel.popup_text == DriftDuel.T_HE_KICKED,
		"the kick lands: -%d stability, \"Ăn đạp của Sói Xám!\" (%s)" % [int(r.kick_dmg), str(kicked)])
	# a dodge: the player steers away during the wind-up
	await _frames(40)
	kicked.clear()
	r.kick_cd = 0.0
	n = 0
	var dodge_d: float = 1.6
	while kicked.is_empty() and n < 400:
		if r.mode == "windup":
			dodge_d = minf(dodge_d + 0.2, 4.5)
		await _alongside(dodge_d, 1)
		n += 1
	_check(kicked.size() == 1 and not bool(kicked[0][1]) and duel.dodges == 1 and duel.popup_text == DriftDuel.T_DODGED, "steering away in the wind-up dodges it: NÉ ĐẸP! (%s)" % str(kicked))
	# the player's kicks: 3 make him wobble and lose speed for 2 s
	r.kick_cd = 99.0
	bike.is_controls_locked = false
	var hits0: int = r.hits_total
	r.wobbled.connect(func() -> void: sig["wob_f"] = Engine.get_physics_frames(), CONNECT_ONE_SHOT)
	for k: int in 3:
		await _alongside(1.6, 2)
		duel.combat.kick(-1)                 # he rides on the player's left
		for f2: int in 40:
			await _alongside(1.6, 1)
	_check(r.hits_total - hits0 == 3 and r.wobbles == 1 and r.wobbling() and duel.popup_text == DriftDuel.T_WOBBLE, "3 kicks: SÓI XÁM LOẠNG CHOẠNG! (hits %d, wobbles %d)" % [r.hits_total - hits0, r.wobbles])
	_check(not r.kickable() and r.hp == DriftRival.KICKS_TO_WOBBLE, "while he wobbles he cannot be kicked, the count starts again after")
	var v_w: float = r.v
	var v_prof: float = course.speed_at(r.s) * r.pace
	var w_frames: int = 0
	while r.wobbling() and w_frames < 300:
		await _alongside(1.6, 1)
		v_w = minf(v_w, r.v)
		w_frames += 1
	var wob_len: float = float(Engine.get_physics_frames() - int(sig.get("wob_f", 0))) / 60.0
	_check(wob_len >= DriftRival.WOBBLE_S - 0.02 and wob_len < DriftRival.WOBBLE_S + 0.3, "the wobble lasts %.2f s (%.1f s of race time, the kick's hit-stop on top)" % [wob_len, DriftRival.WOBBLE_S])
	_check(v_w < v_prof * 0.7, "wobbling he loses speed (down to %.1f m/s against a profile of %.1f)" % [v_w, v_prof])
	# the counter-kick: worth 2 kicks
	await _frames(20)
	r.kick_cd = 0.0
	var counters0: int = duel.combat.counters
	var hits1: int = r.hits_taken
	n = 0
	while n < 400 and duel.combat.counters == counters0:
		await _alongside(1.6, 1)
		var tth: float = r.time_to_hit()
		if tth >= 0.0 and tth <= 0.2:
			duel.combat.kick(-1)
		n += 1
	_check(duel.combat.counters == counters0 + 1 and (r.hits_taken - hits1 == 2 or r.wobbles == 2), "PHẢN ĐÒN in his last 0.25 s: worth 2 kicks (%d)" % (r.hits_taken - hits1))
	bike.is_controls_locked = true
	r.kick_cd = 99.0
	# knocked off: lost, the quick retry on the grid, stability full
	sig.erase("lost_reason")
	for k2: int in 10:
		duel.combat.iframes = 0.0
		duel.combat.damage(20.0, "test")
	await _frames(2)
	_check(duel.state == "lost" and String(sig.get("lost_reason", "")) == "knocked" and duel.losses == 1, "his kicks knock the player off: lost (%s)" % str(sig.get("lost_reason", "")))
	var lost_f: int = 0
	while duel.state != "countdown" and lost_f < 300:
		await _frames(1)
		lost_f += 1
	_check(duel.state == "countdown" and duel.retry_count and absf(duel.countdown_len - DriftDuel.RETRY_COUNTDOWN_S) < 0.01 and is_equal_approx(duel.combat.stability, duel.combat.max_stability),
		"a quick retry by itself: a 2 s countdown, stability full")
	_check(absf(float(lost_f) / 60.0 - (DriftDuel.LOSE_PAUSE_S + DriftDuel.FADE_S)) < 0.15 and absf(duel.s_p - DriftDuel.GRID_LAT * 0.0) < 3.0 and duel.start_s == 0.0,
		"back on the grid %.2f s after the loss" % (float(lost_f) / 60.0))
	n = 0
	while duel.state == "countdown" and n < 200:
		await _frames(1)
		n += 1
	_check(absf(float(n) / 60.0 - 2.0) < 0.1 and duel.state == "racing", "the retry's GO after 2 s")
	bike.is_controls_locked = true
	r.kick_cd = 99.0
	# laps and gates: ride the race (ahead of him), past the lap 2 line, then he crosses first: beaten, the lap 2 grid
	var gates_seen: Array = []
	duel.gate_passed.connect(func(i: int) -> void: gates_seen.append(i))
	laps_seen.clear()
	drive_s = duel.s_p
	await _ride(course.lap_s[1] + 40.0, 0.7)
	_check(laps_seen == [1, 2] and duel.lap2_reached and duel.lap == 2, "the laps: lap 1, then lap 2 (%s)" % str(laps_seen))
	var want_g: int = 0
	for g: float in course.gates:
		if g < course.lap_s[1] + 40.0:
			want_g += 1
	_check(gates_seen.size() == want_g and gates_seen == range(want_g), "the gates in order (%d)" % gates_seen.size())
	sig.erase("lost_reason")
	r.s = course.length - 1.0
	r.v = 20.0
	await _frames(10)
	_check(duel.state == "lost" and String(sig.get("lost_reason", "")) == "beaten" and duel.popup_text == DriftDuel.T_LOSE_BEATEN, "he crosses the line first: lost (%s)" % str(sig.get("lost_reason", "")))
	n = 0
	while duel.state != "countdown" and n < 300:
		await _frames(1)
		n += 1
	_check(duel.state == "countdown" and absf(duel.start_s - (course.lap_s[1] + DriftDuel.LAP2_GRID_AFTER)) < 0.01 and absf(duel.s_p - duel.start_s) < 2.0
		and absf(r.s - duel.start_s - DriftDuel.RIVAL_GRID_AHEAD) < 0.1 and duel.subtitle_text == DriftDuel.T_RETRY_LAP2, "past lap 2 the retry starts on the lap 2 grid (a fair checkpoint)")
	n = 0
	while duel.state == "countdown" and n < 200:
		await _frames(1)
		n += 1
	bike.is_controls_locked = true
	r.kick_cd = 99.0
	# off the course and the wrong way: back to the last gate
	var resets: Array = []
	duel.reset_to_gate.connect(func(i: int) -> void: resets.append(i))
	drive_s = duel.s_p
	var next_gate: float = course.gates[duel.gate_i]
	await _ride(next_gate + 6.0, 0.7)
	var g_at: int = duel.gate_i - 1
	var off_f: int = 0
	while resets.is_empty() and off_f < 200:
		_drive_to(drive_s, course.half_width_at(drive_s) + 6.0, 0.0)
		await _frames(1)
		off_f += 1
	await _frames(20)
	var at: Vector2 = Vector2(bike.global_position.x, bike.global_position.z)
	_check(resets == [g_at] and absf(float(off_f) / 60.0 - DriftDuel.OFF_COURSE_S - DriftDuel.FADE_S) < 0.1 and at.distance_to(course.world(course.gates[g_at], 0.0)) < 1.5,
		"off the road for 1.2 s: back at the last gate behind a 0.2 s fade (%s after %.2f s)" % [str(resets), float(off_f) / 60.0])
	_check(duel.grace_t > 2.0, "a reset gives him 3 s of grace (he eases off)")
	resets.clear()
	drive_s = course.gates[g_at]
	var ww: int = 0
	while resets.is_empty() and ww < 300:
		_drive_to(drive_s - 0.15, 0.0, 9.0, true)
		await _frames(1)
		ww += 1
	await _frames(20)
	_check(resets == [g_at] and absf(float(ww) / 60.0 - DriftDuel.WRONG_WAY_S - DriftDuel.FADE_S) < 0.1, "riding the wrong way 1.5 s: back at the last gate (%.2f s)" % (float(ww) / 60.0))
	# the win: over the line first, the fireworks, the slow-motion finish, then the ending
	r.s = minf(r.s, duel.s_p - 60.0)
	drive_s = duel.s_p
	await _ride(course.length + 3.0, 0.9)
	_check(duel.state == "won" and String(sig.get("won_how", "")) == "race" and duel.popup_text == DriftDuel.T_WIN, "first over the line on the bridge: VỀ NHẤT! (%s)" % duel.state)
	await _frames(70)
	_check(duel.props.fireworks_fired >= 2, "fireworks over the finish (%d bursts)" % duel.props.fireworks_fired)
	n = 0
	while int(sig.get("ended", 0)) == 0 and n < 1200:
		await _frames(1)
		n += 1
	_check(int(sig.get("ended", 0)) == 1 and duel.state == "done" and duel.rival.exit_done() and duel.subtitle_text.contains(DriftDuel.T_END), "the ending: his line, he rides down under the bridge, the fade, ended")
	_check(not bike.is_controls_locked and is_equal_approx(bike.max_speed_ms, float(PlayerBike.OWNER_PROFILE["max_speed_ms"])) and not duel.combat.enabled,
		"after the race the bike rides again on its own profile, the kicks off")
	_check(is_equal_approx(Engine.time_scale, 1.0), "the time scale is back at 1 after the finish")
	duel.stop()
	duel.queue_free()
	await _frames(2)
	# Dễ: the rival's and the rules' numbers
	Difficulty.set_easy(true)
	var rv := DriftRival.new()
	rv.refresh_tuning()
	_check(rv.kick_dmg < 20.0 and rv.kick_windup > 0.5 and rv.kick_cooldown > 2.4 and rv.pace < 1.0 and rv.nitros_per_race < 4, "Dễ: he kicks softer, later and less often, rides slower, fewer nitros")
	rv.free()
	Difficulty.set_easy(false)
	_check(is_equal_approx(Engine.time_scale, 1.0), "the time scale is left at 1")


## The player alongside the rival at `lat` to his right (the rival on the player's left), at his speed, for n frames.
func _alongside(lat: float, n: int) -> void:
	for i: int in n:
		var r: DriftRival = duel.rival
		_drive_to(r.s, r.d + lat, maxf(r.v, 12.0))
		duel.s_p = r.s
		await _frames(1)


# ---------------------------------------------------------------------------
# PART B (FreeRoam)
# ---------------------------------------------------------------------------
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var fr: Node
var tail_node: PhysTail
var _pt0: int = 0
var frame_us: PackedInt32Array = PackedInt32Array()
var timing: bool = false
var duel_us: PackedInt32Array = PackedInt32Array()
var _nitro_hold: int = 0


func _on_phys() -> void:
	_pt0 = Time.get_ticks_usec()


func _tail() -> void:
	if timing:
		frame_us.append(Time.get_ticks_usec() - _pt0)


func _part_b() -> void:
	tail_node = PhysTail.new()
	tail_node.name = "PhysTail"
	tail_node.process_physics_priority = 1 << 30
	tail_node.on_tail = _tail
	root.add_child(tail_node)
	physics_frame.connect(_on_phys)
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", true)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	await _frames(30)
	course = DriftCourse.rach_ham()
	bike = fr.get("bike")
	_clearance()
	await _part_music()
	var peds: Node = fr.get("pedestrians")
	if peds:
		peds.process_mode = Node.PROCESS_MODE_DISABLED   # the bots race with no crowd (deterministic)
	await _bot_run("good", {"k": 1.25, "drift": true, "nitro": true, "kick": true}, 0)
	await _bot_run("stop", {"k": 1.0, "drift": false, "nitro": false, "kick": false, "stop_at": 140.0}, 1)
	fr.queue_free()
	await _frames(3)


func _free_at(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, rq: PhysicsRayQueryParameters3D, p: Vector2) -> bool:
	rq.from = Vector3(p.x, 30.0, p.y)
	rq.to = Vector3(p.x, -10.0, p.y)
	var hit: Dictionary = space.intersect_ray(rq)
	if hit.is_empty():
		return false
	var y: float = (hit["position"] as Vector3).y
	if y > 4.0 or y < -0.15:
		return false
	q.transform = Transform3D(Basis(), Vector3(p.x, y + 0.9, p.y))
	return space.intersect_shape(q, 1).is_empty()


## The racing line in the real world: on the floor (the bridge deck's hump included) with at least 1.2 m clear on both
## sides from the grid to the finish.
func _clearance() -> void:
	var space: PhysicsDirectSpaceState3D = fr.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.4
	q.shape = sh
	var rq := PhysicsRayQueryParameters3D.new()
	var ex: Array[RID] = [bike.get_rid(), (fr.get("player") as CollisionObject3D).get_rid()]
	rq.exclude = ex
	q.exclude = ex
	var tight: Array = []
	var s: float = 0.0
	while s < course.length:
		var p: Vector2 = course.point(s)
		var n: Vector2 = course.right(s)
		if not _free_at(space, q, rq, p) or not _free_at(space, q, rq, p + n * 1.2) or not _free_at(space, q, rq, p - n * 1.2):
			tight.append(int(s))
		s += 2.0
	_check(tight.is_empty(), "the racing line has 1.2 m clear on both sides all the way (tight at s %s)" % str(tight))


func _silent(secs: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var d := PackedByteArray()
	d.resize(int(secs * 22050.0) * 2)
	w.data = d
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = int(secs * 22050.0)
	return w


## MissionDriftDuel's music: with the drift track the chase track fades out over the countdown and the drift track starts
## on GO with fade 0; without it the chase track keeps playing through everything.
func _part_music() -> void:
	var fx: Node = root.get_node_or_null("GameFX")
	var md: MusicDirector = fx.get("music") if fx else null
	if md == null:
		_check(false, "GameFX music director")
		return
	MusicDirector.test_streams[MissionDriftDuel.DRIFT_SLOT] = _silent(4.0)
	MusicDirector.test_streams[MissionDriftDuel.CHASE_SLOT] = _silent(4.0)
	MusicDirector.test_streams["mission_bike_chase_b"] = _silent(4.0)
	for c: int in 3:
		MissionDriftDuel.force_no_track = c >= 1
		var chase_slot: String = "mission_bike_chase_b" if c == 2 else MissionDriftDuel.CHASE_SLOT
		md.play(chase_slot, 0.0)
		var m := MissionDriftDuel.new()
		fr.add_child(m)
		m.setup(fr, StoryMissions.beat("d2_drift"), {"intro": false})
		m.begin()
		await _frames(3)
		if c == 0:
			_check(MissionDriftDuel.drift_slot() == "race_d2_drift" and m.duel.state == "countdown" and m.music_fades == 1 and md.target_gain == 0.0,
				"with the drift track: the chase track fades out over the countdown (no music under it)")
			var pp: DriftRaceProps = m.duel.props
			_check(pp.member_count >= 30 and pp.dropped_members <= pp.member_count / 2, "the pack stands on free ground (%d kept, %d dropped by walls)" % [pp.member_count, pp.dropped_members])
		else:
			_check(MissionDriftDuel.drift_slot() == "mission_bike_chase" and md.slot == chase_slot and md.target_gain == 1.0 and m.music_fades == 0,
				"without the drift track: the chase track (%s) keeps playing through the countdown" % chase_slot)
		var n: int = 0
		while m.duel.state == "countdown" and n < 240:
			await _frames(1)
			n += 1
		await _frames(1)
		if c == 0:
			_check(md.slot == "race_d2_drift" and is_zero_approx(md.fade_time) and is_equal_approx(md.gains[md.cur], 1.0) and m.music_starts == 1,
				"GO: race_d2_drift starts at once (fade 0), its first bar on the launch")
			_check(bool(fr.get("mounted")) and String(fr.call("_hint_text")) == DriftDuel.T_RIDING and (fr.get("traffic") as RoamTraffic).active_count() == 0,
				"during the race: riding, the race's hint, the traffic parked")
		else:
			_check(md.slot == chase_slot and md.target_gain == 1.0, "GO without the drift track: still %s (no crossfade back)" % chase_slot)
		m.abort()
		await _frames(3)
		_check(String(fr.get("riding_hint")) == "" and String(fr.get("dismount_refusal")) == "" and (fr.get("traffic") as RoamTraffic).is_physics_processing(),
			"the race gone: hint, [F] and traffic given back")
	MissionDriftDuel.force_no_track = false
	MusicDirector.test_streams.erase(MissionDriftDuel.DRIFT_SLOT)
	MusicDirector.test_streams.erase(MissionDriftDuel.CHASE_SLOT)
	MusicDirector.test_streams.erase("mission_bike_chase_b")
	md.stop(false)


## A test bot on the real bike in FreeRoam: it steers for the line ahead, holds the rival's profile x k, drifts the
## corners, fires nitro on straights and kicks Sói Xám when he is alongside (a counter in his last 0.2 s).
func _bot(cfg: Dictionary) -> void:
	var bp := Vector2(bike.global_position.x, bike.global_position.z)
	var s: float = duel.s_p
	var v: float = bike.current_speed_ms
	var look: float = clampf(v * 0.45, 4.0, 12.0)
	var tgt: Vector2 = course.world(s + look, 0.0)
	var z: Vector3 = bike.global_transform.basis.z
	var f := Vector2(-z.x, -z.z).normalized()
	var to: Vector2 = (tgt - bp).normalized()
	var ang: float = atan2(f.x * to.y - f.y * to.x, f.dot(to))
	var st: float = clampf(ang * 3.0, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if st < -0.02:
		Input.action_press("steer_left", -st)
	elif st > 0.02:
		Input.action_press("steer_right", st)
	var rr: float = minf(course.radius_at(s + 6.0), course.radius_at(s + 12.0))
	var vt: float = 40.0
	if rr < 30.0:
		vt = maxf(8.0, course.speed_at(s + 8.0) * float(cfg["k"])) if bool(cfg["drift"]) else maxf(4.0, 0.45 * rr)
	if cfg.has("stop_at") and s > float(cfg["stop_at"]):
		vt = 0.0
	Input.action_release("gas")
	Input.action_release("brake")
	if v < vt - 0.3:
		Input.action_press("gas")
	elif v > vt + 1.5:
		Input.action_press("brake", clampf((v - vt) / 6.0, 0.2, 1.0))
	var want_drift: bool = bool(cfg["drift"]) and course.corner_at(s + 3.0) >= 0 and rr < 30.0 and v > 8.0 and absf(ang) > 0.04
	if want_drift:
		Input.action_press("drift")
	else:
		Input.action_release("drift")
	if _nitro_hold > 0:
		_nitro_hold -= 1
		if _nitro_hold == 0:
			Input.action_release("nitro")
	elif bool(cfg["nitro"]) and bike.drift_charge >= PlayerBike.NITRO_MIN and course.radius_at(s + 25.0) > 150.0 and course.radius_at(s + 50.0) > 150.0 and not bike.nitro_active():
		Input.action_press("nitro")
		_nitro_hold = 3
	if bool(cfg.get("kick", false)) and duel.combat.can_kick():
		var r: DriftRival = duel.rival
		var rel_s: float = r.s - s
		var rel_d: float = r.d - duel.d_p
		var tth: float = r.time_to_hit()
		if absf(rel_s) < 1.6 and absf(rel_d) > 0.6 and absf(rel_d) < 2.6 and (r.kickable() and (tth < 0.0 or tth <= 0.2)):
			duel.combat.kick(1 if rel_d > 0.0 else -1)


## expect: 0 = wins, 1 = beaten (stops dead at stop_at).
func _bot_run(name: String, cfg: Dictionary, expect: int) -> void:
	duel = DriftDuel.new()
	duel.name = "BotDuel_" + name
	fr.add_child(duel)
	duel.setup({"roam": fr, "intro": false})
	var res: Dictionary = {}
	duel.won.connect(func(how: String) -> void: res["won"] = how)
	duel.lost.connect(func(r: String) -> void: res["lost"] = r)
	duel.start()
	var n: int = 0
	while duel.state == "countdown" and n < 400:
		await _frames(1)
		n += 1
	var nitros0: int = bike.nitro_count
	var measured: bool = false
	n = 0
	var cap: int = int(cfg.get("frames", 9000))
	while res.is_empty() and n < cap:
		_bot(cfg)
		if name == "good" and not measured and duel.race_t > 12.0:
			measured = true
			await _measure(cfg)
		await _frames(1)
		n += 1
		if OS.has_environment("DRIFT_BOT_TRACE") and n % 60 == 0:
			print("    %s t %.0f s_p %.0f d %.1f v %.1f gap %.0f band %.2f st %.0f" % [name, duel.race_t, duel.s_p, duel.d_p, bike.current_speed_ms, duel.gap(), duel.rival.band, duel.combat.stability])
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro"]:
		Input.action_release(a)
	var outcome: String = ("won " + String(res.get("won", ""))) if res.has("won") else ("lost " + String(res.get("lost", "?")))
	print("  BOT %s: %s after %.1f s, gap %.0f..%.0f m, lead %.1f s, resets %d, corner bonuses %d, nitros %d, stability %d, his kicks %d (%d hit), my kicks on him %d, wobbles %d, blocks %d, contacts %d; Soi Xam drifted %.1f s, %d nitro bursts" % [
		name, outcome, duel.race_t, duel.min_gap, duel.max_gap, duel.lead_t, duel.resets, duel.corner_bonuses, bike.nitro_count - nitros0,
		int(duel.combat.stability), duel.rival.kicks, duel.rival.kick_hits, duel.rival.hits_total, duel.rival.wobbles, duel.rival.blocks,
		duel.contacts, duel.rival.drift_time, duel.rival.nitros])
	if expect == 0:
		_check(res.has("won") and duel.resets <= 1, "the good bot wins the race (%s, resets %d)" % [str(res), duel.resets])
		_check(duel.race_t > 60.0 and duel.race_t < 110.0, "the good bot's race: %.1f s" % duel.race_t)
		_check(duel.rival.drift_time > 3.0, "Sói Xám drifts the corners (%.1f s)" % duel.rival.drift_time)
		_check(bike.nitro_count - nitros0 >= 1 and duel.corner_bonuses >= 3, "drift corners charge nitro and the bot fires it")
	elif expect == 1:
		_check(String(res.get("lost", "")) == "beaten", "a rider who stops is beaten to the line (%s)" % str(res))
		_check(duel.rival.kicks >= 1, "Sói Xám kicks a rider he passes (%d kicks)" % duel.rival.kicks)
	duel.stop()
	duel.queue_free()
	await _frames(3)


## 120 physics frames of the good bot's race: the race's own tick (stepped by hand, timed) and the whole physics frame.
func _measure(cfg: Dictionary) -> void:
	duel.process_mode = Node.PROCESS_MODE_DISABLED
	duel_us.clear()
	frame_us.clear()
	timing = true
	for i: int in 120:
		_bot(cfg)
		await _frames(1)
		var t0: int = Time.get_ticks_usec()
		duel._physics_process(DT)
		duel_us.append(Time.get_ticks_usec() - t0)
	timing = false
	duel.process_mode = Node.PROCESS_MODE_INHERIT
	var a: PackedInt32Array = duel_us.duplicate()
	a.sort()
	var b: PackedInt32Array = frame_us.duplicate()
	b.sort()
	var dm: float = float(a[a.size() / 2]) / 1000.0
	var fm: float = float(b[b.size() / 2]) / 1000.0
	print("  PERF race tick (rival, rules, props, HUD): median %.3f ms, max %.3f ms; whole physics frame median %.2f ms (FreeRoam, crowd off)" % [dm, float(a[a.size() - 1]) / 1000.0, fm])
	_check(dm < 0.6, "the race's own tick stays light (median %.3f ms)" % dm)


func _finish() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro", "duck"]:
		Input.action_release(a)
	PlayerBike.clear_owner_sfx()
	PlayerBike.sfx_dir = "user://sfx/"
	MissionDriftDuel.force_no_track = false
	Difficulty.set_easy(false)
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("SUCCESS: DRIFT DUEL (race course, countdown + revs, corners charge nitro, his kicks / blocks / wobble, laps + lap 2 retry, losses, resets, the win with fireworks, FreeRoam bots, music)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
