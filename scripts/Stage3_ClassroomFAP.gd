# File: res://scripts/Stage3_ClassroomFAP.gd
# MÀN 3: ROLL CALL FAP & SINH TỒN PHÒNG HỌC 16°C
#   Pha 1 (45s): Mã FAP 6 ký tự ngẫu nhiên trên màn chiếu. Wi-Fi lag làm mã nhòe từng ký tự (phải đoán),
#                bật 4G [TAB] mất 5s nhưng mã rõ. Giảng viên đổi mã sau 20s. Sai 3 lần = ABSENT.
#   Pha 2 (60s): Juggle nhiều việc: giữ nhịp tỉnh táo [SPACE] đúng beat, cà phê [C] có hạn, bụng đói kêu
#                làm giảng viên để ý, ăn bánh bao lén [B], bị gọi tên gõ đáp án ngắn, úp điện thoại [F] kịp lúc.
class_name Stage3_ClassroomFAP
extends Node3D

@onready var timer_label: Label = $HUD/TopBar/TimerPanel/TimerLabel
@onready var mission_label: Label = $HUD/TopBar/MissionPanel/MissionLabel
@onready var sleep_panel: PanelContainer = $HUD/SleepPanel
@onready var sleep_vbox: VBoxContainer = $HUD/SleepPanel/VBox
@onready var sleep_bar: ProgressBar = $HUD/SleepPanel/VBox/SleepBar
@onready var coffee_btn: Button = $HUD/SleepPanel/VBox/CoffeeButton

@onready var fap_panel: PanelContainer = $HUD/CenterModals/FAPModal
@onready var fap_vbox: VBoxContainer = $HUD/CenterModals/FAPModal/Margin/VBox
@onready var wifi_status_lbl: Label = $HUD/CenterModals/FAPModal/Margin/VBox/StatusLabel
@onready var switch_4g_btn: Button = $HUD/CenterModals/FAPModal/Margin/VBox/Switch4GButton
@onready var code_input: LineEdit = $HUD/CenterModals/FAPModal/Margin/VBox/CodeInput
@onready var submit_btn: Button = $HUD/CenterModals/FAPModal/Margin/VBox/SubmitButton

@onready var quiz_panel: PanelContainer = $HUD/CenterModals/QuizModal
@onready var quiz_vbox: VBoxContainer = $HUD/CenterModals/QuizModal/Margin/VBox
@onready var quiz_question: Label = $HUD/CenterModals/QuizModal/Margin/VBox/QuestionLabel
@onready var opt_a_btn: Button = $HUD/CenterModals/QuizModal/Margin/VBox/OptionA
@onready var opt_b_btn: Button = $HUD/CenterModals/QuizModal/Margin/VBox/OptionB
@onready var opt_c_btn: Button = $HUD/CenterModals/QuizModal/Margin/VBox/OptionC

@onready var modal_overlay: ColorRect = $HUD/ModalOverlay
@onready var modal_title: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/TitleLabel
@onready var modal_sub: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/SubLabel
@onready var next_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/NextButton
@onready var menu_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/MenuButton
@onready var retry_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/RetryButton

@onready var projector_screen: MeshInstance3D = $Room/ProjectorScreen
@onready var hud: CanvasLayer = $HUD

enum Phase { FAP, SURVIVE, DONE }

const FAP_TIME: float = 45.0
const SURVIVE_TIME: float = 60.0
const CODE_CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const NOISE_CHARS: String = "▒#?*%&▓"
const BEAT_PERIOD: float = 0.8
const BEAT_WINDOW: float = 0.12

const QUIZ_POOL: Array = [
	["Trong SOLID, chữ 'S' viết tắt của nguyên lý nào? (1 từ tiếng Anh)", ["single", "single responsibility", "srp", "single responsibility principle"]],
	["HTTP status 404 nghĩa là gì? (tiếng Anh)", ["not found", "notfound", "404 not found", "page not found"]],
	["Lệnh Git nào lấy code mới nhất từ remote về và merge luôn?", ["pull", "git pull"]],
	["Cấu trúc dữ liệu LIFO (vào sau ra trước) tên là gì?", ["stack"]],
	["Độ phức tạp thời gian của Binary Search?", ["o(log n)", "ologn", "o(logn)", "log n", "logn", "o(log(n))"]],
	["Từ khóa khai báo hằng số trong Java?", ["final"]],
	["Câu lệnh SQL để lấy dữ liệu từ bảng?", ["select"]],
	["Hệ thống điểm danh / xem điểm của FPTU viết tắt là gì?", ["fap"]],
	["Trong OOP, tính chất 'che giấu dữ liệu' gọi là gì? (tiếng Anh)", ["encapsulation"]],
	["Port mặc định của HTTP là số mấy?", ["80"]]
]

var phase: int = Phase.FAP
var time_left: float = FAP_TIME
var elapsed_total: float = 0.0
var is_stage_ended: bool = false

# ----- Pha 1: FAP -----
var real_code: String = ""
var displayed_code: String = ""
var scramble_timer: float = 0.0
var code_change_timer: float = 20.0
var code_changes: int = 0
var strikes: int = 0
var is_using_4g: bool = false
var switching_4g_timer: float = -1.0
var submitting_timer: float = -1.0
var pending_code: String = ""
var input_lock_timer: float = 0.0
var code_label3d: Label3D
var switch_bar: ProgressBar
var projector_hint: Label

# ----- Pha 2: Sinh tồn -----
var sleepiness: float = 15.0
var hunger: float = 20.0
var attention: float = 0.0
var beat_phase: float = 0.0
var beat_hits: int = 0
var beat_misses: int = 0
var coffee_left: int = 3
var banhbao_left: int = 2
var lecturer_watching: bool = false
var watch_timer: float = 4.0
var growl_timer: float = 4.0
var event_schedule: Array[Dictionary] = []
var quiz_active: bool = false
var quiz_timer: float = 0.0
var quiz_answers: Array = []
var quiz_count: int = 0
var quiz_correct: int = 0
var phone_active: bool = false
var phone_timer: float = 0.0
var phone_saved: bool = true
var phone_confiscated: bool = false

var hunger_bar: ProgressBar
var attention_bar: ProgressBar
var watch_label: Label
var banhbao_btn: Button
var beat_panel: PanelContainer
var beat_ring: Control
var beat_feedback: Label
var answer_input: LineEdit
var quiz_bar: ProgressBar
var lecturer: Node3D
var lecturer_bubble: Label3D
var phone_mesh: MeshInstance3D
var phone_mat: StandardMaterial3D
var event_prompt: Label

# Vòng nhịp tim vẽ bằng _draw
class BeatRing extends Control:
	var phase_ratio: float = 0.0
	var flash: float = 0.0
	var good: bool = true
	func _ready() -> void:
		custom_minimum_size = Vector2(140, 140)
	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta * 3.0)
		queue_redraw()
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r_target: float = 26.0
		var ring_col: Color = Color("#F1C40F")
		if flash > 0.0:
			ring_col = (Color("#2ECC71") if good else Color("#E74C3C")).lerp(Color("#F1C40F"), 1.0 - flash)
		draw_circle(c, r_target + 4.0, Color(0.1, 0.12, 0.18, 0.9))
		draw_arc(c, r_target, 0.0, TAU, 48, ring_col, 4.0, true)
		var r_outer: float = r_target + (1.0 - phase_ratio) * 48.0
		draw_arc(c, r_outer, 0.0, TAU, 56, Color(0.9, 0.95, 1.0, 0.85), 2.5, true)
		draw_circle(c, 6.0 + flash * 6.0, ring_col)

func _ready() -> void:
	modal_overlay.visible = false
	quiz_panel.visible = false
	fap_panel.visible = true
	sleep_panel.visible = true

	_build_lab_402_world()
	_apply_projector_texture()
	_build_room_extras()
	_build_fap_ui()
	_build_survive_ui()

	switch_4g_btn.pressed.connect(_on_switch_4g_pressed)
	submit_btn.pressed.connect(_on_submit_fap_pressed)
	code_input.text_submitted.connect(func(_t: String) -> void: _on_submit_fap_pressed())
	coffee_btn.pressed.connect(_on_coffee_pressed)
	opt_a_btn.visible = false
	opt_b_btn.visible = false
	opt_c_btn.visible = false
	next_btn.pressed.connect(_on_next_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)

	coffee_left = 3 + StageManager.item_count("coffee")
	banhbao_left = 2 + StageManager.item_count("banh_bao")
	_refresh_consumables()
	GameFX.disable_button_focus(hud)
	GameFX.upgrade_scene_visuals(self, "indoor")

	_generate_code()
	mission_label.text = "ĐỌC MÃ FAP TRÊN MÀN CHIẾU (WI-FI LAG LÀM NHÒE) HOẶC BẬT 4G [TAB] 5s – NHẬP ĐÚNG MÃ TRƯỚC 45s!"
	code_input.editable = true
	code_input.placeholder_text = "Gõ 6 ký tự mã FAP rồi Enter (đoán cũng được!)"
	submit_btn.disabled = false
	code_input.grab_focus()

# ===========================================================================
# DỰNG THÊM 3D: MÃ TRÊN MÀN CHIẾU, GIẢNG VIÊN, ĐIỆN THOẠI
# ===========================================================================
func _apply_projector_texture() -> void:
	var path: String = "res://assets/textures/fap_portal_screen.png"
	var global_p: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(global_p)
		if img:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.emission_enabled = true
			mat.emission_texture = tex
			mat.emission_energy_multiplier = 0.85
			projector_screen.material_override = mat

## LAB 402 THẬT: campus dựng xoay 180° quanh gốc để phòng (cánh phải, module 0, lầu 4) nằm đúng gốc toạ độ;
## cửa sổ phía +X nhìn xuống sân trong (hồ sen, vòng nhà), phía +Z nhìn ra sân trước / D1 / HUTECH.
func _build_lab_402_world() -> void:
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var c: Vector3 = FPTUCampusBuilder.lab402_room_center()
	var world := Node3D.new()
	world.name = "CampusWorld"
	world.position = Vector3(c.x, -c.y, c.z)
	world.rotation_degrees.y = 180.0
	add_child(world)
	FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": true})
	FPTUCampusBuilder.build_hutech(world, Vector3(135.0, 0.0, -26.0), cm)
	FPTUCampusBuilder.build_d1_road_piece(world, -13.0, -80.0, 300.0, cm, 0.0)
	FPTUCampusBuilder.build_room_interior($Room, FPTUCampusBuilder.lab402_room_size(), cm, {
		"windows": ["+x", "+z"], "door": "+z", "door_x": 0.86, "board_side": "-x", "name": "LAB 402"
	})
	# Bàn giảng viên (quay mặt xuống lớp) + 2 hàng bàn máy, bàn giữa hàng sau là của người chơi
	FPTUCampusBuilder.build_lab_desk($Room, Vector3(0.0, 0.0, -3.9), cm, 1, 180.0, "chair_blue", 2.4)
	for z: float in [-1.2, 1.8]:
		for x: float in [-4.5, 0.0, 4.5]:
			FPTUCampusBuilder.build_lab_desk($Room, Vector3(x, 0.0, z), cm, 2, 0.0, "chair_blue", 3.2)
	# Nắng xiên qua cửa sổ phía sân trong & phía D1
	$DirectionalLight3D.rotation_degrees = Vector3(-38.0, 62.0, 0.0)

func _build_room_extras() -> void:
	code_label3d = Label3D.new()
	code_label3d.text = "------"
	code_label3d.font_size = 96
	code_label3d.outline_size = 16
	code_label3d.modulate = Color("#F1C40F")
	code_label3d.outline_modulate = Color(0, 0, 0, 0.9)
	code_label3d.position = Vector3(0.0, 2.0, -5.5)
	$Room.add_child(code_label3d)

	var code_title := Label3D.new()
	code_title.text = "FAP ROLL CALL CODE – SLOT 1"
	code_title.font_size = 30
	code_title.outline_size = 8
	code_title.modulate = Color.WHITE
	code_title.position = Vector3(0.0, 2.85, -5.5)
	$Room.add_child(code_title)

	# Giảng viên đứng cạnh bàn
	lecturer = Node3D.new()
	lecturer.position = Vector3(2.6, 0.0, -4.0)
	$Room.add_child(lecturer)
	var mat_shirt := StandardMaterial3D.new()
	mat_shirt.albedo_color = Color("#2C3E50")
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.35
	body.mesh = cm
	body.material_override = mat_shirt
	body.position = Vector3(0.0, 0.95, 0.0)
	lecturer.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.18
	hm.height = 0.36
	head.mesh = hm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color("#FFCCAA")
	head.material_override = ms
	head.position = Vector3(0.0, 1.8, 0.0)
	lecturer.add_child(head)
	var glasses := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.3, 0.06, 0.04)
	glasses.mesh = gm
	var mg := StandardMaterial3D.new()
	mg.albedo_color = Color("#111111")
	glasses.material_override = mg
	glasses.position = Vector3(0.0, 1.82, 0.17)
	lecturer.add_child(glasses)
	lecturer_bubble = Label3D.new()
	lecturer_bubble.text = "🎓 Các em nhập mã nhanh lên!"
	lecturer_bubble.font_size = 34
	lecturer_bubble.outline_size = 10
	lecturer_bubble.modulate = Color.WHITE
	lecturer_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lecturer_bubble.position = Vector3(0.0, 2.5, 0.0)
	lecturer.add_child(lecturer_bubble)

	# Điện thoại trên bàn sinh viên
	phone_mesh = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.16, 0.02, 0.32)
	phone_mesh.mesh = pm
	phone_mat = StandardMaterial3D.new()
	phone_mat.albedo_color = Color("#74B9FF")
	phone_mat.emission_enabled = true
	phone_mat.emission = Color("#74B9FF") * 1.2
	phone_mesh.material_override = phone_mat
	phone_mesh.position = Vector3(0.95, 0.78, 2.0)
	$Room.add_child(phone_mesh)

	# Bạn bè áo cam ngồi ở ghế các bàn máy (trừ ghế của người chơi)
	var mat_orange := StandardMaterial3D.new()
	mat_orange.albedo_color = Color("#F37021")
	var mat_skin2 := StandardMaterial3D.new()
	mat_skin2.albedo_color = Color("#FFCCAA")
	var seats: Array = [
		Vector2(-5.3, 2.55), Vector2(-3.7, 2.55), Vector2(3.7, 2.55), Vector2(5.3, 2.55),
		Vector2(-5.3, -0.45), Vector2(-3.7, -0.45), Vector2(-0.8, -0.45), Vector2(0.8, -0.45), Vector2(3.7, -0.45), Vector2(5.3, -0.45)
	]
	for sp: Vector2 in seats:
		var npc := MeshInstance3D.new()
		var nm := CapsuleMesh.new()
		nm.radius = 0.22
		nm.height = 0.9
		npc.mesh = nm
		npc.material_override = mat_orange
		npc.position = Vector3(sp.x, 0.85, sp.y)
		$Room.add_child(npc)
		var nh := MeshInstance3D.new()
		var nhm := SphereMesh.new()
		nhm.radius = 0.15
		nhm.height = 0.3
		nh.mesh = nhm
		nh.material_override = mat_skin2
		nh.position = Vector3(sp.x, 1.42, sp.y)
		$Room.add_child(nh)

# ===========================================================================
# UI
# ===========================================================================
func _build_fap_ui() -> void:
	projector_hint = GameFX.make_label("📺 MÃ TRÊN MÀN CHIẾU: ------", 26, Color("#F1C40F"))
	fap_vbox.add_child(projector_hint)
	fap_vbox.move_child(projector_hint, 1)
	switch_bar = GameFX.make_bar(0.0, Color("#0984E3"), 12)
	switch_bar.visible = false
	fap_vbox.add_child(switch_bar)
	fap_vbox.move_child(switch_bar, 4)
	wifi_status_lbl.text = "📶 Wi-Fi FPTU_Student: 1 vạch, mã bị nhòe. Đoán cho nhanh, hoặc [TAB] bật 4G (mất 5s)."
	switch_4g_btn.text = "📶 BẬT 4G VIETTEL [TAB] – MẤT 5s CHUYỂN MẠNG, MÃ RÕ NÉT"
	submit_btn.text = "✅ GỬI MÃ ĐIỂM DANH [ENTER] (sai 3 lần = ABSENT)"

func _build_survive_ui() -> void:
	sleep_bar.value = sleepiness
	GameFX.set_bar_color(sleep_bar, Color("#74B9FF"))
	coffee_btn.text = "☕ CÀ PHÊ 7-ELEVEN [C] x%d (-15 buồn ngủ)" % coffee_left

	var hl := GameFX.make_label("🍜 ĐÓI BỤNG (>70 là bụng kêu ục ục):", 14, Color("#FDCB6E"), HORIZONTAL_ALIGNMENT_LEFT)
	sleep_vbox.add_child(hl)
	hunger_bar = GameFX.make_bar(hunger, Color("#FDCB6E"), 18)
	sleep_vbox.add_child(hunger_bar)
	banhbao_btn = Button.new()
	banhbao_btn.text = "🥟 ĂN LÉN BÁNH BAO [B] x%d (-40 đói, cẩn thận cô nhìn!)" % banhbao_left
	banhbao_btn.custom_minimum_size = Vector2(0, 36)
	banhbao_btn.pressed.connect(_on_banhbao_pressed)
	sleep_vbox.add_child(banhbao_btn)

	var al := GameFX.make_label("👀 GIẢNG VIÊN ĐỂ Ý (100 = mời ra khỏi lớp):", 14, Color("#FF7675"), HORIZONTAL_ALIGNMENT_LEFT)
	sleep_vbox.add_child(al)
	attention_bar = GameFX.make_bar(0.0, Color("#FF7675"), 18)
	sleep_vbox.add_child(attention_bar)
	watch_label = GameFX.make_label("📖 Giảng viên đang nhìn slide", 14, Color("#BDC3C7"), HORIZONTAL_ALIGNMENT_LEFT)
	sleep_vbox.add_child(watch_label)

	beat_panel = GameFX.anchored_panel(hud, Control.PRESET_CENTER_BOTTOM, Vector2(460, 0), 24, Color("#F1C40F"))
	beat_panel.visible = false
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	beat_panel.add_child(vb)
	vb.add_child(GameFX.make_label("💓 GIỮ NHỊP TỈNH TÁO: BẤM [SPACE] ĐÚNG LÚC VÒNG NGOÀI CHẠM VÒNG VÀNG", 14, Color("#F1C40F")))
	var center := CenterContainer.new()
	vb.add_child(center)
	beat_ring = BeatRing.new()
	center.add_child(beat_ring)
	beat_feedback = GameFX.make_label("", 18, Color("#2ECC71"))
	vb.add_child(beat_feedback)

	event_prompt = GameFX.make_label("", 30, Color("#FF7675"))
	var ep_panel: PanelContainer = GameFX.anchored_panel(hud, Control.PRESET_CENTER_TOP, Vector2(760, 0), 92, Color("#FF7675"))
	ep_panel.add_child(event_prompt)
	ep_panel.visible = false
	event_prompt.set_meta("panel", ep_panel)

	# Quiz: ô trả lời + thanh thời gian
	answer_input = LineEdit.new()
	answer_input.placeholder_text = "Gõ đáp án ngắn rồi Enter (không phân biệt hoa thường)..."
	answer_input.custom_minimum_size = Vector2(0, 44)
	answer_input.add_theme_font_size_override("font_size", 18)
	answer_input.text_submitted.connect(_on_quiz_submitted)
	quiz_vbox.add_child(answer_input)
	quiz_bar = GameFX.make_bar(100.0, Color("#FF7675"), 12)
	quiz_vbox.add_child(quiz_bar)

func _set_event_prompt(text: String, color: Color = Color("#FF7675")) -> void:
	var panel: PanelContainer = event_prompt.get_meta("panel")
	if text == "":
		panel.visible = false
		return
	panel.visible = true
	event_prompt.text = text
	event_prompt.add_theme_color_override("font_color", color)

func _refresh_consumables() -> void:
	coffee_btn.text = "☕ CÀ PHÊ 7-ELEVEN [C] x%d (-15 buồn ngủ)" % coffee_left
	if banhbao_btn:
		banhbao_btn.text = "🥟 ĂN LÉN BÁNH BAO [B] x%d (-40 đói, cẩn thận cô nhìn!)" % banhbao_left

# ===========================================================================
# INPUT
# ===========================================================================
func _input(event: InputEvent) -> void:
	# TAB phải bắt ở _input vì LineEdit đang focus sẽ nuốt TAB (focus traversal) trước _unhandled_input
	if is_stage_ended or phase != Phase.FAP:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.physical_keycode == KEY_TAB:
		if not is_using_4g and switching_4g_timer < 0.0:
			_on_switch_4g_pressed()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_stage_ended:
		return
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var key: int = event.physical_keycode
	if phase == Phase.SURVIVE:
		match key:
			KEY_SPACE:
				if not quiz_active:
					_on_beat_press()
			KEY_C:
				_on_coffee_pressed()
			KEY_B:
				_on_banhbao_pressed()
			KEY_F:
				_on_phone_flip()

# ===========================================================================
# VÒNG LẶP
# ===========================================================================
func _process(delta: float) -> void:
	if is_stage_ended:
		return
	time_left -= delta
	elapsed_total += delta
	_update_clock()

	if phase == Phase.FAP:
		_process_fap(delta)
		if time_left <= 0.0:
			_fail_stage("HẾT GIỜ ĐIỂM DANH! FAP ĐÓNG CỔNG, BẠN NHẬN [A] - ABSENT. Wi-Fi trường thắng 1-0.")
	elif phase == Phase.SURVIVE:
		_process_survive(delta)

func _update_clock() -> void:
	var game_sec: int = 30 * 60 + int(elapsed_total)
	var label: String = "FAP" if phase == Phase.FAP else "SỐNG SÓT"
	timer_label.text = "07:%02d:%02d · %s %ds" % [game_sec / 60, game_sec % 60, label, int(ceil(maxf(0.0, time_left)))]
	if time_left < 8.0 and phase == Phase.FAP:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		timer_label.modulate = Color(1.0, 0.35 + pulse * 0.3, 0.35)
	else:
		timer_label.modulate = Color.WHITE

# ===========================================================================
# PHA 1: FAP
# ===========================================================================
func _generate_code() -> void:
	var s: String = ""
	for i: int in range(6):
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	real_code = s
	displayed_code = s
	scramble_timer = 0.0

func _process_fap(delta: float) -> void:
	# Giảng viên đổi mã mỗi 20s
	code_change_timer -= delta
	if code_change_timer <= 0.0:
		code_change_timer = 20.0
		code_changes += 1
		_generate_code()
		lecturer_bubble.text = "🎓 Lộ mã lên group lớp rồi! ĐỔI MÃ!"
		GameFX.play_sfx("alarm", -4.0)
		GameFX.flash(Color("#F1C40F"), 0.25, 0.3)
		GameFX.popup("⚠️ GIẢNG VIÊN ĐỔI MÃ FAP! ĐỌC LẠI MÀN CHIẾU!", Color("#F1C40F"), 28, 1.5)
		var tw := create_tween()
		tw.tween_property(code_label3d, "scale", Vector3(1.3, 1.3, 1.3), 0.15)
		tw.tween_property(code_label3d, "scale", Vector3.ONE, 0.2)

	# Hiển thị mã: 4G rõ nét, Wi-Fi nhòe từng ký tự
	if is_using_4g:
		displayed_code = real_code
	else:
		scramble_timer -= delta
		if scramble_timer <= 0.0:
			scramble_timer = 0.35
			var s: String = ""
			for i: int in range(real_code.length()):
				if randf() < 0.55:
					s += NOISE_CHARS[randi() % NOISE_CHARS.length()]
				else:
					s += real_code[i]
			displayed_code = s
	code_label3d.text = displayed_code
	code_label3d.modulate = Color("#F1C40F") if is_using_4g else Color("#F1C40F").lerp(Color("#B2BEC3"), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
	projector_hint.text = "📺 MÃ TRÊN MÀN CHIẾU: %s   %s" % [displayed_code, "" if is_using_4g else "⟳ Wi-Fi đang tải..."]

	# Đang chuyển 4G
	if switching_4g_timer >= 0.0:
		switching_4g_timer -= delta
		switch_bar.value = (1.0 - switching_4g_timer / 5.0) * 100.0
		wifi_status_lbl.text = "📶 Đang chuyển sang 4G Viettel... %.1fs (tạm thời không gửi được)" % maxf(0.0, switching_4g_timer)
		if switching_4g_timer <= 0.0:
			switching_4g_timer = -1.0
			is_using_4g = true
			switch_bar.visible = false
			switch_4g_btn.disabled = true
			switch_4g_btn.text = "📶 4G ĐÃ BẬT – MÃ RÕ NÉT"
			wifi_status_lbl.text = "✅ 4G ỔN ĐỊNH! Mã rõ nét trên màn chiếu, gửi là nhận ngay."
			wifi_status_lbl.add_theme_color_override("font_color", Color("#2ECC71"))
			code_input.editable = true
			submit_btn.disabled = false
			code_input.grab_focus()
			GameFX.play_sfx("success", -4.0)

	# Đang gửi qua Wi-Fi lag
	if submitting_timer >= 0.0:
		submitting_timer -= delta
		wifi_status_lbl.text = "⏳ Đang gửi mã '%s' qua Wi-Fi... (%.1fs) quay vòng tròn..." % [pending_code, maxf(0.0, submitting_timer)]
		if submitting_timer <= 0.0:
			submitting_timer = -1.0
			if randf() < 0.3:
				wifi_status_lbl.text = "❌ REQUEST TIMEOUT! Wi-Fi FPTU_Student rớt mạng. Gửi lại hoặc bật 4G [TAB]!"
				wifi_status_lbl.add_theme_color_override("font_color", Color("#E74C3C"))
				GameFX.play_sfx("error", -4.0)
				code_input.editable = true
				submit_btn.disabled = false
				code_input.grab_focus()
			else:
				_evaluate_code(pending_code)

	if input_lock_timer > 0.0:
		input_lock_timer -= delta
		if input_lock_timer <= 0.0 and switching_4g_timer < 0.0 and submitting_timer < 0.0:
			code_input.editable = true
			submit_btn.disabled = false
			code_input.grab_focus()

func _on_switch_4g_pressed() -> void:
	if is_using_4g or switching_4g_timer >= 0.0 or phase != Phase.FAP:
		return
	switching_4g_timer = 5.0
	switch_bar.visible = true
	switch_bar.value = 0.0
	code_input.editable = false
	submit_btn.disabled = true
	switch_4g_btn.disabled = true
	GameFX.play_sfx("beep", -6.0)
	mission_label.text = "ĐANG CHUYỂN 4G (5s)... TRANH THỦ NHÌN MÀN CHIẾU NHỚ MÃ!"

func _on_submit_fap_pressed() -> void:
	if phase != Phase.FAP or is_stage_ended:
		return
	if not code_input.editable or submitting_timer >= 0.0 or switching_4g_timer >= 0.0:
		return
	var entered: String = code_input.text.strip_edges().to_upper()
	if entered.length() < 6:
		wifi_status_lbl.text = "⚠️ Mã FAP có đúng 6 ký tự! Bạn mới gõ %d." % entered.length()
		wifi_status_lbl.add_theme_color_override("font_color", Color("#F1C40F"))
		GameFX.play_sfx("error", -8.0)
		return
	if is_using_4g:
		_evaluate_code(entered)
	else:
		pending_code = entered
		submitting_timer = 1.8
		code_input.editable = false
		submit_btn.disabled = true
		GameFX.play_sfx("tick", -6.0)

func _evaluate_code(entered: String) -> void:
	if entered == real_code:
		_fap_success()
		return
	strikes += 1
	GameFX.play_sfx("error")
	GameFX.shake(0.25)
	GameFX.flash(Color("#E74C3C"), 0.3, 0.3)
	if strikes >= 3:
		_fail_stage("SAI MÃ 3 LẦN! FAP KHÓA ĐIỂM DANH → [A] ABSENT. Lần sau bật 4G sớm hơn nhé!")
		return
	var hint: String = ""
	var correct_pos: int = 0
	for i: int in range(mini(entered.length(), real_code.length())):
		if entered[i] == real_code[i]:
			correct_pos += 1
	hint = " (%d/6 ký tự đúng vị trí)" % correct_pos
	wifi_status_lbl.text = "❌ SAI MÃ LẦN %d/3!%s Khóa 2s rồi thử lại." % [strikes, hint]
	wifi_status_lbl.add_theme_color_override("font_color", Color("#E74C3C"))
	lecturer_bubble.text = "🎓 Nhập sai nữa là tôi điểm danh tay đó!"
	input_lock_timer = 2.0
	code_input.editable = false
	submit_btn.disabled = true
	code_input.text = ""

func _fap_success() -> void:
	phase = Phase.SURVIVE
	time_left = SURVIVE_TIME
	fap_panel.visible = false
	beat_panel.visible = true
	GameFX.play_sfx("success")
	GameFX.flash(Color("#2ECC71"), 0.35, 0.4)
	GameFX.popup("✅ [P] PRESENT! Giờ là 90 phút sinh tồn trong phòng 16°C...", Color("#2ECC71"), 30, 2.0)
	mission_label.text = "SỐNG SÓT 60s: [SPACE] ĐÚNG NHỊP CHỐNG NGỦ · [C] CÀ PHÊ · [B] BÁNH BAO LÉN · [F] ÚP ĐIỆN THOẠI KHI CÔ XUỐNG"
	lecturer_bubble.text = "🎓 Điểm danh xong rồi, vào bài nào!"
	code_label3d.text = "SLIDE 1/120: OOP"
	code_label3d.font_size = 120
	# Lịch sự kiện bất ngờ (tính theo giây đã trôi của pha 2)
	event_schedule = [
		{"t": randf_range(11.0, 15.0), "type": "quiz", "done": false},
		{"t": randf_range(24.0, 30.0), "type": "phone", "done": false},
		{"t": randf_range(38.0, 44.0), "type": "quiz", "done": false},
		{"t": randf_range(50.0, 54.0), "type": "phone", "done": false}
	]
	code_input.release_focus()

# ===========================================================================
# PHA 2: SINH TỒN 16°C
# ===========================================================================
func _process_survive(delta: float) -> void:
	var t_elapsed: float = SURVIVE_TIME - time_left

	# Nhịp tim tỉnh táo
	if not quiz_active:
		beat_phase += delta
		if beat_phase >= BEAT_PERIOD:
			beat_phase -= BEAT_PERIOD
			GameFX.play_sfx("tick", -10.0, 0.8)
		if beat_ring:
			beat_ring.phase_ratio = beat_phase / BEAT_PERIOD

	# Các thanh trạng thái
	var sleep_rate: float = 6.0 if not quiz_active else 3.0
	if hunger >= 100.0:
		sleep_rate += 3.0
	sleepiness = clampf(sleepiness + sleep_rate * delta, 0.0, 100.0)
	hunger = clampf(hunger + 3.0 * delta, 0.0, 100.0)
	attention = clampf(attention - 1.5 * delta, 0.0, 100.0)

	# Giảng viên nhìn lớp theo chu kỳ
	watch_timer -= delta
	if watch_timer <= 0.0:
		lecturer_watching = not lecturer_watching
		watch_timer = randf_range(2.5, 4.0) if lecturer_watching else randf_range(3.0, 6.0)
		watch_label.text = "👀 GIẢNG VIÊN ĐANG NHÌN XUỐNG LỚP!" if lecturer_watching else "📖 Giảng viên đang nhìn slide"
		watch_label.add_theme_color_override("font_color", Color("#FF7675") if lecturer_watching else Color("#BDC3C7"))
		if lecturer and not phone_active:
			var tw := create_tween()
			tw.tween_property(lecturer, "rotation:y", PI if lecturer_watching else 0.0, 0.4)

	# Bụng kêu khi đói
	if hunger > 70.0:
		growl_timer -= delta
		if growl_timer <= 0.0:
			growl_timer = 4.0
			GameFX.play_sfx("growl", 2.0)
			attention = clampf(attention + 15.0, 0.0, 100.0)
			GameFX.popup("ỤC ỤC... 🍜 bụng kêu to quá! Cô liếc nhìn (+15 để ý)", Color("#FDCB6E"), 24, 1.2)
			GameFX.shake(0.15)
	else:
		growl_timer = 4.0

	# Sự kiện theo lịch
	for ev: Dictionary in event_schedule:
		if not ev["done"] and t_elapsed >= float(ev["t"]) and not quiz_active and not phone_active:
			ev["done"] = true
			if ev["type"] == "quiz":
				_start_quiz()
			else:
				_start_phone_check()

	if quiz_active:
		quiz_timer -= delta
		quiz_bar.value = quiz_timer / 8.0 * 100.0
		if quiz_timer <= 0.0:
			_resolve_quiz(false, "HẾT GIỜ")
	if phone_active:
		phone_timer -= delta
		if phone_timer <= 0.0:
			_resolve_phone(false)

	# HUD
	sleep_bar.value = sleepiness
	GameFX.set_bar_color(sleep_bar, Color("#74B9FF") if sleepiness < 60.0 else (Color("#F1C40F") if sleepiness < 85.0 else Color("#E74C3C")))
	hunger_bar.value = hunger
	attention_bar.value = attention
	var vig: float = clampf((sleepiness - 55.0) / 45.0, 0.0, 0.85)
	GameFX.set_vignette(vig, Color(0.05, 0.08, 0.2), 0.0)

	# Thua / thắng
	if sleepiness >= 100.0:
		_fail_stage("BẠN NGỦ GỤC TRÊN BÀN TRONG PHÒNG 16°C! Giảng viên: 'Em ra ngoài rửa mặt rồi khỏi vào nữa.'")
	elif attention >= 100.0:
		_fail_stage("GIẢNG VIÊN ĐỂ Ý QUÁ MỨC: 'Em thu dọn ra ngoài giùm cô!' – BỊ MỜI RA KHỎI LỚP.")
	elif time_left <= 0.0:
		_complete_stage()

func _on_beat_press() -> void:
	var dist: float = minf(beat_phase, BEAT_PERIOD - beat_phase)
	if dist <= BEAT_WINDOW:
		beat_hits += 1
		sleepiness = clampf(sleepiness - 8.0, 0.0, 100.0)
		beat_feedback.text = "✓ ĐÚNG NHỊP! (-8 buồn ngủ) · chuỗi %d" % beat_hits
		beat_feedback.add_theme_color_override("font_color", Color("#2ECC71"))
		beat_ring.good = true
		beat_ring.flash = 1.0
		GameFX.play_sfx("pop", -6.0, 1.2)
	else:
		beat_misses += 1
		sleepiness = clampf(sleepiness + 3.0, 0.0, 100.0)
		beat_feedback.text = "✗ LỆCH NHỊP... gật gù (+3 buồn ngủ)"
		beat_feedback.add_theme_color_override("font_color", Color("#E74C3C"))
		beat_ring.good = false
		beat_ring.flash = 1.0
		GameFX.play_sfx("miss", -10.0)

func _on_coffee_pressed() -> void:
	if phase != Phase.SURVIVE or is_stage_ended:
		return
	if coffee_left <= 0:
		GameFX.popup("☕ HẾT CÀ PHÊ RỒI! Phải giữ nhịp bằng tay thôi...", Color("#BDC3C7"), 22, 1.0)
		GameFX.play_sfx("error", -8.0)
		return
	coffee_left -= 1
	if StageManager.has_item("coffee"):
		StageManager.consume_item("coffee")
	sleepiness = maxf(0.0, sleepiness - 15.0)
	_refresh_consumables()
	GameFX.play_sfx("cash", -4.0)
	GameFX.popup("☕ NHẤP CÀ PHÊ 7-ELEVEN! (-15 buồn ngủ) còn %d ly" % coffee_left, Color("#2ECC71"), 24, 1.0)

func _on_banhbao_pressed() -> void:
	if phase != Phase.SURVIVE or is_stage_ended:
		return
	if banhbao_left <= 0:
		GameFX.popup("🥟 HẾT BÁNH BAO! Nhịn tới trưa thôi...", Color("#BDC3C7"), 22, 1.0)
		GameFX.play_sfx("error", -8.0)
		return
	banhbao_left -= 1
	if StageManager.has_item("banh_bao"):
		StageManager.consume_item("banh_bao")
	hunger = maxf(0.0, hunger - 40.0)
	_refresh_consumables()
	if lecturer_watching:
		attention = clampf(attention + 30.0, 0.0, 100.0)
		GameFX.popup("😱 CÔ THẤY EM ĂN TRONG LỚP! (+30 để ý)", Color("#E74C3C"), 26, 1.3)
		GameFX.play_sfx("alarm", -4.0)
		lecturer_bubble.text = "🎓 Em kia! Lớp học hay căn tin?!"
	else:
		GameFX.popup("🥟 Nhai lén thành công! (-40 đói)", Color("#2ECC71"), 24, 1.0)
		GameFX.play_sfx("pop", -4.0)

func _start_quiz() -> void:
	quiz_active = true
	quiz_count += 1
	quiz_timer = 8.0
	var q: Array = QUIZ_POOL[randi() % QUIZ_POOL.size()]
	quiz_answers = q[1]
	quiz_question.text = "🎓 GIẢNG VIÊN GỌI TÊN BẠN BẤT NGỜ!\n\"%s\"\n(8 giây – gõ đáp án ngắn rồi Enter)" % str(q[0])
	quiz_question.add_theme_color_override("font_color", Color("#F1C40F"))
	quiz_panel.visible = true
	answer_input.text = ""
	answer_input.editable = true
	answer_input.grab_focus()
	lecturer_bubble.text = "🎓 Em áo cam bàn 3, trả lời cô!"
	GameFX.play_sfx("alarm", -3.0)
	GameFX.shake(0.2)
	beat_feedback.text = "(đang bị gọi tên – nhịp tạm dừng)"

func _on_quiz_submitted(text: String) -> void:
	if not quiz_active:
		return
	var norm: String = text.strip_edges().to_lower()
	while norm.find("  ") != -1:
		norm = norm.replace("  ", " ")
	var ok: bool = norm in quiz_answers
	_resolve_quiz(ok, text)

func _resolve_quiz(correct: bool, given: String) -> void:
	quiz_active = false
	quiz_panel.visible = false
	answer_input.release_focus()
	if correct:
		quiz_correct += 1
		attention = clampf(attention - 10.0, 0.0, 100.0)
		GameFX.popup("✅ ĐÚNG RỒI! 'Giỏi, ngồi xuống.' (-10 để ý)", Color("#2ECC71"), 28, 1.4)
		GameFX.play_sfx("success", -2.0)
		lecturer_bubble.text = "🎓 Giỏi! Ngồi xuống."
	else:
		attention = clampf(attention + 25.0, 0.0, 100.0)
		sleepiness = clampf(sleepiness + 15.0, 0.0, 100.0)
		GameFX.popup("❌ '%s'?! Cô: 'Em học hành kiểu gì vậy?' (+25 để ý, +15 buồn ngủ)\nĐáp án: %s" % [given, str(quiz_answers[0]).to_upper()], Color("#E74C3C"), 24, 2.0)
		GameFX.play_sfx("error")
		GameFX.shake(0.3)
		lecturer_bubble.text = "🎓 Em học hành kiểu gì vậy?!"
	beat_feedback.text = ""

func _start_phone_check() -> void:
	if phone_confiscated:
		return
	phone_active = true
	phone_timer = 1.5
	phone_saved = false
	_set_event_prompt("📱 GIẢNG VIÊN ĐI XUỐNG DÃY BÀN! ÚP ĐIỆN THOẠI NGAY [F]!", Color("#FF7675"))
	GameFX.play_sfx("alarm")
	GameFX.shake(0.25)
	lecturer_bubble.text = "🎓 Để cô xuống xem ai chơi điện thoại..."
	if lecturer:
		var tw := create_tween()
		tw.tween_property(lecturer, "position", Vector3(1.4, 0.0, 0.6), 1.4)
		tw.tween_property(lecturer, "rotation:y", PI, 0.2)

func _on_phone_flip() -> void:
	if phone_confiscated:
		return
	if phone_active and not phone_saved:
		_resolve_phone(true)
	else:
		GameFX.popup("📱 (điện thoại đã úp sẵn rồi)", Color("#BDC3C7"), 20, 0.7)

func _resolve_phone(saved: bool) -> void:
	phone_active = false
	phone_saved = saved
	_set_event_prompt("")
	if saved:
		phone_mat.emission_enabled = false
		phone_mat.albedo_color = Color("#2D3436")
		var tw := create_tween()
		tw.tween_property(phone_mesh, "rotation_degrees:z", 180.0, 0.15)
		GameFX.popup("😮‍💨 ÚP KỊP! Cô đi ngang không thấy gì.", Color("#2ECC71"), 26, 1.2)
		GameFX.play_sfx("pop", -2.0)
		lecturer_bubble.text = "🎓 Hmm... tốt, học tiếp."
	else:
		phone_confiscated = true
		attention = clampf(attention + 40.0, 0.0, 100.0)
		GameFX.popup("📱 TỊCH THU ĐIỆN THOẠI! 'Cuối giờ lên văn phòng lấy.' (+40 để ý)", Color("#E74C3C"), 26, 1.8)
		GameFX.play_sfx("miss")
		GameFX.shake(0.4)
		lecturer_bubble.text = "🎓 Điện thoại! Cuối giờ lên lấy!"
		var tw := create_tween()
		tw.tween_property(phone_mesh, "position", lecturer.position + Vector3(0, 1.3, 0), 0.4)
		tw.tween_callback(phone_mesh.queue_free)
	if lecturer:
		var tw2 := create_tween()
		tw2.tween_interval(0.6)
		tw2.tween_property(lecturer, "position", Vector3(2.6, 0.0, -4.0), 1.2)
		tw2.tween_property(lecturer, "rotation:y", 0.0, 0.3)
	# Lần úp tiếp theo: điện thoại lại sáng lên (bạn lại lén mở)
	if saved:
		var tw3 := create_tween()
		tw3.tween_interval(6.0)
		tw3.tween_callback(func() -> void:
			if is_instance_valid(phone_mesh) and not phone_confiscated:
				phone_mat.emission_enabled = true
				phone_mat.albedo_color = Color("#74B9FF")
				phone_mesh.rotation_degrees.z = 0.0
				phone_saved = false
		)

# ===========================================================================
# KẾT THÚC
# ===========================================================================
func _complete_stage() -> void:
	if is_stage_ended:
		return
	is_stage_ended = true
	phase = Phase.DONE
	quiz_panel.visible = false
	beat_panel.visible = false
	_set_event_prompt("")
	GameFX.clear_vignette()
	GameFX.play_sfx("res://assets/audio/victory_fanfare.wav", 2.0)
	GameFX.flash(Color("#2ECC71"), 0.4, 0.5)

	var score: int = 400 - strikes * 100 + beat_hits * 6 - beat_misses * 4 + quiz_correct * 120 + int((100.0 - attention) * 2.0) + coffee_left * 40 + (0 if phone_confiscated else 100)
	score = maxi(0, score)
	var rank: String = GameFX.rank_for(float(score), 1000.0, 750.0, 450.0)
	StageManager.report_stage_result(StageManager.StageID.STAGE_3_CLASSROOM, {
		"result": "win", "score": score, "rank": rank,
		"detail": "strikes=%d beats=%d/%d quiz=%d/%d attention=%d" % [strikes, beat_hits, beat_hits + beat_misses, quiz_correct, quiz_count, int(attention)]
	})
	modal_title.text = "🎉 SỐNG SÓT SLOT 1 – [P] PRESENT! RANK %s" % rank
	modal_title.modulate = Color("#2ECC71")
	modal_sub.text = "FAP: %d lần nhập sai, %s · Mã bị đổi %d lần.\nSinh tồn: %d nhịp đúng / %d lệch · Trả lời đúng %d/%d câu · Để ý cuối: %d%%\n%s · Điểm %d" % [
		strikes, ("dùng 4G" if is_using_4g else "đoán qua Wi-Fi lag 😎"), code_changes,
		beat_hits, beat_misses, quiz_correct, quiz_count, int(attention),
		("Điện thoại bị tịch thu 📱" if phone_confiscated else "Giữ được điện thoại 📱✅"), score
	]
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _fail_stage(reason: String) -> void:
	if is_stage_ended:
		return
	is_stage_ended = true
	phase = Phase.DONE
	quiz_panel.visible = false
	beat_panel.visible = false
	fap_panel.visible = false
	_set_event_prompt("")
	GameFX.clear_vignette()
	GameFX.play_sfx("res://assets/audio/absent_gameover.wav", 2.0)
	StageManager.report_stage_result(StageManager.StageID.STAGE_3_CLASSROOM, {"result": "fail", "score": 0, "rank": "C", "detail": reason})
	modal_title.text = "❌ THẤT BẠI - BỊ ĐÁNH ABSENT!"
	modal_title.modulate = Color("#E74C3C")
	modal_sub.text = reason
	next_btn.visible = false
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _on_next_pressed() -> void:
	StageManager.change_stage(StageManager.StageID.STAGE_4_VOVINAM)

func _on_menu_pressed() -> void:
	StageManager.open_stage_select()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
