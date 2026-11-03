# File: res://tests/test_tower_perf.gd
# W4 Day 7 T5 (plan 2026-11-01-w4-day7.md): the performance gate of the tower scene. The StoryTower scene (LairTower: the
# floors, the gallery, the roof; its own player stack, no city) with the final boss's arena running at its busiest: phase 1
# in the vase gallery (MissionBossGuns, the real mission ticking itself; wave 1 knocked out): Lọ and his bodyguards
# shooting from the plinths, the window opening on his volley's telegraph (the beam, then his 4 shots), the vases chipping, the player popping out of cover to aim and fire every second
# (god mode, Lọ kept alive so the fight runs the whole window). One window of WINDOW physics frames against a baseline of
# the same scene with the mission freed (the tower idle on the gallery floor): the fight's cost, and the scene's whole
# script time with the fight.
# Each < 3 ms per physics frame and per process frame by the MEDIAN and the 5 %-TRIMMED MEAN (the method of
# tests/test_lair_perf.gd: from the physics_frame / process_frame signal to a tail node that runs after every other
# _physics_process / _process, the phase-change frame dropped). Also: no GPUParticles3D, Engine.time_scale back at 1.0.
# Prints the numbers for the plan. Run on AC power (Get-CimInstance BatteryStatus PowerOnline).
# w5-day7 T6: then the parking deck (MissionTowerParking on the spiral deck: the road mesh, the lamps lit round the camera,
# the riders' floors from the route's heights every frame), its wave 1 riding round the bike (god mode, ridden on the
# lane's centre) for one more window: the chase's cost against the same idle baseline, and the scene's whole script time.
# Run:  godot --headless --path . --script tests/test_tower_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120
const SETTLE: int = 360
const TMP: String = "user://test_tower_perf.cfg"

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
var tw: StoryTower
var mg: MissionBossGuns
var mp: MissionTowerParking
var sd: Node
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
	print("--- TEST TOWER PERFORMANCE GATE (StoryTower, the final boss's phase 1 in the vase gallery) ---")
	Difficulty.set_easy(false)
	sd = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	StoryRankCard.skip_all = true
	StoryTower.test_opts = {"missions": {"seed": 7}, "capture_mouse": false, "go_roam": false}
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


func _shots() -> int:
	var n: int = 0
	if mg and is_instance_valid(mg) and mg.fight:
		for g: Variant in mg.fight.gunmen:
			if is_instance_valid(g):
				n += (g as Gunman).shots
	return n


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	if mg and is_instance_valid(mg) and mg.state == "running":
		if mg.lo and is_instance_valid(mg.lo):
			mg.lo.hp = mg.lo.max_hp                 # the fight runs the whole window
		var aim: bool = (frames / 60) % 2 == 1
		tw.weapons.aim_override = aim
		tw.weapons.fire_override = aim and frames % 20 == 0
		if tw.weapons.fire_override == true:
			tw.weapons.cooldown = 0.0
	if sd:
		Day7Clock.set_remaining(sd, 99999.0)
	match phase:
		"boot":
			for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
				if not root.has_node(pair[0]):
					var n: Node = (load(pair[1]) as Script).new()
					n.name = pair[0]
					root.add_child(n)
			tw = (load("res://scenes/story/StoryTower.tscn") as PackedScene).instantiate()
			root.add_child(tw)
			_next("start")
		"start":
			if t < 20:
				return
			Difficulty.set_easy(false)            # GameFX applied the settings file meanwhile
			if sd:
				(sd.get("flags") as Dictionary)[MissionBossGuns.CARD_FLAG] = true   # the villain card seen: the fight starts at once
			_check(tw.start_mission(StoryMissions.beat("d7_boss1")), "the boss fight starts in the tower scene")
			mg = tw.mission_node as MissionBossGuns
			for c: Dictionary in mg.done.get_connections():
				mg.done.disconnect(c["callable"])
			for c2: Dictionary in mg.failed.get_connections():
				mg.failed.disconnect(c2["callable"])
			tw.combat.god = true
			_next("settle")
		"settle":
			if mg.card != null and t < 900:
				mg.card.step(1.0 / 60.0)          # a card still up: step it away
				return
			if t < 120:
				return
			for e: Variant in mg.fight.alive():   # wave 1 down: Lọ's wave (him + his bodyguards) comes in
				if e is Gunman:
					var n: int = 0
					while not (e as Gunman).is_defeated() and n < 12:
						(e as Gunman).take_hit({"kind": "bullet", "from": tw.player.global_position})
						n += 1
			_next("lo")
		"lo":
			# the window opens on his volley's telegraph (the beam, then his 4 shots), SETTLE frames after he showed up
			if (mg.lo == null or t < SETTLE or mg.volley_state != "tele") and t < SETTLE + 900:
				return
			peak = {"alive": mg.fight.alive().size(), "shots0": _shots(), "volleys0": mg.volleys, "volley_shots0": mg.volley_shots}
			_check(mg.state == "running" and tw.level.current_floor == "gallery", "the fight runs in the gallery (%s / %s)" % [mg.state, tw.level.current_floor])
			_check(mg.lo != null and mg.volley_state == "tele", "Lọ up, his volley telegraphed (%s)" % mg.volley_state)
			_check(int(peak["alive"]) >= 3, "Lọ and his bodyguards fighting (%d)" % int(peak["alive"]))
			_start_window()
			_next("window")
		"window":
			if t < WINDOW:
				return
			var r: Array = _end_window()
			res["fight"] = r[0]
			res["pfight"] = r[1]
			peak["shots"] = _shots()
			peak["volleys"] = mg.volleys
			peak["volley_shots"] = mg.volley_shots
			_check(mg.volley_shots > int(peak["volley_shots0"]), "his volley fired in the window")
			peak["shattered"] = mg.shattered
			_check(int(peak["shots"]) > int(peak["shots0"]), "the guards shot during the window")
			_check(mg.state == "running", "the fight still runs after the window (%s)" % mg.state)
			_check(mg.fight.max_shooters_seen <= GunData.max_shooters(), "never more than %d shooting" % GunData.max_shooters())
			_check(tw.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
			tw.weapons.aim_override = false
			tw.weapons.fire_override = false
			tw._free_mission()                    # the tower idle: the baseline (abort_mission would leave the lair)
			mg = null
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
			_next("deck_start")
		"deck_start":
			if sd:
				(sd.get("flags") as Dictionary)[MissionTowerParking.CARD_FLAG] = true   # Sói Xám's card seen
			_check(tw.start_mission(StoryMissions.beat("d7_parking")), "the parking chase starts in the tower scene")
			mp = tw.mission_node as MissionTowerParking
			if mp == null:
				_report()
				return
			for c: Dictionary in mp.done.get_connections():
				mp.done.disconnect(c["callable"])
			for c2: Dictionary in mp.failed.get_connections():
				mp.failed.disconnect(c2["callable"])
			_next("deck")
		"deck":
			# the window opens once wave 1 rides round the bike (its preview cut over)
			var ch: BikeChase = mp.chase
			if ch:
				ch.combat.god = true
				_ride(ch)
			if (ch == null or t < 240 or _riding(ch) < 3 or mp.beat_fx.busy()) and t < 1800:
				return
			peak["deck_riding0"] = _riding(ch)
			_check(ch != null and ch.state == "running" and tw.level.current_floor == "parking", "the chase runs on the deck (%s / %s)" % [ch.state if ch else "none", tw.level.current_floor])
			_check(_riding(ch) >= 3, "wave 1 rides round the bike (%d)" % _riding(ch))
			print("  deck: s_p %.0f at %.1f m/s, %d riding, wave %d, lamps lit %d-%d" % [ch.s_p, ch.p_vel.length(), _riding(ch), ch.wave, tw.level.deck_lit_lo, tw.level.deck_lit_hi])
			_start_window()
			_next("deck_window")
		"deck_window":
			_ride(mp.chase)
			if t < WINDOW:
				return
			var r3: Array = _end_window()
			res["deck"] = r3[0]
			res["pdeck"] = r3[1]
			peak["deck_riding"] = _riding(mp.chase)
			_check(mp.state == "running" and mp.chase.state == "running", "the chase still runs after the window (%s / %s)" % [mp.state, mp.chase.state])
			_check(tw.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D on the deck")
			for a: String in ["gas", "brake", "steer_left", "steer_right"]:
				Input.action_release(a)
			tw._free_mission()
			mp = null
			_next("end")
		"end":
			if t < 30:
				return
			_report()


## Wave riders still riding.
func _riding(ch: BikeChase) -> int:
	var n: int = 0
	if ch == null:
		return 0
	for b: Variant in ch.bikers:
		if is_instance_valid(b) and (b as BikerEnemy).riding() and not (b as BikerEnemy).gone:
			n += 1
	return n


## Rides the bike round the deck (gas, steering at the lane's centre ahead), as test_tower_level's _ride.
func _ride(ch: BikeChase) -> void:
	if ch == null or ch.route == null or ch.bike == null or ch.s_p < 0.0:
		return
	var tgt: Vector2 = ch.route.world(clampf(ch.s_p + 9.0 + absf(ch.bike.current_speed_ms) * 0.35, 0.0, ch.route.length), 0.0)
	var to: Vector2 = tgt - ch.p_pos
	var steer: float = clampf(wrapf(atan2(-to.x, -to.y) - ch.bike.rotation.y, -PI, PI) * 3.0, -1.0, 1.0)
	Input.action_press("gas")
	if steer > 0.02:
		Input.action_press("steer_left", steer)
		Input.action_release("steer_right")
	elif steer < -0.02:
		Input.action_press("steer_right", -steer)
		Input.action_release("steer_left")
	else:
		Input.action_release("steer_left")
		Input.action_release("steer_right")


func _report() -> void:
	var cost: float = (float(res["fight"][0]) - float(res["base"][0])) / 1000.0
	var trim: float = (float(res["fight"][1]) - float(res["base"][1])) / 1000.0
	var pcost: float = (float(res["pfight"][0]) - float(res["pbase"][0])) / 1000.0
	var ptrim: float = (float(res["pfight"][1]) - float(res["pbase"][1])) / 1000.0
	var abs_med: float = (float(res["fight"][0]) + float(res["pfight"][0])) / 1000.0
	var abs_trim: float = (float(res["fight"][1]) + float(res["pfight"][1])) / 1000.0
	print("  peak: %d fighting (Lọ's wave), guard shots %d -> %d, volleys %d -> %d (volley shots %d -> %d), vases shattered %d" % [int(peak["alive"]),
		int(peak["shots0"]), int(peak.get("shots", 0)), int(peak["volleys0"]), int(peak.get("volleys", 0)), int(peak["volley_shots0"]),
		int(peak.get("volley_shots", 0)), int(peak.get("shattered", 0))])
	print("  boss fight: physics %.2f ms median, %.2f ms trimmed; process %.2f / %.2f ms (fight %.0f vs base %.0f us)" % [cost, trim, pcost, ptrim,
		float(res["fight"][0]), float(res["base"][0])])
	print("  tower scene, whole script time with the fight (physics + process): %.2f ms median, %.2f ms trimmed" % [abs_med, abs_trim])
	_check(cost < GATE_MS and trim < GATE_MS, "the fight < 3 ms per physics frame (%.2f / %.2f)" % [cost, trim])
	_check(pcost < GATE_MS and ptrim < GATE_MS, "the fight < 3 ms per process frame (%.2f / %.2f)" % [pcost, ptrim])
	_check(abs_med < GATE_MS and abs_trim < GATE_MS, "the tower scene < 3 ms per frame, whole (%.2f / %.2f)" % [abs_med, abs_trim])
	var dcost: float = 99.0
	var dtrim: float = 99.0
	var dpcost: float = 99.0
	var dptrim: float = 99.0
	var dabs_med: float = 99.0
	var dabs_trim: float = 99.0
	if res.has("deck"):
		dcost = (float(res["deck"][0]) - float(res["base"][0])) / 1000.0
		dtrim = (float(res["deck"][1]) - float(res["base"][1])) / 1000.0
		dpcost = (float(res["pdeck"][0]) - float(res["pbase"][0])) / 1000.0
		dptrim = (float(res["pdeck"][1]) - float(res["pbase"][1])) / 1000.0
		dabs_med = (float(res["deck"][0]) + float(res["pdeck"][0])) / 1000.0
		dabs_trim = (float(res["deck"][1]) + float(res["pdeck"][1])) / 1000.0
		print("  parking deck: %d -> %d riding; physics %.2f ms median, %.2f ms trimmed; process %.2f / %.2f ms; whole %.2f / %.2f ms" % [int(peak.get("deck_riding0", 0)),
			int(peak.get("deck_riding", 0)), dcost, dtrim, dpcost, dptrim, dabs_med, dabs_trim])
	_check(dcost < GATE_MS and dtrim < GATE_MS and dpcost < GATE_MS and dptrim < GATE_MS, "the deck chase < 3 ms per physics / process frame (%.2f / %.2f, %.2f / %.2f)" % [dcost, dtrim, dpcost, dptrim])
	_check(dabs_med < GATE_MS and dabs_trim < GATE_MS, "the tower scene with the deck chase < 3 ms per frame, whole (%.2f / %.2f)" % [dabs_med, dabs_trim])
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0 (%.2f)" % Engine.time_scale)
	StoryTower.test_opts = {}
	StoryRankCard.skip_all = DisplayServer.get_name() == "headless"
	if sd:
		sd.set("save_path", "user://story_save.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS: TOWER PERFORMANCE (boss fight %.2f / %.2f ms physics, %.2f / %.2f ms process; tower scene %.2f / %.2f ms; deck chase %.2f / %.2f ms whole; median / trimmed < 3 ms)" % [cost, trim, pcost, ptrim, abs_med, abs_trim, dabs_med, dabs_trim])
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
