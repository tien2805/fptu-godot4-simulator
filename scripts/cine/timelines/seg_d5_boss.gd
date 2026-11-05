# File: res://scripts/cine/timelines/seg_d5_boss.gd
# seg_d5_boss (22.430 s, spec C-D8 beat 9 / C-D9; reworked by plan 2026-11-05-w6-fights and its fix round: its own
# choreography, cameras and signature moves, every hit on an accent of the owner's cut of "The Good Life", see the music
# note below). The burning server room under The Beverly in red emergency light: the protagonist against Lê Minh Za Mẫn,
# his katana "bought online" (bent from the first frame), and his three masked guards, with a Vovinam staff snatched off a
# crate. By Day 5 the protagonist blocks and parries; he takes one hit (the fox's, from behind).
#   0.0  insert: the bent blade glints in the red dark; reveal: "Đội bảo vệ, xử lý ticket này!"; 1.83 the protagonist
#        snatches the staff off a crate behind him
#   2.91 H1  a staff thrust into the sheep-masked guard's stomach (slow motion)                      sits down hard
#   3.82     the wolf-masked guard's straight right: blocked on the staff held across (normal speed, punch-in)
#   6.19 H2  his second right sails over the crouching protagonist: the low sweep takes his legs, he goes horizontal and
#            lands flat on his back (slow motion)
#   7.29     Za Mẫn's overhead katana cut rings off the staff held up across (sparks)
#   8.38     the fox-masked guard's right in the protagonist's back (normal speed, punch-in): the one hit he takes
#   9.77 H3  without a look, a spin: the end of the staff across the fox's mask (slow motion)        flat on his back
#  11.65 A1  slow-motion accent: Za Mẫn's flat cut parried on the upright staff; the blade glances off and bites into the
#            rack behind him (12.03, sparks); he wrenches at it, stuck
#  12.74 H4  the staff comes down on the wedged blade: it snaps at the bend (slow motion); he stumbles a step aside and
#            stares at the stub; 13.83 the blade drops out of the rack onto the floor
#  14.93 H5  finisher, no run-up: the staff planted where he stands, the pole-vault flying kick into his chest; he flies
#            back into the server rack against the left wall (17.13, sparks, its lights die) and slides down to sit, the hilt
#            still in his hand (19.29) - one locked-off wide profile of the whole vault
#  19.43-22.43 tail at 1x: the sheep quits from the floor ("Nghỉ việc!"); on Za Mẫn hugging the hilt, the protagonist,
#            winded: "...Bảo hành bảy ngày hả?"
# Hand-off to cine_d5: Za Mẫn ends slumped at ZA_END (yaw -90) against the left racks (front face x -4.9), hugging the hilt
# (hold offset HILT, rot HILT_ROT); the snapped blade lies at BLADE_LAND (yaw BLADE_YAW) in front of rack_a; cine_d5 keeps
# rack_a and has the dead rack behind him (its rack_l1); the desk and the laptop stand where cine_d5 has them.
# Music: the owner's "The Good Life" cut from 24.00 s of the original (W6); every hit sits on an accent of it within
# 0.1 s, the crash on one of the cut's loudest (17.13). No gore: sparks and dust. Contacts are measured on every tier by
# tests/test_cine_d5_boss.gd (tests/support/cine_brawl.gd); the staff and the katana are held props whose angle is keyed
# here (CineActor hold "keys"), the staff and katana moves are code poses on every tier.
# Story time runs slow inside the ramps, so every key and cue is anchored on a real time through _sr() or on a hit's story
# time, and a move never starts after the start of a strike it would cut (a later move overrides a strike).
# Stage: CineTimeline.phase_c_stage("server"), the carried server room (open side +Z), 14 x 10 m box.
# Stage frame: X right, -Z forward (the back wall), ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LENGTH: float = 22.43
const TAIL: float = 3.0
## Real times of the beats (accents of the music cut).
const R_GLINT: float = 0.5
const R_PICK: float = 1.83
const R_H1: float = 2.91
const R_X1: float = 3.82
const R_WM: float = 5.95
const R_H2: float = 6.19
const R_PARRY: float = 7.29
const R_X2: float = 8.38
const R_H3: float = 9.77
const R_A1: float = 11.65
const R_BITE: float = 12.03
const R_H4: float = 12.74
const R_DROP: float = 13.83
const R_H5: float = 14.93
const R_CRASH: float = 17.13
const R_SIT: float = 19.29
const SWELL_END: float = 19.43

## Katana bend (deg): visibly "bought online" from the first frame.
const BEND: float = 22.0
## The katana's rest angle in his hand (actor frame): forward and down.
const KAT_REST := Vector3(-35.0, 0.0, 0.0)
const KAT_FLAT := Vector3(18.0, 0.0, 0.0)   # the flat cut, up a little: the bent tip droops 22 deg
const KAT_OFF := Vector3(0.0, 0.0, -0.02)
const KAT_PARRY := Vector3(11.0, 0.0, 0.0)   # the bent tip droops 22 deg
const KAT_LOOK := Vector3(30.0, 0.0, 0.0)    # the stub held up in front of his eyes
## The hilt hugged to his chest, slumped (= cine_d5's hold).
const HILT := Vector3(-0.15, 0.0, -0.05)
const HILT_ROT := Vector3(60.0, 0.0, 0.0)
## The katana snaps (bent -> stub, the blade left in the rack) this long after H4 in story time: the freeze holds the impact.
const SNAP: float = 0.01
## The snapped blade starts at the katana's bend (its tip piece), in Za Mẫn's frame from his feet at the bite (A_A1, facing
## the rack); measured by tests/test_cine_d5_boss.gd (within 0.08 m).
const BLADE_FROM := Vector3(0.141, 1.443, -0.752)
## The staff in both hands (actor frame): along the body (pointing forward), across it (centred: the grip sits 0.4 m off
## the staff's middle), upright with its tip down (the parry), raised for the smash.
const ST_ALONG := Vector3.ZERO
const ST_ACROSS := Vector3(0.0, 90.0, 0.0)
const OFF_ACROSS := Vector3(0.4, 0.05, -0.12)
const OFF_GUARD := Vector3(0.4, -0.22, -0.18)  # across in front of the chest (the block: his right comes in low)
const OFF_CHOKE := Vector3(0.0, 0.0, 0.3)   # the grip slid up for the sweep (0.95 m of staff in front of the hands)
const ST_UPRIGHT := Vector3(-90.0, 0.0, 0.0)
const OFF_UPRIGHT := Vector3(0.0, 0.0, -0.1)   # upright in front of the hands (staff guard), the blade meets it near its tip
const ST_RAISED := Vector3(65.0, 0.0, 0.0)
const ST_SMASH := Vector3(-8.0, 0.0, 0.0)
## The vault: the staff's tip planted ahead and to the left of the take-off (actor frame), the held staff's angle there.
const ST_PLANT := Vector3(-69.0, 45.0, 0.0)
const OFF_PLANT := Vector3(-0.035, -0.13, -0.035)
const TIP_PLANT := Vector3(-0.35, 0.0, -0.7)

# props (stage frame; the room, the racks along the walls, the desk and the laptop as cine_d5_monitors / cine_d5)
const DESK := Vector3(0.9, 0.0, -1.6)
const LAPTOP := Vector3(0.9, 0.75, -1.65)
const RACK_Z: Array[float] = [-3.4, -2.25, -1.1, 0.05]
const RACK_X_I: int = 1                         # the left rack he is kicked into (rack_x)
const FACE := Vector3(-4.9, 0.0, -2.25)         # its front face where his back meets it
const ZA_END := Vector3(-4.55, 0.0, -2.25)      # = cine_d5's ZA
const BLADE_LAND := Vector3(-3.8, 0.02, -3.5)    # just in front of rack_a, along its face
const BLADE_YAW: float = 115.0

# spacing (m, root to root); tuned against tests/test_cine_d5_boss.gd (surface gaps on every tier)
const D_H1: float = 1.88            # the thrust (the staff's tip in his stomach)
const D_X1: float = 1.10            # the wolf's straight right onto the staff across
const D_SW: float = 1.25            # the low sweep (staff choked, pitched down)
const D_P: float = 1.2              # Za Mẫn's overhead cut onto the raised staff
const D_X2: float = 1.0             # the fox's right in his back
const D_A1: float = 1.3             # Za Mẫn's flat cut onto the upright staff (the first half's anchor)
const D_PARRY: float = 0.3          # the protagonist stands this much further back for the parry: the blade's tip on the staff
const PARRY_TURN: float = 5.0       # turned a little to his left at the parry: the staff on the blade's line
const D_BITE: float = 1.62          # Za Mẫn to the bitten rack's centre
const D_H5: float = 1.1             # the flying kick
const AIR: float = 0.6              # take-off to the kick

# the fight frame of the first half (the pre-rework layout, rotated so its line runs to Za Mẫn's A1 spot; the wolf on the
# protagonist's left)
const P0_F := Vector3(-0.3, 0.0, 1.25)
const S0_F := Vector3(-2.7, 0.0, 0.1)
const W0_F := Vector3(2.3, 0.0, -0.4)
const DIR_W_F := Vector3(0.845, 0.0, -0.534)
const DIR_Z_F := Vector3(0.243, 0.0, -0.97)
## Second half (stage frame): Za Mẫn at the flat cut, his facing there, the take-off, the slam point.
const A_A1 := Vector3(-3.5, 0.0, -2.65)
const Y_ZH: float = -75.0
const T5 := Vector3(-2.48, 0.0, -3.44)
const A_SLAM := Vector3(-4.76, 0.0, -2.25)
const A0 := Vector3(-4.0, 0.0, -2.95)
const F0 := Vector3(1.4, 0.0, -3.0)

var DIR_S: Vector3
var DIR_W: Vector3
var DIR_Z: Vector3
var DIR_K: Vector3   # the kick's line: from the take-off to the slam point
var P0: Vector3
var S0: Vector3
var W0: Vector3
var y_pick: float    # the protagonist turned round to the staff lying across a crate behind his right shoulder
var P_PICK: Vector3
var STAFF_ON: Vector3   # the staff on the crate (its grip, where his hands close on it)
var CRATE: Vector3
var S_H1: Vector3
var S_SIT: Vector3
var W_A: Vector3
var W_LIE: Vector3
var P1: Vector3      # the protagonist after the block (the sweep's distance)
var A_P: Vector3     # Za Mẫn's overhead cut
var A_PB: Vector3    # pushed back off the staff
var F_A: Vector3     # the fox in the protagonist's back
var F_LIE: Vector3
var P1B: Vector3     # the protagonist knocked a step forward by the fox
var P2: Vector3      # the first half's anchor
var P2H: Vector3     # the protagonist at the parry
var RACK_A: Vector3  # the rack the flat cut bites into (behind Za Mẫn's left shoulder, against the back wall)
var y_rack_a: float
var y_bite: float    # Za Mẫn facing the rack at the bite
var BLADE_AT: Vector3   # the snapped blade's start (the bend, in the rack)
var A_K: Vector3     # Za Mẫn at the kick
var H_K: Vector3     # the protagonist at the kick
var L5: Vector3      # the landing
var PLANT: Vector3   # the staff's tip on the floor
var RACK_X: Vector3
var y_z: float       # the protagonist facing Za Mẫn (first half)
var y_h3: float      # the protagonist's yaw at H3 (the staff's left end on the fox)
var y_a1: float      # the protagonist facing Za Mẫn at A1
var y_k: float       # the protagonist facing Za Mẫn at the kick
var y_ak: float      # Za Mẫn facing the protagonist at the kick

# story times
var h1: float
var h2: float
var h3: float
var a1: float
var h4: float
var h5: float
var x1: float
var x2: float
var s_pick: float
var s_wm: float
var s_par: float
var s_bite: float
var s_yank: float
var s_drop: float
var s_take: float
var sc: float
var slam_s: float
var s_sit: float


func _sr(r: float) -> float:
	return clock.story_at(r)


static func _d(a: Vector3, b: Vector3) -> Vector3:
	var v: Vector3 = b - a
	v.y = 0.0
	return v.normalized()


## Unit vector at yaw (deg) on the ground: the way a character with that yaw faces.
static func _fwd(yaw_deg: float) -> Vector3:
	var y: float = deg_to_rad(yaw_deg)
	return Vector3(-sin(y), 0.0, -cos(y))


func build() -> void:
	slot = "seg_d5_boss"
	length = LENGTH
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5
	stage = CineTimeline.phase_c_stage("server")
	stage["exposure"] = 1.5
	stage["ambient"] = 1.8
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
	h4 = story_time("H4")
	h5 = story_time("H5")
	x1 = _sr(R_X1)
	x2 = _sr(R_X2)
	s_pick = _sr(R_PICK)
	s_wm = _sr(R_WM)
	s_par = _sr(R_PARRY)
	s_bite = _sr(R_BITE)
	s_yank = s_bite + 0.12
	s_drop = _sr(R_DROP)
	s_take = h5 - 0.4            # the flying kick leaves the ground (its air window opens at 0.15 of its 1.0 s)
	sc = _sr(R_CRASH)
	slam_s = sc
	s_sit = _sr(R_SIT)
	_layout()
	_props()
	_hero()
	_sheep()
	_wolf()
	_fox()
	_za()
	_shots()
	_fx_sfx()
	_subs()


func _cast() -> void:
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("za", StoryCast.opts("za_man"), StoryCast.speaker("za_man"), StoryCast.color("za_man"))
	for e: Array in [["sheep", "guard_sheep"], ["wolf", "guard_wolf"], ["fox", "guard_fox"]]:
		actor(String(e[0]), StoryCast.opts(String(e[1])), StoryCast.speaker(String(e[1])), StoryCast.color(String(e[1])))


## Real-time ramps on the music's accents ({"r": ...}; the story times are placeholders the clock recomputes). Contact
## pairs are checked on every tier by tests/test_cine_d5_boss.gd.
func _hits() -> void:
	hit("H1", 2.2, "medium", "a staff thrust into the sheep-masked guard's stomach", {"r": R_H1, "att": "hero:staff", "tgt": "sheep:torso"})
	hit("H2", 5.0, "medium", "the low staff sweep takes the wolf-masked guard's legs: flat on his back", {"r": R_H2, "att": "hero:staff", "tgt": "wolf:shins"})
	hit("H3", 7.8, "medium", "a blind spin: the end of the staff across the fox-masked guard's mask", {"r": R_H3, "att": "hero:staff", "tgt": "fox:Head"})
	hit("A1", 9.6, "accent", "slow-motion accent: Za Mẫn's flat katana cut parried on the upright staff, it glances off into a rack", {"r": R_A1})
	hit("H4", 10.6, "heavy", "the staff comes down on the katana wedged in the rack: it snaps at the bend",
		{"r": R_H4, "hq": 0.3, "att": "hero:staff", "tgt": "za:katana"})
	hit("H5", 12.9, "finisher", "the pole-vault flying kick off the planted staff: Za Mẫn into the rack on the wall (swell)",
		{"r": R_H5, "hq": SWELL_END - R_H5 - 0.55, "att": "hero:feet", "tgt": "za:torso"})


func _layout() -> void:
	# the first half: the old fight frame turned so its line (DIR_Z) runs from the protagonist's parry spot P2 to A_A1,
	# mirrored on that line for the wolf (he comes in on the protagonist's left, clear of the back wall)
	P2 = A_A1 + _fwd(Y_ZH) * D_A1
	DIR_Z = _d(P2, A_A1)
	var rot: float = CineTimeline.face(Vector3.ZERO, DIR_Z) - CineTimeline.face(Vector3.ZERO, DIR_Z_F)
	var rb := Basis(Vector3.UP, deg_to_rad(rot))
	var mir: Vector3 = DIR_Z_F * (2.0 * DIR_W_F.dot(DIR_Z_F)) - DIR_W_F
	DIR_W = (rb * mir).normalized()
	P0 = P2 - DIR_Z * 0.45 - DIR_W * (D_X1 - D_SW)
	S0 = P0 + rb * (S0_F - P0_F)
	var w_rel: Vector3 = W0_F - P0_F
	W0 = P0 + rb * (DIR_Z_F * (2.0 * w_rel.dot(DIR_Z_F)) - w_rel)
	y_pick = CineTimeline.face(P0, A0) - 150.0
	P_PICK = P0 + _fwd(y_pick) * 0.25
	STAFF_ON = P_PICK + _fwd(y_pick) * 0.38 + Vector3(0.0, 0.436, 0.0)
	CRATE = STAFF_ON + _fwd(y_pick + 90.0) * 0.6
	CRATE.y = 0.21
	DIR_S = _d(P0, S0)
	S_H1 = P0 + DIR_S * D_H1
	S_SIT = S_H1 + DIR_S * 0.55
	W_A = P0 + DIR_W * D_X1
	W_LIE = W_A + DIR_W * 0.45
	P1 = W_A - DIR_W * D_SW
	A_P = P1 + DIR_Z * D_P
	A_PB = A_P + DIR_Z * 0.35
	y_z = CineTimeline.face(P1, A_P)
	# the fox comes up behind the protagonist's left shoulder; the blind spin brings the staff's left end round onto him
	F_A = P1 + _fwd(y_z + 145.0) * D_X2
	P1B = P1 + DIR_Z * 0.15
	var th_f: float = CineTimeline.face(P1B, F_A)
	y_h3 = th_f - 56.0   # the staff's left end sits 56 deg left of his facing (hands 0.45 m out, the end 0.85 m aside)
	while y_h3 < y_z - 30.0:
		y_h3 += 360.0
	while y_h3 > y_z + 330.0:
		y_h3 -= 360.0
	F_LIE = F_A + _d(P1B, F_A) * 0.5
	P2H = P2 - DIR_Z * D_PARRY
	y_a1 = CineTimeline.face(P2H, A_A1)
	# the flat cut runs right to left and ends 100 deg to his left: the blade in the rack there (against the back wall)
	y_bite = Y_ZH + 100.0
	RACK_A = A_A1 + _fwd(y_bite) * D_BITE
	y_rack_a = CineTimeline.face(RACK_A, A_A1)
	BLADE_AT = A_A1 + Basis(Vector3.UP, deg_to_rad(y_bite)) * BLADE_FROM
	# the kick: from the take-off (where the protagonist smashed the blade) on a line to the slam point on the wall rack
	DIR_K = _d(T5, A_SLAM)
	var flight: float = Vector2(A_SLAM.x - T5.x, A_SLAM.z - T5.z).length() - D_H5 - AIR
	A_K = A_SLAM - DIR_K * flight
	H_K = A_K - DIR_K * D_H5
	L5 = H_K + DIR_K * 0.2
	y_k = CineTimeline.face(T5, A_K)
	y_ak = CineTimeline.face(A_K, H_K)
	PLANT = T5 + Basis(Vector3.UP, deg_to_rad(y_k)) * TIP_PLANT
	PLANT.y = 0.0
	RACK_X = Vector3(-5.4, 0.0, RACK_Z[RACK_X_I])


func _props() -> void:
	prop("room", "server_room", Vector3.ZERO, 0.0, {"width": 13.0, "depth": 9.3, "z1": 4.5})
	prop("desk", "desk", DESK, 0.0, {"set": true})
	prop("laptop", "laptop", LAPTOP, 180.0, {"set": true})
	prop("crate_pick", "small_crate", CRATE, y_pick)
	prop("staff_crate", "staff", STAFF_ON, y_pick + 90.0, {"hide_at": s_pick})
	# the racks along both walls (as cine_d5_monitors.server_room); the second one on the left takes him (sc), its lights
	# die (swapped for a dead one)
	for i: int in RACK_Z.size():
		if i == RACK_X_I:
			prop("rack_x", "server_rack", RACK_X, -90.0, {"seed": i, "hide_at": sc})
			prop("rack_x_dead", "server_rack", RACK_X, -90.0, {"seed": i, "dead": true, "show_at": sc})
		else:
			prop("rack_l%d" % i, "server_rack", Vector3(-5.4, 0.0, RACK_Z[i]), -90.0, {"seed": i, "set": true})
		prop("rack_r%d" % i, "server_rack", Vector3(5.4, 0.0, RACK_Z[i]), 90.0, {"seed": i + 1, "set": true})
	prop("rack_a", "server_rack", RACK_A, y_rack_a, {"seed": 2})
	prop("fire0", "fire", Vector3(-5.0, 0.0, 3.4), 0.0, {"anim": true, "spread": 0.8})
	prop("fire1", "fire", Vector3(5.0, 0.0, 3.6), 0.0, {"anim": true, "spread": 0.7})
	prop("fire2", "fire", Vector3(3.0, 0.0, -4.2), 0.0, {"anim": true, "spread": 0.9})
	# the snapped-off blade: stuck in the rack at the bend, then it drops out to the floor (= cine_d5's blade)
	var r_from := Vector3(-(BEND - KAT_FLAT.x), y_bite, 0.0)
	var bp: Array = [[h4 + SNAP, BLADE_AT, r_from]]
	var s_fall: float = h4 + 0.1
	for i: int in 5:   # falls (y quadratic in story time), tipping flat; one small bounce
		var u: float = float(i + 1) / 5.0
		var at: Vector3 = BLADE_AT.lerp(BLADE_LAND, u)
		at.y = lerpf(BLADE_AT.y, BLADE_LAND.y, u * u)
		bp.append([lerpf(s_fall, s_drop, u), at, r_from.lerp(Vector3(0.0, BLADE_YAW - 20.0, 0.0), u)])
	bp.append([s_drop + 0.06, BLADE_LAND + Vector3(0.0, 0.04, 0.0), Vector3(-6.0, BLADE_YAW - 8.0, 0.0)])
	bp.append([s_drop + 0.12, BLADE_LAND, Vector3(0.0, BLADE_YAW, 0.0)])
	prop("blade", "katana_blade", BLADE_LAND, BLADE_YAW, {"show_at": h4 + SNAP, "path": bp})
	# the vault: the staff's tip planted at the take-off; it stands up as he goes over, then topples to his left
	var bz: Basis = Basis(Vector3.UP, deg_to_rad(y_k))
	var dv0: Vector3 = bz * (Basis.from_euler(ST_PLANT * (PI / 180.0)) * Vector3.FORWARD)
	var left: Vector3 = bz * Vector3.LEFT
	var path: Array = []
	var n: int = 12
	for i: int in n + 1:
		var u: float = float(i) / float(n)
		var dv: Vector3
		if u <= 0.4:
			dv = dv0.slerp(Vector3.DOWN, u / 0.4)
		else:
			var ps: float = deg_to_rad(90.0 * smoothstep(0.0, 1.0, (u - 0.4) / 0.6))
			dv = Vector3.DOWN * cos(ps) - left * sin(ps)
		var tip: Vector3 = PLANT + Vector3(0.0, 0.018 * smoothstep(0.7, 1.0, u), 0.0)
		path.append([s_take + 0.7 * u, tip - dv * (CinePropsC.STAFF_LEN - 0.45), _dir_rot(dv)])
	prop("staff_v", "staff", path[path.size() - 1][1], 0.0, {"show_at": s_take, "path": path})


## Euler (deg) of a staff / katana prop whose front end (local -Z) points along d.
static func _dir_rot(d: Vector3) -> Vector3:
	var v: Vector3 = d.normalized()
	return Vector3(rad_to_deg(asin(clampf(v.y, -1.0, 1.0))), rad_to_deg(atan2(-v.x, -v.z)), 0.0)


func _hero() -> void:
	var y0: float = CineTimeline.face(P0, A0)
	var y_s: float = CineTimeline.face(P0, S_H1)
	var y_w: float = CineTimeline.face(P0, W_A)
	var y_w1: float = CineTimeline.face(P1, W_A)
	var y_h4: float = CineTimeline.face(T5, BLADE_AT)
	var p0b: Vector3 = P0 - DIR_W * 0.08
	look("hero", 0.0, _sr(1.3), "za")
	expr("hero", 0.0, "angry")
	key("hero", 0.0, P0, y0)
	move("hero", 0.0, "fight_idle")
	# 1.83 round to his right, the staff off the crate behind him, on round to the sheep on his left, 2.91 the thrust
	key("hero", _sr(1.0), P0, y0)
	key("hero", _sr(1.55), P_PICK, y_pick, {"mode": "out"})
	look("hero", _sr(1.3), _sr(2.0), STAFF_ON)
	strike("hero", s_pick, "pickup", {"dur": 0.45, "reach": 0.1})
	move("hero", s_pick + 0.2, "staff_guard", {"fade": 0.15})
	key("hero", _sr(2.0), P_PICK, y_pick)
	key("hero", _sr(2.4), P0, y_s, {"mode": "out"})
	look("hero", _sr(2.0), h1 + 0.05, "sheep")
	strike("hero", "H1", "staff_thrust")
	# 3.82 the wolf's right: the staff up across in front of his face, the blow rocks him back a little
	key("hero", h1 + 0.08, P0, y_s)
	key("hero", x1 - 0.2, P0, y_w, {"mode": "out"})
	look("hero", h1 + 0.05, h2 + 0.3, "wolf")
	move("hero", x1 - 0.2, "tray_guard", {"fade": 0.12})   # cuts the thrust's follow-through: the block comes up at once
	expr("hero", x1, "pain")
	key("hero", x1, P0, y_w)
	key("hero", x1 + 0.12, p0b, y_w, {"mode": "out"})
	move("hero", x1 + 0.45, "staff_guard", {"fade": 0.15})
	key("hero", x1 + 0.5, p0b, y_w)
	key("hero", x1 + 0.85, P1, y_w1, {"mode": "out"})
	expr("hero", x1 + 0.3, "angry")
	# 6.19 his second right goes over the crouch, the low sweep (the body turns through it, right to left)
	key("hero", h2 - 0.75, P1, y_w1)
	key("hero", h2 - 0.45, P1, y_w1 - 70.0, {"mode": "out"})
	key("hero", h2, P1, y_w1, {"mode": "linear"})
	key("hero", h2 + 0.2, P1, y_w1 + 35.0, {"mode": "out"})
	strike("hero", "H2", "staff_sweep")
	# 7.29 up into a high block, the staff across: Za Mẫn's cut rings off it
	key("hero", s_par - 0.1, P1, y_z, {"mode": "out"})
	look("hero", h2 + 0.3, x2, "za")
	strike("hero", s_par, "block_high", {"dur": 0.6})
	move("hero", s_par + 0.3, "staff_guard", {"fade": 0.15})
	# 8.38 the fox's right in his back, a stumble forward; 9.77 the blind spin, the staff's left end on the fox's mask
	strike("hero", x2, "hit_stomach")
	expr("hero", x2, "pain")
	key("hero", x2, P1, y_z)
	key("hero", x2 + 0.3, P1B, y_z, {"mode": "out"})
	move("hero", x2 + 0.5, "staff_guard", {"fade": 0.15})
	expr("hero", x2 + 0.6, "angry")
	key("hero", h3 - 0.28, P1B, y_z - 15.0)
	key("hero", h3, P1B, y_h3, {"mode": "linear"})
	key("hero", h3 + 0.18, P1B, y_h3 + 35.0, {"mode": "out"})
	strike("hero", "H3", "staff_swing")
	look("hero", x2 + 0.6, h3 + 0.3, "fox")
	# back round to Za Mẫn, a step in; 11.65 the flat cut on the upright staff: he rides it off to his right; 12.74 a step
	# to the wedged blade, the staff comes down on it
	move("hero", h3 + 0.36, "staff_guard", {"fade": 0.15})
	key("hero", h3 + 0.36, P1B, y_h3 + 35.0)
	key("hero", a1 - 0.34, P2H, y_a1 + PARRY_TURN, {"mode": "out"})
	look("hero", h3 + 0.4, h4 - 0.25, "za")
	key("hero", a1, P2H, y_a1 + PARRY_TURN)
	key("hero", a1 + 0.1, P2H, y_a1 - 10.0, {"mode": "out"})
	key("hero", a1 + 0.12, P2H, y_a1 - 10.0)
	key("hero", h4 - 0.24, T5, y_h4, {"mode": "out"})
	look("hero", h4 - 0.25, h4 + 0.3, BLADE_AT)
	strike("hero", "H4", "staff_smash", {"reach": 0.0})
	expr("hero", h4, "angry")
	move("hero", h4 + 0.015, "staff_guard", {"fade": 0.1})   # no follow-through into the floor
	# no run-up: he turns to Za Mẫn where he stands, plants the staff, 14.93 the vault, the kick
	key("hero", h4, T5, y_h4)
	key("hero", s_take - 0.35, T5, y_k, {"mode": "out"})
	look("hero", h4 + 0.3, story_end, "za")
	key("hero", s_take, T5, y_k, {"mode": "in"})
	strike("hero", "H5", "flying_kick", {"reach": {"mixamo": Vector2(-0.05, 0.0), "ual": 0.09, "native": 0.09, "code": 0.09}})
	key("hero", h5, H_K, y_k, {"mode": "linear"})
	key("hero", h5 + 0.45, L5, y_k, {"mode": "out"})
	move("hero", h5 + 0.5, "fight_idle", {"fade": 0.3})
	move("hero", _sr(20.0), "winded", {"fade": 0.3})
	expr("hero", _sr(20.6), "happy")
	# the staff: off the crate across his hands, along for the thrust, across in front of his face for the block, choked
	# and pitched down for the sweep, across for the high block and the spin, upright for the parry, raised and brought
	# down for the smash, its tip down to the floor at the take-off
	var keys: Array = [
		[s_pick, ST_ACROSS, Vector3.ZERO], [_sr(2.0), ST_ACROSS, Vector3.ZERO], [_sr(2.4), ST_ALONG, Vector3.ZERO],
		[h1 - 0.25, ST_ALONG, Vector3.ZERO], [h1 - 0.1, Vector3(-6.0, 0.0, 0.0), Vector3.ZERO],
		[h1 + 0.12, Vector3(-6.0, 0.0, 0.0), Vector3.ZERO],
		[x1 - 0.06, ST_ACROSS, OFF_GUARD], [x1 + 0.4, ST_ACROSS, OFF_GUARD],
		[x1 + 0.6, ST_ALONG, Vector3.ZERO],
		[h2 - 0.45, ST_ALONG, Vector3.ZERO], [h2 - 0.2, Vector3(-24.0, 0.0, 0.0), OFF_CHOKE],
		[h2 + 0.15, Vector3(-24.0, 0.0, 0.0), OFF_CHOKE], [s_par - 0.22, ST_ACROSS, OFF_ACROSS],
		[h3 + 0.36, ST_ACROSS, OFF_ACROSS], [a1 - 0.3, ST_UPRIGHT, OFF_UPRIGHT], [a1 + 0.1, ST_UPRIGHT, OFF_UPRIGHT],
		[h4 - 0.24, ST_RAISED, Vector3.ZERO], [h4, ST_SMASH, Vector3.ZERO],
		[h4 + 0.12, ST_SMASH, Vector3.ZERO], [h4 + 0.35, ST_ALONG, Vector3.ZERO],
		[s_take - 0.25, Vector3(-10.0, 0.0, 0.0), Vector3.ZERO], [s_take, ST_PLANT, OFF_PLANT]]
	hold("hero", s_pick, s_take, "staff", {"mid": "Wrist.L", "keys": keys, "rot": ST_ACROSS})


func _sheep() -> void:
	StoryCast.dress(self, "sheep", "guard_sheep")
	var y_a: float = CineTimeline.face(S_H1, P0)
	key("sheep", 0.0, S0, CineTimeline.face(S0, P0))
	move("sheep", 0.0, "fight_idle")
	key("sheep", _sr(1.0), S0, CineTimeline.face(S0, S_H1))
	move("sheep", _sr(1.0), "walk", {"fade": 0.15})
	key("sheep", _sr(2.45), S_H1, y_a, {"mode": "out"})
	move("sheep", _sr(2.4), "fight_idle", {"fade": 0.1})
	look("sheep", 0.0, h1 + 0.6, "hero")
	# 2.91 the staff in his stomach: back two steps, down hard on the floor, sits there winded to the end (quits from the
	# floor in the tail: "Nghỉ việc!")
	strike("sheep", "H1", "hit_stomach")
	expr("sheep", h1, "pain")
	key("sheep", h1, S_H1, y_a)
	key("sheep", h1 + 0.4, S_SIT, y_a, {"mode": "out"})
	strike("sheep", h1 + 0.25, "slammed")
	move("sheep", h1 + 1.01, "slumped", {"fade": 0.15})
	fx_at(h1 + 0.6, "stars", "sheep", {"until": _sr(19.5)})
	look("sheep", _sr(19.4), story_end, "hero")
	expr("sheep", _sr(19.5), "open")


func _wolf() -> void:
	StoryCast.dress(self, "wolf", "guard_wolf")
	var y_a: float = CineTimeline.face(W_A, P0)
	key("wolf", 0.0, W0, CineTimeline.face(W0, P0))
	move("wolf", 0.0, "fight_idle")
	key("wolf", _sr(1.0), W0, CineTimeline.face(W0, W_A))
	move("wolf", _sr(1.0), "walk", {"fade": 0.15})
	key("wolf", _sr(2.5), W_A + DIR_W * 0.18, y_a, {"mode": "out"})
	key("wolf", x1 - 0.15, W_A + DIR_W * 0.18, y_a)
	key("wolf", x1 - 0.02, W_A, y_a, {"mode": "out"})   # steps in with the right
	move("wolf", _sr(2.45), "fight_idle", {"fade": 0.1})
	look("wolf", 0.0, h2, "hero")
	strike("wolf", x1, "cross", {"reach": {"mixamo": Vector2(-0.07, 0.06), "ual": 0.14, "native": 0.11, "code": 0.11}})
	move("wolf", x1 + 0.3, "fight_idle", {"fade": 0.15})
	# 5.95 a second right over the crouch, 6.19 the sweep: legs out, horizontal in the air, flat on his back
	strike("wolf", s_wm, "cross", {"reach": {"mixamo": Vector2(-0.05, -0.1), "ual": -0.05, "native": -0.05, "code": -0.05}})   # over the crouch
	key("wolf", h2, W_A, CineTimeline.face(W_A, P1))
	strike("wolf", "H2", "thrown", {"dur": 0.45, "fade": 0.03})
	expr("wolf", h2, "pain")
	key("wolf", h2 + 0.4, W_LIE, CineTimeline.face(W_A, P1), {"mode": "linear", "arc": 0.45})
	move("wolf", h2 + 0.4, "lie_flat", {"fade": 0.1})
	key("wolf", h2 + 0.6, W_LIE, CineTimeline.face(W_A, P1))
	fx_at(h2 + 0.6, "stars", "wolf", {"until": story_end})


func _fox() -> void:
	StoryCast.dress(self, "fox", "guard_fox")
	var y_a: float = CineTimeline.face(F_A, P1)
	key("fox", 0.0, F0, CineTimeline.face(F0, P0))
	move("fox", 0.0, "fight_idle")
	key("fox", _sr(5.4), F0, CineTimeline.face(F0, F_A))
	move("fox", _sr(5.4), "walk", {"fade": 0.15})
	key("fox", _sr(7.9), F_A, y_a, {"mode": "out"})
	move("fox", _sr(7.85), "fight_idle", {"fade": 0.1})
	look("fox", 0.0, h3, "hero")
	strike("fox", x2, "cross", {"reach": {"mixamo": Vector2(-0.07, 0.06), "ual": 0.14, "native": 0.11, "code": 0.11}})
	move("fox", x2 + 0.3, "fight_idle", {"fade": 0.15})
	# 9.77 the staff's end across his mask: flat on his back
	key("fox", h3, F_A, CineTimeline.face(F_A, P1B))
	strike("fox", "H3", "thrown", {"dur": 0.5})
	expr("fox", h3, "pain")
	key("fox", h3 + 0.42, F_LIE, CineTimeline.face(F_A, P1B), {"mode": "linear", "arc": 0.3})
	move("fox", h3 + 0.45, "lie_flat", {"fade": 0.1})
	key("fox", h3 + 0.6, F_LIE, CineTimeline.face(F_A, P1B))
	fx_at(h3 + 0.6, "stars", "fox", {"until": story_end})


func _za() -> void:
	StoryCast.dress(self, "za", "za_man")
	var y0: float = CineTimeline.face(A0, P0)
	var y_p: float = CineTimeline.face(A_P, P1)
	var stub: Vector3 = A_K + _fwd(y_ak) * 0.45 + Vector3(0.0, 1.25, 0.0)
	key("za", 0.0, A0, y0)
	move("za", 0.0, "fight_idle")
	look("za", 0.0, h4 + 0.3, "hero")
	move("za", _sr(1.0), "point", {"fade": 0.15})
	move("za", _sr(2.0), "fight_idle", {"fade": 0.2})
	expr("za", 0.0, "angry")
	# 7.29 in for an overhead cut onto the raised staff, pushed back off it
	key("za", _sr(4.0), A0, CineTimeline.face(A0, A_P))
	move("za", _sr(4.0), "walk", {"fade": 0.15})
	key("za", _sr(5.95), A_P, y_p, {"mode": "out"})
	move("za", _sr(5.9), "fight_idle", {"fade": 0.1})
	strike("za", s_par + 0.07, "chair_smash", {"dur": 0.7, "reach": 0.0})   # the blade meets the staff at 0.4 of the cut
	key("za", s_par + 0.05, A_P, y_p)
	key("za", s_par + 0.5, A_PB, y_p, {"mode": "out"})
	move("za", s_par + 0.36, "fight_idle", {"fade": 0.15})
	# 11.65 the flat cut, his body turns through it right to left: met on the upright staff, on round, the blade bites the
	# rack behind his left shoulder (12.03)
	key("za", x2, A_PB, y_p)
	key("za", a1 - 0.75, A_A1, Y_ZH, {"mode": "out"})
	key("za", a1 - 0.42, A_A1, Y_ZH - 80.0, {"mode": "out"})
	key("za", a1, A_A1, Y_ZH, {"mode": "linear"})
	key("za", s_bite, A_A1, y_bite, {"mode": "out"})
	strike("za", "A1", "katana_slash")
	expr("za", a1, "angry")
	# wrenches at it, stuck; 12.74 the staff snaps it at the bend: he stumbles a step aside, stares at the stub, the stub up
	# for an overhead cut: the kick lands first, in his open chest (14.93)
	strike("za", h4 - 0.03, "yank", {"dur": 0.45})   # the pull peaks as the staff lands
	key("za", s_bite + 0.02, A_A1, y_bite)
	expr("za", h4, "pain")
	key("za", h4 + 0.02, A_A1, y_bite)
	key("za", h4 + 0.35, A_K, y_ak, {"mode": "out"})
	move("za", h4 + 0.3, "fight_idle", {"fade": 0.2})
	look("za", h4 + 0.3, h5 - 0.35, stub)
	expr("za", h4 + 0.4, "open")
	look("za", h5 - 0.35, story_end, "hero")
	expr("za", h5 - 0.35, "angry")
	key("za", h5 - 0.1, A_K, y_ak)
	strike("za", h5 + 0.15, "chair_smash", {"dur": 0.9})
	strike("za", "H5", "blown_back", {"fade": 0.06})
	expr("za", h5, "pain")
	key("za", h5, A_K, y_ak)
	key("za", h5 + 0.1, A_K + DIR_K * 0.55, y_ak, {"mode": "linear"})   # blown clear of the kicking leg at once
	key("za", sc, A_SLAM, y_ak, {"mode": "out", "arc": 0.35})
	strike("za", sc, "slammed", {"dur": s_sit - sc})   # slides down the rack to sit by s_sit
	key("za", sc + 0.06, A_SLAM - DIR_K * 0.17, y_ak, {"mode": "out"})   # off the rack: his head clears it as he slumps
	key("za", s_sit, ZA_END, -90.0)
	move("za", s_sit, "slumped", {"fade": 0.1})
	fx_at(s_sit, "stars", "za", {"until": story_end})
	expr("za", s_sit + 0.5, "done")
	# the bent katana in his hand, its angle keyed through the cuts; the stub after H4, hugged to his chest at the end
	hold("za", 0.0, h4 + SNAP, "katana", {"bend": BEND, "rot": KAT_REST, "offset": KAT_OFF, "keys": [
		[0.0, KAT_REST, KAT_OFF], [s_par - 0.28, KAT_REST, KAT_OFF], [s_par - 0.1, Vector3(110.0, 0.0, 0.0), KAT_OFF],
		[s_par, KAT_PARRY, KAT_OFF], [s_par + 0.2, Vector3(-20.0, 0.0, 0.0), KAT_OFF], [s_par + 0.5, KAT_REST, KAT_OFF],
		[a1 - 0.45, KAT_REST, KAT_OFF], [a1 - 0.3, KAT_FLAT, KAT_OFF]]})
	hold("za", h4 + SNAP, story_end, "katana", {"broken": true, "rot": KAT_FLAT, "offset": KAT_OFF, "keys": [
		[h4 + SNAP, KAT_FLAT, KAT_OFF], [h4 + 0.3, KAT_FLAT, KAT_OFF], [h4 + 0.55, KAT_LOOK, KAT_OFF],
		[h5 - 0.35, KAT_LOOK, KAT_OFF], [h5 - 0.05, Vector3(70.0, 0.0, 0.0), KAT_OFF], [h5 + 0.3, Vector3(70.0, 0.0, 0.0), KAT_OFF],
		[h5 + 0.8, KAT_REST, KAT_OFF], [s_sit, KAT_REST, KAT_OFF], [s_sit + 0.5, HILT_ROT, HILT]]})


func _shots() -> void:
	var y_a0: float = CineTimeline.face(A0, P0)
	var a0f: Vector3 = _fwd(y_a0)
	var a0r: Vector3 = Vector3(-a0f.z, 0.0, a0f.x)   # his right
	var glint: Vector3 = _glint()
	shot("G1", 0.0, "static", "insert: the bent blade in Za Mẫn's hand catches the red light, a glint runs along it",
		{"pos": glint + a0r * 0.75 + a0f * 0.2 + Vector3(0.0, 0.12, 0.0), "look": glint, "fov": 34.0, "hand": 0.15, "subj": []})
	shot("R1", 0.85, "dolly", "reveal, wide: Za Mẫn with the bent katana before his racks, three masked guards, the protagonist",
		{"from": Vector3(0.4, 2.2, 0.6), "to": Vector3(0.7, 2.45, 1.0), "look_from": Vector3(-2.6, 1.1, -2.6),
		"look_to": Vector3(-2.6, 1.0, -2.4), "fov": 50.0, "hand": 0.25, "subj": ["za", "hero"]})
	hero_shot("L1", _sr(1.5), "hero", {"side_deg": -60.0, "dist": 2.0, "fov": 46.0})
	shot("O1", _sr(2.4), "orbit", "slow-motion orbit: the staff thrust into the sheep's stomach (2.91)",
		{"center": (P0 + S_H1) * 0.5 + Vector3(0.0, 1.3, 0.0), "radius": 3.0, "deg_from": 20.0, "deg_to": 45.0, "height": 1.4,
		"fov": 46.0, "hand": 0.3, "subj": ["hero", "sheep"]})
	ots_shot("T1", _sr(3.45), "wolf", "hero", {"side": 1.0, "fov": 36.0, "look_y": 1.25, "back": 1.8})
	shot("S1", _sr(5.4), "static", "slow motion, side-on: the low sweep takes the wolf's legs (6.19)",
		{"pos": (P1 + W_A) * 0.5 + Vector3(DIR_W.z, 0.0, -DIR_W.x) * 3.0 + Vector3(0.0, 1.2, 0.0),
		"look": (P1 + W_A) * 0.5 + Vector3(0.0, 1.05, 0.0), "fov": 50.0, "hand": 0.3, "subj": ["hero", "wolf"], "exit_ok": [6.55, 6.95]})
	two_shot("T2", _sr(6.95), "hero", "za", {"side": 1.0, "fov": 40.0, "look_y": 1.2, "height": 1.5, "dist": 3.4})
	shot("S2", _sr(8.05), "static", "slow motion, wide: the fox's right in his back, the blind spin, the staff across the fox's mask (9.77)",
		{"pos": P1B + _fwd(y_z + 70.0) * 3.4 + Vector3(0.0, 1.3, 0.0), "look": (P1B + F_A) * 0.5 + Vector3(0.0, 1.15, 0.0),
		"fov": 50.0, "hand": 0.3, "subj": ["hero", "fox"]})
	push_in("P1", _sr(10.35), "za", {"from": 5.5, "to": 3.8, "side_deg": -30.0, "fov": 30.0, "look_y": 1.35, "height": 1.45})
	shot("O2", _sr(11.1), "orbit", "low slow orbit: the flat cut parried on the upright staff (11.65), the blade into a rack (12.03)",
		{"center": (A_A1 + P2H) * 0.5 + Vector3(0.0, 1.15, 0.0), "radius": 3.0, "deg_from": -15.0, "deg_to": 10.0, "height": 1.0,
		"fov": 48.0, "hand": 0.3, "subj": ["hero", "za"]})
	shot("S3", _sr(12.3), "static", "slow motion, low: the staff comes down on the wedged blade, it snaps (12.74), the blade drops",
		{"pos": Vector3(-1.6, 0.9, -1.6), "look": (BLADE_AT + T5) * 0.5 + Vector3(0.0, 0.5, 0.2), "fov": 48.0, "hand": 0.3,
		"subj": ["hero", "za"]})
	dutch_shot("D1", _sr(13.62), "za", {"roll": -18.0, "side_deg": -45.0, "dist": 2.0, "fov": 38.0, "look_y": 1.4, "push": 0.05})
	shot("F1", _sr(14.25), "static", "locked-off wide profile: the staff planted, the vault, the kick (14.93), his flight into the wall rack (17.13)",
		{"pos": (T5 + A_SLAM) * 0.5 + Vector3(-DIR_K.z, 0.0, DIR_K.x) * -4.4 + Vector3(0.0, 1.55, 0.0),
		"look": (T5 + A_SLAM) * 0.5 + Vector3(0.0, 1.3, 0.0), "fov": 46.0, "hand": 0.0, "subj": ["hero", "za"]})
	shot("S4", _sr(17.85), "dolly", "slow motion: he slides down the dead rack to sit, the hilt still in his hand",
		{"from": ZA_END + Vector3(2.4, 1.3, 1.1), "to": ZA_END + Vector3(2.0, 1.05, 0.9), "look_from": ZA_END + Vector3(0.0, 1.2, 0.0),
		"look_to": ZA_END + Vector3(0.0, 0.85, 0.0), "fov": 46.0, "hand": 0.35, "subj": ["za"]})
	shot("W1", _sr(SWELL_END), "dolly", "tail wide: the wreck of the server room, the sheep quits from the floor",
		{"from": Vector3(0.2, 1.9, 1.4), "to": Vector3(0.0, 1.8, 1.1), "look_from": Vector3(-2.4, 0.8, -1.6),
		"look_to": Vector3(-2.6, 0.8, -1.7), "fov": 52.0, "hand": 0.4, "subj": ["sheep", "hero"]})
	shot("Z1", _sr(20.9), "dolly", "last: on Za Mẫn slumped against the dead rack, hugging the hilt",
		{"from": ZA_END + Vector3(2.4, 1.05, 0.5), "to": ZA_END + Vector3(1.8, 0.95, 0.35), "look_from": ZA_END + Vector3(0.0, 0.75, 0.0),
		"look_to": ZA_END + Vector3(0.0, 0.7, 0.0), "fov": 44.0, "hand": 0.35, "subj": ["za"]})
	punch(x1, "medium")
	punch(x2, "light")


## The middle of the bent blade in Za Mẫn's hand at the start (KAT_REST: forward and down from the right hand).
func _glint() -> Vector3:
	var f: Vector3 = _fwd(CineTimeline.face(A0, P0))
	return A0 + f * 0.72 + Vector3(-f.z, 0.0, f.x) * 0.17 + Vector3(0.0, 0.75, 0.0)


func _fx_sfx() -> void:
	sfx_at(0.05, "fire_crackle", -12.0)
	fx_at(_sr(R_GLINT), "flash", _glint(), {"power": 0.25})
	sfx_at(_sr(R_GLINT), "sword_clang", -18.0)
	sfx_at(s_pick, "whoosh_down", -8.0)
	sfx_at("H1", "impact_medium", -2.0)
	sfx_at("H1", "whoosh_down", -8.0)
	fx_at("H1", "dust", "sheep:Chest", {"power": 0.6})
	sfx_at(h1 + 0.45, "body_fall", -4.0)
	sfx_at(x1, "impact_medium", -4.0)
	fx_at(x1, "dust", "hero:Wrist.L", {"power": 0.3})
	sfx_at(s_wm, "whoosh_down", -6.0)
	sfx_at("H2", "whoosh_down", -4.0)
	sfx_at("H2", "impact_heavy", -6.0)
	sfx_at(h2 + 0.4, "body_fall", -1.0)
	fx_at(h2 + 0.4, "dust", "wolf:Hips", {"power": 0.9})
	sfx_at(s_par, "sword_clang", -2.0)
	fx_at(s_par, "sparks", "hero:Wrist.L", {"power": 0.8})
	sfx_at(x2, "impact_medium", -3.0)
	sfx_at(h3 - 0.15, "whoosh_down", -5.0)
	sfx_at("H3", "helmet_clonk", -1.0)
	sfx_at("H3", "impact_medium", -5.0)
	fx_at("H3", "sparks", "fox:Head", {"power": 0.4})
	sfx_at(h3 + 0.45, "body_fall", -2.0)
	sfx_at(a1 - 0.25, "whoosh_down", -3.0)
	sfx_at("A1", "sword_clang", -1.0)
	fx_at("A1", "sparks", "hero:Wrist.L", {"power": 0.7})
	sfx_at(s_bite, "sword_clang", 0.0)
	sfx_at(s_bite, "static_burst", -6.0)
	fx_at(s_bite, "sparks", "rack_a", {"power": 1.2})
	sfx_at(s_yank, "metal_creak", -6.0)
	sfx_at("H4", "blade_snap", 0.0)
	sfx_at("H4", "impact_heavy", -8.0)
	fx_at("H4", "sparks", BLADE_AT, {"power": 0.9})
	sfx_at(s_drop, "sword_clang", -10.0)
	sfx_at(s_take - 0.05, "whoosh_down", -4.0)
	sfx_at(s_take + 0.7, "body_fall", -8.0)   # the staff topples to the floor
	sfx_at("H5", "impact_heavy", -2.0)
	fx_at("H5", "dust", "za:Chest", {"power": 0.9})
	sfx_at(sc, "impact_heavy", 0.0)
	sfx_at(sc, "static_burst", -2.0)
	sfx_at(sc + 0.05, "glass_crack", -6.0)
	fx_at(sc, "sparks", "rack_x", {"power": 1.4})
	fx_at(sc, "flash", "rack_x", {"power": 0.8})
	fx_at(sc, "debris", "rack_x", {"power": 0.6, "dir": -DIR_K + Vector3(0.0, 0.8, 0.0)})
	sfx_at(s_sit, "body_fall", -2.0)
	sfx_at(_sr(20.3), "groan", -6.0)


func _subs() -> void:
	sub(0.35, 1.8, "za", "Đội bảo vệ, xử lý ticket này!")
	sub(19.6, 0.9, "sheep", "Nghỉ việc!")
	sub(20.9, 1.5, "hero", "...Bảo hành bảy ngày hả?")
