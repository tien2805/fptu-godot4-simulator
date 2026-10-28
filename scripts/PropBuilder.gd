# File: res://scripts/PropBuilder.gd
# ĐỒ VẬT "giống thật" dựng thủ tục nhiều chi tiết (không model ngoài, không ảnh AI; texture gỗ/kim loại/da vẽ bằng
# generate_prop_textures.py). Dùng chung bộ primitive + cache mesh/material của CharacterBuilder.
#   build_scooter(parent, pos, yaw, paint, opts)      xe tay ga ~50 chi tiết (bánh có lốp/mâm/nan hoa, phuộc, yếm, sàn,
#                                                     thân sau tiện, yên da, baga, đèn, biển số, ống xả, ghi-đông, gương…)
#                                                     opts.baked = true → gộp thành 1 MeshInstance3D (xe NPC, menu)
#                                                     opts.traffic_lamps = true → đèn pha / hậu dùng chung traffic_lamp()
#   traffic_lamp(kind), set_traffic_lamps(on)        đèn xe giao thông dùng chung, bật ban đêm (OB-D6); build_car / build_bus luôn dùng
#   build_scooter_parts(root, front, rear, handlebar) lắp chi tiết vào các pivot có sẵn (PlayerBike.tscn)
#   build_bus(parent, is_fbus)                        xe buýt F-Bus / VinBus (thân bo, dải kính + trụ, cửa, gương, đèn, 6 bánh)
#   build_car(parent, paint, baked)                   ô tô con hatchback (xe chạy FreeRoam), mặt trước -Z
#   build_training_dummy(parent, mat)                 nộm gỗ Vovinam (thân, 3 tay, chân, đệm đầu da, đế)
#   build_tree(parent, pos, m, scale, seed)           cây tán rộng: thân cong, rễ bạnh, cành, 8–10 khối lá
#   build_lamp_post(parent, pos, height, m)           cột đèn cao áp 2 nhánh
#   build_tray(parent, kind)                          khay cơm căn tin có dĩa cơm, chén canh, đồ ăn, ly, đũa
#   build_table(parent, pos), build_stool(parent, pos), build_umbrella(parent, pos)
#   palm_meshes()                                     cọ Vice City v2 (plan VC-2): mesh thân 5 khoanh thuôn + mesh tán
#                                                     12 tàu lá rủ + 3 trái dừa, dùng chung, cache tĩnh
#   build_palm_field(parent, points, opts)            cả rừng cọ = 2 MultiMeshInstance3D (thân, tán), collider tuỳ chọn
#   build_palm(parent, pos, height, seed)             một cây cọ lẻ (2 MeshInstance3D dùng chung mesh của rừng cọ)
# KHÔNG dùng định danh autoload ở đây (xem ghi chú ở CharacterBuilder).
class_name PropBuilder
extends RefCounted

# ===========================================================================
# VẬT LIỆU
# ===========================================================================
static func paint(color: Color) -> StandardMaterial3D:
	var k: String = "paint_" + color.to_html(false)
	if CharacterBuilder._mat_cache.has(k):
		return CharacterBuilder._mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.35
	m.roughness = 0.28
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.clearcoat_roughness = 0.1
	CharacterBuilder._style_mat(m, 0.01)
	CharacterBuilder._mat_cache[k] = m
	return m

static func chrome() -> StandardMaterial3D:
	return CharacterBuilder._mat("chrome", Color("#E8ECEF"), 0.14, 0.95)

static func steel() -> StandardMaterial3D:
	return _textured("steel_brushed", Color("#B8BEC4"), "prop_metal_brushed.png", "prop_metal_brushed_n.png", 0.4, 0.85, 3.0)

static func black_plastic() -> StandardMaterial3D:
	return CharacterBuilder._mat("black_plastic", Color("#1E2024"), 0.55)

static func rubber() -> StandardMaterial3D:
	var k: String = "rubber_tread"
	if CharacterBuilder._mat_cache.has(k):
		return CharacterBuilder._mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#15171A")
	m.roughness = 0.95
	var n: Texture2D = CharacterBuilder._tex("prop_tread_n.png")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.8
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(6.0, 6.0, 6.0)
	CharacterBuilder._style_mat(m, 0.01)
	CharacterBuilder._mat_cache[k] = m
	return m

static func leather() -> StandardMaterial3D:
	return _textured("leather", Color("#2A2628"), "prop_leather.png", "prop_leather_n.png", 0.7, 0.0, 4.0)

static func wood() -> StandardMaterial3D:
	return _textured("wood", Color("#9C6B3F"), "prop_wood.png", "prop_wood_n.png", 0.72, 0.0, 1.0)

static func glass_dark() -> StandardMaterial3D:
	var k: String = "glass_dark"
	if CharacterBuilder._mat_cache.has(k):
		return CharacterBuilder._mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.1, 0.14, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.6
	m.roughness = 0.08
	CharacterBuilder._mat_cache[k] = m
	return m

static func lens(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var k: String = "lens_" + color.to_html(false)
	if CharacterBuilder._mat_cache.has(k):
		return CharacterBuilder._mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	CharacterBuilder._mat_cache[k] = m
	return m

## Đèn xe giao thông (OB-D6): 4 vật liệu dùng chung cho mọi xe chạy (ô tô / xe buýt: "head", "tail"; xe máy:
## "moto_head", "moto_tail"). Năng lượng ban ngày = năng lượng lens() cũ thực tế (cache theo màu do xe máy menu tạo trước:
## 1,8 / 1,2) nên ban ngày trông như trước (cả Màn 1).
## Giữ trong biến tĩnh riêng (không phải CharacterBuilder._mat_cache, bị ViceStyle thay mới khi đổi phong cách) để
## set_traffic_lamps() luôn tới được mọi xe đã bake trước đó. Năng lượng ngày > 0,5 nên ViceStyle không coi là soft emitter.
const TRAFFIC_LAMPS: Dictionary = {
	"head": [Color("#FFF4C8"), 1.8, 4.5],        # [màu, năng lượng ngày, năng lượng đêm]
	"tail": [Color("#E53935"), 1.2, 3.0],
	"moto_head": [Color("#FFF4C8"), 1.8, 4.5],
	"moto_tail": [Color("#E53935"), 1.2, 3.0],
}
static var _traffic_lamp_mats: Dictionary = {}
static var _traffic_lamps_lit: bool = false

static func traffic_lamp(kind: String) -> StandardMaterial3D:
	if _traffic_lamp_mats.has(kind):
		return _traffic_lamp_mats[kind]
	var spec: Array = TRAFFIC_LAMPS.get(kind, TRAFFIC_LAMPS["head"])
	var m := StandardMaterial3D.new()
	m.albedo_color = spec[0]
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = spec[0]
	m.emission_energy_multiplier = float(spec[2] if _traffic_lamps_lit else spec[1])
	_traffic_lamp_mats[kind] = m
	return m

## Bật (đêm) / tắt (ngày, mờ như cũ) đèn của mọi xe giao thông: chỉ đổi 4 vật liệu dùng chung, không đụng từng xe.
## Luôn ghi lại giá trị (không return sớm). Giá trị gốc ViceStyle đã lưu (meta "vice_orig", _unstylize ghi lại khi về
## đồ hoạ cổ điển) cũng được cập nhật theo trạng thái hiện tại: không thì năng lượng đêm lưu lúc chuyển kiểu sẽ quay lại
## ban ngày (vd. đêm FreeRoam vice -> menu đổi cổ điển -> đèn xe buýt Màn 1 sáng rực).
static func set_traffic_lamps(on: bool) -> void:
	_traffic_lamps_lit = on
	for kind: String in TRAFFIC_LAMPS.keys():
		var spec: Array = TRAFFIC_LAMPS[kind]
		var m: StandardMaterial3D = traffic_lamp(kind)
		var e: float = float(spec[2] if on else spec[1])
		m.emission_enabled = true
		m.emission_energy_multiplier = e
		if m.has_meta("vice_orig"):
			var o: Dictionary = m.get_meta("vice_orig")
			o["emission_energy_multiplier"] = e
			o["emission_enabled"] = true
			m.set_meta("vice_orig", o)

static func traffic_lamps_on() -> bool:
	return _traffic_lamps_lit

static func _textured(key: String, fallback: Color, albedo_file: String, normal_file: String, rough: float, metal: float, uv_scale: float) -> StandardMaterial3D:
	if CharacterBuilder._mat_cache.has(key):
		return CharacterBuilder._mat_cache[key]
	var m := StandardMaterial3D.new()
	m.roughness = rough
	m.metallic = metal
	var t: Texture2D = CharacterBuilder._tex(albedo_file)
	if t:
		m.albedo_texture = t
		m.albedo_color = Color.WHITE
	else:
		m.albedo_color = fallback
	var n: Texture2D = CharacterBuilder._tex(normal_file)
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	CharacterBuilder._style_mat(m, 0.01)
	CharacterBuilder._mat_cache[key] = m
	return m

# ===========================================================================
# HELPER
# ===========================================================================
## Ống trụ nối hai điểm a→b (trục Y của CylinderMesh quay theo đoạn thẳng)
static func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, r2: float = -1.0) -> MeshInstance3D:
	var d: Vector3 = b - a
	var len: float = d.length()
	var mi: MeshInstance3D = CharacterBuilder._cyl(parent, (a + b) * 0.5, r, r if r2 < 0.0 else r2, maxf(len, 0.001), mat)
	if len > 0.0001:
		var up: Vector3 = d / len
		var ref: Vector3 = Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var x_axis: Vector3 = up.cross(ref).normalized()
		var z_axis: Vector3 = x_axis.cross(up).normalized()
		mi.basis = Basis(x_axis, up, z_axis)
	return mi

## Gộp mọi MeshInstance3D dưới `root` thành 1 MeshInstance3D (giữ vật liệu theo surface); root bị huỷ.
static func bake_into(parent: Node3D, root: Node3D, name: String, pos: Vector3, yaw: float = 0.0) -> MeshInstance3D:
	var mesh: ArrayMesh = CharacterBuilder.bake(root)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	root.free()
	return mi

# ===========================================================================
# BÁNH XE
# ===========================================================================
static func build_wheel(parent: Node3D, pos: Vector3, radius: float = 0.3, width: float = 0.1, spokes: int = 5, rim_color: Color = Color("#C9CED3"), basis: Basis = Basis.IDENTITY) -> Node3D:
	var w := Node3D.new()
	w.name = "Wheel"
	w.position = pos
	w.basis = basis # cho phép bù phép xoay có sẵn của pivot cha (trục lốp phải là trục X của xe)
	parent.add_child(w)
	var r_in: float = radius - width * 1.15
	# lốp (torus trục X) + vành kim loại mảnh + moay-ơ + nan hoa + đĩa phanh
	CharacterBuilder._torus(w, Vector3.ZERO, r_in, radius, rubber(), Vector3(0.0, 0.0, PI * 0.5))
	CharacterBuilder._torus(w, Vector3.ZERO, r_in - 0.018, r_in + 0.006, CharacterBuilder._mat("rim_" + rim_color.to_html(false), rim_color, 0.3, 0.8), Vector3(0.0, 0.0, PI * 0.5))
	CharacterBuilder._cyl(w, Vector3.ZERO, width * 0.5, width * 0.5, width * 1.25, chrome(), Vector3(0.0, 0.0, PI * 0.5))
	var sl: float = r_in - 0.01
	for i: int in range(spokes):
		var a: float = float(i) * TAU / float(spokes)
		var spoke: MeshInstance3D = CharacterBuilder._box(w, Vector3(0.0, cos(a) * sl * 0.5, sin(a) * sl * 0.5), Vector3(width * 0.45, sl, width * 0.3), CharacterBuilder._mat("rim_" + rim_color.to_html(false), rim_color, 0.3, 0.8))
		spoke.rotation.x = -a
	CharacterBuilder._cyl(w, Vector3(width * 0.62, 0.0, 0.0), radius * 0.52, radius * 0.52, 0.006, steel(), Vector3(0.0, 0.0, PI * 0.5))
	return w

# ===========================================================================
# XE TAY GA
# ===========================================================================
## Xe tay ga đứng yên hoặc xe NPC. Trả về {"root","front_wheel","rear_wheel","handlebar"} (baked: chỉ "root").
static func build_scooter(parent: Node3D, pos: Vector3, yaw: float, paint_color: Color, opts: Dictionary = {}) -> Dictionary:
	var root := Node3D.new()
	root.name = String(opts.get("name", "Scooter"))
	var front := Node3D.new()
	front.name = "FrontWheel"
	front.position = Vector3(0.0, 0.3, -0.62)
	var rear := Node3D.new()
	rear.name = "RearWheel"
	rear.position = Vector3(0.0, 0.3, 0.62)
	var bar := Node3D.new()
	bar.name = "HandlebarPivot"
	bar.position = Vector3(0.0, 0.98, -0.48)
	root.add_child(front)
	root.add_child(rear)
	root.add_child(bar)
	build_scooter_parts(root, front, rear, bar, paint_color, opts)
	if bool(opts.get("baked", false)):
		var mi: MeshInstance3D = bake_into(parent, root, root.name, pos, yaw)
		return {"root": mi}
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	return {"root": root, "front_wheel": front, "rear_wheel": rear, "handlebar": bar}

static func build_scooter_parts(root: Node3D, front: Node3D, rear: Node3D, bar: Node3D, paint_color: Color, opts: Dictionary = {}) -> void:
	var pm: Material = paint(paint_color)
	var dark: Material = black_plastic()
	var chr: Material = chrome()
	var stl: Material = steel()
	var lamps: bool = bool(opts.get("traffic_lamps", false))   # xe giao thông: đèn dùng chung bật theo giờ (OB-D6)
	# --- bánh. Pivot FrontWheel/RearWheel của PlayerBike.tscn đã xoay 90° quanh Z (dành cho hình trụ cũ) nên
	#     hình bánh được đặt basis = nghịch đảo basis pivot → trục lốp luôn là trục X của xe, rotate_x quay đúng chiều.
	build_wheel(front, Vector3.ZERO, 0.3, 0.1, 5, Color("#C9CED3"), front.basis.inverse())
	build_wheel(rear, Vector3.ZERO, 0.3, 0.1, 5, Color("#C9CED3"), rear.basis.inverse())
	# --- phuộc trước + cổ lái + chắn bùn trước
	for sx: float in [-1.0, 1.0]:
		_tube(root, Vector3(sx * 0.085, 0.3, -0.62), Vector3(sx * 0.07, 0.9, -0.5), 0.018, chr)
		_tube(root, Vector3(sx * 0.085, 0.3, -0.62), Vector3(sx * 0.085, 0.55, -0.57), 0.03, dark)
	CharacterBuilder._box(root, Vector3(0.0, 0.9, -0.5), Vector3(0.2, 0.05, 0.08), dark)
	_tube(root, Vector3(0.0, 0.68, -0.42), Vector3(0.0, 1.0, -0.5), 0.035, pm)
	for a_deg: float in [-24.0, 0.0, 24.0]:
		var a: float = deg_to_rad(a_deg)
		var fender: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.0, 0.3 + cos(a) * 0.345, -0.62 - sin(a) * 0.345), Vector3(0.13, 0.016, 0.15), pm)
		fender.rotation.x = -a
	# --- yếm trước (3 tấm) + hộc đồ + táp lô
	var shield: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.0, 0.62, -0.41), Vector3(0.4, 0.62, 0.03), pm)
	shield.rotation.x = -0.18
	for sx: float in [-1.0, 1.0]:
		var side: MeshInstance3D = CharacterBuilder._box(root, Vector3(sx * 0.24, 0.62, -0.35), Vector3(0.15, 0.5, 0.03), pm)
		side.rotation.y = sx * 0.62
		side.rotation.x = -0.18
	CharacterBuilder._box(root, Vector3(0.0, 0.93, -0.36), Vector3(0.44, 0.03, 0.22), pm)
	CharacterBuilder._box(root, Vector3(0.0, 0.6, -0.37), Vector3(0.34, 0.26, 0.02), dark)
	CharacterBuilder._box(root, Vector3(0.0, 0.7, -0.36), Vector3(0.1, 0.02, 0.02), chr)
	# --- sàn để chân + ốp hông + cốp xe
	CharacterBuilder._box(root, Vector3(0.0, 0.27, 0.02), Vector3(0.44, 0.04, 0.62), dark)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.12, 0.293, 0.02), Vector3(0.08, 0.006, 0.5), rubber())
		CharacterBuilder._box(root, Vector3(sx * 0.23, 0.33, 0.02), Vector3(0.02, 0.1, 0.6), pm)
	# --- thân sau (mesh tiện, trục xoay về Z) + ốp máy + động cơ
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = _scooter_body_mesh()
	body_mi.material_override = pm
	body_mi.position = Vector3(0.0, 0.62, 0.0)
	body_mi.rotation.x = PI * 0.5
	root.add_child(body_mi)
	CharacterBuilder._box(root, Vector3(0.0, 0.42, 0.38), Vector3(0.3, 0.2, 0.62), dark)
	CharacterBuilder._cyl(root, Vector3(0.13, 0.34, 0.46), 0.11, 0.11, 0.16, stl, Vector3(0.0, 0.0, PI * 0.5))
	CharacterBuilder._cyl(root, Vector3(-0.1, 0.36, 0.5), 0.07, 0.07, 0.18, dark, Vector3(0.0, 0.0, PI * 0.5))
	# --- yên da + ốp mép yên
	CharacterBuilder._capsule(root, Vector3(0.0, 0.87, 0.2), 0.16, 0.76, leather(), Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.12, 0.42, 1.0))
	CharacterBuilder._box(root, Vector3(0.0, 0.8, 0.2), Vector3(0.36, 0.03, 0.72), dark)
	# --- baga sau, đèn hậu, biển số, chắn bùn sau
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.14, 0.92, 0.82), Vector3(0.02, 0.02, 0.28), chr)
		_tube(root, Vector3(sx * 0.12, 0.72, 0.88), Vector3(sx * 0.14, 0.91, 0.9), 0.01, chr)
	CharacterBuilder._box(root, Vector3(0.0, 0.92, 0.95), Vector3(0.3, 0.02, 0.02), chr)
	CharacterBuilder._box(root, Vector3(0.0, 0.92, 0.82), Vector3(0.26, 0.015, 0.2), chr)
	CharacterBuilder._box(root, Vector3(0.0, 0.71, 0.92), Vector3(0.22, 0.08, 0.05), traffic_lamp("moto_tail") if lamps else lens(Color("#E53935"), 1.2))
	var plate_mat: StandardMaterial3D = _textured("plate_59", Color.WHITE, "prop_plate_59.png", "", 0.5, 0.0, 1.0)
	plate_mat.uv1_triplanar = false
	var plate: MeshInstance3D = CharacterBuilder._mi(root, _quad_mesh(Vector2(0.19, 0.14)), plate_mat, Vector3(0.0, 0.58, 0.955), Vector3(0.0, 0.0, 0.0), Vector3.ONE)
	plate.rotation.y = PI
	CharacterBuilder._box(root, Vector3(0.0, 0.58, 0.945), Vector3(0.2, 0.15, 0.012), dark)
	for a_deg: float in [30.0, 58.0]:
		var a: float = deg_to_rad(a_deg)
		var fender: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.0, 0.3 + cos(a) * 0.345, 0.62 + sin(a) * 0.345), Vector3(0.13, 0.016, 0.15), pm)
		fender.rotation.x = a
	# --- ống xả + pô + chân chống
	_tube(root, Vector3(0.14, 0.26, -0.05), Vector3(0.22, 0.3, 0.3), 0.025, stl)
	CharacterBuilder._cyl(root, Vector3(0.22, 0.3, 0.5), 0.045, 0.05, 0.5, stl, Vector3(PI * 0.5, 0.0, 0.0))
	CharacterBuilder._cyl(root, Vector3(0.22, 0.31, 0.47), 0.058, 0.058, 0.3, chr, Vector3(PI * 0.5, 0.0, 0.0))
	CharacterBuilder._torus(root, Vector3(0.22, 0.3, 0.75), 0.03, 0.05, chr, Vector3(PI * 0.5, 0.0, 0.0))
	_tube(root, Vector3(-0.18, 0.3, 0.18), Vector3(-0.25, 0.03, 0.12), 0.012, chr)
	CharacterBuilder._box(root, Vector3(-0.25, 0.02, 0.12), Vector3(0.06, 0.02, 0.05), dark)
	# --- ghi-đông: đèn pha, táp-lô, tay lái, bao tay, phanh, gương, xi-nhan
	CharacterBuilder._cyl(bar, Vector3(0.0, 0.0, -0.1), 0.12, 0.135, 0.16, pm, Vector3(PI * 0.5, 0.0, 0.0))
	CharacterBuilder._cyl(bar, Vector3(0.0, 0.0, -0.185), 0.105, 0.105, 0.012, traffic_lamp("moto_head") if lamps else lens(Color("#FFF4C8"), float(opts.get("headlight_energy", 1.8))), Vector3(PI * 0.5, 0.0, 0.0))
	CharacterBuilder._cyl(bar, Vector3(0.0, 0.085, -0.02), 0.05, 0.05, 0.03, dark, Vector3(0.5, 0.0, 0.0))
	CharacterBuilder._cyl(bar, Vector3(0.0, 0.1, -0.03), 0.04, 0.04, 0.004, CharacterBuilder._mat("dial", Color("#F4F4F4"), 0.4, 0.0, 0.3), Vector3(0.5, 0.0, 0.0))
	CharacterBuilder._cyl(bar, Vector3(0.0, 0.05, 0.0), 0.015, 0.015, 0.72, chr, Vector3(0.0, 0.0, PI * 0.5))
	_tube(bar, Vector3(0.0, -0.14, 0.03), Vector3(0.0, 0.03, 0.0), 0.028, dark)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._cyl(bar, Vector3(sx * 0.31, 0.05, 0.0), 0.024, 0.024, 0.13, rubber(), Vector3(0.0, 0.0, PI * 0.5))
		var lever: MeshInstance3D = CharacterBuilder._box(bar, Vector3(sx * 0.3, 0.05, -0.05), Vector3(0.11, 0.012, 0.012), chr)
		lever.rotation.y = sx * 0.25
		_tube(bar, Vector3(sx * 0.2, 0.06, 0.0), Vector3(sx * 0.3, 0.3, 0.03), 0.008, chr)
		CharacterBuilder._sphere(bar, Vector3(sx * 0.3, 0.31, 0.03), 0.055, chr, Vector3(1.0, 1.25, 0.22))
		CharacterBuilder._sphere(bar, Vector3(sx * 0.3, 0.31, 0.02), 0.05, glass_dark(), Vector3(1.0, 1.25, 0.1))
		CharacterBuilder._box(bar, Vector3(sx * 0.14, -0.02, -0.12), Vector3(0.05, 0.03, 0.03), lens(Color("#FFB300"), 0.6))

static func _scooter_body_mesh() -> ArrayMesh:
	var key: String = "scooter_body"
	if CharacterBuilder._mesh_cache.has(key):
		return CharacterBuilder._mesh_cache[key]
	# (rx, y=dọc thân → sau khi xoay thành +Z, rz=nửa chiều cao)
	var prof: Array = [Vector3(0.15, 0.0, 0.15), Vector3(0.2, 0.18, 0.22), Vector3(0.21, 0.42, 0.23), Vector3(0.185, 0.62, 0.19), Vector3(0.12, 0.73, 0.13), Vector3(0.03, 0.79, 0.04)]
	var m: ArrayMesh = CharacterBuilder._lathe(prof, 20)
	CharacterBuilder._mesh_cache[key] = m
	return m

static func _quad_mesh(size: Vector2) -> QuadMesh:
	var key: String = "quad_%.3f_%.3f" % [size.x, size.y]
	if CharacterBuilder._mesh_cache.has(key):
		return CharacterBuilder._mesh_cache[key]
	var q := QuadMesh.new()
	q.size = size
	CharacterBuilder._mesh_cache[key] = q
	return q

# ===========================================================================
# XE BUÝT (2.5 × 2.8 × 7.5 m, đầu xe hướng -Z)
# ===========================================================================
static func build_bus(parent: Node3D, is_fbus: bool, baked: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "BusModel"
	var col: Color = Color("#F37021") if is_fbus else Color("#00A859")
	var pm: Material = paint(col)
	var white: Material = paint(Color("#F2F4F5"))
	var dark: Material = black_plastic()
	var glass: Material = glass_dark()
	# thân dưới + viền chân + vòm bánh
	CharacterBuilder._box(root, Vector3(0.0, 1.0, 0.0), Vector3(2.5, 1.35, 7.5), pm)
	CharacterBuilder._box(root, Vector3(0.0, 0.38, 0.0), Vector3(2.52, 0.14, 7.52), dark)
	for z: float in [-2.55, 2.45]:
		for sx: float in [-1.0, 1.0]:
			CharacterBuilder._box(root, Vector3(sx * 1.2, 0.55, z), Vector3(0.14, 0.75, 1.25), dark)
	# dải kính + trụ cửa sổ
	CharacterBuilder._box(root, Vector3(0.0, 2.12, 0.0), Vector3(2.46, 0.95, 7.3), glass)
	for i: int in range(6):
		var z: float = -3.0 + float(i) * 1.2
		for sx: float in [-1.0, 1.0]:
			CharacterBuilder._box(root, Vector3(sx * 1.235, 2.12, z), Vector3(0.05, 0.98, 0.08), white)
	CharacterBuilder._box(root, Vector3(0.0, 1.64, 0.0), Vector3(2.5, 0.06, 7.5), white)
	CharacterBuilder._box(root, Vector3(0.0, 2.6, 0.0), Vector3(2.5, 0.06, 7.5), white)
	# mái + máy lạnh + bảng tuyến
	CharacterBuilder._box(root, Vector3(0.0, 2.78, 0.0), Vector3(2.4, 0.3, 7.3), white)
	CharacterBuilder._box(root, Vector3(0.0, 3.0, 0.8), Vector3(1.6, 0.18, 1.9), CharacterBuilder._mat("bus_ac", Color("#D5D8DC"), 0.5, 0.2))
	CharacterBuilder._box(root, Vector3(0.0, 2.95, -3.5), Vector3(2.0, 0.34, 0.1), CharacterBuilder._mat("bus_sign", Color("#101418"), 0.3, 0.0))
	# kính lái trước/sau, cần gạt, đèn, cản, gương
	var ws: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.0, 2.05, -3.76), Vector3(2.3, 1.15, 0.05), glass)
	ws.rotation.x = -0.08
	CharacterBuilder._box(root, Vector3(0.0, 2.1, 3.76), Vector3(2.2, 1.0, 0.05), glass)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.85, 1.05, -3.77), Vector3(0.45, 0.22, 0.06), traffic_lamp("head"))
		CharacterBuilder._box(root, Vector3(sx * 0.9, 1.15, 3.77), Vector3(0.35, 0.3, 0.06), traffic_lamp("tail"))
		CharacterBuilder._box(root, Vector3(sx * 1.1, 0.75, -3.77), Vector3(0.25, 0.12, 0.06), lens(Color("#FFB300"), 0.6))
		_tube(root, Vector3(sx * 1.25, 2.3, -3.6), Vector3(sx * 1.55, 2.35, -3.75), 0.025, dark)
		CharacterBuilder._box(root, Vector3(sx * 1.58, 2.25, -3.75), Vector3(0.1, 0.4, 0.22), dark)
		var wiper: MeshInstance3D = CharacterBuilder._box(root, Vector3(sx * 0.5, 1.55, -3.8), Vector3(0.03, 0.7, 0.02), dark)
		wiper.rotation.z = sx * -0.5
	CharacterBuilder._box(root, Vector3(0.0, 0.5, -3.8), Vector3(2.5, 0.3, 0.14), dark)
	CharacterBuilder._box(root, Vector3(0.0, 0.5, 3.8), Vector3(2.5, 0.3, 0.14), dark)
	# cửa bên phải (+X): 2 cửa gập, khung + kính
	for z: float in [-2.2, 1.6]:
		CharacterBuilder._box(root, Vector3(1.255, 1.35, z), Vector3(0.03, 2.2, 1.2), white)
		CharacterBuilder._box(root, Vector3(1.27, 1.75, z), Vector3(0.02, 1.0, 1.05), glass)
		CharacterBuilder._box(root, Vector3(1.275, 1.35, z), Vector3(0.015, 2.2, 0.04), dark)
	# dải trang trí + tên xe hai bên (texture vẽ bằng code)
	var side_tex: String = "prop_bus_side_fbus.png" if is_fbus else "prop_bus_side_vinbus.png"
	var side_mat: StandardMaterial3D = _textured("bus_side_" + ("f" if is_fbus else "v"), col, side_tex, "", 0.45, 0.05, 1.0)
	side_mat.uv1_triplanar = false
	for sx: float in [-1.0, 1.0]:
		var band: MeshInstance3D = CharacterBuilder._mi(root, _quad_mesh(Vector2(6.4, 1.2)), side_mat, Vector3(sx * 1.262, 1.05, 0.0), Vector3(0.0, sx * PI * 0.5, 0.0), Vector3.ONE)
		band.name = "SideBand"
	# bánh
	for z: float in [-2.55, 2.45]:
		for sx: float in [-1.0, 1.0]:
			build_wheel(root, Vector3(sx * 1.05, 0.5, z), 0.5, 0.28, 6, Color("#9AA0A6"))
	if baked:
		var mi: MeshInstance3D = bake_into(parent, root, "BusModel", Vector3.ZERO)
		return mi
	parent.add_child(root)
	return root

# ===========================================================================
# Ô TÔ CON (xe chạy FreeRoam)
# ===========================================================================
## Ô tô con kiểu hatchback ~3,9 x 1,7 x 1,5 m, mặt trước hướng -Z như xe máy / xe buýt; baked = 1 MeshInstance3D.
static func build_car(parent: Node3D, paint_color: Color, baked: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "CarModel"
	var pm: Material = paint(paint_color)
	var dark: Material = black_plastic()
	var glass: Material = glass_dark()
	# thân dưới, nắp capô, khoang kính, mui
	CharacterBuilder._box(root, Vector3(0.0, 0.62, 0.0), Vector3(1.7, 0.62, 3.9), pm)
	CharacterBuilder._box(root, Vector3(0.0, 0.98, -1.25), Vector3(1.62, 0.12, 1.3), pm)
	CharacterBuilder._box(root, Vector3(0.0, 1.22, 0.25), Vector3(1.56, 0.6, 2.1), glass)
	CharacterBuilder._box(root, Vector3(0.0, 1.55, 0.3), Vector3(1.5, 0.08, 1.8), pm)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.79, 1.22, -0.78), Vector3(0.06, 0.58, 0.08), pm)      # trụ A
		CharacterBuilder._box(root, Vector3(sx * 0.79, 1.22, 1.27), Vector3(0.06, 0.58, 0.12), pm)       # trụ C
		CharacterBuilder._box(root, Vector3(sx * 0.86, 0.42, 0.0), Vector3(0.04, 0.16, 3.0), dark)       # ốp sườn
		CharacterBuilder._box(root, Vector3(sx * 0.62, 0.78, -1.96), Vector3(0.34, 0.14, 0.04), traffic_lamp("head"))
		CharacterBuilder._box(root, Vector3(sx * 0.66, 0.85, 1.96), Vector3(0.28, 0.16, 0.04), traffic_lamp("tail"))
		CharacterBuilder._box(root, Vector3(sx * 0.95, 1.1, -0.72), Vector3(0.14, 0.1, 0.2), dark)       # gương
	CharacterBuilder._box(root, Vector3(0.0, 0.42, -1.97), Vector3(1.72, 0.22, 0.08), dark)             # cản trước
	CharacterBuilder._box(root, Vector3(0.0, 0.42, 1.97), Vector3(1.72, 0.22, 0.08), dark)              # cản sau
	for z: float in [-1.25, 1.25]:
		for sx: float in [-1.0, 1.0]:
			build_wheel(root, Vector3(sx * 0.78, 0.32, z), 0.32, 0.2, 5, Color("#B0B6BC"))
	if baked:
		return bake_into(parent, root, "CarModel", Vector3.ZERO)
	parent.add_child(root)
	return root

# ===========================================================================
# NỘM GỖ VOVINAM (mặt nộm hướng -X: về phía võ sinh)
# ===========================================================================
static func build_training_dummy(parent: Node3D, main_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "DummyModel"
	parent.add_child(root)
	var w: Material = main_mat if main_mat else wood()
	var lth: Material = leather()
	var stl: Material = steel()
	CharacterBuilder._cyl(root, Vector3(0.0, 0.07, 0.0), 0.42, 0.46, 0.14, stl)
	CharacterBuilder._cyl(root, Vector3(0.0, 0.2, 0.0), 0.1, 0.1, 0.14, stl)
	CharacterBuilder._cyl(root, Vector3(0.0, 1.0, 0.0), 0.15, 0.17, 1.5, w)
	CharacterBuilder._torus(root, Vector3(0.0, 1.28, 0.0), 0.15, 0.175, stl)
	CharacterBuilder._torus(root, Vector3(0.0, 0.7, 0.0), 0.15, 0.175, stl)
	# ba tay gỗ chĩa về phía võ sinh (-X) + 1 chân
	for arm: Array in [[1.32, 0.42, -0.2], [1.32, -0.42, 0.2], [1.02, 0.0, 0.0]]:
		var y: float = arm[0]
		var yaw: float = arm[1]
		var pitch: float = arm[2]
		var dir := Vector3(-cos(yaw), sin(pitch), sin(yaw)).normalized()
		_tube(root, Vector3(0.0, y, 0.0) + dir * 0.12, Vector3(0.0, y, 0.0) + dir * 0.6, 0.045, w, 0.035)
	_tube(root, Vector3(0.0, 0.55, 0.0), Vector3(-0.42, 0.25, 0.0), 0.05, w, 0.04)
	# đệm đầu bọc da + dây đai
	CharacterBuilder._sphere(root, Vector3(0.0, 1.95, 0.0), 0.2, lth, Vector3(0.95, 1.15, 0.95))
	CharacterBuilder._torus(root, Vector3(0.0, 1.92, 0.0), 0.19, 0.215, CharacterBuilder._mat("strap_red", Color("#B03A2E"), 0.8))
	return root

# ===========================================================================
# CÂY & CỘT ĐÈN
# ===========================================================================
static func build_tree(parent: Node3D, pos: Vector3, m: Dictionary, scale: float = 1.0, seed_val: int = 0, baked: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Tree"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + int(pos.x * 7.0 + pos.z * 13.0)
	var trunk: Material = m.get("trunk", wood())
	var leafs: Array = [m.get("leaf", CharacterBuilder._mat("leaf_a", Color("#3E8E41"), 0.9)), m.get("leaf2", CharacterBuilder._mat("leaf_b", Color("#2E7D32"), 0.9)), m.get("leaf3", CharacterBuilder._mat("leaf_c", Color("#5BA64A"), 0.9))]
	var h: float = rng.randf_range(4.4, 6.2) * scale
	# thân cong 3 đoạn + rễ bạnh
	var p0 := Vector3.ZERO
	var bend := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)) * scale
	var p1: Vector3 = Vector3(0.0, h * 0.45, 0.0) + bend
	var p2: Vector3 = Vector3(0.0, h, 0.0) + bend * 1.6
	_tube(root, p0, p1, 0.3 * scale, trunk, 0.22 * scale)
	_tube(root, p1, p2, 0.22 * scale, trunk, 0.14 * scale)
	CharacterBuilder._cyl(root, Vector3(0.0, 0.12 * scale, 0.0), 0.28 * scale, 0.5 * scale, 0.25 * scale, trunk)
	# cành + khối lá quanh đầu cành
	var n_branch: int = rng.randi_range(4, 5)
	for i: int in range(n_branch):
		var a: float = float(i) * TAU / float(n_branch) + rng.randf_range(-0.3, 0.3)
		var up: float = rng.randf_range(0.35, 0.7)
		var len: float = rng.randf_range(1.6, 2.4) * scale
		var dir := Vector3(cos(a) * (1.0 - up), up, sin(a) * (1.0 - up)).normalized()
		var tip: Vector3 = p2 + dir * len
		_tube(root, p2 - Vector3(0.0, 0.3 * scale, 0.0), tip, 0.1 * scale, trunk, 0.05 * scale)
		var r: float = rng.randf_range(1.2, 1.7) * scale
		CharacterBuilder._sphere(root, tip + Vector3(0.0, r * 0.35, 0.0), r, leafs[rng.randi() % 3], Vector3(1.0, 0.72, 1.0))
		CharacterBuilder._sphere(root, tip + dir * r * 0.35 + Vector3(0.0, r * 0.1, 0.0), r * 0.7, leafs[rng.randi() % 3], Vector3(1.0, 0.65, 1.0))
	CharacterBuilder._sphere(root, p2 + Vector3(0.0, 1.3 * scale, 0.0), 1.9 * scale, leafs[rng.randi() % 3], Vector3(1.0, 0.7, 1.0))
	CharacterBuilder._sphere(root, p2 + Vector3(0.0, 0.5 * scale, 0.0), 1.5 * scale, leafs[1], Vector3(1.15, 0.6, 1.15))
	if baked:
		return bake_into(parent, root, "Tree", pos, rng.randf_range(0.0, TAU))
	root.position = pos
	root.rotation.y = rng.randf_range(0.0, TAU)
	parent.add_child(root)
	return root

static func build_lamp_post(parent: Node3D, pos: Vector3, height: float = 8.5, two_arms: bool = true, yaw: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "LampPost"
	var stl: Material = CharacterBuilder._mat("lamp_pole", Color("#9EA7AD"), 0.45, 0.7)
	CharacterBuilder._cyl(root, Vector3(0.0, 0.15, 0.0), 0.2, 0.26, 0.3, stl)
	CharacterBuilder._cyl(root, Vector3(0.0, height * 0.5, 0.0), 0.08, 0.14, height, stl)
	for sx: float in ([-1.0, 1.0] if two_arms else [1.0]):
		_tube(root, Vector3(0.0, height - 0.4, 0.0), Vector3(sx * 1.6, height + 0.3, 0.0), 0.05, stl, 0.04)
		var head: MeshInstance3D = CharacterBuilder._box(root, Vector3(sx * 1.85, height + 0.3, 0.0), Vector3(0.7, 0.14, 0.3), stl)
		head.rotation.z = sx * 0.08
		CharacterBuilder._box(root, Vector3(sx * 1.85, height + 0.22, 0.0), Vector3(0.6, 0.03, 0.24), lens(Color("#FFF2CC"), 1.5))
	var mi: MeshInstance3D = bake_into(parent, root, "LampPost", pos, yaw)
	return mi

# ===========================================================================
# CÂY CỌ v2 (phong cách Vice City, plan VC-2; port từ look-dev tests/preview_vice_lookdev.gd _frond / _vice_palm)
#   Thân: mesh CAO 1 m (y 0..1) gồm 5 khoanh thuôn, mỗi khoanh loe ở chân (gờ khoanh như thân cọ thật), hai màu xen kẽ
#   = 2 surface; cong sẵn PALM_CURVE m theo +X (t²). Mỗi instance kéo giãn Y = chiều cao (8,5..13 m) + trượt ngang theo
#   độ nghiêng (0..0,12 m/m), quay yaw ngẫu nhiên. Pháp tuyến thân nằm ngang (y = 0) nên phép kéo giãn Y không đổi hướng
#   pháp tuyến, dù renderer biến đổi nó bằng chính ma trận instance hay bằng nghịch đảo chuyển vị.
#   Tán: 12 tàu lá rủ cong hình chữ V nông (_palm_frond_mesh) + 3 trái dừa gộp thành 1 mesh (2 surface: lá, dừa),
#   đặt lên ngọn thân (đã tính độ cong + nghiêng), yaw và tỉ lệ 0,9..1,15 ngẫu nhiên.
# ===========================================================================
const PALM_H_MIN: float = 8.5
const PALM_H_MAX: float = 13.0
const PALM_LEAN_MAX: float = 0.12        # độ nghiêng thân (m ngang / m cao), như look-dev
const PALM_CURVE: float = 0.45           # độ cong nướng sẵn trong mesh thân: ngọn lệch 0,45 m (cong dần theo t²)
const PALM_BANDS: int = 5
const PALM_SIDES: int = 10
const PALM_FRONDS: int = 12
const PALM_COLLIDER_R: float = 0.28
const PALM_SINK: float = 0.1             # gốc thân lún 10 cm: mặt đất các cảnh nằm ở y -0,05..0

static var _palm_cache: Dictionary = {}

## {"trunk": ArrayMesh, "crown": ArrayMesh, "materials": {"leaf", "trunk", "ring", "nut"}} – dựng một lần, cache tĩnh.
static func palm_meshes() -> Dictionary:
	if not _palm_cache.is_empty():
		return _palm_cache
	var mats: Dictionary = _palm_materials()
	_palm_cache = {"trunk": _palm_trunk_mesh(mats), "crown": _palm_crown_mesh(mats), "materials": mats}
	return _palm_cache

static func _palm_materials() -> Dictionary:
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color("#3f9e52")
	leaf.roughness = 0.9
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trunk := StandardMaterial3D.new()
	trunk.albedo_color = Color("#a08c70")
	trunk.roughness = 0.95
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color("#7d6b55")
	ring.roughness = 0.95
	var nut := StandardMaterial3D.new()
	nut.albedo_color = Color("#6b4a2a")
	nut.roughness = 0.8
	return {"leaf": leaf, "trunk": trunk, "ring": ring, "nut": nut}

## Tam giác có mặt trước hướng `want` (Godot: mặt trước theo chiều kim đồng hồ, (b - a) x (c - a) ngược hướng want).
static func _palm_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, want: Vector3) -> void:
	if (b - a).cross(c - a).dot(want) > 0.0:
		var t: Vector3 = b
		b = c
		c = t
		var tn: Vector3 = nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)

static func _palm_trunk_mesh(mats: Dictionary) -> ArrayMesh:
	var sts: Array[SurfaceTool] = [SurfaceTool.new(), SurfaceTool.new()]
	for st: SurfaceTool in sts:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_top_r: float = 0.0
	for i: int in range(PALM_BANDS):
		var t0: float = float(i) / float(PALM_BANDS)
		var t1: float = float(i + 1) / float(PALM_BANDS)
		# bán kính như look-dev: chân khoanh loe rộng hơn ngọn khoanh dưới -> gờ khoanh
		var rb: float = lerpf(0.26, 0.18, t0)
		var rt: float = lerpf(0.22, 0.16, t0 + 0.2)
		var st: SurfaceTool = sts[i % 2]
		var c0 := Vector3(PALM_CURVE * t0 * t0, t0, 0.0)
		var c1 := Vector3(PALM_CURVE * t1 * t1, t1, 0.0)
		for k: int in range(PALM_SIDES):
			var a0: float = TAU * float(k) / float(PALM_SIDES)
			var a1: float = TAU * float(k + 1) / float(PALM_SIDES)
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var out_n: Vector3 = (d0 + d1).normalized()
			_palm_tri(st, c0 + d0 * rb, c0 + d1 * rb, c1 + d1 * rt, d0, d1, d1, out_n)
			_palm_tri(st, c0 + d0 * rb, c1 + d1 * rt, c1 + d0 * rt, d0, d1, d0, out_n)
			if i > 0:
				# gờ dưới chân khoanh (vành từ ngọn khoanh dưới ra chân khoanh này), nhìn thấy khi ngước lên
				_palm_tri(st, c0 + d0 * prev_top_r, c0 + d1 * prev_top_r, c0 + d1 * rb, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
				_palm_tri(st, c0 + d0 * prev_top_r, c0 + d1 * rb, c0 + d0 * rb, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
			if i == PALM_BANDS - 1:
				_palm_tri(st, c1, c1 + d0 * rt, c1 + d1 * rt, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP)
		prev_top_r = rt
	var mesh := ArrayMesh.new()
	for si: int in range(sts.size()):
		sts[si].index()
		sts[si].commit(mesh)
		mesh.surface_set_material(si, mats["trunk"] if si == 0 else mats["ring"])
	return mesh

## Một tàu lá (look-dev _frond): 8 đốt 0,5 m, chếch lên 28° rồi rủ dần 13°/đốt, rộng nhất ở giữa, gập chữ V nông.
static func _palm_frond_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 8
	var seg_len: float = 0.5
	var p := Vector3.ZERO
	var pitch: float = deg_to_rad(28.0)
	var pts: Array[Vector3] = []
	var widths: Array[float] = []
	for i: int in range(segs + 1):
		pts.append(p)
		var t: float = float(i) / float(segs)
		widths.append(lerpf(0.12, 0.95, sin(t * PI) * 0.9 + 0.1) * (1.0 - t * 0.55))
		p += Vector3(0.0, sin(pitch), cos(pitch)) * seg_len
		pitch -= deg_to_rad(13.0)
	for i: int in range(segs):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var wa: float = widths[i] * 0.5
		var wb: float = widths[i + 1] * 0.5
		var fold: float = 0.06
		var a_l := a + Vector3(-wa, -fold, 0.0)
		var a_r := a + Vector3(wa, -fold, 0.0)
		var b_l := b + Vector3(-wb, -fold, 0.0)
		var b_r := b + Vector3(wb, -fold, 0.0)
		for tri: Array in [[a, b, a_l], [a_l, b, b_l], [a, a_r, b], [a_r, b_r, b]]:
			for v: Vector3 in tri:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()

static func _palm_crown_mesh(mats: Dictionary) -> ArrayMesh:
	var frond: ArrayMesh = _palm_frond_mesh()
	var leaf := SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k: int in range(PALM_FRONDS):
		var rot := Vector3(deg_to_rad(rng.randf_range(-8.0, 10.0)), float(k) * TAU / float(PALM_FRONDS) + rng.randf_range(-0.12, 0.12), 0.0)
		var basis: Basis = Basis.from_euler(rot) * Basis.from_scale(Vector3.ONE * rng.randf_range(1.05, 1.35))
		leaf.append_from(frond, 0, Transform3D(basis, Vector3.ZERO))
	var nut := SurfaceTool.new()
	nut.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 8
	sm.rings = 4
	for k: int in range(3):
		nut.append_from(sm, 0, Transform3D(Basis.IDENTITY, Vector3(cos(k * 2.1) * 0.2, -0.25, sin(k * 2.1) * 0.2)))
	var mesh := ArrayMesh.new()
	leaf.commit(mesh)
	mesh.surface_set_material(0, mats["leaf"])
	nut.commit(mesh)
	mesh.surface_set_material(1, mats["nut"])
	return mesh

## [Transform3D thân, Transform3D tán] của một cây cọ gốc tại `pos` (hệ của parent).
static func _palm_xforms(pos: Vector3, height: float, yaw: float, lean: float, crown_yaw: float, crown_scale: float) -> Array[Transform3D]:
	var rot := Basis(Vector3.UP, yaw)
	var base: Vector3 = pos - Vector3(0.0, PALM_SINK, 0.0)
	# cột Y = (lean * h, h, 0): kéo giãn mesh cao 1 m thành h, trượt ngọn lệch lean * h theo +X cục bộ
	var trunk := Transform3D(rot * Basis(Vector3.RIGHT, Vector3(lean * height, height, 0.0), Vector3.BACK), base)
	var top: Vector3 = base + rot * Vector3(PALM_CURVE + lean * height, height + PALM_SINK, 0.0)
	var crown := Transform3D(Basis(Vector3.UP, crown_yaw) * Basis.from_scale(Vector3.ONE * crown_scale), top)
	return [trunk, crown]

## Dáng từng cây của một rừng cọ (hàm thuần, cùng seed -> cùng kết quả): {"trunk": Array[Transform3D],
## "crown": Array[Transform3D], "heights": PackedFloat32Array}. opts như build_palm_field (seed, heights).
static func palm_field_xforms(points: PackedVector3Array, opts: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	var fixed: PackedFloat32Array = opts.get("heights", PackedFloat32Array())
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var heights := PackedFloat32Array()
	for i: int in range(points.size()):
		var h: float = rng.randf_range(PALM_H_MIN, PALM_H_MAX)
		if i < fixed.size():
			h = fixed[i]
		var xf: Array[Transform3D] = _palm_xforms(points[i], h, rng.randf() * TAU, rng.randf_range(0.0, PALM_LEAN_MAX), rng.randf() * TAU, rng.randf_range(0.9, 1.15))
		trunks.append(xf[0])
		crowns.append(xf[1])
		heights.append(h)
	return {"trunk": trunks, "crown": crowns, "heights": heights}

## Rừng cọ: ONE MultiMeshInstance3D "Trunks" + ONE "Crowns" dưới Node3D "PalmField", toạ độ `points` trong hệ của
## `parent` (y = mặt đất). Meta: palm_count, palm_points (= points), palm_heights (chiều cao thân từng cây).
## opts: seed (1), heights (PackedFloat32Array theo điểm, mặc định ngẫu nhiên 8,5..13 m), cast_shadow (true: thân lẫn tán
## đổ bóng), colliders (false: chỉ để nhìn; true = một StaticBody3D "PalmColliders" với một CylinderShape3D r 0,28 m cao
## bằng thân mỗi cây). Không có điểm -> null.
static func build_palm_field(parent: Node3D, points: PackedVector3Array, opts: Dictionary = {}) -> Node3D:
	if points.is_empty():
		return null
	var pm: Dictionary = palm_meshes()
	var xfs: Dictionary = palm_field_xforms(points, opts)
	var heights: PackedFloat32Array = xfs["heights"]
	var n: int = points.size()
	var mm_t := MultiMesh.new()
	mm_t.transform_format = MultiMesh.TRANSFORM_3D
	mm_t.mesh = pm["trunk"]
	mm_t.instance_count = n
	var mm_c := MultiMesh.new()
	mm_c.transform_format = MultiMesh.TRANSFORM_3D
	mm_c.mesh = pm["crown"]
	mm_c.instance_count = n
	var field := Node3D.new()
	field.name = "PalmField"
	var body: StaticBody3D = null
	if bool(opts.get("colliders", false)):
		body = StaticBody3D.new()
		body.name = "PalmColliders"
	for i: int in range(n):
		mm_t.set_instance_transform(i, xfs["trunk"][i])
		mm_c.set_instance_transform(i, xfs["crown"][i])
		if body:
			var shape := CylinderShape3D.new()
			shape.radius = PALM_COLLIDER_R
			shape.height = heights[i]
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = points[i] + Vector3(0.0, heights[i] * 0.5, 0.0)
			body.add_child(cs)
	mm_t.set_meta("cine_xforms", (xfs["trunk"] as Array).slice(0, n))   # FreeRoam's cinematic clutter check (headless too)
	mm_c.set_meta("cine_xforms", (xfs["crown"] as Array).slice(0, n))
	var shadow: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(opts.get("cast_shadow", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for pair: Array in [["Trunks", mm_t], ["Crowns", mm_c]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = pair[0]
		mmi.multimesh = pair[1]
		mmi.cast_shadow = shadow
		field.add_child(mmi)
	if body:
		field.add_child(body)
	field.set_meta("palm_count", n)
	field.set_meta("palm_points", points)
	field.set_meta("palm_heights", heights)
	parent.add_child(field)
	return field

## Một cây cọ lẻ (FPTUCampusBuilder.build_royal_palm ở phong cách vice): Node3D "Palm" tại `pos` với MeshInstance3D
## "Trunk" + "Crown" dùng chung mesh của build_palm_field; dáng (yaw, nghiêng, tán) theo `seed_val`.
static func build_palm(parent: Node3D, pos: Vector3, height: float, seed_val: int = 0) -> Node3D:
	var pm: Dictionary = palm_meshes()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var xf: Array[Transform3D] = _palm_xforms(Vector3.ZERO, height, rng.randf() * TAU, rng.randf_range(0.0, PALM_LEAN_MAX), rng.randf() * TAU, rng.randf_range(0.9, 1.15))
	var p := Node3D.new()
	p.name = "Palm"
	p.position = pos
	parent.add_child(p)
	for pair: Array in [["Trunk", pm["trunk"], xf[0]], ["Crown", pm["crown"], xf[1]]]:
		var mi := MeshInstance3D.new()
		mi.name = pair[0]
		mi.mesh = pair[1]
		mi.transform = pair[2]
		p.add_child(mi)
	return p

# ===========================================================================
# CĂN TIN: khay cơm, bàn, ghế đẩu, dù
# ===========================================================================
static func build_tray(parent: Node3D, kind: String = "com") -> Node3D:
	var root := Node3D.new()
	root.name = "Tray"
	parent.add_child(root)
	var tray_mat: Material = CharacterBuilder._mat("tray_red", Color("#B03A2E"), 0.5)
	var porcelain: Material = CharacterBuilder._mat("porcelain", Color("#F7F7F2"), 0.25)
	CharacterBuilder._box(root, Vector3.ZERO, Vector3(0.5, 0.02, 0.36), tray_mat)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.245, 0.02, 0.0), Vector3(0.012, 0.035, 0.36), tray_mat)
		CharacterBuilder._box(root, Vector3(0.0, 0.02, sx * 0.175), Vector3(0.5, 0.035, 0.012), tray_mat)
	# dĩa cơm + cơm + đồ ăn
	CharacterBuilder._cyl(root, Vector3(-0.1, 0.018, 0.0), 0.11, 0.09, 0.016, porcelain)
	CharacterBuilder._sphere(root, Vector3(-0.12, 0.03, -0.02), 0.07, CharacterBuilder._mat("rice", Color("#FBFBF4"), 0.6), Vector3(1.0, 0.5, 1.0))
	match kind:
		"bun":
			CharacterBuilder._cyl(root, Vector3(-0.1, 0.03, 0.0), 0.095, 0.07, 0.07, porcelain)
			CharacterBuilder._sphere(root, Vector3(-0.1, 0.07, 0.0), 0.075, CharacterBuilder._mat("broth", Color("#C4833A"), 0.2, 0.0, 0.1), Vector3(1.0, 0.25, 1.0))
		_:
			for i: int in range(3):
				CharacterBuilder._box(root, Vector3(-0.05 + float(i) * 0.03, 0.045, 0.045), Vector3(0.028, 0.02, 0.028), CharacterBuilder._mat("thit_kho", Color("#6B3A1E"), 0.55))
			CharacterBuilder._sphere(root, Vector3(-0.07, 0.04, -0.06), 0.03, CharacterBuilder._mat("rau", Color("#3E8E41"), 0.8), Vector3(1.4, 0.5, 1.0))
	# chén canh, ly trà đá có ống hút, đũa
	CharacterBuilder._cyl(root, Vector3(0.1, 0.03, -0.09), 0.055, 0.04, 0.05, porcelain)
	CharacterBuilder._cyl(root, Vector3(0.1, 0.052, -0.09), 0.048, 0.048, 0.004, CharacterBuilder._mat("soup", Color("#D9A760"), 0.2, 0.0, 0.05))
	CharacterBuilder._cyl(root, Vector3(0.15, 0.06, 0.08), 0.035, 0.03, 0.11, CharacterBuilder._mat("tea", Color(0.75, 0.55, 0.3, 0.7), 0.2))
	var straw: MeshInstance3D = CharacterBuilder._cyl(root, Vector3(0.16, 0.12, 0.08), 0.004, 0.004, 0.16, CharacterBuilder._mat("straw", Color("#2ECC71"), 0.6))
	straw.rotation.z = -0.25
	for i: int in range(2):
		var chop: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.03 + float(i) * 0.012, 0.025, 0.12), Vector3(0.006, 0.006, 0.22), wood())
		chop.rotation.y = 0.12
	return root

static func build_table(parent: Node3D, pos: Vector3, size: Vector3 = Vector3(3.0, 0.76, 1.6), with_collision: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Table"
	root.position = pos
	parent.add_child(root)
	var top: Material = wood()
	var stl: Material = steel()
	CharacterBuilder._box(root, Vector3(0.0, size.y - 0.025, 0.0), Vector3(size.x, 0.05, size.z), top)
	CharacterBuilder._box(root, Vector3(0.0, size.y - 0.09, 0.0), Vector3(size.x - 0.2, 0.08, size.z - 0.2), CharacterBuilder._mat("apron", Color("#2C2F36"), 0.6, 0.4))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			CharacterBuilder._cyl(root, Vector3(sx * (size.x * 0.5 - 0.12), (size.y - 0.1) * 0.5, sz * (size.z * 0.5 - 0.12)), 0.03, 0.035, size.y - 0.1, stl)
		CharacterBuilder._cyl(root, Vector3(sx * (size.x * 0.5 - 0.12), 0.18, 0.0), 0.015, 0.015, size.z - 0.24, stl, Vector3(PI * 0.5, 0.0, 0.0))
	if with_collision:
		var sb := StaticBody3D.new()
		sb.add_to_group("slam_table")        # Q2: a fighter knocked into it slams the table (Impact.surface_of)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(size.x, size.y, size.z)
		cs.shape = bs
		cs.position = Vector3(0.0, size.y * 0.5, 0.0)
		sb.add_child(cs)
		root.add_child(sb)
	return root

static func build_stool(parent: Node3D, pos: Vector3, color: Color = Color("#1F5FA8")) -> Node3D:
	var root := Node3D.new()
	root.name = "Stool"
	root.position = pos
	parent.add_child(root)
	var seat: Material = CharacterBuilder._mat("stool_" + color.to_html(false), color, 0.5)
	var stl: Material = steel()
	CharacterBuilder._cyl(root, Vector3(0.0, 0.44, 0.0), 0.18, 0.17, 0.04, seat)
	for i: int in range(4):
		var a: float = float(i) * TAU / 4.0 + PI * 0.25
		_tube(root, Vector3(cos(a) * 0.11, 0.42, sin(a) * 0.11), Vector3(cos(a) * 0.17, 0.0, sin(a) * 0.17), 0.012, stl)
	CharacterBuilder._torus(root, Vector3(0.0, 0.14, 0.0), 0.14, 0.155, stl)
	return root

static func build_umbrella(parent: Node3D, pos: Vector3, color: Color = Color("#F37021")) -> Node3D:
	var root := Node3D.new()
	root.name = "Umbrella"
	root.position = pos
	parent.add_child(root)
	var stl: Material = steel()
	var cloth: Material = CharacterBuilder._cloth_mat("umb_" + color.to_html(false), color)
	CharacterBuilder._cyl(root, Vector3(0.0, 0.05, 0.0), 0.3, 0.32, 0.1, CharacterBuilder._mat("umb_base", Color("#4A4A4A"), 0.7))
	CharacterBuilder._cyl(root, Vector3(0.0, 1.35, 0.0), 0.03, 0.03, 2.6, stl)
	CharacterBuilder._cyl(root, Vector3(0.0, 2.55, 0.0), 0.0, 1.7, 0.5, cloth)
	CharacterBuilder._torus(root, Vector3(0.0, 2.3, 0.0), 1.66, 1.72, cloth)
	for i: int in range(8):
		var a: float = float(i) * TAU / 8.0
		_tube(root, Vector3(0.0, 2.8, 0.0), Vector3(cos(a) * 1.68, 2.31, sin(a) * 1.68), 0.012, stl)
	CharacterBuilder._sphere(root, Vector3(0.0, 2.84, 0.0), 0.05, stl)
	return root
