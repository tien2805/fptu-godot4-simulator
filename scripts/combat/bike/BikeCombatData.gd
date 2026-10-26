# File: res://scripts/combat/bike/BikeCombatData.gd
# Numbers, texts and poses of the Phase C bike combat (spec C-D1): the player's kicks from the bike, the bike's stability,
# the Bầy Sói biker AI and its comic crash. Plain Vietnamese texts (no emoji or decorative symbols; key glyphs only in the
# control hints). Static only; the kick poses are built once (no allocation per frame).
class_name BikeCombatData
extends RefCounted

# ----- player kicks (seconds from the key press) -----
const KICK_WINDUP: float = 0.10          # the hit window opens
const KICK_ACTIVE_END: float = 0.30      # ... and closes (no hit after this: a miss)
const KICK_DUR: float = 0.45             # leg back on the footboard
const KICK_COOLDOWN: float = 0.55        # next kick allowed (from the press)
const KICK_REACH: float = 2.4            # lateral reach from the bike's centre line (m)
const KICK_MIN: float = 0.3              # closer than this is not "to the side"
const KICK_ALONG: float = 1.7            # +/- along the bike (m)
const KICK_PUSH: float = 4.5             # lateral speed given to the kicked biker (m/s)

# ----- stability (the player's bike HP) -----
const STABILITY_MAX: float = 100.0
const ENEMY_KICK_DMG: float = 20.0
const CRASH_DMG: float = 25.0            # PlayerBike.crash_occurred: traffic, curb, pothole, fall
const RAM_DMG: float = 6.0               # riding into the front biker's back wheel
const HURT_IFRAMES: float = 0.6
const REGEN_DELAY: float = 5.0
const REGEN_RATE: float = 4.0            # per second
const SHOVE_M: float = 0.7               # sideways shove of the player's bike by an enemy kick (m, over SHOVE_S)
const SHOVE_S: float = 0.18
const RAM_COOLDOWN: float = 1.2

# ----- biker AI -----
const MAX_SPEED: float = 31.0            # m/s (player: 22.5, 27 in a slipstream)
const CATCH_SPEED: float = 8.0           # max speed relative to the player while closing in
const ACCEL: float = 16.0                # m/s² (lateral swerves included)
const POS_GAIN: float = 1.8              # target pull (1/s)
const SWERVE_GAIN: float = 4.0           # ... while swerving in to kick (a quick, readable lunge)
const AVOID_GAIN: float = 3.5            # ... while passing a car
const SLOT_LAT: float = 2.35             # flank slot: lateral distance from the player
const SLOT_ALONG: float = -0.6           # flank slot: slightly behind the player's centre
const SWERVE_LAT: float = 1.0            # lateral distance at the kick
const WINDUP_IN: float = 0.6             # share of the wind-up spent swerving in (to SWERVE_LAT + 0.25)
const FRONT_ALONG: float = 7.0           # box-in blocker ahead of the player
const BRAKE_ALONG: float = 2.4           # ... closing to this during a brake check
const BACK_ALONG: float = 8.0            # reserves behind ...
const BACK_LAT: float = 0.65             # ... staggered just off the player's line (clear of the traffic lanes)
const ROAD_HALF: float = 3.6             # default half width the AI keeps to on the route
const SLOT_SQUEEZE: float = 0.8          # a flank slot clamped by more than this has no room: BACK instead
const PACE_MIN: float = 1.2
const PACE_MAX: float = 2.8
const WINDUP_S: float = 0.5              # telegraph before the kick
const ENEMY_KICK_S: float = 0.4
const ENEMY_HIT_AT: float = 0.15         # into the kick
const ENEMY_REACH: float = 1.75          # lateral
const ENEMY_ALONG: float = 1.5
const RECOVER_S: float = 0.8
const ATTACK_GAP_S: float = 0.8          # between two attack starts
const BRAKE_S: float = 1.1
const WOBBLE_S: float = 0.55
const MAX_ATTACKERS: int = 2
const ROLE_EVERY: float = 0.25
const RAY_EVERY: int = 6                 # physics frames between floor rays (10 Hz at 60 fps)
const AVOID_EVERY: int = 3
const AVOID_LOOK: float = 6.0            # + closing speed x AVOID_T metres
const AVOID_T: float = 1.3
const AVOID_HOLD: float = 0.6
const SEPARATION: float = 1.4            # bikers keep this far apart
const GRAZE_SPEED: float = 6.0           # touching a car slower than this (into it) is a scrape, not a crash (unless wobbling)
const PLAYER_GAP_LAT: float = 0.85       # ... and this far to the player's side (unless kicking)
const BOX_LAT: float = 3.6
const BOX_COOLDOWN: float = 6.0
const LEAVE_S: float = 4.0
const TAUNT_EVERY: Vector2 = Vector2(4.0, 9.0)
const TAUNT_S: float = 1.6

# ----- crash (comic, no gore) -----
const TUMBLE_UP: float = 4.6
const GRAVITY: float = 18.0
const TUMBLE_SPIN: float = 9.0           # rad/s forward flip
const BOUNCE: float = 0.35
const RIDER_DECEL: float = 9.0
const BIKE_DECEL: float = 7.0
const BIKE_ROLL: float = 1.4             # on its side (rad)
const SPARK_EVERY: float = 0.1
const STARS_S: float = 8.0
const DOWN_FREEZE_S: float = 2.5         # the downed rider's animation stops after this (pose frozen)
const WAVE_GAP_S: float = 2.5
const REPLAY_AFTER: float = 0.8
const REPLAY_LEN: float = 5.0

# ----- look (Bầy Sói) -----
const BIKE_PAINT := Color("#2B2F36")
const HELMET_COL := Color("#7B8088")
const HELMET_DARK := Color("#4B5058")
const EYE_COL := Color("#FF2A2A")
const JACKETS: Array[Color] = [Color("#2E2E33"), Color("#3B3F46"), Color("#4A4036"), Color("#2F3A40")]

# ----- texts -----
const T_STABILITY: String = "Độ vững xe"
const T_LEFT: String = "Bầy Sói còn: %d"
const T_WAVE: String = "Đợt %d/%d"
const T_KICK_L: String = "[Q] Đạp trái"
const T_KICK_R: String = "[E] Đạp phải"
## FreeRoam's bottom hint while a chase runs (replaces "[F] xuống xe ...").
const T_RIDING: String = "[Q]/[E] đạp trái/phải · [W]/[S] ga/phanh · [A]/[D] lái · [SPACE] drift · [H] còi"
const T_NO_DISMOUNT: String = "Đang bị Bầy Sói rượt, không xuống xe được!"
const T_WARN_L: String = "BÊN TRÁI"
const T_WARN_R: String = "BÊN PHẢI"
const T_DOWN: String = "ĐẠP BAY!"
const T_TRAFFIC_DOWN: String = "HÚC XE RỒI!"
const T_BOXED: String = "BỊ VÂY!"
const T_KNOCKED_OFF: String = "Bị đạp văng khỏi xe!"
const T_RAM: String = "Húc đuôi!"
## Day 2 memes (spec C-D6): the chase start and the win.
const T_START_D2: String = "Tới công chuyện luôn!"
const T_WIN_D2: String = "Đỉnh nóc kịch trần bay phấp phới"
const TAUNTS: Array[String] = ["Đứng lại đó!", "Bầy Sói tới đây!", "Né đi cưng!", "Hàng nóng, tránh ra!", "Chạy đâu cho thoát!"]
const NAMES: Array[String] = ["Sói Đen", "Sói Lửa", "Sói Bạc", "Sói Còi", "Sói Mập", "Sói Phó"]

# ----- sounds (CineAudio / StoryAudio / WeaponAudio cues) -----
const CINE_CUES: Array[String] = ["impact_medium", "impact_heavy", "helmet_clonk", "slide_whistle", "body_fall", "groan", "engine_roar"]
const STORY_CUES: Array[String] = ["bin_crash"]
const WEAPON_CUES: Array[String] = ["swish"]

# ----- kick poses (CharacterBuilder joints, character frame; built once) -----
static var _kick_l: Dictionary = {}
static var _kick_r: Dictionary = {}


## Full side kick from the saddle (side -1 left, +1 right): the leg shoots out sideways, the torso leans away. The caller
## blends it with a weight envelope (so the dictionary never changes after the first call).
static func kick_pose(side: float) -> Dictionary:
	if _kick_r.is_empty():
		_kick_r = {"thigh_r": Vector3(0.55, 0.0, -1.35), "knee_r": Vector3(-0.15, 0.0, 0.0), "foot_r": Vector3(0.2, 0.0, 0.0),
			"torso": Vector3(-0.3, 0.0, 0.32), "head": Vector3(0.2, -0.35, 0.0)}
		for j: String in _kick_r.keys():
			var v: Vector3 = _kick_r[j]
			var k: String = j.replace("_r", "_X").replace("_l", "_r").replace("_X", "_l")
			_kick_l[k] = Vector3(v.x, -v.y, -v.z)
	return _kick_l if side < 0.0 else _kick_r


## Weight of the kick pose at kick time t (0 .. dur): snaps out by the hit window, holds, eases back.
static func kick_weight(t: float, windup: float, active_end: float, dur: float) -> float:
	if t < 0.0 or t >= dur:
		return 0.0
	if t < windup:
		return t / maxf(windup, 1e-3)
	if t < active_end:
		return 1.0
	return 1.0 - (t - active_end) / maxf(dur - active_end, 1e-3)


## Every UI text above (tests: plain, no emoji or decorative symbols).
static func texts() -> Array[String]:
	var out: Array[String] = [T_STABILITY, T_LEFT % 3, T_WAVE % [1, 2], T_KICK_L, T_KICK_R, T_RIDING, T_NO_DISMOUNT, T_WARN_L,
		T_WARN_R, T_DOWN, T_TRAFFIC_DOWN, T_BOXED, T_KNOCKED_OFF, T_RAM, T_START_D2, T_WIN_D2]
	out.append_array(TAUNTS)
	out.append_array(NAMES)
	return out
