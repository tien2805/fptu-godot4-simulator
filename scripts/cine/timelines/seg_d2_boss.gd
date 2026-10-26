# File: res://scripts/cine/timelines/seg_d2_boss.gd
# seg_d2_boss (25.000 s, spec C-D6 beat 6 / C-D9, the full Nobody-style cinematic after the duel with Sói Xám under the Rạch
# Hầm bridge; blocking, rules and tests as seg_d4_brawl through CineFightC: real-time ramp placement, surface-gap contacts,
# the Mixamo tier first with UAL / native / code fallbacks, a beat sheet, tests/test_cine_d2_boss.gd). Night, the bike's
# headlight and the lamp under the deck. Improvised weapons: a dropped wolf helmet, a bike mirror, the chain off a pillar.
#   0.0  standoff: the protagonist holds a biker's dropped wolf helmet; Sói Xám howls the pack in
#   2.4  H1  the helmet, swung like a straight right, into Sói Xám's helmet (slow motion: clonk)     he reels away
#   3.7      a biker's straight right lands on the protagonist's jaw (normal speed, punch-in)
#   4.55     the protagonist snatches a broken-off bike mirror off the ground
#   5.7  H2  the mirror comes down on that biker (slow motion, heavy: the glass cracks)            knocked out flat
#   7.4      the second biker's jab to the stomach (normal speed, punch-in)
#   8.2  H3  a two-handed shove slams him back into a bridge pillar (slow motion)                  slides down, sits
#   9.7      takes the chain off the next pillar, wraps it round the fist
#  11.0  H4  the chain fist into Sói Xám's helmet: the LED eyes go dark (slow motion)               blind, stunned
#  12.4      the third biker's straight right catches the protagonist (normal speed, punch-in)
#  13.4  A1  slow-motion accent: the protagonist slips the second one
#  14.8  H5  finisher: an uppercut sends the blind Sói Xám flying back into the beer crates, one long slow-motion swell
#            to 22.000; the third biker backs off and runs for it
#  22.0-25.0 tail at 1x: "Rút!", the protagonist winded: "Đỉnh nóc kịch trần bay phấp phới."
# No gore. Music slot seg_d2_boss: the owner's local "Heartbreaker" (beat table T on a ~130 bpm grid: retime to its onsets
# when tuning by ear). Stage: CineTimeline.phase_c_stage("bridge") (14 x 10), shared with cine_d2.
extends CineFightC


func _configure() -> void:
	var st: Dictionary = CineTimeline.phase_c_stage("bridge")
	st["exposure"] = 1.5
	st["ambient"] = 1.8
	cfg = {
		"slot": "seg_d2_boss",
		"stage": st,
		"T": {"h1": 2.4, "x1": 3.7, "pick1": 4.55, "h2": 5.7, "x2": 7.4, "h3": 8.2, "pick2": 9.7, "h4": 11.0, "x3": 12.4, "a1": 13.4, "h5": 14.8},
		"cast": {"a": "soi_xam", "b": "bay_soi", "c": "bay_soi", "d": "bay_soi"},
		"cast_extra": {"b": {"seed": 3201, "height": 1.0}, "c": {"seed": 3202, "height": 0.98}, "d": {"seed": 3203, "height": 1.02}},
		"names": {"b": "Bầy Sói 1", "c": "Bầy Sói 2", "d": "Bầy Sói 3"},
		"w1": {"kind": "wolf_helmet", "move": "cross", "opts": {"led_on": false, "color": Color("#5C6168")},
			"offset": Vector3(0.0, 0.0, -0.12), "rot": Vector3(-90.0, 0.0, 0.0), "offset2": Vector3(0.0, -0.02, -0.16), "floor_y": 0.15},
		"w2": {"kind": "bike_mirror", "offset2": Vector3(0.0, 0.05, -0.12), "rot2": Vector3(-20.0, 0.0, 0.0), "floor_y": 0.03,
			"floor_rot": Vector3(0.0, 200.0, 90.0)},
		"w3": {"kind": "chain", "move": "cross", "grab_pos": Vector3(2.16, 0.95, -0.95), "grab_yaw": 90.0, "offset": Vector3(0.0, 0.0, 0.0)},
		"surface": {"kind": "pillar", "pos": Vector3(SURFACE_FACE_X + 0.51, 0.0, 0.75)},
		"surface_extra": [["pillar_b", "pillar", Vector3(SURFACE_FACE_X + 0.51, 0.0, -1.25), 0.0]],
		# per-tier steps into the strikes (tuned with tests/test_cine_d2_boss.gd: surface gaps on every tier)
		"a_pre_h4": "idle",
		"reach": {"H1": {"mixamo": -0.32}, "H4": {"mixamo": -0.16, "ual": 0.12, "native": 0.08, "code": 0.09},
			"X1": {"mixamo": Vector2(-0.26, 0.06), "ual": -0.02}, "X3": {"mixamo": Vector2(-0.16, 0.06), "ual": 0.08, "native": 0.05, "code": 0.05},
			"H5": {"mixamo": Vector2(0.34, -0.18), "ual": -0.08, "native": 0.2, "code": 0.2},
			"X2": {"mixamo": -0.07, "ual": 0.15, "native": 0.1}},
		"crashes": {"kind": "crate_stack", "opts": {"color": Color("#2E7D32")}},
		"dressing": [["deck", "bridge_deck", Vector3.ZERO, 0.0, {"width": 14.0, "depth": 8.0}],
			["bike", "motorbike", Vector3(-4.9, 0.0, 2.7), 35.0, {"headlight": true}]],
		"sfx": {"H1": "helmet_clonk", "H2": "glass_crack", "H3": "impact_heavy", "pick2": "chain_rattle", "H4": "chain_rattle", "crash": "crate_smash"},
		"what": {"H1": "a dropped wolf helmet, swung like a straight right, into Sói Xám's helmet: clonk",
			"H2": "a broken-off bike mirror comes down on a biker: the glass cracks",
			"H3": "a two-handed shove slams a biker back into a bridge pillar",
			"H4": "the chain-wrapped fist into Sói Xám's helmet: the LED eyes go dark",
			"A1": "slow-motion accent: the protagonist slips the third biker's second punch",
			"H5": "uppercut: the blind Sói Xám flies back into the beer crates (long swell)"},
		"shot_what": {"S1": "wide under the bridge: the protagonist with a dropped wolf helmet, Sói Xám and three bikers",
			"S2": "slow-motion close orbit: the helmet into Sói Xám's helmet", "S4": "low and tight: the bike mirror snatched off the ground",
			"S5": "slow motion, low wide: the mirror comes down", "S7": "slow motion: a biker slammed back into the pillar",
			"S8": "medium: the chain off the pillar", "S9": "slow motion, low: the chain fist, the LED eyes go dark",
			"S12": "slow motion: Sói Xám into the beer crates, they burst", "S13": "slow push: the third biker runs for it",
			"S14": "tail wide: the wreckage under the bridge, the protagonist winded"},
		"subs": [[0.4, 1.4, "a", "Bầy Sói, xé nó ra!"], [22.3, 0.7, "d", "Rút!"], [23.0, 2.0, "hero", "Đỉnh nóc kịch trần bay phấp phới."]],
	}


func _extra() -> void:
	StoryCast.dress(self, "a", "soi_xam", 0.0, h4 + 0.03)
	hold("a", h4 + 0.03, story_end, "wolf_helmet", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0), "led_on": false})
	for role: String in ["b", "c", "d"]:
		StoryCast.dress(self, role, "bay_soi")
	sfx_at(0.3, "wolf_howl", -6.0)
	fx_at("H4", "flash", "a:Head", {"power": 0.5})
