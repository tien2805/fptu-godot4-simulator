# File: res://scripts/weapons/WeaponFX.gd
# Gameplay hit FX of Phase W, built in code (spec section 3). It reuses the A1 CineFX bursts (sparks, dust, flash) and daze
# stars, driven by a game clock (scaled seconds) instead of a cinematic story clock, plus short-lived nodes of its own
# ("transients": tracers, smoke puffs, scorch marks, stink clouds, sonic rings – Tasks 4-6) that can fade their material's
# alpha over the last `fade` seconds and grow. CineFX keeps its star rings until it is freed, so the CineFX child is replaced
# once nothing is alive (RECYCLE_AFTER s after the last burst / star window ended). top_level at the world origin: every
# position is global. CPUParticles3D only.
class_name WeaponFX
extends Node3D

const RECYCLE_AFTER: float = 2.0
const LIFE: Dictionary = {"sparks": 2.5, "dust": 3.2, "flash": 0.2}
const TRACER_S: float = 0.07
const TRACER_COL := Color(1.0, 0.85, 0.45, 0.9)
const SCORCH_S: float = 20.0

var cine: CineFX
var t: float = 0.0
var recycles: int = 0
var _busy_until: float = 0.0
var _transient: Array[Dictionary] = []    # {"node", "t0", "life", "kind", "mat", "a0", "fade", "grow"}


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_new_cine()


func _new_cine() -> void:
	cine = CineFX.new()
	cine.name = "CineFX"
	add_child(cine)


func _physics_process(delta: float) -> void:
	t += delta
	cine.update(t, Engine.time_scale)   # particles already run on scaled time: speed / time_scale = 1
	_tick_transient()
	if t > _busy_until + RECYCLE_AFTER and cine.get_child_count() > 0:
		cine.queue_free()
		_new_cine()
		recycles += 1


## CineFX burst ("sparks" | "dust" | "flash") at a world position.
func burst(kind: String, pos: Vector3, dir: Vector3, power: float) -> void:
	cine.burst(kind, pos, dir, power, t)
	_busy_until = maxf(_busy_until, t + float(LIFE.get(kind, 3.0)))


## Comic daze stars orbiting the target's head for `secs` game seconds.
func stars(target: Node3D, secs: float) -> void:
	cine.stars(target, t, t + secs)
	_busy_until = maxf(_busy_until, t + secs)


## A short-lived node owned by the FX layer: freed after `life`; if `mat` is given its alpha fades to 0 over the last
## `fade` seconds; `grow` scales it from 1 to 1 + grow over its life.
func add_transient(node: Node3D, life: float, kind: String, mat: StandardMaterial3D = null, fade: float = 0.0, grow: float = 0.0) -> void:
	add_child(node)
	_transient.append({"node": node, "t0": t, "life": life, "kind": kind, "mat": mat, "a0": mat.albedo_color.a if mat else 1.0, "fade": fade, "grow": grow})


func transient_count(kind: String = "") -> int:
	var n: int = 0
	for e: Dictionary in _transient:
		if kind == "" or String(e["kind"]) == kind:
			n += 1
	return n


func _tick_transient() -> void:
	for i: int in range(_transient.size() - 1, -1, -1):
		var e: Dictionary = _transient[i]
		var node: Node3D = e["node"] if is_instance_valid(e["node"]) else null
		var age: float = t - float(e["t0"])
		var life: float = e["life"]
		if node == null or age >= life:
			if node:
				node.queue_free()
			_transient.remove_at(i)
			continue
		var mat: StandardMaterial3D = e["mat"]
		if mat and float(e["fade"]) > 0.0:
			mat.albedo_color.a = float(e["a0"]) * clampf((life - age) / float(e["fade"]), 0.0, 1.0)
		if float(e["grow"]) > 0.0:
			node.scale = Vector3.ONE * (1.0 + float(e["grow"]) * age / life)


## Muzzle flash with a few sparks forward.
func muzzle(pos: Vector3, dir: Vector3, power: float = 1.0) -> void:
	burst("flash", pos + dir * 0.15, dir, 0.35 * power)
	burst("sparks", pos + dir * 0.2, dir, 0.25 * power)


## Bullet tracer a -> b: a thin unshaded additive box that fades out within TRACER_S.
func tracer(a: Vector3, b: Vector3) -> void:
	var dist: float = a.distance_to(b)
	if dist < 0.2:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Tracer"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, dist)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = TRACER_COL
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fwd: Vector3 = (b - a) / dist
	var up: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(fwd, up), (a + b) * 0.5)
	add_transient(mi, TRACER_S, "tracer", m, TRACER_S)


## Bullet impact: dust on a person, sparks + dust on hard surfaces.
func impact(pos: Vector3, normal: Vector3, soft: bool) -> void:
	if soft:
		burst("dust", pos, normal, 0.35)
	else:
		burst("sparks", pos, normal, 0.6)
		burst("dust", pos, normal, 0.25)


## Rocket explosion: big flash, sparks and dust, a dark smoke puff (4 s) and a scorch mark on the floor below (fades over
## its last 3 s of SCORCH_S). ex: bodies the floor ray ignores (people, the player, traffic).
func explosion(pos: Vector3, radius: float, ex: Array[RID] = []) -> void:
	burst("flash", pos + Vector3(0.0, 0.6, 0.0), Vector3.UP, 4.0)
	burst("sparks", pos, Vector3.UP, 2.5)
	burst("dust", pos, Vector3.UP, 3.0)
	var p := CPUParticles3D.new()
	p.name = "SmokePuff"
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 36
	p.lifetime = 3.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3(0.0, 1.0, 0.0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.damping_min = 1.0
	p.damping_max = 1.5
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.mesh = CineFX._particle_mesh(false)
	p.color_ramp = CineFX._ramp([Color(0.16, 0.15, 0.15, 0.85), Color(0.35, 0.35, 0.36, 0.0)], PackedFloat32Array([0.0, 1.0]))
	p.position = pos + Vector3(0.0, 0.8, 0.0)
	add_transient(p, 4.0, "smoke")
	p.emitting = true
	_scorch(pos, radius * 0.45, ex)


func _scorch(pos: Vector3, r: float, ex: Array[RID]) -> void:
	var floor_y: float = pos.y - 1.0
	if is_inside_tree():
		var rq := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 1.0, 0.0), pos - Vector3(0.0, 6.0, 0.0))
		rq.exclude = ex
		rq.collide_with_areas = false
		var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
		if not h.is_empty():
			floor_y = (h["position"] as Vector3).y
	var mi := MeshInstance3D.new()
	mi.name = "Scorch"
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = CineFX.radial_texture(64, 1.2)
	m.albedo_color = Color(0.05, 0.04, 0.04, 0.8)
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(pos.x, floor_y + 0.03, pos.z)
	add_transient(mi, SCORCH_S, "scorch", m, 3.0)


## Fire and smoke trail on a rocket (a child of it, freed with it).
func rocket_trail(rocket: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.name = "Trail"
	p.amount = 40
	p.lifetime = 0.6
	p.local_coords = false
	p.direction = Vector3(0.0, 0.0, 1.0)
	p.spread = 8.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	p.mesh = CineFX._particle_mesh(false)
	p.color_ramp = CineFX._ramp([Color(1.0, 0.75, 0.35, 0.9), Color(0.5, 0.5, 0.5, 0.5), Color(0.6, 0.6, 0.6, 0.0)], PackedFloat32Array([0.0, 0.25, 1.0]))
	p.position = Vector3(0.0, 0.0, 0.3)
	rocket.add_child(p)
	p.emitting = true


## Sầu riêng stink: green-brown puffs over a disc of radius r for secs.
func stink(pos: Vector3, r: float, secs: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "Stink"
	p.amount = 48
	p.lifetime = 2.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(r * 0.8, 0.4, r * 0.8)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0.0, 0.3, 0.0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.mesh = CineFX._particle_mesh(false)
	p.color_ramp = CineFX._ramp([Color(0.45, 0.62, 0.18, 0.0), Color(0.45, 0.62, 0.18, 0.55), Color(0.38, 0.45, 0.15, 0.0)], PackedFloat32Array([0.0, 0.3, 1.0]))
	p.position = pos + Vector3(0.0, 0.6, 0.0)
	add_transient(p, secs, "stink")
	p.emitting = true


## Loa kẹo kéo: a pink ring in front of the speaker that grows and fades in 0.5 s.
func sonic_ring(apex: Vector3, dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "SonicRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.55
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.37, 0.69, 0.7)
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var f: Vector3 = WeaponMath.flat_dir(dir)
	mi.transform = Transform3D(Basis.looking_at(f, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), apex + f * 0.8)
	add_transient(mi, 0.5, "sonic", m, 0.5, 5.0)
