# File: res://tests/test_basement_blackout.gd
# W3 Day 5 T2 (plan 2026-10-30-w3-day5.md, D5W-2): the blackout of the basement stealth (MissionBasementStealth in the
# StoryBasement scene, no story running). Checks: the time trigger cuts the power row by row (a clunk per row) with the
# dark look and the guards' torch cones; the LED / face / dud beats; an unalerted guard sees only inside his cone; a retry
# restores the lights; the cross-aisle trigger; the player's [F] torch makes him visible from 20 m; the power comes back
# at the goal; "Giảm hù dọa" mutes the whisper and dims the face.
# Run:  godot --headless --path . --script tests/test_basement_blackout.gd
extends SceneTree

const DT: float = 1.0 / 60.0
const BASEMENT: String = "res://scenes/story/StoryBasement.tscn"
var TMP: String = "user://test_basement_blackout_%d.cfg" % OS.get_process_id()
var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var total: int = 0
var bs: StoryBasement
var m: MissionBasementStealth
var g: Gunman
var fx: Node
var hold: Callable = Callable()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("--- TEST BASEMENT BLACKOUT (D5W-2) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	fx = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	StoryBasement.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 3}, "capture_mouse": false, "go_roam": false}


func _next(p: int) -> void:
	phase = p
	frames = 0


func _start_mission() -> MissionBasementStealth:
	_check(bs.start_mission(StoryMissions.beat("d5_stealth")), "the stealth starts in the basement")
	var mn: MissionBasementStealth = bs.mission_node as MissionBasementStealth
	for c: Dictionary in mn.done.get_connections():
		mn.done.disconnect(c["callable"])     # no story running: the test reads the result itself
	return mn


## Guard e stands at local p facing local direction fwd (patrol cleared, yaw pinned every frame through `hold`).
func _pin(e: Gunman, p: Vector3, yaw: float) -> void:
	e.patrol = PackedVector3Array()
	e.position = bs.level.world(p)
	e.yaw = yaw
	e.body.rotation.y = yaw


func _others_away(keep: Gunman) -> void:
	var i: int = 0
	for x: Variant in m.fight.alive():
		if x != keep:
			_pin(x as Gunman, Vector3(9.5 - 2.0 * i, 0.0, 6.5), 0.0)   # by the room's mouth, facing the room (-z)
			i += 1


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 6000:
		_check(false, "timeout in phase %d" % phase)
		phase = 99
	if hold.is_valid():
		hold.call()
	if m and is_instance_valid(m) and m.state == "running":
		m.advance(DT)
	match phase:
		0:
			bs = (load(BASEMENT) as PackedScene).instantiate()
			root.add_child(bs)
			_next(1)
		1:
			if frames < 3:
				return false
			m = _start_mission()
			_check(m != null and m.fight.gunmen.size() == 3, "MissionBasementStealth with 3 guards")
			_check(bs.level.power_on and bs.level.rows_lit == LairBasement.LAMP_ZS.size() and not m.blackout, "the mains on at the start")
			_check(m._props.size() == 3, "every guard wears the smart-glasses LEDs")
			_check(LookPresets.active(bs) == "server_red" and m.beats == ["stairs"], "the base look, the stairs beat")
			m.clock = MissionBasementStealth.BLACKOUT_AT_S - 0.005
			_next(2)
		2:
			if frames == 2:
				_check(m.blackout and m.beats.has("blackout"), "25 s in: the blackout")
				_check(not bs.level.power_on and bs.level.rows_lit > 0 and bs.level.rows_lit < LairBasement.LAMP_ZS.size(), "the rows die one by one (not all at once)")
				_check(LookPresets.active(bs) == "server_blackout", "the dark look")
				var ok: bool = true
				for x: Variant in m.fight.alive():
					var gx: Gunman = x
					ok = ok and is_equal_approx(gx.patrol_sight_m, 12.0) and is_equal_approx(gx.patrol_fov_deg, 30.0) and (m._props[gx][0] as Node3D).visible
				_check(ok, "in the dark the guards see 12 m / 30 deg (their torch beams on)")
			if frames < 60:
				return false
			_check(bs.level.rows_lit == 0 and m.cues_played.count("locker_slam") == LairBasement.LAMP_ZS.size(), "all rows dark, a clunk per row")
			m.blackout_t = MissionBasementStealth.FACE_AFTER_S - 0.005
			_next(3)
		3:
			if frames < 3:
				return false
			_check(m.beats.has("leds") and m.beats.has("face") and m.whispers == 1 and is_equal_approx(bs.level.face_k, 1.0), "the LED radio, Za Mẫn's face with the whisper")
			m.blackout_t = MissionBasementStealth.DUD_AFTER_S - 0.005
			_next(4)
		4:
			if frames == 3:
				_check(m.beats.has("dud") and m.dud_guard != null and is_zero_approx(m.dud_guard.patrol_sight_m), "a guard's torch dies: blind")
				g = m.dud_guard
			if frames < 3 + int(MissionBasementStealth.DUD_S * 60.0) + 5:
				return false
			_check(m.dud_guard == null and is_equal_approx(g.patrol_sight_m, 12.0), "he shook it back on after 4 s")
			# sight only inside the cone: a guard in the left aisle facing +z, the player 20 deg off his axis at 6 m
			g = m.fight.alive()[0]
			_others_away(g)
			hold = func() -> void:
				_pin(g, Vector3(-3.5, 0.0, 14.0), PI)
				var off: Vector3 = Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(20.0)) * 6.0
				bs.player.teleport(bs.level.world(Vector3(-3.5, 0.0, 14.0) + off), PI)
			_next(5)
		5:
			if frames < 40:
				return false
			_check(not g.is_alerted and not m.spotted, "20 deg off his torch axis at 6 m: unseen in the dark")
			hold = func() -> void:
				_pin(g, Vector3(-3.5, 0.0, 14.0), PI)
				bs.player.teleport(bs.level.world(Vector3(-3.5, 0.0, 20.0)), PI)
			_next(6)
		6:
			if not m.spotted and frames < 40:
				return false
			_check(g.is_alerted and m.spotted, "straight in his cone at 6 m: seen")
			hold = Callable()
			m.fail("test")
			m.retry()
			_check(bs.level.power_on and bs.level.rows_lit == LairBasement.LAMP_ZS.size() and not m.blackout and m.beats == ["stairs"], "a retry restores the lights and re-arms the blackout")
			_check(LookPresets.active(bs) == "server_red", "a retry restores the base look")
			_next(7)
		7:
			if frames < 3:
				return false
			var ok7: bool = m.fight.gunmen.size() == 3
			for x: Variant in m.fight.alive():
				ok7 = ok7 and is_equal_approx((x as Gunman).patrol_sight_m, HorrorStalker.SIGHT) and m._props.has(x)
			_check(ok7, "fresh guards with daylight sight and LEDs after the retry")
			_others_away(null)                 # every guard by the room's mouth, facing away
			bs.player.teleport(bs.level.world(Vector3(3.5, 0.0, 20.0)), 0.0)
			_next(8)
		8:
			_check(m.blackout and m.clock < 5.0, "the cross aisle triggers the blackout early")
			bs.player.teleport(bs.level.world(LairBasement.START), 0.0)
			g = m.fight.alive()[0]
			_others_away(g)
			hold = func() -> void:
				_pin(g, Vector3(-3.5, 0.0, 12.0), PI)
				bs.player.teleport(bs.level.world(Vector3(-3.5, 0.0, 29.0)), PI)
			_next(9)
		9:
			if frames < 40:
				return false
			_check(not g.is_alerted and not m.spotted, "17 m ahead in the dark, torch off: unseen")
			m.flashlight.set_on(true)
			_next(10)
		10:
			if not m.spotted and frames < 40:
				return false
			_check(m.spotted and m.light_spots == 1, "the [F] torch gives him away from 17 m")
			hold = Callable()
			m.flashlight.set_on(false)
			m.fail("test")
			m.retry()
			m.clock = MissionBasementStealth.BLACKOUT_AT_S - 0.005
			_next(11)
		11:
			if frames < 3:
				return false
			_check(m.blackout and not bs.level.power_on, "dark again")
			bs.player.teleport(m.pts["goal"], 0.0)
			_next(12)
		12:
			if m.state == "running" and frames < 10:
				return false
			_check(m.state == "done" and m.power_back and bs.level.power_on and m.beats.has("power_back"), "the control room: power back, done")
			bs._free_mission()
			_check(LookPresets.active(bs) == "server_red" and bs.looks.is_empty(), "the look restored after the task")
			if fx:
				fx.set("reduce_scares", true)
			_next(13)
		13:
			if frames < 3:
				return false
			m = _start_mission()
			m.clock = MissionBasementStealth.BLACKOUT_AT_S - 0.005
			_next(14)
		14:
			if frames == 3:
				m.blackout_t = MissionBasementStealth.FACE_AFTER_S - 0.005
			if frames < 6:
				return false
			_check(m.beats.has("face") and m.whispers == 0 and bs.level.face_k < 0.6 and bs.level.face_k > 0.0, "Giảm hù dọa: a dimmer face, no whisper")
			_check(bs.level.face_gentle and m.blackout_db <= -12.0, "Giảm hù dọa: gentle face blips, a soft blackout thump (%.0f dB)" % m.blackout_db)
			_check(m.flashlight.gentle, "Giảm hù dọa: the torch flickers gently")
			bs._free_mission()
			_check(bs.level.power_on and LookPresets.active(bs) == "server_red", "aborting restores the lights and the look")
			phase = 99
		99:
			return _end()
	return false


func _end() -> bool:
	if fx:
		fx.set("reduce_scares", false)
	StoryBasement.test_opts = {}
	if bs and is_instance_valid(bs):
		bs.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS: basement blackout (trigger, rows, cones, torch, beats, retry, power back, Giảm hù dọa)")
		quit(0)
	else:
		print("FAILED: %d check(s)" % fails.size())
		quit(1)
	return true
