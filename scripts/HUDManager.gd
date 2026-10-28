# File: res://scripts/HUDManager.gd
# HUD Màn 1: đồng hồ 07:05 -> 07:30, tốc độ, núp gió, banner sự kiện, thưởng/phạt giây,
# speed lines khi phóng nhanh, overlay mưa, màn hình ABSENT / PRESENT.
class_name HUDManager
extends CanvasLayer

@export var stage_duration_sec: float = 300.0 # giây thực = 25 phút trong game (7:05 -> 7:30 AM) trên tuyến thật 5,5 km; _ready lấy RoadManager.STAGE_TIME (xem lý do con số ở đó)
@export var player_bike: CharacterBody3D
@export var road_manager: Node3D

@onready var clock_label: Label = $TopBar/ClockPanel/ClockLabel
@onready var zone_label: Label = $TopBar/ZonePanel/ZoneLabel
@onready var speed_label: Label = $BottomRight/SpeedContainer/SpeedPanel/SpeedLabel
@onready var slipstream_bar: ProgressBar = $BottomRight/SpeedContainer/SpeedPanel/SlipstreamBar
@onready var slipstream_status: Label = $BottomRight/SpeedContainer/SpeedPanel/SlipstreamStatus
@onready var damage_flash: ColorRect = get_node_or_null("DamageFlash")
@onready var absent_overlay: ColorRect = $AbsentOverlay
@onready var absent_title: Label = $AbsentOverlay/CenterContainer/VBoxContainer/AbsentTitle
@onready var retry_button: Button = $AbsentOverlay/CenterContainer/VBoxContainer/RetryButton
@onready var next_stage_btn: Button = $AbsentOverlay/CenterContainer/VBoxContainer/NextStageButton
@onready var campaign_hub_btn: Button = $AbsentOverlay/CenterContainer/VBoxContainer/CampaignHubButton
@onready var stage_select_btn: Button = $TopBar/StageSelectBtn
@onready var bell_player: AudioStreamPlayer = $AbsentBellPlayer
@onready var notice_banner: PanelContainer = $NoticeBanner
@onready var notice_label: Label = $NoticeBanner/NoticeLabel

const SPEEDLINES_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.6;
	float r = length(uv);
	float ang = atan(uv.y, uv.x);
	float seg = floor(ang * 22.0);
	float n = fract(sin(seg * 12.9898 + floor(TIME * 26.0) * 78.233) * 43758.5453);
	float line = step(0.72, n) * smoothstep(0.30, 0.70, r);
	float vign = smoothstep(0.55, 1.0, r) * 0.55;
	COLOR = vec4(1.0, 1.0, 1.0, (line * 0.5 + vign * 0.5) * intensity);
}
"""

const RAIN_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV;
	float col = floor(uv.x * 110.0);
	float seed = fract(sin(col * 91.7) * 43758.5453);
	float y = fract(uv.y * 1.8 + TIME * (1.8 + seed * 1.4) + seed * 7.0);
	float streak = smoothstep(0.0, 0.10, y) * smoothstep(0.34, 0.12, y);
	float xin = fract(uv.x * 110.0);
	float thin = smoothstep(0.0, 0.35, xin) * smoothstep(0.65, 0.35, xin);
	float a = streak * thin * step(0.45, seed) * 0.45;
	float tint = smoothstep(0.0, 1.0, uv.y) * 0.08;
	COLOR = vec4(0.72, 0.82, 1.0, (a + tint) * intensity);
}
"""

var elapsed_sec: float = 0.0
## Story beat d0_race (A2-D10): replay recorder on the bike + rider; the finish crossing plays seg_d0_race first.
var story_rec: CineReplayRecorder
var story_replay: CineReplay
var is_game_ended: bool = false
var notice_tween: Tween

var bonus_total: float = 0.0
var penalty_total: float = 0.0
var near_miss_count: int = 0
var drift_boosts: int = 0
var crashes: int = 0
const BONUS_CAP: float = 12.0 # trần tổng giây thưởng (8 s x1,5 cùng với thưởng sát nút, tuyến thật 240 s)
var dist_label: Label
var dist_bar: ProgressBar

var speedlines_rect: ColorRect
var speedlines_mat: ShaderMaterial
var rain_rect: ColorRect
var rain_mat: ShaderMaterial
var rain_target: float = 0.0
var is_drifting: bool = false
var is_boosting: bool = false
var last_speed_kmh: float = 0.0
var stats_label: Label
var chain_panel: PanelContainer
var chain_label: Label
var chain_bar: ProgressBar
var chain_break_timer: float = 0.0
var _last_chain_seen: int = 0
var drift_hint_label: Label
## Phong cách vice (Task VC-4): radar góc dưới trái (tuyến thật BE6 -> FPTU màu hồng, cổng FPT = ô cam), tên khu vực
## dọc tuyến (trên bảng tốc độ), ví Cóc Vàng góc trên phải dưới thanh giờ; bảng thưởng / phạt nhích lên trên radar.
var vice_hud: ViceHUD
## Radar + tên khu vực theo node này thay cho xe (null = theo player_bike). Ảnh preview đặt camera chụp vào đây.
var radar_target: Node3D
var stats_holder: MarginContainer
const STATS_MARGIN: int = 24
const STATS_MARGIN_VICE: int = 244     # 28 (lề radar) + 200 (radar) + 16

# Audio Players
var checkpoint_player: AudioStreamPlayer
var victory_player: AudioStreamPlayer
var absent_player: AudioStreamPlayer

func _ready() -> void:
	absent_overlay.visible = false
	absent_overlay.modulate.a = 0.0
	notice_banner.visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	if next_stage_btn:
		next_stage_btn.pressed.connect(_on_next_stage_pressed)
	if campaign_hub_btn:
		campaign_hub_btn.pressed.connect(_on_campaign_hub_pressed)
	if stage_select_btn:
		stage_select_btn.text = "CHỌN MÀN [M]"
		stage_select_btn.pressed.connect(_on_stage_select_pressed)
	_setup_hud_audio()
	_setup_overlays()
	_setup_vice_hud()
	GameFX.disable_button_focus(self)
	if StoryStage.in_story(StageManager.StageID.STAGE_1_RACE) and player_bike:
		_make_story_recorder.call_deferred()   # the scene root is still adding its children here

	if player_bike:
		player_bike.connect("speed_changed", _on_player_speed_changed)
		player_bike.connect("respawned", _on_player_respawned)
		player_bike.connect("offroad_changed", _on_player_offroad_changed)
		player_bike.connect("crash_occurred", _on_player_crashed)
		if player_bike.has_signal("near_miss"):
			player_bike.connect("near_miss", _on_near_miss)
		if player_bike.has_signal("drift_boost"):
			player_bike.connect("drift_boost", _on_drift_boost)
		if player_bike.has_signal("drift_state_changed"):
			player_bike.connect("drift_state_changed", _on_drift_state_changed)
		if player_bike.has_signal("curb_hit"):
			player_bike.connect("curb_hit", _on_curb_hit)
	if road_manager:
		if road_manager is RoadManager:
			stage_duration_sec = RoadEvents.stage_time(RoadManager.STAGE_TIME)   # Q6: Dễ gets more time
		road_manager.connect("zone_changed", _on_zone_changed)
		road_manager.connect("destination_reached", _on_destination_reached)
		var ev: Node = road_manager.get("road_events")
		if ev:
			ev.connect("time_penalty", _on_event_penalty)
			ev.connect("time_bonus", _on_event_bonus)
			ev.connect("banner", _on_event_banner)
			ev.connect("rain_changed", _on_rain_changed)

	_show_notice("[W] GA · [S] PHANH/LÙI · [SPACE]+[A/D] DRIFT · LÁCH SÁT XE = +GIÂY · DỪNG ĐÈN ĐỎ!", Color("#F1C40F"), 4.5)

func _setup_overlays() -> void:
	# Speed lines (dưới cùng, không chặn chuột)
	speedlines_rect = ColorRect.new()
	speedlines_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speedlines_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speedlines_rect.color = Color.WHITE
	var sh := Shader.new()
	sh.code = SPEEDLINES_SHADER
	speedlines_mat = ShaderMaterial.new()
	speedlines_mat.shader = sh
	speedlines_mat.set_shader_parameter("intensity", 0.0)
	speedlines_rect.material = speedlines_mat
	add_child(speedlines_rect)
	move_child(speedlines_rect, 0)

	rain_rect = ColorRect.new()
	rain_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain_rect.color = Color.WHITE
	var rsh := Shader.new()
	rsh.code = RAIN_SHADER
	rain_mat = ShaderMaterial.new()
	rain_mat.shader = rsh
	rain_mat.set_shader_parameter("intensity", 0.0)
	rain_rect.material = rain_mat
	add_child(rain_rect)
	move_child(rain_rect, 1)

	# Bảng thống kê thưởng/phạt ở góc trái dưới (anchors chuẩn)
	var panel: PanelContainer = GameFX.anchored_panel(self, Control.PRESET_BOTTOM_LEFT, Vector2(300, 0), STATS_MARGIN, Color("#2ECC71"))
	stats_holder = panel.get_parent() as MarginContainer
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	stats_label = GameFX.make_label("THƯỞNG +0.0s · PHẠT +0.0s\nSÁT NÚT 0 · DRIFT 0", 14, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
	vb.add_child(stats_label)
	_build_chain_panel()
	drift_hint_label = GameFX.make_label("", 15, Color("#F39C12"), HORIZONTAL_ALIGNMENT_LEFT)
	vb.add_child(drift_hint_label)
	# Quãng đường còn lại tới cổng FPTU (đọc từ curve tuyến thật qua RoadManager.remaining_m) + thanh tiến độ
	dist_label = GameFX.make_label("CÒN LẠI – m", 14, Color("#74B9FF"), HORIZONTAL_ALIGNMENT_LEFT)
	vb.add_child(dist_label)
	dist_bar = GameFX.make_bar(0.0, Color("#74B9FF"), 8)
	vb.add_child(dist_bar)

## ViceHUD của Màn 1 (con của HUD, lớp vẽ 0): không có đồng hồ riêng (thanh giờ 07:05 -> 07:30 giữ nguyên), cột ví
## dưới thanh trên cùng và băng thông báo, tên khu vực trên bảng tốc độ. Ở vice các panel .tscn (giờ, khu vực, tốc độ, thông báo) đổi
## kiểu qua helper GameFX.
func _setup_vice_hud() -> void:
	var md: MapData = road_manager.get("md") as MapData if road_manager else null
	if md == null:
		md = MapData.load_default()
	vice_hud = ViceHUD.new()
	vice_hud.name = "ViceHUD"
	vice_hud.md = md
	vice_hud.show_clock = false
	# dưới cả thanh trên cùng (16..82) lẫn băng thông báo (96..148, nở rộng theo chữ có thể tới mép phải)
	vice_hud.top_margin = Vector2(28.0, 160.0)
	vice_hud.area_margin = Vector2(34.0, 192.0)
	add_child(vice_hud)
	if md:
		vice_hud.radar.route = md.route_points(40.0)
		var g: Variant = md.landmark("campus_main_gate")
		if g is Array and (g as Array).size() >= 2:
			vice_hud.radar.blips = [{"pos": Vector2(float(g[0]), float(g[1])), "color": GameFX.FPT_ORANGE, "shape": "square"}]
	if GameFX.is_vice_ui():
		_restyle_vice_panels()
	GameFX.art_style_changed.connect(_apply_hud_style)
	_apply_hud_style()

func _apply_hud_style(_style: String = "") -> void:
	if stats_holder:
		stats_holder.add_theme_constant_override("margin_bottom", STATS_MARGIN_VICE if ViceHUD.style_active() else STATS_MARGIN)

## Panel khai báo trong HUD.tscn -> kiểu vice qua helper GameFX (classic giữ StyleBoxFlat của .tscn).
func _restyle_vice_panels() -> void:
	var clock_panel: PanelContainer = clock_label.get_parent() as PanelContainer
	var zone_panel: PanelContainer = zone_label.get_parent() as PanelContainer
	var speed_panel: PanelContainer = get_node_or_null("BottomRight/SpeedContainer") as PanelContainer
	if clock_panel:
		clock_panel.add_theme_stylebox_override("panel", GameFX.make_panel_style())
	if zone_panel:
		zone_panel.add_theme_stylebox_override("panel", GameFX.make_panel_style(Color(0.2, 0.55, 0.9, 0.8)))
	if speed_panel:
		speed_panel.add_theme_stylebox_override("panel", GameFX.make_panel_style())
	notice_banner.add_theme_stylebox_override("panel", GameFX.make_panel_style(Color(0.9, 0.2, 0.2, 0.9), Color(0.12, 0.04, 0.04, 0.95)))
	for pair: Array in [[clock_label, 28], [zone_label, 20], [speed_label, 36], [slipstream_status, 12], [notice_label, 17]]:
		GameFX.style_label(pair[0] as Label, int(pair[1]))
	GameFX.style_bar(slipstream_bar, GameFX.VICE_CYAN)

func _update_vice_radar() -> void:
	var target: Node3D = radar_target if is_instance_valid(radar_target) else player_bike
	if vice_hud == null or not vice_hud.visible or target == null:
		return
	var p: Vector3 = target.global_position
	var cam: Camera3D = get_viewport().get_camera_3d()
	vice_hud.track(Vector2(p.x, p.z), cam.global_rotation.y if cam else target.global_rotation.y)

func _update_distance() -> void:
	if not dist_label or not road_manager:
		return
	var rem: Variant = road_manager.get("remaining_m")
	var total: Variant = road_manager.get("total_track_length")
	if not (rem is float) or not (total is float):
		return
	var total_m: float = maxf(1.0, float(total))
	var remaining: float = clampf(float(rem), 0.0, total_m)
	dist_label.text = "CÒN %d m TỚI CỔNG FPTU · ĐÃ ĐI %.1f / %.1f km" % [int(ceil(remaining)), (total_m - remaining) / 1000.0, total_m / 1000.0]
	dist_bar.value = (total_m - remaining) / total_m * 100.0

func _refresh_stats() -> void:
	if stats_label:
		stats_label.text = "THƯỞNG -%.1fs · PHẠT +%.1fs\nSÁT NÚT %d · DRIFT BOOST %d · VA CHẠM %d" % [bonus_total, penalty_total, near_miss_count, drift_boosts, crashes]

func _on_player_crashed() -> void:
	crashes += 1
	_refresh_stats()
	if damage_flash:
		damage_flash.color.a = 0.45
		var tween: Tween = create_tween()
		tween.tween_property(damage_flash, "color:a", 0.0, 0.35)

func _setup_hud_audio() -> void:
	checkpoint_player = AudioStreamPlayer.new()
	var bell_stream := GameFX.load_wav("res://assets/audio/checkpoint_bell.wav")
	if bell_stream:
		checkpoint_player.stream = bell_stream
		checkpoint_player.volume_db = 1.0
	add_child(checkpoint_player)

	victory_player = AudioStreamPlayer.new()
	var vic_stream := GameFX.load_wav("res://assets/audio/victory_fanfare.wav")
	if vic_stream:
		victory_player.stream = vic_stream
		victory_player.volume_db = 3.0
	add_child(victory_player)

	absent_player = AudioStreamPlayer.new()
	var abs_stream := GameFX.load_wav("res://assets/audio/absent_gameover.wav")
	if abs_stream:
		absent_player.stream = abs_stream
		absent_player.volume_db = 4.0
	add_child(absent_player)

func _process(delta: float) -> void:
	_update_chain_panel(delta)
	_update_distance()
	_update_vice_radar()
	if player_bike:
		GameFX.music_tension(clampf(absf(float(player_bike.get("current_speed_ms"))) * 3.6 / 75.0 * 0.55 + float(player_bike.get("near_miss_chain")) * 0.12, 0.2, 1.0))
	# Overlay luôn cập nhật (kể cả khi kết thúc để mờ dần)
	var speed_int: float = clampf((last_speed_kmh - 52.0) / 42.0, 0.0, 1.0)
	if is_boosting:
		speed_int = minf(1.0, speed_int + 0.35)
	if is_drifting:
		speed_int = minf(1.0, speed_int + 0.2)
	if is_game_ended:
		speed_int = 0.0
	var cur: float = float(speedlines_mat.get_shader_parameter("intensity"))
	speedlines_mat.set_shader_parameter("intensity", lerpf(cur, speed_int, delta * 6.0))
	var rcur: float = float(rain_mat.get_shader_parameter("intensity"))
	rain_mat.set_shader_parameter("intensity", lerpf(rcur, rain_target, delta * 2.5))

	if is_game_ended:
		return

	elapsed_sec += delta
	var progress: float = clampf(elapsed_sec / stage_duration_sec, 0.0, 1.0)
	var total_game_minutes: float = 5.0 + progress * 25.0
	var mins: int = int(floor(total_game_minutes))
	var secs: int = int(floor((total_game_minutes - float(mins)) * 60.0))

	var real_left: int = int(ceil(maxf(0.0, stage_duration_sec - elapsed_sec)))
	clock_label.text = "07:%02d:%02d · %ds" % [mins, secs, real_left]

	if mins >= 25:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		clock_label.modulate = Color(1.0, pulse * 0.3, pulse * 0.3)

	if elapsed_sec >= stage_duration_sec:
		_trigger_absent_screen()

func _on_player_speed_changed(speed_kmh: float, slip_ratio: float, boosting: bool) -> void:
	last_speed_kmh = speed_kmh
	is_boosting = boosting
	speed_label.text = "%02d km/h" % int(round(speed_kmh))
	slipstream_bar.value = slip_ratio * 100.0
	if boosting:
		slipstream_status.text = "BOOST! (NÚP GIÓ / DRIFT)"
		slipstream_status.modulate = Color("#FBC531")
	else:
		slipstream_status.text = "NÚP GIÓ SAU F-BUS (< 8M) · DRIFT: GIỮ [SPACE]+[A/D]"
		slipstream_status.modulate = Color("#DCDDE1")

func _on_drift_state_changed(active: bool) -> void:
	is_drifting = active
	if drift_hint_label:
		drift_hint_label.text = "ĐANG DRIFT... GIỮ ≥0.7s RỒI THẢ ĐỂ BOOST!" if active else ""

func _on_drift_boost(_duration: float) -> void:
	drift_boosts += 1
	_refresh_stats()
	GameFX.popup("DRIFT BOOST!", Color("#F39C12"), 34, 0.8)
	GameFX.flash(Color("#F39C12"), 0.22, 0.3)

func _on_near_miss(chain: int) -> void:
	near_miss_count += 1
	# Thưởng theo chuỗi 0.75 / 1.125 / 1.5 s (= 0.5 / 0.75 / 1.0 x1,5 cho tuyến thật 240 s), trần tổng BONUS_CAP
	var bonus: float = [0.75, 1.125, 1.5][mini(chain, 3) - 1]
	var granted: float = _grant_bonus(bonus)
	var txt: String
	if chain <= 1:
		txt = "SÁT NÚT! -%.1fs" % granted
	else:
		txt = "SÁT NÚT x%d! -%.2fs" % [chain, granted]
	if granted <= 0.0:
		txt = "SÁT NÚT x%d! (đã đạt trần thưởng %.0fs – vẫn tính điểm)" % [chain, BONUS_CAP]
	GameFX.popup(txt, Color("#00D2D3"), 30 if chain <= 1 else 36, 0.6)
	_show_chain(chain)
	_refresh_stats()

## Bảng chuỗi sát nút giữa đỉnh màn hình: số chuỗi + thanh thời gian còn giữ chuỗi
func _build_chain_panel() -> void:
	chain_panel = GameFX.anchored_panel(self, Control.PRESET_CENTER_TOP, Vector2(300, 0), 96, Color("#00D2D3"))
	chain_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	chain_panel.add_child(vb)
	chain_label = GameFX.make_label("SÁT NÚT x1", 40, GameFX.FPT_YELLOW)
	chain_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	chain_label.add_theme_constant_override("outline_size", 8)
	chain_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.9))
	vb.add_child(chain_label)
	chain_bar = GameFX.make_bar(100.0, Color("#00D2D3"), 10)
	vb.add_child(chain_bar)
	var hint: Label = GameFX.make_label("giữ chuỗi: lách sát xe ngược chiều trong 6 s", 11, Color("#BDC3C7"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(hint)

func _show_chain(chain: int) -> void:
	if not chain_panel:
		return
	chain_panel.visible = true
	chain_break_timer = 0.0
	chain_label.text = "SÁT NÚT x%d" % chain if chain > 1 else "SÁT NÚT!"
	chain_label.add_theme_color_override("font_color", GameFX.FPT_YELLOW if chain < 3 else Color("#FF9F43"))
	chain_panel.scale = Vector2(1.18, 1.18)
	chain_panel.pivot_offset = chain_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(chain_panel, "scale", Vector2.ONE, 0.12)
	if chain >= 3:
		GameFX.flash(Color(1.0, 0.85, 0.3), 0.18, 0.15)

func _update_chain_panel(delta: float) -> void:
	if not chain_panel or not player_bike:
		return
	var chain: int = int(player_bike.get("near_miss_chain"))
	var timer: float = float(player_bike.get("near_miss_chain_timer"))
	if chain > 0:
		chain_bar.value = clampf(timer / float(player_bike.get("NEAR_MISS_CHAIN_WINDOW")) * 100.0, 0.0, 100.0)
		GameFX.set_bar_color(chain_bar, Color("#00D2D3") if timer > 2.0 else GameFX.FPT_RED)
	elif _last_chain_seen > 0:
		# chuỗi vừa đứt: báo ngắn rồi ẩn
		chain_label.text = "CHUỖI ĐỨT" if _last_chain_seen > 1 else ""
		chain_label.add_theme_color_override("font_color", Color("#BDC3C7"))
		chain_bar.value = 0.0
		chain_break_timer = 0.6
	if chain == 0 and chain_break_timer > 0.0:
		chain_break_timer -= delta
		if chain_break_timer <= 0.0:
			chain_panel.visible = false
	_last_chain_seen = chain

func _grant_bonus(sec: float) -> float:
	var room: float = maxf(0.0, BONUS_CAP - bonus_total)
	var granted: float = minf(sec, room)
	bonus_total += granted
	elapsed_sec = maxf(0.0, elapsed_sec - granted)
	if granted > 0.0:
		clock_label.modulate = Color("#2ECC71")
		var tw := create_tween()
		tw.tween_property(clock_label, "modulate", Color.WHITE, 0.6)
	return granted

func _apply_penalty(sec: float) -> void:
	penalty_total += sec
	elapsed_sec = minf(stage_duration_sec, elapsed_sec + sec)
	clock_label.modulate = Color("#FF4757")
	var tw := create_tween()
	tw.tween_property(clock_label, "modulate", Color.WHITE, 0.8)
	_refresh_stats()

func _on_event_penalty(sec: float, msg: String) -> void:
	_apply_penalty(sec)
	_show_notice(msg, Color("#FF4757"), 2.6)

func _on_event_bonus(sec: float, msg: String) -> void:
	var granted: float = _grant_bonus(sec)
	_refresh_stats()
	_show_notice(msg if granted > 0.0 else msg + " (đã đạt trần thưởng)", Color("#2ECC71"), 2.2)

func _on_event_banner(text: String, color: Color, duration: float) -> void:
	_show_notice(text, color, duration)

func _on_rain_changed(raining: bool) -> void:
	rain_target = 1.0 if raining else 0.0

func _on_zone_changed(zone_name: String) -> void:
	zone_label.text = zone_name
	if checkpoint_player:
		checkpoint_player.play()

func _on_curb_hit(penalty_sec: float) -> void:
	_apply_penalty(penalty_sec)
	_show_notice("LEO LỀ! Văng ngược lại lòng đường (+%d GIÂY PHẠT)" % int(penalty_sec), Color("#FFA502"), 1.6)

func _trigger_absent_screen() -> void:
	is_game_ended = true
	if player_bike:
		player_bike.set("is_controls_locked", true)
		if player_bike.has_method("park"):
			player_bike.call("park")   # strobe / headlight off, horn melody stopped (owner-bike fix round)
	StageManager.report_stage_result(StageManager.StageID.STAGE_1_RACE, {"result": "fail", "score": 0, "rank": "C", "detail": "absent"})

	absent_title.text = "BẠN ĐÃ BỊ ĐÁNH ABSENT!\nHẸN GẶP LẠI Ở KỲ RETAKE (HỌC LẠI)!\n\nSát nút %d · Drift boost %d · Va chạm %d · Phạt %.1fs" % [near_miss_count, drift_boosts, crashes, penalty_total]
	absent_title.modulate = Color("#FF1E1E")
	if next_stage_btn:
		next_stage_btn.visible = false
	absent_overlay.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(absent_overlay, "modulate:a", 1.0, 1.1)
	if absent_player and absent_player.stream:
		absent_player.play()
	else:
		_play_procedural_absent_bell()

func _on_destination_reached() -> void:
	if is_game_ended:
		return   # already ABSENT (time ran out just before the line) or already reported: no second result / replay
	is_game_ended = true
	if player_bike:
		player_bike.set("is_controls_locked", true)
		if player_bike.has_method("park"):
			player_bike.call("park")   # strobe / headlight off, horn melody stopped (owner-bike fix round)
	if story_rec and is_instance_valid(story_rec):
		await _story_replay()

	var time_left: float = maxf(0.0, stage_duration_sec - elapsed_sec)
	# Q6: the score counts the time left on the BASE clock (RoadManager.STAGE_TIME), never Dễ's longer budget, so Dễ
	# runs do not inflate the score or the shared records
	var score_left: float = maxf(0.0, RoadManager.STAGE_TIME - elapsed_sec)
	var longest_chain: int = int(player_bike.get("longest_near_miss_chain")) if player_bike else 0
	var score: int = int(score_left * 40.0) + near_miss_count * 60 + longest_chain * 60 + drift_boosts * 50 - crashes * 40
	score = maxi(0, score)
	# S đòi hỏi ít nhất một chuỗi sát nút 3 (ngưỡng 1100 -> 1250). Wave 2: the bus cut-in, the jam and the flood make a
	# clean run about 14 s slower (about -560 points): S 1250 -> 700, A 800 -> 380, B 450 -> 180.
	var rank: String = GameFX.rank_for(float(score), 700.0, 380.0, 180.0)
	StageManager.report_stage_result(StageManager.StageID.STAGE_1_RACE, {
		"result": "win", "score": score, "rank": rank,
		"detail": "left=%.1f nearmiss=%d chain=%d drift=%d crash=%d" % [time_left, near_miss_count, longest_chain, drift_boosts, crashes]
	})

	absent_title.text = "ĐIỂM DANH SLOT 1 THÀNH CÔNG [PRESENT]! RANK %s\nCHÀO MỪNG ĐẾN ĐẠI HỌC FPT TP.HCM!\n\nCòn dư %ds · Sát nút %d (chuỗi dài nhất x%d) · Drift boost %d · Va chạm %d · Điểm %d" % [rank, int(time_left), near_miss_count, longest_chain, drift_boosts, crashes, score]
	absent_title.modulate = Color("#4CD137")
	if next_stage_btn:
		next_stage_btn.visible = true
	absent_overlay.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(absent_overlay, "modulate:a", 1.0, 0.8)
	if victory_player and victory_player.stream:
		victory_player.play()
	GameFX.flash(Color("#2ECC71"), 0.4, 0.5)

func _make_story_recorder() -> void:
	if is_instance_valid(player_bike):
		story_rec = StoryStage.make_recorder(player_bike.get_parent(), [player_bike, player_bike.get("rider_node")])

## Story win: mark the crossing, let the bike roll on briefly, then the 5 s slow-motion replay (seg_d0_race).
func _story_replay() -> void:
	story_rec.mark("blow")
	await get_tree().create_timer(StoryStage.REPLAY_AFTER, false).timeout
	var slot: String = String(StoryStage.context_for(StageManager.StageID.STAGE_1_RACE).get("replay", "seg_d0_race"))
	story_replay = StoryStage.play_replay(player_bike.get_parent(), story_rec, slot, player_bike, player_bike.get("rider_node"))
	if story_replay:
		await story_replay.finished
	story_replay = null

func _play_procedural_absent_bell() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.5
	bell_player.stream = gen
	bell_player.play()

	var playback: AudioStreamGeneratorPlayback = bell_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var total_frames: int = int(gen.mix_rate * 1.2)
		for i: int in range(total_frames):
			var t: float = float(i) / gen.mix_rate
			var freq: float = 110.0 if t < 0.45 else 82.41
			var env: float = exp(-t * 2.2)
			var sample: float = sin(TAU * freq * t) * env * 0.45
			playback.push_frame(Vector2(sample, sample))

func _on_player_respawned(penalty_sec: float) -> void:
	_apply_penalty(penalty_sec)
	_show_notice("NGÃ XE RƠI KHỎI ĐƯỜNG! ĐÃ CỨU HỘ VỀ TIM ĐƯỜNG (+%d GIÂY PHẠT)!" % int(penalty_sec), Color("#FF4757"), 2.4)

func _on_player_offroad_changed(is_offroad: bool) -> void:
	if is_offroad:
		notice_label.text = "LEO LỀ! ĐANG ĐẨY XE VỀ LÒNG ĐƯỜNG – GIẢM TỐC!"
		notice_label.modulate = Color("#FFA502")
		notice_banner.visible = true
		notice_banner.modulate.a = 1.0
		if notice_tween:
			notice_tween.kill()
	else:
		if notice_label.text.begins_with("LEO LỀ"):
			notice_banner.visible = false

func _show_notice(text: String, color: Color, duration: float) -> void:
	notice_label.text = text
	notice_label.modulate = color
	notice_banner.visible = true
	notice_banner.modulate.a = 1.0
	if notice_tween:
		notice_tween.kill()
	notice_tween = create_tween()
	notice_tween.tween_interval(duration)
	notice_tween.tween_property(notice_banner, "modulate:a", 0.0, 0.4)

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_next_stage_pressed() -> void:
	StageManager.change_stage(StageManager.StageID.STAGE_2_PARKING)

func _on_campaign_hub_pressed() -> void:
	StageManager.open_stage_select()

func _on_stage_select_pressed() -> void:
	StageManager.toggle_stage_select()
