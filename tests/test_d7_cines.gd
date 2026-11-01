# File: res://tests/test_d7_cines.gd
# Headless test of the Day 7 cinematics (plan 2026-11-01-w4-day7.md T4): cine_d7_intro, cine_d7_monologue, seg_d7_phase2 and
# seg_d7_finisher.
#   A. every slot: registered, validates, exact length (real duration within 0.5 ms), music slot = slot, beat sheet in sync, a
#      joke beat, plain Vietnamese lines (no emoji / decorative symbol, "..." not the ellipsis glyph, no gendered pronoun for the
#      protagonist, >= 0.06 s per character, no overlap), known sfx cues, its XEM LẠI PHIM row (Day 7), its music_to_download
#      row, MusicDirector knows the slot; the beats play them (d7_parking intro, d7_monologue, the "after" keys of d7_boss2 /
#      d7_boss3), LairTower stages them on the right floor;
#   B. framing in a CinePlayer (manual, drop_set, empty world): every helper shot (two_shot / ots / low_hero / dutch /
#      push_in) frames its subjects' head, chest and hips in the letterboxed safe area at its start, middle and end with no
#      other actor in front of a face (CameraFraming.report, as tests/test_story_framing.gd); every other shot shows an actor
#      inside the letterboxed frame at its middle;
#   C. the finisher, on every tier (mixamo when its files exist, ual, native, code): the staff on the stub at H1 (and not in
#      Lọ's body, the stub's point at the protagonist), Lọ's hook a near miss at A1, the knee on his torso at H2, the legs round
#      his neck at H5 (the neck between them, no leg sunk in), the two bodies never sink into each other (deeper only on the
#      hits) and no foot goes under the deck, no hips pop, Lọ flat on his back on the helipad and the protagonist standing
#      clear at the end; the props: the stub leaves his hand seamlessly and comes to rest on the deck clear of both, the staff
#      likewise, the held staff clears its holder's body, the helicopter hovers then leaves (>= 10 m), its rotor spins and
#      stays on it, the searchlight is aimed at the duel, the rain falls on the cinematic clock;
#   D. a standalone LairTower: cine_xf for the staged slots, hide_for_cine hides exactly the pieces each slot brings itself
#      (seg_d7_phase2: the two plinths at (+-3, 0); seg_d7_finisher: the helicopter, its searchlight, the rain) and restores
#      them (visibility and emitting), the monologue hides nothing.
# Run:  godot --headless --path . --script tests/test_d7_cines.gd   (CINE_FAST=1: no per-frame body sweep; CINE_NO_MIXAMO=1)
extends SceneTree

const Bodies = preload("res://tests/support/cine_bodies.gd")
const FIN = preload("res://scripts/cine/timelines/seg_d7_finisher.gd")

const SLOTS: Dictionary = {"cine_d7_intro": 13.0, "cine_d7_monologue": 13.0, "seg_d7_phase2": 25.0, "seg_d7_finisher": 25.0}
## Slots that must use the Q1 shot helpers (the Phase C fight template has its own camera plan).
const NEED_HELPERS: Array[String] = ["cine_d7_intro", "cine_d7_monologue", "seg_d7_finisher"]
const HELPERS: Array[String] = ["two_shot", "ots", "low_hero", "dutch", "push_in"]
const BANNED: Array[String] = ["anh ấy", "cô ấy", "cậu ấy", "chàng", "nàng", " hắn", "anh ta", "cô ta"]
## Punctuation allowed above U+2000 (owner rule: no emoji or decorative symbols; "..." is written as three dots).
const ALLOWED_SYMBOLS: Array[int] = [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D]
const BLOCK_R: float = 0.18
const GAP_MIXAMO: float = 0.04
const GAP_OTHER: float = 0.15
const PEN_MAX: float = 0.03
const PEN_HIT_LIMB: float = 0.06
const PEN_HIT_CORE: float = 0.04
const PEN_WINDOW: float = 0.08
const FOOT_FLOOR: float = -0.03
const POP_MAX: float = 0.25          # m per 1/60 s frame (15 m/s): no hips teleport
var fails: Array[String] = []
var world: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("== test_d7_cines")
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		CineRetarget.disabled = PackedStringArray(["mixamo"])
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	await process_frame
	CharacterBuilder.ps2 = true
	var part: String = OS.get_environment("D7_PART")   # "fin": only the finisher (C), for tuning
	if part != "fin":
		_static()
		var n_shots: int = 0
		for s: String in SLOTS.keys():
			var tl: CineTimeline = CineTimeline.load_slot(s)
			if tl:
				n_shots += int(await _frame_slot(tl))
		print("  shots framed: %d" % n_shots)
	var fin: CineTimeline = CineTimeline.load_slot("seg_d7_finisher")
	_fin_static(fin)
	var caps: Array[int] = [1, 2, 3]
	if CineRetarget.available("mixamo"):
		caps.push_front(0)
	else:
		print("  SKIP mixamo tier (no Mixamo files or CINE_NO_MIXAMO=1)")
	for cap: int in caps:
		await _fin_tier(fin, cap)
	await _fin_props(fin)
	if part != "fin":
		await _tower()
	CineMoves.max_tier = 0
	world.queue_free()
	await process_frame
	if fails.is_empty():
		print("SUCCESS test_d7_cines")
		quit(0)
	else:
		print("FAILED test_d7_cines: %d" % fails.size())
		quit(1)


# ---------------------------------------------------------------------------
# A. slots, lines, wiring
# ---------------------------------------------------------------------------
func _plain(t: String) -> bool:
	for i: int in t.length():
		var c: int = t.unicode_at(i)
		if c >= 0x2000 and not (c in ALLOWED_SYMBOLS):
			return false
	return true


func _static() -> void:
	var reg: PackedStringArray = CineTimeline.slots()
	var doc: String = FileAccess.get_file_as_string("res://docs/cinematics/music_to_download.md")
	var music: PackedStringArray = MusicDirector.all_slots()
	for s: String in SLOTS.keys():
		_check(reg.has(s), "%s is registered" % s)
		var tl: CineTimeline = CineTimeline.load_slot(s)
		_check(tl != null, "%s loads" % s)
		if tl == null:
			continue
		var errs: PackedStringArray = tl.validate()
		_check(errs.is_empty(), "%s validates: %s" % [s, "; ".join(errs)])
		var want: float = float(SLOTS[s])
		_check(is_equal_approx(tl.length, want) and absf(tl.clock.real_duration() - want) < 0.0005,
			"%s lasts exactly %.3f s (%.5f)" % [s, want, tl.clock.real_duration()])
		_check(tl.music_slot == s and tl.stage.has("landmark") and tl.stage.has("tod"), "%s: music slot = slot, landmark fallback, tod" % s)
		var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/%s.txt" % s).replace("\r\n", "\n")
		_check(committed == tl.beat_sheet(), "docs/cinematics/%s.txt is in sync (run tools/cine_beats.gd)" % s)
		_check(not tl.jokes.is_empty(), "%s has a joke beat" % s)
		if s in NEED_HELPERS:
			_check(tl.shots.any(func(sh: Dictionary) -> bool: return String(sh["rig"]) in HELPERS), "%s uses the shot helpers" % s)
		_check(tl.actors.has("hero") and tl.actors["hero"]["opts"] == StoryCast.opts("hero"), "%s: the hero is the protagonist" % s)
		for sb: Dictionary in tl.subs:
			var text: String = String(sb["text"])
			var chars: int = text.length() + String(sb["tr"]).length()
			_check(float(sb["dur"]) >= 0.06 * chars - 1e-6, "%s: '%s' reads at >= 0.06 s per character (%.2f s for %d)" % [s, text, float(sb["dur"]), chars])
			_check(float(sb["r"]) + float(sb["dur"]) <= tl.length + 1e-6, "%s: '%s' ends inside the scene" % [s, text])
			_check(_plain(text + String(sb["tr"])), "%s: no emoji / decorative symbol / ellipsis glyph in '%s'" % [s, text])
			_check(not text.contains("{name}"), "%s: {name} formatted in '%s'" % [s, text])
			for w: String in BANNED:
				_check(not text.to_lower().contains(w), "%s: no gendered pronoun '%s' in '%s'" % [s, w, text])
			_check(tl.actors.has(String(sb["speaker"])), "%s: '%s' is said by one of the cast (%s)" % [s, text, String(sb["speaker"])])
		for i: int in range(1, tl.subs.size()):
			var a: Dictionary = tl.subs[i - 1]
			_check(float(tl.subs[i]["r"]) >= float(a["r"]) + float(a["dur"]) - 1e-6, "%s: '%s' does not overlap the line before" % [s, String(tl.subs[i]["text"])])
		for e: Dictionary in tl.sfx:
			_check(CineAudio.SFX_CUES.has(String(e["cue"])) or StoryAudio.is_cue(String(e["cue"])), "%s: sfx cue %s exists" % [s, String(e["cue"])])
		var row: Array = StoryChapters.GALLERY.filter(func(g: Array) -> bool: return String(g[0]) == s)
		_check(row.size() == 1 and int(row[0][1]) == 7 and String(row[0][2]) != "" and _plain(String(row[0][2])),
			"%s has its Day 7 XEM LẠI PHIM row (%s)" % [s, str(row)])
		_check(doc.contains("`%s_`" % s), "%s has its row in docs/cinematics/music_to_download.md" % s)
		_check(music.has(s), "MusicDirector knows the %s slot" % s)
		var src: String = FileAccess.get_file_as_string("res://scripts/cine/timelines/%s.gd" % s)
		for gone: String in ["Thầy Toàn", "ToanHLM", "…"]:
			_check(not src.contains(gone), "%s never writes %s" % [s, gone])
	_check(String(StoryMissions.beat("d7_parking").get("intro", "")) == "cine_d7_intro", "d7_parking opens with cine_d7_intro")
	_check(String(StoryMissions.beat("d7_monologue").get("slot", "")) == "cine_d7_monologue", "d7_monologue plays cine_d7_monologue")
	_check(String(StoryMissions.beat("d7_boss2").get("after", "")) == "seg_d7_phase2", "d7_boss2 is followed by seg_d7_phase2")
	_check(String(StoryMissions.beat("d7_boss3").get("after", "")) == "seg_d7_finisher", "d7_boss3 is followed by seg_d7_finisher")
	_check(String(StoryMissions.beat("d7_typing").get("next", "")) == "d7_ending", "d7_typing hands over to d7_ending")
	_check(LairTower.SLOT_FLOOR.get("cine_d7_monologue", "") == "gallery" and LairTower.SLOT_FLOOR.get("seg_d7_phase2", "") == "gallery"
		and LairTower.SLOT_FLOOR.get("seg_d7_finisher", "") == "roof", "LairTower stages the monologue and phase 2 in the gallery, the finisher on the roof")
	_check("mission_tower" in MusicDirector.SLOTS and "boss_d7" in MusicDirector.SLOTS and doc.contains("`mission_tower_`")
		and doc.contains("`boss_d7_`") and doc.contains("The Final Countdown"), "music slots mission_tower and boss_d7 (The Final Countdown) with their rows")
	for rs: String in ["seg_d7_floors", "seg_d7_phase1"]:
		_check(rs in MusicDirector.REPLAY_SLOTS and doc.contains("`%s_`" % rs), "replay slot %s with its row" % rs)


# ---------------------------------------------------------------------------
# B. framing
# ---------------------------------------------------------------------------
func _frame_slot(tl: CineTimeline) -> int:
	CineMoves.max_tier = 1
	var p := CinePlayer.new()
	world.add_child(p)
	var errs: PackedStringArray = p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false, "drop_set": true})
	_check(errs.is_empty(), "%s sets up: %s" % [tl.slot, str(errs)])
	if not errs.is_empty():
		p.queue_free()
		return 0
	p.start()
	await process_frame
	var vs: Vector2 = root.get_visible_rect().size
	var lb: float = (p.overlay.bar_height_full() / vs.y) if tl.letterbox else 0.0
	var n: int = 0
	for i: int in tl.shots.size():
		var sh: Dictionary = tl.shots[i]
		var rig: String = String(sh["rig"])
		var r0: float = p._shot_r[i]
		var r1: float = p._shot_r[i + 1] if i + 1 < tl.shots.size() else tl.length
		var pr: Dictionary = sh["params"]
		n += 1
		if not (rig in HELPERS):
			p.seek((r0 + r1) * 0.5)
			var seen: String = ""
			for id: String in p.actors.keys():
				var a0: CineActor = p.actors[id]
				if not a0.is_visible_in_tree():
					continue
				for q: Vector3 in CameraFraming.subject_points(a0):
					if seen == "" and CameraFraming.in_safe(p.camera, q, 0.0, lb):
						seen = id
			_check(seen != "", "%s %s (%s) @%.2f: an actor is in the frame" % [tl.slot, String(sh["id"]), rig, (r0 + r1) * 0.5])
			continue
		var subj: Array[String] = []
		match rig:
			"two_shot":
				subj = [String(pr["a"]), String(pr["b"])]
			"ots":
				subj = [String(pr["at"])]
			_:
				subj = [String(pr["actor"])]
		for rr: float in [r0 + minf(0.08, (r1 - r0) * 0.2), (r0 + r1) * 0.5, r1 - minf(0.08, (r1 - r0) * 0.2)]:
			p.seek(rr)
			var cam: Camera3D = p.camera
			for id: String in subj:
				var a: CineActor = p.actors.get(id)
				if a == null or not a.is_visible_in_tree():
					_check(false, "%s %s @%.2f: subject %s is hidden" % [tl.slot, String(sh["id"]), rr, id])
					continue
				var pts: PackedVector3Array = CameraFraming.subject_points(a)
				var rep: Dictionary = CameraFraming.report(cam, pts, world.get_world_3d().direct_space_state, [], CameraRules.SAFE_MARGIN, lb)
				_check(bool(rep["ok"]), "%s %s (%s) @%.2f: %s %s" % [tl.slot, String(sh["id"]), rig, rr, id, CameraFraming.describe(cam, pts, rep)])
				var blocker: String = _blocked(p, cam.global_position, pts[0], id)
				_check(blocker == "", "%s %s (%s) @%.2f: %s stands in front of %s's face" % [tl.slot, String(sh["id"]), rig, rr, blocker, id])
			if rig == "dutch":
				var want: float = float(pr.get("roll", 14.0))
				var got: float = rad_to_deg(asin(clampf(cam.global_basis.x.y, -1.0, 1.0)))
				_check(absf(got) >= absf(want) * 0.8 and signf(got) == signf(want), "%s %s: dutch roll %.1f (want ~%.1f)" % [tl.slot, String(sh["id"]), got, want])
	p.queue_free()
	await process_frame
	return n


## The id of a visible actor (other than the subject) whose head or chest lies near the camera -> face segment, else "".
func _blocked(p: CinePlayer, cam_p: Vector3, face: Vector3, subj: String) -> String:
	var seg: Vector3 = face - cam_p
	var len2: float = seg.length_squared()
	for id: String in p.actors.keys():
		if id == subj:
			continue
		var a: CineActor = p.actors[id]
		if not a.is_visible_in_tree():
			continue
		var pts: PackedVector3Array = CameraFraming.subject_points(a)
		for k: int in mini(2, pts.size()):
			var t: float = clampf((pts[k] - cam_p).dot(seg) / maxf(len2, 1e-6), 0.0, 1.0)
			if t > 0.05 and t < 0.92 and (cam_p + seg * t).distance_to(pts[k]) < BLOCK_R:
				return id
	return ""


# ---------------------------------------------------------------------------
# C. the finisher
# ---------------------------------------------------------------------------
func _hold(a: CineActor, pre: String) -> Dictionary:
	for h: Dictionary in a.holds:
		if String((h["node"] as Node3D).name).begins_with(pre) and (h["att"] as Node3D).visible:
			return h
	return {}


## A held prop's transform from the skeleton (headless global transforms of bone attachments are stale).
func _held_xf(a: CineActor, h: Dictionary) -> Transform3D:
	var hx: Transform3D = a.sk.global_transform * CharacterBuilder._bone_global_now(a.sk, a.sk.find_bone(String(h["bone"])))
	return hx * (h["node"] as Node3D).transform


func _held_boxes(a: CineActor, h: Dictionary) -> Array:
	var node: Node3D = h["node"]
	var nx: Transform3D = _held_xf(a, h)
	var inv: Transform3D = node.global_transform.affine_inverse()
	var out: Array = []
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		var ab: AABB = mi.mesh.get_aabb()
		var gx: Transform3D = nx * (inv * mi.global_transform)
		out.append([String(mi.name), Transform3D(gx.basis.orthonormalized(), gx * ab.get_center()), ab.size * gx.basis.get_scale() * 0.5])
	return out


## Smallest gap (m, < 0 = overlapping) between two sets of oriented boxes: a 5 x 5 x 9 grid of each box of `a` (9 along its
## longest axis) against the boxes of `b`.
func _box_gap(a: Array, b: Array) -> float:
	var best: float = INF
	for ba: Array in a:
		var xf: Transform3D = ba[1]
		var h: Vector3 = ba[2]
		var long: int = 0 if h.x >= h.y and h.x >= h.z else (1 if h.y >= h.z else 2)
		var nn: Vector3i = Vector3i(5, 5, 5)
		nn[long] = 9
		for i: int in nn.x:
			for j: int in nn.y:
				for k: int in nn.z:
					var q := Vector3(h.x * (2.0 * i / (nn.x - 1) - 1.0), h.y * (2.0 * j / (nn.y - 1) - 1.0), h.z * (2.0 * k / (nn.z - 1) - 1.0))
					var w: Vector3 = xf * q
					for bb: Array in b:
						best = minf(best, Bodies._box_sdf((bb[1] as Transform3D).affine_inverse() * w, bb[2]))
	return best


## Lowest point (world y) of a prop's meshes.
func _lowest(n: Node3D) -> float:
	var lo: float = INF
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		if mi.mesh == null:
			continue
		var ab: AABB = mi.mesh.get_aabb()
		for k: int in 8:
			lo = minf(lo, (mi.global_transform * ab.get_endpoint(k)).y)
	return lo


func _fin_static(tl: CineTimeline) -> void:
	_check(tl.clock.ramps.size() == 4, "the finisher has four slow-motion ramps: H1, A1, H2, H5 (%d)" % tl.clock.ramps.size())
	for e: Array in [["H1", FIN.R_H1, "medium"], ["A1", FIN.R_A1, "accent"], ["H2", FIN.R_H2, "heavy"], ["H5", FIN.R_H5, "finisher"]]:
		var rw: Dictionary = tl.clock.ramp(String(e[0]))
		_check(String(rw.get("preset", "")) == String(e[2]) and absf(float(rw.get("r_hit", -1.0)) - float(e[1])) < 0.0005,
			"%s: %s ramp, impact at real %.3f (%.4f)" % [String(e[0]), String(e[2]), float(e[1]), float(rw.get("r_hit", -1.0))])
	var fin: Dictionary = tl.clock.ramp("H5")
	_check(absf(float(fin.get("r1", 0.0)) - FIN.SWELL_END) < 0.0005, "the finisher swell ends at real 22.000 (%.4f)" % float(fin.get("r1", 0.0)))
	_check(absf(tl.length - float(fin.get("r1", 0.0)) - FIN.TAIL) < 0.0005 and tl.clock.speed_at(23.5) > 0.99, "a 3.000 s tail at normal speed")
	_check(tl.clock.speed_at(FIN.R_LEAVE) < 0.6, "the helicopter starts to leave inside the swell")
	var want: Array = [["hero", "H1", "chair_smash"], ["lo", "A1", "hook"], ["hero", "A1", "dodge"], ["hero", "H2", "knee_strike"],
		["hero", "H5", "scissor_takedown"], ["lo", "H5", "thrown"]]
	for w: Array in want:
		_check(tl.cues.any(func(c: Dictionary) -> bool: return c["type"] == "strike" and c["actor"] == w[0] and c["at"] == w[1] and c["move"] == w[2]),
			"%s strikes %s on %s" % [String(w[0]), String(w[2]), String(w[1])])
	var said: String = ""
	for sb: Dictionary in tl.subs:
		said += String(sb["speaker"]) + ":" + String(sb["text"]) + "\n"
	_check(said.contains("hero:Đòn chân kẹp cổ số 21!") and said.contains("lo:Mày có biết tao là ai không?")
		and said.contains("hero:Biết. Ông hiệu trưởng sắp về hưu."), "the finisher's lines (the question, the retirement joke, số 21)")
	var last: Dictionary = tl.subs[tl.subs.size() - 1]
	_check(String(last["speaker"]) == "hero" and String(last["text"]) == "Xin vĩnh biệt cụ." and float(last["r"]) > FIN.SWELL_END,
		"the protagonist has the last word in the tail: Xin vĩnh biệt cụ.")
	var calls: bool = false
	for sb2: Dictionary in tl.subs:
		calls = calls or (String(sb2["speaker"]) == "lo" and String(sb2["text"]).contains("trực thăng") and float(sb2["r"]) >= FIN.R_LEAVE)
	_check(calls, "Lọ calls after the helicopter once it leaves")
	_check(tl.fx.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "sparks" and String(e["at"]) == "H1"), "sparks on the clash")
	_check(tl.fx.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "stars" and String(e["where"]) == "lo"), "stars over Lọ (no gore)")


func _fin_tier(tl: CineTimeline, cap: int) -> void:
	CineMoves.max_tier = cap
	var label: String = ["mixamo", "ual", "native", "code"][cap]
	var p := CinePlayer.new()
	world.add_child(p)
	p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	await process_frame
	var hero: CineActor = p.actors["hero"]
	var lo: CineActor = p.actors["lo"]
	var lim: float = GAP_MIXAMO if label == "mixamo" else GAP_OTHER
	# H1: gạt kiếm, the staff on the stub
	p.seek(float(tl.clock.ramp("H1")["r_hit"]))
	var st: Dictionary = _hold(hero, "Staff")
	var sb: Dictionary = _hold(lo, "Saber")
	_check(not st.is_empty() and not sb.is_empty(), "%s H1: the staff and the stub are in hand" % label)
	if not st.is_empty() and not sb.is_empty():
		var stb: Array = _held_boxes(hero, st)
		var g: float = _box_gap(_held_boxes(lo, sb), stb)
		var gb: float = float(Bodies.gap_boxes(Bodies.capsules(lo), stb)["g"])
		var sx: Transform3D = _held_xf(lo, sb)
		var aim: float = (-sx.basis.z).normalized().dot((hero.bone_world("Chest") - sx.origin).normalized())
		print("  %-6s H1 staff-stub %+.3f, staff-Lọ %+.3f, stub aim %.2f" % [label, g, gb, aim])
		_check(g <= 0.04 and g >= -0.04, "%s H1: the staff meets the stub (gap %+.3f in [-0.04, 0.04])" % [label, g])
		_check(gb >= -0.06, "%s H1: the staff does not cut into Lọ (%+.3f)" % [label, gb])
		_check(aim > 0.7, "%s H1: the stub's point is at the protagonist (%.2f)" % [label, aim])
	# the held weapons: the staff clears its holder's body (the guard, the windup, the answer) and Lọ's (deeper only on the
	# clash), the stub in his hand never stabs the protagonist
	var worst_own: float = INF
	var own_at: String = ""
	var worst_lo: float = INF
	var lo_at: String = ""
	var worst_stab: float = INF
	var stab_at: String = ""
	var h1s: float = tl.story_time("H1")
	var rr: float = 0.0
	while rr < FIN.TOSS_R:
		p.seek(rr)
		var h2: Dictionary = _hold(hero, "Staff")
		if not h2.is_empty():
			var own: Array = []
			for c2: Array in Bodies.capsules(hero):
				if String(c2[0]) in ["torso", "head", "thigh.L", "thigh.R"]:
					own.append(c2)
			var sbx: Array = _held_boxes(hero, h2)
			var go: Dictionary = Bodies.gap_boxes(own, sbx)
			if float(go["g"]) < worst_own:
				worst_own = float(go["g"])
				own_at = "%s at r %.2f" % [String(go["from"]), rr]
			var gl: Dictionary = Bodies.gap_boxes(Bodies.capsules(lo), sbx)
			var lim_lo: float = -0.06 if absf(p.s - h1s) <= PEN_WINDOW else -0.03
			if float(gl["g"]) - lim_lo < worst_lo:
				worst_lo = float(gl["g"]) - lim_lo
				lo_at = "%+.3f %s at r %.2f" % [float(gl["g"]), String(gl["from"]), rr]
		var h3: Dictionary = _hold(lo, "Saber")
		if not h3.is_empty():
			var gs: Dictionary = Bodies.gap_boxes(Bodies.capsules(hero), _held_boxes(lo, h3))
			if float(gs["g"]) < worst_stab:
				worst_stab = float(gs["g"])
				stab_at = "%s at r %.2f" % [String(gs["from"]), rr]
		rr += 1.0 / 30.0
	print("  %-6s held staff: to its holder %+.3f (%s), to Lọ %s; the stub in hand to the protagonist %+.3f (%s)" % [label, worst_own, own_at,
		lo_at, worst_stab, stab_at])
	_check(worst_own >= -0.03, "%s: the held staff does not pass through the protagonist's body (%+.3f, %s)" % [label, worst_own, own_at])
	_check(worst_lo >= 0.0, "%s: the held staff does not cut into Lọ (%s)" % [label, lo_at])
	_check(worst_stab >= 0.0, "%s: the stub in Lọ's hand never stabs the protagonist (%+.3f, %s)" % [label, worst_stab, stab_at])
	# A1: the hook sails past (a near miss)
	var a1: float = tl.story_time("A1")
	var mn: float = INF
	rr = tl.clock.real_at(a1 - 0.3)
	while rr <= tl.clock.real_at(a1 + 0.3):
		p.seek(rr)
		mn = minf(mn, float(Bodies.gap_spheres(Bodies.fists(lo), Bodies.capsules(hero))["g"]))
		rr += 1.0 / 60.0
	print("  %-6s A1 closest fist %+.3f" % [label, mn])
	_check(mn > 0.0 and mn <= 0.35, "%s A1: Lọ's hook misses, close (%+.3f in (0, 0.35])" % [label, mn])
	# H2: the knee on his torso
	p.seek(float(tl.clock.ramp("H2")["r_hit"]))
	var gk: Dictionary = Bodies.gap_spheres([["knee.L", hero.bone_world("LowerLeg.L"), 0.07], ["knee.R", hero.bone_world("LowerLeg.R"), 0.07]],
		Bodies.capsules(lo))
	print("  %-6s H2 knee %+.3f (%s -> %s)" % [label, float(gk["g"]), String(gk["from"]), String(gk["to"])])
	var gt: float = float(Bodies.gap_spheres([["knee.L", hero.bone_world("LowerLeg.L"), 0.07], ["knee.R", hero.bone_world("LowerLeg.R"), 0.07]],
		Bodies.capsules(lo).filter(func(c: Array) -> bool: return String(c[0]) == "torso"))["g"])
	_check(float(gk["g"]) >= -0.06 and float(gk["g"]) <= lim and gt <= 0.12, "%s H2: the knee lands on Lọ's middle (%+.3f in [-0.06, %.2f] on %s, %+.3f to the torso)" % [label,
		float(gk["g"]), lim, String(gk["to"]), gt])
	# H5: the legs round his neck
	p.seek(float(tl.clock.ramp("H5")["r_hit"]))
	var neck: Vector3 = lo.bone_world("Neck")
	var head: Vector3 = lo.bone_world("Head")
	var legs: Dictionary = {}
	for sd: String in ["L", "R"]:
		var best: float = INF
		var at: Vector3 = Vector3.ZERO
		for part: Array in [["UpperLeg.", "LowerLeg.", 0.08], ["LowerLeg.", "Foot.", 0.06]]:
			var a: Vector3 = hero.bone_world(String(part[0]) + sd)
			var b: Vector3 = hero.bone_world(String(part[1]) + sd)
			var d: float = Bodies.seg_dist(a, b, neck, head) - float(part[2]) - 0.07
			if d < best:
				best = d
				at = Geometry3D.get_closest_points_between_segments(a, b, neck, head)[0]
		legs[sd] = [best, at]
	var front: float = minf(float(legs["L"][0]), float(legs["R"][0]))
	var back: float = maxf(float(legs["L"][0]), float(legs["R"][0]))
	var mid: Vector3 = (neck + head) * 0.5
	var between: bool = ((legs["L"][1] as Vector3) - mid).dot((legs["R"][1] as Vector3) - mid) < 0.0
	var leg_caps: Array = []
	for c: Array in Bodies.capsules(hero):
		if String(c[0]).begins_with("thigh") or String(c[0]).begins_with("shin"):
			leg_caps.append(c)
	var sink: float = float(Bodies.gap_caps(leg_caps, Bodies.capsules(lo))["g"])
	print("  %-6s H5 legs to the neck %+.3f / %+.3f, between %s, deepest leg %+.3f" % [label, front, back, str(between), sink])
	_check(front <= 0.08 and back <= 0.25 and between, "%s H5: the legs close round Lọ's neck (front %+.3f <= 0.08, back %+.3f <= 0.25, between %s)" % [label, front, back, str(between)])
	_check(sink >= -0.06, "%s H5: no leg sinks into Lọ (%+.3f)" % [label, sink])
	# the end: Lọ flat on the helipad, the protagonist standing clear
	for r_end: float in [20.0, 24.5]:
		p.seek(r_end)
		var hy: float = lo.bone_world("Hips").y
		var low: float = INF
		for bn: String in ["Head", "Hips", "Chest", "Foot.L", "Foot.R", "Wrist.L", "Wrist.R"]:
			low = minf(low, lo.bone_world(bn).y)
		var lh: Vector3 = lo.bone_world("Hips")
		var off: float = Vector2(lh.x, lh.z).distance_to(Vector2(FIN.L_DOWN.x, FIN.L_DOWN.z))
		var clear: float = float(Bodies.gap_caps(Bodies.capsules(hero), Bodies.capsules(lo))["g"])
		_check(hy < 0.45 and low > -0.08 and off < 0.6, "%s r %.1f: Lọ lies on the helipad at L_DOWN (hips %.2f, lowest %.2f, %.2f m off)" % [label, r_end, hy, low, off])
		_check(hero.bone_world("Hips").y > 0.65 and clear > 0.05, "%s r %.1f: the protagonist stands clear of him (hips %.2f, gap %.2f)" % [label, r_end, hero.bone_world("Hips").y, clear])
	if OS.get_environment("CINE_FAST") != "1":
		_fin_sweep(tl, p, label)
	p.queue_free()
	await process_frame


## Every 1/60 s: the two bodies' deepest overlap (deeper allowed only on a hit), feet above the deck, no hips pop, nobody in
## the stub or the staff once they lie on the deck.
func _fin_sweep(tl: CineTimeline, p: CinePlayer, label: String) -> void:
	var hits: Array[float] = []
	for rw: Dictionary in tl.clock.ramps:
		hits.append(float(rw["s"]))
	var hero: CineActor = p.actors["hero"]
	var lo: CineActor = p.actors["lo"]
	p.seek(tl.length)
	var rest: Dictionary = {"stub": [float(tl.get("s_stub_land")), Bodies.prop_boxes(p.prop_nodes["stub"])],
		"staff_drop": [float(tl.get("s_toss")) + 0.5, Bodies.prop_boxes(p.prop_nodes["staff_drop"])]}
	var worst: Dictionary = {"d": -1.0, "what": "-"}
	var fail: String = ""
	var fails_seen: Array[String] = []   # one line per overlap episode (consecutive frames merge)
	var in_ep: bool = false
	var pop: float = 0.0
	var pop_at: String = ""
	var prev: Dictionary = {}
	for f: int in int(round(tl.length * 60.0)) + 1:
		var r: float = f / 60.0
		p.seek(r)
		var near: bool = hits.any(func(h: float) -> bool: return absf(p.s - h) <= PEN_WINDOW)
		var ch: Array = Bodies.capsules(hero)
		var cl: Array = Bodies.capsules(lo)
		var res: Dictionary = Bodies.actor_pair(ch, cl)
		var core: bool = Bodies.is_core(res["pa"]) and Bodies.is_core(res["pb"])
		var lim: float = (PEN_HIT_CORE if core else PEN_HIT_LIMB) if near else PEN_MAX
		var what: String = "hero %s / lo %s at r %.2f%s" % [res["pa"], res["pb"], r, " (hit)" if near else ""]
		if float(res["d"]) > float(worst["d"]):
			worst = {"d": res["d"], "what": what}
		if float(res["d"]) > lim:
			if fail == "":
				fail = "%.3f m > %.2f: %s" % [res["d"], lim, what]
			if not in_ep:
				fails_seen.append("%.3f m > %.2f: %s" % [res["d"], lim, what])
			in_ep = true
		else:
			in_ep = false
		for e: Array in [["hero", hero, ch], ["lo", lo, cl]]:
			var a: CineActor = e[1]
			for fb: String in ["Foot.L", "Foot.R"]:
				if a.bone_world(fb).y < FOOT_FLOOR and fail == "":
					fail = "%s %s %.3f m under the deck at r %.2f" % [String(e[0]), fb, -a.bone_world(fb).y, r]
			var hp: Vector3 = a.bone_world("Hips")
			if prev.has(e[0]) and hp.distance_to(prev[e[0]]) > pop:
				pop = hp.distance_to(prev[e[0]])
				pop_at = "%s at r %.2f" % [String(e[0]), r]
			prev[e[0]] = hp
			for pk: String in rest.keys():
				if p.s < float(rest[pk][0]):
					continue
				var rb: Dictionary = Bodies.actor_boxes(e[2], rest[pk][1])
				if float(rb["d"]) > PEN_MAX and fail == "":
					fail = "%.3f m: %s %s in the %s at r %.2f" % [rb["d"], String(e[0]), rb["part"], pk, r]
	print("  %-6s bodies: worst overlap %.3f m (%s), max hips step %.3f m (%s)" % [label, maxf(float(worst["d"]), 0.0), worst["what"], pop, pop_at])
	for fl: String in fails_seen.slice(0, 8):
		print("         overlap: ", fl)
	_check(fail == "", "%s: bodies never sink in, feet stay on the deck (%s)" % [label, fail])
	_check(pop <= POP_MAX, "%s: no hips pop (%.3f m in one frame, %s)" % [label, pop, pop_at])


func _fin_props(tl: CineTimeline) -> void:
	CineMoves.max_tier = 1
	var p := CinePlayer.new()
	world.add_child(p)
	p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	await process_frame
	var hero: CineActor = p.actors["hero"]
	var lo: CineActor = p.actors["lo"]
	var h1: float = tl.story_time("H1")
	var s_land: float = float(tl.get("s_stub_land"))
	var s_toss: float = float(tl.get("s_toss"))
	# the stub: in his hand until the clash, then the loose one flies from exactly there
	var stub: Node3D = p.prop_nodes["stub"]
	p.seek(tl.clock.real_at(h1 + 0.028))
	var sh: Dictionary = _hold(lo, "Saber")
	_check(not sh.is_empty() and not stub.visible, "the stub stays in Lọ's hand until the clash, the loose one hidden")
	var hand: Transform3D = _held_xf(lo, sh) if not sh.is_empty() else Transform3D()
	p.seek(tl.clock.real_at(h1 + 0.031))
	_check(stub.visible and _hold(lo, "Saber").is_empty(), "on the clash the stub leaves his hand (the loose one shows)")
	var d0: float = stub.global_position.distance_to(hand.origin)
	var a0: float = rad_to_deg((-stub.global_basis.z).angle_to(-hand.basis.z))
	print("  stub hand -> loose: %.3f m, %.1f deg" % [d0, a0])
	_check(d0 < 0.04 and a0 < 15.0, "the loose stub starts where it was in his hand (%.3f m, %.1f deg)" % [d0, a0])
	var fly: float = INF
	var fly_at: String = ""
	var s: float = h1 + 0.031
	while s < s_land:
		p.seek(tl.clock.real_at(s))
		var bx: Array = Bodies.prop_boxes(stub)
		for a: CineActor in [hero, lo]:
			var caps: Array = Bodies.capsules(a)
			if a == lo and s < h1 + 0.13:   # leaving his hand: the grip is still in his fist for a few frames
				caps = caps.filter(func(c: Array) -> bool: return String(c[0]) != "forearm.R")
			var dd: Dictionary = Bodies.actor_boxes(caps, bx)
			if -float(dd["d"]) < fly:
				fly = -float(dd["d"])
				fly_at = "%s %s, %s, s %.2f after the clash" % [a.name, String(dd["part"]), String(dd["box"]), s - h1]
		s += 0.02
	print("  stub in flight: closest to a body %+.3f m (%s)" % [fly, fly_at])
	_check(fly > -0.01, "the stub flies clear of both bodies (%+.3f)" % fly)
	p.seek(tl.clock.real_at(s_land + 0.1))
	var low: float = _lowest(stub)
	_check(stub.position.distance_to(FIN.STUB_LAND) < 0.01 and low > -0.01 and low < 0.025, "the stub comes to rest on the deck (lowest point %.3f)" % low)
	# the staff: held until the toss, then the loose one flies from his hands and lands flat
	var staff: Node3D = p.prop_nodes["staff_drop"]
	p.seek(tl.clock.real_at(s_toss - 0.004))
	var stf: Dictionary = _hold(hero, "Staff")
	_check(not stf.is_empty() and not staff.visible, "the staff stays in the protagonist's hands until the toss")
	var hx: Transform3D = _held_xf(hero, stf) if not stf.is_empty() else Transform3D()
	p.seek(tl.clock.real_at(s_toss + 0.002))
	_check(staff.visible and _hold(hero, "Staff").is_empty(), "on the toss the loose staff shows, the held one goes")
	var d1: float = staff.global_position.distance_to(hx.origin)
	var a1: float = rad_to_deg((-staff.global_basis.z).angle_to(-hx.basis.z))
	print("  staff hands -> loose: %.3f m, %.1f deg" % [d1, a1])
	_check(d1 < 0.04 and a1 < 15.0, "the tossed staff starts in his hands (%.3f m, %.1f deg; held at H0 + %s)" % [d1, a1, str((hx.origin - FIN.H0).snapped(Vector3.ONE * 0.001))])
	fly = INF
	s = s_toss + 0.02
	while s < s_toss + 0.5:
		p.seek(tl.clock.real_at(s))
		var bx2: Array = Bodies.prop_boxes(staff)
		for a2: CineActor in [hero, lo]:
			var caps2: Array = Bodies.capsules(a2)
			if a2 == hero and s < s_toss + 0.1:   # leaving his hands
				caps2 = caps2.filter(func(c: Array) -> bool: return not String(c[0]).begins_with("forearm"))
			var de: Dictionary = Bodies.actor_boxes(caps2, bx2)
			if -float(de["d"]) < fly:
				fly = -float(de["d"])
				fly_at = "%s %s, s %.2f after the toss" % [a2.name, String(de["part"]), s - s_toss]
		s += 0.02
	print("  staff in flight: closest to a body %+.3f m (%s)" % [fly, fly_at])
	_check(fly > -0.01, "the tossed staff flies clear of both bodies (%+.3f)" % fly)
	p.seek(tl.clock.real_at(s_toss + 0.6))
	low = _lowest(staff)
	_check(staff.position.distance_to(FIN.STAFF_LAND) < 0.01 and low > -0.01 and low < 0.025, "the staff lands flat on the deck (lowest point %.3f)" % low)
	# the helicopter: hovers over the helipad, then banks away and climbs off without him
	var heli: Node3D = p.prop_nodes["heli"]
	var rotor: Node3D = p.prop_nodes["rotor"]
	var light: Node3D = p.prop_nodes["searchlight"]
	for r: float in [1.0, 5.0, 12.0, 20.5]:
		p.seek(r)
		_check(heli.global_position.distance_to(FIN.HELI) < 0.3, "the helicopter hovers over the helipad at r %.1f (%.2f m off)" % [r, heli.global_position.distance_to(FIN.HELI)])
	p.seek(tl.length)
	var gone: float = heli.global_position.distance_to(FIN.HELI)
	_check(gone >= 10.0 and heli.global_position.y > FIN.HELI.y + 2.0, "the helicopter leaves (%.1f m by the end)" % gone)
	for r2: float in [1.0, 8.0, 14.0, 21.5, 23.0, 24.9]:
		p.seek(r2)
		var want: Vector3 = heli.global_transform * CinePropsD7.ROTOR_AT
		_check(rotor.global_position.distance_to(want) < 0.05, "the rotor stays on the helicopter at r %.1f (%.3f m)" % [r2, rotor.global_position.distance_to(want)])
	p.seek(1.0)
	var x0: Vector3 = rotor.global_basis.x
	p.seek(1.05)
	var spin: float = rad_to_deg(x0.angle_to(rotor.global_basis.x))
	_check(spin > 20.0, "the rotor spins (%.0f deg in 0.05 s)" % spin)
	p.seek(5.0)
	var spot: SpotLight3D = light.find_child("Spot", true, false) as SpotLight3D
	var to_aim: Vector3 = (FIN.AIM - light.global_position).normalized()
	var off: float = rad_to_deg((-light.global_basis.z).angle_to(to_aim))
	_check(spot != null and off < 3.0, "the searchlight is aimed at the duel (%.1f deg off)" % off)
	var rain: Node3D = p.prop_nodes["rain"]
	var em: CPUParticles3D = rain.find_child("Rain", true, false) as CPUParticles3D
	_check(em != null and em.emitting and em.has_meta("cine_ambient"), "the rain falls on the cinematic clock (cine_ambient)")
	p.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# D. the tower
# ---------------------------------------------------------------------------
func _tower() -> void:
	var lv := LairTower.new()
	root.add_child(lv)
	lv.build()
	await process_frame
	var g: Transform3D = lv.floor_xf("gallery")
	_check(lv.cine_xf("seg_d7_phase2").is_equal_approx(g.translated_local(Vector3(0.4, 0.0, -0.75))), "seg_d7_phase2 is staged at the gallery's (0.4, 0, -0.75)")
	_check(lv.cine_xf("cine_d7_monologue").is_equal_approx(g), "the monologue is staged in the gallery")
	_check(lv.cine_xf("seg_d7_finisher").is_equal_approx(lv.floor_xf("roof")), "the finisher is staged on the roof")
	var all: Array[Node3D] = []
	for v: Dictionary in lv.vases:
		all.append(v["plinth"])
	for n: Node3D in [lv.heli, lv.heli_light]:
		all.append(n)
	for r: CPUParticles3D in lv.rain:
		all.append(r)
	_check(lv.vases.size() == 12 and lv.heli != null and lv.heli_light != null and not lv.rain.is_empty(), "the tower has its 12 plinths, the helicopter, its light, the rain")
	var before: Array = all.map(func(n: Node3D) -> bool: return n.visible)
	# the monologue brings nothing of its own
	lv.hide_for_cine(true, "cine_d7_monologue")
	_check(all.map(func(n: Node3D) -> bool: return n.visible) == before, "the monologue hides nothing")
	lv.hide_for_cine(false)
	# phase 2: exactly the two plinths at (+-3, 0)
	lv.hide_for_cine(true, "seg_d7_phase2")
	var hidden: Array = []
	for v: Dictionary in lv.vases:
		if not (v["plinth"] as Node3D).visible:
			hidden.append(Vector2((v["at"] as Vector3).x, (v["at"] as Vector3).z))
	hidden.sort()
	_check(hidden == [Vector2(-3.0, 0.0), Vector2(3.0, 0.0)] and lv.heli.visible, "phase 2 hides exactly the plinths at (-3, 0) and (3, 0) (%s)" % str(hidden))
	lv.hide_for_cine(false)
	_check(all.map(func(n: Node3D) -> bool: return n.visible) == before, "after phase 2 every plinth shows again")
	# the finisher: the helicopter, its light and the rain
	for r2: CPUParticles3D in lv.rain:
		r2.emitting = true
	lv.hide_for_cine(true, "seg_d7_finisher")
	var rain_off: bool = lv.rain.all(func(r3: CPUParticles3D) -> bool: return not r3.visible and not r3.emitting)
	_check(not lv.heli.visible and not lv.heli_light.visible and rain_off and lv.vases.all(func(v: Dictionary) -> bool: return (v["plinth"] as Node3D).visible),
		"the finisher hides the tower's helicopter, its light and the rain, nothing else")
	lv.hide_for_cine(false)
	var rain_on: bool = lv.rain.all(func(r4: CPUParticles3D) -> bool: return r4.visible and r4.emitting)
	_check(lv.heli.visible and lv.heli_light.visible and rain_on, "after the finisher the helicopter, the light and the rain (emitting) are back")
	lv.queue_free()
	await process_frame
