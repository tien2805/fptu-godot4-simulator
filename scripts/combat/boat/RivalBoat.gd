# File: res://scripts/combat/boat/RivalBoat.gd
# Thị Lọ's pink speedboat in the Day 6 canal chase (plan 2026-11-01-w4-day6.md T4), route space like PlayerBoat.
#   - The rubber band: she keeps about BoatData.RIVAL_GAP ahead of the player (never closer than RIVAL_GAP_MIN before the
#     finale: caught up, she guns it); a slow player loses her (BoatChase: LOSE_GAP for LOSE_S).
#   - She weaves across the canal, and reads the course: the free half at a net, the sampan ramp at RAMP_D (she always
#     jumps the broken pier), the left of the fireworks barge.
#   - The finale (past BoatData.FINALE_S): she tires and lets the player close in; each ram (BoatChase) pushes her toward
#     the right bank with a wobble and a short burst; after the last one she veers into the bank and stops nose up
#     (crash(): `crashed`, steam).
# Look: CinePropsD6 speedboat in pink with "LỌ" on the hull, Thị Lọ (StoryCast "thi_lo") at the wheel on the "ride" clip, a
# bow spray.
class_name RivalBoat
extends Node3D

const SEAT := Vector3(-0.45, 0.05, 0.95)
const RIVAL_FINALE_D: float = 4.0       # the finale weave (half width)
const FINALE_SLOWER: float = 4.0        # her finale pace under BoatData.v_max()
const FINALE_FAR: float = 30.0
const BOW := Vector3(0.0, 0.62, -1.55)   # standing on the bow (the Titanic), as in seg_d6_chase
const POSE_IN_S: float = 0.35
## The Titanic: standing straight, arms spread wide, chin up, a little lean back (a bone layer over the "ride" clip).
const TITANIC_POSE: Dictionary = {"hips_y": 0.0, "thigh_l": Vector3.ZERO, "thigh_r": Vector3.ZERO, "knee_l": Vector3.ZERO,
	"knee_r": Vector3.ZERO, "torso": Vector3(-0.12, 0.0, 0.0), "head": Vector3(-0.2, 0.0, 0.0),
	"shoulder_l": Vector3(0.1, 0.0, -1.45), "shoulder_r": Vector3(0.1, 0.0, 1.45), "elbow_l": Vector3.ZERO, "elbow_r": Vector3.ZERO}

var level: LairCanal
var s: float = 0.0
var d: float = 0.0
var v: float = 0.0
var lat_v: float = 0.0
var air_h: float = 0.0
var air_vy: float = 0.0
var airborne: bool = false
var rams: int = 0
var crashed: bool = false
var crash_t: float = -1.0
var hit_t: float = -1.0
var burst_t: float = 0.0
var titanic_t: float = 0.0
var titanic_w: float = 0.0
var hull_node: Node3D
var driver: Node3D
var spray: CPUParticles3D
var steam: CPUParticles3D
var _weave_t: float = 0.0
var _bob_t: float = 0.0
var _sk: Skeleton3D = null
var _anim: Node = null


func setup(lv: LairCanal) -> void:
	level = lv
	name = "RivalBoat"
	process_priority = 11                  # the Titanic layer runs after the driver's RigAnimator (10)
	hull_node = CineFX.build_prop("speedboat", {"color": Color("#FFB3D6"), "trim": Color("#FF4FA3"), "name": "LỌ"})
	hull_node.name = "Hull"
	add_child(hull_node)
	driver = StoryCast.build("thi_lo", {"clip": "ride"})
	if driver:
		driver.position = SEAT
		hull_node.add_child(driver)
		CharacterBuilder.set_param(driver, "ride_shoulder", 1.0)
		CharacterBuilder.set_param(driver, "ride_elbow", 0.5)
		CharacterBuilder.set_param(driver, "ride_lean", 0.25)
		var an: Node = CharacterBuilder.get_animator(driver)
		var ap: AnimationPlayer = an.get("player") as AnimationPlayer if an else null
		if ap:
			ap.active = false
		_anim = an
		_sk = driver.get_meta("skeleton") as Skeleton3D if driver.has_meta("skeleton") else null
	Readability.rim(hull_node, "enemy")   # Q3 rim on her boat and on her
	spray = PlayerBoat.make_spray(hull_node, Vector3(0.0, 0.1, -2.0))
	steam = PlayerBoat.make_spray(hull_node, Vector3(0.0, 1.0, 2.8), 16)
	steam.direction = Vector3.UP
	steam.gravity = Vector3(0.0, 1.5, 0.0)
	steam.initial_velocity_min = 0.6
	steam.initial_velocity_max = 1.4
	steam.lifetime = 1.6
	((steam.mesh as QuadMesh).material as StandardMaterial3D).albedo_color = Color(0.85, 0.85, 0.88, 0.45)


func place(s0: float, d0: float, v0: float) -> void:
	s = s0
	d = d0
	v = v0
	lat_v = 0.0
	air_h = 0.0
	air_vy = 0.0
	airborne = false
	rams = 0
	crashed = false
	crash_t = -1.0
	hit_t = -1.0
	burst_t = 0.0
	titanic_t = 0.0
	titanic_w = 0.0
	if driver:
		driver.position = SEAT
	if steam:
		steam.emitting = false
	_apply_xf()


## One chase step behind the player's boat; `finale`: she can be caught and rammed.
func think(dt: float, boat: PlayerBoat, finale: bool) -> void:
	_bob_t += dt
	_weave_t += dt
	if hit_t >= 0.0:
		hit_t += dt
		if hit_t > 0.8:
			hit_t = -1.0
	burst_t = maxf(0.0, burst_t - dt)
	titanic_t = maxf(0.0, titanic_t - dt)
	titanic_w = move_toward(titanic_w, 1.0 if titanic_t > 0.0 else 0.0, dt / POSE_IN_S)
	if driver:
		driver.position = SEAT.lerp(BOW, titanic_w)
	var lim: float = LairCanal.HALF_W - BoatData.BEAM_HALF
	if crashed:
		crash_t += dt
		v = move_toward(v, 0.0, 18.0 * dt)
		lat_v = lerpf(lat_v, 7.0, minf(1.0, dt * 3.0)) if d < lim - 0.05 else 0.0
		s += v * dt
		d = minf(d + lat_v * dt, lim + 0.6)
		air_h = move_toward(air_h, 0.35, dt)   # up on the bank's stones
		_apply_xf()
		return
	var gap: float = s - boat.s
	var want_v: float = clampf(boat.v + (BoatData.RIVAL_GAP - gap) * 0.7, BoatData.V_CRUISE + 3.0, BoatData.RIVAL_V_MAX)
	if not finale and gap < BoatData.RIVAL_GAP_MIN:
		want_v = maxf(want_v, boat.v + 5.0)
	if finale:
		# tired: a fixed pace under the player's top speed (not tied to the player's speed, so a ram can always close in);
		# a short burst away after each ram; slower still when the player fell far behind
		want_v = BoatData.v_max() - FINALE_SLOWER
		if burst_t > 0.0:
			want_v = BoatData.v_max() + 2.0
		elif gap > FINALE_FAR or titanic_t > 0.0:
			want_v = BoatData.v_max() - FINALE_SLOWER * 2.0   # far behind / posing on the bow: nobody steering, she coasts
	if not airborne:
		v = move_toward(v, want_v, 12.0 * dt)
	var td: float = _plan_d() if not finale else RIVAL_FINALE_D * sin(_weave_t * 0.9)
	if titanic_t > 0.0:
		td = d                               # hands off the wheel
	lat_v = lerpf(lat_v, clampf((td - d) * 2.2, -7.0, 7.0), minf(1.0, dt * 3.0))
	var prev_s: float = s
	s += v * dt
	d = clampf(d + lat_v * dt, -lim, lim)
	# the sampan ramp: she always takes it and jumps the broken pier
	var lip: float = LairCanal.RAMP_S - 6.0
	if not airborne and prev_s < lip and s >= lip:
		airborne = true
		air_h = BoatChase.LIP_H
		air_vy = maxf(v, 16.0) * BoatData.RAMP_UP
	elif not airborne and s > lip - 6.0 and s < lip and absf(d - LairCanal.RAMP_D) < 1.5:
		air_h = BoatChase.LIP_H * clampf((s - (lip - 6.0)) / 6.0, 0.0, 1.0)
	elif not airborne:
		air_h = 0.0
	if airborne:
		air_vy -= BoatData.GRAVITY * dt
		air_h += air_vy * dt
		if air_h <= 0.0 and air_vy < 0.0:
			air_h = 0.0
			air_vy = 0.0
			airborne = false
			Impact.particles(self, "splash", global_position, Vector3.UP, 1.2)
	_apply_xf()


## Where she steers before the finale: the weave, the free half at a net, the ramp line, the left of the barge.
func _plan_d() -> float:
	var td: float = BoatData.RIVAL_WEAVE_D * sin(_weave_t * 0.6)
	for n: Array in LairCanal.NETS:          # the nearest net ahead decides (NETS in course order)
		var ns: float = float(n[0])
		if s > ns - 60.0 and s < ns + 3.0:
			td = -float(n[1]) * 5.5
			break
	if s > LairCanal.RAMP_S - 70.0 and s < LairCanal.RAMP_S:
		td = LairCanal.RAMP_D
	if s > LairCanal.BARGE_S - 45.0 and s < LairCanal.BARGE_S + 8.0:
		td = -2.5
	return td


## A ram from the player's boat: pushed toward the right bank, a wobble, a short burst away.
## Her Titanic pose on the bow for `secs` (0 = back to the wheel now).
func titanic(secs: float) -> void:
	titanic_t = secs
	if secs <= 0.0:
		titanic_w = 0.0
		if driver:
			driver.position = SEAT


func rammed() -> void:
	rams += 1
	titanic_t = 0.0                          # knocked back down to the wheel
	hit_t = 0.0
	lat_v = 5.0
	d = minf(d + BoatData.RAM_PUSH_D, LairCanal.HALF_W - BoatData.BEAM_HALF)
	burst_t = 1.4
	v += 4.0


## The last ram: she veers into the right bank and stops there nose up, steaming.
func crash() -> void:
	crashed = true
	crash_t = 0.0
	if steam:
		steam.emitting = true
	if spray:
		spray.emitting = false


func _apply_xf() -> void:
	if level == null:
		return
	var bob: float = 0.0 if airborne or crashed else sin(_bob_t * 2.1 + 0.7) * 0.05
	var pos: Vector3 = level.course_pos(s, d, air_h + bob)
	var wob: float = sin(hit_t * 22.0) * 0.18 * (1.0 - hit_t / 0.8) if hit_t >= 0.0 else 0.0
	var yaw: float = level.yaw_at(s) - atan2(lat_v, maxf(v, 4.0)) * 0.9 + wob
	var pitch: float = clampf(air_vy * 0.035, -0.3, 0.35) if airborne else (0.28 * clampf(crash_t, 0.0, 1.0) if crashed else 0.04)
	var roll: float = clampf(-lat_v * 0.03, -0.25, 0.25) + wob * 0.5
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)
	if spray and not crashed:
		spray.emitting = v > 6.0 and not airborne


## The Titanic layer over the driver (on the frames her RigAnimator ran).
func _process(_dt: float) -> void:
	if titanic_w <= 0.001 or _sk == null:
		return
	if _anim == null or int(_anim.get("_lod_skip")) == 1:
		CharacterBuilder._apply_bone_pose(_sk, TITANIC_POSE, titanic_w)
