# File: res://tests/test_sword_perf.gd
# Phase C performance gate of the sword duel (spec C-D13, "All < 3 ms"): FreeRoam with the full daytime crowd and traffic
# at the BE6 spawn, a SwordDuel against Za Mẫn (AI on, tough enough not to fall) with the player in god mode slashing
# every 0.4 s and thrusting every 2 s, then one measured window of 120 physics frames against two baselines:
#   B1 the duel (fight, boss, katana) and the PlayerCombat (HUD, the player's pose layer) disabled: the duel's own cost;
#   B2 also the crowd, traffic, weapons, wanted level and emotes disabled: the duel + crowd.
# Then the Day 2 mini-boss case: everything back on, a MeleeFight against Sói Xám (AI on, tough, the player blocking and
# punching in god mode), one window against S1 (that fight and the PlayerCombat disabled) and against B2.
# Each cost must stay < 3 ms per physics frame (headless script time, the phase-change frame dropped) by the MEDIAN and by
# the 5 %-TRIMMED MEAN (6 lowest and 6 highest of 120 frames dropped), method of tests/test_combat_perf.gd. Also: no
# GPUParticles3D anywhere, Engine.time_scale back at 1.0. Prints the numbers.
# Run:  godot --headless --path . --script tests/test_sword_perf.gd
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
var duel: SwordDuel
var soi: MeleeFight
var timing: bool = false
var _pt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var medians: Array[float] = []
var means: Array[float] = []
var trimmed: Array[float] = []
var tells0: int = 0
var mark_attacks: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	WeaponAudio.sfx_dir = "user://__no_owner_sfx__/"
	print("--- TEST SWORD DUEL PERFORMANCE GATE ---")
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


func _crowd() -> Array[Node]:
	return [roam.get("pedestrians"), roam.get("traffic"), roam.get("weapons"), roam.get("wanted"), roam.get("emotes")]


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
				duel = SwordDuel.new()
				duel.name = "PerfDuel"
				roam.add_child(duel)
				duel.setup({"roam": roam, "seed": 11, "at": pl.global_position + pl.facing_dir() * 4.0,
					"boss": {"hp_scale": 40.0}})
				duel.start()
				_next("duel")
		"duel":
			if t % 24 == 0:
				combat.light_override = true
			if t % 120 == 60:
				combat.heavy_override = true
			if t == 150:
				var sp: PedestrianSpawner = roam.get("pedestrians")
				print("  duel at BE6: boss %s, %d pedestrians, %d impostors, %d tells so far" % [duel.boss.state_name(), sp.pedestrians().size(), sp.impostors.count(), duel.boss.tells.size()])
				_check(duel.state == "running" and duel.boss.is_hostile(), "the duel runs (%s)" % duel.state)
				_check(SwordAudio.poll(), "the duel cues were warmed on worker tasks before the window")
				tells0 = duel.boss.tells.size()
				_start_window()
			if t == 150 + WINDOW:
				_end_window()
				_check(duel.boss.tells.size() > tells0 or duel.boss.attacks > 0, "Za Mẫn attacked during the window (%d tells)" % duel.boss.tells.size())
				duel.process_mode = Node.PROCESS_MODE_DISABLED
				combat.process_mode = Node.PROCESS_MODE_DISABLED
				combat.pose.process_mode = Node.PROCESS_MODE_DISABLED   # the player's pose layer lives on the body
				_next("b1")
		"b1":
			if t == 2:
				_start_window()   # disabling removes bodies from the physics space: drop the change frame
			if t == 2 + WINDOW:
				_end_window()
				for n: Node in _crowd():
					n.process_mode = Node.PROCESS_MODE_DISABLED
				_next("b2")
		"b2":
			if t == 2:
				_start_window()
			if t == 2 + WINDOW:
				_end_window()
				for n: Node in _crowd():
					n.process_mode = Node.PROCESS_MODE_INHERIT
				combat.process_mode = Node.PROCESS_MODE_INHERIT
				combat.pose.process_mode = Node.PROCESS_MODE_INHERIT
				duel.process_mode = Node.PROCESS_MODE_INHERIT
				duel.stop()
				duel.queue_free()
				soi = MeleeFight.new()
				soi.name = "PerfSoiXam"
				roam.add_child(soi)
				soi.setup({"roam": roam, "seed": 12})
				soi.add_wave([{"archetype": "soi_xam", "at": pl.global_position + pl.facing_dir() * 4.0, "opts": {"hp_scale": 40.0}}])
				soi.start()
				combat.block_override = true
				_next("soi")
		"soi":
			if t % 30 == 0:
				combat.light_override = true
			if t == 150:
				var e: MeleeEnemy = soi.enemies[0]
				print("  Sói Xám at BE6: %s, %d attacks so far" % [e.state_name(), e.attacks])
				_check(soi.state == "running" and e.is_hostile(), "the Sói Xám fight runs (%s)" % soi.state)
				mark_attacks = e.attacks
				_start_window()
			if t == 150 + WINDOW:
				_end_window()
				_check((soi.enemies[0] as MeleeEnemy).attacks > mark_attacks, "Sói Xám attacked during the window")
				soi.process_mode = Node.PROCESS_MODE_DISABLED
				combat.process_mode = Node.PROCESS_MODE_DISABLED
				combat.pose.process_mode = Node.PROCESS_MODE_DISABLED
				_next("s1")
		"s1":
			if t == 2:
				_start_window()
			if t == 2 + WINDOW:
				_end_window()
				combat.block_override = null
				_report()


func _report() -> void:
	var cost_c: float = (medians[0] - medians[1]) / 1000.0
	var trim_c: float = (trimmed[0] - trimmed[1]) / 1000.0
	var cost_b: float = (medians[0] - medians[2]) / 1000.0
	var trim_b: float = (trimmed[0] - trimmed[2]) / 1000.0
	print("  sword duel only (Za Mẫn + katana + staff + PlayerCombat + HUD): %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_c, trim_c, medians[0], medians[1], trimmed[0], trimmed[1], means[0], means[1]])
	print("  sword duel + crowd + traffic + wanted: %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_b, trim_b, medians[0], medians[2], trimmed[0], trimmed[2], means[0], means[2]])
	_check(cost_c < GATE_MS, "sword duel < 3 ms per physics frame, median (%.2f)" % cost_c)
	_check(trim_c < GATE_MS, "sword duel < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim_c)
	_check(cost_b < GATE_MS, "sword duel + crowd < 3 ms per physics frame at BE6, median (%.2f)" % cost_b)
	_check(trim_b < GATE_MS, "sword duel + crowd < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim_b)
	var cost_s: float = (medians[3] - medians[4]) / 1000.0
	var trim_s: float = (trimmed[3] - trimmed[4]) / 1000.0
	var cost_sb: float = (medians[3] - medians[2]) / 1000.0
	var trim_sb: float = (trimmed[3] - trimmed[2]) / 1000.0
	print("  Sói Xám fight only (+ PlayerCombat + HUD): %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us)" % [cost_s, trim_s, medians[3], medians[4]])
	print("  Sói Xám fight + crowd + traffic + wanted: %.2f ms median, %.2f ms trimmed mean (median %.0f vs %.0f us)" % [cost_sb, trim_sb, medians[3], medians[2]])
	_check(cost_s < GATE_MS and trim_s < GATE_MS, "Sói Xám fight < 3 ms per physics frame (%.2f / %.2f)" % [cost_s, trim_s])
	_check(cost_sb < GATE_MS and trim_sb < GATE_MS, "Sói Xám fight + crowd < 3 ms per physics frame (%.2f / %.2f)" % [cost_sb, trim_sb])
	_check(roam.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D in FreeRoam")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: SWORD DUEL PERFORMANCE (duel %.2f / %.2f ms, duel + crowd %.2f / %.2f ms, Sói Xám %.2f / %.2f ms, Sói Xám + crowd %.2f / %.2f ms median / trimmed mean < 3 ms per physics frame)" % [cost_c, trim_c, cost_b, trim_b, cost_s, trim_s, cost_sb, trim_sb])
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
