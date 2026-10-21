# File: res://tests/preview_map.gd
# Chụp ảnh kiểm tra MapBuilder (thế giới mở trên bản đồ thật, plan Task 3). Cần cửa sổ render, KHÔNG --headless:
#   godot --path . --script tests/preview_map.gd
# Dựng cả 3 vùng (vinhomes, corridor, campus) từ assets/data/mapdata.json rồi lưu PNG vào user://preview/:
#   map_01_beverly_air  – 150 m trên BE6 nhìn xuống 60 độ (cụm The Beverly)
#   map_02_be6_street   – tại điểm spawn, tầm mắt 1,6 m, nhìn theo hướng spawn
#   map_03_vincom       – Vincom Mega Mall (VinMall Grand Park) từ phía đường
#   map_04_campus_air   – trên lô đất campus (chỉ vùng campus của MapBuilder, chưa có FPTUCampusBuilder)
#   map_05_corridor     – trên đường Nguyễn Văn Tăng nhìn về phía campus
extends SceneTree

var cam: Camera3D
var frames: int = 0
var shot_idx: int = -1
var shots: Array = []
var out_dir: String = ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var md: MapData = MapData.load_default()
	assert(md != null, "mapdata.json must load")
	var world := Node3D.new()
	root.add_child(world)
	_studio(world)
	for region: String in ["vinhomes", "corridor", "campus"]:
		var t0: int = Time.get_ticks_msec()
		MapBuilder.build_region(world, md, region, {})
		print("  built %s in %d ms" % [region, Time.get_ticks_msec() - t0])

	var be6: Array = md.landmark("be6_center")
	var be6c := Vector3(float(be6[0]), 0.0, float(be6[1]))
	var sp: Transform3D = md.spawn_transform()
	var fwd: Vector3 = -sp.basis.z
	var eye: Vector3 = sp.origin + Vector3(0.0, 1.6, 0.0)
	var vincom := Vector3(3582.0, 0.0, -216.0)
	# a point on Nguyễn Văn Tăng (secondary, OSM way 32583376) and the direction of travel towards the campus
	var nvt_a := Vector3(1023.0, 0.0, -277.0)
	var nvt_dir := Vector3(-0.678, 0.0, -0.735)
	for r: Dictionary in md.roads("corridor"):
		if int(r["id"]) == 32583376:
			var pts: PackedVector2Array = MapData.poly(r["points"])
			var i: int = int(pts.size() * 0.62)
			nvt_a = MapData.to_world(pts[i])
			nvt_dir = MapData.to_world(pts[i + 1]) - nvt_a
			nvt_dir.y = 0.0
			nvt_dir = nvt_dir.normalized()
	shots = [
		{"name": "map_01_beverly_air", "pos": be6c + Vector3(-61.0, 150.0, 61.0), "look": be6c + Vector3(0.0, 30.0, 0.0), "fov": 60.0},
		{"name": "map_02_be6_street", "pos": eye, "look": eye + fwd * 30.0, "fov": 70.0},
		{"name": "map_03_vincom", "pos": vincom + Vector3(125.0, 9.0, 75.0), "look": vincom + Vector3(0.0, 7.0, 0.0), "fov": 60.0},
		{"name": "map_04_campus_air", "pos": Vector3(0.0, 330.0, 190.0), "look": Vector3(0.0, 0.0, 0.0), "fov": 60.0},
		{"name": "map_05_corridor", "pos": nvt_a - nvt_dir * 60.0 + Vector3(0.0, 32.0, 0.0), "look": nvt_a + nvt_dir * 160.0, "fov": 65.0},
	]
	cam = Camera3D.new()
	cam.name = "PreviewCam"
	cam.far = 6000.0
	root.add_child(cam)
	cam.current = true
	print("PREVIEW OUT DIR: ", out_dir)


func _studio(world: Node3D) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = Color(0.40, 0.58, 0.88)
	skm.sky_horizon_color = Color(0.84, 0.88, 0.94)
	skm.ground_bottom_color = Color(0.3, 0.3, 0.32)
	skm.ground_horizon_color = Color(0.72, 0.72, 0.72)
	sky.sky_material = skm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.86, 0.95)
	env.fog_density = 0.00025
	env.fog_aerial_perspective = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 500.0
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -120.0, 0.0)
	fill.light_energy = 0.3
	fill.light_color = Color(0.85, 0.9, 1.0)
	world.add_child(fill)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 20:
		return false
	var local_f: int = (frames - 20) % 20
	if local_f == 0:
		shot_idx += 1
		if shot_idx >= shots.size():
			print("PREVIEW MAP DONE")
			quit(0)
			return true
		var s: Dictionary = shots[shot_idx]
		cam.fov = s["fov"]
		cam.look_at_from_position(s["pos"], s["look"], Vector3.UP)
	elif local_f == 18:
		var img: Image = root.get_texture().get_image()
		var path: String = out_dir.path_join(str(shots[shot_idx]["name"]) + ".png")
		var err: int = img.save_png(path)
		print("  saved %s err=%d size=%s fps=%.0f" % [path, err, img.get_size(), Engine.get_frames_per_second()])
	return false
