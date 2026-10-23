# File: res://scripts/cine/CineActor.gd
# Một diễn viên của cinematic (nguyên mẫu): người PS2 thật của game (CharacterBuilder, thân Quaternius rigged, animate=false)
# điều khiển hoàn toàn bằng thời gian truyện s (giây "trong truyện", chạy chậm khi slow-mo, đứng yên khi đóng băng).
# Mọi thứ là hàm thuần của s (tua tới bất kỳ thời điểm nào để chụp ảnh tĩnh, không trạng thái tích luỹ):
#   • clip  : animation thư viện (ual1 / ual2 / native) qua CineRetarget, hoà chéo giữa hai clip liền nhau;
#   • override: tư thế tự dựng {khớp: Euler hệ nhân vật} đè lên bằng CharacterBuilder._apply_bone_pose (hàm xương của game)
#               ("abs", trộn theo trọng số) hoặc cộng thêm bằng CharacterBuilder._char_rot_local ("add");
#   • key   : vị trí trên đất + hướng (yaw tích luỹ, quay được nhiều vòng) + xoay quanh tâm khối "spin" (lộn, nằm ngang
#             trên không) với kiểu nội suy từng đoạn (linear / smooth / in / out) và cung bay "arc" (độ cao parabol);
#   • expr  : ô biểu cảm của đầu PS2.
class_name CineActor
extends Node3D

## Độ cao tâm xoay "spin" (m) – gần tâm khối người đứng; lộn / nghiêng trên không xoay quanh điểm này.
const PIVOT_Y: float = 0.95

var body: Node3D
var sk: Skeleton3D
var bd: Dictionary
var spin: Node3D
var face_mat: StandardMaterial3D
var clips: Array = []
var overrides: Array = []
var keys: Array = []
var exprs: Array = []
var last_s: float = 0.0


## Dựng nhân vật (opts của CharacterBuilder.build; luôn rigged, animate=false để không Animator nào ghi đè xương).
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
	# vật liệu mặt riêng (vật liệu mặt PS2 dùng chung theo tông da: đổi ô biểu cảm không được lan sang người khác)
	var face: MeshInstance3D = CharacterBuilder.get_pivot(body, "face_mesh") as MeshInstance3D
	if face and face.material_override is StandardMaterial3D:
		face_mat = (face.material_override as StandardMaterial3D).duplicate()
		face.material_override = face_mat


# ---------------------------------------------------------------------------
# Kịch bản
# ---------------------------------------------------------------------------
## Clip bắt đầu ở thời gian truyện s: anim của lib, từ giây clip `from`, tốc độ `speed`, hoà chéo `fade` giây truyện.
func clip(s: float, lib_name: String, anim: String, from: float = 0.0, speed: float = 1.0, loop: bool = false, fade: float = 0.12) -> void:
	clips.append({"s": s, "lib": lib_name, "anim": anim, "from": from, "speed": speed, "loop": loop, "fade": fade})
	clips.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## Vị trí / hướng tại s. mode: kiểu nội suy của đoạn KẾT THÚC ở khoá này; arc: độ cao cung bay thêm vào (m).
func key(s: float, pos: Vector3, yaw: float, spin_euler: Vector3 = Vector3.ZERO, mode: String = "smooth", arc: float = 0.0) -> void:
	keys.append({"s": s, "pos": pos, "yaw": yaw, "spin": spin_euler, "mode": mode, "arc": arc})
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


## Tư thế tự dựng trong [s0, s1] (mờ vào / ra fade_in / fade_out giây truyện). pose: Callable(u: float) -> Dictionary
## {khớp CharacterBuilder: Euler hệ nhân vật}, u = tiến độ 0..1 trong [s0, s1]. mode "abs" | "add".
func override(s0: float, s1: float, pose: Callable, fade_in: float = 0.08, fade_out: float = 0.12, mode: String = "abs") -> void:
	overrides.append({"s0": s0, "s1": s1, "pose": pose, "fi": fade_in, "fo": fade_out, "mode": mode})


func expr(s: float, name: String) -> void:
	exprs.append({"s": s, "e": name})
	exprs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


# ---------------------------------------------------------------------------
# Đánh giá tại thời gian truyện s
# ---------------------------------------------------------------------------
func evaluate(s: float) -> void:
	last_s = s
	_eval_transform(s)
	_eval_pose(s)
	_eval_expr(s)


func _eval_transform(s: float) -> void:
	if keys.is_empty():
		return
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
		# cung bay: ngang tuyến tính theo thời gian, đứng = nội suy + parabol (đúng quỹ đạo rơi tự do)
		p = (k0["pos"] as Vector3).lerp(k1["pos"], u)
		p.y += 4.0 * arc * u * (1.0 - u)
	position = p
	rotation.y = lerpf(float(k0["yaw"]), float(k1["yaw"]), e)
	spin.rotation = (k0["spin"] as Vector3).lerp(k1["spin"], e)


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


func _clip_pose(c: Dictionary, s: float) -> Dictionary:
	var t: float = float(c["from"]) + (s - float(c["s"])) * float(c["speed"])
	return CineRetarget.sample(bd, String(c["lib"]), String(c["anim"]), t, bool(c["loop"]))


func _eval_pose(s: float) -> void:
	if clips.is_empty():
		return
	var i: int = 0
	for j: int in clips.size():
		if float(clips[j]["s"]) <= s:
			i = j
	var cur: Dictionary = clips[i]
	var pose: Dictionary = _clip_pose(cur, s)
	var dt: float = s - float(cur["s"])
	var fade: float = float(cur["fade"])
	if i > 0 and dt < fade and fade > 0.0:
		var prev: Dictionary = clips[i - 1]
		var w: float = clampf(dt / fade, 0.0, 1.0)
		pose = CineRetarget.blend(bd, _clip_pose(prev, s), pose, w * w * (3.0 - 2.0 * w))
	CineRetarget.apply(sk, bd, pose)
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
		var u: float = clampf((s - s0) / maxf(s1 - s0, 0.0001), 0.0, 1.0)
		var cpose: Dictionary = (o["pose"] as Callable).call(u)
		if String(o["mode"]) == "add":
			_add_pose(cpose, w2)
		else:
			CharacterBuilder._apply_bone_pose(sk, cpose, w2)


## Xoay cộng thêm (Euler hệ nhân vật × w) lên tư thế hiện tại – cùng phép với RigAnimator._add_rot (_char_rot_local).
func _add_pose(cpose: Dictionary, w: float) -> void:
	for k: String in cpose.keys():
		if not CharacterBuilder.BONE_OF.has(k):
			continue
		var b: int = sk.find_bone(String(CharacterBuilder.BONE_OF[k]))
		if b < 0:
			continue
		var r: Basis = CharacterBuilder._char_rot_local(sk, b, (cpose[k] as Vector3) * w)
		sk.set_bone_pose_rotation(b, (r * Basis(sk.get_bone_pose_rotation(b))).get_rotation_quaternion())
	CharacterBuilder._mark_bone_poses_dirty(sk)


func _eval_expr(s: float) -> void:
	if face_mat == null or exprs.is_empty():
		return
	var e: String = "open"
	for x: Dictionary in exprs:
		if float(x["s"]) <= s:
			e = String(x["e"])
	face_mat.uv1_offset = PS2Head.cell_offset(e if e in PS2Head.CELLS else "open")


## Vị trí toàn cục hiện tại của một xương (sau evaluate) – để đặt hiệu ứng va chạm đúng chỗ tay / chân.
func bone_world(bone: String) -> Vector3:
	var b: int = sk.find_bone(bone)
	if b < 0:
		return global_position
	return sk.global_transform * CharacterBuilder._bone_global_now(sk, b).origin
