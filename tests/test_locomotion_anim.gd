# File: res://tests/test_locomotion_anim.gd
# Test headless lớp chuyển động của RigAnimator: nước rút tăng biên độ vung tay, nghiêng người không cộng dồn,
# "getup" phát ngược clip Death rồi về clip nền, mỗi clip mới làm xương (rigged) / pivot (thân tự dựng) rời tư thế Idle
# (đo ở cuối cửa sổ của clip, khi clip trước đã tắt), đứng yên lâu có động tác vặt (fidget) nhưng không "nhìn quanh" khi đang nhìn ai đó, Idle_Neutral phát tốc độ 1,
# lớp cộng thêm (nước rút / nghiêng) mờ dần khi clip gói bắt đầu, animation có track xoay Hips thì không bị lăn hông đè.
# Chạy:  godot --headless --path . --script tests/test_locomotion_anim.gd
extends SceneTree

const NEW_CLIPS: Array[String] = ["jump_takeoff", "jump_air", "fall_flail", "land_soft", "skid", "stumble", "knockdown", "getup", "roll"]
const CLIPS_AT: int = 640   # khung bắt đầu chạy lần lượt các clip mới (sau phần getup)
const CLIP_MIN_DEV: float = 0.15   # rad: clip phải xoay ít nhất một xương / pivot hơn mức này so với Idle (Idle tự lắc ~0.03)
const CLIP_SLOT: int = 35          # frame mỗi clip: CLIP_SETTLE frame về Idle + 20 frame clip
const CLIP_SETTLE: int = 15        # 0.25 s: clip gói trước đã hoà xong về Idle (blend 0.18 s), clip tự dựng tắt ngay
const CLIPS_END: int = CLIPS_AT + 9 * CLIP_SLOT
const IDLE_END: int = CLIPS_END + 780   # hết 13 s đứng yên sau các clip (kiểm fidget)

var getup_end: int = 0
var world: Node3D
var rig: Node3D
var code: Node3D
var sk: Skeleton3D
var frames: int = 0
var done: bool = false
var amp_jog: float = 0.0
var amp_sprint: float = 0.0
var arm_min: float = 99.0
var arm_max: float = -99.0
var lean_x30: float = 0.0
var clip_i: int = 0
var ref_rig: Dictionary = {}    # khớp -> Quaternion ở tư thế Idle, trước clip mới đầu tiên
var ref_code: Dictionary = {}   # pivot -> Quaternion ở tư thế Idle, trước clip mới đầu tiên
var dev_rig: float = 0.0
var dev_code: float = 0.0


func _initialize() -> void:
	Engine.max_fps = 60   # bộ hoạt ảnh chạy theo thời gian thật; headless vẽ ~145 khung/s nên đếm khung phải khoá 60
	world = Node3D.new()
	root.add_child(world)
	rig = CharacterBuilder.build({"preset": "player", "seed": 2805, "rigged": true})
	world.add_child(rig)
	code = CharacterBuilder.build({"preset": "student", "seed": 4, "rigged": false})
	code.position = Vector3(3.0, 0.0, 0.0)
	world.add_child(code)
	sk = rig.get_meta("skeleton") as Skeleton3D
	CharacterBuilder.set_speed(rig, 4.2)
	print("--- TEST LOCOMOTION ANIM ---")


func _arm_angle() -> float:
	var b: int = sk.find_bone("UpperArm.L")
	return (sk.get_bone_rest(b).basis.get_rotation_quaternion().inverse() * sk.get_bone_pose_rotation(b)).get_angle()


func _head_x() -> float:
	var hb: int = sk.find_bone("Head")
	var hips: int = sk.find_bone("Hips")
	var d: Vector3 = sk.get_bone_global_pose(hb).origin - sk.get_bone_global_pose(hips).origin
	return d.x


func _process(_d: float) -> bool:
	if done:
		return true
	frames += 1
	# 1) jog 120 frames: biên độ vung tay; 2) sprint 120 frames: phải lớn hơn >= 1.3 lần
	if frames > 30 and frames <= 150:
		var a: float = _arm_angle()
		arm_min = minf(arm_min, a)
		arm_max = maxf(arm_max, a)
	if frames == 150:
		amp_jog = arm_max - arm_min
		arm_min = 99.0
		arm_max = -99.0
		CharacterBuilder.set_param(rig, "run", 0.45)
		CharacterBuilder.set_param(rig, "sprint", 1.0)
		CharacterBuilder.set_speed(rig, 7.5)
	if frames > 180 and frames <= 300:
		var a2: float = _arm_angle()
		arm_min = minf(arm_min, a2)
		arm_max = maxf(arm_max, a2)
	if frames == 300:
		amp_sprint = arm_max - arm_min
		print("  arm swing amplitude: jog %.3f rad, sprint %.3f rad" % [amp_jog, amp_sprint])
		if not _check(amp_sprint >= amp_jog * 1.3, "sprint must swing the arms at least 1.3x wider (jog %.3f, sprint %.3f)" % [amp_jog, amp_sprint]):
			return true
		CharacterBuilder.set_param(rig, "sprint", 0.0)
		CharacterBuilder.set_param(rig, "run", 0.0)
		CharacterBuilder.set_speed(rig, 0.0)   # đo nghiêng khi đứng (Idle): không lẫn với lắc ngang của chu kỳ chạy
		CharacterBuilder.set_param(rig, "lean", 0.2)
	if frames == 330:
		lean_x30 = _head_x()
	if frames == 360:
		var x60: float = _head_x()
		CharacterBuilder.set_param(rig, "lean", 0.0)
		print("  lean 0.2: head x offset %.3f -> %.3f" % [lean_x30, x60])
		if not _check(absf(x60 - lean_x30) < 0.05, "lean must not accumulate (head x %.3f then %.3f)" % [lean_x30, x60]):
			return true
	if frames == 390:
		var x0: float = _head_x()
		if not _check(absf(lean_x30 - x0) > 0.04, "lean 0.2 rad must move the head sideways (%.3f vs %.3f)" % [lean_x30, x0]):
			return true
		CharacterBuilder.set_speed(rig, 0.0)
		CharacterBuilder.play(rig, "knockdown")
	if frames == 470:
		CharacterBuilder.play(rig, "getup")
	if frames == 472:
		var ap: AnimationPlayer = (CharacterBuilder.get_animator(rig) as Node).get("player")
		print("  getup: anim %s speed %.2f" % [ap.current_animation, ap.get_playing_speed()])
		if not _check(ap.current_animation == "Death" and ap.get_playing_speed() < 0.0, "getup must play Death backwards"):
			return true
		getup_end = frames + int(ceil(ap.get_animation("Death").length / CharacterBuilder.GETUP_SPEED * 60.0)) + 8
	if getup_end > 0 and frames == getup_end:
		var an: Node = CharacterBuilder.get_animator(rig)
		if not _check(String(an.get("clip")) == "", "after getup the animator returns to its base clip (clip = '%s')" % an.get("clip")):
			return true
	# mỗi clip mới một ô CLIP_SLOT frame trên cả hai thân: dừng clip trước, chờ CLIP_SETTLE frame về Idle, chụp tư thế Idle
	# tham chiếu, phát clip; trong phần còn lại của ô xương / pivot phải lệch khỏi tham chiếu – clip không làm gì thì chỉ còn Idle
	if frames >= CLIPS_AT and frames < CLIPS_END:
		var j: int = (frames - CLIPS_AT) % CLIP_SLOT
		var c: String = NEW_CLIPS[(frames - CLIPS_AT) / CLIP_SLOT]
		if j == 0:
			CharacterBuilder.stop_clip(rig)
			CharacterBuilder.stop_clip(code)
		elif j == CLIP_SETTLE:
			ref_rig = _rig_pose()
			ref_code = _code_pose()
			dev_rig = 0.0
			dev_code = 0.0
			CharacterBuilder.play(rig, c)
			CharacterBuilder.play(code, c)   # roll: thân tự dựng không có nhánh _clip_pose, chỉ cần không lỗi
		elif j > CLIP_SETTLE:
			dev_rig = maxf(dev_rig, _dev(ref_rig, _rig_pose()))
			dev_code = maxf(dev_code, _dev(ref_code, _code_pose()))
			if j == CLIP_SLOT - 1:
				print("  clip %s: off Idle by rig %.2f rad, code %.2f rad" % [c, dev_rig, dev_code])
				if not _check(dev_rig > CLIP_MIN_DEV, "clip %s must move a bone of the rigged body off Idle (max %.3f rad)" % [c, dev_rig]):
					return true
				if c != "roll" and not _check(dev_code > CLIP_MIN_DEV, "clip %s must move a pivot of the code body off Idle (max %.3f rad)" % [c, dev_code]):
					return true
	if frames == CLIPS_END:
		CharacterBuilder.stop_clip(rig)
		CharacterBuilder.stop_clip(code)
		CharacterBuilder.set_speed(rig, 0.0)
	# đứng yên 13 s: ít nhất một fidget
	var an: Node = CharacterBuilder.get_animator(rig)
	var ap: AnimationPlayer = an.get("player")
	if frames == IDLE_END:
		var n: int = int(an.get("fidget_count"))
		print("  idle fidgets in 13 s: %d" % n)
		if not _check(n >= 1, "standing still for 13 s must trigger at least one fidget"):
			return true
		# đang nhìn một điểm (NPC sân khấu quay về người chơi khi thoại): 40 lần bắt đầu fidget, không lần nào "look"; Idle_Neutral
		# bắt đầu ngay sau khi chạy (speed_scale còn 1.6) phải phát tốc độ 1
		CharacterBuilder.look_at_point(rig, Vector3(0.0, 1.6, -3.0))
		var kinds: Dictionary = {}
		for i: int in range(40):
			an.call("_fidget_stop")
			an.set("_fidget_t", 0.0)
			ap.speed_scale = 1.6
			an.call("_fidget_update", 0.016)
			var k: String = String(an.get("_fidget"))
			kinds[k] = true
			if not _check(k != "look", "no look-around fidget while look_target is set"):
				return true
			if k == "neutral" and not _check(is_equal_approx(ap.speed_scale, 1.0), "an Idle_Neutral fidget must play at speed_scale 1 (got %.2f)" % ap.speed_scale):
				return true
		print("  fidgets started while looking at a target: %s" % [kinds.keys()])
		if not _check(kinds.has("neutral"), "40 fidget starts must include Idle_Neutral (got %s)" % [kinds.keys()]):
			return true
		an.call("_fidget_stop")
		an.set("_fidget_t", 20.0)
		CharacterBuilder.look_at_point(rig, null)
		# nước rút rồi vẫy (clip gói): lớp cộng thêm mờ dần ~10/s, không tắt hẳn trong một khung
		CharacterBuilder.set_param(rig, "run", 0.45)
		CharacterBuilder.set_param(rig, "sprint", 1.0)
		CharacterBuilder.set_speed(rig, 7.5)
	if frames == IDLE_END + 30:
		CharacterBuilder.play(rig, "wave")
	if frames == IDLE_END + 31:
		var ow: Variant = an.get("_overlay_w")
		print("  overlay weight one frame after a pack clip starts: %s" % [ow])
		if not _check(ow != null and float(ow) > 0.75, "the sprint/lean overlay must ease out, not drop to 0 in one frame (got %s)" % [ow]):
			return true
	if frames == IDLE_END + 46:
		if not _check(float(an.get("_overlay_w")) < 0.01, "the overlay must be gone 15 frames into a pack clip (got %s)" % [an.get("_overlay_w")]):
			return true
		CharacterBuilder.stop_clip(rig)
		CharacterBuilder.set_param(rig, "sprint", 0.0)
		CharacterBuilder.set_param(rig, "run", 0.0)
		CharacterBuilder.set_speed(rig, 0.0)
	# animation có track xoay Hips (bộ nhập hiện bỏ hết, xem _hips_roll): lăn hông (lean) không được đè lên track đó
	if frames == IDLE_END + 80:
		var anim := Animation.new()
		anim.length = 1.0
		anim.loop_mode = Animation.LOOP_LINEAR
		var tr: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(String(ap.get_node(ap.root_node).get_path_to(sk)) + ":Hips"))
		anim.rotation_track_insert_key(tr, 0.0, _hips_probe_rot())
		var lib := AnimationLibrary.new()
		lib.add_animation("HipsProbe", anim)
		ap.add_animation_library("probe", lib)
		ap.play("probe/HipsProbe", 0.0)
		CharacterBuilder.set_param(rig, "lean", 0.3)
	if frames == IDLE_END + 90:
		var err: float = sk.get_bone_pose_rotation(sk.find_bone("Hips")).angle_to(_hips_probe_rot())
		print("  Hips under an animation keying it: %.3f rad from the track value" % err)
		if not _check(err < 0.02, "a Hips rotation track must not be overwritten by the hip roll (off by %.3f rad)" % err):
			return true
		CharacterBuilder.set_param(rig, "lean", 0.0)
		print("✅ SUCCESS: LOCOMOTION LAYER - SPRINT SWING, LEAN, GETUP REVERSED, NEW CLIPS MOVE BONES, FIDGETS, OVERLAY EASE, HIPS TRACK")
		done = true
		quit(0)
	return false


## Giá trị track Hips của animation thử: rest xoay thêm 0.5 rad quanh trục Y của xương.
func _hips_probe_rot() -> Quaternion:
	return sk.get_bone_rest(sk.find_bone("Hips")).basis.get_rotation_quaternion() * Quaternion(Vector3.UP, 0.5)


## Xoay hiện tại của các xương khớp (BONE_OF) của thân rigged.
func _rig_pose() -> Dictionary:
	var d: Dictionary = {}
	for k: String in CharacterBuilder.BONE_OF.keys():
		var b: int = sk.find_bone(String(CharacterBuilder.BONE_OF[k]))
		if b >= 0:
			d[k] = sk.get_bone_pose_rotation(b)
	return d


## Xoay hiện tại của các pivot thân tự dựng.
func _code_pose() -> Dictionary:
	var d: Dictionary = {}
	var r: Dictionary = code.get_meta("rig", {})
	for k: String in r.keys():
		if r[k] is Node3D:
			d[k] = (r[k] as Node3D).quaternion
	return d


## Góc lệch lớn nhất (rad) giữa hai tư thế cùng khoá.
func _dev(a: Dictionary, b: Dictionary) -> float:
	var m: float = 0.0
	for k: Variant in a.keys():
		if b.has(k):
			m = maxf(m, (a[k] as Quaternion).angle_to(b[k]))
	return m


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
