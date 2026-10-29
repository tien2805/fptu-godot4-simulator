# File: res://scripts/combat/guns/GunData.gd
# Story Phase C lair gunfights (spec 2026-10-26-story-phase-c-days-2-3-5-design.md, C-D2) and the Day 3 forklift boss
# (C-D4): every number of the cover, the enemy gunmen and the boss, the Vietnamese texts, the default looks and the
# code-pose library GunPose lays over the rigged bodies (crouch behind cover, pistol aim, driving, the name speech).
# Times are game seconds. The player's HP is PlayerCombat's (CombatData.PLAYER_HP, regeneration after REGEN_DELAY).
# Plain text only in the strings below (no emoji or decorative symbols; key glyphs in control hints only; "..." not the
# ellipsis character).
class_name GunData
extends RefCounted

# ----- cover -----
const COVER_ENTER_R: float = 1.5         # hold Ctrl this close to a cover slot to take it
const COVER_MAX_H: float = 1.4           # a box this low (top above its floor) is low cover
const COVER_MIN_H: float = 0.9           # lower boxes do not stop a bullet aimed at a crouched body
const SLOT_STEP: float = 1.1             # slots along a box face
const SLOT_OUT: float = 0.6              # a slot stands this far out from the face
const SLOT_EDGE: float = 0.25            # slots keep this far from a face's corners
const PROTECT_COS: float = 0.3           # a slot protects against a threat within ~72° of the face's inward normal
const CROUCH_DROP: float = 0.75          # a crouched body's hit capsule is lowered this much (capsule top ~1.05 m)
const KO_DROP: float = 1.5               # a knocked-out gunman: capsule (and its stars) lowered onto the floor
const TARGET_STAND_Y: float = 1.3        # where enemy bullets aim on a standing / exposed player
const TARGET_CROUCH_Y: float = 0.7       # ... and on a player crouched behind cover, at most COVER_TARGET_BELOW under the
const COVER_TARGET_BELOW: float = 0.35   #   obstacle's top (a 0.9 m box: aim at 0.55 m)
const GUNMAN_COVER_MAX_H: float = 1.2    # gunmen only use cover their standing muzzle (MUZZLE_Y) clears
const EXPOSE_AFTER_FIRE_S: float = 0.5   # a shot fired from cover keeps the player exposed this long

# ----- gunmen -----
const GUNMAN_HP: float = 60.0
const SIGHT_M: float = 28.0
const FOV_DEG: float = 120.0
const EYE_Y: float = 1.6
const MUZZLE_Y: float = 1.38
const HEAR_SHOT_M: float = 30.0          # the player's gunfire (through walls)
const HEAR_SPRINT_M: float = 9.0
const HEAR_JOG_M: float = 4.0
const ALERT_SHARE_M: float = 14.0        # an alerted gunman wakes the others this close
const SENSE_DT: float = 0.1
const REACT_S: float = 0.6               # "Có biến!": turn and shout before moving
const WALK_SPEED: float = 1.4
const RUN_SPEED: float = 4.2
const TURN_RATE: float = 8.0
const COVER_WAIT: Vector2 = Vector2(0.7, 1.8)
const AIM_S: float = 0.3                 # stand up and aim before the telegraph
const TELEGRAPH_S: float = 0.4           # muzzle glint before every bullet resolves (the old value; gunmen read telegraph_s())
const SHOT_GAP_S: float = 0.22
const BURST: Vector2i = Vector2i(1, 3)
const PEEKS_BEFORE_FLANK: Vector2i = Vector2i(2, 3)
const FLANK_MIN_DEG: float = 50.0
const FLANK_MAX_M: float = 16.0
const COVER_SEARCH_M: float = 14.0
const COVER_MIN_PLAYER_M: float = 5.0
const OPEN_KEEP_M: float = 11.0          # without cover: walk to about this distance and shoot from there
const STAGGER_S: float = 0.45
const PEEK_ABORT_S: float = 1.2          # no clear ray this long while peeking: back down
const RECHECK_S: float = 0.5             # cover still protects? (in cover, at most every 0.5 s)
const SEPARATION_M: float = 1.0
const STUCK_S: float = 3.0               # no progress this long on the way: give up that spot
const RAY_DT: float = 0.1                # line / walk checks while waiting run at most 10 Hz
const NO_LINE_TRIES: int = 3             # this many waits in cover without a line from the standing muzzle: flank
const FLOOR_PROBE_UP: float = 0.6        # floor following (ramps, stairs): a down-ray from this high above the feet
const FLOOR_PROBE_DOWN: float = 1.2      #   ... to this far below them
const PRUNE_S: float = 1.0               # cover slots inside geometry are re-checked this often (moving blockers, crates)
const ACC_BASE: float = 0.72
const ACC_NEAR_M: float = 6.0
const ACC_FAR_M: float = 32.0
const ACC_FAR_K: float = 0.22
const ACC_MOVE_MIN: float = 0.35         # factor at sprint speed (ThirdPersonController.SPRINT_SPEED)
const ACC_COVER_K: float = 0.75          # the player pops out of cover to shoot
const ACC_FIRST_K: float = 0.5           # the first shot after the alert
const ACC_MIN: float = 0.04
const ACC_MAX: float = 0.9
const GUNMAN_DMG: float = 8.0
const MISS_OFFSET: Vector2 = Vector2(0.7, 1.5)
const SHOT_RANGE: float = 60.0
const KO_STARS_S: float = 6.0
const MAX_SHOOTERS: int = 3              # the old cap (GunFight reads max_shooters())
# ----- the gun row of the difficulty table (Wave 3 plan 2026-10-30-w3-shared.md T2): Thường, Dễ -----
const DIFF_TELEGRAPH_S: Vector2 = Vector2(0.35, 0.45)
const DIFF_SHOOTERS: Vector2i = Vector2i(4, 3)
const DIFF_REGEN_DELAY: Vector2 = Vector2(5.0, 3.0)
const DIFF_ACCURACY_K: Vector2 = Vector2(1.0, 0.8)
## Damage a gunman takes per hit kind (WeaponDirector / PlayerCombat info "kind").
const GUNMAN_DMG_TAKEN: Dictionary = {"bullet": 25.0, "pellet": 70.0, "punch": 15.0, "melee": 60.0, "bonk": 60.0,
	"blast": 999.0, "heavy": 30.0, "counter": 30.0}
const TRACER_S: float = 0.16
const TRACER_W: float = 0.05
const TRACER_COL := Color(1.0, 0.42, 0.22, 0.95)
const GLINT_COL := Color(1.0, 0.86, 0.32)

# ----- pallet-shield guard (Gunman opt "kind": "shield", Wave 3 T3; D3W-3, usable by Day 5 too) -----
const SHIELD_FRONT_DEG: float = 70.0     # a hit from within this of his front lands on the pallet (blocked)
const SHIELD_HITS: Vector2i = Vector2i(4, 3)   # hits on the pallet that knock it away (Thường, Dễ)
const SHIELD_SHOTGUN_M: float = 4.0      # a shotgun hit on the pallet from closer than this knocks it away at once
const SHIELD_KEEP_M: float = 5.0         # walks in to about this distance (no cover while he holds the pallet)
const SHIELD_WALK: float = 1.4           # m/s, the pallet is heavy
const SHIELD_TURN_RATE: float = 0.8      # rad/s, slow to turn: a sprint round him (or a dive) flanks him
const SHIELD_BURST: Vector2i = Vector2i(1, 2)
const SHIELD_MUZZLE_SIDE: float = 0.5    # he fires round the pallet's right edge
const T_NO_PIERCE: String = "Không xuyên!"

# ----- ammo -----
const PICKUP_R: float = 1.3
const DEFAULT_RESERVE: Dictionary = {WeaponData.Slot.PISTOL: 48, WeaponData.Slot.SHOTGUN: 12}
const PICKUP_AMOUNT: Dictionary = {WeaponData.Slot.PISTOL: 24, WeaponData.Slot.SHOTGUN: 6}
const FUNNY: Array[int] = [WeaponData.Slot.ROCKET, WeaponData.Slot.DEP, WeaponData.Slot.DURIAN, WeaponData.Slot.LOA]

# ----- forklift boss (Alexander ABCXYZ, Day 3) -----
const BOSS_HP: float = 500.0
const PHASE2_AT: float = 0.5
const IDLE_DIST: Vector2 = Vector2(8.0, 13.0)
const IDLE_SPEED: float = 3.0
const THINK: Vector2 = Vector2(1.0, 1.8)
const CHARGE_TELL_S: float = 1.0
const CHARGE_TELL_S2: float = 0.8
const CHARGE_SPEED: float = 11.0
const CHARGE_SPEED2: float = 13.0
const CHARGE_MAX_S: float = 2.4
const CHARGE_HIT_R: float = 1.3
const CHARGE_DMG: float = 25.0
const CRASH_RECOVER_S: float = 3.2
const MISS_RECOVER_S: float = 1.8
const LIFT_S: float = 0.9
const CRATE_FLIGHT_S: float = 1.2
const CRATE_PEAK: float = 5.0
const CRATE_R: float = 1.5
const CRATE_DMG: float = 30.0
const CRATE_SPREAD: float = 3.0          # phase 2 throws two crates, the second this far beside the first
const HEAT_CHARGE: float = 34.0
const HEAT_TOSS: float = 18.0
const OVERHEAT_S: float = 4.5
const OVERHEAT_DMG_K: float = 1.5
const NAME_AT: Array[float] = [0.66, 0.33]
const NAME_MAX: int = 2
const NAME_S: float = 3.2
const NAME_REFILL: float = 0.1           # of max HP, refilled over each name intro
const BOSS_DMG_TAKEN: Dictionary = {"bullet": 25.0, "pellet": 55.0, "melee": 30.0, "punch": 10.0, "heavy": 18.0,
	"counter": 15.0, "blast": 80.0, "bonk": 20.0}
const IMMUNE_TOAST_S: float = 1.2

# ----- texts -----
const T_HP: String = "Máu"
const T_LEFT: String = "Địch còn %d"
const T_WAVE: String = "Đợt %d/%d"
const T_WAVE_POP: String = "Đợt %d"
const T_COVER_PROMPT: String = "[Ctrl] nấp"
const T_IN_COVER: String = "[Chuột phải] nhô ra bắn · thả [Ctrl] để rời chỗ nấp"
const T_LOCKED: String = "Khoá"
const T_NO_AMMO: String = "Hết đạn, tìm hộp đạn"
const T_AMMO: String = "+%d viên %s"
const T_ALERT: String = "Có biến!"
const T_IMMUNE: String = "Không xi nhê!"
const T_VULN: String = "SƠ HỞ!"
const T_OVERHEAT: String = "QUÁ NHIỆT!"
const T_CHARGE: String = "Xe nâng lao tới!"
const T_FIGHT_PHONE: String = "Đang đấu súng, chưa xem điện thoại được"
const T_FIGHT_EMOTE: String = "Đang đấu súng, không phải lúc diễn"
const ALEX_SHORT: String = "Alexander ABCXYZ"
## The endless name (fictional titles only), restated by every name intro.
const ALEX_FULL: String = "Alexander ABCXYZ Đệ Nhất Đại Lý Kính Thông Minh, Chúa Tể Tai Nghe Hạt Đậu, Người Gác Cổng Bến Container, Hội Viên Bạch Kim Câu Lạc Bộ Xe Nâng, Nhà Nhập Khẩu Độc Quyền Ốc Vít Phát Sáng, Đại Sứ Thiện Chí Của Thùng Các-tông"
## The name intro's subtitles, shown at these seconds into it (NAME_LINE_AT).
const ALEX_INTRO: Array[String] = ["Khoan! Để tôi giới thiệu lại...", "Tôi là " + ALEX_FULL + "...", "...và còn nữa, nhưng thôi để lần sau!"]
const NAME_LINE_AT: Array[float] = [0.0, 0.7, 2.6]

# ----- looks (official looks come from StoryCast later) -----
## Guards in black. Merge "body" opts over it, or pass a body_fn; "mask" picks the head (sheep / wolf / fox / "").
const GUARD_LOOK: Dictionary = {"preset": "student_m", "female": false, "body": "casual", "backpack": false, "glasses": false,
	"shirt_color": Color("#17171C"), "trousers_color": Color("#101014"), "hair_style": "short"}
const MASKS: Array[String] = ["sheep", "wolf", "fox"]
## Alexander: Hawaiian-pink shirt, cream trousers, glasses, slicked side part.
const ALEX_LOOK: Dictionary = {"preset": "casual", "female": false, "body": "casual", "backpack": false, "glasses": true,
	"seed": 3030, "skin": 1, "hair_color": 0, "hair_style": "side_part", "shirt_color": Color("#E8457A"),
	"trousers_color": Color("#EADFC4"), "height": 1.0}

# ----- code poses (character frame Euler, CineMoves conventions) -----
static var _pose_cache: Dictionary = {}


## Code pose {joint: Euler} at progress u (static ones cached: no allocation per frame).
static func pose(pose_name: String, u: float) -> Dictionary:
	match pose_name:
		"stunned":
			return CineMoves.code_pose("stunned", u)
		"cover_crouch", "aim", "drive", "name_speech", "crouch_aim":
			if not _pose_cache.has(pose_name):
				_pose_cache[pose_name] = _static_pose(pose_name)
			return _pose_cache[pose_name]
	return {}


static func _static_pose(pose_name: String) -> Dictionary:
	match pose_name:
		"cover_crouch":          # deep crouch behind low cover, pistol held up at the chest
			return {"thigh_l": Vector3(1.55, 0.0, 0.12), "knee_l": Vector3(-2.15, 0.0, 0.0), "thigh_r": Vector3(1.25, 0.0, -0.1),
				"knee_r": Vector3(-2.3, 0.0, 0.0), "hips_y": -0.5, "torso": Vector3(0.45, 0.0, 0.0), "head": Vector3(-0.25, 0.0, 0.0),
				"shoulder_r": Vector3(0.9, 0.0, 0.25), "elbow_r": Vector3(1.6, 0.0, 0.0),
				"shoulder_l": Vector3(0.8, 0.0, -0.25), "elbow_l": Vector3(1.6, 0.0, 0.0)}
		"aim":                   # pistol aimed straight ahead, left hand supporting (upper body only: the legs keep walking)
			return {"shoulder_r": Vector3(1.5, 0.0, 0.08), "elbow_r": Vector3(0.12, 0.0, 0.0),
				"shoulder_l": Vector3(1.3, 0.0, -0.5), "elbow_l": Vector3(0.55, 0.0, 0.0),
				"torso": Vector3(0.05, 0.0, 0.0), "head": Vector3(0.05, 0.0, 0.0)}
		"crouch_aim":            # the crouch with the arms aimed (a crouched telegraph is never used: kept for poses)
			var c: Dictionary = _static_pose("cover_crouch").duplicate()
			var a: Dictionary = _static_pose("aim")
			for k: String in a.keys():
				c[k] = a[k]
			c["torso"] = Vector3(0.2, 0.0, 0.0)
			return c
		"drive":                 # seated, both hands on the steering wheel (legs from the "sit" clip)
			return {"shoulder_l": Vector3(0.95, 0.0, -0.12), "elbow_l": Vector3(0.7, 0.0, 0.0),
				"shoulder_r": Vector3(0.95, 0.0, 0.12), "elbow_r": Vector3(0.7, 0.0, 0.0), "torso": Vector3(0.1, 0.0, 0.0)}
		"name_speech":           # standing up on the seat, arms wide: presenting himself
			return {"shoulder_l": Vector3(0.45, 0.0, 1.15), "elbow_l": Vector3(0.3, 0.0, 0.0),
				"shoulder_r": Vector3(0.45, 0.0, -1.15), "elbow_r": Vector3(0.3, 0.0, 0.0),
				"torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(-0.2, 0.0, 0.0)}
	return {}


## Gun difficulty (Difficulty.pick): the muzzle glint before each enemy bullet resolves (s).
static func telegraph_s() -> float:
	return float(Difficulty.pick(DIFF_TELEGRAPH_S.x, DIFF_TELEGRAPH_S.y))


## Gun difficulty: gunmen shooting at once (GunFight's token cap unless the setup passes "max_shooters").
static func max_shooters() -> int:
	return int(Difficulty.pick(DIFF_SHOOTERS.x, DIFF_SHOOTERS.y))


## Gun difficulty: seconds without damage before the player's HP regenerates during a gunfight.
static func regen_delay() -> float:
	return float(Difficulty.pick(DIFF_REGEN_DELAY.x, DIFF_REGEN_DELAY.y))


## Gun difficulty: hits on a shield guard's pallet that knock it away (Thường 4, Dễ 3).
static func shield_hits() -> int:
	return int(Difficulty.pick(SHIELD_HITS.x, SHIELD_HITS.y))


## Gun difficulty: a factor on every gunman's hit chance.
static func accuracy_k() -> float:
	return float(Difficulty.pick(DIFF_ACCURACY_K.x, DIFF_ACCURACY_K.y))


## Enemy hit chance (0..1) of one bullet at distance d (m) against a player moving at `speed` m/s; popped = the player is
## shooting from cover; first = the first shot after the alert; k = the gunman's accuracy scale.
static func hit_chance(d: float, speed: float, popped: bool, first: bool, k: float = 1.0) -> float:
	var dist_k: float = lerpf(1.0, ACC_FAR_K, clampf((d - ACC_NEAR_M) / (ACC_FAR_M - ACC_NEAR_M), 0.0, 1.0))
	var move_k: float = lerpf(1.0, ACC_MOVE_MIN, clampf(speed / ThirdPersonController.SPRINT_SPEED, 0.0, 1.0))
	var p: float = ACC_BASE * dist_k * move_k * (ACC_COVER_K if popped else 1.0) * (ACC_FIRST_K if first else 1.0) * k
	return clampf(p, ACC_MIN, ACC_MAX)


## A bright readable enemy tracer a -> b (thicker and redder than the player's, fades within TRACER_S) on the FX layer.
static func tracer(fx: WeaponFX, a: Vector3, b: Vector3) -> void:
	if fx == null:
		return
	var dist: float = a.distance_to(b)
	if dist < 0.2:
		return
	var mi := MeshInstance3D.new()
	mi.name = "EnemyTracer"
	var bm := BoxMesh.new()
	bm.size = Vector3(TRACER_W, TRACER_W, dist)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = TRACER_COL
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fwd: Vector3 = (b - a) / dist
	var up: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(fwd, up), (a + b) * 0.5)
	fx.add_transient(mi, TRACER_S, "enemy_tracer", m, TRACER_S)
