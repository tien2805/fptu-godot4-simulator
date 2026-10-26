# File: res://scripts/cine/timelines/seg_d5_boss.gd
# seg_d5_boss (25.000 s, spec C-D8 beat 9 / C-D9, the full Nobody-style cinematic after the katana duel with Lê Minh Za Mẫn
# in the burning server room; blocking, rules and tests as seg_d4_brawl through CineFightC, tests/test_cine_d5_boss.gd).
# Red emergency light and small fires. Improvised weapons: a keyboard, a server panel, the Vovinam staff; his "katana bought
# online" (already bent) snaps on the staff.
#   0.0  standoff: the protagonist holds a keyboard; Za Mẫn, bent katana in hand, sends his guards in
#   1.7      Za Mẫn charges with an overhead katana slash: the protagonist parries it with the keyboard (keys fly)
#   2.6  H1  the keyboard, swung like a straight right, into Za Mẫn's face (slow motion: keys fly)   he reels away
#   3.9      the sheep-masked guard's straight right on the protagonist's jaw (normal speed, punch-in)
#   4.75     the protagonist snatches a torn-off server panel off the floor
#   5.9  H2  the panel comes down on the sheep (slow motion, heavy)                                  knocked out flat
#   7.6      the wolf-masked guard's jab to the stomach (normal speed, punch-in)
#   8.4  H3  a two-handed shove slams him back into the server racks (slow motion)                  slides down, sits
#   9.9      grabs the Vovinam staff off a desk
#  11.2  H4  the staff comes down: Za Mẫn blocks with the katana across over his head, it snaps at mid-blade, the staff
#            lands (slow motion)                                                                     stunned
#  12.6      the fox-masked guard's straight right catches the protagonist (normal speed, punch-in); he walks off
#  13.6  A1  slow-motion accent: Za Mẫn's wild swing with the snapped stub misses
#  15.0  H5  finisher: an uppercut sends Za Mẫn flying back into a server rack, one long slow-motion swell to 22.000;
#            the fox runs for the door
#  22.0-25.0 tail at 1x: "Nghỉ việc!", the protagonist winded: "...Bảo hành bảy ngày hả?"
# Cameras of its own: S1 down the rack aisle past the fire, orbits through the racks, the tail from the back corner.
# No gore: sparks and dust. Music slot seg_d5_boss: the owner's local "The Good Life" (beat table T on seg_d4_brawl's grid:
# retime to its onsets when tuning by ear). Stage: CineTimeline.phase_c_stage("server"), the carried room.
extends CineFightC

const BLADE_LAND := Vector3(-0.5, 0.02, -2.6)   # clear of d's path and of where Za Mẫn flies
## Katana bend (deg): visibly "bought online" from the first frame.
const BEND: float = 22.0
## The snapped blade starts at the katana's mid-blade at H4, in Za Mẫn's frame from his feet (A_D, facing the protagonist):
## measured on the UAL tier with the block crossing the blade over his head (tests/test_cine_d5_boss.gd checks it, 0.15 m).
const BLADE_FROM := Vector3(-0.09, 1.6, -0.12)
## The katana held across, over the head, while he blocks (blade toward his left).
const BLOCK_ROT := Vector3(0.0, 90.0, 0.0)


func _configure() -> void:
	var st: Dictionary = CineTimeline.phase_c_stage("server")
	st["exposure"] = 1.5
	st["ambient"] = 1.8
	cfg = {
		"slot": "seg_d5_boss",
		"stage": st,
		"cast": {"a": "za_man", "b": "guard_sheep", "c": "guard_wolf", "d": "guard_fox"},
		"a_blocks_h4": true,
		"floor_back": 0.95,   # the torn-off panel lies clear of the protagonist's feet
		# Za Mẫn's signatures: an overhead katana slash the protagonist parries with the keyboard, the katana snapping on the
		# staff (H4), then a wild swing with the snapped stub that misses (A1)
		"opener": {"move": "chair_smash", "hero": "block", "dist": 1.2, "reach": -0.1},
		"a1_by": "a", "a1_move": "chair_smash", "a1_reach": -0.25,
		"shots": {
			"S1": {"rig": "dolly", "from": Vector3(-4.4, 1.3, 4.3), "to": Vector3(-4.0, 1.25, 3.9), "look_from": Vector3(0.0, 1.1, -0.6),
				"look_to": Vector3(0.1, 1.1, -0.5), "fov": 50.0, "hand": 0.3},
			"S2": {"deg_from": 300.0, "deg_to": 330.0, "height": 1.6},
			"S11": {"deg_from": 100.0, "deg_to": 140.0, "height": 1.0},
			"S14": {"rig": "dolly", "from": Vector3(-2.6, 2.2, -4.2), "to": Vector3(-2.3, 2.0, -3.9), "look_from": Vector3(0.5, 0.6, 0.5),
				"look_to": Vector3(0.6, 0.6, 0.6), "fov": 54.0, "hand": 0.5}},
		"w1": {"kind": "keyboard", "move": "cross", "offset": Vector3(0.0, 0.0, -0.2), "rot": Vector3(0.0, 90.0, 0.0),
			"offset2": Vector3(0.0, -0.02, -0.14), "floor_y": 0.015},
		"w2": {"kind": "server_panel", "offset2": Vector3(0.0, 0.05, -0.15), "rot2": Vector3(-20.0, 0.0, 0.0), "floor_y": 0.016,
			"floor_rot": Vector3(-90.0, 200.0, 0.0)},
		"w3": {"kind": "staff", "move": "chair_smash", "grab_pos": Vector3(2.45, 0.79, -0.85), "grab_yaw": 0.0,
			"offset2": Vector3(0.4, 0.05, -0.12), "rot2": Vector3(0.0, 90.0, 0.0)},
		"surface": {"kind": "server_rack", "pos": Vector3(SURFACE_FACE_X + 0.56, 0.0, 0.45), "yaw": 90.0, "opts": {"seed": 1}},
		"surface_extra": [["rack_b", "server_rack", Vector3(SURFACE_FACE_X + 0.56, 0.0, 1.05), 90.0, {"seed": 2}],
			["desk", "desk", Vector3(SURFACE_FACE_X + 0.38, 0.0, -0.95), 90.0]],
		"crashes": {"kind": "server_rack", "yaw": -114.0, "opts": {"seed": 0}},
		# per-tier steps into the strikes (tuned with tests/test_cine_d5_boss.gd: surface gaps on every tier)
		"reach": {"H1": {"mixamo": -0.4, "ual": -0.08, "native": -0.05, "code": -0.05},
			"H4": {"mixamo": 0.15, "ual": 0.13, "native": 0.12, "code": 0.07},
			"H5": {"mixamo": Vector2(0.36, -0.18), "ual": -0.01, "native": 0.2, "code": 0.2},
			"X1": {"mixamo": Vector2(-0.22, 0.06), "ual": -0.02}, "X3": {"mixamo": Vector2(-0.16, 0.06), "ual": 0.08, "native": 0.05, "code": 0.05}},
		"dressing": [["room", "server_room", Vector3.ZERO, 0.0, {"width": 13.0, "depth": 9.3, "z1": 4.5, "door_x": EXIT.x}],
			["rack_l0", "server_rack", Vector3(-5.4, 0.0, 0.6), -90.0], ["rack_l1", "server_rack", Vector3(-5.4, 0.0, 1.75), -90.0],
			["rack_r0", "server_rack", Vector3(5.4, 0.0, -1.6), 90.0], ["rack_r1", "server_rack", Vector3(5.4, 0.0, 2.2), 90.0],
			["fire0", "fire", Vector3(-5.0, 0.0, 3.4), 0.0, {"anim": true, "spread": 0.8}],
			["fire1", "fire", Vector3(5.0, 0.0, 3.6), 0.0, {"anim": true, "spread": 0.7}],
			["fire2", "fire", Vector3(-1.6, 0.0, -4.3), 0.0, {"anim": true, "spread": 0.9}]],
		"sfx": {"H1": "keyboard_clack", "H1_fx": "debris", "H2": "door_bang", "H3": "impact_heavy", "H4": "blade_snap", "crash": "crate_smash"},
		"what": {"H1": "a keyboard, swung like a straight right, into Za Mẫn's face: keys fly",
			"H2": "a torn-off server panel comes down on the sheep-masked guard",
			"H3": "a two-handed shove slams the wolf-masked guard back into the server racks",
			"H4": "the staff comes down: the bent katana raised to block snaps, the staff lands",
			"A1": "slow-motion accent: Za Mẫn's wild swing with the snapped stub misses",
			"H5": "uppercut: Za Mẫn flies back into a server rack (long swell)"},
		"shot_what": {"S1": "wide in the burning server room: the protagonist with a keyboard, Za Mẫn with a bent katana, three masked guards",
			"S2": "slow-motion close orbit: the keyboard into Za Mẫn's face", "S4": "low and tight: the server panel snatched off the floor",
			"S5": "slow motion, low wide: the panel comes down", "S7": "slow motion: the wolf slammed back into the racks",
			"S8": "medium: the Vovinam staff off the desk", "S9": "slow motion, low: the staff, the katana snaps",
			"S12": "slow motion: Za Mẫn into a server rack, it bursts in sparks", "S13": "slow push: the fox runs for it",
			"S14": "tail wide: the wreckage in the server room, the protagonist winded"},
		"subs": [[0.35, 1.8, "a", "Đội bảo vệ, xử lý ticket này!"], [22.4, 0.8, "d", "Nghỉ việc!"], [23.4, 1.5, "hero", "...Bảo hành bảy ngày hả?"]],
	}


func _extra() -> void:
	StoryCast.dress(self, "a", "za_man")
	for role: String in ["b", "c", "d"]:
		StoryCast.dress(self, role, String(cfg["cast"][role]))
	# the bent katana in his right hand, across over his head for the block, then the snapped stub; the blade spins away from
	# where it broke (mid-blade)
	var block_s: float = h4 - 0.4
	hold("a", 0.0, block_s, "katana", {"bend": BEND, "offset": Vector3(0.0, 0.0, -0.02), "rot": Vector3(-35.0, 0.0, 0.0)})
	hold("a", block_s, h4, "katana", {"bend": BEND, "offset": Vector3(0.0, 0.0, -0.02), "rot": BLOCK_ROT})
	hold("a", h4, story_end, "katana", {"broken": true, "offset": Vector3(0.0, 0.0, -0.02), "rot": Vector3(-35.0, 0.0, 0.0)})
	var y_a: float = deg_to_rad(CineTimeline.face(A_D, P3))
	var from: Vector3 = A_D + Basis(Vector3.UP, y_a) * BLADE_FROM
	prop("blade", "katana_blade", BLADE_LAND, 40.0, {"show_at": h4, "arc": 0.6,
		"path": [[h4, from, Vector3(0.0, 0.0, 0.0)], [h4 + 0.9, BLADE_LAND, Vector3(0.0, 40.0, 1080.0)]]})
	fx_at("H4", "sparks", "a:Wrist.R", {"power": 0.9})
	sfx_at(h4 + 0.05, "sword_clang", -4.0)
	sfx_at(h4 + 0.9, "sword_clang", -12.0)
	fx_at(sc, "sparks", "crates", {"power": 1.2})
	# the opener: the katana slash rings off the keyboard, keys fly
	sfx_at(s_open, "sword_clang", -3.0)
	fx_at(s_open, "debris", "hero:Wrist.R", {"power": 0.5, "dir": Vector3(0.2, 0.7, 0.4)})
	fx_at(s_open, "sparks", "hero:Wrist.R", {"power": 0.6})
	sfx_at(a1, "whoosh_down", -4.0)
	sfx_at(0.2, "fire_crackle", -12.0)
