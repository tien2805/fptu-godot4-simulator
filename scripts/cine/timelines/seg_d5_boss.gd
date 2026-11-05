# File: res://scripts/cine/timelines/seg_d5_boss.gd
# seg_d5_boss (24.630 s, spec C-D8 beat 9 / C-D9; reworked by plan 2026-11-05-w6-fights: its own choreography, cameras and
# signature moves, every hit on an accent of the owner's cut of "The Good Life", see the music note below). The burning
# server room under The Beverly in red emergency light: the protagonist against Lê Minh Za Mẫn, his katana "bought online"
# (bent from the first frame), and his three masked guards, with a Vovinam staff snatched off a crate.
#   0.0  standoff: "Đội bảo vệ, xử lý ticket này!"; 1.83 the protagonist snatches the staff off a crate behind him
#   2.91 H1  a staff thrust into the sheep-masked guard's stomach (slow motion)                      sits down hard
#   3.82     the wolf-masked guard's straight right on the protagonist's jaw (normal speed, punch-in)
#   6.19 H2  his second right sails over the crouching protagonist: the low sweep takes his legs, he goes horizontal and
#            lands flat on his back (slow motion)
#   7.29     Za Mẫn's overhead katana cut rings off the staff held up across (sparks)
#   8.38     the fox-masked guard's right in the protagonist's back (normal speed, punch-in)
#   9.77 H3  without a look, a spin: the end of the staff across the fox's mask (slow motion)        flat on his back
#  11.65 A1  slow-motion accent: Za Mẫn's flat cut over the ducking protagonist bites into a server rack (12.03, sparks)
#  12.74 H4  he wrenches it free and blocks high: the staff comes down and snaps the bent katana at mid-blade, the blade
#            spins away (slow motion); he staggers back and stares at the stub
#  14.1      the protagonist turns his back, jogs off for a run-up, turns; 15.55 sprints in with the staff
#  17.13 H5  finisher: the pole-vault flying kick (the staff planted, both feet off the ground) into his chest; he flies back
#            into his own server rack (19.29, sparks, its lights die) and slides down to sit, the hilt still in his hand
#  21.63-24.63 tail at 1x: the sheep quits ("Nghỉ việc!") and runs out of the doorway; the protagonist, winded, looks at
#            the hilt: "...Bảo hành bảy ngày hả?"
# Music: the owner's "The Good Life" re-cut from 24.00 s of the original (W6); every hit sits on an accent of it within
# 0.1 s, the crash on one of the cut's loudest (19.29). No gore: sparks and dust. Contacts are measured on every tier by
# tests/test_cine_d5_boss.gd (tests/support/cine_brawl.gd); the staff and the katana are held props whose angle is keyed
# here (_track), the staff and katana moves are code poses on every tier.
# Story time runs slow inside the ramps, so every key and cue is anchored on a real time through _sr() or on a hit's story
# time, and a move never starts after the start of a strike it would cut (a later move overrides a strike).
# Stage: CineTimeline.phase_c_stage("server"), the carried server room (the doorway at EXIT.x), 14 x 10 m box.
# Stage frame: X right, -Z forward (the back wall with the doorway), ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LENGTH: float = 24.63
const TAIL: float = 3.0
## Real times of the beats (accents of the music cut).
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
const R_RUN: float = 15.55
const R_H5: float = 17.13
const R_CRASH: float = 19.29
const R_SIT: float = 20.38
const SWELL_END: float = 21.63

## Katana bend (deg): visibly "bought online" from the first frame.
const BEND: float = 22.0
## The katana held across over his head for the block (blade toward his left).
const BLOCK_ROT := Vector3(0.0, 90.0, 0.0)
## The katana's rest angle in his hand (actor frame): forward and down.
const KAT_REST := Vector3(-35.0, 0.0, 0.0)
const KAT_FLAT := Vector3(18.0, 0.0, 0.0)   # the flat cut, up a little: the bent tip droops 22 deg
const KAT_OFF := Vector3(0.0, 0.0, -0.02)
const KAT_PARRY := Vector3(11.0, 0.0, 0.0)   # the bent tip droops 22 deg
## The katana snaps (bent -> stub, the blade flies) this long after H4 in story time: the heavy freeze holds the impact.
const SNAP: float = 0.01
## The snapped blade starts at the katana's mid-blade at H4, in Za Mẫn's frame from his feet (A_A1, facing the
## protagonist); measured by tests/test_cine_d5_boss.gd (0.15 m).
const BLADE_FROM := Vector3(-0.1, 1.56, -0.3)
## The staff in both hands (actor frame): along the body (pointing forward), across it (centred: the grip sits 0.4 m off
## the staff's middle).
const ST_ALONG := Vector3.ZERO
const ST_ACROSS := Vector3(0.0, 90.0, 0.0)
const OFF_ACROSS := Vector3(0.4, 0.05, -0.12)
const OFF_CHOKE := Vector3(0.0, 0.0, 0.3)   # the grip slid up for the sweep (0.95 m of staff in front of the hands)
## The vault: the staff's tip planted ahead and to the left of the take-off (actor frame), the held staff's angle there.
const ST_PLANT := Vector3(-69.0, 45.0, 0.0)
const OFF_PLANT := Vector3(-0.035, -0.13, -0.035)
const TIP_PLANT := Vector3(-0.35, 0.0, -0.7)
const DT_TRACK: float = 0.03

# props
const DESK := Vector3(4.4, 0.0, 0.9)            # set dressing by the right wall, yaw 90
const EXIT := Vector3(-3.6, 0.0, -4.6)

# spacing (m, root to root); tuned against tests/test_cine_d5_boss.gd (surface gaps on every tier)
const D_H1: float = 1.88            # the thrust (the staff's tip in his stomach)
const D_X1: float = 1.11            # the wolf's straight right
const D_SW: float = 1.25            # the low sweep (staff choked, pitched down)
const D_P: float = 1.2              # Za Mẫn's overhead cut onto the raised staff
const D_X2: float = 1.0             # the fox's right in his back
const D_A1: float = 1.3             # Za Mẫn's flat cut over the ducking protagonist
const D_H4: float = 0.63           # the staff down on the blocking katana
const D_H5: float = 1.1             # the flying kick
const STAGGER: float = 0.6          # Za Mẫn staggers back after the snap
const FLIGHT: float = 1.7           # his flight back to his rack's face
const RUN_UP: float = 2.4           # the protagonist's sprint to the take-off
const AIR: float = 0.6              # take-off to the kick

# positions
const P0 := Vector3(-0.3, 0.0, 1.25)
const S0 := Vector3(-2.7, 0.0, 0.1)
const W0 := Vector3(2.3, 0.0, -0.4)
const A0 := Vector3(0.6, 0.0, -1.55)
const F0 := Vector3(-3.2, 0.0, 3.6)
const DIR_W := Vector3(0.845, 0.0, -0.534)
const DIR_Z := Vector3(0.243, 0.0, -0.97)       # from the protagonist toward Za Mẫn (and on to his racks)

var DIR_S: Vector3
var y_pick: float    # the protagonist turned round to the staff lying across a crate behind his right shoulder
var P_PICK: Vector3
var STAFF_ON: Vector3   # the staff on the crate (its grip, where his hands close on it)
var CRATE: Vector3
var S_H1: Vector3
var S_SIT: Vector3
var W_A: Vector3
var W_LIE: Vector3
var P1: Vector3      # the protagonist after the wolf's right (the sweep's distance)
var A_P: Vector3     # Za Mẫn's overhead cut
var A_PB: Vector3    # pushed back off the staff
var F_A: Vector3     # the fox in the protagonist's back
var F_LIE: Vector3
var P1B: Vector3     # the protagonist knocked a step forward by the fox
var P2: Vector3      # a step in toward Za Mẫn after H3
var A_A1: Vector3
var RACK_A: Vector3  # the rack the flat cut bites into
var y_rack_a: float
var P_H4: Vector3
var P_RUN: Vector3
var A_K: Vector3     # Za Mẫn at the kick
var H_K: Vector3     # the protagonist at the kick
var T5: Vector3      # the take-off
var L5: Vector3      # the landing
var PLANT: Vector3   # the staff's tip on the floor
var FACE: Vector3    # the crash rack's face where his back meets it
var A_SLAM: Vector3
var A_SIT: Vector3
var RACK_X: Vector3
var y_rack_x: float
var y_z: float       # the protagonist facing Za Mẫn
var y_h3: float      # the protagonist's yaw at H3 (the staff's left end on the fox)
var y_zh: float      # Za Mẫn facing the protagonist at A1

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
var s_run: float
var s_take: float
var sc: float
var slam_s: float
var s_sit: float
var s_up: float
var s_gone: float


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
	s_run = _sr(R_RUN)
	s_take = h5 - 0.4            # the flying kick leaves the ground (its air window opens at 0.15 of its 1.0 s)
	sc = _sr(R_CRASH)
	slam_s = sc
	s_sit = _sr(R_SIT)
	s_up = _sr(21.3)
	s_gone = _sr(23.95)
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
	hit("A1", 9.6, "accent", "slow-motion accent: Za Mẫn's flat katana cut over the ducking protagonist bites into a rack", {"r": R_A1})
	hit("H4", 10.6, "heavy", "the staff comes down on the blocking katana: it snaps at mid-blade", {"r": R_H4, "att": "hero:staff", "tgt": "za:katana"})
	hit("H5", 12.9, "finisher", "the pole-vault flying kick: Za Mẫn into his own server rack (swell)",
		{"r": R_H5, "hq": SWELL_END - R_H5 - 0.55, "att": "hero:feet", "tgt": "za:torso"})


func _layout() -> void:
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
	P2 = P1B + DIR_Z * 0.3
	A_A1 = P2 + DIR_Z * D_A1
	y_zh = CineTimeline.face(A_A1, P2)
	# the flat cut ends 100 deg to his right, the blade into the rack there
	RACK_A = A_A1 + _fwd(y_zh - 100.0) * 1.62
	y_rack_a = CineTimeline.face(RACK_A, A_A1)
	P_H4 = A_A1 - DIR_Z * D_H4
	A_K = A_A1 + DIR_Z * STAGGER
	H_K = A_K - DIR_Z * D_H5
	T5 = H_K - DIR_Z * AIR
	L5 = H_K + DIR_Z * 0.2
	P_RUN = T5 - DIR_Z * RUN_UP
	PLANT = T5 + Basis(Vector3.UP, deg_to_rad(y_z)) * TIP_PLANT
	PLANT.y = 0.0
	FACE = A_K + DIR_Z * FLIGHT
	A_SLAM = FACE - DIR_Z * 0.14
	A_SIT = FACE - DIR_Z * 0.55
	RACK_X = FACE + DIR_Z * 0.5
	y_rack_x = CineTimeline.face(RACK_X, RACK_X - DIR_Z)


func _props() -> void:
	prop("room", "server_room", Vector3.ZERO, 0.0, {"width": 13.0, "depth": 9.3, "z1": 4.5, "door_x": EXIT.x})
	prop("desk", "desk", DESK, 90.0, {"set": true})
	prop("crate_pick", "small_crate", CRATE, y_pick)
	prop("staff_crate", "staff", STAFF_ON, y_pick + 90.0, {"hide_at": s_pick})
	# Za Mẫn's own racks behind him: the middle one takes him (sc), its lights die (swapped for a dead one)
	var rx: Vector3 = Vector3(-DIR_Z.z, 0.0, DIR_Z.x)
	prop("rack_x", "server_rack", RACK_X, y_rack_x, {"seed": 1, "hide_at": sc})
	prop("rack_x_dead", "server_rack", RACK_X, y_rack_x, {"seed": 1, "dead": true, "show_at": sc})
	prop("rack_xl", "server_rack", RACK_X - rx * 0.62, y_rack_x, {"seed": 2})
	prop("rack_xr", "server_rack", RACK_X + rx * 0.62, y_rack_x, {"seed": 0})
	prop("rack_a", "server_rack", RACK_A, y_rack_a, {"seed": 2})
	# set dressing round the fight (the room's own racks along the walls, small fires)
	prop("rack_l0", "server_rack", Vector3(-5.4, 0.0, 0.6), -90.0, {"set": true})
	prop("rack_l1", "server_rack", Vector3(-5.4, 0.0, 1.75), -90.0, {"set": true})
	prop("rack_r0", "server_rack", Vector3(5.4, 0.0, -1.6), 90.0, {"set": true})
	prop("rack_r1", "server_rack", Vector3(5.4, 0.0, 2.2), 90.0, {"set": true})
	prop("fire0", "fire", Vector3(-5.0, 0.0, 3.4), 0.0, {"anim": true, "spread": 0.8})
	prop("fire1", "fire", Vector3(5.0, 0.0, 3.6), 0.0, {"anim": true, "spread": 0.7})
	prop("fire2", "fire", Vector3(3.0, 0.0, -4.2), 0.0, {"anim": true, "spread": 0.9})
	# the snapped-off blade: from mid-blade at H4, spinning away to land clear of everyone
	var from: Vector3 = A_A1 + Basis(Vector3.UP, deg_to_rad(y_zh)) * BLADE_FROM
	var land: Vector3 = A_A1 + _fwd(y_zh - 60.0) * 1.6 + Vector3(0.0, 0.02, 0.0)
	prop("blade", "katana_blade", land, 40.0, {"show_at": h4 + SNAP, "arc": 0.6,
		"path": [[h4 + SNAP, from, Vector3.ZERO], [h4 + 0.9, land, Vector3(0.0, 40.0, 1080.0)]]})
	# the vault: the staff's tip planted at the take-off; it stands up as he goes over, then topples to his left
	var bz: Basis = Basis(Vector3.UP, deg_to_rad(y_z))
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


## A held prop whose angle / offset in the actor's frame is keyed: keys [[s, rot, offset], ...] ascending; held as one
## hold while a key repeats the previous one, else as DT_TRACK-long holds smoothstepped between the keys.
func _track(id: String, kind: String, s0: float, s1: float, keys: Array, base: Dictionary) -> void:
	var cur: float = s0
	for i: int in keys.size():
		var k: Array = keys[i]
		var ks: float = clampf(float(k[0]), s0, s1)
		if i == 0:
			if ks > cur:
				_hold_at(id, kind, cur, ks, k[1], k[2], base)
			cur = ks
			continue
		var kp: Array = keys[i - 1]
		if ks <= cur:
			continue
		if (kp[1] as Vector3).is_equal_approx(k[1]) and (kp[2] as Vector3).is_equal_approx(k[2]):
			_hold_at(id, kind, cur, ks, k[1], k[2], base)
		else:
			var steps: int = maxi(1, int(ceil((ks - cur) / DT_TRACK)))
			var dt: float = (ks - cur) / float(steps)
			for j: int in steps:
				var u: float = smoothstep(0.0, 1.0, (float(j) + 0.5) / float(steps))
				_hold_at(id, kind, cur + dt * j, cur + dt * (j + 1), (kp[1] as Vector3).lerp(k[1], u), (kp[2] as Vector3).lerp(k[2], u), base)
		cur = ks
	if cur < s1:
		var kl: Array = keys[keys.size() - 1]
		_hold_at(id, kind, cur, s1, kl[1], kl[2], base)


func _hold_at(id: String, kind: String, s0: float, s1: float, rot: Vector3, off: Vector3, base: Dictionary) -> void:
	var o: Dictionary = base.duplicate()
	o["rot"] = rot
	o["offset"] = off
	hold(id, s0, s1, kind, o)


func _hero() -> void:
	var y0: float = CineTimeline.face(P0, A0)
	var y_s: float = CineTimeline.face(P0, S_H1)
	var y_w: float = CineTimeline.face(P0, W_A)
	var y_w1: float = CineTimeline.face(P1, W_A)
	var y_back: float = CineTimeline.face(P_H4, P_RUN)
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
	# 3.82 the wolf's right on the jaw, a step back to the sweep's distance
	key("hero", h1 + 0.08, P0, y_s)
	key("hero", x1 - 0.12, P0, y_w, {"mode": "out"})
	look("hero", h1 + 0.05, h2 + 0.3, "wolf")
	strike("hero", x1, "hit_head")
	expr("hero", x1, "pain")
	move("hero", x1 + 0.5, "staff_guard", {"fade": 0.15})
	key("hero", x1 + 0.05, P0, y_w)
	key("hero", x1 + 0.45, P1, y_w1, {"mode": "out"})
	expr("hero", x1 + 0.6, "angry")
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
	# back round to Za Mẫn, a step in; 11.65 ducks the flat cut; 12.74 the staff comes down on his block
	move("hero", h3 + 0.36, "staff_guard", {"fade": 0.15})
	key("hero", h3 + 0.36, P1B, y_h3 + 35.0)
	key("hero", a1 - 0.34, P2, y_z, {"mode": "out"})
	look("hero", h3 + 0.4, h4 + 0.45, "za")
	strike("hero", "A1", "staff_sweep", {"dur": 0.9})   # its crouch (0.3-0.7) ducks the cut
	key("hero", h4 - 0.2, P2, y_z)
	key("hero", h4 - 0.04, P_H4, y_z, {"mode": "out"})
	strike("hero", "H4", "staff_smash", {"reach": 0.0})
	expr("hero", h4, "angry")
	move("hero", h4 + 0.015, "staff_guard", {"fade": 0.1})   # no follow-through into his arms
	# turns his back on him, jogs off for a run-up, turns; 15.55 the sprint, the staff planted, the vault, the kick (17.13)
	key("hero", h4, P_H4, y_z)
	key("hero", h4 + 0.3, P_H4 - DIR_Z * 0.12, y_z, {"mode": "out"})
	key("hero", h4 + 0.45, P_H4 - DIR_Z * 0.12, y_z)
	key("hero", h4 + 0.65, P_H4 - DIR_Z * 0.12, y_back, {"mode": "out"})
	move("hero", h4 + 0.62, "jog", {"fade": 0.15})
	key("hero", s_run - 0.5, P_RUN, y_back)
	move("hero", s_run - 0.5, "staff_guard", {"fade": 0.15})
	key("hero", s_run - 0.15, P_RUN, y_z, {"mode": "out"})
	look("hero", s_run - 0.3, story_end, "za")
	key("hero", s_run, P_RUN, y_z)
	move("hero", s_run, "staff_run", {"fade": 0.1})
	key("hero", s_take, T5, y_z, {"mode": "in"})
	strike("hero", "H5", "flying_kick", {"reach": {"mixamo": Vector2(-0.05, 0.0), "ual": 0.09, "native": 0.09, "code": 0.09}})
	key("hero", h5, H_K, y_z, {"mode": "linear"})
	key("hero", h5 + 0.45, L5, y_z, {"mode": "out"})
	move("hero", h5 + 0.5, "fight_idle", {"fade": 0.3})
	move("hero", _sr(22.4), "winded", {"fade": 0.3})
	expr("hero", _sr(22.4), "happy")
	# the staff: off the crate across his hands, twirled along for the thrust, choked and pitched down for the sweep,
	# across for the block / the spin / the smash, along again for the run, its tip down to the floor at the take-off
	_track("hero", "staff", s_pick, s_take, [
		[s_pick, ST_ACROSS, Vector3.ZERO], [_sr(2.0), ST_ACROSS, Vector3.ZERO], [_sr(2.4), ST_ALONG, Vector3.ZERO],
		[h1 - 0.25, ST_ALONG, Vector3.ZERO], [h1 - 0.1, Vector3(-6.0, 0.0, 0.0), Vector3.ZERO],
		[h1 + 0.25, Vector3(-6.0, 0.0, 0.0), Vector3.ZERO], [h1 + 0.45, ST_ALONG, Vector3.ZERO],
		[h2 - 0.45, ST_ALONG, Vector3.ZERO], [h2 - 0.2, Vector3(-24.0, 0.0, 0.0), OFF_CHOKE],
		[h2 + 0.15, Vector3(-24.0, 0.0, 0.0), OFF_CHOKE], [s_par - 0.22, ST_ACROSS, OFF_ACROSS],
		[h4 + 0.3, ST_ACROSS, OFF_ACROSS], [h4 + 0.6, ST_ALONG, Vector3.ZERO],
		[s_run - 0.2, ST_ALONG, Vector3.ZERO], [s_run, Vector3(-10.0, 0.0, 0.0), Vector3.ZERO],
		[s_take - 0.12, Vector3(-10.0, 0.0, 0.0), Vector3.ZERO], [s_take, ST_PLANT, OFF_PLANT]],
		{"mid": "Wrist.L"})


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
	# 2.91 the staff in his stomach: back two steps, down hard on the floor, sits there winded
	strike("sheep", "H1", "hit_stomach")
	expr("sheep", h1, "pain")
	key("sheep", h1, S_H1, y_a)
	key("sheep", h1 + 0.4, S_SIT, y_a, {"mode": "out"})
	strike("sheep", h1 + 0.25, "slammed")
	move("sheep", h1 + 1.01, "slumped", {"fade": 0.15})
	fx_at(h1 + 0.6, "stars", "sheep", {"until": s_up})
	# the tail: quits on the spot ("Nghỉ việc!"), up and out of the doorway
	var wp1 := Vector3(-3.1, 0.0, -1.6)
	var wp2 := Vector3(-3.6, 0.0, -3.9)
	move("sheep", s_up, "get_up_sit")
	expr("sheep", s_up, "open")
	key("sheep", s_up, S_SIT, y_a)
	key("sheep", s_up + 1.0, S_SIT, y_a)
	key("sheep", s_up + 1.15, S_SIT, CineTimeline.face(S_SIT, wp1))
	move("sheep", s_up + 1.05, "sprint", {"fade": 0.15})
	key("sheep", s_up + 1.6, wp1, CineTimeline.face(S_SIT, wp1), {"mode": "linear"})
	key("sheep", s_up + 2.2, wp2, CineTimeline.face(wp1, wp2), {"mode": "linear"})
	key("sheep", s_gone, EXIT + Vector3(0.0, 0.0, -0.25), CineTimeline.face(wp2, EXIT), {"mode": "linear"})
	show("sheep", s_gone, false)


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
	key("za", 0.0, A0, y0)
	move("za", 0.0, "fight_idle")
	look("za", 0.0, story_end, "hero")
	move("za", 0.3, "point", {"fade": 0.15})
	move("za", _sr(1.9), "fight_idle", {"fade": 0.2})
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
	# 11.65 the flat cut over the ducking protagonist, his body turns through it left to right, the blade bites the rack
	key("za", a1 - 0.75, A_A1, y_zh)
	key("za", a1 - 0.42, A_A1, y_zh + 80.0, {"mode": "out"})
	key("za", a1, A_A1, y_zh, {"mode": "linear"})
	key("za", s_bite, A_A1, y_zh - 100.0, {"mode": "out"})
	strike("za", "A1", "katana_slash")
	expr("za", a1, "angry")
	# wrenches it out of the rack, round to the protagonist, 12.74 blocks high: the katana snaps; staggers back
	strike("za", s_yank, "yank", {"dur": 0.25})
	key("za", s_yank + 0.02, A_A1, y_zh - 100.0)
	key("za", h4 - 0.17, A_A1, y_zh, {"mode": "out"})
	strike("za", h4 + 0.1, "block_high", {"dur": 0.5})   # met at 0.25 of the block, the arms still coming up
	expr("za", h4, "pain")
	strike("za", h4 + 0.06, "hit_stomach")
	key("za", h4 + 0.01, A_A1, y_zh)
	key("za", h4 + 0.4, A_K, y_zh, {"mode": "out"})
	move("za", h4 + 0.65, "fight_idle", {"fade": 0.2})
	# stares at the stub, shakes his head; 17.13 the kick: flung back into his rack (19.29), slides down to sit
	move("za", _sr(14.4), "head_shake", {"fade": 0.15})
	expr("za", _sr(14.4), "open")
	move("za", _sr(15.0), "fight_idle", {"fade": 0.2})
	expr("za", _sr(15.9), "angry")
	key("za", h5 - 0.1, A_K, y_zh)
	strike("za", h5 + 0.15, "chair_smash", {"dur": 0.9})   # the stub up for an overhead cut: the kick lands first, in his open chest
	strike("za", "H5", "blown_back", {"fade": 0.06})
	expr("za", h5, "pain")
	key("za", h5, A_K, y_zh)
	key("za", h5 + 0.1, A_K + DIR_Z * 0.55, y_zh, {"mode": "linear"})   # blown clear of the kicking leg at once
	key("za", sc, A_SLAM, y_zh, {"mode": "out", "arc": 0.35})
	strike("za", sc, "slammed")
	key("za", sc + 0.06, A_SLAM - DIR_Z * 0.08, y_zh, {"mode": "out"})
	key("za", sc + 0.5, A_SIT, y_zh)
	move("za", sc + 0.76, "slumped", {"fade": 0.15})
	fx_at(s_sit, "stars", "za", {"until": story_end})
	# the bent katana in his hand, its angle keyed through the cuts and the block; the stub after H4
	_track("za", "katana", 0.0, h4 + SNAP, [
		[0.0, KAT_REST, KAT_OFF], [s_par - 0.28, KAT_REST, KAT_OFF], [s_par - 0.1, Vector3(110.0, 0.0, 0.0), KAT_OFF],
		[s_par, KAT_PARRY, KAT_OFF], [s_par + 0.2, Vector3(-20.0, 0.0, 0.0), KAT_OFF], [s_par + 0.5, KAT_REST, KAT_OFF],
		[a1 - 0.45, KAT_REST, KAT_OFF], [a1 - 0.3, KAT_FLAT, KAT_OFF], [s_yank, KAT_FLAT, KAT_OFF],
		[h4 - 0.12, BLOCK_ROT, KAT_OFF]], {"bend": BEND})
	# it snaps when the freeze frame on the impact lets go (the stub stays up in the block, then comes down)
	_track("za", "katana", h4 + SNAP, story_end, [[h4 + SNAP, BLOCK_ROT, KAT_OFF], [h4 + 0.3, BLOCK_ROT, KAT_OFF],
		[h4 + 0.55, KAT_REST, KAT_OFF], [h5 - 0.3, KAT_REST, KAT_OFF], [h5 - 0.05, Vector3(70.0, 0.0, 0.0), KAT_OFF],
		[h5 + 0.3, Vector3(70.0, 0.0, 0.0), KAT_OFF], [h5 + 0.8, KAT_REST, KAT_OFF]], {"broken": true})


func _shots() -> void:
	shot("K1", 0.0, "crane", "crane down the burning server room onto the standoff: Za Mẫn with a bent katana, three masked guards",
		{"from": Vector3(3.4, 4.2, 4.3), "to": Vector3(2.6, 2.1, 3.7), "look_from": Vector3(-0.2, 0.5, -0.4),
		"look_to": Vector3(-0.3, 1.1, -0.3), "fov": 50.0, "hand": 0.2})
	dutch_shot("D1", _sr(0.9), "za", {"roll": 14.0, "side_deg": 20.0, "dist": 2.6, "fov": 44.0})
	hero_shot("L1", _sr(1.45), "hero", {"side_deg": -35.0, "dist": 2.4, "fov": 52.0})
	shot("O1", _sr(2.4), "orbit", "slow-motion orbit: the staff thrust into the sheep's stomach (2.91)",
		{"center": (P0 + S_H1) * 0.5 + Vector3(0.0, 1.1, 0.0), "radius": 2.4, "deg_from": 150.0, "deg_to": 180.0, "height": 1.0,
		"fov": 44.0, "hand": 0.3})
	ots_shot("T1", _sr(3.45), "wolf", "hero", {"side": -1.0, "fov": 44.0, "look_y": 1.15, "back": 1.4})
	shot("S1", _sr(5.4), "static", "slow motion, low and side-on: the low sweep takes the wolf's legs (6.19)",
		{"pos": (P1 + W_A) * 0.5 + Vector3(DIR_W.z, 0.0, -DIR_W.x) * -2.8 + Vector3(0.0, 0.5, 0.0),
		"look": (P1 + W_A) * 0.5 + Vector3(0.0, 0.6, 0.0), "fov": 50.0, "hand": 0.3})
	two_shot("T2", _sr(6.95), "hero", "za", {"side": 1.0, "fov": 48.0, "look_y": 1.05, "height": 1.3, "dist": 3.6})
	shot("S2", _sr(8.05), "static", "slow motion, wide: the fox's right in his back, the blind spin, the staff across the fox's mask (9.77)",
		{"pos": P1B + _fwd(y_z + 60.0) * 3.4 + Vector3(0.0, 1.3, 0.0), "look": (P1B + F_A) * 0.5 + Vector3(0.0, 1.2, 0.0),
		"fov": 50.0, "hand": 0.3})
	push_in("P1", _sr(10.35), "za", {"from": 4.0, "to": 2.6, "side_deg": -30.0, "fov": 42.0})
	shot("O2", _sr(11.1), "orbit", "low slow orbit: the flat cut over the ducking protagonist (11.65) bites into a rack (12.03)",
		{"center": (A_A1 + P2) * 0.5 + Vector3(0.0, 1.1, 0.0), "radius": 3.1, "deg_from": 200.0, "deg_to": 230.0, "height": 0.7,
		"fov": 48.0, "hand": 0.3})
	shot("S3", _sr(12.3), "static", "slow motion, low: the staff comes down, the bent katana snaps (12.74)",
		{"pos": (A_A1 + P_H4) * 0.5 + _fwd(y_z + 90.0) * 2.6 + Vector3(0.0, 0.6, 0.0), "look": (A_A1 + P_H4) * 0.5 + Vector3(0.0, 1.6, 0.0),
		"fov": 50.0, "hand": 0.3})
	dutch_shot("D2", _sr(13.9), "za", {"roll": -12.0, "side_deg": -20.0, "dist": 2.2, "fov": 44.0})
	shot("K2", _sr(15.3), "dolly", "tracking from the side: the sprint, the staff planted (16.32), the vault",
		{"from": P_RUN + _fwd(y_z + 90.0) * 2.8 + Vector3(0.0, 1.0, 0.0), "to": T5 + _fwd(y_z + 90.0) * 2.6 + Vector3(0.0, 1.1, 0.0),
		"look_from": P_RUN + Vector3(0.0, 1.0, 0.0), "look_to": (T5 + A_K) * 0.5 + Vector3(0.0, 1.2, 0.0), "fov": 48.0, "hand": 0.3})
	shot("O3", _sr(16.75), "orbit", "low slow orbit: the flying kick lands (17.13)",
		{"center": (H_K + A_K) * 0.5 + Vector3(0.0, 1.2, 0.0), "radius": 3.0, "deg_from": 100.0, "deg_to": 130.0, "height": 0.6,
		"fov": 46.0, "hand": 0.3})
	shot("S4", _sr(18.4), "static", "slow motion at his racks: back first into the middle one (19.29), sparks, its lights die",
		{"pos": FACE - DIR_Z * 2.6 + _fwd(y_z - 90.0) * 1.8 + Vector3(0.0, 1.2, 0.0), "look": FACE - DIR_Z * 0.6 + Vector3(0.0, 1.0, 0.0),
		"fov": 50.0, "hand": 0.4})
	shot("W1", _sr(SWELL_END), "dolly", "tail wide: the wreck of the server room, the sheep quits and runs for the doorway",
		{"from": Vector3(3.4, 2.3, 4.2), "to": Vector3(3.0, 2.1, 3.9), "look_from": Vector3(-0.6, 0.6, -0.8),
		"look_to": Vector3(-0.8, 0.6, -0.9), "fov": 56.0, "hand": 0.4})
	hero_shot("L2", _sr(22.9), "hero", {"side_deg": 30.0, "dist": 2.6, "fov": 50.0})
	punch(x1, "medium")
	punch(x2, "light")


func _fx_sfx() -> void:
	sfx_at(0.2, "fire_crackle", -12.0)
	sfx_at(s_pick, "whoosh_down", -8.0)
	sfx_at("H1", "impact_medium", -2.0)
	sfx_at("H1", "whoosh_down", -8.0)
	fx_at("H1", "dust", "sheep:Chest", {"power": 0.6})
	sfx_at(h1 + 0.45, "body_fall", -4.0)
	sfx_at(x1, "impact_medium", -3.0)
	fx_at(x1, "sparks", "hero:Head", {"power": 0.3})
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
	sfx_at(s_bite, "sword_clang", 0.0)
	sfx_at(s_bite, "static_burst", -6.0)
	fx_at(s_bite, "sparks", "rack_a", {"power": 1.2})
	sfx_at(s_yank, "metal_creak", -6.0)
	sfx_at("H4", "blade_snap", 0.0)
	sfx_at("H4", "impact_heavy", -8.0)
	fx_at("H4", "sparks", "za:Wrist.R", {"power": 0.9})
	sfx_at(h4 + 0.05, "sword_clang", -4.0)
	sfx_at(h4 + 0.9, "sword_clang", -12.0)
	sfx_at(s_run, "whoosh_down", -8.0)
	sfx_at(s_take - 0.05, "whoosh_down", -4.0)
	sfx_at(s_take + 0.7, "body_fall", -8.0)   # the staff topples to the floor
	sfx_at("H5", "impact_heavy", -2.0)
	fx_at("H5", "dust", "za:Chest", {"power": 0.9})
	sfx_at(sc, "impact_heavy", 0.0)
	sfx_at(sc, "static_burst", -2.0)
	sfx_at(sc + 0.05, "glass_crack", -6.0)
	fx_at(sc, "sparks", "rack_x", {"power": 1.4})
	fx_at(sc, "flash", "rack_x", {"power": 0.8})
	fx_at(sc, "debris", "rack_x", {"power": 0.6, "dir": -DIR_Z + Vector3(0.0, 0.8, 0.0)})
	sfx_at(s_sit, "body_fall", -2.0)
	sfx_at(_sr(22.6), "groan", -6.0)


func _subs() -> void:
	sub(0.35, 1.8, "za", "Đội bảo vệ, xử lý ticket này!")
	sub(21.85, 0.9, "sheep", "Nghỉ việc!")
	sub(23.05, 1.5, "hero", "...Bảo hành bảy ngày hả?")
