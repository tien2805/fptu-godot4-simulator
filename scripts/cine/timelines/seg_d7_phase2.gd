# File: res://scripts/cine/timelines/seg_d7_phase2.gd
# seg_d7_phase2 (14.190 s, story spec 8.3 "light returns, heroic"; reworked by plan 2026-11-05-w6-fights task 5: its own
# choreography, cameras and signature, off the CineFightC template; every hit on a snare of the owner's "The Power of
# Love" re-cut from 153.76 s of the original, see the music note below). After the blackout (d7_boss2's "after"): both
# breakers are back on, the gold lights flicker up over the vase gallery, and Lùm Văn Lọ, cradling his favourite antique
# urn like a cat, sends his last three masked guards in.
#   0.0  black, the breakers clunk, the lights flicker up (0.59); the protagonist still holds the blackout flashlight;
#        Lọ: "Có điện thì sao? Tụi bay, xử lý nó!"
#   3.07 H1  the wolf-masked guard steps up cracking his neck at the protagonist: a hopping overhand flashlight bonk on
#            the top of his head mid-crack (slow motion: clonk); he reels, seeing stars, and sits down hard (4.35)
#   4.73     the sheep-masked guard lunges in with a headbutt and catches the protagonist admiring the flashlight (normal
#            speed, punch-in); the flashlight flies off and clatters on the floor (5.15); the sheep grabs the collar
#   6.39 H2  out of the clinch (5.98), a hip throw: the sheep flips backwards over the surface plinth, his back sweeping
#            its vase off (slow motion, heavy: the vase bursts), and lands flat on his back beyond it (7.23)
#            Lọ, mid wind-up: "Bình của tao!" and he hurls his own antique urn at the protagonist
#   8.05 A1  the signature: the protagonist catches the spinning urn two-handed, mouth down (slow-motion accent)
#   9.70 H5  finisher: the fox-masked guard creeps up behind and cowers; the protagonist whips round and, in one jump,
#            slams the urn down over the fox's head (one 2.5 s swell); the fox gets up blind under it, gropes, and
#            topples flat on his back (12.19), the urn still on his head
#  10.30     joke: the sheep, from the floor: "Lương có năm triệu thôi mà!"
#  12.19-14.19 tail at 1x: Lọ: "...Gọi trực thăng. Lên sân thượng!" and he runs for the roof
# Music: the owner's "The Power of Love" re-cut from 153.76 s of the original (W6); every hit, the hit taken, the vase crash
# and both falls sit on its 72 bpm snare / beat grid within 0.1 s (the bonk, the headbutt, the crown on its strongest
# snares). No gore: clonks, shards of porcelain, stars, an urn over a head. Contacts are measured on every tier by
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
const TAIL: float = 2.0
## Real times of the beats (beats of the music cut, see the header).
const R_LIGHT: float = 0.59
const R_H1: float = 3.07
const R_X1: float = 4.73
const R_GRAB: float = 5.98
const R_H2: float = 6.39
const R_LAND: float = 7.23
const R_REL: float = 7.45
const R_A1: float = 8.05
const R_H5: float = 9.70
const SWELL_END: float = 12.19
const R_DOWN: float = 12.19

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
const D_HB: float = 0.65            # the sheep's headbutt
const D_HT: float = 0.8             # the clinch and the hip throw
const D_CR: float = 0.97            # the jumping crown (with its CROWN_STEP in)
const CROWN_STEP: float = 0.28      # the crown jumps this far toward the fox
const D_LUNGE: float = 0.2          # the sheep's headbutt lunges in this far (from S_W to S_G)
const D_BACK: float = 0.3           # the wolf waits this far beyond his bonk spot
const D_REEL: float = 0.6           # ... and reels this far back, turning away (REEL_TURN), to sit down there
const REEL_TURN: float = 70.0
## Where the sheep's flight meets the vase (fraction of the flight: CineMoves "flung" hit_u, measured on the evaluated
## flight; the arc, the flip and the pose all run on the flight's own clock).
const FLUNG_HIT: float = 0.362

# positions
const P0 := Vector3(0.45, 0.0, 1.0)          # the protagonist, flashlight in hand
const L0 := Vector3(0.2, 0.0, -2.4)          # Lọ with his urn
const L_EXIT := Vector3(-6.8, 0.0, -3.4)     # off the left edge (toward the roof stairs)
const W0 := Vector3(-2.7, 0.0, -1.3)
const DIR_W := Vector3(-0.351, 0.0, -0.936)  # from the protagonist to the wolf at the bonk
const S0 := Vector3(1.2, 0.0, -1.6)          # (his walk in keeps off the surface plinth)
const S_G := Vector3(1.6, 0.0, 0.75)         # the sheep at the headbutt and the clinch (the throw goes +X over the plinth)
const S_LAND := Vector3(4.15, 0.0, 0.75)     # his hips after the throw (feet clear of the plinth)
const F0 := Vector3(-1.8, 0.0, 3.6)
const DIR_F := Vector3(-0.33, 0.0, 0.944)    # from the protagonist to the fox at the crown
## The flashlight off the protagonist's hand at the headbutt and where it lands.
const TORCH_FLOOR := Vector3(1.55, 0.034, -0.45)

var W_B: Vector3      # the wolf at the bonk
var W_A: Vector3      # ... waiting
var W_R: Vector3      # ... reeling, sitting down (his legs out of everyone's way)
var S_W: Vector3      # the sheep waiting for the headbutt
var H_X: Vector3      # the protagonist at the headbutt
var H_T: Vector3      # ... at the clinch / the throw / the catch
var F_C: Vector3      # the fox at the crown
var F_DOWN: Vector3
var torch_hand: Vector3   # the flashlight's grip when it leaves the hand (local to the protagonist, measured)

# story times
var h1: float
var x1: float
var s_grab: float
var h2: float
var slam_s: float     # the sheep's body into the surface plinth's vase
var s_fly: float      # ... he leaves the ground
var s_land: float
var s_rel: float      # the urn leaves Lọ's hands
var a1: float         # ... and lands in the protagonist's
var h5: float
var s_on: float       # the protagonist lands: the urn sits on the fox's shoulders
var s_tp: float       # the fox starts to topple
var s_down: float     # ... flat on his back
var s_torch: float    # the flashlight on the floor
var s_go: float       # Lọ runs
var s_gone: float


func _sr(r: float) -> float:
	return clock.story_at(r)


func build() -> void:
	slot = "seg_d7_phase2"
	length = LENGTH
	mood = "punchy"
	fade_in = 0.6
	fade_out = 0.5
	stage = {"at": Vector2(3930.0, -440.0), "size": Vector2(28.0, 24.0), "yaw_deg": 21.0, "landmark": "be6_center",
		"near": 30.0, "tod": "dawn", "exposure": 1.2, "ambient": 1.3}
	_cast()
	_hits()
	clock.length = length
	clock.tail_rule = false   # the W6 fights' short tail: 2 s at 1x after the swell (CineClock's 3-4 s rule is off)
	clock.build()
	story_end = float(clock.ramp("H5")["s1"]) + TAIL
	clock.story_end = story_end
	h1 = story_time("H1")
	h2 = story_time("H2")
	a1 = story_time("A1")
	h5 = story_time("H5")
	x1 = _sr(R_X1)
	s_grab = _sr(R_GRAB)
	slam_s = h2
	s_land = _sr(R_LAND)
	s_fly = (h2 - FLUNG_HIT * s_land) / (1.0 - FLUNG_HIT)   # the flight meets the vase at FLUNG_HIT of the way
	s_rel = _sr(R_REL)
	s_on = h5 + 0.1
	s_down = _sr(R_DOWN) - 0.02
	s_tp = s_down - 0.36
	s_torch = x1 + 0.42
	s_go = _sr(13.05)
	s_gone = _sr(14.0)
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


## Real-time ramps on the music's beats ({"r": ...}; the story times are placeholders the clock recomputes). Contact pairs
## are checked on every tier by tests/test_cine_d7_phase2.gd.
func _hits() -> void:
	hit("H1", 2.4, "medium", "mid neck-crack, a hopping overhand flashlight bonk on top of the wolf-masked guard's head: clonk",
		{"r": R_H1, "att": "hero:flashlight", "tgt": "wolf:Head"})
	hit("H2", 5.2, "heavy", "out of the clinch, a hip throw: the sheep-masked guard flips backwards over the surface plinth, its vase bursts",
		{"r": R_H2, "att": "hero:hands", "tgt": "sheep:torso"})
	hit("A1", 6.5, "accent", "slow-motion accent: the protagonist catches Lọ's hurled antique urn two-handed, mouth down",
		{"r": R_A1})
	hit("H5", 7.6, "finisher", "the jumping crown: the caught urn slammed down over the fox-masked guard's head (swell)",
		{"r": R_H5, "hq": SWELL_END - R_H5 - 0.55, "att": "hero:urn", "tgt": "fox:Head"})


func _layout() -> void:
	W_B = P0 + DIR_W * D_BK
	W_A = W_B + DIR_W * D_BACK
	W_R = W_B + DIR_W * D_REEL
	S_W = S_G + Vector3(D_LUNGE, 0.0, 0.0)
	H_X = S_G - Vector3(D_HB, 0.0, 0.0)
	H_T = S_G - Vector3(D_HT, 0.0, 0.0)
	F_C = H_T + DIR_F * D_CR
	F_DOWN = F_C + DIR_F * 0.55
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
	# the surface plinth the sheep is thrown over (its vase bursts) and the spare one, both on the hall's own spots
	prop("surface", "plinth", SURFACE, 0.0, {"vase": SEED_SURFACE})
	prop("plinth_l", "plinth", SPARE, 0.0, {"vase": SEED_SPARE})
	# the flashlight knocked out of the protagonist's hand by the headbutt: a tumble to the floor, still lit
	var yh: float = deg_to_rad(CineTimeline.face(H_X, S_G))
	var p0: Vector3 = H_X + Basis(Vector3.UP, yh) * torch_hand
	prop("torch", "flashlight", TORCH_FLOOR, 0.0, {"on": true, "show_at": x1,
		"path": [[x1, p0, Vector3(-15.0, rad_to_deg(yh), 0.0)], [s_torch, TORCH_FLOOR, Vector3(0.0, rad_to_deg(yh) + 250.0, 0.0)]],
		"arc": 0.35})
	# Lọ's urn in flight: from his hands at the release to the protagonist's at the catch, end over end (mouth down there)
	prop("urn_fly", "antique_urn", Vector3.ZERO, 0.0, {"show_at": s_rel, "hide_at": a1,
		"path": [[s_rel, _urn_release(), Vector3.ZERO], [a1, _urn_catch(), Vector3(540.0, 0.0, 0.0)]], "arc": 0.12})


## The urn's centre as it leaves Lọ's hands / reaches the protagonist's (stage frame; the wrists' mid point plus the hold
## offsets below, measured on the evaluated actors).
func _urn_release() -> Vector3:
	return L0 + Basis(Vector3.UP, deg_to_rad(CineTimeline.face(L0, H_T))) * Vector3(-0.02, 1.31, -0.635)


func _urn_catch() -> Vector3:
	return H_T + Basis(Vector3.UP, deg_to_rad(CineTimeline.face(H_T, L0))) * Vector3(-0.018, 1.419, -0.332)


# ---------------------------------------------------------------------------
# Actors (story times around the ramps are compressed: every key and cue is anchored on a REAL time through _sr())
# ---------------------------------------------------------------------------
func _hero() -> void:
	var y0: float = CineTimeline.face(P0, L0)
	key("hero", 0.0, P0, y0)
	move("hero", 0.0, "fight_idle")
	expr("hero", 0.0, "angry")
	look("hero", 0.0, _sr(1.6), "lo")
	# the flashlight: reverse of a torch grip, pointing forward-down (lit), until the headbutt knocks it away
	hold("hero", 0.0, x1, "flashlight", {"bone": "Wrist.R", "on": true, "offset": Vector3(0.0, 0.0, -0.04), "rot": Vector3(-15.0, 0.0, 0.0)})
	# 3.07 the bonk on the wolf (he stops to crack his neck)
	var y_w: float = CineTimeline.face(P0, W_B) + BONK_TURN
	key("hero", _sr(1.7), P0, y0)
	key("hero", _sr(2.2), P0, y_w)
	look("hero", _sr(1.6), h1 + 0.3, "wolf")
	strike("hero", "H1", "bonk")
	expr("hero", h1, "angry")
	# admires the flashlight, turned to the sheep coming in: his headbutt (4.73) knocks it out of the hand
	var y_s: float = CineTimeline.face(H_X, S_G)
	key("hero", _sr(3.95), P0, y_w)
	key("hero", _sr(4.15), P0, y_s)
	move("hero", _sr(4.0), "walk", {"fade": 0.15})
	key("hero", _sr(4.45), H_X, y_s, {"mode": "out"})
	move("hero", _sr(4.4), "hold_up", {"fade": 0.12})
	expr("hero", _sr(4.1), "happy")
	look("hero", _sr(4.0), _sr(4.6), Vector3(H_X.x + 0.3, 1.2, H_X.z + 0.2))
	move("hero", x1, "stunned", {"fade": 0.06})   # code on every tier: the headbutt lands on the same chest everywhere
	expr("hero", x1, "pain")
	key("hero", x1 + 0.04, H_X, y_s)
	key("hero", x1 + 0.4, H_T, y_s, {"mode": "out"})   # rocked back into the clinch
	look("hero", x1 + 0.1, h2 + 0.3, "sheep")
	expr("hero", _sr(5.4), "angry")
	# 5.98 the grab, 6.39 the hip throw sends him over the plinth
	strike("hero", s_grab, "hip_throw", {"dur": 0.6})
	# turned to Lọ's throw: 8.05 the catch (the signature)
	var y_l: float = CineTimeline.face(H_T, L0)
	key("hero", h2 + 0.22, H_T, y_s)
	key("hero", a1 - 0.08, H_T, y_l, {"mode": "out"})
	look("hero", h2 + 0.3, a1 + 0.2, "lo")
	strike("hero", "A1", "catch")
	hold("hero", a1, s_on, "antique_urn", {"bone": "Wrist.L", "mid": "Wrist.R", "offset": Vector3(0.0, 0.0, 0.0), "rot": Vector3(180.0, 0.0, 0.0)})
	expr("hero", a1, "happy")
	# whips round to the fox behind: 9.70 the jumping crown
	var y_f: float = CineTimeline.face(H_T, F_C)
	key("hero", a1 + 0.2, H_T, y_l)
	key("hero", h5 - 0.42, H_T, y_f + 360.0, {"mode": "out"})
	look("hero", a1 + 0.25, h5 + 0.6, "fox")
	strike("hero", "H5", "crown", {"reach": CROWN_STEP})
	expr("hero", h5 - 0.3, "angry")
	move("hero", h5 + 0.45, "fight_idle", {"fade": 0.25})
	expr("hero", s_down, "happy")
	key("hero", s_down, H_T, y_f + 360.0)
	key("hero", _sr(12.9), H_T, CineTimeline.face(H_T, L0) + 360.0)
	look("hero", _sr(12.6), story_end, "lo")
	expr("hero", _sr(13.6), "done")


func _lo() -> void:
	CastD7.dress(self, "lo")
	var y0: float = CineTimeline.face(L0, P0)
	key("lo", 0.0, L0, y0)
	move("lo", 0.0, "cradle")
	expr("lo", 0.0, "angry")
	look("lo", 0.0, story_end, "hero")
	# his antique urn, held like a cat; hurled at the protagonist (the release at hit 0.55 of "hurl")
	hold("lo", 0.0, s_rel, "antique_urn", {"bone": "Wrist.L", "mid": "Wrist.R", "offset": Vector3(0.0, 0.02, -0.04)})
	var y_t: float = CineTimeline.face(L0, H_T)
	key("lo", s_rel - 0.6, L0, y0)
	key("lo", s_rel - 0.3, L0, y_t)
	strike("lo", s_rel, "hurl")
	expr("lo", h2, "pain")
	expr("lo", s_rel, "angry")
	move("lo", s_rel + 0.45, "idle", {"fade": 0.2})
	# the crown: he backs off, then runs for the roof in the tail
	move("lo", h5 + 0.2, "cornered", {"fade": 0.2})
	expr("lo", h5 + 0.1, "surprised")
	key("lo", s_go - 0.2, L0, y_t)
	key("lo", s_go + 0.1, L0, CineTimeline.face(L0, L_EXIT))
	move("lo", s_go, "sprint", {"fade": 0.15})
	key("lo", s_gone, L_EXIT, CineTimeline.face(L0, L_EXIT), {"mode": "in"})
	show("lo", s_gone, false)


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
	move("wolf", _sr(2.25), "fight_idle", {"fade": 0.12})
	look("wolf", 0.0, h1, "hero")
	# steps up cracking his neck at the protagonist: the bonk lands mid-crack
	key("wolf", _sr(2.4), W_A, y_b)
	key("wolf", h1 - 0.12, W_B, y_b, {"mode": "out"})
	strike("wolf", h1 - 0.06, "neck_crack")
	expr("wolf", h1, "pain")
	move("wolf", h1 + 0.03, "stunned", {"fade": 0.1})
	key("wolf", h1 + 0.02, W_B, y_b)
	key("wolf", h1 + 0.3, W_R, y_b + REEL_TURN, {"mode": "out"})
	fx_at(h1 + 0.25, "stars", "wolf", {"until": story_end})
	# sits down hard where he stands (4.35)
	move("wolf", _sr(3.95), "sit_down", {"fade": 0.12})
	move("wolf", _sr(4.35), "slumped", {"fade": 0.05})


func _sheep() -> void:
	StoryCast.dress(self, "sheep", "guard_sheep")
	var y_g: float = CineTimeline.face(S_G, H_X)
	key("sheep", 0.0, S0, CineTimeline.face(S0, P0))
	move("sheep", 0.0, "fight_idle")
	look("sheep", 0.0, h2, "hero")
	key("sheep", _sr(2.9), S0, CineTimeline.face(S0, S_W))
	move("sheep", _sr(2.9), "walk", {"fade": 0.15})
	key("sheep", _sr(4.3), S_W, y_g, {"mode": "out"})
	move("sheep", _sr(4.25), "fight_idle", {"fade": 0.12})
	# 4.73 the headbutt, one lunge in (its step and the keys add up to standing at S_G from the impact on), then both
	# hands on the protagonist's collar
	strike("sheep", x1, "headbutt", {"reach": D_LUNGE})
	key("sheep", x1, S_W, y_g)
	key("sheep", x1 + 0.3, S_G, y_g)
	move("sheep", x1 + 0.3, "collar", {"fade": 0.15})
	# 5.98 grabbed, 6.39 over the hip and backwards over the surface plinth: his back sweeps its vase off; flat beyond it
	strike("sheep", "H2", "flung", {"dur": s_land - s_fly})   # loaded on the hip, then flung: the vase at FLUNG_HIT
	key("sheep", s_fly, S_G, y_g)
	key("sheep", s_land, S_LAND, y_g, {"mode": "linear", "arc": 1.0})   # "flung" flips him (CineMoves W6 phase2 block)
	move("sheep", s_land - 0.05, "lie_flat", {"fade": 0.1})
	key("sheep", story_end, S_LAND, y_g)
	expr("sheep", x1, "angry")
	expr("sheep", s_grab, "pain")
	fx_at(s_land + 0.3, "stars", "sheep", {"until": story_end})


func _fox() -> void:
	StoryCast.dress(self, "fox", "guard_fox")
	var y0: float = CineTimeline.face(F0, P0)
	var y_c: float = CineTimeline.face(F_C, H_T)
	key("fox", 0.0, F0, y0)
	move("fox", 0.0, "fight_idle")
	look("fox", 0.0, h5, "hero")
	# creeps up behind the protagonist while he catches the urn; cowers as it comes down
	key("fox", _sr(6.9), F0, y0)
	key("fox", _sr(7.05), F0, CineTimeline.face(F0, F_C))
	move("fox", _sr(6.9), "jog", {"fade": 0.15})
	key("fox", h5 - 0.36, F_C, y_c, {"mode": "out"})
	move("fox", h5 - 0.4, "cower", {"fade": 0.12})
	expr("fox", h5 - 0.3, "surprised")
	# the urn on his head: blind, he gropes, then topples flat on his back with it
	hold("fox", s_on, story_end, "antique_urn", {"bone": "Head", "offset": Vector3(0.023, 0.145, -0.065), "rot": Vector3(180.0, 0.0, 0.0)})
	move("fox", s_on, "grope", {"fade": 0.1})
	strike("fox", s_tp, "thrown", {"dur": 0.4})
	key("fox", s_tp, F_C, y_c)
	key("fox", s_down, F_DOWN, y_c, {"mode": "in"})
	move("fox", s_down + 0.02, "lie_flat", {"fade": 0.1})
	key("fox", story_end, F_DOWN, y_c)
	fx_at(s_down + 0.25, "stars", "fox", {"until": story_end})


func _shots() -> void:
	shot("K1", 0.0, "crane", "crane down from the gallery's ceiling as the gold lights flicker back on: Lọ with his urn, the protagonist with the flashlight, three masked guards",
		{"from": Vector3(-1.2, 5.6, 6.6), "to": Vector3(-0.6, 2.4, 5.2), "look_from": Vector3(0.3, 0.3, -0.6),
		"look_to": Vector3(0.3, 1.2, -0.7), "fov": 52.0, "hand": 0.2})
	dutch_shot("D1", _sr(0.75), "lo", {"roll": -14.0, "side_deg": 25.0, "dist": 2.8, "fov": 44.0})
	two_shot("T1", _sr(2.0), "hero", "wolf", {"side": 1.0, "fov": 44.0, "look_y": 1.25, "height": 1.45})
	shot("O1", _sr(2.65), "orbit", "slow-motion orbit: the wolf cracks his neck, the flashlight comes down on top of his head (3.07)",
		{"center": (P0 + W_B) * 0.5 + Vector3(0.0, 1.45, 0.0), "radius": 2.4, "deg_from": 115.0, "deg_to": 85.0, "height": 1.35,
		"fov": 46.0, "hand": 0.3})
	two_shot("T2", _sr(3.95), "hero", "sheep", {"side": -1.0, "fov": 46.0, "look_y": 1.12, "height": 1.3, "dist": 2.25})
	shot("S1", _sr(5.55), "static", "slow motion, low and side-on: the hip throw flips the sheep backwards over the plinth, its vase bursts (6.39)",
		{"pos": Vector3(2.4, 0.75, 4.6), "look": Vector3(2.5, 1.0, 0.75), "fov": 52.0, "hand": 0.35})
	dutch_shot("D2", _sr(7.15), "lo", {"roll": 14.0, "side_deg": -20.0, "dist": 2.6, "fov": 44.0})
	hero_shot("L1", _sr(7.75), "hero", {"side_deg": 20.0, "dist": 2.4, "fov": 50.0})
	shot("O2", _sr(8.55), "orbit", "slow-motion orbit: he whips round and jumps, the urn comes down over the fox's head (9.70)",
		{"center": (H_T + F_C) * 0.5 + Vector3(0.0, 1.5, 0.0), "radius": 2.8, "deg_from": 70.0, "deg_to": 110.0, "height": 1.3,
		"fov": 48.0, "hand": 0.3})
	shot("S2", _sr(10.75), "static", "slow motion, wide: the blind fox gropes under the urn and topples flat (12.19); the sheep groans from the floor",
		{"pos": Vector3(-2.6, 1.5, 4.4), "look": Vector3(1.0, 0.8, 1.2), "fov": 50.0, "hand": 0.3})
	push_in("P2", _sr(12.05), "lo", {"from": 4.4, "to": 3.0, "side_deg": 20.0, "fov": 42.0})
	shot("W1", _sr(13.25), "dolly", "tail wide: Lọ runs for the roof, guards down round the lit gallery, the fox under the urn",
		{"from": Vector3(3.2, 2.2, 5.0), "to": Vector3(2.9, 2.1, 4.6), "look_from": Vector3(-1.4, 0.8, -0.8),
		"look_to": Vector3(-1.8, 0.8, -0.9), "fov": 56.0, "hand": 0.4})
	punch(x1, "medium")


func _fx_sfx() -> void:
	# the breakers clunk back on, the tubes buzz, the gold lights flicker up
	sfx_at(0.02, "door_bang", -8.0)
	sfx_at(0.05, "fluoro_buzz", -6.0)
	for e: Array in [[0.18, 0.6], [0.36, 0.8], [R_LIGHT, 1.1]]:
		fx_at(_sr(float(e[0])), "flash", HALL + Vector3(0.0, 3.6, -1.5), {"power": float(e[1])})
	# H1: the clonk
	sfx_at("H1", "helmet_clonk", 0.0)
	sfx_at("H1", "impact_medium", -6.0)
	fx_at("H1", "sparks", "wolf:Head", {"power": 0.5})
	sfx_at(_sr(4.35), "body_fall", -5.0)
	# the headbutt, the flashlight clattering away
	sfx_at(x1, "impact_medium", -3.0)
	fx_at(x1, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(s_torch, "tray_clang", -10.0)
	# H2: over the plinth, the vase bursts (crate_break hides it), the landing
	sfx_at(s_grab, "whoosh_down", -6.0)
	sfx_at("H2", "glass_crack", 0.0)
	sfx_at("H2", "crate_smash", -6.0)
	fx_at("H2", "crate", "surface", {"power": 0.8, "dir": Vector3(1.0, 0.6, 0.0)})
	fx_at("H2", "debris", SURFACE + Vector3(0.0, CinePropsD7.PLINTH_H + 0.3, 0.0), {"power": 0.9, "dir": Vector3(0.6, 0.8, 0.0)})
	sfx_at(s_land, "body_fall", -2.0)
	fx_at(s_land, "dust", "sheep:Hips", {"power": 0.8})
	# the hurl, the catch
	sfx_at(s_rel, "whoosh_down", -4.0)
	sfx_at("A1", "impact_light", -6.0)
	sfx_at(a1 + 0.02, "freeze_tick", -8.0)
	# H5: the urn over the fox's head, a muffled groan inside it, the fall
	sfx_at(h5 - 0.2, "whoosh_down", -5.0)
	sfx_at("H5", "pot_clonk", 0.0)
	sfx_at("H5", "impact_heavy", -8.0)
	fx_at("H5", "flash", "fox:Head", {"power": 0.6})
	sfx_at(s_on + 0.1, "groan", -6.0)
	sfx_at(s_down, "body_fall", -2.0)
	fx_at(s_down, "dust", "fox:Hips", {"power": 0.9})
	sfx_at(s_go + 0.1, "slide_whistle", -8.0)


func _subs() -> void:
	sub(0.3, 2.15, "lo", "Có điện thì sao? Tụi bay, xử lý nó!")
	sub(6.55, 0.9, "lo", "Bình của tao!")
	sub(10.3, 1.7, "sheep", "Lương có năm triệu thôi mà!")
	joke(10.3, "the sheep guard quits from the floor: the pay is only five million")
	sub(12.08, 2.1, "lo", "...Gọi trực thăng. Lên sân thượng!")
