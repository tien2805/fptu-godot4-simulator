# File: res://tests/test_cine_player.gd
# Headless test of CinePlayer with the 6 s test timeline. Part A, empty world: refuses an invalid timeline; plays exactly
# 6.000 s (360 manual steps of 1/60); music starts on the first frame; letterbox, fades, subtitle with its Dịch line, shots
# switch by story time; the clock ignores Engine.time_scale and is not clamped through a hitch; hold-Esc skip; debug
# overlay; frame cost; {"music": false}; no owner file = no music and ready at once (H-D8: no synthesized cue); cinematic_active
# cleared when a playing player leaves the tree.
# Part B, FreeRoam (crowd off): stage found on the road side of the west gate (floor near the landmark ground, no shed roof,
# no visual clutter in the box), play_cinematic pauses the tree, hides the player / HUD / map, stops the roam music and
# restores everything (camera, music, time of day) when done; the roam music follows the time of day (roam_day / roam_night,
# H-D8); F9 with no timelines is a no-op.
# Run:  godot --headless --path . --script tests/test_cine_player.gd
# CINE_NO_MIXAMO=1 sets CineRetarget.disabled = ["mixamo"] before any check (covers the fallback tiers with files present).
# The test never reads or writes user://music: its slot "test_slot" has no owner file, Part B passes {"music": false}; the
# "music starts on the first frame" check gives the player a test stream (a silent loop built here, not game music).
extends SceneTree

const TL_SCRIPT: String = "res://tests/support/cine_test_timeline.gd"
var fails: Array[String] = []
var phase: int = -1
var frames: int = 0
var world: Node3D
var fr: Node
var p: CinePlayer
var finished_args: Array = []
var real_t0: int = 0
var r0: float = 0.0
var hitch_done: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _tl() -> CineTimeline:
	var tl: CineTimeline = (load(TL_SCRIPT) as GDScript).new()
	tl.build()
	return tl


## A silent 16-bit stream of `secs` s (test only: it stands in for an owner file; not game music).
func _test_stream(secs: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var d := PackedByteArray()
	d.resize(int(secs * 22050.0) * 2)
	w.data = d
	return w


func _on_finished(skipped: bool) -> void:
	finished_args.append(skipped)


func _sm() -> Node:
	return root.get_node_or_null("StageManager")


func _initialize() -> void:
	print("--- TEST CINE PLAYER ---")
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		CineRetarget.disabled = PackedStringArray(["mixamo"])
		print("  CINE_NO_MIXAMO=1: mixamo source disabled")
	world = Node3D.new()
	root.add_child(world)
	# nodes added in _initialize enter the tree only after it returns (camera / actor global transforms need the tree)
	await process_frame
	var bad: CineTimeline = _tl()
	bad.story_end = 4.0
	var pb := CinePlayer.new()
	world.add_child(pb)
	_check(not pb.setup(bad).is_empty() and pb.actors.is_empty(), "invalid timeline refused, nothing built")
	pb.queue_free()
	# {"music": false}: no cue at all, ready at once
	var pm := CinePlayer.new()
	world.add_child(pm)
	_check(pm.setup(_tl(), Transform3D.IDENTITY, {"manual": true, "music": false}).is_empty() and pm.is_ready() and pm.music.stream == null,
		"{music: false} skips the cue and is ready at once")
	pm.start()
	pm.step(1.0 / 60.0)
	_check(not pm.music.playing and pm.r > 0.0, "{music: false} plays without music")
	var sm: Node = _sm()
	if sm:
		_check(bool(sm.get("cinematic_active")), "cinematic_active set while playing")
	var pm_end: Array = []
	pm.finished.connect(func(sk: bool) -> void: pm_end.append([sk, pm.leaving_tree]))
	world.remove_child(pm)
	if sm:
		_check(not bool(sm.get("cinematic_active")), "cinematic_active cleared when a playing player leaves the tree")
	_check(pm_end == [[true, true]], "a playing player leaving the tree emits finished(true) with leaving_tree (%s)" % str(pm_end))
	pm.free()
	# H-D8: music on but no owner file for "test_slot": no synthesized cue, no music, ready at once
	var pf := CinePlayer.new()
	world.add_child(pf)
	pf.setup(_tl(), Transform3D.IDENTITY, {"manual": true})
	_check(pf.is_ready() and pf.music.stream == null, "no owner file -> no music (no synthesized cue) and ready at once")
	pf.start()
	pf.step(1.0 / 60.0)
	_check(not pf.music.playing and pf.r > 0.0, "no owner file -> the cinematic plays on without music")
	pf.free()
	p = CinePlayer.new()
	world.add_child(p)
	_check(p.setup(_tl(), Transform3D.IDENTITY, {"manual": true}).is_empty(), "test timeline sets up")
	p.music.stream = _test_stream(8.0)   # stands in for an owner file
	p.music_len = 8.0
	p.finished.connect(_on_finished)
	p.start()
	phase = 0
	frames = 0


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		-1:
			return false
		0:   # is_ready() is true at once since H-D8 (nothing is built in the background)
			if p.is_ready():
				phase = 1
			elif frames > 600:
				_check(false, "music never became ready")
				return _end()
		1:
			var steps: int = 0
			var saw_sub: bool = false
			var saw_dich: bool = false
			while finished_args.is_empty() and steps < 400:
				p.step(1.0 / 60.0)
				steps += 1
				if steps == 1:
					_check(p.music.playing, "music starts on the first frame")
					_check(p.overlay.fade_alpha() > 0.9, "starts black")
				if steps == 12:
					_check(p.overlay.letterbox_fraction() > 0.3 and p.overlay.letterbox_fraction() < 0.7, "letterbox sliding in at 0.2 s")
				if steps == 30:
					_check(p.overlay.fade_alpha() < 0.05 and is_equal_approx(p.overlay.letterbox_fraction(), 1.0), "faded in, bars in place at 0.5 s")
				if steps == 60:
					_check(p.current_shot == "S1", "shot S1 at 1.0 s (got %s)" % p.current_shot)
				if steps == 120:
					_check(p.current_shot == "S2", "shot S2 at 2.0 s (got %s)" % p.current_shot)
					_check(absf(p.s - p.timeline.clock.story_at(2.0)) < 1e-4, "story time = clock.story_at(r)")
					_check(p.fx.get_child_count() > 0, "sparks fired on H1")
				if steps == 210:
					saw_sub = p.overlay.sub_visible()
					saw_dich = p.overlay.sub_text().contains("Dịch:")
				if steps == 300:
					_check(not p.overlay.sub_visible(), "subtitle hidden after its window")
				if steps == 345:
					_check(absf(p.overlay.fade_alpha() - 0.5) < 0.1, "fading out over the last 0.5 s")
			_check(saw_sub and saw_dich, "Anh Duy subtitle with its Dịch line at 3.5 s")
			_check(absi(steps - 360) <= 1, "plays exactly 6.000 s (%d steps of 1/60)" % steps)
			_check(finished_args == [false], "finished(false) once")
			_check(p.frame_ms_total / maxf(float(p.frames), 1.0) < 8.0, "frame update %.2f ms < 8" % (p.frame_ms_total / maxf(float(p.frames), 1.0)))
			print("  frame update %.3f ms average over %d frames" % [p.frame_ms_total / maxf(float(p.frames), 1.0), p.frames])
			p.queue_free()
			# real-time clock ignores Engine.time_scale
			Engine.time_scale = 0.5
			p = CinePlayer.new()
			world.add_child(p)
			p.setup(_tl())
			p.start()
			real_t0 = 0
			hitch_done = false
			phase = 2
		2:
			if real_t0 == 0:
				if p.is_ready() and p.r > 0.0:
					real_t0 = Time.get_ticks_msec()
					r0 = p.r
					frames = 0
			elif not hitch_done and Time.get_ticks_msec() - real_t0 >= 500:
				var real_s: float = float(Time.get_ticks_msec() - real_t0) / 1000.0
				_check(real_s > 0.2 and absf((p.r - r0) - real_s) < 0.1, "r follows real time with time_scale 0.5 (dr %.2f, real %.2f)" % [p.r - r0, real_s])
				# a 300 ms hitch inside one frame: the real clock is not clamped (plan review M5)
				r0 = p.r
				OS.delay_msec(300)
				hitch_done = true
				frames = 0
			elif hitch_done and frames >= 2:
				_check(p.r - r0 >= 0.29, "no dt clamp: a 300 ms hitch advances r by %.3f s" % (p.r - r0))
				Engine.time_scale = 1.0
				p.queue_free()
				# hold-Esc skip
				finished_args.clear()
				p = CinePlayer.new()
				world.add_child(p)
				p.setup(_tl(), Transform3D.IDENTITY, {"manual": true})
				p.finished.connect(_on_finished)
				p.start()
				phase = 3
		3:
			if p.is_ready():
				p.set_debug(true)
				p.step(1.0 / 60.0)
				_check(p.overlay.debug_text().contains("r=") and p.overlay.debug_text().contains("s="), "debug overlay shows r and s")
				p.force_skip_hold = true
				var n: int = 0
				while finished_args.is_empty() and n < 200:
					p.step(1.0 / 60.0)
					n += 1
				_check(finished_args == [true], "hold Esc skips (finished(true))")
				_check(n >= 60 and n <= 70, "skip after 0.8 s hold + 0.25 s fade (%d steps)" % n)
				p.queue_free()
				phase = 4
				frames = 0
		4:   # Part B: FreeRoam
			var ps: PackedScene = load("res://scenes/FreeRoam.tscn")
			fr = ps.instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			phase = 5
			frames = 0
		5:
			if frames < 3:
				return false
			return _part_b()
	return false


## Visual clutter seen independently of FreeRoam: every visible small MeshInstance3D / MultiMesh instance (horizontal AABB
## < 30 m, where the AABB is tight) whose AABB overlaps the stage box and pokes more than 0.15 m above the floor.
func _clutter(n: Node, inv: Transform3D, half: Vector2, floor_y: float, out: Array[String]) -> void:
	if n == fr.get("player") or n == fr.get("bike") or n == fr.get("cine_player"):
		return
	if n is MeshInstance3D or n is MultiMeshInstance3D:
		var g: GeometryInstance3D = n
		if g.is_visible_in_tree():
			var abs_list: Array[AABB] = []
			if n is MultiMeshInstance3D:
				var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
				if mm and mm.mesh:
					for i: int in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
						abs_list.append(g.global_transform * mm.get_instance_transform(i) * mm.mesh.get_aabb())
			else:
				abs_list.append(g.global_transform * g.get_aabb())
			for ab: AABB in abs_list:
				if ab.size.x > 30.0 or ab.size.z > 30.0:
					continue
				if ab.end.y <= floor_y + 0.15 or ab.position.y > floor_y + 2.5:
					continue
				var lo := Vector2(INF, INF)
				var hi := Vector2(-INF, -INF)
				for c: Vector3 in [ab.position, Vector3(ab.end.x, 0.0, ab.position.z), Vector3(ab.position.x, 0.0, ab.end.z), ab.end]:
					var l: Vector3 = inv * Vector3(c.x, floor_y, c.z)
					lo = Vector2(minf(lo.x, l.x), minf(lo.y, l.z))
					hi = Vector2(maxf(hi.x, l.x), maxf(hi.y, l.z))
				if hi.x > -half.x and lo.x < half.x and hi.y > -half.y and lo.y < half.y:
					out.append("%s (top %.2f)" % [str(g.get_path()).right(60), ab.end.y])
	for c2: Node in n.get_children():
		_clutter(c2, inv, half, floor_y, out)


func _part_b() -> bool:
	var tl: CineTimeline = _tl()
	var t_search: int = Time.get_ticks_msec()
	var xf: Variant = fr.call("cine_stage", tl.stage)
	t_search = Time.get_ticks_msec() - t_search
	_check(xf is Transform3D, "clear stage found near the west gate")
	if xf is Transform3D:
		var sx: Transform3D = xf
		var lm: Array = fr.get("md").landmark("campus_west_gate")
		var d: float = Vector2(sx.origin.x - float(lm[0]), sx.origin.z - float(lm[1])).length()
		_check(d < 40.0, "stage within 40 m of the landmark (%.1f m)" % d)
		var info: Dictionary = fr.get("cine_stage_info")
		print("  stage spot: %s (search %d ms)" % [str(info), t_search])
		var ground_y: float = float(info.get("ground_y", 0.0))
		_check(absf(ground_y) < 0.1, "landmark ground found at the street level (%.3f)" % ground_y)
		_check(absf(sx.origin.y - ground_y) <= 0.5, "stage floor %.3f within 0.5 m of the landmark ground (no shed roof)" % sx.origin.y)
		var space: PhysicsDirectSpaceState3D = (fr as Node3D).get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(sx.origin + Vector3(0.0, 2.0, 0.0), sx.origin - Vector3(0.0, 1.0, 0.0))
		var hit: Dictionary = space.intersect_ray(q)
		_check(not hit.is_empty() and absf((hit["position"] as Vector3).y - sx.origin.y) < 0.02, "floor under the stage origin is the stage floor")
		var q2 := PhysicsRayQueryParameters3D.create(sx.origin + Vector3(0.0, 30.0, 0.0), sx.origin + Vector3(0.0, 0.3, 0.0))
		_check(space.intersect_ray(q2).is_empty(), "nothing overhead at the stage origin (open sky)")
		# road-aligned: the stage -Z axis runs along the D1 frontage (campus +u)
		var road: Vector3 = FPTUCampusBuilder.real_plot_transform().basis * Vector3.RIGHT
		_check(absf((-sx.basis.z).normalized().dot(road)) > 0.99, "stage yaw runs along the road")
		var size: Vector2 = tl.stage["size"]
		var cl: Array[String] = []
		_clutter(fr, sx.affine_inverse(), size * 0.5, sx.origin.y, cl)
		_check(cl.is_empty(), "no visual clutter inside the stage box (%s)" % ", ".join(cl))
		var cl2: Array = fr.call("cine_clutter", sx, size)
		_check(cl2.is_empty(), "FreeRoam's clutter check agrees (%s)" % str(cl2))
		# the same box centred on the gate itself sees the barrier arm and a lamp post (both checks are not vacuous)
		var at_gate := Transform3D(sx.basis, Vector3(float(lm[0]), 0.0, float(lm[1])))
		var cg: Array[String] = []
		_clutter(fr, at_gate.affine_inverse(), size * 0.5, 0.0, cg)
		var cg2: Array = fr.call("cine_clutter", at_gate, size)
		_check(cg.size() >= 3 and cg2.size() >= 3, "a box on the gate itself is cluttered (test %d, FreeRoam %d meshes)" % [cg.size(), cg2.size()])
		# a 4 x 3 m box across the 0.28 m campus sidewalk edge (campus v -1..-5, 12 m along the frontage): the floor-ray grid
		# (~1 m) sees the step by itself, whether or not a vertex of the merged slab falls inside the box (Tasks 5+6 review)
		var at_walk := Transform3D(sx.basis, Vector3(float(lm[0]), 0.0, float(lm[1])) + sx.basis * Vector3(-3.0, 0.0, 12.0))
		var mesh_only: Array = fr.call("_cine_clutter_in", fr.call("_cine_clutter_items", at_walk.origin, 4.0), at_walk, Vector2(4.0, 3.0))
		var steps: Array = fr.call("_cine_floor_steps", space, at_walk, Vector2(4.0, 3.0), false)
		print("  sidewalk box: mesh clutter %s, floor steps %d" % [str(mesh_only), steps.size()])
		_check(not steps.is_empty() and not (fr.call("cine_clutter", at_walk, Vector2(4.0, 3.0)) as Array).is_empty(),
			"the floor-ray grid sees the sidewalk step inside a box (%d rays)" % steps.size())
	var tod0: String = fr.get("tod_preset")
	var cam0: Camera3D = (fr as Node3D).get_viewport().get_camera_3d()
	var we: WorldEnvironment = (fr as Node).get_node_or_null("WorldEnvironment") as WorldEnvironment
	var exp0: float = we.environment.tonemap_exposure if we and we.environment else 0.0
	var amb0: float = we.environment.ambient_light_energy if we and we.environment else 0.0
	var fx: Node = root.get_node_or_null("GameFX")
	var md_music: Node = fx.get("music") if fx else null
	finished_args.clear()
	var cp: CinePlayer = fr.call("play_cinematic", tl, {"manual": true, "music": false})
	_check(cp != null, "play_cinematic returns the player")
	if cp == null:
		return _end()
	cp.finished.connect(_on_finished)
	_check(paused, "tree paused during the cinematic")
	_check(not (fr.get("player") as Node3D).visible, "roam player hidden")
	_check(not (fr.get("map_overlay") as Control).visible and not (fr.get("hint_holder") as Control).visible, "map and hint hidden")
	_check((fr as Node3D).get_viewport().get_camera_3d() == cp.camera, "cinematic camera is current")
	var env_saved: Array = (fr.get("_cine_saved") as Dictionary).get("env", [])
	_check(we != null and env_saved.size() == 3 and is_equal_approx(we.environment.tonemap_exposure, float(env_saved[1]) * 1.5)
		and is_equal_approx(we.environment.ambient_light_energy, float(env_saved[2]) * 2.0),
		"stage exposure x1.5 / ambient x2 applied during the cinematic")
	var sm: Node = _sm()
	if sm:
		_check(bool(sm.get("cinematic_active")), "StageManager.cinematic_active while the cinematic plays")
		_check(not bool(sm.call("_can_pause")), "Esc cannot pause during the cinematic")
	if md_music:
		_check(float(md_music.get("target_gain")) == 0.0, "roam music stopped for the cinematic")
	while not cp.is_ready():
		OS.delay_msec(20)
	var n2: int = 0
	while finished_args.is_empty() and n2 < 400:
		cp.step(1.0 / 60.0)
		n2 += 1
	_check(finished_args == [false] and absi(n2 - 360) <= 1, "FreeRoam cinematic plays its 6 s (%d steps)" % n2)
	_check(not paused, "tree unpaused after the cinematic")
	_check((fr.get("player") as Node3D).visible, "roam player visible again")
	_check(fr.get("tod_preset") == tod0, "time of day restored")
	if we and we.environment:
		_check(is_equal_approx(we.environment.tonemap_exposure, exp0) and is_equal_approx(we.environment.ambient_light_energy, amb0),
			"exposure / ambient back to the pre-cinematic values (%.2f / %.2f)" % [we.environment.tonemap_exposure, we.environment.ambient_light_energy])
	_check(fr.get("cine_player") == null, "player slot cleared")
	_check((fr as Node3D).get_viewport().get_camera_3d() == cam0, "previous camera restored")
	if sm:
		_check(not bool(sm.get("cinematic_active")), "cinematic_active cleared after the cinematic")
	if md_music:
		_check(String(md_music.get("slot")) == MusicDirector.roam_slot(tod0) and float(md_music.get("target_gain")) == 1.0,
			"roam music resumed (%s for %s)" % [String(md_music.get("slot")), tod0])
		# H-D8: the roam slot follows the time of day while it plays (night -> roam_night, every other preset -> roam_day)
		fr.call("set_time_of_day", "night")
		_check(String(md_music.get("slot")) == "roam_night", "night -> roam_night (%s)" % String(md_music.get("slot")))
		fr.call("set_time_of_day", "sunset")
		_check(String(md_music.get("slot")) == "roam_day", "sunset -> roam_day (%s)" % String(md_music.get("slot")))
		fr.call("set_time_of_day", "night")
		md_music.call("play", "mission_chase")
		fr.call("set_time_of_day", "morning")
		_check(String(md_music.get("slot")) == "mission_chase", "a mission track is not replaced by a time-of-day change")
		fr.call("set_time_of_day", tod0)
		fr.call("roam_music")
	if CineTimeline.slots().is_empty():
		_check(fr.call("_play_next_cinematic") == null, "F9 with no timelines is a no-op")
	return _end()


func _end() -> bool:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: CINE PLAYER (exact length, overlay, shots, real clock, skip, FreeRoam hosting)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
