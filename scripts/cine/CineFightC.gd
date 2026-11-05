# File: res://scripts/cine/CineFightC.gd
# Base of the Phase C full fight seg_d2_boss (spec C-D9; seg_d3_boss, seg_d4_brawl and seg_d5_boss have their own
# choreography since plan 2026-11-05-w6-fights): a Nobody-style cinematic built on the old seg_d4_brawl blocking (the
# surface-gap spacing, tuned on every tier), with the fight's own beat table T (real seconds on the owner's track onsets;
# every key and cue is derived from T, so the blocking follows). Length: the finisher swell ends SWELL (4.5 s) after H5,
# then a TAIL (3 s) at 1x, so the length is T.h5 + 7.5 (seg_d2_boss: 22.3 s).
#
# Roles (as in seg_d4_brawl):
#   "a"  the boss: H1 (weapon w1), reels away stunned, comes back for H4 (weapon w3), then the H5 finisher flies him into the
#        crash prop ("crates") inside the slow-motion swell (to real T.h5 + SWELL);
#   "b"  a henchman: his cross lands on the protagonist's jaw (x1), then H2 (w2, picked up off the floor) knocks him out;
#   "c"  a henchman: his jab to the protagonist's stomach (x2), then H3 shoves him back into the surface prop ("surface"),
#        where he slides down to sit;
#   "d"  a henchman: his straight right catches the protagonist (x3), the second one misses (A1, slow-motion accent: the
#        protagonist slips it), then he backs off and runs for the exit as the swell ends.
# The protagonist takes three hits at normal speed with punch-ins (x1, x2, x3); slow motion only on H1-H4, the A1 accent
# and the finisher swell.
#
# Per-fight signatures (cfg): "opener" (the boss attacks first at about h1 - 0.9: blocked or slipped, no contact), "a1_by":
# "a" (the slow-motion miss A1 is the boss's: d only throws x3 and leaves), "x2_move" (c's hit, e.g. a knee strike),
# "shots" (per-shot camera overrides), "floor_back" (how far behind the protagonist the w2 pickup lies), "a_blocks_h4".
# A subclass sets `cfg` in _configure() (see the keys used below) and may add its own cues in _extra(). Tests:
# tests/support/cine_fight.gd (tests/test_cine_d2_boss.gd).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0. Box 14 x 10 (|x| <= 7, |z| <= 5).
class_name CineFightC
extends CineTimeline

const TAIL: float = 3.0
const CRASH_DS: float = 0.86
## How far in front of the crash prop the boss lands (m; seg_d4_brawl's 1.55 + 0.2 for the taller Phase C bodies).
const CRASH_BACK: float = 1.75
## Default beat table (seg_d4_brawl's): impacts h1-h4, a1 (accent), h5 (finisher); hits taken x1-x3; pickups.
const T_DEFAULT: Dictionary = {"h1": 2.6, "x1": 3.9, "pick1": 4.75, "h2": 5.9, "x2": 7.6, "h3": 8.4, "pick2": 9.9, "h4": 11.2,
	"x3": 12.6, "a1": 13.6, "h5": 15.0}
## The finisher swell: real seconds from the H5 impact to the end of its ramp (was a fixed end at real 22.0, 7.2 s).
const SWELL: float = 4.5
## Story seconds d takes from his turn after the crash to the exit (a sprint of about 3.7 m).
const D_RUN: float = 0.95

# blocking (seg_d4_brawl)
const SURFACE_FACE_X: float = 2.225
const GRAB := Vector3(2.52, 0.95, -0.85)          # the w3 pickup spot (the soup pot's)
const CRATES := Vector3(-3.2, 0.0, -2.9)
const EXIT := Vector3(3.6, 0.0, -4.6)
const D_H1: float = 1.0
const D_C2X: float = 0.97
const D_H2: float = 1.05
const D_C3J: float = 1.0
const D_H3: float = 0.8
const D_H4: float = 0.95
const D_DH: float = 1.05
const D_H5: float = 1.05
const P0 := Vector3(0.0, 0.0, 1.0)
const A_0 := Vector3(1.4, 0.0, -1.2)
const B_0 := Vector3(-1.6, 0.0, -1.0)
const C_0 := Vector3(1.3, 0.0, 3.4)
const D_0 := Vector3(0.6, 0.0, -3.4)

var cfg: Dictionary = {}
var T: Dictionary = {}

var P1: Vector3
var P2: Vector3
var P2B: Vector3
var P3: Vector3
var FLOOR_ITEM: Vector3   # the w2 pickup on the floor
var D_B: Vector3
var A_A: Vector3
var A_B: Vector3
var B_A: Vector3
var B_B: Vector3
var B_DOWN: Vector3
var C_A: Vector3
var C_HIT: Vector3
var C_SIT: Vector3
var A_D: Vector3
var A_E: Vector3
var D_A: Vector3
var A_F: Vector3
var A_CRASH: Vector3
var A_REST: Vector3
var slam_s: float
var A_O: Vector3          # where the boss throws his opener from
var s_open: float = -1.0  # story time of the boss's opener (-1: none)
var h1: float
var h2: float
var h3: float
var h4: float
var a1: float
var h5: float
var x1: float
var x2: float
var x3: float
var s_pick1: float
var s_pick2: float
var sc: float
var s_run: float          # d turns and sprints for the exit
var s_gone: float
var swell_end: float      # real time the finisher swell ends (T.h5 + SWELL)


## Subclasses fill cfg: slot, stage, cast {role: cast id}, names {role: speaker}, T (overrides of T_DEFAULT), w1 / w2 / w3
## (weapon defs), surface / crashes / dressing props, sfx, subs, reach overrides.
func _configure() -> void:
	pass


## Extra cues of a fight (gags, LED eyes, the katana); called at the end of build().
func _extra() -> void:
	pass


func _sr(r: float) -> float:
	return clock.story_at(r)


static func _d(a: Vector3, b: Vector3) -> Vector3:
	var v: Vector3 = b - a
	v.y = 0.0
	return v.normalized()


func _t(k: String) -> float:
	return float(T[k])


## Real time of the boss's opener.
func _open_r() -> float:
	return float((cfg["opener"] as Dictionary).get("at", _t("h1") - 0.9))


func _a1_by_boss() -> bool:
	return String(cfg.get("a1_by", "d")) == "a"


func build() -> void:
	_configure()
	T = T_DEFAULT.duplicate()
	T.merge(cfg.get("T", {}), true)
	slot = String(cfg["slot"])
	swell_end = _t("h5") + SWELL
	length = swell_end + TAIL
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.5
	stage = cfg["stage"]
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
	x1 = _sr(_t("x1"))
	x2 = _sr(_t("x2"))
	x3 = _sr(_t("x3"))
	s_pick1 = _sr(_t("pick1"))
	s_pick2 = _sr(_t("pick2"))
	if cfg.has("opener"):
		s_open = _sr(_open_r())
	sc = h5 + CRASH_DS
	s_run = sc + 0.3
	s_gone = s_run + D_RUN
	_layout()
	_props()
	_hero()
	_role_a()
	_role_b()
	_role_c()
	_role_d()
	_shots()
	_fx_sfx()
	for sb: Array in cfg.get("subs", []):
		sub(float(sb[0]), float(sb[1]), String(sb[2]), String(sb[3]))
	_extra()


func _cast() -> void:
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	for role: String in ["a", "b", "c", "d"]:
		var cid: String = String(cfg["cast"][role])
		var extra: Dictionary = (cfg.get("cast_extra", {}) as Dictionary).get(role, {})
		actor(role, StoryCast.opts(cid, extra), String((cfg.get("names", {}) as Dictionary).get(role, StoryCast.speaker(cid))), StoryCast.color(cid))


func _w(k: String) -> Dictionary:
	return cfg[k]


func _reach(key: String, fallback: Variant) -> Variant:
	return (cfg.get("reach", {}) as Dictionary).get(key, fallback)


## Slow motion on the four best impacts, one dodge accent and the finisher swell (real times). Contact pairs (att -> tgt)
## are checked on every tier by tests/support/cine_fight.gd.
func _hits() -> void:
	var w: Dictionary = cfg.get("what", {})
	hit("H1", _t("h1") - 0.2, "medium", String(w.get("H1", "w1 into the boss")), {"r": _t("h1"), "att": "hero:w1", "tgt": "a:Head"})
	hit("H2", _t("h2") - 0.4, "heavy", String(w.get("H2", "w2 comes down on b")), {"r": _t("h2"), "att": "hero:w2", "tgt": "b:upper"})
	hit("H3", _t("h3") - 0.5, "light", String(w.get("H3", "a two-handed shove slams c into the surface")), {"r": _t("h3"), "att": "hero:hands", "tgt": "c:torso"})
	hit("H4", _t("h4") - 0.6, "medium", String(w.get("H4", "w3 on the boss")), {"r": _t("h4"), "hq": 0.4, "att": "hero:w3", "tgt": "a:Head"})
	hit("A1", _t("a1") - 0.7, "accent", String(w.get("A1", "slow-motion accent: the protagonist slips d's second punch")), {"r": _t("a1")})
	hit("H5", _t("h5") - 0.8, "finisher", String(w.get("H5", "uppercut: the boss flies back into the crash prop (long swell)")),
		{"r": _t("h5"), "hq": SWELL - 0.55, "att": "hero:hands", "tgt": "a:upper"})


func _layout() -> void:
	A_A = P0 + Vector3(0.0, 0.0, -D_H1)
	A_O = P0 + Vector3(0.0, 0.0, -float((cfg.get("opener", {}) as Dictionary).get("dist", 1.2)))
	A_B = A_A + Vector3(0.75, 0.0, -0.55)
	var dir_b: Vector3 = Vector3(-0.74, 0.0, -0.67).normalized()
	B_A = P0 + dir_b * D_C2X
	P1 = P0 - dir_b * 0.35 + Vector3(-0.1, 0.0, 0.1)
	B_B = P1 + _d(P1, B_A) * D_H2
	B_DOWN = B_B + _d(P1, B_B) * 0.9
	FLOOR_ITEM = P1 - dir_b * float(cfg.get("floor_back", 0.62))
	C_A = Vector3(SURFACE_FACE_X - 0.5, 0.0, 0.75)
	P2 = C_A - Vector3(D_C3J, 0.0, 0.0)
	P2B = C_A - Vector3(D_H3, 0.0, 0.0)
	C_HIT = Vector3(SURFACE_FACE_X - 0.2, 0.0, C_A.z)
	C_SIT = Vector3(SURFACE_FACE_X - 0.3, 0.0, C_A.z)
	slam_s = h3 + 0.28
	P3 = Vector3(GRAB.x - 0.85, 0.0, GRAB.z + 0.1)
	var dir_a: Vector3 = Vector3(-0.8, 0.0, 0.6).normalized()
	A_D = P3 + dir_a * D_H4
	A_E = A_D + dir_a * 0.15
	var dir_d: Vector3 = Vector3(-0.55, 0.0, -0.84).normalized()
	D_A = P3 + dir_d * (D_DH + float(cfg.get("d_dh_extra", 0.0)))   # d stands a little further off for a long-armed body
	D_B = D_A + dir_d * 0.9
	A_F = P3 + _d(P3, CRATES) * D_H5
	A_CRASH = CRATES - _d(P3, CRATES) * CRASH_BACK + Vector3(0.0, 0.3, 0.0)
	A_REST = CRATES - _d(P3, CRATES) * CRASH_BACK


func _props() -> void:
	var sf: Dictionary = cfg["surface"]
	prop("surface", String(sf["kind"]), sf["pos"], float(sf.get("yaw", 0.0)), sf.get("opts", {}))   # its face at about SURFACE_FACE_X
	for ex: Array in cfg.get("surface_extra", []):
		prop(String(ex[0]), String(ex[1]), ex[2], float(ex[3]), ex[4] if ex.size() > 4 else {})
	var cr: Dictionary = cfg["crashes"]
	prop("crates", String(cr["kind"]), CRATES, float(cr.get("yaw", 20.0)), cr.get("opts", {}))
	var w2: Dictionary = _w("w2")
	var fo: Dictionary = (w2.get("floor_opts", {}) as Dictionary).duplicate()
	fo["hide_at"] = s_pick1
	var fp: Vector3 = FLOOR_ITEM + Vector3(0.0, float(w2.get("floor_y", 0.0)), 0.0)
	if w2.has("floor_rot"):   # lying flat: a constant path carries the full rotation
		fo["path"] = [[0.0, fp, w2["floor_rot"]], [1.0, fp, w2["floor_rot"]]]
	prop("floor_item", String(w2["kind"]), fp, float(w2.get("floor_yaw", 200.0)), fo)
	var w3: Dictionary = _w("w3")
	var go: Dictionary = (w3.get("grab_opts", {}) as Dictionary).duplicate()
	go["hide_at"] = s_pick2
	prop("grab_item", String(w3["kind"]), w3.get("grab_pos", GRAB), float(w3.get("grab_yaw", 0.0)), go)
	for ds: Array in cfg.get("dressing", []):
		var o: Dictionary = (ds[4] if ds.size() > 4 else {}).duplicate()
		o["set"] = true
		prop(String(ds[0]), String(ds[1]), ds[2], float(ds[3]), o)
	# w1 leaves the hand after H1 and drops to the floor at the protagonist's feet (unless it breaks)
	var w1: Dictionary = _w("w1")
	if not bool(w1.get("breaks", false)):
		var t_hand: Vector3 = P0 + Vector3(0.15, 1.05, -0.45)
		var t_floor: Vector3 = P0 + (w1.get("drop", Vector3(0.3, 0.0, -0.3)) as Vector3) + Vector3(0.0, float(w1.get("floor_y", 0.05)), 0.0)
		var dop: Dictionary = (w1.get("opts", {}) as Dictionary).duplicate()
		dop["show_at"] = _sr(_t("h1") + 0.82)
		dop["arc"] = 0.08
		dop["path"] = [[_sr(_t("h1") + 0.82), t_hand, Vector3(0.0, 0.0, 90.0)], [_sr(_t("h1") + 1.15), t_floor, w1.get("floor_rot", Vector3(0.0, 35.0, 0.0))]]
		prop("w1_drop", String(w1["kind"]), t_floor, 35.0, dop)


## Hold opts for a weapon def: its own opts plus the bone / offset / rot of the grip.
static func _grip(w: Dictionary, two_hand: bool) -> Dictionary:
	var o: Dictionary = (w.get("opts", {}) as Dictionary).duplicate()
	if two_hand:
		o["mid"] = "Wrist.L"
	o["offset"] = w.get("offset2" if two_hand else "offset", Vector3(0.0, 0.0, -0.14))
	o["rot"] = w.get("rot2" if two_hand else "rot", Vector3.ZERO)
	return o


func _hero() -> void:
	var w1: Dictionary = _w("w1")
	var w1_two: bool = String(w1.get("move", "cross")) == "chair_smash"
	key("hero", 0.0, P0, 0.0)
	key("hero", _sr(_t("h1") - 0.4), P0, 0.0)
	move("hero", 0.0, "tray_hold")
	if cfg.has("opener"):   # the boss's opener: slipped (dodge) or caught on the weapon (block)
		strike("hero", s_open, String((cfg["opener"] as Dictionary).get("hero", "dodge")))
		expr("hero", s_open - 0.2, "surprised")
	if w1_two:   # held in both hands from the start, brought down overhead on H1
		hold("hero", 0.0, h1 + 0.03, String(w1["kind"]), _grip(w1, true))
		if not cfg.has("opener"):
			move("hero", _sr(_t("h1") - 0.95), "fight_idle", {"fade": 0.15})
		strike("hero", "H1", "chair_smash", {"reach": _reach("H1", 0.0)})
	else:        # a two-handed carry, then one hand: a right straight, the weapon first
		hold("hero", 0.0, _sr(_t("h1") - 0.65), String(w1["kind"]), _grip(w1, true))
		hold("hero", _sr(_t("h1") - 0.65), _sr(_t("h1") + 0.82), String(w1["kind"]), _grip(w1, false))
		move("hero", _sr(maxf(_t("h1") - 0.7, _open_r() + 0.45) if cfg.has("opener") else _t("h1") - 0.7), "fight_idle", {"fade": 0.15})
		strike("hero", "H1", "cross", {"dur": 0.5, "reach": _reach("H1", {"mixamo": -0.25})})
	expr("hero", 0.0, "open")
	expr("hero", _sr(_t("h1") - 0.55 if cfg.has("opener") else _t("h1") - 1.0), "angry")
	move("hero", _sr(_t("h1") + 0.8), "idle", {"fade": 0.15})   # hands low: b's cross lands on the jaw
	look("hero", 0.0, _sr(_t("h1") + 0.9), "a")
	look("hero", _sr(_t("h1") + 1.0), _sr(_t("h2") - 0.4), "b")
	# x1: b's cross on the jaw, snapped back a step
	var y_b: float = CineTimeline.face(P0, B_A)
	key("hero", _sr(_t("x1") - 0.4), P0, 0.0)
	key("hero", _sr(_t("x1") - 0.15), P0, y_b)
	strike("hero", x1, "hit_head")
	expr("hero", x1, "pain")
	key("hero", x1, P0, y_b)
	key("hero", _sr(_t("x1") + 0.35), P1, y_b, {"mode": "out"})
	# pick1: w2 off the floor behind, turns back, H2 brings it down on b
	var w2: Dictionary = _w("w2")
	var y_fl: float = CineTimeline.face(P1, FLOOR_ITEM)
	var y_bb: float = CineTimeline.face(P1, B_B)
	key("hero", _sr(_t("pick1") - 0.35), P1, y_fl)
	strike("hero", s_pick1, "pickup", {"dur": 0.45})
	hold("hero", s_pick1, h2 + 0.03, String(w2["kind"]), _grip(w2, true))
	key("hero", _sr(_t("pick1") + 0.25), P1, y_fl)
	key("hero", _sr(_t("h2") - 0.6), P1, y_bb)
	strike("hero", "H2", "chair_smash", {"reach": _reach("H2", 0.0)})
	expr("hero", s_pick1, "angry")
	move("hero", _sr(_t("h2") + 1.35), "fight_idle", {"fade": 0.2})
	look("hero", _sr(_t("x2") - 1.0), _sr(_t("h3") + 0.8), "c")
	# x2: c's jab to the stomach at the surface, H3: a step in and the shove
	var y_c: float = CineTimeline.face(P2, C_A)
	if cfg.has("x2_move"):   # hands low: c's kick lands on the stomach (no guard in the way)
		move("hero", _sr(_t("x2") - 0.3), "idle", {"fade": 0.12})
	key("hero", _sr(_t("x2") - 0.7), P1, y_bb)
	key("hero", _sr(_t("x2") - 0.15), P2, y_c, {"mode": "out"})
	strike("hero", x2, String(cfg.get("x2_react", "hit_stomach")))
	expr("hero", x2, "pain")
	if cfg.has("x2_move"):   # doubled over by the kick: staggers back a step off it
		key("hero", x2, P2, y_c)
		key("hero", _sr(_t("x2") + 0.3), P2 - Vector3(0.18, 0.0, 0.0), y_c, {"mode": "out"})
	key("hero", _sr(_t("x2") + 0.35), P2 - Vector3(0.18 if cfg.has("x2_move") else 0.0, 0.0, 0.0), y_c)
	key("hero", _sr(_t("h3") - 0.15), P2B, y_c, {"mode": "out"})
	strike("hero", "H3", "shove", {"reach": _reach("H3", {"mixamo": -0.08, "ual": 0.08, "native": 0.06, "code": 0.06})})
	expr("hero", _sr(_t("h3") - 0.2), "angry")
	move("hero", _sr(_t("h3") + 0.6), "fight_idle", {"fade": 0.2})
	# pick2: w3 from the grab spot, H4 on the boss
	var w3: Dictionary = _w("w3")
	var w3_move: String = String(w3.get("move", "chair_smash"))
	var y_gr: float = CineTimeline.face(P3, GRAB)
	var y_a: float = CineTimeline.face(P3, A_D)
	key("hero", _sr(_t("h3") + 0.65), P2B, y_c)
	key("hero", _sr(_t("pick2") - 0.3), P3, y_gr, {"mode": "out"})
	strike("hero", s_pick2, String(w3.get("grab_move", "shove")), {"dur": 0.5})
	hold("hero", s_pick2, h4 + float(w3.get("keep", 0.03)), String(w3["kind"]), _grip(w3, w3_move == "chair_smash"))
	key("hero", _sr(_t("pick2") + 0.3), P3, y_gr)
	key("hero", _sr(_t("h4") - 0.65), P3, y_a)
	look("hero", _sr(_t("pick2") + 0.3), _sr(_t("h4") + 0.7), "a")
	if w3_move == "chair_smash":
		strike("hero", "H4", "chair_smash", {"reach": _reach("H4", 0.0)})
	else:
		move("hero", _sr(_t("h4") - 0.75), "fight_idle", {"fade": 0.12})
		strike("hero", "H4", "cross", {"dur": 0.5, "reach": _reach("H4", {"mixamo": -0.2})})
	move("hero", _sr(_t("h4") + 0.8), "fight_idle", {"fade": 0.2})
	# x3: d's straight right, A1 slips the second one
	var y_d: float = CineTimeline.face(P3, D_A)
	move("hero", _sr(_t("x3") - 0.6), "idle", {"fade": 0.15})   # hands low: d's straight right lands (no guard clash)
	key("hero", _sr(_t("x3") - 0.6), P3, y_a)
	key("hero", _sr(_t("x3") - 0.3), P3, y_d)
	var y_af: float = CineTimeline.face(P3, A_F)
	if _a1_by_boss():   # d's hit, then the boss lunges in from the other side: the A1 miss is his
		look("hero", _sr(_t("x3") - 0.5), _sr(_t("x3") + 0.3), "d")
		look("hero", _sr(_t("x3") + 0.4), _sr(_t("h5") - 0.9), "a")
		key("hero", _sr(_t("a1") - 0.6), P3, y_d)
		key("hero", _sr(_t("a1") - 0.3), P3, y_af)
	else:
		look("hero", _sr(_t("x3") - 0.5), _sr(_t("a1") + 0.3), "d")
	strike("hero", x3, "hit_head")
	expr("hero", x3, "pain")
	strike("hero", "A1", "dodge")
	expr("hero", _sr(_t("a1") - 0.2), "angry")
	# H5: the uppercut on the boss staggering back in
	key("hero", _sr(_t("h5") - 1.0), P3, y_af if _a1_by_boss() else y_d)
	key("hero", _sr(_t("h5") - 0.75), P3, y_af)
	strike("hero", "H5", "uppercut", {"dur": 0.6, "reach": _reach("H5", {"mixamo": Vector2(0.4, -0.3), "ual": 0.05, "native": 0.2, "code": 0.2})})
	move("hero", h5 + 0.5, "fight_idle", {"fade": 0.3})
	look("hero", _sr(_t("h5") - 0.9), sc + 0.3, "a")
	look("hero", sc + 0.4, story_end, "d")
	key("hero", sc + 0.1, P3, y_af)
	key("hero", sc + 0.5, P3, CineTimeline.face(P3, EXIT))
	move("hero", _sr(swell_end + 0.3), "winded", {"fade": 0.35})
	expr("hero", sc, "happy")
	expr("hero", _sr(swell_end + 0.4), "done")


func _role_a() -> void:
	var y0: float = CineTimeline.face(A_0, P0)
	var y_a: float = CineTimeline.face(A_A, P0)
	key("a", 0.0, A_0, y0)
	move("a", 0.0, "fight_idle")
	if cfg.has("opener"):   # runs in and attacks first; the protagonist slips or blocks it, then H1 lands
		var op: Dictionary = cfg["opener"]
		var t0: float = maxf(_open_r() - 1.4, 0.05)
		var y_run: float = CineTimeline.face(A_0, A_O)
		var y_o: float = CineTimeline.face(A_O, P0)
		key("a", _sr(t0), A_0, y_run)
		move("a", _sr(t0), "jog", {"fade": 0.2})
		key("a", _sr(_open_r() - 0.4), A_O, y_run, {"mode": "out"})
		move("a", _sr(_open_r() - 0.45), "fight_idle", {"fade": 0.12})
		key("a", _sr(_open_r() - 0.3), A_O, y_o)
		strike("a", s_open, String(op["move"]), {"reach": op.get("reach", 0.0)})
		expr("a", s_open - 0.3, "angry")
		move("a", _sr(_open_r() + 0.55), "idle", {"fade": 0.2})   # arms low: H1 lands
		key("a", _sr(_t("h1") - 0.35), A_O, y_o)
	else:
		key("a", _sr(_t("h1") - 1.3), A_0, y0)
		move("a", _sr(_t("h1") - 1.3), "walk", {"fade": 0.2})   # arms low on the way in
	key("a", h1, A_A, y_a, {"mode": "out"})
	strike("a", "H1", "hit_head")
	key("a", _sr(_t("h1") + 1.1), A_B, y_a, {"mode": "out"})
	move("a", _sr(_t("h1") + 0.7), "stunned", {"fade": 0.15})
	fx_at(_sr(_t("h1") + 0.7), "stars", "a", {"until": _sr(_t("pick2") - 0.5)})
	var y_in: float = CineTimeline.face(A_D, P3)
	key("a", s_pick2, A_B, CineTimeline.face(A_B, A_D))
	move("a", s_pick2, "jog", {"fade": 0.2})
	key("a", _sr(_t("h4") - 0.45), A_D, y_in, {"mode": "out"})
	if bool(cfg.get("a_blocks_h4", false)):   # blocks with his weapon over his head: the blow lands on it (the katana snaps)
		strike("a", "H4", "block_high", {"fade": 0.1})
		move("a", h4 + 0.18, "hit_head", {"fade": 0.06})
	else:   # "idle": squares up hands low, chin out (no guard clash with the protagonist's straight right)
		move("a", _sr(_t("h4") - 0.45), String(cfg.get("a_pre_h4", "fight_idle")), {"fade": 0.12})
		strike("a", "H4", "hit_head")
	key("a", h4, A_D, y_in)
	key("a", _sr(_t("x3") - 0.3), A_E, y_in, {"mode": "out"})
	move("a", _sr(_t("h4") + 0.6), "stunned", {"fade": 0.15})
	var y_f: float = CineTimeline.face(A_F, P3)
	if _a1_by_boss():   # circles round to the protagonist's other side and throws the A1 miss
		var y_c: float = CineTimeline.face(A_E, A_F)
		key("a", _sr(_t("x3") + 0.1), A_E, y_c)
		move("a", _sr(_t("x3") + 0.1), "walk", {"fade": 0.2})
		key("a", _sr(_t("a1") - 0.45), A_F, y_c, {"mode": "out"})
		move("a", _sr(_t("a1") - 0.5), "fight_idle", {"fade": 0.12})
		key("a", _sr(_t("a1") - 0.3), A_F, y_f)
		strike("a", "A1", String(cfg.get("a1_move", "cross")), {"reach": cfg.get("a1_reach", -0.3)})
		expr("a", _sr(_t("a1") - 0.4), "angry")
		move("a", _sr(_t("a1") + 0.6), "stunned", {"fade": 0.15})
		key("a", _sr(_t("h5") - 0.4), A_F, y_f)
	else:
		key("a", _sr(_t("a1")), A_E, y_in)
		key("a", _sr(_t("h5") - 0.4), A_F, y_f, {"mode": "out"})
	strike("a", "H5", "launched_back", {"arc": 0.0})
	key("a", h5, A_F, y_f)
	key("a", sc + 0.08, A_CRASH, y_f, {"mode": "linear", "arc": 0.35})
	key("a", sc + 0.35, A_REST, y_f, {"mode": "out"})
	move("a", h5 - 0.08 + 1.6, "lie")
	fx_at(sc + 0.4, "stars", "a", {"until": story_end})


func _role_b() -> void:
	var y0: float = CineTimeline.face(B_0, P0)
	var y_a: float = CineTimeline.face(B_A, P0)
	key("b", 0.0, B_0, y0)
	move("b", 0.0, "fight_idle")
	key("b", _sr(_t("x1") - 0.7), B_0, y0)
	key("b", _sr(_t("x1") - 0.15), B_A, y_a, {"mode": "out"})
	strike("b", x1, "cross", {"reach": _reach("X1", {"mixamo": Vector2(-0.16, 0.06), "ual": -0.02})})
	move("b", _sr(_t("x1") + 0.4), "fight_idle", {"fade": 0.15})
	var y_b: float = CineTimeline.face(B_B, P1)
	key("b", _sr(_t("x1") + 0.4), B_A, y_a)
	key("b", _sr(_t("h2") - 0.65), B_B, y_b, {"mode": "out"})
	strike("b", "H2", "knocked_out")
	key("b", h2, B_B, y_b)
	key("b", _sr(_t("h2") + 1.6), B_DOWN, y_b, {"mode": "out"})
	fx_at(_sr(_t("h2") + 1.7), "stars", "b", {"until": story_end})


func _role_c() -> void:
	var y0: float = CineTimeline.face(C_0, P0)
	var y_a: float = CineTimeline.face(C_A, P2)
	key("c", 0.0, C_0, y0)
	move("c", 0.0, "fight_idle")
	var y_run: float = CineTimeline.face(C_0, C_A)
	key("c", _sr(_t("x2") - 1.1), C_0, y_run)
	move("c", _sr(_t("x2") - 1.1), "jog", {"fade": 0.15})
	key("c", _sr(_t("x2") - 0.5), C_A, y_run, {"mode": "out"})
	move("c", _sr(_t("x2") - 0.55), "fight_idle", {"fade": 0.12})
	key("c", _sr(_t("x2") - 0.3), C_A, y_a)
	strike("c", x2, String(cfg.get("x2_move", "jab")), {"reach": _reach("X2", {"mixamo": -0.04, "ual": 0.15, "native": 0.1})})
	move("c", _sr(_t("x2") + 0.35), "fight_idle", {"fade": 0.12})
	strike("c", "H3", "slammed")
	key("c", h3, C_A, y_a)
	key("c", slam_s, C_HIT, y_a, {"mode": "out"})
	key("c", h3 - 0.04 + 0.8, C_SIT, y_a)
	move("c", h3 - 0.04 + 0.8, "slumped", {"fade": 0.15})
	fx_at(slam_s + 0.1, "stars", "c", {"until": story_end})


func _role_d() -> void:
	var y0: float = CineTimeline.face(D_0, P0)
	key("d", 0.0, D_0, y0)
	move("d", 0.0, "point")
	move("d", _sr(_t("h1") - 1.1), "fight_idle", {"fade": 0.25})
	look("d", 0.0, story_end, "hero")
	var y_a: float = CineTimeline.face(D_A, P3)
	key("d", _sr(_t("x3") - 1.1), D_0, CineTimeline.face(D_0, D_A))
	move("d", _sr(_t("x3") - 1.1), "jog", {"fade": 0.15})
	key("d", _sr(_t("x3") - 0.45), D_A, y_a, {"mode": "out"})
	move("d", _sr(_t("x3") - 0.5), "fight_idle", {"fade": 0.1})
	strike("d", x3, "cross", {"reach": _reach("X3", {"mixamo": Vector2(-0.1, 0.06), "ual": 0.08, "native": 0.05, "code": 0.05})})
	move("d", _sr(_t("x3") + 0.15), "fight_idle", {"fade": 0.12})
	var y_ex: float = CineTimeline.face(D_B, EXIT)
	if _a1_by_boss():   # out of the boss's way: turns and walks off (no backing up)
		var y_off: float = CineTimeline.face(D_A, D_B)
		key("d", _sr(_t("x3") + 0.2), D_A, y_a)
		key("d", _sr(_t("x3") + 0.35), D_A, y_off)
		move("d", _sr(_t("x3") + 0.35), "walk", {"fade": 0.15})
		key("d", _sr(_t("x3") + 1.0), D_B, y_off, {"mode": "out"})
		move("d", _sr(_t("x3") + 1.0), "fight_idle", {"fade": 0.2})
	else:
		strike("d", "A1", "cross", {"reach": _reach("A1", {"mixamo": -0.35, "ual": -0.15, "native": -0.15, "code": -0.15})})   # the miss
		move("d", _sr(_t("a1") + 0.5), "fight_idle", {"fade": 0.15})
		key("d", _sr(_t("a1") + 0.4), D_A, y_a)
		key("d", _sr(_t("a1") + 0.9), D_B, y_a, {"mode": "out"})
	key("d", s_run, D_B, y_ex)
	move("d", s_run, "sprint", {"fade": 0.2})
	key("d", s_gone, EXIT, y_ex, {"mode": "linear"})
	show("d", s_gone, false)


## A shot with the fight's overrides (cfg "shots": {id: {"rig": ..., params...}}).
func _shot(id: String, s: float, rig: String, what: String, params: Dictionary) -> void:
	var o: Dictionary = (cfg.get("shots", {}) as Dictionary).get(id, {})
	var pp: Dictionary = params.duplicate()
	if o.has("rig") and String(o["rig"]) != rig:
		pp = {}
	for k: String in o.keys():
		if k != "rig":
			pp[k] = o[k]
	shot(id, s, String(o.get("rig", rig)), what, pp)


func _shots() -> void:
	var lab: Dictionary = cfg.get("shot_what", {})
	_shot("S1", 0.0, "dolly", String(lab.get("S1", "wide: the standoff")),
		{"from": Vector3(-3.6, 1.8, 4.6), "to": Vector3(-3.2, 1.7, 4.1), "look_from": Vector3(0.0, 1.1, -0.8),
		"look_to": Vector3(-0.1, 1.1, -0.6), "fov": 52.0, "hand": 0.3})
	_shot("S2", h1, "orbit", String(lab.get("S2", "slow-motion close orbit: H1")),
		{"center": (P0 + A_A) * 0.5 + Vector3(0.0, 1.4, 0.0), "radius": 1.7, "deg_from": 70.0, "deg_to": 100.0, "height": 1.45,
		"fov": 40.0, "hand": 0.3})
	_shot("S3", _sr(_t("x1") - 0.3), "track", String(lab.get("S3", "handheld over b's shoulder: the cross on the jaw")),
		{"actor": "b", "offset": Vector3(0.7, 1.6, 0.9), "look_actor": "hero", "look": Vector3(0.0, 1.4, 0.0), "fov": 42.0, "hand": 1.0})
	_shot("S4", s_pick1 - 0.35, "static", String(lab.get("S4", "low and tight: the pickup off the floor")),
		{"pos": P1 + Vector3(1.4, 0.55, 1.2), "look": P1 + Vector3(-0.4, 0.6, 0.6), "fov": 46.0, "hand": 0.8})
	_shot("S5", h2, "static", String(lab.get("S5", "slow motion, low wide: H2")),
		{"pos": (P1 + B_B) * 0.5 + Vector3(-1.9, 0.6, 1.6), "look": (P1 + B_B) * 0.5 + Vector3(0.0, 1.0, 0.0), "fov": 50.0, "hand": 0.4})
	_shot("S6", _sr(_t("x2") - 0.3), "static", String(lab.get("S6", "handheld side-on: c's jab to the stomach")),
		{"pos": (P2 + C_A) * 0.5 + Vector3(0.0, 1.3, 2.3), "look": (P2 + C_A) * 0.5 + Vector3(0.0, 1.1, 0.0), "fov": 44.0, "hand": 1.0})
	_shot("S7", h3, "static", String(lab.get("S7", "slow motion: H3, c slammed back")),
		{"pos": P2 + Vector3(-0.9, 0.7, 1.4), "look": C_HIT + Vector3(0.0, 0.8, 0.0), "fov": 46.0, "hand": 0.4})
	_shot("S8", _sr(_t("pick2") - 0.2), "static", String(lab.get("S8", "medium: the second pickup")),
		{"pos": P3 + Vector3(-1.2, 1.5, 1.7), "look": P3 + Vector3(0.4, 1.0, -0.1), "fov": 46.0, "hand": 0.8})
	_shot("S9", h4, "static", String(lab.get("S9", "slow motion, low: H4")),
		{"pos": (P3 + A_D) * 0.5 + Vector3(0.3, 0.6, 1.9), "look": (P3 + A_D) * 0.5 + Vector3(0.0, 1.4, 0.0), "fov": 44.0, "hand": 0.4})
	_shot("S10", _sr(_t("x3") - 0.3), "track", String(lab.get("S10", "handheld over d's shoulder: the straight right, the slip")),
		{"actor": "d", "offset": Vector3(-0.7, 1.65, 0.8), "look_actor": "hero", "look": Vector3(0.0, 1.4, 0.0), "fov": 42.0, "hand": 1.0})
	_shot("S11", _sr(_t("h5") - 0.5), "orbit", String(lab.get("S11", "low slow orbit: the uppercut, the boss lifts off")),
		{"center": (P3 + A_F) * 0.5 + Vector3(0.0, 1.2, 0.0), "radius": 3.0, "deg_from": 200.0, "deg_to": 240.0, "height": 0.8,
		"fov": 46.0, "hand": 0.4})
	_shot("S12", _sr(_t("h5") + 2.6), "static", String(lab.get("S12", "slow motion: the boss into the crash prop")),
		{"pos": CRATES + Vector3(2.6, 1.0, 2.2), "look": CRATES + Vector3(0.2, 0.6, 0.0), "fov": 48.0, "hand": 0.5})
	_shot("S13", s_run - 0.05, "dolly", String(lab.get("S13", "slow push: d turns and runs for the exit")),
		{"from": P3 + Vector3(0.6, 1.6, 2.4), "to": P3 + Vector3(0.2, 1.55, 1.8), "look_from": EXIT + Vector3(2.0, 1.0, 0.0),
		"look_to": EXIT + Vector3(0.8, 1.0, 0.0), "fov": 50.0, "hand": 0.4})
	_shot("S14", s_gone, "dolly", String(lab.get("S14", "tail wide: the wreckage, the protagonist winded")),
		{"from": Vector3(1.2, 2.1, 4.6), "to": Vector3(0.8, 1.9, 4.2), "look_from": Vector3(0.0, 0.6, -1.0),
		"look_to": Vector3(0.2, 0.6, -0.8), "fov": 54.0, "hand": 0.5})
	punch(x1, "medium")
	punch(x2, "light")
	punch(x3, "medium")
	punch(s_pick1, "light")


func _fx_sfx() -> void:
	var cue: Dictionary = cfg.get("sfx", {})
	sfx_at("H1", String(cue.get("H1", "impact_medium")), 0.0)
	fx_at("H1", String(cue.get("H1_fx", "sparks")), "a:Head", {"power": 0.6, "dir": Vector3(0.3, 0.6, -0.4)})
	sfx_at(x1, "impact_medium", -2.0)
	fx_at(x1, "sparks", "hero:Head", {"power": 0.3})
	sfx_at(s_pick1, "whoosh_down", -6.0)
	sfx_at("H2", String(cue.get("H2", "chair_smash")), 0.0)
	fx_at("H2", "debris", "b:Chest", {"power": 0.9, "dir": Vector3(0.3, 0.8, -0.4)})
	fx_at("H2", "dust", "b:Chest", {"power": 0.6})
	fx_at(h2 + 0.7, "dust", "b:Hips", {"power": 0.8})
	sfx_at(h2 + 0.7, "body_fall", -1.0)
	sfx_at(x2, "impact_light", -3.0)
	sfx_at(slam_s, String(cue.get("H3", "impact_heavy")), -4.0)
	fx_at(slam_s, "dust", "c:Hips", {"power": 0.6})
	sfx_at(s_pick2, String(cue.get("pick2", "whoosh_down")), -8.0)
	sfx_at("H4", String(cue.get("H4", "impact_medium")), 0.0)
	fx_at("H4", "sparks", "a:Head", {"power": 0.6})
	sfx_at(x3, "impact_medium", -2.0)
	fx_at(x3, "sparks", "hero:Head", {"power": 0.3})
	sfx_at("A1", "whoosh_down", -6.0)
	fx_at("H5", "flash", "a:Chest", {"power": 0.7})
	fx_at("H5", "dust", "hero:Foot.L", {"power": 0.5})
	fx_at(sc, "crate", "crates", {"power": 1.1, "dir": _d(P3, CRATES) + Vector3(0.0, 0.4, 0.0)})
	fx_at(sc, "flash", "crates", {"power": 0.9})
	fx_at(sc, "dust", "a:Hips", {"power": 1.0})
	sfx_at(sc, String(cue.get("crash", "crate_smash")), 0.0)
	sfx_at(sc + 0.3, "body_fall", -3.0)
	sfx_at(_sr(swell_end + 0.3), "groan", -5.0)
