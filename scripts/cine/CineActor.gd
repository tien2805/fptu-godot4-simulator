# File: res://scripts/cine/CineActor.gd
# One cinematic actor (spec A1-D21): a real game character (CharacterBuilder rigged body, animate=false) driven purely by
# STORY time s, so any frame can be evaluated in any order:
#   • move / strike: logical moves (CineMoves) resolved to the best tier, crossfaded; strike places the move so its impact
#     frame lands on s_hit; code tiers and "add" layers go on top through CharacterBuilder._apply_bone_pose / _char_rot_local;
#   • key: ground position + yaw (accumulated, may exceed a turn) + spin about the hip-height pivot, per-segment easing and
#     parabolic "arc"; the active move's extras (arc, spin, yaw) are added over its air window; code poses may pitch / drop
#     the whole body about the pivot ("body_pitch" / "body_y": lying, getting up);
#   • override: timeline poses (abs / add); look: head + neck turn toward a node or a point; expr: face expression (PS2 atlas
#     cell, or the classic face texture through CharacterBuilder.set_expression); show_at.
# Without keys the actor stays where it was placed (position / yaw captured at the first evaluate).
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
var last_s: float = 0.0
var _base_pose: Dictionary = {}
var _home: Dictionary = {}             # placement when there are no keys: {pos, yaw}
var _face_ps2: bool = false
var _expr_now: String = ""             # classic faces: expression last applied (texture swaps only on change)


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
	# own face material (the PS2 face material is shared per skin tone, the classic one per skin tone and sex)
	var face: MeshInstance3D = CharacterBuilder.get_pivot(body, "face_mesh") as MeshInstance3D
	if face and face.material_override is StandardMaterial3D:
		face_mat = (face.material_override as StandardMaterial3D).duplicate()
		face.material_override = face_mat
		_face_ps2 = bool(face_mat.get_meta("ps2_face", false))


# ---------------------------------------------------------------------------
# Script
# ---------------------------------------------------------------------------
## Start move_name at story time s. opts: dur (story s, default the move's), fade (crossfade from the previous move), loop.
func move(s: float, move_name: String, opts: Dictionary = {}) -> Dictionary:
	var res: Dictionary = CineMoves.resolve(move_name, bd)
	if res.is_empty():
		push_warning("CineActor %s: unknown move %s" % [name, move_name])
		return {}
	moves.append({"s": s, "dur": float(opts.get("dur", res["dur"])), "fade": float(opts.get("fade", 0.12)),
		"loop": bool(opts.get("loop", res["loop"])), "res": res, "move": move_name})
	moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	return res


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


## The move cue playing at s ({} before the first one).
func active_move(s: float) -> Dictionary:
	var cur: Dictionary = {}
	for c: Dictionary in moves:
		if float(c["s"]) <= s:
			cur = c
	return cur


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


func _eval_transform(s: float) -> void:
	spin.position = Vector3(0.0, PIVOT_Y, 0.0)
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
		var p: Vector3 = (k0["pos"] as Vector3).lerp(k1["pos"], e)
		var arc: float = float(k1["arc"])
		if arc != 0.0:
			p = (k0["pos"] as Vector3).lerp(k1["pos"], u)
			p.y += 4.0 * arc * u * (1.0 - u)
		position = p
		rotation.y = lerpf(float(k0["yaw"]), float(k1["yaw"]), e)
		spin.rotation = (k0["spin"] as Vector3).lerp(k1["spin"], e)
	else:
		# no keys: the placement at the first evaluate is the base every frame (extras below must not accumulate)
		if _home.is_empty():
			_home = {"pos": position, "yaw": rotation.y}
		position = _home["pos"]
		rotation.y = _home["yaw"]
		spin.rotation = Vector3.ZERO
	# extras of the move playing now (A1-D4)
	var c: Dictionary = active_move(s)
	if c.is_empty():
		return
	var res: Dictionary = c["res"]
	rotation.y += deg_to_rad(float(res["yaw"]))
	var air: Array = res["air"]
	if air.size() < 2:
		return
	var uu: float = (s - float(c["s"])) / maxf(float(c["dur"]), 0.0001)
	var u0: float = air[0]
	var u1: float = air[1]
	var spin_deg: Vector3 = res["spin"]
	if uu >= u0 and uu <= u1:
		var a: float = (uu - u0) / maxf(u1 - u0, 0.0001)
		position.y += 4.0 * float(res["arc"]) * a * (1.0 - a)
		spin.rotation += spin_deg * (PI / 180.0) * (a * a * (3.0 - 2.0 * a))
	elif uu > u1 and uu <= 1.0 and absf(spin_deg.x) + absf(spin_deg.y) + absf(spin_deg.z) < 300.0:
		var back: float = (uu - u1) / maxf(1.0 - u1, 0.0001)
		var keep: float = 1.0 if bool(res["hold_spin"]) else 1.0 - back * back * (3.0 - 2.0 * back)
		spin.rotation += spin_deg * (PI / 180.0) * keep


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
		out["code"] = CineMoves.code_pose(String(res["a"]), fposmod(x / dur, 1.0) if bool(c["loop"]) else u)
	else:
		var t: float = CineMoves.clip_time(res, x, dur, bool(c["loop"]))
		if String(res["t"]) == "native":
			out["pose"] = CineRetarget.sample_native(bd, String(res["a"]), t)
		else:
			out["pose"] = CineRetarget.sample(bd, String(res["t"]), String(res["a"]), t, false,
				{"xz": true, "y": String(res["root_y"]) == "strip", "ref": float(res["from"])})
	if String(res["add"]) != "":
		out["add"] = CineMoves.code_pose(String(res["add"]), u)
	return out


func _eval_pose(s: float) -> void:
	if moves.is_empty():
		CineRetarget.apply(sk, bd, _base_pose)
		return
	var i: int = 0
	for j: int in moves.size():
		if float(moves[j]["s"]) <= s:
			i = j
	var cur: Dictionary = _cue_pose(moves[i], s)
	var prev: Dictionary = {}
	var w: float = 1.0
	var dt: float = s - float(moves[i]["s"])
	var fade: float = moves[i]["fade"]
	if i > 0 and dt >= 0.0 and dt < fade and fade > 0.0:
		prev = _cue_pose(moves[i - 1], s)
		var x: float = clampf(dt / fade, 0.0, 1.0)
		w = x * x * (3.0 - 2.0 * x)
	var pose: Dictionary = cur["pose"] if prev.is_empty() else CineRetarget.blend(bd, prev["pose"], cur["pose"], w)
	CineRetarget.apply(sk, bd, pose)
	if not prev.is_empty() and not (prev["code"] as Dictionary).is_empty():
		CharacterBuilder._apply_bone_pose(sk, prev["code"], 1.0 - w)
	if not (cur["code"] as Dictionary).is_empty():
		CharacterBuilder._apply_bone_pose(sk, cur["code"], w)
	if not prev.is_empty():
		_add_pose(prev["add"], 1.0 - w)
	_add_pose(cur["add"], w)
	# whole-body pitch / drop of code poses (lying, getting up), crossfaded like the bones
	var pitch: float = float((cur["code"] as Dictionary).get("body_pitch", 0.0)) * w
	var drop: float = float((cur["code"] as Dictionary).get("body_y", 0.0)) * w
	if not prev.is_empty():
		pitch += float((prev["code"] as Dictionary).get("body_pitch", 0.0)) * (1.0 - w)
		drop += float((prev["code"] as Dictionary).get("body_y", 0.0)) * (1.0 - w)
	if pitch != 0.0 or drop != 0.0:
		spin.rotation.x += pitch
		spin.position.y += drop
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


## Additive rotation (character-frame Euler × w) on the current pose – same operation as RigAnimator._add_rot.
func _add_pose(cpose: Dictionary, w: float) -> void:
	if cpose.is_empty() or w <= 0.0:
		return
	for k: String in cpose.keys():
		if not CharacterBuilder.BONE_OF.has(k):
			continue
		var b: int = sk.find_bone(String(CharacterBuilder.BONE_OF[k]))
		if b < 0:
			continue
		var r: Basis = CharacterBuilder._char_rot_local(sk, b, (cpose[k] as Vector3) * w)
		sk.set_bone_pose_rotation(b, (r * Basis(sk.get_bone_pose_rotation(b))).get_rotation_quaternion())
	CharacterBuilder._mark_bone_poses_dirty(sk)


func _eval_look(s: float) -> void:
	for l: Dictionary in looks:
		var s0: float = l["s0"]
		var s1: float = l["s1"]
		if s < s0 - LOOK_FADE or s > s1 + LOOK_FADE:
			continue
		var w: float = clampf(minf((s - (s0 - LOOK_FADE)) / LOOK_FADE, ((s1 + LOOK_FADE) - s) / LOOK_FADE), 0.0, 1.0)
		var tp: Vector3
		if l["t"] is Node3D:
			var n: Node3D = l["t"]
			tp = (n as CineActor).bone_world("Head") if n is CineActor else n.global_position + Vector3(0.0, 1.5, 0.0)
		else:
			var parent3d: Node3D = get_parent() as Node3D
			tp = parent3d.to_global(l["t"]) if parent3d else (l["t"] as Vector3)
		var head: Vector3 = bone_world("Head")
		var d: Vector3 = tp - head
		var fwd: Vector3 = -global_transform.basis.z   # characters face -Z
		var yaw: float = clampf(Vector2(fwd.x, fwd.z).angle_to(Vector2(d.x, d.z)) * -1.0, -LOOK_YAW_MAX, LOOK_YAW_MAX)
		var pitch: float = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -LOOK_PITCH_MAX, LOOK_PITCH_MAX)
		_add_pose({"neck": Vector3(-pitch * 0.4, yaw * 0.4, 0.0), "head": Vector3(-pitch * 0.6, yaw * 0.6, 0.0)}, w)


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
