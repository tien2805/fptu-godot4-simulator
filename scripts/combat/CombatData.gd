# File: res://scripts/combat/CombatData.gd
# Story Phase B unarmed Vovinam combat (spec 2026-10-25-story-phase-b-days-1-4-design.md, B-D1 / B-D2): every number of the
# player's moves and the melee enemies, the archetype table (courier / clone / dolly; Phase C: soi_xam), the game texts, the
# code-pose library laid over the rigged bodies by CombatPose (the Phase C "sw_*" staff / katana poses live in SwordData),
# and play_clip() (a Quaternius pack clip fitted to a gameplay duration so its impact frame lands on the move's hit time).
# Times are game seconds (Engine.time_scale applies) unless named "real".
# Plain text only in the strings below (owner rule 2026-10-25: no emoji or decorative symbols; key glyphs in hints only).
class_name CombatData
extends RefCounted

# ----- player -----
const PLAYER_HP: float = 100.0
const REGEN_DELAY: float = 4.0           # no damage for 4 s -> regenerate
const REGEN_RATE: float = 10.0           # HP per second
const COMBO_GRACE: float = 0.5           # next light press this long after a move ends continues the combo
const CHAIN_AFTER_HIT: float = 0.06      # a queued light / heavy starts this long after the impact
const LUNGE_MAX: float = 1.2             # m: an attack steps toward (and follows) a target out of reach, per move
const LUNGE_DECEL: float = 18.0          # = ThirdPersonController.DECEL (impulse v0 = sqrt(2 * decel * d))
const LIGHT: Array[Dictionary] = [
	{"id": "jab", "clip": "punch_l", "from": 0.25, "hit_at": 0.57, "dur": 0.34, "hit": 0.18, "dmg": 8.0, "stagger": 16.0, "reach": 1.5, "half_deg": 60.0, "push": 0.25},
	{"id": "cross", "clip": "punch", "from": 0.25, "hit_at": 0.57, "dur": 0.38, "hit": 0.20, "dmg": 10.0, "stagger": 20.0, "reach": 1.5, "half_deg": 60.0, "push": 0.3},
	{"id": "elbow", "clip": "chop", "from": 0.2, "hit_at": 0.5, "dur": 0.50, "hit": 0.24, "dmg": 14.0, "stagger": 30.0, "reach": 1.4, "half_deg": 60.0, "push": 0.6},
]
## Đá tạt: sweeping roundhouse, hits every enemy in its arc, breaks blocks.
const HEAVY: Dictionary = {"id": "heavy", "clip": "kick", "from": 0.1, "hit_at": 0.5, "dur": 0.72, "hit": 0.36, "dmg": 18.0, "stagger": 40.0,
	"reach": 2.0, "half_deg": 70.0, "push": 1.2, "breaks_block": true}
## Automatic counter-strike of a perfect block (lands at once on the attacker).
const COUNTER: Dictionary = {"id": "counter", "clip": "punch", "from": 0.4, "hit_at": 0.57, "dur": 0.4, "hit": 0.06, "dmg": 12.0, "stagger": 45.0,
	"push": 0.8, "stun": 0.6}
const SPEED_CAP: Dictionary = {"light": 0.8, "heavy": 0.4, "counter": 0.4, "finisher": 0.0, "hitstun": 0.4, "block": 1.2, "down": 0.0}
const PERFECT_BLOCK_S: float = 0.2       # block pressed at most this long before the hit lands
const BLOCK_REARM_S: float = 0.35        # Q must have been up this long for a press to arm the perfect window (no mashing)
const HITSTUN_S: float = 0.35
const HEAVY_KNOCK_POWER: float = 3.0     # an unblockable heavy knocks the player down (ThirdPersonController.knock_down)
const DODGE_HOSTILE_M: float = 6.0       # Space dodge-rolls when a hostile is this close (jumps otherwise)
const DODGE_S: float = 0.5
const DODGE_SPEED: float = 6.5
const DODGE_IFRAMES: float = 0.35
const DODGE_COOLDOWN: float = 0.15       # after the roll ends
const LOCK_RANGE: float = 7.0
const LOCK_HALF_DEG: float = 75.0
const LOCK_CLOSE: float = 2.5            # fallback: anyone this close, any direction
const FINISHER_RANGE: float = 2.2
const FINISHER_S: float = 1.0
const FINISHER_IMPACT: float = 0.35
const FINISHER_DMG: float = 35.0         # archetypes whose finisher does not knock out (Dolly)
const SLOWMO_SCALE: float = 0.3
const SLOWMO_REAL_S: float = 0.3
## Pedestrians / officers in free roam (Phase W rules, W-D3): the unarmed reach and arc, combo window.
const PED_REACH: float = 1.6
const PED_HALF_DEG: float = 50.0
const PED_COMBO_S: float = 1.5

# ----- enemies -----
const TELEGRAPH_S: float = 0.5
const DAZE_S: float = 2.5
const STAGGER_S: float = 0.4
const GUARD_BREAK_S: float = 0.8
const KNOCKDOWN_LIE_S: float = 1.2
const GETUP_S: float = 0.9
const FLEE_S: float = 3.0
const STAGGER_DECAY_DELAY: float = 1.5
const STAGGER_DECAY: float = 15.0        # per second
const BLOCKED_RECOVER_ADD: float = 0.35
const BLOCK_CHIP_STAGGER: float = 4.0
const ENGAGE_TIMEOUT: float = 3.0
## Light attacks are read from a wind-up pose (jab_windup_r / _l) held over the whole WINDUP: the tell starts `windup` +
## ENEMY_LIGHT.hit before the impact (0.38-0.45 s with the archetype windups below; CHAIN_WINDUP for a chained punch).
const CHAIN_WINDUP: float = 0.2
const HELD_MAX_S: float = 1.5            # an enemy held for a finisher that never lands is let go
const STUCK_S: float = 4.0               # wedged / off the ring this long (or fallen 1 s): back to its spawn point
const FALL_BELOW_M: float = 3.0          # this far below its spawn point = fallen
const LEASH_M: float = 35.0              # this far from the player = lost
const RESPAWN_MAX: int = 2               # then it counts as knocked out
const ENEMY_RADIUS: float = 0.3
const ENEMY_HEIGHT: float = 1.7
const SEPARATION_M: float = 1.3
const KO_STARS_S: float = 5.0
const ENEMY_LIGHT: Dictionary = {"clip": "punch", "from": 0.25, "hit_at": 0.57, "dur": 0.45, "hit": 0.18}
const ENEMY_LIGHT_ALT: Dictionary = {"clip": "punch_l", "from": 0.25, "hit_at": 0.57, "dur": 0.45, "hit": 0.18}
const ENEMY_HEAVY: Dictionary = {"clip": "kick", "from": 0.15, "hit_at": 0.5, "dur": 0.6, "hit": 0.2}
## Archetypes (B-D2). look = CharacterBuilder opts (callers merge their own "body" opts over it: helmet colours, masks...).
const ARCHETYPES: Dictionary = {
	"courier": {"hp": 70.0, "stagger_max": 60.0, "speed": 3.8, "circle_speed": 1.3, "circle_r": 3.0, "reach": 1.3,
		"light_dmg": 8.0, "heavy_dmg": 20.0, "heavy_chance": 0.3, "windup": 0.26, "recover": 0.8, "chain": 2,
		"block_chance": 0.3, "dodge_chance": 0.0, "think": Vector2(0.5, 1.2), "cooldown": Vector2(0.8, 1.8),
		"taunt_chance": 0.15, "flee_at": 0.0, "finisher_ko": true,
		"look": {"preset": "rider", "body": "hoodie", "backpack": false, "female": false}},
	"clone": {"hp": 45.0, "stagger_max": 45.0, "speed": 3.5, "circle_speed": 1.2, "circle_r": 3.2, "reach": 1.3,
		"light_dmg": 7.0, "heavy_dmg": 18.0, "heavy_chance": 0.25, "windup": 0.27, "recover": 0.9, "chain": 1,
		"block_chance": 0.15, "dodge_chance": 0.0, "think": Vector2(0.6, 1.4), "cooldown": Vector2(1.0, 2.2),
		"taunt_chance": 0.25, "flee_at": 0.0, "finisher_ko": true,
		"look": {"preset": "student_m", "seed": 4040, "female": false, "backpack": false, "glasses": false}},
	"dolly": {"hp": 150.0, "stagger_max": 90.0, "speed": 4.8, "circle_speed": 2.0, "circle_r": 2.8, "reach": 1.35,
		"light_dmg": 9.0, "heavy_dmg": 22.0, "heavy_chance": 0.4, "windup": 0.2, "recover": 0.55, "chain": 3,
		"block_chance": 0.1, "dodge_chance": 0.45, "think": Vector2(0.3, 0.8), "cooldown": Vector2(0.5, 1.2),
		"taunt_chance": 0.2, "flee_at": 0.3, "finisher_ko": false,
		"look": {"preset": "student_f", "seed": 777, "female": true, "backpack": false}},
	## Phase C (spec C-D4, Day 2): the Bầy Sói leader, an unarmed mini-boss. Fast 4-hit chains (light tell 0.2 + 0.18 s, the
	## follow-through shortened by attack_speed: a hit every 0.52 s), the
	## LED eyes glow before every attack, a howl at 50 % HP buffs him; the finisher does not knock him out; boss bar.
	"soi_xam": {"hp": 220.0, "stagger_max": 110.0, "speed": 5.2, "circle_speed": 2.2, "circle_r": 2.7, "reach": 1.35,
		"light_dmg": 8.0, "heavy_dmg": 20.0, "heavy_chance": 0.3, "windup": 0.2, "recover": 0.55, "chain": 4, "attack_speed": 1.4,
		"block_chance": 0.25, "dodge_chance": 0.2, "think": Vector2(0.3, 0.7), "cooldown": Vector2(0.5, 1.1),
		"taunt_chance": 0.1, "flee_at": 0.0, "finisher_ko": false, "boss": true, "glow": true, "howl_at": 0.5,
		"howl": {"speed": 1.25, "circle_speed": 1.25, "light_dmg": 1.3, "heavy_dmg": 1.3, "windup": 0.85, "recover": 0.7,
			"cooldown": 0.7, "think": 0.7, "chain": 1},
		"howl_line": "Sói Xám nổi điên rồi!", "sfx": ["howl"],
		"look": {"preset": "rider", "body": "hoodie", "helmet_color": Color("#7D848C"), "seed": 2020, "female": false, "backpack": false}},
}
const HOWL_S: float = 1.4               # Sói Xám's howl (armoured)
const DODGE_SIDE_S: float = 0.3          # enemy side-step (Dolly)
const DODGE_SIDE_SPEED: float = 6.0

# ----- texts (plain, Vietnamese) -----
const T_HP: String = "Máu"
const T_COUNTER: String = "PHẢN ĐÒN"
const T_FINISHER_PROMPT: String = "[E] Hạ gục"
const T_FINISHED: String = "HẠ GỤC"
const T_GUARD_BREAK: String = "PHÁ THẾ THỦ"
const T_UNARMED_ONLY: String = "Nhiệm vụ này chỉ dùng tay không"
## Control hint under the HP bar during a fight (key glyphs: allowed in control hints).
const T_CONTROLS: String = "[Chuột trái] đấm · [Chuột phải] đá tạt · [Q] đỡ · [Space] lăn né · [E] hạ gục"
## Refusals while a fight runs (MeleeFight / FreeRoam).
const T_FIGHT_BIKE: String = "Đang đánh nhau, chưa lấy xe được"
const T_FIGHT_PHONE: String = "Đang đánh nhau, chưa xem điện thoại được"
const T_FIGHT_EMOTE: String = "Đang đánh nhau, không phải lúc diễn"

# ----- sounds (CineAudio A1 cues, WeaponAudio Phase W cues) -----
const CINE_CUES: Array[String] = ["impact_light", "impact_medium", "impact_heavy", "groan", "body_fall", "whoosh_down"]

## Men's native clip lengths (s) the "from" / "hit_at" windows above are authored on; women's files stretch every clip.
const REF_LEN: Dictionary = {"Punch_Left": 0.8333, "Punch_Right": 0.8333, "Sword_Slash": 1.0333, "Kick_Right": 0.9333,
	"Kick_Left": 0.9333, "HitRecieve": 0.5667, "HitRecieve_2": 0.5667, "Roll": 1.3333, "Death": 1.0667}
const UPPER_JOINTS: Array[String] = ["torso", "head", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r"]
static var _pose_cache: Dictionary = {}


static func archetype(id: String) -> Dictionary:
	return ARCHETYPES.get(id, ARCHETYPES["clone"])


## Play a pack clip (CharacterBuilder.PACK_CLIP name) on a rigged body for `dur` game seconds. With hit_at >= 0 the clip
## starts at `from` (s, men's timing) and runs at the speed that puts clip time hit_at at `hit_t` seconds; otherwise it is
## stretched to fill dur. Bodies without an AnimationPlayer just play the named clip.
static func play_clip(model: Node3D, clip: String, dur: float, from: float = 0.0, hit_at: float = -1.0, hit_t: float = -1.0) -> void:
	if model == null:
		return
	CharacterBuilder.play(model, clip, dur)
	var an: Node = CharacterBuilder.get_animator(model)
	var ap: AnimationPlayer = an.get("player") as AnimationPlayer if an else null
	var anim: String = String(CharacterBuilder.PACK_CLIP.get(clip, ""))
	if ap == null or anim == "" or not ap.has_animation(anim):
		return
	var length: float = ap.get_animation(anim).length
	var k: float = length / float(REF_LEN.get(anim, length))
	var speed: float = 1.0
	if hit_at >= 0.0 and hit_t > 0.0:
		speed = maxf((hit_at - from) * k, 0.01) / hit_t
	elif dur > 0.0:
		speed = maxf(length - from * k, 0.01) / dur
	if from > 0.0:
		ap.seek(from * k, true)
	ap.speed_scale = clampf(speed, 0.2, 4.0)


## Code pose {CharacterBuilder joint: Euler (character frame)} for CombatPose at progress u (0..1; loops: phase).
## Static poses are cached (no allocation per frame).
static func pose(pose_name: String, u: float) -> Dictionary:
	match pose_name:
		"guard", "block", "windup", "brace", "jab_windup_r", "jab_windup_l":
			if not _pose_cache.has(pose_name):
				_pose_cache[pose_name] = _static_pose(pose_name)
			return _pose_cache[pose_name]
		"stunned", "taunt", "dodge_lean", "hip_throw", "winded":
			return CineMoves.code_pose(pose_name, u)
		"howl":                  # Sói Xám: head thrown back, arms spread, a tremble (loop phase u)
			var k: float = sin(u * TAU * 3.0) * 0.05
			return {"torso": Vector3(-0.3, 0.0, k), "head": Vector3(-0.75 + k, 0.0, 0.0),
				"shoulder_l": Vector3(0.45, 0.0, -1.15 - k), "elbow_l": Vector3(0.5, 0.0, 0.0),
				"shoulder_r": Vector3(0.45, 0.0, 1.15 + k), "elbow_r": Vector3(0.5, 0.0, 0.0)}
	if pose_name.begins_with("sw_"):
		return SwordData.pose(pose_name, u)   # Phase C staff and katana poses
	return {}


static func _static_pose(pose_name: String) -> Dictionary:
	match pose_name:
		"guard":                 # the fighting stance's arms and torso only (legs keep walking)
			var st: Dictionary = CineMoves.code_pose("stance", 0.0)
			var out: Dictionary = {}
			for j: String in UPPER_JOINTS:
				if st.has(j):
					out[j] = st[j]
			return out
		"block":                 # forearms up in front of the face
			return CineMoves.code_pose("block", 0.5)
		"windup":                # telegraphed heavy: weight back, right arm cocked high, left arm out front
			return {"torso": Vector3(0.22, 0.7, 0.0), "head": Vector3(-0.12, -0.45, 0.0),
				"shoulder_r": Vector3(0.5, 0.0, 1.25), "elbow_r": Vector3(2.2, 0.0, 0.0),
				"shoulder_l": Vector3(1.25, 0.0, -0.3), "elbow_l": Vector3(1.4, 0.0, 0.0)}
		"jab_windup_r":          # light attack tell: the punching fist pulled back to the cheek, shoulders turned, weight back
			return {"torso": Vector3(0.18, 0.5, 0.0), "head": Vector3(-0.1, -0.35, 0.0),
				"shoulder_r": Vector3(0.35, 0.0, 0.55), "elbow_r": Vector3(2.35, 0.0, 0.0),
				"shoulder_l": Vector3(1.3, 0.0, -0.2), "elbow_l": Vector3(1.3, 0.0, 0.0)}
		"jab_windup_l":          # the same, left fist (mirror: sides swapped, y and z negated)
			var m: Dictionary = {}
			var r: Dictionary = _static_pose("jab_windup_r")
			for j: String in r.keys():
				var v: Vector3 = r[j]
				var k: String = j.replace("_r", "_X").replace("_l", "_r").replace("_X", "_l")
				m[k] = Vector3(v.x, -v.y, -v.z)
			return m
		"brace":                 # hit while blocking: arms crossed tight, leaning in
			var b: Dictionary = CineMoves.code_pose("block", 0.5).duplicate()
			b["torso"] = Vector3(-0.25, 0.0, 0.0)
			return b
	return {}
