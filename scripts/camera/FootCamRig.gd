# File: res://scripts/camera/FootCamRig.gd
# On-foot camera of a ThirdPersonController (Q1 camera director, spec 2026-10-29 Q1 "On foot" and "Melee and sword
# combat"). It drives the controller's own nodes, so everything that uses them keeps working: cam_pivot (top level, orbit
# centre and orientation from the controller's yaw / pitch), camera (child: x = shoulder, y = bob, z = distance),
# cam_ray (the collision probe: every system adds its camera exceptions to it, so all probes go through it).
#   - explore: pivot FOOT_HEIGHT above the feet on a critically damped follow (vertical softer), look-ahead in the move
#     direction, shoulder FOOT_SHOULDER right (a probe pulls it in at a wall on the right), distance FOOT_DIST with a
#     pull-in from 3 probes (centre, both sides) and from the player's view (rays from the head and the hips to the camera
#     spot; instant in, sprung out); close in, the shoulder offset gives way and with no room the camera cranes up;
#     the view converges on the player's line at the first body or wall straight ahead (else FOOT_CONVERGE; the crosshair =
#     the hip-fire line), sprint FOV, a small landing dip, a run bob;
#   - aim (controller.aim_blend): the Phase W over-the-shoulder pose (AIM_DISTANCE, AIM_SIDE, AIM_FOV);
#   - combat (hostile enemies of the controller's PlayerCombat within COMBAT_RANGE): the pivot on the 70/30 point toward the
#     target (the soft lock, else the nearest hostile in view; less when a wall pulls the camera in, so it stays
#     COMBAT_MIN_BEHIND behind the player), the distance by the enemy count, and auto-yaw (after
#     COMBAT_LOOK_IDLE_S without mouse look, at most COMBAT_YAW_RATE_DEG per second) that keeps the target and the next
#     attacker (winding up within COMBAT_VIEW_DEG of the view) in frame; attackers behind are left to the HUD markers;
#     with the back to a wall (less than COMBAT_SIDE_ROOM behind) it aims at a side view that frames both across;
#   - knocked down (SPLAT): the pivot follows the body and the camera rises DOWN_CRANE for a high angle;
#   - framing guard: when the pull-in, a knock-down or a steep pitch would push the player's head, chest or hips out of the
#     frame, the camera turns just enough (instant in, sprung back) to keep them GUARD_MARGIN inside (off while aiming);
#     in combat the target is kept in frame too where the player allows it; while the mouse looks around (and for
#     COMBAT_LOOK_IDLE_S after) the guard drops the target and every yaw turn: the mouse wins;
#   - position springs (follow, look-ahead, shift, dip) step in physics_step on the physics tick; collision, rotation, FOV
#     and the effects in update() once per rendered frame (no chase of a 60 Hz position above 60 Hz);
#   - the CameraDirector's punch / shake (fx_offset, fx_rot_deg, fx_fov) on top, plus the controller's own shake().
# Rays per rendered frame: ~9 through cam_ray (head, shoulder, 3 arm, 2-4 view); 1-3 more at 10 Hz in a fight (side view).
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
## Side view offset (rad) of the combat auto-yaw when the back is to a wall (0 = behind the player).
var side_yaw: float = 0.0
## Current distances (read by tests): the wanted full distance, the shoulder after its probe, the pulled-in distance.
var full_dist: float = CameraRules.FOOT_DIST
var side: float = CameraRules.FOOT_SHOULDER
var dist: float = CameraRules.FOOT_DIST
var trauma: float = 0.0
var last_auto_yaw_rate: float = 0.0       # rad/s of the last auto-yaw step (tests)
var _follow: CamSpring = CamSpring.new()
var _ahead: CamSpring = CamSpring.new()
var _shift: CamSpring = CamSpring.new()
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
var _down: Vector2 = Vector2.ZERO         # knock-down crane: x m, y spring velocity
var _anchor: Vector3 = Vector3.ZERO       # feet (or the fallen body) at the last spring step
var _room: Vector2 = Vector2(CameraRules.FOOT_DIST, 0.0)   # combat shift room: x m (down at once, up sprung), y v
var _conv: Vector2 = Vector2.ZERO         # convergence yaw: x rad, y spring velocity
var _conv_d: float = CameraRules.FOOT_CONVERGE
var _conv_q: PhysicsRayQueryParameters3D = null
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


## Position springs (follow, look-ahead, combat shift, landing dip, combat distance), stepped on the physics tick: the
## pivot moves exactly when the player does, so the camera never chases a 60 Hz position at a higher render rate.
## ThirdPersonController._physics_process calls it.
func physics_step(delta: float) -> void:
	if ctrl.cam_pivot == null:
		return
	_step_springs(maxf(delta, 0.0), false)


func _step_springs(dt: float, snap: bool) -> void:
	var c: ThirdPersonController = ctrl
	var feet: Vector3 = c.global_position
	# knocked down: follow the body (the hips), not the feet it fell from
	_anchor = feet
	if c.move_state == "SPLAT" and _resolve_bones():
		var hb: Vector3 = _bone_point(2)
		_anchor = Vector3(hb.x, feet.y, hb.z)
	var want: Vector3 = _anchor + Vector3.UP * CameraRules.FOOT_HEIGHT
	var hv := Vector3(c.velocity.x, 0.0, c.velocity.z)
	var ahead_t := Vector3.ZERO
	if not in_combat and hv.length_squared() > 0.04 and c.aim_blend < 0.99:
		ahead_t = hv.normalized() * CameraRules.FOOT_LOOK_AHEAD * clampf(hv.length() / ThirdPersonController.JOG_SPEED, 0.0, 1.0) * (1.0 - c.aim_blend)
	# the 70/30 focus: a shift toward the target, never so far that the camera would hang over the player (pulled in by
	# a wall, the camera keeps COMBAT_MIN_BEHIND behind the player; that room follows the distance down at once, up slowly)
	if snap or dist < _room.x:
		_room = Vector2(dist, 0.0)
	else:
		_room = CamSpring.damp(_room.x, _room.y, dist, CameraRules.COMBAT_ROOM_OMEGA, dt)
	var shift_t := Vector3.ZERO
	if in_combat and target != null and is_instance_valid(target):
		var tp: Vector3 = target.global_position
		shift_t = Vector3(tp.x - feet.x, 0.0, tp.z - feet.z) * CameraRules.COMBAT_SPLIT
		var room: float = maxf(0.0, _room.x - CameraRules.COMBAT_MIN_BEHIND)
		if shift_t.length() > room:
			shift_t = shift_t.normalized() * room
	var cd: float = CameraRules.combat_distance(combat_n) if in_combat else CameraRules.FOOT_DIST
	if snap:
		_shift.snap(shift_t)
		_ahead.snap(ahead_t)
		_follow.snap(want + Vector3(ahead_t.x, 0.0, ahead_t.z))
		_dip = Vector2.ZERO
		_combat_dist = cd
		_full_v = 0.0
		return
	_ahead.step(ahead_t, CameraRules.FOOT_AHEAD_OMEGA, dt)
	_shift.step(shift_t, CameraRules.COMBAT_SHIFT_OMEGA, dt)
	var p: Vector3 = _follow.pos
	var sx: Vector2 = CamSpring.damp(p.x, _follow.vel.x, want.x + _ahead.pos.x, CameraRules.FOOT_OMEGA, dt)
	var sz: Vector2 = CamSpring.damp(p.z, _follow.vel.z, want.z + _ahead.pos.z, CameraRules.FOOT_OMEGA, dt)
	var sy: Vector2 = CamSpring.damp(p.y, _follow.vel.y, want.y, CameraRules.FOOT_OMEGA_Y, dt)
	_follow.pos = Vector3(sx.x, sy.x, sz.x)
	_follow.vel = Vector3(sx.y, sy.y, sz.y)
	_dip = CamSpring.damp(_dip.x, _dip.y, 0.0, CameraRules.DIP_OMEGA, dt)
	var dd: Vector2 = CamSpring.damp(_combat_dist, _full_v, cd, CameraRules.COMBAT_DIST_OMEGA, dt)
	_combat_dist = dd.x
	_full_v = dd.y


## The camera's full pose this frame (rotation, collision, effects; once per rendered frame). snap = jump there
## (teleport, set_facing, build).
func update(delta: float, snap: bool) -> void:
	var c: ThirdPersonController = ctrl
	if c.cam_pivot == null or c.camera == null:
		return
	var dt: float = 0.0 if snap else maxf(delta, 0.0)
	var rdt: float = dt / maxf(Engine.time_scale, 0.01)
	_clock += rdt
	_look_idle += rdt
	_scan_t -= dt
	var scanned: bool = snap or _scan_t <= 0.0
	if scanned:
		_scan_t = CameraRules.COMBAT_SCAN_S
		_scan_combat()
	if in_combat and not snap and _look_idle >= CameraRules.COMBAT_LOOK_IDLE_S and c.controls_enabled and c.aim_blend < 0.5:
		_auto_yaw(dt)
	else:
		last_auto_yaw_rate = 0.0
	c.pitch = clampf(c.pitch, ThirdPersonController.PITCH_MIN, ThirdPersonController.PITCH_MAX)
	var basis := Basis.from_euler(Vector3(c.pitch, c.yaw, 0.0))
	if snap:
		_dist_v = 0.0
		_step_springs(0.0, true)
	var pivot: Vector3 = _follow.pos + _shift.pos + Vector3(0.0, _dip.x, 0.0)
	# never lift the pivot through a ceiling or leave it inside a wall: probe from the head
	var head: Vector3 = _anchor + Vector3.UP * minf(CameraRules.FOOT_HEIGHT, 1.5)
	var hp: float = _probe(head, pivot)
	if hp < INF:
		pivot = head + (pivot - head).normalized() * maxf(0.0, hp - CameraRules.PROBE_SIDE)
	c.cam_pivot.global_transform = Transform3D(basis, pivot)
	# shoulder: aim blend, then a probe to the right
	var want_side: float = lerpf(CameraRules.FOOT_SHOULDER, ThirdPersonController.AIM_SIDE, c.aim_blend)
	var right: Vector3 = basis.x
	var sp: float = _probe(pivot, pivot + right * (want_side + CameraRules.PROBE_SIDE))
	side = want_side if sp == INF else clampf(sp - CameraRules.PROBE_SIDE, 0.0, want_side)
	# the arm probes start at the full shoulder spot: nothing here depends on the last frame's distance (no feedback loop)
	var shoulder: Vector3 = pivot + right * side
	# distance: the full one (explore / combat / aim), then 3 probes back from the shoulder
	full_dist = lerpf(_combat_dist, ThirdPersonController.AIM_DISTANCE, c.aim_blend)
	var back: Vector3 = basis.z
	var reach: float = full_dist + CameraRules.PULL_MARGIN
	var hit: float = _probe(shoulder, shoulder + back * reach)
	var o_r: Vector3 = right * CameraRules.PROBE_SIDE
	hit = minf(hit, _probe(shoulder + o_r * 0.5, shoulder + o_r + back * reach))
	hit = minf(hit, _probe(shoulder - o_r * 0.5, shoulder - o_r + back * reach))
	var allowed: float = full_dist if hit == INF else clampf(hit - CameraRules.PULL_MARGIN, CameraRules.PULL_HARD_MIN, full_dist)
	# the actual camera spot (its shoulder offset shrinking close in, the crane) must be reachable along its own arm and
	# seen by the player (rays from the head and the hips, both ways); a hit pulls it in. All within this frame.
	var bones: bool = _resolve_bones()
	var head_p: Vector3 = _bone_point(0) if bones else pivot
	var hips_p: Vector3 = _bone_point(2) if bones else pivot - Vector3.UP * 0.6
	for pass_i: int in CameraRules.LOS_PASSES:
		var cp: Vector3 = _cam_point(pivot, right, back, allowed)
		var f: float = minf(_probe_frac(head_p, cp), _probe_frac(hips_p, cp))
		var se: float = side * smoothstep(CameraRules.CLOSE_SIDE_LO, CameraRules.CLOSE_SIDE_HI, allowed)
		if side - se > 0.05:
			var a0: Vector3 = pivot + right * se
			var la: float = a0.distance_to(cp)
			var ha: float = _probe(a0, cp + (cp - a0).normalized() * CameraRules.PULL_MARGIN) if la > 1e-3 else INF
			if ha < INF:
				f = minf(f, clampf((ha - CameraRules.PULL_MARGIN) / la, 0.0, 1.0))
		if f >= 1.0:
			break
		allowed = clampf(allowed * f - CameraRules.PULL_MARGIN * (1.0 - f), CameraRules.PULL_HARD_MIN, allowed)
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
	# close in: the shoulder offset gives way to a spot behind the head; no room behind: crane up (a probe stops it under
	# a ceiling), the guard then tilts the view down onto the player
	var side_eff: float = side * smoothstep(CameraRules.CLOSE_SIDE_LO, CameraRules.CLOSE_SIDE_HI, dist)
	# knocked down: a sprung rise to a high angle onto the fallen body and whoever stands over it
	var down_t: float = CameraRules.DOWN_CRANE if c.move_state == "SPLAT" else 0.0
	if snap:
		_down = Vector2(down_t, 0.0)
	else:
		_down = CamSpring.damp(_down.x, _down.y, down_t, CameraRules.DIP_OMEGA, dt)
	var crane: float = maxf(_crane(dist), _down.x)
	if crane > 0.0:
		var cpos: Vector3 = pivot + right * side_eff + back * dist
		var hc: float = _probe(cpos, cpos + Vector3.UP * (crane + CameraRules.PULL_MARGIN))
		if hc < INF:
			crane = maxf(0.0, hc - CameraRules.PULL_MARGIN)
	var local := Vector3(side_eff, bob, dist) + basis.inverse() * (Vector3.UP * crane)
	if scanned:                                              # with the 10 Hz scan
		_conv_d = _converge_dist(pivot, basis)
	var conv_t: float = atan2(side_eff, dist + _conv_d) * (1.0 - c.aim_blend)
	if snap:
		_conv = Vector2(conv_t, 0.0)
	else:
		_conv = CamSpring.damp(_conv.x, _conv.y, conv_t, CameraRules.FOOT_CONVERGE_OMEGA, dt)
	var conv: float = _conv.x
	_frame_guard(Transform3D(basis, pivot) * Transform3D(Basis(Vector3.UP, conv), local), cur, dt, snap)
	c.camera.position = local + off
	c.camera.rotation = Vector3(guard.x, guard.y + conv, 0.0) + rot * (PI / 180.0)


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
		var vlo: float = INF
		var vhi: float = -INF
		var hlo: float = INF
		var hhi: float = -INF
		for i: int in 3:
			var q: Vector3 = inv * (_bone_point(i) - cam_xf.origin)
			if q.z > -0.05:
				continue
			var av: float = atan2(q.y, -q.z)
			var ah: float = atan2(q.x, -q.z)
			vlo = minf(vlo, av)
			vhi = maxf(vhi, av)
			hlo = minf(hlo, ah)
			hhi = maxf(hhi, ah)
		# the combat target second: kept in frame too where the player allows it
		var tvlo: float = INF
		var tvhi: float = -INF
		var thlo: float = INF
		var thhi: float = -INF
		var looking: bool = _look_idle < CameraRules.COMBAT_LOOK_IDLE_S
		if in_combat and not looking and target != null and is_instance_valid(target):
			for h: float in [CameraFraming.FALLBACK_H[0] + CameraFraming.HEAD_UP, CameraFraming.FALLBACK_H[2]]:
				var qt: Vector3 = inv * (target.global_position + Vector3.UP * h - cam_xf.origin)
				if qt.z > -0.05:
					continue
				tvlo = minf(tvlo, atan2(qt.y, -qt.z))
				tvhi = maxf(tvhi, atan2(qt.y, -qt.z))
				thlo = minf(thlo, atan2(qt.x, -qt.z))
				thhi = maxf(thhi, atan2(qt.x, -qt.z))
		if vhi >= vlo:
			want = Vector2(CameraRules.guard_fit(vlo, vhi, lim_v, tvlo, tvhi), -CameraRules.guard_fit(hlo, hhi, lim_h, thlo, thhi)) * w
			if looking:
				want.y = 0.0                     # the mouse turns the view: the guard keeps only the body's height in frame
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


## Distance from the pivot to the first body or wall straight ahead of the view (people and cars count: the crosshair
## lands on them), clamped; FOOT_CONVERGE when nothing is there.
func _converge_dist(pivot: Vector3, basis: Basis) -> float:
	if not ctrl.is_inside_tree():
		return CameraRules.FOOT_CONVERGE
	if _conv_q == null:
		_conv_q = PhysicsRayQueryParameters3D.new()
		_conv_q.collide_with_areas = false
		_conv_q.exclude = [ctrl.get_rid()]
	_conv_q.from = pivot
	_conv_q.to = pivot - basis.z * CameraRules.FOOT_CONVERGE_MAX
	var h: Dictionary = ctrl.get_world_3d().direct_space_state.intersect_ray(_conv_q)
	if h.is_empty():
		return CameraRules.FOOT_CONVERGE
	return clampf(pivot.distance_to(h["position"]), CameraRules.FOOT_CONVERGE_MIN, CameraRules.FOOT_CONVERGE_MAX)


## Camera spot at distance d along the arm: the shoulder offset shrinking as it closes in, the crane.
func _cam_point(pivot: Vector3, right: Vector3, back: Vector3, d: float) -> Vector3:
	return pivot + right * (side * smoothstep(CameraRules.CLOSE_SIDE_LO, CameraRules.CLOSE_SIDE_HI, d)) + back * d + Vector3.UP * _crane(d)


static func _crane(d: float) -> float:
	return clampf((CameraRules.PULL_MIN - d) / CameraRules.PULL_MIN, 0.0, 1.0) * CameraRules.CRANE_UP


## World point of subject bone i (0 head centre, 1 chest, 2 hips); call after _resolve_bones().
func _bone_point(i: int) -> Vector3:
	var p: Vector3 = (_sk.global_transform * _sk.get_bone_global_pose(_bones[i])).origin
	if i == 0:
		p += _sk.global_basis.y.normalized() * CameraFraming.HEAD_UP
	return p


## Fraction (0..1) of the line from the subject point to the camera spot that is clear (1 = clear), through cam_ray: from
## the subject first (the nearest obstacle to it, where the camera must stop), then from the camera (a one-sided surface
## facing the camera hides the subject although a ray from the subject passes its back face).
func _probe_frac(subject: Vector3, cam_p: Vector3) -> float:
	var l: float = subject.distance_to(cam_p)
	if l < 1e-3:
		return 1.0
	var h: float = _probe(subject, cam_p)
	if h < INF:
		return clampf(h / l, 0.0, 1.0)
	var hc: float = _probe(cam_p, subject)
	return 1.0 if hc == INF else clampf((l - hc) / l, 0.0, 1.0)


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
	_pick_side()


## Back to a wall in a fight: when the room behind the player on the player -> target line is short, the auto-yaw aims at
## a side view (COMBAT_SIDE_DEG off that line, the side with more room), which frames both across. 10 Hz, 1-3 rays.
func _pick_side() -> void:
	if not in_combat or target == null or not is_instance_valid(target):
		side_yaw = 0.0
		return
	var feet: Vector3 = ctrl.global_position
	var dir := Vector3(target.global_position.x - feet.x, 0.0, target.global_position.z - feet.z)
	if dir.length_squared() < 0.04:
		return
	dir = dir.normalized()
	var origin: Vector3 = feet + Vector3.UP * CameraRules.FOOT_HEIGHT
	var reach: float = CameraRules.combat_distance(combat_n)
	var r0: float = minf(_probe(origin, origin - dir * reach), reach)
	if r0 >= CameraRules.COMBAT_SIDE_ROOM:
		side_yaw = 0.0
		return
	var best: float = side_yaw
	var best_r: float = r0 if is_zero_approx(side_yaw) else minf(_probe(origin, origin - dir.rotated(Vector3.UP, side_yaw) * reach), reach)
	for sgn: float in [1.0, -1.0]:
		var a: float = sgn * deg_to_rad(CameraRules.COMBAT_SIDE_DEG)
		if is_equal_approx(a, side_yaw):
			continue
		var r: float = minf(_probe(origin, origin - dir.rotated(Vector3.UP, a) * reach), reach)
		if r > best_r + 0.5:
			best = a
			best_r = r
	side_yaw = best


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
	var want: float = atan2(-dir.x, -dir.z) + side_yaw
	var before: float = ctrl.yaw
	ctrl.yaw = CameraRules.auto_yaw_step(before, want, dt)
	last_auto_yaw_rate = absf(wrapf(ctrl.yaw - before, -PI, PI)) / dt
