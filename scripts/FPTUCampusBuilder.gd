# File: res://scripts/FPTUCampusBuilder.gd
# Dựng khuôn viên ĐH FPT TP.HCM (Lô E2a-7, Đường D1, Khu CNC SHTP) theo ẢNH CHỤP THẬT & MẶT BẰNG THẬT.
# Dùng chung cho Màn 1 (nhìn từ đường D1) và Màn 2 (đỗ xe trong bãi, chạy bộ qua campus lên Lab 402).
# Tham chiếu (2026-10-20): ảnh flycam top-down + ảnh toàn cảnh do người dùng cung cấp, polygon OSM (way 1022939891).
#   - Lô đất ~180 m dọc D1 × 115 m sâu, ĐỐI DIỆN Viện Công nghệ cao HUTECH (toà tối màu, lam trắng dọc) qua D1.
#   - TOÀ NHÀ CHÍNH: VÒNG CHỮ NHẬT KHÉP KÍN ~150 × 64 m, lùi ~21 m so với ranh giới, RỖNG GIỮA LÀ SÂN TRONG.
#       * Hai cánh dài (trước giáp D1 & sau) dày ~14 m: 6 MODULE khối lớp học trắng, mỗi module có mái NGÓI
#         ĐỎ CAM một mái dốc, nối nhau bằng khối LINK hẹp 3 m mái bằng; cao 5 tầng.
#       * Hai cánh ngắn hai đầu dày ~26 m: các khối cao 6–8 tầng GIẬT CẤP về phía sân (kiểu "ngọn núi").
#       * Mỗi tầng: ban công viền gạch cam (terracotta) + cây xanh bồn, dải kính lùi sâu, nẹp sàn trắng;
#         tầng trệt hiên cột về phía sân; sảnh chính xuyên tầng trệt cánh trước (hướng đi vào từ D1),
#         lối đi sau xuyên tầng trệt cánh sau (từ bãi xe vào sân trong).
#   - Sân trong: nửa phía cổng bãi xe là bãi cỏ + HỒ SEN hình thận + cây; nửa phía cổng chính là sân lát xám
#     với vệt đỏ cam uốn lượn & cát vàng. Trước toà nhà: dải sân đỏ (đưa đón/đỗ xe) + mái che RĂNG CƯA dài,
#     hàng cau & hàng rào cây ra vỉa hè. Sau lưng: 2 dãy bãi xe máy có mái, sân bóng mini.
#     Cầu thang ngoài trời trắng lên sân thượng, đỉnh thang là cửa LAB 402.
#   - Vật liệu: mặt tường ô bàn cờ = fptu_alpha_facade.png (crop ảnh chụp thật) + normal map vẽ code,
#     hồ = lotus_pond_real.png, bảng ảnh thật fptu_*.png; mái ngói/cỏ/sân gạch/bảng tên/cờ/cỏ billboard =
#     texture vẽ code (generate_campus_textures.py).
# Hệ toạ độ cục bộ: X = dọc D1 (u, 0 ở cổng chính, tăng theo chiều xe chạy), Z = chiều sâu (v, 0 ở ranh giới
# giáp vỉa hè), Y lên. Mặt đường D1 ở phía -Z (tim đường tại v = -13).
#
# opts (Dictionary) cho build_authentic_campus:
#   "colliders": bool        – tạo StaticBody3D cho nhà, xe, cây, rào, hồ (Màn 2 cần cho xe máy)
#   "parking_gaps": Array[Vector2(u, v)] – chừa trống các ô đỗ xe trong bãi
#   "skip_barrier_at": float – không dựng thanh barie ở cổng u này (màn tự điều khiển barie)
#   "grass": bool            – cỏ billboard MultiMesh (mặc định true)
#   "no_grass_rects": Array[Rect2(u, v, w, h)] – vùng không rải cỏ (sân hiên căn tin...)
#   "open_front_modules" / "open_back_modules": Array[int] – module tầng trệt để TRỐNG làm sảnh/căn tin
#       (không khối mặt tiền, có cột tròn, sàn gạch, đèn trần, vách kính phía ngoài)
# Tiện ích dùng chung: build_d1_road_piece (đoạn D1 thẳng), build_hutech (HUTECH đối diện, colliders tuỳ chọn),
# build_motorbike / build_motorbike_multimesh (xe máy chi tiết), stair_profile (tuyến cầu thang cho runner).
class_name FPTUCampusBuilder
extends RefCounted

const PLOT_U: float = 180.0
const PLOT_V: float = 115.0
const FLOOR_H: float = 3.6
const TEX_DIR: String = "res://assets/textures/"
const MAIN_GATE_U: float = 6.0
const PARK_GATE_U: float = 174.0
const ROAD_CENTER_V: float = -13.0

# Vòng nhà chữ nhật
const RING_U0: float = 10.0
const RING_U1: float = 160.0
const RING_V0: float = 21.0
const RING_V1: float = 85.0
const LONG_D: float = 14.0    # độ dày cánh dài (trước/sau)
const SIDE_D: float = 26.0    # độ dày cánh ngắn (hai đầu, khối núi)
const LINK_W: float = 3.0
const LOBBY_MODULE: int = 2   # module thứ 3 cánh trước là sảnh xuyên
const BACK_GAP_MODULE: int = 4 # module thứ 5 cánh sau là lối đi từ bãi xe vào sân

# Bãi xe máy phía sau
const PARK_CX: float = 118.0
const PARK_ROW_A: float = 93.5
const PARK_ROW_B: float = 106.5
const PARK_LANE_V: float = 100.0
const PARK_HALF_LEN: float = 32.0

# Cầu thang ngoài trời (mặt ngoài cánh trước, đầu phía cổng bãi xe) -> Lab 402
const STAIR_V: float = 19.4
const STAIR_RUN: float = 30.5
const STAIR_TOP_Y: float = 17.9
const STAIR_W: float = 4.2

static var _opts: Dictionary = {}

static func _opt(key: String, default_value: Variant) -> Variant:
	return _opts.get(key, default_value)

# ===========================================================================
# TIỆN ÍCH VẬT LIỆU & HÌNH KHỐI
# ===========================================================================
static func load_texture(file_name: String) -> Texture2D:
	var path: String = TEX_DIR + file_name
	if not FileAccess.file_exists(path):
		return null
	var img: Image = GameFX.load_image_any(path)
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _tex(file_name: String) -> Texture2D:
	return load_texture(file_name)

static func _mat(color: Color, rough: float = 0.85, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color * emission
	return m

static func _tex_mat(file_name: String, fallback: Color, triplanar: bool, scale: Vector3, rough: float = 0.85, normal_file: String = "", normal_scale: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var t: Texture2D = _tex(file_name)
	if t:
		m.albedo_texture = t
		m.uv1_triplanar = triplanar
		m.uv1_scale = scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if normal_file != "":
			var nt: Texture2D = _tex(normal_file)
			if nt:
				m.normal_enabled = true
				m.normal_texture = nt
				m.normal_scale = normal_scale
	else:
		m.albedo_color = fallback
	m.roughness = rough
	return m

static func make_materials() -> Dictionary:
	var m: Dictionary = {}
	m["facade"] = _tex_mat("fptu_alpha_facade.png", Color("#F0F2F4"), true, Vector3(0.1, 0.1, 0.1), 0.78, "fptu_alpha_facade_n.png", 0.5)
	m["roof"] = _tex_mat("roof_terracotta.png", Color("#B5543A"), true, Vector3(0.55, 0.55, 0.55), 0.92, "roof_terracotta_n.png", 0.8)
	m["terracotta"] = _mat(Color("#C4683F"), 0.9)
	m["band"] = _mat(Color("#263645"), 0.2, 0.45)
	m["planter"] = _mat(Color("#2F6F3E"), 0.95)
	m["leaf"] = _mat(Color("#3B8F4A"), 0.9)
	m["leaf2"] = _mat(Color("#2E7D32"), 0.9)
	m["leaf3"] = _mat(Color("#62A85E"), 0.9)
	m["trunk"] = _mat(Color("#6D4C41"), 0.95)
	m["palm_trunk"] = _mat(Color("#8D8D8D"), 0.9)
	m["grass"] = _tex_mat("grass_lawn.png", Color("#4A8036"), false, Vector3(24.0, 15.0, 1.0), 0.95, "grass_lawn_n.png", 0.5)
	m["lawn_small"] = _tex_mat("grass_lawn.png", Color("#4A8036"), false, Vector3(6.0, 4.0, 1.0), 0.95, "grass_lawn_n.png", 0.5)
	m["paving"] = _tex_mat("fptu_courtyard_paving.png", Color("#A9ABAD"), false, Vector3(1.6, 1.0, 1.0), 0.85, "fptu_courtyard_paving_n.png", 0.35)
	m["sidewalk"] = _tex_mat("sidewalk_tiles.png", Color("#C3AF8C"), false, Vector3(48.0, 1.5, 1.0), 0.9, "sidewalk_tiles_n.png", 0.7)
	m["asphalt"] = _tex_mat("asphalt_road_hd.png", Color("#2F3640"), true, Vector3(0.12, 0.12, 0.12), 0.9, "asphalt_road_n.png", 0.6)
	m["red_plaza"] = _mat(Color("#8E3B2E"), 0.95)
	m["concrete"] = _mat(Color("#A4A8AB"), 0.92)
	m["lab_floor"] = _tex_mat("lab_floor_tiles.png", Color("#D6D2CA"), true, Vector3(0.83, 0.83, 0.83), 0.35, "lab_floor_tiles_n.png", 0.5)
	var terr: StandardMaterial3D = _tex_mat("lab_floor_tiles.png", Color("#B9B4AA"), true, Vector3(0.83, 0.83, 0.83), 0.45, "lab_floor_tiles_n.png", 0.5)
	terr.albedo_color = Color(0.86, 0.84, 0.8)
	m["terrazzo"] = terr
	m["wall_paint"] = _mat(Color("#F2F1EC"), 0.9)
	m["ceiling"] = _mat(Color("#F7F7F5"), 0.95)
	m["wood"] = _mat(Color("#8A5A3C"), 0.6)
	m["desk_top"] = _mat(Color("#D9CDB8"), 0.55)
	m["desk_leg"] = _mat(Color("#55606A"), 0.4, 0.6)
	m["monitor"] = _mat(Color("#14181C"), 0.3)
	m["screen_glow"] = _mat(Color("#CFE8FF"), 0.2, 0.0, 1.4)
	m["whiteboard"] = _mat(Color("#FAFAFA"), 0.25)
	m["chair_blue"] = _mat(Color("#1F5FA8"), 0.7)
	m["chair_orange"] = _mat(Color("#F37021"), 0.7)
	m["red_path"] = _mat(Color("#C44E34"), 0.9)
	m["white"] = _mat(Color("#F4F5F6"), 0.7)
	m["granite"] = _mat(Color("#7F8C8D"), 0.55)
	m["orange"] = _mat(Color("#F37021"), 0.5, 0.0, 0.35)
	var glass := _mat(Color(0.35, 0.6, 0.85, 0.55), 0.08, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m["glass"] = glass
	m["sand"] = _mat(Color("#E6D3A3"), 0.95)
	var water := _tex_mat("lotus_pond_real.png", Color(0.08, 0.48, 0.55), false, Vector3(9.0, 9.0, 1.0), 0.08)
	water.metallic = 0.5
	m["water"] = water
	m["gold"] = _mat(Color("#FFD32A"), 0.14, 0.92)
	m["steel"] = _mat(Color("#B0BEC5"), 0.3, 0.8)
	m["dark"] = _mat(Color("#1E272E"), 0.6)
	m["canopy"] = _tex_mat("parking_canopy_roof.png", Color("#9AA3AA"), false, Vector3(10.0, 5.0, 1.0), 0.6)
	m["pitch"] = _mat(Color("#2E8B3A"), 0.95)
	m["line"] = _mat(Color.WHITE, 0.8, 0.0, 0.2)
	m["yellow_line"] = _mat(Color("#FBC531"), 0.7, 0.0, 0.3)
	m["flag"] = _tex_mat("vietnam_flag.png", Color("#DA251D"), false, Vector3(1.0, 1.0, 1.0), 0.9)
	m["board"] = _tex_mat("fpt_university_board.png", Color("#F37021"), false, Vector3(1.0, 1.0, 1.0), 0.6)
	m["lamp"] = _mat(Color("#FFF3C4"), 0.4, 0.0, 1.2)
	m["bike"] = [_mat(Color("#E74C3C")), _mat(Color("#3498DB")), _mat(Color("#2C3E50")), _mat(Color("#F1C40F")), _mat(Color("#BDC3C7")), _mat(Color("#8E44AD"))]
	var grass_bl := StandardMaterial3D.new()
	var gbt: Texture2D = _tex("grass_blades.png")
	if gbt:
		grass_bl.albedo_texture = gbt
	grass_bl.albedo_color = Color(0.95, 1.0, 0.9)
	grass_bl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	grass_bl.alpha_scissor_threshold = 0.5
	grass_bl.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_bl.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	grass_bl.roughness = 1.0
	m["grass_blades"] = grass_bl
	return m

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if rot_y_deg != 0.0:
		mi.rotation_degrees.y = rot_y_deg
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, pos: Vector3, r_top: float, r_bot: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _sphere(parent: Node3D, pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _torus(parent: Node3D, pos: Vector3, r_in: float, r_out: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r_in
	tm.outer_radius = r_out
	tm.rings = 48
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _prism(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, left_to_right: float = 0.5, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	pm.left_to_right = left_to_right
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	if rot_y_deg != 0.0:
		mi.rotation_degrees.y = rot_y_deg
	parent.add_child(mi)
	return mi

static func _quad(parent: Node3D, pos: Vector3, size: Vector2, mat: Material, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = rot_y_deg
	parent.add_child(mi)
	return mi

static func _label(parent: Node3D, pos: Vector3, text: String, font_size: int, color: Color, rot_y_deg: float = 0.0, billboard: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = maxi(4, int(font_size * 0.22))
	l.modulate = color
	l.position = pos
	l.rotation_degrees.y = rot_y_deg
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l

# --- Va chạm tuỳ chọn (Màn 2) ---
static func _col_box(parent: Node3D, pos: Vector3, size: Vector3, rot_y_deg: float = 0.0) -> void:
	if not bool(_opt("colliders", false)):
		return
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	if rot_y_deg != 0.0:
		sb.rotation_degrees.y = rot_y_deg
	parent.add_child(sb)

static func _col_cyl(parent: Node3D, pos: Vector3, radius: float, height: float) -> void:
	if not bool(_opt("colliders", false)):
		return
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)

# ===========================================================================
# XE MÁY (xe tay ga sinh viên) – 1 bảng linh kiện dùng chung cho xe đơn (MeshInstance) & bãi xe (MultiMesh)
#   Hệ cục bộ: đầu xe hướng -Z, bánh trước tại z = -0.62.
# ===========================================================================
const BIKE_PAINTS: Array[Color] = [
	Color("#C0392B"), Color("#2980B9"), Color("#2C3E50"), Color("#F1C40F"), Color("#BDC3C7"),
	Color("#8E44AD"), Color("#E67E22"), Color("#1ABC9C"), Color("#ECF0F1"), Color("#7F8C8D"), Color("#F37021")
]
const BIKE_PARTS: Array = [
	{"kind": "cyl", "r": 0.3, "h": 0.1, "pos": Vector3(0.0, 0.3, -0.62), "rot": Vector3(0.0, 0.0, 90.0), "mat": "tire"},
	{"kind": "cyl", "r": 0.3, "h": 0.1, "pos": Vector3(0.0, 0.3, 0.62), "rot": Vector3(0.0, 0.0, 90.0), "mat": "tire"},
	{"kind": "cyl", "r": 0.13, "h": 0.12, "pos": Vector3(0.0, 0.3, -0.62), "rot": Vector3(0.0, 0.0, 90.0), "mat": "steel"},
	{"kind": "cyl", "r": 0.13, "h": 0.12, "pos": Vector3(0.0, 0.3, 0.62), "rot": Vector3(0.0, 0.0, 90.0), "mat": "steel"},
	{"kind": "box", "size": Vector3(0.26, 0.24, 0.95), "pos": Vector3(0.0, 0.58, 0.06), "mat": "paint"},
	{"kind": "box", "size": Vector3(0.36, 0.52, 0.16), "pos": Vector3(0.0, 0.7, -0.46), "mat": "paint"},
	{"kind": "box", "size": Vector3(0.34, 0.2, 0.5), "pos": Vector3(0.0, 0.5, 0.42), "mat": "paint"},
	{"kind": "box", "size": Vector3(0.3, 0.1, 0.6), "pos": Vector3(0.0, 0.84, 0.2), "mat": "dark"},
	{"kind": "box", "size": Vector3(0.62, 0.04, 0.04), "pos": Vector3(0.0, 0.99, -0.5), "mat": "dark"},
	{"kind": "cyl", "r": 0.03, "h": 0.52, "pos": Vector3(0.0, 0.72, -0.54), "rot": Vector3(16.0, 0.0, 0.0), "mat": "steel"},
	{"kind": "sphere", "r": 0.07, "pos": Vector3(0.0, 0.86, -0.56), "mat": "lamp"},
	{"kind": "sphere", "r": 0.04, "pos": Vector3(0.3, 1.1, -0.47), "mat": "steel"},
	{"kind": "sphere", "r": 0.04, "pos": Vector3(-0.3, 1.1, -0.47), "mat": "steel"},
	{"kind": "box", "size": Vector3(0.06, 0.06, 0.5), "pos": Vector3(0.15, 0.3, 0.32), "mat": "steel"},
	{"kind": "box", "size": Vector3(0.16, 0.08, 0.08), "pos": Vector3(0.0, 0.62, 0.62), "mat": "tail"}
]

static func _bike_part_mesh(part: Dictionary) -> PrimitiveMesh:
	match String(part["kind"]):
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = float(part["r"])
			c.bottom_radius = float(part["r"])
			c.height = float(part["h"])
			c.radial_segments = 14
			c.rings = 1
			return c
		"sphere":
			var sp := SphereMesh.new()
			sp.radius = float(part["r"])
			sp.height = float(part["r"]) * 2.0
			sp.radial_segments = 10
			sp.rings = 5
			return sp
		_:
			var b := BoxMesh.new()
			b.size = part["size"]
			return b

static func _bike_part_xform(part: Dictionary) -> Transform3D:
	var rot: Vector3 = part.get("rot", Vector3.ZERO)
	var b := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	return Transform3D(b, part["pos"])

static func _bike_part_material(part: Dictionary, m: Dictionary, paint: Color) -> Material:
	match String(part["mat"]):
		"paint":
			return _mat(paint, 0.35, 0.25)
		"tire":
			return _mat(Color("#15181C"), 0.95)
		"tail":
			return _mat(Color("#E74C3C"), 0.3, 0.0, 0.8)
		_:
			return m[part["mat"]]

## Một chiếc xe máy chi tiết (xe NPC, xe đối thủ...). yaw_deg = 0: đầu xe hướng -Z.
static func build_motorbike(parent: Node3D, pos: Vector3, yaw_deg: float, paint: Color, m: Dictionary) -> Node3D:
	var bike := Node3D.new()
	bike.position = pos
	bike.rotation_degrees.y = yaw_deg
	parent.add_child(bike)
	for part: Dictionary in BIKE_PARTS:
		var mi := MeshInstance3D.new()
		mi.mesh = _bike_part_mesh(part)
		mi.material_override = _bike_part_material(part, m, paint)
		mi.transform = _bike_part_xform(part)
		bike.add_child(mi)
	return bike

## Hàng trăm xe máy trong bãi: 1 MultiMeshInstance3D cho mỗi linh kiện (màu sơn theo instance color).
static func build_motorbike_multimesh(parent: Node3D, xforms: Array[Transform3D], colors: Array[Color], m: Dictionary) -> void:
	if xforms.is_empty():
		return
	var paint_mat := StandardMaterial3D.new()
	paint_mat.vertex_color_use_as_albedo = true
	paint_mat.roughness = 0.35
	paint_mat.metallic = 0.25
	var holder := Node3D.new()
	holder.name = "ParkedMotorbikes"
	parent.add_child(holder)
	for part: Dictionary in BIKE_PARTS:
		var is_paint: bool = String(part["mat"]) == "paint"
		var mesh: PrimitiveMesh = _bike_part_mesh(part)
		mesh.material = paint_mat if is_paint else _bike_part_material(part, m, Color.WHITE)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = is_paint
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		var local: Transform3D = _bike_part_xform(part)
		for i: int in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i] * local)
			if is_paint:
				mm.set_instance_color(i, colors[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		holder.add_child(mmi)

# ===========================================================================
# CÂY XANH
# ===========================================================================
static func build_tropical_tree(parent: Node3D, pos: Vector3, m: Dictionary, scale: float = 1.0, seed_val: int = 0) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	parent.add_child(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + int(pos.x * 7.0 + pos.z * 13.0)
	var h: float = rng.randf_range(4.2, 6.0) * scale
	_cyl(t, Vector3(0.0, h * 0.5, 0.0), 0.16 * scale, 0.26 * scale, h, m["trunk"])
	_col_cyl(t, Vector3(0.0, h * 0.5, 0.0), 0.3 * scale, h)
	var leafs: Array = [m["leaf"], m["leaf2"], m["leaf3"]]
	var r: float = rng.randf_range(2.0, 2.8) * scale
	_sphere(t, Vector3(0.0, h + r * 0.55, 0.0), r, leafs[rng.randi() % 3])
	_sphere(t, Vector3(r * 0.55, h + r * 0.25, r * 0.2), r * 0.72, leafs[rng.randi() % 3])
	_sphere(t, Vector3(-r * 0.5, h + r * 0.35, -r * 0.3), r * 0.68, leafs[rng.randi() % 3])
	_sphere(t, Vector3(0.1 * r, h + r * 1.05, -0.1 * r), r * 0.6, leafs[rng.randi() % 3])
	_sphere(t, Vector3(0.0, h + r * 0.1, r * 0.55), r * 0.55, leafs[rng.randi() % 3])
	t.rotation_degrees.y = rng.randf_range(0.0, 360.0)
	return t

static func build_royal_palm(parent: Node3D, pos: Vector3, m: Dictionary, height: float = 8.0) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	_cyl(p, Vector3(0.0, height * 0.5, 0.0), 0.2, 0.3, height, m["palm_trunk"])
	_col_cyl(p, Vector3(0.0, height * 0.5, 0.0), 0.3, height)
	_cyl(p, Vector3(0.0, height + 0.5, 0.0), 0.22, 0.26, 1.0, m["leaf2"])
	for a: int in range(7):
		var ang: float = a * 51.4
		var frond := _box(p, Vector3(0.0, height + 0.9, 0.0), Vector3(0.3, 0.08, 3.4), m["leaf"], ang)
		frond.rotation_degrees.x = -28.0
		frond.position += Vector3(sin(deg_to_rad(ang)), 0.0, cos(deg_to_rad(ang))) * 1.4
	return p

# ===========================================================================
# CÁNH NHÀ GỒM CÁC MODULE (khối lớp học + mái ngói dốc) NỐI BẰNG KHỐI LINK MÁI BẰNG
#   Trục chiều dài = +Z cục bộ (p_start -> p_end). depth = độ dày cánh (theo X cục bộ).
#   inner_sign: phía sân trong (+1 = +X cục bộ, -1 = -X cục bộ): tầng cao giật cấp lùi về phía đó,
#   hiên cột tầng trệt ở phía đó, mái ngói dốc xuống về phía đó.
#   profile: số tầng từng module. gap_module: module để trống tầng trệt làm lối đi xuyên (-1 = không).
# ===========================================================================
static func build_module_wing(parent: Node3D, p_start: Vector3, p_end: Vector3, depth: float, profile: Array, m: Dictionary, inner_sign: float = 1.0, gap_module: int = -1, arcade: bool = true, open_modules: Array = []) -> Node3D:
	var wing := Node3D.new()
	var dir: Vector3 = p_end - p_start
	dir.y = 0.0
	var length: float = maxf(dir.length(), 6.0)
	dir = dir.normalized()
	wing.position = Vector3((p_start.x + p_end.x) * 0.5, 0.0, (p_start.z + p_end.z) * 0.5)
	wing.rotation.y = atan2(dir.x, dir.z)
	parent.add_child(wing)

	var n: int = profile.size()
	var module_w: float = (length - float(n - 1) * LINK_W) / float(n)
	var half_len: float = length * 0.5
	var bush_xforms: Array[Transform3D] = []
	var step: float = 1.6

	for k: int in range(n):
		var floors: int = int(profile[k])
		var zc: float = -half_len + float(k) * (module_w + LINK_W) + module_w * 0.5
		for f: int in range(floors):
			var y0: float = float(f) * FLOOR_H
			var setback: float = 0.0 if f < 2 else float(f - 1) * step
			var depth_f: float = depth - setback
			var xc: float = -inner_sign * setback * 0.5
			var inner_x: float = xc + inner_sign * depth_f * 0.5
			var outer_x: float = xc - inner_sign * depth_f * 0.5

			if f == 0 and (k in open_modules):
				# TẦNG TRỆT MỞ (sảnh / căn tin): sàn gạch, cột tròn, vách kính phía ngoài, đèn trần; hiên cột phía sân
				_box(wing, Vector3(xc, 0.055, zc), Vector3(depth_f - 0.3, 0.05, module_w + LINK_W), m["terrazzo"])
				for cz: float in [zc - module_w * 0.25, zc + module_w * 0.25]:
					for cx: float in [xc - inner_sign * (depth_f * 0.5 - 3.2), xc + inner_sign * (depth_f * 0.5 - 3.2)]:
						_cyl(wing, Vector3(cx, FLOOR_H * 0.5, cz), 0.3, 0.32, FLOOR_H, m["white"])
						_col_cyl(wing, Vector3(cx, FLOOR_H * 0.5, cz), 0.34, FLOOR_H)
				var ox: float = outer_x - inner_sign * 0.12
				_box(wing, Vector3(ox + inner_sign * 0.2, 0.45, zc), Vector3(0.3, 0.9, module_w), m["wall_paint"])
				_col_box(wing, Vector3(ox + inner_sign * 0.2, 0.45, zc), Vector3(0.3, 0.9, module_w))
				_box(wing, Vector3(ox + inner_sign * 0.2, 2.15, zc), Vector3(0.06, 2.5, module_w), m["glass"])
				_col_box(wing, Vector3(ox + inner_sign * 0.2, 2.15, zc), Vector3(0.3, 2.5, module_w))
				var mz: float = zc - module_w * 0.5
				while mz <= zc + module_w * 0.5 + 0.01:
					_box(wing, Vector3(ox + inner_sign * 0.2, 2.15, mz), Vector3(0.1, 2.5, 0.08), m["white"])
					mz += module_w / 4.0
				for lz: float in [zc - module_w * 0.3, zc, zc + module_w * 0.3]:
					for lx: float in [xc - inner_sign * depth_f * 0.22, xc + inner_sign * depth_f * 0.22]:
						_box(wing, Vector3(lx, FLOOR_H - 0.28, lz), Vector3(1.3, 0.06, 0.28), m["lamp"])
						var ol := OmniLight3D.new()
						ol.position = Vector3(lx, FLOOR_H - 0.6, lz)
						ol.light_color = Color(1.0, 0.97, 0.9)
						ol.light_energy = 1.1
						ol.omni_range = 7.5
						ol.omni_attenuation = 1.3
						ol.shadow_enabled = false
						wing.add_child(ol)
				var az: float = zc - module_w * 0.5 + 1.2
				while az <= zc + module_w * 0.5 - 1.2:
					_cyl(wing, Vector3(inner_x - inner_sign * 0.35, FLOOR_H * 0.5, az), 0.22, 0.24, FLOOR_H, m["white"])
					_col_cyl(wing, Vector3(inner_x - inner_sign * 0.35, FLOOR_H * 0.5, az), 0.26, FLOOR_H)
					az += 3.4
			elif f == 0 and k == gap_module:
				# LỐI ĐI XUYÊN tầng trệt: 4 trụ lớn + dầm cam + nền gạch đỏ
				for sz: float in [-1.0, 1.0]:
					for sx: float in [-1.0, 1.0]:
						var pp := Vector3(xc + sx * (depth_f * 0.5 - 0.6), FLOOR_H * 0.5, zc + sz * (module_w * 0.5 - 0.6))
						_box(wing, pp, Vector3(1.0, FLOOR_H, 1.0), m["granite"])
						_col_box(wing, pp, Vector3(1.0, FLOOR_H, 1.0))
				_box(wing, Vector3(xc, FLOOR_H - 0.35, zc), Vector3(depth_f + 0.2, 0.7, module_w + 0.2), m["orange"])
				_box(wing, Vector3(xc, 0.03, zc), Vector3(depth_f + 8.0, 0.06, module_w), m["red_path"])
			elif f == 0 and arcade:
				var bpos := Vector3(xc - inner_sign * 1.1, FLOOR_H * 0.5, zc)
				var bsize := Vector3(depth_f - 2.2, FLOOR_H, module_w)
				_box(wing, bpos, bsize, m["facade"])
				_col_box(wing, bpos, bsize)
				var z: float = zc - module_w * 0.5 + 1.2
				while z <= zc + module_w * 0.5 - 1.2:
					_cyl(wing, Vector3(inner_x - inner_sign * 0.35, FLOOR_H * 0.5, z), 0.22, 0.24, FLOOR_H, m["white"])
					z += 3.4
			else:
				_box(wing, Vector3(xc, y0 + FLOOR_H * 0.5, zc), Vector3(depth_f, FLOOR_H, module_w), m["facade"])
				if f == 0:
					_col_box(wing, Vector3(xc, FLOOR_H * 0.5, zc), Vector3(depth_f, FLOOR_H, module_w))

			_box(wing, Vector3(xc, y0 + FLOOR_H - 0.12, zc), Vector3(depth_f + 0.36, 0.24, module_w + 0.16), m["white"])
			if f >= 1 or not arcade:
				for side_x: float in [inner_x, outer_x]:
					var sgn: float = 1.0 if side_x > xc else -1.0
					_box(wing, Vector3(side_x + sgn * 0.14, y0 + 0.55, zc), Vector3(0.3, 1.05, module_w - 0.3), m["terracotta"])
					var zb: float = zc - module_w * 0.5 + 1.0
					while zb <= zc + module_w * 0.5 - 1.0:
						var sc: float = 0.42 + 0.14 * absf(sin(zb * 1.9 + float(f) + side_x))
						bush_xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(sc, sc, sc)), Vector3(side_x + sgn * 0.05, y0 + 1.28, zb)))
						zb += 2.2
				if _module_has_room(wing, Vector3(xc, y0 + FLOOR_H * 0.5, zc), Vector3(depth_f, FLOOR_H, module_w)):
					for sgn: float in [-1.0, 1.0]:
						var q: MeshInstance3D = _quad(wing, Vector3(xc + sgn * (depth_f * 0.5 + 0.02), y0 + 2.3, zc), Vector2(module_w - 0.6, 1.5), m["band"], 90.0 * sgn)
						q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				else:
					_box(wing, Vector3(xc, y0 + 2.3, zc), Vector3(depth_f + 0.04, 1.5, module_w - 0.6), m["band"])

			if f >= 2:
				var tx: float = inner_x + inner_sign * step * 0.5
				_box(wing, Vector3(tx, y0 + 0.08, zc), Vector3(step, 0.16, module_w - 0.2), m["lawn_small"])

			if f == floors - 1:
				var ltr: float = 0.0 if inner_sign > 0.0 else 1.0
				_prism(wing, Vector3(xc, y0 + FLOOR_H + 1.0, zc), Vector3(depth_f + 0.6, 2.0, module_w + 0.3), m["roof"], ltr)
				# Mặt đứng phía cao của mái dốc: tường trắng + dải kính (không để lộ mặt ngói thẳng đứng)
				var fascia_x: float = outer_x - inner_sign * 0.34
				_box(wing, Vector3(fascia_x, y0 + FLOOR_H + 1.0, zc), Vector3(0.22, 2.0, module_w + 0.34), m["white"])
				_box(wing, Vector3(fascia_x - inner_sign * 0.08, y0 + FLOOR_H + 1.05, zc), Vector3(0.1, 1.1, module_w - 0.8), m["band"])
				if k % 2 == 0:
					_box(wing, Vector3(outer_x + inner_sign * 1.6, y0 + FLOOR_H + 2.6, zc - module_w * 0.5 + 1.8), Vector3(2.6, 2.4, 2.6), m["white"])
					_prism(wing, Vector3(outer_x + inner_sign * 1.6, y0 + FLOOR_H + 4.3, zc - module_w * 0.5 + 1.8), Vector3(2.8, 1.0, 2.8), m["white"], 0.5)

		if k < n - 1:
			var f_link: int = maxi(1, mini(int(profile[k]), int(profile[k + 1])) - 1)
			var zl: float = zc + module_w * 0.5 + LINK_W * 0.5
			var link_d: float = depth - 2.0
			if (k in open_modules) or ((k + 1) in open_modules):
				# Link cạnh module mở: tầng trệt chỉ còn 2 cột tròn (sảnh thông suốt), khối link bắt đầu từ tầng 1
				if f_link >= 2:
					_box(wing, Vector3(0.0, (FLOOR_H + float(f_link) * FLOOR_H) * 0.5, zl), Vector3(link_d, float(f_link - 1) * FLOOR_H, LINK_W), m["white"])
				for cx: float in [-(link_d * 0.5 - 0.5), link_d * 0.5 - 0.5]:
					_cyl(wing, Vector3(cx, FLOOR_H * 0.5, zl), 0.3, 0.32, FLOOR_H, m["white"])
					_col_cyl(wing, Vector3(cx, FLOOR_H * 0.5, zl), 0.34, FLOOR_H)
				_box(wing, Vector3(0.0, FLOOR_H - 0.3, zl), Vector3(link_d, 0.6, LINK_W), m["white"])
			else:
				_box(wing, Vector3(0.0, float(f_link) * FLOOR_H * 0.5, zl), Vector3(link_d, float(f_link) * FLOOR_H, LINK_W), m["white"])
				_col_box(wing, Vector3(0.0, FLOOR_H * 0.5, zl), Vector3(link_d, FLOOR_H, LINK_W))
			_box(wing, Vector3(0.0, float(f_link) * FLOOR_H + 0.12, zl), Vector3(link_d + 0.3, 0.24, LINK_W + 0.1), m["white"])
			_box(wing, Vector3(inner_sign * (link_d * 0.5 - 0.5), float(f_link) * FLOOR_H + 0.45, zl), Vector3(1.0, 0.5, LINK_W), m["planter"])
			for ff: int in range(1, f_link):
				_box(wing, Vector3(0.0, float(ff) * FLOOR_H + 2.3, zl), Vector3(link_d + 0.04, 1.4, LINK_W - 0.4), m["band"])

	if not bush_xforms.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var sm := SphereMesh.new()
		sm.radius = 0.9
		sm.height = 1.5
		sm.radial_segments = 10
		sm.rings = 5
		sm.material = m["leaf"]
		mm.mesh = sm
		mm.instance_count = bush_xforms.size()
		for bi: int in range(bush_xforms.size()):
			mm.set_instance_transform(bi, bush_xforms[bi])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		wing.add_child(mmi)
	return wing

## Tương thích (Màn 4): một dãy nhà đơn có trục dài theo Z cục bộ xoay yaw_deg, profile dạng núi.
static func build_mountain_bar(parent: Node3D, local_pos: Vector3, length: float, width: float, floors: int, yaw_deg: float, m: Dictionary, colonnade: bool = true) -> Node3D:
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0.0, cos(deg_to_rad(yaw_deg)))
	var a: Vector3 = local_pos - dir * length * 0.5
	var b: Vector3 = local_pos + dir * length * 0.5
	var n: int = maxi(2, int(round(length / 16.0)))
	var profile: Array = []
	for k: int in range(n):
		var t: float = (float(k) + 0.5) / float(n)
		var bump: float = 0.5 - 0.5 * cos(TAU * t)
		profile.append(maxi(2, floors - 3) + int(round(bump * 3.0)))
	return build_module_wing(parent, a, b, width, profile, m, 1.0, -1, colonnade)

# ===========================================================================
# TOẠ ĐỘ THAM CHIẾU CHO CÁC MÀN
# ===========================================================================
static func _front_module_w() -> float:
	var span: float = (RING_U1 - SIDE_D) - (RING_U0 + SIDE_D)
	return (span - 5.0 * LINK_W) / 6.0

static func lobby_u() -> float:
	var mw: float = _front_module_w()
	return (RING_U0 + SIDE_D) + float(LOBBY_MODULE) * (mw + LINK_W) + mw * 0.5

static func back_gap_u() -> float:
	var mw: float = _front_module_w()
	return (RING_U0 + SIDE_D) + float(BACK_GAP_MODULE) * (mw + LINK_W) + mw * 0.5

static func stair_foot() -> Vector3:
	return Vector3(RING_U1 - SIDE_D - STAIR_RUN, 0.0, STAIR_V)

static func stair_top() -> Vector3:
	return Vector3(RING_U1 - SIDE_D, STAIR_TOP_Y, STAIR_V)

## Cửa Lab 402 nằm trên mặt trước cánh phải, tầng 5 (lầu 4) – ngay cạnh đỉnh cầu thang ngoài trời.
static func lab402_door() -> Vector3:
	return Vector3(RING_U1 - SIDE_D + 9.0, STAIR_TOP_Y, STAIR_V)

## Mặt cắt cầu thang ngoài trời: 3 đợt thang + 2 chiếu nghỉ (các điểm gấp khúc, dùng làm tuyến chạy Màn 2).
static func stair_profile() -> Array[Vector3]:
	var sf: Vector3 = stair_foot()
	var x_end: float = RING_U1 - SIDE_D
	var landing: float = 2.5
	var flight: float = (x_end - sf.x - 2.0 * landing) / 3.0
	var rise: float = (STAIR_TOP_Y - sf.y) / 3.0
	var pts: Array[Vector3] = [sf]
	var x: float = sf.x
	var y: float = sf.y
	for i: int in range(3):
		x += flight
		y += rise
		pts.append(Vector3(x, y, STAIR_V))
		if i < 2:
			x += landing
			pts.append(Vector3(x, y, STAIR_V))
	return pts

static func parking_spot_candidates() -> Array[Vector3]:
	return [
		Vector3(143.0, 0.0, PARK_ROW_B - 1.8), # gần lối vào nhất, mặt trong dãy B
		Vector3(106.6, 0.0, PARK_ROW_A + 1.8), # giữa bãi, mặt trong dãy A
		Vector3(92.3, 0.0, PARK_ROW_B + 1.8)   # góc xa, mặt ngoài dãy B (phải vòng qua đầu mái)
	]

static func park_gate_guard_pos() -> Vector3:
	return Vector3(PARK_GATE_U + 9.5, 0.0, 4.5)

## Tâm phòng LAB 402: cánh phải, module 0, tầng 5 (lầu 4) – ngay sau cửa đỉnh cầu thang ngoài trời.
## Phòng 14 m (dọc u) × 11.7 m (dọc v) × 3.3 m; cửa sổ phía sân trong (u nhỏ) và phía D1 (v nhỏ).
static func lab402_room_center() -> Vector3:
	return Vector3(148.0, STAIR_TOP_Y + 0.15, 27.2)

static func lab402_room_size() -> Vector3:
	return Vector3(14.0, 3.3, 11.7)

## Tâm PHÒNG 311: cánh trước, module 4, tầng 3 (lầu 3). Phòng 12 × 10 × 3.3 m; cửa sổ 2 phía (D1 & sân trong).
static func room311_center() -> Vector3:
	return Vector3(110.3, FLOOR_H * 3.0 + 0.05, 26.4)

static func room311_size() -> Vector3:
	return Vector3(12.0, 3.3, 10.0)

## Hộp bao (toạ độ campus) của các phòng có nội thất: module chứa phòng không dựng DẢI KÍNH TỐI dạng khối đặc
## (khối đó xuyên qua phòng, camera đặt trên nóc nó sẽ thấy một mảng đen) mà chỉ dán 2 quad hướng ra ngoài.
static func interior_room_aabbs() -> Array[AABB]:
	var out: Array[AABB] = []
	for pair: Array in [[lab402_room_center(), lab402_room_size()], [room311_center(), room311_size()]]:
		var c: Vector3 = pair[0]
		var sz: Vector3 = pair[1]
		out.append(AABB(Vector3(c.x - sz.x * 0.5, c.y + 0.1, c.z - sz.z * 0.5), Vector3(sz.x, sz.y - 0.2, sz.z)))
	return out

static func _module_has_room(wing: Node3D, local_center: Vector3, local_size: Vector3) -> bool:
	var wc: Vector3 = wing.transform * local_center
	var half: Vector3 = (wing.basis * (local_size * 0.5)).abs()
	var box := AABB(wc - half, half * 2.0)
	for r: AABB in interior_room_aabbs():
		if box.intersects(r):
			return true
	return false

## Tâm sảnh CĂN TIN tầng trệt cánh trước (module 3 + 4 mở, trụ link ở giữa làm cột lớn); x ±15, z −12..+12
## (z âm = trong nhà phía D1, z dương = hiên ra sân trong).
static func canteen_center() -> Vector3:
	var mw: float = _front_module_w()
	return Vector3((RING_U0 + SIDE_D) + 4.0 * (mw + LINK_W) - LINK_W * 0.5, 0.0, RING_V0 + LONG_D - 2.0)

# ===========================================================================
# NỘI THẤT PHÒNG HỌC / LAB (dùng cho Màn 3, Màn 6 ban đêm, màn Extra)
#   Hệ cục bộ của parent: sàn ở y = 0, phòng rộng size.x (trục X) × cao size.y × sâu size.z (trục Z).
#   opts: "windows": Array["+x","-x","+z","-z"], "door": side, "door_x": vị trí cửa dọc tường (−1..1),
#         "board_side": tường treo bảng trắng, "name": chữ trên cửa, "ceiling_layer": layer mesh trần,
#         "night": bool (đèn trần sáng mạnh hơn), "accent": Color (sọc màu FPT)
#   Trả về {"ceiling": Array[Node3D], "lights": Array[OmniLight3D], "windows": Array[Node3D]}
# ===========================================================================
static func build_room_interior(parent: Node3D, size: Vector3, m: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var w: float = size.x
	var h: float = size.y
	var d: float = size.z
	var windows: Array = opts.get("windows", ["+x"])
	var door_side: String = String(opts.get("door", "+z"))
	var door_x: float = float(opts.get("door_x", 0.6))
	var board_side: String = String(opts.get("board_side", "-x"))
	var accent: Color = opts.get("accent", Color("#F37021"))
	var night: bool = bool(opts.get("night", false))
	var ceil_layer: int = int(opts.get("ceiling_layer", 1))
	var out: Dictionary = {"ceiling": [], "lights": [], "windows": []}
	var room := Node3D.new()
	room.name = "RoomInterior"
	parent.add_child(room)
	var mat_accent := _mat(accent, 0.6)
	var mat_skirt := _mat(Color("#4A4F55"), 0.7)
	var mat_frame := _mat(Color("#C9CDD1"), 0.3, 0.7)

	_box(room, Vector3(0.0, -0.05, 0.0), Vector3(w, 0.1, d), m["lab_floor"])
	var ceiling: MeshInstance3D = _box(room, Vector3(0.0, h + 0.06, 0.0), Vector3(w + 0.4, 0.12, d + 0.4), m["ceiling"])
	ceiling.layers = ceil_layer
	out["ceiling"].append(ceiling)
	# Đèn tuýp âm trần theo lưới + OmniLight (không bóng) để nội thất sáng đều
	var nx: int = maxi(2, int(round(w / 3.5)))
	var nz: int = maxi(2, int(round(d / 3.5)))
	var mat_tube := _mat(Color("#FFFBEE"), 0.3, 0.0, 2.2 if night else 1.4)
	for ix: int in range(nx):
		for iz: int in range(nz):
			var px: float = -w * 0.5 + (float(ix) + 0.5) * (w / float(nx))
			var pz: float = -d * 0.5 + (float(iz) + 0.5) * (d / float(nz))
			var panel: MeshInstance3D = _box(room, Vector3(px, h - 0.03, pz), Vector3(1.2, 0.05, 0.32), mat_tube)
			panel.layers = ceil_layer
			out["ceiling"].append(panel)
			var housing: MeshInstance3D = _box(room, Vector3(px, h - 0.015, pz), Vector3(1.3, 0.04, 0.42), m["white"])
			housing.layers = ceil_layer
			out["ceiling"].append(housing)
			if (ix + iz) % 2 == 0:
				var ol := OmniLight3D.new()
				ol.position = Vector3(px, h - 0.35, pz)
				ol.light_color = Color(1.0, 0.97, 0.9)
				ol.light_energy = 1.5 if night else 0.9
				ol.omni_range = 7.0
				ol.omni_attenuation = 1.4
				ol.shadow_enabled = false
				room.add_child(ol)
				out["lights"].append(ol)

	# 4 bức tường (tường có cửa sổ = bệ 0.95 m + kính + lanh tô)
	var sides: Array = [
		{"id": "+x", "pos": Vector3(w * 0.5, 0.0, 0.0), "len": d, "rot": 90.0},
		{"id": "-x", "pos": Vector3(-w * 0.5, 0.0, 0.0), "len": d, "rot": 90.0},
		{"id": "+z", "pos": Vector3(0.0, 0.0, d * 0.5), "len": w, "rot": 0.0},
		{"id": "-z", "pos": Vector3(0.0, 0.0, -d * 0.5), "len": w, "rot": 0.0}
	]
	for sd: Dictionary in sides:
		var id: String = sd["id"]
		var len_w: float = float(sd["len"])
		var rot: float = float(sd["rot"])
		var wall := Node3D.new()
		wall.position = sd["pos"]
		wall.rotation_degrees.y = rot
		room.add_child(wall)
		# Trong hệ cục bộ của tường: X dọc tường, Z pháp tuyến (0 = mặt tường)
		if id in windows:
			_box(wall, Vector3(0.0, 0.475, 0.0), Vector3(len_w, 0.95, 0.2), m["wall_paint"])
			_box(wall, Vector3(0.0, (2.55 + h) * 0.5, 0.0), Vector3(len_w, h - 2.55, 0.2), m["wall_paint"])
			var glass: MeshInstance3D = _box(wall, Vector3(0.0, 1.75, 0.0), Vector3(len_w, 1.6, 0.04), m["glass"])
			out["windows"].append(glass)
			_box(wall, Vector3(0.0, 0.97, 0.0), Vector3(len_w, 0.06, 0.26), mat_frame)
			_box(wall, Vector3(0.0, 2.53, 0.0), Vector3(len_w, 0.06, 0.26), mat_frame)
			var n_mul: int = maxi(2, int(round(len_w / 1.45)))
			for i: int in range(n_mul + 1):
				var mx: float = -len_w * 0.5 + float(i) * (len_w / float(n_mul))
				_box(wall, Vector3(mx, 1.75, 0.0), Vector3(0.07, 1.6, 0.1), mat_frame)
			# Rèm lá dọc kéo một phần + bệ cửa sổ
			_box(wall, Vector3(-len_w * 0.5 + 1.1, 1.75, 0.09), Vector3(2.0, 1.56, 0.03), _mat(Color("#DDE3E8"), 0.9))
			_box(wall, Vector3(0.0, 0.97, 0.16), Vector3(len_w, 0.04, 0.12), m["white"])
		else:
			_box(wall, Vector3(0.0, h * 0.5, 0.0), Vector3(len_w, h, 0.2), m["wall_paint"])
			_box(wall, Vector3(0.0, 1.12, 0.105), Vector3(len_w, 0.1, 0.012), mat_accent)
		_box(wall, Vector3(0.0, 0.06, 0.105), Vector3(len_w, 0.12, 0.012), mat_skirt)
		_box(wall, Vector3(0.0, h - 0.06, 0.105), Vector3(len_w, 0.12, 0.012), m["white"])
		if id == board_side:
			_box(wall, Vector3(0.0, 1.75, 0.13), Vector3(3.8, 1.3, 0.04), mat_frame)
			_box(wall, Vector3(0.0, 1.75, 0.15), Vector3(3.6, 1.15, 0.02), m["whiteboard"])
			_box(wall, Vector3(0.0, 1.14, 0.17), Vector3(3.6, 0.04, 0.1), mat_frame)
			_label(wall, Vector3(0.0, 2.0, 0.17), "FAP · SWP391 · LAB 402\nMerge trước 23:59!", 20, Color("#1F5FA8"), 0.0)
			for ux: float in [-len_w * 0.33, len_w * 0.33]:
				_box(wall, Vector3(ux, h - 0.45, 0.22), Vector3(0.95, 0.3, 0.24), m["white"])
				_box(wall, Vector3(ux, h - 0.6, 0.31), Vector3(0.9, 0.04, 0.06), m["dark"])
			var clock_m: MeshInstance3D = _cyl(wall, Vector3(len_w * 0.5 - 1.0, h - 0.5, 0.13), 0.18, 0.18, 0.04, m["white"])
			clock_m.rotation_degrees.x = 90.0
		if id == door_side:
			var dx: float = door_x * (len_w * 0.5 - 1.2)
			_box(wall, Vector3(dx, 1.1, 0.12), Vector3(1.1, 2.2, 0.08), m["dark"])
			_box(wall, Vector3(dx, 1.08, 0.16), Vector3(0.94, 2.1, 0.05), m["wood"])
			_box(wall, Vector3(dx + 0.36, 1.05, 0.21), Vector3(0.1, 0.04, 0.06), m["steel"])
			_box(wall, Vector3(dx, 1.5, 0.2), Vector3(0.3, 0.5, 0.01), m["glass"])
			_box(wall, Vector3(dx, 2.42, 0.13), Vector3(0.9, 0.24, 0.03), mat_accent)
			_label(wall, Vector3(dx, 2.42, 0.16), String(opts.get("name", "LAB 402")), 14, Color.WHITE, 0.0)
	# Máy chiếu trần
	var proj: MeshInstance3D = _box(room, Vector3(0.0, h - 0.4, 0.6), Vector3(0.4, 0.14, 0.34), m["white"])
	proj.layers = ceil_layer
	_cyl(room, Vector3(0.0, h - 0.18, 0.6), 0.03, 0.03, 0.3, m["steel"]).layers = ceil_layer
	return out

## Bàn máy tính phòng lab: mặt bàn + 2 chân + CPU + 1-2 màn hình sáng + bàn phím + ghế. Trả về node bàn.
static func build_lab_desk(parent: Node3D, pos: Vector3, m: Dictionary, monitors: int = 2, yaw_deg: float = 0.0, chair_mat_key: String = "chair_blue", width: float = 3.0) -> Node3D:
	var desk := Node3D.new()
	desk.position = pos
	desk.rotation_degrees.y = yaw_deg
	parent.add_child(desk)
	var top_y: float = 0.76
	_box(desk, Vector3(0.0, top_y - 0.02, 0.0), Vector3(width, 0.04, 0.7), m["desk_top"])
	_box(desk, Vector3(0.0, top_y - 0.3, -0.3), Vector3(width - 0.1, 0.4, 0.03), m["desk_leg"])
	for sx: float in [-1.0, 1.0]:
		_box(desk, Vector3(sx * (width * 0.5 - 0.05), top_y * 0.5 - 0.02, 0.0), Vector3(0.05, top_y - 0.04, 0.66), m["desk_leg"])
	for i: int in range(monitors):
		var mx: float = 0.0 if monitors == 1 else (-width * 0.25 + float(i) * width * 0.5)
		_box(desk, Vector3(mx, top_y + 0.02, -0.2), Vector3(0.22, 0.02, 0.16), m["monitor"])
		_box(desk, Vector3(mx, top_y + 0.14, -0.22), Vector3(0.04, 0.24, 0.03), m["monitor"])
		_box(desk, Vector3(mx, top_y + 0.4, -0.23), Vector3(0.56, 0.34, 0.03), m["monitor"])
		_box(desk, Vector3(mx, top_y + 0.4, -0.212), Vector3(0.52, 0.3, 0.004), m["screen_glow"])
		_box(desk, Vector3(mx, top_y + 0.008, 0.12), Vector3(0.42, 0.016, 0.14), m["dark"])
		_box(desk, Vector3(mx + 0.3, top_y + 0.01, 0.12), Vector3(0.06, 0.02, 0.1), m["dark"])
		_box(desk, Vector3(mx + (0.55 if i == monitors - 1 else -0.55), 0.2, -0.1), Vector3(0.18, 0.4, 0.42), m["monitor"])
		# Ghế xoay
		var cz: float = 0.75
		_cyl(desk, Vector3(mx, 0.44, cz), 0.23, 0.23, 0.08, m[chair_mat_key])
		_box(desk, Vector3(mx, 0.72, cz + 0.2), Vector3(0.42, 0.5, 0.06), m[chair_mat_key])
		_cyl(desk, Vector3(mx, 0.22, cz), 0.025, 0.025, 0.4, m["steel"])
		_cyl(desk, Vector3(mx, 0.03, cz), 0.28, 0.28, 0.03, m["dark"])
	return desk

# ===========================================================================
# KHUÔN VIÊN HOÀN CHỈNH
# ===========================================================================
static func build_authentic_campus(parent: Node3D, gate_origin: Vector3, rot_y_deg: float = 0.0, opts: Dictionary = {}) -> Node3D:
	_opts = opts
	var m: Dictionary = make_materials()
	var root := Node3D.new()
	root.name = "AuthenticFPTUCampus_SHTP"
	root.position = gate_origin
	root.rotation_degrees.y = rot_y_deg
	parent.add_child(root)

	_build_ground_and_boundary(root, m)
	_build_gate(root, m, MAIN_GATE_U, true)
	_build_gate(root, m, PARK_GATE_U, false)
	_build_front_plaza(root, m)
	_build_ring_building(root, m)
	_build_courtyard(root, m)
	_build_back_facilities(root, m)
	_build_perimeter_trees(root, m)
	if bool(_opt("grass", true)):
		_build_grass(root, m)
	_opts = {}
	return root

static func _build_ground_and_boundary(root: Node3D, m: Dictionary) -> void:
	_box(root, Vector3(PLOT_U * 0.5, -0.06, PLOT_V * 0.5), Vector3(PLOT_U + 10.0, 0.12, PLOT_V + 10.0), m["grass"])
	# Vỉa hè lát gạch + bó vỉa đá; HẠ VỈA HÈ (lối xe lên) tại hai cổng
	var walk_segs: Array = [[-35.0, MAIN_GATE_U - 7.0], [MAIN_GATE_U + 7.0, PARK_GATE_U - 7.0], [PARK_GATE_U + 7.0, PLOT_U + 35.0]]
	for seg: Array in walk_segs:
		var a: float = float(seg[0])
		var b: float = float(seg[1])
		_box(root, Vector3((a + b) * 0.5, 0.14, -2.7), Vector3(b - a, 0.28, 5.4), m["sidewalk"])
		_box(root, Vector3((a + b) * 0.5, 0.2, -5.3), Vector3(b - a, 0.4, 0.3), m["granite"])
	for gu: float in [MAIN_GATE_U, PARK_GATE_U]:
		_box(root, Vector3(gu, 0.05, -2.7), Vector3(14.0, 0.1, 5.4), m["red_plaza"])
		for sx: float in [-1.0, 1.0]:
			_box(root, Vector3(gu + sx * 7.1, 0.2, -5.3), Vector3(0.3, 0.4, 0.3), m["granite"])
	var gaps: Array = [[MAIN_GATE_U - 6.5, MAIN_GATE_U + 6.5], [PARK_GATE_U - 6.5, PARK_GATE_U + 6.5]]
	var u: float = -12.0
	while u < PLOT_U + 12.0:
		var seg_end: float = minf(u + 6.0, PLOT_U + 12.0)
		var in_gap: bool = false
		for g: Array in gaps:
			if u < float(g[1]) and seg_end > float(g[0]):
				in_gap = true
		if not in_gap:
			var cx: float = (u + seg_end) * 0.5
			_box(root, Vector3(cx, 0.3, 0.2), Vector3(seg_end - u - 0.1, 0.6, 0.35), m["white"])
			_box(root, Vector3(cx, 1.0, 0.2), Vector3(seg_end - u - 0.1, 0.05, 0.4), m["steel"])
			_box(root, Vector3(cx, 0.8, 1.1), Vector3(seg_end - u - 0.3, 1.4, 1.0), m["leaf2"])
			_col_box(root, Vector3(cx, 0.8, 0.6), Vector3(seg_end - u, 1.6, 1.4))
		u = seg_end
	for side: float in [-10.0, PLOT_U + 10.0]:
		_box(root, Vector3(side, 0.3, PLOT_V * 0.5), Vector3(0.35, 0.6, PLOT_V), m["white"])
		_box(root, Vector3(side + (1.0 if side < 0.0 else -1.0), 0.8, PLOT_V * 0.5), Vector3(0.9, 1.4, PLOT_V - 2.0), m["leaf2"])
		_col_box(root, Vector3(side, 0.8, PLOT_V * 0.5), Vector3(1.6, 1.6, PLOT_V))
	_box(root, Vector3(PLOT_U * 0.5, 0.3, PLOT_V + 5.0), Vector3(PLOT_U + 20.0, 0.6, 0.35), m["white"])
	_col_box(root, Vector3(PLOT_U * 0.5, 0.8, PLOT_V + 5.0), Vector3(PLOT_U + 20.0, 1.6, 0.6))

static func _build_gate(root: Node3D, m: Dictionary, u: float, is_main: bool) -> void:
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(u + sx * 6.0, 2.6, 0.2), Vector3(1.2, 5.2, 1.2), m["granite"])
		_col_box(root, Vector3(u + sx * 6.0, 2.6, 0.2), Vector3(1.2, 5.2, 1.2))
		_box(root, Vector3(u + sx * 6.0, 5.35, 0.2), Vector3(1.6, 0.3, 1.6), m["white"])
	_box(root, Vector3(u, 5.0, 0.2), Vector3(12.4, 1.7, 0.6), m["orange"])
	_quad(root, Vector3(u, 5.0, -0.12), Vector2(12.0, 1.5), m["board"], 180.0)
	if is_main:
		_box(root, Vector3(u - 13.5, 1.3, 1.2), Vector3(11.0, 2.6, 1.0), m["orange"])
		_col_box(root, Vector3(u - 13.5, 1.3, 1.2), Vector3(11.0, 2.6, 1.0))
		_label(root, Vector3(u - 13.5, 1.45, 0.66), "TRƯỜNG ĐẠI HỌC FPT\nTP. HỒ CHÍ MINH", 30, Color.WHITE, 180.0)
		_label(root, Vector3(u - 13.5, 0.45, 0.66), "LÔ E2A-7 · ĐƯỜNG D1 · KHU CÔNG NGHỆ CAO", 13, Color.WHITE, 180.0)
		var mat_map := _tex_mat("fptu_campus_map_billboard.png", Color("#DDDDDD"), false, Vector3.ONE, 0.7)
		_box(root, Vector3(u + 12.5, 2.0, 2.4), Vector3(5.6, 3.2, 0.25), mat_map)
		_label(root, Vector3(u + 12.5, 3.9, 2.25), "SƠ ĐỒ KHUÔN VIÊN FPTU (ẢNH CHỤP THỰC TẾ)", 14, Color("#F37021"), 180.0)
	else:
		_label(root, Vector3(u, 3.3, -0.3), "🅿 CỔNG BÃI XE D1 – SINH VIÊN QUÉT THẺ", 22, Color.WHITE, 180.0)
	_box(root, Vector3(u + 9.5, 1.6, 4.5), Vector3(3.2, 3.2, 3.0), m["white"])
	_col_box(root, Vector3(u + 9.5, 1.6, 4.5), Vector3(3.2, 3.2, 3.0))
	_box(root, Vector3(u + 9.5, 2.0, 2.95), Vector3(2.4, 1.1, 0.1), m["glass"])
	_box(root, Vector3(u + 9.5, 3.35, 4.5), Vector3(3.8, 0.3, 3.6), m["roof"])
	_cyl(root, Vector3(u + 5.2, 0.6, 3.2), 0.12, 0.14, 1.2, m["steel"])
	if absf(float(_opt("skip_barrier_at", -999.0)) - u) > 0.5:
		var arm := _box(root, Vector3(u + 2.2, 1.15, 3.2), Vector3(6.0, 0.14, 0.14), m["line"])
		arm.rotation_degrees.z = 4.0
		for i: int in range(5):
			_box(root, Vector3(u + 4.6 - i * 1.2, 1.15 + i * 0.08, 3.21), Vector3(0.5, 0.15, 0.15), _mat(Color("#E74C3C"), 0.6))
	_cyl(root, Vector3(u - 3.0, 6.0, 7.0), 0.07, 0.11, 12.0, m["steel"])
	_quad(root, Vector3(u - 3.0 + 1.55, 11.1, 7.0), Vector2(3.0, 2.0), m["flag"], 0.0)

static func _build_front_plaza(root: Node3D, m: Dictionary) -> void:
	_box(root, Vector3(PLOT_U * 0.5, 0.02, 13.5), Vector3(PLOT_U - 4.0, 0.05, 15.0), m["red_plaza"])
	_box(root, Vector3(MAIN_GATE_U, 0.03, 4.0), Vector3(10.0, 0.05, 8.0), m["red_plaza"])
	_box(root, Vector3(PARK_GATE_U, 0.03, 4.0), Vector3(10.0, 0.05, 8.0), m["red_plaza"])
	var lu: float = lobby_u()
	var u: float = 30.0
	while u < 150.0:
		if absf(u - lu) > 9.0:
			_box(root, Vector3(u, 0.05, 16.5), Vector3(0.12, 0.02, 5.0), m["line"])
		u += 2.6
	# MÁI CHE RĂNG CƯA dài dọc mặt trước
	var seg: float = 4.0
	var zz: float = 22.0
	while zz < 148.0:
		if absf(zz - lu) > 8.0:
			_prism(root, Vector3(zz, 3.3, 8.5), Vector3(seg, 1.6, 3.6), m["white"], 0.5, 90.0)
			_cyl(root, Vector3(zz - seg * 0.5 + 0.2, 1.4, 7.2), 0.08, 0.08, 2.8, m["steel"])
			_cyl(root, Vector3(zz - seg * 0.5 + 0.2, 1.4, 9.8), 0.08, 0.08, 2.8, m["steel"])
		zz += seg
	u = -4.0
	var k: int = 0
	while u < PLOT_U + 6.0:
		var skip: bool = absf(u - MAIN_GATE_U) < 8.0 or absf(u - PARK_GATE_U) < 8.0
		if not skip:
			if k % 2 == 0:
				build_royal_palm(root, Vector3(u, 0.0, 3.0), m, 7.0 + float(k % 3))
			else:
				build_tropical_tree(root, Vector3(u, 0.0, 4.2), m, 0.9 + 0.1 * float(k % 3), k)
		u += 9.0
		k += 1
	for i: int in range(9):
		var lx: float = -4.0 + i * 23.0
		_cyl(root, Vector3(lx, 2.2, -4.6), 0.07, 0.1, 4.4, m["steel"])
		_sphere(root, Vector3(lx, 4.55, -4.6), 0.28, m["lamp"])

static func _build_ring_building(root: Node3D, m: Dictionary) -> void:
	var u_a: float = RING_U0 + SIDE_D
	var u_b: float = RING_U1 - SIDE_D
	var v_front: float = RING_V0 + LONG_D * 0.5
	var v_back: float = RING_V1 - LONG_D * 0.5
	build_module_wing(root, Vector3(u_a, 0.0, v_front), Vector3(u_b, 0.0, v_front), LONG_D, [5, 5, 5, 5, 5, 5], m, -1.0, LOBBY_MODULE, true, _opt("open_front_modules", []))
	build_module_wing(root, Vector3(u_a, 0.0, v_back), Vector3(u_b, 0.0, v_back), LONG_D, [5, 5, 5, 5, 5, 5], m, 1.0, BACK_GAP_MODULE, true, _opt("open_back_modules", []))
	var u_l: float = RING_U0 + SIDE_D * 0.5
	var u_r: float = RING_U1 - SIDE_D * 0.5
	build_module_wing(root, Vector3(u_l, 0.0, RING_V0), Vector3(u_l, 0.0, RING_V1), SIDE_D, [6, 8, 8, 6], m, 1.0)
	build_module_wing(root, Vector3(u_r, 0.0, RING_V0), Vector3(u_r, 0.0, RING_V1), SIDE_D, [6, 8, 8, 6], m, -1.0)

	var lu: float = lobby_u()
	var bu: float = back_gap_u()
	_label(root, Vector3(lu, FLOOR_H + 1.6, RING_V0 - 0.5), "SẢNH CHÍNH – TRƯỜNG ĐẠI HỌC FPT TP.HCM", 24, Color.WHITE, 180.0)
	_label(root, Vector3(lu, FLOOR_H + 1.6, RING_V0 + LONG_D + 0.5), "SẢNH CHÍNH – ATRIUM", 24, Color.WHITE, 0.0)
	_label(root, Vector3(bu, FLOOR_H + 1.6, RING_V1 + 0.5), "LỐI VÀO SAU – CĂN TIN E2A & 7-ELEVEN", 22, Color.WHITE, 0.0)
	var mat_hall := _tex_mat("fptu_campus_hall_atrium.png", Color("#DDDDDD"), false, Vector3.ONE, 0.7)
	_box(root, Vector3(lu + 9.5, 2.2, RING_V0 + LONG_D + 0.6), Vector3(9.0, 3.2, 0.2), mat_hall)
	_label(root, Vector3(lu + 9.5, 4.2, RING_V0 + LONG_D + 0.8), "ATRIUM HALL (ẢNH CHỤP THỰC TẾ)", 13, Color.WHITE)
	var mat_se := _tex_mat("seven_eleven_sign.png", Color("#2ECC71"), false, Vector3.ONE, 0.5)
	mat_se.emission_enabled = true
	mat_se.emission = Color(0.6, 0.6, 0.6)
	mat_se.emission_texture = mat_se.albedo_texture
	var v_back_face: float = RING_V1 + 0.25
	_quad(root, Vector3(bu - 12.0, 3.0, v_back_face), Vector2(7.0, 1.4), mat_se, 0.0)
	_label(root, Vector3(bu - 12.0, 4.1, v_back_face + 0.1), "7-ELEVEN FPTU CAMPUS · CANTEEN E2A", 16, Color.WHITE, 0.0)
	_box(root, Vector3(bu - 12.0, 1.3, RING_V1 + 0.08), Vector3(5.0, 2.4, 0.12), m["glass"])
	# Passio Coffee – kiosk nhỏ trong sân trong gần hồ
	_box(root, Vector3(127.0, 1.6, 44.0), Vector3(7.0, 3.2, 5.0), m["white"])
	_col_box(root, Vector3(127.0, 1.6, 44.0), Vector3(7.0, 3.2, 5.0))
	_box(root, Vector3(127.0, 1.2, 46.55), Vector3(5.0, 2.0, 0.1), m["glass"])
	_box(root, Vector3(127.0, 3.5, 44.0), Vector3(7.6, 0.3, 5.6), m["roof"])
	_label(root, Vector3(127.0, 4.2, 46.6), "PASSIO COFFEE FPT", 20, Color("#E67E22"), 0.0)

	_build_external_stair(root, m)

## Lan can kính + tay vịn thép dọc một đoạn thang/chiếu nghỉ (a -> b theo trục X, cùng STAIR_V).
static func _stair_rail(root: Node3D, a: Vector3, b: Vector3, m: Dictionary, sides: Array = [-1.0, 1.0]) -> void:
	var d: Vector3 = b - a
	var slen: float = d.length()
	if slen < 0.05:
		return
	var ang: float = rad_to_deg(atan2(d.y, d.x))
	var mid: Vector3 = (a + b) * 0.5
	for sz: float in sides:
		var zpos: float = STAIR_V + sz * (STAIR_W * 0.5 - 0.06)
		var rail := _box(root, Vector3(mid.x, mid.y + 1.05, zpos), Vector3(slen, 0.08, 0.08), m["steel"])
		rail.rotation_degrees.z = ang
		var glass := _box(root, Vector3(mid.x, mid.y + 0.55, zpos), Vector3(slen, 0.9, 0.04), m["glass"])
		glass.rotation_degrees.z = ang
	var n_post: int = maxi(1, int(slen / 2.2))
	for i: int in range(n_post + 1):
		var t: float = float(i) / float(n_post)
		var p: Vector3 = a.lerp(b, t)
		for sz: float in sides:
			_cyl(root, Vector3(p.x, p.y + 0.55, STAIR_V + sz * (STAIR_W * 0.5 - 0.06)), 0.03, 0.03, 1.1, m["steel"])

## CẦU THANG NGOÀI TRỜI TRẮNG ôm mặt ngoài cánh trước: 3 đợt × 35 bậc thật (17 cm) + 2 chiếu nghỉ,
## dầm chéo bê tông dưới thang, lan can kính; đỉnh thang = sân nhỏ + CỬA LAB 402 trên mặt cánh phải (lầu 4).
static func _build_external_stair(root: Node3D, m: Dictionary) -> void:
	var prof: Array[Vector3] = stair_profile()
	var mat_tread := _mat(Color("#E8EAED"), 0.6)
	var mat_nosing := _mat(Color("#F37021"), 0.5, 0.0, 0.25)
	for i: int in range(prof.size() - 1):
		var a: Vector3 = prof[i]
		var b: Vector3 = prof[i + 1]
		var run: float = b.x - a.x
		var rise: float = b.y - a.y
		if rise > 0.01:
			var n: int = maxi(1, int(round(rise / 0.17)))
			var h: float = rise / float(n)
			var dd: float = run / float(n)
			for k: int in range(n):
				var cx: float = a.x + (float(k) + 0.5) * dd
				var cy: float = a.y + (float(k) + 0.5) * h
				_box(root, Vector3(cx, cy, STAIR_V), Vector3(dd + 0.01, h, STAIR_W), mat_tread)
				_box(root, Vector3(cx + dd * 0.5 - 0.03, cy + h * 0.5 + 0.006, STAIR_V), Vector3(0.06, 0.012, STAIR_W - 0.1), mat_nosing)
			var slen: float = sqrt(run * run + rise * rise)
			var soffit := _box(root, Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5 - 0.22, STAIR_V), Vector3(slen, 0.4, STAIR_W + 0.1), m["white"])
			soffit.rotation_degrees.z = rad_to_deg(atan2(rise, run))
		else:
			_box(root, Vector3((a.x + b.x) * 0.5, a.y - 0.2, STAIR_V), Vector3(run + 0.02, 0.4, STAIR_W + 0.1), m["white"])
			_box(root, Vector3((a.x + b.x) * 0.5, a.y + 0.08, STAIR_V), Vector3(run - 0.2, 0.16, STAIR_W - 0.3), m["lawn_small"])
			for sz: float in [-1.0, 1.0]:
				_cyl(root, Vector3((a.x + b.x) * 0.5, (a.y - 0.4) * 0.5, STAIR_V + sz * (STAIR_W * 0.5 - 0.3)), 0.22, 0.26, maxf(0.5, a.y - 0.4), m["white"])
		_stair_rail(root, a, b, m)
	# Sân nhỏ trên đỉnh thang (nối sang cửa Lab 402) + trụ đỡ
	var st: Vector3 = prof[prof.size() - 1]
	var door: Vector3 = lab402_door()
	var land_x0: float = st.x
	var land_x1: float = door.x + 2.4
	var land_cx: float = (land_x0 + land_x1) * 0.5
	_box(root, Vector3(land_cx, st.y - 0.2, STAIR_V + 0.3), Vector3(land_x1 - land_x0, 0.4, STAIR_W + 1.0), m["white"])
	_box(root, Vector3(land_cx, st.y - 0.55, STAIR_V - STAIR_W * 0.5 - 0.1), Vector3(land_x1 - land_x0, 0.5, 0.3), m["terracotta"])
	_stair_rail(root, Vector3(land_x0, st.y, STAIR_V), Vector3(land_x1, st.y, STAIR_V), m, [-1.0])
	for fx: float in [0.3, 0.72]:
		var px: float = lerpf(land_x0, land_x1, fx)
		_cyl(root, Vector3(px, (st.y - 0.4) * 0.5, STAIR_V - 1.3), 0.3, 0.36, st.y - 0.4, m["white"])
	# Cửa Lab 402 (khung đá + cánh cửa xanh phát sáng) + bảng ảnh sảnh atrium cạnh cửa
	_box(root, Vector3(door.x, st.y + 1.85, RING_V0 + 0.1), Vector3(3.8, 3.9, 0.2), m["granite"])
	_box(root, Vector3(door.x, st.y + 1.7, RING_V0 - 0.05), Vector3(3.2, 3.4, 0.14), _mat(Color("#2ECC71"), 0.4, 0.0, 0.9))
	_box(root, Vector3(door.x, st.y + 3.9, RING_V0 - 0.05), Vector3(4.6, 0.6, 0.16), m["orange"])
	_label(root, Vector3(door.x, st.y + 4.8, RING_V0 - 0.25), "🚪 PHÒNG LAB 402 – KỸ THUẬT PHẦN MỀM\n[FAP SLOT 1 – 07:30 AM]", 24, Color.WHITE, 180.0)
	var mat_hall := _tex_mat("fptu_campus_hall_atrium.png", Color("#DDDDDD"), false, Vector3.ONE, 0.7)
	_box(root, Vector3(door.x + 4.8, st.y + 1.7, RING_V0 - 0.02), Vector3(4.0, 2.6, 0.16), mat_hall)
	_label(root, Vector3(door.x + 4.8, st.y + 3.3, RING_V0 - 0.2), "ATRIUM HALL FPTU (ẢNH CHỤP THỰC TẾ)", 12, Color.WHITE, 180.0)
	var sf: Vector3 = prof[0]
	_label(root, Vector3(sf.x - 2.0, 2.6, STAIR_V - 2.6), "⬆ CẦU THANG NGOÀI TRỜI → LẦU 4 (LAB 402)", 16, Color("#F1C40F"), 180.0)

static func _build_courtyard(root: Node3D, m: Dictionary) -> void:
	var u0: float = RING_U0 + SIDE_D
	var u1: float = RING_U1 - SIDE_D
	var v0: float = RING_V0 + LONG_D
	var v1: float = RING_V1 - LONG_D
	var mid_u: float = (u0 + u1) * 0.5
	var cv: float = (v0 + v1) * 0.5
	var dv: float = v1 - v0
	_box(root, Vector3((u0 + mid_u) * 0.5, 0.03, cv), Vector3(mid_u - u0, 0.06, dv), m["paving"])
	_box(root, Vector3((mid_u + u1) * 0.5, 0.03, cv), Vector3(u1 - mid_u, 0.06, dv), m["grass"])
	# HỒ SEN hình thận (2 vòng tròn giao nhau) – nằm trong nửa cỏ, tránh trục lối đi sau
	var pond_c := Vector3(mid_u + 11.0, 0.08, cv + 3.0)
	var lobe_off := Vector3(6.0, 0.0, 6.0)
	_cyl(root, pond_c, 7.5, 7.5, 0.16, m["water"])
	_cyl(root, pond_c + lobe_off, 5.5, 5.5, 0.16, m["water"])
	_torus(root, pond_c + Vector3(0.0, 0.14, 0.0), 7.45, 7.95, m["granite"])
	_torus(root, pond_c + lobe_off + Vector3(0.0, 0.14, 0.0), 5.45, 5.95, m["granite"])
	_col_cyl(root, pond_c + Vector3(0.0, 0.3, 0.0), 7.5, 0.6)
	_col_cyl(root, pond_c + lobe_off + Vector3(0.0, 0.3, 0.0), 5.5, 0.6)
	for i: int in range(12):
		var ang: float = i * TAU / 12.0
		var rad: float = 2.0 + float(i % 3) * 1.8
		var lp: Vector3 = pond_c + Vector3(cos(ang) * rad, 0.12, sin(ang) * rad)
		_cyl(root, lp, 0.6, 0.6, 0.05, m["leaf2"])
		if i % 3 == 0:
			_sphere(root, lp + Vector3(0.0, 0.25, 0.0), 0.2, _mat(Color("#FF9FF3"), 0.8))
	var tree_pts: Array = [Vector2(89.0, 50.0), Vector2(124.0, 39.0), Vector2(128.0, 66.0), Vector2(118.0, 66.5), Vector2(89.0, 67.0), Vector2(121.0, 48.0), Vector2(130.0, 56.0)]
	for i: int in range(tree_pts.size()):
		var tp: Vector2 = tree_pts[i]
		build_tropical_tree(root, Vector3(tp.x, 0.0, tp.y), m, 0.8, 400 + i)
	_box(root, Vector3(mid_u, 0.04, cv), Vector3(3.0, 0.05, dv), m["red_path"])
	_box(root, Vector3(lobby_u(), 0.04, cv), Vector3(5.0, 0.05, dv), m["red_path"])
	_box(root, Vector3(back_gap_u(), 0.04, cv), Vector3(5.0, 0.05, dv), m["red_path"])
	var toad := Vector3(lobby_u() + 8.0, 0.0, v0 + 7.0)
	_cyl(root, toad + Vector3(0.0, 0.7, 0.0), 1.6, 2.0, 1.4, m["granite"])
	_col_cyl(root, toad + Vector3(0.0, 0.7, 0.0), 2.0, 1.4)
	_sphere(root, toad + Vector3(0.0, 2.2, 0.0), 1.2, m["gold"])
	_sphere(root, toad + Vector3(0.0, 3.3, 0.6), 0.75, m["gold"])
	for sx: float in [-1.0, 1.0]:
		_sphere(root, toad + Vector3(sx * 0.5, 3.7, 1.2), 0.2, m["dark"])
	_label(root, toad + Vector3(0.0, 4.6, 0.0), "LINH VẬT CÓC VÀNG FPTU", 22, Color("#FFD32A"), 0.0, true)
	var mat_vtn := _tex_mat("fptu_vtn_architecture_plaque.png", Color("#DDDDDD"), false, Vector3.ONE, 0.7)
	_box(root, Vector3(u0 + 10.0, 1.8, v0 + 2.5), Vector3(2.4, 2.4, 0.15), mat_vtn)
	_label(root, Vector3(u0 + 10.0, 3.4, v0 + 2.6), "VTN ARCHITECTS – KTS VÕ TRỌNG NGHĨA", 15, Color("#2ECC71"))
	var mat_stu := _tex_mat("fptu_student_activities_billboard.png", Color("#DDDDDD"), false, Vector3.ONE, 0.7)
	_box(root, Vector3(u1 - 12.0, 2.0, v0 + 2.5), Vector3(3.6, 2.4, 0.15), mat_stu)
	_label(root, Vector3(u1 - 12.0, 3.5, v0 + 2.6), "HOẠT ĐỘNG SINH VIÊN FPTU (ẢNH CHỤP THẬT)", 14, Color("#F37021"))
	for i: int in range(4):
		_box(root, Vector3(u0 + 8.0 + i * 11.0, 0.3, v1 - 3.0), Vector3(1.8, 0.1, 0.5), m["granite"])
		_box(root, Vector3(u0 + 8.0 + i * 11.0, 0.12, v1 - 3.0), Vector3(1.6, 0.24, 0.4), m["granite"])
	for lp: Vector2 in [Vector2(52.0, 53.0), Vector2(72.0, 53.0), Vector2(118.0, 40.0), Vector2(118.0, 66.0)]:
		_cyl(root, Vector3(lp.x, 2.5, lp.y), 0.07, 0.1, 5.0, m["steel"])
		_sphere(root, Vector3(lp.x, 5.2, lp.y), 0.3, m["lamp"])

static func _build_back_facilities(root: Node3D, m: Dictionary) -> void:
	# Sân bóng mini 5 người góc Đông
	_box(root, Vector3(28.0, 0.02, 101.0), Vector3(38.0, 0.05, 22.0), m["pitch"])
	_box(root, Vector3(28.0, 0.05, 101.0), Vector3(38.0, 0.02, 0.2), m["line"])
	_box(root, Vector3(28.0, 0.05, 101.0), Vector3(0.2, 0.02, 22.0), m["line"])
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(28.0 + sx * 18.8, 0.05, 101.0), Vector3(0.2, 0.02, 22.0), m["line"])
		_box(root, Vector3(28.0 + sx * 18.5, 1.1, 101.0), Vector3(0.1, 2.2, 5.0), m["white"])
	_cyl(root, Vector3(28.0, 0.05, 101.0), 4.0, 4.0, 0.02, m["line"])
	_cyl(root, Vector3(28.0, 0.06, 101.0), 3.8, 3.8, 0.02, m["pitch"])
	for sz: float in [-1.0, 1.0]:
		_box(root, Vector3(28.0, 2.0, 101.0 + sz * 11.5), Vector3(38.0, 4.0, 0.05), m["glass"])
		_col_box(root, Vector3(28.0, 2.0, 101.0 + sz * 11.5), Vector3(38.0, 4.0, 0.3))
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(28.0 + sx * 19.3, 2.0, 101.0), Vector3(0.05, 4.0, 23.0), m["glass"])
		_col_box(root, Vector3(28.0 + sx * 19.3, 2.0, 101.0), Vector3(0.3, 4.0, 23.0))

	# BÃI XE MÁY SINH VIÊN: 2 dãy mái tôn song song, làn xe chạy giữa (v = PARK_LANE_V)
	var gaps: Array = _opt("parking_gaps", [])
	var bu: float = back_gap_u()
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row_v: float in [PARK_ROW_A, PARK_ROW_B]:
		for sx: float in [-1.0, 1.0]:
			for k: int in range(5):
				var pp := Vector3(PARK_CX - 30.0 + k * 15.0, 1.6, row_v + sx * 3.2)
				_cyl(root, pp, 0.1, 0.12, 3.2, m["steel"])
				_col_cyl(root, pp, 0.14, 3.2)
		_prism(root, Vector3(PARK_CX, 3.9, row_v), Vector3(8.0, 1.2, PARK_HALF_LEN * 2.0), m["canopy"], 0.5, 90.0)
		_box(root, Vector3(PARK_CX, 0.015, row_v), Vector3(PARK_HALF_LEN * 2.0 + 4.0, 0.03, 9.4), m["concrete"])
		for r2: float in [-1.8, 1.8]:
			var bx: float = PARK_CX - PARK_HALF_LEN
			while bx <= PARK_CX + PARK_HALF_LEN:
				var bz: float = row_v + r2
				var skip: bool = false
				for g: Variant in gaps:
					var gv: Vector2 = g
					if absf(bx - gv.x) < 2.0 and absf(bz - gv.y) < 1.0:
						skip = true
				# Lối đi bộ từ lối vào sau toà nhà ra làn xe: chừa trống dãy A
				if is_equal_approx(row_v, PARK_ROW_A) and absf(bx - bu) < 2.0:
					skip = true
				if not skip:
					var yaw: float = (0.0 if r2 < 0.0 else PI) + rng.randf_range(-0.08, 0.08)
					var b := Basis.IDENTITY.rotated(Vector3.UP, yaw)
					xforms.append(Transform3D(b, Vector3(bx + rng.randf_range(-0.05, 0.05), 0.0, bz)))
					colors.append(BIKE_PAINTS[rng.randi() % BIKE_PAINTS.size()])
					_col_box(root, Vector3(bx, 0.45, bz), Vector3(0.8, 0.9, 1.8))
				bx += 1.3
	build_motorbike_multimesh(root, xforms, colors, m)
	_box(root, Vector3(bu, 0.03, (RING_V1 + PARK_LANE_V) * 0.5), Vector3(4.0, 0.05, PARK_LANE_V - RING_V1), m["red_path"])
	# Vạch ô đỗ trắng dọc làn + nhãn
	_label(root, Vector3(PARK_CX, 5.6, PARK_ROW_A - 5.0), "BÃI XE MÁY SINH VIÊN – QUÉT THẺ DÂY CAM", 20, Color("#F1C40F"), 180.0)
	_box(root, Vector3(PARK_CX + 14.0, 0.02, PARK_LANE_V), Vector3(PARK_HALF_LEN * 2.0 + 36.0, 0.05, 7.0), m["red_plaza"])
	_box(root, Vector3(PARK_GATE_U, 0.02, 56.0), Vector3(7.0, 0.05, 112.0), m["red_plaza"])
	var vx: float = PARK_CX - PARK_HALF_LEN
	while vx <= PARK_CX + PARK_HALF_LEN:
		for row_v: float in [PARK_ROW_A + 3.6, PARK_ROW_B - 3.6]:
			_box(root, Vector3(vx - 0.65, 0.05, row_v), Vector3(0.08, 0.02, 1.6), m["line"])
		vx += 1.3

static func _build_perimeter_trees(root: Node3D, m: Dictionary) -> void:
	var k: int = 100
	var u: float = -4.0
	while u < PLOT_U + 4.0:
		build_tropical_tree(root, Vector3(u, 0.0, PLOT_V + 1.0), m, 1.1, k)
		u += 14.0
		k += 1
	var v: float = 16.0
	while v < PLOT_V - 4.0:
		build_tropical_tree(root, Vector3(-6.0, 0.0, v), m, 1.0, k)
		build_tropical_tree(root, Vector3(PLOT_U + 6.0, 0.0, v + 6.0), m, 1.0, k + 1)
		v += 16.0
		k += 2

static func _is_lawn(u: float, v: float) -> bool:
	if u < -8.0 or u > PLOT_U + 8.0 or v < 0.8 or v > PLOT_V + 3.0:
		return false
	for r: Variant in _opt("no_grass_rects", []):
		var rr: Rect2 = r
		if rr.has_point(Vector2(u, v)):
			return false
	if absf(u - MAIN_GATE_U) < 7.0 and v < 12.0:
		return false
	if absf(u - PARK_GATE_U) < 4.5:
		return false
	# dải cỏ mặt tiền giữa hàng rào và sân đỏ
	if v >= 0.8 and v <= 6.0:
		return true
	# sân trong nửa cỏ
	var mid_u: float = (RING_U0 + SIDE_D + RING_U1 - SIDE_D) * 0.5
	var v0: float = RING_V0 + LONG_D
	var v1: float = RING_V1 - LONG_D
	if u > mid_u + 1.8 and u < RING_U1 - SIDE_D - 0.5 and v > v0 + 0.5 and v < v1 - 0.5:
		var pc := Vector2(mid_u + 11.0, (v0 + v1) * 0.5 + 3.0)
		if Vector2(u, v).distance_to(pc) < 8.2 or Vector2(u, v).distance_to(pc + Vector2(6.0, 6.0)) < 6.2:
			return false
		if absf(u - back_gap_u()) < 2.6:
			return false
		return true
	# rìa sau & hai bên
	if absf(u - back_gap_u()) < 2.3 and v > RING_V1 and v < PARK_LANE_V:
		return false
	if v > RING_V1 + 1.0:
		if u > 8.0 and u < 48.0 and v > 89.0 and v < 113.0:
			return false
		if u > PARK_CX - PARK_HALF_LEN - 2.0 and u < PARK_CX + PARK_HALF_LEN + 20.0 and v > 88.0 and v < 112.0:
			return false
		return true
	if (u < RING_U0 - 1.0 or u > RING_U1 + 1.0) and v > RING_V0 - 1.0 and v < RING_V1 + 1.0:
		return true
	return false

static func _build_grass(root: Node3D, m: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	var xforms: Array[Transform3D] = []
	var tries: int = 0
	while xforms.size() < 14000 and tries < 90000:
		tries += 1
		var u: float = rng.randf_range(-8.0, PLOT_U + 8.0)
		var v: float = rng.randf_range(0.8, PLOT_V + 3.0)
		if not _is_lawn(u, v):
			continue
		var s: float = rng.randf_range(0.7, 1.35)
		var b := Basis.IDENTITY.rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		xforms.append(Transform3D(b, Vector3(u, 0.27 * s, v)))
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(0.75, 0.55)
	qm.material = m["grass_blades"]
	mm.mesh = qm
	mm.instance_count = xforms.size()
	for i: int in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

# ===========================================================================
# ĐOẠN ĐƯỜNG D1 & HUTECH ĐỐI DIỆN (dùng cho Màn 2; Màn 1 có RoadManager dựng đường riêng)
# ===========================================================================
## Đoạn đường D1 thẳng theo +X tại z_center, từ x0 đến x1, rộng 15 m; mặt nhựa ở cao độ y_top.
## Chỉ dựng bó vỉa + vỉa hè phía đối diện (-Z) vì phía campus đã có vỉa hè riêng.
static func build_d1_road_piece(parent: Node3D, z_center: float, x0: float, x1: float, m: Dictionary, y_top: float = 0.0) -> Node3D:
	var road := Node3D.new()
	road.name = "D1RoadPiece"
	parent.add_child(road)
	var len_x: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	_box(road, Vector3(cx, y_top - 0.125, z_center), Vector3(len_x, 0.25, 15.0), m["asphalt"])
	_box(road, Vector3(cx, y_top + 0.01, z_center), Vector3(len_x, 0.02, 0.36), m["yellow_line"])
	for sz: float in [-1.0, 1.0]:
		_box(road, Vector3(cx, y_top + 0.01, z_center + sz * 6.5), Vector3(len_x, 0.02, 0.15), m["line"])
	_box(road, Vector3(cx, y_top + 0.12, z_center - 7.45), Vector3(len_x, 0.3, 0.3), m["granite"])
	_box(road, Vector3(cx, y_top + 0.09, z_center - 10.3), Vector3(len_x, 0.18, 5.4), m["sidewalk"])
	# Vạch đứt phân làn
	var dx: float = x0 + 2.0
	while dx < x1 - 2.0:
		for sz: float in [-1.0, 1.0]:
			_box(road, Vector3(dx, y_top + 0.01, z_center + sz * 3.3), Vector3(3.0, 0.02, 0.15), m["line"])
		dx += 9.0
	return road

## Viện Công nghệ cao HUTECH đối diện FPT (khối kính tối màu lam trắng dọc + cổng xanh/vàng), origin = tim cổng.
static func build_hutech(parent: Node3D, origin: Vector3, m: Dictionary, colliders: bool = false) -> Node3D:
	var prev_opts: Dictionary = _opts
	_opts = {"colliders": colliders}
	var campus := Node3D.new()
	campus.name = "HUTECH_HiTechPark"
	campus.position = origin
	parent.add_child(campus)
	var mat_blue := _mat(Color("#0055A5"), 0.35)
	var mat_gold := _mat(Color("#FFD100"), 0.5)
	var mat_dark := _mat(Color("#1B2631"), 0.25, 0.45)
	var mat_sign := _tex_mat("hutech_sign.png", Color("#0055A5"), false, Vector3.ONE, 0.6)
	# Cổng
	for sx: float in [-1.0, 1.0]:
		_box(campus, Vector3(sx * 10.0, 3.75, 0.0), Vector3(2.4, 7.5, 2.4), mat_blue)
		_col_box(campus, Vector3(sx * 10.0, 3.75, 0.0), Vector3(2.4, 7.5, 2.4))
	_quad(campus, Vector3(0.0, 6.2, 1.25), Vector2(20.0, 4.4), mat_sign, 0.0)
	# Toà chính 8 tầng kính tối + lam trắng dọc + nẹp sàn trắng
	_box(campus, Vector3(0.0, 14.0, -26.0), Vector3(64.0, 28.0, 24.0), mat_dark)
	_col_box(campus, Vector3(0.0, 14.0, -26.0), Vector3(64.0, 28.0, 24.0))
	var fx: float = -31.0
	while fx <= 31.0:
		_box(campus, Vector3(fx, 14.0, -13.6), Vector3(0.35, 26.5, 1.1), m["white"])
		fx += 2.4
	for sx: float in [-1.0, 1.0]:
		var fz: float = -37.0
		while fz <= -15.0:
			_box(campus, Vector3(sx * 32.4, 14.0, fz), Vector3(1.1, 26.5, 0.35), m["white"])
			fz += 2.4
	for floor_idx: int in range(0, 9):
		_box(campus, Vector3(0.0, floor_idx * 3.4 + 0.3, -26.0), Vector3(64.6, 0.3, 24.6), m["white"])
	_box(campus, Vector3(0.0, 29.6, -13.8), Vector3(22.0, 2.6, 0.5), mat_gold)
	_label(campus, Vector3(0.0, 29.6, -13.4), "HUTECH", 70, Color("#0055A5"), 0.0)
	_label(campus, Vector3(0.0, 9.0, -13.3), "VIỆN CÔNG NGHỆ CAO HUTECH – KHU CÔNG NGHỆ CAO TP.HCM", 30, Color("#FFD100"), 0.0)
	# Khối Viện CNC 3 tầng (kéo dài mặt tiền) + khối nghiên cứu trắng
	_box(campus, Vector3(-90.0, 5.5, -20.0), Vector3(44.0, 11.0, 18.0), m["white"])
	_col_box(campus, Vector3(-90.0, 5.5, -20.0), Vector3(44.0, 11.0, 18.0))
	for floor_idx: int in range(3):
		_box(campus, Vector3(-90.0, floor_idx * 3.5 + 2.2, -10.8), Vector3(42.0, 1.5, 0.4), m["glass"])
	_label(campus, Vector3(-90.0, 12.0, -10.6), "VIỆN CÔNG NGHỆ CAO HUTECH – KHU E1", 34, Color("#FFD100"), 0.0)
	_box(campus, Vector3(-48.0, 10.0, -24.0), Vector3(28.0, 20.0, 20.0), m["white"])
	_col_box(campus, Vector3(-48.0, 10.0, -24.0), Vector3(28.0, 20.0, 20.0))
	# Vỉa hè + cây sau vỉa hè
	_box(campus, Vector3(-25.0, 0.14, 2.9), Vector3(170.0, 0.28, 5.2), m["sidewalk"])
	for x_offset: float in [-110.0, -70.0, -35.0, -18.0, 18.0, 35.0]:
		build_tropical_tree(campus, Vector3(x_offset, 0.0, -4.0), m, 1.0, 700 + int(x_offset))
	_opts = prev_opts
	return campus
