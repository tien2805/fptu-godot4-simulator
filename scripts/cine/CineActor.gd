# File: res://scripts/cine/CineActor.gd
# One cinematic actor (spec A1-D21): a real game character (CharacterBuilder rigged body, animate=false) driven purely by
# STORY time s, so any frame can be evaluated in any order:
#   • move / strike: logical moves (CineMoves) resolved to the best tier, crossfaded (each cue's FULL pose – clip + code +
#     additive layer – is built before blending); strike places the move so its impact frame lands on s_hit; code tiers and
#     "add" layers go on top through CharacterBuilder._apply_bone_pose / _char_rot_local, and leg layers carry the Foot.L/R
#     IK targets with the shin (CharacterBuilder._foot_follow); a last pass seats each foot on its shin's ankle;
#   • key: ground position + yaw (accumulated, may exceed a turn) + spin about the hip-height pivot, per-segment easing and
#     parabolic "arc"; the active move's extras (arc, spin, yaw) are added over its air window; code poses may pitch / drop
#     the whole body about the pivot ("body_pitch" / "body_y": lying, getting up);
#   • override: timeline poses (abs / add); look: head + neck turn toward a node or a point, in the spin node's frame;
#     expr: face expression (PS2 atlas cell, or the classic face texture through CharacterBuilder.set_expression); show_at;
#   • hold: a prop in the hand for a story-time window (a BoneAttachment3D on the hand bone carries it; two-handed holds are
#     centred between both hands), part_show: hide / show a body part ("helmet") from a story time on.
# Order independence: root / spin transforms are pure functions of s (xf_at). A look at another CineActor aims at that
# actor's head_point_at(s) – its root and spin transform at s times its neutral head point – never at its bones from its last
# evaluate, so actors can be evaluated in any order and seeking backwards (replays) gives the same frame. (Clip-driven head
# motion of the target, e.g. a lean or a clip-tier fall, is not followed; code-tier lying is, through body_pitch / body_y.)
# Without keys the actor stays where it was placed: position / yaw are captured at the first evaluate; call place() to move
# a key-less actor afterwards (assigning position after an evaluate snaps back).
class_name CineActor
extends Node3D

const PIVOT_Y: float = 0.95          # = CineMoves.PIVOT_Y
const LOOK_YAW_MAX: float = 1.22     # 70°
const LOOK_PITCH_MAX: float = 0.52   # 30°
const LOOK_FADE: float = 0.25

var body: Node3D
var sk: Skeleton3D
var bd: Dictionary
var spin: Node3D
var face_mat: StandardMaterial3D
var display_name: String = ""
var moves: Array[Dictionary] = []      # {s, dur, fade, loop, res, move}
var overrides: Array[Dictionary] = []
var keys: Array[Dictionary] = []
var exprs: Array[Dictionary] = []
var looks: Array[Dictionary] = []
var shows: Array[Dictionary] = []
var holds: Array[Dictionary] = []      # {s0, s1, node, att, bone, mid, offset, rot}
var parts: Array[Dictionary] = []      # {s, part, v}
var _part_nodes: Dictionary = {}       # part -> Array of MeshInstance3D
var last_s: float = 0.0
var _base_pose: Dictionary = {}
var _home: Dictionary = {}             # placement when there are no keys: {pos, yaw}
var _face_ps2: bool = false
var _expr_now: String = ""             # classic faces: expression last applied (texture swaps only on change)
var _head_in_spin: Vector3 = Vector3(0.0, 1.5 - PIVOT_Y, 0.0)   # neutral Head bone point in the spin node's frame
var _ankles: Array = []                # [LowerLeg bone, Foot bone, ankle in shin-rest frame, ankle in foot-rest frame]


## Build the character (CharacterBuilder.build opts; always rigged, animate=false so no animator writes the bones).
func setup(opts: Dictionary) -> void:
	var o: Dictionary = opts.duplicate()
	o["rigged"] = true
	o["animate"] = false
	spin = Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0.0, PIVOT_Y, 0.0)
	add_child(spin)
	body = CharacterBuilder.build(o)
	body.position = Vector3(0.0, -PIVOT_Y, 0.0)
	spin.add_child(body)
	sk = body.get_meta("skeleton") as Skeleton3D
	var ap: AnimationPlayer = body.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
	bd = CineRetarget.bind(sk, ap)
	# neutral standing base as a full pose (code tier and "no move" pose)
	var nb: Dictionary = CharacterBuilder._base_of(sk)
	var rot: Dictionary = {}
	var pos: Dictionary = {}
	for b: int in sk.get_bone_count():
		var l: Transform3D = nb["local"][b] if not nb.is_empty() else sk.get_bone_rest(b)
		rot[b] = l.basis.get_rotation_quaternion()
		pos[b] = l.origin
	_base_pose = {"rot": rot, "pos": pos}
	# neutral head point in the spin frame (look-at target of other actors, see head_point_at)
	CineRetarget.apply(sk, bd, _base_pose)
	var hb: int = sk.find_bone("Head")
	if hb >= 0:
		var rel: Transform3D = Transform3D.IDENTITY
		var n: Node = sk
		while n != null and n != spin:
			if n is Node3D:
				rel = (n as Node3D).transform * rel
			n = n.get_parent()
		_head_in_spin = rel * CharacterBuilder._bone_global_now(sk, hb).origin
	# ankle reference (rest frames, as CineRetarget attaches the feet) for the foot-seating pass
	for side: String in ["L", "R"]:
		var lb: int = sk.find_bone("LowerLeg." + side)
		var fb: int = sk.find_bone("Foot." + side)
		if lb < 0 or fb < 0:
			continue
		var l0: Transform3D = sk.get_bone_global_rest(lb)
		var f0: Transform3D = sk.get_bone_global_rest(fb)
		var a0: Vector3 = l0.origin + l0.basis.y.normalized() * CharacterBuilder.ANKLE_DOWN_SHIN
		_ankles.append([lb, fb, l0.affine_inverse() * a0, f0.affine_inverse() * a0])
	# own face material (the PS2 face material is shared per skin tone, the classic one per skin tone and sex)
	var face: MeshInstance3D = CharacterBuilder.get_pivot(body, "face_mesh") as MeshInstance3D
	if face and face.material_override is StandardMaterial3D:
		face_mat = (face.material_override as StandardMaterial3D).duplicate()
		face.material_override = face_mat
		_face_ps2 = bool(face_mat.get_meta("ps2_face", false))


# ---------------------------------------------------------------------------
# Script
# ---------------------------------------------------------------------------
## Start move_name at story time s. opts: dur (story s, default the move's), fade (crossfade from the previous move), loop,
## arc (overrides the tier's airborne height, e.g. 0 when timeline keys already carry the flight arc), reach (a step into
## the strike: metres along the facing - or Vector2(forward, right) - 0 at the move's ends and full on its impact; one value,
## or {tier: value} keyed by scene_tier() so each tier lands its striking part on the target's surface).
func move(s: float, move_name: String, opts: Dictionary = {}) -> Dictionary:
	var res: Dictionary = CineMoves.resolve(move_name, bd)
	if res.is_empty():
		push_warning("CineActor %s: unknown move %s" % [name, move_name])
		return {}
	if opts.has("arc"):
		res = res.duplicate()
		res["arc"] = float(opts["arc"])
	if opts.has("reach"):
		var rv: Variant = opts["reach"]
		res = res.duplicate()
		var rt: Variant = (rv as Dictionary).get(scene_tier(), 0.0) if rv is Dictionary else rv
		res["reach"] = rt if rt is Vector2 else Vector2(float(rt), 0.0)
	moves.append({"s": s, "dur": float(opts.get("dur", res["dur"])), "fade": float(opts.get("fade", 0.12)),
		"loop": bool(opts.get("loop", res["loop"])), "res": res, "move": move_name})
	moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	return res


## The tier this actor plays at (what fight_idle resolves to under the current cap): the key of per-tier "reach" offsets,
## so a code-only strike can still be tuned against the clip tier its target plays.
func scene_tier() -> String:
	return String(CineMoves.resolve("fight_idle", bd).get("tier", "code"))


## Start move_name so its impact frame lands on story time s_hit.
func strike(s_hit: float, move_name: String, opts: Dictionary = {}) -> Dictionary:
	var res: Dictionary = CineMoves.resolve(move_name, bd)
	if res.is_empty():
		push_warning("CineActor %s: unknown move %s" % [name, move_name])
		return {}
	var dur: float = float(opts.get("dur", res["dur"]))
	return move(s_hit - maxf(float(res["hit_u"]), 0.0) * dur, move_name, opts)


## Position / yaw at s. mode: easing of the segment ENDING at this key; arc: extra parabolic height (m) of that segment.
func key(s: float, pos: Vector3, yaw: float, spin_euler: Vector3 = Vector3.ZERO, mode: String = "smooth", arc: float = 0.0) -> void:
	keys.append({"s": s, "pos": pos, "yaw": yaw, "spin": spin_euler, "mode": mode, "arc": arc})
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## Place a key-less actor (parent-local position, yaw rad): the base its evaluations start from from now on.
func place(pos: Vector3, yaw: float) -> void:
	position = pos
	rotation.y = yaw
	_home = {"pos": pos, "yaw": yaw}


func override(s0: float, s1: float, pose: Callable, fade_in: float = 0.08, fade_out: float = 0.12, mode: String = "abs") -> void:
	overrides.append({"s0": s0, "s1": s1, "pose": pose, "fi": fade_in, "fo": fade_out, "mode": mode})


func expr(s: float, cell: String) -> void:
	exprs.append({"s": s, "e": cell})
	exprs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## Turn head and neck toward target (Node3D, or a Vector3 in the parent's space) during [s0, s1].
func look(s0: float, s1: float, target: Variant) -> void:
	looks.append({"s0": s0, "s1": s1, "t": target})


func show_at(s: float, on: bool) -> void:
	shows.append({"s": s, "v": on})
	shows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## Hold `node` during story [s0, s1): a BoneAttachment3D on `bone` carries it (hidden outside the window). opts: "mid" (a second
## bone: two-handed, the prop is centred between both), "offset" (m, actor frame, from the hand / the centre), "rot" (deg, actor
## frame). The prop's transform relative to the attachment is set on every evaluate from the bones at s (seekable).
func hold(s0: float, s1: float, node: Node3D, bone: String = "Wrist.R", opts: Dictionary = {}) -> void:
	var att := BoneAttachment3D.new()
	att.name = "Hold%d" % holds.size()
	att.bone_name = bone
	sk.add_child(att)
	att.add_child(node)
	att.visible = false
	holds.append({"s0": s0, "s1": s1, "node": node, "att": att, "bone": bone, "mid": String(opts.get("mid", "")),
		"offset": opts.get("offset", Vector3.ZERO), "rot": opts.get("rot", Vector3.ZERO)})


## Show (on) or hide a body part from story time s on: "helmet" (meshes tagged helmet_part by CharacterBuilder).
func part_show(s: float, part: String, on: bool) -> void:
	parts.append({"s": s, "part": part, "v": on})
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	if not _part_nodes.has(part):
		var found: Array = []
		for n: Node in body.find_children("*", "MeshInstance3D", true, false):
			if n.has_meta(part + "_part"):
				found.append(n)
		_part_nodes[part] = found


## The move cue playing at s ({} before the first one).
func active_move(s: float) -> Dictionary:
	var cur: Dictionary = {}
	for c: Dictionary in moves:
		if float(c["s"]) <= s:
			cur = c
	return cur


# ---------------------------------------------------------------------------
# Pure functions of story time (no node state read except the key-less placement)
# ---------------------------------------------------------------------------
## Root and spin transform at s: {"pos" (parent-local), "yaw", "spin_rot" (Euler), "spin_pos"}.
func xf_at(s: float) -> Dictionary:
	var pos: Vector3
	var yaw: float
	var srot: Vector3 = Vector3.ZERO
	if not keys.is_empty():
		var k0: Dictionary = keys[0]
		var k1: Dictionary = keys[0]
		for i: int in keys.size():
			if float(keys[i]["s"]) <= s:
				k0 = keys[i]
				k1 = keys[mini(i + 1, keys.size() - 1)]
		if s < float(keys[0]["s"]):
			k1 = k0
		var u: float = 0.0
		var span: float = float(k1["s"]) - float(k0["s"])
		if span > 0.0001:
			u = clampf((s - float(k0["s"])) / span, 0.0, 1.0)
		var e: float = ease_u(u, String(k1["mode"]))
		pos = (k0["pos"] as Vector3).lerp(k1["pos"], e)
		var arc: float = float(k1["arc"])
		if arc != 0.0:
			pos = (k0["pos"] as Vector3).lerp(k1["pos"], u)
			pos.y += 4.0 * arc * u * (1.0 - u)
		yaw = lerpf(float(k0["yaw"]), float(k1["yaw"]), e)
		srot = (k0["spin"] as Vector3).lerp(k1["spin"], e)
	elif _home.is_empty():
		pos = position
		yaw = rotation.y
	else:
		pos = _home["pos"]
		yaw = _home["yaw"]
	# reach: steps into strikes along the facing (every cue whose window holds s, so a cut never pops)
	for m: Dictionary in moves:
		var rres: Dictionary = m["res"]
		var rch: Vector2 = rres.get("reach", Vector2.ZERO)
		if rch == Vector2.ZERO:
			continue
		var ru: float = (s - float(m["s"])) / maxf(float(m["dur"]), 0.0001)
		if ru <= 0.0 or ru >= 1.0:
			continue
		var hu: float = clampf(float(rres["hit_u"]), 0.05, 0.95)
		var bell: float = CineMoves._sm(ru / hu) if ru <= hu else 1.0 - CineMoves._sm((ru - hu) / (1.0 - hu))
		pos += (Vector3(-sin(yaw), 0.0, -cos(yaw)) * rch.x + Vector3(cos(yaw), 0.0, -sin(yaw)) * rch.y) * bell
	# extras of the move playing now (A1-D4)
	var c: Dictionary = active_move(s)
	if not c.is_empty():
		var res: Dictionary = c["res"]
		yaw += deg_to_rad(float(res["yaw"]))
		var air: Array = res["air"]
		if air.size() >= 2:
			var uu: float = (s - float(c["s"])) / maxf(float(c["dur"]), 0.0001)
			var u0: float = air[0]
			var u1: float = air[1]
			var spin_deg: Vector3 = res["spin"]
			if uu >= u0 and uu <= u1:
				var a: float = (uu - u0) / maxf(u1 - u0, 0.0001)
				pos.y += 4.0 * float(res["arc"]) * a * (1.0 - a)
				srot += spin_deg * (PI / 180.0) * (a * a * (3.0 - 2.0 * a))
			elif uu > u1 and uu <= 1.0 and absf(spin_deg.x) + absf(spin_deg.y) + absf(spin_deg.z) < 300.0:
				var back: float = (uu - u1) / maxf(1.0 - u1, 0.0001)
				var keep: float = 1.0 if bool(res["hold_spin"]) else 1.0 - back * back * (3.0 - 2.0 * back)
				srot += spin_deg * (PI / 180.0) * keep
	# whole-body pitch / drop of code poses (lying, getting up), crossfaded like the bones
	var bk: Vector2 = _body_keys_at(s)
	srot.x += bk.x
	return {"pos": pos, "yaw": yaw, "spin_rot": srot, "spin_pos": Vector3(0.0, PIVOT_Y + bk.y, 0.0)}


## Global point of this actor's (neutral) head at story time s – what other actors look at.
func head_point_at(s: float) -> Vector3:
	var x: Dictionary = xf_at(s)
	var root_xf := Transform3D(Basis.from_euler(Vector3(rotation.x, float(x["yaw"]), rotation.z)) * Basis.from_scale(scale), x["pos"])
	var spin_xf := Transform3D(Basis.from_euler(x["spin_rot"]), x["spin_pos"])
	var p: Vector3 = root_xf * (spin_xf * _head_in_spin)
	var par: Node3D = get_parent() as Node3D
	return par.global_transform * p if par and par.is_inside_tree() else p


func _cue_index(s: float) -> int:
	var i: int = 0
	for j: int in moves.size():
		if float(moves[j]["s"]) <= s:
			i = j
	return i


## Weight of cue i at s (1 = no crossfade from cue i - 1).
func _fade_w(i: int, s: float) -> float:
	var dt: float = s - float(moves[i]["s"])
	var fade: float = moves[i]["fade"]
	if i > 0 and dt >= 0.0 and dt < fade and fade > 0.0:
		var x: float = clampf(dt / fade, 0.0, 1.0)
		return x * x * (3.0 - 2.0 * x)
	return 1.0


## Pose-u of a code-tier cue at s: loops by phase, one-shots through the entry's [0, hit, 1] window (impact on hit_u).
func _code_u(c: Dictionary, s: float) -> float:
	var x: float = s - float(c["s"])
	var dur: float = c["dur"]
	if dur <= 0.0:
		return 1.0
	if bool(c["loop"]):
		return fposmod(x / dur, 1.0)
	return CineMoves.clip_time(c["res"], x, dur, false)


func _body_keys_at(s: float) -> Vector2:
	if moves.is_empty():
		return Vector2.ZERO
	var i: int = _cue_index(s)
	var w: float = _fade_w(i, s)
	var out: Vector2 = _cue_body(moves[i], s) * w
	if w < 1.0:
		out += _cue_body(moves[i - 1], s) * (1.0 - w)
	return out


func _cue_body(c: Dictionary, s: float) -> Vector2:
	var res: Dictionary = c["res"]
	if String(res["t"]) != "code":
		return Vector2.ZERO
	var cp: Dictionary = CineMoves.code_pose(String(res["a"]), _code_u(c, s))
	return Vector2(float(cp.get("body_pitch", 0.0)), float(cp.get("body_y", 0.0)))


# ---------------------------------------------------------------------------
# Evaluation at story time s
# ---------------------------------------------------------------------------
func evaluate(s: float) -> void:
	last_s = s
	var vis: bool = true
	for x: Dictionary in shows:
		if float(x["s"]) <= s:
			vis = bool(x["v"])
	visible = vis
	_eval_transform(s)
	_eval_pose(s)
	_eval_look(s)
	_eval_expr(s)
	_eval_parts(s)
	_eval_holds(s)


func _eval_transform(s: float) -> void:
	if keys.is_empty() and _home.is_empty():
		_home = {"pos": position, "yaw": rotation.y}
	var x: Dictionary = xf_at(s)
	position = x["pos"]
	rotation.y = x["yaw"]
	spin.rotation = x["spin_rot"]
	spin.position = x["spin_pos"]


static func ease_u(u: float, mode: String) -> float:
	match mode:
		"linear":
			return u
		"in":
			return u * u
		"out":
			return 1.0 - (1.0 - u) * (1.0 - u)
		"step":
			return 0.0 if u < 1.0 else 1.0
	return u * u * (3.0 - 2.0 * u)


## {"pose": local pose, "code": code pose or {}, "add": additive code pose or {}} of one move cue at s.
func _cue_pose(c: Dictionary, s: float) -> Dictionary:
	var res: Dictionary = c["res"]
	var x: float = s - float(c["s"])
	var dur: float = c["dur"]
	var u: float = clampf(x / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var out: Dictionary = {"pose": _base_pose, "code": {}, "add": {}}
	if String(res["t"]) == "code":
		out["code"] = CineMoves.code_pose(String(res["a"]), _code_u(c, s))
	else:
		var t: float = CineMoves.clip_time(res, x, dur, bool(c["loop"]))
		if String(res["t"]) == "native":
			out["pose"] = CineRetarget.sample_native(bd, String(res["a"]), t)
		else:
			out["pose"] = CineRetarget.sample(bd, String(res["t"]), String(res["a"]), t, false,
				{"xz": true, "y": String(res["root_y"]) == "strip", "ref": float(res.get("ref", res["from"]))})
	if String(res["add"]) != "":
		out["add"] = CineMoves.code_pose(String(res["add"]), CineMoves.add_u(res, u))
	return out


## Write one cue's full pose (clip or base, code pose, additive layer) to the skeleton.
func _render_cue(cp: Dictionary) -> void:
	CineRetarget.apply(sk, bd, cp["pose"])
	if not (cp["code"] as Dictionary).is_empty():
		CharacterBuilder._apply_bone_pose(sk, cp["code"], 1.0)
	_add_pose(cp["add"], 1.0)


## Local pose of every bone as it stands on the skeleton now.
func _snapshot() -> Dictionary:
	var rot: Dictionary = {}
	var pos: Dictionary = {}
	for b: int in int(bd["n"]):
		rot[b] = sk.get_bone_pose_rotation(b)
		pos[b] = sk.get_bone_pose_position(b)
	return {"rot": rot, "pos": pos}


func _eval_pose(s: float) -> void:
	if moves.is_empty():
		CineRetarget.apply(sk, bd, _base_pose)
	else:
		var i: int = _cue_index(s)
		var w: float = _fade_w(i, s)
		_render_cue(_cue_pose(moves[i], s))
		if w < 1.0:
			# crossfade the two cues' FULL poses (a code pose blended against the bare base would sag mid-fade)
			var cur: Dictionary = _snapshot()
			_render_cue(_cue_pose(moves[i - 1], s))
			CineRetarget.apply(sk, bd, CineRetarget.blend(bd, _snapshot(), cur, w))
	for o: Dictionary in overrides:
		var s0: float = o["s0"]
		var s1: float = o["s1"]
		var fi: float = o["fi"]
		var fo: float = o["fo"]
		if s < s0 - fi or s > s1 + fo:
			continue
		var w2: float = 1.0
		if s < s0 and fi > 0.0:
			w2 = (s - (s0 - fi)) / fi
		elif s > s1 and fo > 0.0:
			w2 = 1.0 - (s - s1) / fo
		w2 = clampf(w2, 0.0, 1.0)
		w2 = w2 * w2 * (3.0 - 2.0 * w2)
		var uo: float = clampf((s - s0) / maxf(s1 - s0, 0.0001), 0.0, 1.0)
		var cpose: Dictionary = (o["pose"] as Callable).call(uo)
		if String(o["mode"]) == "add":
			_add_pose(cpose, w2)
		else:
			CharacterBuilder._apply_bone_pose(sk, cpose, w2)
	_seat_feet()


## Additive rotation (character-frame Euler × w) on the current pose – same operation as RigAnimator._add_rot. Leg keys
## carry the Foot.L/R IK targets with the shin (CharacterBuilder._foot_follow from the pre-layer shin / foot transforms).
func _add_pose(cpose: Dictionary, w: float) -> void:
	if cpose.is_empty() or w <= 0.0:
		return
	var feet: Array = []
	for side: String in ["l", "r"]:
		if cpose.has("thigh_" + side) or cpose.has("knee_" + side) or cpose.has("foot_" + side):
			var lb: int = sk.find_bone("LowerLeg." + side.to_upper())
			var fb: int = sk.find_bone("Foot." + side.to_upper())
			if lb >= 0 and fb >= 0:
				feet.append([lb, fb, CharacterBuilder._bone_global_now(sk, lb), CharacterBuilder._bone_global_now(sk, fb), side])
	for k: String in cpose.keys():
		if not CharacterBuilder.BONE_OF.has(k):
			continue
		var b: int = sk.find_bone(String(CharacterBuilder.BONE_OF[k]))
		if b < 0:
			continue
		var r: Basis = CharacterBuilder._char_rot_local(sk, b, (cpose[k] as Vector3) * w)
		sk.set_bone_pose_rotation(b, (r * Basis(sk.get_bone_pose_rotation(b))).get_rotation_quaternion())
	for f: Array in feet:
		var fk: String = "foot_" + String(f[4])
		var ef: Variant = (cpose[fk] as Vector3) * w if cpose.has(fk) else null
		CharacterBuilder._foot_follow(sk, f[0], f[1], f[2], f[3], ef, 1.0)
	CharacterBuilder._mark_bone_poses_dirty(sk)


## Seat each foot on its shin's ankle, keeping the foot's own rotation: native clips (IK targets keyed apart from the FK
## shin) and crossfades (feet blended apart from the leg chain) otherwise leave a few cm of gap at the ankle.
func _seat_feet() -> void:
	for e: Array in _ankles:
		var lb: int = e[0]
		var fb: int = e[1]
		var by_shin: Vector3 = CharacterBuilder._bone_global_now(sk, lb) * (e[2] as Vector3)
		var by_foot: Vector3 = CharacterBuilder._bone_global_now(sk, fb) * (e[3] as Vector3)
		var d: Vector3 = by_shin - by_foot
		if d.length_squared() < 1e-10:
			continue
		var pf: int = sk.get_bone_parent(fb)
		var pg: Basis = CharacterBuilder._bone_global_now(sk, pf).basis if pf >= 0 else Basis.IDENTITY
		sk.set_bone_pose_position(fb, sk.get_bone_pose_position(fb) + pg.inverse() * d)
	CharacterBuilder._mark_bone_poses_dirty(sk)


## Head + neck toward each active look target, measured in the spin node's frame (correct while flipping or lying).
func _eval_look(s: float) -> void:
	for l: Dictionary in looks:
		var s0: float = l["s0"]
		var s1: float = l["s1"]
		if s < s0 - LOOK_FADE or s > s1 + LOOK_FADE:
			continue
		var w: float = clampf(minf((s - (s0 - LOOK_FADE)) / LOOK_FADE, ((s1 + LOOK_FADE) - s) / LOOK_FADE), 0.0, 1.0)
		var tgt: Variant = l["t"]
		var tp: Vector3
		if tgt is Object:
			if not is_instance_valid(tgt):
				continue
			if tgt is CineActor:
				tp = (tgt as CineActor).head_point_at(s)
			elif tgt is Node3D:
				tp = (tgt as Node3D).global_position + Vector3(0.0, 1.5, 0.0)
			else:
				continue
		else:
			var parent3d: Node3D = get_parent() as Node3D
			tp = parent3d.to_global(tgt) if parent3d else (tgt as Vector3)
		var dl: Vector3 = spin.global_transform.basis.orthonormalized().inverse() * (tp - bone_world("Head"))
		var yaw: float = clampf(atan2(-dl.x, -dl.z), -LOOK_YAW_MAX, LOOK_YAW_MAX)   # characters face -Z; + = to the left
		var pitch: float = clampf(atan2(dl.y, Vector2(dl.x, dl.z).length()), -LOOK_PITCH_MAX, LOOK_PITCH_MAX)
		_add_pose({"neck": Vector3(-pitch * 0.4, yaw * 0.4, 0.0), "head": Vector3(-pitch * 0.6, yaw * 0.6, 0.0)}, w)


func _eval_parts(s: float) -> void:
	for part: String in _part_nodes.keys():
		var on: bool = true
		for x: Dictionary in parts:
			if String(x["part"]) == part and float(x["s"]) <= s:
				on = bool(x["v"])
		for mi: Node3D in _part_nodes[part]:
			mi.visible = on


## Held props: visible inside their window; placed at the hand (or between both hands) with the spin node's orientation.
func _eval_holds(s: float) -> void:
	for h: Dictionary in holds:
		var att: BoneAttachment3D = h["att"]
		var on: bool = s >= float(h["s0"]) and s < float(h["s1"])
		att.visible = on
		if not on:
			continue
		var b: int = sk.find_bone(String(h["bone"]))
		if b < 0:
			continue
		var hand: Transform3D = sk.global_transform * CharacterBuilder._bone_global_now(sk, b)
		var p: Vector3 = hand.origin
		if String(h["mid"]) != "":
			p = (p + bone_world(String(h["mid"]))) * 0.5
		var bs: Basis = spin.global_transform.basis.orthonormalized()
		var want := Transform3D(bs * Basis.from_euler((h["rot"] as Vector3) * (PI / 180.0)), p + bs * (h["offset"] as Vector3))
		(h["node"] as Node3D).transform = hand.affine_inverse() * want


## PS2 faces switch the atlas cell on the actor's own face material; classic faces (no "ps2_face" meta) swap the face
## texture through CharacterBuilder.set_expression (only when the expression changes).
func _eval_expr(s: float) -> void:
	if face_mat == null or exprs.is_empty():
		return
	var e: String = "open"
	for x: Dictionary in exprs:
		if float(x["s"]) <= s:
			e = String(x["e"])
	if _face_ps2:
		face_mat.uv1_offset = PS2Head.cell_offset(e if e in PS2Head.CELLS else "open")
	elif e != _expr_now:
		CharacterBuilder.set_expression(body, e)
		_expr_now = e


## Current global position of a bone (after evaluate) – for FX at hands / feet and contact checks.
func bone_world(bone: String) -> Vector3:
	var b: int = sk.find_bone(bone)
	if b < 0:
		return global_position
	return sk.global_transform * CharacterBuilder._bone_global_now(sk, b).origin
