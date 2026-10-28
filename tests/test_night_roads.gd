# File: res://tests/test_night_roads.gd
# Headless test of the Q3 night roads (plan 2026-10-29-q3-look.md Task 4):
#   A: NightRoads on the real map (vinhomes + corridor + campus, campus plot skipped): enough lamps, none in the campus
#      plot, none on a carriageway or water, none near a baked cinematic stage, spaced >= MIN_GAP; one MultiMesh each of
#      posts / heads / pools per cell carrying every lamp; build time;
#   B: day / night: pools hidden and heads dark by day, no real light; night: pools shown, heads lit, at most LIGHTS
#      OmniLights (no shadows), all near the viewer and on the nearest lamps; none far from every lamp;
#   C: shared materials: lane paint (ViceStyle soft emitter) brighter at night, back to ViceStyle's energy by day and when
#      the node leaves the tree; the POI sign plate glows at night only;
#   D: render budget near the BE6 spawn and the campus gate: cells in head range, draw instances, lights;
#   E: FreeRoam integration: night_roads built, "night" -> lamps on + night_city preset, "morning" -> off + campus_day,
#      the FX pool is in the scene.
# Run: godot --headless --path . --script tests/test_night_roads.gd
extends SceneTree

const MIN_LAMPS: int = 300
const BUILD_BUDGET_MS: float = 1500.0
const MAX_DRAWS_IN_RANGE: int = 120

var done: bool = false
var frame: int = 0
var holder: Node3D
var md: MapData
var nr: NightRoads
var roam: Node3D = null
var roam_frame: int = -1


func _initialize() -> void:
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	frame += 1
	if done:
		return
	if frame == 2:
		holder = Node3D.new()
		root.add_child(holder)
		md = MapData.load_default()
		for part: Callable in [_part_a, _part_b, _part_c, _part_d]:
			if not part.call():
				return
		var packed: PackedScene = load("res://scenes/FreeRoam.tscn")
		roam = packed.instantiate()
		roam.set("crowd_enabled", false)
		roam.set("mayhem_enabled", false)
		root.add_child(roam)
		roam_frame = frame
		return
	if roam != null and frame == roam_frame + 2:
		if not _part_e():
			return
		done = true
		print("SUCCESS: night roads: lamps along the drawn roads, pools / lights at night only, shared materials restored, budget held")
		quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("FAILED: ", msg)
		quit(1)
	return ok


func _plot() -> PackedVector2Array:
	return MapData.poly(md.landmark("campus_plot"))


# ---------------------------------------------------------------------------
func _part_a() -> bool:
	nr = NightRoads.new()
	holder.add_child(nr)
	nr.build(md, ["vinhomes", "corridor", "campus"], _plot())
	var n: int = nr.lamp_count()
	print("  A: %d lamps in %.0f ms, %d cells" % [n, nr.build_ms, nr.posts.size()])
	if not _check(n >= MIN_LAMPS and nr.build_ms < BUILD_BUDGET_MS, "lamps %d (min %d), build %.0f ms (max %.0f)" % [n, MIN_LAMPS, nr.build_ms, BUILD_BUDGET_MS]):
		return false
	var plot: PackedVector2Array = _plot()
	var clear: PackedVector2Array = NightRoads.cine_clear_points()
	var water: Array = MapBuilder._water_polygons(md)
	var grid: Dictionary = {}
	for i: int in range(n):
		var b: Vector3 = nr.lamp_base[i]
		var c := Vector2(b.x, b.z)
		if not _check(not Geometry2D.is_point_in_polygon(c, plot), "lamp %d inside the campus plot" % i):
			return false
		for k: Vector2 in clear:
			if not _check(c.distance_to(k) >= NightRoads.CINE_CLEAR, "lamp %d within %.0f m of a cinematic stage" % [i, NightRoads.CINE_CLEAR]):
				return false
		for sv: Vector2i in MapBuilder._segments_near(c):
			var cw: Array = MapBuilder._carriageways[sv.x]
			var p: PackedVector2Array = cw[0]
			if not _check(MapBuilder._dist_point_segment(c, p[sv.y], p[sv.y + 1]) >= float(cw[1]) * 0.5, "lamp %d stands on a carriageway" % i):
				return false
		for wp: PackedVector2Array in water:
			# bbox first: Geometry2D.is_point_in_polygon can report a point outside a long canal polygon's bbox as inside
			if not _check(not (MapBuilder._bbox(wp).has_point(c) and Geometry2D.is_point_in_polygon(c, wp)), "lamp %d on water" % i):
				return false
		var cell := Vector2i(int(floor(c.x / 20.0)), int(floor(c.y / 20.0)))
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for o: Vector2 in grid.get(Vector2i(cell.x + dx, cell.y + dy), []):
					if not _check(c.distance_to(o) >= NightRoads.MIN_GAP - 0.01, "two lamps %.1f m apart" % c.distance_to(o)):
						return false
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(c)
		if not _check(is_equal_approx(nr.lamp_in[i].length(), 1.0) and nr.lamp_head[i].y > 6.0, "lamp %d head / direction" % i):
			return false
	var tot: Array[int] = [0, 0, 0]
	for j: int in range(nr.posts.size()):
		tot[0] += nr.posts[j].multimesh.instance_count
		tot[1] += nr.heads[j].multimesh.instance_count
		tot[2] += nr.pools[j].multimesh.instance_count
	if not _check(tot[0] == n and tot[1] == n and tot[2] == n and nr.heads.size() == nr.posts.size() and nr.pools.size() == nr.posts.size(), "multimesh instances %s for %d lamps" % [str(tot), n]):
		return false
	for p: MultiMeshInstance3D in nr.pools:
		if not _check(p.material_override == nr.pool_mat and p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and p.visibility_range_end > 0.0, "pool cell setup"):
			return false
	if not _check(nr.pool_mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and nr.pool_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "pool material not unshaded additive"):
		return false
	return true


func _part_b() -> bool:
	nr.viewer_override = nr.lamp_head[0] + Vector3(0.0, -5.0, 0.0)
	nr.set_night(false)
	for p: MultiMeshInstance3D in nr.pools:
		if not _check(not p.visible, "pool visible by day"):
			return false
	if not _check(not nr.head_mat.emission_enabled and nr.lights_on() == 0, "heads lit / lights on by day"):
		return false
	nr.set_night(true)
	for p: MultiMeshInstance3D in nr.pools:
		if not _check(p.visible, "pool hidden at night"):
			return false
	var on: int = nr.lights_on()
	if not _check(nr.head_mat.emission_enabled and on >= 1 and on <= NightRoads.LIGHTS, "night: heads %s, %d lights" % [str(nr.head_mat.emission_enabled), on]):
		return false
	var lights: Array[Node] = nr.find_children("*", "Light3D", true, false)
	if not _check(lights.size() == NightRoads.LIGHTS, "%d Light3D nodes (want %d)" % [lights.size(), NightRoads.LIGHTS]):
		return false
	var vp: Vector3 = nr.viewer_override
	var far_best: float = 0.0
	for l: OmniLight3D in nr.lights:
		if not _check(not l.shadow_enabled, "lamp light casts shadows"):
			return false
		if l.visible:
			var d: float = Vector2(l.global_position.x - vp.x, l.global_position.z - vp.z).length()
			far_best = maxf(far_best, d)
			if not _check(d <= NightRoads.LIGHT_NEAR, "lamp light %.0f m from the viewer" % d):
				return false
	# brute force: the lit lamps are the nearest ones
	var ds: Array = []
	for i: int in range(nr.lamp_count()):
		var h: Vector3 = nr.lamp_head[i]
		var d2: float = Vector2(h.x - vp.x, h.z - vp.z).length()
		if d2 <= NightRoads.LIGHT_NEAR:
			ds.append(d2)
	ds.sort()
	if not _check(ds.size() >= on and absf(float(ds[on - 1]) - far_best) < 0.01, "lights not on the nearest lamps (farthest lit %.2f, nth nearest %.2f)" % [far_best, float(ds[on - 1]) if ds.size() >= on else -1.0]):
		return false
	nr.viewer_override = Vector3(1.0e5, 0.0, 1.0e5)
	nr._update_lights()
	if not _check(nr.lights_on() == 0, "lights on far from every lamp"):
		return false
	print("  B: day off; night pools + %d near lights (nearest, no shadows); off far away" % on)
	return true


func _part_c() -> bool:
	nr.set_night(false)   # the materials' own state first (part B left the night on)
	var mats: Dictionary = MapBuilder.materials()
	var overlay: StandardMaterial3D = mats["overlay"]
	ViceStyle._stylize(overlay)   # the vice pass FreeRoam runs (night_line -> soft emitter)
	var sign: StandardMaterial3D = mats["sign_blue"]
	ViceStyle._stylize(sign)
	var sign0: bool = sign.emission_enabled
	nr.set_night(true)
	if not _check(is_equal_approx(overlay.emission_energy_multiplier, NightRoads.LINE_NIGHT_ENERGY) and sign.emission_enabled and sign.emission_energy_multiplier > 1.4, "night: lane paint %.2f, sign %s" % [overlay.emission_energy_multiplier, str(sign.emission_enabled)]):
		return false
	nr.set_night(false)
	if not _check(is_equal_approx(overlay.emission_energy_multiplier, ViceStyle.NIGHT_LINE_ENERGY) and sign.emission_enabled == sign0, "day: lane paint / sign not restored"):
		return false
	nr.set_night(true)
	holder.remove_child(nr)   # leaving the tree restores the shared materials
	if not _check(is_equal_approx(overlay.emission_energy_multiplier, ViceStyle.NIGHT_LINE_ENERGY) and sign.emission_enabled == sign0, "exit: lane paint / sign not restored"):
		return false
	holder.add_child(nr)
	nr.set_night(false)
	print("  C: lane paint %.2f at night (%.2f otherwise), sign plates glow at night only" % [NightRoads.LINE_NIGHT_ENERGY, ViceStyle.NIGHT_LINE_ENERGY])
	return true


func _cells_in_range(p: Vector3) -> Array[int]:
	var heads: int = 0
	var draws: int = 0
	for j: int in range(nr.posts.size()):
		var c: Vector3 = nr.cell_centers[j]
		var d: float = Vector2(c.x - p.x, c.z - p.z).length()
		if d <= NightRoads.HEAD_RANGE:
			heads += 1
			draws += 1
		if d <= NightRoads.POST_RANGE:
			draws += 1
		if d <= NightRoads.POOL_RANGE + NightRoads.POOL_FADE:
			draws += 1
	return [heads, draws]


func _part_d() -> bool:
	var sp: Vector3 = md.spawn_transform().origin
	var gate: Variant = md.landmark("campus_main_gate")
	var gp := Vector3(float(gate[0]), 0.0, float(gate[1])) if gate is Array else Vector3.ZERO
	for p: Vector3 in [sp, gp]:
		var r: Array[int] = _cells_in_range(p)
		print("  D: at (%.0f, %.0f): %d cells in head range, %d draw instances max at night, %d lights max" % [p.x, p.z, r[0], r[1], NightRoads.LIGHTS])
		if not _check(r[1] <= MAX_DRAWS_IN_RANGE, "%d night-road draws in range (max %d)" % [r[1], MAX_DRAWS_IN_RANGE]):
			return false
	return true


func _part_e() -> bool:
	var roads: NightRoads = roam.get("night_roads") as NightRoads
	if not _check(roads != null and roads.lamp_count() >= MIN_LAMPS, "FreeRoam has no night roads"):
		return false
	if not _check(FxPool.find(self) != null and FxPool.find(self).get_parent() == roam, "FreeRoam has no FX pool"):
		return false
	roam.call("set_time_of_day", "night")
	if not _check(roads.night and roads.pools[0].visible and LookPresets.active(roam) == "night_city", "night: lamps %s, preset %s" % [str(roads.night), LookPresets.active(roam)]):
		return false
	var e: Environment = (roam.get_node("WorldEnvironment") as WorldEnvironment).environment
	if not _check(is_equal_approx(e.glow_hdr_threshold, float(LookPresets.PRESETS["night_city"]["thr"])), "night_city not written on the FreeRoam environment"):
		return false
	roam.call("set_time_of_day", "morning")
	if not _check(not roads.night and not roads.pools[0].visible and roads.lights_on() == 0 and LookPresets.active(roam) == "campus_day", "morning: lamps %s, preset %s" % [str(roads.night), LookPresets.active(roam)]):
		return false
	roam.call("set_time_of_day", "dawn")
	if not _check(LookPresets.active(roam) == "" and not roads.night, "dawn: preset %s" % LookPresets.active(roam)):
		return false
	print("  E: FreeRoam: night -> lamps + night_city, morning -> off + campus_day, dawn -> ViceStyle only; FX pool present")
	return true
