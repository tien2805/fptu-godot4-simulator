# File: res://tests/test_drift_duel.gd
# Headless test of the Day 2 drift duel with Sói Xám (spec D2X-10, plan 2026-10-27-d2x-drift.md).
# Part A, a flat arena under the course (no FreeRoam; the bike locked and moved along the line by the test):
#   the course data (closed lap ~1 km, 7 gates + the finish, 8 drift zones, the tightest radius, the rival's lap); the
#   hooks (duel profile, nitro on, all given back on stop); the countdown (a rev on each count at 0 / 1 / 2 s, Sói Xám
#   answering 0.5 s later, GO at 3 s, the music cue once at GO); gates passed in order; losing on the gap (> 40 m for 3 s)
#   and the quick retry (fade 0.4 s, a 2 s countdown, the grid again); drift points only inside the zones and doubled
#   while tailing; winning on points at the finish, losing on points; winning by staying ahead 4 s; off the course and the
#   wrong way reset to the last gate with the grace; a knocked cone; the rubber band; the time scale left at 1.
# Part B, FreeRoam (crowd off): the course corridor is clear of the real world (the bridge deck's parapets aside), the
#   traffic is parked and comes back, MissionDriftDuel's music (the drift track on GO with fade 0, the old track faded
#   over the countdown; the chase-track fallback), test bots on the real bike: a good bot wins, a slow bot loses on the
#   gap; lap time, gap range, points and the duel's own cost are printed (plan "Tuning").
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
	print("--- TEST DRIFT DUEL (Sói Xám, Cầu Rạch Hầm) ---")
	PlayerBike.sfx_dir = OS.get_cache_dir().replace("\\", "/").trim_suffix("/") + "/fptu_test_drift_no_sfx/"
	PlayerBike.clear_owner_sfx()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _count(name: String) -> void:
	sig[name] = int(sig.get(name, 0)) + 1


## The test's "rider": the bike locked and set on the line at drive_s (lateral d) facing along it, moving at v.
func _drive_to(s: float, d: float = 0.0, v: float = 18.0, backwards: bool = false) -> void:
	drive_s = s
	var p: Vector2 = course.world(s, d)
	var y: Variant = duel.floor_at(Vector3(p.x, 0.0, p.y), 20.0, 20.0)
	bike.global_position = Vector3(p.x, (float(y) if y is float else 0.0) - DriftDuel.BIKE_FLOOR_OFFSET, p.y)
	bike.rotation = Vector3(0.0, course.yaw_at(s) + (PI if backwards else 0.0), 0.0)
	bike.current_speed_ms = v


func _run() -> void:
	await _frames(1)
	await _part_a()
	if arena and is_instance_valid(arena):
		arena.free()
	await _frames(2)
	await _part_b()
	_finish()


# ---------------------------------------------------------------------------
# PART A
# ---------------------------------------------------------------------------
func _part_a() -> void:
	course = DriftCourse.rach_ham()
	_check(course.length > 1250.0 and course.length < 1450.0, "the lap is about 1.3 km (%.0f m)" % course.length)
	_check(course.gates.size() == 8 and course.zones.size() >= 5, "8 gates + the finish, %d drift zones (at least 5)" % course.zones.size())
	_check(course.point(0.0).distance_to(course.point(course.length)) < 0.01, "a closed lap: the finish is the start")
	_check(course.min_radius() > 7.0, "the tightest corner radius %.1f m (the bike's drift circle is 8.4 m)" % course.min_radius())
	var lap: float = 0.0
	var s: float = 0.0
	while s < course.length:
		lap += 2.0 / maxf(course.speed_at(s), 1.0)
		s += 2.0
	_check(lap > 50.0 and lap < 70.0, "the rival's full-pace lap is %.1f s (the spec's 50-75 s)" % lap)
	var pr: Vector2 = course.project_near(course.world(300.0, 2.0), 290.0)
	_check(absf(pr.x - 300.0) < 0.5 and absf(pr.y - 2.0) < 0.05, "project_near: s and the lateral offset (%.2f, %.2f)" % [pr.x, pr.y])
	var pe: Vector2 = course.project_near(course.world(3.0, 0.0), course.length - 4.0)
	_check(pe.x > course.length, "project_near unwraps over the finish (%.1f > %.1f)" % [pe.x, course.length])
	_check(DriftDuel.band_for(35.0, false) < 0.6 and DriftDuel.band_for(20.0, false) == 1.0 and DriftDuel.band_for(-3.0, false) > 1.05 and DriftDuel.band_for(10.0, true) < 0.5,
		"the rubber band: he waits past 30 m, fights back when passed, waits during a reset's grace")
	var texts: Array[String] = [DriftDuel.T_START, DriftDuel.T_END, DriftDuel.T_GO, DriftDuel.T_TAIL, DriftDuel.T_OVERTAKE, DriftDuel.T_FAR,
		DriftDuel.T_LOSE_GAP, DriftDuel.T_LOSE_POINTS, DriftDuel.T_WIN_POINTS, DriftDuel.T_OFF, DriftDuel.T_WRONG, DriftDuel.T_GATE,
		DriftDuel.T_ZONE, DriftDuel.T_CONE, DriftDuel.T_POINTS, DriftDuel.T_GAP, DriftDuel.T_AHEAD, DriftDuel.T_RIDING,
		DriftDuel.T_NO_DISMOUNT, DriftRival.NAME, DriftRival.T_CLOSE, DriftRival.T_FAR, NitroGauge.T_TITLE, NitroGauge.T_READY,
		NitroGauge.T_HINT, String(StoryMissions.beat("d2_drift")["objective"]), String(StoryMissions.beat("d2_drift")["title"])]
	texts.append_array(DriftRival.TAUNTS)
	for z: Array in course.zones:
		texts.append(String(z[2]))
	var odd: Array = []
	for tx: String in texts:
		for i: int in tx.length():
			if tx.unicode_at(i) >= 0x2000:
				odd.append(tx)
				break
	_check(odd.is_empty(), "every duel / gauge text is plain Vietnamese, no emoji or decorative symbols %s" % str(odd))
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(800.0, 1.0, 800.0)
	cs.shape = bs
	floor.add_child(cs)
	floor.position = Vector3(2125.0, -0.5, 10.0)
	arena.add_child(floor)
	bike = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
	arena.add_child(bike)
	bike.apply_speed_profile(PlayerBike.OWNER_PROFILE)
	bike.chase_cam.make_current()
	duel = DriftDuel.new()
	duel.name = "Duel"
	arena.add_child(duel)
	duel.setup({"bike": bike, "intro": false, "target": 300.0, "course": course})
	for n: String in ["countdown_started", "music_cue", "go", "won", "lost", "ended", "gate_passed", "reset_to_gate"]:
		duel.connect(n, func(_a: Variant = null) -> void: _count(n))
	duel.won.connect(func(how: String) -> void: sig["won_how"] = how)
	duel.lost.connect(func(r: String) -> void: sig["lost_reason"] = r)
	await _frames(2)
	_check(duel._cone_mm.multimesh.instance_count == course.cones.size() and course.cones.size() >= 30, "%d cones placed (gates, slalom, islands)" % course.cones.size())
	duel.start()
	_check(duel.state == "countdown" and bike.staged and bike.is_controls_locked, "start(): the countdown, the bike staged on the line")
	_check(is_equal_approx(bike.max_speed_ms, float(DriftDuel.DUEL_PROFILE["max_speed_ms"])) and bike.nitro_enabled and duel.hud.visible, "the duel profile (86 km/h), nitro on, the HUD")
	_check(absf(duel.rival.s - DriftDuel.RIVAL_LEAD_M) < 0.01 and absf(duel.gap() - DriftDuel.RIVAL_LEAD_M) < 0.5, "Sói Xám starts 8 m ahead (gap %.1f)" % duel.gap())
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
	_check(bike.revs - revs0 == 3 and times.size() == 3 and absf(float(times[1] - times[0]) - 60.0) <= 1.0 and absf(float(times[2] - times[0]) - 120.0) <= 1.0,
		"a rev on each count, 1 s apart (frames %s)" % str(times))
	_check(ans.size() == 3 and absf(float(ans[0] - times[0]) - 30.0) <= 1.0 and absf(float(ans[2] - times[2]) - 30.0) <= 1.0, "Sói Xám answers each count 0.5 s later (frames %s)" % str(ans))
	_check(go_f >= 0 and absf(float(go_f - times[0]) - 180.0) <= 1.0 and int(sig.get("go", 0)) == 1 and int(sig.get("music_cue", 0)) == 1, "GO 3 s after the first count, the music cue once with it (frame %d)" % go_f)
	_check(not bike.staged and not bike.is_controls_locked and duel.rival.racing, "GO: the bike rides, he races")
	_check(duel.rival.revs == 3 and duel.rival.rev_source == "blip", "without the owner's rev file he blips his exhaust loop")
	# gap lose: the player stays put
	bike.is_controls_locked = true
	_drive_to(0.0, 0.0, 0.0)
	var n: int = 0
	while duel.state == "racing" and n < 1200:
		await _frames(1)
		_drive_to(0.0, 0.0, 0.0)
		n += 1
	_check(duel.state == "lost" and String(sig.get("lost_reason", "")) == "gap" and duel.losses == 1, "left behind: lost on the gap after %.1f s (gap %.0f m)" % [float(n) / 60.0, duel.gap()])
	_check(duel.max_gap > DriftDuel.LOSE_GAP_M and duel.max_gap < 70.0, "stopped dead: he waits (band) but the gap passes 40 m, max %.0f m" % duel.max_gap)
	var lost_f: int = 0
	while duel.state != "countdown" and lost_f < 200:
		await _frames(1)
		lost_f += 1
	_check(duel.state == "countdown" and duel.retry_count and absf(duel.countdown_len - DriftDuel.RETRY_COUNTDOWN_S) < 0.01, "a quick retry by itself: a 2 s countdown")
	_check(absf(float(lost_f) / 60.0 - (DriftDuel.LOSE_PAUSE_S + DriftDuel.FADE_S)) < 0.1, "back on the grid %.2f s after the loss (pause %.1f s + a %.1f s fade)" % [float(lost_f) / 60.0, DriftDuel.LOSE_PAUSE_S, DriftDuel.FADE_S])
	_check(absf(duel.rival.s - DriftDuel.RIVAL_LEAD_M) < 0.01 and duel.points == 0.0 and duel.gate_i == 0 and absf(duel.s_p) < 1.0, "the grid again: he is 8 m ahead, points and gates reset")
	var cf: int = 0
	while duel.state == "countdown" and cf < 200:
		await _frames(1)
		cf += 1
	_check(absf(float(cf) / 60.0 - 2.0) < 0.1 and duel.state == "racing" and int(sig.get("go", 0)) == 2, "the retry's GO after 2 s (%.2f s)" % (float(cf) / 60.0))
	# tail the rival 10 m behind through the lap, drifting: gates in order, points only in zones (doubled), win on points
	bike.is_controls_locked = true
	var gates_seen: Array = []
	duel.gate_passed.connect(func(i: int) -> void: gates_seen.append(i))
	var pts_outside: bool = false
	var tail_ok: bool = true
	n = 0
	drive_s = 0.0
	while duel.state == "racing" and n < 4000:
		var tgt: float = maxf(drive_s, duel.rival.s - 10.0)
		if duel.rival.finished:
			tgt = drive_s + 0.4
		var in_zone: bool = course.zone_at(course.wrap_s(tgt)) >= 0
		duel.force_drift = 1
		var p0: float = duel.points
		_drive_to(tgt, 0.0, 15.0)
		await _frames(1)
		if not in_zone and duel.points > p0 + 0.001 and course.zone_at(course.wrap_s(duel.s_p)) < 0:
			pts_outside = true
		if in_zone and duel.state == "racing" and absf(duel.gap() - 10.0) < 1.0 and duel.points > p0:
			var per: float = (duel.points - p0) / (15.0 * DT * DriftDuel.POINTS_PER)
			tail_ok = tail_ok and absf(per - 2.0) < 0.6
		n += 1
	duel.force_drift = -1
	_check(gates_seen == [0, 1, 2, 3, 4, 5, 6, 7], "every gate passed in order %s" % str(gates_seen))
	_check(not pts_outside, "no drift points outside the zones")
	_check(tail_ok and duel.tail_t > 20.0, "tailing within 12 m doubles the points (tailed %.0f s)" % duel.tail_t)
	_check(duel.state == "won" and String(sig.get("won_how", "")) == "points" and duel.points >= 300.0, "the finish with the target: won on points (%.0f)" % duel.points)
	_check(duel.race_t > 50.0 and duel.race_t < 75.0, "the tailed lap took %.1f s" % duel.race_t)
	# the ending: his line, he rides down off the deck, a fade, ended
	n = 0
	while int(sig.get("ended", 0)) == 0 and n < 900:
		await _frames(1)
		n += 1
	_check(int(sig.get("ended", 0)) == 1 and duel.state == "done" and duel.rival.exit_done() and duel.subtitle_text.contains(DriftDuel.T_END), "the ending: his line, he rides down under the bridge, the fade, ended (%.1f s)" % (float(n) / 60.0))
	_check(not bike.is_controls_locked and is_equal_approx(bike.max_speed_ms, 33.3), "after the duel the bike rides again on its own profile")
	# a fresh duel: lose on points at the finish, the overtake win, off course and wrong way, a cone
	duel.queue_free()
	await _frames(2)
	duel = DriftDuel.new()
	duel.name = "Duel2"
	arena.add_child(duel)
	duel.setup({"bike": bike, "intro": false, "target": 1.0e9, "course": course})
	duel.won.connect(func(how: String) -> void: sig["won_how2"] = how)
	duel.lost.connect(func(r: String) -> void: sig["lost_reason2"] = r)
	var resets: Array = []
	duel.reset_to_gate.connect(func(i: int) -> void: resets.append(i))
	await _frames(2)
	duel.start()
	await _frames(185)
	_check(duel.state == "racing", "second duel racing")
	bike.is_controls_locked = true
	# drive to just past gate 1, then off the course sideways
	n = 0
	drive_s = 0.0
	while drive_s < course.gates[1] + 6.0 and n < 3000:
		_drive_to(maxf(drive_s, minf(duel.rival.s - 10.0, drive_s + 1.0)), 0.0, 15.0)
		await _frames(1)
		n += 1
	_check(duel.gate_i == 2, "test setup: past gate 2 (%d)" % duel.gate_i)
	var off_f: int = 0
	while resets.is_empty() and off_f < 200:
		_drive_to(drive_s, 20.0, 0.0)
		await _frames(1)
		off_f += 1
	await _frames(20)
	var at: Vector2 = Vector2(bike.global_position.x, bike.global_position.z)
	_check(resets == [1] and absf(float(off_f) / 60.0 - DriftDuel.OFF_COURSE_S - DriftDuel.FADE_S) < 0.1 and at.distance_to(course.world(course.gates[1], 0.0)) < 1.5,
		"20 m off the line for 1.2 s: back at the last gate behind a 0.2 s fade (%s after %.2f s)" % [str(resets), float(off_f) / 60.0])
	_check(duel.grace_t > 2.0 and duel.rival.band < 1.0, "a reset gives 3 s of grace, he waits (band %.2f)" % duel.rival.band)
	# wrong way
	resets.clear()
	var ww: int = 0
	drive_s = course.gates[1]
	while resets.is_empty() and ww < 300:
		_drive_to(drive_s - 0.15, 0.0, 9.0, true)
		bike.velocity = -Vector3(course.tangent(drive_s).x, 0.0, course.tangent(drive_s).y) * 9.0
		await _frames(1)
		ww += 1
	await _frames(20)
	_check(resets == [1] and absf(float(ww) / 60.0 - DriftDuel.WRONG_WAY_S - DriftDuel.FADE_S) < 0.1, "riding the wrong way 1.5 s: back at the last gate behind the fade (%.2f s)" % (float(ww) / 60.0))
	# a cone: the chicane B cone gate
	var cone: Vector2 = course.cones[6]
	var k0: int = duel.knocked_cones
	duel.points = 100.0
	bike.global_position = Vector3(cone.x, -0.1, cone.y)
	await _frames(2)
	_check(duel.knocked_cones == k0 + 1 and absf(duel.points - (100.0 - DriftDuel.CONE_PENALTY)) < 1.0, "a cone the bike touches flies off and costs %d points" % int(DriftDuel.CONE_PENALTY))
	# overtake: 5 m ahead of him for 4 s
	_drive_to(duel.rival.s, 0.0, 15.0)
	await _frames(2)
	n = 0
	while duel.state == "racing" and n < 600:
		_drive_to(duel.rival.s + 5.0, 0.0, 15.0)
		await _frames(1)
		n += 1
	_check(duel.state == "won" and String(sig.get("won_how2", "")) == "overtake" and absf(float(n) / 60.0 - DriftDuel.OVERTAKE_S) < 0.3, "ahead of him for 4 s: VƯỢT MẶT, an instant win (%.2f s)" % (float(n) / 60.0))
	duel.stop()
	_check(is_equal_approx(bike.max_speed_ms, 33.3) and not bike.staged and is_equal_approx(bike.drift_charge_mult, 1.0), "stop(): the profile and the zone multiplier given back")
	# losing on points at the finish (a third duel, the target out of reach)
	duel.queue_free()
	await _frames(2)
	duel = DriftDuel.new()
	duel.name = "Duel3"
	arena.add_child(duel)
	duel.setup({"bike": bike, "intro": false, "target": 1.0e9, "course": course})
	duel.lost.connect(func(r: String) -> void: sig["lost_reason3"] = r)
	await _frames(2)
	duel.start()
	await _frames(185)
	bike.is_controls_locked = true
	n = 0
	drive_s = 0.0
	while duel.state == "racing" and n < 5000:
		var tg: float = maxf(drive_s, duel.rival.s - 10.0) if not duel.rival.finished else drive_s + 0.4
		_drive_to(tg, 0.0, 15.0)
		await _frames(1)
		n += 1
	_check(duel.state == "lost" and String(sig.get("lost_reason3", "")) == "points", "the finish without the target: lost on points")
	duel.stop()
	duel.queue_free()
	await _frames(2)
	_check(is_equal_approx(Engine.time_scale, 1.0), "the time scale is left at 1")


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
	await _bot_run("good", {"k": 1.3, "vmax": 30.0, "drift": true, "nitro": true}, 0)
	await _bot_run("medium", {"k": 1.05, "vmax": 30.0, "drift": true, "nitro": true, "drift_r": 16.0}, -1)
	await _bot_run("slow", {"k": 0.62, "vmax": 13.0, "drift": false, "nitro": false, "frames": 3600}, 1)
	await _bot_run("stop", {"k": 1.0, "vmax": 30.0, "drift": false, "nitro": false, "stop_at": 140.0}, 2)
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


## The course corridor in the real world: on the floor (the bridge deck's hump included) with at least 1.2 m clear on
## both sides of the line (the deck's parapets are 1.5-2 m off the lanes), and every cone and barrier on free ground.
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
	_check(tight.is_empty(), "the racing line has 1.2 m clear on both sides all round the lap (tight at s %s)" % str(tight))
	var bad: Array = []
	for c: Vector2 in course.cones:
		if not _free_at(space, q, rq, c):
			bad.append(c)
	for b: Array in course.barriers:
		for k: int in 5:
			var bp: Vector2 = (b[0] as Vector2).lerp(b[1], float(k) / 4.0)
			if not _free_at(space, q, rq, bp):
				bad.append(bp)
	_check(bad.is_empty(), "every cone and barrier stands on free ground (%s)" % str(bad))


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
	for c: int in 2:
		MissionDriftDuel.force_no_track = c == 1
		md.play(MissionDriftDuel.CHASE_SLOT, 0.0)
		var m := MissionDriftDuel.new()
		fr.add_child(m)
		m.setup(fr, StoryMissions.beat("d2_drift"), {"intro": false})
		m.begin()
		await _frames(3)
		if c == 0:
			_check(MissionDriftDuel.drift_slot() == "race_d2_drift" and m.duel.state == "countdown" and m.music_fades == 1 and md.target_gain == 0.0,
				"with the drift track: the chase track fades out over the countdown (no music under it)")
		else:
			_check(MissionDriftDuel.drift_slot() == "mission_bike_chase" and md.slot == "mission_bike_chase" and md.target_gain == 1.0 and m.music_fades == 0,
				"without the drift track: the chase track keeps playing through the countdown")
		var n: int = 0
		while m.duel.state == "countdown" and n < 240:
			await _frames(1)
			n += 1
		await _frames(1)
		if c == 0:
			_check(md.slot == "race_d2_drift" and is_zero_approx(md.fade_time) and is_equal_approx(md.gains[md.cur], 1.0) and m.music_starts == 1,
				"GO: race_d2_drift starts at once (fade 0), its first bar on the launch")
			_check(bool(fr.get("mounted")) and String(fr.call("_hint_text")) == DriftDuel.T_RIDING and (fr.get("traffic") as RoamTraffic).active_count() == 0,
				"during the duel: riding, the duel's hint, the traffic parked")
		else:
			_check(md.slot == "mission_bike_chase" and md.target_gain == 1.0, "GO without the drift track: still the chase track")
		m.abort()
		await _frames(3)
		_check(String(fr.get("riding_hint")) == "" and String(fr.get("dismount_refusal")) == "" and (fr.get("traffic") as RoamTraffic).is_physics_processing(),
			"the duel gone: hint, [F] and traffic given back")
	MissionDriftDuel.force_no_track = false
	MusicDirector.test_streams.erase(MissionDriftDuel.DRIFT_SLOT)
	MusicDirector.test_streams.erase(MissionDriftDuel.CHASE_SLOT)
	md.stop(false)


## A test bot on the real bike in FreeRoam: it steers for the line ahead, holds a target speed (the rival's profile x k,
## capped at vmax), drifts in the zones' tight corners and fires nitro on straights.
func _bot(cfg: Dictionary) -> void:
	var bp := Vector2(bike.global_position.x, bike.global_position.z)
	var s: float = duel.s_p
	var v: float = bike.current_speed_ms
	var look: float = clampf(v * 0.5, 3.5, 13.0)
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
	var vt: float = minf(course.speed_at(s + 8.0) * float(cfg["k"]), float(cfg["vmax"]))
	if not bool(cfg["drift"]):
		var rr: float = minf(course.radius_at(s + 4.0), course.radius_at(s + 8.0))
		if rr < 13.0:
			vt = minf(vt, maxf(3.5, 0.5 * rr))   # a careful rider brakes for what the bike turns without a drift
	if cfg.has("stop_at") and s > float(cfg["stop_at"]):
		vt = 0.0
	Input.action_release("gas")
	Input.action_release("brake")
	if v < vt - 0.3:
		Input.action_press("gas")
	elif v > vt + 1.5:
		Input.action_press("brake", clampf((v - vt) / 6.0, 0.2, 1.0))
	var in_zone: bool = course.zone_at(course.wrap_s(s + 4.0)) >= 0
	var want_drift: bool = bool(cfg["drift"]) and in_zone and course.radius_at(s + 6.0) < float(cfg.get("drift_r", 30.0)) and v > 8.0 and absf(ang) > 0.04
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


## expect: 0 = wins, 1 = finishes but loses on points (the band keeps a slow rider in reach), 2 = stops dead and loses
## on the gap.
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
	var hard: int = 0
	var prev_v: float = 0.0
	var nitros0: int = bike.nitro_count
	var measured: bool = false
	n = 0
	var cap: int = int(cfg.get("frames", 6000))
	while res.is_empty() and n < cap:
		_bot(cfg)
		if name == "good" and not measured and duel.race_t > 12.0:
			measured = true
			await _measure(cfg)
		await _frames(1)
		var v: float = bike.current_speed_ms
		if prev_v - v > 4.0:
			hard += 1
		prev_v = v
		n += 1
		if OS.has_environment("DRIFT_BOT_TRACE") and n % 60 == 0:
			print("    %s t %.0f s_p %.0f d %.1f v %.1f gap %.0f band %.2f" % [name, duel.race_t, duel.s_p, duel.d_p, v, duel.gap(), duel.rival.band])
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro"]:
		Input.action_release(a)
	var avg: float = duel.s_p / maxf(duel.race_t, 0.1)
	var outcome: String = ("won " + String(res.get("won", ""))) if res.has("won") else ("lost " + String(res.get("lost", "?")))
	print("  BOT %s: %s after %.1f s (avg %.1f m/s), points %d / %d, tailed %.1f s, gap %.0f..%.0f m, resets %d, cones %d, nitros %d, hard stops %d, drift in zones %.1f s; Soi Xam drifted %.1f s, %d nitro bursts" % [
		name, outcome, duel.race_t, avg, int(duel.points), int(duel.target), duel.tail_t, duel.min_gap, duel.max_gap, duel.resets,
		duel.knocked_cones, bike.nitro_count - nitros0, hard, duel.drift_in_zone_t, duel.rival.drift_time, duel.rival.nitros])
	if expect == 0:
		_check(res.has("won") and duel.resets == 0, "the good bot wins the duel without a reset (%s)" % str(res))
		_check(duel.rival.drift_time > 4.0, "Sói Xám drifts visibly through the tight corners (%.1f s)" % duel.rival.drift_time)
		_check(duel.race_t > 48.0 and duel.race_t < 75.0, "the good bot's lap: %.1f s (50-75 s target)" % duel.race_t)
		_check(duel.max_gap < DriftDuel.LOSE_GAP_M and duel.tail_t > 5.0, "the good bot stays within reach (max gap %.0f m) and tails him %.0f s" % [duel.max_gap, duel.tail_t])
		_check(bike.nitro_count - nitros0 >= 1, "the good bot fires nitro off its drift charge")
	elif expect == 1:
		_check(not res.has("won") and String(res.get("lost", "points")) == "points" and duel.max_gap < DriftDuel.LOSE_GAP_M,
			"the slow bot (no drift, 13 m/s) is never dropped: he waits, max gap %.0f m (%s after %.0f s)" % [duel.max_gap, str(res), duel.race_t])
	elif expect == 2:
		_check(String(res.get("lost", "")) == "gap", "a rider who stops dead loses on the gap (%s)" % str(res))
	duel.stop()
	duel.queue_free()
	await _frames(3)


## 120 physics frames of the good bot's race: the duel's own tick (stepped by hand, timed) and the whole physics frame.
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
	print("  PERF duel tick (rival, gates, points, cones, HUD): median %.3f ms, max %.3f ms; whole physics frame median %.2f ms (FreeRoam, crowd off)" % [dm, float(a[a.size() - 1]) / 1000.0, fm])
	_check(dm < 0.5, "the duel's own tick stays light (median %.3f ms)" % dm)


func _finish() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro", "duck"]:
		Input.action_release(a)
	PlayerBike.clear_owner_sfx()
	PlayerBike.sfx_dir = "user://sfx/"
	MissionDriftDuel.force_no_track = false
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("SUCCESS: DRIFT DUEL (course, countdown + revs, gates, gap lose + quick retry, points, overtake, resets, cones, FreeRoam bots, music)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
