# File: res://scripts/cine/CineAlley.gd
# Phim trường của nguyên mẫu cinematic seg_d1_brawl: góc hẻm ban đêm dựng hoàn toàn bằng code (không ảnh AI, không asset
# ngoài): mặt đường ướt (độ nhám nhiễu -> vũng nước loang, SSR phản chiếu neon), tường hồng / xanh ngọc pastel Miami thập
# niên 80, cửa cuốn, cửa sổ đèn vàng, biển neon chữ nổi (TextMesh phát sáng + đèn màu hắt xuống đất ướt), cột đèn đường,
# cây cọ, xe tay ga giao hàng (PropBuilder.build_scooter) với thùng hàng, chồng thùng gỗ để đập vỡ (mảnh vỡ dựng sẵn, ẩn).
# Tên biển hiệu đều hư cấu. Trục: tường sau dọc X ở z = -4.7, tường phải ở x = 8, miệng hẻm mở ra phố phía -X.
class_name CineAlley
extends RefCounted

const CRATE: float = 0.62
const CRATE_POS: Vector3 = Vector3(-1.25, 0.0, -2.75)


## Dựng phim trường dưới parent. Trả {"crates": Node3D (chồng thùng nguyên), "debris": Array[Dictionary] (mảnh vỡ ẩn:
## node, vị trí / vận tốc / xoay ban đầu), "scooter": Node3D}.
static func build(parent: Node3D) -> Dictionary:
	var out: Dictionary = {}
	var root := Node3D.new()
	root.name = "Alley"
	parent.add_child(root)
	_ground(root)
	_walls(root)
	_signs(root)
	_street(root)
	var sc: Dictionary = PropBuilder.build_scooter(root, Vector3(3.7, 0.0, -3.55), PI * 0.5 + 0.12, Color("#7fd6c8"))
	var box := CharacterBuilder._box(sc["root"], Vector3(0.0, 1.05, 0.72), Vector3(0.46, 0.42, 0.46), _mat("box_teal", Color("#2fb3a0"), 0.6))
	_text(box, "GIAO LIỀN", Vector3(0.0, 0.02, 0.235), 0.07, Color("#fff4c2"), 0.0, Vector3(0.0, 0.0, 0.0))
	_text(box, "GIAO LIỀN", Vector3(0.0, 0.02, -0.235), 0.07, Color("#fff4c2"), 0.0, Vector3(0.0, PI, 0.0))
	out["scooter"] = sc["root"]
	_props(root)
	var cr: Dictionary = _crates(root)
	out["crates"] = cr["stack"]
	out["debris"] = cr["debris"]
	return out


# ---------------------------------------------------------------------------
static func _mat(key: String, col: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.set_meta("vice_done", true)   # phim trường tự chỉnh vật liệu: pass vật liệu của ViceStyle bỏ qua
	return m


static func _emit(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.set_meta("vice_done", true)
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Chữ nổi (TextMesh) – energy > 0: chữ neon phát sáng.
static func _text(parent: Node3D, txt: String, pos: Vector3, size: float, col: Color, energy: float, rot: Vector3) -> MeshInstance3D:
	var tm := TextMesh.new()
	tm.text = txt
	tm.font_size = 64
	tm.pixel_size = size / 64.0
	tm.depth = 0.02
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = _emit(col, energy) if energy > 0.0 else _mat("txt_" + col.to_html(false), col, 0.6)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _omni(parent: Node3D, pos: Vector3, col: Color, energy: float, rng_m: float, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	l.light_size = 0.4
	l.light_specular = 0.6
	parent.add_child(l)
	return l


# ---------------------------------------------------------------------------
static func _ground(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 40.0)
	mi.mesh = pm
	mi.position = Vector3(-4.0, 0.0, 6.0)
	var m := _mat("wet_asphalt", Color("#2a2636"), 1.0, 0.18)
	# độ nhám theo nhiễu: chỗ tối = vũng nước bóng loáng, chỗ sáng = nhựa đường khô hơn
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = 7
	fn.frequency = 0.012
	fn.fractal_octaves = 3
	nt.noise = fn
	nt.color_ramp = _ramp([Color(0.04, 0.04, 0.04), Color(0.1, 0.1, 0.1), Color(0.55, 0.55, 0.55)], [0.0, 0.45, 0.75])
	m.roughness_texture = nt
	m.roughness = 1.0
	var at := NoiseTexture2D.new()
	at.width = 512
	at.height = 512
	at.seamless = true
	var fa := FastNoiseLite.new()
	fa.seed = 3
	fa.frequency = 0.05
	at.noise = fa
	at.color_ramp = _ramp([Color(0.78, 0.76, 0.86), Color(1.0, 1.0, 1.0)], [0.0, 1.0])
	m.albedo_texture = at
	m.uv1_scale = Vector3(6.0, 4.0, 1.0)
	mi.material_override = m
	root.add_child(mi)
	# vỉa hè sát tường sau + vạch sơn
	_box(root, Vector3(0.0, 0.06, -4.2), Vector3(24.0, 0.12, 1.0), _mat("curb", Color("#6d6878"), 0.8))
	_box(root, Vector3(7.5, 0.06, 1.0), Vector3(1.0, 0.12, 11.5), _mat("curb", Color("#6d6878"), 0.8))
	var paint := _mat("road_paint", Color("#e8e2c8"), 0.35)
	for i: int in 6:
		_box(root, Vector3(-11.0 + float(i) * 2.2, 0.004, 3.4), Vector3(1.2, 0.008, 0.14), paint)


static func _ramp(cols: Array, offs: Array) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(cols)
	g.offsets = PackedFloat32Array(offs)
	return g


static func _walls(root: Node3D) -> void:
	var pink := _mat("wall_pink", Color("#c58aa6"), 0.9)
	var teal := _mat("wall_teal", Color("#4f9a94"), 0.9)
	var trim := _mat("wall_trim", Color("#f0e6d2"), 0.8)
	_box(root, Vector3(-1.0, 3.5, -4.9), Vector3(20.0, 7.0, 0.4), pink)
	_box(root, Vector3(8.2, 3.5, 0.6), Vector3(0.4, 7.0, 11.4), teal)
	_box(root, Vector3(-1.0, 3.1, -4.66), Vector3(20.0, 0.12, 0.12), trim)
	_box(root, Vector3(7.96, 3.1, 0.6), Vector3(0.12, 0.12, 11.4), trim)
	# cửa cuốn (sọc ngang) ở tường sau
	var shutter := _mat("shutter", Color("#8d93a3"), 0.55, 0.5)
	var dark := _mat("shutter_dark", Color("#3b3f4c"), 0.6, 0.4)
	for sx: float in [-5.4, 1.4]:
		_box(root, Vector3(sx, 1.35, -4.68), Vector3(3.0, 2.7, 0.06), shutter)
		for k: int in 13:
			_box(root, Vector3(sx, 0.12 + float(k) * 0.2, -4.64), Vector3(3.0, 0.03, 0.03), dark)
	# quán sáng đèn (cửa kính) giữa hai cửa cuốn
	_box(root, Vector3(-2.0, 1.35, -4.69), Vector3(2.6, 2.6, 0.05), _emit(Color("#ffcf8a"), 0.9))
	_box(root, Vector3(-2.0, 1.35, -4.64), Vector3(0.06, 2.6, 0.06), dark)
	_omni(root, Vector3(-2.0, 1.6, -3.6), Color("#ffb878"), 1.6, 5.5)
	# cửa sổ tầng trên: đèn vàng / tím, rèm
	var win_a := _emit(Color("#ffd58f"), 1.1)
	var win_b := _emit(Color("#c79cff"), 0.9)
	for i: int in 6:
		var x: float = -8.0 + float(i) * 2.8
		_box(root, Vector3(x, 4.7, -4.69), Vector3(1.2, 1.3, 0.04), win_a if i % 3 != 1 else win_b)
		_box(root, Vector3(x, 4.02, -4.6), Vector3(1.4, 0.08, 0.2), trim)
		# cục nóng điều hoà
		if i % 2 == 0:
			_box(root, Vector3(x + 1.1, 4.2, -4.45), Vector3(0.7, 0.5, 0.4), _mat("ac", Color("#d6d9de"), 0.7))
	for i: int in 3:
		var z: float = -2.6 + float(i) * 3.2
		_box(root, Vector3(7.99, 4.7, z), Vector3(0.04, 1.3, 1.1), win_a if i != 1 else win_b)
	# dây điện chằng chịt
	var wire := _mat("wire", Color("#111116"), 0.7)
	for i: int in 5:
		var y: float = 5.8 + float(i) * 0.18
		var w := _box(root, Vector3(1.0, y - 0.25, -1.0), Vector3(0.025, 0.025, 13.0), wire, Vector3(0.0, 0.62 + float(i) * 0.05, 0.04))
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _neon_frame(parent: Node3D, center: Vector3, size: Vector2, col: Color, rot: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = center
	holder.rotation = rot
	parent.add_child(holder)
	var m := _emit(col, 5.0)
	var t: float = 0.035
	_box(holder, Vector3(0.0, size.y * 0.5, 0.0), Vector3(size.x, t, t), m)
	_box(holder, Vector3(0.0, -size.y * 0.5, 0.0), Vector3(size.x, t, t), m)
	_box(holder, Vector3(size.x * 0.5, 0.0, 0.0), Vector3(t, size.y, t), m)
	_box(holder, Vector3(-size.x * 0.5, 0.0, 0.0), Vector3(t, size.y, t), m)


static func _signs(root: Node3D) -> void:
	var pink := Color("#ff4fb8")
	var cyan := Color("#3ff0ff")
	var amber := Color("#ffb13b")
	var violet := Color("#b06bff")
	# bảng nền tối cho chữ neon
	var board := _mat("sign_board", Color("#1a1424"), 0.7)
	_box(root, Vector3(-5.4, 3.55, -4.6), Vector3(3.6, 0.95, 0.12), board)
	_text(root, "KARAOKE 99", Vector3(-5.4, 3.55, -4.5), 0.62, pink, 6.0, Vector3.ZERO)
	_neon_frame(root, Vector3(-5.4, 3.55, -4.5), Vector2(3.4, 0.82), violet, Vector3.ZERO)
	_omni(root, Vector3(-5.4, 3.0, -3.3), pink, 3.2, 8.0)
	_box(root, Vector3(1.4, 3.55, -4.6), Vector3(3.2, 0.95, 0.12), board)
	_text(root, "PHỞ ĐÊM", Vector3(1.4, 3.6, -4.5), 0.66, cyan, 6.0, Vector3.ZERO)
	_neon_frame(root, Vector3(1.4, 3.55, -4.5), Vector2(3.0, 0.82), cyan, Vector3.ZERO)
	_omni(root, Vector3(1.4, 3.0, -3.2), cyan, 3.0, 8.0)
	_text(root, "CƠM TẤM 24H", Vector3(-2.0, 2.95, -4.6), 0.34, amber, 5.0, Vector3.ZERO)
	# biển dọc "BIDA" trên tường phải
	var blade := Node3D.new()
	blade.position = Vector3(7.55, 3.9, -1.2)
	root.add_child(blade)
	_box(blade, Vector3.ZERO, Vector3(0.75, 2.4, 0.14), board, Vector3(0.0, PI * 0.5, 0.0))
	var letters: String = "BIDA"
	for i: int in letters.length():
		_text(blade, letters[i], Vector3(-0.09, 0.84 - float(i) * 0.56, 0.0), 0.5, amber, 6.0, Vector3(0.0, -PI * 0.5, 0.0))
	_omni(root, Vector3(6.6, 3.4, -1.2), amber, 2.6, 7.0)
	# mũi tên neon trên tường phải
	_text(root, "» SỬA XE «", Vector3(7.95, 2.7, 2.6), 0.42, pink, 5.5, Vector3(0.0, -PI * 0.5, 0.0))
	_omni(root, Vector3(7.0, 2.4, 2.6), pink, 1.8, 6.0)
	# đèn chính cho cảnh đánh (ánh trăng tím nhạt từ trên + đèn viền xanh phía sau)
	var key := SpotLight3D.new()
	key.position = Vector3(0.5, 7.5, 4.0)
	key.rotation_degrees = Vector3(-62.0, 0.0, 0.0)
	key.light_color = Color("#ffd9f0")
	key.light_energy = 3.2
	key.spot_range = 16.0
	key.spot_angle = 38.0
	key.shadow_enabled = true
	key.light_specular = 0.12   # mặt đất ướt: không phản chiếu đốm sáng của nguồn sáng vô hình
	root.add_child(key)
	var rim := SpotLight3D.new()
	rim.position = Vector3(3.0, 5.0, -3.8)
	rim.rotation_degrees = Vector3(-35.0, 180.0, 0.0)
	rim.light_color = Color("#6f8cff")
	rim.light_energy = 3.5
	rim.spot_range = 14.0
	rim.spot_angle = 50.0
	rim.light_specular = 0.25
	root.add_child(rim)


static func _street(root: Node3D) -> void:
	# cột đèn đường + đèn natri cam ở miệng hẻm, cây cọ, dãy nhà phía bên kia phố
	PropBuilder.build_lamp_post(root, Vector3(-8.5, 0.0, 1.5), 7.0, false, 0.0)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(-6.65, 7.1, 1.5)
	lamp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lamp.light_color = Color("#ffae5c")
	lamp.light_energy = 5.0
	lamp.spot_range = 12.0
	lamp.spot_angle = 55.0
	lamp.shadow_enabled = true
	root.add_child(lamp)
	PropBuilder.build_palm(root, Vector3(-10.5, 0.0, -3.6), 9.5, 4)
	PropBuilder.build_palm(root, Vector3(-13.0, 0.0, 5.0), 11.0, 9)
	var far := _mat("far_bldg", Color("#3a2e52"), 0.9)
	var lit := _emit(Color("#ffcf7a"), 1.2)
	var lit2 := _emit(Color("#7ae2ff"), 1.0)
	for b: int in 3:
		var z: float = -6.0 + float(b) * 7.0
		var h: float = 9.0 + float(b % 2) * 4.0
		_box(root, Vector3(-17.0, h * 0.5, z), Vector3(4.0, h, 6.0), far)
		for r: int in int(h / 1.6):
			for c: int in 3:
				if (r * 3 + c + b) % 4 == 0:
					continue
				_box(root, Vector3(-14.98, 1.2 + float(r) * 1.6, z - 1.8 + float(c) * 1.8), Vector3(0.04, 0.7, 0.9), lit if (r + c) % 3 else lit2)
	_text(root, "KHÁCH SẠN SAO MAI", Vector3(-14.9, 7.6, 1.0), 0.8, Color("#ff5f9e"), 6.0, Vector3(0.0, PI * 0.5, 0.0))


static func _props(root: Node3D) -> void:
	var bag := _mat("trash_bag", Color("#15151c"), 0.35, 0.1)
	for p: Vector3 in [Vector3(6.9, 0.25, 3.8), Vector3(7.2, 0.22, 4.4), Vector3(6.6, 0.2, 4.6), Vector3(-6.8, 0.22, -3.9)]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.5
		mi.mesh = sm
		mi.material_override = bag
		mi.position = p
		root.add_child(mi)
	PropBuilder.build_stool(root, Vector3(-4.4, 0.0, -3.5), Color("#e8436f"))
	PropBuilder.build_stool(root, Vector3(-3.8, 0.0, -3.7), Color("#3fa7e8"))
	# thùng nhựa xanh + két bia
	_box(root, Vector3(5.6, 0.25, -3.9), Vector3(0.8, 0.5, 0.55), _mat("crate_blue", Color("#2a6fd6"), 0.5))
	_box(root, Vector3(5.6, 0.72, -3.9), Vector3(0.7, 0.44, 0.5), _mat("crate_red", Color("#d63a3a"), 0.5))


## Chồng 5 thùng gỗ ở góc + mảnh vỡ (ẩn) cho cú va: mỗi mảnh {node, p0 (vị trí trong chồng), v (m/s), w (rad/s)}.
static func _crates(root: Node3D) -> Dictionary:
	var stack := Node3D.new()
	stack.name = "Crates"
	stack.position = CRATE_POS
	stack.rotation.y = 0.18
	root.add_child(stack)
	var wood_a := _mat("crate_wood", Color("#b07a45"), 0.8)
	var wood_b := _mat("crate_wood_dark", Color("#6e4526"), 0.85)
	var spots: Array[Vector3] = [Vector3(-0.33, 0.0, 0.0), Vector3(0.33, 0.0, 0.05), Vector3(0.0, 0.0, -0.62),
		Vector3(-0.15, CRATE, -0.05), Vector3(0.28, CRATE, -0.1)]
	for si: int in spots.size():
		var p: Vector3 = spots[si]
		var c := Node3D.new()
		c.position = p + Vector3(0.0, CRATE * 0.5, 0.0)
		c.rotation.y = [0.05, -0.09, 0.11, -0.04, 0.08][si]
		stack.add_child(c)
		_box(c, Vector3.ZERO, Vector3(CRATE, CRATE, CRATE) * 0.96, wood_a)
		for sy: float in [-0.5, 0.0, 0.5]:
			_box(c, Vector3(0.0, sy * CRATE * 0.86, CRATE * 0.49), Vector3(CRATE, 0.08, 0.03), wood_b)
			_box(c, Vector3(0.0, sy * CRATE * 0.86, -CRATE * 0.49), Vector3(CRATE, 0.08, 0.03), wood_b)
			_box(c, Vector3(CRATE * 0.49, sy * CRATE * 0.86, 0.0), Vector3(0.03, 0.08, CRATE), wood_b)
			_box(c, Vector3(-CRATE * 0.49, sy * CRATE * 0.86, 0.0), Vector3(0.03, 0.08, CRATE), wood_b)
	var debris: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var holder := Node3D.new()
	holder.name = "Debris"
	root.add_child(holder)
	for i: int in 34:
		var plank: bool = i < 26
		var size: Vector3 = Vector3(rng.randf_range(0.35, 0.62), 0.08, 0.025) if plank else Vector3.ONE * rng.randf_range(0.06, 0.14)
		var mi := _box(holder, Vector3.ZERO, size, wood_a if i % 3 else wood_b)
		mi.visible = false
		var p0: Vector3 = CRATE_POS + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.1, CRATE * 1.8), rng.randf_range(-0.8, 0.4))
		# đẩy ra ngoài theo hướng va (người bay tới từ phía +X +Z) + toả tròn, một phần bắn về phía máy quay (+Z)
		var dir: Vector3 = (p0 - (CRATE_POS + Vector3(0.7, 0.6, 0.5))).normalized()
		var v: Vector3 = dir * rng.randf_range(2.0, 5.5) + Vector3(rng.randf_range(-1.5, 1.0), rng.randf_range(1.5, 5.0), rng.randf_range(-0.5, 3.5))
		var w: Vector3 = Vector3(rng.randf_range(-14.0, 14.0), rng.randf_range(-10.0, 10.0), rng.randf_range(-14.0, 14.0))
		debris.append({"node": mi, "p0": p0, "v": v, "w": w, "r0": Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU), "h": size.y * 0.5 if plank else size.x * 0.5})
	return {"stack": stack, "debris": debris}
