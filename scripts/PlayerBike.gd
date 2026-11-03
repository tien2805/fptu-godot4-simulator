# File: res://scripts/PlayerBike.gd
# Xe máy sinh viên FPTU: vật lý arcade, DRIFT [SPACE], lùi xe [S khi dừng], núp gió F-Bus,
# near-miss (lách sát xe khác), kẹp ranh giới làn đường, âm thanh động cơ/gió/lết bánh.
# Owner's bike (spec owner-bike OB-D1..D5): the model is OwnerBikeBuilder (silver / black underbone); speed profiles
# STAGE_PROFILE (Stage 1, Stage 2, the bike chase) and OWNER_PROFILE (FreeRoam: 120 km/h) via apply_speed_profile();
# lights: a forward headlight (low / high beam on [L], on only at DARK_PRESETS via set_time_of_day, haze at night), tail
# brighter while braking, the red / blue strobe bar (strobe_state, off while parked = NOTIFICATION_DISABLED); owner sounds
# sfx_dir/bike_exhaust (engine loop) and sfx_dir/bike_horn (horn_tap: melody on / off, ducks the music, pedestrians within
# HORN_RADIUS cheer through horn_targets_fn), loaded once on WorkerThreadPool tasks, fallback to the res:// wavs.
# Tokyo Drift (spec D2X-8 / D2X-9, plan 2026-10-27-d2x-drift.md):
#   - nitro: set_nitro_enabled(on) (FreeRoam's owner bike, the chase and the drift duel; never Stage 1 / Stage 2),
#     drift_charge 0-100 (drifting 25 per second x drift_charge_mult, near misses +8, add_drift_charge for the rest),
#     [SHIFT] fires at NITRO_MIN or more: the whole charge for NITRO_FULL_S x charge / 100, +NITRO_BONUS_MS on top of the
#     profile max, stronger acceleration, NitroFX blue flame, FOV punch, whoosh; nitro_active() (also the ram flag),
#     signals nitro_started / nitro_ended; the NitroGauge shows while enabled and ridden;
#   - duck: hold [CTRL] while riding (is_ducking): steering x DUCK_STEER, drag x DUCK_DRAG, the rider flat on the tank;
#   - real revs: rev_blip() plays the owner's sfx_dir/bike_rev (+REV_DB_OVER over the riding engine level, 2 voices),
#     else a throttle blip of the exhaust loop; set_staged(on) holds the bike on a start line with the engine idling and
#     each [W] press revving (one start per REV_MIN_GAP).
# Q1 camera director (spec 2026-10-29): the chase camera is BikeCamRig (scripts/camera/) on the scene's CameraRig /
# SpringArm3D / Camera3D (CameraRules: low chase cam, distance and FOV by speed, nitro, drift swing to the outside, roll
# with the lean, road shake); cam_whip(dir) is the 0.12 s whip of a kick hit; add_camera_shake keeps its meaning.
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
signal nitro_started
signal nitro_ended

@export var road_path: Path3D

## Speed profiles (OB-D2). STAGE = the exports' defaults (Stage 1 is tuned to its 90 s clock; Stage 2 and the bike chase
## use it too). OWNER = free roam and story roam: 120 km/h, 130 in a slipstream. The quadratic drag already took the old
## bike to 81 km/h in ~2.2 s, so the owner profile lowers the drag a little and raises the thrust: never slower off the
## line than before, ~2.4 s to 100 km/h, ~3.5 s to 120 km/h.
const STAGE_PROFILE: Dictionary = {"max_speed_ms": 22.5, "slipstream_max_ms": 27.0, "engine_accel": 13.5, "air_drag": 0.015}
const OWNER_PROFILE: Dictionary = {"max_speed_ms": 33.3, "slipstream_max_ms": 36.1, "engine_accel": 15.0, "air_drag": 0.0105}
## Lights (OB-D5): the real headlight only at these presets; the haze cone only at night.
const DARK_PRESETS: Array[String] = ["night", "sunset", "dawn"]
const LOW_BEAM: Dictionary = {"range": 40.0, "angle": 30.0, "energy": 3.0, "tilt": -5.0, "lens": 2.6}
const HIGH_BEAM: Dictionary = {"range": 70.0, "angle": 20.0, "energy": 5.0, "tilt": -2.0, "lens": 3.6}
const BEAM_EDGE: float = 2.2
const STROBE_CYCLE: float = 1.2           # 3 quick red flashes, then 3 quick blue ones
const STROBE_ON_ENERGY: float = 6.0
const STROBE_RED: Color = Color(1.0, 0.12, 0.1)
const STROBE_BLUE: Color = Color(0.18, 0.38, 1.0)
const TAIL_ENERGY: float = 1.4
const BRAKE_ENERGY: float = 4.5
## Owner sounds (OB-D3, OB-D4): sfx_dir/<name>.ogg | .mp3 | .wav, local only, never committed.
const SFX_EXHAUST: String = "bike_exhaust"
const SFX_HORN: String = "bike_horn"
const SFX_REV: String = "bike_rev"
## Nitro (D2X-8).
const NITRO_MIN: float = 34.0
const NITRO_FULL_S: float = 3.0
const NITRO_BONUS_MS: float = 8.0
const NITRO_ACCEL_MULT: float = 2.2
const NITRO_FOV: float = 8.0
const NITRO_FOV_PUNCH: float = 6.0       # extra FOV at ignition, decaying over NITRO_PUNCH_S
const NITRO_PUNCH_S: float = 0.5
const DRIFT_CHARGE_RATE: float = 25.0    # per second of drifting
const NEAR_MISS_CHARGE: float = 8.0
const NITRO_COAST_DECEL: float = 6.0     # m/s per second the extra speed fades after a burn
## The muffler tip of OwnerBikeBuilder (visual pivot space) and the way the flame points.
const EXHAUST_TIP: Vector3 = Vector3(0.2, 0.456, 0.81)
const EXHAUST_DIR: Vector3 = Vector3(0.0, 0.17, 1.0)
## Duck (D2X-9).
const DUCK_STEER: float = 0.9
const DUCK_DRAG: float = 0.85
## Revs (owner request 2026-10-27): +4 dB over the riding engine, 2 voices, one player start per 0.35 s; the fallback
## blip of the exhaust loop: idle -> REV_BLIP_PITCH -> idle over REV_BLIP_S.
const REV_DB_OVER: float = 4.0
const REV_VOICES: int = 2
const REV_MIN_GAP: float = 0.35
const REV_BLIP_S: float = 0.8
const REV_BLIP_UP: float = 0.22
const REV_BLIP_PITCH: float = 1.2
const HORN_RADIUS: float = 14.0
const HORN_SCAN_S: float = 0.5
const HORN_FADE_S: float = 0.15
const HORN_DUCK_DB: float = -8.0
const MELODY_DB: float = 0.0

## The owner's sound folder (tests point it at an empty temp folder).
static var sfx_dir: String = "user://sfx/"
static var _owner_cache: Dictionary = {}   # file path -> AudioStream (null = failed to load)
static var _owner_tasks: Dictionary = {}   # file path -> {"task": int, "box": [AudioStream]}

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
## Không có road_path (bãi xe Màn 2, thế giới mở): rơi dưới fallback_fall_y thì đặt lại tại fallback_respawn
## (mặc định = toạ độ cũ của Màn 2; FreeRoam đặt điểm spawn BE6 và ngưỡng -5 m).
@export var fallback_respawn: Vector3 = Vector3(2.0, 0.8, -4.0)
@export var fallback_fall_y: float = -3.5

var current_speed_ms: float = 0.0
## Wave 2: a hard speed cap applied in the physics step after every boost (RoadSetPieces' flood water; INF = none).
var speed_cap: float = INF
## Wave 2: physics frame of the last counted crash per collider (one crash per collider per CRASH_COOLDOWN_S).
var _crash_frames: Dictionary = {}
const CRASH_COOLDOWN_S: float = 1.5
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

# Owner's bike: model parts, lights, owner sounds, horn melody (OB-D1..D5)
var bike_parts: Dictionary = {}           # OwnerBikeBuilder.build() result
var headlight: SpotLight3D
var headlight_haze: Node3D
var strobe_glow: OmniLight3D
var high_beam: bool = false
var lights_preset: String = ""
var lights_dark: bool = false
var strobe_t: float = 0.0
var strobe_color: int = 0                 # 0 off, 1 red, 2 blue
var braking: bool = false
var _tail_lit: bool = false
var _tod_set: bool = false
var owner_exhaust: bool = false           # the engine plays the owner's loop
var melody_stream: AudioStream            # the owner's horn melody (null = the short wav horn)
var melody_player: AudioStreamPlayer3D
var melody_left: float = 0.0              # seconds of melody left (counted here, not by the audio driver)
## -> Array of nodes; the Pedestrians among them within HORN_RADIUS cheer while the melody plays (FreeRoam sets it).
var horn_targets_fn: Callable
var horn_cheers: int = 0
var _dancers: Array = []
var _scan_t: float = 0.0
var _owner_pending: bool = false
var _ducked: bool = false
var _fade_tw: Tween
## Stage 1 finish / Stage 2 parking (park()): locked for good, strobe off, headlight off, melody stopped.
var parked: bool = false

# Nitro, duck, revs (D2X-8 / D2X-9)
var nitro_enabled: bool = false
var drift_charge: float = 0.0
## A drift zone owner (chase, duel) sets 1.5 while the bike is inside a zone.
var drift_charge_mult: float = 1.0
var nitro_left: float = 0.0
var nitro_len: float = 0.0
var nitro_count: int = 0
var nitro_refusals: int = 0
var nitro_fx: NitroFX
var nitro_gauge: NitroGauge
var nitro_player: AudioStreamPlayer
var _nitro_punch: float = 0.0
var _coast_cap: float = 0.0
var _burning: bool = false
var ducking: bool = false
var duck_w: float = 0.0
var staged: bool = false
var revs: int = 0
var rev_source: String = ""               # "file" | "blip" (the last rev)
var rev_stream: AudioStream               # the owner's bike_rev (null = the exhaust blip)
var _rev_players: Array[AudioStreamPlayer3D] = []
var _rev_cd: float = 0.0
var _blip_t: float = -1.0
var _rider_base: Vector3 = Vector3(0.0, 0.32, 0.14)
## Q1: the chase camera rig (scripts/camera/BikeCamRig.gd).
var cam_rig: BikeCamRig

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
		if fx_node.has_signal("art_style_changed"):
			fx_node.connect("art_style_changed", _on_art_style_changed)
	_setup_drift_smoke()
	if nitro_enabled:
		_ensure_nitro_nodes()
	_auto_time_of_day.call_deferred()
	slipstream_ray.target_position = Vector3(0.0, 0.0, -8.5) # Quét cự ly 8.5m phía trước
	slipstream_ray.enabled = true
	cam_rig = BikeCamRig.new(self)
	cam_rig.attach()
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
		"horn": [KEY_H, KEY_B],
		"high_beam": [KEY_L],
		"nitro": [KEY_SHIFT],
		"duck": [KEY_CTRL]
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
	engine_player.name = "Engine"
	engine_player.unit_size = 8.0
	engine_player.max_distance = 65.0
	engine_player.volume_db = -4.0
	engine_player.pitch_scale = 0.85
	add_child(engine_player)
	var engine_stream := _load_wav_stream("res://assets/audio/bike_engine_loop.wav", true)
	if engine_stream:
		engine_player.stream = engine_stream
		engine_player.play()

	# 2. Còi xe máy đĩa đôi bim bim (+ còi nhạc của chủ game: melody_player)
	horn_player = AudioStreamPlayer3D.new()
	horn_player.name = "Horn"
	horn_player.unit_size = 12.0
	horn_player.max_distance = 80.0
	horn_player.volume_db = 2.0
	add_child(horn_player)
	var horn_stream := _load_wav_stream("res://assets/audio/bike_horn.wav", false)
	if horn_stream:
		horn_player.stream = horn_stream
	melody_player = AudioStreamPlayer3D.new()
	melody_player.name = "HornMelody"
	melody_player.unit_size = 14.0
	melody_player.max_distance = 90.0
	melody_player.volume_db = MELODY_DB
	add_child(melody_player)
	for i: int in REV_VOICES:
		var rp := AudioStreamPlayer3D.new()
		rp.name = "Rev%d" % i
		rp.unit_size = 8.0
		rp.max_distance = 70.0
		add_child(rp)
		_rev_players.append(rp)
	# owner files (OB-D3, OB-D4): loaded on worker threads, adopted by _poll_owner_sfx()
	warm_owner_sfx()
	_owner_pending = true
	_poll_owner_sfx()

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
	# 1–3. XE CỦA CHỦ GAME (OwnerBikeBuilder, OB-D1): lắp vào các pivot của scene để bánh quay & ghi-đông bẻ lái như cũ
	front_wheel.set("mesh", null)
	rear_wheel.set("mesh", null)
	bike_parts = OwnerBikeBuilder.build(visual_pivot, front_wheel, rear_wheel, handlebar_pivot)
	_build_lights()

	# 4. SINH VIÊN FPTU NGỒI LÁI XE – CharacterBuilder (mặt, tóc, áo polo FPT, ba lô, mũ bảo hiểm, tay ôm ghi-đông)
	#    Gốc nhân vật đặt tại yên: hông ở 0.62 m trên gốc khi ở clip "ride"; yên xe cao 0.85 m → gốc y = 0.23.
	rider_node = CharacterBuilder.build(_rider_opts())
	rider_node.position = Vector3(0.0, 0.32, 0.14)
	visual_pivot.add_child(rider_node)
	CharacterBuilder.set_param(rider_node, "ride_shoulder", 1.2)
	CharacterBuilder.set_param(rider_node, "ride_elbow", 0.28)
	CharacterBuilder.set_param(rider_node, "ride_lean", 0.4)


func _rider_opts() -> Dictionary:
	SideRewards.pending = false   # w5-side: a rider built now wears the current pick (no stale wait from an older world)
	var ro: Dictionary = {"preset": "rider", "seed": 2805, "name": "SeatedFPTURider", "helmet_color": Color("#0066CC"), "backpack": true, "clip": "ride", "glasses": false}
	var hero: Dictionary = StoryUtil.hero_opts()
	if not hero.is_empty():
		# story (A2-D5): the rider is the protagonist (sex, skin, face; the helmet stays on)
		for k: String in ["female", "skin", "hair_color", "hair_style", "variant"]:
			ro[k] = hero[k]
	SideRewards.apply_rider(ro)   # w4-endings T5e: the helmet / jacket colours picked in the phone's Tủ đồ
	return ro


## w5-side T4: rebuilds the seated rider with the colours chosen now (SideRewards.apply_live, from the phone's Tủ đồ),
## keeping the duck pose, the turn / lean and the visibility. Only while the story is free: a bike fight caches the rider's
## skeleton (PlayerBikeCombat.setup) and a story recording holds the rider node.
func refresh_rider_look() -> void:
	if rider_node == null or not is_instance_valid(rider_node) or visual_pivot == null:
		return
	var old: Node3D = rider_node
	var at: Vector3 = old.position
	var rot: Vector3 = old.rotation
	var vis: bool = old.visible
	var par: Node = old.get_parent()
	if par:
		par.remove_child(old)
	old.queue_free()
	rider_node = CharacterBuilder.build(_rider_opts())
	rider_node.position = at
	rider_node.rotation = rot
	rider_node.visible = vis
	(par if par else visual_pivot).add_child(rider_node)
	CharacterBuilder.set_param(rider_node, "ride_shoulder", lerpf(1.2, 1.02, duck_w))
	CharacterBuilder.set_param(rider_node, "ride_elbow", lerpf(0.28, 1.0, duck_w))
	CharacterBuilder.set_param(rider_node, "ride_lean", lerpf(0.4, 1.05, duck_w))
	CharacterBuilder.set_param(rider_node, "lean", -tilt_angle * 0.35)

# ---------------------------------------------------------------------------
# ĐÈN XE (OB-D5): đèn pha chiếu tới (-Z), cos / pha [L], đèn hậu + phanh, đèn nháy xanh đỏ
# ---------------------------------------------------------------------------
func _build_lights() -> void:
	headlight = SpotLight3D.new()
	headlight.name = "Headlight"
	headlight.light_color = Color("#FFF4D8")
	headlight.spot_angle_attenuation = BEAM_EDGE
	headlight.spot_attenuation = 1.2
	headlight.shadow_enabled = false
	headlight.position = bike_parts.get("headlamp_pos", Vector3(0.0, 0.0, -0.2))
	handlebar_pivot.add_child(headlight)   # steers with the handlebar cowl
	_apply_beam()
	# night haze: the CineFX headlight cones (without the dust motes), shown only at night
	CineFX._build_haze(handlebar_pivot, headlight)
	headlight_haze = handlebar_pivot.get_node_or_null("HeadlightHaze") as Node3D
	if headlight_haze:
		var dust: Node = headlight_haze.get_node_or_null("HeadlightDust")
		if dust:
			dust.free()
	strobe_glow = OmniLight3D.new()
	strobe_glow.name = "StrobeGlow"
	strobe_glow.omni_range = 4.0
	strobe_glow.light_energy = 0.9
	strobe_glow.shadow_enabled = false
	strobe_glow.position = (bike_parts.get("strobe_pos", Vector3(0.0, 0.66, 0.93)) as Vector3) + Vector3(0.0, -0.15, 0.15)
	visual_pivot.add_child(strobe_glow)
	_apply_lights_visibility()
	_apply_strobe(0, true)
	_update_tail(true)


func _apply_beam() -> void:
	var b: Dictionary = HIGH_BEAM if high_beam else LOW_BEAM
	if headlight:
		headlight.spot_range = float(b["range"])
		headlight.spot_angle = float(b["angle"])
		headlight.light_energy = float(b["energy"])
		headlight.rotation_degrees = Vector3(float(b["tilt"]), 0.0, 0.0)
		if headlight_haze:
			# the haze cones were built for the low beam's angle: follow the beam's tilt and narrow with its angle
			var k: float = tan(deg_to_rad(float(b["angle"]))) / tan(deg_to_rad(float(LOW_BEAM["angle"])))
			headlight_haze.transform = headlight.transform.scaled_local(Vector3(k, k, 1.0))
	var lens: StandardMaterial3D = bike_parts.get("headlamp_mat") as StandardMaterial3D
	if lens:
		lens.emission_energy_multiplier = float(b["lens"])


## The lamp materials must never be restyled: ViceStyle's classic pass strips their "vice_done" tag, a later vice pass
## then restyles them and snapshots their energy at that moment (the next classic pass would bring a stale strobe or
## brake energy back). After every style change (GameFX.art_style_changed) and every time-of-day change: tag them again,
## drop the snapshot, put the lamp look back and rewrite every energy from the bike's state.
func refresh_lamp_materials() -> void:
	for key: String in ["headlamp_mat", "tail_mat", "pos_lamp_mat", "strobe_red_mat", "strobe_blue_mat"]:
		var m: StandardMaterial3D = bike_parts.get(key) as StandardMaterial3D
		if m == null:
			continue
		for tag: StringName in [&"vice_orig", &"vice_soft_emitter", &"vice_window"]:
			if m.has_meta(tag):
				m.remove_meta(tag)
		m.set_meta("vice_done", true)
		m.roughness = OwnerBikeBuilder.LAMP_ROUGHNESS
		m.metallic = OwnerBikeBuilder.LAMP_METALLIC
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		m.normal_enabled = false
		m.next_pass = null
		m.emission_enabled = true
	var pos: StandardMaterial3D = bike_parts.get("pos_lamp_mat") as StandardMaterial3D
	if pos:
		pos.emission_energy_multiplier = OwnerBikeBuilder.POS_LAMP_ENERGY
	_apply_beam()
	_apply_strobe(strobe_color, true)
	_update_tail(true)


func _on_art_style_changed(_style: String) -> void:
	refresh_lamp_materials()


## Stage 1 finish, Stage 2 parked: the bike stays where it is for good (locked, never disabled). Strobe and headlight
## off, tail back to normal, the horn melody stops at once (the music comes back up).
func park() -> void:
	parked = true
	is_controls_locked = true
	_park_lights_and_horn()


func _park_lights_and_horn() -> void:
	braking = false
	if not bike_parts.is_empty():
		_apply_strobe(0, true)
		_update_tail(true)
	stop_horn_melody(false)
	_apply_lights_visibility()


## [L]: low beam <-> high beam.
func toggle_high_beam() -> void:
	high_beam = not high_beam
	_apply_beam()


## The world's time of day (FreeRoam.set_time_of_day; Stage 1 / Stage 2 read the scene's preset once): the headlight is on
## at DARK_PRESETS, the haze only at night. The lens, tail and strobe meshes glow whatever the time.
func set_time_of_day(preset: String) -> void:
	_tod_set = true
	lights_preset = preset
	lights_dark = preset in DARK_PRESETS
	refresh_lamp_materials()   # the time-of-day pass may have run ViceStyle over the scene
	_apply_lights_visibility()


func _auto_time_of_day() -> void:
	if _tod_set or not is_inside_tree():
		return
	var n: Node = get_parent()
	while n != null:
		if n.has_meta("visual_preset"):
			set_time_of_day(String(n.get_meta("visual_preset")))
			return
		n = n.get_parent()


## The headlight and the haze shine only at dark presets while the bike is ridden (not parked, not disabled).
func headlight_on() -> bool:
	return lights_dark and not parked and (not is_inside_tree() or can_process())


func _apply_lights_visibility() -> void:
	var on: bool = headlight_on()
	if headlight:
		headlight.visible = on
	if headlight_haze:
		headlight_haze.visible = on and lights_preset == "night"
	if strobe_glow:
		strobe_glow.visible = lights_dark and strobe_color != 0


## Strobe colour at time t of the cycle: 0 off, 1 red, 2 blue (3 flashes of 0.1 s every 0.2 s per colour, 1.2 s cycle).
static func strobe_state(t: float) -> int:
	var ph: float = fposmod(t, STROBE_CYCLE)
	var half: float = STROBE_CYCLE * 0.5
	var slot: float = fposmod(ph, half) / (half / 3.0)
	if slot - floorf(slot) >= 0.5:
		return 0
	return 1 if ph < half else 2


func _apply_strobe(c: int, force: bool = false) -> void:
	if c == strobe_color and not force:
		return
	strobe_color = c
	var red: StandardMaterial3D = bike_parts.get("strobe_red_mat") as StandardMaterial3D
	var blue: StandardMaterial3D = bike_parts.get("strobe_blue_mat") as StandardMaterial3D
	if red:
		red.emission_energy_multiplier = STROBE_ON_ENERGY if c == 1 else 0.0
	if blue:
		blue.emission_energy_multiplier = STROBE_ON_ENERGY if c == 2 else 0.0
	if strobe_glow:
		strobe_glow.visible = lights_dark and c != 0
		if c != 0:
			strobe_glow.light_color = STROBE_RED if c == 1 else STROBE_BLUE


func _update_tail(force: bool = false) -> void:
	if braking == _tail_lit and not force:
		return
	_tail_lit = braking
	var tail: StandardMaterial3D = bike_parts.get("tail_mat") as StandardMaterial3D
	if tail:
		tail.emission_energy_multiplier = BRAKE_ENERGY if braking else TAIL_ENERGY


## Current tail light energy (tests).
func tail_energy() -> float:
	var tail: StandardMaterial3D = bike_parts.get("tail_mat") as StandardMaterial3D
	return tail.emission_energy_multiplier if tail else 0.0


## Strobe, tail, owner sounds and the horn melody: every physics frame the bike runs (also while locked).
func _tick_extras(delta: float) -> void:
	if _owner_pending:
		_poll_owner_sfx()
	strobe_t = fposmod(strobe_t + delta, STROBE_CYCLE)
	_apply_strobe(0 if parked else strobe_state(strobe_t))
	_update_tail()
	_tick_horn(delta)
	_tick_rev(delta)
	if nitro_fx and nitro_fx.on:
		nitro_fx.tick(delta)
	if nitro_gauge:
		_sync_gauge(delta)


## Parked (FreeRoam disables the bike): strobe and headlight off, tail back to normal, the melody stops at once.
## Enabled again (mounted): the headlight follows the time of day again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		_park_lights_and_horn()
		_end_nitro()
		_set_ducking(false)
		if nitro_gauge:
			nitro_gauge.visible = false
	elif what == NOTIFICATION_ENABLED:
		_apply_lights_visibility()


func _exit_tree() -> void:
	if _ducked:
		_duck_music(false)


# ---------------------------------------------------------------------------
# TỐC ĐỘ (OB-D2)
# ---------------------------------------------------------------------------
func apply_speed_profile(p: Dictionary) -> void:
	for k: String in p.keys():
		set(k, float(p[k]))


func speed_profile() -> Dictionary:
	return {"max_speed_ms": max_speed_ms, "slipstream_max_ms": slipstream_max_ms, "engine_accel": engine_accel, "air_drag": air_drag}


# ---------------------------------------------------------------------------
# NITRO (D2X-8)
# ---------------------------------------------------------------------------
## Nitro on (FreeRoam's owner bike, the chase, the drift duel) or off (a burn ends; the charge stays). Stage 1 and
## Stage 2 never turn it on. The flame, the whoosh and the gauge are built on the first enable.
func set_nitro_enabled(on: bool) -> void:
	nitro_enabled = on
	if not on:
		_end_nitro()
	if is_node_ready():
		if on:
			_ensure_nitro_nodes()
		if nitro_gauge:
			_sync_gauge(0.0)


## A burn is running (also the nitro-ram flag: touching a biker now is a takedown).
func nitro_active() -> bool:
	return _burning


func add_drift_charge(points: float) -> void:
	drift_charge = clampf(drift_charge + points, 0.0, 100.0)


## [SHIFT]: spends the whole charge (at least NITRO_MIN) on a burn of NITRO_FULL_S x charge / 100. false when it cannot
## (off, burning, too little charge, locked, parked; counted in nitro_refusals while enabled).
func fire_nitro() -> bool:
	if not nitro_enabled or _burning or drift_charge < NITRO_MIN or is_controls_locked or parked:
		if nitro_enabled:
			nitro_refusals += 1
		return false
	_ensure_nitro_nodes()
	nitro_len = NITRO_FULL_S * drift_charge / 100.0
	nitro_left = nitro_len
	drift_charge = 0.0
	nitro_count += 1
	_burning = true
	_nitro_punch = NITRO_PUNCH_S
	_coast_cap = 0.0
	add_camera_shake(0.35)
	if chase_cam:
		chase_cam.fov += NITRO_FOV_PUNCH   # the kick lands on this frame, the lerp holds it
	if nitro_fx:
		nitro_fx.set_on(true)
	if nitro_player and nitro_player.stream and nitro_player.is_inside_tree():
		nitro_player.play()
	if boost_player and boost_player.stream:
		boost_player.play()
	nitro_started.emit()
	return true


## The burn ends (time out, respawn, lock, park, disable, nitro off): the extra speed fades (NITRO_COAST_DECEL).
func _end_nitro() -> void:
	if not _burning:
		return
	_burning = false
	nitro_left = 0.0
	_coast_cap = current_speed_ms
	if nitro_fx:
		nitro_fx.set_on(false)
	nitro_ended.emit()


func _ensure_nitro_nodes() -> void:
	if nitro_fx == null and visual_pivot:
		nitro_fx = NitroFX.build(visual_pivot, EXHAUST_TIP, EXHAUST_DIR)
	if nitro_player == null:
		nitro_player = AudioStreamPlayer.new()
		nitro_player.name = "NitroWhoosh"
		nitro_player.volume_db = 1.0
		nitro_player.stream = NitroFX.whoosh_stream()
		add_child(nitro_player)
		var fx_node: Node = get_node_or_null("/root/GameFX") if is_inside_tree() else null
		if fx_node:
			fx_node.route_audio_to_bus(nitro_player, "SFX")
	if nitro_gauge == null:
		nitro_gauge = NitroGauge.new()
		nitro_gauge.name = "NitroGauge"
		nitro_gauge.bike = self
		add_child(nitro_gauge)


## The gauge shows while nitro is enabled, the bike is ridden (processing, shown, not parked) and its chase camera is the
## current camera (not in cinematics or replays).
func gauge_shown() -> bool:
	return nitro_enabled and not parked and visible and is_inside_tree() and can_process() and chase_cam != null \
		and chase_cam.current


func _sync_gauge(delta: float) -> void:
	var show: bool = gauge_shown()
	if nitro_gauge.visible != show:
		nitro_gauge.visible = show
	if show:
		nitro_gauge.refresh(drift_charge, _burning, nitro_left / maxf(nitro_len, 0.01), delta)


# ---------------------------------------------------------------------------
# DUCK (D2X-9)
# ---------------------------------------------------------------------------
func is_ducking() -> bool:
	return ducking


func _set_ducking(on: bool) -> void:
	ducking = on


## The rider eases flat on the tank and back (every physics frame, also while locked).
func _tick_duck_pose(delta: float) -> void:
	var target: float = 1.0 if ducking else 0.0
	if duck_w == target or rider_node == null:
		return
	duck_w = move_toward(duck_w, target, delta * 6.0)
	rider_node.position = _rider_base + Vector3(0.0, -0.07, -0.07) * duck_w
	CharacterBuilder.set_param(rider_node, "ride_lean", lerpf(0.4, 1.05, duck_w))
	CharacterBuilder.set_param(rider_node, "ride_elbow", lerpf(0.28, 1.0, duck_w))
	CharacterBuilder.set_param(rider_node, "ride_shoulder", lerpf(1.2, 1.02, duck_w))


# ---------------------------------------------------------------------------
# REVS (owner request: real recordings, a bit louder)
# ---------------------------------------------------------------------------
## One rev: the owner's bike_rev on a free voice (REV_VOICES, the oldest is reused) at rev_db(), else a throttle blip of
## the exhaust loop (rev_blip_pitch over REV_BLIP_S, same level). One start per REV_MIN_GAP unless forced (the countdown).
func rev_blip(force: bool = false) -> bool:
	if not force and _rev_cd > 0.0:
		return false
	_rev_cd = REV_MIN_GAP
	revs += 1
	if rev_stream == null and owner_sfx_state(SFX_REV) == 2:
		rev_stream = owner_sfx(SFX_REV, false)   # never waits on the main thread
	if rev_stream and not _rev_players.is_empty():
		var p: AudioStreamPlayer3D = _rev_voice()
		p.stream = rev_stream
		p.pitch_scale = 1.0
		p.volume_db = rev_db()
		p.play()
		rev_source = "file"
	else:
		_blip_t = 0.0
		rev_source = "blip"
	return true


func _rev_voice() -> AudioStreamPlayer3D:
	var best: AudioStreamPlayer3D = _rev_players[0]
	var oldest: float = -1.0
	for p: AudioStreamPlayer3D in _rev_players:
		if not p.playing:
			return p
		var at: float = p.get_playback_position()
		if at > oldest:
			oldest = at
			best = p
	return best


## Rev voices playing now (tests).
func rev_voices_playing() -> int:
	var n: int = 0
	for p: AudioStreamPlayer3D in _rev_players:
		if p.playing:
			n += 1
	return n


## The engine level while riding at full throttle (the owner loop or the res:// wav); revs sit REV_DB_OVER above it.
func riding_engine_db() -> float:
	return exhaust_db(1.0) if owner_exhaust else -1.5


func rev_db() -> float:
	return riding_engine_db() + REV_DB_OVER


func idle_pitch() -> float:
	return exhaust_pitch(0.0, 0.0) if owner_exhaust else 0.85


func idle_db() -> float:
	return exhaust_db(0.0) if owner_exhaust else -5.0


## The fallback blip: idle -> peak (REV_BLIP_PITCH for the owner loop's idle 0.62, scaled for another idle) over
## REV_BLIP_UP, back to idle at REV_BLIP_S.
static func rev_blip_pitch(t: float, idle: float) -> float:
	if t <= 0.0 or t >= REV_BLIP_S:
		return idle
	var peak: float = idle * REV_BLIP_PITCH / 0.62
	if t < REV_BLIP_UP:
		return lerpf(idle, peak, smoothstep(0.0, REV_BLIP_UP, t))
	return lerpf(peak, idle, smoothstep(REV_BLIP_UP, REV_BLIP_S, t))


func _tick_rev(delta: float) -> void:
	if _rev_cd > 0.0:
		_rev_cd -= delta
	_tick_duck_pose(delta)
	if _blip_t < 0.0:
		return
	_blip_t += delta
	if engine_player == null:
		_blip_t = -1.0
		return
	if _blip_t >= REV_BLIP_S:
		_blip_t = -1.0
		engine_player.pitch_scale = idle_pitch()
		engine_player.volume_db = idle_db()
		return
	engine_player.pitch_scale = rev_blip_pitch(_blip_t, idle_pitch())
	engine_player.volume_db = rev_db()


## On a start line: locked, stopped, the engine idling, each [W] press revs (one start per REV_MIN_GAP). Off = GO: the
## bike rides (unlocked) and the engine loop jumps to full throttle.
func set_staged(on: bool) -> void:
	staged = on
	if on:
		is_controls_locked = true
		current_speed_ms = 0.0
		velocity = Vector3.ZERO
		return
	is_controls_locked = false
	_blip_t = -1.0
	if engine_player:
		engine_player.pitch_scale = exhaust_pitch(0.0, 1.0) if owner_exhaust else 1.1
		engine_player.volume_db = riding_engine_db()


func _staged_audio(delta: float) -> void:
	if Input.is_action_just_pressed("gas"):
		rev_blip()
	if _blip_t < 0.0 and engine_player:
		engine_player.pitch_scale = lerpf(engine_player.pitch_scale, idle_pitch(), delta * 8.0)
		engine_player.volume_db = lerpf(engine_player.volume_db, idle_db(), delta * 6.0)


# ---------------------------------------------------------------------------
# ÂM THANH CỦA CHỦ GAME (OB-D3, OB-D4): pô + còi nhạc, nạp một lần trên WorkerThreadPool
# ---------------------------------------------------------------------------
## The owner's file for name: sfx_dir/<name>.ogg, .mp3 or .wav ("" when there is none).
static func owner_file(name: String) -> String:
	for ext: String in [".ogg", ".mp3", ".wav"]:
		var p: String = sfx_dir + name + ext
		if FileAccess.file_exists(p):
			return p
	return ""


## Starts one WorkerThreadPool task per owner file (exhaust, horn, rev) that is neither cached nor loading. Returns the count.
static func warm_owner_sfx() -> int:
	var n: int = 0
	for name: String in [SFX_EXHAUST, SFX_HORN, SFX_REV]:
		var p: String = owner_file(name)
		if p == "" or _owner_cache.has(p) or _owner_tasks.has(p):
			continue
		var box: Array = [null]
		_owner_tasks[p] = {"task": WorkerThreadPool.add_task(_owner_job(box, p)), "box": box}
		n += 1
	return n


static func _owner_job(box: Array, p: String) -> Callable:
	return func() -> void: box[0] = AudioStreamWAV.load_from_file(p) if p.ends_with(".wav") else CineAudio._load_file(p)


## 0 = no owner file, 1 = loading, 2 = ready (or failed to load: then owner_sfx() returns null).
static func owner_sfx_state(name: String) -> int:
	var p: String = owner_file(name)
	if p == "":
		return 0
	_adopt_owner(p, false)
	if _owner_cache.has(p):
		return 2
	return 1 if _owner_tasks.has(p) else 0


## The owner's stream for name (the exhaust loops), or null (no file, still loading without `wait`, or unreadable).
static func owner_sfx(name: String, wait: bool) -> AudioStream:
	var p: String = owner_file(name)
	if p == "":
		return null
	if not _owner_cache.has(p) and not _owner_tasks.has(p):
		warm_owner_sfx()
	_adopt_owner(p, wait)
	return _owner_cache.get(p) as AudioStream


static func _adopt_owner(p: String, wait: bool) -> void:
	if not _owner_tasks.has(p):
		return
	var t: Dictionary = _owner_tasks[p]
	if not wait and not WorkerThreadPool.is_task_completed(int(t["task"])):
		return
	WorkerThreadPool.wait_for_task_completion(int(t["task"]))
	_owner_tasks.erase(p)
	var st: AudioStream = (t["box"] as Array)[0]
	if st and p.get_file().get_basename() == SFX_EXHAUST:
		StoryAudio._set_loop(st, true)
	elif st:
		_set_no_loop(st)   # the horn melody and the rev play once (an owner WAV may carry loop points)
	_owner_cache[p] = st


static func _set_no_loop(st: AudioStream) -> void:
	if st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = false
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = false


## Waits for every loading task and empties the cache (tests, exit).
static func clear_owner_sfx() -> void:
	for p: String in _owner_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int((_owner_tasks[p] as Dictionary)["task"]))
	_owner_tasks.clear()
	_owner_cache.clear()


func _poll_owner_sfx() -> void:
	var ex_state: int = owner_sfx_state(SFX_EXHAUST)
	var horn_state: int = owner_sfx_state(SFX_HORN)
	if ex_state == 2 and not owner_exhaust:
		var st: AudioStream = owner_sfx(SFX_EXHAUST, false)
		if st and engine_player:
			owner_exhaust = true
			engine_player.stream = st
			engine_player.pitch_scale = exhaust_pitch(0.0, 0.0)
			engine_player.volume_db = exhaust_db(0.0)
			engine_player.play()
	if horn_state == 2 and melody_stream == null:
		melody_stream = owner_sfx(SFX_HORN, false)
	var rev_state: int = owner_sfx_state(SFX_REV)
	if rev_state == 2 and rev_stream == null:
		rev_stream = owner_sfx(SFX_REV, false)
	_owner_pending = ex_state == 1 or horn_state == 1 or rev_state == 1


## Owner exhaust loop pitch: 0.62 idle, 1.0 at 70 % of top speed, 1.18 at top (a slipstream continues the slope), +0.06
## under throttle.
static func exhaust_pitch(speed_ratio: float, gas: float) -> float:
	var r: float = clampf(speed_ratio, 0.0, 1.25)
	var p: float = lerpf(0.62, 1.0, r / 0.7) if r <= 0.7 else 1.0 + (r - 0.7) / 0.3 * 0.18
	return p + 0.06 * clampf(gas, 0.0, 1.0)


## Owner exhaust loop volume: -10 dB at idle, +4 dB under full throttle.
static func exhaust_db(gas: float) -> float:
	return lerpf(-10.0, 4.0, clampf(gas, 0.0, 1.0))


## The horn key: with the owner's melody a tap plays it from the start and a tap while it plays stops it (0.15 s fade);
## without it the short wav horn plays as before.
func horn_tap() -> void:
	if melody_stream == null and owner_sfx_state(SFX_HORN) == 2:
		melody_stream = owner_sfx(SFX_HORN, false)   # still loading: never wait on the main thread, the wav horn plays
	if melody_stream:
		if melody_left > 0.0:
			stop_horn_melody(true)
		else:
			_start_melody()
		return
	if horn_player and horn_player.stream:
		horn_player.play()


func horn_melody_playing() -> bool:
	return melody_left > 0.0


func _start_melody() -> void:
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = null
	melody_player.stream = melody_stream
	melody_player.volume_db = MELODY_DB
	melody_player.play(0.0)
	melody_left = maxf(melody_stream.get_length(), 0.1)
	_scan_t = 0.0
	_dancers.clear()
	_duck_music(true)


## Stops the melody (fade: 0.15 s, else at once); the bike's dancers stop at once.
func stop_horn_melody(fade: bool = true) -> void:
	if melody_left <= 0.0:
		return
	melody_left = 0.0
	_end_dancers()
	_duck_music(false)
	if melody_player == null:
		return
	if fade and melody_player.playing and is_inside_tree() and can_process():
		_fade_tw = create_tween()
		_fade_tw.tween_property(melody_player, "volume_db", -40.0, HORN_FADE_S)
		_fade_tw.tween_callback(melody_player.stop)
	else:
		melody_player.stop()


func _tick_horn(delta: float) -> void:
	if melody_left <= 0.0:
		return
	melody_left -= delta
	if melody_left <= 0.0:
		melody_left = 0.0
		_dancers.clear()   # their reaction ends with the melody by itself
		_duck_music(false)
		if melody_player:
			melody_player.stop()
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = HORN_SCAN_S
		_cheer_scan()


## Real pedestrians within HORN_RADIUS that can react (walking or standing) raise both arms and bounce (the "clap"
## reaction = the cheer clip) for the rest of the melody (at least 1 s). Officers, cast and enemies are never in the list.
func _cheer_scan() -> void:
	if not horn_targets_fn.is_valid():
		return
	var me: Vector3 = global_position
	var secs: float = maxf(1.0, melody_left)
	var r2: float = HORN_RADIUS * HORN_RADIUS
	for n: Variant in horn_targets_fn.call():
		if not is_instance_valid(n) or not (n is Pedestrian):
			continue
		var p: Pedestrian = n
		if not p.is_inside_tree() or not p.can_react_emote():
			continue
		var dx: float = p.global_position.x - me.x
		var dz: float = p.global_position.z - me.z
		if dx * dx + dz * dz > r2:
			continue
		if p.react_emote("clap", me, secs):
			_dancers.append(p)
			horn_cheers += 1


func _end_dancers() -> void:
	for d: Variant in _dancers:
		if is_instance_valid(d) and (d as Pedestrian).react_kind == "clap":
			(d as Pedestrian).end_react()
	_dancers.clear()


## Roam music ducks by HORN_DUCK_DB while the melody plays (only when nothing else ducks it), back afterwards.
func _duck_music(on: bool) -> void:
	var fx: Node = get_node_or_null("/root/GameFX") if is_inside_tree() else null
	var md: Object = fx.get("music") if fx else null
	if md == null:
		_ducked = false
		return
	var lin: float = db_to_linear(HORN_DUCK_DB)
	if on:
		if not _ducked and float(md.get("duck_target")) >= 0.999:
			md.set("duck_target", lin)
			_ducked = true
	elif _ducked:
		_ducked = false
		if absf(float(md.get("duck_target")) - lin) < 0.001:
			md.call("duck", false)

# ---------------------------------------------------------------------------
# VẬT LÝ CHÍNH
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_tick_extras(delta)
	if is_controls_locked:
		braking = false
		_end_nitro()
		_set_ducking(false)
		if staged:
			_staged_audio(delta)
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
	braking = brake_input > 0.1 and current_speed_ms > 0.3
	_set_ducking(Input.is_action_pressed("duck"))
	# NITRO (D2X-8): [SHIFT] fires the charge; while it burns the throttle is full (unless braking)
	if nitro_enabled and Input.is_action_just_pressed("nitro"):
		fire_nitro()
	if nitro_left > 0.0:
		nitro_left -= delta
		if nitro_left <= 0.0:
			_end_nitro()
		elif brake_input <= 0.1:
			gas_input = 1.0

	var target_top_speed: float = slipstream_max_ms if is_slipstream_boosting else max_speed_ms
	if drift_boost_timer > 0.0:
		target_top_speed += drift_boost_bonus_ms
	if nitro_left > 0.0:
		target_top_speed += NITRO_BONUS_MS

	if gas_input > 0.0:
		var boost_mult: float = 1.0
		if is_slipstream_boosting:
			boost_mult = 1.45
		if drift_boost_timer > 0.0:
			boost_mult *= 1.6
		if nitro_left > 0.0:
			boost_mult *= NITRO_ACCEL_MULT
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
	var drag_loss: float = air_drag * current_speed_ms * absf(current_speed_ms) * delta * (DUCK_DRAG if ducking else 1.0)
	if _coast_cap > target_top_speed:   # after a nitro burn the extra speed fades instead of snapping off
		_coast_cap = maxf(target_top_speed, _coast_cap - NITRO_COAST_DECEL * delta)
		target_top_speed = maxf(target_top_speed, minf(_coast_cap, current_speed_ms))
	current_speed_ms = clampf(current_speed_ms - drag_loss, -reverse_speed_ms, minf(target_top_speed, speed_cap))

	# 3. Bẻ lái & nghiêng thân xe + DRIFT
	var raw_steer: float = Input.get_axis("steer_right", "steer_left")
	steer_input = lerpf(steer_input, raw_steer, delta * 9.0)

	var speed_factor: float = clampf(absf(current_speed_ms) / max_speed_ms, 0.0, 1.2)
	var can_drift: bool = drift_held and absf(current_speed_ms) > drift_min_speed_ms and absf(steer_input) > 0.15 and is_on_floor()
	_set_drifting(can_drift)
	if is_drifting:
		drift_time += delta
		if nitro_enabled:
			drift_charge = minf(100.0, drift_charge + DRIFT_CHARGE_RATE * drift_charge_mult * delta)

	var steer_mult: float = (drift_steer_mult if is_drifting else 1.0) * rain_factor * (DUCK_STEER if ducking else 1.0)
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
	if nitro_enabled:
		add_drift_charge(NEAR_MISS_CHARGE)
	longest_near_miss_chain = maxi(longest_near_miss_chain, near_miss_chain)
	add_camera_shake(0.08 + 0.03 * float(mini(near_miss_chain, 4)))
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx:
		# Cao độ tăng theo chuỗi: 1.0 / 1.15 / 1.3 (Crazy Taxi "Crazy Through")
		fx.play_sfx("whoosh", -4.0, [1.0, 1.15, 1.3][mini(near_miss_chain, 3) - 1])
		if near_miss_chain >= 3 and not (fx.has_method("time_scale_owned") and bool(fx.call("time_scale_owned"))):
			fx.hit_stop(0.04, 0.1)   # never over a slow motion that owns the time scale (RadialWheel.scale_owner)
	emit_signal("near_miss", near_miss_chain)

# ---------------------------------------------------------------------------
# ÂM THANH ĐỘNG
# ---------------------------------------------------------------------------
func _update_audio_dynamics(delta: float, gas_input: float, brake_input: float) -> void:
	if Input.is_action_just_pressed("horn"):
		horn_tap()   # Stage 2 reads the same action for its rival
	if Input.is_action_just_pressed("high_beam"):
		toggle_high_beam()

	if engine_player and engine_player.playing and _blip_t < 0.0:
		var speed_ratio: float = clampf(absf(current_speed_ms) / max_speed_ms, 0.0, 1.25)
		if nitro_left > 0.0:
			speed_ratio += 0.12   # the engine screams a little higher while nitro burns
		if owner_exhaust:
			engine_player.pitch_scale = lerpf(engine_player.pitch_scale, exhaust_pitch(speed_ratio, gas_input), delta * 8.0)
			engine_player.volume_db = lerpf(engine_player.volume_db, exhaust_db(gas_input), delta * 6.0)
		else:
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
		if global_position.y < fallback_fall_y:
			global_position = fallback_respawn
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
	_end_nitro()
	_coast_cap = 0.0
	respawn_invulnerable_timer = 1.5

	emit_signal("respawned", 3.0)
	emit_signal("crash_occurred")

func _on_obstacle_hit(collider: Object = null) -> void:
	if collider and near_candidates.has(collider):
		near_candidates[collider]["collided"] = true
	near_miss_chain = 0
	near_miss_chain_timer = 0.0
	# the body still stops the bike on every contact; scraping along the same body (a bus, a jam car) counts as one crash
	# (the bump, the shake, crash_occurred) per CRASH_COOLDOWN_S, not one per physics frame
	var counted: bool = true
	if collider != null:
		var now: int = Engine.get_physics_frames()
		var key: int = collider.get_instance_id()
		var last: int = int(_crash_frames.get(key, -1000000))
		counted = now - last >= int(CRASH_COOLDOWN_S * float(Engine.physics_ticks_per_second))
		if counted:
			if _crash_frames.size() > 32:
				_crash_frames.clear()
			_crash_frames[key] = now
	if counted:
		if bump_player:
			bump_player.play()
		add_camera_shake(0.65)
	if current_speed_ms > 6.0:
		current_speed_ms *= 0.35
		slipstream_charge = 0.0
		is_slipstream_boosting = false
		drift_boost_timer = 0.0
		if counted:
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
	if cam_rig:
		cam_rig.update(delta, speed_factor)
	if _nitro_punch > 0.0:
		_nitro_punch = maxf(0.0, _nitro_punch - delta)


## Q1: the 0.12 s whip of the chase camera toward a world direction (a kick hit; CameraDirector.punch with a dir).
func cam_whip(dir: Vector3) -> void:
	if cam_rig:
		cam_rig.whip(dir)
