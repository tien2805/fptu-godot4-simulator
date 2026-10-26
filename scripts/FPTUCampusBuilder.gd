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
# Hệ toạ độ cục bộ: X = dọc D1 (u, 0 ở góc Đông Nam lô đất, tăng theo chiều xe chạy về Tây Bắc), Z = chiều sâu
# (v, 0 ở ranh giới giáp vỉa hè, tăng về Đông Bắc vào trong lô), Y lên. Mặt đường D1 ở phía -Z (tim đường tại v = -13).
#
# v8 (2026-10-22, "real map"): kích thước & vị trí lấy từ assets/data/mapdata.json (OSM, xem docs/superpowers/plans/
# 2026-10-22-real-map-world.md, Task 4). Trong hệ cục bộ (gốc = góc ĐN lô, quay 136° quanh Y so với hệ thế giới):
#   - Lô đất: mặt tiền D1 188 m (PLOT_U = 190), sâu 123 m ở đầu ĐN / 107 m ở đầu Tây (lô hình thang) -> PLOT_V = 116
#     (giá trị trung bình; 4 góc hình chữ nhật cách đỉnh lô thật < 12 m, xem tests/test_campus_real.gd).
#   - Cổng chính (node entrance OSM) ở u = 7 ngay góc ĐN; cổng tây (entrance thứ 2) ở u = 181 gần góc Tây; cả hai trên D1.
#     Cổng sau (BACK_GATE_U, v = PLOT_V) mở ra dải bãi xe phía sau (hotspot Màn 2 của thế giới mở).
#   - Vòng nhà thật: mép ngoài u 15..176 × v 15.5..83 (phình tới 95.7 ở giữa cánh sau); sân trong u 39..144 × v 30..72
#     (phình tới 80.6). Mô hình: mép ngoài RING_* = u 14..175 × v 16..93, cánh đầu 28 m, cánh dài 14 m
#     -> SÂN TRONG 105 × 49 m (ring_courtyard_rect(); kế hoạch yêu cầu 100..110 × 48..52).
#   - Bãi xe máy thật: dải 128 × 12 m dọc mép sau (u 58..186, v ≈ 101..113) -> 2 dãy mái + làn giữa tại v 94..113.
#   - Sân bóng mini thật 42 × 22 m ở góc sau phía ĐN (tâm u 34.5, v 103) -> pitch_center_local().
#   - HUTECH thật: khối chính u 89..183 × v −72..−104, cổng trên hàng rào v ≈ −46 -> hutech_origin_local().
#   real_plot_transform(): Transform3D đưa hệ cục bộ lên hệ thế giới (x đông, z nam, gốc = trọng tâm campus).
#
# opts (Dictionary) cho build_authentic_campus:
#   "colliders": bool        – tạo StaticBody3D cho nhà, xe, cây, rào, hồ (Màn 2 cần cho xe máy)
#   "walk_colliders": bool   – (cần "colliders") thêm va chạm cho các tấm lát nhô cao đi lên được: vỉa hè mặt tiền,
#                              bó vỉa đá, thảm đỏ ở hai cổng (mặc định false: 7 màn chơi giữ nguyên; FreeRoam bật)
#   "parking_gaps": Array[Vector2(u, v)] – chừa trống các ô đỗ xe trong bãi
#   "skip_barrier_at": float – không dựng thanh barie ở cổng u này (màn tự điều khiển barie)
#   "grass": bool            – cỏ billboard MultiMesh (mặc định true)
#   "no_grass_rects": Array[Rect2(u, v, w, h)] – vùng không rải cỏ (sân hiên căn tin...)
#   "open_front_modules" / "open_back_modules": Array[int] – module tầng trệt để TRỐNG làm sảnh/căn tin
#       (không khối mặt tiền, có cột tròn, sàn gạch, đèn trần, vách kính phía ngoài)
#   "palms": bool            – phong cách Vice City (plan VC-2; nơi gọi tự đọc art_style, builder này không đọc): cau vua
#                              sân trước thành cọ v2 (PropBuilder.build_palm) + hai hàng cọ Đường D1 (PalmField MultiMesh,
#                              chỉ để nhìn). Mặc định false: cảnh cổ điển giữ nguyên từng node.
#   "d1_palms": bool         – (cần "palms") hai hàng cọ D1, mặc định true; thế giới thật (FreeRoam, Màn 1) đặt false vì
#                              MapBuilder đã dựng Đường D1 thật (và cọ dọc nó) ở chỗ khác hệ toạ độ mô hình
# Tiện ích dùng chung: build_d1_road_piece (đoạn D1 thẳng), build_hutech (HUTECH đối diện, colliders tuỳ chọn),
# build_motorbike / build_motorbike_multimesh (xe máy chi tiết), stair_profile (tuyến cầu thang cho runner).
class_name FPTUCampusBuilder
extends RefCounted

const PLOT_U: float = 190.0
const PLOT_V: float = 116.0
const FLOOR_H: float = 3.6
const TEX_DIR: String = "res://assets/textures/"
const MAIN_GATE_U: float = 7.0          # cổng chính thật: 7 m từ góc ĐN lô, trên D1
const WEST_GATE_U: float = 181.0        # cổng tây thật (campus_west_gate): 7 m từ góc Tây lô, trên D1 – xe máy vào bãi
const PARK_GATE_U: float = WEST_GATE_U  # tên cũ (Màn 2): cổng bãi xe = cổng tây
const WEST_LANE_U: float = 183.0        # tim làn xe 7 m dọc mép Tây lô, từ cổng tây tới bãi xe sau
const BACK_GATE_U: float = 122.0        # cổng sau (hàng rào mép ĐB, v = PLOT_V) mở thẳng ra dải bãi xe
const ROAD_CENTER_V: float = -13.0

# Vị trí lô đất thật trong hệ thế giới (mapdata.json): quay 136° quanh Y (+u chạy từ góc ĐN về Tây Bắc dọc D1,
# +v hướng ĐB vào lô); gốc giải sao cho (MAIN_GATE_U, 0, 0) rơi đúng campus_main_gate. Hằng số dự phòng khi thiếu MapData.
const REAL_ROT_Y_DEG: float = 136.0
const REAL_MAIN_GATE_XZ: Vector2 = Vector2(16.1, 99.5)

# Vòng nhà chữ nhật: RING_* = MÉP NGOÀI toà nhà; sân trong = RING_U0 + SIDE_D .. RING_U1 - SIDE_D × RING_V0 + LONG_D .. RING_V1 - LONG_D
const RING_U0: float = 14.0
const RING_U1: float = 175.0
const RING_V0: float = 16.0
const RING_V1: float = 93.0
const LONG_D: float = 14.0    # độ dày cánh dài (trước/sau)
const SIDE_D: float = 28.0    # độ dày cánh ngắn (hai đầu, khối núi; thật 24 m đầu ĐN / 32 m đầu Tây)
const LINK_W: float = 3.0
const MODULE_NOMINAL_W: float = 14.0  # bề rộng danh định một module lớp học (mô hình giấy) -> suy ra số module cánh dài
const FRONT_MODULES: int = int(((RING_U1 - SIDE_D) - (RING_U0 + SIDE_D) + LINK_W + (MODULE_NOMINAL_W + LINK_W) * 0.5) / (MODULE_NOMINAL_W + LINK_W)) # round(108 / 17) = 6
const SIDE_MODULES: int = 4
const SIDE_MODULE_W: float = ((RING_V1 - RING_V0) - float(SIDE_MODULES - 1) * LINK_W) / float(SIDE_MODULES) # = 17
const LOBBY_MODULE: int = 2   # module thứ 3 cánh trước là sảnh xuyên
const BACK_GAP_MODULE: int = 4 # module thứ 5 cánh sau là lối đi từ bãi xe vào sân

# Bãi xe máy phía sau: dải thật 128 × 12 m dọc mép ĐB (u 58..186, v ≈ 101..113) -> 2 dãy mái 7 m + làn 7 m ở giữa
const PARK_CX: float = 122.0
const PARK_HALF_LEN: float = 56.0      # dãy mái u 66..178 (chừa làn xe mép Tây tại WEST_LANE_U)
const PARK_ROW_A: float = 97.5         # dãy sát lưng toà nhà (mái 94..101)
const PARK_LANE_V: float = 103.5       # làn xe đỏ 7 m (100..107)
const PARK_ROW_B: float = 109.5        # dãy ngoài (mái 106..113)
const PARK_CANOPY_W: float = 7.0

# Sân bóng mini thật 42 × 22 m, góc sau phía ĐN (tâm thật u 34.5, v 103; đặt song song trục u)
const PITCH_CX: float = 35.0
const PITCH_CV: float = 105.0
const PITCH_LEN: float = 42.0
const PITCH_W: float = 22.0

# HUTECH đối diện (footprint thật 94 × 32 m, tâm cách cổng trên hàng rào mặt D1 42 m về phía sau)
const HUTECH_BLOCK_LEN: float = 94.0
const HUTECH_BLOCK_DEPTH: float = 32.0
const HUTECH_BLOCK_OFFSET: float = 42.0

# Cầu thang ngoài trời (mặt ngoài cánh trước, đầu phía cổng bãi xe) -> Lab 402
const STAIR_V: float = 19.4            # (cũ – cầu thang ngoài trời, giữ để tương thích)
const STAIR_RUN: float = 30.5
const STAIR_TOP_Y: float = 17.9
const STAIR_W: float = 5.0
## CẦU THANG TRONG NHÀ (v7): sảnh thông tầng ở module 1–2 cánh phải, thang chạy dọc v từ cửa kính sân trong
## (ATRIUM_DOOR_V, đầu nam module 2) lên chiếu nghỉ đỉnh trong khối link 0/1, cửa Lab 402 mở ở mặt nam module 0, lầu 4.
const STAIR_U: float = RING_U1 - SIDE_D * 0.5 + 3.0   # = 164: trong cánh phải (u 147..175), lệch 3 m về mặt ngoài
const ATRIUM_DOOR_V: float = RING_V0 + 3.0 * SIDE_MODULE_W + 2.0 * LINK_W - 3.6  # tâm lối vào kính module 2 (= 69.4)
const STAIR_FOOT_V: float = ATRIUM_DOOR_V - 2.5
const STAIR_SLOT_HALF: float = 3.0     # nửa bề rộng khe thang trong sàn các tầng
const ATRIUM_MODULES: Array[int] = [1, 2]

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
	var img: Image = _load_image_file(path)
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Đọc PNG/JPG/WebP bằng FileAccess (chạy được trong PCK và trong test --script, không cần autoload GameFX)
static func _load_image_file(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	var ext: String = path.get_extension().to_lower()
	var err: int = ERR_UNAVAILABLE
	match ext:
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
		_:
			err = img.load_png_from_buffer(bytes)
	return img if err == OK else null

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

static var _materials_cache: Dictionary = {}

## Bộ vật liệu campus dùng chung. Được CACHE: màn gọi lại (ngoài lần trong build_authentic_campus) không nạp lại texture.
static func make_materials() -> Dictionary:
	if not _materials_cache.is_empty():
		return _materials_cache
	var m: Dictionary = _materials_cache
	# v7: mặt đứng vẽ bằng code theo mô hình giấy (1 ô = 1 tầng 3,6 m × 14 m, 4 ô cửa). Ảnh chụp thật
	# fptu_alpha_facade.png (sân gạch cam Hòa Lạc) vẫn giữ trong repo cho bảng ảnh, không còn dán lặp lên tường.
	m["facade"] = _tex_mat("fptu_facade_modules.png", Color("#EEEEEA"), true, Vector3(1.0 / 14.0, 1.0 / 3.6, 1.0 / 14.0), 0.82, "fptu_facade_modules_n.png", 0.6)
	m["facade_photo"] = _tex_mat("fptu_alpha_facade.png", Color("#F0F2F4"), false, Vector3.ONE, 0.7)
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
	# ViceStyle: vạch sơn chỉ phát sáng nhẹ ban đêm (ban ngày không quầng); cổ điển giữ emission như cũ
	m["line"].set_meta("night_line", true)
	m["yellow_line"].set_meta("night_line", true)
	m["flag"] = _tex_mat("vietnam_flag.png", Color("#DA251D"), false, Vector3(1.0, 1.0, 1.0), 0.9)
	m["board"] = _tex_mat("fpt_university_board.png", Color("#F37021"), false, Vector3(1.0, 1.0, 1.0), 0.6)
	m["lamp"] = _mat(Color("#FFF3C4"), 0.4, 0.0, 1.2)
	# v7: sảnh trống đồng, sảnh thông tầng, mặt đứng theo mô hình giấy
	m["red_accent"] = _mat(Color("#D9442B"), 0.6)
	m["terrazzo_lobby"] = _tex_mat("fptu_terrazzo_lobby.png", Color("#C9C9C6"), true, Vector3(0.09, 0.09, 0.09), 0.28, "fptu_terrazzo_lobby_n.png", 0.3)
	m["concrete_beam"] = _tex_mat("fptu_concrete_beam.png", Color("#A4A6A3"), true, Vector3(0.5, 0.5, 0.5), 0.9, "fptu_concrete_beam_n.png", 0.5)
	m["graffiti"] = _tex_mat("fptu_graffiti_stair.png", Color("#C42622"), false, Vector3.ONE, 0.75)
	m["bronze"] = _mat(Color("#8C6A3F"), 0.38, 0.85)
	var drum_face: StandardMaterial3D = _tex_mat("fptu_bronze_drum.png", Color("#8C6A3F"), false, Vector3.ONE, 0.4)
	drum_face.metallic = 0.7
	m["bronze_face"] = drum_face
	m["marble"] = _mat(Color("#33363B"), 0.22, 0.15)
	m["black_plinth"] = _mat(Color("#141518"), 0.3, 0.1)
	m["elevator"] = _mat(Color("#9AA4AB"), 0.25, 0.9)
	var glass_clear := _mat(Color(0.78, 0.86, 0.94, 0.28), 0.04, 0.3)
	glass_clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m["glass_clear"] = glass_clear
	m["rail_white"] = _mat(Color("#F7F8F8"), 0.5, 0.2)
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

## Va chạm cho tấm lát nhô cao người đi bộ bước lên được (bậc ≤ 0,35 m của ThirdPersonController): chỉ khi opts
## "walk_colliders" (thế giới mở), để các màn chơi cũ không đổi. Hộp đặt trên mặt đất (đáy y = 0), đỉnh = đỉnh tấm lát
## nhưng tối đa WALK_COL_MAX_TOP: bó vỉa đá cao 0,4 m nằm sát nền đất y = 0 nên va chạm hạ còn 0,32 m để bước qua được.
const WALK_COL_MAX_TOP: float = 0.32

static func _walk_col_box(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	if not bool(_opt("walk_colliders", false)):
		return
	var top: float = minf(pos.y + size.y * 0.5, WALK_COL_MAX_TOP)
	_col_box(parent, Vector3(pos.x, top * 0.5, pos.z), Vector3(size.x, top, size.z))

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
		var kept: Array[Transform3D] = []
		for i: int in range(xforms.size()):
			kept.append(xforms[i] * local)
			mm.set_instance_transform(i, kept[i])
			if is_paint:
				mm.set_instance_color(i, colors[i])
		# instance transforms kept for FreeRoam's cinematic clutter check (headless RenderingServer returns none)
		mm.set_meta("cine_xforms", kept)
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

## Cau vua. Trong build_authentic_campus với opts.palms (phong cách vice) giao cho cây cọ v2 của PropBuilder (cao hơn
## 1,5 m cho khớp dải 8,5..13 m của rừng cọ), collider giữ nguyên như bản cổ điển.
static func build_royal_palm(parent: Node3D, pos: Vector3, m: Dictionary, height: float = 8.0) -> Node3D:
	if bool(_opt("palms", false)):
		var palm: Node3D = PropBuilder.build_palm(parent, pos, height + 1.5, int(pos.x * 7.0 + pos.z * 13.0))
		_col_cyl(palm, Vector3(0.0, height * 0.5, 0.0), 0.3, height)
		return palm
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
static func build_module_wing(parent: Node3D, p_start: Vector3, p_end: Vector3, depth: float, profile: Array, m: Dictionary, inner_sign: float = 1.0, gap_module: int = -1, arcade: bool = true, open_modules: Array = [], atrium_modules: Array = [], double_step: bool = false, lobby_module: int = -1) -> Node3D:
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
			var outer_sb: float = setback * 0.5 if double_step else 0.0 # hai đầu nhà: xếp tầng cả mặt ngoài (mô hình giấy)
			var depth_f: float = depth - setback - outer_sb
			var xc: float = -inner_sign * setback * 0.5 + inner_sign * outer_sb * 0.5
			var is_atrium: bool = k in atrium_modules
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
				_exposed_beams(wing, xc, zc, depth_f, module_w + LINK_W, FLOOR_H, m)
				_white_railing(wing, Vector3(inner_x - inner_sign * 0.2, FLOOR_H, zc), module_w, 0.0, m)
			elif f == 0 and k == lobby_module:
				_build_lobby_trong_dong(wing, xc, zc, depth_f, module_w, inner_sign, m)
			elif is_atrium:
				_build_atrium_floor(wing, xc, zc, depth_f, module_w, inner_sign, y0, m, f == 0, f == floors - 1)
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
				# Mặt đứng theo mô hình giấy: tường trắng (texture ảnh thật) + ô cửa khung ĐỎ CAM rải rác, không còn dải kính tối
				var seed_i: int = k * 7 + f * 3
				for sgn: float in [-1.0, 1.0]:
					if is_atrium and sgn == inner_sign:
						continue # mặt sân trong của sảnh thông tầng là tường kính
					var face_x: float = xc + sgn * (depth_f * 0.5 + 0.07)
					var n_acc: int = 2 + (seed_i + (1 if sgn > 0.0 else 0)) % 2
					for a: int in range(n_acc):
						var zz: float = zc - module_w * 0.5 + 1.6 + float((a * 5 + seed_i * 3) % maxi(1, int(module_w - 3.2)))
						var fr: MeshInstance3D = _box(wing, Vector3(face_x, y0 + 2.0, zz), Vector3(0.14, 1.5, 1.3), m["red_accent"])
						fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						var gl: MeshInstance3D = _box(wing, Vector3(face_x + sgn * 0.03, y0 + 2.0, zz), Vector3(0.06, 1.2, 1.0), m["band"])
						gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			if f >= 2:
				var tx: float = inner_x + inner_sign * step * 0.5
				_box(wing, Vector3(tx, y0 + 0.08, zc), Vector3(step, 0.16, module_w - 0.2), m["lawn_small"])

			if f == floors - 1:
				# MÁI BẰNG = SÂN THƯỢNG (mô hình giấy): sàn, tường chắn mái trắng 4 phía, bồn cây xanh dọc 2 mép dài, buồng kỹ thuật
				_box(wing, Vector3(xc, y0 + FLOOR_H + 0.1, zc), Vector3(depth_f + 0.5, 0.2, module_w + 0.3), m["white"])
				for sgn: float in [-1.0, 1.0]:
					var px: float = xc + sgn * (depth_f * 0.5 + 0.12)
					_box(wing, Vector3(px, y0 + FLOOR_H + 0.75, zc), Vector3(0.25, 1.1, module_w + 0.3), m["white"])
					_box(wing, Vector3(px - sgn * 0.75, y0 + FLOOR_H + 0.45, zc), Vector3(1.2, 0.5, module_w - 0.6), m["planter"])
					var zb: float = zc - module_w * 0.5 + 1.0
					while zb <= zc + module_w * 0.5 - 1.0:
						bush_xforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 0.5, 0.55)), Vector3(px - sgn * 0.75, y0 + FLOOR_H + 0.95, zb)))
						zb += 2.0
					_box(wing, Vector3(xc, y0 + FLOOR_H + 0.75, zc + sgn * (module_w * 0.5 + 0.03)), Vector3(depth_f + 0.5, 1.1, 0.25), m["white"])
				if k % 2 == 0:
					_box(wing, Vector3(xc - inner_sign * (depth_f * 0.5 - 2.2), y0 + FLOOR_H + 1.5, zc - module_w * 0.5 + 2.2), Vector3(3.2, 2.6, 3.2), m["white"])

		if k < n - 1:
			var f_link: int = maxi(1, mini(int(profile[k]), int(profile[k + 1])) - 1)
			var zl: float = zc + module_w * 0.5 + LINK_W * 0.5
			var link_d: float = depth - 2.0
			if (k in atrium_modules) and ((k + 1) in atrium_modules):
				# Link giữa 2 module thông tầng: khe thang chạy xuyên → dựng từng tầng rỗng như module
				var f_both: int = mini(int(profile[k]), int(profile[k + 1]))
				for ff: int in range(f_both):
					var sb2: float = 0.0 if ff < 2 else float(ff - 1) * step
					var osb2: float = sb2 * 0.5 if double_step else 0.0
					var dl: float = depth - sb2 - osb2 - 2.0
					var xl: float = -inner_sign * sb2 * 0.5 + inner_sign * osb2 * 0.5
					_build_atrium_floor(wing, xl, zl, dl, LINK_W, inner_sign, float(ff) * FLOOR_H, m, ff == 0, ff == f_both - 1)
				continue
			elif (k in atrium_modules) or ((k + 1) in atrium_modules):
				# Link cạnh module thông tầng (link 0/1 cánh phải): đặc tới dưới chiếu nghỉ đỉnh thang, trên là sân hở
				var top_y: float = STAIR_TOP_Y - 0.2
				_box(wing, Vector3(0.0, top_y * 0.5, zl), Vector3(link_d, top_y, LINK_W), m["white"])
				_col_box(wing, Vector3(0.0, FLOOR_H * 0.5, zl), Vector3(link_d, FLOOR_H, LINK_W))
				_box(wing, Vector3(0.0, STAIR_TOP_Y - 0.1, zl), Vector3(link_d + 0.3, 0.2, LINK_W + 0.1), m["white"])
				_white_railing(wing, Vector3(-inner_sign * (link_d * 0.5 - 0.15), STAIR_TOP_Y, zl), LINK_W, 0.0, m)
				continue
			elif (k in open_modules) or ((k + 1) in open_modules):
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
		mm.set_meta("cine_xforms", bush_xforms)   # FreeRoam's cinematic clutter check (headless too)
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
	return (span - float(FRONT_MODULES - 1) * LINK_W) / float(FRONT_MODULES)

## Số tầng từng module cánh dài: hai đầu cao (6), trũng xuống 4 ở giữa (mô hình giấy [6,5,4,4,5,6] với 6 module).
static func _long_wing_profile() -> Array:
	var prof: Array = []
	for k: int in range(FRONT_MODULES):
		var d: int = mini(k, FRONT_MODULES - 1 - k) # khoảng cách tới đầu gần nhất
		prof.append(maxi(4, 6 - d))
	return prof

## Số tầng từng module cánh đầu (khối núi): 7 ở hai đầu, 8 ở giữa.
static func _side_wing_profile() -> Array:
	var prof: Array = []
	for k: int in range(SIDE_MODULES):
		prof.append(7 if (k == 0 or k == SIDE_MODULES - 1) else 8)
	return prof

## Tâm module k (0-based) của cánh dài, theo u.
static func front_module_u(k: int) -> float:
	var mw: float = _front_module_w()
	return (RING_U0 + SIDE_D) + float(k) * (mw + LINK_W) + mw * 0.5

static func lobby_u() -> float:
	return front_module_u(LOBBY_MODULE)

static func back_gap_u() -> float:
	return front_module_u(BACK_GAP_MODULE)

static func _side_module_w() -> float:
	return SIDE_MODULE_W

## v của đầu nam module 1 cánh phải (= sau khối link 0/1): chiếu nghỉ đỉnh cầu thang trong nhà.
static func stair_top_v() -> float:
	return RING_V0 + _side_module_w() + LINK_W

## Sân trong (mép trong vòng nhà) trong hệ cục bộ: Rect2(u0, v0, dài, sâu) = 105 × 49 m theo dữ liệu thật.
static func ring_courtyard_rect() -> Rect2:
	return Rect2(RING_U0 + SIDE_D, RING_V0 + LONG_D, (RING_U1 - SIDE_D) - (RING_U0 + SIDE_D), (RING_V1 - LONG_D) - (RING_V0 + LONG_D))

## Mép ngoài vòng nhà trong hệ cục bộ.
static func ring_outer_rect() -> Rect2:
	return Rect2(RING_U0, RING_V0, RING_U1 - RING_U0, RING_V1 - RING_V0)

## Lô đất (hình chữ nhật mô hình) trong hệ cục bộ.
static func plot_rect() -> Rect2:
	return Rect2(0.0, 0.0, PLOT_U, PLOT_V)

static func main_gate_local() -> Vector3:
	return Vector3(MAIN_GATE_U, 0.0, 0.0)

static func west_gate_local() -> Vector3:
	return Vector3(WEST_GATE_U, 0.0, 0.0)

static func back_gate_local() -> Vector3:
	return Vector3(BACK_GATE_U, 0.0, PLOT_V)

static func parking_center_local() -> Vector3:
	return Vector3(PARK_CX, 0.0, PARK_LANE_V)

static func pitch_center_local() -> Vector3:
	return Vector3(PITCH_CX, 0.0, PITCH_CV)

## Tâm lối vào kính sảnh thông tầng cánh phải (mặt sân trong, module 2) – điểm rẽ vào cầu thang của Màn 2.
static func atrium_door_local() -> Vector3:
	return Vector3(RING_U1 - SIDE_D, 0.0, ATRIUM_DOOR_V)

# --- Lô đất thật -------------------------------------------------------------
## Transform đưa hệ cục bộ (u, y, v) lên hệ thế giới của mapdata.json (x đông, z nam, gốc = trọng tâm campus):
## quay REAL_ROT_Y_DEG quanh Y, gốc giải sao cho Vector3(MAIN_GATE_U, 0, 0) rơi đúng cổng chính thật.
## Dùng landmark campus_main_gate khi có MapData, không thì hằng số REAL_MAIN_GATE_XZ.
static func real_plot_transform() -> Transform3D:
	var gate: Vector2 = REAL_MAIN_GATE_XZ
	var md: MapData = MapData.load_default()
	if md != null:
		var g: Variant = md.landmark("campus_main_gate")
		if g is Array and (g as Array).size() >= 2:
			gate = Vector2(float(g[0]), float(g[1]))
	return real_plot_transform_from(gate)

## Cùng phép đặt nhưng với toạ độ cổng chính (x, z) cho trước (test / dữ liệu khác).
static func real_plot_transform_from(gate_xz: Vector2) -> Transform3D:
	var basis := Basis(Vector3.UP, deg_to_rad(REAL_ROT_Y_DEG))
	var origin: Vector3 = Vector3(gate_xz.x, 0.0, gate_xz.y) - basis * Vector3(MAIN_GATE_U, 0.0, 0.0)
	return Transform3D(basis, origin)

## Điểm thế giới (x, z) của mapdata -> hệ cục bộ campus (u, y=0, v); dùng hằng số dự phòng khi không có MapData.
static func world_xz_to_local(p: Vector2) -> Vector3:
	return real_plot_transform().affine_inverse() * Vector3(p.x, 0.0, p.y)

## Gốc HUTECH (tim cổng trên hàng rào mặt D1) trong hệ cục bộ campus, suy từ footprint thật `hutech_building`:
## khối chính nằm 26 m sau cổng (như build_hutech), cổng đặt giữa mặt tiền khối. Dự phòng (136, 0, -46).
static func hutech_origin_local() -> Vector3:
	var c: Vector3 = hutech_block_center_local()
	return Vector3(c.x, 0.0, c.z + HUTECH_BLOCK_OFFSET)

## Tâm khối chính HUTECH trong hệ cục bộ campus (từ hutech_building; dự phòng (136, 0, -88)).
static func hutech_block_center_local() -> Vector3:
	var md: MapData = MapData.load_default()
	if md != null:
		var poly: Variant = md.landmark("hutech_building")
		if poly is Array and (poly as Array).size() >= 3:
			var inv: Transform3D = real_plot_transform().affine_inverse()
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for p: Variant in (poly as Array):
				var l: Vector3 = inv * Vector3(float(p[0]), 0.0, float(p[1]))
				lo = Vector2(minf(lo.x, l.x), minf(lo.y, l.z))
				hi = Vector2(maxf(hi.x, l.x), maxf(hi.y, l.z))
			return Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5)
	return Vector3(136.0, 0.0, -88.0)

static func stair_foot() -> Vector3:
	return Vector3(STAIR_U, 0.0, STAIR_FOOT_V)

static func stair_top() -> Vector3:
	return Vector3(STAIR_U, STAIR_TOP_Y, stair_top_v())

## Cửa Lab 402: mặt NAM module 0 cánh phải (v = RING_V0 + module), lầu 4 – ngay sau chiếu nghỉ đỉnh thang trong nhà.
static func lab402_door() -> Vector3:
	return Vector3(STAIR_U, STAIR_TOP_Y, RING_V0 + _side_module_w())

## Mặt cắt cầu thang trong nhà: chạy dọc -v, 3 đợt thang + 2 chiếu nghỉ (điểm gấp khúc = tuyến chạy Màn 2).
static func stair_profile() -> Array[Vector3]:
	var sf: Vector3 = stair_foot()
	var z_end: float = stair_top_v()
	var landing: float = 2.5
	var flight: float = (sf.z - z_end - 2.0 * landing) / 3.0
	var rise: float = (STAIR_TOP_Y - sf.y) / 3.0
	var pts: Array[Vector3] = [sf]
	var z: float = sf.z
	var y: float = sf.y
	for i: int in range(3):
		z -= flight
		y += rise
		pts.append(Vector3(STAIR_U, y, z))
		if i < 2:
			z -= landing
			pts.append(Vector3(STAIR_U, y, z))
	return pts

## 3 ô đỗ ứng viên (Màn 2): gần cổng tây nhất (mặt trong dãy B), giữa bãi (mặt trong dãy A), góc xa (mặt ngoài dãy B,
## phải vòng qua đầu mái). Toạ độ suy từ dải bãi xe thật (PARK_CX ± PARK_HALF_LEN).
static func parking_spot_candidates() -> Array[Vector3]:
	return [
		Vector3(PARK_CX + PARK_HALF_LEN - 8.0, 0.0, PARK_ROW_B - 1.8),
		Vector3(PARK_CX, 0.0, PARK_ROW_A + 1.8),
		Vector3(PARK_CX - PARK_HALF_LEN + 6.0, 0.0, PARK_ROW_B + 1.8)
	]

## Bốt bảo vệ cổng tây (xe máy): nằm phía -u của cổng (phía +u là mép lô / làn xe).
static func park_gate_guard_pos() -> Vector3:
	return Vector3(PARK_GATE_U - 9.5, 0.0, 4.5)

## Tâm phòng LAB 402: cánh phải, module 0, tầng 5 (lầu 4) – ngay sau cửa đỉnh cầu thang trong nhà.
## Phòng 14 m (dọc u) × 11.7 m (dọc v) × 3.3 m; cửa sổ phía sân trong (u nhỏ) và phía D1 (v nhỏ);
## tường nam cách mặt nam module 0 (cửa Lab 402) 1,7 m.
static func lab402_room_center() -> Vector3:
	var sz: Vector3 = lab402_room_size()
	return Vector3(STAIR_U - 2.0, STAIR_TOP_Y + 0.15, RING_V0 + _side_module_w() - 1.7 - sz.z * 0.5)

static func lab402_room_size() -> Vector3:
	return Vector3(14.0, 3.3, 11.7)

## Tâm PHÒNG 311: cánh trước, module 4, tầng 3 (lầu 3). Phòng 12 × 10 × 3.3 m; cửa sổ 2 phía (D1 & sân trong).
## Tầng 3 lùi 3,2 m về phía sân trong (setback) nên tâm module lệch 1,6 m về phía D1.
static func room311_center() -> Vector3:
	return Vector3(front_module_u(4), FLOOR_H * 3.0 + 0.05, RING_V0 + LONG_D * 0.5 - 1.6)

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
	_build_gate(root, m, MAIN_GATE_U, true, 1.0)
	_build_gate(root, m, WEST_GATE_U, false, -1.0)
	_build_back_gate(root, m)
	_build_front_plaza(root, m)
	_build_ring_building(root, m)
	_build_courtyard(root, m)
	_build_back_facilities(root, m)
	_build_perimeter_trees(root, m)
	if bool(_opt("grass", true)):
		_build_grass(root, m)
	if bool(_opt("palms", false)) and bool(_opt("d1_palms", true)):
		_build_d1_palms(root)
	_opts = {}
	return root

## Phong cách vice (opts.palms): hai hàng cọ dọc Đường D1 – vỉa hè phía campus (v = -3.2) và dải vỉa hè giữa hai chiều phía
## xa (v = ROAD_CENTER_V - 9) – mỗi 13 m, chừa 9 m quanh cổng chính và cổng tây (look-dev _add_palms_d1). Một PalmField
## MultiMesh, chỉ để nhìn (không collider: bot Màn 2 không vướng).
static func _build_d1_palms(root: Node3D) -> void:
	var pts := PackedVector3Array()
	var u: float = -60.0
	while u < 200.0:
		if absf(u - MAIN_GATE_U) > 9.0 and absf(u - WEST_GATE_U) > 9.0:
			for v: float in [-3.2, ROAD_CENTER_V - 9.0]:
				pts.append(Vector3(u, 0.0, v))
		u += 13.0
	PropBuilder.build_palm_field(root, pts, {"seed": 3000})

static func _build_ground_and_boundary(root: Node3D, m: Dictionary) -> void:
	_box(root, Vector3(PLOT_U * 0.5, -0.06, PLOT_V * 0.5), Vector3(PLOT_U + 10.0, 0.12, PLOT_V + 10.0), m["grass"])
	# Vỉa hè lát gạch + bó vỉa đá; HẠ VỈA HÈ (lối xe lên) tại hai cổng
	var walk_segs: Array = [[-35.0, MAIN_GATE_U - 7.0], [MAIN_GATE_U + 7.0, PARK_GATE_U - 7.0], [PARK_GATE_U + 7.0, PLOT_U + 35.0]]
	for seg: Array in walk_segs:
		var a: float = float(seg[0])
		var b: float = float(seg[1])
		_box(root, Vector3((a + b) * 0.5, 0.14, -2.7), Vector3(b - a, 0.28, 5.4), m["sidewalk"])
		_walk_col_box(root, Vector3((a + b) * 0.5, 0.14, -2.7), Vector3(b - a, 0.28, 5.4))
		_box(root, Vector3((a + b) * 0.5, 0.2, -5.3), Vector3(b - a, 0.4, 0.3), m["granite"])
		_walk_col_box(root, Vector3((a + b) * 0.5, 0.2, -5.3), Vector3(b - a, 0.4, 0.3))
	for gu: float in [MAIN_GATE_U, PARK_GATE_U]:
		_box(root, Vector3(gu, 0.05, -2.7), Vector3(14.0, 0.1, 5.4), m["red_plaza"])
		_walk_col_box(root, Vector3(gu, 0.05, -2.7), Vector3(14.0, 0.1, 5.4))
		for sx: float in [-1.0, 1.0]:
			_box(root, Vector3(gu + sx * 7.1, 0.2, -5.3), Vector3(0.3, 0.4, 0.3), m["granite"])
			_walk_col_box(root, Vector3(gu + sx * 7.1, 0.2, -5.3), Vector3(0.3, 0.4, 0.3))
	# Hàng rào mặt tiền (tường thấp + hàng rào cây) đúng ranh giới lô 0..PLOT_U, chừa cổng chính & cổng tây
	var gaps: Array = [[MAIN_GATE_U - 6.5, MAIN_GATE_U + 6.5], [WEST_GATE_U - 6.5, WEST_GATE_U + 6.5]]
	var u: float = -0.5
	while u < PLOT_U + 0.5:
		var seg_end: float = minf(u + 6.0, PLOT_U + 0.5)
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
	# Hai hàng rào bên đúng mép lô (lô thật: góc ĐN tại u = 0, góc Tây tại u ≈ 188)
	for side: float in [-0.5, PLOT_U + 0.5]:
		_box(root, Vector3(side, 0.3, PLOT_V * 0.5), Vector3(0.35, 0.6, PLOT_V), m["white"])
		_box(root, Vector3(side + (1.0 if side < 1.0 else -1.0), 0.8, PLOT_V * 0.5), Vector3(0.9, 1.4, PLOT_V - 2.0), m["leaf2"])
		_col_box(root, Vector3(side, 0.8, PLOT_V * 0.5), Vector3(1.6, 1.6, PLOT_V))
	# Hàng rào sau (mép ĐB) chừa cổng sau 11 m tại BACK_GATE_U
	for seg: Array in [[-0.5, BACK_GATE_U - 5.5], [BACK_GATE_U + 5.5, PLOT_U + 0.5]]:
		var a: float = float(seg[0])
		var b: float = float(seg[1])
		_box(root, Vector3((a + b) * 0.5, 0.3, PLOT_V + 0.5), Vector3(b - a, 0.6, 0.35), m["white"])
		_box(root, Vector3((a + b) * 0.5, 1.0, PLOT_V + 0.5), Vector3(b - a, 0.05, 0.4), m["steel"])
		_col_box(root, Vector3((a + b) * 0.5, 0.8, PLOT_V + 0.5), Vector3(b - a, 1.6, 0.6))

## Cổng trên mặt D1 (12 m giữa hai trụ đá). `s` = phía đặt bốt bảo vệ / trụ barie / bảng (+1 = phía +u, -1 = phía -u):
## cổng chính ở góc ĐN nên bốt về phía +u; cổng tây sát góc Tây nên bốt về phía -u (phía +u là làn xe & mép lô).
static func _build_gate(root: Node3D, m: Dictionary, u: float, is_main: bool, s: float = 1.0) -> void:
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(u + sx * 6.0, 2.6, 0.2), Vector3(1.2, 5.2, 1.2), m["granite"])
		_col_box(root, Vector3(u + sx * 6.0, 2.6, 0.2), Vector3(1.2, 5.2, 1.2))
		_box(root, Vector3(u + sx * 6.0, 5.35, 0.2), Vector3(1.6, 0.3, 1.6), m["white"])
	_box(root, Vector3(u, 5.0, 0.2), Vector3(12.4, 1.7, 0.6), m["orange"])
	_quad(root, Vector3(u, 5.0, -0.12), Vector2(12.0, 1.5), m["board"], 180.0)
	if is_main:
		var bu: float = u + s * 23.0
		_box(root, Vector3(bu, 1.3, 1.2), Vector3(11.0, 2.6, 1.0), m["orange"])
		_col_box(root, Vector3(bu, 1.3, 1.2), Vector3(11.0, 2.6, 1.0))
		_label(root, Vector3(bu, 1.45, 0.66), "TRƯỜNG ĐẠI HỌC FPT\nTP. HỒ CHÍ MINH", 30, Color.WHITE, 180.0)
		_label(root, Vector3(bu, 0.45, 0.66), "LÔ E2A-7 · ĐƯỜNG D1 · KHU CÔNG NGHỆ CAO", 13, Color.WHITE, 180.0)
		var mat_map := _tex_mat("fptu_campus_map_billboard.png", Color("#DDDDDD"), false, Vector3.ONE, 0.7)
		_box(root, Vector3(u + s * 33.0, 2.0, 2.4), Vector3(5.6, 3.2, 0.25), mat_map)
		_label(root, Vector3(u + s * 33.0, 3.9, 2.25), "SƠ ĐỒ KHUÔN VIÊN FPTU (ẢNH CHỤP THỰC TẾ)", 14, Color("#F37021"), 180.0)
	else:
		_label(root, Vector3(u, 3.3, -0.3), "🅿 CỔNG BÃI XE D1 – SINH VIÊN QUÉT THẺ", 22, Color.WHITE, 180.0)
	var bx: float = u + s * 9.5
	_box(root, Vector3(bx, 1.6, 4.5), Vector3(3.2, 3.2, 3.0), m["white"])
	_col_box(root, Vector3(bx, 1.6, 4.5), Vector3(3.2, 3.2, 3.0))
	_box(root, Vector3(bx, 2.0, 2.95), Vector3(2.4, 1.1, 0.1), m["glass"])
	_box(root, Vector3(bx, 3.35, 4.5), Vector3(3.8, 0.3, 3.6), m["roof"])
	_cyl(root, Vector3(u + s * 5.2, 0.6, 3.2), 0.12, 0.14, 1.2, m["steel"])
	if absf(float(_opt("skip_barrier_at", -999.0)) - u) > 0.5:
		var arm := _box(root, Vector3(u + s * 2.2, 1.15, 3.2), Vector3(6.0, 0.14, 0.14), m["line"])
		arm.rotation_degrees.z = 4.0 * s
		for i: int in range(5):
			_box(root, Vector3(u + s * (4.6 - i * 1.2), 1.15 + i * 0.08, 3.21), Vector3(0.5, 0.15, 0.15), _mat(Color("#E74C3C"), 0.6))
	if is_main:
		_cyl(root, Vector3(u - s * 3.0, 6.0, 7.0), 0.07, 0.11, 12.0, m["steel"])
		_quad(root, Vector3(u - s * 3.0 + 1.55, 11.1, 7.0), Vector2(3.0, 2.0), m["flag"], 0.0)

## Cổng sau trên hàng rào mép ĐB (v = PLOT_V): hai trụ đá, cánh cổng trượt thép đang mở, bảng tên, đèn.
## Mở thẳng vào dãy B của bãi xe (chừa khe 6 m) -> làn xe giữa bãi. Thế giới mở dùng làm hotspot Màn 2.
static func _build_back_gate(root: Node3D, m: Dictionary) -> void:
	var v: float = PLOT_V + 0.5
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(BACK_GATE_U + sx * 5.5, 2.0, v), Vector3(0.9, 4.0, 0.9), m["granite"])
		_col_box(root, Vector3(BACK_GATE_U + sx * 5.5, 2.0, v), Vector3(0.9, 4.0, 0.9))
		_box(root, Vector3(BACK_GATE_U + sx * 5.5, 4.1, v), Vector3(1.2, 0.25, 1.2), m["white"])
	# cánh cổng trượt (đang mở, đẩy sang phía +u dọc hàng rào)
	var slide_cx: float = BACK_GATE_U + 5.5 + 5.4
	_box(root, Vector3(slide_cx, 1.0, v + 0.45), Vector3(10.4, 1.9, 0.08), m["steel"])
	_col_box(root, Vector3(slide_cx, 1.0, v + 0.45), Vector3(10.4, 1.9, 0.2))
	var gx: float = slide_cx - 5.0
	while gx <= slide_cx + 5.0:
		_box(root, Vector3(gx, 1.0, v + 0.5), Vector3(0.06, 1.9, 0.06), m["dark"])
		gx += 0.5
	_box(root, Vector3(BACK_GATE_U, 3.6, v), Vector3(11.0, 0.7, 0.3), m["orange"])
	_label(root, Vector3(BACK_GATE_U, 3.6, v + 0.2), "CỔNG SAU – BÃI XE MÁY SINH VIÊN", 18, Color.WHITE, 0.0)
	_label(root, Vector3(BACK_GATE_U, 3.6, v - 0.2), "CỔNG SAU – BÃI XE MÁY SINH VIÊN", 18, Color.WHITE, 180.0)
	_cyl(root, Vector3(BACK_GATE_U - 7.5, 2.2, v - 1.0), 0.07, 0.1, 4.4, m["steel"])
	_sphere(root, Vector3(BACK_GATE_U - 7.5, 4.55, v - 1.0), 0.28, m["lamp"])
	# lối xe từ cổng sau qua khe dãy B vào làn giữa bãi
	_box(root, Vector3(BACK_GATE_U, 0.02, (PARK_LANE_V + PLOT_V) * 0.5), Vector3(5.6, 0.05, PLOT_V - PARK_LANE_V), m["red_plaza"])

static func _build_front_plaza(root: Node3D, m: Dictionary) -> void:
	# Sân đỏ (đưa đón / đỗ xe) giữa dải cỏ mặt tiền (v 0.8..6) và mặt trước toà nhà (RING_V0)
	_box(root, Vector3(PLOT_U * 0.5, 0.02, (6.0 + RING_V0) * 0.5), Vector3(PLOT_U - 4.0, 0.05, RING_V0 - 6.0), m["red_plaza"])
	_box(root, Vector3(MAIN_GATE_U, 0.03, 4.0), Vector3(10.0, 0.05, 8.0), m["red_plaza"])
	_box(root, Vector3(WEST_GATE_U, 0.03, 4.0), Vector3(10.0, 0.05, 8.0), m["red_plaza"])
	var lu: float = lobby_u()
	var u: float = RING_U0 + 12.0
	while u < RING_U1 - 12.0:
		if absf(u - lu) > 9.0:
			_box(root, Vector3(u, 0.05, RING_V0 - 3.5), Vector3(0.12, 0.02, 5.0), m["line"])
		u += 2.6
	# MÁI CHE RĂNG CƯA dài dọc mặt trước
	var seg: float = 4.0
	var zz: float = RING_U0 + 8.0
	while zz < RING_U1 - 8.0:
		if absf(zz - lu) > 8.0:
			_prism(root, Vector3(zz, 3.3, RING_V0 - 7.5), Vector3(seg, 1.6, 3.6), m["white"], 0.5, 90.0)
			_cyl(root, Vector3(zz - seg * 0.5 + 0.2, 1.4, RING_V0 - 8.8), 0.08, 0.08, 2.8, m["steel"])
			_cyl(root, Vector3(zz - seg * 0.5 + 0.2, 1.4, RING_V0 - 6.2), 0.08, 0.08, 2.8, m["steel"])
		zz += seg
	u = 2.0
	var k: int = 0
	while u < PLOT_U - 2.0:
		var skip: bool = absf(u - MAIN_GATE_U) < 8.0 or absf(u - WEST_GATE_U) < 8.0
		if not skip:
			if k % 2 == 0:
				build_royal_palm(root, Vector3(u, 0.0, 3.0), m, 7.0 + float(k % 3))
			else:
				build_tropical_tree(root, Vector3(u, 0.0, 4.2), m, 0.9 + 0.1 * float(k % 3), k)
		u += 9.0
		k += 1
	for i: int in range(9):
		var lx: float = 5.0 + i * 22.5
		_cyl(root, Vector3(lx, 2.2, -4.6), 0.07, 0.1, 4.4, m["steel"])
		_sphere(root, Vector3(lx, 4.55, -4.6), 0.28, m["lamp"])

static func _build_ring_building(root: Node3D, m: Dictionary) -> void:
	var u_a: float = RING_U0 + SIDE_D
	var u_b: float = RING_U1 - SIDE_D
	var v_front: float = RING_V0 + LONG_D * 0.5
	var v_back: float = RING_V1 - LONG_D * 0.5
	# v7 (mô hình giấy): hai cánh dài trũng ở giữa, hai đầu nhà xếp tầng cao như núi; sảnh trống đồng ở module 2 cánh trước;
	# sảnh thông tầng + cầu thang trong nhà ở module 1–2 cánh phải (lên Lab 402)
	var long_prof: Array = _long_wing_profile()
	var side_prof: Array = _side_wing_profile()
	build_module_wing(root, Vector3(u_a, 0.0, v_front), Vector3(u_b, 0.0, v_front), LONG_D, long_prof, m, -1.0, -1, true, _opt("open_front_modules", []), [], false, LOBBY_MODULE)
	build_module_wing(root, Vector3(u_a, 0.0, v_back), Vector3(u_b, 0.0, v_back), LONG_D, long_prof, m, 1.0, BACK_GAP_MODULE, true, _opt("open_back_modules", []))
	var u_l: float = RING_U0 + SIDE_D * 0.5
	var u_r: float = RING_U1 - SIDE_D * 0.5
	build_module_wing(root, Vector3(u_l, 0.0, RING_V0), Vector3(u_l, 0.0, RING_V1), SIDE_D, side_prof, m, 1.0, -1, true, [], [], true)
	build_module_wing(root, Vector3(u_r, 0.0, RING_V0), Vector3(u_r, 0.0, RING_V1), SIDE_D, side_prof, m, -1.0, -1, true, [], ATRIUM_MODULES, true)

	var lu: float = lobby_u()
	var bu: float = back_gap_u()
	_label(root, Vector3(lu, FLOOR_H + 1.6, RING_V0 - 0.5), "SẢNH TRỐNG ĐỒNG – TRƯỜNG ĐẠI HỌC FPT TP.HCM", 24, Color.WHITE, 180.0)
	_label(root, Vector3(lu, FLOOR_H + 1.6, RING_V0 + LONG_D + 0.5), "SẢNH TRỐNG ĐỒNG", 24, Color.WHITE, 0.0)
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
	# Passio Coffee – kiosk nhỏ trong nửa cỏ của sân trong, gần hồ
	var court: Rect2 = ring_courtyard_rect()
	var ck := Vector3(court.position.x + court.size.x * 0.5 + 32.0, 0.0, court.position.y + 10.0)
	_box(root, ck + Vector3(0.0, 1.6, 0.0), Vector3(7.0, 3.2, 5.0), m["white"])
	_col_box(root, ck + Vector3(0.0, 1.6, 0.0), Vector3(7.0, 3.2, 5.0))
	_box(root, ck + Vector3(0.0, 1.2, 2.55), Vector3(5.0, 2.0, 0.1), m["glass"])
	_box(root, ck + Vector3(0.0, 3.5, 0.0), Vector3(7.6, 0.3, 5.6), m["roof"])
	_label(root, ck + Vector3(0.0, 4.2, 2.6), "PASSIO COFFEE FPT", 20, Color("#E67E22"), 0.0)

	_build_atrium_stair(root, m)

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
	_label(root, Vector3(door.x, st.y + 4.8, RING_V0 - 0.25), "PHÒNG LAB 402 – KỸ THUẬT PHẦN MỀM\n[FAP SLOT 1 – 07:30 AM]", 24, Color.WHITE, 180.0)
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
	# Cây trong nửa cỏ (toạ độ tương đối với tâm sân / hai mép, tránh hồ sen, lối đi sau và kiosk Passio)
	var tree_pts: Array = [
		Vector2(mid_u + 4.0, v0 + 15.0), Vector2(mid_u + 39.0, v0 + 4.0), Vector2(mid_u + 43.0, v1 - 5.0),
		Vector2(mid_u + 33.0, v1 - 4.5), Vector2(mid_u + 4.0, v1 - 4.0), Vector2(mid_u + 36.0, v0 + 13.0), Vector2(mid_u + 45.0, cv + 3.0)
	]
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
	for lp: Vector2 in [Vector2(u0 + 16.0, cv), Vector2(u0 + 36.0, cv), Vector2(mid_u + 20.0, v0 + 5.0), Vector2(mid_u + 20.0, v1 - 5.0)]:
		_cyl(root, Vector3(lp.x, 2.5, lp.y), 0.07, 0.1, 5.0, m["steel"])
		_sphere(root, Vector3(lp.x, 5.2, lp.y), 0.3, m["lamp"])

static func _build_back_facilities(root: Node3D, m: Dictionary) -> void:
	# Sân bóng mini 5 người (42 × 22 m thật) ở góc sau phía ĐN, sau lưng đầu nhà ĐN
	var pc := Vector3(PITCH_CX, 0.0, PITCH_CV)
	var hl: float = PITCH_LEN * 0.5
	var hw: float = PITCH_W * 0.5
	_box(root, pc + Vector3(0.0, 0.02, 0.0), Vector3(PITCH_LEN, 0.05, PITCH_W), m["pitch"])
	_box(root, pc + Vector3(0.0, 0.05, 0.0), Vector3(PITCH_LEN, 0.02, 0.2), m["line"])
	_box(root, pc + Vector3(0.0, 0.05, 0.0), Vector3(0.2, 0.02, PITCH_W), m["line"])
	for sx: float in [-1.0, 1.0]:
		_box(root, pc + Vector3(sx * (hl - 0.2), 0.05, 0.0), Vector3(0.2, 0.02, PITCH_W), m["line"])
		_box(root, pc + Vector3(sx * (hl - 0.5), 1.1, 0.0), Vector3(0.1, 2.2, 5.0), m["white"])
	_cyl(root, pc + Vector3(0.0, 0.05, 0.0), 4.0, 4.0, 0.02, m["line"])
	_cyl(root, pc + Vector3(0.0, 0.06, 0.0), 3.8, 3.8, 0.02, m["pitch"])
	for sz: float in [-1.0, 1.0]:
		_box(root, pc + Vector3(0.0, 2.0, sz * (hw + 0.5)), Vector3(PITCH_LEN, 4.0, 0.05), m["glass"])
		_col_box(root, pc + Vector3(0.0, 2.0, sz * (hw + 0.5)), Vector3(PITCH_LEN, 4.0, 0.3))
	for sx: float in [-1.0, 1.0]:
		_box(root, pc + Vector3(sx * (hl + 0.3), 2.0, 0.0), Vector3(0.05, 4.0, PITCH_W + 1.0), m["glass"])
		_col_box(root, pc + Vector3(sx * (hl + 0.3), 2.0, 0.0), Vector3(0.3, 4.0, PITCH_W + 1.0))

	# BÃI XE MÁY SINH VIÊN (dải thật 128 × 12 m dọc mép ĐB): 2 dãy mái tôn 7 m song song, làn xe 7 m ở giữa
	# (v = PARK_LANE_V); dãy B chừa khe 6 m trước cổng sau.
	var gaps: Array = _opt("parking_gaps", [])
	var bu: float = back_gap_u()
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var post_off: float = PARK_CANOPY_W * 0.5 - 0.6
	for row_v: float in [PARK_ROW_A, PARK_ROW_B]:
		var is_b: bool = is_equal_approx(row_v, PARK_ROW_B)
		var segs: Array = [[PARK_CX - PARK_HALF_LEN, PARK_CX + PARK_HALF_LEN]]
		if is_b:
			segs = [[PARK_CX - PARK_HALF_LEN, BACK_GATE_U - 3.0], [BACK_GATE_U + 3.0, PARK_CX + PARK_HALF_LEN]]
		for seg: Array in segs:
			var a: float = float(seg[0])
			var b: float = float(seg[1])
			var n_post: int = maxi(2, int(round((b - a) / 14.0)) + 1)
			for sx: float in [-1.0, 1.0]:
				for k: int in range(n_post):
					var pp := Vector3(lerpf(a + 0.6, b - 0.6, float(k) / float(n_post - 1)), 1.6, row_v + sx * post_off)
					_cyl(root, pp, 0.1, 0.12, 3.2, m["steel"])
					_col_cyl(root, pp, 0.14, 3.2)
			_prism(root, Vector3((a + b) * 0.5, 3.9, row_v), Vector3(PARK_CANOPY_W, 1.2, b - a), m["canopy"], 0.5, 90.0)
			_box(root, Vector3((a + b) * 0.5, 0.015, row_v), Vector3(b - a + 1.0, 0.03, PARK_CANOPY_W + 0.4), m["concrete"])
		for r2: float in [-1.8, 1.8]:
			var bx: float = PARK_CX - PARK_HALF_LEN
			while bx <= PARK_CX + PARK_HALF_LEN:
				var bz: float = row_v + r2
				var skip: bool = false
				for g: Variant in gaps:
					var gv: Vector2 = g
					if absf(bx - gv.x) < 2.0 and absf(bz - gv.y) < 1.0:
						skip = true
				# Lối đi bộ từ lối vào sau toà nhà ra làn xe: chừa trống dãy A; khe cổng sau: chừa trống dãy B
				if (not is_b) and absf(bx - bu) < 2.0:
					skip = true
				if is_b and absf(bx - BACK_GATE_U) < 3.0:
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
	# Làn xe đỏ giữa hai dãy (nối tới làn mép Tây) + làn xe mép Tây từ cổng tây; vạch ô đỗ trắng + nhãn
	_label(root, Vector3(PARK_CX, 5.6, PARK_ROW_A - 4.5), "BÃI XE MÁY SINH VIÊN – QUÉT THẺ DÂY CAM", 20, Color("#F1C40F"), 180.0)
	var lane_u0: float = PARK_CX - PARK_HALF_LEN - 4.0
	var lane_u1: float = WEST_LANE_U + 3.5
	_box(root, Vector3((lane_u0 + lane_u1) * 0.5, 0.02, PARK_LANE_V), Vector3(lane_u1 - lane_u0, 0.05, 7.0), m["red_plaza"])
	_box(root, Vector3(WEST_LANE_U, 0.02, (PARK_LANE_V + 3.5) * 0.5), Vector3(7.0, 0.05, PARK_LANE_V + 3.5), m["red_plaza"])
	var vx: float = PARK_CX - PARK_HALF_LEN
	while vx <= PARK_CX + PARK_HALF_LEN:
		for row_v: float in [PARK_ROW_A + 3.1, PARK_ROW_B - 3.1]:
			_box(root, Vector3(vx - 0.65, 0.05, row_v), Vector3(0.08, 0.02, 1.6), m["line"])
		vx += 1.3

static func _build_perimeter_trees(root: Node3D, m: Dictionary) -> void:
	# Hàng cây trong hàng rào: dọc mép sau (trừ sân bóng & cổng sau) và hai mép bên (dải ĐN 0..RING_U0, dải Tây sau làn xe)
	var k: int = 100
	var u: float = 4.0
	while u < PLOT_U - 3.0:
		var on_pitch: bool = absf(u - PITCH_CX) < PITCH_LEN * 0.5 + 2.0
		var on_gate: bool = absf(u - BACK_GATE_U) < 8.0
		if not on_pitch and not on_gate:
			build_tropical_tree(root, Vector3(u, 0.0, PLOT_V - 1.6), m, 1.1, k)
		u += 14.0
		k += 1
	var v: float = 16.0
	while v < PLOT_V - 4.0:
		build_tropical_tree(root, Vector3(4.0, 0.0, v), m, 1.0, k)
		build_tropical_tree(root, Vector3(PLOT_U - 2.0, 0.0, v + 6.0), m, 1.0, k + 1)
		v += 16.0
		k += 2

static func _is_lawn(u: float, v: float) -> bool:
	if u < 0.5 or u > PLOT_U - 0.5 or v < 0.8 or v > PLOT_V - 0.8:
		return false
	for r: Variant in _opt("no_grass_rects", []):
		var rr: Rect2 = r
		if rr.has_point(Vector2(u, v)):
			return false
	if absf(u - MAIN_GATE_U) < 7.0 and v < 12.0:
		return false
	if absf(u - WEST_LANE_U) < 4.5:
		return false
	if absf(u - BACK_GATE_U) < 3.8 and v > PARK_LANE_V - 3.5:
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
	if v > RING_V1 + 0.5:
		if absf(u - PITCH_CX) < PITCH_LEN * 0.5 + 1.5 and absf(v - PITCH_CV) < PITCH_W * 0.5 + 1.5:
			return false
		if u > PARK_CX - PARK_HALF_LEN - 4.5 and u < PLOT_U and v > PARK_ROW_A - 4.5 and v < PARK_ROW_B + 4.0:
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
	mm.set_meta("cine_xforms", xforms)   # FreeRoam's cinematic clutter check (headless RenderingServer returns none)
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

## Viện Công nghệ cao HUTECH đối diện FPT (khối kính tối màu lam trắng dọc + cổng xanh/vàng), origin = tim cổng trên
## hàng rào mặt D1 (hệ cục bộ campus: hutech_origin_local() = (136, 0, −46)). v8: khối chính theo footprint thật
## 94 × 32 m, tâm cách cổng HUTECH_BLOCK_OFFSET = 42 m về phía sau; trước hàng rào là vỉa hè + làn xe D1 phía xa
## (lấp dải −26..−46 giữa đoạn D1 của build_d1_road_piece và hàng rào). `draw_d1 = false` bỏ dải vỉa hè + làn xe
## đó (thế giới mở: MapBuilder đã dựng đường D1 thật ngay tại chỗ, vẽ chồng sẽ z-fight).
static func build_hutech(parent: Node3D, origin: Vector3, m: Dictionary, colliders: bool = false, draw_d1: bool = true) -> Node3D:
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
	var hl: float = HUTECH_BLOCK_LEN * 0.5
	var hd: float = HUTECH_BLOCK_DEPTH * 0.5
	var zc: float = -HUTECH_BLOCK_OFFSET
	var z_front: float = zc + hd   # mặt trước khối chính (phía D1)
	# Cổng + hàng rào thép xanh dọc mặt D1 (chừa lối 20 m)
	for sx: float in [-1.0, 1.0]:
		_box(campus, Vector3(sx * 10.0, 3.75, 0.0), Vector3(2.4, 7.5, 2.4), mat_blue)
		_col_box(campus, Vector3(sx * 10.0, 3.75, 0.0), Vector3(2.4, 7.5, 2.4))
	_quad(campus, Vector3(0.0, 6.2, 1.25), Vector2(20.0, 4.4), mat_sign, 0.0)
	for seg: Array in [[-128.0, -11.2], [11.2, 60.0]]:
		var a: float = float(seg[0])
		var b: float = float(seg[1])
		_box(campus, Vector3((a + b) * 0.5, 0.25, 0.0), Vector3(b - a, 0.5, 0.3), m["concrete"])
		_box(campus, Vector3((a + b) * 0.5, 1.25, 0.0), Vector3(b - a, 1.5, 0.08), mat_blue)
		_col_box(campus, Vector3((a + b) * 0.5, 1.0, 0.0), Vector3(b - a, 2.0, 0.3))
	# Toà chính 8 tầng kính tối + lam trắng dọc + nẹp sàn trắng (footprint thật)
	_box(campus, Vector3(0.0, 14.0, zc), Vector3(HUTECH_BLOCK_LEN, 28.0, HUTECH_BLOCK_DEPTH), mat_dark)
	_col_box(campus, Vector3(0.0, 14.0, zc), Vector3(HUTECH_BLOCK_LEN, 28.0, HUTECH_BLOCK_DEPTH))
	var fx: float = -(hl - 1.0)
	while fx <= hl - 1.0:
		_box(campus, Vector3(fx, 14.0, z_front + 0.4), Vector3(0.35, 26.5, 1.1), m["white"])
		fx += 2.4
	for sx: float in [-1.0, 1.0]:
		var fz: float = zc - hd + 3.0
		while fz <= zc + hd - 3.0:
			_box(campus, Vector3(sx * (hl + 0.4), 14.0, fz), Vector3(1.1, 26.5, 0.35), m["white"])
			fz += 2.4
	for floor_idx: int in range(0, 9):
		_box(campus, Vector3(0.0, floor_idx * 3.4 + 0.3, zc), Vector3(HUTECH_BLOCK_LEN + 0.6, 0.3, HUTECH_BLOCK_DEPTH + 0.6), m["white"])
	_box(campus, Vector3(0.0, 29.6, z_front + 0.2), Vector3(22.0, 2.6, 0.5), mat_gold)
	_label(campus, Vector3(0.0, 29.6, z_front + 0.6), "HUTECH", 70, Color("#0055A5"), 0.0)
	_label(campus, Vector3(0.0, 9.0, z_front + 0.7), "VIỆN CÔNG NGHỆ CAO HUTECH – KHU CÔNG NGHỆ CAO TP.HCM", 30, Color("#FFD100"), 0.0)
	# Sân trước khối chính (từ cổng tới mặt tiền) + đường xe nội bộ
	_box(campus, Vector3(0.0, 0.01, z_front * 0.5), Vector3(HUTECH_BLOCK_LEN * 0.6, 0.03, -z_front), m["concrete"])
	_box(campus, Vector3(0.0, 0.02, z_front * 0.5), Vector3(8.0, 0.03, -z_front), m["asphalt"])
	# Khối Viện CNC 3 tầng (phía -u, đối diện đầu ĐN campus) + khối nghiên cứu trắng ở giữa
	_box(campus, Vector3(-100.0, 5.5, -24.0), Vector3(44.0, 11.0, 18.0), m["white"])
	_col_box(campus, Vector3(-100.0, 5.5, -24.0), Vector3(44.0, 11.0, 18.0))
	for floor_idx: int in range(3):
		_box(campus, Vector3(-100.0, floor_idx * 3.5 + 2.2, -14.8), Vector3(42.0, 1.5, 0.4), m["glass"])
	_label(campus, Vector3(-100.0, 12.0, -14.6), "VIỆN CÔNG NGHỆ CAO HUTECH – KHU E1", 34, Color("#FFD100"), 0.0)
	_box(campus, Vector3(-62.0, 10.0, -30.0), Vector3(28.0, 20.0, 20.0), m["white"])
	_col_box(campus, Vector3(-62.0, 10.0, -30.0), Vector3(28.0, 20.0, 20.0))
	# Trước hàng rào: vỉa hè lát gạch, rồi làn xe D1 phía xa (3 làn một chiều) nối tới mép vỉa hè đối diện của
	# build_d1_road_piece (v ≈ −26), dải phân cách cỏ hẹp
	if draw_d1:
		_box(campus, Vector3(-34.0, 0.14, 2.9), Vector3(188.0, 0.28, 5.2), m["sidewalk"])
		_box(campus, Vector3(-34.0, 0.2, 5.65), Vector3(188.0, 0.4, 0.3), m["granite"])
		# mặt nhựa nhô 2 cm trên y = 0 để không z-fight với mặt đất của màn (Màn 1 đặt mặt đất tại y = 0)
		_box(campus, Vector3(-34.0, -0.105, 12.8), Vector3(188.0, 0.25, 14.0), m["asphalt"])
		_box(campus, Vector3(-34.0, 0.03, 19.65), Vector3(188.0, 0.02, 0.15), m["line"])
		var dx: float = -126.0
		while dx < 58.0:
			for lz: float in [9.4, 14.0]:
				_box(campus, Vector3(dx, 0.03, lz), Vector3(3.0, 0.02, 0.15), m["line"])
			dx += 9.0
	for x_offset: float in [-110.0, -70.0, -35.0, -18.0, 18.0, 35.0, 52.0]:
		build_tropical_tree(campus, Vector3(x_offset, 0.0, -4.0), m, 1.0, 700 + int(x_offset))
	_opts = prev_opts
	return campus

# ===========================================================================
# v7 – SẢNH TRỐNG ĐỒNG, SẢNH THÔNG TẦNG, CẦU THANG TRONG NHÀ, CHI TIẾT KIẾN TRÚC
# ===========================================================================
## Dầm bê tông lộ dưới trần (ảnh tham chiếu: trần sảnh tầng trệt lộ dầm, sơn xám)
static func _exposed_beams(parent: Node3D, xc: float, zc: float, depth_f: float, len_z: float, ceil_y: float, m: Dictionary) -> void:
	var bz: float = zc - len_z * 0.5 + 1.6
	while bz <= zc + len_z * 0.5 - 1.0:
		_box(parent, Vector3(xc, ceil_y - 0.32, bz), Vector3(depth_f - 0.4, 0.55, 0.36), m["concrete_beam"])
		bz += 3.2
	_box(parent, Vector3(xc, ceil_y - 0.32, zc), Vector3(0.4, 0.55, len_z), m["concrete_beam"])

## Đèn trần: panel sáng + OmniLight không bóng, rải theo chiều dài (sảnh thông tầng tối vì bị tường/sàn che)
static func _hall_lights(parent: Node3D, xc: float, zc: float, depth_f: float, len_z: float, ceil_y: float, m: Dictionary, energy: float) -> void:
	var lz: float = zc - len_z * 0.5 + 2.2
	while lz <= zc + len_z * 0.5 - 1.5:
		for lx: float in [xc - depth_f * 0.28, xc + depth_f * 0.28]:
			_box(parent, Vector3(lx, ceil_y - 0.62, lz), Vector3(1.3, 0.05, 0.3), m["lamp"])
			var ol := OmniLight3D.new()
			ol.position = Vector3(lx, ceil_y - 0.9, lz)
			ol.light_color = Color(1.0, 0.97, 0.9)
			ol.light_energy = energy
			ol.omni_range = 9.0
			ol.omni_attenuation = 1.2
			ol.shadow_enabled = false
			parent.add_child(ol)
		lz += 4.4

## Lan can thép trắng (song đứng + tay vịn) dài `length` dọc trục Z (yaw 0) hoặc X (yaw 90) tại `pos` (đáy lan can).
static func _white_railing(parent: Node3D, pos: Vector3, length: float, yaw_deg: float, m: Dictionary) -> void:
	var rail := Node3D.new()
	rail.position = pos
	rail.rotation_degrees.y = yaw_deg
	parent.add_child(rail)
	_box(rail, Vector3(0.0, 1.08, 0.0), Vector3(0.06, 0.06, length), m["rail_white"])
	_box(rail, Vector3(0.0, 0.55, 0.0), Vector3(0.04, 0.03, length), m["rail_white"])
	var n: int = maxi(2, int(length / 0.32))
	for i: int in range(n + 1):
		var z: float = -length * 0.5 + float(i) * (length / float(n))
		_box(rail, Vector3(0.0, 0.54, z), Vector3(0.03, 1.08, 0.03), m["rail_white"])
	_col_box(parent, pos + Vector3(0.0, 0.55, 0.0), Vector3(0.2, 1.1, length) if yaw_deg == 0.0 else Vector3(length, 1.1, 0.2))

## Một tầng của SẢNH THÔNG TẦNG (hệ cục bộ cánh, x = chiều sâu, z = dọc cánh): sàn 2 dải hai bên KHE THANG,
## lan can trắng mép khe, dầm bê tông, tường ngoài có cửa sổ, mặt sân trong là tường kính; tầng trệt = sảnh mở
## (sàn terrazzo, cột tròn, kính có lối vào, trần dầm). is_top: thêm sàn mái bằng.
static func _build_atrium_floor(wing: Node3D, xc: float, zc: float, depth_f: float, len_z: float, inner_sign: float, y0: float, m: Dictionary, ground: bool, is_top: bool) -> void:
	var inner_x: float = xc + inner_sign * depth_f * 0.5
	var outer_x: float = xc - inner_sign * depth_f * 0.5
	# khe thang trong hệ cục bộ cánh: cánh phải đặt tại u_r = RING_U1 - SIDE_D/2, x cục bộ = u - u_r
	var u_r: float = RING_U1 - SIDE_D * 0.5
	var slot0: float = STAIR_U - STAIR_SLOT_HALF - u_r
	var slot1: float = STAIR_U + STAIR_SLOT_HALF - u_r
	var lo_x: float = minf(inner_x, outer_x)
	var hi_x: float = maxf(inner_x, outer_x)
	var top_y: float = y0 + FLOOR_H
	if ground:
		_box(wing, Vector3(xc, 0.055, zc), Vector3(depth_f - 0.2, 0.05, len_z), m["terrazzo_lobby"])
		# cột tròn hai bên khe thang + dầm trần
		var cz: float = zc - len_z * 0.5 + 1.5
		while cz <= zc + len_z * 0.5 - 1.0:
			for cx: float in [slot0 - 1.2, slot1 + 1.2]:
				_cyl(wing, Vector3(cx, FLOOR_H * 0.5, cz), 0.28, 0.3, FLOOR_H, m["white"])
				_col_cyl(wing, Vector3(cx, FLOOR_H * 0.5, cz), 0.32, FLOOR_H)
			cz += 4.5
		_exposed_beams(wing, xc, zc, depth_f, len_z, FLOOR_H, m)
		_hall_lights(wing, xc, zc, depth_f, len_z, FLOOR_H, m, 1.3)
		# tường ngoài đặc (tầng trệt) + tường kính phía sân trong có LỐI VÀO ở nửa nam (v lớn = z cục bộ lớn)
		_box(wing, Vector3(outer_x + inner_sign * 0.25, FLOOR_H * 0.5, zc), Vector3(0.5, FLOOR_H, len_z), m["facade"])
		_col_box(wing, Vector3(outer_x + inner_sign * 0.25, FLOOR_H * 0.5, zc), Vector3(0.5, FLOOR_H, len_z))
		var gx: float = inner_x - inner_sign * 0.12
		var door_z0: float = zc + len_z * 0.5 - 6.0
		var door_z1: float = zc + len_z * 0.5 - 1.2
		if len_z > 8.0:
			# kính phía bắc lối vào + kính phía nam lối vào
			var za: float = zc - len_z * 0.5
			_box(wing, Vector3(gx, FLOOR_H * 0.5, (za + door_z0) * 0.5), Vector3(0.08, FLOOR_H - 0.3, door_z0 - za), m["glass_clear"])
			_col_box(wing, Vector3(gx, FLOOR_H * 0.5, (za + door_z0) * 0.5), Vector3(0.3, FLOOR_H, door_z0 - za))
			_box(wing, Vector3(gx, FLOOR_H * 0.5, (door_z1 + zc + len_z * 0.5) * 0.5), Vector3(0.08, FLOOR_H - 0.3, zc + len_z * 0.5 - door_z1), m["glass_clear"])
			_col_box(wing, Vector3(gx, FLOOR_H * 0.5, (door_z1 + zc + len_z * 0.5) * 0.5), Vector3(0.3, FLOOR_H, zc + len_z * 0.5 - door_z1))
			_box(wing, Vector3(gx, FLOOR_H - 0.3, (door_z0 + door_z1) * 0.5), Vector3(0.3, 0.6, door_z1 - door_z0), m["white"])
			var mz: float = za
			while mz <= zc + len_z * 0.5 + 0.01:
				_box(wing, Vector3(gx, FLOOR_H * 0.5, mz), Vector3(0.12, FLOOR_H - 0.3, 0.1), m["white"])
				mz += 2.3
		else:
			_box(wing, Vector3(gx, FLOOR_H * 0.5, zc), Vector3(0.08, FLOOR_H - 0.3, len_z), m["glass_clear"])
			_col_box(wing, Vector3(gx, FLOOR_H * 0.5, zc), Vector3(0.3, FLOOR_H, len_z))
	# sàn tầng trên (trần tầng này) = 2 dải hai bên khe thang + lan can trắng mép khe + dầm dưới sàn
	var strip_a: float = slot0 - lo_x
	var strip_b: float = hi_x - slot1
	_box(wing, Vector3((lo_x + slot0) * 0.5, top_y - 0.15, zc), Vector3(strip_a, 0.3, len_z + 0.1), m["white"])
	_box(wing, Vector3((slot1 + hi_x) * 0.5, top_y - 0.15, zc), Vector3(strip_b, 0.3, len_z + 0.1), m["white"])
	if not is_top:
		_white_railing(wing, Vector3(slot0 - 0.1, top_y, zc), len_z, 0.0, m)
		_white_railing(wing, Vector3(slot1 + 0.1, top_y, zc), len_z, 0.0, m)
	if not ground:
		# tầng trên: tường ngoài có cửa sổ (texture ảnh), kính phía sân trong, dầm trần
		_box(wing, Vector3(outer_x + inner_sign * 0.25, y0 + FLOOR_H * 0.5, zc), Vector3(0.5, FLOOR_H, len_z), m["facade"])
		var gx2: float = inner_x - inner_sign * 0.12
		_box(wing, Vector3(gx2, y0 + FLOOR_H * 0.5, zc), Vector3(0.08, FLOOR_H - 0.3, len_z), m["glass_clear"])
		var mz2: float = zc - len_z * 0.5
		while mz2 <= zc + len_z * 0.5 + 0.01:
			_box(wing, Vector3(gx2, y0 + FLOOR_H * 0.5, mz2), Vector3(0.12, FLOOR_H - 0.3, 0.1), m["white"])
			mz2 += 2.3
		var bz: float = zc - len_z * 0.5 + 1.6
		while bz <= zc + len_z * 0.5 - 1.0:
			_box(wing, Vector3((lo_x + slot0) * 0.5, top_y - 0.5, bz), Vector3(strip_a - 0.3, 0.4, 0.3), m["concrete_beam"])
			_box(wing, Vector3((slot1 + hi_x) * 0.5, top_y - 0.5, bz), Vector3(strip_b - 0.3, 0.4, 0.3), m["concrete_beam"])
			bz += 3.2
		_hall_lights(wing, xc, zc, depth_f, len_z, top_y, m, 0.9)

## Lan can kính + tay vịn dọc một đoạn thang chạy theo trục Z (a → b cùng x = STAIR_U).
static func _stair_rail_v(root: Node3D, a: Vector3, b: Vector3, m: Dictionary, width: float, sides: Array = [-1.0, 1.0]) -> void:
	var d: Vector3 = b - a
	var slen: float = d.length()
	if slen < 0.05:
		return
	var ang: float = rad_to_deg(atan2(d.y, -d.z)) # thang chạy về -z
	var mid: Vector3 = (a + b) * 0.5
	for sx: float in sides:
		var xpos: float = STAIR_U + sx * (width * 0.5 - 0.06)
		var rail := _box(root, Vector3(xpos, mid.y + 1.05, mid.z), Vector3(0.08, 0.08, slen), m["steel"])
		rail.rotation_degrees.x = ang
		var glass := _box(root, Vector3(xpos, mid.y + 0.55, mid.z), Vector3(0.04, 0.9, slen), m["glass"])
		glass.rotation_degrees.x = ang
	var n_post: int = maxi(1, int(slen / 2.2))
	for i: int in range(n_post + 1):
		var t: float = float(i) / float(n_post)
		var p: Vector3 = a.lerp(b, t)
		for sx: float in sides:
			_cyl(root, Vector3(STAIR_U + sx * (width * 0.5 - 0.06), p.y + 0.55, p.z), 0.03, 0.03, 1.1, m["steel"])

## CẦU THANG TRONG NHÀ trong sảnh thông tầng cánh phải: đợt 1 = KHÁN ĐÀI ĐỎ vẽ graffiti (ảnh tham chiếu),
## đợt 2–3 = thang trắng lan can kính; 2 chiếu nghỉ có bồn cây; chiếu nghỉ đỉnh nối cửa Lab 402 ở mặt nam module 0.
static func _build_atrium_stair(root: Node3D, m: Dictionary) -> void:
	var prof: Array[Vector3] = stair_profile()
	var mat_tread := _mat(Color("#E8EAED"), 0.6)
	var mat_nosing := _mat(Color("#F37021"), 0.5, 0.0, 0.25)
	var mat_red := _mat(Color("#C4302C"), 0.65)
	for i: int in range(prof.size() - 1):
		var a: Vector3 = prof[i]
		var b: Vector3 = prof[i + 1]
		var run: float = a.z - b.z
		var rise: float = b.y - a.y
		var first: bool = i == 0
		var width: float = STAIR_W + (2.6 if first else 0.0)
		if rise > 0.01:
			var n: int = maxi(1, int(round(rise / (0.21 if first else 0.17))))
			var h: float = rise / float(n)
			var dd: float = run / float(n)
			for k: int in range(n):
				var cz: float = a.z - (float(k) + 0.5) * dd
				var cy: float = a.y + (float(k) + 0.5) * h
				_box(root, Vector3(STAIR_U, cy, cz), Vector3(width, h, dd + 0.01), mat_red if first else mat_tread)
				_box(root, Vector3(STAIR_U, cy + h * 0.5 + 0.006, cz - dd * 0.5 + 0.03), Vector3(width - 0.1, 0.012, 0.06), m["dark"] if first else mat_nosing)
			var slen: float = sqrt(run * run + rise * rise)
			var soffit := _box(root, Vector3(STAIR_U, (a.y + b.y) * 0.5 - 0.22, (a.z + b.z) * 0.5), Vector3(width + 0.1, 0.4, slen), m["white"] if not first else mat_red)
			soffit.rotation_degrees.x = rad_to_deg(atan2(rise, run))
			if first:
				# tường graffiti hai bên khán đài (thấp) + bức tường graffiti lớn sau chiếu nghỉ 1
				for sx: float in [-1.0, 1.0]:
					var wall := _box(root, Vector3(STAIR_U + sx * (width * 0.5 + 0.08), (a.y + b.y) * 0.5 + 0.6, (a.z + b.z) * 0.5), Vector3(0.16, 1.4, slen), m["graffiti"])
					wall.rotation_degrees.x = rad_to_deg(atan2(rise, run))
			else:
				_stair_rail_v(root, a, b, m, width)
		else:
			# chiếu nghỉ: sàn trắng + bồn cây + lan can
			_box(root, Vector3(STAIR_U, a.y - 0.2, (a.z + b.z) * 0.5), Vector3(width + 0.1, 0.4, run + 0.02), m["white"])
			_box(root, Vector3(STAIR_U, a.y + 0.08, (a.z + b.z) * 0.5), Vector3(width - 0.3, 0.16, run - 0.2), m["lawn_small"])
			_stair_rail_v(root, a, b, m, width)
			if i == 1:
				var gw: float = STAIR_W + 2.6
				_box(root, Vector3(STAIR_U, a.y + 2.2, b.z - 0.3), Vector3(gw + 1.0, 4.4, 0.25), m["graffiti"])
				_box(root, Vector3(STAIR_U, a.y + 4.5, b.z - 0.3), Vector3(gw + 1.2, 0.25, 0.4), m["white"])
	# chiếu nghỉ đỉnh (khối link 0/1) nối tới cửa Lab 402 ở mặt nam module 0
	var st: Vector3 = prof[prof.size() - 1]
	var door: Vector3 = lab402_door()
	var land_z: float = (st.z + door.z) * 0.5
	_box(root, Vector3(STAIR_U, st.y - 0.1, land_z), Vector3(STAIR_W + 1.0, 0.2, st.z - door.z + 0.2), m["white"])
	_box(root, Vector3(door.x, st.y + 1.85, door.z + 0.12), Vector3(3.8, 3.9, 0.24), m["granite"])
	_box(root, Vector3(door.x, st.y + 1.7, door.z + 0.26), Vector3(3.2, 3.4, 0.14), _mat(Color("#2ECC71"), 0.4, 0.0, 0.9))
	_box(root, Vector3(door.x, st.y + 3.9, door.z + 0.26), Vector3(4.6, 0.6, 0.16), m["orange"])
	_label(root, Vector3(door.x, st.y + 4.8, door.z + 0.45), "PHÒNG LAB 402 – KỸ THUẬT PHẦN MỀM\n[FAP SLOT 1 – 07:30 AM]", 24, Color.WHITE, 0.0)
	var sf: Vector3 = prof[0]
	_label(root, Vector3(sf.x, 3.2, sf.z + 2.5), "⬆ SẢNH THÔNG TẦNG – CẦU THANG LÊN LẦU 4 (LAB 402)", 16, Color("#F1C40F"), 0.0)

## Đĩa phẳng có UV phẳng (mặt trống đồng).
static func _disc_mesh(radius: float, segments: int = 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(segments):
		var a0: float = float(i) / float(segments) * TAU
		var a1: float = float(i + 1) / float(segments) * TAU
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(0.5 + 0.5 * cos(a1), 0.5 + 0.5 * sin(a1))); st.add_vertex(Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
		st.set_uv(Vector2(0.5 + 0.5 * cos(a0), 0.5 + 0.5 * sin(a0))); st.add_vertex(Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
	return st.commit()

## SẢNH TRỐNG ĐỒNG (hệ cục bộ cánh trước: x = chiều sâu, +x = phía D1, z = dọc u): sàn terrazzo hoa văn, trống đồng
## trên bệ đen giữa sảnh, kính 2 mặt có lối đi, bảng FPT UNIVERSITY, thang máy ốp đá, dãy ảnh, cây cảnh, trần đèn panel.
static func _build_lobby_trong_dong(wing: Node3D, xc: float, zc: float, depth_f: float, module_w: float, inner_sign: float, m: Dictionary) -> void:
	var half_d: float = depth_f * 0.5
	var half_w: float = module_w * 0.5
	var outer_x: float = xc - inner_sign * half_d   # phía D1
	var inner_x: float = xc + inner_sign * half_d   # phía sân trong
	_box(wing, Vector3(xc, 0.06, zc), Vector3(depth_f + 0.4, 0.06, module_w + LINK_W), m["terrazzo_lobby"])
	# trần: tấm trắng + 6 panel đèn + đèn
	_box(wing, Vector3(xc, FLOOR_H - 0.06, zc), Vector3(depth_f + 0.2, 0.12, module_w + LINK_W), m["ceiling"])
	for lz: float in [zc - half_w * 0.55, zc, zc + half_w * 0.55]:
		for lx: float in [xc - half_d * 0.4, xc + half_d * 0.4]:
			_box(wing, Vector3(lx, FLOOR_H - 0.14, lz), Vector3(1.4, 0.05, 0.7), m["lamp"])
			var ol := OmniLight3D.new()
			ol.position = Vector3(lx, FLOOR_H - 0.5, lz)
			ol.light_color = Color(1.0, 0.98, 0.94)
			ol.light_energy = 1.2
			ol.omni_range = 8.0
			ol.omni_attenuation = 1.3
			ol.shadow_enabled = false
			wing.add_child(ol)
	# hai mặt kính (D1 & sân trong) có LỐI ĐI 3.2 m ở giữa; cột kính trắng
	for face_x: float in [outer_x + inner_sign * 0.15, inner_x - inner_sign * 0.15]:
		for sgn: float in [-1.0, 1.0]:
			var seg_len: float = half_w - 1.6
			var cz: float = zc + sgn * (1.6 + seg_len * 0.5)
			_box(wing, Vector3(face_x, FLOOR_H * 0.5 - 0.1, cz), Vector3(0.08, FLOOR_H - 0.3, seg_len), m["glass_clear"])
			_col_box(wing, Vector3(face_x, FLOOR_H * 0.5, cz), Vector3(0.3, FLOOR_H, seg_len))
		_box(wing, Vector3(face_x, FLOOR_H - 0.35, zc), Vector3(0.3, 0.5, 3.4), m["white"])
		var mz: float = zc - half_w
		while mz <= zc + half_w + 0.01:
			_box(wing, Vector3(face_x, FLOOR_H * 0.5, mz), Vector3(0.14, FLOOR_H - 0.2, 0.12), m["white"])
			mz += 2.2
	# bảng FPT UNIVERSITY trên lối vào phía D1 (nhìn được cả hai mặt)
	for sgn: float in [-1.0, 1.0]:
		_quad(wing, Vector3(outer_x + inner_sign * 0.15 + sgn * 0.2, FLOOR_H - 0.95, zc), Vector2(6.0, 1.3), m["board"], 90.0 * sgn * (-inner_sign))
	# tường bên: (z nhỏ) THANG MÁY ốp đá + 2 cửa thép + chữ G; (z lớn) dãy ảnh khung + ghế gỗ
	var wall_z0: float = zc - half_w - LINK_W * 0.5 + 0.2
	var wall_z1: float = zc + half_w + LINK_W * 0.5 - 0.2
	_box(wing, Vector3(xc, FLOOR_H * 0.5, wall_z0), Vector3(depth_f - 0.6, FLOOR_H, 0.3), m["wall_paint"])
	_col_box(wing, Vector3(xc, FLOOR_H * 0.5, wall_z0), Vector3(depth_f - 0.6, FLOOR_H, 0.3))
	_box(wing, Vector3(xc, FLOOR_H * 0.5, wall_z1), Vector3(depth_f - 0.6, FLOOR_H, 0.3), m["wall_paint"])
	_col_box(wing, Vector3(xc, FLOOR_H * 0.5, wall_z1), Vector3(depth_f - 0.6, FLOOR_H, 0.3))
	_box(wing, Vector3(xc - 1.0, FLOOR_H * 0.5, wall_z0 + 0.2), Vector3(6.2, FLOOR_H - 0.1, 0.12), m["marble"])
	for ex: float in [xc - 2.4, xc + 0.4]:
		_box(wing, Vector3(ex, 1.2, wall_z0 + 0.3), Vector3(1.3, 2.4, 0.08), m["elevator"])
		_box(wing, Vector3(ex, 1.2, wall_z0 + 0.35), Vector3(0.03, 2.4, 0.04), m["dark"])
		_box(wing, Vector3(ex, 2.6, wall_z0 + 0.31), Vector3(0.5, 0.18, 0.04), _mat(Color("#FF5722"), 0.3, 0.0, 1.0))
	_label(wing, Vector3(xc - 3.9, 1.9, wall_z0 + 0.32), "G", 48, Color("#F1C40F"), 0.0)
	_box(wing, Vector3(xc + 2.7, 1.0, wall_z0 + 0.3), Vector3(0.9, 0.9, 0.06), m["board"])
	var photos: Array = ["fptu_campus_hall_atrium.png", "fptu_student_activities_billboard.png", "fptu_vtn_architecture_plaque.png", "fptu_campus_map_billboard.png"]
	for i: int in range(photos.size()):
		var pm: StandardMaterial3D = _tex_mat(String(photos[i]), Color("#DDDDDD"), false, Vector3.ONE, 0.6)
		var px: float = xc - half_d + 1.8 + float(i) * 3.0
		_box(wing, Vector3(px, 1.75, wall_z1 - 0.22), Vector3(2.4, 1.6, 0.06), m["dark"])
		_quad(wing, Vector3(px, 1.75, wall_z1 - 0.27), Vector2(2.2, 1.4), pm, 180.0)
	_box(wing, Vector3(xc, 0.45, wall_z1 - 0.9), Vector3(4.0, 0.08, 0.6), m["wood"])
	_box(wing, Vector3(xc, 0.2, wall_z1 - 0.9), Vector3(3.6, 0.4, 0.5), m["dark"])
	# TRỐNG ĐỒNG trên bệ đá đen (tâm sảnh): thân tiện (phình – thắt eo – xoè chân), mặt trống dán hoa văn, 4 quai, vành
	var pc := Vector3(xc, 0.0, zc)
	_box(wing, pc + Vector3(0.0, 0.06, 0.0), Vector3(3.6, 0.12, 3.6), m["marble"])
	_box(wing, pc + Vector3(0.0, 0.36, 0.0), Vector3(2.8, 0.5, 2.8), m["black_plinth"])
	_col_box(wing, pc + Vector3(0.0, 0.5, 0.0), Vector3(3.6, 1.0, 3.6))
	var drum := MeshInstance3D.new()
	drum.mesh = CharacterBuilder._lathe([Vector3(0.9, 0.0, 0.9), Vector3(1.0, 0.1, 1.0), Vector3(0.86, 0.32, 0.86), Vector3(0.8, 0.5, 0.8), Vector3(0.93, 0.74, 0.93), Vector3(1.02, 0.9, 1.02), Vector3(1.0, 1.02, 1.0), Vector3(0.0, 1.03, 0.0)], 40)
	drum.material_override = m["bronze"]
	drum.position = pc + Vector3(0.0, 0.61, 0.0)
	wing.add_child(drum)
	var face := MeshInstance3D.new()
	face.mesh = _disc_mesh(0.99)
	face.material_override = m["bronze_face"]
	face.position = pc + Vector3(0.0, 1.645, 0.0)
	wing.add_child(face)
	for ring_y: float in [0.72, 1.0, 1.5]:
		_torus(wing, pc + Vector3(0.0, ring_y, 0.0), 0.86 if ring_y < 1.2 else 0.98, (0.86 if ring_y < 1.2 else 0.98) + 0.05, m["dark"])
	for a: int in range(4):
		var ang: float = float(a) * TAU / 4.0 + PI * 0.25
		var hp: Vector3 = pc + Vector3(cos(ang) * 1.0, 1.15, sin(ang) * 1.0)
		var handle := _torus(wing, hp, 0.08, 0.14, m["bronze"])
		handle.rotation_degrees.y = -rad_to_deg(ang)
	_label(wing, pc + Vector3(0.0, 2.3, 0.0), "TRỐNG ĐỒNG ĐÔNG SƠN – SẢNH CHÍNH FPTU", 18, Color("#FFD32A"), 0.0, true)
	# cây cảnh trong chậu ở 4 góc + thảm đỏ lối vào
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pp: Vector3 = Vector3(xc + sx * (half_d - 1.3), 0.0, zc + sz * (half_w - 1.0))
			_cyl(wing, pp + Vector3(0.0, 0.3, 0.0), 0.3, 0.24, 0.6, m["white"])
			_cyl(wing, pp + Vector3(0.0, 1.1, 0.0), 0.03, 0.04, 1.0, m["trunk"])
			_sphere(wing, pp + Vector3(0.0, 1.75, 0.0), 0.5, m["leaf3"])
			_sphere(wing, pp + Vector3(0.25, 1.5, 0.1), 0.35, m["leaf2"])
	_box(wing, Vector3(xc, 0.1, zc), Vector3(depth_f + 0.5, 0.02, 2.6), m["red_path"])
