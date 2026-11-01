# File: res://scripts/combat/boat/PlayerBoat.gd
# The player's speedboat in the Day 6 canal chase (plan 2026-11-01-w4-day6.md T4): arcade water handling in route space on
# the LairCanal course (s along, d across, right +), the hull HP, the duck under the low bridges, the side kicks, the bow
# spray. BoatChase owns it, feeds `input` and calls step(dt) on the chase clock; the hazards are BoatChase's.
#   input: {"throttle": -1..1 ([W] / [S]), "steer": -1..1 ([A] / [D]), "duck": bool ([CTRL])}
#   step(dt)                one step; then `scraped` (against a bank wall this step) and `landed` (back on the water after
#                           a jump this step) tell what happened (fields: no per-frame Dictionary)
#   kick(side) -> bool      side -1 left [Q], +1 right [E]; the kick's hit window: kick_active()
#   damage(n), stun(secs), launch(lip_h, vy) (the ramp), place(s, d, v)
# Look: the white and orange speedboat (CinePropsD6), the protagonist on the driver's seat in the pink shipper shirt (the
# "ride" clip; the duck folds the body down over the console), a kick leg (BikeCombatData.kick_pose, a bone layer after
# the RigAnimator), a bow spray growing with the speed. The transform follows the route heading plus the steering yaw,
# with a bob on the waves, a roll into the turn and the nose up in the air.
class_name PlayerBoat
extends Node3D

const SEAT := Vector3(-0.45, 0.05, 0.95)   # the "ride" clip's hips 0.62 m over the origin, on the driver's cushion (0.67)

var level: LairCanal
var s: float = 0.0
var d: float = 0.0
var v: float = 0.0
var lat_v: float = 0.0
var hull: float = BoatData.HULL
var air_h: float = 0.0
var air_vy: float = 0.0
var airborne: bool = false
var duck_t: float = 0.0
var kick_t: float = -1.0
var kick_side: int = 0
var kick_cd: float = 0.0
var kick_hit: bool = false
var stun_t: float = 0.0
var scraped: bool = false                 # this step: against a bank wall
var landed: bool = false                  # this step: back on the water after a jump
var input: Dictionary = {"throttle": 0.0, "steer": 0.0, "duck": false}
var hull_node: Node3D
var rider: Node3D
var spray: CPUParticles3D
var _sk: Skeleton3D = null
var _anim: Node = null
var _bob_t: float = 0.0


func setup(lv: LairCanal, rider_opts: Dictionary) -> void:
	level = lv
	name = "PlayerBoat"
	process_priority = 11                  # the kick leg layer runs after the rider's RigAnimator (10)
	hull_node = CineFX.build_prop("speedboat", {"color": Color("#F4F1EA"), "trim": Color("#F37021")})
	hull_node.name = "Hull"
	add_child(hull_node)
	var o: Dictionary = rider_opts.duplicate()
	o["rigged"] = true
	o["clip"] = "ride"
	o["name"] = "BoatRider"
	rider = CharacterBuilder.build(o)
	if rider:
		rider.position = SEAT
		hull_node.add_child(rider)
		CharacterBuilder.set_param(rider, "ride_shoulder", 1.0)
		CharacterBuilder.set_param(rider, "ride_elbow", 0.5)
		CharacterBuilder.set_param(rider, "ride_lean", 0.3)
		_sk = rider.get_meta("skeleton") as Skeleton3D if rider.has_meta("skeleton") else null
		_anim = CharacterBuilder.get_animator(rider)
		var ap: AnimationPlayer = _anim.get("player") as AnimationPlayer if _anim else null
		if ap:
			ap.active = false              # the "ride" code clip owns the joints while driving
	spray = make_spray(hull_node, Vector3(0.0, 0.1, -2.0))


## A bow spray emitter (world-space droplets), shared with the rival and the jet skis.
static func make_spray(parent: Node3D, at: Vector3, amount: int = 28) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Spray"
	p.amount = amount
	p.lifetime = 0.55
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3(0.0, 1.0, 0.6)
	p.spread = 35.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.18
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.93, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.set_meta("vice_done", true)
	qm.material = m
	p.mesh = qm
	p.position = at
	parent.add_child(p)
	return p


func place(s0: float, d0: float, v0: float) -> void:
	s = s0
	d = d0
	v = v0
	lat_v = 0.0
	air_h = 0.0
	air_vy = 0.0
	airborne = false
	stun_t = 0.0
	kick_t = -1.0
	kick_cd = 0.0
	duck_t = 0.0
	_apply_xf()


func step(dt: float) -> void:
	scraped = false
	landed = false
	_bob_t += dt
	kick_cd = maxf(0.0, kick_cd - dt)
	if kick_t >= 0.0:
		kick_t += dt
		if kick_t >= BoatData.KICK_DUR:
			kick_t = -1.0
	duck_t = duck_t + dt if bool(input.get("duck", false)) else 0.0
	stun_t = maxf(0.0, stun_t - dt)
	var thr: float = float(input.get("throttle", 0.0))
	var target: float = BoatData.V_CRUISE
	if thr > 0.1:
		target = BoatData.v_max()
	elif thr < -0.1:
		target = BoatData.V_SLOW
	if stun_t > 0.0:
		target = minf(target, BoatData.V_SLOW)
	if not airborne:
		v = move_toward(v, target, (BoatData.ACCEL if target > v else BoatData.BRAKE) * dt)
	var grip: float = clampf(v / 10.0, 0.35, 1.0) * (0.25 if airborne else 1.0)
	var want: float = clampf(float(input.get("steer", 0.0)), -1.0, 1.0) * BoatData.LAT_MS * grip
	lat_v = lerpf(lat_v, want, minf(1.0, dt * BoatData.LAT_RESP))
	s += v * dt
	d += lat_v * dt
	if airborne:
		air_vy -= BoatData.GRAVITY * dt
		air_h += air_vy * dt
		if air_h <= 0.0 and air_vy < 0.0:
			air_h = 0.0
			air_vy = 0.0
			airborne = false
			landed = true
	var lim: float = LairCanal.HALF_W - BoatData.BEAM_HALF
	if absf(d) > lim:
		d = signf(d) * lim
		if signf(lat_v) == signf(d):
			lat_v = -lat_v * BoatData.BANK_BOUNCE
		scraped = true
	_apply_xf()
	if spray:
		spray.emitting = v > 6.0 and not airborne


## The ramp: up off the sampan's lip at lip_h with a vertical speed vy.
func launch(lip_h: float, vy: float) -> void:
	airborne = true
	air_h = lip_h
	air_vy = vy


func damage(n: float) -> void:
	hull = maxf(0.0, hull - n)


func stun(secs: float) -> void:
	stun_t = maxf(stun_t, secs)


func ducked() -> bool:
	return duck_t >= BoatData.DUCK_IN_S


func kick(side: int) -> bool:
	if kick_cd > 0.0 or kick_t >= 0.0 or side == 0:
		return false
	kick_t = 0.0
	kick_side = side
	kick_cd = BoatData.KICK_COOLDOWN
	kick_hit = false
	return true


## The kick's hit window is open (a jet ski in reach now takes it; one per kick).
func kick_active() -> bool:
	return kick_t >= BoatData.KICK_WINDUP and kick_t <= BoatData.KICK_ACTIVE_END and not kick_hit


## The bow's world point (the rams, the camera).
func bow() -> Vector3:
	return global_transform * Vector3(0.0, 0.6, -2.2)


func _apply_xf() -> void:
	if level == null:
		return
	var bob: float = 0.0 if airborne else sin(_bob_t * 2.3) * 0.05 + sin(_bob_t * 3.7 + 1.0) * 0.025
	var pos: Vector3 = level.course_pos(s, d, air_h + bob)
	var yaw: float = level.yaw_at(s) - atan2(lat_v, maxf(v, 4.0)) * 0.9
	var pitch: float = clampf(air_vy * 0.035, -0.3, 0.35) if airborne else 0.04 * clampf(v / 20.0, 0.0, 1.0)
	var roll: float = clampf(-lat_v * 0.03, -0.25, 0.25)
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)
	if rider:
		var dw: float = clampf(duck_t / BoatData.DUCK_IN_S, 0.0, 1.0)
		rider.position = SEAT + Vector3(0.0, -0.28 * dw, -0.05 * dw)
		CharacterBuilder.set_param(rider, "ride_lean", 0.3 + 0.9 * dw)


## Kick leg over the rider (a bone layer on the frames its RigAnimator ran; a lean without a skeleton).
func _process(_dt: float) -> void:
	if rider == null:
		return
	var w: float = 0.0 if kick_t < 0.0 else BoatData.kick_weight(kick_t)
	if _sk:
		if w > 0.001 and (_anim == null or int(_anim.get("_lod_skip")) == 1):
			CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.kick_pose(float(kick_side)), w)
	else:
		rider.rotation.z = -float(kick_side) * 0.35 * w
