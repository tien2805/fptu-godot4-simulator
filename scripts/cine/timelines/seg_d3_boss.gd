# File: res://scripts/cine/timelines/seg_d3_boss.gd
# seg_d3_boss (25.000 s, spec C-D7 beat 9 / C-D9, the full Nobody-style cinematic after the forklift boss in the container
# yard; blocking, rules and tests as seg_d4_brawl through CineFightC, tests/test_cine_d3_boss.gd). Night, the forklift's
# amber beacon. Improvised weapons: a crate of smart glasses, a pallet, Alexander's own party horn.
#   0.0  standoff: the protagonist holds a small crate; Alexander points his masked guards in
#   1.8      Alexander lunges in with a wild hook, vape in hand: the protagonist ducks it (normal speed)
#   2.7  H1  the crate comes down on Alexander (slow motion: it bursts, the gold sunglasses fly)    he reels away
#   4.0      the fox-masked guard's straight right on the protagonist's jaw (normal speed, punch-in)
#   4.85     the protagonist snatches a pallet off the ground
#   6.0  H2  the pallet comes down on the fox (slow motion, heavy: planks fly)                      knocked out flat
#   7.7      the wolf-masked guard's jab to the stomach (normal speed, punch-in)
#   8.5  H3  a two-handed shove slams him back into the forklift (slow motion)                     slides down, sits
#  10.0      grabs the party horn off the forklift
#  11.3  H4  a straight right jams the party horn into Alexander's mouth (slow motion: it squeaks)  stunned, horn in
#  12.7      the sheep-masked guard's straight right catches the protagonist (normal speed, punch-in); he walks off
#  13.7  A1  slow-motion accent: Alexander's lunging tackle misses the protagonist
#  15.1  H5  finisher: an uppercut sends Alexander flying back into the crates of smart glasses, one long slow-motion swell
#            to 22.000; the sheep runs for it
#  22.0-25.0 tail at 1x: "Chạy!", the protagonist winded: "Còn ai tên dài nữa không?"
# Cameras of its own: S1 high from the forklift's overhead guard, high orbits, the tail looking down from the forklift.
# No gore. Music slot seg_d3_boss: the owner's local "Straighten Up and Fly Right" (beat table T on a swing grid: retime to
# its onsets when tuning by ear). Stage: CineTimeline.phase_c_stage("yard"), shared with cine_d3_mannequins / cine_d3.
extends CineFightC


func _configure() -> void:
	var st: Dictionary = CineTimeline.phase_c_stage("yard")
	st["exposure"] = 1.5
	st["ambient"] = 1.8
	cfg = {
		"slot": "seg_d3_boss",
		"stage": st,
		"T": {"h1": 2.7, "x1": 4.0, "pick1": 4.85, "h2": 6.0, "x2": 7.7, "h3": 8.5, "pick2": 10.0, "h4": 11.3, "x3": 12.7, "a1": 13.7, "h5": 15.1},
		"cast": {"a": "alexander", "b": "guard_fox", "c": "guard_wolf", "d": "guard_sheep"},
		"w1": {"kind": "small_crate", "move": "chair_smash", "breaks": true, "offset2": Vector3(0.0, 0.12, -0.16), "rot2": Vector3(-15.0, 0.0, 0.0)},
		"w2": {"kind": "pallet", "opts": {"held": true}, "offset2": Vector3(0.0, 0.05, 0.1), "rot2": Vector3(-20.0, 0.0, 0.0), "floor_y": 0.0},
		"w3": {"kind": "party_horn", "move": "cross", "grab_pos": Vector3(2.32, 1.01, -0.55), "grab_yaw": 70.0, "offset": Vector3(0.0, 0.0, -0.05)},
		"surface": {"kind": "forklift", "pos": Vector3(SURFACE_FACE_X + 0.575, 0.0, 0.1), "opts": {"pallet": true}},
		# per-tier steps into the strikes (tuned with tests/test_cine_d3_boss.gd: surface gaps on every tier)
		"a_pre_h4": "idle",
		"d_dh_extra": 0.12,
		"floor_back": 0.95,   # the pallet lies clear of the protagonist's heels
		# Alexander's signatures: a wild hook with the vape in hand that the protagonist ducks, then a lunging tackle that
		# misses (A1)
		"opener": {"move": "hook", "hero": "dodge", "dist": 1.2, "reach": -0.2},
		"a1_by": "a", "a1_move": "tackle", "a1_reach": -0.35,
		"shots": {
			"S1": {"rig": "dolly", "from": Vector3(3.05, 2.55, 0.45), "to": Vector3(2.9, 2.5, 0.3), "look_from": Vector3(0.0, 0.95, 0.1),
				"look_to": Vector3(-0.1, 1.0, -0.05), "fov": 52.0, "hand": 0.3},
			"S2": {"deg_from": 120.0, "deg_to": 150.0, "height": 2.3},
			"S11": {"deg_from": 160.0, "deg_to": 200.0, "height": 2.4},
			"S14": {"rig": "dolly", "from": Vector3(3.0, 2.9, 0.6), "to": Vector3(2.8, 2.7, 0.8), "look_from": Vector3(-1.5, 0.4, -1.5),
				"look_to": Vector3(-1.4, 0.4, -1.4), "fov": 54.0, "hand": 0.5}},
		"reach": {"H1": {"ual": -0.06, "native": -0.04, "code": -0.04}, "H5": {"mixamo": Vector2(0.36, -0.18), "ual": 0.02, "native": 0.2, "code": 0.2},
			"X1": {"mixamo": Vector2(-0.22, 0.06), "ual": -0.02}, "X3": {"mixamo": Vector2(-0.04, 0.02), "ual": 0.2, "native": 0.17, "code": 0.17}},
		"crashes": {"kind": "crate_stack", "opts": {"color": Color("#8A6A43")}},
		"dressing": [["box0", "container", Vector3(-6.08, 0.0, -5.0), 90.0, {"color": Color("#2E5E8C")}],
			["pallets", "pallet", Vector3(-5.6, 0.0, 1.8), 15.0]],
		"sfx": {"H1": "crate_smash", "H1_fx": "debris", "H2": "crate_smash", "H3": "door_bang", "H4": "party_horn", "crash": "crate_smash"},
		"what": {"H1": "a crate of smart glasses comes down on Alexander: it bursts, the sunglasses fly",
			"H2": "a pallet comes down on the fox-masked guard: planks fly",
			"H3": "a two-handed shove slams the wolf-masked guard back into the forklift",
			"H4": "a straight right jams the party horn into Alexander's mouth: squeak",
			"A1": "slow-motion accent: Alexander's lunging tackle misses the protagonist",
			"H5": "uppercut: Alexander flies back into the crates of smart glasses (long swell)"},
		"shot_what": {"S1": "wide in the container yard: the protagonist with a small crate, Alexander and three masked guards",
			"S2": "slow-motion close orbit: the crate comes down on Alexander", "S4": "low and tight: the pallet snatched off the ground",
			"S5": "slow motion, low wide: the pallet comes down", "S7": "slow motion: the wolf slammed back into the forklift",
			"S8": "medium: the party horn off the forklift", "S9": "slow motion, low: the horn into Alexander's mouth",
			"S12": "slow motion: Alexander into the crates of smart glasses, they burst", "S13": "slow push: the sheep runs for it",
			"S14": "tail wide: the wreckage in the yard, the protagonist winded"},
		"subs": [[0.4, 1.6, "a", "Bắt nó lại cho ta!"], [22.4, 0.8, "d", "Chạy!"], [23.4, 1.5, "hero", "Còn ai tên dài nữa không?"]],
	}


func _extra() -> void:
	hold("a", 0.0, h1, "cigar_vape", {"offset": Vector3(0.0, -0.02, -0.05)})   # swung in the opener's hook
	hold("a", 0.0, story_end, "hawaii_print", {"bone": "Chest", "offset": Vector3.ZERO, "depth": -0.175})
	hold("a", 0.0, h1, "gold_shades", {"bone": "Head", "offset": Vector3(0.0, StoryCast.EYE_UP, StoryCast.EYE_FRONT)})
	var head: Vector3 = A_A + Vector3(0.0, 1.6, -0.05)
	prop("shades_fly", "gold_shades", A_A + Vector3(-0.7, 0.012, -0.8), 200.0, {"show_at": h1, "arc": 0.35,
		"path": [[h1, head, Vector3.ZERO], [h1 + 0.6, A_A + Vector3(-0.7, 0.012, -0.8), Vector3(0.0, 200.0, 0.0)]]})
	hold("a", h4 + 0.03, story_end, "party_horn", {"bone": "Head", "offset": Vector3(0.0, 0.05, -0.115)})
	for role: String in ["b", "c", "d"]:
		StoryCast.dress(self, role, String(cfg["cast"][role]))
	sfx_at(h4 + 0.3, "party_horn", -6.0)
	sfx_at(sc + 0.1, "party_horn", -8.0)
