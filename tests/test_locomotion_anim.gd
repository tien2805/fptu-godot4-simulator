# File: res://tests/test_locomotion_anim.gd
# Test headless lớp chuyển động của RigAnimator: nước rút tăng biên độ vung tay, nghiêng người không cộng dồn,
# "getup" phát ngược clip Death rồi về clip nền, đủ clip mới chạy trên thân rigged và thân tự dựng, đứng yên lâu có
# động tác vặt (fidget).
# Chạy:  godot --headless --path . --script tests/test_locomotion_anim.gd
extends SceneTree

const NEW_CLIPS: Array[String] = ["jump_takeoff", "jump_air", "fall_flail", "land_soft", "skid", "stumble", "knockdown", "getup", "roll"]
const CLIPS_AT: int = 640   # khung bắt đầu chạy lần lượt các clip mới (sau phần getup)

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
	# mọi clip mới chạy 20 frame trên cả hai thân, không lỗi
	if frames >= CLIPS_AT and frames < CLIPS_AT + NEW_CLIPS.size() * 20 and (frames - CLIPS_AT) % 20 == 0:
		var c: String = NEW_CLIPS[(frames - CLIPS_AT) / 20]
		CharacterBuilder.play(rig, c)
		CharacterBuilder.play(code, c)
	if frames == CLIPS_AT + NEW_CLIPS.size() * 20:
		CharacterBuilder.stop_clip(rig)
		CharacterBuilder.stop_clip(code)
		CharacterBuilder.set_speed(rig, 0.0)
	# đứng yên 13 s: ít nhất một fidget
	if frames == CLIPS_AT + NEW_CLIPS.size() * 20 + 780:
		var n: int = int((CharacterBuilder.get_animator(rig) as Node).get("fidget_count"))
		print("  idle fidgets in 13 s: %d" % n)
		if not _check(n >= 1, "standing still for 13 s must trigger at least one fidget"):
			return true
		print("✅ SUCCESS: LOCOMOTION LAYER - SPRINT SWING, LEAN, GETUP REVERSED, NEW CLIPS, IDLE FIDGETS")
		done = true
		quit(0)
	return false


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
