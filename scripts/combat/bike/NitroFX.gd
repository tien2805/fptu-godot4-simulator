# File: res://scripts/combat/bike/NitroFX.gd
# The blue nitro flame of a bike exhaust (spec D2X-8), code-built: an outer blue emissive cone, a white-hot inner core, a
# CPUParticles3D stream of blue sparks and a short blue OmniLight flash on ignition. The node sits at the muffler tip with
# its -Z axis pointing out of the pipe (build() orients it). set_on() starts / stops it; tick() flickers the cones and
# fades the flash (call it every frame while it runs; it returns at once while off).
# whoosh_stream(): the ignition whoosh, a synthesized SFX (rising filtered hiss + a low thump; not music), built once
# and cached (about 9k samples). Used by PlayerBike and DriftRival.
class_name NitroFX
extends Node3D

const BLUE := Color(0.25, 0.55, 1.0)
const CORE := Color(0.85, 0.95, 1.0)
const FLAME_LEN: float = 0.75
const FLASH_ENERGY: float = 6.0
const FLASH_S: float = 0.35
const RUN_ENERGY: float = 1.4
const SR: int = 11025
const WHOOSH_S: float = 0.8

static var _whoosh: AudioStreamWAV = null

var on: bool = false
var flame: MeshInstance3D
var core: MeshInstance3D
var sparks: CPUParticles3D
var light: OmniLight3D
var _t: float = 0.0
var _flash: float = 0.0
var _scale: float = 1.0


## A flame at `pos` (parent space) pointing along `dir` (parent space, out of the pipe). scale 1 = a scooter muffler.
static func build(parent: Node3D, pos: Vector3, dir: Vector3, flame_scale: float = 1.0) -> NitroFX:
	var fx := NitroFX.new()
	fx.name = "NitroFX"
	fx._scale = flame_scale
	parent.add_child(fx)
	fx.position = pos
	var d: Vector3 = dir.normalized() if dir.length_squared() > 1e-6 else Vector3(0.0, 0.0, 1.0)
	var up: Vector3 = Vector3.UP if absf(d.y) < 0.95 else Vector3(1.0, 0.0, 0.0)
	fx.basis = Basis.looking_at(d, up)   # -Z out of the pipe
	fx._build()
	return fx


func _build() -> void:
	flame = _cone("Flame", 0.085 * _scale, FLAME_LEN * _scale, BLUE, 6.0, 0.55)
	core = _cone("Core", 0.04 * _scale, FLAME_LEN * 0.55 * _scale, CORE, 9.0, 0.85)
	sparks = CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.emitting = false
	sparks.amount = 24
	sparks.lifetime = 0.28
	sparks.local_coords = false
	sparks.direction = Vector3(0.0, 0.0, -1.0)
	sparks.spread = 12.0
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3.ZERO
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.1
	sparks.color = Color(0.45, 0.7, 1.0, 0.9)
	var sm := SphereMesh.new()
	sm.radius = 0.035 * _scale
	sm.height = 0.07 * _scale
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _glow(Color(0.5, 0.75, 1.0), 4.0, 0.9)
	sparks.mesh = sm
	add_child(sparks)
	light = OmniLight3D.new()
	light.name = "NitroLight"
	light.light_color = BLUE
	light.omni_range = 4.0 * _scale
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.0, -0.3 * _scale)
	add_child(light)
	_apply(false)


func _cone(nm: String, r: float, h: float, col: Color, energy: float, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0          # the tip (+Y before the turn below) points out of the pipe
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	cm.material = _glow(col, energy, alpha)
	mi.mesh = cm
	mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # +Y -> -Z
	mi.position = Vector3(0.0, 0.0, -h * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _glow(col: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.set_meta("vice_done", true)   # never restyled by ViceStyle
	return m


func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	_t = 0.0
	_flash = FLASH_S if v else 0.0
	_apply(v)


func _apply(v: bool) -> void:
	if flame:
		flame.visible = v
		core.visible = v
		sparks.emitting = v
		light.visible = v
		light.light_energy = FLASH_ENERGY if v else 0.0


## Flicker (cone length and width) and the ignition flash fading to the running glow.
func tick(delta: float) -> void:
	if not on or flame == null:
		return
	_t += delta
	var f: float = 0.85 + 0.15 * sin(_t * 61.0) + 0.08 * sin(_t * 23.0 + 1.3)
	flame.scale = Vector3(1.0 + 0.1 * sin(_t * 37.0), f, 1.0)
	core.scale = Vector3(1.0, 0.9 + 0.2 * sin(_t * 53.0 + 0.7), 1.0)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	light.light_energy = lerpf(RUN_ENERGY, FLASH_ENERGY, _flash / FLASH_S) * (0.9 + 0.1 * f)


## The ignition whoosh (synthesized SFX, cached): a hiss whose low-pass opens over 0.25 s and closes again, plus a 52 Hz
## thump in the first 0.15 s.
static func whoosh_stream() -> AudioStreamWAV:
	if _whoosh != null:
		return _whoosh
	var n: int = int(WHOOSH_S * SR)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var lp: float = 0.0
	var ph: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(SR)
		var open: float = clampf(t / 0.25, 0.0, 1.0) * clampf((WHOOSH_S - t) / 0.45, 0.0, 1.0)
		var k: float = lerpf(0.04, 0.55, open)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		var env: float = minf(1.0, t / 0.03) * clampf((WHOOSH_S - t) / 0.5, 0.0, 1.0)
		ph += TAU * lerpf(70.0, 40.0, clampf(t / 0.15, 0.0, 1.0)) / float(SR)
		var thump: float = sin(ph) * exp(-t * 18.0)
		var v: float = clampf(lp * 1.6 * env + thump * 0.8, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = data
	_whoosh = s
	return s
