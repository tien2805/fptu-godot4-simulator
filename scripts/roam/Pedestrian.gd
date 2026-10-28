# File: res://scripts/roam/Pedestrian.gd
# Người đi đường FreeRoam: thân CharacterBuilder (rigged; đầu PS2 ở phong cách Vice City), đi theo PedWalkGraph với kiểu
# đi walk / jog / stroll, thỉnh thoảng đứng lại; tự đo va chạm với người chơi (đi bộ) / xe (khi cưỡi) bằng khoảng cách và
# phản ứng: va nhẹ -> STUMBLE (lảo đảo, né 0.6 m), nước rút > 6 m/s -> KNOCKDOWN (ngã rồi đứng dậy, bỏ chạy),
# xe > 3 m/s -> KNOCKDOWN văng 2..4 m; mỗi lần một câu càu nhàu (spawner giới hạn nhịp). Không phạt gì.
# Tầng giữa (lod_far, PedestrianSpawner đặt): trượt theo đồ thị không vật lý, không đo va chạm, không tách đám.
# Danh tính (identity) giữ nguyên khi đổi tầng: preset / seed / female quyết định mô hình (model_opts), profile / wseed
# quyết định cách đi. Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
# Phase W (spec 2026-10-23-phase-w-weapons-wanted-design.md, W-D3): take_hit(info) – weapons knock people out (comic
# stars by WeaponFX, up after 6-10 s, then they flee), launch them along a ballistic arc (explosion, shotgun), make them
# pinch their nose (stink) or dance / get pushed (loa), or just scare them. Nobody dies; a mid-tier person is promoted.
class_name Pedestrian
extends CharacterBody3D

signal hit(ped: Pedestrian, kind: String)

enum State { WALK, IDLE, STUMBLE, KNOCKDOWN, FLEE, KNOCKED_OUT, LAUNCHED, STINK, DANCE, REACT }

const RADIUS: float = 0.28
const HEIGHT: float = 1.7
const GRAVITY: float = 20.0
## Khoảng tốc độ (m/s) theo kiểu đi (spec Amendment: người chạy bộ ~2.5 m/s, người tản bộ ~0.8 m/s).
const PROFILES: Dictionary = {"walk": [1.1, 1.6], "jog": [2.4, 2.8], "stroll": [0.7, 0.9]}
const FLEE_SPEED: float = 3.2
const STUMBLE_TIME: float = 0.8
const STUMBLE_DECEL: float = 6.0
const FALL_TIME: float = 1.2
const GETUP_TIME: float = 0.9
const FLEE_TIME: float = 3.0
const THROW_TIME: float = 0.5
const THROW_KEEP: float = 0.75           # tốc văng = quãng / THROW_TIME x 0,75, rồi hãm THROW_DECEL: tổng ~ quãng văng
const THROW_DECEL: float = 16.0
const HIT_COOLDOWN: float = 1.0
const SIDESTEP_M: float = 0.6
const STUCK_TIME: float = 3.0
const STUCK_RECYCLE: float = 10.0
const SEPARATION_R: float = 1.2
const SEPARATION_EVERY: int = 4          # tính lực tách đám mỗi 4 khung vật lý (lệch pha theo wseed)
const SNAP_EVERY: int = 30               # tầng giữa: đặt lại lên mặt sàn mỗi 30 khung vật lý
const STEP_HEIGHT: float = 0.35          # bậc lề 0,12-0,15 m, bậc sân campus tới 0,32 m (như ThirdPersonController)
const PLAYER_RADIUS: float = 0.4
const BIKE_RADIUS: float = 0.6
const BIKE_HALF_AXIS: float = 0.355      # PlayerBike.tscn: capsule r 0,42 cao 1,55 nằm dọc Z -> trục ±0,355 m quanh gốc xe
const MIN_HIT_SPEED: float = 0.5         # người chơi / xe gần như đứng yên: người đi đường tự né, không phản ứng
const SPRINT_HIT_SPEED: float = 6.0
const BIKE_HIT_SPEED: float = 3.0
const IDLE_CHANCE: float = 0.1
const ARRIVE_R: float = 0.6
## Phase W weapon reactions (W-D3: nobody dies – knocked out, up after KO_MIN..KO_MAX s, then flee).
const KO_MIN: float = 6.0
const KO_MAX: float = 10.0
const FLEE_HIT_TIME: float = 6.0          # bỏ chạy sau phản ứng vũ khí (va chạm thường: FLEE_TIME 3 s)
const STINK_TIME: float = 2.5
const DANCE_TIME: float = 2.0
const DANCE_CHANCE: float = 0.35
const PUNCH_STEP_M: float = 0.25          # cú đấm 1-2 của combo: lùi 0,25 m (đòn 3 vẫn trong tầm với)
const PUSH_DECEL: float = 8.0
const LAUNCH_MAX_S: float = 4.0
const LAUNCH_SPIN: float = 9.0            # rad/s quanh trục đứng khi bay
const LAND_MIN_S: float = 0.15
const PED_LINES: Dictionary = {
	"bump": ["Ê, nhìn đường chứ bạn!", "Đi đứng kiểu gì vậy trời...", "Từ từ thôi, trễ học hả?", "Xin lỗi một tiếng coi!"],
	"sprint": ["Chạy deadline hả em?!", "Ối giời ơi, đụng người ta rồi!", "Thanh niên gì mà hấp tấp vậy!", "Điểm danh trễ cũng đâu cần chạy vậy!"],
	"bike": ["Trời đất ơi, chạy xe kiểu gì vậy!", "Có bằng lái không đó?!", "Đi chậm lại giùm cái!", "Gọi bảo vệ bây giờ!"],
}

var graph: PedWalkGraph
var model: Node3D
var identity: Dictionary = {}
var state: int = State.WALK
var walk_speed: float = 1.3
var target_node: int = -1
var prev_node: int = -1
var player: Node3D
var bike: Node3D
var mounted_fn: Callable
var crowd: Array = []
var spawner: Node
var lod_far: bool = false
var hits: Array[String] = []
var stuck_out: bool = false
var _t: float = 0.0
var _cool: float = 0.0
var _stuck_t: float = 0.0
var _stuck_total: float = 0.0
var _last_pos: Vector3
var _has_last: bool = false
var _throw_v: Vector3 = Vector3.ZERO
var _away: Vector3 = Vector3.ZERO
var _getting_up: bool = false
var _idle_left: float = 0.0
var _walked: int = 0
var _sep: Vector3 = Vector3.ZERO
var _sep_phase: int = 0
var _rng := RandomNumberGenerator.new()
var ko_left: float = 0.0
var flee_left: float = FLEE_TIME
var _push_v: Vector3 = Vector3.ZERO
var _flee_src: Vector3 = Vector3.ZERO
## Phase W emotes: reacting to the player's emote (clap / shout / film / look), then back to the previous state.
var react_kind: String = ""
var react_left: float = 0.0
var _react_prev: int = State.WALK
var _react_prop: Node3D = null


## Tuỳ chọn CharacterBuilder.build() của một danh tính (dùng chung với bake người nộm của CrowdImpostors).
static func model_opts(ident: Dictionary) -> Dictionary:
	var o: Dictionary = {"preset": String(ident.get("preset", "student")), "seed": int(ident.get("seed", 0)), "rigged": true}
	if ident.has("female"):
		o["female"] = bool(ident["female"])
	return o


## Tốc độ đi (m/s) theo kiểu đi và wseed – cố định, nên người nộm và người đi đường cùng danh tính đi cùng tốc độ.
static func speed_for(profile: String, wseed: int) -> float:
	var lim: Array = PROFILES.get(profile, PROFILES["walk"])
	var r := RandomNumberGenerator.new()
	r.seed = wseed * 7919 + 17
	return r.randf_range(float(lim[0]), float(lim[1]))


## Dựng (lần đầu) hoặc đặt lại (người trong pool của spawner) một người đi đường; gọi khi chưa ở trong cây.
## Mô hình chỉ dựng lại khi preset / seed / female khác mô hình đang có.
func setup(g: PedWalkGraph, node: int, ident: Dictionary) -> void:
	graph = g
	identity = ident.duplicate()
	identity["profile"] = String(identity.get("profile", "walk"))
	identity["wseed"] = int(identity.get("wseed", int(identity.get("seed", 0))))
	identity["wid"] = int(identity.get("wid", -1))
	identity["v"] = int(identity.get("v", -1))
	_rng.seed = int(identity["wseed"])
	walk_speed = speed_for(String(identity["profile"]), int(identity["wseed"]))
	_sep_phase = int(identity["wseed"]) % SEPARATION_EVERY
	prev_node = node
	target_node = node
	if react_kind != "":
		_end_react()                         # recycled mid-reaction: no phone left on the reused body
	state = State.WALK
	velocity = Vector3.ZERO
	hits.clear()
	stuck_out = false
	lod_far = false
	collision_layer = 1
	_t = 0.0
	_cool = 0.0
	_stuck_t = 0.0
	_stuck_total = 0.0
	_has_last = false
	_throw_v = Vector3.ZERO
	_getting_up = false
	_walked = 0
	_sep = Vector3.ZERO
	ko_left = 0.0
	flee_left = FLEE_TIME
	_push_v = Vector3.ZERO
	if _react_prop:
		_react_prop.queue_free()
		_react_prop = null
	react_kind = ""
	floor_snap_length = 0.4
	if get_node_or_null("Capsule") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Capsule"
		var cap := CapsuleShape3D.new()
		cap.radius = RADIUS
		cap.height = HEIGHT
		cs.shape = cap
		cs.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
		add_child(cs)
	var key: String = "%s|%d|%s" % [String(identity.get("preset", "student")), int(identity.get("seed", 0)), str(identity.get("female", "-"))]
	if model != null and String(model.get_meta("ped_key", "")) == key:
		CharacterBuilder.stop_clip(model)
		CharacterBuilder.set_expression(model, "open")
		CharacterBuilder.set_speed(model, 0.0)
		_shadows(true)
		return
	if model != null:
		model.free()
	var o: Dictionary = model_opts(identity)
	o["name"] = "Model"
	model = CharacterBuilder.build(o)
	model.set_meta("ped_key", key)
	add_child(model)


## Đổi tầng (PedestrianSpawner): tầng giữa không vật lý, không va chạm, không đổ bóng; về tầng gần thì đặt lại lên sàn.
func set_far(far: bool) -> void:
	if far == lod_far:
		return
	lod_far = far
	_shadows(not far)
	# tầng giữa không phản ứng va chạm nên cũng không được là capsule cứng chắn người chơi / xe
	if far:
		collision_layer = 0
	elif not is_down():
		collision_layer = 1
	if not far:
		snap_to_floor()


## Đặt lại độ cao lên mặt sàn ngay dưới chân (về tầng gần, và định kỳ ở tầng giữa).
func snap_to_floor() -> void:
	if not is_inside_tree():
		return
	var rq := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.0, 0.0), global_position - Vector3(0.0, 1.5, 0.0))
	rq.exclude = [get_rid()]
	rq.collide_with_areas = false
	var hit_info: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
	if not hit_info.is_empty():
		global_position.y = (hit_info["position"] as Vector3).y + 0.02
		velocity.y = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	match state:
		State.WALK, State.FLEE:
			_walk(delta)
		State.IDLE:
			_idle(delta)
		State.STUMBLE:
			_stumble(delta)
		State.KNOCKDOWN:
			_knockdown(delta)
		State.KNOCKED_OUT:
			_knocked_out(delta)
		State.LAUNCHED:
			_launched(delta)
		State.STINK:
			_stinking(delta)
		State.DANCE:
			_dancing(delta)
		State.REACT:
			_reacting(delta)
	_check_contacts()


# ---------------------------------------------------------------------------
# VA CHẠM
# ---------------------------------------------------------------------------
func _check_contacts() -> void:
	if lod_far or _cool > 0.0 or is_down():
		return
	var mounted: bool = bool(mounted_fn.call()) if mounted_fn.is_valid() else false
	var other: Node3D = bike if mounted else player
	if other == null or not other.is_inside_tree():
		return
	var r: float = (BIKE_RADIUS if mounted else PLAYER_RADIUS) + RADIUS + 0.05
	var d := Vector2(global_position.x - other.global_position.x, global_position.z - other.global_position.z)
	if mounted:
		# xe máy là capsule nằm dọc hướng xe: đo tới đoạn trục của nó, không tới gốc (đầu xe nhô 0,78 m trước gốc)
		var f3: Vector3 = -other.global_basis.z
		var f := Vector2(f3.x, f3.z).normalized()
		d -= f * clampf(d.dot(f), -BIKE_HALF_AXIS, BIKE_HALF_AXIS)
	if d.length() > r or absf(global_position.y - other.global_position.y) > 1.2:
		return
	var speed: float = absf(float(other.get("current_speed_ms")) if mounted else float(other.get("horizontal_speed")))
	if speed < MIN_HIT_SPEED:
		return
	var away: Vector3 = Vector3(d.x, 0.0, d.y).normalized() if d.length() > 0.01 else Vector3.FORWARD
	var kind: String
	if mounted:
		kind = "bike" if speed > BIKE_HIT_SPEED else "bump"
	else:
		kind = "sprint" if speed > SPRINT_HIT_SPEED else "bump"
	_cool = HIT_COOLDOWN
	react(kind, away, speed)
	hit.emit(self, kind)


func react(kind: String, away: Vector3, speed: float) -> void:
	if state == State.REACT:
		_end_react()                         # bumped while reacting to an emote: drop the phone, free the head look
	hits.append(kind)
	_away = away
	_t = 0.0
	if kind == "bump":
		state = State.STUMBLE
		var v0: float = sqrt(2.0 * STUMBLE_DECEL * SIDESTEP_M)   # trượt ngang đúng SIDESTEP_M rồi dừng
		velocity.x = away.x * v0
		velocity.z = away.z * v0
		CharacterBuilder.play(model, "stumble")
		CharacterBuilder.set_expression(model, "angry")
	else:
		state = State.KNOCKDOWN
		_getting_up = false
		var throw: float = clampf(2.0 + (speed - BIKE_HIT_SPEED) * 0.25, 2.0, 4.0) if kind == "bike" else 0.8
		_throw_v = away * (throw / THROW_TIME * THROW_KEEP) + Vector3(0.0, 3.0 if kind == "bike" else 0.0, 0.0)
		model.rotation.y = atan2(away.x, away.z)   # nhìn về phía cú va: ngã ngửa ra xa nó
		collision_layer = 0                         # đang ngã: xe / người đi qua được
		CharacterBuilder.play(model, "knockdown")
		CharacterBuilder.set_expression(model, "pain")
	if spawner and spawner.has_method("request_line"):
		spawner.request_line(self, kind)


# ---------------------------------------------------------------------------
# TRẠNG THÁI
# ---------------------------------------------------------------------------
func _walk(delta: float) -> void:
	if target_node < 0 or graph == null or graph.node_count() == 0:
		state = State.IDLE
		_idle_left = 2.0
		return
	var tp: Vector3 = graph.node_pos(target_node)
	var to := Vector3(tp.x - global_position.x, 0.0, tp.z - global_position.z)
	if to.length() < ARRIVE_R:
		_arrive()
		return
	if not lod_far and (Engine.get_physics_frames() + _sep_phase) % SEPARATION_EVERY == 0:
		_sep = _separation()
	var dir: Vector3 = (to.normalized() + (Vector3.ZERO if lod_far else _sep * 0.8)).normalized()
	var sp: float = FLEE_SPEED if state == State.FLEE else walk_speed
	velocity.x = dir.x * sp + _push_v.x
	velocity.z = dir.z * sp + _push_v.z
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	if lod_far:
		velocity.y = 0.0
		global_position += Vector3(velocity.x, 0.0, velocity.z) * delta
		if (Engine.get_physics_frames() + _sep_phase * 7) % SNAP_EVERY == 0:
			snap_to_floor()
	else:
		_gravity(delta)
		if is_on_wall() and _wall_is_low_static():
			_try_step_up(dir, delta)
		move_and_slide()
	_face(dir, delta)
	CharacterBuilder.set_speed(model, sp)
	_stuck_check(delta)
	if state == State.FLEE and _t >= flee_left:
		state = State.WALK


func _arrive() -> void:
	var nxt: int = graph.next_node(target_node, prev_node, _rng)
	if nxt == target_node:
		# nút cô lập (bậc 0, ví dụ bị block_near cắt): không có đường đi, cho spawner thu hồi thay vì đứng "tới nơi" mãi
		stuck_out = true
		return
	prev_node = target_node
	target_node = nxt
	_walked += 1
	# không dừng ở nút đầu tiên (vừa xuất hiện); người chạy bộ không dừng
	if state == State.WALK and _walked > 1 and String(identity.get("profile", "walk")) != "jog" and _rng.randf() < IDLE_CHANCE:
		state = State.IDLE
		_idle_left = _rng.randf_range(2.0, 6.0)
		CharacterBuilder.set_speed(model, 0.0)
		if _rng.randf() < 0.5:
			CharacterBuilder.play(model, "phone_stand", _idle_left)


func _idle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if lod_far:
		velocity.y = 0.0
	else:
		_gravity(delta)
		move_and_slide()
	_idle_left -= delta
	if _idle_left <= 0.0:
		CharacterBuilder.stop_clip(model)
		state = State.WALK


func _stumble(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, STUMBLE_DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, STUMBLE_DECEL * delta)
	_gravity(delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= STUMBLE_TIME:
		state = State.WALK
		CharacterBuilder.set_expression(model, "open")


func _knockdown(delta: float) -> void:
	_gravity(delta)
	if _t < THROW_TIME:
		velocity.x = _throw_v.x
		velocity.z = _throw_v.z
		if _throw_v.y > 0.0 and _t < delta * 1.5:
			velocity.y = _throw_v.y   # đặt sau _gravity: đang chạm đất vẫn bật lên được (cú văng của xe)
	else:
		velocity.x = move_toward(velocity.x, 0.0, THROW_DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, THROW_DECEL * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= FALL_TIME and not _getting_up:
		_getting_up = true
		CharacterBuilder.play(model, "getup")
	if _t >= FALL_TIME + GETUP_TIME:
		_getting_up = false
		_throw_v = Vector3.ZERO
		collision_layer = 1
		CharacterBuilder.set_expression(model, "open")
		# bỏ chạy: chọn nút kề xa người chơi nhất
		flee_from(player.global_position if player else global_position, FLEE_TIME)


# ---------------------------------------------------------------------------
# PHASE W: PHẢN ỨNG VŨ KHÍ
# ---------------------------------------------------------------------------
## Weapon hit (Phase W, spec section 3). info:
##   "kind": "punch" (1st / 2nd hit of a punch combo: stumble) | "melee" | "bullet" | "bonk" (knock out) | "pellet" |
##           "blast" (launch with info "vel") | "stink" | "sonic" (push along info "dir" at info "power" m/s; info "dance"
##           forces the dance roll) | "scare" (flee only);
##   "from": Vector3 source position; "ko": knock-out seconds (default random KO_MIN..KO_MAX).
## A mid-tier pedestrian is promoted first. Returns "knocked_out" | "launched" | "stink" | "dance" | "pushed" | "flee" |
## "stumble" | "none" (already down).
func take_hit(info: Dictionary) -> String:
	if is_down():
		return "none"
	if state == State.REACT:
		_end_react()
		state = State.WALK
	if lod_far:
		set_far(false)
	var kind: String = String(info.get("kind", "melee"))
	var from: Vector3 = info.get("from", global_position)
	var away: Vector3 = _flat_dir(global_position - from)
	_flee_src = from
	match kind:
		"punch":
			react("bump", away, 1.0)
			var v0: float = sqrt(2.0 * STUMBLE_DECEL * PUNCH_STEP_M)
			velocity.x = away.x * v0
			velocity.z = away.z * v0
			return "stumble"
		"melee", "bullet", "bonk":
			knock_out(float(info.get("ko", _rng.randf_range(KO_MIN, KO_MAX))), away)
			return "knocked_out"
		"pellet", "blast":
			launch(info.get("vel", away * 6.0 + Vector3(0.0, 5.0, 0.0)), float(info.get("ko", _rng.randf_range(KO_MIN, KO_MAX))))
			return "launched"
		"stink":
			if state == State.STINK:
				return "stink"
			state = State.STINK
			_t = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
			CharacterBuilder.play(model, "facepalm", STINK_TIME)
			CharacterBuilder.set_expression(model, "done")
			hits.append("stink")
			return "stink"
		"sonic":
			_push_v = _flat_dir(info.get("dir", away)) * float(info.get("power", 5.0))
			if state == State.DANCE or state == State.FLEE:
				return "pushed"
			var dance: bool = bool(info["dance"]) if info.has("dance") else _rng.randf() < DANCE_CHANCE
			if dance:
				state = State.DANCE
				_t = 0.0
				CharacterBuilder.play(model, "cheer", DANCE_TIME)
				CharacterBuilder.set_expression(model, "happy")
				hits.append("dance")
				return "dance"
			flee_from(from, FLEE_HIT_TIME)
			hits.append("pushed")
			return "pushed"
		"scare":
			if state == State.STINK or state == State.DANCE:
				return "none"                    # already reacting; they flee when it ends
			if state != State.FLEE:
				flee_from(from, FLEE_HIT_TIME)
			return "flee"
	return "none"


## Knocked out on the spot (WeaponFX draws the comic stars): lies down `secs`, gets up (GETUP_TIME), then flees.
func knock_out(secs: float, away: Vector3) -> void:
	state = State.KNOCKED_OUT
	ko_left = maxf(secs, GETUP_TIME + 0.1)
	_t = 0.0
	_getting_up = false
	_push_v = Vector3.ZERO
	velocity = Vector3(away.x, 0.0, away.z) * 1.5
	collision_layer = 0
	if away.length_squared() > 0.0001:
		model.rotation.y = atan2(away.x, away.z)   # nhìn về phía cú đánh: ngã ngửa ra xa nó
	CharacterBuilder.play(model, "knockdown")
	CharacterBuilder.set_expression(model, "pain")
	hits.append("ko")


## Thrown along a ballistic arc (explosion, shotgun), spinning; lands knocked out for `ko` seconds.
func launch(vel: Vector3, ko: float) -> void:
	state = State.LAUNCHED
	velocity = vel
	ko_left = ko
	_t = 0.0
	_push_v = Vector3.ZERO
	collision_layer = 0
	CharacterBuilder.play(model, "fall_flail")
	CharacterBuilder.set_expression(model, "surprised")
	hits.append("launched")


## Run away from `src` for `secs`: the next node is the neighbour farthest from src.
func flee_from(src: Vector3, secs: float) -> void:
	state = State.FLEE
	_t = 0.0
	flee_left = secs
	_flee_src = src
	CharacterBuilder.stop_clip(model)
	if graph and target_node >= 0:
		var best: int = target_node
		var best_d: float = -1.0
		for v: int in graph.neighbours(target_node):
			var d: float = graph.node_pos(v).distance_to(src)
			if d > best_d:
				best_d = d
				best = v
		prev_node = target_node
		target_node = best


func is_down() -> bool:
	return state == State.KNOCKDOWN or state == State.KNOCKED_OUT or state == State.LAUNCHED


func _knocked_out(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, THROW_DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, THROW_DECEL * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	ko_left -= delta
	if ko_left <= GETUP_TIME and not _getting_up:
		_getting_up = true
		CharacterBuilder.play(model, "getup")
	if ko_left <= 0.0:
		_getting_up = false
		collision_layer = 0 if lod_far else 1
		CharacterBuilder.set_expression(model, "open")
		flee_from(_flee_src, FLEE_HIT_TIME)


func _launched(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	model.rotation.y += LAUNCH_SPIN * delta
	CharacterBuilder.set_speed(model, 0.0)
	if (_t >= LAND_MIN_S and is_on_floor() and velocity.y <= 0.0) or _t >= LAUNCH_MAX_S:
		knock_out(ko_left, _flat_dir(Vector3(velocity.x, 0.0, velocity.z)))


func _stinking(delta: float) -> void:
	_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, STUMBLE_DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, STUMBLE_DECEL * delta)
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= STINK_TIME:
		flee_from(_flee_src, FLEE_HIT_TIME)


func _dancing(delta: float) -> void:
	_gravity(delta)
	_push_v = _push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	velocity.x = _push_v.x
	velocity.z = _push_v.z
	move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	if _t >= DANCE_TIME:
		flee_from(_flee_src, FLEE_HIT_TIME)


## Can react to an emote: walking or standing only (not fleeing, down, stinking, dancing or already reacting).
func can_react_emote() -> bool:
	return state == State.WALK or state == State.IDLE


## React to the player's emote from `from` for `secs`: "clap" (cheer clip), "shout" (wave; the bubble and the cue come
## from EmoteDirector), "film" (phone_stand + a glowing phone prop), "look" (turns the head). Then resumes its state.
func react_emote(kind: String, from: Vector3, secs: float) -> bool:
	if not can_react_emote():
		return false
	_react_prev = state
	state = State.REACT
	react_kind = kind
	react_left = secs
	velocity.x = 0.0
	velocity.z = 0.0
	var d: Vector3 = _flat_dir(from - global_position)
	model.rotation.y = atan2(-d.x, -d.z)
	match kind:
		"clap":
			CharacterBuilder.play(model, "cheer", secs)
		"shout":
			CharacterBuilder.play(model, "wave", secs)
		"film":
			CharacterBuilder.play(model, "phone_stand", secs)
			_react_prop = CineFX.build_prop("phone")
			_react_prop.name = "Phone"
			model.add_child(_react_prop)
			_react_prop.position = Vector3(0.12, 1.3, -0.3)
			CineFX.set_prop_glow(_react_prop, true)
		_:
			CharacterBuilder.look_at_point(model, from + Vector3(0.0, 1.5, 0.0))
	hits.append("react_" + kind)
	return true


func _reacting(delta: float) -> void:
	if not lod_far:
		_gravity(delta)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
	CharacterBuilder.set_speed(model, 0.0)
	react_left -= delta
	if react_left <= 0.0:
		_end_react()
		state = _react_prev


## Ends an emote reaction now and resumes the previous state (the bike's horn melody stopped early, spec owner-bike
## OB-D4). false when not reacting.
func end_react() -> bool:
	if state != State.REACT:
		return false
	_end_react()
	state = _react_prev
	return true


func _end_react() -> void:
	if _react_prop:
		_react_prop.queue_free()
		_react_prop = null
	react_kind = ""
	CharacterBuilder.stop_clip(model)
	CharacterBuilder.look_at_point(model, null)


## Horizontal unit direction of v; +Z when v is (almost) vertical or zero.
static func _flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-6 else Vector3(0.0, 0.0, 1.0)


# ---------------------------------------------------------------------------
# PHỤ TRỢ
# ---------------------------------------------------------------------------
func _gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))


## Bước lên bậc thấp khi đang bị chặn (lề, bậc sân campus), như ThirdPersonController._try_step_up.
## Phase W (performance gate): only a low static contact (kerb, step) is worth the step-up probes; bumping into people,
## officers, vehicles or a building wall (contact higher than STEP_HEIGHT above the feet) costs no test_move.
func _wall_is_low_static() -> bool:
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		if absf(c.get_normal().y) < 0.7 and c.get_position().y - global_position.y <= STEP_HEIGHT 				and c.get_collider() is StaticBody3D:
			return true
	return false


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


## Bật / tắt bóng đổ của mô hình (tầng giữa tắt), nhớ cài đặt gốc của từng mesh.
func _shadows(on: bool) -> void:
	if model == null:
		return
	for mi: MeshInstance3D in CharacterBuilder._mesh_instances(model):
		if not mi.has_meta("ped_cast"):
			mi.set_meta("ped_cast", mi.cast_shadow)
		var orig: GeometryInstance3D.ShadowCastingSetting = mi.get_meta("ped_cast")
		mi.cast_shadow = orig if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o: Variant in crowd:
		if o == self or not is_instance_valid(o):
			continue
		var on: Pedestrian = o
		if on.lod_far:
			continue
		var d := Vector3(global_position.x - on.global_position.x, 0.0, global_position.z - on.global_position.z)
		var l: float = d.length()
		if l > 0.01 and l < SEPARATION_R:
			push += d / l * (1.0 - l / SEPARATION_R)
	if player and player.is_inside_tree():
		var dp := Vector3(global_position.x - player.global_position.x, 0.0, global_position.z - player.global_position.z)
		var lp: float = dp.length()
		if lp > 0.01 and lp < SEPARATION_R * 1.5:
			push += dp / lp * (1.0 - lp / (SEPARATION_R * 1.5))
	return push


func _stuck_check(delta: float) -> void:
	if not _has_last:
		_has_last = true
		_last_pos = global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < STUCK_TIME:
		return
	var moved: float = global_position.distance_to(_last_pos)
	_last_pos = global_position
	_stuck_t = 0.0
	if moved < 0.15:
		_stuck_total += STUCK_TIME
		var alt: int = graph.next_node(target_node, -1, _rng)
		prev_node = target_node
		target_node = alt
		if _stuck_total >= STUCK_RECYCLE:
			stuck_out = true
	else:
		_stuck_total = 0.0
	if global_position.y < -20.0:
		stuck_out = true
