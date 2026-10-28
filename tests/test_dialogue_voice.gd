# File: res://tests/test_dialogue_voice.gd
# Headless test of the dialogue voices (plan 2026-10-29-w2-story T2-T4):
#   V. DialogueVoice: every character has a profile and the speaker mapping picks it (the protagonist by sex); warm()
#      returns at once and builds every bank on worker threads (bank() is empty until then, never synthesized on the main
#      thread); banks are cached; the timbres differ (pitch, waveform, speed); tone detection; word starts; typewriter
#      timing (fit_cps finishes a line by 75 % of its time).
#   T. CinePlayer: a subtitle types out letter by letter in sync with real time, one blip per new word on the SFX bus
#      (none while seeking), a reveal shows the whole line at once, the next line types from its own start; the skip ring
#      reads "Giữ để bỏ qua"; the hold skip takes SkipHold.HOLD (Esc or Enter).
#   C. StoryChoice after a cinematic: a Space / Enter tap in the first frame after the choice opens (meant to reveal the
#      last line) picks nothing; once armed (StoryChoice.ARM_S) Space picks; key 2 picks at once.
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
	_part_g()
	await _part_c()
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
	_check(DialogueVoice.voice_for("Phúc (tin nhắn)", "Phúc (tin nhắn)") == "phuc", "a text from 'Phúc (tin nhắn)' uses Phúc's voice")
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


class VoiceTL extends CineTimeline:
	func build() -> void:
		slot = "test_voice"
		length = 6.0
		story_end = 6.0
		actor("mr_t", {"preset": "lecturer", "seed": 1995, "glasses": true}, "Mr.T", Color("#B98CFF"))
		actor("hero", {"preset": "player", "seed": 2805, "female": true}, "Bạn", Color("#F37021"))
		key("mr_t", 0.0, Vector3(-0.5, 0.0, 0.0), 90.0)
		key("hero", 0.0, Vector3(0.5, 0.0, 0.0), -90.0)
		shot("S1", 0.0, "static", "wide", {"pos": Vector3(0.0, 1.5, 4.0), "look": Vector3(0.0, 1.3, 0.0), "fov": 45.0})
		sub(0.5, 2.0, "mr_t", "Em xem cái này, tối qua.")
		sub(3.0, 2.0, "hero", "Dạ, em xem rồi!")


func _part_t() -> void:
	print("  T: typed subtitles and voices in CinePlayer")
	var tl := VoiceTL.new()
	tl.build()
	var p := CinePlayer.new()
	root.add_child(p)
	_check(p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false}).is_empty(), "test timeline sets up")
	p.start()
	DialogueVoice.finish_all()
	_check(p._sub_voice == PackedStringArray(["mr_t", "hero_f"]), "subtitle voices: Mr.T and the female protagonist (%s)" % str(p._sub_voice))
	_check(p.voice_player.bus == CinePlayer._bus("SFX"), "voices play on the SFX bus")
	var line: String = "Em xem cái này, tối qua."
	var dt: float = 1.0 / 60.0
	var typed: Array[int] = []
	var mono: bool = true
	var last: int = -1
	while p.r < 2.6:
		p.step(dt)
		if p.r >= 0.5 and p.r < 2.5:
			var tt: String = p.overlay.sub_typed_text()
			mono = mono and tt.length() >= last and line.begins_with(tt)
			last = tt.length()
			typed.append(tt.length())
			_check(p.overlay.sub_text().ends_with(line), "sub_text keeps the whole line")
	_check(mono, "the line types out letter by letter (prefixes, never shrinking)")
	_check(typed.size() > 10 and typed[0] <= 2 and typed[typed.size() - 1] == line.length(), "from the first letter to the whole line (%d .. %d)" % [typed[0] if typed.size() > 0 else -1, last])
	var full_at: int = typed.find(line.length())
	var full_r: float = 0.5 + float(full_at) * dt
	_check(full_at > 0 and full_r <= 0.5 + 2.0 * DialogueVoice.FIT_U + 0.05, "typed in sync: complete by 75 %% of the line (%.2f s)" % full_r)
	_check(p.blips_played == 6, "one blip per word (%d)" % p.blips_played)
	# seek: silent
	var b0: int = p.blips_played
	p.seek(3.6)
	_check(p.blips_played == b0, "seeking plays no blip")
	# reveal
	p.seek(3.02)
	p.step(dt)
	_check(p.overlay.sub_typed_text().length() < "Dạ, em xem rồi!".length(), "the second line starts typing from its own start")
	p.reveal_line()
	var b1: int = p.blips_played
	p.step(dt)
	_check(p.overlay.sub_typed_text() == "Dạ, em xem rồi!", "a reveal shows the whole line (%s)" % p.overlay.sub_typed_text())
	_check(p.blips_played == b1, "no blip after a reveal")
	# skip ring
	_check(p.overlay.skip_label.text == "Giữ để bỏ qua", "skip text 'Giữ để bỏ qua'")
	_check(not p.overlay.skip_box.visible, "ring hidden while nothing is held")
	p.force_skip_hold = true
	for i: int in 12:
		p.step(dt)
	var pr: float = p.overlay.skip_progress()
	_check(pr > 0.2 and pr < 0.5 and p.overlay.skip_box.visible, "the ring fills while held (%.2f)" % pr)
	_check(is_equal_approx(CinePlayer.ESC_HOLD, 0.6) and is_equal_approx(SkipHold.HOLD, 0.6), "the hold is 0.6 s")
	var sh := SkipHold.new()
	var k: int = 0
	while not sh.step(dt, true) and k < 100:
		k += 1
	_check(k + 1 >= 35 and k + 1 <= 37, "SkipHold completes after 0.6 s (%d frames)" % (k + 1))
	_check(not SkipHold.new().step(0.5, false), "no hold, no skip")
	p.queue_free()
	await process_frame


func _part_r() -> void:
	print("  R: radio chatter and phone texts")
	var m := StoryMission.new()
	m.setup(null, {"id": "d2_chase", "title": "Bầy Sói"}, {"manual": true})
	root.add_child(m)
	m.begin()
	m.radio("Ok e, a ping vị trí Bầy Sói lên map r.", "Đuổi theo tụi nó.")
	var lbl: Label = m.radio_label
	_check(lbl.text == "ANH DUY (bộ đàm): Ok e, a ping vị trí Bầy Sói lên map r.\nDịch: Đuổi theo tụi nó.", "Anh Duy's radio text keeps its format (%s)" % lbl.text)
	_check(lbl.visible_characters >= 0 and lbl.visible_characters <= "ANH DUY (bộ đàm): ".length() + 1, "the line starts typing (%d)" % lbl.visible_characters)
	_check(m.radio_typer.voice == "anh_duy" and m.radio_typer.player.bus == CinePlayer._bus("SFX"), "Anh Duy's voice on the SFX bus")
	var dt: float = 1.0 / 60.0
	var steps: int = 0
	while not m.radio_typer.done() and steps < 600:
		m.advance(dt)
		steps += 1
	_check(m.radio_typer.done() and lbl.visible_characters == -1, "typed to the end, the Dịch: line shows (%d steps)" % steps)
	_check(m.radio_typer.blips == 11, "one blip per word on the radio (%d)" % m.radio_typer.blips)
	# the beat's scripted chatter plays on the mission clock once the panel is free
	var first: Array = StoryRadio.lines("d2_chase")[0]
	while m.clock < float(first[0]) + 0.2:
		m.advance(dt)
	_check(lbl.text.contains(String(first[2])) and lbl.text.contains("Dịch: " + String(first[3])), "the d2_chase chatter plays at %.0f s" % float(first[0]))
	m.radio_as("mr_t", "Em nhớ tắt đèn flash.")
	_check(lbl.text == "MR.T (điện thoại): Em nhớ tắt đèn flash." and m.radio_typer.voice == "mr_t", "radio_as: Mr.T on the phone, his voice")
	m.abort()
	# scripts: known speakers, ordered times, plain text
	for bid: String in StoryRadio.SCRIPTS.keys():
		var lt: float = -1.0
		for l: Array in StoryRadio.SCRIPTS[bid]:
			_check(l.size() == 4 and float(l[0]) > lt and StoryRadio.PREFIX.has(String(l[1])), "%s: radio line %s" % [bid, str(l)])
			_check(not StoryMissions.beat(bid).is_empty(), "%s is a story beat" % bid)
			for txt: String in [String(l[2]), String(l[3])]:
				for i: int in txt.length():
					_check(txt.unicode_at(i) < 0x2000, "%s: plain text (%s)" % [bid, txt])
			_check(String(l[1]) != "anh_duy" or String(l[3]) != "", "%s: Anh Duy's lines carry a Dịch: line" % bid)
			lt = float(l[0])
	# phone toast typer (UI bus)
	var ty := StoryRadio.new("UI")
	root.add_child(ty)
	var tl2 := Label.new()
	root.add_child(tl2)
	ty.type_text(tl2, "Phúc: ", "Ê, mai thi rồi đó!", "", DialogueVoice.voice_for("", "Phúc"))
	_check(ty.voice == "phuc" and ty.player.bus == CinePlayer._bus("UI"), "a text from Phúc types with his voice on the UI bus")
	for i2: int in 120:
		ty.step(dt)
	_check(ty.done() and tl2.text == "Phúc: Ê, mai thi rồi đó!", "the text completes")
	ty.queue_free()
	tl2.queue_free()
	await process_frame


func _part_g() -> void:
	print("  G: gestures")
	for mv: String in ["talk_ual", "fold_arms", "head_no", "facepalm", "shrug", "laugh", "point", "arms_crossed"]:
		_check(CineMoves.has_move(mv), "move %s" % mv)
	var src: Array = (CineMoves.MOVES["fold_arms"] as Dictionary)["src"]
	_check(String(src[0]["t"]) == "ual2" and String(src[0]["a"]) == "Idle_FoldArms" and String(src[src.size() - 1]["t"]) == "code", "fold_arms: the UAL clip first, a code fallback")
	var fp: Dictionary = CineMoves.code_pose("facepalm", 0.5)
	_check((fp["elbow_r"] as Vector3).x > 2.0 and (fp["head"] as Vector3).x > 0.3, "facepalm: the hand at the face, head down")
	var f0: Dictionary = CineMoves.code_pose("facepalm", 0.0)
	_check((f0["elbow_r"] as Vector3).x < 0.4, "facepalm eases in from rest")
	var sh: Dictionary = CineMoves.code_pose("shrug", 0.5)
	_check((sh["shoulder_r"] as Vector3).z > 0.4 and (sh["shoulder_l"] as Vector3).z < -0.4, "shrug: both arms out")
	var la: Dictionary = CineMoves.code_pose("laugh", 0.3)
	_check((la["torso"] as Vector3).x > 0.08 and (la["head"] as Vector3).x < -0.15, "laugh: leaning back, head up")


func _part_c() -> void:
	print("  C: the choice ignores reveal taps until armed")
	var def: Dictionary = (CineTimeline.load_slot("cine_d1_choice").choice_def as Dictionary).duplicate(true)
	def["record"] = false   # the story state stays untouched
	var c: StoryChoice = StoryChoice.open(root, def, true)
	c.step(1.0 / 60.0)
	for k: Key in [KEY_SPACE, KEY_ENTER]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.pressed = true
		c._input(ev)
	_check(c.result == "" and c.phase == 0, "a Space / Enter tap in the first frame after the choice opens picks nothing")
	while c.t < StoryChoice.ARM_S + 0.02:
		c.step(1.0 / 60.0)
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_SPACE
	ev2.pressed = true
	c._input(ev2)
	_check(c.result == String((def["options"] as Array)[0]["key"]), "armed: Space picks the focused option (%s)" % c.result)
	c.step(1.0)
	var c2: StoryChoice = StoryChoice.open(root, def, true)
	c2.step(1.0 / 60.0)
	var ev3 := InputEventKey.new()
	ev3.physical_keycode = KEY_2
	ev3.pressed = true
	c2._input(ev3)
	_check(c2.result == String((def["options"] as Array)[1]["key"]), "key 2 picks at once")
	c2.step(1.0)
	await process_frame
	paused = false
