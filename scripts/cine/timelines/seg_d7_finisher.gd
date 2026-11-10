# File: res://scripts/cine/timelines/seg_d7_finisher.gd
# seg_d7_finisher (25.000 s, plan 2026-11-01-w4-day7.md T4, story spec 8.3 "the last move"): d7_boss3's "after", the
# rooftop duel's end in the rain under the helicopter's searchlight, played like the QTE the player just passed (gạt kiếm,
# bật nhảy, kẹp cổ số 21). Lùm Văn Lọ still has the stub of his snapped sabre; the protagonist still has the staff.
#   0.0      wide in the rain: Lọ aims the stub: "Kiếm gãy thì sao? Kế hoạch của tao vẫn còn!"
#   2.2      he charges bent low, the stub thrust at the protagonist's stomach; the protagonist holds the staff level
#            across his body (a côn guard)
#   3.2  H1  gạt kiếm: the staff comes down on the stub, sparks, it spins away over the wet deck (slow motion, medium)
#   4.5      Lọ shakes his stinging hand, points: "Mày có biết tao là ai không?"
#   6.45     joke: "Biết. Ông hiệu trưởng sắp về hưu."; the protagonist shrugs and tosses the staff away
#   8.55 A1  slow-motion accent (the music's accent): Lọ's furious hook sails past (dodge)
#   9.6  H2  a flying knee to the stomach (slow motion, heavy): the protagonist swings out behind the spent hook arm and
#            comes in on Lọ as he drifts back in, turned a little short; Lọ folds double and staggers back
#  10.7      the protagonist hops back for a run-up, sprints in; Lọ straightens up, dazed
#  13.0  H5  finisher: bật nhảy, the scissor takedown, legs round Lọ's neck; he is thrown off to the side in one long
#            slow-motion flip onto the wet helipad (swell to 22.000), stars; "Đòn chân kẹp cổ số 21!"
#  21.2      the helicopter tilts away without him; Lọ from the deck (21.6): "Ê... trực thăng... chờ tao với..."
#  22.0-25.0 tail at 1x: the protagonist over him, a little nod: "Xin vĩnh biệt cụ."
# The helicopter, its rotor, its searchlight and the rain are this timeline's own props on the cinematic clock (the rotor
# spins with a path, the searchlight follows the helicopter, the rain is cine_ambient): in the tower LairTower.hide_for_cine
# hides the level's own (the paused tree would freeze them). The roof itself is a carried set (roof_deck, opts "set") for
# XEM LẠI PHIM; StoryTower plays this on the real roof (LairTower.cine_xf, drop_set). No gore: sparks, splashes, stars.
# Contacts (tests/test_d7_cines.gd, every tier): the staff on the stub at H1, the knee on his torso at H2, the legs round
# his neck at H5. Music slot seg_d7_finisher: the owner's local file (docs/cinematics/music_to_download.md), else silence.
# Stage frame: X right, -Z forward (toward the helicopter), ground y = 0 (the roof deck); yaw in degrees.
extends CineTimeline

const TAIL: float = 3.0
const SWELL_END: float = 22.0
# real times of the impacts (H1, A1, H2, H5) and of the helicopter leaving
const R_H1: float = 3.2
const R_A1: float = 8.55
const R_H2: float = 9.6
const R_H5: float = 13.0
const R_LEAVE: float = 21.2
## The helicopter hovering over the far edge of the helipad (LairTower.HELI_AT, turned to face the duel) and its parts.
const HELI := Vector3(0.0, 9.0, -13.0)
const HELI_YAW: float = 180.0
const AIM := Vector3(0.0, 0.9, 0.0)              # the searchlight's spot on the deck during the fight
const KEY_DT: float = 0.1                        # story s between the rotor / helicopter / searchlight path keys
const ROTOR_DEG: float = 100.0                   # rotor turn per key (1000 deg per story second)
# blocking (the duel on the helipad's centre; the boss starts where MissionBossSaber put him)
const H0 := Vector3(-0.27, 0.0, 1.9)             # square on to the stub (his staff comes down along it)
const H_YAW: float = 0.0
const L0 := Vector3(0.0, 0.0, -1.7)
const L1 := Vector3(0.0, 0.0, 0.5)               # the charge: bent low, the stub thrust at the protagonist's stomach
const CLASH := Vector3(-0.28, 1.04, 1.45)        # where the staff comes down on the stub (H1)
const L1B := Vector3(0.05, 0.0, 0.15)            # knocked back a step by the clash
const H_A1 := Vector3(-0.1, 0.0, 1.75)           # the protagonist slips the hook here
const L_A1 := Vector3(0.0, 0.0, 0.6)             # Lọ's hook (short of him: a miss)
const L_PASS := Vector3(0.45, 0.0, 0.75)         # carried on by the miss, then he turns back
const L_H2 := Vector3(0.45, 0.0, 1.0)            # dazed, facing the protagonist again for the knee
const H_H2 := Vector3(0.45, 0.0, 1.7)            # where the protagonist throws the knee from (toward L_H2: -Z)
const H_SLIP := Vector3(0.2, 0.0, 2.0)           # the side step to H_H2 swings out behind Lọ's spent hook arm
const LO_DRIFT: float = 0.12                     # he is still drifting in (m short of L_H2) as the knee comes up
const LO_H2_TURN: float = -12.0                  # Lọ squares up a little short (his hanging right arm off the knee's line)
const H_H2B := Vector3(0.5, 0.0, 2.0)            # the hop back off the knee
const L_BACK := Vector3(0.5, 0.0, 0.5)           # driven back folded double by the knee
const L_H5 := Vector3(0.55, 0.0, 0.0)            # still doubled over when the protagonist comes flying in
const LO_H5_YAW: float = 210.0                    # Lọ turned to the protagonist coming flying in (his left arm clear of the leap)
const H_RUN := Vector3(1.25, 0.0, 3.0)           # the run-up mark
const L_DOWN := Vector3(-1.3, 0.0, -0.4)        # flung over backwards onto the helipad
# the scissor: the protagonist's root at the impact relative to Lọ (the legs round his neck; tuned by test_d7_cines)
const SC_OFF := Vector3(0.55, 0.0, 0.27)
const SC_UP: float = 0.22                        # extra root height at the impact (m)
const SC_TAKE: float = 0.55                      # story s from the takeoff to the impact
const SC_OUT := Vector3(0.45, 0.0, 0.2)          # right after the impact his legs let go: out of the way of the flip
const LO_OUT := Vector3(-0.35, 0.05, 0.0)       # Lọ's first jolt back off the impact (out of the legs)
const SC_LAND := Vector3(0.5, 0.0, 0.3)          # where he lands, from the impact point (clear of the flip)
# held props: the staff across both hands (CinePropsC staff: its axis along -Z) and the stub in Lọ's right hand
# the staff level across both hands (côn guard: through the left hand and the right, the left end dipping with the left
# hand); STAFF_OFF centres it on the hands (its origin is 0.4 m off its middle, along its axis)
const STAFF_ROT := Vector3(-14.0, 86.5, 0.0)
const STAFF_OFF := Vector3(0.3874, 0.1368, -0.0763)   # + 7.6 cm forward and 4 cm up: in the fists, not the wrists
const SABER_OFF := Vector3(0.0, 0.04, -0.05)    # in his fist (the grip above the wrist)
const STUB_LAND := Vector3(-2.6, 0.057, 0.4)     # where the stub ends up on the deck (on its side: the guard and the point)
const STUB_REST := Vector3(-6.5, 940.0, 90.0)
const STAFF_LAND := Vector3(-2.5, 0.017, 1.75)    # tossed aside to his left, flat on the deck
const TOSS_R: float = 7.25
## H1 / H2 steps into the strikes per tier (CineActor reach), tuned by tests/test_d7_cines.gd.
const REACH_H1: Dictionary = {}
const REACH_H2: Dictionary = {"mixamo": 0.0}
## Lọ's hook falls short on every tier (the miss): a step back from the impact (CineActor reach).
const REACH_A1: Dictionary = {"mixamo": -0.4, "ual": -0.3, "native": -0.2, "code": -0.2}

var h1: float
var a1: float
var h2: float
var h5: float
var s_toss: float
var s_leave: float
var s_stub_land: float


## Story time at real time r (after the ramps are placed).
func _sr(r: float) -> float:
	return clock.story_at(r)


func build() -> void:
	slot = "seg_d7_finisher"
	length = 25.0
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.8
	stage = {"at": Vector2(3930.0, -440.0), "size": Vector2(28.0, 24.0), "yaw_deg": 21.0, "landmark": "be6_center",
		"near": 30.0, "tod": "dawn", "exposure": 1.25, "ambient": 1.3}
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("lo", CastD7.opts("van_lo"), CastD7.SPEAKER, CastD7.COLOR)
	_hits()
	clock.length = length
	clock.build()
	# exact length: the finisher ramp ends at real 22.000, then TAIL story seconds at 1x -> 25.000
	story_end = float(clock.ramp("H5")["s1"]) + TAIL
	clock.story_end = story_end
	h1 = story_time("H1")
	a1 = story_time("A1")
	h2 = story_time("H2")
	h5 = story_time("H5")
	s_toss = _sr(TOSS_R)
	s_leave = _sr(R_LEAVE)
	s_stub_land = h1 + 0.75
	CastD7.dress(self, "lo")
	_props()
	_hero()
	_lo()
	_shots()
	_fx_sfx()
	_subs()


## Slow motion on the parry, the knee and the scissor, one accent on the missed hook (real times).
func _hits() -> void:
	hit("H1", R_H1 - 0.2, "medium", "gạt kiếm: the staff comes down on the stub, it spins away", {"r": R_H1, "att": "hero:staff",
		"tgt": "lo:saber"})
	hit("A1", R_A1 - 0.5, "accent", "slow-motion accent: Lọ's furious hook sails past the protagonist", {"r": R_A1})
	hit("H2", R_H2 - 0.6, "heavy", "a flying knee to the stomach: Lọ folds double", {"r": R_H2, "att": "hero:knees", "tgt": "lo:torso"})
	hit("H5", R_H5 - 0.8, "finisher", "bật nhảy, kẹp cổ số 21: the scissor takedown, Lọ flung over backwards (long swell)",
		{"r": R_H5, "hq": SWELL_END - R_H5 - 0.55, "att": "hero:legs", "tgt": "lo:Neck"})


## The roof (a carried set), the rain, the helicopter with its own rotor and searchlight on path keys, the knocked-off stub
## and the tossed staff.
func _props() -> void:
	prop("roof", "roof_deck", Vector3.ZERO, 0.0, {"set": true, "half": 12.0})
	prop("rain", "rain", Vector3.ZERO, 0.0, {"extents": Vector3(9.0, 0.2, 9.0)})
	var hp: Array = []
	var rp: Array = []
	var lp: Array = []
	var aim_rot: Vector3 = _aim_rot(HELI + _rot_y(CinePropsD7.LIGHT_AT, HELI_YAW), AIM)
	var n: int = int(ceil(story_end / KEY_DT))
	for i: int in n + 1:
		var s: float = minf(float(i) * KEY_DT, story_end)
		var hx: Dictionary = heli_at(s)
		var pos: Vector3 = hx["pos"]
		var rot: Vector3 = hx["rot"]
		var b := Basis.from_euler(rot * (PI / 180.0))
		hp.append([s, pos, rot])
		rp.append([s, pos + b * CinePropsD7.ROTOR_AT, rot + Vector3(0.0, ROTOR_DEG * float(i), 0.0)])
		lp.append([s, pos + b * CinePropsD7.LIGHT_AT, aim_rot + (rot - Vector3(0.0, HELI_YAW, 0.0))])
	prop("heli", "helicopter", HELI, HELI_YAW, {"rotor": false, "path": hp})
	prop("rotor", "heli_rotor", HELI + _rot_y(CinePropsD7.ROTOR_AT, HELI_YAW), HELI_YAW, {"path": rp})
	prop("searchlight", "searchlight", HELI + _rot_y(CinePropsD7.LIGHT_AT, HELI_YAW), HELI_YAW,
		{"path": lp, "energy": 9.0, "range": 24.0, "angle": 14.0})
	# the stub spins off the clash and skids to a stop on the deck
	var stub_from: Vector3 = L1 + Vector3(-0.28, 1.03, 0.59)   # where it is in his hand on H1 (measured: seamless)
	prop("stub", "saber", STUB_LAND, STUB_REST.y, {"broken": true, "show_at": h1 + 0.03, "arc": 0.5,
		"path": [[h1 + 0.03, stub_from, Vector3(0.0, 180.0, 0.0)], [s_stub_land, STUB_LAND, STUB_REST],
			[s_stub_land + 0.01, STUB_LAND, STUB_REST]]})
	# the staff, tossed aside (it lands flat on the deck)
	var toss_from: Vector3 = H0 + Vector3(0.344, 1.437, -0.357)   # the held staff at the toss (measured: seamless)
	# out to his left first (level, clear of him), then it turns as it falls flat
	prop("staff_drop", "staff", STAFF_LAND, 200.0, {"show_at": s_toss, "arc": 0.4,
		"path": [[s_toss, toss_from, STAFF_ROT], [s_toss + 0.18, toss_from + Vector3(-0.95, 0.15, 0.0), STAFF_ROT + Vector3(10.0, 20.0, 0.0)],
			[s_toss + 0.5, STAFF_LAND, Vector3(0.0, 200.0, 0.0)], [s_toss + 0.51, STAFF_LAND, Vector3(0.0, 200.0, 0.0)]]})


## The helicopter at story time s: {"pos", "rot" (deg)}: a slow bob while it hovers, then from R_LEAVE it banks away and
## climbs off over the far parapet.
func heli_at(s: float) -> Dictionary:
	var pos: Vector3 = HELI + Vector3(0.0, sin(s * 1.3) * 0.25, 0.0)
	var rot := Vector3(0.0, HELI_YAW, 0.0)
	if s > s_leave:
		var u: float = clampf((s - s_leave) / maxf(story_end - s_leave, 0.01), 0.0, 1.0)
		var e: float = u * u
		pos += Vector3(7.0, 5.0, -16.0) * e
		rot += Vector3(-12.0 * minf(u * 3.0, 1.0), 35.0 * e, 10.0 * minf(u * 3.0, 1.0))
	return {"pos": pos, "rot": rot}


static func _rot_y(v: Vector3, yaw_deg: float) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * v


## Euler degrees (YXZ) that point a node's -Z from `from` at `to`.
static func _aim_rot(from: Vector3, to: Vector3) -> Vector3:
	var d: Vector3 = (to - from).normalized()
	return Vector3(rad_to_deg(asin(clampf(d.y, -1.0, 1.0))), rad_to_deg(atan2(-d.x, -d.z)), 0.0)


func _hero() -> void:
	var y0: float = H_YAW
	key("hero", 0.0, H0, y0)
	move("hero", 0.0, "staff_guard")
	hold("hero", 0.0, s_toss, "staff", {"mid": "Wrist.L", "offset": STAFF_OFF, "rot": STAFF_ROT})
	look("hero", 0.0, story_end, "lo")
	expr("hero", 0.0, "angry")
	# H1: gạt kiếm, the staff brought down on the stub
	key("hero", h1 - 0.5, H0, y0)
	strike("hero", "H1", "chair_smash", {"reach": REACH_H1})
	move("hero", h1 + 0.35, "staff_guard", {"fade": 0.25})
	# the answer, then the staff tossed aside (it is legs from here on)
	expr("hero", _sr(6.3), "done")
	move("hero", s_toss, "shrug", {"fade": 0.15})
	move("hero", s_toss + 0.45, "fight_idle", {"fade": 0.2})
	expr("hero", s_toss + 0.3, "angry")
	# A1: slips the hook
	key("hero", _sr(7.7), H0, y0)
	key("hero", a1 - 0.1, H_A1, CineTimeline.face(H_A1, L_A1))
	strike("hero", "A1", "dodge")
	expr("hero", a1 - 0.2, "surprised")
	expr("hero", a1 + 0.2, "angry")
	# H2: a side step out behind the spent hook arm (only 0.44 story s after A1), then in for the flying knee
	key("hero", a1 + 0.12, H_A1, CineTimeline.face(H_A1, L_A1))
	key("hero", a1 + 0.18, H_SLIP, CineTimeline.face(H_SLIP, L_H2))
	key("hero", h2 - 0.1, H_H2, CineTimeline.face(H_H2, L_H2))
	strike("hero", "H2", "knee_strike", {"reach": REACH_H2})
	key("hero", h2 + 0.02, H_H2, CineTimeline.face(H_H2, L_H2))
	key("hero", h2 + 0.3, H_H2B, CineTimeline.face(H_H2B, L_BACK))
	move("hero", h2 + 0.5, "fight_idle", {"fade": 0.2})
	# the run-up: hop back to the mark, then sprint in
	var take: Vector3 = L_H5 + SC_OFF + Vector3(0.0, 0.0, 0.9)
	var hit_at: Vector3 = L_H5 + SC_OFF + Vector3(0.0, SC_UP, 0.0)
	var land: Vector3 = hit_at + SC_LAND
	land.y = 0.0
	var y_run: float = CineTimeline.face(H_RUN, take)
	key("hero", _sr(10.8), H_H2B, CineTimeline.face(H_H2B, L_BACK))
	key("hero", _sr(11.35), H_RUN, y_run, {"arc": 0.12})
	move("hero", _sr(11.3), "sprint", {"fade": 0.12})
	key("hero", h5 - SC_TAKE - 0.04, take, CineTimeline.face(take, hit_at))
	# H5: the leap and the scissor (the move carries the jump arc and the roll), the landing
	strike("hero", "H5", "scissor_takedown")
	key("hero", h5, hit_at, 0.0, {"mode": "linear"})
	key("hero", h5 + 0.06, hit_at + SC_OUT, 0.0, {"mode": "linear"})
	key("hero", h5 + 0.44, land, CineTimeline.face(land, L_DOWN), {"mode": "smooth"})
	move("hero", h5 + 0.44, "fight_idle", {"fade": 0.2})
	expr("hero", h5 - 0.6, "angry")
	expr("hero", h5 + 0.8, "done")
	move("hero", _sr(19.0), "idle", {"fade": 0.4})
	# the tail: the little nod, "Xin vĩnh biệt cụ."
	move("hero", _sr(23.55), "nod", {"fade": 0.15})


func _lo() -> void:
	key("lo", 0.0, L0, 180.0)
	move("lo", 0.0, "point")
	hold("lo", 0.0, h1 + 0.03, "saber", {"broken": true, "offset": SABER_OFF})
	look("lo", 0.0, h5 - 0.2, "hero")
	expr("lo", 0.0, "angry")
	# the lunge, the stub's point at the protagonist
	key("lo", _sr(2.1), L0, 180.0)
	move("lo", _sr(2.1), "jog", {"fade": 0.15})
	key("lo", h1, L1, 180.0)
	move("lo", h1 - 0.32, "drive", {"fade": 0.12})   # the charge, bent low: the stub thrust at his stomach
	# H1: the clash knocks him back a step, he shakes out his stinging hand
	move("lo", h1 + 0.03, "startled", {"fade": 0.06})
	expr("lo", h1, "surprised")
	key("lo", h1 + 0.5, L1B, 180.0)
	move("lo", h1 + 0.6, "head_shake", {"fade": 0.15})
	# "Mày có biết tao là ai không?", then arms crossed at the answer
	move("lo", _sr(4.5), "point", {"fade": 0.2})
	expr("lo", _sr(4.4), "angry")
	move("lo", _sr(6.5), "arms_crossed", {"fade": 0.25})
	expr("lo", _sr(6.8), "surprised")
	expr("lo", _sr(7.5), "angry")
	# A1: the furious hook, a miss; carried past, he turns back dazed, still drifting in (his right arm off the knee's line)
	key("lo", _sr(7.6), L1B, 180.0)
	move("lo", _sr(7.6), "jog", {"fade": 0.15})
	key("lo", a1, L_A1, CineTimeline.face(L_A1, H_A1))
	strike("lo", "A1", "hook", {"reach": REACH_A1})
	key("lo", a1 + 0.22, L_PASS, CineTimeline.face(L_A1, H_A1) + 30.0)
	move("lo", a1 + 0.15, "stunned", {"fade": 0.12})
	key("lo", h2 - 0.15, L_H2 - Vector3(0.0, 0.0, LO_DRIFT), CineTimeline.face(L_H2, H_H2) + LO_H2_TURN)
	# H2: the knee folds him double and drives him back; he sways there, doubled over
	move("lo", h2 + 0.01, "doubled", {"fade": 0.3})   # folds as the knee drives him back (not into the protagonist)
	expr("lo", h2, "pain")
	key("lo", h2 + 0.01, L_H2, CineTimeline.face(L_H2, H_H2) + LO_H2_TURN)
	key("lo", h2 + 0.3, L_BACK, CineTimeline.face(L_BACK, H_H2))
	key("lo", h5 - 0.5, L_H5, LO_H5_YAW)
	key("lo", h5, L_H5, LO_H5_YAW)
	move("lo", h5 - 0.55, "stunned", {"fade": 0.35})   # straightens up, dazed: straight into the scissor
	# H5: thrown off to the side in one long slow-motion flip, onto his back on the helipad, stars
	strike("lo", "H5", "thrown")
	key("lo", h5 + 0.06, L_H5 + LO_OUT, 180.0, {"mode": "linear"})   # yanked out of the scissor
	key("lo", h5 + 0.6, L_DOWN, 180.0, {"mode": "linear", "arc": 0.9, "spin": Vector3(-360.0, 0.0, 0.0)})
	move("lo", h5 + 0.63, "lie_flat", {"fade": 0.15})
	expr("lo", h5 + 0.7, "done")


func _shots() -> void:
	shot("S1", 0.0, "dolly", "wide in the rain under the searchlight: Lọ aims the stub, the protagonist on guard",
		{"from": Vector3(6.4, 2.3, 6.2), "to": Vector3(5.6, 2.1, 5.4), "look_from": Vector3(0.0, 2.6, -2.0),
			"look_to": Vector3(0.0, 2.4, -1.8), "fov": 55.0, "hand": 0.25})
	two_shot("S2", _sr(2.0), "lo", "hero", {"side": 1.0, "push": 0.15, "look_y": 1.1, "height": 1.35})
	shot("S3", _sr(R_H1 - 0.3), "orbit", "slow-motion orbit: the staff comes down on the stub, sparks",
		{"center": CLASH + Vector3(0.1, 0.1, 0.0), "radius": 2.4, "deg_from": 60.0, "deg_to": 110.0, "height": 1.6, "fov": 42.0})
	dutch_shot("S4", _sr(4.4), "lo", {"roll": 14.0})
	push_in("S5", _sr(6.35), "hero", {"from": 3.8, "to": 2.6})
	two_shot("S6", _sr(7.15), "hero", "lo", {"side": -1.0, "look_y": 1.15})
	shot("S7", _sr(R_A1 - 0.35), "orbit", "slow-motion accent, low orbit: the hook sails past",
		{"center": (H_A1 + L_A1) * 0.5 + Vector3(0.0, 1.1, 0.0), "radius": 2.6, "deg_from": 210.0, "deg_to": 250.0,
			"height": 1.0, "fov": 44.0})
	shot("S8", _sr(R_H2 - 0.35), "static", "slow motion, low and side-on: the flying knee folds him double",
		{"pos": (H_H2 + L_H2) * 0.5 + Vector3(-2.4, 0.6, -0.9), "look": (H_H2 + L_H2) * 0.5 + Vector3(0.0, 1.25, 0.0), "fov": 46.0})
	shot("S9", _sr(10.8), "dolly", "the protagonist hops back for the run-up, Lọ sways doubled over",
		{"from": L_BACK + Vector3(-1.6, 1.4, -2.8), "to": L_BACK + Vector3(-1.2, 1.3, -2.4), "look_from": H_RUN + Vector3(0.0, 1.2, 0.0),
			"look_to": L_H5 + Vector3(0.4, 1.1, 1.2), "fov": 48.0, "hand": 0.4})
	hero_shot("S10", _sr(11.45), "hero", {"side_deg": 35.0, "dist": 3.6})
	shot("S11", _sr(12.2), "orbit", "slow motion, the long orbit: the leap, the scissor round his neck, the flip",
		{"center": L_H5 + Vector3(0.2, 1.0, -0.6), "radius": 3.2, "deg_from": 80.0, "deg_to": 150.0, "height": 1.3, "fov": 46.0})
	shot("S12", _sr(16.8), "static", "slow motion, low: he comes down on his back on the helipad, the splash",
		{"pos": L_DOWN + Vector3(2.6, 0.45, 1.4), "look": L_DOWN + Vector3(-0.3, 0.5, 0.0), "fov": 44.0})
	shot("S13", _sr(19.4), "crane", "crane up: the protagonist over Lọ in the rain, the searchlight, the helicopter",
		{"from": L_DOWN + Vector3(2.2, 0.9, 2.6), "to": L_DOWN + Vector3(3.4, 3.8, 4.6), "look_from": L_DOWN + Vector3(0.0, 0.5, 0.0),
			"look_to": Vector3(-0.6, 2.4, -6.0), "fov": 60.0})
	shot("S14", _sr(22.0), "static", "tail, low wide: the helicopter tilts away without him",
		{"pos": L_DOWN + Vector3(3.0, 0.5, 3.4), "look": Vector3(1.5, 4.0, -10.0), "fov": 52.0})
	push_in("S15", _sr(23.4), "hero", {"from": 3.4, "to": 2.5})


func _fx_sfx() -> void:
	sfx_at(0.0, "engine_roar", -16.0)
	# H1: steel on wood, sparks off the stub; it clatters down on the deck
	sfx_at(h1 - 0.15, "whoosh_down", -6.0)
	sfx_at("H1", "sword_clang", 0.0)
	fx_at("H1", "sparks", "lo:Wrist.R", {"power": 1.0})
	sfx_at(s_stub_land, "tray_clang", -9.0)
	fx_at(s_stub_land, "dust", STUB_LAND, {"power": 0.3})
	sfx_at(s_toss + 0.5, "impact_light", -9.0)
	# A1 and H2
	sfx_at("A1", "whoosh_down", -4.0)
	sfx_at("H2", "impact_heavy", 0.0)
	sfx_at(h2 + 0.08, "groan", -4.0)
	fx_at("H2", "dust", "lo:Chest", {"power": 0.6})
	# H5: the leap, the scissor, the flip and the splash down
	sfx_at(h5 - 0.45, "whoosh_down", -3.0)
	sfx_at("H5", "impact_heavy", 0.0)
	fx_at("H5", "flash", "lo:Head", {"power": 0.6})
	sfx_at(h5 + 0.6, "body_fall", 0.0)
	fx_at(h5 + 0.6, "dust", L_DOWN, {"power": 1.2})
	fx_at(h5 + 0.8, "stars", "lo", {"until": story_end})
	sfx_at(_sr(R_LEAVE + 0.1), "engine_roar", -7.0)


func _subs() -> void:
	sub(0.3, 2.7, "lo", "Kiếm gãy thì sao? Kế hoạch của tao vẫn còn!")
	sub(4.5, 1.8, "lo", "Mày có biết tao là ai không?")
	sub(6.45, 2.0, "hero", "Biết. Ông hiệu trưởng sắp về hưu.")
	joke(6.45, "Lọ: 'Do you know who I am?' - 'Yes. The headmaster about to retire.'")
	sub(13.6, 2.0, "hero", "Đòn chân kẹp cổ số 21!")
	sub(21.6, 2.0, "lo", "Ê... trực thăng... chờ tao với...")
	joke(21.6, "the helicopter Lọ called flies off without him")
	sub(23.65, 1.1, "hero", "Xin vĩnh biệt cụ.")
