# File: res://tests/test_horror_perf.gd
# Performance gate of the horror toolkit (spec B-D4, B-D12): the Night Building with 4 stalkers patrolling, the flashlight
# on and the player jogging the ring corridor (a bot steers it from corner to corner; catching off so the run never stops).
# One measured window of 120 physics frames against a baseline with the stalkers, the kit, the scare director and the
# flashlight disabled (the bot keeps the player running in both). The horror layer must cost < 3 ms per physics frame
# (headless script time from the physics_frame signal to a tail node that runs after every other _physics_process, the
# phase-change frame dropped) by both statistics of test_mayhem_perf.gd:
#   - the MEDIAN (stable against OS / GC spikes),
#   - the 5 %-TRIMMED MEAN (the 6 lowest and 6 highest of 120 frames dropped), so the 10 Hz senses and re-routes count.
# Plain means are printed too. Prints the numbers for PLAN.md.
# Run:  godot --headless --path . --script tests/test_horror_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120
const LOOP: Array[Vector3] = [Vector3(-31.5, 0, 16.5), Vector3(-31.5, 0, -16.5), Vector3(31.5, 0, -16.5), Vector3(31.5, 0, 16.5)]

class PhysTail extends Node:
	var on_tail: Callable

	func _physics_process(_d: float) -> void:
		on_tail.call()


var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var lvl: NightBuilding
var timing: bool = false
var _pt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var medians: Array[float] = []
var means: Array[float] = []
var trimmed: Array[float] = []
var _wp: int = 0
var _start_pos: Array[Vector3] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST HORROR PERFORMANCE GATE ---")
	var tail := PhysTail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _tail
	root.add_child(tail)
	lvl = (load("res://scenes/story/NightBuilding.tscn") as PackedScene).instantiate()
	lvl.setup({"seed": 11, "catch_enabled": false, "auto_retry": false, "capture_mouse": false, "reduce_scares": false})
	root.add_child(lvl)
	phase = "settle"
	physics_frame.connect(_on_physics)


func _tail() -> void:
	if timing:
		samples.append(Time.get_ticks_usec() - _pt0)


func _next(p: String) -> void:
	phase = p
	t0 = frames


static func trimmed_mean(sorted: PackedInt32Array, frac: float) -> float:
	var k: int = int(floor(float(sorted.size()) * frac))
	var n: int = sorted.size() - 2 * k
	if n <= 0:
		return float(sorted[sorted.size() / 2])
	var t: int = 0
	for i: int in range(k, k + n):
		t += sorted[i]
	return float(t) / float(n)


func _close_window() -> void:
	timing = false
	var total: int = 0
	for s: int in samples:
		total += s
	means.append(float(total) / float(maxi(1, samples.size())))
	var sorted: PackedInt32Array = samples.duplicate()
	sorted.sort()
	trimmed.append(trimmed_mean(sorted, 0.05))
	medians.append(float(sorted[sorted.size() / 2]))


## The bot: jog to the next corner of the ring corridor.
func _drive() -> void:
	var p: ThirdPersonController = lvl.player
	if p == null:
		return
	var target: Vector3 = LOOP[_wp]
	var d: Vector3 = target - p.global_position
	d.y = 0.0
	if d.length() < 1.2:
		_wp = (_wp + 1) % LOOP.size()
		d = LOOP[_wp] - p.global_position
	p.yaw = atan2(-d.x, -d.z)
	p.input_override = Vector2(0, -1)


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	if lvl.state == "play":
		_drive()
	match phase:
		"settle":
			if t == 5 and lvl.state == "play":
				lvl.player.teleport(LOOP[0] + Vector3(0, 0, -2), 0.0)
				_wp = 1
			if t == 150:
				lvl.flashlight.battery = 1.0
				lvl.flashlight.set_on(true)
				_check(lvl.stalkers.size() == 4, "4 stalkers")
				for s: HorrorStalker in lvl.stalkers:
					_start_pos.append(s.global_position)
				_next("horror")
		"horror":
			if t == 1:
				samples.clear()
				timing = true
			if t == WINDOW + 1:
				_close_window()
				var moved: int = 0
				var st: Array[String] = []
				for i: int in lvl.stalkers.size():
					if lvl.stalkers[i].global_position.distance_to(_start_pos[i]) > 0.5:
						moved += 1
					st.append(lvl.stalkers[i].state)
				print("  stalkers: %d of 4 moved, states %s; flashlight lit %s, battery %.2f" % [moved, str(st), str(lvl.flashlight.is_lit()), lvl.flashlight.battery])
				_check(moved >= 3, "the stalkers patrol during the window (%d moved)" % moved)
				_check(lvl.flashlight.is_lit(), "the flashlight is on during the window")
				for n: Node in lvl.stalkers:
					n.process_mode = Node.PROCESS_MODE_DISABLED
				for n2: Node in [lvl.kit, lvl.scare, lvl.flashlight]:
					n2.process_mode = Node.PROCESS_MODE_DISABLED
				_next("base")
		"base":
			if t == 2:
				samples.clear()
				timing = true
			if t == WINDOW + 2:
				_close_window()
				var cost_med: float = (medians[0] - medians[1]) / 1000.0
				var cost_trim: float = (trimmed[0] - trimmed[1]) / 1000.0
				print("  Night Building, 4 stalkers + flashlight + kit + scare director: %.3f ms per physics frame median, %.3f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us; mean %.0f vs %.0f us)" % [cost_med, cost_trim, medians[0], medians[1], trimmed[0], trimmed[1], means[0], means[1]])
				_check(cost_med < GATE_MS, "horror layer < 3 ms per physics frame, median (%.3f)" % cost_med)
				_check(cost_trim < GATE_MS, "horror layer < 3 ms per physics frame, 5 %%-trimmed mean (%.3f)" % cost_trim)
				_check(lvl.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
				if fails.is_empty():
					print("✅ SUCCESS: HORROR PERFORMANCE (%.3f / %.3f ms median / trimmed mean < 3 ms per physics frame)" % [cost_med, cost_trim])
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
