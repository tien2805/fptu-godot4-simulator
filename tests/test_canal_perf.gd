# File: res://tests/test_canal_perf.gd
# W4 Day 6 T9 (plan 2026-11-01-w4-day6.md): the performance gate of the canal scene. The StoryCanal scene (LairCanal: the
# shop, the back room, the canal course; its own player stack, no city) with the speedboat chase (MissionBoatChase, the
# real mission ticking itself) at its peak: the boat at full throttle on the stretch before the fireworks barge, a wave of
# jet skis alongside, the rogue rockets and their rings, the sky bursts, Thị Lọ ahead, the chase camera. One window of
# WINDOW physics frames against a baseline of the same scene with the mission ended (the canal idle): the chase's cost,
# and the scene's whole script time with the chase.
# Each < 3 ms per physics frame and per process frame by the MEDIAN and the 5 %-TRIMMED MEAN (the method of
# tests/test_lair_perf.gd: from the physics_frame / process_frame signal to a tail node that runs after every other
# _physics_process / _process, the phase-change frame dropped). Also: no GPUParticles3D, Engine.time_scale back at 1.0.
# Prints the numbers for the plan. Run on AC power (Get-CimInstance BatteryStatus PowerOnline).
# Run:  godot --headless --path . --script tests/test_canal_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120
const START_S: float = 990.0
const PEAK_S: float = LairCanal.BARGE_S - BoatData.BARGE_FROM + 6.0   # the rockets fly from here
const TMP: String = "user://test_canal_perf.cfg"

class Tail extends Node:
	var on_tail: Callable
	var physics: bool = true

	func _physics_process(_d: float) -> void:
		if physics:
			on_tail.call()

	func _process(_d: float) -> void:
		if not physics:
			on_tail.call()


var fails: Array[String] = []
var frames: int = 0
var phase: String = "boot"
var t0: int = 0
var sc: StoryCanal
var mn: MissionBoatChase
var chase: BoatChase
var inp: Dictionary = {"throttle": 1.0, "steer": 0.0, "duck": false}
var timing: bool = false
var _pt0: int = 0
var _qt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var psamples: PackedInt32Array = PackedInt32Array()
var res: Dictionary = {}
var peak: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	WeaponAudio.sfx_dir = "user://__test_no_sfx__/"
	print("--- TEST CANAL PERFORMANCE GATE (StoryCanal, the speedboat chase at its peak) ---")
	Difficulty.set_easy(false)
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	StoryRankCard.skip_all = true
	StoryCanal.test_opts = {"missions": {"seed": 7, "input": inp}, "capture_mouse": false, "go_roam": false}
	var tail := Tail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = func() -> void:
		if timing:
			samples.append(Time.get_ticks_usec() - _pt0)
	root.add_child(tail)
	var ptail := Tail.new()
	ptail.name = "ProcTail"
	ptail.physics = false
	ptail.process_priority = 1 << 30
	ptail.on_tail = func() -> void:
		if timing:
			psamples.append(Time.get_ticks_usec() - _qt0)
	root.add_child(ptail)
	physics_frame.connect(_on_physics)
	process_frame.connect(func() -> void: _qt0 = Time.get_ticks_usec())


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _start_window() -> void:
	samples.clear()
	psamples.clear()
	timing = true


## [median, trimmed] of the physics and the process samples of the window just ended.
func _end_window() -> Array:
	timing = false
	var out: Array = []
	for s: PackedInt32Array in [samples, psamples]:
		var sorted: PackedInt32Array = s.duplicate()
		sorted.sort()
		if sorted.size() > 1:
			sorted.remove_at(0)   # the phase-change frame
		if sorted.is_empty():
			out.append([0.0, 0.0])
			continue
		out.append([float(sorted[sorted.size() / 2]), trimmed_mean(sorted, 0.05)])
	return out


static func trimmed_mean(sorted: PackedInt32Array, frac: float) -> float:
	var k: int = int(floor(float(sorted.size()) * frac))
	var n: int = sorted.size() - 2 * k
	if n <= 0:
		return float(sorted[sorted.size() / 2])
	var t: int = 0
	for i: int in range(k, k + n):
		t += sorted[i]
	return float(t) / float(n)


## The chase to s: the boat (an unsinkable hull for the window), Thị Lọ ahead, the jet ski waves from there on.
func _place(s: float) -> void:
	chase.boat.place(s, -2.0, BoatData.v_max())
	chase.boat.hull = 1.0e6
	chase.rival.place(s + BoatData.RIVAL_GAP, 0.0, BoatData.v_max())
	for sk: JetSki in chase.skis:
		sk.retire()
	chase._attacker = null
	var wi: int = 0
	while wi < BoatData.WAVES.size() and float(BoatData.WAVES[wi][0]) <= s:
		wi += 1
	chase.wave_i = wi
	chase.hits.clear()
	chase.finale = false
	chase.lose_t = 0.0
	chase._cam_init = false
	chase.set_pieces.reset(s)


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	if chase and is_instance_valid(chase) and chase.boat:
		inp["steer"] = clampf((-2.0 - chase.boat.d) * 0.5, -1.0, 1.0)   # a lane clear of the barge
		chase.boat.hull = 1.0e6
	match phase:
		"boot":
			for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
				if not root.has_node(pair[0]):
					var n: Node = (load(pair[1]) as Script).new()
					n.name = pair[0]
					root.add_child(n)
			sc = (load("res://scenes/story/StoryCanal.tscn") as PackedScene).instantiate()
			root.add_child(sc)
			_next("start")
		"start":
			if t < 20:
				return
			Difficulty.set_easy(false)            # GameFX applied the settings file meanwhile
			_check(sc.start_mission(StoryMissions.beat("d6_boat")), "the boat chase starts in the canal scene")
			mn = sc.mission_node as MissionBoatChase
			for c: Dictionary in mn.done.get_connections():
				mn.done.disconnect(c["callable"])
			for c2: Dictionary in mn.failed.get_connections():
				mn.failed.disconnect(c2["callable"])
			chase = mn.chase
			_next("place")
		"place":
			if t < 30:
				return
			_place(START_S)
			_next("settle")
		"settle":
			if chase.boat.s < PEAK_S and t < 900:
				return
			peak = {"skis": chase.active_skis().size(), "s": chase.boat.s, "rockets0": _rockets_launched()}
			_check(chase.state == "running" and mn.state == "running", "the chase runs (%s / %s)" % [chase.state, mn.state])
			_check(int(peak["skis"]) >= BoatData.wave_count(BoatData.WAVES[2]), "a wave of jet skis in the race (%d)" % int(peak["skis"]))
			_start_window()
			_next("window")
		"window":
			if t < WINDOW:
				return
			var r: Array = _end_window()
			res["chase"] = r[0]
			res["pchase"] = r[1]
			_check(_rockets_launched() > int(peak["rockets0"]), "rogue rockets flew in the window")
			_check(chase.set_pieces.sky_count > 0, "the barge's sky bursts")
			_check(chase.boat.s > float(peak["s"]) + 20.0, "the boat moved on (%.0f -> %.0f m)" % [float(peak["s"]), chase.boat.s])
			_check(sc.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
			peak["sky"] = chase.set_pieces.sky_count
			peak["rockets"] = _rockets_launched()
			sc._free_mission()                    # the canal idle: the baseline (abort_mission would leave the lair)
			chase = null
			mn = null
			_next("base_settle")
		"base_settle":
			if t < 90:
				return
			_start_window()
			_next("base")
		"base":
			if t < WINDOW:
				return
			var r2: Array = _end_window()
			res["base"] = r2[0]
			res["pbase"] = r2[1]
			_next("end")
		"end":
			if t < 30:
				return
			_report()


func _rockets_launched() -> int:
	return chase.set_pieces.rocket_count if chase and is_instance_valid(chase) else 0


func _report() -> void:
	var cost: float = (float(res["chase"][0]) - float(res["base"][0])) / 1000.0
	var trim: float = (float(res["chase"][1]) - float(res["base"][1])) / 1000.0
	var pcost: float = (float(res["pchase"][0]) - float(res["pbase"][0])) / 1000.0
	var ptrim: float = (float(res["pchase"][1]) - float(res["pbase"][1])) / 1000.0
	var abs_med: float = (float(res["chase"][0]) + float(res["pchase"][0])) / 1000.0
	var abs_trim: float = (float(res["chase"][1]) + float(res["pchase"][1])) / 1000.0
	print("  peak: %d jet skis, the boat from %.0f m, rockets launched %d -> %d, sky bursts %d" % [int(peak["skis"]), float(peak["s"]),
		int(peak["rockets0"]), int(peak.get("rockets", 0)), int(peak.get("sky", 0))])
	print("  boat chase: physics %.2f ms median, %.2f ms trimmed; process %.2f / %.2f ms (chase %.0f vs base %.0f us)" % [cost, trim, pcost, ptrim,
		float(res["chase"][0]), float(res["base"][0])])
	print("  canal scene, whole script time with the chase (physics + process): %.2f ms median, %.2f ms trimmed" % [abs_med, abs_trim])
	_check(cost < GATE_MS and trim < GATE_MS, "the chase < 3 ms per physics frame (%.2f / %.2f)" % [cost, trim])
	_check(pcost < GATE_MS and ptrim < GATE_MS, "the chase < 3 ms per process frame (%.2f / %.2f)" % [pcost, ptrim])
	_check(abs_med < GATE_MS and abs_trim < GATE_MS, "the canal scene < 3 ms per frame, whole (%.2f / %.2f)" % [abs_med, abs_trim])
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0 (%.2f)" % Engine.time_scale)
	StoryCanal.test_opts = {}
	StoryRankCard.skip_all = DisplayServer.get_name() == "headless"
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", "user://story_save.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS: CANAL PERFORMANCE (boat chase %.2f / %.2f ms physics, %.2f / %.2f ms process; canal scene %.2f / %.2f ms; median / trimmed < 3 ms)" % [cost, trim, pcost, ptrim, abs_med, abs_trim])
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
