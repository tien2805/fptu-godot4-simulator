# File: res://tests/test_cine_transition.gd
# Headless test of the gameplay -> cinematic transition (plan 2026-10-26-cine-transition):
#   A. baked stages: every stage the game resolves (CineStage.requests) is in CineStageBake and matches a full
#      FreeRoam.cine_stage_search; cine_stage serves each from the table with no search (cine_search_tries == 0) after the
#      static check. On a mismatch the test prints the replacement CineStageBake.gd (CINE_BAKE_WRITE=1 writes it).
#      Headless sees multimesh clutter (kept instance transforms): the canteen point is cluttered by the campus grass.
#   B. fallback search: a stage off the table searches under CINE_SEARCH_BUDGET_MS and returns a transform; a budget
#      fallback is never cached (searched again), a full answer is (the repeat comes from the per-signature cache); the grid
#      clutter test equals the flat one on random boxes.
#   C. clone cache: a cloned CineActor equals a fresh build (nodes, meshes, transforms, metas remapped into its own body,
#      bone poses after the same cues); unseeded opts are never cloned; CinePlayer.setup clones the Day 4 sheep.
#   D. prepare ahead: FreeRoam.prepare_cinematic only loads the timeline and resolves the stage (no actor during live
#      play); play_cinematic takes the stage when slot, stage and opts "xf" match (both null, or the same xf).
#   E. fade, then the work under black: play_cinematic (not manual) pauses, prerolls (nothing built, the world still shown,
#      the black layer rising, the 2D card hidden from its first frame); under black one piece per frame: the hide / time of
#      day, then at most one actor per frame (clone cache), then the setup adopting them; the cinematic starts from black;
#      manual stays synchronous.
#   G. hard cuts: a timeline with scare hits or no fade_in cuts in at once (synchronous setup, no black layer).
#   F. dev path: F9 plays a timeline at its own (baked) stage and a hold-Esc skip restores the world.
# The table is baked in the vice art style (the palms exist only there): the test pins GameFX to vice (not saved) and puts
# the owner's style back at the end.
# Run:  godot --headless --path . --script tests/test_cine_transition.gd
# It only reads user:// (the owner's settings, the roam music FreeRoam loads), never writes it: no save or setting is
# touched; the players built here pass {"music": false} and the F9 slot gets a silent test stream.
extends SceneTree

var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var fr: Node = null
var story: StoryRoam = null
var cp: CinePlayer = null
var ended: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


var style0: String = ""


func _initialize() -> void:
	Engine.max_fps = 60
	print("== test_cine_transition")
	var gfx: Node = root.get_node_or_null("GameFX")
	if gfx:
		# the table is baked in the vice style (palms); not persisted. GameFX reads the owner's settings in its _ready, which
		# runs before FreeRoam's (autoloads come first in the tree)
		if gfx.is_inside_tree():
			style0 = String(gfx.get("art_style"))
			gfx.call("set_art_style", "vice", false)
		else:
			gfx.ready.connect(func() -> void:
				style0 = String(gfx.get("art_style"))
				gfx.call("set_art_style", "vice", false), CONNECT_ONE_SHOT)
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
	fr.call("cine_stage", st)
	_check(String((fr.get("cine_stage_info") as Dictionary).get("source", "")) == "search", "a budget fallback is never cached: the repeat searches again")
	# an easy off-table stage (found at ring 0 within the budget) is cached
	var easy: Dictionary = {"landmark": "be6_center", "near": 70.0, "size": Vector2(6.0, 6.0), "tod": "morning"}
	_check(CineStage.baked(easy).is_empty(), "the easy probe stage is not in the baked table")
	var xe: Variant = fr.call("cine_stage", easy)
	_check(xe is Transform3D and not bool((fr.get("cine_stage_info") as Dictionary).get("budget_hit", false)), "the easy stage is found within the budget")
	var xe2: Variant = fr.call("cine_stage", easy)
	_check(xe2 is Transform3D and xe is Transform3D and (xe2 as Transform3D).is_equal_approx(xe)
		and String((fr.get("cine_stage_info") as Dictionary).get("source", "")) == "cache" and int(fr.get("cine_search_tries")) == 0,
		"a full answer is served from the per-signature cache (same frame, no tries)")
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
# D. prepare ahead (cheap work only)
# ---------------------------------------------------------------------------
var d_step: int = 0
var d_body: CharacterBody3D = null
var d_wall: StaticBody3D = null


func _d_start() -> void:
	print("-- D. prepare ahead (timeline + stage only)")
	var tl: CineTimeline = CineTimeline.load_slot("cine_d4_stare")
	var t0: int = Time.get_ticks_usec()
	_check(bool(fr.call("prepare_cinematic", tl, {})), "prepare_cinematic accepts the timeline")
	var us: int = Time.get_ticks_usec() - t0
	var cpp: CinePrep = fr.get("cine_prep")
	_check(cpp != null and cpp.xf is Transform3D and String(cpp.info.get("source", "")) == "baked" and cpp.opts_xf == null,
		"the prep holds the timeline's baked stage frame")
	_check(us < 20000, "preparing is cheap: no actor is built during live play (%d us)" % us)
	var live: Array = fr.find_children("*", "CineActor", true, false).filter(func(n: Node) -> bool:
		return not n.is_queued_for_deletion() and not n.get_parent().is_queued_for_deletion() and not n.get_parent().get_parent().is_queued_for_deletion())
	_check(live.is_empty(), "no CineActor is built ahead (%d live)" % live.size())
	# xf must match: a prep made without opts "xf" is not used by a play with one, and the other way round
	var other := Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 2.0))
	_check(cpp != null and cpp.matches(tl, {}) and not cpp.matches(tl, {"xf": other}), "a prep without opts xf matches only plays without one")
	var px: CinePrep = CinePrep.new(tl, other, other, {})
	_check(px.matches(tl, {"xf": other}) and not px.matches(tl, {}) and not px.matches(tl, {"xf": Transform3D.IDENTITY}),
		"a prep with opts xf matches only plays with the same xf")
	# a knocked-out body and a set wall being freed lie in the baked canteen box: the static check must look through them
	var bk: Dictionary = CineStage.baked(CineTimeline.canteen_stage(Vector2(14.0, 10.0), "sunset"))
	var o: Vector3 = (bk["xf"] as Transform3D).origin
	d_body = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 0.6, 3.0)
	cs.shape = bs
	d_body.add_child(cs)
	fr.add_child(d_body)
	d_body.global_position = o + Vector3(0.0, 0.3, 0.0)
	d_wall = StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(3.0, 0.6, 3.0)
	cs2.shape = bs2
	d_wall.add_child(cs2)
	var holder := StoryMission.new()   # a mission's set
	fr.add_child(holder)
	holder.add_child(d_wall)
	d_wall.global_position = o + Vector3(3.5, 0.3, 0.0)


func _d_step() -> bool:
	if d_step == 0 and frames < 3:
		return false
	if d_step == 0 and d_body != null:
		var st: Dictionary = CineTimeline.canteen_stage(Vector2(14.0, 10.0), "sunset")
		var bk: Dictionary = CineStage.baked(st)
		var space: PhysicsDirectSpaceState3D = (fr as Node3D).get_world_3d().direct_space_state
		var steps_any: Array = fr.call("_cine_floor_steps", space, bk["xf"], Vector2(14.0, 10.0), true)
		_check(not steps_any.is_empty(), "the bodies really block the plain floor rays (the check below is not vacuous)")
		fr.call("cine_stage", st)
		_check(String((fr.get("cine_stage_info") as Dictionary).get("source", "")) == "baked",
			"a knocked-out body and a mission wall in the box do not reject the baked spot (map floor only)")
		d_body.queue_free()
		d_wall.get_parent().queue_free()
		d_body = null
		var tl2: CineTimeline = CineTimeline.load_slot("cine_d4_stare")   # a fresh load, as StoryRoam does at play time
		cp = fr.call("play_cinematic", tl2, {"manual": true, "music": false})
		_check(cp != null and fr.get("cine_prep") == null and bool((fr.get("cine_stage_info") as Dictionary).get("prepared", false)),
			"play_cinematic takes the prepared stage frame and drops the prep")
		if cp:
			cp.call("_finish", true)
		fr.call("prepare_cinematic", CineTimeline.load_slot("cine_d4_intro"), {})
		d_step = 1
		frames = 0
		return false
	if d_step == 1:
		if frames < 3:
			return false
		cp = fr.call("play_cinematic", CineTimeline.load_slot("cine_d4"), {"manual": true, "music": false})
		_check(cp != null and not bool((fr.get("cine_stage_info") as Dictionary).get("prepared", false)), "another slot resolves its own stage")
		if cp:
			cp.call("_finish", true)
		d_step = 2
		frames = 0
		return false
	if frames < 3:
		return false
	_check(fr.get("cine_player") == null and not paused, "the world is restored after the manual cinematics")
	phase = 2
	frames = 0
	return false


# ---------------------------------------------------------------------------
# E. fade, then the work under black one piece per frame
# ---------------------------------------------------------------------------
var e_rows: Array = []        # per frame: [prerolling, black alpha, actors built, set up]
var e_t0: int = 0
var e_card: StoryDayCard = null
var e_card_rows: Array = []   # [prerolling, card visible]; row 0 right after the card is added
var e_step: int = 0


func _e_step() -> bool:
	if e_step == 0:
		print("-- E. fade, then one piece of work per black frame")
		fr.call("prepare_cinematic", CineTimeline.load_slot("cine_d4_stare"), {})
		var player_node: Node3D = fr.get("player")
		e_t0 = Time.get_ticks_usec()
		ended.clear()
		fr.connect("cinematic_finished", func(slot: String, sk: bool) -> void: ended.append([slot, sk]), CONNECT_ONE_SHOT)
		cp = fr.call("play_cinematic", CineTimeline.load_slot("cine_d4_stare"), {"music": false})
		_check(cp != null and cp.prerolling and cp.stage == null and cp.pre_built == 0, "play_cinematic returns at once, prerolling, nothing built or set up")
		_check(paused and player_node.visible, "the game is frozen and the world still shown while the picture fades")
		if cp == null:
			return _end()
		e_card = StoryDayCard.new()
		e_card.player = cp
		root.add_child(e_card)
		e_card_rows.append([cp.prerolling, e_card.visible])   # row 0: before its first _process
		e_step = 1
		return false
	if e_step == 1:
		var pr: Variant = cp.get("_pre_rect")
		var a: float = (pr as ColorRect).color.a if pr is ColorRect else -1.0
		e_rows.append([cp.prerolling, snappedf(a, 0.01), cp.pre_built, cp.stage != null])
		e_card_rows.append([cp.prerolling, e_card.visible])
		if cp.stage != null:
			var n_act: int = cp.timeline.actors.size()
			var ms: float = float(Time.get_ticks_usec() - e_t0) / 1000.0
			var first_black: int = -1
			var first_build: int = -1
			var first_setup: int = -1
			var step_ok: bool = true
			for i: int in e_rows.size():
				if first_black < 0 and float(e_rows[i][1]) >= 1.0:
					first_black = i
				if first_build < 0 and int(e_rows[i][2]) > 0:
					first_build = i
				if first_setup < 0 and bool(e_rows[i][3]):
					first_setup = i
				if i > 0 and int(e_rows[i][2]) - int(e_rows[i - 1][2]) > 1:
					step_ok = false
			print("  preroll %.0f ms over %d frames: %s" % [ms, e_rows.size(), str(e_rows)])
			_check(first_black >= 0 and first_build > first_black + 1,
				"the actors are built only under black, after the hide / time-of-day frame (black %d, first build %d)" % [first_black, first_build])
			_check(step_ok and first_setup >= first_build + n_act - 1,
				"at most one actor per black frame, then the setup (%d actors, setup at frame %d)" % [n_act, first_setup])
			_check(cp.adopted == n_act and cp.clones >= 5, "setup adopted every actor built under black (%d of %d, %d cloned)" % [cp.adopted, n_act, cp.clones])
			_check(ms >= CinePlayer.FADE_S * 1000.0 - 1.0, "the fade lasts CinePlayer.FADE_S (%.0f ms)" % ms)
			var rising: bool = true
			for j: int in range(1, maxi(first_black, 1)):
				rising = rising and float(e_rows[j][1]) >= float(e_rows[j - 1][1])
			_check(rising, "the black layer rises monotonically")
			_check(not (fr.get("player") as Node3D).visible and fr.get_viewport().get_camera_3d() == cp.camera, "under black: world hidden, cinematic camera current")
			_check(cp.overlay != null and float(cp.overlay.get("_fade")) >= 0.99, "the cinematic itself starts from black")
			var hid: bool = true
			for row: Array in e_card_rows:
				if bool(row[0]) and bool(row[1]):
					hid = false
			_check(hid, "the 2D card never shows during the preroll, from its first frame (%s)" % str(e_card_rows.slice(0, 3)))
			e_step = 2
			frames = 0
		elif frames > 300:
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
	_g_hard_cuts()
	phase = 3
	frames = 0
	return false


# ---------------------------------------------------------------------------
# G. hard cuts: jump scares and fade_in 0 keep the immediate cut
# ---------------------------------------------------------------------------
func _g_hard_cuts() -> void:
	print("-- G. hard cuts (scares, no fade_in)")
	var sc: CineTimeline = CineTimeline.load_slot("cine_d0_midnight")
	_check(not sc.scare_hits.is_empty() and not CinePlayer.wants_preroll(sc, {}), "a timeline with scare hits is a hard cut")
	cp = fr.call("play_cinematic", sc, {"music": false})
	_check(cp != null and not cp.prerolling and cp.stage != null and cp.get("_pre_layer") == null,
		"the scare cinematic cuts in at once: synchronous setup, no black layer")
	if cp:
		cp.call("_finish", true)
	var nf: CineTimeline = CineTimeline.load_slot("cine_d4")
	nf.fade_in = 0.0
	_check(not CinePlayer.wants_preroll(nf, {}) and CinePlayer.wants_preroll(CineTimeline.load_slot("cine_d4"), {}),
		"fade_in 0 is a hard cut; the same slot with its fade_in prerolls")
	cp = fr.call("play_cinematic", nf, {"music": false})
	_check(cp != null and not cp.prerolling and cp.stage != null, "a fade_in 0 cinematic cuts in at once")
	if cp:
		cp.call("_finish", true)


# ---------------------------------------------------------------------------
# F. dev path
# ---------------------------------------------------------------------------
var f_step: int = 0


func _f_step() -> bool:
	if f_step == 0:
		print("-- F. dev path (F9) on a timeline's own stage")
		fr.set("_cine_slot_i", CineTimeline.slots().find("cine_d2") - 1)
		MusicDirector.test_streams["cine_d2"] = null   # silent: the F9 path never reads user://music
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
	MusicDirector.test_streams.erase("cine_d2")
	var gfx2: Node = root.get_node_or_null("GameFX")
	if gfx2 and style0 != "":
		gfx2.call("set_art_style", style0, false)
	print("  art style during the test: vice (owner style %s restored)" % style0)
	if story:
		story.free()
		story = null
	if fails.is_empty():
		print("✅ SUCCESS: CINE TRANSITION (baked stages, budgeted search + cache, clone cache, prepare ahead, fade then one piece per black frame, hard cuts, dev path)")
		quit(0)
	else:
		print("❌ FAIL: CINE TRANSITION (%d)" % fails.size())
		quit(1)
	return true
