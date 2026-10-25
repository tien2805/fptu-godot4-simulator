# File: res://tests/test_cine_replay.gd
# Headless test of the short replay (spec A1-D18) with scripted actors (combat arrives in Phase B): the recorder keeps the
# last seconds of transforms and bone poses; a 5 s replay lasts exactly 300 steps of 1/60, pauses the game, shows the actor
# where it was at the blow when the slow-motion impact plays, cuts orbit -> low -> wide, then restores the live state, the
# camera and the pause; length clamps to 4-6 s; hold-Esc skips; no footage -> no replay. Plan review corrections: the
# replays run at frame 185 (>= 1 s of footage after the mark, so the impact sits at 55 % = 2.75 s) and the expected impact
# is also computed from replay_clock (M6); the real-time loop advances by the full dt (M5); a replay removed mid-play
# clears cinematic_active and the pause (Minor 3). H-D8: no synthesized sting: without a slot (or without the owner's file)
# the replay is silent. Independent of user://music (no slot is passed; the slot case uses a name with no file).
# Run:  godot --headless --path . --script tests/test_cine_replay.gd
extends SceneTree

const RUN_FRAME: int = 185

var fails: Array[String] = []
var frames: int = 0
var world: Node3D
var a: Node3D
var b: Node3D
var cam: Camera3D
var rec: CineReplayRecorder
var pos_mark: Vector3
var done: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _sm() -> Node:
	return root.get_node_or_null("StageManager")


func _initialize() -> void:
	print("--- TEST CINE REPLAY ---")
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		CineRetarget.disabled = PackedStringArray(["mixamo"])
		print("  CINE_NO_MIXAMO=1: mixamo source disabled")
	Engine.max_fps = 60
	world = Node3D.new()
	root.add_child(world)
	a = CharacterBuilder.build({"preset": "player", "seed": 21, "rigged": true})
	b = CharacterBuilder.build({"preset": "rider", "seed": 22, "rigged": true})
	world.add_child(a)
	world.add_child(b)
	b.position = Vector3(6.0, 0.0, 0.0)
	cam = Camera3D.new()
	cam.name = "GameCam"
	world.add_child(cam)
	cam.position = Vector3(0.0, 3.0, 8.0)
	rec = CineReplayRecorder.new()
	world.add_child(rec)
	rec.track(a)
	rec.track(b)
	CharacterBuilder.set_speed(a, 3.0)


func _physics_process(_d: float) -> bool:
	if done:
		return true
	frames += 1
	if frames == 1:
		cam.make_current()
	if frames < RUN_FRAME:
		a.position.x += 3.0 / 60.0           # scripted runner (physics frames are 1/60 s)
	if frames == 120:
		rec.mark("blow")
		pos_mark = a.global_position
	if frames == RUN_FRAME:
		_run_replays()
	if frames == RUN_FRAME + 30:             # the audio thread releases stopped playbacks late: quitting at once reports leaks
		done = true
		if fails.is_empty():
			print("✅ SUCCESS: CINE REPLAY (exact length, pause, recorded poses, shots, restore, clamp, skip)")
			quit(0)
		else:
			print("❌ FAILED: %d issues" % fails.size())
			quit(1)
	return false


func _run_replays() -> void:
	_check(rec.frame_count() >= 60, "recorder holds frames (%d)" % rec.frame_count())
	var live_pos: Vector3 = a.global_position
	var sk: Skeleton3D = a.get_meta("skeleton") as Skeleton3D
	var arm: int = sk.find_bone("UpperArm.L")
	var live_arm: Quaternion = sk.get_bone_pose_rotation(arm)
	var rec_clock0: float = rec.clock
	var f: float = float(rec.marks["blow"])
	var want: Dictionary = CineReplayRecorder.replay_clock(5.0, f, rec.newest_time() - f)
	var want_hit: float = float((want["clock"] as CineClock).ramp("focus")["r_hit"])
	var rp := CineReplay.new()
	world.add_child(rp)
	var ok: bool = rp.start(rec, {"length": 5.0, "manual": true, "focus": a, "other": b})
	_check(ok, "replay starts")
	_check(paused, "game paused during the replay")
	_check(get_root().get_viewport().get_camera_3d() == rp.camera, "replay camera is current")
	var sm: Node = _sm()
	if sm:
		_check(bool(sm.get("cinematic_active")), "cinematic_active set during the replay")
	var r_hit: float = float(rp.clock.ramp("focus")["r_hit"])
	var shots: Dictionary = {}
	var at_hit: float = -1.0
	var ended: Array = [false]
	rp.finished.connect(func() -> void: ended[0] = true)
	var n: int = 0
	while not ended[0] and n < 400:
		var before: float = rp.r
		rp.step(1.0 / 60.0)
		n += 1
		shots[rp.phase_shot] = true
		if before < r_hit and rp.r >= r_hit:
			at_hit = a.global_position.distance_to(pos_mark)
	print("  replay: %d steps, impact at %.4f s (replay_clock %.4f), blow offset at the impact %.4f m, footage after the mark %.3f s" % [n, r_hit, want_hit, at_hit, rec.newest_time() - f])
	_check(absi(n - 300) <= 1, "5 s replay = 300 steps (%d)" % n)
	_check(absf(r_hit - want_hit) < 1e-6, "impact where replay_clock puts it (%.4f vs %.4f)" % [r_hit, want_hit])
	_check(absf(r_hit - 2.75) < 0.01, "impact at 55 %% of the length (%.3f s)" % r_hit)
	_check(at_hit >= 0.0 and at_hit < 0.1, "actor at its recorded blow position when the impact plays (%.3f m)" % at_hit)
	_check(shots.has("orbit") and shots.has("low") and shots.has("wide"), "orbit, low and wide shots used: %s" % str(shots.keys()))
	_check(not paused, "game unpaused after the replay")
	_check(a.global_position.distance_to(live_pos) < 1e-3, "live position restored")
	_check(sk.get_bone_pose_rotation(arm).is_equal_approx(live_arm), "live bone pose restored")
	_check(get_root().get_viewport().get_camera_3d() == cam, "game camera current again")
	_check(is_equal_approx(rec.clock, rec_clock0), "recorder did not record while paused")
	if sm:
		_check(not bool(sm.get("cinematic_active")), "cinematic_active cleared after the replay")
	# length clamp + hold-Esc skip
	var rp2 := CineReplay.new()
	world.add_child(rp2)
	rp2.start(rec, {"length": 9.0, "manual": true})
	_check(is_equal_approx(rp2.length, 6.0), "length clamps to 6 s")
	rp2.force_skip_hold = true
	var ended2: Array = [false]
	rp2.finished.connect(func() -> void: ended2[0] = true)
	var m: int = 0
	while not ended2[0] and m < 200:
		rp2.step(1.0 / 60.0)
		m += 1
	_check(ended2[0] and m <= 52, "hold Esc skips the replay (%d steps)" % m)
	_check(not paused, "unpaused after the skip")
	# no footage -> no replay
	var empty := CineReplayRecorder.new()
	world.add_child(empty)
	var rp3 := CineReplay.new()
	world.add_child(rp3)
	_check(not rp3.start(empty, {"manual": true}), "no footage -> no replay")
	_check(not paused, "and the game is not paused")
	rp3.queue_free()
	empty.queue_free()
	# H-D8: no synthesized sting; no slot -> silent, a slot without an owner file -> silent
	var probe := CineReplay.new()
	_check(probe.has_method("start") and not probe.has_method("sting"), "CineReplay has no synthesized sting any more")
	probe.free()
	var rp_a := CineReplay.new()
	world.add_child(rp_a)
	_check(rp_a.start(rec, {"length": 4.0, "manual": true}), "a replay without a slot still plays")
	_check(rp_a.music.stream == null and not rp_a.music.playing, "no slot -> the replay is silent (no code music)")
	rp_a.force_skip_hold = true
	for i: int in 60:
		rp_a.step(1.0 / 60.0)
	var rp_b := CineReplay.new()
	world.add_child(rp_b)
	rp_b.start(rec, {"length": 4.0, "manual": true, "slot": "hd8_no_such_replay_slot"})
	_check(rp_b.music.stream == null and not rp_b.music.playing, "a slot with no owner file -> silent")
	# real-time loop: full dt, no clamp (M5) - a 300 ms hitch advances r by >= 0.29 s
	rp_b.manual = false
	rp_b._last_us = Time.get_ticks_usec()
	var r_before: float = rp_b.r
	OS.delay_msec(300)
	rp_b._process(0.0)
	_check(rp_b.r - r_before >= 0.29, "real-time loop advances by the full dt through a hitch (%.3f s)" % (rp_b.r - r_before))
	# removed mid-replay: pause, camera and cinematic_active are released (Minor 3)
	_check(paused, "paused while the second replay plays")
	world.remove_child(rp_b)
	_check(not paused, "a replay removed mid-play unpauses the game")
	_check(get_root().get_viewport().get_camera_3d() == cam, "and gives the camera back")
	if sm:
		_check(not bool(sm.get("cinematic_active")), "and clears cinematic_active")
	_check(a.global_position.distance_to(live_pos) < 1e-3, "and restores the live state")
	rp_b.free()
