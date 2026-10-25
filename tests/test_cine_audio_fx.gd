# File: res://tests/test_cine_audio_fx.gd
# Headless test of CineAudio (slot loader, gain rule, no synthesized music since H-D8, synthesized SFX) and CineFX (particles follow the clock speed,
# analytic debris freezes with story time and rests flat at half its height, fixed particle seeds, a burst inside a freeze
# starts frozen, crate break, stars, props, code textures, no GPU particles).
# Run:  godot --headless --path . --script tests/test_cine_audio_fx.gd
extends SceneTree

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST CINE AUDIO + FX ---")
	# --- gain rule (A1-D13)
	_check(is_equal_approx(CineAudio.music_gain(24.0, 25.0, 30.0), 1.0), "longer file: full volume before the last 0.5 s")
	_check(absf(CineAudio.music_gain(24.75, 25.0, 30.0) - 0.5) < 1e-6, "longer file: half way through the fade at 24.75")
	_check(CineAudio.music_gain(25.0, 25.0, 30.0) == 0.0, "longer file: silent at the end")
	_check(is_equal_approx(CineAudio.music_gain(24.9, 25.0, 20.0), 1.0), "shorter file: no fade")
	_check(CineAudio.music_file("a1_no_such_slot") == "" and CineAudio.load_music("a1_no_such_slot") == null, "missing slot file -> no music")
	# --- owner track (local only, never committed): when user://music/seg_d1_brawl.mp3 exists the slot resolves to it and it
	# plays; when it does not, the slot is silent (H-D8: no code music). The test never writes to user://music.
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
			"no owner track -> seg_d1_brawl has no music")
		print("  no owner track in %s: silent path" % CineAudio.MUSIC_DIR)
	# --- H-D8: no synthesized music path is left in CineAudio (the synthesized SFX below stay)
	var ca := CineAudio.new()
	_check(ca.has_method("music_file") and ca.has_method("sfx"), "has_method sees CineAudio's static functions (the checks below are not vacuous)")
	for m: String in ["synth_cue", "synth_sting", "_in_windows"]:
		_check(not ca.has_method(m), "CineAudio has no %s (no code music)" % m)
	_check(not ("MOODS" in (CineAudio as Script).get_script_constant_map()), "CineAudio has no music MOODS table")
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
	var seeded: bool = true
	for p2: Node in parts:
		var cp: CPUParticles3D = p2 as CPUParticles3D
		seeded = seeded and cp.use_fixed_seed and cp.seed == (hash(cp.position) & 0xFFFFFFFF)
	_check(seeded, "particle emitters use a fixed seed from their position (repeatable runs)")
	# a burst fired inside a freeze is frozen from its first frame (Tasks 3+4 review Minor 2)
	fx.update(2.15, 0.0)
	fx.burst("sparks", Vector3(0.5, 1.0, 0.0), Vector3.UP, 1.0, 2.15)
	var newest: CPUParticles3D = fx.get_child(fx.get_child_count() - 1) as CPUParticles3D
	_check(newest != null and is_equal_approx(newest.speed_scale, 0.0), "burst inside a freeze starts frozen (%s)" % (str(newest.speed_scale) if newest else "none"))
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
		var half_y: float = ((ch as MeshInstance3D).mesh as BoxMesh).size.y * 0.5
		_check(absf(ch.position.y - half_y) < 1e-4, "debris chunk rests on its half height %.3f (y %.4f)" % [half_y, ch.position.y])
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
	fx.update(40.0, 1.0)
	var planks_flat: int = 0
	var planks_n: int = 0
	for ch2: Node in fx.find_children("Debris*", "MeshInstance3D", true, false):
		var bm2: BoxMesh = (ch2 as MeshInstance3D).mesh as BoxMesh
		if bm2 and bm2.size.is_equal_approx(Vector3(0.55, 0.02, 0.07)):
			planks_n += 1
			if absf((ch2 as Node3D).position.y - 0.01) < 1e-4:
				planks_flat += 1
	_check(planks_n >= 8 and planks_flat == planks_n, "planks are 0.55 x 0.02 x 0.07 and rest flat at y 0.01 (%d / %d)" % [planks_flat, planks_n])
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
		print("✅ SUCCESS: CINE AUDIO + FX (slots, gain, no code music, synth sfx, clock-driven FX, props)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
