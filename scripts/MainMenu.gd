# File: res://scripts/MainMenu.gd
# MENU CHÍNH – hiện ngay khi mở game.
#   Nền 3D: chính khuôn viên ĐH FPT thật (cùng FPTUCampusBuilder với 7 màn) + HUTECH + đường D1, camera bay chậm
#   qua 5 góc (toàn cảnh từ phía HUTECH, dolly dọc D1, sân trong + hồ sen, sân trước + cầu thang ngoài trời, flycam),
#   xe máy sinh viên chạy qua lại trên D1, nắng sớm vàng.
#   Nút (story Phase A2, spec A2-D6): ▶ TIẾP TỤC – NGÀY N (chỉ khi có bản lưu cốt truyện hợp lệ: StoryDirector.continue_story)
#        · ✚ CỐT TRUYỆN MỚI: TOOL ĐEN (có bản lưu thì hỏi "Ghi đè bản lưu Ngày N?"; rồi màn tạo nhân vật) · 🌏 KHÁM PHÁ CAMPUS
#        (thế giới mở FreeRoam chơi tự do, không cốt truyện: spawn ở BE6 Vinhomes Grand Park) · 🎮 HƯỚNG DẪN ĐIỀU KHIỂN
#        (bảng phím + khối "Nguồn dữ liệu bản đồ": OpenStreetMap ODbL, footprint nhà Microsoft CDLA-Permissive-2.0)
#        · ⚙ CÀI ĐẶT ĐỒ HOẠ (3 mức chất lượng + toàn màn hình + phong cách Vice City / Cổ điển + vệt sáng + "Giảm hù dọa",
#        lưu user://settings.cfg) · ✖ THOÁT. Điều hướng: chuột hoặc ↑↓ + Enter.
#   Đã bỏ (A2-D6): "Bắt đầu ngày mới", "Chọn màn", bảng "Nhật ký hành trình", phím [M] mở hub ở menu.
class_name MainMenu
extends Node3D

## 5 góc máy (hệ cục bộ campus v8: lô 190 × 116 m, vòng nhà u 14..175 × v 16..93, sân trong u 42..147 × v 30..79,
## cổng chính u = 7, cổng tây u = 181, HUTECH sau hàng rào v = −46)
const SHOTS: Array = [
	{"from": Vector3(-30.0, 48.0, -70.0), "to": Vector3(45.0, 44.0, -84.0), "look_from": Vector3(95.0, 6.0, 58.0), "look_to": Vector3(101.0, 8.0, 52.0), "fov": 58.0, "dur": 11.0},
	{"from": Vector3(-30.0, 2.3, -9.7), "to": Vector3(70.0, 2.5, -9.7), "look_from": Vector3(60.0, 9.0, 16.0), "look_to": Vector3(150.0, 10.0, 22.0), "fov": 66.0, "dur": 11.0},
	{"from": Vector3(62.0, 2.2, 66.0), "to": Vector3(72.0, 2.6, 60.0), "look_from": Vector3(110.0, 6.0, 55.0), "look_to": Vector3(128.0, 9.0, 60.0), "fov": 68.0, "dur": 11.0},
	{"from": Vector3(78.0, 2.6, 8.5), "to": Vector3(94.0, 3.0, 9.5), "look_from": Vector3(120.0, 9.0, 14.0), "look_to": Vector3(140.0, 15.0, 16.0), "fov": 64.0, "dur": 11.0},
	{"from": Vector3(220.0, 58.0, -30.0), "to": Vector3(180.0, 72.0, -100.0), "look_from": Vector3(95.0, 0.0, 60.0), "look_to": Vector3(87.0, 0.0, 58.0), "fov": 56.0, "dur": 12.0}
]
const FADE_T: float = 0.55
## Bảng Hướng dẫn: khối "Nguồn dữ liệu bản đồ" (OpenStreetMap ODbL + footprint nhà Microsoft CDLA-Permissive-2.0).
const MAP_CREDITS_TITLE: String = "Nguồn dữ liệu bản đồ"
const MAP_CREDITS: Array[String] = ["© OpenStreetMap contributors (ODbL)", "Building footprints © Microsoft (CDLA-Permissive-2.0)"]

@onready var cam: Camera3D = $Camera3D
@onready var world: Node3D = $World
@onready var fade_rect: ColorRect = $Fade/FadeRect
@onready var ui: CanvasLayer = $UI

var shot_idx: int = 0
var shot_t: float = 0.0
var bikes: Array[Dictionary] = []
var campus_mats: Dictionary = {}

var btn_continue: Button
var btn_story: Button
var btn_chapters: Button
var btn_roam: Button
var btn_guide: Button
var btn_settings: Button
var btn_quit: Button
var modal_dim: ColorRect
var guide_panel: PanelContainer
var settings_panel: PanelContainer
var quality_buttons: Array[Button] = []
var fullscreen_check: CheckButton
var confirm_panel: PanelContainer
var confirm_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	GameFX.reset_all()
	_build_world()
	_build_ui()
	GameFX.upgrade_scene_visuals(self, "dawn")
	# đổi phong cách (bảng cài đặt) -> chú thích nút mức đồ hoạ theo phong cách mới (tự ngắt khi menu bị giải phóng)
	GameFX.art_style_changed.connect(_on_art_style_changed)
	GameFX.music_play("menu", 0.2)
	_apply_shot(0.0)
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_refresh_story_buttons()
	_first_button().call_deferred("grab_focus")

# ===========================================================================
# NỀN 3D
# ===========================================================================
func _build_world() -> void:
	campus_mats = FPTUCampusBuilder.make_materials()
	FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": true, "palms": GameFX.art_style == "vice"})
	FPTUCampusBuilder.build_hutech(world, FPTUCampusBuilder.hutech_origin_local(), campus_mats)
	FPTUCampusBuilder.build_d1_road_piece(world, -13.0, -140.0, 340.0, campus_mats, 0.0)
	# Mặt đất xa + nền cỏ bao quanh
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(1400.0, 1400.0)
	ground.mesh = gm
	var mat_ground: StandardMaterial3D = campus_mats["grass"].duplicate()
	mat_ground.uv1_triplanar = true
	mat_ground.uv1_scale = Vector3(0.08, 0.08, 0.08)
	mat_ground.albedo_color = Color(0.86, 0.88, 0.8)
	ground.material_override = mat_ground
	ground.position = Vector3(90.0, -0.2, 40.0)
	world.add_child(ground)
	# Xe máy sinh viên chạy qua lại trên D1 cho có sự sống
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var specs: Array = [
		[-9.7, 1.0, 9.0, -60.0], [-11.2, 1.0, 11.5, 40.0], [-9.7, 1.0, 8.2, 150.0],
		[-16.3, -1.0, 9.5, 260.0], [-14.8, -1.0, 12.0, 120.0], [-16.3, -1.0, 8.8, 10.0]
	]
	for sp: Array in specs:
		var dir_sign: float = float(sp[1])
		var paint: Color = FPTUCampusBuilder.BIKE_PAINTS[rng.randi() % FPTUCampusBuilder.BIKE_PAINTS.size()]
		var bike: Node3D = PropBuilder.build_scooter(world, Vector3(float(sp[3]), 0.0, float(sp[0])), deg_to_rad(-90.0 * dir_sign), paint, {"baked": true})["root"]
		_add_rider(bike, rng)
		bikes.append({"node": bike, "dir": dir_sign, "speed": float(sp[2]), "z": float(sp[0])})

func _add_rider(bike: Node3D, rng: RandomNumberGenerator) -> void:
	var opts: Dictionary = {"seed": rng.randi(), "helmet_color": [Color("#F1C40F"), Color("#E74C3C"), Color("#ECF0F1"), Color("#2C3E50")][rng.randi() % 4]}
	if rng.randf() < 0.5:
		opts["shirt_color"] = [Color("#2C3E50"), Color("#3498DB"), Color("#2ECC71"), Color("#ECF0F1")][rng.randi() % 4]
	CharacterBuilder.build_baked_rider(bike, Vector3(0.0, 0.32, 0.12), opts)

func _process(delta: float) -> void:
	# Xe chạy trên D1, quay vòng
	for b: Dictionary in bikes:
		var node: Node3D = b["node"]
		node.position.x += float(b["dir"]) * float(b["speed"]) * delta
		if float(b["dir"]) > 0.0 and node.position.x > 330.0:
			node.position.x = -130.0
		elif float(b["dir"]) < 0.0 and node.position.x < -130.0:
			node.position.x = 330.0
	# Camera bay theo shot
	var s: Dictionary = SHOTS[shot_idx]
	shot_t += delta
	var dur: float = float(s["dur"])
	if shot_t >= dur:
		shot_idx = (shot_idx + 1) % SHOTS.size()
		shot_t = 0.0
		s = SHOTS[shot_idx]
		dur = float(s["dur"])
	_apply_shot(shot_t / dur)
	var a_in: float = clampf(1.0 - shot_t / FADE_T, 0.0, 1.0)
	var a_out: float = clampf((shot_t - (dur - FADE_T)) / FADE_T, 0.0, 1.0)
	fade_rect.color.a = maxf(a_in, a_out)

func _apply_shot(t: float) -> void:
	var s: Dictionary = SHOTS[shot_idx]
	var k: float = smoothstep(0.0, 1.0, t)
	var pos: Vector3 = (s["from"] as Vector3).lerp(s["to"], k)
	var look: Vector3 = (s["look_from"] as Vector3).lerp(s["look_to"], k)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = float(s["fov"])

# ===========================================================================
# UI (anchors / containers)
# ===========================================================================
func _style_button(btn: Button, accent: Color = GameFX.FPT_ORANGE) -> void:
	var normal := GameFX.make_panel_style(Color(accent, 0.55), Color(0.05, 0.07, 0.12, 0.86), 10)
	var hover := GameFX.make_panel_style(accent, Color(0.1, 0.12, 0.2, 0.96), 10)
	var pressed := GameFX.make_panel_style(GameFX.FPT_YELLOW, Color(0.18, 0.1, 0.03, 0.98), 10)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("#F4F5F6"))
	btn.add_theme_color_override("font_hover_color", GameFX.FPT_YELLOW)
	btn.add_theme_color_override("font_focus_color", GameFX.FPT_YELLOW)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.mouse_entered.connect(func() -> void: GameFX.play_ui("tick", -10.0, 1.4))
	btn.focus_entered.connect(func() -> void: GameFX.play_ui("tick", -10.0, 1.4))

func _menu_button(text: String, accent: Color = GameFX.FPT_ORANGE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 19)
	b.focus_mode = Control.FOCUS_ALL
	_style_button(b, accent)
	return b

func _build_ui() -> void:
	# Dải tối bên trái cho chữ dễ đọc
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 560.0
	shade.color = Color(0.02, 0.03, 0.06, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	var shade2 := ColorRect.new()
	shade2.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade2.offset_left = 560.0
	shade2.offset_right = 640.0
	shade2.color = Color(0.02, 0.03, 0.06, 0.25)
	shade2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade2)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 560.0
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.add_theme_constant_override("margin_right", 24)
	ui.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var kicker: Label = GameFX.make_label("TRƯỜNG ĐẠI HỌC FPT TP.HCM · KHU CÔNG NGHỆ CAO · ĐƯỜNG D1", 12, Color("#BDC3C7"), HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(kicker)
	var title: Label = GameFX.make_label("FPTU STUDENT\nSIMULATOR", 46, GameFX.FPT_ORANGE, HORIZONTAL_ALIGNMENT_LEFT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.9))
	col.add_child(title)
	var subtitle: Label = GameFX.make_label("ĐƯỜNG ĐẾN TRƯỜNG", 26, GameFX.FPT_YELLOW, HORIZONTAL_ALIGNMENT_LEFT)
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.9))
	col.add_child(subtitle)
	var tagline: Label = GameFX.make_label("Cốt truyện TOOL ĐEN – 7 ngày minh oan: sáng thi EOS, đêm bị cài kính gian lận vào ba lô, sáng mai bị đình chỉ thi. Còn 7 ngày để tìm bằng chứng... hoặc cứ đi chơi campus tự do.", 13, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(440, 0)
	col.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	col.add_child(spacer)

	btn_continue = _menu_button("TIẾP TỤC – NGÀY 0", GameFX.FPT_ORANGE)
	btn_continue.name = "ContinueButton"
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_continue.visible = false
	col.add_child(btn_continue)
	btn_story = _menu_button("CỐT TRUYỆN", Color("#FF4FA3"))
	btn_story.name = "NewStoryButton"
	btn_story.pressed.connect(_on_story_pressed)
	col.add_child(btn_story)
	btn_chapters = _menu_button("CHỌN CẢNH  (tua lại · xem lại phim)", Color("#3FF2FF"))
	btn_chapters.name = "ChaptersButton"
	btn_chapters.pressed.connect(_on_chapters_pressed)
	btn_chapters.visible = false
	col.add_child(btn_chapters)
	btn_roam = _menu_button("KHÁM PHÁ CAMPUS  (chơi tự do · BE6 → FPTU)", Color("#1ABC9C"))
	btn_roam.pressed.connect(_on_roam_pressed)
	col.add_child(btn_roam)
	btn_guide = _menu_button("HƯỚNG DẪN ĐIỀU KHIỂN", Color("#3498DB"))
	btn_guide.pressed.connect(_show_guide)
	col.add_child(btn_guide)
	btn_settings = _menu_button("CÀI ĐẶT ĐỒ HOẠ", Color("#2ECC71"))
	btn_settings.pressed.connect(_show_settings)
	col.add_child(btn_settings)
	btn_quit = _menu_button("THOÁT GAME", Color("#E74C3C"))
	btn_quit.pressed.connect(_on_quit_pressed)
	col.add_child(btn_quit)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer2)
	var footer: Label = GameFX.make_label("↑↓ chọn · Enter xác nhận · Godot 4\nẢnh tham chiếu & texture mặt tiền: ảnh chụp thật, không dùng AI tạo ảnh", 11, Color("#95A5A6"), HORIZONTAL_ALIGNMENT_LEFT)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size = Vector2(440, 0)
	col.add_child(footer)

	# Góc trên phải: phiên bản
	var ver: PanelContainer = GameFX.anchored_panel(ui, Control.PRESET_TOP_RIGHT, Vector2(0, 0), 20, Color("#7F8C8D"))
	var ver_lbl: Label = GameFX.make_label("v4 · cốt truyện TOOL ĐEN (Ngày 0) · campus dựng theo ảnh flycam thật", 11, Color("#BDC3C7"))
	ver_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	ver.add_child(ver_lbl)

	# Lớp mờ + 2 bảng modal (hướng dẫn, cài đặt)
	modal_dim = ColorRect.new()
	modal_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_dim.color = Color(0.02, 0.03, 0.06, 0.78)
	modal_dim.visible = false
	modal_dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_hide_modals())
	ui.add_child(modal_dim)
	guide_panel = _build_guide_panel()
	settings_panel = _build_settings_panel()
	confirm_panel = _build_confirm_panel()

func _center_modal(min_size: Vector2, border: Color) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", GameFX.make_panel_style(border, Color(0.05, 0.07, 0.12, 0.97), 12))
	panel.visible = false
	center.add_child(panel)
	return panel

func _build_guide_panel() -> PanelContainer:
	var panel: PanelContainer = _center_modal(Vector2(900, 0), Color("#3498DB"))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 24)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	v.add_child(GameFX.make_label("HƯỚNG DẪN ĐIỀU KHIỂN", 24, Color("#3498DB")))
	# The rows scroll inside a fixed height so the panel (title, credits, close button) stays inside the 720 px screen
	var scroll := ScrollContainer.new()
	scroll.name = "GuideScroll"
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var lines: Array = StageManager.CONTROLS_GUIDE
	for ln: Array in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		rows.add_child(row)
		var k: Label = GameFX.make_label(String(ln[0]), 14, GameFX.FPT_YELLOW, HORIZONTAL_ALIGNMENT_LEFT)
		k.custom_minimum_size = Vector2(190, 0)
		row.add_child(k)
		var d: Label = GameFX.make_label(String(ln[1]), 13, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
	v.add_child(HSeparator.new())
	v.add_child(_build_map_credits())
	var close := _menu_button("ĐÃ HIỂU, ĐÓNG  [ESC]", Color("#3498DB"))
	close.custom_minimum_size = Vector2(320, 46)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.pressed.connect(_hide_modals)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(close)
	v.add_child(hb)
	return panel

## Ghi công dữ liệu bản đồ (thế giới mở + Màn 1, plan Task 7): một dòng như bảng phím, cột trái tiêu đề, cột phải
## hai dòng giấy phép. Chuỗi đầy đủ (kèm link giấy phép) ở assets/data/mapdata.json["attribution"] và README.md.
func _build_map_credits() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "MapCredits"
	row.add_theme_constant_override("separation", 14)
	var k: Label = GameFX.make_label(MAP_CREDITS_TITLE, 14, Color("#1ABC9C"), HORIZONTAL_ALIGNMENT_LEFT)
	k.custom_minimum_size = Vector2(190, 0)
	row.add_child(k)
	var d: Label = GameFX.make_label("\n".join(PackedStringArray(MAP_CREDITS)), 12, Color("#BDC3C7"), HORIZONTAL_ALIGNMENT_LEFT)
	d.name = "MapCreditsText"
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(d)
	return row

func _build_settings_panel() -> PanelContainer:
	var panel: PanelContainer = _center_modal(Vector2(760, 0), Color("#2ECC71"))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 24)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	v.add_child(GameFX.make_label("CÀI ĐẶT ĐỒ HOẠ", 24, Color("#2ECC71")))
	var desc: Label = GameFX.make_label("Phong cách Vice City (mặc định) dùng ánh sáng phẳng kiểu PS2, nhẹ máy; mức đồ hoạ đổi bóng đổ và khử răng cưa. Phong cách Cổ điển ở mức CAO bật SDFGI, SSIL, phản xạ màn hình, sương thể tích. Áp dụng ngay và lưu cho lần sau.", 13, Color("#BDC3C7"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var qrow := HBoxContainer.new()
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	qrow.add_theme_constant_override("separation", 10)
	v.add_child(qrow)
	quality_buttons.clear()
	for q: int in range(3):
		var b := _menu_button(_quality_text(q), Color("#2ECC71"))
		b.name = "QualityButton%d" % q
		b.custom_minimum_size = Vector2(225, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_set_quality.bind(q))
		qrow.add_child(b)
		quality_buttons.append(b)
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Toàn màn hình (Fullscreen)"
	fullscreen_check.add_theme_font_size_override("font_size", 15)
	fullscreen_check.button_pressed = GameFX.fullscreen
	fullscreen_check.toggled.connect(func(on: bool) -> void:
		GameFX.set_fullscreen(on)
		GameFX.play_sfx("pop", -6.0))
	var frow := HBoxContainer.new()
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	frow.add_child(fullscreen_check)
	v.add_child(frow)
	# Phong cách đồ hoạ (Vice City / Cổ điển) + vệt sáng: GameFX.set_art_style() áp lại nền 3D của menu ngay
	GameFX.build_style_settings(v)
	GameFX.build_story_settings(v)
	v.add_child(GameFX.make_label("ÂM LƯỢNG", 18, Color("#2ECC71")))
	GameFX.build_audio_settings(v)
	var close := _menu_button("LƯU & ĐÓNG  [ESC]", Color("#2ECC71"))
	close.custom_minimum_size = Vector2(320, 46)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.pressed.connect(_hide_modals)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(close)
	v.add_child(hb)
	_refresh_quality_buttons()
	return panel

## Chữ trên nút mức đồ hoạ q theo phong cách hiện tại (GameFX.quality_caption): "THẤP\nbóng cơ bản"...
func _quality_text(q: int) -> String:
	var cap: PackedStringArray = GameFX.quality_caption(q)
	return "%s%s\n%s" % [cap[0], " (mặc định)" if q == 2 else "", cap[1]]

func _on_art_style_changed(_style: String) -> void:
	_refresh_quality_buttons()

func _refresh_quality_buttons() -> void:
	for q: int in range(quality_buttons.size()):
		var b: Button = quality_buttons[q]
		b.text = _quality_text(q)
		var active: bool = q == GameFX.visual_quality
		b.add_theme_color_override("font_color", GameFX.FPT_YELLOW if active else Color("#F4F5F6"))
		b.add_theme_stylebox_override("normal", GameFX.make_panel_style(GameFX.FPT_YELLOW if active else Color(0.18, 0.8, 0.44, 0.45), Color(0.12, 0.1, 0.03, 0.96) if active else Color(0.05, 0.07, 0.12, 0.86), 10))

## "Ghi đè bản lưu Ngày N?" before a new story replaces the save.
func _build_confirm_panel() -> PanelContainer:
	var panel: PanelContainer = _center_modal(Vector2(520, 0), Color("#FF4FA3"))
	panel.name = "ConfirmPanel"
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 24)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	confirm_label = GameFX.make_label("Ghi đè bản lưu Ngày 0?", 22, Color("#FF4FA3"))
	confirm_label.name = "ConfirmLabel"
	v.add_child(confirm_label)
	v.add_child(GameFX.make_label("Bản lưu cốt truyện hiện tại sẽ mất, câu chuyện bắt đầu lại từ màn tạo nhân vật.", 13, Color("#BDC3C7")))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	v.add_child(hb)
	var yes := _menu_button("GHI ĐÈ", Color("#FF4FA3"))
	yes.name = "ConfirmYes"
	yes.custom_minimum_size = Vector2(200, 46)
	yes.alignment = HORIZONTAL_ALIGNMENT_CENTER
	yes.pressed.connect(func() -> void:
		_hide_modals()
		_open_creator())
	hb.add_child(yes)
	var no := _menu_button("THÔI", Color("#7F8C8D"))
	no.name = "ConfirmNo"
	no.custom_minimum_size = Vector2(200, 46)
	no.alignment = HORIZONTAL_ALIGNMENT_CENTER
	no.pressed.connect(_hide_modals)
	hb.add_child(no)
	return panel

func _director() -> Node:
	return get_node_or_null("/root/StoryDirector")

## The saved story state ({} = no valid save).
func _save_info() -> Dictionary:
	var sd: Node = _director()
	if sd == null:
		return {}
	return sd.call("read_save", String(sd.get("save_path")))

## "TIẾP TỤC – NGÀY N" only with a valid save (A2-D2, A2-D6).
func _refresh_story_buttons() -> void:
	var info: Dictionary = _save_info()
	btn_continue.visible = not info.is_empty() and String(info.get("ending", "")) == ""   # a finished story (ending C) only rewinds
	if not info.is_empty():
		btn_continue.text = "TIẾP TỤC – NGÀY %d" % int(info.get("day", 0))
	StoryChapters.ensure_seeded(info)   # a save from before the chapter select unlocks what it has played
	btn_chapters.visible = StoryChapters.has_unlocks()

func _first_button() -> Button:
	return btn_continue if btn_continue.visible else btn_story

# ===========================================================================
# HÀNH ĐỘNG
# ===========================================================================
func _show_guide() -> void:
	GameFX.play_sfx("pop", -6.0)
	modal_dim.visible = true
	guide_panel.visible = true
	settings_panel.visible = false

func _show_settings() -> void:
	GameFX.play_sfx("pop", -6.0)
	_refresh_quality_buttons()
	fullscreen_check.button_pressed = GameFX.fullscreen
	GameFX.sync_style_settings(settings_panel)
	modal_dim.visible = true
	settings_panel.visible = true
	guide_panel.visible = false

func _hide_modals() -> void:
	modal_dim.visible = false
	guide_panel.visible = false
	settings_panel.visible = false
	if confirm_panel:
		confirm_panel.visible = false
	_first_button().grab_focus()

func _set_quality(q: int) -> void:
	GameFX.set_visual_quality(q)
	_refresh_quality_buttons()
	GameFX.upgrade_scene_visuals(self, "dawn")
	GameFX.play_sfx("pop", -4.0)
	GameFX.popup("Đã áp dụng mức đồ hoạ: %s" % " · ".join(GameFX.quality_caption(q)), GameFX.FPT_GREEN, 22, 1.0)

func _on_continue_pressed() -> void:
	var sd: Node = _director()
	if sd == null:
		return
	if not bool(sd.call("continue_story")):
		_refresh_story_buttons()   # the save went bad meanwhile: hide the button
		_first_button().grab_focus()
		return
	GameFX.play_sfx("success", -2.0)
	GameFX.flash(Color.WHITE, 0.6, 0.4)

## "CỐT TRUYỆN MỚI": with a save, ask "Ghi đè bản lưu Ngày N?" first.
func _on_story_pressed() -> void:
	var info: Dictionary = _save_info()
	if info.is_empty():
		_open_creator()
		return
	GameFX.play_sfx("pop", -6.0)
	confirm_label.text = "Ghi đè bản lưu Ngày %d?" % int(info.get("day", 0))
	modal_dim.visible = true
	confirm_panel.visible = true
	guide_panel.visible = false
	settings_panel.visible = false
	var no_btn: Button = confirm_panel.find_child("ConfirmNo", true, false) as Button
	if no_btn:
		no_btn.call_deferred("grab_focus")   # keyboard reaches the confirm; "Thôi" is the safe default (review A2-R1)

func _open_creator() -> void:
	GameFX.play_sfx("success", -2.0)
	GameFX.flash(Color.WHITE, 0.6, 0.4)
	var sd: Node = _director()
	if sd:
		sd.call("open_creator")
	else:
		get_tree().change_scene_to_file("res://scenes/story/CharacterCreator.tscn")

## "CHỌN CẢNH" (plan 2026-10-26-chapter-select.md): the chapter select / gallery screen; QUAY LẠI comes back here.
func _on_chapters_pressed() -> void:
	GameFX.play_sfx("pop", -4.0)
	ChapterSelect.from_story = false
	get_tree().change_scene_to_file(ChapterSelect.SCENE)

## Thế giới mở: spawn mặc định ở BE6 (Vinhomes Grand Park), đi bộ / xe máy 5,5 km tới campus FPTU.
func _on_roam_pressed() -> void:
	GameFX.play_sfx("success", -4.0)
	GameFX.flash(Color.WHITE, 0.5, 0.4)
	StageManager.roam_spawn = null
	StageManager.go_to_roam()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_ESCAPE and modal_dim.visible:
			_hide_modals()
			get_viewport().set_input_as_handled()
