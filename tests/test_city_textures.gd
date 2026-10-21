# File: res://tests/test_city_textures.gd
# Headless check that every code-drawn city texture (generate_city_textures.py) loads through the
# project's own loader (FileAccess + load_png_from_buffer, i.e. the importer="keep" path) and is 512 px wide.
# Run:  godot --headless --path . --script tests/test_city_textures.gd
extends SceneTree

const FILES: Array[String] = [
	"city_tower_facade.png", "city_tower_facade_n.png",
	"city_beverly_facade.png", "city_beverly_facade_n.png",
	"city_mall_facade.png", "city_shophouse_facade.png", "city_industrial_facade.png",
	"city_canal_water.png", "city_road_overlay.png", "city_roof_flat.png",
]


func _initialize() -> void:
	var problems: int = 0
	for f in FILES:
		var tex: Texture2D = FPTUCampusBuilder.load_texture(f)
		if tex == null:
			push_error("city texture missing or unreadable: " + f)
			problems += 1
			continue
		if tex.get_width() != 512 or tex.get_height() < 128:
			push_error("city texture %s has size %d x %d, expected 512 px wide" % [f, tex.get_width(), tex.get_height()])
			problems += 1
	if problems > 0:
		print("FAILED: %d city texture problem(s)" % problems)
		quit(1)
		return
	print("✅ SUCCESS: CITY TEXTURES OK n=%d" % FILES.size())
	quit(0)
