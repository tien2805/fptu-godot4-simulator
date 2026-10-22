# File: res://scripts/characters/PS2Head.gd
# Đầu người kiểu PS2 (phong cách Vice City): khối ít mặt (~300 tam giác) dựng từ bảng vòng RINGS, mặt vẽ Pillow
# chiếu phẳng từ phía trước (atlas 4 x 2 ô biểu cảm; đổi ô bằng uv1_offset của vật liệu riêng mỗi nhân vật), tóc là vỏ
# ít mặt theo kiểu tóc. Cùng hệ toạ độ với đầu tự dựng cũ của CharacterBuilder (pivot "Head" ở chân cằm, mặt nhìn -Z,
# tâm đầu ~y 0.12) nên kính / mũ bảo hiểm / mũ bảo vệ / mũ đầu bếp cũ vẫn khớp.
# Không dùng GameFX / StageManager ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name PS2Head
extends RefCounted

const HEAD_H: float = 0.235
const FACE_U_SPAN: float = 0.2
const BACK_UV_DEG: float = 100.0
const CELLS: Array[String] = ["open", "closed", "happy", "angry", "surprised", "done", "talk", "pain"]
const ATLAS_COLS: int = 4
const ATLAS_ROWS: int = 2
const SEGMENTS: int = 16
const SUPER_N: float = 2.6
## [y, nửa bề ngang, sâu phía trước, sâu phía sau] từ cằm (y 0) lên đỉnh đầu.
const RINGS: Array = [
	[0.000, 0.028, 0.058, 0.004],
	[0.022, 0.050, 0.080, 0.032],
	[0.050, 0.064, 0.094, 0.064],
	[0.080, 0.072, 0.100, 0.088],
	[0.110, 0.077, 0.101, 0.100],
	[0.140, 0.079, 0.099, 0.106],
	[0.170, 0.077, 0.093, 0.104],
	[0.198, 0.066, 0.077, 0.090],
	[0.220, 0.044, 0.050, 0.060],
	[0.235, 0.000, 0.000, 0.000],
]
const HAIR_STYLES: Array[String] = ["short", "side_part", "spiky", "undercut", "bob", "ponytail", "long", "bun"]
const HAIR_PUFF: float = 1.07
## Mép dưới của tóc (y, m) theo dải góc: [trước |θ| < 50°, hai bên < 110°, sau gáy].
const HAIRLINES: Dictionary = {
	"short": [0.180, 0.125, 0.040], "side_part": [0.172, 0.125, 0.040], "spiky": [0.182, 0.130, 0.045],
	"undercut": [0.176, 0.172, 0.150], "bob": [0.168, 0.030, 0.020], "ponytail": [0.176, 0.120, 0.060],
	"long": [0.168, 0.030, 0.010], "bun": [0.178, 0.122, 0.070],
}

static var _mesh_cache: Dictionary = {}


# ===========================================================================
# API
# ===========================================================================
## Dựng đầu PS2 dưới parent: pivot "Head" tại pos. Ghi rig["head"], rig["face_mesh"], rig["head_top"].
static func build(parent: Node3D, pos: Vector3, opts: Dictionary, rig: Dictionary) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1))
	var female: bool = bool(opts.get("female", false))
	var skin_idx: int = clampi(int(opts.get("skin", 1)), 0, CharacterBuilder.SKIN_TONES.size() - 1)
	var variant: int = clampi(int(opts.get("variant", rng.randi_range(0, 2))), 0, 2)
	var width: float = float(opts.get("width", 1.0))
	var k: Dictionary = {
		"w": snappedf(width * (0.95 if female else 1.0), 0.01),
		"jaw": snappedf((0.9 if female else 1.0) * rng.randf_range(0.94, 1.06), 0.01),
		"nose": snappedf((0.85 if female else 1.0) * rng.randf_range(0.88, 1.12), 0.01),
	}
	var head := Node3D.new()
	head.name = "Head"
	head.position = pos
	parent.add_child(head)
	rig["head"] = head
	var mi := MeshInstance3D.new()
	mi.name = "HeadMesh"
	mi.mesh = head_mesh(k)
	mi.material_override = face_material(skin_idx, female, variant)
	head.add_child(mi)
	rig["face_mesh"] = mi
	var outfit: Dictionary = opts.get("outfit", {})
	var hair_idx: int = clampi(int(opts.get("hair_color", 0)), 0, CharacterBuilder.HAIR_COLORS.size() - 1)
	if bool(outfit.get("chef_hat", false)) or bool(outfit.get("cap", false)):
		CharacterBuilder._build_hair(head, "short", hair_idx, outfit, width, rng)   # mũ + tóc ngắn của bộ dựng cũ (vừa đầu này)
	else:
		var hm := MeshInstance3D.new()
		hm.name = "Hair"
		hm.mesh = hair_mesh(String(opts.get("hair_style", "short")), k)
		hm.material_override = hair_material(hair_idx)
		head.add_child(hm)
	if bool(outfit.get("glasses", false)):
		_build_glasses(head, k)
	if bool(outfit.get("helmet", false)):
		CharacterBuilder._build_helmet(head, outfit.get("helmet_color", Color("#F1C40F")), width)
	var top := Node3D.new()
	top.name = "HeadTop"
	top.position = Vector3(0.0, 0.27, 0.0)
	head.add_child(top)
	rig["head_top"] = top
	head.set_meta("ps2_head", true)
	return head


## uv1_offset của ô biểu cảm (ô lạ -> "open").
static func cell_offset(expr: String) -> Vector3:
	var i: int = maxi(0, CELLS.find(expr))
	return Vector3(float(i % ATLAS_COLS) / float(ATLAS_COLS), float(floori(float(i) / float(ATLAS_COLS))) / float(ATLAS_ROWS), 0.0)


## Vật liệu mặt RIÊNG cho một nhân vật (đổi ô biểu cảm / chớp mắt không ảnh hưởng người khác).
static func face_material(skin_idx: int, female: bool, variant: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.85
	var tex: Texture2D = CharacterBuilder._tex("char_ps2_face_%s%s%d.png" % [CharacterBuilder.SKIN_KEYS[skin_idx], "f" if female else "m", variant])
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = Vector3(1.0 / float(ATLAS_COLS), 1.0 / float(ATLAS_ROWS), 1.0)
		m.uv1_offset = cell_offset("open")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		push_warning("PS2Head: thiếu atlas mặt PS2, dùng da trơn (chạy generate_character_textures.py --ps2-only)")
		m.albedo_color = CharacterBuilder.SKIN_TONES[skin_idx]
	m.set_meta("ps2_face", tex != null)
	return m


static func hair_material(idx: int) -> StandardMaterial3D:
	var key: String = "ps2_hair_%d" % idx
	if CharacterBuilder._mat_cache.has(key):
		return CharacterBuilder._mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = CharacterBuilder.HAIR_COLORS[idx]
	m.roughness = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var t: Texture2D = CharacterBuilder._tex("char_ps2_hair.png")
	if t:
		m.albedo_texture = t
	CharacterBuilder._mat_cache[key] = m
	return m


# ===========================================================================
# MESH ĐẦU
# ===========================================================================
static func head_mesh(k: Dictionary) -> ArrayMesh:
	var key: String = "head_%.2f_%.2f_%.2f" % [float(k.get("w", 1.0)), float(k.get("jaw", 1.0)), float(k.get("nose", 1.0))]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = TAU / float(SEGMENTS)
	for i: int in range(RINGS.size() - 1):
		for j: int in range(SEGMENTS):
			var th1: float = -PI + float(j) * step
			var th2: float = th1 + step
			var side: float = signf(th1 + step * 0.5)
			var a: Vector3 = _ring_point(RINGS[i], th1, k)
			var b: Vector3 = _ring_point(RINGS[i], th2, k)
			var c: Vector3 = _ring_point(RINGS[i + 1], th1, k)
			var d: Vector3 = _ring_point(RINGS[i + 1], th2, k)
			var want: Vector3 = _outward((a + b + c + d) * 0.25)
			_quad(st, a, b, c, d, _uv(a, th1, side), _uv(b, th2, side), _uv(c, th1, side), _uv(d, th2, side), want)
	# đáy cằm: quạt về tâm
	var under := Vector3(0.0, 0.004, -0.02)
	for j: int in range(SEGMENTS):
		var th1: float = -PI + float(j) * step
		var th2: float = th1 + step
		var side: float = signf(th1 + step * 0.5)
		var a: Vector3 = _ring_point(RINGS[0], th1, k)
		var b: Vector3 = _ring_point(RINGS[0], th2, k)
		_tri(st, a, b, under, _uv(a, th1, side), _uv(b, th2, side), _uv(under, 0.0, 0.0), Vector3(0.0, -1.0, -0.2))
	# mũi
	var nk: float = float(k.get("nose", 1.0))
	var nb := Vector3(0.0, 0.133, _front_z(0.133) - 0.003)
	var nt := Vector3(0.0, 0.093, _front_z(0.093) - 0.024 * nk)
	var nl := Vector3(-0.016, 0.089, _front_z(0.089) + 0.006)
	var nr := Vector3(0.016, 0.089, _front_z(0.089) + 0.006)
	var nn := Vector3(0.0, 0.086, _front_z(0.086) - 0.009 * nk)
	_tri(st, nb, nl, nt, _uv(nb, 0.0, 0.0), _uv(nl, 0.0, 0.0), _uv(nt, 0.0, 0.0), Vector3(-0.6, 0.2, -1.0))
	_tri(st, nb, nt, nr, _uv(nb, 0.0, 0.0), _uv(nt, 0.0, 0.0), _uv(nr, 0.0, 0.0), Vector3(0.6, 0.2, -1.0))
	_tri(st, nl, nn, nt, _uv(nl, 0.0, 0.0), _uv(nn, 0.0, 0.0), _uv(nt, 0.0, 0.0), Vector3(-0.3, -1.0, -0.6))
	_tri(st, nt, nn, nr, _uv(nt, 0.0, 0.0), _uv(nn, 0.0, 0.0), _uv(nr, 0.0, 0.0), Vector3(0.3, -1.0, -0.6))
	# tai: tấm phẳng, hai mặt
	var w: float = float(k.get("w", 1.0))
	for sx: float in [-1.0, 1.0]:
		var xe: float = sx * (0.077 * w + 0.004)
		var et := Vector3(xe, 0.150, 0.010)
		var ef := Vector3(xe, 0.124, -0.004)
		var eb := Vector3(xe, 0.100, 0.008)
		var ek := Vector3(xe + sx * 0.011, 0.127, 0.026)
		var th: float = sx * PI * 0.5
		var ut: Vector2 = _uv(et, th, sx)
		var uf: Vector2 = _uv(ef, th, sx)
		var ub: Vector2 = _uv(eb, th, sx)
		var uk: Vector2 = _uv(ek, th, sx)
		_tri(st, et, ef, ek, ut, uf, uk, Vector3(sx, 0.0, 0.3))
		_tri(st, ef, eb, ek, uf, ub, uk, Vector3(sx, 0.0, 0.3))
		_tri(st, et, ef, ek, ut, uf, uk, Vector3(0.2 * sx, 0.0, 1.0))
		_tri(st, ef, eb, ek, uf, ub, uk, Vector3(0.2 * sx, 0.0, 1.0))
	st.index()
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


# ===========================================================================
# TÓC
# ===========================================================================
static func hair_mesh(style: String, k: Dictionary) -> ArrayMesh:
	var key: String = "hair_%s_%.2f_%.2f" % [style, float(k.get("w", 1.0)), float(k.get("jaw", 1.0))]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var lines: Array = HAIRLINES.get(style, HAIRLINES["short"])
	var puff: float = HAIR_PUFF * (1.05 if style in ["bob", "long"] else 1.0)
	var lift: float = 0.006 + (0.012 if style == "undercut" else 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = TAU / float(SEGMENTS)
	for i: int in range(RINGS.size() - 1):
		var y0: float = float(RINGS[i][0])
		for j: int in range(SEGMENTS):
			var th1: float = -PI + float(j) * step
			var th2: float = th1 + step
			if y0 < _hairline(style, lines, th1 + step * 0.5):
				continue
			var a: Vector3 = _puffed(_ring_point(RINGS[i], th1, k), puff, lift)
			var b: Vector3 = _puffed(_ring_point(RINGS[i], th2, k), puff, lift)
			var c: Vector3 = _puffed(_ring_point(RINGS[i + 1], th1, k), puff, lift)
			var d: Vector3 = _puffed(_ring_point(RINGS[i + 1], th2, k), puff, lift)
			_quad(st, a, b, c, d, _huv(th1, a.y), _huv(th2, b.y), _huv(th1, c.y), _huv(th2, d.y), _outward((a + b + c + d) * 0.25))
	match style:
		"spiky":
			for s: int in range(7):
				var th: float = -0.9 + float(s) * 0.3
				var base: Vector3 = _puffed(_ring_point(RINGS[7], th, k), puff, lift)
				var out: Vector3 = _outward(base)
				var tip: Vector3 = base + out * 0.04 + Vector3(0.0, 0.025, 0.0)
				var side := Vector3(cos(th), 0.0, sin(th)) * 0.014
				var p1: Vector3 = base + side
				var p2: Vector3 = base - side
				var p3: Vector3 = base - out * 0.012 + Vector3(0.0, 0.01, 0.0)
				var uv := Vector2(0.5, 0.5)
				_tri(st, p1, p2, tip, uv, uv, uv, out)
				_tri(st, p2, p3, tip, uv, uv, uv, -side.normalized() + out)
				_tri(st, p3, p1, tip, uv, uv, uv, side.normalized() + out)
		"bun":
			_add_blob(st, Vector3(0.0, 0.205, 0.085), 0.042)
		"ponytail":
			_add_tube(st, Vector3(0.0, 0.15, 0.112), Vector3(0.0, -0.07, 0.17), 0.03, 0.016, 6)
		"long":
			_quad(st, Vector3(-0.088, -0.20, 0.10), Vector3(0.088, -0.20, 0.10), Vector3(-0.092, 0.07, 0.112), Vector3(0.092, 0.07, 0.112),
				Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 2.7), Vector2(1.0, 2.7), Vector3(0.0, 0.0, 1.0))
			for sx: float in [-1.0, 1.0]:
				_quad(st, Vector3(sx * 0.088, -0.02, -0.03), Vector3(sx * 0.090, -0.02, 0.07), Vector3(sx * 0.086, 0.15, -0.04), Vector3(sx * 0.090, 0.15, 0.08),
					Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.7), Vector2(1.0, 1.7), Vector3(sx, 0.0, 0.0))
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _hairline(style: String, lines: Array, th: float) -> float:
	var deg: float = absf(rad_to_deg(th))
	if deg < 50.0:
		if style == "side_part" and rad_to_deg(th) < -10.0:
			return float(lines[0]) - 0.008
		return float(lines[0])
	if deg < 110.0:
		return float(lines[1])
	return float(lines[2])


static func _puffed(p: Vector3, puff: float, lift: float) -> Vector3:
	return Vector3(p.x * puff, 0.12 + (p.y - 0.12) * (1.0 + (puff - 1.0) * 0.6) + lift, p.z * puff)


static func _huv(th: float, y: float) -> Vector2:
	return Vector2((th / TAU + 0.5) * 6.0, y * 10.0)


# ===========================================================================
# KÍNH (khung vuông kiểu thập niên 80, đặt trước mặt đầu PS2)
# ===========================================================================
static func _build_glasses(head: Node3D, k: Dictionary) -> void:
	var gm: StandardMaterial3D = CharacterBuilder._mat("ps2_glasses", Color("#16161A"), 0.4, 0.3)
	var w: float = float(k.get("w", 1.0))
	var y: float = 0.127
	var z: float = _front_z(y) - 0.008
	for sx: float in [-1.0, 1.0]:
		var cx: float = sx * 0.032 * w
		CharacterBuilder._box(head, Vector3(cx, y + 0.009, z), Vector3(0.03, 0.004, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx, y - 0.009, z), Vector3(0.03, 0.003, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx + sx * 0.016, y, z), Vector3(0.003, 0.021, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx - sx * 0.016, y, z), Vector3(0.003, 0.021, 0.004), gm)
		CharacterBuilder._box(head, Vector3(sx * 0.081 * w, y + 0.004, z + 0.05), Vector3(0.003, 0.003, 0.1), gm)
	CharacterBuilder._box(head, Vector3(0.0, y + 0.006, z), Vector3(0.008, 0.003, 0.004), gm)


# ===========================================================================
# HÌNH HỌC
# ===========================================================================
static func _ring_point(ring: Array, theta: float, k: Dictionary) -> Vector3:
	var s: float = sin(theta)
	var c: float = cos(theta)
	var ps: float = signf(s) * pow(absf(s), 2.0 / SUPER_N)
	var pc: float = pow(absf(c), 2.0 / SUPER_N)
	var y: float = float(ring[0])
	var w: float = float(ring[1]) * float(k.get("w", 1.0)) * (float(k.get("jaw", 1.0)) if y < 0.06 else 1.0)
	if c >= 0.0:
		return Vector3(w * ps, y, -float(ring[2]) * pc)
	return Vector3(w * ps, y, float(ring[3]) * pc)


## z mặt trước tại độ cao y (đường giữa mặt, x = 0).
static func _front_z(y: float) -> float:
	for i: int in range(RINGS.size() - 1):
		var r0: Array = RINGS[i]
		var r1: Array = RINGS[i + 1]
		if y <= float(r1[0]):
			var t: float = clampf((y - float(r0[0])) / maxf(float(r1[0]) - float(r0[0]), 0.0001), 0.0, 1.0)
			return -lerpf(float(r0[2]), float(r1[2]), t)
	return 0.0


## UV mặt: chiếu phẳng từ trước cho |θ| <= BACK_UV_DEG; sau đầu lấy cột viền da (trái/phải theo side của ô quad).
static func _uv(p: Vector3, theta: float, side: float) -> Vector2:
	var v: float = clampf(1.0 - p.y / HEAD_H, 0.01, 0.99)
	if absf(rad_to_deg(theta)) > BACK_UV_DEG:
		return Vector2(0.99 if side > 0.0 else 0.01, v)
	return Vector2(clampf(0.5 + p.x / FACE_U_SPAN, 0.01, 0.99), v)


static func _outward(p: Vector3) -> Vector3:
	var o := Vector3(p.x, (p.y - 0.12) * 0.8, p.z)
	return o.normalized() if o.length() > 0.0001 else Vector3.UP


## Tam giác với chiều quấn mặt trước của Godot (theo chiều kim đồng hồ: (c - a) x (b - a) hướng ra ngoài = want).
static func _tri(st: SurfaceTool, pa: Vector3, pb: Vector3, pc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, want: Vector3) -> void:
	if (pc - pa).cross(pb - pa).length_squared() < 1e-14:
		return
	if (pc - pa).cross(pb - pa).dot(want) < 0.0:
		var tp: Vector3 = pb
		pb = pc
		pc = tp
		var tu: Vector2 = ub
		ub = uc
		uc = tu
	st.set_uv(ua)
	st.add_vertex(pa)
	st.set_uv(ub)
	st.add_vertex(pb)
	st.set_uv(uc)
	st.add_vertex(pc)


## Tứ giác a-b (dưới), c-d (trên); tam giác suy biến (đỉnh đầu, cực cầu) tự bỏ.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, want: Vector3) -> void:
	_tri(st, a, b, c, ua, ub, uc, want)
	_tri(st, b, d, c, ub, ud, uc, want)


static func _add_blob(st: SurfaceTool, c: Vector3, r: float) -> void:
	var rings: int = 4
	var segs: int = 6
	for i: int in range(rings):
		var p0: float = PI * float(i) / float(rings) - PI * 0.5
		var p1: float = PI * float(i + 1) / float(rings) - PI * 0.5
		for j: int in range(segs):
			var t0: float = TAU * float(j) / float(segs)
			var t1: float = TAU * float(j + 1) / float(segs)
			var a: Vector3 = c + r * Vector3(cos(p0) * cos(t0), sin(p0), cos(p0) * sin(t0))
			var b: Vector3 = c + r * Vector3(cos(p0) * cos(t1), sin(p0), cos(p0) * sin(t1))
			var cc: Vector3 = c + r * Vector3(cos(p1) * cos(t0), sin(p1), cos(p1) * sin(t0))
			var d: Vector3 = c + r * Vector3(cos(p1) * cos(t1), sin(p1), cos(p1) * sin(t1))
			var uv := Vector2(t0 / TAU * 2.0, p0)
			_quad(st, a, b, cc, d, uv, uv, uv, uv, ((a + b + cc + d) * 0.25 - c).normalized())


static func _add_tube(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, segs: int) -> void:
	var axis: Vector3 = (p1 - p0).normalized()
	var ref: Vector3 = Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u: Vector3 = axis.cross(ref).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	for j: int in range(segs):
		var t0: float = TAU * float(j) / float(segs)
		var t1: float = TAU * float(j + 1) / float(segs)
		var o0: Vector3 = u * cos(t0) + v * sin(t0)
		var o1: Vector3 = u * cos(t1) + v * sin(t1)
		var a: Vector3 = p0 + o0 * r0
		var b: Vector3 = p0 + o1 * r0
		var c: Vector3 = p1 + o0 * r1
		var d: Vector3 = p1 + o1 * r1
		_quad(st, a, b, c, d, Vector2(t0, 0.0), Vector2(t1, 0.0), Vector2(t0, 2.0), Vector2(t1, 2.0), (o0 + o1).normalized())
		_tri(st, c, d, p1 + axis * 0.012, Vector2(t0, 2.0), Vector2(t1, 2.0), Vector2(t0, 2.1), axis)
