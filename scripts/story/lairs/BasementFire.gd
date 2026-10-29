# File: res://scripts/story/lairs/BasementFire.gd
# W3 D5W-1 (plan 2026-10-30-w3-day5.md T4): the server room catching fire while the player types (MissionHack). A fixed
# pool of CPUParticles3D built once in setup() (FIRE_N fire and SMOKE_N smoke emitters at the given spots, one flickering
# OmniLight3D that never moves), driven by set_stage(0..3): the fire grows at 90 / 60 / 30 / 10 s left (more emitters,
# bigger flames, denser smoke, a brighter light); set_stage(-1) / stop() turns everything off (nothing is ever made per
# frame). The light flickers at 20 Hz while lit. Plain code-built FX, no texture.
class_name BasementFire
extends Node3D

const STAGE_FIRES: Array[int] = [1, 2, 3, 4]
const STAGE_SMOKE: Array[int] = [0, 1, 2, 2]
const STAGE_SCALE: Array[float] = [0.55, 0.8, 1.05, 1.4]
const STAGE_LIGHT: Array[float] = [0.7, 1.3, 2.0, 2.9]
const FIRE_COL := Color(1.0, 0.55, 0.15)
const SMOKE_COL := Color(0.12, 0.11, 0.12, 0.55)

var stage: int = -1
var fires: Array[CPUParticles3D] = []
var smokes: Array[CPUParticles3D] = []
var light: OmniLight3D
var _t: float = 0.0
var _acc: float = 0.0


func _init() -> void:
	name = "BasementFire"


## Builds the pool at the fire spots and the smoke spots (local to this node's parent frame: world positions are fine
## when the node sits at the origin).
func setup(fire_pts: Array, smoke_pts: Array) -> void:
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.vertex_color_use_as_albedo = true
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.albedo_color = Color(1.6, 1.1, 0.7)
	fmat.set_meta("vice_done", true)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.set_meta("vice_done", true)
	var framp := Gradient.new()
	framp.offsets = PackedFloat32Array([0.0, 1.0])
	framp.colors = PackedColorArray([Color(1.0, 0.85, 0.35, 0.95), Color(0.9, 0.12, 0.02, 0.0)])
	var sramp := Gradient.new()
	sramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	sramp.colors = PackedColorArray([Color(SMOKE_COL.r, SMOKE_COL.g, SMOKE_COL.b, 0.0), SMOKE_COL, Color(0.2, 0.19, 0.2, 0.0)])
	for p: Variant in fire_pts:
		var f := CPUParticles3D.new()
		f.name = "Fire"
		f.emitting = false
		f.amount = 26
		f.lifetime = 0.8
		f.local_coords = false
		f.direction = Vector3.UP
		f.spread = 18.0
		f.gravity = Vector3(0.0, 1.6, 0.0)
		f.initial_velocity_min = 0.6
		f.initial_velocity_max = 1.4
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		f.emission_sphere_radius = 0.35
		f.scale_amount_min = 0.6
		f.scale_amount_max = 1.1
		f.color_ramp = framp
		var qm := QuadMesh.new()
		qm.size = Vector2(0.45, 0.6)
		qm.material = fmat
		f.mesh = qm
		add_child(f)
		f.position = p
		fires.append(f)
	for p2: Variant in smoke_pts:
		var s := CPUParticles3D.new()
		s.name = "Smoke"
		s.emitting = false
		s.amount = 14
		s.lifetime = 2.6
		s.local_coords = false
		s.direction = Vector3.UP
		s.spread = 25.0
		s.gravity = Vector3(0.0, 0.5, 0.0)
		s.initial_velocity_min = 0.4
		s.initial_velocity_max = 0.9
		s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = 0.5
		s.scale_amount_min = 1.2
		s.scale_amount_max = 2.2
		s.color_ramp = sramp
		var qm2 := QuadMesh.new()
		qm2.size = Vector2(0.9, 0.9)
		qm2.material = smat
		s.mesh = qm2
		add_child(s)
		s.position = p2 + Vector3(0.0, 1.0, 0.0)
		smokes.append(s)
	light = OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.45, 0.18)
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	if not fire_pts.is_empty():
		light.position = (fire_pts[0] as Vector3) + Vector3(0.0, 1.2, 0.0)
	set_process(false)


## 0..3 = the fire's size (90 / 60 / 30 / 10 s left); -1 = out.
func set_stage(s: int) -> void:
	s = clampi(s, -1, STAGE_FIRES.size() - 1)
	if s == stage:
		return
	stage = s
	for i: int in fires.size():
		var on: bool = s >= 0 and i < STAGE_FIRES[s]
		var f: CPUParticles3D = fires[i]
		if on:
			f.scale_amount_min = 0.6 * STAGE_SCALE[s]
			f.scale_amount_max = 1.1 * STAGE_SCALE[s]
			f.emission_sphere_radius = 0.35 * STAGE_SCALE[s]
		f.emitting = on
	for j: int in smokes.size():
		smokes[j].emitting = s >= 0 and j < STAGE_SMOKE[s]
	if light:
		light.visible = s >= 0
		light.light_energy = STAGE_LIGHT[s] if s >= 0 else 0.0
	set_process(s >= 0)


func stop() -> void:
	set_stage(-1)


## Emitters emitting now (tests).
func emitting_count() -> int:
	var n: int = 0
	for f: CPUParticles3D in fires:
		n += 1 if f.emitting else 0
	for s: CPUParticles3D in smokes:
		n += 1 if s.emitting else 0
	return n


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < 0.05 or stage < 0:
		return
	_acc = 0.0
	light.light_energy = STAGE_LIGHT[stage] * (0.75 + 0.25 * sin(_t * 23.0) * sin(_t * 7.3 + 1.0))
