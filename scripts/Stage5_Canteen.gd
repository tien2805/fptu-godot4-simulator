# File: res://scripts/Stage5_Canteen.gd
# MÀN 5: CĂN TIN ĐẠI CHIẾN & 7-ELEVEN
#   Pha 1 (60s) – Bưng khay kiểu Overcooked: lấy khay ở quầy [E], luồn qua biển người áo cam đi cắt ngang
#            tới bàn bạn đang vẫy, giao [E]. Va NPC -> khay nghiêng; đứng yên giữ [SPACE] để cân lại;
#            nghiêng tới mép = đổ cơm, quay lại quầy lấy khay mới. Giao 2 đơn (đơn 2 đông hơn).
#   Pha 2 (35s) – 7-Eleven combo puzzle: KÉO THẢ (hoặc double-click) món vào giỏ trong ngân sách
#            ngẫu nhiên 30k/40k/50k, đạt Năng lượng ≥60 & Tinh thần ≥40. Monster/cà phê/bánh bao mua
#            được lưu vào inventory dùng ở màn khác.
class_name Stage5_Canteen
extends Node3D

@onready var mission_label: Label = $HUD/MissionPanel/MissionLabel
@onready var balance_panel: PanelContainer = $HUD/BalancePanel
@onready var balance_vbox: VBoxContainer = $HUD/BalancePanel/VBox
@onready var balance_title: Label = $HUD/BalancePanel/VBox/Label
@onready var balance_bar: ProgressBar = $HUD/BalancePanel/VBox/BalanceBar
@onready var balance_hbox: HBoxContainer = $HUD/BalancePanel/VBox/HBox

@onready var shop_panel: PanelContainer = $HUD/CenterModals/SevenElevenModal
@onready var shop_vbox: VBoxContainer = $HUD/CenterModals/SevenElevenModal/Margin/VBox
@onready var shop_title: Label = $HUD/CenterModals/SevenElevenModal/Margin/VBox/Title
@onready var buy_noodles_btn: Button = $HUD/CenterModals/SevenElevenModal/Margin/VBox/BuyNoodlesButton
@onready var buy_drink_btn: Button = $HUD/CenterModals/SevenElevenModal/Margin/VBox/BuyDrinkButton
@onready var finish_shop_btn: Button = $HUD/CenterModals/SevenElevenModal/Margin/VBox/FinishButton

@onready var modal_overlay: ColorRect = $HUD/ModalOverlay
@onready var modal_title: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/TitleLabel
@onready var modal_sub: Label = $HUD/ModalOverlay/Center/Card/Margin/VBox/SubLabel
@onready var next_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/NextButton
@onready var menu_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/MenuButton
@onready var retry_btn: Button = $HUD/ModalOverlay/Center/Card/Margin/VBox/RetryButton

@onready var se_sign_mesh: MeshInstance3D = $CanteenHall/SevenElevenSign
@onready var hall: Node3D = $CanteenHall
@onready var camera: Camera3D = $Camera3D
@onready var hud: CanvasLayer = $HUD

enum Phase { SERVE, TO_SHOP, SHOP, DONE }

const SERVE_TIME: float = 60.0
const SHOP_TIME: float = 35.0
const COUNTER_FRONT: Vector3 = Vector3(-8.0, 0.0, -5.6)
const SHOP_FRONT: Vector3 = Vector3(8.0, 0.0, -5.4)
const WALK_SPEED: float = 4.3
const WALK_SPEED_FREE: float = 5.4
const HALL_HALF: Vector2 = Vector2(14.5, 11.0)

const ORDERS: Array = [
	{"food": "🍛 CƠM TẤM SƯỜN TRỨNG", "table": Vector3(10.0, 0.0, 5.0), "friend": "Minh 'ăn chực'"},
	{"food": "🧋 TRÀ ĐÁ + MÌ XÀO BÒ", "table": Vector3(-10.0, 0.0, 5.0), "friend": "Hằng 'deadline'"}
]

# Giá được cân để: 30k có ĐÚNG 1 lời giải (mì + bánh bao + sting + trà), 40k thoải mái hơn,
# 50k mới đủ tiền Monster (18k) = phần thưởng mang sang màn khác.
const SHOP_ITEMS: Array = [
	{"id": "indomie", "name": "Mì trộn Indomie", "icon": "🍜", "price": 10, "energy": 30, "sanity": 0},
	{"id": "banh_bao", "name": "Bánh bao trứng cút", "icon": "🥟", "price": 8, "energy": 20, "sanity": 0},
	{"id": "xucxich", "name": "Xúc xích nướng", "icon": "🌭", "price": 5, "energy": 10, "sanity": 0},
	{"id": "monster", "name": "Monster Energy", "icon": "⚡", "price": 18, "energy": 0, "sanity": 40},
	{"id": "sting", "name": "Sting dâu", "icon": "🧃", "price": 7, "energy": 0, "sanity": 20},
	{"id": "tra", "name": "Trà xanh 0 độ", "icon": "🍵", "price": 5, "energy": 0, "sanity": 10},
	{"id": "coffee", "name": "Cà phê lon", "icon": "☕", "price": 10, "energy": -5, "sanity": 30},
	{"id": "keo", "name": "Kẹo cao su", "icon": "🍬", "price": 2, "energy": 4, "sanity": 0}
]
const TARGET_ENERGY: int = 50
const TARGET_SANITY: int = 30

var phase: int = Phase.SERVE
var time_left: float = SERVE_TIME
var is_stage_ended: bool = false

# Pha 1
var player: CharacterBody3D
var player_visual: Node3D
var tray_mesh: Node3D
var has_tray: bool = false
var tilt: float = 0.0
var drift_dir: float = 1.0
var drift_timer: float = 0.0
var order_idx: int = 0
var orders_done: int = 0
var spills: int = 0
var bumps: int = 0
var npcs: Array[Dictionary] = []
var friend_root: Node3D
var friend_label: Label3D
var friend_arm: Node3D
var prompt_label: Label
var prompt_panel: PanelContainer
var bump_cooldown: float = 0.0
var balance_hint: Label
var tray_shake: float = 0.0

# Pha 2
var budget: int = 40
var basket: Array[Dictionary] = []
var basket_list: VBoxContainer
var totals_label: Label
var pay_btn: Button
var shop_timer_bar: ProgressBar
var score_phase1: int = 0
# Điều khiển cửa hàng bằng bàn phím (Slay the Spire style): lưới 4x2, Enter thêm, Backspace bỏ, Tab sang giỏ, Space trả tiền
var shop_cards: Array[PanelContainer] = []
var shop_focus_idx: int = 0
var shop_focus_zone: int = 0 # 0 = kệ hàng, 1 = giỏ
var basket_focus_idx: int = 0
var basket_buttons: Array[Button] = []

class ShopCard extends PanelContainer:
	var item: Dictionary
	var stage: Node
	func _get_drag_data(_at: Vector2) -> Variant:
		var prev := Label.new()
		prev.text = "%s %s" % [item["icon"], item["name"]]
		prev.add_theme_font_size_override("font_size", 20)
		prev.add_theme_color_override("font_color", Color("#F1C40F"))
		set_drag_preview(prev)
		return item
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and ev.double_click:
			stage.call("add_to_basket", item)
			accept_event()

class BasketDrop extends PanelContainer:
	var stage: Node
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("price")
	func _drop_data(_at: Vector2, data: Variant) -> void:
		stage.call("add_to_basket", data)

func _ready() -> void:
	modal_overlay.visible = false
	shop_panel.visible = false
	balance_panel.visible = true

	_apply_7eleven_sign()
	_build_hall()
	_build_player()
	_build_npcs(14)
	_build_hud()
	_set_order(0)

	next_btn.pressed.connect(_on_next_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	for b: Button in [next_btn, menu_btn, retry_btn]:
		b.focus_mode = Control.FOCUS_NONE

	GameFX.upgrade_scene_visuals(self, "indoor")
	mission_label.text = "11:30 – GIỜ CƠM TRƯA! TỚI QUẦY CÔ CĂN TIN (BÊN TRÁI) BẤM [E] LẤY KHAY CƠM"
	_say("🍛 [WASD] DI CHUYỂN · [E] LẤY KHAY / GIAO BÀN · ĐỨNG YÊN GIỮ [SPACE] ĐỂ CÂN KHAY", GameFX.FPT_YELLOW)

# ===========================================================================
# 3D
# ===========================================================================
func _apply_7eleven_sign() -> void:
	var path: String = "res://assets/textures/seven_eleven_sign.png"
	if FileAccess.file_exists(path):
		var img: Image = GameFX.load_image_any(path)
		if img:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var qm := QuadMesh.new()
			qm.size = Vector2(6.0, 1.0)
			se_sign_mesh.mesh = qm
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.emission_enabled = true
			mat.emission_texture = tex
			mat.emission_energy_multiplier = 0.6
			se_sign_mesh.material_override = mat

func _build_hall() -> void:
	# Sàn có va chạm + tường bao
	var floor_body := StaticBody3D.new()
	var fc := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(34.0, 0.4, 28.0)
	fc.shape = fb
	floor_body.add_child(fc)
	floor_body.position = Vector3(0.0, -0.12, 0.0)
	hall.add_child(floor_body)

	# CAMPUS THẬT: căn tin = tầng trệt MỞ của cánh trước (module 3 + 4, trụ link giữa thành cột lớn),
	# hiên ăn ngoài trời trải ra sân trong; quầy cô Ba & 7-Eleven nằm sâu phía D1.
	var cmat: Dictionary = FPTUCampusBuilder.make_materials()
	var cc: Vector3 = FPTUCampusBuilder.canteen_center()
	var world := Node3D.new()
	world.name = "CampusWorld"
	world.position = -cc
	hall.add_child(world)
	FPTUCampusBuilder.build_authentic_campus(world, Vector3.ZERO, 0.0, {
		"colliders": true,
		"open_front_modules": [3, 4],
		"no_grass_rects": [Rect2(cc.x - 15.5, 34.0, 31.0, 13.0)]
	})
	FPTUCampusBuilder.build_hutech(world, Vector3(135.0, 0.0, -26.0), cmat)
	FPTUCampusBuilder.build_d1_road_piece(world, -13.0, -80.0, 300.0, cmat, 0.0)
	$DirectionalLight3D.rotation_degrees = Vector3(-58.0, 20.0, 0.0)
	# Hiên ăn lát gạch + bồn cây viền + cây xanh
	var slab := MeshInstance3D.new()
	var slm := BoxMesh.new()
	slm.size = Vector3(30.0, 0.03, 10.4)
	slab.mesh = slm
	slab.material_override = cmat["terrazzo"]
	slab.position = Vector3(0.0, 0.075, 7.1)
	hall.add_child(slab)
	for edge: Array in [[Vector3(-15.2, 0.3, 7.1), Vector3(0.6, 0.6, 10.4)], [Vector3(15.2, 0.3, 7.1), Vector3(0.6, 0.6, 10.4)], [Vector3(0.0, 0.3, 12.5), Vector3(31.0, 0.6, 0.6)]]:
		var planter := MeshInstance3D.new()
		var plm := BoxMesh.new()
		plm.size = edge[1]
		planter.mesh = plm
		planter.material_override = cmat["terracotta"]
		planter.position = edge[0]
		hall.add_child(planter)
		var bush := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(edge[1].x - 0.1, 0.5, edge[1].z - 0.1)
		bush.mesh = bm
		bush.material_override = cmat["leaf"]
		bush.position = edge[0] + Vector3(0.0, 0.5, 0.0)
		hall.add_child(bush)
	for csg_name: String in ["FoodCounter", "SevenElevenStore", "Table1", "Table2"]:
		var csg: CSGBox3D = hall.get_node_or_null(csg_name)
		if csg:
			csg.use_collision = true
	# QUẦY CƠM CÔ BA: mặt inox, kính chắn, khay thức ăn, nồi cơm, bảng menu cam
	var counter: CSGBox3D = hall.get_node("FoodCounter")
	var mat_inox := StandardMaterial3D.new()
	mat_inox.albedo_color = Color("#C8CDD1")
	mat_inox.metallic = 0.8
	mat_inox.roughness = 0.3
	counter.material = mat_inox
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(10.0, 0.6, 0.04)
	guard.mesh = gm
	guard.material_override = cmat["glass"]
	guard.position = Vector3(-8.0, 1.45, -6.8)
	hall.add_child(guard)
	var tray_cols: Array = [Color("#F7F3E8"), Color("#8E4B2A"), Color("#3E8E41"), Color("#5B3A29"), Color("#E9B44C"), Color("#D35400")]
	for i: int in range(6):
		var tray := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(1.3, 0.12, 0.7)
		tray.mesh = tm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = tray_cols[i]
		tray.material_override = mt
		tray.position = Vector3(-12.2 + i * 1.6, 1.06, -7.6)
		hall.add_child(tray)
	var cooker := MeshInstance3D.new()
	var ckm := CylinderMesh.new()
	ckm.top_radius = 0.35
	ckm.bottom_radius = 0.35
	ckm.height = 0.5
	cooker.mesh = ckm
	cooker.material_override = mat_inox
	cooker.position = Vector3(-12.3, 1.25, -8.6)
	hall.add_child(cooker)
	var menu := MeshInstance3D.new()
	var mnm := BoxMesh.new()
	mnm.size = Vector3(6.0, 1.0, 0.08)
	menu.mesh = mnm
	menu.material_override = cmat["orange"]
	menu.position = Vector3(-8.0, 2.85, -9.2)
	hall.add_child(menu)
	# 7-ELEVEN: hộp trắng viền sọc cam/xanh/đỏ, mặt kính, kệ hàng đầy đồ
	var store: CSGBox3D = hall.get_node("SevenElevenStore")
	var mat_store := StandardMaterial3D.new()
	mat_store.albedo_color = Color("#F4F6F7")
	store.material = mat_store
	var stripe_cols: Array = [Color("#F37021"), Color("#2ECC71"), Color("#E74C3C")]
	for i: int in range(3):
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(10.0, 0.14, 0.06)
		stripe.mesh = sm
		var ms := StandardMaterial3D.new()
		ms.albedo_color = stripe_cols[i]
		stripe.material_override = ms
		stripe.position = Vector3(8.0, 2.4 - i * 0.16, -6.44)
		hall.add_child(stripe)
	var front := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(9.6, 2.1, 0.05)
	front.mesh = fm
	front.material_override = cmat["glass"]
	front.position = Vector3(8.0, 1.15, -6.5)
	hall.add_child(front)
	var prod_cols: Array = [Color("#E74C3C"), Color("#3498DB"), Color("#F1C40F"), Color("#2ECC71"), Color("#9B59B6"), Color("#E67E22")]
	for k: int in range(3):
		var shelf := MeshInstance3D.new()
		var shm := BoxMesh.new()
		shm.size = Vector3(9.0, 0.04, 0.7)
		shelf.mesh = shm
		shelf.material_override = cmat["white"]
		shelf.position = Vector3(8.0, 0.55 + k * 0.7, -7.1)
		hall.add_child(shelf)
		for j: int in range(14):
			var prod := MeshInstance3D.new()
			var pdm := BoxMesh.new()
			pdm.size = Vector3(0.42, 0.34, 0.3)
			prod.mesh = pdm
			var mp := StandardMaterial3D.new()
			mp.albedo_color = prod_cols[(j + k) % prod_cols.size()]
			prod.material_override = mp
			prod.position = Vector3(3.8 + j * 0.64, 0.76 + k * 0.7, -7.1)
			hall.add_child(prod)
	var fridge := MeshInstance3D.new()
	var frm := BoxMesh.new()
	frm.size = Vector3(1.2, 2.0, 0.7)
	fridge.mesh = frm
	fridge.material_override = cmat["glass"]
	fridge.position = Vector3(12.3, 1.0, -7.1)
	hall.add_child(fridge)

	# Thêm bàn ăn thành lưới + ghế
	var mat_table := StandardMaterial3D.new()
	mat_table.albedo_color = Color(0.55, 0.38, 0.25)
	var positions: Array[Vector3] = [Vector3(-10, 0, 0), Vector3(10, 0, 0), Vector3(-10, 0, 5), Vector3(-4, 0, 5), Vector3(4, 0, 5), Vector3(10, 0, 5), Vector3(-4, 0, 10), Vector3(4, 0, 10)]
	for p: Vector3 in positions:
		var t := CSGBox3D.new()
		t.size = Vector3(3.0, 1.0, 1.6)
		t.material_override = mat_table
		t.use_collision = true
		t.position = p + Vector3(0.0, 0.6, 0.0)
		hall.add_child(t)
	# Ghế đẩu quanh mọi bàn + dù cam che nắng cho bàn ngoài hiên
	var mat_stool := StandardMaterial3D.new()
	mat_stool.albedo_color = Color("#1F5FA8")
	var mat_umb := StandardMaterial3D.new()
	mat_umb.albedo_color = Color("#F37021")
	var all_tables: Array = positions.duplicate()
	all_tables.append(Vector3(-4.0, 0.0, -1.5))
	all_tables.append(Vector3(4.0, 0.0, -1.5))
	for p: Vector3 in all_tables:
		for off: Vector3 in [Vector3(-0.9, 0.0, 1.25), Vector3(0.9, 0.0, 1.25), Vector3(-0.9, 0.0, -1.25), Vector3(0.9, 0.0, -1.25)]:
			var st := MeshInstance3D.new()
			var stm := CylinderMesh.new()
			stm.top_radius = 0.2
			stm.bottom_radius = 0.17
			stm.height = 0.45
			st.mesh = stm
			st.material_override = mat_stool
			st.position = p + off + Vector3(0.0, 0.225, 0.0)
			hall.add_child(st)
		if p.z >= 4.0:
			var pole := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.03
			pm.bottom_radius = 0.03
			pm.height = 2.6
			pole.mesh = pm
			pole.material_override = cmat["steel"]
			pole.position = p + Vector3(0.0, 1.3, 0.0)
			hall.add_child(pole)
			var umb := MeshInstance3D.new()
			var um := CylinderMesh.new()
			um.top_radius = 0.0
			um.bottom_radius = 1.7
			um.height = 0.5
			um.radial_segments = 8
			umb.mesh = um
			umb.material_override = mat_umb
			umb.position = p + Vector3(0.0, 2.55, 0.0)
			hall.add_child(umb)
	# Quầy cô căn tin: biển + cô bán hàng
	var lbl := Label3D.new()
	lbl.text = "🍚 QUẦY CƠM CÔ BA – CƠM TẤM 35K · MÌ XÀO 30K\n[E] LẤY KHAY"
	lbl.font_size = 34
	lbl.outline_size = 10
	lbl.modulate = Color("#F1C40F")
	lbl.position = Vector3(-8.0, 2.9, -6.6)
	hall.add_child(lbl)
	# Cô Ba đứng sau quầy (CharacterBuilder: áo bếp, tạp dề, mũ bếp, bưng khay) – quay mặt ra sảnh (+Z)
	var cook: Node3D = CharacterBuilder.build({"preset": "cook", "seed": 31, "female": true, "name": "CoBa", "clip": "carry", "height": 0.96})
	cook.position = Vector3(-8.0, 0.0, -9.65)
	cook.rotation.y = PI
	hall.add_child(cook)
	var lbl2 := Label3D.new()
	lbl2.text = "🏪 7-ELEVEN CAMPUS – [E] VÀO MUA COMBO"
	lbl2.font_size = 22
	lbl2.outline_size = 8
	lbl2.modulate = Color("#2ECC71")
	lbl2.position = Vector3(8.0, 2.95, -6.0)
	hall.add_child(lbl2)
	# Nhóm đứng tụ tập (chướng ngại cứng) tại điểm nghẽn – 3 người thật quay mặt vào nhau tán gẫu
	var gi: int = 0
	for center: Vector3 in [Vector3(0.0, 0.0, 3.0), Vector3(6.5, 0.0, 2.5), Vector3(-6.0, 0.0, 8.0)]:
		for k: int in range(3):
			var ang: float = k * TAU / 3.0
			var sb := StaticBody3D.new()
			sb.position = center + Vector3(cos(ang) * 0.7, 0.0, sin(ang) * 0.7)
			hall.add_child(sb)
			var cs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.32
			cap.height = 1.7
			cs.shape = cap
			cs.position = Vector3(0.0, 0.85, 0.0)
			sb.add_child(cs)
			var talker: Node3D = CharacterBuilder.build({"preset": "student" if gi % 4 != 3 else "casual", "seed": 500 + gi * 7, "name": "Talker%d" % gi})
			talker.rotation.y = atan2(cos(ang), sin(ang))
			sb.add_child(talker)
			if k == 0:
				CharacterBuilder.play(talker, "phone")
			gi += 1
		var glbl := Label3D.new()
		glbl.text = "💬 'Ê nghe nói slot 3 nghỉ hả?'"
		glbl.font_size = 20
		glbl.outline_size = 7
		glbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glbl.position = center + Vector3(0.0, 2.3, 0.0)
		hall.add_child(glbl)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(-3.0, 0.0, -3.5)
	hall.add_child(player)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0.0, 0.85, 0.0)
	player.add_child(cs)

	# Người chơi: CharacterBuilder "player" (áo FPT, ba lô, vòng tay vàng); bước đi do Animator lái theo vận tốc
	player_visual = CharacterBuilder.build({"preset": "player", "seed": 2805, "name": "PlayerVisual", "glasses": false})
	player.add_child(player_visual)

	tray_mesh = Node3D.new()
	tray_mesh.position = Vector3(0.0, 1.0, -0.42)
	player_visual.add_child(tray_mesh)
	var tray := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.6, 0.03, 0.4)
	tray.mesh = tm
	var mat_tray := StandardMaterial3D.new()
	mat_tray.albedo_color = Color("#C0392B")
	tray.material_override = mat_tray
	tray_mesh.add_child(tray)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.14
	bm.bottom_radius = 0.1
	bm.height = 0.08
	bowl.mesh = bm
	var mat_bowl := StandardMaterial3D.new()
	mat_bowl.albedo_color = Color.WHITE
	bowl.material_override = mat_bowl
	bowl.position = Vector3(-0.12, 0.06, 0.0)
	tray_mesh.add_child(bowl)
	var cup := MeshInstance3D.new()
	var cpm := CylinderMesh.new()
	cpm.top_radius = 0.05
	cpm.bottom_radius = 0.04
	cpm.height = 0.14
	cup.mesh = cpm
	var mat_cup := StandardMaterial3D.new()
	mat_cup.albedo_color = Color("#F39C12")
	cup.material_override = mat_cup
	cup.position = Vector3(0.18, 0.08, 0.05)
	tray_mesh.add_child(cup)
	tray_mesh.visible = false

	# Bạn đang vẫy ở bàn (người thật, clip "wave" liên tục)
	friend_root = Node3D.new()
	hall.add_child(friend_root)
	var friend_person: Node3D = CharacterBuilder.build({"preset": "student", "seed": 77, "name": "Friend", "clip": "wave"})
	friend_root.add_child(friend_person)
	friend_arm = CharacterBuilder.get_pivot(friend_person, "shoulder_r")
	friend_label = Label3D.new()
	friend_label.font_size = 34
	friend_label.outline_size = 10
	friend_label.modulate = Color("#F1C40F")
	friend_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	friend_label.position = Vector3(0.0, 2.6, 0.0)
	friend_root.add_child(friend_label)

func _build_npcs(count: int) -> void:
	var colors: Array[Color] = [Color("#F37021"), Color("#F37021"), Color("#F37021"), Color("#3498DB"), Color("#2C3E50"), Color("#E84393")]
	for i: int in range(count):
		var root := Node3D.new()
		var wps: Array[Vector3] = []
		for k: int in range(3 + randi() % 2):
			wps.append(Vector3(randf_range(-13.0, 13.0), 0.0, randf_range(-5.0, 11.0)))
		root.position = wps[0]
		hall.add_child(root)
		var npc_opts: Dictionary = {"preset": "student" if randf() < 0.65 else "casual", "seed": 700 + i * 19, "name": "Walker%d" % i}
		var walker: Node3D = CharacterBuilder.build(npc_opts)
		root.add_child(walker)
		if randf() < 0.5:
			CharacterBuilder.play(walker, "carry")
			var tray := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.5, 0.03, 0.35)
			tray.mesh = tm
			var mat_tray_npc := StandardMaterial3D.new()
			mat_tray_npc.albedo_color = [Color("#C0392B"), Color("#2980B9"), Color("#27AE60")][randi() % 3]
			tray.material_override = mat_tray_npc
			tray.position = Vector3(0.0, 1.0, -0.42)
			root.add_child(tray)
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.62
		cs.shape = sph
		cs.position = Vector3(0.0, 0.9, 0.0)
		area.add_child(cs)
		root.add_child(area)
		area.body_entered.connect(_on_npc_bump.bind(root))
		npcs.append({"node": root, "char": walker, "wps": wps, "idx": 1, "speed": randf_range(1.6, 2.5), "pause": randf_range(0.0, 1.0)})

# ===========================================================================
# HUD
# ===========================================================================
func _build_hud() -> void:
	balance_title.text = "⚖️ KHAY CƠM – giữ vạch ở giữa (đứng yên + giữ [SPACE] để cân lại)"
	balance_bar.value = 50.0
	GameFX.set_bar_color(balance_bar, Color("#2ECC71"))
	balance_hbox.visible = false
	balance_hint = GameFX.make_label("Chưa cầm khay – tới quầy cô Ba lấy cơm", 13, Color("#BDC3C7"))
	balance_vbox.add_child(balance_hint)

	prompt_panel = GameFX.anchored_panel(hud, Control.PRESET_CENTER_TOP, Vector2(760, 0), 80, GameFX.FPT_YELLOW)
	prompt_label = GameFX.make_label("", 18, GameFX.FPT_YELLOW)
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false

func _say(text: String, color: Color = GameFX.FPT_YELLOW) -> void:
	prompt_panel.visible = text != ""
	prompt_label.text = text
	prompt_label.add_theme_color_override("font_color", color)

# ===========================================================================
# INPUT
# ===========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if is_stage_ended:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if phase == Phase.SHOP:
			_shop_key(event.physical_keycode)
			return
		if event.physical_keycode == KEY_E:
			_interact()

func _shop_key(key: int) -> void:
	var cols: int = 4
	match key:
		KEY_LEFT, KEY_A:
			if shop_focus_zone == 0:
				shop_focus_idx = (shop_focus_idx / cols) * cols + ((shop_focus_idx % cols) + cols - 1) % cols
			_refresh_shop_focus()
		KEY_RIGHT, KEY_D:
			if shop_focus_zone == 0:
				shop_focus_idx = (shop_focus_idx / cols) * cols + ((shop_focus_idx % cols) + 1) % cols
			_refresh_shop_focus()
		KEY_UP, KEY_W:
			if shop_focus_zone == 0:
				shop_focus_idx = (shop_focus_idx + shop_cards.size() - cols) % shop_cards.size()
			else:
				basket_focus_idx = maxi(0, basket_focus_idx - 1)
			_refresh_shop_focus()
		KEY_DOWN, KEY_S:
			if shop_focus_zone == 0:
				shop_focus_idx = (shop_focus_idx + cols) % shop_cards.size()
			else:
				basket_focus_idx = mini(basket.size() - 1, basket_focus_idx + 1)
			_refresh_shop_focus()
		KEY_TAB:
			shop_focus_zone = 1 - shop_focus_zone if not basket.is_empty() else 0
			basket_focus_idx = clampi(basket_focus_idx, 0, maxi(0, basket.size() - 1))
			GameFX.play_sfx("tick", -10.0)
			_refresh_shop_focus()
		KEY_ENTER, KEY_KP_ENTER, KEY_E:
			if shop_focus_zone == 0 and shop_focus_idx < SHOP_ITEMS.size():
				add_to_basket(SHOP_ITEMS[shop_focus_idx])
			elif shop_focus_zone == 1:
				remove_from_basket(basket_focus_idx)
				if basket.is_empty():
					shop_focus_zone = 0
				basket_focus_idx = clampi(basket_focus_idx, 0, maxi(0, basket.size() - 1))
				_refresh_shop_focus()
		KEY_BACKSPACE, KEY_DELETE:
			if not basket.is_empty():
				remove_from_basket(basket.size() - 1 if shop_focus_zone == 0 else basket_focus_idx)
				if basket.is_empty():
					shop_focus_zone = 0
				basket_focus_idx = clampi(basket_focus_idx, 0, maxi(0, basket.size() - 1))
				_refresh_shop_focus()
		KEY_SPACE:
			if pay_btn and not pay_btn.disabled:
				_on_pay_pressed()
			else:
				GameFX.play_sfx("error", -6.0)
				if shop_panel:
					var tw := create_tween()
					tw.tween_property(shop_panel, "position:x", shop_panel.position.x + 10.0, 0.05)
					tw.tween_property(shop_panel, "position:x", shop_panel.position.x - 10.0, 0.05)
					tw.tween_property(shop_panel, "position:x", shop_panel.position.x, 0.05)

func _refresh_shop_focus() -> void:
	for i: int in range(shop_cards.size()):
		var c: PanelContainer = shop_cards[i]
		var focused: bool = shop_focus_zone == 0 and i == shop_focus_idx
		c.add_theme_stylebox_override("panel", GameFX.make_panel_style(GameFX.FPT_YELLOW if focused else Color("#2ECC71"), Color(0.12, 0.12, 0.04, 0.98) if focused else Color(0.05, 0.1, 0.08, 0.98), 8))
		c.scale = Vector2(1.04, 1.04) if focused else Vector2.ONE
		c.pivot_offset = c.size * 0.5
	for i: int in range(basket_buttons.size()):
		var b: Button = basket_buttons[i]
		if is_instance_valid(b):
			b.add_theme_color_override("font_color", GameFX.FPT_YELLOW if (shop_focus_zone == 1 and i == basket_focus_idx) else Color.WHITE)

func _interact() -> void:
	match phase:
		Phase.SERVE:
			var p: Vector3 = player.global_position
			if not has_tray and p.distance_to(COUNTER_FRONT) < 2.8:
				_take_tray()
			elif has_tray and p.distance_to(_current_table()) < 2.4:
				_deliver()
			elif not has_tray:
				_say("Tới quầy cô Ba (bên trái) để lấy khay!", GameFX.FPT_YELLOW)
			else:
				_say("Mang khay tới bàn bạn đang vẫy tay!", GameFX.FPT_YELLOW)
		Phase.TO_SHOP:
			if player.global_position.distance_to(SHOP_FRONT) < 3.0:
				_open_shop()
			else:
				_say("Đi tới 7-Eleven (bên phải) rồi bấm [E]!", GameFX.FPT_GREEN)

# ===========================================================================
# PHA 1
# ===========================================================================
func _current_table() -> Vector3:
	return ORDERS[order_idx]["table"]

func _set_order(idx: int) -> void:
	order_idx = clampi(idx, 0, ORDERS.size() - 1)
	var o: Dictionary = ORDERS[order_idx]
	friend_root.position = o["table"] + Vector3(0.0, 0.0, 1.3)
	friend_label.text = "🙋 %s: 'ĐÂY NÈ!! %s CỦA TUI ĐÂU?!'" % [o["friend"], o["food"]]
	mission_label.text = "ĐƠN %d/2: LẤY %s Ở QUẦY → GIAO TỚI BÀN %s (%s)" % [order_idx + 1, o["food"], ("BÊN PHẢI" if o["table"].x > 0 else "BÊN TRÁI"), o["friend"]]

func _take_tray() -> void:
	has_tray = true
	CharacterBuilder.play(player_visual, "carry")
	tilt = 0.0
	tray_mesh.visible = true
	GameFX.play_sfx("pop", -2.0)
	_say("🍛 ĐÃ LẤY %s! Đi chậm thôi, né đám đông!" % ORDERS[order_idx]["food"], GameFX.FPT_GREEN)
	balance_hint.text = "Đang bưng khay: đi chậm, né người; đứng yên + [SPACE] để cân"

func _deliver() -> void:
	has_tray = false
	CharacterBuilder.stop_clip(player_visual)
	tray_mesh.visible = false
	orders_done += 1
	GameFX.play_sfx("success")
	GameFX.flash(GameFX.FPT_GREEN, 0.3, 0.3)
	GameFX.popup("✅ GIAO XONG! %s: 'Trời ơi cứu tinh!'" % ORDERS[order_idx]["friend"], GameFX.FPT_GREEN, 28, 1.4)
	score_phase1 += 300
	if orders_done >= ORDERS.size():
		_start_to_shop()
	else:
		_set_order(order_idx + 1)
		_build_npcs(5) # Đơn 2: đông hơn
		_say("🧋 ĐƠN 2: quay lại quầy lấy TRÀ ĐÁ + MÌ XÀO cho Hằng (bàn BÊN TRÁI). Căn tin đông hơn rồi!", GameFX.FPT_YELLOW)
		balance_hint.text = "Chưa cầm khay – quay lại quầy cô Ba"

func _spill() -> void:
	has_tray = false
	CharacterBuilder.stop_clip(player_visual)
	tray_mesh.visible = false
	spills += 1
	tilt = 0.0
	GameFX.play_sfx("thud")
	GameFX.play_sfx("miss", -4.0)
	GameFX.shake(0.6)
	GameFX.flash(GameFX.FPT_RED, 0.35, 0.35)
	GameFX.popup("💥 ĐỔ CƠM!! Cô Ba: 'TRỜI ƠI CƠM CỦA TUI!' – quay lại quầy lấy khay mới", GameFX.FPT_RED, 26, 2.0)
	GameFX.float_text(self, player.global_position + Vector3(0, 2.2, 0), "ĐỔ RỒI!", GameFX.FPT_RED, 48)
	balance_hint.text = "Đổ rồi... quay lại quầy cô Ba lấy khay mới"
	# Vũng cơm trên sàn
	var puddle := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.6
	pm.bottom_radius = 0.6
	pm.height = 0.03
	puddle.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#F5E6C8")
	puddle.material_override = mat
	puddle.position = player.global_position + Vector3(0.0, 0.03, -0.6)
	hall.add_child(puddle)

func _on_npc_bump(body: Node3D, npc: Node3D) -> void:
	if body != player or phase != Phase.SERVE or not has_tray or bump_cooldown > 0.0:
		return
	bump_cooldown = 0.5
	bumps += 1
	var side: float = 1.0 if (npc.global_position - player.global_position).dot(player.global_transform.basis.x) > 0.0 else -1.0
	tilt += 28.0 * -side
	tray_shake = 1.0
	GameFX.play_sfx("hit", -8.0, 1.2)
	GameFX.shake(0.2)
	GameFX.float_text(self, player.global_position + Vector3(0, 2.1, 0), ["'Ủa đi kiểu gì vậy?!'", "'Xin lỗi xin lỗi!'", "'Coi chừng cơm!'", "'Ê né ra!'"][randi() % 4], Color.WHITE, 26)

func _process(delta: float) -> void:
	if is_stage_ended:
		return
	match phase:
		Phase.SERVE, Phase.TO_SHOP:
			time_left -= delta
			_process_walk(delta)
			_process_npcs(delta)
			_process_tray(delta)
			_update_camera(delta)
			mission_label.text = mission_label.text.get_slice(" ⏱", 0) + " ⏱ %ds" % int(ceil(maxf(0.0, time_left)))
			if time_left <= 0.0:
				_fail_stage("HẾT GIỜ NGHỈ TRƯA! Bạn bè đói meo, cô Ba lắc đầu: 'Lần sau lẹ lên em!'")
		Phase.SHOP:
			time_left -= delta
			shop_timer_bar.value = time_left / SHOP_TIME * 100.0
			if time_left <= 0.0:
				_fail_stage("HẾT GIỜ! Thu ngân 7-Eleven: 'Em ơi 13:00 vào lớp rồi, tính tiền chưa?' – combo không kịp mua.")

func _process_walk(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	var balancing: bool = has_tray and Input.is_key_pressed(KEY_SPACE)
	if balancing:
		dir = Vector3.ZERO
	dir = dir.normalized()
	var speed: float = WALK_SPEED if has_tray else WALK_SPEED_FREE
	player.velocity.x = move_toward(player.velocity.x, dir.x * speed, delta * 30.0)
	player.velocity.z = move_toward(player.velocity.z, dir.z * speed, delta * 30.0)
	player.velocity.y = -1.0
	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -HALL_HALF.x, HALL_HALF.x)
	player.global_position.z = clampf(player.global_position.z, -HALL_HALF.y, HALL_HALF.y)
	if dir != Vector3.ZERO:
		var yaw: float = atan2(-dir.x, -dir.z)
		player_visual.rotation.y = lerp_angle(player_visual.rotation.y, yaw, delta * 12.0)
	CharacterBuilder.set_speed(player_visual, Vector2(player.velocity.x, player.velocity.z).length())
	bump_cooldown = maxf(0.0, bump_cooldown - delta)

func _process_npcs(delta: float) -> void:
	for n: Dictionary in npcs:
		var node: Node3D = n["node"]
		if n["pause"] > 0.0:
			n["pause"] = float(n["pause"]) - delta
			CharacterBuilder.set_speed(n["char"], 0.0)
			continue
		CharacterBuilder.set_speed(n["char"], float(n["speed"]))
		var wps: Array = n["wps"]
		var target: Vector3 = wps[int(n["idx"])]
		var to: Vector3 = target - node.position
		to.y = 0.0
		if to.length() < 0.3:
			n["idx"] = (int(n["idx"]) + 1) % wps.size()
			n["pause"] = randf_range(0.2, 1.2)
			continue
		var step: Vector3 = to.normalized() * float(n["speed"]) * delta
		node.position += step
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-to.x, -to.z), delta * 8.0)

func _process_tray(delta: float) -> void:
	if not has_tray:
		tilt = move_toward(tilt, 0.0, delta * 80.0)
		balance_bar.value = 50.0
		tray_mesh.rotation.z = 0.0
		return
	var moving_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var balancing: bool = Input.is_key_pressed(KEY_SPACE) and moving_speed < 0.3
	drift_timer -= delta
	if drift_timer <= 0.0:
		drift_timer = randf_range(0.8, 1.6)
		drift_dir = 1.0 if randf() < 0.5 else -1.0
	if balancing:
		tilt = move_toward(tilt, 0.0, delta * 70.0)
	else:
		var sway: float = (moving_speed / WALK_SPEED) * 22.0 + 6.0
		tilt += drift_dir * sway * delta + randf_range(-1.0, 1.0) * sway * 0.4 * delta
		if moving_speed < 0.3:
			tilt = move_toward(tilt, 0.0, delta * 8.0)
	tilt = clampf(tilt, -100.0, 100.0)
	tray_shake = maxf(0.0, tray_shake - delta * 3.0)
	tray_mesh.rotation.z = deg_to_rad(tilt * 0.35) + sin(Time.get_ticks_msec() * 0.05) * tray_shake * 0.2
	balance_bar.value = 50.0 + tilt * 0.5
	var danger: float = absf(tilt) / 100.0
	GameFX.set_bar_color(balance_bar, Color("#2ECC71") if danger < 0.5 else (Color("#F1C40F") if danger < 0.8 else Color("#E74C3C")))
	if danger >= 0.8:
		balance_hint.text = "⚠️ SẮP ĐỔ! ĐỨNG YÊN GIỮ [SPACE] ĐỂ CÂN LẠI!"
		balance_hint.add_theme_color_override("font_color", Color("#E74C3C"))
	else:
		balance_hint.add_theme_color_override("font_color", Color("#BDC3C7"))
	if absf(tilt) >= 100.0:
		_spill()

func _update_camera(delta: float) -> void:
	# Trong nhà (trần 3.4 m) camera hạ thấp sau lưng; ra hiên camera nâng cao nhìn xuống
	var p: Vector3 = player.global_position
	var indoor: float = clampf((2.6 - p.z) / 2.5, 0.0, 1.0)
	var offset: Vector3 = Vector3(0.0, 7.5, 7.5).lerp(Vector3(0.0, 2.75, 3.9), indoor)
	camera.global_position = camera.global_position.lerp(p + offset, delta * 6.0)
	var look: Vector3 = p + Vector3(0.0, 0.8, -0.5).lerp(Vector3(0.0, 0.9, -3.0), indoor)
	camera.look_at(look, Vector3.UP)

# ===========================================================================
# PHA 2: 7-ELEVEN
# ===========================================================================
func _start_to_shop() -> void:
	phase = Phase.TO_SHOP
	time_left = maxf(time_left, 20.0)
	mission_label.text = "ĐÃ GIAO 2 ĐƠN! GHÉ 7-ELEVEN (BÊN PHẢI) BẤM [E] MUA COMBO CỨU SINH CHO ĐÊM CAPSTONE"
	mission_label.add_theme_color_override("font_color", Color("#2ECC71"))
	balance_panel.visible = false
	_say("🏪 Đi tới 7-Eleven bên phải rồi bấm [E]", GameFX.FPT_GREEN)
	friend_label.text = "🙋 Cảm ơn nha! Tối nay nhớ merge code!"

func _open_shop() -> void:
	phase = Phase.SHOP
	time_left = SHOP_TIME
	budget = [30, 40, 50][randi() % 3]
	basket.clear()
	_say("")
	_build_shop_ui()
	shop_panel.visible = true
	GameFX.play_sfx("cash", -2.0)
	mission_label.text = "7-ELEVEN: KÉO THẢ (hoặc double-click) MÓN VÀO GIỎ – NGÂN SÁCH %dk · CẦN ⚡≥%d & 🧠≥%d" % [budget, TARGET_ENERGY, TARGET_SANITY]

func _build_shop_ui() -> void:
	for c: Node in [buy_noodles_btn, buy_drink_btn, finish_shop_btn]:
		c.visible = false
	shop_panel.custom_minimum_size = Vector2(960, 560)
	shop_title.text = "🏪 7-ELEVEN FPTU CAMPUS – NGÂN SÁCH %dk · 35 GIÂY" % budget
	shop_timer_bar = GameFX.make_bar(100.0, Color("#E74C3C"), 10)
	shop_vbox.add_child(shop_timer_bar)
	var hint := GameFX.make_label("Mục tiêu: ⚡ NĂNG LƯỢNG ≥ %d và 🧠 TINH THẦN ≥ %d, không vượt %dk." % [TARGET_ENERGY, TARGET_SANITY, budget], 14, Color("#BDC3C7"))
	shop_vbox.add_child(hint)
	var keys_hint := GameFX.make_label("⌨ [←→↑↓] chọn món · [ENTER] thêm vào giỏ · [BACKSPACE] bỏ món cuối · [TAB] sang giỏ · [SPACE] trả tiền   (chuột: kéo thả / double-click)", 13, GameFX.FPT_YELLOW)
	shop_vbox.add_child(keys_hint)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	shop_vbox.add_child(hb)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(grid)
	for item: Dictionary in SHOP_ITEMS:
		var card := ShopCard.new()
		card.item = item
		card.stage = self
		card.custom_minimum_size = Vector2(150, 110)
		card.add_theme_stylebox_override("panel", GameFX.make_panel_style(Color("#2ECC71"), Color(0.05, 0.1, 0.08, 0.98), 8))
		card.tooltip_text = "Kéo vào giỏ hoặc double-click"
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vb)
		vb.add_child(GameFX.make_label("%s %s" % [item["icon"], item["name"]], 15, Color.WHITE))
		vb.add_child(GameFX.make_label("%dk" % item["price"], 20, Color("#F1C40F")))
		var stat: String = ""
		if int(item["energy"]) != 0:
			stat += "⚡%+d " % int(item["energy"])
		if int(item["sanity"]) != 0:
			stat += "🧠%+d" % int(item["sanity"])
		vb.add_child(GameFX.make_label(stat, 13, Color("#74B9FF")))
		grid.add_child(card)
		shop_cards.append(card)

	var basket_panel := BasketDrop.new()
	basket_panel.stage = self
	basket_panel.custom_minimum_size = Vector2(300, 320)
	basket_panel.add_theme_stylebox_override("panel", GameFX.make_panel_style(Color("#F37021"), Color(0.1, 0.07, 0.03, 0.98), 8))
	hb.add_child(basket_panel)
	var bvb := VBoxContainer.new()
	bvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	basket_panel.add_child(bvb)
	bvb.add_child(GameFX.make_label("🛒 GIỎ HÀNG (thả vào đây)", 16, Color("#F37021")))
	basket_list = VBoxContainer.new()
	basket_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bvb.add_child(basket_list)
	totals_label = GameFX.make_label("", 14, Color.WHITE)
	bvb.add_child(totals_label)
	pay_btn = Button.new()
	pay_btn.text = "💳 THANH TOÁN"
	pay_btn.custom_minimum_size = Vector2(0, 44)
	pay_btn.focus_mode = Control.FOCUS_NONE
	pay_btn.pressed.connect(_on_pay_pressed)
	bvb.add_child(pay_btn)
	shop_focus_idx = 0
	shop_focus_zone = 0
	_refresh_basket()
	_refresh_shop_focus()

func add_to_basket(item: Dictionary) -> void:
	if phase != Phase.SHOP:
		return
	var total: int = _basket_total("price") + int(item["price"])
	if total > budget:
		GameFX.play_sfx("error", -4.0)
		GameFX.popup("💸 Thu ngân: 'Thiếu %dk rồi em ơi!'" % (total - budget), GameFX.FPT_RED, 24, 1.0)
		return
	if basket.size() >= 6:
		GameFX.play_sfx("error", -4.0)
		GameFX.popup("Giỏ đầy rồi (tối đa 6 món)!", GameFX.FPT_RED, 22, 0.9)
		return
	basket.append(item)
	GameFX.play_sfx("pop", -4.0)
	_refresh_basket()

func remove_from_basket(idx: int) -> void:
	if idx >= 0 and idx < basket.size():
		basket.remove_at(idx)
		GameFX.play_sfx("tick", -6.0)
		_refresh_basket()

func _basket_total(key: String) -> int:
	var s: int = 0
	for it: Dictionary in basket:
		s += int(it[key])
	return s

func _refresh_basket() -> void:
	for c: Node in basket_list.get_children():
		c.queue_free()
	basket_buttons.clear()
	for i: int in range(basket.size()):
		var it: Dictionary = basket[i]
		var b := Button.new()
		b.text = "%s %s – %dk ✖" % [it["icon"], it["name"], it["price"]]
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_remove_idx.bind(i))
		basket_list.add_child(b)
		basket_buttons.append(b)
	var money: int = _basket_total("price")
	var e: int = _basket_total("energy")
	var s: int = _basket_total("sanity")
	var ok: bool = e >= TARGET_ENERGY and s >= TARGET_SANITY and money <= budget
	totals_label.text = "💰 %dk / %dk   ⚡ %d/%d %s   🧠 %d/%d %s" % [money, budget, e, TARGET_ENERGY, "✓" if e >= TARGET_ENERGY else "", s, TARGET_SANITY, "✓" if s >= TARGET_SANITY else ""]
	totals_label.add_theme_color_override("font_color", Color("#2ECC71") if ok else Color.WHITE)
	pay_btn.disabled = not ok
	pay_btn.text = "💳 THANH TOÁN %dk – ĐỦ COMBO!" % money if ok else "💳 CHƯA ĐỦ CHỈ SỐ / VƯỢT NGÂN SÁCH"

func _remove_idx(i: int) -> void:
	remove_from_basket(i)

func _on_pay_pressed() -> void:
	if phase != Phase.SHOP or pay_btn.disabled:
		return
	for it: Dictionary in basket:
		match str(it["id"]):
			"monster": StageManager.add_item("monster", 1)
			"coffee": StageManager.add_item("coffee", 1)
			"banh_bao": StageManager.add_item("banh_bao", 1)
	GameFX.play_sfx("cash")
	_complete_stage()

# ===========================================================================
# KẾT THÚC
# ===========================================================================
func _complete_stage() -> void:
	if is_stage_ended:
		return
	is_stage_ended = true
	phase = Phase.DONE
	shop_panel.visible = false
	var money_left: int = budget - _basket_total("price")
	var shop_score: int = int(time_left * 10.0) + money_left * 8 + maxi(0, _basket_total("energy") - TARGET_ENERGY) * 2 + maxi(0, _basket_total("sanity") - TARGET_SANITY) * 2
	var serve_score: int = score_phase1 + maxi(0, 300 - spills * 150) + maxi(0, 150 - bumps * 15)
	var score: int = serve_score + shop_score
	var rank: String = GameFX.rank_for(float(score), 1250.0, 1000.0, 700.0)
	StageManager.report_stage_result(StageManager.StageID.STAGE_5_CANTEEN, {
		"result": "win", "score": score, "rank": rank,
		"detail": "spills=%d bumps=%d basket=%d money_left=%d" % [spills, bumps, basket.size(), money_left]
	})
	GameFX.play_sfx("res://assets/audio/victory_fanfare.wav", 2.0)
	GameFX.flash(GameFX.FPT_GREEN, 0.4, 0.5)
	var items_txt: String = ""
	for it: Dictionary in basket:
		items_txt += str(it["icon"]) + " "
	var inv_txt: String = "Monster x%d · Cà phê x%d · Bánh bao x%d" % [StageManager.item_count("monster"), StageManager.item_count("coffee"), StageManager.item_count("banh_bao")]
	modal_title.text = "🎉 NO NÊ CĂN TIN & NẠP ĐẦY PIN 7-ELEVEN! RANK %s" % rank
	modal_title.modulate = Color("#2ECC71")
	modal_sub.text = "Giao 2 đơn · đổ cơm %d lần · va %d người.\nCombo 7-Eleven: %s(⚡%d 🧠%d) còn dư %dk.\nTúi đồ mang sang màn khác: %s\nĐiểm %d (căn tin %d + 7-Eleven %d)" % [
		spills, bumps, items_txt, _basket_total("energy"), _basket_total("sanity"), money_left, inv_txt, score, serve_score, shop_score
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
	shop_panel.visible = false
	StageManager.report_stage_result(StageManager.StageID.STAGE_5_CANTEEN, {"result": "fail", "score": score_phase1, "rank": "C", "detail": reason})
	GameFX.play_sfx("res://assets/audio/absent_gameover.wav", 2.0)
	modal_title.text = "❌ THẤT BẠI TẠI CĂN TIN!"
	modal_title.modulate = Color("#E74C3C")
	modal_sub.text = reason + "\nĐã giao %d/2 đơn · đổ cơm %d lần." % [orders_done, spills]
	next_btn.visible = false
	modal_overlay.visible = true
	modal_overlay.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(modal_overlay, "modulate:a", 1.0, 0.5)

func _on_next_pressed() -> void:
	StageManager.change_stage(StageManager.StageID.STAGE_6_CAPSTONE)

func _on_menu_pressed() -> void:
	StageManager.open_stage_select()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
