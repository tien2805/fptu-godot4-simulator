# File: res://tests/test_mayhem_perf.gd
# Phase W performance gate (spec section 7): FreeRoam with the full daytime crowd and traffic at the BE6 spawn, 3 stars with
# the second police wave (catching off), then two measured windows of 120 physics frames against one baseline with the
# crowd, traffic, weapons, wanted level and emotes disabled:
#   W1 weapons + wanted: the loa kẹo kéo blasting into the crowd, a stink cloud, officers chasing, police bikes;
#   W2 emote: "Siuuu!" from its run-up through the landing (bystanders within 10 m react) into the hold.
# Each window must cost < 3 ms per physics frame more than the baseline (headless script time, the phase-change frame
# dropped), by two statistics of its per-frame times:
#   - the MEDIAN (stable against the laptop's OS / GC spikes),
#   - the 5 %-TRIMMED MEAN (the 6 lowest and 6 highest of 120 frames dropped), so work that does not run every frame
#     (spawns, the 1 Hz maintain, the loa's 0.2 s sonic tick) still counts.
# The plain means are printed too. Also: no GPUParticles3D anywhere in FreeRoam, Engine.time_scale back at 1.0. Prints the
# numbers for PLAN.md.
# Run:  godot --headless --path . --script tests/test_mayhem_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120

## Runs AFTER every other _physics_process: from the physics_frame signal (before the nodes) to here = the script time of
## one physics step (Performance.TIME_PHYSICS_PROCESS only updates once a second).
class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var roam: Node3D
var timing: bool = false
var _pt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var means: Array[float] = []
var trimmed: Array[float] = []
var with_w: float = 0.0
var with_e: float = 0.0
var without: float = 0.0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST MAYHEM PERFORMANCE GATE ---")
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


## Median per-frame script time of the window (us); its mean is appended to `means`, its 5 %-trimmed mean to `trimmed`.
func _window_us() -> float:
	timing = false
	if samples.is_empty():
		means.append(0.0)
		trimmed.append(0.0)
		return 0.0
	var total: int = 0
	for s: int in samples:
		total += s
	means.append(float(total) / float(samples.size()))
	var sorted: PackedInt32Array = samples.duplicate()
	sorted.sort()
	trimmed.append(trimmed_mean(sorted, 0.05))
	return float(sorted[sorted.size() / 2])


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


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	var w: WantedDirector = roam.get("wanted")
	var wd: WeaponDirector = roam.get("weapons")
	var em: EmoteDirector = roam.get("emotes")
	var pl: ThirdPersonController = roam.get("player")
	match phase:
		"settle":
			if t == 180:
				w.catch_enabled = false
				w.add_heat(25.0)
				w.three_star_t = WantedDirector.SECOND_WAVE_S
				_next("chase")
		"chase":
			if t == 600:
				var sp: PedestrianSpawner = roam.get("pedestrians")
				print("  3 stars at BE6: %d officers, %d police bikes on the way, %d pedestrians, %d impostors" % [w.officers().size(), w.pending_bikes.size(), sp.pedestrians().size(), sp.impostors.count()])
				_check(w.stars == 3 and w.officers().size() >= 3, "3 stars with officers chasing (%d)" % w.officers().size())
				wd.equip(WeaponData.Slot.LOA)
				wd.fire_override = true
				wd.spawn_stink(pl.global_position + pl.facing_dir() * 6.0)
				_next("w1")
		"w1":
			if t == 1:
				_start_window()   # the phase-change frame (stink cloud spawn, first blast) is dropped
			if t == WINDOW + 1:
				with_w = _window_us()
				wd.fire_override = false
				_next("w2_wait")
		"w2_wait":
			if t == 30:
				_check(em.play(0), "Siuuu! starts in the crowd")
				_next("w2")
		"w2":
			if t == 61:
				_start_window()   # covers the take-off, the landing (1.70 s) with the bystander reactions and the hold
			if t == 61 + WINDOW:
				with_e = _window_us()
				var n_react: int = 0
				for k: String in em.reactions.keys():
					n_react += int(em.reactions[k])
				print("  emote: %d bystanders reacted %s" % [n_react, str(em.reactions)])
				_next("base_wait")
		"base_wait":
			if t == 150:
				for n: Node in [roam.get("pedestrians"), roam.get("traffic"), wd, w, em]:
					(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
				_next("base")
		"base":
			if t == 1:
				_start_window()   # disabling removes bodies from the physics space: drop this frame
			if t == WINDOW + 1:
				without = _window_us()
				var cost_w: float = (with_w - without) / 1000.0
				var cost_e: float = (with_e - without) / 1000.0
				var trim_w: float = (trimmed[0] - trimmed[2]) / 1000.0
				var trim_e: float = (trimmed[1] - trimmed[2]) / 1000.0
				print("  W1 weapons + wanted + crowd + traffic: %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_w, trim_w, with_w, without, trimmed[0], trimmed[2], means[0], means[2]])
				print("  W2 emote + bystanders + crowd + traffic: %.2f ms per physics frame median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_e, trim_e, with_e, without, trimmed[1], trimmed[2], means[1], means[2]])
				_check(cost_w < GATE_MS, "weapons + wanted + crowd + traffic < 3 ms per physics frame at BE6 with 3 stars, median (%.2f)" % cost_w)
				_check(trim_w < GATE_MS, "weapons + wanted + crowd + traffic < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim_w)
				_check(cost_e < GATE_MS, "the Siuuu! emote with bystanders + crowd + traffic < 3 ms per physics frame, median (%.2f)" % cost_e)
				_check(trim_e < GATE_MS, "the Siuuu! emote with bystanders + crowd + traffic < 3 ms, 5 %%-trimmed mean (%.2f)" % trim_e)
				_check(roam.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D in FreeRoam")
				_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: MAYHEM PERFORMANCE (W1 %.2f / %.2f ms, W2 %.2f / %.2f ms median / trimmed mean < 3 ms per physics frame)" % [cost_w, trim_w, cost_e, trim_e])
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
