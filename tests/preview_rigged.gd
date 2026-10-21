# File: res://tests/preview_rigged.gd
# Chụp "studio" nhân vật LAI (thân Quaternius + đầu tự dựng) – cần cửa sổ render:
#   godot --path . --script tests/preview_rigged.gd
# Ảnh vào user://preview/rig_*.png:
#   rig_01_lineup      – 9 preset đứng idle (so với char_01_lineup của thân tự dựng)
#   rig_02_faces       – cận mặt + biểu cảm
#   rig_03_clips_a/b   – walk, run, wave, punch (gói) + phone, facepalm, sit, type, cheer (xoay xương)
#   rig_04_back        – nhìn từ sau (ba lô)
#   rig_05_vs          – lai đứng cạnh thân tự dựng cùng preset
extends SceneTree

const PRESETS: Array = [
	["student_m", {"body": "casual"}], ["student_f", {"body": "casual"}], ["player", {"body": "hoodie"}],
	["lecturer", {"body": "suit", "female": false}], ["guard", {"body": "worker"}], ["proctor", {"body": "formal", "female": true}],
	["cook", {"body": "worker", "female": true}], ["vovinam", {"body": "casual", "female": false}], ["casual", {"body": "hoodie", "female": true}]]
const CLIPS: Array = [["walk", 1.3], ["run", 2.8], ["wave", 0.0], ["punch", 0.0], ["phone", 0.0], ["facepalm", 0.0], ["sit", 0.0], ["type", 0.0], ["cheer", 0.0]]
const SPACING: float = 0.95

var cam: Camera3D
var chars: Array[Node3D] = []
var frames: int = 0
var out_dir: String
var world: Node3D
var procedural: Node3D

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = Node3D.new()
	root.add_child(world)
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
		var o: Dictionary = (PRESETS[i][1] as Dictionary).duplicate()
		o["preset"] = PRESETS[i][0]
		o["seed"] = 100 + i * 7
		o["name"] = "R_" + String(PRESETS[i][0])
		o["rigged"] = true
		var c: Node3D = CharacterBuilder.build(o)
		if not c.get_meta("rigged", false):
			print("  !! %s không dựng được thân rigged" % PRESETS[i][0])
		c.position = Vector3((float(i) - float(PRESETS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		c.rotation.y = PI # quay mặt về +Z (phía camera)
		world.add_child(c)
		chars.append(c)
		var label := Label3D.new()
		label.text = String(PRESETS[i][0])
		label.font_size = 28
		label.pixel_size = 0.004
		label.position = Vector3(0.0, 2.0, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.1, 0.1, 0.1)
		label.outline_modulate = Color(1, 1, 1, 0.8)
		c.add_child(label)
	# thân tự dựng cùng preset để so sánh (shot 05)
	procedural = CharacterBuilder.build({"preset": "student_m", "seed": 100, "name": "P_student_m", "rigged": false})
	procedural.position = Vector3(-0.7, 0.0, 3.0)
	procedural.rotation.y = PI
	procedural.visible = false
	world.add_child(procedural)
	cam = Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.current = true
	_shot(Vector3(0.0, 1.45, 7.2), Vector3(0.0, 0.95, 0.0))
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
		70:
			_save("rig_01_lineup")
			var exprs: Array[String] = ["happy", "angry", "surprised", "done", "open"]
			for i: int in range(mini(5, chars.size())):
				CharacterBuilder.set_expression(chars[i], exprs[i])
			_shot(Vector3(-2.8, 1.62, 1.9), Vector3(-2.8, 1.45, 0.0), 40.0)
		85:
			_save("rig_02_faces")
			for i: int in range(mini(5, chars.size())):
				CharacterBuilder.set_expression(chars[i], "open")
			for i: int in range(chars.size()):
				CharacterBuilder.look_at_point(chars[i], null)
				var cl: Array = CLIPS[i % CLIPS.size()]
				CharacterBuilder.set_speed(chars[i], float(cl[1]))
				if cl[1] == 0.0:
					CharacterBuilder.play(chars[i], String(cl[0]), 30.0)
				var lab: Label3D = chars[i].get_node("Label3D") if chars[i].has_node("Label3D") else null
				if lab:
					lab.text = "%s · %s" % [String(PRESETS[i][0]), String(cl[0])]
			_shot(Vector3(0.0, 1.5, 7.2), Vector3(0.0, 0.85, 0.0), 50.0)
		110:
			_save("rig_03_clips_a")
		140:
			_save("rig_03_clips_b")
			for i: int in range(chars.size()):
				CharacterBuilder.stop_clip(chars[i])
				CharacterBuilder.set_speed(chars[i], 0.0)
			_shot(Vector3(0.0, 1.5, -7.0), Vector3(0.0, 0.95, 0.0), 50.0)
		165:
			_save("rig_04_back")
			for c: Node3D in chars:
				c.visible = false
			chars[0].visible = true
			chars[0].position = Vector3(0.7, 0.0, 3.0)
			procedural.visible = true
			CharacterBuilder.look_at_point(chars[0], null)
			_shot(Vector3(0.0, 1.3, 6.2), Vector3(0.0, 0.9, 3.0), 42.0)
		190:
			_save("rig_05_vs")
			print("PREVIEW RIGGED DONE")
			quit(0)
	return false
