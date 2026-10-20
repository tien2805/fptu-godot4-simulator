# File: res://scripts/Stage4_Vovinam.gd
# MÀN 4: VOVINAM ĐẠI CHIẾN
#   Pha 1: Rhythm lane 3 vòng nhanh dần (85/110/135 BPM), Perfect/Good/Miss, combo x1-x4,
#          3 Miss liên tiếp = hít đất mash [SPACE]; vòng 3 phải ≥70% trúng mới được thi finisher.
#   Pha 2: Finisher ĐÒN CHÂN KẸP CỔ SỐ 21 = chuỗi 5 bước: giữ [W] lấy đà -> [SPACE] đúng vòng ->
#          [←][→] luân phiên 6 lần -> [SPACE] kẹp -> [↓] quật. Sai bước nào ngã, làm lại từ đầu, -3s.
#   Thành công: slow-motion, camera zoom, nộm ngã cinematic.
class_name Stage4_Vovinam
extends Node3D

@onready var rhythm_panel: PanelContainer = $HUD/RhythmPanel
@onready var rhythm_vbox: VBoxContainer = $HUD/RhythmPanel/VBox
@onready var command_label: Label = $HUD/RhythmPanel/VBox/CommandLabel
@onready var target_key_label: Label = $HUD/RhythmPanel/VBox/KeyLabel
@onready var combo_label: Label = $HUD/RhythmPanel/VBox/ComboLabel
@onready var finisher_panel: PanelContainer = $HUD/FinisherPanel
@onready var finisher_vbox: VBoxContainer = $HUD/FinisherPanel/VBox
@onready var finisher_label: Label = $HUD/FinisherPanel/VBox/Label
@onready var power_bar: ProgressBar = $HUD/FinisherPanel/VBox/PowerBar
@onready var execute_btn: Button = $HUD/FinisherPanel/VBox/ExecuteButton
@onready var top_title: Label = $HUD/TopTitle/Label

@onready var dummy: Node3D = $Arena/TrainingDummy
@onready var dummy_body: CSGCylinder3D = $Arena/TrainingDummy/DummyBody
@onready var dummy_head: CSGSphere3D = $Arena/TrainingDummy/DummyHead
@onready var player_fighter: Node3D = $Arena/PlayerFighter
@onready var fighter_body: CSGCylinder3D = $Arena/PlayerFighter/Body
@onready var fighter_head: CSGSphere3D = $Arena/PlayerFighter/Head
@onready var mat_pad: CSGBox3D = $Arena/MatPad
@onready var camera: Camera3D = $Camera3D
@onready var hud: CanvasLayer = $HUD

@onready var modal_overlay: ColorRect = $HUD/ModalOverlay
@onready var modal_title: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/TitleLabel
@onready var modal_sub: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/SubLabel
@onready var next_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/NextButton
@onready var menu_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/MenuButton
@onready var retry_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/RetryButton

enum State { INTRO, RHYTHM, PUSHUP, BREAK, FINISHER, CINEMATIC, DONE }

const ROUNDS: Array = [
	{"bpm": 85, "notes": 8, "name": "VÒNG 1 – KHỞI ĐỘNG"},
	{"bpm": 110, "notes": 10, "name": "VÒNG 2 – NHANH HƠN!"},
	{"bpm": 135, "notes": 12, "name": "VÒNG 3 – HẾT TỐC LỰC! (cần ≥70% trúng)"}
]
const APPROACH_TIME: float = 1.8
const PERFECT_WIN: float = 0.07
const GOOD_WIN: float = 0.15
const FINISHER_TIME: float = 30.0

var KEY_DEFS: Dictionary = {
	KEY_LEFT: {"icon": "⬅", "name": "ĐẤM THẲNG", "move": "punch", "color": Color("#E74C3C")},
	KEY_RIGHT: {"icon": "➡", "name": "CHÉM CẠNH TAY", "move": "chop", "color": Color("#F39C12")},
	KEY_UP: {"icon": "⬆", "name": "TRUNG BÌNH TẤN", "move": "stance", "color": Color("#3498DB")},
	KEY_DOWN: {"icon": "⬇", "name": "ĐÁ TẠT", "move": "kick", "color": Color("#9B59B6")},
	KEY_SPACE: {"icon": "␣", "name": "HÉT KHÍ THẾ", "move": "shout", "color": Color("#2ECC71")}
}

var state: int = State.INTRO
var song_time: float = 0.0
var round_idx: int = 0
var round3_retries: int = 0
var notes: Array[Dictionary] = []
var round_hits: int = 0
var round_total: int = 0
var combo: int = 0
var max_combo: int = 0
var score: int = 0
var perfects: int = 0
var goods: int = 0
var misses: int = 0
var consecutive_misses: int = 0
var pushup_count: int = 0
var pushup_timer: float = 0.0
var pushups_done: int = 0
var break_timer: float = 0.0
var intro_timer: float = 2.2

# Finisher
var fin_step: int = 1
var fin_progress: float = 0.0
var fin_time_left: float = FINISHER_TIME
var fin_fails: int = 0
var ring_t: float = 0.0
var ring_duration: float = 1.4
var ring_target: float = 0.25
var ring_window: float = 0.09
var alt_count: int = 0
var alt_last_key: int = 0
var alt_timer: float = 0.0
var slam_timer: float = 0.0
var fighter_start_pos: Vector3
var cinematic_timer: float = 0.0
var cam_start_xform: Transform3D

# Nodes tạo bằng code
var lane: Control
var hit_zone: ColorRect
var pushup_panel: PanelContainer
var pushup_label: Label
var pushup_bar: ProgressBar
var fin_ring: Control
var master: Node3D
var master_bubble: Label3D
var dummy_mat: StandardMaterial3D
var fighter_model: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

class TimingRing extends Control:
	var ratio: float = 1.0
	var target: float = 0.25
	var window: float = 0.09
	var active: bool = false
	var flash: float = 0.0
	var good: bool = true
	func _ready() -> void:
		custom_minimum_size = Vector2(150, 150)
	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta * 3.0)
		queue_redraw()
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r_max: float = 66.0
		var col: Color = Color("#F1C40F")
		if flash > 0.0:
			col = (Color("#2ECC71") if good else Color("#E74C3C")).lerp(Color("#F1C40F"), 1.0 - flash)
		draw_circle(c, r_max + 4.0, Color(0.08, 0.1, 0.16, 0.9))
		# Vùng vàng mục tiêu
		draw_arc(c, r_max * (target + window), 0.0, TAU, 64, Color(1.0, 0.85, 0.2, 0.35), r_max * window * 2.0, true)
		draw_arc(c, r_max * target, 0.0, TAU, 64, col, 3.0, true)
		if active:
			draw_arc(c, maxf(2.0, r_max * ratio), 0.0, TAU, 64, Color(0.95, 0.98, 1.0, 0.9), 3.0, true)
		draw_circle(c, 5.0 + flash * 5.0, col)

func _ready() -> void:
	modal_overlay.visible = false
	finisher_panel.visible = false
	rhythm_panel.visible = true

	_apply_mat_texture()
	_build_fighter_limbs()
	_build_arena_extras()
	_build_rhythm_ui()
	_build_pushup_ui()
	_build_finisher_ui()

	execute_btn.visible = false
	GameFX.disable_button_focus(hud)
	GameFX.upgrade_scene_visuals(self, "outdoor")
	next_btn.pressed.connect(_on_next_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)

	fighter_start_pos = player_fighter.position
	cam_start_xform = camera.global_transform
	command_label.text = "THẦY HÔ: 'NGHIÊM! LỄ!' – CHUẨN BỊ VÀO NHỊP..."
	target_key_label.text = "⬅ ĐẤM · ➡ CHÉM · ⬆ TẤN · ⬇ ĐÁ · ␣ HÉT  —  BẤM KHI NỐT CHẠM VÙNG SÁNG"
	combo_label.text = "COMBO 0 · x1 · ĐIỂM 0"
	_update_title()

# ===========================================================================
# DỰNG 3D
# ===========================================================================
func _apply_mat_texture() -> void:
	var path: String = "res://assets/textures/vovinam_mat.png"
	if FileAccess.file_exists(path):
		var img: Image = GameFX.load_image_any(path)
		if img:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat_pad.material_override = mat

func _build_fighter_limbs() -> void:
	# Võ sinh CharacterBuilder (võ phục xanh, đai vàng, mặt thật). CSG Body/Head/Belt cũ ẩn đi.
	# Gốc PlayerFighter ở y = 0.8 → model đặt y = -0.8; mặt quay về +X (phía nộm) nên xoay -90°.
	fighter_body.visible = false
	fighter_head.visible = false
	var belt_csg: Node3D = player_fighter.get_node_or_null("Belt")
	if belt_csg:
		belt_csg.visible = false
	fighter_model = CharacterBuilder.build({"preset": "vovinam", "seed": 2805, "name": "FighterModel", "glasses": false})
	fighter_model.position = Vector3(0.0, -0.8, 0.0)
	fighter_model.rotation.y = -PI * 0.5
	player_fighter.add_child(fighter_model)
	CharacterBuilder.set_base_clip(fighter_model, "stance")
	arm_l = CharacterBuilder.get_pivot(fighter_model, "shoulder_l")
	arm_r = CharacterBuilder.get_pivot(fighter_model, "shoulder_r")
	leg_l = CharacterBuilder.get_pivot(fighter_model, "thigh_l")
	leg_r = CharacterBuilder.get_pivot(fighter_model, "thigh_r")

	# Vật liệu nộm riêng để flash khi trúng đòn
	dummy_mat = StandardMaterial3D.new()
	dummy_mat.albedo_color = Color(0.65, 0.45, 0.3)
	dummy_mat.roughness = 0.8
	dummy_mat.emission_enabled = true
	dummy_mat.emission = Color.WHITE
	dummy_mat.emission_energy_multiplier = 0.0
	dummy_mat.albedo_color = Color(0.92, 0.8, 0.64)
	dummy_mat.albedo_texture = CharacterBuilder._tex("prop_wood.png")
	dummy_mat.uv1_triplanar = true
	dummy_mat.uv1_scale = Vector3(1.5, 1.5, 1.5)
	dummy_body.visible = false
	dummy_head.visible = false
	var dummy_model: Node3D = PropBuilder.build_training_dummy(dummy, dummy_mat)
	dummy_model.position = Vector3(0.0, -0.8, 0.0)

func _build_arena_extras() -> void:
	# Thầy võ trên bục
	master = Node3D.new()
	master.position = Vector3(0.0, 0.0, -4.6)
	$Arena.add_child(master)
	var mat_red := StandardMaterial3D.new()
	mat_red.albedo_color = Color("#C0392B")
	var podium := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(2.2, 0.4, 1.4)
	podium.mesh = pm
	podium.material_override = mat_red
	podium.position = Vector3(0.0, 0.2, 0.0)
	master.add_child(podium)
	var master_model: Node3D = CharacterBuilder.build({"preset": "master", "seed": 5, "name": "MasterModel", "clip": "guard", "height": 1.04})
	master_model.position = Vector3(0.0, 0.4, 0.0)
	master_model.rotation.y = PI
	master.add_child(master_model)
	master_bubble = Label3D.new()
	master_bubble.text = "🥋 THẦY: Nghiêm! Lễ!"
	master_bubble.font_size = 40
	master_bubble.outline_size = 12
	master_bubble.modulate = Color.WHITE
	master_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	master_bubble.position = Vector3(0.0, 2.7, 0.0)
	master.add_child(master_bubble)

	# Hàng đồng môn áo xanh đứng nghiêm xem thi (người thật, tay chắp sau lưng)
	for i: int in range(8):
		var s: Node3D = CharacterBuilder.build({"preset": "vovinam", "seed": 400 + i * 11, "name": "Peer%d" % i, "clip": "guard"})
		s.position = Vector3(-7.0 + i * 2.0, 0.0, -7.5)
		s.rotation.y = PI
		$Arena.add_child(s)

	# SÂN VÕ ĐẶT GIỮA NỬA SÂN LÁT GẠCH CỦA SÂN TRONG CAMPUS THẬT: toàn bộ vòng nhà, hồ sen, cóc vàng bao quanh
	var cm: Dictionary = FPTUCampusBuilder.make_materials()
	var world := Node3D.new()
	world.name = "CampusWorld"
	world.position = Vector3(-60.5, 0.0, -53.0)
	$Arena.add_child(world)
	FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {"grass": true})
	FPTUCampusBuilder.build_hutech(world, Vector3(135.0, 0.0, -26.0), cm)
	FPTUCampusBuilder.build_d1_road_piece(world, -13.0, -80.0, 300.0, cm, 0.0)
	# Nắng từ phía sau lưng người xem để thảm võ không bị bóng cánh nhà che
	$DirectionalLight3D.rotation_degrees = Vector3(-62.0, 20.0, 0.0)
	# Băng rôn giải đấu treo trên hiên cột cánh trước + cờ Vovinam hai bên
	var mat_banner := StandardMaterial3D.new()
	mat_banner.albedo_color = Color("#0055A5")
	var banner := MeshInstance3D.new()
	var bnm := BoxMesh.new()
	bnm.size = Vector3(11.0, 1.3, 0.08)
	banner.mesh = bnm
	banner.material_override = mat_banner
	banner.position = Vector3(0.0, 3.0, -17.4)
	$Arena.add_child(banner)
	var bl := Label3D.new()
	bl.text = "GIẢI VOVINAM FPTU – ĐÒN CHÂN KẸP CỔ #21\nCLB VOVINAM ĐẠI HỌC FPT TP.HCM"
	bl.font_size = 34
	bl.outline_size = 8
	bl.modulate = Color("#FFD100")
	bl.position = Vector3(0.0, 3.0, -17.34)
	$Arena.add_child(bl)
	var mat_flag_b := StandardMaterial3D.new()
	mat_flag_b.albedo_color = Color("#0055A5")
	var mat_flag_y := StandardMaterial3D.new()
	mat_flag_y.albedo_color = Color("#FFD100")
	for fx: float in [-10.0, 10.0]:
		var pole := MeshInstance3D.new()
		var plm := CylinderMesh.new()
		plm.top_radius = 0.05
		plm.bottom_radius = 0.07
		plm.height = 5.0
		pole.mesh = plm
		pole.material_override = cm["steel"]
		pole.position = Vector3(fx, 2.5, -9.5)
		$Arena.add_child(pole)
		for k: int in range(2):
			var flag := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(1.4, 0.45, 0.03)
			flag.mesh = fm
			flag.material_override = mat_flag_b if k == 0 else mat_flag_y
			flag.position = Vector3(fx + 0.72, 4.6 - k * 0.5, -9.5)
			$Arena.add_child(flag)

# ===========================================================================
# UI
# ===========================================================================
func _build_rhythm_ui() -> void:
	lane = Control.new()
	lane.custom_minimum_size = Vector2(680, 92)
	lane.clip_contents = true
	rhythm_vbox.add_child(lane)
	rhythm_vbox.move_child(lane, 1)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.1, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_child(bg)
	var mid := ColorRect.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.offset_top = 44.0
	mid.offset_bottom = 48.0
	mid.color = Color(1, 1, 1, 0.08)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_child(mid)
	hit_zone = ColorRect.new()
	hit_zone.position = Vector2(50.0, 6.0)
	hit_zone.size = Vector2(64.0, 80.0)
	hit_zone.color = Color(1.0, 0.85, 0.2, 0.28)
	hit_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_child(hit_zone)
	var hz_lbl := GameFX.make_label("HIT", 12, Color("#F1C40F"))
	hz_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_zone.add_child(hz_lbl)

func _build_pushup_ui() -> void:
	pushup_panel = GameFX.anchored_panel(hud, Control.PRESET_CENTER, Vector2(560, 0), 24, Color("#E74C3C"))
	pushup_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pushup_panel.add_child(vb)
	vb.add_child(GameFX.make_label("💢 THẦY: 'SAI NHỊP 3 LẦN! HÍT ĐẤT 10 CÁI!'", 22, Color("#E74C3C")))
	pushup_label = GameFX.make_label("MASH [SPACE]: 0 / 10 – còn 4.0s", 20, Color.WHITE)
	vb.add_child(pushup_label)
	pushup_bar = GameFX.make_bar(0.0, Color("#E74C3C"), 20)
	vb.add_child(pushup_bar)

func _build_finisher_ui() -> void:
	var center := CenterContainer.new()
	finisher_vbox.add_child(center)
	finisher_vbox.move_child(center, 1)
	fin_ring = TimingRing.new()
	center.add_child(fin_ring)
	power_bar.custom_minimum_size = Vector2(0, 22)

func _update_title() -> void:
	match state:
		State.RHYTHM, State.PUSHUP, State.BREAK, State.INTRO:
			var r: Dictionary = ROUNDS[mini(round_idx, 2)]
			top_title.text = "🥋 VOVINAM · %s · %d BPM · ĐIỂM %d" % [str(r["name"]).split(" –")[0], int(r["bpm"]), score]
		State.FINISHER:
			top_title.text = "🥋 FINISHER ĐÒN CHÂN KẸP CỔ #21 · BƯỚC %d/5 · ⏱ %ds · ĐIỂM %d" % [fin_step, int(ceil(fin_time_left)), score]
		_:
			top_title.text = "🥋 VOVINAM ĐẠI CHIẾN – SÂN VÕ FPTU · ĐIỂM %d" % score

# ===========================================================================
# INPUT
# ===========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if state == State.DONE or state == State.CINEMATIC:
		return
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var key: int = _normalize_key(event.physical_keycode)
	match state:
		State.RHYTHM:
			if KEY_DEFS.has(key):
				_judge_press(key)
		State.PUSHUP:
			if key == KEY_SPACE:
				_pushup_press()
		State.FINISHER:
			_finisher_key(key)

func _normalize_key(k: int) -> int:
	match k:
		KEY_A: return KEY_LEFT
		KEY_D: return KEY_RIGHT
		KEY_W: return KEY_UP
		KEY_S: return KEY_DOWN
		KEY_ENTER: return KEY_SPACE
	return k

# ===========================================================================
# VÒNG LẶP
# ===========================================================================
func _process(delta: float) -> void:
	match state:
		State.INTRO:
			intro_timer -= delta
			if intro_timer <= 0.0:
				_start_round(0)
		State.RHYTHM:
			song_time += delta
			_update_notes()
			_check_round_end()
		State.PUSHUP:
			pushup_timer -= delta
			pushup_label.text = "MASH [SPACE]: %d / 10 – còn %.1fs" % [pushup_count, maxf(0.0, pushup_timer)]
			pushup_bar.value = pushup_count * 10.0
			if pushup_timer <= 0.0:
				_end_pushup(false)
		State.BREAK:
			break_timer -= delta
			if break_timer <= 0.0:
				_start_round(round_idx)
		State.FINISHER:
			_process_finisher(delta)
		State.CINEMATIC:
			cinematic_timer -= delta
			if camera and dummy:
				camera.look_at(dummy.global_position + Vector3(0, 0.6, 0), Vector3.UP)
			if cinematic_timer <= 0.0:
				_complete_stage()
	_update_title()

# ===========================================================================
# PHA 1: RHYTHM
# ===========================================================================
func _start_round(idx: int) -> void:
	round_idx = idx
	state = State.RHYTHM
	var r: Dictionary = ROUNDS[idx]
	var beat: float = 60.0 / float(r["bpm"])
	round_hits = 0
	round_total = int(r["notes"])
	consecutive_misses = 0
	for n: Dictionary in notes:
		if is_instance_valid(n["node"]):
			n["node"].queue_free()
	notes.clear()
	var keys: Array = KEY_DEFS.keys()
	var last_key: int = -1
	var streak: int = 0
	var has_space: bool = false
	for i: int in range(round_total):
		var k: int = keys[randi() % keys.size()]
		if k == last_key:
			streak += 1
			if streak >= 2:
				k = keys[(keys.find(k) + 1 + randi() % (keys.size() - 1)) % keys.size()]
				streak = 0
		else:
			streak = 0
		if i == round_total - 1 and not has_space:
			k = KEY_SPACE
		if k == KEY_SPACE:
			has_space = true
		last_key = k
		_spawn_note(song_time + APPROACH_TIME + 0.6 + float(i) * beat, k)
	command_label.text = "THẦY HÔ: '%s' – %d BPM" % [str(r["name"]), int(r["bpm"])]
	master_bubble.text = "🥋 THẦY: %s" % str(r["name"]).split(" –")[0]
	target_key_label.text = "MỘT! HAI! BA! BỐN! – bấm đúng phím khi nốt vào vùng HIT"
	target_key_label.modulate = Color("#F1C40F")
	GameFX.play_sfx("beep", -4.0, 0.9 + idx * 0.15)

func _spawn_note(t: float, key: int) -> void:
	var def: Dictionary = KEY_DEFS[key]
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = def["color"]
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(56, 56)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := GameFX.make_label(def["icon"], 30, Color.WHITE)
	pc.add_child(lbl)
	lane.add_child(pc)
	pc.position = Vector2(lane.size.x + 10.0, 18.0)
	notes.append({"time": t, "key": key, "node": pc, "judged": false})

func _update_notes() -> void:
	var hit_x: float = hit_zone.position.x + hit_zone.size.x * 0.5 - 28.0
	var travel: float = lane.size.x - hit_x
	if travel < 100.0:
		travel = 620.0
	for n: Dictionary in notes:
		if n["judged"]:
			continue # Nốt đã chấm tự animate & tự free, không đụng vào nữa
		if not is_instance_valid(n["node"]):
			continue
		var node: Control = n["node"]
		var dt: float = float(n["time"]) - song_time
		node.position.x = hit_x + dt / APPROACH_TIME * travel
		if dt < -GOOD_WIN:
			_judge_result(n, "MISS", "TRỄ RỒI!")

func _judge_press(key: int) -> void:
	var best: Dictionary = {}
	var best_dt: float = 999.0
	for n: Dictionary in notes:
		if n["judged"]:
			continue
		var dt: float = absf(float(n["time"]) - song_time)
		if dt < best_dt:
			best_dt = dt
			best = n
	if best.is_empty() or best_dt > 0.32:
		return # Bấm lúc không có nốt: bỏ qua, không phạt
	if int(best["key"]) != key:
		_judge_result(best, "MISS", "SAI PHÍM! Thầy hô %s mà!" % str(KEY_DEFS[int(best["key"])]["name"]))
		return
	if best_dt <= PERFECT_WIN:
		_judge_result(best, "PERFECT", "PERFECT!")
	elif best_dt <= GOOD_WIN:
		_judge_result(best, "GOOD", "GOOD")
	else:
		_judge_result(best, "MISS", "LỆCH NHỊP!")

func _judge_result(n: Dictionary, grade: String, text: String) -> void:
	n["judged"] = true
	var node: Control = n["node"] if is_instance_valid(n["node"]) else null
	var key: int = int(n["key"])
	var def: Dictionary = KEY_DEFS[key]
	match grade:
		"PERFECT", "GOOD":
			combo += 1
			max_combo = maxi(max_combo, combo)
			consecutive_misses = 0
			round_hits += 1
			var mult: int = 1 + mini(combo / 8, 3)
			var pts: int = (100 if grade == "PERFECT" else 50) * mult
			score += pts
			if grade == "PERFECT":
				perfects += 1
			else:
				goods += 1
			target_key_label.text = "%s +%d (x%d) – %s!" % [text, pts, mult, str(def["name"])]
			target_key_label.modulate = Color("#2ECC71") if grade == "PERFECT" else Color("#F1C40F")
			_play_move(def["move"], grade == "PERFECT")
			GameFX.play_sfx("hit" if def["move"] != "shout" else "pop", -4.0 if grade == "PERFECT" else -8.0, 1.1 if grade == "PERFECT" else 0.95)
			if grade == "PERFECT":
				GameFX.popup("PERFECT!", Color("#2ECC71"), 30, 0.35)
			if is_instance_valid(node):
				var tw := create_tween()
				tw.set_parallel(true)
				tw.tween_property(node, "scale", Vector2(1.6, 1.6), 0.15)
				tw.tween_property(node, "modulate:a", 0.0, 0.15)
				tw.chain().tween_callback(node.queue_free)
		_:
			combo = 0
			misses += 1
			consecutive_misses += 1
			target_key_label.text = "✗ " + text
			target_key_label.modulate = Color("#E74C3C")
			GameFX.play_sfx("miss", -4.0)
			GameFX.shake(0.12)
			master_bubble.text = "🥋 THẦY: Tập trung khí công nào!"
			if is_instance_valid(node):
				var tw := create_tween()
				tw.tween_property(node, "modulate", Color(1, 0.3, 0.3, 0.0), 0.25)
				tw.tween_callback(node.queue_free)
			if consecutive_misses >= 3 and state == State.RHYTHM:
				_start_pushup()
	combo_label.text = "COMBO %d (max %d) · x%d · ĐIỂM %d · TRÚNG %d/%d" % [combo, max_combo, 1 + mini(combo / 8, 3), score, round_hits, round_total]

func _check_round_end() -> void:
	for n: Dictionary in notes:
		if not n["judged"]:
			return
	if notes.is_empty():
		return
	# Hết nốt của vòng
	var ratio: float = float(round_hits) / float(maxi(1, round_total))
	if round_idx < 2:
		round_idx += 1
		state = State.BREAK
		break_timer = 1.6
		command_label.text = "THẦY: 'ĐƯỢC! %d%% trúng. %s'" % [int(ratio * 100.0), str(ROUNDS[round_idx]["name"])]
		master_bubble.text = "🥋 THẦY: Nhanh hơn nữa!"
		GameFX.popup("HẾT VÒNG %d – %d%% TRÚNG" % [round_idx, int(ratio * 100.0)], Color("#F1C40F"), 30, 1.2)
		notes.clear()
	else:
		if ratio >= 0.7:
			notes.clear()
			_start_finisher()
		else:
			round3_retries += 1
			notes.clear()
			if round3_retries <= 1:
				state = State.BREAK
				break_timer = 2.0
				command_label.text = "THẦY: 'Mới %d%%! TẬP LẠI VÒNG 3 – cần ≥70% để được thi đòn kẹp cổ!'" % int(ratio * 100.0)
				master_bubble.text = "🥋 THẦY: Tập lại vòng 3!"
				GameFX.popup("CHƯA ĐỦ 70%! TẬP LẠI VÒNG 3 (lần cuối)", Color("#E74C3C"), 28, 1.6)
				GameFX.play_sfx("error")
			else:
				_fail_stage("THẦY: 'Vòng 3 vẫn chưa tới 70%%! Về tập thêm rồi thi lại nha.' – 0 ĐIỂM THỂ CHẤT (trúng %d%%)" % int(ratio * 100.0))

func _start_pushup() -> void:
	state = State.PUSHUP
	pushup_count = 0
	pushup_timer = 4.0
	pushup_panel.visible = true
	pushup_bar.value = 0.0
	GameFX.play_sfx("alarm", -2.0)
	GameFX.shake(0.3)
	master_bubble.text = "🥋 THẦY: HÍT ĐẤT 10 CÁI!!"
	var tw := create_tween()
	CharacterBuilder.play(fighter_model, "plank", 999.0)
	tw.tween_property(player_fighter, "rotation_degrees:z", -80.0, 0.25)
	tw.parallel().tween_property(player_fighter, "position:y", 0.35, 0.25)

func _pushup_press() -> void:
	pushup_count += 1
	GameFX.play_sfx("tick", -6.0, 0.8 + pushup_count * 0.03)
	var tw := create_tween()
	tw.tween_property(player_fighter, "position:y", 0.2, 0.06)
	tw.tween_property(player_fighter, "position:y", 0.35, 0.08)
	if pushup_count >= 10:
		_end_pushup(true)

func _end_pushup(success: bool) -> void:
	pushup_panel.visible = false
	pushups_done += 1
	consecutive_misses = 0
	combo = 0
	var tw := create_tween()
	CharacterBuilder.stop_clip(fighter_model)
	tw.tween_property(player_fighter, "rotation_degrees:z", 0.0, 0.25)
	tw.parallel().tween_property(player_fighter, "position:y", fighter_start_pos.y, 0.25)
	if success:
		GameFX.popup("HÍT ĐẤT XONG! VÀO LẠI NHỊP!", Color("#2ECC71"), 28, 1.0)
		master_bubble.text = "🥋 THẦY: Được rồi, vào nhịp!"
	else:
		score = maxi(0, score - 100)
		GameFX.popup("HÍT ĐẤT CHẬM QUÁ! -100 ĐIỂM", Color("#E74C3C"), 28, 1.2)
		master_bubble.text = "🥋 THẦY: Yếu quá! Vào nhịp lại!"
	# Dời các nốt chưa đánh về sau để người chơi kịp phản ứng
	for n: Dictionary in notes:
		if not n["judged"]:
			n["time"] = float(n["time"]) + 0.6
	state = State.RHYTHM

# ---------------------------------------------------------------------------
# Animation đòn thế trên capsule
# ---------------------------------------------------------------------------
func _play_move(move: String, strong: bool) -> void:
	var amp: float = 1.0 if strong else 0.75
	var tw := create_tween()
	match move:
		"punch":
			tw.set_parallel(true)
			CharacterBuilder.play(fighter_model, "punch", 0.42)
			tw.tween_property(player_fighter, "position:x", fighter_start_pos.x + 0.45 * amp, 0.07)
			tw.chain().tween_interval(0.22)
			tw.parallel().tween_property(player_fighter, "position:x", fighter_start_pos.x, 0.22)
			_dummy_hit(0.3 * amp)
		"chop":
			tw.set_parallel(true)
			CharacterBuilder.play(fighter_model, "chop", 0.4)
			tw.tween_property(player_fighter, "rotation_degrees:y", -45.0 * amp, 0.08)
			tw.chain().tween_interval(0.22)
			tw.parallel().tween_property(player_fighter, "rotation_degrees:y", 0.0, 0.22)
			_dummy_hit(0.22 * amp)
		"stance":
			tw.set_parallel(true)
			tw.tween_property(player_fighter, "position:y", fighter_start_pos.y - 0.28, 0.1)
			CharacterBuilder.play(fighter_model, "stance", 0.45)
			tw.chain().tween_interval(0.15)
			tw.chain().tween_property(player_fighter, "position:y", fighter_start_pos.y, 0.15)
		"kick":
			tw.set_parallel(true)
			CharacterBuilder.play(fighter_model, "kick", 0.62)
			tw.tween_property(player_fighter, "position:y", fighter_start_pos.y + 0.18, 0.09)
			tw.chain().tween_interval(0.22)
			tw.parallel().tween_property(player_fighter, "position:y", fighter_start_pos.y, 0.22)
			_dummy_hit(0.35 * amp)
		"shout":
			CharacterBuilder.play(fighter_model, "cheer_once", 0.6)
			tw.tween_property(player_fighter, "scale", Vector3(1.18, 1.18, 1.18), 0.08)
			tw.tween_property(player_fighter, "scale", Vector3.ONE, 0.2)
			GameFX.float_text(self, player_fighter.global_position + Vector3(0, 2.0, 0), "ÁAAAA!", Color("#F1C40F"), 56)
			GameFX.shake(0.15)

func _dummy_hit(amount: float) -> void:
	if state == State.CINEMATIC or state == State.DONE:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dummy, "position:x", 2.5 + amount, 0.06)
	tw.tween_property(dummy, "rotation_degrees:z", -amount * 40.0, 0.06)
	tw.tween_property(dummy_mat, "emission_energy_multiplier", 1.2, 0.05)
	tw.chain().tween_property(dummy, "position:x", 2.5, 0.25)
	tw.parallel().tween_property(dummy, "rotation_degrees:z", 0.0, 0.25)
	tw.parallel().tween_property(dummy_mat, "emission_energy_multiplier", 0.0, 0.25)
	GameFX.hit_stop(0.04, 0.1)

# ===========================================================================
# PHA 2: FINISHER CHUỖI 5 BƯỚC
# ===========================================================================
func _start_finisher() -> void:
	state = State.FINISHER
	rhythm_panel.visible = false
	finisher_panel.visible = true
	fin_time_left = FINISHER_TIME
	fin_fails = 0
	master_bubble.text = "🥋 THẦY: Đòn chân kẹp cổ số 21! Lấy đà!"
	GameFX.popup("🎉 QUA VÒNG 3! THI TRIỂN ĐÒN CHÂN KẸP CỔ SỐ 21!", Color("#2ECC71"), 30, 1.8)
	GameFX.play_sfx("success")
	_set_fin_step(1)

func _set_fin_step(step: int) -> void:
	if fighter_model:
		CharacterBuilder.set_speed(fighter_model, 0.0)
	fin_step = step
	fin_progress = 0.0
	fin_ring.active = false
	power_bar.value = 0.0
	match step:
		1:
			finisher_label.text = "BƯỚC 1/5 – GIỮ [W] 1.2s ĐỂ CHẠY ĐÀ (thả sớm là mất đà!)"
			power_bar.visible = true
		2:
			finisher_label.text = "BƯỚC 2/5 – BẤM [SPACE] KHI VÒNG TRẮNG CO VÀO VÙNG VÀNG → PHÓNG NGƯỜI!"
			ring_t = 0.0
			ring_duration = 1.4
			ring_target = 0.25
			ring_window = 0.09
			fin_ring.target = ring_target
			fin_ring.window = ring_window
			fin_ring.active = true
			power_bar.visible = false
		3:
			finisher_label.text = "BƯỚC 3/5 – XOAY NGƯỜI 360°: BẤM [←] [→] LUÂN PHIÊN 6 LẦN TRONG 2s!"
			alt_count = 0
			alt_last_key = 0
			alt_timer = 2.0
			power_bar.visible = true
		4:
			finisher_label.text = "BƯỚC 4/5 – [SPACE] ĐÚNG TIMING ĐỂ KẸP HAI CHÂN VÀO CỔ NỘM!"
			ring_t = 0.0
			ring_duration = 1.0
			ring_target = 0.3
			ring_window = 0.08
			fin_ring.target = ring_target
			fin_ring.window = ring_window
			fin_ring.active = true
			power_bar.visible = false
		5:
			finisher_label.text = "BƯỚC 5/5 – BẤM [↓] NGAY ĐỂ QUẬT NGÃ!!"
			slam_timer = 1.2
			power_bar.visible = true

func _process_finisher(delta: float) -> void:
	fin_time_left -= delta
	if fin_time_left <= 0.0:
		_fail_stage("HẾT 30 GIÂY FINISHER! Thầy: 'Đòn 21 là phải dứt khoát!' – Ngã %d lần, thiếu chút nữa thôi!" % fin_fails)
		return
	match fin_step:
		1:
			var holding: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
			if holding:
				fin_progress = minf(1.0, fin_progress + delta / 1.2)
				player_fighter.position.x = lerpf(fighter_start_pos.x, dummy.position.x - 1.4, fin_progress)
				CharacterBuilder.set_speed(fighter_model, 2.6)
				if fin_progress >= 1.0:
					GameFX.play_sfx("whoosh", -4.0)
					_set_fin_step(2)
			elif fin_progress > 0.05:
				_finisher_fail("THẢ [W] SỚM – MẤT ĐÀ!")
				return
			power_bar.value = fin_progress * 100.0
		2, 4:
			ring_t += delta / ring_duration
			fin_ring.ratio = 1.0 - ring_t
			if ring_t >= 1.0:
				_finisher_fail("TRỄ TIMING – VÒNG ĐÃ KHÉP!")
				return
		3:
			alt_timer -= delta
			power_bar.value = float(alt_count) / 6.0 * 100.0
			player_fighter.rotation_degrees.y = float(alt_count) * 60.0
			if alt_timer <= 0.0:
				_finisher_fail("XOAY CHẬM QUÁ – CHƯA ĐỦ 6 NHỊP!")
				return
		5:
			slam_timer -= delta
			power_bar.value = slam_timer / 1.2 * 100.0
			if slam_timer <= 0.0:
				_finisher_fail("CHẬM TAY – NỘM VÙNG RA!")
				return

func _finisher_key(key: int) -> void:
	match fin_step:
		2:
			if key == KEY_SPACE:
				if absf(fin_ring.ratio - ring_target) <= ring_window:
					fin_ring.good = true
					fin_ring.flash = 1.0
					GameFX.play_sfx("jump", -2.0)
					var tw := create_tween()
					tw.tween_property(player_fighter, "position:y", fighter_start_pos.y + 1.6, 0.3).set_ease(Tween.EASE_OUT)
					_set_fin_step(3)
				else:
					fin_ring.good = false
					fin_ring.flash = 1.0
					_finisher_fail("SAI TIMING PHÓNG NGƯỜI!" if fin_ring.ratio > ring_target else "TRỄ TIMING!")
		3:
			if key == KEY_LEFT or key == KEY_RIGHT:
				if alt_last_key == key:
					_finisher_fail("PHẢI LUÂN PHIÊN ← → – BẤM TRÙNG PHÍM!")
					return
				alt_last_key = key
				alt_count += 1
				GameFX.play_sfx("tick", -4.0, 0.9 + alt_count * 0.08)
				if alt_count >= 6:
					GameFX.play_sfx("whoosh", -2.0, 1.3)
					_set_fin_step(4)
		4:
			if key == KEY_SPACE:
				if absf(fin_ring.ratio - ring_target) <= ring_window:
					fin_ring.good = true
					fin_ring.flash = 1.0
					GameFX.play_sfx("hit", -2.0)
					var tw := create_tween()
					tw.tween_property(player_fighter, "position", dummy.position + Vector3(0.0, 1.5, 0.0), 0.18)
					tw.parallel().tween_property(player_fighter, "rotation_degrees:x", -90.0, 0.18)
					_set_fin_step(5)
				else:
					fin_ring.good = false
					fin_ring.flash = 1.0
					_finisher_fail("KẸP HỤT – SAI TIMING!")
		5:
			if key == KEY_DOWN:
				_finisher_success()

func _finisher_fail(reason: String) -> void:
	fin_fails += 1
	fin_time_left -= 3.0
	fin_ring.active = false
	GameFX.play_sfx("thud")
	GameFX.shake(0.5)
	GameFX.flash(Color("#E74C3C"), 0.3, 0.3)
	GameFX.popup("💥 RỚT XUỐNG THẢM! %s (-3s, làm lại từ bước 1)" % reason, Color("#E74C3C"), 26, 1.6)
	master_bubble.text = "🥋 THẦY: Đứng dậy! Làm lại!"
	var tw := create_tween()
	tw.tween_property(player_fighter, "rotation_degrees", Vector3(0, 0, 70.0), 0.2)
	tw.tween_property(player_fighter, "position", fighter_start_pos + Vector3(0, -0.4, 0), 0.2)
	tw.tween_interval(0.3)
	tw.tween_property(player_fighter, "rotation_degrees", Vector3.ZERO, 0.25)
	tw.parallel().tween_property(player_fighter, "position", fighter_start_pos, 0.25)
	_set_fin_step(1)

func _finisher_success() -> void:
	state = State.CINEMATIC
	cinematic_timer = 2.6
	finisher_panel.visible = false
	GameFX.slow_motion(0.28, 1.5)
	GameFX.flash(Color.WHITE, 0.7, 0.5)
	GameFX.shake(0.9)
	GameFX.play_sfx("explode")
	GameFX.play_sfx("res://assets/audio/crash_bump.wav", 4.0, 0.7)
	master_bubble.text = "🥋 THẦY: TUYỆT KỸ SỐ 21!!!"
	GameFX.float_text(self, dummy.global_position + Vector3(0, 2.6, 0), "ĐÒN CHÂN KẸP CỔ SỐ 21!!!", Color("#F1C40F"), 64, 2.0)
	# Nộm ngã bounce, võ sinh tiếp đất
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dummy, "rotation_degrees:x", -88.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dummy, "position:y", 0.35, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_fighter, "position", dummy.position + Vector3(-0.9, 0.0, 0.6), 0.5)
	tw.tween_property(player_fighter, "rotation_degrees", Vector3(0, 0, 0), 0.5)
	# Camera zoom + orbit quanh nộm
	var cam_tw := create_tween()
	cam_tw.tween_property(camera, "global_position", dummy.global_position + Vector3(2.2, 1.9, 3.2), 0.9).set_ease(Tween.EASE_OUT)
	cam_tw.tween_property(camera, "global_position", dummy.global_position + Vector3(-2.6, 1.6, 2.8), 1.5)
	cam_tw.parallel().tween_property(camera, "fov", 42.0, 1.2)

# ===========================================================================
# KẾT THÚC
# ===========================================================================
func _complete_stage() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	Engine.time_scale = 1.0
	var fin_bonus: int = int(maxf(0.0, fin_time_left) * 20.0) + maxi(0, 3 - fin_fails) * 100
	score += fin_bonus
	var total_notes: int = perfects + goods + misses
	var rank: String = GameFX.rank_for(float(score), 2600.0, 1900.0, 1200.0)
	StageManager.report_stage_result(StageManager.StageID.STAGE_4_VOVINAM, {
		"result": "win", "score": score, "rank": rank,
		"detail": "perfect=%d good=%d miss=%d maxcombo=%d finfails=%d" % [perfects, goods, misses, max_combo, fin_fails]
	})
	GameFX.play_sfx("res://assets/audio/victory_fanfare.wav", 2.0)
	modal_title.text = "🥋 ĐIỂM 10 VOVINAM – ĐÒN CHÂN KẸP CỔ #21! RANK %s" % rank
	modal_title.modulate = Color("#2ECC71")
	modal_sub.text = "Quyền pháp: %d PERFECT · %d GOOD · %d MISS (%d nốt) · combo cao nhất %d · hít đất %d lần.\nFinisher: ngã %d lần, hoàn thành khi còn %ds (+%d điểm).\nTổng điểm: %d – đồng môn vỗ tay rần rần!" % [
		perfects, goods, misses, total_notes, max_combo, pushups_done, fin_fails, int(maxf(0.0, fin_time_left)), fin_bonus, score
	]
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _fail_stage(reason: String) -> void:
	if state == State.DONE:
		return
	state = State.DONE
	Engine.time_scale = 1.0
	rhythm_panel.visible = false
	finisher_panel.visible = false
	pushup_panel.visible = false
	StageManager.report_stage_result(StageManager.StageID.STAGE_4_VOVINAM, {"result": "fail", "score": score, "rank": "C", "detail": reason})
	GameFX.play_sfx("res://assets/audio/absent_gameover.wav", 2.0)
	modal_title.text = "❌ RỚT MÔN VOVINAM!"
	modal_title.modulate = Color("#E74C3C")
	modal_sub.text = reason + "\nĐiểm quyền pháp tạm tính: %d (PERFECT %d · GOOD %d · MISS %d)" % [score, perfects, goods, misses]
	next_btn.visible = false
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _on_next_pressed() -> void:
	StageManager.change_stage(StageManager.StageID.STAGE_5_CANTEEN)

func _on_menu_pressed() -> void:
	StageManager.open_stage_select()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
