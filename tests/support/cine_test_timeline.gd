# File: res://tests/support/cine_test_timeline.gd
# 6 s test timeline for test_cine_timeline / test_cine_player: two actors, one light hit, two shots, an Anh Duy subtitle with
# its "Dịch:" line, one SFX, one FX, one prop.
extends CineTimeline


func build() -> void:
	slot = "test_slot"
	length = 6.0
	story_end = 5.615
	mood = "punchy"
	stage = {"landmark": "campus_west_gate", "near": 30.0, "size": Vector2(10.0, 8.0), "tod": "night"}
	actor("hero", {"preset": "player", "seed": 3}, "Bạn", Color("#F37021"))
	actor("dummy", {"preset": "rider", "seed": 4, "backpack": false, "shirt_color": Color("#1E8C8C")}, "Anh Duy", Color("#9B59B6"))
	hit("H1", 1.6, "light", "jab -> dummy")
	key("hero", 0.0, Vector3(-1.5, 0.0, 0.0), -90.0)
	key("hero", 1.6, Vector3(-0.55, 0.0, 0.0), -90.0)
	move("hero", 0.0, "fight_idle")
	strike("hero", "H1", "jab")
	move("hero", 2.2, "fight_idle")
	key("dummy", 0.0, Vector3(0.3, 0.0, 0.0), 90.0)
	move("dummy", 0.0, "fight_idle")
	strike("dummy", "H1", "hit_head")
	move("dummy", 2.2, "fight_idle")
	expr("dummy", 1.6, "pain")
	look("hero", 3.0, 5.6, "dummy")
	shot("S1", 0.0, "static", "two-shot", {"pos": Vector3(0.0, 1.5, 4.0), "look": Vector3(-0.3, 1.1, 0.0), "fov": 45.0})
	shot("S2", 1.4, "orbit", "orbit on the jab", {"center": Vector3(-0.2, 1.2, 0.0), "radius": 3.0, "deg_from": 20.0, "deg_to": 80.0, "height": 0.6, "fov": 45.0})
	sub(3.0, 1.5, "dummy", "Ok e, a check log r, deploy hotfix lên prod, gg.", "Dịch: Anh ổn, em cứ yên tâm.")
	sfx_at("H1", "groan", -4.0)
	fx_at("H1", "sparks", "dummy:Head", {"power": 0.5})
	prop("crates", "crate_stack", Vector3(1.8, 0.0, -1.5), 15.0)
