# File: res://scripts/cine/CineMoves.gd
# Logical moves for cinematics (spec A1-D4, A1-D22). A move has a fixed STORY duration and an impact fraction hit_u; at run
# time it resolves to the best available tier (Mixamo -> UAL -> native body clip -> code pose). Each tier's clip window
# [from, hit, to] is mapped piecewise-linearly onto the move so its impact frame lands at story time start + hit_u·dur:
# blocking, timing and the beat sheet are the same whichever tier plays. Entry extras ("arc" metres, "spin" degrees per axis)
# add the airborne height / rotation a tier lacks over the move's "air" window; "add" layers an additive code pose; "yaw"
# turns the actor while that entry plays; "ref" is the clip time whose hips position the horizontal root strip keeps (default
# from; 0 keeps a mid-clip hold window over the root when the clip travelled before it). to = -1 -> full clip; from > to ->
# backwards. Code entries play pose-u 0..1 and
# may carry "hit" (pose-u of their impact), mapped like a clip window; additive layers peak on the impact (add_u).
# Native windows are authored in seconds of the men/* body clips; women/* body files hold the same keys stretched in time
# (every clip 1.25x longer), so resolve() scales native windows by the rig's Death length over NATIVE_REF_LEN.
class_name CineMoves
extends RefCounted

const TIERS: Array[String] = ["mixamo", "ual", "native", "code"]
## Test hook: best tier allowed (index into TIERS). If no entry passes the cap, the last available entry is used.
static var max_tier: int = 0
## Reference native clip and its length (s) on the men/* rigs the native windows below were authored on.
const NATIVE_REF_CLIP: String = "Death"
const NATIVE_REF_LEN: float = 1.0666667
## Hip-height pivot of CineActor's spin node (= CineActor.PIVOT_Y): code poses that lay the body down drop it by this much.
const PIVOT_Y: float = 0.95
## Height of the pivot above the ground when lying flat (half the body's thickness at the hips; Task 7: hips bone ~0.14 m,
## like the clip tiers' lying frames at 0.10-0.13 m).
const LIE_PIVOT_Y: float = 0.08
## Pose-u of the code poses' impact (striking foot at full reach, measured on the evaluated actor): code entries carry it as
## "hit" so the move's hit_u maps onto it exactly like a clip window (clip_time with from 0, to 1).
const FLYING_KICK_HIT: float = 0.75
const SPIN_KICK_HIT: float = 0.7
## Additive layers ("add") peak at pose-u ADD_HIT; add_u() maps the move's hit_u onto it, so the delta peaks on the impact
## and is zero at both window ends (no pop).
const ADD_HIT: float = 0.5

const MOVES: Dictionary = {
	"fight_idle": {"dur": 3.3, "loop": true, "src": [
		{"t": "mixamo", "a": "Fighting_Idle", "from": 0.0, "to": 3.3}, {"t": "ual1", "a": "Idle"},
		{"t": "native", "a": "Idle"}, {"t": "code", "a": "stance"}]},
	"taunt": {"dur": 1.6, "src": [
		{"t": "mixamo", "a": "Taunt"}, {"t": "ual2", "a": "Idle_No"}, {"t": "native", "a": "Wave"}, {"t": "code", "a": "taunt"}]},
	"sprint": {"dur": 0.533, "loop": true, "src": [
		{"t": "mixamo", "a": "Sprint"}, {"t": "ual1", "a": "Sprint"}, {"t": "native", "a": "Run"}]},
	"jog": {"dur": 0.8, "loop": true, "src": [{"t": "ual1", "a": "Jog_Fwd"}, {"t": "native", "a": "Run"}]},
	"walk": {"dur": 1.0, "loop": true, "src": [{"t": "ual1", "a": "Walk"}, {"t": "native", "a": "Walk"}]},
	"flying_kick": {"dur": 1.0, "hit_u": 0.55, "air": [0.15, 0.6], "src": [
		{"t": "mixamo", "a": "Flying_Kick", "from": 0.0, "hit": 0.53, "to": 1.1},
		{"t": "code", "a": "flying_kick", "hit": FLYING_KICK_HIT, "arc": 0.9}]},
	"jab": {"dur": 0.45, "hit_u": 0.55, "src": [
		{"t": "mixamo", "a": "Jab_Cross", "from": 0.15, "hit": 0.40, "to": 0.55},
		{"t": "ual1", "a": "Punch_Jab", "from": 0.0, "hit": 0.22, "to": 0.6},
		{"t": "native", "a": "Punch_Left", "from": 0.0, "hit": 0.57, "to": 0.83}]},
	"cross": {"dur": 0.5, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Jab_Cross", "from": 0.50, "hit": 0.67, "to": 0.95},
		{"t": "ual1", "a": "Punch_Cross", "from": 0.1, "hit": 0.3, "to": 0.7},
		{"t": "native", "a": "Punch_Right", "from": 0.0, "hit": 0.57, "to": 0.83}]},
	"hook": {"dur": 0.7, "hit_u": 0.55, "src": [
		{"t": "mixamo", "a": "Hook_Punch", "from": 0.6, "hit": 1.0, "to": 1.4},
		{"t": "ual2", "a": "Melee_Hook", "from": 0.0, "hit": 0.25, "to": 0.47},
		{"t": "native", "a": "Punch_Right", "from": 0.0, "hit": 0.57, "to": 0.83}]},
	"uppercut": {"dur": 0.8, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Uppercut", "from": 0.2, "hit": 0.49, "to": 0.95},
		{"t": "ual1", "a": "Punch_Jab", "from": 0.0, "hit": 0.2, "to": 0.6, "add": "uppercut"},
		{"t": "native", "a": "Punch_Left", "from": 0.0, "hit": 0.57, "to": 0.83, "add": "uppercut"}]},
	"roundhouse": {"dur": 1.0, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Roundhouse_Kick", "from": 0.6, "hit": 1.07, "to": 1.6},
		{"t": "native", "a": "Kick_Right", "from": 0.1, "hit": 0.5, "to": 0.93, "add": "spin_kick_add"},
		{"t": "code", "a": "spin_kick", "hit": SPIN_KICK_HIT}]},
	# code tier: the smoothstep spin is half done at the impact (hit_u 0.5), so two turns put the kick on the target at
	# exactly one turn and still end facing forward (one turn would strike while facing away)
	"hurricane_kick": {"dur": 1.2, "hit_u": 0.5, "air": [0.05, 0.95], "src": [
		{"t": "mixamo", "a": "Hurricane_Kick", "from": 0.1, "hit": 0.9, "to": 1.7, "arc": 0.35},
		{"t": "code", "a": "spin_kick", "hit": SPIN_KICK_HIT, "arc": 0.7, "spin": Vector3(0.0, -720.0, 0.0)}]},
	"front_flip": {"dur": 1.2, "hit_u": 0.45, "air": [0.15, 0.85], "src": [
		{"t": "mixamo", "a": "Front_Flip", "from": 0.35, "hit": 0.85, "to": 1.55},
		{"t": "code", "a": "tuck", "arc": 1.4, "spin": Vector3(-360.0, 0.0, 0.0)}]},
	"dodge": {"dur": 0.8, "hit_u": 0.45, "src": [
		{"t": "mixamo", "a": "Dodging", "from": 0.0, "hit": 0.5, "to": 1.2}, {"t": "code", "a": "dodge_lean", "hit": 0.5}]},
	"block": {"dur": 0.8, "hit_u": 0.4, "src": [
		{"t": "mixamo", "a": "Block", "from": 0.1, "hit": 0.45, "to": 1.2},
		{"t": "ual2", "a": "Sword_Block", "from": 0.0, "hit": 0.2, "to": -1.0}, {"t": "code", "a": "block", "hit": 0.3}]},
	"knee_strike": {"dur": 0.9, "hit_u": 0.5, "air": [0.2, 0.6], "src": [
		{"t": "mixamo", "a": "Knee_Kick", "from": 0.45, "hit": 0.9, "to": 1.35, "arc": 0.25},
		{"t": "native", "a": "Kick_Left", "from": 0.1, "hit": 0.33, "to": 0.93, "add": "knee_add", "arc": 0.4},
		{"t": "code", "a": "knee", "hit": 0.5, "arc": 0.4}]},
	"hit_head": {"dur": 0.6, "hit_u": 0.1, "src": [
		{"t": "mixamo", "a": "Head_Hit", "from": 0.0, "hit": 0.12, "to": 1.0},
		{"t": "ual1", "a": "Hit_Head", "from": 0.0, "hit": 0.06, "to": -1.0},
		{"t": "native", "a": "HitRecieve", "from": 0.0, "hit": 0.06, "to": -1.0}]},
	"hit_stomach": {"dur": 0.6, "hit_u": 0.1, "src": [
		{"t": "mixamo", "a": "Stomach_Hit", "from": 0.0, "hit": 0.1, "to": 1.0},
		{"t": "ual1", "a": "Hit_Chest", "from": 0.0, "hit": 0.06, "to": -1.0},
		{"t": "native", "a": "HitRecieve_2", "from": 0.0, "hit": 0.06, "to": -1.0}]},
	"launched_back": {"dur": 1.6, "hit_u": 0.05, "air": [0.05, 0.55], "src": [
		{"t": "mixamo", "a": "Flying_Back_Death", "from": 0.0, "hit": 0.08, "to": 2.0},
		{"t": "ual2", "a": "Hit_Knockback", "from": 0.0, "hit": 0.04, "to": -1.0, "arc": 0.8},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.05, "to": -1.0, "arc": 0.8},
		{"t": "code", "a": "fall_back", "arc": 0.8}]},
	"knocked_out": {"dur": 2.0, "hit_u": 0.05, "src": [
		{"t": "mixamo", "a": "Knocked_Out", "from": 0.6, "hit": 0.7, "to": 4.9, "ref": 0.0},
		{"t": "ual1", "a": "Death01", "from": 0.0, "hit": 0.05, "to": -1.0},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.05, "to": -1.0}, {"t": "code", "a": "fall_back"}]},
	"sweep_fall": {"dur": 1.4, "hit_u": 0.35, "src": [
		{"t": "mixamo", "a": "Sweep_Fall", "from": 0.5, "hit": 1.0, "to": 2.5},
		{"t": "ual1", "a": "Death01", "from": 0.0, "hit": 0.3, "to": 2.4, "ref": 0.0},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.2, "to": -1.0}, {"t": "code", "a": "fall_back"}]},
	"slip_fall": {"dur": 1.2, "hit_u": 0.3, "src": [
		{"t": "mixamo", "a": "Sweep_Fall", "from": 0.6, "hit": 1.0, "to": 2.5},
		{"t": "ual1", "a": "Death01", "from": 0.0, "hit": 0.3, "to": 2.4, "ref": 0.0},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.2, "to": -1.0}, {"t": "code", "a": "fall_back"}]},
	"lie": {"dur": 1.0, "loop": true, "src": [
		# Mixamo: the last lying frame of Flying_Back_Death with the hips kept at their clip-start spot (over the root), the
		# same frame launched_back ends on; Knocked_Out's lying frames sit 1.2 m from the root (crossfades skated)
		{"t": "mixamo", "a": "Flying_Back_Death", "from": 1.97, "to": 2.0, "ref": 0.0},
		{"t": "ual1", "a": "Death01", "from": 2.38, "to": 2.40, "ref": 0.0}, {"t": "native", "a": "Death", "from": 1.05, "to": 1.066},
		{"t": "code", "a": "lie_back"}]},
	"get_up": {"dur": 2.0, "src": [
		{"t": "mixamo", "a": "Getting_Up", "from": 3.0, "to": 8.33},   # 3.0: still half lying (smaller pop out of lie)
		{"t": "ual2", "a": "LayToIdle"}, {"t": "native", "a": "Death", "from": 1.066, "to": 0.0}, {"t": "code", "a": "getup"}]},
	"victory": {"dur": 2.0, "src": [
		{"t": "mixamo", "a": "Victory", "from": 0.5, "to": 2.5}, {"t": "ual2", "a": "Yes"},
		{"t": "native", "a": "Wave"}, {"t": "code", "a": "victory"}]},
	"scissor_takedown": {"dur": 1.1, "hit_u": 0.6, "air": [0.1, 0.65], "src": [
		{"t": "code", "a": "scissor", "arc": 0.8, "spin": Vector3(0.0, 0.0, -80.0)}]},
}


static func has_move(move_name: String) -> bool:
	return MOVES.has(move_name)


static func is_strike(move_name: String) -> bool:
	return MOVES.has(move_name) and float((MOVES[move_name] as Dictionary).get("hit_u", -1.0)) >= 0.0


static func tier_index(t: String) -> int:
	match t:
		"mixamo":
			return 0
		"ual1", "ual2":
			return 1
		"native":
			return 2
	return 3


static func _entry_ok(e: Dictionary, bd: Dictionary) -> bool:
	match String(e["t"]):
		"code":
			return true
		"native":
			return bd.has("native") and (bd["native"]["anims"] as Dictionary).has(String(e["a"]))
	return CineRetarget.has_anim(String(e["t"]), String(e["a"]))


## Time scale of this rig's native clips against the men/* rigs the native windows were authored on (cached in bd).
static func native_scale(bd: Dictionary) -> float:
	if bd.has("native_scale"):
		return bd["native_scale"]
	var sc: float = 1.0
	if bd.has("native") and (bd["native"]["anims"] as Dictionary).has(NATIVE_REF_CLIP):
		var l: float = CineRetarget.anim_length("native", NATIVE_REF_CLIP, bd)
		if l > 0.0 and absf(l / NATIVE_REF_LEN - 1.0) > 0.01:
			sc = l / NATIVE_REF_LEN
	bd["native_scale"] = sc
	return sc


## The entry a move plays for this skeleton (bd = CineRetarget.bind()), flattened with the move's fields.
static func resolve(move_name: String, bd: Dictionary) -> Dictionary:
	if not MOVES.has(move_name):
		return {}
	var m: Dictionary = MOVES[move_name]
	var pick: Dictionary = {}
	var last_ok: Dictionary = {}
	for e: Dictionary in m["src"]:
		if not _entry_ok(e, bd):
			continue
		last_ok = e
		if pick.is_empty() and tier_index(String(e["t"])) >= max_tier:
			pick = e
	if pick.is_empty():
		pick = last_ok
	if pick.is_empty():
		return {}
	var r: Dictionary = {"move": move_name, "t": String(pick["t"]), "a": String(pick["a"]),
		"tier": TIERS[tier_index(String(pick["t"]))],
		"from": float(pick.get("from", 0.0)), "hit": float(pick.get("hit", -1.0)), "to": float(pick.get("to", -1.0)),
		"arc": float(pick.get("arc", 0.0)), "spin": pick.get("spin", Vector3.ZERO), "add": String(pick.get("add", "")),
		"yaw": float(pick.get("yaw", 0.0)), "hold_spin": bool(pick.get("hold_spin", false)),
		"ref": float(pick.get("ref", pick.get("from", 0.0))),
		"dur": float(m["dur"]), "hit_u": float(m.get("hit_u", -1.0)), "loop": bool(m.get("loop", false)),
		"air": m.get("air", []), "root_y": String(m.get("root_y", "keep"))}
	if r["t"] == "code":
		r["from"] = 0.0
		r["to"] = 1.0
	if r["t"] == "native":
		var sc: float = native_scale(bd)
		r["from"] = float(r["from"]) * sc
		if float(r["hit"]) >= 0.0:
			r["hit"] = float(r["hit"]) * sc
		if float(r["to"]) >= 0.0:
			r["to"] = float(r["to"]) * sc
	if r["t"] != "code" and float(r["to"]) < 0.0:
		r["to"] = CineRetarget.anim_length(String(r["t"]), String(r["a"]), bd)
	return r


## Clip seconds for story offset x (story seconds since the move started) of a resolved move played over dur story seconds.
## Strikes map [from, hit] onto [0, hit_u·dur] and [hit, to] onto [hit_u·dur, dur]; loops play at natural speed inside
## [from, to]; from > to plays backwards.
static func clip_time(res: Dictionary, x: float, dur: float, loop: bool) -> float:
	var a: float = res["from"]
	var b: float = res["to"]
	if loop:
		var span: float = absf(b - a)
		var dir: float = 1.0 if b >= a else -1.0
		return a + dir * (fposmod(x, span) if span > 0.0 else 0.0)
	var u: float = clampf(x / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var h: float = res["hit"]
	var hu: float = res["hit_u"]
	if h >= 0.0 and hu > 0.0 and hu < 1.0:
		if u <= hu:
			return lerpf(a, h, u / hu)
		return lerpf(h, b, (u - hu) / (1.0 - hu))
	return lerpf(a, b, u)


## Pose-u of a resolved move's additive layer at move progress u: [0, hit_u] -> [0, ADD_HIT], [hit_u, 1] -> [ADD_HIT, 1].
static func add_u(res: Dictionary, u: float) -> float:
	var hu: float = res["hit_u"]
	if hu <= 0.0 or hu >= 1.0:
		return clampf(u, 0.0, 1.0)
	return clip_time({"from": 0.0, "hit": ADD_HIT, "to": 1.0, "hit_u": hu}, u, 1.0, false)


static func _sm(u: float) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Pivot drop (m) that keeps the feet near the ground while the body pitches back by p rad about the hip-height pivot.
static func _lay_drop(p: float) -> float:
	return maxf(PIVOT_Y * cos(p), LIE_PIVOT_Y) - PIVOT_Y


## Get-up keyframes (u 0 lying = lie_back, 0.4 sitting, 0.7 squatting, 1 standing), smoothstep between them. Leg angles
## keep the ankles near the floor: with the body pitched back by p, a thigh flexed by f points f + p from straight down,
## the shin f + p + knee; ankle height = pivot - 0.45 (cos(thigh) + cos(shin)) (Task 7, checked numerically per frame).
const GETUP_KEYS: Array = [
	[0.0, PI * 0.5, LIE_PIVOT_Y, 0.35, -0.6, 0.05, -0.1, 0.3, 1.0, 0.4],
	[0.4, 0.3, 0.22, 1.7, -1.0, 1.6, -0.95, -0.5, 0.35, 0.2],
	[0.7, -0.3, 0.58, 1.7, -1.7, 1.7, -1.7, 0.9, 0.2, 0.6],
	[1.0, 0.0, PIVOT_Y, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]


static func _getup_keys(u: float) -> Array:
	var x: float = clampf(u, 0.0, 1.0)
	for i: int in range(1, GETUP_KEYS.size()):
		var b: Array = GETUP_KEYS[i]
		if x <= float(b[0]) or i == GETUP_KEYS.size() - 1:
			var a: Array = GETUP_KEYS[i - 1]
			var t: float = _sm((x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
			var out: Array = []
			for k: int in range(1, a.size()):
				out.append(lerpf(float(a[k]), float(b[k]), t))
			return out
	return []


## Code poses {CharacterBuilder joint: Euler (character frame, rad)} applied with CharacterBuilder._apply_bone_pose on the
## neutral standing base; u = progress 0..1 through the move (loops: phase). flying_kick, spin_kick and scissor are the
## prototype's (git show ec72795:scripts/cine/CineBrawl.gd) – retune the leg angles on the neutral base by eye in Task 7.
## Whole-body keys (read by CineActor, ignored by _apply_bone_pose): "body_pitch" (rad, + = onto the back, about the
## hip-height pivot) and "body_y" (m, pivot offset) – the lying / get-up poses lay the whole body down with them.
static func code_pose(pose: String, u: float) -> Dictionary:
	match pose:
		"stance":
			var br: float = sin(u * TAU) * 0.03
			return {"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.45, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
				"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(0.12 + br, 0.35, 0.0), "head": Vector3(-0.08, -0.3, 0.0),
				"shoulder_l": Vector3(1.0, 0.0, -0.35), "elbow_l": Vector3(1.9, 0.0, 0.0),
				"shoulder_r": Vector3(0.8, 0.0, 0.4), "elbow_r": Vector3(2.1, 0.0, 0.0)}
		"taunt":
			var w: float = sin(u * TAU * 2.0)
			return {"torso": Vector3(-0.1, 0.0, 0.0), "shoulder_r": Vector3(1.4 + 0.3 * w, 0.0, 0.5), "elbow_r": Vector3(1.6, 0.0, 0.0),
				"shoulder_l": Vector3(0.9, 0.0, -0.4), "elbow_l": Vector3(2.0, 0.0, 0.0), "head": Vector3(-0.15, 0.0, 0.1 * w)}
		"flying_kick":   # LEFT foot strikes (as Mixamo Flying_Kick); mirror of the prototype pose (swap sides, negate y / z)
			var e: float = _sm(u / 0.86)
			return {"thigh_l": Vector3(lerpf(1.05, 1.62, e), 0.0, 0.08), "knee_l": Vector3(lerpf(-1.9, -0.02, e), 0.0, 0.0),
				"foot_l": Vector3(lerpf(0.4, -0.25, e), 0.0, 0.0), "thigh_r": Vector3(lerpf(0.9, 0.75, e), 0.0, -0.18),
				"knee_r": Vector3(-2.1, 0.0, 0.0), "torso": Vector3(lerpf(-0.1, 0.38, e), lerpf(0.0, -0.25, e), 0.0),
				"head": Vector3(lerpf(0.0, -0.3, e), 0.0, 0.0),
				"shoulder_r": Vector3(lerpf(0.9, 0.35, e), 0.0, lerpf(0.0, 0.95, e)), "elbow_r": Vector3(lerpf(1.6, 0.7, e), 0.0, 0.0),
				"shoulder_l": Vector3(lerpf(0.9, -0.55, e), 0.0, lerpf(0.0, -0.75, e)), "elbow_l": Vector3(lerpf(1.6, 0.5, e), 0.0, 0.0)}
		"spin_kick":     # foot reaches straight ahead at hip height (Task 7: thigh z -0.95 crossed it 45° to the left)
			var e2: float = _sm(u / 0.8)
			return {"thigh_r": Vector3(lerpf(0.9, 1.5, e2), 0.0, lerpf(-0.2, -0.3, e2)), "knee_r": Vector3(lerpf(-1.6, -0.05, e2), 0.0, 0.0),
				"torso": Vector3(lerpf(0.0, 0.32, e2), 0.0, lerpf(0.0, 0.42, e2)), "head": Vector3(0.0, 0.0, lerpf(0.0, -0.35, e2)),
				"shoulder_l": Vector3(0.6, 0.0, lerpf(0.3, -0.8, e2)), "elbow_l": Vector3(1.4, 0.0, 0.0),
				"shoulder_r": Vector3(0.3, 0.0, lerpf(-0.3, 0.9, e2)), "elbow_r": Vector3(1.0, 0.0, 0.0)}
		"scissor":
			var open_k: float = _sm(u / 0.4)
			var close_k: float = _sm((u - 0.42) / 0.3)
			var spread: float = open_k * (1.0 - 0.75 * close_k)
			return {"thigh_r": Vector3(0.2 + 1.35 * spread, 0.0, -0.1), "knee_r": Vector3(-0.15, 0.0, 0.0),
				"thigh_l": Vector3(0.2 - 0.95 * spread, 0.0, 0.1), "knee_l": Vector3(-0.35 - 0.4 * close_k, 0.0, 0.0),
				"torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(0.0, -0.4, 0.0),
				"shoulder_l": Vector3(1.6, 0.0, -0.4), "elbow_l": Vector3(0.3, 0.0, 0.0),
				"shoulder_r": Vector3(1.9, 0.0, 0.5), "elbow_r": Vector3(0.25, 0.0, 0.0)}
		"tuck":
			var k: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"thigh_l": Vector3(1.9 * k, 0.0, 0.1), "thigh_r": Vector3(1.9 * k, 0.0, -0.1), "knee_l": Vector3(-2.2 * k, 0.0, 0.0),
				"knee_r": Vector3(-2.2 * k, 0.0, 0.0), "torso": Vector3(0.5 * k, 0.0, 0.0), "head": Vector3(0.4 * k, 0.0, 0.0),
				"shoulder_l": Vector3(1.2 * k, 0.0, -0.2), "shoulder_r": Vector3(1.2 * k, 0.0, 0.2),
				"elbow_l": Vector3(1.4 * k, 0.0, 0.0), "elbow_r": Vector3(1.4 * k, 0.0, 0.0)}
		"dodge_lean":
			var k2: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"torso": Vector3(-0.45 * k2, 0.0, 0.25 * k2), "head": Vector3(-0.2 * k2, 0.0, 0.0),
				"knee_l": Vector3(-0.5 * k2, 0.0, 0.0), "knee_r": Vector3(-0.5 * k2, 0.0, 0.0),
				"shoulder_l": Vector3(1.1, 0.0, -0.4), "elbow_l": Vector3(2.0, 0.0, 0.0), "shoulder_r": Vector3(1.1, 0.0, 0.4), "elbow_r": Vector3(2.0, 0.0, 0.0)}
		"block":
			var k3: float = _sm(u / 0.3) * (1.0 - _sm((u - 0.7) / 0.3))
			return {"shoulder_l": Vector3(1.5 * k3 + 0.6, 0.0, -0.2), "elbow_l": Vector3(2.2, 0.0, 0.0),
				"shoulder_r": Vector3(1.5 * k3 + 0.6, 0.0, 0.2), "elbow_r": Vector3(2.2, 0.0, 0.0),
				"torso": Vector3(-0.15 * k3, 0.0, 0.0), "head": Vector3(0.2 * k3, 0.0, 0.0)}
		"knee":
			var k4: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"thigh_l": Vector3(1.7 * k4, 0.0, 0.0), "knee_l": Vector3(-2.2 * k4, 0.0, 0.0),
				"torso": Vector3(-0.25 * k4, 0.0, 0.0), "shoulder_l": Vector3(1.3, 0.0, -0.3), "shoulder_r": Vector3(1.3, 0.0, 0.3),
				"elbow_l": Vector3(1.5, 0.0, 0.0), "elbow_r": Vector3(1.5, 0.0, 0.0)}
		"spin_kick_add":   # additive on Kick_Right: swing the leg out and round, lean away (0 at both ends, peak at ADD_HIT)
			var ks: float = pow(sin(clampf(u, 0.0, 1.0) * PI), 2.0)
			return {"thigh_r": Vector3(0.15 * ks, 0.0, 0.55 * ks), "torso": Vector3(0.1 * ks, 0.0, 0.35 * ks),
				"head": Vector3(0.0, 0.0, -0.25 * ks), "shoulder_l": Vector3(0.0, 0.0, -0.5 * ks), "shoulder_r": Vector3(0.0, 0.0, 0.4 * ks)}
		"knee_add":        # additive on Kick_Left: lift the thigh higher and fold the shin into a knee (0 at both ends)
			var kk: float = pow(sin(clampf(u, 0.0, 1.0) * PI), 2.0)
			return {"thigh_l": Vector3(0.35 * kk, 0.0, 0.0), "knee_l": Vector3(-1.6 * kk, 0.0, 0.0), "torso": Vector3(-0.2 * kk, 0.0, 0.0)}
		"uppercut":   # additive on a left punch clip: drive the fist upward through the impact
			var k5: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"shoulder_l": Vector3(0.9 * k5, 0.0, 0.0), "elbow_l": Vector3(0.6 * k5, 0.0, 0.0), "torso": Vector3(-0.2 * k5, 0.0, 0.15 * k5)}
		"victory":
			var k6: float = _sm(u / 0.25)
			return {"shoulder_r": Vector3(2.9 * k6, 0.0, 0.3), "elbow_r": Vector3(0.3, 0.0, 0.0),
				"shoulder_l": Vector3(0.3, 0.0, -0.3), "torso": Vector3(-0.1 * k6, 0.0, 0.0), "head": Vector3(-0.25 * k6, 0.0, 0.0)}
		"lie_back":   # flat on the back, arms out, slow breathing (loop phase u)
			var br2: float = sin(u * TAU) * 0.02
			return {"body_pitch": PI * 0.5, "body_y": _lay_drop(PI * 0.5),
				"thigh_l": Vector3(0.35, 0.0, 0.1), "thigh_r": Vector3(0.05, 0.0, -0.12), "knee_l": Vector3(-0.6, 0.0, 0.0),
				"knee_r": Vector3(-0.1, 0.0, 0.0), "torso": Vector3(br2, 0.0, 0.0), "head": Vector3(0.1, 0.25, 0.0),
				"shoulder_l": Vector3(0.3, 0.0, -1.1), "elbow_l": Vector3(0.35, 0.0, 0.0),
				"shoulder_r": Vector3(0.15, 0.0, 0.9), "elbow_r": Vector3(0.5, 0.0, 0.0)}
		"fall_back":  # knocked out at the code tier: topple onto the back over the first 40 %, then lie_back
			var kf: float = _sm(u / 0.4)
			var lp: Dictionary = code_pose("lie_back", 0.0)
			var out: Dictionary = {}
			for j: String in lp.keys():
				if j == "body_y":
					continue
				out[j] = (lp[j] as Vector3) * kf if lp[j] is Vector3 else float(lp[j]) * kf
			out["body_y"] = _lay_drop(float(out["body_pitch"]))
			return out
		"getup":      # from lie_back: sit up (knees up, hands back on the floor), rock forward into a squat, stand up
			var g: Array = _getup_keys(u)   # [pitch, pivot height, thigh_l, knee_l, thigh_r, knee_r, shoulder x, shoulder z, elbow]
			return {"body_pitch": g[0], "body_y": float(g[1]) - PIVOT_Y,
				"thigh_l": Vector3(g[2], 0.0, 0.1), "knee_l": Vector3(g[3], 0.0, 0.0),
				"thigh_r": Vector3(g[4], 0.0, -0.1), "knee_r": Vector3(g[5], 0.0, 0.0),
				"head": Vector3(-0.15 * sin(clampf(u, 0.0, 1.0) * PI), 0.0, 0.0),
				"shoulder_l": Vector3(g[6], 0.0, -float(g[7])), "elbow_l": Vector3(g[8], 0.0, 0.0),
				"shoulder_r": Vector3(g[6], 0.0, g[7]), "elbow_r": Vector3(g[8], 0.0, 0.0)}
	return {}
