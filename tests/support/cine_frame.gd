# File: res://tests/support/cine_frame.gd
# The strong shot check of the fight cinematics (plan 2026-11-05-w6-fights, fix round), shared by tests/support/cine_brawl.gd
# and tests/support/cine_fight.gd. Every shot is sampled N (16) times, evenly, 2 frames clear of each cut:
#   subjects   the shot's params "subj" (actor ids). The Q1 helpers default to theirs (two_shot: a and b; ots: at; low_hero,
#              dutch, push_in: actor). DEFAULT for any other shot without "subj": the visible actor whose head is nearest
#              the frame centre at the shot's middle sample (so a timeline that never names subjects is still checked).
#   framing    each subject's head and chest inside the letterboxed 8 % safe area in >= 90 % of the samples, its head
#              inside the letterboxed frame in every sample, no other actor standing in front of its face. Samples inside
#              the shot's params "exit_ok" [r0, r1] (real seconds) are skipped: a body thrown out of frame on purpose.
#   occlusion  the segment from the camera to each subject's head clear of the solid prop boxes (Bodies.prop_boxes of every
#              visible prop, minus the test's not_solid ids, the NOT_SOLID_KINDS and the glow / haze / beam / cable meshes)
#              in >= 90 % of the samples. A "burst" prop stops counting after its story var: a seek fires no FX, so the
#              stack that bursts in the game would still stand in the test.
#   camera     never inside a solid prop box grown by the camera's near plane + 0.02 m.
#   dutch      a dutch shot rolls at least 80 % of its "roll".
# check() returns the failures (one line each) and prints one summary line per shot.
extends RefCounted

const Bodies = preload("res://tests/support/cine_bodies.gd")

const N: int = 16
const CUT_SKIP: float = 2.0 / 60.0
const KEEP: float = 0.9
const BLOCK_R: float = 0.18
const HELPERS: Array[String] = ["two_shot", "ots", "low_hero", "dutch", "push_in"]
const NOT_SOLID_KINDS: Array[String] = ["bridge_deck", "fire", "monitor_wall", "gallery_hall"]
const NOT_SOLID_MESH: Array[String] = ["Haze", "Glow", "Light", "Beam", "Smoke", "Dust", "Spark", "Fire", "Flame", "Cable", "Lamp"]


## The subjects of shot `sh` (see the header); `pf` must be seeked to the shot's middle for the default.
static func subjects(sh: Dictionary, pf: CinePlayer) -> Array[String]:
	var pr: Dictionary = sh["params"]
	var out: Array[String] = []
	if pr.has("subj"):
		for s: Variant in pr["subj"]:
			out.append(String(s))
		return out
	match String(sh["rig"]):
		"two_shot":
			return [String(pr["a"]), String(pr["b"])]
		"ots":
			return [String(pr["at"])]
		"low_hero", "dutch", "push_in":
			return [String(pr["actor"])]
	var best: float = INF
	var who: String = ""
	for id: String in pf.actors.keys():
		var a: CineActor = pf.actors[id]
		if not a.is_visible_in_tree():
			continue
		var uv: Vector2 = CameraFraming.screen_uv(pf.camera, CameraFraming.subject_points(a)[0])
		if uv.x < 0.0:
			continue
		var d: float = uv.distance_to(Vector2(0.5, 0.5))
		if d < best:
			best = d
			who = id
	if who != "":
		out.append(who)
	return out


## Solid prop boxes [[name, xf, half]] at the player's current time.
static func solid_boxes(tl: CineTimeline, pf: CinePlayer, not_solid: Array, burst: Dictionary) -> Array:
	var out: Array = []
	for pr: Dictionary in tl.props:
		var id: String = String(pr["id"])
		if id in not_solid or String(pr["kind"]) in NOT_SOLID_KINDS or not pf.prop_nodes.has(id):
			continue
		if burst.has(id) and pf.s > float(tl.get(String(burst[id]))) + 0.001:
			continue
		var n: Node3D = pf.prop_nodes[id]
		if not n.is_visible_in_tree():
			continue
		for b: Array in Bodies.prop_boxes(n):
			if NOT_SOLID_MESH.any(func(k: String) -> bool: return String(b[0]).contains(k)):
				continue
			out.append([id + "." + String(b[0]), b[1], b[2]])
	return out


## Segment a -> b against an oriented box: the entry fraction (0..1), or -1 when it misses.
static func seg_box(a: Vector3, b: Vector3, xf: Transform3D, h: Vector3) -> float:
	var inv: Transform3D = xf.affine_inverse()
	var la: Vector3 = inv * a
	var d: Vector3 = inv * b - la
	var t0: float = 0.0
	var t1: float = 1.0
	for ax: int in 3:
		if absf(d[ax]) < 1e-9:
			if la[ax] < -h[ax] or la[ax] > h[ax]:
				return -1.0
			continue
		var u0: float = (-h[ax] - la[ax]) / d[ax]
		var u1: float = (h[ax] - la[ax]) / d[ax]
		t0 = maxf(t0, minf(u0, u1))
		t1 = minf(t1, maxf(u0, u1))
		if t0 > t1:
			return -1.0
	return t0


static func inside(p: Vector3, xf: Transform3D, h: Vector3, m: float) -> bool:
	var q: Vector3 = xf.affine_inverse() * p
	return absf(q.x) <= h.x + m and absf(q.y) <= h.y + m and absf(q.z) <= h.z + m


## Another actor in front of the subject's face (within BLOCK_R of the camera -> face segment).
static func blocker(pf: CinePlayer, cam_p: Vector3, face: Vector3, subj: String) -> String:
	var seg: Vector3 = face - cam_p
	var len2: float = seg.length_squared()
	for id: String in pf.actors.keys():
		if id == subj:
			continue
		var a: CineActor = pf.actors[id]
		if not a.is_visible_in_tree():
			continue
		var pts: PackedVector3Array = CameraFraming.subject_points(a)
		for k: int in mini(2, pts.size()):
			var t: float = clampf((pts[k] - cam_p).dot(seg) / maxf(len2, 1e-6), 0.0, 1.0)
			if t > 0.05 and t < 0.92 and (cam_p + seg * t).distance_to(pts[k]) < BLOCK_R:
				return id
	return ""


## Every shot of tl on the started, manual player pf (lb: one letterbox bar, 0..0.5). Returns the failures.
static func check(tl: CineTimeline, pf: CinePlayer, lb: float, not_solid: Array, burst: Dictionary, label: String) -> PackedStringArray:
	var fails := PackedStringArray()
	for i: int in tl.shots.size():
		var sh: Dictionary = tl.shots[i]
		var id: String = String(sh["id"])
		var rig: String = String(sh["rig"])
		var pr: Dictionary = sh["params"]
		var r0: float = pf._shot_r[i]
		var r1: float = pf._shot_r[i + 1] if i + 1 < tl.shots.size() else tl.length
		var ex: Array = pr.get("exit_ok", [])
		pf.seek((r0 + r1) * 0.5)
		var subj: Array[String] = subjects(sh, pf)
		if subj.is_empty():
			fails.append("%s %s %s (%s): no actor in the frame" % [label, tl.slot, id, rig])
			continue
		var good: Dictionary = {}
		var lost: Dictionary = {}
		var out_first: Dictionary = {}
		var counted: int = 0
		var cam_in: String = ""
		var roll_min: float = INF
		for s: String in subj:
			good[s] = 0
			lost[s] = ""
			out_first[s] = ""
		var a0: float = r0 + CUT_SKIP
		var a1: float = maxf(r1 - CUT_SKIP, a0)
		for k: int in N:
			var rr: float = lerpf(a0, a1, (float(k) + 0.5) / float(N))
			pf.seek(rr)
			var cam: Camera3D = pf.camera
			var cp: Vector3 = cam.global_position
			var boxes: Array = solid_boxes(tl, pf, not_solid, burst)
			for bx: Array in boxes:
				if cam_in == "" and inside(cp, bx[1], bx[2], cam.near + 0.02):
					cam_in = "@%.2f in %s" % [rr, String(bx[0])]
			if rig == "dutch":
				roll_min = minf(roll_min, absf(rad_to_deg(asin(clampf(cam.global_basis.x.y, -1.0, 1.0)))))
			if ex.size() == 2 and rr >= float(ex[0]) and rr <= float(ex[1]):
				continue
			counted += 1
			for s: String in subj:
				var a: CineActor = pf.actors.get(s)
				if a == null or not a.is_visible_in_tree():
					if lost[s] == "":
						lost[s] = "@%.2f hidden" % rr
					continue
				var pts: PackedVector3Array = CameraFraming.subject_points(a)
				var why: String = ""
				if not CameraFraming.in_safe(cam, pts[0], 0.0, lb):
					why = "head out of frame %s" % str(CameraFraming.screen_uv(cam, pts[0]).snapped(Vector2.ONE * 0.01))
					if out_first[s] == "":
						out_first[s] = "@%.2f %s" % [rr, why]
					if lost[s] == "":
						lost[s] = "@%.2f %s" % [rr, why]
					continue
				for j: int in 2:
					if why == "" and not CameraFraming.in_safe(cam, pts[j], CameraRules.SAFE_MARGIN, lb):
						why = "%s outside the safe area %s" % [["head", "chest"][j], str(CameraFraming.screen_uv(cam, pts[j]).snapped(Vector2.ONE * 0.01))]
				if why == "":
					for bx: Array in boxes:
						var t: float = seg_box(cp, pts[0], bx[1], bx[2])
						if t >= 0.0 and t < 0.97:
							why = "head behind %s" % String(bx[0])
							break
				if why == "":
					var bl: String = blocker(pf, cp, pts[0], s)
					if bl != "":
						why = "%s in front of the face" % bl
				if why == "":
					good[s] = int(good[s]) + 1
				elif lost[s] == "":
					lost[s] = "@%.2f %s" % [rr, why]
		var row := PackedStringArray()
		for s: String in subj:
			var frac: float = float(good[s]) / maxf(float(counted), 1.0)
			row.append("%s %d/%d" % [s, int(good[s]), counted])
			if out_first[s] != "":
				fails.append("%s %s %s (%s): %s's head leaves the frame (first %s)" % [label, tl.slot, id, rig, s, String(out_first[s])])
			if counted > 0 and frac < KEEP:
				fails.append("%s %s %s (%s) %.2f-%.2f: %s framed and clear in %d/%d samples (< 90 %%), first %s" % [label, tl.slot, id, rig,
					r0, r1, s, int(good[s]), counted, String(lost[s])])
		if cam_in != "":
			fails.append("%s %s %s (%s): the camera is inside a prop %s" % [label, tl.slot, id, rig, cam_in])
		if rig == "dutch":
			var want: float = absf(float(pr.get("roll", 14.0)))
			if roll_min < want * 0.8:
				fails.append("%s %s %s: dutch roll %.1f (want ~%.1f)" % [label, tl.slot, id, roll_min, want])
		print("  frame  %-6s %-4s %-9s %5.2f-%5.2f  %s%s" % [label, id, rig, r0, r1, ", ".join(row), ("  CAMERA " + cam_in) if cam_in != "" else ""])
	return fails


## Emoji or pictographs in a line (the "no emoji in UI text" rule): symbols, dingbats, pictographs, variation selectors.
static func has_emoji(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c >= 0x1F000 or (c >= 0x2600 and c <= 0x27BF) or (c >= 0x2B00 and c <= 0x2BFF) or c == 0xFE0F or c == 0x200D:
			return true
	return false
