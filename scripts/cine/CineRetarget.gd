# File: res://scripts/cine/CineRetarget.gd
# Retarget animation của hai thư viện Quaternius Universal Animation Library (CC0, assets/models/quaternius/anim_library/)
# lên thân Quaternius Modular (xương Hips/Torso/Chest/UpperArm.L/... của CharacterBuilder) – nguyên mẫu cinematic.
#   • ual1: UAL1 (xương Rigify "DEF-*"), ual2: UAL2 (tên kiểu UE mannequin pelvis/spine_01/upperarm_l/...). Hai thư viện có
#     CÙNG khung xương (cùng vị trí khớp, cùng tư thế nghỉ chữ T), chỉ khác tên.
#   • native: animation có sẵn trong chính tệp thân (Kick_Right, Punch_Right, Roll, Death...) – không cần retarget.
#
# Cách retarget (một lần mỗi skeleton đích, xem bind()):
#   Thân đích có tư thế nghỉ "lệch" (tay buông chéo, hông xoay ~27°, chân trái xoay ngoài, đang bước dở) còn nguồn nghỉ chữ T.
#   Với mỗi xương đích b ứng với xương nguồn s, tìm phép xoay A_b (hệ mô hình, cả hai mô hình nhìn +Z, +X = bên trái nhân
#   vật) đưa xương đích từ tư thế nghỉ của nó về "tư thế tương đương" với tư thế nghỉ của nguồn, rồi
#       O_b = R_s⁻¹ · A_b · R_t           (R = xoay toàn cục lúc nghỉ, hằng số)
#       G_t(t) = G_s(t) · O_b              (G = xoay toàn cục ở thời điểm t)
#   tức là xương đích quay đúng bằng phần quay của xương nguồn so với tư thế tương đương. A_b theo loại xương:
#     "delta": A = I (thân trên, cổ, đầu, xương đòn: hai tư thế nghỉ đã tương đương);
#     "yaw"  : chỉ xoay quanh Y cho trục Z (phía trước) của xương khớp nhau (Body/Hips/Abdomen: bỏ góc xoay hông 27°);
#     "dir"  : cung ngắn nhất đưa trục Y (dọc xương) đích về trục Y nguồn (tay, cẳng tay, bàn tay, ngón tay);
#     "leg"  : khung (trục dọc xương, hướng mũi gối) đích -> nguồn (đùi, ống chân: mũi gối luôn hướng trước);
#     "foot" : khung (lên trên, mũi giày nằm ngang) đích -> nguồn.
#   Vị trí: tâm hai khớp háng của đích = tâm khớp háng nguồn × k (k = tỉ lệ chiều dài chân), Body dời theo. Bàn chân đích
#   (Foot.L/R là đích IK con của Root) gắn cứng vào cổ chân của ống chân (như CharacterBuilder._apply_bone_pose) với hướng
#   lấy từ bàn chân nguồn.
# Kết quả là tư thế CỤC BỘ {xương: Quaternion / vị trí} (sample / sample_native), trộn được (blend) rồi đặt lên skeleton
# (apply). Lớp tư thế tự dựng (đá bay, cắt kéo...) đè lên sau bằng CharacterBuilder._apply_bone_pose của game.
class_name CineRetarget
extends RefCounted

const LIB_DIR: String = "res://assets/models/quaternius/anim_library/"
const LIB_FILES: Dictionary = {"ual1": "ual1_AnimationLibrary_Godot_Standard.glb", "ual2": "ual2_UAL2_Standard.glb"}
const ANKLE_DOWN_SHIN: float = 0.42   # = CharacterBuilder.ANKLE_DOWN_SHIN (cổ chân cách gối dọc ống chân)

static var _libs: Dictionary = {}
static var _map_cache: Array = []


## Bảng xương: [đích, nguồn ual1, nguồn ual2, loại]. Ngón tay sinh tự động.
static func bone_map() -> Array:
	if not _map_cache.is_empty():
		return _map_cache
	var m: Array = [
		["Body", "DEF-hips", "pelvis", "yaw"], ["Hips", "DEF-hips", "pelvis", "yaw"],
		["Abdomen", "DEF-spine.001", "spine_01", "yaw"], ["Torso", "DEF-spine.002", "spine_02", "delta"],
		["Chest", "DEF-spine.003", "spine_03", "delta"], ["Neck", "DEF-neck", "neck_01", "delta"],
		["Head", "DEF-head", "Head", "delta"],
	]
	for s: String in ["L", "R"]:
		var l: String = s.to_lower()
		m.append(["Shoulder." + s, "DEF-shoulder." + s, "clavicle_" + l, "delta"])
		m.append(["UpperArm." + s, "DEF-upper_arm." + s, "upperarm_" + l, "dir"])
		m.append(["LowerArm." + s, "DEF-forearm." + s, "lowerarm_" + l, "dir"])
		m.append(["Wrist." + s, "DEF-hand." + s, "hand_" + l, "dir"])
		for f: Array in [["Index", "f_index", "index"], ["Middle", "f_middle", "middle"], ["Ring", "f_ring", "ring"], ["Pinky", "f_pinky", "pinky"]]:
			for i: int in range(1, 4):
				m.append(["%s%d.%s" % [f[0], i, s], "DEF-%s.%02d.%s" % [f[1], i, s], "%s_%02d_%s" % [f[2], i, l], "dir"])
		for i: int in range(1, 4):
			m.append(["Thumb%d.%s" % [i, s], "DEF-thumb.%02d.%s" % [i, s], "thumb_%02d_%s" % [i, l], "dir"])
		m.append(["UpperLeg." + s, "DEF-thigh." + s, "thigh_" + l, "leg"])
		m.append(["LowerLeg." + s, "DEF-shin." + s, "calf_" + l, "leg"])
		m.append(["Foot." + s, "DEF-foot." + s, "foot_" + l, "foot"])
	_map_cache = m
	return m


# ===========================================================================
# THƯ VIỆN NGUỒN
# ===========================================================================
## Dữ liệu một thư viện (nạp một lần): animation, cây xương, tư thế nghỉ cục bộ / toàn cục.
static func lib(name: String) -> Dictionary:
	if _libs.has(name):
		return _libs[name]
	var d: Dictionary = {}
	var ps: PackedScene = load(LIB_DIR + String(LIB_FILES[name]))
	var inst: Node = ps.instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	d["anims"] = {}
	for a: String in ap.get_animation_list():
		d["anims"][a] = ap.get_animation(a)
	_read_skeleton(sk, d)
	d["tracks"] = {}
	inst.free()
	_libs[name] = d
	return d


static func _read_skeleton(sk: Skeleton3D, d: Dictionary) -> void:
	var n: int = sk.get_bone_count()
	var parent: PackedInt32Array = []
	var names: Dictionary = {}
	var rest_local: Array[Transform3D] = []
	var rest_global: Array[Transform3D] = []
	for b: int in n:
		parent.append(sk.get_bone_parent(b))
		names[sk.get_bone_name(b)] = b
		rest_local.append(sk.get_bone_rest(b))
		rest_global.append(sk.get_bone_global_rest(b))
	d["n"] = n
	d["parent"] = parent
	d["idx"] = names
	d["rest_local"] = rest_local
	d["rest_global"] = rest_global
	d["order"] = _parent_first(parent)


## Thứ tự duyệt xương cha trước con.
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


## Track xoay / vị trí của từng xương trong animation (theo tên xương = subname của đường dẫn track).
static func _tracks_of(d: Dictionary, anim_name: String) -> Dictionary:
	var cache: Dictionary = d["tracks"]
	if cache.has(anim_name):
		return cache[anim_name]
	var a: Animation = d["anims"][anim_name]
	var idx: Dictionary = d["idx"]
	var out: Dictionary = {}   # chỉ số xương -> [track xoay, track vị trí]
	for t: int in a.get_track_count():
		var bone: String = String(a.track_get_path(t).get_concatenated_subnames())
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


static func has_anim(lib_name: String, anim_name: String) -> bool:
	return (lib(lib_name)["anims"] as Dictionary).has(anim_name)


static func anim_length(lib_name: String, anim_name: String, bind_d: Dictionary = {}) -> float:
	if lib_name == "native":
		return (bind_d["native"]["anims"][anim_name] as Animation).length
	return (lib(lib_name)["anims"][anim_name] as Animation).length


# ===========================================================================
# GẮN VỚI SKELETON ĐÍCH
# ===========================================================================
## Dữ liệu retarget cho một skeleton đích (thân Quaternius Modular). ap: AnimationPlayer của chính tệp thân (clip native).
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
	for ln: String in LIB_FILES.keys():
		t[ln] = _bind_lib(t, ln)
	return t


static func _bind_lib(t: Dictionary, ln: String) -> Dictionary:
	var src: Dictionary = lib(ln)
	var col: int = 1 if ln == "ual1" else 2
	var tidx: Dictionary = t["idx"]
	var sidx: Dictionary = src["idx"]
	var tg: Array = t["rest_global"]
	var sg: Array = src["rest_global"]
	var maps: Array = []        # [xương đích, xương nguồn, O (Basis)]
	var by_target: Dictionary = {}
	for row: Array in bone_map():
		if not (tidx.has(row[0]) and sidx.has(row[col])):
			continue
		var tb: int = tidx[row[0]]
		var sb: int = sidx[row[col]]
		var rt: Basis = (tg[tb] as Transform3D).basis.orthonormalized()
		var rs: Basis = (sg[sb] as Transform3D).basis.orthonormalized()
		var a: Basis = _align(String(row[3]), String(row[0]), rt, rs, t, src, col)
		var o: Basis = (rs.inverse() * a * rt).orthonormalized()
		maps.append([tb, sb, o])
		by_target[tb] = sb
	var d: Dictionary = {"maps": maps, "by_target": by_target}
	# --- vị trí: tâm khớp háng, tỉ lệ chân, cổ chân
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


## Cổ chân đích lúc nghỉ (hệ skeleton): cách gối ANKLE_DOWN_SHIN dọc trục Y của ống chân.
static func _ankle_rest(t: Dictionary, s: String) -> Vector3:
	var lo: Transform3D = t["rest_global"][t["idx"]["LowerLeg." + s]]
	return lo.origin + lo.basis.y.normalized() * ANKLE_DOWN_SHIN


## A_b: xoay (hệ mô hình) đưa xương đích từ tư thế nghỉ của nó về tư thế tương đương tư thế nghỉ của nguồn.
static func _align(mode: String, tname: String, rt: Basis, rs: Basis, t: Dictionary, src: Dictionary, col: int) -> Basis:
	match mode:
		"yaw":
			var ft := Vector3(rt.z.x, 0.0, rt.z.z).normalized()
			var fs := Vector3(rs.z.x, 0.0, rs.z.z).normalized()
			return Basis(Quaternion(ft, fs))
		"dir":
			return Basis(Quaternion(rt.y.normalized(), rs.y.normalized()))
		"leg":
			var s: String = tname.substr(tname.length() - 1)
			var knee_dir: Vector3 = _knee_dir_rest(t, s)
			var ft: Basis = _frame(rt.y, knee_dir)
			var fs: Basis = _frame(rs.y, Vector3(0.0, 0.0, 1.0))
			return fs * ft.inverse()
		"foot":
			var ft2: Basis = _frame_fwd(Vector3(rt.y.x, 0.0, rt.y.z))
			var fs2: Basis = _frame_fwd(Vector3(rs.y.x, 0.0, rs.y.z))
			return fs2 * ft2.inverse()
	return Basis.IDENTITY


## Hướng mũi gối của chân đích lúc nghỉ: phần vuông góc với đường háng-cổ chân của vị trí gối (chân gần thẳng -> +Z).
static func _knee_dir_rest(t: Dictionary, s: String) -> Vector3:
	var hip: Vector3 = (t["rest_global"][t["idx"]["UpperLeg." + s]] as Transform3D).origin
	var knee: Vector3 = (t["rest_global"][t["idx"]["LowerLeg." + s]] as Transform3D).origin
	var ankle: Vector3 = _ankle_rest(t, s)
	var axis: Vector3 = (ankle - hip).normalized()
	var off: Vector3 = (knee - hip) - axis * (knee - hip).dot(axis)
	if off.length() < 0.02:
		return Vector3(0.0, 0.0, 1.0)
	return off.normalized()


## Khung trực chuẩn: cột Y = y, cột Z gần z_hint nhất.
static func _frame(y: Vector3, z_hint: Vector3) -> Basis:
	var yy: Vector3 = y.normalized()
	var x: Vector3 = yy.cross(z_hint).normalized()
	var z: Vector3 = x.cross(yy).normalized()
	return Basis(x, yy, z)


## Khung bàn chân: Y lên trên, Z = mũi giày (nằm ngang).
static func _frame_fwd(fwd: Vector3) -> Basis:
	var z: Vector3 = fwd.normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


# ===========================================================================
# LẤY MẪU
# ===========================================================================
## Tư thế cục bộ của skeleton đích cho animation anim_name của thư viện lib_name ở thời điểm t (giây clip).
## Trả {"rot": {xương: Quaternion}, "pos": {xương: Vector3}}; xương không có khoá = tư thế nghỉ.
static func sample(bd: Dictionary, lib_name: String, anim_name: String, t: float, loop: bool = false) -> Dictionary:
	if lib_name == "native":
		return sample_native(bd, anim_name, t, loop)
	var src: Dictionary = lib(lib_name)
	var a: Animation = src["anims"][anim_name]
	var tt: float = _clip_time(a, t, loop)
	var tracks: Dictionary = _tracks_of(src, anim_name)
	# --- toàn cục của xương nguồn
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
	# --- xoay toàn cục của xương đích
	var ld: Dictionary = bd[lib_name]
	var tg_rot: Dictionary = {}
	for m: Array in ld["maps"]:
		tg_rot[m[0]] = sg[m[1]].basis.orthonormalized() * (m[2] as Basis)
	# --- vị trí Body: tâm khớp háng = tâm khớp háng nguồn × k
	var th: Array = ld["src_thighs"]
	var mid_s: Vector3 = (sg[th[0]].origin + sg[th[1]].origin) * 0.5
	var k: float = ld["k"]
	var mid_t: Vector3 = mid_s * k + (ld["hip_off"] as Vector3)
	var body: int = ld["body"]
	var body_basis: Basis = tg_rot.get(body, (bd["rest_global"][body] as Transform3D).basis)
	var body_pos: Vector3 = mid_t - body_basis * (ld["hip_c"] as Vector3)
	# --- đổi sang cục bộ theo thứ tự cha trước con
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
	# --- bàn chân (đích IK con của Root): cổ chân theo ống chân, hướng theo bàn chân nguồn
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


## Clip có sẵn trong tệp thân: track đã đúng skeleton, lấy thẳng tư thế cục bộ.
static func sample_native(bd: Dictionary, anim_name: String, t: float, loop: bool = false) -> Dictionary:
	var nat: Dictionary = bd["native"]
	var a: Animation = nat["anims"][anim_name]
	var tt: float = _clip_time(a, t, loop)
	var tracks: Dictionary = _tracks_of(nat, anim_name)
	var out_rot: Dictionary = {}
	var out_pos: Dictionary = {}
	for b: int in tracks.keys():
		var e: Array = tracks[b]
		if e[0] >= 0:
			out_rot[b] = a.rotation_track_interpolate(e[0], tt)
		if e[1] >= 0:
			out_pos[b] = a.position_track_interpolate(e[1], tt)
	return {"rot": out_rot, "pos": out_pos}


## Trộn hai tư thế cục bộ (w = 0 -> a, 1 -> b); xương thiếu khoá dùng tư thế nghỉ.
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


## Đặt tư thế lên skeleton: mọi xương (xương không có khoá về tư thế nghỉ).
static func apply(sk: Skeleton3D, bd: Dictionary, pose: Dictionary) -> void:
	var rr: Array = bd["rest_rot"]
	var rp: Array = bd["rest_pos"]
	var pr: Dictionary = pose["rot"]
	var pp: Dictionary = pose["pos"]
	for b: int in bd["n"]:
		sk.set_bone_pose_rotation(b, pr.get(b, rr[b]))
		sk.set_bone_pose_position(b, pp.get(b, rp[b]))
	CharacterBuilder._mark_bone_poses_dirty(sk)
