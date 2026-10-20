# File: res://scripts/PlayerBike.gd
# Xe máy sinh viên FPTU: vật lý arcade, DRIFT [SPACE], lùi xe [S khi dừng], núp gió F-Bus,
# near-miss (lách sát xe khác), kẹp ranh giới làn đường, âm thanh động cơ/gió/lết bánh.
class_name PlayerBike
extends CharacterBody3D

signal speed_changed(speed_kmh: float, slipstream_ratio: float, is_boosting: bool)
signal crash_occurred()
signal respawned(penalty_sec: float)
signal curb_hit(penalty_sec: float)
signal offroad_changed(is_offroad: bool)
signal near_miss(chain: int)
signal drift_boost(duration: float)
signal drift_state_changed(is_drifting: bool)

@export var road_path: Path3D

@export_group("Bike Physics")
@export var max_speed_ms: float = 22.5        # ~81 km/h bình thường (lái sạch 1.9km vừa kịp 90s)
@export var slipstream_max_ms: float = 27.0   # ~97 km/h khi Núp gió F-Bus / VinBus
@export var engine_accel: float = 13.5
@export var brake_decel: float = 26.0
@export var rolling_friction: float = 2.8
@export var air_drag: float = 0.015
@export var steer_speed: float = 2.2
@export var max_tilt_angle: float = 0.48      # ~27.5 độ nghiêng thân xe khi ôm cua
@export var gravity: float = 20.0
@export var reverse_speed_ms: float = 3.0     # Lùi xe khi giữ S lúc đã dừng

@export_group("Drift")
@export var drift_steer_mult: float = 1.5
@export var drift_min_speed_ms: float = 7.0
@export var drift_boost_bonus_ms: float = 4.0
@export var drift_boost_min_time: float = 0.7

@export_group("Road Clamp")
@export var lane_clamp_enabled: bool = true
@export var road_half_width: float = 6.9      # Quá mức này sẽ bị đẩy về lòng đường
@export var road_hard_limit: float = 8.6      # Quá mức này: đặt lại ở mép đường + phạt 1s

var current_speed_ms: float = 0.0
var steer_input: float = 0.0
var tilt_angle: float = 0.0
var slipstream_charge: float = 0.0
var is_slipstream_boosting: bool = false
var is_controls_locked: bool = false
var RearSkidOffset: float = 0.0
var is_offroad: bool = false
var respawn_invulnerable_timer: float = 0.0
var camera_shake_trauma: float = 0.0

# Drift
var is_drifting: bool = false
var drift_time: float = 0.0
var drift_boost_timer: float = 0.0
var rain_factor: float = 1.0

# Near-miss
var near_candidates: Dictionary = {}
var near_miss_chain: int = 0
var near_miss_chain_timer: float = 0.0
const NEAR_MISS_CHAIN_WINDOW: float = 6.0 # đủ để đi từ cụm xe này sang cụm kế (~130 m ở 80 km/h)
var longest_near_miss_chain: int = 0
var rider_node: Node3D
var near_miss_area: Area3D

# Hệ thống Âm thanh Vòm 3D
var engine_player: AudioStreamPlayer3D
var horn_player: AudioStreamPlayer3D
var skid_player: AudioStreamPlayer3D
var drift_player: AudioStreamPlayer3D
var bump_player: AudioStreamPlayer3D
var wind_player: AudioStreamPlayer
var boost_player: AudioStreamPlayer

var smoke_particles: CPUParticles3D

@onready var visual_pivot: Node3D = $VisualPivot
@onready var front_wheel: Node3D = $VisualPivot/FrontWheel
@onready var rear_wheel: Node3D = $VisualPivot/RearWheel
@onready var handlebar_pivot: Node3D = $VisualPivot/HandlebarPivot
@onready var slipstream_ray: RayCast3D = $SlipstreamRay
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var chase_cam: Camera3D = $CameraRig/SpringArm3D/Camera3D

func _ready() -> void:
	_ensure_input_map()
	if not road_path:
		road_path = get_node_or_null("../RoadSystem/RoadTrack/RoadPath")
	_build_procedural_bike_and_seated_rider()
	_setup_audio_system()
	_setup_near_miss_area()
	# Không dùng định danh autoload GameFX ở đây: test --script biên dịch PlayerBike trước khi autoload được đăng ký
	var fx_node: Node = get_node_or_null("/root/GameFX")
	if fx_node:
		fx_node.route_audio_to_bus(self, "SFX")
	_setup_drift_smoke()
	slipstream_ray.target_position = Vector3(0.0, 0.0, -8.5) # Quét cự ly 8.5m phía trước
	slipstream_ray.enabled = true
	floor_snap_length = 0.45 # Chống bay lơ lửng hoặc xuyên dốc Cầu Trau Trảu
	floor_max_angle = deg_to_rad(50.0)

func add_camera_shake(amount: float) -> void:
	camera_shake_trauma = clampf(camera_shake_trauma + amount, 0.0, 1.0)

func set_rain(enabled: bool) -> void:
	rain_factor = 0.78 if enabled else 1.0

func _ensure_input_map() -> void:
	var bindings: Dictionary = {
		"gas": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"drift": [KEY_SPACE],
		"horn": [KEY_H, KEY_B]
	}
	for action: String in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for key_code: int in bindings[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key_code as Key
				InputMap.action_add_event(action, ev)

func _setup_audio_system() -> void:
	# 1. Tiếng bô xe máy 4 thì Honda Wave (AudioStreamPlayer3D định hướng theo vị trí xe)
	engine_player = AudioStreamPlayer3D.new()
	var engine_stream := _load_wav_stream("res://assets/audio/bike_engine_loop.wav", true)
	if engine_stream:
		engine_player.stream = engine_stream
		engine_player.unit_size = 8.0
		engine_player.max_distance = 65.0
		engine_player.volume_db = -4.0
		engine_player.pitch_scale = 0.85
		add_child(engine_player)
		engine_player.play()

	# 2. Còi xe máy đĩa đôi bim bim
	horn_player = AudioStreamPlayer3D.new()
	var horn_stream := _load_wav_stream("res://assets/audio/bike_horn.wav", false)
	if horn_stream:
		horn_player.stream = horn_stream
		horn_player.unit_size = 12.0
		horn_player.max_distance = 80.0
		horn_player.volume_db = 2.0
		add_child(horn_player)

	# 3. Tiếng gió rít khi chạy tốc độ cao
	wind_player = AudioStreamPlayer.new()
	var wind_stream := _load_wav_stream("res://assets/audio/wind_rush_loop.wav", true)
	if wind_stream:
		wind_player.stream = wind_stream
		wind_player.volume_db = -80.0 # Bắt đầu im lặng
		add_child(wind_player)
		wind_player.play()

	# 4. Tiếng lết bánh khi phanh gấp (one-shot) và khi drift (loop)
	skid_player = AudioStreamPlayer3D.new()
	var skid_stream := _load_wav_stream("res://assets/audio/tire_skid.wav", false)
	if skid_stream:
		skid_player.stream = skid_stream
		skid_player.volume_db = 0.0
		add_child(skid_player)

	drift_player = AudioStreamPlayer3D.new()
	var drift_stream := _load_wav_stream("res://assets/audio/tire_skid.wav", true)
	if drift_stream:
		drift_player.stream = drift_stream
		drift_player.volume_db = -3.0
		drift_player.pitch_scale = 0.9
		add_child(drift_player)

	# 5. Tiếng va chạm va quẹt chướng ngại vật
	bump_player = AudioStreamPlayer3D.new()
	var bump_stream := _load_wav_stream("res://assets/audio/crash_bump.wav", false)
	if bump_stream:
		bump_player.stream = bump_stream
		bump_player.volume_db = 2.0
		add_child(bump_player)

	# 6. Tiếng kích hoạt Slipstream / Drift boost
	boost_player = AudioStreamPlayer.new()
	var boost_stream := _load_wav_stream("res://assets/audio/slipstream_boost.wav", false)
	if boost_stream:
		boost_player.stream = boost_stream
		boost_player.volume_db = 1.0
		add_child(boost_player)

func _load_wav_stream(res_path: String, is_loop: bool = false) -> AudioStreamWAV:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("load_wav"):
		return fx.load_wav(res_path, is_loop)
	if not FileAccess.file_exists(res_path):
		return null
	var file := FileAccess.open(res_path, FileAccess.READ)
	if not file:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 44:
		return null
	var data := bytes.slice(44)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data = data
	if is_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	return stream

func _setup_near_miss_area() -> void:
	near_miss_area = Area3D.new()
	near_miss_area.name = "NearMissZone"
	near_miss_area.monitoring = true
	near_miss_area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.4, 1.6, 2.8) # Lách trong phạm vi ~2.2m hai bên = "sát nút"
	shape.shape = box
	shape.position = Vector3(0.0, 0.8, 0.0)
	near_miss_area.add_child(shape)
	add_child(near_miss_area)
	near_miss_area.body_entered.connect(_on_near_body_entered)
	near_miss_area.body_exited.connect(_on_near_body_exited)
	# Jolt (Godot 4.4+) không cho Area3D thấy StaticBody3D -> xe NPC gắn thêm Area3D "near_miss_tag",
	# phát hiện area-area hoạt động trên mọi engine vật lý.
	near_miss_area.area_entered.connect(_on_near_area_entered)
	near_miss_area.area_exited.connect(_on_near_area_exited)

## Gắn thẻ near-miss (Area3D) lên một xe NPC để vùng near-miss của người chơi phát hiện được.
static func attach_near_miss_tag(body: Node3D, size: Vector3, center_y: float) -> Area3D:
	var tag := Area3D.new()
	tag.name = "NearMissTag"
	tag.add_to_group("near_miss_tag")
	tag.monitoring = false
	tag.monitorable = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0.0, center_y, 0.0)
	tag.add_child(cs)
	body.add_child(tag)
	return tag

func _on_near_area_entered(area: Area3D) -> void:
	if not area.is_in_group("near_miss_tag"):
		return
	var body: Node3D = area.get_parent() as Node3D
	if body and body != self:
		_on_near_body_entered(body)

func _on_near_area_exited(area: Area3D) -> void:
	if not area.is_in_group("near_miss_tag"):
		return
	var body: Node3D = area.get_parent() as Node3D
	if body:
		_on_near_body_exited(body)

func _setup_drift_smoke() -> void:
	smoke_particles = CPUParticles3D.new()
	smoke_particles.emitting = false
	smoke_particles.amount = 28
	smoke_particles.lifetime = 0.7
	smoke_particles.one_shot = false
	smoke_particles.explosiveness = 0.0
	smoke_particles.direction = Vector3(0.0, 0.6, 1.0)
	smoke_particles.spread = 35.0
	smoke_particles.initial_velocity_min = 1.2
	smoke_particles.initial_velocity_max = 2.6
	smoke_particles.gravity = Vector3(0.0, 0.9, 0.0)
	smoke_particles.scale_amount_min = 0.25
	smoke_particles.scale_amount_max = 0.7
	smoke_particles.color = Color(0.85, 0.85, 0.85, 0.55)
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	sm.material = mat
	smoke_particles.mesh = sm
	smoke_particles.position = Vector3(0.0, 0.18, 0.66)
	visual_pivot.add_child(smoke_particles)

func _build_procedural_bike_and_seated_rider() -> void:
	# 1–3. XE TAY GA CHI TIẾT (PropBuilder): lắp vào các pivot của scene để bánh quay & ghi-đông bẻ lái như cũ
	front_wheel.set("mesh", null)
	rear_wheel.set("mesh", null)
	PropBuilder.build_scooter_parts(visual_pivot, front_wheel, rear_wheel, handlebar_pivot, Color("#2C3E50"), {"headlight_energy": 2.2})
	var spot := SpotLight3D.new()
	spot.light_color = Color("#FFF9C4")
	spot.light_energy = 2.4
	spot.spot_range = 28.0
	spot.spot_angle = 35.0
	spot.position = Vector3(0.0, 0.9, -0.7)
	spot.rotation_degrees = Vector3(-8.0, 180.0, 0.0)
	visual_pivot.add_child(spot)

	# 4. SINH VIÊN FPTU NGỒI LÁI XE – CharacterBuilder (mặt, tóc, áo polo FPT, ba lô, mũ bảo hiểm, tay ôm ghi-đông)
	#    Gốc nhân vật đặt tại yên: hông ở 0.62 m trên gốc khi ở clip "ride"; yên xe cao 0.85 m → gốc y = 0.23.
	rider_node = CharacterBuilder.build({"preset": "rider", "seed": 2805, "name": "SeatedFPTURider", "helmet_color": Color("#0066CC"), "backpack": true, "clip": "ride", "glasses": false})
	rider_node.position = Vector3(0.0, 0.32, 0.14)
	visual_pivot.add_child(rider_node)
	CharacterBuilder.set_param(rider_node, "ride_shoulder", 1.2)
	CharacterBuilder.set_param(rider_node, "ride_elbow", 0.28)
	CharacterBuilder.set_param(rider_node, "ride_lean", 0.4)

# ---------------------------------------------------------------------------
# VẬT LÝ CHÍNH
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_controls_locked:
		current_speed_ms = move_toward(current_speed_ms, 0.0, brake_decel * delta)
		velocity = -global_transform.basis.z * current_speed_ms
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_set_drifting(false)
		_update_chase_camera(delta, clampf(absf(current_speed_ms) / max_speed_ms, 0.0, 1.2))
		emit_signal("speed_changed", absf(current_speed_ms) * 3.6, slipstream_charge, false)
		return

	drift_boost_timer = maxf(0.0, drift_boost_timer - delta)
	if near_miss_chain_timer > 0.0:
		near_miss_chain_timer -= delta
		if near_miss_chain_timer <= 0.0:
			near_miss_chain = 0

	# 1. Núp gió (Slipstream Boost) trong cự ly 8m sau F-Bus / VinBus
	var hitting_bus: bool = false
	if slipstream_ray.is_colliding():
		var col: Object = slipstream_ray.get_collider()
		if col and col.is_in_group("slipstream_vehicle"):
			hitting_bus = true

	if hitting_bus and current_speed_ms > 8.0:
		slipstream_charge = clampf(slipstream_charge + delta * 0.55, 0.0, 1.0)
		if not is_slipstream_boosting and slipstream_charge >= 0.35:
			is_slipstream_boosting = true
			add_camera_shake(0.25)
			if boost_player:
				boost_player.play()
	else:
		slipstream_charge = clampf(slipstream_charge - delta * 0.25, 0.0, 1.0)
		if slipstream_charge <= 0.05:
			is_slipstream_boosting = false

	# 2. Gia tốc / phanh / lùi / ma sát / cản gió
	var gas_input: float = Input.get_action_strength("gas")
	var brake_input: float = Input.get_action_strength("brake")
	var drift_held: bool = Input.is_action_pressed("drift")

	var target_top_speed: float = slipstream_max_ms if is_slipstream_boosting else max_speed_ms
	if drift_boost_timer > 0.0:
		target_top_speed += drift_boost_bonus_ms

	if gas_input > 0.0:
		var boost_mult: float = 1.0
		if is_slipstream_boosting:
			boost_mult = 1.45
		if drift_boost_timer > 0.0:
			boost_mult *= 1.6
		if is_drifting:
			boost_mult *= 0.55
		current_speed_ms += engine_accel * boost_mult * gas_input * delta
	elif brake_input > 0.0:
		if current_speed_ms > 0.05:
			current_speed_ms = maxf(0.0, current_speed_ms - brake_decel * brake_input * delta)
		else:
			# Lùi xe chậm khi đã dừng hẳn (hữu ích trong bãi xe D1)
			current_speed_ms = move_toward(current_speed_ms, -reverse_speed_ms, 6.0 * delta)
	else:
		current_speed_ms = move_toward(current_speed_ms, 0.0, rolling_friction * delta)

	if is_drifting:
		current_speed_ms = move_toward(current_speed_ms, 0.0, 2.2 * delta)

	# Lực cản không khí tỷ lệ với bình phương vận tốc (có dấu)
	var drag_loss: float = air_drag * current_speed_ms * absf(current_speed_ms) * delta
	current_speed_ms = clampf(current_speed_ms - drag_loss, -reverse_speed_ms, target_top_speed)

	# 3. Bẻ lái & nghiêng thân xe + DRIFT
	var raw_steer: float = Input.get_axis("steer_right", "steer_left")
	steer_input = lerpf(steer_input, raw_steer, delta * 9.0)

	var speed_factor: float = clampf(absf(current_speed_ms) / max_speed_ms, 0.0, 1.2)
	var can_drift: bool = drift_held and absf(current_speed_ms) > drift_min_speed_ms and absf(steer_input) > 0.15 and is_on_floor()
	_set_drifting(can_drift)
	if is_drifting:
		drift_time += delta

	var steer_mult: float = (drift_steer_mult if is_drifting else 1.0) * rain_factor
	if is_drifting and rain_factor < 1.0:
		steer_mult *= 1.25 # Mưa trơn: drift văng mạnh hơn
	if absf(current_speed_ms) > 0.5:
		var dir_sign: float = 1.0 if current_speed_ms >= 0.0 else -1.0
		rotate_y(steer_input * steer_speed * steer_mult * clampf(speed_factor, 0.25, 1.0) * delta * dir_sign)

	# Văng đuôi xe: khi drift hoặc khi vừa phanh gấp vừa bẻ lái
	var skid_yaw: float = 0.0
	if is_drifting:
		skid_yaw = steer_input * 0.42
	elif brake_input > 0.5 and current_speed_ms > 10.0:
		skid_yaw = steer_input * 0.16
	RearSkidOffset = lerpf(RearSkidOffset, skid_yaw, delta * 8.0)

	var target_tilt: float = steer_input * max_tilt_angle * speed_factor * (1.25 if is_drifting else 1.0)
	tilt_angle = lerpf(tilt_angle, target_tilt, delta * 10.0)
	visual_pivot.rotation.z = tilt_angle
	if rider_node:
		CharacterBuilder.set_param(rider_node, "lean", -tilt_angle * 0.35)
	visual_pivot.rotation.y = RearSkidOffset
	handlebar_pivot.rotation.y = steer_input * 0.38

	# 4. Trọng lực (không còn nhảy: xe Wave không nhảy, ổ gà phải né bằng tay lái)
	if not is_on_floor():
		velocity.y -= gravity * delta

	var suspension_bob: float = sin(Time.get_ticks_msec() * 0.025) * 0.025 * speed_factor
	visual_pivot.position.y = lerpf(visual_pivot.position.y, suspension_bob, delta * 12.0)

	var wheel_rot: float = (current_speed_ms / 0.32) * delta
	front_wheel.rotate_x(-wheel_rot)
	rear_wheel.rotate_x(-wheel_rot)

	# 5. Di chuyển & va chạm xe lưu thông
	var forward_dir: Vector3 = -global_transform.basis.z
	velocity.x = forward_dir.x * current_speed_ms
	velocity.z = forward_dir.z * current_speed_ms
	move_and_slide()
	apply_floor_snap()

	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider and collider.is_in_group("traffic_obstacle"):
			_on_obstacle_hit(collider)
			break

	_check_fall_and_offroad(delta)
	_update_audio_dynamics(delta, gas_input, brake_input)
	_update_chase_camera(delta, speed_factor)

	emit_signal("speed_changed", absf(current_speed_ms) * 3.6, slipstream_charge, is_slipstream_boosting or drift_boost_timer > 0.0)

func _set_drifting(active: bool) -> void:
	if active == is_drifting:
		return
	is_drifting = active
	if active:
		drift_time = 0.0
		if drift_player and not drift_player.playing:
			drift_player.play()
		if smoke_particles:
			smoke_particles.emitting = true
	else:
		if drift_player:
			drift_player.stop()
		if smoke_particles:
			smoke_particles.emitting = false
		if drift_time >= drift_boost_min_time and absf(current_speed_ms) > drift_min_speed_ms:
			drift_boost_timer = 1.0
			add_camera_shake(0.2)
			if boost_player:
				boost_player.play()
			emit_signal("drift_boost", 1.0)
		drift_time = 0.0
	emit_signal("drift_state_changed", is_drifting)

# ---------------------------------------------------------------------------
# NEAR-MISS: lách sát xe khác mà không va chạm
# ---------------------------------------------------------------------------
func _on_near_body_entered(body: Node3D) -> void:
	if body == self or not body.is_in_group("traffic_obstacle"):
		return
	if near_candidates.has(body):
		return
	near_candidates[body] = {"collided": false}

func _on_near_body_exited(body: Node3D) -> void:
	if not near_candidates.has(body):
		return
	var info: Dictionary = near_candidates[body]
	near_candidates.erase(body)
	if info.get("collided", false):
		return
	if is_controls_locked or respawn_invulnerable_timer > 0.0:
		return
	if current_speed_ms * 3.6 < 50.0:
		return
	near_miss_chain = (near_miss_chain + 1) if near_miss_chain_timer > 0.0 else 1
	near_miss_chain_timer = NEAR_MISS_CHAIN_WINDOW
	longest_near_miss_chain = maxi(longest_near_miss_chain, near_miss_chain)
	add_camera_shake(0.08 + 0.03 * float(mini(near_miss_chain, 4)))
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx:
		# Cao độ tăng theo chuỗi: 1.0 / 1.15 / 1.3 (Crazy Taxi "Crazy Through")
		fx.play_sfx("whoosh", -4.0, [1.0, 1.15, 1.3][mini(near_miss_chain, 3) - 1])
		if near_miss_chain >= 3:
			fx.hit_stop(0.04, 0.1)
	emit_signal("near_miss", near_miss_chain)

# ---------------------------------------------------------------------------
# ÂM THANH ĐỘNG
# ---------------------------------------------------------------------------
func _update_audio_dynamics(delta: float, gas_input: float, brake_input: float) -> void:
	if Input.is_action_just_pressed("horn"):
		if horn_player:
			horn_player.play()

	if engine_player and engine_player.playing:
		var speed_ratio: float = clampf(absf(current_speed_ms) / max_speed_ms, 0.0, 1.25)
		var target_pitch: float = 0.85 + speed_ratio * 0.95 + gas_input * 0.25
		engine_player.pitch_scale = lerpf(engine_player.pitch_scale, target_pitch, delta * 8.0)
		engine_player.volume_db = lerpf(engine_player.volume_db, -5.0 + gas_input * 3.5, delta * 6.0)

	if wind_player and wind_player.playing:
		var speed_kmh: float = absf(current_speed_ms) * 3.6
		if speed_kmh > 45.0:
			var wind_ratio: float = clampf((speed_kmh - 45.0) / 45.0, 0.0, 1.0)
			wind_player.volume_db = lerpf(wind_player.volume_db, -26.0 + wind_ratio * 20.0, delta * 4.0)
		else:
			wind_player.volume_db = lerpf(wind_player.volume_db, -80.0, delta * 6.0)

	if brake_input > 0.65 and current_speed_ms > 9.5 and not is_drifting:
		if skid_player and not skid_player.playing:
			skid_player.play()

# ---------------------------------------------------------------------------
# RƠI KHỎI MAP / LỀ CỎ / KẸP LÀN
# ---------------------------------------------------------------------------
func _check_fall_and_offroad(delta: float) -> void:
	if respawn_invulnerable_timer > 0.0:
		respawn_invulnerable_timer -= delta
		visual_pivot.visible = (int(Time.get_ticks_msec() / 120) % 2 == 0)
		if respawn_invulnerable_timer <= 0.0:
			visual_pivot.visible = true

	if not road_path or not road_path.curve:
		if global_position.y < -3.5:
			global_position = Vector3(2.0, 0.8, -4.0)
			velocity = Vector3.ZERO
			current_speed_ms = 0.0
		return

	var closest_offset: float = road_path.curve.get_closest_offset(global_position)
	var road_pt: Vector3 = road_path.curve.sample_baked(closest_offset)
	var lateral: Vector3 = Vector3(global_position.x - road_pt.x, 0.0, global_position.z - road_pt.z)
	var horiz_dist: float = lateral.length()

	# 1. Rơi khỏi map (lọt xuống rạch nước / bay quá xa)
	if global_position.y < -3.5 or horiz_dist > 35.0:
		_perform_road_respawn(closest_offset)
		return

	var was_offroad: bool = is_offroad
	if lane_clamp_enabled and horiz_dist > road_hard_limit:
		# 2. Vượt quá gờ đường: đặt lại ở mép trong của đường, giữ hướng, phạt nhẹ
		var dir: Vector3 = lateral.normalized()
		var edge: Vector3 = road_pt + dir * (road_half_width - 0.6)
		global_position.x = edge.x
		global_position.z = edge.z
		global_position.y = maxf(global_position.y, road_pt.y + 0.3)
		current_speed_ms *= 0.45
		add_camera_shake(0.4)
		if bump_player:
			bump_player.play()
		is_offroad = false
		emit_signal("curb_hit", 1.0)
		emit_signal("crash_occurred")
	elif lane_clamp_enabled and horiz_dist > road_half_width and is_on_floor():
		# 3. Leo lề: đẩy xe về lòng đường, hãm tốc, rung lắc
		is_offroad = true
		var dir: Vector3 = lateral.normalized()
		var target: Vector3 = road_pt + dir * (road_half_width - 0.35)
		global_position.x = lerpf(global_position.x, target.x, delta * 7.0)
		global_position.z = lerpf(global_position.z, target.z, delta * 7.0)
		current_speed_ms = minf(current_speed_ms, 9.0)
		visual_pivot.position.x = (randf() - 0.5) * 0.08
	elif not lane_clamp_enabled and horiz_dist > 6.8 and is_on_floor():
		is_offroad = true
		visual_pivot.position.x = (randf() - 0.5) * 0.08
		current_speed_ms = minf(current_speed_ms, 7.0)
	else:
		is_offroad = false
		visual_pivot.position.x = 0.0

	if was_offroad != is_offroad:
		emit_signal("offroad_changed", is_offroad)

func _perform_road_respawn(closest_offset: float) -> void:
	if bump_player:
		bump_player.play()

	var safe_offset: float = maxf(0.0, closest_offset - 8.0)
	var safe_xform: Transform3D = road_path.curve.sample_baked_with_rotation(safe_offset)

	global_position = safe_xform.origin + Vector3(0.0, 0.65, 0.0)

	var forward_tangent: Vector3 = -safe_xform.basis.z
	forward_tangent.y = 0.0
	if forward_tangent.length_squared() > 0.001:
		look_at(global_position + forward_tangent.normalized(), Vector3.UP)

	velocity = Vector3.ZERO
	current_speed_ms = 0.0
	tilt_angle = 0.0
	RearSkidOffset = 0.0
	slipstream_charge = 0.0
	is_slipstream_boosting = false
	_set_drifting(false)
	drift_boost_timer = 0.0
	respawn_invulnerable_timer = 1.5

	emit_signal("respawned", 3.0)
	emit_signal("crash_occurred")

func _on_obstacle_hit(collider: Object = null) -> void:
	if collider and near_candidates.has(collider):
		near_candidates[collider]["collided"] = true
	near_miss_chain = 0
	near_miss_chain_timer = 0.0
	if bump_player:
		bump_player.play()
	add_camera_shake(0.65)
	if current_speed_ms > 6.0:
		current_speed_ms *= 0.35
		slipstream_charge = 0.0
		is_slipstream_boosting = false
		drift_boost_timer = 0.0
		emit_signal("crash_occurred")

## Ổ gà: không chặn xe nhưng làm mất tốc + xóc mạnh
func hit_pothole() -> void:
	if respawn_invulnerable_timer > 0.0:
		return
	if bump_player:
		bump_player.play()
	add_camera_shake(0.45)
	current_speed_ms *= 0.62
	var tw := create_tween()
	tw.tween_property(visual_pivot, "position:y", -0.12, 0.06)
	tw.tween_property(visual_pivot, "position:y", 0.0, 0.14)
	emit_signal("crash_occurred")

## Va chướng ngại mềm (chó, người) : mất tốc nặng + shake
func hit_soft_obstacle() -> void:
	near_miss_chain = 0
	if bump_player:
		bump_player.play()
	add_camera_shake(0.7)
	current_speed_ms *= 0.25
	drift_boost_timer = 0.0
	emit_signal("crash_occurred")

func _update_chase_camera(delta: float, speed_factor: float) -> void:
	spring_arm.rotation.y = lerpf(spring_arm.rotation.y, -steer_input * (0.22 if is_drifting else 0.14), delta * 6.0)
	var extra_fov: float = 0.0
	if is_slipstream_boosting:
		extra_fov += 6.0
	if drift_boost_timer > 0.0:
		extra_fov += 8.0
	var target_fov: float = 68.0 + speed_factor * 14.0 + extra_fov
	chase_cam.fov = lerpf(chase_cam.fov, target_fov, delta * 5.0)

	if camera_shake_trauma > 0.0:
		camera_shake_trauma = maxf(camera_shake_trauma - delta * 2.4, 0.0)
		var shake: float = camera_shake_trauma * camera_shake_trauma * 0.22
		chase_cam.h_offset = randf_range(-shake, shake)
		chase_cam.v_offset = randf_range(-shake, shake)
	else:
		chase_cam.h_offset = 0.0
		chase_cam.v_offset = 0.0
