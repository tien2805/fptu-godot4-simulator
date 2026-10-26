# File: res://scripts/cine/timelines/cine_d5_choice_refuse.gd
# cine_d5_choice_refuse (4.000 s, spec C-D8 beat 9, branch tail of cine_d5_choice for choice 2 = "refuse"): same burning
# server room, same places. "Không." - Za Mẫn sets his coffee down on the desk, draws his "katana bought online" (already a
# little bent) and takes a guard: "Tiếc ghê. Vậy tôi pivot sang... chém." The integration then shows his villain card
# (StoryVillainCard.show_for(self, StoryCast.villain_data("za_man"), StoryCast.card_len("za_man"))) and starts the duel.
# No ramps. Music slot cine_d5_choice_refuse (owner file, else the parent slot cine_d5_choice, else silence).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const ZA := Vector3(-0.6, 0.0, -1.3)
const HERO := Vector3(0.35, 0.0, 1.3)
const DESK := Vector3(-1.5, 0.0, -1.9)


func build() -> void:
	slot = "cine_d5_choice_refuse"
	length = 4.0
	story_end = 4.0
	mood = "punchy"
	fade_in = 0.3
	fade_out = 0.4
	stage = CineTimeline.phase_c_stage("server")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("za", StoryCast.opts("za_man"), StoryCast.speaker("za_man"), StoryCast.color("za_man"))
	StoryCast.dress(self, "za", "za_man")
	(load("res://scripts/cine/timelines/cine_d5_choice.gd") as GDScript).call("set_dressing", self)
	prop("desk", "desk", DESK, 40.0)
	prop("cup", "coffee_cup", DESK + Vector3(0.25, 0.75, 0.1), 0.0, {"show_at": 1.0})
	var y_za: float = CineTimeline.face(ZA, HERO)
	key("hero", 0.0, HERO, CineTimeline.face(HERO, ZA))
	move("hero", 0.0, "arms_crossed")
	move("hero", 1.4, "fight_idle", {"fade": 0.3})
	look("hero", 0.0, 4.0, "za")
	expr("hero", 0.0, "angry")
	key("za", 0.0, ZA, y_za)
	key("za", 0.5, ZA, CineTimeline.face(ZA, DESK))
	key("za", 1.2, ZA, y_za)
	move("za", 0.0, "sip")
	hold("za", 0.0, 1.0, "coffee_cup", {"offset": Vector3(0.0, 0.02, -0.04)})
	strike("za", 1.25, "pickup", {"dur": 0.5})
	hold("za", 1.25, 4.0, "katana", {"offset": Vector3(0.0, 0.0, -0.02), "rot": Vector3(-35.0, 0.0, 0.0), "bend": 8.0})
	move("za", 1.55, "staff_guard", {"fade": 0.2})
	look("za", 1.2, 4.0, "hero")
	expr("za", 0.0, "done")
	expr("za", 1.4, "angry")
	sfx_at(1.25, "sword_clang", -8.0)
	sfx_at(1.3, "whoosh_down", -8.0)
	shot("S1", 0.0, "static", "close: the protagonist, \"Không.\"",
		{"pos": Vector3(0.0, 1.6, 0.35), "look": Vector3(0.35, 1.55, 1.3), "fov": 40.0})
	shot("S2", 0.9, "static", "wide side on: Za Mẫn sets the cup down and draws a slightly bent katana",
		{"pos": Vector3(-3.4, 1.5, 0.9), "look": Vector3(-0.3, 1.2, -0.4), "fov": 46.0})
	sub(0.2, 0.6, "hero", "Không.")
	sub(1.4, 2.3, "za", "Tiếc ghê. Vậy tôi pivot sang... chém.")
