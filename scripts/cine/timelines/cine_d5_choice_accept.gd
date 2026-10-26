# File: res://scripts/cine/timelines/cine_d5_choice_accept.gd
# cine_d5_choice_accept (4.000 s, spec C-D8 beat 8, branch tail of cine_d5_choice for choice 2 = "accept"): same burning
# server room, same places. Za Mẫn puts his coffee down on the desk behind him (the cup stays in his right hand from the
# choice scene until then), turns back and shakes the protagonist's hand: "Chào mừng sếp mới." - a slow, smug look from the
# protagonist (dun dun duun). The integration plays end_c (ending C) next.
# No ramps. Music slot cine_d5_choice_accept (owner file, else the parent slot cine_d5_choice, else silence).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const ZA := Vector3(-0.6, 0.0, -1.3)
const HERO := Vector3(0.35, 0.0, 1.3)
const MEET := Vector3(-0.22, 0.0, -0.5)        # the protagonist steps in to shake hands (0.88 m from Za Mẫn)
const PUT: float = 0.55


func build() -> void:
	slot = "cine_d5_choice_accept"
	length = 4.0
	story_end = 4.0
	mood = "eerie"
	fade_in = 0.3
	fade_out = 0.5
	stage = CineTimeline.phase_c_stage("server")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("za", StoryCast.opts("za_man"), StoryCast.speaker("za_man"), StoryCast.color("za_man"))
	StoryCast.dress(self, "za", "za_man")
	var ch: GDScript = load("res://scripts/cine/timelines/cine_d5_choice.gd")
	var cup_at: Vector3 = ch.get_script_constant_map()["CUP_ON_DESK"]
	ch.call("set_dressing", self, -1.0, PUT)
	var y_in: float = CineTimeline.face(HERO, MEET)
	key("hero", 0.0, HERO, y_in)
	key("hero", 1.0, MEET, y_in, {"mode": "out"})
	key("hero", 1.2, MEET, CineTimeline.face(MEET, ZA))
	move("hero", 0.0, "walk")
	move("hero", 1.0, "idle", {"fade": 0.2})
	move("hero", 1.25, "handshake", {"fade": 0.15})
	move("hero", 2.6, "arms_crossed", {"fade": 0.3})
	look("hero", 0.0, 4.0, "za")
	expr("hero", 0.0, "open")
	expr("hero", 2.6, "happy")
	# Za Mẫn: the cup down on the desk (a reach), then the handshake
	var y_za: float = CineTimeline.face(ZA, MEET)
	var y_desk: float = CineTimeline.face(ZA, Vector3(cup_at.x, 0.0, cup_at.z))
	key("za", 0.0, ZA, y_za)
	key("za", 0.3, ZA, y_desk)
	key("za", 0.85, ZA, y_desk)
	key("za", 1.15, ZA, y_za)
	move("za", 0.0, "sip")
	hold("za", 0.0, PUT, "coffee_cup", {"offset": Vector3(0.0, 0.02, -0.04)})
	strike("za", PUT, "shove", {"dur": 0.5})
	move("za", 1.25, "handshake", {"fade": 0.15})
	move("za", 2.6, "talk", {"fade": 0.3})
	look("za", 1.0, 4.0, "hero")
	expr("za", 0.0, "happy")
	sfx_at(0.1, "fire_crackle", -10.0)
	sfx_at(PUT, "freeze_tick", -14.0)
	sfx_at(2.4, "dun_dun_duun", -5.0)
	shot("S1", 0.0, "static", "two-shot side on: the cup down on the desk, the handshake",
		{"pos": Vector3(3.0, 1.5, -0.3), "look": Vector3(-0.3, 1.2, -0.8), "fov": 44.0})
	shot("S2", 2.45, "static", "close: the protagonist's smug look, the fire behind",
		{"pos": Vector3(0.5, 1.62, -1.15), "look": Vector3(-0.22, 1.55, -0.5), "fov": 38.0})
	sub(1.3, 1.4, "za", "Chào mừng sếp mới.")
