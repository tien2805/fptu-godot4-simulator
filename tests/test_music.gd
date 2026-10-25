# File: res://tests/test_music.gd
# Headless test of the music wiring (spec H-D8: owner files only, no code music): the GameFX autoload owns one
# MusicDirector on the MusicBed bus (send -> Music, one low-pass filter); GameFX.music_play(slot, tension) plays every slot
# as its owner file or as silence (never a generated / synthesized stream), music_tension reaches the director, a stop
# fades out and the slot clears, stop(false) is immediate, and every caller in the game passes a known slot name.
# Independent of user://music: a slot with a file plays it, a slot without one is silent; the test never writes there.
# Run:  godot --headless --path . --script tests/test_music.gd
extends SceneTree

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST MUSIC (owner slots through GameFX) ---")
	await process_frame
	var fx: Node = root.get_node_or_null("GameFX")
	_check(fx != null, "GameFX autoload present")
	if fx == null:
		_end()
		return
	var md: MusicDirector = fx.get("music")
	_check(md != null and md.players.size() == 2, "GameFX created the MusicDirector with two crossfade players")
	if md == null:
		_end()
		return
	md.process_mode = Node.PROCESS_MODE_DISABLED   # the test drives _process itself
	var bus: int = AudioServer.get_bus_index(MusicDirector.BUS)
	_check(bus >= 0 and AudioServer.get_bus_send(bus) == "Music", "MusicBed bus sends to Music (settings volume applies)")
	var has_lp: bool = false
	for i: int in AudioServer.get_bus_effect_count(bus):
		has_lp = has_lp or AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter
	_check(has_lp, "MusicBed carries the tension low-pass")
	for p: AudioStreamPlayer in md.players:
		_check(p.bus == MusicDirector.BUS, "track %s plays on MusicBed" % p.name)
	# every slot: file or silence, never a generator / WAV
	var loaded: int = 0
	for s: String in MusicDirector.SLOTS:
		var has_file: bool = MusicDirector.slot_file(s) != ""
		if has_file and loaded >= 3:
			continue   # owner files are big: three real loads are enough here
		fx.call("music_play", s, 0.4)
		md._process(0.05)
		var st: AudioStream = md.current_stream()
		_check(md.slot == s and md.target_gain == 1.0, "music_play(%s) selects the slot" % s)
		if has_file:
			loaded += 1
			_check(st is AudioStreamOggVorbis or st is AudioStreamMP3, "%s plays the owner's file" % s)
			_check(st != null and bool(st.get("loop")), "%s loops" % s)
		else:
			_check(st == null and not md.players[md.cur].playing, "%s has no file -> silence" % s)
		for p2: AudioStreamPlayer in md.players:
			_check(not (p2.stream is AudioStreamGenerator) and not (p2.stream is AudioStreamWAV), "%s: no generated stream" % s)
	_check(is_equal_approx(md.tension, 0.4), "music_play passes the tension")
	fx.call("music_tension", 0.9)
	_check(is_equal_approx(md.tension, 0.9), "music_tension reaches the director")
	fx.call("music_tension", 3.0)
	_check(is_equal_approx(md.tension, 1.0), "tension clamps to 1")
	# stop fades out and clears the slot; stop(false) is immediate
	fx.call("music_play", "menu", 0.2)
	fx.call("music_stop", true)
	_check(md.target_gain == 0.0 and md.slot == "menu", "a fading stop keeps the slot while it fades")
	for i2: int in 40:
		md._process(0.05)
	_check(md.slot == "" and not md.players[0].playing and not md.players[1].playing, "after the fade the director is stopped")
	fx.call("music_play", "roam_day", 0.15)
	fx.call("music_stop", false)
	_check(md.slot == "" and md.target_gain == 0.0 and not md.is_audible(), "stop(false) is immediate")
	# every music_play caller passes a known slot (static check of the call sites)
	var known: Array[String] = MusicDirector.SLOTS
	var re := RegEx.create_from_string("music_play\"?,?\\s*\\(?\"([a-z0-9_]+)\"")
	for f: String in ["res://scripts/MainMenu.gd", "res://scripts/RoadManager.gd", "res://scripts/Stage2_Parking.gd",
			"res://scripts/Stage3_ClassroomFAP.gd", "res://scripts/Stage4_Vovinam.gd", "res://scripts/Stage5_Canteen.gd",
			"res://scripts/Stage6_CapstoneBoss.gd", "res://scripts/StageExtra_EOSExam.gd", "res://scripts/story/CharacterCreator.gd"]:
		var src: String = FileAccess.get_file_as_string(f)
		var ms: Array[RegExMatch] = re.search_all(src)
		_check(not ms.is_empty(), "%s plays music" % f.get_file())
		for m: RegExMatch in ms:
			_check(known.has(m.get_string(1)), "%s plays a known slot (%s)" % [f.get_file(), m.get_string(1)])
	_end()


func _end() -> void:
	if fails.is_empty():
		print("✅ SUCCESS: MUSIC (GameFX -> MusicDirector, owner slots or silence, tension, stop)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
