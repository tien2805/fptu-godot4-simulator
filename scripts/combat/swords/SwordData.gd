# File: res://scripts/combat/swords/SwordData.gd
# Story Phase C sword duels (spec 2026-10-26-story-phase-c-days-2-3-5-design.md, C-D3 / C-D4 Day 5): every number of the
# player's Vovinam staff (the PlayerCombat move set STAFF), the Za Mẫn katana boss (stats, steps, patterns, phases, katana
# bend stages, finale), the game texts and the code poses "sw_*" that CombatData.pose() hands over to pose() below.
# Times are game seconds. Plain text only (owner rule: no emoji or decorative symbols; key glyphs in the control hint).
class_name SwordData
extends RefCounted

# ----- texts (plain, Vietnamese) -----
const T_CONTROLS: String = "[Chuột trái] chém gậy · [Chuột phải] đâm · [Q] đỡ, gạt đúng lúc · [Space] lăn né"
const T_PARRY: String = "GẠT ĐỠ"
const T_BOSS: String = "Lê Minh Za Mẫn"
## Popups on a phase change (index = the new phase).
const T_PHASE: Array[String] = ["", "", "Za Mẫn: Pivot chiến lược!", "Za Mẫn: Scale lên gấp mười!"]
## Popups when the katana bends one stage further (index = the new stage).
const T_BEND: Array[String] = ["", "Za Mẫn: Hàng chính hãng mà...", "Za Mẫn: Cong nhẹ thôi, vẫn ổn!", "Za Mẫn: Shop bảo bảo hành 7 ngày..."]
## The comic finisher: the katana snaps at 0 HP.
const T_BREAK: String = "Za Mẫn: Kiếm order trên mạng... đánh giá 5 sao mà!"

# ----- player: the Vovinam staff (PlayerCombat move set) -----
const STAFF_LIGHT: Array[Dictionary] = [
	{"id": "slash1", "clip": "chop", "from": 0.2, "hit_at": 0.5, "dur": 0.36, "hit": 0.18, "dmg": 9.0, "stagger": 14.0, "reach": 1.9, "half_deg": 70.0, "push": 0.25, "pose": "sw_staff_slash_a"},
	{"id": "slash2", "clip": "chop", "from": 0.2, "hit_at": 0.5, "dur": 0.40, "hit": 0.20, "dmg": 11.0, "stagger": 18.0, "reach": 1.9, "half_deg": 70.0, "push": 0.3, "pose": "sw_staff_slash_b"},
	{"id": "slash3", "clip": "chop", "from": 0.15, "hit_at": 0.5, "dur": 0.52, "hit": 0.26, "dmg": 15.0, "stagger": 28.0, "reach": 2.0, "half_deg": 60.0, "push": 0.6, "pose": "sw_staff_slash_c"},
]
## Đâm gậy: a long straight thrust, narrow, breaks the katana's guard.
## Clip "": the code pose alone (a pack punch twists the body and would turn the staff sideways).
const STAFF_HEAVY: Dictionary = {"id": "thrust", "clip": "", "dur": 0.7, "hit": 0.34, "dmg": 20.0,
	"stagger": 40.0, "reach": 2.4, "half_deg": 30.0, "push": 1.0, "breaks_block": true, "pose": "sw_staff_thrust"}
## The parry riposte of a perfect block: lands at once, the boss staggers PARRY_STUN.
const PARRY_STUN: float = 1.3
const STAFF_PARRY: Dictionary = {"id": "parry", "clip": "", "dur": 0.45, "hit": 0.06, "dmg": 8.0,
	"stagger": 50.0, "push": 0.6, "stun": PARRY_STUN, "pose": "sw_staff_riposte"}
const STAFF: Dictionary = {"light": STAFF_LIGHT, "heavy": STAFF_HEAVY, "counter": STAFF_PARRY, "controls": T_CONTROLS,
	"counter_text": T_PARRY, "block_pose": "sw_staff_block", "idle_pose": "sw_staff_guard", "dodge_m": 14.0, "blade": true,
	"cues": {"punch": "blade_clash", "swish": "staff_swish", "whoosh_down": "staff_swish", "impact_light": "staff_hit",
		"impact_heavy": "staff_hit_heavy", "knife_hit": "parry_ring"}}
const STAFF_LEN: float = 1.6
const STAFF_BACK: float = 0.15           # m of staff behind the fist
const STAFF_TILT: float = 0.17           # rad off the forearm, toward the thumb side
const KATANA_TILT: float = 0.45

# ----- the Za Mẫn katana boss -----
## Every boss hit lands exactly TELL_S after its glint + sound.
const TELL_S: float = 0.5
## MeleeEnemy stats (callers' "stats" opts override them); heavy_chance 0: KatanaBoss picks patterns itself.
const ZA_MAN: Dictionary = {"hp": 300.0, "stagger_max": 180.0, "speed": 4.0, "circle_speed": 1.5, "circle_r": 3.4, "reach": 1.9,
	"light_dmg": 10.0, "heavy_dmg": 20.0, "heavy_chance": 0.0, "windup": 0.25, "recover": 0.9, "chain": 1,
	"block_chance": 0.3, "dodge_chance": 0.1, "think": Vector2(0.5, 1.0), "cooldown": Vector2(0.9, 1.6),
	"taunt_chance": 0.12, "flee_at": 0.0, "finisher_ko": false, "boss": true,
	"sfx": ["glint", "glint_red", "katana_slash", "katana_boing", "katana_snap", "blade_clash", "parry_ring", "staff_swish", "staff_hit", "staff_hit_heavy"],
	"look": {"preset": "student_m", "body": "suit", "seed": 5050, "female": false, "backpack": false, "glasses": true}}
## One attack of a pattern. kind: slash (cone at the hit frame), lunge (a dash; contact any time from `hit` to `dash_s`),
## spin (all around at the hit frame). unblockable: red glint + red flash, goes through any block (dodge it).
const STEPS: Dictionary = {
	"slash_r": {"kind": "slash", "clip": "chop", "from": 0.2, "hit_at": 0.5, "dur": 0.5, "hit": 0.16, "dmg": 10.0, "reach": 1.9,
		"half_deg": 75.0, "unblockable": false, "wind": "sw_kat_wind_r", "pose": "sw_kat_slash_r"},
	"slash_l": {"kind": "slash", "clip": "chop", "from": 0.2, "hit_at": 0.5, "dur": 0.5, "hit": 0.16, "dmg": 10.0, "reach": 1.9,
		"half_deg": 75.0, "unblockable": false, "wind": "sw_kat_wind_l", "pose": "sw_kat_slash_l"},
	"slash_down": {"kind": "slash", "clip": "chop", "from": 0.15, "hit_at": 0.5, "dur": 0.55, "hit": 0.18, "dmg": 13.0, "reach": 2.0,
		"half_deg": 50.0, "unblockable": false, "wind": "sw_kat_wind_down", "pose": "sw_kat_slash_down"},
	"lunge": {"kind": "lunge", "clip": "", "dur": 0.6, "hit": 0.12, "dmg": 18.0, "reach": 1.5,
		"half_deg": 60.0, "unblockable": true, "dash": 9.0, "dash_s": 0.45, "wind": "sw_kat_wind_lunge", "pose": "sw_kat_lunge"},
	"spin": {"kind": "spin", "clip": "", "dur": 0.7, "hit": 0.3, "dmg": 15.0, "reach": 2.5, "half_deg": 180.0, "unblockable": true,
		"turns": 1.5, "wind": "sw_kat_wind_spin", "pose": "sw_kat_spin"},
}
const PATTERNS: Dictionary = {
	"chain2": ["slash_r", "slash_l"],
	"chain3": ["slash_r", "slash_l", "slash_down"],
	"lunge": ["lunge"],
	"spin": ["spin"],
	"frenzy": ["slash_r", "slash_l", "slash_r", "lunge"],
}
## Phases (index 0 = phase 1): from HP fraction `at`; speed_k scales movement and the follow-through after each hit;
## gap = pause between a chain's hits before the next glint; new patterns: spin (phase 2), frenzy (phase 3).
const PHASES: Array[Dictionary] = [
	{"at": 1.0, "speed_k": 1.0, "recover": 0.9, "cooldown": Vector2(0.9, 1.6), "gap": 0.3, "block_chance": 0.3,
		"patterns": ["chain2", "chain3", "lunge"]},
	{"at": 0.66, "speed_k": 1.2, "recover": 0.65, "cooldown": Vector2(0.6, 1.1), "gap": 0.2, "block_chance": 0.35,
		"patterns": ["chain3", "lunge", "spin"]},
	{"at": 0.33, "speed_k": 1.4, "recover": 0.45, "cooldown": Vector2(0.35, 0.8), "gap": 0.12, "block_chance": 0.4,
		"patterns": ["chain3", "spin", "frenzy", "lunge"]},
]
const PHASE_TAUNT_S: float = 0.8
const LUNGE_MIN_M: float = 2.4           # the lunge is picked from at least this far (closer: a chain)
## Katana bend stages: stage k from HP fraction BEND_AT[k - 1] down; total blade bend per stage (rad).
const BEND_AT: Array[float] = [0.75, 0.5, 0.25]
const BEND_RAD: Array[float] = [0.0, 0.35, 0.8, 1.4]
const FINALE_S: float = 1.8              # snap, the stare and the line, then the knockout

# ----- code poses (CombatPose joints, character frame) -----
## Held poses (also the ends of the swings below).
## Held poses (also the ends of the swings below). Measured on the rig: +torso y turns the right shoulder forward, shoulder x
## raises the arm forward, shoulder y then swings it toward the left, shoulder z lifts it out to the side (right) / in (left),
## elbow x bends the forearm up; the forearm's angle from straight down is about shoulder x + elbow x + 0.42 (the rest bend).
## The staff runs along the forearm (+STAFF_TILT), the katana KATANA_TILT above it.
const POSES: Dictionary = {
	"sw_staff_guard": {"torso": Vector3(0.08, 0.15, 0.0), "head": Vector3(-0.05, -0.15, 0.0),
		"shoulder_r": Vector3(0.5, 0.0, 0.1), "elbow_r": Vector3(0.9, 0.0, 0.0),
		"shoulder_l": Vector3(0.7, 0.0, 0.0), "elbow_l": Vector3(1.6, 0.0, 0.0)},
	"sw_staff_block": {"torso": Vector3(-0.08, 0.1, 0.0), "head": Vector3(0.05, -0.1, 0.0),
		"shoulder_r": Vector3(1.0, 0.0, 0.0), "elbow_r": Vector3(1.55, 0.0, 0.0),
		"shoulder_l": Vector3(1.0, 0.0, 0.3), "elbow_l": Vector3(1.6, 0.0, 0.0)},
	"staff_cock_r": {"torso": Vector3(0.05, -0.45, 0.0), "head": Vector3(0.0, 0.45, 0.0),
		"shoulder_r": Vector3(0.9, -1.1, 0.0), "elbow_r": Vector3(0.3, 0.0, 0.0),
		"shoulder_l": Vector3(0.7, 0.0, 0.0), "elbow_l": Vector3(1.6, 0.0, 0.0)},
	"staff_follow_l": {"torso": Vector3(0.15, 0.45, 0.0), "head": Vector3(0.0, -0.45, 0.0),
		"shoulder_r": Vector3(0.9, 0.9, 0.0), "elbow_r": Vector3(0.1, 0.0, 0.0),
		"shoulder_l": Vector3(0.5, 0.0, -0.2), "elbow_l": Vector3(1.4, 0.0, 0.0)},
	"staff_cock_l": {"torso": Vector3(0.05, 0.45, 0.0), "head": Vector3(0.0, -0.45, 0.0),
		"shoulder_r": Vector3(1.0, 0.9, 0.0), "elbow_r": Vector3(1.2, 0.0, 0.0),
		"shoulder_l": Vector3(0.6, 0.0, -0.2), "elbow_l": Vector3(1.5, 0.0, 0.0)},
	"staff_follow_r": {"torso": Vector3(0.12, -0.4, 0.0), "head": Vector3(0.0, 0.4, 0.0),
		"shoulder_r": Vector3(0.9, -1.0, 0.0), "elbow_r": Vector3(0.1, 0.0, 0.0),
		"shoulder_l": Vector3(0.7, 0.0, 0.0), "elbow_l": Vector3(1.6, 0.0, 0.0)},
	"staff_cock_up": {"torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(-0.1, 0.0, 0.0),
		"shoulder_r": Vector3(2.5, 0.0, 0.1), "elbow_r": Vector3(1.2, 0.0, 0.0),
		"shoulder_l": Vector3(2.3, 0.0, 0.2), "elbow_l": Vector3(1.3, 0.0, 0.0)},
	"staff_follow_down": {"torso": Vector3(0.3, 0.0, 0.0), "head": Vector3(-0.1, 0.0, 0.0),
		"shoulder_r": Vector3(0.8, 0.0, 0.0), "elbow_r": Vector3(0.1, 0.0, 0.0),
		"shoulder_l": Vector3(0.8, 0.0, 0.3), "elbow_l": Vector3(0.4, 0.0, 0.0)},
	"staff_thrust_wind": {"torso": Vector3(0.0, -0.4, 0.0), "head": Vector3(0.0, 0.4, 0.0),
		"shoulder_r": Vector3(-0.35, 0.0, 0.15), "elbow_r": Vector3(1.3, 0.0, 0.0),
		"shoulder_l": Vector3(1.2, 0.0, 0.0), "elbow_l": Vector3(0.3, 0.0, 0.0)},
	"staff_thrust_end": {"torso": Vector3(0.3, 0.25, 0.0), "head": Vector3(-0.25, -0.25, 0.0),
		"shoulder_r": Vector3(0.8, -0.2, 0.0), "elbow_r": Vector3(0.03, 0.0, 0.0),
		"shoulder_l": Vector3(0.3, 0.0, -0.4), "elbow_l": Vector3(1.0, 0.0, 0.0)},
	"sw_kat_guard": {"torso": Vector3(0.1, 0.15, 0.0), "head": Vector3(-0.05, -0.15, 0.0),
		"shoulder_r": Vector3(0.6, 0.0, 0.0), "elbow_r": Vector3(0.6, 0.0, 0.0),
		"shoulder_l": Vector3(0.6, 0.0, 0.35), "elbow_l": Vector3(0.7, 0.0, 0.0)},
	"sw_kat_block": {"torso": Vector3(-0.1, 0.1, 0.0), "head": Vector3(0.05, -0.1, 0.0),
		"shoulder_r": Vector3(0.9, 0.3, 0.0), "elbow_r": Vector3(1.4, 0.0, 0.0),
		"shoulder_l": Vector3(0.9, 0.0, 0.4), "elbow_l": Vector3(1.4, 0.0, 0.0)},
	"sw_kat_wind_r": {"torso": Vector3(0.1, -0.5, 0.0), "head": Vector3(0.0, 0.45, 0.0),
		"shoulder_r": Vector3(1.0, -1.2, 0.2), "elbow_r": Vector3(0.6, 0.0, 0.0),
		"shoulder_l": Vector3(0.8, -0.6, 0.3), "elbow_l": Vector3(1.0, 0.0, 0.0)},
	"kat_end_r": {"torso": Vector3(0.2, 0.5, 0.0), "head": Vector3(0.0, -0.4, 0.0),
		"shoulder_r": Vector3(0.9, 0.9, 0.0), "elbow_r": Vector3(0.15, 0.0, 0.0),
		"shoulder_l": Vector3(0.6, 0.6, 0.0), "elbow_l": Vector3(0.5, 0.0, 0.0)},
	"sw_kat_wind_l": {"torso": Vector3(0.1, 0.5, 0.0), "head": Vector3(0.0, -0.4, 0.0),
		"shoulder_r": Vector3(1.2, 0.8, -0.4), "elbow_r": Vector3(1.1, 0.0, 0.0),
		"shoulder_l": Vector3(0.7, 0.8, 0.0), "elbow_l": Vector3(1.2, 0.0, 0.0)},
	"kat_end_l": {"torso": Vector3(0.15, -0.45, 0.0), "head": Vector3(0.0, 0.4, 0.0),
		"shoulder_r": Vector3(0.9, -1.0, 0.1), "elbow_r": Vector3(0.15, 0.0, 0.0),
		"shoulder_l": Vector3(0.6, -0.4, 0.2), "elbow_l": Vector3(0.6, 0.0, 0.0)},
	"sw_kat_wind_down": {"torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(-0.1, 0.0, 0.0),
		"shoulder_r": Vector3(2.6, 0.0, 0.1), "elbow_r": Vector3(1.0, 0.0, 0.0),
		"shoulder_l": Vector3(2.5, 0.0, 0.2), "elbow_l": Vector3(1.1, 0.0, 0.0)},
	"kat_end_down": {"torso": Vector3(0.35, 0.0, 0.0), "head": Vector3(-0.15, 0.0, 0.0),
		"shoulder_r": Vector3(0.75, 0.0, 0.0), "elbow_r": Vector3(0.1, 0.0, 0.0),
		"shoulder_l": Vector3(0.75, 0.0, 0.3), "elbow_l": Vector3(0.2, 0.0, 0.0)},
	"sw_kat_wind_lunge": {"torso": Vector3(0.0, -0.55, 0.0), "head": Vector3(0.0, 0.45, 0.0),
		"shoulder_r": Vector3(-0.4, 0.0, 0.2), "elbow_r": Vector3(1.1, 0.0, 0.0),
		"shoulder_l": Vector3(1.3, 0.0, 0.0), "elbow_l": Vector3(0.1, 0.0, 0.0),
		"thigh_l": Vector3(0.3, 0.0, 0.0), "knee_l": Vector3(-0.5, 0.0, 0.0), "thigh_r": Vector3(-0.2, 0.0, 0.0), "knee_r": Vector3(-0.4, 0.0, 0.0)},
	"kat_end_lunge": {"torso": Vector3(0.4, 0.3, 0.0), "head": Vector3(-0.35, -0.3, 0.0),
		"shoulder_r": Vector3(0.65, -0.3, 0.0), "elbow_r": Vector3(0.0, 0.0, 0.0),
		"shoulder_l": Vector3(-0.3, 0.0, -0.5), "elbow_l": Vector3(0.3, 0.0, 0.0),
		"thigh_l": Vector3(0.9, 0.0, 0.0), "knee_l": Vector3(-0.9, 0.0, 0.0), "thigh_r": Vector3(-0.5, 0.0, 0.0), "knee_r": Vector3(-0.1, 0.0, 0.0)},
	"sw_kat_wind_spin": {"torso": Vector3(0.1, -0.6, 0.0), "head": Vector3(0.0, 0.5, 0.0),
		"shoulder_r": Vector3(1.0, -1.3, 0.3), "elbow_r": Vector3(0.15, 0.0, 0.0),
		"shoulder_l": Vector3(0.8, 0.0, -0.6), "elbow_l": Vector3(0.8, 0.0, 0.0)},
	"kat_spin": {"torso": Vector3(0.15, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0),
		"shoulder_r": Vector3(1.0, -1.5, 0.3), "elbow_r": Vector3(0.1, 0.0, 0.0),
		"shoulder_l": Vector3(1.0, 0.0, -1.2), "elbow_l": Vector3(0.4, 0.0, 0.0)},
}
## Played once over a move (u 0..1): [from pose, to pose, swing start u, swing end u] (smoothstep), then held at the end.
const SWINGS: Dictionary = {
	"sw_staff_slash_a": ["staff_cock_r", "staff_follow_l", 0.2, 0.8],
	"sw_staff_slash_b": ["staff_cock_l", "staff_follow_r", 0.2, 0.8],
	"sw_staff_slash_c": ["staff_cock_up", "staff_follow_down", 0.2, 0.75],
	"sw_staff_thrust": ["staff_thrust_wind", "staff_thrust_end", 0.3, 0.55],
	"sw_staff_riposte": ["sw_staff_block", "staff_thrust_end", 0.0, 0.2],
	"sw_kat_slash_r": ["sw_kat_wind_r", "kat_end_r", 0.0, 0.45],
	"sw_kat_slash_l": ["sw_kat_wind_l", "kat_end_l", 0.0, 0.45],
	"sw_kat_slash_down": ["sw_kat_wind_down", "kat_end_down", 0.0, 0.45],
	"sw_kat_lunge": ["sw_kat_wind_lunge", "kat_end_lunge", 0.0, 0.3],
	"sw_kat_spin": ["sw_kat_wind_spin", "kat_spin", 0.0, 0.25],
}
static var _scratch: Dictionary = {}     # swing name -> Dictionary reused every frame (read at once by CombatPose)
static var _held: Dictionary = {}        # held pose name -> POSES entry + the neutral wrist (built once)


## A held pose with "hand_r" at the neutral wrist added: the clip's wrist turns never twist the fist off the prop's grip.
static func held(pose_name: String) -> Dictionary:
	if not _held.has(pose_name):
		var d: Dictionary = (POSES[pose_name] as Dictionary).duplicate()
		d["hand_r"] = Vector3.ZERO
		_held[pose_name] = d
	return _held[pose_name]


## The code pose `pose_name` at progress u (held poses ignore u; swings ease between their two poses and hold the hips and
## chest neutral against the clip under them; "sw_kat_stare" and "sw_kat_taunt" loop). No allocation for held poses and
## swings.
static func pose(pose_name: String, u: float) -> Dictionary:
	if POSES.has(pose_name):
		return held(pose_name)
	if SWINGS.has(pose_name):
		var sw: Array = SWINGS[pose_name]
		var a: Dictionary = held(String(sw[0]))
		var b: Dictionary = held(String(sw[1]))
		var e: float = smoothstep(float(sw[2]), float(sw[3]), u)
		if not _scratch.has(pose_name):
			_scratch[pose_name] = {}
		var out: Dictionary = _scratch[pose_name]
		for j: String in a:
			out[j] = (a[j] as Vector3).lerp(b[j] as Vector3, e)
		out["hips"] = Vector3.ZERO           # the clip under a swing (punch, chop) must not turn the upper body away
		out["chest"] = Vector3.ZERO
		return out
	match pose_name:
		"sw_kat_stare":          # the finale: stares at the broken hilt held up close, trembling
			var k: float = sin(u * TAU * 4.0) * 0.06
			return {"torso": Vector3(0.2, 0.1, 0.0), "head": Vector3(0.15, 0.25, k),
				"shoulder_r": Vector3(0.8, 0.4, 0.0), "elbow_r": Vector3(1.9 + k, 0.0, 0.0),
				"shoulder_l": Vector3(0.3, 0.0, -0.25), "elbow_l": Vector3(0.4, 0.0, 0.0)}
		"sw_kat_taunt":          # a phase change: arms open, "pivot!"
			var w: float = sin(u * TAU)
			return {"torso": Vector3(-0.1, 0.0, 0.0), "head": Vector3(-0.15, 0.0, 0.15 * w),
				"shoulder_r": Vector3(0.7, 0.0, 1.0 + 0.15 * w), "elbow_r": Vector3(1.1, 0.0, 0.0),
				"shoulder_l": Vector3(0.7, 0.0, -1.0 - 0.15 * w), "elbow_l": Vector3(1.1, 0.0, 0.0)}
	return {}


## The phase (1..3) of an HP fraction.
static func phase_of(frac: float) -> int:
	var ph: int = 1
	for i: int in range(1, PHASES.size()):
		if frac <= float(PHASES[i]["at"]) + 1e-6:
			ph = i + 1
	return ph


## The katana bend stage (0..3) of an HP fraction.
static func bend_stage_of(frac: float) -> int:
	var s: int = 0
	for i: int in BEND_AT.size():
		if frac <= BEND_AT[i] + 1e-6:
			s = i + 1
	return s
