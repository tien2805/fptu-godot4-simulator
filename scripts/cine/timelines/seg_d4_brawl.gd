# File: res://scripts/cine/timelines/seg_d4_brawl.gd
# seg_d4_brawl (22.350 s, spec B-D7 beat 6 / B-D10; reworked by plan 2026-11-05-w6-fights and its review round: its own
# choreography, cameras and signature moves, every hit on an accent of the owner's cut of "Ain't That a Kick in the Head",
# see the music note below). Closing time in the canteen: the protagonist, a lunch tray in hand, against three sheep-masked
# clones and Cừu Dolly (masked, cream cardigan), with nothing but the canteen's own things: food, trays, a bench, the
# lunch tables.
#   0.0  insert on the full lunch tray in his hands, then the crane down onto the standoff: "Từ từ... nói chuyện đã.";
#        Dolly sends them in ("Lên!")
#   2.44 H1  the full tray shoved up into C1's mask: lunch everywhere, rice and curry plugged in the mask's eye holes; he
#            wipes at it, blind
#   3.80 / 5.24  the tray shield: C2's jab and cross clang off the tray held up like a shield (normal speed)
#   6.21 H2  the tray, edge first, straight into C2's mask (slow motion, clang): he reels back to the serving counter
#   9.39 H3  the bench ram: the canteen bench carried at a run pins C2 and C3 against the counter (slow motion, heavy);
#            he tosses it over his shoulder (10.75)
#  11.09     bends for his dropped tray ... 11.51 ... and comes up into Dolly's sucker punch (normal speed, punch-in)
#  12.61     Dolly flings the counter's tray like a frisbee; 13.01 A1 (slow motion) he bats it straight back with his own
#            tray, 13.49 it clangs off her own mask; the clang sets the blind C1 charging at the noise
#  14.85 H5  finisher: the hip throw sends the charging C1 onto the lunch tables, he slides the whole row in slow motion
#            (trays flying), feet first into the stacked chairs (17.10) and off the end to the floor; Dolly bolts for the
#            side exit
#  19.35-22.35 tail at 1x: "Bai bai!" from the door, the protagonist winded among the wreckage ("...Lại chạy.")
# Music: the owner's "Ain't That a Kick in the Head" re-cut from 89.38 s of the original (+1.5 dB, W6); every hit sits
# on an accent of it within 0.1 s, the crash into the chairs on the cut's strongest (17.10). No gore: the food is lunch,
# knockouts, stars, groans. Contacts are measured on every tier by tests/test_cine_d4_brawl.gd (tests/support/cine_brawl.gd).
# Stage: CineTimeline.canteen_stage (the canteen's courtyard side), 14 x 10 m box (|x| <= 7, |z| <= 5): the serving
# counter on the right, the row of lunch tables at the left, a bench at the front left.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LENGTH: float = 22.35
const TAIL: float = 3.0
## Real times of the beats (accents of the music cut).
const R_H1: float = 2.44
const R_X1: float = 3.80
const R_X2: float = 5.24
const R_H2: float = 6.21
const R_H3: float = 9.39
const R_TOSS: float = 10.75
const R_PICK: float = 11.09
const R_X4: float = 11.51
const R_THROW: float = 12.61
const R_A1: float = 13.01
const R_TF: float = 13.49
const R_H5: float = 14.85
const R_CRASH: float = 17.10
const SWELL_END: float = 19.35

# props
const COUNTER := Vector3(2.55, 0.0, 0.2)         # yaw 90: its customer face looks -X, at x = 2.55 - 0.325
const COUNTER_FACE_X: float = 2.225
const TRAY_C := Vector3(2.45, 0.962, -1.15)      # a tray on the counter (Dolly's frisbee)
const BENCH := Vector3(-1.2, 0.0, -1.4)          # yaw 180: the backrest away from the protagonist's side
const TABLE_TOP: float = 0.75
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
const C1_0 := Vector3(1.2, 0.0, 2.3)
const C2_0 := Vector3(1.8, 0.0, -2.4)
const C3_0 := Vector3(1.4, 0.0, 3.4)
const D_0 := Vector3(0.3, 0.0, -3.6)
const DIR1 := Vector3(0.6, 0.0, 0.8)            # from the protagonist toward C1
const DIR2 := Vector3(0.8, 0.0, -0.6)           # toward C2
const DIR_D := Vector3(0.2, 0.0, -0.98)         # toward Dolly at the counter end
const DIR_T := Vector3(0.633, 0.0, 0.774)       # the hip throw: from the protagonist toward C1 (seg_d1_brawl's)
const H_T := Vector3(0.3, 0.0, 0.3)             # the protagonist at the hip throw, a step off where Dolly found him

var TABLES: Array[Vector3] = []
var CHAIRS: Vector3
var C1_A: Vector3   # C1 steps onto the tray
var C1_C: Vector3   # where the blind C1 wipes his mask
var C1_W: Vector3   # where he has wandered, blind, when the clang sets him charging
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
var P_BACK: Vector3   # one step back off the pinned pair, where he finds his tray (and Dolly finds him)
var D_T: Vector3    # Dolly at the counter end, taking a tray
var D_A: Vector3
var D_B: Vector3
var T_FLOOR: Vector3   # his tray on the floor, under his hand at the pickup

# story times
var h1: float
var h2: float
var h3: float
var a1: float
var h5: float
var x1: float
var x2: float
var x4: float
var tf: float       # the batted frisbee on Dolly's mask
var s_bench: float  # bench pickup
var s_tray: float   # Dolly takes the counter tray
var s_pick: float   # the protagonist picks his own tray back up
var s_throw: float  # Dolly lets go of hers
var s_drop: float   # he lets go of his after the bat
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
	x4 = _sr(R_X4)
	tf = _sr(R_TF)
	s_bench = _sr(7.95)
	s_tray = _sr(10.3)
	s_pick = _sr(R_PICK)
	s_throw = _sr(R_THROW)
	s_drop = _sr(13.6)
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
	hit("H1", 2.2, "medium", "the full lunch tray shoved up into C1's mask: food everywhere, the eye holes plugged", {"r": R_H1, "att": "hero:tray", "tgt": "c1:upper"})
	hit("H2", 5.0, "heavy", "the tray, edge first, straight into C2's mask: clang", {"r": R_H2, "att": "hero:tray", "tgt": "c2:Head"})
	hit("H3", 7.8, "heavy", "the bench ram: C2 and C3 pinned against the serving counter", {"r": R_H3, "att": "hero:bench", "tgt": "c3:torso"})
	hit("A1", 10.6, "accent", "slow-motion accent: Dolly's tray frisbee batted straight back with his own tray", {"r": R_A1})
	hit("H5", 12.0, "finisher", "the hip throw: the charging C1 slides the length of the lunch tables into the chairs (swell)",
		{"r": R_H5, "hq": SWELL_END - R_H5 - 0.55, "att": "hero:hands", "tgt": "c1:upper"})


func _layout() -> void:
	C1_A = P0 + DIR1 * D_H1
	C1_C = C1_A + DIR1 * 0.4
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
	T_FLOOR = P_BACK + DIR_D * 0.33 + Vector3(0.98, 0.0, 0.2) * 0.2 + Vector3(0.0, 0.012, 0.0)   # under his right hand
	# the hip throw (seg_d1_brawl's, turned so he travels -X along the tables): C1 charges in along DIR_T, his hips land on
	# the first table's near end; the row of tables is laid out from there
	C1_F = H_T + DIR_T * D_HT
	C1_W = C1_F + DIR_T * 1.45
	LAND = Vector3(C1_F.x - 1.84, TABLE_TOP + 0.05, C1_F.z)
	TABLES = [Vector3(LAND.x + 0.25, 0.0, LAND.z), Vector3(LAND.x - 1.15, 0.0, LAND.z), Vector3(LAND.x - 2.55, 0.0, LAND.z)]
	CHAIRS = Vector3(TABLES[2].x - 1.45, 0.0, LAND.z)
	SLIDE_END = Vector3(TABLES[2].x - 0.7 + 0.9, LAND.y, LAND.z)
	CRASH = Vector3(TABLES[2].x - 0.28, LAND.y, LAND.z)
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
	var trays: Array = [[Vector3(TABLES[0].x - 1.05, TABLE_TOP + 0.006, LAND.z - 0.05), 0.308],
		[Vector3(TABLES[0].x - 2.4, TABLE_TOP + 0.006, LAND.z + 0.1), 0.423]]
	for j: int in trays.size():
		var at: Vector3 = trays[j][0]
		var s_hit: float = h5 + float(trays[j][1])
		prop("lunch_%d" % j, "tray", at, 0.0, {"food": true, "arc": 0.5,
			"path": [[s_hit, at, Vector3.ZERO], [s_hit + 0.35, Vector3(at.x - 0.7, 0.012, LAND.z + 1.05 + 0.3 * j), Vector3(0.0, 160.0, 180.0)]]})
	prop("chairs_a", "chair", CHAIRS, 90.0, {"color": Color("#2E86C1")})
	prop("chairs_b", "chair", CHAIRS + Vector3(0.0, 0.47, 0.0), 90.0, {"color": Color("#E67E22")})
	# set dressing round the fight (drop_set)
	prop("table_d", "table", Vector3(-4.6, 0.0, -1.7), 90.0, {"set": true})
	prop("table_e", "table", Vector3(-3.0, 0.0, -3.6), 0.0, {"set": true})
	prop("stool_a", "stool", Vector3(-4.0, 0.0, -1.0), 0.0, {"set": true})
	prop("stool_b", "stool", Vector3(-2.3, 0.0, -3.0), 0.0, {"set": true, "color": Color("#2E86C1")})
	# the protagonist's tray, let go after H2 to grab the bench: it skids to where he picks it back up (11.09)
	var t_hand: Vector3 = P1 + Vector3(0.3, 1.05, -0.3)
	var y_fl: float = CineTimeline.face(P_BACK, D_A)
	prop("tray_drop", "tray", T_FLOOR, y_fl, {"show_at": _sr(6.9), "hide_at": s_pick, "arc": 0.25,
		"path": [[_sr(6.9), t_hand, Vector3(0.0, 0.0, 90.0)], [_sr(7.25), T_FLOOR, Vector3(0.0, y_fl, 0.0)]]})
	# the bench, let go after the ram, tossed over his shoulder: it lands behind him, clear of Dolly's way in
	var b_floor: Vector3 = P_RAM + Vector3(-1.0, 0.0, -0.95)
	prop("bench_drop", "bench", b_floor, 270.0, {"show_at": _sr(9.9), "arc": 1.6,
		"path": [[_sr(9.9), P_RAM + Vector3(0.55, 0.62, 0.0), Vector3(0.0, 90.0, 0.0)], [_sr(R_TOSS), b_floor, Vector3(0.0, 270.0, -8.0)]]})
	# Dolly's frisbee: out of her hand (12.61), batted back off his tray (13.01), off her own mask (13.49), to the floor
	var f0: Vector3 = D_B - DIR_D * 0.55 + Vector3(0.0, 1.45, 0.0)
	var f1: Vector3 = P_BACK + DIR_D * 0.62 + Vector3(0.0, 1.5, 0.0)
	var f2: Vector3 = D_B - DIR_D * 0.25 + Vector3(0.03, 1.5, 0.0)
	var f3: Vector3 = D_B - DIR_D * 0.75 + Vector3(-0.35, 0.012, 0.0)
	prop("tray_fly", "tray", f3, 0.0, {"show_at": s_throw,
		"path": [[s_throw, f0, Vector3(0.0, 0.0, 0.0)], [a1, f1, Vector3(0.0, 540.0, 0.0)], [tf, f2, Vector3(15.0, 900.0, 0.0)],
			[_sr(14.3), f3, Vector3(0.0, 1080.0, 0.0)]]})
	# his own tray, let go after the bat: it drops at his feet
	var g0: Vector3 = P_BACK + DIR_D * 0.46 + Vector3(0.0, 1.32, 0.0)
	var g1: Vector3 = P_BACK + DIR_D * 0.35 + Vector3(0.3, 0.012, 0.05)
	prop("tray_toss", "tray", g1, 20.0, {"show_at": s_drop, "arc": 0.1,
		"path": [[s_drop, g0, Vector3(90.0, y_fl, 0.0)], [_sr(13.95), g1, Vector3(0.0, 20.0, 0.0)]]})


## Story times around the ramps are compressed, so every key and cue here is anchored on a REAL time through _sr().
func _hero() -> void:
	var y1: float = CineTimeline.face(P0, C1_A)
	var y2: float = CineTimeline.face(P0, C2_A)
	var shield: Dictionary = {"mid": "Wrist.L", "offset": Vector3(0.0, -0.12, -0.1), "rot": Vector3(90.0, 0.0, 0.0)}
	var one_hand: Dictionary = {"offset": Vector3(0.0, 0.0, -0.14), "rot": Vector3(0.0, 0.0, 90.0)}
	# 0-2.44 the standoff with a full tray, then shoves it up into C1's mask
	key("hero", 0.0, P0, y1)
	move("hero", 0.0, "tray_hold")
	hold("hero", 0.0, h1 + 0.03, "tray", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.12), "food": true})
	expr("hero", 0.0, "open")
	expr("hero", _sr(1.6), "angry")
	strike("hero", "H1", "shove", {"reach": {"mixamo": 0.0, "ual": 0.06, "native": 0.06, "code": 0.06}})
	look("hero", 0.0, _sr(3.2), "c1")
	# 3.45-5.45 the tray shield against C2's jab and cross
	hold("hero", h1 + 0.03, _sr(5.45), "tray", shield)
	key("hero", _sr(3.05), P0, y1)
	key("hero", _sr(3.45), P0, y2)
	move("hero", _sr(3.2), "tray_guard", {"fade": 0.15})
	look("hero", _sr(3.3), _sr(7.0), "c2")
	for xr: float in [R_X1, R_X2]:
		expr("hero", _sr(xr), "pain")
	expr("hero", _sr(5.45), "angry")
	# 6.21 the tray edge first into C2's mask (a straight right), then lets it go
	hold("hero", _sr(5.45), _sr(6.9), "tray", one_hand)
	move("hero", _sr(5.4), "fight_idle", {"fade": 0.12})
	key("hero", _sr(5.4), P0, y2)
	key("hero", _sr(5.7), P1, y2, {"mode": "out"})   # a step back to swing
	strike("hero", "H2", "cross", {"dur": 0.5, "reach": {"mixamo": -0.1, "ual": 0.15, "native": 0.15, "code": 0.15}})
	move("hero", _sr(7.0), "fight_idle", {"fade": 0.15})
	# 7.95 snatches up the bench, 9.39 rams C2 and C3 into the counter with it
	var y_b: float = CineTimeline.face(GRAB_B, BENCH)
	var y_r: float = CineTimeline.face(GRAB_B, P_RAM)
	var y_x: float = CineTimeline.face(P_RAM, P_RAM + Vector3.RIGHT)
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
	key("hero", _sr(9.12), P_RAM, y_x, {"mode": "out"})
	strike("hero", "H3", "shove", {"reach": {"mixamo": 0.0, "ual": 0.0, "native": 0.0, "code": 0.0}})
	move("hero", _sr(10.0), "idle", {"fade": 0.25})   # guard down after the ram
	look("hero", _sr(10.2), _sr(13.6), "dolly")
	# 11.09 bends for his tray, 11.51 comes up into Dolly's straight right on the jaw
	var y_d: float = CineTimeline.face(P_BACK, D_A)
	key("hero", _sr(10.2), P_RAM, y_x)
	key("hero", _sr(10.5), P_BACK, y_x)
	key("hero", _sr(10.8), P_BACK, y_d)
	strike("hero", s_pick, "pickup")
	hold("hero", s_pick, _sr(12.3), "tray", one_hand)
	strike("hero", x4, "hit_head")
	expr("hero", x4, "pain")
	move("hero", x4 + 0.5, "fight_idle", {"fade": 0.15})
	# 12.3 the tray up two-handed as she winds up; 13.01 bats her frisbee straight back
	hold("hero", _sr(12.3), s_drop, "tray", shield)
	move("hero", _sr(12.3), "tray_guard", {"fade": 0.15})
	strike("hero", "A1", "shove_high")
	expr("hero", _sr(12.3), "angry")
	# 13.6 lets the tray drop, turns into the charging C1; 14.85 the hip throw
	var y_f: float = CineTimeline.face(H_T, C1_F)
	key("hero", s_drop, P_BACK, y_d)
	move("hero", s_drop, "fight_idle", {"fade": 0.12})
	key("hero", _sr(14.1), H_T, y_f)
	look("hero", s_drop, sc + 0.3, "c1")
	strike("hero", "H5", "hip_throw", {"dur": 0.6, "reach": {"mixamo": 0.17, "ual": 0.12, "native": 0.1, "code": 0.1}})
	expr("hero", h5 - 0.1, "angry")
	move("hero", h5 + 0.62, "fight_idle", {"fade": 0.3})
	key("hero", sc + 0.1, H_T, y_f)
	key("hero", _sr(19.95), H_T, CineTimeline.face(H_T, FLOOR))
	move("hero", _sr(19.75), "winded", {"fade": 0.35})
	expr("hero", sc, "happy")
	expr("hero", _sr(19.95), "done")


func _c1() -> void:
	var y0: float = CineTimeline.face(C1_0, P0)
	var y_a: float = CineTimeline.face(C1_A, P0)
	key("c1", 0.0, C1_0, y0)
	move("c1", 0.0, "fight_idle")
	key("c1", _sr(1.2), C1_0, y0)
	move("c1", _sr(1.2), "walk", {"fade": 0.2})
	key("c1", h1, C1_A, y_a, {"mode": "out"})
	strike("c1", "H1", "hit_head")
	# rice and curry plugged in the mask's eye holes: he staggers back and wipes, blind
	hold("c1", h1 + 0.03, story_end, "food_eyes", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
	var y_c: float = CineTimeline.face(C1_C, P_RAM)
	key("c1", _sr(3.35), C1_C, y_a, {"mode": "out"})
	move("c1", _sr(3.2), "facepalm", {"fade": 0.15})
	key("c1", _sr(5.0), C1_C, y_c)
	move("c1", _sr(5.05), "stunned", {"fade": 0.2})
	# 7.8 wanders off blind, away from the fight
	var y_w: float = CineTimeline.face(C1_C, C1_W)
	key("c1", _sr(7.8), C1_C, y_c)
	key("c1", _sr(8.2), C1_C, y_w)
	move("c1", _sr(8.1), "walk", {"fade": 0.2})
	key("c1", _sr(10.6), C1_W, y_w, {"mode": "out"})
	move("c1", _sr(10.5), "stunned", {"fade": 0.2})
	# 13.49 the clang: jumps, turns to the noise and charges; 14.85 the hip throw
	var y_f: float = CineTimeline.face(C1_F, H_T)
	move("c1", tf, "startled", {"fade": 0.08})
	key("c1", tf, C1_W, y_w)
	key("c1", _sr(13.65), C1_W, y_f)
	move("c1", _sr(13.65), "jog", {"fade": 0.12})
	key("c1", _sr(14.2), C1_F, y_f, {"mode": "out"})
	move("c1", _sr(14.15), "stunned", {"fade": 0.12})   # arms down: blind, he runs into the throw
	strike("c1", "H5", "thrown", {"dur": 0.45})
	key("c1", h5, C1_F, y_f)
	# over the hip and flat onto the first table (keys: the forward flip), the slide down the row, off the end
	var y_s: float = CineTimeline.face(C1_F, LAND)
	key("c1", h5 + 0.24, LAND, y_s, {"mode": "linear", "arc": 0.9, "spin": Vector3(-360.0, 0.0, 0.0)})
	move("c1", h5 + 0.3, "lie_flat", {"fade": 0.12})
	key("c1", h5 + 0.44, SLIDE_END, y_s, {"mode": "linear", "spin": Vector3(-360.0, 0.0, 0.0)})
	key("c1", sc, CRASH, y_s, {"mode": "linear", "spin": Vector3(-360.0, 0.0, 0.0)})
	key("c1", sc + 0.1, TIP, y_s, {"mode": "linear", "spin": Vector3(-385.0, 0.0, 0.0)})
	key("c1", _sr(18.3), FLOOR, y_s, {"mode": "in", "arc": 0.2, "spin": Vector3(-360.0, 0.0, 0.0)})
	fx_at(_sr(18.4), "stars", "c1", {"until": story_end})


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
	strike("c2", x2, "cross", {"reach": {"mixamo": Vector2(-0.2, 0.04), "ual": 0.08, "native": 0.08, "code": 0.08}})
	move("c2", x2 + 0.2, "fight_idle", {"fade": 0.12})
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
	look("dolly", 0.0, tf, "hero")
	# 9.7 to the counter end for a tray, 11.51 the straight right, 12.61 the frisbee
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
	move("dolly", _sr(12.9), "fight_idle", {"fade": 0.15})
	# 13.49 her own frisbee back on her mask: she reels, seeing stars; the hip throw: she bolts for the side door
	strike("dolly", tf, "hit_head")
	expr("dolly", tf, "pain")
	move("dolly", tf + 0.45, "stunned", {"fade": 0.15})
	var y_ex: float = CineTimeline.face(D_B, EXIT)
	key("dolly", h5 + 0.2, D_B, y_a)
	key("dolly", h5 + 0.45, D_B, y_ex)
	move("dolly", h5 + 0.45, "sprint", {"fade": 0.2})
	key("dolly", s_gone, EXIT, y_ex, {"mode": "linear"})
	show("dolly", s_gone, false)


func _shots() -> void:
	var fwd1: Vector3 = DIR1
	var lft1 := Vector3(fwd1.z, 0.0, -fwd1.x)
	var tray0: Vector3 = P0 + fwd1 * 0.32 + Vector3(0.0, 1.0, 0.0)
	shot("G1", 0.0, "static", "insert: the full lunch tray in his hands, rice, soup and chopsticks; behind it the clones close in",
		{"pos": tray0 + fwd1 * 0.75 + lft1 * 0.35 + Vector3(0.0, 0.25, 0.0), "look": tray0, "fov": 34.0, "hand": 0.15, "subj": []})
	shot("K1", _sr(0.9), "crane", "crane down over the lunch tables onto the standoff: a tray, three masked clones, Dolly",
		{"from": Vector3(-3.6, 4.4, 3.6), "to": Vector3(-2.6, 2.1, 3.0), "look_from": Vector3(0.3, 0.4, -0.6),
		"look_to": Vector3(0.4, 1.1, -0.5), "fov": 50.0, "hand": 0.2, "subj": ["hero"]})
	shot("O1", _sr(2.15), "orbit", "slow-motion orbit: the full tray up into C1's mask (2.44), lunch in his eye holes",
		{"center": (P0 + C1_A) * 0.5 + Vector3(0.0, 1.35, 0.0), "radius": 1.9, "deg_from": 300.0, "deg_to": 325.0, "height": 1.3,
		"fov": 42.0, "hand": 0.3, "subj": ["hero", "c1"]})
	ots_shot("T1", _sr(3.45), "c2", "hero", {"side": -1.0, "fov": 44.0, "look_y": 1.15, "back": 1.4, "subj": ["hero"]})
	two_shot("T2", _sr(5.6), "hero", "c2", {"side": 1.0, "fov": 44.0, "look_y": 1.15, "height": 1.35, "push": 0.1, "subj": ["hero", "c2"]})
	hero_shot("L1", _sr(7.35), "hero", {"side_deg": -80.0, "dist": 2.3, "fov": 52.0, "subj": ["hero"]})
	shot("S1", _sr(8.4), "static", "slow motion, low and wide: the bench carried at a run, pinning C2 and C3 to the counter (9.39)",
		{"pos": Vector3(-0.4, 0.85, -3.1), "look": Vector3(0.2, 0.95, -0.25), "fov": 50.0, "hand": 0.4, "subj": ["hero", "c3"]})
	ots_shot("T3", _sr(10.45), "dolly", "hero", {"side": 1.0, "fov": 38.0, "look_y": 1.1, "back": 2.2, "height": 1.65, "subj": ["hero"]})
	var mid: Vector3 = (P_BACK + D_B) * 0.5
	var side_d := Vector3(DIR_D.z, 0.0, -DIR_D.x)   # perpendicular to the frisbee's line, toward -X
	shot("S2", _sr(12.5), "static", "slow motion, side-on: the frisbee out of her hand, batted back off his tray (13.01), onto her mask (13.49)",
		{"pos": mid + side_d * 3.3 + Vector3(0.0, 1.35, 0.0), "look": mid + Vector3(0.0, 1.3, 0.0), "fov": 46.0, "hand": 0.3,
		"subj": ["hero", "dolly"]})
	var thr: Vector3 = (H_T + C1_F) * 0.5
	shot("V1", _sr(13.9), "static", "slow motion, high overhead: blind C1 charges at the noise, the hip throw (14.85) lays him on the first table",
		{"pos": thr + Vector3(0.9, 4.3, -1.4), "look": thr + Vector3(-0.6, 0.6, 0.15), "fov": 50.0, "hand": 0.2, "subj": ["hero", "c1"]})
	shot("K2", _sr(16.0), "dolly", "tracking along the lunch tables: C1 slides the whole row feet first, trays flying",
		{"from": Vector3(LAND.x + 0.3, 1.3, LAND.z - 2.3), "to": Vector3(SLIDE_END.x + 0.6, 1.25, LAND.z - 2.3),
		"look_from": LAND + Vector3(0.5, 0.15, 0.0), "look_to": SLIDE_END + Vector3(0.5, 0.1, 0.0), "fov": 44.0, "hand": 0.3,
		"subj": ["c1"]})
	shot("S3", _sr(16.85), "static", "slow motion at the end of the row: off the table into the stacked chairs (17.10)",
		{"pos": CHAIRS + Vector3(2.2, 1.1, -2.4), "look": CHAIRS + Vector3(0.6, 0.6, 0.0), "fov": 50.0, "hand": 0.4, "subj": ["c1"]})
	dutch_shot("D2", _sr(17.7), "dolly", {"roll": -13.0, "side_deg": 160.0, "dist": 3.0, "fov": 46.0, "subj": ["dolly"]})
	shot("W2", s_gone, "dolly", "tail wide: the wreck of the canteen, C1 in the chairs, C2 and C3 at the counter",
		{"from": Vector3(1.6, 2.2, 4.0), "to": Vector3(1.2, 2.0, 3.7), "look_from": Vector3(-1.4, 0.5, 0.4),
		"look_to": Vector3(-1.2, 0.5, 0.4), "fov": 56.0, "hand": 0.4, "subj": ["hero"]})
	push_in("P2", _sr(20.75), "hero", {"from": 4.0, "to": 3.0, "side_deg": 30.0, "fov": 44.0, "look_y": 1.1, "height": 1.35, "subj": ["hero"]})
	for xr: float in [R_X1, R_X2]:
		punch(_sr(xr), "light")
	punch(x4, "medium")


func _fx_sfx() -> void:
	sfx_at("H1", "tray_clang", -3.0)
	sfx_at("H1", "impact_medium", -4.0)
	fx_at("H1", "dust", "c1:Head", {"power": 0.9})
	fx_at("H1", "debris", "c1:Head", {"power": 0.6, "dir": DIR1 + Vector3(0.0, 0.9, 0.0)})
	for xr: float in [R_X1, R_X2]:
		sfx_at(_sr(xr), "tray_clang", -2.0 if xr < R_X2 else 0.0)
		fx_at(_sr(xr), "sparks", "hero:Head", {"power": 0.3})
	sfx_at("H2", "tray_clang", 0.0)
	sfx_at("H2", "impact_heavy", -6.0)
	fx_at("H2", "sparks", "c2:Head", {"power": 0.7})
	sfx_at(_sr(7.25), "tray_clang", -8.0)   # his tray skids across the floor
	sfx_at(s_bench, "whoosh_down", -6.0)
	sfx_at(_sr(R_TOSS), "body_fall", -5.0)   # the tossed bench lands behind him
	sfx_at("H3", "impact_heavy", -1.0)
	sfx_at(slam_s, "body_fall", -3.0)
	fx_at("H3", "dust", "c3:Chest", {"power": 0.8})
	fx_at("H3", "dust", "c2:Chest", {"power": 0.8})
	fx_at(slam_s, "flash", "counter", {"power": 0.5})
	sfx_at(x4, "impact_medium", -2.0)
	fx_at(x4, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(s_throw, "whoosh_down", -4.0)
	sfx_at("A1", "tray_clang", -1.0)
	fx_at("A1", "sparks", "tray_fly", {"power": 0.6})
	sfx_at(tf, "tray_clang", 0.0)
	fx_at(tf, "sparks", "dolly:Head", {"power": 0.6})
	fx_at(tf + 0.1, "stars", "dolly", {"until": s_gone})
	sfx_at(_sr(13.95), "tray_clang", -9.0)   # his own tray hits the floor
	fx_at("H5", "dust", "hero:Foot.L", {"power": 0.6})
	sfx_at("H5", "impact_heavy", -3.0)
	sfx_at(h5 + 0.24, "body_fall", -2.0)
	sfx_at(h5 + 0.26, "slide_whistle", -4.0)
	fx_at(h5 + 0.25, "dust", "table_0", {"power": 0.7})
	for j: int in 2:
		sfx_at(h5 + [0.308, 0.423][j], "tray_clang", -5.0)
		fx_at(h5 + [0.308, 0.423][j], "debris", "lunch_%d" % j, {"power": 0.5, "dir": Vector3(-0.4, 0.9, 0.5)})
	fx_at(sc, "crate", "chairs_a", {"power": 1.0, "dir": Vector3(-1.0, 0.5, 0.0)})
	fx_at(sc, "crate", "chairs_b", {"power": 1.1, "dir": Vector3(-0.8, 0.8, 0.2)})
	fx_at(sc, "flash", "chairs_a", {"power": 0.8})
	fx_at(sc, "dust", "c1:Hips", {"power": 1.0})
	sfx_at(sc, "chair_smash", 0.0)
	sfx_at(sc, "crate_smash", -6.0)
	sfx_at(_sr(18.3), "body_fall", -2.0)
	sfx_at(_sr(19.65), "groan", -5.0)


func _subs() -> void:
	sub(0.3, 1.5, "hero", "Từ từ... nói chuyện đã.")
	sub(1.95, 0.6, "dolly", "Lên!")
	sub(19.5, 0.9, "dolly", "Bai bai!")
	sub(21.0, 1.0, "hero", "...Lại chạy.")
