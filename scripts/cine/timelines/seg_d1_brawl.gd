# File: res://scripts/cine/timelines/seg_d1_brawl.gd
# seg_d1_brawl (25.000 s, spec 2026-10-23-story-phase-a1-cinematics-design.md section 13, plan Task 7; restaged in the style of
# the film *Nobody*, story spec section 8.1 amendment 2026-10-23 - a style homage, not a shot-for-shot copy):
# Day 1, the protagonist against three fictional couriers at the road edge outside the campus west gate, night. Grounded,
# messy, close-quarters: he asks politely to pass, gets shoved and sucker-punched flat, gets up, shakes his head, cracks his
# neck and goes to work - a gut punch and a slam into the scooter (Mũ Đỏ), a stomach punch taken, a headbutt into a helmet
# that hurts him more than the courier, a hip throw onto the asphalt (Mũ Xanh, whose helmet pops off), that helmet swung
# into Mũ Vàng's face, then a spear tackle that drives Mũ Vàng across the kerb in one long slow-motion stretch over the
# sustained note, into the crate stack on 21.99; the protagonist ends winded, hands on his knees; 22-25 s at 1x: the comic tail.
# Music: the owner's cut of "I've Gotta Be Me" (user://music/seg_d1_brawl.mp3, 26.87 s, ~112 bpm, starts on frame 0). Slow
# motion only on the four most painful / funniest impacts plus the finisher swell (each placed on its onset with {"r": onset},
# story times derived in build()); every other onset gets a cut, an SFX accent and / or a camera punch-in at normal speed.
# Stage: campus_west_gate, road-aligned yaw 46°, centre 12 m to the road side (plan review M4, Task 5 spot: ring 0, floor
# 0.05). Stage frame: X right (+X toward the gate, 12 m away; X < -1.25 is the D1 roadway), -Z forward along the road,
# ground y = 0; yaw in degrees (characters face -Z at 0). Everything stays inside the 14 x 10 box (|x| <= 7, |z| <= 5),
# clear of the lamp post (7.3, -4), the bollards (6.6, ±7.1), the barrier arm (x 15.1) and the gate roof (x 12).
extends CineTimeline

const TAIL: float = 3.0                        # real seconds at 1x after the finisher ramp (22.000 -> 25.000)
const CRASH_R: float = 21.99                   # the track's hit at the end of the sustained note

# the scooter parked on the roadway edge, its headlight on the fight; SC + k·L is k metres in front of its centre
const SCOOTER := Vector3(-3.3, 0.0, -1.6)
const SCOOTER_YAW: float = 160.0
# Spacing (m, root to root) of each exchange, set so bodies touch but never sink in on any tier (bone-capsule check in
# tests/test_cine_d1_brawl.gd): strikes land at full reach of the longest-reaching tier, the others fall short a little.
const D_SHOVE: float = 0.8                    # Mũ Vàng's shove
const D_HOOK: float = 0.97                     # the sucker punch
const K_C2: float = 1.62                       # Mũ Đỏ squares up just in front of the scooter (SC + K_C2·L)
const K_C2_HIT: float = 0.95                   # ... his back meets the headlight / handlebar here
const K_C2_SIT: float = 1.2                    # ... and he slides down to sit against the front wheel
const D_C2: float = 0.95                       # gut punch and arm's-length grab on Mũ Đỏ's collar
const D_C3: float = 1.0                        # Mũ Xanh's jab
const D_C1: float = 1.0                       # the helmet swing
const D_C1B: float = 1.25                       # Mũ Vàng staggers back to this after the helmet
const D_DRIVE: float = 0.81                     # tackle: his shoulder in Mũ Vàng's midriff, head beside his hip
const LAT_DRIVE: float = 0.25                  # ... offset to his left so the head passes beside the body
# opening: the protagonist walks up to Mũ Vàng, is shoved back and punched flat (falls toward -X onto the road)
const H0 := Vector3(-4.85, 0.0, 1.05)
const P_STOP := Vector3(-2.82, 0.0, 0.76)
const P_HIT := Vector3(-3.12, 0.0, 0.78)
const P_C3 := Vector3(-3.35, 0.0, 1.6)         # against Mũ Xanh (and Mũ Vàng)
const C1_0 := Vector3(-1.85, 0.0, 0.6)
const C1_REL := Vector3(-0.08, 0.0, -0.876)    # where he is thrown off into the crates
const C2_0 := Vector3(-1.3, 0.0, -0.5)
const C3_0 := Vector3(-1.45, 0.0, 1.95)
const C3_DOWN := Vector3(-3.95, 0.0, 2.9)
const DIR_C3 := Vector3(0.9503, 0.0, 0.3101)   # from P_C3 toward Mũ Xanh
const DIR_C1 := Vector3(0.8217, 0.0, -0.5699)  # from P_C3 toward Mũ Vàng
const CRATES := Vector3(1.2, 0.0, -1.75)
const BANANA := Vector3(-3.13, 0.0, 0.39)
const PHONE := Vector3(-0.55, 0.0, -0.1)
const HELMET_A := Vector3(-3.4, 0.02, 2.02)    # Mũ Xanh's helmet where it lands after the throw
const HELMET_B := Vector3(-3.1, 0.02, 1.95)    # dropped after the swing
const C3_HELMET := Color("#3498DB")

# positions derived from the spacing above (filled in _layout())
var C1_SHOVE: Vector3
var C1_HOOK: Vector3
var C1_BACK: Vector3
var P_SLAM: Vector3
var P_SLAM_BACK: Vector3
var C2_STAND: Vector3
var C2_HIT: Vector3
var C2_SIT: Vector3
var slam_s: float      # story time Mũ Đỏ's back meets the scooter (tests: contact + hit window)
var P_C3B: Vector3
var P_C1Y: Vector3
var P_C1B: Vector3
var DIR_DRIVE: Vector3
var P_TACKLE: Vector3
var P_REL: Vector3
var P_STUMBLE: Vector3
var C1_CRASH: Vector3
var C1_REST: Vector3

# story times derived from the real-time placement (filled in build())
var h1: float          # sucker punch (2.76)
var h2: float          # slam into the scooter (8.48)
var h3: float          # headbutt on the helmet (9.83)
var h4: float          # helmet into Mũ Vàng's face (11.76)
var h5: float          # spear tackle (12.71)
var xg: float          # gut punch on Mũ Đỏ (7.72, no ramp)
var xt: float          # hip throw (10.73, no ramp)
var sp: float          # picks the helmet up
var sc: float          # the crash on 21.99
var ss: float          # Mũ Đỏ slips on the banana (tail)


## Story time at real time r (after the ramps are placed).
func _sr(r: float) -> float:
	return clock.story_at(r)


## Stage point k metres in front of the scooter's centre (its front faces the fight).
static func _sc(k: float) -> Vector3:
	var y: float = deg_to_rad(SCOOTER_YAW)
	return SCOOTER + Vector3(-sin(y), 0.0, -cos(y)) * k


func build() -> void:
	slot = "seg_d1_brawl"
	length = 25.0
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5   # A2 sets 0 when this segment flows straight into cine_d1 (spec 8.1)
	stage = {"landmark": "campus_west_gate", "near": 30.0, "size": Vector2(14.0, 10.0), "tod": "night", "yaw_deg": 46.0,
		"offset": Vector2(-12.0, 0.0), "fallback": "campus_parking_center",
		"exposure": 1.4, "ambient": 1.8}   # owner: "hơi tối" - brighter night, faces and hits stay readable
	_cast()
	_hits()
	clock.length = length
	clock.build()
	# exact length: the finisher ramp ends at real 22.000, then TAIL story seconds at 1x -> 25.000
	story_end = float(clock.ramp("H5")["s1"]) + TAIL
	clock.story_end = story_end
	h1 = story_time("H1")
	h2 = story_time("H2")
	h3 = story_time("H3")
	h4 = story_time("H4")
	h5 = story_time("H5")
	xg = _sr(7.72)
	xt = _sr(10.73)
	sp = _sr(11.25)
	sc = _sr(CRASH_R)
	ss = _sr(23.43)
	_layout()
	_props()
	_hero()
	_c1()
	_c2()
	_c3()
	_shots()
	_fx_sfx()
	_subs()


func _layout() -> void:
	C1_SHOVE = P_STOP + Vector3(D_SHOVE, 0.0, 0.0)
	C1_HOOK = P_HIT + Vector3(D_HOOK, 0.0, 0.0)
	C1_BACK = C1_HOOK + Vector3(0.35, 0.0, 0.0)
	P_SLAM = _sc(K_C2 + D_C2)
	P_SLAM_BACK = P_SLAM + Vector3(0.94, 0.0, 0.342) * 0.6   # sideways, out of the line Mũ Đỏ falls along
	C2_STAND = _sc(K_C2)
	C2_HIT = _sc(K_C2_HIT)
	C2_SIT = _sc(K_C2_SIT)
	slam_s = h2 + 0.28
	P_C3B = P_C3 + DIR_C3 * D_C3
	P_C1Y = P_C3 + DIR_C1 * D_C1
	P_C1B = P_C3 + DIR_C1 * D_C1B
	DIR_DRIVE = (C1_REL - P_C1B).normalized()
	var lat: Vector3 = Vector3(DIR_DRIVE.z, 0.0, -DIR_DRIVE.x) * LAT_DRIVE   # to his left as he faces DIR_DRIVE
	P_TACKLE = P_C1B - DIR_DRIVE * D_DRIVE + lat
	P_REL = C1_REL - DIR_DRIVE * D_DRIVE + lat
	P_STUMBLE = P_REL - DIR_DRIVE * 0.25   # rocks back on his heels as he heaves him off
	C1_CRASH = CRATES - DIR_DRIVE * 1.1 + Vector3(0.0, 0.25, 0.0)
	C1_REST = CRATES - DIR_DRIVE * 0.95


func _cast() -> void:
	actor("hero", {"preset": "player", "seed": 2805, "female": false, "hair_style": "spiky", "name": "Hero"}, "Bạn", Color("#F37021"))
	actor("c1", {"preset": "rider", "seed": 101, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#C9A227"),
		"helmet_color": Color("#F1C40F"), "name": "ShipperMuVang"}, "Shipper Mũ Vàng", Color("#F1C40F"))
	actor("c2", {"preset": "rider", "seed": 102, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#8E2A2A"),
		"helmet_color": Color("#E74C3C"), "name": "ShipperMuDo"}, "Shipper Mũ Đỏ", Color("#FF6B5A"))
	actor("c3", {"preset": "rider", "seed": 103, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#1E8C8C"),
		"helmet_color": C3_HELMET, "name": "ShipperMuXanh"}, "Shipper Mũ Xanh", Color("#5DADE2"))


## Slow motion only on the four most painful / funniest impacts and the finisher swell, each on a strong onset (real s,
## {"r": ...}; the story-time argument only orders them). The finisher's long hold (hq 8.74 s at k 0.25) carries the slow
## motion to real 22.000 over the sustained note. Contact pairs (att -> tgt) are checked on every tier by
## tests/test_cine_d1_brawl.gd ("upper" = head, chest or upper arms).
func _hits() -> void:
	hit("H1", 2.4, "heavy", "Mũ Vàng's sucker punch: the protagonist goes down flat", {"r": 2.76, "att": "c1:hands", "tgt": "hero:Head"})
	# owner: the neck-crack close-up ("Gét gô.") in slow motion "cho ngầu" - an accent ramp (no freeze, no contact) on 7.17,
	# slow from 6.67 to 7.41 so the 7.72 gut punch stays at normal speed
	hit("N1", 5.9, "accent", "slow-motion close-up: he cracks his neck, deadpan \"Gét gô.\"", {"r": 7.17, "ri": 0.2, "hp": 0.3,
		"hq": 0.12, "ro": 0.12})
	hit("H2", 6.5, "medium", "Mũ Đỏ slammed back into the scooter", {"r": 8.48, "hq": 0.3, "att": "hero:hands", "tgt": "c2:torso"})
	hit("H3", 7.4, "light", "headbutt into Mũ Xanh's helmet: clonk (it hurts him more)", {"r": 9.83, "att": "hero:Head", "tgt": "c3:Head"})
	hit("H4", 8.9, "medium", "Mũ Xanh's own helmet swung into Mũ Vàng's face", {"r": 11.76, "hq": 0.2, "ro": 0.15,
		"att": "hero:hands", "tgt": "c1:Head"})
	hit("H5", 9.6, "finisher", "spear tackle: Mũ Vàng driven across the kerb in slow motion", {"r": 12.71, "hp": 0.2, "hq": 8.74,
		"att": "hero:upper", "tgt": "c1:torso"})


func _props() -> void:
	prop("crates", "crate_stack", CRATES, 15.0)
	prop("scooter", "scooter", SCOOTER, SCOOTER_YAW, {"headlight": true})   # headlight on the fight
	prop("banana", "banana", BANANA, 30.0)
	prop("phone", "phone", PHONE, 25.0, {"glow_at": _sr(23.55)})
	# Mũ Xanh's helmet: pops off in the throw, lands by the protagonist, is snatched up, swung, dropped
	# it leaves his head as he goes over the hip (xt + 0.06: hidden on him, this prop shown there) and tumbles to the road
	var pop: Vector3 = P_C3B.lerp(C3_DOWN, 0.12) + Vector3(-0.38, 1.75, -0.06)   # his head as he starts the flip (measured)
	prop("helmet_a", "helmet", HELMET_A, 70.0, {"color": C3_HELMET, "show_at": xt + 0.06, "hide_at": sp, "arc": 0.25,
		"path": [[xt + 0.06, pop, Vector3(0.0, 70.0, 0.0)], [xt + 0.22, HELMET_A, Vector3(720.0, 70.0, 0.0)]]})
	prop("helmet_b", "helmet", HELMET_B, -35.0, {"color": C3_HELMET, "show_at": _sr(12.13)})


func _hero() -> void:
	# 0-1.45: walks up to the couriers, deadpan, and asks to pass
	var y0: float = face(H0, P_STOP)
	key("hero", 0.0, H0, y0)
	move("hero", 0.0, "walk")
	key("hero", 1.2, P_STOP, y0, {"mode": "out"})
	move("hero", 1.2, "idle", {"fade": 0.2})
	# 1.45: shoved back a step; 2.76: Mũ Vàng's hook drops him flat on the road (slow motion, freeze on the jaw)
	strike("hero", 1.45, "hit_stomach")
	key("hero", 1.45, P_STOP, y0)
	key("hero", 1.85, P_HIT, y0, {"mode": "out"})
	move("hero", 2.05, "idle", {"fade": 0.2})
	strike("hero", "H1", "launched_back", {"dur": 1.3, "arc": 0.0})   # the keys carry the short flight
	expr("hero", h1, "pain")
	key("hero", h1, P_HIT, y0)
	key("hero", h1 + 0.12, P_HIT + Vector3(-0.2, 0.0, 0.0), y0, {"mode": "linear"})   # snapped back off the fist at once
	key("hero", h1 + 0.7, P_SLAM, y0, {"mode": "linear", "arc": 0.3})
	move("hero", h1 - 0.065 + 1.3, "lie")
	expr("hero", h1 + 0.8, "done")
	# gets up (groan on 5.89), shakes the stars off, turns to Mũ Đỏ cracking his neck (7.17), a deadpan beat
	var s_up: float = _sr(5.02)
	move("hero", s_up, "get_up", {"dur": 1.5})
	expr("hero", s_up, "pain")
	move("hero", s_up + 1.5, "head_shake", {"dur": 0.38, "fade": 0.15})
	var y_c2: float = face(P_SLAM, C2_STAND)
	key("hero", s_up + 1.5, P_SLAM, y0)
	key("hero", _sr(7.4), P_SLAM, y_c2)
	strike("hero", "N1", "neck_crack", {"dur": 0.5})   # plays through the slow-motion accent
	expr("hero", _sr(6.9), "open")
	# 7.72: gut punch, grab, 8.48: slams Mũ Đỏ back into the scooter, steps back off his legs
	strike("hero", xg, "uppercut", {"dur": 0.6, "reach": {"mixamo": Vector2(0.17, -0.03), "ual": 0.12, "native": 0.12, "code": 0.12}})   # a short uppercut to the body
	expr("hero", xg - 0.1, "angry")
	move("hero", xg + 0.22, "grab", {"fade": 0.12})
	strike("hero", "H2", "shove", {"reach": 0.1})
	key("hero", h2 + 0.05, P_SLAM, y_c2)
	key("hero", h2 + 0.06, P_SLAM_BACK, y_c2, {"mode": "out"})   # sidesteps Mũ Đỏ's legs as he goes down
	var y_c3: float = face(P_C3, P_C3B)
	move("hero", h2 + 0.25, "fight_idle", {"fade": 0.2})
	# Mũ Xanh from behind: turns into a stomach punch (9.30), headbutts his helmet (9.83), "ow" (10.14), hip throw (10.73)
	key("hero", _sr(9.27), P_C3, y_c3)
	strike("hero", _sr(9.30), "hit_stomach")
	expr("hero", _sr(9.30), "pain")
	strike("hero", "H3", "headbutt", {"reach": {"mixamo": 0.12, "ual": 0.12, "native": 0.12, "code": 0.12}})
	key("hero", h3 - 0.28, P_C3, y_c3)
	key("hero", h3, P_C3 + DIR_C3 * 0.25, y_c3, {"mode": "in"})     # steps into the headbutt
	key("hero", xt - 0.25, P_C3 + DIR_C3 * 0.05, y_c3)
	expr("hero", h3 - 0.15, "angry")
	strike("hero", _sr(10.14), "hit_head")
	expr("hero", _sr(10.14), "pain")
	strike("hero", xt, "hip_throw", {"dur": 0.6, "reach": {"mixamo": 0.15, "ual": 0.12, "native": 0.1, "code": 0.1}})
	expr("hero", xt - 0.1, "angry")
	# snatches the helmet up, swings it into Mũ Vàng's face (11.76)
	var y_hel: float = face(P_C3, HELMET_A)
	var y_c1: float = face(P_C3, P_C1Y)
	key("hero", xt + 0.3, P_C3, y_c3)
	key("hero", sp - 0.12, P_C3, y_hel)
	strike("hero", sp, "pickup", {"dur": 0.4})
	hold("hero", sp, _sr(12.13), "helmet", {"color": C3_HELMET, "offset": Vector3(0.0, 0.0, -0.1), "rot": Vector3(-90.0, 0.0, 0.0)})
	key("hero", h4 - 0.2, P_C3, y_c1)
	strike("hero", "H4", "cross", {"dur": 0.5, "reach": {"mixamo": -0.17}})   # a right straight, helmet first
	# 12.13 drops low; 12.71 spear tackle, then drives him across the kerb in slow motion; lets go before the crates
	strike("hero", "H5", "tackle")
	var y_dr: float = face(P_TACKLE, P_REL)
	key("hero", h5 - 0.27, P_C3, y_c1)
	key("hero", h5, P_TACKLE, y_dr, {"mode": "in"})
	move("hero", h5 + 0.15, "drive", {"fade": 0.1})
	key("hero", h5 + 0.35, P_TACKLE.lerp(P_REL, 0.07), y_dr)
	key("hero", sc - 0.3, P_REL, y_dr, {"mode": "linear"})
	move("hero", sc - 0.2, "winded", {"fade": 0.3})   # heaves him off the shoulder and folds, hands on knees
	key("hero", sc - 0.15, P_STUMBLE, y_dr, {"mode": "out"})
	expr("hero", sc - 0.3, "angry")
	expr("hero", sc + 0.1, "pain")
	# tail: gets his breath back, the phone lights up at his feet
	move("hero", sc + 1.05, "idle", {"fade": 0.35})
	var y_ph: float = face(P_STUMBLE, PHONE)
	key("hero", sc + 1.1, P_STUMBLE, y_dr)
	key("hero", sc + 1.55, P_STUMBLE, y_ph)
	look("hero", sc + 1.3, story_end, PHONE)
	expr("hero", sc + 0.9, "open")
	expr("hero", _sr(23.6), "surprised")


func _c1() -> void:
	var y_c1: float = face(C1_0, P_STOP)
	key("c1", 0.0, C1_0, y_c1)
	move("c1", 0.0, "taunt")
	expr("c1", 0.0, "happy")
	move("c1", 0.95, "fight_idle", {"fade": 0.15})
	# 1.45 shove, 2.76 the sucker punch
	strike("c1", 1.45, "shove", {"reach": {"mixamo": -0.06}})
	key("c1", 1.15, C1_0, y_c1)
	key("c1", 1.45, C1_SHOVE, y_c1, {"mode": "out"})
	expr("c1", 1.4, "angry")
	key("c1", 2.05, C1_SHOVE, y_c1)
	key("c1", h1 - 0.1, C1_HOOK, y_c1, {"mode": "out"})
	strike("c1", "H1", "cross", {"reach": {"mixamo": Vector2(0.05, 0.06), "ual": -0.02}})
	key("c1", h1 + 0.04, C1_HOOK, y_c1)
	key("c1", h1 + 0.4, C1_BACK, y_c1, {"mode": "out"})   # steps back to watch him fall
	move("c1", h1 + 0.45, "taunt", {"fade": 0.2})
	expr("c1", h1 + 0.3, "happy")
	move("c1", _sr(5.6), "fight_idle", {"fade": 0.2})
	# runs in at the protagonist after the throw, eats the helmet (11.76), sees stars
	var y_run: float = face(C1_BACK, P_C1Y)
	var y_hit: float = face(P_C1Y, P_C3)
	var s_run: float = _sr(10.95)
	var s_arr: float = _sr(11.3)
	key("c1", s_run - 0.15, C1_BACK, y_run)
	move("c1", s_run - 0.15, "sprint", {"fade": 0.15})
	key("c1", s_arr, P_C1Y, y_hit, {"mode": "linear"})
	move("c1", s_arr, "idle", {"fade": 0.15})   # squares up, hands low, chin out
	expr("c1", s_arr, "angry")
	strike("c1", "H4", "hit_head")
	key("c1", h4, P_C1Y, y_hit)
	key("c1", h4 + 0.35, P_C1B, y_hit, {"mode": "out"})   # staggers back off the helmet
	expr("c1", h4, "pain")
	move("c1", h4 + 0.2, "stunned", {"fade": 0.15})
	# 12.71 tackled: folded over the protagonist's shoulder, driven back across the kerb, thrown off into the crates on 21.99
	move("c1", h5 - 0.04, "doubled", {"fade": 0.08})   # folds straight over the shoulder (no clip arms in his midriff)
	var y_back: float = face(P_C1B, P_C1B - DIR_DRIVE)
	key("c1", h5, P_C1B, y_back)
	key("c1", h5 + 0.35, P_C1B.lerp(C1_REL, 0.07), y_back)
	key("c1", sc - 0.3, C1_REL, y_back, {"mode": "linear"})
	strike("c1", sc - 0.2, "launched_back", {"arc": 0.0})
	key("c1", sc, C1_CRASH, y_back, {"mode": "linear", "arc": 0.3})
	key("c1", sc + 0.35, C1_REST, y_back, {"mode": "out"})
	move("c1", sc - 0.2 - 0.08 + 1.6, "lie")
	expr("c1", sc + 0.4, "done")


func _c2() -> void:
	var y_c2: float = face(C2_0, P_STOP)
	key("c2", 0.0, C2_0, y_c2)
	move("c2", 0.0, "fight_idle")
	expr("c2", 0.3, "angry")
	move("c2", h1 + 0.3, "taunt", {"fade": 0.2})
	expr("c2", h1 + 0.3, "happy")
	move("c2", _sr(5.5), "fight_idle", {"fade": 0.2})
	expr("c2", _sr(6.0), "angry")
	# charges the protagonist, eats a gut punch (7.72), is grabbed and slammed back into the scooter (8.48)
	var y_in: float = face(C2_0, C2_STAND)
	var y_face: float = face(C2_STAND, P_SLAM)
	var s_jog: float = _sr(6.2)
	key("c2", s_jog, C2_0, y_in)
	move("c2", s_jog, "jog")
	key("c2", xg - 0.12, C2_STAND, y_face, {"mode": "linear"})
	move("c2", xg - 0.12, "idle", {"fade": 0.1})   # runs in arms low: the body shot lands
	strike("c2", xg, "hit_stomach")
	expr("c2", xg, "pain")
	move("c2", xg + 0.3, "stunned", {"fade": 0.15})   # held at arm's length by the collar
	strike("c2", "H2", "slammed")   # back into the scooter's headlight (slam_s), slides down to sit against the wheel
	key("c2", h2, C2_STAND, y_face)
	key("c2", slam_s, C2_HIT, y_face, {"mode": "out"})
	key("c2", h2 - 0.04 + 0.8, C2_SIT, y_face)
	move("c2", h2 - 0.04 + 0.8, "slumped", {"fade": 0.15})
	expr("c2", h2 + 0.5, "done")
	# end of the slow motion / tail: gets up, wanders toward Mũ Vàng and slips on the banana peel
	var s_up: float = _sr(19.43)
	var s_walk: float = _sr(22.83)
	move("c2", s_up, "get_up_sit", {"dur": s_walk - s_up})
	var y_away: float = face(C2_SIT, BANANA)
	key("c2", s_walk - 0.3, C2_SIT, y_face)   # no turning on the ground: he turns as he gets to his feet
	key("c2", s_walk, C2_SIT, y_away)
	move("c2", s_walk, "walk")
	strike("c2", ss, "slip_fall")
	expr("c2", ss - 0.05, "surprised")
	key("c2", ss, BANANA, y_away, {"mode": "linear"})
	var d_slip: Vector3 = (BANANA - C2_SIT).normalized() * 0.4
	key("c2", ss + 0.4, BANANA + d_slip, y_away, {"mode": "out"})
	expr("c2", ss + 0.4, "pain")
	move("c2", ss - 0.36 + 1.2, "lie")


func _c3() -> void:
	var y_c3: float = face(C3_0, P_STOP)
	key("c3", 0.0, C3_0, y_c3)
	move("c3", 0.0, "fight_idle")
	expr("c3", 0.3, "angry")
	move("c3", h1 + 0.35, "taunt", {"fade": 0.2})
	expr("c3", h1 + 0.35, "happy")
	move("c3", _sr(5.8), "fight_idle", {"fade": 0.2})
	expr("c3", _sr(7.4), "angry")
	# from behind: a jab to the stomach (9.30), takes the headbutt (9.83), hip-thrown onto the asphalt (10.73)
	var y_run: float = face(C3_0, P_C3B)
	var y_face: float = face(P_C3B, P_C3)
	var s_run: float = _sr(7.9)
	key("c3", s_run, C3_0, y_run)
	move("c3", s_run, "sprint")
	key("c3", _sr(9.2), P_C3B, y_face, {"mode": "linear"})
	strike("c3", _sr(9.30), "jab", {"reach": {"ual": 0.15, "native": 0.1}})
	strike("c3", "H3", "hit_head")
	expr("c3", h3, "pain")
	strike("c3", xt, "thrown")
	part("c3", xt + 0.06, "helmet", false)
	key("c3", xt, P_C3B, y_face)
	# over the hip: a forward flip (keys) while the code pose rolls onto the back, landing face up, head toward the thrower
	var y_land: float = face(P_C3B, C3_DOWN)
	key("c3", xt + 0.45, C3_DOWN, y_land, {"mode": "linear", "arc": 1.1, "spin": Vector3(-360.0, 0.0, 0.0)})
	move("c3", xt - 0.07 + 0.7, "lie_flat", {"fade": 0.15})   # stays on the code lying pose the throw ends on
	expr("c3", xt + 0.5, "done")


## Handheld ("hand"), tight and fast at normal speed; wide / orbiting only in the slow-motion stretches (plan review: cuts on
## onsets; S16 / S18 / S19 on the 112 bpm grid through the sustained note and tail).
func _shots() -> void:
	shot("S1", 0.0, "dolly", "wide from the road: the protagonist walks up to three couriers blocking the west gate, night",
		{"from": Vector3(-7.2, 1.7, 3.6), "to": Vector3(-6.6, 1.6, 3.1), "look_from": Vector3(-2.4, 1.1, 0.6),
		"look_to": Vector3(-2.6, 1.1, 0.6), "fov": 50.0, "hand": 0.3})
	shot("S2", 1.45, "track", "over his shoulder, handheld: Mũ Vàng shoves him back (onset 1.45)",
		{"actor": "hero", "offset": Vector3(-0.9, 1.6, 0.9), "look_actor": "c1", "look": Vector3(0.0, 1.3, 0.0), "fov": 40.0, "hand": 1.0})
	shot("S3", h1, "orbit", "slow-motion close orbit: the sucker punch lands on his jaw (2.76)",
		{"center": Vector3(-2.95, 1.3, 0.76), "radius": 1.6, "deg_from": 25.0, "deg_to": 55.0, "height": 1.35, "fov": 40.0, "hand": 0.3})
	shot("S4", _sr(3.02), "static", "low wide reverse: he topples back onto the road in slow motion (3.02)",
		{"pos": Vector3(-2.0, 0.6, 2.8), "look": Vector3(-3.6, 0.8, 0.8), "fov": 52.0, "hand": 0.4})
	shot("S5", _sr(5.89), "static", "low and tight, handheld: he drags himself up, groaning (5.89)",
		{"pos": Vector3(-3.44, 0.5, 2.6), "look": Vector3(-4.44, 0.65, 1.52), "fov": 44.0, "hand": 1.0})
	shot("S6", _sr(6.15), "static", "from behind him: the couriers laugh (6.15)",
		{"pos": Vector3(-5.8, 1.5, 2.2), "look": Vector3(-1.9, 1.2, 0.5), "fov": 42.0, "hand": 0.8})
	shot("S7", _sr(7.17), "static", "close-up: he cracks his neck, deadpan (7.17)",
		{"pos": Vector3(-3.99, 1.45, 0.3), "look": Vector3(-4.44, 1.35, 1.52), "fov": 38.0, "hand": 0.6})
	shot("S8", xg, "static", "side-on, handheld: gut punch, grab (7.72)",
		{"pos": Vector3(-2.77, 1.3, 1.62), "look": Vector3(-4.27, 1.1, 1.07), "fov": 44.0, "hand": 1.0})
	shot("S9", h2, "static", "slow motion, low wide: Mũ Đỏ slammed back into the scooter (8.48)",
		{"pos": Vector3(-2.4, 0.55, 1.4), "look": Vector3(-4.1, 0.7, 0.75), "fov": 50.0, "hand": 0.4})
	shot("S10", _sr(9.02), "static", "handheld two-shot: Mũ Xanh from behind, a jab to the stomach (9.30)",
		{"pos": Vector3(-3.5, 1.4, 3.65), "look": Vector3(-2.88, 1.15, 1.75), "fov": 42.0, "hand": 1.0})
	shot("S11", h3, "static", "slow motion, tight profile: the headbutt clonks on Mũ Xanh's helmet (9.83); \"ow\" (10.14)",
		{"pos": Vector3(-3.2, 1.35, 3.0), "look": Vector3(-2.8, 1.3, 1.78), "fov": 34.0, "hand": 0.3})
	shot("S12", xt, "static", "handheld wide: hip throw onto the asphalt, the helmet pops off; he snatches it up (10.73)",
		{"pos": Vector3(-1.7, 1.6, 3.6), "look": Vector3(-3.3, 0.9, 2.1), "fov": 50.0, "hand": 1.0})
	shot("S13", h4, "static", "slow motion over his shoulder: the helmet into Mũ Vàng's face (11.76)",
		{"pos": Vector3(-4.29, 1.4, 1.83), "look": Vector3(-2.53, 1.35, 1.03), "fov": 36.0, "hand": 0.3})
	shot("S14", _sr(12.13), "orbit", "low slow orbit: he drops low (12.13), the spear tackle (12.71), the drive begins",
		{"center_actor": "c1", "center_y": 0.9, "radius": 3.2, "deg_from": 10.0, "deg_to": 60.0, "height": 0.8, "fov": 46.0, "hand": 0.4})
	shot("S15", _sr(15.92), "track", "low side tracking: Mũ Vàng driven back across the kerb, legs churning",
		{"actor": "c1", "offset": Vector3(0.9, 0.45, 2.6), "look": Vector3(0.0, 1.0, 0.0), "fov": 50.0, "hand": 0.4})
	# Wave 6 (plan 2026-11-05-w6-cines T6): a close-up inside the swell, three beats into S15 on the 112 bpm grid
	shot("S15b", _sr(17.53), "track", "close tracking: Mũ Vàng folded over the shoulder, eyes wide, the kerb rushing past",
		{"actor": "c1", "offset": Vector3(0.35, 1.25, 1.3), "look": Vector3(0.0, 1.15, 0.0), "fov": 38.0, "hand": 0.4})
	shot("S16", _sr(19.14), "dolly", "push in as they near the crate stack",
		{"from": Vector3(-1.6, 1.2, 1.0), "to": Vector3(-0.9, 1.0, 0.4), "look_from": Vector3(-0.6, 0.9, -0.6),
		"look_to": Vector3(0.5, 0.8, -1.2), "fov": 54.0, "hand": 0.4})
	shot("S17", sc, "static", "crate close-up: he throws him off into the stack, it explodes on the 21.99 hit",
		{"pos": Vector3(0.0, 0.85, 0.75), "look": Vector3(0.7, 0.6, -1.3), "fov": 46.0, "hand": 0.8})
	shot("S18", _sr(22.53), "dolly", "tail wide: Mũ Vàng in the debris, the protagonist winded, Mũ Đỏ slips on the banana peel",
		{"from": Vector3(-2.6, 1.9, 2.4), "to": Vector3(-2.0, 1.7, 1.9), "look_from": Vector3(-2.3, 0.6, -0.4),
		"look_to": Vector3(-2.2, 0.5, -0.3), "fov": 52.0, "hand": 0.5})
	shot("S19", _sr(23.60), "static", "medium: the dropped phone lights up with the next clue at his feet, engines roar in the distance",
		{"pos": Vector3(-0.5, 1.15, 1.5), "look": Vector3(-0.8, 0.7, -0.35), "fov": 48.0, "hand": 0.6})
	# punch-ins / whips on the biggest hits without a ramp
	punch(1.45, "light")
	punch(xg, "medium")
	punch(_sr(9.30), "light")
	punch(xt, "medium")


func _fx_sfx() -> void:
	sfx_at(1.45, "impact_light", -5.0)                          # 1.45: the shove
	fx_at("H1", "sparks", "hero:Head", {"power": 0.5})
	fx_at("H1", "flash", "hero:Head", {"power": 0.8})
	sfx_at(_sr(3.02), "whoosh_down", -6.0)                     # 3.02: he topples
	fx_at(h1 + 0.7, "dust", "hero:Hips", {"power": 0.9})
	sfx_at(h1 + 0.7, "body_fall", -1.0)
	fx_at(h1 + 0.75, "stars", "hero", {"until": _sr(6.75)})
	sfx_at(_sr(5.89), "groan", -6.0)                           # 5.89: he drags himself up
	sfx_at(_sr(7.17), "neck_crack", 0.0)                       # 7.17: the neck crack
	sfx_at(_sr(7.17) + 0.2, "neck_crack", -4.0)
	sfx_at(xg, "impact_medium", -2.0)                           # 7.72: gut punch
	fx_at(xg, "sparks", "c2:Chest", {"power": 0.3})
	fx_at("H2", "dust", "c2:Hips", {"power": 0.5})
	fx_at(h2 + 0.3, "debris", _sc(0.9) + Vector3(0.0, 0.6, 0.0), {"power": 0.5, "dir": Vector3(0.3, 0.6, 0.5)})
	sfx_at(h2 + 0.3, "impact_heavy", -4.0)                      # back into the scooter's front
	fx_at(h2 + 0.45, "dust", "c2:Hips", {"power": 0.7})
	sfx_at(h2 + 0.45, "body_fall", -2.0)
	sfx_at(_sr(9.02), "whoosh_down", -7.0)                     # 9.02: Mũ Xanh charges
	sfx_at(_sr(9.30), "impact_light", -3.0)                    # 9.30: the jab to his stomach
	sfx_at("H3", "helmet_clonk", 0.0)
	fx_at("H3", "sparks", "c3:Head", {"power": 0.4})
	fx_at(h3 + 0.05, "stars", "hero", {"until": xt - 0.1})
	sfx_at(_sr(10.14), "groan", -9.0)                          # 10.14: "ow"
	sfx_at(xt, "whoosh_down", -4.0)                             # 10.73: the hip throw
	fx_at(xt + 0.45, "dust", "c3:Hips", {"power": 1.0})
	sfx_at(xt + 0.45, "body_fall", 0.0)
	sfx_at(xt + 0.5, "helmet_clonk", -10.0)                     # the helmet bounces on the asphalt
	sfx_at("H4", "helmet_clonk", -1.0)
	fx_at("H4", "sparks", "c1:Head", {"power": 0.6})
	fx_at("H4", "flash", "c1:Head", {"power": 0.6})
	fx_at(h4 + 0.2, "stars", "c1", {"until": h5})
	sfx_at(_sr(12.13), "whoosh_down", -5.0)                    # 12.13: he drops low
	fx_at("H5", "dust", "hero:Foot.L", {"power": 0.6})
	fx_at("H5", "flash", "c1:Chest", {"power": 0.7})
	# 21.99: the crash (no freeze, tail rule)
	fx_at(sc, "crate", "crates", {"power": 1.2, "dir": Vector3(0.8, 0.35, -0.4)})
	fx_at(sc, "flash", "crates", {"power": 1.0})
	fx_at(sc, "debris", "c1:Hips", {"power": 0.7})
	fx_at(sc, "dust", "c1:Hips", {"power": 1.0})
	sfx_at(sc, "crate_smash", 0.0)
	sfx_at(sc, "impact_heavy", -1.0)
	sfx_at(sc + 0.35, "body_fall", -3.0)
	fx_at(xt + 0.6, "stars", "c3", {"until": story_end})
	fx_at(sc + 0.5, "stars", "c1", {"until": story_end})
	sfx_at(sc + 0.55, "groan", -4.0)
	sfx_at(ss - 0.25, "slide_whistle", -2.0)
	sfx_at(ss + 0.4, "body_fall", -3.0)
	sfx_at(_sr(23.55), "phone_buzz", -4.0)
	sfx_at(_sr(24.1), "engine_roar", -5.0)
	sfx_at(_sr(24.2), "phone_buzz", -5.0)


func _subs() -> void:
	sub(0.35, 0.9, "hero", "Cho mình qua với.")
	sub(1.5, 0.75, "c1", "Đi đâu mà vội!")
	sub(7.3, 0.4, "hero", "Gét gô.")
	sub(22.55, 1.0, "c1", "Ui da... đơn này... bom thật rồi...")
	sub(23.7, 1.25, "hero", "Ơ... điện thoại ai sáng kìa?")
