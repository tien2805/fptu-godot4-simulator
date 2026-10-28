# File: res://scripts/camera/FootCamRig.gd
# On-foot camera of a ThirdPersonController (Q1 camera director, spec 2026-10-29 Q1 "On foot" and "Melee and sword
# combat"). It drives the controller's own nodes, so everything that uses them keeps working: cam_pivot (top level, orbit
# centre and orientation from the controller's yaw / pitch), camera (child: x = shoulder, y = bob, z = distance),
# cam_ray (the collision probe: every system adds its camera exceptions to it, so all probes go through it).
#   - explore: pivot FOOT_HEIGHT above the feet on a critically damped follow (vertical softer), look-ahead in the move
#     direction, shoulder FOOT_SHOULDER right (a probe pulls it in at a wall on the right), distance FOOT_DIST with a
#     pull-in from 4 probes (centre, both sides, top; instant in, sprung out), sprint FOV, a small landing dip, a run bob;
#   - aim (controller.aim_blend): the Phase W over-the-shoulder pose (AIM_DISTANCE, AIM_SIDE, AIM_FOV);
#   - combat (hostile enemies of the controller's PlayerCombat within COMBAT_RANGE): the pivot on the 70/30 point toward the
#     target (the soft lock, else the nearest hostile in view), the distance by the enemy count, and auto-yaw (after
#     COMBAT_LOOK_IDLE_S without mouse look, at most COMBAT_YAW_RATE_DEG per second) that keeps the target and the next
#     attacker (winding up within COMBAT_VIEW_DEG of the view) in frame; attackers behind are left to the HUD markers;
#   - framing guard: when the pull-in, a knock-down or a steep pitch would push the player's head, chest or hips out of the
#     frame, the camera turns just enough (instant in, sprung back) to keep them GUARD_MARGIN inside (off while aiming);
#   - the CameraDirector's punch / shake (fx_offset, fx_rot_deg, fx_fov) on top, plus the controller's own shake().
# The PlayerCombat is found through controller.jump_filter (PlayerCombat.setup binds its try_dodge there) and read by duck
# typing (enemies, lock; enemies: is_hostile, is_down, incoming), so neither script depends on the other.
class_name FootCamRig
extends RefCounted

var ctrl: ThirdPersonController
## Combat state (read by tests): enemies within COMBAT_RANGE, the framed target, the next attacker, the combat flag.
var combat_n: int = 0
var target: Node3D = null
var attacker: Node3D = null
var in_combat: bool = false
## Current distances (read by tests): the wanted full distance, the shoulder after its probe, the pulled-in distance.
var full_dist: float = CameraRules.FOOT_DIST
var side: float = CameraRules.FOOT_SHOULDER
var dist: float = CameraRules.FOOT_DIST
var trauma: float = 0.0
var last_auto_yaw_rate: float = 0.0       # rad/s of the last auto-yaw step (tests)
var _follow: CamSpring = CamSpring.new()
var _ahead: CamSpring = CamSpring.new()
var _dip: Vector2 = Vector2.ZERO          # x offset (m, negative = down), v
var _dist_v: float = 0.0
var _full_v: float = 0.0
var _combat_dist: float = CameraRules.FOOT_DIST
var _scan_t: float = 0.0
var _look_idle: float = 99.0
var _bob_phase: float = 0.0
var _clock: float = 0.0
var _director: CameraDirector = null
var _director_t: float = 0.0
var _last_fx_fov: float = 0.0
## Framing guard turn (pitch, yaw; rad) of the last frame (tests).
var guard: Vector2 = Vector2.ZERO
var _guard_v: Vector2 = Vector2.ZERO
var _sk: Skeleton3D = null
var _bones: PackedInt32Array = PackedInt32Array()


func _init(c: ThirdPersonController) -> void:
	ctrl = c


## Mouse look or the orbit keys this frame: auto-yaw waits COMBAT_LOOK_IDLE_S.
func look_input() -> void:
	_look_idle = 0.0


## Landing dip of the pivot by landing kind (LAND_SOFT, LAND_ROLL, SPLAT).
func dip(kind: String) -> void:
	var depth: float = CameraRules.DIP_SOFT
	if kind == "LAND_ROLL":
		depth = CameraRules.DIP_ROLL
	elif kind == "SPLAT":
		depth = CameraRules.DIP_SPLAT
	_dip.y -= depth * CameraRules.DIP_OMEGA * exp(1.0)


func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t, 0.0, 1.0)


## The camera's full pose this frame. snap = jump there (teleport, set_facing, build).
func update(delta: float, snap: bool) -> void:
	var c: ThirdPersonController = ctrl
	if c.cam_pivot == null or c.camera == null:
		return
	var dt: float = 0.0 if snap else maxf(delta, 0.0)
	var rdt: float = dt / maxf(Engine.time_scale, 0.01)
	_clock += rdt
	_look_idle += rdt
	_scan_t -= dt
	if snap or _scan_t <= 0.0:
		_scan_t = CameraRules.COMBAT_SCAN_S
		_scan_combat()
	if in_combat and not snap and _look_idle >= CameraRules.COMBAT_LOOK_IDLE_S and c.controls_enabled and c.aim_blend < 0.5:
		_auto_yaw(dt)
	else:
		last_auto_yaw_rate = 0.0
	c.pitch = clampf(c.pitch, ThirdPersonController.PITCH_MIN, ThirdPersonController.PITCH_MAX)
	var basis := Basis.from_euler(Vector3(c.pitch, c.yaw, 0.0))
	# pivot: follow spring on the feet + height, look-ahead, the 70/30 combat focus, the landing dip
	var feet: Vector3 = c.global_position
	var want: Vector3 = feet + Vector3.UP * CameraRules.FOOT_HEIGHT
	var hv := Vector3(c.velocity.x, 0.0, c.velocity.z)
	var ahead_t := Vector3.ZERO
	if not in_combat and hv.length_squared() > 0.04 and c.aim_blend < 0.99:
		ahead_t = hv.normalized() * CameraRules.FOOT_LOOK_AHEAD * clampf(hv.length() / ThirdPersonController.JOG_SPEED, 0.0, 1.0) * (1.0 - c.aim_blend)
	if in_combat and target != null and is_instance_valid(target):
		var tp: Vector3 = target.global_position
		want += Vector3(tp.x - feet.x, 0.0, tp.z - feet.z) * CameraRules.COMBAT_SPLIT
	if snap:
		_ahead.snap(ahead_t)
		_follow.snap(want)
		_dip = Vector2.ZERO
		_combat_dist = CameraRules.combat_distance(combat_n) if in_combat else CameraRules.FOOT_DIST
		_dist_v = 0.0
	else:
		_ahead.step(ahead_t, CameraRules.FOOT_AHEAD_OMEGA, dt)
		var p: Vector3 = _follow.pos
		var hz := Vector2(p.x, p.z)
		var hw := Vector2(want.x + _ahead.pos.x, want.z + _ahead.pos.z)
		var sx: Vector2 = CamSpring.damp(hz.x, _follow.vel.x, hw.x, CameraRules.FOOT_OMEGA, dt)
		var sz: Vector2 = CamSpring.damp(hz.y, _follow.vel.z, hw.y, CameraRules.FOOT_OMEGA, dt)
		var sy: Vector2 = CamSpring.damp(p.y, _follow.vel.y, want.y, CameraRules.FOOT_OMEGA_Y, dt)
		_follow.pos = Vector3(sx.x, sy.x, sz.x)
		_follow.vel = Vector3(sx.y, sy.y, sz.y)
		_dip = CamSpring.damp(_dip.x, _dip.y, 0.0, CameraRules.DIP_OMEGA, dt)
		var cd: float = CameraRules.combat_distance(combat_n) if in_combat else CameraRules.FOOT_DIST
		var dd: Vector2 = CamSpring.damp(_combat_dist, _full_v, cd, CameraRules.COMBAT_DIST_OMEGA, dt)
		_combat_dist = dd.x
		_full_v = dd.y
	var pivot: Vector3 = _follow.pos + Vector3(0.0, _dip.x, 0.0)
	# never lift the pivot through a ceiling or leave it inside a wall: probe from the head
	var head: Vector3 = feet + Vector3.UP * minf(CameraRules.FOOT_HEIGHT, 1.5)
	var hp: float = _probe(head, pivot)
	if hp < INF:
		pivot = head + (pivot - head).normalized() * maxf(0.0, hp - CameraRules.PROBE_SIDE)
	c.cam_pivot.global_transform = Transform3D(basis, pivot)
	# shoulder: aim blend, then a probe to the right
	var want_side: float = lerpf(CameraRules.FOOT_SHOULDER, ThirdPersonController.AIM_SIDE, c.aim_blend)
	var right: Vector3 = basis.x
	var sp: float = _probe(pivot, pivot + right * (want_side + CameraRules.PROBE_SIDE))
	side = want_side if sp == INF else clampf(sp - CameraRules.PROBE_SIDE, 0.0, want_side)
	var shoulder: Vector3 = pivot + right * side
	# distance: the full one (explore / combat / aim), then 4 probes back from the shoulder
	full_dist = lerpf(_combat_dist, ThirdPersonController.AIM_DISTANCE, c.aim_blend)
	var back: Vector3 = basis.z
	var up: Vector3 = basis.y
	var reach: float = full_dist + CameraRules.PULL_MARGIN
	var hit: float = _probe(shoulder, shoulder + back * reach)
	var o_r: Vector3 = right * CameraRules.PROBE_SIDE
	var o_u: Vector3 = up * CameraRules.PROBE_SIDE
	hit = minf(hit, _probe(shoulder + o_r * 0.5, shoulder + o_r + back * reach))
	hit = minf(hit, _probe(shoulder - o_r * 0.5, shoulder - o_r + back * reach))
	hit = minf(hit, _probe(shoulder + o_u * 0.5, shoulder + o_u + back * reach))
	var allowed: float = full_dist if hit == INF else clampf(hit - CameraRules.PULL_MARGIN, CameraRules.PULL_HARD_MIN, full_dist)
	if snap or allowed < dist:
		dist = allowed
		_dist_v = 0.0
	else:
		var dv: Vector2 = CamSpring.damp(dist, _dist_v, allowed, CameraRules.PULL_OUT_OMEGA, dt)
		dist = minf(dv.x, allowed)
		_dist_v = dv.y
	# effects: run bob, own shake, director punch / shake
	var bob: float = 0.0
	_bob_phase = fmod(_bob_phase + dt * TAU * c.horizontal_speed / 2.6, TAU)
	if c.move_state == "GROUND" and c.horizontal_speed > ThirdPersonController.JOG_SPEED - 0.5:
		bob = sin(_bob_phase) * CameraRules.FOOT_BOB * clampf(c.horizontal_speed / ThirdPersonController.SPRINT_SPEED, 0.0, 1.0)
	trauma = maxf(0.0, trauma - CameraRules.SHAKE_DECAY * rdt)
	var k: float = trauma * trauma
	var off := Vector3(CameraRules.shake_noise(_clock, 5), CameraRules.shake_noise(_clock, 6), 0.0) * (CameraRules.SHAKE_M * k)
	var rot := Vector3(CameraRules.shake_noise(_clock, 7), CameraRules.shake_noise(_clock, 8), 0.0) * (CameraRules.SHAKE_DEG * k)
	var fx_fov: float = 0.0
	var d: CameraDirector = _find_director(rdt)
	if d != null:
		off += d.fx_offset
		rot += d.fx_rot_deg
		fx_fov = d.fx_fov
	var sprinting: bool = c.is_sprinting and c.horizontal_speed > ThirdPersonController.JOG_SPEED + 0.5
	var base_fov: float = lerpf(CameraRules.FOOT_FOV, ThirdPersonController.AIM_FOV, c.aim_blend) + (CameraRules.FOOT_SPRINT_FOV if sprinting else 0.0)
	var cur: float = c.camera.fov - _last_fx_fov
	cur = base_fov if snap else lerpf(cur, base_fov, 1.0 - exp(-CameraRules.FOOT_FOV_EASE * dt))
	_last_fx_fov = fx_fov
	c.camera.fov = cur + fx_fov
	# no room behind: crane up (a probe stops it under a ceiling), the guard then tilts the view down onto the player
	var crane: float = clampf((CameraRules.PULL_MIN - dist) / CameraRules.PULL_MIN, 0.0, 1.0) * CameraRules.CRANE_UP
	if crane > 0.0:
		var cpos: Vector3 = shoulder + back * dist
		var hc: float = _probe(cpos, cpos + Vector3.UP * (crane + CameraRules.PULL_MARGIN))
		if hc < INF:
			crane = maxf(0.0, hc - CameraRules.PULL_MARGIN)
	var local := Vector3(side, bob, dist) + basis.inverse() * (Vector3.UP * crane)
	_frame_guard(Transform3D(basis, pivot) * Transform3D(Basis.IDENTITY, local), cur, dt, snap)
	c.camera.position = local + off
	c.camera.rotation = Vector3(guard.x, guard.y, 0.0) + rot * (PI / 180.0)


## Framing guard (see the header): from the camera pose without it, the turn that keeps the player's head, chest and hips
## inside the GUARD_MARGIN area; instant toward a bigger turn, sprung back toward a smaller one.
func _frame_guard(cam_xf: Transform3D, fov: float, dt: float, snap: bool) -> void:
	var want := Vector2.ZERO
	var w: float = 1.0 - ctrl.aim_blend
	if w > 0.01 and _resolve_bones() and ctrl.camera.is_inside_tree():
		var vs: Vector2 = ctrl.camera.get_viewport().get_visible_rect().size
		var tv: float = tan(deg_to_rad(fov) * 0.5)
		var shrink: float = 1.0 - 2.0 * CameraRules.GUARD_MARGIN
		var lim_v: float = atan(tv * shrink)
		var lim_h: float = atan(tv * (vs.x / maxf(vs.y, 1.0)) * shrink)
		var inv: Basis = cam_xf.basis.inverse()
		var up: Vector3 = _sk.global_basis.y.normalized() * CameraFraming.HEAD_UP
		var vlo: float = INF
		var vhi: float = -INF
		var hlo: float = INF
		var hhi: float = -INF
		for i: int in 3:
			var p: Vector3 = (_sk.global_transform * _sk.get_bone_global_pose(_bones[i])).origin
			if i == 0:
				p += up
			var q: Vector3 = inv * (p - cam_xf.origin)
			if q.z > -0.05:
				continue
			var av: float = atan2(q.y, -q.z)
			var ah: float = atan2(q.x, -q.z)
			vlo = minf(vlo, av)
			vhi = maxf(vhi, av)
			hlo = minf(hlo, ah)
			hhi = maxf(hhi, ah)
		if vhi >= vlo:
			want = Vector2(CameraRules.guard_fit(vlo, vhi, lim_v), -CameraRules.guard_fit(hlo, hhi, lim_h)) * w
	if snap:
		guard = want
		_guard_v = Vector2.ZERO
		return
	for k: int in 2:
		var g: float = guard[k]
		var t: float = want[k]
		if absf(t) >= absf(g) or signf(t) != signf(g):
			guard[k] = t
			_guard_v[k] = 0.0
		else:
			var r: Vector2 = CamSpring.damp(g, _guard_v[k], t, CameraRules.GUARD_RELAX_OMEGA, dt)
			guard[k] = r.x
			_guard_v[k] = r.y


func _resolve_bones() -> bool:
	if _sk != null and is_instance_valid(_sk) and _sk.is_inside_tree() and _bones.size() == 3:
		return true
	_sk = CameraFraming.skeleton_of(ctrl.model) if ctrl.model != null else null
	_bones.clear()
	if _sk == null or not _sk.is_inside_tree():
		_sk = null
		return false
	for bn: String in CameraFraming.BONES:
		var b: int = _sk.find_bone(bn)
		if b < 0:
			_sk = null
			_bones.clear()
			return false
		_bones.append(b)
	return true


## Ray through the controller's cam_ray (its exceptions: the player, people, cars, enemies, invisible walls). Distance to the
## first hit from `from` toward `to`, INF when clear.
func _probe(from: Vector3, to: Vector3) -> float:
	var r: RayCast3D = ctrl.cam_ray
	if r == null or not r.is_inside_tree() or not r.enabled:
		return INF
	r.global_transform = Transform3D(Basis.IDENTITY, from)
	r.target_position = to - from
	r.force_raycast_update()
	if r.is_colliding():
		return from.distance_to(r.get_collision_point())
	return INF


func _find_director(rdt: float) -> CameraDirector:
	if _director != null and is_instance_valid(_director) and _director.is_inside_tree():
		return _director
	_director = null
	_director_t -= rdt
	if _director_t > 0.0:
		return null
	_director_t = 0.5
	_director = CameraDirector.live()
	if _director == null and ctrl.is_inside_tree():
		CameraDirector.ensure(ctrl)
	return _director


# ---------------------------------------------------------------------------
# COMBAT FRAMING
# ---------------------------------------------------------------------------
func _combat_obj() -> Object:
	var f: Callable = ctrl.jump_filter
	if not f.is_valid():
		return null
	var o: Object = f.get_object()
	if o == null or not is_instance_valid(o) or not ("enemies" in o):
		return null
	return o


func _scan_combat() -> void:
	combat_n = 0
	target = null
	attacker = null
	var o: Object = _combat_obj()
	if o == null:
		in_combat = false
		return
	var feet: Vector3 = ctrl.global_position
	var fwd: Vector3 = -ctrl.cam_pivot.global_basis.z if ctrl.cam_pivot else ctrl.facing_dir()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else ctrl.facing_dir()
	var cos_view: float = cos(deg_to_rad(CameraRules.COMBAT_VIEW_DEG))
	var lock: Variant = o.get("lock")
	var best_d: float = INF
	var att_d: float = INF
	for e: Variant in o.get("enemies"):
		if not _hostile(e):
			continue
		var n: Node3D = e
		var to := Vector3(n.global_position.x - feet.x, 0.0, n.global_position.z - feet.z)
		var d: float = to.length()
		if d > CameraRules.COMBAT_RANGE:
			continue
		combat_n += 1
		var in_view: bool = d < 0.01 or fwd.dot(to / d) >= cos_view
		if in_view and d < best_d:
			best_d = d
			target = n
		if in_view and n.has_method("incoming") and int(n.call("incoming")) > 0 and d < att_d:
			att_d = d
			attacker = n
	if lock is Node3D and _hostile(lock):
		target = lock
	if attacker == target:
		attacker = null
	in_combat = combat_n > 0


static func _hostile(e: Variant) -> bool:
	if e == null or not is_instance_valid(e) or not (e is Node3D) or not (e as Node).is_inside_tree():
		return false
	var o: Object = e
	if o.has_method("is_hostile") and not bool(o.call("is_hostile")):
		return false
	if o.has_method("is_down") and bool(o.call("is_down")):
		return false
	return true


## Turn the camera yaw so the target (and the next attacker) sit in frame: the direction from the player to the target
## (averaged with the attacker's), the dead zone left alone, min(gain x error, the 90 deg/s cap).
func _auto_yaw(dt: float) -> void:
	last_auto_yaw_rate = 0.0
	if target == null or not is_instance_valid(target) or dt <= 0.0:
		return
	var feet: Vector3 = ctrl.global_position
	var dir := Vector3(target.global_position.x - feet.x, 0.0, target.global_position.z - feet.z)
	if dir.length_squared() < 0.04:
		return
	dir = dir.normalized()
	if attacker != null and is_instance_valid(attacker):
		var ad := Vector3(attacker.global_position.x - feet.x, 0.0, attacker.global_position.z - feet.z)
		if ad.length_squared() > 0.04:
			var mid: Vector3 = dir + ad.normalized()
			if mid.length_squared() > 0.01:
				dir = mid.normalized()
	var want: float = atan2(-dir.x, -dir.z)
	var before: float = ctrl.yaw
	ctrl.yaw = CameraRules.auto_yaw_step(before, want, dt)
	last_auto_yaw_rate = absf(wrapf(ctrl.yaw - before, -PI, PI)) / dt
