# File: res://tests/test_story_audio.gd
# Headless test of StoryAudio (spec A2-D9, A2-D14): all 17 meme / horror cues synthesize, each length in its range and
# not silent, the four looping cues loop, an owner file in the (temp) sfx folder overrides a cue, CineAudio.sfx() serves the
# story cues, a timeline using them validates, warm() returns at once and the cues are cached afterwards (no main-thread
# stall), cue_db() lowers horror cues 6 dB while "Giảm hù dọa" is on. Never touches the owner's user://sfx.
# Run:  godot --headless --path . --script tests/test_story_audio.gd
extends SceneTree

const TMP_DIR: String = "user://test_story_sfx/"
var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY AUDIO ---")
	StoryAudio.sfx_dir = TMP_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
	_cleanup()
	StoryAudio.clear_cache()
	_check(StoryAudio.CUES.size() == 17, "17 story cues (got %d)" % StoryAudio.CUES.size())
	_check(not StoryAudio.CUES.has("slide_whistle") and CineAudio.SFX_CUES.has("slide_whistle"), "slide_whistle stays the A1 cue")
	_warm()
	_cues()
	_override()
	_timeline()
	_reduce()
	_cleanup()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_DIR))
	StoryAudio.sfx_dir = "user://sfx/"
	if fails.is_empty():
		print("✅ SUCCESS: STORY AUDIO (17 cues, loops, override, warm without stall, reduce scares)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _cleanup() -> void:
	for ext: String in [".wav", ".ogg", ".mp3"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_DIR + "bonk" + ext))


func _warm() -> void:
	var t0: int = Time.get_ticks_usec()
	var task: int = StoryAudio.warm(StoryAudio.CUES + StoryAudio.EXTRA)
	var dt_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("  warm() returned in %.2f ms (task %d)" % [dt_ms, task])
	_check(task >= 0 and dt_ms < 16.0, "warm() starts a worker task and returns within a frame (%.2f ms)" % dt_ms)
	var waited: int = 0
	while not StoryAudio.poll() and waited < 30000:
		OS.delay_msec(10)
		waited += 10
	_check(not StoryAudio.warm_pending(), "warm task finished")
	var worst: float = 0.0
	for cue: String in StoryAudio.CUES:
		var t1: int = Time.get_ticks_usec()
		StoryAudio.stream(cue)
		worst = maxf(worst, float(Time.get_ticks_usec() - t1) / 1000.0)
	print("  worst stream() after warm: %.3f ms, built on the worker: %d" % [worst, StoryAudio.warm_builds])
	_check(worst < 2.0 and StoryAudio.warm_builds >= 17, "every cue comes from the warm cache (worst %.3f ms)" % worst)
	_check(StoryAudio.warm(StoryAudio.CUES) == -1, "warming cached cues does nothing")


func _cues() -> void:
	for cue: String in StoryAudio.CUES + StoryAudio.EXTRA:
		var st: AudioStream = StoryAudio.stream(cue)
		_check(st is AudioStreamWAV, "%s is a WAV stream" % cue)
		if not (st is AudioStreamWAV):
			continue
		var w: AudioStreamWAV = st
		var L: float = w.get_length()
		var rng: Array = StoryAudio.LENGTHS[cue]
		_check(L >= float(rng[0]) and L <= float(rng[1]), "%s length %.2f s in %s" % [cue, L, str(rng)])
		var samples: PackedFloat32Array = StoryAudio.synth_samples(cue)
		var peak: float = 0.0
		for v: float in samples:
			peak = maxf(peak, absf(v))
		_check(peak > 0.05, "%s is audible (peak %.2f)" % [cue, peak])
		var loops: bool = w.loop_mode == AudioStreamWAV.LOOP_FORWARD
		_check(loops == (cue in StoryAudio.LOOPS), "%s loop flag %s" % [cue, str(loops)])
		if loops:
			_check(w.loop_end == w.data.size() / 2, "%s loops over the whole cue" % cue)
	var once: AudioStream = CineAudio.sfx("heartbeat")
	_check(once is AudioStreamWAV and (once as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED
		and absf(once.get_length() - StoryAudio.stream("heartbeat").get_length()) < 0.001, "CineAudio.sfx() serves a one-shot copy of a looping story cue")
	_check(CineAudio.sfx("bonk") == StoryAudio.stream("bonk"), "CineAudio.sfx() serves the story cue")
	_check(CineAudio.sfx("impact_light") is AudioStreamWAV, "A1 cues unchanged")
	for cue2: String in ["heartbeat", "whisper_bed", "music_box"]:
		_check(cue2 in StoryAudio.LOOPS, "%s loops (A2-D9)" % cue2)


func _override() -> void:
	var buf: PackedFloat32Array = CineAudio._tone(0.75, 1000.0, 1000.0, 0.4, 0.0)
	var w: AudioStreamWAV = CineAudio._to_wav(buf)
	_check(w.save_to_wav(TMP_DIR + "bonk.wav") == OK, "test override written")
	StoryAudio.clear_cache()
	_check(StoryAudio.override_file("bonk") == TMP_DIR + "bonk.wav", "override found in the sfx folder")
	var st: AudioStream = StoryAudio.stream("bonk")
	_check(st != null and absf(st.get_length() - 0.75) < 0.02, "owner file wins over the synthesized bonk (%.2f s)" % (st.get_length() if st else -1.0))
	_check(StoryAudio.warm(["bonk"]) == -1, "warm skips overridden cues")
	_cleanup()
	StoryAudio.clear_cache()
	_check(absf(StoryAudio.stream("bonk").get_length() - 0.75) > 0.1, "without the file the synthesized cue is back")


func _timeline() -> void:
	var tl := CineTimeline.new()
	tl.slot = "story_audio_test"
	tl.length = 3.0
	tl.story_end = 3.0
	tl.actor("hero", {"preset": "player", "seed": 1}, "Bạn")
	tl.shot("S1", 0.0, "static", "wide", {"pos": Vector3(0, 1.6, 4), "look": Vector3(0, 1, 0)})
	tl.sfx_at(1.0, "ba_dum_tss")
	tl.sfx_at(2.0, "heartbeat")
	var errs: PackedStringArray = tl.validate()
	_check(errs.is_empty(), "a timeline with story cues validates: %s" % str(errs))
	tl.sfx_at(2.5, "no_such_cue")
	_check(not tl.validate().is_empty(), "an unknown cue is still rejected")


func _reduce() -> void:
	var fx: Node = root.get_node_or_null("GameFX")
	_check(fx != null, "GameFX autoload present")
	if fx == null:
		return
	var was: bool = bool(fx.get("reduce_scares"))
	fx.set("reduce_scares", false)
	_check(StoryAudio.cue_db("heartbeat") == 0.0 and StoryAudio.cue_db("violin_screech") == 0.0, "full volume by default")
	fx.set("reduce_scares", true)
	_check(StoryAudio.cue_db("heartbeat") == -6.0 and StoryAudio.cue_db("phone_ring_3am") == -6.0, "horror -6 dB with Giảm hù dọa")
	_check(StoryAudio.cue_db("ba_dum_tss") == 0.0 and StoryAudio.cue_db("impact_heavy") == 0.0, "meme and A1 cues unchanged")
	fx.set("reduce_scares", was)
	var box := VBoxContainer.new()
	root.add_child(box)
	fx.call("build_story_settings", box)
	var cb: CheckButton = box.find_child("ReduceScaresCheck", true, false) as CheckButton
	_check(cb != null and cb.text == "Giảm hù dọa" and cb.button_pressed == was, "settings row ReduceScaresCheck 'Giảm hù dọa'")
	_check((load("res://scripts/GameFX.gd") as Script).get_script_constant_map()["TOD_PRESETS"].has("sunset"), "TOD preset sunset exists (A2-D13)")
	box.queue_free()
