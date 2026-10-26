# File: res://scripts/FreeRoam.gd
# THẾ GIỚI MỞ trên bản đồ thật (plan Task 5, docs/superpowers/plans/2026-10-22-real-map-world.md):
#   - 3 vùng MapBuilder (vinhomes, corridor lod 1, campus) từ assets/data/mapdata.json + campus FPTU thật
#     (FPTUCampusBuilder.real_plot_transform(), quay 136°, opts walk_colliders: vỉa hè/bó vỉa/thảm cổng có va chạm)
#     + HUTECH đối diện (không vẽ lại dải D1 xa).
#   - Mặt đất: hình vuông 12 km chia ô GROUND_TILE m, khoét đúng các mặt nước (MapBuilder._water_polygons) -> cùng
#     các mảnh đó dựng mặt cỏ (y = -0,05) và sàn đi bộ ConcavePolygonShape3D (y = 0). Dưới đó một WorldBoundaryShape3D
#     ở mực nước (MapBuilder.WATER_Y) để không ai rơi mãi, tường bờ kênh vô hình cao BANK_WALL_H dọc mép mọi mặt nước
#     (khe đúng bằng ribbon của đường / lối đi bộ có mặt thấp cắt qua; dưới cầu cao tường chạy liền) và lan can vô hình
#     dọc hai mép ribbon ở mọi đoạn mặt thấp nằm trên mặt nước (cầu đi bộ, đường qua cống, đầu cầu thấp chưa có lan can
#     BridgeParts) để không đi bộ, chạy xe hay xuống xe vào kênh. Lưới an toàn: đứng / chạy xe trên sàn mực nước quá
#     RESCUE_AFTER_S giây -> đưa về chỗ khô gần chỗ khô cuối cùng (find_free_spot) + gợi ý.
#   - Spawn: MapData.spawn_transform() (6 m ngoài cửa sảnh BE6, quay lưng vào toà tháp) hoặc StageManager.roam_spawn
#     khi quay về từ một màn chơi; điểm spawn được kiểm bằng capsule người chơi (intersect_shape) + tia tìm sàn, nếu vướng
#     thì dò ra ngoài theo vòng 1 m tới SPAWN_SEARCH_M m, cuối cùng về spawn BE6. Người chơi = ThirdPersonController;
#     xe máy = PlayerBike.tscn (ẩn tới khi [F]; khi đỗ vẫn là vật cản: disable_mode KEEP_ACTIVE).
#   - Hotspot Area3D "Hotspot_<StageID>" (bán kính 2,5 m, cột sáng + Label3D) đều ở MẶT ĐẤT đi tới được: sân BE6
#     (Màn 1), cổng sau (Màn 2), cửa kính sảnh thông tầng cánh phải nhìn ra sân trong (Lab 402: Màn 3 ban ngày / Màn 6
#     ban đêm), đầu sân bóng phía làn bãi xe ngoài hàng rào (Màn 4), căn tin (Màn 5), mặt sân trong của module chứa
#     phòng 311 (Extra). [E] trong hotspot -> StageManager.start_stage_from_roam() (roam_spawn = return_spawn: 3,5 m từ
#     hotspot về phía tâm sân trong / về spawn BE6, đã kiểm chỗ trống).
#   - HUD (anchors): gợi ý đáy giữa (kèm phím di chuyển kiểu GTA: nước rút / đi bộ / nhảy), thanh thể lực nước rút ngay
#     trên dòng gợi ý (chỉ hiện khi đang đi bộ và đang nước rút / chưa hồi đầy), giờ trong ngày trên trái, FPS + khoảng
#     cách tới cổng FPTU trên phải. Tường bờ kênh / lan can vô hình cao 1,6 m: cú nhảy (~0,95 m) không vượt qua được.
#     [T] đổi preset giờ (GameFX.TOD_PRESETS ngoài trời + đêm; luôn áp lên Environment gốc của cảnh), [M] bản đồ
#     (RoamMap: lớp tĩnh = 1 mesh 2D dựng sẵn, chỉ vẽ khi mở lần đầu / đổi kích thước / đổi màu hotspot; lớp động =
#     người chơi + xe đang đỗ, vẽ lại theo nhịp HUD), [Z]/[C] xoay camera, [ESC] tạm dừng (StageManager).
#   - Đám đông ba tầng (PedestrianSpawner "Pedestrians", spec vice-people Phần 3): dựng cuối _ready khi crowd_enabled,
#     tránh cột sáng hotspot và điểm spawn.
#   - Cinematic (spec A1): cine_stage() / play_cinematic(); [F9] (bản debug) phát lần lượt các timeline.
# Autoload chỉ dùng qua get_node_or_null("/root/GameFX" | "/root/StageManager") (test headless chạy được không cần
# autoload); hàm tĩnh / enum lấy qua preload script.
extends Node3D

const GameFXScript: Script = preload("res://scripts/GameFX.gd")
const StageManagerScript: Script = preload("res://scripts/StageManager.gd")
const BIKE_SCENE: PackedScene = preload("res://scenes/PlayerBike.tscn")

## Vòng nhà chính FPT (relation) + 3 nhà trên lô HUTECH: FPTUCampusBuilder dựng chi tiết, MapBuilder bỏ qua.
const SKIP_BUILDING_IDS: Array = [13698121, 605379726, 605379727, 605379728]
## Lô đất FPT (cỏ của builder phủ) + sân bóng & bãi xe OSM bên trong lô (builder tự dựng).
const SKIP_AREA_IDS: Array = [1022939891, 1022939892, 1022939893]
const HOTSPOT_RADIUS: float = 2.5
const MOUNT_RANGE: float = 2.5
const GROUND_SIZE: float = 12000.0
const GROUND_TILE: float = 500.0          # ô chia mặt đất (tam giác sàn va chạm không dài hàng km)
const GROUND_MESH_Y: float = -0.05
const GROUND_COLLIDER_Y: float = 0.0
const BANK_WALL_H: float = 1.6           # tường bờ kênh vô hình: từ dưới mặt nước lên 1,6 m trên mặt đất
const BANK_GAP_DECK_MAX: float = 1.65    # tường bờ chỉ khoét dưới đoạn ribbon có mặt thấp hơn đỉnh tường (+5 cm)
# đoạn ribbon trên mặt nước thấp hơn ROAD_Y + DECK_GUARD_MAX_H: lan can vô hình 2 mép. Suy từ BANK_GAP_DECK_MAX để
# mọi đoạn được khoét khe tường bờ đều có lan can (không còn đoạn có khe mà hở mép).
const DECK_GUARD_MAX_H: float = BANK_GAP_DECK_MAX - MapBuilder.ROAD_Y
const DECK_GUARD_ABOVE: float = 1.6      # lan can vô hình cao tới mặt đường + 1,6 m (cú nhảy ~0,95 m không qua được)
const WALL_BOTTOM_BELOW_WATER: float = 0.3
const ROAD_HASH_CELL: float = 64.0
const WET_MARGIN: float = 0.15           # chân (người / xe) thấp hơn WATER_Y + 0,15 = đang ở dưới kênh
const WATER_FLOOR_BELOW: float = 0.2     # sàn dự phòng dưới nước đặt thấp hơn WATER_Y (vượt tầm floor snap)
const RESCUE_AFTER_S: float = 1.0
const PLAYER_RADIUS: float = 0.4         # = capsule của ThirdPersonController
const PLAYER_HEIGHT: float = 1.7
const SPOT_LIFT: float = 0.05            # capsule kiểm tra đặt cao hơn mặt sàn chút để không tính "chạm sàn"
const FLOOR_PROBE_UP: float = 0.45       # sàn hợp lệ: cao hơn mốc tối đa ~ 1 bậc
const FLOOR_PROBE_DOWN: float = 1.0
const SPAWN_SEARCH_M: int = 8
const RETURN_SPAWN_M: float = 3.5
const ATRIUM_PUSH_M: float = 2.0
const DISMOUNT_OFFSETS: Array[float] = [1.3, 2.0]
const BIKE_FLOOR_OFFSET: float = 0.13    # gốc PlayerBike nằm dưới mặt sàn 0,13 m (capsule nằm r 0,42 tâm y 0,55)
const HINT_FLASH_S: float = 2.5
const HUD_REFRESH: float = 0.2
const MAP_TOP: float = 66.0              # bản đồ [M] bắt đầu dưới bảng giờ / FPS (cao ~56 px)
const MAP_BOTTOM: float = 30.0
const HINT_DEFAULT: String = "[WASD] đi · [Shift] chạy nước rút · [Ctrl] đi bộ · [Space] nhảy · [Z]/[C] xoay camera · [F] xe máy · [T] giờ trong ngày · [M] bản đồ · [ESC] tạm dừng"
## Story mode (A2): the story drives the time of day, so [T] gives way to the phone [P].
const HINT_STORY: String = "[WASD] đi · [Shift] chạy nước rút · [Ctrl] đi bộ · [Space] nhảy · [Z]/[C] xoay camera · [F] xe máy · [P] điện thoại · [M] bản đồ · [ESC] tạm dừng"
const HINT_RIDING: String = "[F] xuống xe · [W]/[S] ga/phanh · [A]/[D] lái · [SPACE] drift · [H] còi · [L] đèn xa"
const HINT_NO_DISMOUNT: String = "Không có chỗ trống cạnh xe để xuống (nước / tường / vật cản) – chạy ra chỗ rộng rồi bấm [F]"
const HINT_RESCUED: String = "Rơi xuống kênh! Đã đưa bạn về chỗ khô gần nhất"
const HINT_SERVICE_BIKE: String = "Đang lao động công ích – làm xong mới được lấy xe"
const TOD_NAMES: Dictionary = {"dawn": "Bình minh 06:00", "morning": "Buổi sáng 07:30", "noon": "Giữa trưa 11:30", "sunset": "Hoàng hôn 17:45", "night": "Đêm khuya 23:00"}
const HOTSPOT_COLORS: Dictionary = {1: Color("#F37021"), 2: Color("#3498DB"), 3: Color("#2ECC71"), 4: Color("#E74C3C"), 5: Color("#F1C40F"), 6: Color("#9B59B6"), 7: Color("#1ABC9C")}

@onready var world: Node3D = $World
@onready var hud: CanvasLayer = $HUD

var md: MapData
var player: ThirdPersonController
var bike: PlayerBike
var pedestrians: PedestrianSpawner
var traffic: RoamTraffic
## false = không dựng người đi đường / xe chạy (test_free_roam đặt trước add_child để các pha kiểm tra cố định)
var crowd_enabled: bool = true
## false = no weapons / wanted level (Phase W): test_free_roam sets it before add_child so its phases stay deterministic.
var mayhem_enabled: bool = true
var weapons: WeaponDirector
var weapon_wheel: WeaponWheel
var weapon_hud: WeaponHUD
var wanted: WantedDirector
## Classic style: small wanted star row under the clock (spec section 4); ViceHUD shows them in vice style.
var classic_stars: ViceStars
var emote_wheel: EmoteWheel
var emotes: EmoteDirector
## Phase B unarmed Vovinam combat (scripts/combat/): owns Tay không, HP, the combat HUD; MeleeFight registers enemies.
var combat: PlayerCombat
## Story mode (spec A2-D4): StoryDirector.active when the scene loads. No stage hotspots, no [T]; the story layer (markers,
## objective, phone, call, beat runner) lives in the StoryRoam child, scripts/story/.
var story_mode: bool = false
var story_roam: StoryRoam = null
## Random jump scares in both modes (RandomScares; GameFX "Hù dọa ngẫu nhiên").
var random_scares: RandomScares = null
var mounted: bool = false
var bike_parked: bool = false
## Phase C bike chase (BikeChase): the riding hint while set (instead of HINT_RIDING), and [F] refused off the bike with
## this hint while set ("" = normal).
var riding_hint: String = ""
var dismount_refusal: String = ""
var campus_xf: Transform3D = Transform3D.IDENTITY
var gate_xz: Vector2 = Vector2(16.1, 99.5)
var hotspots: Array[Area3D] = []
var active_hotspot: Area3D = null
var tod_preset: String = ""
var tod_cycle: Array[String] = []
var build_ms: int = 0
var spawn_xf: Transform3D = Transform3D.IDENTITY
## Sàn đi bộ (ConcavePolygonShape3D khoét nước), sàn mực nước, tường bờ kênh.
var ground_body: StaticBody3D
var water_floor: StaticBody3D
var bank_walls: StaticBody3D

var hint_label: Label
var hint_holder: Control
var tod_label: Label
var stats_label: Label
var map_overlay: RoamMap
## Thanh thể lực nước rút (ThirdPersonController.stamina): hiện khi đang đi bộ và đang nước rút / chưa hồi đầy.
var stamina_bar: ProgressBar
## HUD kiểu thập niên 80 (Task VC-4): chỉ hiện ở phong cách vice; giờ = huy hiệu giờ trong ngày, ví Cóc Vàng, radar
## (blip hotspot theo màu màn, xe đang đỗ khi đi bộ, tuyến BE6 -> FPTU màu hồng), tên khu vực, "Xe máy" khi lên xe.
var vice_hud: ViceHUD
var tod_holder: Control
var stats_holder: Control
var _hud_timer: float = 0.0
var _lab_hotspot: Area3D = null
var _base_env: Environment = null
var _hint_flash: String = ""
var _hint_flash_t: float = 0.0
var _probe_capsule: CapsuleShape3D
## Lưới an toàn dưới kênh: chỗ khô cuối cùng (chân người / bánh xe đang chạm sàn khô), thời gian đã ở dưới nước.
var _last_dry: Vector3 = Vector3.ZERO
var _has_dry: bool = false
var _wet_t: float = 0.0
var rescues: int = 0

signal cinematic_finished(slot: String, skipped: bool)

const CINE_FLOOR_UP: float = 2.0         # tia tìm sàn sân khấu bắt đầu 2 m trên mặt đất của landmark (không dính mái)
const CINE_FLOOR_MAX: float = 0.5        # sàn lệch quá 0,5 m so với mặt đất landmark = mái / bục: loại
const CINE_CLUTTER_H: float = 0.15       # mesh nhìn thấy nhô > 0,15 m trên sàn trong hộp sân khấu = vật cản hình ảnh
const CINE_CLUTTER_TOP: float = 2.5      # ... và bắt đầu thấp hơn 2,5 m trên sàn (tán cây cao không tính)
const CINE_GRID_STEP: float = 1.0       # lưới tia sàn ~1 m trong hộp sân khấu (bậc vỉa hè gộp lớn không có đỉnh nào trong hộp)
const CINE_BIG_MESH: float = 30.0        # mesh gộp rộng hơn 30 m: xét từng đỉnh thay cho AABB
const CINE_SEARCH_BUDGET_MS: float = 6.0 # stage search off the baked table (dev, new content): wall-clock cap of the tries
const CINE_CELL: float = 4.0             # XZ grid over the clutter items: a try only tests the items near its box
var cine_player: CinePlayer = null
## The cinematic being prepared ahead (prepare_cinematic): stage resolved, actors built one per frame; null when none.
var cine_prep: CinePrep = null
## Chỗ diễn vừa tìm được (báo cáo / test): landmark, tâm dò, vòng, yaw, sàn, mặt đất landmark, source (baked / cache /
## search), budget_hit.
var cine_stage_info: Dictionary = {}
## _cine_try calls of the last stage resolution (0 = served from the baked table or the cache).
var cine_search_tries: int = 0
var _cine_stage_cache: Dictionary = {}   # CineStage.signature -> [Transform3D, info] (searched spots, this FreeRoam)
var _cine_flat: Variant = null           # first candidate of the running search with a flat floor (budget fallback)
var _cine_saved: Dictionary = {}
var _cine_slot_i: int = -1


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	md = MapData.load_default()
	if md == null:
		push_error("FreeRoam: mapdata.json missing")
		return
	var g: Variant = md.landmark("campus_main_gate")
	if g is Array and (g as Array).size() >= 2:
		gate_xz = Vector2(float(g[0]), float(g[1]))
	campus_xf = FPTUCampusBuilder.real_plot_transform()
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		_base_env = we.environment
	_probe_capsule = CapsuleShape3D.new()
	_probe_capsule.radius = PLAYER_RADIUS
	_probe_capsule.height = PLAYER_HEIGHT
	var sd: Node = get_node_or_null("/root/StoryDirector")
	story_mode = sd != null and bool(sd.get("active"))
	_build_ground()
	_build_regions()
	_build_campus()
	_build_player()
	_build_bike()
	if not story_mode:
		_build_hotspots()   # story mode: the story's markers replace the stage hotspots
	_build_hud()
	build_ms = Time.get_ticks_msec() - t0
	_apply_spawn()
	for k: String in GameFXScript.TOD_PRESETS.keys():
		var tod: Dictionary = GameFXScript.TOD_PRESETS[k]
		if (bool(tod.get("outdoor", false)) and k != "sunset") or k == "night":   # sunset is story-only (A2-D13)
			tod_cycle.append(k)
	set_time_of_day(String(sd.get("tod")) if story_mode else "morning")
	if crowd_enabled:
		_build_pedestrians()
		_build_traffic()
	if mayhem_enabled:
		_build_mayhem()
	if story_mode:
		story_roam = StoryRoam.new()
		add_child(story_roam)
		story_roam.setup(self)
	random_scares = RandomScares.new()
	add_child(random_scares)
	random_scares.setup(self)
	player.camera.make_current()
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("hub_key_blocked", true)
	MusicDirector.warm(["roam_day", "roam_night"])   # both roam tracks load on worker threads (no stall at a switch)
	roam_music()
	print("FreeRoam: world built in %d ms" % build_ms)


func _exit_tree() -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("hub_key_blocked", false)
	if cine_player != null and is_inside_tree():
		get_tree().paused = false   # rời cảnh giữa cinematic: không để cảnh sau bị dừng
	if wanted and wanted.state == "stamp" and is_inside_tree():
		get_tree().paused = false   # rời cảnh giữa dấu "BỊ TÓM!": không để cảnh sau bị dừng
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ===========================================================================
# DỰNG THẾ GIỚI
# ===========================================================================
func _build_ground() -> void:
	var be6: Variant = md.landmark("be6_center")
	var far_pt := Vector2(3910.0, -409.0)
	if be6 is Array and (be6 as Array).size() >= 2:
		far_pt = Vector2(float(be6[0]), float(be6[1]))
	var centre: Vector2 = (far_pt + gate_xz) * 0.5
	var water: Array = MapBuilder._water_polygons(md)
	var pieces: Array = _ground_pieces(centre, GROUND_SIZE * 0.5, water)
	# Mặt cỏ 12 km tại y = -0,05 (dưới mặt đất vùng -0,03, trên mặt nước -0,3) + sàn đi bộ y = 0 từ CÙNG các mảnh đã
	# khoét nước: không che kênh đào / hồ, không ai đứng được trên mặt nước.
	var grass: StandardMaterial3D = (FPTUCampusBuilder.make_materials()["grass"] as StandardMaterial3D).duplicate()
	grass.uv1_triplanar = true
	grass.uv1_scale = Vector3(0.2, 0.2, 0.2)
	grass.albedo_color = Color(0.84, 0.84, 0.68)
	var batch := MapBuilder.Batch.new()
	var faces := PackedVector3Array()
	for piece: PackedVector2Array in pieces:
		MapBuilder._emit_polygon(batch, piece, GROUND_MESH_Y, Vector3.UP, 0.2)
		_append_floor_faces(faces, piece, GROUND_COLLIDER_Y)
	var mi: MeshInstance3D = MapBuilder._commit(batch, grass, "GroundPlane")
	if mi:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
	ground_body = StaticBody3D.new()
	ground_body.name = "Ground"
	var cs := CollisionShape3D.new()
	var floor_shape := ConcavePolygonShape3D.new()
	floor_shape.set_faces(faces)
	cs.shape = floor_shape
	ground_body.add_child(cs)
	world.add_child(ground_body)
	# Sàn dự phòng ở mực nước (Jolt: hộp world_boundary_shape_size = 12 km, project.godot)
	water_floor = StaticBody3D.new()
	water_floor.name = "WaterFloor"
	# 0,2 m dưới mặt nước: khoảng cách tới sàn đi bộ (0,5 m) phải lớn hơn floor_snap_length của người (0,4) và xe (0,45),
	# nếu không khi trượt dọc tường, apply_floor_snap có lúc hút thân xuống WaterFloor 1 frame (tụt 30 cm).
	water_floor.position = Vector3(centre.x, MapBuilder.WATER_Y - WATER_FLOOR_BELOW, centre.y)
	var wcs := CollisionShape3D.new()
	wcs.shape = WorldBoundaryShape3D.new()
	water_floor.add_child(wcs)
	world.add_child(water_floor)
	_build_bank_walls(water)


## Hình vuông 2*half quanh centre chia ô GROUND_TILE, mỗi ô trừ các mặt nước (MapBuilder._subtract).
func _ground_pieces(centre: Vector2, half: float, water: Array) -> Array:
	var pieces: Array = []
	var n: int = int(ceil(half * 2.0 / GROUND_TILE))
	var x0: float = centre.x - half
	var z0: float = centre.y - half
	for i: int in range(n):
		for j: int in range(n):
			var ax: float = x0 + float(i) * GROUND_TILE
			var az: float = z0 + float(j) * GROUND_TILE
			var bx: float = minf(ax + GROUND_TILE, centre.x + half)
			var bz: float = minf(az + GROUND_TILE, centre.y + half)
			var tile := PackedVector2Array([Vector2(ax, az), Vector2(bx, az), Vector2(bx, bz), Vector2(ax, bz)])
			pieces.append_array(MapBuilder._subtract([tile], water))
	return pieces


## Tam giác sàn (mặt trước hướng lên: (b - a) x (c - a) hướng xuống như MapBuilder._tri với want = UP).
static func _append_floor_faces(faces: PackedVector3Array, piece: PackedVector2Array, y: float) -> void:
	var p: PackedVector2Array = MapBuilder._open(piece)
	if p.size() < 3:
		return
	var idx: PackedInt32Array = MapBuilder._triangulate(p)
	for k: int in range(0, idx.size() - 2, 3):
		var a := Vector3(p[idx[k]].x, y, p[idx[k]].y)
		var b := Vector3(p[idx[k + 1]].x, y, p[idx[k + 1]].y)
		var c := Vector3(p[idx[k + 2]].x, y, p[idx[k + 2]].y)
		if (b - a).cross(c - a).y > 0.0:
			var t: Vector3 = b
			b = c
			c = t
		faces.append(a)
		faces.append(b)
		faces.append(c)


## Tường vô hình quanh mặt nước (một StaticBody3D "BankWalls", ConcavePolygonShape3D va chạm hai mặt):
##   1) Tường bờ cao BANK_WALL_H dọc mép mọi mặt nước, khoét đúng phần nằm dưới ribbon của một con đường / lối đi bộ
##      có mặt thấp hơn đỉnh tường (BANK_GAP_DECK_MAX): khe kết thúc ĐÚNG ở mép ribbon. Dưới cầu cao (mặt cầu trên
##      đỉnh tường) tường bờ chạy liền, nên không thể đi từ bờ xuống nước dưới gầm cầu.
##   2) Lan can vô hình dọc hai mép ribbon ở mọi đoạn nằm trên mặt nước có mặt thấp (< ROAD_Y + DECK_GUARD_MAX_H:
##      lối đi bộ, đường thường qua cống, đầu cầu thấp chưa có lan can BridgeParts), từ dưới mặt nước tới mặt đường
##      + DECK_GUARD_ABOVE. Cùng hình ribbon với 1) nên góc tường bờ / lan can khép kín.
func _build_bank_walls(water: Array) -> void:
	var rings: Array = []
	var rects: Array = []
	for poly: PackedVector2Array in water:
		var ring: PackedVector2Array = MapBuilder._open(poly)
		rings.append(ring)
		var bb := Rect2(ring[0], Vector2.ZERO) if ring.size() > 0 else Rect2()
		for p: Vector2 in ring:
			bb = bb.expand(p)
		rects.append(bb.grow(1.0))
	var ribbons: Array = _ribbons_near_water(rects)
	var cells: Dictionary = {}   # Vector2i (ô ROAD_HASH_CELL m) -> Array[int] chỉ số ribbon
	for id: int in range(ribbons.size()):
		var rb_box: Rect2 = ribbons[id][3]
		for cell: Vector2i in _cells_of(rb_box.position, rb_box.end, 0.0):
			if not cells.has(cell):
				cells[cell] = []
			(cells[cell] as Array).append(id)
	var faces := PackedVector3Array()
	var y_bot: float = MapBuilder.WATER_Y - WALL_BOTTOM_BELOW_WATER
	var y_bank: float = GROUND_COLLIDER_Y + BANK_WALL_H
	# 1) tường bờ trừ phần dưới ribbon mặt thấp
	for wi: int in range(rings.size()):
		var ring: PackedVector2Array = rings[wi]
		var n: int = ring.size()
		if n < 3:
			continue
		for i: int in range(n):
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % n]
			if a.distance_squared_to(b) < 1e-4:
				continue
			var pieces: Array = [PackedVector2Array([a, b])]
			var edge_box: Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(0.05)
			var seen: Dictionary = {}
			for cell: Vector2i in _cells_of(a, b, 0.0):
				for id: int in cells.get(cell, []):
					if seen.has(id):
						continue
					seen[id] = true
					var rb: Array = ribbons[id]
					if minf(float(rb[1]), float(rb[2])) >= BANK_GAP_DECK_MAX or not (rb[3] as Rect2).intersects(edge_box):
						continue
					var next: Array = []
					for pc: PackedVector2Array in pieces:
						next.append_array(Geometry2D.clip_polyline_with_polygon(pc, rb[0]))
					pieces = next
			for pc: PackedVector2Array in pieces:
				for k: int in range(pc.size() - 1):
					_wall_quad(faces, pc[k], pc[k + 1], y_bot, y_bank, y_bank)
	# 2) lan can vô hình dọc mép ribbon mặt thấp trên mặt nước
	var low_y: float = MapBuilder.ROAD_Y + DECK_GUARD_MAX_H
	for rb: Array in ribbons:
		var ya: float = rb[1]
		var yb: float = rb[2]
		if minf(ya, yb) >= low_y:
			continue
		var q: PackedVector2Array = rb[0]
		for wi: int in range(rings.size()):
			if (rings[wi] as PackedVector2Array).size() < 3 or not (rects[wi] as Rect2).intersects(rb[3]):
				continue
			for side: Array in [[q[0], q[1]], [q[3], q[2]]]:
				var s0: Vector2 = side[0]
				var s1: Vector2 = side[1]
				for part: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([s0, s1]), rings[wi]):
					for k: int in range(part.size() - 1):
						var y0: float = lerpf(ya, yb, _param_on(s0, s1, part[k]))
						var y1: float = lerpf(ya, yb, _param_on(s0, s1, part[k + 1]))
						if minf(y0, y1) >= low_y:
							continue
						_wall_quad(faces, part[k], part[k + 1], y_bot, y0 + DECK_GUARD_ABOVE, y1 + DECK_GUARD_ABOVE)
	if faces.is_empty():
		return
	bank_walls = StaticBody3D.new()
	bank_walls.name = "BankWalls"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	bank_walls.add_child(cs)
	world.add_child(bank_walls)


## Ribbon của mọi con đường / lối đi bộ có hộp bao chạm hộp bao một mặt nước, đúng hình MapBuilder._build_roads vẽ
## (resample + profile cầu cho đường, FOOTWAY_Y cho lối đi bộ, mitre như _emit_ribbon). Mỗi đoạn:
## [PackedVector2Array quad (trái a, trái c, phải c, phải a), float mặt tại a, float mặt tại c, Rect2 hộp bao].
func _ribbons_near_water(water_rects: Array) -> Array:
	var out: Array = []
	for r: Dictionary in md.roads():
		var pts2: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts2.size() < 2:
			continue
		var w: float = float(r.get("width", 6.0))
		var footway: bool = int(r.get("lanes", 2)) <= 0
		if footway:
			w = clampf(w, 1.5, 2.5)
		var road_box := Rect2(pts2[0], Vector2.ZERO)
		for p: Vector2 in pts2:
			road_box = road_box.expand(p)
		road_box = road_box.grow(w)
		var near: bool = false
		for wr: Rect2 in water_rects:
			if wr.intersects(road_box):
				near = true
				break
		if not near:
			continue
		var pts3 := PackedVector3Array()
		if footway:
			for p: Vector2 in MapBuilder._resample(pts2, MapBuilder.FOOTWAY_STEP_M):
				pts3.append(Vector3(p.x, MapBuilder.FOOTWAY_Y, p.y))
		else:
			pts3 = MapBuilder._road_profile(pts2, bool(r.get("bridge", false)), MapBuilder.ROAD_Y)
		var offs: PackedVector2Array = MapBuilder._mitre_offsets(pts3)
		var half: float = w * 0.5
		for i: int in range(pts3.size() - 1):
			var a := Vector2(pts3[i].x, pts3[i].z)
			var c := Vector2(pts3[i + 1].x, pts3[i + 1].z)
			if a.distance_squared_to(c) < 1e-6:
				continue
			var la: Vector2 = a + offs[i] * half
			var ra: Vector2 = a - offs[i] * half
			var lc: Vector2 = c + offs[i + 1] * half
			var rc: Vector2 = c - offs[i + 1] * half
			var box: Rect2 = Rect2(la, Vector2.ZERO).expand(lc).expand(rc).expand(ra)
			out.append([PackedVector2Array([la, lc, rc, ra]), pts3[i].y, pts3[i + 1].y, box])
	return out


## Tham số [0, 1] của hình chiếu p lên đoạn s0 -> s1.
static func _param_on(s0: Vector2, s1: Vector2, p: Vector2) -> float:
	var d: Vector2 = s1 - s0
	var l2: float = d.length_squared()
	return clampf((p - s0).dot(d) / l2, 0.0, 1.0) if l2 > 1e-9 else 0.0


## Một quad đứng p0 -> p1 từ y_bot lên y_top0 (tại p0) / y_top1 (tại p1), bỏ mẩu < 2 cm.
static func _wall_quad(faces: PackedVector3Array, p0: Vector2, p1: Vector2, y_bot: float, y_top0: float, y_top1: float) -> void:
	if p0.distance_squared_to(p1) < 0.0004:
		return
	var v0 := Vector3(p0.x, y_bot, p0.y)
	var v1 := Vector3(p1.x, y_bot, p1.y)
	var v2 := Vector3(p1.x, y_top1, p1.y)
	var v3 := Vector3(p0.x, y_top0, p0.y)
	faces.append_array(PackedVector3Array([v0, v1, v2, v0, v2, v3]))


static func _cells_of(a: Vector2, b: Vector2, grow: float) -> Array:
	var lo := Vector2(minf(a.x, b.x) - grow, minf(a.y, b.y) - grow)
	var hi := Vector2(maxf(a.x, b.x) + grow, maxf(a.y, b.y) + grow)
	var out: Array = []
	for cx: int in range(int(floor(lo.x / ROAD_HASH_CELL)), int(floor(hi.x / ROAD_HASH_CELL)) + 1):
		for cz: int in range(int(floor(lo.y / ROAD_HASH_CELL)), int(floor(hi.y / ROAD_HASH_CELL)) + 1):
			out.append(Vector2i(cx, cz))
	return out


func _build_regions() -> void:
	var common: Dictionary = {"skip_building_ids": SKIP_BUILDING_IDS, "skip_area_ids": SKIP_AREA_IDS, "palms": GameFXScript._art_style() == "vice", "palm_colliders": true}
	MapBuilder.build_region(world, md, "vinhomes", common)
	var cor: Dictionary = common.duplicate()
	cor["lod"] = 1
	MapBuilder.build_region(world, md, "corridor", cor)
	var campus: Node3D = MapBuilder.build_region(world, md, "campus", common)
	var plot: PackedVector2Array = MapData.poly(md.landmark("campus_plot"))
	if plot.size() >= 3:
		_cull_region_inside_plot(campus, plot)


## OSM có đường nội bộ + 4 cầu thang trong lô FPT; FPTUCampusBuilder đã dựng sân/đường riêng ở đó nên các tam giác
## đường/vạch/vỉa hè/bó vỉa của vùng campus có trọng tâm nằm trong lô bị cắt bỏ (collider dựng lại theo mesh mới).
func _cull_region_inside_plot(region_root: Node3D, plot: PackedVector2Array) -> void:
	for child: Node in region_root.get_children():
		var n: String = child.name
		if not (n.begins_with("Roads_") or n == "RoadLines" or n == "Footways" or n == "Kerbs"):
			continue
		if child is MeshInstance3D:
			_cull_mesh_inside(child as MeshInstance3D, plot)


func _cull_mesh_inside(mi: MeshInstance3D, plot: PackedVector2Array) -> void:
	var src: ArrayMesh = mi.mesh as ArrayMesh
	if src == null:
		return
	var dst := ArrayMesh.new()
	var removed: int = 0
	for s: int in range(src.get_surface_count()):
		var arr: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx_v: Variant = arr[Mesh.ARRAY_INDEX]
		var idx := PackedInt32Array()
		if idx_v is PackedInt32Array and (idx_v as PackedInt32Array).size() > 0:
			idx = idx_v
		else:
			idx.resize(verts.size())
			for i: int in range(verts.size()):
				idx[i] = i
		var keep := PackedInt32Array()
		for t: int in range(idx.size() / 3):
			var a: Vector3 = verts[idx[t * 3]]
			var b: Vector3 = verts[idx[t * 3 + 1]]
			var c: Vector3 = verts[idx[t * 3 + 2]]
			if Geometry2D.is_point_in_polygon(Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0), plot):
				removed += 1
				continue
			keep.append(idx[t * 3])
			keep.append(idx[t * 3 + 1])
			keep.append(idx[t * 3 + 2])
		if keep.is_empty():
			continue
		arr[Mesh.ARRAY_INDEX] = keep
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		dst.surface_set_material(dst.get_surface_count() - 1, src.surface_get_material(s))
	if removed == 0:
		return
	var had_body: bool = false
	for c: Node in mi.get_children():
		if c is StaticBody3D:
			had_body = true
			mi.remove_child(c)
			c.free()
	if dst.get_surface_count() == 0:
		mi.mesh = null
		mi.visible = false
		return
	mi.mesh = dst
	if had_body:
		var shape: ConcavePolygonShape3D = dst.create_trimesh_shape()
		if shape:
			var sb := StaticBody3D.new()
			sb.name = "Col"
			var cs := CollisionShape3D.new()
			cs.shape = shape
			sb.add_child(cs)
			mi.add_child(sb)


func _build_campus() -> void:
	FPTUCampusBuilder.build_authentic_campus(world, campus_xf.origin, FPTUCampusBuilder.REAL_ROT_Y_DEG, {"colliders": true, "grass": true, "walk_colliders": true, "palms": GameFXScript._art_style() == "vice", "d1_palms": false})
	var frame := Node3D.new()
	frame.name = "CampusFrame"
	frame.transform = campus_xf
	world.add_child(frame)
	FPTUCampusBuilder.build_hutech(frame, FPTUCampusBuilder.hutech_origin_local(), FPTUCampusBuilder.make_materials(), true, false)


func _build_player() -> void:
	player = ThirdPersonController.new()
	player.name = "Player"
	if story_mode:
		player.character_opts = StoryUtil.director().call("protagonist_opts")   # the creator's protagonist (A2-D5)
	add_child(player)
	if bank_walls and player.cam_ray:
		player.cam_ray.add_exception(bank_walls)   # tường vô hình không kéo camera vào sát người


func _build_bike() -> void:
	bike = BIKE_SCENE.instantiate() as PlayerBike
	bike.name = "Bike"
	bike.road_path = null
	bike.lane_clamp_enabled = false
	bike.fallback_fall_y = -5.0
	bike.apply_speed_profile(PlayerBike.OWNER_PROFILE)   # owner's bike: 120 km/h in free roam and story roam (OB-D2)
	# xe đang đỗ (PROCESS_MODE_DISABLED) vẫn là vật cản: không bị gỡ khỏi không gian vật lý
	bike.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	add_child(bike)
	if bank_walls and bike.spring_arm:
		bike.spring_arm.add_excluded_object(bank_walls.get_rid())
	bike.chase_cam.current = false
	bike.visible = false
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	bike.global_position = Vector3(0.0, -50.0, 0.0)


## Đám đông ba tầng (spec vice-people-and-movement, Phần 3 + Amendment): tránh cột sáng hotspot và điểm spawn.
func _build_pedestrians() -> void:
	pedestrians = PedestrianSpawner.new()
	pedestrians.name = "Pedestrians"
	add_child(pedestrians)
	var avoid: Array = [spawn_xf.origin]
	for h: Area3D in hotspots:
		avoid.append(h.global_position)
	pedestrians.setup(md, player, {"bike": bike, "roam": self, "avoid": avoid})
	if bike:
		bike.horn_targets_fn = pedestrians.pedestrians   # the horn melody's dancing crowd (OB-D4)


## Xe chạy (spec vice-people-and-movement, Amendment 2026-10-22): làn bên phải, dừng trước người / xe; camera đi xuyên xe.
func _build_traffic() -> void:
	traffic = RoamTraffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	var opts: Dictionary = {"bike": bike, "roam": self}
	if pedestrians:
		opts["peds_fn"] = pedestrians.pedestrians
	traffic.setup(md, player, opts)
	if pedestrians:
		traffic.fleer_fn = pedestrians.spawn_fleer   # Phase W: the rider of a shot / flipped vehicle runs away
	for b: Variant in traffic.bodies():
		var body: CollisionObject3D = b
		if player and player.cam_ray:
			player.cam_ray.add_exception(body)
		if bike and bike.spring_arm:
			bike.spring_arm.add_excluded_object(body.get_rid())


func _apply_spawn() -> void:
	var default_xf: Transform3D = md.spawn_transform()
	spawn_xf = default_xf
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		var rs: Variant = sm.get("roam_spawn")
		if rs is Transform3D:
			spawn_xf = rs
		sm.set("roam_spawn", null)
	var spot: Variant = find_free_spot(spawn_xf.origin, spawn_xf.origin.y, SPAWN_SEARCH_M)
	if spot == null and spawn_xf != default_xf:
		spawn_xf = default_xf
		spot = find_free_spot(spawn_xf.origin, spawn_xf.origin.y, SPAWN_SEARCH_M)
	if spot is Vector3:
		spawn_xf.origin = spot
	player.teleport(spawn_xf.origin, spawn_xf.basis.get_euler().y)
	bike.fallback_respawn = spawn_xf.origin + Vector3(0.0, 0.8, 0.0)


# ===========================================================================
# CHỖ ĐỨNG TRỐNG (spawn, điểm quay về của hotspot, xuống xe)
# ===========================================================================
## Mặt sàn đứng được tại (p.x, p.z) quanh độ cao base_y: tia từ base_y + FLOOR_PROBE_UP xuống base_y - FLOOR_PROBE_DOWN
## phải chạm sàn hướng lên, cao hơn mực nước (không phải WaterFloor), và capsule người chơi (r 0,4, cao 1,7, tâm +0,85)
## đặt trên đó không chạm vật nào (probe: capsule khác, vd. cỡ người đi đường của PedestrianSpawner). Trả về điểm sàn
## (Vector3) hoặc null.
func free_spot_at(p: Vector3, base_y: float, exclude: Array[RID] = [], probe: CapsuleShape3D = null) -> Variant:
	if not is_inside_tree():
		return null
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var excl: Array[RID] = exclude.duplicate()
	if player:
		excl.append(player.get_rid())
	var rq := PhysicsRayQueryParameters3D.create(Vector3(p.x, base_y + FLOOR_PROBE_UP, p.z), Vector3(p.x, base_y - FLOOR_PROBE_DOWN, p.z))
	rq.exclude = excl
	rq.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(rq)
	if hit.is_empty():
		return null
	if (hit["normal"] as Vector3).y < 0.7:
		return null
	var fy: float = (hit["position"] as Vector3).y
	if fy < MapBuilder.WATER_Y + 0.12 or hit.get("collider") == water_floor:
		return null
	var cap: CapsuleShape3D = probe if probe != null else _probe_capsule
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, fy + SPOT_LIFT + cap.height * 0.5, p.z))
	q.exclude = excl
	q.collide_with_areas = false
	if not space.intersect_shape(q, 1).is_empty():
		return null
	return Vector3(p.x, fy, p.z)


## Chỗ trống gần `centre` nhất: chính nó, rồi các vòng 1 m, 2 m ... max_r m (mỗi vòng ~1 m một điểm). null nếu không có.
func find_free_spot(centre: Vector3, base_y: float, max_r: int, exclude: Array[RID] = []) -> Variant:
	var s: Variant = free_spot_at(centre, base_y, exclude)
	if s != null:
		return s
	for r: int in range(1, max_r + 1):
		var n: int = maxi(8, int(ceil(TAU * float(r))))
		for k: int in range(n):
			var ang: float = TAU * float(k) / float(n)
			s = free_spot_at(centre + Vector3(cos(ang) * float(r), 0.0, sin(ang) * float(r)), base_y, exclude)
			if s != null:
				return s
	return null


# ===========================================================================
# HOTSPOT
# ===========================================================================
func _build_hotspots() -> void:
	var ids: Dictionary = StageManagerScript.StageID
	var sp: Transform3D = md.spawn_transform()
	var sp_fwd: Vector3 = -sp.basis.z
	var sp_right: Vector3 = sp.basis.x
	var be6_plaza: Vector3 = sp.origin + sp_fwd * 7.0 + sp_right * 3.0
	var ring_c: Rect2 = FPTUCampusBuilder.ring_courtyard_rect()
	var court_c := Vector3(ring_c.get_center().x, 0.0, ring_c.get_center().y)
	var ring_centre: Vector3 = campus_xf * court_c
	# Mọi điểm hotspot campus ở MẶT ĐẤT, ngoài khối tầng trệt (hệ cục bộ u, 0, v):
	#   Lab 402 / Màn 6: cửa kính sảnh thông tầng cánh phải (cầu thang lên lầu 4 ở trong), lùi ATRIUM_PUSH_M vào sân trong.
	var atrium: Vector3 = FPTUCampusBuilder.atrium_door_local()
	atrium += (court_c - atrium).normalized() * ATRIUM_PUSH_M
	#   Màn 4: đầu sân bóng quay về làn bãi xe (phía tâm vòng nhà), ngoài hàng rào kính 2,5 m. Hướng -v ("về phía sân
	#   trong") thì đụng lưng cánh trái (vòng nhà kết thúc ở v 93, rào sân bóng ở v 93,5) nên đặt ở đầu +u của sân.
	var pitch: Vector3 = FPTUCampusBuilder.pitch_center_local() + Vector3(FPTUCampusBuilder.PITCH_LEN * 0.5 + 2.5, 0.0, 0.0)
	#   Extra: mặt sân trong của module cánh trước chứa phòng 311 (khối tầng trệt kết thúc ở v 27,8; hiên tới v 30).
	var r311: Vector3 = FPTUCampusBuilder.room311_center()
	var room311 := Vector3(r311.x, 0.0, ring_c.position.y + 1.5)
	var defs: Array = [
		[ids.STAGE_1_RACE, be6_plaza, sp.origin, -1],
		[ids.STAGE_2_PARKING, campus_xf * FPTUCampusBuilder.back_gate_local(), ring_centre, -1],
		[ids.STAGE_3_CLASSROOM, campus_xf * atrium, ring_centre, ids.STAGE_6_CAPSTONE],
		[ids.STAGE_4_VOVINAM, campus_xf * pitch, ring_centre, -1],
		[ids.STAGE_5_CANTEEN, campus_xf * FPTUCampusBuilder.canteen_center(), ring_centre, -1],
		[ids.STAGE_EXTRA_EOS, campus_xf * room311, ring_centre, -1],
	]
	var holder := Node3D.new()
	holder.name = "Hotspots"
	add_child(holder)
	for d: Array in defs:
		var h: Area3D = _make_hotspot(holder, int(d[0]), d[1], d[2], int(d[3]))
		hotspots.append(h)
		if int(d[3]) >= 0:
			_lab_hotspot = h


func _make_hotspot(parent: Node3D, stage_id: int, pos: Vector3, anchor: Vector3, night_stage: int) -> Area3D:
	var a := Area3D.new()
	a.name = "Hotspot_" + String(StageManagerScript.StageID.find_key(stage_id))
	a.position = pos
	a.monitoring = true
	a.monitorable = true
	a.set_meta("stage_id", stage_id)
	a.set_meta("day_stage", stage_id)
	a.set_meta("night_stage", night_stage)
	# Điểm spawn khi quay về: RETURN_SPAWN_M từ điểm mặt đất của hotspot về phía mốc (spawn BE6 / tâm sân trong),
	# kiểm chỗ trống bằng capsule (dò vòng ra ngoài nếu vướng), quay mặt vào hotspot.
	var away: Vector3 = anchor - pos
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.001 else Vector3(0.0, 0.0, 1.0)
	var back: Vector3 = pos + away * RETURN_SPAWN_M
	var spot: Variant = find_free_spot(back, back.y, SPAWN_SEARCH_M)
	if spot is Vector3:
		back = spot
	var face: Vector3 = back - pos
	face.y = 0.0
	if face.length_squared() < 0.01:
		face = away
	a.set_meta("return_spawn", Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)), back))
	parent.add_child(a)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = HOTSPOT_RADIUS
	cyl.height = 4.0
	cs.shape = cyl
	cs.position = Vector3(0.0, 2.0, 0.0)
	a.add_child(cs)
	var col: Color = HOTSPOT_COLORS.get(stage_id, Color("#F37021"))
	var pillar := MeshInstance3D.new()
	pillar.name = "Pillar"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.7
	pm.bottom_radius = 1.1
	pm.height = 5.0
	pillar.mesh = pm
	pillar.position = Vector3(0.0, 2.5, 0.0)
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.material_override = _glow_material(col, 0.3)
	a.add_child(pillar)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var rm := CylinderMesh.new()
	rm.top_radius = HOTSPOT_RADIUS
	rm.bottom_radius = HOTSPOT_RADIUS
	rm.height = 0.06
	ring.mesh = rm
	ring.position = Vector3(0.0, 0.16, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _glow_material(col, 0.55)
	a.add_child(ring)
	var l := Label3D.new()
	l.name = "Title"
	l.text = _short_title(stage_id)
	l.font_size = 44
	l.pixel_size = 0.011
	l.outline_size = 12
	l.modulate = Color(1.0, 0.98, 0.9)
	l.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0.0, 5.7, 0.0)
	a.add_child(l)
	var key := Label3D.new()
	key.name = "Key"
	key.text = "[E]"
	key.font_size = 64
	key.pixel_size = 0.011
	key.outline_size = 14
	key.modulate = col
	key.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	key.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	key.position = Vector3(0.0, 6.5, 0.0)
	a.add_child(key)
	return a


func _glow_material(col: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


func _stage_title(stage_id: int) -> String:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		var info: Variant = sm.get("stage_info")
		if info is Dictionary and (info as Dictionary).has(stage_id):
			return String((info as Dictionary)[stage_id].get("title", ""))
	return "Màn %d" % stage_id


func _short_title(stage_id: int) -> String:
	var full: String = _stage_title(stage_id)
	return full.get_slice("] ", 1) if full.contains("] ") else full


## Đổi nhãn + id màn của hotspot Lab 402 theo ngày/đêm (Màn 3 ban ngày, Màn 6 ban đêm).
func _refresh_lab_hotspot() -> void:
	if _lab_hotspot == null:
		return
	var sid: int = int(_lab_hotspot.get_meta("night_stage")) if tod_preset == "night" else int(_lab_hotspot.get_meta("day_stage"))
	_lab_hotspot.set_meta("stage_id", sid)
	_lab_hotspot.name = "Hotspot_" + String(StageManagerScript.StageID.find_key(sid))
	var title: Label3D = _lab_hotspot.get_node_or_null("Title") as Label3D
	if title:
		title.text = _short_title(sid)
	var col: Color = HOTSPOT_COLORS.get(sid, Color("#F37021"))
	for pair: Array in [["Pillar", 0.3], ["Ring", 0.55]]:
		var mi: MeshInstance3D = _lab_hotspot.get_node_or_null(String(pair[0])) as MeshInstance3D
		if mi:
			# Đổi màu vật liệu sẵn có (đã qua upgrade_scene_visuals) thay vì gán vật liệu mới chưa chuyển kiểu.
			var gm: StandardMaterial3D = mi.material_override as StandardMaterial3D
			if gm:
				gm.albedo_color = Color(col.r, col.g, col.b, float(pair[1]))
				gm.emission = col
			else:
				mi.material_override = _glow_material(col, float(pair[1]))
	var key: Label3D = _lab_hotspot.get_node_or_null("Key") as Label3D
	if key:
		key.modulate = col
	_sync_map_hotspots()


func _update_hotspot() -> void:
	var found: Area3D = null
	if not mounted and player:
		for h: Area3D in hotspots:
			if h.overlaps_body(player):
				found = h
				break
	active_hotspot = found


## [E] trong hotspot: vào màn qua StageManager (return_to_roam = true, roam_spawn cạnh hotspot).
func start_hotspot_stage(h: Area3D) -> bool:
	if h == null:
		return false
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm == null or not sm.has_method("start_stage_from_roam"):
		return false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sm.call("start_stage_from_roam", int(h.get_meta("stage_id")), h.get_meta("return_spawn"))
	return true


# ===========================================================================
# XE MÁY
# ===========================================================================
func roam_position() -> Vector3:
	return bike.global_position if mounted else player.global_position


## Khoảng cách ngang (m, làm tròn) từ người chơi tới xe đang đỗ.
func bike_distance_m() -> int:
	var d := Vector2(player.global_position.x - bike.global_position.x, player.global_position.z - bike.global_position.z)
	return int(round(d.length()))


func can_mount() -> bool:
	if mounted or player == null:
		return false
	if not bike_parked:
		return true
	return player.global_position.distance_to(bike.global_position) <= MOUNT_RANGE


func mount_bike() -> void:
	if mounted:
		return
	if not can_mount():
		if bike_parked and player:
			flash_hint("Xe máy đang đỗ cách %d m – lại gần xe rồi bấm [F]" % bike_distance_m())
		return
	mounted = true
	var pos: Vector3 = bike.global_position if bike_parked else player.global_position
	var yaw: float = bike.rotation.y if bike_parked else player.facing_yaw()
	bike.process_mode = Node.PROCESS_MODE_INHERIT
	bike.visible = true
	# đặt xe đúng độ cao nghỉ (gốc dưới sàn BIKE_FLOOR_OFFSET; xe đỗ đã nằm sẵn ở đó): thả từ cao 0,25 m thì floor snap của xe
	# có chỗ lún qua sàn ConcavePolygon xuống WaterFloor, rồi không xuống xe được
	bike.global_position = pos if bike_parked else pos - Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0)
	bike.rotation = Vector3(0.0, yaw, 0.0)
	bike.velocity = Vector3.ZERO
	bike.current_speed_ms = 0.0
	bike.fallback_respawn = pos + Vector3(0.0, 0.8, 0.0)
	bike.chase_cam.make_current()
	player.controls_enabled = false
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	active_hotspot = null
	if vice_hud:
		vice_hud.show_vehicle("Xe máy")
	roam_music()


## Chỗ xuống xe: bên phải rồi bên trái xe, cách DISMOUNT_OFFSETS m; phải có sàn (không phải mặt nước) và capsule
## người chơi không chạm gì (tường bờ kênh, nhà, xe...). null = không có chỗ.
func _dismount_spot() -> Variant:
	var side: Vector3 = bike.global_transform.basis.x
	side.y = 0.0
	side = side.normalized() if side.length_squared() > 0.001 else Vector3(1.0, 0.0, 0.0)
	var base: Vector3 = bike.global_position + Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0)
	for dist: float in DISMOUNT_OFFSETS:
		for s: float in [1.0, -1.0]:
			var spot: Variant = free_spot_at(base + side * (s * dist), base.y)
			if spot != null:
				return spot
	return null


## Xuống xe vào chỗ trống cạnh xe; không có chỗ (vd. sát bờ kênh cả hai bên) thì ở lại trên xe + báo gợi ý.
func dismount_bike() -> bool:
	if not mounted:
		return false
	var spot: Variant = _dismount_spot()
	if spot == null:
		flash_hint(HINT_NO_DISMOUNT)
		return false
	mounted = false
	bike_parked = true
	bike.current_speed_ms = 0.0
	bike.velocity = Vector3.ZERO
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.controls_enabled = true
	player.teleport(spot, bike.rotation.y)
	player.camera.make_current()
	if vice_hud:
		vice_hud.hide_vehicle()
	roam_music()
	return true


func toggle_bike() -> void:
	if wanted and wanted.state != "free":
		flash_hint(HINT_SERVICE_BIKE)   # Phase W: không lấy xe khi đang bị bắt / lao động công ích
		return
	if not mounted and combat and combat.fight_active:
		flash_hint(CombatData.T_FIGHT_BIKE)   # Phase B: no bike in the middle of a fight (MeleeFight)
		return
	if not mounted and story_mission_active():
		flash_hint(StoryRoam.ON_FOOT_HINT)   # Phase B story missions are on foot
		return
	if mounted and dismount_refusal != "":
		flash_hint(dismount_refusal)   # Phase C: no getting off mid-chase (BikeChase)
		return
	if mounted:
		dismount_bike()
	else:
		mount_bike()


## Phase W, after community service (spec section 5): put the player on a free spot beside the parked bike (if parked).
func place_beside_bike() -> bool:
	if mounted or not bike_parked:
		return false
	var spot: Variant = _dismount_spot()
	if spot == null:
		return false
	player.teleport(spot, bike.rotation.y)
	return true


# ===========================================================================
# LƯỚI AN TOÀN DƯỚI KÊNH
# ===========================================================================
## Cao độ chân của thân đang điều khiển (người chơi; khi cưỡi xe: mặt sàn dưới bánh = gốc xe + BIKE_FLOOR_OFFSET).
func _active_floor_y() -> float:
	if mounted:
		return bike.global_position.y + BIKE_FLOOR_OFFSET
	return player.global_position.y


func is_wet() -> bool:
	return _active_floor_y() < MapBuilder.WATER_Y + WET_MARGIN


## Mỗi frame vật lý: chân ở dưới mức sàn đất (đang đứng trên sàn mực nước) quá RESCUE_AFTER_S giây -> rescue;
## còn khô, chạm sàn và tia ngắn xuống dưới chân trúng sàn khô (không phải WaterFloor) thì nhớ chỗ đó.
func _watch_water(delta: float) -> void:
	if is_wet():
		_wet_t += delta
		if _wet_t >= RESCUE_AFTER_S:
			rescue_from_water()
		return
	_wet_t = 0.0
	var body: CharacterBody3D = bike if mounted else player
	if not body.is_on_floor() or not is_inside_tree():
		return
	var fy: float = _active_floor_y()
	var p: Vector3 = body.global_position
	var rq := PhysicsRayQueryParameters3D.create(Vector3(p.x, fy + 0.3, p.z), Vector3(p.x, fy - 0.3, p.z))
	rq.exclude = [player.get_rid(), bike.get_rid()]
	rq.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
	if hit.is_empty() or hit.get("collider") == water_floor:
		return
	_last_dry = Vector3(p.x, (hit["position"] as Vector3).y, p.z)
	_has_dry = true


## Đưa người chơi (hoặc xe đang cưỡi) từ dưới kênh về chỗ trống gần chỗ khô cuối cùng, không có thì về spawn.
func rescue_from_water() -> void:
	_wet_t = 0.0
	var excl: Array[RID] = []
	if mounted:
		excl.append(bike.get_rid())
	var target: Variant = null
	if _has_dry:
		target = find_free_spot(_last_dry, _last_dry.y, SPAWN_SEARCH_M, excl)
	if target == null:
		target = find_free_spot(spawn_xf.origin, spawn_xf.origin.y, SPAWN_SEARCH_M, excl)
	var pos: Vector3 = target if target is Vector3 else spawn_xf.origin
	if mounted:
		bike.global_position = pos - Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0)   # độ cao nghỉ, như mount_bike
		bike.velocity = Vector3.ZERO
		bike.current_speed_ms = 0.0
		bike.fallback_respawn = pos + Vector3(0.0, 0.8, 0.0)
	else:
		player.teleport(pos, player.facing_yaw())
	rescues += 1
	flash_hint(HINT_RESCUED)


# ===========================================================================
# GIỜ TRONG NGÀY / BẢN ĐỒ / HUD
# ===========================================================================
## Đổi preset ánh sáng chỉ khi preset thật sự đổi. Luôn trả Environment gốc của cảnh về WorldEnvironment trước
## (GameFX.upgrade_scene_visuals nhân bản Environment hiện tại: không làm vậy thì ánh sáng môi trường đêm còn dính
## sang các preset ban ngày khi bấm [T] vòng qua đêm).
func set_time_of_day(preset: String) -> void:
	var key: String = String(GameFXScript.TOD_ALIASES.get(preset, preset))
	if not GameFXScript.TOD_PRESETS.has(key):
		return
	if key == tod_preset:
		return
	tod_preset = key
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and _base_env:
		we.environment = _base_env
	GameFXScript.upgrade_scene_visuals(self, key)
	if traffic: traffic.set_night_lamps(RoamTraffic.is_dark_preset(key))   # OB-D6 traffic lamps
	_refresh_lab_hotspot()
	if bike:
		bike.set_time_of_day(key)   # headlight / haze / strobe glow at dark presets (OB-D5)
	if tod_label:
		tod_label.text = "%s · [T] đổi giờ" % String(TOD_NAMES.get(key, key))
	if vice_hud:
		# giờ của ViceHUD = phần "HH:MM" cuối tên preset ("Buổi sáng 07:30" -> "07:30")
		var tod_name: String = String(TOD_NAMES.get(key, ""))
		vice_hud.set_clock(tod_name.right(5) if tod_name.length() >= 5 else "")
	# đang phát nhạc thế giới mở thì đổi theo giờ (roam_day <-> roam_night); nhạc nhiệm vụ / cinematic thì để yên
	var md: Node = _music_director()
	if md and float(md.get("target_gain")) > 0.0 and String(md.get("slot")).begins_with("roam_"):
		roam_music()


## Nhạc thế giới mở (spec H-D8): file của chủ game roam_day / roam_night theo giờ (đêm = roam_night, còn lại kể cả hoàng
## hôn = roam_day), đi bộ hay chạy xe cùng một bài (trên xe tension cao hơn: to và sáng hơn). Không có file = im lặng.
func roam_music() -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_play"):
		fx.call("music_play", MusicDirector.roam_slot(tod_preset), 0.3 if mounted else 0.15)


func _music_director() -> Node:
	var fx: Node = get_node_or_null("/root/GameFX")
	return fx.get("music") if fx else null


func cycle_time_of_day() -> void:
	if tod_cycle.is_empty():
		return
	var i: int = tod_cycle.find(tod_preset)
	set_time_of_day(tod_cycle[(i + 1) % tod_cycle.size()])


## [M]: hiện / ẩn bản đồ. Lần mở đầu tiên RoamMap gửi lớp tĩnh (mesh nhà/đường/nước dựng sẵn trong setup); các lần
## sau chỉ lớp động được vẽ lại.
func toggle_map() -> void:
	if map_overlay == null:
		return
	map_overlay.visible = not map_overlay.visible
	if hint_holder:
		hint_holder.visible = not map_overlay.visible   # bản đồ có tiêu đề + chú giải riêng
	if vice_hud:
		vice_hud.suppressed = map_overlay.visible        # bản đồ phủ cả radar / cột giờ - ví
	if wanted:
		wanted.hud_hidden = map_overlay.visible          # Phase W: the classic star row too
		wanted.refresh_hud()
	if map_overlay.visible:
		_hud_timer = HUD_REFRESH
		_update_map_dynamic()


## Lớp động của bản đồ: vị trí + hướng người chơi (hoặc xe đang cưỡi), xe đang đỗ. Gọi theo nhịp HUD khi bản đồ mở.
func _update_map_dynamic() -> void:
	var pos: Vector3 = roam_position()
	var fwd: Vector3 = -bike.global_transform.basis.z if mounted else player.facing_dir()
	map_overlay.player_pos = Vector2(pos.x, pos.z)
	map_overlay.player_dir = Vector2(fwd.x, fwd.z)
	map_overlay.bike_shown = bike_parked and not mounted
	map_overlay.bike_pos = Vector2(bike.global_position.x, bike.global_position.z)
	map_overlay.bike_dist = bike_distance_m()
	map_overlay.refresh_dynamic()


## Hotspot (vị trí + màu theo màn hiện tại) thuộc lớp tĩnh: RoamMap chỉ vẽ lại lớp tĩnh khi danh sách thật sự đổi
## (Lab 402 đổi Màn 3 <-> Màn 6 theo ngày/đêm).
func _sync_map_hotspots() -> void:
	if map_overlay == null:
		return
	var pts: Array = []
	for h: Area3D in hotspots:
		pts.append([Vector2(h.global_position.x, h.global_position.z), HOTSPOT_COLORS.get(int(h.get_meta("stage_id")), Color.WHITE)])
	if story_roam:
		pts.append_array(story_roam.map_pins())   # story markers (pink)
	map_overlay.set_hotspots(pts)


## Gợi ý tạm thời (HINT_FLASH_S giây) đè lên dòng gợi ý đáy.
func flash_hint(text: String) -> void:
	_hint_flash = text
	_hint_flash_t = HINT_FLASH_S
	_hud_timer = 0.0
	if hint_label:
		hint_label.text = text


func _build_hud() -> void:
	var hint_panel: PanelContainer = GameFXScript.anchored_panel(hud, Control.PRESET_CENTER_BOTTOM, Vector2(760, 0), 24)
	hint_holder = hint_panel.get_parent() as Control
	hint_label = GameFXScript.make_label(HINT_DEFAULT, 15, Color("#F4F5F6"))
	hint_panel.add_child(hint_label)
	var tod_panel: PanelContainer = GameFXScript.anchored_panel(hud, Control.PRESET_TOP_LEFT, Vector2(0, 0), 20, Color("#F1C40F"))
	tod_label = GameFXScript.make_label("—", 14, Color("#F1C40F"), HORIZONTAL_ALIGNMENT_LEFT)
	tod_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tod_panel.add_child(tod_label)
	tod_holder = tod_panel.get_parent() as Control
	var stats_panel: PanelContainer = GameFXScript.anchored_panel(hud, Control.PRESET_TOP_RIGHT, Vector2(0, 0), 20, Color("#2ECC71"))
	stats_label = GameFXScript.make_label("FPS — · Cổng FPTU — m", 14, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_RIGHT)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_panel.add_child(stats_label)
	stats_holder = stats_panel.get_parent() as Control
	map_overlay = RoamMap.new()
	map_overlay.name = "MapOverlay"
	map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# dưới hai bảng giờ / FPS ở mép trên; bảng gợi ý đáy ẩn khi bản đồ mở (toggle_map) nên mép dưới sát hơn
	map_overlay.offset_left = 48.0
	map_overlay.offset_top = MAP_TOP
	map_overlay.offset_right = -48.0
	map_overlay.offset_bottom = -MAP_BOTTOM
	map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.clip_contents = true      # chấm người chơi đi ra ngoài khung bản đồ bị cắt ở mép
	map_overlay.visible = false
	map_overlay.setup(md, gate_xz, MapBuilder._water_polygons(md))
	hud.add_child(map_overlay)
	_sync_map_hotspots()
	_build_vice_hud()
	# Thanh thể lực nước rút (Shift): hiện khi đang nước rút hoặc chưa hồi đầy; nằm ngay trên bảng gợi ý đáy (bảng 2 dòng
	# cao 63 px + lề 24 -> đỉnh bảng ở 87 px từ đáy; thanh cách 2 px, vẫn dưới tên khu vực của ViceHUD ở 104 px)
	stamina_bar = GameFXScript.make_bar(100.0, Color("#3FF2FF"), 10)
	stamina_bar.name = "StaminaBar"
	stamina_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_bar.offset_left = -110.0
	stamina_bar.offset_right = 110.0
	stamina_bar.offset_top = -99.0
	stamina_bar.offset_bottom = -89.0
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.visible = false
	hud.add_child(stamina_bar)


## ViceHUD (nút con của cảnh, lớp vẽ 0 dưới HUD): tên khu vực nằm trên dòng gợi ý 2 dòng ở đáy (đáy 104 px).
func _build_vice_hud() -> void:
	vice_hud = ViceHUD.new()
	vice_hud.name = "ViceHUD"
	vice_hud.md = md
	vice_hud.area_margin = Vector2(34.0, 104.0)
	add_child(vice_hud)
	vice_hud.radar.route = md.route_points(40.0)
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_signal("art_style_changed"):
		fx.connect("art_style_changed", _on_art_style_changed)
	_apply_hud_style()


func _on_art_style_changed(_style: String) -> void:
	_apply_hud_style()


## Bố cục HUD theo phong cách: vice = ViceHUD (giờ + ví góc trên phải) thay huy hiệu giờ, bảng FPS / khoảng cách sang
## góc trên trái; classic = như cũ (giờ trên trái, FPS trên phải, không ViceHUD).
func _apply_hud_style() -> void:
	var vice: bool = ViceHUD.style_active()
	if tod_holder:
		tod_holder.visible = not vice
	if stats_holder:
		stats_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if vice else Control.PRESET_TOP_RIGHT)
		stats_holder.grow_horizontal = Control.GROW_DIRECTION_END if vice else Control.GROW_DIRECTION_BEGIN
		stats_holder.grow_vertical = Control.GROW_DIRECTION_END
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if vice else HORIZONTAL_ALIGNMENT_RIGHT
	if vice_hud:
		vice_hud.suppressed = map_overlay != null and map_overlay.visible
		_update_vice_hud(true)
	if wanted:
		wanted.refresh_hud()   # classic star row vs ViceHUD stars


## Radar theo người chơi / xe đang cưỡi (mỗi frame vật lý chỉ gán tâm + hướng); blip hotspot + xe đỗ theo nhịp HUD.
func _update_vice_hud(blips_too: bool) -> void:
	if vice_hud == null or not vice_hud.visible or player == null or bike == null:
		return
	var pos: Vector3 = roam_position()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var yaw: float = cam.global_rotation.y if cam else player.facing_yaw()
	vice_hud.track(Vector2(pos.x, pos.z), yaw)
	if not blips_too:
		return
	var bl: Array[Dictionary] = []
	for h: Area3D in hotspots:
		bl.append({"pos": Vector2(h.global_position.x, h.global_position.z), "color": HOTSPOT_COLORS.get(int(h.get_meta("stage_id")), Color.WHITE), "shape": "circle"})
	if bike_parked and not mounted:
		bl.append({"pos": Vector2(bike.global_position.x, bike.global_position.z), "color": RoamMap.BIKE, "shape": "diamond"})
	if story_roam:
		bl.append_array(story_roam.blips())
	if random_scares:
		bl.append_array(random_scares.blips())
	vice_hud.radar.blips = bl


func _hint_text() -> String:
	if _hint_flash_t > 0.0:
		return _hint_flash
	if story_roam:
		var sh: String = story_roam.hint_text()
		if sh != "":
			return sh
	var base: String = HINT_STORY if story_mode else HINT_DEFAULT
	if active_hotspot:
		return "[E] Chơi %s" % _stage_title(int(active_hotspot.get_meta("stage_id")))
	if mounted:
		return riding_hint if riding_hint != "" else HINT_RIDING
	if bike_parked:
		if can_mount():
			return "[F] lên xe máy · " + base
		return base.replace("[F] xe máy", "[F] xe máy cách %d m" % bike_distance_m())
	return base


func _physics_process(delta: float) -> void:
	if player == null or bike == null:
		return
	_watch_water(delta)
	_update_hotspot()
	if stamina_bar:
		var on_foot: bool = not mounted and player.visible
		stamina_bar.value = player.stamina * 100.0
		stamina_bar.visible = on_foot and (player.stamina < 0.999 or player.is_sprinting) and not (map_overlay and map_overlay.visible)
	if weapon_hud:
		weapon_hud.visible = not mayhem_blocked()
	if weapons:
		weapons.set_held_hidden("service", wanted != null and wanted.state == "service")
	if _hint_flash_t > 0.0:
		_hint_flash_t -= delta
	_hud_timer -= delta
	if _hud_timer > 0.0:
		_update_vice_hud(false)
		return
	_hud_timer = HUD_REFRESH
	_update_vice_hud(true)
	var pos: Vector3 = roam_position()
	var dist: float = Vector2(pos.x, pos.z).distance_to(gate_xz)
	if stats_label:
		stats_label.text = "FPS %d · Cổng FPTU %s m" % [int(Engine.get_frames_per_second()), _thousands(int(dist))]
	if hint_label:
		hint_label.text = _hint_text()
	if map_overlay and map_overlay.visible:
		_update_map_dynamic()   # chỉ lớp động; lớp tĩnh không vẽ lại theo nhịp HUD


static func _thousands(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var k: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		k += 1
		if k % 3 == 0 and i > 0:
			out = " " + out
	return out


# ===========================================================================
# PHASE W: VŨ KHÍ / TRUY NÃ (spec 2026-10-23-phase-w-weapons-wanted-design.md)
# ===========================================================================
func _build_mayhem() -> void:
	weapon_wheel = WeaponWheel.new()
	weapon_wheel.name = "WeaponWheel"
	add_child(weapon_wheel)
	weapon_hud = WeaponHUD.new()
	weapon_hud.name = "WeaponHUD"
	add_child(weapon_hud)
	weapons = WeaponDirector.new()
	weapons.name = "Weapons"
	add_child(weapons)
	weapons.setup({"player": player, "wheel": weapon_wheel, "hud": weapon_hud, "targets_fn": mayhem_targets,
		"traffic": traffic, "spawner": pedestrians, "blocked_fn": mayhem_blocked})
	classic_stars = ViceStars.new()
	classic_stars.name = "ClassicStars"
	classic_stars.cells = 3
	classic_stars.align_right = false
	classic_stars.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	classic_stars.offset_left = 24.0
	classic_stars.offset_top = 64.0
	classic_stars.offset_right = 24.0 + 3.0 * 22.0
	classic_stars.offset_bottom = 64.0 + 22.0
	classic_stars.visible = false
	hud.add_child(classic_stars)
	if vice_hud:
		vice_hud.stars.cells = 3
		vice_hud.stars.custom_minimum_size = Vector2(3.0 * ViceHUD.STAR_CELL, ViceHUD.STAR_CELL)
	wanted = WantedDirector.new()
	wanted.name = "Wanted"
	add_child(wanted)
	wanted.setup({"player": player, "roam": self, "md": md, "traffic": traffic, "vice_hud": vice_hud, "classic_stars": classic_stars})
	weapons.mayhem.connect(wanted.add_heat)
	emote_wheel = EmoteWheel.new()
	emote_wheel.name = "EmoteWheel"
	add_child(emote_wheel)
	emotes = EmoteDirector.new()
	emotes.name = "Emotes"
	add_child(emotes)
	emotes.setup({"player": player, "weapons": weapons, "wheel": emote_wheel, "weapon_wheel": weapon_wheel,
		"targets_fn": mayhem_targets, "fx": weapons.fx,
		"blocked_fn": func() -> bool: return mayhem_blocked() or (combat != null and combat.fight_active) or story_mission_active()})   # Phase B: no emote mid-fight / mission
	# one wheel at a time; no weapon during an emote (spec section 9)
	weapons.blocked_fn = func() -> bool: return mayhem_blocked() or emotes.active or emotes.pending >= 0 or emote_wheel.is_open()
	# Phase B: the Vovinam moves replace the Phase W unarmed punch (pedestrians keep their Phase W reactions and heat)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup({"player": player, "weapons": weapons, "targets_fn": mayhem_targets, "blocked_fn": weapons.blocked_fn})


## Everything weapons can hit: pedestrians of both tiers (officers join in Task 8). Nothing during a Phase B story
## mission (no heat, wanted or bust mid-mission; MeleeFight enemies come through PlayerCombat.add_enemy).
func mayhem_targets() -> Array:
	var out: Array = []
	if story_mission_active():
		return out
	if pedestrians:
		out.append_array(pedestrians.pedestrians())
	if wanted:
		out.append_array(wanted.officers())
	return out


## A Phase B story mission (stake-out, chase, brawl, corridor, canteen) is running.
func story_mission_active() -> bool:
	return story_roam != null and story_roam.mission_node != null


## Weapons and the wheel are off while riding (W-D9: on foot only), during a cinematic / replay (tree paused or
## StageManager.cinematic_active), while the map is open or the player is hidden.
func mayhem_blocked() -> bool:
	if mounted or cine_player != null or player == null or not player.visible:
		return true
	if map_overlay and map_overlay.visible:
		return true
	if story_roam and story_roam.phone and story_roam.phone.is_open():
		return true   # story phone open (A2-D7): no weapons, wheels, reload or emotes
	if wanted and wanted.state != "free":
		return true   # busted (stamp, cutscene) or community service
	if is_inside_tree() and get_tree().paused:
		return true
	var sm: Node = get_node_or_null("/root/StageManager")
	return sm != null and bool(sm.get("cinematic_active"))


# ===========================================================================
# CINEMATIC (spec A1)
# ===========================================================================
## Stage frame for a cinematic (Transform3D, origin on the floor) or null. Resolution order (plan 2026-10-26-cine-transition):
## the baked table (CineStage / CineStageBake: every stage the game resolves, recomputed by tests/test_cine_transition.gd),
## then the spots searched earlier by this FreeRoam (per CineStage.signature), then cine_stage_search with a
## CINE_SEARCH_BUDGET_MS wall-clock cap. A baked or cached spot is used after one cheap static check (cine_stage_ok: the
## floor-ray grid, no mesh scan; the visual clutter is static map content the bake test verifies). cine_stage_info says
## which spot won and its "source" ("baked", "cache", "search"); cine_search_tries counts the tries (0 off the table).
func cine_stage(stage: Dictionary) -> Variant:
	cine_stage_info = {}
	cine_search_tries = 0
	if not is_inside_tree() or md == null:
		return null
	var sig: String = CineStage.signature(stage)
	var bk: Dictionary = CineStage.baked(stage)
	if bk.has("none"):
		cine_stage_info = {"source": "baked", "none": true}   # baked: no clear spot (play_cinematic shows its hint)
		return null
	if not bk.is_empty():
		if cine_stage_ok(bk["xf"], stage):
			cine_stage_info = (bk["info"] as Dictionary).duplicate()
			cine_stage_info["source"] = "baked"
			return bk["xf"]
		push_warning("FreeRoam: baked cinematic stage %s has lost its floor; searching (re-run tests/test_cine_transition.gd)" % sig)
	if _cine_stage_cache.has(sig):
		var hit: Array = _cine_stage_cache[sig]
		if cine_stage_ok(hit[0], stage):
			cine_stage_info = (hit[1] as Dictionary).duplicate()
			cine_stage_info["source"] = "cache"
			return hit[0]
	var xf: Variant = cine_stage_search(stage, CINE_SEARCH_BUDGET_MS)
	cine_stage_info["source"] = "search"
	if xf is Transform3D:
		_cine_stage_cache[sig] = [xf, cine_stage_info.duplicate()]   # the same spot on every replay of this stage
	return xf


## Cheap static check of a known stage frame: the floor-ray grid (CINE_GRID_STEP) finds the stage floor everywhere in the
## box (no missing floor, no step, no slope). No mesh scan and no body query: those are static map content (bake test) or
## transient bodies (a fight's knocked-out enemies, a set being freed) that never moved a stage.
func cine_stage_ok(xf: Transform3D, stage: Dictionary) -> bool:
	if not is_inside_tree():
		return false
	var size: Vector2 = stage.get("size", Vector2(14.0, 10.0))
	return _cine_floor_steps(get_world_3d().direct_space_state, xf, size, true).is_empty()


## Clear, flat stage frame near a landmark (spec A1-D19, plan review M4): the full search. stage: {"landmark", "near" (m),
## "size" (Vector2 m: x across, y along the stage's Z), "yaw_deg" (road-aligned yaw; the stage's -Z runs along the road),
## "offset" (Vector2 m in that yaw frame: x right, y back; pushes the search centre, e.g. to the road side of a gate),
## "fallback" (second landmark)}. Landmark ground = the lowest upward floor under the landmark. Rings every 2 m out to
## `near`, first with yaw_deg only, then with 45° steps; floor = 5 downward rays from 2 m above the landmark ground, all
## within 0.5 m of it (no shed roofs) and agreeing within 0.15 m; no visible mesh pokes more than 0.15 m above the floor
## inside the box (gate barrier arm, poles, bollards: cine_clutter); the box (size.x × 1.8 × size.y) 0.25 m above the
## floor touches nothing except the player, the bike, pedestrians and traffic. Returns Transform3D (origin on the floor)
## or null; cine_stage_info says which spot won. Each try tests only the clutter items of the grid cells its box covers
## (same answer as testing them all). budget_ms > 0: after that much wall time spent on tries (the first spot's clutter
## walk, about 60 ms windowed, is not counted) the search stops and returns the first flat candidate it met, else the first
## spot's centre on its ground (cine_stage_info.budget_hit).
func cine_stage_search(stage: Dictionary, budget_ms: float = 0.0) -> Variant:
	cine_stage_info = {}
	cine_search_tries = 0
	_cine_flat = null
	if not is_inside_tree() or md == null:
		return null
	var t0: int = Time.get_ticks_usec()
	var size: Vector2 = stage.get("size", Vector2(14.0, 10.0))
	var near: float = float(stage.get("near", 30.0))
	var yaw0: float = deg_to_rad(float(stage.get("yaw_deg", 0.0)))
	var off: Vector2 = stage.get("offset", Vector2.ZERO)
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 1.8, size.y)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var excl: Array[RID] = _cine_exclusions()
	var names: Array[String] = [String(stage.get("landmark", ""))]
	if stage.has("fallback"):
		names.append(String(stage["fallback"]))
	if stage.get("at") is Vector2:
		names.push_front("@at")   # story (A2): an explicit map point (Vector2 x, z) searched first, the landmark stays the fallback
	var first: Variant = null     # [landmark, centre, ground_y] of the first spot (budget fallback)
	for lk: String in names:
		var lm: Variant = [(stage["at"] as Vector2).x, (stage["at"] as Vector2).y] if lk == "@at" else md.landmark(lk)
		if not (lm is Array and (lm as Array).size() >= 2):
			continue
		var lc := Vector2(float(lm[0]), float(lm[1]))
		var ground_y: float = _cine_ground_y(space, lc)
		var ov: Vector3 = Basis(Vector3.UP, yaw0) * Vector3(off.x, 0.0, off.y)
		var c: Vector2 = lc + Vector2(ov.x, ov.z)
		var grid: Dictionary = _cine_grid(_cine_clutter_items(Vector3(c.x, ground_y, c.y), near + size.length() * 0.5 + 1.0))
		if first == null:
			first = [lk, c, ground_y]
			t0 = Time.get_ticks_usec()   # the budget is for the tries (the first spot's clutter walk is not counted)
		for pass_i: int in 2:
			var yaws: Array[float] = [yaw0]
			if pass_i == 1:
				yaws = [yaw0 + PI * 0.25, yaw0 + PI * 0.5, yaw0 + PI * 0.75]
			var ring: float = 0.0
			while ring <= near:
				var steps: int = 1 if ring == 0.0 else int(ceil(TAU * ring / 2.0))
				for i: int in steps:
					var a: float = TAU * float(i) / float(steps)
					var pt: Vector2 = c + Vector2(cos(a), sin(a)) * ring
					for yaw: float in yaws:
						if budget_ms > 0.0 and cine_search_tries > 0 and float(Time.get_ticks_usec() - t0) > budget_ms * 1000.0:
							return _cine_budget_fallback(first, yaw0)
						var xf: Variant = _cine_try(space, box, excl, pt, yaw, size, ground_y, [], grid)
						if xf != null:
							cine_stage_info = {"landmark": lk, "centre": c, "ring": ring, "yaw_deg": snappedf(rad_to_deg(yaw), 0.01),
								"floor_y": snappedf((xf as Transform3D).origin.y, 0.001), "ground_y": ground_y,
								"pos": Vector2(snappedf(pt.x, 0.01), snappedf(pt.y, 0.01)), "road_aligned": pass_i == 0}
							return xf
				ring += 2.0
	return null


## Budget ran out: the first candidate with a flat floor, else the first spot's centre on its ground (road yaw).
func _cine_budget_fallback(first: Variant, yaw0: float) -> Variant:
	if first == null:
		return null
	var c: Vector2 = first[1]
	var xf: Transform3D = _cine_flat if _cine_flat is Transform3D else Transform3D(Basis(Vector3.UP, yaw0), Vector3(c.x, float(first[2]), c.y))
	cine_stage_info = {"landmark": String(first[0]), "centre": c, "ring": -1.0, "yaw_deg": snappedf(rad_to_deg(xf.basis.get_euler().y), 0.01),
		"floor_y": snappedf(xf.origin.y, 0.001), "ground_y": float(first[2]), "pos": Vector2(snappedf(xf.origin.x, 0.01), snappedf(xf.origin.z, 0.01)),
		"road_aligned": false, "budget_hit": true, "flat": _cine_flat is Transform3D}
	return xf


## Lowest upward-facing floor under the landmark (walk-floor level, below gate roofs and fences; WaterFloor ignored).
func _cine_ground_y(space: PhysicsDirectSpaceState3D, lc: Vector2) -> float:
	var excl: Array[RID] = _cine_exclusions()
	if water_floor:
		excl.append(water_floor.get_rid())
	var top: float = 60.0
	var best: float = GROUND_COLLIDER_Y
	for i: int in 16:
		var q := PhysicsRayQueryParameters3D.create(Vector3(lc.x, top, lc.y), Vector3(lc.x, MapBuilder.WATER_Y - 1.0, lc.y))
		q.exclude = excl
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			break
		var hy: float = (hit["position"] as Vector3).y
		if (hit["normal"] as Vector3).y > 0.7:
			best = hy
		top = hy - 0.02
	return best


## One candidate box. Clutter from `grid` (_cine_grid: only the items near the box) when given, else from the flat list.
func _cine_try(space: PhysicsDirectSpaceState3D, box: BoxShape3D, excl: Array[RID], pt: Vector2, yaw: float, size: Vector2,
		ground_y: float, items: Array, grid: Dictionary = {}) -> Variant:
	cine_search_tries += 1
	var basis := Basis(Vector3.UP, yaw)
	var ray_excl: Array[RID] = excl.duplicate()
	if water_floor:
		ray_excl.append(water_floor.get_rid())
	var ys: Array[float] = []
	for o: Vector2 in [Vector2.ZERO, Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		var off: Vector3 = basis * Vector3(o.x * size.x, 0.0, o.y * size.y)
		var q := PhysicsRayQueryParameters3D.create(Vector3(pt.x, ground_y + CINE_FLOOR_UP, pt.y) + off, Vector3(pt.x, ground_y - 1.0, pt.y) + off)
		q.exclude = ray_excl
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
			return null
		var y: float = (hit["position"] as Vector3).y
		if absf(y - ground_y) > CINE_FLOOR_MAX:
			return null
		ys.append(y)
	if ys.max() - ys.min() > 0.15:
		return null
	var xf := Transform3D(basis, Vector3(pt.x, ys[0], pt.y))
	if _cine_flat == null:
		_cine_flat = xf
	if _cine_grid_hit(grid, xf, size) if not grid.is_empty() else not _cine_clutter_in(items, xf, size).is_empty():
		return null
	if not _cine_floor_steps(space, xf, size, true).is_empty():
		return null
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = box
	sq.transform = Transform3D(basis, Vector3(pt.x, ys[0] + 0.25 + 0.9, pt.y))
	sq.exclude = excl
	if not space.intersect_shape(sq, 1).is_empty():
		return null
	return xf


func _cine_exclusions() -> Array[RID]:
	var out: Array[RID] = []
	if player:
		out.append(player.get_rid())
	if bike:
		out.append(bike.get_rid())
	if pedestrians:
		for p: Node in pedestrians.pedestrians():
			if p is CollisionObject3D:
				out.append((p as CollisionObject3D).get_rid())
	if traffic:
		for b: Node in traffic.bodies():
			if b is CollisionObject3D:
				out.append((b as CollisionObject3D).get_rid())
	return out


## Visual clutter (names) inside the stage box xf / size: visible meshes poking more than CINE_CLUTTER_H above the floor,
## plus floor steps found by the ~1 m ray grid.
func cine_clutter(xf: Transform3D, size: Vector2) -> Array:
	var out: Array = _cine_clutter_in(_cine_clutter_items(xf.origin, size.length() * 0.5 + 1.0), xf, size)
	out.append_array(_cine_floor_steps(get_world_3d().direct_space_state, xf, size, false))
	return out


## Floor steps inside the box: a downward ray every ~CINE_GRID_STEP m from CINE_FLOOR_UP above the floor; a missing floor,
## a steep hit or one more than CINE_CLUTTER_H (+1 cm) off the floor height is a step. Catches wide merged slabs (the
## 0.28 m campus sidewalk) that cross the box with no vertex inside it. first_only: stop at the first step (search).
func _cine_floor_steps(space: PhysicsDirectSpaceState3D, xf: Transform3D, size: Vector2, first_only: bool) -> Array:
	var excl: Array[RID] = _cine_exclusions()
	if water_floor:
		excl.append(water_floor.get_rid())
	var nx: int = maxi(1, ceili(size.x / CINE_GRID_STEP))
	var nz: int = maxi(1, ceili(size.y / CINE_GRID_STEP))
	var out: Array = []
	for i: int in nx + 1:
		for j: int in nz + 1:
			var l := Vector3(size.x * (float(i) / nx - 0.5), 0.0, size.y * (float(j) / nz - 0.5))
			var w: Vector3 = xf * l
			var q := PhysicsRayQueryParameters3D.create(w + Vector3(0.0, CINE_FLOOR_UP, 0.0), w - Vector3(0.0, 1.0, 0.0))
			q.exclude = excl
			var hit: Dictionary = space.intersect_ray(q)
			var bad: bool = hit.is_empty() or (hit["normal"] as Vector3).y < 0.7 \
				or absf((hit["position"] as Vector3).y - xf.origin.y) > CINE_CLUTTER_H + 0.01
			if bad:
				out.append("floor step at (%.1f, %.1f): %s" % [l.x, l.z, "no floor" if hit.is_empty() else "y %.2f" % (hit["position"] as Vector3).y])
				if first_only:
					return out
	return out


## Clutter sources within `radius` (XZ) of centre, in the height band a stage floor near centre.y can see: small visible
## meshes and multimesh instances as global AABBs, merged meshes wider than CINE_BIG_MESH as their global vertices (their
## AABB spans whole regions). The nodes hidden during a cinematic (player, bike, crowd, traffic) are skipped.
func _cine_clutter_items(centre: Vector3, radius: float) -> Array:
	var y_lo: float = centre.y - CINE_FLOOR_MAX + CINE_CLUTTER_H
	var region := AABB(Vector3(centre.x - radius, y_lo, centre.z - radius), Vector3(radius * 2.0, CINE_CLUTTER_TOP + 2.0 * CINE_FLOOR_MAX, radius * 2.0))
	var out: Array = []
	var skip: Array = [player, bike, pedestrians, traffic, cine_player, hud]
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if skip.has(n):
			continue
		for ch: Node in n.get_children():
			stack.append(ch)
		if not (n is MeshInstance3D or n is MultiMeshInstance3D):
			continue
		var g: GeometryInstance3D = n
		if not g.is_visible_in_tree():
			continue
		var gt: Transform3D = g.global_transform
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh if n is MultiMeshInstance3D else null
		var kept: Array = mm.get_meta("cine_xforms", []) if mm != null and mm.mesh != null else []
		var ab: AABB = gt * (_cine_mm_aabb(mm, kept) if not kept.is_empty() else g.get_aabb())
		if not ab.intersects(region):
			continue
		if n is MultiMeshInstance3D:
			if mm == null or mm.mesh == null:
				continue
			# the builders' own instance transforms when kept (meta cine_xforms: the headless RenderingServer returns none,
			# so headless tests and the windowed game see the same clutter), else the RenderingServer's
			var cnt: int = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			var use_kept: bool = kept.size() >= cnt
			var mab: AABB = mm.mesh.get_aabb()
			for i: int in cnt:
				var iab: AABB = gt * (kept[i] as Transform3D if use_kept else mm.get_instance_transform(i)) * mab
				if iab.intersects(region):
					out.append({"name": "%s#%d" % [g.name, i], "aabb": iab})
			continue
		if ab.size.x <= CINE_BIG_MESH and ab.size.z <= CINE_BIG_MESH:
			out.append({"name": String(g.name), "aabb": ab})
			continue
		var mesh: Mesh = (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		var inv: Transform3D = gt.affine_inverse()
		var lr: AABB = inv * region
		var pts := PackedVector3Array()
		for si: int in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(si)
			if arr.is_empty() or not (arr[Mesh.ARRAY_VERTEX] is PackedVector3Array):
				continue
			for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
				if lr.has_point(v):
					var w: Vector3 = gt * v
					if region.has_point(w):
						pts.append(w)
		if not pts.is_empty():
			out.append({"name": String(g.name), "pts": pts})
	return out


## Local AABB of a multimesh from its kept instance transforms (meta cine_xforms), cached on the MultiMesh.
func _cine_mm_aabb(mm: MultiMesh, kept: Array) -> AABB:
	if mm.has_meta("cine_aabb"):
		return mm.get_meta("cine_aabb")
	var mab: AABB = mm.mesh.get_aabb()
	var out: AABB = (kept[0] as Transform3D) * mab
	for i: int in range(1, kept.size()):
		out = out.merge((kept[i] as Transform3D) * mab)
	mm.set_meta("cine_aabb", out)
	return out


func _cine_clutter_in(items: Array, xf: Transform3D, size: Vector2, first_only: bool = false) -> Array:
	var inv: Transform3D = xf.affine_inverse()
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	var y0: float = xf.origin.y + CINE_CLUTTER_H + 0.01   # 1 cm float slack: kerbs sit exactly 0.15 m above the ground
	var y1: float = xf.origin.y + CINE_CLUTTER_TOP
	var out: Array = []
	for it: Dictionary in items:
		if it.has("aabb"):
			var ab: AABB = it["aabb"]
			if ab.end.y <= y0 or ab.position.y >= y1:
				continue
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for cn: Vector3 in [ab.position, Vector3(ab.end.x, 0.0, ab.position.z), Vector3(ab.position.x, 0.0, ab.end.z), ab.end]:
				var l: Vector3 = inv * Vector3(cn.x, xf.origin.y, cn.z)
				lo = Vector2(minf(lo.x, l.x), minf(lo.y, l.z))
				hi = Vector2(maxf(hi.x, l.x), maxf(hi.y, l.z))
			if hi.x > -hx and lo.x < hx and hi.y > -hz and lo.y < hz:
				out.append(it["name"])
				if first_only:
					return out
		else:
			for w: Vector3 in (it["pts"] as PackedVector3Array):
				if w.y <= y0 or w.y >= y1:
					continue
				var l2: Vector3 = inv * w
				if absf(l2.x) < hx and absf(l2.z) < hz:
					out.append(it["name"])
					if first_only:
						return out
					break
	return out


## XZ grid (CINE_CELL) over clutter items for the search: {"items": [...], "cells": {Vector2i: Array of item indices}}. An AABB
## item goes into every cell of its centre ± half-diagonal × √2 (the stage-local bounds _cine_clutter_in tests never reach
## farther); a vertex item is split per cell (one sub-item per cell with that cell's vertices). A box then only needs the
## cells within its half-diagonal: the same answer as testing every item.
func _cine_grid(items: Array) -> Dictionary:
	var sub: Array = []
	var cells: Dictionary = {}
	for it: Dictionary in items:
		if it.has("aabb"):
			var ab: AABB = it["aabb"]
			var cc := Vector2(ab.position.x + ab.size.x * 0.5, ab.position.z + ab.size.z * 0.5)
			var r: float = Vector2(ab.size.x, ab.size.z).length() * 0.5 * 1.4143 + 0.01
			var k: int = sub.size()
			sub.append(it)
			for gx: int in range(floori((cc.x - r) / CINE_CELL), floori((cc.x + r) / CINE_CELL) + 1):
				for gz: int in range(floori((cc.y - r) / CINE_CELL), floori((cc.y + r) / CINE_CELL) + 1):
					_cine_cell_add(cells, Vector2i(gx, gz), k)
		else:
			var per: Dictionary = {}
			for w: Vector3 in (it["pts"] as PackedVector3Array):
				var key := Vector2i(floori(w.x / CINE_CELL), floori(w.z / CINE_CELL))
				if not per.has(key):
					per[key] = []
				(per[key] as Array).append(w)   # plain Array: a packed array read from a Dictionary is a copy
			for key2: Vector2i in per.keys():
				_cine_cell_add(cells, key2, sub.size())
				sub.append({"name": it["name"], "pts": PackedVector3Array(per[key2])})
	return {"items": sub, "cells": cells}


func _cine_cell_add(cells: Dictionary, key: Vector2i, k: int) -> void:
	if not cells.has(key):
		cells[key] = []
	(cells[key] as Array).append(k)   # plain Array: a packed array read from a Dictionary is a copy


## true when any item of the grid cells under the box is clutter for it (same test as _cine_clutter_in).
func _cine_grid_hit(grid: Dictionary, xf: Transform3D, size: Vector2) -> bool:
	var r: float = size.length() * 0.5 + 0.01
	var o: Vector3 = xf.origin
	var cells: Dictionary = grid["cells"]
	var sub: Array = grid["items"]
	var seen: Dictionary = {}
	var near: Array = []
	for gx: int in range(floori((o.x - r) / CINE_CELL), floori((o.x + r) / CINE_CELL) + 1):
		for gz: int in range(floori((o.z - r) / CINE_CELL), floori((o.z + r) / CINE_CELL) + 1):
			var key := Vector2i(gx, gz)
			if not cells.has(key):
				continue
			for k: int in (cells[key] as Array):
				if not seen.has(k):
					seen[k] = true
					near.append(sub[k])
	return not near.is_empty() and not _cine_clutter_in(near, xf, size, true).is_empty()


## Prepare tl ahead (plan 2026-10-26-cine-transition): one CinePrep child resolves its stage now (opts "xf" wins, as in
## play_cinematic) and builds its actors one per unpaused frame. A prep for the same slot and stage is kept; another one
## is replaced. false when tl is null.
func prepare_cinematic(tl: CineTimeline, opts: Dictionary = {}) -> bool:
	if tl == null:
		return false
	var sig: String = CineStage.signature(tl.stage)
	if cine_prep != null and is_instance_valid(cine_prep) and cine_prep.slot == tl.slot and cine_prep.stage_sig == sig \
			and (not (opts.get("xf") is Transform3D) or cine_prep.xf == opts["xf"]):
		return true
	drop_cinematic_prep()
	var xf: Variant = opts["xf"] if opts.get("xf") is Transform3D else (cine_stage(tl.stage) if not tl.stage.is_empty() else null)
	cine_prep = CinePrep.new()
	add_child(cine_prep)
	cine_prep.begin(tl, xf)
	cine_prep.info = cine_stage_info.duplicate()
	return true


func drop_cinematic_prep() -> void:
	if cine_prep != null and is_instance_valid(cine_prep):
		cine_prep.queue_free()
	cine_prep = null


## Play a cinematic at its stage: pauses the game (game clock frozen), hides the roam player / bike / HUD / map / crowd /
## traffic, stops the roam music, switches the time of day, and restores everything (camera, music) on finished. opts go
## to CinePlayer.setup (manual, debug, music, drop_set); "fade" (default: not manual) fades to black over CinePlayer.FADE_S
## first and does the setup, the hiding, the time of day and the exposure under the black frame (CinePlayer.preroll);
## "on_black" (Callable) runs there too, before the setup (StoryRoam hides the yard's copies). A prepared cinematic
## (prepare_cinematic) with the same slot and stage hands over its stage frame and actors. Returns the player at once
## (during the fade its timeline is set, nothing else), or null (invalid timeline, no stage spot, one already playing).
func play_cinematic(tl: CineTimeline, opts: Dictionary = {}) -> CinePlayer:
	if tl == null or cine_player != null:
		return null
	var errs: PackedStringArray = tl.validate()
	if not errs.is_empty():
		push_error("CinePlayer: timeline %s is invalid:\n  %s" % [tl.slot, "\n  ".join(errs)])
		return null
	var o: Dictionary = opts.duplicate()
	var xf: Variant = null
	var adopt: CinePrep = null
	if cine_prep != null and is_instance_valid(cine_prep) and cine_prep.slot == tl.slot \
			and cine_prep.stage_sig == CineStage.signature(tl.stage) and (not (opts.get("xf") is Transform3D) or cine_prep.xf == opts["xf"]):
		xf = cine_prep.xf
		if cine_prep.xf is Transform3D:
			cine_stage_info = cine_prep.info.duplicate()
			cine_stage_info["prepared"] = true
		adopt = cine_prep
		o["actors"] = adopt.take_actors()
		cine_prep = null   # the prep node (its hidden actors) goes with the player until the setup reparents them
	if not (xf is Transform3D):
		xf = opts["xf"] if opts.get("xf") is Transform3D else (cine_stage(tl.stage) if not tl.stage.is_empty() else Transform3D(Basis.IDENTITY, roam_position()))
	if xf == null:
		if adopt != null:
			adopt.queue_free()
		flash_hint("Không tìm được chỗ trống để diễn cinematic %s" % tl.slot)
		return null
	var p := CinePlayer.new()
	p.name = "CinePlayer"
	add_child(p)
	if adopt != null:
		adopt.reparent(p, false)   # freed with the player; setup moves its actors under the stage
	cine_player = p
	_cine_saved = {"tod": tod_preset, "vis": {}, "proc": {}, "cam": get_viewport().get_camera_3d()}
	get_tree().paused = true   # the game freezes now (also through the fade)
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_stop"):
		fx.call("music_stop", true)   # before the time of day changes, so the other roam track is not started for nothing
	p.finished.connect(_on_cine_finished.bind(tl.slot), CONNECT_ONE_SHOT)
	var go: Callable = _cine_go.bind(p, tl, xf, o)
	if bool(opts.get("fade", not bool(opts.get("manual", false)))):
		p.preroll(tl, CinePlayer.FADE_S, go)
	else:
		go.call()
	return p


## Setup and start (under the black frame when faded): the actors, props and camera, then the world hidden, the crowd and
## traffic stopped, the stage's time of day and exposure.
func _cine_go(p: CinePlayer, tl: CineTimeline, xf: Transform3D, o: Dictionary) -> void:
	if not is_instance_valid(p) or cine_player != p:
		return
	var ob: Variant = o.get("on_black")
	if ob is Callable and (ob as Callable).is_valid():
		(ob as Callable).call()
	o.erase("on_black")
	if not p.setup(tl, xf, o).is_empty():
		p.call("_finish", true)   # validated in play_cinematic: not expected; the host restores as after a skip
		return
	for n: Node in [player, bike, hint_holder, tod_holder, stats_holder, vice_hud, stamina_bar, map_overlay, pedestrians, traffic, weapon_hud, wanted, classic_stars]:
		if n and "visible" in n:
			_cine_saved["vis"][n] = n.visible
			n.visible = false
	for n2: Node in [pedestrians, traffic]:
		if n2:
			_cine_saved["proc"][n2] = n2.process_mode
			n2.process_mode = Node.PROCESS_MODE_DISABLED
	set_time_of_day(String(tl.stage.get("tod", tod_preset)))
	# stage "exposure" / "ambient": hệ số sáng riêng cho cinematic (đêm vẫn đọc rõ người), lưu giá trị gốc để trả lại
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment and (tl.stage.has("exposure") or tl.stage.has("ambient")):
		var env: Environment = we.environment
		_cine_saved["env"] = [env, env.tonemap_exposure, env.ambient_light_energy]
		env.tonemap_exposure *= float(tl.stage.get("exposure", 1.0))
		env.ambient_light_energy *= float(tl.stage.get("ambient", 1.0))
	p.start()


func _on_cine_finished(skipped: bool, slot: String) -> void:
	if cine_player and cine_player.leaving_tree:
		# the player left the tree mid-cinematic: when FreeRoam itself is leaving (scene change) do nothing (no music_play
		# while the next scene loads); if only the player was removed, restore the world once the removal is done
		call_deferred("_on_cine_left_tree", skipped, slot)
		return
	_restore_after_cine(skipped, slot)


func _on_cine_left_tree(skipped: bool, slot: String) -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_restore_after_cine(skipped, slot)


func _restore_after_cine(skipped: bool, slot: String) -> void:
	for n: Node in (_cine_saved.get("vis", {}) as Dictionary).keys():
		if is_instance_valid(n):
			n.visible = _cine_saved["vis"][n]
	for n2: Node in (_cine_saved.get("proc", {}) as Dictionary).keys():
		if is_instance_valid(n2):
			n2.process_mode = _cine_saved["proc"][n2]
	var saved_env: Array = _cine_saved.get("env", [])
	if saved_env.size() == 3 and is_instance_valid(saved_env[0]):
		(saved_env[0] as Environment).tonemap_exposure = float(saved_env[1])
		(saved_env[0] as Environment).ambient_light_energy = float(saved_env[2])
	set_time_of_day(String(_cine_saved.get("tod", tod_preset)))
	get_tree().paused = false
	var cam: Variant = _cine_saved.get("cam")
	if cam is Camera3D and is_instance_valid(cam) and (cam as Camera3D).is_inside_tree():
		(cam as Camera3D).make_current()   # camera trước cinematic (camera xe khi đang cưỡi)
	elif player and player.camera:
		player.camera.make_current()
	roam_music()
	if cine_player:
		cine_player.queue_free()
	cine_player = null
	_cine_saved = {}
	cinematic_finished.emit(slot, skipped)


## [F9] (debug builds): play the next timeline in scripts/cine/timelines/.
func _play_next_cinematic() -> CinePlayer:
	var all: PackedStringArray = CineTimeline.slots()
	if all.is_empty():
		flash_hint("Chưa có cinematic nào (scripts/cine/timelines/)")
		return null
	_cine_slot_i = (_cine_slot_i + 1) % all.size()
	return play_cinematic(CineTimeline.load_slot(all[_cine_slot_i]))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_E:
			# Phase W: no stage while busted or in community service (it would skip the chore)
			if active_hotspot and not mounted and (wanted == null or wanted.state == "free"):
				if start_hotspot_stage(active_hotspot):
					get_viewport().set_input_as_handled()
		KEY_F:
			toggle_bike()
			get_viewport().set_input_as_handled()
		KEY_T:
			if not story_mode:   # the story drives the time of day (A2-D13)
				cycle_time_of_day()
				get_viewport().set_input_as_handled()
		KEY_M:
			toggle_map()
			get_viewport().set_input_as_handled()
		KEY_F9:
			if OS.is_debug_build() and cine_player == null:
				_play_next_cinematic()
				get_viewport().set_input_as_handled()


# ===========================================================================
# BẢN ĐỒ [M] – hai lớp vẽ:
#   TĨNH  (Control "Static" + canvas item RID con do RoamMap tự quản; phần bản đồ nằm dưới Control "MapClip"
#         clip_contents đặt đúng content_rect() để đường chạy ra ngoài không đè chú giải): nền, công viên / sân
#         bóng, nước, đường, cả 2 691 nhà theo ĐÚNG đường viền (MapData.poly; nhà có sân trong cắt bằng MapBuilder._subtract), nhà OSM đậm
#         hơn nhà Microsoft (màu theo vùng), tất cả gộp sẵn trong setup() thành MỘT ArrayMesh 2D toạ độ bản đồ (vẽ bằng
#         đúng 1 lệnh canvas_item_add_mesh + Transform2D bản đồ -> màn hình); tuyến BE6 -> FPTU, cổng, hotspot, nhãn
#         BE6 / ĐH FPT, chú giải + 2 dòng ghi công (OSM ODbL, Microsoft CDLA-Permissive-2.0). Lệnh vẽ chỉ được gửi khi
#         mở bản đồ lần đầu, khi đổi kích thước hoặc khi màu hotspot đổi (Lab 402 ngày / đêm). Ẩn / hiện bản đồ khiến
#         Godot vẽ lại các Control nhưng không xoá canvas item con này, nên mở lại không gửi lại gì.
#   ĐỘNG  (Control "Dynamic", vẽ qua tín hiệu draw): chấm người chơi + hướng, xe đang đỗ + khoảng cách; FreeRoam gọi
#         refresh_dynamic() theo nhịp HUD (HUD_REFRESH).
# static_draws / dynamic_draws và static_draw_usec / dynamic_draw_usec: số lần vẽ + thời gian lần vẽ gần nhất của từng
# lớp (tests/test_free_roam.gd đo).
# ===========================================================================
class RoamMap extends Control:
	const BG := Color(0.03, 0.05, 0.09, 0.95)
	const FRAME := Color(0.95, 0.44, 0.13, 0.9)
	const WATER := Color(0.17, 0.45, 0.78)
	const AREA_COLORS: Dictionary = {"park": Color(0.12, 0.3, 0.17), "pitch": Color(0.16, 0.4, 0.21), "campus": Color(0.13, 0.19, 0.29), "pool": Color(0.17, 0.45, 0.78)}
	const ROAD_MAJOR := Color(0.82, 0.77, 0.62)
	const ROAD_MINOR := Color(0.45, 0.48, 0.54)
	const MAJOR_CLASSES: Array = ["motorway", "primary", "secondary", "tertiary"]
	const REGION_COLORS: Dictionary = {"vinhomes": Color(0.98, 0.62, 0.3), "campus": Color(0.45, 0.78, 0.98), "corridor": Color(0.76, 0.76, 0.74)}
	const OSM_DARKEN: float = 0.3
	const ROUTE := Color(0.95, 0.44, 0.13)
	const CASING := Color(0.02, 0.03, 0.06, 0.92)
	const GATE := Color(0.18, 0.8, 0.44)
	const BIKE := Color(0.3, 0.85, 1.0)
	const INK := Color(0.02, 0.05, 0.1)
	const TEXT := Color(0.96, 0.96, 0.96)
	const DIM := Color(0.8, 0.82, 0.85)
	const PAD: float = 16.0
	const TOP_RESERVE: float = 84.0      # tiêu đề + 2 dòng chú giải
	const BOTTOM_RESERVE: float = 46.0   # 2 dòng ghi công
	const LEGEND_SIZE: int = 13
	const ATTR_OSM: String = "Bản đồ © OpenStreetMap contributors (ODbL 1.0)"
	const ATTR_MSFT: String = "Nhà ống © Microsoft Global ML Building Footprints (CDLA-Permissive-2.0)"

	var route := PackedVector2Array()
	var bounds := Rect2()
	var hotspot_pts: Array = []          # [Vector2, Color] – lớp tĩnh (set_hotspots)
	var labels: Array = []               # [Vector2, String, Vector2 lệch px] – nhãn địa danh trên lớp tĩnh
	var gate := Vector2.ZERO
	var player_pos := Vector2.ZERO
	var player_dir := Vector2(0.0, -1.0)
	var bike_shown: bool = false         # xe máy đang đỗ (người chơi đã xuống xe)
	var bike_pos := Vector2.ZERO
	var bike_dist: int = 0
	var static_layer: Control
	var dynamic_layer: Control
	var static_draws: int = 0
	var dynamic_draws: int = 0
	var static_draw_usec: int = 0
	var dynamic_draw_usec: int = 0
	var osm_buildings: int = 0
	var msft_buildings: int = 0
	var triangles: int = 0
	var setup_usec: int = 0              # dựng mesh tĩnh (một lần, lúc nạp cảnh)
	var _mesh: ArrayMesh
	var _ci := RID()
	var _map_ci := RID()
	var _map_clip: Control
	var _static_dirty: bool = true
	var _static_size := Vector2(-1.0, -1.0)

	## Dựng một lần (lúc FreeRoam._build_hud): mesh 2D của lớp tĩnh + hai Control con. `water` = các đa giác nước
	## (MapBuilder._water_polygons, đã cache).
	func setup(md: MapData, gate_xz: Vector2, water: Array = []) -> void:
		var t0: int = Time.get_ticks_usec()
		gate = gate_xz
		var verts := PackedVector2Array()
		var cols := PackedColorArray()
		for a: Dictionary in md.areas():
			var kind: String = str(a.get("kind", ""))
			if AREA_COLORS.has(kind) and float(a.get("area", 0.0)) <= MapBuilder.BIG_AREA_SKIP_M2:
				_add_poly(verts, cols, MapData.poly(a.get("outer", [])), AREA_COLORS[kind])
		for w: PackedVector2Array in water:
			_add_poly(verts, cols, w, WATER)
		for r: Dictionary in md.roads():
			if int(r.get("lanes", 2)) <= 0:
				continue   # lối đi bộ / bậc thang: bỏ cho bản đồ đỡ rối
			var cls: String = str(r.get("class", ""))
			var major: bool = MAJOR_CLASSES.has(String(MapBuilder.CLASS_ALIAS.get(cls, cls)))
			var w: float = float(r.get("width", 6.0))
			# bề rộng phóng to cho dễ nhìn ở tỉ lệ ~0,2 px/m (đường lớn >= 12 m, đường nhỏ >= 7 m)
			var half: float = maxf(w * 0.7, 6.0) if major else maxf(w * 0.6, 3.5)
			_add_road(verts, cols, MapData.poly(r.get("points", [])), half, ROAD_MAJOR if major else ROAD_MINOR)
		var started: bool = false
		for b: Dictionary in md.buildings():
			var outer: PackedVector2Array = MapBuilder._open(MapData.poly(b.get("outer", [])))
			if outer.size() < 3:
				continue
			var msft: bool = MapBuilder.is_msft(b)
			var col: Color = building_color(str(b.get("region", "")), msft)
			var inners: Array = []
			for ring: Variant in b.get("inner", []):
				var hole: PackedVector2Array = MapBuilder._open(MapData.poly(ring))
				if hole.size() >= 3:
					inners.append(hole)
			var pieces: Array = [outer] if inners.is_empty() else MapBuilder._subtract([outer], inners)
			for piece: PackedVector2Array in pieces:
				_add_poly(verts, cols, piece, col)
			if msft:
				msft_buildings += 1
			else:
				osm_buildings += 1
			var bb: Rect2 = MapBuilder._bbox(outer)
			bounds = bb if not started else bounds.merge(bb)
			started = true
		route = md.route_points(40.0)
		for p: Vector2 in route:
			bounds = bounds.expand(p) if started else Rect2(p, Vector2.ZERO)
			started = true
		bounds = bounds.grow(150.0)
		var be6: Variant = md.landmark("be6_center")
		if be6 is Array and (be6 as Array).size() >= 2:
			labels.append([Vector2(float(be6[0]), float(be6[1])), "BE6 · Vinhomes Grand Park", Vector2(0.0, -16.0)])
		# gốc toạ độ mapdata = trọng tâm campus FPT; nhãn đặt cao hơn cụm 5 hotspot campus
		labels.append([Vector2.ZERO, "ĐH FPT", Vector2(0.0, -34.0)])
		triangles = verts.size() / 3
		if triangles > 0:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_COLOR] = cols
			_mesh = ArrayMesh.new()
			_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		static_layer = _make_layer("Static")
		_map_clip = Control.new()
		_map_clip.name = "MapClip"
		_map_clip.clip_contents = true
		_map_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		static_layer.add_child(_map_clip)
		dynamic_layer = _make_layer("Dynamic")
		dynamic_layer.draw.connect(_draw_dynamic)
		setup_usec = Time.get_ticks_usec() - t0

	func _make_layer(layer_name: String) -> Control:
		var c := Control.new()
		c.name = layer_name
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		return c

	## Màu nhà theo vùng; nhà OpenStreetMap đậm hơn nhà Microsoft cùng vùng.
	static func building_color(region: String, msft: bool) -> Color:
		var base: Color = REGION_COLORS.get(region, REGION_COLORS["corridor"])
		return base if msft else base.darkened(OSM_DARKEN)

	static func _add_poly(verts: PackedVector2Array, cols: PackedColorArray, poly: PackedVector2Array, col: Color) -> void:
		var p: PackedVector2Array = MapBuilder._open(poly)
		if p.size() < 3:
			return
		for i: int in MapBuilder._triangulate(p):
			verts.append(p[i])
			cols.append(col)

	## Dải đường: mỗi đoạn một quad nửa bề rộng `half`, kéo dài `half` ở hai đầu để che khe ở chỗ gấp khúc.
	static func _add_road(verts: PackedVector2Array, cols: PackedColorArray, pts: PackedVector2Array, half: float, col: Color) -> void:
		for i: int in range(pts.size() - 1):
			var d: Vector2 = pts[i + 1] - pts[i]
			if d.length_squared() < 1e-6:
				continue
			d = d.normalized()
			var n := Vector2(-d.y, d.x) * half
			var a: Vector2 = pts[i] - d * half
			var c: Vector2 = pts[i + 1] + d * half
			verts.append_array(PackedVector2Array([a + n, c + n, c - n, a + n, c - n, a - n]))
			for k: int in range(6):
				cols.append(col)

	## Vùng vẽ bản đồ (chừa chỗ chú giải trên, ghi công dưới); nội dung bản đồ bị cắt đúng khung này.
	func content_rect() -> Rect2:
		return Rect2(PAD, TOP_RESERVE, maxf(1.0, size.x - PAD * 2.0), maxf(1.0, size.y - TOP_RESERVE - BOTTOM_RESERVE))

	## Bản đồ -> màn hình: khung bounds vừa khít content_rect().
	func map_xform() -> Transform2D:
		var area: Rect2 = content_rect()
		var s: float = 1.0
		if bounds.size.x > 0.0 and bounds.size.y > 0.0:
			s = minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
		return Transform2D(0.0, Vector2(s, s), 0.0, area.get_center() - bounds.get_center() * s)

	func to_screen(p: Vector2) -> Vector2:
		return map_xform() * p

	## Hotspot thuộc lớp tĩnh: chỉ vẽ lại khi danh sách (vị trí / màu) thật sự đổi.
	func set_hotspots(pts: Array) -> void:
		if pts == hotspot_pts:
			return
		hotspot_pts = pts.duplicate(true)
		_static_dirty = true
		_ensure_static()

	## Lớp động: xếp một lần vẽ lại (người chơi, xe đang đỗ).
	func refresh_dynamic() -> void:
		if dynamic_layer and is_visible_in_tree():
			dynamic_layer.queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
			_ensure_static()
		elif what == NOTIFICATION_PREDELETE and _ci.is_valid():
			RenderingServer.free_rid(_map_ci)
			RenderingServer.free_rid(_ci)
			_map_ci = RID()
			_ci = RID()

	func _ensure_static() -> void:
		if static_layer == null or not is_visible_in_tree() or size.x < 4.0 or size.y < 4.0:
			return
		if _static_dirty or not size.is_equal_approx(_static_size):
			_submit_static()

	## Gửi toàn bộ lệnh vẽ lớp tĩnh (xoá lệnh cũ trước) vào hai canvas item tự quản: _ci (con của "Static") = nền,
	## khung, chú giải, ghi công; _map_ci (con của "Static/MapClip", cắt theo content_rect) = mesh, tuyến, nhãn, cổng,
	## hotspot.
	func _submit_static() -> void:
		var t0: int = Time.get_ticks_usec()
		if not _ci.is_valid():
			_ci = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(_ci, static_layer.get_canvas_item())
			RenderingServer.canvas_item_set_draw_index(_ci, -1)   # nền vẽ trước MapClip (chỉ số cảnh 0)
			_map_ci = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(_map_ci, _map_clip.get_canvas_item())
		RenderingServer.canvas_item_clear(_ci)
		RenderingServer.canvas_item_clear(_map_ci)
		# khung cắt = Control "MapClip" (clip_contents) đặt đúng content_rect; _map_ci vẽ theo toạ độ của RoamMap
		var area: Rect2 = content_rect()
		_map_clip.position = area.position
		_map_clip.size = area.size
		RenderingServer.canvas_item_set_transform(_map_ci, Transform2D(0.0, -area.position))
		_static_dirty = false
		_static_size = size
		var ci: RID = _ci
		var mci: RID = _map_ci
		var font: Font = ThemeDB.fallback_font
		var xf: Transform2D = map_xform()
		RenderingServer.canvas_item_add_rect(ci, Rect2(Vector2.ZERO, size), BG)
		if _mesh:
			RenderingServer.canvas_item_add_mesh(mci, _mesh.get_rid(), xf)
		if route.size() >= 2:
			var pts := PackedVector2Array()
			for p: Vector2 in route:
				pts.append(xf * p)
			RenderingServer.canvas_item_add_polyline(mci, pts, PackedColorArray([CASING]), 6.0, true)
			RenderingServer.canvas_item_add_polyline(mci, pts, PackedColorArray([ROUTE]), 3.0, true)
		for lb: Array in labels:
			_outlined_text(mci, font, xf * (lb[0] as Vector2) + (lb[2] as Vector2), String(lb[1]), 14, TEXT, true)
		var gp: Vector2 = xf * gate
		RenderingServer.canvas_item_add_circle(mci, gp, 8.0, INK)
		RenderingServer.canvas_item_add_circle(mci, gp, 6.0, GATE)
		for h: Array in hotspot_pts:
			var hp: Vector2 = xf * (h[0] as Vector2)
			RenderingServer.canvas_item_add_circle(mci, hp, 7.0, INK)
			RenderingServer.canvas_item_add_circle(mci, hp, 5.0, h[1])
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y), Vector2.ZERO]), PackedColorArray([FRAME]), 2.0)
		# tiêu đề + chú giải (hai dòng) + ghi công (hai dòng)
		font.draw_string(ci, Vector2(PAD, 28.0), "BẢN ĐỒ  ·  [M] đóng", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
		var x: float = PAD
		var y1: float = 52.0
		x = _legend(ci, font, x, y1, "split", REGION_COLORS["vinhomes"], "Vinhomes Grand Park")
		x = _legend(ci, font, x, y1, "split", REGION_COLORS["corridor"], "dọc tuyến đường")
		x = _legend(ci, font, x, y1, "split", REGION_COLORS["campus"], "khu campus FPTU")
		font.draw_string(ci, Vector2(x, y1), "(nửa đậm: nhà OpenStreetMap · nửa nhạt: nhà Microsoft)", HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_SIZE, DIM)
		x = PAD
		var y2: float = 72.0
		x = _legend(ci, font, x, y2, "rect", WATER, "nước")
		x = _legend(ci, font, x, y2, "rect", AREA_COLORS["park"], "công viên")
		x = _legend(ci, font, x, y2, "line", ROAD_MAJOR, "đường lớn")
		x = _legend(ci, font, x, y2, "line", ROAD_MINOR, "đường nhỏ")
		x = _legend(ci, font, x, y2, "route", ROUTE, "tuyến BE6 → FPTU 5,5 km")
		x = _legend(ci, font, x, y2, "dot", GATE, "cổng FPTU")
		x = _legend(ci, font, x, y2, "dot", Color("#F1C40F"), "điểm nóng [E] (màu theo màn)")
		x = _legend(ci, font, x, y2, "dot", Color.WHITE, "bạn")
		_legend(ci, font, x, y2, "diamond", BIKE, "xe máy đang đỗ")
		font.draw_string(ci, Vector2(PAD, size.y - 30.0), ATTR_OSM, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_SIZE, DIM)
		font.draw_string(ci, Vector2(PAD, size.y - 12.0), ATTR_MSFT, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_SIZE, DIM)
		static_draws += 1
		static_draw_usec = Time.get_ticks_usec() - t0

	## Một mục chú giải tại đường chân chữ y: ô mẫu 14 x 10 px + nhãn; trả về x cho mục kế tiếp.
	func _legend(ci: RID, font: Font, x: float, y: float, kind: String, col: Color, text: String) -> float:
		var c := Vector2(x + 7.0, y - 5.0)
		match kind:
			"split":
				RenderingServer.canvas_item_add_rect(ci, Rect2(x, y - 10.0, 7.0, 10.0), col.darkened(OSM_DARKEN))
				RenderingServer.canvas_item_add_rect(ci, Rect2(x + 7.0, y - 10.0, 7.0, 10.0), col)
			"rect":
				RenderingServer.canvas_item_add_rect(ci, Rect2(x, y - 10.0, 14.0, 10.0), col)
			"line":
				RenderingServer.canvas_item_add_line(ci, Vector2(x, y - 5.0), Vector2(x + 14.0, y - 5.0), col, 3.0)
			"route":
				RenderingServer.canvas_item_add_line(ci, Vector2(x, y - 5.0), Vector2(x + 14.0, y - 5.0), CASING, 6.0)
				RenderingServer.canvas_item_add_line(ci, Vector2(x, y - 5.0), Vector2(x + 14.0, y - 5.0), col, 3.0)
			"dot":
				RenderingServer.canvas_item_add_circle(ci, c, 6.0, INK)
				RenderingServer.canvas_item_add_circle(ci, c, 4.5, col)
			"diamond":
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([c + Vector2(0.0, -6.0), c + Vector2(6.0, 0.0), c + Vector2(0.0, 6.0), c + Vector2(-6.0, 0.0)]), PackedColorArray([col]))
		font.draw_string(ci, Vector2(x + 19.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_SIZE, DIM)
		return x + 19.0 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_SIZE).x + 16.0

	## Chữ có viền tối (đọc được trên nền nhà / đường), căn giữa tại pos khi centred.
	static func _outlined_text(ci: RID, font: Font, pos: Vector2, text: String, font_size: int, col: Color, centred: bool) -> void:
		var p: Vector2 = pos
		if centred:
			p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
		font.draw_string_outline(ci, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, INK)
		font.draw_string(ci, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)

	## Lớp động (tín hiệu draw của "Dynamic"): xe đang đỗ + chấm người chơi có vạch hướng.
	func _draw_dynamic() -> void:
		var t0: int = Time.get_ticks_usec()
		var layer: Control = dynamic_layer
		var xf: Transform2D = map_xform()
		var font: Font = ThemeDB.fallback_font
		if bike_shown:
			var bp: Vector2 = xf * bike_pos
			var dia := PackedVector2Array([bp + Vector2(0.0, -8.0), bp + Vector2(8.0, 0.0), bp + Vector2(0.0, 8.0), bp + Vector2(-8.0, 0.0)])
			layer.draw_colored_polygon(dia, BIKE)
			layer.draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), INK, 1.5)
			layer.draw_string_outline(font, bp + Vector2(11.0, 5.0), "XE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, INK)
			layer.draw_string(font, bp + Vector2(11.0, 5.0), "XE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BIKE)
			layer.draw_string(font, Vector2(PAD, 28.0), "Xe máy đang đỗ cách %d m" % bike_dist, HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, 15, BIKE)
		var pp: Vector2 = xf * player_pos
		var dir: Vector2 = player_dir.normalized() if player_dir.length_squared() > 1e-6 else Vector2(0.0, -1.0)
		layer.draw_line(pp, pp + dir * 20.0, INK, 6.0)
		layer.draw_line(pp, pp + dir * 19.0, Color.WHITE, 3.0)
		layer.draw_circle(pp, 8.5, INK)
		layer.draw_circle(pp, 6.5, Color.WHITE)
		dynamic_draws += 1
		dynamic_draw_usec = Time.get_ticks_usec() - t0
