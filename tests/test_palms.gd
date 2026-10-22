# File: res://tests/test_palms.gd
# Headless test for Task VC-2 (docs/superpowers/plans/2026-10-22-vice-city-art-direction.md): palms v2 as MultiMesh fields.
#   - PropBuilder.palm_meshes(): cached trunk (5 tapered bands, 2 surfaces) + crown (12 fronds + 3 coconuts, 2 surfaces).
#   - PropBuilder.build_palm_field(): 500 points -> one "PalmField" with exactly 2 MultiMeshInstance3D of 500 instances,
#     < 6 surfaces in total, heights 8.5..13 m, crowns on the trunk tops, deterministic per seed, visual-only by default;
#     opts.colliders -> one StaticBody3D with one CylinderShape3D (r 0.28, trunk height) per palm.
#   - MapBuilder opts.palms: vinhomes -> one PalmField with 200..1500 palms, none inside a building footprint or water,
#     on a carriageway or a footway ribbon, within 12 m of a junction, 8 m of the BE6 spawn / FreeRoam hotspots, inside the
#     BE6 plaza ring, the campus plot or 9 m of a campus gate; corridor palms stay inside the route buffer; no palms (and no
#     PalmField) unless opts.palms; opts.palm_colliders adds the colliders.
#   - FPTUCampusBuilder opts.palms: Đường D1 rows (v -3.2 and ROAD_CENTER_V - 9, every 13 m, 9 m clear of both gates) as one
#     PalmField, the front-plaza royal palms use the new palm meshes; without opts.palms nothing palm-v2 is built.
# Every check goes through _check() (a failed assert inside _initialize hangs a --script run).
# Run:  godot --headless --path . --script tests/test_palms.gd
extends SceneTree

const FIELD_N: int = 500
const MIN_REGION_PALMS: int = 200
const MAX_REGION_PALMS: int = 1500

var _problems: int = 0


func _initialize() -> void:
	var summary: String = _run()
	if _problems > 0 or summary == "":
		print("FAILED: %d problem(s)" % maxi(1, _problems))
		quit(1)
		return
	print("✅ SUCCESS: PALMS OK " + summary)
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_problems += 1
		print("FAILED: " + msg)
	return ok


func _run() -> String:
	var world := Node3D.new()
	root.add_child(world)

	# --- shared meshes -----------------------------------------------------------------------
	var pm: Dictionary = PropBuilder.palm_meshes()
	var trunk: ArrayMesh = pm.get("trunk") as ArrayMesh
	var crown: ArrayMesh = pm.get("crown") as ArrayMesh
	if not _check(trunk != null and crown != null, "palm_meshes() returns trunk + crown ArrayMesh"):
		return ""
	_check(trunk.get_surface_count() == 2, "trunk: 2 surfaces (alternating band colours), got %d" % trunk.get_surface_count())
	_check(crown.get_surface_count() == 2, "crown: 2 surfaces (fronds, coconuts), got %d" % crown.get_surface_count())
	var mats: Dictionary = pm.get("materials", {})
	for k: String in ["leaf", "trunk", "ring", "nut"]:
		_check(mats.get(k) is StandardMaterial3D, "palm material %s" % k)
	_check(PropBuilder.palm_meshes()["trunk"] == trunk, "palm_meshes() is cached")
	_check(absf(trunk.get_aabb().size.y - 1.0) < 0.05, "trunk mesh is unit height (scaled per instance), got %.2f" % trunk.get_aabb().size.y)
	_check((mats["leaf"] as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED, "fronds are double-sided")
	var crown_tris: int = _tri_count(crown)
	var trunk_tris: int = _tri_count(trunk)
	_check(crown_tris >= 300 and crown_tris <= 700, "crown 300..700 triangles (got %d)" % crown_tris)
	_check(trunk_tris >= 80 and trunk_tris <= 260, "trunk 80..260 triangles (got %d)" % trunk_tris)

	# --- build_palm_field ---------------------------------------------------------------------
	var pts := PackedVector3Array()
	for i: int in range(FIELD_N):
		pts.append(Vector3(float(i % 25) * 9.0, 0.0, float(i / 25) * 9.0))
	var field: Node3D = PropBuilder.build_palm_field(world, pts, {"seed": 3})
	if not _check(field != null and field.name == "PalmField", "build_palm_field returns a node named PalmField"):
		return ""
	_check(int(field.get_meta("palm_count", -1)) == FIELD_N, "meta palm_count = %d" % FIELD_N)
	var mmis: Array = _mmis(field)
	_check(mmis.size() == 2, "exactly 2 MultiMeshInstance3D (trunks, crowns), got %d" % mmis.size())
	var surfaces: int = 0
	for mmi: MultiMeshInstance3D in mmis:
		_check(mmi.multimesh.instance_count == FIELD_N, "%s: %d instances (got %d)" % [mmi.name, FIELD_N, mmi.multimesh.instance_count])
		surfaces += mmi.multimesh.mesh.get_surface_count()
	_check(surfaces < 6, "< 6 surfaces in total (got %d)" % surfaces)
	_check(_count(field, "StaticBody3D") == 0, "palms are visual-only by default")
	var trunks: MultiMeshInstance3D = field.get_node_or_null("Trunks") as MultiMeshInstance3D
	var crowns: MultiMeshInstance3D = field.get_node_or_null("Crowns") as MultiMeshInstance3D
	if not _check(trunks != null and crowns != null, "children Trunks + Crowns"):
		return ""
	_check(trunks.multimesh.mesh == trunk and crowns.multimesh.mesh == crown, "the field instances the shared palm meshes")
	_check(trunks.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and crowns.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "trunks and crowns cast shadows by default")
	_check(field.get_meta("palm_points", PackedVector3Array()) == pts, "meta palm_points = the points")
	# instance transforms (the headless RenderingServer does not keep MultiMesh buffers, so the pure helper that
	# build_palm_field fills them from is checked)
	var xfs: Dictionary = PropBuilder.palm_field_xforms(pts, {"seed": 3})
	var heights: PackedFloat32Array = xfs["heights"]
	_check(field.get_meta("palm_heights", PackedFloat32Array()) == heights, "meta palm_heights = the trunk heights")
	var h_lo: float = INF
	var h_hi: float = -INF
	var bad_top: int = 0
	for i: int in range(FIELD_N):
		var tx: Transform3D = xfs["trunk"][i]
		var cx: Transform3D = xfs["crown"][i]
		var h: float = tx.basis.y.y
		h_lo = minf(h_lo, h)
		h_hi = maxf(h_hi, h)
		var base: Vector3 = pts[i]
		var off := Vector2(cx.origin.x - base.x, cx.origin.z - base.z)
		# trunk stands on the point; crown on the trunk top: h above the base, displaced by the lean + baked curve (< 2.2 m)
		if absf(heights[i] - h) > 0.001 or absf(cx.origin.y - base.y - h) > 0.3 or off.length() > 2.2 or Vector2(tx.origin.x - base.x, tx.origin.z - base.z).length() > 0.01 or absf(tx.origin.y - base.y) > 0.2:
			bad_top += 1
	_check(h_lo >= 8.49 and h_hi <= 13.01, "trunk heights in 8.5..13 m (got %.2f..%.2f)" % [h_lo, h_hi])
	_check(h_hi - h_lo > 2.5, "heights vary (%.2f..%.2f)" % [h_lo, h_hi])
	_check(bad_top == 0, "every trunk stands on its point and every crown sits on its trunk top (%d off)" % bad_top)
	var t_a: Transform3D = PropBuilder.palm_field_xforms(pts, {"seed": 3})["crown"][17]
	var t_o: Transform3D = PropBuilder.palm_field_xforms(pts, {"seed": 4})["crown"][17]
	_check(t_a.is_equal_approx(xfs["crown"][17]), "same seed -> same palms")
	_check(not t_o.is_equal_approx(t_a), "another seed -> other palms")
	var fixed: Dictionary = PropBuilder.palm_field_xforms(pts.slice(0, 3), {"heights": PackedFloat32Array([9.0, 10.0, 11.0])})
	_check(absf((fixed["trunk"][1] as Transform3D).basis.y.y - 10.0) < 0.001, "opts.heights fixes the trunk heights")
	_check(PropBuilder.build_palm_field(world, PackedVector3Array(), {}) == null, "no points -> no PalmField")
	# colliders: one StaticBody3D, one cylinder (r 0.28, trunk height) per palm, standing on the ground
	var few: PackedVector3Array = pts.slice(0, 50)
	var cf: Node3D = PropBuilder.build_palm_field(world, few, {"seed": 9, "colliders": true})
	var bodies: Array = _nodes_of(cf, "StaticBody3D")
	if _check(bodies.size() == 1, "colliders -> exactly one StaticBody3D per PalmField (got %d)" % bodies.size()):
		var shapes: Array = _nodes_of(bodies[0], "CollisionShape3D")
		_check(shapes.size() == few.size(), "one CollisionShape3D per palm (%d vs %d)" % [shapes.size(), few.size()])
		var ch: PackedFloat32Array = cf.get_meta("palm_heights", PackedFloat32Array())
		var bad_shape: int = 0
		for i: int in range(mini(shapes.size(), ch.size())):
			var cs: CollisionShape3D = shapes[i]
			var cyl: CylinderShape3D = cs.shape as CylinderShape3D
			var h: float = ch[i]
			var at: Vector3 = (bodies[0] as StaticBody3D).transform * cs.position
			if cyl == null or absf(cyl.radius - 0.28) > 0.001 or absf(cyl.height - h) > 0.01 or absf(at.y - (few[i].y + h * 0.5)) > 0.15 or Vector2(at.x - few[i].x, at.z - few[i].z).length() > 0.01:
				bad_shape += 1
		_check(bad_shape == 0, "collider = CylinderShape3D r 0.28 x trunk height at the palm base (%d wrong)" % bad_shape)
	# single palm (build_royal_palm in vice): two MeshInstance3D sharing the field meshes
	var single: Node3D = PropBuilder.build_palm(world, Vector3(5.0, 0.0, -7.0), 9.0, 11)
	if _check(single != null, "build_palm returns a node"):
		var smis: Array = _nodes_of(single, "MeshInstance3D")
		_check(smis.size() == 2 and (smis[0] as MeshInstance3D).mesh == trunk and (smis[1] as MeshInstance3D).mesh == crown, "single palm = trunk + crown MeshInstance3D with the shared meshes")
	for n: Node in [field, cf, single]:
		n.free()

	# --- MapBuilder regions ---------------------------------------------------------------------
	var md: MapData = MapData.load_default()
	if not _check(md != null, "mapdata.json must load"):
		return ""
	var ctx: Dictionary = _context(md)
	var t0: int = Time.get_ticks_msec()
	var vin: Node3D = MapBuilder.build_region(world, md, "vinhomes", {"palms": true, "labels": false})
	var ms_vin: int = Time.get_ticks_msec() - t0
	var vin_fields: Array = _named(vin, "PalmField")
	var n_vin: int = 0
	if _check(vin_fields.size() == 1, "vinhomes palms -> exactly one PalmField (got %d)" % vin_fields.size()):
		var f: Node3D = vin_fields[0]
		_check(f.get_parent() == vin and String(f.get_meta("region", "")) == "vinhomes", "PalmField is a direct child of the region root with meta region")
		_check(_count(f, "StaticBody3D") == 0, "MapBuilder palms are visual-only unless palm_colliders")
		n_vin = int(f.get_meta("palm_count", 0))
		_check(n_vin >= MIN_REGION_PALMS and n_vin <= MAX_REGION_PALMS, "vinhomes: %d..%d palms (got %d)" % [MIN_REGION_PALMS, MAX_REGION_PALMS, n_vin])
		_check_placement(md, ctx, f, "vinhomes")
	_check(ms_vin < 5000, "vinhomes with palms builds in < 5000 ms (got %d)" % ms_vin)
	vin.free()

	var cor: Node3D = MapBuilder.build_region(world, md, "corridor", {"palms": true, "labels": false, "lod": 1})
	var cor_fields: Array = _named(cor, "PalmField")
	var n_cor: int = 0
	if _check(cor_fields.size() == 1, "corridor palms -> one PalmField (got %d)" % cor_fields.size()):
		var f: Node3D = cor_fields[0]
		n_cor = int(f.get_meta("palm_count", 0))
		_check(n_cor >= MIN_REGION_PALMS and n_cor <= MAX_REGION_PALMS, "corridor: %d..%d palms (got %d)" % [MIN_REGION_PALMS, MAX_REGION_PALMS, n_cor])
		var outside: int = 0
		for p: Vector2 in _palm_points(f):
			if not MapBuilder.region_contains(md, "corridor", p):
				outside += 1
		_check(outside == 0, "corridor palms stay inside the route buffer (%d outside)" % outside)
		_check_placement(md, ctx, f, "corridor")
	cor.free()
	# palm_verge (Stage 1: palms behind the RoadManager route-tree row): the palm line moves out from every carriageway
	var near_pts: PackedVector3Array = MapBuilder.palm_points(md, "corridor", {})
	var far_pts: PackedVector3Array = MapBuilder.palm_points(md, "corridor", {"palm_verge": 8.0})
	var med_near: float = _median_edge_gap(ctx, near_pts)
	var med_far: float = _median_edge_gap(ctx, far_pts)
	_check(absf(med_near - 2.6) < 0.6, "default palm line ~2.6 m behind the carriageway edge (median %.2f)" % med_near)
	_check(med_far > 7.0 and far_pts.size() >= 100, "palm_verge 8 -> palms ~8 m behind the edge (median %.2f, %d palms)" % [med_far, far_pts.size()])

	var cam: Node3D = MapBuilder.build_region(world, md, "campus", {"palms": true, "palm_colliders": true, "labels": false})
	var cam_fields: Array = _named(cam, "PalmField")
	var n_cam: int = 0
	if _check(cam_fields.size() == 1, "campus palms -> one PalmField (got %d)" % cam_fields.size()):
		var f: Node3D = cam_fields[0]
		n_cam = int(f.get_meta("palm_count", 0))
		_check(n_cam >= MIN_REGION_PALMS and n_cam <= MAX_REGION_PALMS, "campus: %d..%d palms (got %d)" % [MIN_REGION_PALMS, MAX_REGION_PALMS, n_cam])
		var cb: Array = _nodes_of(f, "StaticBody3D")
		_check(cb.size() == 1 and _nodes_of(cb[0], "CollisionShape3D").size() == n_cam, "palm_colliders -> one StaticBody3D with one shape per palm")
		_check_placement(md, ctx, f, "campus")
	cam.free()

	# no palms unless asked (classic scenes keep their node content)
	var plain: Node3D = MapBuilder.build_region(world, md, "campus", {"labels": false, "lod": 1})
	_check(_named(plain, "PalmField").is_empty(), "no opts.palms -> no PalmField")
	plain.free()

	# --- FPTUCampusBuilder ------------------------------------------------------------------------
	var campus_v: Node3D = FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": false, "palms": true})
	var d1_fields: Array = _named(campus_v, "PalmField")
	var n_d1: int = 0
	if _check(d1_fields.size() == 1, "campus builder palms -> one Đường D1 PalmField (got %d)" % d1_fields.size()):
		var f: Node3D = d1_fields[0]
		n_d1 = int(f.get_meta("palm_count", 0))
		_check(_count(f, "StaticBody3D") == 0, "D1 palms are visual-only")
		var bad_row: int = 0
		var near_gate: int = 0
		for p: Vector2 in _palm_points(f):
			if absf(p.y - (-3.2)) > 0.05 and absf(p.y - (FPTUCampusBuilder.ROAD_CENTER_V - 9.0)) > 0.05:
				bad_row += 1
			for gu: float in [FPTUCampusBuilder.MAIN_GATE_U, FPTUCampusBuilder.WEST_GATE_U]:
				if absf(p.x - gu) <= 9.0:
					near_gate += 1
		_check(n_d1 >= 30 and n_d1 <= 44, "D1 rows: 30..44 palms every 13 m (got %d)" % n_d1)
		_check(bad_row == 0, "D1 palms on v -3.2 and ROAD_CENTER_V - 9 only (%d off)" % bad_row)
		_check(near_gate == 0, "D1 palms keep 9 m clear of the gates (%d too close)" % near_gate)
	var plaza_palms: int = _mesh_users(campus_v, crown)
	_check(plaza_palms >= 6, "front-plaza royal palms use the new palm meshes in vice (got %d)" % plaza_palms)
	campus_v.free()
	var campus_nod1: Node3D = FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": false, "palms": true, "d1_palms": false})
	_check(_named(campus_nod1, "PalmField").is_empty() and _mesh_users(campus_nod1, crown) == plaza_palms, "d1_palms false -> no D1 field, plaza palms kept")
	campus_nod1.free()
	var campus_c: Node3D = FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": false})
	_check(_named(campus_c, "PalmField").is_empty() and _mesh_users(campus_c, crown) == 0 and _mesh_users(campus_c, trunk) == 0, "classic campus (no opts.palms) has no palm v2 at all")
	campus_c.free()

	return "field=%d vinhomes=%d (%d ms) corridor=%d campus=%d d1=%d plaza=%d crown_tris=%d trunk_tris=%d" % [FIELD_N, n_vin, ms_vin, n_cor, n_cam, n_d1, plaza_palms, crown_tris, trunk_tris]


# ---------------------------------------------------------------------------------------------
# placement rules
# ---------------------------------------------------------------------------------------------
## Everything the placement rules are checked against, computed here from MapData (independent of MapBuilder's caches,
## except the junction discs, which are MapBuilder's own definition of a junction node).
func _context(md: MapData) -> Dictionary:
	var cways: Array = []
	var foots: Array = []
	for r: Dictionary in md.roads():
		var p: PackedVector2Array = MapData.poly(r.get("points", []))
		if p.size() < 2:
			continue
		if int(r.get("lanes", 0)) > 0:
			cways.append([p, float(r.get("width", 6.0)), MapBuilder._bbox(p).grow(float(r.get("width", 6.0)))])
		else:
			var fw: float = MapBuilder.footway_width(float(r.get("width", 2.0)))
			foots.append([p, fw, MapBuilder._bbox(p).grow(fw)])
	var bpolys: Array = []
	for b: Dictionary in md.buildings():
		var o: PackedVector2Array = MapBuilder._open(MapData.poly(b.get("outer", [])))
		if o.size() >= 3:
			bpolys.append([o, MapBuilder._bbox(o)])
	var wpolys: Array = []
	for w: PackedVector2Array in MapBuilder._water_polygons(md):
		wpolys.append([w, MapBuilder._bbox(w)])
	MapBuilder._prepare_road_index(md)
	var junctions: Array = []
	for d: Array in MapBuilder._discs:
		junctions.append(d[0])
	var sp: Transform3D = md.spawn_transform()
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var ring_c: Rect2 = FPTUCampusBuilder.ring_courtyard_rect()
	var court := Vector3(ring_c.get_center().x, 0.0, ring_c.get_center().y)
	var atrium: Vector3 = FPTUCampusBuilder.atrium_door_local()
	atrium += (court - atrium).normalized() * 2.0
	var r311: Vector3 = FPTUCampusBuilder.room311_center()
	# FreeRoam._build_hotspots(): BE6 plaza (Màn 1) + the campus hotspots (local u, 0, v)
	var hot_local: Array = [FPTUCampusBuilder.back_gate_local(), atrium, FPTUCampusBuilder.pitch_center_local() + Vector3(FPTUCampusBuilder.PITCH_LEN * 0.5 + 2.5, 0.0, 0.0), FPTUCampusBuilder.canteen_center(), Vector3(r311.x, 0.0, ring_c.position.y + 1.5)]
	var hotspots: Array = [sp.origin + (-sp.basis.z) * 7.0 + sp.basis.x * 3.0]
	for l: Vector3 in hot_local:
		hotspots.append(xf * l)
	var gates: Array = []
	for l: Vector3 in [FPTUCampusBuilder.main_gate_local(), FPTUCampusBuilder.west_gate_local(), FPTUCampusBuilder.back_gate_local()]:
		gates.append(xf * l)
	var be6: PackedVector2Array = MapBuilder._open(MapData.poly(md.landmark("be6_outer")))
	return {"cways": cways, "foots": foots, "buildings": bpolys, "water": wpolys, "junctions": junctions, "spawn": sp.origin,
		"hotspots": hotspots, "gates": gates, "plot": MapData.poly(md.landmark("campus_plot")), "be6": be6}


func _check_placement(md: MapData, ctx: Dictionary, field: Node3D, label: String) -> void:
	var pts: Array = _palm_points(field)
	var fails: Dictionary = {}
	var min_pair: float = INF
	var hash: Dictionary = {}
	for i: int in range(pts.size()):
		var p: Vector2 = pts[i]
		var why: String = _violation(ctx, p)
		if why != "":
			fails[why] = int(fails.get(why, 0)) + 1
		var cell := Vector2i(int(floor(p.x / 8.0)), int(floor(p.y / 8.0)))
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for j: int in hash.get(Vector2i(cell.x + dx, cell.y + dy), []):
					min_pair = minf(min_pair, p.distance_to(pts[j]))
		if not hash.has(cell):
			hash[cell] = []
		(hash[cell] as Array).append(i)
	for why: String in fails.keys():
		_check(false, "%s: %d palm(s) %s" % [label, int(fails[why]), why])
	_check(min_pair >= 3.0, "%s: no two palms closer than 3 m (min %.2f)" % [label, min_pair])
	print("  %s: %d palms checked, min spacing %.1f m" % [label, pts.size(), min_pair])


func _violation(ctx: Dictionary, p: Vector2) -> String:
	for c: Array in ctx["cways"]:
		if (c[2] as Rect2).has_point(p) and _dist_polyline(p, c[0]) < float(c[1]) * 0.5 + 1.5:
			return "on / within 1.5 m of a carriageway"
	for f: Array in ctx["foots"]:
		if (f[2] as Rect2).has_point(p) and _dist_polyline(p, f[0]) <= float(f[1]) * 0.5:
			return "on a footway ribbon"
	for b: Array in ctx["buildings"]:
		if (b[1] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, b[0]):
			return "inside a building footprint"
	for w: Array in ctx["water"]:
		if (w[1] as Rect2).grow(1.0).has_point(p) and Geometry2D.is_point_in_polygon(p, w[0]):
			return "in water"
	for j: Vector2 in ctx["junctions"]:
		if p.distance_to(j) < 12.0:
			return "within 12 m of a junction node"
	var sp: Vector3 = ctx["spawn"]
	if p.distance_to(Vector2(sp.x, sp.z)) < 8.0:
		return "within 8 m of the BE6 spawn"
	for h: Vector3 in ctx["hotspots"]:
		if p.distance_to(Vector2(h.x, h.z)) < 8.0:
			return "within 8 m of a FreeRoam hotspot"
	for g: Vector3 in ctx["gates"]:
		if p.distance_to(Vector2(g.x, g.z)) < 9.0:
			return "within 9 m of a campus gate"
	if (ctx["plot"] as PackedVector2Array).size() >= 3 and Geometry2D.is_point_in_polygon(p, ctx["plot"]):
		return "inside the campus plot"
	if (ctx["be6"] as PackedVector2Array).size() >= 3 and _in_or_near(p, ctx["be6"], 20.0):
		return "inside the BE6 plaza ring"
	return ""


# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
## Palm bases on the map plane (meta palm_points, in the frame of the PalmField's parent = region root / campus root,
## both placed without rotation here except the campus root, whose local frame the D1 rows are checked in).
func _palm_points(field: Node3D) -> Array:
	var out: Array = []
	for p: Vector3 in (field.get_meta("palm_points", PackedVector3Array()) as PackedVector3Array):
		out.append(Vector2(p.x, p.z))
	return out


## Median over the palms of the gap between the palm and the edge of its nearest carriageway.
func _median_edge_gap(ctx: Dictionary, pts: PackedVector3Array) -> float:
	var gaps: Array[float] = []
	for p3: Vector3 in pts:
		var p := Vector2(p3.x, p3.z)
		var best: float = INF
		for c: Array in ctx["cways"]:
			if (c[2] as Rect2).grow(12.0).has_point(p):
				best = minf(best, _dist_polyline(p, c[0]) - float(c[1]) * 0.5)
		if best < INF:
			gaps.append(best)
	if gaps.is_empty():
		return 0.0
	gaps.sort()
	return gaps[gaps.size() / 2]


func _in_or_near(p: Vector2, poly: PackedVector2Array, r: float) -> bool:
	if Geometry2D.is_point_in_polygon(p, poly):
		return true
	return _dist_polyline(p, poly + PackedVector2Array([poly[0]])) < r


func _dist_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in range(pts.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


func _mmis(n: Node) -> Array:
	return _nodes_of(n, "MultiMeshInstance3D")


func _nodes_of(n: Node, cls: String) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c.is_class(cls):
			out.append(c)
		out.append_array(_nodes_of(c, cls))
	return out


func _named(n: Node, name: String) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c.name == name:
			out.append(c)
		out.append_array(_named(c, name))
	return out


func _count(n: Node, cls: String) -> int:
	return _nodes_of(n, cls).size()


## Number of MeshInstance3D under `n` showing `mesh`.
func _mesh_users(n: Node, mesh: Mesh) -> int:
	var k: int = 0
	for mi: MeshInstance3D in _nodes_of(n, "MeshInstance3D"):
		if mi.mesh == mesh:
			k += 1
	return k


func _tri_count(mesh: Mesh) -> int:
	var t: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arr: Array = mesh.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		else:
			t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t
