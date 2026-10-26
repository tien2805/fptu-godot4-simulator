# File: res://scripts/cine/CinePropsC.gd
# Story Phase C props (spec C-D9 / C-D10), plain meshes and code colours only, built through CineFX.build_prop(kind, opts)
# (CineFX dispatches every kind in KINDS here). Origin on the ground and front toward -Z unless said otherwise.
#
# Wearables (held on bones in cinematics, attached to pivots by StoryCast.build in gameplay; origin = the head centre for
# head gear, the Chest / Neck bone for body gear):
#   wolf_helmet (Sói Xám and the Bầy Sói: grey wolf head, LED eyes; opts "led" Color, "led_on" bool), wolf_mask, fox_mask,
#   gold_shades, round_glasses, headphones, key_lanyard, turtleneck, hawaii_print, belly (opts "color").
# Hand props (Wrist.R; the long ones point along -Z from the grip):
#   energy_drink, cigar_vape, coffee_cup, party_horn, usb (a label "ZA MẪN LABS"), katana (opts "bend" deg, "broken"),
#   katana_blade (the broken-off piece), keyboard, server_panel (two-handed, origin at its centre), staff (Vovinam staff),
#   bike_mirror, chain (wrapped round the fist), small_crate (two-handed, breakable), pallet (breakable; opts "held").
# Sets and big props:
#   pillar (bridge pillar, opts "chain": a chain hangs on it), bridge_deck (the deck overhead: set dressing), rope (the loops
#   round a pillar and a seated captive: opts "rx", "rz", "y"), motorbike (Sói Xám's tuned bike, opts "headlight"),
#   container (a 20 ft container, doors on its -Z face that swing open: opts "anim": true, "open_at", "open_dur";
#   body behind the origin toward +Z; "inner_light"), mannequins (CineCrowd: opts "cols", "rows", "dx", "dz"; animated with
#   "anim": true + "turn_at" / "turn_from" / "clap_from"), forklift (cine prop; forks toward -Z), server_rack (breakable,
#   LEDs on -Z), server_room (walls, ceiling, red emergency light: set dressing; opts "width", "depth", "height"),
#   monitor_wall / stonks_screen / fire (CineAnimProp, "anim": true), keynote (stage, podium, big screen "LỌ THẦN 10.0":
#   set dressing), desk.
class_name CinePropsC
extends RefCounted

const KINDS: Array[String] = ["wolf_helmet", "wolf_mask", "fox_mask", "gold_shades", "round_glasses", "headphones",
	"key_lanyard", "turtleneck", "hawaii_print", "belly", "energy_drink", "cigar_vape", "coffee_cup", "party_horn", "usb",
	"katana", "katana_blade", "keyboard", "server_panel", "staff", "bike_mirror", "chain", "small_crate", "pallet", "pillar",
	"bridge_deck", "rope", "motorbike", "container", "mannequins", "forklift", "server_rack", "server_room", "monitor_wall",
	"stonks_screen", "fire", "keynote", "desk"]
const WOLF_GREY := Color("#7D8288")
const LED_RED := Color("#FF2A2A")
const CONTAINER_L: float = 6.06
const CONTAINER_W: float = 2.44
const CONTAINER_H: float = 2.59
const KATANA_BLADE: float = 0.7
const STAFF_LEN: float = 1.7


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String, root: Node3D, opts: Dictionary) -> void:
	match kind:
		"wolf_helmet":
			_wolf_helmet(root, opts)
		"wolf_mask":
			_wolf_mask(root)
		"fox_mask":
			_fox_mask(root)
		"gold_shades":
			_shades(root)
		"round_glasses":
			_round_glasses(root)
		"headphones":
			_headphones(root)
		"key_lanyard":
			_lanyard(root)
		"turtleneck":
			_turtleneck(root)
		"hawaii_print":
			_hawaii(root, opts)
		"belly":
			CineFX._sphere(root, "Belly", 0.2, Vector3.ZERO, CineFX._mat(opts.get("color", Color("#C9824E")), 0.9), Vector3(1.08, 0.9, 0.78))
		"energy_drink":
			_can(root)
		"cigar_vape":
			_vape(root)
		"coffee_cup":
			_cup(root)
		"party_horn":
			_horn(root)
		"usb":
			_usb(root)
		"katana":
			_katana(root, opts)
		"katana_blade":
			_blade(root, 0.0, KATANA_BLADE * 0.72)
		"keyboard":
			_keyboard(root)
		"server_panel":
			_panel(root)
		"staff":
			_staff(root)
		"bike_mirror":
			_mirror(root)
		"chain":
			_chain(root)
		"small_crate":
			_small_crate(root)
		"pallet":
			_pallet(root, opts)
		"pillar":
			_pillar(root, opts)
		"bridge_deck":
			_deck(root, opts)
		"rope":
			_rope(root, opts)
		"motorbike":
			_motorbike(root, opts)
		"container":
			_container(root, opts)
		"mannequins":
			var c := CineCrowd.new()
			c.layout_grid(Vector3.ZERO, int(opts.get("cols", 5)), int(opts.get("rows", 10)), float(opts.get("dx", 0.44)), float(opts.get("dz", 0.46)))
			root.add_child(c)
			root.set_meta("anim_node", c)
		"forklift":
			_forklift(root, opts)
		"server_rack":
			_rack(root, opts)
		"server_room":
			_room(root, opts)
		"monitor_wall", "stonks_screen", "fire":
			var m: String = {"monitor_wall": "wall", "stonks_screen": "stonks", "fire": "fire"}[kind]
			var ap: CineAnimProp = CineAnimProp.make(m, opts)
			root.add_child(ap)
			root.set_meta("anim_node", ap)
		"keynote":
			_keynote(root, opts)
		"desk":
			_desk(root)


# ---------------------------------------------------------------------------
# Wearables
# ---------------------------------------------------------------------------
## Grey wolf-head helmet over the whole head: dome, snout, pointed ears, a dark visor band and two LED eyes.
static func _wolf_helmet(root: Node3D, opts: Dictionary) -> void:
	var grey: StandardMaterial3D = CineFX._mat(opts.get("color", WOLF_GREY), 0.45)
	var dark: StandardMaterial3D = CineFX._mat(Color("#2A2C30"), 0.35)
	CineFX._sphere(root, "Dome", 0.15, Vector3(0.0, 0.02, 0.0), grey, Vector3(1.0, 1.05, 1.1))
	CineFX._box(root, "Snout", Vector3(0.11, 0.08, 0.12), Vector3(0.0, -0.025, -0.16), grey, Vector3(0.12, 0.0, 0.0))
	CineFX._box(root, "Nose", Vector3(0.05, 0.035, 0.03), Vector3(0.0, -0.005, -0.225), dark)
	CineFX._box(root, "Visor", Vector3(0.24, 0.05, 0.02), Vector3(0.0, 0.035, -0.152), dark)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Ear", Vector3(0.06, 0.1, 0.035), Vector3(sx * 0.075, 0.17, 0.0), grey, Vector3(0.0, 0.0, sx * -0.3))
	var led: Color = opts.get("led", LED_RED)
	var on: bool = bool(opts.get("led_on", true))
	var em: StandardMaterial3D = CineFX._glow_mat(led, 4.0) if on else CineFX._mat(Color("#301010"), 0.4)
	for sx2: float in [-0.045, 0.045]:
		CineFX._box(root, "LedEye", Vector3(0.04, 0.016, 0.01), Vector3(sx2, 0.04, -0.164), em, Vector3(0.0, 0.0, signf(sx2) * 0.2))
	root.set_meta("led_on", on)


static func _wolf_mask(root: Node3D) -> void:
	var grey: StandardMaterial3D = CineFX._mat(Color("#6E737A"), 0.6)
	var dark: StandardMaterial3D = CineFX._mat(Color("#1C1D20"), 0.5)
	CineFX._sphere(root, "Plate", 0.11, Vector3(0.0, 0.03, -0.085), grey, Vector3(1.0, 1.15, 0.45))
	CineFX._box(root, "Snout", Vector3(0.08, 0.06, 0.09), Vector3(0.0, -0.02, -0.15), grey, Vector3(0.15, 0.0, 0.0))
	CineFX._box(root, "Nose", Vector3(0.04, 0.03, 0.02), Vector3(0.0, 0.0, -0.198), dark)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Ear", Vector3(0.055, 0.09, 0.03), Vector3(sx * 0.07, 0.15, -0.05), grey, Vector3(0.0, 0.0, sx * -0.35))
		CineFX._sphere(root, "EyeHole", 0.016, Vector3(sx * 0.035, 0.05, -0.135), dark, Vector3(1.5, 0.8, 0.4))


static func _fox_mask(root: Node3D) -> void:
	var orange: StandardMaterial3D = CineFX._mat(Color("#D9681E"), 0.6)
	var white: StandardMaterial3D = CineFX._mat(Color("#F4F1EA"), 0.7)
	var dark: StandardMaterial3D = CineFX._mat(Color("#1C1D20"), 0.5)
	CineFX._sphere(root, "Plate", 0.11, Vector3(0.0, 0.035, -0.085), orange, Vector3(1.05, 1.1, 0.45))
	CineFX._box(root, "Muzzle", Vector3(0.07, 0.05, 0.1), Vector3(0.0, -0.025, -0.15), white, Vector3(0.2, 0.0, 0.0))
	CineFX._box(root, "Nose", Vector3(0.03, 0.025, 0.02), Vector3(0.0, -0.005, -0.2), dark)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Ear", Vector3(0.05, 0.12, 0.03), Vector3(sx * 0.07, 0.17, -0.05), orange, Vector3(0.0, 0.0, sx * -0.25))
		CineFX._sphere(root, "EyeHole", 0.016, Vector3(sx * 0.035, 0.055, -0.135), dark, Vector3(1.6, 0.7, 0.4))


## Gold aviator-ish sunglasses at eye level in front of the face.
static func _shades(root: Node3D) -> void:
	var gold: StandardMaterial3D = CineFX._mat(Color("#D4AF37"), 0.25)
	gold.metallic = 0.8
	var lens: StandardMaterial3D = CineFX._mat(Color("#3A2A10"), 0.1)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Lens", Vector3(0.05, 0.032, 0.006), Vector3(sx * 0.034, 0.0, 0.0), lens)
		CineFX._box(root, "Rim", Vector3(0.054, 0.004, 0.008), Vector3(sx * 0.034, 0.018, 0.0), gold)
		CineFX._box(root, "Temple", Vector3(0.004, 0.004, 0.11), Vector3(sx * 0.072, 0.012, 0.055), gold)
	CineFX._box(root, "Bridge", Vector3(0.02, 0.004, 0.006), Vector3(0.0, 0.012, 0.0), gold)


## Round wire glasses (Za Mẫn).
static func _round_glasses(root: Node3D) -> void:
	var wire: StandardMaterial3D = CineFX._mat(Color("#141416"), 0.3)
	for sx: float in [-1.0, 1.0]:
		var t := MeshInstance3D.new()
		t.name = "Rim"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.019
		tm.outer_radius = 0.023
		tm.rings = 14
		tm.ring_segments = 4
		t.mesh = tm
		t.material_override = wire
		t.position = Vector3(sx * 0.033, 0.0, 0.0)
		t.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		root.add_child(t)
		CineFX._box(root, "Temple", Vector3(0.003, 0.003, 0.11), Vector3(sx * 0.07, 0.004, 0.055), wire)
	CineFX._box(root, "Bridge", Vector3(0.022, 0.003, 0.003), Vector3(0.0, 0.006, 0.0), wire)


## Over-ear headphones: a band over the head and two cups by the ears (origin at the head centre).
static func _headphones(root: Node3D) -> void:
	var black: StandardMaterial3D = CineFX._mat(Color("#1B1C20"), 0.5)
	var accent: StandardMaterial3D = CineFX._mat(Color("#F37021"), 0.5)
	for i: int in 7:
		var a: float = PI * float(i) / 6.0
		CineFX._box(root, "Band", Vector3(0.05, 0.022, 0.035), Vector3(cos(a) * 0.125, 0.02 + sin(a) * 0.135, 0.0), black,
			Vector3(0.0, 0.0, a - PI * 0.5))
	for sx: float in [-1.0, 1.0]:
		var cup: MeshInstance3D = CineFX._cyl(root, "Cup", 0.05, 0.05, 0.045, Vector3(sx * 0.13, 0.0, 0.0), black)
		cup.rotation = Vector3(0.0, 0.0, PI * 0.5)
		var ring: MeshInstance3D = CineFX._cyl(root, "CupRing", 0.052, 0.052, 0.012, Vector3(sx * 0.152, 0.0, 0.0), accent)
		ring.rotation = Vector3(0.0, 0.0, PI * 0.5)


## A lanyard from the back of the neck down the chest with a bunch of keys and a badge (origin at the Chest bone).
static func _lanyard(root: Node3D) -> void:
	var cord: StandardMaterial3D = CineFX._mat(Color("#F37021"), 0.7)
	var metal: StandardMaterial3D = CineFX._mat(Color("#C9C9C9"), 0.3)
	metal.metallic = 0.7
	for sx: float in [-1.0, 1.0]:
		var a := Vector3(sx * 0.07, 0.13, -0.05)
		var b := Vector3(0.0, -0.13, -0.035)
		var bar: MeshInstance3D = CineFX._box(root, "Cord", Vector3(0.012, a.distance_to(b), 0.004), (a + b) * 0.5, cord)
		bar.rotation = Vector3(0.0, 0.0, atan2(b.x - a.x, a.y - b.y))
	CineFX._box(root, "Badge", Vector3(0.055, 0.075, 0.004), Vector3(0.0, -0.18, -0.035), CineFX._mat(Color("#F4F1EA"), 0.6))
	for i: int in 3:
		CineFX._box(root, "Key", Vector3(0.012, 0.045, 0.003), Vector3(-0.025 + 0.02 * i, -0.15, -0.04), metal, Vector3(0.0, 0.0, -0.3 + 0.3 * i))


## The rolled collar of a turtleneck round the neck (origin at the Neck bone).
static func _turtleneck(root: Node3D) -> void:
	var black: StandardMaterial3D = CineFX._mat(Color("#141416"), 0.9)
	var t := MeshInstance3D.new()
	t.name = "Collar"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.045
	tm.outer_radius = 0.078
	tm.rings = 12
	tm.ring_segments = 6
	t.mesh = tm
	t.material_override = black
	t.position = Vector3(0.0, -0.035, 0.012)
	t.scale = Vector3(1.0, 1.6, 1.0)
	root.add_child(t)


## Hawaiian shirt flowers: flat petal clusters on the chest and the shoulders (origin at the Chest bone; opts "depth": front z).
static func _hawaii(root: Node3D, opts: Dictionary) -> void:
	var z: float = float(opts.get("depth", -0.135))
	var cols: Array[Color] = [Color("#FFD43B"), Color("#FF5D8F"), Color("#F4F1EA"), Color("#FF8A3D")]
	var spots: Array[Vector3] = [Vector3(-0.08, 0.02, z), Vector3(0.07, -0.06, z + 0.01), Vector3(-0.03, -0.17, z - 0.01),
		Vector3(0.1, 0.06, z + 0.02), Vector3(-0.12, -0.1, z + 0.02), Vector3(0.04, -0.24, z - 0.01)]
	for i: int in spots.size():
		var m: StandardMaterial3D = CineFX._mat(cols[i % cols.size()], 0.8)
		for k: int in 5:
			var a: float = TAU * float(k) / 5.0 + float(i)
			CineFX._sphere(root, "Petal", 0.016, spots[i] + Vector3(cos(a) * 0.017, sin(a) * 0.017, 0.0), m, Vector3(1.0, 1.0, 0.35))
		CineFX._sphere(root, "Heart", 0.009, spots[i] + Vector3(0.0, 0.0, -0.004), CineFX._mat(Color("#7A3B12"), 0.8), Vector3(1.0, 1.0, 0.5))


# ---------------------------------------------------------------------------
# Hand props
# ---------------------------------------------------------------------------
static func _can(root: Node3D) -> void:
	CineFX._cyl(root, "Can", 0.033, 0.033, 0.125, Vector3.ZERO, CineFX._mat(Color("#7ED321"), 0.35))
	CineFX._cyl(root, "Band", 0.0335, 0.0335, 0.04, Vector3(0.0, 0.0, 0.0), CineFX._mat(Color("#141414"), 0.4))
	CineFX._cyl(root, "Lid", 0.03, 0.03, 0.005, Vector3(0.0, 0.064, 0.0), CineFX._mat(Color("#C9C9C9"), 0.3))


static func _vape(root: Node3D) -> void:
	var body: MeshInstance3D = CineFX._cyl(root, "Vape", 0.011, 0.012, 0.12, Vector3(0.0, 0.0, -0.06), CineFX._mat(Color("#6B3E1E"), 0.6))
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var band: MeshInstance3D = CineFX._cyl(root, "Band", 0.0125, 0.0125, 0.015, Vector3(0.0, 0.0, -0.02), CineFX._mat(Color("#D4AF37"), 0.3))
	band.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	CineFX._sphere(root, "Tip", 0.011, Vector3(0.0, 0.0, -0.122), CineFX._glow_mat(Color("#FF6A1E"), 3.0))


static func _cup(root: Node3D) -> void:
	CineFX._cyl(root, "Cup", 0.04, 0.036, 0.095, Vector3.ZERO, CineFX._mat(Color("#F4F1EA"), 0.6))
	CineFX._cyl(root, "Coffee", 0.037, 0.037, 0.004, Vector3(0.0, 0.045, 0.0), CineFX._mat(Color("#3B2314"), 0.4))
	var h := MeshInstance3D.new()
	h.name = "Handle"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.016
	tm.outer_radius = 0.024
	h.mesh = tm
	h.material_override = CineFX._mat(Color("#F4F1EA"), 0.6)
	h.position = Vector3(0.045, 0.0, 0.0)
	h.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(h)


## Party horn blown straight out from the mouth (origin at the mouthpiece, the tube along -Z).
static func _horn(root: Node3D) -> void:
	var cols: Array[Color] = [Color("#FF3B7F"), Color("#FFD43B"), Color("#3BC9FF")]
	for i: int in 6:
		var seg: MeshInstance3D = CineFX._cyl(root, "Tube%d" % i, 0.011 + 0.0016 * i, 0.011 + 0.0016 * (i + 1), 0.04, Vector3(0.0, 0.0, -0.02 - 0.04 * i), CineFX._mat(cols[i % 3], 0.6))
		seg.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	var curl := MeshInstance3D.new()
	curl.name = "Curl"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.012
	tm.outer_radius = 0.026
	curl.mesh = tm
	curl.material_override = CineFX._mat(cols[1], 0.6)
	curl.position = Vector3(0.0, -0.02, -0.255)
	curl.rotation = Vector3(0.0, 0.0, PI * 0.5)
	root.add_child(curl)
	CineFX._box(root, "Tassel", Vector3(0.006, 0.05, 0.006), Vector3(0.0, -0.03, -0.24), CineFX._mat(cols[2], 0.6))


## USB stick with the label "ZA MẪN LABS" (readable in a close-up).
static func _usb(root: Node3D) -> void:
	CineFX._box(root, "Body", Vector3(0.024, 0.012, 0.07), Vector3.ZERO, CineFX._mat(Color("#141416"), 0.4))
	CineFX._box(root, "Plug", Vector3(0.016, 0.006, 0.018), Vector3(0.0, 0.0, -0.044), CineFX._mat(Color("#C9C9C9"), 0.3))
	CineFX._box(root, "Led", Vector3(0.004, 0.004, 0.004), Vector3(0.0, 0.007, 0.028), CineFX._glow_mat(Color("#3FA9FF"), 3.0))
	var l := Label3D.new()
	l.name = "UsbLabel"
	l.text = "ZA MẪN LABS"
	l.font_size = 32
	l.pixel_size = 0.00028
	l.outline_size = 0
	l.modulate = Color("#F37021")
	l.position = Vector3(0.0, 0.0065, 0.0)
	l.rotation = Vector3(-PI * 0.5, PI * 0.5, 0.0)
	root.add_child(l)


## Katana "bought online": handle at the grip (origin), guard, blade along -Z. opts "bend" (deg, the outer part droops),
## "broken" (only a short stub of blade is left).
static func _katana(root: Node3D, opts: Dictionary) -> void:
	var wrap: StandardMaterial3D = CineFX._mat(Color("#1B1B1F"), 0.7)
	var h: MeshInstance3D = CineFX._cyl(root, "Handle", 0.015, 0.015, 0.26, Vector3(0.0, 0.0, 0.06), wrap)
	h.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var g: MeshInstance3D = CineFX._cyl(root, "Guard", 0.04, 0.04, 0.01, Vector3(0.0, 0.0, -0.075), CineFX._mat(Color("#C9A227"), 0.3))
	g.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	if bool(opts.get("broken", false)):
		_blade(root, 0.0, 0.12)
		return
	var bend: float = float(opts.get("bend", 0.0))
	_blade(root, 0.0, KATANA_BLADE * 0.4)
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0.0, 0.0, -0.08 - KATANA_BLADE * 0.4)
	tip.rotation = Vector3(deg_to_rad(-bend), 0.0, 0.0)
	root.add_child(tip)
	_blade(tip, 0.0, KATANA_BLADE * 0.6, true)


## A straight piece of blade from z0 to z0 + len (along -Z) starting just past the guard (or at the node origin with `rel`).
static func _blade(root: Node3D, z0: float, ln: float, rel: bool = false) -> void:
	var steel: StandardMaterial3D = CineFX._mat(Color("#D7DDE3"), 0.15)
	steel.metallic = 0.85
	var start: float = z0 if rel else z0 - 0.08
	CineFX._box(root, "Blade", Vector3(0.006, 0.03, ln), Vector3(0.0, 0.0, start - ln * 0.5), steel)


static func _keyboard(root: Node3D) -> void:
	CineFX._box(root, "Case", Vector3(0.44, 0.028, 0.15), Vector3.ZERO, CineFX._mat(Color("#202227"), 0.5))
	for i: int in 4:
		CineFX._box(root, "Keys%d" % i, Vector3(0.4, 0.008, 0.026), Vector3(0.0, 0.018, -0.05 + 0.033 * i), CineFX._mat(Color("#3A3D45"), 0.6))


## A server rack's front panel, torn off (two-handed: origin at its centre).
static func _panel(root: Node3D) -> void:
	CineFX._box(root, "Panel", Vector3(0.6, 0.9, 0.03), Vector3.ZERO, CineFX._mat(Color("#2A2D33"), 0.4))
	for i: int in 6:
		CineFX._box(root, "Vent", Vector3(0.48, 0.02, 0.008), Vector3(0.0, -0.3 + 0.12 * i, -0.018), CineFX._mat(Color("#121316"), 0.6))
	CineFX._box(root, "Led", Vector3(0.03, 0.012, 0.01), Vector3(0.24, 0.4, -0.02), CineFX._glow_mat(Color("#3BFF7A"), 3.0))


## Vovinam staff (gậy): a wooden pole along Z, the grip (origin) a third of the way from the back end.
static func _staff(root: Node3D) -> void:
	var wood: StandardMaterial3D = CineFX._mat(Color("#8A5A2B"), 0.6)
	var p: MeshInstance3D = CineFX._cyl(root, "Staff", 0.016, 0.016, STAFF_LEN, Vector3(0.0, 0.0, 0.45 - STAFF_LEN * 0.5), wood)
	p.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	for z: float in [0.42, 0.45 - STAFF_LEN + 0.03]:
		var cap: MeshInstance3D = CineFX._cyl(root, "Cap", 0.018, 0.018, 0.05, Vector3(0.0, 0.0, z), CineFX._mat(Color("#C0392B"), 0.6))
		cap.rotation = Vector3(PI * 0.5, 0.0, 0.0)


## A motorbike mirror ripped off the handlebar: a stalk along -Z with the oval mirror at its end.
static func _mirror(root: Node3D) -> void:
	var stalk: MeshInstance3D = CineFX._cyl(root, "Stalk", 0.008, 0.008, 0.26, Vector3(0.0, 0.0, -0.12), CineFX._mat(Color("#2B2D31"), 0.4))
	stalk.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	CineFX._sphere(root, "Mirror", 0.07, Vector3(0.0, 0.02, -0.28), CineFX._mat(Color("#1B1C20"), 0.4), Vector3(1.3, 0.85, 0.3))
	CineFX._sphere(root, "Glass", 0.06, Vector3(0.0, 0.02, -0.3), CineFX._mat(Color("#AFC6D8"), 0.05), Vector3(1.3, 0.85, 0.12))


## A chain wrapped round the fist, the loose end hanging (held on Wrist.R).
static func _chain(root: Node3D) -> void:
	var steel: StandardMaterial3D = CineFX._mat(Color("#8E949B"), 0.25)
	steel.metallic = 0.8
	for i: int in 3:
		var t := MeshInstance3D.new()
		t.name = "Wrap%d" % i
		var tm := TorusMesh.new()
		tm.inner_radius = 0.045
		tm.outer_radius = 0.057
		tm.rings = 12
		tm.ring_segments = 4
		t.mesh = tm
		t.material_override = steel
		t.position = Vector3(0.0, 0.0, -0.03 - 0.025 * i)
		t.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		root.add_child(t)
	for k: int in 5:
		var l := MeshInstance3D.new()
		l.name = "Link%d" % k
		var lm := TorusMesh.new()
		lm.inner_radius = 0.008
		lm.outer_radius = 0.016
		l.mesh = lm
		l.material_override = steel
		l.position = Vector3(0.04, -0.05 - 0.026 * k, -0.05)
		l.rotation = Vector3(0.0, 0.0, PI * 0.5 * (k % 2))
		root.add_child(l)


## A small wooden crate held in both hands (origin at its centre); breakable.
static func _small_crate(root: Node3D) -> void:
	var piece := Node3D.new()
	piece.name = "SmallCratePiece"
	root.add_child(piece)
	var size: float = 0.42
	CineFX._box(piece, "Body", Vector3.ONE * size, Vector3.ZERO, CineFX._mat(CineFX.COL_CRATE, 0.85))
	for sy: float in [-1.0, 1.0]:
		CineFX._box(piece, "Batten", Vector3(size + 0.01, 0.05, size + 0.01), Vector3(0.0, sy * (size * 0.5 - 0.025), 0.0), CineFX._mat(CineFX.COL_CRATE_EDGE, 0.85))
	CineFX._breakable(root, [piece], 7, CineFX.COL_CRATE)


## Wooden pallet 1.2 x 0.8 m, 0.14 m high; breakable. opts "held": origin at its centre.
static func _pallet(root: Node3D, opts: Dictionary) -> void:
	var piece := Node3D.new()
	piece.name = "PalletPiece"
	root.add_child(piece)
	var y0: float = -0.07 if bool(opts.get("held", false)) else 0.0
	var wood: StandardMaterial3D = CineFX._mat(Color("#B48A5A"), 0.85)
	for i: int in 5:
		CineFX._box(piece, "Slat", Vector3(1.2, 0.022, 0.12), Vector3(0.0, y0 + 0.13, -0.34 + 0.17 * i), wood)
	for j: int in 3:
		CineFX._box(piece, "Block", Vector3(0.1, 0.1, 0.8), Vector3(-0.55 + 0.55 * j, y0 + 0.07, 0.0), wood)
		CineFX._box(piece, "Base", Vector3(0.14, 0.02, 0.8), Vector3(-0.55 + 0.55 * j, y0 + 0.01, 0.0), wood)
	CineFX._breakable(root, [piece], 10, Color("#B48A5A"))


# ---------------------------------------------------------------------------
# Sets and big props
# ---------------------------------------------------------------------------
## Square concrete bridge pillar (0.9 m, height opts "height" 5.6), a spray-paint stripe; opts "chain": a chain hangs on it.
static func _pillar(root: Node3D, opts: Dictionary) -> void:
	var h: float = float(opts.get("height", 5.6))
	CineFX._box(root, "Pillar", Vector3(0.9, h, 0.9), Vector3(0.0, h * 0.5, 0.0), CineFX._mat(Color("#8D8F8C"), 0.95))
	CineFX._box(root, "Paint", Vector3(0.92, 0.35, 0.92), Vector3(0.0, 1.6, 0.0), CineFX._mat(Color("#5B3F8C"), 0.9))
	if bool(opts.get("chain", false)):
		var steel: StandardMaterial3D = CineFX._mat(Color("#8E949B"), 0.25)
		for k: int in 10:
			var l := MeshInstance3D.new()
			l.name = "HangLink%d" % k
			var lm := TorusMesh.new()
			lm.inner_radius = 0.01
			lm.outer_radius = 0.02
			l.mesh = lm
			l.material_override = steel
			l.position = Vector3(0.3, 1.75 - 0.034 * k, -0.47)
			l.rotation = Vector3(0.0, 0.0, PI * 0.5 * (k % 2))
			root.add_child(l)


## The bridge deck overhead (set dressing: the real bridge stands nearby): slab, two beams, a lit lamp underneath.
static func _deck(root: Node3D, opts: Dictionary) -> void:
	var w: float = float(opts.get("width", 14.0))
	var d: float = float(opts.get("depth", 7.0))
	var y: float = float(opts.get("y", 5.6))
	var conc: StandardMaterial3D = CineFX._mat(Color("#7E807D"), 0.95)
	CineFX._box(root, "Deck", Vector3(w, 0.6, d), Vector3(0.0, y + 0.3, 0.0), conc)
	for sz: float in [-1.0, 1.0]:
		CineFX._box(root, "Beam", Vector3(w, 0.5, 0.5), Vector3(0.0, y - 0.25, sz * d * 0.3), conc)
	var ol := OmniLight3D.new()
	ol.name = "UnderLamp"
	ol.light_color = Color("#FFB86A")
	ol.light_energy = 1.6
	ol.omni_range = 10.0
	ol.position = Vector3(0.0, y - 0.6, 0.0)
	root.add_child(ol)


## Rope loops round a pillar and the captive sitting against it (an elliptic torus: opts "rx", "rz", "y" list of heights).
static func _rope(root: Node3D, opts: Dictionary) -> void:
	var m: StandardMaterial3D = CineFX._mat(Color("#C8A86A"), 0.9)
	for y: float in opts.get("y", [0.55, 0.8]):
		var t := MeshInstance3D.new()
		t.name = "Loop"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.97
		tm.outer_radius = 1.0
		tm.rings = 24
		tm.ring_segments = 4
		t.mesh = tm
		t.material_override = m
		t.position = Vector3(0.0, y, 0.0)
		t.scale = Vector3(float(opts.get("rx", 0.62)), 1.0, float(opts.get("rz", 0.75)))
		root.add_child(t)


## Sói Xám's tuned manual bike: the scooter body in gunmetal with a tank, raised bars and twin pipes.
static func _motorbike(root: Node3D, opts: Dictionary) -> void:
	CineFX._build_scooter(root, {"color": Color("#3C4148"), "headlight": bool(opts.get("headlight", false))})
	CineFX._box(root, "Tank", Vector3(0.3, 0.18, 0.45), Vector3(0.0, 0.78, -0.2), CineFX._mat(Color("#8E9AA6"), 0.3))
	CineFX._box(root, "Stripe", Vector3(0.31, 0.04, 0.46), Vector3(0.0, 0.8, -0.2), CineFX._mat(LED_RED, 0.5))
	for sx: float in [-1.0, 1.0]:
		var pipe: MeshInstance3D = CineFX._cyl(root, "Pipe", 0.035, 0.035, 0.7, Vector3(sx * 0.2, 0.35, 0.45), CineFX._mat(Color("#B9BEC4"), 0.2))
		pipe.rotation = Vector3(PI * 0.5 - 0.15, 0.0, 0.0)


## A 20 ft shipping container (6.06 x 2.44 x 2.59 m): doors on the -Z face at z = 0, the body toward +Z; corrugation ribs;
## the two door leaves are posed by a CineAnimProp in "doors" mode (opts "anim": true, "open_at", "open_dur"). opts
## "color", "inner_light" (a faint cold light inside).
static func _container(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#9E3B2E"))
	var steel: StandardMaterial3D = CineFX._mat(col, 0.6)
	var rib: StandardMaterial3D = CineFX._mat(col.darkened(0.25), 0.6)
	var inside: StandardMaterial3D = CineFX._mat(col.darkened(0.55), 0.8)
	var L: float = CONTAINER_L
	var W: float = CONTAINER_W
	var H: float = CONTAINER_H
	CineFX._box(root, "Floor", Vector3(W, 0.08, L), Vector3(0.0, 0.04, L * 0.5), inside)
	CineFX._box(root, "Roof", Vector3(W, 0.06, L), Vector3(0.0, H - 0.03, L * 0.5), steel)
	CineFX._box(root, "Back", Vector3(W, H, 0.06), Vector3(0.0, H * 0.5, L - 0.03), steel)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "Side", Vector3(0.05, H, L), Vector3(sx * (W * 0.5 - 0.025), H * 0.5, L * 0.5), steel)
		for k: int in 8:
			CineFX._box(root, "Rib", Vector3(0.04, H - 0.2, 0.12), Vector3(sx * (W * 0.5 + 0.01), H * 0.5, 0.4 + 0.75 * k), rib)
	var anim: CineAnimProp = CineAnimProp.new()
	anim.name = "Doors"
	anim.mode = "doors"
	root.add_child(anim)
	for sx2: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "LeafL" if sx2 < 0.0 else "LeafR"
		hinge.position = Vector3(sx2 * W * 0.5, 0.0, -0.02)
		anim.add_child(hinge)
		CineFX._box(hinge, "Leaf", Vector3(W * 0.5 - 0.02, H - 0.1, 0.04), Vector3(-sx2 * (W * 0.25 - 0.01), H * 0.5, 0.0), steel)
		for b: int in 2:
			CineFX._box(hinge, "Bar", Vector3(0.035, H - 0.3, 0.035), Vector3(-sx2 * (0.25 + 0.4 * b), H * 0.5, -0.04), rib)
		anim.leaves.append(hinge)
	root.set_meta("anim_node", anim)
	if bool(opts.get("inner_light", false)):
		var ol := OmniLight3D.new()
		ol.name = "InnerLight"
		ol.light_color = Color("#9FB8FF")
		ol.light_energy = 0.7
		ol.omni_range = 4.5
		ol.position = Vector3(0.0, H - 0.4, 1.2)
		root.add_child(ol)


## A warehouse forklift (Alexander's), forks toward -Z: chassis, counterweight, overhead guard, mast, forks with a pallet
## (opts "pallet"), four wheels, an amber beacon. Height 2.2 m, footprint 1.2 x 2.3 m (+ forks 1.1 m).
static func _forklift(root: Node3D, opts: Dictionary) -> void:
	var yellow: StandardMaterial3D = CineFX._mat(Color("#F2B705"), 0.5)
	var dark: StandardMaterial3D = CineFX._mat(Color("#1E1F22"), 0.6)
	var steel: StandardMaterial3D = CineFX._mat(Color("#55595F"), 0.35)
	CineFX._box(root, "Chassis", Vector3(1.15, 0.75, 1.9), Vector3(0.0, 0.62, 0.15), yellow)
	CineFX._box(root, "Counterweight", Vector3(1.15, 0.6, 0.35), Vector3(0.0, 0.8, 1.05), dark)
	CineFX._box(root, "Seat", Vector3(0.45, 0.12, 0.45), Vector3(0.0, 1.06, 0.35), dark)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-0.6, 0.85]:
			CineFX._box(root, "Post", Vector3(0.06, 1.15, 0.06), Vector3(sx * 0.5, 1.55, sz), steel)
		CineFX._box(root, "Upright", Vector3(0.09, 2.2, 0.12), Vector3(sx * 0.38, 1.1, -0.9), steel)
		CineFX._box(root, "Fork", Vector3(0.12, 0.05, 1.1), Vector3(sx * 0.3, 0.1, -1.5), steel)
		for wz: float in [-0.55, 0.75]:
			var wh: MeshInstance3D = CineFX._cyl(root, "Wheel", 0.27, 0.27, 0.2, Vector3(sx * 0.5, 0.27, wz), dark)
			wh.rotation = Vector3(0.0, 0.0, PI * 0.5)
	CineFX._box(root, "Guard", Vector3(1.1, 0.06, 1.55), Vector3(0.0, 2.13, 0.12), steel)
	CineFX._box(root, "Carriage", Vector3(0.85, 0.5, 0.06), Vector3(0.0, 0.4, -0.97), steel)
	CineFX._sphere(root, "Beacon", 0.06, Vector3(0.0, 2.22, 0.6), CineFX._glow_mat(Color("#FFAA22"), 3.0))
	if bool(opts.get("pallet", false)):
		var p := Node3D.new()
		p.name = "ForkPallet"
		p.position = Vector3(0.0, 0.13, -1.5)
		root.add_child(p)
		_pallet(p, {})


## A 42U server rack (0.6 x 2.0 x 1.0 m), black, rows of blinking LEDs on its -Z face; breakable (crate_break).
static func _rack(root: Node3D, opts: Dictionary) -> void:
	var piece := Node3D.new()
	piece.name = "RackPiece"
	root.add_child(piece)
	CineFX._box(piece, "Cabinet", Vector3(0.6, 2.0, 1.0), Vector3(0.0, 1.0, 0.0), CineFX._mat(Color("#16171B"), 0.4))
	var leds: Array[Color] = [Color("#3BFF7A"), Color("#3BA7FF"), Color("#FFB23B")]
	for i: int in 10:
		CineFX._box(piece, "Unit", Vector3(0.5, 0.1, 0.01), Vector3(0.0, 0.3 + 0.16 * i, -0.505), CineFX._mat(Color("#24262C"), 0.5))
		CineFX._box(piece, "Led", Vector3(0.03, 0.015, 0.01), Vector3(0.19, 0.3 + 0.16 * i, -0.512), CineFX._glow_mat(leds[(i + int(opts.get("seed", 0))) % 3], 3.0))
	CineFX._breakable(root, [piece], 10, Color("#2A2C31"))


## Server room set (set dressing for the basement under The Beverly tower): raised floor, three walls, ceiling with cable
## trays, a red emergency light; the open side faces +Z. opts "width" (x), "depth" (z extent behind the origin toward -Z),
## "height", "red" (emergency light on).
static func _room(root: Node3D, opts: Dictionary) -> void:
	var w: float = float(opts.get("width", 13.0))
	var d: float = float(opts.get("depth", 9.5))
	var h: float = float(opts.get("height", 3.4))
	var z1: float = float(opts.get("z1", 4.5))
	var zc: float = z1 - d * 0.5
	var wall: StandardMaterial3D = CineFX._mat(Color("#3A3F46"), 0.85)
	CineFX._box(root, "Floor", Vector3(w, 0.02, d), Vector3(0.0, 0.01, zc), CineFX._mat(Color("#5A6068"), 0.6))
	CineFX._box(root, "BackWall", Vector3(w, h, 0.15), Vector3(0.0, h * 0.5, z1 - d - 0.075), wall)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(root, "SideWall", Vector3(0.15, h, d), Vector3(sx * (w * 0.5 + 0.075), h * 0.5, zc), wall)
		CineFX._box(root, "Tray", Vector3(0.3, 0.08, d), Vector3(sx * w * 0.25, h - 0.3, zc), CineFX._mat(Color("#8C939C"), 0.4))
	CineFX._box(root, "Ceiling", Vector3(w + 0.3, 0.12, d), Vector3(0.0, h + 0.06, zc), CineFX._mat(Color("#2B2F35"), 0.9))
	var cold := OmniLight3D.new()
	cold.name = "ColdLight"
	cold.light_color = Color("#9FC4FF")
	cold.light_energy = 0.9
	cold.omni_range = 12.0
	cold.position = Vector3(0.0, h - 0.5, zc)
	root.add_child(cold)
	if bool(opts.get("red", true)):
		var red := OmniLight3D.new()
		red.name = "EmergencyLight"
		red.light_color = Color("#FF2A2A")
		red.light_energy = 1.4
		red.omni_range = 9.0
		red.position = Vector3(w * 0.3, h - 0.3, z1 - d + 1.0)
		root.add_child(red)
		CineFX._sphere(root, "Beacon", 0.1, red.position + Vector3(0.0, 0.15, 0.0), CineFX._glow_mat(Color("#FF2A2A"), 3.0))


## Keynote stage for ending C (set dressing): a platform 9 x 3.5 m (top 0.45 m), the big screen at its back with
## "LỌ THẦN 10.0" and a tagline, a podium, two warm spots. The audience stands on the -Z side.
static func _keynote(root: Node3D, opts: Dictionary) -> void:
	var dark: StandardMaterial3D = CineFX._mat(Color("#121318"), 0.5)
	CineFX._box(root, "Platform", Vector3(9.0, 0.45, 3.5), Vector3(0.0, 0.225, 0.0), dark)
	CineFX._box(root, "Edge", Vector3(9.02, 0.04, 0.02), Vector3(0.0, 0.44, -1.76), CineFX._glow_mat(Color("#F37021"), 2.0))
	CineFX._box(root, "Screen", Vector3(7.2, 3.4, 0.1), Vector3(0.0, 2.45, 1.7), CineFX._glow_mat(Color("#0B0F1A"), 0.6))
	for e: Array in [["Title", String(opts.get("title", "LỌ THẦN 10.0")), 260, Color("#F4F1EA"), 2.95],
			["Tagline", String(opts.get("tagline", "Thi hộ bằng AI. Gói sinh viên 0đ tháng đầu.")), 90, Color("#FFB23B"), 2.05],
			["Small", String(opts.get("small", "Điều khoản: đậu hay rớt đều không hoàn tiền.")), 46, Color("#8C93A6"), 1.45]]:
		var l := Label3D.new()
		l.name = String(e[0])
		l.text = String(e[1])
		l.font_size = int(e[2])
		l.pixel_size = 0.0035
		l.outline_size = 0
		l.modulate = e[3]
		l.position = Vector3(0.0, float(e[4]), 1.63)
		l.rotation.y = PI
		root.add_child(l)
	CineFX._box(root, "Podium", Vector3(0.6, 1.1, 0.45), Vector3(2.7, 0.45 + 0.55, -0.6), CineFX._mat(Color("#2B2F36"), 0.5))
	for sx: float in [-3.0, 3.0]:
		var sp := OmniLight3D.new()
		sp.name = "Spot"
		sp.light_color = Color("#FFE2B0")
		sp.light_energy = 1.8
		sp.omni_range = 7.0
		sp.position = Vector3(sx, 3.8, -2.5)
		root.add_child(sp)


static func _desk(root: Node3D) -> void:
	var top: StandardMaterial3D = CineFX._mat(Color("#4A3B30"), 0.6)
	CineFX._box(root, "Top", Vector3(1.5, 0.04, 0.75), Vector3(0.0, 0.73, 0.0), top)
	for sx: float in [-0.7, 0.7]:
		CineFX._box(root, "Leg", Vector3(0.05, 0.71, 0.7), Vector3(sx, 0.355, 0.0), CineFX._mat(Color("#2B2B2E"), 0.4))
