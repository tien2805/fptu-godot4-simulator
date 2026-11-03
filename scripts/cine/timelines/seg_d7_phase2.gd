# File: res://scripts/cine/timelines/seg_d7_phase2.gd
# seg_d7_phase2 (25.000 s, plan 2026-11-01-w4-day7.md T4, story spec 8.3 "light returns, heroic"): the full Nobody-style
# fight after the blackout (d7_boss2's "after"), when both breakers are back on and the gold lights blaze in the vase
# gallery. Lùm Văn Lọ, blinking in the light, sends his last three masked guards in. Blocking, rules and tests as the
# Phase C fights through CineFightC (tests/test_cine_d7_phase2.gd on tests/support/cine_fight.gd).
# Improvised weapons: the blackout flashlight, a wall speaker that fell in the dark, an antique vase off a plinth.
#   0.0  standoff: the protagonist still holds the flashlight; Lọ: "Có điện thì sao? Tụi bay, xử lý nó!"
#            (w5-day7 T3, the Q1 helpers as Days 2-5 use them: the wide S1, then a dutch angle on Lọ for his line at 0.75,
#            a two-shot of the two into the opener at 1.45)
#   1.7      Lọ runs in and throws a hook: the protagonist sways out of it (normal speed)
#   2.6  H1  the flashlight, swung like a straight right, into Lọ's face (slow motion: clonk)            he reels away
#   3.9      the sheep-masked guard's straight right on the protagonist's jaw (normal speed, punch-in)
#   4.75     the protagonist snatches the fallen wall speaker off the floor
#   5.9  H2  the speaker comes down on the sheep (slow motion, heavy)                                    knocked out flat
#   7.6      the wolf-masked guard's jab to the stomach (normal speed, punch-in)
#   8.4  H3  a two-handed shove slams him back into a plinth (slow motion)                            slides down, sits
#   9.9      lifts an antique vase off the next plinth
#  11.2  H4  the vase comes down on Lọ's head and bursts (slow motion: shards, no gore)                stunned
#  12.6      the fox-masked guard's straight right catches the protagonist (normal speed, punch-in); he walks off
#  13.6  A1  slow-motion accent: Lọ's desperate tackle sails past the protagonist
#  15.0  H5  finisher: an uppercut sends Lọ flying back into a plinth, its vase bursts, one long slow-motion swell to 22.000;
#            the fox runs off
#  20.9     joke: the fox, running: "Lương có năm triệu thôi mà!"
#  22.0-25.0 tail at 1x: Lọ from the floor: "...Gọi trực thăng. Lên sân thượng!" (the wide S14, then a push-in on him
#            down under the plinth at 23.1)
# Staged in the tower: LairTower.cine_xf moves this stage to the hall's (0.4, 0, -0.75) so the surface plinth stands on the
# hall's plinth at (3, 0) and the spare one on (-3, 0) (hide_for_cine hides those two real plinths while it plays); the
# other real plinths, the speakers, the breakers and the sign are the hall's own (drop_set). For XEM LẠI PHIM the carried
# set (LairTower.cine_gallery_set: the hall, the other ten plinths with vases, speakers, breakers, the sign; opts "set")
# stands in for the hall.
# No gore: shards, dust, stars. Music slot seg_d7_phase2: the owner's local file (docs/cinematics/music_to_download.md),
# else silence. Stage frame: X right, -Z forward (toward the hall's back wall and Lọ's sign), ground y = 0; yaw in degrees.
extends CineFightC

## The hall's centre in this stage's frame (the stage origin is the hall's (0.4, 0, -0.75)).
const HALL := Vector3(-0.4, 0.0, 0.75)
## The vase plinth the protagonist lifts the vase off (cine-only, beside the surface plinth).
const GRAB_PLINTH := Vector3(2.6, 0.0, -0.85)
const VASE_GRAB := Vector3(2.6, CinePropsD7.PLINTH_H, -0.85)
## The vase seeds of the hall's plinths at (3, 0) and (-3, 0) (LairTower: seed = the row-major index) the fight's surface
## and spare plinth stand in for.
const SEED_SURFACE: int = 6
const SEED_SPARE: int = 5
## The helper shots (real starts) and their framing (tests/test_d7_cines.gd frames them at their start, middle and end).
const DUTCH_R: float = 0.75
const DUTCH: Dictionary = {"roll": -13.0, "side_deg": 30.0, "dist": 2.8, "push": 0.12}
const TWO_R: float = 1.45
const TWO: Dictionary = {"side": 1.0, "dist": 3.4, "look_y": 1.2, "height": 1.5, "fov": 44.0}
const PUSH_R: float = 23.1
const PUSH: Dictionary = {"from": 4.4, "to": 3.0, "side_deg": 40.0, "height": 1.9, "look_y": 0.45, "fov": 42.0}


func _configure() -> void:
	var st: Dictionary = {"at": Vector2(3930.0, -440.0), "size": Vector2(28.0, 24.0), "yaw_deg": 21.0, "landmark": "be6_center",
		"near": 30.0, "tod": "dawn", "exposure": 1.2, "ambient": 1.3}
	cfg = {
		"slot": "seg_d7_phase2",
		"stage": st,
		"cast": {"a": "van_lo", "b": "guard_sheep", "c": "guard_wolf", "d": "guard_fox"},
		"floor_back": 0.9,     # the fallen speaker lies clear of the protagonist's feet
		# Lọ's signatures: he throws the first punch (a hook the protagonist sways out of) and, stunned, a desperate tackle
		# that misses (A1)
		"opener": {"move": "hook", "hero": "dodge", "dist": 1.2, "reach": -0.2},
		"a1_by": "a", "a1_move": "tackle", "a1_reach": -0.35,
		"a_pre_h4": "idle",
		"shots": {
			"S1": {"rig": "dolly", "from": Vector3(-4.4, 1.4, 4.4), "to": Vector3(-4.0, 1.35, 4.0), "look_from": Vector3(0.0, 1.1, -0.6),
				"look_to": Vector3(0.1, 1.1, -0.5), "fov": 50.0, "hand": 0.3},
			"S2": {"deg_from": 300.0, "deg_to": 330.0, "height": 1.6},
			"S11": {"deg_from": 100.0, "deg_to": 140.0, "height": 1.0},
			"S14": {"rig": "dolly", "from": Vector3(1.2, 2.3, 4.6), "to": Vector3(0.8, 2.1, 4.2), "look_from": Vector3(-0.8, 0.6, -1.4),
				"look_to": Vector3(-0.7, 0.6, -1.3), "fov": 54.0, "hand": 0.5}},
		"w1": {"kind": "flashlight", "move": "cross", "opts": {"on": true}, "offset": Vector3(0.0, 0.0, -0.05),
			"offset2": Vector3(0.0, 0.0, -0.08), "floor_y": 0.034, "drop": Vector3(-0.5, 0.0, 0.45)},
		"w2": {"kind": "speaker", "offset2": Vector3(0.0, 0.05, -0.15), "rot2": Vector3(-20.0, 0.0, 0.0), "floor_y": 0.012,
			"floor_rot": Vector3(-90.0, 200.0, 0.0)},
		"w3": {"kind": "vase", "move": "chair_smash", "opts": {"seed": 4, "h": 0.5}, "grab_pos": VASE_GRAB, "grab_yaw": 0.0,
			"grab_opts": {"seed": 4, "h": 0.5}, "offset2": Vector3(0.0, -0.06, -0.12)},
		# the surface and the spare plinth stand in for the hall's own at (3, 0) and (-3, 0), their vases the same seeds
		"surface": {"kind": "plinth", "pos": Vector3(SURFACE_FACE_X + 0.37, 0.0, 0.75), "opts": {"vase": SEED_SURFACE}},
		"surface_extra": [["plinth_l", "plinth", Vector3(-3.4, 0.0, 0.75), 0.0, {"vase": SEED_SPARE}], ["plinth_g", "plinth", GRAB_PLINTH, 0.0]],
		"crashes": {"kind": "plinth", "yaw": 0.0, "opts": {"vase": 9}},
		# per-tier steps into the strikes (start: seg_d5_boss's, tuned with tests/test_cine_d7_phase2.gd)
		"reach": {"H1": {"mixamo": -0.36, "ual": -0.08, "native": -0.05, "code": -0.05},
			"H2": {"mixamo": -0.3},
			"H4": {"mixamo": -0.05, "ual": -0.04, "native": -0.05, "code": -0.07},
			"H5": {"mixamo": Vector2(0.36, -0.18), "ual": -0.03, "native": 0.2, "code": 0.2},
			"X1": {"mixamo": Vector2(-0.22, 0.06), "ual": -0.02}, "X3": {"mixamo": Vector2(-0.16, 0.06), "ual": 0.08, "native": 0.05, "code": 0.05}},
		"dressing": _hall_set(),
		"sfx": {"H1": "helmet_clonk", "H1_fx": "sparks", "H2": "door_bang", "H3": "impact_heavy", "H4": "glass_crack", "crash": "glass_crack"},
		"what": {"H1": "the blackout flashlight, swung like a straight right, into Lọ's face: clonk",
			"H2": "a fallen wall speaker comes down on the sheep-masked guard",
			"H3": "a two-handed shove slams the wolf-masked guard back into a vase plinth",
			"H4": "an antique vase comes down on Lọ's head and bursts",
			"A1": "slow-motion accent: Lọ's desperate tackle sails past the protagonist",
			"H5": "uppercut: Lọ flies back into a plinth, its vase bursts (long swell)"},
		"shot_what": {"S1": "wide in the lit vase gallery: the protagonist with the flashlight, Lọ in his white suit, three masked guards",
			"S2": "slow-motion close orbit: the flashlight into Lọ's face", "S4": "low and tight: the fallen speaker snatched off the floor",
			"S5": "slow motion, low wide: the speaker comes down", "S7": "slow motion: the wolf slammed back into a plinth",
			"S8": "medium: the antique vase lifted off its plinth", "S9": "slow motion, low: the vase bursts on Lọ's head",
			"S12": "slow motion: Lọ into a plinth, its vase bursts", "S13": "slow push: the fox runs for it",
			"S14": "tail wide: the lit gallery, guards down, Lọ under the plinth"},
		"subs": [[0.3, 2.2, "a", "Có điện thì sao? Tụi bay, xử lý nó!"], [20.9, 1.7, "d", "Lương có năm triệu thôi mà!"],
			[22.65, 2.1, "a", "...Gọi trực thăng. Lên sân thượng!"]],
	}


## The carried hall for XEM LẠI PHIM (dropped in the tower): LairTower's gallery without the two plinths the fight brings.
static func _hall_set() -> Array:
	return LairTower.cine_gallery_set(HALL, LairTower.CINE_PLINTHS["seg_d7_phase2"])


func _cast() -> void:
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("a", CastD7.opts("van_lo"), CastD7.SPEAKER, CastD7.COLOR)
	for role: String in ["b", "c", "d"]:
		var cid: String = String(cfg["cast"][role])
		actor(role, StoryCast.opts(cid), StoryCast.speaker(cid), StoryCast.color(cid))


func _extra() -> void:
	CastD7.dress(self, "a")
	for role: String in ["b", "c", "d"]:
		StoryCast.dress(self, role, String(cfg["cast"][role]))
	# the opener: the hook whooshes past
	sfx_at(s_open, "whoosh_down", -5.0)
	# H1: the lens glass on his face (sparks are the bulb), a dull clonk under it
	sfx_at(h1 + 0.03, "impact_medium", -6.0)
	# H4: the vase bursts on his head (it leaves the protagonist's hands at the impact): shards and dust
	fx_at("H4", "debris", "a:Head", {"power": 0.9, "dir": Vector3(0.0, 0.8, 0.3)})
	fx_at("H4", "dust", "a:Head", {"power": 0.5})
	sfx_at(h4 + 0.05, "crate_smash", -8.0)
	# H3: the wolf slammed into the surface plinth, its vase bursts over him (crate_break hides it)
	fx_at(slam_s, "crate", "surface")
	sfx_at(slam_s + 0.02, "glass_crack", -6.0)
	# the crash plinth's vase bursts as he lands against it (crate_break hides it)
	fx_at(sc, "debris", CRATES + Vector3(0.0, CinePropsD7.PLINTH_H + 0.3, 0.0), {"power": 1.0, "dir": Vector3(-0.3, 0.8, -0.3)})
	sfx_at(a1, "whoosh_down", -4.0)
	joke(20.9, "the fox guard quits mid-fight: the pay is only five million")
	# w5-day7 T3, the Q1 shot helpers (as the Days 2-5 cines): a dutch angle on Lọ's opening line, a two-shot of the two into
	# the opener, a push-in on him from the floor for the tail line; the fight's own S1 .. S14 stay as they were around them
	dutch_shot("D1", _sr(DUTCH_R), "a", DUTCH)
	two_shot("D2", _sr(TWO_R), "hero", "a", TWO)
	push_in("D3", _sr(PUSH_R), "a", PUSH)
	shots.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["s"]) < float(y["s"]))
