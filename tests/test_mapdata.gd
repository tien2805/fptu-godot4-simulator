# File: res://tests/test_mapdata.gd
extends SceneTree
func _initialize() -> void:
	var md: MapData = MapData.load_default()
	assert(md != null, "mapdata.json must load")
	assert(md.roads().size() > 500, "roads")
	assert(md.roads("campus").size() > 100, "campus roads")
	assert(md.buildings("vinhomes").size() >= 40, "vinhomes buildings")
	var be6: Array = md.buildings("vinhomes").filter(func(b: Dictionary) -> bool: return b["name"] == "Tòa BE6")
	assert(be6.size() == 1 and int(be6[0]["levels"]) >= 20, "BE6 present with levels")
	var plot: PackedVector2Array = MapData.poly(md.landmark("campus_plot"))
	assert(plot.size() == 8 and plot[0] == plot[7], "campus plot closed polygon")
	var sp: Transform3D = md.spawn_transform()
	assert(sp.origin.distance_to(Vector3(3893.2, 0.0, -424.2)) < 1.0, "spawn origin")
	assert(md.route_points().size() > 100 and absf(md.route_length() - 5478.0) < 50.0, "route")
	var b: Rect2 = md.bounds("campus")
	assert(b.size.x > 500.0 and b.has_point(Vector2(0.0, 0.0)), "campus bounds contain origin")
	print("✅ SUCCESS: MAPDATA OK roads=%d buildings=%d" % [md.roads().size(), md.buildings().size()])
	quit(0)
