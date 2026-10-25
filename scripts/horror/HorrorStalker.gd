# File: res://scripts/horror/HorrorStalker.gd
# A sheep-masked clone that hunts the player (spec B-D3). Plain Node3D moved along a HorrorNavGraph (no physics body: the
# graph only has walkable straight edges), body = an identical student clone (CharacterBuilder, rigged) with the A2 sheep
# mask (CineFX.build_prop("sheep_mask")) on its Head bone.
# Senses (10 Hz, from HorrorSenses):
#   sight:   a 70° cone (35° each side of the facing), 14 m, 22 m when the flashlight is lit, a clear ray from the eyes to
#            the player's chest; a hidden player is never seen;
#   hearing: the player's noise radius (sprint 10 m, jog 6 m, walk on Ctrl 3 m; HorrorKit), through walls.
# States:
#   PATROL      walks its waypoint loop, pausing at each waypoint;
#   SUSPICIOUS  heard a noise: turns to it (0.6 s), walks there, looks around 3 s, back to PATROL;
#   CHASE       saw the player: runs straight to where the latest sight check saw it while that check saw it with a
#               clear floor line (within 10 m), else routes to the last known spot; arriving there without sight -> SEARCH;
#   SEARCH      wanders the nodes within 10 m of the last known spot for 15 s, then PATROL;
#   CHECK       saw the player enter a hiding spot (notice_hide): runs to it and checks it: caught if the player is still
#               inside; only this stalker can find a hidden player.
# Catch: within 1.2 m of a visible player with a clear ray (hit_from_inside: never from inside a wall) and no catch grace
# (HorrorSenses.grace, just after leaving a hiding spot) -> caught_player(self), then frozen until reset_at().
# SEARCH wanders the graph's wander nodes only (never the waypoints on a hiding spot's exit point).
# Per physics frame: one movement step and a distance check; rays only at 10 Hz or within catch range; no allocation
# except when it re-routes (at most every 0.5 s).
# Horror polish:
#   make_dolly() (H-D1, call before adding to the tree): Cừu Dolly's look (StoryCast "dolly": cream cardigan and cuff, the
#     sheep mask), speed_mult DOLLY_SPEED, and a positional music-box hum loop (StoryAudio "dolly_hum" on an
#     AudioStreamPlayer3D, HUM_MAX_M range, -6 dB with "Giảm hù dọa"); set_hum(on).
#   investigate_spot(spot) (H-D4): heard breathing or a gasp from a hiding spot: CHECK it (catches if the player is inside).
#   rush(p) (H-D5): the alarm: CHASE towards p without having seen the player (arriving without sight -> SEARCH as usual).
class_name HorrorStalker
extends Node3D

signal state_changed(old_state: String, new_state: String)
signal caught_player(stalker: HorrorStalker)

const PATROL: String = "PATROL"
const SUSPICIOUS: String = "SUSPICIOUS"
const CHASE: String = "CHASE"
const SEARCH: String = "SEARCH"
const CHECK: String = "CHECK"
const FOV_DEG: float = 70.0
const SIGHT: float = 14.0
const SIGHT_LIT: float = 22.0
const CATCH_R: float = 1.2
const SEARCH_S: float = 15.0
const SENSE_DT: float = 0.1
const EYE_Y: float = 1.6
const TARGET_Y: float = 1.2
const SPEEDS: Dictionary = {"PATROL": 1.4, "SUSPICIOUS": 2.2, "CHASE": 4.6, "SEARCH": 1.9, "CHECK": 4.6}
const TURN_RATE: float = 7.0
const SUS_TURN_S: float = 0.6
const LOOK_AROUND_S: float = 3.0
const PATROL_PAUSE_S: float = 1.2
const SEARCH_PAUSE_S: float = 1.4
const SAW_GRACE_S: float = 0.5
const REPATH_S: float = 0.5
const DIRECT_CHASE_R: float = 10.0
const SEARCH_RADIUS: float = 10.0
const STATE_LOG_MAX: int = 64
const WORLD_MASK: int = 1
## The clone look (identical for every stalker): student body, no backpack, the sheep mask on top.
const LOOK: Dictionary = {"preset": "student_m", "rigged": true, "seed": 4404, "female": false, "backpack": false,
	"glasses": false, "name": "Clone"}
## Dolly is a little faster than the clones (H-D1).
const DOLLY_SPEED: float = 1.12
const HUM_MAX_M: float = 32.0
const HUM_DB: float = -2.0

var graph: HorrorNavGraph = null
var senses: HorrorSenses = null
var patrol: PackedInt32Array = PackedInt32Array()
var state: String = PATROL
var state_log: Array[String] = []
var frozen: bool = false
## false: the owner calls step() itself (tests).
var auto_update: bool = true
var build_model: bool = true
var look: Dictionary = LOOK
var catch_enabled: bool = true
## Optional line-of-sight override (from: Vector3, to: Vector3) -> bool; default = a physics ray on the world layer.
var los_fn: Callable = Callable()
var last_known: Vector3 = Vector3.ZERO
var noise_pos: Vector3 = Vector3.ZERO
var check_spot: Node3D = null
var model: Node3D = null
var mask: Node3D = null
var yaw: float = 0.0
var speed_now: float = 0.0
var rng := RandomNumberGenerator.new()
## Movement speed factor (Dolly DOLLY_SPEED).
var speed_mult: float = 1.0
var is_dolly: bool = false
## Dolly's hum (null for the clones) and its "Giảm hù dọa" setting.
var hum: AudioStreamPlayer3D = null
var hum_reduced: bool = false
var hum_on: bool = false
## Rushing at the alarm (rush()); cleared by reset_at.
var rushing: bool = false

var _patrol_i: int = 0
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _wait: float = 0.0
var _state_t: float = 0.0
var _sense_acc: float = 0.0
var _since_seen: float = INF
var _repath_t: float = 0.0
var _sus_turn: float = 0.0
var _search_t: float = 0.0
var _arrived_t: float = -1.0
var _route_to: Vector3 = Vector3(INF, 0.0, INF)
var _caught: bool = false
var _sees_now: bool = false
var _direct_ok: bool = false
var _animator: Node = null


func _ready() -> void:
	if build_model and model == null:
		_build_model()
	if is_dolly and hum == null:
		_build_hum()
	set_process(is_dolly)


## Turns this stalker into Cừu Dolly (before it enters the tree): her look, a little faster, the hum.
func make_dolly(reduced: bool = false) -> void:
	is_dolly = true
	speed_mult = DOLLY_SPEED
	hum_reduced = reduced
	var o: Dictionary = StoryCast.opts("dolly")
	o["rigged"] = true
	o["name"] = "Dolly"
	look = o
	if is_inside_tree() and hum == null:
		_build_hum()


func _build_hum() -> void:
	hum = AudioStreamPlayer3D.new()
	hum.name = "DollyHum"
	hum.position = Vector3(0.0, 1.5, 0.0)
	hum.max_distance = HUM_MAX_M
	hum.unit_size = 4.0
	hum.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	hum.volume_db = hum_volume_db()
	if AudioServer.get_bus_index("SFX") != -1:
		hum.bus = "SFX"
	add_child(hum)
	StoryAudio.warm(["dolly_hum"])
	set_hum(true)


## Hum level before distance attenuation (dB): -6 dB with "Giảm hù dọa".
func hum_volume_db() -> float:
	return HUM_DB + (StoryAudio.REDUCED_DB if hum_reduced else 0.0)


## Starts or stops the hum (it starts once the cue is synthesized).
func set_hum(on: bool) -> void:
	hum_on = on
	if hum == null:
		return
	if not on:
		hum.stop()
	elif StoryAudio.ready_for(["dolly_hum"]):
		if hum.stream == null:
			hum.stream = StoryAudio.stream("dolly_hum")
		if not hum.playing:
			hum.play()


func _process(_delta: float) -> void:
	if hum != null and hum_on and not hum.playing:
		set_hum(true)   # waits for the warm task, then loops


func speed_of(st: String) -> float:
	return float(SPEEDS[st]) * speed_mult


func _build_model() -> void:
	model = CharacterBuilder.build(look)
	model.name = "Model"
	add_child(model)
	if is_dolly:
		StoryCast.attach_tells(model, false)   # her cream wool cuff
	_animator = CharacterBuilder.get_animator(model)
	mask = CineFX.build_prop("sheep_mask")
	mask.name = "SheepMask"
	var sks: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	var sk: Skeleton3D = sks[0] as Skeleton3D if not sks.is_empty() else null
	var hb: int = sk.find_bone("Head") if sk != null else -1
	if hb >= 0:
		var att := BoneAttachment3D.new()
		att.name = "MaskAttach"
		att.bone_name = "Head"
		sk.add_child(att)
		att.add_child(mask)
		var head: Transform3D = sk.global_transform * CharacterBuilder._bone_global_now(sk, hb)
		var bs: Basis = global_transform.basis.orthonormalized()
		mask.transform = head.affine_inverse() * Transform3D(bs, head.origin + bs * Vector3(0.0, 0.06, 0.0))
	else:
		model.add_child(mask)
		mask.position = Vector3(0.0, 1.62, 0.0)


## Graph, shared senses, the patrol loop (node ids) and the waypoint index to start on.
func setup(g: HorrorNavGraph, s: HorrorSenses, patrol_ids: PackedInt32Array, start_index: int = 0, seed_val: int = 0) -> void:
	graph = g
	senses = s
	patrol = patrol_ids
	rng.seed = seed_val
	if not patrol.is_empty():
		_patrol_i = posmod(start_index, patrol.size())
		position = graph.pos(patrol[_patrol_i])
		_advance_patrol()


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Faces a horizontal direction at once.
func face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length_squared() > 1e-8:
		yaw = atan2(-dir.x, -dir.z)
		rotation.y = yaw


func _physics_process(delta: float) -> void:
	if auto_update:
		step(delta)


# ---------------------------------------------------------------------------
# Senses
# ---------------------------------------------------------------------------
func _los(from: Vector3, to: Vector3) -> bool:
	if los_fn.is_valid():
		return bool(los_fn.call(from, to))
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	q.collide_with_areas = false
	q.hit_from_inside = true   # an origin inside a wall box never sees (or catches) through it
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Physics space for graph routing and walk checks (null with a los_fn mock or outside the tree: everything is clear).
func _space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state if is_inside_tree() and not los_fn.is_valid() else null


func _flat_to_player() -> Vector3:
	var d: Vector3 = senses.pos - global_position
	d.y = 0.0
	return d


func sight_range() -> float:
	return SIGHT_LIT if senses != null and senses.lit else SIGHT


## In the cone, in range and in clear view (a hidden player is never seen).
func can_see() -> bool:
	if senses == null or senses.hidden:
		return false
	var to: Vector3 = _flat_to_player()
	var d: float = to.length()
	if d > sight_range():
		return false
	if d > 0.3 and forward().angle_to(to / d) > deg_to_rad(FOV_DEG * 0.5):
		return false
	return _los(global_position + Vector3(0.0, EYE_Y, 0.0), senses.pos + Vector3(0.0, TARGET_Y, 0.0))


func can_hear() -> bool:
	if senses == null or senses.hidden or senses.noise <= 0.0:
		return false
	return _flat_to_player().length() <= senses.noise


## One sensing pass (10 Hz from step()).
func sense() -> void:
	if senses == null or frozen:
		return
	if can_see():
		_since_seen = 0.0
		last_known = senses.pos
		_sees_now = true
		# straight run only when the floor line is clear too (sight goes over desks, legs do not)
		_direct_ok = HorrorNavGraph.clear(_space(), global_position, senses.pos)
		if state == CHECK:
			check_spot = null   # it sees the player, who has already left the spot
		if state != CHASE:
			_set_state(CHASE)
			_repath_t = 0.0
		return
	_sees_now = false
	_direct_ok = false
	if can_hear():
		_on_noise(senses.pos)


## A noise from the level (a slammed door, the generator starting): reacts as if it heard the player there.
func hear_at(p: Vector3) -> void:
	_repath_t = 0.0   # a level event always re-routes, even right after another noise
	_on_noise(p)


func _on_noise(p: Vector3) -> void:
	noise_pos = Vector3(p.x, 0.0, p.z)
	match state:
		CHASE:
			last_known = noise_pos
		CHECK:
			pass
		SEARCH:
			last_known = noise_pos
			if _repath_t <= 0.0:
				_go(noise_pos)
				_wait = 0.0
				_repath_t = REPATH_S
		SUSPICIOUS:
			if _sus_turn <= 0.0 and _repath_t <= 0.0:
				_go(noise_pos)
				_arrived_t = -1.0
				_repath_t = REPATH_S
		_:
			_set_state(SUSPICIOUS)
			_sus_turn = SUS_TURN_S
			_arrived_t = -1.0
			_path.clear()
			_path_i = 0


## The player is about to hide in `spot`: a stalker that sees the player now (or lost sight of the chased player less than
## SAW_GRACE_S ago) remembers the spot and goes to check it. Returns true when it saw.
func notice_hide(spot: Node3D) -> bool:
	if frozen or senses == null:
		return false
	var saw: bool = can_see() or (state == CHASE and _since_seen <= SAW_GRACE_S)
	if not saw:
		return false
	check_spot = spot
	_set_state(CHECK)
	_go(_spot_point())
	_repath_t = 1.0
	return true


## Heard breathing or a gasp from `spot` (H-D4): goes to check it (catches the player if still inside). Returns true
## when it goes (not frozen, not already checking that spot).
func investigate_spot(spot: Node3D) -> bool:
	if frozen or senses == null or spot == null:
		return false
	if state == CHECK and check_spot == spot:
		return false
	check_spot = spot
	_set_state(CHECK)
	_go(_spot_point())
	_repath_t = 1.0
	return true


## The alarm (H-D5): runs towards p as if chasing (it has not seen the player: arriving without sight -> SEARCH).
## A stalker checking a spot or already seeing the player keeps doing that.
func rush(p: Vector3) -> void:
	if frozen or senses == null or state == CHECK or (state == CHASE and _sees_now):
		return
	rushing = true
	last_known = Vector3(p.x, 0.0, p.z)
	_since_seen = maxf(_since_seen, 1.0)
	if state != CHASE:
		_set_state(CHASE)
	_go(last_known)
	_repath_t = REPATH_S


func _spot_point() -> Vector3:
	if check_spot != null and is_instance_valid(check_spot) and check_spot.has_method("exit_point"):
		return check_spot.call("exit_point")
	return last_known


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------
func step(delta: float) -> void:
	if frozen or senses == null:
		_set_anim_speed(0.0)
		return
	_state_t += delta
	_since_seen += delta
	_repath_t -= delta
	_sense_acc += delta
	if _sense_acc >= SENSE_DT:
		_sense_acc -= SENSE_DT
		sense()
	speed_now = 0.0
	match state:
		PATROL:
			_do_patrol(delta)
		SUSPICIOUS:
			_do_suspicious(delta)
		CHASE:
			_do_chase(delta)
		SEARCH:
			_do_search(delta)
		CHECK:
			_do_check(delta)
	_check_catch()
	_set_anim_speed(speed_now)


func _set_anim_speed(v: float) -> void:
	if _animator != null:
		_animator.speed = v


func _do_patrol(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_scan(delta)
		return
	if _arrived():
		_wait = PATROL_PAUSE_S
		_advance_patrol()
		return
	_move(delta, speed_of(PATROL))


func _advance_patrol() -> void:
	if patrol.is_empty() or graph == null:
		return
	_patrol_i = (_patrol_i + 1) % patrol.size()
	_go(graph.pos(patrol[_patrol_i]))


func _do_suspicious(delta: float) -> void:
	if _sus_turn > 0.0:
		_sus_turn -= delta
		_turn_toward(noise_pos - global_position, delta)
		if _sus_turn <= 0.0:
			_go(noise_pos)
			_repath_t = REPATH_S
		return
	if not _arrived():
		_move(delta, speed_of(SUSPICIOUS))
		return
	if _arrived_t < 0.0:
		_arrived_t = _state_t
	_scan(delta)
	if _state_t - _arrived_t >= LOOK_AROUND_S:
		_back_to_patrol()


func _do_chase(delta: float) -> void:
	# straight at the player only while the latest sight check saw it with a clear floor line, and only towards the
	# position that check saw (never the live position between checks: no corner cutting through door jambs)
	var to: Vector3 = last_known - global_position
	to.y = 0.0
	if _sees_now and _direct_ok and not senses.hidden and to.length() < DIRECT_CHASE_R:
		var d: float = to.length()
		if d > 0.05:
			var stp: float = minf(speed_of(CHASE) * delta, d)
			global_position += to / d * stp
			_turn_toward(to, delta)
			speed_now = speed_of(CHASE)
		_path.clear()
		_path_i = 0
		return
	if _path.is_empty() or (_repath_t <= 0.0 and last_known.distance_to(_route_to) > 1.0):
		_go(last_known)
		_repath_t = REPATH_S
	if _arrived():
		if _since_seen > 0.3:
			_set_state(SEARCH)
		return
	_move(delta, speed_of(CHASE))


func _do_search(delta: float) -> void:
	_search_t += delta
	if _search_t >= SEARCH_S:
		_back_to_patrol()
		return
	if _wait > 0.0:
		_wait -= delta
		_scan(delta)
		return
	if _arrived():
		_wait = SEARCH_PAUSE_S
		var near: PackedInt32Array = graph.nodes_within(last_known, SEARCH_RADIUS, true) if graph != null else PackedInt32Array()
		if near.is_empty():
			_path.clear()
		else:
			_go(graph.pos(near[rng.randi_range(0, near.size() - 1)]))
		return
	_move(delta, speed_of(SEARCH))


func _do_check(delta: float) -> void:
	var target: Vector3 = _spot_point()
	if _repath_t <= 0.0:
		_go(target)
		_repath_t = 1.0
	_move(delta, speed_of(CHECK))
	var d: Vector3 = target - global_position
	d.y = 0.0
	if d.length() <= CATCH_R:
		if senses.hidden and senses.spot == check_spot and catch_enabled:
			if check_spot != null and check_spot.has_method("reveal"):
				check_spot.call("reveal")
			_catch()
		else:   # the player left (or catching is off): search from here
			check_spot = null
			last_known = global_position
			_set_state(SEARCH)


func _check_catch() -> void:
	if not catch_enabled or _caught or senses == null or senses.hidden or senses.grace > 0.0:
		return
	var d: Vector3 = senses.pos - global_position
	if absf(d.y) > 1.5 or Vector2(d.x, d.z).length() > CATCH_R:
		return
	if _los(global_position + Vector3(0.0, TARGET_Y, 0.0), senses.pos + Vector3(0.0, TARGET_Y, 0.0)):
		_catch()


func _catch() -> void:
	if _caught or not catch_enabled:
		return
	_caught = true
	frozen = true
	speed_now = 0.0
	caught_player.emit(self)


func is_catching() -> bool:
	return _caught


func _back_to_patrol() -> void:
	check_spot = null
	if not patrol.is_empty() and graph != null:
		var best: int = 0
		var bd: float = INF
		for i: int in patrol.size():
			var dd: float = graph.pos(patrol[i]).distance_squared_to(global_position)
			if dd < bd:
				bd = dd
				best = i
		_patrol_i = best
		_go(graph.pos(patrol[_patrol_i]))
	_wait = 0.0
	_set_state(PATROL)


func _set_state(s: String) -> void:
	if s == state:
		return
	var old: String = state
	state = s
	_state_t = 0.0
	_arrived_t = -1.0
	if s == SEARCH:
		_search_t = 0.0
		_wait = 1.0
		_path.clear()
		_path_i = 0
	state_log.append(s)
	if state_log.size() > STATE_LOG_MAX:
		state_log.remove_at(0)
	state_changed.emit(old, s)


## Puts the stalker back on its loop at p (retry), unfrozen, patrolling.
func reset_at(p: Vector3) -> void:
	if is_inside_tree():
		global_position = Vector3(p.x, 0.0, p.z)
	else:
		position = Vector3(p.x, 0.0, p.z)
	_caught = false
	frozen = false
	rushing = false
	check_spot = null
	_since_seen = INF
	_sees_now = false
	_direct_ok = false
	_wait = 0.5
	_sus_turn = 0.0
	_path.clear()
	_path_i = 0
	if state != PATROL:
		_set_state(PATROL)
	if not patrol.is_empty() and graph != null:
		var best: int = 0
		var bd: float = INF
		for i: int in patrol.size():
			var dd: float = graph.pos(patrol[i]).distance_squared_to(p)
			if dd < bd:
				bd = dd
				best = i
		_patrol_i = best
		_advance_patrol()


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------
func _go(target: Vector3) -> void:
	_route_to = target
	if graph == null:
		_path = PackedVector3Array([Vector3(target.x, 0.0, target.z)])
	else:
		_path = graph.route(global_position if is_inside_tree() else position, target, _space())
	_path_i = 0


func _arrived() -> bool:
	return _path_i >= _path.size()


func _move(delta: float, speed: float) -> void:
	var budget: float = speed * delta
	while budget > 0.0 and _path_i < _path.size():
		var tgt: Vector3 = _path[_path_i]
		var d: Vector3 = tgt - global_position
		d.y = 0.0
		var dist: float = d.length()
		if dist < 0.05:
			_path_i += 1
			continue
		var stp: float = minf(budget, dist)
		global_position += d / dist * stp
		budget -= stp
		_turn_toward(d, delta)
		speed_now = speed
		if stp >= dist - 0.0001:
			_path_i += 1


func _turn_toward(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 1e-8:
		return
	var want: float = atan2(-dir.x, -dir.z)
	yaw += clampf(wrapf(want - yaw, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta)
	rotation.y = yaw


## Slow look-around while waiting.
func _scan(delta: float) -> void:
	yaw += sin(_state_t * 1.3) * 1.1 * delta
	rotation.y = yaw
