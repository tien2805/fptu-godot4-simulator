# File: res://scripts/cine/CineCrowd.gd
# Mannequins in smart glasses (story Phase C, spec C-D10): a cheap crowd of hundreds of faceless store mannequins drawn
# with three MultiMeshes (bodies, heads, smart glasses with a red LED), all code-built. Every head can turn on one beat
# (cine_eval: the discovery jump scare of cine_d3_mannequins), the crowd can "clap" (a small bob, end_c).
#
#   var c := CineCrowd.new(); c.layout_grid(Vector3.ZERO, 5, 12, 0.45, 0.48)   # or c.layout(points, yaws)
#   c.cine_eval(s, {"turn_at": 3.0, "turn_from": 75.0})     # heads face 75 deg away until 3.0, snap to the front by 3.12
#   StoryCast.build("mannequins", {"cols": 6, "rows": 8})    # gameplay: a ready laid-out crowd
#
# Pure in story time (seekable). The head and glasses transforms are only rewritten when the turn amount changes.
class_name CineCrowd
extends Node3D

const TURN_DUR: float = 0.12
const BODY_COL := Color("#E8E1D6")
const HEAD_Y: float = 1.58        # head centre above the feet
const BODY_H: float = 1.42

var bodies: MultiMeshInstance3D
var heads: MultiMeshInstance3D
var glasses: MultiMeshInstance3D
var points: PackedVector3Array = PackedVector3Array()
var yaws: PackedFloat32Array = PackedFloat32Array()
## Current head turn away from the front (rad; MultiMesh transforms cannot be read back on the headless renderer).
var head_turn: float = 0.0
var _last_turn: float = -1.0
var _last_bob: float = -1.0


func _init() -> void:
	name = "Mannequins"


## n_x across (local X) by n_z deep (local +Z away from the front row), spacing dx / dz; everyone faces -Z.
func layout_grid(origin: Vector3, n_x: int, n_z: int, dx: float, dz: float) -> void:
	var pts := PackedVector3Array()
	var ys := PackedFloat32Array()
	for j: int in n_z:
		for i: int in n_x:
			var jit: float = sin(float(i * 7 + j * 13)) * 0.04
			pts.append(origin + Vector3((float(i) - float(n_x - 1) * 0.5) * dx + jit, 0.0, float(j) * dz))
			ys.append(0.0)
	layout(pts, ys)


## Explicit places (local) and yaws (rad, 0 = facing -Z).
func layout(pts: PackedVector3Array, ys: PackedFloat32Array) -> void:
	points = pts
	yaws = ys
	for n: Node in [bodies, heads, glasses]:
		if n:
			n.queue_free()
	var skin: StandardMaterial3D = CineFX._mat(BODY_COL, 0.4)
	bodies = _mm("Bodies", _body_mesh(), skin)
	heads = _mm("Heads", _head_mesh(), skin)
	glasses = _mm("Glasses", _glasses_mesh(), null)   # per-surface materials: dark band, glowing LED
	for i: int in points.size():
		bodies.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaws[i]), points[i]))
	_last_turn = -1.0
	_apply_turn(0.0, 0.0)


func count() -> int:
	return points.size()


func _mm(nm: String, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	add_child(mmi)
	return mmi


## Story-time evaluation (CinePlayer, prop opts "anim": true): "turn_at" (s), "turn_dur" (s, default TURN_DUR), "turn_from"
## (deg the heads face away before), "claps" [[s0, s1], ...] or "clap_from" / "clap_to" (s: the crowd bobs as if applauding).
func cine_eval(s: float, opts: Dictionary) -> void:
	var u: float = 1.0
	if opts.has("turn_at"):
		u = clampf((s - float(opts["turn_at"])) / float(opts.get("turn_dur", TURN_DUR)), 0.0, 1.0)
	var away: float = deg_to_rad(float(opts.get("turn_from", 0.0)))
	var bob: float = 0.0
	var claps: Array = opts.get("claps", [])
	if opts.has("clap_from"):
		claps = claps + [[float(opts["clap_from"]), float(opts.get("clap_to", INF))]]
	for w: Variant in claps:
		if s >= float(w[0]) and s < float(w[1]):
			bob = absf(sin((s - float(w[0])) * TAU * 2.2)) * 0.025
	_apply_turn(away * (1.0 - u * u * (3.0 - 2.0 * u)), bob)


func _apply_turn(a: float, bob: float) -> void:
	if is_equal_approx(a, _last_turn) and is_equal_approx(bob, _last_bob):
		return
	var bob_changed: bool = not is_equal_approx(bob, _last_bob)
	head_turn = a
	_last_turn = a
	_last_bob = bob
	for i: int in points.size():
		var side: float = 1.0 if (i % 2) == 0 else -1.0   # half look left, half right before the snap
		var b := Basis(Vector3.UP, yaws[i] + a * side)
		var hp: Vector3 = points[i] + Vector3(0.0, HEAD_Y + bob, 0.0)
		heads.multimesh.set_instance_transform(i, Transform3D(b, hp))
		glasses.multimesh.set_instance_transform(i, Transform3D(b, hp))
		if bob_changed:
			bodies.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaws[i]), points[i] + Vector3(0.0, bob, 0.0)))


## Torso + legs as one capsule-ish lathe (origin at the feet), a neck stub on top.
static func _body_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof: Array = [[0.0, 0.07], [0.45, 0.09], [0.82, 0.14], [0.95, 0.15], [1.12, 0.12], [1.3, 0.17], [1.36, 0.12], [1.42, 0.05],
		[1.48, 0.045]]
	var seg: int = 8
	for k: int in prof.size() - 1:
		var y0: float = prof[k][0]
		var r0: float = prof[k][1]
		var y1: float = prof[k + 1][0]
		var r1: float = prof[k + 1][1]
		for i: int in seg:
			var a0: float = TAU * float(i) / seg
			var a1: float = TAU * float(i + 1) / seg
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0 * 0.7)
			var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0 * 0.7)
			var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1 * 0.7)
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1 * 0.7)
			for v: Vector3 in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _head_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.24
	sm.radial_segments = 10
	sm.rings = 6
	return sm


## Smart glasses: a dark visor band in front of the head (-Z) and a red LED (emissive surface).
static func _glasses_mesh() -> Mesh:
	var am := ArrayMesh.new()
	var band := BoxMesh.new()
	band.size = Vector3(0.17, 0.035, 0.03)
	var arr: Array = band.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i: int in v.size():
		v[i] += Vector3(0.0, 0.015, -0.095)
	arr[Mesh.ARRAY_VERTEX] = v
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, CineFX._mat(Color("#0E0E12"), 0.2))
	var led := BoxMesh.new()
	led.size = Vector3(0.018, 0.012, 0.012)
	var arr2: Array = led.get_mesh_arrays()
	var v2: PackedVector3Array = arr2[Mesh.ARRAY_VERTEX]
	for i2: int in v2.size():
		v2[i2] += Vector3(0.062, 0.022, -0.112)
	arr2[Mesh.ARRAY_VERTEX] = v2
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	am.surface_set_material(1, CineFX._glow_mat(Color("#FF2030"), 3.5))
	return am
