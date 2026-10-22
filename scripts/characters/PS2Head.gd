# File: res://scripts/characters/PS2Head.gd
# Đầu người kiểu PS2 (phong cách Vice City): khối ít mặt (~330 tam giác) dựng từ bảng vòng RINGS (sọ, gờ mày, gò má, hàm,
# cằm) + mũi hình nêm + tai phẳng; mặt vẽ Pillow chiếu phẳng từ phía trước (atlas 4 x 2 ô biểu cảm; đổi ô bằng uv1_offset của
# vật liệu riêng mỗi nhân vật), tóc là vỏ ít mặt theo kiểu tóc (cả khi đội mũ). Cùng hệ toạ độ với đầu tự dựng cũ của
# CharacterBuilder (pivot "Head" ở chân cằm, mặt nhìn -Z, tâm đầu ~y 0.12). Mũ trong nút "HatFit": mũ lưỡi trai / mũ đầu bếp dựng
# cho đầu này; mũ bảo hiểm của bộ dựng cũ (cỡ cho đầu rộng hơn) thu vào đầu này, tấm che + quai dựng lại; kính vẽ riêng.
# Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
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
## [y, nửa bề ngang, sâu phía trước, sâu phía sau] từ cằm (y 0) lên đỉnh đầu. Gò má ở y 0.110 (rộng nhất), gờ mày ở y 0.140
## (nhô 4 mm), vòng chân tóc ở y 0.183 (tóc bắt đầu từ vòng này), hàm / cằm ở ba vòng thấp nhất.
const RINGS: Array = [
	[0.000, 0.028, 0.058, 0.004],
	[0.022, 0.050, 0.080, 0.032],
	[0.050, 0.063, 0.094, 0.064],
	[0.080, 0.073, 0.100, 0.088],
	[0.110, 0.079, 0.100, 0.100],
	[0.140, 0.078, 0.104, 0.106],
	[0.160, 0.077, 0.097, 0.105],
	[0.183, 0.074, 0.089, 0.101],
	[0.205, 0.062, 0.073, 0.087],
	[0.222, 0.042, 0.048, 0.058],
	[0.235, 0.000, 0.000, 0.000],
]
## Vòng gốc của gai tóc kiểu "spiky" (y 0.205).
const SPIKE_RING: int = 8
## Nhóm làm mượt pháp tuyến (SurfaceTool.set_smooth_group): sọ + mặt = 0; hai dải thấp nhất + đáy cằm = 1 (nếp hàm tại y 0.05);
## mũi = -1 (phẳng, sống mũi sắc); tai hai mặt: bản sao ngoài = 3, bản sao trong = 4 (để không hàn / triệt tiêu pháp tuyến nhau).
const SMOOTH_SKULL: int = 0
const SMOOTH_JAW: int = 1
const SMOOTH_FLAT: int = -1
const SMOOTH_EAR_OUT: int = 3
const SMOOTH_EAR_IN: int = 4
## Toạ độ vòng làm tròn 1e-6 để đỉnh ở hai đầu đường kinh tuyến trùng nhau bit-chính-xác (pháp tuyến mịn qua đường nối).
const WELD: float = 0.000001
## Bước lượng tử hoá w / jaw / nose trong build(): nhân vật gần giống nhau dùng chung một lưới (cache có giới hạn ~200 lưới đầu).
const K_STEP: float = 0.04
## Nút "HatFit" chứa mũ. Mũ bảo hiểm: mũ của bộ dựng cũ (cỡ cho đầu tròn bán kính 0.105 m) thu vào đầu PS2: vòm cách sọ ~1.4 cm
## hai bên (đỉnh vòm y 0.258, đỉnh đầu 0.235), vành y 0.154..0.173 nằm trên mắt (mắt y 0.116..0.134) và trên lông mày thường; nâng
## 0.08 để vành tựa lên trên chân tóc. Sâu 1.0 để phần tóc trong mũ (vỏ phồng như tóc ngắn, xem COVER_Y) lọt hẳn trong vành + vòm
## (probe: giá trị ellipsoid tệ nhất 0.925 < 1; với sâu 0.9 là 1.057 nên tóc đâm xuyên mũ). Tấm che phía trước và quai được dựng lại
## trong hệ đầu (_build_helmet_visor, _build_helmet_straps): tấm che cũ là tấm phẳng 8 cm, quai cũ không thể chạm tới cằm.
const HELMET_FIT_SCALE: Vector3 = Vector3(0.74, 0.64, 1.0)
const HELMET_LIFT: float = 0.08
## Mũ lưỡi trai (bảo vệ / công an) và mũ đầu bếp dựng thẳng cho đầu PS2 (HatFit không co giãn): vành là trụ elip tâm (0, HAT_Z)
## từ HAT_BOTTOM (ngay trên gờ mày 0.140) lên, ôm phần tóc trong mũ (vỏ phồng như tóc ngắn: ngang 0.083, sâu 0.112 ở vòng 0.160;
## sọ là siêu elip n 2.6 nên bốn góc chéo của vỏ nhô ra ngoài elip cùng bán trục: vành rộng hơn ~7 % và lùi tâm 4 mm về sau vì
## sọ sâu phía sau hơn; đo: đỉnh tóc xa nhất ở góc thái dương / chéo sau đạt 0.97 bán kính vành). Bán trục ngang nhân bề ngang đầu w
## như vỏ tóc. Tóc lộ ra hai bên tai và sau gáy dưới vành. [bán trục ngang, chiều cao, bán trục sâu] của vành; chóp mũ lưỡi trai là
## nửa elip cao CAP_CROWN_H (đỉnh y 0.257, trên đỉnh vỏ tóc 0.246); mũ đầu bếp: miệng vành loe CHEF_FLARE lần đáy, trên là bánh
## phồng (bán trục CHEF_PUFF) rộng hơn miệng vành. Bản cũ đặt ống mũ đầu bếp từ y 0.23 (ngồi trên đỉnh đầu 0.235, như bay lơ lửng).
const HAT_BOTTOM: float = 0.150
const HAT_Z: float = 0.004
const CAP_BAND: Vector3 = Vector3(0.094, 0.035, 0.125)
const CAP_CROWN_H: float = 0.072
const CHEF_BAND: Vector3 = Vector3(0.094, 0.125, 0.125)
const CHEF_FLARE: float = 1.08
const CHEF_PUFF: Vector3 = Vector3(0.112, 0.048, 0.138)
## Tóc dưới mũ / mũ bảo hiểm: vòng từ COVER_Y trở lên phồng như tóc ngắn (nằm gọn trong mũ), vòng thấp hơn giữ độ phồng của kiểu
## tóc (bob / dài lộ ra dưới vành, che tai).
const COVER_Y: float = 0.16
## Rèm tóc dài: buông từ vòng CURTAIN_RING (y 0.050, mép dưới vỏ tóc hai bên, ngang hàm) ở hai bên + sau gáy (|θ| >= 70°), loe ra
## CURTAIN_FLARE ở mép dưới; mép dưới y 0.0 ở hai bên (cằm, trên đỉnh vai), -0.08 sau gáy (ngang vai, còn cách lưng trên ~1.5 cm
## ở tư thế nghỉ). Thay hai tấm phẳng cũ (tấm sau gáy dài tới -0.20, nhìn từ sau / bên như tấm ván).
const CURTAIN_RING: int = 2
const CURTAIN_FLARE: float = 1.12
const HAIR_STYLES: Array[String] = ["short", "side_part", "spiky", "undercut", "bob", "ponytail", "long", "bun"]
const HAIR_PUFF: float = 1.07
## Bob / tóc dài phồng thêm 10 % so với các kiểu khác: đủ để tai (nhô ra tới x 0.087) nằm lọt dưới vỏ tóc thay vì đâm xuyên.
const LONG_HAIR_VOLUME: float = 1.10
## Mép dưới của tóc (y, m) theo dải góc: [trước |θ| < 50°, hai bên < 110°, sau gáy]; dải thái dương 50..70° lấy trung bình của
## mép trước và hai bên (xem _hairline). Một dải của vỏ tóc chỉ được vẽ khi vòng DƯỚI của dải đó cao hơn hoặc bằng giá trị này
## (xem hair_mesh), nên mép thực tế bị làm tròn LÊN tới vòng kế tiếp trong RINGS (vd. trước 0.180 -> vòng 0.183, hai bên 0.125 ->
## vòng 0.140, thái dương 0.1525 -> vòng 0.160): muốn mép tóc ở một vòng thì đặt giá trị trong khoảng (vòng liền dưới, vòng đó].
## Undercut: mép như tóc ngắn, phần đỉnh phồng hơn (_ring_puff); bản cũ [0.176, 0.172, 0.150] để hai bên + sau đầu trọc.
const HAIRLINES: Dictionary = {
	"short": [0.180, 0.125, 0.040], "side_part": [0.172, 0.125, 0.040], "spiky": [0.182, 0.130, 0.045],
	"undercut": [0.176, 0.125, 0.040], "bob": [0.158, 0.030, 0.020], "ponytail": [0.176, 0.120, 0.060],
	"long": [0.158, 0.030, 0.010], "bun": [0.178, 0.122, 0.070],
}
## Phần rẽ ngôi của "side_part": nửa trái hạ mép trước 2 cm (0.172 -> 0.152 rơi vào vòng 0.160 thay vì 0.183).
const SIDE_PART_DROP: float = 0.02

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
		"w": snappedf(width * (0.95 if female else 1.0), K_STEP),
		"jaw": snappedf((0.9 if female else 1.0) * rng.randf_range(0.94, 1.06), K_STEP),
		"nose": snappedf((0.85 if female else 1.0) * rng.randf_range(0.88, 1.12), K_STEP),
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
	var chef: bool = bool(outfit.get("chef_hat", false))
	var cap: bool = bool(outfit.get("cap", false))
	var helmet: bool = bool(outfit.get("helmet", false))
	var covered: bool = chef or cap or helmet
	# tóc luôn là vỏ PS2; dưới mũ / mũ bảo hiểm: phần trong mũ ép như tóc ngắn, tóc dài / bob / đuôi ngựa lộ ra dưới vành (xem
	# covered_style, hair_mesh); gai / búi / undercut thành tóc ngắn
	var style: String = String(opts.get("hair_style", "short"))
	var hm := MeshInstance3D.new()
	hm.name = "Hair"
	hm.mesh = hair_mesh(covered_style(style) if covered else style, k, true, covered)
	hm.material_override = hair_material(hair_idx)
	head.add_child(hm)
	if bool(outfit.get("glasses", false)):
		_build_glasses(head, k)
	if covered:
		var fit := Node3D.new()
		fit.name = "HatFit"
		head.add_child(fit)
		if helmet:
			# mũ bảo hiểm của bộ dựng cũ (cỡ cho đầu tròn rộng hơn) thu vào đầu PS2 và nâng để vành ở trên mắt
			fit.scale = HELMET_FIT_SCALE
			fit.position = Vector3(0.0, HELMET_LIFT, 0.0)
			var hc: Color = outfit.get("helmet_color", Color("#F1C40F"))
			CharacterBuilder._build_helmet(fit, hc, width)
			_build_helmet_visor(fit, hc, width)
			_build_helmet_straps(head, fit, k)
		elif cap:
			_build_cap(fit, outfit.get("cap_color", Color("#1C2A4A")), float(k["w"]))
		else:
			_build_chef_hat(fit, float(k["w"]))
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
		# nếp hàm: hai dải thấp nhất (dưới hàm, cằm) làm mượt riêng nhóm 1, phần sọ + mặt phía trên nhóm 0 -> pháp tuyến gập tại y 0.05
		st.set_smooth_group(SMOOTH_JAW if i < 2 else SMOOTH_SKULL)
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
	# đáy cằm: quạt về tâm (cùng nhóm làm mượt với hai dải thấp nhất)
	st.set_smooth_group(SMOOTH_JAW)
	var under := Vector3(0.0, 0.004, -0.02)
	for j: int in range(SEGMENTS):
		var th1: float = -PI + float(j) * step
		var th2: float = th1 + step
		var side: float = signf(th1 + step * 0.5)
		var a: Vector3 = _ring_point(RINGS[0], th1, k)
		var b: Vector3 = _ring_point(RINGS[0], th2, k)
		_tri(st, a, b, under, _uv(a, th1, side), _uv(b, th2, side), _uv(under, 0.0, 0.0), Vector3(0.0, -1.0, -0.2))
	# mũi: tô phẳng từng mặt (sống mũi sắc)
	st.set_smooth_group(SMOOTH_FLAT)
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
	# tai: tấm phẳng hai mặt. Bản sao NGOÀI (quay ra +-x) và bản sao TRONG (đảo chiều quấn, quay về phía đầu) nằm ở hai nhóm làm
	# mượt khác nhau nên index() không hàn chúng và pháp tuyến không triệt tiêu nhau. Mũi tai nhô 6 mm (ek) để lọt dưới vỏ tóc bob / dài;
	# toàn bộ tai (chân 0.081, mũi +0.006) co giãn theo w như vỏ tóc, nên đầu hẹp không mất khe hở giữa tai và vỏ tóc.
	var w: float = float(k.get("w", 1.0))
	for sx: float in [-1.0, 1.0]:
		var xe: float = sx * 0.081 * w
		var et := Vector3(xe, 0.150, 0.010)
		var ef := Vector3(xe, 0.124, -0.004)
		var eb := Vector3(xe, 0.100, 0.008)
		var ek := Vector3(xe + sx * 0.006 * w, 0.127, 0.026)
		var th: float = sx * PI * 0.5
		var ut: Vector2 = _uv(et, th, sx)
		var uf: Vector2 = _uv(ef, th, sx)
		var ub: Vector2 = _uv(eb, th, sx)
		var uk: Vector2 = _uv(ek, th, sx)
		var away := Vector3(sx, 0.0, 0.0)
		st.set_smooth_group(SMOOTH_EAR_OUT)
		_tri(st, et, ef, ek, ut, uf, uk, away)
		_tri(st, ef, eb, ek, uf, ub, uk, away)
		st.set_smooth_group(SMOOTH_EAR_IN)
		_tri(st, et, ek, ef, ut, uk, uf, -away)
		_tri(st, ef, ek, eb, uf, uk, ub, -away)
	st.index()
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


# ===========================================================================
# TÓC
# ===========================================================================
## with_extras = false chỉ trả VỎ tóc (và rèm tóc dài), bỏ gai / búi / đuôi ngựa (các phần đó cố ý cắm vào đầu); test dùng để
## kiểm tra vỏ không chìm vào hoặc đâm xuyên da đầu. covered = dưới mũ / mũ bảo hiểm (độ phồng theo vòng, xem _ring_puff; đuôi ngựa
## mọc thấp hơn, dưới vành). Khoá cache có with_extras và covered.
static func hair_mesh(style: String, k: Dictionary, with_extras: bool = true, covered: bool = false) -> ArrayMesh:
	var key: String = "hair_%s_%.2f_%.2f_%d%d" % [style, float(k.get("w", 1.0)), float(k.get("jaw", 1.0)), 1 if with_extras else 0, 1 if covered else 0]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var lines: Array = HAIRLINES.get(style, HAIRLINES["short"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = TAU / float(SEGMENTS)
	for i: int in range(RINGS.size() - 1):
		var y0: float = float(RINGS[i][0])
		var p0: Vector2 = _ring_puff(style, y0, covered)
		var p1: Vector2 = _ring_puff(style, float(RINGS[i + 1][0]), covered)
		for j: int in range(SEGMENTS):
			var th1: float = -PI + float(j) * step
			var th2: float = th1 + step
			if y0 < _hairline(style, lines, th1 + step * 0.5):
				continue
			var a: Vector3 = _puffed(_ring_point(RINGS[i], th1, k), p0.x, p0.y)
			var b: Vector3 = _puffed(_ring_point(RINGS[i], th2, k), p0.x, p0.y)
			var c: Vector3 = _puffed(_ring_point(RINGS[i + 1], th1, k), p1.x, p1.y)
			var d: Vector3 = _puffed(_ring_point(RINGS[i + 1], th2, k), p1.x, p1.y)
			_quad(st, a, b, c, d, _huv(th1, a.y), _huv(th2, b.y), _huv(th1, c.y), _huv(th2, d.y), _outward((a + b + c + d) * 0.25))
	match style:
		"spiky":
			var ps: Vector2 = _ring_puff(style, float(RINGS[SPIKE_RING][0]), covered)
			for s: int in range(7 if with_extras else 0):
				var th: float = -0.9 + float(s) * 0.3
				var base: Vector3 = _puffed(_ring_point(RINGS[SPIKE_RING], th, k), ps.x, ps.y)
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
			if with_extras:
				_add_blob(st, Vector3(0.0, 0.205, 0.085), 0.042)
		"ponytail":
			if with_extras:
				# dưới mũ: đuôi mọc từ sau gáy ngay dưới vành (vòng đầu ống thấp hơn đáy vành 0.154)
				_add_tube(st, Vector3(0.0, 0.12 if covered else 0.15, 0.112), Vector3(0.0, -0.07, 0.17), 0.03, 0.016, 6)
		"long":
			# rèm tóc thay hai tấm phẳng cũ (nhìn từ sau / bên là tấm ván); thuộc hình dáng kiểu tóc nên giữ cả khi with_extras = false
			_add_curtain(st, k, _ring_puff(style, float(RINGS[CURTAIN_RING][0]), covered))
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## Kiểu tóc khi đội mũ / mũ bảo hiểm: bob, dài, đuôi ngựa giữ (lộ ra dưới vành); gai, búi, undercut và các kiểu ngắn thành "short"
## (gai / búi / phần đỉnh phồng sẽ đâm xuyên mũ).
static func covered_style(style: String) -> String:
	return style if style in ["bob", "long", "ponytail"] else "short"


## Độ phồng (x) và độ nâng (y) của vòng tóc ở độ cao y: bob / dài phồng thêm LONG_HAIR_VOLUME (tai lọt dưới vỏ), trừ phần trong mũ
## (covered, y >= COVER_Y) phồng như tóc ngắn để nằm gọn trong mũ; undercut nâng phần đỉnh (y >= 0.18) thêm 1.2 cm, hai bên / gáy
## sát như tóc ngắn (cũ: hai bên / gáy trọc).
static func _ring_puff(style: String, y: float, covered: bool) -> Vector2:
	var vol: bool = style in ["bob", "long"] and not (covered and y >= COVER_Y)
	return Vector2(HAIR_PUFF * (LONG_HAIR_VOLUME if vol else 1.0), 0.006 + (0.012 if style == "undercut" and y >= 0.18 else 0.0))


## Rèm tóc dài (xem CURTAIN_RING): mỗi ô của vòng y 0.050 ở hai bên + sau gáy buông thẳng xuống, loe CURTAIN_FLARE ở mép dưới;
## mép trên trùng mép dưới vỏ tóc hai bên (vỏ sau gáy thấp hơn nằm lọt bên trong rèm). Hai mặt (vật liệu tóc không cull).
static func _add_curtain(st: SurfaceTool, k: Dictionary, pl: Vector2) -> void:
	var step: float = TAU / float(SEGMENTS)
	var ring: Array = RINGS[CURTAIN_RING]
	for j: int in range(SEGMENTS):
		var th1: float = -PI + float(j) * step
		var th2: float = th1 + step
		if absf(rad_to_deg(th1 + step * 0.5)) < 70.0:
			continue
		var a: Vector3 = _puffed(_ring_point(ring, th1, k), pl.x, pl.y)
		var b: Vector3 = _puffed(_ring_point(ring, th2, k), pl.x, pl.y)
		var a2 := Vector3(a.x * CURTAIN_FLARE, _curtain_bottom(th1), a.z * CURTAIN_FLARE)
		var b2 := Vector3(b.x * CURTAIN_FLARE, _curtain_bottom(th2), b.z * CURTAIN_FLARE)
		_quad(st, a2, b2, a, b, _huv(th1, a2.y), _huv(th2, b2.y), _huv(th1, a.y), _huv(th2, b.y), Vector3(a.x + b.x, 0.0, a.z + b.z))


## Mép dưới rèm tóc dài ở góc th: 0.0 ở hai bên (ngang cằm), xuống -0.08 sau gáy.
static func _curtain_bottom(th: float) -> float:
	return lerpf(0.0, -0.08, smoothstep(80.0, 150.0, absf(rad_to_deg(th))))


## Mép tóc (y) của dải ở góc giữa th: trước (|θ| < 50°), thái dương (50..70°: nửa đường giữa mép trước và mép hai bên, để mép
## tóc đi xuống từng bậc ~2 cm thay vì một bậc 4 cm thẳng đứng ở 45°), hai bên (< 110°), sau gáy. "side_part": nửa trái của phần
## trước thấp hơn SIDE_PART_DROP (đủ để rơi vào vòng thấp hơn, thấy được đường rẽ).
static func _hairline(style: String, lines: Array, th: float) -> float:
	var deg: float = absf(rad_to_deg(th))
	if deg < 50.0:
		if style == "side_part" and rad_to_deg(th) < -10.0:
			return float(lines[0]) - SIDE_PART_DROP
		return float(lines[0])
	if deg < 70.0:
		return (float(lines[0]) + float(lines[1])) * 0.5
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
	var z: float = _front_z(y) - 0.004   # khung cách mặt 4 mm, tựa vào sống mũi
	for sx: float in [-1.0, 1.0]:
		var cx: float = sx * 0.032 * w
		CharacterBuilder._box(head, Vector3(cx, y + 0.009, z), Vector3(0.03, 0.004, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx, y - 0.009, z), Vector3(0.03, 0.003, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx + sx * 0.016, y, z), Vector3(0.003, 0.021, 0.004), gm)
		CharacterBuilder._box(head, Vector3(cx - sx * 0.016, y, z), Vector3(0.003, 0.021, 0.004), gm)
		# gọng: bắt đầu ở mép ngoài khung, vòng ra ngoài gò má (ngay ngoài chân tai, x = xe + 2.5 mm) rồi chạy thẳng ra tai
		var ya: float = y + 0.004
		var hinge := Vector3(sx * (0.081 * w + 0.0025), ya, -0.045)
		_bar(head, Vector3(cx + sx * 0.016, ya, z), hinge, gm)
		_bar(head, hinge, Vector3(hinge.x, ya, 0.014), gm)
	CharacterBuilder._box(head, Vector3(0.0, y + 0.006, z), Vector3(0.008, 0.003, 0.004), gm)


## Thanh hộp nối p0 -> p1 theo hướng bất kỳ, chiều dài theo trục Z cục bộ: gọng kính (vuông, cạnh thick); quai mũ bảo hiểm dẹt
## (width > 0: bản rộng width, dày thick, mặt rộng quay về phía out).
static func _bar(parent: Node3D, p0: Vector3, p1: Vector3, mat: Material, thick: float = 0.003, width: float = 0.0, out: Vector3 = Vector3.ZERO) -> void:
	var d: Vector3 = p1 - p0
	var dir: Vector3 = d.normalized()
	var up: Vector3 = out if out != Vector3.ZERO else (Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	CharacterBuilder._box(parent, (p0 + p1) * 0.5, Vector3(width if width > 0.0 else thick, thick, d.length()), mat, Basis.looking_at(dir, up).get_euler())


# ===========================================================================
# MŨ BẢO HIỂM: QUAI + TẤM CHE
# ===========================================================================
## Bỏ quai của bộ dựng cũ (hộp cao 0.12 nghiêng ra ngoài, treo lơ lửng cạnh má, không bao giờ chạm cằm) và dựng quai mới trong hệ
## đầu: từ vành xuống má (ngoài gò má 3..6 mm), vòng góc hàm, xuống cằm; một dây luồn dưới cằm nối hai bên. Quai dẹt 12 x 3 mm như
## dây vải (bản cũ thanh vuông 6 mm trông như dây thép), mặt rộng áp theo má / hàm.
static func _build_helmet_straps(head: Node3D, fit: Node3D, k: Dictionary) -> void:
	for ch: Node in fit.get_children():
		var mi := ch as MeshInstance3D
		if mi != null and mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.y >= 0.1:
			fit.remove_child(mi)
			mi.free()
	var sm: StandardMaterial3D = CharacterBuilder._mat("helmet_strap", Color("#222222"), 0.8)
	var w: float = float(k.get("w", 1.0))
	for sx: float in [-1.0, 1.0]:
		var rim := Vector3(sx * 0.090 * w, 0.152, -0.012)
		var jaw := Vector3(sx * 0.077 * w, 0.050, -0.022)
		var chin := Vector3(sx * 0.030 * w, -0.008, -0.032)
		_bar(head, rim, jaw, sm, 0.003, 0.012, Vector3(sx, 0.0, -0.15))
		_bar(head, jaw, chin, sm, 0.003, 0.012, Vector3(sx * 0.6, -0.8, -0.2))
	_bar(head, Vector3(-0.030 * w, -0.008, -0.032), Vector3(0.030 * w, -0.008, -0.032), sm, 0.003, 0.012, Vector3(0.0, -1.0, -0.3))


## Tấm che trước mũ bảo hiểm: lưỡi liềm cùng màu mũ ôm cung trước của vành (hệ đầu: ngang 0.126 * 0.98 * width * 0.74, sâu
## 0.126 * 1.02; xem HELMET_FIT_SCALE), gắn ở nửa trên vành (y 0.166), nhô 4.5 cm, chúi 0.8 cm: mép thấp nhất 0.155 vẫn trên đáy
## vành 0.154 (phần tóc lộ dưới vành không bị tính là xuyên mũ) và trên mắt. Thay tấm phẳng 8 cm của bộ dựng cũ (nhận ra bằng vật
## liệu "helmet_visor"). Nằm trong HatFit với co giãn bù lại (kiểm tra "trên mắt" đo mọi phần trong HatFit).
static func _build_helmet_visor(fit: Node3D, color: Color, width: float) -> void:
	var old_mat: Material = CharacterBuilder._mat("helmet_visor", Color("#111318"), 0.2, 0.3)
	for ch: Node in fit.get_children():
		var mi := ch as MeshInstance3D
		if mi != null and mi.material_override == old_mat:
			fit.remove_child(mi)
			mi.free()
	var v := MeshInstance3D.new()
	v.name = "Visor"
	v.mesh = _visor_mesh(0.126 * 0.98 * width * HELMET_FIT_SCALE.x, 0.126 * 1.02 * HELMET_FIT_SCALE.z, 0.045, 0.008, 0.006)
	v.material_override = CharacterBuilder._mat("helmet_" + color.to_html(false), color, 0.25, 0.1)
	v.scale = Vector3.ONE / HELMET_FIT_SCALE
	v.position = Vector3(0.0, 0.166 - HELMET_LIFT, 0.0) / HELMET_FIT_SCALE
	fit.add_child(v)


# ===========================================================================
# MŨ LƯỠI TRAI / MŨ ĐẦU BẾP (dựng cho đầu PS2, xem HAT_BOTTOM)
# ===========================================================================
## Mũ lưỡi trai đồng phục: vành trụ elip (CAP_BAND, ngang nhân w), chóp nửa elip cao CAP_CROWN_H, lưỡi trai lưỡi liềm ôm mép trước
## vành (nhô 6.5 cm, chúi 1.4 cm; bản cũ là tấm phẳng 10 cm), phù hiệu vàng trước chóp nghiêng theo mặt chóp. Bốn phần, hệ đầu.
static func _build_cap(fit: Node3D, color: Color, w: float) -> void:
	var cm: StandardMaterial3D = CharacterBuilder._cloth_mat("cap_" + color.to_html(false), color)
	var a: float = CAP_BAND.x * w
	var b: float = CAP_BAND.z
	var top: float = HAT_BOTTOM + CAP_BAND.y
	CharacterBuilder._cyl(fit, Vector3(0.0, HAT_BOTTOM + CAP_BAND.y * 0.5, HAT_Z), 0.1, 0.1, CAP_BAND.y, cm, Vector3.ZERO, Vector3(a / 0.1, 1.0, b / 0.1))
	CharacterBuilder._hemisphere(fit, Vector3(0.0, top, HAT_Z), 0.1, cm, Vector3.ZERO, Vector3(a / 0.1, CAP_CROWN_H / 0.1, b / 0.1))
	var visor := MeshInstance3D.new()
	visor.name = "Visor"
	visor.mesh = _visor_mesh(a, b, 0.065, 0.014, 0.006)
	visor.material_override = CharacterBuilder._mat("cap_brim", Color("#101418"), 0.5)
	visor.position = Vector3(0.0, HAT_BOTTOM + 0.004, HAT_Z)
	fit.add_child(visor)
	var h: float = 0.018   # phù hiệu: 1.8 cm trên đáy chóp, mặt chóp ở đó nghiêng ra sau ~23°
	# kim loại 0.3: metal 0.9 phản chiếu bầu trời nên phù hiệu ngả xanh. Khoá riêng: _mat đệm theo khoá, "cap_badge" là của
	# mũ cổ điển (metal 0.9), dùng chung thì kết quả phụ thuộc thứ tự dựng
	CharacterBuilder._box(fit, Vector3(0.0, top + h, HAT_Z - b * sqrt(1.0 - pow(h / CAP_CROWN_H, 2.0)) - 0.002), Vector3(0.026, 0.022, 0.006), CharacterBuilder._mat("cap_badge_ps2", Color("#D4AF37"), 0.3, 0.3), Vector3(0.4, 0.0, 0.0))


## Mũ đầu bếp: vành trụ elip (ngang nhân w) từ HAT_BOTTOM cao CHEF_BAND.y, miệng loe CHEF_FLARE, trên là bánh phồng dẹt rộng hơn
## miệng vành.
static func _build_chef_hat(fit: Node3D, w: float) -> void:
	var wm: StandardMaterial3D = CharacterBuilder._mat("chef_hat", Color("#FAFAFA"), 0.8)
	var a: float = CHEF_BAND.x * w
	var b: float = CHEF_BAND.z
	CharacterBuilder._cyl(fit, Vector3(0.0, HAT_BOTTOM + CHEF_BAND.y * 0.5, HAT_Z), 0.1 * CHEF_FLARE, 0.1, CHEF_BAND.y, wm, Vector3.ZERO, Vector3(a / 0.1, 1.0, b / 0.1))
	CharacterBuilder._sphere(fit, Vector3(0.0, HAT_BOTTOM + CHEF_BAND.y + CHEF_PUFF.y * 0.3, HAT_Z), 0.1, wm, Vector3(CHEF_PUFF.x * w, CHEF_PUFF.y, CHEF_PUFF.z) / 0.1)


## Lưỡi trai hình lưỡi liềm trong mặt XZ (y 0 = mặt giữa, dày thick, mặt trước -Z): mép trong là cung trước của elip (a, b) quanh
## gốc (ôm vành mũ, +-65°), mép ngoài nhô về PHÍA TRƯỚC tối đa `out` ở giữa (loe ngang 25 % theo pháp tuyến), nhỏ dần về 0 ở hai đầu,
## chúi xuống tối đa `droop`: nhìn thẳng chỉ thấy lưỡi trước trán, không thành vành tròn kiểu mũ quả dưa. Cache theo tham số.
static func _visor_mesh(a: float, b: float, out: float, droop: float, thick: float) -> ArrayMesh:
	var key: String = "visor_%.4f_%.4f_%.3f_%.3f_%.3f" % [a, b, out, droop, thick]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 10
	var span: float = deg_to_rad(65.0)
	var hh := Vector3(0.0, thick * 0.5, 0.0)
	var uv := Vector2(0.5, 0.5)
	var prev_in := Vector3.ZERO
	var prev_out := Vector3.ZERO
	for s: int in range(n + 1):
		var t: float = -span + 2.0 * span * float(s) / float(n)
		var p_in := Vector3(a * sin(t), 0.0, -b * cos(t))
		var nrm := Vector3(b * sin(t), 0.0, -a * cos(t)).normalized()   # pháp tuyến ngoài của elip tại p_in
		var e: float = out * pow(cos(t / span * PI * 0.5), 0.6)
		var p_out: Vector3 = p_in + Vector3(nrm.x * 0.25, 0.0, -1.0) * e + Vector3(0.0, -droop * e / out, 0.0)
		if s > 0:
			_quad(st, prev_in + hh, p_in + hh, prev_out + hh, p_out + hh, uv, uv, uv, uv, Vector3.UP)
			_quad(st, prev_in - hh, p_in - hh, prev_out - hh, p_out - hh, uv, uv, uv, uv, Vector3.DOWN)
			_quad(st, prev_out - hh, p_out - hh, prev_out + hh, p_out + hh, uv, uv, uv, uv, nrm)
		prev_in = p_in
		prev_out = p_out
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


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
	# làm tròn 1e-6: sin(+-PI) ~ 1e-16 nên hai đầu đường kinh tuyến sau gáy (và cột x = +-w) lệch nhau ~1e-14 nếu không làm tròn
	if c >= 0.0:
		return Vector3(snappedf(w * ps, WELD), y, snappedf(-float(ring[2]) * pc, WELD))
	return Vector3(snappedf(w * ps, WELD), y, snappedf(float(ring[3]) * pc, WELD))


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
