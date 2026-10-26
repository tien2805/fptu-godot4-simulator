# File: res://scripts/combat/swords/KatanaProp.gd
# Za Mẫn's "katana bought online" (spec C-D3), code-built: a wrapped grip, a guard and a blade of SEGMENTS chained pivots
# (origin at the grip, blade along -Z; SwordProps.attach_to_hand puts it in the hand). It visibly bends with the boss's
# damage: set_stage(0..3) eases the whole blade to SwordData.BEND_RAD[stage] (spread over the segments: a droop toward the
# edge plus a little sideways twist), every hit adds a decaying wobble, and snap() at 0 HP breaks off the outer half,
# which tumbles to the floor (top_level piece, freed with the katana). The glint (a small 3-axis star, white = blockable,
# red = unblockable) pops on the blade for the boss's 0.5 s tells. Per frame: nothing while still (no wobble, glint or
# falling piece).
class_name KatanaProp
extends Node3D

const SEGMENTS: int = 6
const SEG_LEN: float = 0.12
const BASE_CURVE: float = 0.02           # rad per segment: the katana's natural curve
const SIDE_K: float = 0.35               # sideways share of the bend
const EASE: float = 3.0                  # bend change per second toward the stage target
const WOBBLE_HZ: float = 4.5
const WOBBLE_DECAY: float = 4.0
const BREAK_AT: int = 3                  # segments BREAK_AT.. fly off
const GRAVITY: float = 9.8

var segs: Array[Node3D] = []
var stage: int = 0
var target_bend: float = 0.0
var bend: float = 0.0
var wobble_amp: float = 0.0
var wobble_t: float = 0.0
var glint: Node3D
var glint_on: bool = false
var glint_red: bool = false
var glint_t: float = 0.0
var broken: bool = false
var piece: Node3D = null
var piece_v: Vector3 = Vector3.ZERO
var piece_spin: Vector3 = Vector3.ZERO
var piece_floor: float = 0.0
var piece_resting: bool = false
static var _glint_mats: Array[StandardMaterial3D] = []


static func create() -> KatanaProp:
	var k := KatanaProp.new()
	k.name = "Katana"
	k._build()
	return k


func _build() -> void:
	var wrap: Material = SwordProps.mat(Color("#1C1C22"), 0.0, 0.9)
	var gold: Material = SwordProps.mat(Color("#B89A3E"), 0.7, 0.35)
	var steel: Material = SwordProps.mat(Color("#D8DDE3"), 0.85, 0.22)
	SwordProps.box(self, Vector3(0.034, 0.03, 0.25), Vector3(0.0, 0.0, 0.06), wrap)          # tsuka
	SwordProps.box(self, Vector3(0.04, 0.036, 0.02), Vector3(0.0, 0.0, 0.19), gold)          # pommel cap
	var guard := SwordProps.rod(self, 0.048, 0.012, Vector3(0.0, 0.0, -0.075), SwordProps.mat(Color("#3A3324"), 0.6, 0.4))
	guard.name = "Guard"
	SwordProps.box(self, Vector3(0.016, 0.036, 0.02), Vector3(0.0, 0.0, -0.09), gold)        # habaki
	var parent: Node3D = self
	var z0: float = -0.1
	for i: int in SEGMENTS:
		var p := Node3D.new()
		p.name = "Seg%d" % i
		p.position = Vector3(0.0, 0.0, z0)
		parent.add_child(p)
		var w: float = lerpf(0.032, 0.022, float(i) / float(SEGMENTS - 1))
		var mi := SwordProps.box(p, Vector3(0.007, w, SEG_LEN + 0.004), Vector3(0.0, 0.0, -SEG_LEN * 0.5), steel)
		mi.name = "Blade"
		segs.append(p)
		parent = p
		z0 = -SEG_LEN
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0.0, 0.0, -SEG_LEN)
	parent.add_child(tip)
	glint = _build_glint()
	glint.position = Vector3(0.0, 0.0, -SEG_LEN * 0.5)
	segs[3].add_child(glint)
	_apply()


static func _glint_mat(red: bool) -> StandardMaterial3D:
	if _glint_mats.is_empty():
		for col: Color in [Color(0.85, 0.95, 1.0), Color(1.0, 0.18, 0.12)]:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(col, 0.95)
			m.no_depth_test = true                # a tell must read even through the boss's own arm
			m.set_meta("vice_done", true)
			_glint_mats.append(m)
	return _glint_mats[1 if red else 0]


func _build_glint() -> Node3D:
	var g := Node3D.new()
	g.name = "Glint"
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 8
	sm.rings = 4
	core.mesh = sm
	core.name = "Core"
	g.add_child(core)
	for ax: Vector3 in [Vector3(0.34, 0.012, 0.012), Vector3(0.012, 0.34, 0.012), Vector3(0.012, 0.012, 0.34)]:
		var ray := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = ax
		ray.mesh = bm
		ray.name = "Ray"
		g.add_child(ray)
	for c: Node in g.get_children():
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visible = false
	return g


## Bend stage 0..3 (SwordData.BEND_RAD). Returns true when the stage went up (a "boing" wobble starts).
func set_stage(s: int) -> bool:
	s = clampi(s, 0, SwordData.BEND_RAD.size() - 1)
	var up: bool = s > stage
	stage = s
	target_bend = SwordData.BEND_RAD[s]
	if up:
		wobble(0.45)
	set_process(true)
	return up


## A decaying wobble of `amp` rad (each hit on the boss).
func wobble(amp: float) -> void:
	wobble_amp = maxf(wobble_amp * exp(-WOBBLE_DECAY * wobble_t), 0.0) + amp
	wobble_t = 0.0
	set_process(true)


## The glint star on (white, or red for an unblockable move) or off.
func set_glint(on: bool, red: bool = false) -> void:
	glint_on = on
	glint_red = red
	glint_t = 0.0
	glint.visible = on and not broken
	if on:
		var m: StandardMaterial3D = _glint_mat(red)
		for c: Node in glint.get_children():
			(c as MeshInstance3D).material_override = m
		glint.scale = Vector3.ONE * 0.01
		set_process(true)


## 0 HP: the outer half breaks off and tumbles down to floor_y (world height of the floor).
func snap(floor_y: float, away: Vector3 = Vector3.ZERO) -> void:
	if broken:
		return
	broken = true
	set_glint(false)
	piece = segs[BREAK_AT]
	piece.top_level = true                   # keeps its world transform, then flies on its own
	piece.name = "BrokenTip"
	piece_floor = floor_y
	piece_v = Vector3(away.x * 1.4, 2.6, away.z * 1.4) + Vector3(0.6, 0.0, -0.4)
	piece_spin = Vector3(9.0, 4.0, 2.0)
	piece_resting = false
	set_process(true)


## The angle (rad) between the blade's base direction and its tip direction (0 = straight; tests).
func tip_deviation() -> float:
	var a: Vector3 = -segs[0].global_basis.z.normalized()
	var last: Node3D = segs[SEGMENTS - 1] if not broken else segs[BREAK_AT - 1]
	var b: Vector3 = -last.global_basis.z.normalized()
	return acos(clampf(a.dot(b), -1.0, 1.0))


func _process(delta: float) -> void:
	var busy: bool = false
	if not is_equal_approx(bend, target_bend) or wobble_amp > 0.002:
		bend = move_toward(bend, target_bend, EASE * delta)
		wobble_t += delta
		if wobble_amp * exp(-WOBBLE_DECAY * wobble_t) < 0.002:
			wobble_amp = 0.0
		_apply()
		busy = true
	if glint_on:
		glint_t += delta
		var pop: float = 1.35 * smoothstep(0.0, 0.06, glint_t) - 0.35 * smoothstep(0.06, 0.16, glint_t)
		glint.scale = Vector3.ONE * maxf(0.01, pop * (1.0 + 0.12 * sin(glint_t * 60.0)))
		busy = true
	if piece != null and not piece_resting and is_instance_valid(piece):
		piece_v.y -= GRAVITY * delta
		piece.global_position += piece_v * delta
		piece.rotation += piece_spin * delta
		if piece.global_position.y <= piece_floor + 0.03 and piece_v.y < 0.0:
			piece.global_position.y = piece_floor + 0.03
			piece.rotation = Vector3(PI * 0.5, piece.rotation.y, 0.0)   # flat on the floor
			piece_resting = true
		busy = true
	if not busy:
		set_process(false)


func _apply() -> void:
	var w: float = 0.0
	if wobble_amp > 0.0:
		w = wobble_amp * exp(-WOBBLE_DECAY * wobble_t) * sin(TAU * WOBBLE_HZ * wobble_t)
	var per: float = (bend + w) / float(SEGMENTS)
	for i: int in segs.size():
		if broken and i >= BREAK_AT:
			break
		segs[i].rotation = Vector3(BASE_CURVE - per, per * SIDE_K, 0.0)
