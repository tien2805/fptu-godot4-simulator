# File: res://tests/test_bike_perf.gd
# Phase C performance gate for the bike chase (spec C-D13, "bike-chase case"): FreeRoam with the full daytime crowd and
# traffic (worse than the Day 2 night: 30 % traffic), the player riding Nguyễn Xiển on autopilot (gas held, steered
# along the chase route), a BikeChase of 6 AI bikers in one wave (god mode, tough bikers that wobble and recover), a kick
# every 0.6 s, then one measured window of 120 physics frames against two baselines. Day 2 (spec 2026-10-27 D2X-12): the
# bikers are the new kinds (2 riders, a stick, a heavy, a thrower, the pickup) on the chase profile, and the window runs
# with set pieces live (melons rolling, 2 police riders, the wrong-way cones, a drift zone):
#   B1 the chase disabled (its bikers, PlayerBikeCombat and HUD with it; crowd, traffic, weapons, wanted level still on):
#      the chase's own cost;
#   B2 also the crowd, traffic, weapons, wanted level and emotes disabled: chase + crowd + traffic.
# Each cost must stay < 3 ms per physics frame (headless script time, the phase-change frame dropped) by the MEDIAN and by
# the 5 %-TRIMMED MEAN (6 lowest and 6 highest of 120 frames dropped), the method of tests/test_combat_perf.gd. Also: no
# GPUParticles3D, Engine.time_scale back at 1.0. Prints the numbers for PLAN.md.
# Run:  godot --headless --path . --script tests/test_bike_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120
const ENGAGE: int = 330                  # frames after the start before measuring (bikers caught up, traffic refilled)
## Day 2 set pieces live in the window (the start at s 60; ~5.5 s in the player is near s 150).
const PERF_PIECES: Array = [
	{"kind": "police", "s": 80.0, "end_s": 900.0, "dur": 25.0},
	{"kind": "drift", "s": 130.0, "len": 60.0},
	{"kind": "wrong_way", "s": 140.0, "len": 250.0},
	{"kind": "melons", "s": 175.0},
]


class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var roam: Node3D
var chase: BikeChase
var timing: bool = false
var _pt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var medians: Array[float] = []
var means: Array[float] = []
var trimmed: Array[float] = []
var kicks0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST BIKE CHASE PERFORMANCE GATE ---")
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	var tail := PhysTail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _tail
	root.add_child(tail)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	phase = "settle"
	physics_frame.connect(_on_physics)


func _tail() -> void:
	if timing:
		samples.append(Time.get_ticks_usec() - _pt0)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _start_window() -> void:
	samples.clear()
	timing = true


func _end_window() -> void:
	timing = false
	if samples.is_empty():
		medians.append(0.0)
		means.append(0.0)
		trimmed.append(0.0)
		return
	var total: int = 0
	for s: int in samples:
		total += s
	means.append(float(total) / float(samples.size()))
	var sorted: PackedInt32Array = samples.duplicate()
	sorted.sort()
	trimmed.append(trimmed_mean(sorted, 0.05))
	medians.append(float(sorted[sorted.size() / 2]))


static func trimmed_mean(sorted: PackedInt32Array, frac: float) -> float:
	var k: int = int(floor(float(sorted.size()) * frac))
	var n: int = sorted.size() - 2 * k
	if n <= 0:
		return float(sorted[sorted.size() / 2])
	var t: int = 0
	for i: int in range(k, k + n):
		t += sorted[i]
	return float(t) / float(n)


## Autopilot: gas held (phase start), the bike's yaw eased toward the route 14 m ahead.
func _steer() -> void:
	if chase == null or chase.route == null or chase.s_p < 0.0:
		return
	var b: PlayerBike = roam.get("bike")
	var to: Vector2 = chase.route.point(chase.s_p + 14.0) - Vector2(b.global_position.x, b.global_position.z)
	b.rotation.y = lerp_angle(b.rotation.y, atan2(-to.x, -to.y), 0.25)


func _riding() -> int:
	var n: int = 0
	for b: Variant in chase.bikers:
		if is_instance_valid(b) and (b as BikerEnemy).riding() and not (b as BikerEnemy).gone:
			n += 1
	return n


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	if chase != null and phase != "settle":
		_steer()
	match phase:
		"settle":
			if t == 180:
				chase = BikeChase.new()
				chase.name = "PerfChase"
				roam.add_child(chase)
				chase.setup({"roam": roam, "start_s": 60.0, "seed": 21, "profile": BikeCombatData.CHASE_PROFILE, "takedown_cam": false,
					"set_pieces": PERF_PIECES})
				var w: Array = []
				var kinds: Array[String] = ["rider", "stick", "heavy", "rider", "thrower", "pickup"]
				for i: int in 6:
					w.append({"lane": [-1, 1, 0][i % 3], "gap": float(i / 3) * 4.0, "opts": {"kind": kinds[i], "hp": 99, "aggression": 0.8}})
				chase.add_wave(w)
				chase.combat.god = true
				chase.start()
				Input.action_press("gas")
				_next("chase")
		"chase":
			if t % 36 == 0:
				chase.combat.kick(1 if (t / 36) % 2 == 0 else -1)
			if t == ENGAGE:
				var sp: PedestrianSpawner = roam.get("pedestrians")
				var tr: RoamTraffic = roam.get("traffic")
				var near: int = 0
				for b: Variant in chase.bikers:
					if (b as BikerEnemy).pos2.distance_to(chase.p_pos) < 20.0:
						near += 1
				print("  chase on Nguyễn Xiển s %.0f at %.1f m/s: %d bikers riding (%d within 20 m), %d pedestrians, %d impostors, %d vehicles active; set pieces %s, melons rolling %s, police %d" % [chase.s_p, chase.p_vel.length(), _riding(), near, sp.pedestrians().size(), sp.impostors.count(), tr.active_count(), str(chase.set_pieces.counts), str(chase.set_pieces.melon_t >= 0.0), chase.police_active()])
				_check(chase.set_pieces.melon_t >= 0.0 and chase.police_active() == 2 and chase.set_pieces.fired("wrong_way") == 1, "the window runs with melons rolling, 2 police and the wrong way (%s)" % str(chase.set_pieces.counts))
				_check(chase.state == "running" and _riding() >= 5 and near >= 4, "the 6-biker chase is engaged (%s, %d riding, %d near)" % [chase.state, _riding(), near])
				_check(chase.p_vel.length() > 12.0, "the player rides at speed (%.1f m/s)" % chase.p_vel.length())
				kicks0 = chase.combat.kicks
				_start_window()
			if t == ENGAGE + WINDOW:
				_end_window()
				var att: int = 0
				for b: Variant in chase.bikers:
					att += (b as BikerEnemy).attacks
				print("  window: %d kicks by the player, %d biker attacks so far, %d still riding, max attackers %d" % [chase.combat.kicks - kicks0, att, _riding(), chase.max_attackers_seen])
				var info: Array[String] = []
				for b2: Variant in chase.bikers:
					var e: BikerEnemy = b2
					info.append("%s %s%s avoids %d" % [e.label, e.state_name(), (" (" + e.crash_cause + (", kicked" if e.kicked_by_player else "") + ")") if e.is_down() else "", e.avoids])
				print("  bikers: ", ", ".join(info))
				_check(chase.combat.kicks > kicks0, "the player kicked during the window")
				_check(chase.max_attackers_seen <= BikeCombatData.MAX_ATTACKERS, "never more than %d attackers (max %d)" % [BikeCombatData.MAX_ATTACKERS, chase.max_attackers_seen])
				chase.end_slow_motion()
				chase.process_mode = Node.PROCESS_MODE_DISABLED
				_next("b1")
		"b1":
			if t == 2:
				_start_window()
			if t == 2 + WINDOW:
				_end_window()
				for n: Node in [roam.get("pedestrians"), roam.get("traffic"), roam.get("weapons"), roam.get("wanted"), roam.get("emotes")]:
					if n:
						n.process_mode = Node.PROCESS_MODE_DISABLED
				_next("b2")
		"b2":
			if t == 2:
				_start_window()
			if t == 2 + WINDOW:
				_end_window()
				_report()


func _report() -> void:
	Input.action_release("gas")
	var cost_c: float = (medians[0] - medians[1]) / 1000.0
	var trim_c: float = (trimmed[0] - trimmed[1]) / 1000.0
	var cost_b: float = (medians[0] - medians[2]) / 1000.0
	var trim_b: float = (trimmed[0] - trimmed[2]) / 1000.0
	print("  bike chase only (6 bikers + PlayerBikeCombat + HUD): %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_c, trim_c, medians[0], medians[1], trimmed[0], trimmed[1], means[0], means[1]])
	print("  6-biker chase + crowd + traffic + wanted: %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_b, trim_b, medians[0], medians[2], trimmed[0], trimmed[2], means[0], means[2]])
	_check(cost_c < GATE_MS, "bike chase < 3 ms per physics frame, median (%.2f)" % cost_c)
	_check(trim_c < GATE_MS, "bike chase < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim_c)
	_check(cost_b < GATE_MS, "6-biker chase + crowd + traffic < 3 ms per physics frame, median (%.2f)" % cost_b)
	_check(trim_b < GATE_MS, "6-biker chase + crowd + traffic < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim_b)
	_check(roam.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D in FreeRoam")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: BIKE CHASE PERFORMANCE (chase %.2f / %.2f ms, chase + crowd + traffic %.2f / %.2f ms median / trimmed mean < 3 ms per physics frame)" % [cost_c, trim_c, cost_b, trim_b])
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
