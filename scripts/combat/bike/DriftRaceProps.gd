# File: res://scripts/combat/bike/DriftRaceProps.gd
# The dressing of the Day 2 race "Rạch Hầm GP" (Wave 2 Day 2 rework, plan 2026-10-29-w2-day2.md), owned by DriftDuel and
# built once from the DriftCourse data:
#   - neon arches over the road (DriftCourse.arches: the grid / finish on the bridge deck with a checkered line, the Y
#     junction, the lap line, the hairpin): two pillars and a beam with cyan and magenta emissive strips (they glow under
#     the tokyo_drift look), a label for each direction of travel, one small light each;
#   - yellow glowing road arrows before every drift corner and a yellow-on-black chevron board on its outside (Q3 yellow =
#     prompt); each corner's set only shows while the player is near it (the lap junction has a "lap 2" and a "to the
#     finish" set at the same spot);
#   - the Bầy Sói pack lining the course (DriftCourse.crowds): wolf-helmeted figures with red LED eyes, each waving a red
#     flare, in 4 MultiMeshes (figures, eyes, arms, flare tips); the groups near the player cheer (a jumping bob and the
#     waving arm, rewritten at CHEER_HZ), LIGHTS flare lights and SMOKE flare-smoke emitters follow the nearest groups,
#     and a group cheers out loud ("applause") when the player rides by. Members that would stand in a wall are dropped;
#   - fireworks over the finish (fireworks(at)): FIREWORKS pooled bursts of coloured sparks with pops and a flash light.
# Everything is built in setup(); tick() never allocates. Synthesized SFX only.
class_name DriftRaceProps
extends Node3D

const ARCH_H: float = 5.4
const ARCH_OUT: float = 0.9                # pillars this far outside the road edge
const CYAN := Color("#27E8FF")
const MAGENTA := Color("#FF3FD2")
const ARROW_Y: float = 0.035
const ARROW_SHOW_BEFORE: float = 170.0
const ARROW_SHOW_AFTER: float = 15.0
const CROWD_OUT: float = 2.3               # members this far outside the road edge ...
const CROWD_STEP: float = 1.5              # ... and this far apart along the road
const CHEER_HZ: float = 15.0
const CHEER_M: float = 90.0
const CHEER_SOUND_M: float = 24.0
const CHEER_GAP_S: float = 8.0
const LIGHTS: int = 3
const SMOKE: int = 2
const FIREWORKS: int = 6
const FW_BURSTS: int = 9
const FW_EVERY: float = 0.32
const FW_COLORS: Array[Color] = [Color("#FF3B3B"), Color("#FFD23F"), Color("#27E8FF"), Color("#FF3FD2"), Color("#7CFF6B"), Color("#FFFFFF")]

var course: DriftCourse
var floor_fn: Callable
var arch_count: int = 0
var member_count: int = 0
var dropped_members: int = 0
var arrow_groups: Array[Node3D] = []
var cheers: int = 0
var fireworks_fired: int = 0
var lights: Array[OmniLight3D] = []
var smokes: Array[CPUParticles3D] = []
# crowd
var _fig_mm: MultiMesh
var _eye_mm: MultiMesh
var _arm_mm: MultiMesh
var _tip_mm: MultiMesh
var _m_xf: Array[Transform3D] = []         # each member's base transform (feet on the floor, facing the road)
var _m_group := PackedInt32Array()
var _m_phase := PackedFloat32Array()
var _g_center := PackedVector3Array()
var _g_first := PackedInt32Array()
var _g_count := PackedInt32Array()
var _g_cheer_t := PackedFloat32Array()
var _g_near := PackedByteArray()
var _t: float = 0.0
var _cheer_t: float = 0.0
var _light_t: float = 0.0
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
# fireworks
var _fw: Array[CPUParticles3D] = []
var _fw_i: int = 0
var _fw_left: int = 0
var _fw_t: float = 0.0
var _fw_at: Vector3 = Vector3.ZERO
var _fw_light: OmniLight3D
var _fw_rng := RandomNumberGenerator.new()
var _arm_local := Transform3D.IDENTITY
var _shape_q: PhysicsShapeQueryParameters3D


func setup(c: DriftCourse, floor_cb: Callable, ray_exclude: Array[RID] = []) -> void:
	course = c
	floor_fn = floor_cb
	name = "RaceProps"
	top_level = true
	global_transform = Transform3D.IDENTITY
	_fw_rng.seed = 2910
	_shape_q = PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.28
	_shape_q.shape = sh
	_shape_q.exclude = ray_exclude
	for a: Array in course.arches:
		_arch(float(a[0]), String(a[1]), String(a[2]) if a.size() > 2 else "")
	_finish_line()
	for ci: int in course.corners.size():
		_corner_signs(ci)
	_build_crowd()
	for i: int in LIGHTS:
		var l := OmniLight3D.new()
		l.name = "FlareLight%d" % i
		l.light_color = Color(1.0, 0.25, 0.12)
		l.omni_range = 8.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		lights.append(l)
	for i2: int in SMOKE:
		smokes.append(_flare_smoke(i2))
	for i3: int in 2:
		var p := AudioStreamPlayer3D.new()
		p.name = "CrowdSfx%d" % i3
		p.max_distance = 70.0
		p.unit_size = 9.0
		p.bus = WeaponAudio.bus()
		add_child(p)
		_sfx.append(p)
	for i4: int in FIREWORKS:
		_fw.append(_firework(i4))
	_fw_light = OmniLight3D.new()
	_fw_light.name = "FireworkFlash"
	_fw_light.omni_range = 45.0
	_fw_light.light_energy = 0.0
	_fw_light.shadow_enabled = false
	add_child(_fw_light)
	for c2: String in ["applause"]:
		CineAudio.sfx(c2)
	WeaponAudio.stream("explosion")


func _floor(p: Vector2) -> float:
	var y: Variant = floor_fn.call(Vector3(p.x, 0.0, p.y)) if floor_fn.is_valid() else null
	return float(y) if y is float else 0.05


static func _emit(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	m.set_meta("vice_done", true)
	return m


# ---------------------------------------------------------------------------
# ARCHES, FINISH LINE, ARROWS
# ---------------------------------------------------------------------------
func _arch(s: float, front: String, back: String) -> void:
	var root := Node3D.new()
	root.name = "Arch"
	add_child(root)
	var p: Vector2 = course.point(s)
	var w: float = course.half_width_at(s) + ARCH_OUT
	root.global_transform = Transform3D(Basis(Vector3.UP, course.yaw_at(s)), Vector3(p.x, _floor(p), p.y))
	var dark := _emit(Color("#14101C"), 0.0)
	var cyan := _emit(CYAN, 4.5)
	var mag := _emit(MAGENTA, 4.5)
	for sx: float in [-w, w]:
		CineFX._box(root, "Pillar", Vector3(0.5, ARCH_H, 0.5), Vector3(sx, ARCH_H * 0.5, 0.0), dark)
		CineFX._box(root, "NeonPillar", Vector3(0.08, ARCH_H - 0.4, 0.08), Vector3(sx - signf(sx) * 0.27, ARCH_H * 0.5, -0.27), cyan)
		CineFX._box(root, "NeonPillarB", Vector3(0.08, ARCH_H - 0.4, 0.08), Vector3(sx - signf(sx) * 0.27, ARCH_H * 0.5, 0.27), cyan)
	CineFX._box(root, "Beam", Vector3(2.0 * w + 0.5, 0.9, 0.55), Vector3(0.0, ARCH_H, 0.0), dark)
	for z: float in [-0.3, 0.3]:
		CineFX._box(root, "NeonBeam", Vector3(2.0 * w + 0.3, 0.08, 0.06), Vector3(0.0, ARCH_H - 0.36, z), mag)
		CineFX._box(root, "NeonBeamTop", Vector3(2.0 * w + 0.3, 0.08, 0.06), Vector3(0.0, ARCH_H + 0.36, z), cyan)
	for side: int in 2:
		var txt: String = front if side == 0 else back
		if txt == "":
			continue
		var l := Label3D.new()
		l.name = "ArchText"
		l.text = txt
		l.font_size = 96
		l.pixel_size = 0.0075
		l.outline_size = 14
		l.modulate = Color("#FFF1FB")
		l.outline_modulate = Color(MAGENTA, 1.0)
		l.position = Vector3(0.0, ARCH_H, 0.3 if side == 0 else -0.3)
		l.rotation = Vector3(0.0, 0.0 if side == 0 else PI, 0.0)
		root.add_child(l)
	var lt := OmniLight3D.new()
	lt.name = "ArchLight"
	lt.light_color = MAGENTA.lerp(CYAN, 0.4)
	lt.omni_range = 11.0
	lt.light_energy = 1.6
	lt.shadow_enabled = false
	lt.position = Vector3(0.0, ARCH_H - 1.2, 0.0)
	root.add_child(lt)
	arch_count += 1


## A checkered band across the deck at the grid / finish line (a code-built 16 x 2 checker texture).
func _finish_line() -> void:
	var img := Image.create(16, 2, false, Image.FORMAT_RGB8)
	for x: int in 16:
		for y: int in 2:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.06))
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.35
	m.set_meta("vice_done", true)
	var pm := PlaneMesh.new()
	var w: float = course.half_width_at(0.0) * 2.0
	pm.size = Vector2(w, w / 8.0)
	pm.material = m
	var mi := MeshInstance3D.new()
	mi.name = "FinishLine"
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var p: Vector2 = course.point(0.0)
	mi.global_transform = Transform3D(Basis(Vector3.UP, course.yaw_at(0.0) + PI * 0.5), Vector3(p.x, _floor(p) + ARROW_Y, p.y))


## Corner ci: its road arrows (a glowing yellow chevron each, bent toward the turn) and the chevron board on the outside.
func _corner_signs(ci: int) -> void:
	var g := Node3D.new()
	g.name = "CornerSigns%d" % ci
	add_child(g)
	g.set_meta("s0", float(course.corners[ci][0]))
	g.set_meta("s1", float(course.corners[ci][1]))
	var yel: StandardMaterial3D = Readability.telegraph_material("prompt", 3.2)
	var dir: float = float(course.corners[ci][2])
	for a: Array in course.arrows:
		if int(a[2]) != ci:
			continue
		var s: float = float(a[0])
		var p: Vector2 = course.point(s)
		var root := Node3D.new()
		root.name = "Arrow"
		g.add_child(root)
		root.global_transform = Transform3D(Basis(Vector3.UP, course.yaw_at(s) - dir * deg_to_rad(28.0)), Vector3(p.x, _floor(p) + ARROW_Y, p.y))
		for k: float in [-1.0, 1.0]:
			CineFX._box(root, "Bar", Vector3(0.24, 0.04, 1.5), Vector3(k * 0.42, 0.0, 0.0), yel, Vector3(0.0, k * 0.75, 0.0))
	# the board on the outside of the apex, facing the riders coming in
	var apex: float = (float(course.corners[ci][0]) + float(course.corners[ci][1])) * 0.5
	var bs: float = maxf(float(course.corners[ci][0]), apex - 4.0)
	var q: Vector2 = course.world(bs, -dir * (course.half_width_at(bs) + 1.2))
	var board := Node3D.new()
	board.name = "Chevron"
	g.add_child(board)
	board.global_transform = Transform3D(Basis(Vector3.UP, course.yaw_at(bs)), Vector3(q.x, _floor(q), q.y))
	var black := _emit(Color("#15151A"), 0.0)
	CineFX._box(board, "Board", Vector3(2.4, 0.8, 0.06), Vector3(0.0, 1.2, 0.0), black)
	for leg: float in [-1.0, 1.0]:
		CineFX._box(board, "Leg", Vector3(0.07, 0.85, 0.07), Vector3(leg, 0.42, 0.0), black)
	for k2: int in 3:
		var x: float = (-0.7 + 0.7 * float(k2)) * dir
		CineFX._box(board, "ArrowA", Vector3(0.09, 0.42, 0.02), Vector3(x - 0.07 * dir, 1.29, 0.05), yel, Vector3(0.0, 0.0, -0.7 * dir))
		CineFX._box(board, "ArrowB", Vector3(0.09, 0.42, 0.02), Vector3(x - 0.07 * dir, 1.11, 0.05), yel, Vector3(0.0, 0.0, 0.7 * dir))
	g.visible = false
	arrow_groups.append(g)


# ---------------------------------------------------------------------------
# THE PACK
# ---------------------------------------------------------------------------
func _build_crowd() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for gi: int in course.crowds.size():
		var row: Array = course.crowds[gi]
		var s: float = float(row[0])
		var side: float = float(row[1])
		var n: int = int(row[2])
		var first: int = _m_xf.size()
		var centre := Vector3.ZERO
		var kept: int = 0
		for k: int in n:
			var sk: float = s + (float(k) - float(n - 1) * 0.5) * CROWD_STEP
			var off: float = side * (course.half_width_at(sk) + CROWD_OUT + rng.randf_range(-0.3, 0.6) + (0.9 if k % 2 == 1 else 0.0))
			var p: Vector2 = course.world(sk, off)
			var fy: float = _floor(p)
			if space and not _free(space, Vector3(p.x, fy + 1.0, p.y)):
				dropped_members += 1
				continue
			var face: Vector2 = course.point(sk) - p                  # toward the road
			var yaw: float = atan2(-face.x, -face.y) + rng.randf_range(-0.3, 0.3)
			_m_xf.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, fy, p.y)))
			_m_group.append(gi)
			_m_phase.append(rng.randf_range(0.0, TAU))
			centre += Vector3(p.x, fy, p.y)
			kept += 1
		_g_first.append(first)
		_g_count.append(kept)
		_g_center.append(centre / float(maxi(kept, 1)))
		_g_cheer_t.append(-99.0)
		_g_near.append(0)
	member_count = _m_xf.size()
	_arm_local = Transform3D(Basis(), Vector3(0.3, 1.42, 0.0))
	_fig_mm = _crowd_mm("PackBodies", _figure_mesh(), _vc_mat())
	_eye_mm = _crowd_mm("PackEyes", _eyes_mesh(), _emit(BikeCombatData.EYE_COL, 5.0))
	_arm_mm = _crowd_mm("PackArms", _arm_mesh(), _vc_mat())
	_tip_mm = _crowd_mm("PackFlares", _tip_mesh(), _emit(Color(1.0, 0.22, 0.1), 7.0))
	for i: int in member_count:
		_pose_member(i, 0.0, 0.0)


func _free(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	_shape_q.transform = Transform3D(Basis(), at)
	return space.intersect_shape(_shape_q, 1).is_empty()


func _crowd_mm(nm: String, mesh: Mesh, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = member_count
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm


static func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	m.set_meta("vice_done", true)
	return m


## A member: bob (jump height, m) and wave (arm swing, rad).
func _pose_member(i: int, bob: float, wave: float) -> void:
	var xf: Transform3D = _m_xf[i].translated(Vector3(0.0, bob, 0.0))
	_fig_mm.set_instance_transform(i, xf)
	_eye_mm.set_instance_transform(i, xf)
	var arm: Transform3D = xf * _arm_local * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -0.35 + wave), Vector3.ZERO)
	_arm_mm.set_instance_transform(i, arm)
	_tip_mm.set_instance_transform(i, arm)


static func _box_into(st: SurfaceTool, c: Vector3, sz: Vector3, col: Color) -> void:
	var h: Vector3 = sz * 0.5
	var faces: Array = [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	st.set_color(col)
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o: Vector3 = c + n * h.abs().dot(n.abs())
		var du: Vector3 = u * h.abs().dot(u.abs())
		var dv: Vector3 = v * h.abs().dot(v.abs())
		var q: Array[Vector3] = [o - du - dv, o + du - dv, o + du + dv, o - du + dv]
		st.set_normal(n)
		for idx: int in [0, 2, 1, 0, 3, 2]:   # clockwise seen from outside (Godot's front faces)
			st.add_vertex(q[idx])


## Legs, jacket, wolf helmet (grey with cone-ish ears and a snout), the other arm down: one vertex-coloured mesh.
static func _figure_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var jeans := Color("#2B3140")
	var jacket := Color("#1E1E24")
	var helm := BikeCombatData.HELMET_COL
	var dark := BikeCombatData.HELMET_DARK
	_box_into(st, Vector3(-0.11, 0.42, 0.0), Vector3(0.16, 0.84, 0.2), jeans)
	_box_into(st, Vector3(0.11, 0.42, 0.0), Vector3(0.16, 0.84, 0.2), jeans)
	_box_into(st, Vector3(0.0, 1.12, 0.0), Vector3(0.46, 0.6, 0.26), jacket)
	_box_into(st, Vector3(-0.3, 1.02, 0.0), Vector3(0.12, 0.56, 0.13), jacket)
	_box_into(st, Vector3(0.0, 1.6, 0.0), Vector3(0.32, 0.32, 0.34), helm)
	_box_into(st, Vector3(0.0, 1.55, -0.21), Vector3(0.16, 0.12, 0.14), dark)
	_box_into(st, Vector3(-0.1, 1.82, 0.02), Vector3(0.08, 0.14, 0.08), dark)
	_box_into(st, Vector3(0.1, 1.82, 0.02), Vector3(0.08, 0.14, 0.08), dark)
	return st.commit()


static func _eyes_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box_into(st, Vector3(-0.075, 1.64, -0.172), Vector3(0.08, 0.035, 0.02), Color.WHITE)
	_box_into(st, Vector3(0.075, 1.64, -0.172), Vector3(0.08, 0.035, 0.02), Color.WHITE)
	return st.commit()


## The raised arm (shoulder at the origin, pointing up) with the flare stick.
static func _arm_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box_into(st, Vector3(0.0, 0.28, 0.0), Vector3(0.12, 0.58, 0.13), Color("#1E1E24"))
	_box_into(st, Vector3(0.0, 0.66, 0.0), Vector3(0.05, 0.3, 0.05), Color("#B02020"))
	return st.commit()


static func _tip_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box_into(st, Vector3(0.0, 0.86, 0.0), Vector3(0.09, 0.12, 0.09), Color.WHITE)
	return st.commit()


func _flare_smoke(i: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "FlareSmoke%d" % i
	p.emitting = false
	p.amount = 18
	p.lifetime = 2.2
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3.5, 0.2, 1.0)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0.3, 0.5, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = Color(1.0, 0.35, 0.4, 0.35)
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.set_meta("vice_done", true)
	sm.material = mat
	p.mesh = sm
	add_child(p)
	return p


# ---------------------------------------------------------------------------
# FIREWORKS
# ---------------------------------------------------------------------------
func _firework(i: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Firework%d" % i
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 72
	p.lifetime = 1.7
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 12.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0.0, -3.5, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	var col: Color = FW_COLORS[i % FW_COLORS.size()]
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(col, 0.0))
	g.add_point(0.25, Color(col, 1.0))
	p.color_ramp = g
	var qm := QuadMesh.new()
	qm.size = Vector2(0.45, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _dot()
	mat.set_meta("vice_done", true)
	qm.material = mat
	p.mesh = qm
	add_child(p)
	return p


static var _dot_tex: GradientTexture2D = null


static func _dot() -> GradientTexture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_dot_tex = GradientTexture2D.new()
		_dot_tex.gradient = g
		_dot_tex.fill = GradientTexture2D.FILL_RADIAL
		_dot_tex.fill_from = Vector2(0.5, 0.5)
		_dot_tex.fill_to = Vector2(1.0, 0.5)
		_dot_tex.width = 32
		_dot_tex.height = 32
	return _dot_tex


## FW_BURSTS bursts over `at` (the finish), one every FW_EVERY s.
func fireworks(at: Vector3) -> void:
	_fw_at = at
	_fw_left = FW_BURSTS
	_fw_t = 0.0


func _burst() -> void:
	var e: CPUParticles3D = _fw[_fw_i]
	_fw_i = (_fw_i + 1) % _fw.size()
	var p: Vector3 = _fw_at + Vector3(_fw_rng.randf_range(-22.0, 22.0), _fw_rng.randf_range(20.0, 32.0), _fw_rng.randf_range(-22.0, 22.0))
	e.global_position = p
	e.restart()
	fireworks_fired += 1
	_fw_light.global_position = p
	_fw_light.light_color = FW_COLORS[(_fw_i + 5) % FW_COLORS.size()]
	_fw_light.light_energy = 6.0
	var s: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	s.stream = WeaponAudio.stream("explosion")
	s.pitch_scale = _fw_rng.randf_range(1.4, 1.9)
	s.volume_db = -9.0
	s.max_distance = 300.0
	s.global_position = p
	s.play()


# ---------------------------------------------------------------------------
# PER FRAME (DriftDuel)
# ---------------------------------------------------------------------------
## The player's progress s_p and position: the corner sets near him, the cheering groups, the flare lights and smoke,
## the fireworks. rdt: real seconds.
func tick(rdt: float, s_p: float, pos: Vector3) -> void:
	_t += rdt
	if _fw_left > 0:
		_fw_t -= rdt
		if _fw_t <= 0.0:
			_fw_t = FW_EVERY
			_fw_left -= 1
			_burst()
	if _fw_light.light_energy > 0.0:
		_fw_light.light_energy = maxf(0.0, _fw_light.light_energy - rdt * 14.0)
	for g: Node3D in arrow_groups:
		var on: bool = s_p >= float(g.get_meta("s0")) - ARROW_SHOW_BEFORE and s_p <= float(g.get_meta("s1")) + ARROW_SHOW_AFTER
		if g.visible != on:
			g.visible = on
	_light_t -= rdt
	if _light_t <= 0.0:
		_light_t = 0.25
		_place_lights(pos)
	for i: int in lights.size():
		var l: OmniLight3D = lights[i]
		if l.visible:
			l.light_energy = 2.0 + 0.7 * sin(_t * 23.0 + float(i) * 2.1) + 0.3 * sin(_t * 41.0 + float(i))
	_cheer_t -= rdt
	if _cheer_t > 0.0:
		return
	_cheer_t = 1.0 / CHEER_HZ
	for gi: int in _g_center.size():
		if _g_count[gi] == 0:
			continue
		var dist: float = _g_center[gi].distance_to(pos)
		var near: bool = dist < CHEER_M
		if near:
			for i2: int in range(_g_first[gi], _g_first[gi] + _g_count[gi]):
				var ph: float = _m_phase[i2]
				_pose_member(i2, absf(sin(_t * 7.5 + ph)) * 0.22, sin(_t * 9.0 + ph) * 0.55)
		elif _g_near[gi] == 1:
			for i3: int in range(_g_first[gi], _g_first[gi] + _g_count[gi]):
				_pose_member(i3, 0.0, 0.0)
		_g_near[gi] = 1 if near else 0
		if dist < CHEER_SOUND_M and _t - _g_cheer_t[gi] > CHEER_GAP_S:
			_g_cheer_t[gi] = _t
			cheers += 1
			var s: AudioStreamPlayer3D = _sfx[_sfx_i]
			_sfx_i = (_sfx_i + 1) % _sfx.size()
			s.stream = CineAudio.sfx("applause")
			s.pitch_scale = 1.0
			s.volume_db = -2.0
			s.max_distance = 70.0
			s.global_position = _g_center[gi] + Vector3(0.0, 1.5, 0.0)
			s.play()


## The flare lights and smoke at the groups nearest pos (no allocation: a small insertion pick).
func _place_lights(pos: Vector3) -> void:
	var best_i: Array[int] = [-1, -1, -1]
	var best_d: Array[float] = [INF, INF, INF]
	for gi: int in _g_center.size():
		if _g_count[gi] == 0:
			continue
		var dd: float = _g_center[gi].distance_squared_to(pos)
		for k: int in 3:
			if dd < best_d[k]:
				for m: int in range(2, k, -1):
					best_d[m] = best_d[m - 1]
					best_i[m] = best_i[m - 1]
				best_d[k] = dd
				best_i[k] = gi
				break
	for i: int in lights.size():
		var gi2: int = best_i[i] if i < best_i.size() else -1
		var on: bool = gi2 >= 0 and best_d[i] < 120.0 * 120.0
		lights[i].visible = on
		if on:
			lights[i].global_position = _g_center[gi2] + Vector3(0.0, 2.4, 0.0)
	for j: int in smokes.size():
		var gi3: int = best_i[j]
		var on2: bool = gi3 >= 0 and best_d[j] < 80.0 * 80.0
		if on2:
			smokes[j].global_position = _g_center[gi3] + Vector3(0.0, 2.2, 0.0)
		if smokes[j].emitting != on2:
			smokes[j].emitting = on2
