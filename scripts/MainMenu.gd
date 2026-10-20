# File: res://scripts/MainMenu.gd
# MENU CHÍNH – hiện ngay khi mở game.
#   Nền 3D: chính khuôn viên ĐH FPT thật (cùng FPTUCampusBuilder với 7 màn) + HUTECH + đường D1, camera bay chậm
#   qua 5 góc (toàn cảnh từ phía HUTECH, dolly dọc D1, sân trong + hồ sen, sân trước + cầu thang ngoài trời, flycam),
#   xe máy sinh viên chạy qua lại trên D1, nắng sớm vàng.
#   Nút: ▶ BẮT ĐẦU NGÀY MỚI (reset hành trình → Màn 1) · 📋 CHỌN MÀN (Campaign Hub có rank) · 🎮 HƯỚNG DẪN ĐIỀU KHIỂN
#        · ⚙ CÀI ĐẶT ĐỒ HOẠ (3 mức chất lượng + toàn màn hình, lưu user://settings.cfg) · ✖ THOÁT.
#   Bảng "Nhật ký hành trình" hiện kỷ lục từng màn (lưu user://progress.cfg). Điều hướng: chuột hoặc ↑↓ + Enter, [M] mở hub.
class_name MainMenu
extends Node3D

const SHOTS: Array = [
	{"from": Vector3(-30.0, 44.0, -75.0), "to": Vector3(40.0, 40.0, -88.0), "look_from": Vector3(90.0, 6.0, 55.0), "look_to": Vector3(96.0, 8.0, 50.0), "fov": 58.0, "dur": 11.0},
	{"from": Vector3(-30.0, 2.3, -9.7), "to": Vector3(70.0, 2.5, -9.7), "look_from": Vector3(60.0, 9.0, 20.0), "look_to": Vector3(150.0, 10.0, 25.0), "fov": 66.0, "dur": 11.0},
	{"from": Vector3(56.0, 2.2, 62.0), "to": Vector3(66.0, 2.6, 56.0), "look_from": Vector3(100.0, 6.0, 52.0), "look_to": Vector3(118.0, 9.0, 56.0), "fov": 68.0, "dur": 11.0},
	{"from": Vector3(78.0, 2.6, 14.0), "to": Vector3(94.0, 3.0, 15.0), "look_from": Vector3(120.0, 9.0, 19.0), "look_to": Vector3(140.0, 15.0, 21.0), "fov": 64.0, "dur": 11.0},
	{"from": Vector3(210.0, 58.0, -30.0), "to": Vector3(170.0, 70.0, -95.0), "look_from": Vector3(90.0, 0.0, 60.0), "look_to": Vector3(82.0, 0.0, 58.0), "fov": 56.0, "dur": 12.0}
]
const FADE_T: float = 0.55

@onready var cam: Camera3D = $Camera3D
@onready var world: Node3D = $World
@onready var fade_rect: ColorRect = $Fade/FadeRect
@onready var ui: CanvasLayer = $UI

var shot_idx: int = 0
var shot_t: float = 0.0
var bikes: Array[Dictionary] = []
var campus_mats: Dictionary = {}

var btn_start: Button
var btn_hub: Button
var btn_guide: Button
var btn_settings: Button
var btn_quit: Button
var modal_dim: ColorRect
var guide_panel: PanelContainer
var settings_panel: PanelContainer
var quality_buttons: Array[Button] = []
var fullscreen_check: CheckButton
var journal_rows: Dictionary = {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	GameFX.reset_all()
	_build_world()
	_build_ui()
	GameFX.upgrade_scene_visuals(self, "outdoor")
	_apply_shot(0.0)
	fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	btn_start.call_deferred("grab_focus")
	_refresh_journal()

# ===========================================================================
# NỀN 3D
# ===========================================================================
func _build_world() -> void:
	campus_mats = FPTUCampusBuilder.make_materials()
	FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": true})
	FPTUCampusBuilder.build_hutech(world, Vector3(135.0, 0.0, -26.0), campus_mats)
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
		var bike: Node3D = FPTUCampusBuilder.build_motorbike(world, Vector3(float(sp[3]), 0.0, float(sp[0])), -90.0 * dir_sign, paint, campus_mats)
		_add_rider(bike, rng)
		bikes.append({"node": bike, "dir": dir_sign, "speed": float(sp[2]), "z": float(sp[0])})

func _add_rider(bike: Node3D, rng: RandomNumberGenerator) -> void:
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = [Color("#F37021"), Color("#2C3E50"), Color("#3498DB"), Color("#F37021")][rng.randi() % 4]
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.17
	bm.height = 0.66
	body.mesh = bm
	body.material_override = shirt
	body.position = Vector3(0.0, 1.08, 0.12)
	bike.add_child(body)
	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.15
	hm.height = 0.3
	helmet.mesh = hm
	var mh := StandardMaterial3D.new()
	mh.albedo_color = [Color("#F1C40F"), Color("#E74C3C"), Color("#ECF0F1")][rng.randi() % 3]
	helmet.material_override = mh
	helmet.position = Vector3(0.0, 1.56, 0.06)
	bike.add_child(helmet)

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
	b.custom_minimum_size = Vector2(400, 50)
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
	col.add_theme_constant_override("separation", 8)
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
	var tagline: Label = GameFX.make_label("Một ngày của sinh viên áo cam: đua xe tới cổng trước 07:30, giành ô đỗ, điểm danh FAP, thi Vovinam, bưng khay căn tin, đánh boss Capstone 23:59… và bắt tool cheat EOS.", 13, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(440, 0)
	col.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	col.add_child(spacer)

	btn_start = _menu_button("▶   BẮT ĐẦU NGÀY MỚI  (07:05 AM – Màn 1)", GameFX.FPT_ORANGE)
	btn_start.pressed.connect(_on_start_pressed)
	col.add_child(btn_start)
	btn_hub = _menu_button("📋   CHỌN MÀN CHƠI  (Campaign Hub · rank)  [M]", Color("#F1C40F"))
	btn_hub.pressed.connect(_on_hub_pressed)
	col.add_child(btn_hub)
	btn_guide = _menu_button("🎮   HƯỚNG DẪN ĐIỀU KHIỂN", Color("#3498DB"))
	btn_guide.pressed.connect(_show_guide)
	col.add_child(btn_guide)
	btn_settings = _menu_button("⚙   CÀI ĐẶT ĐỒ HOẠ", Color("#2ECC71"))
	btn_settings.pressed.connect(_show_settings)
	col.add_child(btn_settings)
	btn_quit = _menu_button("✖   THOÁT GAME", Color("#E74C3C"))
	btn_quit.pressed.connect(_on_quit_pressed)
	col.add_child(btn_quit)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer2)
	var footer: Label = GameFX.make_label("↑↓ chọn · Enter xác nhận · Godot 4\nẢnh tham chiếu & texture mặt tiền: ảnh chụp thật, không dùng AI tạo ảnh", 11, Color("#95A5A6"), HORIZONTAL_ALIGNMENT_LEFT)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size = Vector2(440, 0)
	col.add_child(footer)

	# Nhật ký hành trình (kỷ lục từng màn) – góc dưới phải
	var journal: PanelContainer = GameFX.anchored_panel(ui, Control.PRESET_BOTTOM_RIGHT, Vector2(380, 0), 28, GameFX.FPT_YELLOW)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 4)
	journal.add_child(jv)
	var jhead: Label = GameFX.make_label("📒 NHẬT KÝ HÀNH TRÌNH – KỶ LỤC", 15, GameFX.FPT_YELLOW)
	jhead.autowrap_mode = TextServer.AUTOWRAP_OFF
	jv.add_child(jhead)
	var sm: Node = StageManager
	for sid: int in sm.stage_info.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		jv.add_child(row)
		var full: String = String(sm.stage_info[sid]["title"])
		var short_t: String = full.get_slice("] ", 1) if full.contains("] ") else full
		if short_t.length() > 34:
			short_t = short_t.substr(0, 33) + "…"
		var name_lbl: Label = GameFX.make_label(short_t, 12, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_lbl)
		var best_lbl: Label = GameFX.make_label("—", 12, Color("#2ECC71"), HORIZONTAL_ALIGNMENT_RIGHT)
		best_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		best_lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(best_lbl)
		journal_rows[sid] = best_lbl

	# Góc trên phải: phiên bản
	var ver: PanelContainer = GameFX.anchored_panel(ui, Control.PRESET_TOP_RIGHT, Vector2(0, 0), 20, Color("#7F8C8D"))
	var ver_lbl: Label = GameFX.make_label("v3 · campus dựng theo ảnh flycam thật · [M] Campaign Hub", 11, Color("#BDC3C7"))
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
	v.add_child(GameFX.make_label("🎮 HƯỚNG DẪN ĐIỀU KHIỂN", 24, Color("#3498DB")))
	var lines: Array = StageManager.CONTROLS_GUIDE
	for ln: Array in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		var k: Label = GameFX.make_label(String(ln[0]), 14, GameFX.FPT_YELLOW, HORIZONTAL_ALIGNMENT_LEFT)
		k.custom_minimum_size = Vector2(190, 0)
		row.add_child(k)
		var d: Label = GameFX.make_label(String(ln[1]), 13, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
	var close := _menu_button("✔   ĐÃ HIỂU, ĐÓNG  [ESC]", Color("#3498DB"))
	close.custom_minimum_size = Vector2(320, 46)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.pressed.connect(_hide_modals)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(close)
	v.add_child(hb)
	return panel

func _build_settings_panel() -> PanelContainer:
	var panel: PanelContainer = _center_modal(Vector2(760, 0), Color("#2ECC71"))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 24)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	v.add_child(GameFX.make_label("⚙ CÀI ĐẶT ĐỒ HOẠ", 24, Color("#2ECC71")))
	var desc: Label = GameFX.make_label("Game mặc định chạy mức CAO (SDFGI, SSIL, phản xạ màn hình, sương thể tích, bóng mềm 8K). Máy yếu chọn mức thấp hơn – áp dụng ngay và lưu cho lần sau.", 13, Color("#BDC3C7"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var qrow := HBoxContainer.new()
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	qrow.add_theme_constant_override("separation", 10)
	v.add_child(qrow)
	var names: Array = ["🟢 THẤP\nkhông GI, bóng cơ bản", "🟡 TRUNG BÌNH\nSSAO + phản xạ, không SDFGI", "🔴 CAO (mặc định)\nSDFGI + SSIL + sương thể tích"]
	quality_buttons.clear()
	for q: int in range(3):
		var b := _menu_button(String(names[q]), Color("#2ECC71"))
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
	v.add_child(GameFX.make_label("🔈 ÂM LƯỢNG", 18, Color("#2ECC71")))
	GameFX.build_audio_settings(v)
	var close := _menu_button("✔   LƯU & ĐÓNG  [ESC]", Color("#2ECC71"))
	close.custom_minimum_size = Vector2(320, 46)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.pressed.connect(_hide_modals)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(close)
	v.add_child(hb)
	_refresh_quality_buttons()
	return panel

func _refresh_quality_buttons() -> void:
	for q: int in range(quality_buttons.size()):
		var b: Button = quality_buttons[q]
		var active: bool = q == GameFX.visual_quality
		b.add_theme_color_override("font_color", GameFX.FPT_YELLOW if active else Color("#F4F5F6"))
		b.add_theme_stylebox_override("normal", GameFX.make_panel_style(GameFX.FPT_YELLOW if active else Color(0.18, 0.8, 0.44, 0.45), Color(0.12, 0.1, 0.03, 0.96) if active else Color(0.05, 0.07, 0.12, 0.86), 10))

func _refresh_journal() -> void:
	for sid: int in journal_rows.keys():
		var lbl: Label = journal_rows[sid]
		lbl.text = StageManager.get_best_text(sid)

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
	modal_dim.visible = true
	settings_panel.visible = true
	guide_panel.visible = false

func _hide_modals() -> void:
	modal_dim.visible = false
	guide_panel.visible = false
	settings_panel.visible = false
	btn_start.grab_focus()

func _set_quality(q: int) -> void:
	GameFX.set_visual_quality(q)
	_refresh_quality_buttons()
	GameFX.upgrade_scene_visuals(self, "outdoor")
	GameFX.play_sfx("pop", -4.0)
	GameFX.popup("Đã áp dụng mức đồ hoạ: %s" % ["THẤP", "TRUNG BÌNH", "CAO"][clampi(q, 0, 2)], GameFX.FPT_GREEN, 22, 1.0)

func _on_start_pressed() -> void:
	GameFX.play_sfx("success", -2.0)
	GameFX.flash(Color.WHITE, 0.6, 0.4)
	StageManager.start_new_day()

func _on_hub_pressed() -> void:
	GameFX.play_sfx("pop", -6.0)
	StageManager.open_stage_select()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_ESCAPE and modal_dim.visible:
			_hide_modals()
			get_viewport().set_input_as_handled()
