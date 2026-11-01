# File: res://scripts/cine/CinePropsE.gd
# Props of the ending cinematics (plan 2026-11-01-w4-endings.md T1), plain meshes and code colours only, built through
# CineFX.build_prop(kind, opts) (CineFX dispatches every kind in KINDS here). Origin on the ground, front toward -Z unless
# said otherwise. Move them with the prop "path" opts (CinePlayer) where they fly or fall.
#   billboard     the "LỌ ACADEMY – Học thật, đậu thật" billboard on two posts (panel 7 x 3.2 m, face toward -Z) with a
#                 code-drawn face of Lùm Văn Lọ (gold-rimmed glasses, smug smile); its origin is the foot line, so a path
#                 rotating x tips it over backward (+Z) or forward (-Z).
#   helicopter    a small helicopter (body, tail boom, skids, a blurred rotor disc); nose toward -Z, origin at the skids.
#   police_car    a white-and-blue patrol car with a red / blue light bar (glows), rear door open (opts "door": true).
#   box           a cardboard box of belongings (two-handed, origin at its centre), a plant and a mug poking out.
#   belt          "cái nịt": a brown belt hanging from the hand (origin at the buckle).
#   scholarship   a big presentation board "HỌC BỔNG – HỌC THẬT, ĐẬU THẬT" (two-handed, origin at its centre, face -Z).
#   certificate   a framed "GIẤY KHEN" (one-handed, origin at its centre, face -Z; opts "title", "sub").
#   sign          a cloth banner with one line of text (opts "text", "width", "color"; origin at its centre, face -Z).
#   hearing_set   the disciplinary hearing room (set dressing): a long council table with a name sign, a big screen at the
#                 back; opts "title" (the sign text), "screen" (Array of screen lines), "screen_title".
#   canal         a strip of dark canal water (opts "width", "length"), slightly emissive so the night keeps it readable.
class_name CinePropsE
extends RefCounted

const KINDS: Array[String] = ["billboard", "helicopter", "police_car", "box", "belt", "scholarship", "certificate",
	"hearing_set", "canal", "sign"]
const LO_PINK := Color("#FF8FC8")
const GOLD := Color("#E2B23C")


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String, root: Node3D, opts: Dictionary) -> void:
	match kind:
		"billboard":
			_billboard(root, opts)
		"helicopter":
			_helicopter(root)
		"police_car":
			_police_car(root, opts)
		"box":
			_carton(root)
		"belt":
			_belt(root)
		"scholarship":
			_board(root, "HỌC BỔNG", "Học thật, đậu thật", Vector2(0.9, 0.5), Color("#FFF6DA"))
		"certificate":
			_board(root, String(opts.get("title", "GIẤY KHEN")), String(opts.get("sub", "Phòng Khảo thí")), Vector2(0.34, 0.25),
				Color("#FDF3E1"))
		"sign":
			var w2: float = float(opts.get("width", 3.0))
			CineFX._box(root, "Banner", Vector3(w2, 0.46, 0.03), Vector3(0.0, 0.0, 0.0), CineFX._mat(opts.get("color", Color("#2A3A5C")), 0.8))
			_label(root, "Text", String(opts.get("text", "")), 80, Color("#F4F1EA"), Vector3(0.0, 0.0, -0.02), 0.004)
		"hearing_set":
			_hearing(root, opts)
		"canal":
			var w: float = float(opts.get("width", 14.0))
			var l: float = float(opts.get("length", 6.0))
			var m: StandardMaterial3D = CineFX._glow_mat(Color("#123A44"), 0.25)
			m.roughness = 0.12
			m.metallic = 0.3
			CineFX._box(root, "Water", Vector3(w, 0.04, l), Vector3(0.0, -0.05, 0.0), m)


static func _label(root: Node3D, nm: String, text: String, size: int, col: Color, pos: Vector3, px: float = 0.004) -> Label3D:
	var l := Label3D.new()
	l.name = nm
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = col
	l.position = pos
	l.rotation.y = PI   # readable from -Z (the prop's front)
	root.add_child(l)
	return l


static func _billboard(root: Node3D, opts: Dictionary) -> void:
	var steel: StandardMaterial3D = CineFX._mat(Color("#5A5F66"), 0.4)
	for sx: float in [-2.4, 2.4]:
		CineFX._box(root, "Post", Vector3(0.22, 4.2, 0.22), Vector3(sx, 2.1, 0.15), steel)
	var panel := Node3D.new()
	panel.name = "Panel"
	root.add_child(panel)
	CineFX._box(panel, "Board", Vector3(7.0, 3.2, 0.12), Vector3(0.0, 5.6, 0.1), CineFX._glow_mat(Color("#2A1636"), 0.35))
	CineFX._box(panel, "Frame", Vector3(7.2, 0.12, 0.16), Vector3(0.0, 7.22, 0.1), CineFX._glow_mat(LO_PINK, 1.6))
	CineFX._box(panel, "FrameB", Vector3(7.2, 0.12, 0.16), Vector3(0.0, 3.98, 0.1), CineFX._glow_mat(LO_PINK, 1.6))
	_label(panel, "Title", String(opts.get("title", "LỌ ACADEMY")), 200, Color("#FFF1F8"), Vector3(-1.0, 6.3, 0.02))
	_label(panel, "Slogan", String(opts.get("slogan", "Học thật, đậu thật")), 110, LO_PINK, Vector3(-1.0, 5.2, 0.02))
	_label(panel, "Small", "Cam kết đậu 100%. Không đậu học lại... gói VIP.", 46, Color("#C8B6D8"), Vector3(-1.0, 4.45, 0.02))
	# the smug face on the right: a skin disc, white suit collar, gold-rimmed glasses, a wide smile
	var skin: StandardMaterial3D = CineFX._mat(Color("#E7B892"), 0.7)
	CineFX._sphere(panel, "Face", 0.85, Vector3(2.35, 5.75, 0.0), skin, Vector3(1.0, 1.15, 0.12))
	CineFX._sphere(panel, "Hair", 0.88, Vector3(2.35, 6.35, 0.02), CineFX._mat(Color("#141416"), 0.5), Vector3(1.0, 0.45, 0.12))
	CineFX._box(panel, "Collar", Vector3(1.9, 0.5, 0.06), Vector3(2.35, 4.45, -0.02), CineFX._mat(Color("#F4F1EA"), 0.5))
	CineFX._box(panel, "Shirt", Vector3(0.5, 0.42, 0.07), Vector3(2.35, 4.47, -0.03), CineFX._mat(Color("#F7B9D6"), 0.5))
	for gx: float in [-0.3, 0.3]:
		CineFX._sphere(panel, "Lens", 0.2, Vector3(2.35 + gx, 5.95, -0.09), CineFX._glow_mat(GOLD, 1.2), Vector3(1.0, 0.8, 0.15))
		CineFX._sphere(panel, "Eye", 0.07, Vector3(2.35 + gx, 5.95, -0.12), CineFX._mat(Color("#1A1A1A"), 0.4), Vector3(1.0, 1.0, 0.3))
	CineFX._box(panel, "Smile", Vector3(0.7, 0.1, 0.04), Vector3(2.35, 5.35, -0.1), CineFX._mat(Color("#7A1E2E"), 0.6))
	CineFX._box(panel, "Teeth", Vector3(0.55, 0.05, 0.045), Vector3(2.35, 5.37, -0.115), CineFX._mat(Color("#FFFFFF"), 0.4))


static func _helicopter(root: Node3D) -> void:
	var body: StandardMaterial3D = CineFX._mat(Color("#1C1D22"), 0.3)
	var trim: StandardMaterial3D = CineFX._glow_mat(LO_PINK, 1.2)
	CineFX._sphere(root, "Cabin", 1.1, Vector3(0.0, 1.45, -0.2), body, Vector3(1.0, 0.95, 1.5))
	CineFX._sphere(root, "Glass", 0.9, Vector3(0.0, 1.6, -1.1), CineFX._glow_mat(Color("#4FB7E8"), 0.4), Vector3(0.95, 0.75, 0.7))
	var boom: MeshInstance3D = CineFX._cyl(root, "Boom", 0.12, 0.28, 3.6, Vector3(0.0, 1.75, 2.6), body)
	boom.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	CineFX._box(root, "Fin", Vector3(0.08, 1.0, 0.6), Vector3(0.0, 2.2, 4.3), body)
	CineFX._box(root, "Stripe", Vector3(2.25, 0.08, 1.6), Vector3(0.0, 1.2, -0.1), trim)
	for sx: float in [-0.75, 0.75]:
		CineFX._box(root, "Skid", Vector3(0.08, 0.08, 2.6), Vector3(sx, 0.04, -0.1), CineFX._mat(Color("#8C939C"), 0.3))
		for sz: float in [-0.7, 0.6]:
			CineFX._box(root, "Strut", Vector3(0.06, 0.45, 0.06), Vector3(sx, 0.27, sz), CineFX._mat(Color("#8C939C"), 0.3))
	CineFX._cyl(root, "Mast", 0.08, 0.08, 0.5, Vector3(0.0, 2.6, -0.2), body)
	var disc: StandardMaterial3D = CineFX._mat(Color(0.75, 0.78, 0.82, 0.28), 0.5)
	disc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CineFX._cyl(root, "RotorBlur", 4.2, 4.2, 0.02, Vector3(0.0, 2.86, -0.2), disc)
	for a: float in [0.0, PI * 0.5]:
		CineFX._box(root, "Blade", Vector3(8.2, 0.03, 0.18), Vector3(0.0, 2.87, -0.2), body, Vector3(0.0, a + 0.4, 0.0))
	var ol := OmniLight3D.new()
	ol.name = "Beacon"
	ol.light_color = Color("#FF3B3B")
	ol.light_energy = 1.5
	ol.omni_range = 6.0
	ol.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(ol)


static func _police_car(root: Node3D, opts: Dictionary) -> void:
	var white: StandardMaterial3D = CineFX._mat(Color("#F2F4F6"), 0.35)
	var blue: StandardMaterial3D = CineFX._mat(Color("#1F4E9C"), 0.4)
	var dark: StandardMaterial3D = CineFX._mat(Color("#15171B"), 0.6)
	CineFX._box(root, "Body", Vector3(1.8, 0.65, 4.3), Vector3(0.0, 0.62, 0.0), white)
	CineFX._box(root, "Stripe", Vector3(1.82, 0.16, 4.32), Vector3(0.0, 0.7, 0.0), blue)
	CineFX._box(root, "Cabin", Vector3(1.6, 0.55, 2.1), Vector3(0.0, 1.22, 0.25), white)
	CineFX._box(root, "Windows", Vector3(1.62, 0.36, 1.9), Vector3(0.0, 1.27, 0.25), CineFX._mat(Color("#25303A"), 0.15))
	_label(root, "Word", "CẢNH SÁT", 64, Color("#1F4E9C"), Vector3(0.0, 0.72, -2.17), 0.004)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Lamp", Vector3(0.36, 0.12, 0.22), Vector3(sx * 0.22, 1.56, 0.25),
			CineFX._glow_mat(Color("#FF2A2A") if sx < 0.0 else Color("#2A6BFF"), 4.0))
		for wz: float in [-1.35, 1.35]:
			var wh: MeshInstance3D = CineFX._cyl(root, "Wheel", 0.33, 0.33, 0.24, Vector3(sx * 0.86, 0.33, wz), dark)
			wh.rotation = Vector3(0.0, 0.0, PI * 0.5)
	if bool(opts.get("door", false)):
		CineFX._box(root, "Door", Vector3(0.06, 0.9, 1.0), Vector3(1.35, 0.9, 0.9), white, Vector3(0.0, -1.0, 0.0))


static func _carton(root: Node3D) -> void:
	var card: StandardMaterial3D = CineFX._mat(Color("#B58A57"), 0.9)
	CineFX._box(root, "Carton", Vector3(0.5, 0.32, 0.36), Vector3.ZERO, card)
	CineFX._box(root, "Flap", Vector3(0.5, 0.02, 0.16), Vector3(0.0, 0.17, 0.2), card, Vector3(-0.6, 0.0, 0.0))
	CineFX._cyl(root, "Mug", 0.05, 0.05, 0.12, Vector3(-0.14, 0.2, 0.0), CineFX._mat(Color("#F37021"), 0.5))
	CineFX._sphere(root, "Plant", 0.1, Vector3(0.12, 0.25, 0.04), CineFX._mat(Color("#3E9A4A"), 0.8), Vector3(1.0, 1.3, 1.0))


static func _belt(root: Node3D) -> void:
	var leather: StandardMaterial3D = CineFX._mat(Color("#5A3A22"), 0.7)
	CineFX._box(root, "Buckle", Vector3(0.07, 0.06, 0.012), Vector3.ZERO, CineFX._mat(Color("#C9CCD1"), 0.2))
	CineFX._box(root, "Strap", Vector3(0.035, 0.7, 0.008), Vector3(0.0, -0.37, 0.0), leather)
	CineFX._box(root, "Tail", Vector3(0.035, 0.45, 0.008), Vector3(0.05, -0.26, 0.01), leather, Vector3(0.0, 0.0, 0.12))


static func _board(root: Node3D, title: String, sub: String, size: Vector2, col: Color) -> void:
	CineFX._box(root, "Board", Vector3(size.x, size.y, 0.02), Vector3.ZERO, CineFX._mat(col, 0.6))
	CineFX._box(root, "Rim", Vector3(size.x + 0.03, size.y + 0.03, 0.012), Vector3(0.0, 0.0, 0.006), CineFX._mat(GOLD, 0.3))
	var k: float = size.x / 0.9
	_label(root, "Title", title, int(round(120 * k)), Color("#B3261E"), Vector3(0.0, size.y * 0.14, -0.012), 0.0018 * maxf(k, 0.5))
	_label(root, "Sub", sub, int(round(64 * k)), Color("#3A2A1A"), Vector3(0.0, -size.y * 0.22, -0.012), 0.0018 * maxf(k, 0.5))


static func _hearing(root: Node3D, opts: Dictionary) -> void:
	var wood: StandardMaterial3D = CineFX._mat(Color("#5A4030"), 0.6)
	CineFX._box(root, "Table", Vector3(5.0, 0.08, 1.0), Vector3(0.0, 0.76, 0.0), wood)
	CineFX._box(root, "Skirt", Vector3(5.0, 0.7, 0.05), Vector3(0.0, 0.38, -0.48), CineFX._mat(Color("#2A3A5C"), 0.8))
	if String(opts.get("title", "")) != "":
		_label(root, "Sign", String(opts["title"]), 90, Color("#F4F1EA"), Vector3(0.0, 0.45, -0.52), 0.004)
	CineFX._box(root, "Screen", Vector3(4.2, 2.3, 0.08), Vector3(0.0, 2.25, 1.6), CineFX._glow_mat(Color("#0B1220"), 0.5))
	_label(root, "ScreenTitle", String(opts.get("screen_title", "BẰNG CHỨNG")), 70, Color("#3FF2FF"), Vector3(0.0, 3.1, 1.55), 0.004)
	var lines: Array = opts.get("screen", [])
	for i: int in lines.size():
		_label(root, "ScreenLine%d" % i, String(lines[i]), 36, Color("#E8F4FF"), Vector3(0.0, 2.75 - 0.22 * i, 1.55), 0.004)
	for sx: float in [-1.6, 0.0, 1.6]:
		CineFX._box(root, "Chair", Vector3(0.5, 1.0, 0.5), Vector3(sx, 0.5, 0.75), CineFX._mat(Color("#1E2430"), 0.7))
