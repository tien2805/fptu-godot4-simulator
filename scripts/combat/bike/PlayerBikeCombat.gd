# File: res://scripts/combat/bike/PlayerBikeCombat.gd
# The player's side of the Phase C bike combat (spec C-D1) on one PlayerBike, owned by a BikeChase:
#   - kicks: Q left, E right (key events, consumed only while `enabled` and riding; kick(side) for scripts / tests).
#     Wind-up KICK_WINDUP, hit window up to KICK_ACTIVE_END, leg back at KICK_DUR, cooldown KICK_COOLDOWN from the press.
#     During the window the closest kickable target on that side (0.3-2.4 m to the side, +/-1.7 m along, in the bike's own
#     frame) takes the kick (one target per kick); no target by the end of the window = a miss.
#   - stability (the bike's HP, 100): damage(amount, cause, from_side) from an enemy kick (+ a sideways shove), a crash
#     (PlayerBike.crash_occurred: traffic, curb, pothole, fall), a ram; HURT_IFRAMES after a hit; REGEN_RATE per second
#     after REGEN_DELAY without damage. At 0 the player is knocked off: the bike locks (PlayerBike.is_controls_locked, the
#     previous value restored by reset()), lies on its side, daze stars; `knocked_off` is emitted.
#   - the kick leg as a bone pose over the rider (process priority 11, after its RigAnimator), a lean on a non-rigged one.
# Refusals: kick() while not riding / not enabled / knocked off counts in `refusals` and does nothing.
class_name PlayerBikeCombat
extends Node

signal kicked(side: int)
signal kick_hit(target: Node3D, side: int)
signal kick_missed(side: int)
signal damaged(amount: float, cause: String)
signal knocked_off

var bike: PlayerBike
var roam: Node = null
## Kick targets: the chase's current bikers (shared Array, read every window frame).
var targets: Array = []
var enabled: bool = false
var god: bool = false
var stability: float = BikeCombatData.STABILITY_MAX
var max_stability: float = BikeCombatData.STABILITY_MAX
var kick_t: float = -1.0
var kick_side: int = 0
var kick_cd: float = 0.0
var kick_done: bool = false
var kicks: int = 0
var hits: int = 0
var misses: int = 0
var refusals: int = 0
## Last kick results ("hit" | "miss"; last 16).
var results: Array[String] = []
var knocked: bool = false
var hurt_t: float = 99.0
var iframes: float = 0.0
var ram_cd: float = 0.0
var fx: WeaponFX = null
var _shove: Vector3 = Vector3.ZERO
var _shove_t: float = 0.0
var _prev_locked: bool = false
var _locked: bool = false
var _sk: Skeleton3D = null
var _anim: Node = null
var _lay: Tween = null
var _anchor: Node3D = null
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
var _connected: bool = false


func setup(b: PlayerBike, opts: Dictionary = {}) -> void:
	bike = b
	roam = opts.get("roam", null)
	fx = opts.get("fx", null)
	if opts.has("targets"):
		targets = opts["targets"]
	max_stability = float(opts.get("max_stability", BikeCombatData.STABILITY_MAX))
	stability = max_stability
	if bike and bike.rider_node:
		_sk = bike.rider_node.get_meta("skeleton", null) as Skeleton3D
		_anim = CharacterBuilder.get_animator(bike.rider_node)
	if bike and not _connected:
		bike.crash_occurred.connect(_on_crash)
		_connected = true


func _ready() -> void:
	process_priority = 11
	process_physics_priority = 2
	for i: int in 3:
		var p := AudioStreamPlayer3D.new()
		p.name = "BikeSfx%d" % i
		p.bus = WeaponAudio.bus()
		p.max_distance = 80.0
		p.unit_size = 6.0
		add_child(p)
		_sfx.append(p)


## Riding right now: the bike is in the tree, shown and processing, and (with a roam) the roam says mounted.
func riding() -> bool:
	if bike == null or not is_instance_valid(bike) or not bike.is_inside_tree():
		return false
	if not bike.visible or bike.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if roam != null and is_instance_valid(roam) and not bool(roam.get("mounted")):
		return false
	return true


func can_kick() -> bool:
	return enabled and riding() and not knocked and not bike.is_controls_locked and kick_cd <= 0.0 \
		and not (is_inside_tree() and get_tree().paused)


## Kick to side -1 (left) or +1 (right). false (a refusal when not riding / not enabled / knocked off; just false in the
## cooldown) when it cannot.
func kick(side: int) -> bool:
	if not enabled or not riding() or knocked or bike.is_controls_locked or (is_inside_tree() and get_tree().paused):
		refusals += 1
		return false
	if kick_cd > 0.0:
		return false
	kick_side = -1 if side < 0 else 1
	kick_t = 0.0
	kick_cd = BikeCombatData.KICK_COOLDOWN
	kick_done = false
	kicks += 1
	_cue("swish", bike.global_position + Vector3(0.0, 0.8, 0.0), -4.0)
	kicked.emit(kick_side)
	return true


func kicking() -> bool:
	return kick_t >= 0.0


## Bike frame on the map plane: [forward, right] (unit Vector2).
func bike_frame() -> Array[Vector2]:
	var z: Vector3 = bike.global_transform.basis.z
	var f := Vector2(-z.x, -z.z)
	f = f.normalized() if f.length_squared() > 1e-6 else Vector2(0.0, -1.0)
	return [f, Vector2(-f.y, f.x)]


## The kickable target the window would hit now on `side`, or null.
func kick_target(side: int) -> Node3D:
	var fr: Array[Vector2] = bike_frame()
	var p := Vector2(bike.global_position.x, bike.global_position.z)
	var best: Node3D = null
	var best_score: float = INF
	for t: Variant in targets:
		if not is_instance_valid(t) or not bool((t as Object).call("kickable")):
			continue
		var g: Vector3 = (t as Object).call("ground_pos")
		if absf(g.y - bike.global_position.y) > 2.5:
			continue
		var rel := Vector2(g.x, g.z) - p
		var lat: float = rel.dot(fr[1]) * float(side)
		var along: float = rel.dot(fr[0])
		if lat < BikeCombatData.KICK_MIN or lat > BikeCombatData.KICK_REACH or absf(along) > BikeCombatData.KICK_ALONG:
			continue
		var score: float = absf(lat - 1.4) + absf(along) * 0.5
		if score < best_score:
			best_score = score
			best = t
	return best


## Stability damage (from_side: +1 from the right, -1 from the left, 0 none). false when ignored (god, i-frames, off).
func damage(amount: float, cause: String, from_side: int = 0) -> bool:
	if not enabled or knocked or god or iframes > 0.0:
		return false
	stability = maxf(0.0, stability - amount)
	iframes = BikeCombatData.HURT_IFRAMES
	hurt_t = 0.0
	if bike:
		bike.add_camera_shake(0.55)
		if cause == "kick":
			bike.current_speed_ms *= 0.85
		if from_side != 0:
			var r: Vector2 = bike_frame()[1] * -float(from_side)
			_shove = Vector3(r.x, 0.0, r.y) * (BikeCombatData.SHOVE_M / BikeCombatData.SHOVE_S)
			_shove_t = BikeCombatData.SHOVE_S
		_cue("impact_heavy", bike.global_position + Vector3(0.0, 0.9, 0.0), -2.0)
	damaged.emit(amount, cause)
	if stability <= 0.0:
		knock_off()
	return true


func _on_crash() -> void:
	if enabled:
		damage(BikeCombatData.CRASH_DMG, "crash")


## Stability 0: the bike locks and lies on its side with the rider, daze stars.
func knock_off() -> void:
	if knocked:
		return
	knocked = true
	kick_t = -1.0
	_lock(true)
	if bike:
		bike.current_speed_ms *= 0.5
		if _lay and _lay.is_valid():
			_lay.kill()
		_lay = create_tween()
		_lay.tween_property(bike.visual_pivot, "rotation:z", 1.35, 0.35)
		_cue("bin_crash", bike.global_position, -2.0)
		_cue("groan", bike.global_position + Vector3(0.0, 0.5, 0.0), -3.0)
		if fx:
			_anchor = Node3D.new()
			_anchor.name = "KnockedStars"
			_anchor.top_level = true
			add_child(_anchor)
			var r: Vector2 = bike_frame()[1]
			_anchor.global_position = bike.global_position + Vector3(-r.x * 0.7, -1.5, -r.y * 0.7)
			fx.stars(_anchor, 6.0)
	knocked_off.emit()


## Full stability, upright and unlocked bike, no kick in progress (retry / stop).
func reset() -> void:
	stability = max_stability
	knocked = false
	kick_t = -1.0
	kick_cd = 0.0
	kick_done = false
	iframes = 0.0
	ram_cd = 0.0
	hurt_t = 99.0
	_shove_t = 0.0
	if _lay and _lay.is_valid():
		_lay.kill()
	_lay = null
	if bike and is_instance_valid(bike):
		bike.visual_pivot.rotation.z = 0.0
		if bike.rider_node and not _sk:
			bike.rider_node.rotation.z = 0.0
	if _anchor and is_instance_valid(_anchor):
		_anchor.queue_free()
	_anchor = null
	_lock(false)


func _lock(on: bool) -> void:
	if bike == null or not is_instance_valid(bike):
		_locked = false
		return
	if on and not _locked:
		_prev_locked = bike.is_controls_locked
		bike.is_controls_locked = true
		_locked = true
	elif not on and _locked:
		bike.is_controls_locked = _prev_locked
		_locked = false


func _physics_process(delta: float) -> void:
	if kick_cd > 0.0:
		kick_cd -= delta
	iframes -= delta
	ram_cd -= delta
	hurt_t += delta
	if kick_t >= 0.0:
		kick_t += delta
		if not kick_done and kick_t >= BikeCombatData.KICK_WINDUP:
			var t: Node3D = kick_target(kick_side) if kick_t <= BikeCombatData.KICK_ACTIVE_END and not knocked else null
			if t != null:
				kick_done = true
				hits += 1
				_log("hit")
				var away := Vector2(t.global_position.x - bike.global_position.x, t.global_position.z - bike.global_position.z)
				away = away.normalized() if away.length_squared() > 1e-4 else bike_frame()[1] * float(kick_side)
				(t as Object).call("take_kick", away)
				bike.add_camera_shake(0.3)
				kick_hit.emit(t, kick_side)
			elif kick_t > BikeCombatData.KICK_ACTIVE_END:
				kick_done = true
				misses += 1
				_log("miss")
				kick_missed.emit(kick_side)
		if kick_t >= BikeCombatData.KICK_DUR:
			kick_t = -1.0
	if enabled and not knocked and hurt_t >= BikeCombatData.REGEN_DELAY and stability < max_stability:
		stability = minf(max_stability, stability + BikeCombatData.REGEN_RATE * delta)
	if _shove_t > 0.0 and bike and is_instance_valid(bike):
		_shove_t -= delta
		bike.move_and_collide(_shove * delta)


func _log(r: String) -> void:
	results.append(r)
	if results.size() > 16:
		results.pop_front()


## Kick leg over the rider (rigged: bone layer after its RigAnimator, only on frames it ran; else a lean of the body).
func _process(_d: float) -> void:
	if bike == null or not is_instance_valid(bike) or bike.rider_node == null:
		return
	var w: float = 0.0 if knocked or kick_t < 0.0 else BikeCombatData.kick_weight(kick_t, BikeCombatData.KICK_WINDUP, BikeCombatData.KICK_ACTIVE_END, BikeCombatData.KICK_DUR)
	if _sk:
		if w > 0.001 and (_anim == null or int(_anim.get("_lod_skip")) == 1):
			CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.kick_pose(float(kick_side)), w)
	else:
		bike.rider_node.rotation.z = -float(kick_side) * 0.35 * w


func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo or (k.physical_keycode != KEY_Q and k.physical_keycode != KEY_E):
		return
	if not riding():
		return                             # on foot: Q / E belong to the Vovinam block / finisher and the markers
	kick(-1 if k.physical_keycode == KEY_Q else 1)
	get_viewport().set_input_as_handled()


func _cue(cue: String, at: Vector3, db: float = 0.0) -> void:
	if _sfx.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = WeaponAudio.stream(cue) if WeaponAudio.CUES.has(cue) else CineAudio.sfx(cue)
	p.volume_db = db
	p.global_position = at
	p.play()


func _exit_tree() -> void:
	if _lay and _lay.is_valid():
		_lay.kill()
	if bike and is_instance_valid(bike):
		if knocked:
			bike.visual_pivot.rotation.z = 0.0
		if _connected and bike.crash_occurred.is_connected(_on_crash):
			bike.crash_occurred.disconnect(_on_crash)
	_connected = false
	_lock(false)
