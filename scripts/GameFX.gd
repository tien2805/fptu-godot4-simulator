# File: res://scripts/GameFX.gd
# Autoload "GameFX": bộ hiệu ứng "juice" dùng chung cho mọi màn chơi.
# - Screen shake cho camera đang active (h_offset / v_offset)
# - Flash toàn màn, vignette nhịp tim (shader canvas_item)
# - Hit-stop & slow-motion an toàn (tự khôi phục Engine.time_scale)
# - Chữ bay 3D (Label3D) và popup 2D ở giữa màn hình
# - Nạp WAV dùng chung + ngân hàng SFX tổng hợp bằng code (không cần file)
extends Node

const FPT_ORANGE := Color("#F37021")
const FPT_GREEN := Color("#2ECC71")
const FPT_RED := Color("#E74C3C")
const FPT_YELLOW := Color("#F1C40F")

var _layer: CanvasLayer
var _flash_rect: ColorRect
var _vignette_rect: ColorRect
var _vignette_mat: ShaderMaterial
var _popup_root: VBoxContainer

var _shake_trauma: float = 0.0
var _shake_cam: Camera3D

var _vignette_strength: float = 0.0
var _vignette_target: float = 0.0
var _vignette_pulse_hz: float = 0.0
var _vignette_color: Color = Color(0.9, 0.1, 0.1)

var _slowmo_token: int = 0
var _sfx_bank: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.9, 0.1, 0.1, 1.0);
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 1.6;
	float a = smoothstep(0.35, 1.05, d) * strength;
	COLOR = vec4(tint.rgb, a);
}
"""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)

	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.color = Color.WHITE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	_vignette_mat.set_shader_parameter("strength", 0.0)
	_vignette_rect.material = _vignette_mat
	_layer.add_child(_vignette_rect)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	_layer.add_child(_flash_rect)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)
	_popup_root = VBoxContainer.new()
	_popup_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_root.add_theme_constant_override("separation", 6)
	center.add_child(_popup_root)

	for i: int in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

	# Khi đổi scene, dọn hiệu ứng còn sót lại
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	# Scene gốc mới được add -> reset trạng thái FX
	if node.get_parent() == get_tree().root and node != self:
		reset_all()

func reset_all() -> void:
	_shake_trauma = 0.0
	if is_instance_valid(_shake_cam):
		_shake_cam.h_offset = 0.0
		_shake_cam.v_offset = 0.0
	_shake_cam = null
	_vignette_strength = 0.0
	_vignette_target = 0.0
	_vignette_pulse_hz = 0.0
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("strength", 0.0)
	if _flash_rect:
		_flash_rect.color.a = 0.0
	_slowmo_token += 1
	Engine.time_scale = 1.0
	if _popup_root:
		for c: Node in _popup_root.get_children():
			c.queue_free()

func _process(delta: float) -> void:
	_process_shake(delta)
	_process_vignette(delta)

# ---------------------------------------------------------------------------
# SCREEN SHAKE (cho camera đang active; không dùng cho PlayerBike vì xe tự lo)
# ---------------------------------------------------------------------------
func shake(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)

func _process_shake(delta: float) -> void:
	var vp := get_viewport()
	if not vp:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam != _shake_cam:
		if is_instance_valid(_shake_cam):
			_shake_cam.h_offset = 0.0
			_shake_cam.v_offset = 0.0
		_shake_cam = cam
	if not cam:
		return
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(_shake_trauma - delta * 2.6, 0.0)
		var s: float = _shake_trauma * _shake_trauma * 0.25
		cam.h_offset = randf_range(-s, s)
		cam.v_offset = randf_range(-s, s)
	elif cam.h_offset != 0.0 or cam.v_offset != 0.0:
		# Chỉ reset nếu không có ai khác (PlayerBike) đang điều khiển offset
		if not cam.get_parent() or not cam.get_parent().get_parent() or not (cam.get_parent().get_parent().get_parent() is CharacterBody3D):
			cam.h_offset = 0.0
			cam.v_offset = 0.0

# ---------------------------------------------------------------------------
# FLASH & VIGNETTE
# ---------------------------------------------------------------------------
func flash(color: Color = Color.WHITE, alpha: float = 0.55, duration: float = 0.28) -> void:
	_flash_rect.color = Color(color.r, color.g, color.b, alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)

## Đặt vignette cố định (strength 0..1). pulse_hz > 0 -> nhấp nháy theo nhịp tim.
func set_vignette(strength: float, color: Color = Color(0.9, 0.1, 0.1), pulse_hz: float = 0.0) -> void:
	_vignette_target = clampf(strength, 0.0, 1.0)
	_vignette_color = color
	_vignette_pulse_hz = pulse_hz
	_vignette_mat.set_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))

func clear_vignette() -> void:
	set_vignette(0.0)

func _process_vignette(delta: float) -> void:
	_vignette_strength = lerpf(_vignette_strength, _vignette_target, delta * 6.0)
	var s: float = _vignette_strength
	if _vignette_pulse_hz > 0.0 and s > 0.01:
		var t: float = Time.get_ticks_msec() * 0.001 * _vignette_pulse_hz * TAU
		s *= 0.65 + 0.35 * maxf(0.0, sin(t))
	_vignette_mat.set_shader_parameter("strength", s)

# ---------------------------------------------------------------------------
# HIT-STOP & SLOW MOTION
# ---------------------------------------------------------------------------
func hit_stop(duration: float = 0.07, scale: float = 0.05) -> void:
	slow_motion(scale, duration)

## Làm chậm thời gian trong `real_seconds` giây thực, rồi tự khôi phục.
func slow_motion(scale: float = 0.3, real_seconds: float = 1.2) -> void:
	_slowmo_token += 1
	var my_token: int = _slowmo_token
	Engine.time_scale = clampf(scale, 0.02, 1.0)
	var timer := get_tree().create_timer(real_seconds, true, false, true)
	timer.timeout.connect(func() -> void:
		if my_token == _slowmo_token:
			Engine.time_scale = 1.0
	)

# ---------------------------------------------------------------------------
# TEXT POPUPS
# ---------------------------------------------------------------------------
## Chữ bay 3D tại vị trí world_pos, tự bay lên và biến mất.
func float_text(parent: Node, world_pos: Vector3, text: String, color: Color = Color.WHITE, font_size: int = 40, duration: float = 1.1) -> Label3D:
	if not is_instance_valid(parent):
		return null
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = font_size
	lbl.outline_size = int(font_size * 0.3)
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = false
	parent.add_child(lbl)
	lbl.global_position = world_pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", world_pos + Vector3(0, 1.8, 0), duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, duration).set_delay(duration * 0.45)
	tw.chain().tween_callback(lbl.queue_free)
	return lbl

## Popup 2D giữa màn hình (ví dụ "SÁT NÚT! +0.5s", "PERFECT!").
func popup(text: String, color: Color = Color.WHITE, font_size: int = 34, duration: float = 0.9) -> void:
	if not _popup_root:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.pivot_offset = Vector2.ZERO
	_popup_root.add_child(lbl)
	# Giới hạn số popup đồng thời
	while _popup_root.get_child_count() > 4:
		var old: Node = _popup_root.get_child(0)
		_popup_root.remove_child(old)
		old.queue_free()
	lbl.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.25)
	tw.tween_callback(lbl.queue_free)

# ---------------------------------------------------------------------------
# AUDIO
# ---------------------------------------------------------------------------
## Nạp WAV 16-bit mono 44.1kHz do generate_audio.py tạo (header chuẩn 44 byte).
func load_wav(res_path: String, is_loop: bool = false) -> AudioStreamWAV:
	if not FileAccess.file_exists(res_path):
		return null
	var file := FileAccess.open(res_path, FileAccess.READ)
	if not file:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 44:
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data = bytes.slice(44)
	if is_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	return stream

## Phát SFX theo tên trong ngân hàng tổng hợp ("tick","hit","miss","pop","heart",
## "error","success","whoosh","shutter","growl","ring","beep","thud","cash","alarm")
## hoặc theo đường dẫn res:// tới file WAV.
func play_sfx(name_or_path: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = null
	if name_or_path.begins_with("res://"):
		if not _sfx_bank.has(name_or_path):
			_sfx_bank[name_or_path] = load_wav(name_or_path)
		stream = _sfx_bank[name_or_path]
	else:
		if not _sfx_bank.has(name_or_path):
			_sfx_bank[name_or_path] = _synth(name_or_path)
		stream = _sfx_bank[name_or_path]
	if not stream:
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_pool_idx]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % _sfx_pool.size()
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

func _make_wav(samples: PackedFloat32Array, mix_rate: int = 22050) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = mix_rate
	s.stereo = false
	s.data = data
	return s

func _synth(name: String) -> AudioStreamWAV:
	var sr: int = 22050
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	match name:
		"tick":
			_tone(out, sr, 1400.0, 0.04, 0.5, 30.0)
		"beep":
			_tone(out, sr, 1000.0, 0.09, 0.5, 18.0)
		"pop":
			_sweep(out, sr, 500.0, 950.0, 0.09, 0.6)
		"hit":
			_noise(out, sr, rng, 0.08, 0.7, 40.0)
			_tone(out, sr, 180.0, 0.10, 0.5, 20.0, true)
		"thud":
			_tone(out, sr, 110.0, 0.16, 0.8, 14.0)
			_noise(out, sr, rng, 0.05, 0.3, 50.0, true)
		"miss":
			_tone(out, sr, 190.0, 0.18, 0.5, 10.0)
			_tone(out, sr, 150.0, 0.18, 0.5, 10.0, true)
		"error":
			_tone(out, sr, 230.0, 0.13, 0.45, 12.0)
			_tone(out, sr, 170.0, 0.17, 0.45, 10.0)
		"heart":
			_tone(out, sr, 62.0, 0.11, 0.9, 22.0)
			_silence(out, sr, 0.09)
			_tone(out, sr, 55.0, 0.13, 0.7, 18.0)
		"success":
			_tone(out, sr, 523.25, 0.09, 0.45, 12.0)
			_tone(out, sr, 659.25, 0.09, 0.45, 12.0)
			_tone(out, sr, 783.99, 0.16, 0.5, 8.0)
		"cash":
			_tone(out, sr, 1560.0, 0.06, 0.4, 20.0)
			_tone(out, sr, 2080.0, 0.12, 0.4, 14.0)
		"whoosh":
			_noise(out, sr, rng, 0.26, 0.5, 6.0)
		"shutter":
			_noise(out, sr, rng, 0.025, 0.6, 80.0)
			_silence(out, sr, 0.03)
			_noise(out, sr, rng, 0.03, 0.4, 80.0)
		"growl":
			for i: int in range(3):
				_tone(out, sr, 70.0 + i * 8.0, 0.13, 0.55, 8.0)
		"ring":
			for i: int in range(2):
				_tone(out, sr, 880.0, 0.12, 0.35, 6.0)
				_tone(out, sr, 1046.0, 0.12, 0.35, 6.0)
			_silence(out, sr, 0.15)
		"alarm":
			for i: int in range(3):
				_tone(out, sr, 920.0, 0.10, 0.5, 6.0)
				_tone(out, sr, 640.0, 0.10, 0.5, 6.0)
		"jump":
			_sweep(out, sr, 300.0, 700.0, 0.14, 0.4)
		"slide":
			_noise(out, sr, rng, 0.18, 0.35, 10.0)
		"typing":
			_noise(out, sr, rng, 0.02, 0.45, 90.0)
		"explode":
			_noise(out, sr, rng, 0.22, 0.8, 12.0)
			_tone(out, sr, 90.0, 0.2, 0.6, 10.0, true)
		_:
			_tone(out, sr, 800.0, 0.08, 0.4, 20.0)
	if out.is_empty():
		return null
	return _make_wav(out, sr)

func _tone(out: PackedFloat32Array, sr: int, freq: float, dur: float, amp: float, decay: float, mix: bool = false) -> void:
	var n: int = int(dur * sr)
	var start: int = out.size()
	if mix:
		start = maxi(0, out.size() - n)
	else:
		out.resize(out.size() + n)
	for i: int in range(n):
		var t: float = float(i) / float(sr)
		var env: float = exp(-t * decay) * minf(1.0, t * 400.0)
		var v: float = sin(TAU * freq * t) * amp * env
		var idx: int = start + i
		if idx < out.size():
			out[idx] = clampf(out[idx] + v, -1.0, 1.0) if mix else v
		else:
			out.append(v)

func _sweep(out: PackedFloat32Array, sr: int, f0: float, f1: float, dur: float, amp: float) -> void:
	var n: int = int(dur * sr)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(n)
		var f: float = lerpf(f0, f1, t)
		phase += TAU * f / float(sr)
		var env: float = sin(PI * t)
		out.append(sin(phase) * amp * env)

func _noise(out: PackedFloat32Array, sr: int, rng: RandomNumberGenerator, dur: float, amp: float, decay: float, mix: bool = false) -> void:
	var n: int = int(dur * sr)
	var start: int = out.size()
	if mix:
		start = maxi(0, out.size() - n)
	else:
		out.resize(out.size() + n)
	var last: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(sr)
		var env: float = exp(-t * decay)
		# Lọc thông thấp đơn giản cho tiếng gió / va chạm mềm hơn
		last = lerpf(last, rng.randf_range(-1.0, 1.0), 0.35)
		var v: float = last * amp * env
		var idx: int = start + i
		if idx < out.size():
			out[idx] = clampf(out[idx] + v, -1.0, 1.0) if mix else v
		else:
			out.append(v)

func _silence(out: PackedFloat32Array, sr: int, dur: float) -> void:
	var n: int = int(dur * sr)
	for i: int in range(n):
		out.append(0.0)

# ---------------------------------------------------------------------------
# NÂNG CẤP RENDER (Forward+): SDFGI, SSAO, SSIL, SSR, glow, ACES, sương thể tích, bóng mềm 4 split
# ---------------------------------------------------------------------------
static func _find_first(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for c: Node in node.get_children():
		var r: Node = _find_first(c, cls)
		if r:
			return r
	return null

## Bảo đảm Environment có bầu trời ProceduralSky (phòng có cửa sổ cần thấy trời + ánh sáng trời cho SDFGI).
static func _ensure_sky(e: Environment, night: bool) -> void:
	var sm: ProceduralSkyMaterial = null
	if e.background_mode == Environment.BG_SKY and e.sky and e.sky.sky_material is ProceduralSkyMaterial:
		sm = e.sky.sky_material
	else:
		sm = ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(0.3, 0.6, 0.97)
		sm.sky_horizon_color = Color(0.8, 0.88, 0.97)
		var sky := Sky.new()
		sky.sky_material = sm
		e.sky = sky
		e.background_mode = Environment.BG_SKY
		e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		e.ambient_light_sky_contribution = 0.6
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.12
	sm.use_debanding = true
	if night:
		sm.sky_top_color = Color(0.015, 0.025, 0.07)
		sm.sky_horizon_color = Color(0.09, 0.11, 0.2)
		sm.ground_bottom_color = Color(0.015, 0.015, 0.02)
		sm.ground_horizon_color = Color(0.06, 0.06, 0.08)
		sm.sky_energy_multiplier = 0.4
	else:
		# Bán cầu dưới của sky màu trung tính: tránh ám xanh lá lên mặt dưới mái che / trần hiên
		sm.ground_bottom_color = Color(0.27, 0.26, 0.24)
		sm.ground_horizon_color = Color(0.72, 0.72, 0.7)

## Gọi ở cuối _ready của mỗi màn: preset "outdoor" (đường, campus, sân võ), "indoor" (phòng học, căn tin...)
## hoặc "night" (phòng lab 23:59 – trời đêm, trăng xanh, đèn trần & màn hình là nguồn sáng chính).
static func upgrade_scene_visuals(root: Node, preset: String = "outdoor") -> void:
	if root == null:
		return
	var outdoor: bool = preset == "outdoor"
	var night: bool = preset == "night"
	var env_node: WorldEnvironment = _find_first(root, "WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var e: Environment = env_node.environment.duplicate(true)
		env_node.environment = e
		_ensure_sky(e, night)
		e.ssao_enabled = true
		e.ssao_radius = 1.8
		e.ssao_intensity = 2.2
		e.ssao_power = 1.6
		e.ssil_enabled = true
		e.ssil_radius = 4.0
		e.ssil_intensity = 1.0
		e.sdfgi_enabled = true
		e.sdfgi_use_occlusion = true
		e.sdfgi_bounce_feedback = 0.35
		e.sdfgi_cascades = 6 if outdoor else 4
		e.sdfgi_min_cell_size = 0.3 if outdoor else 0.12
		e.sdfgi_energy = 1.0
		e.ssr_enabled = true
		e.ssr_max_steps = 96
		e.ssr_fade_in = 0.2
		e.ssr_fade_out = 2.0
		e.glow_enabled = true
		e.glow_intensity = 0.9 if night else 0.55
		e.glow_bloom = 0.22 if night else 0.1
		e.glow_hdr_threshold = 1.05
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		e.tonemap_mode = Environment.TONE_MAPPER_ACES
		e.tonemap_exposure = 1.0 if (outdoor or night) else 1.1
		e.tonemap_white = 4.0
		e.adjustment_enabled = true
		e.adjustment_brightness = 1.02
		e.adjustment_contrast = 1.07
		e.adjustment_saturation = 1.0
		if outdoor:
			e.fog_enabled = true
			e.fog_density = 0.00016
			e.fog_sun_scatter = 0.06
			e.fog_aerial_perspective = 0.2
			e.fog_sky_affect = 0.04
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = 0.0014
			e.volumetric_fog_albedo = Color(0.9, 0.93, 1.0)
			e.volumetric_fog_length = 200.0
			e.volumetric_fog_anisotropy = 0.55
			e.volumetric_fog_sky_affect = 0.03
		else:
			e.fog_enabled = false
			e.volumetric_fog_enabled = false
		if night:
			e.ambient_light_energy = 0.3
			e.ambient_light_color = Color(0.7, 0.78, 1.0)
	var sun: DirectionalLight3D = _find_first(root, "DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 420.0 if outdoor else 90.0
		sun.directional_shadow_split_1 = 0.06
		sun.directional_shadow_split_2 = 0.15
		sun.directional_shadow_split_3 = 0.35
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_fade_start = 0.85
		sun.light_angular_distance = 0.7
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 1.6
		sun.shadow_blur = 1.2
		if night:
			sun.light_energy = 0.22
			sun.light_color = Color(0.62, 0.72, 1.0)
			sun.light_indirect_energy = 0.6
		else:
			sun.light_indirect_energy = 1.3
			if sun.light_energy < 1.2:
				sun.light_energy = 1.3

# ---------------------------------------------------------------------------
# TIỆN ÍCH HUD CHUẨN GODOT 4 (anchors / containers, không offset cứng)
# ---------------------------------------------------------------------------
static func make_panel_style(border: Color = FPT_ORANGE, bg: Color = Color(0.06, 0.08, 0.14, 0.92), radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb

static func make_label(text: String, size: int = 16, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func make_bar(value: float = 100.0, color: Color = FPT_GREEN, height: int = 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b

static func set_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

## Tạo panel neo theo preset chuẩn (vd Control.PRESET_CENTER_BOTTOM) với margin.
static func anchored_panel(parent: Node, preset: int, min_size: Vector2, margin: int = 24, border: Color = FPT_ORANGE) -> PanelContainer:
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(preset as Control.LayoutPreset)
	# Hướng nở phải theo mép neo: panel neo mép phải nở sang trái, neo đáy nở lên... nếu để BOTH thì
	# một nửa panel nằm ngoài màn hình (lỗi "panel bị cắt" ở Sổ bằng chứng / dòng gợi ý đáy).
	match preset:
		Control.PRESET_TOP_LEFT, Control.PRESET_CENTER_LEFT, Control.PRESET_BOTTOM_LEFT, Control.PRESET_LEFT_WIDE:
			holder.grow_horizontal = Control.GROW_DIRECTION_END
		Control.PRESET_TOP_RIGHT, Control.PRESET_CENTER_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_RIGHT_WIDE:
			holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_:
			holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	match preset:
		Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT, Control.PRESET_CENTER_TOP, Control.PRESET_TOP_WIDE:
			holder.grow_vertical = Control.GROW_DIRECTION_END
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_WIDE:
			holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_:
			holder.grow_vertical = Control.GROW_DIRECTION_BOTH
	holder.add_theme_constant_override("margin_left", margin)
	holder.add_theme_constant_override("margin_right", margin)
	holder.add_theme_constant_override("margin_top", margin)
	holder.add_theme_constant_override("margin_bottom", margin)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", make_panel_style(border))
	holder.add_child(panel)
	return panel

## Tắt focus bàn phím của mọi Button dưới `root` để SPACE/ENTER không vô tình bấm nút đang focus
## (các màn dùng SPACE làm phím gameplay: nhịp tim, nhảy, drift, mash...).
static func disable_button_focus(root: Node) -> void:
	if root is Button:
		(root as Button).focus_mode = Control.FOCUS_NONE
	for c: Node in root.get_children():
		disable_button_focus(c)

static func rank_for(score: float, s_threshold: float, a_threshold: float, b_threshold: float) -> String:
	if score >= s_threshold:
		return "S"
	if score >= a_threshold:
		return "A"
	if score >= b_threshold:
		return "B"
	return "C"
