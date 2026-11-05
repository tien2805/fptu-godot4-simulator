# File: res://scripts/cine/timelines/seg_d7_phase2.gd
# seg_d7_phase2 (14.190 s, story spec 8.3 "light returns, heroic"; reworked by plan 2026-11-05-w6-fights task 5 and its
# review: its own choreography, cameras and signature, off the CineFightC template and away from the other fights' moves;
# every hit on an accent of the owner's "The Power of Love" re-cut from 153.76 s of the original, see the music note
# below). After the blackout (d7_boss2's "after"): both breakers are back on, the gold lights stutter up over the vase
# gallery, and Lùm Văn Lọ, cradling his favourite antique urn like a cat, sends his last three masked guards in. Mostly at
# full speed: three short slow-motion ramps (the vase, the catch, the crown) take 2.64 s of the 14.19.
#   0.0  hard cut from black: the breakers clunk, the lights stutter up (0.59) on the protagonist, the blackout flashlight
#        still in hand; Lọ: "Có điện thì sao? Tụi bay, xử lý nó!"
#   3.07     the wolf-masked guard steps up cracking his neck: a hopping overhand flashlight bonk on the top of his head
#            mid-crack (full speed, punch-in: clonk); he reels, seeing stars, and sits down hard (4.11)
#   4.73     the sheep-masked guard lunges in with a headbutt and catches the protagonist admiring the flashlight (full
#            speed, punch-in); the protagonist is rocked back against the surface plinth, the flashlight clatters to the
#            floor (5.26); the sheep paws the floor like a bull
#   6.39 H2  the bull's charge, head down (5.57): the protagonist steps aside like a matador, and the sheep dives
#            head first into the surface plinth's vase (a short freeze: it bursts); back on his feet in the shards, he
#            keels over flat on his back (7.23)
#   7.37     Lọ, too late: "Bình của tao!", both hands flung up in despair: his own antique urn flies off them
#   8.05 A1  the signature: the protagonist catches the spinning urn two-handed, mouth down (a short slow-motion accent);
#            the fox-masked guard creeps up behind
#   9.70 H5  finisher: the protagonist whips round and, in one jump, puts the caught urn down over the cowering fox's
#            head (a short swell to 10.54, seen from straight above); the fox straightens up under it, stiff as a post
#  10.30     joke: the sheep, from the floor: "Lương có năm triệu thôi mà!"
#  10.54-14.19 at 1x:
#  11.36     knock knock: the protagonist steps up and raps on the urn with a knuckle, and the fox topples like a felled
#            tree, flat on his back with the urn still on (12.19)
#  12.10     Lọ: "...Gọi trực thăng. Lên sân thượng!" and he sprints for the roof stairs (13.02), still running at the end
# Music: the owner's "The Power of Love" re-cut from 153.76 s of the original (W6); every hit, the hit taken, the vase
# burst, the knock and the falls sit on its accents within 0.1 s (the bonk, the headbutt, the crown and the knock on its
# four strongest). No gore: clonks, shards of porcelain, stars, an urn over a head. Contacts are measured on every tier by
# tests/test_cine_d7_phase2.gd (tests/support/cine_brawl.gd); every contact pairs two code poses (tier invariant).
# Staged in the tower: LairTower.cine_xf moves this stage to the hall's (0.4, 0, -0.75) so the surface plinth stands on the
# hall's plinth at (3, 0) and the spare one on (-3, 0) (hide_for_cine hides those two real plinths while it plays); the
# other real plinths, the speakers, the breakers and the sign are the hall's own (drop_set). For XEM LẠI PHIM the carried
# set (LairTower.cine_gallery_set: the hall, the other ten plinths with vases, speakers, breakers, the sign; opts "set")
# stands in for the hall. The fight keeps to the 14 x 10 box (|x| <= 7, |z| <= 5).
# Stage frame: X right, -Z forward (toward the hall's back wall and Lọ's sign), ground y = 0; yaw in degrees, characters
# face -Z at 0.
extends CineTimeline

const LENGTH: float = 14.19
## Real times of the beats (accents of the music cut, see the header).
const R_LIGHT: float = 0.59
const R_H1: float = 3.07
const R_SIT: float = 4.11
const R_X1: float = 4.73
const R_TORCH: float = 5.26
const R_CHARGE: float = 5.57
const R_H2: float = 6.39
const R_LAND: float = 7.23
const R_REL: float = 7.37
const R_A1: float = 8.05
const R_H5: float = 9.70
const SWELL_END: float = 10.54
const R_KNOCK: float = 11.36
const R_DOWN: float = 12.19
const R_GO: float = 13.02
const TAIL: float = LENGTH - SWELL_END

## The hall's centre in this stage's frame (the stage origin is the hall's (0.4, 0, -0.75)).
const HALL := Vector3(-0.4, 0.0, 0.75)
## The surface plinth (the hall's at (3, 0)) and the spare one (the hall's at (-3, 0)), with the vase seeds of those two
## (LairTower: seed = the row-major index).
const SURFACE := Vector3(2.6, 0.0, 0.75)
const SPARE := Vector3(-3.4, 0.0, 0.75)
const SEED_SURFACE: int = 6
const SEED_SPARE: int = 5

# spacing (m, root to root); tuned against tests/test_cine_d7_phase2.gd (surface gaps, the same on every tier)
const D_BK: float = 0.68            # the flashlight bonk
## The protagonist turned this far left of the wolf at the bonk: the right hand comes down on the middle of his head.
const BONK_TURN: float = 14.0
const D_BACK: float = 0.3           # the wolf waits this far beyond his bonk spot
const D_REEL: float = 0.6           # ... and reels this far back, turning away (REEL_TURN), to sit down there
const REEL_TURN: float = 70.0
const D_HB: float = 0.65            # the sheep's headbutt
const D_LUNGE: float = 0.2          # ... lunges in this far (from S_W to S_G)
const D_VASE: float = 0.81          # the sheep's root from the surface plinth's centre when his head meets its vase
const D_CR: float = 0.97            # the jumping crown (with its CROWN_STEP in)
const CROWN_STEP: float = 0.28      # the crown jumps this far toward the fox
const D_KN: float = 0.64            # the knock
## A stiff fall onto the back pivots about the heels: the root goes back this far (CineMoves.PIVOT_Y).
const TOPPLE: float = 0.95
const FALL_DUR: float = 0.45        # the sheep's keel-over (CineMoves "thrown")
const PLANK_DUR: float = 0.75       # the fox's timber fall (CineMoves "plank")
## The protagonist's sidestep turns him this far (deg) to watch the bull go by.
const OLE_TURN: float = -100.0
## Lọ's sprint for the roof stairs: 0.3 s to sprint pace, then sprint pace to the end.
const RUN_SPEED: float = 6.0
const RUN_ACCEL: float = 0.3

# positions
const P0 := Vector3(1.05, 0.0, 0.75)         # the protagonist: the bonk and the headbutt on one spot
const DIR_W := Vector3(0.0, 0.0, -1.0)       # from the protagonist to the wolf at the bonk
const W0 := Vector3(-1.6, 0.0, -1.3)
const L0 := Vector3(2.6, 0.0, -1.6)          # Lọ with his urn
const RUN_DIR := Vector3(-0.985, 0.0, -0.172) # his sprint for the roof stairs (to the left)
const S0 := Vector3(-1.9, 0.0, 1.5)          # the sheep comes in from the left
const DIR_S := Vector3(1.0, 0.0, 0.0)        # his headbutt and his charge (toward the surface plinth)
const H_O := Vector3(1.75, 0.0, 0.75)        # the protagonist rocked back against the surface plinth by the headbutt
const H_S := Vector3(1.75, 0.0, 1.65)        # ... the matador's sidestep; the catch and the crown from there
const F0 := Vector3(-1.4, 0.0, 2.2)
const DIR_F := Vector3(-0.33, 0.0, 0.944)    # from the protagonist to the fox at the crown
## The flashlight off the protagonist's hand at the headbutt and where it lands.
const TORCH_FLOOR := Vector3(0.45, 0.034, 1.95)
## The urn's centre in Lọ's hands at the release (his frame, measured on the evaluated fling) and in the protagonist's at
## the catch (his frame, measured on the evaluated catch).
const URN_RELEASE := Vector3(-0.023, 1.649, -0.183)
const URN_CATCH := Vector3(-0.018, 1.419, -0.332)

var W_B: Vector3      # the wolf at the bonk
var W_A: Vector3      # ... waiting
var W_R: Vector3      # ... reeling, sitting down (his legs out of everyone's way)
var S_W: Vector3      # the sheep waiting for the headbutt
var S_G: Vector3      # ... at the headbutt, pawing the floor
var S_V: Vector3      # ... his head in the vase
var S_DOWN: Vector3   # ... flat on his back (the heels where he stood)
var F_C: Vector3      # the fox at the crown
var F_DOWN: Vector3   # ... flat on his back
var H_K: Vector3      # the protagonist at the knock
var L_RUN: Vector3    # Lọ at the end of the cinematic, still sprinting
var torch_hand: Vector3   # the flashlight's grip when it leaves the hand (local to the protagonist, measured)

# story times
var h1: float
var s_sit: float      # the wolf sits down hard
var x1: float
var s_torch: float    # the flashlight on the floor
var s_charge: float
var s_side: float     # the protagonist's sidestep starts
var h2: float
var slam_s: float     # the sheep's head into the surface plinth's vase
var s_fall: float     # ... he keels over
var s_land: float     # ... flat
var s_rel: float      # the urn leaves Lọ's hands
var s_creep: float    # the fox sets off
var a1: float         # the urn lands in the protagonist's hands
var h5: float
var s_on: float       # the protagonist lands: the urn sits on the fox's head
var s_knock: float
var s_tp: float       # the fox starts to topple
var s_down: float     # ... flat on his back
var s_go: float       # Lọ sprints


func _sr(r: float) -> float:
	return clock.story_at(r)


func build() -> void:
	slot = "seg_d7_phase2"
	length = LENGTH
	mood = "punchy"
	fade_in = 0.12     # a hard cut from black
	fade_out = 0.5
	stage = {"at": Vector2(3930.0, -440.0), "size": Vector2(28.0, 24.0), "yaw_deg": 21.0, "landmark": "be6_center",
		"near": 30.0, "tod": "dawn", "exposure": 1.2, "ambient": 1.3}
	_cast()
	_hits()
	clock.length = length
	clock.tail_rule = false   # the W6 fights' short tail at 1x after the swell (CineClock's 3-4 s rule is off)
	clock.build()
	story_end = float(clock.ramp("H5")["s1"]) + TAIL
	clock.story_end = story_end
	h2 = story_time("H2")
	a1 = story_time("A1")
	h5 = story_time("H5")
	h1 = _sr(R_H1)
	s_sit = _sr(R_SIT)
	x1 = _sr(R_X1)
	s_torch = _sr(R_TORCH)
	s_charge = _sr(R_CHARGE)
	s_side = _sr(5.95)
	slam_s = h2
	s_land = _sr(R_LAND)
	s_fall = s_land - FALL_DUR
	s_rel = _sr(R_REL)
	s_creep = _sr(6.9)
	s_on = h5 + 0.1
	s_knock = _sr(R_KNOCK)
	s_down = _sr(R_DOWN) - 0.02
	s_tp = s_down - PLANK_DUR
	s_go = _sr(R_GO)
	_layout()
	_props()
	_hero()
	_lo()
	_wolf()
	_sheep()
	_fox()
	_shots()
	_fx_sfx()
	_subs()


func _cast() -> void:
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("lo", CastD7.opts("van_lo"), CastD7.SPEAKER, CastD7.COLOR)
	for e: Array in [["wolf", "guard_wolf"], ["sheep", "guard_sheep"], ["fox", "guard_fox"]]:
		actor(String(e[0]), StoryCast.opts(String(e[1])), StoryCast.speaker(String(e[1])), StoryCast.color(String(e[1])))


## Real-time ramps on the music's accents ({"r": ...}; the story times are placeholders the clock recomputes), kept short:
## the bonk, the headbutt and the knock play at full speed. Contact pairs are checked on every tier by
## tests/test_cine_d7_phase2.gd.
func _hits() -> void:
	hit("H2", 5.0, "light", "the bull's charge, head down: the protagonist sidesteps like a matador and the sheep-masked guard dives head first into the surface plinth's vase",
		{"r": R_H2, "att": "sheep:head", "tgt": "surface"})
	hit("A1", 6.5, "accent", "slow-motion accent: the protagonist catches the antique urn Lọ flung up in despair, two-handed, mouth down",
		{"r": R_A1, "ri": 0.1, "hp": 0.15, "hq": 0.2, "ro": 0.2})
	hit("H5", 7.6, "finisher", "the jumping crown, seen from above: the caught urn put down over the fox-masked guard's head (swell)",
		{"r": R_H5, "ri": 0.15, "hp": 0.3, "hq": SWELL_END - R_H5 - 0.55, "att": "hero:urn", "tgt": "fox:Head"})


func _layout() -> void:
	W_B = P0 + DIR_W * D_BK
	W_A = W_B + DIR_W * D_BACK
	W_R = W_B + DIR_W * D_REEL
	S_G = P0 - DIR_S * D_HB
	S_W = S_G - DIR_S * D_LUNGE
	S_V = SURFACE - DIR_S * D_VASE
	S_DOWN = S_V - DIR_S * TOPPLE
	F_C = H_S + DIR_F * D_CR
	F_DOWN = F_C + DIR_F * TOPPLE
	H_K = F_C - DIR_F * D_KN
	L_RUN = L0 + RUN_DIR * (RUN_SPEED * RUN_ACCEL * 0.5 + RUN_SPEED * (story_end - s_go - RUN_ACCEL))
	torch_hand = Vector3(0.182, 1.377, -0.231)


## The carried hall for XEM LẠI PHIM (dropped in the tower): LairTower's gallery without the two plinths the fight brings,
## its breakers switched back on.
static func _hall_set() -> Array:
	var out: Array = []
	for ds: Array in LairTower.cine_gallery_set(HALL, LairTower.CINE_PLINTHS["seg_d7_phase2"]):
		var row: Array = ds.duplicate()
		if String(row[1]) == "breaker":
			row[4] = {"on": true}
		out.append(row)
	return out


func _props() -> void:
	for ds: Array in _hall_set():
		var o: Dictionary = (ds[4] if ds.size() > 4 else {}).duplicate()
		o["set"] = true
		prop(String(ds[0]), String(ds[1]), ds[2], float(ds[3]), o)
	# the surface plinth whose vase the sheep's head bursts, and the spare one, both on the hall's own spots
	prop("surface", "plinth", SURFACE, 0.0, {"vase": SEED_SURFACE})
	prop("plinth_l", "plinth", SPARE, 0.0, {"vase": SEED_SPARE})
	# the flashlight knocked out of the protagonist's hand by the headbutt: a tumble to the floor, still lit
	var yh: float = deg_to_rad(CineTimeline.face(P0, S_G))
	var p0: Vector3 = P0 + Basis(Vector3.UP, yh) * torch_hand
	prop("torch", "flashlight", TORCH_FLOOR, 0.0, {"on": true, "show_at": x1,
		"path": [[x1, p0, Vector3(-15.0, rad_to_deg(yh), 0.0)], [s_torch, TORCH_FLOOR, Vector3(0.0, rad_to_deg(yh) + 250.0, 0.0)]],
		"arc": 0.45})
	# Lọ's urn flung up off his hands: a lob to the protagonist's, end over end (mouth down there)
	prop("urn_fly", "antique_urn", Vector3.ZERO, 0.0, {"show_at": s_rel, "hide_at": a1,
		"path": [[s_rel, _urn_release(), Vector3.ZERO], [a1, _urn_catch(), Vector3(540.0, 0.0, 0.0)]], "arc": 0.35})


func _urn_release() -> Vector3:
	return L0 + Basis(Vector3.UP, deg_to_rad(CineTimeline.face(L0, H_S))) * URN_RELEASE


func _urn_catch() -> Vector3:
	return H_S + Basis(Vector3.UP, deg_to_rad(CineTimeline.face(H_S, L0))) * URN_CATCH


## Root keys of a stiff fall onto the back from `from` (facing yaw) over story [s0, s1]: the root goes back along `back`
## by TOPPLE * sin(pitch), so the heels stay where they stood. curve "thrown": pitch = 90 deg * smoothstep(u) (CineMoves
## "thrown"); "plank": 90 deg * u^2 (CineMoves "plank").
func _topple(id: String, s0: float, s1: float, from: Vector3, back: Vector3, yaw: float, curve: String) -> void:
	for i: int in range(1, 7):
		var u: float = float(i) / 6.0
		var e: float = u * u * (3.0 - 2.0 * u) if curve == "thrown" else u * u
		key(id, lerpf(s0, s1, u), from + back * (TOPPLE * sin(PI * 0.5 * e)), yaw, {"mode": "linear"})


# ---------------------------------------------------------------------------
# Actors (every key and cue is anchored on a REAL time through _sr())
# ---------------------------------------------------------------------------
func _hero() -> void:
	var y0: float = CineTimeline.face(P0, L0)
	key("hero", 0.0, P0, y0)
	move("hero", 0.0, "fight_idle")
	expr("hero", 0.0, "angry")
	look("hero", 0.0, _sr(1.6), "lo")
	# the flashlight: reverse of a torch grip, pointing forward-down (lit), until the headbutt knocks it away
	hold("hero", 0.0, x1, "flashlight", {"bone": "Wrist.R", "on": true, "offset": Vector3(0.0, 0.0, -0.04), "rot": Vector3(-15.0, 0.0, 0.0)})
	# 3.07 the bonk on the wolf, at full speed (he stops to crack his neck)
	var y_w: float = CineTimeline.face(P0, W_B) + BONK_TURN
	key("hero", _sr(1.7), P0, y0)
	key("hero", _sr(2.2), P0, y_w)
	look("hero", _sr(1.6), h1 + 0.3, "wolf")
	strike("hero", h1, "bonk")
	expr("hero", h1, "angry")
	# turned to admire the flashlight, the sheep coming in from the left: his headbutt (4.73) knocks it out of the hand
	var y_s: float = CineTimeline.face(P0, S_G)
	key("hero", _sr(3.65), P0, y_w)
	key("hero", _sr(4.05), P0, y_s)
	move("hero", _sr(3.95), "hold_up", {"fade": 0.15})
	expr("hero", _sr(4.0), "happy")
	look("hero", _sr(3.9), _sr(4.6), Vector3(P0.x - 0.3, 1.2, P0.z + 0.2))
	move("hero", x1, "stunned", {"fade": 0.06})   # code on every tier: the headbutt lands on the same chest everywhere
	expr("hero", x1, "pain")
	key("hero", x1 + 0.04, P0, y_s)
	key("hero", x1 + 0.45, H_O, y_s, {"mode": "out"})   # rocked back against the surface plinth
	look("hero", x1 + 0.1, h2 + 0.4, "sheep")
	expr("hero", _sr(5.3), "angry")
	move("hero", _sr(5.3), "fight_idle", {"fade": 0.2})
	# the bull's charge: the matador's sidestep, and the sheep goes by into the vase (6.39)
	key("hero", s_side, H_O, y_s)
	key("hero", s_side + 0.25, H_S, y_s + OLE_TURN * 0.4, {"mode": "out"})
	key("hero", h2 + 0.1, H_S, y_s + OLE_TURN, {"mode": "out"})
	move("hero", s_side - 0.05, "ole", {"fade": 0.1})
	expr("hero", s_side + 0.1, "happy")
	move("hero", h2 + 0.45, "fight_idle", {"fade": 0.2})
	# turned to Lọ's flung urn: 8.05 the catch (the signature)
	var y_l: float = CineTimeline.face(H_S, L0)
	key("hero", s_rel - 0.05, H_S, y_s + OLE_TURN)
	key("hero", a1 - 0.08, H_S, y_l, {"mode": "out"})
	look("hero", h2 + 0.45, a1 + 0.2, "lo")
	expr("hero", s_rel, "surprised")
	strike("hero", "A1", "catch")
	hold("hero", a1, s_on, "antique_urn", {"bone": "Wrist.L", "mid": "Wrist.R", "offset": Vector3(0.0, 0.0, 0.0), "rot": Vector3(180.0, 0.0, 0.0)})
	expr("hero", a1, "happy")
	# whips round to the fox behind: 9.70 the jumping crown
	var y_f: float = CineTimeline.face(H_S, F_C)
	key("hero", a1 + 0.2, H_S, y_l)
	key("hero", h5 - 0.42, H_S, y_f, {"mode": "out"})
	look("hero", a1 + 0.25, s_down, "fox")
	strike("hero", "H5", "crown", {"reach": CROWN_STEP})
	expr("hero", h5 - 0.3, "angry")
	# 11.36 knock knock on the urn (a step up to the stiff fox first): he topples
	key("hero", h5 + 0.4, H_S, y_f)
	key("hero", s_knock - 0.42, H_K, y_f, {"mode": "out"})
	move("hero", h5 + 0.4, "walk", {"fade": 0.1})
	strike("hero", s_knock, "knock")
	expr("hero", s_knock - 0.4, "happy")
	move("hero", s_knock + 0.3, "fight_idle", {"fade": 0.2})
	# Lọ runs: turned after him
	key("hero", s_down + 0.1, H_K, y_f)
	key("hero", _sr(13.4), H_K, CineTimeline.face(H_K, L0))
	look("hero", s_down + 0.1, story_end, "lo")
	expr("hero", _sr(13.6), "done")


func _lo() -> void:
	CastD7.dress(self, "lo")
	var y0: float = CineTimeline.face(L0, P0)
	key("lo", 0.0, L0, y0)
	move("lo", 0.0, "cradle")
	expr("lo", 0.0, "angry")
	look("lo", 0.0, h2 - 0.2, "hero")
	# his antique urn, held like a cat; flung off his hands in despair over the burst vase (the release at hit 0.4 of "fling")
	hold("lo", 0.0, s_rel, "antique_urn", {"bone": "Wrist.L", "mid": "Wrist.R", "offset": Vector3(0.0, 0.02, -0.04)})
	var y_t: float = CineTimeline.face(L0, H_S)
	key("lo", h2, L0, y0)
	key("lo", s_rel - 0.25, L0, y_t, {"mode": "out"})
	look("lo", h2 - 0.2, s_rel + 0.3, Vector3(SURFACE.x, 1.3, SURFACE.z))   # his vase bursting
	expr("lo", h2, "surprised")
	strike("lo", s_rel, "fling")
	expr("lo", s_rel, "pain")
	look("lo", s_rel + 0.3, story_end, "hero")
	# the crown: he backs off, then sprints for the roof stairs in the tail, still running at the end
	move("lo", h5 + 0.2, "cornered", {"fade": 0.25})
	expr("lo", h5 + 0.1, "surprised")
	var y_r: float = CineTimeline.face(L0, L0 + RUN_DIR)
	key("lo", s_go - 0.2, L0, y_t)
	key("lo", s_go, L0, y_r)
	move("lo", s_go - 0.05, "sprint", {"fade": 0.12})
	key("lo", s_go + RUN_ACCEL, L0 + RUN_DIR * (RUN_SPEED * RUN_ACCEL * 0.5), y_r, {"mode": "in"})
	key("lo", story_end, L_RUN, y_r, {"mode": "linear"})


func _wolf() -> void:
	StoryCast.dress(self, "wolf", "guard_wolf")
	var y_b: float = CineTimeline.face(W_B, P0)
	key("wolf", 0.0, W0, CineTimeline.face(W0, P0))
	move("wolf", 0.0, "fight_idle")
	move("wolf", _sr(0.2), "head_shake", {"fade": 0.15})   # blinking in the light
	move("wolf", _sr(0.9), "fight_idle", {"fade": 0.2})
	key("wolf", _sr(1.3), W0, CineTimeline.face(W0, W_A))
	move("wolf", _sr(1.3), "jog", {"fade": 0.15})
	key("wolf", _sr(2.3), W_A, y_b, {"mode": "out"})
	move("wolf", _sr(2.25), "walk", {"fade": 0.12})   # arms down: clear of the protagonist's guard
	look("wolf", 0.0, h1, "hero")
	# walks up cracking his neck at the protagonist: the bonk lands mid-crack
	key("wolf", _sr(2.4), W_A, y_b)
	key("wolf", h1 - 0.12, W_B, y_b, {"mode": "out"})
	strike("wolf", h1 - 0.06, "neck_crack")
	expr("wolf", h1, "pain")
	move("wolf", h1 + 0.03, "stunned", {"fade": 0.1})
	key("wolf", h1 + 0.02, W_B, y_b)
	key("wolf", h1 + 0.35, W_R, y_b + REEL_TURN, {"mode": "out"})
	fx_at(h1 + 0.25, "stars", "wolf", {"until": story_end})
	# sits down hard where he stands (4.11)
	move("wolf", s_sit - 0.4, "sit_down", {"fade": 0.12})
	move("wolf", s_sit, "slumped", {"fade": 0.05})


func _sheep() -> void:
	StoryCast.dress(self, "sheep", "guard_sheep")
	var y_g: float = CineTimeline.face(S_G, P0)
	key("sheep", 0.0, S0, CineTimeline.face(S0, P0))
	move("sheep", 0.0, "fight_idle")
	look("sheep", 0.0, h2, "hero")
	key("sheep", _sr(2.9), S0, CineTimeline.face(S0, S_W))
	move("sheep", _sr(2.9), "walk", {"fade": 0.15})
	key("sheep", _sr(4.3), S_W, y_g, {"mode": "out"})
	move("sheep", _sr(4.25), "fight_idle", {"fade": 0.12})
	# 4.73 the headbutt, one lunge in (its step and the keys add up to standing at S_G from the impact on)
	strike("sheep", x1, "headbutt", {"reach": D_LUNGE})
	key("sheep", x1, S_W, y_g)
	key("sheep", x1 + 0.3, S_G, y_g)
	# pawing the floor like a bull at the matador, then the charge, head down: 6.39 his head into the vase
	move("sheep", x1 + 0.35, "paw", {"fade": 0.15})
	strike("sheep", "H2", "ram", {"dur": (h2 - s_charge) / 0.85})
	key("sheep", s_charge, S_G, y_g)
	key("sheep", h2, S_V, y_g, {"mode": "in"})
	expr("sheep", x1, "angry")
	expr("sheep", h2, "pain")
	# frozen in the shards (the freeze), back on his feet, then he keels over flat on his back where he stands (7.23)
	strike("sheep", s_fall + 0.1 * FALL_DUR, "thrown", {"dur": FALL_DUR})
	key("sheep", s_fall, S_V, y_g)
	_topple("sheep", s_fall, s_land, S_V, -DIR_S, y_g, "thrown")
	move("sheep", s_land - 0.03, "lie_flat", {"fade": 0.1})
	key("sheep", story_end, S_DOWN, y_g)
	fx_at(h2 + 0.15, "stars", "sheep", {"until": story_end})


func _fox() -> void:
	StoryCast.dress(self, "fox", "guard_fox")
	var y0: float = CineTimeline.face(F0, P0)
	var y_c: float = CineTimeline.face(F_C, H_S)
	key("fox", 0.0, F0, y0)
	move("fox", 0.0, "fight_idle")
	look("fox", 0.0, h5, "hero")
	# creeps up behind the protagonist while he catches the urn; cowers at the whip-round
	key("fox", s_creep, F0, y0)
	key("fox", s_creep + 0.2, F0, CineTimeline.face(F0, F_C))
	move("fox", s_creep, "walk", {"fade": 0.15})
	key("fox", h5 - 0.36, F_C, y_c, {"mode": "out"})
	move("fox", h5 - 0.4, "cower", {"fade": 0.12})
	expr("fox", h5 - 0.3, "surprised")
	# the urn on his head: he straightens up under it stiff as a post; knocked on, he topples like a felled tree, the urn
	# still on
	hold("fox", s_on, story_end, "antique_urn", {"bone": "Head", "offset": Vector3(0.023, 0.145, -0.065), "rot": Vector3(180.0, 0.0, 0.0)})
	move("fox", h5 + 0.36, "rigid", {"fade": 0.25})
	move("fox", s_tp, "plank", {"fade": 0.05, "dur": PLANK_DUR})
	key("fox", s_tp, F_C, y_c)
	_topple("fox", s_tp, s_tp + PLANK_DUR, F_C, DIR_F, y_c, "plank")
	move("fox", s_down, "lie_flat", {"fade": 0.08})
	key("fox", story_end, F_DOWN, y_c)
	fx_at(s_down + 0.25, "stars", "fox", {"until": story_end})


func _shots() -> void:
	push_in("P1", 0.0, "hero", {"from": 3.6, "to": 2.5, "side_deg": 20.0, "look_y": 1.3, "fov": 40.0})
	ots_shot("O1", _sr(1.43), "hero", "lo", {"side": 1.0, "fov": 40.0})
	two_shot("T1", _sr(2.25), "hero", "wolf", {"side": 1.0, "fov": 44.0, "look_y": 1.1, "height": 1.35, "dist": 2.7})
	two_shot("T2", _sr(3.91), "hero", "sheep", {"side": -1.0, "fov": 46.0, "look_y": 1.12, "height": 1.3, "dist": 2.4})
	shot("S1", _sr(5.57), "static", "side-on, low: the bull's charge, the matador's sidestep, the sheep's dive into the vase (6.39), the keel-over (7.23)",
		{"pos": Vector3(1.1, 1.0, 5.2), "look": Vector3(1.2, 0.95, 1.0), "fov": 50.0, "hand": 0.3})
	hero_shot("L1", _sr(7.3), "lo", {"side_deg": 15.0, "dist": 2.6, "fov": 46.0})
	ots_shot("C1", _sr(7.95), "lo", "hero", {"side": -1.0, "fov": 44.0})
	shot("V1", _sr(9.25), "static", "from straight above: the protagonist whips round and jumps, the urn comes down over the fox's head (9.70)",
		{"pos": (H_S + F_C) * 0.5 + Vector3(0.35, 4.1, 0.9), "look": (H_S + F_C) * 0.5 + Vector3(0.0, 0.9, 0.0), "fov": 52.0, "hand": 0.2})
	shot("S2", _sr(10.25), "static", "low along the floor past the sheep's head: he groans his line on his back, the fox stiff under the urn behind",
		{"pos": Vector3(-2.2, 0.55, -0.9), "look": Vector3(1.1, 0.75, 1.35), "fov": 46.0, "hand": 0.3})
	two_shot("T3", _sr(11.05), "hero", "fox", {"side": 1.0, "fov": 46.0, "look_y": 0.9, "height": 1.3, "dist": 3.0})
	shot("K1", _sr(12.6), "track", "tracking Lọ: the helicopter line, then his sprint for the roof stairs",
		{"actor": "lo", "offset": Vector3(1.4, 1.5, 2.8), "look": Vector3(0.0, 1.1, 0.0), "fov": 46.0, "hand": 0.3})
	punch(h1, "light")
	punch(x1, "medium")


func _fx_sfx() -> void:
	# the breakers clunk back on, the tubes buzz, the gold lights stutter up
	sfx_at(0.02, "door_bang", -8.0)
	sfx_at(0.05, "fluoro_buzz", -6.0)
	for e: Array in [[0.18, 0.6], [0.36, 0.8], [R_LIGHT, 1.1]]:
		fx_at(_sr(float(e[0])), "flash", HALL + Vector3(0.0, 3.6, -1.5), {"power": float(e[1])})
	# the bonk: the clonk
	sfx_at(h1, "helmet_clonk", 0.0)
	sfx_at(h1, "impact_medium", -6.0)
	fx_at(h1, "sparks", "wolf:Head", {"power": 0.5})
	sfx_at(s_sit, "body_fall", -5.0)
	# the headbutt, the flashlight clattering away
	sfx_at(x1, "impact_medium", -3.0)
	fx_at(x1, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(s_torch, "tray_clang", -10.0)
	# H2: the charge, the vase bursts on his head (crate_break hides it), the keel-over
	sfx_at(s_charge, "whoosh_down", -8.0)
	sfx_at("H2", "glass_crack", 0.0)
	sfx_at("H2", "crate_smash", -6.0)
	fx_at("H2", "crate", "surface", {"power": 0.8, "dir": Vector3(1.0, 0.6, 0.0)})
	fx_at("H2", "debris", SURFACE + Vector3(0.0, CinePropsD7.PLINTH_H + 0.3, 0.0), {"power": 0.9, "dir": Vector3(-0.4, 0.8, 0.0)})
	sfx_at(s_land, "body_fall", -2.0)
	fx_at(s_land, "dust", "sheep:Hips", {"power": 0.8})
	# the fling, the catch
	sfx_at(s_rel, "whoosh_down", -4.0)
	sfx_at("A1", "impact_light", -6.0)
	sfx_at(a1 + 0.02, "freeze_tick", -8.0)
	# H5: the urn over the fox's head, a muffled groan inside it
	sfx_at(h5 - 0.2, "whoosh_down", -5.0)
	sfx_at("H5", "pot_clonk", 0.0)
	sfx_at("H5", "impact_heavy", -8.0)
	fx_at("H5", "flash", "fox:Head", {"power": 0.6})
	sfx_at(s_on + 0.1, "groan", -6.0)
	# knock knock, the timber fall
	sfx_at(s_knock - 0.15, "pot_clonk", -8.0)
	sfx_at(s_knock, "pot_clonk", -4.0)
	sfx_at(s_down, "body_fall", -2.0)
	fx_at(s_down, "dust", "fox:Hips", {"power": 0.9})
	sfx_at(s_go + 0.1, "slide_whistle", -8.0)


func _subs() -> void:
	sub(0.4, 2.15, "lo", "Có điện thì sao? Tụi bay, xử lý nó!")
	sub(7.3, 0.8, "lo", "Bình của tao!")
	sub(10.3, 1.65, "sheep", "Lương có năm triệu thôi mà!")
	joke(10.3, "the sheep guard quits from the floor: the pay is only five million")
	sub(12.1, 2.05, "lo", "...Gọi trực thăng. Lên sân thượng!")
