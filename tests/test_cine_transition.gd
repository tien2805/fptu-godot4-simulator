# File: res://tests/test_cine_transition.gd
# Headless test of the gameplay -> cinematic transition (plan 2026-10-26-cine-transition):
#   A. baked stages: every stage the game resolves (CineStage.requests) is in CineStageBake and matches a full
#      FreeRoam.cine_stage_search; cine_stage serves each from the table with no search (cine_search_tries == 0) after the
#      static check. On a mismatch the test prints the replacement CineStageBake.gd (CINE_BAKE_WRITE=1 writes it).
#      Headless sees multimesh clutter (kept instance transforms): the canteen point is cluttered by the campus grass.
#   B. fallback search: a stage off the table searches under CINE_SEARCH_BUDGET_MS, returns a transform, and the repeat is
#      served from the per-signature cache; the grid clutter test equals the flat one on random boxes.
#   C. clone cache: a cloned CineActor equals a fresh build (nodes, meshes, transforms, metas remapped into its own body,
#      bone poses after the same cues); unseeded opts are never cloned; CinePlayer.setup clones the Day 4 sheep.
#   D. prepare ahead: FreeRoam.prepare_cinematic builds one actor per frame (none while paused), play_cinematic adopts the
#      prepared actors (same nodes) and stage; a different slot is not adopted.
#   E. fade then setup: play_cinematic (not manual) pauses, prerolls (nothing set up, the world still shown, black layer
#      rising, the 2D card hidden), sets up only after a full black frame, then the cinematic starts from black; manual
#      stays synchronous.
#   F. dev path: F9 plays a timeline at its own (baked) stage and a hold-Esc skip restores the world.
# Run:  godot --headless --path . --script tests/test_cine_transition.gd
# Every player built here passes {"music": false}: the test never depends on user://music; nothing touches user:// saves.
extends SceneTree

var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var fr: Node = null
var story: StoryRoam = null
var cp: CinePlayer = null
var ended: Array = []
var prep_built: Array[int] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("== test_cine_transition")
	var ps: PackedScene = load("res://scenes/FreeRoam.tscn")
	fr = ps.instantiate()
	fr.set("crowd_enabled", false)
	root.add_child(fr)


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			if frames < 3:
				return false
			if not _part_a():
				return _end()
			_part_b()
			_part_c()
			_d_start()
			phase = 1
			frames = 0
		1:
			return _d_step()
		2:
			return _e_step()
		3:
			return _f_step()
		_:
			return _end()
	return false


# ---------------------------------------------------------------------------
# A. baked stages
# ---------------------------------------------------------------------------
func _story() -> StoryRoam:
	if story == null:
		story = StoryRoam.new()
		story.roam = fr as Node3D
		story._compute_anchors()
	return story


## false when the table is stale (the rest of the test would only repeat the same failure).
func _part_a() -> bool:
	print("-- A. baked stages")
	var rqs: Array = CineStage.requests(_story())
	_check(rqs.size() >= 20, "every timeline, story anchor and mission spot listed (%d stages)" % rqs.size())
	var lines: Array[String] = []
	var bad: Array[String] = []
	var t_all: int = Time.get_ticks_msec()
	for rq: Dictionary in rqs:
		var st: Dictionary = rq["stage"]
		var sig: String = CineStage.signature(st)
		var t0: int = Time.get_ticks_msec()
		var xf: Variant = fr.call("cine_stage_search", st, 0.0)
		var info: Dictionary = (fr.get("cine_stage_info") as Dictionary).duplicate()
		var tries: int = int(fr.get("cine_search_tries"))
		var ms: int = Time.get_ticks_msec() - t0
		var bk: Dictionary = CineStage.baked(st)
		var line: String = CineStage.entry_text(sig, xf, info) if xf is Transform3D else "\t\"%s\": []," % sig
		lines.append(line + "   # " + String(rq["label"]))
		var same: bool = false
		if xf is Transform3D and not bk.is_empty() and not bk.has("none"):
			var b: Transform3D = bk["xf"]
			var x: Transform3D = xf
			same = b.origin.distance_to(x.origin) < 0.005 and absf(wrapf(b.basis.get_euler().y - x.basis.get_euler().y, -PI, PI)) < 1e-4 \
				and String((bk["info"] as Dictionary)["landmark"]) == String(info.get("landmark", ""))
		elif xf == null and bk.has("none"):
			same = true
		if not same:
			bad.append("%s (%s): searched %s, baked %s" % [rq["label"], sig, str(info), str(bk.get("info", "missing"))])
		print("  %-34s %5d tries %5d ms  %s %s" % [String(rq["label"]).left(34), tries, ms, String(info.get("landmark", "none")), str(info.get("ring", "-"))])
	print("  full searches: %d ms" % (Time.get_ticks_msec() - t_all))
	_check(bad.is_empty(), "the baked table matches a full search for every stage (%d stale):\n    %s" % [bad.size(), "\n    ".join(bad)])
	if not bad.is_empty():
		var txt: String = _bake_file(lines)
		print("---- replacement res://scripts/cine/CineStageBake.gd ----\n%s---- end ----" % txt)
		if OS.get_environment("CINE_BAKE_WRITE") == "1":
			var f: FileAccess = FileAccess.open("res://scripts/cine/CineStageBake.gd", FileAccess.WRITE)
			if f:
				f.store_string(txt)
				f.close()
				print("  CineStageBake.gd written (CINE_BAKE_WRITE=1): re-import, then re-run")
		return false
	# every request is served from the table, no search, and the static check passes
	var searched: Array[String] = []
	var worst_us: int = 0
	for rq2: Dictionary in rqs:
		var t1: int = Time.get_ticks_usec()
		var xf2: Variant = fr.call("cine_stage", rq2["stage"])
		var us: int = Time.get_ticks_usec() - t1
		worst_us = maxi(worst_us, us)
		var inf2: Dictionary = fr.get("cine_stage_info")
		if String(inf2.get("source", "")) != "baked" or int(fr.get("cine_search_tries")) != 0:
			searched.append("%s (%s, %d tries)" % [rq2["label"], String(inf2.get("source", "")), int(fr.get("cine_search_tries"))])
		elif xf2 is Transform3D and us > 20000:
			searched.append("%s took %d us" % [rq2["label"], us])
	print("  baked lookups: worst %d us" % worst_us)
	_check(searched.is_empty(), "every stage resolves from the baked table with no search, under 20 ms (%s)" % ", ".join(searched))
	# headless sees the multimesh clutter the windowed game sees: the campus grass fills the canteen point
	var st_c: Dictionary = CineTimeline.canteen_stage(Vector2(14.0, 10.0), "sunset")
	var at: Vector2 = st_c["at"]
	var xc := Transform3D(Basis(Vector3.UP, deg_to_rad(271.0)), Vector3(at.x, 0.0, at.y))
	var cl: Array = fr.call("cine_clutter", xc, Vector2(14.0, 10.0))
	_check(cl.size() > 50, "headless sees the campus grass multimesh in the canteen box (%d items)" % cl.size())
	return true


func _bake_file(lines: Array[String]) -> String:
	var head: String = "# File: res://scripts/cine/CineStageBake.gd\n" \
		+ "# GENERATED by tests/test_cine_transition.gd (CineStage): do not edit by hand. When the map changes, the test fails and\n" \
		+ "# prints the replacement for this file (or writes it with CINE_BAKE_WRITE=1).\n" \
		+ "# signature -> [x, y, z, yaw (rad), landmark, ring, road_aligned, ground_y, centre x, centre z]; [] = no clear spot\n" \
		+ "class_name CineStageBake\nextends RefCounted\n\nconst TABLE: Dictionary = {\n"
	return head + "\n".join(lines) + "\n}\n"


# ---------------------------------------------------------------------------
# B. fallback search
# ---------------------------------------------------------------------------
func _part_b() -> void:
	print("-- B. budgeted search + cache")
	# a canteen-like stage that is not baked (13 x 9.5): the full search would take hundreds of tries
	var st: Dictionary = {"landmark": "campus_parking_center", "at": Vector2(-31.17, -4.51), "near": 24.0, "size": Vector2(13.0, 9.5), "yaw_deg": 271.0}
	_check(CineStage.baked(st).is_empty(), "the probe stage is not in the baked table")
	var t0: int = Time.get_ticks_msec()
	var xf: Variant = fr.call("cine_stage", st)
	var ms: int = Time.get_ticks_msec() - t0
	var info: Dictionary = (fr.get("cine_stage_info") as Dictionary).duplicate()
	var tries: int = int(fr.get("cine_search_tries"))
	print("  off-table stage: %d ms, %d tries, %s" % [ms, tries, str(info)])
	_check(xf is Transform3D and String(info.get("source", "")) == "search", "an off-table stage is searched and still gets a frame")
	_check(bool(info.get("budget_hit", false)) and tries >= 1 and tries < 400, "the search stopped at its %.0f ms budget (%d tries)" % [float((fr.get_script() as GDScript).get_script_constant_map()["CINE_SEARCH_BUDGET_MS"]), tries])
	_check(ms < 250, "a budgeted search returns quickly headless (%d ms, the clutter walk included)" % ms)
	var xf2: Variant = fr.call("cine_stage", st)
	_check(xf2 is Transform3D and xf is Transform3D and (xf2 as Transform3D).is_equal_approx(xf) and String((fr.get("cine_stage_info") as Dictionary).get("source", "")) == "cache"
		and int(fr.get("cine_search_tries")) == 0, "the repeat is served from the per-signature cache (same frame, no tries)")
	# the grid gives the flat list's answer for any box (exact equivalence on random boxes around the canteen)
	var c := Vector3(-31.17, 0.0, -4.51)
	var items: Array = fr.call("_cine_clutter_items", c, 34.0)
	var grid: Dictionary = fr.call("_cine_grid", items)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2610
	var diff: int = 0
	var hits: int = 0
	var sizes: Array[Vector2] = [Vector2(14.0, 10.0), Vector2(4.0, 3.0), Vector2(5.0, 44.0), Vector2(10.0, 9.0)]
	for i: int in 400:
		var sz: Vector2 = sizes[i % sizes.size()]
		var bx := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), c + Vector3(rng.randf_range(-24.0, 24.0), 0.0, rng.randf_range(-24.0, 24.0)))
		var a: bool = bool(fr.call("_cine_grid_hit", grid, bx, sz))
		var b: bool = not (fr.call("_cine_clutter_in", items, bx, sz) as Array).is_empty()
		if a != b:
			diff += 1
		if b:
			hits += 1
	_check(diff == 0 and hits > 20 and hits < 400, "grid clutter test == flat test on 400 random boxes (%d differ, %d cluttered)" % [diff, hits])


# ---------------------------------------------------------------------------
# C. clone cache
# ---------------------------------------------------------------------------
func _part_c() -> void:
	print("-- C. clone cache")
	var holder := Node3D.new()
	holder.name = "CloneTest"
	fr.add_child(holder)
	var o: Dictionary = StoryCast.opts("clone")
	_check(CineActor.clone_key(o) != "" and CineActor.clone_key({"preset": "student"}) == "", "seeded opts have a clone key, unseeded ones none")
	var a1 := CineActor.new()
	holder.add_child(a1)
	a1.setup(o)
	var t0: int = Time.get_ticks_usec()
	var a2 := CineActor.new()
	holder.add_child(a2)
	a2.setup(o, a1)
	var us_clone: int = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var a3 := CineActor.new()
	holder.add_child(a3)
	a3.setup(o)
	var us_fresh: int = Time.get_ticks_usec() - t0
	print("  clone %d us, fresh build %d us" % [us_clone, us_fresh])
	_check(a2.cloned and not a1.cloned and not a3.cloned, "the second actor is cloned, the others built")
	# windowed a build costs 50-75 ms in mesh uploads (headless almost nothing): a clone shares the template's meshes
	var shared: int = 0
	var meshes: int = 0
	var t_mi: Array[Node] = []
	_flat(a1.body, t_mi)
	var c_mi: Array[Node] = []
	_flat(a2.body, c_mi)
	for i0: int in mini(t_mi.size(), c_mi.size()):
		if t_mi[i0] is MeshInstance3D and (t_mi[i0] as MeshInstance3D).mesh != null:
			meshes += 1
			if (c_mi[i0] as MeshInstance3D).mesh == (t_mi[i0] as MeshInstance3D).mesh:
				shared += 1
	_check(meshes > 5 and shared == meshes, "the clone shares the template's meshes (%d of %d): no new mesh uploads" % [shared, meshes])
	# same tree as a fresh build
	var na: Array[Node] = []
	var nb: Array[Node] = []
	_flat(a2.body, na)
	_flat(a3.body, nb)
	var tree_diff: Array[String] = []
	if na.size() != nb.size():
		tree_diff.append("%d vs %d nodes" % [na.size(), nb.size()])
	else:
		for i: int in na.size():
			var x: Node = na[i]
			var y: Node = nb[i]
			if x.get_class() != y.get_class() or (not String(y.name).begins_with("@") and x.name != y.name):
				tree_diff.append("%s/%s vs %s/%s" % [x.get_class(), x.name, y.get_class(), y.name])
			elif x is Node3D and not (x is BoneAttachment3D) and not (x as Node3D).transform.is_equal_approx((y as Node3D).transform):
				tree_diff.append("transform of %s" % x.name)
			elif x is MeshInstance3D and ((x as MeshInstance3D).mesh == null) != ((y as MeshInstance3D).mesh == null):
				tree_diff.append("mesh of %s" % x.name)
			elif x is MeshInstance3D and (x as MeshInstance3D).mesh != null \
					and not (x as MeshInstance3D).mesh.get_aabb().is_equal_approx((y as MeshInstance3D).mesh.get_aabb()):
				tree_diff.append("mesh aabb of %s" % x.name)
			if tree_diff.size() > 5:
				break
	_check(tree_diff.is_empty(), "the clone's body equals a fresh build (%d nodes: classes, transforms (bone attachments follow the bones, compared below), meshes): %s" % [na.size(), ", ".join(tree_diff)])
	# node references in metas point into the clone's own body
	var stray: Array[String] = []
	for n: Node in na:
		for k: StringName in n.get_meta_list():
			_meta_refs(n.get_meta(k), a2.body, "%s.%s" % [n.name, k], stray)
	_check(stray.is_empty() and (a2.body.get_meta("skeleton") as Node) == a2.sk and a2.sk != a1.sk and a2.body.is_ancestor_of(a2.sk),
		"the clone's metas reference its own nodes (%s)" % ", ".join(stray))
	_check(a2.face_mat != null and a2.face_mat != a1.face_mat and a2.face_mat != a3.face_mat, "the clone has its own face material")
	# the same cues give the same pose
	for a: CineActor in [a2, a3]:
		a.key(0.0, Vector3.ZERO, 0.0)
		a.move(0.0, "eat_sit", {"dur": 1.6})
		a.move(1.0, "stare_sit", {"fade": 0.12})
		a.evaluate(0.7)
		a.evaluate(1.05)
	var pose_d: float = 0.0
	for bone: String in ["Head", "Wrist.R", "Wrist.L", "Foot.L", "Hips"]:
		pose_d = maxf(pose_d, a2.bone_world(bone).distance_to(a3.bone_world(bone)))
	_check(pose_d < 1e-4, "the clone and a fresh build pose identically after the same cues (%.6f m)" % pose_d)
	# unseeded opts never clone
	var b1 := CineActor.new()
	holder.add_child(b1)
	b1.setup({"preset": "student"}, a1)
	_check(not b1.cloned, "unseeded opts are built, never cloned")
	holder.queue_free()
	# CinePlayer.setup clones the Day 4 sheep (six identical seeded clones)
	var tl: CineTimeline = CineTimeline.load_slot("cine_d4_stare")
	var p := CinePlayer.new()
	fr.add_child(p)
	t0 = Time.get_ticks_usec()
	p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	print("  cine_d4_stare setup: %d ms, %d clones" % [(Time.get_ticks_usec() - t0) / 1000, p.clones])
	_check(p.clones >= 5 and p.actors.size() == tl.actors.size(), "CinePlayer.setup clones the seeded Day 4 sheep (%d clones of %d actors)" % [p.clones, p.actors.size()])
	p.queue_free()


func _flat(n: Node, out: Array[Node]) -> void:
	out.append(n)
	for ch: Node in n.get_children():
		_flat(ch, out)


func _meta_refs(v: Variant, own: Node, where: String, out: Array[String]) -> void:
	if v is Node:
		if v != own and not own.is_ancestor_of(v):
			out.append(where)
	elif v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			_meta_refs(v[k], own, "%s[%s]" % [where, str(k)], out)
	elif v is Array:
		for x: Variant in (v as Array):
			_meta_refs(x, own, where + "[]", out)


# ---------------------------------------------------------------------------
# D. prepare ahead
# ---------------------------------------------------------------------------
var d_step: int = 0
var d_paused_at: int = -1


func _d_start() -> void:
	print("-- D. prepare ahead")
	var tl: CineTimeline = CineTimeline.load_slot("cine_d4_stare")
	_check(bool(fr.call("prepare_cinematic", tl, {})), "prepare_cinematic accepts the timeline")
	var cpp: CinePrep = fr.get("cine_prep")
	_check(cpp != null and cpp.built == 0 and cpp.xf is Transform3D and String(cpp.info.get("source", "")) == "baked",
		"the prep resolves its stage at once (baked) and has built nothing yet")
	_check(cpp != null and not cpp.visible, "prepared actors stay hidden")
	prep_built.clear()


func _d_step() -> bool:
	var cpp: CinePrep = fr.get("cine_prep")
	if d_step == 0:
		if cpp == null:
			_check(false, "the prep vanished")
			return _end()
		prep_built.append(cpp.built)
		if prep_built.size() == 3:
			paused = true   # a paused tree (cinematic, call, video) builds nothing
			d_paused_at = cpp.built
		elif prep_built.size() == 6:
			_check(cpp.built == d_paused_at, "nothing is built while the tree is paused (%d -> %d)" % [d_paused_at, cpp.built])
			paused = false
		if cpp.done() or frames > 120:
			print("  built per frame: %s" % str(prep_built))
			var grows: bool = true
			for i: int in range(1, prep_built.size()):
				grows = grows and prep_built[i] - prep_built[i - 1] <= 1
			_check(grows and cpp.done(), "at most one actor per frame, until done (%s)" % str(prep_built))
			var ids: Dictionary = {}
			for id: String in cpp.actors.keys():
				ids[id] = (cpp.actors[id] as Node).get_instance_id()
			var tl2: CineTimeline = CineTimeline.load_slot("cine_d4_stare")   # a fresh load, as StoryRoam does at play time
			cp = fr.call("play_cinematic", tl2, {"manual": true, "music": false})
			_check(cp != null and cp.adopted == tl2.actors.size() and fr.get("cine_prep") == null,
				"play_cinematic adopts every prepared actor (%d of %d) and drops the prep" % [cp.adopted if cp else -1, tl2.actors.size()])
			var same: bool = cp != null
			if cp:
				for id2: String in ids.keys():
					same = same and cp.actors.has(id2) and (cp.actors[id2] as Node).get_instance_id() == int(ids[id2]) \
						and (cp.actors[id2] as Node).get_parent() == cp.stage
			_check(same, "the cinematic plays the very nodes that were prepared, under its stage")
			_check(bool((fr.get("cine_stage_info") as Dictionary).get("prepared", false)), "the stage frame came from the prep")
			if cp:
				cp.step(0.5)
				cp.call("_finish", true)
			d_step = 1
			frames = 0
		return false
	if d_step == 1:
		if frames < 3:
			return false
		_check(fr.get("cine_player") == null and not paused, "the world is restored after the prepared cinematic")
		# a prep for another slot is not adopted, and stays
		fr.call("prepare_cinematic", CineTimeline.load_slot("cine_d4_intro"), {})
		cp = fr.call("play_cinematic", CineTimeline.load_slot("cine_d4"), {"manual": true, "music": false})
		var keep: CinePrep = fr.get("cine_prep")
		_check(cp != null and cp.adopted == 0 and keep != null and keep.slot == "cine_d4_intro", "another slot builds its own actors; the prep is kept")
		if cp:
			cp.call("_finish", true)
		fr.call("drop_cinematic_prep")
		d_step = 2
		frames = 0
		return false
	if frames < 3:
		return false
	_check(fr.get("cine_prep") == null, "drop_cinematic_prep clears the prep")
	phase = 2
	frames = 0
	return false


# ---------------------------------------------------------------------------
# E. fade then setup
# ---------------------------------------------------------------------------
var e_rows: Array = []        # per frame: [prerolling, black alpha, set up]
var e_t0: int = 0
var e_card: StoryDayCard = null
var e_card_rows: Array = []   # per frame: [prerolling, card visible]
var e_step: int = 0


func _e_step() -> bool:
	if e_step == 0:
		print("-- E. fade then setup (prepared first: the faded play adopts the prep)")
		fr.call("prepare_cinematic", CineTimeline.load_slot("cine_d4_stare"), {})
		e_step = 5
		return false
	if e_step == 5:
		var pp: CinePrep = fr.get("cine_prep")
		if pp != null and not pp.done() and frames < 200:
			return false
		var tl: CineTimeline = CineTimeline.load_slot("cine_d4_stare")
		var player_node: Node3D = fr.get("player")
		e_t0 = Time.get_ticks_usec()
		ended.clear()
		fr.connect("cinematic_finished", func(slot: String, sk: bool) -> void: ended.append([slot, sk]), CONNECT_ONE_SHOT)
		cp = fr.call("play_cinematic", tl, {"music": false})
		_check(cp != null and cp.prerolling and cp.stage == null and cp.timeline == tl, "play_cinematic returns at once, prerolling, nothing set up")
		_check(paused and player_node.visible, "the game is frozen and the world still shown while the picture fades")
		if cp == null:
			return _end()
		e_card = StoryDayCard.new()
		e_card.player = cp
		root.add_child(e_card)
		e_step = 1
		return false
	if e_step == 1:
		var pr: Variant = cp.get("_pre_rect")
		var a: float = (pr as ColorRect).color.a if pr is ColorRect else -1.0
		e_rows.append([cp.prerolling, snappedf(a, 0.01), cp.stage != null])
		e_card_rows.append([cp.prerolling, e_card.visible])
		if cp.stage != null:
			var ms: float = float(Time.get_ticks_usec() - e_t0) / 1000.0
			var first_black: int = -1
			var first_setup: int = -1
			for i: int in e_rows.size():
				if first_black < 0 and float(e_rows[i][1]) >= 1.0:
					first_black = i
				if first_setup < 0 and bool(e_rows[i][2]):
					first_setup = i
			print("  preroll %.0f ms over %d frames: %s" % [ms, e_rows.size(), str(e_rows)])
			_check(first_black >= 0 and first_setup > first_black, "setup ran only after a fully black frame (black at %d, setup at %d)" % [first_black, first_setup])
			_check(ms >= CinePlayer.FADE_S * 1000.0 - 1.0, "the fade lasts CinePlayer.FADE_S (%.0f ms)" % ms)
			var rising: bool = true
			for j: int in range(1, maxi(first_black, 1)):
				rising = rising and float(e_rows[j][1]) >= float(e_rows[j - 1][1])
			_check(rising, "the black layer rises monotonically")
			_check(not (fr.get("player") as Node3D).visible and fr.get_viewport().get_camera_3d() == cp.camera, "under black: world hidden, cinematic camera current")
			_check(cp.overlay != null and float(cp.overlay.get("_fade")) >= 0.99, "the cinematic itself starts from black")
			_check(cp.adopted == cp.timeline.actors.size(), "the faded play adopted every prepared actor after the fade (%d of %d)" % [cp.adopted, cp.timeline.actors.size()])
			var hid: bool = true
			for k: int in range(1, e_card_rows.size()):
				if bool(e_card_rows[k][0]) and bool(e_card_rows[k][1]):
					hid = false
			_check(hid, "the 2D card stays hidden during the preroll (%s)" % str(e_card_rows))
			e_step = 2
			frames = 0
		elif frames > 200:
			_check(false, "the preroll never set up")
			return _end()
		return false
	if e_step == 2:
		if frames == 3:
			_check(e_card.visible, "the card shows once the cinematic runs")
			e_card.queue_free()
			cp.force_skip_hold = true
		if not ended.is_empty():
			_check(ended[0] == ["cine_d4_stare", true], "the faded cinematic skips and finishes: %s" % str(ended))
			_check(not paused and (fr.get("player") as Node3D).visible, "world restored after the faded cinematic")
			# manual stays synchronous
			cp = fr.call("play_cinematic", CineTimeline.load_slot("cine_d1_intro"), {"manual": true, "music": false})
			_check(cp != null and not cp.prerolling and cp.stage != null, "manual play_cinematic sets up at once (no fade)")
			if cp:
				cp.call("_finish", true)
			e_step = 3
			frames = 0
		elif frames > 2000:
			_check(false, "the faded cinematic never finished")
			return _end()
		return false
	if frames < 3:
		return false
	phase = 3
	frames = 0
	return false


# ---------------------------------------------------------------------------
# F. dev path
# ---------------------------------------------------------------------------
var f_step: int = 0


func _f_step() -> bool:
	if f_step == 0:
		print("-- F. dev path (F9) on a timeline's own stage")
		fr.set("_cine_slot_i", CineTimeline.slots().find("cine_d2") - 1)
		ended.clear()
		fr.connect("cinematic_finished", func(slot: String, sk: bool) -> void: ended.append([slot, sk]), CONNECT_ONE_SHOT)
		cp = fr.call("_play_next_cinematic")
		_check(cp != null and cp.timeline.slot == "cine_d2", "F9 plays cine_d2")
		_check(String((fr.get("cine_stage_info") as Dictionary).get("source", "")) == "baked", "its own stage comes from the baked table")
		if cp == null:
			return _end()
		cp.force_skip_hold = true
		f_step = 1
		frames = 0
		return false
	if not ended.is_empty():
		_check(ended[0] == ["cine_d2", true], "the dev cinematic skips: %s" % str(ended))
		_check(not paused and (fr.get("player") as Node3D).visible, "world restored after the dev cinematic")
		return _end()
	if frames > 2000:
		_check(false, "the dev cinematic never finished")
		return _end()
	return false


func _end() -> bool:
	if story:
		story.free()
		story = null
	if fails.is_empty():
		print("✅ SUCCESS: CINE TRANSITION (baked stages, budgeted search + cache, clone cache, prepare ahead, fade then setup, dev path)")
		quit(0)
	else:
		print("❌ FAIL: CINE TRANSITION (%d)" % fails.size())
		quit(1)
	return true
