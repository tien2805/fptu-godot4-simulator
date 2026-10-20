# File: res://scripts/Stage2_Parking.gd
# MÀN 2: BÃI XE D1 & CHINH PHỤC CẦU THANG NGOÀI TRỜI LÊN LAB 402 – DIỄN RA TRONG CHÍNH KHUÔN VIÊN THẬT CỦA MÀN 1.
#   FPTUCampusBuilder dựng cùng một campus (vòng nhà chữ nhật, sân trong, bãi xe có mái, HUTECH đối diện qua D1)
#   tại gốc toạ độ. Màn 1 về đích ngay trước CỔNG BÃI XE D1 (u = 174) -> Màn 2 bắt đầu đúng chỗ đó trên đường D1.
#
#   Pha 1 (55s): rẽ phải từ D1 vào cổng bãi xe, dừng trước barie quét thẻ [E] với bác bảo vệ, barie mở, chạy dọc
#                lối xe ven cánh phải toà nhà (~95 m) tới bãi xe máy có mái phía sau, tranh ô đỗ với xe NPC,
#                đỗ thẳng & dừng hẳn, có thể lùi [S], còi [H] doạ xe NPC. Máy bán nước sau lưng toà nhà có Monster:
#                rẽ vào lấy tốn vài giây (risk/reward cho pha 2).
#   Pha 2 (48s): AUTO-RUNNER 3D theo Path3D xuyên campus: bãi xe -> lối đi bộ qua dãy A -> lối vào sau (tầng trệt
#                cánh sau) -> sân trong (vòng qua hồ sen) -> sảnh chính -> sân trước -> CẦU THANG NGOÀI TRỜI 3 đợt
#                -> cửa Lab 402 (lầu 4, cánh phải). [A/D] đổi làn, [SPACE] nhảy, [S] trượt, [SHIFT] sprint, [Q] Monster.
class_name Stage2_Parking
extends Node3D

signal stage_completed()

@onready var timer_label: Label = $HUD/TopBar/TimerPanel/TimerLabel
@onready var mission_label: Label = $HUD/TopBar/MissionPanel/MissionLabel
@onready var stamina_panel: PanelContainer = $HUD/StaminaPanel
@onready var stamina_bar: ProgressBar = $HUD/StaminaPanel/VBox/StaminaBar
@onready var stamina_label: Label = $HUD/StaminaPanel/VBox/StaminaLabel
@onready var prompt_panel: PanelContainer = $HUD/PromptPanel
@onready var prompt_label: Label = $HUD/PromptPanel/PromptLabel

@onready var modal_overlay: ColorRect = $HUD/ModalOverlay
@onready var modal_title: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/TitleLabel
@onready var modal_sub: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/SubLabel
@onready var next_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/NextButton
@onready var menu_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/MenuButton
@onready var retry_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/RetryButton

@onready var env_root: Node3D = $Environment
@onready var barie_arm: MeshInstance3D = $Environment/BarieArm
@onready var target_spot: Area3D = $Environment/TargetParkingSpot
@onready var marker_pad: CSGBox3D = $Environment/TargetParkingSpot/MarkerPad
@onready var player_bike: CharacterBody3D = $PlayerBike
@onready var campus_root: Node3D = $Environment/CampusBuildingRoot
@onready var staircase_root: Node3D = $Environment/StaircaseRoot
@onready var hud: CanvasLayer = $HUD

# ----- Thiết kế -----
const PHASE1_TIME: float = 55.0
const PHASE2_TIME: float = 48.0   # Chạy thẳng không vấp ~36s trên ~215 m -> được phép vấp ~6 lần
const GATE_U: float = FPTUCampusBuilder.PARK_GATE_U
const GUARD_POS: Vector3 = Vector3(180.6, 0.0, 2.3)      # Bác bảo vệ đứng cạnh trụ barie, trước bốt
const BIKE_START: Vector3 = Vector3(146.0, 0.4, -9.7)    # Làn phải đường D1, 28 m trước cổng bãi xe (đích Màn 1)
const RIVAL_START: Vector3 = Vector3(174.0, 0.0, 13.0)   # Xe NPC đã quét thẻ trước, đang đứng sau barie
const MONSTER_POS: Vector3 = Vector3(138.0, 0.0, 86.6)   # Máy bán nước sát mặt sau cánh sau (phải rẽ vào lấy)
const HUTECH_ORIGIN: Vector3 = Vector3(135.0, 0.0, -26.0) # Cùng toạ độ tương đối như Màn 1
const LANE_OFFSET: float = 1.5
const RUN_SPEED: float = 6.0
const SPRINT_SPEED: float = 9.0
const JUMP_DURATION: float = 0.62
const SLIDE_DURATION: float = 0.68
const RIVAL_SPEED: float = 4.6

# ----- Trạng thái chung -----
var spot_candidates: Array[Vector3] = FPTUCampusBuilder.parking_spot_candidates()
var campus_mats: Dictionary = {}
var time_left: float = PHASE1_TIME
var elapsed_total: float = 0.0
var is_phase_2: bool = false
var is_stage_ended: bool = false
var prompt_timer: float = 0.0

# ----- Pha 1 -----
var has_scanned_card: bool = false
var has_parked: bool = false
var is_near_guard: bool = false
var spot_idx: int = 0
var inside_spot: bool = false
var park_hold: float = 0.0
var park_retries: int = 0
var spot_stolen: bool = false
var park_time_left: float = 0.0
var floating_marker: MeshInstance3D
var guard_bubble: Label3D
var guard_nag_timer: float = 5.0
var guard_nag_idx: int = 0
var barie_arm2: Node3D
var rival_root: Node3D
var rival_bubble: Label3D
var rival_waypoints: Array[Vector3] = []
var rival_wp_idx: int = 0
var rival_delay: float = 2.5
var rival_pause: float = 0.0
var rival_horn_cd: float = 0.0
var rival_done: bool = false
var monster_can: Node3D
var monster_area: Area3D
var monster_taken: bool = false

# ----- Pha 2 -----
var run_curve: Curve3D
var run_length: float = 1.0
var run_progress: float = 0.0
var run_speed_cur: float = 0.0
var lane: int = 0
var lane_x: float = 0.0
var runner_body: Node3D
var runner_visual: Node3D
var runner_left_leg: Node3D
var runner_right_leg: Node3D
var runner_left_arm: Node3D
var runner_right_arm: Node3D
var jump_t: float = -1.0
var slide_t: float = -1.0
var stumble_timer: float = 0.0
var exhausted_timer: float = 0.0
var free_sprint_timer: float = 0.0
var heart_sfx_timer: float = 0.0
var stamina: float = 100.0
var stumbles: int = 0
var dodges: int = 0
var obstacles: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var run_cam: Camera3D
var route_points: Array[Vector3] = []
var hud_run_panel: PanelContainer
var run_progress_bar: ProgressBar
var monster_label: Label
var has_won: bool = false

func _ready() -> void:
	modal_overlay.visible = false
	prompt_panel.visible = false
	stamina_panel.visible = false

	# Xe máy trong campus: chậm, lái gắt, có lùi, không kẹp làn (không có Path3D)
	if player_bike:
		player_bike.set("max_speed_ms", 11.0)
		player_bike.set("steer_speed", 3.2)
		player_bike.set("lane_clamp_enabled", false)
		player_bike.set("reverse_speed_ms", 3.0)
		player_bike.global_position = BIKE_START
		player_bike.rotation.y = -PI * 0.5 # chạy theo +X dọc D1 (cùng chiều Màn 1)

	next_btn.pressed.connect(_on_next_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	target_spot.body_entered.connect(_on_target_spot_entered)
	target_spot.body_exited.connect(_on_target_spot_exited)

	_build_world()
	_build_gate_props()
	_create_floating_marker()
	_build_rival()
	_build_monster_machine()
	_build_phase2_hud()
	_apply_spot(0)
	GameFX.disable_button_focus(hud)
	GameFX.upgrade_scene_visuals(self, "outdoor")

	mission_label.text = "RẼ PHẢI VÀO CỔNG BÃI XE D1 (BÊN PHẢI) → DỪNG TRƯỚC BARIE, BẤM [E] QUÉT THẺ DÂY CAM!"
	_say("⏱ 07:26 AM! VỀ TỚI ĐƯỜNG D1 – FPTU BÊN PHẢI, HUTECH BÊN TRÁI. CỔNG BÃI XE NGAY PHÍA TRƯỚC. [H] CÒI · [S] LÙI", GameFX.FPT_YELLOW, 4.5)

# ===========================================================================
# INPUT
# ===========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if is_stage_ended:
		return
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var key: int = event.physical_keycode
	if is_phase_2:
		match key:
			KEY_A, KEY_LEFT:
				if lane > -1:
					lane -= 1
					GameFX.play_sfx("tick", -8.0)
			KEY_D, KEY_RIGHT:
				if lane < 1:
					lane += 1
					GameFX.play_sfx("tick", -8.0)
			KEY_SPACE, KEY_W, KEY_UP:
				if jump_t < 0.0 and slide_t < 0.0 and stumble_timer <= 0.0 and exhausted_timer <= 0.0:
					jump_t = 0.0
					GameFX.play_sfx("jump", -6.0)
			KEY_S, KEY_DOWN:
				if slide_t < 0.0 and jump_t < 0.0 and stumble_timer <= 0.0:
					slide_t = 0.0
					GameFX.play_sfx("slide", -8.0)
			KEY_Q:
				_try_drink_monster()
	else:
		if key == KEY_E and is_near_guard and not has_scanned_card:
			_scan_student_card()

# ===========================================================================
# HUD HELPERS
# ===========================================================================
func _say(text: String, color: Color = GameFX.FPT_YELLOW, duration: float = 2.5) -> void:
	prompt_panel.visible = true
	prompt_label.text = text
	prompt_label.modulate = color
	prompt_timer = duration

func _build_phase2_hud() -> void:
	hud_run_panel = GameFX.anchored_panel(hud, Control.PRESET_CENTER_TOP, Vector2(620, 0), 92, GameFX.FPT_ORANGE)
	hud_run_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	hud_run_panel.add_child(vb)
	vb.add_child(GameFX.make_label("🏁 BÃI XE → LỐI SAU → SÂN TRONG → SẢNH → CẦU THANG NGOÀI TRỜI → LAB 402", 13, GameFX.FPT_YELLOW))
	run_progress_bar = GameFX.make_bar(0.0, GameFX.FPT_ORANGE, 16)
	vb.add_child(run_progress_bar)
	monster_label = GameFX.make_label("", 13, Color("#BDC3C7"))
	vb.add_child(monster_label)
	_refresh_monster_label()

func _refresh_monster_label() -> void:
	if not monster_label:
		return
	var n: int = StageManager.item_count("monster")
	monster_label.text = "[A/D] LÀN · [SPACE] NHẢY · [S] TRƯỢT · [SHIFT] SPRINT · [Q] MONSTER x%d" % n

# ===========================================================================
# DỰNG THẾ GIỚI: CAMPUS THẬT (CÙNG BUILDER MÀN 1) + ĐƯỜNG D1 + HUTECH
# ===========================================================================
func _build_world() -> void:
	campus_mats = FPTUCampusBuilder.make_materials()
	var gaps: Array = []
	for sp: Vector3 in spot_candidates:
		gaps.append(Vector2(sp.x, sp.z))
	FPTUCampusBuilder.build_authentic_campus(campus_root, Vector3.ZERO, 0.0, {
		"colliders": true,
		"parking_gaps": gaps,
		"skip_barrier_at": GATE_U,
		"grass": true
	})
	FPTUCampusBuilder.build_d1_road_piece(campus_root, FPTUCampusBuilder.ROAD_CENTER_V, -80.0, 300.0, campus_mats, 0.0)
	FPTUCampusBuilder.build_hutech(campus_root, HUTECH_ORIGIN, campus_mats, true)

	# Cổng chính (u = 6) đóng với xe máy sinh viên: thanh chắn + nón + bảng chỉ sang cổng bãi xe
	var mg: float = FPTUCampusBuilder.MAIN_GATE_U
	var closure := StaticBody3D.new()
	closure.position = Vector3(mg, 0.0, 1.6)
	campus_root.add_child(closure)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(13.0, 2.0, 0.6)
	cs.shape = bs
	cs.position = Vector3(0.0, 1.0, 0.0)
	closure.add_child(cs)
	var mat_stripe := StandardMaterial3D.new()
	mat_stripe.albedo_color = Color("#E74C3C")
	for i: int in range(6):
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 0.12, 0.12)
		seg.mesh = bm
		seg.material_override = mat_stripe if i % 2 == 0 else campus_mats["white"]
		seg.position = Vector3(-5.0 + i * 2.0, 0.95, 0.0)
		closure.add_child(seg)
	for sx: float in [-1.0, 1.0]:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.22
		cm.height = 0.7
		cone.mesh = cm
		cone.material_override = campus_mats["orange"]
		cone.position = Vector3(sx * 4.0, 0.35, -0.6)
		closure.add_child(cone)
	var lbl := Label3D.new()
	lbl.text = "⛔ CỔNG CHÍNH: Ô TÔ & KHÁCH\nXE MÁY SINH VIÊN → CỔNG BÃI XE D1 (CUỐI ĐƯỜNG, BÊN PHẢI) ➔"
	lbl.font_size = 22
	lbl.outline_size = 8
	lbl.modulate = Color("#F1C40F")
	lbl.position = Vector3(0.0, 2.1, -0.3)
	lbl.rotation_degrees.y = 180.0
	closure.add_child(lbl)

func _build_gate_props() -> void:
	# Thanh barie thứ hai (trụ trái) – hai thanh 5.5 m chắn kín lối vào 12 m; sọc đỏ trắng
	var m: Dictionary = campus_mats
	var pole2 := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.12
	pm.bottom_radius = 0.14
	pm.height = 1.2
	pole2.mesh = pm
	pole2.material_override = m["steel"]
	pole2.position = Vector3(168.8, 0.6, 3.2)
	env_root.add_child(pole2)
	barie_arm2 = Node3D.new()
	barie_arm2.position = Vector3(168.8, 1.2, 3.2)
	env_root.add_child(barie_arm2)
	var arm2 := MeshInstance3D.new()
	var abm := BoxMesh.new()
	abm.size = Vector3(5.5, 0.14, 0.14)
	arm2.mesh = abm
	arm2.material_override = m["line"]
	arm2.position = Vector3(2.75, 0.0, 0.0)
	barie_arm2.add_child(arm2)
	var arm1_mesh: Node3D = barie_arm.get_node_or_null("ArmMesh")
	if arm1_mesh is CSGBox3D:
		(arm1_mesh as CSGBox3D).material = m["line"]
	var mat_red := StandardMaterial3D.new()
	mat_red.albedo_color = Color("#E74C3C")
	for i: int in range(4):
		for holder: Array in [[barie_arm, -1.0], [barie_arm2, 1.0]]:
			var stripe := MeshInstance3D.new()
			var sbm := BoxMesh.new()
			sbm.size = Vector3(0.55, 0.16, 0.16)
			stripe.mesh = sbm
			stripe.material_override = mat_red
			var sgn: float = float(holder[1])
			stripe.position = Vector3(sgn * (0.8 + i * 1.3), 0.0, 0.0)
			(holder[0] as Node3D).add_child(stripe)

	# Trụ đầu đọc thẻ bên phải lối vào
	var reader := Node3D.new()
	reader.position = Vector3(178.2, 0.0, 0.4)
	env_root.add_child(reader)
	var post := MeshInstance3D.new()
	var postm := CylinderMesh.new()
	postm.top_radius = 0.06
	postm.bottom_radius = 0.08
	postm.height = 1.1
	post.mesh = postm
	post.material_override = m["steel"]
	post.position = Vector3(0.0, 0.55, 0.0)
	reader.add_child(post)
	var head := MeshInstance3D.new()
	var hbm := BoxMesh.new()
	hbm.size = Vector3(0.28, 0.36, 0.14)
	head.mesh = hbm
	head.material_override = m["dark"]
	head.position = Vector3(0.0, 1.25, 0.0)
	head.rotation_degrees.x = -20.0
	reader.add_child(head)
	var led := MeshInstance3D.new()
	var lbm := BoxMesh.new()
	lbm.size = Vector3(0.18, 0.05, 0.02)
	led.mesh = lbm
	led.material_override = campus_mats["orange"]
	led.position = Vector3(0.0, 1.33, -0.08)
	reader.add_child(led)
	var rl := Label3D.new()
	rl.text = "QUÉT THẺ SV\n[E]"
	rl.font_size = 18
	rl.outline_size = 6
	rl.modulate = Color("#F1C40F")
	rl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rl.position = Vector3(0.0, 1.75, 0.0)
	reader.add_child(rl)

	# Bác bảo vệ đứng gác + bong bóng thoại
	var guard := Node3D.new()
	guard.position = GUARD_POS
	env_root.add_child(guard)
	var g_body := MeshInstance3D.new()
	var g_b_mesh := CapsuleMesh.new()
	g_b_mesh.radius = 0.25
	g_b_mesh.height = 1.65
	g_body.mesh = g_b_mesh
	var mat_guard := StandardMaterial3D.new()
	mat_guard.albedo_color = Color("#2980B9")
	g_body.material_override = mat_guard
	g_body.position = Vector3(0.0, 0.85, 0.0)
	guard.add_child(g_body)
	var g_head := MeshInstance3D.new()
	var gh_m := SphereMesh.new()
	gh_m.radius = 0.16
	gh_m.height = 0.32
	g_head.mesh = gh_m
	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = Color("#E0B084")
	g_head.material_override = mat_skin
	g_head.position = Vector3(0.0, 1.62, 0.0)
	guard.add_child(g_head)
	var g_cap := MeshInstance3D.new()
	var gc_m := CylinderMesh.new()
	gc_m.top_radius = 0.19
	gc_m.bottom_radius = 0.19
	gc_m.height = 0.08
	g_cap.mesh = gc_m
	var mat_cap := StandardMaterial3D.new()
	mat_cap.albedo_color = Color("#1B4F72")
	g_cap.material_override = mat_cap
	g_cap.position = Vector3(0.0, 1.8, 0.0)
	guard.add_child(g_cap)
	guard_bubble = Label3D.new()
	guard_bubble.text = "👮 Thẻ sinh viên đâu em?!"
	guard_bubble.font_size = 30
	guard_bubble.outline_size = 10
	guard_bubble.modulate = Color("#FFFFFF")
	guard_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guard_bubble.no_depth_test = true
	guard_bubble.position = Vector3(0.0, 2.6, 0.0)
	guard.add_child(guard_bubble)

func _create_floating_marker() -> void:
	floating_marker = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.0, 1.4, 0.4)
	floating_marker.mesh = prism
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#F1C40F")
	mat.emission_enabled = true
	mat.emission = Color("#F1C40F") * 0.8
	floating_marker.material_override = mat
	floating_marker.rotation_degrees = Vector3(180, 0, 0)
	env_root.add_child(floating_marker)

func _apply_spot(idx: int) -> void:
	spot_idx = clampi(idx, 0, spot_candidates.size() - 1)
	var sp: Vector3 = spot_candidates[spot_idx]
	target_spot.position = sp + Vector3(0.0, 1.0, 0.0)
	if floating_marker:
		floating_marker.position = sp + Vector3(0.0, 2.8, 0.0)
	inside_spot = false
	park_hold = 0.0

func _build_rival() -> void:
	rival_root = Node3D.new()
	rival_root.name = "RivalBike"
	rival_root.position = RIVAL_START
	env_root.add_child(rival_root)

	var body := StaticBody3D.new()
	body.add_to_group("traffic_obstacle")
	rival_root.add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.2, 1.7)
	col.shape = box
	col.position = Vector3(0.0, 0.6, 0.0)
	body.add_child(col)

	FPTUCampusBuilder.build_motorbike(rival_root, Vector3.ZERO, 0.0, Color("#C0392B"), campus_mats)
	var mat_shirt := StandardMaterial3D.new()
	mat_shirt.albedo_color = Color("#3498DB")
	var rider := MeshInstance3D.new()
	var rm := CapsuleMesh.new()
	rm.radius = 0.19
	rm.height = 0.7
	rider.mesh = rm
	rider.material_override = mat_shirt
	rider.position = Vector3(0.0, 1.12, 0.15)
	rival_root.add_child(rider)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.15
	hm.height = 0.3
	head.mesh = hm
	var mat_helmet := StandardMaterial3D.new()
	mat_helmet.albedo_color = Color("#F39C12")
	head.material_override = mat_helmet
	head.position = Vector3(0.0, 1.62, 0.1)
	rival_root.add_child(head)

	rival_bubble = Label3D.new()
	rival_bubble.text = "🛵 Ô gần nhất là của tui!"
	rival_bubble.font_size = 28
	rival_bubble.outline_size = 10
	rival_bubble.modulate = Color("#FFEAA7")
	rival_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rival_bubble.no_depth_test = true
	rival_bubble.position = Vector3(0.0, 2.3, 0.0)
	rival_root.add_child(rival_bubble)

	_rival_plan_route(spot_candidates[0])

func _rival_plan_route(spot: Vector3) -> void:
	var lane_v: float = FPTUCampusBuilder.PARK_LANE_V
	rival_waypoints = [
		rival_root.position,
		Vector3(GATE_U, 0.0, 60.0),
		Vector3(GATE_U, 0.0, lane_v - 1.0),
		Vector3(spot.x + 6.0, 0.0, lane_v),
		Vector3(spot.x, 0.0, lane_v),
		spot
	]
	rival_wp_idx = 1

func _build_monster_machine() -> void:
	var m: Dictionary = campus_mats
	var kiosk := Node3D.new()
	kiosk.position = MONSTER_POS
	env_root.add_child(kiosk)
	var body := StaticBody3D.new()
	kiosk.add_child(body)
	var bcol := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(1.2, 2.0, 0.9)
	bcol.shape = bbox
	bcol.position = Vector3(0.0, 1.0, -0.45)
	body.add_child(bcol)
	var cab := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(1.1, 1.95, 0.8)
	cab.mesh = cbm
	var mat_cab := StandardMaterial3D.new()
	mat_cab.albedo_color = Color("#1E8449")
	mat_cab.roughness = 0.4
	cab.material_override = mat_cab
	cab.position = Vector3(0.0, 0.98, -0.45)
	kiosk.add_child(cab)
	var glass := MeshInstance3D.new()
	var gbm := BoxMesh.new()
	gbm.size = Vector3(0.9, 1.2, 0.04)
	glass.mesh = gbm
	glass.material_override = m["glass"]
	glass.position = Vector3(0.0, 1.25, -0.03)
	kiosk.add_child(glass)
	var light := MeshInstance3D.new()
	var lbm := BoxMesh.new()
	lbm.size = Vector3(1.0, 0.18, 0.05)
	light.mesh = lbm
	light.material_override = m["lamp"]
	light.position = Vector3(0.0, 1.95, -0.03)
	kiosk.add_child(light)
	var tex: Texture2D = FPTUCampusBuilder.load_texture("seven_eleven_sign.png")
	if tex:
		var sign := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 0.3)
		sign.mesh = qm
		var mat_s := StandardMaterial3D.new()
		mat_s.albedo_texture = tex
		mat_s.emission_enabled = true
		mat_s.emission_texture = tex
		mat_s.emission_energy_multiplier = 0.5
		sign.material_override = mat_s
		sign.position = Vector3(0.0, 0.45, -0.03)
		kiosk.add_child(sign)

	monster_can = Node3D.new()
	monster_can.position = Vector3(0.0, 1.4, 0.9)
	kiosk.add_child(monster_can)
	var can := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = 0.62
	can.mesh = cm
	var mat_can := StandardMaterial3D.new()
	mat_can.albedo_color = Color("#27AE60")
	mat_can.emission_enabled = true
	mat_can.emission = Color("#2ECC71") * 1.2
	mat_can.metallic = 0.6
	can.material_override = mat_can
	monster_can.add_child(can)

	var lbl := Label3D.new()
	lbl.text = "⚡ MÁY BÁN NƯỚC SAU TOÀ NHÀ: MONSTER MIỄN PHÍ CHO SV ĐI SỚM\nRẼ XE VÀO LẤY (MẤT VÀI GIÂY) · DÙNG [Q] KHI CHẠY BỘ"
	lbl.font_size = 22
	lbl.outline_size = 8
	lbl.modulate = Color("#2ECC71")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 3.2, 0.6)
	kiosk.add_child(lbl)

	monster_area = Area3D.new()
	var ac := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	ac.shape = sph
	monster_area.add_child(ac)
	monster_area.position = Vector3(0.0, 1.0, 1.2)
	kiosk.add_child(monster_area)
	monster_area.body_entered.connect(_on_monster_area_entered)

func _on_monster_area_entered(body: Node3D) -> void:
	if monster_taken or is_phase_2 or body != player_bike:
		return
	monster_taken = true
	StageManager.add_item("monster", 1)
	_refresh_monster_label()
	GameFX.play_sfx("cash")
	GameFX.flash(GameFX.FPT_GREEN, 0.3, 0.3)
	GameFX.popup("⚡ ĐÃ LẤY MONSTER! (Bấm [Q] khi chạy bộ lên Lab 402)", GameFX.FPT_GREEN, 28, 1.4)
	if monster_can:
		var tw := create_tween()
		tw.tween_property(monster_can, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tw.tween_callback(monster_can.queue_free)
		monster_can = null

# ===========================================================================
# TUYẾN CHẠY BỘ PHA 2 (Path3D xuyên campus thật)
# ===========================================================================
func _build_route() -> void:
	var sp: Vector3 = spot_candidates[spot_idx]
	var bu: float = FPTUCampusBuilder.back_gap_u()
	var lu: float = FPTUCampusBuilder.lobby_u()
	var lane_v: float = FPTUCampusBuilder.PARK_LANE_V
	var g: float = 0.1
	var pts: Array[Vector3] = [Vector3(sp.x, g, sp.z)]
	var cp_back: int = -1
	var cp_lobby: int = -1
	var cp_stair: int = -1
	if sp.z > 107.0:
		# Ô góc xa ở mặt ngoài dãy B: phải vòng qua đầu dãy mái che
		var west_end: float = FPTUCampusBuilder.PARK_CX - FPTUCampusBuilder.PARK_HALF_LEN - 3.0
		pts.append(Vector3(sp.x, g, 112.5))
		pts.append(Vector3(west_end, g, 112.5))
		pts.append(Vector3(west_end, g, lane_v))
	else:
		pts.append(Vector3(sp.x, g, lane_v))
	pts.append(Vector3(bu, g, lane_v))                       # chạy dọc làn xe tới lối đi bộ
	pts.append(Vector3(bu, g, 88.0))                         # qua khe dãy A -> sau lưng toà nhà
	cp_back = pts.size() - 1
	pts.append(Vector3(bu, g, FPTUCampusBuilder.RING_V1 - FPTUCampusBuilder.LONG_D)) # xuyên lối vào sau ra sân trong
	pts.append(Vector3(bu, g, 62.0))
	pts.append(Vector3(bu, g, 50.0))
	pts.append(Vector3(lu + 9.5, g, 42.0))                   # vòng qua hồ sen, hướng về sảnh
	pts.append(Vector3(lu, g, 42.0))
	pts.append(Vector3(lu, g, FPTUCampusBuilder.RING_V0))    # xuyên sảnh chính ra sân trước
	cp_lobby = pts.size() - 1
	pts.append(Vector3(lu, g, 15.5))
	var sf: Vector3 = FPTUCampusBuilder.stair_foot()
	pts.append(Vector3(sf.x - 4.0, g, 17.5))
	var prof: Array[Vector3] = FPTUCampusBuilder.stair_profile()
	for i: int in range(prof.size()):
		pts.append(prof[i] + Vector3(0.0, 0.05, 0.0))
		if i == 0:
			cp_stair = pts.size() - 1
	var door: Vector3 = FPTUCampusBuilder.lab402_door()
	var top_y: float = prof[prof.size() - 1].y + 0.05
	pts.append(Vector3(door.x - 0.6, top_y, FPTUCampusBuilder.STAIR_V))

	route_points = pts
	run_curve = Curve3D.new()
	run_curve.bake_interval = 0.25
	run_curve.up_vector_enabled = false # Chỉ cần vị trí; tắt bake up-vector để tránh lỗi axis tại góc cua 90°
	for p: Vector3 in pts:
		run_curve.add_point(p)
	run_length = run_curve.get_baked_length()

	checkpoints = [
		{"progress": run_curve.get_closest_offset(pts[cp_back]), "text": "📍 LỐI VÀO SAU – CĂN TIN E2A & 7-ELEVEN. XUYÊN QUA SÂN TRONG!", "done": false},
		{"progress": run_curve.get_closest_offset(pts[cp_lobby]), "text": "📍 SẢNH CHÍNH – RA SÂN TRƯỚC, CẦU THANG NGOÀI TRỜI BÊN PHẢI!", "done": false},
		{"progress": run_curve.get_closest_offset(pts[cp_stair]), "text": "📍 CẦU THANG NGOÀI TRỜI – 105 BẬC LÊN LAB 402! BỨT TỐC!", "done": false}
	]

# ===========================================================================
# VÒNG LẶP CHÍNH
# ===========================================================================
func _process(delta: float) -> void:
	if is_stage_ended:
		return

	time_left -= delta
	elapsed_total += delta
	_update_clock()

	if prompt_timer > 0.0:
		prompt_timer -= delta
		if prompt_timer <= 0.0:
			prompt_panel.visible = false

	if floating_marker and is_instance_valid(floating_marker):
		floating_marker.rotate_y(delta * 2.5)
		floating_marker.position.y = 2.8 + sin(Time.get_ticks_msec() * 0.005) * 0.35
	if monster_can and is_instance_valid(monster_can):
		monster_can.rotate_y(delta * 2.0)
		monster_can.position.y = 1.4 + sin(Time.get_ticks_msec() * 0.004) * 0.15

	if marker_pad and not has_parked:
		var blink: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		var mat: StandardMaterial3D = marker_pad.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.emission_enabled = true
			marker_pad.material_override = mat
		mat.albedo_color = Color("#F1C40F").lerp(Color("#E67E22"), blink)
		mat.emission = Color("#F1C40F") * (0.4 + blink * 0.8)

	if not is_phase_2:
		_process_phase_1(delta)
	else:
		_process_phase_2(delta)

	if time_left <= 0.0 and not is_stage_ended:
		if is_phase_2:
			_fail_stage("07:29! GIẢNG VIÊN ĐÓNG CỬA LAB 402 NGAY TRƯỚC MŨI BẠN. ABSENT!")
		else:
			_fail_stage("HẾT GIỜ GỬI XE! BÁC BẢO VỆ: 'Thôi em về đi, mai học lại nha!'")

func _update_clock() -> void:
	var game_sec: int = 26 * 60 + int(elapsed_total * 2.0)
	var phase_name: String = "CHẠY" if is_phase_2 else "ĐỖ XE"
	timer_label.text = "07:%02d:%02d · %s %ds" % [game_sec / 60, game_sec % 60, phase_name, int(ceil(maxf(0.0, time_left)))]
	if time_left < 8.0:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		timer_label.modulate = Color(1.0, 0.35 + pulse * 0.3, 0.35)
	else:
		timer_label.modulate = Color.WHITE

# ===========================================================================
# PHA 1: QUÉT THẺ, TRANH Ô, ĐỖ CHO CHUẨN
# ===========================================================================
func _process_phase_1(delta: float) -> void:
	_update_guard_nag(delta)
	_update_rival(delta)

	var p: Vector3 = player_bike.global_position
	var dist_to_guard: float = p.distance_to(GUARD_POS)
	if not has_scanned_card:
		is_near_guard = dist_to_guard < 9.0
		if is_near_guard and prompt_timer <= 0.0:
			_say("[BẤM PHÍM E]: XUẤT TRÌNH THẺ SINH VIÊN FPTU DÂY CAM CHO BÁC BẢO VỆ!", GameFX.FPT_YELLOW, 0.2)
			if Input.is_key_pressed(KEY_E):
				_scan_student_card()
		# Barie đang đóng: chặn xe ngay trước thanh chắn (z = 3.2)
		if p.z > 1.0 and absf(p.x - GATE_U) < 7.5:
			player_bike.global_position.z = 0.4
			player_bike.set("current_speed_ms", 0.0)
			_say("👮 BÁC BẢO VỆ TUÝT CÒI: 'Thẻ sinh viên dây cam đâu em ơi?!' (Bấm [E])", GameFX.FPT_RED, 1.5)
			GameFX.play_sfx("error", -4.0)
	else:
		is_near_guard = false
		# Còi xe làm xe NPC giật mình
		if Input.is_action_just_pressed("horn") and rival_root and not rival_done:
			if rival_horn_cd <= 0.0 and p.distance_to(rival_root.global_position) < 10.0:
				rival_pause = 1.6
				rival_horn_cd = 4.0
				_rival_say("😵 GIẬT CẢ MÌNH!!")
		_check_parking(delta)
	rival_horn_cd = maxf(0.0, rival_horn_cd - delta)

func _update_guard_nag(delta: float) -> void:
	guard_nag_timer -= delta
	if guard_nag_timer > 0.0:
		return
	guard_nag_timer = 7.0
	var lines: Array[String]
	if not has_scanned_card:
		lines = ["👮 Thẻ sinh viên đâu em?!", "👮 Nhanh lên, 7h29 rồi đó!", "👮 Không thẻ là không vô nha!", "👮 Rẽ vô cổng bãi xe nè em!"]
	else:
		lines = ["👮 Chạy thẳng tới bãi xe sau nhà!", "👮 Đỗ lẹ lên em ơi!", "👮 Bên trái làn còn ô kìa!", "👮 Xe sau đang chờ đó!", "👮 Dựng chân chống cho thẳng!"]
	guard_bubble.text = lines[guard_nag_idx % lines.size()]
	guard_nag_idx += 1
	var tw := create_tween()
	tw.tween_property(guard_bubble, "scale", Vector3(1.25, 1.25, 1.25), 0.12)
	tw.tween_property(guard_bubble, "scale", Vector3.ONE, 0.18)

func _rival_say(text: String) -> void:
	if rival_bubble:
		rival_bubble.text = text
		var tw := create_tween()
		tw.tween_property(rival_bubble, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
		tw.tween_property(rival_bubble, "scale", Vector3.ONE, 0.2)

func _update_rival(delta: float) -> void:
	if not rival_root or rival_done:
		return
	if rival_delay > 0.0:
		rival_delay -= delta
		if rival_delay <= 0.0:
			_rival_say("🛵 Ô gần nhất là của tui nha!")
		return
	if rival_pause > 0.0:
		rival_pause -= delta
		return
	if has_parked:
		rival_done = true
		_rival_say("😭 Trời ơi mất chỗ rồi!")
		return
	if rival_wp_idx >= rival_waypoints.size():
		rival_done = true
		return
	var target: Vector3 = rival_waypoints[rival_wp_idx]
	var pos: Vector3 = rival_root.position
	var to: Vector3 = target - pos
	to.y = 0.0
	var dist: float = to.length()
	var is_last: bool = rival_wp_idx == rival_waypoints.size() - 1
	if dist < 0.35:
		if is_last:
			_on_rival_reached_spot()
			return
		rival_wp_idx += 1
		return
	var speed: float = RIVAL_SPEED if not is_last else 2.2
	var step: Vector3 = to.normalized() * minf(speed * delta, dist)
	rival_root.position += step
	var yaw: float = atan2(-to.x, -to.z)
	rival_root.rotation.y = lerp_angle(rival_root.rotation.y, yaw, delta * 8.0)
	# Nếu người chơi đang đứng trong ô -> NPC nhường
	if is_last and dist < 3.5 and inside_spot:
		rival_done = true
		_rival_say("😅 Ủa có người rồi hả? Thôi nhường!")

func _on_rival_reached_spot() -> void:
	rival_done = true
	if has_parked or spot_stolen:
		return
	if inside_spot:
		_rival_say("😅 Ủa có người rồi hả? Thôi nhường!")
		return
	spot_stolen = true
	_rival_say("😜 HEHE NHANH CHÂN HƠN RỒI NHÉ!")
	GameFX.play_sfx("error")
	GameFX.shake(0.35)
	GameFX.flash(GameFX.FPT_RED, 0.25, 0.3)
	_apply_spot(spot_idx + 1)
	_say("😱 BỊ CƯỚP Ô RỒI! Ô TRỐNG KHÁC Ở DÃY ĐỐI DIỆN, GIỮA BÃI – THEO MŨI TÊN VÀNG!", GameFX.FPT_RED, 3.5)
	mission_label.text = "Ô ĐÃ BỊ CHIẾM! TÌM Ô VÀNG MỚI Ở DÃY A GIỮA BÃI, ĐỖ THẲNG & DỪNG HẲN!"

func _scan_student_card() -> void:
	if has_scanned_card:
		return
	has_scanned_card = true
	is_near_guard = false
	GameFX.play_sfx("pop")
	_say("✅ ĐÃ QUÉT THẺ DÂY CAM! BARIE MỞ. CHẠY DỌC LỐI XE VEN TOÀ NHÀ TỚI BÃI XE PHÍA SAU, ĐỖ VÀO Ô VÀNG!", GameFX.FPT_GREEN, 3.0)
	guard_bubble.text = "👮 Ờ vô đi, bãi xe sau nhà, lẹ lên!"
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(barie_arm, "rotation_degrees:z", -80.0, 0.8).set_trans(Tween.TRANS_SINE)
	if barie_arm2:
		tween.tween_property(barie_arm2, "rotation_degrees:z", 80.0, 0.8).set_trans(Tween.TRANS_SINE)
	mission_label.text = "CHẠY TỚI BÃI XE MÁY PHÍA SAU → LÁCH VÀO Ô VÀNG NHẤP NHÁY (XE KHÁC CŨNG ĐANG NHẮM!) – ĐỖ THẲNG & DỪNG HẲN"
	mission_label.add_theme_color_override("font_color", Color("#F1C40F"))

func _on_target_spot_entered(body: Node3D) -> void:
	if body == player_bike and has_scanned_card and not has_parked:
		inside_spot = true

func _on_target_spot_exited(body: Node3D) -> void:
	if body == player_bike and inside_spot and not has_parked:
		inside_spot = false
		if park_hold > 0.0 or has_scanned_card:
			park_retries += 1
		park_hold = 0.0

func _check_parking(delta: float) -> void:
	if not inside_spot or has_parked:
		return
	var sp: Vector3 = spot_candidates[spot_idx]
	var p: Vector3 = player_bike.global_position
	var speed: float = absf(float(player_bike.get("current_speed_ms")))
	var fwd: Vector3 = -player_bike.global_transform.basis.z
	var align_dot: float = absf(fwd.z) # dãy xe chạy dọc trục X -> xe phải nằm dọc trục Z
	var aligned: bool = align_dot >= 0.906 # lệch < 25°
	var centered: bool = absf(p.x - sp.x) < 0.7 and absf(p.z - sp.z) < 1.1

	if speed < 0.8 and aligned and centered:
		park_hold += delta
		_say("🅿️ ĐANG DỰNG CHÂN CHỐNG... %d%%" % int(park_hold / 0.6 * 100.0), GameFX.FPT_GREEN, 0.2)
		if park_hold >= 0.6:
			_on_parked()
	else:
		park_hold = maxf(0.0, park_hold - delta * 2.0)
		if prompt_timer <= 0.2:
			if not aligned:
				var deg: int = int(rad_to_deg(acos(clampf(align_dot, 0.0, 1.0))))
				_say("↔️ XE LỆCH %d°! CHỈNH THẲNG HÀNG VỚI DÃY XE (LÙI [S] RỒI VÀO LẠI)" % deg, GameFX.FPT_YELLOW, 0.2)
			elif not centered:
				_say("↕️ CHƯA VÀO HẲN Ô! TIẾN / LÙI [W]/[S] CHO GỌN", GameFX.FPT_YELLOW, 0.2)
			else:
				_say("✋ DỪNG HẲN XE LẠI!", GameFX.FPT_YELLOW, 0.2)

func _on_parked() -> void:
	if has_parked:
		return
	has_parked = true
	park_time_left = maxf(0.0, time_left)
	player_bike.set("is_controls_locked", true)
	GameFX.play_sfx("success")
	GameFX.flash(GameFX.FPT_GREEN, 0.35, 0.4)
	_say("✅ ĐÃ GỬI XE! THANG MÁY KẸT CỨNG → CHẠY BỘ XUYÊN CAMPUS, LEO CẦU THANG NGOÀI TRỜI LÊN LAB 402!", GameFX.FPT_GREEN, 2.0)
	guard_bubble.text = "👮 Đỗ đẹp đó! Lên lớp lẹ đi!"
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(_start_phase_2_stairs_climb)

# ===========================================================================
# PHA 2: AUTO-RUNNER THEO PATH3D
# ===========================================================================
func _start_phase_2_stairs_climb() -> void:
	if is_phase_2 or is_stage_ended:
		return
	is_phase_2 = true
	time_left = PHASE2_TIME
	stamina = 100.0
	run_progress = 0.0
	run_speed_cur = 0.0
	lane = 0
	lane_x = 0.0
	player_bike.set("is_controls_locked", true)
	if floating_marker and is_instance_valid(floating_marker):
		floating_marker.queue_free()
		floating_marker = null
	if rival_root and is_instance_valid(rival_root) and not rival_done:
		rival_done = true

	mission_label.text = "🏃 PHA 2: CHẠY BỘ XUYÊN CAMPUS & LEO 105 BẬC THANG NGOÀI TRỜI! NÉ SINH VIÊN ÁO CAM, XE ĐẨY, BĂNG RÔN – TỚI LAB 402 TRƯỚC 07:29!"
	mission_label.add_theme_color_override("font_color", Color("#F37021"))
	stamina_panel.visible = true
	stamina_label.text = "⚡ THỂ LỰC (GIỮ SHIFT ĐỂ SPRINT – HẾT LÀ HỤT HƠI!)"
	hud_run_panel.visible = true
	_refresh_monster_label()

	_build_route()
	_spawn_runner()
	_setup_run_camera()
	_spawn_obstacles()
	GameFX.flash(Color.WHITE, 0.6, 0.5)
	GameFX.play_sfx("whoosh")
	_say("⚡ [A/D] ĐỔI LÀN · [SPACE] NHẢY QUA XE ĐẨY/VŨNG NƯỚC · [S] TRƯỢT DƯỚI BĂNG RÔN · [SHIFT] SPRINT · [Q] MONSTER", GameFX.FPT_ORANGE, 5.0)

func _spawn_runner() -> void:
	runner_body = Node3D.new()
	runner_body.name = "Runner"
	staircase_root.add_child(runner_body)
	runner_body.global_position = route_points[0]

	runner_visual = Node3D.new()
	runner_visual.name = "RunnerVisual"
	runner_body.add_child(runner_visual)

	var mat_fpt_orange := StandardMaterial3D.new()
	mat_fpt_orange.albedo_color = Color("#F37021")
	mat_fpt_orange.roughness = 0.6
	var mat_white := StandardMaterial3D.new()
	mat_white.albedo_color = Color("#FFFFFF")
	var mat_pack := StandardMaterial3D.new()
	mat_pack.albedo_color = Color("#1E272E")
	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = Color("#FFCCAA")
	var mat_hair := StandardMaterial3D.new()
	mat_hair.albedo_color = Color("#1E1E1E")
	var mat_jeans := StandardMaterial3D.new()
	mat_jeans.albedo_color = Color("#2C3A47")

	var torso := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.48, 0.58, 0.28)
	torso.mesh = tm
	torso.material_override = mat_fpt_orange
	torso.position = Vector3(0.0, 1.05, 0.0)
	runner_visual.add_child(torso)

	var collar := MeshInstance3D.new()
	var clm := BoxMesh.new()
	clm.size = Vector3(0.32, 0.08, 0.3)
	collar.mesh = clm
	collar.material_override = mat_white
	collar.position = Vector3(0.0, 1.35, 0.0)
	runner_visual.add_child(collar)

	var lanyard := MeshInstance3D.new()
	var lnm := BoxMesh.new()
	lnm.size = Vector3(0.12, 0.16, 0.02)
	lanyard.mesh = lnm
	lanyard.material_override = mat_white
	lanyard.position = Vector3(0.0, 1.0, -0.16)
	runner_visual.add_child(lanyard)

	var backpack := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.38, 0.48, 0.22)
	backpack.mesh = bm
	backpack.material_override = mat_pack
	backpack.position = Vector3(0.0, 1.05, 0.22)
	runner_visual.add_child(backpack)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.32
	head.mesh = hm
	head.material_override = mat_skin
	head.position = Vector3(0.0, 1.55, 0.0)
	runner_visual.add_child(head)

	var hair := MeshInstance3D.new()
	var hrm := BoxMesh.new()
	hrm.size = Vector3(0.34, 0.14, 0.34)
	hair.mesh = hrm
	hair.material_override = mat_hair
	hair.position = Vector3(0.0, 1.68, 0.0)
	runner_visual.add_child(hair)

	for side: float in [-1.0, 1.0]:
		var arm_pivot := Node3D.new()
		arm_pivot.position = Vector3(side * 0.28, 1.30, 0.0)
		runner_visual.add_child(arm_pivot)
		if side < 0.0:
			runner_left_arm = arm_pivot
		else:
			runner_right_arm = arm_pivot
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.07
		am.height = 0.48
		arm.mesh = am
		arm.material_override = mat_fpt_orange
		arm.position = Vector3(0.0, -0.22, 0.0)
		arm_pivot.add_child(arm)

	for side: float in [-1.0, 1.0]:
		var leg_pivot := Node3D.new()
		leg_pivot.position = Vector3(side * 0.14, 0.72, 0.0)
		runner_visual.add_child(leg_pivot)
		if side < 0.0:
			runner_left_leg = leg_pivot
		else:
			runner_right_leg = leg_pivot
		var leg := MeshInstance3D.new()
		var lm := CapsuleMesh.new()
		lm.radius = 0.09
		lm.height = 0.60
		leg.mesh = lm
		leg.material_override = mat_jeans
		leg.position = Vector3(0.0, -0.28, 0.0)
		leg_pivot.add_child(leg)
		var shoe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.14, 0.12, 0.26)
		shoe.mesh = sm
		shoe.material_override = mat_white
		shoe.position = Vector3(0.0, -0.58, -0.05)
		leg_pivot.add_child(shoe)

func _setup_run_camera() -> void:
	run_cam = Camera3D.new()
	run_cam.fov = 72.0
	run_cam.top_level = true
	staircase_root.add_child(run_cam)
	var fr: Dictionary = _path_frame(0.0)
	var fwd: Vector3 = fr["fwd"]
	run_cam.global_position = runner_body.global_position - fwd * 4.8 + Vector3(0.0, 2.4, 0.0)
	run_cam.look_at(runner_body.global_position + Vector3(0.0, 1.0, 0.0) + fwd * 2.5, Vector3.UP)
	run_cam.current = true

func _path_frame(progress: float) -> Dictionary:
	var p: float = clampf(progress, 0.0, run_length)
	var base: Vector3 = run_curve.sample_baked(p)
	var ahead: Vector3 = run_curve.sample_baked(minf(p + 0.8, run_length))
	var behind: Vector3 = run_curve.sample_baked(maxf(p - 0.8, 0.0))
	var fwd: Vector3 = ahead - behind
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	return {"pos": base, "fwd": fwd, "right": right}

func _spawn_obstacles() -> void:
	# [tỉ lệ quãng đường, làn, loại] – mật độ tăng dần; đoạn cầu thang cuối chỉ có người & băng rôn
	var spec: Array = [
		[0.045, [0], "npc"],
		[0.08, [1], "teacher"],
		[0.11, [-1, 0], "cart"],
		[0.16, [-1], "npc"],
		[0.19, [-1, 0, 1], "banner"],
		[0.24, [-1, 0, 1], "puddle"],
		[0.28, [0], "npc"],
		[0.32, [0, 1], "cart"],
		[0.355, [-1], "teacher"],
		[0.405, [1], "npc"],
		[0.44, [-1, 0, 1], "banner"],
		[0.49, [-1, 0, 1], "puddle"],
		[0.535, [0], "npc"],
		[0.575, [-1], "npc"],
		[0.615, [-1, 0], "cart"],
		[0.655, [1], "teacher"],
		[0.69, [-1, 0, 1], "banner"],
		[0.745, [0], "npc"],
		[0.78, [-1, 0, 1], "puddle"],
		[0.82, [0, 1], "cart"],
		[0.86, [-1], "npc"],
		[0.9, [-1, 0, 1], "banner"],
		[0.935, [1], "teacher"],
		[0.965, [0], "npc"]
	]
	obstacles.clear()
	for item: Array in spec:
		var prog: float = clampf(float(item[0]) * run_length, 5.0, run_length - 3.0)
		var lanes: Array = item[1]
		var type: String = item[2]
		var node: Node3D = _make_obstacle_node(type, lanes)
		staircase_root.add_child(node)
		var ob: Dictionary = {
			"type": type, "progress": prog, "lanes": lanes, "node": node,
			"hit": false, "dodged": false, "active": type != "npc",
			"low": type in ["cart", "puddle"], "high": type == "banner",
			"half_len": 0.9 if type in ["cart", "puddle"] else 0.65
		}
		if type == "npc":
			node.visible = false
		_place_obstacle(ob)
		obstacles.append(ob)

func _lanes_center(lanes: Array) -> float:
	var s: float = 0.0
	for l: int in lanes:
		s += float(l)
	return (s / float(lanes.size())) * LANE_OFFSET

func _place_obstacle(ob: Dictionary) -> void:
	var fr: Dictionary = _path_frame(ob["progress"])
	var node: Node3D = ob["node"]
	node.global_position = fr["pos"] + fr["right"] * _lanes_center(ob["lanes"])
	var fwd: Vector3 = fr["fwd"]
	var face_dir: Vector3 = -fwd if ob["type"] in ["npc"] else fwd
	node.rotation.y = atan2(-face_dir.x, -face_dir.z)

func _make_obstacle_node(type: String, lanes: Array) -> Node3D:
	var root := Node3D.new()
	match type:
		"npc", "teacher":
			var is_teacher: bool = type == "teacher"
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#34495E") if is_teacher else Color("#F37021")
			var body := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.26
			cm.height = 1.25
			body.mesh = cm
			body.material_override = mat
			body.position = Vector3(0.0, 0.95, 0.0)
			root.add_child(body)
			var head := MeshInstance3D.new()
			var hm := SphereMesh.new()
			hm.radius = 0.17
			hm.height = 0.34
			head.mesh = hm
			var ms := StandardMaterial3D.new()
			ms.albedo_color = Color("#FFCCAA")
			head.material_override = ms
			head.position = Vector3(0.0, 1.75, 0.0)
			root.add_child(head)
			if is_teacher:
				var book := MeshInstance3D.new()
				var bkm := BoxMesh.new()
				bkm.size = Vector3(0.3, 0.4, 0.05)
				book.mesh = bkm
				var mb := StandardMaterial3D.new()
				mb.albedo_color = Color("#E67E22")
				book.material_override = mb
				book.position = Vector3(0.25, 1.1, -0.25)
				root.add_child(book)
			var lbl := Label3D.new()
			lbl.text = "📚 Cô đi chậm..." if is_teacher else "🏃 Ê né ra!!"
			lbl.font_size = 22
			lbl.outline_size = 8
			lbl.modulate = Color("#FFFFFF")
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0.0, 2.3, 0.0)
			root.add_child(lbl)
		"cart":
			var w: float = LANE_OFFSET * float(lanes.size()) - 0.2
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#F1C40F")
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(w, 0.85, 1.0)
			box.mesh = bm
			box.material_override = mat
			box.position = Vector3(0.0, 0.55, 0.0)
			root.add_child(box)
			var mat_w := StandardMaterial3D.new()
			mat_w.albedo_color = Color("#2C3E50")
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var wh := MeshInstance3D.new()
					var wm := CylinderMesh.new()
					wm.top_radius = 0.12
					wm.bottom_radius = 0.12
					wm.height = 0.08
					wh.mesh = wm
					wh.material_override = mat_w
					wh.rotation_degrees = Vector3(0, 0, 90)
					wh.position = Vector3(sx * (w * 0.45), 0.12, sz * 0.4)
					root.add_child(wh)
			var mop := MeshInstance3D.new()
			var mm := CylinderMesh.new()
			mm.top_radius = 0.03
			mm.bottom_radius = 0.03
			mm.height = 1.6
			mop.mesh = mm
			mop.position = Vector3(w * 0.3, 1.2, 0.0)
			mop.rotation_degrees = Vector3(0, 0, 12)
			root.add_child(mop)
			var lbl := Label3D.new()
			lbl.text = "🧹 XE DỌN VỆ SINH – NHẢY QUA!"
			lbl.font_size = 20
			lbl.outline_size = 8
			lbl.modulate = Color("#F1C40F")
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0.0, 1.8, 0.0)
			root.add_child(lbl)
		"banner":
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("#8E44AD")
			var cloth := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(5.6, 0.55, 0.06)
			cloth.mesh = cm
			cloth.material_override = mat
			cloth.position = Vector3(0.0, 1.15, 0.0)
			root.add_child(cloth)
			var mat_pole := StandardMaterial3D.new()
			mat_pole.albedo_color = Color("#7F8C8D")
			for sx: float in [-1.0, 1.0]:
				var pole := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.05
				pm.bottom_radius = 0.05
				pm.height = 2.2
				pole.mesh = pm
				pole.material_override = mat_pole
				pole.position = Vector3(sx * 2.9, 1.1, 0.0)
				root.add_child(pole)
			var lbl := Label3D.new()
			lbl.text = "CLB F-CODE TUYỂN THÀNH VIÊN – TRƯỢT [S] DƯỚI BĂNG RÔN!"
			lbl.font_size = 18
			lbl.outline_size = 7
			lbl.modulate = Color("#FFFFFF")
			lbl.position = Vector3(0.0, 1.15, 0.05)
			root.add_child(lbl)
			var lbl2 := lbl.duplicate() as Label3D
			lbl2.rotation_degrees.y = 180.0
			lbl2.position.z = -0.05
			root.add_child(lbl2)
		"puddle":
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.6, 0.95, 0.55)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.05
			mat.metallic = 0.5
			var water := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 2.4
			wm.bottom_radius = 2.4
			wm.height = 0.04
			water.mesh = wm
			water.material_override = mat
			water.position = Vector3(0.0, 0.03, 0.0)
			root.add_child(water)
			var sign := MeshInstance3D.new()
			var sm := PrismMesh.new()
			sm.size = Vector3(0.5, 0.7, 0.4)
			sign.mesh = sm
			var ms := StandardMaterial3D.new()
			ms.albedo_color = Color("#F1C40F")
			sign.material_override = ms
			sign.position = Vector3(2.6, 0.35, 0.0)
			root.add_child(sign)
			var lbl := Label3D.new()
			lbl.text = "⚠️ SÀN ƯỚT – NHẢY QUA!"
			lbl.font_size = 18
			lbl.outline_size = 7
			lbl.modulate = Color("#F1C40F")
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(2.6, 1.1, 0.0)
			root.add_child(lbl)
	return root

func _process_phase_2(delta: float) -> void:
	if not runner_body or is_stage_ended:
		return

	# --- Thể lực & trạng thái ---
	if stumble_timer > 0.0:
		stumble_timer -= delta
	if exhausted_timer > 0.0:
		exhausted_timer -= delta
		heart_sfx_timer -= delta
		if heart_sfx_timer <= 0.0:
			heart_sfx_timer = 0.5
			GameFX.play_sfx("heart", -2.0)
		if exhausted_timer <= 0.0:
			GameFX.clear_vignette()
			stamina = maxf(stamina, 28.0)
	free_sprint_timer = maxf(0.0, free_sprint_timer - delta)

	var sprint_held: bool = Input.is_key_pressed(KEY_SHIFT)
	var sprinting: bool = false
	if sprint_held and stumble_timer <= 0.0 and exhausted_timer <= 0.0 and (stamina > 0.0 or free_sprint_timer > 0.0):
		sprinting = true
		if free_sprint_timer <= 0.0:
			stamina -= 24.0 * delta
			if stamina <= 0.0:
				stamina = 0.0
				_trigger_exhausted()
				sprinting = false
	else:
		stamina = minf(100.0, stamina + 9.0 * delta)
	stamina_bar.value = stamina
	GameFX.set_bar_color(stamina_bar, GameFX.FPT_GREEN if stamina > 40.0 else (GameFX.FPT_YELLOW if stamina > 15.0 else GameFX.FPT_RED))

	# --- Tốc độ chạy theo tuyến ---
	var target_speed: float = SPRINT_SPEED if sprinting else RUN_SPEED
	if exhausted_timer > 0.0:
		target_speed *= 0.5
	if stumble_timer > 0.0:
		target_speed = 0.0
	run_speed_cur = move_toward(run_speed_cur, target_speed, delta * (14.0 if target_speed > run_speed_cur else 30.0))
	run_progress = minf(run_progress + run_speed_cur * delta, run_length)

	if jump_t >= 0.0:
		jump_t += delta / JUMP_DURATION
		if jump_t >= 1.0:
			jump_t = -1.0
	if slide_t >= 0.0:
		slide_t += delta / SLIDE_DURATION
		if slide_t >= 1.0:
			slide_t = -1.0

	_update_runner_transform(delta, sprinting)
	_update_obstacles(delta)
	_update_checkpoints()
	_update_run_camera(delta)

	run_progress_bar.value = run_progress / run_length * 100.0

	if run_progress >= run_length - 0.4:
		_complete_stage()

func _trigger_exhausted() -> void:
	exhausted_timer = 2.5
	heart_sfx_timer = 0.0
	GameFX.set_vignette(0.85, Color(0.9, 0.08, 0.08), 2.0)
	GameFX.popup("😮‍💨 HỤT HƠI! CHẠY CHẬM LẠI 2.5s... (Monster: [Q])", GameFX.FPT_RED, 28, 1.6)
	GameFX.shake(0.3)

func _try_drink_monster() -> void:
	if StageManager.consume_item("monster"):
		stamina = 100.0
		exhausted_timer = 0.0
		free_sprint_timer = 3.0
		GameFX.clear_vignette()
		GameFX.play_sfx("cash")
		GameFX.flash(GameFX.FPT_GREEN, 0.3, 0.3)
		GameFX.popup("⚡ MONSTER! +100% THỂ LỰC, 3s SPRINT MIỄN PHÍ!", GameFX.FPT_GREEN, 30, 1.4)
		_refresh_monster_label()
	else:
		GameFX.play_sfx("error", -6.0)
		GameFX.popup("KHÔNG CÓ MONSTER! (Lần sau ghé máy bán nước sau toà nhà / 7-Eleven Màn 5)", Color("#BDC3C7"), 22, 1.2)

func _update_runner_transform(delta: float, sprinting: bool) -> void:
	var fr: Dictionary = _path_frame(run_progress)
	lane_x = lerpf(lane_x, float(lane) * LANE_OFFSET, delta * 10.0)
	var jump_h: float = 0.0
	if jump_t >= 0.0:
		jump_h = 1.15 * sin(PI * clampf(jump_t, 0.0, 1.0))
	runner_body.global_position = fr["pos"] + fr["right"] * lane_x + Vector3(0.0, jump_h, 0.0)
	var fwd: Vector3 = fr["fwd"]
	var target_yaw: float = atan2(-fwd.x, -fwd.z)
	runner_body.rotation.y = lerp_angle(runner_body.rotation.y, target_yaw, delta * 10.0)

	# Dáng người: trượt / vấp / chạy
	var target_rot_x: float = 0.0
	var target_y: float = 0.0
	if slide_t >= 0.0:
		target_rot_x = -1.15
		target_y = -0.45
	elif stumble_timer > 0.35:
		target_rot_x = 0.95
		target_y = -0.3
	runner_visual.rotation.x = lerpf(runner_visual.rotation.x, target_rot_x, delta * 14.0)
	runner_visual.rotation.z = lerpf(runner_visual.rotation.z, -(float(lane) * LANE_OFFSET - lane_x) * 0.35, delta * 10.0)

	var moving: bool = run_speed_cur > 0.5 and jump_t < 0.0 and slide_t < 0.0
	if moving:
		var stride_freq: float = 18.0 if sprinting else 11.0
		var leg_swing: float = sin(Time.get_ticks_msec() * 0.001 * stride_freq) * (0.7 if sprinting else 0.45)
		runner_left_leg.rotation.x = leg_swing
		runner_right_leg.rotation.x = -leg_swing
		runner_left_arm.rotation.x = -leg_swing * 0.85
		runner_right_arm.rotation.x = leg_swing * 0.85
		runner_visual.position.y = lerpf(runner_visual.position.y, target_y + absf(sin(Time.get_ticks_msec() * 0.001 * stride_freq)) * 0.06, delta * 12.0)
	else:
		var tuck: float = 1.3 if jump_t >= 0.0 else 0.0
		runner_left_leg.rotation.x = lerpf(runner_left_leg.rotation.x, tuck, delta * 12.0)
		runner_right_leg.rotation.x = lerpf(runner_right_leg.rotation.x, tuck * 0.6, delta * 12.0)
		runner_left_arm.rotation.x = lerpf(runner_left_arm.rotation.x, -tuck * 1.5, delta * 12.0)
		runner_right_arm.rotation.x = lerpf(runner_right_arm.rotation.x, -tuck * 1.5, delta * 12.0)
		runner_visual.position.y = lerpf(runner_visual.position.y, target_y, delta * 10.0)

func _update_obstacles(delta: float) -> void:
	for ob: Dictionary in obstacles:
		if ob["hit"]:
			continue
		var node: Node3D = ob["node"]
		match ob["type"]:
			"npc":
				if not ob["active"]:
					if ob["progress"] - run_progress < 30.0:
						ob["active"] = true
						node.visible = true
				else:
					ob["progress"] -= 3.2 * delta
					_place_obstacle(ob)
					if ob["progress"] < run_progress - 4.0:
						ob["hit"] = true
						node.queue_free()
						continue
			"teacher":
				ob["progress"] = minf(ob["progress"] + 1.1 * delta, run_length - 2.0)
				_place_obstacle(ob)

		var dp: float = ob["progress"] - run_progress
		if absf(dp) < float(ob["half_len"]) and (lane in ob["lanes"]):
			var safe: bool = false
			if ob["low"] and jump_t >= 0.08 and jump_t < 0.95:
				safe = true
			elif ob["high"] and slide_t >= 0.05 and slide_t < 0.95:
				safe = true
			if safe:
				if not ob["dodged"]:
					ob["dodged"] = true
					dodges += 1
					GameFX.popup("NÉ ĐẸP! +20", GameFX.FPT_YELLOW, 24, 0.5)
					GameFX.play_sfx("pop", -6.0, 1.3)
				continue
			_stumble(ob)

func _stumble(ob: Dictionary) -> void:
	ob["hit"] = true
	stumbles += 1
	var type: String = ob["type"]
	var is_slip: bool = type == "puddle"
	stumble_timer = 0.75 if is_slip else 1.1
	run_speed_cur = 0.0
	jump_t = -1.0
	slide_t = -1.0
	stamina = maxf(0.0, stamina - 15.0)
	GameFX.shake(0.55)
	GameFX.flash(GameFX.FPT_RED, 0.3, 0.3)
	GameFX.play_sfx("thud")
	var msg: String
	match type:
		"npc": msg = "VẤP SINH VIÊN! 'Ủa đi đứng kiểu gì vậy?!'"
		"teacher": msg = "ĐỤNG CÔ! 'Em chạy đâu mà dữ vậy?!' -15 thể lực"
		"cart": msg = "ĐÂM XE ĐẨY! Xô chậu đổ hết..."
		"banner": msg = "DÍNH BĂNG RÔN! Quấn cổ luôn rồi!"
		_: msg = "TRƯỢT SÀN ƯỚT! 'Đã bảo có biển rồi mà!'"
	GameFX.popup(msg, GameFX.FPT_RED, 24, 1.1)
	GameFX.float_text(self, runner_body.global_position + Vector3(0, 2.2, 0), "VẤP!" if not is_slip else "TRƯỢT!", GameFX.FPT_RED, 48)
	var node: Node3D = ob["node"]
	if type in ["npc", "teacher"] and is_instance_valid(node):
		var tw := create_tween()
		tw.tween_property(node, "position", node.position + node.global_transform.basis.x * 2.5, 0.5)
		tw.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
		tw.tween_callback(node.queue_free)

func _update_checkpoints() -> void:
	for cp: Dictionary in checkpoints:
		if cp["done"]:
			continue
		if run_progress >= float(cp["progress"]):
			cp["done"] = true
			GameFX.play_sfx("res://assets/audio/checkpoint_bell.wav", -2.0)
			GameFX.popup(cp["text"], GameFX.FPT_YELLOW, 28, 1.5)
			GameFX.float_text(self, runner_body.global_position + Vector3(0, 2.4, 0), "✓", GameFX.FPT_GREEN, 56)

func _update_run_camera(delta: float) -> void:
	if not run_cam or not runner_body:
		return
	var fr: Dictionary = _path_frame(run_progress)
	var fwd: Vector3 = fr["fwd"]
	var rp: Vector3 = runner_body.global_position
	var desired: Vector3 = rp - fwd * 4.8 + Vector3(0.0, 2.4, 0.0)
	run_cam.global_position = run_cam.global_position.lerp(desired, delta * 6.0)
	var look_target: Vector3 = rp + Vector3(0.0, 1.0, 0.0) + fwd * 2.5
	if run_cam.global_position.distance_squared_to(look_target) > 0.01:
		run_cam.look_at(look_target, Vector3.UP)
	var target_fov: float = 72.0 + (run_speed_cur / SPRINT_SPEED) * 10.0
	run_cam.fov = lerpf(run_cam.fov, target_fov, delta * 4.0)

# ===========================================================================
# KẾT THÚC MÀN
# ===========================================================================
func _complete_stage() -> void:
	if is_stage_ended:
		return
	is_stage_ended = true
	has_won = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameFX.clear_vignette()
	GameFX.play_sfx("res://assets/audio/victory_fanfare.wav", 2.0)
	GameFX.flash(GameFX.FPT_GREEN, 0.4, 0.5)

	var park_score: int = maxi(0, 350 - park_retries * 60 - (50 if spot_stolen else 0)) + int(park_time_left * 5.0)
	var run_score: int = int(maxf(0.0, time_left) * 22.0) + maxi(0, 300 - stumbles * 70) + dodges * 20
	var score: int = park_score + run_score
	var rank: String = GameFX.rank_for(float(score), 1050.0, 800.0, 500.0)
	StageManager.report_stage_result(StageManager.StageID.STAGE_2_PARKING, {
		"result": "win", "score": score, "rank": rank,
		"detail": "park=%d run=%d stumbles=%d dodges=%d" % [park_score, run_score, stumbles, dodges]
	})

	modal_title.text = "🎉 LÊN TỚI LAB 402 SAU 105 BẬC THANG! RANK %s" % rank
	modal_title.modulate = Color("#2ECC71")
	modal_sub.text = "Gửi xe xong (%s), chạy bộ %d m xuyên campus – bãi xe, sân trong, sảnh, cầu thang ngoài trời:\n%d lần vấp · %d pha né đẹp · còn dư %ds. Vào Lab 402 lúc 07:29!\nĐiểm: %d (đỗ xe %d + chạy bộ %d)" % [
		("bị cướp ô, đỗ ô dự phòng" if spot_stolen else "ô gần nhất"), int(run_length), stumbles, dodges, int(maxf(0.0, time_left)), score, park_score, run_score
	]
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)
	emit_signal("stage_completed")

func _fail_stage(reason: String) -> void:
	if is_stage_ended:
		return
	is_stage_ended = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameFX.clear_vignette()
	GameFX.play_sfx("res://assets/audio/absent_gameover.wav", 2.0)
	if player_bike:
		player_bike.set("is_controls_locked", true)
	StageManager.report_stage_result(StageManager.StageID.STAGE_2_PARKING, {"result": "fail", "score": 0, "rank": "C", "detail": reason})
	modal_title.text = "❌ THẤT BẠI - BỊ ĐÁNH ABSENT!"
	modal_title.modulate = Color("#E74C3C")
	var progress_txt: String = ""
	if is_phase_2:
		progress_txt = "\nBạn đã chạy được %d%% quãng đường – thiếu chút nữa thôi!" % int(run_progress / run_length * 100.0)
	modal_sub.text = reason + progress_txt
	next_btn.visible = false
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _on_next_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StageManager.change_stage(StageManager.StageID.STAGE_3_CLASSROOM)

func _on_menu_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StageManager.open_stage_select()

func _on_retry_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()
