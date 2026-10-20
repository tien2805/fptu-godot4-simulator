# File: res://scripts/StageExtra_EOSExam.gd
# EXTRA: GIÁM THỊ COI THI EOS BẮT TOOL CHEAT (90s, 16 máy, 6 thánh tool random, cần bắt 5)
#   - Đi tuần [WASD] hoặc xem CCTV top-down [C].
#   - Thánh tool chỉ lộ "tell" trong cửa sổ ngắn: Alt+Tab lộ liễu (0-30s), điện thoại sáng gầm bàn (25s+),
#     tai nghe bluetooth / Apple Watch (50s+, cửa sổ 0.85s). Sinh viên ngay thẳng cũng vươn vai, gãi đầu.
#   - [S] chụp bằng chứng đúng lúc tell đang diễn ra (tối đa 8 ảnh). [E] soi máy -> đối chiếu Quy chế thi
#     -> chỉ lập biên bản được khi có bằng chứng của đúng máy. Ép biên bản không bằng chứng: trừ Uy tín.
#   - Uy tín ≤ 0 = bị Phòng Khảo thí đình chỉ. Bắt đủ 5 = thắng, xếp hạng theo điểm & uy tín.
class_name StageExtra_EOSExam
extends Node3D

@onready var proctor: CharacterBody3D = $Proctor
@onready var walk_cam: Camera3D = $Proctor/Camera3D
@onready var timer_label: Label = $HUD/TopBar/TimerPanel/TimerLabel
@onready var count_label: Label = $HUD/TopBar/ScorePanel/CountLabel
@onready var prompt_panel: PanelContainer = $HUD/PromptPanel
@onready var prompt_label: Label = $HUD/PromptPanel/PromptLabel

@onready var inspect_panel: PanelContainer = $HUD/CenterModals/InspectModal
@onready var inspect_vbox: VBoxContainer = $HUD/CenterModals/InspectModal/Margin/VBox
@onready var inspect_title: Label = $HUD/CenterModals/InspectModal/Margin/VBox/Title
@onready var inspect_text: Label = $HUD/CenterModals/InspectModal/Margin/VBox/StatusLabel
@onready var confiscate_btn: Button = $HUD/CenterModals/InspectModal/Margin/VBox/ConfiscateButton
@onready var close_btn: Button = $HUD/CenterModals/InspectModal/Margin/VBox/CloseButton

@onready var modal_overlay: ColorRect = $HUD/ModalOverlay
@onready var modal_title: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/TitleLabel
@onready var modal_sub: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/SubLabel
@onready var replay_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/ReplayCampaignButton
@onready var menu_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/MenuButton
@onready var retry_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/RetryButton
@onready var hud: CanvasLayer = $HUD

enum Tell { NONE, ALT_TAB, PHONE, EARBUD, WATCH }

const STAGE_TIME: float = 90.0
const NEED_CAUGHT: int = 5
const MAX_PHOTOS: int = 8
const INSPECT_RANGE: float = 3.2
const TELL_INFO: Dictionary = {
	Tell.ALT_TAB: {"name": "Alt+Tab giấu tài liệu", "rule": "Điều 1: Mở ứng dụng ngoài EOS", "dur": 1.5, "gap": [5.0, 8.0], "start": 0.0},
	Tell.PHONE: {"name": "Điện thoại sáng dưới gầm bàn", "rule": "Điều 2: Thiết bị liên lạc trong phòng thi", "dur": 1.2, "gap": [6.0, 9.0], "start": 25.0},
	Tell.EARBUD: {"name": "Tai nghe bluetooth nhận đáp án", "rule": "Điều 2: Thiết bị liên lạc trong phòng thi", "dur": 0.85, "gap": [6.0, 9.5], "start": 50.0},
	Tell.WATCH: {"name": "Apple Watch hiện đáp án", "rule": "Điều 3: Thiết bị thông minh đeo tay", "dur": 0.85, "gap": [6.0, 9.5], "start": 50.0}
}
const NAMES: Array[String] = ["Tuấn", "Linh", "Khoa", "My", "Đạt", "Trang", "Huy", "Ngân", "Phúc", "Vy", "Long", "Hà", "Quân", "Thảo", "Bảo", "Nhi"]

var time_left: float = STAGE_TIME
var is_stage_ended: bool = false
var stations: Array[Dictionary] = []
var caught: int = 0
var wrong_books: int = 0
var photos_used: int = 0
var reputation: int = 100
var score: int = 0
var current_idx: int = -1
var evidence_log: Array[String] = []
var is_cctv: bool = false
var cctv_cam: Camera3D
var cctv_hover_idx: int = -1
var cctv_panel: PanelContainer
var cctv_label: Label
var evidence_panel: PanelContainer
var evidence_label: Label
var hint_label: Label
var force_btn: Button
var tex_eos: Texture2D
var decoy_timer: float = 3.0
var cctv_marker: MeshInstance3D
var proctor_model: Node3D
var cam_yaw: float = PI # yaw camera đang bám (PI = nhìn về phía bảng / cửa sổ D1)

## Vật liệu riêng (có alpha) cho thân & đầu giám thị để camera lại gần thì mờ dần.
func _setup_proctor_materials() -> void:
	# Giám thị = CharacterBuilder "proctor" (sơ mi trắng, cà vạt, thẻ, kính). CSG BodyMesh/HeadMesh cũ ẩn đi.
	# Gốc Proctor (CharacterBody3D) ở y = 0.85, mặt hướng +Z (theo _handle_movement) → model y = -0.85, xoay PI.
	for n: String in ["BodyMesh", "HeadMesh"]:
		var g: Node3D = proctor.get_node_or_null(n)
		if g:
			g.visible = false
	proctor_model = CharacterBuilder.build({"preset": "proctor", "seed": 2026, "name": "ProctorModel", "female": false})
	proctor_model.position = Vector3(0.0, -0.85, 0.0)
	proctor_model.rotation.y = PI
	proctor.add_child(proctor_model)
	var badge := Label3D.new()
	badge.text = "GIÁM THỊ"
	badge.font_size = 18
	badge.outline_size = 6
	badge.modulate = Color("#F1C40F")
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.position = Vector3(0.0, 1.45, 0.0)
	proctor.add_child(badge)

func _ready() -> void:
	modal_overlay.visible = false
	prompt_panel.visible = false
	inspect_panel.visible = false

	_load_eos_texture()
	_build_room_311_world()
	_build_exam_stations()
	_build_cctv()
	_build_hud_extras()

	confiscate_btn.pressed.connect(_on_confiscate_pressed)
	close_btn.pressed.connect(_on_close_inspect)
	replay_btn.pressed.connect(_on_replay_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	GameFX.disable_button_focus(hud)
	GameFX.upgrade_scene_visuals(self, "exam")
	GameFX.music_play("exam", 0.3)
	walk_cam.top_level = true
	proctor.rotation.y = PI
	cam_yaw = PI
	_setup_proctor_materials()
	_update_walk_camera(1.0)
	_update_hud()
	GameFX.popup("🕵️ 08:00 – GIỜ THI EOS BẮT ĐẦU. QUAN SÁT → [S] CHỤP BẰNG CHỨNG → [E] LẬP BIÊN BẢN. [C] XEM CCTV", GameFX.FPT_YELLOW, 24, 3.5)

func _load_eos_texture() -> void:
	var path: String = "res://assets/textures/eos_exam_screen.png"
	if FileAccess.file_exists(path):
		var img: Image = GameFX.load_image_any(path)
		if img:
			tex_eos = ImageTexture.create_from_image(img)

# ===========================================================================
# DỰNG PHÒNG THI
# ===========================================================================
func _build_exam_stations() -> void:
	var root: Node3D = $ExamRoom/Stations
	var mat_desk := StandardMaterial3D.new()
	mat_desk.albedo_color = Color("#34495E")

	# Chọn 6 thánh tool: 2 cấp 1 (Alt+Tab), 2 cấp 2 (điện thoại), 2 cấp 3 (tai nghe / watch)
	var all_idx: Array[int] = []
	for i: int in range(16):
		all_idx.append(i)
	all_idx.shuffle()
	var cheat_types: Array[int] = [Tell.ALT_TAB, Tell.ALT_TAB, Tell.PHONE, Tell.PHONE, Tell.EARBUD, Tell.WATCH]
	var assigned: Dictionary = {}
	for k: int in range(6):
		assigned[all_idx[k]] = cheat_types[k]

	var idx: int = 0
	for row: int in range(4):
		for col: int in range(4):
			var x_pos: float = (col - 1.5) * 2.6
			var z_pos: float = (row - 1.5) * 2.35
			var station := Node3D.new()
			station.position = Vector3(x_pos, 0.0, z_pos)
			station.scale = Vector3(0.62, 0.62, 0.62)
			root.add_child(station)

			var desk := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(2.6, 1.3, 1.4)
			desk.mesh = dm
			desk.material_override = mat_desk
			desk.position = Vector3(0.0, 0.65, 0.0)
			station.add_child(desk)

			var mat_screen := StandardMaterial3D.new()
			if tex_eos:
				mat_screen.albedo_texture = tex_eos
				mat_screen.emission_enabled = true
				mat_screen.emission_texture = tex_eos
				mat_screen.emission_energy_multiplier = 0.75
			else:
				mat_screen.albedo_color = Color("#3498DB")
				mat_screen.emission_enabled = true
				mat_screen.emission = Color("#3498DB")
			var monitor := MeshInstance3D.new()
			var mm := BoxMesh.new()
			mm.size = Vector3(1.2, 0.8, 0.1)
			monitor.mesh = mm
			monitor.material_override = mat_screen
			monitor.position = Vector3(0.0, 1.7, -0.3)
			station.add_child(monitor)

			var student: Node3D = CharacterBuilder.build({"preset": "student", "seed": 900 + idx * 23, "name": "Student%02d" % idx, "backpack": false, "animate": false})
			student.position = Vector3(0.0, 0.0, 0.6)
			station.add_child(student)
			# ghế cao: hông ở 0.78 (đơn vị trạm) để đầu nhô khỏi bàn 1.3
			CharacterBuilder.pose(student, "type", float(idx) * 0.7, {"sit_height": 0.95})
			var head: Node3D = CharacterBuilder.get_pivot(student, "head")
			# Tai nghe (ẩn) gắn tai phải
			var earbud := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.022
			em.height = 0.044
			earbud.mesh = em
			var mat_e := StandardMaterial3D.new()
			mat_e.albedo_color = Color.WHITE
			mat_e.emission_enabled = true
			mat_e.emission = Color.WHITE * 1.5
			earbud.material_override = mat_e
			earbud.position = Vector3(0.108, 0.115, 0.0)
			earbud.visible = false
			head.add_child(earbud)
			# Cẳng tay phải + đồng hồ (sáng lên khi gian lận)
			var arm: Node3D = CharacterBuilder.get_pivot(student, "elbow_r")
			var watch := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.035, 0.03, 0.012)
			watch.mesh = wm
			var mat_w := StandardMaterial3D.new()
			mat_w.albedo_color = Color("#111111")
			mat_w.emission_enabled = true
			mat_w.emission = Color.BLACK
			watch.material_override = mat_w
			watch.position = Vector3(0.0, -0.23, -0.045)
			arm.add_child(watch)
			# Điện thoại + đèn dưới gầm bàn (ẩn)
			var phone := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.14, 0.02, 0.28)
			phone.mesh = pm
			var mat_p := StandardMaterial3D.new()
			mat_p.albedo_color = Color("#74B9FF")
			mat_p.emission_enabled = true
			mat_p.emission = Color("#74B9FF") * 1.5
			phone.material_override = mat_p
			phone.position = Vector3(0.2, 0.55, 0.45)
			phone.visible = false
			station.add_child(phone)
			var light := OmniLight3D.new()
			light.light_color = Color("#74B9FF")
			light.light_energy = 0.0
			light.omni_range = 2.2
			light.position = Vector3(0.2, 0.5, 0.5)
			station.add_child(light)

			var tag := Label3D.new()
			tag.text = "MÁY %02d" % (idx + 1)
			tag.font_size = 20
			tag.outline_size = 6
			tag.modulate = Color("#BDC3C7")
			tag.position = Vector3(0.0, 2.3, -0.3)
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			station.add_child(tag)

			var area := Area3D.new()
			var c_shape := CollisionShape3D.new()
			var b_box := BoxShape3D.new()
			b_box.size = Vector3(3.4, 2.5, 3.4)
			c_shape.shape = b_box
			area.add_child(c_shape)
			area.position = Vector3(0.0, 1.2, 0.6)
			station.add_child(area)

			var tell_type: int = int(assigned.get(idx, Tell.NONE))
			var st: Dictionary = {
				"idx": idx, "node": station, "monitor_mat": mat_screen, "student": student, "head": head,
				"earbud": earbud, "arm": arm, "watch_mat": mat_w, "phone": phone, "light": light, "tag": tag,
				"is_cheater": tell_type != Tell.NONE, "tell": tell_type,
				"next_tell": 0.0, "tell_active": false, "tell_left": 0.0,
				"evidence": 0, "booked": false, "name": NAMES[idx % NAMES.size()]
			}
			if st["is_cheater"]:
				var info: Dictionary = TELL_INFO[tell_type]
				st["next_tell"] = float(info["start"]) + randf_range(1.5, 4.0)
			stations.append(st)
			idx += 1

	# Bảng quy chế trên tường phía D1 (tường -Z)
	var board := Label3D.new()
	board.text = "PHÒNG 311 – EOS PRACTICAL CODING – 08:00 → 09:30\nĐ1 Ứng dụng ngoài EOS · Đ2 Thiết bị liên lạc · Đ3 Thiết bị đeo tay"
	board.font_size = 22
	board.outline_size = 7
	board.modulate = Color("#F1C40F")
	board.position = Vector3(0.0, 2.85, -4.86)
	$ExamRoom.add_child(board)

## PHÒNG 311 THẬT: cánh trước, module 4, lầu 3 – cửa sổ hai phía (D1 ở -Z, sân trong ở +Z); trần ở layer 2
## để camera CCTV gắn trần (cull_mask = 1) nhìn xuyên xuống lớp.
func _build_room_311_world() -> void:
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var c: Vector3 = FPTUCampusBuilder.room311_center()
	var world := Node3D.new()
	world.name = "CampusWorld"
	world.position = -c
	$ExamRoom.add_child(world)
	FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": true})
	FPTUCampusBuilder.build_hutech(world, Vector3(135.0, 0.0, -26.0), cm)
	FPTUCampusBuilder.build_d1_road_piece(world, -13.0, -80.0, 300.0, cm, 0.0)
	FPTUCampusBuilder.build_room_interior($ExamRoom, FPTUCampusBuilder.room311_size(), cm, {
		"windows": ["-z", "+z"], "door": "-x", "door_x": 0.7, "board_side": "+x", "name": "PHÒNG 311", "ceiling_layer": 2
	})
	$DirectionalLight3D.rotation_degrees = Vector3(-45.0, 20.0, 0.0)

func _build_cctv() -> void:
	# CCTV gắn góc trần phía sau-phải phòng, nhìn chéo xuống (thấy mặt màn hình của cả 16 máy như camera phòng thi thật)
	cctv_cam = Camera3D.new()
	cctv_cam.fov = 92.0
	cctv_cam.position = Vector3(5.55, 3.1, 4.6)
	cctv_cam.current = false
	add_child(cctv_cam)
	cctv_cam.look_at(Vector3(-0.8, 0.3, -1.6), Vector3.UP)
	# Hộp camera + đèn đỏ ở góc trần
	var cam_box := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(0.22, 0.14, 0.3)
	cam_box.mesh = cbm
	var mat_cam := StandardMaterial3D.new()
	mat_cam.albedo_color = Color("#ECEFF1")
	cam_box.material_override = mat_cam
	$ExamRoom.add_child(cam_box)
	cam_box.look_at_from_position(Vector3(5.55, 3.05, 4.6), Vector3(-0.8, 0.3, -1.6), Vector3.UP)
	var cam_led := MeshInstance3D.new()
	var clm := SphereMesh.new()
	clm.radius = 0.025
	clm.height = 0.05
	cam_led.mesh = clm
	var mat_led := StandardMaterial3D.new()
	mat_led.albedo_color = Color("#E74C3C")
	mat_led.emission_enabled = true
	mat_led.emission = Color("#E74C3C") * 2.0
	cam_led.material_override = mat_led
	cam_led.position = Vector3(5.5, 2.98, 4.52)
	$ExamRoom.add_child(cam_led)
	# Vòng đánh dấu máy đang rê chuột trong CCTV
	cctv_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.15
	cctv_marker.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#F1C40F")
	mat.emission_enabled = true
	mat.emission = Color("#F1C40F")
	cctv_marker.material_override = mat
	cctv_marker.visible = false
	add_child(cctv_marker)

func _build_hud_extras() -> void:
	cctv_panel = GameFX.anchored_panel(hud, Control.PRESET_TOP_LEFT, Vector2(300, 0), 90, Color("#E74C3C"))
	cctv_label = GameFX.make_label("● REC  CCTV PHÒNG 311 – CAM 01\n08:00:00  ·  rê chuột vào máy, [S] chụp · [E] soi", 14, Color("#FF7675"), HORIZONTAL_ALIGNMENT_LEFT)
	cctv_panel.add_child(cctv_label)
	cctv_panel.visible = false

	evidence_panel = GameFX.anchored_panel(hud, Control.PRESET_TOP_RIGHT, Vector2(300, 0), 90, GameFX.FPT_YELLOW)
	var vb := VBoxContainer.new()
	evidence_panel.add_child(vb)
	vb.add_child(GameFX.make_label("📒 SỔ BẰNG CHỨNG (0/8 ảnh)", 15, GameFX.FPT_YELLOW))
	evidence_label = GameFX.make_label("(chưa có) – bấm [S] khi thấy hành vi đáng ngờ", 13, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_LEFT)
	vb.add_child(evidence_label)

	var hint_panel: PanelContainer = GameFX.anchored_panel(hud, Control.PRESET_CENTER_BOTTOM, Vector2(760, 0), 24, Color("#BDC3C7"))
	hint_label = GameFX.make_label("[WASD] đi tuần · [C] CCTV · [S] chụp bằng chứng · [E] soi máy & lập biên bản · Bắt oan = -35 uy tín", 13, Color("#BDC3C7"))
	hint_panel.add_child(hint_label)

	force_btn = Button.new()
	force_btn.text = "⚠️ ÉP LẬP BIÊN BẢN KHÔNG BẰNG CHỨNG (rủi ro bắt oan) [Shift+Space]"
	force_btn.custom_minimum_size = Vector2(0, 38)
	force_btn.focus_mode = Control.FOCUS_NONE
	force_btn.pressed.connect(_on_force_book)
	inspect_vbox.add_child(force_btn)
	inspect_vbox.move_child(force_btn, inspect_vbox.get_child_count() - 2)

func _update_hud() -> void:
	count_label.text = "THÁNH TOOL: %d / %d · 📸 %d/%d · ⚖️ UY TÍN %d · ĐIỂM %d" % [caught, NEED_CAUGHT, photos_used, MAX_PHOTOS, reputation, score]
	var kid: Node = evidence_panel.get_child(0).get_child(0)
	if kid is Label:
		(kid as Label).text = "📒 SỔ BẰNG CHỨNG (%d/%d ảnh)" % [photos_used, MAX_PHOTOS]
	evidence_label.text = "\n".join(evidence_log) if not evidence_log.is_empty() else "(chưa có) – bấm [S] khi thấy hành vi đáng ngờ"

# ===========================================================================
# INPUT
# ===========================================================================
func _input(event: InputEvent) -> void:
	if is_stage_ended:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key: int = event.physical_keycode
		if inspect_panel.visible:
			if key == KEY_SPACE and event.shift_pressed:
				_on_force_book()
			elif key in [KEY_SPACE, KEY_ENTER] and not confiscate_btn.disabled:
				_on_confiscate_pressed()
			elif key in [KEY_ESCAPE, KEY_N, KEY_E]:
				_on_close_inspect()
			return
		match key:
			KEY_C:
				_toggle_cctv()
			KEY_S:
				if not is_cctv or cctv_hover_idx != -1:
					_take_photo(_target_station_idx())
			KEY_E:
				var t: int = _target_station_idx()
				if t != -1:
					_inspect_station(t)
				else:
					GameFX.popup("Lại gần máy (hoặc rê chuột vào máy trong CCTV) rồi bấm [E]", Color("#BDC3C7"), 20, 0.8)

func _target_station_idx() -> int:
	if is_cctv:
		return cctv_hover_idx
	return current_idx

# ===========================================================================
# VÒNG LẶP
# ===========================================================================
func _process(delta: float) -> void:
	if is_stage_ended:
		return
	time_left -= delta
	var elapsed: float = STAGE_TIME - time_left
	var secs: int = int(elapsed)
	timer_label.text = "08:%02d:%02d · còn %ds" % [secs / 60, secs % 60, int(ceil(maxf(0.0, time_left)))]
	if cctv_panel.visible:
		cctv_label.text = "● REC  CCTV PHÒNG 311 – CAM 01\n08:%02d:%02d  ·  rê chuột vào máy, [S] chụp · [E] soi" % [secs / 60, secs % 60]

	_update_tells(delta, elapsed)
	_update_decoys(delta)
	if not inspect_panel.visible:
		if is_cctv:
			_update_cctv_hover()
		else:
			_handle_movement(delta)
			_update_proximity()

	if time_left <= 0.0:
		_fail_stage("HẾT GIỜ THI! Bạn mới bắt %d/%d thánh tool. Phòng Khảo thí: 'Lần sau tinh mắt hơn nha!'" % [caught, NEED_CAUGHT])

## Camera đi tuần góc nhìn thứ ba: XOAY THEO HƯỚNG NHÂN VẬT (lười theo sau lưng, lệch vai phải), kẹp trong phòng
## 12 × 10 m. Không đuổi theo khi nhân vật quay ngược lại phía camera (>110°) để tránh quay vòng vô tận khi giữ [S].
## Bị dồn sát tường thì camera hạ thấp, lệch vai hơn và thân giám thị mờ dần để không thành "cục đen" giữa màn hình.
func _update_walk_camera(delta: float) -> void:
	var p: Vector3 = proctor.global_position
	var facing: float = proctor.rotation.y
	if absf(angle_difference(cam_yaw, facing)) < deg_to_rad(110.0):
		cam_yaw = lerp_angle(cam_yaw, facing, minf(1.0, delta * 3.5))
	var f := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))   # hướng nhìn của nhân vật (local +Z)
	var r := Vector3(-cos(cam_yaw), 0.0, sin(cam_yaw))  # bên phải của nhân vật
	var desired: Vector3 = p - f * 2.8 + r * 1.3 + Vector3(0.0, 2.55, 0.0)
	desired.x = clampf(desired.x, -5.5, 5.5)
	desired.z = clampf(desired.z, -4.6, 4.6)
	var planar: float = Vector2(desired.x - p.x, desired.z - p.z).length()
	var tight: float = clampf((2.8 - planar) / 1.4, 0.0, 1.0) # 1 = camera bị tường ép sát nhân vật
	desired.y = lerpf(2.55, 2.25, tight)
	walk_cam.global_position = walk_cam.global_position.lerp(desired, minf(1.0, delta * 8.0))
	var look: Vector3 = (p + f * 4.5 + r * 0.4 + Vector3(0.0, 1.1, 0.0)).lerp(p + f * 3.0 + Vector3(0.0, 0.8, 0.0), tight)
	if walk_cam.global_position.distance_squared_to(look) > 0.01:
		walk_cam.look_at(look, Vector3.UP)
	var d: float = walk_cam.global_position.distance_to(p + Vector3(0.0, 0.95, 0.0))
	var alpha: float = clampf((d - 1.4) / 1.1, 0.18, 1.0)
	if proctor_model:
		CharacterBuilder.set_opacity(proctor_model, alpha)

func _handle_movement(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()
	# Phím tính theo hướng camera: [W] = tiến theo hướng đang nhìn, [A]/[D] = rẽ trái/phải (nhân vật quay, camera theo sau)
	var cam_f: Vector3 = -walk_cam.global_basis.z
	cam_f.y = 0.0
	cam_f = cam_f.normalized() if cam_f.length_squared() > 0.0001 else Vector3(0.0, 0.0, -1.0)
	var cam_r: Vector3 = walk_cam.global_basis.x
	cam_r.y = 0.0
	cam_r = cam_r.normalized() if cam_r.length_squared() > 0.0001 else Vector3(1.0, 0.0, 0.0)
	var move: Vector3 = cam_f * (-input_dir.z) + cam_r * input_dir.x
	if move.length_squared() > 0.0001:
		move = move.normalized()
		var target_angle: float = atan2(move.x, move.z)
		proctor.rotation.y = lerp_angle(proctor.rotation.y, target_angle, delta * 10.0)
		proctor.velocity.x = move.x * 4.2
		proctor.velocity.z = move.z * 4.2
		if proctor_model:
			CharacterBuilder.set_speed(proctor_model, 4.2)
	else:
		proctor.velocity.x = move_toward(proctor.velocity.x, 0.0, delta * 20.0)
		if proctor_model:
			CharacterBuilder.set_speed(proctor_model, 0.0)
		proctor.velocity.z = move_toward(proctor.velocity.z, 0.0, delta * 20.0)
	proctor.velocity.y = 0.0
	proctor.move_and_slide()
	proctor.global_position.x = clampf(proctor.global_position.x, -5.4, 5.4)
	proctor.global_position.z = clampf(proctor.global_position.z, -4.3, 3.2)
	proctor.global_position.y = 0.85
	_update_walk_camera(delta)

func _update_proximity() -> void:
	var best: int = -1
	var best_d: float = INSPECT_RANGE
	for st: Dictionary in stations:
		var d: float = proctor.global_position.distance_to((st["node"] as Node3D).global_position + Vector3(0, 0.85, 0.6))
		if d < best_d:
			best_d = d
			best = int(st["idx"])
	if best != current_idx:
		current_idx = best
		if best == -1:
			prompt_panel.visible = false
		else:
			var st: Dictionary = stations[best]
			prompt_panel.visible = true
			prompt_label.text = "MÁY %02d (%s) – [S] CHỤP BẰNG CHỨNG · [E] SOI & LẬP BIÊN BẢN%s" % [best + 1, st["name"], (" · ĐÃ ĐÌNH CHỈ" if st["booked"] else "")]

func _update_cctv_hover() -> void:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var best: int = -1
	var best_d: float = 70.0
	for st: Dictionary in stations:
		var p3: Vector3 = (st["node"] as Node3D).global_position
		if cctv_cam.is_position_behind(p3):
			continue
		var p2: Vector2 = cctv_cam.unproject_position(p3)
		var d: float = p2.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = int(st["idx"])
	cctv_hover_idx = best
	cctv_marker.visible = best != -1
	if best != -1:
		cctv_marker.global_position = (stations[best]["node"] as Node3D).global_position + Vector3(0, 0.2, 0.3)
		prompt_panel.visible = true
		prompt_label.text = "CCTV → MÁY %02d (%s): [S] CHỤP · [E] SOI" % [best + 1, stations[best]["name"]]
	else:
		prompt_panel.visible = false

func _toggle_cctv() -> void:
	is_cctv = not is_cctv
	cctv_cam.current = is_cctv
	walk_cam.current = not is_cctv
	cctv_panel.visible = is_cctv
	cctv_marker.visible = false
	prompt_panel.visible = false
	cctv_hover_idx = -1
	GameFX.play_sfx("beep", -8.0, 0.8 if is_cctv else 1.2)
	if is_cctv:
		GameFX.set_vignette(0.45, Color(0.05, 0.05, 0.08), 0.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		GameFX.clear_vignette()

# ===========================================================================
# HÀNH VI GIAN LẬN & NHIỄU
# ===========================================================================
func _update_tells(delta: float, elapsed: float) -> void:
	for st: Dictionary in stations:
		if not st["is_cheater"] or st["booked"]:
			continue
		var info: Dictionary = TELL_INFO[int(st["tell"])]
		if st["tell_active"]:
			st["tell_left"] = float(st["tell_left"]) - delta
			if float(st["tell_left"]) <= 0.0:
				_set_tell_visual(st, false)
				st["tell_active"] = false
				var gap: Array = info["gap"]
				st["next_tell"] = elapsed + randf_range(float(gap[0]), float(gap[1]))
		elif elapsed >= float(st["next_tell"]) and elapsed >= float(info["start"]):
			st["tell_active"] = true
			st["tell_left"] = float(info["dur"])
			_set_tell_visual(st, true)

func _set_tell_visual(st: Dictionary, on: bool) -> void:
	match int(st["tell"]):
		Tell.ALT_TAB:
			var m: StandardMaterial3D = st["monitor_mat"]
			if on:
				m.albedo_texture = null
				m.emission_texture = null
				m.albedo_color = Color("#1F7A4D")
				m.emission = Color("#2ECC71")
				m.emission_energy_multiplier = 1.4
			else:
				m.albedo_texture = tex_eos
				m.emission_texture = tex_eos
				m.albedo_color = Color.WHITE
				m.emission = Color.WHITE
				m.emission_energy_multiplier = 0.75
		Tell.PHONE:
			(st["phone"] as MeshInstance3D).visible = on
			(st["light"] as OmniLight3D).light_energy = 2.4 if on else 0.0
			var head: Node3D = st["head"]
			var tw := create_tween()
			tw.tween_property(head, "rotation_degrees:x", -38.0 if on else -10.0, 0.2)
		Tell.EARBUD:
			(st["earbud"] as MeshInstance3D).visible = on
			var head: Node3D = st["head"]
			var tw := create_tween()
			tw.tween_property(head, "rotation_degrees:z", 24.0 if on else 0.0, 0.2)
		Tell.WATCH:
			var wm: StandardMaterial3D = st["watch_mat"]
			wm.emission = Color("#74B9FF") * (2.0 if on else 0.0)
			var arm: Node3D = st["arm"]
			var tw := create_tween()
			tw.tween_property(arm, "rotation_degrees:x", 138.0 if on else 83.0, 0.2)

func _update_decoys(delta: float) -> void:
	# Sinh viên ngay thẳng cũng cử động: vươn vai / gãi đầu / nhìn trần (KHÔNG phải vi phạm)
	decoy_timer -= delta
	if decoy_timer > 0.0:
		return
	decoy_timer = randf_range(2.5, 4.5)
	var innocents: Array[Dictionary] = []
	for st: Dictionary in stations:
		if not st["is_cheater"] and not st["booked"]:
			innocents.append(st)
	if innocents.is_empty():
		return
	var st: Dictionary = innocents[randi() % innocents.size()]
	var head: Node3D = st["head"]
	var tw := create_tween()
	match randi() % 3:
		0:
			var hy: float = head.position.y
			tw.tween_property(head, "position:y", hy + 0.08, 0.35)
			tw.tween_property(head, "position:y", hy, 0.35)
		1:
			tw.tween_property(head, "rotation_degrees:y", 40.0, 0.4)
			tw.tween_property(head, "rotation_degrees:y", 4.6, 0.4)
		_:
			tw.tween_property(head, "rotation_degrees:x", 22.0, 0.4)
			tw.tween_property(head, "rotation_degrees:x", -10.0, 0.4)

# ===========================================================================
# CHỤP BẰNG CHỨNG & LẬP BIÊN BẢN
# ===========================================================================
func _take_photo(idx: int) -> void:
	if idx == -1:
		GameFX.popup("📸 Chụp gì vậy? Lại gần một máy đã!", Color("#BDC3C7"), 20, 0.8)
		return
	if photos_used >= MAX_PHOTOS:
		GameFX.popup("📸 HẾT 8 ẢNH! Dùng bằng chứng đã có thôi.", GameFX.FPT_RED, 22, 1.0)
		GameFX.play_sfx("error", -6.0)
		return
	photos_used += 1
	GameFX.play_sfx("shutter", 0.0)
	GameFX.flash(Color.WHITE, 0.5, 0.18)
	var st: Dictionary = stations[idx]
	if st["is_cheater"] and st["tell_active"]:
		st["evidence"] = int(st["evidence"]) + 1
		var info: Dictionary = TELL_INFO[int(st["tell"])]
		evidence_log.append("#%d Máy %02d (%s): %s" % [photos_used, idx + 1, st["name"], info["name"]])
		GameFX.popup("📸 BẰNG CHỨNG #%d: Máy %02d – %s!" % [photos_used, idx + 1, info["name"]], GameFX.FPT_GREEN, 26, 1.4)
		(st["tag"] as Label3D).modulate = Color("#E74C3C")
		(st["tag"] as Label3D).text = "MÁY %02d 📸x%d" % [idx + 1, int(st["evidence"])]
	else:
		evidence_log.append("#%d Máy %02d: ...không có gì (tốn 1 ảnh)" % [photos_used, idx + 1])
		GameFX.popup("📸 Máy %02d: đang làm bài bình thường. Tốn 1 ảnh!" % (idx + 1), Color("#BDC3C7"), 22, 1.0)
	_update_hud()

func _inspect_station(idx: int) -> void:
	current_idx = idx if not is_cctv else current_idx
	var st: Dictionary = stations[idx]
	inspect_panel.visible = true
	inspect_panel.set_meta("idx", idx)
	inspect_title.text = "🔍 SOI MÁY %02d – THÍ SINH %s" % [idx + 1, st["name"]]
	if st["booked"]:
		inspect_text.text = "Thí sinh đã bị lập biên bản và đình chỉ thi."
		inspect_text.modulate = Color("#BDC3C7")
		confiscate_btn.disabled = true
		force_btn.visible = false
		return
	force_btn.visible = true
	var ev: int = int(st["evidence"])
	if ev > 0:
		var info: Dictionary = TELL_INFO[int(st["tell"])]
		inspect_text.text = "📒 Có %d bằng chứng ảnh: %s\n📜 Đối chiếu: %s → VI PHẠM.\n✅ Đủ căn cứ lập biên bản đình chỉ thi." % [ev, info["name"], info["rule"]]
		inspect_text.modulate = Color("#E74C3C")
		confiscate_btn.disabled = false
		confiscate_btn.text = "🚨 LẬP BIÊN BẢN ĐÌNH CHỈ THI [SPACE]"
	else:
		inspect_text.text = "📒 Chưa có bằng chứng ảnh nào của máy này.\nMàn hình hiện EOS bình thường, ngăn bàn trống (lúc này).\n⚠️ Lập biên bản không bằng chứng = rủi ro bắt oan (-35 uy tín)."
		inspect_text.modulate = Color("#F1C40F")
		confiscate_btn.disabled = true
		confiscate_btn.text = "🚨 LẬP BIÊN BẢN (cần ≥1 bằng chứng)"

func _on_confiscate_pressed() -> void:
	if not inspect_panel.visible or confiscate_btn.disabled:
		return
	var idx: int = int(inspect_panel.get_meta("idx", -1))
	if idx == -1:
		return
	_book(idx, false)

func _on_force_book() -> void:
	if not inspect_panel.visible:
		return
	var idx: int = int(inspect_panel.get_meta("idx", -1))
	if idx == -1 or stations[idx]["booked"]:
		return
	_book(idx, true)

func _book(idx: int, forced: bool) -> void:
	var st: Dictionary = stations[idx]
	st["booked"] = true
	inspect_panel.visible = false
	var student: Node3D = st["student"]
	if st["is_cheater"]:
		caught += 1
		var gain: int = 100 + (50 if int(st["evidence"]) >= 2 else 0)
		if forced and int(st["evidence"]) == 0:
			reputation -= 10
			gain = 40
			GameFX.popup("🚨 ĐÌNH CHỈ MÁY %02d – đúng là thánh tool, nhưng thiếu bằng chứng: SV khiếu nại (-10 uy tín)" % (idx + 1), GameFX.FPT_YELLOW, 24, 1.8)
		else:
			GameFX.popup("🚨 ĐÌNH CHỈ MÁY %02d! %s: 'Dạ em... em xin lỗi thầy cô' (+%d)" % [idx + 1, st["name"], gain], GameFX.FPT_GREEN, 26, 1.6)
		score += gain
		_set_tell_visual(st, false)
		st["tell_active"] = false
		GameFX.play_sfx("success")
		(st["tag"] as Label3D).text = "MÁY %02d ⛔ ĐÌNH CHỈ" % (idx + 1)
		(st["tag"] as Label3D).modulate = Color("#E74C3C")
		var tw := create_tween()
		tw.tween_property(student, "position", student.position + Vector3(0, 0, 1.5), 0.5)
		tw.tween_property(student, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	else:
		wrong_books += 1
		reputation -= 35
		score = maxi(0, score - 50)
		GameFX.play_sfx("miss")
		GameFX.shake(0.4)
		GameFX.flash(GameFX.FPT_RED, 0.35, 0.4)
		GameFX.popup("😭 BẮT OAN! %s khóc: 'EM OAN MÀ THẦY ƠI!' – cả phòng xì xào (-35 uy tín)" % st["name"], GameFX.FPT_RED, 26, 2.2)
		(st["tag"] as Label3D).text = "MÁY %02d 😭 OAN" % (idx + 1)
		(st["tag"] as Label3D).modulate = Color("#F1C40F")
	_update_hud()
	if reputation <= 0:
		_fail_stage("UY TÍN VỀ 0! Phòng Khảo thí: 'Thầy/cô bắt oan quá nhiều, đình chỉ coi thi.' (bắt đúng %d, bắt oan %d)" % [caught, wrong_books])
	elif caught >= NEED_CAUGHT:
		_complete_stage()

func _on_close_inspect() -> void:
	inspect_panel.visible = false

# ===========================================================================
# KẾT THÚC
# ===========================================================================
func _complete_stage() -> void:
	if is_stage_ended:
		return
	is_stage_ended = true
	inspect_panel.visible = false
	GameFX.clear_vignette()
	var total: int = score + int(maxf(0.0, time_left) * 8.0) + reputation * 3
	var rank: String = GameFX.rank_for(float(total), 1100.0, 850.0, 600.0)
	if wrong_books > 0 and rank == "S":
		rank = "A"
	StageManager.report_stage_result(StageManager.StageID.STAGE_EXTRA_EOS, {
		"result": "win", "score": total, "rank": rank,
		"detail": "caught=%d wrong=%d photos=%d rep=%d" % [caught, wrong_books, photos_used, reputation]
	})
	GameFX.play_sfx("res://assets/audio/victory_fanfare.wav", 2.0)
	GameFX.flash(GameFX.FPT_GREEN, 0.4, 0.5)
	modal_title.text = "⚖️ DANH HIỆU 'GIÁM THỊ CÔNG LÝ FPTU' – RANK %s" % rank
	modal_title.modulate = Color("#2ECC71")
	modal_sub.text = "Bắt đúng %d thánh tool trong %ds · bắt oan %d · dùng %d/%d ảnh · uy tín còn %d.\nQuy trình chuẩn: quan sát → chụp bằng chứng → đối chiếu quy chế → lập biên bản.\nTổng điểm %d. Kỷ cương phòng thi EOS được giữ vững!" % [
		caught, int(STAGE_TIME - time_left), wrong_books, photos_used, MAX_PHOTOS, reputation, total
	]
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _fail_stage(reason: String) -> void:
	if is_stage_ended:
		return
	is_stage_ended = true
	inspect_panel.visible = false
	GameFX.clear_vignette()
	StageManager.report_stage_result(StageManager.StageID.STAGE_EXTRA_EOS, {"result": "fail", "score": score, "rank": "C", "detail": reason})
	GameFX.play_sfx("res://assets/audio/absent_gameover.wav", 2.0)
	modal_title.text = "❌ THẤT BẠI TRONG PHÒNG KHẢO THÍ!"
	modal_title.modulate = Color("#E74C3C")
	modal_sub.text = reason
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _on_replay_pressed() -> void:
	StageManager.change_stage(StageManager.StageID.STAGE_1_RACE)

func _on_menu_pressed() -> void:
	StageManager.open_stage_select()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
