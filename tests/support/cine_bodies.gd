# File: res://tests/support/cine_bodies.gd
# Body-overlap measure for cinematic tests: each CineActor as bone capsules (torso Hips->Neck r 0.17, head sphere r 0.12,
# upper arm / forearm r 0.055, thigh r 0.08, shin r 0.06) and each solid prop as oriented boxes built from its meshes;
# penetration depth = radii sum minus the distance between the capsule axes (or capsule radius minus the signed box
# distance). Used by tests/test_cine_d1_brawl.gd (preload, no class_name).
extends RefCounted

const CAPS: Array = [
	["torso", "Hips", "Neck", 0.17], ["upper_arm.L", "UpperArm.L", "LowerArm.L", 0.055], ["forearm.L", "LowerArm.L", "Wrist.L", 0.055],
	["upper_arm.R", "UpperArm.R", "LowerArm.R", 0.055], ["forearm.R", "LowerArm.R", "Wrist.R", 0.055],
	["thigh.L", "UpperLeg.L", "LowerLeg.L", 0.08], ["shin.L", "LowerLeg.L", "Foot.L", 0.06],
	["thigh.R", "UpperLeg.R", "LowerLeg.R", 0.08], ["shin.R", "LowerLeg.R", "Foot.R", 0.06]]
const HEAD_R: float = 0.12
const HEAD_UP: float = 0.11          # head sphere centre along the Head bone axis
const CORE: Array[String] = ["torso", "head"]
## Prop meshes that are not solid (lights, lamp lens, thin battens, the crane hook's cable overhead).
const SKIP_MESH: Array[String] = ["Headlight", "Haze", "Edge", "Screen", "Hub", "Cable"]


## [[part, a, b, r], ...] in world space (the head as a zero-length capsule).
static func capsules(a: CineActor) -> Array:
	var out: Array = []
	for c: Array in CAPS:
		out.append([c[0], a.bone_world(String(c[1])), a.bone_world(String(c[2])), float(c[3])])
	var hb: int = a.sk.find_bone("Head")
	var hx: Transform3D = a.sk.global_transform * CharacterBuilder._bone_global_now(a.sk, hb)
	var hc: Vector3 = hx.origin + hx.basis.y.normalized() * HEAD_UP
	out.append(["head", hc, hc, HEAD_R])
	return out


static func is_core(part: String) -> bool:
	return part in CORE


## Closest distance between segments p1-q1 and p2-q2.
static func seg_dist(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1: Vector3 = q1 - p1
	var d2: Vector3 = q2 - p2
	var r: Vector3 = p1 - p2
	var a: float = d1.dot(d1)
	var e: float = d2.dot(d2)
	var f: float = d2.dot(r)
	var s: float = 0.0
	var t: float = 0.0
	if a <= 1e-9 and e <= 1e-9:
		return p1.distance_to(p2)
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c: float = d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b: float = d1.dot(d2)
			var den: float = a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-9 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


## Deepest penetration between two actors: {"d": depth (m, <= 0 = apart), "pa", "pb"}.
static func actor_pair(ca: Array, cb: Array) -> Dictionary:
	var best: Dictionary = {"d": -1.0, "pa": "", "pb": ""}
	for x: Array in ca:
		for y: Array in cb:
			var d: float = float(x[3]) + float(y[3]) - seg_dist(x[1], x[2], y[1], y[2])
			if d > float(best["d"]):
				best = {"d": d, "pa": String(x[0]), "pb": String(y[0])}
	return best


## Solid boxes of a prop: [[name, Transform3D (orthonormal), half extents], ...] from its meshes' AABBs.
static func prop_boxes(prop: Node3D) -> Array:
	var out: Array = []
	for n: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null or String(mi.name).begins_with("@") or SKIP_MESH.any(func(k: String) -> bool: return String(mi.name).begins_with(k)):
			continue
		var ab: AABB = mi.mesh.get_aabb()
		var gx: Transform3D = mi.global_transform
		var sc: Vector3 = gx.basis.get_scale()
		var xf := Transform3D(gx.basis.orthonormalized(), gx * ab.get_center())
		out.append([String(mi.name), xf, ab.size * sc * 0.5])
	return out


static func _box_sdf(q: Vector3, h: Vector3) -> float:
	var d: Vector3 = q.abs() - h
	return Vector3(maxf(d.x, 0.0), maxf(d.y, 0.0), maxf(d.z, 0.0)).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0)


## Deepest penetration of an actor's capsules into boxes: {"d", "part", "box"}.
static func actor_boxes(ca: Array, boxes: Array) -> Dictionary:
	var best: Dictionary = {"d": -1.0, "part": "", "box": ""}
	for x: Array in ca:
		var a: Vector3 = x[1]
		var b: Vector3 = x[2]
		var r: float = x[3]
		for bx: Array in boxes:
			var xf: Transform3D = bx[1]
			var h: Vector3 = bx[2]
			if (a + b).distance_to(xf.origin * 2.0) * 0.5 > h.length() + r + a.distance_to(b) * 0.5:
				continue
			var inv: Transform3D = xf.affine_inverse()
			for i: int in 9:
				var p: Vector3 = a.lerp(b, float(i) / 8.0)
				var d: float = r - _box_sdf(inv * p, h)
				if d > float(best["d"]):
					best = {"d": d, "part": String(x[0]), "box": String(bx[0])}
	return best


# ---------------------------------------------------------------------------
# Surface gaps (m; < 0 = overlapping) for contact checks
# ---------------------------------------------------------------------------
const FIST_R: float = 0.05
const FIST_OUT: float = 0.06          # fist centre beyond the wrist, along the forearm
const HELMET_R: float = 0.12


## Both fists as spheres [[name, centre, r], ...].
static func fists(a: CineActor) -> Array:
	var out: Array = []
	for sd: String in ["L", "R"]:
		var w: Vector3 = a.bone_world("Wrist." + sd)
		var e: Vector3 = a.bone_world("LowerArm." + sd)
		out.append(["fist." + sd, w + (w - e).normalized() * FIST_OUT, FIST_R])
	return out


## Smallest surface gap between spheres [[name, c, r]] and capsules [[part, a, b, r]]: {"g", "from", "to"}.
static func gap_spheres(spheres: Array, caps: Array) -> Dictionary:
	var best: Dictionary = {"g": INF, "from": "", "to": ""}
	for sp: Array in spheres:
		for c: Array in caps:
			var g: float = seg_dist(sp[1], sp[1], c[1], c[2]) - float(sp[2]) - float(c[3])
			if g < float(best["g"]):
				best = {"g": g, "from": String(sp[0]), "to": String(c[0])}
	return best


## Smallest surface gap between two capsule sets: {"g", "from", "to"}.
static func gap_caps(ca: Array, cb: Array) -> Dictionary:
	var best: Dictionary = {"g": INF, "from": "", "to": ""}
	for x: Array in ca:
		for y: Array in cb:
			var g: float = seg_dist(x[1], x[2], y[1], y[2]) - float(x[3]) - float(y[3])
			if g < float(best["g"]):
				best = {"g": g, "from": String(x[0]), "to": String(y[0])}
	return best


## Smallest surface gap from capsules to boxes (9 samples per capsule axis): {"g", "from", "to"}.
static func gap_boxes(ca: Array, boxes: Array) -> Dictionary:
	var best: Dictionary = {"g": INF, "from": "", "to": ""}
	for x: Array in ca:
		for bx: Array in boxes:
			var inv: Transform3D = (bx[1] as Transform3D).affine_inverse()
			for i: int in 9:
				var g: float = _box_sdf(inv * (x[1] as Vector3).lerp(x[2], float(i) / 8.0), bx[2]) - float(x[3])
				if g < float(best["g"]):
					best = {"g": g, "from": String(x[0]), "to": String(bx[0])}
	return best
