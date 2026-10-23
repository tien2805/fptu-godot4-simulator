# File: res://scripts/cine/CineFX.gd
# Code-built impact FX for cinematics (spec A1). Everything is driven by the cinematic clock through update(s, speed):
# - sparks / dust are CPUParticles3D whose speed_scale follows the clock speed (they freeze in freezes, crawl in slow motion);
# - flash, debris and daze stars are pure functions of story time s (seeking or re-evaluating the same s gives the same frame);
# - debris chunks fly a ballistic arc, bounce once, then rest flat on the ground (at half their box height) until this node
#   is freed (aftermath);
# - particle emitters use a fixed seed from their position (repeatable runs) and start at the current clock speed (a burst
#   fired inside a freeze is frozen from its first frame).
# Playback is FORWARD-ONLY: crate_break hides the intact crates and expired flashes / particles are freed, so seeking back
# before an event does not undo it (debris and stars themselves are pure functions of s).
# Positions passed to burst() are in this node's local space (CinePlayer parents CineFX under the stage).
# Also builds the A1 set-dressing props (crate stack, scooter, banana, phone, helmet) from plain meshes; no imported art, no
# GPUParticles, no AI images. Textures are generated in code (radial_texture).
class_name CineFX
extends Node3D

const REST_Y: float = 0.03            # rest height of a chunk whose mesh is not a BoxMesh
const GRAVITY: float = 9.8
const FLASH_LEN: float = 0.12
const PARTICLE_GRACE: float = 2.0
const STAR_RADIUS: float = 0.22
const STAR_RATE: float = 4.0
const COL_ASPHALT: Color = Color("#2E2E33")
const COL_WOOD_CHUNK: Color = Color("#8A6A43")
const COL_CRATE: Color = Color("#9A7448")
const COL_CRATE_EDGE: Color = Color("#6E5232")
## Prop kinds build_prop knows (timeline props and held props).
const PROP_KINDS: Array[String] = ["crate_stack", "scooter", "banana", "phone", "helmet"]

var _serial: int = 0
var _parts: Array[Dictionary] = []     # {node: CPUParticles3D, s0, life}
var _debris: Array[Dictionary] = []    # {node, p0, v, w, r0, s0, tg, p1, v2, dt2, rot_g, rest}
var _flashes: Array[Dictionary] = []   # {node, mat, s0, size}
var _stars: Array[Dictionary] = []     # {nodes: Array[Node3D], actor, s0, s1}
var _last_ss: float = 1.0              # particle speed_scale of the last update() (new bursts start at it)

static var _tex_cache: Dictionary = {}
static var _star_mesh: ArrayMesh = null


# ---------------------------------------------------------------------------
# Spawning
# ---------------------------------------------------------------------------
## kind: sparks | dust | flash | debris. pos/dir in local space, power ~1 for a normal hit, s = story time of the impact.
func burst(kind: String, pos: Vector3, dir: Vector3, power: float, s: float) -> void:
	match kind:
		"sparks":
			_sparks(pos, dir, power, s)
		"dust":
			_dust(pos, power, s)
		"flash":
			_flash(pos, power, s)
		"debris":
			_debris_burst(pos, dir, power, s)
		_:
			push_warning("CineFX.burst: unknown kind '%s'" % kind)


func _next_name(prefix: String) -> String:
	_serial += 1
	return "%s%d" % [prefix, _serial]


static func _particle_mesh(additive: bool) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = radial_texture(64, 2.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.set_meta("vice_done", true)   # ViceStyle must not flatten FX materials
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = m
	return q


static func _ramp(cols: Array[Color], offs: PackedFloat32Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	return g


func _add_particles(p: CPUParticles3D, prefix: String, pos: Vector3, s: float) -> void:
	p.name = _next_name(prefix)
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.position = pos
	p.use_fixed_seed = true
	p.seed = hash(pos)
	p.speed_scale = _last_ss
	add_child(p)
	p.emitting = true
	_parts.append({"node": p, "s0": s, "life": p.lifetime})


func _sparks(pos: Vector3, dir: Vector3, power: float, s: float) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _particle_mesh(true)
	p.amount = maxi(8, int(28.0 * power))
	p.lifetime = 0.45
	p.direction = dir if dir.length_squared() > 1e-6 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 4.0 * power
	p.initial_velocity_max = 9.0 * power
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.035
	p.scale_amount_max = 0.08
	p.color_ramp = _ramp([Color.WHITE, Color("#FFB040"), Color(1.0, 0.69, 0.25, 0.0)], PackedFloat32Array([0.0, 0.4, 1.0]))
	_add_particles(p, "Sparks", pos, s)


func _dust(pos: Vector3, power: float, s: float) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _particle_mesh(false)
	p.amount = maxi(8, int(20.0 * power))
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.35
	p.emission_ring_inner_radius = 0.1
	p.emission_ring_height = 0.02
	p.direction = Vector3(1.0, 0.0, 0.0)
	p.spread = 180.0
	p.flatness = 1.0
	p.initial_velocity_min = 1.2 * power
	p.initial_velocity_max = 2.6 * power
	p.damping_min = 2.5
	p.damping_max = 2.5
	p.gravity = Vector3(0.0, -0.5, 0.0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var dc := Color("#B9AE9A")
	p.color_ramp = _ramp([Color(dc, 0.55), Color(dc, 0.0)], PackedFloat32Array([0.0, 1.0]))
	_add_particles(p, "Dust", pos, s)


func _flash(pos: Vector3, power: float, s: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = _next_name("Flash")
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = radial_texture(64, 2.0)
	m.albedo_color = Color(1.0, 0.95, 0.85, 1.0)
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	var f: Dictionary = {"node": mi, "mat": m, "s0": s, "size": 1.2 * power}
	_flashes.append(f)
	_eval_flash(f, s)


func _debris_burst(pos: Vector3, dir: Vector3, power: float, s: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	var mats: Array[StandardMaterial3D] = [_mat(COL_ASPHALT, 0.95), _mat(COL_WOOD_CHUNK, 0.85)]
	var d: Vector3 = dir.normalized()
	for i: int in maxi(4, int(8.0 * power)):
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.04, 0.12), rng.randf_range(0.04, 0.12), rng.randf_range(0.04, 0.12))
		var v: Vector3 = d * rng.randf_range(2.0, 5.0) * power + Vector3(0.0, rng.randf_range(2.0, 4.0), 0.0) \
			+ Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		var w := Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-12.0, 12.0))
		_spawn_chunk(bm, mats[rng.randi() % 2], pos, v, w, Vector3.ZERO, s)


## Launch one debris chunk (also used for crate planks). Precomputes the contacts so evaluation is a pure function of s.
func _spawn_chunk(mesh: Mesh, mat: Material, p0: Vector3, v: Vector3, w: Vector3, r0: Vector3, s: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = _next_name("Debris")
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	var rest: float = (mesh as BoxMesh).size.y * 0.5 if mesh is BoxMesh else REST_Y   # lies flat, does not sink
	var a: float = 0.5 * GRAVITY
	# first contact: p0.y + v.y t - a t^2 = rest
	var disc: float = v.y * v.y + 4.0 * a * (p0.y - rest)
	var tg: float = maxf((v.y + sqrt(maxf(disc, 0.0))) / (2.0 * a), 0.0)
	var p1: Vector3 = p0 + v * tg + Vector3(0.0, -a * tg * tg, 0.0)
	p1.y = rest
	var vy_contact: float = v.y - GRAVITY * tg
	var v2 := Vector3(0.35 * v.x, -0.3 * vy_contact, 0.35 * v.z)
	var dt2: float = maxf(2.0 * v2.y / GRAVITY, 1e-4)
	var c: Dictionary = {"node": mi, "p0": p0, "v": v, "w": w, "r0": r0, "s0": s, "tg": tg, "p1": p1, "v2": v2, "dt2": dt2,
		"rot_g": r0 + w * tg, "rest": rest}
	_debris.append(c)
	_eval_chunk(c, s)


## Hide the intact crates of a crate_stack prop and launch its planks plus a dust burst at the stack base.
func crate_break(prop: Node3D, dir: Vector3, power: float, s: float) -> void:
	var crates: Array = prop.get_meta("crates", [])
	var n_planks: int = int(prop.get_meta("planks", 10))
	var col: Color = prop.get_meta("crate_color", COL_CRATE)
	for cr: Node3D in crates:
		cr.visible = false
	var base: Vector3 = _local_of(prop)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(base) ^ hash(s)
	var mats: Array[StandardMaterial3D] = [_mat(col, 0.85), _mat(col.darkened(0.15), 0.85), _mat(COL_CRATE_EDGE, 0.85)]
	var plank := BoxMesh.new()
	plank.size = Vector3(0.55, 0.02, 0.07)
	var d: Vector3 = dir.normalized()
	for i: int in n_planks:
		var src: Vector3 = _local_of(crates[i % crates.size()]) if not crates.is_empty() else base + Vector3(0.0, 0.3, 0.0)
		var p0: Vector3 = src + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.15, 0.2), rng.randf_range(-0.2, 0.2))
		var v: Vector3 = d * rng.randf_range(1.5, 4.0) * power + Vector3(0.0, rng.randf_range(1.5, 3.5), 0.0) \
			+ Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
		var w := Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-6.0, 6.0), rng.randf_range(-9.0, 9.0))
		var r0 := Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)
		_spawn_chunk(plank, mats[i % mats.size()], p0, v, w, r0, s)
	burst("dust", base + Vector3(0.0, 0.05, 0.0), Vector3.UP, maxf(power, 1.0) * 1.3, s)


## Three daze stars orbiting the actor's head for story seconds [s0, s1].
func stars(actor: Node3D, s0: float, s1: float) -> void:
	if _star_mesh == null:
		_star_mesh = star_mesh(0.07, 0.03, 0.015)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#FFE14D")
	m.emission_enabled = true
	m.emission = Color("#FFD23A")
	m.emission_energy_multiplier = 2.5
	m.set_meta("vice_done", true)
	var nodes: Array[Node3D] = []
	for i: int in 3:
		var mi := MeshInstance3D.new()
		mi.name = _next_name("Star")
		mi.mesh = _star_mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		nodes.append(mi)
	_stars.append({"nodes": nodes, "actor": actor, "s0": s0, "s1": s1})


# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------
## Called every frame by the player with the story time s and the clock speed (story s per real s; 0 in a freeze).
func update(s: float, speed: float) -> void:
	var ss: float = speed / maxf(Engine.time_scale, 0.01)
	_last_ss = ss
	for i: int in range(_parts.size() - 1, -1, -1):
		var d: Dictionary = _parts[i]
		var p: CPUParticles3D = d["node"] if is_instance_valid(d["node"]) else null
		if p == null:
			_parts.remove_at(i)
			continue
		if s - float(d["s0"]) > float(d["life"]) + PARTICLE_GRACE:
			p.queue_free()
			_parts.remove_at(i)
			continue
		p.speed_scale = ss
	for i: int in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		if not is_instance_valid(f["node"]):
			_flashes.remove_at(i)
			continue
		if s - float(f["s0"]) > FLASH_LEN:
			(f["node"] as Node).queue_free()
			_flashes.remove_at(i)
			continue
		_eval_flash(f, s)
	for c: Dictionary in _debris:
		if is_instance_valid(c["node"]):
			_eval_chunk(c, s)
	for st: Dictionary in _stars:
		_eval_stars(st, s)


func live_count() -> int:
	var n: int = _parts.size() + _debris.size() + _flashes.size()
	for st: Dictionary in _stars:
		n += (st["nodes"] as Array).size()
	return n


func _eval_flash(f: Dictionary, s: float) -> void:
	var mi: MeshInstance3D = f["node"]
	var age: float = s - float(f["s0"])
	mi.visible = age >= 0.0 and age <= FLASH_LEN
	var u: float = clampf(age / FLASH_LEN, 0.0, 1.0)
	var m: StandardMaterial3D = f["mat"]
	m.albedo_color.a = 1.0 - u
	mi.scale = Vector3.ONE * float(f["size"]) * lerpf(0.6, 1.0, u)


## Debris position/rotation as a pure function of t = s - s0: arc to the first contact tg, one damped bounce of dt2, rest.
## During the bounce the x/z tilt eases to the nearest flat orientation so chunks and planks settle flat (no pop at rest).
func _eval_chunk(c: Dictionary, s: float) -> void:
	var mi: MeshInstance3D = c["node"]
	var t: float = s - float(c["s0"])
	mi.visible = t >= 0.0
	if t < 0.0:
		return
	var a: float = 0.5 * GRAVITY
	var tg: float = c["tg"]
	var w: Vector3 = c["w"]
	var r0: Vector3 = c["r0"]
	if t <= tg:
		mi.position = (c["p0"] as Vector3) + (c["v"] as Vector3) * t + Vector3(0.0, -a * t * t, 0.0)
		mi.rotation = r0 + w * t
		return
	var p1: Vector3 = c["p1"]
	var v2: Vector3 = c["v2"]
	var dt2: float = c["dt2"]
	var tt: float = minf(t - tg, dt2)
	var pos: Vector3 = p1 + v2 * tt + Vector3(0.0, -a * tt * tt, 0.0)
	var rest: float = c["rest"]
	pos.y = maxf(pos.y, rest)
	if t - tg >= dt2:
		pos.y = rest
	mi.position = pos
	var rg: Vector3 = c["rot_g"]
	var u: float = tt / dt2
	var flat := Vector3(snappedf(rg.x, PI), rg.y, snappedf(rg.z, PI))
	mi.rotation = Vector3(lerpf(rg.x, flat.x, u), r0.y + w.y * (tg + tt), lerpf(rg.z, flat.z, u))


func _eval_stars(st: Dictionary, s: float) -> void:
	var actor: Node3D = st["actor"] if is_instance_valid(st["actor"]) else null
	var on: bool = actor != null and s >= float(st["s0"]) and s <= float(st["s1"])
	var nodes: Array = st["nodes"]
	var head: Vector3 = Vector3.ZERO
	if on:
		# head in this node's local space; outside the tree (headless set-up) assume actor and CineFX share a parent space
		if actor.is_inside_tree() and is_inside_tree():
			var g: Vector3 = (actor as CineActor).bone_world("Head") if actor is CineActor \
				else actor.global_position + Vector3(0.0, 1.9, 0.0)
			head = to_local(g)
		else:
			head = actor.position + Vector3(0.0, 1.9, 0.0)
	for i: int in nodes.size():
		var n: Node3D = nodes[i]
		n.visible = on
		if not on:
			continue
		var ang: float = STAR_RATE * (s - float(st["s0"])) + float(i) * TAU / 3.0
		n.position = head + Vector3(0.0, 0.28, 0.0) + Vector3(cos(ang) * STAR_RADIUS, 0.0, sin(ang) * STAR_RADIUS)
		n.rotation = Vector3(0.0, -ang, 0.0)


func _local_of(n: Node3D) -> Vector3:
	if n.is_inside_tree() and is_inside_tree():
		return to_local(n.global_position)
	return n.position


# ---------------------------------------------------------------------------
# Code assets: textures, meshes, props
# ---------------------------------------------------------------------------
## White radial alpha blob: alpha = (1 - d)^power, d = distance from the centre / (size / 2). Cached per (size, power).
static func radial_texture(size: int = 64, power: float = 2.0) -> ImageTexture:
	var key: String = "%d:%s" % [size, power]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half: float = float(size) * 0.5
	var c: float = (float(size) - 1.0) * 0.5
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / half
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(clampf(1.0 - d, 0.0, 1.0), power)))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


## Flat 5-point star prism in the XY plane.
static func star_mesh(r_out: float, r_in: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i: int in 10:
		var ang: float = float(i) * TAU / 10.0
		var rr: float = r_out if i % 2 == 0 else r_in
		pts.append(Vector3(sin(ang) * rr, cos(ang) * rr, 0.0))
	for side: float in [1.0, -1.0]:
		var c := Vector3(0.0, 0.0, depth * 0.5 * side)
		for i: int in 10:
			var a: Vector3 = pts[i] + Vector3(0.0, 0.0, depth * 0.5 * side)
			var b: Vector3 = pts[(i + 1) % 10] + Vector3(0.0, 0.0, depth * 0.5 * side)
			st.set_normal(Vector3(0.0, 0.0, side))
			if side > 0.0:
				st.add_vertex(c)
				st.add_vertex(b)
				st.add_vertex(a)
			else:
				st.add_vertex(c)
				st.add_vertex(a)
				st.add_vertex(b)
	# rim
	for i: int in 10:
		var a2: Vector3 = pts[i]
		var b2: Vector3 = pts[(i + 1) % 10]
		var h := Vector3(0.0, 0.0, depth * 0.5)
		st.set_normal(((a2 + b2) * 0.5).normalized())
		st.add_vertex(a2 + h)
		st.add_vertex(b2 + h)
		st.add_vertex(b2 - h)
		st.add_vertex(a2 + h)
		st.add_vertex(b2 - h)
		st.add_vertex(a2 - h)
	return st.commit()


static func _mat(col: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


static func _box(parent: Node3D, nm: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Set-dressing props from plain meshes: crate_stack | scooter (opts "headlight": a lit SpotLight beam) | banana | phone
## (its screen glow also lights a small OmniLight). Origin on the ground.
static func build_prop(kind: String, opts: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = String(opts.get("name", kind.to_pascal_case()))
	match kind:
		"crate_stack":
			_build_crates(root, opts)
		"scooter":
			_build_scooter(root, opts)
		"banana":
			_build_banana(root)
		"phone":
			_build_phone(root)
		"helmet":
			_build_helmet(root, opts)
		_:
			push_warning("CineFX.build_prop: unknown kind '%s'" % kind)
	return root


static func _build_crates(root: Node3D, opts: Dictionary) -> void:
	var size: float = 0.62
	var col: Color = opts.get("color", COL_CRATE)
	var wood: StandardMaterial3D = _mat(col, 0.85)
	var edge: StandardMaterial3D = _mat(COL_CRATE_EDGE, 0.85)
	var places: Array[Vector3] = [Vector3(-0.33, size * 0.5, 0.0), Vector3(0.33, size * 0.5, 0.05), Vector3(0.02, size * 1.5, 0.02)]
	var yaws: Array[float] = [0.08, -0.12, 0.3]
	var crates: Array[Node3D] = []
	var e: float = 0.06
	var h: float = size * 0.5 - e * 0.5 + 0.005
	for i: int in places.size():
		var cr := Node3D.new()
		cr.name = "Crate%d" % i
		cr.position = places[i]
		cr.rotation.y = yaws[i]
		root.add_child(cr)
		_box(cr, "Body", Vector3.ONE * size, Vector3.ZERO, wood)
		# 12 darker edge battens
		for axis: int in 3:
			for sa: float in [-1.0, 1.0]:
				for sb: float in [-1.0, 1.0]:
					var sz := Vector3(e, e, e)
					var p := Vector3.ZERO
					match axis:
						0:
							sz.x = size + 0.01
							p = Vector3(0.0, sa * h, sb * h)
						1:
							sz.y = size + 0.01
							p = Vector3(sa * h, 0.0, sb * h)
						2:
							sz.z = size + 0.01
							p = Vector3(sa * h, sb * h, 0.0)
					_box(cr, "Edge", sz, p, edge)
		crates.append(cr)
	root.set_meta("crates", crates)
	root.set_meta("planks", 10)
	root.set_meta("crate_color", col)


static func _build_scooter(root: Node3D, opts: Dictionary) -> void:
	# length along Z (front = -Z), about 1.8 m from wheel edge to wheel edge
	var body_col: Color = opts.get("color", Color("#C8CCD2"))
	var body: StandardMaterial3D = _mat(body_col, 0.5)
	var dark: StandardMaterial3D = _mat(Color("#1C1C20"), 0.9)
	var seat: StandardMaterial3D = _mat(Color("#2A2422"), 0.8)
	var teal: StandardMaterial3D = _mat(Color("#1E9C93"), 0.7)
	var metal: StandardMaterial3D = _mat(Color("#7E848C"), 0.4)
	for z: float in [-0.68, 0.68]:
		var wh := MeshInstance3D.new()
		wh.name = "Wheel"
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.22
		cm.height = 0.11
		wh.mesh = cm
		wh.material_override = dark
		wh.position = Vector3(0.0, 0.22, z)
		wh.rotation = Vector3(0.0, 0.0, PI * 0.5)
		root.add_child(wh)
		var hub := MeshInstance3D.new()
		hub.name = "Hub"
		var hm := CylinderMesh.new()
		hm.top_radius = 0.1
		hm.bottom_radius = 0.1
		hm.height = 0.12
		hub.mesh = hm
		hub.material_override = metal
		hub.position = wh.position
		hub.rotation = wh.rotation
		root.add_child(hub)
	_box(root, "Floorboard", Vector3(0.34, 0.08, 0.7), Vector3(0.0, 0.3, -0.05), dark)
	_box(root, "RearBody", Vector3(0.38, 0.34, 0.75), Vector3(0.0, 0.52, 0.42), body)
	_box(root, "Seat", Vector3(0.32, 0.1, 0.62), Vector3(0.0, 0.74, 0.38), seat)
	_box(root, "FrontShield", Vector3(0.36, 0.62, 0.12), Vector3(0.0, 0.62, -0.5), body, Vector3(-0.25, 0.0, 0.0))
	_box(root, "Fork", Vector3(0.06, 0.6, 0.06), Vector3(0.0, 0.5, -0.66), metal, Vector3(-0.25, 0.0, 0.0))
	_box(root, "Stem", Vector3(0.07, 0.32, 0.07), Vector3(0.0, 0.98, -0.6), metal, Vector3(-0.25, 0.0, 0.0))
	_box(root, "Handlebar", Vector3(0.62, 0.05, 0.05), Vector3(0.0, 1.12, -0.56), metal)
	var lamp: MeshInstance3D = _box(root, "Headlight", Vector3(0.16, 0.1, 0.06), Vector3(0.0, 1.0, -0.7), _mat(Color("#F2EEDC"), 0.3))
	if bool(opts.get("headlight", false)):
		# parked with the headlight on: a warm key light on the fight at night (Task 7)
		var hm: StandardMaterial3D = lamp.material_override as StandardMaterial3D
		hm.emission_enabled = true
		hm.emission = Color("#FFF4D6")
		hm.emission_energy_multiplier = 3.0
		hm.set_meta("vice_done", true)
		var spot := SpotLight3D.new()
		spot.name = "HeadlightBeam"
		spot.light_color = Color("#FFF1CC")
		spot.light_energy = float(opts.get("headlight_energy", 3.0))
		spot.spot_range = 14.0
		spot.spot_angle = 34.0
		spot.shadow_enabled = true
		spot.position = Vector3(0.0, 1.0, -0.75)
		spot.rotation_degrees = Vector3(-9.0, 0.0, 0.0)
		root.add_child(spot)
	_box(root, "Rack", Vector3(0.36, 0.04, 0.4), Vector3(0.0, 0.8, 0.72), metal)
	_box(root, "DeliveryBox", Vector3(0.45, 0.45, 0.45), Vector3(0.0, 1.05, 0.72), teal)


static func _build_banana(root: Node3D) -> void:
	var yel: StandardMaterial3D = _mat(Color("#F2D23C"), 0.6)
	var cm := CapsuleMesh.new()
	cm.radius = 0.018
	cm.height = 0.18
	for i: int in 3:
		var yaw: float = float(i) * TAU / 3.0 + 0.3
		var mi := MeshInstance3D.new()
		mi.name = "Peel%d" % i
		mi.mesh = cm
		mi.material_override = yel
		var out := Vector3(sin(yaw), 0.0, cos(yaw))
		mi.position = out * 0.07 + Vector3(0.0, 0.018, 0.0)
		# lie flat, pointing outwards
		mi.basis = Basis.looking_at(out, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		root.add_child(mi)


## A courier's half-shell helmet (as CharacterBuilder's, about 0.25 m across), dome up, visor toward -Z; origin at the rim
## centre. opts "color".
static func _build_helmet(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#F1C40F"))
	var shell: StandardMaterial3D = _mat(col, 0.25)
	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	var sm := SphereMesh.new()
	sm.radius = 0.126
	sm.height = 0.126
	sm.is_hemisphere = true
	dome.mesh = sm
	dome.material_override = shell
	dome.scale = Vector3(1.0, 1.05, 1.02)
	root.add_child(dome)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.128
	cm.bottom_radius = 0.128
	cm.height = 0.03
	rim.mesh = cm
	rim.material_override = shell
	rim.position = Vector3(0.0, -0.01, 0.0)
	root.add_child(rim)
	_box(root, "Visor", Vector3(0.21, 0.012, 0.08), Vector3(0.0, -0.005, -0.15), _mat(Color("#111318"), 0.2))
	for sx: float in [-1.0, 1.0]:
		_box(root, "Strap", Vector3(0.01, 0.12, 0.006), Vector3(sx * 0.09, -0.07, -0.02), _mat(Color("#222222"), 0.8))


static func _build_phone(root: Node3D) -> void:
	var body := _box(root, "Body", Vector3(0.075, 0.008, 0.15), Vector3(0.0, 0.004, 0.0), _mat(Color("#141418"), 0.3))
	body.set_meta("phone_body", true)
	var scr := MeshInstance3D.new()
	scr.name = "Screen"
	var q := QuadMesh.new()
	q.size = Vector2(0.068, 0.138)
	scr.mesh = q
	scr.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	scr.position = Vector3(0.0, 0.0085, 0.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#0B1030")
	sm.roughness = 0.2
	sm.emission_enabled = false
	sm.emission = Color("#BFE3FF")
	sm.set_meta("vice_done", true)
	scr.material_override = sm
	root.add_child(scr)
	root.set_meta("screen_mat", sm)
	# soft blue spill on the ground while the screen is lit (a 15 cm prop is otherwise lost at night)
	var ol := OmniLight3D.new()
	ol.name = "ScreenGlow"
	ol.light_color = Color("#BFE3FF")
	ol.light_energy = 0.9
	ol.omni_range = 1.4
	ol.position = Vector3(0.0, 0.12, 0.0)
	ol.visible = false
	root.add_child(ol)
	root.set_meta("glow_light", ol)


## Light or darken a prop's screen (phone).
static func set_prop_glow(prop: Node3D, on: bool) -> void:
	var m: StandardMaterial3D = prop.get_meta("screen_mat", null)
	if m == null:
		return
	m.emission_enabled = on
	m.emission_energy_multiplier = 2.0
	var ol: OmniLight3D = prop.get_meta("glow_light", null)
	if ol:
		ol.visible = on
