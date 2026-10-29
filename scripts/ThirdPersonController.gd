# File: res://scripts/ThirdPersonController.gd
# Nhân vật đi bộ góc nhìn thứ ba cho thế giới mở (FreeRoam), di chuyển kiểu GTA: WASD theo hướng camera, mặc định chạy
# bộ 4,2 m/s, giữ Ctrl đi bộ 1,7 m/s, giữ Shift nước rút 7,5 m/s (thể lực 6 s, hồi sau 1 s), quán tính + trượt chân khi
# thả phím lúc nước rút, quay thân với tốc độ góc giới hạn và nghiêng người khi cua, Space nhảy (đệm phím + coyote time),
# rơi: < 2,5 m nhún, 2,5..6 m lăn, > 6 m ngã sóng soài 1,5 s (khoá điều khiển) rồi đứng dậy – không bao giờ mất máu.
# Trọng lực, bước lên bậc/bó vỉa tới 0,35 m, chuột xoay camera (bắt chuột khi click, thả khi ESC), Z/C xoay quanh nhân
# vật (không dùng Q/E: [E] là phím vào màn ở cột sáng của FreeRoam), camera 3,2 m phía sau ở độ cao 1,55 m có RayCast3D để
# tường không che nhân vật, FOV rộng thêm khi nước rút, nhún nhẹ theo bước chạy, rung khi tiếp đất mạnh. Hình nhân vật =
# CharacterBuilder (preset "player", thân rigged), bước chân theo tốc độ ngang qua CharacterBuilder.set_speed().
# Tách từ StageExtra_EOSExam._handle_movement() / _update_walk_camera() và Stage5_Canteen._process_walk(), bỏ kẹp phòng.
# Không dùng GameFX / StageManager ở đây (script class_name biên dịch trước autoload khi chạy test --script).
#
# API: input_dir (Vector2: x phải, y = -1 tiến; đọc từ InputMap mỗi frame vật lý, hoặc gán input_override cho bot/test),
#      sprint_override / walk_override / jump_override (bot / test; jump_override là một lần nhấn, tự xoá),
#      set_facing(yaw), facing_yaw(), teleport(pos, yaw), controls_enabled, camera, model, horizontal_speed, is_sprinting,
#      move_state (GROUND | JUMP | AIR | LAND_SOFT | LAND_ROLL | SPLAT), stamina (0..1), slow_t (giây chậm một nửa),
#      landings (nhật ký kiểu tiếp đất), tín hiệu landed(kind, drop).
# Actions InputMap tự đăng ký: move_forward (W/↑), move_back (S/↓), move_left (A/←), move_right (D/→), sprint (Shift),
# walk (Ctrl), jump (Space; trên xe Space vẫn là drift của PlayerBike).
# Phase W: aiming (WeaponDirector sets `aiming` from the right mouse button) eases the camera over the right shoulder
# (AIM_DISTANCE behind, AIM_SIDE right, FOV AIM_FOV), turns the body with the camera and caps the speed at AIM_SPEED;
# knock_down() is the comic fall of a rocket blast / an officer's tackle (SPLAT, never hurts); shake() for explosions.
# Phase B (scripts/combat/PlayerCombat): combat_speed_cap caps the ground speed while attacking / blocking; jump_filter is
# asked on each jump press (true = the press became a dodge-roll, no jump); dodge_roll() is the LAND_ROLL state with its own
# duration and speed.
# Phase C (scripts/combat/guns/PlayerCover): move_lock = no walking input while crouched in cover (the cover holds the spot).
# Q1 camera director (spec 2026-10-29): the camera is FootCamRig (scripts/camera/), updated once per rendered frame in
# _process (its position springs on the physics tick: FootCamRig.physics_step): CameraRules shoulder / distance / height, a critically damped follow, look-ahead, a pull-in from probes through
# cam_ray (keep adding camera exceptions to it), sprint FOV, a landing dip, the combat framing of a PlayerCombat fight and
# the CameraDirector's punch / shake. yaw / pitch stay the camera's orientation (auto-yaw in combat writes yaw);
# _update_camera(true) snaps it; the camera carries the CameraDirector.META_FX meta.
# Wave 3 bullet time (plan 2026-10-30-w3-shared.md T4, BulletTime): dive(dir, real_secs, speed, prone_secs) is the DIVE
# state: the body flies along dir at `speed` m/s of real time (velocity divided by Engine.time_scale, so the slow motion does
# not slow it; move_and_slide keeps the collisions), tilted along the dive with a small arc, for round(real_secs * ticks)
# physics frames, then PRONE (lying, sliding to a stop) for round(prone_secs * ticks) frames, then GROUND. The camera springs
# and the aim ease run on real time while diving. dive_filter is asked first on each jump press (true = consumed by the dive
# or a refused dive: no jump, no dodge). is_diving(), is_prone(), cancel_dive() (back on the feet at once; teleport too).
class_name ThirdPersonController
extends CharacterBody3D

signal landed(kind: String, drop: float)

const WALK_SPEED: float = 1.7            # giữ Ctrl
const JOG_SPEED: float = 4.2             # mặc định
const SPRINT_SPEED: float = 7.5          # giữ Shift
const RUN_SPEED: float = SPRINT_SPEED    # tên cũ (mã ngoài / test)
const GRAVITY: float = 20.0
const ACCEL_JOG: float = 14.0
const ACCEL_SPRINT: float = 9.0
const DECEL: float = 18.0
const TURN_RATE_JOG: float = 10.0
const TURN_RATE_SPRINT: float = 6.0
const LEAN_K: float = 0.6                # độ nghiêng (độ) = LEAN_K × tốc độ quay (rad/s) × tốc độ (m/s)
const LEAN_MAX_DEG: float = 14.0
const STAMINA_MAX_S: float = 6.0
const STAMINA_DRAIN: float = 1.0
const STAMINA_REGEN: float = 0.8
const STAMINA_REGEN_DELAY: float = 1.0
const STAMINA_RESUME: float = 0.25
const SKID_MIN_SPEED: float = 6.0
const SKID_TIME: float = 0.25
const JUMP_APEX: float = 0.9
const JUMP_BUFFER: float = 0.12
const COYOTE: float = 0.1
const AIR_CONTROL: float = 0.3
const SOFT_LAND_MAX: float = 2.5
const ROLL_LAND_MAX: float = 6.0
const SOFT_LAND_TIME: float = 0.15
const ROLL_TIME: float = 0.8
const ROLL_KEEP: float = 0.7
const SPLAT_TIME: float = 1.5
const GETUP_TIME: float = 0.9
const FLAIL_AFTER: float = 0.5
const FLAIL_VY: float = -6.0
const FLOOR_SNAP: float = 0.4
const SPRINT_FOV_ADD: float = 6.0
const FOV_EASE: float = 5.0              # 1/s, như FOV camera xe (PlayerBike)
const STEP_HEIGHT: float = 0.35
const CAM_DISTANCE: float = CameraRules.FOOT_DIST
const CAM_HEIGHT: float = CameraRules.FOOT_HEIGHT
const CAM_SHOULDER: float = CameraRules.FOOT_SHOULDER
const CAM_MARGIN: float = CameraRules.PULL_MARGIN
const MOUSE_SENS: float = 0.0022
const ORBIT_SPEED: float = 2.2          # rad/s khi giữ Z/C
const ORBIT_LEFT_KEY: Key = KEY_Z
const ORBIT_RIGHT_KEY: Key = KEY_C
const PITCH_MIN: float = -1.1
const PITCH_MAX: float = 0.55
const DEFAULT_PITCH: float = -0.2
const AIM_DISTANCE: float = 1.7          # Phase W: over-the-shoulder camera while aiming
const AIM_SIDE: float = 0.55
const AIM_FOV: float = 50.0
const AIM_SPEED: float = 2.2
const AIM_TURN_RATE: float = 18.0
const AIM_EASE_S: float = 0.15

## Tuỳ chọn truyền cho CharacterBuilder.build() (đặt trước khi vào cây).
var character_opts: Dictionary = {"preset": "player", "rigged": true, "seed": 2805, "name": "PlayerModel"}
## Hướng di chuyển của frame vật lý gần nhất (x = phải, y = -1 tiến theo camera).
var input_dir: Vector2 = Vector2.ZERO
## Vector2 để ép hướng di chuyển (bot / test); null = đọc bàn phím.
var input_override: Variant = null
var sprint_override: bool = false
var controls_enabled: bool = true
## Bắt chuột khi click trái lúc chuột đang hiện (tắt trong test / preview).
var capture_on_click: bool = true
var yaw: float = 0.0           # yaw camera (rad), 0 = nhìn về -Z
var pitch: float = DEFAULT_PITCH
var horizontal_speed: float = 0.0
var is_sprinting: bool = false
## Trạng thái di chuyển: GROUND | JUMP | AIR | LAND_SOFT | LAND_ROLL | SPLAT.
var move_state: String = "GROUND"
## Thể lực nước rút 0..1 (1 = STAMINA_MAX_S giây).
var stamina: float = 1.0
var walk_override: bool = false
## Bot / test: nhấn nhảy một lần (tự xoá sau khi đọc).
var jump_override: bool = false
## Giây còn lại bị chậm một nửa (va người đi đường khi nước rút).
var slow_t: float = 0.0
## Nhật ký kiểu tiếp đất (test).
var landings: Array[String] = []
## Phase W: right mouse held (WeaponDirector); aim_blend eases 0..1 over AIM_EASE_S.
var aiming: bool = false
var aim_blend: float = 0.0
## Phase B: ground speed cap set by PlayerCombat (INF = none) and the jump-press filter (-> bool, true = consumed).
var combat_speed_cap: float = INF
var jump_filter: Callable
## Phase C: true while PlayerCover holds the player crouched behind cover (movement input reads as zero).
var move_lock: bool = false
## Wave 3 bullet time: asked first on each jump press (-> bool, true = consumed by a dive); the dive's frame counters.
var dive_filter: Callable
var dive_frames: int = 0
var prone_frames: int = 0
const DIVE_TILT: float = 1.25
const PRONE_TILT: float = 1.45
const DIVE_ARC: float = 0.45
var _dive_dir: Vector3 = Vector3.ZERO
var _dive_speed: float = 0.0
var _dive_total: int = 1
var _dive_left: int = 0
var _prone_total: int = 0
var _prone_left: int = 0
var _roll_time: float = ROLL_TIME
var _exhausted: bool = false
var _stamina_wait: float = 0.0
var _state_t: float = 0.0
var _air_t: float = 0.0
var _peak_y: float = 0.0
var _last_floor_y: float = 0.0
var _jump_buffer_t: float = 0.0
var _coyote_t: float = 0.0
var _skid_t: float = 0.0
var _lean: float = 0.0
var _air_clip: String = ""
var _splat_phase: int = 0
var _cam_dt: float = 0.0
var _shake_t: float = 0.0                # seconds left of the last shake() (read by tests; the shake itself is FootCamRig's)

var model: Node3D
var cam_pivot: Node3D
var cam_ray: RayCast3D
var camera: Camera3D
## Q1: the on-foot camera rig (scripts/camera/FootCamRig.gd).
var cam_rig: FootCamRig
var _shape: CollisionShape3D
var _built: bool = false


func _ready() -> void:
	_ensure_input_map()
	_build()


## Dựng hình nhân vật + collider + camera (gọi một lần; _ready tự gọi).
func _build() -> void:
	if _built:
		return
	_built = true
	floor_snap_length = FLOOR_SNAP
	safe_margin = 0.02
	floor_max_angle = deg_to_rad(46.0)
	_shape = CollisionShape3D.new()
	_shape.name = "Capsule"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	_shape.shape = cap
	_shape.position = Vector3(0.0, 0.85, 0.0)
	add_child(_shape)

	model = CharacterBuilder.build(character_opts)
	model.name = "Model"
	add_child(model)
	model.rotation.y = yaw

	cam_pivot = Node3D.new()
	cam_pivot.name = "CamPivot"
	cam_pivot.top_level = true
	add_child(cam_pivot)
	cam_ray = RayCast3D.new()
	cam_ray.name = "CamRay"
	cam_ray.top_level = true             # FootCamRig aims it for each probe (world space)
	cam_ray.target_position = Vector3(0.0, 0.0, CAM_DISTANCE + CAM_MARGIN)
	cam_ray.collide_with_areas = false
	cam_ray.collide_with_bodies = true
	cam_ray.hit_from_inside = false
	cam_ray.add_exception(self)
	cam_ray.enabled = true
	cam_pivot.add_child(cam_ray)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 6000.0
	camera.position = Vector3(CAM_SHOULDER, 0.0, CAM_DISTANCE)
	camera.set_meta(CameraDirector.META_FX, self)
	cam_pivot.add_child(camera)
	cam_rig = FootCamRig.new(self)
	_update_camera(true)


func _ensure_input_map() -> void:
	var bindings: Dictionary = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"walk": [KEY_CTRL],
		"jump": [KEY_SPACE]
	}
	for action: String in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for key_code: int in bindings[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key_code as Key
				InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------------------
# HƯỚNG / DỊCH CHUYỂN
# ---------------------------------------------------------------------------
## Hướng nhìn của nhân vật (rad quanh Y; 0 = -Z). Đặt cả camera lẫn thân nhân vật.
func set_facing(yaw_rad: float) -> void:
	yaw = yaw_rad
	pitch = DEFAULT_PITCH
	if model:
		model.rotation.y = yaw_rad
	_update_camera(true)


func facing_yaw() -> float:
	return model.rotation.y if model else yaw


## Hướng -Z của thân nhân vật (đơn vị, trên mặt phẳng ngang).
func facing_dir() -> Vector3:
	var a: float = facing_yaw()
	return Vector3(-sin(a), 0.0, -cos(a))


## Dịch tới chỗ đứng pos: xoá mọi trạng thái di chuyển đang dở (đang nhảy / rơi / lăn / ngã, clip của chúng, nước rút, phím
## nhảy đang chờ, trượt chân, chậm vì va người, rung camera) – vd. lên xe giữa cú ngã rồi xuống xe thì không chạy bộ trong tư
## thế nằm. Coi như vừa đứng trên sàn (coyote đầy): khe vài cm tới sàn ở khung đầu không tính là một cú rơi.
## Thể lực giữ nguyên.
func teleport(pos: Vector3, yaw_rad: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	move_state = "GROUND"
	floor_snap_length = FLOOR_SNAP
	_peak_y = pos.y
	_last_floor_y = pos.y
	_air_clip = ""
	_state_t = 0.0
	_air_t = 0.0
	_splat_phase = 0
	_skid_t = 0.0
	_jump_buffer_t = 0.0
	jump_override = false
	_coyote_t = COYOTE
	is_sprinting = false
	slow_t = 0.0
	_lean = 0.0
	_shake_t = 0.0
	if cam_rig:
		cam_rig.trauma = 0.0
	_dive_left = 0
	_prone_left = 0
	_untilt()
	set_facing(yaw_rad)
	if model:
		CharacterBuilder.stop_clip(model)
		CharacterBuilder.set_speed(model, 0.0)
		CharacterBuilder.set_param(model, "run", 0.0)
		CharacterBuilder.set_param(model, "sprint", 0.0)
		CharacterBuilder.set_param(model, "lean", 0.0)


func _read_input() -> Vector2:
	if move_lock:
		return Vector2.ZERO
	if input_override is Vector2:
		return input_override
	if not controls_enabled:
		return Vector2.ZERO
	var d := Vector2.ZERO
	if InputMap.has_action("move_forward"):
		d.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		d.y = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	return d.limit_length(1.0)


func _physics_process(delta: float) -> void:
	if not _built:
		return
	input_dir = _read_input()
	var want_sprint: bool = sprint_override or (controls_enabled and _pressed("sprint"))
	var want_walk: bool = walk_override or (controls_enabled and _pressed("walk"))
	if jump_override or (controls_enabled and InputMap.has_action("jump") and Input.is_action_just_pressed("jump")):
		if move_state == "DIVE" or move_state == "PRONE":
			pass                             # no jump out of a dive
		elif dive_filter.is_valid() and bool(dive_filter.call()):
			pass                             # the press started (or was refused as) a bullet-time dive
		elif not (jump_filter.is_valid() and bool(jump_filter.call())):
			_jump_buffer_t = JUMP_BUFFER
	jump_override = false
	if controls_enabled:
		if Input.is_physical_key_pressed(ORBIT_LEFT_KEY):
			yaw += ORBIT_SPEED * delta
			_look_input()
		if Input.is_physical_key_pressed(ORBIT_RIGHT_KEY):
			yaw -= ORBIT_SPEED * delta
			_look_input()
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var r := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move: Vector3 = f * (-input_dir.y) + r * input_dir.x
	if move.length_squared() > 1.0:
		move = move.normalized()
	_state_t += delta
	_jump_buffer_t = maxf(0.0, _jump_buffer_t - delta)
	_coyote_t = COYOTE if is_on_floor() else maxf(0.0, _coyote_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	match move_state:
		"GROUND":
			_ground(delta, move, want_sprint, want_walk)
		"JUMP", "AIR":
			_air(delta, move)
		"LAND_SOFT":
			_ground(delta, move, want_sprint, want_walk)
			if move_state == "LAND_SOFT" and _state_t >= SOFT_LAND_TIME:
				move_state = "GROUND"
		"LAND_ROLL":
			_roll(delta, move)
		"SPLAT":
			_splat(delta)
		"DIVE":
			_dive(delta)
		"PRONE":
			_prone(delta)
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if model:
		var moving_state: bool = move_state == "GROUND" or move_state == "LAND_SOFT"
		var sprint_anim: bool = is_sprinting and horizontal_speed > JOG_SPEED + 0.5
		CharacterBuilder.set_speed(model, horizontal_speed if moving_state else 0.0)
		CharacterBuilder.set_param(model, "run", 0.45 if sprint_anim else 0.0)
		CharacterBuilder.set_param(model, "sprint", 1.0 if sprint_anim else 0.0)
		CharacterBuilder.set_param(model, "lean", _lean)
	if cam_rig:
		cam_rig.physics_step(_real_delta(delta) if move_state == "DIVE" else delta)   # same tick as the player (a dive: real time)


func _look_input() -> void:
	if cam_rig:
		cam_rig.look_input()


func _pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _play(clip: String, duration: float = -1.0) -> void:
	if model:
		CharacterBuilder.play(model, clip, duration)


## Thể lực: tụt 1/s khi đang nước rút nhanh hơn 5 m/s; hồi 0.8/s sau 1 s không nước rút; cạn thì chỉ chạy lại khi > 25 %.
func _update_stamina(delta: float, sprinting_now: bool) -> void:
	var s: float = stamina * STAMINA_MAX_S
	if sprinting_now and horizontal_speed > 5.0:
		s = maxf(0.0, s - STAMINA_DRAIN * delta)
		_stamina_wait = STAMINA_REGEN_DELAY
		if s <= 0.0:
			_exhausted = true
	else:
		_stamina_wait = maxf(0.0, _stamina_wait - delta)
		if _stamina_wait <= 0.0:
			s = minf(STAMINA_MAX_S, s + STAMINA_REGEN * delta)
	if _exhausted and s > STAMINA_RESUME * STAMINA_MAX_S:
		_exhausted = false
	stamina = s / STAMINA_MAX_S


func _ground(delta: float, move: Vector3, want_sprint: bool, want_walk: bool) -> void:
	var has_input: bool = move.length_squared() > 0.0001
	is_sprinting = want_sprint and has_input and not _exhausted and not aiming
	_update_stamina(delta, is_sprinting)
	var speed: float = SPRINT_SPEED if is_sprinting else (WALK_SPEED if want_walk else JOG_SPEED)
	if slow_t > 0.0:
		speed *= 0.5
	if aiming:
		speed = minf(speed, AIM_SPEED)
	speed = minf(speed, combat_speed_cap)
	if has_input:
		var accel: float = ACCEL_SPRINT if is_sprinting else ACCEL_JOG
		velocity.x = move_toward(velocity.x, move.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, move.z * speed, accel * delta)
		_skid_t = 0.0
	else:
		if horizontal_speed > SKID_MIN_SPEED and _skid_t <= 0.0 and move_state == "GROUND":
			_skid_t = SKID_TIME
			_play("skid", SKID_TIME)
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
	_skid_t = maxf(0.0, _skid_t - delta)
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
		_last_floor_y = global_position.y
	else:
		velocity.y -= GRAVITY * delta
	if _jump_buffer_t > 0.0 and _coyote_t > 0.0:
		_start_jump()
		return
	if has_input and is_on_floor():
		_try_step_up(move, delta)
	move_and_slide()
	_turn(delta, move, TURN_RATE_SPRINT if is_sprinting else TURN_RATE_JOG)
	if not is_on_floor() and _coyote_t <= 0.0:
		_enter_air(false)


func _start_jump() -> void:
	_jump_buffer_t = 0.0
	_coyote_t = 0.0
	velocity.y = sqrt(2.0 * GRAVITY * JUMP_APEX)
	_enter_air(true)
	_play("jump_takeoff", 0.12)
	move_and_slide()


func _enter_air(jumped: bool) -> void:
	move_state = "JUMP" if jumped else "AIR"
	_state_t = 0.0
	_air_t = 0.0
	_air_clip = ""
	_peak_y = maxf(global_position.y, _last_floor_y)
	floor_snap_length = 0.0


func _air(delta: float, move: Vector3) -> void:
	_air_t += delta
	_update_stamina(delta, false)
	is_sprinting = false
	if move.length_squared() > 0.0001:
		var speed: float = maxf(JOG_SPEED, horizontal_speed)
		velocity.x = move_toward(velocity.x, move.x * speed, ACCEL_JOG * AIR_CONTROL * delta)
		velocity.z = move_toward(velocity.z, move.z * speed, ACCEL_JOG * AIR_CONTROL * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	_peak_y = maxf(_peak_y, global_position.y)
	_turn(delta, move, TURN_RATE_SPRINT * AIR_CONTROL)
	if move_state == "JUMP" and velocity.y <= 0.0:
		move_state = "AIR"
	var clip: String = "fall_flail" if (_air_t > FLAIL_AFTER or velocity.y < FLAIL_VY) else ("jump_air" if _air_t > 0.1 else "")
	if clip != "" and clip != _air_clip:
		_air_clip = clip
		_play(clip)
	if is_on_floor() and velocity.y <= 0.0 and _air_t > 0.05:
		_land(_peak_y - global_position.y)


func _land(drop: float) -> void:
	floor_snap_length = FLOOR_SNAP
	_air_clip = ""
	_state_t = 0.0
	_last_floor_y = global_position.y
	if drop < SOFT_LAND_MAX:
		move_state = "LAND_SOFT"
		_play("land_soft", SOFT_LAND_TIME)
	elif drop < ROLL_LAND_MAX:
		move_state = "LAND_ROLL"
		_roll_time = ROLL_TIME
		var fwd: Vector3 = facing_dir()
		var sp: float = maxf(horizontal_speed * ROLL_KEEP, 2.5)
		velocity.x = fwd.x * sp
		velocity.z = fwd.z * sp
		_play("roll", ROLL_TIME)
		_shake(0.25)
	else:
		move_state = "SPLAT"
		velocity.x = 0.0
		velocity.z = 0.0
		_splat_phase = 0
		_play("knockdown")
		_shake(0.5)
	if cam_rig:
		cam_rig.dip(move_state)
	landings.append(move_state)
	landed.emit(move_state, drop)


## Lăn: chỉ lái hướng; vận tốc bám hướng thân, giảm dần.
func _roll(delta: float, move: Vector3) -> void:
	_turn(delta, move, TURN_RATE_SPRINT)
	var sp: float = move_toward(Vector2(velocity.x, velocity.z).length(), 0.0, 2.0 * delta)
	var fwd: Vector3 = facing_dir()
	velocity.x = fwd.x * sp
	velocity.z = fwd.z * sp
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if _state_t >= _roll_time:
		move_state = "GROUND"


## Phase B dodge-roll (PlayerCombat): roll along dir (flat; zero = backwards) at `speed` m/s for `secs`, body turned to it.
## Same LAND_ROLL state as a landing roll (steered by the input, slowing down), just shorter.
func dodge_roll(dir: Vector3, secs: float, speed: float) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length_squared() > 1e-6 else -facing_dir()
	move_state = "LAND_ROLL"
	_state_t = 0.0
	_roll_time = secs
	_jump_buffer_t = 0.0
	_air_clip = ""
	is_sprinting = false
	velocity = Vector3(d.x * speed, minf(velocity.y, 0.0), d.z * speed)
	if model:
		model.rotation.y = atan2(-d.x, -d.z)
	_play("roll", secs)


## Wave 3 bullet time: dive along dir (flat; zero = to the right of the camera) at `speed` m/s of real time for real_secs,
## then lie prone for prone_secs (real), then stand. Returns false (nothing changes) while airborne, rolling, down or
## already diving.
func dive(dir: Vector3, real_secs: float, speed: float, prone_secs: float = 0.4) -> bool:
	if move_state != "GROUND" and move_state != "LAND_SOFT":
		return false
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length_squared() > 1e-6 else Vector3(cos(yaw), 0.0, -sin(yaw))
	var ticks: float = float(maxi(1, Engine.physics_ticks_per_second))
	move_state = "DIVE"
	_state_t = 0.0
	_dive_dir = d
	_dive_speed = speed
	_dive_total = maxi(1, roundi(real_secs * ticks))
	_dive_left = _dive_total
	_prone_total = maxi(0, roundi(prone_secs * ticks))
	_prone_left = 0
	dive_frames = 0
	prone_frames = 0
	_jump_buffer_t = 0.0
	_air_clip = ""
	is_sprinting = false
	_skid_t = 0.0
	return true


func is_diving() -> bool:
	return move_state == "DIVE"


func is_prone() -> bool:
	return move_state == "PRONE"


## Ends a dive or the prone time at once: standing on the ground, the body upright.
func cancel_dive() -> void:
	if move_state == "DIVE" or move_state == "PRONE":
		move_state = "GROUND"
		_state_t = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
	_dive_left = 0
	_prone_left = 0
	_untilt()


func _real_delta(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)


func _dive(delta: float) -> void:
	_dive_left -= 1
	dive_frames += 1
	var k: float = 1.0 - float(_dive_left) / float(_dive_total)
	var sp: float = _dive_speed * (1.0 if k < 0.75 else lerpf(1.0, 0.45, (k - 0.75) / 0.25))
	var inv: float = 1.0 / maxf(Engine.time_scale, 0.01)
	velocity.x = _dive_dir.x * sp * inv      # real-time displacement: velocity * scaled delta = sp * real delta
	velocity.z = _dive_dir.z * sp * inv
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_turn(delta, Vector3.ZERO, TURN_RATE_JOG)
	_tilt(DIVE_TILT * minf(1.0, k / 0.15), DIVE_ARC * sin(PI * k))
	if _dive_left <= 0:
		velocity.x = _dive_dir.x * sp * 0.4
		velocity.z = _dive_dir.z * sp * 0.4
		if _prone_total > 0:
			move_state = "PRONE"
			_prone_left = _prone_total
		else:
			move_state = "GROUND"
			_untilt()
		_state_t = 0.0


func _prone(delta: float) -> void:
	_prone_left -= 1
	prone_frames += 1
	velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_turn(delta, Vector3.ZERO, TURN_RATE_JOG)
	_tilt(PRONE_TILT, 0.0)
	if _prone_left <= 0:
		move_state = "GROUND"
		_state_t = 0.0
		_untilt()


## The body tipped `amount` rad toward the dive direction (in the model's frame), lifted `lift` m.
func _tilt(amount: float, lift: float) -> void:
	if model == null:
		return
	var loc: Vector3 = Basis(Vector3.UP, model.rotation.y).inverse() * _dive_dir
	model.rotation.x = loc.z * amount
	model.rotation.z = -loc.x * amount
	model.position.y = lift


func _untilt() -> void:
	if model == null:
		return
	model.rotation.x = 0.0
	model.rotation.z = 0.0
	model.position.y = 0.0


## Ngã sóng soài: khoá điều khiển SPLAT_TIME, rồi đứng dậy (getup) GETUP_TIME.
func _splat(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if _splat_phase == 0 and _state_t >= SPLAT_TIME:
		_splat_phase = 1
		_play("getup")
	elif _splat_phase == 1 and _state_t >= SPLAT_TIME + GETUP_TIME:
		move_state = "GROUND"
		_state_t = 0.0
		if model:
			CharacterBuilder.stop_clip(model)


## Quay thân về hướng di chuyển với tốc độ góc cố định (rad/s); nghiêng người theo tốc độ quay × tốc độ chạy.
func _turn(delta: float, move: Vector3, rate: float) -> void:
	if model == null:
		return
	var before: float = model.rotation.y
	if aiming:
		var diff_a: float = wrapf(yaw - before, -PI, PI)
		model.rotation.y = before + clampf(diff_a, -AIM_TURN_RATE * delta, AIM_TURN_RATE * delta)
	elif move.length_squared() > 0.0001:
		var diff: float = wrapf(atan2(-move.x, -move.z) - before, -PI, PI)
		model.rotation.y = before + clampf(diff, -rate * delta, rate * delta)
	var turn_rate: float = wrapf(model.rotation.y - before, -PI, PI) / maxf(delta, 0.0001)
	var lean_deg: float = clampf(LEAN_K * turn_rate * horizontal_speed, -LEAN_MAX_DEG, LEAN_MAX_DEG)
	_lean = lerpf(_lean, deg_to_rad(lean_deg), minf(1.0, delta * 8.0))


func _shake(amp: float) -> void:
	_shake_t = 0.35
	if cam_rig:
		cam_rig.add_trauma(amp * CameraRules.LOCAL_SHAKE_K)


## Bước lên bậc thấp (bó vỉa 0,15 m, bậc thang 0,17 m, tối đa STEP_HEIGHT): nếu đường đi bị chặn ở độ cao bàn chân
## nhưng thông ở độ cao bậc, và sau khi tiến có sàn ngay dưới, thì nâng thân lên đúng chiều cao bậc.
func _try_step_up(move: Vector3, delta: float) -> void:
	var motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 0.000001:
		motion = move.normalized() * 0.05
	var xf: Transform3D = global_transform
	if not test_move(xf, motion):
		return
	var up := Vector3(0.0, STEP_HEIGHT + 0.03, 0.0)
	if test_move(xf, up):
		return
	var probe: Vector3 = motion + move.normalized() * 0.12
	var raised: Transform3D = xf.translated(up)
	if test_move(raised, probe):
		return
	var moved: Transform3D = raised.translated(probe)
	var col := KinematicCollision3D.new()
	if not test_move(moved, Vector3(0.0, -(STEP_HEIGHT + 0.06), 0.0), col):
		return
	if col.get_normal().y < 0.7:
		return
	var step_h: float = up.y + col.get_travel().y
	if step_h > 0.02 and step_h <= STEP_HEIGHT + 0.03:
		global_position.y += step_h + 0.01


## Phase W: comic knock-down (a rocket blast nearby, an officer's tackle): SPLAT – down SPLAT_TIME, getup GETUP_TIME –
## shoved `power` m/s along `away`; never hurts. Ignored while already down.
func knock_down(away: Vector3, power: float = 3.0) -> void:
	if move_state == "SPLAT":
		return
	aiming = false
	var a := Vector3(away.x, 0.0, away.z)
	a = a.normalized() if a.length_squared() > 1e-6 else -facing_dir()
	move_state = "SPLAT"
	_state_t = 0.0
	_splat_phase = 0
	_air_clip = ""
	floor_snap_length = FLOOR_SNAP
	velocity = Vector3(a.x * power, 0.0, a.z * power)
	if model:
		model.rotation.y = atan2(-a.x, -a.z) + PI    # faces the shove, falls on its back away from it
	_play("knockdown")
	_shake(0.5)
	if cam_rig:
		cam_rig.dip("SPLAT")


func is_knocked_down() -> bool:
	return move_state == "SPLAT"


## Phase W: camera shake (explosions), amp ~0.15-1.0.
func shake(amp: float) -> void:
	_shake(amp)


# ---------------------------------------------------------------------------
# CAMERA
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _built:
		var cd: float = _real_delta(delta) if move_state == "DIVE" else delta   # a dive: aim and camera on real time
		aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, cd / AIM_EASE_S)
		_shake_t = maxf(0.0, _shake_t - delta)
		_cam_dt = cd
		_update_camera(false)
		_cam_dt = 0.0


## The camera pose through FootCamRig (once per rendered frame from _process; snap = jump there: build, set_facing,
## teleport, tests).
func _update_camera(snap: bool) -> void:
	if cam_pivot == null or cam_rig == null:
		return
	cam_rig.update(_cam_dt, snap)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		yaw -= mm.relative.x * MOUSE_SENS
		pitch = clampf(pitch - mm.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
		_look_input()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and capture_on_click and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
