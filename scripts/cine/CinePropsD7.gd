# File: res://scripts/cine/CinePropsD7.gd
# Day 7 props (Phase D, plan 2026-11-01-w4-day7.md), plain meshes and code colours only, built through
# CineFX.build_prop(kind, opts) (CineFX dispatches every kind in KINDS here). Origin on the ground and front toward -Z unless
# said otherwise.
# Wearables of Lùm Văn Lọ (CastD7.gear; origin = the head centre for head gear, the bone for body gear):
#   gold_glasses (gold-rimmed glasses), pink_collar (the pastel-pink shirt collar showing at the neck), gold_chain.
# Hand props: saber (his antique sabre, the grip at the origin, the blade along -Z; opts "broken").
# Sets and big props: vase (an antique vase; opts "seed" picks the shape and the glaze, "h" height, "cracked" 0..1 shows
#   the crack lines), plinth (the gallery pedestal, 1.0 m), speaker (a wall speaker, origin at its back, front -Z; opts
#   "glow" a lit ring), laser_emitter (a wall emitter, front -Z), breaker (a wall breaker box with a lever; opts "on"),
#   exam_server (the exam-system rack with its screen "HỆ THỐNG THI"), helicopter (a code-built helicopter: its "Rotor"
#   child is turned by the owner, its "Searchlight" child marks where the spotlight hangs), academy_sign ("LỌ ACADEMY ·
#   HỌC THẬT, ĐẬU THẬT", a lit sign; opts "width", "text").
class_name CinePropsD7
extends RefCounted

const KINDS: Array[String] = ["gold_glasses", "pink_collar", "gold_chain", "saber", "vase", "plinth", "speaker",
	"laser_emitter", "breaker", "exam_server", "helicopter", "academy_sign"]
const GOLD := Color("#D4AF37")
const PINK := Color("#F6B8CF")
const SABER_LEN: float = 0.86
const PLINTH_H: float = 1.0
const VASE_GLAZES: Array[Color] = [Color("#2B5DAF"), Color("#C9452E"), Color("#2E8A6B"), Color("#E7DCC4"), Color("#B8892E")]
const T_SIGN: String = "LỌ ACADEMY · HỌC THẬT, ĐẬU THẬT"
const T_EXAM: String = "HỆ THỐNG THI"


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String, root: Node3D, opts: Dictionary) -> void:
	match kind:
		"gold_glasses":
			_glasses(root)
		"pink_collar":
			_collar(root)
		"gold_chain":
			_chain(root)
		"saber":
			_saber(root, opts)
		"vase":
			vase(root, opts)
		"plinth":
			_plinth(root)
		"speaker":
			_speaker(root, opts)
		"laser_emitter":
			_emitter(root)
		"breaker":
			_breaker(root, opts)
		"exam_server":
			_exam_server(root)
		"helicopter":
			_helicopter(root)
		"academy_sign":
			_sign(root, opts)


static func _gold() -> StandardMaterial3D:
	var m: StandardMaterial3D = CineFX._mat(GOLD, 0.25)
	m.metallic = 0.85
	return m


# ---------------------------------------------------------------------------
# Wearables
# ---------------------------------------------------------------------------
static func _glasses(root: Node3D) -> void:
	var gold: StandardMaterial3D = _gold()
	var lens: StandardMaterial3D = CineFX._mat(Color(0.75, 0.85, 0.9, 0.35), 0.05)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Lens", Vector3(0.046, 0.03, 0.004), Vector3(sx * 0.034, 0.0, 0.0), lens)
		CineFX._box(root, "RimTop", Vector3(0.05, 0.005, 0.006), Vector3(sx * 0.034, 0.017, 0.0), gold)
		CineFX._box(root, "RimLow", Vector3(0.05, 0.004, 0.006), Vector3(sx * 0.034, -0.016, 0.0), gold)
		CineFX._box(root, "Temple", Vector3(0.004, 0.004, 0.11), Vector3(sx * 0.07, 0.012, 0.055), gold)
	CineFX._box(root, "Bridge", Vector3(0.02, 0.004, 0.006), Vector3(0.0, 0.01, 0.0), gold)


static func _collar(root: Node3D) -> void:
	var pink: StandardMaterial3D = CineFX._mat(PINK, 0.8)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "CollarWing", Vector3(0.06, 0.05, 0.012), Vector3(sx * 0.04, -0.02, -0.07), pink, Vector3(0.3, 0.0, sx * 0.5))
	CineFX._box(root, "ShirtV", Vector3(0.05, 0.1, 0.01), Vector3(0.0, -0.09, -0.085), pink)


static func _chain(root: Node3D) -> void:
	var gold: StandardMaterial3D = _gold()
	var t := MeshInstance3D.new()
	t.name = "Chain"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.085
	tm.outer_radius = 0.097
	tm.rings = 18
	tm.ring_segments = 5
	t.mesh = tm
	t.material_override = gold
	t.rotation = Vector3(PI * 0.42, 0.0, 0.0)
	t.scale = Vector3(1.0, 1.0, 1.25)
	root.add_child(t)
	CineFX._box(root, "Pendant", Vector3(0.035, 0.045, 0.01), Vector3(0.0, -0.105, -0.02), gold)


# ---------------------------------------------------------------------------
# Hand props
# ---------------------------------------------------------------------------
## The antique sabre: a curved blade along -Z from the guard (the grip at the origin, toward +Z).
static func _saber(root: Node3D, opts: Dictionary) -> void:
	var steel: StandardMaterial3D = CineFX._mat(Color("#D9DEE4"), 0.15)
	steel.metallic = 0.9
	var gold: StandardMaterial3D = _gold()
	var grip: MeshInstance3D = CineFX._cyl(root, "Grip", 0.016, 0.016, 0.2, Vector3(0.0, 0.0, 0.08), CineFX._mat(Color("#4A1F14"), 0.6))
	grip.rotation.x = PI * 0.5
	CineFX._box(root, "Guard", Vector3(0.11, 0.02, 0.03), Vector3(0.0, 0.0, -0.02), gold)
	CineFX._sphere(root, "Pommel", 0.022, Vector3(0.0, 0.0, 0.19), gold)
	var n: int = 3 if bool(opts.get("broken", false)) else 6
	var seg: float = SABER_LEN / 6.0
	for i: int in n:
		var z: float = -0.04 - seg * (float(i) + 0.5)
		var curve: float = 0.012 * float(i * i) / 6.0
		CineFX._box(root, "Blade", Vector3(0.006, 0.034 - 0.003 * i, seg + 0.004), Vector3(0.0, curve, z), steel, Vector3(-0.03 * i, 0.0, 0.0))


# ---------------------------------------------------------------------------
# Sets
# ---------------------------------------------------------------------------
## An antique vase on the ground (or a plinth). Public: LairTower builds its gallery vases with it. Returns the body mesh.
static func vase(root: Node3D, opts: Dictionary) -> MeshInstance3D:
	var sd: int = int(opts.get("seed", 0))
	var h: float = float(opts.get("h", 0.62))
	var glaze: StandardMaterial3D = CineFX._mat(VASE_GLAZES[absi(sd) % VASE_GLAZES.size()], 0.18)
	glaze.metallic_specular = 0.8
	var trim: StandardMaterial3D = _gold() if sd % 2 == 0 else CineFX._mat(Color("#F2EEE6"), 0.3)
	var w: float = 0.16 + 0.04 * float(absi(sd) % 3)
	var body: MeshInstance3D = CineFX._sphere(root, "Belly", w, Vector3(0.0, h * 0.42, 0.0), glaze, Vector3(1.0, h * 0.62 / w, 1.0))
	CineFX._cyl(root, "Neck", w * 0.42, w * 0.5, h * 0.3, Vector3(0.0, h * 0.82, 0.0), glaze)
	CineFX._cyl(root, "Lip", w * 0.52, w * 0.44, 0.03, Vector3(0.0, h * 0.98, 0.0), trim)
	CineFX._cyl(root, "Foot", w * 0.5, w * 0.55, 0.05, Vector3(0.0, 0.025, 0.0), trim)
	var crack := StandardMaterial3D.new()
	crack.albedo_color = Color(0.05, 0.03, 0.02)
	crack.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cracks := Node3D.new()
	cracks.name = "Cracks"
	root.add_child(cracks)
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0 + 0.4
		var c: MeshInstance3D = CineFX._box(cracks, "Crack", Vector3(0.006, h * 0.36, 0.004),
			Vector3(sin(a) * (w + 0.003), h * (0.32 + 0.06 * k), cos(a) * (w + 0.003)), crack, Vector3(0.0, a, 0.35 * (1.0 if k % 2 == 0 else -1.0)))
		c.visible = float(opts.get("cracked", 0.0)) > 0.25 * float(k)
	return body


static func _plinth(root: Node3D) -> void:
	var stone: StandardMaterial3D = CineFX._mat(Color("#1B1714"), 0.35)
	var gold: StandardMaterial3D = _gold()
	CineFX._box(root, "Column", Vector3(0.62, PLINTH_H - 0.08, 0.62), Vector3(0.0, (PLINTH_H - 0.08) * 0.5, 0.0), stone)
	CineFX._box(root, "Cap", Vector3(0.74, 0.08, 0.74), Vector3(0.0, PLINTH_H - 0.04, 0.0), gold)
	CineFX._box(root, "Base", Vector3(0.74, 0.06, 0.74), Vector3(0.0, 0.03, 0.0), gold)


static func _speaker(root: Node3D, opts: Dictionary) -> void:
	var black: StandardMaterial3D = CineFX._mat(Color("#121214"), 0.6)
	CineFX._box(root, "Cabinet", Vector3(0.36, 0.5, 0.22), Vector3(0.0, 0.0, -0.11), black)
	var cone: StandardMaterial3D = CineFX._mat(Color("#2A2A30"), 0.8)
	var woofer: MeshInstance3D = CineFX._cyl(root, "Woofer", 0.12, 0.12, 0.02, Vector3(0.0, -0.06, -0.225), cone)
	woofer.rotation.x = PI * 0.5
	var tweeter: MeshInstance3D = CineFX._cyl(root, "Tweeter", 0.04, 0.04, 0.02, Vector3(0.0, 0.15, -0.225), cone)
	tweeter.rotation.x = PI * 0.5
	var ring: MeshInstance3D = CineFX._cyl(root, "Ring", 0.135, 0.135, 0.01, Vector3(0.0, -0.06, -0.222), CineFX._glow_mat(Color("#FF3B5C"), 2.2))
	ring.rotation.x = PI * 0.5
	ring.visible = bool(opts.get("glow", false))


static func _emitter(root: Node3D) -> void:
	CineFX._box(root, "Housing", Vector3(0.14, 0.14, 0.12), Vector3(0.0, 0.0, -0.06), CineFX._mat(Color("#25272C"), 0.4))
	CineFX._sphere(root, "Lens", 0.035, Vector3(0.0, 0.0, -0.125), CineFX._glow_mat(Color("#FF2030"), 3.0))


static func _breaker(root: Node3D, opts: Dictionary) -> void:
	CineFX._box(root, "Box", Vector3(0.5, 0.7, 0.16), Vector3(0.0, 0.0, -0.08), CineFX._mat(Color("#8A8F96"), 0.5))
	CineFX._box(root, "Stripe", Vector3(0.5, 0.06, 0.01), Vector3(0.0, 0.3, -0.165), CineFX._mat(Color("#F1C40F"), 0.6))
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0.0, -0.05, -0.17)
	lever.rotation.x = -0.7 if bool(opts.get("on", false)) else 0.7
	root.add_child(lever)
	CineFX._box(lever, "Arm", Vector3(0.06, 0.24, 0.05), Vector3(0.0, 0.12, 0.0), CineFX._mat(Color("#C0392B"), 0.5))
	CineFX._sphere(root, "Lamp", 0.03, Vector3(0.17, 0.24, -0.17), CineFX._glow_mat(Color("#3BFF7A") if bool(opts.get("on", false)) else Color("#FF3B3B"), 2.5))


static func _exam_server(root: Node3D) -> void:
	var cab: StandardMaterial3D = CineFX._mat(Color("#14161A"), 0.4)
	CineFX._box(root, "Rack", Vector3(1.1, 2.1, 0.8), Vector3(0.0, 1.05, 0.0), cab)
	var scr: MeshInstance3D = CineFX._box(root, "Screen", Vector3(0.9, 0.55, 0.02), Vector3(0.0, 1.45, -0.41), CineFX._glow_mat(Color("#1E6BFF"), 1.6))
	scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := Label3D.new()
	l.name = "Title"
	l.text = T_EXAM
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = Color.WHITE
	l.outline_size = 6
	l.position = Vector3(0.0, 1.5, -0.425)
	l.rotation.y = PI
	root.add_child(l)
	for i: int in 6:
		CineFX._box(root, "Led", Vector3(0.7, 0.025, 0.01), Vector3(0.0, 0.25 + 0.12 * i, -0.41), CineFX._glow_mat(Color("#3BFF7A") if i % 2 == 0 else Color("#FFB23B"), 2.0))


## A code-built helicopter (body toward -Z): origin at the body centre; "Rotor" (spin it about Y), "Tail", "Searchlight".
static func _helicopter(root: Node3D) -> void:
	var paint: StandardMaterial3D = CineFX._mat(Color("#101114"), 0.35)
	paint.metallic = 0.4
	var gold: StandardMaterial3D = _gold()
	var glass: StandardMaterial3D = CineFX._mat(Color(0.1, 0.16, 0.22, 0.7), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CineFX._sphere(root, "Cabin", 1.2, Vector3(0.0, 0.0, -0.4), paint, Vector3(1.0, 0.9, 1.6))
	CineFX._sphere(root, "Canopy", 0.95, Vector3(0.0, 0.15, -1.3), glass, Vector3(1.0, 0.8, 0.9))
	CineFX._box(root, "Stripe", Vector3(2.42, 0.12, 2.4), Vector3(0.0, -0.1, -0.3), gold)
	CineFX._box(root, "Tail", Vector3(0.3, 0.35, 4.6), Vector3(0.0, 0.25, 3.3), paint)
	CineFX._box(root, "Fin", Vector3(0.1, 1.2, 0.6), Vector3(0.0, 0.8, 5.5), paint)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Skid", Vector3(0.1, 0.08, 3.2), Vector3(sx * 0.9, -1.25, -0.3), paint)
		CineFX._box(root, "Strut", Vector3(0.06, 0.5, 0.06), Vector3(sx * 0.85, -1.0, -1.0), paint)
		CineFX._box(root, "Strut", Vector3(0.06, 0.5, 0.06), Vector3(sx * 0.85, -1.0, 0.4), paint)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0.0, 1.3, -0.3)
	root.add_child(rotor)
	CineFX._cyl(rotor, "Mast", 0.08, 0.1, 0.3, Vector3.ZERO, paint)
	for k: int in 2:
		var b: MeshInstance3D = CineFX._box(rotor, "Blade", Vector3(0.22, 0.03, 5.2), Vector3(0.0, 0.12, 0.0), paint)
		b.rotation.y = PI * 0.5 * float(k)
	var sl := Node3D.new()
	sl.name = "Searchlight"
	sl.position = Vector3(0.0, -1.0, -1.6)
	root.add_child(sl)
	CineFX._cyl(sl, "Lamp", 0.16, 0.2, 0.25, Vector3.ZERO, CineFX._glow_mat(Color("#FFF6D8"), 3.5))
	var l := Label3D.new()
	l.name = "Logo"
	l.text = "LỌ"
	l.font_size = 96
	l.pixel_size = 0.006
	l.modulate = GOLD
	l.position = Vector3(1.21, 0.0, -0.3)
	l.rotation.y = PI * 0.5
	root.add_child(l)


static func _sign(root: Node3D, opts: Dictionary) -> void:
	var w: float = float(opts.get("width", 5.0))
	CineFX._box(root, "Board", Vector3(w, 0.9, 0.12), Vector3(0.0, 0.0, 0.0), CineFX._mat(Color("#0D0B09"), 0.5))
	CineFX._box(root, "Frame", Vector3(w + 0.12, 0.06, 0.14), Vector3(0.0, 0.48, 0.0), _gold())
	CineFX._box(root, "Frame", Vector3(w + 0.12, 0.06, 0.14), Vector3(0.0, -0.48, 0.0), _gold())
	var l := Label3D.new()
	l.name = "Text"
	l.text = String(opts.get("text", T_SIGN))
	l.font_size = 64
	l.pixel_size = 0.0075 * w / 5.0
	l.modulate = Color("#FFE7A8")
	l.outline_size = 8
	l.outline_modulate = Color("#6B4A10")
	l.position = Vector3(0.0, 0.0, -0.07)
	l.rotation.y = PI
	root.add_child(l)
