# File: res://tests/test_story_call.gd
# Headless test of the 3 a.m. call (spec A2-D8, A2-D14), driven with manual 1/60 s steps: black fade, ringing with the
# looping phone_ring_3am, auto-answer at 6 s, early answer with [E], whisper_bed + static_burst (no voice file), typed
# subtitle reaching "…Mày… còn… 7 ngày…", hang-up and fade out about 10 s after an immediate answer, Esc blocked from the
# pause menu while it runs, hold-Esc skip, "Giảm hù dọa" removes the shake and the flash, generic N.
# Run:  godot --headless --path . --script tests/test_story_call.gd
extends SceneTree

const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var ended: Array = []
var holder: Node


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _process(_d: float) -> bool:
	frames += 1
	if frames < 2:
		return false
	_run()
	if fails.is_empty():
		print("✅ SUCCESS: STORY CALL (fade, ring, auto-answer, voice, subtitle, hang-up, skip, reduce scares)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true


func _make(n: int, opts: Dictionary) -> StoryCall:
	if holder == null:
		holder = Node.new()
		holder.name = "CallHolder"
		root.add_child(holder)
	var c := StoryCall.new()
	holder.add_child(c)
	ended = []
	c.finished.connect(func(sk: bool) -> void: ended.append(sk))
	c.start(n, opts)
	return c


func _run_until(c: StoryCall, secs: float) -> int:
	var n: int = 0
	while ended.is_empty() and float(n) * DT < secs:
		c.step(DT)
		n += 1
	return n


func _run() -> void:
	var sm: Node = root.get_node_or_null("StageManager")
	# 1. auto-answer
	var c: StoryCall = _make(7, {"manual": true, "reduce": false})
	_check(c.phase == "fade" and c.layer >= 100, "starts with the black fade above the HUD")
	if sm:
		_check(bool(sm.get("cinematic_active")) and not bool(sm.call("_can_pause")), "Esc cannot open the pause menu during the call")
	_run_until(c, 0.9)
	_check(c.phase == "ring" and c.loop_player.playing and c.loop_player.stream == StoryAudio.stream("phone_ring_3am"), "ringing with phone_ring_3am after the fade")
	_check(c.caller_label.text == "SỐ LẠ", "caller SỐ LẠ · 03:00")
	_run_until(c, 6.0)
	_check(c.phase == "voice" and c.auto_answered and absf(c.answered_at - 6.8) < 0.05, "auto-answers 6 s after ringing (at %.2f s)" % c.answered_at)
	_check(c.loop_player.stream == StoryAudio.stream("whisper_bed"), "the voice is whisper_bed (+ static_burst), no recorded voice")
	c.free()
	# 2. answer at once: ~10 s total, subtitle, shake + flash
	c = _make(7, {"manual": true, "reduce": false})
	_run_until(c, 1.0)
	var ek := InputEventKey.new()
	ek.physical_keycode = KEY_E
	ek.pressed = true
	c._input(ek)
	_check(c.phase == "voice" and not c.auto_answered, "[E] answers")
	_check(c.shake_used and c.flash_used, "shake and flash on answer")
	_run_until(c, 6.0)
	_check(c.subtitle == "…Mày… còn… 7 ngày…", "typed subtitle reaches the full line: %s" % c.subtitle)
	_run_until(c, 10.0)
	_check(ended == [false], "finishes on its own")
	var after: float = c.total - c.answered_at
	_check(absf(after - 9.2) < 0.1 and c.total < 11.0, "about 10 s: %.2f s after the answer, %.2f s in all" % [after, c.total])
	_check(not c.visible and not c.loop_player.playing, "hidden and silent at the end")
	if sm:
		_check(not bool(sm.get("cinematic_active")), "cinematic flag cleared")
	c.free()
	# 3. reduce scares
	c = _make(7, {"manual": true, "reduce": true})
	_run_until(c, 1.0)
	c.answer()
	_run_until(c, 0.5)
	_check(not c.shake_used and not c.flash_used and c.flash_rect.color.a == 0.0, "Giảm hù dọa: no shake, no flash")
	c.free()
	# 4. hold-Esc skip, generic N
	c = _make(3, {"manual": true, "reduce": false})
	_check(c.full_line() == "…Mày… còn… 3 ngày…", "generic in N")
	_run_until(c, 1.5)
	c.force_skip_hold = true
	var n: int = _run_until(c, 2.0)
	_check(ended == [true] and n <= 50, "hold Esc skips (%d steps)" % n)
	if sm:
		_check(not bool(sm.get("cinematic_active")), "flag cleared after a skip")
	c.free()
