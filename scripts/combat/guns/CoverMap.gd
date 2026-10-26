# File: res://scripts/combat/guns/CoverMap.gd
# Cover slots of a lair (spec C-D2), built from simple level data:
#   add_box(xf, size)          a box obstacle (centre transform, full size; only its yaw is used): when its height is low
#                              cover (GunData.COVER_MIN_H..COVER_MAX_H) every vertical face gets slots SLOT_STEP apart,
#                              SLOT_OUT out from the face, on the box's floor;
#   add_marker(pos, normal, h) one hand-placed slot: pos on the floor, normal pointing from the obstacle to the slot;
#   scan(root)                 every node in the group "cover" under root (root included): a CollisionObject3D adds a box
#                              per BoxShape3D child (its global transform and size), any other Node3D adds a marker whose
#                              -Z points at the obstacle (meta "cover_h" = obstacle height, default 1.0).
# A slot protects against a threat when its obstacle stands between them: for a box slot the flat line slot -> threat
# crosses the box (a 2D slab test, so a slot at a box's end does not count against a threat along the box's long side);
# for a marker the threat lies within ~72° of its inward normal (PROTECT_COS). Queries never allocate except
# candidates() / flank_candidates() (decisions only).
class_name CoverMap
extends RefCounted

var pos: PackedVector3Array = PackedVector3Array()
var normal: PackedVector3Array = PackedVector3Array()
var height: PackedFloat32Array = PackedFloat32Array()
var slot_box: PackedInt32Array = PackedInt32Array()      # box index of each slot (-1 = marker)
var box_c: PackedVector3Array = PackedVector3Array()     # box centres (floor height)
var box_ax: PackedVector3Array = PackedVector3Array()    # box x axes (flat)
var box_half: PackedVector2Array = PackedVector2Array()  # box half extents (x, z)
var boxes: int = 0


func count() -> int:
	return pos.size()


func add_marker(p: Vector3, n: Vector3, h: float = 1.0, box: int = -1) -> int:
	pos.append(p)
	normal.append(WeaponMath.flat_dir(n))
	height.append(h)
	slot_box.append(box)
	return pos.size() - 1


## A box obstacle; returns the number of slots it added (0 for a box that is too tall or too flat to crouch behind).
func add_box(xf: Transform3D, size: Vector3) -> int:
	var h: float = size.y
	if h < GunData.COVER_MIN_H - 0.005 or h > GunData.COVER_MAX_H + 0.005:   # float32 sizes: 0.9 is 0.89999998
		return 0
	boxes += 1
	var c: Vector3 = xf.origin
	var floor_y: float = c.y - h * 0.5
	var ax: Vector3 = WeaponMath.flat_dir(xf.basis.x)
	var az: Vector3 = Vector3(-ax.z, 0.0, ax.x)   # perpendicular in the floor plane (the box's own z, sign irrelevant)
	if WeaponMath.flat_dir(xf.basis.z).dot(az) < 0.0:
		az = -az
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var bi: int = box_c.size()
	box_c.append(Vector3(c.x, floor_y, c.z))
	box_ax.append(ax)
	box_half.append(Vector2(hx, hz))
	var added: int = 0
	# faces: (outward normal, half depth to the face, tangent, half length along the face)
	for f: Array in [[ax, hx, az, hz], [-ax, hx, az, hz], [az, hz, ax, hx], [-az, hz, ax, hx]]:
		var n: Vector3 = f[0]
		var t: Vector3 = f[2]
		var half_len: float = float(f[3])
		var fc: Vector3 = Vector3(c.x, floor_y, c.z) + n * float(f[1])
		var usable: float = half_len - GunData.SLOT_EDGE
		var k: int = maxi(1, int(floor(usable * 2.0 / GunData.SLOT_STEP)) + 1) if usable > 0.0 else 1
		for i: int in k:
			var s: float = 0.0 if k == 1 else lerpf(-usable, usable, float(i) / float(k - 1))
			add_marker(fc + t * s + n * GunData.SLOT_OUT, n, h, bi)
			added += 1
	return added


## Every node in the group "cover" under root (see the header). Returns the number of slots added.
func scan(root: Node) -> int:
	if root == null or not root.is_inside_tree():
		return 0
	var before: int = pos.size()
	for n: Node in root.get_tree().get_nodes_in_group("cover"):
		if n != root and not root.is_ancestor_of(n):
			continue
		if n is CollisionObject3D:
			for cs: Node in n.get_children():
				if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
					var c3: CollisionShape3D = cs
					var gx: Transform3D = c3.global_transform
					var sc: Vector3 = gx.basis.get_scale()
					add_box(Transform3D(gx.basis.orthonormalized(), gx.origin), ((c3.shape as BoxShape3D).size) * sc)
		elif n is Node3D:
			var m: Node3D = n
			add_marker(m.global_position, m.global_basis.z, float(m.get_meta("cover_h", 1.0)))
	return pos.size() - before


## The nearest slot within r (flat distance, within 1 m of height) not in `taken` (slot -> occupant); -1 = none.
func nearest(p: Vector3, r: float, taken: Dictionary = {}, me: Object = null) -> int:
	var best: int = -1
	var bd: float = r * r
	for i: int in pos.size():
		var q: Vector3 = pos[i]
		if absf(q.y - p.y) > 1.0:
			continue
		var d2: float = (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if d2 > bd:
			continue
		if taken.has(i) and taken[i] != me:
			continue
		bd = d2
		best = i
	return best


## Free slots within r of p (flat, within 1 m of height), nearest first (the player's cover prompt checks each one's
## reachability in that order).
func near_ids(p: Vector3, r: float, taken: Dictionary = {}, me: Object = null) -> PackedInt32Array:
	var found: Array = []
	for i: int in pos.size():
		var q: Vector3 = pos[i]
		if absf(q.y - p.y) > 1.0:
			continue
		var d2: float = (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if d2 > r * r or (taken.has(i) and taken[i] != me):
			continue
		found.append(Vector2(d2, float(i)))
	return _sorted_ids(found)


## The slot's obstacle stands between it and the threat.
func protects(i: int, threat: Vector3) -> bool:
	if i < 0 or i >= pos.size():
		return false
	var v := Vector3(threat.x - pos[i].x, 0.0, threat.z - pos[i].z)
	var d: float = v.length()
	if d < 0.5:
		return false
	var b: int = slot_box[i]
	if b < 0:
		return (-normal[i]).dot(v / d) >= GunData.PROTECT_COS
	return _crosses_box(b, pos[i], threat)


## The flat segment a -> b crosses box b_i (shrunk 5 cm: a line grazing a corner does not count).
func _crosses_box(b_i: int, a: Vector3, b: Vector3) -> bool:
	var c: Vector3 = box_c[b_i]
	var ax: Vector3 = box_ax[b_i]
	var az := Vector3(-ax.z, 0.0, ax.x)
	var h: Vector2 = box_half[b_i] - Vector2(0.05, 0.05)
	var a2 := Vector2((a - c).dot(ax), (a - c).dot(az))
	var d2 := Vector2((b - c).dot(ax), (b - c).dot(az)) - a2
	var t0: float = 0.0
	var t1: float = 1.0
	for k: int in 2:
		var lo: float = -h[k]
		var hi: float = h[k]
		if absf(d2[k]) < 1e-6:
			if a2[k] < lo or a2[k] > hi:
				return false
			continue
		var ta: float = (lo - a2[k]) / d2[k]
		var tb: float = (hi - a2[k]) / d2[k]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return false
	return true


## Free slots within max_d of `from` that protect against the threat and stand min_threat_d..SIGHT_M from it, best first
## (score: the walk plus how far the threat distance is from a comfortable 12 m).
func candidates(threat: Vector3, from: Vector3, max_d: float, taken: Dictionary, me: Object, min_threat_d: float, max_h: float = INF) -> PackedInt32Array:
	var found: Array = []
	for i: int in pos.size():
		if (taken.has(i) and taken[i] != me) or height[i] > max_h:
			continue
		var walk: float = WeaponMath.flat(pos[i], from)
		if walk > max_d:
			continue
		var dt: float = WeaponMath.flat(pos[i], threat)
		if dt < min_threat_d or dt > GunData.SIGHT_M or not protects(i, threat):
			continue
		found.append(Vector2(walk + 0.25 * absf(dt - 12.0), float(i)))
	return _sorted_ids(found)


## Slots for a flank: like candidates(), at least min_deg around the threat from where `from` stands (closest to 75°).
func flank_candidates(threat: Vector3, from: Vector3, max_d: float, taken: Dictionary, me: Object, min_deg: float, max_h: float = INF) -> PackedInt32Array:
	var found: Array = []
	var a0: Vector3 = WeaponMath.flat_dir(from - threat)
	for i: int in pos.size():
		if (taken.has(i) and taken[i] != me) or height[i] > max_h:
			continue
		var walk: float = WeaponMath.flat(pos[i], from)
		if walk > max_d or walk < 1.0:
			continue
		var dt: float = WeaponMath.flat(pos[i], threat)
		if dt < GunData.COVER_MIN_PLAYER_M or dt > GunData.SIGHT_M or not protects(i, threat):
			continue
		var ang: float = rad_to_deg(a0.angle_to(WeaponMath.flat_dir(pos[i] - threat)))
		if ang < min_deg:
			continue
		found.append(Vector2(walk * 0.3 + absf(ang - 75.0) * 0.1, float(i)))
	return _sorted_ids(found)


## Ids of (score, id) pairs, lowest score first.
static func _sorted_ids(found: Array) -> PackedInt32Array:
	found.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var ids := PackedInt32Array()
	for v: Vector2 in found:
		ids.append(int(v.y))
	return ids
