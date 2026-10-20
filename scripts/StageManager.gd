# File: res://scripts/StageManager.gd
# Autoload "StageManager": điều phối chuyển màn, Campaign Hub, inventory & thành tích xuyên màn.
extends Node

enum StageID {
	STAGE_1_RACE = 1,
	STAGE_2_PARKING = 2,
	STAGE_3_CLASSROOM = 3,
	STAGE_4_VOVINAM = 4,
	STAGE_5_CANTEEN = 5,
	STAGE_6_CAPSTONE = 6,
	STAGE_EXTRA_EOS = 7
}

var stage_scenes: Dictionary = {
	StageID.STAGE_1_RACE: "res://scenes/Main.tscn",
	StageID.STAGE_2_PARKING: "res://scenes/Stage2_Parking.tscn",
	StageID.STAGE_3_CLASSROOM: "res://scenes/Stage3_ClassroomFAP.tscn",
	StageID.STAGE_4_VOVINAM: "res://scenes/Stage4_Vovinam.tscn",
	StageID.STAGE_5_CANTEEN: "res://scenes/Stage5_Canteen.tscn",
	StageID.STAGE_6_CAPSTONE: "res://scenes/Stage6_CapstoneBoss.tscn",
	StageID.STAGE_EXTRA_EOS: "res://scenes/StageExtra_EOSExam.tscn"
}

var stage_info: Dictionary = {
	StageID.STAGE_1_RACE: {
		"title": "MÀN 1: [07:05 AM] ĐUA XE VŨ BÃO SHTP ĐẾN CỔNG FPTU",
		"desc": "Drift [SPACE], lách sát xe ngược chiều ăn giây thưởng, né ổ gà, dừng đèn đỏ, cán đích trước 07:30!"
	},
	StageID.STAGE_2_PARKING: {
		"title": "MÀN 2: [07:26 AM] BÃI XE D1 & CHINH PHỤC NGỌN NÚI 11 TẦNG",
		"desc": "Quét thẻ [E], tranh ô đỗ với xe khác, đỗ cho thẳng, rồi chạy bộ né sinh viên leo lên Lab 402!"
	},
	StageID.STAGE_3_CLASSROOM: {
		"title": "MÀN 3: [07:30 AM] ROLL CALL FAP 4G & PHÒNG HỌC 16°C",
		"desc": "Đoán mã FAP qua Wi-Fi lag hoặc chờ 4G, rồi sinh tồn: giữ nhịp tỉnh táo, bụng đói, bị gọi tên, giấu điện thoại!"
	},
	StageID.STAGE_4_VOVINAM: {
		"title": "MÀN 4: [09:30 AM] VOVINAM ĐẠI CHIẾN & ĐÒN KẸP CỔ #21",
		"desc": "Rhythm 3 vòng nhanh dần, combo x4, hít đất nếu sai, rồi chuỗi 5 bước thi triển Đòn chân kẹp cổ số 21!"
	},
	StageID.STAGE_5_CANTEEN: {
		"title": "MÀN 5: [11:30 AM] CĂN TIN ĐẠI CHIẾN & 7-ELEVEN",
		"desc": "Bưng khay luồn qua biển người áo cam tới bàn bạn, rồi kéo thả combo 7-Eleven trong ngân sách!"
	},
	StageID.STAGE_6_CAPSTONE: {
		"title": "MÀN 6: [23:00 PM] BOSS FIGHT: CUỘC CHIẾN ĐỒ ÁN CAPSTONE 23:59",
		"desc": "Gõ tên lỗi để bắn hạ đạn 404/NullPointer, gọi dậy bạn seen không rep, resolve Git Conflict trước 23:59!"
	},
	StageID.STAGE_EXTRA_EOS: {
		"title": "EXTRA: [08:00 AM] GIÁM THỊ COI THI EOS BẮT TOOL CHEAT",
		"desc": "Đi tuần hoặc xem CCTV [C], chụp bằng chứng [S] đúng lúc, lập biên bản 5 thánh tool mà không bắt oan!"
	}
}

const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"
## Bảng phím dùng chung cho menu chính và menu tạm dừng
const CONTROLS_GUIDE: Array = [
	["Chung", "[M] mở Campaign Hub chọn màn (xem rank) · [ESC] tạm dừng / đóng cửa sổ · Vật phẩm mua ở 7-Eleven (Màn 5) dùng được ở Màn 2, 3"],
	["Màn 1 – Đua xe", "[W] ga · [S] phanh/lùi · [A]/[D] lái · [SPACE]+[A]/[D] drift (thả để boost) · [H] còi · lách sát xe ngược chiều liên tiếp để nhân thưởng"],
	["Màn 2 – Bãi xe & chạy bộ", "[E] quét thẻ · [H] còi doạ xe tranh ô · [S] lùi · pha chạy: [A]/[D] đổi làn, [SPACE] nhảy, [S] trượt, [SHIFT] sprint, [Q] Monster"],
	["Màn 3 – Roll call FAP", "gõ mã + [ENTER] · [TAB] bật 4G · [SPACE] đúng nhịp · [C] cà phê · [B] bánh bao · [F] úp điện thoại · gõ đáp án khi bị gọi tên"],
	["Màn 4 – Vovinam", "[←][→][↑][↓][SPACE] theo nốt (hoặc A D W S) · hít đất mash [SPACE] · finisher: giữ [W], [SPACE], [←][→] luân phiên, [SPACE], [↓]"],
	["Màn 5 – Căn tin", "[WASD] đi · [E] lấy khay / giao / vào 7-Eleven · đứng yên giữ [SPACE] cân khay · cửa hàng: [←→↑↓] chọn, [ENTER] thêm, [BACKSPACE] bỏ, [SPACE] trả tiền"],
	["Màn 6 – Boss Capstone", "gõ chữ trên đạn · [BACKSPACE] xoá · [TAB] đổi người · [ENTER] skill / gọi điện · [SPACE] mash khi gọi · [←]/[→] chọn khối code conflict"],
	["Extra – Giám thị EOS", "[WASD] đi tuần (theo hướng camera) · [C] CCTV · [S] chụp bằng chứng · [E] soi / lập biên bản · [Shift]+[SPACE] ép biên bản"]
]
var pause_layer: CanvasLayer
# Thẻ chuyển cảnh giữa các màn
var transition_layer: CanvasLayer
var transition_clock: Label
var transition_line: Label
var transition_sub: Label
var transition_active: bool = false
var _transition_target: int = -1
var _transition_tween: Tween
const TRANSITION_SECONDS: float = 3.0
var pause_settings_box: VBoxContainer
var pause_controls_box: VBoxContainer
var pause_resume_btn: Button
var pause_quality_buttons: Array[Button] = []
const PROGRESS_PATH: String = "user://progress.cfg"

var current_stage: int = StageID.STAGE_1_RACE
var modal_layer: CanvasLayer
## Kỷ lục lưu trên đĩa: stage_id -> {"score": int, "rank": String, "wins": int, "plays": int}
var best_stats: Dictionary = {}

# ----- Trạng thái xuyên màn -----
## Vật phẩm mang theo giữa các màn (mua ở 7-Eleven, nhặt ở bãi xe...)
var inventory: Dictionary = {"monster": 0, "coffee": 0, "banh_bao": 0}
## Kết quả từng màn: stage_id -> {"result": "win"/"fail", "score": int, "rank": "S", "detail": String}
var run_stats: Dictionary = {}

var _rank_labels: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()
	_create_stage_select_ui()
	_create_pause_ui()
	_create_transition_ui()

# ---------------------------------------------------------------------------
# MENU CHÍNH & LƯU KỶ LỤC
# ---------------------------------------------------------------------------
func go_to_main_menu() -> void:
	typing_mode = false
	if modal_layer:
		modal_layer.visible = false
	if pause_layer and pause_layer.visible:
		pause_layer.visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

## Bắt đầu hành trình mới từ Màn 1: xoá vật phẩm & kết quả phiên hiện tại (kỷ lục trên đĩa vẫn giữ)
func start_new_day() -> void:
	inventory = {"monster": 0, "coffee": 0, "banh_bao": 0}
	run_stats.clear()
	_refresh_rank_labels()
	change_stage(StageID.STAGE_1_RACE)

func load_progress() -> void:
	best_stats.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	for sid: int in stage_scenes.keys():
		var sec: String = "stage_%d" % sid
		if cfg.has_section(sec):
			best_stats[sid] = {
				"score": int(cfg.get_value(sec, "score", 0)), "rank": String(cfg.get_value(sec, "rank", "")),
				"wins": int(cfg.get_value(sec, "wins", 0)), "plays": int(cfg.get_value(sec, "plays", 0))
			}

func save_progress() -> void:
	if DisplayServer.get_name() == "headless":
		return # bot test headless không được ghi đè kỷ lục thật của người chơi
	var cfg := ConfigFile.new()
	for sid: int in best_stats.keys():
		var b: Dictionary = best_stats[sid]
		var sec: String = "stage_%d" % sid
		cfg.set_value(sec, "score", int(b.get("score", 0)))
		cfg.set_value(sec, "rank", String(b.get("rank", "")))
		cfg.set_value(sec, "wins", int(b.get("wins", 0)))
		cfg.set_value(sec, "plays", int(b.get("plays", 0)))
	cfg.save(PROGRESS_PATH)

func get_best_text(stage_id: int) -> String:
	if not best_stats.has(stage_id):
		return "— chưa chơi —"
	var b: Dictionary = best_stats[stage_id]
	if int(b.get("wins", 0)) <= 0:
		return "chưa qua (%d lần thử)" % int(b.get("plays", 0))
	return "🏆 %s · %d điểm · %d/%d thắng" % [String(b.get("rank", "B")), int(b.get("score", 0)), int(b.get("wins", 0)), int(b.get("plays", 0))]

## Màn chơi đặt true khi người chơi đang gõ chữ (bullet-hell typing...) để phím M không mở Campaign Hub
var typing_mode: bool = false

func _is_text_input_focused() -> bool:
	var vp: Viewport = get_viewport()
	if not vp:
		return false
	var owner: Control = vp.gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit

func _input(event: InputEvent) -> void:
	if transition_active and event is InputEventKey and event.is_pressed() and not event.is_echo():
		_finish_transition()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_M:
			if typing_mode or _is_text_input_focused():
				return
			toggle_stage_select()
		elif event.physical_keycode == KEY_TAB and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
			toggle_stage_select()
		elif event.physical_keycode == KEY_ESCAPE and modal_layer and modal_layer.visible:
			modal_layer.visible = false
		elif event.physical_keycode == KEY_ESCAPE and _can_pause():
			toggle_pause()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# TẠM DỪNG (ESC trong màn chơi)
# ---------------------------------------------------------------------------
func _can_pause() -> bool:
	var cs: Node = get_tree().current_scene
	if cs == null or cs is MainMenu or transition_active:
		return false
	return true

func is_paused() -> bool:
	return pause_layer != null and pause_layer.visible

func toggle_pause() -> void:
	if pause_layer == null:
		return
	if pause_layer.visible:
		resume_game()
	else:
		pause_game()

func pause_game() -> void:
	if pause_layer == null or pause_layer.visible:
		return
	pause_layer.visible = true
	pause_settings_box.visible = false
	pause_controls_box.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameFX.play_ui("pop", -6.0, 0.8)
	_refresh_pause_quality()
	pause_resume_btn.call_deferred("grab_focus")

func resume_game() -> void:
	if pause_layer == null or not pause_layer.visible:
		return
	pause_layer.visible = false
	get_tree().paused = false
	GameFX.play_ui("pop", -6.0, 1.1)

func _create_pause_ui() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 118
	pause_layer.visible = false
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	card.add_theme_stylebox_override("panel", GameFX.make_panel_style(Color("#F37021"), Color(0.05, 0.07, 0.12, 0.97), 12))
	center.add_child(card)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	vb.add_child(GameFX.make_label("⏸ TẠM DỪNG", 26, Color("#F37021")))
	var sub: Label = GameFX.make_label("Thời gian trong game đã dừng. Giảng viên vẫn chưa điểm danh… tranh thủ đi.", 13, Color("#BDC3C7"))
	vb.add_child(sub)

	pause_resume_btn = _pause_button("▶   TIẾP TỤC  [ESC]")
	pause_resume_btn.pressed.connect(resume_game)
	vb.add_child(pause_resume_btn)
	var settings_btn: Button = _pause_button("⚙   CÀI ĐẶT (đồ hoạ · âm lượng)")
	settings_btn.pressed.connect(func() -> void:
		pause_settings_box.visible = not pause_settings_box.visible
		pause_controls_box.visible = false)
	vb.add_child(settings_btn)
	pause_settings_box = VBoxContainer.new()
	pause_settings_box.add_theme_constant_override("separation", 8)
	pause_settings_box.visible = false
	vb.add_child(pause_settings_box)
	var qrow := HBoxContainer.new()
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	qrow.add_theme_constant_override("separation", 8)
	pause_settings_box.add_child(qrow)
	pause_quality_buttons.clear()
	for q: int in range(3):
		var qb: Button = _pause_button(["🟢 Thấp", "🟡 Trung bình", "🔴 Cao"][q])
		qb.custom_minimum_size = Vector2(170, 40)
		qb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		qb.pressed.connect(func() -> void:
			GameFX.set_visual_quality(q)
			var cs: Node = get_tree().current_scene
			if cs:
				GameFX.upgrade_scene_visuals(cs, String(cs.get_meta("visual_preset", "morning")))
			_refresh_pause_quality()
			GameFX.play_ui("pop", -6.0))
		qrow.add_child(qb)
		pause_quality_buttons.append(qb)
	GameFX.build_audio_settings(pause_settings_box)

	var controls_btn: Button = _pause_button("🎮   ĐIỀU KHIỂN")
	controls_btn.pressed.connect(func() -> void:
		pause_controls_box.visible = not pause_controls_box.visible
		pause_settings_box.visible = false)
	vb.add_child(controls_btn)
	pause_controls_box = VBoxContainer.new()
	pause_controls_box.add_theme_constant_override("separation", 4)
	pause_controls_box.visible = false
	vb.add_child(pause_controls_box)
	for ln: Array in CONTROLS_GUIDE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		pause_controls_box.add_child(row)
		var k: Label = GameFX.make_label(String(ln[0]), 12, Color("#F1C40F"), HORIZONTAL_ALIGNMENT_LEFT)
		k.custom_minimum_size = Vector2(150, 0)
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(k)
		var d: Label = GameFX.make_label(String(ln[1]), 11, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)

	var hub_btn: Button = _pause_button("📋   CHỌN MÀN KHÁC (Campaign Hub)")
	hub_btn.pressed.connect(func() -> void:
		resume_game()
		open_stage_select())
	vb.add_child(hub_btn)
	var menu_btn: Button = _pause_button("🏠   VỀ MENU CHÍNH")
	menu_btn.pressed.connect(func() -> void:
		resume_game()
		go_to_main_menu())
	vb.add_child(menu_btn)
	var quit_btn: Button = _pause_button("✖   THOÁT GAME")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vb.add_child(quit_btn)

func _pause_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 17)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", GameFX.make_panel_style(Color(0.95, 0.44, 0.13, 0.55), Color(0.07, 0.09, 0.15, 0.9), 10))
	b.add_theme_stylebox_override("hover", GameFX.make_panel_style(Color("#F37021"), Color(0.1, 0.12, 0.2, 0.96), 10))
	b.add_theme_stylebox_override("focus", GameFX.make_panel_style(Color("#F37021"), Color(0.1, 0.12, 0.2, 0.96), 10))
	b.add_theme_stylebox_override("pressed", GameFX.make_panel_style(Color("#F1C40F"), Color(0.18, 0.1, 0.03, 0.98), 10))
	b.mouse_entered.connect(func() -> void: GameFX.play_ui("tick", -12.0, 1.4))
	return b

func _refresh_pause_quality() -> void:
	for q: int in range(pause_quality_buttons.size()):
		var b: Button = pause_quality_buttons[q]
		var active: bool = q == GameFX.visual_quality
		b.add_theme_color_override("font_color", Color("#F1C40F") if active else Color("#F4F5F6"))

# ---------------------------------------------------------------------------
# CHUYỂN MÀN
# ---------------------------------------------------------------------------
func change_stage(stage_id: int) -> void:
	if not stage_scenes.has(stage_id):
		return
	typing_mode = false
	if modal_layer:
		modal_layer.visible = false
	if pause_layer and pause_layer.visible:
		pause_layer.visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if transition_active:
		return
	# Headless (bot test) hoặc chưa có cảnh: chuyển thẳng
	if DisplayServer.get_name() == "headless" or transition_layer == null:
		current_stage = stage_id
		get_tree().change_scene_to_file(stage_scenes[stage_id])
		return
	_begin_transition(stage_id)

# ---------------------------------------------------------------------------
# THẺ CHUYỂN CẢNH (3 s, bấm phím bất kỳ để bỏ qua)
# ---------------------------------------------------------------------------
static func _clock_of(title: String) -> String:
	var re := RegEx.new()
	re.compile("\\[(\\d{2}:\\d{2}) (AM|PM)\\]")
	var m: RegExMatch = re.search(title)
	return m.get_string(1) if m else "07:00"

static func _clock_minutes(hhmm: String) -> int:
	var parts: PackedStringArray = hhmm.split(":")
	if parts.size() != 2:
		return 7 * 60
	return int(parts[0]) * 60 + int(parts[1])

func _transition_quip(from_stage: int, to_stage: int) -> String:
	var r: Dictionary = run_stats.get(from_stage, {})
	var result: String = String(r.get("result", ""))
	var rank: String = String(r.get("rank", ""))
	if from_stage == -1:
		return "Một ngày mới ở FPTU bắt đầu. Báo thức đã reo 3 lần rồi đó."
	if result == "win" and rank == "S":
		return ["Quá mượt. Giảng viên còn chưa tới, ngồi ghế đầu luôn.", "Rank S! Cóc Vàng gật gù nhìn bạn.", "Đỉnh. Nhóm chat đã có người xin vía."][randi() % 3]
	if result == "win":
		return ["Qua được rồi, thở cái đã. Tiết sau còn gắt hơn.", "Xong việc, vẫn còn kịp mua ly Passio.", "Ổn áp. Không ai cần biết vừa run tay thế nào."][randi() % 3]
	if result == "fail":
		return ["Thôi kệ, ngày còn dài. Lần sau nhớ đặt báo thức sớm hơn.", "Fail nhẹ. Đời sinh viên ai chẳng có vài slot như thế.", "Không sao, retake là một phần của tuổi trẻ."][randi() % 3]
	if to_stage == StageID.STAGE_6_CAPSTONE:
		return "Tối rồi. Deadline Capstone đang thở sau gáy."
	return "Tiếp tục hành trình. Áo cam vẫn chưa ướt mồ hôi."

func _begin_transition(stage_id: int) -> void:
	transition_active = true
	_transition_target = stage_id
	var cs: Node = get_tree().current_scene
	var from_stage: int = -1
	if cs and not (cs is MainMenu):
		from_stage = current_stage
	var from_clock: String = _clock_of(String(stage_info[from_stage]["title"])) if from_stage != -1 else "06:45"
	var to_clock: String = _clock_of(String(stage_info[stage_id]["title"]))
	transition_line.text = _transition_quip(from_stage, stage_id)
	var full_title: String = String(stage_info[stage_id]["title"])
	transition_sub.text = full_title.get_slice("] ", 1) if full_title.contains("] ") else full_title
	transition_layer.visible = true
	var dim: ColorRect = transition_layer.get_node("Dim")
	dim.color.a = 0.0
	transition_clock.text = from_clock
	current_stage = stage_id
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.tween_property(dim, "color:a", 0.94, 0.35)
	var m0: int = _clock_minutes(from_clock)
	var m1: int = _clock_minutes(to_clock)
	if m1 < m0:
		m1 += 24 * 60
	_transition_tween.tween_method(func(t: float) -> void:
		var m: int = int(round(lerpf(float(m0), float(m1), t))) % (24 * 60)
		transition_clock.text = "%02d:%02d" % [m / 60, m % 60]
		if int(t * 40.0) % 2 == 0:
			GameFX.play_ui("tick", -18.0, 2.0), 0.0, 1.0, 1.3)
	_transition_tween.tween_interval(TRANSITION_SECONDS - 1.65)
	_transition_tween.tween_callback(_finish_transition)

func _finish_transition() -> void:
	if not transition_active:
		return
	transition_active = false
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	get_tree().change_scene_to_file(stage_scenes[_transition_target])
	var dim: ColorRect = transition_layer.get_node("Dim")
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(dim, "color:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: transition_layer.visible = false)

func _create_transition_ui() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 119
	transition_layer.visible = false
	transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(transition_layer)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	transition_clock = GameFX.make_label("07:05", 96, Color("#F1C40F"))
	transition_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	transition_clock.add_theme_constant_override("outline_size", 12)
	transition_clock.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.9))
	vb.add_child(transition_clock)
	transition_sub = GameFX.make_label("", 22, Color("#F37021"))
	transition_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(transition_sub)
	transition_line = GameFX.make_label("", 17, Color("#DFE6E9"))
	transition_line.custom_minimum_size = Vector2(760, 0)
	vb.add_child(transition_line)
	var hint: Label = GameFX.make_label("bấm phím bất kỳ để tiếp tục", 12, Color("#7F8C8D"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(hint)

func next_stage() -> void:
	var next_id: int = current_stage + 1
	if next_id > StageID.STAGE_EXTRA_EOS:
		next_id = StageID.STAGE_1_RACE
	change_stage(next_id)

func toggle_stage_select() -> void:
	if modal_layer:
		modal_layer.visible = not modal_layer.visible
		if modal_layer.visible:
			_refresh_rank_labels()

func open_stage_select() -> void:
	if modal_layer:
		modal_layer.visible = true
		_refresh_rank_labels()

# ---------------------------------------------------------------------------
# INVENTORY & THÀNH TÍCH
# ---------------------------------------------------------------------------
func add_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount

func has_item(item_id: String) -> bool:
	return int(inventory.get(item_id, 0)) > 0

func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func consume_item(item_id: String) -> bool:
	if has_item(item_id):
		inventory[item_id] = int(inventory[item_id]) - 1
		return true
	return false

## Màn chơi gọi khi kết thúc: result = {"result": "win"|"fail", "score": int, "rank": "S|A|B|C", "detail": String}
func report_stage_result(stage_id: int, result: Dictionary) -> void:
	run_stats[stage_id] = result
	var b: Dictionary = best_stats.get(stage_id, {"score": 0, "rank": "", "wins": 0, "plays": 0})
	b["plays"] = int(b.get("plays", 0)) + 1
	if result.get("result", "") == "win":
		b["wins"] = int(b.get("wins", 0)) + 1
		if int(result.get("score", 0)) >= int(b.get("score", 0)):
			b["score"] = int(result.get("score", 0))
			b["rank"] = String(result.get("rank", "B"))
	best_stats[stage_id] = b
	save_progress()
	_refresh_rank_labels()

func get_stage_rank_text(stage_id: int) -> String:
	var best: String = ""
	if best_stats.has(stage_id) and int(best_stats[stage_id].get("wins", 0)) > 0:
		best = "   (kỷ lục: %s · %d điểm)" % [String(best_stats[stage_id].get("rank", "B")), int(best_stats[stage_id].get("score", 0))]
	if not run_stats.has(stage_id):
		return "— chưa chơi hôm nay —" + best
	var r: Dictionary = run_stats[stage_id]
	if r.get("result", "") == "win":
		return "✅ RANK %s · %d điểm" % [str(r.get("rank", "B")), int(r.get("score", 0))] + best
	return "❌ Thất bại lần gần nhất" + best

func _refresh_rank_labels() -> void:
	for sid: int in _rank_labels.keys():
		var lbl: Label = _rank_labels[sid]
		if is_instance_valid(lbl):
			lbl.text = get_stage_rank_text(sid)

# ---------------------------------------------------------------------------
# CAMPAIGN HUB UI (anchors chuẩn Godot 4)
# ---------------------------------------------------------------------------
func _create_stage_select_ui() -> void:
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 120
	modal_layer.visible = false
	add_child(modal_layer)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.1, 0.96)
	modal_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(980, 640)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(main_vbox)

	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title := Label.new()
	title.text = "📋 FPTU STUDENT SIMULATOR - CHỌN MÀN CHƠI (CAMPAIGN HUB)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#F37021"))
	header_hbox.add_child(title)

	var quick_close := Button.new()
	quick_close.text = " ✖ [ESC] "
	quick_close.add_theme_font_size_override("font_size", 16)
	quick_close.pressed.connect(toggle_stage_select)
	header_hbox.add_child(quick_close)

	var sub := Label.new()
	sub.text = "Chọn chơi ngay bất kỳ màn nào trong hành trình ngày học của sinh viên FPTU (phím [M] hoặc [ESC] để đóng). Vật phẩm mua ở 7-Eleven được mang sang các màn khác!"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color("#BDC3C7"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920, 440)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(list_vbox)

	for stage_id: int in stage_info.keys():
		var info: Dictionary = stage_info[stage_id]
		var item_panel := PanelContainer.new()
		list_vbox.add_child(item_panel)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		item_panel.add_child(hbox)

		var text_vbox := VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(text_vbox)

		var item_title := Label.new()
		item_title.text = info["title"]
		item_title.add_theme_font_size_override("font_size", 16)
		item_title.add_theme_color_override("font_color", Color("#F1C40F"))
		text_vbox.add_child(item_title)

		var item_desc := Label.new()
		item_desc.text = info["desc"]
		item_desc.add_theme_font_size_override("font_size", 13)
		item_desc.add_theme_color_override("font_color", Color("#BDC3C7"))
		item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_vbox.add_child(item_desc)

		var rank_lbl := Label.new()
		rank_lbl.text = get_stage_rank_text(stage_id)
		rank_lbl.add_theme_font_size_override("font_size", 12)
		rank_lbl.add_theme_color_override("font_color", Color("#2ECC71"))
		text_vbox.add_child(rank_lbl)
		_rank_labels[stage_id] = rank_lbl

		var play_btn := Button.new()
		play_btn.custom_minimum_size = Vector2(150, 46)
		play_btn.text = "▶️ CHƠI NGAY"
		play_btn.add_theme_font_size_override("font_size", 15)
		play_btn.pressed.connect(func() -> void: change_stage(stage_id))
		hbox.add_child(play_btn)

	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(bottom_hbox)

	bottom_hbox.add_theme_constant_override("separation", 14)
	var menu_btn := Button.new()
	menu_btn.custom_minimum_size = Vector2(260, 44)
	menu_btn.text = "🏠 VỀ MENU CHÍNH"
	menu_btn.add_theme_font_size_override("font_size", 15)
	menu_btn.pressed.connect(go_to_main_menu)
	bottom_hbox.add_child(menu_btn)
	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(280, 44)
	close_btn.text = "✖ ĐÓNG CỬA SỔ CHỌN MÀN"
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(toggle_stage_select)
	bottom_hbox.add_child(close_btn)
