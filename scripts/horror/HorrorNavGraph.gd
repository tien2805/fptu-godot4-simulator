# File: res://scripts/horror/HorrorNavGraph.gd
# Hand-placed waypoint graph for the stalkers (spec B-D3): cheaper and more predictable than NavigationServer in 3 m
# corridors. Nodes are points on the floor with optional names; edges are straight walkable lines (the level builder only
# connects points that see each other). Routing = Dijkstra with a binary heap on the ~120 nodes, then the route is trimmed so it
# does not walk back to a node it is already past (only when that shortcut has a clear ray).
# nearest(pos, space): the closest node, preferring one with a clear ray at knee and chest height when a physics space is
# given (a point in a classroom never snaps to a corridor node behind the wall).
class_name HorrorNavGraph
extends RefCounted

const WORLD_MASK: int = 1
const NEAREST_CANDIDATES: int = 6
## A target this close with a clear line is walked to straight (no detour through a node behind it).
const DIRECT_R: float = 12.0

var points: PackedVector3Array = PackedVector3Array()
var adj: Array[PackedInt32Array] = []
var names: Dictionary = {}   # name -> id
var no_wander: Dictionary = {}   # id -> true


func add_node(p: Vector3, node_name: String = "") -> int:
	points.append(Vector3(p.x, 0.0, p.z))
	adj.append(PackedInt32Array())
	var id: int = points.size() - 1
	if node_name != "":
		names[node_name] = id
	return id


func connect_nodes(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0:
		return
	if not adj[a].has(b):
		adj[a].append(b)
	if not adj[b].has(a):
		adj[b].append(a)


func id_of(node_name: String) -> int:
	return int(names.get(node_name, -1))


func size() -> int:
	return points.size()


func pos(id: int) -> Vector3:
	return points[id]


## Ids of the nodes within r metres (horizontal) of p; wander_only skips the no-wander nodes (hiding-spot exit points).
func nodes_within(p: Vector3, r: float, wander_only: bool = false) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2: float = r * r
	for i: int in points.size():
		if wander_only and no_wander.has(i):
			continue
		var d: Vector3 = points[i] - p
		if d.x * d.x + d.z * d.z <= r2:
			out.append(i)
	return out


## Routes may pass the node, searches never pick it as a place to stand and look (it sits on a hiding spot's way out).
func set_no_wander(id: int) -> void:
	if id >= 0:
		no_wander[id] = true


## Closest node to p (horizontal). With a physics space, the closest of the NEAREST_CANDIDATES with a clear ray wins.
## No allocation beyond two small fixed arrays (a partial insertion sort of the candidates).
func nearest(p: Vector3, space: PhysicsDirectSpaceState3D = null) -> int:
	if points.is_empty():
		return -1
	var k: int = 1 if space == null else mini(NEAREST_CANDIDATES, points.size())
	var best_d := PackedFloat32Array()
	best_d.resize(k)
	best_d.fill(INF)
	var best_i := PackedInt32Array()
	best_i.resize(k)
	best_i.fill(-1)
	for i: int in points.size():
		var dv: Vector3 = points[i] - p
		var d2: float = dv.x * dv.x + dv.z * dv.z
		if d2 >= best_d[k - 1]:
			continue
		var j: int = k - 1
		while j > 0 and best_d[j - 1] > d2:
			best_d[j] = best_d[j - 1]
			best_i[j] = best_i[j - 1]
			j -= 1
		best_d[j] = d2
		best_i[j] = i
	if space == null:
		return best_i[0]
	for c: int in k:
		if best_i[c] >= 0 and clear(space, p, points[best_i[c]]):
			return best_i[c]
	return best_i[0]


## true when nothing on the world layer blocks the straight line a -> b at knee and chest height (or without a space).
static func clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	if space == null:
		return true
	for h: float in [0.5, 1.3]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(a.x, h, a.z), Vector3(b.x, h, b.z), WORLD_MASK)
		q.collide_with_areas = false
		q.hit_from_inside = true
		if not space.intersect_ray(q).is_empty():
			return false
	return true


## Node ids from a to b (both included); empty when unreachable. Dijkstra with a binary heap (lazy deletion).
func path_ids(a: int, b: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if a < 0 or b < 0:
		return out
	if a == b:
		out.append(a)
		return out
	var n: int = points.size()
	var dist := PackedFloat64Array()   # 64-bit like the heap keys: a float32 round-down would make the stale check skip nodes
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var hk: Array[float] = []   # heap keys (typed Arrays: passed by reference, unlike Packed arrays)
	var hv: Array[int] = []     # heap node ids
	dist[a] = 0.0
	_push(hk, hv, 0.0, a)
	while not hk.is_empty():
		var du: float = hk[0]
		var u: int = hv[0]
		_pop(hk, hv)
		if du > dist[u]:
			continue
		if u == b:
			break
		for v: int in adj[u]:
			var nd: float = du + points[u].distance_to(points[v])
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				_push(hk, hv, nd, v)
	if prev[b] == -1:
		return out
	var cur: int = b
	while cur != -1:
		out.append(cur)
		cur = prev[cur]
	out.reverse()
	return out


static func _push(hk: Array[float], hv: Array[int], key: float, id: int) -> void:
	hk.append(key)
	hv.append(id)
	var i: int = hk.size() - 1
	while i > 0:
		var par: int = (i - 1) >> 1
		if hk[par] <= hk[i]:
			break
		var tk: float = hk[par]
		hk[par] = hk[i]
		hk[i] = tk
		var tv: int = hv[par]
		hv[par] = hv[i]
		hv[i] = tv
		i = par


static func _pop(hk: Array[float], hv: Array[int]) -> void:
	var last: int = hk.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i: int = 0
	while true:
		var l: int = 2 * i + 1
		if l >= last:
			break
		var m: int = l
		if l + 1 < last and hk[l + 1] < hk[l]:
			m = l + 1
		if hk[i] <= hk[m]:
			break
		var tk: float = hk[m]
		hk[m] = hk[i]
		hk[i] = tk
		var tv: int = hv[m]
		hv[m] = hv[i]
		hv[i] = tv
		i = m


func reachable(a: int, b: int) -> bool:
	return not path_ids(a, b).is_empty()


## Walkable points from `from` to `to`: straight when close and clear, else the nearest nodes of both ends, the node path
## between them, then `to` itself.
func route(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D = null) -> PackedVector3Array:
	var pts := PackedVector3Array()
	if Vector2(to.x - from.x, to.z - from.z).length() <= DIRECT_R and clear(space, from, to):
		pts.append(Vector3(to.x, 0.0, to.z))
		return pts
	var a: int = nearest(from, space)
	var b: int = nearest(to, space)
	if a >= 0 and b >= 0:
		for id: int in path_ids(a, b):
			pts.append(points[id])
	if pts.size() >= 2 and from.distance_to(pts[1]) <= pts[0].distance_to(pts[1]) and clear(space, from, pts[1]):
		pts.remove_at(0)
	if pts.size() >= 2 and to.distance_to(pts[pts.size() - 2]) <= pts[pts.size() - 1].distance_to(pts[pts.size() - 2]) \
			and clear(space, to, pts[pts.size() - 2]):
		pts.remove_at(pts.size() - 1)
	pts.append(Vector3(to.x, 0.0, to.z))
	return pts
