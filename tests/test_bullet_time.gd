# File: res://tests/test_bullet_time.gd
# Headless test of the Wave 3 bullet time (plan 2026-10-30-w3-shared.md, W-1):
#   M  MusicDirector.focus_muffle: the bed low-pass reaches MUFFLE_CUTOFF within MUFFLE_TIME real seconds (also at a
#      0.35x time scale), a repeated call changes nothing, release goes back to the slot's tension cutoff (open here).
# Counts frames at Engine.max_fps = 60.
# Run:  godot --headless --path . --script tests/test_bullet_time.gd
extends SceneTree

var fails: Array[String] = []
var world: Node


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST BULLET TIME (W-1) ---")
	world = Node.new()
	world.name = "BulletTimeTestWorld"
	root.add_child(world)
	await process_frame
	await _part_muffle()
	_end()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _part_muffle() -> void:
	print("  [part] M muffle")
	var md := MusicDirector.new()
	world.add_child(md)
	await process_frame
	_check(is_equal_approx(md.filter_cutoff(), MusicDirector.CUTOFF_OPEN), "M: no muffle, a plain slot plays with the filter open")
	md.focus_muffle(true)
	await _frames(4)
	var mid: float = md.muffle
	md.focus_muffle(true)   # idempotent: the slide goes on from where it is
	_check(mid > 0.0 and mid < 1.0 and md.muffle == mid, "M: a repeated focus_muffle(true) changes nothing (%.2f)" % mid)
	await _frames(8)
	_check(md.muffle == 1.0 and is_equal_approx(md.filter_cutoff(), MusicDirector.MUFFLE_CUTOFF), "M: the cutoff reaches %.0f Hz within 0.2 s" % MusicDirector.MUFFLE_CUTOFF)
	var f: AudioEffectLowPassFilter = null
	var idx: int = AudioServer.get_bus_index(MusicDirector.BUS)
	for i: int in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectLowPassFilter:
			f = AudioServer.get_bus_effect(idx, i)
	_check(f != null and absf(f.cutoff_hz - MusicDirector.MUFFLE_CUTOFF) < 2.0, "M: the live bus filter is at the muffle cutoff (%.0f)" % (f.cutoff_hz if f else -1.0))
	md.focus_muffle(false)
	await _frames(12)
	_check(md.muffle == 0.0 and is_equal_approx(md.filter_cutoff(), MusicDirector.CUTOFF_OPEN) and f != null and f.cutoff_hz > 19000.0,
		"M: release goes back to the open cutoff")
	# real time: at 0.35x the muffle still lands in about 0.15 real s
	Engine.time_scale = 0.35
	md.focus_muffle(true)
	await _frames(12)
	_check(md.muffle == 1.0, "M: at a 0.35x time scale the muffle lands within 12 real frames (%.2f)" % md.muffle)
	md.focus_muffle(false)
	await _frames(12)
	Engine.time_scale = 1.0
	_check(md.muffle == 0.0, "M: released at 0.35x as well")
	md.queue_free()
	await process_frame


func _end() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("--- BULLET TIME: SUCCESS ---")
		quit(0)
	else:
		print("--- BULLET TIME: FAIL (%d) ---" % fails.size())
		quit(1)
