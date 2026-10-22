# File: res://tests/test_mapbuilder.gd
# Headless test for MapBuilder (plan Task 3 + Microsoft footprints): builds the vinhomes, corridor and campus regions
# from assets/data/mapdata.json and checks geometry, naming, colliders, the facade UV contract, the merged msft
# chunks (MSChunk_<gx>_<gz>: every msft id in exactly one chunk, lean colliders (one convex / concave shape per
# footprint piece, < 40 % of the render triangles, nothing above the roofs), <= 30-triangle water tanks, visibility
# range, outward walls, nothing on a carriageway or footway ribbon or inside an OSM building, no piece under 1 m
# wide) and the time budget; palms (plan VC-2, header "PALMS" of MapBuilder) only with opts.palms: one PalmField of
# 2 MultiMeshInstance3D, visual-only unless palm_colliders (placement rules: tests/test_palms.gd). Every check goes
# through _check() (a failed assert inside _initialize would hang a --script run); a watchdog quits if _initialize
# aborts anyway.
# Run:  godot --headless --path . --script tests/test_mapbuilder.gd
extends SceneTree

const TIME_BUDGET_MS: int = 5000
const MAX_MESH_INSTANCES: int = 600
const MAX_TANK_TRIS: int = 30
const MAX_COLLIDER_SHARE: float = 0.4      # collider faces / render triangles of one msft chunk
const FOOT_CELL: float = 32.0

var _done: bool = false
var _frames: int = 0
var _problems: int = 0
var _foot_quads: Array = []                # [PackedVector2Array drawn footway quad, Rect2] (whole map)
var _foot_quad_hash: Dictionary = {}       # Vector2i FOOT_CELL cell -> Array[int] into _foot_quads


func _initialize() -> void:
	var summary: String = _run()
	_done = true
	if _problems > 0 or summary == "":
		print("FAILED: %d problem(s)" % maxi(1, _problems))
		quit(1)
		return
	print("✅ SUCCESS: MAPBUILDER OK " + summary)
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_problems += 1
		print("FAILED: " + msg)
	return ok


func _run() -> String:
	var md: MapData = MapData.load_default()
	if not _check(md != null, "mapdata.json must load"):
		return ""
	var world := Node3D.new()
	root.add_child(world)

	# --- vinhomes -------------------------------------------------------------------
	var t0: int = Time.get_ticks_msec()
	var vin: Node3D = MapBuilder.build_region(world, md, "vinhomes", {})
	var ms_vin: int = Time.get_ticks_msec() - t0
	if not _check(vin != null and vin.get_meta("region", "") == "vinhomes", "region root carries meta region"):
		return ""
	for c: Node in vin.get_children():
		_check(c.get_meta("region", "") == "vinhomes", "top-level node %s carries meta region" % c.name)

	# OSM buildings: one MeshInstance3D per building with meta building_id, one StaticBody3D each
	var bld: Array = _building_meshes(vin)
	var osm_vin: Array = _osm(md, "vinhomes")
	_check(bld.size() >= 40, "at least 40 vinhomes OSM building meshes (got %d)" % bld.size())
	_check(bld.size() == osm_vin.size(), "one mesh per OSM building (%d vs %d)" % [bld.size(), osm_vin.size()])
	var by_id: Dictionary = {}
	for b: Dictionary in osm_vin:
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
		_check(bodies == 1 and concave == 1, "building %s: expected 1 StaticBody3D with 1 ConcavePolygonShape3D, got %d/%d" % [mi.name, bodies, concave])
		var mesh: ArrayMesh = mi.mesh as ArrayMesh
		if not _check(mesh != null and mesh.get_surface_count() >= 2, "building %s: expected walls + roof surfaces" % mi.name):
			continue
		var b: Dictionary = by_id.get(int(mi.get_meta("building_id")), {})
		if not _check(not b.is_empty(), "building %s: building_id is not an OSM building of the region" % mi.name):
			continue
		_check_building(mi, mesh, b)

	# BE6: named node, 30 levels x 3.2 m (+ parapet) -> 90..100 m tall
	var be6: MeshInstance3D = vin.find_child("BE6", true, false) as MeshInstance3D
	if not _check(be6 != null, "node BE6 exists"):
		return ""
	var h: float = be6.mesh.get_aabb().size.y
	_check(h >= 90.0 and h <= 100.0, "BE6 height 90..100 (got %.1f)" % h)
	_check(int(be6.get_meta("building_id")) == 1308943355, "BE6 building_id")
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
	_check(absf(vmin) < 0.001 and absf(vmax - 30.0) < 0.001, "BE6 wall v spans 0..30 storeys (got %.2f..%.2f)" % [vmin, vmax])
	_check(umax > 5.0, "BE6 wall u counts 3 m tiles along the edges (got max %.2f)" % umax)
	_check((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() > 0, "normal-mapped facade has tangents")

	# roads: merged per class, every data segment covered by >= 2 triangles
	var road_meshes: Array = _nodes_named_prefix(vin, "Roads_")
	_check(road_meshes.size() >= 2, "merged road meshes per class")
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
		_check(has_body, "road mesh %s has a StaticBody3D collider" % mi.name)
	_check(tris >= seg_data * 2, "road triangles %d cover %d carriageway segments" % [tris, seg_data])
	for n: String in ["Kerbs", "RoadLines", "Footways", "Ground", "Water", "Trees"]:
		_check(vin.find_child(n, true, false) != null, "vinhomes has %s" % n)

	var n_mi_vin: int = _count(vin, "MeshInstance3D")
	var n_mmi_vin: int = _count(vin, "MultiMeshInstance3D")
	var ch_vin: int = _check_msft(md, vin, "vinhomes", [], 0, true)
	print("vinhomes: %d ms, %d MeshInstance3D + %d MultiMeshInstance3D, %d OSM buildings, %d msft chunks, %d road tris" % [ms_vin, n_mi_vin, n_mmi_vin, bld.size(), ch_vin, tris])
	_check(n_mi_vin < MAX_MESH_INSTANCES, "vinhomes: roads/areas/msft are merged, not one node per way or house (got %d MeshInstance3D)" % n_mi_vin)
	_check(ch_vin > 0, "vinhomes has msft chunks")
	_check_chunk_walls(md, vin, "vinhomes", [])

	# --- corridor -----------------------------------------------------------------------
	t0 = Time.get_ticks_msec()
	var cor: Node3D = MapBuilder.build_region(world, md, "corridor", {})
	var ms_cor: int = Time.get_ticks_msec() - t0
	var n_mi_cor: int = _count(cor, "MeshInstance3D")
	var ch_cor: int = _check_msft(md, cor, "corridor", [], 0, true)
	print("corridor: %d ms, %d MeshInstance3D + %d MultiMeshInstance3D, %d msft chunks" % [ms_cor, n_mi_cor, _count(cor, "MultiMeshInstance3D"), ch_cor])
	_check(_building_meshes(cor).size() == _osm(md, "corridor").size(), "corridor: one mesh per OSM building (%d vs %d)" % [_building_meshes(cor).size(), _osm(md, "corridor").size()])
	_check(n_mi_cor < MAX_MESH_INSTANCES, "corridor: < %d MeshInstance3D (got %d)" % [MAX_MESH_INSTANCES, n_mi_cor])
	_check(ch_cor > 0, "corridor has msft chunks")
	_check_chunk_walls(md, cor, "corridor", [])
	# the corridor ground follows the route buffer, never the 5 x 8 km AABB of the tagged ways
	var ground: MeshInstance3D = cor.find_child("Ground", true, false) as MeshInstance3D
	if _check(ground != null, "corridor ground mesh"):
		var gb: AABB = ground.mesh.get_aabb()
		var rb: Rect2 = md.bounds("corridor")
		_check(gb.size.x < rb.size.x * 0.95 or gb.size.z < rb.size.y * 0.95, "corridor ground is the buffered route, not bounds()")
	var shape: Array = MapBuilder.region_shape(md, "corridor")
	_check(shape.size() >= 1 and MapBuilder.region_contains(md, "corridor", md.route_points(0.0)[40]), "route inside the corridor buffer")
	_check(not MapBuilder.region_contains(md, "corridor", Vector2(2000.0, 1500.0)), "far point outside the corridor buffer")

	# --- campus (skip + lod options; one msft id skipped too) ----------------------------
	var cam_msft: Array = md.buildings("campus").filter(func(b: Dictionary) -> bool: return MapBuilder.is_msft(b))
	if not _check(cam_msft.size() > 0, "campus has msft buildings"):
		return ""
	var skip: Array = [13698121, 605379728, int(cam_msft[0]["id"])]
	t0 = Time.get_ticks_msec()
	var cam: Node3D = MapBuilder.build_region(world, md, "campus", {"skip_building_ids": skip, "labels": false})
	var ms_cam: int = Time.get_ticks_msec() - t0
	var n_mi_cam: int = _count(cam, "MeshInstance3D")
	var ch_cam: int = _check_msft(md, cam, "campus", skip, 0, true)
	print("campus: %d ms, %d MeshInstance3D + %d MultiMeshInstance3D, %d msft chunks" % [ms_cam, n_mi_cam, _count(cam, "MultiMeshInstance3D"), ch_cam])
	_check(_building_meshes(cam).size() == _osm(md, "campus").size() - 2, "skip_building_ids honoured for OSM buildings")
	_check(cam.find_child("B13698121", true, false) == null, "ring building skipped")
	_check(_count(cam, "Label3D") == 0, "labels off -> no Label3D")
	_check(n_mi_cam < MAX_MESH_INSTANCES, "campus: < %d MeshInstance3D (got %d)" % [MAX_MESH_INSTANCES, n_mi_cam])
	var lod2: Node3D = MapBuilder.build_region(world, md, "campus", {"lod": 2, "colliders": false})
	_check(_count(lod2, "Label3D") == 0 and _count(lod2, "MultiMeshInstance3D") == 0, "lod 2 has no labels/trees")
	_check(_count(lod2, "StaticBody3D") == 0, "colliders false -> no bodies")
	_check(_check_msft(md, lod2, "campus", [], 2, false) > 0, "lod 2 keeps the msft chunks (boxes)")

	# --- palms (VC-2): nothing without opts.palms, one visual-only PalmField with it -------------
	for r: Node3D in [vin, cor, cam, lod2]:
		_check(r.find_child("PalmField", true, false) == null, "%s: no opts.palms -> no PalmField" % r.name)
	var palm_reg: Node3D = MapBuilder.build_region(world, md, "campus", {"lod": 2, "colliders": false, "palms": true})
	var pf: Node3D = palm_reg.get_node_or_null("PalmField") as Node3D
	if _check(pf != null and palm_reg.find_children("PalmField", "", true, false).size() == 1, "opts.palms -> one PalmField under the region root"):
		_check(_count(pf, "MultiMeshInstance3D") == 2 and int(pf.get_meta("palm_count", 0)) >= 200, "PalmField: 2 MultiMeshInstance3D, >= 200 palms (got %d)" % int(pf.get_meta("palm_count", 0)))
		_check(_count(palm_reg, "StaticBody3D") == 0, "palms are visual-only unless palm_colliders")
		_check(String(pf.get_meta("region", "")) == "campus", "PalmField carries meta region")
	var palm_col: Node3D = MapBuilder.build_region(world, md, "campus", {"lod": 2, "colliders": false, "palms": true, "palm_colliders": true})
	var pcf: Node3D = palm_col.get_node_or_null("PalmField") as Node3D
	if _check(pcf != null, "palm_colliders build has a PalmField"):
		var bodies: Array = pcf.find_children("*", "StaticBody3D", true, false)
		_check(bodies.size() == 1 and (bodies[0] as Node).get_child_count() == int(pcf.get_meta("palm_count", 0)), "palm_colliders -> one StaticBody3D, one shape per palm")
	palm_reg.free()
	palm_col.free()

	# --- standalone build_road -----------------------------------------------------------
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(80, 30), Vector2(120, 30)])
	var road: MeshInstance3D = MapBuilder.build_road(world, pts, 7.0, {})
	if _check(road != null and _tri_count(road.mesh) >= 6, "build_road ribbon"):
		var road_body: bool = false
		var road_kerb: bool = false
		for c: Node in road.get_children():
			if c is StaticBody3D:
				road_body = true
			if c.name == "Kerbs":
				road_kerb = true
		_check(road_body and road_kerb, "build_road collider + kerbs")
	var bridge: MeshInstance3D = MapBuilder.build_road(world, PackedVector2Array([Vector2(0, 100), Vector2(200, 100)]), 8.0, {"bridge": true})
	_check(bridge != null and bridge.mesh.get_aabb().size.y > 5.0, "bridge deck rises ~6 m")

	# --- tank-only build: one rooftop water tank on a 6 x 12 m roof at 7.2 m ------------------
	_check_tank_only()

	_check(ms_vin < TIME_BUDGET_MS and ms_cor < TIME_BUDGET_MS and ms_cam < TIME_BUDGET_MS, "each region under %d ms (vin %d, cor %d, cam %d)" % [TIME_BUDGET_MS, ms_vin, ms_cor, ms_cam])
	return "vinhomes=%dms corridor=%dms campus=%dms chunks=%d/%d/%d" % [ms_vin, ms_cor, ms_cam, ch_vin, ch_cor, ch_cam]


## Microsoft chunks of a built region: every unskipped msft id of the region in exactly one chunk (and in the chunk
## of its centroid cell), meta source, lean colliders (when `colliders`: one StaticBody3D holding only
## ConvexPolygonShape3D / ConcavePolygonShape3D shapes, one per footprint piece, from the ground up to the roofs, faces
## < MAX_COLLIDER_SHARE of the render triangles), visibility range by lod, no Label3D, ~40 % rooftop tanks of
## <= MAX_TANK_TRIS triangles, and every final footprint off the carriageways and footways, outside the OSM buildings
## and at least 1 m wide. Returns the chunk count.
func _check_msft(md: MapData, region_root: Node3D, region: String, skip: Array, lod: int, colliders: bool) -> int:
	var holder: Node = region_root.get_node_or_null("Buildings")
	if not _check(holder != null, "%s has a Buildings node" % region):
		return 0
	var want: Dictionary = {}
	var by_id: Dictionary = {}
	for b: Dictionary in md.buildings(region):
		if MapBuilder.is_msft(b):
			by_id[int(b["id"])] = b
			if not skip.has(int(b["id"])):
				want[int(b["id"])] = 0
	var dropped: Array = holder.get_meta("msft_dropped_ids", [])
	_check(dropped.is_empty(), "%s: no msft footprint clipped away entirely (dropped %s)" % [region, str(dropped)])
	var fps: Array = MapBuilder.msft_footprints(md, region, skip)
	var pieces_of: Dictionary = {}
	for e: Array in fps:
		pieces_of[int(e[0]["id"])] = (e[1] as Array).size()
	var vis_end: float = 700.0 if lod == 0 else 450.0
	var chunks: Array = []
	var tanks: int = 0
	var n_convex: int = 0
	var n_concave: int = 0
	var col_faces_all: int = 0
	var render_all: int = 0
	for c: Node in holder.get_children():
		if not c.name.begins_with("MSChunk_"):
			continue
		var mi: MeshInstance3D = c as MeshInstance3D
		if not _check(mi != null and mi.mesh != null, "%s/%s is a MeshInstance3D with a mesh" % [region, c.name]):
			continue
		chunks.append(mi)
		_check(mi.get_meta("source", "") == "msft" and not mi.has_meta("building_id"), "%s/%s: meta source msft, no per-building id" % [region, mi.name])
		var ids: Array = mi.get_meta("building_ids", [])
		_check(ids.size() > 0, "%s/%s lists its building_ids" % [region, mi.name])
		for id_v: Variant in ids:
			var id: int = int(id_v)
			if not _check(want.has(id), "%s/%s holds id %d, not an unskipped msft building of the region" % [region, mi.name, id]):
				continue
			want[id] = int(want[id]) + 1
			var key: Vector2i = MapBuilder.msft_chunk_key(by_id[id])
			_check(mi.name == "MSChunk_%d_%d" % [key.x, key.y], "%s: building %d sits in %s, its centroid cell is %s" % [region, id, mi.name, str(key)])
		_check(absf(mi.visibility_range_end - vis_end) < 0.01 and absf(mi.visibility_range_end_margin - 40.0) < 0.01 and mi.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF, "%s/%s: visibility_range_end %.0f (lod %d), margin 40, fade self" % [region, mi.name, vis_end, lod])
		var bodies: int = 0
		var shapes: int = 0
		var others: int = 0
		var col_faces: int = 0
		var col_top: float = -INF
		var col_bottom: float = INF
		for k: Node in mi.get_children():
			if k is StaticBody3D:
				bodies += 1
				for cs: Node in k.get_children():
					var shape: Shape3D = (cs as CollisionShape3D).shape if cs is CollisionShape3D else null
					var pts := PackedVector3Array()
					if shape is ConcavePolygonShape3D:
						pts = (shape as ConcavePolygonShape3D).get_faces()
						col_faces += pts.size() / 3
						n_concave += 1
					elif shape is ConvexPolygonShape3D:
						pts = (shape as ConvexPolygonShape3D).points
						col_faces += 2 * pts.size() - 4   # triangles of a convex hull with that many vertices (upper bound)
						n_convex += 1
					else:
						others += 1
						continue
					shapes += 1
					for v: Vector3 in pts:
						col_top = maxf(col_top, v.y)
						col_bottom = minf(col_bottom, v.y)
		var render_tris: int = _tri_count(mi.mesh)
		if colliders:
			var want_shapes: int = 0
			var roof_top: float = 0.0
			for id_v: Variant in ids:
				want_shapes += int(pieces_of.get(int(id_v), 0))
				if by_id.has(int(id_v)):
					var hb: float = MapBuilder._building_height(by_id[int(id_v)])
					roof_top = maxf(roof_top, maxf(3.0, hb) if lod >= 2 else hb)
			_check(bodies == 1 and shapes >= 1 and others == 0, "%s/%s: 1 StaticBody3D holding only ConvexPolygonShape3D / ConcavePolygonShape3D shapes (got %d bodies, %d shapes, %d other children)" % [region, mi.name, bodies, shapes, others])
			_check(shapes == want_shapes, "%s/%s: one collider shape per footprint piece (%d shapes, %d pieces)" % [region, mi.name, shapes, want_shapes])
			_check(col_top <= roof_top + 0.01 and col_bottom >= -0.01, "%s/%s: colliders span the ground .. the roofs only, no parapet / tank (y %.2f..%.2f, highest roof %.2f)" % [region, mi.name, col_bottom, col_top, roof_top])
			if lod < 2:
				_check(float(col_faces) < MAX_COLLIDER_SHARE * float(render_tris), "%s/%s: collider faces %d < %.0f %% of the %d render triangles" % [region, mi.name, col_faces, MAX_COLLIDER_SHARE * 100.0, render_tris])
			col_faces_all += col_faces
			render_all += render_tris
		_check(_count(mi, "Label3D") == 0, "%s/%s: no Label3D" % [region, mi.name])
		var surfaces: Array = []
		for s: int in range(mi.mesh.get_surface_count()):
			surfaces.append(mi.mesh.surface_get_name(s))
		if lod >= 2:
			_check(surfaces == ["boxes"], "%s/%s lod 2: one box surface (got %s)" % [region, mi.name, str(surfaces)])
		else:
			_check(surfaces.has("roof") and surfaces.has("parapet") and surfaces.any(func(n: String) -> bool: return n.begins_with("walls_")), "%s/%s: walls_<style> + roof + parapet surfaces (got %s)" % [region, mi.name, str(surfaces)])
			var tank_tris: int = 0
			var si: int = surfaces.find("tank")
			if si >= 0:
				var tarr: Array = mi.mesh.surface_get_arrays(si)
				var tidx: PackedInt32Array = _indices(tarr)
				tank_tris = tidx.size() / 3 if tidx.size() > 0 else (tarr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var n_tanks: int = int(mi.get_meta("tank_count", 0))
			_check((n_tanks == 0) == (si < 0) and tank_tris <= MAX_TANK_TRIS * n_tanks, "%s/%s: %d tank triangles for %d tanks (<= %d each)" % [region, mi.name, tank_tris, n_tanks, MAX_TANK_TRIS])
		tanks += int(mi.get_meta("tank_count", 0))
	var missing: int = 0
	var several: int = 0
	for id: int in want.keys():
		if int(want[id]) == 0:
			missing += 1
		elif int(want[id]) > 1:
			several += 1
	_check(missing == 0 and several == 0, "%s: every msft id in exactly one chunk (%d missing, %d in several chunks, %d ids)" % [region, missing, several, want.size()])
	for id: Variant in skip:
		_check(not want.has(int(id)), "%s: skipped id %d is in no chunk" % [region, int(id)])
	if lod < 2 and want.size() >= 100:
		var share: float = float(tanks) / float(want.size())
		_check(share > 0.25 and share < 0.45, "%s: rooftop water tanks on ~40 %% of the msft roofs (got %.1f %%)" % [region, share * 100.0])
	if colliders:
		print("  %s colliders: %d convex + %d concave shapes, %d faces = %.1f %% of %d render tris" % [region, n_convex, n_concave, col_faces_all, 100.0 * float(col_faces_all) / maxf(1.0, float(render_all)), render_all])
	if lod == 0:
		_check_footprints(md, region, fps)
	return chunks.size()


## Final msft footprints (`fps` = MapBuilder.msft_footprints()): no vertex or centroid on a carriageway ribbon
## (+ 0.3 m) or on a drawn footway ribbon (+ 0.2 m), no overlap with any OSM building or drawn footway quad, and no
## piece narrower than 1 m (eroding it by 0.49 m leaves something).
func _check_footprints(md: MapData, region: String, fps: Array) -> void:
	var osm: Array = []
	for b: Dictionary in md.buildings():
		if not MapBuilder.is_msft(b):
			var p: PackedVector2Array = MapData.poly(b["outer"])
			osm.append([p, _bbox(p)])
	_prepare_foot_quads(md)
	var on_road: int = 0
	var in_osm: int = 0
	var on_foot: int = 0
	var foot_overlap: int = 0
	var thin: int = 0
	var fins: int = 0
	var worst_fin: float = 0.0
	var pieces: int = 0
	for e: Array in fps:
		for piece: PackedVector2Array in e[1]:
			pieces += 1
			var probe := PackedVector2Array(piece)
			probe.append(MapBuilder._area_centroid(piece))
			for v: Vector2 in probe:
				if _on_ribbon(v, 0.3):
					on_road += 1
					break
			for v: Vector2 in probe:
				if _on_footway(v, 0.2):
					on_foot += 1
					break
			if Geometry2D.offset_polygon(piece, -0.49, Geometry2D.JOIN_MITER).is_empty():
				thin += 1
			var piece_area: float = absf(_signed_area(piece))
			var fin_loss: float = piece_area - _opened_area(piece, 0.45)
			worst_fin = maxf(worst_fin, fin_loss)
			if fin_loss > maxf(0.1, piece_area * 0.01):
				fins += 1
			var pb: Rect2 = _bbox(piece)
			for o: Array in osm:
				if not (o[1] as Rect2).intersects(pb):
					continue
				var area: float = 0.0
				for q: PackedVector2Array in Geometry2D.intersect_polygons(piece, o[0]):
					area += absf(_signed_area(q))
				if area > 0.05:
					in_osm += 1
			var seen: Dictionary = {}
			var hit: bool = false
			for cell: Vector2i in _foot_cells(pb):
				for qi: int in _foot_quad_hash.get(cell, []):
					if hit or seen.has(qi) or not (_foot_quads[qi][1] as Rect2).intersects(pb):
						continue
					seen[qi] = true
					var fa: float = 0.0
					for q: PackedVector2Array in Geometry2D.intersect_polygons(piece, _foot_quads[qi][0]):
						fa += absf(_signed_area(q))
					if fa > 0.01:
						hit = true
			if hit:
				foot_overlap += 1
	_check(pieces > 0, "%s: msft footprints exist" % region)
	_check(on_road == 0, "%s: %d msft footprint pieces touch a carriageway ribbon" % [region, on_road])
	_check(in_osm == 0, "%s: %d msft footprint pieces overlap an OSM building (z-fighting)" % [region, in_osm])
	_check(on_foot == 0, "%s: %d msft footprint pieces have a vertex within 0.2 m of a footway ribbon" % [region, on_foot])
	_check(foot_overlap == 0, "%s: %d msft footprint pieces intersect a drawn footway ribbon" % [region, foot_overlap])
	_check(thin == 0, "%s: %d msft footprint pieces narrower than 1 m (eroding by 0.49 m leaves nothing)" % [region, thin])
	print("  %s: %d msft pieces, worst area lost to a 0.45 m opening %.3f m2" % [region, pieces, worst_fin])
	_check(fins == 0, "%s: %d msft footprint pieces keep a fin / neck under ~0.9 m wide (a 0.45 m opening removes > max(0.1 m2, 1 %%) of them)" % [region, fins])


## Area left after a morphological opening of `poly` by `r` (erode, dilate each core with mitre joins, clip to poly).
func _opened_area(poly: PackedVector2Array, r: float) -> float:
	var area: float = 0.0
	for core: PackedVector2Array in Geometry2D.offset_polygon(poly, -r, Geometry2D.JOIN_MITER):
		for g: PackedVector2Array in Geometry2D.offset_polygon(core, r, Geometry2D.JOIN_MITER):
			for q: PackedVector2Array in Geometry2D.intersect_polygons(g, poly):
				area += absf(_signed_area(q))
	return area


## Drawn footway / steps / path ribbon quads of the whole map, exactly as MapBuilder._build_roads emits them
## (_footway_profile + _mitre_offsets, half width footway_width / 2), hashed by FOOT_CELL cells.
func _prepare_foot_quads(md: MapData) -> void:
	if not _foot_quads.is_empty():
		return
	for r: Dictionary in md.roads():
		if int(r.get("lanes", 2)) > 0:
			continue
		var pts2: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts2.size() < 2:
			continue
		var half: float = MapBuilder.footway_width(float(r.get("width", 6.0))) * 0.5
		var fp: PackedVector3Array = MapBuilder._footway_profile(pts2)
		var offs: PackedVector2Array = MapBuilder._mitre_offsets(fp)
		for i: int in range(fp.size() - 1):
			var a := Vector2(fp[i].x, fp[i].z)
			var c := Vector2(fp[i + 1].x, fp[i + 1].z)
			var q := PackedVector2Array([a + offs[i] * half, c + offs[i + 1] * half, c - offs[i + 1] * half, a - offs[i] * half])
			var qb: Rect2 = _bbox(q)
			var qi: int = _foot_quads.size()
			_foot_quads.append([q, qb])
			for cell: Vector2i in _foot_cells(qb):
				if not _foot_quad_hash.has(cell):
					_foot_quad_hash[cell] = []
				(_foot_quad_hash[cell] as Array).append(qi)


func _foot_cells(r: Rect2) -> Array:
	var out: Array = []
	for cx: int in range(floori(r.position.x / FOOT_CELL), floori(r.end.x / FOOT_CELL) + 1):
		for cz: int in range(floori(r.position.y / FOOT_CELL), floori(r.end.y / FOOT_CELL) + 1):
			out.append(Vector2i(cx, cz))
	return out


## True when `p` lies on a drawn footway ribbon widened by `margin` on both sides (MapBuilder's footway index): within
## footway_width / 2 + margin of a segment, except past the flat end of a way.
func _on_footway(p: Vector2, margin: float) -> bool:
	var c: Vector2i = MapBuilder._cell(p)
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			for sv: Vector2i in MapBuilder._foot_hash.get(Vector2i(c.x + dx, c.y + dy), []):
				var fw: Array = MapBuilder._footways[sv.x]
				var pts: PackedVector2Array = fw[0]
				var a: Vector2 = pts[sv.y]
				var b: Vector2 = pts[sv.y + 1]
				var ab: Vector2 = b - a
				var t: float = (p - a).dot(ab) / maxf(ab.length_squared(), 1e-9)
				if (t < 0.0 and sv.y == 0) or (t > 1.0 and sv.y == pts.size() - 2):
					continue
				if MapBuilder._dist_point_segment(p, a, b) <= float(fw[1]) * 0.5 + margin:
					return true
	return false


## One tank on a plain 6 x 12 m roof (MapBuilder._emit_roof_tank alone): it fits, stays within MAX_TANK_TRIS
## triangles, sits on the roof and every triangle's winding agrees with its shading normal.
func _check_tank_only() -> void:
	var tb := MapBuilder.Batch.new()
	var roof := PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(6, 12), Vector2(0, 12)])
	if not _check(MapBuilder._emit_roof_tank(tb, roof, 7.2), "a tank fits a 6 x 12 m roof"):
		return
	var mesh: ArrayMesh = tb.st.commit()
	var tris: int = _tri_count(mesh)
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = _indices(arr)
	var bad: int = 0
	for t: int in range(tris):
		var i0: int = idx[t * 3] if idx.size() > 0 else t * 3
		var i1: int = idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
		var i2: int = idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
		var geo_n: Vector3 = -(verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).normalized()
		if geo_n.dot((norms[i0] + norms[i1] + norms[i2]).normalized()) < 0.9:
			bad += 1
	var bb: AABB = mesh.get_aabb()
	print("  tank-only build: %d triangles, aabb y %.2f..%.2f" % [tris, bb.position.y, bb.end.y])
	_check(tris > 0 and tris <= MAX_TANK_TRIS, "one water tank is <= %d triangles (got %d)" % [MAX_TANK_TRIS, tris])
	_check(absf(bb.position.y - 7.2) < 0.01 and bb.end.y < 7.2 + MapBuilder.TANK_LEG_H + 2.0 * MapBuilder.TANK_R + 0.01, "tank stands on the roof (aabb y %.2f..%.2f)" % [bb.position.y, bb.end.y])
	_check(bad == 0, "tank: %d triangles whose winding disagrees with the shading normal" % bad)


## True when `p` lies on a drawn carriageway ribbon widened by `margin` on both sides (MapBuilder's road index):
## within width / 2 + margin of a segment, except past the flat end of a way (ribbons stop square at way ends).
func _on_ribbon(p: Vector2, margin: float) -> bool:
	for sv: Vector2i in MapBuilder._segments_near(p):
		var cw: Array = MapBuilder._carriageways[sv.x]
		var pts: PackedVector2Array = cw[0]
		var a: Vector2 = pts[sv.y]
		var b: Vector2 = pts[sv.y + 1]
		var ab: Vector2 = b - a
		var t: float = (p - a).dot(ab) / maxf(ab.length_squared(), 1e-9)
		if (t < 0.0 and sv.y == 0) or (t > 1.0 and sv.y == pts.size() - 2):
			continue
		if MapBuilder._dist_point_segment(p, a, b) <= float(cw[1]) * 0.5 + margin:
			return true
	return false


## Winding / normals / outward walls / upward roofs on the chunk with the most buildings: every wall triangle's
## front normal agrees with its shading normal and points out of the footprint piece it was built from.
func _check_chunk_walls(md: MapData, region_root: Node3D, region: String, skip: Array) -> void:
	var holder: Node = region_root.get_node_or_null("Buildings")
	var chunk: MeshInstance3D = null
	for c: Node in holder.get_children():
		if c.name.begins_with("MSChunk_") and (chunk == null or (c.get_meta("building_ids") as Array).size() > (chunk.get_meta("building_ids") as Array).size()):
			chunk = c as MeshInstance3D
	if not _check(chunk != null, "%s: a chunk to inspect" % region):
		return
	var fp: Dictionary = {}
	for e: Array in MapBuilder.msft_footprints(md, region, skip):
		fp[int(e[0]["id"])] = e[1]
	var polys: Array = []
	for id: Variant in chunk.get_meta("building_ids"):
		for p: PackedVector2Array in fp.get(int(id), []):
			polys.append([p, _bbox(p).grow(0.5)])
	var mesh: ArrayMesh = chunk.mesh as ArrayMesh
	var bad_n: int = 0
	var bad_out: int = 0
	var mirrored: int = 0
	var walls: int = 0
	var roof_bad: int = 0
	var roofs: int = 0
	for s: int in range(mesh.get_surface_count()):
		var sname: String = mesh.surface_get_name(s)
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var suv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = _indices(arr)
		var n_tri: int = idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		for t: int in range(n_tri):
			var i0: int = idx[t * 3] if idx.size() > 0 else t * 3
			var i1: int = idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
			var i2: int = idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
			# Godot front faces wind clockwise seen from the front: the front normal is -(b - a) x (c - a)
			var geo_n: Vector3 = -(verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).normalized()
			if geo_n.dot(norms[i0]) < 0.9:
				bad_n += 1
				continue
			if sname == "roof":
				roofs += 1
				if geo_n.y <= 0.0:
					roof_bad += 1
				continue
			if not sname.begins_with("walls_"):
				continue
			var span: float = 0.0
			for pair: Array in [[i0, i1], [i1, i2], [i0, i2]]:
				var a: Vector3 = verts[pair[0]]
				var b: Vector3 = verts[pair[1]]
				span = maxf(span, Vector2(a.x - b.x, a.z - b.z).length())
			if _mirrored(verts, suv, i0, i1, i2, geo_n):
				mirrored += 1
			if span < 0.6:
				continue   # corner slivers of clipped outlines: the 0.3 m probes would leave the piece sideways
			walls += 1
			var c: Vector3 = (verts[i0] + verts[i1] + verts[i2]) / 3.0
			var out_p := Vector2(c.x + geo_n.x * 0.3, c.z + geo_n.z * 0.3)
			var in_p := Vector2(c.x - geo_n.x * 0.3, c.z - geo_n.z * 0.3)
			var ok: bool = false
			for pe: Array in polys:
				if (pe[1] as Rect2).has_point(in_p) and Geometry2D.is_point_in_polygon(in_p, pe[0]) and not Geometry2D.is_point_in_polygon(out_p, pe[0]):
					ok = true
					break
			if not ok:
				bad_out += 1
	print("  %s/%s: %d buildings, %d wall tris checked, %d roof tris" % [region, chunk.name, (chunk.get_meta("building_ids") as Array).size(), walls, roofs])
	_check(walls > 0 and roofs > 0, "%s/%s: walls and roofs present" % [region, chunk.name])
	_check(bad_n == 0, "%s/%s: %d triangles whose winding disagrees with the shading normal" % [region, chunk.name, bad_n])
	_check(bad_out == 0, "%s/%s: %d wall triangles facing into their footprint" % [region, chunk.name, bad_out])
	_check(mirrored == 0, "%s/%s: %d wall triangles with a mirrored facade (u must grow to the viewer's right)" % [region, chunk.name, mirrored])
	_check(roof_bad == 0, "%s/%s: %d roof triangles facing down" % [region, chunk.name, roof_bad])


## Walls must face away from the footprint, roof triangles must face up (clockwise front faces).
func _check_building(mi: MeshInstance3D, mesh: ArrayMesh, b: Dictionary) -> void:
	if not (b["inner"] as Array).is_empty():
		return
	var bad: int = 0
	var mirrored: int = 0
	var outer: PackedVector2Array = MapData.poly(b["outer"])
	var walls: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = walls[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = walls[Mesh.ARRAY_NORMAL]
	var wuv: PackedVector2Array = walls[Mesh.ARRAY_TEX_UV]
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
		if _mirrored(verts, wuv, i0, i1, i2, geo_n):
			mirrored += 1
		var out_p := Vector2(c.x + geo_n.x * 0.3, c.z + geo_n.z * 0.3)
		var in_p := Vector2(c.x - geo_n.x * 0.3, c.z - geo_n.z * 0.3)
		if Geometry2D.is_point_in_polygon(out_p, outer) or not Geometry2D.is_point_in_polygon(in_p, outer):
			bad += 1
	_check(mirrored == 0, "building %s: %d wall triangles with a mirrored facade (u must grow to the viewer's right)" % [mi.name, mirrored])
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
	_check(bad == 0 and roof_bad == 0 and n_roof > 0, "building %s: %d wall triangles inward/misnormal, %d roof triangles facing down (%d roof tris)" % [mi.name, bad, roof_bad, n_roof])


## OSM buildings of a region (the ones built one node each).
func _osm(md: MapData, region: String) -> Array:
	return md.buildings(region).filter(func(b: Dictionary) -> bool: return not MapBuilder.is_msft(b))


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


## True when the facade texture of wall triangle (i0, i1, i2) reads mirrored: along its horizontal edge u must grow to
## the right of a viewer outside, i.e. along (-front normal) x up = (n.z, 0, -n.x).
func _mirrored(verts: PackedVector3Array, uvs: PackedVector2Array, i0: int, i1: int, i2: int, geo_n: Vector3) -> bool:
	var right := Vector3(geo_n.z, 0.0, -geo_n.x)
	for pair: Array in [[i0, i1], [i1, i2], [i0, i2]]:
		var a: int = pair[0]
		var b: int = pair[1]
		var d: Vector3 = verts[b] - verts[a]
		if absf(d.y) < 0.001 and Vector2(d.x, d.z).length() > 0.1:
			return (uvs[b].x - uvs[a].x) * d.dot(right) < 0.0
	return false


## Index array of a surface, empty for non-indexed surfaces (the slot is null then).
func _indices(arr: Array) -> PackedInt32Array:
	var v: Variant = arr[Mesh.ARRAY_INDEX]
	return v if v is PackedInt32Array else PackedInt32Array()


func _bbox(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		r = r.expand(p)
	return r


func _signed_area(ring: PackedVector2Array) -> float:
	var s: float = 0.0
	for i: int in range(ring.size()):
		var a: Vector2 = ring[i]
		var c: Vector2 = ring[(i + 1) % ring.size()]
		s += a.x * c.y - c.x * a.y
	return s * 0.5


## Watchdog: if _initialize aborts before quit(), do not idle forever.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames > 3:
		print("FAILED: test aborted before completion (see errors above)")
		quit(2)
		return true
	return false
