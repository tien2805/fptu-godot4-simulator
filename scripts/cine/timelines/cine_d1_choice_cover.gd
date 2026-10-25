# File: res://scripts/cine/timelines/cine_d1_choice_cover.gd
# cine_d1_choice_cover (4.000 s, spec B-D8 choice scene, branch tail of cine_d1_choice for choice 1 = "cover"): same
# courtyard bench, same places. Phúc throws both arms up in relief, "Mày là nhất! Tao nợ mày một tô mì!", and the
# protagonist ups the price, "…Hai tô." (ba-dum-tss). No ramps. Music slot cine_d1_choice_cover (synthesized, playful).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const BENCH := Vector3(0.0, 0.0, 1.2)
const HERO := Vector3(0.55, 0.0, 0.1)
const PHUC := Vector3(-0.5, 0.0, -0.35)


func build() -> void:
	slot = "cine_d1_choice_cover"
	length = 4.0
	story_end = 4.0
	mood = "playful"
	fade_in = 0.3
	fade_out = 0.4
	stage = (load("res://scripts/cine/timelines/cine_d1_choice.gd") as GDScript).call("choice_stage")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	prop("bench", "bench", BENCH, 0.0)
	prop("lamp", "lamp", Vector3(2.2, 0.0, 1.6), 0.0, {"energy": 2.0})
	key("hero", 0.0, HERO, CineTimeline.face(HERO, PHUC))
	move("hero", 0.0, "arms_crossed")
	look("hero", 0.0, 4.0, "phuc")
	expr("hero", 0.0, "open")
	expr("hero", 2.8, "happy")
	key("phuc", 0.0, PHUC, CineTimeline.face(PHUC, HERO))
	move("phuc", 0.0, "victory")
	move("phuc", 2.2, "talk", {"fade": 0.3})
	look("phuc", 0.0, 4.0, "hero")
	expr("phuc", 0.0, "happy")
	expr("phuc", 3.0, "surprised")
	sfx_at(0.2, "success_fanfare", -9.0)
	sfx_at(3.2, "ba_dum_tss", -5.0)
	shot("S1", 0.0, "static", "two-shot: Phúc's arms up in relief",
		{"pos": Vector3(0.2, 1.5, -2.6), "look": Vector3(0.0, 1.3, -0.1), "fov": 46.0})
	shot("S2", 2.7, "static", "close: the protagonist, deadpan",
		{"pos": Vector3(-0.15, 1.58, -0.75), "look": Vector3(0.55, 1.5, 0.1), "fov": 38.0})
	sub(0.3, 2.4, "phuc", "Mày là nhất! Tao nợ mày một tô mì!")
	sub(2.8, 1.0, "hero", "…Hai tô.")
