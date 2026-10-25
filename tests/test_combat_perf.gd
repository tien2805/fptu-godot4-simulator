# File: res://tests/test_combat_perf.gd
# Phase B performance gate (spec B-D12, "3-enemy brawl + crowd"): FreeRoam with the full daytime crowd and traffic at the
# BE6 spawn, a MeleeFight of 3 couriers (AI on, tough enough not to fall, force unarmed) around the player (god mode, a
# light combo every 0.4 s and a heavy kick every 2 s), then one measured window of 120 physics frames against two baselines:
#   B1 the fight and the PlayerCombat disabled (crowd, traffic, weapons, wanted level still on): the combat's own cost;
#   B2 also the crowd, traffic, weapons, wanted level and emotes disabled (the test_mayhem_perf baseline): brawl + crowd.
# Each cost must stay < 3 ms per physics frame (headless script time, the phase-change frame dropped) by the MEDIAN and by
# the 5 %-TRIMMED MEAN (6 lowest and 6 highest of 120 frames dropped), same method as tests/test_mayhem_perf.gd. Also: no
# GPUParticles3D anywhere, Engine.time_scale back at 1.0. Prints the numbers for PLAN.md.
# Run:  godot --headless --path . --script tests/test_combat_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120

## Runs AFTER every other _physics_process: from the physics_frame signal (before the nodes) to here = the script time of
## one physics step.
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var roam: Node3D
var fight: MeleeFight
var timing: bool = false
var _pt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var medians: Array[float] = []
var means: Array[float] = []
var trimmed: Array[float] = []
var attacks0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST COMBAT PERFORMANCE GATE ---")
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


## Mean of a sorted sample without the lowest and highest `frac` of it (at least one value is kept).
static func trimmed_mean(sorted: PackedInt32Array, frac: float) -> float:
	var k: int = int(floor(float(sorted.size()) * frac))
	var n: int = sorted.size() - 2 * k
	if n <= 0:
		return float(sorted[sorted.size() / 2])
	var t: int = 0
	for i: int in range(k, k + n):
		t += sorted[i]
	return float(t) / float(n)


func _attacks() -> int:
	var n: int = 0
	for e: Variant in fight.enemies:
		n += (e as MeleeEnemy).attacks
	return n


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	var pl: ThirdPersonController = roam.get("player")
	var combat: PlayerCombat = roam.get("combat")
	match phase:
		"settle":
			if t == 180:
				combat.god = true
				fight = MeleeFight.new()
				fight.name = "PerfFight"
				roam.add_child(fight)
				fight.setup({"roam": roam, "seed": 11})
				var w: Array = []
				for i: int in 3:
					var a: float = pl.facing_yaw() + (float(i) - 1.0) * 0.9
					var at: Vector3 = pl.global_position + Vector3(-sin(a), 0.0, -cos(a)) * 4.0
					w.append({"archetype": "courier", "at": at, "opts": {"hp_scale": 30.0, "label": ["Mũ Đỏ", "Mũ Xanh", "Mũ Vàng"][i],
						"body": {"helmet_color": [Color("#E74C3C"), Color("#5DADE2"), Color("#F1C40F")][i]}}})
				fight.add_wave(w)
				fight.start()
				_next("brawl")
		"brawl":
			if t % 24 == 0:
				combat.light_override = true
			if t % 120 == 60:
				combat.heavy_override = true
			if t == 120:
				var sp: PedestrianSpawner = roam.get("pedestrians")
				print("  brawl at BE6: %d enemies, %d pedestrians, %d impostors, %d attacks so far" % [fight.alive().size(), sp.pedestrians().size(), sp.impostors.count(), _attacks()])
				_check(fight.state == "running" and fight.alive().size() == 3, "3 couriers brawling (%s, %d alive)" % [fight.state, fight.alive().size()])
				attacks0 = _attacks()
				_start_window()
			if t == 120 + WINDOW:
				_end_window()
				_check(_attacks() > attacks0, "the couriers attacked during the window (%d -> %d)" % [attacks0, _attacks()])
				_check(fight.attackers() <= 2 and fight.max_attackers_seen <= 2, "never more than 2 attackers (max %d)" % fight.max_attackers_seen)
				fight.process_mode = Node.PROCESS_MODE_DISABLED
				combat.process_mode = Node.PROCESS_MODE_DISABLED
				_next("b1")
		"b1":
			if t == 2:
				_start_window()   # disabling removes bodies from the physics space: drop the change frame
			if t == 2 + WINDOW:
				_end_window()
				var wd: Node = roam.get("weapons")
				for n: Node in [roam.get("pedestrians"), roam.get("traffic"), wd, roam.get("wanted"), roam.get("emotes")]:
					(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
				_next("b2")
		"b2":
			if t == 2:
				_start_window()
			if t == 2 + WINDOW:
				_end_window()
				_report()


func _report() -> void:
	var cost_c: float = (medians[0] - medians[1]) / 1000.0
	var trim_c: float = (trimmed[0] - trimmed[1]) / 1000.0
	var cost_b: float = (medians[0] - medians[2]) / 1000.0
	var trim_b: float = (trimmed[0] - trimmed[2]) / 1000.0
	print("  combat only (3 couriers + PlayerCombat + HUD): %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_c, trim_c, medians[0], medians[1], trimmed[0], trimmed[1], means[0], means[1]])
	print("  3-enemy brawl + crowd + traffic + wanted: %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_b, trim_b, medians[0], medians[2], trimmed[0], trimmed[2], means[0], means[2]])
	_check(cost_c < GATE_MS, "combat < 3 ms per physics frame, median (%.2f)" % cost_c)
	_check(trim_c < GATE_MS, "combat < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim_c)
	_check(cost_b < GATE_MS, "3-enemy brawl + crowd < 3 ms per physics frame at BE6, median (%.2f)" % cost_b)
	_check(trim_b < GATE_MS, "3-enemy brawl + crowd < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim_b)
	_check(roam.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D in FreeRoam")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: COMBAT PERFORMANCE (combat %.2f / %.2f ms, brawl + crowd %.2f / %.2f ms median / trimmed mean < 3 ms per physics frame)" % [cost_c, trim_c, cost_b, trim_b])
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
