# File: res://tests/preview_props.gd
# Chụp "studio" đồ vật PropBuilder (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_props.gd
# Ảnh vào user://preview/props_*.png: xe tay ga (3 góc), xe buýt, nộm gỗ, cây + cột đèn, bàn ghế dù + khay cơm.
extends SceneTree

var cam: Camera3D
var frames: int = 0
var out_dir: String
var world: Node3D
var step: int = 0

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
	env.ssr_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 40.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.72, 0.72, 0.7)
	fm.roughness = 0.9
	floor_mi.material_override = fm
	world.add_child(floor_mi)

	var m: Dictionary = FPTUCampusBuilder.make_materials()
	# xe tay ga (có pivot) + xe baked + người lái
	var s1: Dictionary = PropBuilder.build_scooter(world, Vector3(0.0, 0.0, 0.0), 0.0, Color("#2C3E50"), {"name": "ScooterA"})
	var rider: Node3D = CharacterBuilder.build({"preset": "rider", "seed": 2805, "helmet_color": Color("#0066CC"), "clip": "ride"})
	rider.position = Vector3(0.0, 0.32, 0.14)
	(s1["root"] as Node3D).add_child(rider)
	CharacterBuilder.set_param(rider, "ride_shoulder", 1.2)
	CharacterBuilder.set_param(rider, "ride_elbow", 0.28)
	CharacterBuilder.set_param(rider, "ride_lean", 0.4)
	PropBuilder.build_scooter(world, Vector3(1.6, 0.0, 0.3), 0.3, Color("#C0392B"), {"baked": true})
	var s3: Dictionary = PropBuilder.build_scooter(world, Vector3(-1.6, 0.0, 0.2), -0.25, Color("#F1C40F"), {"baked": true})
	CharacterBuilder.build_baked_rider(s3["root"], Vector3(0.0, 0.32, 0.12), {"seed": 4, "shirt_color": Color("#3498DB")})
	# xe buýt
	var bus_root := Node3D.new()
	bus_root.position = Vector3(8.0, 0.0, -6.0)
	bus_root.rotation.y = 0.5
	world.add_child(bus_root)
	PropBuilder.build_bus(bus_root, true, true)
	var bus2 := Node3D.new()
	bus2.position = Vector3(-9.0, 0.0, -7.0)
	bus2.rotation.y = -0.4
	world.add_child(bus2)
	PropBuilder.build_bus(bus2, false, true)
	# nộm gỗ
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.9, 0.78, 0.62)
	dm.albedo_texture = CharacterBuilder._tex("prop_wood.png")
	dm.uv1_triplanar = true
	dm.roughness = 0.75
	var dummy_root := Node3D.new()
	dummy_root.position = Vector3(4.0, 0.0, 3.0)
	world.add_child(dummy_root)
	PropBuilder.build_training_dummy(dummy_root, dm)
	# cây + cột đèn
	PropBuilder.build_tree(world, Vector3(-6.0, 0.0, 4.0), m, 1.2, 7)
	PropBuilder.build_tree(world, Vector3(-10.0, 0.0, 1.0), m, 1.0, 11)
	PropBuilder.build_lamp_post(world, Vector3(-3.5, 0.0, 5.0), 7.0, true, 0.4)
	# bàn ghế dù + khay
	PropBuilder.build_table(world, Vector3(6.0, 0.0, 8.0))
	for off: Vector3 in [Vector3(-0.9, 0.0, 1.25), Vector3(0.9, 0.0, 1.25), Vector3(-0.9, 0.0, -1.25), Vector3(0.9, 0.0, -1.25)]:
		PropBuilder.build_stool(world, Vector3(6.0, 0.0, 8.0) + off)
	PropBuilder.build_umbrella(world, Vector3(6.0, 0.0, 8.0))
	var tray_a: Node3D = PropBuilder.build_tray(world, "com")
	tray_a.position = Vector3(5.4, 0.77, 8.0)
	var tray_b: Node3D = PropBuilder.build_tray(world, "bun")
	tray_b.position = Vector3(6.7, 0.77, 7.8)
	tray_b.rotation.y = 0.4

	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	_shot(Vector3(2.2, 1.3, 3.2), Vector3(0.0, 0.7, 0.0), 45.0)
	print("PREVIEW OUT DIR: ", out_dir)

func _shot(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.look_at_from_position(pos, look, Vector3.UP)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])

func _process(_d: float) -> bool:
	frames += 1
	match frames:
		50:
			_save("props_01_scooter_rider")
			_shot(Vector3(-2.6, 1.1, -2.4), Vector3(0.0, 0.6, 0.0), 45.0)
		65:
			_save("props_02_scooter_front")
			_shot(Vector3(0.0, 1.6, 4.5), Vector3(0.0, 0.6, 0.0), 50.0)
		80:
			_save("props_03_scooters_three")
			_shot(Vector3(2.0, 2.4, 4.0), Vector3(8.0, 1.4, -6.0), 50.0)
		95:
			_save("props_04_bus")
			_shot(Vector3(2.0, 1.4, 5.5), Vector3(4.0, 1.1, 3.0), 40.0)
		110:
			_save("props_05_dummy")
			_shot(Vector3(0.0, 3.0, 12.0), Vector3(-6.5, 4.0, 3.0), 55.0)
		125:
			_save("props_06_trees_lamp")
			_shot(Vector3(8.5, 1.9, 11.5), Vector3(6.0, 0.8, 8.0), 45.0)
		140:
			_save("props_07_table_tray")
			_shot(Vector3(5.6, 1.25, 8.9), Vector3(5.4, 0.78, 8.0), 35.0)
		155:
			_save("props_08_tray_closeup")
			print("PREVIEW PROPS DONE")
			quit(0)
			return true
	return false
