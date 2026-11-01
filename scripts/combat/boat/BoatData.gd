# File: res://scripts/combat/boat/BoatData.gd
# Tuning of the Day 6 speedboat chase (plan 2026-11-01-w4-day6.md T4) in one place. Everything lives in route space on the
# LairCanal course: s (metres along the canal), d (lateral, right +, the banks at +/- LairCanal.HALF_W), v (m/s along s).
# Numbers the difficulty changes go through Difficulty.pick(normal, easy) in the functions below; the constants are the
# same for both. Strings are the chase's Vietnamese HUD lines (plain text, no emoji).
class_name BoatData
extends RefCounted

# ----- the player's speedboat -----
const V_CRUISE: float = 13.0             # no throttle: the engine idles the boat forward at this speed
const V_SLOW: float = 5.0                # [S] held
const ACCEL: float = 9.0
const BRAKE: float = 16.0
const LAT_MS: float = 8.5                # [A] / [D] lateral speed (m/s)
const LAT_RESP: float = 6.0              # how fast the lateral speed follows the stick (1/s)
const BEAM_HALF: float = 1.0             # half the hull's width (bank contact)
const LEN_HALF: float = 2.6              # half the hull's length (s contact)
const BANK_BOUNCE: float = 0.35          # lateral speed kept (reversed) off a bank wall
const HULL: float = 100.0
const KICK_ALONG: float = 2.8            # +/- along the boat a jet ski can be kicked (m) ...
const KICK_MIN: float = 0.5              # ... from this far to the side ...
const KICK_MAX: float = 3.6              # ... to this far
const KICK_WINDUP: float = 0.10
const KICK_ACTIVE_END: float = 0.32
const KICK_DUR: float = 0.45
const KICK_COOLDOWN: float = 0.5
const DUCK_IN_S: float = 0.12            # [CTRL]: the head is down after this (the bridge check uses ducked())
const GRAVITY: float = 14.0              # the ramp jump (arcade)
const RAMP_UP: float = 0.42              # vertical speed off the lip per m/s of speed
const RAMP_MIN_V: float = 12.0           # slower than this the boat climbs the sampan and flops back (no jump)
const CLEAR_H: float = 1.75              # airborne higher than this clears the broken pier wall

# ----- hazards (LairCanal: BRIDGES, NETS, RAMP_S / RAMP_D / GAP_D1, BARGE_S / BARGE_D) -----
const BRIDGE_HALF: float = 1.4           # +/- s around a bridge's centre line where an upright head hits it
const NET_HALF: float = 0.6
const NET_INNER: float = 0.4             # a net covers its half of the canal from this far past the centre line
const RAMP_HALF_D: float = 0.9           # +/- d around RAMP_D that takes the ramp
const WALL_HALF: float = 0.8
const WALL_SOFT_V: float = 4.0           # slower than this into the pier wall: blocked, no damage (creeping along it)
const WALL_CD: float = 1.5               # one damaging wall hit per this long
const BARGE_HALF_S: float = 6.2
const BARGE_HALF_D: float = 2.1
const STUN_S: float = 1.1                # a net / wall / bridge hit: no throttle for this long

# ----- the jet skis (Bầy Sói) -----
const SKI_FLANK_D: float = 4.4           # their slot beside the boat (each side), out of kick reach (KICK_MAX) ...
const SKI_TELL_D: float = 2.4            # ... the telegraph closes in to this: the kick's window (T8 sim_day6)
const SKI_LEASH: float = 32.0            # further than this behind: they gun it to catch up
const SKI_V_EXTRA: float = 9.0
const SKI_RAM_DASH: float = 9.0          # lateral speed of the ram dash (m/s)
const SKI_RAM_ALONG: float = 2.4         # the ram connects within this along ...
const SKI_RAM_D: float = 1.7             # ... and this across
const SKI_SPAWN_BEHIND: float = 26.0     # spawned behind the boat, out of the chase camera's view
## Waves: [s where they come, count Thường, count Dễ]
const WAVES: Array = [[110.0, 2, 1], [480.0, 2, 2], [1020.0, 3, 2], [1560.0, 3, 2]]

# ----- Thị Lọ's pink speedboat -----
const RIVAL_GAP: float = 24.0            # the rubber band keeps her about this far ahead ...
const RIVAL_GAP_MIN: float = 12.0
const RIVAL_V_MAX: float = 29.0
const RIVAL_WEAVE_D: float = 3.2
const FINALE_S: float = 1350.0           # past the fireworks barge she tires: catch her and ram her into the bank
const RAM_ALONG: float = 5.6             # bow to stern (the two hulls' centres) ...
const RAM_D: float = 1.9                 # ... and across
const RAM_CLOSING: float = 1.0           # faster than her by at least this (m/s)
const RAM_PUSH_D: float = 2.6            # each ram pushes her this far toward the right bank
const RAM_COOLDOWN: float = 1.2
const LOSE_GAP: float = 130.0            # further ahead than this ...
const LOSE_S: float = 5.0                # ... this long = she got away
const END_MARGIN: float = 45.0           # the rams not done before the end of the canal = she got away
# ----- set pieces (BoatSetPieces) -----
const NET_RAISE_AT: float = 70.0         # a net rises when the boat is this far before it ...
const NET_RAISE_S: float = 1.4           # ... over this long (its red top line on: the telegraph)
const NET_LIVE_W: float = 0.6            # raised past this it catches a hull
const JUMP_SCALE: float = 0.4            # the ramp jump in slow motion (the Impact clock) ...
const JUMP_SLOW_S: float = 0.9           # ... for this long (real seconds), the side camera until the landing
const BARGE_FROM: float = 150.0          # the rogue rockets fly while the boat is this far before the barge ...
const BARGE_TO: float = 10.0             # ... until this far past it
const ROCKET_R: float = 2.4              # a rocket's blast radius (its red ring on the water)
const TITANIC_S: float = 3.0             # her Titanic pose on the bow at the finale (nobody steering: she coasts)
const FINISH_ORBIT_S: float = 1.2        # the last ram: slow-motion orbit (real seconds)
## Checkpoints (route s): a retry starts at the last one passed with a full hull.
const CHECKPOINTS: Array[float] = [6.0, 450.0, 860.0, 1340.0]

# ----- HUD / fail lines -----
const T_DUCK: String = "CÚI! [CTRL]"
const T_KICK: String = "[Q] đá trái   [E] đá phải"
const T_RAM: String = "Húc cano của Thị Lọ vào bờ!"
const T_SINK: String = "Cano nát bét rồi."
const T_LOST: String = "Thị Lọ chạy mất tiêu rồi."
const T_BONK: String = "Cốp! Quên cúi đầu..."
const T_NET: String = "Dính lưới!"
const T_WALL: String = "Rầm! Đâm trụ cầu gãy"
const T_ROCKET: String = "Dính pháo lạc!"
const T_TITANIC: String = "Tao là nữ hoàng kênh Rạch Hầm!"


static func v_max() -> float:
	return float(Difficulty.pick(26.0, 24.0))


static func bank_dps() -> float:
	return float(Difficulty.pick(14.0, 9.0))


static func dmg_bridge() -> float:
	return float(Difficulty.pick(30.0, 20.0))


static func dmg_net() -> float:
	return float(Difficulty.pick(20.0, 14.0))


static func dmg_wall() -> float:
	return float(Difficulty.pick(40.0, 28.0))


static func dmg_barge() -> float:
	return float(Difficulty.pick(18.0, 12.0))


static func dmg_ram() -> float:
	return float(Difficulty.pick(20.0, 9.0))


## Seconds the jet ski telegraphs its ram (the red ring, "!") before it dashes in.
static func ski_tell() -> float:
	return float(Difficulty.pick(0.9, 1.25))


static func ski_ram_gap() -> float:
	return float(Difficulty.pick(3.0, 4.6))


## A rogue rocket every this many seconds near the fireworks barge, its ring this long before it lands, its damage.
static func rocket_gap() -> float:
	return float(Difficulty.pick(1.3, 1.9))


static func rocket_tell() -> float:
	return float(Difficulty.pick(1.0, 1.35))


static func dmg_rocket() -> float:
	return float(Difficulty.pick(14.0, 8.0))


static func rams_needed() -> int:
	return int(Difficulty.pick(3, 2))


static func wave_count(w: Array) -> int:
	return int(Difficulty.pick(int(w[1]), int(w[2])))


## The kick leg's weight over the rider at t seconds into a kick (0 -> 1 -> 0).
static func kick_weight(t: float) -> float:
	return BikeCombatData.kick_weight(t, KICK_WINDUP, KICK_ACTIVE_END, KICK_DUR)
