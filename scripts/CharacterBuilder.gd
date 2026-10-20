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

# ===========================================================================
# API TĨNH
# ===========================================================================
static func build(opts: Dictionary = {}) -> Node3D:
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
	var head := _pivot(neck, "Head", Vector3(0.0, 0.065, 0.0))
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

	root.set_meta("rig", rig)
	root.set_meta("preset", preset)
	root.set_meta("female", female)
	root.set_meta("height", height)
	# --- Animator
	if bool(opts.get("animate", true)):
		var an := Animator.new()
		an.name = "Animator"
		an.rig = rig
		an.blink_enabled = bool(opts.get("blink", true))
		if an.blink_enabled:
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
		root.add_child(an)
		var clip: String = String(opts.get("clip", ""))
		if clip != "":
			an.play(clip)
	return root

## Node Animator của nhân vật (null nếu dựng với animate=false)
static func get_animator(root: Node3D) -> Animator:
	return root.get_node_or_null("Animator") as Animator

## Đặt tư thế tĩnh ngay lập tức (không cần Animator / không cần ở trong cây) – dùng trước bake() cho đám đông,
## người ngồi xe NPC, người đứng xa. params: ví dụ {"ride_shoulder": 1.1, "ride_elbow": 0.3, "lean": 0.1}
static func pose(root: Node3D, clip: String, t: float = 0.0, params: Dictionary = {}) -> void:
	var an := Animator.new()
	an.rig = root.get_meta("rig", {})
	for k: String in params.keys():
		an.params[k] = params[k]
	var cpose: Dictionary = an._clip_pose(clip, t) if clip != "" else {}
	an._apply({}, cpose, 1.0 if clip != "" else 0.0, 0.0)
	an.free()

## Người ngồi xe máy đã bake thành 1 MeshInstance3D (≈16 surface thay vì ~50 node) – cho xe NPC / menu / bãi xe.
## Gốc đặt tại yên xe: pos = (0, cao_yên − 0.62, z_yên). Hướng -Z như xe.
static func build_baked_rider(parent: Node3D, pos: Vector3, opts: Dictionary = {}) -> MeshInstance3D:
	var o: Dictionary = opts.duplicate()
	if not o.has("preset"):
		o["preset"] = "rider"
	o["animate"] = false
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
	var an: Animator = get_animator(root)
	if an:
		an.play(clip, duration)

static func stop_clip(root: Node3D) -> void:
	var an: Animator = get_animator(root)
	if an:
		an.stop_clip()

## Clip nền: sau mỗi clip one-shot (punch 0.4 s, flinch…) nhân vật quay về clip này thay vì đứng thẳng
static func set_base_clip(root: Node3D, clip: String) -> void:
	var an: Animator = get_animator(root)
	if an:
		an.set_base(clip)

static func set_speed(root: Node3D, speed_ms: float) -> void:
	var an: Animator = get_animator(root)
	if an:
		an.speed = speed_ms

static func set_param(root: Node3D, key: String, value: float) -> void:
	var an: Animator = get_animator(root)
	if an:
		an.params[key] = value

static func look_at_point(root: Node3D, global_point: Variant) -> void:
	var an: Animator = get_animator(root)
	if an:
		an.look_target = global_point

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
				mi.material_override = m
		var an: Animator = get_animator(root)
		if an and an.face_mat:
			var fm: StandardMaterial3D = get_pivot(root, "face_mesh").material_override
			an.face_mat = fm
		root.set_meta("own_mats", true)
	for mi: MeshInstance3D in _mesh_instances(root):
		var m: Material = mi.material_override
		if m is StandardMaterial3D:
			m.albedo_color.a = alpha
	root.visible = alpha > 0.01

## Gộp toàn bộ mesh của nhân vật (ở tư thế hiện tại) thành 1 ArrayMesh nhiều surface – dùng cho MultiMesh đám đông.
static func bake(root: Node3D) -> ArrayMesh:
	var by_mat: Dictionary = {}
	var inv: Transform3D = root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	for mi: MeshInstance3D in _mesh_instances(root):
		if mi.mesh == null:
			continue
		var xf: Transform3D = (inv * mi.global_transform) if root.is_inside_tree() else _local_xform(mi, root)
		for si: int in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si)
			if not by_mat.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_mat[mat] = st
			(by_mat[mat] as SurfaceTool).append_from(mi.mesh, si, xf)
	var out := ArrayMesh.new()
	for mat: Material in by_mat.keys():
		var st: SurfaceTool = by_mat[mat]
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out

static func _local_xform(n: Node3D, root: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p and p != root and p is Node3D:
		xf = (p as Node3D).transform * xf
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
	_hemisphere(head, hc + Vector3(0.0, 0.02, 0.0), HEAD_R * 1.2, hm, Vector3(-0.05, 0.0, 0.0), Vector3(0.98 * width, 1.05, 1.02))
	_cyl(head, hc + Vector3(0.0, 0.01, 0.0), HEAD_R * 1.2, HEAD_R * 1.2, 0.03, hm, Vector3.ZERO, Vector3(0.98 * width, 1.0, 1.02))
	_box(head, hc + Vector3(0.0, 0.015, -(HEAD_R * 1.18)), Vector3(0.21, 0.012, 0.08), _mat("helmet_visor", Color("#111318"), 0.2, 0.3))
	for sx: float in [-1.0, 1.0]:
		_box(head, hc + Vector3(sx * 0.09 * width, -0.05, -0.02), Vector3(0.01, 0.12, 0.006), _mat("helmet_strap", Color("#222222"), 0.8), Vector3(0.0, 0.0, sx * 0.25))

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
	var n: Texture2D = _tex("char_cloth_n.png")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.5
		m.uv1_scale = Vector3(4.0, 4.0, 4.0)
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 2.0
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
	_mat_cache[k] = m
	return m

# ===========================================================================
# ANIMATOR – animation thủ tục
# ===========================================================================
class Animator extends Node:
	var rig: Dictionary = {}
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
	const ONE_SHOT: Dictionary = {"flinch": 0.9, "facepalm": 1.6, "bow": 1.4, "cheer_once": 1.6, "nod": 0.8}

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
			clip_weight = minf(1.0, clip_weight + dt * 5.0)
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
				face_mat.albedo_texture = face_open
			return
		_blink_t -= dt
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.0, 5.5)
			_blink_closed = 0.13
			face_mat.albedo_texture = face_closed

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
			"lie":
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
			"jump":
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
			hips.position.y = HIP_Y + hy
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
