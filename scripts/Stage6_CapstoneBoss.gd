# File: res://scripts/Stage6_CapstoneBoss.gd
# MÀN 6: BOSS FIGHT CAPSTONE 23:59 – BULLET-HELL GÕ CHỮ
#   - Boss "Quái vật Deadline" phóng "viên đạn lỗi" (404, null, NPE, merge...) rơi xuống 4 làn ứng 4 thành viên.
#   - Gõ đúng tên lỗi để bắn hạ (sát thương = độ dài × combo). Đạn chạm đáy -> thành viên làn đó mất HP.
#   - [Tab] đổi thành viên điều khiển, [Enter] dùng skill có cooldown. Bạn "seen không rep" đang NGỦ:
#     chọn + [Enter] -> mash [SPACE] gọi điện tới khi bắt máy mới mở skill "git merge".
#   - Boss còn 40% HP -> pha Git Merge Conflict: 3 lần chọn [←]/[→] đúng khối code trong 8s.
#   - Cuối cùng gõ "git push origin main" để nộp đồ án. 2 thành viên gục hoặc hết giờ 23:59 = thua.
class_name Stage6_CapstoneBoss
extends Node3D

@onready var clock_label: Label = $HUD/TopBar/ClockPanel/ClockLabel
@onready var boss_hp_bar: ProgressBar = $HUD/TopBar/BossPanel/VBox/BossHPBar
@onready var boss_name_lbl: Label = $HUD/TopBar/BossPanel/VBox/BossNameLabel
@onready var combat_log: Label = $HUD/LogPanel/LogLabel
@onready var log_panel: PanelContainer = $HUD/LogPanel
@onready var actions_panel: PanelContainer = $HUD/ActionsPanel
@onready var actions_hbox: HBoxContainer = $HUD/ActionsPanel/HBox

@onready var git_panel: PanelContainer = $HUD/CenterModals/GitConflictModal
@onready var git_vbox: VBoxContainer = $HUD/CenterModals/GitConflictModal/Margin/VBox
@onready var git_title: Label = $HUD/CenterModals/GitConflictModal/Margin/VBox/Title
@onready var git_desc: Label = $HUD/CenterModals/GitConflictModal/Margin/VBox/Desc
@onready var resolve_btn: Button = $HUD/CenterModals/GitConflictModal/Margin/VBox/ResolveButton

@onready var modal_overlay: ColorRect = $HUD/ModalOverlay
@onready var modal_title: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/TitleLabel
@onready var modal_sub: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/SubLabel
@onready var extra_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/ExtraButton
@onready var menu_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/MenuButton
@onready var retry_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/RetryButton

@onready var boss_core: MeshInstance3D = $Arena/DeadlineBoss/BossCore
@onready var boss_root: Node3D = $Arena/DeadlineBoss
@onready var laptop_screen: MeshInstance3D = $Arena/LaptopScreen
@onready var hud: CanvasLayer = $HUD

enum State { INTRO, BATTLE, GIT, FINAL_PUSH, WIN, LOSE }

const BATTLE_TIME: float = 90.0
const BOSS_MAX_HP: float = 1600.0 # ~27 từ gõ đúng với combo trung bình -> boss gục ở giây ~60-70
const LANE_COUNT: int = 4
const WORDS_W1: Array[String] = ["404", "500", "null", "lag", "typo", "bug", "NaN", "undefined"]
const WORDS_W2: Array[String] = ["NPE", "CORS", "leak", "OOM", "regex", "merge", "crash", "timeout", "403"]
const WORDS_W3: Array[String] = ["deadlock", "segfault", "overflow", "conflict", "rollback", "hotfix", "race", "panic"]
const FINAL_COMMAND: String = "git push origin main"

const CONFLICT_POOL: Array = [
	{"hint": "Bản nào gọi đúng hàm submitCapstone() với ĐỦ 2 tham số?", "head": "submitCapstone(team);", "theirs": "submitCapstone(team, deadline);", "correct": KEY_RIGHT},
	{"hint": "Bản nào KHÔNG dính NullPointerException?", "head": "if (user != null) user.save();", "theirs": "user.save();", "correct": KEY_LEFT},
	{"hint": "Bản nào đúng cú pháp Java?", "head": "int score = 10", "theirs": "int score = 10;", "correct": KEY_RIGHT},
	{"hint": "Bản nào gõ ĐÚNG tên nhánh nộp bài?", "head": "git push origin main", "theirs": "git push origin mian", "correct": KEY_LEFT},
	{"hint": "Bản nào KHÔNG hardcode mật khẩu database?", "head": "password = \"123456\";", "theirs": "password = env(\"DB_PASS\");", "correct": KEY_RIGHT},
	{"hint": "Vòng lặp nào KHÔNG chạy vô hạn?", "head": "for (i = 0; i < n; i++)", "theirs": "for (i = 0; i < n; i--)", "correct": KEY_LEFT},
	{"hint": "Bản nào trả về đúng kiểu boolean?", "head": "return isValid;", "theirs": "return \"true\";", "correct": KEY_LEFT}
]

var state: int = State.INTRO
var intro_timer: float = 2.0
var time_left: float = BATTLE_TIME
var boss_hp: float = BOSS_MAX_HP
var score: int = 0
var combo: int = 0
var max_combo: int = 0
var words_destroyed: int = 0
var typos: int = 0
var members: Array[Dictionary] = []
var active_idx: int = 0
var bullets: Array[Dictionary] = []
var spawn_timer: float = 1.2
var freeze_timer: float = 0.0
var typed: String = ""
var locked: Dictionary = {}
var phone_active: bool = false
var phone_presses: int = 0
var phone_timer: float = 0.0
var phone_cd: float = 0.0
var conflicts: Array = []
var conflict_idx: int = 0
var conflict_timer: float = 0.0
var conflicts_right: int = 0
var final_bullet: Dictionary = {}
var hits_taken: int = 0

# UI tạo bằng code
var arena: Control
var lane_rects: Array[ColorRect] = []
var member_cards: Array[Dictionary] = []
var typing_label: Label
var hint_label: Label
var phone_panel: PanelContainer
var phone_label: Label
var phone_bar: ProgressBar
var git_head_lbl: Label
var git_theirs_lbl: Label
var git_bar: ProgressBar
var log_lines: Array[String] = []
var team_people: Array[Node3D] = []
var team_meshes: Array[Node3D] = []
var sleep_label: Label3D

func _ready() -> void:
	modal_overlay.visible = false
	git_panel.visible = false
	resolve_btn.visible = false

	_apply_laptop_texture()
	_init_members()
	_build_team_meshes()
	_build_lab_night_world()
	_build_arena_ui()
	_build_member_cards()
	_build_typing_ui()
	_build_git_ui()

	extra_btn.pressed.connect(_on_extra_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	for b: Button in [extra_btn, menu_btn, retry_btn]:
		b.focus_mode = Control.FOCUS_NONE

	StageManager.typing_mode = true
	GameFX.upgrade_scene_visuals(self, "night")
	GameFX.music_play("capstone", 0.3)
	_log("⚔️ 23:57:30 – QUÁI VẬT DEADLINE XUẤT HIỆN! GÕ TÊN LỖI ĐỂ BẮN HẠ. [TAB] ĐỔI NGƯỜI · [ENTER] SKILL")
	_update_boss_ui()

func _exit_tree() -> void:
	StageManager.typing_mode = false

func _apply_laptop_texture() -> void:
	var path: String = "res://assets/textures/capstone_code_screen.png"
	if FileAccess.file_exists(path):
		var img: Image = GameFX.load_image_any(path)
		if img:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var qm := QuadMesh.new()
			qm.size = Vector2(2.4, 1.35)
			laptop_screen.mesh = qm
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.emission_enabled = true
			mat.emission_texture = tex
			mat.emission_energy_multiplier = 0.8
			laptop_screen.material_override = mat

func _init_members() -> void:
	members = [
		{"name": "LEADER", "icon": "💻", "hp": 100.0, "awake": true, "down": false,
		 "skill": "Clean Architecture", "skill_desc": "xóa 3 đạn thấp nhất", "cd": 10.0, "cd_left": 0.0, "shield": 0, "color": Color("#F37021")},
		{"name": "FRONTEND", "icon": "🎨", "hp": 100.0, "awake": true, "down": false,
		 "skill": "CSS Shield", "skill_desc": "chặn 3 đạn làn mình", "cd": 12.0, "cd_left": 0.0, "shield": 0, "color": Color("#3498DB")},
		{"name": "TESTER QA", "icon": "📑", "hp": 100.0, "awake": true, "down": false,
		 "skill": "Ném SRS 300 trang", "skill_desc": "đóng băng đạn 2.5s", "cd": 15.0, "cd_left": 0.0, "shield": 0, "color": Color("#2ECC71")},
		{"name": "SEEN KO REP", "icon": "📞", "hp": 100.0, "awake": false, "down": false,
		 "skill": "git merge", "skill_desc": "hồi 40 HP cả team", "cd": 20.0, "cd_left": 0.0, "shield": 0, "color": Color("#9B59B6")}
	]

# ===========================================================================
# 3D
# ===========================================================================
func _build_team_meshes() -> void:
	# 4 thành viên nhóm Capstone (CharacterBuilder) ngồi gõ máy; người thứ 4 đang ngủ gục dưới sàn
	for i: int in range(LANE_COUNT):
		var m: Dictionary = members[i]
		var root := Node3D.new()
		root.position = Vector3(-2.1 + i * 1.4, 0.0, 2.6)
		$Arena.add_child(root)
		var person: Node3D = CharacterBuilder.build({"preset": "student", "seed": 600 + i * 29, "name": "Member%d" % i, "shirt_color": m["color"], "backpack": false, "clip": "type" if m["awake"] else "lie"})
		root.add_child(person)
		team_people.append(person)
		var lbl := Label3D.new()
		lbl.text = "%s %s" % [m["icon"], m["name"]]
		lbl.font_size = 22
		lbl.outline_size = 8
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0.0, 1.75, 0.0)
		root.add_child(lbl)
		if not m["awake"]:
			root.rotation_degrees.z = 80.0
			root.position.y = 0.3
			sleep_label = Label3D.new()
			sleep_label.text = "💤 zZz (seen lúc 22:03)"
			sleep_label.font_size = 26
			sleep_label.outline_size = 8
			sleep_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sleep_label.position = Vector3(0.0, 2.3, 0.0)
			root.add_child(sleep_label)
		team_meshes.append(root)

## LAB 402 LÚC 23:57: cùng căn phòng Màn 3 nhưng đêm – campus tối ngoài cửa sổ, đèn trần + màn hình là nguồn sáng.
func _build_lab_night_world() -> void:
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var c: Vector3 = FPTUCampusBuilder.lab402_room_center()
	var world := Node3D.new()
	world.name = "CampusWorld"
	world.position = Vector3(c.x, -c.y, c.z)
	world.rotation_degrees.y = 180.0
	$Arena.add_child(world)
	FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": false})
	FPTUCampusBuilder.build_hutech(world, Vector3(135.0, 0.0, -26.0), cm)
	FPTUCampusBuilder.build_d1_road_piece(world, -13.0, -80.0, 300.0, cm, 0.0)
	FPTUCampusBuilder.build_room_interior($Arena, FPTUCampusBuilder.lab402_room_size(), cm, {
		"windows": ["+x", "+z"], "door": "+z", "door_x": 0.86, "board_side": "-x", "name": "LAB 402", "night": true
	})
	# Bàn máy của 4 thành viên (sau lưng hàng người), bàn giữa đặt laptop chung, pizza & lon nước thức đêm
	for i: int in range(LANE_COUNT):
		FPTUCampusBuilder.build_lab_desk($Arena, Vector3(-2.1 + i * 1.4, 0.0, 3.7), cm, 1, 0.0, "chair_orange", 1.3)
	FPTUCampusBuilder.build_lab_desk($Arena, Vector3(0.0, 0.0, 1.5), cm, 0, 0.0, "chair_orange", 3.0)
	var mat_pizza := StandardMaterial3D.new()
	mat_pizza.albedo_color = Color("#D9B47A")
	for pz: Vector3 in [Vector3(-1.1, 0.79, 1.4), Vector3(1.2, 0.79, 1.55)]:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.05, 0.45)
		box.mesh = bm
		box.material_override = mat_pizza
		box.position = pz
		$Arena.add_child(box)
	var mat_can := StandardMaterial3D.new()
	mat_can.albedo_color = Color("#27AE60")
	mat_can.metallic = 0.6
	mat_can.emission_enabled = true
	mat_can.emission = Color("#2ECC71") * 0.4
	for cz: Vector3 in [Vector3(-0.5, 0.86, 1.3), Vector3(0.3, 0.86, 1.7), Vector3(-2.3, 0.86, 3.5), Vector3(0.9, 0.86, 3.6)]:
		var can := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.035
		cm2.bottom_radius = 0.035
		cm2.height = 0.16
		can.mesh = cm2
		can.material_override = mat_can
		can.position = cz
		$Arena.add_child(can)
	# Boss hạ xuống dưới trần 3.3 m; camera vào trong phòng
	boss_root.position.y = 1.9
	$Camera3D.global_position = Vector3(0.0, 3.0, 5.3)
	$Camera3D.look_at(Vector3(0.0, 1.5, -1.6), Vector3.UP)
	$DirectionalLight3D.rotation_degrees = Vector3(-34.0, 58.0, 0.0)

# ===========================================================================
# UI
# ===========================================================================
func _build_arena_ui() -> void:
	arena = Control.new()
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.offset_top = 92.0
	arena.offset_bottom = -250.0
	arena.offset_left = 120.0
	arena.offset_right = -120.0
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.clip_contents = true
	hud.add_child(arena)
	hud.move_child(arena, 0)
	for i: int in range(LANE_COUNT):
		var r := ColorRect.new()
		r.color = Color(0.1, 0.12, 0.2, 0.22) if i % 2 == 0 else Color(0.06, 0.08, 0.14, 0.22)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arena.add_child(r)
		lane_rects.append(r)
	# Vạch "deadline" dưới đáy
	var line := ColorRect.new()
	line.color = Color(1.0, 0.25, 0.25, 0.7)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.name = "DeadlineLine"
	arena.add_child(line)

func _layout_arena() -> void:
	var w: float = arena.size.x / float(LANE_COUNT)
	for i: int in range(LANE_COUNT):
		var r: ColorRect = lane_rects[i]
		r.position = Vector2(i * w, 0.0)
		r.size = Vector2(w - 2.0, arena.size.y)
		var m: Dictionary = members[i]
		if i == active_idx:
			r.color = Color(0.95, 0.44, 0.13, 0.16)
		elif m["down"]:
			r.color = Color(0.3, 0.05, 0.05, 0.3)
		elif m["shield"] > 0:
			r.color = Color(0.2, 0.55, 0.95, 0.2)
		else:
			r.color = Color(0.1, 0.12, 0.2, 0.22) if i % 2 == 0 else Color(0.06, 0.08, 0.14, 0.22)
	var line: ColorRect = arena.get_node("DeadlineLine")
	line.position = Vector2(0.0, arena.size.y - 4.0)
	line.size = Vector2(arena.size.x, 4.0)

func _build_member_cards() -> void:
	for c: Node in actions_hbox.get_children():
		c.queue_free()
	actions_hbox.add_theme_constant_override("separation", 10)
	for i: int in range(LANE_COUNT):
		var m: Dictionary = members[i]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 96)
		actions_hbox.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		card.add_child(vb)
		var btn := Button.new()
		btn.text = "%s %s" % [m["icon"], m["name"]]
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(func() -> void: _select_member(i))
		vb.add_child(btn)
		var hp := GameFX.make_bar(100.0, m["color"], 12)
		vb.add_child(hp)
		var sk := GameFX.make_label("", 11, Color("#DFE6E9"))
		vb.add_child(sk)
		member_cards.append({"card": card, "btn": btn, "hp": hp, "skill": sk})
	_refresh_cards()

func _refresh_cards() -> void:
	for i: int in range(LANE_COUNT):
		var m: Dictionary = members[i]
		var c: Dictionary = member_cards[i]
		var hp_bar: ProgressBar = c["hp"]
		hp_bar.value = m["hp"]
		var sk: Label = c["skill"]
		if m["down"]:
			sk.text = "💀 GỤC – không còn gõ nổi"
		elif not m["awake"]:
			sk.text = "💤 ĐANG NGỦ – chọn + [Enter] để gọi dậy"
		elif m["cd_left"] > 0.0:
			sk.text = "%s (%.0fs)" % [m["skill"], m["cd_left"]]
		else:
			sk.text = "✅ [Enter] %s: %s" % [m["skill"], m["skill_desc"]]
		if m["shield"] > 0:
			sk.text += " · 🛡x%d" % m["shield"]
		var card: PanelContainer = c["card"]
		var border: Color = Color("#F37021") if i == active_idx else Color(0.3, 0.35, 0.45)
		if m["down"]:
			border = Color("#E74C3C")
		card.add_theme_stylebox_override("panel", GameFX.make_panel_style(border, Color(0.06, 0.08, 0.14, 0.95), 8))

func _build_typing_ui() -> void:
	var panel: PanelContainer = GameFX.anchored_panel(hud, Control.PRESET_CENTER_BOTTOM, Vector2(760, 0), 24, Color("#F1C40F"))
	# đặt ngay trên LogPanel: dời lên bằng margin bottom lớn hơn
	var holder: MarginContainer = panel.get_parent()
	holder.add_theme_constant_override("margin_bottom", 236)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	typing_label = GameFX.make_label("ĐANG GÕ: _", 24, Color("#F1C40F"))
	vb.add_child(typing_label)
	hint_label = GameFX.make_label("Gõ chữ trên viên đạn để bắn · [Backspace] xóa · [Tab] đổi người · [Enter] skill", 12, Color("#BDC3C7"))
	vb.add_child(hint_label)

	phone_panel = GameFX.anchored_panel(hud, Control.PRESET_CENTER, Vector2(520, 0), 24, Color("#9B59B6"))
	phone_panel.visible = false
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	phone_panel.add_child(pv)
	pv.add_child(GameFX.make_label("📞 ĐANG GỌI BẠN SEEN KHÔNG REP...", 22, Color("#9B59B6")))
	phone_label = GameFX.make_label("MASH [SPACE] 0 / 14 – còn 4.0s", 18, Color.WHITE)
	pv.add_child(phone_label)
	phone_bar = GameFX.make_bar(0.0, Color("#9B59B6"), 18)
	pv.add_child(phone_bar)

func _build_git_ui() -> void:
	git_desc.text = ""
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	git_vbox.add_child(hb)
	for side: int in range(2):
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pc.add_theme_stylebox_override("panel", GameFX.make_panel_style(Color("#2ECC71") if side == 0 else Color("#3498DB"), Color(0.03, 0.05, 0.08, 0.98), 6))
		hb.add_child(pc)
		var vb := VBoxContainer.new()
		pc.add_child(vb)
		vb.add_child(GameFX.make_label("[←] <<<<<<< HEAD (code của bạn)" if side == 0 else "[→] >>>>>>> feature/teammate", 13, Color("#2ECC71") if side == 0 else Color("#3498DB")))
		var code := GameFX.make_label("", 18, Color.WHITE)
		code.add_theme_font_override("font", ThemeDB.fallback_font)
		vb.add_child(code)
		if side == 0:
			git_head_lbl = code
		else:
			git_theirs_lbl = code
	git_bar = GameFX.make_bar(100.0, Color("#E74C3C"), 12)
	git_vbox.add_child(git_bar)

func _log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 2:
		log_lines.remove_at(0)
	combat_log.text = "\n".join(log_lines)

func _update_boss_ui() -> void:
	boss_hp_bar.value = boss_hp / BOSS_MAX_HP * 100.0
	GameFX.music_tension(0.3 + 0.7 * (1.0 - boss_hp / BOSS_MAX_HP))
	boss_name_lbl.text = "👾 QUÁI VẬT DEADLINE 23:59 · HP %d/%d · COMBO x%d (%d) · ĐIỂM %d" % [int(boss_hp), int(BOSS_MAX_HP), _mult(), combo, score]

func _mult() -> int:
	return 1 + mini(combo / 6, 2)

# ===========================================================================
# INPUT
# ===========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if state == State.WIN or state == State.LOSE or state == State.INTRO:
		return
	if not (event is InputEventKey and event.is_pressed()):
		return
	var key: int = event.physical_keycode
	if state == State.GIT:
		if not event.is_echo() and (key == KEY_LEFT or key == KEY_RIGHT or key == KEY_A or key == KEY_D):
			_resolve_conflict(KEY_LEFT if (key == KEY_LEFT or key == KEY_A) else KEY_RIGHT)
		get_viewport().set_input_as_handled()
		return
	if event.is_echo() and key != KEY_BACKSPACE:
		return
	match key:
		KEY_TAB:
			_cycle_member()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_use_skill()
		KEY_BACKSPACE:
			if typed.length() > 0:
				typed = typed.substr(0, typed.length() - 1)
				_relock()
		KEY_SPACE:
			if phone_active:
				_phone_press()
			elif state == State.FINAL_PUSH:
				_type_char(" ")
		KEY_ESCAPE:
			typed = ""
			locked = {}
		_:
			var uni: int = event.unicode
			if uni > 32 and uni < 127:
				var ch: String = String.chr(uni).to_lower()
				_type_char(ch)
	_refresh_typing_label()

func _type_char(ch: String) -> void:
	var candidate: String = typed + ch
	# Ưu tiên viên đạn đang khóa
	if not locked.is_empty() and _bullet_alive(locked) and str(locked["word"]).to_lower().begins_with(candidate):
		typed = candidate
	else:
		var found: Dictionary = _find_bullet_with_prefix(candidate)
		if found.is_empty():
			typos += 1
			combo = 0
			typed = ""
			locked = {}
			GameFX.play_sfx("error", -10.0)
			typing_label.add_theme_color_override("font_color", Color("#E74C3C"))
			_update_boss_ui()
			return
		locked = found
		typed = candidate
	GameFX.play_sfx("typing", -6.0, randf_range(0.9, 1.1))
	typing_label.add_theme_color_override("font_color", Color("#F1C40F"))
	_refresh_bullet_label(locked)
	if typed == str(locked["word"]).to_lower():
		_destroy_bullet(locked, true)
		typed = ""
		locked = {}

func _relock() -> void:
	if typed.is_empty():
		locked = {}
		return
	if not locked.is_empty() and _bullet_alive(locked) and str(locked["word"]).to_lower().begins_with(typed):
		_refresh_bullet_label(locked)
		return
	locked = _find_bullet_with_prefix(typed)

func _bullet_alive(b: Dictionary) -> bool:
	return not b.is_empty() and not b.get("dead", false) and is_instance_valid(b.get("node"))

func _find_bullet_with_prefix(prefix: String) -> Dictionary:
	var best: Dictionary = {}
	var best_y: float = -1.0
	var pool: Array = bullets.duplicate()
	if not final_bullet.is_empty():
		pool.append(final_bullet)
	for b: Dictionary in pool:
		if not _bullet_alive(b):
			continue
		if str(b["word"]).to_lower().begins_with(prefix) and float(b["y"]) > best_y:
			best_y = float(b["y"])
			best = b
	return best

func _refresh_typing_label() -> void:
	if typed.is_empty():
		typing_label.text = "ĐANG GÕ: _"
	else:
		var rest: String = ""
		if not locked.is_empty() and _bullet_alive(locked):
			rest = str(locked["word"]).substr(typed.length())
		typing_label.text = "ĐANG GÕ: %s▌%s" % [typed.to_upper(), rest.to_lower()]

# ===========================================================================
# VÒNG LẶP
# ===========================================================================
func _process(delta: float) -> void:
	if boss_core and state != State.WIN:
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08
		boss_core.scale = Vector3(pulse, pulse, pulse)
	if arena:
		_layout_arena()
	match state:
		State.INTRO:
			intro_timer -= delta
			if intro_timer <= 0.0:
				state = State.BATTLE
				GameFX.play_sfx("alarm", -2.0)
		State.BATTLE, State.FINAL_PUSH:
			_process_battle(delta)
		State.GIT:
			time_left -= delta
			conflict_timer -= delta
			git_bar.value = conflict_timer / 8.0 * 100.0
			if conflict_timer <= 0.0:
				_resolve_conflict(-1)
			if time_left <= 0.0:
				_lose("DEADLINE 23:59 ĐÃ QUA KHI ĐANG RESOLVE CONFLICT! Cổng nộp đã đóng.")
	_update_clock()

func _update_clock() -> void:
	var elapsed: float = BATTLE_TIME - time_left
	var total_sec: int = 57 * 60 + 30 + int(elapsed)
	clock_label.text = "23:%02d:%02d · còn %ds" % [total_sec / 60, total_sec % 60, int(ceil(maxf(0.0, time_left)))]
	if time_left < 15.0:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		clock_label.modulate = Color(1.0, 0.3 + pulse * 0.3, 0.3)

func _wave() -> int:
	var elapsed: float = BATTLE_TIME - time_left
	if elapsed < 30.0:
		return 1
	if elapsed < 60.0:
		return 2
	return 3

func _process_battle(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		_lose("DEADLINE 23:59 ĐÃ QUA! Portal đóng cổng nộp, nhóm nhìn nhau khóc... (boss còn %d HP)" % int(boss_hp))
		return

	# Cooldown & điện thoại
	for m: Dictionary in members:
		m["cd_left"] = maxf(0.0, float(m["cd_left"]) - delta)
	phone_cd = maxf(0.0, phone_cd - delta)
	if phone_active:
		phone_timer -= delta
		phone_label.text = "MASH [SPACE] %d / 14 – còn %.1fs" % [phone_presses, maxf(0.0, phone_timer)]
		phone_bar.value = phone_presses / 14.0 * 100.0
		if phone_timer <= 0.0:
			_phone_end(false)
	if freeze_timer > 0.0:
		freeze_timer -= delta

	# Spawn đạn
	if state == State.BATTLE and freeze_timer <= 0.0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var w: int = _wave()
			spawn_timer = [1.7, 1.2, 0.85][w - 1] * randf_range(0.85, 1.15)
			_spawn_bullet(w)

	# Di chuyển đạn
	var fall_speed: float = [1.0 / 6.5, 1.0 / 5.0, 1.0 / 3.8][_wave() - 1]
	var h: float = arena.size.y
	var lane_w: float = arena.size.x / float(LANE_COUNT)
	for b: Dictionary in bullets:
		if b.get("dead", false):
			continue
		if freeze_timer <= 0.0:
			b["y"] = float(b["y"]) + fall_speed * delta
		var node: Control = b["node"]
		if is_instance_valid(node):
			node.position = Vector2(float(b["lane"]) * lane_w + lane_w * 0.5 - node.size.x * 0.5, float(b["y"]) * (h - 40.0))
		if float(b["y"]) >= 1.0:
			_bullet_hits_bottom(b)
	bullets = bullets.filter(func(b: Dictionary) -> bool: return not b.get("dead", false))

	if state == State.FINAL_PUSH and not final_bullet.is_empty():
		var node: Control = final_bullet["node"]
		if is_instance_valid(node):
			node.position = Vector2(arena.size.x * 0.5 - node.size.x * 0.5, h * 0.35)

	_refresh_cards()

func _spawn_bullet(w: int) -> void:
	var pool: Array[String] = WORDS_W1 if w == 1 else (WORDS_W2 if w == 2 else WORDS_W3)
	if w == 3 and randf() < 0.3:
		pool = WORDS_W2
	var word: String = pool[randi() % pool.size()]
	# Tránh 2 đạn cùng tiền tố đầu đang sống (khó phân biệt khi gõ)
	for attempt: int in range(4):
		var clash: bool = false
		for b: Dictionary in bullets:
			if not b.get("dead", false) and str(b["word"]).to_lower()[0] == word.to_lower()[0]:
				clash = true
		if not clash:
			break
		word = pool[randi() % pool.size()]
	var lane: int = randi() % LANE_COUNT
	var b: Dictionary = {"word": word, "lane": lane, "y": 0.0, "dead": false}
	b["node"] = _make_bullet_node(b)
	bullets.append(b)
	# Boss "phun" đạn
	var tw := create_tween()
	tw.tween_property(boss_root, "scale", Vector3(1.15, 0.9, 1.15), 0.08)
	tw.tween_property(boss_root, "scale", Vector3.ONE, 0.2)

func _make_bullet_node(b: Dictionary) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.08, 0.1, 0.95)
	sb.border_color = Color("#FF6B6B")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.custom_minimum_size = Vector2(70, 30)
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.add_theme_font_size_override("bold_font_size", 22)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.text = "[b]%s[/b]" % str(b["word"])
	pc.add_child(rt)
	arena.add_child(pc)
	pc.position = Vector2(float(b["lane"]) * (arena.size.x / LANE_COUNT) + 20.0, -40.0)
	b["label"] = rt
	return pc

func _refresh_bullet_label(b: Dictionary) -> void:
	if not _bullet_alive(b):
		return
	var rt: RichTextLabel = b["label"]
	var word: String = str(b["word"])
	var n: int = mini(typed.length(), word.length())
	rt.text = "[color=#2ECC71][b]%s[/b][/color][b]%s[/b]" % [word.substr(0, n), word.substr(n)]

func _destroy_bullet(b: Dictionary, by_typing: bool) -> void:
	if b.get("dead", false):
		return
	b["dead"] = true
	var word: String = str(b["word"])
	var dmg: int = word.length() * (6 if by_typing else 4) * (_mult() if by_typing else 1)
	if by_typing:
		combo += 1
		max_combo = maxi(max_combo, combo)
		words_destroyed += 1
	score += dmg
	boss_hp = maxf(0.0, boss_hp - float(dmg))
	GameFX.play_sfx("explode", -8.0, randf_range(0.9, 1.3))
	var node: Control = b["node"]
	if is_instance_valid(node):
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(node, "scale", Vector2(1.6, 1.6), 0.15)
		tw.tween_property(node, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(node.queue_free)
	_shake_boss()
	if by_typing:
		GameFX.float_text(self, boss_root.global_position + Vector3(randf_range(-1.0, 1.0), 1.0, 0.0), "-%d" % dmg, Color("#F1C40F"), 44)
		if combo > 0 and combo % 6 == 0:
			GameFX.popup("🔥 COMBO %d! x%d SÁT THƯƠNG" % [combo, _mult()], Color("#F39C12"), 30, 0.8)
	_update_boss_ui()
	_check_boss_phase()

func _bullet_hits_bottom(b: Dictionary) -> void:
	b["dead"] = true
	var node: Control = b["node"]
	if is_instance_valid(node):
		node.queue_free()
	if locked == b:
		locked = {}
		typed = ""
		_refresh_typing_label()
	var lane: int = int(b["lane"])
	var m: Dictionary = members[lane]
	var target: Dictionary = m
	if m["down"]:
		target = members[active_idx]
	if int(target["shield"]) > 0:
		target["shield"] = int(target["shield"]) - 1
		GameFX.play_sfx("pop", -4.0, 0.7)
		_log("🛡 CSS Shield chặn '%s'! (còn %d)" % [str(b["word"]), int(target["shield"])])
		return
	var dmg: float = [18.0, 22.0, 26.0][_wave() - 1]
	target["hp"] = maxf(0.0, float(target["hp"]) - dmg)
	hits_taken += 1
	combo = 0
	GameFX.play_sfx("hit", -2.0, 0.8)
	GameFX.shake(0.35)
	GameFX.flash(Color("#E74C3C"), 0.25, 0.3)
	_log("💥 '%s' trúng %s %s: -%d HP!" % [str(b["word"]), target["icon"], target["name"], int(dmg)])
	if float(target["hp"]) <= 0.0 and not target["down"]:
		target["down"] = true
		_log("💀 %s %s GỤC TRÊN BÀN PHÍM! %s" % [target["icon"], target["name"], "Team còn %d người..." % (LANE_COUNT - _down_count())])
		GameFX.popup("💀 %s GỤC!" % target["name"], Color("#E74C3C"), 32, 1.2)
		var idx: int = members.find(target)
		if idx >= 0 and idx < team_meshes.size():
			var tw := create_tween()
			tw.tween_property(team_meshes[idx], "rotation_degrees:x", -12.0, 0.4)
			if idx < team_people.size():
				CharacterBuilder.play(team_people[idx], "slump")
		if active_idx == idx:
			_cycle_member()
		if _down_count() >= 2:
			_lose("2 THÀNH VIÊN GỤC TRƯỚC GIỜ G! Đồ án không kịp hoàn thành, hẹn kỳ sau bảo vệ lại...")
	_update_boss_ui()

func _down_count() -> int:
	var c: int = 0
	for m: Dictionary in members:
		if m["down"]:
			c += 1
	return c

func _shake_boss() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(boss_root, "position:x", 0.35, 0.05)
	tween.tween_property(boss_root, "position:x", -0.35, 0.05)
	tween.tween_property(boss_root, "position:x", 0.0, 0.05)

# ===========================================================================
# THÀNH VIÊN & SKILL
# ===========================================================================
func _select_member(i: int) -> void:
	if members[i]["down"]:
		GameFX.play_sfx("error", -8.0)
		return
	active_idx = i
	GameFX.play_sfx("tick", -6.0)
	_refresh_cards()

func _cycle_member() -> void:
	for step: int in range(1, LANE_COUNT + 1):
		var i: int = (active_idx + step) % LANE_COUNT
		if not members[i]["down"]:
			active_idx = i
			break
	GameFX.play_sfx("tick", -6.0)
	_refresh_cards()

func _use_skill() -> void:
	var m: Dictionary = members[active_idx]
	if m["down"]:
		return
	if not m["awake"]:
		if phone_active:
			return
		if phone_cd > 0.0:
			_log("📞 Máy bận... thử lại sau %.0fs" % phone_cd)
			return
		_phone_start()
		return
	if float(m["cd_left"]) > 0.0:
		GameFX.play_sfx("error", -10.0)
		_log("⏳ %s đang hồi chiêu (%.0fs)" % [m["skill"], float(m["cd_left"])])
		return
	m["cd_left"] = float(m["cd"])
	GameFX.play_sfx("success", -4.0)
	match active_idx:
		0:
			var alive: Array = bullets.filter(func(b: Dictionary) -> bool: return not b.get("dead", false))
			alive.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) > float(b["y"]))
			var n: int = mini(3, alive.size())
			for i: int in range(n):
				_destroy_bullet(alive[i], false)
			_log("💻 LEADER 'Clean Architecture': refactor bay %d viên đạn thấp nhất!" % n)
			GameFX.flash(Color("#F37021"), 0.25, 0.3)
		1:
			m["shield"] = 3
			_log("🎨 FRONTEND bật 'CSS Shield' (flex + z-index 9999): chặn 3 đạn làn mình!")
		2:
			freeze_timer = 2.5
			_log("📑 TESTER ném SRS 300 trang: Boss choáng, đạn đóng băng 2.5s!")
			GameFX.flash(Color("#2ECC71"), 0.2, 0.3)
		3:
			for mm: Dictionary in members:
				if not mm["down"]:
					mm["hp"] = minf(100.0, float(mm["hp"]) + 40.0)
			_log("📞 'git merge' thành công: cả team hồi +40 HP!")
			GameFX.flash(Color("#9B59B6"), 0.25, 0.3)
	_refresh_cards()

func _phone_start() -> void:
	phone_active = true
	phone_presses = 0
	phone_timer = 4.0
	phone_panel.visible = true
	GameFX.play_sfx("ring", -2.0)
	_log("📞 Gọi bạn seen không rep... (mash [SPACE] 14 lần trong 4s)")

func _phone_press() -> void:
	phone_presses += 1
	GameFX.play_sfx("tick", -8.0, 1.0 + phone_presses * 0.03)
	if phone_presses >= 14:
		_phone_end(true)

func _phone_end(success: bool) -> void:
	phone_active = false
	phone_panel.visible = false
	var m: Dictionary = members[3]
	if success:
		m["awake"] = true
		m["hp"] = 100.0
		GameFX.play_sfx("success")
		GameFX.popup("📞 BẮT MÁY RỒI! 'Hả? Deadline hả?! Để tui merge!'", Color("#9B59B6"), 28, 1.8)
		_log("📞 SEEN KO REP đã tỉnh! Skill 'git merge' (+40 HP team) đã mở.")
		if team_meshes.size() > 3:
			var tw := create_tween()
			tw.tween_property(team_meshes[3], "rotation_degrees:z", 0.0, 0.4)
			tw.parallel().tween_property(team_meshes[3], "position:y", 0.0, 0.4)
			if team_people.size() > 3:
				CharacterBuilder.play(team_people[3], "type")
		if sleep_label:
			sleep_label.text = "☕ tỉnh rồi!"
	else:
		phone_cd = 5.0
		GameFX.play_sfx("error")
		_log("📞 Vẫn seen không rep... (thử lại sau 5s)")
	_refresh_cards()

# ===========================================================================
# PHA GIT CONFLICT & FINAL PUSH
# ===========================================================================
func _check_boss_phase() -> void:
	if state == State.BATTLE and boss_hp <= BOSS_MAX_HP * 0.4:
		_start_git_phase()
	elif state == State.FINAL_PUSH and boss_hp <= 0.0:
		_win()

func _start_git_phase() -> void:
	state = State.GIT
	typed = ""
	locked = {}
	_refresh_typing_label()
	for b: Dictionary in bullets:
		b["dead"] = true
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	bullets.clear()
	var pool: Array = CONFLICT_POOL.duplicate()
	pool.shuffle()
	conflicts = pool.slice(0, 3)
	conflict_idx = 0
	GameFX.play_sfx("alarm")
	GameFX.flash(Color("#E74C3C"), 0.35, 0.4)
	GameFX.popup("⚠️ CẢ NHÓM PUSH CÙNG LÚC 23:58 → GIT MERGE CONFLICT!", Color("#E74C3C"), 30, 2.0)
	_log("⚠️ Boss yếu rồi nhưng branch main xung đột! Chọn đúng khối code [←]/[→] trong 8s.")
	git_panel.visible = true
	_show_conflict()

func _show_conflict() -> void:
	var c: Dictionary = conflicts[conflict_idx]
	conflict_timer = 8.0
	git_title.text = "⚠️ GIT MERGE CONFLICT %d/3 TRÊN MAIN!" % (conflict_idx + 1)
	git_desc.text = str(c["hint"])
	git_head_lbl.text = str(c["head"])
	git_theirs_lbl.text = str(c["theirs"])
	git_bar.value = 100.0

func _resolve_conflict(choice: int) -> void:
	var c: Dictionary = conflicts[conflict_idx]
	if choice == int(c["correct"]):
		conflicts_right += 1
		var dmg: float = BOSS_MAX_HP * 0.12
		boss_hp = maxf(1.0, boss_hp - dmg)
		score += int(dmg)
		GameFX.play_sfx("success", -2.0)
		GameFX.popup("✅ RESOLVE ĐÚNG! Boss -%d HP" % int(dmg), Color("#2ECC71"), 28, 1.0)
		_shake_boss()
	else:
		for m: Dictionary in members:
			if not m["down"]:
				m["hp"] = maxf(1.0, float(m["hp"]) - 25.0)
		GameFX.play_sfx("miss")
		GameFX.shake(0.4)
		GameFX.flash(Color("#E74C3C"), 0.3, 0.3)
		GameFX.popup("❌ MERGE SAI! Build fail, cả team -25 HP" if choice != -1 else "⏰ HẾT 8s! Conflict tự merge bừa, cả team -25 HP", Color("#E74C3C"), 26, 1.2)
	_update_boss_ui()
	_refresh_cards()
	conflict_idx += 1
	if conflict_idx >= conflicts.size():
		_start_final_push()
	else:
		_show_conflict()

func _start_final_push() -> void:
	state = State.FINAL_PUSH
	git_panel.visible = false
	spawn_timer = 1.0
	GameFX.play_sfx("whoosh")
	GameFX.popup("🚀 MAIN SẠCH RỒI! GÕ LỆNH: git push origin main", Color("#F1C40F"), 30, 2.5)
	_log("🚀 GÕ NGUYÊN CÂU LỆNH 'git push origin main' (có dấu cách) để nộp đồ án! Đạn vẫn rơi, cẩn thận!")
	hint_label.text = "Gõ 'git push origin main' (có dấu cách) · vẫn có thể bắn đạn lỗi khác"
	final_bullet = {"word": FINAL_COMMAND, "lane": 0, "y": 0.35, "dead": false}
	var pc: Control = _make_bullet_node(final_bullet)
	var sb: StyleBoxFlat = pc.get_theme_stylebox("panel").duplicate()
	sb.bg_color = Color(0.05, 0.3, 0.12, 0.96)
	sb.border_color = Color("#2ECC71")
	pc.add_theme_stylebox_override("panel", sb)
	final_bullet["node"] = pc
	# Ghi đè huỷ: gõ xong câu lệnh = thắng
	final_bullet["final"] = true

func _win() -> void:
	if state == State.WIN:
		return
	state = State.WIN
	StageManager.typing_mode = false
	git_panel.visible = false
	phone_panel.visible = false
	GameFX.flash(Color.WHITE, 0.8, 0.6)
	GameFX.play_sfx("res://assets/audio/victory_fanfare.wav", 3.0)
	GameFX.slow_motion(0.35, 1.0)
	# Pháo hoa
	for i: int in range(5):
		var fw := CPUParticles3D.new()
		fw.one_shot = true
		fw.amount = 60
		fw.lifetime = 1.4
		fw.explosiveness = 1.0
		fw.spread = 180.0
		fw.initial_velocity_min = 4.0
		fw.initial_velocity_max = 8.0
		fw.gravity = Vector3(0, -3.0, 0)
		fw.scale_amount_min = 0.2
		fw.scale_amount_max = 0.5
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = [Color("#F37021"), Color("#F1C40F"), Color("#2ECC71"), Color("#3498DB"), Color("#E84393")][i]
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 2.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.material = mat
		fw.mesh = sm
		fw.position = Vector3(-4.0 + i * 2.0, 2.0 + randf() * 0.7, -3.0)
		$Arena.add_child(fw)
		fw.emitting = true
	var tw := create_tween()
	tw.tween_property(boss_root, "scale", Vector3(0.01, 0.01, 0.01), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_show_win_modal)

func _show_win_modal() -> void:
	var time_bonus: int = int(maxf(0.0, time_left) * 15.0)
	score += time_bonus
	var rank: String = GameFX.rank_for(float(score), 2600.0, 1900.0, 1200.0)
	StageManager.report_stage_result(StageManager.StageID.STAGE_6_CAPSTONE, {
		"result": "win", "score": score, "rank": rank,
		"detail": "words=%d maxcombo=%d typos=%d hits=%d conflicts=%d/3" % [words_destroyed, max_combo, typos, hits_taken, conflicts_right]
	})
	var done_sec: int = 57 * 60 + 30 + int(BATTLE_TIME - time_left)
	modal_title.text = "🏆 DANH HIỆU 'CÓC VÀNG FPTU' – NỘP CAPSTONE LÚC 23:%02d:%02d! RANK %s" % [done_sec / 60, done_sec % 60, rank]
	modal_title.modulate = Color("#F1C40F")
	modal_sub.text = "Bắn hạ %d viên đạn lỗi · combo cao nhất x%d (%d) · %d lần gõ sai · trúng %d đạn.\nGit conflict resolve đúng %d/3 · Bạn seen không rep: %s.\nĐiểm %d (thưởng thời gian +%d). Pháo hoa rực sáng campus FPTU!" % [
		words_destroyed, 1 + mini(max_combo / 6, 2), max_combo, typos, hits_taken, conflicts_right,
		("đã tỉnh và merge" if members[3]["awake"] else "ngủ tới sáng 💤"), score, time_bonus
	]
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _lose(reason: String) -> void:
	if state == State.LOSE or state == State.WIN:
		return
	state = State.LOSE
	StageManager.typing_mode = false
	git_panel.visible = false
	phone_panel.visible = false
	StageManager.report_stage_result(StageManager.StageID.STAGE_6_CAPSTONE, {"result": "fail", "score": score, "rank": "C", "detail": reason})
	GameFX.play_sfx("res://assets/audio/absent_gameover.wav", 2.0)
	modal_title.text = "❌ THẤT BẠI TRƯỚC DEADLINE 23:59!"
	modal_title.modulate = Color("#E74C3C")
	modal_sub.text = reason + "\nBoss còn %d%% HP · bắn hạ %d đạn · combo cao nhất %d – thiếu chút nữa thôi!" % [int(boss_hp / BOSS_MAX_HP * 100.0), words_destroyed, max_combo]
	extra_btn.visible = false
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _on_extra_pressed() -> void:
	StageManager.change_stage(StageManager.StageID.STAGE_EXTRA_EOS)

func _on_menu_pressed() -> void:
	StageManager.open_stage_select()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
