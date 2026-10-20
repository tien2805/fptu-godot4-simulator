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
	load_progress()
	_create_stage_select_ui()

# ---------------------------------------------------------------------------
# MENU CHÍNH & LƯU KỶ LỤC
# ---------------------------------------------------------------------------
func go_to_main_menu() -> void:
	typing_mode = false
	if modal_layer:
		modal_layer.visible = false
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
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_M:
			if typing_mode or _is_text_input_focused():
				return
			toggle_stage_select()
		elif event.physical_keycode == KEY_TAB and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
			toggle_stage_select()
		elif event.physical_keycode == KEY_ESCAPE and modal_layer and modal_layer.visible:
			modal_layer.visible = false

# ---------------------------------------------------------------------------
# CHUYỂN MÀN
# ---------------------------------------------------------------------------
func change_stage(stage_id: int) -> void:
	if stage_scenes.has(stage_id):
		current_stage = stage_id
		typing_mode = false
		if modal_layer:
			modal_layer.visible = false
		Engine.time_scale = 1.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(stage_scenes[stage_id])

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
