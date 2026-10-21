# File: res://scripts/FreeRoam.gd
# THẾ GIỚI MỞ trên bản đồ thật (plan Task 5, docs/superpowers/plans/2026-10-22-real-map-world.md):
#   - 3 vùng MapBuilder (vinhomes, corridor lod 1, campus) từ assets/data/mapdata.json + campus FPTU thật
#     (FPTUCampusBuilder.real_plot_transform(), quay 136°, opts walk_colliders: vỉa hè/bó vỉa/thảm cổng có va chạm)
#     + HUTECH đối diện (không vẽ lại dải D1 xa).
#   - Mặt đất: hình vuông 12 km chia ô GROUND_TILE m, khoét đúng các mặt nước (MapBuilder._water_polygons) -> cùng
#     các mảnh đó dựng mặt cỏ (y = -0,05) và sàn đi bộ ConcavePolygonShape3D (y = 0). Dưới đó một WorldBoundaryShape3D
#     ở mực nước (MapBuilder.WATER_Y) để không ai rơi mãi, và tường bờ kênh vô hình cao BANK_WALL_H dọc mép mọi mặt
#     nước (chừa khe nơi đường / lối đi bộ cắt qua) để không đi bộ hay xuống xe vào kênh.
#   - Spawn: MapData.spawn_transform() (6 m ngoài cửa sảnh BE6, quay lưng vào toà tháp) hoặc StageManager.roam_spawn
#     khi quay về từ một màn chơi; điểm spawn được kiểm bằng capsule người chơi (intersect_shape) + tia tìm sàn, nếu vướng
#     thì dò ra ngoài theo vòng 1 m tới SPAWN_SEARCH_M m, cuối cùng về spawn BE6. Người chơi = ThirdPersonController;
#     xe máy = PlayerBike.tscn (ẩn tới khi [F]; khi đỗ vẫn là vật cản: disable_mode KEEP_ACTIVE).
#   - Hotspot Area3D "Hotspot_<StageID>" (bán kính 2,5 m, cột sáng + Label3D) đều ở MẶT ĐẤT đi tới được: sân BE6
#     (Màn 1), cổng sau (Màn 2), cửa kính sảnh thông tầng cánh phải nhìn ra sân trong (Lab 402: Màn 3 ban ngày / Màn 6
#     ban đêm), đầu sân bóng phía làn bãi xe ngoài hàng rào (Màn 4), căn tin (Màn 5), mặt sân trong của module chứa
#     phòng 311 (Extra). [E] trong hotspot -> StageManager.start_stage_from_roam() (roam_spawn = return_spawn: 3,5 m từ
#     hotspot về phía tâm sân trong / về spawn BE6, đã kiểm chỗ trống).
#   - HUD (anchors): gợi ý đáy giữa, giờ trong ngày trên trái, FPS + khoảng cách tới cổng FPTU trên phải.
#     [T] đổi preset giờ (GameFX.TOD_PRESETS ngoài trời + đêm; luôn áp lên Environment gốc của cảnh), [M] bản đồ
#     (vẽ bằng _draw, có xe đang đỗ), [Z]/[C] xoay camera, [ESC] tạm dừng (StageManager).
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
const BANK_WALL_H: float = 1.0           # tường bờ kênh vô hình: từ dưới mặt nước lên 1 m trên mặt đất
const BANK_GAP_MARGIN: float = 0.6       # khe tường ở chỗ đường cắt mép nước: nửa bề rộng đường + lề này
const BANK_GAP_MAX: float = 30.0
const ROAD_HASH_CELL: float = 64.0
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
const HINT_DEFAULT: String = "[WASD] đi · [Shift] chạy · [Z]/[C] xoay camera · [F] xe máy · [T] giờ trong ngày · [M] bản đồ · [ESC] tạm dừng"
const HINT_RIDING: String = "[F] xuống xe · [W]/[S] ga/phanh · [A]/[D] lái · [SPACE] drift · [H] còi"
const HINT_NO_DISMOUNT: String = "Không có chỗ trống cạnh xe để xuống (nước / tường / vật cản) – chạy ra chỗ rộng rồi bấm [F]"
const TOD_NAMES: Dictionary = {"dawn": "Bình minh 06:00", "morning": "Buổi sáng 07:30", "noon": "Giữa trưa 11:30", "night": "Đêm khuya 23:00"}
const HOTSPOT_COLORS: Dictionary = {1: Color("#F37021"), 2: Color("#3498DB"), 3: Color("#2ECC71"), 4: Color("#E74C3C"), 5: Color("#F1C40F"), 6: Color("#9B59B6"), 7: Color("#1ABC9C")}

@onready var world: Node3D = $World
@onready var hud: CanvasLayer = $HUD

var md: MapData
var player: ThirdPersonController
var bike: PlayerBike
var mounted: bool = false
var bike_parked: bool = false
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
var tod_label: Label
var stats_label: Label
var map_overlay: RoamMap
var _hud_timer: float = 0.0
var _lab_hotspot: Area3D = null
var _base_env: Environment = null
var _hint_flash: String = ""
var _hint_flash_t: float = 0.0
var _probe_capsule: CapsuleShape3D


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
	_build_ground()
	_build_regions()
	_build_campus()
	_build_player()
	_build_bike()
	_build_hotspots()
	_build_hud()
	build_ms = Time.get_ticks_msec() - t0
	_apply_spawn()
	for k: String in GameFXScript.TOD_PRESETS.keys():
		var tod: Dictionary = GameFXScript.TOD_PRESETS[k]
		if bool(tod.get("outdoor", false)) or k == "night":
			tod_cycle.append(k)
	set_time_of_day("morning")
	player.camera.make_current()
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("hub_key_blocked", true)
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_play"):
		fx.music_play("menu", 0.15)
	print("FreeRoam: world built in %d ms" % build_ms)


func _exit_tree() -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("hub_key_blocked", false)
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
	water_floor.position = Vector3(centre.x, MapBuilder.WATER_Y, centre.y)
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


## Tường bờ vô hình dọc mép mọi mặt nước, chừa khe nơi tim một con đường / lối đi bộ cắt mép nước (cầu, cống).
func _build_bank_walls(water: Array) -> void:
	var segs: Array = []          # [Vector2 a, Vector2 b, float half_width]
	var seg_cells: Dictionary = {}  # Vector2i -> Array[int] (ô ROAD_HASH_CELL m)
	for r: Dictionary in md.roads():
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		if pts.size() < 2:
			continue
		var w: float = float(r.get("width", 6.0))
		if int(r.get("lanes", 0)) <= 0:
			w = clampf(w, 1.5, 2.5)   # lối đi bộ: cùng bề rộng MapBuilder vẽ
		for si: int in range(pts.size() - 1):
			var id: int = segs.size()
			segs.append([pts[si], pts[si + 1], w * 0.5])
			for cell: Vector2i in _cells_of(pts[si], pts[si + 1], 0.0):
				if not seg_cells.has(cell):
					seg_cells[cell] = []
				(seg_cells[cell] as Array).append(id)
	var faces := PackedVector3Array()
	var y0: float = MapBuilder.WATER_Y - 0.3
	var y1: float = GROUND_COLLIDER_Y + BANK_WALL_H
	for poly: PackedVector2Array in water:
		var ring: PackedVector2Array = MapBuilder._open(poly)
		var n: int = ring.size()
		if n < 3:
			continue
		# 1) chỗ đường cắt mép nước: [điểm cắt, bán kính khe]
		var crossings: Array = []
		for i: int in range(n):
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % n]
			var e: Vector2 = b - a
			if e.length_squared() < 1e-6:
				continue
			var eu: Vector2 = e.normalized()
			var seen: Dictionary = {}
			for cell: Vector2i in _cells_of(a, b, 0.0):
				for id: int in seg_cells.get(cell, []):
					if seen.has(id):
						continue
					seen[id] = true
					var s: Array = segs[id]
					var x: Variant = Geometry2D.segment_intersects_segment(a, b, s[0], s[1])
					if x == null:
						continue
					var rd: Vector2 = (s[1] as Vector2) - (s[0] as Vector2)
					var sin_a: float = absf(eu.cross(rd.normalized())) if rd.length_squared() > 1e-6 else 1.0
					crossings.append([x, minf(BANK_GAP_MAX, (float(s[2]) + BANK_GAP_MARGIN) / maxf(0.25, sin_a))])
		# 2) mỗi cạnh: phần không nằm trong khe nào -> 1 quad đứng
		for i: int in range(n):
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % n]
			var len_e: float = a.distance_to(b)
			if len_e < 0.01:
				continue
			var eu: Vector2 = (b - a) / len_e
			var gaps: Array = []
			for c: Array in crossings:
				var xp: Vector2 = c[0]
				var r: float = c[1]
				var rel: Vector2 = xp - a
				var tc: float = rel.dot(eu)
				var dp: float = absf(rel.cross(eu))
				if dp >= r:
					continue
				var hw: float = sqrt(r * r - dp * dp)
				if tc + hw <= 0.0 or tc - hw >= len_e:
					continue
				gaps.append([maxf(0.0, tc - hw), minf(len_e, tc + hw)])
			for run: Array in _free_intervals(gaps, len_e):
				var p0: Vector2 = a + eu * float(run[0])
				var p1: Vector2 = a + eu * float(run[1])
				var v0 := Vector3(p0.x, y0, p0.y)
				var v1 := Vector3(p1.x, y0, p1.y)
				var v2 := Vector3(p1.x, y1, p1.y)
				var v3 := Vector3(p0.x, y1, p0.y)
				faces.append_array(PackedVector3Array([v0, v1, v2, v0, v2, v3]))
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


static func _cells_of(a: Vector2, b: Vector2, grow: float) -> Array:
	var lo := Vector2(minf(a.x, b.x) - grow, minf(a.y, b.y) - grow)
	var hi := Vector2(maxf(a.x, b.x) + grow, maxf(a.y, b.y) + grow)
	var out: Array = []
	for cx: int in range(int(floor(lo.x / ROAD_HASH_CELL)), int(floor(hi.x / ROAD_HASH_CELL)) + 1):
		for cz: int in range(int(floor(lo.y / ROAD_HASH_CELL)), int(floor(hi.y / ROAD_HASH_CELL)) + 1):
			out.append(Vector2i(cx, cz))
	return out


## Phần bù của các khoảng [t0, t1] trong [0, length] (bỏ mẩu < 5 cm).
static func _free_intervals(gaps: Array, length: float) -> Array:
	if gaps.is_empty():
		return [[0.0, length]]
	gaps.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var out: Array = []
	var cur: float = 0.0
	for gp: Array in gaps:
		if float(gp[0]) > cur + 0.05:
			out.append([cur, float(gp[0])])
		cur = maxf(cur, float(gp[1]))
	if cur < length - 0.05:
		out.append([cur, length])
	return out


func _build_regions() -> void:
	var common: Dictionary = {"skip_building_ids": SKIP_BUILDING_IDS, "skip_area_ids": SKIP_AREA_IDS}
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
	FPTUCampusBuilder.build_authentic_campus(world, campus_xf.origin, FPTUCampusBuilder.REAL_ROT_Y_DEG, {"colliders": true, "grass": true, "walk_colliders": true})
	var frame := Node3D.new()
	frame.name = "CampusFrame"
	frame.transform = campus_xf
	world.add_child(frame)
	FPTUCampusBuilder.build_hutech(frame, FPTUCampusBuilder.hutech_origin_local(), FPTUCampusBuilder.make_materials(), true, false)


func _build_player() -> void:
	player = ThirdPersonController.new()
	player.name = "Player"
	add_child(player)


func _build_bike() -> void:
	bike = BIKE_SCENE.instantiate() as PlayerBike
	bike.name = "Bike"
	bike.road_path = null
	bike.lane_clamp_enabled = false
	bike.fallback_fall_y = -5.0
	# xe đang đỗ (PROCESS_MODE_DISABLED) vẫn là vật cản: không bị gỡ khỏi không gian vật lý
	bike.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	add_child(bike)
	bike.chase_cam.current = false
	bike.visible = false
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	bike.global_position = Vector3(0.0, -50.0, 0.0)


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
## đặt trên đó không chạm vật nào. Trả về điểm sàn (Vector3) hoặc null.
func free_spot_at(p: Vector3, base_y: float, exclude: Array[RID] = []) -> Variant:
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
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe_capsule
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, fy + SPOT_LIFT + PLAYER_HEIGHT * 0.5, p.z))
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
			mi.material_override = _glow_material(col, float(pair[1]))
	var key: Label3D = _lab_hotspot.get_node_or_null("Key") as Label3D
	if key:
		key.modulate = col


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
	bike.global_position = pos + Vector3(0.0, 0.25, 0.0)
	bike.rotation = Vector3(0.0, yaw, 0.0)
	bike.velocity = Vector3.ZERO
	bike.current_speed_ms = 0.0
	bike.fallback_respawn = pos + Vector3(0.0, 0.8, 0.0)
	bike.chase_cam.make_current()
	player.controls_enabled = false
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	active_hotspot = null
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_play"):
		fx.music_play("ride", 0.3)


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
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_play"):
		fx.music_play("menu", 0.15)
	return true


func toggle_bike() -> void:
	if mounted:
		dismount_bike()
	else:
		mount_bike()


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
	_refresh_lab_hotspot()
	if tod_label:
		tod_label.text = "🕒 %s · [T] đổi giờ" % String(TOD_NAMES.get(key, key))


func cycle_time_of_day() -> void:
	if tod_cycle.is_empty():
		return
	var i: int = tod_cycle.find(tod_preset)
	set_time_of_day(tod_cycle[(i + 1) % tod_cycle.size()])


func toggle_map() -> void:
	if map_overlay:
		map_overlay.visible = not map_overlay.visible
		if map_overlay.visible:
			_hud_timer = 0.0
			map_overlay.queue_redraw()


## Gợi ý tạm thời (HINT_FLASH_S giây) đè lên dòng gợi ý đáy.
func flash_hint(text: String) -> void:
	_hint_flash = text
	_hint_flash_t = HINT_FLASH_S
	_hud_timer = 0.0
	if hint_label:
		hint_label.text = text


func _build_hud() -> void:
	var hint_panel: PanelContainer = GameFXScript.anchored_panel(hud, Control.PRESET_CENTER_BOTTOM, Vector2(760, 0), 24, Color("#F37021"))
	hint_label = GameFXScript.make_label(HINT_DEFAULT, 15, Color("#F4F5F6"))
	hint_panel.add_child(hint_label)
	var tod_panel: PanelContainer = GameFXScript.anchored_panel(hud, Control.PRESET_TOP_LEFT, Vector2(0, 0), 20, Color("#F1C40F"))
	tod_label = GameFXScript.make_label("🕒 —", 14, Color("#F1C40F"), HORIZONTAL_ALIGNMENT_LEFT)
	tod_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tod_panel.add_child(tod_label)
	var stats_panel: PanelContainer = GameFXScript.anchored_panel(hud, Control.PRESET_TOP_RIGHT, Vector2(0, 0), 20, Color("#2ECC71"))
	stats_label = GameFXScript.make_label("FPS — · Cổng FPTU — m", 14, Color("#DFE6E9"), HORIZONTAL_ALIGNMENT_RIGHT)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_panel.add_child(stats_label)
	map_overlay = RoamMap.new()
	map_overlay.name = "MapOverlay"
	map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_overlay.offset_left = 48.0
	map_overlay.offset_top = 48.0
	map_overlay.offset_right = -48.0
	map_overlay.offset_bottom = -48.0
	map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.visible = false
	map_overlay.setup(md, gate_xz)
	hud.add_child(map_overlay)


func _hint_text() -> String:
	if _hint_flash_t > 0.0:
		return _hint_flash
	if active_hotspot:
		return "[E] Chơi %s" % _stage_title(int(active_hotspot.get_meta("stage_id")))
	if mounted:
		return HINT_RIDING
	if bike_parked:
		if can_mount():
			return "[F] lên xe máy · " + HINT_DEFAULT
		return HINT_DEFAULT.replace("[F] xe máy", "[F] xe máy cách %d m" % bike_distance_m())
	return HINT_DEFAULT


func _physics_process(delta: float) -> void:
	if player == null or bike == null:
		return
	_update_hotspot()
	if _hint_flash_t > 0.0:
		_hint_flash_t -= delta
	_hud_timer -= delta
	if _hud_timer > 0.0:
		return
	_hud_timer = HUD_REFRESH
	var pos: Vector3 = roam_position()
	var dist: float = Vector2(pos.x, pos.z).distance_to(gate_xz)
	if stats_label:
		stats_label.text = "FPS %d · Cổng FPTU %s m" % [int(Engine.get_frames_per_second()), _thousands(int(dist))]
	if hint_label:
		hint_label.text = _hint_text()
	if map_overlay and map_overlay.visible:
		var fwd: Vector3 = -bike.global_transform.basis.z if mounted else player.facing_dir()
		map_overlay.player_pos = Vector2(pos.x, pos.z)
		map_overlay.player_dir = Vector2(fwd.x, fwd.z)
		map_overlay.bike_shown = bike_parked and not mounted
		map_overlay.bike_pos = Vector2(bike.global_position.x, bike.global_position.z)
		map_overlay.bike_dist = bike_distance_m()
		map_overlay.hotspot_pts.clear()
		for h: Area3D in hotspots:
			map_overlay.hotspot_pts.append([Vector2(h.global_position.x, h.global_position.z), HOTSPOT_COLORS.get(int(h.get_meta("stage_id")), Color.WHITE)])
		map_overlay.queue_redraw()


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


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_E:
			if active_hotspot and not mounted:
				if start_hotspot_stage(active_hotspot):
					get_viewport().set_input_as_handled()
		KEY_F:
			toggle_bike()
			get_viewport().set_input_as_handled()
		KEY_T:
			cycle_time_of_day()
			get_viewport().set_input_as_handled()
		KEY_M:
			toggle_map()
			get_viewport().set_input_as_handled()


# ===========================================================================
# BẢN ĐỒ [M]: nhà = hình chữ nhật bao (theo vùng), tuyến BE6 -> FPTU, hotspot, xe đang đỗ, chấm người chơi
# ===========================================================================
class RoamMap extends Control:
	var rects: Array = []            # [Rect2, Color]
	var route := PackedVector2Array()
	var bounds := Rect2()
	var hotspot_pts: Array = []      # [Vector2, Color]
	var player_pos := Vector2.ZERO
	var player_dir := Vector2(0.0, -1.0)
	var gate := Vector2.ZERO
	var bike_shown: bool = false     # xe máy đang đỗ (người chơi đã xuống xe)
	var bike_pos := Vector2.ZERO
	var bike_dist: int = 0

	func setup(md: MapData, gate_xz: Vector2) -> void:
		gate = gate_xz
		var started: bool = false
		for b: Dictionary in md.buildings():
			var pts: PackedVector2Array = MapData.poly(b.get("outer", []))
			if pts.size() < 3:
				continue
			var r := Rect2(pts[0], Vector2.ZERO)
			for p: Vector2 in pts:
				r = r.expand(p)
			var region: String = str(b.get("region", ""))
			var col: Color = Color(0.98, 0.62, 0.3, 0.95)
			if region == "campus":
				col = Color(0.45, 0.78, 0.98, 0.95)
			elif region == "corridor":
				col = Color(0.72, 0.72, 0.7, 0.85)
			rects.append([r, col])
			bounds = r if not started else bounds.merge(r)
			started = true
		route = md.route_points(40.0)
		for p: Vector2 in route:
			bounds = bounds.expand(p) if started else Rect2(p, Vector2.ZERO)
			started = true
		bounds = bounds.grow(150.0)

	func _scale() -> float:
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			return 1.0
		return minf(size.x / bounds.size.x, size.y / bounds.size.y)

	func _to_screen(p: Vector2) -> Vector2:
		return (p - bounds.get_center()) * _scale() + size * 0.5

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.09, 0.88))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.44, 0.13, 0.9), false, 2.0)
		var s: float = _scale()
		for e: Array in rects:
			var r: Rect2 = e[0]
			draw_rect(Rect2(_to_screen(r.position), r.size * s), e[1])
		if route.size() >= 2:
			var pts := PackedVector2Array()
			for p: Vector2 in route:
				pts.append(_to_screen(p))
			draw_polyline(pts, Color(0.95, 0.44, 0.13, 1.0), 2.5, true)
		var gp: Vector2 = _to_screen(gate)
		draw_circle(gp, 6.0, Color(0.18, 0.8, 0.44))
		for h: Array in hotspot_pts:
			draw_circle(_to_screen(h[0]), 5.0, h[1])
		var font: Font = ThemeDB.fallback_font
		if bike_shown:
			var bp: Vector2 = _to_screen(bike_pos)
			var dia := PackedVector2Array([bp + Vector2(0.0, -8.0), bp + Vector2(8.0, 0.0), bp + Vector2(0.0, 8.0), bp + Vector2(-8.0, 0.0)])
			draw_colored_polygon(dia, Color(0.3, 0.85, 1.0))
			draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), Color(0.02, 0.05, 0.1), 1.5)
			draw_string(font, bp + Vector2(11.0, 5.0), "XE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.85, 1.0))
			draw_string(font, Vector2(16.0, 52.0), "Ô thoi xanh lơ: xe máy đang đỗ (cách %d m)" % bike_dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.3, 0.85, 1.0))
		var pp: Vector2 = _to_screen(player_pos)
		draw_circle(pp, 7.0, Color.WHITE)
		draw_line(pp, pp + player_dir.normalized() * 18.0, Color.WHITE, 3.0)
		draw_string(font, Vector2(16.0, 30.0), "BẢN ĐỒ · [M] đóng · cam: Vinhomes Grand Park · xanh: khu campus · vạch cam: tuyến BE6 → FPTU · chấm xanh: cổng FPTU", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.96, 0.96, 0.96))
		draw_string(font, Vector2(16.0, size.y - 14.0), "Bản đồ (c) OpenStreetMap contributors (ODbL)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.75, 0.75))
