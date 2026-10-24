# File: res://scripts/wanted/Officer.gd
# Phase W chaser on foot (spec W-D7, section 4): a campus security guard (bảo vệ), Thầy Toàn (ThS. ToanHLM, the story's
# fictional lecturer: lecturer preset, faster, shouts "Em kia! Đứng lại! Thẻ sinh viên đâu?") or a police officer off his
# bike. CHASE runs straight at the player while WantedDirector says he sees him (sees_player); SEARCH walks to the last
# seen point and wanders inside the search circle; GIVE_UP walks away once the stars are gone. Officers never shoot: within
# TACKLE_R of a player running faster than TACKLE_MIN_SPEED they dive (comic tackle: the player is knocked down, never
# hurt); otherwise they stop beside him (WantedDirector counts the catch, Task 10). Weapons knock them out for KO_S whatever
# the weapon (plan P5) and emit `knocked` (+5 heat); a blast launches them; stink stuns; the loa pushes some into a dance.
# Steering: straight line, step-up like Pedestrian (only against low static geometry), sidestep when stuck; `stuck_s` counts
# how long he has been pinned (WantedDirector replaces him after STUCK_REPLACE_S). GIVE_UP turns back into SEARCH as soon as
# the stars rise again. Hot path: typed refs to the director, the player and the animator (no dynamic calls). SUPERVISE (community service): stands, faces the
# player, says lines. Rigged CharacterBuilder body (PS2 head in vice). No autoload is referenced here.
class_name Officer
extends CharacterBody3D

signal knocked(officer: Officer)

enum State { CHASE, SEARCH, TACKLE, KNOCKED, LAUNCHED, STUNNED, GIVE_UP, SUPERVISE }

const RADIUS: float = 0.3
const HEIGHT: float = 1.75
const GRAVITY: float = 20.0
const SPEEDS: Dictionary = {"guard": 5.0, "toan": 6.2, "police": 5.4}
const SEARCH_FACTOR: float = 0.7
const GIVE_UP_SPEED: float = 2.0
const STOP_R: float = 0.9
const KO_S: float = 10.0
const GETUP_S: float = 0.9
const STUN_S: float = 3.0
const DANCE_S: float = 2.0
const DANCE_CHANCE: float = 0.3
const TACKLE_R: float = 1.5
const TACKLE_MIN_SPEED: float = 4.5
const TACKLE_S: float = 0.9
const TACKLE_HIT_S: float = 0.25
const TACKLE_SPEED: float = 6.5
const TACKLE_COOLDOWN: float = 4.0
const PUSH_DECEL: float = 8.0
const STEP_HEIGHT: float = 0.35
const STUCK_S: float = 1.0
const SIDESTEP_S: float = 1.0
const WANDER_ARRIVE: float = 1.5
const SHOUT_EVERY: float = 8.0
const SHOUT_S: float = 2.5
const SAY_S: float = 3.5
const LAND_MIN_S: float = 0.15
const STEP_CONTACT_MAX: float = 0.35     # a wall contact higher than this above the feet is a wall, never a kerb
const LOD_FAR_M: float = 20.0            # chasing / searching beyond this from the player: move every other frame (x2)
const PRESETS: Dictionary = {
	"guard": {"preset": "guard"},
	"toan": {"preset": "lecturer", "seed": 1995, "glasses": true},
	"police": {"preset": "cop"},
}
const LINES: Dictionary = {
	"guard": ["Đứng lại!", "Bảo vệ đây, đứng yên đó!", "Chạy đi đâu, cổng khoá rồi!"],
	"toan": ["Em kia! Đứng lại! Thẻ sinh viên đâu?", "Em học lớp nào? Đứng lại cho tôi!", "Chạy nữa là tôi cho F môn này đấy!"],
	"police": ["Dừng lại!", "Đứng yên, xuất trình giấy tờ!", "Không được chạy!"],
}

var role: String = "guard"
var state: int = State.CHASE
var wanted: Node
var player: Node3D
var stuck_s: float = 0.0                 # seconds pinned in place in a row (0 while making progress)
var _wd: WantedDirector                  # typed wanted (null for the community-service supervisor)
var _tpc: ThirdPersonController          # typed player (null in odd tests)
var _an: Node                            # the model's RigAnimator
var _lod_phase: int = 0
var model: Node3D
var bubble: Label3D
var sees_player: bool = false
var bike_idx: int = -1
var ko_left: float = 0.0
var hits: Array[String] = []
var shouts: int = 0
var _t: float = 0.0
var _tackle_cd: float = 0.0
var _tackled: bool = false
var _getting_up: bool = false
var _shout_t: float = 0.0
var _bubble_left: float = 0.0
var _wander: Vector3 = Vector3.ZERO
var _has_wander: bool = false
var _push_v: Vector3 = Vector3.ZERO
var _side: float = 1.0
var _side_t: float = 0.0
var _stuck_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()


## Build the body; call before add_child. wanted_node: WantedDirector (target_pos, last_seen, search_radius) or null
## (community-service supervisor: looks at player_node).
func setup(r: String, wanted_node: Node, player_node: Node3D, seed_v: int) -> void:
	role = r if SPEEDS.has(r) else "guard"
	wanted = wanted_node
	player = player_node
	_wd = wanted_node as WantedDirector
	_tpc = player_node as ThirdPersonController
	_rng.seed = seed_v
	_lod_phase = seed_v % 2
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	cs.name = "Capsule"
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(cs)
	var o: Dictionary = (PRESETS[role] as Dictionary).duplicate()
	if not o.has("seed"):
		o["seed"] = seed_v
	o["rigged"] = true
	o["name"] = "Model"
	model = CharacterBuilder.build(o)
	add_child(model)
	_an = CharacterBuilder.get_animator(model)
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 40
	bubble.pixel_size = 0.005
	bubble.outline_size = 10
	bubble.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	bubble.no_depth_test = true
	bubble.position = Vector3(0.0, 2.25, 0.0)
	bubble.visible = false
	add_child(bubble)
	_shout_t = 0.6 if role == "toan" else _rng.randf_range(1.0, 3.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_tackle_cd = maxf(0.0, _tackle_cd - delta)
	_tick_bubble(delta)
	match state:
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.TACKLE:
			_tackle(delta)
		State.KNOCKED:
			_knocked(delta)
		State.LAUNCHED:
			_launched(delta)
		State.STUNNED:
			_stunned(delta)
		State.GIVE_UP:
			_give_up(delta)
		State.SUPERVISE:
			_supervise(delta)


func _target() -> Vector3:
	if _wd:
		return _wd.target
	if wanted and wanted.has_method("target_pos"):
		return wanted.call("target_pos")
	return player.global_position if player else global_position


func _set_anim(speed_ms: float, run: float) -> void:
	if _an:
		_an.set("speed", speed_ms)
		(_an.get("params") as Dictionary)["run"] = run


func _flat_d(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


static func _flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-6 else Vector3(0.0, 0.0, 1.0)


func _chase(delta: float) -> void:
	if not sees_player:
		state = State.SEARCH
		_has_wander = false
		return
	var p: Vector3 = _target()
	var d: float = _flat_d(p)
	var pl_speed: float = _tpc.horizontal_speed if _tpc else 0.0
	var down: bool = _tpc != null and _tpc.is_knocked_down()
	if d <= TACKLE_R and pl_speed >= TACKLE_MIN_SPEED and _tackle_cd <= 0.0 and not down and player.visible:
		_start_tackle(p)
		return
	_move_to(p, float(SPEEDS[role]) if d > STOP_R else 0.0, delta)
	_maybe_shout(delta)


func _search(delta: float) -> void:
	if sees_player:
		state = State.CHASE
		return
	var ls: Vector3 = wanted.get("last_seen") if wanted else global_position
	if not _has_wander:
		_wander = ls
		_has_wander = true
	if _flat_d(_wander) <= WANDER_ARRIVE:
		var r: float = float(wanted.call("search_radius")) if wanted and wanted.has_method("search_radius") else 30.0
		var a: float = _rng.randf() * TAU
		var k: float = sqrt(_rng.randf()) * r * 0.6
		_wander = ls + Vector3(cos(a) * k, 0.0, sin(a) * k)
	_move_to(_wander, float(SPEEDS[role]) * SEARCH_FACTOR, delta)


func _give_up(delta: float) -> void:
	if _wd and _wd.stars > 0 and _wd.state == "free":
		state = State.SEARCH                 # a new crime while walking away: back on the hunt
		_has_wander = false
		return
	var away: Vector3 = _flat_dir(global_position - _target())
	_move_to(global_position + away * 10.0, GIVE_UP_SPEED, delta)


func _supervise(delta: float) -> void:
	_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if player:
		var d: Vector3 = _flat_dir(player.global_position - global_position)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 6.0))


## Straight-line steering with a sidestep when stuck, step-up onto kerbs, push decay, run animation.
func _move_to(target: Vector3, speed: float, delta: float) -> void:
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var d: float = to.length()
	# LOD (performance gate): far from the player, the body moves every other frame by two frames' worth
	var lod: bool = (state == State.CHASE or state == State.SEARCH) and _push_v == Vector3.ZERO and player != null 		and _flat_d(player.global_position) > LOD_FAR_M
	if lod:
		if (Engine.get_physics_frames() + _lod_phase) % 2 == 1:
			return
		delta *= 2.0
	var dir: Vector3 = to / d if d > 0.01 else Vector3.ZERO
	var goal_dir: Vector3 = dir
	if _side_t > 0.0 and dir != Vector3.ZERO:
		_side_t -= delta
		dir = (dir + Vector3(-dir.z, 0.0, dir.x) * _side * 1.2).normalized()
	if speed <= 0.0 and _push_v == Vector3.ZERO and is_on_floor() and _side_t <= 0.0:
		# standing beside the player: no physics query (performance gate), just face him
		velocity = Vector3.ZERO
		if player:
			var f0: Vector3 = _flat_dir(player.global_position - global_position)
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-f0.x, -f0.z), minf(1.0, delta * 6.0))
		_set_anim(0.0, 0.0)
		_stuck_check(delta, d, speed, dir)
		return
	var k: float = 2.0 if lod else 1.0
	velocity.x = (dir.x * speed + _push_v.x) * k
	velocity.z = (dir.z * speed + _push_v.z) * k
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	_gravity(delta)
	if is_on_wall() and speed > 0.0 and _wall_is_static():
		_try_step_up(dir, delta / k)
	move_and_slide()
	if lod:
		velocity.x /= k
		velocity.z /= k
	if dir != Vector3.ZERO and speed > 0.0:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 10.0))
	elif player:
		var f: Vector3 = _flat_dir(player.global_position - global_position)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-f.x, -f.z), minf(1.0, delta * 6.0))
	_set_anim(Vector2(velocity.x, velocity.z).length(), 0.45 if speed > 4.5 else 0.0)
	_stuck_check(delta, d, speed, goal_dir)


## Every STUCK_S: an officer who got less than a quarter of his speed closer to his goal (pinned on a wall, or sliding to and
## fro in a corner) flips his sidestep side and adds to stuck_s; real progress resets it.
func _stuck_check(delta: float, d: float, speed: float, goal_dir: Vector3) -> void:
	if speed <= 0.0 or d < 2.0:
		_stuck_t = 0.0
		stuck_s = 0.0
		_last_pos = global_position
		return
	_stuck_t += delta
	if _stuck_t < STUCK_S:
		return
	if (global_position - _last_pos).dot(goal_dir) < speed * STUCK_S * 0.25:
		_side = -_side
		_side_t = SIDESTEP_S
		stuck_s += _stuck_t
	else:
		stuck_s = 0.0
	_stuck_t = 0.0
	_last_pos = global_position


func _start_tackle(p: Vector3) -> void:
	state = State.TACKLE
	_t = 0.0
	_tackled = false
	var dir: Vector3 = _flat_dir(p - global_position)
	velocity = dir * TACKLE_SPEED
	model.rotation.y = atan2(-dir.x, -dir.z)
	CharacterBuilder.play(model, "knockdown")
	_log("tackle")


func _tackle(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)
	move_and_slide()
	if not _tackled and _t >= TACKLE_HIT_S:
		_tackled = true
		var p: Vector3 = _target()
		if _flat_d(p) <= TACKLE_R + 0.5 and player and player.has_method("knock_down"):
			player.call("knock_down", p - global_position, 2.5)
		CharacterBuilder.play(model, "getup")
	if _t >= TACKLE_S:
		state = State.CHASE
		_tackle_cd = TACKLE_COOLDOWN
		CharacterBuilder.stop_clip(model)


## Weapon hit (same info as Pedestrian.take_hit). Officers stay down KO_S whatever the weapon (spec section 4, plan P5) and
## emit `knocked` (+5 heat). "scare" does nothing: officers are not scared off.
func take_hit(info: Dictionary) -> String:
	if is_down() or state == State.SUPERVISE:
		return "none"
	var kind: String = String(info.get("kind", "melee"))
	var from: Vector3 = info.get("from", global_position)
	var away: Vector3 = _flat_dir(global_position - from)
	match kind:
		"punch":
			_push_v = away * 2.0
			CharacterBuilder.play(model, "stumble")
			_log("stumble")
			return "stumble"
		"melee", "bullet", "bonk":
			_knock_out(away)
			return "knocked_out"
		"pellet", "blast":
			state = State.LAUNCHED
			_t = 0.0
			velocity = info.get("vel", away * 6.0 + Vector3(0.0, 5.0, 0.0))
			ko_left = KO_S
			collision_layer = 0
			CharacterBuilder.play(model, "fall_flail")
			_log("launched")
			knocked.emit(self)
			return "launched"
		"stink":
			_stun(STUN_S, "facepalm")
			_log("stink")
			return "stink"
		"sonic":
			_push_v = _flat_dir(info.get("dir", away)) * float(info.get("power", 5.0))
			var dance: bool = bool(info["dance"]) if info.has("dance") else _rng.randf() < DANCE_CHANCE
			if dance and state != State.STUNNED:
				_stun(DANCE_S, "cheer")
				_log("dance")
				return "dance"
			return "pushed"
	return "none"


func _knock_out(away: Vector3) -> void:
	state = State.KNOCKED
	ko_left = KO_S
	_t = 0.0
	_getting_up = false
	velocity = away * 1.5
	collision_layer = 0
	if away.length_squared() > 1e-4:
		model.rotation.y = atan2(away.x, away.z)
	CharacterBuilder.play(model, "knockdown")
	CharacterBuilder.set_expression(model, "pain")
	_log("ko")
	knocked.emit(self)


func _stun(secs: float, clip: String) -> void:
	state = State.STUNNED
	ko_left = secs
	_t = 0.0
	CharacterBuilder.play(model, clip, secs)


func _knocked(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	ko_left -= delta
	if ko_left <= GETUP_S and not _getting_up:
		_getting_up = true
		CharacterBuilder.play(model, "getup")
	if ko_left <= 0.0:
		_getting_up = false
		collision_layer = 1
		CharacterBuilder.set_expression(model, "open")
		CharacterBuilder.stop_clip(model)
		state = State.CHASE if sees_player else State.SEARCH
		_has_wander = false


func _launched(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	model.rotation.y += 9.0 * delta
	if (_t >= LAND_MIN_S and is_on_floor() and velocity.y <= 0.0) or _t >= 4.0:
		state = State.KNOCKED
		_t = 0.0
		_getting_up = false
		velocity = Vector3(velocity.x, 0.0, velocity.z) * 0.3
		CharacterBuilder.play(model, "knockdown")


func _stunned(delta: float) -> void:
	_gravity(delta)
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	velocity.x = _push_v.x
	velocity.z = _push_v.z
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	ko_left -= delta
	if ko_left <= 0.0:
		CharacterBuilder.stop_clip(model)
		state = State.SEARCH
		_has_wander = false


func is_down() -> bool:
	return state == State.KNOCKED or state == State.LAUNCHED


## Only an officer on his feet and after the player can grab him (WantedDirector's catch rule, Task 10).
func can_catch() -> bool:
	return state == State.CHASE or state == State.SEARCH


func give_up() -> void:
	if not is_down() and state != State.SUPERVISE:
		state = State.GIVE_UP


func supervise() -> void:
	state = State.SUPERVISE
	velocity = Vector3.ZERO


func say(text: String, secs: float = SAY_S) -> void:
	bubble.text = text
	bubble.visible = true
	_bubble_left = secs


func _maybe_shout(delta: float) -> void:
	_shout_t -= delta
	if _shout_t > 0.0:
		return
	var lines: Array = LINES[role]
	say(String(lines[0] if shouts == 0 else lines[_rng.randi_range(0, lines.size() - 1)]), SHOUT_S)
	shouts += 1
	_shout_t = SHOUT_EVERY


func _log(what: String) -> void:
	hits.append(what)
	if hits.size() > 32:
		hits.remove_at(0)


func _tick_bubble(delta: float) -> void:
	if _bubble_left <= 0.0:
		return
	_bubble_left -= delta
	if _bubble_left <= 0.0:
		bubble.visible = false


func _gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta


## The wall touched by the last move_and_slide is low level geometry (a kerb or a step can be climbed): not a building
## wall (contact above STEP_CONTACT_MAX), a person, an officer, the player or a vehicle. Pinned officers must not cost four
## test_move probes per frame.
func _wall_is_static() -> bool:
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		if absf(c.get_normal().y) < 0.7 and c.get_position().y - global_position.y <= STEP_CONTACT_MAX 				and c.get_collider() is StaticBody3D:
			return true
	return false


## Step onto low kerbs / steps while blocked (as Pedestrian._try_step_up).
func _try_step_up(dir: Vector3, delta: float) -> void:
	var motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return
	var xf: Transform3D = global_transform
	if not test_move(xf, motion):
		return
	var up := Vector3(0.0, STEP_HEIGHT + 0.03, 0.0)
	if test_move(xf, up):
		return
	var probe: Vector3 = motion + dir * 0.12
	var raised: Transform3D = xf.translated(up)
	if test_move(raised, probe):
		return
	var col := KinematicCollision3D.new()
	if not test_move(raised.translated(probe), Vector3(0.0, -(STEP_HEIGHT + 0.06), 0.0), col):
		return
	if col.get_normal().y < 0.7:
		return
	var step_h: float = up.y + col.get_travel().y
	if step_h > 0.02 and step_h <= STEP_HEIGHT + 0.03:
		global_position.y += step_h + 0.01
