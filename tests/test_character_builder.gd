# File: res://tests/test_character_builder.gd
# Test headless CharacterBuilder: dựng mọi preset, đủ khớp, animator chạy các clip 120 frame không lỗi,
# bake() ra ArrayMesh nhiều surface, set_opacity hoạt động, texture mặt tồn tại.
# Chạy:  godot --headless --path . --script tests/test_character_builder.gd
extends SceneTree

const PRESETS: Array[String] = ["student", "student_m", "student_f", "player", "rider", "lecturer", "guard", "vovinam", "master", "cook", "proctor", "casual", "cop"]
const CLIPS: Array[String] = ["", "walk", "sit", "type", "eat", "phone", "cheer", "flinch", "facepalm", "sleepy", "wave", "bow", "stance", "punch", "kick", "ride", "guard", "lie", "carry", "sleepy_sit", "nod"]
const REQUIRED_PIVOTS: Array[String] = ["hips", "torso", "head", "head_top", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "knee_l", "knee_r", "foot_l", "foot_r", "face_mesh", "torso_mesh"]

var chars: Array[Node3D] = []
var frames: int = 0
var fails: Array[String] = []

func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	for i: int in range(PRESETS.size()):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i], "seed": i * 31 + 1})
		c.position = Vector3(float(i) * 1.0, 0.0, 0.0)
		world.add_child(c)
		chars.append(c)
		for k: String in REQUIRED_PIVOTS:
			if CharacterBuilder.get_pivot(c, k) == null:
				fails.append("%s: thiếu pivot %s" % [PRESETS[i], k])
		if CharacterBuilder.get_animator(c) == null:
			fails.append("%s: thiếu Animator" % PRESETS[i])
		var n_mesh: int = CharacterBuilder._mesh_instances(c).size()
		if n_mesh < 20:
			fails.append("%s: chỉ có %d MeshInstance3D (quá ít chi tiết)" % [PRESETS[i], n_mesh])
	# texture mặt phải có đủ 16 file
	var missing: int = 0
	for t: String in ["a", "b", "c", "d"]:
		for s: String in ["m", "f"]:
			for st: String in ["open", "closed"]:
				if not FileAccess.file_exists("res://assets/textures/char_face_%s%s_%s.png" % [t, s, st]):
					missing += 1
	if missing > 0:
		fails.append("thiếu %d texture mặt (chạy generate_character_textures.py)" % missing)
	# bake
	var baked: ArrayMesh = CharacterBuilder.bake(chars[0])
	var verts: int = 0
	for s: int in range(baked.get_surface_count()):
		verts += (baked.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	print("  bake: %d surfaces, %d verts, %d mesh instances/char" % [baked.get_surface_count(), verts, CharacterBuilder._mesh_instances(chars[0]).size()])
	if baked.get_surface_count() < 3 or verts < 2000:
		fails.append("bake() quá ít dữ liệu")
	print("--- TEST CHARACTER BUILDER: %d preset, %d clip ---" % [PRESETS.size(), CLIPS.size()])

func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		# chiều cao đỉnh đầu ~1.6–1.9 m (global transform chỉ hợp lệ sau khi cây cảnh chạy frame đầu)
		var top: Node3D = CharacterBuilder.head_top(chars[1])
		print("  head_top student_m y=%.2f" % top.global_position.y)
		if top.global_position.y < 1.55 or top.global_position.y > 1.95:
			fails.append("head_top sai độ cao %.2f" % top.global_position.y)
	if frames % 10 == 1:
		var ci: int = (frames / 10) % CLIPS.size()
		for i: int in range(chars.size()):
			if i == 0 and frames >= 90:
				continue # chars[0] giữ clip "sit" để đo hông
			var clip: String = CLIPS[(ci + i) % CLIPS.size()]
			if clip == "":
				CharacterBuilder.stop_clip(chars[i])
			else:
				CharacterBuilder.play(chars[i], clip)
			CharacterBuilder.set_speed(chars[i], float(i % 3) * 1.2)
			CharacterBuilder.look_at_point(chars[i], Vector3(0.0, 1.5, 5.0) if i % 2 == 0 else null)
	if frames == 60:
		CharacterBuilder.set_opacity(chars[2], 0.3)
		var fm: Material = CharacterBuilder.get_pivot(chars[2], "face_mesh").material_override
		if not (fm is StandardMaterial3D) or not is_equal_approx((fm as StandardMaterial3D).albedo_color.a, 0.3):
			fails.append("set_opacity không áp vào mặt")
		CharacterBuilder.set_opacity(chars[2], 1.0)
	if frames == 90:
		CharacterBuilder.play(chars[0], "sit")
	if frames >= 120:
		# sau khi ngồi 30 frame, hông phải hạ xuống ~0.47 m
		var hips: Node3D = CharacterBuilder.get_pivot(chars[0], "hips")
		print("  hips y khi ngồi=%.2f (clip %s)" % [hips.position.y, CharacterBuilder.get_animator(chars[0]).clip])
		if hips.position.y > 0.6:
			fails.append("clip sit không hạ hông (y=%.2f)" % hips.position.y)
		if fails.is_empty():
			print("✅ SUCCESS: CHARACTER BUILDER – ALL PRESETS, PIVOTS, CLIPS, BAKE AND OPACITY OK")
			quit(0)
		else:
			for f: String in fails:
				print("  ✗ ", f)
			print("❌ FAILED: %d issues" % fails.size())
			quit(1)
		return true
	return false
