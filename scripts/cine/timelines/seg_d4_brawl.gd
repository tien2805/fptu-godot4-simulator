# File: res://scripts/cine/timelines/seg_d4_brawl.gd
# seg_d4_brawl (24.600 s, spec B-D7 beat 6 / B-D10; reworked by plan 2026-11-05-w6-fights: its own choreography, cameras
# and signature moves, every hit on an accent of the owner's cut of "Ain't That a Kick in the Head", see the music note
# below). Closing time in the canteen: the protagonist, a lunch tray in hand, against three sheep-masked clones and Cừu
# Dolly (masked, cream cardigan), with nothing but the canteen's own things: food, trays, a bench, the lunch tables.
#   0.0  standoff: "Từ từ... nói chuyện đã."; Dolly sends them in ("Lên!")
#   2.44 H1  the full tray shoved up into C1's mask: lunch everywhere, the rice bowl stays stuck on his mask; he wipes
#   3.80 / 4.43 / 4.89  the tray shield: C2's jab, jab, cross clang off the tray held up like a shield (normal speed)
#   6.21 H2  the tray, edge first, straight into C2's mask (slow motion, clang): he reels back to the serving counter
#   9.39 H3  the bench ram: the canteen bench carried at a run pins C2 and C3 against the counter (slow motion, heavy);
#            he tosses it over his shoulder (10.75)
#  11.51     guard down, catching his breath: Dolly's sucker punch on the jaw (normal speed, punch-in)
#  13.01 A1  slow-motion accent: Dolly flings a tray like a frisbee, the protagonist ducks under it ...
#  13.49     ... and it clangs off the blind C1's mask behind him
#  17.10 H5  finisher: C1 charges blind, a hip throw lands him on the lunch tables and he slides the whole row in slow
#            motion (trays flying), feet first into the stacked chairs (20.30) and off the end to the floor (21.5); Dolly
#            bolts for the side exit
#  21.6-24.6 tail at 1x: "Bai bai!" from the door, the protagonist winded among the wreckage ("...Lại chạy.")
# Music: the owner's "Ain't That a Kick in the Head" re-cut from 89.38 s of the original (+1.5 dB, W6); every hit sits
# on an accent of it within 0.1 s, the finisher on the cut's strongest (17.10). No gore: the food is lunch, knockouts,
# stars, groans. Contacts are measured on every tier by tests/test_cine_d4_brawl.gd (tests/support/cine_brawl.gd).
# Stage: CineTimeline.canteen_stage (the canteen's courtyard side), 14 x 10 m box (|x| <= 7, |z| <= 5): the serving
# counter on the right, the row of lunch tables at the back left, a bench at the front left.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LENGTH: float = 24.6
const TAIL: float = 3.0
## Real times of the beats (accents of the music cut).
const R_H1: float = 2.44
const R_X1: float = 3.80
const R_X2: float = 4.43
const R_X3: float = 4.89
const R_H2: float = 6.21
const R_H3: float = 9.39
const R_X4: float = 11.51
const R_A1: float = 13.01
const R_TF: float = 13.49
const R_H5: float = 17.10
const R_CRASH: float = 20.30
const SWELL_END: float = 21.6

# props
const COUNTER := Vector3(2.55, 0.0, 0.2)         # yaw 90: its customer face looks -X, at x = 2.55 - 0.325
const COUNTER_FACE_X: float = 2.225
const TRAY_C := Vector3(2.45, 0.962, -1.15)      # a tray on the counter (Dolly's frisbee)
const BENCH := Vector3(-1.2, 0.0, -1.4)          # yaw 180: the backrest away from the protagonist's side
const TABLES: Array[Vector3] = [Vector3(-1.5, 0.0, 2.4), Vector3(-2.9, 0.0, 2.4), Vector3(-4.3, 0.0, 2.4)]
const TABLE_TOP: float = 0.75
const CHAIRS := Vector3(-5.75, 0.0, 2.4)
const EXIT := Vector3(3.6, 0.0, -4.6)

# spacing (m, root to root); tuned against tests/test_cine_d4_brawl.gd (surface gaps on every tier)
const D_H1: float = 0.96            # the food tray shoved two-handed into C1
const D_SH: float = 1.0             # C2's punches onto the raised tray
const D_H2: float = 1.15            # the tray, edge first (a straight right)
const D_RAM: float = 1.05           # the bench ram (hands to the counter face)
const D_DX: float = 1.05            # Dolly's straight right
const D_HT: float = 0.95            # the hip throw

# positions
const P0 := Vector3(0.0, 0.0, 0.0)
const C1_0 := Vector3(0.9, 0.0, 2.3)
const C2_0 := Vector3(1.8, 0.0, -2.4)
const C3_0 := Vector3(1.4, 0.0, 3.4)
const D_0 := Vector3(0.3, 0.0, -3.6)
const DIR1 := Vector3(0.45, 0.0, 0.893)         # from the protagonist toward C1
const DIR2 := Vector3(0.8, 0.0, -0.6)           # toward C2
const DIR_D := Vector3(0.2, 0.0, -0.98)         # toward Dolly at the counter end

var C1_A: Vector3   # C1 steps onto the tray
var C1_C: Vector3   # where the blind C1 wipes his mask (and the frisbee finds him)
var C1_F: Vector3   # C1 at the hip throw
var LAND: Vector3   # his hips on the first table
var SLIDE_END: Vector3
var CRASH: Vector3   # feet first into the stacked chairs (sc)
var TIP: Vector3     # hips past the last table, feet dropping
var C3_W: Vector3    # C3 waits a step off the counter, backs into it as the bench comes
var FLOOR: Vector3
var C2_A: Vector3
var P1: Vector3
var C2_B: Vector3
var C3_A: Vector3
var C2_SIT: Vector3
var C3_SIT: Vector3
var GRAB_B: Vector3
var P_RAM: Vector3
var P_BACK: Vector3   # one step back off the pinned pair, where Dolly finds him
var D_T: Vector3    # Dolly at the counter end, taking a tray
var D_A: Vector3
var D_B: Vector3
var H_T: Vector3    # the protagonist at the hip throw
var W1: Vector3     # his way round the blind C1

# story times
var h1: float
var h2: float
var h3: float
var a1: float
var h5: float
var x1: float
var x2: float
var x3: float
var x4: float
var tf: float       # the frisbee on C1's mask
var s_bench: float  # bench pickup
var s_tray: float   # Dolly takes the counter tray
var s_throw: float  # Dolly lets go of it
var slam_s: float   # C2 / C3 meet the counter
var sc: float       # C1 into the chairs
var s_gone: float   # Dolly out of the side door


func _sr(r: float) -> float:
	return clock.story_at(r)


static func _d(a: Vector3, b: Vector3) -> Vector3:
	var v: Vector3 = b - a
	v.y = 0.0
	return v.normalized()


func build() -> void:
	slot = "seg_d4_brawl"
	length = LENGTH
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5
	stage = CineTimeline.canteen_stage(Vector2(14.0, 10.0), "sunset")
	stage["exposure"] = 1.2
	stage["ambient"] = 1.4
	_cast()
	_hits()
	clock.length = length
	clock.build()
	story_end = float(clock.ramp("H5")["s1"]) + TAIL
	clock.story_end = story_end
	h1 = story_time("H1")
	h2 = story_time("H2")
	h3 = story_time("H3")
	a1 = story_time("A1")
	h5 = story_time("H5")
	x1 = _sr(R_X1)
	x2 = _sr(R_X2)
	x3 = _sr(R_X3)
	x4 = _sr(R_X4)
	tf = _sr(R_TF)
	s_bench = _sr(7.95)
	s_tray = _sr(10.3)
	s_throw = _sr(12.62)
	slam_s = h3 + 0.06
	sc = _sr(R_CRASH)
	s_gone = _sr(SWELL_END)   # hidden at the cut to the wide tail (the door is off screen there)
	_layout()
	_masks()
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


## Sheep masks on (continuity with cine_d4_stare), all four, the whole scene.
func _masks() -> void:
	var m: Dictionary = {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)}
	for id: String in ["c1", "c2", "c3", "dolly"]:
		hold(id, 0.0, story_end, "sheep_mask", m)


## Real-time ramps on the music's accents ({"r": ...}; the story times are placeholders the clock recomputes). Contact
## pairs are checked on every tier by tests/test_cine_d4_brawl.gd.
func _hits() -> void:
	hit("H1", 2.2, "medium", "the full lunch tray shoved up into C1's mask: food everywhere", {"r": R_H1, "att": "hero:tray", "tgt": "c1:upper"})
	hit("H2", 5.0, "heavy", "the tray, edge first, straight into C2's mask: clang", {"r": R_H2, "att": "hero:tray", "tgt": "c2:Head"})
	hit("H3", 7.8, "heavy", "the bench ram: C2 and C3 pinned against the serving counter", {"r": R_H3, "att": "hero:bench", "tgt": "c3:torso"})
	hit("A1", 10.6, "accent", "slow-motion accent: Dolly's tray frisbee sails over the ducking protagonist", {"r": R_A1})
	hit("H5", 12.9, "finisher", "the hip throw: blind C1 slides the length of the lunch tables into the chairs (swell)",
		{"r": R_H5, "hq": SWELL_END - R_H5 - 0.55, "att": "hero:hands", "tgt": "c1:upper"})


func _layout() -> void:
	C1_A = P0 + DIR1 * D_H1
	C1_C = Vector3(0.605, 0.0, 1.22)
	C2_A = P0 + DIR2 * D_SH
	P1 = P0 + DIR2 * (D_SH - D_H2)
	C2_B = Vector3(COUNTER_FACE_X - 0.25, 0.0, -0.42)
	C3_A = Vector3(COUNTER_FACE_X - 0.25, 0.0, 0.62)
	C3_W = C3_A + Vector3(-0.25, 0.0, 0.0)
	C2_SIT = Vector3(COUNTER_FACE_X - 0.32, 0.0, C2_B.z)
	C3_SIT = Vector3(COUNTER_FACE_X - 0.32, 0.0, C3_A.z)
	GRAB_B = BENCH + Vector3(0.0, 0.0, 0.65)
	P_RAM = Vector3(C2_B.x - D_RAM, 0.0, 0.03)
	D_T = Vector3(1.6, 0.0, TRAY_C.z)
	P_BACK = P_RAM + Vector3(-0.25, 0.0, -0.05)
	D_A = P_BACK + DIR_D * D_DX
	D_B = D_A + DIR_D * 1.0
	# the hip throw (seg_d1_brawl's, turned so he travels -X along the tables): hips land on the first table's near end
	LAND = Vector3(TABLES[0].x + 0.7 - 0.95, TABLE_TOP + 0.05, TABLES[0].z)
	C1_F = Vector3(LAND.x + 1.84, 0.0, LAND.z)
	H_T = C1_F + Vector3(-0.633, 0.0, -0.774) * D_HT
	W1 = Vector3(-0.35, 0.0, 0.35)
	SLIDE_END = Vector3(TABLES[2].x - 0.7 + 0.9, LAND.y, LAND.z)
	CRASH = Vector3(-4.58, LAND.y, LAND.z)
	TIP = Vector3(TABLES[2].x - 0.7 - 0.2, LAND.y - 0.05, LAND.z)
	FLOOR = Vector3(CHAIRS.x - 0.3, 0.0, LAND.z)


func _props() -> void:
	prop("counter", "counter", COUNTER, 90.0, {"len": 3.0})
	prop("pot", "soup_pot", Vector3(2.52, 0.95, 1.1), 0.0, {"set": true})
	prop("tray_c", "tray", TRAY_C, 90.0, {"hide_at": s_tray})
	prop("bench", "bench", BENCH, 180.0, {"hide_at": s_bench})
	for i: int in TABLES.size():
		prop("table_%d" % i, "table", TABLES[i], 0.0)
	# lunch on the slide tables: each tray flies off as C1 slides through it
	var trays: Array = [[Vector3(-2.55, TABLE_TOP + 0.006, 2.35), 0.4], [Vector3(-3.9, TABLE_TOP + 0.006, 2.5), 0.55]]
	for j: int in trays.size():
		var at: Vector3 = trays[j][0]
		var s_hit: float = h5 + float(trays[j][1])
		prop("lunch_%d" % j, "tray", at, 0.0, {"food": true, "arc": 0.5,
			"path": [[s_hit, at, Vector3.ZERO], [s_hit + 0.35, Vector3(at.x - 0.7, 0.012, 3.45 + 0.3 * j), Vector3(0.0, 160.0, 180.0)]]})
	prop("chairs_a", "chair", CHAIRS, 90.0, {"color": Color("#2E86C1")})
	prop("chairs_b", "chair", CHAIRS + Vector3(0.0, 0.47, 0.0), 90.0, {"color": Color("#E67E22")})
	# set dressing round the fight (drop_set)
	prop("table_d", "table", Vector3(-4.6, 0.0, -1.7), 90.0, {"set": true})
	prop("table_e", "table", Vector3(-3.0, 0.0, -3.6), 0.0, {"set": true})
	prop("stool_a", "stool", Vector3(-4.0, 0.0, -1.0), 0.0, {"set": true})
	prop("stool_b", "stool", Vector3(-2.3, 0.0, -3.0), 0.0, {"set": true, "color": Color("#2E86C1")})
	# the protagonist's tray, dropped after H2 at his feet
	var t_hand: Vector3 = P1 + Vector3(0.3, 1.05, -0.3)
	var t_floor: Vector3 = P1 + Vector3(0.45, 0.012, 0.1)
	prop("tray_drop", "tray", t_floor, 35.0, {"show_at": _sr(6.9), "arc": 0.08,
		"path": [[_sr(6.9), t_hand, Vector3(0.0, 0.0, 90.0)], [_sr(7.2), t_floor, Vector3(0.0, 35.0, 0.0)]]})
	# the bench, let go after the ram, tossed over his shoulder: it lands behind him, clear of Dolly's way in
	var b_floor: Vector3 = P_RAM + Vector3(-1.0, 0.0, -0.95)
	prop("bench_drop", "bench", b_floor, 270.0, {"show_at": _sr(9.9), "arc": 1.6,
		"path": [[_sr(9.9), P_RAM + Vector3(0.55, 0.62, 0.0), Vector3(0.0, 90.0, 0.0)], [_sr(10.75), b_floor, Vector3(0.0, 270.0, -8.0)]]})
	# Dolly's frisbee: out of her hand (12.62), over the ducking protagonist (13.01), off C1's mask (13.49), to the floor
	var f0: Vector3 = D_B + _d(D_B, P_BACK) * 0.55 + Vector3(0.0, 1.45, 0.0)
	var f1: Vector3 = P_BACK + Vector3(0.0, 1.45, 0.0)
	var f2: Vector3 = C1_C + Vector3(0.05, 1.62, -0.04)
	var f3: Vector3 = C1_C + Vector3(-0.7, 0.012, 0.1)
	prop("tray_fly", "tray", f3, 0.0, {"show_at": s_throw,
		"path": [[s_throw, f0, Vector3(0.0, 0.0, 0.0)], [a1, f1, Vector3(0.0, 540.0, 0.0)], [tf, f2, Vector3(20.0, 900.0, 0.0)],
			[_sr(14.0), f3, Vector3(0.0, 1080.0, 0.0)]]})


## Story times around the ramps are compressed, so every key and cue here is anchored on a REAL time through _sr().
func _hero() -> void:
	var y1: float = CineTimeline.face(P0, C1_A)
	var y2: float = CineTimeline.face(P0, C2_A)
	# 0-2.44 the standoff with a full tray, then shoves it up into C1's mask
	key("hero", 0.0, P0, y1)
	move("hero", 0.0, "tray_hold")
	hold("hero", 0.0, h1 + 0.03, "tray", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.12), "food": true})
	expr("hero", 0.0, "open")
	expr("hero", _sr(1.6), "angry")
	strike("hero", "H1", "shove", {"reach": {"mixamo": 0.0, "ual": 0.06, "native": 0.06, "code": 0.06}})
	look("hero", 0.0, _sr(3.2), "c1")
	# 3.45-5.3 the tray shield against C2's three punches
	hold("hero", h1 + 0.03, _sr(5.35), "tray", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.12, -0.1), "rot": Vector3(90.0, 0.0, 0.0)})
	key("hero", _sr(3.05), P0, y1)
	key("hero", _sr(3.45), P0, y2)
	move("hero", _sr(3.2), "tray_guard", {"fade": 0.15})
	look("hero", _sr(3.3), _sr(7.0), "c2")
	for xr: float in [R_X1, R_X2, R_X3]:
		expr("hero", _sr(xr), "pain")
	expr("hero", _sr(5.1), "angry")
	# 6.21 the tray edge first into C2's mask (a straight right), then drops it
	hold("hero", _sr(5.35), _sr(6.9), "tray", {"offset": Vector3(0.0, 0.0, -0.14), "rot": Vector3(0.0, 0.0, 90.0)})
	move("hero", _sr(5.3), "fight_idle", {"fade": 0.15})
	key("hero", _sr(5.3), P0, y2)
	key("hero", _sr(5.65), P1, y2, {"mode": "out"})   # a step back to swing
	strike("hero", "H2", "cross", {"dur": 0.5, "reach": {"mixamo": -0.1, "ual": 0.15, "native": 0.15, "code": 0.15}})
	move("hero", _sr(7.0), "fight_idle", {"fade": 0.15})
	# 7.95 snatches up the bench, 9.39 rams C2 and C3 into the counter with it
	var y_b: float = CineTimeline.face(GRAB_B, BENCH)
	var y_r: float = CineTimeline.face(GRAB_B, P_RAM)
	key("hero", _sr(7.05), P1, y2)
	key("hero", _sr(7.3), P1, CineTimeline.face(P1, GRAB_B))
	move("hero", _sr(7.3), "walk", {"fade": 0.15})
	key("hero", _sr(7.7), GRAB_B, y_b, {"mode": "out"})
	move("hero", _sr(7.65), "fight_idle", {"fade": 0.1})
	strike("hero", s_bench, "pickup", {"dur": 0.45})
	hold("hero", s_bench, _sr(9.9), "bench", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.44, -0.05), "rot": Vector3(0.0, 180.0, 0.0)})
	expr("hero", s_bench, "angry")
	key("hero", _sr(8.2), GRAB_B, y_b)
	key("hero", _sr(8.45), GRAB_B, y_r)
	move("hero", _sr(8.4), "jog", {"fade": 0.12})
	key("hero", _sr(9.12), P_RAM, CineTimeline.face(P_RAM, P_RAM + Vector3.RIGHT), {"mode": "out"})
	strike("hero", "H3", "shove", {"reach": {"mixamo": 0.0, "ual": 0.0, "native": 0.0, "code": 0.0}})
	move("hero", _sr(10.0), "idle", {"fade": 0.25})   # guard down after the ram: Dolly's sucker punch
	look("hero", _sr(10.2), _sr(13.7), "dolly")
	# 11.51 Dolly's straight right on the jaw; 13.01 ducks her frisbee
	var y_d: float = CineTimeline.face(P_BACK, D_A)
	key("hero", _sr(10.2), P_RAM, CineTimeline.face(P_RAM, P_RAM + Vector3.RIGHT))
	key("hero", _sr(10.6), P_BACK, CineTimeline.face(P_RAM, P_RAM + Vector3.RIGHT))
	key("hero", _sr(10.95), P_BACK, y_d)
	strike("hero", x4, "hit_head")
	expr("hero", x4, "pain")
	move("hero", x4 + 0.5, "fight_idle", {"fade": 0.15})
	strike("hero", "A1", "dodge")
	expr("hero", _sr(12.8), "angry")
	# round the blind C1 to the tables; 17.10 the hip throw
	var y_w: float = CineTimeline.face(P_BACK, W1)
	var y_t: float = CineTimeline.face(W1, H_T)
	var y_f: float = CineTimeline.face(H_T, C1_F)
	key("hero", _sr(13.75), P_BACK, y_d)
	key("hero", _sr(14.05), P_BACK, y_w)
	move("hero", _sr(14.05), "walk", {"fade": 0.15})
	key("hero", _sr(14.75), W1, y_t, {"mode": "linear"})
	key("hero", _sr(15.6), H_T, y_t, {"mode": "out"})
	move("hero", _sr(15.5), "fight_idle", {"fade": 0.15})
	key("hero", _sr(16.1), H_T, y_f)
	look("hero", _sr(15.6), sc + 0.3, "c1")
	strike("hero", "H5", "hip_throw", {"dur": 0.6, "reach": {"mixamo": 0.17, "ual": 0.12, "native": 0.1, "code": 0.1}})
	expr("hero", h5 - 0.1, "angry")
	move("hero", h5 + 0.62, "fight_idle", {"fade": 0.3})
	key("hero", sc + 0.1, H_T, y_f)
	key("hero", _sr(22.4), H_T, CineTimeline.face(H_T, FLOOR))
	move("hero", _sr(22.2), "winded", {"fade": 0.35})
	expr("hero", sc, "happy")
	expr("hero", _sr(22.4), "done")


func _c1() -> void:
	var y0: float = CineTimeline.face(C1_0, P0)
	var y_a: float = CineTimeline.face(C1_A, P0)
	key("c1", 0.0, C1_0, y0)
	move("c1", 0.0, "fight_idle")
	key("c1", _sr(1.2), C1_0, y0)
	move("c1", _sr(1.2), "walk", {"fade": 0.2})
	key("c1", h1, C1_A, y_a, {"mode": "out"})
	strike("c1", "H1", "hit_head")
	# the rice bowl stuck upside down on the mask's face; he staggers back and wipes, blind
	hold("c1", h1 + 0.03, story_end, "rice_bowl", {"bone": "Head", "offset": Vector3(0.0, 0.12, -0.15), "rot": Vector3(-100.0, 0.0, 0.0)})
	var y_c: float = CineTimeline.face(C1_C, P_RAM)
	key("c1", _sr(3.35), C1_C, y_a, {"mode": "out"})
	move("c1", _sr(3.2), "facepalm", {"fade": 0.15})
	key("c1", _sr(5.0), C1_C, y_c)
	move("c1", _sr(5.05), "stunned", {"fade": 0.2})
	# 13.49 Dolly's frisbee clangs off his mask; turns blind, charges at the voice, 17.10 the hip throw
	strike("c1", tf, "hit_head")
	var y_f: float = CineTimeline.face(C1_F, H_T)
	key("c1", tf, C1_C, y_c)
	key("c1", _sr(14.4), C1_C, y_c + 140.0)
	move("c1", _sr(14.3), "stunned", {"fade": 0.15})
	key("c1", _sr(14.85), C1_C, CineTimeline.face(C1_C, C1_F))
	move("c1", _sr(14.85), "jog", {"fade": 0.15})
	key("c1", _sr(16.3), C1_F, CineTimeline.face(C1_C, C1_F), {"mode": "out"})
	move("c1", _sr(16.25), "stunned", {"fade": 0.12})
	key("c1", _sr(16.7), C1_F, y_f)
	strike("c1", "H5", "thrown", {"dur": 0.45})
	key("c1", h5, C1_F, y_f)
	# over the hip and flat onto the first table (keys: the forward flip), the slide down the row, off the end
	var y_s: float = CineTimeline.face(C1_F, LAND)
	key("c1", h5 + 0.32, LAND, y_s, {"mode": "linear", "arc": 0.9, "spin": Vector3(-360.0, 0.0, 0.0)})
	move("c1", h5 + 0.4, "lie_flat", {"fade": 0.12})
	key("c1", h5 + 0.65, SLIDE_END, y_s, {"mode": "linear", "spin": Vector3(-360.0, 0.0, 0.0)})
	key("c1", sc, CRASH, y_s, {"mode": "linear", "spin": Vector3(-360.0, 0.0, 0.0)})
	key("c1", sc + 0.1, TIP, y_s, {"mode": "linear", "spin": Vector3(-385.0, 0.0, 0.0)})
	key("c1", _sr(21.5), FLOOR, y_s, {"mode": "in", "arc": 0.2, "spin": Vector3(-360.0, 0.0, 0.0)})
	fx_at(h5 + 1.0, "stars", "c1", {"until": story_end})


func _c2() -> void:
	var y0: float = CineTimeline.face(C2_0, P0)
	var y_a: float = CineTimeline.face(C2_A, P0)
	key("c2", 0.0, C2_0, y0)
	move("c2", 0.0, "fight_idle")
	key("c2", _sr(2.9), C2_0, y0)
	move("c2", _sr(2.9), "jog", {"fade": 0.15})
	key("c2", _sr(3.55), C2_A, y_a, {"mode": "out"})
	move("c2", _sr(3.5), "fight_idle", {"fade": 0.1})
	strike("c2", x1, "jab", {"reach": {"mixamo": 0.12, "ual": 0.15, "native": 0.1, "code": 0.14}})
	strike("c2", x2, "jab", {"reach": {"mixamo": 0.12, "ual": 0.15, "native": 0.1, "code": 0.14}})
	strike("c2", x3, "cross", {"reach": {"mixamo": Vector2(-0.2, 0.04), "ual": 0.08, "native": 0.08, "code": 0.08}})
	move("c2", x3 + 0.2, "fight_idle", {"fade": 0.12})
	# 6.21 the tray edge into the mask; reels back to the counter
	strike("c2", "H2", "hit_head")
	var y_b: float = CineTimeline.face(C2_B, P_RAM)
	key("c2", h2, C2_A, y_a)
	key("c2", _sr(7.6), C2_B, y_b, {"mode": "out"})
	move("c2", _sr(7.4), "stunned", {"fade": 0.15})
	fx_at(_sr(7.4), "stars", "c2", {"until": _sr(9.3)})
	# 9.39 the bench pins him to the counter, he slides down to sit
	strike("c2", "H3", "slammed")
	key("c2", h3, C2_B, y_b)
	key("c2", slam_s, C2_B + Vector3(0.08, 0.0, 0.0), y_b, {"mode": "out"})
	key("c2", h3 - 0.04 + 0.8, C2_SIT, y_b)
	move("c2", h3 - 0.04 + 0.8, "slumped", {"fade": 0.15})
	fx_at(slam_s + 0.1, "stars", "c2", {"until": story_end})


func _c3() -> void:
	var y_run: float = CineTimeline.face(C3_0, C3_W)
	var y_a: float = CineTimeline.face(C3_A, P_RAM)
	key("c3", 0.0, C3_0, CineTimeline.face(C3_0, P0))
	move("c3", 0.0, "fight_idle")
	key("c3", _sr(6.6), C3_0, y_run)
	move("c3", _sr(6.6), "jog", {"fade": 0.15})
	key("c3", _sr(7.6), C3_W, y_run, {"mode": "out"})
	move("c3", _sr(7.55), "fight_idle", {"fade": 0.12})
	key("c3", _sr(7.9), C3_W, y_a)
	key("c3", _sr(8.95), C3_W, y_a)
	move("c3", _sr(8.9), "block_high", {"fade": 0.12})   # arms up at the bench, backing into the counter
	key("c3", _sr(9.3), C3_A, y_a, {"mode": "out"})
	strike("c3", "H3", "slammed")
	key("c3", h3, C3_A, y_a)
	key("c3", slam_s, C3_A + Vector3(0.08, 0.0, 0.0), y_a, {"mode": "out"})
	key("c3", h3 - 0.04 + 0.8, C3_SIT, y_a)
	move("c3", h3 - 0.04 + 0.8, "slumped", {"fade": 0.15})
	fx_at(slam_s + 0.1, "stars", "c3", {"until": story_end})


func _dolly() -> void:
	var y0: float = CineTimeline.face(D_0, P0)
	key("dolly", 0.0, D_0, y0)
	move("dolly", 0.0, "point")
	move("dolly", _sr(1.5), "fight_idle", {"fade": 0.25})
	look("dolly", 0.0, story_end, "hero")
	# 9.7 to the counter end for a tray, 11.51 the straight right, 12.62 the frisbee
	var y_t: float = CineTimeline.face(D_T, TRAY_C)
	key("dolly", _sr(9.6), D_0, CineTimeline.face(D_0, D_T))
	move("dolly", _sr(9.6), "walk", {"fade": 0.2})
	key("dolly", _sr(10.1), D_T, y_t, {"mode": "out"})
	move("dolly", _sr(10.05), "fight_idle", {"fade": 0.1})
	strike("dolly", s_tray, "shove", {"dur": 0.5})
	hold("dolly", s_tray, _sr(11.95), "tray", {"bone": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.12), "rot": Vector3(0.0, 0.0, -90.0)})
	hold("dolly", _sr(11.95), s_throw, "tray", {"offset": Vector3(0.0, 0.0, -0.14), "rot": Vector3(0.0, 0.0, 90.0)})
	var y_a: float = CineTimeline.face(D_A, P_BACK)
	key("dolly", _sr(10.5), D_T, CineTimeline.face(D_T, D_A))
	move("dolly", _sr(10.5), "walk", {"fade": 0.15})
	key("dolly", _sr(11.15), D_A, y_a, {"mode": "out"})
	move("dolly", _sr(11.1), "fight_idle", {"fade": 0.1})
	strike("dolly", x4, "cross", {"reach": {"mixamo": Vector2(-0.1, 0.06), "ual": 0.08, "native": 0.05, "code": 0.05}})
	move("dolly", x4 + 0.25, "fight_idle", {"fade": 0.15})
	key("dolly", x4 + 0.05, D_A, y_a)
	key("dolly", _sr(12.25), D_B, y_a, {"mode": "out"})
	strike("dolly", s_throw, "cross", {"reach": -0.3})
	move("dolly", _sr(13.2), "fight_idle", {"fade": 0.15})
	# the hip throw: she backs off, then bolts for the side door and is gone
	var y_ex: float = CineTimeline.face(D_B, EXIT)
	key("dolly", h5 + 0.2, D_B, y_a)
	key("dolly", h5 + 0.45, D_B, y_ex)
	move("dolly", h5 + 0.45, "sprint", {"fade": 0.2})
	key("dolly", s_gone, EXIT, y_ex, {"mode": "linear"})
	show("dolly", s_gone, false)


func _shots() -> void:
	shot("K1", 0.0, "crane", "crane down over the lunch tables onto the standoff: a tray, three masked clones, Dolly",
		{"from": Vector3(-4.6, 4.6, 5.2), "to": Vector3(-3.4, 2.1, 4.4), "look_from": Vector3(0.0, 0.4, -0.4),
		"look_to": Vector3(0.2, 1.1, -0.4), "fov": 50.0, "hand": 0.2})
	dutch_shot("D1", _sr(1.55), "dolly", {"roll": 14.0, "side_deg": 20.0, "dist": 2.6, "fov": 44.0})
	shot("O1", _sr(2.15), "orbit", "slow-motion orbit: the full tray up into C1's mask (2.44), lunch everywhere",
		{"center": (P0 + C1_A) * 0.5 + Vector3(0.0, 1.35, 0.0), "radius": 1.9, "deg_from": 120.0, "deg_to": 150.0, "height": 1.3,
		"fov": 42.0, "hand": 0.3})
	ots_shot("T1", _sr(3.45), "c2", "hero", {"side": -1.0, "fov": 44.0, "look_y": 1.15, "back": 1.4})
	two_shot("T2", _sr(5.6), "hero", "c2", {"side": 1.0, "fov": 44.0, "look_y": 1.15, "height": 1.35, "push": 0.1})
	hero_shot("L1", _sr(7.35), "hero", {"side_deg": 35.0, "dist": 2.3, "fov": 52.0})
	shot("S1", _sr(8.85), "static", "slow motion, side-on and low: the bench ram pins C2 and C3 to the counter (9.39)",
		{"pos": Vector3(0.55, 0.85, -3.3), "look": Vector3(1.45, 0.95, -0.05), "fov": 50.0, "hand": 0.4})
	push_in("P1", _sr(10.45), "dolly", {"from": 4.0, "to": 2.6, "side_deg": -25.0, "fov": 42.0})
	ots_shot("T3", _sr(11.15), "dolly", "hero", {"side": 1.0, "fov": 40.0})
	shot("S2", _sr(12.5), "static", "slow motion, low behind C1: the frisbee over the ducking protagonist, onto C1's mask",
		{"pos": C1_C + Vector3(-0.9, 0.9, 1.5), "look": (P_RAM + C1_C) * 0.5 + Vector3(0.0, 1.35, 0.0), "fov": 48.0, "hand": 0.5})
	two_shot("T4", _sr(14.2), "hero", "c1", {"side": -1.0, "fov": 46.0, "look_y": 1.12, "height": 1.35})
	shot("O2", _sr(16.6), "orbit", "low slow orbit: the hip throw (17.10)",
		{"center": (H_T + C1_F) * 0.5 + Vector3(0.0, 1.1, 0.0), "radius": 3.0, "deg_from": 150.0, "deg_to": 200.0, "height": 0.8,
		"fov": 46.0, "hand": 0.3})
	shot("K2", _sr(18.4), "dolly", "tracking along the lunch tables: C1 slides the whole row, trays flying",
		{"from": Vector3(-1.4, 1.25, 0.6), "to": Vector3(-3.8, 1.2, 0.6), "look_from": LAND + Vector3(-0.3, 0.1, 0.0),
		"look_to": SLIDE_END + Vector3(-0.6, 0.0, 0.0), "fov": 44.0, "hand": 0.3})
	shot("S3", _sr(19.95), "static", "slow motion at the end of the row: off the table into the stacked chairs (20.30)",
		{"pos": CHAIRS + Vector3(2.2, 1.1, -2.4), "look": CHAIRS + Vector3(0.6, 0.6, 0.0), "fov": 50.0, "hand": 0.4})
	dutch_shot("D2", _sr(20.75), "dolly", {"roll": -13.0, "side_deg": 160.0, "dist": 3.0, "fov": 46.0})
	shot("W2", s_gone, "dolly", "tail wide: the wreck of the canteen, C1 in the chairs, C2 and C3 at the counter",
		{"from": Vector3(1.6, 2.2, 4.6), "to": Vector3(1.2, 2.0, 4.2), "look_from": Vector3(-1.4, 0.5, 1.0),
		"look_to": Vector3(-1.2, 0.5, 1.0), "fov": 56.0, "hand": 0.4})
	push_in("P2", _sr(23.0), "hero", {"from": 4.0, "to": 3.0, "side_deg": 30.0, "fov": 44.0, "look_y": 1.1, "height": 1.35})
	for xr: float in [R_X1, R_X2, R_X3]:
		punch(_sr(xr), "light")
	punch(x4, "medium")


func _fx_sfx() -> void:
	sfx_at("H1", "tray_clang", -3.0)
	sfx_at("H1", "impact_medium", -4.0)
	fx_at("H1", "dust", "c1:Head", {"power": 0.9})
	fx_at("H1", "debris", "c1:Head", {"power": 0.6, "dir": DIR1 + Vector3(0.0, 0.9, 0.0)})
	for xr: float in [R_X1, R_X2, R_X3]:
		sfx_at(_sr(xr), "tray_clang", -2.0 if xr < R_X3 else 0.0)
		fx_at(_sr(xr), "sparks", "hero:Head", {"power": 0.3})
	sfx_at("H2", "tray_clang", 0.0)
	sfx_at("H2", "impact_heavy", -6.0)
	fx_at("H2", "sparks", "c2:Head", {"power": 0.7})
	sfx_at(s_bench, "whoosh_down", -6.0)
	sfx_at(_sr(10.75), "body_fall", -5.0)   # the tossed bench lands behind him
	sfx_at("H3", "impact_heavy", -1.0)
	sfx_at(slam_s, "body_fall", -3.0)
	fx_at("H3", "dust", "c3:Chest", {"power": 0.8})
	fx_at("H3", "dust", "c2:Chest", {"power": 0.8})
	fx_at(slam_s, "flash", "counter", {"power": 0.5})
	sfx_at(x4, "impact_medium", -2.0)
	fx_at(x4, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(s_throw, "whoosh_down", -4.0)
	sfx_at("A1", "whoosh_down", -6.0)
	sfx_at(tf, "tray_clang", -1.0)
	fx_at(tf, "sparks", "c1:Head", {"power": 0.5})
	fx_at("H5", "dust", "hero:Foot.L", {"power": 0.6})
	sfx_at("H5", "impact_heavy", -3.0)
	sfx_at(h5 + 0.32, "body_fall", -2.0)
	sfx_at(h5 + 0.34, "slide_whistle", -4.0)
	fx_at(h5 + 0.33, "dust", "table_0", {"power": 0.7})
	for j: int in 2:
		sfx_at(h5 + [0.4, 0.55][j], "tray_clang", -5.0)
		fx_at(h5 + [0.4, 0.55][j], "debris", "lunch_%d" % j, {"power": 0.5, "dir": Vector3(-0.4, 0.9, 0.5)})
	fx_at(sc, "crate", "chairs_a", {"power": 1.0, "dir": Vector3(-1.0, 0.5, 0.0)})
	fx_at(sc, "crate", "chairs_b", {"power": 1.1, "dir": Vector3(-0.8, 0.8, 0.2)})
	fx_at(sc, "flash", "chairs_a", {"power": 0.8})
	fx_at(sc, "dust", "c1:Hips", {"power": 1.0})
	sfx_at(sc, "chair_smash", 0.0)
	sfx_at(sc, "crate_smash", -6.0)
	sfx_at(_sr(21.5), "body_fall", -2.0)
	sfx_at(_sr(22.3), "groan", -5.0)


func _subs() -> void:
	sub(0.3, 1.5, "hero", "Từ từ... nói chuyện đã.")
	sub(1.95, 0.6, "dolly", "Lên!")
	sub(21.75, 0.9, "dolly", "Bai bai!")
	sub(23.3, 1.0, "hero", "...Lại chạy.")
