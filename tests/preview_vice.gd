# File: res://tests/preview_vice.gd
# Ảnh kiểm tra phong cách Vice City bằng CODE GAME THẬT (kế nhiệm tests/preview_vice_lookdev.gd, plan VC-2 Step 5):
# cùng 4 góc của look-dev + spawn BE6 của thế giới mở + vạch xuất phát Màn 1. Cần cửa sổ render, KHÔNG --headless:
#   godot --path . --resolution 1280x720 --script tests/preview_vice.gd
# Pha 1 – thế giới look-dev: MapBuilder vùng vinhomes (opts.palms: rừng cọ MultiMesh dọc đường thật) + campus FPTU trên lô
#   đất thật (FPTUCampusBuilder opts.palms: cau sân trước thành cọ v2 + hai hàng cọ Đường D1) + HUTECH + đoạn D1 mô hình +
#   nhân vật; ánh sáng = ViceStyle.apply(world, preset) (look sunset / day / night thật của game, không môi trường riêng).
#     palms_street_be6_sunset, palms_air_beverly_sunset, palms_gate_d1_day, palms_street_be6_night
# Pha 2 – scenes/FreeRoam.tscn (phong cách vice, preset dawn): palms_roam_spawn (camera người chơi ở spawn BE6).
# Pha 3 – scenes/Main.tscn (Màn 1): palms_s1_start (góc s1_01_start_be6 của tests/preview_stages.gd; vùng vinhomes lod 2
#   của Màn 1 không có cọ) + palms_s1_nguyen_xien (vùng corridor: cọ đứng sau hàng cây ven tuyến, palm_verge 7,5 m).
# FPS in ra = trung bình MEASURE frame ngay trước khi chụp. Ảnh: vice_<tên>.png trong user://preview (PREVIEW_DIR thay
# thư mục). Biến môi trường chỉ cho preview: PREVIEW_NOVSYNC=1 tắt V-Sync để đo FPS thật, PREVIEW_PALMS=0 dựng pha 1
# KHÔNG cọ (đo chi phí cọ), PREVIEW_ONLY=<tên,...> chỉ chụp các ảnh đó (pha 2 / 3 bỏ qua nếu không có ảnh nào của nó).
extends SceneTree

const SETTLE: int = 100
const MEASURE: int = 60
const WATCHDOG_FRAMES: int = 9000
## Màn 1: vạch xuất phát (= s1_01_start_be6 của preview_stages) + Nguyễn Xiển (vùng corridor: cọ sau hàng cây ven tuyến)
const S1_SHOTS: Array = [
	{"name": "palms_s1_start", "cam_off": 24.0, "cam_lat": 3.6, "cam_h": 2.4, "look_off": 0.0, "look_lat": -1.0, "look_h": 9.0, "fov": 72.0},
	{"name": "palms_s1_nguyen_xien", "mark": "nguyen_xien", "cam_off": 40.0, "cam_lat": 1.8, "cam_h": 2.6, "look_off": 130.0, "look_lat": 0.0, "look_h": 3.0, "fov": 70.0},
]

var md: MapData
var out_dir: String = ""
var palms: bool = true
var only: PackedStringArray = []
var fx: Node
# pha 1
var world: Node3D
var cam: Camera3D
var shots: Array = []
var shot_i: int = -1
# pha 2 / 3
var scene: Node = null
var s1_shots: Array = []
var s1_i: int = 0
var phase: int = 1
var frames: int = 0
var local_f: int = 0
var t_measure: int = 0
var results: Array[String] = []


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	fx = root.get_node("GameFX")
	# autoload GameFX nạp settings.cfg trong _ready (sau _initialize): ép phong cách vice ngay sau tín hiệu ready; thế
	# giới pha 1 dựng ở frame đầu của vòng lặp (sau đó) để nhân vật theo kiểu vice (không viền toon, đầu 1.15)
	if fx.is_node_ready():
		fx.call("set_art_style", "vice", false)
	else:
		fx.ready.connect(func() -> void: fx.call("set_art_style", "vice", false), CONNECT_ONE_SHOT)
	if OS.get_environment("PREVIEW_NOVSYNC") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	palms = OS.get_environment("PREVIEW_PALMS") != "0"
	only = OS.get_environment("PREVIEW_ONLY").replace(" ", "").split(",", false)
	md = MapData.load_default()
	print("PREVIEW VICE: palms=%s -> %s" % [str(palms), out_dir])


# ---------------------------------------------------------------------------------------------------------------
# PHA 1: thế giới look-dev dựng bằng builder thật
# ---------------------------------------------------------------------------------------------------------------
func _build_world() -> void:
	var t0: int = Time.get_ticks_msec()
	world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	world.add_child(we)
	world.add_child(DirectionalLight3D.new())
	cam = Camera3D.new()
	cam.far = 4000.0
	world.add_child(cam)
	cam.current = true
	MapBuilder.build_region(world, md, "vinhomes", {"labels": false, "palms": palms})
	var m: Dictionary = FPTUCampusBuilder.make_materials()
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var campus_root: Node3D = FPTUCampusBuilder.build_authentic_campus(world, xf.origin, rad_to_deg(xf.basis.get_euler().y), {"grass": true, "palms": palms})
	FPTUCampusBuilder.build_hutech(campus_root, FPTUCampusBuilder.hutech_origin_local(), m)
	FPTUCampusBuilder.build_d1_road_piece(campus_root, FPTUCampusBuilder.ROAD_CENTER_V, -160.0, 360.0, m, 0.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000.0, 12000.0)
	ground.mesh = pm
	ground.position = Vector3(2000.0, -0.05, -200.0)
	ground.material_override = m["grass"]
	world.add_child(ground)
	_add_people(xf)
	var n_palms: int = 0
	for f: Node in world.find_children("PalmField", "Node3D", true, false):
		n_palms += int(f.get_meta("palm_count", 0))
	print("  world built in %d ms, %d palms in PalmFields" % [Time.get_ticks_msec() - t0, n_palms])


func _add_people(xf: Transform3D) -> void:
	var sp: Transform3D = md.spawn_transform()
	var fwd: Vector3 = -sp.basis.z
	var side: Vector3 = sp.basis.x
	var presets: Array[String] = ["student_m", "student_f", "casual", "player"]
	for i: int in range(4):
		var c: Node3D = CharacterBuilder.build({"preset": presets[i], "seed": 700 + i * 13, "rigged": true})
		world.add_child(c)
		c.position = sp.origin + fwd * (6.0 + i * 2.2) + side * (-2.5 + i * 1.6)
		c.rotation.y = sp.basis.get_euler().y + (PI if i % 2 == 0 else 0.0)
		CharacterBuilder.set_speed(c, 1.1 if i < 3 else 0.0)
	var gate: Vector3 = FPTUCampusBuilder.main_gate_local()
	for i: int in range(5):
		var c2: Node3D = CharacterBuilder.build({"preset": "student_m" if i % 2 == 0 else "student_f", "seed": 900 + i * 7, "rigged": true})
		world.add_child(c2)
		c2.transform = Transform3D(xf.basis, xf * (gate + Vector3(-4.0 + i * 2.1, 0.0, 3.0 + (i % 2) * 1.5)))
		c2.rotate_y(PI * 0.5 if i % 2 == 0 else -PI * 0.5)
		CharacterBuilder.set_speed(c2, 1.2)


## Cùng 4 góc của look-dev (đoạn đường nội khu dài gần sảnh BE6 nhất, flycam trên The Beverly, D1 trước cổng chính).
func _define_shots() -> void:
	var sp: Transform3D = md.spawn_transform()
	var be6v: Variant = md.landmark("be6_center")
	var be6 := Vector3(float(be6v[0]), 0.0, float(be6v[1]))
	var sp2 := Vector2(sp.origin.x, sp.origin.z)
	var best_d: float = 1.0e9
	var best_p := sp2
	var best_dir := Vector2(1.0, 0.0)
	var best_half: float = 3.0
	for r: Dictionary in md.roads("vinhomes"):
		if int(r.get("lanes", 0)) == 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r["points"])
		for i: int in range(pts.size() - 1):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(sp2, pts[i], pts[i + 1])
			var dd: float = q.distance_to(sp2)
			if dd < best_d and pts[i].distance_to(pts[i + 1]) > 20.0:
				best_d = dd
				best_p = q
				best_dir = (pts[i + 1] - pts[i]).normalized()
				best_half = float(r.get("width", 6.0)) * 0.5
	var nrm2 := Vector2(-best_dir.y, best_dir.x)
	if nrm2.dot(sp2 - best_p) < 0.0:
		nrm2 = -nrm2
	var cam2: Vector2 = best_p + best_dir * 58.0 - nrm2 * (best_half - 1.2)
	var look2: Vector2 = best_p - best_dir * 12.0 + nrm2 * 18.0
	var street_cam := Vector3(cam2.x, 1.7, cam2.y)
	var street_look := Vector3(look2.x, 15.0, look2.y)
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var gate: Vector3 = FPTUCampusBuilder.main_gate_local()
	var gate_cam: Vector3 = xf * Vector3(gate.x - 30.0, 1.7, FPTUCampusBuilder.ROAD_CENTER_V - 3.0)
	var gate_look: Vector3 = xf * Vector3(gate.x + 8.0, 5.0, 10.0)
	shots = [
		{"name": "palms_street_be6_sunset", "pos": street_cam, "look": street_look, "preset": "sunset", "fov": 72.0},
		{"name": "palms_air_beverly_sunset", "pos": be6 + Vector3(-190.0, 110.0, 170.0), "look": be6 + Vector3(40.0, 10.0, 30.0), "preset": "sunset", "fov": 55.0},
		{"name": "palms_gate_d1_day", "pos": gate_cam, "look": gate_look, "preset": "morning", "fov": 62.0},
		{"name": "palms_street_be6_night", "pos": street_cam, "look": street_look, "preset": "night", "fov": 72.0},
	]
	if not only.is_empty():
		shots = shots.filter(func(s: Dictionary) -> bool: return String(s["name"]) in only)


func _begin_world_shot() -> void:
	var s: Dictionary = shots[shot_i]
	cam.fov = float(s["fov"])
	cam.look_at_from_position(s["pos"], s["look"], Vector3.UP)
	cam.make_current()
	ViceStyle.apply(world, String(s["preset"]), int(fx.get("visual_quality")), bool(fx.get("trails_enabled")))


# ---------------------------------------------------------------------------------------------------------------
# PHA 2 / 3: cảnh thật
# ---------------------------------------------------------------------------------------------------------------
func _wanted(name: String) -> bool:
	return only.is_empty() or name in only


func _wanted_s1() -> bool:
	for s: Dictionary in S1_SHOTS:
		if _wanted(String(s["name"])):
			return true
	return false


func _start_roam() -> void:
	scene = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _start_stage1() -> void:
	scene = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	var hud: Node = scene.get_node_or_null("HUD")
	if hud:
		hud.visible = false


## Góc Màn 1 theo offset trên curve RoadPath (như tests/preview_stages.gd): cam_off / look_off tính từ mốc `mark`.
func _stage1_cam(shot: Dictionary) -> bool:
	var rs: Node = scene.get_node_or_null("RoadSystem")
	var path: Path3D = scene.get_node_or_null("RoadSystem/RoadTrack/RoadPath") as Path3D
	if rs == null or path == null or path.curve == null:
		return false
	var base: float = 0.0
	if shot.has("mark"):
		base = float((rs.get("route_marks") as Dictionary).get(shot["mark"], -1.0))
		if base < 0.0:
			return false
	var len: float = path.curve.get_baked_length() - 0.1
	var cx: Transform3D = path.curve.sample_baked_with_rotation(clampf(base + float(shot["cam_off"]), 0.0, len))
	var lx: Transform3D = path.curve.sample_baked_with_rotation(clampf(base + float(shot["look_off"]), 0.0, len))
	var pos: Vector3 = cx.origin + cx.basis.x * float(shot["cam_lat"]) + Vector3(0.0, float(shot["cam_h"]), 0.0)
	var look: Vector3 = lx.origin + lx.basis.x * float(shot["look_lat"]) + Vector3(0.0, float(shot["look_h"]), 0.0)
	var c: Camera3D = root.get_node_or_null("PreviewCam") as Camera3D
	if c == null:
		c = Camera3D.new()
		c.name = "PreviewCam"
		c.far = 6000.0
		root.add_child(c)
	c.fov = float(shot["fov"])
	c.look_at_from_position(pos, look, Vector3.UP)
	c.make_current()
	return true


func _free_scene() -> void:
	if scene:
		scene.queue_free()
		scene = null
	var pc: Node = root.get_node_or_null("PreviewCam")
	if pc:
		pc.queue_free()


func _save(name: String) -> void:
	var mean_fps: float = float(MEASURE) * 1000000.0 / float(maxi(1, Time.get_ticks_usec() - t_measure))
	var img: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join("vice_" + name + ".png")
	var err: int = img.save_png(path)
	var line: String = "%s fps=%.0f" % [name, mean_fps]
	results.append(line)
	print("  saved %s err=%d size=%s fps=%.0f (engine %.0f) style=%s quality=%d palms=%s" % [path, err, img.get_size(), mean_fps, Engine.get_frames_per_second(), String(fx.get("art_style")), int(fx.get("visual_quality")), str(palms)])


## true = ảnh của bước hiện tại đã chụp xong (đếm local_f: đặt góc ở 0, đo từ SETTLE - MEASURE, chụp ở SETTLE).
func _tick_capture(name: String) -> bool:
	local_f += 1
	if local_f == SETTLE - MEASURE:
		t_measure = Time.get_ticks_usec()
	elif local_f == SETTLE:
		_save(name)
		local_f = 0
		return true
	return false


func _process(_delta: float) -> bool:
	frames += 1
	if frames > WATCHDOG_FRAMES:
		push_error("preview_vice watchdog")
		quit(2)
		return true
	match phase:
		1:
			if shot_i < 0:
				if frames == 2:
					_define_shots()
					if not shots.is_empty():
						_build_world()
				if frames < 30:          # shader biên dịch, bộ đếm FPS ổn định
					return false
				if shots.is_empty():
					_end_world()
					return false
				shot_i = 0
				local_f = 0
				_begin_world_shot()
				return false
			if _tick_capture(String(shots[shot_i]["name"])):
				shot_i += 1
				if shot_i >= shots.size():
					_end_world()
				else:
					_begin_world_shot()
		2:
			if scene == null:
				_start_roam()
				local_f = -240                  # FreeRoam._ready ở frame đầu + shader của thế giới mở
				return false
			if local_f == -239:
				scene.call("set_time_of_day", "dawn")
				(scene.get("player").get("camera") as Camera3D).make_current()
			if _tick_capture("palms_roam_spawn"):
				_free_scene()
				phase = 3 if _wanted_s1() else 4
		3:
			if scene == null:
				s1_shots = S1_SHOTS.filter(func(s: Dictionary) -> bool: return _wanted(String(s["name"])))
				s1_i = 0
				_start_stage1()
				local_f = -120
				return false
			if local_f == -60 or (local_f == 0 and s1_i > 0):
				if not _stage1_cam(s1_shots[s1_i]):
					print("  Stage 1 RoadPath / mark missing, skipping %s" % s1_shots[s1_i]["name"])
					_free_scene()
					phase = 4
					return false
			if _tick_capture(String(s1_shots[s1_i]["name"])):
				s1_i += 1
				if s1_i >= s1_shots.size():
					_free_scene()
					phase = 4
		_:
			print("PREVIEW VICE DONE: " + " | ".join(results))
			quit(0)
			return true
	return false


func _end_world() -> void:
	if world:
		world.queue_free()
		world = null
	phase = 2 if _wanted("palms_roam_spawn") else (3 if _wanted_s1() else 4)
