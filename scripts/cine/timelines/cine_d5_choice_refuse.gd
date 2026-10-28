# File: res://scripts/cine/timelines/cine_d5_choice_refuse.gd
# cine_d5_choice_refuse (4.000 s, spec C-D8 beat 9, branch tail of cine_d5_choice for choice 2 = "refuse"): same burning
# server room, same places. "Không." - Za Mẫn turns to the desk behind him, puts his coffee down (0.85), takes up his
# "katana bought online" lying there (1.3; already bent) and takes a guard: "Tiếc ghê. Vậy tôi pivot sang... chém." The
# integration then shows his villain card (StoryVillainCard.show_for(self, StoryCast.villain_data("za_man"),
# StoryCast.card_len("za_man"))) and starts the duel.
# No ramps. Music slot cine_d5_choice_refuse (owner file, else the parent slot cine_d5_choice, else silence).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const ZA := Vector3(-0.6, 0.0, -1.3)
const HERO := Vector3(0.35, 0.0, 1.3)
const PUT: float = 0.85
const TAKE: float = 1.3


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
	var ch: GDScript = load("res://scripts/cine/timelines/cine_d5_choice.gd")
	var cup_at: Vector3 = ch.get_script_constant_map()["CUP_ON_DESK"]
	var katana_at: Vector3 = ch.get_script_constant_map()["KATANA_ON_DESK"]
	ch.call("set_dressing", self, TAKE, PUT)
	var y_za: float = CineTimeline.face(ZA, HERO)
	key("hero", 0.0, HERO, CineTimeline.face(HERO, ZA))
	move("hero", 0.0, "arms_crossed")
	move("hero", 1.4, "fight_idle", {"fade": 0.3})
	look("hero", 0.0, 4.0, "za")
	expr("hero", 0.0, "angry")
	# Za Mẫn: the cup down (a reach to the desk), the katana up off it (a second reach), then the guard
	var y_cup: float = CineTimeline.face(ZA, Vector3(cup_at.x, 0.0, cup_at.z))
	var y_kat: float = CineTimeline.face(ZA, Vector3(katana_at.x, 0.0, katana_at.z))
	key("za", 0.0, ZA, y_za)
	key("za", 0.45, ZA, y_cup)
	key("za", 1.0, ZA, y_kat)
	key("za", TAKE + 0.1, ZA, y_kat)
	key("za", TAKE + 0.4, ZA, y_za)
	move("za", 0.0, "sip")
	hold("za", 0.0, PUT, "coffee_cup", {"offset": Vector3(0.0, 0.02, -0.04)})
	strike("za", PUT, "shove", {"dur": 0.45})
	strike("za", TAKE, "shove", {"dur": 0.45})
	hold("za", TAKE, 4.0, "katana", {"offset": Vector3(0.0, 0.0, -0.02), "rot": Vector3(-35.0, 0.0, 0.0), "bend": 22.0})
	move("za", TAKE + 0.3, "staff_guard", {"fade": 0.2})
	look("za", TAKE + 0.2, 4.0, "hero")
	expr("za", 0.0, "done")
	expr("za", 1.4, "angry")
	sfx_at(PUT, "freeze_tick", -14.0)
	sfx_at(TAKE, "sword_clang", -8.0)
	sfx_at(TAKE + 0.05, "whoosh_down", -8.0)
	shot("S1", 0.0, "static", "close: the protagonist, \"Không.\"",
		{"pos": Vector3(0.0, 1.6, 0.35), "look": Vector3(0.35, 1.55, 1.3), "fov": 40.0})
	two_shot("S2", 0.7, "hero", "za", {"side": 1.0, "look_y": 1.2})   # Q5: the cup down, a bent katana up
	sub(0.15, 0.5, "hero", "Không.")
	sub(1.5, 2.3, "za", "Tiếc ghê. Vậy tôi pivot sang... chém.")
	joke(1.5, "startup talk: he pivots to slashing")
