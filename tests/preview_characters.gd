# File: res://tests/preview_characters.gd
# Chụp "studio" nhân vật CharacterBuilder (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_characters.gd
# Ảnh vào user://preview/char_*.png:
#   char_01_lineup      – 12 preset đứng idle nhìn về camera
#   char_02_faces       – cận mặt 4 người đầu (mắt, mày, môi, tóc, kính)
#   char_03_clips_a/b   – mỗi người một clip (walk, run, sit, type, cheer, wave, stance, punch, ride, phone, sleepy, carry) ở 2 thời điểm
#   char_04_back        – nhìn từ sau (ba lô, tóc, đuôi tóc)
#   char_05_crowd       – 60 bản sao bake() trong MultiMesh (đám đông)
extends SceneTree

const PRESETS: Array[String] = ["student_m", "student_f", "player", "rider", "lecturer", "guard", "vovinam", "master", "cook", "proctor", "casual", "cop"]
const CLIPS: Array = [["walk", 1.3], ["run", 2.8], ["sit", 0.0], ["type", 0.0], ["cheer", 0.0], ["wave", 0.0], ["stance", 0.0], ["punch", 0.0], ["ride", 0.0], ["phone", 0.0], ["sleepy", 0.0], ["carry", 1.0]]
const SPACING: float = 0.95

var cam: Camera3D
var chars: Array[Node3D] = []
var frames: int = 0
var out_dir: String
var world: Node3D

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = Node3D.new()
	root.add_child(world)
	# studio: nền sáng, trời thủ tục, nắng xiên
	var env := Environment.new()
	var sky := Sky.new()
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = Color(0.45, 0.6, 0.85)
	skm.sky_horizon_color = Color(0.82, 0.86, 0.9)
	skm.ground_bottom_color = Color(0.3, 0.3, 0.32)
	skm.ground_horizon_color = Color(0.7, 0.7, 0.7)
	sky.sky_material = skm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60.0
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -120.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.9, 1.0)
	world.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 60.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.78, 0.78, 0.76)
	fm.roughness = 0.9
	floor_mi.material_override = fm
	world.add_child(floor_mi)

	for i: int in range(PRESETS.size()):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i], "seed": 100 + i * 7, "name": "C_" + PRESETS[i]})
		c.position = Vector3((float(i) - float(PRESETS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		c.rotation.y = PI # quay mặt về +Z (phía camera)
		world.add_child(c)
		chars.append(c)
		var label := Label3D.new()
		label.text = PRESETS[i]
		label.font_size = 28
		label.pixel_size = 0.004
		label.position = Vector3(0.0, 1.95, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.1, 0.1, 0.1)
		label.outline_modulate = Color(1, 1, 1, 0.8)
		c.add_child(label)
	cam = Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.current = true
	_shot(Vector3(0.0, 1.45, 8.6), Vector3(0.0, 0.95, 0.0))
	print("PREVIEW OUT DIR: ", out_dir)

func _shot(pos: Vector3, look: Vector3, fov: float = 50.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(pos, look, Vector3.UP)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])

func _process(_d: float) -> bool:
	frames += 1
	match frames:
		45:
			for c: Node3D in chars:
				CharacterBuilder.look_at_point(c, cam.global_position)
		60:
			_save("char_01_lineup")
			_shot(Vector3(-4.1, 1.62, 1.35), Vector3(-4.4, 1.5, 0.0), 32.0)
		80:
			_save("char_02_faces")
			for i: int in range(chars.size()):
				var cl: Array = CLIPS[i]
				CharacterBuilder.look_at_point(chars[i], null)
				CharacterBuilder.play(chars[i], cl[0])
				CharacterBuilder.set_speed(chars[i], float(cl[1]))
				var lbl: Label3D = chars[i].get_child(chars[i].get_child_count() - 1) as Label3D
				if lbl:
					lbl.text = "%s · %s" % [PRESETS[i], cl[0]]
			_shot(Vector3(0.0, 1.5, 8.6), Vector3(0.0, 0.85, 0.0), 50.0)
		125:
			_save("char_03_clips_a")
		150:
			_save("char_03_clips_b")
			for i: int in range(chars.size()):
				CharacterBuilder.stop_clip(chars[i])
				CharacterBuilder.set_speed(chars[i], 0.0)
			_shot(Vector3(0.0, 1.5, -8.2), Vector3(0.0, 0.95, 0.0), 50.0)
		185:
			_save("char_04_back")
			# đám đông bake: 1 nhân vật walk → ArrayMesh → MultiMesh 60 bản sao
			var proto: Node3D = CharacterBuilder.build({"preset": "student", "seed": 3, "animate": false})
			world.add_child(proto)
			proto.position = Vector3(0.0, 0.0, -30.0)
			var mesh: ArrayMesh = CharacterBuilder.bake(proto)
			proto.queue_free()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = 60
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i: int in range(60):
				var t := Transform3D.IDENTITY
				t = t.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6) + PI)
				t.origin = Vector3(float(i % 12 - 6) * 0.8 + rng.randf_range(-0.2, 0.2), 0.0, -3.0 - float(i / 12) * 0.9)
				mm.set_instance_transform(i, t)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			world.add_child(mmi)
			print("  baked mesh: %d surfaces, %d verts" % [mesh.get_surface_count(), _vcount(mesh)])
			_shot(Vector3(0.0, 2.6, 7.5), Vector3(0.0, 0.9, -3.0), 55.0)
		215:
			_save("char_05_crowd")
			print("PREVIEW CHARACTERS DONE")
			quit(0)
			return true
	return false

func _vcount(mesh: ArrayMesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n
