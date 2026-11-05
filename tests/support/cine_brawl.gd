# File: res://tests/support/cine_brawl.gd
# Data-driven headless test of a hand-choreographed fight cinematic (plan 2026-11-05-w6-fights: seg_d3_boss, seg_d4_brawl,
# seg_d5_boss, seg_d7_phase2; modelled on tests/test_cine_d4_brawl.gd and tests/support/cine_fight.gd, which keeps
# seg_d2_boss on CineFightC). A test extends this script and returns its fight from _conf():
#   slot, length                      the exact real length
#   ramps {name: real}                every slow-motion ramp on its real time (within 0.5 ms); freezes = how many freeze
#   finisher, swell_end, tail         the finisher ramp's name, its swell end (real) and the 1x tail after it
#   taken {name: real}                hits the protagonist takes (or blocks) at normal speed, each with a camera punch-in
#   touch {name: real}                other contacts measured without a speed rule
#   strikes {name: [att, part, tgt]}  part: fists | knees | feet | head | held:<Prefix> (a held prop's node) |
#                                     prop:<id> (a scene prop); tgt: an actor, or "<actor>:held:<Prefix>" (a prop it holds)
#   slams [[actor, [props], r0, r1]]  the actor's body reaches the props' boxes inside the real window
#   lying [[actor, real]]             on the floor (hips < 0.45 m, lowest bone > -0.08 m)
#   crash [story var, prop]           the crash (a "crate" fx on the prop) sits inside the finisher swell
#   hit_vars [story vars]             more hit moments for the penetration window; pen_skip [[actor, prop, r0, r1]]
#   not_solid [prop ids]; moving [prop ids] (boxes re-read every frame); burst {prop: story var} (not solid after it)
#   held [[actor, Prefix, real, bool]] a prop in an actor's hands / on it or not; shown [[prop, real, bool]] prop visibility
#   gone [[actor, real, bool]]        actor visibility; keep [prop ids] that drop_set must keep
#   stages [slots]                    FreeRoam stage checks (as the old harnesses); checks: Callable(test, player) gags
# Every check of the old harnesses stays: valid, beat sheet in sync, plays length * 60 steps of 1/60 inside the 14 x 10 box,
# frame cost < 8 ms, surface gaps at every contact <= 0.04 m on Mixamo and <= 0.15 m on the fallbacks (never sinking more
# than 0.06 m, props 0.10 m), lying bodies, no hips skating (<= 0.08 m / frame) through lie / sit transitions, bodies never
# sink into each other or solid props (<= 0.03 m, near a hit <= 0.06 m limb / 0.04 m core), feet never 3 cm under the
# floor, on every tier (cap 0 Mixamo when present, 1 UAL, 2 native, 3 code). New: every Q1 helper shot frames its subjects'
# head, chest and hips inside the letterboxed 8 % safe area at its start, middle and end with no actor in front of a
# subject's face (CameraFraming.report, as tests/test_d7_cines.gd), and every other shot has an actor in the frame.
# Env: CINE_NO_MIXAMO=1, CINE_FAST=1 (no penetration sweep), CINE_NO_FREEROAM=1. Players pass {"music": false}.
# Tuning aids: CINE_DBG=1 prints the geometry of held-prop / scene-prop strikes; CINE_TR="a,b,r0,r1" traces two actors.
extends SceneTree

const Bodies = preload("res://tests/support/cine_bodies.gd")

const GAP_MIXAMO: float = 0.04
const GAP_OTHER: float = 0.15
const HALF: Vector2 = Vector2(7.0, 5.0)
const HIPS_STEP_MAX: float = 0.08
const LIE_MOVES: Array[String] = ["lie", "lie_flat", "get_up", "slumped", "get_up_sit"]
const PEN_MAX: float = 0.03
const PEN_HIT_LIMB: float = 0.06
const PEN_HIT_CORE: float = 0.04
const PEN_WINDOW: float = 0.08
const FOOT_FLOOR: float = -0.03
const NOT_SOLID_KINDS: Array[String] = ["bridge_deck", "fire", "monitor_wall", "gallery_hall"]
const ROOM_SOLID: Array[String] = ["BackWall", "SideWall"]
const HELPERS: Array[String] = ["two_shot", "ots", "low_hero", "dutch", "push_in"]
const BLOCK_R: float = 0.18
## Slots whose explicit point lies on the campus lawn (as the old harnesses: the baked spot, this far off, +2 m).
const GRASS_MOVED: Dictionary = {"cine_d1_intro": 20.0, "cine_d4": 22.0, "cine_d4_intro": 24.0, "cine_d4_stare": 24.0,
	"seg_d4_brawl": 86.9, "end_c": 86.9}
var fails: Array[String] = []
var phase: int = -1
var frames: int = 0
var world: Node3D
var p: CinePlayer
var tl: CineTimeline
var fr: Node
var ended: Array = []
var conf: Dictionary = {}


func _conf() -> Dictionary:
	return {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _hold_of(a: CineActor, prefix: String) -> Dictionary:
	for h: Dictionary in a.holds:
		if String((h["node"] as Node3D).name).begins_with(prefix) and (h["att"] as Node3D).visible:
			return h
	return {}


func _held(a: CineActor, prefix: String) -> Node3D:
	var h: Dictionary = _hold_of(a, prefix)
	return h["node"] if not h.is_empty() else null


## World transform of a held prop from the bones as they stand now (BoneAttachment3D globals update late after a seek).
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
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var ab: AABB = mi.mesh.get_aabb()
		var gx: Transform3D = nx * (inv * mi.global_transform)
		out.append([String(mi.name), Transform3D(gx.basis.orthonormalized(), gx * ab.get_center()), ab.size * gx.basis.get_scale() * 0.5])
	return out


## Striking spheres of a body part [[name, centre, r]] (fists from Bodies; knees, feet and the head here).
static func _spheres(a: CineActor, part: String) -> Array:
	match part:
		"fists":
			return Bodies.fists(a)
		"knees":
			return [["knee.L", a.bone_world("LowerLeg.L"), 0.07], ["knee.R", a.bone_world("LowerLeg.R"), 0.07]]
		"feet":
			return [["foot.L", a.bone_world("Foot.L"), 0.07], ["foot.R", a.bone_world("Foot.R"), 0.07]]
		"head":
			var caps: Array = Bodies.capsules(a)
			var hd: Array = caps[caps.size() - 1]
			return [["head", hd[1], Bodies.HEAD_R]]
	return []


func _prop_boxes(pl: CinePlayer, pk: String) -> Array:
	var bx: Array = Bodies.prop_boxes(pl.prop_nodes[pk])
	var rows: Array = tl.props.filter(func(pr: Dictionary) -> bool: return String(pr["id"]) == pk)
	if not rows.is_empty() and String(rows[0]["kind"]) == "server_room":
		bx = bx.filter(func(b: Array) -> bool: return ROOM_SOLID.any(func(k: String) -> bool: return String(b[0]).begins_with(k)))
	return bx


## Surface gap of a strike: {"g", "from", "to"}.
func _strike_gap(pl: CinePlayer, who: String, part: String, target: String) -> Dictionary:
	var a: CineActor = pl.actors[who]
	var tparts: PackedStringArray = target.split(":")
	var t_boxes: Array = []
	var t_caps: Array = []
	if tparts.size() == 3 and tparts[1] == "held":
		var th: Dictionary = _hold_of(pl.actors[tparts[0]], tparts[2])
		if th.is_empty():
			return {"g": INF, "from": "?", "to": "no %s held by %s" % [tparts[2], tparts[0]]}
		t_boxes = _held_boxes(pl.actors[tparts[0]], th)
	else:
		t_caps = Bodies.capsules(pl.actors[target])
	if part in ["fists", "knees", "feet", "head"]:
		var sp: Array = _spheres(a, part)
		if t_boxes.is_empty():
			return Bodies.gap_spheres(sp, t_caps)
		var as_caps: Array = sp.map(func(s: Array) -> Array: return [s[0], s[1], s[1], s[2]])
		return Bodies.gap_boxes(as_caps, t_boxes)
	var boxes: Array = []
	if part.begins_with("held:"):
		var h: Dictionary = _hold_of(a, part.substr(5))
		if h.is_empty():
			return {"g": INF, "from": "no %s in hand" % part.substr(5), "to": "?"}
		boxes = _held_boxes(a, h)
	elif part.begins_with("prop:"):
		boxes = Bodies.prop_boxes(pl.prop_nodes[part.substr(5)])
	if not t_boxes.is_empty():
		# a prop on a held prop (seg_d5_boss: the staff on the katana): the striking boxes as capsules on their long axes
		var r2: Dictionary = Bodies.gap_boxes(_box_caps(boxes), t_boxes)
		return {"g": r2["g"], "from": "%s %s" % [part, r2["from"]], "to": r2["to"]}
	var r: Dictionary = Bodies.gap_boxes(t_caps, boxes)
	return {"g": r["g"], "from": "%s %s" % [part, r["to"]], "to": r["from"]}


## Boxes [[name, xf, half]] as capsules [[name, a, b, r]] along each box's longest axis (r = its second half size).
static func _box_caps(boxes: Array) -> Array:
	var out: Array = []
	for bx: Array in boxes:
		var xf: Transform3D = bx[1]
		var h: Vector3 = bx[2]
		var ax: int = 0 if h.x >= h.y and h.x >= h.z else (1 if h.y >= h.z else 2)
		var hs: Array = [h.x, h.y, h.z]
		var r: float = maxf(float(hs[(ax + 1) % 3]), float(hs[(ax + 2) % 3]))
		var dv: Vector3 = xf.basis[ax].normalized() * maxf(float(hs[ax]) - r, 0.0)
		out.append([String(bx[0]), xf.origin - dv, xf.origin + dv, r])
	return out


func _when(name: String) -> float:
	for k: String in ["ramps", "taken", "touch"]:
		if (conf.get(k, {}) as Dictionary).has(name):
			return float(conf[k][name])
	return -1.0


func _contacts(pl: CinePlayer, label: String) -> void:
	var lim: float = GAP_MIXAMO if label == "mixamo" else GAP_OTHER
	var st_all: Dictionary = conf.get("strikes", {})
	for nm: String in st_all.keys():
		var at_r: float = _when(nm)
		_check(at_r >= 0.0, "strike %s has a time" % nm)
		pl.seek(at_r)
		var st: Array = st_all[nm]
		var res: Dictionary = _strike_gap(pl, String(st[0]), String(st[1]), String(st[2]))
		var mv: Dictionary = (pl.actors[String(st[0])] as CineActor).active_move(pl.s)
		if OS.get_environment("CINE_DBG") != "" and String(st[2]).contains(":held:"):
			var tp: PackedStringArray = String(st[2]).split(":")
			var ta: CineActor = pl.actors[tp[0]]
			var txf: Transform3D = _held_xf(ta, _hold_of(ta, tp[2]))
			var sa: CineActor = pl.actors[String(st[0])]
			print("  DBG %s tray at %s normal %s; fists %s; holder yaw %.1f" % [nm, str(txf.origin), str(txf.basis.y.normalized()),
				str(_spheres(sa, "fists").map(func(q: Array) -> Vector3: return q[1])), rad_to_deg(ta.rotation.y)])
		if OS.get_environment("CINE_DBG") != "" and String(st[1]).begins_with("prop:"):
			var pn: Node3D = pl.prop_nodes[String(st[1]).substr(5)]
			print("  DBG %s prop at %s, %s head at %s" % [nm, str(pn.global_position), st[2], str((pl.actors[String(st[2])] as CineActor).bone_world("Head"))])
		print("  gap     %-6s %-4s %+.3f m  %s %s -> %s %s  (%s %s)" % [label, nm, float(res["g"]), st[0], res["from"], st[2],
			res["to"], String(mv.get("move", "?")), String((mv.get("res", {}) as Dictionary).get("tier", "?"))])
		_check(float(res["g"]) <= lim, "%s: %s surface gap %.3f m <= %.2f (%s %s -> %s %s)" % [label, nm, float(res["g"]), lim,
			st[0], res["from"], st[2], res["to"]])
		var body: bool = String(st[1]) in ["fists", "knees", "feet", "head"] and not String(st[2]).contains(":held:")
		var deep: float = PEN_HIT_LIMB if body else PEN_HIT_LIMB + 0.04
		_check(float(res["g"]) >= -deep, "%s: %s strike sinks %.3f m into the target (> %.2f)" % [label, nm, -float(res["g"]), deep])
	for sl: Array in conf.get("slams", []):
		var boxes: Array = []
		for pk: String in sl[1]:
			boxes.append_array(_prop_boxes(pl, pk))
		var best: float = INF
		var bat: float = 0.0
		var r: float = float(sl[2])
		while r <= float(sl[3]):
			pl.seek(r)
			var g2: float = float(Bodies.gap_boxes(Bodies.capsules(pl.actors[String(sl[0])]), boxes)["g"])
			if g2 < best:
				best = g2
				bat = r
			r += 1.0 / 60.0
		print("  gap     %-6s %s into %s %+.3f m at r %.2f" % [label, sl[0], str(sl[1]), best, bat])
		_check(best <= lim, "%s: %s reaches %s, gap %.3f m <= %.2f" % [label, sl[0], str(sl[1]), best, lim])


func _lying(pl: CinePlayer, label: String) -> void:
	for e: Array in conf.get("lying", []):
		pl.seek(float(e[1]))
		var a: CineActor = pl.actors[String(e[0])]
		var hy: float = a.bone_world("Hips").y
		var lo: float = INF
		for b: String in ["Head", "Hips", "Chest", "Foot.L", "Foot.R", "Wrist.L", "Wrist.R"]:
			lo = minf(lo, a.bone_world(b).y)
		print("  lying  %-6s %s r %.1f: hips %.2f m, lowest bone %.2f m" % [label, String(e[0]), float(e[1]), hy, lo])
		_check(hy < 0.45 and lo > -0.08, "%s: %s on the floor at r %.1f (hips %.2f, lowest %.2f)" % [label, String(e[0]), float(e[1]), hy, lo])


func _lie_transitions() -> Array:
	var by_actor: Dictionary = {}
	for c: Dictionary in tl.cues:
		if c["type"] != "move" and c["type"] != "strike":
			continue
		var st: float = float(c["s"])
		if c["type"] == "strike":
			var dur: float = float((c["opts"] as Dictionary).get("dur", CineMoves.MOVES[c["move"]]["dur"]))
			st = tl.story_time(c["at"]) - float(CineMoves.MOVES[c["move"]]["hit_u"]) * dur
		if not by_actor.has(c["actor"]):
			by_actor[c["actor"]] = []
		(by_actor[c["actor"]] as Array).append([st, String(c["move"])])
	var out: Array = []
	for id: String in by_actor.keys():
		var arr: Array = by_actor[id]
		arr.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for i: int in arr.size():
			var prev: String = arr[i - 1][1] if i > 0 else ""
			if String(arr[i][1]) in LIE_MOVES or prev in LIE_MOVES:
				out.append([id, float(arr[i][0]), "%s->%s" % [prev, String(arr[i][1])]])
	return out


func _skate(pl: CinePlayer, label: String) -> void:
	var worst: float = 0.0
	var where: String = ""
	for t: Array in _lie_transitions():
		var a: CineActor = pl.actors[String(t[0])]
		var rt: float = tl.clock.real_at(float(t[1]))
		var r: float = maxf(rt - 0.3, 0.0)
		var prev: Variant = null
		while r <= minf(rt + 0.6, tl.length):
			pl.seek(r)
			var h: Vector3 = a.to_local(a.bone_world("Hips"))
			if prev != null and h.distance_to(prev) > worst:
				worst = h.distance_to(prev)
				where = "%s %s at r %.2f" % [String(t[0]), String(t[2]), r]
			prev = h
			r += 1.0 / 60.0
	print("  skate  %-6s max hips step %.3f m/frame (%s)" % [label, worst, where])
	_check(worst <= HIPS_STEP_MAX, "%s: hips step %.3f m/frame <= %.2f across lie / sit transitions (%s)" % [label, worst, HIPS_STEP_MAX, where])


func _solid_props() -> Array[String]:
	var out: Array[String] = []
	for pr: Dictionary in tl.props:
		var id: String = String(pr["id"])
		if id in conf.get("not_solid", []) or String(pr["kind"]) in NOT_SOLID_KINDS:
			continue
		out.append(id)
	return out


func _penetration(pl: CinePlayer, label: String) -> void:
	var hits: Array[float] = []
	for rw: Dictionary in tl.clock.ramps:
		hits.append(float(rw["s"]))
	for k: String in ["taken", "touch"]:
		for nm: String in (conf.get(k, {}) as Dictionary).keys():
			hits.append(tl.clock.story_at(float(conf[k][nm])))
	for v: String in conf.get("hit_vars", []):
		hits.append(float(tl.get(v)))
	var burst: Dictionary = {}
	for pk: String in (conf.get("burst", {}) as Dictionary).keys():
		burst[pk] = float(tl.get(String(conf["burst"][pk])))
	var moving: Array = conf.get("moving", [])
	var boxes: Dictionary = {}
	var landed: Dictionary = {}   # props flying along a path count once landed
	for pk: String in _solid_props():
		if pl.prop_nodes.has(pk):
			boxes[pk] = _prop_boxes(pl, pk)
			var po: Dictionary = tl.props.filter(func(pr: Dictionary) -> bool: return String(pr["id"]) == pk)[0]["opts"]
			var pth: Array = po.get("path", [])
			if pth.size() >= 2 and float(pth[pth.size() - 1][0]) > 1.5 and not pk in moving:
				landed[pk] = float(pth[pth.size() - 1][0])
	var skips: Array = conf.get("pen_skip", [])
	var ids: Array = pl.actors.keys()
	var worst: Dictionary = {"d": -1.0, "what": "-"}
	var fails: Dictionary = {}   # the first failure of each actor pair / actor in prop / foot
	var f: int = 0
	while f <= int(round(tl.length * 60.0)):
		var r: float = f / 60.0
		pl.seek(r)
		var near: bool = hits.any(func(h: float) -> bool: return absf(pl.s - h) <= PEN_WINDOW)
		var caps: Dictionary = {}
		for id: String in ids:
			caps[id] = Bodies.capsules(pl.actors[id])
		for i: int in ids.size():
			var a: CineActor = pl.actors[ids[i]]
			if not a.visible:
				continue
			for j: int in range(i + 1, ids.size()):
				var b: CineActor = pl.actors[ids[j]]
				if not b.visible or a.position.distance_to(b.position) > 2.6:
					continue
				var res: Dictionary = Bodies.actor_pair(caps[ids[i]], caps[ids[j]])
				var core: bool = Bodies.is_core(res["pa"]) and Bodies.is_core(res["pb"])
				var lim: float = (PEN_HIT_CORE if core else PEN_HIT_LIMB) if near else PEN_MAX
				var what: String = "%s %s / %s %s at r %.2f%s" % [ids[i], res["pa"], ids[j], res["pb"], r, " (hit)" if near else ""]
				if float(res["d"]) > float(worst["d"]):
					worst = {"d": res["d"], "what": what}
				if float(res["d"]) > lim and not fails.has(ids[i] + "/" + ids[j]):
					fails[ids[i] + "/" + ids[j]] = "%.3f m > %.2f: %s" % [res["d"], lim, what]
			for pk: String in boxes.keys():
				if burst.has(pk) and pl.s > float(burst[pk]) + 0.001:
					continue
				if not (pl.prop_nodes[pk] as Node3D).is_visible_in_tree() or pl.s < float(landed.get(pk, -1.0)):
					continue
				if skips.any(func(sk: Array) -> bool: return String(sk[0]) == ids[i] and String(sk[1]) == pk and r >= float(sk[2]) and r <= float(sk[3])):
					continue
				if pk in moving:
					boxes[pk] = _prop_boxes(pl, pk)
				var rb: Dictionary = Bodies.actor_boxes(caps[ids[i]], boxes[pk])
				var limb: float = PEN_HIT_LIMB if near else PEN_MAX
				if float(rb["d"]) > limb and not fails.has(ids[i] + "@" + pk):
					fails[ids[i] + "@" + pk] = "%.3f m > %.2f: %s %s in the %s (%s) at r %.2f" % [rb["d"], limb, ids[i], rb["part"], pk, rb["box"], r]
				if float(rb["d"]) > float(worst["d"]):
					worst = {"d": rb["d"], "what": "%s %s in the %s at r %.2f" % [ids[i], rb["part"], pk, r]}
			for fb: String in ["Foot.L", "Foot.R"]:
				var fy: float = a.bone_world(fb).y
				if fy < FOOT_FLOOR and not fails.has(ids[i] + "_floor"):
					fails[ids[i] + "_floor"] = "%s %s %.3f m under the floor at r %.2f" % [ids[i], fb, -fy, r]
		f += 1
	print("  bodies %-6s worst penetration %.3f m (%s)" % [label, maxf(float(worst["d"]), 0.0), worst["what"]])
	_check(fails.is_empty(), "%s: bodies never sink in" % label)
	for k: String in fails.keys():
		print("    sinks: %s" % fails[k])


## Held props, prop visibility, actor visibility, drop_set, then the fight's own gags.
func _states(pl: CinePlayer) -> void:
	for e: Array in conf.get("held", []):
		pl.seek(float(e[2]))
		var n: Node3D = _held(pl.actors[String(e[0])], String(e[1]))
		var has: bool = n != null and n.is_visible_in_tree()
		_check(has == bool(e[3]), "%s %s %s at r %.2f" % [String(e[0]), "has" if bool(e[3]) else "no longer has", String(e[1]), float(e[2])])
	for e: Array in conf.get("shown", []):
		pl.seek(float(e[1]))
		var vis: bool = (pl.prop_nodes[String(e[0])] as Node3D).is_visible_in_tree()
		_check(vis == bool(e[2]), "prop %s %s at r %.2f" % [String(e[0]), "visible" if bool(e[2]) else "hidden", float(e[1])])
	for e: Array in conf.get("gone", []):
		pl.seek(float(e[1]))
		var vis2: bool = (pl.actors[String(e[0])] as CineActor).visible
		_check(vis2 == bool(e[2]), "%s %s at r %.2f" % [String(e[0]), "in the scene" if bool(e[2]) else "gone", float(e[1])])
	var pd := CinePlayer.new()
	world.add_child(pd)
	pd.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false, "drop_set": true})
	var sets: Array = tl.props.filter(func(pr: Dictionary) -> bool: return bool((pr["opts"] as Dictionary).get("set", false)))
	_check(sets.all(func(pr: Dictionary) -> bool: return not pd.prop_nodes.has(String(pr["id"])))
		and (conf.get("keep", []) as Array).all(func(k: String) -> bool: return pd.prop_nodes.has(k)),
		"drop_set leaves out the carried set dressing and keeps %s" % str(conf.get("keep", [])))
	pd.queue_free()
	if conf.has("checks"):
		(conf["checks"] as Callable).call(self, pl)


## Q1 helper shots framed (start, middle, end), every other shot with an actor in the frame (tests/test_d7_cines.gd).
func _framing() -> void:
	CineMoves.max_tier = 1
	var pf := CinePlayer.new()
	world.add_child(pf)
	pf.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false, "drop_set": true})
	pf.start()
	await process_frame
	var vs: Vector2 = root.get_visible_rect().size
	var lb: float = (pf.overlay.bar_height_full() / vs.y) if tl.letterbox else 0.0
	var helpers: int = 0
	for i: int in tl.shots.size():
		var sh: Dictionary = tl.shots[i]
		var rig: String = String(sh["rig"])
		var r0: float = pf._shot_r[i]
		var r1: float = pf._shot_r[i + 1] if i + 1 < tl.shots.size() else tl.length
		var pr: Dictionary = sh["params"]
		if not (rig in HELPERS):
			pf.seek((r0 + r1) * 0.5)
			var seen: String = ""
			for id: String in pf.actors.keys():
				var a0: CineActor = pf.actors[id]
				if not a0.is_visible_in_tree():
					continue
				for q: Vector3 in CameraFraming.subject_points(a0):
					if seen == "" and CameraFraming.in_safe(pf.camera, q, 0.0, lb):
						seen = id
			_check(seen != "", "%s %s (%s) @%.2f: an actor is in the frame" % [tl.slot, String(sh["id"]), rig, (r0 + r1) * 0.5])
			continue
		helpers += 1
		var subj: Array[String] = []
		match rig:
			"two_shot":
				subj = [String(pr["a"]), String(pr["b"])]
			"ots":
				subj = [String(pr["at"])]
			_:
				subj = [String(pr["actor"])]
		for rr: float in [r0 + minf(0.08, (r1 - r0) * 0.2), (r0 + r1) * 0.5, r1 - minf(0.08, (r1 - r0) * 0.2)]:
			pf.seek(rr)
			var cam: Camera3D = pf.camera
			for id: String in subj:
				var a: CineActor = pf.actors.get(id)
				if a == null or not a.is_visible_in_tree():
					_check(false, "%s %s @%.2f: subject %s is hidden" % [tl.slot, String(sh["id"]), rr, id])
					continue
				var pts: PackedVector3Array = CameraFraming.subject_points(a)
				var rep: Dictionary = CameraFraming.report(cam, pts, world.get_world_3d().direct_space_state, [], CameraRules.SAFE_MARGIN, lb)
				_check(bool(rep["ok"]), "%s %s (%s) @%.2f: %s %s" % [tl.slot, String(sh["id"]), rig, rr, id, CameraFraming.describe(cam, pts, rep)])
				var blocker: String = _blocked(pf, cam.global_position, pts[0], id)
				_check(blocker == "", "%s %s (%s) @%.2f: %s stands in front of %s's face" % [tl.slot, String(sh["id"]), rig, rr, blocker, id])
			if rig == "dutch":
				var want: float = float(pr.get("roll", 14.0))
				var got: float = rad_to_deg(asin(clampf(cam.global_basis.x.y, -1.0, 1.0)))
				_check(absf(got) >= absf(want) * 0.8 and signf(got) == signf(want), "%s %s: dutch roll %.1f (want ~%.1f)" % [tl.slot, String(sh["id"]), got, want])
	print("  framing: %d shots, %d Q1 helper shots checked" % [tl.shots.size(), helpers])
	_check(helpers >= 4, "the fight uses the Q1 shot helpers (%d)" % helpers)
	pf.queue_free()


func _blocked(pl: CinePlayer, cam_p: Vector3, face: Vector3, subj: String) -> String:
	var seg: Vector3 = face - cam_p
	var len2: float = seg.length_squared()
	for id: String in pl.actors.keys():
		if id == subj:
			continue
		var a: CineActor = pl.actors[id]
		if not a.is_visible_in_tree():
			continue
		var pts: PackedVector3Array = CameraFraming.subject_points(a)
		for k: int in mini(2, pts.size()):
			var t: float = clampf((pts[k] - cam_p).dot(seg) / maxf(len2, 1e-6), 0.0, 1.0)
			if t > 0.05 and t < 0.92 and (cam_p + seg * t).distance_to(pts[k]) < BLOCK_R:
				return id
	return ""


func _initialize() -> void:
	conf = _conf()
	print("--- TEST CINE %s ---" % String(conf["slot"]))
	if OS.get_environment("CINE_NO_MIXAMO") == "1":
		CineRetarget.disabled = PackedStringArray(["mixamo"])
		print("  CINE_NO_MIXAMO=1: mixamo source disabled")
	tl = CineTimeline.load_slot(String(conf["slot"]))
	_check(tl != null and not tl is CineFightC, "timeline loads (its own choreography, not the CineFightC template)")
	if tl == null:
		_end()
		return
	var errs: PackedStringArray = tl.validate()
	_check(errs.is_empty(), "valid: %s" % str(errs))
	var ln: float = float(conf["length"])
	_check(is_equal_approx(tl.length, ln) and absf(tl.clock.real_duration() - ln) < 0.0005, "exactly %.3f s (%.5f)" % [ln, tl.clock.real_duration()])
	var ramps: Dictionary = conf["ramps"]
	var freezes: int = 0
	for row: Dictionary in tl.clock.ramps:
		freezes += 1 if float(row["freeze"]) > 0.0 else 0
	_check(tl.clock.ramps.size() == ramps.size() and freezes == int(conf.get("freezes", ramps.size())),
		"%d slow-motion ramps, %d freezes (%d, %d)" % [ramps.size(), int(conf.get("freezes", ramps.size())), tl.clock.ramps.size(), freezes])
	for nm: String in ramps.keys():
		var rh: float = float(tl.clock.ramp(nm).get("r_hit", -1.0))
		_check(absf(rh - float(ramps[nm])) < 0.0005, "%s real impact %.4f on %.3f" % [nm, rh, float(ramps[nm])])
	var fin: Dictionary = tl.clock.ramp(String(conf["finisher"]))
	var sw: float = float(conf["swell_end"])
	_check(String(fin.get("preset", "")) == "finisher" and absf(float(fin.get("r1", 0.0)) - sw) < 0.0005,
		"finisher swell ends at real %.3f (%.4f)" % [sw, float(fin.get("r1", 0.0))])
	_check(float(fin.get("r1", 0.0)) - float(fin.get("r_hit", 0.0)) <= 5.0, "the finisher swell is short (%.2f s <= 5)" % (float(fin.get("r1", 0.0)) - float(fin.get("r_hit", 0.0))))
	var tail: float = ln - float(tl.clock.ramps[tl.clock.ramps.size() - 1]["r1"])
	_check(absf(tail - float(conf["tail"])) < 0.0005, "normal-speed tail %.4f s = %.3f" % [tail, float(conf["tail"])])
	if conf.has("crash"):
		var cr: Array = conf["crash"]
		var sc_r: float = tl.clock.real_at(float(tl.get(String(cr[0]))))
		_check(sc_r > float(fin["r_hit"]) + 0.2 and sc_r < sw and tl.clock.speed_at(sc_r) < 0.5, "the crash (real %.2f) sits inside the slow-motion swell" % sc_r)
		_check(tl.fx.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "crate" and String(e["where"]) == String(cr[1])), "the %s bursts" % String(cr[1]))
	for nm: String in (conf.get("taken", {}) as Dictionary).keys():
		var tr: float = float(conf["taken"][nm])
		_check(tl.clock.speed_at(tr) > 0.99, "%s at %.2f plays at normal speed" % [nm, tr])
		var hitp: bool = tl.punches.any(func(pu: Dictionary) -> bool: return absf(tl.clock.real_at(tl.story_time(pu["at"])) - tr) < 0.0005)
		_check(hitp, "camera punch-in on %s at %.2f" % [nm, tr])
	var hero_o: Dictionary = tl.actors["hero"]["opts"]
	_check(String(hero_o.get("preset", "")) == "player", "the hero is the protagonist look (%s)" % str(hero_o))
	var st_half: Vector2 = (tl.stage.get("size", HALF * 2.0) as Vector2) * 0.5
	for pr: Dictionary in tl.props:
		var pp: Vector3 = pr["pos"]
		var hb: Vector2 = Vector2(maxf(st_half.x, HALF.x), maxf(st_half.y, HALF.y)) if bool((pr["opts"] as Dictionary).get("set", false)) else HALF
		_check(absf(pp.x) <= hb.x + 0.1 and absf(pp.z) <= hb.y + 0.1, "prop %s inside the %.0f x %.0f box" % [String(pr["id"]), hb.x * 2.0, hb.y * 2.0])
	for sb: Dictionary in tl.subs:
		_check(not String(sb["text"]).contains("…"), "no ellipsis glyph in '%s'" % String(sb["text"]))
	var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/%s.txt" % tl.slot).replace("\r\n", "\n")
	_check(committed == tl.beat_sheet(), "docs/cinematics/%s.txt is in sync (run tools/cine_beats.gd)" % tl.slot)
	world = Node3D.new()
	root.add_child(world)
	await process_frame
	var gfx: Node = root.get_node_or_null("/root/GameFX")
	if gfx and gfx.has_method("set_art_style"):
		gfx.call("set_art_style", "vice", false)
	CharacterBuilder.ps2 = true
	await _framing()
	CineMoves.max_tier = 1
	p = CinePlayer.new()
	world.add_child(p)
	_check(p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false}).is_empty(), "sets up in an empty world")
	p.finished.connect(func(sk: bool) -> void: ended.append(sk))
	p.start()
	phase = 0


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			var n: int = 0
			var outside: String = ""
			var want: int = int(round(tl.length * 60.0))
			while ended.is_empty() and n < want + 100:
				p.step(1.0 / 60.0)
				n += 1
				if outside == "" and n % 6 == 0:
					for id: String in p.actors.keys():
						var ap: Vector3 = (p.actors[id] as CineActor).position
						if absf(ap.x) > HALF.x or absf(ap.z) > HALF.y:
							outside = "%s at r %.2f (%.2f, %.2f)" % [id, p.r, ap.x, ap.z]
			_check(absi(n - want) <= 1 and ended == [false], "plays %d steps of 1/60 (%d)" % [want, n])
			_check(outside == "", "actors stay inside the 14 x 10 box (%s)" % outside)
			var ms: float = p.frame_ms_total / maxf(float(p.frames), 1.0)
			print("  frame update %.2f ms (%d actors)" % [ms, p.actors.size()])
			_check(ms < 8.0, "frame update %.2f ms < 8" % ms)
			_contacts(p, "ual")
			if OS.get_environment("CINE_TR") != "":
				_trace(p, "ual")
			_lying(p, "ual")
			_skate(p, "ual")
			if OS.get_environment("CINE_FAST") != "1":
				_penetration(p, "ual")
			_states(p)
			p.queue_free()
			var caps: Array[int] = [2, 3]
			if CineRetarget.available("mixamo"):
				caps.push_front(0)
			else:
				print("  SKIP mixamo contacts (no Mixamo files in res://assets/local/mixamo/ or CINE_NO_MIXAMO=1)")
			for cap: int in caps:
				CineMoves.max_tier = cap
				var label: String = ["mixamo", "ual", "native", "code"][cap]
				var pc := CinePlayer.new()
				world.add_child(pc)
				pc.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
				_contacts(pc, label)
				if OS.get_environment("CINE_TR") != "":
					_trace(pc, label)
				_lying(pc, label)
				_skate(pc, label)
				if OS.get_environment("CINE_FAST") != "1":
					_penetration(pc, label)
				pc.queue_free()
			CineMoves.max_tier = 0
			if OS.get_environment("CINE_NO_FREEROAM") == "1":
				return _end()
			var ps: PackedScene = load("res://scenes/FreeRoam.tscn")
			fr = ps.instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			frames = 0
			phase = 1
		1:
			if frames < 3:
				return false
			for slot: String in conf.get("stages", [tl.slot]):
				var t: CineTimeline = CineTimeline.load_slot(slot)
				var xf: Variant = fr.call("cine_stage", t.stage)
				var info: Dictionary = fr.get("cine_stage_info")
				print("  stage %-24s %s" % [slot, str(info)])
				_check(xf is Transform3D, "%s: a clear %s m stage spot in FreeRoam" % [slot, str(t.stage.get("size"))])
				if xf is Transform3D and GRASS_MOVED.has(slot):
					var bk: Dictionary = CineStage.baked(t.stage)
					var at: Vector2 = t.stage["at"]
					var dist: float = Vector2((xf as Transform3D).origin.x, (xf as Transform3D).origin.z).distance_to(at)
					_check(String(info.get("source", "")) == "baked" and not bk.is_empty() and (bk["xf"] as Transform3D).is_equal_approx(xf)
						and dist <= float(GRASS_MOVED[slot]) + 2.0,
						"%s: staged at its baked spot off the lawn, %.1f m from its point (bound %.1f m; got %s, ring %s)" % [slot, dist,
						float(GRASS_MOVED[slot]) + 2.0, String(info.get("landmark", "")), str(info.get("ring"))])
				elif xf is Transform3D:
					_check(String(info.get("landmark", "")) == "@at" and float(info.get("ring", 99.0)) <= 4.0,
						"%s: staged within 4 m of its explicit point (got %s, ring %s)" % [slot, String(info.get("landmark", "")), str(info.get("ring"))])
			ended.clear()
			fr.connect("cinematic_finished", func(slot: String, sk: bool) -> void: ended.append([slot, sk]))
			var cp: Variant = fr.call("play_cinematic", tl, {})
			_check(cp is CinePlayer, "FreeRoam plays %s at its stage" % tl.slot)
			if not cp is CinePlayer:
				return _end()
			_check(paused, "game paused during the cinematic")
			(cp as CinePlayer).force_skip_hold = true
			frames = 0
			phase = 2
		2:
			if not ended.is_empty():
				_check(ended[0] == [tl.slot, true], "skip finished the cinematic: %s" % str(ended))
				_check(not paused and (fr.get("player") as Node3D).visible, "world restored")
				return _end()
			if frames > 2000:
				_check(false, "skip never finished")
				return _end()
	return false


func _end() -> bool:
	if fails.is_empty():
		print("✅ SUCCESS: CINE %s (%.3f s, ramps, beat sheet, framing, tiers, contacts, props, bodies, FreeRoam stages)" % [String(conf.get("slot", "?")), float(conf.get("length", 0.0))])
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true


## CINE_TR="a,b,r0,r1": prints both actors' roots, hips, wrists and moves every 0.05 s (tuning aid, every tier).
func _trace(pl: CinePlayer, label: String) -> void:
	var tr: PackedStringArray = OS.get_environment("CINE_TR").split(",")
	if tr.size() < 4:
		return
	var a: CineActor = pl.actors[tr[0]]
	var b: CineActor = pl.actors[tr[1]]
	var r2: float = float(tr[2])
	while r2 <= float(tr[3]):
		pl.seek(r2)
		print("  TRACE %s r %.2f %s %s hips %s wrists %s %s %s | %s %s hips %s wrists %s %s %s" % [label, r2,
			tr[0], str(a.position), str(a.bone_world("Hips")), str(a.bone_world("Wrist.L")), str(a.bone_world("Wrist.R")), String(a.active_move(pl.s).get("move", "?")),
			tr[1], str(b.position), str(b.bone_world("Hips")), str(b.bone_world("Wrist.L")), str(b.bone_world("Wrist.R")), String(b.active_move(pl.s).get("move", "?"))])
		r2 += 0.05
