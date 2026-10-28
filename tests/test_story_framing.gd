# File: res://tests/test_story_framing.gd
# Headless test of the Q5 story cinematic pass (plan 2026-10-29-w2-story T6 / T7), the substitute for screenshots:
#   1. pacing: every story dialogue cinematic of Days 0-5 validates, lasts at most 30 s and has a joke beat; each day ends
#      (ai_intro, cine_d1 .. cine_d5) on a cliffhanger line (its last subtitle) followed by a sting;
#   2. camera language: every scene uses the Q1 shot helpers (two_shot / ots / low_hero / dutch / push_in); the shot over
#      each villain card is a push-in or a dutch angle;
#   3. framing: every helper shot, sampled at its start, middle and end inside a CinePlayer (manual, empty world), frames
#      its subjects' head, chest and hips inside the letterboxed 8 % safe area (CameraFraming.report: Camera3D
#      .unproject_position plus rays), no other actor stands in the line of sight to a subject's face, and dutch shots roll;
#   4. acting: every scene where a character talks for more than one line gives a talker a gesture.
# Run:  godot --headless --path . --script tests/test_story_framing.gd
extends SceneTree

const SLOTS: Array[String] = ["cine_d0_wake", "cine_d0_brief", "cine_d0_exam", "cine_d0_midnight", "ai_intro", "cine_day_start",
	"cine_d1_intro", "cine_d1_corridor", "cine_d1_choice", "cine_d1_choice_cover", "cine_d1_choice_report", "cine_d1",
	"cine_d2_intro", "cine_d2", "cine_d3_intro", "cine_d3_mannequins", "cine_d3", "cine_d4_intro", "cine_d4_stare", "cine_d4",
	"cine_d5_intro", "cine_d5_monitors", "cine_d5_choice", "cine_d5_choice_accept", "cine_d5_choice_refuse", "cine_d5", "end_c"]
const DAY_END: Array[String] = ["ai_intro", "cine_d1", "cine_d2", "cine_d3", "cine_d4", "cine_d5"]
const HELPERS: Array[String] = ["two_shot", "ots", "low_hero", "dutch", "push_in"]
const GESTURES: Array[String] = ["talk", "talk_ual", "point", "arms_crossed", "fold_arms", "facepalm", "shrug", "laugh", "head_no",
	"nod", "present", "confess", "cornered", "taunt", "head_shake", "startled", "victory", "bow_ceo"]
const BLOCK_R: float = 0.18
## The Day 4 stare card's pointer gag ("...à nhầm, con kia") is aimed through the static wide row; the reveal right after it
## is the dutch angle on Dolly.
const CARD_STATIC_OK: Array[String] = ["cine_d4_stare"]
## Riding with Anh Duy only on the radio (no hands free for a gesture).
const ACT_EXEMPT: Array[String] = ["cine_d3_intro"]
var fails: Array[String] = []
var world: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("== test_story_framing")
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var shots_checked: int = 0
	var samples: int = 0
	for slot: String in SLOTS:
		var tl: CineTimeline = CineTimeline.load_slot(slot)
		_check(tl != null, "%s loads" % slot)
		if tl == null:
			continue
		var errs: PackedStringArray = tl.validate()
		_check(errs.is_empty(), "%s validates: %s" % [slot, "; ".join(errs)])
		# 1. pacing
		_check(tl.length <= 30.0 + 1e-6, "%s lasts at most 30 s (%.1f)" % [slot, tl.length])
		_check(not tl.jokes.is_empty(), "%s has a joke beat" % slot)
		if slot in DAY_END:
			var last_r: float = -1.0
			for sb: Dictionary in tl.subs:
				last_r = maxf(last_r, float(sb["r"]))
			_check(tl.cliff_r >= 0.0 and absf(tl.cliff_r - last_r) < 0.001, "%s ends on its cliffhanger line (cliff %.2f, last line %.2f)" % [slot, tl.cliff_r, last_r])
		# 2. camera language
		var helper_n: int = 0
		for sh: Dictionary in tl.shots:
			if String(sh["rig"]) in HELPERS:
				helper_n += 1
		_check(helper_n >= 1, "%s uses the Q1 shot helpers (%d)" % [slot, helper_n])
		for cd: Dictionary in tl.cards:
			if String(cd["kind"]) != "villain" or slot in CARD_STATIC_OK:
				continue
			var sh_at: Dictionary = _shot_at(tl, tl.clock.story_at(float(cd["r"]) + 0.01))
			_check(String(sh_at.get("rig", "")) in ["push_in", "dutch"], "%s: the villain card plays over a push-in or a dutch angle (%s)" % [slot, String(sh_at.get("rig", "?"))])
		# 4. acting
		var talkers: Dictionary = {}
		for sb2: Dictionary in tl.subs:
			talkers[String(sb2["speaker"])] = int(talkers.get(String(sb2["speaker"]), 0)) + 1
		var needs: bool = false
		for k: String in talkers.keys():
			if int(talkers[k]) >= 2 and tl.actors.has(k):
				needs = true
		if needs and not (slot in ACT_EXEMPT):
			var gest: bool = false
			for c: Dictionary in tl.cues:
				if String(c["type"]) == "move" and String(c["move"]) in GESTURES and talkers.has(String(c["actor"])):
					gest = true
			_check(gest, "%s: a talking actor gestures" % slot)
		# 3. framing
		var res: Array = await _frame_slot(tl)
		shots_checked += int(res[0])
		samples += int(res[1])
	print("  helper shots checked: %d (%d samples)" % [shots_checked, samples])
	_check(shots_checked >= SLOTS.size(), "helper shots across the story (%d)" % shots_checked)
	world.queue_free()
	await process_frame
	if fails.is_empty():
		print("SUCCESS test_story_framing")
		quit(0)
	else:
		print("FAILED test_story_framing: %d" % fails.size())
		quit(1)


func _shot_at(tl: CineTimeline, s: float) -> Dictionary:
	var out: Dictionary = {}
	for sh: Dictionary in tl.shots:
		if float(sh["s"]) <= s + 1e-6:
			out = sh
	return out


func _frame_slot(tl: CineTimeline) -> Array:
	var p := CinePlayer.new()
	world.add_child(p)
	var errs: PackedStringArray = p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false, "drop_set": true})
	if not errs.is_empty():
		p.queue_free()
		return [0, 0]
	p.start()
	await process_frame
	var vs: Vector2 = root.get_visible_rect().size
	var lb: float = (p.overlay.bar_height_full() / vs.y) if tl.letterbox else 0.0
	var n_shots: int = 0
	var n_samples: int = 0
	for i: int in tl.shots.size():
		var sh: Dictionary = tl.shots[i]
		var rig: String = String(sh["rig"])
		if not (rig in HELPERS):
			continue
		n_shots += 1
		var r0: float = p._shot_r[i]
		var r1: float = p._shot_r[i + 1] if i + 1 < tl.shots.size() else tl.length
		var pr: Dictionary = sh["params"]
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
			n_samples += 1
			var cam: Camera3D = p.camera
			for id: String in subj:
				var a: CineActor = p.actors.get(id)
				if a == null or not a.is_visible_in_tree():
					fails.append("%s %s @%.2f: subject %s is hidden" % [tl.slot, String(sh["id"]), rr, id])
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
	return [n_shots, n_samples]


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
