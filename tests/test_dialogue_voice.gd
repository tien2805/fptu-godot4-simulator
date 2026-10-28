# File: res://tests/test_dialogue_voice.gd
# Headless test of the dialogue voices (plan 2026-10-29-w2-story T2-T4):
#   V. DialogueVoice: every character has a profile and the speaker mapping picks it (the protagonist by sex); warm()
#      returns at once and builds every bank on worker threads (bank() is empty until then, never synthesized on the main
#      thread); banks are cached; the timbres differ (pitch, waveform, speed); tone detection; word starts; typewriter
#      timing (fit_cps finishes a line by 75 % of its time).
#   T. CinePlayer: a subtitle types out letter by letter in sync with real time, one blip per new word on the SFX bus
#      (none while seeking), a reveal shows the whole line at once, the next line types from its own start; the skip ring
#      reads "Giữ để bỏ qua"; the hold skip takes SkipHold.HOLD (Esc or Enter).
#   R. Radio and phone: StoryRadio types the line with the speaker's voice and its "Dịch:" line, beat scripts are valid
#      (known speakers, times in order, no emoji).
# Run:  godot --headless --path . --script tests/test_dialogue_voice.gd
extends SceneTree

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("== test_dialogue_voice")
	call_deferred("_run")


func _run() -> void:
	await _part_v()
	if has_method("_part_t"):
		await call("_part_t")
	if has_method("_part_r"):
		await call("_part_r")
	if fails.is_empty():
		print("SUCCESS test_dialogue_voice")
		quit(0)
	else:
		print("FAILED test_dialogue_voice: %d" % fails.size())
		quit(1)


func _part_v() -> void:
	print("  V: voices")
	var want: Array[String] = ["hero_m", "hero_f", "mr_t", "phuc", "linh", "anh_duy", "chu_bay", "soi_xam", "alexander", "za_man",
		"thi_lo", "van_lo", "dolly"]
	for id: String in want:
		_check(DialogueVoice.PROFILES.has(id), "profile %s" % id)
	_check(DialogueVoice.voice_for("hero", "", {"female": true}) == "hero_f" and DialogueVoice.voice_for("hero", "", {"female": false}) == "hero_m", "the protagonist's voice follows the sex")
	_check(DialogueVoice.voice_for("mr_t") == "mr_t" and DialogueVoice.voice_for("x", "Anh Duy") == "anh_duy" and DialogueVoice.voice_for("dolly_unmasked") == "dolly"
		and DialogueVoice.voice_for("lum_van_lo") == "van_lo" and DialogueVoice.voice_for("y", "Lùm Thị Lọ") == "thi_lo", "cast ids and speaker names map to voices")
	_check(DialogueVoice.voice_for("nobody", "Ai đó") == "generic", "unknown speakers get the generic voice")
	# distinct timbres: no two profiles share pitch, waveform and speed
	var seen: Dictionary = {}
	for id2: String in want:
		var p: Dictionary = DialogueVoice.PROFILES[id2]
		var k: String = "%s|%d|%d" % [String(p["wave"]), int(float(p["f0"]) / 10.0), int(float(p["cps"]))]
		_check(not seen.has(k), "%s has its own timbre (same as %s)" % [id2, String(seen.get(k, ""))])
		seen[k] = id2
	# worker-thread build
	DialogueVoice.clear_cache()
	var t0: int = Time.get_ticks_usec()
	var n: int = DialogueVoice.warm(want)
	var warm_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_check(n == want.size(), "one task per voice (%d)" % n)
	_check(warm_ms < 20.0, "warm returns at once (%.2f ms)" % warm_ms)
	_check(DialogueVoice.warm(want) == 0, "pending voices are not started twice")
	var guard: int = 0
	while DialogueVoice.pending() and guard < 600:
		await process_frame
		guard += 1
	_check(not DialogueVoice.pending(), "every bank built off the main thread (%d frames)" % guard)
	for id3: String in want:
		var b: Array = DialogueVoice.bank(id3)
		_check(b.size() == DialogueVoice.TONES * DialogueVoice.STEPS.size(), "%s: %d blips" % [id3, b.size()])
		if b.size() > 0:
			var w: AudioStreamWAV = b[0]
			_check(w.get_length() > 0.03 and w.get_length() < 0.25, "%s blip length %.3f s" % [id3, w.get_length()])
	_check(DialogueVoice.warm(want) == 0 and DialogueVoice.bank("mr_t") == DialogueVoice.bank("mr_t"), "banks are cached")
	_check(DialogueVoice.blip("mr_t", "thầy") != null and DialogueVoice.blip("mr_t", "thầy") == DialogueVoice.blip("mr_t", "thầy"), "a word always gets the same blip")
	_check(DialogueVoice.blip("generic_none", "a") == null, "an unbuilt voice is silent")
	# pitch differs between low and high voices (zero crossings of the flat blip)
	_check(float(DialogueVoice.PROFILES["soi_xam"]["f0"]) * 3.0 < float(DialogueVoice.PROFILES["thi_lo"]["f0"]), "Sói Xám is far lower than Thị Lọ")
	_check(_crossings(DialogueVoice.synth_blip("hero_m", 0)) < _crossings(DialogueVoice.synth_blip("hero_f", 0)), "the male protagonist is lower than the female")
	# tones
	_check(DialogueVoice.tone_of("ma") == 0 and DialogueVoice.tone_of("má") == 1 and DialogueVoice.tone_of("mà") == 2
		and DialogueVoice.tone_of("mả") == 3 and DialogueVoice.tone_of("mã") == 3 and DialogueVoice.tone_of("mạ") == 4
		and DialogueVoice.tone_of("Thầy") == 2 and DialogueVoice.tone_of("ĐƯỢC") == 4, "tone marks")
	# typewriter maths
	var line: String = "Em xem cái này, tối qua."
	_check(Array(DialogueVoice.word_starts(line)) == [0, 3, 7, 11, 16, 20], "word starts %s" % str(DialogueVoice.word_starts(line)))
	_check(Array(DialogueVoice.new_words(line, 0, 4)) == ["Em", "xem"], "new words as the line types")
	_check(DialogueVoice.chars_at(line, 0.0, 20.0) == 0 and DialogueVoice.chars_at(line, 0.5, 20.0) == 11 and DialogueVoice.chars_at(line, 9.0, 20.0) == line.length(), "chars at a time")
	var cps: float = DialogueVoice.fit_cps(line, 1.0, 10.0)
	_check(float(line.length()) / cps <= 0.75 + 1e-4, "fit_cps finishes the line by 75 %% of its time (%.1f cps)" % cps)
	_check(DialogueVoice.fit_cps("Dạ!", 3.0, 20.0) == 20.0, "a short line keeps the voice's own speed")


func _crossings(buf: PackedFloat32Array) -> int:
	var n: int = 0
	for i: int in range(1, int(buf.size() * 0.5)):
		if (buf[i - 1] < 0.0) != (buf[i] < 0.0):
			n += 1
	return n
