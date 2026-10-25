# File: res://scripts/cine/timelines/seg_d4_brawl.gd
# seg_d4_brawl (25.000 s, spec B-D7 beat 6 / B-D10, full Nobody-style cinematic after the Day 4 canteen brawl; rules as
# seg_d1_brawl: real-time ramp placement, surface-gap contacts, the Mixamo tier first with UAL / native / code fallbacks,
# a beat sheet, tests/test_cine_d4_brawl.gd). Closing time in the canteen: the protagonist against three sheep-masked clones
# and Cừu Dolly (masked, cream cardigan), with whatever is at hand. Grounded and messy; the protagonist takes hits too:
#   0.0  standoff, the protagonist still holding a tray; Dolly sends the clones in
#   2.6  H1  the tray, edge first, into C1's mask (slow motion: tray clang)            C1 reels away
#   3.9      C2's straight right lands on the protagonist's jaw (normal speed, punch-in)
#   4.7      the protagonist snatches a plastic chair off the floor
#   5.9  H2  the chair comes down on C2 (slow motion, heavy: it breaks)                  C2 knocked out flat
#   7.6      C3's jab to the stomach (normal speed, punch-in)
#   8.4  H3  a two-handed shove slams C3 back into the serving counter (slow motion)    C3 slides down, sits
#   9.9      grabs the empty soup pot off the counter
#  11.2  H4  the pot comes down over C1's head like a helmet (slow motion: bong)        C1 blind, the pot stays on
#  12.6      Dolly's straight right catches the protagonist's jaw (normal speed, punch-in)
#  13.6  A1  slow-motion accent: the protagonist slips Dolly's hook
#  15.0  H5  finisher: an uppercut sends the blind, pot-headed C1 flying back into the stacked drink crates, one long
#            slow-motion swell to 22.000 (crash on ~18.6 inside it); Dolly backs off and bolts for the side exit
#  22.0-25.0 tail at 1x: Dolly gone ("Bai bai!"), the protagonist winded among the wreckage ("…Lại chạy.")
# No gore: the pot is empty and cold, knockouts, stars, groans. Ramps sit on a 120 bpm-ish grid (no onset data for the
# owner's local track user://music/seg_d4_brawl.mp3: retime "r" values to its onsets when tuning by ear).
# Stage: explicit "at" at the canteen (FPTUCampusBuilder.canteen_center), stage -Z toward D1, 14 x 10 m box
# (|x| <= 7, |z| <= 5); props: the serving counter (right), the drink crates (back left), two tables (out of the fight lanes).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const TAIL: float = 3.0
const CRASH_DS: float = 0.86        # story seconds after H5 when C1 meets the crates (inside the swell)

# props
const COUNTER := Vector3(2.55, 0.0, 0.2)         # yaw 90: its customer face looks -X, at x = 2.55 - 0.325
const COUNTER_FACE_X: float = 2.225
const POT := Vector3(2.52, 0.95, -0.85)
const CRATES := Vector3(-3.2, 0.0, -2.9)
const TABLE_A := Vector3(-4.9, 0.0, -0.2)
const TABLE_B := Vector3(-0.6, 0.0, -4.0)
const EXIT := Vector3(3.6, 0.0, -4.6)

# spacing (m, root to root) of each exchange; tuned against tests/test_cine_d4_brawl.gd (surface gaps on every tier)
const D_H1: float = 1.0             # tray (held in the right hand) straight into C1's mask
const D_C2X: float = 0.97           # C2's cross on the jaw
const D_H2: float = 1.05            # overhead chair smash
const D_C3J: float = 1.0            # C3's jab to the stomach
const D_H3: float = 0.8             # two-handed shove
const D_H4: float = 0.95            # overhead pot smash
const D_DH: float = 1.05            # Dolly's straight right
const D_H5: float = 1.05            # uppercut

# positions
const P0 := Vector3(0.0, 0.0, 1.0)              # the protagonist's start
const C1_0 := Vector3(1.4, 0.0, -1.2)
const C2_0 := Vector3(-1.6, 0.0, -1.0)
const C3_0 := Vector3(1.3, 0.0, 3.4)
const D_0 := Vector3(0.6, 0.0, -3.4)

var P1: Vector3     # after C2's punch (staggered back)
var P2: Vector3     # facing C3 at the counter
var P2B: Vector3    # stepped in for the shove
var CHAIR: Vector3  # the plastic chair just behind the protagonist after C2's punch
var D_B: Vector3    # Dolly backs off after the slip
var P3: Vector3     # at the pot
var C1_A: Vector3
var C1_B: Vector3
var C2_A: Vector3
var C2_B: Vector3
var C2_DOWN: Vector3
var C3_A: Vector3
var C3_HIT: Vector3
var C3_SIT: Vector3
var C1_D: Vector3
var C1_E: Vector3
var D_A: Vector3
var C1_F: Vector3
var C1_CRASH: Vector3
var C1_REST: Vector3
var slam_s: float

# story times
var h1: float
var h2: float
var h3: float
var h4: float
var a1: float
var h5: float
var xc2: float      # C2's punch (3.9)
var xc3: float      # C3's jab (7.6)
var xdh: float      # Dolly's hook (12.6)
var s_chair: float  # chair pickup
var s_pot: float    # pot grab
var sc: float       # the crash into the crates
var s_gone: float   # Dolly out of the side exit


func _sr(r: float) -> float:
	return clock.story_at(r)


static func _d(a: Vector3, b: Vector3) -> Vector3:
	var v: Vector3 = b - a
	v.y = 0.0
	return v.normalized()


func build() -> void:
	slot = "seg_d4_brawl"
	length = 25.0
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5
	stage = {"landmark": "campus_parking_center", "at": CineTimeline.campus_at(FPTUCampusBuilder.canteen_center()), "near": 24.0,
		"size": Vector2(14.0, 10.0), "tod": "sunset", "yaw_deg": CineTimeline.campus_yaw(0.0), "exposure": 1.2, "ambient": 1.4}
	_cast()
	_hits()
	clock.length = length
	clock.build()
	story_end = float(clock.ramp("H5")["s1"]) + TAIL
	clock.story_end = story_end
	h1 = story_time("H1")
	h2 = story_time("H2")
	h3 = story_time("H3")
	h4 = story_time("H4")
	a1 = story_time("A1")
	h5 = story_time("H5")
	xc2 = _sr(3.9)
	xc3 = _sr(7.6)
	xdh = _sr(12.6)
	s_chair = _sr(4.75)
	s_pot = _sr(9.9)
	sc = h5 + CRASH_DS
	s_gone = _sr(23.2)
	_layout()
	_props()
	_hero()
	_c1()
	_c2()
	_c3()
	_dolly()
	_shots()
	_fx_sfx()
	_subs()


func _cast() -> void:
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("dolly", StoryCast.opts("dolly"), StoryCast.speaker("dolly"), StoryCast.color("dolly"))
	for i: int in 3:
		actor("c%d" % (i + 1), StoryCast.opts("clone_masked"), "Nhân bản %d" % (i + 1), StoryCast.color("clone_masked"))


## Slow motion on the four best impacts, one dodge accent and the finisher swell (real times, {"r": ...}). Contact pairs
## (att -> tgt) are checked on every tier by tests/test_cine_d4_brawl.gd.
func _hits() -> void:
	hit("H1", 2.4, "medium", "the tray, edge first, into C1's mask: clang", {"r": 2.6, "att": "hero:tray", "tgt": "c1:Head"})
	hit("H2", 5.5, "heavy", "a plastic chair comes down on C2 and breaks", {"r": 5.9, "att": "hero:chair", "tgt": "c2:upper"})
	hit("H3", 7.9, "light", "a two-handed shove slams C3 back into the serving counter", {"r": 8.4, "att": "hero:hands", "tgt": "c3:torso"})
	hit("H4", 10.6, "medium", "the empty soup pot over C1's head like a helmet: bong", {"r": 11.2, "hq": 0.4, "att": "hero:pot", "tgt": "c1:Head"})
	hit("A1", 12.9, "accent", "slow-motion accent: the protagonist slips Dolly's second hook", {"r": 13.6})
	hit("H5", 14.2, "finisher", "uppercut: the blind, pot-headed C1 flies back into the drink crates (long swell)",
		{"r": 15.0, "hq": 6.45, "att": "hero:hands", "tgt": "c1:upper"})


func _layout() -> void:
	C1_A = P0 + Vector3(0.0, 0.0, -D_H1)
	C1_B = C1_A + Vector3(0.75, 0.0, -0.55)
	var dir_c2: Vector3 = Vector3(-0.74, 0.0, -0.67).normalized()
	C2_A = P0 + dir_c2 * D_C2X
	P1 = P0 - dir_c2 * 0.35 + Vector3(-0.1, 0.0, 0.1)
	C2_B = P1 + _d(P1, C2_A) * D_H2
	C2_DOWN = C2_B + _d(P1, C2_B) * 0.9
	CHAIR = P1 - dir_c2 * 0.62
	C3_A = Vector3(COUNTER_FACE_X - 0.5, 0.0, 0.75)
	P2 = C3_A - Vector3(D_C3J, 0.0, 0.0)
	P2B = C3_A - Vector3(D_H3, 0.0, 0.0)
	C3_HIT = Vector3(COUNTER_FACE_X - 0.2, 0.0, C3_A.z)
	C3_SIT = Vector3(COUNTER_FACE_X - 0.3, 0.0, C3_A.z)
	slam_s = h3 + 0.28
	P3 = Vector3(POT.x - 0.85, 0.0, POT.z + 0.1)
	var dir_c1: Vector3 = Vector3(-0.8, 0.0, 0.6).normalized()
	C1_D = P3 + dir_c1 * D_H4
	C1_E = C1_D + dir_c1 * 0.15
	var dir_d: Vector3 = Vector3(-0.55, 0.0, -0.84).normalized()
	D_A = P3 + dir_d * D_DH
	D_B = D_A + dir_d * 0.9
	C1_F = P3 + _d(P3, CRATES) * D_H5
	C1_CRASH = CRATES - _d(P3, CRATES) * 1.55 + Vector3(0.0, 0.3, 0.0)
	C1_REST = CRATES - _d(P3, CRATES) * 1.55


func _props() -> void:
	prop("counter", "counter", COUNTER, 90.0, {"len": 3.0})
	prop("pot", "soup_pot", POT, 0.0, {"hide_at": s_pot})
	prop("crates", "crate_stack", CRATES, 20.0, {"color": Color("#B03A2E")})
	prop("chair", "chair", CHAIR, 200.0, {"hide_at": s_chair})
	prop("table_a", "table", TABLE_A, 90.0)
	prop("table_b", "table", TABLE_B, 0.0)
	prop("tray_drop", "tray", P0 + Vector3(-0.55, 0.012, -0.2), 35.0, {"show_at": _sr(3.42), "food": false})


## Story times around the ramps are compressed, so every key and cue here is anchored on a REAL time through _sr().
func _hero() -> void:
	# 0-2.6 standoff with the tray, then the tray into C1's mask; drops it (3.42)
	key("hero", 0.0, P0, 0.0)
	key("hero", _sr(2.2), P0, 0.0)
	move("hero", 0.0, "tray_hold")
	hold("hero", 0.0, _sr(1.95), "tray", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.12)})
	hold("hero", _sr(1.95), _sr(3.42), "tray", {"offset": Vector3(0.0, 0.0, -0.14), "rot": Vector3(0.0, 0.0, 90.0)})
	move("hero", _sr(1.9), "fight_idle", {"fade": 0.15})
	expr("hero", 0.0, "open")
	expr("hero", _sr(1.6), "angry")
	strike("hero", "H1", "cross", {"dur": 0.5, "reach": {"mixamo": -0.25}})
	move("hero", _sr(3.4), "idle", {"fade": 0.15})   # hands low: C2's cross lands on the jaw
	look("hero", 0.0, _sr(3.5), "c1")
	look("hero", _sr(3.6), _sr(5.5), "c2")
	# 3.9 C2's cross on the jaw: snaps back a step
	var y_c2: float = CineTimeline.face(P0, C2_A)
	key("hero", _sr(3.5), P0, 0.0)
	key("hero", _sr(3.75), P0, y_c2)
	strike("hero", xc2, "hit_head")
	expr("hero", xc2, "pain")
	key("hero", xc2, P0, y_c2)
	key("hero", _sr(4.25), P1, y_c2, {"mode": "out"})
	# 4.75 grabs the chair behind, turns back, 5.9 brings it down on C2
	var y_ch: float = CineTimeline.face(P1, CHAIR)
	var y_c2b: float = CineTimeline.face(P1, C2_B)
	key("hero", _sr(4.4), P1, y_ch)
	strike("hero", s_chair, "pickup", {"dur": 0.45})
	hold("hero", s_chair, h2 + 0.03, "chair", {"mid": "Wrist.L", "held": true, "offset": Vector3(0.0, 0.05, -0.12), "rot": Vector3(-20.0, 0.0, 0.0)})
	key("hero", _sr(5.0), P1, y_ch)
	key("hero", _sr(5.3), P1, y_c2b)
	strike("hero", "H2", "chair_smash")
	expr("hero", s_chair, "angry")
	move("hero", _sr(7.25), "fight_idle", {"fade": 0.2})
	look("hero", _sr(6.6), _sr(9.2), "c3")
	# 7.6 C3's jab to the stomach at the counter, 8.4 a step in and the shove
	var y_c3: float = CineTimeline.face(P2, C3_A)
	key("hero", _sr(6.9), P1, y_c2b)
	key("hero", _sr(7.45), P2, y_c3, {"mode": "out"})
	strike("hero", xc3, "hit_stomach")
	expr("hero", xc3, "pain")
	key("hero", _sr(7.95), P2, y_c3)
	key("hero", _sr(8.25), P2B, y_c3, {"mode": "out"})
	strike("hero", "H3", "shove", {"reach": {"mixamo": -0.08, "ual": 0.08, "native": 0.06, "code": 0.06}})
	expr("hero", _sr(8.2), "angry")
	move("hero", _sr(9.0), "fight_idle", {"fade": 0.2})
	# 9.9 grabs the pot off the counter (two hands), 11.2 slams it down on C1
	var y_pot: float = CineTimeline.face(P3, POT)
	var y_c1: float = CineTimeline.face(P3, C1_D)
	key("hero", _sr(9.05), P2B, y_c3)
	key("hero", _sr(9.6), P3, y_pot, {"mode": "out"})
	strike("hero", s_pot, "shove", {"dur": 0.5})
	hold("hero", s_pot, h4 + 0.03, "soup_pot", {"mid": "Wrist.L", "offset": Vector3(0.0, 0.08, -0.1)})
	key("hero", _sr(10.2), P3, y_pot)
	key("hero", _sr(10.55), P3, y_c1)
	look("hero", _sr(10.2), _sr(11.9), "c1")
	strike("hero", "H4", "chair_smash")
	move("hero", _sr(12.0), "fight_idle", {"fade": 0.2})
	# 12.6 Dolly's hook, 13.6 slips the second one
	var y_d: float = CineTimeline.face(P3, D_A)
	key("hero", _sr(12.0), P3, y_c1)
	key("hero", _sr(12.3), P3, y_d)
	look("hero", _sr(12.1), _sr(13.9), "dolly")
	strike("hero", xdh, "hit_head")
	expr("hero", xdh, "pain")
	strike("hero", "A1", "dodge")
	expr("hero", _sr(13.4), "angry")
	# 15.0 the uppercut on C1, staggering in blind
	var y_c1f: float = CineTimeline.face(P3, C1_F)
	key("hero", _sr(14.0), P3, y_d)
	key("hero", _sr(14.25), P3, y_c1f)
	strike("hero", "H5", "uppercut", {"dur": 0.6, "reach": {"mixamo": Vector2(0.4, -0.3), "ual": 0.05, "native": 0.2, "code": 0.2}})
	move("hero", h5 + 0.5, "fight_idle", {"fade": 0.3})
	look("hero", _sr(14.1), sc + 0.3, "c1")
	look("hero", sc + 0.4, story_end, "dolly")
	key("hero", sc + 0.1, P3, y_c1f)
	key("hero", sc + 0.5, P3, CineTimeline.face(P3, EXIT))
	move("hero", _sr(22.3), "winded", {"fade": 0.35})
	expr("hero", sc, "happy")
	expr("hero", _sr(22.4), "done")


func _c1() -> void:
	var y0: float = CineTimeline.face(C1_0, P0)
	var y_a: float = CineTimeline.face(C1_A, P0)
	key("c1", 0.0, C1_0, y0)
	move("c1", 0.0, "fight_idle")
	key("c1", _sr(1.3), C1_0, y0)
	move("c1", _sr(1.3), "walk", {"fade": 0.2})   # arms low on the way in (no guard clash before the tray)
	key("c1", h1, C1_A, y_a, {"mode": "out"})   # steps in onto the tray
	strike("c1", "H1", "hit_head")
	key("c1", _sr(3.7), C1_B, y_a, {"mode": "out"})
	move("c1", _sr(3.3), "stunned", {"fade": 0.15})
	fx_at(_sr(3.3), "stars", "c1", {"until": _sr(9.4)})
	# 9.9 comes back at the protagonist at the counter; 11.2 the pot
	var y_in: float = CineTimeline.face(C1_D, P3)
	key("c1", _sr(9.9), C1_B, CineTimeline.face(C1_B, C1_D))
	move("c1", _sr(9.9), "jog", {"fade": 0.2})
	key("c1", _sr(10.75), C1_D, y_in, {"mode": "out"})
	move("c1", _sr(10.75), "fight_idle", {"fade": 0.12})
	strike("c1", "H4", "hit_head")
	hold("c1", h4 + 0.03, story_end, "soup_pot", {"bone": "Head", "offset": Vector3(0.0, 0.2, 0.0), "rot": Vector3(180.0, 0.0, 0.0)})
	key("c1", h4, C1_D, y_in)
	key("c1", _sr(12.3), C1_E, y_in, {"mode": "out"})
	move("c1", _sr(11.8), "stunned", {"fade": 0.15})
	# 15.0 staggers back in blind, eats the uppercut, flies into the crates (sc, inside the swell)
	var y_f: float = CineTimeline.face(C1_F, P3)
	key("c1", _sr(13.6), C1_E, y_in)
	key("c1", _sr(14.6), C1_F, y_f, {"mode": "out"})
	strike("c1", "H5", "launched_back", {"arc": 0.0})
	key("c1", h5, C1_F, y_f)
	key("c1", sc + 0.08, C1_CRASH, y_f, {"mode": "linear", "arc": 0.35})   # the crates burst (sc) just before he lands
	key("c1", sc + 0.35, C1_REST, y_f, {"mode": "out"})
	move("c1", h5 - 0.08 + 1.6, "lie")
	fx_at(sc + 0.4, "stars", "c1", {"until": story_end})


func _c2() -> void:
	var y0: float = CineTimeline.face(C2_0, P0)
	var y_a: float = CineTimeline.face(C2_A, P0)
	key("c2", 0.0, C2_0, y0)
	move("c2", 0.0, "fight_idle")
	key("c2", _sr(3.2), C2_0, y0)
	key("c2", _sr(3.75), C2_A, y_a, {"mode": "out"})
	strike("c2", xc2, "cross", {"reach": {"mixamo": Vector2(-0.16, 0.06), "ual": -0.02}})
	move("c2", _sr(4.3), "fight_idle", {"fade": 0.15})
	# follows the protagonist, eats the chair
	var y_b: float = CineTimeline.face(C2_B, P1)
	key("c2", _sr(4.3), C2_A, y_a)
	key("c2", _sr(5.25), C2_B, y_b, {"mode": "out"})
	strike("c2", "H2", "knocked_out")
	key("c2", h2, C2_B, y_b)
	key("c2", _sr(7.5), C2_DOWN, y_b, {"mode": "out"})
	# no "lie" cue: knocked_out holds its own last (lying) frame; a crossfade into lie dipped a foot under the floor
	fx_at(_sr(7.6), "stars", "c2", {"until": story_end})


func _c3() -> void:
	var y0: float = CineTimeline.face(C3_0, P0)
	var y_a: float = CineTimeline.face(C3_A, P2)
	key("c3", 0.0, C3_0, y0)
	move("c3", 0.0, "fight_idle")
	# runs round to the counter, jabs the protagonist, is shoved back into it (slam_s), slides down to sit
	var y_run: float = CineTimeline.face(C3_0, C3_A)
	key("c3", _sr(6.5), C3_0, y_run)
	move("c3", _sr(6.5), "jog", {"fade": 0.15})
	key("c3", _sr(7.1), C3_A, y_run, {"mode": "out"})   # stops facing his run, then squares up (no stride into the counter)
	move("c3", _sr(7.05), "fight_idle", {"fade": 0.12})
	key("c3", _sr(7.3), C3_A, y_a)
	strike("c3", xc3, "jab", {"reach": {"ual": 0.15, "native": 0.1}})
	move("c3", _sr(7.95), "fight_idle", {"fade": 0.12})
	strike("c3", "H3", "slammed")
	key("c3", h3, C3_A, y_a)
	key("c3", slam_s, C3_HIT, y_a, {"mode": "out"})
	key("c3", h3 - 0.04 + 0.8, C3_SIT, y_a)
	move("c3", h3 - 0.04 + 0.8, "slumped", {"fade": 0.15})
	fx_at(slam_s + 0.1, "stars", "c3", {"until": story_end})


func _dolly() -> void:
	var y0: float = CineTimeline.face(D_0, P0)
	key("dolly", 0.0, D_0, y0)
	move("dolly", 0.0, "point")
	move("dolly", _sr(1.5), "fight_idle", {"fade": 0.25})
	look("dolly", 0.0, story_end, "hero")
	# 12.6 the hook, 13.6 the second hook misses
	var y_a: float = CineTimeline.face(D_A, P3)
	key("dolly", _sr(11.5), D_0, CineTimeline.face(D_0, D_A))
	move("dolly", _sr(11.5), "jog", {"fade": 0.15})
	key("dolly", _sr(12.15), D_A, y_a, {"mode": "out"})
	move("dolly", _sr(12.1), "fight_idle", {"fade": 0.1})
	strike("dolly", xdh, "cross", {"reach": {"mixamo": Vector2(-0.1, 0.06), "ual": 0.08, "native": 0.05, "code": 0.05}})
	move("dolly", _sr(12.75), "fight_idle", {"fade": 0.12})
	strike("dolly", "A1", "cross", {"reach": {"mixamo": -0.35, "ual": -0.15, "native": -0.15, "code": -0.15}})   # the miss: over the ducking head
	move("dolly", _sr(14.1), "fight_idle", {"fade": 0.15})
	# backs off from the protagonist (clear of C1 staggering in), then bolts for the side exit and is gone
	var y_ex: float = CineTimeline.face(D_B, EXIT)
	key("dolly", _sr(14.0), D_A, y_a)
	key("dolly", _sr(14.5), D_B, y_a, {"mode": "out"})
	key("dolly", sc + 0.3, D_B, y_ex)
	move("dolly", sc + 0.3, "sprint", {"fade": 0.2})
	key("dolly", s_gone, EXIT, y_ex, {"mode": "linear"})
	show("dolly", s_gone, false)


func _shots() -> void:
	shot("S1", 0.0, "dolly", "wide: closing time, the protagonist with a tray, three masked clones and Dolly",
		{"from": Vector3(-3.6, 1.8, 4.6), "to": Vector3(-3.2, 1.7, 4.1), "look_from": Vector3(0.0, 1.1, -0.8),
		"look_to": Vector3(-0.1, 1.1, -0.6), "fov": 52.0, "hand": 0.3})
	shot("S2", h1, "orbit", "slow-motion close orbit: the tray into C1's mask (2.6)",
		{"center": (P0 + C1_A) * 0.5 + Vector3(0.0, 1.4, 0.0), "radius": 1.7, "deg_from": 70.0, "deg_to": 100.0, "height": 1.45,
		"fov": 40.0, "hand": 0.3})
	shot("S3", _sr(3.6), "track", "handheld over C2's shoulder: the cross on the jaw (3.9)",
		{"actor": "c2", "offset": Vector3(0.7, 1.6, 0.9), "look_actor": "hero", "look": Vector3(0.0, 1.4, 0.0), "fov": 42.0, "hand": 1.0})
	shot("S4", s_chair - 0.35, "static", "low and tight: the chair snatched off the floor (4.7)",
		{"pos": P1 + Vector3(1.4, 0.55, 1.2), "look": P1 + Vector3(-0.4, 0.6, 0.6), "fov": 46.0, "hand": 0.8})
	shot("S5", h2, "static", "slow motion, low wide: the chair comes down on C2 (5.9)",
		{"pos": (P1 + C2_B) * 0.5 + Vector3(-1.9, 0.6, 1.6), "look": (P1 + C2_B) * 0.5 + Vector3(0.0, 1.0, 0.0), "fov": 50.0, "hand": 0.4})
	shot("S6", _sr(7.3), "static", "handheld side-on at the counter: C3's jab to the stomach (7.6)",
		{"pos": (P2 + C3_A) * 0.5 + Vector3(0.0, 1.3, 2.3), "look": (P2 + C3_A) * 0.5 + Vector3(0.0, 1.1, 0.0), "fov": 44.0, "hand": 1.0})
	shot("S7", h3, "static", "slow motion: C3 slammed back into the counter (8.4)",
		{"pos": P2 + Vector3(-0.9, 0.7, 1.4), "look": C3_HIT + Vector3(0.0, 0.8, 0.0), "fov": 46.0, "hand": 0.4})
	shot("S8", _sr(9.7), "static", "medium: the soup pot off the counter (9.9)",
		{"pos": P3 + Vector3(-1.2, 1.5, 1.7), "look": P3 + Vector3(0.4, 1.0, -0.1), "fov": 46.0, "hand": 0.8})
	shot("S9", h4, "static", "slow motion, low: the pot comes down over C1's head (11.2)",
		{"pos": (P3 + C1_D) * 0.5 + Vector3(0.3, 0.6, 1.9), "look": (P3 + C1_D) * 0.5 + Vector3(0.0, 1.4, 0.0), "fov": 44.0, "hand": 0.4})
	shot("S10", _sr(12.3), "track", "handheld over Dolly's shoulder: the hook (12.6), the slip (13.6)",
		{"actor": "dolly", "offset": Vector3(-0.7, 1.65, 0.8), "look_actor": "hero", "look": Vector3(0.0, 1.4, 0.0), "fov": 42.0, "hand": 1.0})
	shot("S11", _sr(14.5), "orbit", "low slow orbit: the uppercut (15.0), C1 lifts off",
		{"center": (P3 + C1_F) * 0.5 + Vector3(0.0, 1.2, 0.0), "radius": 3.0, "deg_from": 200.0, "deg_to": 240.0, "height": 0.8,
		"fov": 46.0, "hand": 0.4})
	shot("S12", _sr(17.6), "static", "slow motion: C1 into the drink crates, they burst",
		{"pos": CRATES + Vector3(2.6, 1.0, 2.2), "look": CRATES + Vector3(0.2, 0.6, 0.0), "fov": 48.0, "hand": 0.5})
	shot("S13", _sr(19.6), "dolly", "slow push: Dolly turns and bolts for the side exit",
		{"from": P3 + Vector3(0.6, 1.6, 2.4), "to": P3 + Vector3(0.2, 1.55, 1.8), "look_from": EXIT + Vector3(2.0, 1.0, 0.0),
		"look_to": EXIT + Vector3(0.8, 1.0, 0.0), "fov": 50.0, "hand": 0.4})
	shot("S14", _sr(22.2), "dolly", "tail wide: the wreckage, C1 with the pot on his head, the protagonist winded",
		{"from": Vector3(1.2, 2.1, 4.6), "to": Vector3(0.8, 1.9, 4.2), "look_from": Vector3(0.0, 0.6, -1.0),
		"look_to": Vector3(0.2, 0.6, -0.8), "fov": 54.0, "hand": 0.5})
	punch(xc2, "medium")
	punch(xc3, "light")
	punch(xdh, "medium")
	punch(s_chair, "light")


func _fx_sfx() -> void:
	sfx_at("H1", "tray_clang", 0.0)
	fx_at("H1", "sparks", "c1:Head", {"power": 0.5})
	sfx_at(xc2, "impact_medium", -2.0)
	fx_at(xc2, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(s_chair, "whoosh_down", -6.0)
	sfx_at("H2", "chair_smash", 0.0)
	fx_at("H2", "debris", "c2:Chest", {"power": 0.9, "dir": Vector3(0.3, 0.8, -0.4)})
	fx_at("H2", "dust", "c2:Chest", {"power": 0.6})
	fx_at(h2 + 0.7, "dust", "c2:Hips", {"power": 0.8})
	sfx_at(h2 + 0.7, "body_fall", -1.0)
	sfx_at(xc3, "impact_light", -3.0)
	sfx_at(slam_s, "impact_heavy", -4.0)
	fx_at(slam_s, "dust", "c3:Hips", {"power": 0.6})
	sfx_at(s_pot, "whoosh_down", -8.0)
	sfx_at("H4", "pot_clonk", 0.0)
	fx_at("H4", "sparks", "c1:Head", {"power": 0.6})
	sfx_at(xdh, "impact_medium", -2.0)
	fx_at(xdh, "sparks", "hero:Head", {"power": 0.3})
	sfx_at("A1", "whoosh_down", -6.0)
	fx_at("H5", "flash", "c1:Chest", {"power": 0.7})
	fx_at("H5", "dust", "hero:Foot.L", {"power": 0.5})
	fx_at(sc, "crate", "crates", {"power": 1.1, "dir": _d(P3, CRATES) + Vector3(0.0, 0.4, 0.0)})
	fx_at(sc, "flash", "crates", {"power": 0.9})
	fx_at(sc, "dust", "c1:Hips", {"power": 1.0})
	sfx_at(sc, "crate_smash", 0.0)
	sfx_at(sc + 0.05, "pot_clonk", -6.0)
	sfx_at(sc + 0.3, "body_fall", -3.0)
	sfx_at(_sr(22.3), "groan", -5.0)
	sfx_at(_sr(23.9), "pot_clonk", -12.0)


func _subs() -> void:
	sub(0.4, 1.5, "hero", "Từ từ… nói chuyện đã.")
	sub(1.95, 0.6, "dolly", "Lên!")
	sub(22.4, 0.9, "dolly", "Bai bai!")
	sub(23.6, 1.0, "hero", "…Lại chạy.")
