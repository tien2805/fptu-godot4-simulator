# File: res://scripts/combat/bike/BikeCombatData.gd
# Numbers, texts and poses of the Phase C bike combat (spec C-D1): the player's kicks from the bike, the bike's stability,
# the Bầy Sói biker AI and its comic crash. Plain Vietnamese texts (no emoji or decorative symbols; key glyphs only in the
# control hints). Static only; the kick poses are built once (no allocation per frame).
# Day 2 "Tokyo Drift" (spec 2026-10-27, D2X-2 to D2X-7): the chase speed profile, the enemy kinds (KINDS: rider, stick,
# thrower, heavy, pickup, police), takedowns, the film opening (OPEN_DROP_S, tunable), the set pieces (DAY2_SET_PIECES,
# tunable: kind + route distance) and the Sói Xám cameo.
class_name BikeCombatData
extends RefCounted

# ----- player kicks (seconds from the key press) -----
const KICK_WINDUP: float = 0.10          # the hit window opens
const KICK_ACTIVE_END: float = 0.30      # ... and closes (no hit after this: a miss)
const KICK_DUR: float = 0.45             # leg back on the footboard
const KICK_COOLDOWN: float = 0.55        # next kick allowed (from the press)
const KICK_REACH: float = 2.8            # lateral reach from the bike's centre line (m): a flanker in its slot is always in it
const KICK_MIN: float = 0.3              # closer than this is not "to the side"
const KICK_ALONG: float = 1.7            # +/- along the bike (m)
const KICK_PUSH: float = 4.5             # lateral speed given to the kicked biker (m/s)
## Kick assist (plan 2026-10-30-d2-playtest-fixes.md): Q / E take the nearest kickable target on that side within ASSIST_LAT
## to the side and +/-ASSIST_ALONG along the bike (KICK_REACH / KICK_ALONG are the plain leg's reach); the target picked at
## the press is pulled in toward the leg through the hit window (BikerEnemy / DriftRival.magnet) so the kick connects.
const ASSIST_LAT: float = 3.5
const ASSIST_ALONG: float = 3.5
const ASSIST_PULL_S: float = 0.32        # the pull lasts the wind-up and the hit window

# ----- stability (the player's bike HP) -----
const STABILITY_MAX: float = 100.0
const ENEMY_KICK_DMG: float = 26.0       # = KINDS.rider.dmg
const CRASH_DMG: float = 25.0            # PlayerBike.crash_occurred: traffic, curb, pothole, fall (PlayerBikeCombat's own)
const CRASH_DMG_MIN: float = 15.0        # D2X-4: BikeChase scales a crash by the speed before it: 15 at 6 m/s ...
const CRASH_DMG_MAX: float = 25.0        # ... 25 at the chase top speed
const WAVE_REFILL: float = 5.0           # D2X-4: a cleared wave gives back this much stability (Thường, playtest fixes; Dễ 40)
const RAM_DMG: float = 6.0               # riding into the front biker's back wheel
const HURT_IFRAMES: float = 0.6
const REGEN_DELAY: float = 5.0
const REGEN_RATE: float = 0.0            # per second (D2X-4: no regeneration; a cleared wave refills WAVE_REFILL)
const SHOVE_M: float = 0.7               # sideways shove of the player's bike by an enemy kick (m, over SHOVE_S)
const SHOVE_S: float = 0.18
const RAM_COOLDOWN: float = 1.2

# ----- biker AI -----
const MAX_SPEED: float = 32.0            # m/s (D2X-2: the chase profile tops at 27.8, 30.6 in a slipstream; heavies slower)
const CATCH_SPEED: float = 8.0           # max speed relative to the player while closing in
const ACCEL: float = 16.0                # m/s² (lateral swerves included)
const POS_GAIN: float = 1.8              # target pull (1/s)
const SWERVE_GAIN: float = 4.0           # ... while swerving in to kick (a quick, readable lunge)
const AVOID_GAIN: float = 3.5            # ... while passing a car
const SLOT_LAT: float = 2.2              # flank slot: lateral distance from the player (route frame; inside KICK_REACH and the assist)
const SLOT_ALONG: float = -0.6           # flank slot: slightly behind the player's centre
const SWERVE_LAT: float = 1.0            # lateral distance at the kick
const WINDUP_IN: float = 0.6             # share of the wind-up spent swerving in (to SWERVE_LAT + 0.25)
const KICK_LOCK_S: float = 0.2           # the kick line is fixed in world space this long before the kick starts (steer away = dodge)
const FRONT_ALONG: float = 7.0           # box-in blocker ahead of the player
const BRAKE_ALONG: float = 2.4           # ... closing to this during a brake check
const BACK_ALONG: float = 4.0            # reserves: a second row this far ahead (playtest fixes: on screen, was 8 m behind) ...
const BACK_LAT: float = 3.0              # ... out to the side, left and right in turn
const ROAD_HALF: float = 3.6             # default half width the AI keeps to on the route
const SLOT_SQUEEZE: float = 0.8          # a flank slot clamped by more than this has no room: BACK instead
const PACE_MIN: float = 0.9            # tuned 2026-10-27 (Day 2 bots): flankers pace, then attack (non-flank roles)
const PACE_MAX: float = 2.2
## Playtest fixes (plan 2026-10-30-d2-playtest-fixes.md): the owner could not find the bikers to kick ("lũ xe cứ chạy loạn
## lên"). A flanker settles in its slot (inside kick reach) and holds it HOLD_MIN..HOLD_MAX s (counted only while within
## SETTLE_M of the slot; Dễ + HOLD_EASY) before it winds up; every active biker stays within LEASH_AHEAD ahead and
## LEASH_BEHIND behind the player (the speed limited from LEASH_SOFT inside the band, a hard clamp at it); at most
## MAX_ALIVE riders at once (Dễ MAX_ALIVE_EASY), the rest of a wave waits; a slot unfit (traffic, the road edge) keeps its
## holder ROLE_UNFIT_S before it gives the role up.
const HOLD_MIN: float = 1.5
const HOLD_MAX: float = 2.5
const HOLD_EASY: float = 0.5
const SETTLE_M: float = 1.2
const LEASH_AHEAD: float = 20.0
const LEASH_BEHIND: float = 12.0
const LEASH_SOFT: float = 4.0
const LEASH_GAIN: float = 1.5            # 1/s: the closing speed per metre past the soft band
const LEASH_CATCH: float = 6.0           # a biker behind the band may ride this much faster than the player
const MAX_ALIVE: int = 4
const MAX_ALIVE_EASY: int = 3
const ROLE_UNFIT_S: float = 0.6
const SEP_SOFT: float = 0.25             # separation: share of the overlap corrected per frame (no jitter)
const COMBAT_CAM_M: float = 25.0         # the bike camera's combat framing while a biker rides this near ...
const COMBAT_CAM_HOLD_S: float = 1.2     # ... and this long after
const ARRIVE_ROAR_M: float = 7.0         # a biker closing in from behind revs as it comes within this
const APPROACH_K: float = 1.4            # ... closing at up to CATCH_SPEED x this
const ARRIVE_REL: float = 6.0            # a biker from behind arrives this much faster than the player (m/s)
const WINDUP_S: float = 0.5              # telegraph before the kick
const ENEMY_KICK_S: float = 0.4
const ENEMY_HIT_AT: float = 0.15         # into the kick
const ENEMY_REACH: float = 1.75          # lateral
const ENEMY_ALONG: float = 1.5
const RECOVER_S: float = 0.8
const ATTACK_GAP_S: float = 0.6          # between two attack starts
const BRAKE_S: float = 1.1
const WOBBLE_S: float = 0.55
const MAX_ATTACKERS: int = 3            # D2X-4: 3 at once (wave 3: 4, per wave opts)
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
const LEAVE_S: float = 1.5               # riding off: hidden after this once out of view (or LEAVE_MAX_S anyway)
const LEAVE_MAX_S: float = 25.0
const LEAVE_SPEED: float = 14.0          # m/s relative to the player while riding off
const END_MARGIN: float = 25.0           # without end_at_s the chase ends this far before the route end
const VIEW_M: float = 160.0              # "in view": in the camera frustum and nearer than this
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

# ----- Day 2 "Tokyo Drift" (spec 2026-10-27) -----
## D2X-2: the player's bike while the Day 2 chase runs (100 km/h, 110 in a slipstream); BikeChase opt "profile".
const CHASE_PROFILE: Dictionary = {"max_speed_ms": 27.8, "slipstream_max_ms": 30.6, "engine_accel": 14.5, "air_drag": 0.0125}
## D2X-4 enemy kinds. hp: kicks to crash; dmg: stability per hit; windup: telegraph (s); reach / along: the hit box beside
## the player (m; tuned 2026-10-27 so a flanker paces just out of kick reach: the kick is a counter in its wind-up, or
## a steer toward it); lock: the attack line (and with lock_speed the speed too: braking dodges) is fixed this long before the
## attack starts; swerve: lateral distance of the attack line (negative = past the player's line); slot_lat: pacing
## distance to the side (playtest fixes 2026-10-30: the flank slots are inside the kick reach and the assist zone, held for
## HOLD_MIN..HOLD_MAX s before the wind-up); top: top speed (m/s); wobble / push: a kick's wobble time and shove; atk: attack
## duration (s).
const KINDS: Dictionary = {
	"rider": {"hp": 1, "dmg": 26.0, "windup": 0.5, "reach": 1.75, "along": 1.5, "lock": 0.2, "lock_speed": false, "swerve": 1.0,
		"slot_lat": 2.2, "top": 32.0, "kickable": true, "wobble": 0.55, "push": 4.5, "atk": 0.4},
	"stick": {"hp": 1, "dmg": 28.0, "windup": 0.5, "reach": 2.5, "along": 1.15, "lock": 0.35, "lock_speed": true, "swerve": 1.6,
		"slot_lat": 2.4, "top": 32.0, "kickable": true, "wobble": 0.55, "push": 4.5, "atk": 0.4},
	"thrower": {"hp": 1, "dmg": 15.0, "windup": 0.6, "reach": 1.6, "along": 1.6, "lock": 0.0, "lock_speed": false, "swerve": 2.0,
		"slot_lat": 3.2, "top": 33.0, "kickable": true, "wobble": 0.55, "push": 4.5, "atk": 0.4},
	"heavy": {"hp": 3, "dmg": 30.0, "windup": 0.6, "reach": 1.8, "along": 1.8, "lock": 0.25, "lock_speed": false, "swerve": 1.05,
		"slot_lat": 2.3, "top": 29.5, "kickable": true, "wobble": 0.35, "push": 2.0, "atk": 0.45},
	"pickup": {"hp": 1, "dmg": 40.0, "windup": 1.0, "reach": 1.55, "along": 2.9, "lock": 0.5, "lock_speed": true, "swerve": -0.3,
		"slot_lat": 3.3, "top": 31.0, "kickable": false, "wobble": 0.0, "push": 0.0, "atk": 0.75},
	"police": {"hp": 1, "dmg": 12.0, "windup": 0.5, "reach": 1.75, "along": 1.6, "lock": 0.2, "lock_speed": false, "swerve": 1.0,
		"slot_lat": 2.0, "top": 33.0, "kickable": false, "wobble": 0.0, "push": 0.0, "atk": 0.4},
}
const KIND_NAMES: Dictionary = {"rider": "", "stick": "Sói Gậy", "thrower": "Sói Ném", "heavy": "Sói Bự", "pickup": "Bán Tải Sói",
	"police": "Cảnh sát"}
const THROW_AHEAD: float = 7.5           # thrower: paces this far ahead ...
const THROW_BACK_S: float = 2.2          # ... and after each throw drops back alongside for this long (the kick window)
const THROW_FLIGHT: float = 0.8          # helmet flight = the red road marker's warning (s)
const THROW_R: float = 1.6               # the marker's radius: inside it when the helmet lands = hit
const THROW_ARC: float = 3.5             # helmet arc height (m)
const PICKUP_STRIKES: int = 3            # dodged rams before the pickup loses it and hits a pole (takedown; playtest fixes: 2) ...
const PICKUP_MAX_RAMS: int = 3           # ... and it loses it after its 3rd ram anyway
const PICKUP_HALF := Vector2(0.95, 2.6)  # pickup half width / half length (m)
const PICKUP_RECOVER_S: float = 1.4
const PICKUP_BACK: float = -4.5          # no room beside the player: the pickup waits this far back in its lane (playtest fixes: -8)
const POLICE_RAM_EVERY := Vector2(2.4, 3.8)
const POLICE_PLAYER_CHANCE: float = 0.2
const POLICE_PLAYER_GAP_S: float = 6.0     # the police go for the player at most once in this long (both cops)
const POLICE_APPROACH_S: float = 2.5
const POLICE_BEHIND: float = 7.0
## D2X-5 takedowns: crash causes that count (a plain kick crash does not); 0.5 s at 0.3x and a side camera cut, at most
## one every TD_GAP_S and none while 2+ attackers wind up within TD_BUSY_M of the player.
const TAKEDOWN_CAUSES: Array[String] = ["traffic", "pole", "melon", "barrier", "police", "nitro", "spin", "air", "cones", "counter", "gap",
	"roadblock"]
const TD_SCALE: float = 0.3
const TD_REAL_S: float = 0.5
const TD_GAP_S: float = 3.0
const TD_BUSY_M: float = 6.0
const TD_CHARGE: float = 15.0            # nitro charge per takedown (D2X-8)
const SPIN_PAIR_S: float = 0.3           # two spin-kick hits within this = both riders tagged "spin"
## D2X-3 film opening: slow motion until OPEN_DROP_S (the beat drop of the owner's Tokyo Drift file, 4.15 s: measured
## 2026-10-27, owner-tunable), then wave 1 bursts out of the side roads.
const OPEN_DROP_S: float = 4.15
const OPEN_SCALE: float = 0.35
const START_SPEED_D2: float = 14.0       # rolling start of the Day 2 chase (m/s)
const OPEN_CAM_BACK: float = 3.1         # the opening's low camera behind the bike ...
const OPEN_CAM_UP: float = 0.55          # ... and its height
const SIDE_SPAWN_LAT: float = 3.4        # "side" spawns: this far past the AI half width, out of view beside the player
const FLARE_S: float = 1.2               # LED eyes flaring after a burst
## D2X-6 set pieces.
const MELON_N: int = 100                 # Wave 2: the tipped truck spills 100 (one MultiMesh, analytic)
const MELON_S: float = 5.0               # melons roll this long
const MELON_DMG: float = 12.0
const MELON_R: float = 0.85              # player / biker within this of a melon = hit
const MELON_TRUCK_LEAD: float = 90.0     # the truck shows this far before the drop point
const TRUCK_SPEED: float = 15.0
const BARRIER_WARN_M: float = 80.0
const BARRIER_GAP_W: float = 1.6         # the slow gap by the right curb (m)
const BARRIER_Y: float = 1.15            # the arm's height (chest high on the bike)
const CONE_DMG: float = 8.0
const CONE_CD: float = 0.8
const RAMP_MIN_SPEED: float = 20.0
const RAMP_HALF_W: float = 1.25
const JUMP_REAL_S: float = 1.2           # the scripted jump (real seconds) ...
const JUMP_SCALE: float = 0.4            # ... in slow motion
const JUMP_H: float = 1.7
const POLICE_N: int = 2
const ROADBLOCK_GAP_W: float = 2.4       # the roadblock's gap (Thường; Dễ 3.4 m)
const ROADBLOCK_DMG: float = 35.0        # crashing into it (Thường; Dễ 22)
const POLICE_S: float = 25.0
const DRIFT_FAST: float = 19.0           # through a drift zone faster than this without drifting = into the curb
const CURB_DMG: float = 10.0
const CURB_SLOW: float = 0.6
const DRIFT_ZONE_BONUS: float = 12.5     # extra charge per second drifting in a zone (PlayerBike's own 25/s x 1.5)
## The Day 2 layout on MissionBikeChase.day2_route (route distance s in m; drift zones from s over len, on the real turns).
## Wave 2 (plan 2026-10-29-w2-day2.md): the truck tips over (melons), the broken road gap (ramp), the police roadblock
## (it replaces the police joining), the crane beam (barrier) last on Cầu Vồng 5.
const DAY2_SET_PIECES: Array = [
	{"kind": "drift", "s": 488.0, "len": 44.0},
	{"kind": "melons", "s": 690.0},
	{"kind": "drift", "s": 748.0, "len": 28.0},
	{"kind": "ramp", "s": 860.0},
	{"kind": "drift", "s": 910.0, "len": 58.0},
	{"kind": "wrong_way", "s": 1000.0, "len": 250.0},
	{"kind": "drift", "s": 1266.0, "len": 30.0},
	{"kind": "roadblock", "s": 1820.0, "gap_d": -1.5},
	{"kind": "barrier", "s": 2080.0},
]
## D2X-7: Sói Xám rides past after wave 2 once the player is past CAMEO_S (at CAMEO_FORCE_S anyway).
const CAMEO_S: float = 1470.0
const CAMEO_FORCE_S: float = 1640.0
const CAMEO_REL: float = 9.0             # he closes in at this much over the player ...
const CAMEO_AWAY: float = 22.0           # ... and leaves on nitro at this much
const CAMEO_TAUNT_S: float = 2.3
const CAMEO_PAINT := Color("#8E9AA6")
const NITRO_FLAME := Color(0.25, 0.55, 1.0)

# ----- Q2 bike feel (plan 2026-10-29-q2-feel.md T3) -----
const COUNTER_WINDOW: float = 0.25       # a kick toward an attacker this long (or less) before his hit = PHẢN ĐÒN
const COUNTER_LAT: float = 3.2           # ... within this far to that side ...
const COUNTER_ALONG: float = 2.2         # ... and this far along the bike
const COUNTER_PUSH: float = 7.0          # the countered rider is sent flying (m/s)
const KICKBACK_ROLL: float = 0.14        # a connecting kick rocks the player's bike this much (rad) away from the kick ...
const KICKBACK_S: float = 0.2            # ... over this long (visual only: the line is kept), and costs 1.5 % speed
const STICK_SWINGS: int = 3              # a grabbed stick: Q / E swings, then it breaks
const STICK_REACH_BONUS: float = 1.0     # the swing reaches this much further than a kick ...
const STICK_ALONG_BONUS: float = 0.5     # ... and this much more along the bike
const STICK_POWER: int = 2               # kicks' worth of damage per stick hit (a heavy goes down in 2)
const STICK_FLIGHT_S: float = 0.4        # a kicked stick flies this long toward the rider's hands ...
const STICK_ARC_H: float = 1.6           # ... in an arc this high ...
const STICK_CATCH_LAT: float = 3.0       # ... and is caught when the bike is within this to its side ...
const STICK_CATCH_ALONG: float = 3.5     # ... and this along it when it comes down
const STICK_PICK_R: float = 1.5          # a missed stick lies on the road: riding over it within this picks it up
const STICK_LIFE: float = 15.0           # a dropped stick lies on the road this long
const HURT_WOBBLE_S: float = 0.5         # a hit on the player wobbles the bike this long
const WOBBLE_VEER: float = 0.9           # rad/s the kicked bike veers off while wobbling to a crash
const PART_S: float = 2.4                # a crash's flying parts (mirror, helmet) stay this long
const T_COUNTER: String = "PHẢN ĐÒN!"
const T_STICK_GOT: String = "Nhặt được gậy! [Q]/[E] vụt"
const T_STICK_BROKE: String = "Gãy gậy!"

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
const T_RIDING: String = "[Q]/[E] đạp · [SPACE] drift · [Q]/[E] khi drift: đá xoay · [SHIFT] nitro · [CTRL] cúi · [W]/[S] ga/phanh · [A]/[D] lái"
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
## Day 2 (D2X-5 to D2X-7, D2X-11).
const T_TAKEDOWN: Array[String] = ["TAKEDOWN!", "BAY MÀU!", "ĐI ĐÂU VỘI THẾ EM?"]
const T_TD_COUNT: String = "Hạ gục: %d"
const T_AIR_KICK: String = "AIR KICK!"
const T_DUCK: String = "[CTRL] CÚI XUỐNG"
const T_DUCKED: String = "CÚI NÉ!"
const T_BARRIER_HIT: String = "Đập mặt vào thanh chắn!"
const T_BARRIER_SIGN: String = "CÔNG TRÌNH\nCÚI XUỐNG"
const T_DRIFT: String = "DRIFT!"
const T_CURB: String = "VĂNG RA LỀ!"
const T_MELONS: String = "XE DƯA RỚT THÙNG!"
const T_MELON_HIT: String = "Dính dưa!"
const T_TRUCK_SIGN: String = "DƯA HẤU"
const T_WRONG_WAY: String = "ĐƯỜNG CHẶN! CHẠY NGƯỢC CHIỀU!"
const T_CONES: String = "Tông cọc!"
const T_RAMP: String = "BAY!"
const T_POLICE: String = "CẢNH SÁT TỚI!"
const T_POLICE_GONE: String = "Cảnh sát bỏ cuộc"
const T_HELMET_HIT: String = "Trúng mũ bảo hiểm!"
const T_PICKUP: String = "XE BÁN TẢI!"
const T_PICKUP_DOWN: String = "BÁN TẢI ÔM CỘT!"
const T_STICK_HIT: String = "Ăn gậy!"
const T_HEAVY_HIT: String = "Bị ủi văng!"
const T_CAMEO_TAUNT: String = "Muốn biết hàng về đâu thì lên cầu Rạch Hầm mà hỏi!"
const T_CAMEO_NAME: String = "SÓI XÁM - đầu đàn Bầy Sói"
## Wave 2 set pieces.
const T_GAP: String = "ĐƯỜNG SỤT! TĂNG TỐC MÀ NHẢY!"
const T_GAP_JUMP: String = "TĂNG TỐC! NHẢY QUA HỐ!"
const T_GAP_SHORT: String = "HỤT ĐÀ! Rớt bánh!"
const T_GAP_SIGN: String = "ĐƯỜNG SỤT\nTĂNG TỐC"
const T_ROADBLOCK: String = "CHỐT CHẶN! LỌT QUA KHE"
const T_ROADBLOCK_SEEN: String = "CẢNH SÁT CHẶN ĐƯỜNG!"
const T_ROADBLOCK_THROUGH: String = "LỌT KHE!"
const T_ROADBLOCK_HIT: String = "TÔNG CHỐT CHẶN!"

# ----- sounds (CineAudio / StoryAudio / WeaponAudio cues) -----
const CINE_CUES: Array[String] = ["impact_medium", "impact_heavy", "helmet_clonk", "slide_whistle", "body_fall", "groan", "engine_roar",
	"impact_light", "whoosh_down", "crate_smash", "tray_clang"]   # Day 2 set pieces (synthesized at setup, never mid-chase)
const STORY_CUES: Array[String] = ["bin_crash"]
const WEAPON_CUES: Array[String] = ["swish", "dep_whoosh"]

# ----- kick poses (CharacterBuilder joints, character frame; built once) -----
static var _kick_l: Dictionary = {}
static var _kick_r: Dictionary = {}
static var _flail: Dictionary = {}


## Q2: the kicked rider flailing on a wobbling bike (arms windmilling, head thrown about; legs keep the ride clip). One
## reused Dictionary (no allocation per frame).
static func flail_pose(t: float) -> Dictionary:
	var f: float = sin(t * 17.0)
	var g: float = sin(t * 13.0 + 1.1)
	_flail["shoulder_l"] = Vector3(1.9 + 0.7 * f, 0.0, 0.7 + 0.25 * g)
	_flail["shoulder_r"] = Vector3(1.9 - 0.7 * f, 0.0, -0.7 - 0.25 * g)
	_flail["elbow_l"] = Vector3(0.6 + 0.4 * g, 0.0, 0.0)
	_flail["elbow_r"] = Vector3(0.6 - 0.4 * g, 0.0, 0.0)
	_flail["torso"] = Vector3(0.25 + 0.1 * g, 0.0, 0.2 * f)
	_flail["head"] = Vector3(0.3 + 0.15 * f, 0.4 * g, 0.0)
	return _flail


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
	out.append_array(T_TAKEDOWN)
	out.append_array([T_TD_COUNT % 4, T_AIR_KICK, T_DUCK, T_DUCKED, T_BARRIER_HIT, T_BARRIER_SIGN, T_DRIFT, T_CURB, T_MELONS,
		T_MELON_HIT, T_TRUCK_SIGN, T_WRONG_WAY, T_CONES, T_RAMP, T_POLICE, T_POLICE_GONE, T_HELMET_HIT, T_PICKUP, T_PICKUP_DOWN,
		T_STICK_HIT, T_HEAVY_HIT, T_CAMEO_TAUNT, T_CAMEO_NAME, T_COUNTER, T_STICK_GOT, T_STICK_BROKE, T_GAP, T_GAP_JUMP, T_GAP_SHORT,
		T_GAP_SIGN, T_ROADBLOCK, T_ROADBLOCK_SEEN, T_ROADBLOCK_THROUGH, T_ROADBLOCK_HIT])
	for k: String in KIND_NAMES.keys():
		if String(KIND_NAMES[k]) != "":
			out.append(String(KIND_NAMES[k]))
	return out


## Q6 Dễ: enemy hits cost this much of their Thường damage, and every wind-up is this much longer.
const EASY_DMG: float = 0.65
const EASY_WINDUP: float = 0.2
static var _easy_kinds: Dictionary = {}


## The parameters of an enemy kind (KINDS; an unknown kind is a rider), adjusted for the difficulty (Dễ: softer hits,
## longer telegraphs; built once per kind, no allocation per call).
static func kind(k: String) -> Dictionary:
	var base: Dictionary = KINDS.get(k, KINDS["rider"])
	if not Difficulty.easy:
		return base
	var key: String = k if KINDS.has(k) else "rider"
	if not _easy_kinds.has(key):
		var e: Dictionary = base.duplicate()
		e["dmg"] = float(base["dmg"]) * EASY_DMG
		e["windup"] = float(base["windup"]) + EASY_WINDUP
		_easy_kinds[key] = e
	return _easy_kinds[key]
