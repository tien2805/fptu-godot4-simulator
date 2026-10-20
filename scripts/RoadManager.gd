# File: res://scripts/RoadManager.gd
class_name RoadManager
extends Node3D

const FPTUCampusBuilder = preload("res://scripts/FPTUCampusBuilder.gd")

signal zone_changed(zone_name: String)
signal destination_reached()

@export var player_bike: CharacterBody3D

@onready var road_path: Path3D = $RoadTrack/RoadPath
@onready var asphalt_csg: CSGPolygon3D = $RoadTrack/AsphaltCSG
@onready var center_line_csg: CSGPolygon3D = $RoadTrack/CenterYellowLineCSG
@onready var scenery_root: Node3D = $SceneryRoot

var total_track_length: float = 1.0
var current_zone: String = ""
var has_finished: bool = false
var finish_offset: float = 1.0e9
var road_events: Node3D

# Preloaded Textures
var tex_asphalt: Texture2D
var tex_sidewalk: Texture2D
var tex_curb: Texture2D
var tex_milano: Texture2D
var tex_suaxe: Texture2D
var tex_bunbo: Texture2D
var tex_taphoa: Texture2D
var tex_bachhoa: Texture2D
var tex_awning_red: Texture2D
var tex_awning_blue: Texture2D
var tex_roundabout: Texture2D
var tex_fptu_gate: Texture2D
var tex_7eleven: Texture2D
var tex_bridge: Texture2D
var tex_ringroad3: Texture2D
var tex_wire_pole: Texture2D
var tex_hutech: Texture2D
var tex_vinhomes_facade: Texture2D
var tex_vinhomes_gate: Texture2D
var tex_fptu_alpha: Texture2D
var tex_hutech_bldg: Texture2D
var tex_shtp: Texture2D

func _ready() -> void:
	_load_textures()
	_build_real_world_curve()
	_configure_road_csg()
	_build_landmarks_and_fptu_campus()
	_spawn_road_events()
	GameFX.upgrade_scene_visuals(get_parent(), "outdoor")

func _spawn_road_events() -> void:
	# Sự kiện bất ngờ trên đường (ổ gà, xe tải hỏng, chó, đèn đỏ, mưa, checkpoint hài)
	if not player_bike:
		return
	var ev_script: Script = load("res://scripts/RoadEvents.gd")
	if ev_script == null:
		return
	road_events = ev_script.new()
	road_events.name = "RoadEvents"
	add_child(road_events)
	road_events.call("setup", road_path, player_bike)

func _load_textures() -> void:
	tex_asphalt = _load_tex("res://assets/textures/asphalt_road.png")
	tex_sidewalk = _load_tex("res://assets/textures/sidewalk_tiles.png")
	tex_curb = _load_tex("res://assets/textures/curb_stone.png")
	tex_milano = _load_tex("res://assets/textures/shop_milano.png")
	tex_suaxe = _load_tex("res://assets/textures/shop_suaxe.png")
	tex_bunbo = _load_tex("res://assets/textures/shop_bunbo.png")
	tex_taphoa = _load_tex("res://assets/textures/shop_taphoa.png")
	tex_bachhoa = _load_tex("res://assets/textures/shop_bachhoaxanh.png")
	tex_awning_red = _load_tex("res://assets/textures/awning_red.png")
	tex_awning_blue = _load_tex("res://assets/textures/awning_blue.png")
	tex_roundabout = _load_tex("res://assets/textures/roundabout_sign.png")
	tex_fptu_gate = _load_tex("res://assets/textures/fptu_gate_sign.png")
	tex_7eleven = _load_tex("res://assets/textures/seven_eleven_sign.png")
	tex_bridge = _load_tex("res://assets/textures/bridge_barrier.png")
	tex_ringroad3 = _load_tex("res://assets/textures/ringroad3_pillar.png")
	tex_wire_pole = _load_tex("res://assets/textures/wire_pole.png")
	tex_hutech = _load_tex("res://assets/textures/hutech_sign.png")
	tex_vinhomes_facade = _load_tex("res://assets/textures/vinhomes_facade.png")
	tex_vinhomes_gate = _load_tex("res://assets/textures/vinhomes_gate.png")
	tex_fptu_alpha = _load_tex("res://assets/textures/fptu_alpha_facade.png")
	tex_hutech_bldg = _load_tex("res://assets/textures/hutech_building.png")
	tex_shtp = _load_tex("res://assets/textures/fptu_shtp_monument.png")

func _load_tex(res_path: String) -> Texture2D:
	var img: Image = GameFX.load_image_any(res_path)
	if img:
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)
	return null

func _build_real_world_curve() -> void:
	var curve := Curve3D.new()
	curve.up_vector_enabled = true

	# TÁI TẠO CHÍNH XÁC CUNG ĐƯỜNG NGOÀI ĐỜI TỪ GOOGLE MAPS:
	# Vinhomes Grand Park -> Nguyễn Xiển (ngoằn ngoèo) -> Cầu Trau Trảu & Vành Đai 3
	# -> Đại lộ D2 SHTP -> VÒNG XOAY BÙNG BINH D1/D2 -> RẼ PHẢI VÀO ĐƯỜNG D1 -> CỔNG ĐH FPT
	var waypoints: Array[Vector3] = [
		Vector3(0, 0, 0),             # 0m: Xuất phát Vinhomes Grand Park (đường nội khu)
		Vector3(0, 0, -140),          # 140m: Ra cổng Nguyễn Xiển
		Vector3(-45, 0, -280),        # 280m: Khúc cua gắt vào đường Nguyễn Xiển
		Vector3(-25, 0, -410),        # 410m: Uốn lượn qua các tiệm sửa xe, Milano Coffee
		Vector3(50, 0, -560),         # 560m: Khúc cua zigzag Nguyễn Xiển qua quán bún bò
		Vector3(-20, 0, -720),        # 720m: Tiếp cận ngã ba Cầu Trau Trảu
		Vector3(5, 4.8, -870),        # 870m: Đỉnh dốc Cầu Trau Trảu vượt rạch (nhìn thấy Vành Đai 3)
		Vector3(15, 0, -1020),        # 1020m: Xuống dốc cầu, tiến vào Đại lộ D2 SHTP
		Vector3(15, 0, -1280),        # 1280m: Đại lộ D2 thẳng tắp 6 làn xe rợp bóng cây
		Vector3(15, 0, -1510),        # 1510m: Tiếp cận Vòng xoay Bùng binh D1 - D2
		# VÒNG XOAY BÙNG BINH D1 - D2 (Tâm đảo bùng binh tại (48, 0, -1560), bán kính đảo 16m):
		# Tuyến đường uốn lượn VÒNG QUANH bùng binh (cách tâm 28m - 35m) KHÔNG ĐÂM XUYÊN QUA ĐẢO:
		Vector3(15, 0, -1535),        # 1535m: Cửa ngõ bùng binh D1 - D2
		Vector3(18, 0, -1555),        # 1555m: Ôm vòng cung phía Tây đảo tròn (cách tâm 30.4m > 16m đảo)
		Vector3(24, 0, -1575),        # 1575m: Ôm cua Tây-Nam bùng binh (cách tâm 28.3m > 16m đảo)
		Vector3(34, 0, -1588),        # 1588m: Ôm cua phía Nam bùng binh (cách tâm 31.3m > 16m đảo)
		Vector3(50, 0, -1595),        # 1595m: Đáy phía Nam bùng binh, chuẩn bị thoát bùng binh (cách tâm 35m)
		Vector3(75, 0, -1595),        # 1620m: RẼ PHẢI THOÁT KHỎI BÙNG BINH VÀO ĐƯỜNG D1 (HƯỚNG ĐÔNG +X)!
		# ĐƯỜNG D1 (Chạy hướng Đông +X tại Z = -1595):
		Vector3(140, 0, -1595),       # Đường D1 rợp bóng cây công nghệ cao
		Vector3(210, 0, -1595),       # Đường D1 - Hướng đến cụm trường Đại học SHTP
		Vector3(260, 0, -1595),       # Phân khu ĐH HUTECH (BÊN TAY TRÁI, -Z)
		Vector3(300, 0, -1595),       # Mặt tiền ĐH FPT (BÊN TAY PHẢI, +Z) đối diện HUTECH (BÊN TRÁI, -Z)
		Vector3(400, 0, -1595),       # Cổng bãi xe D1 FPTU – VẠCH ĐÍCH (x = 389)
		Vector3(470, 0, -1595)        # Đường D1 tiếp tục về hướng N10 / Xa lộ Hà Nội
	]

	for pt: Vector3 in waypoints:
		curve.add_point(pt)

	road_path.curve = curve
	total_track_length = curve.get_baked_length()

func _configure_road_csg() -> void:
	# Mặt đường nhựa 14m trải nhựa asphalt chân thực với gờ chắn bảo vệ 2 bên
	asphalt_csg.mode = CSGPolygon3D.MODE_PATH
	asphalt_csg.path_node = road_path.get_path()
	asphalt_csg.path_interval = 3.5
	asphalt_csg.use_collision = true
	# Thiết kế tiết diện mặt đường có gờ chắn vỉa hè cao 1.1m ở 2 biên (-7.6m và +7.6m) chống văng khỏi map
	asphalt_csg.polygon = PackedVector2Array([
		Vector2(-7.6, 1.1),
		Vector2(-7.0, 1.1),
		Vector2(-7.0, 0.25),
		Vector2(7.0, 0.25),
		Vector2(7.0, 1.1),
		Vector2(7.6, 1.1),
		Vector2(7.6, 0.0),
		Vector2(-7.6, 0.0)
	])
	# Nhựa đường HD (vẽ code) + normal map, triplanar để không bị kéo giãn theo đường cong
	var mat_asphalt: StandardMaterial3D = FPTUCampusBuilder.make_materials()["asphalt"]
	if mat_asphalt.albedo_texture == null and tex_asphalt:
		mat_asphalt.albedo_texture = tex_asphalt
		mat_asphalt.uv1_triplanar = true
		mat_asphalt.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mat_asphalt.roughness = 0.9
	asphalt_csg.material = mat_asphalt

	# Vạch trắng liền 2 mép đường
	for side: float in [-1.0, 1.0]:
		var edge := CSGPolygon3D.new()
		edge.mode = CSGPolygon3D.MODE_PATH
		edge.path_node = road_path.get_path()
		edge.path_interval = 3.5
		edge.polygon = PackedVector2Array([
			Vector2(side * 6.45, 0.26), Vector2(side * 6.45, 0.275), Vector2(side * 6.6, 0.275), Vector2(side * 6.6, 0.26)
		])
		var mat_edge := StandardMaterial3D.new()
		mat_edge.albedo_color = Color(0.95, 0.95, 0.95)
		mat_edge.emission_enabled = true
		mat_edge.emission = Color(0.4, 0.4, 0.4)
		edge.material = mat_edge
		asphalt_csg.get_parent().add_child(edge)

	# Vạch sơn vàng đôi tim đường phát sáng
	center_line_csg.mode = CSGPolygon3D.MODE_PATH
	center_line_csg.path_node = road_path.get_path()
	center_line_csg.path_interval = 3.5
	center_line_csg.polygon = PackedVector2Array([
		Vector2(-0.18, 0.26),
		Vector2(-0.18, 0.28),
		Vector2(0.18, 0.28),
		Vector2(0.18, 0.26)
	])
	var mat_yellow := StandardMaterial3D.new()
	mat_yellow.albedo_color = Color("#FBC531")
	mat_yellow.emission_enabled = true
	mat_yellow.emission = Color("#FBC531") * 0.35
	center_line_csg.material = mat_yellow

func _build_landmarks_and_fptu_campus() -> void:
	# 0. Mặt đất bao bọc bản đồ & Lan can bảo vệ cầu
	_build_world_ground_and_safety_barriers()

	# 1. ĐOẠN 1: VINHOMES GRAND PARK (0m -> 180m)
	_build_vinhomes_zone()

	# 2. ĐOẠN 2: ĐƯỜNG NGUYỄN XIỂN QUANH CO VỚI HÀNG QUÁN THẬT (220m -> 760m)
	_build_nguyen_xien_shophouses_and_powerlines()

	# 3. ĐOẠN 3: CẦU TRAU TRẢU & CÔNG TRƯỜNG VÀNH ĐAI 3 (800m -> 990m)
	_build_cau_trau_trau_and_ringroad3()

	# 4. ĐOẠN 4: ĐẠI LỘ D2 KHU CÔNG NGHỆ CAO SHTP (1040m -> 1500m)
	_build_dai_lo_d2_boulevard()

	# 5. ĐOẠN 5: VÒNG XOAY BÙNG BINH D1 - D2 (1520m -> 1640m)
	_build_roundabout_d1_d2()

	# 6. ĐOẠN 6: ĐƯỜNG D1 - VIỆN CÔNG NGHỆ CAO ĐH HUTECH (BÊN TAY TRÁI, -Z)
	_build_hutech_campus()

	# 7. ĐÍCH ĐẾN: DỰNG TOÀN CẢNH KHUÔN VIÊN ĐH FPT TP.HCM (LÔ E2A-7 ĐƯỜNG D1 SHTP)
	# Khuôn viên FPT theo mặt bằng thật (OSM + vệ tinh): lô 180 m dọc D1 × 115 m sâu, nằm BÊN PHẢI (+Z)
	# đối diện HUTECH, cổng chính ở x≈221, cổng bãi xe D1 ở x≈389. Ranh giới cách tim đường 13 m.
	FPTUCampusBuilder.build_authentic_campus(scenery_root, Vector3(215.0, 0.0, -1582.0), 0.0)
	finish_offset = road_path.curve.get_closest_offset(Vector3(389.0, 0.0, -1595.0))

	# Vạch đích Finish Line ca-rô trắng trước cổng trường (Nằm trên mặt đường D1)
	var finish := MeshInstance3D.new()
	var fin_mesh := BoxMesh.new()
	fin_mesh.size = Vector3(2.0, 0.05, 14.0)
	finish.mesh = fin_mesh
	var mat_fin := StandardMaterial3D.new()
	mat_fin.albedo_color = Color("#FFFFFF")
	mat_fin.emission_enabled = true
	mat_fin.emission = Color("#FFFFFF") * 0.5
	finish.material_override = mat_fin
	scenery_root.add_child(finish)
	finish.position = Vector3(389.0, 0.28, -1595.0)
	var fin_lbl := Label3D.new()
	fin_lbl.text = "🏁 FINISH – CỔNG BÃI XE D1 FPTU"
	fin_lbl.font_size = 48
	fin_lbl.outline_size = 14
	fin_lbl.modulate = Color("#F1C40F")
	fin_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fin_lbl.position = Vector3(389.0, 6.5, -1595.0)
	scenery_root.add_child(fin_lbl)

func _build_world_ground_and_safety_barriers() -> void:
	# 1. Thảm cỏ địa hình bao bọc toàn bản đồ có va chạm vật lý (Không lo rơi vào hư vô)
	var ground_body := StaticBody3D.new()
	ground_body.position = Vector3(100.0, -0.15, -900.0)
	scenery_root.add_child(ground_body)

	var ground_col := CollisionShape3D.new()
	var g_box := BoxShape3D.new()
	g_box.size = Vector3(3000.0, 0.3, 3000.0)
	ground_col.shape = g_box
	ground_body.add_child(ground_col)

	var ground_mesh := MeshInstance3D.new()
	var gm_box := BoxMesh.new()
	gm_box.size = Vector3(3000.0, 0.3, 3000.0)
	ground_mesh.mesh = gm_box
	# Cỏ có texture (triplanar, lặp 12 m) + màu dịu: nền phẳng xanh bão hoà bị ánh sáng trời của SDFGI làm bạc màu ở xa
	var mat_grass: StandardMaterial3D = FPTUCampusBuilder.make_materials()["grass"]
	mat_grass.uv1_triplanar = true
	mat_grass.uv1_scale = Vector3(0.08, 0.08, 0.08)
	mat_grass.albedo_color = Color(0.86, 0.88, 0.8)
	mat_grass.roughness = 1.0
	ground_mesh.material_override = mat_grass
	ground_body.add_child(ground_mesh)

	# 2. Lan can vô hình chống trượt rớt trên Cầu Trau Trảu (d=800m -> 940m)
	for d: float in range(805.0, 935.0, 16.0):
		var b_xform: Transform3D = road_path.curve.sample_baked_with_rotation(d)
		for side: float in [-1.0, 1.0]:
			var wall_body := StaticBody3D.new()
			scenery_root.add_child(wall_body)
			wall_body.global_transform = b_xform
			wall_body.position += b_xform.basis.x * (side * 7.1) + Vector3(0, 1.6, 0)
			var w_col := CollisionShape3D.new()
			var w_box := BoxShape3D.new()
			w_box.size = Vector3(0.5, 3.2, 16.0)
			w_col.shape = w_box
			wall_body.add_child(w_col)

func _build_vinhomes_zone() -> void:
	var mat_tower := StandardMaterial3D.new()
	if tex_vinhomes_facade:
		mat_tower.albedo_texture = tex_vinhomes_facade
		mat_tower.uv1_scale = Vector3(1.0, 2.0, 1.0)
	else:
		mat_tower.albedo_color = Color("#E4E8EE")
	mat_tower.roughness = 0.35

	var mat_glass := StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.2, 0.65, 0.85, 0.7)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.roughness = 0.1

	var mat_palm_trunk := StandardMaterial3D.new()
	mat_palm_trunk.albedo_color = Color("#5D4037")

	var mat_palm_leaf := StandardMaterial3D.new()
	mat_palm_leaf.albedo_color = Color("#2E7D32")

	var mat_lamp_glow := StandardMaterial3D.new()
	mat_lamp_glow.albedo_color = Color("#FFEAA7")
	mat_lamp_glow.emission_enabled = true
	mat_lamp_glow.emission = Color("#FFEAA7") * 1.5

	# 1. Các tòa tháp chung cư cao cấp Vinhomes Grand Park (The Origami & The Rainbow)
	for i: int in range(6):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z_pos: float = -i * 28.0

		var tower := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(22.0, 56.0, 18.0)
		tower.mesh = b_mesh
		tower.material_override = mat_tower
		scenery_root.add_child(tower)
		tower.position = Vector3(side * 26.0, 28.0, z_pos)

		# Vỉa hè đá hoa cương Vinhomes
		var sidewalk := MeshInstance3D.new()
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(5.5, 0.28, 28.0)
		sidewalk.mesh = s_mesh
		var mat_sw := StandardMaterial3D.new()
		mat_sw.albedo_texture = tex_sidewalk
		mat_sw.uv1_scale = Vector3(2.0, 8.0, 1.0)
		sidewalk.material_override = mat_sw
		scenery_root.add_child(sidewalk)
		sidewalk.position = Vector3(side * 9.8, 0.14, z_pos)

		# Hàng Cây Cau Vua / Cọ Nhiệt Đới (Royal Palm Trees) dọc lối đi
		var palm := Node3D.new()
		palm.position = Vector3(side * 7.6, 0.0, z_pos)
		scenery_root.add_child(palm)

		var trunk := MeshInstance3D.new()
		var tr_mesh := CylinderMesh.new()
		tr_mesh.top_radius = 0.22
		tr_mesh.bottom_radius = 0.35
		tr_mesh.height = 7.5
		trunk.mesh = tr_mesh
		trunk.material_override = mat_palm_trunk
		trunk.position = Vector3(0.0, 3.75, 0.0)
		palm.add_child(trunk)

		for ang: float in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]:
			var frond := MeshInstance3D.new()
			var f_mesh := BoxMesh.new()
			f_mesh.size = Vector3(2.4, 0.08, 0.7)
			frond.mesh = f_mesh
			frond.material_override = mat_palm_leaf
			frond.position = Vector3(0.0, 7.3, 0.0)
			frond.rotation_degrees = Vector3(-20.0, ang, 0.0)
			palm.add_child(frond)

		# Cột đèn đường LED hiện đại
		var lamp := Node3D.new()
		lamp.position = Vector3(side * 11.5, 0.0, z_pos + 10.0)
		scenery_root.add_child(lamp)

		var pole := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.1
		p_mesh.bottom_radius = 0.16
		p_mesh.height = 6.5
		pole.mesh = p_mesh
		var mat_dark := StandardMaterial3D.new()
		mat_dark.albedo_color = Color("#2C3A47")
		pole.material_override = mat_dark
		pole.position = Vector3(0.0, 3.25, 0.0)
		lamp.add_child(pole)

		var bulb := MeshInstance3D.new()
		var bl_mesh := SphereMesh.new()
		bl_mesh.radius = 0.35
		bl_mesh.height = 0.7
		bulb.mesh = bl_mesh
		bulb.material_override = mat_lamp_glow
		bulb.position = Vector3(-side * 0.8, 6.4, 0.0)
		lamp.add_child(bulb)

	# 2. CỔNG CHÀO ĐẠI ĐÔ THỊ VINHOMES GRAND PARK (Vắt ngang qua đường tại Z = -135.0)
	var gate_root := Node3D.new()
	gate_root.position = Vector3(0.0, 0.0, -135.0)
	scenery_root.add_child(gate_root)

	# Cột cổng 2 bên
	for s: float in [-1.0, 1.0]:
		var g_pillar := MeshInstance3D.new()
		var gp_mesh := BoxMesh.new()
		gp_mesh.size = Vector3(2.2, 10.5, 2.2)
		g_pillar.mesh = gp_mesh
		var mat_gp := StandardMaterial3D.new()
		mat_gp.albedo_color = Color("#2C3A47")
		g_pillar.material_override = mat_gp
		g_pillar.position = Vector3(s * 9.5, 5.25, 0.0)
		gate_root.add_child(g_pillar)

	# Xà ngang cổng
	var arch_beam := MeshInstance3D.new()
	var ab_mesh := BoxMesh.new()
	ab_mesh.size = Vector3(21.2, 1.8, 2.2)
	arch_beam.mesh = ab_mesh
	var mat_ab := StandardMaterial3D.new()
	mat_ab.albedo_color = Color("#1E272E")
	arch_beam.material_override = mat_ab
	arch_beam.position = Vector3(0.0, 9.6, 0.0)
	gate_root.add_child(arch_beam)

	# Biển hiệu Vinhomes Grand Park nét căng
	if tex_vinhomes_gate:
		var gate_sign := MeshInstance3D.new()
		var gs_mesh := QuadMesh.new()
		gs_mesh.size = Vector2(18.0, 4.2)
		gate_sign.mesh = gs_mesh
		var mat_gs := StandardMaterial3D.new()
		mat_gs.albedo_texture = tex_vinhomes_gate
		gate_sign.material_override = mat_gs
		gate_sign.position = Vector3(0.0, 9.6, 1.15) # Hướng về phía người chơi xuất phát (+Z)
		gate_root.add_child(gate_sign)

func _build_nguyen_xien_shophouses_and_powerlines() -> void:
	# Danh sách các bảng hiệu hàng quán chân thực
	var shop_textures: Array[Texture2D] = [
		tex_milano,
		tex_suaxe,
		tex_bunbo,
		tex_taphoa,
		tex_bachhoa
	]

	var prev_pole_pos: Vector3 = Vector3.ZERO
	var shop_idx: int = 0

	for d: float in range(230.0, 760.0, 36.0):
		var t_xform: Transform3D = road_path.curve.sample_baked_with_rotation(d)

		for side: float in [-1.0, 1.0]:
			var shop_root := Node3D.new()
			scenery_root.add_child(shop_root)
			shop_root.global_transform = t_xform
			shop_root.position += t_xform.basis.x * (side * 12.5) + Vector3(0, 3.2, 0)
			# Xoay mặt tiền nhà hướng thẳng vào tim đường
			if side > 0.0:
				shop_root.rotate_y(PI)

			# 1. Thân nhà phố 2 tầng
			var house := MeshInstance3D.new()
			var h_mesh := BoxMesh.new()
			h_mesh.size = Vector3(9.5, 6.4, 9.0)
			house.mesh = h_mesh
			var mat_wall := StandardMaterial3D.new()
			mat_wall.albedo_color = Color("#E8D8C8") if side < 0 else Color("#D8E0E8")
			house.material_override = mat_wall
			shop_root.add_child(house)

			# 2. Mặt tiền tầng trệt ốp bảng hiệu thật (Milano, Sửa xe, Bún bò, Tạp hóa, Bách Hóa Xanh)
			var facade := MeshInstance3D.new()
			var f_mesh := QuadMesh.new()
			f_mesh.size = Vector2(9.2, 4.6)
			facade.mesh = f_mesh
			var chosen_tex: Texture2D = shop_textures[shop_idx % shop_textures.size()]
			shop_idx += 1
			var mat_facade := StandardMaterial3D.new()
			mat_facade.albedo_texture = chosen_tex
			facade.material_override = mat_facade
			facade.position = Vector3(0.0, -0.6, 4.55)
			shop_root.add_child(facade)

			# 3. Mái hiên di động nhô ra vỉa hè kẻ sọc đỏ-trắng hoặc xanh-trắng
			var awning := MeshInstance3D.new()
			var a_mesh := BoxMesh.new()
			a_mesh.size = Vector3(9.4, 0.1, 2.8)
			awning.mesh = a_mesh
			var mat_awning := StandardMaterial3D.new()
			mat_awning.albedo_texture = tex_awning_red if (shop_idx % 2 == 0) else tex_awning_blue
			mat_awning.uv1_scale = Vector3(4.0, 1.0, 1.0)
			awning.material_override = mat_awning
			awning.position = Vector3(0.0, 0.45, 5.8)
			awning.rotation_degrees = Vector3(16.0, 0.0, 0.0)
			shop_root.add_child(awning)

			# 4. Bàn ghế quán cóc & chậu cây trên vỉa hè
			var bench := MeshInstance3D.new()
			var bench_mesh := BoxMesh.new()
			bench_mesh.size = Vector3(2.4, 0.5, 0.8)
			bench.mesh = bench_mesh
			var mat_bench := StandardMaterial3D.new()
			mat_bench.albedo_color = Color("#795548")
			bench.material_override = mat_bench
			bench.position = Vector3(-2.2, -2.8, 5.6)
			shop_root.add_child(bench)

		# 5. Cột điện bê tông ly tâm & Búi dây điện chằng chịt
		var pole := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.22
		p_mesh.bottom_radius = 0.28
		p_mesh.height = 9.5
		pole.mesh = p_mesh
		var mat_pole := StandardMaterial3D.new()
		mat_pole.albedo_texture = tex_wire_pole
		pole.material_override = mat_pole
		scenery_root.add_child(pole)
		var pole_side: float = 1.0 if (int(d) % 72 == 0) else -1.0
		var pole_pos: Vector3 = t_xform.origin + t_xform.basis.x * (pole_side * 7.6) + Vector3(0, 4.75, 0)
		pole.global_position = pole_pos

		# Nối dây điện chằng chịt giữa 2 cột điện liên tiếp
		if prev_pole_pos != Vector3.ZERO:
			_create_powerline(prev_pole_pos + Vector3(0, 4.0, 0), pole_pos + Vector3(0, 4.0, 0))
		prev_pole_pos = pole_pos

func _create_powerline(from_pos: Vector3, to_pos: Vector3) -> void:
	var wire := MeshInstance3D.new()
	var w_mesh := CylinderMesh.new()
	w_mesh.top_radius = 0.02
	w_mesh.bottom_radius = 0.02
	var dist: float = from_pos.distance_to(to_pos)
	w_mesh.height = dist
	wire.mesh = w_mesh
	var mat_wire := StandardMaterial3D.new()
	mat_wire.albedo_color = Color("#111111")
	wire.material_override = mat_wire
	scenery_root.add_child(wire)

	wire.global_position = (from_pos + to_pos) * 0.5
	wire.look_at(to_pos, Vector3.UP)
	wire.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _build_cau_trau_trau_and_ringroad3() -> void:
	# Cầu Trau Trảu bắc qua rạch nhỏ từ d=810 đến d=930
	var mat_bridge_mat := StandardMaterial3D.new()
	mat_bridge_mat.albedo_texture = tex_bridge
	mat_bridge_mat.uv1_scale = Vector3(8.0, 1.0, 1.0)

	for d: float in range(810.0, 930.0, 12.0):
		var b_xform: Transform3D = road_path.curve.sample_baked_with_rotation(d)
		for side: float in [-1.0, 1.0]:
			var barrier := MeshInstance3D.new()
			var bar_mesh := BoxMesh.new()
			bar_mesh.size = Vector3(0.35, 1.1, 11.5)
			barrier.mesh = bar_mesh
			barrier.material_override = mat_bridge_mat
			scenery_root.add_child(barrier)
			barrier.global_transform = b_xform
			barrier.position += b_xform.basis.x * (side * 6.9) + Vector3(0, 0.7, 0)

	# Mặt nước rạch Trau Trảu phía dưới cầu
	var water := MeshInstance3D.new()
	var w_mesh := PlaneMesh.new()
	w_mesh.size = Vector2(80.0, 120.0)
	water.mesh = w_mesh
	var mat_water := StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.18, 0.38, 0.32, 0.95)
	mat_water.roughness = 0.15
	water.material_override = mat_water
	scenery_root.add_child(water)
	water.position = Vector3(10.0, -1.5, -870.0)

	# 4 Trụ bê tông khổng lồ của CÔNG TRÌNH VÀNH ĐAI 3
	var mat_ringroad := StandardMaterial3D.new()
	mat_ringroad.albedo_texture = tex_ringroad3

	for offset_z: float in [-820.0, -870.0, -920.0]:
		var pillar := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 2.4
		p_mesh.bottom_radius = 2.6
		p_mesh.height = 32.0
		pillar.mesh = p_mesh
		pillar.material_override = mat_ringroad
		scenery_root.add_child(pillar)
		pillar.position = Vector3(-20.0, 16.0, offset_z)

		# Cẩu tháp xây dựng Vành Đai 3 trên đỉnh trụ
		var crane_arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(28.0, 1.2, 1.2)
		crane_arm.mesh = arm_mesh
		var mat_crane := StandardMaterial3D.new()
		mat_crane.albedo_color = Color("#F1C40F") # Màu vàng cẩu tháp
		crane_arm.material_override = mat_crane
		scenery_root.add_child(crane_arm)
		crane_arm.position = Vector3(-12.0, 32.0, offset_z)

func _build_dai_lo_d2_boulevard() -> void:
	# Đại lộ D2 SHTP: 6 làn xe rộng rãi, dải phân cách trồng cỏ và cây cảnh
	var mat_palm := StandardMaterial3D.new()
	mat_palm.albedo_color = Color("#27AE60")

	for d: float in range(1040.0, 1500.0, 32.0):
		var t_xform: Transform3D = road_path.curve.sample_baked_with_rotation(d)

		# Hàng cây xanh 2 bên vỉa hè
		for side: float in [-1.0, 1.0]:
			var tree := MeshInstance3D.new()
			var t_mesh := SphereMesh.new()
			t_mesh.radius = 3.4
			t_mesh.height = 6.8
			tree.mesh = t_mesh
			tree.material_override = mat_palm
			scenery_root.add_child(tree)
			tree.global_position = t_xform.origin + t_xform.basis.x * (side * 11.5) + Vector3(0, 4.2, 0)

			# Cột đèn cao áp 2 nhánh chiếu sáng
			if int(d) % 64 == 0:
				var lamp := MeshInstance3D.new()
				var l_mesh := CylinderMesh.new()
				l_mesh.top_radius = 0.12
				l_mesh.bottom_radius = 0.16
				l_mesh.height = 8.5
				lamp.mesh = l_mesh
				var mat_metal := StandardMaterial3D.new()
				mat_metal.albedo_color = Color("#BDC3C7")
				mat_metal.metallic = 0.8
				lamp.material_override = mat_metal
				scenery_root.add_child(lamp)
				lamp.global_position = t_xform.origin + t_xform.basis.x * (side * 8.2) + Vector3(0, 4.25, 0)

	# Biển chào Khu Công nghệ cao SHTP từ ảnh chụp thật (fptu_shtp_monument.png)
	if tex_shtp:
		var shtp_board := MeshInstance3D.new()
		var sb_mesh := BoxMesh.new()
		sb_mesh.size = Vector3(8.0, 4.2, 0.3)
		shtp_board.mesh = sb_mesh
		var mat_shtp_b := StandardMaterial3D.new()
		mat_shtp_b.albedo_texture = tex_shtp
		shtp_board.material_override = mat_shtp_b
		scenery_root.add_child(shtp_board)
		var s_xform: Transform3D = road_path.curve.sample_baked_with_rotation(1070.0)
		shtp_board.global_position = s_xform.origin + s_xform.basis.x * 13.0 + Vector3(0, 3.4, 0)
		shtp_board.look_at(s_xform.origin + Vector3(0, 3.4, 0), Vector3.UP)
		shtp_board.rotate_object_local(Vector3.UP, PI)

func _build_roundabout_d1_d2() -> void:
	# VÒNG XOAY BÙNG BINH D1 - D2:
	# Tâm vòng xoay đặt tại (48.0, 0.0, -1560.0)
	var center: Vector3 = Vector3(48.0, 0.0, -1560.0)

	# 1. Mặt đường nhựa vòng xuyến (Lòng đường bùng binh nối 4 nhánh D1 & D2)
	var ring_road := MeshInstance3D.new()
	var rr_mesh := CylinderMesh.new()
	rr_mesh.top_radius = 36.0
	rr_mesh.bottom_radius = 36.0
	rr_mesh.height = 0.04
	ring_road.mesh = rr_mesh
	var mat_rr := StandardMaterial3D.new()
	if tex_asphalt:
		mat_rr.albedo_texture = tex_asphalt
		mat_rr.uv1_scale = Vector3(10.0, 10.0, 1.0)
	else:
		mat_rr.albedo_color = Color("#2F3640")
	ring_road.material_override = mat_rr
	ring_road.position = center + Vector3(0.0, 0.03, 0.0)
	scenery_root.add_child(ring_road)

	# Các nhánh đường của nút giao 4 ngã:
	# Nhánh D1 phía Tây (hướng Xa lộ Hà Nội)
	var arm_west := MeshInstance3D.new()
	var aw_mesh := BoxMesh.new()
	aw_mesh.size = Vector3(48.0, 0.04, 13.6)
	arm_west.mesh = aw_mesh
	arm_west.material_override = mat_rr
	arm_west.position = center + Vector3(-38.0, 0.03, 0.0)
	scenery_root.add_child(arm_west)

	# Nhánh D2 phía Bắc (hướng tiếp tục D2)
	var arm_north := MeshInstance3D.new()
	var an_mesh := BoxMesh.new()
	an_mesh.size = Vector3(13.6, 0.04, 48.0)
	arm_north.mesh = an_mesh
	arm_north.material_override = mat_rr
	arm_north.position = center + Vector3(0.0, 0.03, 38.0)
	scenery_root.add_child(arm_north)

	# 2. ĐẢO TRÒN BÙNG BINH (VẬT THỂ RẮN CÓ VA CHẠM VẬT LÝ - XE TUYỆT ĐỐI KHÔNG CHẠY XUYÊN QUA)
	var island_body := StaticBody3D.new()
	island_body.position = center
	scenery_root.add_child(island_body)

	var island_col := CollisionShape3D.new()
	var col_shape := CylinderShape3D.new()
	col_shape.radius = 16.0
	col_shape.height = 3.5
	island_col.shape = col_shape
	island_col.position = Vector3(0.0, 1.75, 0.0)
	island_body.add_child(island_col)

	# Đảo thảm cỏ xanh
	var island_mesh_inst := MeshInstance3D.new()
	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 16.0
	c_mesh.bottom_radius = 16.0
	c_mesh.height = 0.7
	island_mesh_inst.mesh = c_mesh
	var mat_grass := StandardMaterial3D.new()
	mat_grass.albedo_color = Color("#2ECC71") # Xanh cỏ bùng binh
	island_mesh_inst.material_override = mat_grass
	island_mesh_inst.position = Vector3(0.0, 0.35, 0.0)
	island_body.add_child(island_mesh_inst)

	# Bó vỉa tròn sơn đỏ-trắng quanh bùng binh
	var curb_ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 15.6
	ring_mesh.outer_radius = 16.4
	curb_ring.mesh = ring_mesh
	var mat_curb_ring := StandardMaterial3D.new()
	mat_curb_ring.albedo_texture = tex_curb
	mat_curb_ring.uv1_scale = Vector3(12.0, 1.0, 1.0)
	curb_ring.material_override = mat_curb_ring
	curb_ring.position = Vector3(0.0, 0.5, 0.0)
	island_body.add_child(curb_ring)

	# Tượng đài biểu tượng công nghệ cao SHTP ở tâm bùng binh
	var monument := MeshInstance3D.new()
	var m_mesh := PrismMesh.new()
	m_mesh.size = Vector3(6.0, 14.0, 6.0)
	monument.mesh = m_mesh
	var mat_monument := StandardMaterial3D.new()
	mat_monument.albedo_color = Color("#3498DB")
	mat_monument.metallic = 0.85
	monument.material_override = mat_monument
	monument.position = Vector3(0.0, 7.3, 0.0)
	island_body.add_child(monument)

	# 3. Biển báo giao thông Vòng Xuyến & Hướng Rẽ Phải ĐH FPT (4 hướng quanh đảo)
	for angle_deg: float in [0.0, 90.0, 180.0, 270.0]:
		var sign_post := MeshInstance3D.new()
		var sp_mesh := CylinderMesh.new()
		sp_mesh.top_radius = 0.08
		sp_mesh.bottom_radius = 0.08
		sp_mesh.height = 4.2
		sign_post.mesh = sp_mesh
		var mat_p := StandardMaterial3D.new()
		mat_p.albedo_color = Color("#7F8FA6")
		sign_post.material_override = mat_p
		island_body.add_child(sign_post)

		var rad: float = deg_to_rad(angle_deg)
		var sign_pos: Vector3 = Vector3(cos(rad) * 14.2, 2.1, sin(rad) * 14.2)
		sign_post.position = sign_pos

		var sign_board := MeshInstance3D.new()
		var sb_mesh := QuadMesh.new()
		sb_mesh.size = Vector2(2.6, 2.6)
		sign_board.mesh = sb_mesh
		var mat_sb := StandardMaterial3D.new()
		mat_sb.albedo_texture = tex_roundabout
		mat_sb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sign_board.material_override = mat_sb
		sign_board.position = Vector3(0.0, 1.4, 0.0)
		sign_post.add_child(sign_board)
		sign_board.look_at(island_body.global_position, Vector3.UP)

func _build_hutech_campus() -> void:
	# CỔNG VÀ KHUÔN VIÊN VIỆN CÔNG NGHỆ CAO ĐẠI HỌC HUTECH TRÊN ĐƯỜNG D1 (BÊN TAY TRÁI, -Z)
	# Theo OSM: mặt tiền HUTECH bắt đầu cách cổng chính FPT ~40 m và kéo dài qua cổng bãi xe FPT;
	# cổng HUTECH đối diện khoảng giữa các module cánh trước của FPT (x ≈ 350). Dùng chung builder với Màn 2.
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	FPTUCampusBuilder.build_hutech(scenery_root, Vector3(350.0, 0.0, -1608.0), cm)


func _process(_delta: float) -> void:
	if not player_bike or has_finished:
		return

	var offset: float = road_path.curve.get_closest_offset(player_bike.global_position)
	var new_zone: String = ""
	if offset < 200.0:
		new_zone = "VINHOMES GRAND PARK"
	elif offset < 780.0:
		new_zone = "ĐƯỜNG NGUYỄN XIỂN (QUANH CO & HÀNG QUÁN)"
	elif offset < 1030.0:
		new_zone = "CẦU TRAU TRẢU & CÔNG TRƯỜNG VÀNH ĐAI 3"
	elif offset < 1520.0:
		new_zone = "ĐẠI LỘ D2 - KHU CÔNG NGHỆ CAO SHTP"
	elif offset < 1720.0:
		new_zone = "VÒNG XOAY BÙNG BINH D1 - D2 (RẼ PHẢI VÀO ĐƯỜNG D1)"
	else:
		new_zone = "ĐƯỜNG D1 - ĐH FPT (BÊN PHẢI) & ĐH HUTECH (BÊN TRÁI)"

	if new_zone != current_zone:
		current_zone = new_zone
		emit_signal("zone_changed", current_zone)

	if offset >= finish_offset:
		has_finished = true
		emit_signal("destination_reached")