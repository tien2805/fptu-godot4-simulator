# File: res://scripts/camera/CameraFraming.gd
# Framing maths of the Q1 camera director (spec 2026-10-29 Q1, "automated framing tests"). The same code picks camera
# angles at runtime (CameraDirector cuts, the bike chase takedown cams) and checks the framing in the tests, which stand in
# for screenshots:
#   subject_points(node)            head centre, chest and hips of a character (skeleton bones; fixed heights otherwise)
#   screen_uv(cam, p)               0..1 screen position (Camera3D.unproject_position / the viewport size)
#   in_safe(cam, p, margin, lb)     inside the safe area: margin (8 %) off every edge of the picture left between the
#                                   letterbox bars (lb = the bar height as a fraction of the screen, per bar)
#   los_clear(space, a, b, excl)    no static geometry between a and b (StaticBody3D, not AnimatableBody3D: cars, people,
#                                   enemies and areas never block a view)
#   in_geometry(space, p, r, excl)  static geometry within r of p (the camera's near plane would clip it)
#   view_ok(space, cam_p, pts, excl) / pick(space, candidates, pts, excl): the first candidate position with a clear view
#   report(cam, pts, space, excl)   test summary: points inside the safe area, the view, the camera not in geometry
class_name CameraFraming
extends RefCounted

const HEAD_UP: float = 0.12                # head centre above the CharacterBuilder "Head" bone (a chin pivot)
const FALLBACK_H: Array[float] = [1.62, 1.3, 0.95]
const BONES: Array[String] = ["Head", "Chest", "Hips"]
const NEAR_R: float = 0.12
const MAX_PASSES: int = 8

static var _sphere: SphereShape3D = null


## Head centre, chest and hips (world) of a character node: a CharacterBuilder model (meta "skeleton"), a node holding one
## in `model` / `body` (ThirdPersonController, MeleeEnemy) or a direct child with the meta; else fixed heights above the
## node's origin.
static func subject_points(n: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if n == null or not is_instance_valid(n):
		return out
	var sk: Skeleton3D = skeleton_of(n)
	if sk != null and sk.is_inside_tree():
		var up: Vector3 = sk.global_basis.y.normalized() * HEAD_UP * sk.global_basis.get_scale().y
		for bn: String in BONES:
			var b: int = sk.find_bone(bn)
			if b < 0:
				break
			var p: Vector3 = (sk.global_transform * sk.get_bone_global_pose(b)).origin
			out.append(p + up if bn == "Head" else p)
		if out.size() == BONES.size():
			return out
		out.clear()
	var s: float = n.global_basis.get_scale().y if n.is_inside_tree() else 1.0
	for h: float in FALLBACK_H:
		out.append(n.global_position + Vector3.UP * h * s)
	return out


static func skeleton_of(n: Node) -> Skeleton3D:
	if n == null:
		return null
	if n.has_meta("skeleton"):
		return n.get_meta("skeleton") as Skeleton3D
	for key: String in ["model", "body", "rider_node", "rider"]:
		var m: Variant = n.get(key)
		if m is Node and is_instance_valid(m) and (m as Node).has_meta("skeleton"):
			return (m as Node).get_meta("skeleton") as Skeleton3D
	for c: Node in n.get_children():
		if c.has_meta("skeleton"):
			return c.get_meta("skeleton") as Skeleton3D
	return null


## 0..1 screen position of a world point for cam (x right, y down); behind the camera = Vector2(-1, -1).
static func screen_uv(cam: Camera3D, p: Vector3) -> Vector2:
	if cam == null or not cam.is_inside_tree() or cam.is_position_behind(p):
		return Vector2(-1.0, -1.0)
	var vs: Vector2 = cam.get_viewport().get_visible_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return Vector2(-1.0, -1.0)
	return cam.unproject_position(p) / vs


## Inside the safe area: `margin` off every edge of the picture between the letterbox bars (lb = one bar, 0..0.5).
static func in_safe(cam: Camera3D, p: Vector3, margin: float = CameraRules.SAFE_MARGIN, lb: float = 0.0) -> bool:
	var uv: Vector2 = screen_uv(cam, p)
	if uv.x < 0.0:
		return false
	var band: float = 1.0 - 2.0 * lb
	return uv.x >= margin and uv.x <= 1.0 - margin and uv.y >= lb + margin * band and uv.y <= 1.0 - lb - margin * band


## True when nothing static stands between a and b. Bodies in `excl`, non-static bodies (people, enemies, cars: the camera
## goes through them) and areas are stepped through.
static func los_clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, excl: Array[RID] = []) -> bool:
	if space == null:
		return true
	var rq := PhysicsRayQueryParameters3D.create(a, b)
	rq.collide_with_areas = false
	rq.hit_from_inside = false
	var ex: Array[RID] = excl.duplicate()
	for i: int in MAX_PASSES:
		rq.exclude = ex
		var h: Dictionary = space.intersect_ray(rq)
		if h.is_empty():
			return true
		var col: Object = h.get("collider")
		if is_blocker(col):
			return false
		ex.append(h["rid"])
	return true


## Static geometry that hides a subject or holds a camera: StaticBody3D (and CSG / GridMap colliders), never an
## AnimatableBody3D (traffic), a CharacterBody3D (people, enemies, the player) or a RigidBody3D.
static func is_blocker(col: Object) -> bool:
	if col == null:
		return false
	if col is AnimatableBody3D or col is CharacterBody3D or col is RigidBody3D or col is Area3D:
		return false
	return col is StaticBody3D or col is CSGShape3D or col is GridMap


## Static geometry within r of p.
static func in_geometry(space: PhysicsDirectSpaceState3D, p: Vector3, r: float = NEAR_R, excl: Array[RID] = []) -> bool:
	if space == null:
		return false
	if _sphere == null:
		_sphere = SphereShape3D.new()
	_sphere.radius = r
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere
	q.transform = Transform3D(Basis.IDENTITY, p)
	q.collide_with_areas = false
	q.exclude = excl
	for h: Dictionary in space.intersect_shape(q, 16):
		if is_blocker(h.get("collider")):
			return true
	return false


## A camera at cam_p sees every point (no static geometry in between) and is not in geometry.
static func view_ok(space: PhysicsDirectSpaceState3D, cam_p: Vector3, pts: PackedVector3Array, excl: Array[RID] = []) -> bool:
	if in_geometry(space, cam_p, NEAR_R, excl):
		return false
	for p: Vector3 in pts:
		if not los_clear(space, cam_p, p, excl):
			return false
	return true


## Index of the first candidate with view_ok; else the one that sees the most points (ties: the first); -1 when empty.
static func pick(space: PhysicsDirectSpaceState3D, candidates: Array[Vector3], pts: PackedVector3Array, excl: Array[RID] = []) -> int:
	var best: int = -1
	var best_n: int = -1
	for i: int in candidates.size():
		var c: Vector3 = candidates[i]
		if view_ok(space, c, pts, excl):
			return i
		var n: int = 0
		if not in_geometry(space, c, NEAR_R, excl):
			for p: Vector3 in pts:
				if los_clear(space, c, p, excl):
					n += 1
		if n > best_n:
			best_n = n
			best = i
	return best


## Test summary for cam and the subject points: {"inside": points in the safe area, "total", "out": [indices],
## "los": every point visible, "in_geo": the camera in geometry, "ok": all of it}.
static func report(cam: Camera3D, pts: PackedVector3Array, space: PhysicsDirectSpaceState3D, excl: Array[RID] = [],
		margin: float = CameraRules.SAFE_MARGIN, lb: float = 0.0) -> Dictionary:
	var out: Array[int] = []
	var los: bool = true
	var cp: Vector3 = cam.global_position
	for i: int in pts.size():
		if not in_safe(cam, pts[i], margin, lb):
			out.append(i)
		if space != null and not los_clear(space, cp, pts[i], excl):
			los = false
	var geo: bool = in_geometry(space, cp, NEAR_R, excl) if space != null else false
	return {"inside": pts.size() - out.size(), "total": pts.size(), "out": out, "los": los, "in_geo": geo,
		"ok": out.is_empty() and los and not geo}


## One line for a failed report: which points left the safe area and where.
static func describe(cam: Camera3D, pts: PackedVector3Array, rep: Dictionary) -> String:
	var parts: PackedStringArray = []
	for i: int in rep["out"]:
		var uv: Vector2 = screen_uv(cam, pts[i])
		parts.append("%s at (%.2f, %.2f)" % [["head", "chest", "hips", "p3", "p4", "p5"][mini(i, 5)], uv.x, uv.y])
	if not bool(rep["los"]):
		parts.append("view blocked")
	if bool(rep["in_geo"]):
		parts.append("camera in geometry")
	return ", ".join(parts)
