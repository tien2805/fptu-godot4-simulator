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

# ---------------------------------------------------------------------------
# CÀI ĐẶT (lưu user://settings.cfg): mức đồ hoạ 0 thấp / 1 trung bình / 2 cao, toàn màn hình,
# phong cách đồ hoạ "vice" (Vice City, mặc định – ViceStyle.gd) / "classic" (đường render SDFGI cũ), vệt sáng (trails)
# ---------------------------------------------------------------------------
const SETTINGS_PATH: String = "user://settings.cfg"
const ART_STYLES: Array[String] = ["vice", "classic"]
const ART_STYLE_NAMES: Dictionary = {"vice": "Vice City", "classic": "Cổ điển"}
const ART_STYLE_HINT: String = "Áp dụng ngay cho màn đang mở · Cổ điển áp dụng đầy đủ khi vào lại màn"
## Nút mức đồ hoạ (menu chính, menu tạm dừng): tên + mô tả theo phong cách. Vice City không dùng SDFGI / SSIL / SSAO /
## SSR / sương thể tích, mức chỉ đổi bóng nắng (2 / 4 lớp, tầm xa) và khử răng cưa (MSAA) nên không quảng cáo chúng.
const QUALITY_NAMES: Array[String] = ["THẤP", "TRUNG BÌNH", "CAO"]
const QUALITY_DESC: Dictionary = {
	"vice": ["bóng cơ bản", "bóng 4 lớp", "bóng xa + khử răng cưa"],
	"classic": ["không GI, bóng cơ bản", "SSAO + phản xạ, không SDFGI", "SDFGI + SSIL + sương thể tích"],
}
## Phát sau set_art_style() (kể cả khi chọn lại phong cách đang dùng): menu làm mới chú thích nút mức đồ hoạ.
signal art_style_changed(style: String)
var visual_quality: int = 2
var fullscreen: bool = false
## Phong cách đồ hoạ (video/art_style). Đổi qua set_art_style() để áp lại cảnh hiện tại.
var art_style: String = "vice"
## Vệt sáng kiểu PS2 lúc hoàng hôn / ban đêm (video/trails). Hiện chỉ lưu cờ; hiệu ứng ở Task VC-7.
var trails_enabled: bool = true
## Âm lượng tuyến tính 0..1 theo bus (lưu trong settings.cfg)
const AUDIO_BUSES: Array[String] = ["Master", "Music", "SFX", "UI"]
var volumes: Dictionary = {"Master": 1.0, "Music": 0.8, "SFX": 1.0, "UI": 0.9}
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_pool_idx: int = 0

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		visual_quality = clampi(int(cfg.get_value("video", "quality", 2)), 0, 2)
		fullscreen = bool(cfg.get_value("video", "fullscreen", false))
		var st: String = String(cfg.get_value("video", "art_style", "vice"))
		art_style = st if st in ART_STYLES else "vice"
		trails_enabled = bool(cfg.get_value("video", "trails", true))
		for b: String in AUDIO_BUSES:
			volumes[b] = clampf(float(cfg.get_value("audio", "vol_" + b.to_lower(), volumes[b])), 0.0, 1.0)
	_apply_global_quality()
	_apply_window_mode()
	_apply_volumes()
	_apply_art_style_statics()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", visual_quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "art_style", art_style)
	cfg.set_value("video", "trails", trails_enabled)
	for b: String in AUDIO_BUSES:
		cfg.set_value("audio", "vol_" + b.to_lower(), float(volumes[b]))
	cfg.save(SETTINGS_PATH)

# --- Bus âm thanh: Master (limiter) <- Music / SFX / UI. Tạo lúc chạy vì dự án không có bus layout riêng.
func _setup_audio_buses() -> void:
	for name: String in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")
	var master: int = AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim: AudioEffect = null
		if ClassDB.class_exists("AudioEffectHardLimiter"):
			lim = ClassDB.instantiate("AudioEffectHardLimiter")
		else:
			lim = AudioEffectLimiter.new()
		AudioServer.add_bus_effect(master, lim)

func _apply_volumes() -> void:
	for b: String in AUDIO_BUSES:
		var idx: int = AudioServer.get_bus_index(b)
		if idx == -1:
			continue
		var v: float = clampf(float(volumes.get(b, 1.0)), 0.0, 1.0)
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))

func set_volume(bus_name: String, linear: float) -> void:
	volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func get_volume(bus_name: String) -> float:
	return float(volumes.get(bus_name, 1.0))

## Chuyển mọi AudioStreamPlayer/3D dưới `node` sang bus (xe máy Màn 1 có player riêng)
static func route_audio_to_bus(node: Node, bus_name: String) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		node.set("bus", bus_name)
	for c: Node in node.get_children():
		route_audio_to_bus(c, bus_name)

## SFX giao diện (menu, tạm dừng, cửa hàng) đi bus UI
func play_ui(name_or_path: String, volume_db: float = -8.0, pitch: float = 1.0) -> void:
	if _ui_pool.is_empty():
		for i: int in range(4):
			var p := AudioStreamPlayer.new()
			p.bus = "UI"
			add_child(p)
			_ui_pool.append(p)
	var stream: AudioStream = null
	if not _sfx_bank.has(name_or_path):
		_sfx_bank[name_or_path] = load_wav(name_or_path) if name_or_path.begins_with("res://") else _synth(name_or_path)
	stream = _sfx_bank[name_or_path]
	if not stream:
		return
	var p: AudioStreamPlayer = _ui_pool[_ui_pool_idx]
	_ui_pool_idx = (_ui_pool_idx + 1) % _ui_pool.size()
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## Hàng thanh trượt âm lượng cho bảng cài đặt (menu chính & tạm dừng)
func build_audio_settings(parent: Control) -> void:
	var names: Dictionary = {"Master": "🔊 Tổng", "Music": "🎵 Nhạc", "SFX": "💥 Hiệu ứng", "UI": "🖱 Giao diện"}
	for b: String in AUDIO_BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)
		var lbl: Label = make_label(String(names[b]), 15, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.custom_minimum_size = Vector2(130, 0)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = get_volume(b)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(260, 24)
		slider.focus_mode = Control.FOCUS_ALL
		row.add_child(slider)
		var pct: Label = make_label("%d%%" % int(round(get_volume(b) * 100.0)), 14, FPT_YELLOW, HORIZONTAL_ALIGNMENT_RIGHT)
		pct.autowrap_mode = TextServer.AUTOWRAP_OFF
		pct.custom_minimum_size = Vector2(52, 0)
		row.add_child(pct)
		slider.value_changed.connect(func(v: float) -> void:
			set_volume(b, v)
			pct.text = "%d%%" % int(round(v * 100.0))
			play_ui("tick", -12.0, 1.0 + v * 0.5))

## Hàng "Phong cách đồ hoạ" (OptionButton Vice City / Cổ điển) + "Vệt sáng (trails)" (CheckButton) + dòng gợi ý cho
## bảng cài đặt (menu chính & tạm dừng). Node tên ArtStyleOption / TrailsCheck để sync_style_settings() tìm lại.
func build_style_settings(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "ArtStyleRow"
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var lbl: Label = make_label("🎨 Phong cách đồ hoạ", 15, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.custom_minimum_size = Vector2(130, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.name = "ArtStyleOption"
	for i: int in range(ART_STYLES.size()):
		opt.add_item(String(ART_STYLE_NAMES[ART_STYLES[i]]), i)
		opt.set_item_metadata(i, ART_STYLES[i])
	opt.custom_minimum_size = Vector2(150, 30)
	opt.add_theme_font_size_override("font_size", 15)
	opt.focus_mode = Control.FOCUS_ALL
	row.add_child(opt)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var trails := CheckButton.new()
	trails.name = "TrailsCheck"
	trails.text = "Vệt sáng (trails)"
	trails.add_theme_font_size_override("font_size", 15)
	row.add_child(trails)
	var hint: Label = make_label(ART_STYLE_HINT, 12, Color("#95A5A6"), HORIZONTAL_ALIGNMENT_LEFT)
	hint.name = "ArtStyleHint"
	parent.add_child(hint)
	sync_style_settings(row)
	opt.item_selected.connect(func(idx: int) -> void:
		set_art_style(String(opt.get_item_metadata(idx)))
		play_ui("pop", -6.0))
	trails.toggled.connect(func(on: bool) -> void:
		set_trails(on)
		play_ui("tick", -10.0, 1.3))

## Đồng bộ các hàng do build_style_settings() dựng (dưới `root`) với cài đặt hiện tại, không phát tín hiệu.
func sync_style_settings(root: Node) -> void:
	if root == null:
		return
	var opt: OptionButton = root.find_child("ArtStyleOption", true, false) as OptionButton
	if opt:
		opt.select(maxi(0, ART_STYLES.find(art_style)))
	var trails: CheckButton = root.find_child("TrailsCheck", true, false) as CheckButton
	if trails:
		trails.set_pressed_no_signal(trails_enabled)

## Đổi phong cách đồ hoạ: lưu cài đặt (persist), đặt kiểu nhân vật dựng sau này (CharacterBuilder.toon, tỉ lệ đầu), quên
## cache vật liệu dùng chung (cả hai chiều: cache còn giữ vật liệu của phong cách cũ) rồi áp lại preset ánh sáng của cảnh
## hiện tại (meta "visual_preset") mà không nạp lại cảnh. Sang "classic": trả Environment gốc + lớp đêm cũ, đường cổ điển
## của upgrade_scene_visuals() trả vật liệu đã chuyển kiểu về gốc (ViceStyle.unstylize_materials).
func set_art_style(style: String, persist: bool = true) -> void:
	var s: String = style if style in ART_STYLES else "vice"
	var changed: bool = s != art_style
	art_style = s
	_apply_art_style_statics()
	if persist:
		save_settings()
	if changed:
		ViceStyle.forget_cached_materials()
	var tree: SceneTree = get_tree()
	var cs: Node = tree.current_scene if tree else null
	if cs and cs.has_meta("visual_preset"):
		if s == "classic":
			ViceStyle.restore_classic(cs)
		upgrade_scene_visuals(cs, String(cs.get_meta("visual_preset")))
	art_style_changed.emit(s)

## Chú thích nút mức đồ hoạ q theo phong cách (mặc định phong cách hiện tại): [tên, mô tả].
func quality_caption(q: int, style: String = "") -> PackedStringArray:
	var st: String = style if style in ART_STYLES else art_style
	var qi: int = clampi(q, 0, QUALITY_NAMES.size() - 1)
	var desc: Array = QUALITY_DESC.get(st, QUALITY_DESC["vice"])
	return PackedStringArray([QUALITY_NAMES[qi], String(desc[qi])])

## Vệt sáng: hiện chỉ lưu cờ (hiệu ứng ở Task VC-7); ở phong cách vice áp lại cảnh để meta "vice_trails" đúng ngay.
func set_trails(on: bool, persist: bool = true) -> void:
	trails_enabled = on
	if persist:
		save_settings()
	var tree: SceneTree = get_tree()
	var cs: Node = tree.current_scene if tree else null
	if art_style == "vice" and cs and cs.has_meta("visual_preset"):
		upgrade_scene_visuals(cs, String(cs.get_meta("visual_preset")))

## Kiểu nhân vật theo phong cách: cổ điển = toon + viền, đầu 1.3; Vice City = không viền, đầu 1.15 (plan D3).
func _apply_art_style_statics() -> void:
	var classic: bool = art_style == "classic"
	CharacterBuilder.toon = classic
	CharacterBuilder.head_scale_default = 1.3 if classic else 1.15

func set_visual_quality(q: int) -> void:
	visual_quality = clampi(q, 0, 2)
	_apply_global_quality()
	save_settings()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window_mode()
	save_settings()

func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

## Các thiết lập toàn cục (MSAA, FXAA, kích thước shadow map) theo mức chất lượng
func _apply_global_quality() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	match visual_quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(8192, true)

## Nạp ảnh từ res:// an toàn cho cả editor lẫn bản EXPORT (đọc byte thô qua FileAccess rồi giải mã,
## vì ProjectSettings.globalize_path("res://...") không dùng được khi tài nguyên nằm trong PCK).
static func load_image_any(res_path: String) -> Image:
	if not FileAccess.file_exists(res_path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	var err: int = ERR_FILE_UNRECOGNIZED
	match res_path.get_extension().to_lower():
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
		"bmp":
			err = img.load_bmp_from_buffer(bytes)
		_:
			err = img.load_png_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	return img

static func _quality() -> int:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml and ml.root:
		var g: Node = ml.root.get_node_or_null("GameFX")
		if g:
			return int(g.get("visual_quality"))
	return 2

## Phong cách đồ hoạ từ autoload /root/GameFX, giống _quality() (không có node /root/GameFX -> "vice").
static func _art_style() -> String:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml and ml.root:
		var g: Node = ml.root.get_node_or_null("GameFX")
		if g:
			return String(g.get("art_style"))
	return "vice"

static func _trails() -> bool:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml and ml.root:
		var g: Node = ml.root.get_node_or_null("GameFX")
		if g:
			return bool(g.get("trails_enabled"))
	return true

var music: MusicDirector

## Nhạc nền thủ tục theo màn: style thuộc MusicDirector.STYLES (menu, ride, parking, classroom, vovinam, canteen, capstone, exam)
func music_play(style: String, tension: float = 0.35) -> void:
	if music:
		music.play(style)
		music.set_tension(tension)

func music_tension(v: float) -> void:
	if music:
		music.set_tension(v)

func music_stop(fade: bool = true) -> void:
	if music:
		music.stop(fade)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	load_settings()
	music = MusicDirector.new()
	music.name = "Music"
	add_child(music)

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
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	# Khi đổi scene, dọn hiệu ứng còn sót lại
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	# Scene gốc mới được add -> reset trạng thái FX
	if node.get_parent() == get_tree().root and node != self:
		reset_all()
		# phong cách vice: chuyển panel / nút / nhãn khai báo trong .tscn sang giao diện vice sau khi cảnh _ready xong
		if art_style == "vice":
			_vice_theme_deferred.call_deferred(node)

func _vice_theme_deferred(node: Node) -> void:
	if is_instance_valid(node) and node.is_inside_tree():
		apply_vice_theme(node)

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
	if is_vice_ui():
		# vice: chữ nghiêng đậm, viền tím than + bóng đổ (giống chữ HUD thập niên 80)
		lbl.add_theme_font_override("font", vice_font(0.7, 0.2))
		lbl.add_theme_color_override("font_outline_color", VICE_INK)
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
		lbl.add_theme_constant_override("shadow_offset_x", 3)
		lbl.add_theme_constant_override("shadow_offset_y", 3)
	else:
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
## Preset ánh sáng theo GIỜ TRONG NGÀY của từng màn (độ cao/hướng nắng, màu nắng, màu trời, sương, tonemap).
## Tên cũ "outdoor"/"indoor"/"night" vẫn dùng được (alias).
const TOD_PRESETS: Dictionary = {
	"dawn":           {"outdoor": true,  "elev": 18.0, "azim": 118.0, "sun": Color(1.0, 0.82, 0.6), "energy": 2.0, "top": Color(0.36, 0.55, 0.9), "horizon": Color(0.99, 0.82, 0.64), "exposure": 1.08, "contrast": 1.08, "saturation": 1.06, "fog_tint": Color(0.98, 0.86, 0.72), "shafts": false, "haze": false, "ambient": 1.45},
	"morning":        {"outdoor": true,  "elev": 22.0, "azim": 112.0, "sun": Color(1.0, 0.9, 0.76), "energy": 1.5,  "top": Color(0.3, 0.58, 0.95),  "horizon": Color(0.9, 0.9, 0.9),   "exposure": 1.0, "contrast": 1.07, "saturation": 1.02, "fog_tint": Color(0.92, 0.93, 0.97), "shafts": false, "haze": false},
	"morning_indoor": {"outdoor": false, "elev": 24.0, "azim": 120.0, "sun": Color(0.96, 0.98, 1.0), "energy": 1.7,  "top": Color(0.3, 0.6, 0.97),   "horizon": Color(0.85, 0.9, 0.97), "exposure": 1.08, "contrast": 1.06, "saturation": 0.98, "fog_tint": Color(0.95, 0.97, 1.0), "shafts": true,  "haze": false},
	"noon":           {"outdoor": true,  "elev": 58.0, "azim": 150.0, "sun": Color(1.0, 0.98, 0.95), "energy": 1.75, "top": Color(0.22, 0.5, 0.95),  "horizon": Color(0.82, 0.88, 0.96), "exposure": 0.98, "contrast": 1.1,  "saturation": 1.05, "fog_tint": Color(0.9, 0.93, 0.98), "shafts": false, "haze": false},
	"midday_open":    {"outdoor": false, "elev": 70.0, "azim": 175.0, "sun": Color(1.0, 0.99, 0.96), "energy": 1.85, "top": Color(0.25, 0.52, 0.96), "horizon": Color(0.86, 0.9, 0.95),  "exposure": 1.05, "contrast": 1.06, "saturation": 1.03, "fog_tint": Color(0.95, 0.95, 0.93), "shafts": false, "haze": true},
	"exam":           {"outdoor": false, "elev": 30.0, "azim": 125.0, "sun": Color(0.97, 0.98, 1.0), "energy": 1.35, "top": Color(0.32, 0.58, 0.95), "horizon": Color(0.85, 0.9, 0.96),  "exposure": 1.08, "contrast": 1.04, "saturation": 0.97, "fog_tint": Color(0.95, 0.97, 1.0), "shafts": false, "haze": false},
	"night":          {"outdoor": false, "elev": 40.0, "azim": 200.0, "sun": Color(0.62, 0.72, 1.0), "energy": 0.22, "top": Color(0.015, 0.025, 0.07), "horizon": Color(0.09, 0.11, 0.2), "exposure": 1.0, "contrast": 1.07, "saturation": 1.0, "fog_tint": Color(0.1, 0.12, 0.2), "shafts": false, "haze": false}
}
const TOD_ALIASES: Dictionary = {"outdoor": "morning", "indoor": "exam"}

static func _ensure_sky(e: Environment, night: bool, top: Color = Color(0.3, 0.6, 0.97), horizon: Color = Color(0.8, 0.88, 0.97)) -> void:
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
		sm.sky_top_color = top
		sm.sky_horizon_color = horizon
		sm.sky_energy_multiplier = 1.0
		# Bán cầu dưới của sky màu trung tính: tránh ám xanh lá lên mặt dưới mái che / trần hiên
		sm.ground_bottom_color = Color(0.27, 0.26, 0.24)
		sm.ground_horizon_color = Color(0.72, 0.72, 0.7)

## Gọi ở cuối _ready của mỗi màn: preset "outdoor" (đường, campus, sân võ), "indoor" (phòng học, căn tin...)
## hoặc "night" (phòng lab 23:59 – trời đêm, trăng xanh, đèn trần & màn hình là nguồn sáng chính).
## Phong cách "vice" (mặc định): ViceStyle.apply() (bảng map preset -> look trong ViceStyle.PRESET_LOOK); phần còn lại
## của hàm là đường render "classic" giữ nguyên.
static func upgrade_scene_visuals(root: Node, preset: String = "outdoor") -> void:
	if root == null:
		return
	if _art_style() == "vice":
		ViceStyle.apply(root, preset, _quality(), _trails())
		return
	# vật liệu đã chuyển kiểu vice trong phiên này (sub-resource .tscn dùng lại khi nạp lại cùng cảnh, vật liệu đang hiển
	# thị khi đổi phong cách lúc chạy) -> trả về gốc; phiên chỉ chơi cổ điển thì không làm gì
	ViceStyle.unstylize_materials(root)
	var key: String = String(TOD_ALIASES.get(preset, preset))
	if not TOD_PRESETS.has(key):
		key = "morning"
	var tod: Dictionary = TOD_PRESETS[key]
	root.set_meta("visual_preset", key)
	var outdoor: bool = bool(tod["outdoor"])
	var night: bool = key == "night"
	var q: int = _quality() # 0 thấp / 1 trung bình / 2 cao (menu Cài đặt đồ hoạ)
	var env_node: WorldEnvironment = _find_first(root, "WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var e: Environment = env_node.environment.duplicate(true)
		env_node.environment = e
		_ensure_sky(e, night, tod["top"], tod["horizon"])
		e.ssao_enabled = q >= 1
		e.ssao_radius = 1.8
		e.ssao_intensity = 2.2
		e.ssao_power = 1.6
		e.ssil_enabled = q >= 2
		e.ssil_radius = 4.0
		e.ssil_intensity = 1.0
		e.sdfgi_enabled = q >= 2
		e.sdfgi_use_occlusion = true
		e.sdfgi_bounce_feedback = 0.35
		e.sdfgi_cascades = 6 if outdoor else 4
		e.sdfgi_min_cell_size = 0.3 if outdoor else 0.12
		e.sdfgi_energy = 1.0
		e.ssr_enabled = q >= 1
		e.ssr_max_steps = 96
		e.ssr_fade_in = 0.2
		e.ssr_fade_out = 2.0
		e.glow_enabled = true
		e.glow_intensity = 0.9 if night else 0.55
		e.glow_bloom = 0.22 if night else 0.1
		e.glow_hdr_threshold = 1.05
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		e.tonemap_mode = Environment.TONE_MAPPER_ACES
		e.tonemap_exposure = float(tod["exposure"])
		e.tonemap_white = 4.0
		e.adjustment_enabled = true
		e.adjustment_brightness = 1.02
		e.adjustment_contrast = float(tod["contrast"])
		e.adjustment_saturation = float(tod["saturation"])
		if outdoor:
			e.fog_enabled = true
			e.fog_light_color = tod["fog_tint"]
			e.fog_density = 0.00016 if key != "dawn" else 0.00026
			e.fog_sun_scatter = 0.06 if key != "dawn" else 0.16
			e.fog_aerial_perspective = 0.2
			e.fog_sky_affect = 0.04
			e.volumetric_fog_enabled = q >= 2
			e.volumetric_fog_density = 0.0014 if key != "dawn" else 0.0022
			e.volumetric_fog_albedo = tod["fog_tint"]
			e.volumetric_fog_length = 200.0
			e.volumetric_fog_anisotropy = 0.55 if key != "dawn" else 0.7
			e.volumetric_fog_sky_affect = 0.03
		elif bool(tod["shafts"]) and q >= 2:
			# Tia nắng xuyên cửa sổ phòng học 07:30 (sương thể tích mỏng trong nhà)
			e.fog_enabled = false
			e.volumetric_fog_enabled = true
			e.volumetric_fog_density = 0.012
			e.volumetric_fog_albedo = Color(1.0, 0.98, 0.94)
			e.volumetric_fog_length = 40.0
			e.volumetric_fog_anisotropy = 0.75
			e.volumetric_fog_ambient_inject = 0.0
			e.volumetric_fog_sky_affect = 0.0
		elif bool(tod["haze"]):
			# Nắng trưa 11:30 ở căn tin hở: sương nhiệt nhẹ phía xa
			e.fog_enabled = true
			e.fog_light_color = tod["fog_tint"]
			e.fog_density = 0.0009
			e.fog_sun_scatter = 0.1
			e.fog_aerial_perspective = 0.3
			e.volumetric_fog_enabled = false
		else:
			e.fog_enabled = false
			e.volumetric_fog_enabled = false
		if tod.has("ambient"):
			e.ambient_light_energy = float(tod["ambient"]) # trời sớm: bầu trời tối hơn nên bù ánh sáng môi trường
		if night:
			e.ambient_light_energy = 0.3 if q >= 2 else 0.5
			e.ambient_light_color = Color(0.7, 0.78, 1.0)
		elif not outdoor and q < 2:
			e.ambient_light_energy = maxf(e.ambient_light_energy, 1.2) # không có SDFGI thì bù ánh sáng môi trường trong nhà
	var sun: DirectionalLight3D = _find_first(root, "DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = ([150.0, 260.0, 420.0][q]) if outdoor else 90.0
		sun.directional_shadow_split_1 = 0.06
		sun.directional_shadow_split_2 = 0.15
		sun.directional_shadow_split_3 = 0.35
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_fade_start = 0.85
		sun.light_angular_distance = 0.7
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 1.6
		sun.shadow_blur = 1.2
		sun.rotation_degrees = Vector3(-float(tod["elev"]), float(tod["azim"]), 0.0)
		sun.light_color = tod["sun"]
		sun.light_energy = float(tod["energy"])
		sun.light_indirect_energy = 0.6 if night else 1.3
		if key == "dawn":
			sun.directional_shadow_max_distance = [220.0, 360.0, 520.0][q] # bóng dài buổi sớm
			sun.light_angular_distance = 1.2

# ---------------------------------------------------------------------------
# TIỆN ÍCH HUD CHUẨN GODOT 4 (anchors / containers, không offset cứng)
# Phong cách giao diện theo art_style (đọc lúc dựng qua _art_style(), tức /root/GameFX hoặc "vice" khi không có autoload):
#   classic = đúng như trước (viền cam FPT, nền xanh đen, bo 8, chữ không viền);
#   vice    = nền tím Color(0.07, 0.04, 0.14, 0.88), viền hồng #FF5FB0 khi không truyền màu, cam FPT giữ nguyên khi được
#             truyền tường minh (chỉ dùng cho thứ mang thương hiệu FPT), màu ngữ nghĩa khác -> bản pastel cùng sắc
#             (vice_tint), bo 4, chữ viền 6 #1B0F33 + bóng đổ, tiêu đề >= 24 px nghiêng giả lập (vice_font()).
# Mặc định của tham số màu là UI_DEFAULT (trong suốt, không ai dùng làm viền thật) để phân biệt "không truyền" với
# "truyền FPT_ORANGE". Kiểu tạo ra được đánh dấu meta ("ui_panel" / "ui_label" / "ui_bar") để restyle_tree() dựng lại
# khi đổi phong cách lúc đang mở (menu tạm dừng); HUD của màn đổi kiểu khi nạp lại màn.
# apply_vice_theme(): khi nạp một cảnh ở phong cách vice, panel / nút / thanh / nhãn khai báo trong .tscn (không qua các
# helper) được chuyển sang giao diện vice (GameFX tự gọi trì hoãn cho mỗi cảnh gốc mới, _on_node_added). Control có meta
# "ui_keep" (cả nhánh) được bỏ qua; meta "fpt_brand" giữ viền cam FPT.
# ---------------------------------------------------------------------------
const UI_DEFAULT := Color(0.0, 0.0, 0.0, 0.0)
const VICE_PINK := Color("#FF5FB0")
const VICE_CYAN := Color("#3FF2FF")
const VICE_INK := Color("#1B0F33")
const VICE_PANEL_BG := Color(0.07, 0.04, 0.14, 0.88)
const VICE_PANEL_BG_HI := Color(0.2, 0.09, 0.3)
const VICE_BAR_BG := Color(0.1, 0.05, 0.18, 0.9)
const CLASSIC_PANEL_BG := Color(0.06, 0.08, 0.14, 0.92)
const VICE_HEADING_SIZE: int = 24
## Bảng màu vice theo dải sắc độ (độ): màu ngữ nghĩa giữ nghĩa (xanh lá = tốt, đỏ = nguy, vàng = chú ý) nhưng sang pastel neon.
const VICE_HUE_BANDS: Array = [
	[12.0, Color("#FF5F7E")],    # đỏ
	[33.0, Color("#FF5FB0")],    # cam -> hồng chủ đạo (cam FPT tường minh được giữ trước khi tra bảng)
	[70.0, Color("#FFD166")],    # vàng / cam vàng
	[165.0, Color("#7CFFB2")],   # xanh lá
	[200.0, Color("#3FF2FF")],   # ngọc / cyan
	[245.0, Color("#6FB8FF")],   # xanh dương
	[290.0, Color("#B79CFF")],   # tím
	[335.0, Color("#FF5FB0")],   # hồng / magenta
	[361.0, Color("#FF5F7E")],   # đỏ
]
const VICE_GREY := Color("#B8A9D9")
var _vice_fonts: Dictionary = {}

static func is_vice_ui() -> bool:
	return _art_style() == "vice"

## Màu nhấn của giao diện cho chữ / viền không mang thương hiệu FPT: classic cam FPT, vice hồng.
static func ui_accent() -> Color:
	return VICE_PINK if is_vice_ui() else FPT_ORANGE

## Font nghiêng giả lập kiểu thập niên 80 từ font mặc định của Godot (không dùng font của Rockstar): FontVariation
## với variation_transform nghiêng `slant` và variation_embolden. Dùng chung theo tham số trong cache của node
## /root/GameFX (biến thành viên, giải phóng cùng autoload; cache tĩnh làm rò RID font lúc thoát); không có autoload
## (test --script) thì tạo mới.
static func vice_font(embolden: float = 0.6, slant: float = 0.22) -> FontVariation:
	var key: String = "%.3f/%.3f" % [embolden, slant]
	var cache: Variant = null
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	var g: Node = ml.root.get_node_or_null("GameFX") if ml and ml.root else null
	if g:
		cache = g.get("_vice_fonts")
	if cache is Dictionary and (cache as Dictionary).has(key):
		return (cache as Dictionary)[key]
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = embolden
	fv.variation_transform = Transform2D(Vector2(1.0, slant), Vector2(0.0, 1.0), Vector2.ZERO)
	if cache is Dictionary:
		(cache as Dictionary)[key] = fv
	return fv

## Màu `c` trong bảng vice (giữ alpha). keep_fpt: cam FPT giữ nguyên (helper: màu truyền tường minh); panel .tscn
## không mang thương hiệu thì cam -> hồng.
static func vice_tint(c: Color, keep_fpt: bool = true) -> Color:
	if keep_fpt and _same_rgb(c, FPT_ORANGE):
		return c
	var out: Color = VICE_GREY
	if c.s >= 0.2 and c.v >= 0.15:
		var h: float = c.h * 360.0
		for band: Array in VICE_HUE_BANDS:
			if h < float(band[0]):
				out = band[1]
				break
	return Color(out.r, out.g, out.b, c.a)

## Cùng màu RGB (bỏ qua alpha) gần như tuyệt đối: chỉ FPT_ORANGE / Color("#F37021") được coi là cam FPT; cam xấp xỉ
## Color(0.95, 0.44, 0.13) của các panel cũ không mang thương hiệu nên sang hồng ở vice.
static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 and absf(a.b - b.b) < 0.001

## Nền panel vice: nền mặc định -> VICE_PANEL_BG; nền tường minh -> tím, sáng hơn theo độ sáng của màu gốc (giữ khác
## biệt hover / pressed), giữ alpha.
static func _vice_bg(bg: Color) -> Color:
	if bg == UI_DEFAULT:
		return VICE_PANEL_BG
	var lum: float = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	var c: Color = Color(VICE_PANEL_BG.r, VICE_PANEL_BG.g, VICE_PANEL_BG.b).lerp(VICE_PANEL_BG_HI, clampf((lum - 0.075) / 0.12, 0.0, 1.0))
	return Color(c.r, c.g, c.b, bg.a)

static func make_panel_style(border: Color = UI_DEFAULT, bg: Color = UI_DEFAULT, radius: int = -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if is_vice_ui():
		sb.bg_color = _vice_bg(bg)
		sb.border_color = VICE_PINK if border == UI_DEFAULT else vice_tint(border)
		sb.set_corner_radius_all(4)
	else:
		sb.bg_color = CLASSIC_PANEL_BG if bg == UI_DEFAULT else bg
		sb.border_color = FPT_ORANGE if border == UI_DEFAULT else border
		sb.set_corner_radius_all(8 if radius < 0 else radius)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.set_meta("ui_panel", [border, bg, radius])
	return sb

static func make_label(text: String, size: int = 16, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_meta("ui_label", size)
	style_label(l, size)
	return l

## Kiểu chữ theo phong cách cho một Label có sẵn (helper, .tscn): vice = viền #1B0F33 (6 px, 4 px khi chữ < 14 px) +
## bóng đổ 2 px, chữ >= 24 px dùng vice_font(); classic = gỡ các override đó. Viền / bóng vẽ ngoài glyph nhưng trong
## lề của panel (content margin >= 8 px), không đổi kích thước Label.
static func style_label(l: Label, size: int = -1) -> void:
	var sz: int = size if size > 0 else l.get_theme_font_size("font_size")
	if is_vice_ui():
		l.add_theme_color_override("font_outline_color", VICE_INK)
		l.add_theme_constant_override("outline_size", 6 if sz >= 14 else 4)
		l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		if sz >= VICE_HEADING_SIZE:
			l.add_theme_font_override("font", vice_font())
	else:
		l.remove_theme_color_override("font_outline_color")
		l.remove_theme_constant_override("outline_size")
		l.remove_theme_color_override("font_shadow_color")
		l.remove_theme_constant_override("shadow_offset_x")
		l.remove_theme_constant_override("shadow_offset_y")
		l.remove_theme_font_override("font")

static func make_bar(value: float = 100.0, color: Color = FPT_GREEN, height: int = 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	style_bar(b, color)
	return b

## Kiểu thanh tiến độ theo phong cách: classic bo 4, nền xanh đen; vice màu pastel (vice_tint), nền tím, bo 2.
static func style_bar(bar: ProgressBar, color: Color) -> void:
	var vice: bool = is_vice_ui()
	var bg := StyleBoxFlat.new()
	bg.bg_color = VICE_BAR_BG if vice else Color(0.1, 0.12, 0.18, 0.9)
	bg.set_corner_radius_all(2 if vice else 4)
	bar.add_theme_stylebox_override("background", bg)
	set_bar_color(bar, color)

static func set_bar_color(bar: ProgressBar, color: Color) -> void:
	var vice: bool = is_vice_ui()
	var fill := StyleBoxFlat.new()
	fill.bg_color = vice_tint(color) if vice else color
	fill.set_corner_radius_all(2 if vice else 4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.set_meta("ui_bar", color)

## Dải gradient pastel (hồng -> đào -> cyan) cho thẻ kết quả / thẻ chuyển cảnh vice.
static func pastel_strip(height: float = 6.0) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([VICE_PINK, Color("#FFB08A"), VICE_CYAN])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	var tr := TextureRect.new()
	tr.name = "PastelStrip"
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = Vector2(0.0, height)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## Dựng lại theo phong cách hiện tại mọi kiểu do các helper tạo dưới `n` (panel "ui_panel", nhãn "ui_label", thanh
## "ui_bar"); node có meta "vice_only" chỉ hiện ở vice. Dùng khi đổi phong cách lúc giao diện đang mở.
static func restyle_tree(n: Node) -> void:
	if n is Control:
		var c: Control = n
		for nm: String in ["panel", "normal", "hover", "focus", "pressed", "disabled"]:
			if c.has_theme_stylebox_override(nm):
				var sb: StyleBox = c.get_theme_stylebox(nm)
				if sb and sb.has_meta("ui_panel"):
					var a: Array = sb.get_meta("ui_panel")
					c.add_theme_stylebox_override(nm, make_panel_style(a[0], a[1], a[2]))
		if c is Label and c.has_meta("ui_label"):
			style_label(c as Label, int(c.get_meta("ui_label")))
		if c is ProgressBar and c.has_meta("ui_bar"):
			style_bar(c as ProgressBar, c.get_meta("ui_bar"))
		if c.has_meta("vice_only"):
			c.visible = is_vice_ui()
	for ch: Node in n.get_children():
		restyle_tree(ch)

## Giao diện vice cho phần HUD khai báo trong .tscn (không qua helper): StyleBoxFlat của panel / nút -> nền tím, viền
## bảng vice (cam -> hồng, trừ meta "fpt_brand"), bo 4; Button / ProgressBar dùng theme mặc định -> kiểu vice (giữ lề
## nội dung của theme mặc định nên kích thước không đổi); Label chưa có viền -> style_label(). Chỉ Control nằm dưới
## CanvasLayer, bỏ qua SubViewport (màn chiếu, màn hình 3D) và nhánh có meta "ui_keep". Không làm gì ở classic.
static func apply_vice_theme(n: Node, in_canvas: bool = false) -> void:
	if n == null or not is_vice_ui() or n is SubViewport or n.has_meta("ui_keep"):
		return
	var canvas: bool = in_canvas or n is CanvasLayer
	if canvas and n is Control:
		_vice_theme_control(n as Control)
	for ch: Node in n.get_children():
		apply_vice_theme(ch, canvas)

static func _vice_theme_control(c: Control) -> void:
	var keep_fpt: bool = c.has_meta("fpt_brand")
	var names: Array[String] = ["panel", "normal", "hover", "focus", "pressed", "disabled"]
	for nm: String in names:
		if c.has_theme_stylebox_override(nm):
			var sb: StyleBox = c.get_theme_stylebox(nm)
			if sb is StyleBoxFlat and not sb.has_meta("ui_panel") and not sb.has_meta("vice_themed"):
				c.add_theme_stylebox_override(nm, _vice_flat(sb as StyleBoxFlat, keep_fpt))
	if c.get_class() == "Button" and not c.has_theme_stylebox_override("normal"):
		_vice_button(c as Button)
	elif c is ProgressBar and not c.has_theme_stylebox_override("fill"):
		style_bar(c as ProgressBar, VICE_CYAN)
	elif c is Label and not c.has_meta("ui_label") and not c.has_theme_constant_override("outline_size"):
		style_label(c as Label)

static func _vice_flat(src: StyleBoxFlat, keep_fpt: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = src.duplicate() as StyleBoxFlat
	var lum: float = 0.299 * src.bg_color.r + 0.587 * src.bg_color.g + 0.114 * src.bg_color.b
	var c: Color = Color(VICE_PANEL_BG.r, VICE_PANEL_BG.g, VICE_PANEL_BG.b).lerp(VICE_PANEL_BG_HI, clampf((lum - 0.075) / 0.12, 0.0, 1.0))
	sb.bg_color = Color(c.r, c.g, c.b, src.bg_color.a)
	# panel mang thương hiệu FPT (meta "fpt_brand", vd. cổng điểm danh FAP): giữ nguyên viền cam của .tscn
	sb.border_color = src.border_color if keep_fpt else vice_tint(src.border_color, false)
	sb.set_corner_radius_all(mini(4, src.corner_radius_top_left))
	sb.set_meta("vice_themed", true)
	return sb

## Nút theme mặc định -> kiểu vice (nền tím, viền hồng mờ; hover / focus viền hồng; pressed viền cyan), lề nội dung lấy
## từ theme mặc định để kích thước nút không đổi.
static func _vice_button(b: Button) -> void:
	var dt: Theme = ThemeDB.get_default_theme()
	var ref: StyleBox = dt.get_stylebox("normal", "Button") if dt else null
	var states: Dictionary = {
		"normal": [Color(VICE_PINK, 0.55), Color(VICE_PANEL_BG, 0.92)],
		"hover": [VICE_PINK, Color(0.14, 0.07, 0.24, 0.96)],
		"focus": [VICE_PINK, Color(0.14, 0.07, 0.24, 0.0)],
		"pressed": [VICE_CYAN, Color(0.18, 0.08, 0.28, 0.98)],
		"disabled": [Color(VICE_GREY, 0.35), Color(VICE_PANEL_BG, 0.6)],
	}
	for nm: String in states.keys():
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[nm][1]
		sb.border_color = states[nm][0]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		if ref:
			sb.content_margin_left = ref.get_content_margin(SIDE_LEFT)
			sb.content_margin_right = ref.get_content_margin(SIDE_RIGHT)
			sb.content_margin_top = ref.get_content_margin(SIDE_TOP)
			sb.content_margin_bottom = ref.get_content_margin(SIDE_BOTTOM)
		sb.set_meta("vice_themed", true)
		b.add_theme_stylebox_override(nm, sb)

## Tạo panel neo theo preset chuẩn (vd Control.PRESET_CENTER_BOTTOM) với margin.
static func anchored_panel(parent: Node, preset: int, min_size: Vector2, margin: int = 24, border: Color = UI_DEFAULT) -> PanelContainer:
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
