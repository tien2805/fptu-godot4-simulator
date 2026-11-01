# File: res://scripts/cine/CinePropsD6.gd
# Day 6 "Trà Sữa Lọ" props (plan 2026-11-01-w4-day6.md), plain meshes, code colours and code shaders only, built through
# CineFX.build_prop(kind, opts) (CineFX dispatches every kind in KINDS here) and by the lair LairCanal (the same builders,
# so the cinematics and the level agree). Origin on the ground (boats: on the waterline) and front toward -Z unless said.
#
# Wearables (Thị Lọ; StoryCast.gear("thi_lo")): pink_bob (head gear over the PS2 hair), lo_shades (oversized pink
#   sunglasses), leopard_print (spots on the jacket front, opts "depth").
# Hand props: cash_bag (opts "open"), cash_wad (the tip money in a rubber band; opts "band_only", "no_band"), ledger,
#   milk_tea (opts "tea" Color, "topping" pearl | jelly | pudding | cheese), powder_puff (Thị Lọ's compact), uniform_pack
#   (the folded pink shipper shirt with the pink helmet on top).
# Vehicles: speedboat (opts "color", "trim", "name": the side lettering; meta "seat", "bow"), jet_ski (opts "color";
#   meta "seat").
# Back room (the same layout in the lair and the cinematics: backroom_layout()): backroom (set: walls, floor, ceiling,
#   the two doors), doll_shelf (two rows of sheep dolls; "anim": true + "turn_at", "turn_dur", "look_at" (prop-local
#   Vector3) turns every head; meta "anim_node" with aim_heads() for gameplay), music_box ("anim": "play_at" spins the
#   sheep), sheep_doll, vanity (a mirror with bulbs; meta "glass"), safe ("anim": "open_at" swings the door).
#   bulb (a bare hanging bulb with its light: CineFX.set_lamp / prop opts "dark" / "flicker" work on it; opts "bare": the
#   light only, "color", "energy", "range").
# Shop: tea_shop (set: the front room, the counter with 4 cup spots, the menu board, the pink neon sign; shop_layout()).
# Canal: canal_bank (set: a piece of bank, the water with the code water shader, lanterns), low_bridge (opts "span",
#   "clear"), fish_net (opts "w", "h"; meta "net"), sampan (opts "ramp": a moored sampan tipped into a ramp), pier_wall,
#   house_row (a row of canal houses with lit windows along X, front toward -Z: opts "n", "seed"),
#   billboard ("anim": "on_at" lights the LỌ ACADEMY board and Lùm Văn Lọ's face), fireworks ("anim": "bursts"
#   [[s, Vector3, Color], ...] story-time sky bursts, seekable).
# water_material(): the shared canal water (a small spatial shader: waves in the vertex, a moving normal, fresnel).
class_name CinePropsD6
extends RefCounted

const KINDS: Array[String] = ["pink_bob", "lo_shades", "leopard_print", "cash_bag", "ledger", "milk_tea", "powder_puff",
	"uniform_pack", "speedboat", "jet_ski", "backroom", "doll_shelf", "music_box", "sheep_doll", "vanity", "safe", "tea_shop",
	"canal_bank", "low_bridge", "fish_net", "sampan", "pier_wall", "billboard", "fireworks", "bulb", "house_row", "cash_wad"]
const PINK := Color("#FF4FA3")
const NEON := Color("#FF5FC8")
const WOOL := Color("#F1ECE2")
const FACE := Color("#2B2622")
const BOAT_LEN: float = 5.4
const BOAT_BEAM: float = 2.0
const SKI_LEN: float = 2.8
## Back room frame (room_xf in the lair): 9 x 7 m, 3 m high; the shop door on +Z at x = -3, the pier door on -Z at x = 0.3.
const ROOM_W: float = 9.0
const ROOM_D: float = 7.0
const ROOM_H: float = 3.0
const ROOM_DOOR_X: float = -3.0
const PIER_DOOR_X: float = 0.3
## Shop frame: 10 x 8 m; the counter along X at z = COUNTER_Z (customers on -Z, staff on +Z); the cup spots on its top.
const SHOP_W: float = 10.0
const SHOP_D: float = 8.0
const COUNTER_Z: float = 0.6
const COUNTER_Y: float = 1.0
const CUP_X: Array[float] = [-1.5, -0.5, 0.5, 1.5]
const SHOP_BACK_DOOR_X: float = 3.0
const TEA_COLORS: Dictionary = {"tra": Color("#C8915A"), "matcha": Color("#8DBF5A"), "khoai_mon": Color("#A88BD6"), "dau": Color("#FF8FB0")}
const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep : source_color = vec3(0.015, 0.035, 0.08);
uniform vec3 sky : source_color = vec3(0.16, 0.14, 0.32);
uniform float chop = 1.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += chop * (0.05 * sin(wp.x * 0.7 + TIME * 1.3) + 0.04 * sin(wp.z * 0.9 - TIME * 1.1));
}
void fragment() {
	vec2 p = wp.xz;
	float t = TIME;
	float gx = 0.049 * cos(p.x * 0.7 + t * 1.3) + 0.06 * cos(p.x * 2.3 + p.y * 1.7 + t * 2.0) + 0.04 * cos(p.x * 5.1 - p.y * 4.3 + t * 3.1);
	float gz = 0.036 * cos(p.y * 0.9 - t * 1.1) + 0.05 * cos(p.x * 2.3 + p.y * 1.7 + t * 2.0) - 0.035 * cos(p.x * 5.1 - p.y * 4.3 + t * 3.1);
	vec3 n = normalize(vec3(-gx * chop, 1.0, -gz * chop));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep, sky, fres * 0.8);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	EMISSION = sky * fres * 0.18;
}
"""

static var _water: ShaderMaterial = null


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String, root: Node3D, opts: Dictionary) -> void:
	match kind:
		"pink_bob":
			_pink_bob(root)
		"lo_shades":
			_lo_shades(root)
		"leopard_print":
			_leopard(root, opts)
		"cash_bag":
			_cash_bag(root, opts)
		"ledger":
			_ledger(root)
		"cash_wad":
			_cash_wad(root, opts)
		"milk_tea":
			_milk_tea(root, opts)
		"powder_puff":
			_puff(root)
		"uniform_pack":
			_uniform(root)
		"speedboat":
			_speedboat(root, opts)
		"jet_ski":
			_jet_ski(root, opts)
		"backroom":
			_backroom(root)
		"doll_shelf":
			var dn := CineAnimD6.make("dolls", opts)
			root.add_child(dn)
			root.set_meta("anim_node", dn)
		"music_box":
			var mb := CineAnimD6.make("music_box", opts)
			root.add_child(mb)
			root.set_meta("anim_node", mb)
		"sheep_doll":
			sheep_doll(root, "Doll")
		"bulb":
			_bulb(root, opts)
		"house_row":
			_house_row(root, opts)
		"vanity":
			_vanity(root)
		"safe":
			var sf := CineAnimD6.make("safe", opts)
			root.add_child(sf)
			root.set_meta("anim_node", sf)
		"tea_shop":
			_tea_shop(root)
		"canal_bank":
			_canal_bank(root, opts)
		"low_bridge":
			low_bridge(root, float(opts.get("span", 26.0)), float(opts.get("clear", 2.2)))
		"fish_net":
			var fn := CineAnimD6.make("net", opts)
			root.add_child(fn)
			root.set_meta("anim_node", fn)
			root.set_meta("net", fn)
		"sampan":
			sampan(root, bool(opts.get("ramp", false)))
		"pier_wall":
			pier_wall(root, float(opts.get("w", 14.0)))
		"billboard":
			var bb := CineAnimD6.make("billboard", opts)
			root.add_child(bb)
			root.set_meta("anim_node", bb)
		"fireworks":
			var fw := CineAnimD6.make("fireworks", opts)
			root.add_child(fw)
			root.set_meta("anim_node", fw)


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------
static func water_material() -> ShaderMaterial:
	if _water == null:
		var sh := Shader.new()
		sh.code = WATER_SHADER
		_water = ShaderMaterial.new()
		_water.shader = sh
	return _water


static func text(parent: Node3D, nm: String, t: String, size: int, col: Color, pos: Vector3, glow: bool = false) -> Label3D:
	var l := Label3D.new()
	l.name = nm
	l.text = t
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 8 if glow else 4
	l.outline_modulate = Color(col.r * 0.4, col.g * 0.2, col.b * 0.4, 0.9) if glow else Color(0.05, 0.03, 0.06, 0.9)
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = PI   # Label3D reads toward +Z: turn it to read from -Z (the prop's front)
	parent.add_child(l)
	return l


static func lantern(parent: Node3D, pos: Vector3, col: Color) -> MeshInstance3D:
	var l: MeshInstance3D = CineFX._sphere(parent, "Lantern", 0.16, pos, CineFX._glow_mat(col, 2.6), Vector3(1.0, 1.25, 1.0))
	CineFX._cyl(parent, "Cap", 0.06, 0.1, 0.06, pos + Vector3(0.0, 0.21, 0.0), CineFX._mat(Color("#3A1E12"), 0.7))
	return l


static func _prism(parent: Node3D, nm: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Wearables
# ---------------------------------------------------------------------------
## Neon-pink bob over the PS2 hair (origin = the head centre): a cap a little larger than the head, the fringe, the sides.
static func _pink_bob(root: Node3D) -> void:
	var m: StandardMaterial3D = CineFX._mat(Color("#FF3FA0"), 0.55)
	m.emission_enabled = true
	m.emission = Color("#FF3FA0")
	m.emission_energy_multiplier = 0.35
	m.set_meta("vice_done", true)
	CineFX._sphere(root, "Cap", 0.118, Vector3(0.0, 0.045, 0.012), m, Vector3(1.04, 0.95, 1.08))
	CineFX._box(root, "Fringe", Vector3(0.2, 0.05, 0.05), Vector3(0.0, 0.085, -0.095), m, Vector3(0.2, 0.0, 0.0))
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Side", Vector3(0.05, 0.17, 0.17), Vector3(sx * 0.105, -0.01, 0.01), m)
	CineFX._box(root, "Back", Vector3(0.21, 0.15, 0.05), Vector3(0.0, -0.005, 0.1), m)


## Oversized pink sunglasses (origin at the eye line).
static func _lo_shades(root: Node3D) -> void:
	var rim: StandardMaterial3D = CineFX._mat(PINK, 0.3)
	var lens: StandardMaterial3D = CineFX._mat(Color("#1A0A14"), 0.05)
	lens.metallic = 0.6
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Lens", Vector3(0.068, 0.05, 0.006), Vector3(sx * 0.04, 0.0, 0.0), lens)
		CineFX._box(root, "Rim", Vector3(0.074, 0.008, 0.01), Vector3(sx * 0.04, 0.028, 0.0), rim)
		CineFX._box(root, "Temple", Vector3(0.005, 0.006, 0.11), Vector3(sx * 0.08, 0.018, 0.055), rim)
	CineFX._box(root, "Bridge", Vector3(0.016, 0.006, 0.008), Vector3(0.0, 0.016, 0.0), rim)


## Leopard spots on the jacket front (Chest bone; origin on the chest, spots at "depth").
static func _leopard(root: Node3D, opts: Dictionary) -> void:
	var z: float = float(opts.get("depth", -0.15))
	var ring: StandardMaterial3D = CineFX._mat(Color("#2A1A0E"), 0.9)
	var core: StandardMaterial3D = CineFX._mat(Color("#8A5A22"), 0.9)
	var spots: Array[Vector3] = [Vector3(-0.09, 0.04, z), Vector3(0.06, 0.07, z), Vector3(-0.02, -0.06, z - 0.005),
		Vector3(0.1, -0.08, z + 0.01), Vector3(-0.11, -0.15, z + 0.01), Vector3(0.03, -0.2, z), Vector3(-0.05, -0.27, z + 0.005),
		Vector3(0.12, -0.24, z + 0.015)]
	for i: int in spots.size():
		CineFX._sphere(root, "Spot", 0.02, spots[i], ring, Vector3(1.2, 1.0, 0.3))
		CineFX._sphere(root, "Core", 0.011, spots[i] + Vector3(0.0, 0.0, -0.004), core, Vector3(1.2, 1.0, 0.3))


# ---------------------------------------------------------------------------
# Hand props
# ---------------------------------------------------------------------------
## Briefcase of cash (two-handed, origin at the handle); opts "open": the lid up, the bundles showing.
static func _cash_bag(root: Node3D, opts: Dictionary) -> void:
	var leather: StandardMaterial3D = CineFX._mat(Color("#2A1A12"), 0.5)
	CineFX._box(root, "Case", Vector3(0.48, 0.1, 0.34), Vector3(0.0, -0.22, 0.0), leather, Vector3(PI * 0.5, 0.0, 0.0))
	CineFX._box(root, "Handle", Vector3(0.12, 0.03, 0.02), Vector3(0.0, -0.02, 0.0), CineFX._mat(Color("#C9A227"), 0.3))
	var cash: StandardMaterial3D = CineFX._mat(Color("#5FAF6A"), 0.8)
	var band: StandardMaterial3D = CineFX._mat(Color("#F4F1EA"), 0.8)
	var open: bool = bool(opts.get("open", false))
	for i: int in 6:
		var p := Vector3(-0.15 + 0.15 * float(i % 3), -0.12 - 0.13 * float(i / 3), -0.06 if open else 0.0)
		CineFX._box(root, "Cash", Vector3(0.13, 0.06, 0.05), p, cash)
		CineFX._box(root, "Band", Vector3(0.02, 0.062, 0.052), p, band)
	if open:
		CineFX._box(root, "Lid", Vector3(0.48, 0.34, 0.02), Vector3(0.0, -0.22, 0.12), leather)


## The day's tip money: a wad of notes in a pink rubber band (origin at its centre); opts "band_only": just the band (what
## Thị Lọ hands back: "Còn cái nịt."), "no_band": just the notes.
static func _cash_wad(root: Node3D, opts: Dictionary) -> void:
	if not bool(opts.get("band_only", false)):
		for i: int in 4:
			CineFX._box(root, "Note", Vector3(0.14, 0.006, 0.065), Vector3(0.004 * float(i % 2), 0.007 * float(i), 0.003 * float(i)),
				CineFX._mat(Color("#5FAF6A").lightened(0.06 * float(i % 2)), 0.85))
	if not bool(opts.get("no_band", false)):
		var band: MeshInstance3D = CineFX._cyl(root, "Band", 0.036, 0.036, 0.012, Vector3(0.0, 0.012, 0.0), CineFX._glow_mat(PINK, 0.4))
		band.rotation.z = PI * 0.5
		band.scale = Vector3(1.0, 1.0, 0.55)


## The ledger E7: a thick dark-red book with a gold "SỔ CÁI" label and a sheep stamp (origin at its centre).
static func _ledger(root: Node3D) -> void:
	CineFX._box(root, "Cover", Vector3(0.24, 0.06, 0.32), Vector3.ZERO, CineFX._mat(Color("#6E1424"), 0.6))
	CineFX._box(root, "Pages", Vector3(0.225, 0.05, 0.305), Vector3(0.012, 0.0, 0.0), CineFX._mat(Color("#EFE6D2"), 0.9))
	var l := text(root, "Label", "SỔ CÁI", 26, Color("#E8C15A"), Vector3(0.0, 0.032, -0.03))
	l.rotation = Vector3(-PI * 0.5, PI, 0.0)
	CineFX._sphere(root, "Stamp", 0.03, Vector3(0.0, 0.031, 0.07), CineFX._mat(Color("#FF4FA3"), 0.6), Vector3(1.0, 0.15, 1.0))


## A milk tea cup (origin at its bottom): the tea, the dome lid, the fat pink straw, the topping in the bottom.
static func _milk_tea(root: Node3D, opts: Dictionary) -> void:
	var tea: Color = opts.get("tea", TEA_COLORS["tra"])
	var cup: StandardMaterial3D = CineFX._mat(Color(0.95, 0.95, 1.0, 0.35), 0.1)
	cup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CineFX._cyl(root, "Tea", 0.042, 0.035, 0.12, Vector3(0.0, 0.065, 0.0), CineFX._mat(tea, 0.5))
	CineFX._cyl(root, "Cup", 0.046, 0.038, 0.15, Vector3(0.0, 0.075, 0.0), cup)
	CineFX._sphere(root, "Lid", 0.046, Vector3(0.0, 0.15, 0.0), cup, Vector3(1.0, 0.45, 1.0))
	var straw: MeshInstance3D = CineFX._cyl(root, "Straw", 0.008, 0.008, 0.22, Vector3(0.012, 0.18, 0.0), CineFX._glow_mat(PINK, 0.6))
	straw.rotation.z = -0.15
	match String(opts.get("topping", "pearl")):
		"pearl":
			for i: int in 7:
				var a: float = TAU * float(i) / 7.0
				CineFX._sphere(root, "Pearl", 0.009, Vector3(cos(a) * 0.022, 0.016, sin(a) * 0.022), CineFX._mat(Color("#1A120E"), 0.3))
		"jelly":
			for i2: int in 5:
				CineFX._box(root, "Jelly", Vector3(0.014, 0.014, 0.014), Vector3(-0.02 + 0.01 * float(i2), 0.02, 0.006 * float(i2 % 2)), CineFX._mat(Color("#F6F2D8"), 0.2))
		"pudding":
			CineFX._cyl(root, "Pudding", 0.03, 0.032, 0.025, Vector3(0.0, 0.02, 0.0), CineFX._mat(Color("#F2C14E"), 0.4))
		"cheese":
			CineFX._cyl(root, "Cheese", 0.043, 0.043, 0.03, Vector3(0.0, 0.135, 0.0), CineFX._mat(Color("#FFF4D6"), 0.6))


## Thị Lọ's compact with the powder puff (origin at the grip).
static func _puff(root: Node3D) -> void:
	CineFX._cyl(root, "Compact", 0.04, 0.04, 0.015, Vector3(0.0, 0.0, -0.03), CineFX._mat(Color("#FFB3D6"), 0.3))
	var mirror: StandardMaterial3D = CineFX._mat(Color("#DDE6F0"), 0.02)
	mirror.metallic = 1.0
	CineFX._cyl(root, "Mirror", 0.034, 0.034, 0.004, Vector3(0.0, 0.01, -0.03), mirror)
	CineFX._sphere(root, "Puff", 0.035, Vector3(0.05, 0.02, -0.06), CineFX._mat(Color("#FFE3EE"), 1.0), Vector3(1.0, 0.45, 1.0))


## The shipper uniform Phúc hands over: a folded pink shirt with "TRÀ SỮA LỌ" and a pink helmet on top (two-handed).
static func _uniform(root: Node3D) -> void:
	CineFX._box(root, "Shirt", Vector3(0.34, 0.08, 0.26), Vector3(0.0, -0.08, 0.0), CineFX._mat(Color("#FF7AB6"), 0.9))
	var l := text(root, "Logo", "TRÀ SỮA LỌ", 18, Color("#FFFFFF"), Vector3(0.0, -0.035, -0.02))
	l.rotation = Vector3(-PI * 0.5, PI, 0.0)
	CineFX._sphere(root, "Helmet", 0.13, Vector3(0.0, 0.02, 0.02), CineFX._mat(PINK, 0.35), Vector3(1.0, 0.75, 1.15))
	CineFX._sphere(root, "Ear", 0.05, Vector3(-0.1, 0.1, 0.0), CineFX._mat(WOOL, 1.0))
	CineFX._sphere(root, "Ear2", 0.05, Vector3(0.1, 0.1, 0.0), CineFX._mat(WOOL, 1.0))


# ---------------------------------------------------------------------------
# Vehicles
# ---------------------------------------------------------------------------
## Speedboat, 5.4 x 2.0 m, origin on the waterline at the hull centre, bow toward -Z. Meta "seat" (the driver's hips),
## "bow" (Thị Lọ's Titanic spot), "lights" (the two nav lights).
static func _speedboat(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#F4F1EA"))
	var trim: Color = opts.get("trim", Color("#F37021"))
	var hull: StandardMaterial3D = CineFX._mat(col, 0.35)
	var stripe: StandardMaterial3D = CineFX._mat(trim, 0.4)
	CineFX._box(root, "Hull", Vector3(BOAT_BEAM, 0.72, 3.9), Vector3(0.0, 0.14, 0.75), hull)
	_prism(root, "Bow", Vector3(BOAT_BEAM, 1.5, 0.72), Vector3(0.0, 0.14, -1.95), hull, Vector3(-PI * 0.5, 0.0, 0.0))
	CineFX._box(root, "Stripe", Vector3(BOAT_BEAM + 0.02, 0.12, 3.9), Vector3(0.0, 0.3, 0.75), stripe)
	CineFX._box(root, "Deck", Vector3(BOAT_BEAM - 0.24, 0.05, 3.6), Vector3(0.0, 0.47, 0.8), CineFX._mat(Color("#C9A27A"), 0.7))
	var glass: StandardMaterial3D = CineFX._mat(Color(0.6, 0.8, 1.0, 0.35), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CineFX._box(root, "Windscreen", Vector3(1.5, 0.45, 0.04), Vector3(0.0, 0.72, -0.15), glass, Vector3(-0.5, 0.0, 0.0))
	CineFX._box(root, "Console", Vector3(0.6, 0.45, 0.4), Vector3(0.0, 0.7, 0.1), CineFX._mat(Color("#2A2C33"), 0.5))
	CineFX._cyl(root, "Wheel", 0.15, 0.15, 0.03, Vector3(0.0, 0.98, 0.3), CineFX._mat(Color("#151515"), 0.5)).rotation.x = 1.1
	for sx: float in [-0.45, 0.45]:
		CineFX._box(root, "Seat", Vector3(0.6, 0.18, 0.55), Vector3(sx, 0.58, 0.95), CineFX._mat(Color("#E9E2D2"), 0.8))
		CineFX._box(root, "SeatBack", Vector3(0.6, 0.45, 0.12), Vector3(sx, 0.85, 1.22), CineFX._mat(Color("#E9E2D2"), 0.8))
	CineFX._box(root, "Engine", Vector3(0.6, 0.7, 0.5), Vector3(0.0, 0.5, 2.85), CineFX._mat(Color("#1C1D22"), 0.4))
	CineFX._box(root, "EngineCap", Vector3(0.5, 0.12, 0.42), Vector3(0.0, 0.9, 2.85), stripe)
	var lights: Array = []
	lights.append(CineFX._sphere(root, "NavRed", 0.05, Vector3(-0.85, 0.55, -1.6), CineFX._glow_mat(Color("#FF2A2A"), 3.0)))
	lights.append(CineFX._sphere(root, "NavGreen", 0.05, Vector3(0.85, 0.55, -1.6), CineFX._glow_mat(Color("#2AFF6A"), 3.0)))
	var nm: String = String(opts.get("name", ""))
	if nm != "":
		for sx2: float in [-1.0, 1.0]:
			var l := text(root, "Name", nm, 64, trim, Vector3(sx2 * (BOAT_BEAM * 0.5 + 0.012), 0.22, 0.2), true)
			l.rotation.y = -sx2 * PI * 0.5
	root.set_meta("seat", Vector3(-0.45, 0.62, 0.95))
	root.set_meta("bow", Vector3(0.0, 0.62, -1.9))
	root.set_meta("lights", lights)


## Jet ski, 2.8 x 1.1 m, origin on the waterline, bow toward -Z. Meta "seat".
static func _jet_ski(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#25282E"))
	var body: StandardMaterial3D = CineFX._mat(col, 0.35)
	CineFX._box(root, "Hull", Vector3(1.0, 0.5, 1.9), Vector3(0.0, 0.08, 0.35), body)
	_prism(root, "Bow", Vector3(1.0, 0.9, 0.5), Vector3(0.0, 0.08, -1.05), body, Vector3(-PI * 0.5, 0.0, 0.0))
	CineFX._box(root, "Stripe", Vector3(1.02, 0.08, 1.9), Vector3(0.0, 0.22, 0.35), CineFX._mat(Color("#FFB020"), 0.4))
	CineFX._box(root, "Seat", Vector3(0.42, 0.2, 1.0), Vector3(0.0, 0.42, 0.45), CineFX._mat(Color("#121214"), 0.7))
	CineFX._box(root, "Nose", Vector3(0.7, 0.3, 0.5), Vector3(0.0, 0.42, -0.35), body)
	CineFX._box(root, "Bars", Vector3(0.7, 0.04, 0.04), Vector3(0.0, 0.72, -0.25), CineFX._mat(Color("#151515"), 0.5))
	CineFX._sphere(root, "Lamp", 0.05, Vector3(0.0, 0.5, -0.62), CineFX._glow_mat(Color("#FFB020"), 2.5))
	root.set_meta("seat", Vector3(0.0, 0.52, 0.45))


# ---------------------------------------------------------------------------
# Back room
# ---------------------------------------------------------------------------
## [kind, pos, yaw_deg, opts] of the back room's furniture in the room frame (the lair and the cinematics both use it).
static func backroom_layout() -> Array:
	return [["doll_shelf", Vector3(-4.2, 0.0, -1.6), -90.0, {"tint": 0}], ["doll_shelf", Vector3(-4.2, 0.0, 1.0), -90.0, {"tint": 1}],
		["doll_shelf", Vector3(4.2, 0.0, -1.6), 90.0, {"tint": 2}], ["doll_shelf", Vector3(4.2, 0.0, 1.0), 90.0, {"tint": 3}],
		["music_box", Vector3(0.0, 0.0, 0.4), 180.0, {}], ["vanity", Vector3(-2.4, 0.0, -3.05), 180.0, {}],
		["safe", Vector3(2.9, 0.0, -3.0), 180.0, {}], ["bulb", Vector3(0.0, ROOM_H - 0.45, 0.0), 0.0, {}],
		["bulb", Vector3(-2.4, 1.7, -2.3), 0.0, {"bare": true, "color": Color("#FF3060"), "energy": 0.7, "range": 5.0}]]


## Back-room shell (set): floor, walls with the two door gaps, ceiling, a bare bulb and a small table under the music box.
static func _backroom(root: Node3D) -> void:
	var wall: StandardMaterial3D = CineFX._mat(Color("#4A3B44"), 0.95)
	var floor_m: StandardMaterial3D = CineFX._mat(Color("#2B2226"), 0.9)
	var hw: float = ROOM_W * 0.5
	var hd: float = ROOM_D * 0.5
	CineFX._box(root, "Floor", Vector3(ROOM_W, 0.1, ROOM_D), Vector3(0.0, -0.05, 0.0), floor_m)
	CineFX._box(root, "Ceiling", Vector3(ROOM_W, 0.1, ROOM_D), Vector3(0.0, ROOM_H + 0.05, 0.0), wall)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Side", Vector3(0.12, ROOM_H, ROOM_D), Vector3(sx * hw, ROOM_H * 0.5, 0.0), wall)
	_wall_with_door(root, "Front", hd, ROOM_DOOR_X, wall)
	_wall_with_door(root, "Back", -hd, PIER_DOOR_X, wall)
	CineFX._box(root, "Table", Vector3(0.8, 0.75, 0.6), Vector3(0.0, 0.375, 0.4), CineFX._mat(Color("#5A3A28"), 0.7))



static func _wall_with_door(root: Node3D, nm: String, z: float, door_x: float, mat: Material) -> void:
	var hw: float = ROOM_W * 0.5
	var dw: float = 1.2
	var l0: float = door_x - dw * 0.5 + hw
	var l1: float = hw - (door_x + dw * 0.5)
	CineFX._box(root, nm + "L", Vector3(l0, ROOM_H, 0.12), Vector3(-hw + l0 * 0.5, ROOM_H * 0.5, z), mat)
	CineFX._box(root, nm + "R", Vector3(l1, ROOM_H, 0.12), Vector3(hw - l1 * 0.5, ROOM_H * 0.5, z), mat)
	CineFX._box(root, nm + "Top", Vector3(dw, ROOM_H - 2.1, 0.12), Vector3(door_x, 2.1 + (ROOM_H - 2.1) * 0.5, z), mat)


## One plush sheep doll (0.3 m) under `parent`: wool body, the dark face on a "Head" pivot (returned) that turns.
static func sheep_doll(parent: Node3D, nm: String) -> Node3D:
	var d := Node3D.new()
	d.name = nm
	parent.add_child(d)
	var wool: StandardMaterial3D = CineFX._mat(WOOL, 1.0)
	CineFX._sphere(d, "Body", 0.11, Vector3(0.0, 0.11, 0.02), wool, Vector3(1.0, 0.9, 1.15))
	for p: Vector3 in [Vector3(-0.06, 0.02, -0.04), Vector3(0.06, 0.02, -0.04), Vector3(-0.06, 0.02, 0.08), Vector3(0.06, 0.02, 0.08)]:
		CineFX._cyl(d, "Leg", 0.018, 0.018, 0.05, p, CineFX._mat(FACE, 0.8))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.2, -0.08)
	d.add_child(head)
	CineFX._sphere(head, "Wool", 0.07, Vector3(0.0, 0.03, 0.0), wool)
	CineFX._sphere(head, "Face", 0.055, Vector3(0.0, -0.005, -0.045), CineFX._mat(FACE, 0.7), Vector3(0.85, 1.1, 0.8))
	for sx: float in [-0.022, 0.022]:
		CineFX._sphere(head, "Eye", 0.011, Vector3(sx, 0.01, -0.093), CineFX._glow_mat(Color("#FFFFFF"), 0.8))
		CineFX._box(head, "Ear", Vector3(0.05, 0.016, 0.025), Vector3(sx * 3.2, 0.03, -0.01), CineFX._mat(FACE, 0.7))
	d.set_meta("head", head)
	return head


## A hanging bulb (origin at the bulb) with its OmniLight (CineFX lamp metas, so "dark" / "flicker" windows switch it).
static func _bulb(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#FFC88A"))
	var ol := OmniLight3D.new()
	ol.name = "BulbLight"
	ol.light_color = col
	ol.light_energy = float(opts.get("energy", 1.0))
	ol.omni_range = float(opts.get("range", 7.5))
	ol.position = Vector3(0.0, -0.1, 0.0)
	root.add_child(ol)
	root.set_meta("lamp_light", ol)
	if bool(opts.get("bare", false)):
		return
	var bulb: StandardMaterial3D = CineFX._glow_mat(col.lightened(0.3), 3.0)
	CineFX._sphere(root, "Bulb", 0.07, Vector3.ZERO, bulb)
	CineFX._cyl(root, "Cord", 0.006, 0.006, 0.4, Vector3(0.0, 0.25, 0.0), CineFX._mat(Color("#111111"), 0.8))
	root.set_meta("lamp_bulb", bulb)


## Vanity: a table, a tall mirror framed by bulbs and a stool (front toward -Z; the glass faces -Z). Meta "glass".
static func _vanity(root: Node3D) -> void:
	CineFX._box(root, "Table", Vector3(1.1, 0.75, 0.5), Vector3(0.0, 0.375, 0.0), CineFX._mat(Color("#F2E6EA"), 0.5))
	CineFX._box(root, "Frame", Vector3(0.9, 1.1, 0.06), Vector3(0.0, 1.35, 0.2), CineFX._mat(Color("#E8C15A"), 0.35))
	var glass: StandardMaterial3D = CineFX._mat(Color(0.25, 0.28, 0.34, 0.75), 0.02)
	glass.metallic = 0.9
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g: MeshInstance3D = CineFX._box(root, "Glass", Vector3(0.78, 0.98, 0.01), Vector3(0.0, 1.35, 0.165), glass)
	var bulb: StandardMaterial3D = CineFX._glow_mat(Color("#FFE7B8"), 2.2)
	for i: int in 5:
		for sx: float in [-0.47, 0.47]:
			CineFX._sphere(root, "Bulb", 0.03, Vector3(sx, 0.9 + 0.22 * float(i), 0.16), bulb)
	CineFX._cyl(root, "Stool", 0.2, 0.18, 0.45, Vector3(0.0, 0.225, -0.6), CineFX._mat(Color("#FF7AB6"), 0.9))
	for k: int in 4:
		CineFX._cyl(root, "Bottle", 0.025, 0.025, 0.1 + 0.03 * float(k % 2), Vector3(-0.35 + 0.15 * float(k), 0.8, 0.05), CineFX._mat(Color.from_hsv(0.9 - 0.08 * float(k), 0.5, 0.95), 0.2))
	root.set_meta("glass", g)


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------
## [kind, pos, yaw_deg, opts] of the shop furniture in the shop frame (cups, the jars, the neon sign).
static func shop_cup_pos(i: int) -> Vector3:
	return Vector3(CUP_X[i], COUNTER_Y, COUNTER_Z)


## The front room of Trà Sữa Lọ (set): floor, walls with the glass front door (-Z) and the back door (+Z, x = 3), the
## counter (customers on -Z, staff on +Z) with the logo, the back counter with topping jars and the menu board, pendant
## lamps, the pink neon sign over the door outside, warm lights.
static func _tea_shop(root: Node3D) -> void:
	var hw: float = SHOP_W * 0.5
	var hd: float = SHOP_D * 0.5
	var wall: StandardMaterial3D = CineFX._mat(Color("#FCE4EE"), 0.9)
	var floor_m: StandardMaterial3D = CineFX._mat(Color("#E9D6C4"), 0.7)
	CineFX._box(root, "Floor", Vector3(SHOP_W, 0.1, SHOP_D), Vector3(0.0, -0.05, 0.0), floor_m)
	CineFX._box(root, "Ceiling", Vector3(SHOP_W, 0.1, SHOP_D), Vector3(0.0, 3.25, 0.0), wall)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Side", Vector3(0.12, 3.2, SHOP_D), Vector3(sx * hw, 1.6, 0.0), wall)
	# back wall (+Z) with the back door at SHOP_BACK_DOOR_X
	var dl: float = SHOP_BACK_DOOR_X - 0.6 + hw
	CineFX._box(root, "BackL", Vector3(dl, 3.2, 0.12), Vector3(-hw + dl * 0.5, 1.6, hd), wall)
	var dr: float = hw - SHOP_BACK_DOOR_X - 0.6
	CineFX._box(root, "BackR", Vector3(dr, 3.2, 0.12), Vector3(hw - dr * 0.5, 1.6, hd), wall)
	CineFX._box(root, "BackTop", Vector3(1.2, 1.1, 0.12), Vector3(SHOP_BACK_DOOR_X, 2.65, hd), wall)
	CineFX._box(root, "BackDoor", Vector3(1.1, 2.1, 0.05), Vector3(SHOP_BACK_DOOR_X, 1.05, hd - 0.05), CineFX._mat(Color("#5A3A28"), 0.7))
	text(root, "Staff", "NHÂN VIÊN", 40, Color("#5A3A28"), Vector3(SHOP_BACK_DOOR_X, 2.3, hd - 0.08))
	# front wall (-Z): glass with the door in the middle
	var glass: StandardMaterial3D = CineFX._mat(Color(0.7, 0.85, 1.0, 0.25), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for sx2: float in [-1.0, 1.0]:
		CineFX._box(root, "FrontGlass", Vector3(hw - 0.8, 2.4, 0.04), Vector3(sx2 * (hw * 0.5 + 0.4), 1.2, -hd), glass)
		CineFX._box(root, "FrontPost", Vector3(0.1, 3.2, 0.12), Vector3(sx2 * 0.8, 1.6, -hd), CineFX._mat(Color("#FF7AB6"), 0.5))
	CineFX._box(root, "FrontTop", Vector3(SHOP_W, 0.8, 0.12), Vector3(0.0, 2.8, -hd), wall)
	text(root, "Neon", "TRÀ SỮA LỌ", 150, NEON, Vector3(0.0, 2.85, -hd - 0.1), true)
	# counter
	CineFX._box(root, "Counter", Vector3(4.6, 0.95, 0.7), Vector3(0.0, 0.475, COUNTER_Z), CineFX._mat(Color("#FF8EC4"), 0.5))
	CineFX._box(root, "CounterTop", Vector3(4.7, 0.06, 0.8), Vector3(0.0, COUNTER_Y - 0.03, COUNTER_Z), CineFX._mat(Color("#FFFFFF"), 0.3))
	text(root, "Logo", "LỌ", 120, Color("#FFFFFF"), Vector3(0.0, 0.55, COUNTER_Z - 0.37))
	for i: int in CUP_X.size():
		CineFX._cyl(root, "CupMat", 0.07, 0.07, 0.008, shop_cup_pos(i) + Vector3(0.0, 0.005, 0.0), CineFX._glow_mat(Color("#FFE66D"), 0.4))
		text(root, "Key", str(i + 1), 40, Color("#FFE66D"), shop_cup_pos(i) + Vector3(0.0, 0.03, -0.32)).rotation.x = -PI * 0.35
	# back counter and the menu board
	CineFX._box(root, "BackCounter", Vector3(6.0, 0.95, 0.6), Vector3(-1.0, 0.475, hd - 0.4), CineFX._mat(Color("#F4F1EA"), 0.6))
	var jar_cols: Array[Color] = [Color("#1A120E"), Color("#F6F2D8"), Color("#F2C14E"), Color("#FFF4D6"), Color("#8DBF5A"), Color("#A88BD6")]
	for j: int in jar_cols.size():
		CineFX._cyl(root, "Jar", 0.12, 0.12, 0.3, Vector3(-3.4 + 0.75 * float(j), 1.1, hd - 0.4), CineFX._mat(jar_cols[j], 0.3))
	CineFX._box(root, "Board", Vector3(4.2, 1.1, 0.05), Vector3(-1.2, 2.3, hd - 0.1), CineFX._mat(Color("#2A1A22"), 0.6))
	text(root, "Menu", "TRÀ SỮA TRUYỀN THỐNG   25K\nMATCHA   29K\nKHOAI MÔN   29K\nDÂU   27K", 34, Color("#FFE6F3"), Vector3(-1.2, 2.35, hd - 0.14))
	var pend: StandardMaterial3D = CineFX._glow_mat(Color("#FFD0E6"), 2.0)
	for px: float in [-2.0, 0.0, 2.0]:
		CineFX._sphere(root, "Pendant", 0.14, Vector3(px, 2.6, COUNTER_Z), pend, Vector3(1.0, 0.6, 1.0))
	for lp: Vector3 in [Vector3(-2.0, 2.4, 0.4), Vector3(2.0, 2.4, 0.4), Vector3(0.0, 2.4, -2.6)]:
		var ol := OmniLight3D.new()
		ol.name = "ShopLight"
		ol.light_color = Color("#FFD9E8")
		ol.light_energy = 1.1
		ol.omni_range = 6.5
		ol.position = lp
		root.add_child(ol)


# ---------------------------------------------------------------------------
# Canal
# ---------------------------------------------------------------------------
## A row of n canal houses along X (front toward -Z; origin at the row's centre on the ground), lit windows (emissive).
static func _house_row(root: Node3D, opts: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 6))
	var n: int = int(opts.get("n", 8))
	var x: float = 0.0
	var ws: Array[float] = []
	for i: int in n:
		ws.append(rng.randf_range(5.5, 8.0))
		x += ws[i]
	x = -x * 0.5
	for i2: int in n:
		var h: float = rng.randf_range(4.0, 10.0)
		var dep: float = rng.randf_range(6.0, 8.0)
		var c := Vector3(x + ws[i2] * 0.5, h * 0.5, dep * 0.5)
		CineFX._box(root, "House", Vector3(ws[i2] - 0.3, h, dep), c, CineFX._mat(Color.from_hsv(rng.randf_range(0.02, 0.12), 0.3, rng.randf_range(0.35, 0.55)), 0.9))
		for f: int in int(h / 3.0):
			for k: int in 2:
				if rng.randf() < 0.6:
					CineFX._box(root, "Window", Vector3(0.9, 1.1, 0.03), Vector3(c.x - ws[i2] * 0.25 + ws[i2] * 0.5 * float(k), 1.6 + 3.0 * float(f), -0.02), CineFX._glow_mat(Color.from_hsv(rng.randf_range(0.08, 0.14), 0.5, 1.0), 1.6))
		x += ws[i2]


## A piece of canal bank (set) for the cinematics outside the lair: the land on +Z (top at y = 0), the stone edge at z = 0,
## the water on -Z (y = -1, the code water shader), a lantern string, two bollards. opts "w" (along X), "d" (water depth).
static func _canal_bank(root: Node3D, opts: Dictionary) -> void:
	var w: float = float(opts.get("w", 30.0))
	var d: float = float(opts.get("d", 24.0))
	CineFX._box(root, "Land", Vector3(w, 1.2, 10.0), Vector3(0.0, -0.6, 5.0), CineFX._mat(Color("#3A3A36"), 0.95))
	CineFX._box(root, "Edge", Vector3(w, 0.15, 0.4), Vector3(0.0, 0.02, 0.2), CineFX._mat(Color("#8A8478"), 0.8))
	var water := MeshInstance3D.new()
	water.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(w + 20.0, d)
	pm.subdivide_width = 24
	pm.subdivide_depth = 16
	water.mesh = pm
	water.material_override = water_material()
	water.position = Vector3(0.0, -1.0, -d * 0.5)
	root.add_child(water)
	for i: int in 7:
		lantern(root, Vector3(-w * 0.4 + w * 0.8 * float(i) / 6.0, 2.6 - 0.25 * absf(sin(float(i) * 1.3)), 0.6), Color.from_hsv(0.95 - 0.06 * float(i % 3), 0.75, 1.0))
	CineFX._box(root, "Wire", Vector3(w * 0.8, 0.01, 0.01), Vector3(0.0, 2.85, 0.6), CineFX._mat(Color("#111111"), 0.8))
	for bx: float in [-4.0, 5.0]:
		CineFX._cyl(root, "Bollard", 0.12, 0.14, 0.45, Vector3(bx, 0.22, 0.5), CineFX._mat(Color("#22252A"), 0.5))


## A low canal bridge across X (span), the deck's underside at `clear` above the water line (origin on the water line at the
## canal centre): the beam with red-white warning stripes, the rails, abutments at both ends, a red warning strip and
## lanterns under the beam, a "CẦU THẤP" sign.
static func low_bridge(root: Node3D, span: float, clear: float) -> void:
	var conc: StandardMaterial3D = CineFX._mat(Color("#8E8A80"), 0.85)
	CineFX._box(root, "Deck", Vector3(span + 6.0, 0.55, 4.0), Vector3(0.0, clear + 0.275, 0.0), conc)
	var stripe_r: StandardMaterial3D = CineFX._glow_mat(Color("#FF2A2A"), 1.6)
	var stripe_w: StandardMaterial3D = CineFX._mat(Color("#F4F1EA"), 0.6)
	var n: int = int(span / 1.2)
	for i: int in n:
		CineFX._box(root, "Stripe", Vector3(1.2, 0.3, 0.03), Vector3(-span * 0.5 + 0.6 + 1.2 * float(i), clear + 0.2, -2.02), stripe_r if i % 2 == 0 else stripe_w)
	for sz: float in [-1.9, 1.9]:
		CineFX._box(root, "Rail", Vector3(span + 6.0, 0.08, 0.08), Vector3(0.0, clear + 1.45, sz), CineFX._mat(Color("#2A2C33"), 0.5))
		for k: int in int((span + 6.0) / 2.5):
			CineFX._box(root, "Post", Vector3(0.06, 0.9, 0.06), Vector3(-(span + 6.0) * 0.5 + 1.25 + 2.5 * float(k), clear + 1.0, sz), CineFX._mat(Color("#2A2C33"), 0.5))
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Abutment", Vector3(3.0, clear + 1.8, 4.4), Vector3(sx * (span * 0.5 + 1.5), (clear + 1.8) * 0.5 - 1.2, 0.0), conc)
	for j: int in 4:
		lantern(root, Vector3(-span * 0.35 + span * 0.7 * float(j) / 3.0, clear - 0.25, -2.1), Color("#FFB86B"))
	text(root, "Sign", "CẦU THẤP", 90, Color("#FFE66D"), Vector3(0.0, clear + 0.95, -2.06), true)


## A moored wooden sampan (origin on the water line, length along Z); "ramp": tipped up so its stern makes a ramp toward -Z
## (the boat jump).
static func sampan(root: Node3D, ramp: bool) -> void:
	var wood: StandardMaterial3D = CineFX._mat(Color("#6B4426"), 0.85)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	CineFX._box(body, "Hull", Vector3(1.6, 0.5, 6.0), Vector3(0.0, 0.1, 0.0), wood)
	_prism(body, "BowF", Vector3(1.6, 1.0, 0.5), Vector3(0.0, 0.1, -3.5), wood, Vector3(-PI * 0.5, 0.0, 0.0))
	_prism(body, "BowB", Vector3(1.6, 1.0, 0.5), Vector3(0.0, 0.1, 3.5), wood, Vector3(PI * 0.5, 0.0, 0.0))
	CineFX._box(body, "Roof", Vector3(1.8, 0.08, 2.2), Vector3(0.0, 1.1, 0.6), CineFX._mat(Color("#3A2A18"), 0.9))
	if ramp:
		body.rotation.x = deg_to_rad(-13.0)   # the -Z end up: the ramp lip
		body.position.y = 0.55
		var chev: StandardMaterial3D = CineFX._glow_mat(Color("#FFE66D"), 2.2)
		for i: int in 3:
			_prism(body, "Chevron", Vector3(0.9, 0.5, 0.04), Vector3(0.0, 0.37, 1.5 - 1.3 * float(i)), chev, Vector3(-PI * 0.5, 0.0, 0.0))
		root.set_meta("lip_y", 0.55 + 3.0 * sin(deg_to_rad(13.0)))


## A broken bridge pier across the canal (the ramp jump clears it): concrete block w x 1.6 m with rubble and rebar, a
## gap left of it (origin on the water line at its centre).
static func pier_wall(root: Node3D, w: float) -> void:
	var conc: StandardMaterial3D = CineFX._mat(Color("#7E7A70"), 0.9)
	CineFX._box(root, "Pier", Vector3(w, 2.6, 1.6), Vector3(0.0, 0.3, 0.0), conc)
	var rebar: StandardMaterial3D = CineFX._mat(Color("#5A3A28"), 0.6)
	for i: int in 6:
		CineFX._box(root, "Rebar", Vector3(0.04, 0.7, 0.04), Vector3(-w * 0.4 + w * 0.16 * float(i), 1.9, 0.2 * float(i % 2)), rebar, Vector3(0.2 * float(i % 3 - 1), 0.0, 0.3))
	for k: int in 5:
		CineFX._box(root, "Rubble", Vector3(0.6, 0.4, 0.5), Vector3(-w * 0.45 + w * 0.22 * float(k), 1.75, 0.3 - 0.3 * float(k % 2)), conc, Vector3(0.3, float(k), 0.2))
	var warn: StandardMaterial3D = CineFX._glow_mat(Color("#FF2A2A"), 2.0)
	for sx: float in [-0.5, 0.5]:
		CineFX._sphere(root, "Warn", 0.12, Vector3(sx * w, 1.75, -0.85), warn)
