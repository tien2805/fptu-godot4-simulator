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
## Scooter headlight (owner: the road patch looked pasted on): dim energy, soft angular falloff (spot_angle_attenuation),
## haze cones [width of the beam, alpha] and dust mote alpha - kept faint so the actors never blow out.
const HEADLIGHT_ENERGY: float = 1.1
const HEADLIGHT_EDGE: float = 3.0
const HAZE_LEN: float = 4.5
const HAZE_LAYERS: Array = [[0.45, 0.03], [0.7, 0.022], [0.95, 0.015]]
const DUST_ALPHA: float = 0.28
## Rim centre height in CharacterBuilder._build_helmet's frame (head centre 0.12 + rim offset 0.01).
const HELMET_RIM_Y: float = 0.13
## Prop kinds build_prop knows (timeline props and held props).
const PROP_KINDS: Array[String] = ["crate_stack", "scooter", "banana", "phone", "helmet",
	# story Phase A2 (Day 0 cinematics): lobby bench, the protagonist's backpack (glows red inside via glow_at), the planted
	# smart glasses, an instant-noodle cup, the E1 photo card, a lamp (opts "flicker": [[s0, s1], ...] story windows, see
	# CinePlayer), a fluffy sheep mask and a white face mask (both held on the Head bone)
	"bench", "backpack", "glasses", "noodles", "photo", "lamp", "sheep_mask", "face_mask",
	# jump scare v2: the creepier sheep mask of the scares (ScareFace.build_scare_mask), held on the Head bone
	"scare_mask",
	# story Phase B (Days 1 and 4): Chú Bảy's shiba (StoryShiba, opts "anim"), canteen furniture and improvised weapons
	# (table, stool, chair, tray, soup_pot, counter), Mr.T's laptop (screen glow via glow_at), the "THI HỘ BAO ĐẬU" flyer
	# stand, and the night corridor set (walls, ceiling, tube lamps that flicker like "lamp": opts "flicker")
	"shiba", "table", "stool", "chair", "tray", "soup_pot", "counter", "laptop", "flyer", "corridor",
	# W6 fights: lunch plugged in a clone's sheep-mask eye holes (seg_d4_brawl; held on Head like the mask), the yard
	# crane's hook on its cable (seg_d3_boss: origin at the block's centre, the cable up to opts "cable" m, the J hook below
	# opening toward +Z)
	"food_eyes", "crane_hook",
	# Dolly's tells as held props (cuff on Wrist.L, keychain on Hips) and a lobby front with glass doors (cine_d4)
	"wool_cuff", "sheep_keychain", "lobby_wall",
	# story Phase C (Days 2, 3, 5): wearables, hand props, sets and animated props, built by CinePropsC (see its header;
	# this list = CinePropsC.KINDS, kept literal so it stays a constant)
	"wolf_helmet", "wolf_mask", "fox_mask", "gold_shades", "round_glasses", "headphones", "key_lanyard", "turtleneck",
	"hawaii_print", "belly", "energy_drink", "cigar_vape", "coffee_cup", "party_horn", "usb", "katana", "katana_blade",
	"keyboard", "server_panel", "staff", "bike_mirror", "chain", "small_crate", "pallet", "pillar", "bridge_deck", "rope",
	"motorbike", "container", "mannequins", "forklift", "server_rack", "server_room", "monitor_wall", "stonks_screen", "fire",
	"keynote", "desk",
	# Phase D Day 6 (plan 2026-11-01-w4-day6.md): Thị Lọ's wearables, the shop, the back room, the boats and the canal set
	# pieces, built by CinePropsD6 (this list = CinePropsD6.KINDS, kept literal so it stays a constant)
	"pink_bob", "lo_shades", "leopard_print", "cash_bag", "ledger", "milk_tea", "powder_puff", "uniform_pack", "speedboat",
	"jet_ski", "backroom", "doll_shelf", "music_box", "sheep_doll", "vanity", "safe", "tea_shop", "canal_bank", "low_bridge",
	"fish_net", "sampan", "pier_wall", "billboard", "fireworks", "bulb", "house_row", "cash_wad",
	# w4-endings: the ending cinematics' props, built by CinePropsE (this list = CinePropsE.KINDS)
	"end_billboard", "end_helicopter", "police_car", "box", "belt", "scholarship", "certificate", "hearing_set", "canal", "sign",
	"boat", "lift_frame", "lift_door", "dossier",
	# W6 phase2 (seg_d7_phase2): Lùm Văn Lọ's antique urn, wide-mouthed so it ends up over a head (W6 phase2 block below)
	"antique_urn",
	# Phase D Day 7 (w4-day7): CinePropsD7.KINDS (Lọ's gear, the saber, the gallery and roof props)
	"gold_glasses", "pink_collar", "gold_chain", "saber", "vase", "plinth", "speaker", "laser_emitter", "breaker",
	"exam_server", "helicopter", "academy_sign", "flashlight", "heli_rotor", "searchlight", "rain", "gallery_hall", "roof_deck"]

var _serial: int = 0
var _parts: Array[Dictionary] = []     # {node: CPUParticles3D, s0, life}
var _debris: Array[Dictionary] = []    # {node, p0, v, w, r0, s0, tg, p1, v2, dt2, rot_g, rest}
var _flashes: Array[Dictionary] = []   # {node, mat, s0, size}
var _stars: Array[Dictionary] = []     # {nodes: Array[Node3D], actor, s0, s1}
var _last_ss: float = 1.0              # particle speed_scale of the last update() (new bursts start at it)
var _ambient: Array[CPUParticles3D] = []   # looping prop particles (headlight dust) that follow the clock too

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


## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
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


## Shared with Phase W (called by name from its scripts): signature frozen, do not rename.
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
## Let looping prop particles under root (meta "cine_ambient", e.g. the headlight dust) follow the cinematic clock.
func adopt_ambient(root: Node) -> void:
	for n: Node in root.find_children("*", "CPUParticles3D", true, false):
		if n.has_meta("cine_ambient"):
			_ambient.append(n as CPUParticles3D)


func update(s: float, speed: float) -> void:
	var ss: float = speed / maxf(Engine.time_scale, 0.01)
	_last_ss = ss
	for ap: CPUParticles3D in _ambient:
		if is_instance_valid(ap):
			ap.speed_scale = ss
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
		"antique_urn":   # W6 phase2 block
			_build_antique_urn(root)
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
		"bench":
			_build_bench(root)
		"backpack":
			_build_backpack(root)
		"glasses":
			_build_glasses(root)
		"noodles":
			_build_noodles(root)
		"photo":
			_build_photo(root)
		"lamp":
			_build_lamp(root, opts)
		"sheep_mask":
			_build_sheep_mask(root)
		"scare_mask":
			root.add_child(ScareFace.build_scare_mask())
		"face_mask":
			_build_face_mask(root)
		"shiba":
			var dog := StoryShiba.new()
			dog.name = "Dog"
			root.add_child(dog)
			root.set_meta("shiba", dog)
		"table":
			_build_table(root, opts)
		"stool":
			_build_stool(root, opts)
		"chair":
			_build_chair(root, opts)
		"tray":
			_build_tray(root, opts)
		"soup_pot":
			_build_soup_pot(root)
		"food_eyes":
			_build_food_eyes(root)
		"crane_hook":
			_build_crane_hook(root, opts)
		"counter":
			_build_counter(root, opts)
		"laptop":
			_build_laptop(root)
		"flyer":
			_build_flyer(root, opts)
		"corridor":
			_build_corridor(root, opts)
		"wool_cuff":
			_build_wool_cuff(root)
		"sheep_keychain":
			_build_sheep_keychain(root)
		"lobby_wall":
			_build_lobby_wall(root, opts)
		_:
			if CinePropsC.has(kind):
				CinePropsC.build(kind, root, opts)
			elif CinePropsD6.has(kind):
				CinePropsD6.build(kind, root, opts)
			elif CinePropsE.has(kind):
				CinePropsE.build(kind, root, opts)
			elif CinePropsD7.has(kind):   # Day 7 (w4-day7)
				CinePropsD7.build(kind, root, opts)
			else:
				push_warning("CineFX.build_prop: unknown kind '%s'" % kind)
	return root


static func _build_crates(root: Node3D, opts: Dictionary) -> void:
	var size: float = 0.62
	var col: Color = opts.get("color", COL_CRATE)
	var wood: StandardMaterial3D = _mat(col, 0.85)
	var edge: StandardMaterial3D = _mat(COL_CRATE_EDGE, 0.85)
	if bool(opts.get("broken", false)):
		# the stack after crate_break (a later scene): its planks lie flat around the spot, seeded, no intact crate
		var rng := RandomNumberGenerator.new()
		rng.seed = int(opts.get("seed", 3))
		var pm := BoxMesh.new()
		pm.size = Vector3(0.55, 0.02, 0.07)
		for i: int in 10:
			var pl := MeshInstance3D.new()
			pl.name = "Plank%d" % i
			pl.mesh = pm
			pl.material_override = wood if i % 3 != 2 else edge
			var a: float = rng.randf_range(0.0, TAU)
			var r: float = rng.randf_range(0.25, 1.1)
			pl.position = Vector3(cos(a) * r, 0.011 + 0.021 * (i % 2), sin(a) * r)
			pl.rotation.y = rng.randf_range(0.0, TAU)
			root.add_child(pl)
		return
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
		# a dim pool with a soft angular and distance falloff (no hard-edged disc on the road), plus faint haze and dust
		var spot := SpotLight3D.new()
		spot.name = "HeadlightBeam"
		spot.light_color = Color("#FFF1CC")
		spot.light_energy = float(opts.get("headlight_energy", HEADLIGHT_ENERGY))
		spot.spot_range = 11.0
		spot.spot_angle = 38.0
		spot.spot_angle_attenuation = HEADLIGHT_EDGE
		spot.spot_attenuation = 1.6
		spot.shadow_enabled = true
		spot.position = Vector3(0.0, 1.0, -0.75)
		spot.rotation_degrees = Vector3(-9.0, 0.0, 0.0)
		root.add_child(spot)
		_build_haze(root, spot)
	_box(root, "Rack", Vector3(0.36, 0.04, 0.4), Vector3(0.0, 0.8, 0.72), metal)
	_box(root, "DeliveryBox", Vector3(0.45, 0.45, 0.45), Vector3(0.0, 1.05, 0.72), teal)


## Night haze in the headlight: three nested additive cones (alpha fading toward the far end and at the lamp, soft where
## they meet the ground or a body) and slow dust motes drifting inside the beam (clock-driven through adopt_ambient).
static func _build_haze(root: Node3D, spot: SpotLight3D) -> void:
	var haze := Node3D.new()
	haze.name = "HeadlightHaze"
	haze.transform = spot.transform
	root.add_child(haze)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.65, 0.92, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 64
	# CylinderMesh sides span uv.v 0 (top = the wide far end) .. 0.5 (bottom = the lamp); uv1_scale y 2 maps them to 0..1 and
	# the fill runs from v 1 (lamp, gradient offset 0) to v 0 (far end): 0 at the lens, peak ~2.9 m out, 0 at HAZE_LEN
	gt.fill_from = Vector2(0.0, 1.0)
	gt.fill_to = Vector2(0.0, 0.0)
	var half: float = deg_to_rad(spot.spot_angle)
	for i: int in HAZE_LAYERS.size():
		var k: float = HAZE_LAYERS[i][0]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.albedo_color = Color(1.0, 0.94, 0.78, float(HAZE_LAYERS[i][1]))
		m.albedo_texture = gt
		m.uv1_scale = Vector3(1.0, 2.0, 1.0)
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.6
		m.set_meta("vice_done", true)
		var cm := CylinderMesh.new()
		cm.height = HAZE_LEN
		cm.top_radius = tan(half * k) * HAZE_LEN
		cm.bottom_radius = 0.05
		cm.cap_top = false
		cm.cap_bottom = false
		cm.radial_segments = 24
		var mi := MeshInstance3D.new()
		mi.name = "Haze%d" % i
		mi.mesh = cm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)        # mesh +Y (the wide end) points down the beam (-Z)
		mi.position = Vector3(0.0, 0.0, -HAZE_LEN * 0.5)
		haze.add_child(mi)
	var dust := CPUParticles3D.new()
	dust.name = "HeadlightDust"
	dust.set_meta("cine_ambient", true)
	dust.amount = 48
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = true
	dust.use_fixed_seed = true
	dust.seed = 4242
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.45, 0.3, 1.4)
	dust.position = Vector3(0.0, 0.0, -1.8)
	dust.direction = Vector3(0.0, 0.2, 0.0)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.07
	dust.gravity = Vector3(0.0, -0.004, 0.0)
	dust.scale_amount_min = 0.012
	dust.scale_amount_max = 0.026
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	dg.colors = PackedColorArray([Color(1, 0.95, 0.8, 0.0), Color(1, 0.95, 0.8, DUST_ALPHA), Color(1, 0.95, 0.8, DUST_ALPHA), Color(1, 0.95, 0.8, 0.0)])
	dust.color_ramp = dg
	dust.mesh = _particle_mesh(true)
	haze.add_child(dust)
	dust.emitting = true


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


## A courier's helmet as worn, built by the same builders as the characters' (CharacterBuilder._build_helmet; in the vice
## style fitted with PS2Head's scale and crescent visor, without the chin straps that belong to the head), dome up, visor
## toward -Z, origin at the rim centre (about 0.25 m across). opts "color".
static func _build_helmet(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#F1C40F"))
	var fit := Node3D.new()
	fit.name = "HelmetFit"
	root.add_child(fit)
	CharacterBuilder._build_helmet(fit, col, 1.0)
	if CharacterBuilder.ps2:
		fit.scale = PS2Head.HELMET_FIT_SCALE
		PS2Head._build_helmet_visor(fit, col, 1.0)
		for ch: Node in fit.get_children():
			var mi := ch as MeshInstance3D
			if mi != null and mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.y >= 0.1:
				fit.remove_child(mi)
				mi.free()
	fit.position = Vector3(0.0, -HELMET_RIM_Y * fit.scale.y, 0.0)


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


# ---------------------------------------------------------------------------
# Story Phase A2 props (plain meshes, code colours only)
# ---------------------------------------------------------------------------
static func _sphere(parent: Node3D, nm: String, r: float, pos: Vector3, mat: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, nm: String, r0: float, r1: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var cm := CylinderMesh.new()
	cm.top_radius = r0
	cm.bottom_radius = r1
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.set_meta("vice_done", true)
	return m


## Lobby bench 1.6 m: slatted seat 0.45 m high, back rest on +Z (sitters face -Z).
static func _build_bench(root: Node3D) -> void:
	var wood: StandardMaterial3D = _mat(Color("#B07A4A"), 0.8)
	var metal: StandardMaterial3D = _mat(Color("#3C4048"), 0.4)
	for i: int in 3:
		_box(root, "Slat%d" % i, Vector3(1.6, 0.035, 0.12), Vector3(0.0, 0.44, -0.15 + 0.14 * i), wood)
	for j: int in 2:
		_box(root, "BackSlat%d" % j, Vector3(1.6, 0.1, 0.03), Vector3(0.0, 0.62 + 0.16 * j, 0.24), wood, Vector3(-0.15, 0.0, 0.0))
	for sx: float in [-0.7, 0.7]:
		_box(root, "Leg", Vector3(0.05, 0.44, 0.5), Vector3(sx, 0.22, 0.03), metal)


## Black backpack; a red emissive seam + red light switched on by the prop's glow_at (the planted glasses inside).
static func _build_backpack(root: Node3D) -> void:
	var cloth: StandardMaterial3D = _mat(Color("#1E1E22"), 0.9)
	_box(root, "Bag", Vector3(0.32, 0.42, 0.18), Vector3(0.0, 0.21, 0.0), cloth)
	_box(root, "Pocket", Vector3(0.24, 0.18, 0.05), Vector3(0.0, 0.14, -0.11), _mat(Color("#2A2A30"), 0.9))
	var seam := StandardMaterial3D.new()
	seam.albedo_color = Color("#3A0A0A")
	seam.emission = Color("#FF2030")
	seam.emission_enabled = false
	seam.set_meta("vice_done", true)
	_box(root, "Seam", Vector3(0.26, 0.02, 0.02), Vector3(0.0, 0.42, -0.06), seam)
	root.set_meta("screen_mat", seam)
	var ol := OmniLight3D.new()
	ol.name = "BagGlow"
	ol.light_color = Color("#FF2030")
	ol.light_energy = 2.2
	ol.omni_range = 2.2
	ol.position = Vector3(0.0, 0.5, -0.1)
	ol.visible = false
	root.add_child(ol)
	root.set_meta("glow_light", ol)


## Smart glasses: dark lenses, black frame, a tiny red LED on the temple.
static func _build_glasses(root: Node3D) -> void:
	var frame: StandardMaterial3D = _mat(Color("#101014"), 0.3)
	var lens: StandardMaterial3D = _mat(Color("#203040"), 0.1)
	for sx: float in [-0.035, 0.035]:
		_box(root, "Lens", Vector3(0.05, 0.03, 0.006), Vector3(sx, 0.0, 0.0), lens)
	_box(root, "Bridge", Vector3(0.14, 0.008, 0.008), Vector3(0.0, 0.016, 0.0), frame)
	for sx2: float in [-0.068, 0.068]:
		_box(root, "Temple", Vector3(0.006, 0.008, 0.12), Vector3(sx2, 0.012, 0.06), frame)
	_box(root, "Led", Vector3(0.008, 0.008, 0.008), Vector3(0.072, 0.016, 0.02), _glow_mat(Color("#FF2030"), 3.0))


## Instant-noodle cup with a red band and chopsticks.
static func _build_noodles(root: Node3D) -> void:
	_cyl(root, "Cup", 0.05, 0.038, 0.1, Vector3(0.0, 0.05, 0.0), _mat(Color("#F4F1EA"), 0.7))
	_cyl(root, "Band", 0.049, 0.045, 0.03, Vector3(0.0, 0.07, 0.0), _mat(Color("#D7262E"), 0.6))
	_cyl(root, "Noodles", 0.046, 0.046, 0.01, Vector3(0.0, 0.098, 0.0), _mat(Color("#E9C46A"), 0.8))
	var stick: StandardMaterial3D = _mat(Color("#D9B98A"), 0.7)
	for sx: float in [-0.008, 0.008]:
		_box(root, "Chopstick", Vector3(0.005, 0.2, 0.005), Vector3(sx, 0.16, 0.01), stick, Vector3(0.25, 0.0, 0.0))


## The E1 photo card: white print, dark photo of a hand with a glowing blue earbud.
static func _build_photo(root: Node3D) -> void:
	_box(root, "Card", Vector3(0.13, 0.004, 0.1), Vector3.ZERO, _mat(Color("#F7F7F2"), 0.6))
	_box(root, "Print", Vector3(0.11, 0.002, 0.075), Vector3(0.0, 0.003, -0.005), _mat(Color("#262A36"), 0.5))
	_sphere(root, "Earbud", 0.009, Vector3(0.015, 0.006, -0.01), _glow_mat(Color("#3FA9FF"), 2.5))


## Lobby lamp post: pole, warm bulb, OmniLight. opts "flicker" windows drive set_lamp() from CinePlayer.
static func _build_lamp(root: Node3D, opts: Dictionary) -> void:
	_cyl(root, "Pole", 0.03, 0.04, 2.6, Vector3(0.0, 1.3, 0.0), _mat(Color("#2E3238"), 0.4))
	var bulb: StandardMaterial3D = _glow_mat(Color("#FFD27A"), 2.5)
	_sphere(root, "Bulb", 0.12, Vector3(0.0, 2.7, 0.0), bulb)
	var ol := OmniLight3D.new()
	ol.name = "LampLight"
	ol.light_color = Color(opts.get("color", Color("#FFD9A0")))
	ol.light_energy = float(opts.get("energy", 2.4))
	ol.omni_range = float(opts.get("range", 7.0))
	ol.position = Vector3(0.0, 2.6, 0.0)
	root.add_child(ol)
	root.set_meta("lamp_light", ol)
	root.set_meta("lamp_bulb", bulb)


## true unless story time s falls inside a flicker window and the deterministic stutter has the light off (seekable).
static func lamp_on(s: float, windows: Array) -> bool:
	for w: Variant in windows:
		var a: Array = w
		if s >= float(a[0]) and s < float(a[1]):
			return int(floor(s * 17.0)) % 3 != 1 and int(floor(s * 5.0)) % 4 != 2
	return true


## true when story time s lies inside one of the [s0, s1) windows (Phase B lamp blackouts: prop opts "dark").
static func in_windows(s: float, windows: Array) -> bool:
	for w: Variant in windows:
		var a: Array = w
		if s >= float(a[0]) and s < float(a[1]):
			return true
	return false


## Lamp on / off without switching shader variants (review A2-R3: toggling emission_enabled can hitch on the first flicker).
static func set_lamp(prop: Node3D, on: bool) -> void:
	var ol: OmniLight3D = prop.get_meta("lamp_light") if prop.has_meta("lamp_light") else null   # (a null default errors)
	if ol:
		ol.visible = on
	for l: OmniLight3D in prop.get_meta("lamp_lights", []):
		l.visible = on
	var b: StandardMaterial3D = prop.get_meta("lamp_bulb", null)
	if b:
		b.emission_energy_multiplier = 2.5 if on else 0.0


## Fluffy white sheep mask (Cừu Dolly's clones): wool puffs, dark muzzle, ears; centred on the head (Head bone + offset).
static func _build_sheep_mask(root: Node3D) -> void:
	var wool: StandardMaterial3D = _mat(Color("#F4F1EA"), 1.0)
	var face: StandardMaterial3D = _mat(Color("#2B2622"), 0.7)
	var puffs: Array[Vector3] = [Vector3(0, 0.1, 0), Vector3(-0.08, 0.07, 0.02), Vector3(0.08, 0.07, 0.02), Vector3(0, 0.05, 0.08),
		Vector3(-0.06, 0.13, 0.05), Vector3(0.06, 0.13, 0.05), Vector3(0, 0.15, -0.03)]
	for i: int in puffs.size():
		_sphere(root, "Puff%d" % i, 0.085, puffs[i], wool)
	_sphere(root, "Muzzle", 0.075, Vector3(0.0, -0.005, -0.09), face, Vector3(0.9, 1.35, 0.8))   # down over the chin
	var eye: StandardMaterial3D = _glow_mat(Color("#FFFFFF"), 1.2)
	for sx: float in [-0.028, 0.028]:
		_sphere(root, "Eye", 0.012, Vector3(sx, 0.06, -0.15), eye)
		_box(root, "Ear", Vector3(0.08, 0.025, 0.04), Vector3(sx * 4.0, 0.09, -0.02), face, Vector3(0.0, 0.0, signf(sx) * -0.5))


## White face mask (Phúc's sheet mask): a pale oval in front of the face with eye and mouth holes.
static func _build_face_mask(root: Node3D) -> void:
	var white: StandardMaterial3D = _mat(Color("#FBFBF7"), 0.9)
	_sphere(root, "Mask", 0.1, Vector3(0.0, 0.05, -0.1), white, Vector3(0.95, 1.25, 0.25))
	var hole: StandardMaterial3D = _mat(Color("#1A1A1A"), 0.9)
	for sx: float in [-0.035, 0.035]:
		_sphere(root, "EyeHole", 0.016, Vector3(sx, 0.08, -0.126), hole, Vector3(1.4, 0.8, 0.4))
	_sphere(root, "MouthHole", 0.014, Vector3(0.0, 0.0, -0.126), hole, Vector3(2.0, 0.7, 0.4))


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


# ---------------------------------------------------------------------------
# Story Phase B props (plain meshes, code colours only; origin on the ground, front toward -Z)
# ---------------------------------------------------------------------------
## Breakable furniture: the pieces go in the "crates" metas so crate_break() hides them and throws planks.
static func _breakable(root: Node3D, pieces: Array[Node3D], planks: int, col: Color) -> void:
	root.set_meta("crates", pieces)
	root.set_meta("planks", planks)
	root.set_meta("crate_color", col)


## Canteen table 1.4 x 0.8 m, top at 0.75 m: laminate top, steel legs. opts "color" (top).
static func _build_table(root: Node3D, opts: Dictionary) -> void:
	var top_col: Color = opts.get("color", Color("#D9CFBE"))
	var piece := Node3D.new()
	piece.name = "TablePiece"
	root.add_child(piece)
	_box(piece, "Top", Vector3(1.4, 0.04, 0.8), Vector3(0.0, 0.73, 0.0), _mat(top_col, 0.6))
	var steel: StandardMaterial3D = _mat(Color("#8C939C"), 0.35)
	for sx: float in [-0.62, 0.62]:
		for sz: float in [-0.32, 0.32]:
			_box(piece, "Leg", Vector3(0.04, 0.71, 0.04), Vector3(sx, 0.355, sz), steel)
	_breakable(root, [piece], 8, top_col.darkened(0.2))


## Round canteen stool, seat at 0.45 m (sit_bench height).
static func _build_stool(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#C0392B"))
	_cyl(root, "Seat", 0.17, 0.17, 0.04, Vector3(0.0, 0.43, 0.0), _mat(col, 0.5))
	_cyl(root, "Post", 0.025, 0.025, 0.41, Vector3(0.0, 0.205, 0.0), _mat(Color("#8C939C"), 0.35))
	_cyl(root, "Foot", 0.14, 0.16, 0.02, Vector3(0.0, 0.01, 0.0), _mat(Color("#6E747C"), 0.4))


## Plastic canteen chair (seat 0.45 m, back rest on +Z); breakable. opts "held": origin at the seat centre (the hands grip
## the seat when it is held two-handed).
static func _build_chair(root: Node3D, opts: Dictionary) -> void:
	var col: Color = opts.get("color", Color("#2E86C1"))
	var plastic: StandardMaterial3D = _mat(col, 0.45)
	var piece := Node3D.new()
	piece.name = "ChairPiece"
	root.add_child(piece)
	if bool(opts.get("held", false)):
		piece.position = Vector3(0.0, -0.45, 0.0)
	_box(piece, "Seat", Vector3(0.44, 0.04, 0.42), Vector3(0.0, 0.45, 0.0), plastic)
	_box(piece, "Back", Vector3(0.44, 0.4, 0.04), Vector3(0.0, 0.68, 0.2), plastic, Vector3(-0.12, 0.0, 0.0))
	for sx: float in [-0.19, 0.19]:
		for sz: float in [-0.18, 0.18]:
			_box(piece, "Leg", Vector3(0.035, 0.45, 0.035), Vector3(sx, 0.225, sz), plastic)
	_breakable(root, [piece], 9, col)


## Steel canteen tray 0.42 x 0.3 m (origin at its centre) with optional food (opts "food": rice bowl, soup cup, chopsticks).
static func _build_tray(root: Node3D, opts: Dictionary) -> void:
	var steel: StandardMaterial3D = _mat(Color("#B8BEC6"), 0.25)
	steel.metallic = 0.6
	_box(root, "Plate", Vector3(0.42, 0.012, 0.3), Vector3.ZERO, steel)
	for sz: float in [-0.145, 0.145]:
		_box(root, "Rim", Vector3(0.42, 0.025, 0.012), Vector3(0.0, 0.01, sz), steel)
	for sx: float in [-0.205, 0.205]:
		_box(root, "Rim", Vector3(0.012, 0.025, 0.3), Vector3(sx, 0.01, 0.0), steel)
	if bool(opts.get("food", false)):
		_cyl(root, "Bowl", 0.06, 0.04, 0.05, Vector3(-0.1, 0.03, 0.02), _mat(Color("#F4F1EA"), 0.6))
		_sphere(root, "Rice", 0.05, Vector3(-0.1, 0.055, 0.02), _mat(Color("#FBFAF5"), 0.9), Vector3(1.0, 0.45, 1.0))
		_cyl(root, "Soup", 0.05, 0.045, 0.045, Vector3(0.1, 0.03, -0.03), _mat(Color("#E9C46A"), 0.5))
		_box(root, "Sticks", Vector3(0.24, 0.006, 0.012), Vector3(0.02, 0.012, 0.11), _mat(Color("#D9B98A"), 0.7))


## Lunch in a sheep mask's eye holes (seg_d4_brawl: the full tray shoved into a clone's face): a rice blob over each
## glowing eye, a curry smear under them, a noodle strand hanging off; held on the Head bone with the mask's offset, so
## the mask's eyes sit at (+-0.028, 0.06, -0.15) in this frame.
static func _build_food_eyes(root: Node3D) -> void:
	var rice: StandardMaterial3D = _mat(Color("#FBFAF5"), 0.9)
	for sx: float in [-0.028, 0.028]:
		_sphere(root, "Rice", 0.024, Vector3(sx, 0.062, -0.156), rice, Vector3(1.15, 0.95, 0.6))
		_sphere(root, "Grain", 0.008, Vector3(sx * 1.8, 0.04, -0.153), rice)
	_sphere(root, "Curry", 0.03, Vector3(0.01, 0.026, -0.152), _mat(Color("#D9962B"), 0.6), Vector3(1.6, 0.5, 0.3))
	_box(root, "Noodle", Vector3(0.006, 0.09, 0.006), Vector3(0.036, 0.0, -0.156), _mat(Color("#F2D98C"), 0.7), Vector3(0.0, 0.0, 0.25))


## The container-yard crane's hook (seg_d3_boss): a yellow hook block (origin at its centre), a steel shank and a J hook
## below it (bottom 0.45 m under the origin, the tip rising on the +Z side), the cable straight up (opts "cable" m, default
## 5.75; tests skip it as a contact, it is never in the way).
static func _build_crane_hook(root: Node3D, opts: Dictionary) -> void:
	var steel: StandardMaterial3D = _mat(Color("#55595F"), 0.35)
	steel.metallic = 0.6
	_box(root, "HookBlock", Vector3(0.24, 0.3, 0.16), Vector3.ZERO, _mat(Color("#F2B705"), 0.5))
	_box(root, "HookStripe", Vector3(0.245, 0.06, 0.165), Vector3(0.0, 0.06, 0.0), _mat(Color("#1E1F22"), 0.6))
	_box(root, "HookShank", Vector3(0.04, 0.26, 0.04), Vector3(0.0, -0.28, 0.0), steel)
	_box(root, "HookBase", Vector3(0.04, 0.04, 0.18), Vector3(0.0, -0.43, 0.07), steel)
	_box(root, "HookTip", Vector3(0.04, 0.12, 0.04), Vector3(0.0, -0.35, 0.14), steel)
	var ln: float = float(opts.get("cable", 5.75))
	_cyl(root, "Cable", 0.012, 0.012, ln, Vector3(0.0, 0.15 + ln * 0.5, 0.0), steel)


## Empty steel soup pot (cold and empty: no burns, no gore), two side handles; origin at the bottom centre.
static func _build_soup_pot(root: Node3D) -> void:
	var steel: StandardMaterial3D = _mat(Color("#A9B0B8"), 0.3)
	steel.metallic = 0.7
	_cyl(root, "Pot", 0.17, 0.16, 0.24, Vector3(0.0, 0.12, 0.0), steel)
	_cyl(root, "Lip", 0.18, 0.18, 0.02, Vector3(0.0, 0.24, 0.0), steel)
	for sx: float in [-0.2, 0.2]:
		_box(root, "Handle", Vector3(0.05, 0.025, 0.08), Vector3(sx, 0.2, 0.0), _mat(Color("#2B2B2B"), 0.5))


## Serving counter: a long steel-front box with a laminate top (length opts "len", default 2.4 m), 0.95 m high.
static func _build_counter(root: Node3D, opts: Dictionary) -> void:
	var ln: float = float(opts.get("len", 2.4))
	_box(root, "Front", Vector3(ln, 0.9, 0.65), Vector3(0.0, 0.45, 0.0), _mat(Color("#9AA3AD"), 0.35))
	_box(root, "Top", Vector3(ln + 0.06, 0.05, 0.72), Vector3(0.0, 0.925, 0.0), _mat(Color("#E8E2D6"), 0.6))
	_box(root, "Band", Vector3(ln + 0.01, 0.12, 0.01), Vector3(0.0, 0.7, -0.33), _mat(Color("#F37021"), 0.6))


## Open laptop (base 0.32 x 0.22 m, screen hinged at the back, ~105 degrees); the screen glows through glow_at.
static func _build_laptop(root: Node3D) -> void:
	var shell: StandardMaterial3D = _mat(Color("#2C2F36"), 0.35)
	_box(root, "Base", Vector3(0.32, 0.018, 0.22), Vector3(0.0, 0.009, 0.0), shell)
	_box(root, "Keys", Vector3(0.28, 0.004, 0.12), Vector3(0.0, 0.019, -0.02), _mat(Color("#15171C"), 0.6))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0.0, 0.018, 0.11)
	lid.rotation = Vector3(deg_to_rad(15.0), 0.0, 0.0)   # leans back, away from the user: ~105 degrees open
	root.add_child(lid)
	_box(lid, "Back", Vector3(0.32, 0.21, 0.01), Vector3(0.0, 0.105, 0.0), shell)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#0B1A12")
	sm.roughness = 0.2
	sm.emission = Color("#9CFFB8")
	sm.emission_enabled = false
	sm.set_meta("vice_done", true)
	_box(lid, "Screen", Vector3(0.29, 0.18, 0.002), Vector3(0.0, 0.105, -0.006), sm)
	root.set_meta("screen_mat", sm)
	var ol := OmniLight3D.new()
	ol.name = "ScreenGlow"
	ol.light_color = Color("#9CFFB8")
	ol.light_energy = 0.8
	ol.omni_range = 1.6
	ol.position = Vector3(0.0, 0.2, -0.15)
	ol.visible = false
	root.add_child(ol)
	root.set_meta("glow_light", ol)


## A-board stand with a printed flyer; opts "text" (default "THI HỘ / BAO ĐẬU"), "sub" (small print). Faces -Z.
static func _build_flyer(root: Node3D, opts: Dictionary) -> void:
	var wood: StandardMaterial3D = _mat(Color("#6B4F35"), 0.8)
	for sx: float in [-0.3, 0.3]:
		_box(root, "Post", Vector3(0.04, 1.3, 0.04), Vector3(sx, 0.65, 0.05), wood, Vector3(0.12, 0.0, 0.0))
	_box(root, "Board", Vector3(0.66, 0.9, 0.025), Vector3(0.0, 0.95, 0.0), _mat(Color("#2B2F36"), 0.7), Vector3(0.12, 0.0, 0.0))
	var paper := Node3D.new()
	paper.name = "Paper"
	paper.position = Vector3(0.0, 0.95, -0.016)
	paper.rotation = Vector3(0.12, 0.0, 0.0)
	root.add_child(paper)
	_box(paper, "Sheet", Vector3(0.56, 0.78, 0.004), Vector3.ZERO, _mat(Color("#FFE45C"), 0.8))
	paper.add_child(_flyer_label("Headline", String(opts.get("text", "THI HỘ\nBAO ĐẬU")), 64, Color("#C0172B"), 0.14))
	paper.add_child(_flyer_label("Sub", String(opts.get("sub", "Không đậu hoàn tiền\nLiên hệ: Cừu")), 30, Color("#1A1A1A"), -0.2))


static func _flyer_label(nm: String, text: String, size: int, col: Color, y: float) -> Label3D:
	var l := Label3D.new()
	l.name = nm
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0022
	l.outline_size = 0
	l.modulate = col
	l.position = Vector3(0.0, y, -0.004)
	l.rotation_degrees.y = 180.0   # read from the -Z side (Label3D faces +Z)
	return l


## Night corridor set (a ground-floor campus corridor carried by the cinematic, so it plays on any flat stage spot): two
## walls at x = +-width / 2, a ceiling, a floor strip, classroom doors, an end wall with a green exit sign, and tube lamps
## along the ceiling (one shared tube material + an OmniLight each; set_lamp() switches them all). opts: "len" (m, along -Z
## from z = "z0"), "z0" (default 2), "closed" (a wall at the +Z end too), "width" (m), "lamps" (count), "energy",
## "flicker" / "dark" (CinePlayer windows, as "lamp").
static func _build_corridor(root: Node3D, opts: Dictionary) -> void:
	var ln: float = float(opts.get("len", 15.0))
	var w: float = float(opts.get("width", 3.2))
	var hgt: float = 3.0
	var z0: float = float(opts.get("z0", 2.0))
	var zc: float = z0 - ln * 0.5
	var wall: StandardMaterial3D = _mat(Color("#BFC6C2"), 0.85)
	var dado: StandardMaterial3D = _mat(Color("#5E7F78"), 0.8)
	for sx: float in [-1.0, 1.0]:
		_box(root, "Wall", Vector3(0.12, hgt, ln), Vector3(sx * (w * 0.5 + 0.06), hgt * 0.5, zc), wall)
		_box(root, "Dado", Vector3(0.02, 1.0, ln), Vector3(sx * (w * 0.5 - 0.005), 0.5, zc), dado)
		for i: int in maxi(int((ln - 1.6) / 4.2), 1):
			var dz: float = z0 - 1.6 - 4.2 * float(i) - (1.4 if sx > 0.0 else 0.0)
			if dz < z0 - ln + 0.6:
				continue
			_box(root, "Door", Vector3(0.03, 2.1, 0.95), Vector3(sx * (w * 0.5 - 0.01), 1.05, dz), _mat(Color("#6D4C33"), 0.7))
	_box(root, "Ceiling", Vector3(w + 0.24, 0.1, ln), Vector3(0.0, hgt + 0.05, zc), _mat(Color("#D8DAD6"), 0.9))
	_box(root, "Floor", Vector3(w, 0.012, ln), Vector3(0.0, 0.006, zc), _mat(Color("#8E9894"), 0.35))
	_box(root, "EndWall", Vector3(w + 0.24, hgt, 0.12), Vector3(0.0, hgt * 0.5, z0 - ln - 0.06), wall)
	if bool(opts.get("closed", false)):
		_box(root, "BackWall", Vector3(w + 0.24, hgt, 0.12), Vector3(0.0, hgt * 0.5, z0 + 0.06), wall)
	_box(root, "ExitSign", Vector3(0.6, 0.2, 0.04), Vector3(0.0, 2.6, z0 - ln + 0.02), _glow_mat(Color("#29C46A"), 2.0))
	var lbl := Label3D.new()
	lbl.name = "ExitText"
	lbl.text = "LỐI THOÁT"
	lbl.font_size = 40
	lbl.pixel_size = 0.0035
	lbl.outline_size = 0
	lbl.modulate = Color("#F4FFF6")
	lbl.position = Vector3(0.0, 2.6, z0 - ln + 0.05)
	root.add_child(lbl)
	var tube: StandardMaterial3D = _glow_mat(Color("#E9F6FF"), 2.5)
	var lights: Array[OmniLight3D] = []
	var n: int = int(opts.get("lamps", 4))
	for j: int in n:
		var lz: float = z0 - 1.2 - (ln - 2.4) * float(j) / maxf(float(n - 1), 1.0)
		_box(root, "Tube%d" % j, Vector3(0.12, 0.05, 1.2), Vector3(0.0, hgt - 0.03, lz), tube)
		var ol := OmniLight3D.new()
		ol.name = "TubeLight%d" % j
		ol.light_color = Color("#DDEEFF")
		ol.light_energy = float(opts.get("energy", 1.6))
		ol.omni_range = 5.5
		ol.position = Vector3(0.0, hgt - 0.3, lz)
		root.add_child(ol)
		lights.append(ol)
	root.set_meta("lamp_lights", lights)
	root.set_meta("lamp_bulb", tube)


## Dolly's cream wool cuff: a ring around the forearm (held on Wrist.L; its axis is the prop's Z, along the forearm).
static func _build_wool_cuff(root: Node3D) -> void:
	var cuff := MeshInstance3D.new()
	cuff.name = "WoolCuff"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.034
	tm.outer_radius = 0.062
	tm.rings = 12
	tm.ring_segments = 6
	cuff.mesh = tm
	cuff.material_override = _mat(Color("#EADCBD"), 1.0)
	cuff.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(cuff)


## Dolly's sheep keychain: a ring, a woolly ball and a dark face, hanging below its origin (held on Hips).
static func _build_sheep_keychain(root: Node3D) -> void:
	_box(root, "Ring", Vector3(0.006, 0.04, 0.006), Vector3(0.0, -0.02, 0.0), _mat(Color("#C9C9C9"), 0.3))
	_sphere(root, "Wool", 0.035, Vector3(0.0, -0.07, 0.0), _mat(Color("#F4F1EA"), 1.0))
	_sphere(root, "Face", 0.018, Vector3(0.0, -0.065, -0.03), _mat(Color("#2B2622"), 0.7))


## A lobby front: a wall section with two dark glass doors and a lit sign band (opts "width", default 7 m). Its face is
## the prop's +Z side (the wall body lies behind z = 0), so placed behind actors standing at +Z of it, it faces them.
static func _build_lobby_wall(root: Node3D, opts: Dictionary) -> void:
	var w: float = float(opts.get("width", 7.0))
	_box(root, "Wall", Vector3(w, 3.4, 0.25), Vector3(0.0, 1.7, -0.125), _mat(Color("#D9D2C6"), 0.85))
	var glass: StandardMaterial3D = _mat(Color("#1C2833"), 0.15)
	glass.metallic = 0.4
	for sx: float in [-0.75, 0.75]:
		_box(root, "Door", Vector3(1.3, 2.3, 0.04), Vector3(sx, 1.15, 0.02), glass)
		_box(root, "Frame", Vector3(1.4, 0.06, 0.06), Vector3(sx, 2.33, 0.03), _mat(Color("#6E747C"), 0.4))
	_box(root, "SignBand", Vector3(w * 0.6, 0.35, 0.05), Vector3(0.0, 2.85, 0.03), _glow_mat(Color("#F37021"), 1.2))


# --- W6 phase2 (plan 2026-11-05-w6-fights task 5): seg_d7_phase2's prop ---
## Lùm Văn Lọ's antique urn: a wide-mouthed blue-and-white jar, URN_H tall, origin at its centre, mouth up (+Y), foot down.
## Open at the mouth and drawn from both sides, so turned over (hold "rot" 180 about X) it fits over a head and a mask
## (inner radius 0.2 at the mouth, 0.24 at the shoulder). Round about Y: any yaw looks the same.
const URN_H: float = 0.5
const URN_MOUTH_R: float = 0.2


static func _build_antique_urn(root: Node3D) -> void:
	var glaze: StandardMaterial3D = _mat(Color("#EEF0F2"), 0.18)
	glaze.metallic_specular = 0.8
	glaze.cull_mode = BaseMaterial3D.CULL_DISABLED
	var blue: StandardMaterial3D = _mat(Color("#1E4C9A"), 0.22)
	blue.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold: StandardMaterial3D = _mat(Color("#D4AF37"), 0.25)
	gold.metallic = 0.8
	var h: float = URN_H * 0.5
	# the body: the foot (r 0.14) widening to the shoulder (r 0.24) at y +0.08, then in to the mouth (r 0.2)
	var body: MeshInstance3D = _cyl(root, "Body", 0.24, 0.14, 0.33, Vector3(0.0, -h + 0.165, 0.0), glaze)
	(body.mesh as CylinderMesh).cap_top = false
	var sh: MeshInstance3D = _cyl(root, "Shoulder", URN_MOUTH_R, 0.24, 0.17, Vector3(0.0, -h + 0.33 + 0.085, 0.0), glaze)
	(sh.mesh as CylinderMesh).cap_top = false
	(sh.mesh as CylinderMesh).cap_bottom = false
	# blue bands on the belly and the shoulder, a gold lip and foot
	var b1: MeshInstance3D = _cyl(root, "Band", 0.2135, 0.2045, 0.05, Vector3(0.0, -h + 0.21, 0.0), blue)
	(b1.mesh as CylinderMesh).cap_top = false
	(b1.mesh as CylinderMesh).cap_bottom = false
	var b2: MeshInstance3D = _cyl(root, "Band", 0.2245, 0.2365, 0.05, Vector3(0.0, -h + 0.375, 0.0), blue)
	(b2.mesh as CylinderMesh).cap_top = false
	(b2.mesh as CylinderMesh).cap_bottom = false
	var lip := MeshInstance3D.new()
	lip.name = "Lip"
	var tm := TorusMesh.new()
	tm.inner_radius = URN_MOUTH_R - 0.006
	tm.outer_radius = URN_MOUTH_R + 0.022
	tm.rings = 20
	tm.ring_segments = 6
	lip.mesh = tm
	lip.material_override = gold
	lip.position = Vector3(0.0, h - 0.01, 0.0)
	root.add_child(lip)
	_cyl(root, "Foot", 0.13, 0.145, 0.03, Vector3(0.0, -h + 0.015, 0.0), gold)
