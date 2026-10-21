# File: res://scripts/ThirdPersonController.gd
# Nhân vật đi bộ góc nhìn thứ ba cho thế giới mở (FreeRoam): WASD theo hướng camera, Shift chạy, trọng lực,
# bước lên bậc/bó vỉa tới 0,35 m, chuột xoay camera (bắt chuột khi click, thả khi ESC), Q/E xoay quanh nhân vật,
# cần camera 3,2 m phía sau ở độ cao 1,6 m có RayCast3D để tường không che nhân vật. Hình nhân vật = CharacterBuilder
# (preset "player", thân rigged), bước chân theo tốc độ ngang qua CharacterBuilder.set_speed().
# Tách từ StageExtra_EOSExam._handle_movement() / _update_walk_camera() và Stage5_Canteen._process_walk(), bỏ kẹp phòng.
# Không dùng GameFX / StageManager ở đây (script class_name biên dịch trước autoload khi chạy test --script).
#
# API: input_dir (Vector2: x phải, y = -1 tiến; đọc từ InputMap mỗi frame vật lý, hoặc gán input_override cho bot/test),
#      set_facing(yaw), facing_yaw(), teleport(pos, yaw), controls_enabled, camera, model, horizontal_speed.
# Actions InputMap tự đăng ký: move_forward (W/↑), move_back (S/↓), move_left (A/←), move_right (D/→), sprint (Shift).
class_name ThirdPersonController
extends CharacterBody3D

const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 7.0
const GRAVITY: float = 20.0
const ACCEL: float = 18.0
const DECEL: float = 24.0
const STEP_HEIGHT: float = 0.35
const CAM_DISTANCE: float = 3.2
const CAM_HEIGHT: float = 1.6
const CAM_MARGIN: float = 0.25
const MOUSE_SENS: float = 0.0022
const ORBIT_SPEED: float = 2.2          # rad/s khi giữ Q/E
const PITCH_MIN: float = -1.1
const PITCH_MAX: float = 0.55
const DEFAULT_PITCH: float = -0.2
const TURN_LERP: float = 12.0

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

var model: Node3D
var cam_pivot: Node3D
var cam_ray: RayCast3D
var camera: Camera3D
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
	floor_snap_length = 0.4
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
	camera.position = Vector3(0.0, 0.0, CAM_DISTANCE)
	cam_pivot.add_child(camera)
	_update_camera(true)


func _ensure_input_map() -> void:
	var bindings: Dictionary = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT]
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


func teleport(pos: Vector3, yaw_rad: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	horizontal_speed = 0.0
	set_facing(yaw_rad)
	if model:
		CharacterBuilder.set_speed(model, 0.0)


func _read_input() -> Vector2:
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
	is_sprinting = sprint_override or (controls_enabled and InputMap.has_action("sprint") and Input.is_action_pressed("sprint"))
	if controls_enabled:
		if Input.is_physical_key_pressed(KEY_Q):
			yaw += ORBIT_SPEED * delta
		if Input.is_physical_key_pressed(KEY_E):
			yaw -= ORBIT_SPEED * delta
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var r := Vector3(cos(yaw), 0.0, -sin(yaw))
	var move: Vector3 = f * (-input_dir.y) + r * input_dir.x
	if move.length_squared() > 1.0:
		move = move.normalized()
	var speed: float = RUN_SPEED if is_sprinting else WALK_SPEED
	var target: Vector3 = move * speed
	var rate: float = ACCEL if move.length_squared() > 0.0001 else DECEL
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta
	if move.length_squared() > 0.0001 and is_on_floor():
		_try_step_up(move, delta)
	move_and_slide()
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if model:
		if move.length_squared() > 0.0001:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-move.x, -move.z), minf(1.0, delta * TURN_LERP))
		CharacterBuilder.set_speed(model, horizontal_speed)
		CharacterBuilder.set_param(model, "run", 0.45 if (is_sprinting and horizontal_speed > WALK_SPEED + 0.5) else 0.0)
	_update_camera(false)


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


# ---------------------------------------------------------------------------
# CAMERA
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _built:
		_update_camera(false)


func _update_camera(snap: bool) -> void:
	if cam_pivot == null:
		return
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	cam_pivot.global_position = global_position + Vector3(0.0, CAM_HEIGHT, 0.0)
	cam_pivot.global_basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var dist: float = CAM_DISTANCE
	if cam_ray and cam_ray.enabled:
		if not snap:
			cam_ray.force_raycast_update()
		if cam_ray.is_colliding():
			var hit: Vector3 = cam_ray.get_collision_point()
			dist = clampf(cam_pivot.global_position.distance_to(hit) - CAM_MARGIN, 0.6, CAM_DISTANCE)
	if snap:
		camera.position = Vector3(0.0, 0.0, dist)
	else:
		camera.position.z = lerpf(camera.position.z, dist, 0.35 if dist < camera.position.z else 0.12)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		yaw -= mm.relative.x * MOUSE_SENS
		pitch = clampf(pitch - mm.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and capture_on_click and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
