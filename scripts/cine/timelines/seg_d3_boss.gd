# File: res://scripts/cine/timelines/seg_d3_boss.gd
# seg_d3_boss (21.100 s, spec C-D7 beat 9 / C-D9; reworked by plan 2026-11-05-w6-fights: its own choreography, cameras and
# signature, every hit on an accent of the owner's cut of "Straighten Up and Fly Right", see the music note below). Night
# in the container yard after the forklift boss: the forklift lies on its side, Alexander picks himself up beside it and
# sends his three masked guards in. The yard's crane hook hangs on its cable in the middle of it all: the protagonist
# turns it into a wrecking ball (its swing is one pendulum, see _hook_theta: +Z passes on H2 and H5; after the snag the
# shortened cable whips it up to the top of its swing, where Alexander's collar slips).
#   0.0  standoff: "Bắt nó lại cho ta!"; the fox-masked guard walks in
#   2.83 H1  the protagonist shoves the hanging hook: it swings into the fox's mask (slow motion, clonk)   flat on his back
#   4.22     the wolf-masked guard's straight right on the jaw, guard still down (normal speed, punch-in)
#   5.31     the protagonist grabs his collar: "stay right there" ...
#   5.90 H2  ... and steps aside as the hook swings back into the back of the wolf's head (slow motion)  a somersault
#   7.54     the sheep-masked guard's jab catches him admiring his work (normal speed, punch-in)
#   8.23 H3  a shove slams the sheep back into the toppled forklift's roof guard (slow motion, heavy)    slides down, sits
#   9.42     Alexander lowers his gold sunglasses: "Ta học võ trên mạng đó!"; he steps in behind the passing hook
#  10.81     his uppercut lands (normal speed, punch-in); he laughs
#  12.08 A1  slow-motion accent: his flashy hurricane kick (while the hook dwells at its far end), the protagonist ducks
#  13.54 H5  finisher: he lands, steps in for more and the returning crane hook snags his collar from behind; the crane jerks
#            the cable up and the hook swings him high over the yard, kicking (crane-high shot down); at the top of the swing
#            the collar slips (15.02) and he drops onto the stack of smart-glasses crates (16.87): they burst; his party horn
#            pops out and toots on the ground (17.40)
#  18.1-21.1 tail at 1x: "Chạy!" (the sheep runs for it), the protagonist winded: "Còn ai tên dài nữa không?"
# Music: the owner's "Straighten Up and Fly Right" re-cut from 9.92 s of the original (W6); every hit, every hit taken and
# the crash sit on an accent of it within 0.1 s, the finisher on the cut's strongest (13.54). No gore: clonks, stars, a
# collar, crates. Contacts are measured on every tier by tests/test_cine_d3_boss.gd (tests/support/cine_brawl.gd).
# Stage: CineTimeline.phase_c_stage("yard") (14 x 12), shared with cine_d3_mannequins / cine_d3 (the forklift lies where
# cine_d3 has it; the containers are set dressing); the fight keeps to the 14 x 10 box (|x| <= 7, |z| <= 5).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LENGTH: float = 21.1
const TAIL: float = 3.0
## Real times of the beats (accents of the music cut).
const R_H1: float = 2.83
const R_X1: float = 4.22
const R_YK: float = 5.31
const R_H2: float = 5.90
const R_X2: float = 7.54
const R_SH: float = 7.96
const R_H3: float = 8.23
const R_SD: float = 9.42
const R_X3: float = 10.81
const R_LAUGH: float = 11.12
const R_A1: float = 12.08
const R_H5: float = 13.54
const R_REL: float = 15.02
const R_CRASH: float = 16.87
const R_HORN: float = 17.40
const SWELL_END: float = 18.1

# the crane hook: a pendulum in the plane x = HOOK_R.x swinging along Z (block centre at rest HOOK_R, cable HOOK_L)
const HOOK_R := Vector3(-0.5, 1.82, 0.6)
const HOOK_L: float = 5.75
const HOOK_A: float = 40.0          # amplitude (deg): a heavy block, the guards hardly slow it
const HOOK_A5: float = 30.0         # after the snag: the whip up to the top of the swing (reached as the collar slips)
const HOOK_W4: float = 1.46         # the phase rate (rad / s) after the release: the shortened cable's own swing
const TH_H1: float = -10.0          # its angle (deg) at each hit: going -Z into the fox, +Z into the wolf and Alexander
const TH_H2: float = -2.0
const TH_H5: float = -3.0
const HOIST: float = 1.15           # the crane jerks the cable up this much after the snag
const J_BASE := Vector3(0.0, -0.43, 0.07)   # the J hook's bottom bar in the prop frame (CineFX._build_crane_hook)
## Alexander hangs from the hook by his collar: the collar (back of the neck) relative to his root, facing +Z.
const COLLAR_Y: float = 1.445
const COLLAR_BACK: float = 0.13

# props
const FORKLIFT := Vector3(3.6, 0.6, -1.3)
const FORKLIFT_ROT := Vector3(0.0, 35.0, 88.0)   # on its side (as cine_d3): the roof guard faces the fight, a steel wall
const CRATES := Vector3(-0.5, 0.0, 3.5)           # the stack of smart-glasses crates (yaw 90: along Z), under the swing's top

# spacing (m, root to root); tuned against tests/test_cine_d3_boss.gd (surface gaps on every tier)
const D_X1: float = 1.08            # the wolf's straight right
const D_YK: float = 0.75            # the collar grab
const D_X2: float = 1.0             # the sheep's jab
const D_X3: float = 1.12            # Alexander's uppercut

# positions
const P0 := Vector3(-0.5, 0.0, 1.12)     # behind the hanging hook, facing it
const F0 := Vector3(-0.5, 0.0, -2.7)
const F_LIE := Vector3(-0.5, 0.0, -2.3)
const W0 := Vector3(-2.6, 0.0, -0.4)
const W_A := Vector3(-0.5, 0.0, 0.63)    # where the hook comes back to the back of his head
const DIR_W := Vector3(0.7071, 0.0, 0.7071)   # the wolf faces the protagonist along it (and somersaults along it)
const S0 := Vector3(1.5, 0.0, 1.1)
const A0 := Vector3(0.5, 0.0, -1.15)     # Alexander on the ground by the forklift's forks
const A_APP := Vector3(0.25, 0.0, 0.12)  # beside the hook's path while it swings through toward -Z (10.3)
const A_X3 := Vector3(-0.25, 0.0, 0.12)  # in behind it: his uppercut, then the hurricane kick from here
const A_K2 := Vector3(-0.5, 0.0, 0.25)   # where the spinning kick lands him (in the hook's path, his back to it)
const P_A1 := Vector3(-0.45, 0.0, 1.85)  # the protagonist ducks the kick here and waits for the hook
const P5D := Vector3(-1.35, 0.0, 1.6)    # the protagonist's sidestep out of the hook's way at H5

var N: Vector3        # the toppled forklift's roof guard: outward normal (horizontal)
var F1: Vector3
var W_LIE: Vector3
var P1: Vector3
var P_YK: Vector3
var P_DG: Vector3
var S_SLAM: Vector3
var S_SIT: Vector3
var S_A: Vector3
var P2: Vector3
var S_RUN: Vector3
var S_EXIT: Vector3
var P_X3: Vector3
var A_H5: Vector3
var LAND: Vector3    # Alexander on top of the crate stack (sc)
var A_FLOOR: Vector3

# story times
var h1: float
var h2: float
var h3: float
var a1: float
var h5: float
var x1: float
var x2: float
var x3: float
var s_sh: float      # the protagonist's shove on the hook
var s_yk: float      # the collar grab
var s_shv: float     # the shove on the sheep
var slam_s: float
var s_sd: float      # shades down
var s_hoist: float   # the crane's jerk ends
var s_rel: float     # the collar slips
var sc: float        # onto the crates
var s_horn: float
var s_gone: float    # the sheep out of the yard
var w1: float        # the hook's phase rates (rad / story s) before and after H2, and from the snag to the release
var w2: float
var w3: float


func _sr(r: float) -> float:
	return clock.story_at(r)


static func _d(a: Vector3, b: Vector3) -> Vector3:
	var v: Vector3 = b - a
	v.y = 0.0
	return v.normalized()


func build() -> void:
	slot = "seg_d3_boss"
	length = LENGTH
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5
	stage = CineTimeline.phase_c_stage("yard")
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
	h5 = story_time("H5")
	x1 = _sr(R_X1)
	x2 = _sr(R_X2)
	x3 = _sr(R_X3)
	s_yk = _sr(R_YK)
	s_shv = _sr(R_SH)
	slam_s = h3 + 0.06
	s_sd = _sr(R_SD)
	s_rel = _sr(R_REL)
	s_hoist = h5 + 0.24
	sc = _sr(R_CRASH)
	s_horn = _sr(R_HORN)
	s_gone = _sr(20.6)
	# the pendulum's phase: theta = A sin(phi); -Z through the fox at h1, +Z through the wolf at h2 and Alexander at h5
	var p1: float = asin(-TH_H1 / HOOK_A)
	var p2: float = asin(-TH_H2 / HOOK_A)
	var p5: float = asin(-TH_H5 / HOOK_A)
	w1 = (PI - p2 - p1) / (h2 - h1)
	s_sh = h1 - p1 / w1
	w2 = (TAU + p2 - p5) / (h5 - h2)
	w3 = (PI * 0.5 - asin(TH_H5 / HOOK_A5)) / (s_rel - h5)
	_layout()
	_props()
	_hero()
	_fox()
	_wolf()
	_sheep()
	_alex()
	_shots()
	_fx_sfx()
	_subs()


func _cast() -> void:
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("alex", StoryCast.opts("alexander"), StoryCast.speaker("alexander"), StoryCast.color("alexander"))
	for e: Array in [["fox", "guard_fox"], ["wolf", "guard_wolf"], ["sheep", "guard_sheep"]]:
		actor(String(e[0]), StoryCast.opts(String(e[1])), StoryCast.speaker(String(e[1])), StoryCast.color(String(e[1])))


## Real-time ramps on the music's accents ({"r": ...}; the story times are placeholders the clock recomputes). Contact
## pairs are checked on every tier by tests/test_cine_d3_boss.gd.
func _hits() -> void:
	hit("H1", 2.2, "medium", "the protagonist shoves the hanging crane hook: it swings into the fox-masked guard's face", {"r": R_H1, "att": "hook", "tgt": "fox:Head"})
	hit("H2", 5.0, "heavy", "held by the collar, then let go: the hook swings back into the back of the wolf's head", {"r": R_H2, "att": "hook", "tgt": "wolf:Head"})
	hit("H3", 7.8, "heavy", "a shove slams the sheep-masked guard back into the toppled forklift's roof guard", {"r": R_H3, "att": "hero:hands", "tgt": "sheep:torso"})
	hit("A1", 10.6, "accent", "slow-motion accent: Alexander's hurricane kick, the protagonist ducks under it", {"r": R_A1})
	hit("H5", 12.9, "finisher", "the returning crane hook snags Alexander's collar and hoists him away; down onto the crates (swell)",
		{"r": R_H5, "hq": SWELL_END - R_H5 - 0.55, "att": "hook", "tgt": "alex:Neck"})


func _plate(zl: float) -> Vector3:
	var xf := Transform3D(Basis.from_euler(FORKLIFT_ROT * (PI / 180.0)), FORKLIFT)
	var p: Vector3 = xf * Vector3(0.0, 2.16, zl)
	p.y = 0.0
	return p


func _layout() -> void:
	var b := Basis.from_euler(FORKLIFT_ROT * (PI / 180.0))
	N = b * Vector3.UP
	N.y = 0.0
	N = N.normalized()
	# the fox walks into the shank of the hook as it swings out (his face on its -Z side)
	var hk1: Vector3 = _hook_pos(h1)
	F1 = Vector3(HOOK_R.x, 0.0, hk1.z - 0.07 - 0.12 - 0.1)
	W_LIE = W_A + DIR_W * 1.9
	P1 = W_A + DIR_W * D_X1
	P_YK = W_A + DIR_W * D_YK
	var right := Vector3(DIR_W.z, 0.0, -DIR_W.x)   # the protagonist's right, facing -DIR_W
	P_DG = P_YK + right * 0.85
	S_SLAM = _plate(-0.35) + N * 0.14
	S_SIT = _plate(-0.35) + N * 0.4
	S_A = S_SLAM + N * 0.47
	P2 = S_A + N * D_X2
	S_RUN = _plate(0.9) + N * 0.45
	S_EXIT = S_RUN + Vector3(0.574, 0.0, 0.819) * 2.6
	P_X3 = A_X3 + Vector3(0.0, 0.0, D_X3)
	A_H5 = _collar_root(h5)
	A_H5.y = 0.0
	# the drop: the collar slips at s_rel, a forward somersault above the crate stack, flat on his back onto its top (sc),
	# down with it to the floor
	LAND = Vector3(CRATES.x, 1.28, _collar_root(s_rel).z + 0.24)
	A_FLOOR = Vector3(CRATES.x, 0.0, LAND.z + 0.05)


# ---------------------------------------------------------------------------
# The crane hook
# ---------------------------------------------------------------------------
## The hook's angle (deg, + toward +Z) at story s: at rest until the protagonist's shove, then one pendulum at amplitude
## HOOK_A through all its hits (phase rates w1 / w2 around H2); from the snag the hoisted cable whips it (rate w3) up to the
## top of its swing (HOOK_A5) at the release, where it turns at zero speed and swings back on its own, fading in the tail.
func _hook_theta(s: float) -> float:
	if s <= s_sh:
		return 0.0
	if s <= h2:
		return HOOK_A * sin(PI + w1 * (s - s_sh))
	if s <= h5:
		return HOOK_A * sin(TAU - asin(-TH_H2 / HOOK_A) + w2 * (s - h2))
	if s <= s_rel:
		return HOOK_A5 * sin(asin(TH_H5 / HOOK_A5) + w3 * (s - h5))
	return HOOK_A5 * exp(-0.3 * (s - s_rel)) * cos(HOOK_W4 * (s - s_rel))


## Cable length at story s: the crane jerks it up HOIST m over the 0.24 s after the snag.
func _hook_len(s: float) -> float:
	var u: float = clampf((s - h5 - 0.02) / (s_hoist - h5 - 0.02), 0.0, 1.0)
	return HOOK_L - HOIST * u * u * (3.0 - 2.0 * u)


func _hook_pos(s: float) -> Vector3:
	var th: float = deg_to_rad(_hook_theta(s))
	var ln: float = _hook_len(s)
	return HOOK_R + Vector3(0.0, HOOK_L, 0.0) + Vector3(0.0, -cos(th) * ln, sin(th) * ln)


## The J hook's bottom bar (where the collar hangs) at story s.
func _j_base(s: float) -> Vector3:
	return _hook_pos(s) + Basis(Vector3.RIGHT, deg_to_rad(-_hook_theta(s))) * J_BASE


## Alexander's root while he hangs by the collar (facing +Z: the collar is behind his root).
func _collar_root(s: float) -> Vector3:
	return _j_base(s) + Vector3(0.0, 0.05 - COLLAR_Y, COLLAR_BACK)


func _props() -> void:
	# the hook on its cable: keys every 0.03 s plus every hit (linear between keys)
	var ts: Array[float] = []
	var t: float = 0.0
	while t < story_end:
		ts.append(t)
		t += 0.03
	for e: float in [s_sh, h1, h2, h5, s_hoist, s_rel, story_end]:
		ts.append(e)
	ts.sort()
	var path: Array = []
	for s: float in ts:
		if not path.is_empty() and s - float(path[path.size() - 1][0]) < 0.004:
			continue
		path.append([s, _hook_pos(s), Vector3(-_hook_theta(s), 0.0, 0.0)])
	prop("crane_hook", "crane_hook", HOOK_R, 0.0, {"path": path, "cable": HOOK_L})
	# the toppled forklift (fixed: a two-key path holds its roll), the crates the finisher lands on
	prop("forklift", "forklift", FORKLIFT, 0.0, {"pallet": true, "path": [[0.0, FORKLIFT, FORKLIFT_ROT], [0.01, FORKLIFT, FORKLIFT_ROT]]})
	prop("crates", "crate_stack", CRATES, 90.0, {"color": Color("#8A6A43")})
	# set dressing (as cine_d3): two containers along the back, a second crate stack, pallets
	prop("box0", "container", Vector3(-6.08, 0.0, -4.6), 90.0, {"set": true, "color": Color("#2E5E8C")})
	prop("box1", "container", Vector3(0.02, 0.0, -4.6), 90.0, {"set": true, "color": Color("#9E3B2E")})
	prop("crates_b", "crate_stack", Vector3(-3.6, 0.0, 0.4), 25.0, {"set": true, "color": Color("#7A5A3A")})
	prop("pallets", "pallet", Vector3(-5.6, 0.0, 1.8), 15.0, {"set": true})
	# his party horn pops out of his shirt pocket as the crates burst and toots on the ground (cine_d3 finds it there)
	var hp0: Vector3 = LAND + Vector3(0.15, 0.3, -0.2)
	var hp1: Vector3 = Vector3(0.35, 0.05, LAND.z - 0.9)
	prop("horn_fly", "party_horn", hp1, 60.0, {"show_at": sc,
		"path": [[sc, hp0, Vector3(0.0, 0.0, 0.0)], [s_horn, hp1, Vector3(0.0, 60.0, 0.0)]]})


# ---------------------------------------------------------------------------
# Actors (story times around the ramps are compressed: every key and cue is anchored on a REAL time through _sr())
# ---------------------------------------------------------------------------
func _hero() -> void:
	key("hero", 0.0, P0, 0.0)
	move("hero", 0.0, "fight_idle")
	look("hero", 0.0, _sr(1.9), "alex")
	look("hero", _sr(1.9), h1 + 0.3, "fox")
	expr("hero", 0.0, "angry")
	# 2.45 both hands on the hook, a shove: it swings into the fox (2.83)
	strike("hero", s_sh, "shove_high", {"reach": 0.0})
	# turns to the wolf: his straight right (4.22), the collar grab (5.31), a sidestep as the hook swings back (5.90)
	var y_w: float = CineTimeline.face(P1, W_A)
	key("hero", _sr(3.35), P0, 0.0)
	key("hero", _sr(3.55), P0, CineTimeline.face(P0, P1))
	move("hero", _sr(3.5), "walk", {"fade": 0.15})
	key("hero", _sr(3.95), P1, y_w, {"mode": "out"})
	move("hero", _sr(3.9), "idle", {"fade": 0.12})   # guard still down: the wolf's right catches him cold
	look("hero", _sr(3.5), _sr(5.0), "wolf")
	strike("hero", x1, "hit_head")
	key("hero", x1 + 0.05, P1, y_w)
	key("hero", x1 + 0.4, P1 + DIR_W * 0.12, y_w, {"mode": "out"})   # rocked back a step
	move("hero", x1 + 0.5, "fight_idle", {"fade": 0.15})
	expr("hero", x1, "pain")
	look("hero", _sr(4.9), _sr(5.5), Vector3(HOOK_R.x, 1.6, W_A.z - 0.6))   # the hook coming back
	expr("hero", _sr(4.9), "happy")
	key("hero", _sr(4.95), P1 + DIR_W * 0.12, y_w)
	key("hero", _sr(5.2), P_YK, y_w, {"mode": "out"})
	strike("hero", s_yk, "yank", {"reach": 0.0})
	key("hero", s_yk + 0.04, P_YK, y_w)
	move("hero", s_yk + 0.2, "dodge", {"fade": 0.1})
	key("hero", h2 - 0.03, P_DG, y_w, {"mode": "out"})
	move("hero", h2 + 0.2, "fight_idle", {"fade": 0.2})
	# the sheep's jab (7.54), the shove into the forklift (7.96, slam 8.23)
	var y_s: float = CineTimeline.face(P2, S_A)
	move("hero", _sr(6.9), "idle", {"fade": 0.2})   # admiring his work: the sheep's jab catches him with his guard down
	key("hero", _sr(6.95), P_DG, y_w)
	key("hero", _sr(7.15), P_DG, y_s)
	key("hero", _sr(7.4), P2, y_s, {"mode": "out"})
	look("hero", _sr(6.9), _sr(8.8), "sheep")
	strike("hero", x2, "hit_head")
	expr("hero", x2, "pain")
	expr("hero", _sr(7.75), "angry")
	strike("hero", s_shv, "shove", {"reach": {"mixamo": 0.03, "ual": 0.14, "native": 0.1, "code": 0.1}})
	move("hero", h3 + 0.5, "fight_idle", {"fade": 0.2})
	look("hero", _sr(8.8), story_end, "alex")
	# into the hook's path behind it as it swings through (10.32), takes Alexander's right (10.81), ducks his kick (12.08)
	key("hero", _sr(10.15), P2, y_s)
	key("hero", _sr(10.3), P2, CineTimeline.face(P2, P_X3))
	move("hero", _sr(10.25), "walk", {"fade": 0.15})
	key("hero", _sr(10.62), P_X3, 0.0, {"mode": "out"})
	move("hero", _sr(10.58), "fight_idle", {"fade": 0.1})
	strike("hero", x3, "hit_head")
	expr("hero", x3, "pain")
	key("hero", x3 + 0.05, P_X3, 0.0)
	key("hero", x3 + 0.45, P_A1, 0.0, {"mode": "out"})
	expr("hero", x3 + 0.5, "angry")
	strike("hero", "A1", "dodge")
	# 13.54 sidesteps as the hook swings back: it takes Alexander instead
	key("hero", h5 - 0.3, P_A1, 0.0)
	move("hero", h5 - 0.36, "dodge", {"fade": 0.08})
	key("hero", h5 - 0.02, P5D, 0.0, {"mode": "out"})
	move("hero", h5 + 0.35, "fight_idle", {"fade": 0.25})
	expr("hero", h5 + 0.1, "happy")
	var y_c: float = CineTimeline.face(P5D, LAND)
	key("hero", sc - 0.2, P5D, 0.0)
	key("hero", sc + 0.1, P5D, y_c)
	move("hero", _sr(18.4), "winded", {"fade": 0.35})
	expr("hero", _sr(19.4), "done")


func _fox() -> void:
	StoryCast.dress(self, "fox", "guard_fox")
	var y0: float = CineTimeline.face(F0, P0)
	key("fox", 0.0, F0, y0)
	move("fox", 0.0, "fight_idle")
	key("fox", _sr(1.0), F0, y0)
	move("fox", _sr(1.0), "walk", {"fade": 0.2})
	key("fox", h1, F1, y0, {"mode": "out"})
	look("fox", 0.0, h1, "hero")
	# the hook's block into his mask: batted back, limbs flying, flat on his back
	strike("fox", "H1", "thrown", {"dur": 0.6})
	expr("fox", h1, "pain")
	key("fox", h1 + 0.1, F1 + Vector3(0.0, 0.0, -0.5), y0, {"mode": "linear"})
	key("fox", h1 + 0.6, F_LIE, y0, {"mode": "out", "arc": 0.3})
	move("fox", h1 + 0.5, "lie_flat", {"fade": 0.12})
	fx_at(h1 + 0.8, "stars", "fox", {"until": story_end})


func _wolf() -> void:
	StoryCast.dress(self, "wolf", "guard_wolf")
	var y_a: float = CineTimeline.face(W_A, P1)
	key("wolf", 0.0, W0, CineTimeline.face(W0, P0))
	move("wolf", 0.0, "fight_idle")
	key("wolf", _sr(2.9), W0, CineTimeline.face(W0, W_A))
	move("wolf", _sr(2.9), "jog", {"fade": 0.15})
	key("wolf", _sr(3.9), W_A, y_a, {"mode": "out"})
	move("wolf", _sr(3.85), "fight_idle", {"fade": 0.1})
	look("wolf", _sr(2.9), h2, "hero")
	strike("wolf", x1, "cross", {"reach": {"mixamo": Vector2(-0.07, 0.06), "ual": 0.14, "native": 0.11, "code": 0.11}})
	move("wolf", x1 + 0.3, "idle", {"fade": 0.15})
	# held by the collar (5.31), let go: the hook into the back of his head (5.90), a somersault forward onto his back
	strike("wolf", s_yk + 0.02, "hit_head")
	move("wolf", s_yk + 0.22, "stunned", {"fade": 0.1})
	expr("wolf", s_yk, "pain")
	key("wolf", h2, W_A, y_a)
	strike("wolf", "H2", "thrown", {"dur": 0.45})
	key("wolf", h2 + 0.36, W_LIE, y_a, {"mode": "linear", "arc": 0.9, "spin": Vector3(-360.0, 0.0, 0.0)})
	move("wolf", h2 + 0.42, "lie_flat", {"fade": 0.12})
	key("wolf", h2 + 0.6, W_LIE, y_a, {"spin": Vector3(-360.0, 0.0, 0.0)})
	fx_at(h2 + 0.6, "stars", "wolf", {"until": story_end})


func _sheep() -> void:
	StoryCast.dress(self, "sheep", "guard_sheep")
	var y_a: float = CineTimeline.face(S_A, P2)
	key("sheep", 0.0, S0, CineTimeline.face(S0, P0))
	move("sheep", 0.0, "fight_idle")
	key("sheep", _sr(5.0), S0, CineTimeline.face(S0, S_A))
	move("sheep", _sr(5.0), "walk", {"fade": 0.15})
	key("sheep", _sr(7.25), S_A, y_a, {"mode": "out"})
	move("sheep", _sr(7.2), "fight_idle", {"fade": 0.1})
	look("sheep", _sr(5.0), h3, "hero")
	strike("sheep", x2, "jab", {"reach": {"mixamo": Vector2(0.1, -0.12), "ual": 0.15, "native": 0.1, "code": 0.05}})
	move("sheep", x2 + 0.25, "fight_idle", {"fade": 0.12})
	# 7.96 the shove, 8.23 back first into the forklift's roof guard, slides down to sit against it
	strike("sheep", s_shv, "hit_stomach")
	key("sheep", s_shv, S_A, y_a)
	key("sheep", h3, S_SLAM, y_a, {"mode": "linear"})
	strike("sheep", "H3", "slammed")
	key("sheep", slam_s, S_SLAM + N * -0.02, y_a, {"mode": "out"})
	key("sheep", h3 - 0.04 + 0.8, S_SIT, y_a)
	move("sheep", h3 - 0.04 + 0.8, "slumped", {"fade": 0.15})
	fx_at(slam_s + 0.1, "stars", "sheep", {"until": _sr(18.6)})
	# the tail: up and away along the forklift ("Chạy!")
	var s_up: float = _sr(18.15)
	move("sheep", s_up, "get_up_sit")
	key("sheep", s_up + 1.2, S_SIT, y_a)
	key("sheep", s_up + 1.35, S_SIT, CineTimeline.face(S_SIT, S_RUN))
	move("sheep", s_up + 1.25, "sprint", {"fade": 0.15})
	key("sheep", s_up + 1.7, S_RUN, CineTimeline.face(S_SIT, S_RUN), {"mode": "linear"})
	key("sheep", s_gone, S_EXIT, CineTimeline.face(S_RUN, S_EXIT), {"mode": "linear"})
	show("sheep", s_gone, false)


func _alex() -> void:
	hold("alex", 0.0, story_end, "hawaii_print", {"bone": "Chest", "offset": Vector3.ZERO, "depth": -0.175})
	var eyes := Vector3(0.0, StoryCast.EYE_UP, StoryCast.EYE_FRONT)
	hold("alex", 0.0, s_sd, "gold_shades", {"bone": "Head", "offset": eyes})
	hold("alex", s_sd, sc, "gold_shades", {"bone": "Head", "offset": eyes + Vector3(0.0, -0.03, -0.012), "rot": Vector3(-8.0, 0.0, 0.0)})
	hold("alex", sc, story_end, "gold_shades", {"bone": "Head", "offset": Vector3(0.012, StoryCast.EYE_UP - 0.012, StoryCast.EYE_FRONT), "rot": Vector3(0.0, 0.0, 16.0)})
	hold("alex", 0.0, sc, "party_horn", {"bone": "Chest", "offset": Vector3(0.1, -0.02, -0.16), "rot": Vector3(-70.0, 0.0, 0.0)})
	# on the ground by his toppled forklift, dazed; up, shakes it off, points his guards in
	var y0: float = CineTimeline.face(A0, P0)
	key("alex", 0.0, A0, y0)
	move("alex", 0.0, "slumped")
	fx_at(0.0, "stars", "alex", {"until": _sr(1.4)})
	move("alex", _sr(0.3), "get_up_sit")
	move("alex", _sr(1.5), "head_shake", {"fade": 0.12})
	move("alex", _sr(2.1), "point", {"fade": 0.2})
	move("alex", _sr(3.3), "idle", {"fade": 0.3})
	look("alex", _sr(1.6), story_end, "hero")
	expr("alex", 0.0, "pain")
	expr("alex", _sr(1.7), "angry")
	# 9.42 the shades lowered with one finger; beside the hook's path, in behind it once it has swung through (10.32)
	move("alex", _sr(8.9), "hold_up", {"fade": 0.2})
	expr("alex", s_sd, "happy")
	var y_ap: float = CineTimeline.face(A0, A_APP)
	move("alex", _sr(9.75), "walk", {"fade": 0.2})
	key("alex", _sr(9.75), A0, y0)
	key("alex", _sr(9.85), A0, y_ap)
	key("alex", _sr(10.45), A_APP, y_ap, {"mode": "linear"})
	key("alex", _sr(10.65), A_X3, 180.0, {"mode": "out"})
	move("alex", _sr(10.4), "fight_idle", {"fade": 0.1})
	# 10.81 his uppercut; laughs; 12.08 the hurricane kick (it carries him into the hook's path, his back to it)
	strike("alex", x3, "uppercut", {"dur": 0.6, "reach": {"mixamo": Vector2(0.35, -0.12), "ual": 0.18, "native": 0.2, "code": 0.17}})
	move("alex", _sr(11.0), "laugh", {"fade": 0.15})
	expr("alex", _sr(11.0), "happy")
	key("alex", a1 - 0.5, A_X3, 180.0)
	strike("alex", "A1", "hurricane_kick", {"dur": 1.0})
	expr("alex", a1, "angry")
	key("alex", a1 + 0.45, A_K2, 180.0, {"mode": "linear"})
	move("alex", a1 + 0.5, "fight_idle", {"fade": 0.1})
	# 13.54 steps in for more: the hook takes him by the collar
	key("alex", h5, A_H5, 180.0, {"mode": "linear"})
	# hanging by the collar: the root follows the hook (keys every 0.03 s), legs kicking
	strike("alex", "H5", "dangle", {"fade": 0.1})
	expr("alex", h5 + 0.02, "pain")
	var s: float = h5 + 0.03
	while s < s_rel:
		key("alex", s, _collar_root(s), 180.0, {"mode": "linear"})
		s += 0.03
	key("alex", s_rel, _collar_root(s_rel), 180.0, {"mode": "linear"})
	# the top of the swing: the collar slips forward off the hook's tip (15.02), he drops still kicking onto the crates and
	# lands flat on his back (16.87), they burst, he lies in the wreck
	key("alex", s_rel + 0.06, _collar_root(s_rel) + Vector3(0.0, -0.03, 0.22), 180.0, {"mode": "out"})
	move("alex", sc - 0.1, "lie_flat", {"fade": 0.09})
	key("alex", sc, LAND, 180.0, {"mode": "in"})
	key("alex", sc + 0.14, A_FLOOR, 180.0, {"mode": "in"})
	key("alex", story_end, A_FLOOR, 180.0)
	expr("alex", sc, "done")
	fx_at(sc + 0.3, "stars", "alex", {"until": story_end})


func _shots() -> void:
	shot("K1", 0.0, "crane", "crane down past the hanging crane hook: the toppled forklift, Alexander on the ground, three masked guards",
		{"from": Vector3(0.9, 5.4, 5.2), "to": Vector3(0.4, 2.2, 4.0), "look_from": Vector3(-0.2, 0.6, -0.8),
		"look_to": Vector3(-0.1, 1.2, -0.6), "fov": 50.0, "hand": 0.2})
	dutch_shot("D1", _sr(1.15), "alex", {"roll": 14.0, "side_deg": 20.0, "dist": 2.6, "fov": 44.0})
	shot("O1", _sr(2.2), "orbit", "slow-motion orbit: the shove, the hook swings into the fox's mask (2.83)",
		{"center": Vector3(HOOK_R.x, 1.45, 0.25), "radius": 2.6, "deg_from": 95.0, "deg_to": 70.0, "height": 1.35, "fov": 46.0, "hand": 0.3})
	ots_shot("T1", _sr(3.75), "wolf", "hero", {"side": -1.0, "fov": 44.0, "look_y": 1.15, "back": 1.4})
	shot("S1", _sr(5.0), "static", "slow motion, low and side-on: held by the collar, then let go as the hook swings back into him (5.90)",
		{"pos": Vector3(2.3, 0.8, 0.0), "look": Vector3(-0.4, 1.35, 0.55), "fov": 50.0, "hand": 0.4})
	two_shot("T2", _sr(7.15), "hero", "sheep", {"side": 1.0, "fov": 44.0, "look_y": 1.15, "height": 1.35})
	shot("S2", _sr(7.8), "static", "slow motion, low: the sheep slammed back into the forklift's roof guard (8.23)",
		{"pos": S_SLAM + N * 2.4 + Vector3(-0.9, 0.7, 1.0), "look": S_SLAM + Vector3(0.0, 0.9, 0.0), "fov": 50.0, "hand": 0.4})
	push_in("P1", _sr(9.0), "alex", {"from": 3.8, "to": 2.4, "side_deg": -50.0, "fov": 42.0})
	ots_shot("T3", _sr(10.45), "alex", "hero", {"side": 1.0, "fov": 40.0})
	shot("O2", _sr(11.55), "orbit", "low slow orbit: the hurricane kick sails over the ducking protagonist (12.08), the hook far off",
		{"center": (A_X3 + P_A1) * 0.5 + Vector3(0.0, 1.0, 0.0), "radius": 3.0, "deg_from": 70.0, "deg_to": 95.0, "height": 0.7,
		"fov": 48.0, "hand": 0.3})
	shot("S3", _sr(12.95), "static", "slow motion, side-on and wide: the hook swings back and takes Alexander by the collar (13.54)",
		{"pos": Vector3(3.6, 1.2, 1.2), "look": Vector3(HOOK_R.x, 1.4, 0.9), "fov": 52.0, "hand": 0.3})
	shot("C1", _sr(14.1), "crane", "crane-high, looking down the cable: the hook swings him high over the yard, kicking; the collar slips",
		{"from": Vector3(1.4, 5.0, 0.6), "to": Vector3(1.2, 5.6, 1.4), "look_from": Vector3(HOOK_R.x, 1.6, 2.6),
		"look_to": Vector3(HOOK_R.x, 2.0, 3.4), "fov": 52.0, "hand": 0.2})
	shot("S4", _sr(16.2), "static", "slow motion at the crate stack: he drops flat onto the smart-glasses crates (16.87)",
		{"pos": CRATES + Vector3(2.6, 1.0, -1.4), "look": CRATES + Vector3(0.0, 1.2, -0.2), "fov": 50.0, "hand": 0.4})
	shot("W1", _sr(SWELL_END), "dolly", "tail wide: the wreck in the yard, the sheep runs for it",
		{"from": Vector3(-3.2, 2.4, 4.6), "to": Vector3(-2.9, 2.2, 4.3), "look_from": Vector3(0.4, 0.5, 1.6),
		"look_to": Vector3(0.6, 0.5, 1.4), "fov": 56.0, "hand": 0.4})
	hero_shot("L1", _sr(19.3), "hero", {"side_deg": 25.0, "dist": 2.6, "fov": 50.0})
	punch(x1, "medium")
	punch(x2, "light")
	punch(x3, "medium")


func _fx_sfx() -> void:
	sfx_at(s_sh, "chain_rattle", -6.0)
	sfx_at(s_sh + 0.05, "whoosh_down", -8.0)
	sfx_at("H1", "pot_clonk", -1.0)
	sfx_at("H1", "impact_medium", -5.0)
	fx_at("H1", "sparks", "fox:Head", {"power": 0.6})
	sfx_at(h1 + 0.6, "body_fall", -3.0)
	sfx_at(x1, "impact_medium", -3.0)
	fx_at(x1, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(h2 - 0.3, "whoosh_down", -6.0)
	sfx_at("H2", "pot_clonk", 0.0)
	sfx_at("H2", "impact_heavy", -6.0)
	fx_at("H2", "sparks", "wolf:Head", {"power": 0.7})
	sfx_at(h2 + 0.36, "body_fall", -2.0)
	fx_at(h2 + 0.36, "dust", "wolf:Hips", {"power": 0.7})
	sfx_at(x2, "impact_light", -2.0)
	sfx_at(s_shv, "whoosh_down", -8.0)
	sfx_at("H3", "door_bang", 0.0)
	sfx_at("H3", "impact_heavy", -5.0)
	fx_at("H3", "dust", "sheep:Chest", {"power": 0.8})
	fx_at(slam_s, "flash", "forklift", {"power": 0.4})
	sfx_at(_sr(R_SD), "freeze_tick", -6.0)
	sfx_at(a1 - 0.3, "whoosh_down", -4.0)
	sfx_at("A1", "whoosh_down", -6.0)
	sfx_at(x3, "impact_medium", -2.0)
	fx_at(x3, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(_sr(R_LAUGH), "evil_laugh", -6.0)
	sfx_at(h5 - 0.25, "whoosh_down", -5.0)
	sfx_at("H5", "impact_heavy", -4.0)
	sfx_at("H5", "chain_rattle", -2.0)
	sfx_at(h5 + 0.03, "engine_roar", -10.0)
	sfx_at(h5 + 0.1, "slide_whistle", -5.0)
	sfx_at(s_rel, "chain_rattle", -6.0)
	sfx_at(sc, "crate_smash", 0.0)
	sfx_at(sc, "glass_crack", -6.0)
	sfx_at(sc + 0.14, "body_fall", -3.0)
	fx_at(sc, "crate", "crates", {"power": 1.1, "dir": Vector3(0.0, 0.7, 0.6)})
	fx_at(sc, "flash", "crates", {"power": 0.7})
	fx_at(sc, "dust", "alex:Hips", {"power": 1.0})
	sfx_at(s_horn, "party_horn", -4.0)
	sfx_at(_sr(18.6), "groan", -6.0)


func _subs() -> void:
	sub(1.4, 1.4, "alex", "Bắt nó lại cho ta!")
	sub(9.15, 1.5, "alex", "Ta học võ trên mạng đó!")
	sub(18.35, 0.8, "sheep", "Chạy!")
	sub(19.45, 1.5, "hero", "Còn ai tên dài nữa không?")
