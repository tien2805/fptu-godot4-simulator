# File: res://scripts/combat/bike/BikerEnemy.gd
# One Bầy Sói biker of the Phase C bike chase (spec C-D1). Analytic, no physics body: a kinematic follower of a target
# point that BikeChase computes from the route (or the player's heading frame). The node itself is the bike (top_level,
# global transform = the bike on the road); the rider is a rigged CharacterBuilder body sitting on it ("ride" code clip,
# its AnimationPlayer kept inactive while riding so far LOD frames never flash the idle pose), with the wolf helmet
# (grey shell, cone ears, snout, red LED eyes) unless opts give a body / body_fn; a name label with short taunts.
# AI states (BikeChase assigns the role FRONT / LEFT / RIGHT / BACK and the attack tokens):
#   APPROACH (catch up to the slot) -> PACE (hold it) -> WINDUP (0.5 s telegraph: LED eyes flash, engine rev, HUD side
#   warning; swerves in; its last KICK_LOCK_S fix the kick line in world space, so steering away dodges) -> KICK (hit
#   check at 0.15 s through BikeChase.enemy_kick, on that fixed line) -> RECOVER; BRAKE (the FRONT biker
#   brake-checks the player); WOBBLE (kicked: 0.55 s, then CRASH, or RECOVER while hp is left); CRASH (the rider flies in a
#   comic somersault, bounces once and slides; the bike slides on its side with sparks); DOWN (stars, no gore); LEAVE
#   (after `lost` or the chase's end: rides off ahead, or drops back at the route end, and is hidden once out of view);
#   HOLD (ai off, tests: holds hold_along / hold_lat beside the player).
# Traffic: every AVOID_EVERY frames it looks for the nearest car in its path and passes on the free side (within the
# road) or brakes behind it; touching a car anyway (a kicked biker wobbling into one) is a crash.
# opts: "label", "hp" (kicks to crash, default 1), "seed", "ai" (false = HOLD), "aggression" (0..1: shorter pacing),
# "eye_color", "paint", "body" (CharacterBuilder opts merged over the wolf rider look), "body_fn" (Callable(look) ->
# rigged Node3D; the wolf helmet is not added then).
class_name BikerEnemy
extends Node3D

enum St { APPROACH, PACE, WINDUP, KICK, RECOVER, BRAKE, WOBBLE, CRASH, DOWN, LEAVE, HOLD }
enum Role { BACK, LEFT, RIGHT, FRONT }
const ST_NAMES: Array[String] = ["approach", "pace", "windup", "kick", "recover", "brake", "wobble", "crash", "down", "leave", "hold"]
const SEAT := Vector3(0.0, 0.32, 0.14)
const LABEL_Y: float = 2.25
const SPIN_PIVOT: float = 0.9            # the somersault turns about a point this high above the rider's root

var ch: BikeChase
var label: String = ""
var hp: int = 1
var max_hp: int = 1
var ai: bool = true
var aggression: float = 0.5
var st: int = St.APPROACH
var st_t: float = 0.0
var role: int = Role.BACK
var back_k: int = 0                      # rank among the BACK reserves
var side: float = -1.0                   # LEFT -1 / RIGHT +1 (the side it kicks from)
var has_token: bool = false
var hit_done: bool = false
var pace_t: float = 1.5
var pos2: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var lean: float = 0.0
var floor_y: float = 0.0
var hold_along: float = 0.0
var hold_lat: float = 2.0
var crash_cause: String = ""
var kicked_by_player: bool = false
## Results of this biker's kicks on the player ("hit" | "miss" | "ignored"; last 16).
var results: Array[String] = []
var attacks: int = 0
var body: Node3D
var rider_landed: bool = false
var rider_v: Vector3 = Vector3.ZERO
var rider_pos: Vector3 = Vector3.ZERO
var rider_yaw: float = 0.0
var rider_flip: float = 0.0
var rider_spin: float = 0.0
var bike_v: Vector2 = Vector2.ZERO
var bike_spin: float = 0.0
var crash_roll: float = 1.0
var bounces: int = 0
var _flip_target: float = 0.0
var pose_w: float = 0.0
var avoid_car: int = -1                 # traffic vehicle being passed (-1: braking behind / none)
var avoid_side: float = 0.0
var avoid_need: float = 0.0
var avoid_r: Vector2 = Vector2.RIGHT
var _last_target: Vector2 = Vector2.ZERO
var avoid_cap: float = -1.0
var avoid_t: float = 0.0
var avoids: int = 0
var scrapes: int = 0
var gone: bool = false
## Spawned behind for an "ahead" slot (in view there): takes the FRONT role first.
var prefer_front: bool = false
var leave_along: float = 45.0
var _line_locked: bool = false
var _line_o: Vector2 = Vector2.ZERO
var _line_t: Vector2 = Vector2(0.0, -1.0)
var _rng := RandomNumberGenerator.new()
var _sk: Skeleton3D = null
var _anim: Node = null
var _ap: AnimationPlayer = null
var _eye_mat: StandardMaterial3D
var _eye_col: Color = BikeCombatData.EYE_COL
var _label3d: Label3D
var _taunt_t: float = 5.0
var _taunt_left: float = 0.0
var _frame: int = 0
var _spark_t: float = 0.0
var _prev_vel: Vector2 = Vector2.ZERO
var _anchor: Node3D = null
var _frozen: bool = false
var _wob_sign: float = 1.0


func setup(opts: Dictionary = {}) -> void:
	top_level = true
	label = String(opts.get("label", ""))
	max_hp = maxi(1, int(opts.get("hp", 1)))
	hp = max_hp
	ai = bool(opts.get("ai", true))
	aggression = clampf(float(opts.get("aggression", 0.5)), 0.0, 1.0)
	_rng.seed = int(opts.get("seed", 1))
	_eye_col = opts.get("eye_color", BikeCombatData.EYE_COL)
	_taunt_t = _rng.randf_range(BikeCombatData.TAUNT_EVERY.x, BikeCombatData.TAUNT_EVERY.y)
	var paint: Color = opts.get("paint", BikeCombatData.BIKE_PAINT)
	PropBuilder.build_scooter(self, Vector3.ZERO, 0.0, paint, {"baked": true, "name": "Scooter", "traffic_lamps": true})
	var look: Dictionary = {"preset": "rider", "seed": _rng.randi(), "female": false, "body": "hoodie", "backpack": false,
		"glasses": false, "helmet_color": BikeCombatData.HELMET_COL,
		"shirt_color": BikeCombatData.JACKETS[_rng.randi() % BikeCombatData.JACKETS.size()], "clip": "ride"}
	var bo: Dictionary = opts.get("body", {})
	for k: String in bo.keys():
		look[k] = bo[k]
	look["rigged"] = true
	look["name"] = "Rider"
	var bf: Callable = opts.get("body_fn", Callable())
	body = bf.call(look) if bf.is_valid() else CharacterBuilder.build(look)
	body.name = "Rider"
	body.position = SEAT
	add_child(body)
	CharacterBuilder.set_param(body, "ride_shoulder", 1.2)
	CharacterBuilder.set_param(body, "ride_elbow", 0.28)
	CharacterBuilder.set_param(body, "ride_lean", 0.4)
	if not bf.is_valid():
		attach_wolf_helmet(body, _eye_col)
	_eye_mat = body.get_meta("wolf_eye_mat", null) as StandardMaterial3D
	_sk = body.get_meta("skeleton", null) as Skeleton3D
	_anim = CharacterBuilder.get_animator(body)
	_ap = _anim.get("player") as AnimationPlayer if _anim else null
	if _ap:
		_ap.active = false                # the "ride" code clip owns every joint that matters while riding
	_label3d = Label3D.new()
	_label3d.name = "Name"
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.font_size = 40
	_label3d.pixel_size = 0.006
	_label3d.outline_size = 8
	_label3d.modulate = Color("#FFD0C8")
	_label3d.position = Vector3(0.0, LABEL_Y, 0.0)
	_label3d.text = label
	_label3d.no_depth_test = false
	add_child(_label3d)
	process_priority = 11                  # the kick pose layer runs after the RigAnimator (10)


## The Bầy Sói helmet on a rigged body's head pivot: cone ears, a snout with a nose, two red LED eyes (an emissive material
## of its own, kept as meta "wolf_eye_mat" for the telegraph flash). The rider preset's helmet shell is the grey dome.
static func attach_wolf_helmet(b: Node3D, eye_col: Color = BikeCombatData.EYE_COL) -> Node3D:
	var head: Node3D = CharacterBuilder.get_pivot(b, "head")
	if head == null:
		return null
	var w := Node3D.new()
	w.name = "WolfHelmet"
	head.add_child(w)
	var hs: float = maxf(head.scale.y, 0.01)
	w.position = Vector3(0.0, 0.1 / hs, 0.0)
	w.scale = Vector3.ONE / hs
	var shell: StandardMaterial3D = CineFX._mat(BikeCombatData.HELMET_COL, 0.5)
	var dark: StandardMaterial3D = CineFX._mat(BikeCombatData.HELMET_DARK, 0.6)
	for sx: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = CineFX._cyl(w, "Ear", 0.0, 0.04, 0.1, Vector3(sx * 0.075, 0.17, 0.01), dark)
		ear.rotation = Vector3(0.0, 0.0, -sx * 0.35)
	CineFX._box(w, "Snout", Vector3(0.09, 0.06, 0.1), Vector3(0.0, -0.005, -0.15), shell)
	CineFX._sphere(w, "Nose", 0.018, Vector3(0.0, 0.02, -0.203), CineFX._mat(Color("#141414"), 0.4))
	var eye: StandardMaterial3D = CineFX._glow_mat(eye_col, 3.0)
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx2: float in [-0.04, 0.04]:
		CineFX._sphere(w, "LedEye", 0.017, Vector3(sx2, 0.062, -0.128), eye)
	b.set_meta("wolf_eye_mat", eye)
	return w


## Put the biker on the road at pos (floor height y), facing yaw, moving at speed along its facing.
func place(pos: Vector3, face_yaw: float, speed: float) -> void:
	pos2 = Vector2(pos.x, pos.z)
	floor_y = pos.y
	yaw = face_yaw
	vel = Vector2(-sin(face_yaw), -cos(face_yaw)) * speed
	_prev_vel = vel
	_enter(St.APPROACH if ai else St.HOLD)
	_place_bike()


func state_name() -> String:
	return ST_NAMES[st]


func is_down() -> bool:
	return st == St.CRASH or st == St.DOWN


## Still part of the fight (not crashed, not riding off).
func is_active() -> bool:
	return not is_down() and st != St.LEAVE


## A player kick can land on it.
func kickable() -> bool:
	return is_active() and not gone


func is_attacking() -> bool:
	return st == St.WINDUP or st == St.KICK


func telegraphing() -> bool:
	return st == St.WINDUP


func riding() -> bool:
	return st != St.CRASH and st != St.DOWN


func ground_pos() -> Vector3:
	return Vector3(pos2.x, floor_y, pos2.y)


func speed() -> float:
	return vel.length()


func _enter(s: int) -> void:
	if (st == St.WINDUP or st == St.KICK) and s != St.WINDUP and s != St.KICK:
		_release_token()
	if st == St.WINDUP and _eye_mat:
		_eye_mat.emission_energy_multiplier = 3.0
	st = s
	st_t = 0.0
	hit_done = false
	match s:
		St.PACE:
			pace_t = _rng.randf_range(BikeCombatData.PACE_MIN, BikeCombatData.PACE_MAX) * lerpf(1.25, 0.6, aggression)
		St.WINDUP:
			attacks += 1
			_line_locked = false
			if ch:
				ch.cue("engine_roar", ground_pos(), -6.0)


func _release_token() -> void:
	if has_token and ch:
		ch.release_token(self)
	has_token = false


## The chase gave it an attack token: swerve in from its side (tests call it directly with ai off too).
func start_attack(from_side: float) -> void:
	side = signf(from_side) if from_side != 0.0 else side
	has_token = true
	_enter(St.WINDUP)


## A player kick (away = unit direction from the player to this biker on the map plane). "wobble" (hp left: it recovers),
## "crash" (it wobbles, then crashes) or "ignored".
func take_kick(away: Vector2) -> String:
	if not kickable() or st == St.WOBBLE:
		return "ignored"
	hp -= 1
	kicked_by_player = true
	_release_token()
	vel += away * BikeCombatData.KICK_PUSH
	_wob_sign = signf(away.dot(Vector2(-vel.y, vel.x))) if vel.length() > 0.5 else 1.0
	_enter(St.WOBBLE)
	if ch:
		ch.cue("impact_medium", ground_pos() + Vector3(0.0, 1.0, 0.0))
	return "crash" if hp <= 0 else "wobble"


## Comic crash: the rider is thrown off in a somersault, the bike slides on its side. cause "kick" | "traffic" | ...
func crash(cause: String, push: Vector2 = Vector2.ZERO) -> void:
	if is_down():
		return
	crash_cause = cause
	_release_token()
	var g: Transform3D = body.global_transform
	body.top_level = true
	body.global_transform = g
	rider_pos = g.origin
	rider_yaw = yaw
	rider_v = Vector3(vel.x * 0.85 + push.x, BikeCombatData.TUMBLE_UP, vel.y * 0.85 + push.y)
	rider_spin = BikeCombatData.TUMBLE_SPIN * (1.0 if _rng.randf() < 0.5 else -1.0)
	rider_flip = 0.0
	rider_landed = false
	bounces = 0
	bike_v = vel + push * 0.6
	bike_spin = _rng.randf_range(1.2, 2.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
	crash_roll = -1.0 if (push.dot(Vector2(cos(yaw), -sin(yaw))) >= 0.0) else 1.0   # falls toward the push (+roll = left)
	pose_w = 0.0
	_spark_t = 0.0
	if _ap:
		_ap.active = true
	CharacterBuilder.play(body, "knockdown")
	_label3d.visible = false
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 1.5
	_enter(St.CRASH)
	if ch:
		ch.cue("helmet_clonk", ground_pos() + Vector3(0.0, 0.8, 0.0))
		ch.cue("bin_crash", ground_pos(), -3.0)
		ch.cue("slide_whistle", rider_pos + Vector3(0.0, 1.0, 0.0), -2.0)
		ch.on_biker_crash(self)


## After the player lost: ride off ahead, then vanish.
func stand_down() -> void:
	if is_down() or st == St.LEAVE:
		return
	# the player still riding (or the route ending): they give up and drop back behind the camera; the player stopped
	# (knocked off): they ride on far ahead, out of view
	leave_along = 200.0 if ch == null or (ch.p_vel.length() <= 5.0 and ch.room_ahead(220.0)) else -70.0
	_enter(St.LEAVE)


# ---------------------------------------------------------------------------
# PER FRAME (called by BikeChase._physics_process)
# ---------------------------------------------------------------------------
func tick(delta: float) -> void:
	if gone:
		return
	_frame += 1
	st_t += delta
	match st:
		St.CRASH:
			_tumble(delta)
			_floor_ray(3)
			return
		St.DOWN:
			if not _frozen and st_t >= BikeCombatData.DOWN_FREEZE_S:
				_frozen = true
				body.process_mode = Node.PROCESS_MODE_DISABLED   # the Death pose holds; no animation cost
			return
	_think(delta)
	if st == St.CRASH:
		return
	_floor_ray(BikeCombatData.RAY_EVERY)
	_taunts(delta)
	if st != St.WOBBLE and st != St.LEAVE and ch.traffic and (_frame + get_index()) % BikeCombatData.AVOID_EVERY == 0:
		_avoid_check()
	if ch.traffic and st != St.LEAVE:
		_traffic_contact()


func _think(delta: float) -> void:
	var target: Vector2 = pos2
	var max_rel: float = BikeCombatData.CATCH_SPEED
	var gain: float = BikeCombatData.POS_GAIN
	match st:
		St.HOLD:
			target = ch.target_at(hold_along, hold_lat)
		St.APPROACH:
			target = slot_target()
			if pos2.distance_to(target) < 3.0:
				_enter(St.PACE)
		St.PACE:
			target = slot_target()
			if ai and st_t >= pace_t:
				if (role == Role.LEFT or role == Role.RIGHT) and ch.request_token(self):
					start_attack(-1.0 if role == Role.LEFT else 1.0)
				elif role == Role.FRONT:
					_enter(St.BRAKE)
				else:
					pace_t += 0.4
		St.RECOVER:
			target = slot_target() if ai else ch.target_at(hold_along, hold_lat)
			if st_t >= BikeCombatData.RECOVER_S:
				_enter(St.PACE if ai else St.HOLD)
		St.BRAKE:
			target = slot_target()
			if st_t >= BikeCombatData.BRAKE_S:
				_enter(St.PACE)
		St.WINDUP:
			var u: float = clampf(st_t / BikeCombatData.WINDUP_S, 0.0, 1.0)
			var ui: float = clampf(u / BikeCombatData.WINDUP_IN, 0.0, 1.0)
			if not _line_locked and st_t >= BikeCombatData.WINDUP_S - BikeCombatData.KICK_LOCK_S:
				_lock_line()
			if _line_locked:
				target = _on_line(BikeCombatData.SLOT_ALONG * 0.5)
			else:
				target = ch.target_at(BikeCombatData.SLOT_ALONG * 0.5, side * lerpf(BikeCombatData.SLOT_LAT, BikeCombatData.SWERVE_LAT + 0.25, ui))
			gain = BikeCombatData.SWERVE_GAIN
			pose_w = 0.25 * u
			if _eye_mat:
				_eye_mat.emission_energy_multiplier = 3.0 + 7.0 * absf(sin(st_t * 24.0))
			if st_t >= BikeCombatData.WINDUP_S:
				_enter(St.KICK)
		St.KICK:
			if not _line_locked:
				_lock_line()
			target = _on_line(0.0)
			gain = BikeCombatData.SWERVE_GAIN
			pose_w = BikeCombatData.kick_weight(st_t, 0.1, 0.25, BikeCombatData.ENEMY_KICK_S)
			if not hit_done and st_t >= BikeCombatData.ENEMY_HIT_AT:
				hit_done = true
				var res: String = ch.enemy_kick(self)
				results.append(res)
				if results.size() > 16:
					results.pop_front()
			if st_t >= BikeCombatData.ENEMY_KICK_S:
				pose_w = 0.0
				_enter(St.RECOVER)
		St.WOBBLE:
			target = pos2 + vel * 0.5
			vel = vel * maxf(0.0, 1.0 - 0.8 * delta)
			if st_t >= BikeCombatData.WOBBLE_S:
				if hp <= 0:
					crash("kick", vel.normalized() * 1.5 if vel.length() > 0.1 else Vector2.ZERO)
					return
				_enter(St.RECOVER)
		St.LEAVE:
			target = ch.target_at(leave_along, side * 2.5)
			max_rel = BikeCombatData.LEAVE_SPEED
			if (st_t >= BikeCombatData.LEAVE_S and not ch.in_view(ground_pos() + Vector3(0.0, 1.0, 0.0))) or st_t >= BikeCombatData.LEAVE_MAX_S:
				gone = true
				visible = false              # out of view: no pop
				return
	if st != St.KICK and st != St.WINDUP and pose_w > 0.0:
		pose_w = maxf(0.0, pose_w - delta * 4.0)
	if avoid_t > 0.0:
		avoid_t -= delta
		if avoid_car >= 0:
			var c: RoamTraffic.Vehicle = ch.traffic.vehicles[avoid_car]
			if c.active:
				var lt: float = (target - c.pos).dot(avoid_r)
				if avoid_side < 0.0 and lt > -avoid_need:
					target += avoid_r * (-avoid_need - lt)
				elif avoid_side > 0.0 and lt < avoid_need:
					target += avoid_r * (avoid_need - lt)
				gain = maxf(gain, BikeCombatData.AVOID_GAIN)
	else:
		avoid_cap = -1.0
		avoid_car = -1
	_last_target = target
	if st == St.WOBBLE:
		pos2 += vel * delta
		yaw += sin(st_t * 22.0) * 2.2 * delta * _wob_sign
		lean = sin(st_t * 18.0) * 0.45
		_place_bike()
		return
	_drive(delta, target, max_rel, gain)


## Kinematic follower: the player's velocity fed forward plus a pull to the target (gain 1/s), capped relative to the
## player and in absolute speed, reached with an acceleration limit.
func _drive(delta: float, target: Vector2, max_rel: float, gain: float) -> void:
	var pv: Vector2 = ch.p_vel
	var v_des: Vector2 = pv + (target - pos2) * gain
	var rel: Vector2 = v_des - pv
	if rel.length() > max_rel:
		v_des = pv + rel.normalized() * max_rel
	if avoid_cap >= 0.0:
		var f: Vector2 = vel.normalized() if vel.length() > 1.0 else ch.p_fwd
		var along: float = v_des.dot(f)
		if along > avoid_cap:
			v_des -= f * (along - avoid_cap)
	var sp: float = v_des.length()
	if sp > BikeCombatData.MAX_SPEED:
		v_des *= BikeCombatData.MAX_SPEED / sp
	vel = vel.move_toward(v_des, BikeCombatData.ACCEL * delta)
	pos2 += vel * delta
	var spd: float = vel.length()
	if spd > 1.0:
		yaw = lerp_angle(yaw, atan2(-vel.x, -vel.y), minf(1.0, delta * 10.0))
	var acc: Vector2 = (vel - _prev_vel) / maxf(delta, 1e-3)
	_prev_vel = vel
	var right := Vector2(cos(yaw), -sin(yaw))
	lean = lerpf(lean, clampf(-acc.dot(right) * 0.05, -0.45, 0.45), minf(1.0, delta * 8.0))
	_place_bike()


## Slot of its role around the player (BikeChase.target_at clamps it to the road on the route).
func slot_target() -> Vector2:
	match role:
		Role.LEFT, Role.RIGHT:
			return ch.target_at(BikeCombatData.SLOT_ALONG, side * BikeCombatData.SLOT_LAT)
		Role.FRONT:
			var along: float = BikeCombatData.FRONT_ALONG
			if st == St.BRAKE:
				var u: float = clampf(st_t / BikeCombatData.BRAKE_S, 0.0, 1.0)
				along = lerpf(BikeCombatData.FRONT_ALONG, BikeCombatData.BRAKE_ALONG, sin(u * PI))
			return ch.target_at(along, 0.0)
	var lat: float = BikeCombatData.BACK_LAT if back_k % 2 == 0 else -BikeCombatData.BACK_LAT
	return ch.target_at(-BikeCombatData.BACK_ALONG - 3.0 * float(back_k / 2), lat)


## Fix the kick line in world space: through the point SWERVE_LAT beside the player now, along his travel direction.
func _lock_line() -> void:
	_line_locked = true
	_line_o = ch.target_at(0.0, side * BikeCombatData.SWERVE_LAT)
	_line_t = ch.p_fwd


## Point on the fixed kick line level with the player (+ along metres ahead of him).
func _on_line(along: float) -> Vector2:
	return _line_o + _line_t * ((ch.p_pos - _line_o).dot(_line_t) + along)


func _place_bike() -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), lean)
	global_transform = Transform3D(b, Vector3(pos2.x, floor_y, pos2.y))


func _floor_ray(every: int) -> void:
	if (_frame + get_index()) % every != 0 or not is_inside_tree():
		return
	var y: Variant = ch.floor_at(Vector3(pos2.x, floor_y, pos2.y))
	if y is float:
		floor_y = lerpf(floor_y, float(y), 0.6) if absf(float(y) - floor_y) < 1.5 else float(y)


func _taunts(delta: float) -> void:
	if _taunt_left > 0.0:
		_taunt_left -= delta
		if _taunt_left <= 0.0:
			_label3d.text = label
		return
	if st != St.PACE:
		return
	_taunt_t -= delta
	if _taunt_t <= 0.0:
		_taunt_t = _rng.randf_range(BikeCombatData.TAUNT_EVERY.x, BikeCombatData.TAUNT_EVERY.y)
		_taunt_left = BikeCombatData.TAUNT_S
		var line: String = BikeCombatData.TAUNTS[_rng.randi() % BikeCombatData.TAUNTS.size()]
		_label3d.text = line if label == "" else label + "\n" + line


## Nearest car in its path within the look-ahead (its path: from where it is to where its target is, laterally): pass on
## the free side (road room on the route, not through the player's bike) or brake behind it.
func _avoid_check() -> void:
	var f: Vector2 = vel.normalized() if vel.length() > 2.0 else ch.p_fwd
	var r := Vector2(-f.y, f.x)
	var sp: float = vel.dot(f)
	var tl: float = (_last_target - pos2).dot(r)
	var lo: float = minf(0.0, tl)
	var hi: float = maxf(0.0, tl)
	var best_along: float = INF
	var best_lat: float = 0.0
	var best_need: float = 0.0
	var best_v: float = 0.0
	var best_i: int = -1
	for v: Variant in ch.traffic.vehicles:
		var c: RoamTraffic.Vehicle = v
		if not c.active:
			continue
		var rel: Vector2 = c.pos - pos2
		if rel.length_squared() > 1600.0:
			continue
		var along: float = rel.dot(f)
		var v_along: float = c.speed * c.dir.dot(f)
		var look: float = BikeCombatData.AVOID_LOOK + maxf(sp - v_along, 0.0) * BikeCombatData.AVOID_T
		if along < -(c.half_len + 1.2) or along > look or along >= best_along:
			continue
		var ext: float = c.half_w * absf(c.dir.dot(f)) + c.half_len * absf(c.dir.cross(f))
		var lat: float = rel.dot(r)
		var gap: float = 0.0 if (lat >= lo and lat <= hi) else minf(absf(lat - lo), absf(lat - hi))
		if gap > ext + 0.75:
			continue
		best_along = along
		best_lat = lat
		best_need = ext + 1.0
		best_v = v_along
		best_i = c.idx
	if best_i < 0:
		return
	# already passing this car: keep the side while it still has room (a little tolerance, so the choice never flip-flops)
	if avoid_car == best_i and avoid_t > 0.0 and avoid_side != 0.0:
		var keep: Vector2 = pos2 + r * (best_lat + avoid_side * best_need) + f * maxf(best_along, 0.0)
		if ch.on_road(keep, 0.7):
			avoid_need = best_need
			avoid_r = r
			avoid_t = BikeCombatData.AVOID_HOLD
			return
	# pass on the side nearer to where it is heading; the other side if that one leaves the road; else brake behind
	var first: float = 1.0 if absf(best_lat + best_need - tl) < absf(best_lat - best_need - tl) else -1.0
	var oncoming: bool = best_v < -1.0     # braking does not help: squeeze past, even beside the player
	for k: int in 2:
		var sd: float = first if k == 0 else -first
		var p: Vector2 = pos2 + r * (best_lat + sd * best_need) + f * maxf(best_along, 0.0)
		if ch.on_road(p) and (oncoming or not ch.near_player(p, best_v)):
			avoid_car = best_i
			avoid_side = sd
			avoid_need = best_need
			avoid_r = r
			avoid_t = BikeCombatData.AVOID_HOLD
			avoid_cap = -1.0
			avoids += 1
			return
	avoid_car = -1
	avoid_cap = maxf(best_v - 0.5, 0.0)
	avoid_t = BikeCombatData.AVOID_HOLD
	avoids += 1


## Touching a car: a crash when it hits it hard (faster than GRAZE_SPEED into it) or while wobbling from a kick; a slow
## scrape only pushes it out along the shallower side and takes the speed into the car away.
func _traffic_contact() -> void:
	for v: Variant in ch.traffic.vehicles:
		var c: RoamTraffic.Vehicle = v
		if not c.active:
			continue
		var rel: Vector2 = pos2 - c.pos
		if rel.length_squared() > 36.0:
			continue
		var cr := Vector2(-c.dir.y, c.dir.x)
		var ra: float = rel.dot(c.dir)
		var rl: float = rel.dot(cr)
		var pa: float = c.half_len + 0.55 - absf(ra)
		var pl: float = c.half_w + 0.28 - absf(rl)
		if pa <= 0.0 or pl <= 0.0:
			continue
		var n: Vector2 = cr * (1.0 if rl >= 0.0 else -1.0) if pl < pa else c.dir * (1.0 if ra >= 0.0 else -1.0)
		var into: float = -(vel - c.dir * c.speed).dot(n)
		if st == St.WOBBLE or into > BikeCombatData.GRAZE_SPEED:
			crash("traffic", n * 3.0 + c.dir * c.speed * 0.5)
			return
		pos2 += n * minf(pl, pa)
		if into > 0.0:
			vel += n * into
		scrapes += 1


# ---------------------------------------------------------------------------
# CRASH
# ---------------------------------------------------------------------------
func _tumble(delta: float) -> void:
	var bs: float = bike_v.length()
	if bs > 0.0:
		bike_v = bike_v.move_toward(Vector2.ZERO, BikeCombatData.BIKE_DECEL * delta)
		pos2 += bike_v * delta
		_spark_t -= delta
		if _spark_t <= 0.0 and bs > 3.0 and ch:
			_spark_t = BikeCombatData.SPARK_EVERY
			ch.sparks(Vector3(pos2.x, floor_y + 0.1, pos2.y), Vector3(-bike_v.x, 0.4, -bike_v.y).normalized())
	yaw += bike_spin * delta
	bike_spin = move_toward(bike_spin, 0.0, 2.5 * delta)
	lean = move_toward(lean, crash_roll * BikeCombatData.BIKE_ROLL, 6.0 * delta)
	_place_bike()
	if not rider_landed:
		rider_v.y -= BikeCombatData.GRAVITY * delta
	rider_pos += rider_v * delta
	if rider_pos.y <= floor_y and rider_v.y <= 0.0:
		rider_pos.y = floor_y
		if bounces == 0 and absf(rider_v.y) > 2.0:
			rider_v.y = -rider_v.y * BikeCombatData.BOUNCE
			bounces += 1
			if ch:
				ch.cue("body_fall", rider_pos + Vector3(0.0, 0.3, 0.0))
		else:
			rider_v.y = 0.0
			rider_landed = true
			_flip_target = roundf(rider_flip / TAU) * TAU
	if rider_landed:
		var h := Vector2(rider_v.x, rider_v.z).move_toward(Vector2.ZERO, BikeCombatData.RIDER_DECEL * delta)
		rider_v = Vector3(h.x, 0.0, h.y)
		rider_flip = move_toward(rider_flip, _flip_target, 12.0 * delta)
	else:
		rider_flip += rider_spin * delta
	var piv := Vector3(0.0, SPIN_PIVOT, 0.0)
	var rb := Basis(Vector3.UP, rider_yaw) * Basis(Vector3.RIGHT, rider_flip)
	body.global_transform = Transform3D(rb, rider_pos + piv) * Transform3D(Basis.IDENTITY, -piv)
	if rider_landed and rider_v.length() < 0.3 and bike_v.length() < 0.3 and rider_flip == _flip_target:
		_enter(St.DOWN)
		_anchor = Node3D.new()
		_anchor.name = "StarsAnchor"
		_anchor.top_level = true
		add_child(_anchor)
		_anchor.global_position = rider_pos + Vector3(0.0, -1.55, 0.0)   # WeaponFX stars ring 2.18 m above: ~0.6 m over the body
		if ch:
			ch.stars(_anchor, BikeCombatData.STARS_S)
			ch.cue("groan", rider_pos + Vector3(0.0, 0.4, 0.0), -3.0)


## Distance the rider ended up from its bike (tests: the rider is thrown clear).
func rider_gap() -> float:
	return Vector2(rider_pos.x - pos2.x, rider_pos.z - pos2.y).length()


# ---------------------------------------------------------------------------
# KICK POSE (after the RigAnimator; only on frames it ran, so the layer never compounds)
# ---------------------------------------------------------------------------
func _process(_d: float) -> void:
	if pose_w <= 0.001 or _sk == null or not riding():
		return
	if _anim and int(_anim.get("_lod_skip")) != 1:
		return
	CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.kick_pose(-side), pose_w)
