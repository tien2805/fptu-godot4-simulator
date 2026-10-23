# File: res://scripts/cine/timelines/seg_d1_brawl.gd
# seg_d1_brawl (25.000 s, spec 2026-10-23-story-phase-a1-cinematics-design.md section 13, plan Task 7 + controller re-time):
# Day 1, the protagonist against three fictional couriers at the road edge outside the campus west gate, night.
# Music: the owner's cut of "I've Gotta Be Me" (user://music/seg_d1_brawl.mp3, 26.87 s, ~112 bpm, starts on frame 0).
# Every impact sits on one of its strong onsets: each hit carries {"r": onset} so CineClock places it at that REAL time
# (story times are derived in build()). The finisher at 12.71 holds slow motion over the long sustained vocal (12.7-22 s):
# Mũ Vàng sails through the air, the camera orbits, the protagonist front-flips below; he crashes into the crate stack on the
# 21.99 hit (a non-ramp FX/SFX event, no freeze: tail rule A1-D8); 22-25 s at 1x: the comic tail.
# Stage: campus_west_gate, road-aligned yaw 46°, centre 12 m to the road side (plan review M4, Task 5 spot: ring 0, floor
# 0.05). Stage frame: X right (+X toward the gate, 12 m away; X < -1.25 is the D1 roadway), -Z forward along the road,
# ground y = 0; yaw in degrees (characters face -Z at 0). Everything stays inside the 14 x 10 box (|x| <= 7, |z| <= 5),
# clear of the lamp post (7.3, -4), the bollards (6.6, ±7.1), the barrier arm (x 15.1) and the gate roof (x 12).
extends CineTimeline

const TAIL: float = 3.0                        # real seconds at 1x after the finisher ramp (22.000 -> 25.000)
const CRASH_R: float = 21.99                   # the track's hit at the end of the sustained note

const H0 := Vector3(-4.9, 0.0, 0.4)
const P_TAKEOFF := Vector3(-3.05, 0.0, 0.34)
const P_H1 := Vector3(-1.85, 0.0, 0.3)
const P_LAND := Vector3(-1.5, 0.0, 0.3)
const P_JAB := Vector3(-1.27, 0.0, 0.16)
const P_CROSS := Vector3(-1.24, 0.0, 0.14)
const P_UP := Vector3(-1.05, 0.0, 0.02)
const P_DODGE := Vector3(-1.05, 0.0, 0.0)
const P_RH := Vector3(-0.95, 0.0, 0.05)
const P_HUR := Vector3(-0.75, 0.0, 0.08)
const P_FLIP_LAND := Vector3(1.3, 0.0, 0.0)
const P_PHONE_LOOK := Vector3(2.55, 0.0, -0.1)

const C1_0 := Vector3(-1.0, 0.0, 0.3)
const C1_DOWN := Vector3(2.3, 0.0, 0.15)
const P_C1K := Vector3(-0.2, 0.0, -0.1)
const P_C1H6 := Vector3(0.1, 0.0, 0.0)
const C1_CRASH := Vector3(4.75, 0.3, -0.55)
const C1_REST := Vector3(5.0, 0.0, -0.3)

const C2_0 := Vector3(0.4, 0.0, -1.5)
const P_HOOK := Vector3(-0.77, 0.0, -0.2)
const P_C2A := Vector3(-0.55, 0.0, -0.33)
const P_C2B := Vector3(-0.36, 0.0, -0.5)
const P_C2C := Vector3(-0.38, 0.0, -0.52)
const C2_DOWN := Vector3(0.9, 0.0, -2.9)

const C3_0 := Vector3(1.2, 0.0, 1.9)
const P_C3H := Vector3(-0.4, 0.0, 0.75)
const P_C3R := Vector3(-0.3, 0.0, 0.72)
const C3_DOWN := Vector3(1.5, 0.0, 2.6)

const CRATES := Vector3(5.3, 0.0, -0.7)
const SCOOTER := Vector3(3.0, 0.0, -1.6)
const BANANA := Vector3(1.55, 0.0, -3.45)
const PHONE := Vector3(3.4, 0.0, -0.25)

# story times derived from the real-time placement (filled in build())
var h1: float
var a1: float
var h2: float
var xs: float          # the cross on the 7.72 onset (no ramp)
var h3: float
var a2: float
var h4: float
var h5: float
var h6: float
var sc: float          # the crash on 21.99


## Story time at real time r (after the ramps are placed).
func _sr(r: float) -> float:
	return clock.story_at(r)


func build() -> void:
	slot = "seg_d1_brawl"
	length = 25.0
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5   # A2 sets 0 when this segment flows straight into cine_d1 (spec 8.1)
	stage = {"landmark": "campus_west_gate", "near": 30.0, "size": Vector2(14.0, 10.0), "tod": "night", "yaw_deg": 46.0,
		"offset": Vector2(-12.0, 0.0), "fallback": "campus_parking_center"}
	_cast()
	_hits()
	clock.length = length
	clock.build()
	# exact length: the finisher ramp ends at real 22.000, then TAIL story seconds at 1x -> 25.000
	story_end = float(clock.ramp("H6")["s1"]) + TAIL
	clock.story_end = story_end
	h1 = story_time("H1")
	a1 = story_time("A1")
	h2 = story_time("H2")
	xs = _sr(7.72)
	h3 = story_time("H3")
	a2 = story_time("A2")
	h4 = story_time("H4")
	h5 = story_time("H5")
	h6 = story_time("H6")
	sc = _sr(CRASH_R)
	_props()
	_hero()
	_c1()
	_c2()
	_c3()
	_shots()
	_fx_sfx()
	_subs()


func _cast() -> void:
	actor("hero", {"preset": "player", "seed": 2805, "female": false, "hair_style": "spiky", "name": "Hero"}, "Bạn", Color("#F37021"))
	actor("c1", {"preset": "rider", "seed": 101, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#C9A227"),
		"helmet_color": Color("#F1C40F"), "name": "ShipperMuVang"}, "Shipper Mũ Vàng", Color("#F1C40F"))
	actor("c2", {"preset": "rider", "seed": 102, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#8E2A2A"),
		"helmet_color": Color("#E74C3C"), "name": "ShipperMuDo"}, "Shipper Mũ Đỏ", Color("#FF6B5A"))
	actor("c3", {"preset": "rider", "seed": 103, "female": false, "body": "hoodie", "backpack": false, "shirt_color": Color("#1E8C8C"),
		"helmet_color": Color("#3498DB"), "name": "ShipperMuXanh"}, "Shipper Mũ Xanh", Color("#5DADE2"))


## Ramps on the track's onsets (real s, {"r": ...}; the story-time argument only orders them). Overrides keep neighbouring
## ramps from overlapping; the finisher's long hold (hq 8.74 s at k 0.25) carries the slow motion to real 22.000 (validated
## by the Tasks 3+4 review). Contact pairs (att -> tgt) are checked on every tier by tests/test_cine_d1_brawl.gd.
func _hits() -> void:
	hit("H1", 2.4, "heavy", "LEFT flying kick -> Mũ Vàng launched past the scooter", {"r": 2.76, "att": "hero:Foot.L", "tgt": "c1:Chest"})
	hit("A1", 4.7, "accent", "block Mũ Đỏ's hook", {"r": 6.15, "att": "c2:hands", "tgt": "hero:hands"})
	hit("H2", 5.3, "light", "jab -> Mũ Đỏ", {"r": 7.17, "att": "hero:hands", "tgt": "c2:Head"})
	hit("H3", 6.1, "medium", "uppercut -> Mũ Đỏ launched to the kerb", {"r": 8.48, "hq": 0.2, "att": "hero:hands", "tgt": "c2:Head"})
	hit("A2", 6.5, "accent", "duck under Mũ Xanh's haymaker (near miss)", {"r": 9.30, "ri": 0.1, "hp": 0.15, "hq": 0.25, "ro": 0.2})
	hit("H4", 6.9, "heavy", "roundhouse -> Mũ Xanh launched", {"r": 10.14, "ri": 0.15, "hp": 0.2, "att": "hero:feet", "tgt": "c3:torso"})
	hit("H5", 7.5, "light", "block Mũ Vàng's flying knee", {"r": 11.76, "att": "c1:knees", "tgt": "hero:hands"})
	hit("H6", 8.0, "finisher", "hurricane kick -> Mũ Vàng sails through the air in slow motion", {"r": 12.71, "hp": 0.2, "hq": 8.74,
		"att": "hero:feet", "tgt": "c1:torso"})


func _props() -> void:
	prop("crates", "crate_stack", CRATES, 15.0)
	prop("scooter", "scooter", SCOOTER, 121.0, {"headlight": true})   # headlight on the fight
	prop("banana", "banana", BANANA, 30.0)
	prop("phone", "phone", PHONE, 25.0, {"glow_at": _sr(23.55)})


func _hero() -> void:
	var y0: float = face(H0, C1_0)
	key("hero", 0.0, H0, y0)
	move("hero", 0.0, "fight_idle")
	expr("hero", 0.3, "angry")
	# 1.45 onset: the run-up; the flying kick (LEFT foot on every tier) lands on 2.76
	key("hero", 1.45, H0, y0)
	move("hero", 1.45, "sprint")
	key("hero", h1 - 0.45, P_TAKEOFF, y0, {"mode": "linear"})
	strike("hero", "H1", "flying_kick")
	key("hero", h1, P_H1, y0, {"mode": "linear"})
	key("hero", h1 + 0.45, P_LAND, y0, {"mode": "out"})
	move("hero", h1 + 0.45, "fight_idle", {"fade": 0.2})
	# Mũ Đỏ: block the hook (6.15), jab (7.17), cross (7.72), uppercut (8.48)
	var y_c2: float = face(P_LAND, P_HOOK)
	key("hero", a1 - 0.6, P_LAND, y_c2)
	strike("hero", "A1", "block")
	key("hero", a1, P_LAND, y_c2)
	strike("hero", "H2", "jab")
	key("hero", h2, P_JAB, face(P_JAB, P_C2A))
	strike("hero", xs, "cross")
	key("hero", xs, P_CROSS, face(P_CROSS, P_C2B))
	strike("hero", "H3", "uppercut")
	key("hero", h3, P_UP, face(P_UP, P_C2C))
	key("hero", h3 + 0.1, P_UP, face(P_UP, P_C2C))
	# Mũ Xanh from behind: duck the haymaker (9.30), roundhouse (10.14)
	strike("hero", "A2", "dodge", {"dur": 0.5})
	key("hero", a2, P_DODGE, face(P_DODGE, P_C3H))
	strike("hero", "H4", "roundhouse", {"dur": 0.7})
	key("hero", h4, P_RH, face(P_RH, P_C3R))
	# Mũ Vàng is back: block the flying knee (11.76), hurricane kick (12.71)
	var y_c1: float = face(P_RH, P_C1K)
	key("hero", h4 + 0.3, P_RH, y_c1)
	strike("hero", "H5", "block", {"dur": 0.6})
	key("hero", h5, P_RH, y_c1)
	strike("hero", "H6", "hurricane_kick", {"dur": 0.8})
	key("hero", h6, P_HUR, face(P_HUR, P_C1H6))
	# slow motion over the sustained note: land, then a front flip after the flying courier
	var y_fl: float = face(P_HUR, P_FLIP_LAND)
	move("hero", h6 + 0.4, "fight_idle", {"fade": 0.15})
	key("hero", h6 + 0.45, P_HUR, y_fl)
	move("hero", h6 + 0.6, "front_flip")
	key("hero", h6 + 0.6 + 0.18, P_HUR + Vector3(0.1, 0.0, 0.0), y_fl)
	key("hero", h6 + 0.6 + 1.02, P_FLIP_LAND, y_fl, {"mode": "linear"})
	move("hero", h6 + 0.6 + 1.2, "fight_idle", {"fade": 0.2})
	# tail: the phone lights up on the ground
	expr("hero", sc + 0.15, "happy")
	var y_ph: float = face(P_FLIP_LAND, PHONE)
	key("hero", sc + 0.5, P_FLIP_LAND, y_ph)
	move("hero", sc + 0.5, "walk")
	key("hero", sc + 1.35, P_PHONE_LOOK, y_ph, {"mode": "out"})
	move("hero", sc + 1.35, "fight_idle", {"fade": 0.25})
	look("hero", sc + 1.2, story_end, PHONE)
	expr("hero", _sr(23.6), "surprised")


func _c1() -> void:
	var y_c1: float = face(C1_0, H0)
	key("c1", 0.0, C1_0, y_c1)
	move("c1", 0.0, "taunt")
	expr("c1", 0.0, "happy")
	move("c1", 1.6, "fight_idle", {"fade": 0.2})
	expr("c1", 2.0, "surprised")
	# H1: launched past the scooter
	strike("c1", "H1", "launched_back")
	expr("c1", h1, "pain")
	key("c1", h1, C1_0, y_c1)
	key("c1", h1 + 0.75, C1_DOWN, y_c1, {"mode": "linear", "arc": 1.0})
	move("c1", h1 - 0.08 + 1.6, "lie")
	# gets up angry while the others fight, sprints in, flying knee (blocked on 11.76)
	move("c1", 5.0, "get_up", {"dur": 1.7})
	expr("c1", 6.2, "angry")
	var y_back: float = face(C1_DOWN, P_RH)
	key("c1", 6.7, C1_DOWN, y_back)
	move("c1", 6.7, "sprint")
	strike("c1", "H5", "knee_strike")
	key("c1", h5, P_C1K, y_back, {"mode": "linear"})
	key("c1", h5 + 0.25, P_C1H6, y_back, {"mode": "out"})
	key("c1", h6, P_C1H6, y_back)
	# H6: hurricane kick -> a slow tumbling flight over the sustained note, into the crates on 21.99
	strike("c1", "H6", "launched_back", {"dur": 2.4})
	expr("c1", h6, "pain")
	key("c1", sc, C1_CRASH, y_back, {"mode": "linear", "arc": 2.2, "spin": Vector3(0.0, 360.0, 0.0)})
	key("c1", sc + 0.35, C1_REST, y_back, {"mode": "out", "spin": Vector3(0.0, 360.0, 0.0)})
	move("c1", sc + 0.3, "lie")
	expr("c1", sc + 0.4, "done")


func _c2() -> void:
	var y_c2: float = face(C2_0, H0)
	key("c2", 0.0, C2_0, y_c2)
	move("c2", 0.0, "fight_idle")
	expr("c2", 0.3, "angry")
	var y_hook: float = face(P_HOOK, P_LAND)
	key("c2", 3.55, C2_0, y_hook)
	move("c2", 3.55, "jog")
	key("c2", a1 - 0.385, P_HOOK, y_hook, {"mode": "linear"})
	strike("c2", "A1", "hook")
	key("c2", a1, P_HOOK, y_hook)
	strike("c2", "H2", "hit_head")
	expr("c2", h2, "pain")
	key("c2", h2, P_C2A, y_hook)
	key("c2", xs - 0.05, P_C2B, y_hook, {"mode": "out"})
	strike("c2", xs, "hit_stomach")
	key("c2", xs, P_C2B, y_hook)
	key("c2", h3 - 0.1, P_C2C, y_hook, {"mode": "out"})
	strike("c2", "H3", "launched_back")
	key("c2", h3, P_C2C, y_hook)
	key("c2", _sr(9.83), C2_DOWN, y_hook, {"mode": "linear", "arc": 0.9})
	move("c2", h3 - 0.08 + 1.6, "lie")
	expr("c2", 8.0, "done")
	# tail: gets up, wanders off and slips on the banana peel
	move("c2", 9.6, "get_up", {"dur": 1.6})
	var y_away: float = face(C2_DOWN, BANANA)
	key("c2", 11.2, C2_DOWN, y_away)
	move("c2", 11.2, "walk")
	var s_slip: float = 11.8
	strike("c2", s_slip, "slip_fall")
	expr("c2", s_slip - 0.05, "surprised")
	key("c2", s_slip, BANANA, y_away, {"mode": "linear"})
	key("c2", s_slip + 0.4, BANANA + Vector3(0.35, 0.0, -0.25), y_away, {"mode": "out"})
	expr("c2", s_slip + 0.4, "pain")
	move("c2", s_slip - 0.36 + 1.2, "lie")


func _c3() -> void:
	var y_c3: float = face(C3_0, H0)
	key("c3", 0.0, C3_0, y_c3)
	move("c3", 0.0, "fight_idle")
	expr("c3", 0.3, "angry")
	var y_run: float = face(C3_0, P_DODGE)
	key("c3", 5.45, C3_0, y_run)
	move("c3", 5.45, "sprint")
	key("c3", a2 - 0.385, P_C3H, y_run, {"mode": "linear"})
	strike("c3", "A2", "hook")
	key("c3", a2, P_C3H, y_run)
	expr("c3", a2 + 0.1, "surprised")
	var y_hit: float = face(P_C3R, P_RH)
	strike("c3", "H4", "launched_back")
	expr("c3", h4, "pain")
	key("c3", h4, P_C3R, y_hit)
	key("c3", h4 + 0.55, C3_DOWN, y_hit, {"mode": "linear", "arc": 1.0})
	move("c3", h4 - 0.08 + 1.6, "lie")
	expr("c3", 8.0, "done")


func _shots() -> void:
	shot("S1", 0.0, "dolly", "wide establishing from the road: three couriers block the west gate, night; Mũ Vàng taunts",
		{"from": Vector3(-8.6, 2.0, 3.6), "to": Vector3(-7.7, 1.7, 2.9), "look_from": Vector3(0.0, 1.1, 0.2), "look_to": Vector3(-0.6, 1.1, 0.2), "fov": 50.0})
	shot("S2", _sr(1.45), "track", "low behind the protagonist on the run-up (onset 1.45)",
		{"actor": "hero", "offset": Vector3(-1.7, 0.55, 1.3), "look": Vector3(2.6, 1.0, -0.1), "fov": 58.0})
	shot("S3", h1, "orbit", "bullet-time orbit: the left flying kick lands on 2.76, Mũ Vàng flies past the scooter",
		{"center": Vector3(-1.2, 1.15, 0.3), "radius": 3.0, "deg_from": -25.0, "deg_to": 45.0, "height": 1.0, "fov": 46.0})
	shot("S4", _sr(5.89), "static", "side medium: Mũ Đỏ's hook is blocked (6.15)",
		{"pos": Vector3(-1.2, 1.45, 2.9), "look": Vector3(-1.05, 1.3, -0.05), "fov": 42.0})
	shot("S5", h2, "track", "over the shoulder: the jab (7.17)",
		{"actor": "hero", "offset": Vector3(-0.75, 1.55, 0.85), "look_actor": "c2", "look": Vector3(0.0, 1.35, 0.0), "fov": 38.0})
	shot("S6", xs, "low_hero", "low angle: the cross (7.72) and the uppercut launches Mũ Đỏ (8.48)",
		{"actor": "hero", "side_deg": 35.0, "dist": 2.2, "fov": 52.0})
	shot("S7", _sr(9.02), "static", "Mũ Xanh charges from behind, the protagonist ducks the haymaker (9.30)",
		{"pos": Vector3(-2.9, 1.25, 2.4), "look": Vector3(-0.6, 1.05, 0.35), "fov": 46.0})
	shot("S8", _sr(9.83), "static", "wide: the roundhouse launches Mũ Xanh (10.14)",
		{"pos": Vector3(-2.2, 1.55, -2.7), "look": Vector3(0.3, 0.9, 1.1), "fov": 54.0})
	shot("S9", _sr(10.73), "dolly", "Mũ Vàng is back: sprint, flying knee, blocked (11.76)",
		{"from": Vector3(-0.4, 1.15, 3.3), "to": Vector3(-0.2, 1.3, 2.7), "look_from": Vector3(1.4, 1.0, 0.1), "look_to": Vector3(-0.4, 1.3, 0.1), "fov": 46.0})
	shot("S10", _sr(12.13), "orbit", "rising orbit: the hurricane kick (12.71) launches Mũ Vàng into a slow flat-spinning flight",
		{"center_actor": "c1", "center_y": 1.0, "radius": 3.6, "deg_from": 20.0, "deg_to": 95.0, "height_from": 1.2, "height_to": 3.2, "fov": 50.0})
	shot("S11", _sr(15.92), "crane", "low wide: Mũ Vàng sails overhead while the protagonist front-flips after him",
		{"from": Vector3(-1.6, 0.35, 3.6), "to": Vector3(-1.2, 1.3, 4.3), "look_from": Vector3(0.9, 1.8, 0.0), "look_to": Vector3(2.4, 2.3, -0.3), "fov": 56.0})
	shot("S12", _sr(19.14), "dolly", "push in as Mũ Vàng comes down toward the crate stack",
		{"from": Vector3(0.8, 1.1, 3.9), "to": Vector3(1.6, 0.95, 2.9), "look_from": Vector3(4.0, 1.7, -0.4), "look_to": Vector3(4.8, 0.9, -0.6), "fov": 56.0})
	shot("S13", sc, "static", "crate close-up: the stack explodes on the 21.99 hit",
		{"pos": Vector3(3.5, 0.85, 1.9), "look": Vector3(5.2, 0.6, -0.6), "fov": 42.0})
	shot("S14", _sr(22.53), "dolly", "tail: Mũ Vàng in the debris, Mũ Đỏ slips on the banana peel, the protagonist walks over",
		{"from": Vector3(-0.2, 1.9, 4.6), "to": Vector3(0.6, 1.6, 3.9), "look_from": Vector3(2.9, 0.6, -0.9), "look_to": Vector3(2.7, 0.5, -1.1), "fov": 52.0})
	shot("S15", _sr(23.60), "static", "medium: the dropped phone lights up with the next clue at the protagonist's feet, engines roar in the distance",
		{"pos": Vector3(3.2, 1.15, 2.7), "look": Vector3(3.0, 0.8, -0.2), "fov": 50.0})


func _fx_sfx() -> void:
	fx_at("H1", "sparks", "c1:Chest", {"power": 1.0})
	fx_at("H1", "flash", "c1:Chest", {"power": 1.0})
	fx_at(_sr(3.02), "sparks", "c1:Head", {"power": 0.35})
	sfx_at(_sr(3.02), "impact_light", -7.0)                    # 3.02: the helmet clacks
	fx_at(h1 + 0.75, "dust", "c1:Hips", {"power": 0.8})
	sfx_at(h1 + 0.75, "body_fall", -2.0)
	sfx_at(_sr(5.89), "whoosh_down", -6.0)                     # 5.89: Mũ Đỏ winds up the hook
	fx_at("A1", "sparks", "hero:LowerArm.L", {"power": 0.3})
	sfx_at("A1", "impact_light", -4.0)
	fx_at("H2", "sparks", "c2:Head", {"power": 0.4})
	fx_at(xs, "sparks", "c2:Chest", {"power": 0.45})
	sfx_at(xs, "impact_light", 0.0)                             # 7.72: the cross
	fx_at("H3", "sparks", "c2:Head", {"power": 0.8})
	fx_at("H3", "flash", "c2:Head", {"power": 0.6})
	sfx_at(_sr(9.02), "whoosh_down", -7.0)                     # 9.02: Mũ Xanh's haymaker
	fx_at(_sr(9.83), "dust", "c2:Hips", {"power": 0.7})
	sfx_at(_sr(9.83), "body_fall", -2.0)                       # 9.83: Mũ Đỏ hits the kerb
	fx_at("H4", "sparks", "c3:Chest", {"power": 1.0})
	fx_at("H4", "flash", "c3:Chest", {"power": 1.0})
	fx_at(h4 + 0.55, "dust", "c3:Hips", {"power": 0.8})
	sfx_at(h4 + 0.55, "body_fall", -2.0)
	fx_at("H5", "sparks", "hero:LowerArm.R", {"power": 0.35})
	sfx_at(_sr(12.13), "whoosh_down", -5.0)                    # 12.13: the hurricane kick spins up
	fx_at("H6", "sparks", "c1:Chest", {"power": 1.2})
	fx_at("H6", "flash", "c1:Chest", {"power": 1.2})
	fx_at("H6", "dust", "hero", {"power": 0.6})
	fx_at(h6 + 0.6 + 1.02, "dust", "hero", {"power": 0.5})      # the front flip lands
	# 21.99: the crash (no freeze, tail rule)
	fx_at(sc, "crate", "crates", {"power": 1.2, "dir": Vector3(0.8, 0.35, -0.2)})
	fx_at(sc, "flash", "crates", {"power": 1.0})
	fx_at(sc, "debris", "c1:Hips", {"power": 0.7})
	fx_at(sc, "dust", "c1:Hips", {"power": 1.0})
	sfx_at(sc, "crate_smash", 0.0)
	sfx_at(sc, "impact_heavy", -1.0)
	sfx_at(sc + 0.35, "body_fall", -3.0)
	fx_at(h4 + 0.7, "stars", "c3", {"until": story_end})
	fx_at(sc + 0.5, "stars", "c1", {"until": story_end})
	sfx_at(sc + 0.55, "groan", -4.0)
	sfx_at(11.55, "slide_whistle", -2.0)
	sfx_at(12.2, "body_fall", -3.0)
	sfx_at(_sr(23.55), "phone_buzz", -4.0)
	sfx_at(_sr(24.1), "engine_roar", -5.0)
	sfx_at(_sr(24.2), "phone_buzz", -5.0)


func _subs() -> void:
	sub(0.55, 0.8, "hero", "Gét gô!")
	sub(22.55, 1.0, "c1", "Ui da… đơn này… bom thật rồi…")
	sub(23.7, 1.25, "hero", "Ơ… điện thoại ai sáng kìa?")
