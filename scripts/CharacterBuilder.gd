# File: res://scripts/CharacterBuilder.gd
# Dựng NGƯỜI "giống thật" hoàn toàn bằng hình học thủ tục (không ảnh AI, không plugin, không model ngoài):
#   • thân người là mesh tiện (lathe) có vai/eo/hông thật, đầu ellipsoid dán bản đồ mặt (mắt, mày, môi) vẽ bằng Pillow,
#     mũi, tai, tóc nhiều kiểu, cổ áo, tay áo, tay 2 đoạn có bàn tay, chân 2 đoạn có giày, ba lô, kính, dây đeo thẻ…
#   • mỗi khớp là một Node3D pivot (Hips/Torso/Neck/Head/ShoulderL/ElbowL/…/ThighL/KneeL/…) để animate.
#   • lớp animation thủ tục (CharacterBuilder.Animator): thở, đổi trọng tâm, đi/chạy theo tốc độ, nhìn theo mục tiêu,
#     chớp mắt, và các clip: sit, type, eat, phone, cheer, flinch, facepalm, sleepy, wave, bow, punch, kick, ride,
#     stance, guard, lie.
#   • biến thể theo seed: giới tính, 4 tông da, 5 màu tóc, kiểu tóc, chiều cao, độ rộng vai.
#
# Dùng:
#   var p: Node3D = CharacterBuilder.build({"preset": "student", "seed": 7})   # chân ở y=0, mặt hướng -Z
#   parent.add_child(p); p.position = …; p.rotation.y = …
#   CharacterBuilder.play(p, "sit")            # ngồi (hông hạ xuống 0.47 m, đầu gối đưa ra -Z 0.42 m)
#   CharacterBuilder.set_speed(p, 1.3)         # m/s → chu kỳ bước chân tự chạy
#   CharacterBuilder.look_at_point(p, cam.global_position)
#   CharacterBuilder.head_top(p)               # Node3D trên đỉnh đầu để treo Label3D
# Presets: student (ngẫu nhiên nam/nữ), student_m, student_f, player, rider, lecturer, guard, vovinam, master, cook,
#          proctor, casual, cop.
# KHÔNG dùng định danh autoload (GameFX/StageManager) trong file này: test --script có thể biên dịch nó trước autoload.
class_name CharacterBuilder
extends RefCounted

const TEX_DIR: String = "res://assets/textures/"
## Phải khớp TONES trong generate_character_textures.py (a..d)
const SKIN_TONES: Array[Color] = [Color("#F3D5B5"), Color("#E8C09A"), Color("#D5A47A"), Color("#BE8A5E")]
const SKIN_KEYS: Array[String] = ["a", "b", "c", "d"]
const HAIR_COLORS: Array[Color] = [Color("#15120F"), Color("#2A1C13"), Color("#45291A"), Color("#6E3A22"), Color("#2E2E38")]
const FPT_ORANGE := Color("#F37021")
const HAIR_STYLES_M: Array[String] = ["short", "side_part", "spiky", "short", "undercut"]
const HAIR_STYLES_F: Array[String] = ["bob", "ponytail", "long", "bun", "bob"]

# Kích thước chuẩn (m) cho người cao ~1.68 m, scale theo opts.height
const HIP_Y: float = 0.86
const THIGH_LEN: float = 0.42
const SHIN_LEN: float = 0.40
const TORSO_H: float = 0.54
const UPPER_ARM_LEN: float = 0.28
const FOREARM_LEN: float = 0.26
const HEAD_R: float = 0.105

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}
## Phong cách hoạt hình: toon diffuse/specular + viền đen (next_pass) cho mọi vật liệu nhân vật & đồ vật.
## Autoload hiệu ứng đặt toon = (art_style == "classic") lúc khởi động, trước khi cảnh nào dựng nhân vật.
static var toon: bool = true
## Tỉ lệ đầu tự dựng trên thân có xương khi opts không có head_scale: 1.3 (cổ điển, đầu to hoạt hình), autoload hiệu ứng đặt 1.0
## cho phong cách Vice City (ở đó thân rigged dùng đầu PS2 với PS2_HEAD_SCALE_RIG, xem ps2).
static var head_scale_default: float = 1.3
## Phong cách Vice City (autoload hiệu ứng đặt = art_style == "vice", xem _apply_art_style_statics): mọi preset dựng trên thân Quaternius
## với đầu PS2 (PS2Head), tỉ lệ người thật; cổ điển (false) giữ nguyên nhân vật hiện tại.
static var ps2: bool = false
const PS2_HEAD_SCALE_RIG: float = 1.06
## Pivot gắn đồ của thân rigged: khóa thân tự dựng -> [xương, độ dời từ khớp]. Độ dời tính theo TRỤC RIÊNG của pivot (đơn vị
## hệ gốc nhân vật), không theo trục gốc nhân vật: pivot tay / chân có -Y chạy dọc chi (xuống phía khớp con), -Z về phía trước,
## +X sang phải nhân vật (lệch ít nhất khỏi trục nhân vật); thân / cổ giữ trục gốc nhân vật. Vd bàn chân: ANKLE_DOWN_SHIN
## xuống dọc ống chân từ gối, dù ống chân nghiêng. Xem _rig_attach_pivots.
const ATTACH_BONES: Dictionary = {
	"torso": ["Torso", Vector3.ZERO], "neck": ["Neck", Vector3.ZERO],
	"shoulder_l": ["UpperArm.L", Vector3.ZERO], "shoulder_r": ["UpperArm.R", Vector3.ZERO],
	"elbow_l": ["LowerArm.L", Vector3.ZERO], "elbow_r": ["LowerArm.R", Vector3.ZERO],
	"thigh_l": ["UpperLeg.L", Vector3.ZERO], "thigh_r": ["UpperLeg.R", Vector3.ZERO],
	"knee_l": ["LowerLeg.L", Vector3.ZERO], "knee_r": ["LowerLeg.R", Vector3.ZERO],
	"foot_l": ["LowerLeg.L", Vector3(0.0, -ANKLE_DOWN_SHIN, 0.0)], "foot_r": ["LowerLeg.R", Vector3(0.0, -ANKLE_DOWN_SHIN, 0.0)],
}
## Cổ chân của thân rigged: cách gối 0.42 dọc ống chân (ngay trên đích IK Foot.L/R); pivot foot_* và trục quay bàn chân ở đây.
const ANKLE_DOWN_SHIN: float = 0.42
static var _outline_cache: Dictionary = {}
const EXPRESSIONS: Array[String] = ["open", "closed", "happy", "angry", "surprised", "done"]

## --- Thân người có xương (Quaternius Ultimate Modular Men/Women, CC0, assets/models/quaternius/) ---
## Mỗi file glTF: 1 Skeleton3D 62 xương + 24 animation + 4 mesh (Body/Feet/Head/Legs). Đầu của mô hình bị ẩn,
## thay bằng đầu/mặt tự dựng (biểu cảm, tóc, kính, mũ) gắn vào xương "Head" qua BoneAttachment3D.
const MODEL_DIR: String = "res://assets/models/quaternius/"
const BODIES_M: Dictionary = {"casual": "men/Casual_2", "hoodie": "men/Casual_Hoodie", "suit": "men/Suit", "worker": "men/Worker"}
const BODIES_F: Dictionary = {"casual": "women/Casual", "formal": "women/Formal", "worker": "women/Worker"}
const PRESET_BODY: Dictionary = {"student": "casual", "student_m": "casual", "student_f": "casual", "player": "hoodie", "rider": "casual",
	"lecturer": "suit", "proctor": "suit", "guard": "worker", "cop": "worker", "vovinam": "casual", "master": "casual", "cook": "worker", "casual": "hoodie"}
const MODEL_HEIGHT: float = 1.86     # chiều cao mô hình gốc (m) → root.scale đưa về ~1.74 m như nhân vật tự dựng
const MODEL_YAW: float = PI          # mô hình quay mặt về +Z, nhân vật của ta quay mặt về -Z
## khớp của ta → xương mô hình
const BONE_OF: Dictionary = {"hips": "Hips", "torso": "Torso", "head": "Head", "neck": "Neck", "chest": "Chest",
	"shoulder_l": "UpperArm.L", "shoulder_r": "UpperArm.R", "elbow_l": "LowerArm.L", "elbow_r": "LowerArm.R",
	"hand_l": "Wrist.L", "hand_r": "Wrist.R", "thigh_l": "UpperLeg.L", "thigh_r": "UpperLeg.R", "knee_l": "LowerLeg.L", "knee_r": "LowerLeg.R"}
## clip của ta → animation có sẵn trong gói (các clip khác dựng bằng xoay xương từ bảng clip của Animator)
const PACK_CLIP: Dictionary = {"wave": "Wave", "punch": "Punch_Right", "kick": "Kick_Right", "flinch": "HitRecieve", "roll": "Roll",
	"interact": "Interact", "lie": "Death", "chop": "Sword_Slash", "stumble": "HitRecieve", "knockdown": "Death"}
## Clip gói giữ khung cuối tới khi có clip khác (không tự hết giờ).
const HOLD_CLIPS: Array[String] = ["lie", "knockdown"]
## Tốc độ phát ngược Death cho "getup" (Death ~1.3 s -> đứng dậy ~0.9 s).
const GETUP_SPEED: float = 1.4
## Tốc độ hoà clip tự dựng (1/s); mặc định 5.
const FAST_BLEND: Dictionary = {"jump_takeoff": 14.0, "jump_air": 10.0, "fall_flail": 8.0, "land_soft": 14.0, "skid": 10.0, "stumble": 10.0}
static var _scene_cache: Dictionary = {}
static var _smooth_cache: Dictionary = {}
static var _skin_cache: Dictionary = {}   # [id mesh, transform skin các xương] -> mesh skinned bằng CPU, xem _skin_cpu
static var rigged_default: bool = false   # true → build() mặc định dùng thân Quaternius (bật sau khi duyệt)

static func _outline_mat(width: float) -> ShaderMaterial:
	var key: String = "%.4f" % width
	if _outline_cache.has(key):
		return _outline_cache[key]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/outline.gdshader")
	sm.set_shader_parameter("width", width)
	_outline_cache[key] = sm
	return sm

## Áp phong cách toon + viền lên một StandardMaterial3D (bỏ qua vật liệu trong suốt)
static func _style_mat(m: StandardMaterial3D, outline_width: float = 0.012) -> StandardMaterial3D:
	if not toon:
		return m
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and outline_width > 0.0:
		m.next_pass = _outline_mat(outline_width)
	return m

# ===========================================================================
# API TĨNH
# ===========================================================================
static func build(opts: Dictionary = {}) -> Node3D:
	if bool(opts.get("rigged", rigged_default or ps2)):
		var r: Node3D = _build_rigged(opts)
		if r:
			return r
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", randi()))
	var preset: String = String(opts.get("preset", "student"))
	var female: bool
	match preset:
		"student_f":
			female = true
		"student_m", "guard", "master", "cop":
			female = false
		_:
			female = bool(opts.get("female", rng.randf() < (0.45 if preset in ["student", "casual", "player", "rider"] else 0.3)))
	var skin_idx: int = int(opts.get("skin", rng.randi_range(0, SKIN_TONES.size() - 1)))
	skin_idx = clampi(skin_idx, 0, SKIN_TONES.size() - 1)
	var hair_idx: int = clampi(int(opts.get("hair_color", rng.randi_range(0, HAIR_COLORS.size() - 1))), 0, HAIR_COLORS.size() - 1)
	var hair_style: String = String(opts.get("hair_style", ""))
	if hair_style == "":
		hair_style = (HAIR_STYLES_F if female else HAIR_STYLES_M)[rng.randi_range(0, 4)]
	var height: float = float(opts.get("height", rng.randf_range(0.93, 1.06) * (0.95 if female else 1.0)))
	var width: float = float(opts.get("width", rng.randf_range(0.94, 1.06)))
	var outfit: Dictionary = _outfit_for(preset, female, rng, opts)

	var root := Node3D.new()
	root.name = String(opts.get("name", "Character"))
	root.scale = Vector3(height, height, height)
	var rig: Dictionary = {}
	var skin: Material = _skin_mat(skin_idx)

	# --- Hông / thân
	var hips := _pivot(root, "Hips", Vector3(0.0, HIP_Y, 0.0))
	rig["hips"] = hips
	var torso := _pivot(hips, "Torso", Vector3.ZERO)
	rig["torso"] = torso
	var torso_mi := MeshInstance3D.new()
	torso_mi.name = "TorsoMesh"
	torso_mi.mesh = _torso_mesh(female, width)
	torso_mi.material_override = outfit["shirt"]
	torso.add_child(torso_mi)
	rig["torso_mesh"] = torso_mi
	var shoulder_w: float = (0.165 if female else 0.19) * width
	var chest_z: float = (0.125 if female else 0.12) * width
	# cổ áo
	if outfit.get("collar", true):
		_cyl(torso, Vector3(0.0, TORSO_H - 0.005, 0.0), 0.075 * width, 0.085 * width, 0.03, outfit["collar_mat"], Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	# thắt lưng
	if outfit.get("belt", false):
		_cyl(torso, Vector3(0.0, 0.02, 0.0), 0.178 * width, 0.178 * width, 0.045, outfit["belt_mat"], Vector3.ZERO, Vector3(1.0, 1.0, 0.68))
		_box(torso, Vector3(0.0, 0.02, -0.118 * width), Vector3(0.05, 0.035, 0.012), _mat("belt_buckle", Color("#C9B458"), 0.35, 0.8))
	if outfit.get("vovinam_belt", false):
		_cyl(torso, Vector3(0.0, 0.16, 0.0), 0.165 * width, 0.165 * width, 0.06, outfit["vbelt_mat"], Vector3.ZERO, Vector3(1.0, 1.0, 0.66))
		_box(torso, Vector3(0.0, 0.14, -0.108 * width), Vector3(0.07, 0.05, 0.02), outfit["vbelt_mat"])
		_box(torso, Vector3(-0.03, 0.02, -0.112 * width), Vector3(0.03, 0.2, 0.012), outfit["vbelt_mat"], Vector3(0.0, 0.0, 0.1))
		_box(torso, Vector3(0.03, 0.02, -0.112 * width), Vector3(0.03, 0.2, 0.012), outfit["vbelt_mat"], Vector3(0.0, 0.0, -0.1))
	if outfit.get("apron", false):
		_box(torso, Vector3(0.0, 0.06, -(chest_z + 0.02)), Vector3(0.30 * width, 0.74, 0.012), outfit["apron_mat"])
		_box(torso, Vector3(0.0, 0.50, -(chest_z - 0.02)), Vector3(0.012, 0.16, 0.012), outfit["apron_mat"], Vector3(0.0, 0.0, 0.6))
		_box(torso, Vector3(0.0, 0.50, -(chest_z - 0.02)), Vector3(0.012, 0.16, 0.012), outfit["apron_mat"], Vector3(0.0, 0.0, -0.6))
	if outfit.get("lanyard", false):
		var ly: Material = _mat("lanyard", Color("#1F4FA3"), 0.9)
		_box(torso, Vector3(-0.045, 0.40, -(chest_z + 0.01)), Vector3(0.012, 0.22, 0.004), ly, Vector3(0.0, 0.0, -0.32))
		_box(torso, Vector3(0.045, 0.40, -(chest_z + 0.01)), Vector3(0.012, 0.22, 0.004), ly, Vector3(0.0, 0.0, 0.32))
		var card := _box(torso, Vector3(0.0, 0.265, -(chest_z + 0.012)), Vector3(0.062, 0.088, 0.004), _mat("id_card", Color("#F7F7F7"), 0.5))
		_box(card, Vector3(0.0, 0.03, -0.003), Vector3(0.062, 0.02, 0.002), _mat("id_stripe", FPT_ORANGE, 0.5))
		_box(card, Vector3(0.0, -0.012, -0.003), Vector3(0.036, 0.034, 0.002), _mat("id_photo", Color("#B9C2CC"), 0.6))
	if outfit.get("tie", false):
		_box(torso, Vector3(0.0, 0.40, -(chest_z + 0.008)), Vector3(0.032, 0.05, 0.008), outfit["tie_mat"])
		_box(torso, Vector3(0.0, 0.26, -(chest_z + 0.008)), Vector3(0.05, 0.24, 0.006), outfit["tie_mat"])
	if outfit.get("badge", false):
		_box(torso, Vector3(-0.07 * width, 0.42, -(chest_z + 0.01)), Vector3(0.05, 0.022, 0.006), _mat("badge", Color("#D4AF37"), 0.3, 0.9))
	if outfit.get("epaulettes", false):
		for sx: float in [-1.0, 1.0]:
			_box(torso, Vector3(sx * (shoulder_w - 0.03), TORSO_H - 0.04, 0.0), Vector3(0.09, 0.012, 0.05), outfit["epaulette_mat"])
	if outfit.get("backpack", false):
		var bp: Material = outfit["backpack_mat"]
		_box(torso, Vector3(0.0, 0.28, chest_z + 0.07), Vector3(0.25 * width, 0.33, 0.12), bp)
		_box(torso, Vector3(0.0, 0.40, chest_z + 0.135), Vector3(0.22 * width, 0.10, 0.03), bp)
		_box(torso, Vector3(0.0, 0.17, chest_z + 0.135), Vector3(0.18 * width, 0.14, 0.03), outfit["backpack_pocket_mat"])
		for sx: float in [-1.0, 1.0]:
			_box(torso, Vector3(sx * 0.075 * width, 0.40, -(chest_z - 0.015)), Vector3(0.03, 0.2, 0.012), bp, Vector3(0.0, 0.0, sx * 0.08))
			_box(torso, Vector3(sx * 0.075 * width, 0.50, 0.0), Vector3(0.03, 0.012, chest_z * 2.0 + 0.02), bp)

	# --- Cổ, đầu
	var neck := _pivot(torso, "Neck", Vector3(0.0, TORSO_H - 0.01, 0.0))
	_cyl(neck, Vector3(0.0, 0.04, 0.005), 0.042 * width, 0.05 * width, 0.09, skin)
	var head: Node3D
	if ps2:
		head = PS2Head.build(neck, Vector3(0.0, 0.065, 0.0), _ps2_head_opts(skin_idx, female, hair_style, hair_idx, width, outfit, rng), rig)
	else:
		head = _build_head(neck, Vector3(0.0, 0.065, 0.0), skin_idx, female, width, hair_style, hair_idx, outfit, rng, rig)
	var head_mi: MeshInstance3D = rig["face_mesh"]
	var face_mat: StandardMaterial3D = head_mi.material_override as StandardMaterial3D if ps2 else _face_mat(skin_idx, female)

	# --- Tay
	for side: Array in [["L", -1.0], ["R", 1.0]]:
		var s: String = side[0]
		var sx: float = side[1]
		var sh := _pivot(torso, "Shoulder" + s, Vector3(sx * shoulder_w, TORSO_H - 0.055, 0.0))
		rig["shoulder_" + s.to_lower()] = sh
		var arm_r: float = (0.042 if female else 0.047) * width
		_capsule(sh, Vector3(0.0, -UPPER_ARM_LEN * 0.5, 0.0), arm_r, UPPER_ARM_LEN + arm_r * 1.2, skin)
		# tay áo
		var sleeve_len: float = float(outfit.get("sleeve", 0.14))
		if sleeve_len > 0.0:
			_capsule(sh, Vector3(0.0, -sleeve_len * 0.5 + 0.015, 0.0), arm_r + 0.012, sleeve_len + 0.03, outfit["shirt_plain"])
		var el := _pivot(sh, "Elbow" + s, Vector3(0.0, -UPPER_ARM_LEN, 0.0))
		rig["elbow_" + s.to_lower()] = el
		_capsule(el, Vector3(0.0, -FOREARM_LEN * 0.5, 0.0), arm_r * 0.86, FOREARM_LEN + arm_r, skin)
		if sleeve_len > UPPER_ARM_LEN:
			_capsule(el, Vector3(0.0, -FOREARM_LEN * 0.5 + 0.01, 0.0), arm_r * 0.86 + 0.01, FOREARM_LEN, outfit["shirt_plain"])
		# bàn tay (dẹt) + cổ tay / đồng hồ
		var hand := _pivot(el, "Hand" + s, Vector3(0.0, -FOREARM_LEN, 0.0))
		rig["hand_" + s.to_lower()] = hand
		_capsule(hand, Vector3(0.0, -0.045, -0.005), 0.034, 0.1, skin, Vector3.ZERO, Vector3(0.55, 1.0, 1.0))
		if s == "L" and outfit.get("watch", false):
			_cyl(el, Vector3(0.0, -FOREARM_LEN + 0.025, 0.0), arm_r * 0.9 + 0.004, arm_r * 0.9 + 0.004, 0.018, _mat("watch_band", Color("#222222"), 0.6))
			_box(el, Vector3(0.0, -FOREARM_LEN + 0.025, -(arm_r * 0.9 + 0.006)), Vector3(0.026, 0.03, 0.006), _mat("watch_face", Color("#111111"), 0.2, 0.6, 0.3))
		if outfit.get("wristband", false) and s == "R":
			_cyl(el, Vector3(0.0, -FOREARM_LEN + 0.03, 0.0), arm_r * 0.9 + 0.005, arm_r * 0.9 + 0.005, 0.025, _mat("wristband", Color("#F1C40F"), 0.8))

	# --- Chân
	var hip_w: float = (0.095 if female else 0.088) * width
	for side: Array in [["L", -1.0], ["R", 1.0]]:
		var s: String = side[0]
		var sx: float = side[1]
		var th := _pivot(hips, "Thigh" + s, Vector3(sx * hip_w, -0.02, 0.0))
		rig["thigh_" + s.to_lower()] = th
		var leg_r: float = (0.072 if female else 0.07) * width
		var shorts: bool = bool(outfit.get("shorts", false))
		_capsule(th, Vector3(0.0, -THIGH_LEN * 0.5 + 0.02, 0.0), leg_r, THIGH_LEN + leg_r, outfit["trousers"])
		var kn := _pivot(th, "Knee" + s, Vector3(0.0, -THIGH_LEN, 0.0))
		rig["knee_" + s.to_lower()] = kn
		_capsule(kn, Vector3(0.0, -SHIN_LEN * 0.5, 0.0), leg_r * 0.78, SHIN_LEN + leg_r * 0.6, skin if shorts else outfit["trousers"])
		if not shorts:
			# gấu quần hơi loe che cổ giày
			_cyl(kn, Vector3(0.0, -SHIN_LEN + 0.04, 0.0), leg_r * 0.8, leg_r * 0.86, 0.06, outfit["trousers"])
		# giày
		var foot := _pivot(kn, "Foot" + s, Vector3(0.0, -SHIN_LEN, 0.0))
		rig["foot_" + s.to_lower()] = foot
		var shoe_style: String = String(outfit.get("shoes", "sneaker"))
		if shoe_style == "barefoot":
			_capsule(foot, Vector3(0.0, -0.02, -0.035), 0.04, 0.2, skin, Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.55))
		else:
			var shoe_mat: Material = outfit["shoe_mat"]
			_capsule(foot, Vector3(0.0, -0.012, -0.04), 0.044, 0.22, shoe_mat, Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.62))
			_box(foot, Vector3(0.0, -0.03, -0.04), Vector3(0.088, 0.022, 0.25), outfit["sole_mat"])
			if shoe_style == "sneaker":
				_box(foot, Vector3(0.0, 0.0, -0.065), Vector3(0.05, 0.012, 0.09), outfit["lace_mat"])
			elif shoe_style == "sandal":
				_box(foot, Vector3(0.0, 0.0, -0.05), Vector3(0.09, 0.01, 0.025), outfit["sole_mat"])

	# --- Tỉ lệ cách điệu (hoạt hình): đầu to, tay chân ngắn, bàn tay to; hông hạ theo chân ngắn
	var stylized: bool = bool(opts.get("stylized", not ps2))
	var leg_scale: float = 1.0
	if stylized:
		head.scale = Vector3(1.26, 1.26, 1.26)
		for key: String in ["shoulder_l", "shoulder_r"]:
			(rig[key] as Node3D).scale = Vector3(0.93, 0.93, 0.93)
		for key: String in ["hand_l", "hand_r"]:
			(rig[key] as Node3D).scale = Vector3(1.18, 1.18, 1.18)
		leg_scale = 0.9
		for key: String in ["thigh_l", "thigh_r"]:
			(rig[key] as Node3D).scale = Vector3(leg_scale, leg_scale, leg_scale)
		hips.position.y = HIP_Y * leg_scale
		torso_mi.scale = Vector3(1.05, 1.0, 1.05)
	# --- Khối cầu lấp khớp (vai, khuỷu, cổ tay, háng, gối) để không lộ đoạn rời. Chỉ cổ điển: spec vice không khối cầu khớp
	# (ảnh cận cảnh Task 4: các khúc chồng nhau nên không hở khớp nào; gối gập mạnh chỉ lộ nếp nối đùi / ống chân)
	if not ps2:
		var arm_r2: float = (0.042 if female else 0.047) * width
		var leg_r2: float = (0.072 if female else 0.07) * width
		for sfx: String in ["l", "r"]:
			_sphere(rig["shoulder_" + sfx], Vector3.ZERO, arm_r2 * 1.15, outfit["shirt_plain"])
			_sphere(rig["elbow_" + sfx], Vector3.ZERO, arm_r2 * 0.92, outfit["shirt_plain"] if float(outfit.get("sleeve", 0.14)) > UPPER_ARM_LEN else skin)
			_sphere(rig["hand_" + sfx], Vector3.ZERO, arm_r2 * 0.8, skin)
			_sphere(rig["thigh_" + sfx], Vector3.ZERO, leg_r2 * 1.0, outfit["trousers"])
			_sphere(rig["knee_" + sfx], Vector3.ZERO, leg_r2 * 0.84, skin if bool(outfit.get("shorts", false)) else outfit["trousers"])
	root.set_meta("rig", rig)
	root.set_meta("preset", preset)
	root.set_meta("female", female)
	root.set_meta("height", height)
	root.set_meta("hip_base", HIP_Y * leg_scale)
	root.set_meta("skin_idx", skin_idx)
	if ps2:
		root.set_meta("ps2_head", true)
	# --- Animator
	if bool(opts.get("animate", true)):
		var an := Animator.new()
		an.name = "Animator"
		an.rig = rig
		an.blink_enabled = bool(opts.get("blink", true))
		if an.blink_enabled:
			if ps2:
				an.blink_enabled = _setup_face_cells(an, face_mat)
			else:
				var open_tex: Texture2D = face_mat.albedo_texture
				var closed_tex: Texture2D = _tex("char_face_%s%s_closed.png" % [SKIN_KEYS[skin_idx], "f" if female else "m"])
				if open_tex and closed_tex:
					var own: StandardMaterial3D = face_mat.duplicate()
					head_mi.material_override = own
					an.face_mat = own
					an.face_open = open_tex
					an.face_closed = closed_tex
				else:
					an.blink_enabled = false
		an.rng_phase = rng.randf() * TAU
		an.hip_base = HIP_Y * leg_scale
		root.add_child(an)
		var clip: String = String(opts.get("clip", ""))
		if clip != "":
			an.play(clip)
	return root

## Đầu tự dựng (cầu + mặt vẽ Pillow, mũi, tai, tóc, kính, mũ) dưới pivot "Head" đặt tại pos trong parent.
## Dùng chung cho thân tự dựng và thân rigged. Ghi rig["head"], rig["face_mesh"], rig["head_top"].
static func _build_head(parent: Node3D, pos: Vector3, skin_idx: int, female: bool, width: float, hair_style: String, hair_idx: int, outfit: Dictionary, rng: RandomNumberGenerator, rig: Dictionary) -> Node3D:
	var skin: Material = _skin_mat(skin_idx)
	var head := _pivot(parent, "Head", pos)
	rig["head"] = head
	var face_mat: StandardMaterial3D = _face_mat(skin_idx, female)
	var head_mi := MeshInstance3D.new()
	head_mi.name = "HeadMesh"
	var sm := SphereMesh.new()
	sm.radius = HEAD_R
	sm.height = HEAD_R * 2.0 * 1.16
	sm.radial_segments = 28
	sm.rings = 14
	head_mi.mesh = sm
	head_mi.position = Vector3(0.0, 0.12, 0.0)
	head_mi.scale = Vector3(0.94 * width, 1.0, 0.96)
	head_mi.material_override = face_mat
	head.add_child(head_mi)
	rig["face_mesh"] = head_mi
	# mũi, tai
	_capsule(head, Vector3(0.0, 0.108, -0.104), 0.011, 0.034, skin, Vector3(-1.05, 0.0, 0.0))
	for sx: float in [-1.0, 1.0]:
		_sphere(head, Vector3(sx * 0.097 * width, 0.118, 0.006), 0.02, skin, Vector3(0.5, 1.0, 0.8))
	_build_hair(head, hair_style, hair_idx, outfit, width, rng)
	if outfit.get("glasses", false):
		_build_glasses(head, width)
	if outfit.get("helmet", false):
		_build_helmet(head, outfit["helmet_color"], width)
	var head_top := _pivot(head, "HeadTop", Vector3(0.0, 0.27, 0.0))
	rig["head_top"] = head_top
	return head

## Tham số PS2Head.build() chung cho thân tự dựng và thân rigged (rút rng.randi() đúng một lần cho hạt giống của đầu).
static func _ps2_head_opts(skin_idx: int, female: bool, hair_style: String, hair_idx: int, width: float, outfit: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	return {"skin": skin_idx, "female": female, "hair_style": hair_style, "hair_color": hair_idx, "width": width, "seed": rng.randi(), "outfit": outfit}

## Chớp mắt / biểu cảm đầu PS2 bằng ô atlas: gán vật liệu mặt riêng cho an (Animator hoặc RigAnimator, cùng các trường face_*).
## Trả false nếu vật liệu không có atlas (meta "ps2_face"), khi đó người gọi tắt chớp mắt.
static func _setup_face_cells(an: Node, face_mat: StandardMaterial3D) -> bool:
	if face_mat == null or not bool(face_mat.get_meta("ps2_face", false)):
		return false
	an.face_mat = face_mat
	an.face_cells = true
	an.face_cell_open = PS2Head.cell_offset("open")
	an.face_cell_closed = PS2Head.cell_offset("closed")
	return true

## Mặt mở / nhắm cho Animator và RigAnimator (một chỗ cho cả hai lớp): đầu PS2 đổi ô atlas, đầu cổ điển đổi texture.
static func _show_face(an: Node, closed: bool) -> void:
	var fm: StandardMaterial3D = an.face_mat
	if an.face_cells:
		fm.uv1_offset = an.face_cell_closed if closed else an.face_cell_open
	else:
		fm.albedo_texture = an.face_closed if closed else an.face_open

## Làm mượt pháp tuyến mesh glTF low-poly (đỉnh tách theo mặt): gộp đỉnh trùng vị trí, trung bình pháp tuyến trong ngưỡng góc.
## Không làm thì vỏ viền (inverted hull) nứt thành mảnh và toon shading bị khía. Giữ nguyên xương/trọng số/UV/chỉ số.
static func _smooth_mesh(src: Mesh, angle_deg: float = 60.0) -> Mesh:
	if src == null:
		return null
	var key: RID = src.get_rid()
	if _smooth_cache.has(key):
		return _smooth_cache[key]
	var out := ArrayMesh.new()
	var cos_t: float = cos(deg_to_rad(angle_deg))
	for si: int in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.size() == verts.size():
			var groups: Dictionary = {}
			for i: int in verts.size():
				var k: Vector3i = Vector3i((verts[i] * 2000.0).round())
				if not groups.has(k):
					groups[k] = []
				(groups[k] as Array).append(i)
			var smoothed := PackedVector3Array()
			smoothed.resize(verts.size())
			for k: Vector3i in groups.keys():
				var idx: Array = groups[k]
				for i: int in idx:
					var n: Vector3 = normals[i]
					var acc: Vector3 = Vector3.ZERO
					for j: int in idx:
						var nj: Vector3 = normals[j]
						if n.dot(nj) >= cos_t:
							acc += nj
					smoothed[i] = acc.normalized() if acc.length_squared() > 1e-8 else n
			arrays[Mesh.ARRAY_NORMAL] = smoothed
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, src.surface_get_material(si))
		if src is ArrayMesh:
			out.surface_set_name(si, (src as ArrayMesh).surface_get_name(si))
	_smooth_cache[key] = out
	return out

static func _body_scene(rel: String) -> PackedScene:
	if _scene_cache.has(rel):
		return _scene_cache[rel]
	var path: String = MODEL_DIR + rel + ".gltf"
	var ps: PackedScene = load(path) if ResourceLoader.exists(path) else null
	_scene_cache[rel] = ps
	return ps

## Thân Quaternius + đầu tự dựng. opts thêm: body ("casual|hoodie|suit|worker|formal"), head_scale (mặc định head_scale_default: 1.3 – đầu to kiểu
## hoạt hình; chế độ ps2: đầu PS2 với PS2_HEAD_SCALE_RIG), body_width (chỉ ps2, mặc định ngẫu nhiên 0.92..1.12), rigged=true.
## Trả về null nếu không có mô hình (build() sẽ quay về thân tự dựng).
static func _build_rigged(opts: Dictionary) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", randi()))
	var preset: String = String(opts.get("preset", "student"))
	var female: bool
	match preset:
		"student_f":
			female = true
		"student_m", "guard", "master", "cop":
			female = false
		_:
			female = bool(opts.get("female", rng.randf() < (0.45 if preset in ["student", "casual", "player", "rider"] else 0.3)))
	var skin_idx: int = clampi(int(opts.get("skin", rng.randi_range(0, SKIN_TONES.size() - 1))), 0, SKIN_TONES.size() - 1)
	var hair_idx: int = clampi(int(opts.get("hair_color", rng.randi_range(0, HAIR_COLORS.size() - 1))), 0, HAIR_COLORS.size() - 1)
	var hair_style: String = String(opts.get("hair_style", ""))
	if hair_style == "":
		hair_style = (HAIR_STYLES_F if female else HAIR_STYLES_M)[rng.randi_range(0, 4)]
	var height: float = float(opts.get("height", rng.randf_range(0.93, 1.06) * (0.95 if female else 1.0)))
	var width: float = float(opts.get("width", rng.randf_range(0.94, 1.06)))
	var body_key: String = String(opts.get("body", PRESET_BODY.get(preset, "casual")))
	var table: Dictionary = BODIES_F if female else BODIES_M
	if not table.has(body_key):
		body_key = "casual"
	var ps: PackedScene = _body_scene(table[body_key])
	if ps == null:
		push_warning("CharacterBuilder: thiếu mô hình %s, dùng thân tự dựng" % body_key)
		return null
	var outfit: Dictionary = _outfit_for(preset, female, rng, opts)

	var root := Node3D.new()
	root.name = String(opts.get("name", "Character"))
	var s: float = height * 1.74 / MODEL_HEIGHT
	root.scale = Vector3(s, s, s)
	var model: Node3D = ps.instantiate()
	model.name = "Model"
	model.rotation.y = MODEL_YAW
	root.add_child(model)
	var hs: float = float(opts.get("head_scale", PS2_HEAD_SCALE_RIG if ps2 else head_scale_default))
	var wk: float = 1.0
	if ps2:
		wk = float(opts.get("body_width", rng.randf_range(0.92, 1.12)))
		model.scale = Vector3(wk, 1.0, wk)
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if sk == null or ap == null:
		root.free()
		return null
	var rig: Dictionary = {}
	var skin: Material = _skin_mat(skin_idx)
	# --- vật liệu: da theo tông của mặt, áo/quần/giày theo trang phục preset, đầu mô hình ẩn
	for mi: MeshInstance3D in _mesh_instances(sk):
		var n: String = mi.name
		if n.ends_with("_Head") or not ("_" in n):
			mi.visible = false   # đầu gốc + vật thể lạ (súng…) ẩn
			continue
		var is_legs: bool = n.ends_with("_Legs")
		var is_feet: bool = n.ends_with("_Feet")
		mi.mesh = _smooth_mesh(mi.mesh)
		# mặt vải lớn nhất (nhiều tam giác nhất, không phải da) = áo/quần chính. Vice: áo gi-lê phản quang của thân Worker
		# ("Worker_Vest" cam, sọc "Worker_Yellow") không phải trang phục hiện tại của bảo vệ / công an / đầu bếp: không tính là áo
		# chính và tô màu cổ áo của trang phục (gi-lê cùng tông đồng phục, xem nhánh dưới)
		var main_si: int = -1
		var main_tris: int = -1
		for si: int in mi.mesh.get_surface_count():
			var src0: Material = mi.get_active_material(si)
			if src0 and (src0.resource_name.begins_with("Skin") or (ps2 and src0.resource_name.begins_with("Worker_"))):
				continue
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var tris: int = arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()
			if tris > main_tris:
				main_tris = tris
				main_si = si
		var cloth_i: int = 0
		for si: int in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(si)
			var src_name: String = src.resource_name if src else ""
			var m: Material
			if src_name.begins_with("Skin"):
				m = skin
			elif is_feet:
				m = outfit["shoe_mat"] if cloth_i == 0 else outfit["sole_mat"]
				cloth_i += 1
			elif is_legs:
				m = outfit["trousers"]
			elif src_name == "Tie" and outfit.has("tie_mat"):
				m = outfit["tie_mat"]
			elif ps2 and src_name.begins_with("Worker_"):
				m = outfit["collar_mat"]
			elif si == main_si:
				m = outfit["shirt_plain"]
			else:
				m = _rig_extra_mat(src, outfit, cloth_i)
				cloth_i += 1
			mi.set_surface_override_material(si, m)
		if not is_legs and not is_feet and main_si >= 0 and not rig.has("torso_mesh"):
			rig["torso_mesh"] = mi
	# --- đầu tự dựng gắn xương Head
	var hb: int = sk.find_bone("Head")
	var att := BoneAttachment3D.new()
	att.name = "HeadBone"
	sk.add_child(att)
	att.bone_name = "Head"
	var head_pivot: Node3D
	if ps2:
		# xương Head nghỉ cúi ~4° (đầu gốc skinned bù bằng bind pose): nút bù tư thế nghỉ để đầu PS2 nhìn thẳng như đầu gốc
		# rồi đi theo độ xoay của xương so với tư thế nghỉ (cùng cách với _rig_attach_pivots)
		var upright := Node3D.new()
		upright.name = "HeadUpright"
		if hb >= 0:
			upright.basis = sk.get_bone_global_rest(hb).basis.orthonormalized().inverse()
		att.add_child(upright)
		head_pivot = PS2Head.build(upright, Vector3.ZERO, _ps2_head_opts(skin_idx, female, hair_style, hair_idx, width, outfit, rng), rig)
	else:
		head_pivot = _build_head(att, Vector3(0.0, 0.0, 0.0), skin_idx, female, width, hair_style, hair_idx, outfit, rng, rig)
	head_pivot.rotation.y = PI   # đầu nhìn về -Z của pivot; xương Head nhìn về +Z của mô hình (đã quay PI)
	head_pivot.position = Vector3(0.0, -0.045 + (hs - 1.0) * 0.1, 0.0)
	head_pivot.scale = Vector3(hs / wk, hs, hs / wk)   # bù bề ngang thân (wk) để mặt không méo
	if ps2 and female:
		# cổ của thân nữ (da) dừng 1-2 cm dưới cằm PS2 ở phía trước (cổ áo thân nam che chỗ này): trụ cổ bằng da nối từ trong cổ
		# thân lên trong hàm; bán kính 0.035 nằm trong mặt cổ thân (đo ở tư thế nghỉ: trước 0.040, sau 0.036 tính từ trục cằm)
		_cyl(head_pivot.get_parent(), head_pivot.position + Vector3(0.0, -0.012, 0.0), 0.035, 0.035, 0.08, skin).name = "NeckFill"
	# --- các pivot gắn đồ (tay, ngực) qua BoneAttachment3D
	for key: String in ["hand_l", "hand_r", "chest", "hips"]:
		var a := BoneAttachment3D.new()
		a.name = "Att_" + key
		sk.add_child(a)
		a.bone_name = BONE_OF[key]
		rig[key] = a
	if ps2:
		_rig_attach_pivots(root, sk, rig, String(table[body_key]))   # chỉ ps2: thân rigged cổ điển (người chơi FreeRoam) giữ nguyên cây node
		_rig_torso_extras_ps2(model, sk, rig, outfit, String(table[body_key]))
	else:
		_rig_torso_extras(rig["chest"], rig["hips"], outfit, width)
	root.set_meta("rig", rig)
	root.set_meta("rigged", true)
	root.set_meta("preset", preset)
	root.set_meta("female", female)
	root.set_meta("height", height)
	root.set_meta("skin_idx", skin_idx)
	root.set_meta("skeleton", sk)
	var base_key: String = String(table[body_key])
	if not _base_cache.has(base_key):
		_base_cache[base_key] = _neutral_base(sk)
	sk.set_meta("base", _base_cache[base_key])   # tư thế đứng trung tính làm gốc cho pose() tĩnh và _apply_bone_pose
	if ps2:
		root.set_meta("ps2_head", true)
	# --- Animator
	if bool(opts.get("animate", true)):
		var an := RigAnimator.new()
		an.name = "Animator"
		an.rig = rig
		an.skeleton = sk
		an.player = ap
		an.head_pivot = head_pivot
		an.blink_enabled = bool(opts.get("blink", true))
		if an.blink_enabled:
			if ps2:
				an.blink_enabled = _setup_face_cells(an, (rig["face_mesh"] as MeshInstance3D).material_override as StandardMaterial3D)
			else:
				var face_mat: StandardMaterial3D = _face_mat(skin_idx, female)
				var closed_tex: Texture2D = _tex("char_face_%s%s_closed.png" % [SKIN_KEYS[skin_idx], "f" if female else "m"])
				if face_mat.albedo_texture and closed_tex:
					var own: StandardMaterial3D = face_mat.duplicate()
					(rig["face_mesh"] as MeshInstance3D).material_override = own
					an.face_mat = own
					an.face_open = face_mat.albedo_texture
					an.face_closed = closed_tex
				else:
					an.blink_enabled = false
		an.rng_phase = rng.randf() * TAU
		root.add_child(an)
		var clip: String = String(opts.get("clip", ""))
		if clip != "":
			an.play(clip)
	return root

## Mặt vải thứ hai/ba trên thân mô hình (áo vest, cà vạt, áo gi-lê): giữ màu gốc nhưng theo phong cách toon
static func _rig_extra_mat(src: Material, outfit: Dictionary, idx: int) -> Material:
	if outfit.has("tie_mat") and idx == 1:
		return outfit["tie_mat"]
	var c: Color = (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color(0.5, 0.5, 0.5)
	return _cloth_mat("rig_" + c.to_html(false), c)

## Logo FPT ngực trái, dây thẻ, bảng tên, tạp dề, ba lô gắn vào xương Chest/Hips (vị trí theo mô hình Quaternius, mô hình nhìn +Z)
static func _rig_torso_extras(chest: Node3D, hips: Node3D, outfit: Dictionary, width: float) -> void:
	var front: float = 1.0   # +Z của mô hình là phía trước
	var cz: float = 0.125 * width
	if outfit.get("preset", "") in ["student", "student_m", "student_f", "player", "rider", "casual"] or outfit.get("logo", true):
		var logo: Texture2D = _tex("char_fpt_logo.png")
		if logo:
			var qm := QuadMesh.new()
			qm.size = Vector2(0.07, 0.035)
			var lm := StandardMaterial3D.new()
			lm.albedo_texture = logo
			lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			lm.alpha_scissor_threshold = 0.5
			lm.roughness = 0.9
			var mi := MeshInstance3D.new()
			mi.mesh = qm
			mi.material_override = lm
			mi.position = Vector3(0.06 * width, 0.04, front * (cz + 0.012))
			mi.rotation.y = 0.0 if front > 0.0 else PI
			chest.add_child(mi)
	if outfit.get("lanyard", false):
		var ly: Material = _mat("lanyard", Color("#1F4FA3"), 0.9)
		_box(chest, Vector3(-0.045, 0.02, front * (cz + 0.01)), Vector3(0.012, 0.22, 0.004), ly, Vector3(0.0, 0.0, -0.32))
		_box(chest, Vector3(0.045, 0.02, front * (cz + 0.01)), Vector3(0.012, 0.22, 0.004), ly, Vector3(0.0, 0.0, 0.32))
		var card := _box(chest, Vector3(0.0, -0.115, front * (cz + 0.012)), Vector3(0.062, 0.088, 0.004), _mat("id_card", Color("#F7F7F7"), 0.5))
		_box(card, Vector3(0.0, 0.03, front * 0.003), Vector3(0.062, 0.02, 0.002), _mat("id_stripe", FPT_ORANGE, 0.5))
		_box(card, Vector3(0.0, -0.012, front * 0.003), Vector3(0.036, 0.034, 0.002), _mat("id_photo", Color("#B9C2CC"), 0.6))
	if outfit.get("badge", false):
		_box(chest, Vector3(-0.07 * width, 0.05, front * (cz + 0.01)), Vector3(0.05, 0.022, 0.006), _mat("badge", Color("#D4AF37"), 0.3, 0.9))
	if outfit.get("apron", false):
		_box(hips, Vector3(0.0, 0.1, front * (cz + 0.03)), Vector3(0.30 * width, 0.62, 0.012), outfit["apron_mat"])
	if outfit.get("vovinam_belt", false):
		var vb: Material = outfit["vbelt_mat"]
		_box(hips, Vector3(0.0, 0.12, 0.0), Vector3(0.34 * width, 0.06, 0.25 * width), vb)
		_box(hips, Vector3(-0.03, 0.02, front * (cz + 0.012)), Vector3(0.03, 0.2, 0.012), vb, Vector3(0.0, 0.0, 0.1))
		_box(hips, Vector3(0.03, 0.02, front * (cz + 0.012)), Vector3(0.03, 0.2, 0.012), vb, Vector3(0.0, 0.0, -0.1))
	if outfit.get("backpack", false):
		var bp: Material = outfit["backpack_mat"]
		_box(chest, Vector3(0.0, -0.08, -front * (cz + 0.08)), Vector3(0.25 * width, 0.33, 0.12), bp)
		_box(chest, Vector3(0.0, 0.03, -front * (cz + 0.145)), Vector3(0.22 * width, 0.10, 0.03), bp)
		_box(chest, Vector3(0.0, -0.19, -front * (cz + 0.145)), Vector3(0.18 * width, 0.14, 0.03), outfit["backpack_pocket_mat"])

## Vice (ps2): logo polo FPT, dây thẻ chữ V từ cổ xuống thẻ, bảng tên, ba lô áp lưng + quai qua vai, tạp dề, đai Vovinam ôm eo,
## đặt theo dáng thân đo được (_body_fit) trong các nút "khớp" có trục nhân vật ở tư thế nghỉ (_fit_node: xương Hips nghỉ của
## Quaternius xoay ~27° quanh Y, Chest cúi ~8°, nên hộp gắn thẳng vào xương bị lệch / lơ lửng). Nút nằm trong mô hình nên đồ co
## giãn theo bề ngang wk cùng thân. Kích thước đồ như thân tự dựng; cổ điển giữ _rig_torso_extras.
static func _rig_torso_extras_ps2(model: Node3D, sk: Skeleton3D, rig: Dictionary, outfit: Dictionary, rel: String) -> void:
	var f: Dictionary = _body_fit(rel, model, sk)
	var c_xf: Transform3D = f["c_xf"]
	var chest: Node3D = _fit_node(rig["chest"], sk, c_xf, "Chest", "ChestFit")
	var front := Vector3(0.0, 0.0, -1.0)
	if outfit.get("fpt_polo", false):
		var logo: Texture2D = _tex("char_fpt_logo.png")
		if logo:
			var qm := QuadMesh.new()
			qm.size = Vector2(0.07, 0.035)
			var lm := StandardMaterial3D.new()
			lm.albedo_texture = logo
			lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			lm.alpha_scissor_threshold = 0.5
			lm.roughness = 0.9
			var mi := MeshInstance3D.new()
			mi.mesh = qm
			mi.material_override = lm
			var n: Vector3 = f["logo_n"]   # pháp tuyến mặt ngực (hướng -Z), mặt quad (+Z cục bộ) quay theo
			var up: Vector3 = Vector3(0.0, -n.z, n.y)
			mi.basis = Basis(up.cross(n), up, n)
			mi.position = f["logo"]
			chest.add_child(mi)
	if outfit.get("lanyard", false):
		var ly: Material = _mat("lanyard", Color("#1F4FA3"), 0.9)
		for side: Array in f["lanyard"]:   # mỗi bên: cổ -> giữa ngực -> đỉnh chữ V trên thẻ
			_strap(chest, side[0], side[1], 0.012, 0.003, ly, front)
			_strap(chest, side[1], side[2], 0.012, 0.003, ly, front)
		var card := _box(chest, f["card"], Vector3(0.062, 0.088, 0.004), _mat("id_card", Color("#F7F7F7"), 0.5))
		_box(card, Vector3(0.0, 0.03, -0.003), Vector3(0.062, 0.02, 0.002), _mat("id_stripe", FPT_ORANGE, 0.5))
		_box(card, Vector3(0.0, -0.012, -0.003), Vector3(0.036, 0.034, 0.002), _mat("id_photo", Color("#B9C2CC"), 0.6))
	if outfit.get("badge", false):
		_box(chest, f["badge"], Vector3(0.05, 0.022, 0.006), _mat("badge", Color("#D4AF37"), 0.3, 0.9))
	if outfit.get("backpack", false):
		var bp: Material = outfit["backpack_mat"]
		var pc: Vector3 = f["pack"]   # tâm khối ba lô: mặt trước áp vào chỗ lưng nhô nhất trong vùng ba lô
		_box(chest, pc, Vector3(0.25, 0.33, 0.12), bp)
		_box(chest, pc + Vector3(0.0, 0.115, 0.075), Vector3(0.22, 0.10, 0.03), bp)
		_box(chest, pc + Vector3(0.0, -0.075, 0.075), Vector3(0.18, 0.14, 0.03), outfit["backpack_pocket_mat"])
		for side: Array in f["pack_straps"]:   # mỗi bên: mép trên ba lô -> đỉnh vai -> mép trước vai -> trước ngực
			_strap(chest, side[0], side[1], 0.03, 0.012, bp, Vector3.UP)
			_strap(chest, side[1], side[2], 0.03, 0.012, bp, Vector3(0.0, 1.0, -1.0))
			_strap(chest, side[2], side[3], 0.03, 0.012, bp, front)
	if outfit.get("apron", false) and not rig.has("torso"):
		push_warning("CharacterBuilder: thân %s không có pivot \"torso\", bỏ tạp dề" % rel)
	if outfit.get("apron", false) and rig.has("torso"):
		var am: Material = outfit["apron_mat"]
		var tf: Node3D = _fit_node((rig["torso"] as Node3D).get_parent() as Node3D, sk, c_xf, "Torso", "TorsoFit")
		var ap: Vector3 = f["apron"]
		_box(tf, ap, Vector3(0.30, f["apron_h"], 0.012), am)
		for side: Array in f["apron_straps"]:   # góc trên yếm -> hai bên cổ
			_strap(tf, side[0], side[1], 0.016, 0.006, am, front)
	if outfit.get("vovinam_belt", false):
		var vb: Material = outfit["vbelt_mat"]
		var hf: Node3D = _fit_node(rig["hips"], sk, c_xf, "Hips", "HipsFit")
		var bc: Vector3 = f["belt_c"]
		var ab: Vector2 = f["belt_ab"]   # bán trục ngang / sâu của vòng đai (ôm mọi đỉnh của eo)
		_cyl(hf, bc, 0.1, 0.1, 0.05, vb, Vector3.ZERO, Vector3(ab.x / 0.1, 1.0, ab.y / 0.1))
		_box(hf, f["belt_knot"], Vector3(0.07, 0.05, 0.02), vb)
		for side: Array in f["belt_tails"]:
			_strap(hf, side[0], side[1], 0.03, 0.012, vb, front)

## Nút con của BoneAttachment3D att có trục = trục nhân vật ở tư thế nghỉ và gốc tại gốc hệ C (hệ nhân vật chưa nhân bề ngang wk;
## c_xf: skeleton -> C): con của nút đặt thẳng bằng toạ độ hệ C, rồi đi theo xương bone.
static func _fit_node(att: Node3D, sk: Skeleton3D, c_xf: Transform3D, bone: String, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.transform = (c_xf * sk.get_bone_global_rest(sk.find_bone(bone))).affine_inverse()
	att.add_child(n)
	return n

## Dải phẳng rộng w, dày t (quai, dây) nối p0 -> p1 trong parent; mặt rộng quay về phía out (vd -Z: áp lên ngực).
static func _strap(parent: Node3D, p0: Vector3, p1: Vector3, w: float, t: float, mat: Material, out: Vector3) -> MeshInstance3D:
	var d: Vector3 = p1 - p0
	var y: Vector3 = d.normalized()
	var x: Vector3 = y.cross(out).normalized()
	var mi := _box(parent, (p0 + p1) * 0.5, Vector3(w, d.length(), t), mat)
	mi.basis = Basis(x, y, x.cross(y))
	return mi

## Dáng thân Quaternius cho _rig_torso_extras_ps2, đo MỘT lần mỗi tệp mô hình (cache): đỉnh của các mesh skinned đang hiện (trừ
## giày) skin ở tư thế NGHỈ (bind pose glTF khác tư thế nghỉ) trong hệ C (mặt trước -Z, phải +X, đơn vị gốc trước root.scale),
## rồi chỗ đặt từng món đồ: cực trị (_env) của các đỉnh trong hộp quanh chỗ đó, nên đồ nằm ngoài mặt thân (+ khe vài mm).
## Độ cao tính từ gốc xương (Neck / Chest / Hips) nên khớp cả thân nam lẫn nữ.
static var _body_fit_cache: Dictionary = {}
static var _env_misses: Array[String] = []   # hộp mẫu rỗng (_env dùng giá trị dự phòng) của lần _body_fit đang chạy

static func _body_fit(rel: String, model: Node3D, sk: Skeleton3D) -> Dictionary:
	if _body_fit_cache.has(rel):
		return _body_fit_cache[rel]
	_env_misses.clear()
	var c_xf: Transform3D = Transform3D(Basis(Vector3.UP, MODEL_YAW), Vector3.ZERO) * _local_xform(sk, model)
	var pts := PackedVector3Array()
	for mi: MeshInstance3D in _mesh_instances(sk):
		if not mi.visible or mi.skin == null or mi.mesh == null or String(mi.name).ends_with("_Feet"):
			continue
		var skin: Skin = mi.skin
		var xfs: Array[Transform3D] = []
		var arm: Array[bool] = []   # tay buông hai bên (cánh tay, cổ tay, ngón) không thuộc dáng thân: bỏ
		for i: int in range(skin.get_bind_count()):
			var bn: StringName = skin.get_bind_name(i)
			var b: int = sk.find_bone(String(bn)) if bn != &"" else skin.get_bind_bone(i)
			xfs.append(c_xf * sk.get_bone_global_rest(b) * skin.get_bind_pose(i) if b >= 0 else c_xf)
			var nm: String = sk.get_bone_name(b) if b >= 0 else ""
			arm.append(nm.contains("Arm") or nm.contains("Wrist") or nm.contains("Thumb") or nm.contains("Index") or nm.contains("Middle") or nm.contains("Ring") or nm.contains("Pinky"))
		for si: int in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(si)
			if arr[Mesh.ARRAY_BONES] == null or arr[Mesh.ARRAY_WEIGHTS] == null:
				continue
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per: int = bones.size() / maxi(verts.size(), 1)
			for i: int in range(verts.size()):
				var p := Vector3.ZERO
				var w_arm: float = 0.0
				for k: int in range(per):
					var wt: float = weights[i * per + k]
					if wt > 0.0:
						p += (xfs[bones[i * per + k]] * verts[i]) * wt
						if arm[bones[i * per + k]]:
							w_arm += wt
				if w_arm < 0.5:
					pts.append(p)
	var oc: Vector3 = (c_xf * sk.get_bone_global_rest(sk.find_bone("Chest"))).origin
	var on: Vector3 = (c_xf * sk.get_bone_global_rest(sk.find_bone("Neck"))).origin
	var oh: Vector3 = (c_xf * sk.get_bone_global_rest(sk.find_bone("Hips"))).origin
	var zc: float = oc.z   # mặt phẳng giữa thân (trước: z < zc)
	var mx: float = oc.x   # đường giữa thân ở ngực (xương thân nữ lệch +1.4 cm)
	var f: Dictionary = {"c_xf": c_xf}
	# logo ngực trái (-X), nghiêng theo dốc ngực
	var ly: float = oc.y + 0.035
	var zl: float = _front(pts, mx - 0.062, ly, 0.022, 0.02, zc, zc - 0.12)
	var dz: float = _front(pts, mx - 0.062, ly + 0.03, 0.022, 0.015, zc, zl) - _front(pts, mx - 0.062, ly - 0.03, 0.022, 0.015, zc, zl)
	f["logo"] = Vector3(mx - 0.062, ly, zl - 0.003)
	f["logo_n"] = Vector3(0.0, dz / 0.06, -1.0).normalized()
	# bảng tên ngực trái như thân tự dựng (ngoài dây thẻ)
	var yb: float = oc.y + 0.05
	f["badge"] = Vector3(mx - 0.075, yb, _front(pts, mx - 0.075, yb, 0.025, 0.02, zc, zc - 0.12) - 0.006)
	# dây thẻ: hai bên cổ (x 0.05, ngang cổ áo) -> giữa ngực -> đỉnh chữ V ngay trên mép thẻ (đối xứng: lấy bên nhô hơn); thẻ
	# treo thẳng trước ngực
	var yc: float = oc.y - 0.10
	var zcard: float = _front(pts, mx, yc, 0.035, 0.045, zc, zc - 0.12)
	f["card"] = Vector3(mx, yc, zcard - 0.006)
	var y0: float = on.y - 0.035
	var y2: float = yc + 0.048
	var lz: Array = []
	for q: Vector2 in [Vector2(0.05, y0), Vector2(0.03, (y0 + y2) * 0.5), Vector2(0.007, y2)]:
		lz.append(minf(_front(pts, mx - q.x, q.y, 0.015, 0.015, zc, zcard), _front(pts, mx + q.x, q.y, 0.015, 0.015, zc, zcard)) - 0.005)
	lz[2] = minf(lz[2], zcard - 0.006)   # đỉnh chữ V chạm mép trên thẻ
	# dây nằm TRÊN logo polo: điểm giữa ngực trước mặt logo, và đoạn giữa ngực -> cổ ở độ cao mép trên logo cũng vậy (thân nam
	# có hõm cổ sâu 2-3 cm: đoạn thẳng tới cổ đo được lùi sau logo, logo che dây) -> kéo điểm cổ ra vừa đủ
	var zlogo: float = (f["logo"] as Vector3).z - 0.003
	lz[1] = minf(lz[1], zlogo)
	var tl: float = (ly + 0.0175 - (y0 + y2) * 0.5) / (y0 - (y0 + y2) * 0.5)   # mép trên logo trên đoạn giữa ngực -> cổ
	if tl > 0.0:
		lz[0] = minf(lz[0], lz[1] + (zlogo - lz[1]) / tl)
	var lan: Array = []
	for sx: float in [-1.0, 1.0]:
		lan.append([Vector3(mx + sx * 0.05, y0, lz[0]), Vector3(mx + sx * 0.03, (y0 + y2) * 0.5, lz[1]), Vector3(mx + sx * 0.007, y2, lz[2])])
	f["lanyard"] = lan
	# ba lô: đỉnh ngang bả vai, cao 0.33; mặt trước áp chỗ lưng nhô nhất trong vùng |x| < 0.12. Quai (3 đoạn): mép trên ba lô ->
	# đỉnh vai (x 0.105: vai thân Quaternius dốc lên sát cổ tới ngang cằm) -> mép trước vai -> trước ngực ngang nách
	var top: float = oc.y + 0.085
	var zback: float = _env(pts, Vector3(mx - 0.12, top - 0.33, zc), Vector3(mx + 0.12, top, 1.0), 2, 1.0, zc + 0.12)
	f["pack"] = Vector3(mx, top - 0.165, zback + 0.006 + 0.06)
	var straps: Array = []
	for sx: float in [-1.0, 1.0]:
		var xs: float = mx + sx * 0.105
		var ysh: float = _env(pts, Vector3(xs - 0.015, oc.y - 0.05, zc - 0.08), Vector3(xs + 0.015, on.y + 0.08, zc + 0.08), 1, 1.0, top + 0.03)
		var yft: float = ysh - 0.035
		var zft: float = _front(pts, xs, yft, 0.015, 0.015, zc + 0.04, zc - 0.06)
		var ylow: float = oc.y - 0.06
		var zlow: float = _front(pts, xs, ylow, 0.02, 0.02, zc, zc - 0.1)
		straps.append([Vector3(mx + sx * 0.1, top - 0.012, zback + 0.008), Vector3(xs, ysh + 0.01, zc), Vector3(xs, yft, zft - 0.008), Vector3(xs, ylow, minf(zlow, zft) - 0.008)])
	f["pack_straps"] = straps
	# tạp dề: từ giữa đùi tới ngực, áp chỗ thân nhô nhất từ trên háng lên (đùi để tự do: tư thế nghỉ chân phải bước tới)
	var ap_bot: float = oh.y - 0.22
	var ap_top: float = oc.y
	var zap: float = _env(pts, Vector3(mx - 0.15, oh.y + 0.08, -1.0), Vector3(mx + 0.15, ap_top, zc), 2, -1.0, zc - 0.15) - 0.012
	f["apron"] = Vector3(mx, (ap_bot + ap_top) * 0.5, zap)
	f["apron_h"] = ap_top - ap_bot
	var zn: float = minf(_front(pts, mx - 0.052, y0, 0.018, 0.02, zc, zap), _front(pts, mx + 0.052, y0, 0.018, 0.02, zc, zap))
	var ast: Array = []
	for sx: float in [-1.0, 1.0]:
		ast.append([Vector3(mx + sx * 0.11, ap_top - 0.006, zap - 0.004), Vector3(mx + sx * 0.052, y0 + 0.01, zn - 0.004)])
	f["apron_straps"] = ast
	# đai Vovinam ở eo: 0.58 chiều cao mô hình (vòng hẹp nhất đo được: nam 1.078, nữ 1.086), elip ôm mọi đỉnh của lát eo
	var ybelt: float = MODEL_HEIGHT * 0.58
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var ring := PackedVector2Array()
	for p: Vector3 in pts:
		if absf(p.y - ybelt) < 0.025 and absf(p.x - oh.x) < 0.25 and absf(p.z - oh.z) < 0.25:
			ring.append(Vector2(p.x, p.z))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var cen: Vector2 = (lo + hi) * 0.5 if ring.size() > 0 else Vector2(oh.x, oh.z)
	var half: Vector2 = (hi - lo) * 0.5 if ring.size() > 0 else Vector2(0.15, 0.11)
	var kmax: float = 1.0
	for q: Vector2 in ring:
		kmax = maxf(kmax, Vector2((q.x - cen.x) / half.x, (q.y - cen.y) / half.y).length())
	var ab: Vector2 = half * kmax + Vector2(0.006, 0.006)
	f["belt_c"] = Vector3(cen.x, ybelt, cen.y)
	f["belt_ab"] = ab
	f["belt_knot"] = Vector3(cen.x, ybelt, cen.y - ab.y - 0.006)   # nút thắt 0.02 dày, trước vòng đai
	var zk: float = cen.y - ab.y - 0.022   # hai đuôi đai buông từ mặt trước nút
	var ztail: float = _front(pts, cen.x, ybelt - 0.125, 0.07, 0.095, zc, zk)
	var tails: Array = []
	for sx: float in [-1.0, 1.0]:
		tails.append([Vector3(cen.x + sx * 0.02, ybelt - 0.02, zk), Vector3(cen.x + sx * 0.035, ybelt - 0.2, minf(ztail - 0.008, zk))])
	f["belt_tails"] = tails
	if not _env_misses.is_empty():
		push_warning("CharacterBuilder: thân %s: %d hộp mẫu không có đỉnh nào, đồ ở đó đặt theo giá trị dự phòng: %s" % [rel, _env_misses.size(), ", ".join(_env_misses)])
	_body_fit_cache[rel] = f
	return f

## Số lần nới hộp mẫu rỗng của _env (mỗi lần +25 % kích thước ngang; tối đa gấp 3).
const ENV_GROW_STEPS: int = 8

## Cực trị toạ độ axis (2 = z, 1 = y) của các điểm pts trong hộp [lo, hi]: sgn -1 lấy nhỏ nhất (mặt trước thân, phía -Z), +1 lớn
## nhất (mặt sau, đỉnh vai). Thân nam ít đa giác có ô rộng hơn hộp mẫu 3-4 cm: hộp rỗng được nới hai chiều còn lại quanh tâm
## (không nới trục đo, giữ giới hạn nửa trước / nửa sau), mỗi lần thêm 25 %, tới khi có đỉnh (thân hiện có cần tối đa 4 lần =
## gấp 2). Nới ít nhất có thể: cực trị của hộp to hơn nhô ra hơn mặt thân tại đúng chỗ. Hết ENV_GROW_STEPS lần vẫn rỗng ->
## fallback, ghi hộp vào _env_misses (món đồ có thể lơ lửng hoặc chìm vào thân; _body_fit cảnh báo gộp một lần mỗi mô hình).
static func _env(pts: PackedVector3Array, lo: Vector3, hi: Vector3, axis: int, sgn: float, fallback: float) -> float:
	var c: Vector3 = (lo + hi) * 0.5
	var h: Vector3 = (hi - lo) * 0.5
	for grow: int in range(ENV_GROW_STEPS + 1):
		var a: Vector3 = lo
		var b: Vector3 = hi
		for i: int in range(3):
			if i != axis:
				a[i] = c[i] - h[i] * (1.0 + 0.25 * float(grow))
				b[i] = c[i] + h[i] * (1.0 + 0.25 * float(grow))
		var best: float = -INF
		for p: Vector3 in pts:
			if p.x >= a.x and p.x <= b.x and p.y >= a.y and p.y <= b.y and p.z >= a.z and p.z <= b.z:
				best = maxf(best, p[axis] * sgn)
		if best != -INF:
			return best * sgn
	_env_misses.append("%s..%s" % [lo, hi])   # _body_fit cảnh báo gộp một lần mỗi mô hình
	return fallback

## Mặt trước thân (z nhỏ nhất của nửa trước z < zc) trong ô (x +- hx, y +- hy).
static func _front(pts: PackedVector3Array, x: float, y: float, hx: float, hy: float, zc: float, fallback: float) -> float:
	return _env(pts, Vector3(x - hx, y - hy, -1.0), Vector3(x + hx, y + hy, zc), 2, -1.0, fallback)

## Pivot gắn đồ cho thân rigged theo quy ước thân tự dựng: Node3D đặt tại khớp, trục trùng trục gốc nhân vật ở tư thế
## nghỉ, rồi đi theo xương. Tay / chân: như thân tự dựng, -Y của pivot chạy DỌC CHI (tư thế nghỉ Quaternius lệch: tay buông
## chéo ~28°, cẳng tay phải gập ra trước 23°, đùi phải bước tới 24°, ống chân trái 18°), nên trục gốc được xoay ít nhất để -Y
## trùng trục +Y của xương (hướng về khớp con) và độ dời trong ATTACH_BONES đo dọc chi; thân / cổ giữ trục gốc nhân vật.
## Chỉ để gắn đồ (đồng hồ, tai nghe...): xoay pivot này KHÔNG xoay xương. Một BoneAttachment3D mỗi xương: pivot foot_* nằm
## dưới attachment của knee_* (cùng xương LowerLeg). body: tệp mô hình (vd "men/Casual_2") cho cảnh báo thiếu xương.
static func _rig_attach_pivots(root: Node3D, sk: Skeleton3D, rig: Dictionary, body: String) -> void:
	var to_root: Transform3D = _local_xform(sk, root)
	var att_of: Dictionary = {}   # tên xương -> BoneAttachment3D
	for key: String in ATTACH_BONES.keys():
		if rig.has(key):
			continue
		var spec: Array = ATTACH_BONES[key]
		var bone: String = String(spec[0])
		var b: int = sk.find_bone(bone)
		if b < 0:
			push_warning("CharacterBuilder: thân %s thiếu xương %s, không có pivot %s" % [body, bone, key])
			continue
		var att: BoneAttachment3D = att_of.get(bone, null)
		if att == null:
			att = BoneAttachment3D.new()
			att.name = "Att_" + key
			sk.add_child(att)
			att.bone_name = bone
			att_of[bone] = att
		var rest: Transform3D = to_root * sk.get_bone_global_rest(b)
		var axes := Basis.IDENTITY
		if key != "torso" and key != "neck":
			axes = Basis(Quaternion(Vector3.DOWN, (rest.basis * Vector3.UP).normalized()))
		var pivot := Node3D.new()
		pivot.name = "Pivot_" + key
		pivot.transform = rest.affine_inverse() * Transform3D(axes, rest.origin + axes * (spec[1] as Vector3))
		att.add_child(pivot)
		rig[key] = pivot

## Node Animator của nhân vật (Animator hoặc RigAnimator – cùng giao diện; null nếu dựng với animate=false)
static func get_animator(root: Node3D) -> Node:
	return root.get_node_or_null("Animator")

## Đặt tư thế tĩnh ngay lập tức (không cần Animator / không cần ở trong cây) – dùng trước bake() cho đám đông,
## người ngồi xe NPC, người đứng xa. params: ví dụ {"ride_shoulder": 1.1, "ride_elbow": 0.3, "lean": 0.1}
## Thân rigged: đặt tư thế xương một lần (clip "" = tư thế nghỉ); dùng với animate=false (RigAnimator sẽ đè ở frame sau).
static func pose(root: Node3D, clip: String, t: float = 0.0, params: Dictionary = {}) -> void:
	if root.get_meta("rigged", false):
		_rig_pose(root, clip, t, params)
		return
	var an := Animator.new()
	an.rig = root.get_meta("rig", {})
	for k: String in params.keys():
		an.params[k] = params[k]
	var cpose: Dictionary = an._clip_pose(clip, t) if clip != "" else {}
	an._apply({}, cpose, 1.0 if clip != "" else 0.0, 0.0)
	an.free()

## Tư thế tĩnh cho thân rigged (không cần Animator): xương đặt theo bảng clip của Animator, đè tư thế đứng trung tính
## (_neutral_base); clip "" = đứng trung tính.
static func _rig_pose(root: Node3D, clip: String, t: float, params: Dictionary) -> void:
	var sk: Skeleton3D = root.get_meta("skeleton", null) as Skeleton3D
	if sk == null:
		return
	sk.reset_bone_poses()
	var nb: Dictionary = _base_of(sk)
	if not nb.is_empty():
		for b: int in nb["bones"]:
			var l: Transform3D = nb["local"][b]
			sk.set_bone_pose_position(b, l.origin)
			sk.set_bone_pose_rotation(b, l.basis.get_rotation_quaternion())
	if clip == "":
		_mark_bone_poses_dirty(sk)   # tư thế nghỉ đặt ngoài cây cũng phải còn khi bake() và khi vào cây
		return
	var an := Animator.new()
	an.rig = {}
	for k: String in params.keys():
		an.params[k] = params[k]
	var cpose: Dictionary = an._clip_pose(clip, t)
	an.free()
	_apply_bone_pose(sk, cpose, 1.0)   # tự đánh dấu xương khi ngoài cây


## Tư thế đứng trung tính của thân rigged, thay tư thế nghỉ glTF làm GỐC cho tư thế tĩnh và cho phép xoay khớp của
## _apply_bone_pose / _char_rot_local (RigAnimator dùng chung). Rest của gói Quaternius chính là khung đầu Idle, một thế đứng
## "3/4": hông xoay 27°, chân phải bước trước (bàn chân ~0,36, gối ~0,26 đơn vị mô hình), bàn chân trái xoè 59°; clip tĩnh để
## nguyên chân ("", "phone_stand", người ngồi xe bake...) vì thế lệch chân. Chỉ chỉnh hai chân: đùi xoay quanh khớp hông sao
## cho cổ chân nằm dưới hông (z = trung bình z hai khớp hông, giữ độ dang ngang), gối giữ độ gập; bàn chân (đích IK Foot.L/R,
## con của Root) đặt phẳng ở độ cao cũ dưới cổ chân mới, xoè đối xứng FOOT_TOE_OUT. Hông / thân trên giữ rest (RigAnimator đặt
## "hips" trong khung Body của animation). Tính một lần mỗi thân (theo đường dẫn mô hình, _base_cache), gắn vào skeleton (meta
## "base"): {"local", "global": Array[Transform3D] mọi xương, "bones": xương khác rest}. {} khi thiếu xương chân -> dùng rest.
const FOOT_TOE_OUT: float = 0.21   # ~12°
static var _base_cache: Dictionary = {}

static func _neutral_base(sk: Skeleton3D) -> Dictionary:
	var uls: Array[int] = [sk.find_bone("UpperLeg.L"), sk.find_bone("UpperLeg.R")]
	var lls: Array[int] = [sk.find_bone("LowerLeg.L"), sk.find_bone("LowerLeg.R")]
	var fts: Array[int] = [sk.find_bone("Foot.L"), sk.find_bone("Foot.R")]
	if (uls + lls + fts).has(-1):
		return {}
	var n: int = sk.get_bone_count()
	var loc: Array[Transform3D] = []
	var glob: Array[Transform3D] = []
	for b: int in range(n):
		loc.append(sk.get_bone_rest(b))
		glob.append(sk.get_bone_global_rest(b))
	var zmid: float = (glob[uls[0]].origin.z + glob[uls[1]].origin.z) * 0.5
	var bones := PackedInt32Array()
	for i: int in range(2):
		var u: int = uls[i]
		var lg0: Transform3D = glob[lls[i]]
		var hip: Vector3 = glob[u].origin
		var ankle: Vector3 = lg0.origin + lg0.basis.y.normalized() * ANKLE_DOWN_SHIN
		var v: Vector3 = ankle - hip
		var tgt := Vector3(v.x, 0.0, zmid - hip.z)
		tgt.y = -sqrt(maxf(v.length_squared() - tgt.x * tgt.x - tgt.z * tgt.z, 0.0))
		var ug := Transform3D(Basis(Quaternion(v.normalized(), tgt.normalized())) * glob[u].basis, hip)
		var pu: int = sk.get_bone_parent(u)
		loc[u] = (glob[pu].affine_inverse() * ug) if pu >= 0 else ug
		var lg: Transform3D = ug * loc[lls[i]]
		var ankle_n: Vector3 = lg.origin + lg.basis.y.normalized() * ANKLE_DOWN_SHIN
		# bàn chân: trục Y của xương Foot chạy gót -> mũi (nằm ngang); chân trái (+X) xoè về +X, chân phải về -X
		var f: int = fts[i]
		var fg: Transform3D = glob[f]
		var ry := Basis(Vector3.UP, (FOOT_TOE_OUT if i == 0 else -FOOT_TOE_OUT) - atan2(fg.basis.y.x, fg.basis.y.z))
		var off: Vector3 = ry * (fg.origin - ankle)
		var fgn := Transform3D(ry * fg.basis, Vector3(ankle_n.x + off.x, fg.origin.y, ankle_n.z + off.z))
		var pf: int = sk.get_bone_parent(f)
		loc[f] = (glob[pf].affine_inverse() * fgn) if pf >= 0 else fgn
		bones.append(u)
		bones.append(f)
	for b: int in range(n):   # toàn cục từ cục bộ mới (đi ngược lên chuỗi cha; một lần mỗi thân)
		var xf: Transform3D = loc[b]
		var p: int = sk.get_bone_parent(b)
		while p >= 0:
			xf = loc[p] * xf
			p = sk.get_bone_parent(p)
		glob[b] = xf
	return {"local": loc, "global": glob, "bones": bones}


## Gốc tư thế của skeleton (meta "base" từ _neutral_base), {} = dùng rest.
static func _base_of(sk: Skeleton3D) -> Dictionary:
	return sk.get_meta("base") if sk.has_meta("base") else {}


static func _base_local(sk: Skeleton3D, nb: Dictionary, b: int) -> Transform3D:
	return nb["local"][b] if not nb.is_empty() else sk.get_bone_rest(b)


static func _base_global(sk: Skeleton3D, nb: Dictionary, b: int) -> Transform3D:
	return nb["global"][b] if not nb.is_empty() else sk.get_bone_global_rest(b)


## Godot 4.7: ngoài cây, set_bone_pose_*() không đánh dấu tư thế toàn cục của xương cần tính lại, nên get_bone_global_pose()
## (bake) và cả lần vào cây sau đó vẫn thấy tư thế cũ; force_update_all_bone_transforms() cũng bỏ qua xương không bị đánh dấu.
## Gán lại show_rest_only (giá trị không đổi) đánh dấu lại mọi xương. Trong cây không cần (setter tự đánh dấu).
static func _mark_bone_poses_dirty(sk: Skeleton3D) -> void:
	if not sk.is_inside_tree():
		sk.show_rest_only = sk.show_rest_only


## Áp tư thế {khớp: Euler hệ nhân vật} lên xương Quaternius, trộn với tư thế hiện tại theo w (1 = đè hẳn):
## local = (Pg⁻¹·R·Pg)·base_local (Pg⁻¹·R·Pg ở _char_rot_local; base = tư thế đứng trung tính _neutral_base, thiếu thì rest); "hips_y" dời xương Body (đơn vị mô hình). Nơi DUY NHẤT
## chứa phép này: pose() tĩnh và RigAnimator (_apply_bones, _hips_roll) đều gọi hàm này. Gọi được cả khi skeleton ngoài
## cây (tự đánh dấu xương).
static func _apply_bone_pose(sk: Skeleton3D, cpose: Dictionary, w: float) -> void:
	var nb: Dictionary = _base_of(sk)
	for k: String in cpose.keys():
		if not BONE_OF.has(k):
			continue
		var b: int = sk.find_bone(String(BONE_OF[k]))
		if b < 0:
			continue
		var local: Basis = _char_rot_local(sk, b, cpose[k]) * _base_local(sk, nb, b).basis
		var q_cur: Quaternion = sk.get_bone_pose_rotation(b)
		sk.set_bone_pose_rotation(b, q_cur.slerp(local.get_rotation_quaternion(), w))
	if cpose.has("hips_y"):
		var body: int = sk.find_bone("Body")
		if body >= 0:
			var rest_pos: Vector3 = _base_local(sk, nb, body).origin
			var p: Vector3 = sk.get_bone_pose_position(body)
			sk.set_bone_pose_position(body, p.lerp(rest_pos + Vector3(0.0, float(cpose["hips_y"]), 0.0), w))
	# Bàn chân Quaternius (Foot.L/R) là đích IK con của Root, không phải con của ống chân: clip gập chân mà để nguyên thì bàn chân
	# đứng yên trên sàn và giày bị kéo dài. Như thân tự dựng (bàn chân con của gối): bàn chân đi cứng theo ống chân, rồi quay
	# "foot_l/r" (hệ nhân vật, trong hệ ống chân) quanh cổ chân (ANKLE_DOWN_SHIN dọc ống chân từ gối).
	for s: String in ["l", "r"]:
		if not (cpose.has("thigh_" + s) or cpose.has("knee_" + s) or cpose.has("foot_" + s) or cpose.has("hips_y")):
			continue
		var lb: int = sk.find_bone("LowerLeg." + s.to_upper())
		var fb: int = sk.find_bone("Foot." + s.to_upper())
		if lb < 0 or fb < 0:
			continue
		_foot_follow(sk, lb, fb, _base_global(sk, nb, lb), _base_global(sk, nb, fb), cpose.get("foot_" + s, null), w)
	_mark_bone_poses_dirty(sk)


## Bàn chân fb (đích IK Foot.L/R dưới Root) đi cứng theo ống chân lb: foot = (ống_chân_now · shin_ref⁻¹) · foot_ref, rồi quay
## ef (Euler hệ nhân vật, trong hệ ống chân; null = không quay) quanh cổ chân (ANKLE_DOWN_SHIN dọc ống chân từ gối); trộn vào tư
## thế bàn chân hiện tại theo w. shin_ref / foot_ref: tư thế toàn cục (hệ skeleton) của ống chân và bàn chân khi chúng còn khớp
## nhau – gốc trung tính (_apply_bone_pose) hoặc tư thế ngay trước một lớp xoay cộng thêm (CineActor._add_pose). Nơi DUY NHẤT
## chứa phép bám bàn chân.
static func _foot_follow(sk: Skeleton3D, lb: int, fb: int, shin_ref: Transform3D, foot_ref: Transform3D, ef: Variant, w: float) -> void:
	var follow: Transform3D = _bone_global_now(sk, lb) * shin_ref.affine_inverse()   # chuyển động cứng của ống chân so với ref
	var foot: Transform3D = follow * foot_ref
	if ef is Vector3:
		var e: Vector3 = ef
		if MODEL_YAW != 0.0:
			e = Vector3(-e.x, e.y, -e.z)
		var q: Basis = follow.basis.orthonormalized()
		var rf: Basis = q * Basis.from_euler(e) * q.inverse()
		var ankle: Vector3 = follow * (shin_ref.origin + shin_ref.basis.y.normalized() * ANKLE_DOWN_SHIN)
		foot = Transform3D(rf, ankle - rf * ankle) * foot
	var pf: int = sk.get_bone_parent(fb)
	var local: Transform3D = (_bone_global_now(sk, pf).affine_inverse() * foot) if pf >= 0 else foot
	sk.set_bone_pose_position(fb, sk.get_bone_pose_position(fb).lerp(local.origin, w))
	sk.set_bone_pose_rotation(fb, sk.get_bone_pose_rotation(fb).slerp(local.basis.get_rotation_quaternion(), w))


## Xoay e (Euler hệ nhân vật) đổi sang hệ cục bộ của xương b: Pg⁻¹·R·Pg, Pg = gốc toàn cục (_base_global) của xương cha (mô hình quay
## MODEL_YAW nên đảo dấu x, z). Dùng chung cho _apply_bone_pose (tư thế tuyệt đối) và RigAnimator._add_rot (xoay cộng thêm).
static func _char_rot_local(sk: Skeleton3D, b: int, e: Vector3) -> Basis:
	if MODEL_YAW != 0.0:
		e = Vector3(-e.x, e.y, -e.z)
	var pb: int = sk.get_bone_parent(b)
	var pg: Basis = _base_global(sk, _base_of(sk), pb).basis if pb >= 0 else Basis.IDENTITY
	return pg.inverse() * Basis.from_euler(e) * pg


## Tư thế toàn cục hiện tại của xương b tính từ các tư thế cục bộ (đúng cả ngoài cây và ngay sau khi vừa đặt tư thế, nơi
## Skeleton3D.get_bone_global_pose() có thể còn giá trị cũ).
static func _bone_global_now(sk: Skeleton3D, b: int) -> Transform3D:
	var xf: Transform3D = sk.get_bone_pose(b)
	var p: int = sk.get_bone_parent(b)
	while p >= 0:
		xf = sk.get_bone_pose(p) * xf
		p = sk.get_bone_parent(p)
	return xf

## Người ngồi xe máy đã bake thành 1 MeshInstance3D – cho xe NPC / menu / bãi xe. Gốc đặt tại yên xe:
## pos = (0, cao_yên − 0.62, z_yên). Hướng -Z như xe. Chế độ ps2: thân Quaternius + đầu PS2 (bake không cần vào cây).
static func build_baked_rider(parent: Node3D, pos: Vector3, opts: Dictionary = {}) -> MeshInstance3D:
	var o: Dictionary = opts.duplicate()
	if not o.has("preset"):
		o["preset"] = "rider"
	o["animate"] = false
	o["rigged"] = ps2
	var rig: Node3D = build(o)
	pose(rig, "ride", 0.0, {"ride_shoulder": float(o.get("ride_shoulder", 1.15)), "ride_elbow": float(o.get("ride_elbow", 0.3)), "ride_lean": float(o.get("ride_lean", 0.42)), "lean": float(o.get("lean", 0.0))})
	var mesh: ArrayMesh = bake(rig)
	var mi := MeshInstance3D.new()
	mi.name = String(o.get("name", "Rider"))
	mi.mesh = mesh
	mi.position = pos
	mi.scale = rig.scale
	parent.add_child(mi)
	rig.free()
	return mi

static func play(root: Node3D, clip: String, duration: float = -1.0) -> void:
	var an: Node = get_animator(root)
	if an:
		an.play(clip, duration)

static func stop_clip(root: Node3D) -> void:
	var an: Node = get_animator(root)
	if an:
		an.stop_clip()

## Clip nền: sau mỗi clip one-shot (punch 0.4 s, flinch…) nhân vật quay về clip này thay vì đứng thẳng
static func set_base_clip(root: Node3D, clip: String) -> void:
	var an: Node = get_animator(root)
	if an:
		an.set_base(clip)

static func set_speed(root: Node3D, speed_ms: float) -> void:
	var an: Node = get_animator(root)
	if an:
		an.speed = speed_ms

static func set_param(root: Node3D, key: String, value: float) -> void:
	var an: Node = get_animator(root)
	if an:
		an.params[key] = value

static func look_at_point(root: Node3D, global_point: Variant) -> void:
	var an: Node = get_animator(root)
	if an:
		an.look_target = global_point

## Đổi biểu cảm mặt: "open" (bình thường), "happy", "angry", "surprised", "done" (cạn lời). Chớp mắt vẫn hoạt động.
## Đầu PS2: thêm "talk", "pain"; đổi ô atlas (uv1_offset của vật liệu mặt riêng) thay vì đổi texture.
static func set_expression(root: Node3D, expr: String) -> void:
	var an: Node = get_animator(root)
	var face: MeshInstance3D = get_pivot(root, "face_mesh") as MeshInstance3D
	if face == null:
		return
	var fmat: StandardMaterial3D = face.material_override as StandardMaterial3D
	if fmat and bool(fmat.get_meta("ps2_face", false)):
		var off: Vector3 = PS2Head.cell_offset(expr if expr in PS2Head.CELLS else "open")
		if an and bool(an.get("face_cells")):
			an.face_cell_open = off
			if an._blink_closed <= 0.0:
				fmat.uv1_offset = off
		else:
			fmat.uv1_offset = off
		return
	var idx: int = int(root.get_meta("skin_idx", 1))
	var female: bool = bool(root.get_meta("female", false))
	var tex: Texture2D = _tex("char_face_%s%s_%s.png" % [SKIN_KEYS[idx], "f" if female else "m", expr if expr in EXPRESSIONS else "open"])
	if tex == null:
		return
	var fm: StandardMaterial3D = face.material_override as StandardMaterial3D
	if an and an.face_mat:
		an.face_open = tex
		if an._blink_closed <= 0.0:
			an.face_mat.albedo_texture = tex
	elif fm:
		if fm == _mat_cache.get("face_%d_%s" % [idx, "f" if female else "m"], null):
			fm = fm.duplicate()
			face.material_override = fm
		fm.albedo_texture = tex

static func get_pivot(root: Node3D, key: String) -> Node3D:
	var rig: Dictionary = root.get_meta("rig", {})
	return rig.get(key, null)

static func head_top(root: Node3D) -> Node3D:
	return get_pivot(root, "head_top")

## Độ trong suốt toàn thân (0 = tàng hình). Lần gọi đầu nhân bản vật liệu để không ảnh hưởng người khác.
static func set_opacity(root: Node3D, alpha: float) -> void:
	if not root.has_meta("own_mats"):
		for mi: MeshInstance3D in _mesh_instances(root):
			if mi.material_override:
				var m: Material = mi.material_override.duplicate()
				if m is StandardMaterial3D:
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					m.next_pass = null # bong ma trong suot khong ve vien
				mi.material_override = m
			elif mi.mesh:
				for si: int in mi.mesh.get_surface_count():
					var sm: Material = mi.get_active_material(si)
					if sm is StandardMaterial3D:
						var m2: StandardMaterial3D = sm.duplicate()
						m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						m2.next_pass = null
						mi.set_surface_override_material(si, m2)
		var an: Node = get_animator(root)
		if an and an.face_mat:
			var fm: StandardMaterial3D = get_pivot(root, "face_mesh").material_override
			an.face_mat = fm
		root.set_meta("own_mats", true)
	for mi: MeshInstance3D in _mesh_instances(root):
		var m: Material = mi.material_override
		if m is StandardMaterial3D:
			m.albedo_color.a = alpha
		elif mi.mesh:
			for si: int in mi.mesh.get_surface_count():
				var sm: Material = mi.get_surface_override_material(si)
				if sm is StandardMaterial3D:
					sm.albedo_color.a = alpha
	root.visible = alpha > 0.01

## Gộp toàn bộ mesh của nhân vật (ở tư thế hiện tại) thành 1 ArrayMesh nhiều surface – dùng cho MultiMesh đám đông.
## Thân rigged: xem _bake_rigged (trong hay ngoài cây đều được). Mesh ở hệ gốc nhân vật, chưa nhân root.scale.
static func bake(root: Node3D) -> ArrayMesh:
	if root.get_meta("rigged", false):
		return _bake_rigged(root)
	var inv: Transform3D = root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	var parts: Array = []
	for mi: MeshInstance3D in _mesh_instances(root):
		if mi.mesh == null:
			continue
		parts.append([mi, mi.mesh, (inv * mi.global_transform) if root.is_inside_tree() else _local_xform(mi, root)])
	return _merge_by_material(parts)

## Gộp thân rigged ở tư thế hiện tại (trong hay ngoài cây): phần skinned skin bằng CPU (_skin_cpu), phần gắn xương
## (đầu, đồ gắn) theo tư thế xương. Bỏ mesh ẩn (đầu gốc của mô hình).
static func _bake_rigged(root: Node3D) -> ArrayMesh:
	var sk: Skeleton3D = root.get_meta("skeleton", null) as Skeleton3D
	if sk == null:
		return ArrayMesh.new()
	_mark_bone_poses_dirty(sk)
	var parts: Array = []
	for mi: MeshInstance3D in _mesh_instances(root):
		if mi.mesh == null or not mi.visible:
			continue
		parts.append([mi, _skin_cpu(mi, sk) if mi.skin != null else mi.mesh, _local_xform(mi, root, sk)])
	return _merge_by_material(parts)

## Gộp các phần [MeshInstance3D, mesh nguồn, transform trong hệ gốc] thành 1 ArrayMesh, một surface mỗi vật liệu (dùng chung
## cho bake() thân tự dựng / đồ vật và _bake_rigged). Mesh nguồn có cùng các surface như mi.mesh (bản skin CPU của nó hoặc
## chính nó); vật liệu = get_active_material(si): material_override trước, rồi vật liệu đè của surface, rồi vật liệu của mesh.
static func _merge_by_material(parts: Array) -> ArrayMesh:
	var by_mat: Dictionary = {}
	for part: Array in parts:
		var mi: MeshInstance3D = part[0]
		var src: Mesh = part[1]
		for si: int in range(src.get_surface_count()):
			var mat: Material = mi.get_active_material(si)
			if not by_mat.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_mat[mat] = st
			(by_mat[mat] as SurfaceTool).append_from(src, si, part[2])
	var out := ArrayMesh.new()
	for mat: Material in by_mat.keys():
		var st: SurfaceTool = by_mat[mat]
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## Mesh skinned của mi ở tư thế xương hiện tại, skin bằng CPU: đỉnh = Σ w·(tư_thế_toàn_cục_xương · bind_pose)·đỉnh, trong hệ
## của mi (như renderer), bỏ xương / trọng số. Không dùng MeshInstance3D.bake_mesh_from_current_skeleton_pose(): hàm đó đọc
## xương từ RenderingServer – rỗng khi chạy headless (lỗi "skin registered with a valid skeleton"), và chỉ được ghi ở lần cập
## nhật skeleton trễ cuối frame, nên tư thế vừa đặt chưa có. Cache theo GIÁ TRỊ (mesh, transform skin của mọi xương; so khớp
## đúng từng số, không qua băm 32 bit): mọi người ngồi xe cùng mô hình chỉ skin một lần (~8 nghìn đỉnh, vài ms).
static func _skin_cpu(mi: MeshInstance3D, sk: Skeleton3D) -> ArrayMesh:
	var skin: Skin = mi.skin
	var src: Mesh = mi.mesh
	var xfs: Array[Transform3D] = []
	for i: int in range(skin.get_bind_count()):
		var bn: StringName = skin.get_bind_name(i)
		var b: int = sk.find_bone(String(bn)) if bn != &"" else skin.get_bind_bone(i)
		xfs.append(sk.get_bone_global_pose(b) * skin.get_bind_pose(i) if b >= 0 else Transform3D.IDENTITY)
	var key: Array = [src.get_instance_id(), xfs]
	if _skin_cache.has(key):
		return _skin_cache[key]
	var out := ArrayMesh.new()
	for si: int in range(src.get_surface_count()):
		var prim: Mesh.PrimitiveType = (src as ArrayMesh).surface_get_primitive_type(si) if src is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		var arr: Array = src.surface_get_arrays(si)
		if arr[Mesh.ARRAY_BONES] != null and arr[Mesh.ARRAY_WEIGHTS] != null:
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var tans: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT] if arr[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var nv: int = verts.size()
			var per: int = bones.size() / maxi(nv, 1)   # 4 hoặc 8 xương mỗi đỉnh
			var has_n: bool = norms.size() == nv
			var has_t: bool = tans.size() == nv * 4
			for i: int in range(nv):
				var v: Vector3 = verts[i]
				var p := Vector3.ZERO
				var n := Vector3.ZERO
				var tg := Vector3.ZERO
				var tv := Vector3(tans[i * 4], tans[i * 4 + 1], tans[i * 4 + 2]) if has_t else Vector3.ZERO
				for k: int in range(per):
					var wt: float = weights[i * per + k]
					if wt <= 0.0:
						continue
					var t: Transform3D = xfs[bones[i * per + k]]
					p += (t * v) * wt
					if has_n:
						n += (t.basis * norms[i]) * wt
					if has_t:
						tg += (t.basis * tv) * wt
				verts[i] = p
				if has_n:
					norms[i] = n.normalized()
				if has_t:
					tg = tg.normalized()
					tans[i * 4] = tg.x
					tans[i * 4 + 1] = tg.y
					tans[i * 4 + 2] = tg.z
			arr[Mesh.ARRAY_VERTEX] = verts
			if has_n:
				arr[Mesh.ARRAY_NORMAL] = norms
			if has_t:
				arr[Mesh.ARRAY_TANGENT] = tans
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
		out.add_surface_from_arrays(prim, arr)
	if _skin_cache.size() >= 64:
		_skin_cache.clear()
	_skin_cache[key] = out
	return out

## Transform của n trong hệ root (trong hay ngoài cây), đi ngược từ n lên tới root. sk (thân rigged): mỗi BoneAttachment3D trên
## đường đi (kể cả n) lấy tư thế xương hiện tại thay cho transform của node – ngoài cây transform đó không được cập nhật.
static func _local_xform(n: Node3D, root: Node3D, sk: Skeleton3D = null) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p and p != root and p is Node3D:
		var t: Transform3D = (p as Node3D).transform
		if sk and p is BoneAttachment3D:
			t = sk.get_bone_global_pose(sk.find_bone((p as BoneAttachment3D).bone_name))
		xf = t * xf
		p = p.get_parent()
	return xf

static func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out

# ===========================================================================
# TRANG PHỤC THEO PRESET
# ===========================================================================
static func _outfit_for(preset: String, female: bool, rng: RandomNumberGenerator, opts: Dictionary) -> Dictionary:
	var o: Dictionary = {}
	var trousers_dark: Material = _cloth_mat("trousers_dark", Color("#2B2F3A"))
	var jeans: Material = _denim_mat()
	var white_shoe: Material = _mat("shoe_white", Color("#F2F2F2"), 0.55)
	var black_shoe: Material = _mat("shoe_black", Color("#1B1B1F"), 0.35)
	o["sole_mat"] = _mat("sole", Color("#D9D9D9"), 0.7)
	o["lace_mat"] = _mat("lace", Color("#FFFFFF"), 0.8)
	o["collar_mat"] = _cloth_mat("collar_orange", Color("#D8611B"))
	o["shoes"] = "sneaker"
	o["shoe_mat"] = white_shoe
	o["sleeve"] = 0.14
	o["backpack"] = false
	o["watch"] = rng.randf() < 0.4
	match preset:
		"student", "student_m", "student_f", "player", "rider":
			o["shirt"] = _shirt_fpt_mat()
			o["shirt_plain"] = _cloth_mat("fpt_orange", FPT_ORANGE)
			o["fpt_polo"] = true   # áo polo FPT (logo ngực trái); vice: logo chỉ trên áo này như thân tự dựng
			o["trousers"] = jeans if rng.randf() < 0.7 else trousers_dark
			o["backpack"] = bool(opts.get("backpack", preset == "player" or rng.randf() < 0.55))
			var bp_col: Color = [Color("#1F2A44"), Color("#2E3A2F"), Color("#4A2E6B"), Color("#222222"), Color("#7A1F2B")][rng.randi_range(0, 4)]
			o["backpack_mat"] = _cloth_mat("bp_" + bp_col.to_html(false), bp_col)
			o["backpack_pocket_mat"] = _cloth_mat("bp_pocket_" + bp_col.to_html(false), bp_col.darkened(0.25))
			o["glasses"] = bool(opts.get("glasses", rng.randf() < 0.3))
			o["lanyard"] = rng.randf() < 0.35
			o["wristband"] = preset == "player"
			if preset == "rider":
				o["helmet"] = true
				o["helmet_color"] = opts.get("helmet_color", [Color("#F1C40F"), Color("#2C3E50"), Color("#E74C3C"), Color("#ECF0F1"), Color("#1ABC9C")][rng.randi_range(0, 4)])
			if rng.randf() < 0.25:
				o["shoe_mat"] = black_shoe
		"lecturer", "proctor":
			var shirt_col: Color = Color("#DCE6F2") if preset == "lecturer" else Color("#F5F5F5")
			o["shirt"] = _cloth_mat("shirt_" + shirt_col.to_html(false), shirt_col)
			o["shirt_plain"] = o["shirt"]
			o["collar_mat"] = _cloth_mat("collar_" + shirt_col.to_html(false), shirt_col.darkened(0.08))
			o["sleeve"] = UPPER_ARM_LEN + FOREARM_LEN
			o["trousers"] = _cloth_mat("trousers_navy", Color("#1E2638"))
			o["belt"] = true
			o["belt_mat"] = _mat("belt_leather", Color("#2A1A10"), 0.5)
			o["shoes"] = "leather"
			o["shoe_mat"] = black_shoe
			o["sole_mat"] = _mat("sole_dark", Color("#2B2B2B"), 0.6)
			o["glasses"] = bool(opts.get("glasses", preset == "lecturer" or rng.randf() < 0.5))
			o["lanyard"] = true
			o["tie"] = preset == "proctor"
			o["tie_mat"] = _cloth_mat("tie", Color("#7A1F2B"))
			o["badge"] = preset == "proctor"
			o["watch"] = true
		"guard", "cop":
			var col: Color = Color("#7FB2E5") if preset == "guard" else Color("#C9B87A")
			o["shirt"] = _cloth_mat("uniform_" + col.to_html(false), col)
			o["shirt_plain"] = o["shirt"]
			o["collar_mat"] = _cloth_mat("uniform_collar_" + col.to_html(false), col.darkened(0.12))
			o["sleeve"] = 0.15
			o["trousers"] = _cloth_mat("trousers_uniform", Color("#1C2A4A") if preset == "guard" else Color("#5A4A2E"))
			o["belt"] = true
			o["belt_mat"] = _mat("belt_black", Color("#151515"), 0.45)
			o["epaulettes"] = true
			o["epaulette_mat"] = _cloth_mat("epaulette", col.darkened(0.3))
			o["shoes"] = "leather"
			o["shoe_mat"] = black_shoe
			o["sole_mat"] = _mat("sole_dark", Color("#2B2B2B"), 0.6)
			o["cap"] = true
			o["cap_color"] = Color("#1C2A4A") if preset == "guard" else Color("#5A4A2E")
			o["badge"] = true
		"vovinam", "master":
			var blue: Color = Color("#1F5FBF")
			o["shirt"] = _cloth_mat("vovinam", blue)
			o["shirt_plain"] = o["shirt"]
			o["collar_mat"] = _cloth_mat("vovinam_collar", blue.darkened(0.2))
			o["sleeve"] = UPPER_ARM_LEN + FOREARM_LEN - 0.06
			o["trousers"] = o["shirt"]
			o["vovinam_belt"] = true
			o["vbelt_mat"] = _cloth_mat("vbelt_red" if preset == "master" else "vbelt_yellow", Color("#C0392B") if preset == "master" else Color("#F1C40F"))
			o["shoes"] = "barefoot"
			o["watch"] = false
		"cook":
			o["shirt"] = _cloth_mat("cook_shirt", Color("#F4EFE6"))
			o["shirt_plain"] = o["shirt"]
			o["collar_mat"] = _cloth_mat("cook_collar", Color("#E3DACB"))
			o["sleeve"] = 0.16
			o["trousers"] = _cloth_mat("cook_trousers", Color("#3C3F4A"))
			o["apron"] = true
			o["apron_mat"] = _cloth_mat("apron", Color("#2E7D5B"))
			o["shoes"] = "sandal"
			o["shoe_mat"] = _mat("sandal", Color("#5B3A1E"), 0.6)
			o["chef_hat"] = true
		_: # casual
			var tee: Color = [Color("#2ECC71"), Color("#9B59B6"), Color("#34495E"), Color("#E67E22"), Color("#ECF0F1"), Color("#3498DB")][rng.randi_range(0, 5)]
			o["shirt"] = _cloth_mat("tee_" + tee.to_html(false), tee)
			o["shirt_plain"] = o["shirt"]
			o["collar_mat"] = _cloth_mat("tee_collar_" + tee.to_html(false), tee.darkened(0.15))
			o["trousers"] = jeans if rng.randf() < 0.5 else _cloth_mat("shorts_khaki", Color("#C8B48A"))
			o["shorts"] = rng.randf() < 0.4
			o["glasses"] = rng.randf() < 0.2
			if rng.randf() < 0.3:
				o["shoes"] = "sandal"
				o["shoe_mat"] = _mat("sandal", Color("#5B3A1E"), 0.6)
	if opts.has("shirt_color"):
		var c: Color = opts["shirt_color"]
		o["fpt_polo"] = false
		o["shirt"] = _cloth_mat("custom_" + c.to_html(false), c)
		o["shirt_plain"] = o["shirt"]
		o["collar_mat"] = _cloth_mat("custom_collar_" + c.to_html(false), c.darkened(0.15))
	if opts.has("trousers_color"):
		var c2: Color = opts["trousers_color"]
		o["trousers"] = _cloth_mat("custom_tr_" + c2.to_html(false), c2)
	return o

# ===========================================================================
# TÓC / KÍNH / MŨ
# ===========================================================================
static func _build_hair(head: Node3D, style: String, hair_idx: int, outfit: Dictionary, width: float, rng: RandomNumberGenerator) -> void:
	var hm: Material = _hair_mat(hair_idx)
	var hc := Vector3(0.0, 0.12, 0.0)   # tâm đầu; mắt ở ~hc.y + 0.005; chân tóc trán ~hc.y + 0.05; đỉnh đầu hc.y + 0.122
	var r: float = HEAD_R
	var sxw: float = 0.94 * width
	# Mũ tóc = bán cầu đặt tại chân tóc (hc.y + 0.045), hơi nghiêng ra trước; gáy = cầu dẹt phía sau-dưới
	var cap_pos: Vector3 = hc + Vector3(0.0, 0.045, 0.0)
	var cap_rot := Vector3(-0.1, 0.0, 0.0)
	var cap_scl := Vector3(sxw * 1.06, 1.0, 1.04)
	var nape_pos: Vector3 = hc + Vector3(0.0, 0.0, 0.046)
	var nape_scl := Vector3(sxw * 1.0, 0.78, 0.62)
	if outfit.get("chef_hat", false):
		var chef: Material = _mat("chef_hat", Color("#FAFAFA"), 0.8)
		_cyl(head, hc + Vector3(0.0, 0.16, 0.0), 0.098, 0.104, 0.1, chef)
		_sphere(head, hc + Vector3(0.0, 0.225, 0.0), 0.108, chef, Vector3(1.0, 0.5, 1.0))
		_hemisphere(head, cap_pos, r * 0.98, hm, cap_rot, Vector3(sxw * 1.04, 0.8, 1.02))
		_sphere(head, nape_pos, r * 0.95, hm, nape_scl)
		return
	if outfit.get("cap", false):
		var cm: Material = _cloth_mat("cap_" + (outfit["cap_color"] as Color).to_html(false), outfit["cap_color"])
		_hemisphere(head, hc + Vector3(0.0, 0.04, 0.0), r * 1.08, cm, Vector3(-0.06, 0.0, 0.0), Vector3(sxw * 1.02, 0.8, 1.0))
		_cyl(head, hc + Vector3(0.0, 0.045, 0.0), r * 1.08, r * 1.08, 0.04, cm, Vector3.ZERO, Vector3(sxw * 1.02, 1.0, 1.0))
		_box(head, hc + Vector3(0.0, 0.03, -(r + 0.045)), Vector3(0.17, 0.01, 0.1), _mat("cap_brim", Color("#101418"), 0.5))
		_box(head, hc + Vector3(0.0, 0.085, -(r * 1.0)), Vector3(0.04, 0.03, 0.012), _mat("cap_badge", Color("#D4AF37"), 0.3, 0.9))
		_sphere(head, nape_pos + Vector3(0.0, -0.01, 0.0), r * 0.92, hm, Vector3(sxw * 0.98, 0.6, 0.6))
		return
	# tóc mai hai bên (mọi kiểu) để không bị "hói" cạnh tai
	for sx: float in [-1.0, 1.0]:
		_capsule(head, hc + Vector3(sx * 0.098 * width, 0.085, -0.01), 0.022, 0.09, hm, Vector3(0.0, 0.0, sx * 0.12), Vector3(0.6, 1.0, 1.1))
	match style:
		"short", "undercut":
			_hemisphere(head, cap_pos, r * 1.0, hm, cap_rot, cap_scl)
			if style == "undercut":
				_hemisphere(head, cap_pos + Vector3(0.0, 0.03, 0.0), r * 0.92, hm, Vector3(-0.08, 0.0, 0.0), Vector3(sxw * 0.95, 1.15, 0.95))
			_sphere(head, nape_pos, r * 0.95, hm, nape_scl)
		"side_part":
			_hemisphere(head, cap_pos, r * 1.0, hm, cap_rot, cap_scl)
			_sphere(head, nape_pos, r * 0.95, hm, nape_scl)
			_box(head, hc + Vector3(-0.03, 0.045, -0.088), Vector3(0.09, 0.03, 0.03), hm, Vector3(0.3, 0.0, -0.25))
			_box(head, hc + Vector3(0.045, 0.05, -0.082), Vector3(0.05, 0.026, 0.028), hm, Vector3(0.3, 0.0, 0.5))
		"spiky":
			_hemisphere(head, cap_pos, r * 1.0, hm, Vector3(-0.06, 0.0, 0.0), cap_scl)
			_sphere(head, nape_pos, r * 0.95, hm, nape_scl)
			for i: int in range(7):
				var a: float = rng.randf_range(-0.9, 0.9)
				var z: float = rng.randf_range(-0.07, 0.04)
				_cyl(head, hc + Vector3(a * 0.07, 0.135, z), 0.0, 0.018, 0.05, hm, Vector3(z * -4.0, 0.0, -a * 0.6))
		"bob":
			_hemisphere(head, cap_pos, r * 1.02, hm, cap_rot, Vector3(sxw * 1.08, 1.0, 1.06))
			_sphere(head, nape_pos, r * 1.0, hm, Vector3(sxw * 1.04, 0.8, 0.7))
			for sx: float in [-1.0, 1.0]:
				_capsule(head, hc + Vector3(sx * 0.105 * width, -0.02, 0.02), 0.03, 0.2, hm, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.7))
			_box(head, hc + Vector3(0.0, 0.052, -0.094), Vector3(0.15, 0.03, 0.024), hm, Vector3(0.3, 0.0, 0.0))
		"long":
			_hemisphere(head, cap_pos, r * 1.02, hm, cap_rot, Vector3(sxw * 1.08, 1.0, 1.06))
			_sphere(head, nape_pos, r * 1.0, hm, Vector3(sxw * 1.04, 0.85, 0.75))
			for sx: float in [-1.0, 1.0]:
				_capsule(head, hc + Vector3(sx * 0.105 * width, -0.09, 0.035), 0.03, 0.32, hm, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.6))
			_capsule(head, hc + Vector3(0.0, -0.13, 0.085), 0.045, 0.36, hm, Vector3(0.0, 0.0, 0.0), Vector3(1.9, 1.0, 0.8))
			_box(head, hc + Vector3(0.03, 0.052, -0.094), Vector3(0.1, 0.03, 0.024), hm, Vector3(0.3, 0.0, 0.3))
		"ponytail":
			_hemisphere(head, cap_pos, r * 1.0, hm, cap_rot, cap_scl)
			_sphere(head, nape_pos, r * 0.97, hm, Vector3(sxw * 1.0, 0.7, 0.7))
			var tail := _capsule(head, hc + Vector3(0.0, -0.05, 0.13), 0.03, 0.26, hm, Vector3(0.55, 0.0, 0.0))
			tail.name = "Ponytail"
			_torus(head, hc + Vector3(0.0, 0.04, 0.1), 0.022, 0.034, _mat("hair_tie", Color("#C0392B"), 0.7), Vector3(PI * 0.5 + 0.55, 0.0, 0.0))
			_box(head, hc + Vector3(-0.02, 0.05, -0.09), Vector3(0.1, 0.028, 0.028), hm, Vector3(0.3, 0.0, -0.2))
		"bun":
			_hemisphere(head, cap_pos, r * 0.99, hm, Vector3(-0.05, 0.0, 0.0), cap_scl)
			_sphere(head, nape_pos, r * 0.95, hm, Vector3(sxw, 0.65, 0.65))
			_sphere(head, hc + Vector3(0.0, 0.1, 0.075), 0.045, hm)
		_:
			_hemisphere(head, cap_pos, r * 1.0, hm, cap_rot, cap_scl)
			_sphere(head, nape_pos, r * 0.95, hm, nape_scl)

static func _build_glasses(head: Node3D, width: float) -> void:
	var gm: Material = _mat("glasses", Color("#1A1A1F"), 0.3, 0.6)
	var lens: Material = _mat("lens", Color(0.7, 0.8, 0.9, 0.18), 0.05, 0.0)
	if lens is StandardMaterial3D and (lens as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		(lens as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var y: float = 0.12 + 0.012
	for sx: float in [-1.0, 1.0]:
		_torus(head, Vector3(sx * 0.031 * width, y, -0.097), 0.017, 0.022, gm, Vector3(PI * 0.5, 0.0, 0.0))
		_cyl(head, Vector3(sx * 0.031 * width, y, -0.097), 0.017, 0.017, 0.002, lens, Vector3(PI * 0.5, 0.0, 0.0))
		_box(head, Vector3(sx * 0.072 * width, y, -0.05), Vector3(0.003, 0.003, 0.1), gm)
	_box(head, Vector3(0.0, y + 0.003, -0.1), Vector3(0.02, 0.003, 0.003), gm)

static func _build_helmet(head: Node3D, color: Color, width: float) -> void:
	var hm: Material = _mat("helmet_" + color.to_html(false), color, 0.25, 0.1)
	var hc := Vector3(0.0, 0.12, 0.0)
	# mũ bảo hiểm nửa đầu: vòm từ ngang trán lên, vành + kính che trước, quai cằm
	var parts: Array[MeshInstance3D] = []
	parts.append(_hemisphere(head, hc + Vector3(0.0, 0.02, 0.0), HEAD_R * 1.2, hm, Vector3(-0.05, 0.0, 0.0), Vector3(0.98 * width, 1.05, 1.02)))
	parts.append(_cyl(head, hc + Vector3(0.0, 0.01, 0.0), HEAD_R * 1.2, HEAD_R * 1.2, 0.03, hm, Vector3.ZERO, Vector3(0.98 * width, 1.0, 1.02)))
	parts.append(_box(head, hc + Vector3(0.0, 0.015, -(HEAD_R * 1.18)), Vector3(0.21, 0.012, 0.08), _mat("helmet_visor", Color("#111318"), 0.2, 0.3)))
	for sx: float in [-1.0, 1.0]:
		parts.append(_box(head, hc + Vector3(sx * 0.09 * width, -0.05, -0.02), Vector3(0.01, 0.12, 0.006), _mat("helmet_strap", Color("#222222"), 0.8), Vector3(0.0, 0.0, sx * 0.25)))
	# cinematics hide the helmet when it is knocked or yanked off (CineActor part "helmet")
	for mi: MeshInstance3D in parts:
		mi.set_meta("helmet_part", true)

# ===========================================================================
# MESH / VẬT LIỆU
# ===========================================================================
static func _pivot(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	return n

static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func _capsule(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var key: String = "cap_%.3f_%.3f" % [r, h]
	if not _mesh_cache.has(key):
		var cm := CapsuleMesh.new()
		cm.radius = r
		cm.height = maxf(h, r * 2.0 + 0.001)
		cm.radial_segments = 14
		cm.rings = 5
		_mesh_cache[key] = cm
	return _mi(parent, _mesh_cache[key], mat, pos, rot, scl)

static func _sphere(parent: Node3D, pos: Vector3, r: float, mat: Material, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var key: String = "sph_%.3f" % r
	if not _mesh_cache.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 18
		sm.rings = 9
		_mesh_cache[key] = sm
	return _mi(parent, _mesh_cache[key], mat, pos, Vector3.ZERO, scl)

static func _hemisphere(parent: Node3D, pos: Vector3, r: float, mat: Material, rot: Vector3, scl: Vector3) -> MeshInstance3D:
	var key: String = "hemi_%.3f" % r
	if not _mesh_cache.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		# Godot: với is_hemisphere, `height` là chiều cao của CHÍNH bán cầu (không chia đôi) → đặt = r
		sm.height = r
		sm.is_hemisphere = true
		sm.radial_segments = 22
		sm.rings = 10
		_mesh_cache[key] = sm
	return _mi(parent, _mesh_cache[key], mat, pos, rot, scl)

static func _cyl(parent: Node3D, pos: Vector3, r_top: float, r_bot: float, h: float, mat: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var key: String = "cyl_%.3f_%.3f_%.3f" % [r_top, r_bot, h]
	if not _mesh_cache.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = 18
		cm.rings = 1
		_mesh_cache[key] = cm
	return _mi(parent, _mesh_cache[key], mat, pos, rot, scl)

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key: String = "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _mesh_cache.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_mesh_cache[key] = bm
	return _mi(parent, _mesh_cache[key], mat, pos, rot, Vector3.ONE)

static func _torus(parent: Node3D, pos: Vector3, r_in: float, r_out: float, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key: String = "tor_%.3f_%.3f" % [r_in, r_out]
	if not _mesh_cache.has(key):
		var tm := TorusMesh.new()
		tm.inner_radius = r_in
		tm.outer_radius = r_out
		tm.rings = 24
		tm.ring_segments = 8
		_mesh_cache[key] = tm
	return _mi(parent, _mesh_cache[key], mat, pos, rot, Vector3.ONE)

## Mesh tiện (lathe) tiết diện ellipse. prof: Vector3(rx, y, rz) từ dưới lên.
static func _lathe(prof: Array, seg: int = 20) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: float = maxf(0.001, (prof[prof.size() - 1] as Vector3).y)
	for i: int in range(prof.size() - 1):
		var a: Vector3 = prof[i]
		var b: Vector3 = prof[i + 1]
		var va: float = 1.0 - a.y / top
		var vb: float = 1.0 - b.y / top
		for j: int in range(seg):
			var u0: float = float(j) / float(seg)
			var u1: float = float(j + 1) / float(seg)
			var p00: Vector3 = _ring_pt(a, u0)
			var p01: Vector3 = _ring_pt(a, u1)
			var p10: Vector3 = _ring_pt(b, u0)
			var p11: Vector3 = _ring_pt(b, u1)
			# Godot: mặt trước theo chiều kim đồng hồ nhìn từ ngoài
			st.set_uv(Vector2(u0, va)); st.add_vertex(p00)
			st.set_uv(Vector2(u0, vb)); st.add_vertex(p10)
			st.set_uv(Vector2(u1, vb)); st.add_vertex(p11)
			st.set_uv(Vector2(u0, va)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, vb)); st.add_vertex(p11)
			st.set_uv(Vector2(u1, va)); st.add_vertex(p01)
	st.index()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _ring_pt(p: Vector3, u: float) -> Vector3:
	var a: float = u * TAU
	return Vector3(sin(a) * p.x, p.y, cos(a) * p.z)

static func _torso_mesh(female: bool, width: float) -> ArrayMesh:
	var key: String = "torso_%s_%.2f" % ["f" if female else "m", width]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var prof: Array = []
	if female:
		prof = [Vector3(0.175, 0.0, 0.115), Vector3(0.168, 0.07, 0.112), Vector3(0.14, 0.17, 0.095), Vector3(0.148, 0.26, 0.112), Vector3(0.162, 0.35, 0.128), Vector3(0.165, 0.43, 0.112), Vector3(0.178, 0.49, 0.10), Vector3(0.15, 0.53, 0.085), Vector3(0.06, 0.55, 0.05)]
	else:
		prof = [Vector3(0.17, 0.0, 0.11), Vector3(0.166, 0.08, 0.106), Vector3(0.162, 0.18, 0.102), Vector3(0.18, 0.3, 0.115), Vector3(0.198, 0.4, 0.122), Vector3(0.212, 0.47, 0.116), Vector3(0.196, 0.52, 0.10), Vector3(0.08, 0.55, 0.06)]
	for i: int in range(prof.size()):
		var p: Vector3 = prof[i]
		prof[i] = Vector3(p.x * width, p.y, p.z * width)
	var m: ArrayMesh = _lathe(prof, 22)
	_mesh_cache[key] = m
	return m

static func _tex(file_name: String) -> Texture2D:
	if _tex_cache.has(file_name):
		return _tex_cache[file_name]
	var tex: Texture2D = null
	var path: String = TEX_DIR + file_name
	if FileAccess.file_exists(path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var img := Image.new()
		if img.load_png_from_buffer(bytes) == OK:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_tex_cache[file_name] = tex
	return tex

static func _mat(key: String, color: Color, rough: float = 0.85, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var k: String = "m_" + key
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color * emission
	_style_mat(m, 0.0 if emission > 0.0 else 0.012)
	_mat_cache[k] = m
	return m

static func _cloth_mat(key: String, color: Color) -> StandardMaterial3D:
	var k: String = "cloth_" + key
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	m.metallic = 0.0
	var folds: Texture2D = _tex("char_cloth_folds.png")
	if folds:
		m.albedo_texture = folds # bóng + nếp gấp vẽ sẵn, nhân với màu vải
	var n: Texture2D = _tex("char_cloth_n.png")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.5
	m.uv1_scale = Vector3(4.0, 4.0, 4.0)
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 2.0
	_style_mat(m)
	_mat_cache[k] = m
	return m

static func _denim_mat() -> StandardMaterial3D:
	var k: String = "denim"
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.roughness = 0.95
	var t: Texture2D = _tex("char_denim.png")
	if t:
		m.albedo_texture = t
	else:
		m.albedo_color = Color("#3A4E76")
	var n: Texture2D = _tex("char_denim_n.png")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.5
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	m.uv1_triplanar = true
	_style_mat(m)
	_mat_cache[k] = m
	return m

static func _shirt_fpt_mat() -> StandardMaterial3D:
	var k: String = "shirt_fpt"
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	var t: Texture2D = _tex("char_shirt_fpt.png")
	if t:
		m.albedo_texture = t
		m.albedo_color = Color.WHITE
	else:
		m.albedo_color = FPT_ORANGE
	var n: Texture2D = _tex("char_cloth_n.png")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.35
	_style_mat(m)
	_mat_cache[k] = m
	return m

static func _skin_mat(idx: int) -> StandardMaterial3D:
	var k: String = "skin_%d" % idx
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = SKIN_TONES[idx]
	m.roughness = 0.62
	m.metallic = 0.0
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	var n: Texture2D = _tex("char_skin_n.png")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.25
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(6.0, 6.0, 6.0)
	_style_mat(m)
	_mat_cache[k] = m
	return m

static func _face_mat(idx: int, female: bool) -> StandardMaterial3D:
	var k: String = "face_%d_%s" % [idx, "f" if female else "m"]
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.6
	var t: Texture2D = _tex("char_face_%s%s_open.png" % [SKIN_KEYS[idx], "f" if female else "m"])
	if t:
		m.albedo_texture = t
		m.albedo_color = Color.WHITE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		m.albedo_color = SKIN_TONES[idx]
	_style_mat(m)
	_mat_cache[k] = m
	return m

static func _hair_mat(idx: int) -> StandardMaterial3D:
	var k: String = "hair_%d" % idx
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = HAIR_COLORS[idx]
	m.roughness = 0.45
	m.metallic = 0.15
	m.anisotropy_enabled = true
	m.anisotropy = 0.6
	var n: Texture2D = _tex("char_hair_n.png")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.8
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(5.0, 5.0, 5.0)
	_style_mat(m, 0.014)
	_mat_cache[k] = m
	return m

# ===========================================================================
# ANIMATOR – animation thủ tục
# ===========================================================================
class Animator extends Node:
	var rig: Dictionary = {}
	var hip_base: float = HIP_Y       # cao độ hông khi đứng (ngắn hơn HIP_Y nếu tỉ lệ cách điệu)
	var speed: float = 0.0            # m/s, lái chu kỳ bước
	var look_target: Variant = null   # Vector3 toàn cục hoặc null
	var params: Dictionary = {"lean": 0.0, "run": 0.0}
	var clip: String = ""
	var base_clip: String = ""        # clip nền quay về sau khi clip một lần (one-shot) kết thúc (vd "stance", "sit")
	var clip_time: float = 0.0
	var clip_duration: float = -1.0
	var clip_weight: float = 0.0
	var blink_enabled: bool = true
	var face_mat: StandardMaterial3D
	var face_open: Texture2D
	var face_closed: Texture2D
	var face_cells: bool = false         # đầu PS2: chớp mắt / biểu cảm bằng ô atlas (uv1_offset) thay vì đổi texture
	var face_cell_open: Vector3 = Vector3.ZERO
	var face_cell_closed: Vector3 = Vector3.ZERO
	var rng_phase: float = 0.0
	var _t: float = 0.0
	var _phase: float = 0.0
	var _blink_t: float = 2.0
	var _blink_closed: float = 0.0
	var _lod_t: float = 0.0
	var _lod_skip: int = 1
	var _frame: int = 0
	var _look_yaw: float = 0.0
	var _look_pitch: float = 0.0
	const ONE_SHOT: Dictionary = {"flinch": 0.9, "facepalm": 1.6, "bow": 1.4, "cheer_once": 1.6, "nod": 0.8,
		"jump_takeoff": 0.12, "land_soft": 0.18, "skid": 0.3, "stumble": 0.8, "getup": 0.9}

	func _ready() -> void:
		_t = rng_phase
		_blink_t = randf_range(1.5, 4.5)
		set_process(true)

	func play(name: String, duration: float = -1.0) -> void:
		clip = name
		clip_time = 0.0
		clip_duration = duration if duration > 0.0 else float(ONE_SHOT.get(name, -1.0))

	func stop_clip() -> void:
		clip = base_clip
		clip_time = 0.0
		clip_duration = -1.0

	func set_base(name: String) -> void:
		base_clip = name
		if clip == "" or clip_duration < 0.0:
			clip = name
			clip_time = 0.0
			clip_duration = -1.0

	func _process(delta: float) -> void:
		_frame += 1
		_t += delta
		# LOD: xa camera thì cập nhật thưa
		_lod_t -= delta
		if _lod_t <= 0.0:
			_lod_t = 0.5
			_lod_skip = 1
			var vp: Viewport = get_viewport()
			var cam: Camera3D = vp.get_camera_3d() if vp else null
			var root: Node3D = get_parent() as Node3D
			if cam and root:
				var d: float = cam.global_position.distance_to(root.global_position)
				_lod_skip = 1 if d < 35.0 else (3 if d < 80.0 else (8 if d < 140.0 else 0))
		if _lod_skip == 0 or (_lod_skip > 1 and _frame % _lod_skip != 0):
			return
		var dt: float = delta * float(maxi(_lod_skip, 1))
		if clip != "":
			clip_time += dt
			clip_weight = minf(1.0, clip_weight + dt * float(FAST_BLEND.get(clip, 5.0)))
			if clip_duration > 0.0 and clip_time >= clip_duration:
				clip = base_clip
				clip_time = 0.0
				clip_duration = -1.0
		else:
			clip_weight = maxf(0.0, clip_weight - dt * 4.0)
		var amp: float = clampf(speed / 1.4, 0.0, 1.6)
		_phase += dt * TAU * speed / 1.5
		var loco: Dictionary = _loco_pose(amp)
		var cpose: Dictionary = _clip_pose(clip, clip_time) if clip_weight > 0.001 else {}
		_apply(loco, cpose, clip_weight, dt)
		_blink(dt)

	func _blink(dt: float) -> void:
		if not blink_enabled or face_mat == null:
			return
		if _blink_closed > 0.0:
			_blink_closed -= dt
			if _blink_closed <= 0.0:
				CharacterBuilder._show_face(self, false)
			return
		_blink_t -= dt
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.0, 5.5)
			_blink_closed = 0.13
			CharacterBuilder._show_face(self, true)

	# --- Tư thế đi/đứng (idle ↔ walk/run theo amp)
	func _loco_pose(amp: float) -> Dictionary:
		var p: Dictionary = {}
		var s: float = sin(_phase)
		var c: float = cos(_phase)
		var idle: float = 1.0 - clampf(amp, 0.0, 1.0)
		var run: float = clampf(amp - 1.0, 0.0, 0.6) + float(params.get("run", 0.0))
		var swing: float = 0.5 * minf(amp, 1.0) + 0.35 * run
		# chân: đùi vung trước/sau, gối gập khi vung ra trước
		p["thigh_l"] = Vector3(swing * s, 0.0, 0.03)
		p["thigh_r"] = Vector3(-swing * s, 0.0, -0.03)
		p["knee_l"] = Vector3(-(minf(amp, 1.0) * (0.12 + 0.75 * maxf(0.0, c)) + run * 0.6), 0.0, 0.0)
		p["knee_r"] = Vector3(-(minf(amp, 1.0) * (0.12 + 0.75 * maxf(0.0, -c)) + run * 0.6), 0.0, 0.0)
		p["foot_l"] = Vector3(0.15 * s * minf(amp, 1.0), 0.0, 0.0)
		p["foot_r"] = Vector3(-0.15 * s * minf(amp, 1.0), 0.0, 0.0)
		# tay: ngược chân, hơi dang ra để không xuyên thân, thở khi đứng yên
		var breathe: float = sin(_t * 1.7)
		var arm_swing: float = 0.38 * minf(amp, 1.0) + 0.5 * run
		p["shoulder_l"] = Vector3(-arm_swing * s + idle * 0.03 * breathe, 0.0, 0.14 + idle * 0.02 * sin(_t * 1.1))
		p["shoulder_r"] = Vector3(arm_swing * s + idle * 0.03 * breathe, 0.0, -0.14 - idle * 0.02 * sin(_t * 1.1 + 1.0))
		p["elbow_l"] = Vector3(0.25 + 0.25 * minf(amp, 1.0) + run * 1.1, 0.0, 0.0)
		p["elbow_r"] = Vector3(0.25 + 0.25 * minf(amp, 1.0) + run * 1.1, 0.0, 0.0)
		# thân & đầu: vặn nhẹ khi đi, đổi trọng tâm khi đứng
		p["torso"] = Vector3(-0.08 * minf(amp, 1.0) - run * 0.18, 0.09 * minf(amp, 1.0) * s, 0.0)
		p["hips"] = Vector3(0.0, 0.0, idle * 0.025 * sin(_t * 0.6) + 0.03 * minf(amp, 1.0) * s + float(params.get("lean", 0.0)))
		p["head"] = Vector3(0.02 * breathe * idle, -0.05 * minf(amp, 1.0) * s + idle * (0.12 * sin(_t * 0.37) + 0.06 * sin(_t * 0.91)), 0.0)
		p["hips_y"] = 0.02 * minf(amp, 1.0) * sin(2.0 * _phase) + run * 0.03 * sin(2.0 * _phase)
		p["breathe"] = breathe * idle
		return p

	# --- Các clip; chỉ ghi đè khớp được nêu
	func _clip_pose(name: String, ct: float) -> Dictionary:
		var p: Dictionary = {}
		match name:
			"sit", "type", "eat", "phone", "sleepy_sit":
				p["thigh_l"] = Vector3(1.5, 0.0, 0.1)
				p["thigh_r"] = Vector3(1.5, 0.0, -0.1)
				p["knee_l"] = Vector3(-1.48, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.48, 0.0, 0.0)
				p["foot_l"] = Vector3.ZERO
				p["foot_r"] = Vector3.ZERO
				p["hips_y"] = -(HIP_Y - float(params.get("sit_height", 0.47)))
				p["torso"] = Vector3(0.04, 0.0, 0.0)
				p["shoulder_l"] = Vector3(0.55, 0.0, 0.12)
				p["shoulder_r"] = Vector3(0.55, 0.0, -0.12)
				p["elbow_l"] = Vector3(0.9, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.9, 0.0, 0.0)
				p["head"] = Vector3(0.0, 0.0, 0.0)
				if name == "type":
					var tap: float = sin(ct * 14.0)
					p["torso"] = Vector3(-0.12, 0.0, 0.0)
					p["shoulder_l"] = Vector3(0.45 + 0.04 * tap, 0.0, 0.14)
					p["shoulder_r"] = Vector3(0.45 - 0.04 * tap, 0.0, -0.14)
					p["elbow_l"] = Vector3(1.45 + 0.08 * tap, 0.0, 0.0)
					p["elbow_r"] = Vector3(1.45 - 0.08 * tap, 0.0, 0.0)
					p["head"] = Vector3(-0.18 + 0.03 * sin(ct * 0.8), 0.08 * sin(ct * 0.5), 0.0)
				elif name == "eat":
					var up: float = 0.5 + 0.5 * sin(ct * 2.6)
					p["shoulder_r"] = Vector3(0.6 + 0.5 * up, 0.0, -0.2)
					p["elbow_r"] = Vector3(1.6 + 1.0 * up, 0.0, 0.0)
					p["head"] = Vector3(-0.25 * up, 0.0, 0.0)
				elif name == "phone":
					p["shoulder_l"] = Vector3(0.95, 0.0, 0.18)
					p["shoulder_r"] = Vector3(0.95, 0.0, -0.18)
					p["elbow_l"] = Vector3(1.25, -0.35, 0.0)
					p["elbow_r"] = Vector3(1.25, 0.35, 0.0)
					p["head"] = Vector3(-0.55, 0.0, 0.0)
					p["torso"] = Vector3(-0.22, 0.0, 0.0)
				elif name == "sleepy_sit":
					var nod: float = 0.5 + 0.5 * sin(ct * 0.8)
					var jerk: float = maxf(0.0, sin(ct * 0.8 + 1.3)) ** 24.0
					p["head"] = Vector3(-0.3 - 0.4 * nod + 0.5 * jerk, 0.1 * sin(ct * 0.3), 0.08 * sin(ct * 0.5))
					p["torso"] = Vector3(-0.1 - 0.15 * nod, 0.0, 0.04 * sin(ct * 0.4))
			"sleepy":
				var nod: float = 0.5 + 0.5 * sin(ct * 0.8)
				var jerk: float = maxf(0.0, sin(ct * 0.8 + 1.3)) ** 24.0
				p["head"] = Vector3(-0.3 - 0.4 * nod + 0.5 * jerk, 0.0, 0.08 * sin(ct * 0.5))
				p["torso"] = Vector3(-0.1 - 0.12 * nod, 0.0, 0.0)
			"stride":   # bước đi đứng hình cho người nộm đám đông xa (CrowdImpostors): tư thế đi ở pha sải chân rộng nhất
				var keep: float = _phase
				_phase = PI * 0.5
				p = _loco_pose(1.0)
				_phase = keep
				p.erase("breathe")
			"phone_stand":   # đứng xem điện thoại (người đi đường dừng chân): tay, đầu, thân như "phone"; chân để nguyên
				p["shoulder_l"] = Vector3(0.95, 0.0, 0.18)
				p["shoulder_r"] = Vector3(0.95, 0.0, -0.18)
				p["elbow_l"] = Vector3(1.25, -0.35, 0.0)
				p["elbow_r"] = Vector3(1.25, 0.35, 0.0)
				p["head"] = Vector3(-0.55, 0.0, 0.0)
				p["torso"] = Vector3(-0.12, 0.0, 0.0)
			"cheer", "cheer_once":
				var b: float = absf(sin(ct * 6.0))
				p["shoulder_l"] = Vector3(2.75 - 0.25 * b, 0.0, 0.35)
				p["shoulder_r"] = Vector3(2.75 - 0.25 * b, 0.0, -0.35)
				p["elbow_l"] = Vector3(0.35, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.35, 0.0, 0.0)
				p["head"] = Vector3(0.25, 0.0, 0.0)
				p["torso"] = Vector3(0.08, 0.0, 0.0)
				p["hips_y"] = 0.07 * b
				p["knee_l"] = Vector3(-0.25 * (1.0 - b), 0.0, 0.0)
				p["knee_r"] = Vector3(-0.25 * (1.0 - b), 0.0, 0.0)
			"flinch":
				var k: float = clampf(1.0 - (ct - 0.5) / 0.4, 0.0, 1.0) if ct > 0.5 else 1.0
				p["torso"] = Vector3(0.28 * k, 0.0, 0.0)
				p["shoulder_l"] = Vector3(1.9 * k, 0.0, 0.3)
				p["shoulder_r"] = Vector3(1.9 * k, 0.0, -0.3)
				p["elbow_l"] = Vector3(2.3 * k, 0.0, 0.0)
				p["elbow_r"] = Vector3(2.3 * k, 0.0, 0.0)
				p["head"] = Vector3(0.2 * k, 0.0, 0.0)
				p["knee_l"] = Vector3(-0.3 * k, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.3 * k, 0.0, 0.0)
			"facepalm":
				var k: float = clampf(ct / 0.25, 0.0, 1.0) * clampf((1.6 - ct) / 0.3, 0.0, 1.0)
				p["shoulder_r"] = Vector3(1.95 * k, 0.0, -0.4 * k)
				p["elbow_r"] = Vector3(2.45 * k, 0.0, 0.0)
				p["head"] = Vector3(-0.4 * k, 0.0, 0.1 * k)
				p["torso"] = Vector3(-0.1 * k, 0.0, 0.0)
			"wave":
				p["shoulder_r"] = Vector3(2.9, 0.0, -0.35)
				p["elbow_r"] = Vector3(0.6 + 0.45 * sin(ct * 9.0), 0.3 * sin(ct * 9.0), 0.0)
				p["head"] = Vector3(0.05, 0.1, 0.0)
			"bow":
				var k: float = sin(clampf(ct / 1.4, 0.0, 1.0) * PI)
				p["torso"] = Vector3(-0.65 * k, 0.0, 0.0)
				p["head"] = Vector3(-0.15 * k, 0.0, 0.0)
				p["shoulder_l"] = Vector3(-0.25 * k, 0.0, 0.12)
				p["shoulder_r"] = Vector3(-0.25 * k, 0.0, -0.12)
			"nod":
				var k: float = sin(clampf(ct / 0.8, 0.0, 1.0) * TAU)
				p["head"] = Vector3(-0.3 * maxf(0.0, k), 0.0, 0.0)
			"stance", "punch", "kick":
				p["thigh_l"] = Vector3(0.25, 0.0, 0.32)
				p["thigh_r"] = Vector3(-0.2, 0.0, -0.32)
				p["knee_l"] = Vector3(-0.45, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.4, 0.0, 0.0)
				p["hips_y"] = -0.07
				p["torso"] = Vector3(-0.12, 0.25, 0.0)
				p["shoulder_l"] = Vector3(1.15, 0.0, 0.35)
				p["shoulder_r"] = Vector3(1.25, 0.0, -0.3)
				p["elbow_l"] = Vector3(2.1, 0.0, 0.0)
				p["elbow_r"] = Vector3(2.2, 0.0, 0.0)
				p["head"] = Vector3(0.0, -0.2, 0.0)
				if name == "punch":
					var k: float = maxf(0.0, sin(ct * 7.0))
					p["shoulder_r"] = Vector3(1.25 + 0.35 * k, 0.0, -0.3 + 0.25 * k)
					p["elbow_r"] = Vector3(2.2 - 2.05 * k, 0.0, 0.0)
					p["torso"] = Vector3(-0.15, 0.25 - 0.45 * k, 0.0)
				elif name == "kick":
					var k: float = maxf(0.0, sin(ct * 4.5))
					p["thigh_r"] = Vector3(-0.2 + 1.9 * k, 0.0, -0.32 + 0.15 * k)
					p["knee_r"] = Vector3(-0.4 - 1.0 * maxf(0.0, sin(ct * 4.5 - 0.6)) * (1.0 - k) , 0.0, 0.0)
					p["torso"] = Vector3(0.12 * k, 0.25, 0.0)
					p["hips_y"] = -0.07 + 0.04 * k
			"ride":
				var sh: float = float(params.get("ride_shoulder", 1.0))
				var el: float = float(params.get("ride_elbow", 0.45))
				var lean_f: float = float(params.get("ride_lean", 0.32))
				# chân gác lên sàn xe (sàn ~0.29 m trên gốc xe): đùi gần ngang, cẳng chân chúc xuống trước
				p["thigh_l"] = Vector3(1.42, 0.0, 0.3)
				p["thigh_r"] = Vector3(1.42, 0.0, -0.3)
				p["knee_l"] = Vector3(-1.12, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.12, 0.0, 0.0)
				p["foot_l"] = Vector3(0.45, 0.0, 0.0)
				p["foot_r"] = Vector3(0.45, 0.0, 0.0)
				p["hips_y"] = -(HIP_Y - 0.62)
				p["torso"] = Vector3(-lean_f, 0.0, 0.0)
				p["shoulder_l"] = Vector3(sh, 0.0, 0.22)
				p["shoulder_r"] = Vector3(sh, 0.0, -0.22)
				p["elbow_l"] = Vector3(el, 0.0, 0.0)
				p["elbow_r"] = Vector3(el, 0.0, 0.0)
				p["head"] = Vector3(lean_f * 0.9, 0.0, 0.0)
				p["hips"] = Vector3(0.0, 0.0, float(params.get("lean", 0.0)))
			"guard":
				p["shoulder_l"] = Vector3(-0.45, 0.0, 0.25)
				p["shoulder_r"] = Vector3(-0.45, 0.0, -0.25)
				p["elbow_l"] = Vector3(1.25, 0.9, 0.0)
				p["elbow_r"] = Vector3(1.25, -0.9, 0.0)
				p["thigh_l"] = Vector3(0.0, 0.0, 0.12)
				p["thigh_r"] = Vector3(0.0, 0.0, -0.12)
				p["torso"] = Vector3(0.05, 0.0, 0.0)
			"lie", "knockdown":
				p["thigh_l"] = Vector3(0.05, 0.0, 0.1)
				p["thigh_r"] = Vector3(0.05, 0.0, -0.1)
				p["knee_l"] = Vector3(-0.1, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.1, 0.0, 0.0)
				p["shoulder_l"] = Vector3(0.1, 0.0, 0.45)
				p["shoulder_r"] = Vector3(0.1, 0.0, -0.45)
				p["elbow_l"] = Vector3(0.3, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.3, 0.0, 0.0)
				p["head"] = Vector3(0.0, 0.3, 0.0)
			"carry":
				# bưng khay / ôm sách trước ngực
				p["shoulder_l"] = Vector3(0.75, 0.0, 0.18)
				p["shoulder_r"] = Vector3(0.75, 0.0, -0.18)
				p["elbow_l"] = Vector3(1.55, -0.25, 0.0)
				p["elbow_r"] = Vector3(1.55, 0.25, 0.0)
			"chop":
				# chém cạnh tay trái từ trên xuống (Vovinam)
				var k: float = clampf(ct / 0.22, 0.0, 1.0)
				p["thigh_l"] = Vector3(0.25, 0.0, 0.32)
				p["thigh_r"] = Vector3(-0.2, 0.0, -0.32)
				p["knee_l"] = Vector3(-0.45, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.4, 0.0, 0.0)
				p["hips_y"] = -0.07
				p["shoulder_l"] = Vector3(2.6 - 1.5 * k, 0.0, 0.35)
				p["elbow_l"] = Vector3(0.9 - 0.6 * k, 0.0, 0.0)
				p["shoulder_r"] = Vector3(1.2, 0.0, -0.3)
				p["elbow_r"] = Vector3(2.2, 0.0, 0.0)
				p["torso"] = Vector3(-0.25 * k, 0.3 - 0.5 * k, 0.0)
			"plank":
				# chống đẩy: hai tay thẳng chống xuống, thân thẳng (gốc được màn chơi xoay nằm sấp)
				p["shoulder_l"] = Vector3(1.55, 0.0, 0.15)
				p["shoulder_r"] = Vector3(1.55, 0.0, -0.15)
				p["elbow_l"] = Vector3(0.1, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.1, 0.0, 0.0)
				p["thigh_l"] = Vector3(0.0, 0.0, 0.08)
				p["thigh_r"] = Vector3(0.0, 0.0, -0.08)
				p["knee_l"] = Vector3.ZERO
				p["knee_r"] = Vector3.ZERO
				p["foot_l"] = Vector3(-0.5, 0.0, 0.0)
				p["foot_r"] = Vector3(-0.5, 0.0, 0.0)
				p["head"] = Vector3(0.5, 0.0, 0.0)
			"slump":
				# gục xuống bàn phím (ngồi)
				p["thigh_l"] = Vector3(1.5, 0.0, 0.1)
				p["thigh_r"] = Vector3(1.5, 0.0, -0.1)
				p["knee_l"] = Vector3(-1.48, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.48, 0.0, 0.0)
				p["hips_y"] = -(HIP_Y - float(params.get("sit_height", 0.47)))
				p["torso"] = Vector3(-0.95, 0.0, 0.08)
				p["head"] = Vector3(-0.5, 0.3, 0.2)
				p["shoulder_l"] = Vector3(1.3, 0.0, 0.3)
				p["shoulder_r"] = Vector3(1.1, 0.0, -0.3)
				p["elbow_l"] = Vector3(1.4, 0.0, 0.0)
				p["elbow_r"] = Vector3(1.0, 0.0, 0.0)
			"jump", "jump_air":
				# co gối giữa không trung, tay vung ra sau
				p["thigh_l"] = Vector3(1.3, 0.0, 0.15)
				p["thigh_r"] = Vector3(0.95, 0.0, -0.15)
				p["knee_l"] = Vector3(-1.7, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.3, 0.0, 0.0)
				p["shoulder_l"] = Vector3(-0.7, 0.0, 0.5)
				p["shoulder_r"] = Vector3(-0.7, 0.0, -0.5)
				p["elbow_l"] = Vector3(0.9, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.9, 0.0, 0.0)
				p["torso"] = Vector3(-0.18, 0.0, 0.0)
				p["head"] = Vector3(0.15, 0.0, 0.0)
			"slide":
				# trượt chân trước, ngả người ra sau
				p["thigh_l"] = Vector3(1.35, 0.0, 0.12)
				p["thigh_r"] = Vector3(1.1, 0.0, -0.2)
				p["knee_l"] = Vector3(-0.15, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.9, 0.0, 0.0)
				p["shoulder_l"] = Vector3(-0.9, 0.0, 0.4)
				p["shoulder_r"] = Vector3(-0.6, 0.0, -0.4)
				p["elbow_l"] = Vector3(0.4, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.6, 0.0, 0.0)
				p["torso"] = Vector3(0.35, 0.0, 0.0)
				p["head"] = Vector3(-0.45, 0.0, 0.0)
				p["hips_y"] = -0.12
			"jump_takeoff":
				p["thigh_l"] = Vector3(0.55, 0.0, 0.08)
				p["thigh_r"] = Vector3(0.55, 0.0, -0.08)
				p["knee_l"] = Vector3(-1.05, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.05, 0.0, 0.0)
				p["foot_l"] = Vector3(0.45, 0.0, 0.0)
				p["foot_r"] = Vector3(0.45, 0.0, 0.0)
				p["hips_y"] = -0.14
				p["torso"] = Vector3(-0.32, 0.0, 0.0)
				p["shoulder_l"] = Vector3(-0.65, 0.0, 0.18)
				p["shoulder_r"] = Vector3(-0.65, 0.0, -0.18)
				p["elbow_l"] = Vector3(0.35, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.35, 0.0, 0.0)
			"fall_flail":
				var f: float = sin(ct * 11.0)
				var g: float = sin(ct * 9.0 + 1.3)
				p["shoulder_l"] = Vector3(2.3 + 0.45 * f, 0.0, 0.55)
				p["shoulder_r"] = Vector3(2.3 - 0.45 * f, 0.0, -0.55)
				p["elbow_l"] = Vector3(0.5 + 0.3 * g, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.5 - 0.3 * g, 0.0, 0.0)
				p["thigh_l"] = Vector3(0.55 + 0.45 * g, 0.0, 0.12)
				p["thigh_r"] = Vector3(0.55 - 0.45 * g, 0.0, -0.12)
				p["knee_l"] = Vector3(-0.9 - 0.3 * f, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.9 + 0.3 * f, 0.0, 0.0)
				p["torso"] = Vector3(0.12, 0.0, 0.0)
				p["head"] = Vector3(0.25, 0.0, 0.0)
			"land_soft":
				var k: float = sin(clampf(ct / 0.18, 0.0, 1.0) * PI)
				p["thigh_l"] = Vector3(0.75 * k, 0.0, 0.1)
				p["thigh_r"] = Vector3(0.75 * k, 0.0, -0.1)
				p["knee_l"] = Vector3(-1.25 * k, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.25 * k, 0.0, 0.0)
				p["foot_l"] = Vector3(0.5 * k, 0.0, 0.0)
				p["foot_r"] = Vector3(0.5 * k, 0.0, 0.0)
				p["hips_y"] = -0.2 * k
				p["torso"] = Vector3(-0.3 * k, 0.0, 0.0)
				p["shoulder_l"] = Vector3(0.45 * k, 0.0, 0.3)
				p["shoulder_r"] = Vector3(0.45 * k, 0.0, -0.3)
			"skid":
				p["thigh_l"] = Vector3(0.7, 0.0, 0.1)
				p["thigh_r"] = Vector3(-0.25, 0.0, -0.1)
				p["knee_l"] = Vector3(-0.15, 0.0, 0.0)
				p["knee_r"] = Vector3(-0.6, 0.0, 0.0)
				p["hips_y"] = -0.1
				p["torso"] = Vector3(0.28, 0.0, 0.0)
				p["shoulder_l"] = Vector3(0.9, 0.0, 0.45)
				p["shoulder_r"] = Vector3(0.7, 0.0, -0.45)
				p["elbow_l"] = Vector3(0.5, 0.0, 0.0)
				p["elbow_r"] = Vector3(0.6, 0.0, 0.0)
				p["head"] = Vector3(-0.15, 0.0, 0.0)
			"stumble":
				var k2: float = sin(clampf(ct / 0.8, 0.0, 1.0) * PI)
				p["torso"] = Vector3(0.35 * k2, 0.25 * k2, 0.15 * k2)
				p["shoulder_l"] = Vector3(1.2 * k2, 0.0, 0.8 * k2)
				p["shoulder_r"] = Vector3(0.6 * k2, 0.0, -0.9 * k2)
				p["thigh_r"] = Vector3(-0.35 * k2, 0.0, -0.1)
				p["knee_r"] = Vector3(-0.3 * k2, 0.0, 0.0)
				p["head"] = Vector3(0.2 * k2, 0.0, 0.0)
			"getup":
				var k3: float = 1.0 - clampf(ct / 0.9, 0.0, 1.0)
				p["torso"] = Vector3(-0.9 * k3, 0.0, 0.0)
				p["thigh_l"] = Vector3(1.2 * k3, 0.0, 0.1)
				p["thigh_r"] = Vector3(1.2 * k3, 0.0, -0.1)
				p["knee_l"] = Vector3(-1.6 * k3, 0.0, 0.0)
				p["knee_r"] = Vector3(-1.6 * k3, 0.0, 0.0)
				p["hips_y"] = -0.5 * k3
		return p

	func _apply(loco: Dictionary, cpose: Dictionary, w: float, dt: float) -> void:
		var keys: Array = ["hips", "torso", "head", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "thigh_l", "thigh_r", "knee_l", "knee_r", "foot_l", "foot_r"]
		for k: String in keys:
			var n: Node3D = rig.get(k, null)
			if n == null:
				continue
			var lv: Vector3 = loco.get(k, Vector3.ZERO)
			var cv: Vector3 = cpose.get(k, lv)
			var rot: Vector3 = lv.lerp(cv, w)
			if k == "head":
				rot += _look(n, dt) * (1.0 - 0.6 * w)
			n.rotation = rot
		var hips: Node3D = rig.get("hips", null)
		if hips:
			var hy: float = lerpf(float(loco.get("hips_y", 0.0)), float(cpose.get("hips_y", float(loco.get("hips_y", 0.0)))), w)
			hips.position.y = hip_base + hy
		var torso_mesh: MeshInstance3D = rig.get("torso_mesh", null)
		if torso_mesh:
			var b: float = float(loco.get("breathe", 0.0))
			torso_mesh.scale = Vector3(1.0, 1.0 + 0.008 * b, 1.0 + 0.02 * b)

	func _look(head: Node3D, dt: float) -> Vector3:
		var ty: float = 0.0
		var tp: float = 0.0
		if look_target != null and look_target is Vector3:
			var parent: Node3D = head.get_parent() as Node3D
			if parent:
				var local: Vector3 = parent.to_local(look_target) - head.position
				var horiz: float = Vector2(local.x, local.z).length()
				ty = clampf(atan2(-local.x, -local.z), -1.2, 1.2)
				tp = clampf(atan2(local.y - 0.12, maxf(horiz, 0.001)), -0.5, 0.55)
				if absf(ty) > 1.19:
					ty = 0.0
					tp = 0.0
		_look_yaw = lerp_angle(_look_yaw, ty, minf(1.0, dt * 5.0))
		_look_pitch = lerpf(_look_pitch, tp, minf(1.0, dt * 5.0))
		return Vector3(_look_pitch, _look_yaw, 0.0)


# ===========================================================================
# RIG ANIMATOR – điều khiển thân Quaternius: AnimationPlayer cho đi/chạy/vẫy/đấm…, xoay xương trực tiếp cho các
# clip tự dựng (ngồi, gõ máy, ăn, điện thoại, facepalm…) lấy từ bảng clip của Animator. Cùng giao diện với Animator.
# ===========================================================================
class RigAnimator extends Node:
	var rig: Dictionary = {}
	var skeleton: Skeleton3D
	var player: AnimationPlayer
	var head_pivot: Node3D
	var speed: float = 0.0
	var look_target: Variant = null
	var params: Dictionary = {"lean": 0.0, "run": 0.0}
	var clip: String = ""
	var base_clip: String = ""
	var clip_time: float = 0.0
	var clip_duration: float = -1.0
	var clip_weight: float = 0.0
	var blink_enabled: bool = true
	var face_mat: StandardMaterial3D
	var face_open: Texture2D
	var face_closed: Texture2D
	var face_cells: bool = false         # đầu PS2: chớp mắt / biểu cảm bằng ô atlas (uv1_offset) thay vì đổi texture
	var face_cell_open: Vector3 = Vector3.ZERO
	var face_cell_closed: Vector3 = Vector3.ZERO
	var rng_phase: float = 0.0
	var _t: float = 0.0
	var _phase: float = 0.0
	var _blink_t: float = 2.0
	var _blink_closed: float = 0.0
	var _look_yaw: float = 0.0
	var _look_pitch: float = 0.0
	var _src: Animator                  # nguồn tư thế clip (không nằm trong cây; tạo khi cần, xem _clip_source)
	var _bone: Dictionary = {}          # khớp của ta → chỉ số xương
	var _rest_local: Dictionary = {}    # xương → Basis rest cục bộ
	var _body_bone: int = -1
	var _body_rest_pos: Vector3
	var _cur_anim: String = ""
	var _pack_clip_playing: String = ""
	var _lod_t: float = 0.0
	var _lod_skip: int = 1
	var _frame: int = 0
	const OVERLAY_EASE: float = 10.0    # 1/s: trọng số lớp cộng thêm tiến về đích (clip gói bắt đầu: mờ trong 0.1 s)
	var _overlay_w: float = 1.0         # trọng số hiện tại của lớp cộng thêm (nước rút, lăn hông)
	var _hips_keyed: Dictionary = {}    # tên animation → có track xoay Hips (cache, xem _hips_roll)
	const FIDGETS: Array[String] = ["look", "shift", "neutral"]
	var fidget_count: int = 0           # số động tác vặt khi đứng yên đã bắt đầu (cho test)
	var _fidget: String = ""
	var _fidget_t: float = 8.0
	var _fidget_time: float = 0.0
	var _fidget_yaw: float = 0.0
	var _fidget_sway: float = 0.0

	func _ready() -> void:
		process_priority = 10   # chạy SAU AnimationPlayer để ghi đè tư thế xương
		_t = rng_phase
		_blink_t = randf_range(1.5, 4.5)
		_fidget_t = randf_range(6.0, 12.0)   # đám đông không fidget cùng lúc
		for k: String in BONE_OF.keys():
			var b: int = skeleton.find_bone(BONE_OF[k])
			if b >= 0:
				_bone[k] = b
				_rest_local[b] = skeleton.get_bone_rest(b).basis
		_body_bone = skeleton.find_bone("Body")
		if _body_bone >= 0:
			_body_rest_pos = skeleton.get_bone_rest(_body_bone).origin
		# animation lặp cho các chu kỳ
		for a: String in ["Idle", "Idle_Neutral", "Walk", "Run", "Run_Left", "Run_Right", "Run_Back"]:
			if player.has_animation(a):
				player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		player.playback_default_blend_time = 0.18
		_play_anim("Idle")
		set_process(true)

	func _exit_tree() -> void:
		if _src:
			_src.free()
			_src = null

	## Nguồn tư thế clip tự dựng, tạo ở lần dùng đầu: _ready chỉ chạy một lần nên nhân vật rời cây (_exit_tree giải phóng
	## nguồn) rồi vào lại vẫn có nguồn mới; nhân vật không bao giờ chạy clip tự dựng thì không tạo.
	func _clip_source() -> Animator:
		if _src == null:
			_src = Animator.new()
			_src.rig = {}
		return _src

	func play(name: String, duration: float = -1.0) -> void:
		clip = name
		clip_time = 0.0
		clip_duration = duration if duration > 0.0 else float(Animator.ONE_SHOT.get(name, -1.0))
		_fidget_stop()   # Idle_Neutral của fidget không được giữ lại sau clip
		if name == "getup" and player.has_animation("Death"):
			_pack_clip_playing = "Death"
			player.play("Death", 0.05, -GETUP_SPEED, true)
			player.speed_scale = 1.0
			_cur_anim = "Death"
			if duration <= 0.0:
				clip_duration = player.get_animation("Death").length / GETUP_SPEED
			return
		if PACK_CLIP.has(name) and player.has_animation(PACK_CLIP[name]):
			var a: String = PACK_CLIP[name]
			_pack_clip_playing = a
			player.play(a, 0.12)
			player.speed_scale = 1.0
			_cur_anim = a
			if clip_duration < 0.0 and not (name in HOLD_CLIPS):
				clip_duration = player.get_animation(a).length
		else:
			_pack_clip_playing = ""

	func stop_clip() -> void:
		clip = base_clip
		clip_time = 0.0
		clip_duration = -1.0
		_pack_clip_playing = ""

	func set_base(name: String) -> void:
		base_clip = name
		if clip == "" or clip_duration < 0.0:
			play(name)
			clip_duration = -1.0

	func _play_anim(a: String) -> void:
		if a == _cur_anim or not player.has_animation(a):
			return
		_cur_anim = a
		player.play(a, 0.18)

	func _process(delta: float) -> void:
		_frame += 1
		_t += delta
		_lod_t -= delta
		if _lod_t <= 0.0:
			_lod_t = 0.5
			_lod_skip = 1
			var vp: Viewport = get_viewport()
			var cam: Camera3D = vp.get_camera_3d() if vp else null
			var root: Node3D = get_parent() as Node3D
			if cam and root:
				var d: float = cam.global_position.distance_to(root.global_position)
				_lod_skip = 1 if d < 35.0 else (3 if d < 80.0 else (8 if d < 140.0 else 0))
		if _lod_skip == 0 or (_lod_skip > 1 and _frame % _lod_skip != 0):
			return
		var dt: float = delta * float(maxi(_lod_skip, 1))
		if clip != "":
			clip_time += dt
			clip_weight = minf(1.0, clip_weight + dt * float(FAST_BLEND.get(clip, 5.0)))
			if clip_duration > 0.0 and clip_time >= clip_duration:
				stop_clip()
				if base_clip != "":
					play(base_clip)
					clip_duration = -1.0
		else:
			clip_weight = maxf(0.0, clip_weight - dt * 4.0)
		# --- đi/chạy từ gói; khi clip gói đang chạy thì giữ nó, khi clip tự dựng thì đứng Idle làm nền
		var amp: float = clampf(speed / 1.4, 0.0, 1.6)
		_phase += dt * TAU * speed / 1.5
		var sprint: float = clampf(float(params.get("sprint", 0.0)), 0.0, 1.0)
		if _pack_clip_playing != "":
			if clip == "lie" and not player.is_playing():
				pass   # giữ khung cuối (Death)
		elif amp < 0.08:
			_fidget_update(dt)
			if _fidget != "neutral":
				_play_anim("Idle")
				player.speed_scale = 1.0
		elif amp < 1.05 and float(params.get("run", 0.0)) < 0.3:
			_fidget_stop()
			_play_anim("Walk")
			player.speed_scale = clampf(speed / 1.25, 0.6, 1.6)
		else:
			_fidget_stop()
			_play_anim("Run")
			player.speed_scale = clampf(speed / 3.2, 0.7, 1.5) * (1.0 + 0.35 * sprint)
		# --- lớp cộng thêm (nước rút, nghiêng hông) theo phần tư thế còn do đi/đứng quyết định; clip gói hoặc clip tự
		# dựng đã hoà đủ thì 0 (hông về rest, xem _hips_roll). Trọng số tiến dần về đích (OVERLAY_EASE): clip gói bắt đầu
		# thì thân không bật thẳng dậy trong một khung
		var free_w: float = (1.0 - clip_weight) if _pack_clip_playing == "" else 0.0
		_overlay_w = move_toward(_overlay_w, free_w, OVERLAY_EASE * dt)
		_overlay(sprint * _overlay_w, (float(params.get("lean", 0.0)) + _fidget_sway) * _overlay_w)
		# --- clip tự dựng: xoay xương theo bảng clip của Animator
		if clip != "" and _pack_clip_playing == "" and clip_weight > 0.001:
			var src: Animator = _clip_source()
			src._t = _t
			src._phase = _phase
			src.params = params
			var cpose: Dictionary = src._clip_pose(clip, clip_time)
			_apply_bones(cpose, clip_weight)
		_look(dt)
		_blink(dt)

	## Áp tư thế {khớp: Euler trong hệ nhân vật} lên xương, trộn với tư thế animation theo w (phép tính ở _apply_bone_pose)
	func _apply_bones(cpose: Dictionary, w: float) -> void:
		CharacterBuilder._apply_bone_pose(skeleton, cpose, w)

	## Lớp cộng thêm sau AnimationPlayer: nước rút (vung tay rộng hơn quanh tư thế nghỉ, thân đổ trước 12°), lăn hông.
	func _overlay(sprint: float, roll: float) -> void:
		if sprint > 0.01:
			for k: String in ["shoulder_l", "shoulder_r", "elbow_l", "elbow_r"]:
				if not _bone.has(k):
					continue
				var b: int = _bone[k]
				var rest_q: Quaternion = (_rest_local[b] as Basis).get_rotation_quaternion()
				var d: Quaternion = rest_q.inverse() * skeleton.get_bone_pose_rotation(b)
				if d.w < 0.0:
					d = -d   # cùng phép xoay, góc ngắn (< PI) để nhân góc không vòng ngược
				var ang: float = d.get_angle()
				if ang > 0.0001:
					skeleton.set_bone_pose_rotation(b, rest_q * Quaternion(d.get_axis().normalized(), ang * (1.0 + 0.6 * sprint)))
			_add_rot("torso", Vector3(-0.21 * sprint, 0.0, 0.0))
		_hips_roll(roll)

	## Xoay cộng thêm (Euler hệ nhân vật) lên tư thế hiện tại của xương khớp k. Chỉ dùng cho xương animation gói có track
	## xoay (ghi lại mỗi khung) nên không cộng dồn; Hips thường không có track, xem _hips_roll.
	func _add_rot(k: String, e: Vector3) -> void:
		if not _bone.has(k):
			return
		var b: int = _bone[k]
		var r: Basis = CharacterBuilder._char_rot_local(skeleton, b, e)
		skeleton.set_bone_pose_rotation(b, (r * Basis(skeleton.get_bone_pose_rotation(b))).get_rotation_quaternion())

	## Lăn hông (Euler z hệ nhân vật, dương = nghiêng trái), đặt TUYỆT ĐỐI so với rest mỗi khung qua _apply_bone_pose: trong
	## tệp glTF chỉ Run_Left / Run_Right có kênh xoay Hips, mà kênh đó là hằng số bằng rest nên bộ nhập (remove_immutable_tracks)
	## bỏ đi; lúc chạy Hips không có track nào ghi lại mỗi khung, cộng dồn từng khung sẽ trôi mãi. Animation đang phát mà CÓ track
	## xoay Hips (đổi thiết lập nhập, gói khác) thì bỏ qua, không đè track đó. Hips chỉ mang thân trên (chân là con của Body), nên
	## chân và giày đứng yên. Clip tự dựng có khoá "hips" (ride) áp sau, đè lên.
	func _hips_roll(roll: float) -> void:
		if _anim_keys_hips(player.current_animation):
			return
		CharacterBuilder._apply_bone_pose(skeleton, {"hips": Vector3(0.0, 0.0, roll)}, 1.0)

	## Animation a của AnimationPlayer có track xoay xương Hips không (tra một lần mỗi tên, cache).
	func _anim_keys_hips(a: String) -> bool:
		if a == "":
			return false
		if not _hips_keyed.has(a):
			var path := NodePath(String(player.get_node(player.root_node).get_path_to(skeleton)) + ":Hips")
			_hips_keyed[a] = player.has_animation(a) and player.get_animation(a).find_track(path, Animation.TYPE_ROTATION_3D) >= 0
		return _hips_keyed[a]

	## Động tác vặt khi đứng yên, mỗi 6..12 s: nhìn quanh (đầu ±50°), đổi chân (lăn hông), Idle_Neutral. Đang nhìn một điểm
	## (look_target: NPC sân khấu quay về người chơi khi thoại) thì không nhìn quanh.
	func _fidget_update(dt: float) -> void:
		if clip != "":
			_fidget_stop()
			return
		if _fidget == "":
			_fidget_t -= dt
			if _fidget_t <= 0.0:
				_fidget_t = randf_range(6.0, 12.0)
				_fidget = FIDGETS[randi() % FIDGETS.size()]
				if _fidget == "neutral" and not player.has_animation("Idle_Neutral"):
					_fidget = "look"
				if _fidget == "look" and look_target != null:
					_fidget = "shift"
				_fidget_time = 0.0
				fidget_count += 1
				if _fidget == "neutral":
					_cur_anim = "Idle_Neutral"
					player.play("Idle_Neutral", 0.25)
					player.speed_scale = 1.0   # có thể bắt đầu ngay khung đầu đứng lại, khi speed_scale còn của Walk / Run
			return
		_fidget_time += dt
		match _fidget:
			"look":
				_fidget_yaw = sin(_fidget_time / 3.0 * TAU) * 0.92   # ≈ ±50° sau bộ lọc của _look (lệch 0.92 lần ở chu kỳ 3 s)
				if _fidget_time >= 3.0 or look_target != null:
					_fidget_stop()
			"shift":
				_fidget_sway = 0.06 * sin(_fidget_time / 2.5 * PI)
				if _fidget_time >= 2.5:
					_fidget_stop()
			"neutral":
				if _fidget_time >= player.get_animation("Idle_Neutral").length:
					_fidget_stop()

	func _fidget_stop() -> void:
		_fidget = ""
		_fidget_yaw = 0.0
		_fidget_sway = 0.0

	func _look(dt: float) -> void:
		var ty: float = 0.0
		var tp: float = 0.0
		if look_target != null and look_target is Vector3 and head_pivot:
			var parent: Node3D = head_pivot.get_parent() as Node3D
			if parent:
				var local: Vector3 = parent.to_local(look_target)
				local = Vector3(-local.x, local.y, -local.z)   # pivot đầu quay PI
				var horiz: float = Vector2(local.x, local.z).length()
				ty = clampf(atan2(-local.x, -local.z), -1.2, 1.2)
				tp = clampf(atan2(local.y - 0.12, maxf(horiz, 0.001)), -0.5, 0.55)
				if absf(ty) > 1.19:
					ty = 0.0
					tp = 0.0
		# fidget nhìn quanh đi qua cùng bộ lọc: dừng giữa chừng (bắt đầu đi) thì đầu quay về êm, không giật
		_look_yaw = lerp_angle(_look_yaw, clampf(ty + _fidget_yaw, -1.2, 1.2), minf(1.0, dt * 5.0))
		_look_pitch = lerpf(_look_pitch, tp, minf(1.0, dt * 5.0))
		if head_pivot:
			head_pivot.rotation = Vector3(_look_pitch, PI + _look_yaw, 0.0)

	func _blink(dt: float) -> void:
		if not blink_enabled or face_mat == null:
			return
		if _blink_closed > 0.0:
			_blink_closed -= dt
			if _blink_closed <= 0.0:
				CharacterBuilder._show_face(self, false)
			return
		_blink_t -= dt
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.0, 5.5)
			_blink_closed = 0.13
			CharacterBuilder._show_face(self, true)
