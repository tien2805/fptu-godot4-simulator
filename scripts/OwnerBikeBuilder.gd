# File: res://scripts/OwnerBikeBuilder.gd
# The owner's own bike for PlayerBike (spec owner-bike OB-D1): a silver and black underbone (xe số) built in code from
# the owner's front three-quarter photo (kept outside the repo). Handlebar cowl with a two-tier clear headlight, black top
# visor and clear side signals; leg shield with silver sides and a black centre V holding two small red position lamps
# around a plain dark disc; silver front fender, chrome fork, front disc (left side, as in the photo) and caliper; 5-spoke
# silver alloys with narrow tyres; silver flanks with a black stripe, black frame and underbody, dark grey engine, chrome
# pegs; a long black seat; a long black muffler on the right, tilted up at the end; a red tail light, a fake plate
# (PLATE_TEXT) and the blue / red strobe bar under the tail (OB-D5). No brand text or logo anywhere.
#
# build(root, front, rear, bar) fills the PlayerBike pivots (VisualPivot, FrontWheel, RearWheel, HandlebarPivot) so the
# wheels spin and the handlebar steers as before. The pivots' own transforms stay untouched; each wheel is a node "Wheel"
# whose basis cancels the pivot's 90 degree roll (tyre axis = the bike's X axis, rotate_x spins it), tyre torus first.
# The light materials are created per build (never the shared PropBuilder.lens cache, which traffic uses) and tagged
# "vice_done" so ViceStyle never restyles them. Returns:
#   {"headlamp_mat", "tail_mat", "pos_lamp_mat", "strobe_red_mat", "strobe_blue_mat": StandardMaterial3D,
#    "headlamp_pos": Vector3 (bar space, the lens centre), "strobe_pos": Vector3 (root space, under the tail),
#    "plate": Label3D, "parts": Dictionary name -> Node3D}
class_name OwnerBikeBuilder
extends RefCounted

const PLATE_TEXT: String = "FPTU 28.05"
const SILVER: Color = Color("#C3C8CE")
const SILVER_WHITE: Color = Color("#DCDFE3")
const GLOSS_BLACK: Color = Color("#121417")
const ENGINE_GREY: Color = Color("#3B3E43")
const WHEEL_R: float = 0.3
const TYRE_TUBE: float = 0.034
## Named parts every build has (tests).
const PART_NAMES: Array[String] = ["Cowl", "HeadlampUpper", "HeadlampLower", "Visor", "SignalL", "SignalR", "GripL",
	"GripR", "LegShieldV", "LegShieldL", "LegShieldR", "PositionLampL", "PositionLampR", "EmblemDisc", "FrontFender",
	"ForkL", "ForkR", "FrontDisc", "Caliper", "FlankL", "FlankR", "StripeL", "StripeR", "Frame", "Engine", "PegL", "PegR",
	"Seat", "Muffler", "TailLight", "Plate", "StrobeBar", "StrobeRed", "StrobeBlue"]


static func build(root: Node3D, front: Node3D, rear: Node3D, bar: Node3D) -> Dictionary:
	var parts: Dictionary = {}
	var mats: Dictionary = _light_materials()
	var silver: Material = PropBuilder.paint(SILVER)
	var silver_w: Material = PropBuilder.paint(SILVER_WHITE)
	var black: Material = PropBuilder.paint(GLOSS_BLACK)
	var plastic: Material = PropBuilder.black_plastic()
	var chr: Material = PropBuilder.chrome()
	var engine: Material = CharacterBuilder._mat("owner_engine", ENGINE_GREY, 0.45, 0.65)
	var clear: Material = CharacterBuilder._mat("owner_clear_lens", Color(0.9, 0.92, 0.95, 0.72), 0.06, 0.15)
	# --- wheels (5-spoke alloys, narrow tyres); front disc on the left (-X) as in the photo, rear sprocket on the left
	_wheel(front, front.basis.inverse(), true, parts)
	_wheel(rear, rear.basis.inverse(), false, parts)
	_build_front(root, silver, black, plastic, chr, mats, parts)
	_build_body(root, silver, black, plastic, chr, engine, parts)
	_build_rear(root, black, plastic, chr, mats, parts)
	_build_cowl(bar, silver_w, plastic, chr, clear, mats, parts)
	return {"headlamp_mat": mats["headlamp"], "tail_mat": mats["tail"], "pos_lamp_mat": mats["pos"],
		"strobe_red_mat": mats["strobe_red"], "strobe_blue_mat": mats["strobe_blue"],
		"headlamp_pos": Vector3(0.0, 0.0, -0.2), "strobe_pos": Vector3(0.0, 0.66, 0.93),
		"plate": parts.get("Plate"), "parts": parts}


## One emissive material per light, unique to this bike (energy changed at run time).
static func _light_materials() -> Dictionary:
	return {
		"headlamp": _lamp(Color(0.95, 0.96, 1.0), Color("#FFF5DC"), 2.6),
		"tail": _lamp(Color("#B71C1C"), Color("#FF2A1F"), 1.4),
		"pos": _lamp(Color("#C62828"), Color("#FF3B30"), 1.2),
		"strobe_red": _lamp(Color("#4A0D0D"), Color("#FF1E1E"), 0.0),
		"strobe_blue": _lamp(Color("#0D1A4A"), Color("#2F62FF"), 0.0),
	}


static func _lamp(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 0.12
	m.metallic = 0.1
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = energy
	m.set_meta("vice_done", true)
	return m


static func _named(n: Node3D, name: String, parts: Dictionary) -> Node3D:
	n.name = name
	parts[name] = n
	return n


# ---------------------------------------------------------------------------
# WHEELS
# ---------------------------------------------------------------------------
static func _wheel(pivot: Node3D, basis: Basis, is_front: bool, parts: Dictionary) -> void:
	var w := Node3D.new()
	w.name = "Wheel"
	w.basis = basis
	pivot.add_child(w)
	var rim_mat: Material = CharacterBuilder._mat("owner_rim", Color("#CDD2D8"), 0.25, 0.85)
	var r_in: float = WHEEL_R - TYRE_TUBE * 2.0
	# tyre first (test_wheel_spin reads the first TorusMesh), then the rim lip, hub, 5 split spokes
	CharacterBuilder._torus(w, Vector3.ZERO, r_in, WHEEL_R, PropBuilder.rubber(), Vector3(0.0, 0.0, PI * 0.5))
	CharacterBuilder._torus(w, Vector3.ZERO, r_in - 0.022, r_in + 0.004, rim_mat, Vector3(0.0, 0.0, PI * 0.5))
	CharacterBuilder._cyl(w, Vector3.ZERO, 0.045, 0.045, 0.1, rim_mat, Vector3(0.0, 0.0, PI * 0.5))
	var sl: float = r_in - 0.05
	for i: int in range(5):
		var a: float = float(i) * TAU / 5.0
		for s: float in [-1.0, 1.0]:
			var a2: float = a + s * 0.09
			var spoke: MeshInstance3D = CharacterBuilder._box(w, Vector3(0.0, cos(a2) * (0.04 + sl * 0.5), sin(a2) * (0.04 + sl * 0.5)), Vector3(0.022, sl, 0.016), rim_mat)
			spoke.rotation.x = a2
	if is_front:
		# disc on the left side + its dark carrier
		var disc: MeshInstance3D = CharacterBuilder._cyl(w, Vector3(-0.052, 0.0, 0.0), 0.13, 0.13, 0.005, PropBuilder.steel(), Vector3(0.0, 0.0, PI * 0.5))
		_named(disc, "FrontDisc", parts)
		CharacterBuilder._cyl(w, Vector3(-0.05, 0.0, 0.0), 0.07, 0.07, 0.008, PropBuilder.black_plastic(), Vector3(0.0, 0.0, PI * 0.5))
	else:
		# drum hub + sprocket on the left (chain side)
		CharacterBuilder._cyl(w, Vector3(0.03, 0.0, 0.0), 0.09, 0.09, 0.05, CharacterBuilder._mat("owner_drum", Color("#8C9198"), 0.4, 0.7), Vector3(0.0, 0.0, PI * 0.5))
		CharacterBuilder._cyl(w, Vector3(-0.055, 0.0, 0.0), 0.1, 0.1, 0.006, PropBuilder.steel(), Vector3(0.0, 0.0, PI * 0.5))


# ---------------------------------------------------------------------------
# FRONT END: fork, fender, caliper, leg shield (silver sides, black centre V, red position lamps, plain disc)
# ---------------------------------------------------------------------------
static func _build_front(root: Node3D, silver: Material, black: Material, plastic: Material, chr: Material, mats: Dictionary, parts: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		var fork: MeshInstance3D = PropBuilder._tube(root, Vector3(sx * 0.078, 0.5, -0.597), Vector3(sx * 0.07, 0.92, -0.5), 0.017, chr)
		_named(fork, "ForkL" if sx < 0.0 else "ForkR", parts)
		PropBuilder._tube(root, Vector3(sx * 0.08, 0.3, -0.62), Vector3(sx * 0.078, 0.54, -0.588), 0.026, silver)
	# caliper behind the disc, on the left fork leg
	_named(CharacterBuilder._box(root, Vector3(-0.1, 0.42, -0.54), Vector3(0.035, 0.09, 0.06), plastic, Vector3(-0.5, 0.0, 0.0)), "Caliper", parts)
	# silver front fender hugging the tyre, with a short pointed beak at the front
	var fender := Node3D.new()
	root.add_child(fender)
	_named(fender, "FrontFender", parts)
	for a_deg: float in [-42.0, -20.0, 0.0, 20.0, 38.0]:
		var a: float = deg_to_rad(a_deg)
		var seg: MeshInstance3D = CharacterBuilder._box(fender, Vector3(0.0, 0.32 + cos(a) * 0.34, -0.62 - sin(a) * 0.34), Vector3(0.15, 0.018, 0.13), silver)
		seg.rotation.x = -a
	CharacterBuilder._box(fender, Vector3(0.0, 0.52, -0.9), Vector3(0.11, 0.016, 0.09), silver, Vector3(-1.05, 0.0, 0.0))
	for sx2: float in [-1.0, 1.0]:
		CharacterBuilder._box(fender, Vector3(sx2 * 0.075, 0.6, -0.66), Vector3(0.012, 0.08, 0.26), silver, Vector3(0.25, 0.0, 0.0))
	# leg shield: black centre V (two leaning halves meeting at the bottom), silver side panels wrapping back
	var v := Node3D.new()
	v.position = Vector3(0.0, 0.76, -0.385)
	v.rotation.x = 0.2
	root.add_child(v)
	_named(v, "LegShieldV", parts)
	for sx3: float in [-1.0, 1.0]:
		CharacterBuilder._box(v, Vector3(sx3 * 0.045, 0.0, 0.0), Vector3(0.095, 0.44, 0.03), black, Vector3(0.0, 0.0, sx3 * -0.2))
	CharacterBuilder._box(v, Vector3(0.0, 0.17, 0.0), Vector3(0.2, 0.1, 0.03), black)
	for sx4: float in [-1.0, 1.0]:
		var side: MeshInstance3D = CharacterBuilder._box(root, Vector3(sx4 * 0.15, 0.73, -0.37), Vector3(0.15, 0.46, 0.03), silver, Vector3(0.2, sx4 * -0.55, 0.0))
		_named(side, "LegShieldL" if sx4 < 0.0 else "LegShieldR", parts)
		# the sharp lower wing sweeping back toward the frame
		CharacterBuilder._box(root, Vector3(sx4 * 0.19, 0.5, -0.3), Vector3(0.03, 0.2, 0.22), silver, Vector3(0.35, 0.0, 0.0))
		var lamp: MeshInstance3D = CharacterBuilder._box(root, Vector3(sx4 * 0.06, 0.885, -0.387), Vector3(0.04, 0.026, 0.02), mats["pos"], Vector3(0.2, 0.0, 0.0))
		_named(lamp, "PositionLampL" if sx4 < 0.0 else "PositionLampR", parts)
	# plain dark disc where the emblem was (no logo)
	var disc: MeshInstance3D = CharacterBuilder._cyl(root, Vector3(0.0, 0.875, -0.39), 0.032, 0.032, 0.012, PropBuilder.steel(), Vector3(PI * 0.5 + 0.2, 0.0, 0.0))
	_named(disc, "EmblemDisc", parts)
	CharacterBuilder._cyl(root, Vector3(0.0, 0.875, -0.395), 0.024, 0.024, 0.008, plastic, Vector3(PI * 0.5 + 0.2, 0.0, 0.0))
	# steering head cover between the shield and the cowl
	CharacterBuilder._box(root, Vector3(0.0, 0.93, -0.44), Vector3(0.16, 0.08, 0.1), black)


# ---------------------------------------------------------------------------
# BODY: frame, engine, pegs, silver flanks with a black stripe, black underbody, seat, muffler
# ---------------------------------------------------------------------------
static func _build_body(root: Node3D, silver: Material, black: Material, plastic: Material, chr: Material, engine: Material, parts: Dictionary) -> void:
	# underbone spine: steering head down to the engine, then up under the seat
	var frame: MeshInstance3D = PropBuilder._tube(root, Vector3(0.0, 0.86, -0.42), Vector3(0.0, 0.44, -0.14), 0.045, plastic)
	_named(frame, "Frame", parts)
	PropBuilder._tube(root, Vector3(0.0, 0.44, -0.14), Vector3(0.0, 0.62, 0.2), 0.04, plastic)
	# lower front covers (silver, the black stripe runs along them), under the leg shield
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.11, 0.5, -0.2), Vector3(0.03, 0.2, 0.3), silver, Vector3(-0.35, 0.0, 0.0))
	# engine: forward-leaning cylinder, crankcase, round side covers
	var eng := Node3D.new()
	root.add_child(eng)
	_named(eng, "Engine", parts)
	CharacterBuilder._cyl(eng, Vector3(0.0, 0.34, -0.2), 0.07, 0.075, 0.2, engine, Vector3(PI * 0.5 + 0.25, 0.0, 0.0))
	for i: int in range(4):
		CharacterBuilder._box(eng, Vector3(0.0, 0.36 - float(i) * 0.012, -0.24 + float(i) * 0.04), Vector3(0.17, 0.16, 0.01), engine, Vector3(0.25, 0.0, 0.0))
	CharacterBuilder._box(eng, Vector3(0.0, 0.3, 0.02), Vector3(0.22, 0.2, 0.28), engine)
	CharacterBuilder._cyl(eng, Vector3(0.12, 0.3, 0.0), 0.1, 0.1, 0.03, CharacterBuilder._mat("owner_case", Color("#9AA0A7"), 0.35, 0.75), Vector3(0.0, 0.0, PI * 0.5))
	CharacterBuilder._cyl(eng, Vector3(-0.12, 0.31, 0.04), 0.09, 0.09, 0.03, engine, Vector3(0.0, 0.0, PI * 0.5))
	# foot pegs (rider + passenger), gear lever, side stand
	for sx2: float in [-1.0, 1.0]:
		var peg: MeshInstance3D = CharacterBuilder._cyl(root, Vector3(sx2 * 0.2, 0.27, 0.06), 0.014, 0.014, 0.12, chr, Vector3(0.0, 0.0, PI * 0.5))
		_named(peg, "PegL" if sx2 < 0.0 else "PegR", parts)
		CharacterBuilder._cyl(root, Vector3(sx2 * 0.2, 0.27, 0.06), 0.02, 0.02, 0.07, PropBuilder.rubber(), Vector3(0.0, 0.0, PI * 0.5))
		CharacterBuilder._cyl(root, Vector3(sx2 * 0.17, 0.5, 0.3), 0.012, 0.012, 0.09, chr, Vector3(0.0, 0.0, PI * 0.5))   # passenger, above the muffler
	PropBuilder._tube(root, Vector3(-0.16, 0.29, -0.02), Vector3(-0.17, 0.3, -0.16), 0.008, chr)
	PropBuilder._tube(root, Vector3(-0.12, 0.26, 0.1), Vector3(-0.22, 0.03, 0.06), 0.012, chr)
	# silver flanks under the seat, rising to the tail, with a black stripe; black underbody below
	for sx3: float in [-1.0, 1.0]:
		var flank: MeshInstance3D = CharacterBuilder._box(root, Vector3(sx3 * 0.125, 0.67, 0.33), Vector3(0.03, 0.2, 0.62), silver, Vector3(-0.12, 0.0, 0.0))
		_named(flank, "FlankL" if sx3 < 0.0 else "FlankR", parts)
		var stripe: MeshInstance3D = CharacterBuilder._box(root, Vector3(sx3 * 0.142, 0.69, 0.33), Vector3(0.008, 0.032, 0.6), black, Vector3(-0.12, 0.0, 0.0))
		_named(stripe, "StripeL" if sx3 < 0.0 else "StripeR", parts)
		# the stripe carries on along the lower front cover
		CharacterBuilder._box(root, Vector3(sx3 * 0.127, 0.52, -0.2), Vector3(0.008, 0.026, 0.3), black, Vector3(-0.35, 0.0, 0.0))
	CharacterBuilder._box(root, Vector3(0.0, 0.67, 0.33), Vector3(0.22, 0.18, 0.6), silver, Vector3(-0.12, 0.0, 0.0))
	CharacterBuilder._box(root, Vector3(0.0, 0.53, 0.36), Vector3(0.2, 0.08, 0.5), plastic, Vector3(-0.12, 0.0, 0.0))
	CharacterBuilder._box(root, Vector3(0.0, 0.78, 0.74), Vector3(0.17, 0.11, 0.26), silver, Vector3(-0.22, 0.0, 0.0))
	# long black seat (capsule along Z, flattened), no text
	CharacterBuilder._box(root, Vector3(0.0, 0.81, 0.3), Vector3(0.23, 0.07, 0.76), plastic, Vector3(-0.06, 0.0, 0.0))
	var seat: MeshInstance3D = CharacterBuilder._capsule(root, Vector3(0.0, 0.875, 0.3), 0.13, 0.8, PropBuilder.leather(), Vector3(PI * 0.5 - 0.06, 0.0, 0.0), Vector3(1.0, 1.0, 0.42))
	_named(seat, "Seat", parts)
	# exhaust on the right: chrome header from under the cylinder, black pipe, long black muffler tilted up at the end
	PropBuilder._tube(root, Vector3(0.04, 0.24, -0.26), Vector3(0.12, 0.18, -0.08), 0.02, chr)
	PropBuilder._tube(root, Vector3(0.12, 0.18, -0.08), Vector3(0.19, 0.24, 0.13), 0.022, black)   # under the right peg
	PropBuilder._tube(root, Vector3(0.19, 0.24, 0.13), Vector3(0.2, 0.34, 0.15), 0.022, black)
	var tilt: float = 0.17
	var muffler: MeshInstance3D = CharacterBuilder._cyl(root, Vector3(0.2, 0.4, 0.46), 0.056, 0.05, 0.66, black, Vector3(PI * 0.5 - tilt, 0.0, 0.0), Vector3(1.0, 1.0, 0.82))
	_named(muffler, "Muffler", parts)
	var tip: Vector3 = Vector3(0.2, 0.4, 0.46) + Vector3(0.0, sin(tilt), cos(tilt)) * 0.33
	CharacterBuilder._torus(root, tip, 0.03, 0.05, chr, Vector3(PI * 0.5 - tilt, 0.0, 0.0))
	CharacterBuilder._cyl(root, tip, 0.03, 0.03, 0.02, plastic, Vector3(PI * 0.5 - tilt, 0.0, 0.0))
	CharacterBuilder._box(root, Vector3(0.16, 0.37, 0.4), Vector3(0.04, 0.03, 0.05), chr)


# ---------------------------------------------------------------------------
# REAR: swingarm, shocks, chain guard, fender, tail light, fake plate, strobe bar
# ---------------------------------------------------------------------------
static func _build_rear(root: Node3D, black: Material, plastic: Material, chr: Material, mats: Dictionary, parts: Dictionary) -> void:
	for sx: float in [-1.0, 1.0]:
		PropBuilder._tube(root, Vector3(sx * 0.1, 0.33, 0.12), Vector3(sx * 0.085, 0.32, 0.62), 0.022, plastic)
		PropBuilder._tube(root, Vector3(sx * 0.11, 0.35, 0.56), Vector3(sx * 0.11, 0.7, 0.46), 0.011, chr)
		PropBuilder._tube(root, Vector3(sx * 0.11, 0.42, 0.54), Vector3(sx * 0.11, 0.62, 0.48), 0.026, plastic)
	CharacterBuilder._box(root, Vector3(-0.11, 0.36, 0.38), Vector3(0.025, 0.07, 0.44), plastic)
	for a_deg: float in [12.0, 34.0, 56.0]:
		var a: float = deg_to_rad(a_deg)
		var seg: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.0, 0.32 + cos(a) * 0.35, 0.62 + sin(a) * 0.35), Vector3(0.14, 0.016, 0.14), black)
		seg.rotation.x = a
	var tail: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.0, 0.79, 0.875), Vector3(0.15, 0.055, 0.04), mats["tail"], Vector3(-0.3, 0.0, 0.0))
	_named(tail, "TailLight", parts)
	var clear_amber: Material = CharacterBuilder._mat("owner_rear_signal", Color(0.95, 0.75, 0.35, 0.8), 0.1, 0.1)
	for sx2: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx2 * 0.13, 0.73, 0.86), Vector3(0.04, 0.03, 0.05), clear_amber)
	# strobe bar under the tail: red strip left (-X), blue strip right (+X)
	var bar := CharacterBuilder._box(root, Vector3(0.0, 0.69, 0.9), Vector3(0.24, 0.032, 0.03), plastic)
	_named(bar, "StrobeBar", parts)
	_named(CharacterBuilder._box(root, Vector3(-0.058, 0.69, 0.917), Vector3(0.1, 0.02, 0.006), mats["strobe_red"]), "StrobeRed", parts)
	_named(CharacterBuilder._box(root, Vector3(0.058, 0.69, 0.917), Vector3(0.1, 0.02, 0.006), mats["strobe_blue"]), "StrobeBlue", parts)
	# fake plate on the rear hugger (two lines like a Vietnamese bike plate), facing backward (+Z)
	var holder: MeshInstance3D = CharacterBuilder._box(root, Vector3(0.0, 0.56, 0.93), Vector3(0.2, 0.15, 0.01), plastic, Vector3(0.18, 0.0, 0.0))
	CharacterBuilder._box(root, Vector3(0.0, 0.56, 0.936), Vector3(0.19, 0.14, 0.004), CharacterBuilder._mat("owner_plate", Color("#F4F4F0"), 0.5), Vector3(0.18, 0.0, 0.0))
	var plate := Label3D.new()
	plate.text = PLATE_TEXT.replace(" ", "\n")
	plate.font_size = 40
	plate.pixel_size = 0.0011
	plate.outline_size = 0
	plate.modulate = Color("#15171A")
	plate.double_sided = false
	plate.shaded = true
	plate.position = Vector3(0.0, 0.56, 0.94)
	plate.rotation = holder.rotation
	plate.set_meta("plate_text", PLATE_TEXT)
	root.add_child(plate)
	_named(plate, "Plate", parts)


# ---------------------------------------------------------------------------
# HANDLEBAR COWL (on the steering pivot): silver-white wedge, two-tier clear headlight, black visor, clear signals, grips
# ---------------------------------------------------------------------------
static func _build_cowl(bar: Node3D, silver_w: Material, plastic: Material, chr: Material, clear: Material, mats: Dictionary, parts: Dictionary) -> void:
	var cowl := Node3D.new()
	bar.add_child(cowl)
	_named(cowl, "Cowl", parts)
	# wedge body: centre block plus two angled cheeks meeting in a point at the front
	CharacterBuilder._box(cowl, Vector3(0.0, 0.0, -0.02), Vector3(0.36, 0.13, 0.17), silver_w)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(cowl, Vector3(sx * 0.11, 0.0, -0.1), Vector3(0.2, 0.13, 0.05), silver_w, Vector3(0.0, sx * -0.42, 0.0))
		CharacterBuilder._box(cowl, Vector3(sx * 0.17, -0.055, -0.04), Vector3(0.1, 0.04, 0.14), silver_w, Vector3(0.0, 0.0, sx * 0.35))
	CharacterBuilder._box(cowl, Vector3(0.0, 0.06, -0.05), Vector3(0.3, 0.03, 0.18), silver_w, Vector3(-0.12, 0.0, 0.0))
	CharacterBuilder._box(cowl, Vector3(0.0, -0.01, 0.08), Vector3(0.28, 0.11, 0.08), plastic)
	# two-tier multi-reflector headlight: chrome reflectors behind clear lenses that always glow
	CharacterBuilder._box(cowl, Vector3(0.0, 0.0, -0.17), Vector3(0.22, 0.12, 0.03), chr)
	var hi: MeshInstance3D = CharacterBuilder._box(cowl, Vector3(0.0, 0.025, -0.19), Vector3(0.2, 0.05, 0.016), mats["headlamp"], Vector3(0.25, 0.0, 0.0))
	_named(hi, "HeadlampUpper", parts)
	var lo: MeshInstance3D = CharacterBuilder._box(cowl, Vector3(0.0, -0.035, -0.185), Vector3(0.13, 0.045, 0.016), mats["headlamp"], Vector3(0.1, 0.0, 0.0))
	_named(lo, "HeadlampLower", parts)
	# black top visor sloping down to the front
	var visor: MeshInstance3D = CharacterBuilder._box(cowl, Vector3(0.0, 0.075, -0.15), Vector3(0.26, 0.014, 0.11), plastic, Vector3(-0.3, 0.0, 0.0))
	_named(visor, "Visor", parts)
	# speedo behind the visor
	CharacterBuilder._box(cowl, Vector3(0.0, 0.085, 0.02), Vector3(0.16, 0.03, 0.09), plastic, Vector3(0.35, 0.0, 0.0))
	CharacterBuilder._box(cowl, Vector3(0.0, 0.1, 0.02), Vector3(0.12, 0.004, 0.06), CharacterBuilder._mat("owner_dial", Color("#2C3640"), 0.2, 0.0, 0.4), Vector3(0.35, 0.0, 0.0))
	for sx2: float in [-1.0, 1.0]:
		# clear turn signals at the cowl sides
		var sig: MeshInstance3D = CharacterBuilder._box(cowl, Vector3(sx2 * 0.2, 0.0, -0.08), Vector3(0.05, 0.045, 0.07), clear, Vector3(0.0, sx2 * -0.6, 0.0))
		_named(sig, "SignalL" if sx2 < 0.0 else "SignalR", parts)
		# bar ends out of the cowl, black grips, chrome levers (no mirrors, as in the photo)
		CharacterBuilder._cyl(bar, Vector3(sx2 * 0.24, 0.03, 0.04), 0.012, 0.012, 0.1, plastic, Vector3(0.0, 0.0, PI * 0.5))
		var grip: MeshInstance3D = CharacterBuilder._cyl(bar, Vector3(sx2 * 0.33, 0.03, 0.04), 0.022, 0.022, 0.12, PropBuilder.rubber(), Vector3(0.0, 0.0, PI * 0.5))
		_named(grip, "GripL" if sx2 < 0.0 else "GripR", parts)
		CharacterBuilder._cyl(bar, Vector3(sx2 * 0.395, 0.03, 0.04), 0.017, 0.017, 0.02, chr, Vector3(0.0, 0.0, PI * 0.5))
		var lever: MeshInstance3D = CharacterBuilder._box(bar, Vector3(sx2 * 0.32, 0.035, -0.02), Vector3(0.12, 0.01, 0.012), chr)
		lever.rotation.y = sx2 * 0.22
		CharacterBuilder._box(bar, Vector3(sx2 * 0.235, 0.04, 0.03), Vector3(0.04, 0.04, 0.04), plastic)
