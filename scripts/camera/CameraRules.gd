# File: res://scripts/camera/CameraRules.gd
# The rule book of every gameplay camera (Q1 camera director, spec 2026-10-29 section 3 Q1): reference values and the pure
# mappings the rigs (FootCamRig, BikeCamRig), the CameraDirector, the takedown cams and the framing tests share. Change a
# camera's feel here, never inside a rig.
class_name CameraRules
extends RefCounted

# --- on foot (FootCamRig) ---
const FOOT_SHOULDER: float = 0.45          # m to the right of the pivot
const FOOT_DIST: float = 3.2               # m behind the pivot
const FOOT_HEIGHT: float = 1.55            # pivot above the feet
const FOOT_FOV: float = 70.0
const FOOT_SPRINT_FOV: float = 6.0
const FOOT_FOV_EASE: float = 5.0           # 1/s
const FOOT_OMEGA: float = 14.0             # follow spring, horizontal (rad/s)
const FOOT_OMEGA_Y: float = 9.0            # follow spring, vertical: steps and jumps stay soft
const FOOT_LOOK_AHEAD: float = 0.8         # m in the move direction at jogging speed and above
const FOOT_AHEAD_OMEGA: float = 3.0
const FOOT_BOB: float = 0.025              # m at sprint speed
const DIP_SOFT: float = 0.08               # landing dip (m) of the pivot
const DIP_ROLL: float = 0.16
const DIP_SPLAT: float = 0.24
const DIP_OMEGA: float = 9.0
const PROBE_SIDE: float = 0.2              # side / top collision probes, m off the centre probe
const PULL_MARGIN: float = 0.25            # m kept between the camera and a hit
const PULL_MIN: float = 0.6                # closest the camera comes to the shoulder point while there is room ...
const PULL_HARD_MIN: float = 0.12          # ... and with a wall right behind (never inside it)
const CRANE_UP: float = 0.45               # m the camera rises as the room behind shrinks below PULL_MIN
const DOWN_CRANE: float = 0.9              # m the camera rises while the player lies knocked down (SPLAT)
const CLOSE_SIDE_LO: float = 0.3           # the shoulder offset shrinks to 0 as the distance falls from HI to LO (m)
const CLOSE_SIDE_HI: float = 1.5
const LOS_PASSES: int = 2                  # pull-in passes for a blocked view from the player's head / hips
const PULL_OUT_OMEGA: float = 4.0          # pull-in is instant, the way back out is sprung
const LOCAL_SHAKE_K: float = 0.7           # ThirdPersonController.shake(amp) -> trauma
const GUARD_MARGIN: float = 0.11           # framing guard: the player's head / chest / hips kept this far inside the edges
const GUARD_RELAX_OMEGA: float = 6.0       # (a bigger correction is instant, the way back is sprung)

# --- melee and sword combat (FootCamRig, combat mode) ---
const COMBAT_SPLIT: float = 0.3            # focus = player + 30 % of the way to the target (the 70/30 point)
const COMBAT_DIST_MIN: float = 3.5         # one enemy within COMBAT_RANGE
const COMBAT_DIST_MAX: float = 6.5
const COMBAT_DIST_STEP: float = 1.0        # per extra enemy
const COMBAT_RANGE: float = 8.0
const COMBAT_YAW_RATE_DEG: float = 90.0    # auto-yaw never turns faster
const COMBAT_YAW_GAIN: float = 3.0         # 1/s: the auto-yaw rate is min(gain x error, the cap)
const COMBAT_DEAD_DEG: float = 20.0        # a target within this of the view centre needs no turn
const COMBAT_VIEW_DEG: float = 75.0        # targets and attackers beyond this off the view are left to the HUD markers
const COMBAT_LOOK_IDLE_S: float = 0.5      # auto-yaw waits this long after mouse look
const COMBAT_DIST_OMEGA: float = 3.0
const COMBAT_SCAN_S: float = 0.1           # enemy scan at 10 Hz
const COMBAT_MIN_BEHIND: float = 1.4       # m the camera stays behind the player when a wall shortens the arm
const COMBAT_SHIFT_OMEGA: float = 6.0      # the focus shift's spring
const COMBAT_SIDE_ROOM: float = 1.8        # less room than this behind the player (to the target's line): a side view
const COMBAT_SIDE_DEG: float = 70.0

# --- bike chase cam (BikeCamRig) ---
const BIKE_GROUND: float = 0.13            # the road surface above the PlayerBike origin
const BIKE_HEIGHT: float = 1.35            # camera above the road
const BIKE_LOOK_H: float = 1.05            # look point above the road
const BIKE_LOOK_AHEAD: float = 2.0         # m ahead of the bike at rest ...
const BIKE_LOOK_AHEAD_TOP: float = 6.0     # ... and at top speed
const BIKE_DIST_REST: float = 3.8
const BIKE_DIST_TOP: float = 5.2
const BIKE_DIST_OMEGA: float = 2.5
const BIKE_FOV_REST: float = 70.0
const BIKE_FOV_TOP: float = 86.0
const BIKE_NITRO_FOV: float = 8.0
const BIKE_BOOST_FOV: float = 4.0          # slipstream / drift-release boost
const BIKE_FOV_EASE: float = 5.0
const BIKE_ROLL_K: float = 0.3             # camera roll = 30 % of the bike's lean
const BIKE_DRIFT_SWING_MIN: float = 12.0   # deg to the outside of a drift ...
const BIKE_DRIFT_SWING_MAX: float = 18.0   # ... at full steer
const BIKE_TURN_LOOK: float = 0.08         # rad into a normal turn per unit of steer
const BIKE_SWING_OMEGA: float = 5.0
const BIKE_WHIP_S: float = 0.12
const BIKE_WHIP_DEG: float = 7.0
const BIKE_ROAD_SHAKE: float = 0.008       # m of road shake at top speed (kept small)
const BIKE_TRAUMA_DECAY: float = 2.4       # PlayerBike.camera_shake_trauma per second
const BIKE_TRAUMA_M: float = 0.16          # m of shake at trauma 1 (trauma squared)
const BIKE_PROBE_R: float = 0.2            # SpringArm3D sphere

# --- bike chase takedown cams (BikeChase "td" cut): (side m, up m, along m) from the falling rider, in the player's
# frame, side = toward the rider; the first with a clear view wins ---
const TD_CANDIDATES: Array[Vector3] = [Vector3(5.5, 1.5, -1.5), Vector3(2.6, 0.7, 6.0), Vector3(2.4, 3.4, -5.0)]
const TD_RECHECK_S: float = 0.1

# --- director cuts (CameraDirector) ---
const CUT_DIST: float = 9.0                # preview cut: m from the target toward the viewer
const CUT_UP: float = 2.6
const CUT_SIDE_DEG: float = 35.0
const CUT_PUSH: float = 0.15               # push-in over the cut (fraction of the distance)
const CUT_FOV: float = 50.0
const CUT_SCALE: float = 0.35              # slow motion while a preview cut runs
const ORBIT_R: float = 3.4
const ORBIT_UP: float = 0.5                # above the look point (chest)
const ORBIT_DEG: float = 75.0
const ORBIT_FOV: float = 55.0
const ORBIT_SCALE: float = 0.25
const SHAKE_DECAY: float = 1.6             # trauma per real second
const SHAKE_M: float = 0.12                # m at trauma 1 (x trauma squared)
const SHAKE_DEG: float = 2.2               # deg at trauma 1 (roll x 1.5)
const SHAKE_HZ: float = 9.0
const PUNCH_OMEGA: float = 26.0
const PUNCH_M: float = 0.2                 # peak offset at strength 1
const PUNCH_DEG: float = 3.0               # peak rotation at strength 1
const PUNCH_FOV: float = -5.0              # peak FOV change at strength 1

# --- framing (CameraFraming, the tests) ---
const SAFE_MARGIN: float = 0.08


## Combat camera distance for n hostile enemies within COMBAT_RANGE (n <= 0: the plain on-foot distance).
static func combat_distance(n: int) -> float:
	if n <= 0:
		return FOOT_DIST
	return clampf(COMBAT_DIST_MIN + COMBAT_DIST_STEP * float(n - 1), COMBAT_DIST_MIN, COMBAT_DIST_MAX)


## Chase cam distance at speed ratio u (0 rest, 1 the profile's top speed).
static func bike_distance(u: float) -> float:
	return lerpf(BIKE_DIST_REST, BIKE_DIST_TOP, clampf(u, 0.0, 1.0))


## Chase cam FOV at speed ratio u, with the nitro burning or not (the ignition punch comes on top).
static func bike_fov(u: float, nitro: bool, boost: bool = false) -> float:
	return lerpf(BIKE_FOV_REST, BIKE_FOV_TOP, clampf(u, 0.0, 1.0)) + (BIKE_NITRO_FOV if nitro else 0.0) \
		+ (BIKE_BOOST_FOV if boost else 0.0)


## Drift swing (deg) to the outside of the turn for a steer input in -1..1 (positive = left; the outside is then right).
static func drift_swing_deg(steer: float) -> float:
	var a: float = absf(steer)
	if a < 0.01:
		return 0.0
	return signf(steer) * lerpf(BIKE_DRIFT_SWING_MIN, BIKE_DRIFT_SWING_MAX, clampf(a, 0.0, 1.0))


## Whip pulse 0..1 at t seconds into a BIKE_WHIP_S whip (0 outside).
static func whip_curve(t: float) -> float:
	if t < 0.0 or t >= BIKE_WHIP_S:
		return 0.0
	return sin(PI * t / BIKE_WHIP_S)


## One auto-yaw step: from yaw toward target (rad) at min(gain x error, the rate cap), the dead zone left alone.
static func auto_yaw_step(yaw: float, target: float, dt: float) -> float:
	var err: float = wrapf(target - yaw, -PI, PI)
	var dead: float = deg_to_rad(COMBAT_DEAD_DEG)
	if absf(err) <= dead:
		return yaw
	var beyond: float = err - signf(err) * dead
	var cap: float = deg_to_rad(COMBAT_YAW_RATE_DEG) * dt
	return yaw + clampf(beyond * minf(1.0, COMBAT_YAW_GAIN * dt), -cap, cap)


## Framing guard on one axis: the turn (rad) that brings the angles lo..hi (from the view centre) inside +/-lim, the
## smallest such turn (a span too wide for the limit is centred). With a second subject (t_lo <= t_hi, e.g. the combat
## target): among the turns that keep the first inside, the one that keeps the second inside too, else comes closest.
static func guard_fit(lo: float, hi: float, lim: float, t_lo: float = INF, t_hi: float = -INF) -> float:
	if hi - lo > 2.0 * lim:
		return (hi + lo) * 0.5
	var a: float = hi - lim
	var b: float = lo + lim
	if t_lo > t_hi:
		return clampf(0.0, a, b)
	var ta: float = t_hi - lim
	var tb: float = t_lo + lim
	var ia: float = maxf(a, ta)
	var ib: float = minf(b, tb)
	if ia <= ib:
		return clampf(0.0, ia, ib)
	var tc: float = (ta + tb) * 0.5 if ta > tb else (ta if ta > b else tb)
	return clampf(tc, a, b)


## Smooth shake noise in -1..1 (sums of incommensurate sines: deterministic, no allocation).
static func shake_noise(t: float, lane: int) -> float:
	var s: float = float(lane) * 1.618
	return 0.55 * sin(t * 6.283 * SHAKE_HZ + s * 2.1) + 0.3 * sin(t * 6.283 * SHAKE_HZ * 1.73 + s * 4.7) \
		+ 0.15 * sin(t * 6.283 * SHAKE_HZ * 2.91 + s * 1.3)
