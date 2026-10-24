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
	STAGE_EXTRA_EOS = 7,
	FREE_ROAM = 8
}

## FREE_ROAM (thế giới mở BE6 -> campus) không có trong stage_info: không hiện trong Campaign Hub / nhật ký,
## không đi qua thẻ chuyển cảnh; vào bằng go_to_roam() (menu chính "Khám phá campus" hoặc nút "Về campus").
var stage_scenes: Dictionary = {
	StageID.STAGE_1_RACE: "res://scenes/Main.tscn",
	StageID.STAGE_2_PARKING: "res://scenes/Stage2_Parking.tscn",
	StageID.STAGE_3_CLASSROOM: "res://scenes/Stage3_ClassroomFAP.tscn",
	StageID.STAGE_4_VOVINAM: "res://scenes/Stage4_Vovinam.tscn",
	StageID.STAGE_5_CANTEEN: "res://scenes/Stage5_Canteen.tscn",
	StageID.STAGE_6_CAPSTONE: "res://scenes/Stage6_CapstoneBoss.tscn",
	StageID.STAGE_EXTRA_EOS: "res://scenes/StageExtra_EOSExam.tscn",
	StageID.FREE_ROAM: "res://scenes/FreeRoam.tscn"
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
	["Chung", "[ESC] tạm dừng / đóng cửa sổ · [P] điện thoại khi chơi cốt truyện (tin nhắn, bằng chứng, nhiệm vụ) · Vật phẩm mua ở 7-Eleven (Màn 5) dùng được ở Màn 2, 3"],
	["Màn 1 – Đua xe", "[W] ga · [S] phanh/lùi · [A]/[D] lái · [SPACE]+[A]/[D] drift (thả để boost) · [H] còi · lách sát xe ngược chiều liên tiếp để nhân thưởng"],
	["Màn 2 – Bãi xe & chạy bộ", "[E] quét thẻ · [H] còi doạ xe tranh ô · [S] lùi · pha chạy: [A]/[D] đổi làn, [SPACE] nhảy, [S] trượt, [SHIFT] sprint, [Q] Monster"],
	["Màn 3 – Roll call FAP", "gõ mã + [ENTER] · [TAB] bật 4G · [SPACE] đúng nhịp · [C] cà phê · [B] bánh bao · [F] úp điện thoại · gõ đáp án khi bị gọi tên"],
	["Màn 4 – Vovinam", "[←][→][↑][↓][SPACE] theo nốt (hoặc A D W S) · hít đất mash [SPACE] · finisher: giữ [W], [SPACE], [←][→] luân phiên, [SPACE], [↓]"],
	["Màn 5 – Căn tin", "[WASD] đi · [E] lấy khay / giao / vào 7-Eleven · đứng yên giữ [SPACE] cân khay · cửa hàng: [←→↑↓] chọn, [ENTER] thêm, [BACKSPACE] bỏ, [SPACE] trả tiền"],
	["Màn 6 – Boss Capstone", "gõ chữ trên đạn · [BACKSPACE] xoá · [TAB] đổi người · [ENTER] skill / gọi điện · [SPACE] mash khi gọi · [←]/[→] chọn khối code conflict"],
	["Extra – Giám thị EOS", "[WASD] đi tuần (theo hướng camera) · [C] CCTV · [S] chụp bằng chứng · [E] soi / lập biên bản · [Shift]+[SPACE] ép biên bản"],
	["Thế giới mở", "[WASD] đi · [Shift] chạy · chuột xoay camera (click để bắt, ESC thả) · [Z]/[C] xoay · [F] lên/xuống xe máy · [E] vào màn tại cột sáng · [T] giờ trong ngày · [M] bản đồ"]
]
var pause_layer: CanvasLayer
# Thẻ chuyển cảnh giữa các màn
var transition_layer: CanvasLayer
var transition_clock: Label
var transition_line: Label
var transition_sub: Label
var transition_strip: TextureRect
var pause_title: Label
var hub_title: Label
var transition_active: bool = false
var _transition_target: int = -1
var _transition_tween: Tween
const TRANSITION_SECONDS: float = 3.0
var pause_settings_box: VBoxContainer
## Bảng phím trong menu tạm dừng: VBox nằm trong pause_controls_scroll (cao tối đa PAUSE_CONTROLS_MAX_H) để nút
## "VỀ MENU CHÍNH" không bị đẩy khỏi màn 720 px khi bảng phím mở.
var pause_controls_box: VBoxContainer
var pause_controls_scroll: ScrollContainer
const PAUSE_CONTROLS_MAX_H: float = 260.0
var pause_resume_btn: Button
var pause_quality_buttons: Array[Button] = []
const PROGRESS_PATH: String = "user://progress.cfg"

var current_stage: int = StageID.STAGE_1_RACE
var modal_layer: CanvasLayer

# ----- Thế giới mở (FreeRoam) -----
## true khi màn hiện tại được mở từ một hotspot của thế giới mở: report_stage_result() hiện nút "Về campus".
var return_to_roam: bool = false
## Transform3D (vị trí + hướng) để FreeRoam spawn lại cạnh hotspot vừa chơi; null = spawn mặc định ở BE6.
var roam_spawn: Variant = null
## FreeRoam đặt true: phím [M] là bản đồ của thế giới mở, không mở Campaign Hub.
var hub_key_blocked: bool = false
## Story beat context of the stage being played (spec A2-D11): set by StoryDirector.launch_stage_beat, empty outside the
## story. {"beat", "stage", "replay", "name", "opts"}; report_stage_result forwards to StoryDirector when set.
var story_context: Dictionary = {}
var pause_hub_btn: Button
var cinematic_active: bool = false   # cinematic / replay đang chạy: ESC là "giữ để bỏ qua", không mở menu tạm dừng (spec A1-D16)
var roam_return_layer: CanvasLayer
## Kỷ lục lưu trên đĩa: stage_id -> {"score": int, "rank": String, "wins": int, "plays": int}
var best_stats: Dictionary = {}

# ----- Ví Cóc Vàng (CV) – bản tối thiểu của spec free-roam mục 1.1 -----
## Số Cóc Vàng đang có (lưu đĩa: mục [roam] khoá "wallet" của progress.cfg). Chỉ đổi qua earn() / spend().
var wallet: int = 0
## Phát mỗi lần ví đổi: tổng mới + chênh lệch (dương khi nhận, âm khi tiêu).
signal wallet_changed(total: int, delta: int)
## Thắng một màn được trả theo rank (thua: 0). Nguồn kiếm duy nhất ở bản này.
const RANK_COINS: Dictionary = {"S": 50, "A": 30, "B": 20, "C": 10}

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
	_create_roam_return_ui()
	get_tree().node_added.connect(_on_node_added)
	_restyle_ui.call_deferred()

## Nút "Chơi lại" của các màn dùng get_tree().reload_current_scene() (không qua change_stage): khi một cảnh gốc mới
## vào cây (cùng phép thử GameFX._on_node_added) thì ẩn lớp "VỀ CAMPUS" của lượt trước. return_to_roam giữ nguyên
## nên kết quả của lượt chơi lại vẫn hiện nút đó.
func _on_node_added(node: Node) -> void:
	var tree: SceneTree = get_tree()
	if tree and node.get_parent() == tree.root and node == tree.current_scene:
		_hide_roam_return()

# ---------------------------------------------------------------------------
# MENU CHÍNH & LƯU KỶ LỤC
# ---------------------------------------------------------------------------
func go_to_main_menu() -> void:
	var sd: Node = get_node_or_null("/root/StoryDirector")
	if sd:
		sd.call("on_leave_to_menu")   # A2-D2: autosave the story (player spot in story free roam), story off
	story_context = {}
	typing_mode = false
	return_to_roam = false
	roam_spawn = null
	_hide_roam_return()
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
	return_to_roam = false
	_refresh_rank_labels()
	change_stage(StageID.STAGE_1_RACE)

# ---------------------------------------------------------------------------
# THẾ GIỚI MỞ (FreeRoam.tscn)
# ---------------------------------------------------------------------------
## Hotspot của thế giới mở gọi: vào màn `stage_id` theo đường chuyển màn bình thường, nhớ quay về campus
## (`spawn` = Transform3D cạnh hotspot, hoặc null = spawn mặc định BE6).
func start_stage_from_roam(stage_id: int, spawn: Variant = null) -> void:
	if not stage_scenes.has(stage_id) or stage_id == StageID.FREE_ROAM:
		return
	roam_spawn = spawn if spawn is Transform3D else null
	change_stage(stage_id, true)

## Nạp thế giới mở ngay (không thẻ chuyển cảnh): menu chính "Khám phá campus" hoặc nút "Về campus" sau một màn.
func go_to_roam() -> void:
	typing_mode = false
	return_to_roam = false
	_hide_roam_return()
	if modal_layer:
		modal_layer.visible = false
	if pause_layer and pause_layer.visible:
		pause_layer.visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if transition_active:
		_finish_transition_silent()
	current_stage = StageID.FREE_ROAM
	get_tree().change_scene_to_file(stage_scenes[StageID.FREE_ROAM])

func _finish_transition_silent() -> void:
	transition_active = false
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	if transition_layer:
		transition_layer.visible = false

## Nút "Về campus" (đáy giữa, trên modal kết quả của màn) – chỉ hiện khi màn được mở từ thế giới mở.
func _create_roam_return_ui() -> void:
	roam_return_layer = CanvasLayer.new()
	roam_return_layer.layer = 117
	roam_return_layer.visible = false
	roam_return_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(roam_return_layer)
	var panel: PanelContainer = GameFX.anchored_panel(roam_return_layer, Control.PRESET_CENTER_BOTTOM, Vector2(0, 0), 18, Color("#2ECC71"))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	panel.add_child(hb)
	var lbl: Label = GameFX.make_label("Xong màn này rồi – quay lại thế giới mở?", 14, Color("#DFE6E9"))
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(lbl)
	var btn: Button = _pause_button("🏫   VỀ CAMPUS  (thế giới mở)")
	btn.custom_minimum_size = Vector2(300, 42)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.pressed.connect(go_to_roam)
	hb.add_child(btn)

func _show_roam_return() -> void:
	if roam_return_layer:
		roam_return_layer.visible = true

func _hide_roam_return() -> void:
	if roam_return_layer:
		roam_return_layer.visible = false

## `path` khác PROGRESS_PATH: test headless dùng file tạm. File không có / hỏng -> kỷ lục rỗng, ví 0.
func load_progress(path: String = PROGRESS_PATH) -> void:
	best_stats.clear()
	wallet = 0
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for sid: int in stage_scenes.keys():
		var sec: String = "stage_%d" % sid
		if cfg.has_section(sec):
			best_stats[sid] = {
				"score": int(cfg.get_value(sec, "score", 0)), "rank": String(cfg.get_value(sec, "rank", "")),
				"wins": int(cfg.get_value(sec, "wins", 0)), "plays": int(cfg.get_value(sec, "plays", 0))
			}
	wallet = maxi(0, int(cfg.get_value("roam", "wallet", 0)))

func save_progress(path: String = PROGRESS_PATH) -> void:
	if DisplayServer.get_name() == "headless" and path == PROGRESS_PATH:
		return # bot test headless không được ghi đè kỷ lục thật của người chơi (test ví ghi file tạm qua `path`)
	var cfg := ConfigFile.new()
	for sid: int in best_stats.keys():
		var b: Dictionary = best_stats[sid]
		var sec: String = "stage_%d" % sid
		cfg.set_value(sec, "score", int(b.get("score", 0)))
		cfg.set_value(sec, "rank", String(b.get("rank", "")))
		cfg.set_value(sec, "wins", int(b.get("wins", 0)))
		cfg.set_value(sec, "plays", int(b.get("plays", 0)))
	cfg.set_value("roam", "wallet", wallet)
	cfg.save(path)

## Nhận `amount` Cóc Vàng (<= 0: bỏ qua). `reason` chỉ để ghi log / mở rộng sau. Lưu đĩa ngay.
func earn(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	wallet += amount
	if reason != "":
		print_verbose("wallet +%d (%s) -> %d" % [amount, reason, wallet])
	wallet_changed.emit(wallet, amount)
	save_progress()

## Tiêu `amount` Cóc Vàng; không đủ tiền (hoặc amount <= 0) thì từ chối, ví không đổi. Lưu đĩa khi tiêu được.
func spend(amount: int) -> bool:
	if amount <= 0 or amount > wallet:
		return false
	wallet -= amount
	wallet_changed.emit(wallet, -amount)
	save_progress()
	return true

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
			if typing_mode or hub_key_blocked or cinematic_active or _is_text_input_focused() or not story_context.is_empty():
				return   # no Campaign Hub in the middle of a story mission either
			toggle_stage_select()
		elif event.physical_keycode == KEY_TAB and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)):
			if not cinematic_active:   # không mở chọn màn giữa cinematic (plan review A1 Minor 10)
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
	if cinematic_active: return false
	var cs: Node = get_tree().current_scene
	if cs == null or cs is MainMenu or cs.has_meta("no_pause") or transition_active:
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
	pause_controls_scroll.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameFX.play_ui("pop", -6.0, 0.8)
	_refresh_pause_quality()
	GameFX.sync_style_settings(pause_settings_box)
	if pause_hub_btn:
		var sd: Node = get_node_or_null("/root/StoryDirector")
		pause_hub_btn.visible = sd == null or not bool(sd.get("active"))   # no stage picking in the middle of the story
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
	card.add_theme_stylebox_override("panel", GameFX.make_panel_style(GameFX.UI_DEFAULT, Color(0.05, 0.07, 0.12, 0.97), 12))
	center.add_child(card)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	pause_title = GameFX.make_label("⏸ TẠM DỪNG", 26, GameFX.ui_accent())
	vb.add_child(pause_title)
	var sub: Label = GameFX.make_label("Thời gian trong game đã dừng. Giảng viên vẫn chưa điểm danh… tranh thủ đi.", 13, Color("#BDC3C7"))
	vb.add_child(sub)

	pause_resume_btn = _pause_button("▶   TIẾP TỤC  [ESC]")
	pause_resume_btn.pressed.connect(resume_game)
	vb.add_child(pause_resume_btn)
	var settings_btn: Button = _pause_button("⚙   CÀI ĐẶT (đồ hoạ · âm lượng)")
	settings_btn.pressed.connect(func() -> void:
		pause_settings_box.visible = not pause_settings_box.visible
		pause_controls_scroll.visible = false)
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
		var qb: Button = _pause_button(_pause_quality_text(q))
		qb.name = "PauseQuality%d" % q
		qb.custom_minimum_size = Vector2(170, 48)
		qb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		qb.add_theme_font_size_override("font_size", 13)
		qb.pressed.connect(func() -> void:
			GameFX.set_visual_quality(q)
			var cs: Node = get_tree().current_scene
			if cs:
				GameFX.upgrade_scene_visuals(cs, String(cs.get_meta("visual_preset", "morning")))
			_refresh_pause_quality()
			GameFX.play_ui("pop", -6.0))
		qrow.add_child(qb)
		pause_quality_buttons.append(qb)
	# Phong cách đồ hoạ (Vice City / Cổ điển) + vệt sáng: đổi là áp lại preset ánh sáng của màn đang chơi, không nạp lại;
	# chú thích nút mức đồ hoạ theo phong cách mới
	GameFX.build_style_settings(pause_settings_box)
	GameFX.art_style_changed.connect(_on_art_style_changed)
	GameFX.build_audio_settings(pause_settings_box)
	GameFX.build_story_settings(pause_settings_box, true)   # "Giảm hù dọa" (A2-D14) in the style row: card stays < 720 px

	var controls_btn: Button = _pause_button("🎮   ĐIỀU KHIỂN")
	controls_btn.pressed.connect(func() -> void:
		pause_controls_scroll.visible = not pause_controls_scroll.visible
		pause_settings_box.visible = false)
	vb.add_child(controls_btn)
	# Bảng phím (9 dòng) cuộn trong khung cao tối đa PAUSE_CONTROLS_MAX_H như danh sách Campaign Hub
	pause_controls_scroll = ScrollContainer.new()
	pause_controls_scroll.name = "ControlsScroll"
	pause_controls_scroll.custom_minimum_size = Vector2(0, PAUSE_CONTROLS_MAX_H)
	pause_controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_controls_scroll.visible = false
	vb.add_child(pause_controls_scroll)
	pause_controls_box = VBoxContainer.new()
	pause_controls_box.add_theme_constant_override("separation", 4)
	pause_controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_controls_scroll.add_child(pause_controls_box)
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
	pause_hub_btn = hub_btn
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
	# viền: classic cam (UI_DEFAULT = cam FPT ở classic), vice hồng (nút không mang thương hiệu FPT)
	b.add_theme_stylebox_override("normal", GameFX.make_panel_style(Color(0.95, 0.44, 0.13, 0.55), Color(0.07, 0.09, 0.15, 0.9), 10))
	b.add_theme_stylebox_override("hover", GameFX.make_panel_style(GameFX.UI_DEFAULT, Color(0.1, 0.12, 0.2, 0.96), 10))
	b.add_theme_stylebox_override("focus", GameFX.make_panel_style(GameFX.UI_DEFAULT, Color(0.1, 0.12, 0.2, 0.96), 10))
	b.add_theme_stylebox_override("pressed", GameFX.make_panel_style(Color("#F1C40F"), Color(0.18, 0.1, 0.03, 0.98), 10))
	b.mouse_entered.connect(func() -> void: GameFX.play_ui("tick", -12.0, 1.4))
	return b

## Chữ trên nút mức đồ hoạ q của menu tạm dừng theo phong cách hiện tại: "🟢 Thấp\nbóng cơ bản"...
func _pause_quality_text(q: int) -> String:
	var cap: PackedStringArray = GameFX.quality_caption(q)
	return "%s %s\n%s" % [["🟢", "🟡", "🔴"][q], ["Thấp", "Trung bình", "Cao"][q], cap[1]]

func _on_art_style_changed(_style: String) -> void:
	_restyle_ui()

## Giao diện của StageManager (menu tạm dừng, thẻ chuyển cảnh, nút "Về campus", tiêu đề Campaign Hub) theo phong cách
## hiện tại: GameFX.restyle_tree() dựng lại kiểu do helper tạo, rồi các chi tiết riêng. Gọi trì hoãn sau _ready (autoload
## GameFX nạp settings.cfg sau StageManager nên lúc dựng chưa biết phong cách đã lưu) và mỗi lần đổi phong cách.
func _restyle_ui() -> void:
	for layer: CanvasLayer in [pause_layer, transition_layer, roam_return_layer]:
		if layer:
			GameFX.restyle_tree(layer)
	if pause_title:
		pause_title.add_theme_color_override("font_color", GameFX.ui_accent())
	if hub_title:
		hub_title.add_theme_color_override("font_color", GameFX.ui_accent())
	_style_transition()
	_refresh_pause_quality()

## Thẻ chuyển cảnh: vice = đồng hồ chữ nghiêng vàng pastel, dải gradient pastel, tên màn hồng, nền tím than; classic =
## như cũ (đồng hồ vàng, tên màn cam, nền xanh đen).
func _style_transition() -> void:
	if transition_clock == null:
		return
	var vice: bool = GameFX.is_vice_ui()
	transition_clock.add_theme_color_override("font_color", Color("#FFD166") if vice else Color("#F1C40F"))
	transition_clock.add_theme_constant_override("outline_size", 12)
	transition_clock.add_theme_color_override("font_outline_color", GameFX.VICE_INK if vice else Color(0.02, 0.03, 0.06, 0.9))
	if vice:
		transition_clock.add_theme_font_override("font", GameFX.vice_font(0.9, 0.28))
	else:
		transition_clock.remove_theme_font_override("font")
	transition_sub.add_theme_color_override("font_color", GameFX.ui_accent())
	if transition_strip:
		transition_strip.visible = vice
	var dim: ColorRect = transition_layer.get_node_or_null("Dim") as ColorRect
	if dim:
		var base: Color = Color(0.04, 0.02, 0.09) if vice else Color(0.02, 0.03, 0.06)
		dim.color = Color(base.r, base.g, base.b, dim.color.a)

func _refresh_pause_quality() -> void:
	for q: int in range(pause_quality_buttons.size()):
		var b: Button = pause_quality_buttons[q]
		b.text = _pause_quality_text(q)
		var active: bool = q == GameFX.visual_quality
		b.add_theme_color_override("font_color", Color("#F1C40F") if active else Color("#F4F5F6"))

# ---------------------------------------------------------------------------
# CHUYỂN MÀN
# ---------------------------------------------------------------------------
## `from_roam` = true chỉ khi vào từ hotspot của thế giới mở (start_stage_from_roam); mọi đường khác ("Màn tiếp",
## "Chơi lại toàn bộ chiến dịch", Campaign Hub...) tắt return_to_roam và quên roam_spawn.
func change_stage(stage_id: int, from_roam: bool = false) -> void:
	if not stage_scenes.has(stage_id):
		return
	if stage_id == StageID.FREE_ROAM:
		go_to_roam()
		return
	typing_mode = false
	_hide_roam_return()
	if modal_layer:
		modal_layer.visible = false
	if pause_layer and pause_layer.visible:
		pause_layer.visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if transition_active:
		return
	return_to_roam = from_roam
	if not from_roam:
		roam_spawn = null
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
	if from_stage == -1 and return_to_roam:
		return "Từ thế giới mở bước vào màn chơi. Xong màn là quay lại campus ngay."
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
	if cs and not (cs is MainMenu) and stage_info.has(current_stage):
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
	vb.add_child(transition_clock)
	# dải gradient pastel giữa đồng hồ và tên màn: chỉ ở phong cách vice
	transition_strip = GameFX.pastel_strip(6.0)
	transition_strip.custom_minimum_size = Vector2(520.0, 6.0)
	transition_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	transition_strip.set_meta("vice_only", true)
	vb.add_child(transition_strip)
	transition_sub = GameFX.make_label("", 22, GameFX.ui_accent())
	transition_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(transition_sub)
	_style_transition()
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

## The story owns stage launches: no Campaign Hub (M, Ctrl/Shift+Tab, stage buttons) while a story runs (review A2-R4).
func _story_blocks_hub() -> bool:
	if not story_context.is_empty():
		return true
	var sd: Node = get_node_or_null("/root/StoryDirector")
	return sd != null and bool(sd.get("active"))

func toggle_stage_select() -> void:
	if modal_layer and not modal_layer.visible and _story_blocks_hub():
		return
	if modal_layer:
		modal_layer.visible = not modal_layer.visible
		if modal_layer.visible:
			_refresh_rank_labels()

func open_stage_select() -> void:
	if _story_blocks_hub():
		return
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

## Màn chơi gọi khi kết thúc: result = {"result": "win"|"fail", "score": int, "rank": "S|A|B|C", "detail": String,
## "caught": bool (tuỳ chọn: thua vì bị bắt -> thẻ "BỊ BẮT")}. Thắng được trả Cóc Vàng theo rank (RANK_COINS); số xu
## ghi lại vào result["coins"] (thua: 0).
func report_stage_result(stage_id: int, result: Dictionary) -> void:
	# story beat (A2-D11): StoryDirector completes the beat on a win and replaces the card buttons
	var sd: Node = get_node_or_null("/root/StoryDirector") if int(story_context.get("stage", -1)) == stage_id else null
	var won: bool = result.get("result", "") == "win"
	var coins: int = int(RANK_COINS.get(String(result.get("rank", "C")), RANK_COINS["C"])) if won else 0
	result["coins"] = coins
	run_stats[stage_id] = result
	var b: Dictionary = best_stats.get(stage_id, {"score": 0, "rank": "", "wins": 0, "plays": 0})
	b["plays"] = int(b.get("plays", 0)) + 1
	if won:
		b["wins"] = int(b.get("wins", 0)) + 1
		if int(result.get("score", 0)) >= int(b.get("score", 0)):
			b["score"] = int(result.get("score", 0))
			b["rank"] = String(result.get("rank", "B"))
	best_stats[stage_id] = b
	if coins > 0:
		earn(coins, "stage_%d_rank_%s" % [stage_id, String(result.get("rank", "C"))])   # earn() lưu cả kỷ lục
	else:
		save_progress()
	if sd:
		sd.call("on_stage_result", stage_id, result)
	_refresh_rank_labels()
	_apply_result_card(result)
	if return_to_roam and sd == null:
		_show_roam_return()

## Thẻ kết quả của màn (HUD/ModalOverlay/.../VBox ở Màn 2..Extra, HUD/AbsentOverlay/.../VBoxContainer ở Màn 1): ở
## phong cách vice chèn lên đầu thẻ khối "ViceResult" = tiêu đề nghiêng lớn (result_banner_title), dải gradient pastel,
## dòng "+N Cóc Vàng" khi thắng; nền phủ + panel thẻ sang giao diện vice. Báo kết quả lần nữa thì thay khối cũ (không
## chồng); classic chỉ gỡ khối cũ nếu có. Màn chơi gọi report_stage_result ngay trước khi hiện thẻ nên khối có sẵn khi
## thẻ mờ dần lên.
func _apply_result_card(result: Dictionary) -> void:
	var vb: VBoxContainer = _result_card_box()
	if vb == null:
		return
	var old: Node = vb.get_node_or_null("ViceResult")
	if old:
		vb.remove_child(old)
		old.queue_free()
	if not GameFX.is_vice_ui():
		return
	var n: Node = vb.get_parent()
	while n and not (n is CanvasLayer):
		if n is PanelContainer:
			(n as PanelContainer).add_theme_stylebox_override("panel", GameFX.make_panel_style(GameFX.UI_DEFAULT, Color(0.07, 0.04, 0.14, 0.97)))
		elif n is ColorRect:
			var cr: ColorRect = n
			cr.color = Color(0.05, 0.02, 0.1, maxf(cr.color.a, 0.9))
			# nền phủ lên trên mọi panel HUD thêm bằng code sau .tscn (bảng thưởng / chuỗi sát nút của Màn 1)
			if cr.get_parent() is CanvasLayer:
				cr.get_parent().move_child(cr, cr.get_parent().get_child_count() - 1)
		n = n.get_parent()
	# tiêu đề riêng của màn: màn tô bằng modulate (đỏ / xanh) nhân với màu chữ .tscn (xanh lá) -> chữ trắng để màu
	# modulate hiện đúng (đỏ x xanh lá ra màu ô liu tối khó đọc)
	var stage_title: Label = vb.get_node_or_null("TitleLabel") as Label
	if stage_title:
		stage_title.add_theme_color_override("font_color", Color.WHITE)
	var won: bool = result.get("result", "") == "win"
	var caught: bool = not won and bool(result.get("caught", false))
	var box := VBoxContainer.new()
	box.name = "ViceResult"
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.name = "BannerTitle"
	title.text = result_banner_title(result)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", GameFX.vice_font(0.9, 0.28))
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GameFX.VICE_PINK if won else (GameFX.VICE_CYAN if caught else Color("#FF5F7E")))
	title.add_theme_color_override("font_outline_color", GameFX.VICE_INK)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	box.add_child(GameFX.pastel_strip(6.0))
	var coins: int = int(result.get("coins", 0))
	if coins > 0:
		var cl := Label.new()
		cl.name = "BannerCoins"
		cl.text = coins_text(coins)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.add_theme_font_override("font", GameFX.vice_font(0.6, 0.22))
		cl.add_theme_font_size_override("font_size", 24)
		cl.add_theme_color_override("font_color", Color("#9BEA7A"))
		cl.add_theme_color_override("font_outline_color", Color("#0B1A06"))
		cl.add_theme_constant_override("outline_size", 6)
		box.add_child(cl)
	vb.add_child(box)
	vb.move_child(box, 0)

## VBox của thẻ kết quả trong cảnh đang chơi (current_scene; test --script thêm màn thẳng vào root nên dò cả các con
## của root, mới nhất trước).
func _result_card_box() -> VBoxContainer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var candidates: Array[Node] = []
	if tree.current_scene:
		candidates.append(tree.current_scene)
	for i: int in range(tree.root.get_child_count() - 1, -1, -1):
		var ch: Node = tree.root.get_child(i)
		if ch != self and ch != tree.current_scene and ch.name != "GameFX":
			candidates.append(ch)
	for cand: Node in candidates:
		for path: String in ["HUD/ModalOverlay/Center/Card/Margin/VBox", "HUD/AbsentOverlay/CenterContainer/VBoxContainer"]:
			var vb: VBoxContainer = cand.get_node_or_null(path) as VBoxContainer
			if vb:
				return vb
	return null

## Tiêu đề lớn của thẻ kết quả (phong cách vice): thắng "QUA MÔN!", thua vì bị bắt "BỊ BẮT", thua "TRƯỢT MÔN".
static func result_banner_title(result: Dictionary) -> String:
	if result.has("story"):   # story beat (story spec 7): "QUA MÔN! Uy tín +" / "TOANG!"
		return "QUA MÔN! Uy tín +" if String(result["story"]) == "win" else "TOANG!"
	if result.get("result", "") == "win":
		return "QUA MÔN!"
	if bool(result.get("caught", false)):
		return "BỊ BẮT"
	return "TRƯỢT MÔN"

## Dòng thưởng dưới tiêu đề thẻ kết quả: "+30 Cóc Vàng".
static func coins_text(coins: int) -> String:
	return "+%d Cóc Vàng" % coins

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
	title.add_theme_color_override("font_color", GameFX.ui_accent())
	header_hbox.add_child(title)
	hub_title = title

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
		play_btn.pressed.connect(func() -> void: change_stage(stage_id)) # từ hub: from_roam = false
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
