# File: res://scripts/horror/HorrorNavGraph.gd
# Hand-placed waypoint graph for the stalkers (spec B-D3): cheaper and more predictable than NavigationServer in 3 m
# corridors. Nodes are points on the floor with optional names; edges are straight walkable lines (the level builder only
# connects points that see each other). Routing = Dijkstra on the ~150 nodes (a few µs), then the route is trimmed so it
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


## Ids of the nodes within r metres (horizontal) of p.
func nodes_within(p: Vector3, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2: float = r * r
	for i: int in points.size():
		var d: Vector3 = points[i] - p
		if d.x * d.x + d.z * d.z <= r2:
			out.append(i)
	return out


## Closest node to p (horizontal). With a physics space, the closest of the NEAREST_CANDIDATES with a clear ray wins.
func nearest(p: Vector3, space: PhysicsDirectSpaceState3D = null) -> int:
	if points.is_empty():
		return -1
	var order: Array = []
	for i: int in points.size():
		var d: Vector3 = points[i] - p
		order.append([d.x * d.x + d.z * d.z, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	if space == null:
		return int(order[0][1])
	for k: int in mini(NEAREST_CANDIDATES, order.size()):
		var id: int = int(order[k][1])
		if clear(space, p, points[id]):
			return id
	return int(order[0][1])


## true when nothing on the world layer blocks the straight line a -> b at knee and chest height (or without a space).
static func clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	if space == null:
		return true
	for h: float in [0.5, 1.3]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(a.x, h, a.z), Vector3(b.x, h, b.z), WORLD_MASK)
		q.collide_with_areas = false
		if not space.intersect_ray(q).is_empty():
			return false
	return true


## Node ids from a to b (both included); empty when unreachable.
func path_ids(a: int, b: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if a < 0 or b < 0:
		return out
	if a == b:
		out.append(a)
		return out
	var n: int = points.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	dist[a] = 0.0
	while true:
		var u: int = -1
		var best: float = INF
		for i: int in n:
			if done[i] == 0 and dist[i] < best:
				best = dist[i]
				u = i
		if u == -1 or u == b:
			break
		done[u] = 1
		for v: int in adj[u]:
			var nd: float = best + points[u].distance_to(points[v])
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if prev[b] == -1:
		return out
	var cur: int = b
	while cur != -1:
		out.append(cur)
		cur = prev[cur]
	out.reverse()
	return out


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
