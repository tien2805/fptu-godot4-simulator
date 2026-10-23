# File: res://tests/test_cine_audio_fx.gd
# Headless test of CineAudio (slot loader, gain rule, synthesized cue/sting/SFX) and CineFX (particles follow the clock speed,
# analytic debris freezes with story time, crate break, stars, props, code textures, no GPU particles).
# Run:  godot --headless --path . --script tests/test_cine_audio_fx.gd
extends SceneTree

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _rms(w: AudioStreamWAV, t0: float, t1: float) -> float:
	var d: PackedByteArray = w.data
	var a: int = int(t0 * CineAudio.SR)
	var b: int = mini(int(t1 * CineAudio.SR), d.size() / 2)
	var acc: float = 0.0
	for i: int in range(a, b):
		var v: float = float(d.decode_s16(i * 2)) / 32767.0
		acc += v * v
	return sqrt(acc / maxf(float(b - a), 1.0))


func _initialize() -> void:
	print("--- TEST CINE AUDIO + FX ---")
	# --- gain rule (A1-D13)
	_check(is_equal_approx(CineAudio.music_gain(24.0, 25.0, 30.0), 1.0), "longer file: full volume before the last 0.5 s")
	_check(absf(CineAudio.music_gain(24.75, 25.0, 30.0) - 0.5) < 1e-6, "longer file: half way through the fade at 24.75")
	_check(CineAudio.music_gain(25.0, 25.0, 30.0) == 0.0, "longer file: silent at the end")
	_check(is_equal_approx(CineAudio.music_gain(24.9, 25.0, 20.0), 1.0), "shorter file: no fade")
	_check(CineAudio.music_file("a1_no_such_slot") == "" and CineAudio.load_music("a1_no_such_slot") == null, "missing slot file -> synthesized cue")
	# --- owner track (local only, never committed): when user://music/seg_d1_brawl.mp3 exists the slot resolves to it and it
	# plays; when it does not, the slot falls back to the synthesized cue. The test never writes to user://music.
	var owner_mp3: String = CineAudio.MUSIC_DIR + "seg_d1_brawl.mp3"
	if FileAccess.file_exists(owner_mp3) and not FileAccess.file_exists(CineAudio.MUSIC_DIR + "seg_d1_brawl.ogg"):
		var own: AudioStream = CineAudio.load_music("seg_d1_brawl")
		var own_len: float = CineAudio.stream_length(own)
		_check(CineAudio.music_file("seg_d1_brawl") == owner_mp3, "owner slot resolves to %s" % owner_mp3)
		_check(own is AudioStreamMP3 and own_len > 1.0, "owner mp3 loads (%.2f s)" % own_len)
		# _initialize runs before the root is in the tree, so decode through the stream's own playback instead of a player node
		var pb: AudioStreamPlayback = own.instantiate_playback() if own else null
		var loud: float = 0.0
		if pb:
			pb.start(5.0)
			var frames: PackedVector2Array = pb.mix_audio(1.0, 4410)
			for fr: Vector2 in frames:
				loud = maxf(loud, maxf(absf(fr.x), absf(fr.y)))
			pb.stop()
		_check(pb != null and loud > 0.01, "owner mp3 decodes and plays (peak %.3f at 5 s)" % loud)
		print("  owner track found: %s (%.2f s)" % [owner_mp3, own_len])
	elif not FileAccess.file_exists(CineAudio.MUSIC_DIR + "seg_d1_brawl.ogg"):
		_check(CineAudio.music_file("seg_d1_brawl") == "" and CineAudio.load_music("seg_d1_brawl") == null,
			"no owner track -> seg_d1_brawl uses the synthesized cue")
		print("  no owner track in %s: synthesized cue path" % CineAudio.MUSIC_DIR)
	# --- synthesized cue: exact length, accents on the hits, silent end
	var hits: Array[Dictionary] = [
		{"r": 2.681, "preset": "heavy", "freeze": 0.18, "r_start": 2.231, "r_end": 3.961},
		{"r": 7.975, "preset": "medium", "freeze": 0.14, "r_start": 7.655, "r_end": 8.835},
		{"r": 19.950, "preset": "finisher", "freeze": 0.2, "r_start": 19.300, "r_end": 21.500}]
	var t0: int = Time.get_ticks_msec()
	var cue: AudioStreamWAV = CineAudio.synth_cue(25.0, hits, "punchy")
	var ms: int = Time.get_ticks_msec() - t0
	print("  25 s cue synthesized in %d ms" % ms)
	_check(cue != null and cue.mix_rate == CineAudio.SR and cue.format == AudioStreamWAV.FORMAT_16_BITS, "cue is 22.05 kHz 16-bit")
	_check(absi(cue.data.size() - 25 * CineAudio.SR * 2) <= 4, "cue is exactly 25.000 s (%d bytes)" % cue.data.size())
	_check(ms < 3000, "cue synthesized in %d ms < 3000" % ms)
	for h: Dictionary in hits:
		var at: float = float(h["r"])
		var peak: float = _rms(cue, at, at + 0.06)
		var before: float = _rms(cue, at - 1.45, at - 0.45)   # 1 s of grid before the riser
		_check(peak > 2.0 * before + 0.01, "accent at %.3f (rms %.3f vs %.3f before)" % [at, peak, before])
	_check(_rms(cue, 24.99, 25.0) < 0.02, "cue faded out at the end")
	# pure + thread-safe: the same cue built on a WorkerThreadPool task (holder box, as CinePlayer does) is byte-identical
	var box: Array = [null]
	var task: int = WorkerThreadPool.add_task(func() -> void: box[0] = CineAudio.synth_cue(25.0, hits, "punchy"))
	WorkerThreadPool.wait_for_task_completion(task)
	var wcue: AudioStreamWAV = box[0]
	_check(wcue != null and wcue.data == cue.data, "worker-thread cue is identical to the main-thread cue")
	var sting: AudioStreamWAV = CineAudio.synth_sting(5.0, 2.75)
	_check(absi(sting.data.size() - 5 * CineAudio.SR * 2) <= 4, "sting is exactly 5.000 s")
	for c: String in CineAudio.SFX_CUES:
		var st: AudioStream = CineAudio.sfx(c)
		var ln: float = CineAudio.stream_length(st)
		_check(st != null and ln > 0.04 and ln < 2.5, "sfx %s synthesized (%.2f s)" % [c, ln])
	# --- FX follow the clock
	var world := Node3D.new()
	root.add_child(world)
	var fx := CineFX.new()
	world.add_child(fx)
	fx.burst("sparks", Vector3(0.0, 1.2, 0.0), Vector3(1.0, 0.3, 0.0), 1.0, 2.0)
	fx.burst("dust", Vector3.ZERO, Vector3.UP, 1.0, 2.0)
	fx.burst("flash", Vector3(0.0, 1.2, 0.0), Vector3.UP, 1.0, 2.0)
	fx.burst("debris", Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.5, 0.0), 1.0, 2.0)
	_check(fx.live_count() >= 4, "bursts spawned (%d live)" % fx.live_count())
	fx.update(2.05, 0.0)
	var parts: Array[Node] = fx.find_children("*", "CPUParticles3D", true, false)
	_check(parts.size() >= 2, "sparks and dust are CPUParticles3D")
	var frozen: bool = true
	for p: Node in parts:
		frozen = frozen and is_equal_approx((p as CPUParticles3D).speed_scale, 0.0)
	_check(frozen, "particles stop while the clock is frozen")
	fx.update(2.1, 0.5)
	_check(is_equal_approx((parts[0] as CPUParticles3D).speed_scale, 0.5), "particles run at the clock speed")
	var chunks: Array[Node] = fx.find_children("Debris*", "Node3D", true, false)
	_check(not chunks.is_empty(), "debris chunks exist")
	if not chunks.is_empty():
		var ch: Node3D = chunks[0] as Node3D
		fx.update(2.2, 1.0)
		var p1: Vector3 = ch.position
		fx.update(2.2, 0.0)
		_check(ch.position.is_equal_approx(p1), "debris position is a function of story time")
		fx.update(6.0, 1.0)
		_check(ch.position.y > -0.01 and ch.position.y < 0.2, "debris rests on the ground (y %.3f)" % ch.position.y)
	_check(fx.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
	# --- crate break, stars, props, texture
	var crates: Node3D = CineFX.build_prop("crate_stack")
	world.add_child(crates)
	var intact: Array = crates.get_meta("crates", [])
	_check(intact.size() >= 3, "crate stack has >= 3 crates")
	var before_n: int = fx.live_count()
	fx.crate_break(crates, Vector3(-1.0, 0.2, -1.0), 1.0, 8.4)
	var hidden: bool = true
	for c2: Node3D in intact:
		hidden = hidden and not c2.visible
	_check(hidden, "crate break hides the intact crates")
	_check(fx.live_count() >= before_n + 8, "crate break launches >= 8 planks")
	var dummy := Node3D.new()
	world.add_child(dummy)
	fx.stars(dummy, 9.0, 12.0)
	fx.update(10.0, 1.0)
	var star_nodes: Array[Node] = fx.find_children("Star*", "Node3D", true, false)
	_check(star_nodes.size() >= 3 and (star_nodes[0] as Node3D).visible, "three stars orbit during their window")
	fx.update(12.5, 1.0)
	_check(not (star_nodes[0] as Node3D).visible, "stars gone after their window")
	for k: String in ["crate_stack", "scooter", "banana", "phone"]:
		var n: Node3D = CineFX.build_prop(k)
		_check(n != null and not n.find_children("*", "MeshInstance3D", true, false).is_empty(), "prop %s built from code" % k)
		if k == "phone":
			CineFX.set_prop_glow(n, true)
			var scr: StandardMaterial3D = n.get_meta("screen_mat")
			_check(scr.emission_enabled, "phone screen glows")
		n.free()
	var tex: ImageTexture = CineFX.radial_texture(64, 2.0)
	var img: Image = tex.get_image()
	_check(img.get_pixel(32, 32).a > 0.9 and img.get_pixel(1, 1).a < 0.05, "radial texture is code-made (bright centre, clear edge)")
	if fails.is_empty():
		print("✅ SUCCESS: CINE AUDIO + FX (slots, gain, synth cue/sting/sfx, clock-driven FX, props)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
