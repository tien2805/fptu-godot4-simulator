# File: res://scripts/cine/CineRetarget.gd
# Runtime retargeter for the cinematic system (spec 2026-10-23-story-phase-a1-cinematics-design.md, A1-D2).
# Sources: "mixamo" (owner's local FBX files, res://assets/local/mixamo/, git-ignored, optional), "ual1" / "ual2"
# (Quaternius Universal Animation Library, CC0, assets/models/quaternius/anim_library/) and "native" (the clips inside the
# game body file). Target: the game's Quaternius Modular body (bones Body/Hips/Torso/.../UpperArm.L/..., Foot.L/R are IK
# targets under Root).
# Math (per target bone b with source bone s, once per skeleton and source, see _bind_src()):
#     O_b = R_s⁻¹ · A_b · R_t          R = global rest rotation, A_b = model-frame rotation that moves the target bone from
#                                      its rest into the pose equivalent to the source rest (classes delta/yaw/dir/leg/foot)
#     G_t(t) = G_s(t) · O_b            every frame; globals converted to locals parent-first
# Body position: target hip-joint midpoint = source hip-joint midpoint × k (leg-length ratio) + rest offset. Feet follow the
# shin's ankle rigidly (as CharacterBuilder._apply_bone_pose does) with the source foot's orientation.
# Root motion (A1-D5): sample(..., root) can remove the source hips' horizontal ("xz") and/or vertical ("y") displacement
# relative to clip time root["ref"], so travel comes from timeline keys instead.
# Verified on the owner's 31 Mixamo clips (Godot 4.7.2 ufbx import: bones "mixamorig_*", metres, Y along the bone, +Z
# forward, identical T-pose rest in every file): k = 1.032, standing ankle heights match the source within 2 cm.
class_name CineRetarget
extends RefCounted

const UAL_DIR: String = "res://assets/models/quaternius/anim_library/"
const UAL_FILES: Dictionary = {"ual1": "ual1_AnimationLibrary_Godot_Standard.glb", "ual2": "ual2_UAL2_Standard.glb"}
const MIXAMO_DIR: String = "res://assets/local/mixamo/"
const MIXAMO_REST: String = "Y_Bot_TPose"
const SOURCES: Array[String] = ["mixamo", "ual1", "ual2"]
const COL: Dictionary = {"ual1": 1, "ual2": 2, "mixamo": 3}
const ANKLE_DOWN_SHIN: float = 0.42   # = CharacterBuilder.ANKLE_DOWN_SHIN

## Test hook: sources listed here are treated as missing (tests force the fallback tiers).
static var disabled: PackedStringArray = []
static var _src: Dictionary = {}       # source id -> data ({} = not available)
static var _map_cache: Array = []


## Bone table: [target, ual1, ual2, mixamo (prefix stripped), class]. Fingers generated.
static func bone_map() -> Array:
	if not _map_cache.is_empty():
		return _map_cache
	var m: Array = [
		["Body", "DEF-hips", "pelvis", "Hips", "yaw"], ["Hips", "DEF-hips", "pelvis", "Hips", "yaw"],
		["Abdomen", "DEF-spine.001", "spine_01", "Spine", "yaw"], ["Torso", "DEF-spine.002", "spine_02", "Spine1", "delta"],
		["Chest", "DEF-spine.003", "spine_03", "Spine2", "delta"], ["Neck", "DEF-neck", "neck_01", "Neck", "delta"],
		["Head", "DEF-head", "Head", "Head", "delta"],
	]
	for s: String in ["L", "R"]:
		var l: String = s.to_lower()
		var side: String = "Left" if s == "L" else "Right"
		m.append(["Shoulder." + s, "DEF-shoulder." + s, "clavicle_" + l, side + "Shoulder", "delta"])
		m.append(["UpperArm." + s, "DEF-upper_arm." + s, "upperarm_" + l, side + "Arm", "dir"])
		m.append(["LowerArm." + s, "DEF-forearm." + s, "lowerarm_" + l, side + "ForeArm", "dir"])
		m.append(["Wrist." + s, "DEF-hand." + s, "hand_" + l, side + "Hand", "dir"])
		for f: Array in [["Index", "f_index", "index"], ["Middle", "f_middle", "middle"], ["Ring", "f_ring", "ring"], ["Pinky", "f_pinky", "pinky"]]:
			for i: int in range(1, 4):
				m.append(["%s%d.%s" % [f[0], i, s], "DEF-%s.%02d.%s" % [f[1], i, s], "%s_%02d_%s" % [f[2], i, l], "%sHand%s%d" % [side, f[0], i], "dir"])
		for i: int in range(1, 4):
			m.append(["Thumb%d.%s" % [i, s], "DEF-thumb.%02d.%s" % [i, s], "thumb_%02d_%s" % [i, l], "%sHandThumb%d" % [side, i], "dir"])
		m.append(["UpperLeg." + s, "DEF-thigh." + s, "thigh_" + l, side + "UpLeg", "leg"])
		m.append(["LowerLeg." + s, "DEF-shin." + s, "calf_" + l, side + "Leg", "leg"])
		m.append(["Foot." + s, "DEF-foot." + s, "foot_" + l, side + "Foot", "foot"])
	_map_cache = m
	return m


## Mixamo bone / track names come through Godot's FBX import as "mixamorig_Hips" (older exports "mixamorig:Hips").
static func norm(n: String) -> String:
	return n.trim_prefix("mixamorig_").trim_prefix("mixamorig:")


# ===========================================================================
# SOURCES
# ===========================================================================
static func available(src_id: String) -> bool:
	if disabled.has(src_id):
		return false
	return not source(src_id).is_empty()


## Source data, loaded once: {"n", "parent", "idx", "rest_local", "rest_global", "order", "anims": {name: Animation},
## "files": {name: path} (mixamo, loaded lazily), "tracks": {}}. {} when the source is missing.
static func source(src_id: String) -> Dictionary:
	if _src.has(src_id):
		return _src[src_id]
	var d: Dictionary = {}
	if src_id == "mixamo":
		d = _load_mixamo()
	elif UAL_FILES.has(src_id):
		d = _load_ual(src_id)
	_src[src_id] = d
	return d


static func _load_ual(src_id: String) -> Dictionary:
	var path: String = UAL_DIR + String(UAL_FILES[src_id])
	if not ResourceLoader.exists(path):
		return {}
	var inst: Node = (load(path) as PackedScene).instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if sk == null or ap == null:
		inst.free()
		return {}
	var d: Dictionary = {"anims": {}, "files": {}, "tracks": {}}
	for a: String in ap.get_animation_list():
		d["anims"][a] = ap.get_animation(a)
	_read_skeleton(sk, d)
	inst.free()
	return d


## One FBX per clip; clip name = file stem without its "NN_" prefix ("07_Flying_Kick.fbx" -> "Flying_Kick").
## The rest skeleton comes from Y_Bot_TPose (or the first clip: every Mixamo export of one character shares it).
static func _load_mixamo() -> Dictionary:
	if not DirAccess.dir_exists_absolute(MIXAMO_DIR):
		return {}
	var files: Dictionary = {}
	for f: String in ResourceLoader.list_directory(MIXAMO_DIR):
		if not f.to_lower().ends_with(".fbx"):
			continue
		files[clip_name_of(f)] = MIXAMO_DIR + f
	if files.is_empty():
		return {}
	var rest_path: String = String(files.get(MIXAMO_REST, files.values()[0]))
	var ps: PackedScene = load(rest_path) as PackedScene
	if ps == null:
		return {}
	var inst: Node = ps.instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		inst.free()
		return {}
	var d: Dictionary = {"anims": {}, "files": files, "tracks": {}}
	_read_skeleton(sk, d)
	inst.free()
	files.erase(MIXAMO_REST)
	if not (d["idx"] as Dictionary).has("Hips"):
		push_warning("CineRetarget: %s has no mixamorig Hips bone; Mixamo source disabled" % rest_path)
		return {}
	return d


static func clip_name_of(file_name: String) -> String:
	var stem: String = file_name.get_file().get_basename()
	if stem.length() > 3 and stem[2] == "_" and stem.substr(0, 2).is_valid_int():
		return stem.substr(3)
	return stem


## Clip names of a source (sorted).
static func clips(src_id: String) -> PackedStringArray:
	var d: Dictionary = source(src_id)
	var out: PackedStringArray = []
	if d.is_empty():
		return out
	for k: String in (d["anims"] as Dictionary).keys():
		out.append(k)
	for k2: String in (d["files"] as Dictionary).keys():
		if not out.has(k2):
			out.append(k2)
	out.sort()
	return out


static func has_anim(src_id: String, anim_name: String) -> bool:
	if not available(src_id):
		return false
	var d: Dictionary = source(src_id)
	return (d["anims"] as Dictionary).has(anim_name) or (d["files"] as Dictionary).has(anim_name)


## Animation of a source (Mixamo files load on first use: the longest animation in the file, "mixamo_com").
static func get_anim(src_id: String, anim_name: String) -> Animation:
	var d: Dictionary = source(src_id)
	if d.is_empty():
		return null
	if (d["anims"] as Dictionary).has(anim_name):
		return d["anims"][anim_name]
	if not (d["files"] as Dictionary).has(anim_name):
		return null
	var ps: PackedScene = load(String(d["files"][anim_name])) as PackedScene
	var best: Animation = null
	if ps:
		var inst: Node = ps.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for a: String in ap.get_animation_list():
				var an: Animation = ap.get_animation(a)
				if best == null or an.length > best.length:
					best = an
		inst.free()
	d["anims"][anim_name] = best
	return best


static func anim_length(src_id: String, anim_name: String, bd: Dictionary = {}) -> float:
	if src_id == "native":
		var a0: Animation = (bd["native"]["anims"] as Dictionary).get(anim_name)
		return a0.length if a0 else 0.0
	var a: Animation = get_anim(src_id, anim_name)
	return a.length if a else 0.0


static func _read_skeleton(sk: Skeleton3D, d: Dictionary) -> void:
	var n: int = sk.get_bone_count()
	var parent: PackedInt32Array = []
	var names: Dictionary = {}
	var rest_local: Array[Transform3D] = []
	var rest_global: Array[Transform3D] = []
	for b: int in n:
		parent.append(sk.get_bone_parent(b))
		names[norm(sk.get_bone_name(b))] = b
		rest_local.append(sk.get_bone_rest(b))
		rest_global.append(sk.get_bone_global_rest(b))
	d["n"] = n
	d["parent"] = parent
	d["idx"] = names
	d["rest_local"] = rest_local
	d["rest_global"] = rest_global
	d["order"] = _parent_first(parent)


static func _parent_first(parent: PackedInt32Array) -> PackedInt32Array:
	var order: PackedInt32Array = []
	var done: Dictionary = {}
	while order.size() < parent.size():
		for b: int in parent.size():
			if done.has(b):
				continue
			if parent[b] < 0 or done.has(parent[b]):
				order.append(b)
				done[b] = true
	return order


## Bone index -> [rotation track, position track] of an animation (cached per source and clip).
static func _tracks_of(d: Dictionary, anim_name: String, a: Animation) -> Dictionary:
	var cache: Dictionary = d["tracks"]
	if cache.has(anim_name):
		return cache[anim_name]
	var idx: Dictionary = d["idx"]
	var out: Dictionary = {}
	for t: int in a.get_track_count():
		var bone: String = norm(String(a.track_get_path(t).get_concatenated_subnames()))
		if not idx.has(bone):
			continue
		var b: int = idx[bone]
		var e: Array = out.get(b, [-1, -1])
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				e[0] = t
			Animation.TYPE_POSITION_3D:
				e[1] = t
		out[b] = e
	cache[anim_name] = out
	return out


## Source globals (skeleton space) at clip time tt.
static func _src_globals(src: Dictionary, a: Animation, tracks: Dictionary, tt: float) -> Array[Transform3D]:
	var n: int = src["n"]
	var sp: PackedInt32Array = src["parent"]
	var srl: Array = src["rest_local"]
	var sg: Array[Transform3D] = []
	sg.resize(n)
	for b: int in src["order"]:
		var loc: Transform3D = srl[b]
		if tracks.has(b):
			var e: Array = tracks[b]
			if e[0] >= 0:
				loc.basis = Basis(a.rotation_track_interpolate(e[0], tt))
			if e[1] >= 0:
				loc.origin = a.position_track_interpolate(e[1], tt)
		sg[b] = sg[sp[b]] * loc if sp[b] >= 0 else loc
	return sg


## Position of one source bone (skeleton space) at clip time tt: walks the parent chain only.
static func _src_bone_pos(src: Dictionary, a: Animation, tracks: Dictionary, bone: int, tt: float) -> Vector3:
	var xf := Transform3D.IDENTITY
	var b: int = bone
	var sp: PackedInt32Array = src["parent"]
	while b >= 0:
		var loc: Transform3D = src["rest_local"][b]
		if tracks.has(b):
			var e: Array = tracks[b]
			if e[0] >= 0:
				loc.basis = Basis(a.rotation_track_interpolate(e[0], tt))
			if e[1] >= 0:
				loc.origin = a.position_track_interpolate(e[1], tt)
		xf = loc * xf
		b = sp[b]
	return xf.origin


# ===========================================================================
# BINDING TO A TARGET SKELETON
# ===========================================================================
## Retarget data for one target skeleton. ap: the body file's own AnimationPlayer (native clips). Source bindings are made
## lazily on the first sample of each source (_ensure_src).
static func bind(sk: Skeleton3D, ap: AnimationPlayer) -> Dictionary:
	var t: Dictionary = {}
	_read_skeleton(sk, t)
	var rest_rot: Array[Quaternion] = []
	var rest_pos: Array[Vector3] = []
	for b: int in t["n"]:
		rest_rot.append((t["rest_local"][b] as Transform3D).basis.get_rotation_quaternion())
		rest_pos.append((t["rest_local"][b] as Transform3D).origin)
	t["rest_rot"] = rest_rot
	t["rest_pos"] = rest_pos
	var nat: Dictionary = {"anims": {}, "idx": t["idx"], "tracks": {}}
	if ap:
		for a: String in ap.get_animation_list():
			nat["anims"][a] = ap.get_animation(a)
	t["native"] = nat
	return t


static func _ensure_src(t: Dictionary, src_id: String) -> Dictionary:
	if t.has(src_id):
		return t[src_id]
	var src: Dictionary = source(src_id)
	var d: Dictionary = {} if src.is_empty() else _bind_src(t, src, int(COL[src_id]))
	t[src_id] = d
	return d


static func _bind_src(t: Dictionary, src: Dictionary, col: int) -> Dictionary:
	var tidx: Dictionary = t["idx"]
	var sidx: Dictionary = src["idx"]
	var tg: Array = t["rest_global"]
	var sg: Array = src["rest_global"]
	var maps: Array = []        # [target bone, source bone, O (Basis)]
	for row: Array in bone_map():
		if not (tidx.has(row[0]) and sidx.has(row[col])):
			continue
		var tb: int = tidx[row[0]]
		var sb: int = sidx[row[col]]
		var rt: Basis = (tg[tb] as Transform3D).basis.orthonormalized()
		var rs: Basis = (sg[sb] as Transform3D).basis.orthonormalized()
		var a: Basis = _align(String(row[4]), String(row[0]), rt, rs, t)
		maps.append([tb, sb, (rs.inverse() * a * rt).orthonormalized()])
	var d: Dictionary = {"maps": maps}
	var tl: int = tidx["UpperLeg.L"]
	var tr: int = tidx["UpperLeg.R"]
	var sl: int = sidx[_src_name("UpperLeg.L", col)]
	var sr: int = sidx[_src_name("UpperLeg.R", col)]
	var mid_t: Vector3 = ((tg[tl] as Transform3D).origin + (tg[tr] as Transform3D).origin) * 0.5
	var mid_s: Vector3 = ((sg[sl] as Transform3D).origin + (sg[sr] as Transform3D).origin) * 0.5
	var knee_t: Vector3 = (tg[tidx["LowerLeg.L"]] as Transform3D).origin
	var ankle_t: Vector3 = _ankle_rest(t, "L")
	var len_t: float = knee_t.distance_to((tg[tl] as Transform3D).origin) + ANKLE_DOWN_SHIN + ankle_t.y
	var s_shin: Vector3 = (sg[sidx[_src_name("LowerLeg.L", col)]] as Transform3D).origin
	var s_foot: Vector3 = (sg[sidx[_src_name("Foot.L", col)]] as Transform3D).origin
	var len_s: float = s_shin.distance_to((sg[sl] as Transform3D).origin) + s_foot.distance_to(s_shin) + s_foot.y
	var k: float = len_t / len_s
	d["k"] = k
	d["src_thighs"] = [sl, sr]
	d["src_hips"] = sidx[_src_name("Body", col)]
	d["hip_off"] = Vector3(mid_t.x - k * mid_s.x, 0.0, mid_t.z - k * mid_s.z)
	var body: int = tidx["Body"]
	d["body"] = body
	d["hip_c"] = (tg[body] as Transform3D).basis.orthonormalized().inverse() * (mid_t - (tg[body] as Transform3D).origin)
	return d


static func _src_name(target: String, col: int) -> String:
	for row: Array in bone_map():
		if row[0] == target:
			return String(row[col])
	return ""


## Target ankle at rest (skeleton space): ANKLE_DOWN_SHIN along the shin's Y axis from the knee.
static func _ankle_rest(t: Dictionary, s: String) -> Vector3:
	var lo: Transform3D = t["rest_global"][t["idx"]["LowerLeg." + s]]
	return lo.origin + lo.basis.y.normalized() * ANKLE_DOWN_SHIN


## A_b: model-frame rotation taking the target bone from its rest to the pose equivalent to the source rest.
static func _align(mode: String, tname: String, rt: Basis, rs: Basis, t: Dictionary) -> Basis:
	match mode:
		"yaw":
			var ft := Vector3(rt.z.x, 0.0, rt.z.z).normalized()
			var fs := Vector3(rs.z.x, 0.0, rs.z.z).normalized()
			return Basis(Quaternion(ft, fs))
		"dir":
			return Basis(Quaternion(rt.y.normalized(), rs.y.normalized()))
		"leg":
			var s: String = tname.substr(tname.length() - 1)
			var ft1: Basis = _frame(rt.y, _knee_dir_rest(t, s))
			var fs1: Basis = _frame(rs.y, Vector3(0.0, 0.0, 1.0))
			return fs1 * ft1.inverse()
		"foot":
			var ft2: Basis = _frame_fwd(Vector3(rt.y.x, 0.0, rt.y.z))
			var fs2: Basis = _frame_fwd(Vector3(rs.y.x, 0.0, rs.y.z))
			return fs2 * ft2.inverse()
	return Basis.IDENTITY


static func _knee_dir_rest(t: Dictionary, s: String) -> Vector3:
	var hip: Vector3 = (t["rest_global"][t["idx"]["UpperLeg." + s]] as Transform3D).origin
	var knee: Vector3 = (t["rest_global"][t["idx"]["LowerLeg." + s]] as Transform3D).origin
	var ankle: Vector3 = _ankle_rest(t, s)
	var axis: Vector3 = (ankle - hip).normalized()
	var off: Vector3 = (knee - hip) - axis * (knee - hip).dot(axis)
	if off.length() < 0.02:
		return Vector3(0.0, 0.0, 1.0)
	return off.normalized()


static func _frame(y: Vector3, z_hint: Vector3) -> Basis:
	var yy: Vector3 = y.normalized()
	var x: Vector3 = yy.cross(z_hint).normalized()
	var z: Vector3 = x.cross(yy).normalized()
	return Basis(x, yy, z)


static func _frame_fwd(fwd: Vector3) -> Basis:
	var z: Vector3 = fwd.normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


# ===========================================================================
# SAMPLING
# ===========================================================================
## Local pose of the target skeleton for clip anim_name of source src_id at clip time t (seconds).
## root: {"xz": bool, "y": bool, "ref": float} removes the source hips' displacement since clip time ref.
## Returns {"rot": {bone: Quaternion}, "pos": {bone: Vector3}}; {} pose parts = rest. Empty dicts if the clip is missing.
static func sample(bd: Dictionary, src_id: String, anim_name: String, t: float, loop: bool = false, root: Dictionary = {}) -> Dictionary:
	if src_id == "native":
		return sample_native(bd, anim_name, t, loop)
	var ld: Dictionary = _ensure_src(bd, src_id)
	var a: Animation = get_anim(src_id, anim_name)
	if ld.is_empty() or a == null:
		return {"rot": {}, "pos": {}}
	var src: Dictionary = source(src_id)
	var tt: float = _clip_time(a, t, loop)
	var tracks: Dictionary = _tracks_of(src, anim_name, a)
	var sg: Array[Transform3D] = _src_globals(src, a, tracks, tt)
	var tg_rot: Dictionary = {}
	for m: Array in ld["maps"]:
		tg_rot[m[0]] = sg[m[1]].basis.orthonormalized() * (m[2] as Basis)
	var th: Array = ld["src_thighs"]
	var mid_s: Vector3 = (sg[th[0]].origin + sg[th[1]].origin) * 0.5
	var strip_xz: bool = bool(root.get("xz", false))
	var strip_y: bool = bool(root.get("y", false))
	if strip_xz or strip_y:
		var h: int = ld["src_hips"]
		var ref: Vector3 = _src_bone_pos(src, a, tracks, h, _clip_time(a, float(root.get("ref", 0.0)), loop))
		var dlt: Vector3 = sg[h].origin - ref
		mid_s -= Vector3(dlt.x if strip_xz else 0.0, dlt.y if strip_y else 0.0, dlt.z if strip_xz else 0.0)
	var k: float = ld["k"]
	var mid_t: Vector3 = mid_s * k + (ld["hip_off"] as Vector3)
	var body: int = ld["body"]
	var body_basis: Basis = tg_rot.get(body, (bd["rest_global"][body] as Transform3D).basis)
	var body_pos: Vector3 = mid_t - body_basis * (ld["hip_c"] as Vector3)
	var tn: int = bd["n"]
	var tp: PackedInt32Array = bd["parent"]
	var trl: Array = bd["rest_local"]
	var cur: Array[Transform3D] = []
	cur.resize(tn)
	var out_rot: Dictionary = {}
	var out_pos: Dictionary = {}
	var feet: Dictionary = {}
	for b: int in bd["order"]:
		var pg: Transform3D = cur[tp[b]] if tp[b] >= 0 else Transform3D.IDENTITY
		var loc: Transform3D = trl[b]
		if b == body:
			loc = pg.affine_inverse() * Transform3D(body_basis, body_pos)
			out_pos[b] = loc.origin
			out_rot[b] = loc.basis.get_rotation_quaternion()
		elif tg_rot.has(b):
			var nm: String = _name_of(bd, b)
			if nm.begins_with("Foot."):
				feet[nm.substr(5)] = b
			else:
				loc.basis = pg.basis.orthonormalized().inverse() * (tg_rot[b] as Basis)
				out_rot[b] = loc.basis.get_rotation_quaternion()
		cur[b] = pg * loc
	for s: String in feet.keys():
		var fb: int = feet[s]
		var lb: int = bd["idx"]["LowerLeg." + s]
		var l0: Transform3D = bd["rest_global"][lb]
		var a_rest: Vector3 = _ankle_rest(bd, s)
		var a_now: Vector3 = cur[lb] * (l0.affine_inverse() * a_rest)
		var f0: Transform3D = bd["rest_global"][fb]
		var fbasis: Basis = tg_rot[fb]
		var forigin: Vector3 = a_now + fbasis * (f0.basis.orthonormalized().inverse() * (f0.origin - a_rest))
		var pf: int = tp[fb]
		var pgf: Transform3D = cur[pf] if pf >= 0 else Transform3D.IDENTITY
		var locf: Transform3D = pgf.affine_inverse() * Transform3D(fbasis, forigin)
		out_rot[fb] = locf.basis.get_rotation_quaternion()
		out_pos[fb] = locf.origin
	return {"rot": out_rot, "pos": out_pos}


static func _name_of(bd: Dictionary, b: int) -> String:
	if not bd.has("names"):
		var arr: PackedStringArray = []
		arr.resize(bd["n"])
		for nm: String in (bd["idx"] as Dictionary).keys():
			arr[bd["idx"][nm]] = nm
		bd["names"] = arr
	return (bd["names"] as PackedStringArray)[b]


static func _clip_time(a: Animation, t: float, loop: bool) -> float:
	if loop and a.length > 0.0:
		return fposmod(t, a.length)
	return clampf(t, 0.0, a.length)


## Clip inside the body file: tracks already match the skeleton.
static func sample_native(bd: Dictionary, anim_name: String, t: float, loop: bool = false) -> Dictionary:
	var nat: Dictionary = bd["native"]
	var a: Animation = (nat["anims"] as Dictionary).get(anim_name)
	if a == null:
		return {"rot": {}, "pos": {}}
	var tt: float = _clip_time(a, t, loop)
	var tracks: Dictionary = _tracks_of(nat, anim_name, a)
	var out_rot: Dictionary = {}
	var out_pos: Dictionary = {}
	for b: int in tracks.keys():
		var e: Array = tracks[b]
		if e[0] >= 0:
			out_rot[b] = a.rotation_track_interpolate(e[0], tt)
		if e[1] >= 0:
			out_pos[b] = a.position_track_interpolate(e[1], tt)
	return {"rot": out_rot, "pos": out_pos}


## Blend two local poses (w = 0 -> a, 1 -> b); missing bones use the rest pose.
static func blend(bd: Dictionary, a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	var rr: Array = bd["rest_rot"]
	var rp: Array = bd["rest_pos"]
	var out_rot: Dictionary = {}
	var out_pos: Dictionary = {}
	var ar: Dictionary = a["rot"]
	var br: Dictionary = b["rot"]
	for k: int in ar.keys():
		out_rot[k] = (ar[k] as Quaternion).slerp(br.get(k, rr[k]), w)
	for k: int in br.keys():
		if not ar.has(k):
			out_rot[k] = (rr[k] as Quaternion).slerp(br[k], w)
	var ap_: Dictionary = a["pos"]
	var bp: Dictionary = b["pos"]
	for k: int in ap_.keys():
		out_pos[k] = (ap_[k] as Vector3).lerp(bp.get(k, rp[k]), w)
	for k: int in bp.keys():
		if not ap_.has(k):
			out_pos[k] = (rp[k] as Vector3).lerp(bp[k], w)
	return {"rot": out_rot, "pos": out_pos}


## Write a pose to the skeleton: every bone (bones without a key go to rest).
static func apply(sk: Skeleton3D, bd: Dictionary, pose: Dictionary) -> void:
	var rr: Array = bd["rest_rot"]
	var rp: Array = bd["rest_pos"]
	var pr: Dictionary = pose["rot"]
	var pp: Dictionary = pose["pos"]
	for b: int in bd["n"]:
		sk.set_bone_pose_rotation(b, pr.get(b, rr[b]))
		sk.set_bone_pose_position(b, pp.get(b, rp[b]))
	CharacterBuilder._mark_bone_poses_dirty(sk)
