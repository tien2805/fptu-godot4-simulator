# File: res://tests/test_music_slots.gd
# Headless test of spec H-D8 / H-D9 ("tuyệt đối không xài nhạc code nữa"):
#   - the slot catalogue: every required slot (menu, roam, stages, missions, night, every cinematic timeline, replays,
#     wanted_busted) is known, resolves to an owner file in user://music or to silence, and is listed in
#     docs/cinematics/music_suggestions.md;
#   - no synthesized music path: a static scan of the scripts (no AudioStreamGenerator except the absent-bell SFX, no
#     synth_cue / synth_sting / sting / music_hits / STYLES) plus runtime checks (MusicDirector and CinePlayer never hold a
#     generated or WAV music stream);
#   - MusicDirector crossfades (test streams stand in for owner files), same-slot no-op, fading back in, silence for a
#     missing file; tension -> volume and low-pass cutoff (curve and the live bus filter);
#   - roam_day / roam_night from every time-of-day preset (sunset = day);
#   - NightMusic with a fake level: stealth / tense / chase / hidden / escape from the stalker states, the kit, doors and
#     the optional alarm; 1.2 s crossfades; hidden ducks to silence; a track resumes where it left off; lazy loading.
# Never writes to user://music. Test streams are silent WAV loops built here (not game music).
# Run:  godot --headless --path . --script tests/test_music_slots.gd
extends SceneTree

const REQUIRED: Array[String] = ["menu", "roam_day", "roam_night", "stage1_race", "stage2_parking", "stage3_classroom",
	"stage4_vovinam", "stage5_canteen", "stage6_capstone", "stage_extra_exam", "mission_stakeout", "mission_chase",
	"mission_fight", "mission_canteen", "mission_corridor", "night_stealth", "night_tense", "night_chase", "night_escape",
	"cine_d1_intro", "cine_d1_corridor", "cine_d1_choice", "cine_d4_intro", "cine_d4_stare", "wanted_busted",
	"seg_d0_race", "seg_d0_exam", "seg_d1_chase", "seg_d4_escape",
	# Wave 3 (plan 2026-10-30-w3-shared.md T1)
	"meme_mannequin", "mission_fire_hack"]

var fails: Array[String] = []
var world: Node   # every test node lives under this one root child (GameFX themes new root children with a deferred call)


class FakeStalker extends RefCounted:
	var state: String = "PATROL"


class FakeKit extends RefCounted:
	var hidden: bool = false
	func is_hidden() -> bool:
		return hidden


class FakeLevel extends Node:
	var state: String = "play"
	var doors_unlocked: bool = false
	var kit: FakeKit = FakeKit.new()
	var stalkers: Array = [FakeStalker.new(), FakeStalker.new()]


class FakeAlarmLevel extends FakeLevel:
	var alarm: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _loop(secs: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var d := PackedByteArray()
	d.resize(int(secs * 22050.0) * 2)
	w.data = d
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = int(secs * 22050.0)
	return w


func _initialize() -> void:
	print("--- TEST MUSIC SLOTS (H-D8 / H-D9) ---")
	world = Node.new()
	world.name = "MusicTestWorld"
	root.add_child(world)
	await process_frame
	_catalogue()
	_static_scan()
	_runtime_no_synth()
	_curves()
	await _crossfade()
	await _night_music()
	_end()


func _catalogue() -> void:
	var all: PackedStringArray = MusicDirector.all_slots()
	for s: String in REQUIRED:
		_check(all.has(s), "slot %s is in the catalogue" % s)
	for t: String in CineTimeline.slots():
		_check(all.has(CineTimeline.load_slot(t).music_slot), "cinematic %s's music slot is in the catalogue" % t)
	# every story mission (and both fights) has its owner slot (StoryRoam.MISSION_MUSIC; Phase C: the bridge horror beat
	# plays a night track, the Sói Xám duel and the basement tasks their own slots)
	for mk: String in StoryMissions.MISSIONS + ["fight"]:
		var ms: String = String(StoryRoam.MISSION_MUSIC.get(mk, ""))
		_check(StoryRoam.MISSION_MUSIC.has(mk) and (MusicDirector.SLOTS.has(ms) or MusicDirector.NIGHT_SLOTS.has(ms)),
			"mission %s plays a known slot (%s)" % [mk, String(StoryRoam.MISSION_MUSIC.get(mk, "?"))])
	for fk: String in StoryRoam.FIGHT_MUSIC.keys():
		_check(MusicDirector.SLOTS.has(String(StoryRoam.FIGHT_MUSIC[fk])), "fight %s plays a known slot" % fk)
	for tk: String in StoryMissions.LAIR_TASKS:
		if StoryTower.LAIR_MUSIC.has(tk):   # Day 7 (w4-day7): the tower's tasks; the blackout is silent by design
			var tm: String = String(StoryTower.LAIR_MUSIC[tk])
			_check(MusicDirector.SLOTS.has(tm) or (tm == "" and tk == "boss_dark"), "tower task %s plays a known slot" % tk)
			continue
		_check(MusicDirector.SLOTS.has(String(StoryBasement.LAIR_MUSIC.get(tk, ""))), "basement task %s plays a known slot" % tk)
	for rs: String in ["seg_d2_chase", "seg_d3_gunfight", "seg_d3_crates", "seg_d5_gunfight", "seg_d5_hack"]:
		_check(MusicDirector.REPLAY_SLOTS.has(rs), "the Phase C replay %s is a slot" % rs)
	var doc: String = FileAccess.get_file_as_string("res://docs/cinematics/music_suggestions.md")
	var loads: int = 0
	var files: int = 0
	for s2: String in all:
		var f: String = MusicDirector.slot_file(s2)
		var own: String = s2 if not CineAudio.SLOT_FALLBACK.has(s2) or f.contains("/" + s2 + ".") else String(CineAudio.SLOT_FALLBACK[s2])
		_check(f == "" or (f.begins_with("user://music/" + own + ".") and (f.ends_with(".ogg") or f.ends_with(".mp3"))),
			"%s resolves to its owner file or to silence (%s)" % [s2, f if f != "" else "silence"])
		if f == "":
			_check(MusicDirector.load_slot(s2) == null and CineAudio.load_music(s2) == null, "%s: no file -> silence" % s2)
		else:
			files += 1
			if loads < 2:   # owner files are several MB each: two real loads prove the path
				loads += 1
				var st: AudioStream = MusicDirector.load_slot(s2)
				_check((st is AudioStreamOggVorbis or st is AudioStreamMP3) and bool(st.get("loop")), "%s loads as a looping owner track" % s2)
		_check(doc.contains("`%s`" % s2), "music_suggestions.md lists `%s`" % s2)
	print("  %d slots, %d with an owner file on this machine" % [all.size(), files])


func _static_scan() -> void:
	var banned: Array[String] = ["synth_cue", "synth_sting", "_synth_job", "music_hits", "MusicDirector.STYLES", "CineReplay.sting", "_sting_cache"]
	var scripts: Array[String] = []
	_collect("res://scripts", scripts)
	_check(scripts.size() > 50, "scanned %d scripts" % scripts.size())
	for p: String in scripts:
		var src: String = FileAccess.get_file_as_string(p)
		for b: String in banned:
			_check(not src.contains(b), "%s has no %s" % [p.get_file(), b])
		if src.contains("AudioStreamGenerator"):
			_check(p.ends_with("HUDManager.gd"), "%s uses AudioStreamGenerator (only the absent-bell SFX may)" % p.get_file())
	for p2: String in ["res://scripts/MusicDirector.gd", "res://scripts/story/NightMusic.gd", "res://scripts/cine/CinePlayer.gd",
			"res://scripts/cine/CineReplay.gd"]:
		var src2: String = FileAccess.get_file_as_string(p2)
		for b2: String in ["AudioStreamGenerator", "AudioStreamWAV", "_tone(", "_noise(", "_to_wav(", "STYLES"]:
			_check(not src2.contains(b2), "%s builds no audio (%s)" % [p2.get_file(), b2])


func _collect(dir: String, out: Array[String]) -> void:
	for f: String in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			_collect(dir + "/" + f.trim_suffix("/"), out)
		elif f.ends_with(".gd"):
			out.append(dir + "/" + f)


func _runtime_no_synth() -> void:
	var md := MusicDirector.new()
	world.add_child(md)
	md.process_mode = Node.PROCESS_MODE_DISABLED
	for s: String in MusicDirector.SLOTS:
		if MusicDirector.slot_file(s) != "":
			continue   # a real owner file is checked above; here only the silent path
		md.play(s, 0.0)
		for p: AudioStreamPlayer in md.players:
			_check(p.stream == null and not p.playing, "%s without a file: nothing plays (no generated stream)" % s)
	md.play("hd8_no_such_slot", 0.0)
	_check(md.slot == "hd8_no_such_slot" and md.current_stream() == null and not md.players[0].playing and not md.players[1].playing,
		"a slot without a file: nothing plays (no generated stream)")
	md.free()
	var ca := CineAudio.new()
	_check(ca.has_method("music_file") and not ca.has_method("synth_cue") and not ca.has_method("synth_sting"), "CineAudio has no music synthesis")
	# a cinematic whose slot has no owner file plays without music
	var tl: CineTimeline = (load("res://tests/support/cine_test_timeline.gd") as GDScript).new()
	tl.build()
	var cp := CinePlayer.new()
	world.add_child(cp)
	_check(cp.setup(tl, Transform3D.IDENTITY, {"manual": true}).is_empty() and cp.is_ready() and cp.music.stream == null,
		"cinematic without an owner file: no music stream, ready at once")
	cp.free()


func _curves() -> void:
	_check(is_equal_approx(MusicDirector.tension_db(0.0), MusicDirector.TENSION_DB_MIN) and is_equal_approx(MusicDirector.tension_db(1.0), 0.0),
		"tension_db: %.1f dB at 0, 0 dB at 1" % MusicDirector.TENSION_DB_MIN)
	_check(is_equal_approx(MusicDirector.tension_cutoff(0.0), MusicDirector.CUTOFF_MIN), "cutoff %.0f Hz at tension 0" % MusicDirector.CUTOFF_MIN)
	_check(is_equal_approx(MusicDirector.tension_cutoff(MusicDirector.CUTOFF_OPEN_AT), 20000.0) and is_equal_approx(MusicDirector.tension_cutoff(1.0), 20000.0),
		"low-pass fully open from tension %.1f" % MusicDirector.CUTOFF_OPEN_AT)
	var prev_db: float = -INF
	var prev_c: float = 0.0
	for i: int in 11:
		var t: float = float(i) / 10.0
		_check(MusicDirector.tension_db(t) >= prev_db and MusicDirector.tension_cutoff(t) >= prev_c, "tension curves rise at %.1f" % t)
		prev_db = MusicDirector.tension_db(t)
		prev_c = MusicDirector.tension_cutoff(t)
	_check(MusicDirector.tension_db(-1.0) == MusicDirector.tension_db(0.0) and MusicDirector.tension_db(2.0) == 0.0, "tension clamps")
	# roam_day / roam_night from every time-of-day preset
	var presets: Dictionary = (load("res://scripts/GameFX.gd") as GDScript).get_script_constant_map()["TOD_PRESETS"]
	_check(presets.has("night") and presets.has("sunset"), "the presets include night and sunset")
	for k: String in presets.keys():
		var want: String = "roam_night" if k == "night" else "roam_day"
		_check(MusicDirector.roam_slot(k) == want, "time of day %s -> %s" % [k, want])
	_check(MusicDirector.roam_slot("outdoor") == "roam_day", "alias outdoor -> roam_day")


func _crossfade() -> void:
	var a: AudioStreamWAV = _loop(3.0)
	var b: AudioStreamWAV = _loop(3.0)
	MusicDirector.test_streams = {"hd8_a": a, "hd8_b": b}
	var md := MusicDirector.new()
	world.add_child(md)
	await process_frame
	md.process_mode = Node.PROCESS_MODE_DISABLED
	md.play("hd8_a")
	var pa: AudioStreamPlayer = md.players[md.cur]
	_check(pa.stream == a and pa.playing and is_zero_approx(md.gains[md.cur]), "slot A starts at zero gain")
	for i: int in 6:
		md._process(0.1)
	_check(absf(md.gains[md.cur] - 0.5) < 0.02, "A is half way in after 0.6 s (%.2f)" % md.gains[md.cur])
	for i2: int in 7:
		md._process(0.1)
	_check(is_equal_approx(md.gains[md.cur], 1.0), "A fully in after %.1f s" % MusicDirector.CROSSFADE)
	md.play("hd8_a")
	_check(md.players[md.cur] == pa and pa.stream == a, "the same slot again is a no-op")
	md.play("hd8_b")
	var pb: AudioStreamPlayer = md.players[md.cur]
	var ia: int = md.players.find(pa)
	_check(pb != pa and pb.stream == b and pb.playing, "slot B takes the other player")
	for i3: int in 6:
		md._process(0.1)
	_check(absf(md.gains[md.cur] - 0.5) < 0.02 and absf(md.gains[ia] - 0.5) < 0.02, "half way: B 0.5 in, A 0.5 out")
	_check(absf(db_to_linear(pb.volume_db - MusicDirector.tension_db(md._tension_cur)) - md.gains[md.cur]) < 0.01, "player volume follows the crossfade gain")
	for i4: int in 7:
		md._process(0.1)
	_check(is_equal_approx(md.gains[md.cur], 1.0) and not pa.playing and pa.stream == null, "after the crossfade A is stopped and released")
	# a fading stop, then the same slot fades back in on the same player
	md.stop(true)
	md._process(0.3)
	_check(md.slot == "hd8_b" and md.gains[md.cur] < 1.0 and pb.playing, "stop fades B out")
	md.play("hd8_b")
	md._process(0.3)
	_check(pb.playing and pb.stream == b and md.target_gain == 1.0 and is_equal_approx(md.gains[md.cur], 1.0), "B fades back in without a restart")
	# a slot without a file: the current track fades out and nothing new plays
	md.play("hd8_no_such_file")
	for i5: int in 15:
		md._process(0.1)
	_check(not md.players[0].playing and not md.players[1].playing and md.slot == "hd8_no_such_file", "a missing file fades to silence")
	# tension reaches the live bus filter (tension slots only) and the volume
	MusicDirector.test_streams["stage1_race"] = a
	md.play("stage1_race", 0.0)
	md.set_tension(1.0)
	for i6: int in 60:
		md._process(0.1)
	var bus: int = AudioServer.get_bus_index(MusicDirector.BUS)
	var lp: AudioEffectLowPassFilter = null
	for e: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, e) is AudioEffectLowPassFilter:
			lp = AudioServer.get_bus_effect(bus, e)
	_check(lp != null and lp.cutoff_hz > 19000.0 and absf(md.players[md.cur].volume_db) < 0.2, "tension 1: low-pass open, full volume")
	md.set_tension(0.0)
	for i7: int in 80:
		md._process(0.1)
	_check(lp != null and lp.cutoff_hz < 5200.0 and md.players[md.cur].volume_db < -4.0, "tension 0: gentle low-pass and %.1f dB" % MusicDirector.TENSION_DB_MIN)
	md.play("hd8_b", 0.0)
	md._process(0.1)
	_check(lp != null and lp.cutoff_hz > 19000.0, "a non-tension slot at tension 0 plays with the low-pass open (%.0f Hz)" % (lp.cutoff_hz if lp else 0.0))
	# fixed trim: mission_canteen -6 dB (Dolly's hum stays audible)
	MusicDirector.test_streams["mission_canteen"] = b
	md.set_tension(1.0)
	for i8: int in 60:
		md._process(0.1)
	md.play("mission_canteen", 0.0)
	_check(absf(md.players[md.cur].volume_db - (-6.0)) < 0.2, "mission_canteen plays 6 dB down (%.1f dB)" % md.players[md.cur].volume_db)
	md.free()
	MusicDirector.test_streams = {}
	await _both_busy()
	await _duck_and_resume()
	await _warm_cache()
	_drum_onset()


## Review I1: a switch while both players are busy reuses the quieter one; the louder keeps fading; no blip.
func _both_busy() -> void:
	MusicDirector.test_streams = {"hd8_a": _loop(3.0), "hd8_b": _loop(3.0), "hd8_c": _loop(3.0)}
	var md := MusicDirector.new()
	world.add_child(md)
	await process_frame
	md.process_mode = Node.PROCESS_MODE_DISABLED
	md.play("hd8_a", 0.0)
	var pa: AudioStreamPlayer = md.players[md.cur]
	md.play("hd8_b")          # A (gain 1) starts fading out, B (gain 0) in
	var pb: AudioStreamPlayer = md.players[md.cur]
	md._process(0.05)         # the auto-mission case: a new slot 0.05 s later
	var ga: float = md.gains[md.players.find(pa)]
	md.play("hd8_c")
	var pc: AudioStreamPlayer = md.players[md.cur]
	_check(pc == pb and pc.stream == MusicDirector.test_streams["hd8_c"], "both busy: the quieter (just started) player takes the new slot")
	_check(pa.playing and absf(md.gains[md.players.find(pa)] - ga) < 1e-6 and md.goals[md.players.find(pa)] == 0.0,
		"the louder outgoing track keeps fading (gain %.2f), no hard cut" % ga)
	_check(pc.volume_db <= -79.0, "the reused player starts silent (%.1f dB), no blip at its old level" % pc.volume_db)
	for i: int in 14:
		md._process(0.1)
	_check(not pa.playing and is_equal_approx(md.gains[md.cur], 1.0), "after the crossfade only the new slot plays")
	md.free()
	MusicDirector.test_streams = {}


## Review I3 (director side) + Minor: duck keeps the players running; roam tracks resume where they stopped.
func _duck_and_resume() -> void:
	MusicDirector.clear_cache()
	MusicDirector.test_streams = {"roam_day": _loop(20.0), "hd8_b": _loop(3.0)}
	var md := MusicDirector.new()
	world.add_child(md)
	await process_frame
	md.process_mode = Node.PROCESS_MODE_DISABLED
	md.play("roam_day", 0.0)
	md.duck(true)
	md._process(0.15)
	_check(md.duck_gain > 0.0 and md.duck_gain < 1.0, "duck fades (%.2f after 0.15 s)" % md.duck_gain)
	md._process(0.2)
	_check(md.duck_gain == 0.0 and md.players[md.cur].playing and md.players[md.cur].volume_db < -60.0, "ducked: silent, still playing")
	md.duck(false)
	md._process(0.4)
	_check(md.duck_gain == 1.0 and md.players[md.cur].volume_db > -6.0, "released: back to its level")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await process_frame
	var p0: float = md.players[md.cur].get_playback_position()
	md.play("hd8_b", 0.0)     # a mission / cinematic takes over
	var saved: float = float(MusicDirector._resume.get("roam_day", 0.0))
	_check(saved > 0.3 and absf(saved - p0) < 0.2, "roam_day's position is remembered (%.2f s)" % saved)
	md.play("roam_day", 0.0)
	_check(md.players[md.cur].get_playback_position() >= saved - 0.05, "roam_day resumes at %.2f s instead of 0:00" % md.players[md.cur].get_playback_position())
	md.free()
	MusicDirector.test_streams = {}
	MusicDirector.clear_cache()


## Review I2: warm() loads on a worker thread; play() after warm does no main-thread load.
func _warm_cache() -> void:
	MusicDirector.clear_cache()
	var threads: Array = []
	var main_id: int = OS.get_thread_caller_id()
	MusicDirector.test_loader = func(s: String) -> AudioStream:
		threads.append([s, OS.get_thread_caller_id()])
		return _loop(2.0)
	var started: int = MusicDirector.warm(["hd8_w1", "hd8_w2"])
	_check(started == 2 and MusicDirector.warm(["hd8_w1"]) == 0, "warm starts one task per slot, once")
	var t0: int = Time.get_ticks_msec()
	while not (MusicDirector.is_warm("hd8_w1") and MusicDirector.is_warm("hd8_w2")) and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	_check(MusicDirector.is_warm("hd8_w1") and MusicDirector.is_warm("hd8_w2"), "both slots warmed")
	_check(threads.size() == 2 and threads.all(func(e: Array) -> bool: return int(e[1]) != main_id), "the loads ran off the main thread")
	var md := MusicDirector.new()
	world.add_child(md)
	await process_frame
	md.process_mode = Node.PROCESS_MODE_DISABLED
	var before: int = MusicDirector.main_thread_loads
	md.play("hd8_w1", 0.0)
	md.play("hd8_w2")
	_check(MusicDirector.main_thread_loads == before and threads.size() == 2, "play() after warm() loads nothing on the main thread")
	var st1: AudioStream = md.players[1 - md.cur].stream
	md.play("hd8_w1")
	_check(md.current_stream() == st1 and threads.size() == 2, "the cached stream is reused on the next play")
	md.play("hd8_cold")
	_check(MusicDirector.main_thread_loads == before + 1, "a slot that was never warmed is the only main-thread load")
	# a play() while the warm task still runs waits for it instead of reading the file again
	MusicDirector.warm(["hd8_pending"])
	md.play("hd8_pending")
	_check(MusicDirector.main_thread_loads == before + 1 and md.current_stream() != null, "a pending warm is adopted, not re-read")
	md.free()
	MusicDirector.test_loader = Callable()
	MusicDirector.clear_cache()


## Review I4: the Stage 4 drum hits from sample 0 (no late layer).
func _drum_onset() -> void:
	var fx: Node = root.get_node_or_null("GameFX")
	if fx == null:
		_check(false, "GameFX autoload present for the drum check")
		return
	var w: AudioStreamWAV = fx.call("_synth", "drum")
	var sr: int = w.mix_rate
	var n: int = w.data.size() / 2
	var peak_i: int = 0
	var peak: float = 0.0
	var early: float = 0.0
	for i: int in n:
		var v: float = absf(float(w.data.decode_s16(i * 2)) / 32767.0)
		if v > peak:
			peak = v
			peak_i = i
		if i < int(0.005 * sr):
			early = maxf(early, v)
	_check(early > 0.3, "the drum is loud within its first 5 ms (%.2f)" % early)
	_check(float(peak_i) / float(sr) < 0.02, "the drum peaks within 20 ms of the beat (%.3f s)" % (float(peak_i) / float(sr)))
	var late: float = 0.0
	for j: int in range(int(0.08 * sr), n):
		late = maxf(late, absf(float(w.data.decode_s16(j * 2)) / 32767.0))
	_check(late < peak * 0.5, "no layer starts late (after 80 ms: %.2f vs peak %.2f)" % [late, peak])


func _night_music() -> void:
	var tracks: Dictionary = {}
	for k: String in NightMusic.TRACKS.keys():
		tracks[NightMusic.TRACKS[k]] = _loop(4.0)
	MusicDirector.test_streams = tracks
	var lvl := FakeLevel.new()
	world.add_child(lvl)
	var nm := NightMusic.for_level(lvl)
	nm.manual = true
	world.add_child(nm)
	await process_frame
	_check(nm.state == "stealth" and nm.loaded.has("stealth") and not nm.loaded.has("chase"), "starts in stealth; only the stealth track is started")
	_run(nm, 2.1)
	_check(is_equal_approx(nm.gain("stealth"), 1.0), "stealth faded in")
	(lvl.stalkers[1] as FakeStalker).state = "SUSPICIOUS"
	_run(nm, 0.15)
	_check(nm.state == "tense", "a suspicious stalker -> tense")
	_run(nm, 0.6)
	_check(nm.gain("tense") > 0.3 and nm.gain("tense") < 0.7 and nm.gain("stealth") > 0.3 and nm.gain("stealth") < 0.7, "crossfade half way at 0.6 s")
	_run(nm, 0.8)
	_check(is_equal_approx(nm.gain("tense"), 1.0) and is_zero_approx(nm.gain("stealth")), "tense in, stealth out after the crossfade")
	var ps: AudioStreamPlayer = nm.players["stealth"]
	_check(ps.stream_paused, "the silent stealth track is paused, not stopped")
	var pos_s: float = ps.get_playback_position()
	(lvl.stalkers[1] as FakeStalker).state = "SEARCH"
	_run(nm, 0.2)
	_check(nm.state == "tense", "searching stays tense")
	(lvl.stalkers[0] as FakeStalker).state = "CHASE"
	_run(nm, 0.5)
	_check(nm.state == "chase" and nm.loaded.has("chase"), "a chasing stalker -> chase")
	_run(nm, 1.3)
	(lvl.stalkers[0] as FakeStalker).state = "CHECK"
	_run(nm, 0.2)
	_check(nm.state == "chase", "a stalker checking the spot counts as chase")
	lvl.kit.hidden = true
	_run(nm, 0.2)
	_check(nm.state == "hidden", "in a hiding spot -> hidden")
	_run(nm, 1.3)
	var all_quiet: bool = true
	for k2: String in NightMusic.TRACKS.keys():
		all_quiet = all_quiet and is_zero_approx(nm.gain(k2))
	_check(all_quiet, "hidden ducks every track to silence")
	lvl.kit.hidden = false
	(lvl.stalkers[0] as FakeStalker).state = "PATROL"
	(lvl.stalkers[1] as FakeStalker).state = "PATROL"
	_run(nm, 0.2)
	_check(nm.state == "stealth" and not ps.stream_paused and ps.playing, "back to stealth: the track resumes")
	_check(ps.get_playback_position() >= pos_s - 0.01 and ps.get_playback_position() < pos_s + 1.0,
		"stealth resumes where it left off (%.2f s, was %.2f s)" % [ps.get_playback_position(), pos_s])
	(lvl.stalkers[1] as FakeStalker).state = "SUSPICIOUS"
	_run(nm, 0.5)
	_check(nm.state == "stealth", "a new suspicion right after a switch waits out the %.0f s hold" % NightMusic.MIN_HOLD)
	_run(nm, 1.7)
	_check(nm.state == "tense", "then tense once the hold is over")
	lvl.doors_unlocked = true
	_run(nm, 0.2)
	_check(nm.state == "escape", "doors unlocked -> escape")
	(lvl.stalkers[0] as FakeStalker).state = "CHASE"
	_run(nm, 0.2)
	_check(nm.state == "escape", "escape outranks a chase")
	lvl.state = "caught"
	_run(nm, 0.2)
	_check(nm.state == "hidden", "a catch ducks the music")
	lvl.state = "escaped"
	_run(nm, 0.2)
	_check(nm.state == "escape", "escaped keeps the escape track")
	var log_ok: bool = nm.state_log.has("stealth") and nm.state_log.has("tense") and nm.state_log.has("chase") \
		and nm.state_log.has("hidden") and nm.state_log.has("escape")
	_check(log_ok, "every state was reached (%s)" % ", ".join(nm.state_log))
	nm.free()
	lvl.free()
	# the optional alarm flag (the horror polish may add it), read only when the level has it
	var al := FakeAlarmLevel.new()
	world.add_child(al)
	var nm2 := NightMusic.for_level(al)
	nm2.manual = true
	world.add_child(nm2)
	_run(nm2, 0.2)
	_check(nm2.state == "stealth", "alarm off -> stealth")
	al.alarm = true
	_run(nm2, 0.2)
	_check(nm2.state == "escape", "alarm on -> escape")
	for st2: FakeStalker in al.stalkers:
		st2.state = "CHASE"   # the horror polish: every hunter rushes (CHASE) after the alarm
	_run(nm2, 0.2)
	_check(nm2.state == "escape", "rushing hunters after the alarm keep the escape track")
	al.kit.hidden = true
	_run(nm2, 0.2)
	_check(nm2.state == "hidden", "hiding still ducks the music during the escape")
	nm2.free()
	al.free()
	# review I2: the four night tracks are warmed on worker threads when the node enters the scene
	MusicDirector.clear_cache()
	MusicDirector.test_loader = func(_s: String) -> AudioStream: return _loop(1.0)
	var nmw := NightMusic.new()
	nmw.manual = true
	world.add_child(nmw)
	var warmed: bool = true
	for ns: String in NightMusic.TRACKS.values():
		warmed = warmed and (MusicDirector.is_warm(ns) or MusicDirector._pending.has(ns))
	_check(warmed, "all four night tracks are warmed at scene load")
	nmw.free()
	MusicDirector.test_loader = Callable()
	MusicDirector.clear_cache()
	# no level (freed or never set): stealth, no error; without owner files every track is silent
	MusicDirector.test_streams = {}
	var nm3 := NightMusic.new()
	nm3.manual = true
	world.add_child(nm3)
	_run(nm3, 0.3)
	_check(nm3.state == "stealth", "no level -> stealth")
	if MusicDirector.slot_file("night_stealth") == "":
		_check((nm3.players["stealth"] as AudioStreamPlayer).stream == null and not (nm3.players["stealth"] as AudioStreamPlayer).playing,
			"no owner file -> the night track is silent")
	nm3.free()
	# the standalone level scene carries a NightMusic child bound to the level
	var scene: Node = (load("res://scenes/story/NightBuilding.tscn") as PackedScene).instantiate()
	var child: Node = scene.get_node_or_null("NightMusic")
	_check(child is NightMusic, "NightBuilding.tscn has a NightMusic child for the standalone run")
	scene.free()


func _run(nm: NightMusic, secs: float) -> void:
	var n: int = int(round(secs / 0.05))
	for i: int in n:
		nm.step(0.05)


func _end() -> void:
	if fails.is_empty():
		print("✅ SUCCESS: MUSIC SLOTS (catalogue, file or silence, no code music, crossfades, tension, roam day/night, NightMusic)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
