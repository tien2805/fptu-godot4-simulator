# File: res://scripts/camera/CameraDirector.gd
# The Q1 camera director (spec 2026-10-29 section 3 Q1): one node per scene, in the group "camera_director", that owns the
# shared camera effects and the director cuts. The gameplay cameras keep their own nodes and rigs (FootCamRig on the
# ThirdPersonController, BikeCamRig on the PlayerBike) and follow CameraRules; this node adds what every camera shares.
#
# ===== API (other streams: get_tree().get_first_node_in_group("camera_director") + has_method guards) =====
#   punch(strength, dir = ZERO)   impact kick: strength ~0.15 light, 0.35 heavy, 0.6 finisher; dir (world) = the way the
#                                 hit pushes; the camera kicks along it (camera space), turns a few degrees toward it and
#                                 dips its FOV, then springs back (critically damped, ~0.15 s). On the bike, a punch with a
#                                 dir is also the 0.12 s whip toward it (PlayerBike.cam_whip).
#   shake(trauma)                 trauma 0..1 adds up (capped at 1) and decays at SHAKE_DECAY per real second; the shake
#                                 amplitude is trauma squared (smooth noise, so small trauma is almost nothing).
#   preview_cut(target, secs=0.6) readability rule: a director camera shows the target (a hazard ahead) from the viewer's
#                                 side, angle picked by an occlusion test, pushing in a little; slow motion CUT_SCALE while
#                                 it runs; then the previous camera. false when it cannot run (no target, no camera).
#   slowmo_orbit(target, secs=0.5) last-enemy knockouts: slow motion ORBIT_SCALE and an orbit of ORBIT_DEG round the target
#                                 (the clear side, by occlusion test; from a start spot that sees the target, the radius
#                                 shrunk toward it when a wall is there; false below ORBIT_R_MIN, the gameplay camera
#                                 stays), lasting as long as a running slow motion of another owner (owner_remaining, else
#                                 ORBIT_OWNED_S), then the previous camera and normal time.
#   cutting() / cut_kind ("" | "preview" | "orbit"), cam (the director camera, made on the first cut), cuts / orbits.
# Slow motion only through RadialWheel.scale_owner: never over another owner (the cut still plays, in normal time) and the
# scale goes back to 1.0 only while this node owns it. A pause (cinematic), a disable or leaving the tree ends a cut at once.
# Rigs read fx_offset (camera-local m), fx_rot_deg (pitch, yaw, roll) and fx_fov every frame; a camera they drive carries the
# meta META_FX (its owner). Any other current camera gets shake() through GameFX.shake (h / v offsets) instead.
# Installation: CameraDirector.ensure(node) (camera owners call it) adds one, deferred, to the current scene (else the
# node's parent); CameraDirector.current is the live one. Autoloads are reached only through /root paths.
# ===========================================
class_name CameraDirector
extends Node

const GROUP: String = "camera_director"
const META_FX: String = "director_fx"
const META_CUT: String = "director_cut"

static var current: CameraDirector = null
static var _pending: CameraDirector = null

var trauma: float = 0.0
var fx_offset: Vector3 = Vector3.ZERO
var fx_rot_deg: Vector3 = Vector3.ZERO
var fx_fov: float = 0.0
var cam: Camera3D = null
var cut_kind: String = ""
var cuts: int = 0
var orbits: int = 0
var punches: int = 0
## Real seconds since the start (noise clock).
var clock: float = 0.0
var _punch: CamSpring = CamSpring.new()   # offset (camera space)
var _punch_rot: CamSpring = CamSpring.new()   # deg
var _punch_fov: Vector2 = Vector2.ZERO   # x, v
var _cut_t: float = 0.0
var _cut_len: float = 0.0
var _cut_target: Node3D = null
var _cut_prev: Camera3D = null
var _last_prev: Camera3D = null          # the camera before the last cut (a stale restore by someone else goes back to it)
var _cut_off: Vector3 = Vector3.ZERO     # preview: camera offset from the target point
var _cut_look: Vector3 = Vector3.ZERO    # last look point (a freed target keeps the last one)
var _orbit_a0: float = 0.0
var _orbit_sign: float = 1.0
var _orbit_sweep: float = 0.0
var _orbit_r: float = CameraRules.ORBIT_R
var _owns_time: bool = false
var _excl: Array[RID] = []


static func ensure(from: Node) -> CameraDirector:
	if current != null and is_instance_valid(current) and current.is_inside_tree():
		return current
	if _pending != null and is_instance_valid(_pending) and not _pending.is_queued_for_deletion():
		return _pending
	if from == null or not is_instance_valid(from) or not from.is_inside_tree():
		return null
	var host: Node = from.get_tree().current_scene
	if host == null or not (host == from or host.is_ancestor_of(from)):
		host = from.get_parent() if from.get_parent() != null else from.get_tree().root
	var d := CameraDirector.new()
	d.name = "CameraDirector"
	_pending = d
	host.add_child.call_deferred(d)
	return d


## The live director (null when none is in the tree yet).
static func live() -> CameraDirector:
	if current != null and is_instance_valid(current) and current.is_inside_tree():
		return current
	return null


func _init() -> void:
	process_priority = -100              # before the rigs' _process: they read this frame's fx


func _enter_tree() -> void:
	add_to_group(GROUP)
	current = self
	if _pending == self:
		_pending = null


func _exit_tree() -> void:
	_end_cut(true)
	if current == self:
		current = null
	if _pending == self:
		_pending = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_DISABLED:
		_end_cut(true)
	elif what == NOTIFICATION_PREDELETE:
		if current == self:
			current = null
		if _pending == self:
			_pending = null


# ---------------------------------------------------------------------------
# SHARED EFFECTS
# ---------------------------------------------------------------------------
func punch(strength: float, dir: Vector3 = Vector3.ZERO) -> void:
	var s: float = clampf(strength, 0.0, 1.5)
	if s <= 0.0:
		return
	punches += 1
	var view: Camera3D = _view()
	var local := Vector3(0.0, 0.0, -1.0)    # no dir: a push-in
	if dir.length_squared() > 1e-6 and view != null:
		local = (view.global_basis.inverse() * dir.normalized()).normalized()
	var w: float = CameraRules.PUNCH_OMEGA
	var k: float = w * exp(1.0)             # impulse that peaks at 1 after 1 / w
	_punch.impulse(local * CameraRules.PUNCH_M * s * k)
	# turn toward the push (yaw by its side, pitch up a touch) and dip the FOV
	_punch_rot.impulse(Vector3(CameraRules.PUNCH_DEG * s * 0.6, -local.x * CameraRules.PUNCH_DEG * s, local.x * CameraRules.PUNCH_DEG * s * 0.5) * k)
	_punch_fov.y += CameraRules.PUNCH_FOV * s * k
	if view != null and not view.has_meta(META_FX):
		_gamefx_shake(s * 0.5)
	if dir.length_squared() > 1e-6 and view != null and view.has_meta(META_FX):
		var owner_obj: Object = view.get_meta(META_FX)
		if owner_obj != null and is_instance_valid(owner_obj) and owner_obj.has_method("cam_whip"):
			owner_obj.call("cam_whip", dir)


func shake(t: float) -> void:
	if t <= 0.0:
		return
	trauma = clampf(trauma + t, 0.0, 1.0)
	var view: Camera3D = _view()
	if view != null and not view.has_meta(META_FX):
		_gamefx_shake(t)


func cutting() -> bool:
	return cut_kind != ""


func _view() -> Camera3D:
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	return vp.get_camera_3d() if vp else null


func _gamefx_shake(t: float) -> void:
	var gfx: Node = get_node_or_null("/root/GameFX")
	if gfx != null and gfx.has_method("shake"):
		gfx.call("shake", t)


func _process(delta: float) -> void:
	var rdt: float = minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
	clock += rdt
	trauma = maxf(0.0, trauma - CameraRules.SHAKE_DECAY * rdt)
	var k: float = trauma * trauma
	var sh_off := Vector3.ZERO
	var sh_rot := Vector3.ZERO
	if k > 0.0:
		sh_off = Vector3(CameraRules.shake_noise(clock, 0), CameraRules.shake_noise(clock, 1), 0.0) * (CameraRules.SHAKE_M * k)
		sh_rot = Vector3(CameraRules.shake_noise(clock, 2), CameraRules.shake_noise(clock, 3), CameraRules.shake_noise(clock, 4) * 1.5) * (CameraRules.SHAKE_DEG * k)
	var w: float = CameraRules.PUNCH_OMEGA
	_punch.step(Vector3.ZERO, w, rdt)
	_punch_rot.step(Vector3.ZERO, w, rdt)
	_punch_fov = CamSpring.damp(_punch_fov.x, _punch_fov.y, 0.0, w, rdt)
	fx_offset = sh_off + _punch.pos
	fx_rot_deg = sh_rot + _punch_rot.pos
	fx_fov = _punch_fov.x
	if cut_kind != "":
		_tick_cut(rdt)
	elif cam != null and cam.current:
		_hand_back()                         # someone restored the director camera after its cut: back to the gameplay one


func _hand_back() -> void:
	if _last_prev != null and is_instance_valid(_last_prev) and _last_prev.is_inside_tree():
		_last_prev.make_current()
	else:
		cam.clear_current(true)


# ---------------------------------------------------------------------------
# DIRECTOR CUTS
# ---------------------------------------------------------------------------
func preview_cut(target: Node3D, secs: float = 0.6) -> bool:
	var view: Camera3D = _view()
	if not _cut_ready(target, view):
		return false
	var look: Vector3 = _look_point(target)
	var away: Vector3 = view.global_position - look
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.BACK
	var cands: Array[Vector3] = []
	for deg: float in [0.0, CameraRules.CUT_SIDE_DEG, -CameraRules.CUT_SIDE_DEG]:
		var d: Vector3 = away.rotated(Vector3.UP, deg_to_rad(deg))
		cands.append(look + d * CameraRules.CUT_DIST + Vector3.UP * CameraRules.CUT_UP)
	cands.append(look + away * (CameraRules.CUT_DIST * 0.6) + Vector3.UP * (CameraRules.CUT_UP * 2.0))
	var i: int = CameraFraming.pick(_space(), cands, _cut_points(target, look), _excl_for(target))
	_begin_cut("preview", target, view, secs)
	_cut_off = cands[maxi(i, 0)] - look
	_cut_look = look
	cam.fov = CameraRules.CUT_FOV
	_slow(CameraRules.CUT_SCALE)
	cuts += 1
	_tick_cut(0.0)
	return true


func slowmo_orbit(target: Node3D, secs: float = 0.5) -> bool:
	var view: Camera3D = _view()
	if not _cut_ready(target, view):
		return false
	var look: Vector3 = _look_point(target)
	var away: Vector3 = view.global_position - look
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.BACK
	var a0: float = atan2(away.x, away.z)
	var pts: PackedVector3Array = _cut_points(target, look)
	var excl: Array[RID] = _excl_for(target)
	var space: PhysicsDirectSpaceState3D = _space()
	# the start spot must see the target and not be in a wall; else the radius shrinks to the clear distance toward it,
	# and below ORBIT_R_MIN the orbit is refused (the gameplay camera stays)
	var r: float = CameraRules.ORBIT_R
	if not CameraFraming.view_ok(space, _orbit_pos(look, a0, r), pts, excl):
		var v: Vector3 = _orbit_pos(look, a0, r) - look
		var f: float = _clear_frac(space, look, look + v, excl)
		r = (v.length() * f - CameraRules.PULL_MARGIN) * (r / v.length())
		if r < CameraRules.ORBIT_R_MIN or not CameraFraming.view_ok(space, _orbit_pos(look, a0, r), pts, excl):
			return false
	var best_sign: float = 1.0
	var best_sweep: float = 0.0
	for sgn: float in [1.0, -1.0]:
		var sweep: float = 0.0
		for step: int in range(1, 4):         # the arc at 1/3, 2/3 and the end
			var a: float = a0 + sgn * deg_to_rad(CameraRules.ORBIT_DEG) * float(step) / 3.0
			if not CameraFraming.view_ok(space, _orbit_pos(look, a, r), pts, excl):
				break
			sweep = deg_to_rad(CameraRules.ORBIT_DEG) * float(step) / 3.0
		if sweep > best_sweep:
			best_sweep = sweep
			best_sign = sgn
	# as long as the slow motion that is running (an Impact clock's), at least secs
	var length: float = secs
	var owner_obj: Object = RadialWheel.scale_owner
	if owner_obj != null and owner_obj != self and is_instance_valid(owner_obj):
		var rem: float = owner_remaining(owner_obj)
		length = maxf(secs, rem if rem > 0.0 else CameraRules.ORBIT_OWNED_S)
	_begin_cut("orbit", target, view, length)
	_orbit_a0 = a0
	_orbit_sign = best_sign
	_orbit_sweep = best_sweep              # 0 = a held shot from the clear start (never swings into a wall)
	_orbit_r = r
	_cut_look = look
	cam.fov = CameraRules.ORBIT_FOV
	_slow(CameraRules.ORBIT_SCALE)
	orbits += 1
	_tick_cut(0.0)
	return true


## Real seconds left of the slow motion a time-scale owner runs: its slowmo_remaining() when it has one, else an Impact
## clock's frame counters; -1 when unknown.
static func owner_remaining(o: Object) -> float:
	if o == null or not is_instance_valid(o):
		return -1.0
	if o.has_method("slowmo_remaining"):
		return float(o.call("slowmo_remaining"))
	var se: Variant = o.get("_slow_end")
	var sf: Variant = o.get("_slow_frames")
	var he: Variant = o.get("_hs_end")
	if se is int and sf is int and he is int:
		var end: int = -1
		if int(se) >= 0:
			end = int(se)
		elif int(he) >= 0 and int(sf) > 0:
			end = int(he) + int(sf)
		if end >= 0:
			return float(end - Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	return -1.0


## Fraction of a -> b clear of static geometry.
static func _clear_frac(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, excl: Array[RID]) -> float:
	if space == null:
		return 1.0
	var rq := PhysicsRayQueryParameters3D.create(a, b)
	rq.collide_with_areas = false
	var ex: Array[RID] = excl.duplicate()
	for i: int in CameraFraming.MAX_PASSES:
		rq.exclude = ex
		var h: Dictionary = space.intersect_ray(rq)
		if h.is_empty():
			return 1.0
		if CameraFraming.is_blocker(h.get("collider")):
			return a.distance_to(h["position"]) / maxf(a.distance_to(b), 1e-4)
		ex.append(h["rid"])
	return 1.0


func _cut_ready(target: Node3D, view: Camera3D) -> bool:
	if not is_inside_tree() or target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if view == null and cut_kind == "":
		return false
	if cam == null:
		cam = Camera3D.new()
		cam.name = "DirectorCam"
		cam.near = 0.05
		cam.far = 1500.0
		cam.set_meta(META_CUT, self)
		add_child(cam)
	return true


func _begin_cut(kind: String, target: Node3D, view: Camera3D, secs: float) -> void:
	if cut_kind == "":
		_cut_prev = view if view != cam else null
		_last_prev = _cut_prev
	cut_kind = kind
	_cut_target = target
	_cut_t = 0.0
	_cut_len = maxf(secs, 0.05)
	cam.make_current()


func _tick_cut(rdt: float) -> void:
	_cut_t += rdt
	if cam == null or not cam.current:
		_end_cut(false)                      # someone else took the screen (a cinematic, a takedown cut)
		return
	if _cut_target != null and is_instance_valid(_cut_target) and _cut_target.is_inside_tree():
		_cut_look = _look_point(_cut_target)
	var u: float = clampf(_cut_t / _cut_len, 0.0, 1.0)
	var e: float = u * u * (3.0 - 2.0 * u)
	var pos: Vector3
	if cut_kind == "preview":
		pos = _cut_look + _cut_off * (1.0 - CameraRules.CUT_PUSH * e)
	else:
		pos = _orbit_pos(_cut_look, _orbit_a0 + _orbit_sign * _orbit_sweep * e, _orbit_r)
	var d: Vector3 = _cut_look - pos
	if d.length_squared() > 1e-4:
		var up: Vector3 = Vector3.UP if absf(d.normalized().y) < 0.995 else Vector3.FORWARD
		var b: Basis = Basis.looking_at(d, up) * Basis.from_euler(fx_rot_deg * (PI / 180.0))
		cam.global_transform = Transform3D(b, pos + b * (fx_offset * 0.5))
	if _cut_t >= _cut_len:
		_end_cut(false)


## End the running cut: the previous camera back (only while the director camera still holds the screen) and normal time
## (only while this node owns the time scale). quiet = from a pause / leaving the tree.
func _end_cut(quiet: bool) -> void:
	if cut_kind == "" and not _owns_time:
		return
	cut_kind = ""
	_unslow()
	if cam != null and is_instance_valid(cam) and cam.current and cam.is_inside_tree():
		var back: Camera3D = _cut_prev if (_cut_prev != null and is_instance_valid(_cut_prev) and _cut_prev.is_inside_tree()) else null
		if back != null:
			back.make_current()
		elif not quiet:
			cam.clear_current(true)
	_cut_prev = null
	_cut_target = null


func _orbit_pos(look: Vector3, a: float, r: float = CameraRules.ORBIT_R) -> Vector3:
	return look + Vector3(sin(a), 0.0, cos(a)) * r + Vector3.UP * CameraRules.ORBIT_UP


## The chest of a character (subject points), else the node's origin + 1 m.
func _look_point(target: Node3D) -> Vector3:
	var pts: PackedVector3Array = CameraFraming.subject_points(target)
	if pts.size() >= 2:
		return pts[1]
	return target.global_position + Vector3.UP


func _cut_points(target: Node3D, look: Vector3) -> PackedVector3Array:
	var pts: PackedVector3Array = CameraFraming.subject_points(target)
	if pts.is_empty():
		pts.append(look)
	return pts


func _excl_for(target: Node3D) -> Array[RID]:
	_excl.clear()
	if target is CollisionObject3D:
		_excl.append((target as CollisionObject3D).get_rid())
	return _excl


func _space() -> PhysicsDirectSpaceState3D:
	var w: World3D = cam.get_world_3d() if cam != null and cam.is_inside_tree() else null
	return w.direct_space_state if w != null else null


func _slow(scale: float) -> void:
	var owner_obj: Object = RadialWheel.scale_owner
	if owner_obj != null and owner_obj != self and is_instance_valid(owner_obj):
		return                               # a wheel / a combat / a chase owns the time scale: the cut plays in its time
	RadialWheel.scale_owner = self
	Engine.time_scale = clampf(scale, 0.05, 1.0)
	_owns_time = true


func _unslow() -> void:
	if _owns_time and RadialWheel.scale_owner == self:
		Engine.time_scale = 1.0
		RadialWheel.scale_owner = null
	_owns_time = false
