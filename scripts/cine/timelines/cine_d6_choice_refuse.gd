# File: res://scripts/cine/timelines/cine_d6_choice_refuse.gd
# cine_d6_choice_refuse (5.000 s, plan 2026-11-01-w4-day6 beat d6_choice_tail, branch tail of cine_d6_choice for choice 3 =
# "refuse"): same finish bank, same places. The protagonist shakes their head and pushes the dripping bag back: "Không.
# Tiền ướt, em không lấy." A Bầy Sói jet ski swings in to the bank, Thị Lọ hops on behind the rider with her bag and
# speeds off in a fan of spray: "Hẹn gặp ở Lọ Academy nha!"
# No ramps. Music slot cine_d6_choice_refuse (owner file, else the parent slot cine_d6_choice, else silence).
# Bank frame: X along the bank, -Z toward the water (y = -1), the bank top at y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline


func build() -> void:
	slot = "cine_d6_choice_refuse"
	length = 5.0
	story_end = 5.0
	mood = "punchy"
	fade_in = 0.3
	fade_out = 0.5
	stage = CineTimeline.phase_c_stage("bridge")
	var ch: GDScript = load("res://scripts/cine/timelines/cine_d6_choice.gd")
	var lo_at: Vector3 = ch.get_script_constant_map()["LO"]
	var hero_at: Vector3 = ch.get_script_constant_map()["HERO"]
	ch.call("set_dressing", self)
	actor("hero", StoryCast.opts("hero", {"shirt_color": StoryCanal.SHIPPER_SHIRT}), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("lo", StoryCast.opts("thi_lo"), StoryCast.speaker("thi_lo"), StoryCast.color("thi_lo"))
	actor("w1", StoryCast.opts("bay_soi", {"seed": 3203}), StoryCast.speaker("bay_soi"), StoryCast.color("bay_soi"))
	StoryCast.dress(self, "lo", "thi_lo")
	StoryCast.dress(self, "w1", "bay_soi")
	var hop: float = 2.6
	var take: GDScript = load("res://scripts/cine/timelines/cine_d6_choice_take.gd")
	take.call("ski_escape", self, "lo", "w1", lo_at, 1.5, hop, 4.8)
	key("hero", 0.0, hero_at, CineTimeline.face(hero_at, lo_at))
	move("hero", 0.0, "head_no")
	move("hero", 1.0, "shove", {"dur": 0.5, "fade": 0.1})
	move("hero", 1.5, "arms_crossed", {"fade": 0.25})
	hold("hero", 0.0, story_end, "ledger", {"bone": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.09)})
	look("hero", 0.0, story_end, "lo")
	expr("hero", 0.0, "angry")
	expr("hero", hop + 0.5, "done")
	move("lo", 0.0, "present")
	move("lo", 1.2, "shrug", {"fade": 0.15})
	hold("lo", 0.0, 1.2, "cash_bag", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.16), "open": true})
	hold("lo", 1.2, story_end, "cash_bag", {"offset": Vector3(0.0, -0.05, -0.08)})
	expr("lo", 0.0, "done")
	expr("lo", hop, "happy")
	sfx_at(1.05, "rustle", -6.0)
	sfx_at(1.6, "engine_roar", -6.0)
	sfx_at(hop + 0.6, "engine_roar", -3.0)
	sfx_at(hop + 1.4, "evil_laugh", -10.0)
	push_in("S1", 0.0, "hero", {"from": 2.8, "to": 2.4, "side_deg": -15.0, "look_y": 1.2})   # "Không."
	two_shot("S2", 1.0, "hero", "lo", {"side": 1.0, "look_y": 1.1})   # the bag pushed back, the jet ski swings in
	shot("S3", hop + 0.3, "static", "wide from the bank: Thị Lọ rides off behind the Bầy Sói rider in a fan of spray",
		{"pos": Vector3(-3.4, 1.6, 4.4), "look": Vector3(3.0, -0.2, -5.0), "fov": 54.0, "hand": 0.15})
	sub(0.2, 1.8, "hero", "Không. Tiền ướt, em không lấy.")
	joke(0.2, "refusing the bribe because the money is wet")
	sub(hop + 0.5, 1.8, "lo", "Hẹn gặp ở Lọ Academy nha!")
