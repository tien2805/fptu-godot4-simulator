# File: res://scripts/fx/FxPool.gd
# Q3 VFX library (master plan 2026-10-29 Q3; plan docs/superpowers/plans/2026-10-29-q3-look.md Task 3): one pooled node per
# scene (FreeRoam, StoryBasement, NightBuilding) in the group "fx_pool". Other code finds it through the group and calls
#   spawn(kind, pos, dir = Vector3.UP, scale = 1.0) -> bool
# guarded by has_method (the Q2 combat-feel stream: get_tree().get_first_node_in_group("fx_pool")).
#
# Kinds (KINDS): sparks, dust, dust_ring, smoke, debris, splash, fire, rain_burst, speed_lines, nitro_flame. Every kind owns
# a fixed number of prebuilt CPUParticles3D emitters (its budget), all built in _ready with shared meshes, materials,
# colour ramps and curves (static caches): spawning never creates a node or a resource. A spawn takes a free emitter of
# the kind, else steals the one that frees soonest (`steals` counts them); the emitter moves to pos (world-space particles:
# moving it later never drags live particles).
# dir contract: dust, dust_ring, smoke, fire and rain_burst always stand upright (local +Y = UP, dir is ignored: a
# horizontal attacker-to-target dir never tips a dust ring into a vertical disc); sparks, debris, splash, speed_lines
# and nitro_flame point their local +Y along dir (UP_KINDS lists the upright ones). One-shot kinds burst once; continuous kinds
# (fire, rain_burst, speed_lines, nitro_flame) emit for their "dur" seconds (x scale) and are stopped by the pool's
# _process, which only walks the few continuous emitters. scale multiplies particle size and emission radius, speeds by
# sqrt(scale). Quality 0 (GameFX THẤP) halves every particle amount (decided once in _ready).
# Code-built look: a radial soft-dot texture (GradientTexture2D), unshaded billboards (additive for sparks / fire / nitro /
# speed lines), shaded little boxes for debris. Materials carry meta vice_done (ViceStyle leaves them alone).
class_name FxPool
extends Node3D

const GROUP: StringName = &"fx_pool"
## budget: emitters of the kind; amount: particles per emitter; life: particle lifetime (s); dur: continuous emission time
## (s, 0 = one shot).
const KINDS: Dictionary = {
	"sparks": {"budget": 6, "amount": 24, "life": 0.45, "dur": 0.0},
	"dust": {"budget": 6, "amount": 10, "life": 0.9, "dur": 0.0},
	"dust_ring": {"budget": 4, "amount": 24, "life": 0.7, "dur": 0.0},
	"smoke": {"budget": 4, "amount": 14, "life": 2.4, "dur": 0.0},
	"debris": {"budget": 4, "amount": 10, "life": 1.4, "dur": 0.0},
	"splash": {"budget": 3, "amount": 30, "life": 0.9, "dur": 0.0},
	"fire": {"budget": 3, "amount": 24, "life": 0.7, "dur": 2.5},
	"rain_burst": {"budget": 2, "amount": 60, "life": 0.6, "dur": 1.5},
	"speed_lines": {"budget": 2, "amount": 24, "life": 0.25, "dur": 0.6},
	"nitro_flame": {"budget": 2, "amount": 24, "life": 0.18, "dur": 0.4},
}
## Kinds that ignore spawn()'s dir and always emit upright (ground puffs, rising smoke and flames, falling rain).
const UP_KINDS: Array[String] = ["dust", "dust_ring", "smoke", "fire", "rain_burst"]
## Spawn order of the kinds in the flat emitter list (fixed, so indices are stable).
const ORDER: Array[String] = ["sparks", "dust", "dust_ring", "smoke", "debris", "splash", "fire", "rain_burst", "speed_lines", "nitro_flame"]

static var _soft_tex: GradientTexture2D = null
static var _res: Dictionary = {}           # cached meshes / materials / ramps / curves by key

var quality: int = 2
var steals: int = 0
var spawns: int = 0
var _all: Array[CPUParticles3D] = []
var _until: PackedFloat32Array = PackedFloat32Array()     # pool clock when the emitter's last particle dies
var _stop_at: PackedFloat32Array = PackedFloat32Array()   # continuous emitters: when emission stops (0 = not running)
var _amount: PackedInt32Array = PackedInt32Array()
var _base_scale: PackedFloat32Array = PackedFloat32Array()
var _base_v: PackedVector2Array = PackedVector2Array()    # initial velocity min / max at scale 1
var _base_r: PackedFloat32Array = PackedFloat32Array()    # emission radius (sphere / ring / box half x) at scale 1
var _cont: PackedInt32Array = PackedInt32Array()          # indices of continuous emitters
var _start: Dictionary = {}                                # kind -> first index
var _count: Dictionary = {}                                # kind -> emitters
var _t: float = 0.0


func _init() -> void:
	name = "FxPool"


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	quality = _quality()
	for kind: String in ORDER:
		var d: Dictionary = KINDS[kind]
		_start[kind] = _all.size()
		_count[kind] = int(d["budget"])
		for i: int in range(int(d["budget"])):
			var p: CPUParticles3D = _build(kind)
			p.name = "%s_%d" % [kind, i]
			add_child(p)
			_all.append(p)
			_until.append(0.0)
			_stop_at.append(0.0)
			_amount.append(p.amount)
			_base_scale.append(p.scale_amount_max)
			_base_v.append(Vector2(p.initial_velocity_min, p.initial_velocity_max))
			_base_r.append(_radius_of(p))
			if float(d["dur"]) > 0.0:
				_cont.append(_all.size() - 1)


## Finds the scene's pool (null when the scene has none).
static func find(tree: SceneTree) -> FxPool:
	return tree.get_first_node_in_group(GROUP) as FxPool if tree else null


func has_kind(kind: String) -> bool:
	return _start.has(kind)


func budget(kind: String) -> int:
	return int(_count.get(kind, 0))


## Spawns one effect. false = unknown kind (or the pool is not ready).
func spawn(kind: String, pos: Vector3, dir: Vector3 = Vector3.UP, scale: float = 1.0) -> bool:
	if not _start.has(kind):
		return false
	var s0: int = int(_start[kind])
	var n: int = int(_count[kind])
	var pick: int = -1
	var best: int = s0
	var soonest: float = INF
	for i: int in range(s0, s0 + n):
		if _until[i] <= _t:
			pick = i
			break
		if _until[i] < soonest:
			soonest = _until[i]
			best = i
	if pick < 0:
		pick = best
		steals += 1
	spawns += 1
	var sc: float = clampf(scale, 0.1, 6.0)
	var p: CPUParticles3D = _all[pick]
	p.global_transform = Transform3D(_basis_up(Vector3.UP if kind in UP_KINDS else dir), pos)
	p.scale_amount_max = _base_scale[pick] * sc
	p.scale_amount_min = _base_scale[pick] * sc * 0.55
	var vs: float = sqrt(sc)
	p.initial_velocity_min = _base_v[pick].x * vs
	p.initial_velocity_max = _base_v[pick].y * vs
	_set_radius(p, _base_r[pick] * sc)
	var d: Dictionary = KINDS[kind]
	var life: float = float(d["life"])
	var dur: float = float(d["dur"])
	if dur > 0.0:
		p.one_shot = false
		_stop_at[pick] = _t + dur * maxf(sc, 0.5)
		_until[pick] = _stop_at[pick] + life * 1.2
	else:
		p.one_shot = true
		_stop_at[pick] = 0.0
		_until[pick] = _t + life * 1.2
	p.restart()
	p.emitting = true
	return true


## Emitters of a kind ("" = all) still showing particles.
func active_count(kind: String = "") -> int:
	var a: int = 0
	var b: int = _all.size()
	if kind != "":
		if not _start.has(kind):
			return 0
		a = int(_start[kind])
		b = a + int(_count[kind])
	var c: int = 0
	for i: int in range(a, b):
		if _until[i] > _t:
			c += 1
	return c


## Upper bound of live particles right now (render budget): the amounts of the active emitters.
func active_particles() -> int:
	var c: int = 0
	for i: int in range(_all.size()):
		if _until[i] > _t:
			c += _amount[i]
	return c


## Every emitter running at once.
func max_particles() -> int:
	var c: int = 0
	for a: int in _amount:
		c += a
	return c


func emitter_count() -> int:
	return _all.size()


## Stops everything at once (scene changes, cinematics).
func stop_all() -> void:
	for i: int in range(_all.size()):
		_all[i].emitting = false
		_until[i] = 0.0
		_stop_at[i] = 0.0


func _process(delta: float) -> void:
	_t += delta
	for i: int in _cont:
		if _stop_at[i] > 0.0 and _t >= _stop_at[i]:
			_stop_at[i] = 0.0
			_all[i].emitting = false


## Advances the pool clock by hand (tests).
func advance(dt: float) -> void:
	_process(dt)


# ---------------------------------------------------------------------------
# Emitters
# ---------------------------------------------------------------------------
func _build(kind: String) -> CPUParticles3D:
	var d: Dictionary = KINDS[kind]
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = float(d["dur"]) <= 0.0
	p.local_coords = false
	p.amount = maxi(4, int(d["amount"]) / (2 if quality <= 0 else 1))
	p.lifetime = float(d["life"])
	p.explosiveness = 1.0
	p.randomness = 0.3
	p.lifetime_randomness = 0.3
	p.direction = Vector3.UP
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	match kind:
		"sparks":
			p.mesh = _quad("spark", Vector2(0.05, 0.05))
			p.material_override = _mat("add_dot", true, true)
			p.spread = 55.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 9.0
			p.gravity = Vector3(0.0, -12.0, 0.0)
			p.damping_min = 1.0
			p.damping_max = 3.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			p.color_ramp = _ramp("sparks", [Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.62, 0.15, 1.0), Color(0.9, 0.2, 0.05, 0.0)])
		"dust":
			p.mesh = _quad("puff", Vector2(0.5, 0.5))
			p.material_override = _mat("mix_dot", true, false)
			p.spread = 70.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0.0, 0.25, 0.0)
			p.damping_min = 1.5
			p.damping_max = 2.5
			p.explosiveness = 0.9
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.1
			p.scale_amount_curve = _curve("grow", 0.45, 1.0)
			p.color_ramp = _ramp("dust", [Color(0.72, 0.64, 0.54, 0.55), Color(0.62, 0.56, 0.5, 0.0)])
		"dust_ring":
			p.mesh = _quad("puff", Vector2(0.5, 0.5))
			p.material_override = _mat("mix_dot", true, false)
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = 0.35
			p.emission_ring_inner_radius = 0.25
			p.emission_ring_height = 0.05
			p.direction = Vector3(1.0, 0.0, 0.0)
			p.spread = 180.0
			p.flatness = 1.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 4.5
			p.gravity = Vector3(0.0, 0.3, 0.0)
			p.damping_min = 4.0
			p.damping_max = 6.0
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.2
			p.scale_amount_curve = _curve("grow", 0.45, 1.0)
			p.color_ramp = _ramp("dust_ring", [Color(0.78, 0.7, 0.6, 0.6), Color(0.7, 0.64, 0.58, 0.0)])
		"smoke":
			p.mesh = _quad("smoke", Vector2(1.0, 1.0))
			p.material_override = _mat("mix_dot", true, false)
			p.spread = 25.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0.0, 0.35, 0.0)
			p.damping_min = 0.4
			p.damping_max = 0.8
			p.explosiveness = 0.35
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
			p.scale_amount_curve = _curve("grow_big", 0.35, 1.0)
			p.color_ramp = _ramp("smoke", [Color(0.22, 0.21, 0.23, 0.0), Color(0.26, 0.25, 0.27, 0.55), Color(0.36, 0.35, 0.37, 0.0)])
		"debris":
			p.mesh = _box("chunk", Vector3(0.12, 0.08, 0.1))
			p.material_override = _mat("debris", false, false)
			p.spread = 50.0
			p.initial_velocity_min = 3.5
			p.initial_velocity_max = 7.0
			p.gravity = Vector3(0.0, -14.0, 0.0)
			p.angular_velocity_min = -540.0
			p.angular_velocity_max = 540.0
			p.particle_flag_rotate_y = true
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.3
			p.color_ramp = _ramp("debris", [Color(0.55, 0.52, 0.5, 1.0), Color(0.42, 0.38, 0.34, 1.0)])
		"splash":
			p.mesh = _quad("drop", Vector2(0.12, 0.12))
			p.material_override = _mat("mix_dot", true, false)
			p.spread = 28.0
			p.initial_velocity_min = 3.5
			p.initial_velocity_max = 6.5
			p.gravity = Vector3(0.0, -11.0, 0.0)
			p.emission_sphere_radius = 0.3
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.4
			p.color_ramp = _ramp("splash", [Color(0.9, 0.97, 1.0, 0.85), Color(0.6, 0.8, 1.0, 0.0)])
		"fire":
			p.mesh = _quad("flame", Vector2(0.55, 0.55))
			p.material_override = _mat("add_dot", true, true)
			p.explosiveness = 0.0
			p.spread = 14.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.2
			p.gravity = Vector3(0.0, 1.5, 0.0)
			p.emission_sphere_radius = 0.35
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			p.scale_amount_curve = _curve("shrink", 1.0, 0.25)
			p.color_ramp = _ramp("fire", [Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.45, 0.08, 0.7), Color(0.5, 0.08, 0.02, 0.0)])
		"rain_burst":
			p.mesh = _quad("streak_rain", Vector2(0.015, 0.35))
			p.material_override = _mat("mix_streak", false, false)
			p.explosiveness = 0.0
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(1.5, 0.1, 1.5)
			p.direction = Vector3.DOWN
			p.spread = 4.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 8.0
			p.gravity = Vector3(0.0, -9.8, 0.0)
			p.particle_flag_align_y = true
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.0
			p.color_ramp = _ramp("rain", [Color(0.75, 0.88, 1.0, 0.55), Color(0.75, 0.88, 1.0, 0.35)])
		"speed_lines":
			p.mesh = _quad("streak_speed", Vector2(0.03, 1.4))
			p.material_override = _mat("add_streak", false, true)
			p.explosiveness = 0.0
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = 2.4
			p.emission_ring_inner_radius = 1.4
			p.emission_ring_height = 0.2
			p.direction = Vector3.DOWN          # local +Y = the caller's forward: lines stream back past the viewer
			p.spread = 2.0
			p.initial_velocity_min = 22.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector3.ZERO
			p.particle_flag_align_y = true
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.0
			p.color_ramp = _ramp("speed", [Color(1.0, 1.0, 1.0, 0.0), Color(0.9, 0.97, 1.0, 0.35), Color(1.0, 1.0, 1.0, 0.0)])
		"nitro_flame":
			p.mesh = _quad("nitro", Vector2(0.22, 0.22))
			p.material_override = _mat("add_dot", true, true)
			p.explosiveness = 0.0
			p.spread = 8.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 5.0
			p.gravity = Vector3.ZERO
			p.emission_sphere_radius = 0.04
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.0
			p.scale_amount_curve = _curve("shrink", 1.0, 0.25)
			p.color_ramp = _ramp("nitro", [Color(0.9, 0.97, 1.0, 0.95), Color(0.3, 0.6, 1.0, 0.8), Color(0.15, 0.3, 1.0, 0.0)])
	return p


static func _radius_of(p: CPUParticles3D) -> float:
	match p.emission_shape:
		CPUParticles3D.EMISSION_SHAPE_RING:
			return p.emission_ring_radius
		CPUParticles3D.EMISSION_SHAPE_BOX:
			return p.emission_box_extents.x
	return p.emission_sphere_radius


static func _set_radius(p: CPUParticles3D, r: float) -> void:
	match p.emission_shape:
		CPUParticles3D.EMISSION_SHAPE_RING:
			var k: float = p.emission_ring_inner_radius / maxf(p.emission_ring_radius, 0.001)
			p.emission_ring_radius = r
			p.emission_ring_inner_radius = r * k
		CPUParticles3D.EMISSION_SHAPE_BOX:
			p.emission_box_extents = Vector3(r, p.emission_box_extents.y, r)
		_:
			p.emission_sphere_radius = r


## Rotation whose +Y is dir (UP when dir is ~zero).
static func _basis_up(dir: Vector3) -> Basis:
	var up: Vector3 = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP
	var a: Vector3 = Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT
	var x: Vector3 = up.cross(a).normalized()
	var z: Vector3 = x.cross(up)
	return Basis(x, up, z)


# ---------------------------------------------------------------------------
# Shared resources (built once per process)
# ---------------------------------------------------------------------------
static func _soft() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 32
		t.height = 32
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		_soft_tex = t
	return _soft_tex


static func _quad(key: String, size: Vector2) -> QuadMesh:
	var k: String = "quad_" + key
	if not _res.has(k):
		var q := QuadMesh.new()
		q.size = size
		_res[k] = q
	return _res[k]


static func _box(key: String, size: Vector3) -> BoxMesh:
	var k: String = "box_" + key
	if not _res.has(k):
		var b := BoxMesh.new()
		b.size = size
		_res[k] = b
	return _res[k]


## dot: soft round texture (else a flat streak); add: additive blend. Billboards: dots face the camera, streaks turn
## around their own Y (aligned to the velocity by particle_flag_align_y). "debris" = shaded boxes.
static func _mat(key: String, dot: bool, add: bool) -> StandardMaterial3D:
	var k: String = "mat_" + key
	if _res.has(k):
		return _res[k]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if key == "debris":
		m.roughness = 0.9
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if dot else BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
		if dot:
			m.albedo_texture = _soft()
		if add:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.set_meta("vice_done", true)
	_res[k] = m
	return m


static func _ramp(key: String, cols: Array) -> Gradient:
	var k: String = "ramp_" + key
	if _res.has(k):
		return _res[k]
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var pc := PackedColorArray()
	for i: int in range(cols.size()):
		offs.append(float(i) / float(maxi(1, cols.size() - 1)))
		pc.append(cols[i])
	g.offsets = offs
	g.colors = pc
	_res[k] = g
	return g


static func _curve(key: String, a: float, b: float) -> Curve:
	var k: String = "curve_" + key
	if _res.has(k):
		return _res[k]
	var c := Curve.new()
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	_res[k] = c
	return c


static func _quality() -> int:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml and ml.root:
		var g: Node = ml.root.get_node_or_null("GameFX")
		if g:
			return int(g.get("visual_quality"))
	return 2
