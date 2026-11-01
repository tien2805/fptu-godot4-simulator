# File: res://scripts/cine/timelines/cine_d6_choice_take.gd
# cine_d6_choice_take (5.000 s, plan 2026-11-01-w4-day6 beat d6_choice_tail, branch tail of cine_d6_choice for choice 3 =
# "take"): same finish bank, same places. The protagonist takes the dripping bag; Thị Lọ grins: "Biết điều đó." A Bầy Sói
# jet ski swings in to the bank, she hops on behind the rider and is gone in a fan of spray, waving; the protagonist is
# left holding the wet bag: "...Ủa, khoan đã?" (the bribe caps the ending at D: StoryDirector.evaluate_ending).
# No ramps. Music slot cine_d6_choice_take (owner file, else the parent slot cine_d6_choice, else silence).
# Bank frame: X along the bank, -Z toward the water (y = -1), the bank top at y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline


func build() -> void:
	slot = "cine_d6_choice_take"
	length = 5.0
	story_end = 5.0
	mood = "playful"
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
	var give: float = 0.7
	var hop: float = 2.3
	ski_escape(self, "lo", "w1", lo_at, 1.2, hop, 4.6)
	# the bag changes hands
	key("hero", 0.0, hero_at, CineTimeline.face(hero_at, lo_at))
	move("hero", 0.0, "idle")
	move("hero", give - 0.3, "present", {"fade": 0.2})
	move("hero", give + 0.6, "idle", {"fade": 0.25})
	move("hero", 3.3, "shrug", {"fade": 0.2})
	hold("hero", 0.0, story_end, "ledger", {"bone": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.09)})
	hold("hero", give, story_end, "cash_bag", {"offset": Vector3(0.0, -0.05, -0.08)})
	look("hero", 0.0, story_end, "lo")
	expr("hero", 0.0, "open")
	expr("hero", 3.2, "surprised")
	move("lo", 0.0, "present")
	hold("lo", 0.0, give, "cash_bag", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.16), "open": true})
	move("lo", give + 0.1, "laugh", {"fade": 0.15})
	expr("lo", 0.0, "happy")
	sfx_at(give, "rustle", -6.0)
	sfx_at(1.3, "engine_roar", -6.0)
	sfx_at(hop + 0.6, "engine_roar", -3.0)
	shot("S1", 0.0, "static", "close: the dripping bag changes hands",
		{"pos": Vector3(0.6, 1.45, 2.7), "look": Vector3(-0.1, 1.05, 1.8), "fov": 42.0})
	two_shot("S2", 1.1, "hero", "lo", {"side": 1.0, "look_y": 1.1})   # Q5: the jet ski swings in behind her
	shot("S3", hop + 0.3, "static", "wide from the bank: she rides off in a fan of spray, waving; the protagonist holds the wet bag",
		{"pos": Vector3(-3.4, 1.6, 4.4), "look": Vector3(3.0, -0.2, -5.0), "fov": 54.0, "hand": 0.15})
	sub(0.9, 1.1, "lo", "Biết điều đó.")
	sub(3.3, 1.4, "hero", "...Ủa, khoan đã?")
	joke(3.3, "the protagonist is left holding a dripping bag while she rides off")


## Thị Lọ's escape shared by both tails: a Bầy Sói jet ski (rider `rider`) swings in along the bank to stop by her at
## `arrive`, she hops on behind him at `hop` and they speed off to the right, gone by `gone`.
static func ski_escape(tl: CineTimeline, lo: String, rider: String, lo_at: Vector3, arrive: float, hop: float, gone: float) -> void:
	var stop := Vector3(lo_at.x + 0.6, -1.0, -1.1)
	var rot := Vector3(-4.0, -90.0, 0.0)   # heading +X along the bank
	var path: Array = [[0.0, Vector3(-16.0, -1.0, -4.0), Vector3(-4.0, -80.0, 4.0)], [arrive, stop, rot], [hop + 0.25, stop, rot],
		[gone, Vector3(20.0, -1.0, -7.0), Vector3(-6.0, -100.0, -6.0)]]
	tl.prop("ski", "jet_ski", path[0][1], -80.0, {"color": Color("#25282E"), "path": path})
	var drv := Vector3(0.0, 0.05, 0.25)
	var back := Vector3(0.0, 0.1, 0.85)
	for k: Array in path:
		var r: Vector3 = k[2]
		tl.key(rider, float(k[0]), (k[1] as Vector3) + Basis(Vector3.UP, deg_to_rad(r.y)) * drv, r.y, {"mode": "linear"})
	tl.move(rider, 0.0, "ride")
	tl.look(rider, arrive, hop + 0.3, lo)
	var seat: Vector3 = stop + Basis(Vector3.UP, deg_to_rad(rot.y)) * back
	var seat_gone: Vector3 = (path[3][1] as Vector3) + Basis(Vector3.UP, deg_to_rad(-100.0)) * back
	tl.key(lo, 0.0, lo_at, CineTimeline.face(lo_at, Vector3(lo_at.x - 1.2, 0.0, lo_at.z + 2.0)))
	tl.key(lo, hop - 0.25, lo_at, CineTimeline.face(lo_at, seat))
	tl.key(lo, hop + 0.25, seat, rot.y, {"mode": "linear", "arc": 0.5})
	tl.key(lo, gone, seat_gone, -100.0, {"mode": "linear"})
	tl.move(lo, hop - 0.2, "flying_kick", {"dur": 0.45, "fade": 0.05})
	tl.move(lo, hop + 0.25, "ride", {"fade": 0.1})
	tl.look(lo, 0.0, tl.story_end, "hero")
	tl.sfx_at(hop + 0.25, "whoosh_down", -6.0)

