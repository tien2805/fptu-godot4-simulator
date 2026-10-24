# File: res://scripts/weapons/WeaponMath.gd
# Pure math of Phase W (no nodes): wheel wedges (Task 1), cones (Task 3), analytic ray tests and spread (Task 4), the dép
# boomerang path (Task 6). Wheel angles: 0 = up, clockwise, screen y down.
class_name WeaponMath
extends RefCounted


## Wheel wedge (0..count-1, slot 0 at the top, clockwise) under a stick vector in screen space; -1 inside the dead zone.
static func wedge_for(v: Vector2, dead_zone: float, count: int = 8) -> int:
	if v.length() < dead_zone:
		return -1
	var a: float = fposmod(atan2(v.x, -v.y), TAU)
	var w: float = TAU / float(count)
	return int(floor((a + w * 0.5) / w)) % count


## Centre angle (rad, 0 = up, clockwise) of wedge i.
static func wedge_angle(i: int, count: int = 8) -> float:
	return TAU * float(i) / float(count)


## Unit screen vector at wheel angle a (0 = up, clockwise; y down).
static func wedge_point(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))


## Horizontal distance (x, z) between two points.
static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Horizontal unit direction of v (+Z when v is vertical or zero).
static func flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-6 else Vector3(0.0, 0.0, 1.0)


## p inside the horizontal cone at apex along dir (half angle half_rad, length reach), within 2 m of the apex height.
static func in_cone(apex: Vector3, dir: Vector3, half_rad: float, reach: float, p: Vector3) -> bool:
	var v := Vector3(p.x - apex.x, 0.0, p.z - apex.z)
	var d: float = v.length()
	if d > reach or absf(p.y - apex.y) > 2.0:
		return false
	if d < 0.05:
		return true
	return flat_dir(dir).dot(v / d) >= cos(half_rad) - 1e-6


## Ray (origin o, unit direction d) against an upright capsule standing on `base` (radius r, total height h): distance along
## the ray to the hit, or -1. (Closest approach to the capsule axis segment, then back off by half the chord.)
static func ray_capsule(o: Vector3, d: Vector3, base: Vector3, r: float, h: float) -> float:
	var a: Vector3 = base + Vector3(0.0, r, 0.0)
	var u: Vector3 = Vector3(0.0, maxf(h - 2.0 * r, 0.0), 0.0)
	var uu: float = u.length_squared()
	var t: float = maxf(0.0, (a + u * 0.5 - o).dot(d))
	var s: float = 0.5
	for i: int in 4:
		s = clampf((o + d * t - a).dot(u) / uu, 0.0, 1.0) if uu > 1e-6 else 0.0
		t = maxf(0.0, (a + u * s - o).dot(d))
	var dist: float = (o + d * t).distance_to(a + u * s)
	if dist > r:
		return -1.0
	return maxf(0.0, t - sqrt(r * r - dist * dist))


## Ray against a box (centre frame xf with an orthonormal basis, half extents `half`): entry distance, 0 if o is inside, -1 = miss.
static func ray_box(o: Vector3, d: Vector3, xf: Transform3D, half: Vector3) -> float:
	var inv: Transform3D = xf.affine_inverse()
	var lo: Vector3 = inv * o
	var ld: Vector3 = inv.basis * d
	var tmin: float = 0.0
	var tmax: float = INF
	for i: int in 3:
		if absf(ld[i]) < 1e-8:
			if lo[i] < -half[i] or lo[i] > half[i]:
				return -1.0
			continue
		var t1: float = (-half[i] - lo[i]) / ld[i]
		var t2: float = (half[i] - lo[i]) / ld[i]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
		if tmin > tmax:
			return -1.0
	return tmin


## Random unit direction inside a cone of half angle `deg` around d (uniform over the disc).
static func spread_dir(d: Vector3, deg: float, rng: RandomNumberGenerator) -> Vector3:
	var n: Vector3 = d.normalized()
	if deg <= 0.0:
		return n
	var p1: Vector3 = n.cross(Vector3.UP)
	if p1.length_squared() < 1e-6:
		p1 = n.cross(Vector3.RIGHT)
	p1 = p1.normalized()
	var p2: Vector3 = n.cross(p1)
	var a: float = deg_to_rad(deg) * sqrt(rng.randf())
	var phi: float = rng.randf() * TAU
	return (n * cos(a) + (p1 * cos(phi) + p2 * sin(phi)) * sin(a)).normalized()


## Dép tổ ong path at u (0..1): straight out along fwd to `reach` m at u = 0.5 (forward = reach·sin(πu)), then curving back on
## the right side (lateral = side·sin(2π(u − 0.5)) for u > 0.5), ending where it started.
static func boomerang_point(start: Vector3, fwd: Vector3, right: Vector3, reach: float, side: float, u: float) -> Vector3:
	var lateral: float = side * sin(TAU * (u - 0.5)) if u > 0.5 else 0.0
	return start + fwd * (reach * sin(PI * u)) + right * lateral
