# File: res://tests/test_mapbuilder.gd
# Headless test for MapBuilder (plan Task 3): builds the vinhomes, corridor and campus regions from
# assets/data/mapdata.json and checks geometry, naming, colliders, the facade UV contract and the time budget.
# Run:  godot --headless --path . --script tests/test_mapbuilder.gd
extends SceneTree

const TIME_BUDGET_MS: int = 5000

var _done: bool = false
var _frames: int = 0


func _initialize() -> void:
	var md: MapData = MapData.load_default()
	assert(md != null, "mapdata.json must load")
	var world := Node3D.new()
	root.add_child(world)
	var problems: int = 0

	# --- vinhomes -------------------------------------------------------------------
	var t0: int = Time.get_ticks_msec()
	var vin: Node3D = MapBuilder.build_region(world, md, "vinhomes", {})
	var ms_vin: int = Time.get_ticks_msec() - t0
	assert(vin != null and vin.get_meta("region", "") == "vinhomes", "region root carries meta region")
	for c: Node in vin.get_children():
		if c.get_meta("region", "") != "vinhomes":
			push_error("top-level node without region meta: " + c.name)
			problems += 1

	# buildings: one MeshInstance3D per building with meta building_id, one StaticBody3D each
	var bld: Array = _building_meshes(vin)
	var n_bld_data: int = md.buildings("vinhomes").size()
	assert(bld.size() >= 40, "at least 40 vinhomes building meshes (got %d)" % bld.size())
	assert(bld.size() == n_bld_data, "one mesh per data building (%d vs %d)" % [bld.size(), n_bld_data])
	var by_id: Dictionary = {}
	for b: Dictionary in md.buildings("vinhomes"):
		by_id[int(b["id"])] = b
	for mi: MeshInstance3D in bld:
		var bodies: int = 0
		var concave: int = 0
		for c: Node in mi.get_children():
			if c is StaticBody3D:
				bodies += 1
				for cs: Node in c.get_children():
					if cs is CollisionShape3D and (cs as CollisionShape3D).shape is ConcavePolygonShape3D:
						concave += 1
		if bodies != 1 or concave != 1:
			push_error("building %s: expected 1 StaticBody3D with 1 ConcavePolygonShape3D, got %d/%d" % [mi.name, bodies, concave])
			problems += 1
		var mesh: ArrayMesh = mi.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() < 2:
			push_error("building %s: expected walls + roof surfaces" % mi.name)
			problems += 1
			continue
		var b: Dictionary = by_id.get(int(mi.get_meta("building_id")), {})
		if b.is_empty():
			push_error("building %s: unknown building_id" % mi.name)
			problems += 1
			continue
		problems += _check_building(mi, mesh, b)

	# BE6: named node, 30 levels x 3.2 m (+ parapet) -> 90..100 m tall
	var be6: MeshInstance3D = vin.find_child("BE6", true, false) as MeshInstance3D
	assert(be6 != null, "node BE6 exists")
	var h: float = be6.mesh.get_aabb().size.y
	assert(h >= 90.0 and h <= 100.0, "BE6 height 90..100 (got %.1f)" % h)
	assert(int(be6.get_meta("building_id")) == 1308943355, "BE6 building_id")
	# facade UV contract on BE6: v = 0 at the roof, v = levels / TILE_STOREYS at the ground, u in tiles of 3 m
	var arrays: Array = be6.mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vmin: float = INF
	var vmax: float = -INF
	var umax: float = -INF
	for uv: Vector2 in uvs:
		vmin = minf(vmin, uv.y)
		vmax = maxf(vmax, uv.y)
		umax = maxf(umax, uv.x)
	assert(absf(vmin) < 0.001 and absf(vmax - 30.0) < 0.001, "BE6 wall v spans 0..30 storeys (got %.2f..%.2f)" % [vmin, vmax])
	assert(umax > 5.0, "BE6 wall u counts 3 m tiles along the edges (got max %.2f)" % umax)
	assert((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() > 0, "normal-mapped facade has tangents")

	# roads: merged per class, every data segment covered by >= 2 triangles
	var road_meshes: Array = _nodes_named_prefix(vin, "Roads_")
	assert(road_meshes.size() >= 2, "merged road meshes per class")
	var seg_data: int = 0
	for r: Dictionary in md.roads("vinhomes"):
		if int(r["lanes"]) > 0:
			seg_data += (r["points"] as Array).size() - 1
	var tris: int = 0
	for mi: MeshInstance3D in road_meshes:
		tris += _tri_count(mi.mesh)
		var has_body: bool = false
		for c: Node in mi.get_children():
			if c is StaticBody3D:
				has_body = true
		assert(has_body, "road mesh %s has a StaticBody3D collider" % mi.name)
	assert(tris >= seg_data * 2, "road triangles %d cover %d carriageway segments" % [tris, seg_data])
	assert(vin.find_child("Kerbs", true, false) != null, "kerb mesh")
	assert(vin.find_child("RoadLines", true, false) != null, "lane overlay mesh")
	assert(vin.find_child("Footways", true, false) != null, "footway mesh")
	assert(vin.find_child("Ground", true, false) != null, "ground mesh")
	assert(vin.find_child("Water", true, false) != null, "water mesh")
	assert(vin.find_child("Trees", true, false) != null, "trees")

	var n_mi_vin: int = _count(vin, "MeshInstance3D")
	var n_mmi_vin: int = _count(vin, "MultiMeshInstance3D")
	print("vinhomes: %d ms, %d MeshInstance3D + %d MultiMeshInstance3D, %d buildings, %d road tris" % [ms_vin, n_mi_vin, n_mmi_vin, bld.size(), tris])
	assert(n_mi_vin < 400, "roads/areas are merged, not one node per way (got %d MeshInstance3D)" % n_mi_vin)

	# --- corridor -----------------------------------------------------------------------
	t0 = Time.get_ticks_msec()
	var cor: Node3D = MapBuilder.build_region(world, md, "corridor", {})
	var ms_cor: int = Time.get_ticks_msec() - t0
	print("corridor: %d ms, %d MeshInstance3D + %d MultiMeshInstance3D" % [ms_cor, _count(cor, "MeshInstance3D"), _count(cor, "MultiMeshInstance3D")])
	assert(_building_meshes(cor).size() == md.buildings("corridor").size(), "corridor buildings")
	# the corridor ground follows the route buffer, never the 5 x 8 km AABB of the tagged ways
	var ground: MeshInstance3D = cor.find_child("Ground", true, false) as MeshInstance3D
	var gb: AABB = ground.mesh.get_aabb()
	var rb: Rect2 = md.bounds("corridor")
	assert(gb.size.x < rb.size.x * 0.95 or gb.size.z < rb.size.y * 0.95, "corridor ground is the buffered route, not bounds()")
	var shape: Array = MapBuilder.region_shape(md, "corridor")
	assert(shape.size() >= 1 and MapBuilder.region_contains(md, "corridor", md.route_points(0.0)[40]), "route inside the corridor buffer")
	assert(not MapBuilder.region_contains(md, "corridor", Vector2(2000.0, 1500.0)), "far point outside the corridor buffer")

	# --- campus (skip + lod options) -------------------------------------------------
	t0 = Time.get_ticks_msec()
	var cam: Node3D = MapBuilder.build_region(world, md, "campus", {"skip_building_ids": [13698121, 605379728], "labels": false})
	var ms_cam: int = Time.get_ticks_msec() - t0
	print("campus: %d ms, %d MeshInstance3D + %d MultiMeshInstance3D" % [ms_cam, _count(cam, "MeshInstance3D"), _count(cam, "MultiMeshInstance3D")])
	assert(_building_meshes(cam).size() == md.buildings("campus").size() - 2, "skip_building_ids honoured")
	assert(cam.find_child("B13698121", true, false) == null, "ring building skipped")
	assert(_count(cam, "Label3D") == 0, "labels off -> no Label3D")
	var lod2: Node3D = MapBuilder.build_region(world, md, "campus", {"lod": 2, "colliders": false})
	assert(_count(lod2, "Label3D") == 0 and _count(lod2, "MultiMeshInstance3D") == 0, "lod 2 has no labels/trees")
	assert(_count(lod2, "StaticBody3D") == 0, "colliders false -> no bodies")

	# --- standalone build_road -----------------------------------------------------------
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(80, 30), Vector2(120, 30)])
	var road: MeshInstance3D = MapBuilder.build_road(world, pts, 7.0, {})
	assert(road != null and _tri_count(road.mesh) >= 6, "build_road ribbon")
	var road_body: bool = false
	var road_kerb: bool = false
	for c: Node in road.get_children():
		if c is StaticBody3D:
			road_body = true
		if c.name == "Kerbs":
			road_kerb = true
	assert(road_body and road_kerb, "build_road collider + kerbs")
	var bridge: MeshInstance3D = MapBuilder.build_road(world, PackedVector2Array([Vector2(0, 100), Vector2(200, 100)]), 8.0, {"bridge": true})
	assert(bridge.mesh.get_aabb().size.y > 5.0, "bridge deck rises ~6 m")

	assert(ms_vin < TIME_BUDGET_MS and ms_cor < TIME_BUDGET_MS and ms_cam < TIME_BUDGET_MS, "each region under %d ms (vin %d, cor %d, cam %d)" % [TIME_BUDGET_MS, ms_vin, ms_cor, ms_cam])
	_done = true
	if problems > 0:
		print("FAILED: %d problem(s)" % problems)
		quit(1)
		return
	print("✅ SUCCESS: MAPBUILDER OK vinhomes=%dms corridor=%dms campus=%dms" % [ms_vin, ms_cor, ms_cam])
	quit(0)


## Walls must face away from the footprint, roof triangles must face up (clockwise front faces).
func _check_building(mi: MeshInstance3D, mesh: ArrayMesh, b: Dictionary) -> int:
	var bad: int = 0
	if not (b["inner"] as Array).is_empty():
		return 0
	var outer: PackedVector2Array = MapData.poly(b["outer"])
	var walls: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = walls[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = walls[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = _indices(walls)
	var n_tri: int = idx.size() / 3 if idx.size() > 0 else verts.size() / 3
	for t: int in range(n_tri):
		var i0: int = idx[t * 3] if idx.size() > 0 else t * 3
		var i1: int = idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
		var i2: int = idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
		var c: Vector3 = (verts[i0] + verts[i1] + verts[i2]) / 3.0
		# Godot front faces wind clockwise seen from the front: the front normal is -(b - a) x (c - a)
		var geo_n: Vector3 = -(verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).normalized()
		if geo_n.dot(norms[i0]) < 0.9:
			bad += 1
			continue
		var out_p := Vector2(c.x + geo_n.x * 0.3, c.z + geo_n.z * 0.3)
		var in_p := Vector2(c.x - geo_n.x * 0.3, c.z - geo_n.z * 0.3)
		if Geometry2D.is_point_in_polygon(out_p, outer) or not Geometry2D.is_point_in_polygon(in_p, outer):
			bad += 1
	var roof: Array = mesh.surface_get_arrays(1)
	var rv: PackedVector3Array = roof[Mesh.ARRAY_VERTEX]
	var ri: PackedInt32Array = _indices(roof)
	var n_roof: int = ri.size() / 3 if ri.size() > 0 else rv.size() / 3
	var roof_bad: int = 0
	for t: int in range(n_roof):
		var i0: int = ri[t * 3] if ri.size() > 0 else t * 3
		var i1: int = ri[t * 3 + 1] if ri.size() > 0 else t * 3 + 1
		var i2: int = ri[t * 3 + 2] if ri.size() > 0 else t * 3 + 2
		if -(rv[i1] - rv[i0]).cross(rv[i2] - rv[i0]).y <= 0.0:
			roof_bad += 1
	if bad > 0 or roof_bad > 0 or n_roof == 0:
		push_error("building %s: %d wall triangles inward/misnormal, %d roof triangles facing down (%d roof tris)" % [mi.name, bad, roof_bad, n_roof])
		return 1
	return 0


func _building_meshes(n: Node) -> Array:
	var out: Array = []
	_collect_buildings(n, out)
	return out


func _collect_buildings(n: Node, out: Array) -> void:
	if n is MeshInstance3D and n.has_meta("building_id"):
		out.append(n)
	for c: Node in n.get_children():
		_collect_buildings(c, out)


func _nodes_named_prefix(n: Node, prefix: String) -> Array:
	var out: Array = []
	if n.name.begins_with(prefix):
		out.append(n)
	for c: Node in n.get_children():
		out.append_array(_nodes_named_prefix(c, prefix))
	return out


func _count(n: Node, cls: String) -> int:
	var k: int = 1 if n.is_class(cls) else 0
	for c: Node in n.get_children():
		k += _count(c, cls)
	return k


func _tri_count(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = _indices(arr)
		n += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## Index array of a surface, empty for non-indexed surfaces (the slot is null then).
func _indices(arr: Array) -> PackedInt32Array:
	var v: Variant = arr[Mesh.ARRAY_INDEX]
	return v if v is PackedInt32Array else PackedInt32Array()


## Watchdog: a failed assert aborts _initialize before quit(); do not idle forever.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames > 3:
		print("FAILED: test aborted before completion (see errors above)")
		quit(2)
		return true
	return false
