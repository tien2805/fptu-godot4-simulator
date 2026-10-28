# File: res://scripts/camera/BikeCamRig.gd
# Chase camera of a PlayerBike (Q1 camera director, spec 2026-10-29 Q1 "Bike"). It drives the bike's own scene nodes, so
# every caller keeps them: CameraRig (the pivot, at the look height), SpringArm3D (the collision pull-in: a 0.2 m sphere,
# the bike itself and FreeRoam's excluded bodies left out) and its Camera3D (chase_cam).
#   - low chase cam: BIKE_HEIGHT above the road, BIKE_DIST_REST at rest to BIKE_DIST_TOP at the profile's top speed,
#     looking at a point ahead of the bike (further with speed);
#   - yaw locked to the bike plus a sprung offset: a look into normal turns, a 12-18 deg swing to the outside of a drift
#     (the bike's side shows), and the 0.12 s whip of a kick hit toward the target (cam_whip, real time);
#   - roll = 30 % of the bike's lean; FOV 70 -> 86 with speed, +8 while the nitro burns (the ignition punch on top),
#     +4 in a slipstream / drift-release boost;
#   - shake through the camera's h / v offsets: PlayerBike.camera_shake_trauma squared plus a small road shake growing
#     with speed (smooth noise), plus the CameraDirector's punch / shake (fx_*).
class_name BikeCamRig
extends RefCounted

var bike: PlayerBike
## Current sprung yaw offset (rad, + = camera to the bike's right), distance, roll (rad) and whip (tests).
var swing: float = 0.0
var dist: float = CameraRules.BIKE_DIST_REST
var roll: float = 0.0
var whip_yaw: float = 0.0
var whips: int = 0
var _swing_v: float = 0.0
var _dist_v: float = 0.0
var _whip_t: float = -1.0
var _whip_side: float = 0.0
var _clock: float = 0.0
var _snap: bool = true
var _director: CameraDirector = null
var _director_t: float = 0.0
var _shape: SphereShape3D = null
var _last_fx_fov: float = 0.0
var _was_current: bool = false
var _d: Director = Director.new()


func _init(b: PlayerBike) -> void:
	bike = b


## Once the bike's nodes exist: the arm's sphere, the bike left out of it, the director meta on the camera.
func attach() -> void:
	if bike.spring_arm:
		_shape = SphereShape3D.new()
		_shape.radius = CameraRules.BIKE_PROBE_R
		bike.spring_arm.shape = _shape
		bike.spring_arm.add_excluded_object(bike.get_rid())
	if bike.chase_cam:
		bike.chase_cam.set_meta(CameraDirector.META_FX, bike)
		bike.chase_cam.near = 0.08


## Next update jumps to the pose (a respawn, a mount).
func snap() -> void:
	_snap = true


## Whip toward a world direction (the kicked target): the side by the bike's right axis.
func whip(dir: Vector3) -> void:
	var r: Vector3 = bike.global_basis.x
	var s: float = Vector2(dir.x, dir.z).dot(Vector2(r.x, r.z))
	if absf(s) < 1e-3:
		return
	_whip_side = signf(s)
	_whip_t = 0.0
	whips += 1


func update(delta: float, _speed_factor: float) -> void:
	var b: PlayerBike = bike
	var arm: SpringArm3D = b.spring_arm
	var cam: Camera3D = b.chase_cam
	if arm == null or cam == null:
		return
	var dt: float = maxf(delta, 0.0)
	var rdt: float = minf(dt / maxf(Engine.time_scale, 0.01), 0.1)
	if cam.current and not _was_current:
		_snap = true                         # mounted / back from a cut or a cinematic: no swoop from an old pose
	_was_current = cam.current
	_clock += rdt
	var u: float = clampf(absf(b.current_speed_ms) / maxf(b.max_speed_ms, 0.1), 0.0, 1.0)
	# yaw offset: into a normal turn, to the outside of a drift
	var want_swing: float = deg_to_rad(CameraRules.drift_swing_deg(b.steer_input)) if b.is_drifting else -b.steer_input * CameraRules.BIKE_TURN_LOOK
	var want_dist: float = CameraRules.bike_distance(u)
	if _snap:
		swing = want_swing
		_swing_v = 0.0
		dist = want_dist
		_dist_v = 0.0
	else:
		var sv: Vector2 = CamSpring.damp(swing, _swing_v, want_swing, CameraRules.BIKE_SWING_OMEGA, dt)
		swing = sv.x
		_swing_v = sv.y
		var dv: Vector2 = CamSpring.damp(dist, _dist_v, want_dist, CameraRules.BIKE_DIST_OMEGA, dt)
		dist = dv.x
		_dist_v = dv.y
	if _whip_t >= 0.0:
		_whip_t += rdt
		if _whip_t >= CameraRules.BIKE_WHIP_S:
			_whip_t = -1.0
	whip_yaw = -_whip_side * deg_to_rad(CameraRules.BIKE_WHIP_DEG) * CameraRules.whip_curve(_whip_t)
	# arm: pivot at the look height, raised so the camera sits BIKE_HEIGHT above the road
	var rig: Node3D = arm.get_parent() as Node3D
	var pivot_y: float = CameraRules.BIKE_GROUND + CameraRules.BIKE_LOOK_H
	if rig:
		rig.position = Vector3(0.0, pivot_y, 0.0)
	var rise: float = CameraRules.BIKE_HEIGHT - CameraRules.BIKE_LOOK_H
	arm.rotation = Vector3(-asin(clampf(rise / maxf(dist, 0.5), -1.0, 1.0)), swing, 0.0)
	arm.spring_length = dist
	# camera: look ahead of the bike from the ideal (not pulled-in) spot, roll with the lean, whip, director rotation
	var axf: Transform3D = arm.global_transform
	var ideal: Vector3 = axf.origin + axf.basis.z.normalized() * dist
	var fwd: Vector3 = -b.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	var look: Vector3 = b.global_position + Vector3.UP * pivot_y + fwd * lerpf(CameraRules.BIKE_LOOK_AHEAD, CameraRules.BIKE_LOOK_AHEAD_TOP, u)
	roll = b.tilt_angle * CameraRules.BIKE_ROLL_K
	var d: Director = _fx(rdt)
	var bas: Basis = Basis.looking_at(look - ideal, Vector3.UP) if (look - ideal).length_squared() > 1e-4 else cam.global_basis
	bas = bas * Basis(Vector3(0.0, 0.0, 1.0), roll)
	bas = Basis(Vector3.UP, whip_yaw) * bas
	if d.on:
		bas = bas * Basis.from_euler(d.rot * (PI / 180.0))
	cam.global_basis = bas.orthonormalized()
	# FOV
	var boost: bool = b.is_slipstream_boosting or b.drift_boost_timer > 0.0
	var target_fov: float = CameraRules.bike_fov(u, b.nitro_left > 0.0, boost)
	if b.nitro_left > 0.0:
		target_fov += PlayerBike.NITRO_FOV_PUNCH * (b._nitro_punch / PlayerBike.NITRO_PUNCH_S)
	if _snap:
		cam.fov = target_fov + d.fov
	else:
		cam.fov = lerpf(cam.fov - _last_fx_fov, target_fov, 1.0 - exp(-CameraRules.BIKE_FOV_EASE * dt)) + d.fov
	_last_fx_fov = d.fov
	# shake: trauma squared + a small road shake with speed + the director's offset
	if b.camera_shake_trauma > 0.0:
		b.camera_shake_trauma = maxf(b.camera_shake_trauma - CameraRules.BIKE_TRAUMA_DECAY * dt, 0.0)
	var k: float = b.camera_shake_trauma * b.camera_shake_trauma
	var amp: float = CameraRules.BIKE_TRAUMA_M * k + CameraRules.BIKE_ROAD_SHAKE * u * u
	cam.h_offset = CameraRules.shake_noise(_clock, 10) * amp + d.off.x
	cam.v_offset = CameraRules.shake_noise(_clock, 11) * amp + d.off.y
	_snap = false


## The director's effects of this frame (zero without a director).
class Director:
	var on: bool = false
	var off: Vector3 = Vector3.ZERO
	var rot: Vector3 = Vector3.ZERO
	var fov: float = 0.0


func _fx(rdt: float) -> Director:
	var dd: CameraDirector = _find_director(rdt)
	_d.on = dd != null
	_d.off = dd.fx_offset if dd else Vector3.ZERO
	_d.rot = dd.fx_rot_deg if dd else Vector3.ZERO
	_d.fov = dd.fx_fov if dd else 0.0
	return _d


func _find_director(rdt: float) -> CameraDirector:
	if _director != null and is_instance_valid(_director) and _director.is_inside_tree():
		return _director
	_director = null
	_director_t -= rdt
	if _director_t > 0.0:
		return null
	_director_t = 0.5
	_director = CameraDirector.live()
	if _director == null and bike.is_inside_tree():
		CameraDirector.ensure(bike)
	return _director
