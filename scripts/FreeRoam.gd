# File: res://scripts/FreeRoam.gd
# THẾ GIỚI MỞ trên bản đồ thật (plan Task 5, docs/superpowers/plans/2026-10-22-real-map-world.md):
#   - 3 vùng MapBuilder (vinhomes, corridor lod 1, campus) từ assets/data/mapdata.json + campus FPTU thật
#     (FPTUCampusBuilder.real_plot_transform(), quay 136°) + HUTECH đối diện (không vẽ lại dải D1 xa).
#   - Mặt đất: 1 StaticBody3D WorldBoundaryShape3D tại y = 0 + PlaneMesh 12 km (cỏ của campus builder) tại y = -0,05.
#   - Spawn: MapData.spawn_transform() (6 m ngoài cửa sảnh BE6, quay lưng vào toà tháp) hoặc StageManager.roam_spawn
#     khi quay về từ một màn chơi. Người chơi = ThirdPersonController; xe máy = PlayerBike.tscn (ẩn tới khi [F]).
#   - Hotspot Area3D "Hotspot_<StageID>" (bán kính 2,5 m, cột sáng + Label3D): sân BE6 (Màn 1), cổng sau (Màn 2),
#     cửa Lab 402 (Màn 3 ban ngày / Màn 6 ban đêm), sân bóng (Màn 4), căn tin (Màn 5), phòng 311 (Extra);
#     [E] trong hotspot -> StageManager.start_stage_from_roam() (return_to_roam = true, roam_spawn = cạnh hotspot).
#   - HUD (anchors): gợi ý đáy giữa, giờ trong ngày trên trái, FPS + khoảng cách tới cổng FPTU trên phải.
#     [T] đổi preset giờ (GameFX.TOD_PRESETS ngoài trời + đêm), [M] bản đồ (vẽ bằng _draw), [ESC] tạm dừng (StageManager).
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
const GROUND_MESH_Y: float = -0.05
const HUD_REFRESH: float = 0.2
const HINT_DEFAULT: String = "[WASD] đi · [Shift] chạy · [F] xe máy · [T] giờ trong ngày · [M] bản đồ · [ESC] tạm dừng"
const HINT_RIDING: String = "[F] xuống xe · [W]/[S] ga/phanh · [A]/[D] lái · [SPACE] drift · [H] còi"
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

var hint_label: Label
var tod_label: Label
var stats_label: Label
var map_overlay: RoamMap
var _hud_timer: float = 0.0
var _lab_hotspot: Area3D = null


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
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(centre.x, 0.0, centre.y)
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()   # mặt phẳng y = 0 (Jolt: hộp world_boundary_shape_size = 12 km, project.godot)
	body.add_child(cs)
	world.add_child(body)
	# Mặt cỏ 12 km tại y = -0,05 (dưới mặt đất vùng -0,03, trên mặt nước -0,3): cắt lỗ đúng các mặt nước như
	# MapBuilder làm với mặt đất vùng, nếu không tấm này che kênh đào / hồ (nước nằm dưới nó).
	var grass: StandardMaterial3D = (FPTUCampusBuilder.make_materials()["grass"] as StandardMaterial3D).duplicate()
	grass.uv1_triplanar = true
	grass.uv1_scale = Vector3(0.2, 0.2, 0.2)
	grass.albedo_color = Color(0.84, 0.84, 0.68)
	var half: float = GROUND_SIZE * 0.5
	var square := PackedVector2Array([centre + Vector2(-half, -half), centre + Vector2(half, -half), centre + Vector2(half, half), centre + Vector2(-half, half)])
	var pieces: Array = MapBuilder._subtract([square], MapBuilder._water_polygons(md))
	var batch := MapBuilder.Batch.new()
	for piece: PackedVector2Array in pieces:
		MapBuilder._emit_polygon(batch, piece, GROUND_MESH_Y, Vector3.UP, 0.2)
	var mi: MeshInstance3D = MapBuilder._commit(batch, grass, "GroundPlane")
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "GroundPlane"
		var pm := PlaneMesh.new()
		pm.size = Vector2(GROUND_SIZE, GROUND_SIZE)
		mi.mesh = pm
		mi.material_override = grass
		mi.position = Vector3(centre.x, GROUND_MESH_Y, centre.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)


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
	FPTUCampusBuilder.build_authentic_campus(world, campus_xf.origin, FPTUCampusBuilder.REAL_ROT_Y_DEG, {"colliders": true, "grass": true})
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
	add_child(bike)
	bike.chase_cam.current = false
	bike.visible = false
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	bike.global_position = Vector3(0.0, -50.0, 0.0)


func _apply_spawn() -> void:
	spawn_xf = md.spawn_transform()
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		var rs: Variant = sm.get("roam_spawn")
		if rs is Transform3D:
			spawn_xf = rs
		sm.set("roam_spawn", null)
	player.teleport(spawn_xf.origin, spawn_xf.basis.get_euler().y)
	bike.fallback_respawn = spawn_xf.origin + Vector3(0.0, 0.8, 0.0)


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
	var ring_centre: Vector3 = campus_xf * Vector3(ring_c.get_center().x, 0.0, ring_c.get_center().y)
	var defs: Array = [
		[ids.STAGE_1_RACE, be6_plaza, sp.origin, -1],
		[ids.STAGE_2_PARKING, campus_xf * FPTUCampusBuilder.back_gate_local(), ring_centre, -1],
		[ids.STAGE_3_CLASSROOM, campus_xf * FPTUCampusBuilder.lab402_door(), ring_centre, ids.STAGE_6_CAPSTONE],
		[ids.STAGE_4_VOVINAM, campus_xf * FPTUCampusBuilder.pitch_center_local(), ring_centre, -1],
		[ids.STAGE_5_CANTEEN, campus_xf * FPTUCampusBuilder.canteen_center(), ring_centre, -1],
		[ids.STAGE_EXTRA_EOS, campus_xf * FPTUCampusBuilder.room311_center(), ring_centre, -1],
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
	# điểm spawn khi quay về: 3,5 m về phía mốc (sân BE6 / tâm sân trong), quay mặt vào hotspot; hotspot trên tầng -> y = 0
	var away: Vector3 = anchor - pos
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.001 else Vector3(0.0, 0.0, 1.0)
	var back: Vector3 = pos + away * 3.5
	if pos.y > 2.0:
		back.y = 0.0
	a.set_meta("return_spawn", Transform3D(Basis(Vector3.UP, atan2(away.x, away.z)), back))
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


func can_mount() -> bool:
	if mounted or player == null:
		return false
	if not bike_parked:
		return true
	return player.global_position.distance_to(bike.global_position) <= MOUNT_RANGE


func mount_bike() -> void:
	if mounted or not can_mount():
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


func dismount_bike() -> void:
	if not mounted:
		return
	mounted = false
	bike_parked = true
	bike.current_speed_ms = 0.0
	bike.velocity = Vector3.ZERO
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	var side: Vector3 = bike.global_transform.basis.x
	side.y = 0.0
	side = side.normalized() if side.length_squared() > 0.001 else Vector3(1.0, 0.0, 0.0)
	var pos: Vector3 = bike.global_position + side * 1.3
	pos.y = maxf(bike.global_position.y, 0.0) + 0.05
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.controls_enabled = true
	player.teleport(pos, bike.rotation.y)
	player.camera.make_current()
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_play"):
		fx.music_play("menu", 0.15)


func toggle_bike() -> void:
	if mounted:
		dismount_bike()
	else:
		mount_bike()


# ===========================================================================
# GIỜ TRONG NGÀY / BẢN ĐỒ / HUD
# ===========================================================================
## Đổi preset ánh sáng (GameFX.upgrade_scene_visuals) chỉ khi preset thật sự đổi.
func set_time_of_day(preset: String) -> void:
	var key: String = String(GameFXScript.TOD_ALIASES.get(preset, preset))
	if not GameFXScript.TOD_PRESETS.has(key):
		return
	if key == tod_preset:
		return
	tod_preset = key
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
			map_overlay.queue_redraw()


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


func _physics_process(delta: float) -> void:
	if player == null or bike == null:
		return
	_update_hotspot()
	_hud_timer -= delta
	if _hud_timer > 0.0:
		return
	_hud_timer = HUD_REFRESH
	var pos: Vector3 = roam_position()
	var dist: float = Vector2(pos.x, pos.z).distance_to(gate_xz)
	if stats_label:
		stats_label.text = "FPS %d · Cổng FPTU %s m" % [int(Engine.get_frames_per_second()), _thousands(int(dist))]
	if hint_label:
		if active_hotspot:
			hint_label.text = "[E] Chơi %s" % _stage_title(int(active_hotspot.get_meta("stage_id")))
		elif mounted:
			hint_label.text = HINT_RIDING
		elif bike_parked and can_mount():
			hint_label.text = "[F] lên xe máy · " + HINT_DEFAULT
		else:
			hint_label.text = HINT_DEFAULT
	if map_overlay and map_overlay.visible:
		var fwd: Vector3 = -bike.global_transform.basis.z if mounted else player.facing_dir()
		map_overlay.player_pos = Vector2(pos.x, pos.z)
		map_overlay.player_dir = Vector2(fwd.x, fwd.z)
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
# BẢN ĐỒ [M]: nhà = hình chữ nhật bao (theo vùng), tuyến BE6 -> FPTU, hotspot, chấm người chơi
# ===========================================================================
class RoamMap extends Control:
	var rects: Array = []            # [Rect2, Color]
	var route := PackedVector2Array()
	var bounds := Rect2()
	var hotspot_pts: Array = []      # [Vector2, Color]
	var player_pos := Vector2.ZERO
	var player_dir := Vector2(0.0, -1.0)
	var gate := Vector2.ZERO

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
		var pp: Vector2 = _to_screen(player_pos)
		draw_circle(pp, 7.0, Color.WHITE)
		draw_line(pp, pp + player_dir.normalized() * 18.0, Color.WHITE, 3.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(16.0, 30.0), "BẢN ĐỒ · [M] đóng · cam: Vinhomes Grand Park · xanh: khu campus · vạch cam: tuyến BE6 → FPTU · chấm xanh: cổng FPTU", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.96, 0.96, 0.96))
		draw_string(font, Vector2(16.0, size.y - 14.0), "Bản đồ (c) OpenStreetMap contributors (ODbL)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.75, 0.75))
