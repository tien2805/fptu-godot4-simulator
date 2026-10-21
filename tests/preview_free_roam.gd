# File: res://tests/preview_free_roam.gd
# Chụp ảnh kiểm tra thế giới mở (plan Task 5). Cần cửa sổ render, KHÔNG --headless:
#   godot --path . --script tests/preview_free_roam.gd
# Nạp scenes/FreeRoam.tscn (autoload GameFX + StageManager được tiêm như các test khác) rồi lưu PNG vào user://preview/:
#   roam_01_spawn_be6        – góc nhìn thứ ba tại điểm spawn BE6 (quay lưng vào tháp, nhìn ra đường nội bộ)
#   roam_02_canal            – bờ kênh đào Hoa giấy (The Beverly)
#   roam_03_vincom           – trước VinMall Grand Park (Vincom Mega Mall)
#   roam_04_ride_nguyen_xien – đang chạy xe máy trên Nguyễn Xiển (camera đuổi của PlayerBike)
#   roam_05_campus_gate_from_d1 – đứng trên D1 nhìn về cổng chính FPTU
#   roam_06_campus_air       – flycam trên campus
#   roam_07_nguyen_van_tang  – chạy xe máy trên Nguyễn Văn Tăng (tuyến 3 350 m), dãy nhà ống Microsoft hai bên đường
# In FPS ở mỗi ảnh: trung bình MEASURE frame ngay trước khi chụp (sau dịch chuyển, SDFGI dựng lại cascade và shader
# biên dịch trong vài frame đầu, nên SETTLE - MEASURE frame đầu không tính) + bộ đếm Engine lúc chụp.
# Biến môi trường chỉ dùng cho ảnh preview (không ghi settings.cfg): VICE_STYLE=vice|classic ép phong cách đồ hoạ,
# PREVIEW_DIR=<thư mục tuyệt đối> thay cho user://preview, PREVIEW_NOVSYNC=1 tắt V-Sync để đo FPS thật.
extends SceneTree

const SETTLE: int = 96
const MEASURE: int = 60

var roam: Node3D
var player: CharacterBody3D
var bike: CharacterBody3D
var md: MapData
var out_dir: String = ""
var frames: int = 0
var shot_idx: int = -1
var shots: Array = []
var free_cam: Camera3D
var gas_held: bool = false
var ready_done: bool = false
var t_ready: int = 0
var t_measure: int = 0


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	_apply_style_override(root.get_node("GameFX"))
	if OS.get_environment("PREVIEW_NOVSYNC") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)   # _ready chạy ở frame đầu của vòng lặp -> phần còn lại trong _setup()
	print("PREVIEW OUT DIR: ", out_dir)


## VICE_STYLE=vice|classic: ép phong cách cho lần chạy preview (không lưu settings.cfg). Autoload GameFX chỉ _ready
## (nạp settings.cfg) sau _initialize, nên đặt phong cách ngay sau tín hiệu ready của nó, trước FreeRoam._ready.
static func _apply_style_override(fx: Node) -> void:
	var style: String = OS.get_environment("VICE_STYLE")
	if style == "" or fx == null:
		return
	if fx.is_node_ready():
		fx.call("set_art_style", style, false)
	else:
		fx.ready.connect(func() -> void: fx.call("set_art_style", style, false), CONNECT_ONE_SHOT)


## Gọi ở frame đầu tiên sau khi FreeRoam._ready dựng xong thế giới.
func _setup() -> void:
	print("  FreeRoam._ready built the world in %d ms" % int(roam.get("build_ms")))
	player = roam.get("player")
	bike = roam.get("bike")
	md = roam.get("md")
	player.set("capture_on_click", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var campus_xf: Transform3D = roam.get("campus_xf")

	# 2. kênh đào Hoa giấy: điểm bờ gần BE6 nhất, lùi 7 m, nhìn ra giữa kênh
	var canal: PackedVector2Array = PackedVector2Array()
	for w: Dictionary in md.water("vinhomes"):
		if int(w.get("id", 0)) == 1241266632:
			canal = MapData.poly(w.get("outer", []))
	var be6: Array = md.landmark("be6_center")
	var be6c := Vector2(float(be6[0]), float(be6[1]))
	var canal_stand := Vector3(3850.0, 0.0, -495.0)
	var canal_look := Vector3(3850.0, 0.0, -600.0)
	if canal.size() >= 3:
		var c: Vector2 = _centroid(canal)
		var p: Vector2 = _closest_on_polygon(be6c, canal)
		var outward: Vector2 = (p - c).normalized()
		var st: Vector2 = p + outward * 7.0
		canal_stand = Vector3(st.x, 0.0, st.y)
		canal_look = Vector3(c.x, 0.0, c.y)
	# 3. VinMall: điểm chân tường gần góc nhìn tham chiếu nhất, lùi 26 m
	var vin_stand := Vector3(3700.0, 0.0, -150.0)
	var vin_look := Vector3(3585.0, 0.0, -291.0)
	for b: Dictionary in md.buildings("vinhomes"):
		if int(b.get("id", 0)) == 1115566351:
			var poly: PackedVector2Array = MapData.poly(b.get("outer", []))
			var c: Vector2 = _centroid(poly)
			var p: Vector2 = _closest_on_polygon(c + Vector2(125.0, 75.0), poly)
			var outward: Vector2 = (p - c).normalized()
			var st: Vector2 = p + outward * 26.0
			vin_stand = Vector3(st.x, 0.0, st.y)
			vin_look = Vector3(c.x, 0.0, c.y)
	# 4. Nguyễn Xiển: điểm trên tuyến tại 2 560 m (đoạn Nguyễn Xiển thứ hai, 2 410..2 711 m) + hướng chạy
	var ride: Array = _route_at(2560.0)
	var ride_pos: Vector3 = ride[0]
	var ride_dir: Vector3 = ride[1]
	# 7. Nguyễn Văn Tăng (tuyến 2 711..4 123 m): đoạn 3 350 m có nhà ống dày đặc hai bên
	var nvt: Array = _route_at(3350.0)
	var nvt_pos: Vector3 = nvt[0]
	var nvt_dir: Vector3 = nvt[1]
	# 5. trên D1, 30 m trước cổng chính, nhìn về cổng
	var gate_w: Vector3 = campus_xf * FPTUCampusBuilder.main_gate_local()
	var d1_stand: Vector3 = campus_xf * Vector3(FPTUCampusBuilder.MAIN_GATE_U + 30.0, 0.0, -11.5)
	# 6. flycam trên sân trong
	var ring: Rect2 = FPTUCampusBuilder.ring_courtyard_rect()
	var ring_c: Vector3 = campus_xf * Vector3(ring.get_center().x, 0.0, ring.get_center().y)

	shots = [
		{"name": "roam_01_spawn_be6", "kind": "walk", "pos": null, "look": null},
		{"name": "roam_02_canal", "kind": "walk", "pos": canal_stand, "look": canal_look},
		{"name": "roam_03_vincom", "kind": "walk", "pos": vin_stand, "look": vin_look},
		{"name": "roam_04_ride_nguyen_xien", "kind": "ride", "pos": ride_pos, "look": ride_pos + ride_dir * 20.0},
		{"name": "roam_05_campus_gate_from_d1", "kind": "walk", "pos": d1_stand, "look": gate_w},
		{"name": "roam_06_campus_air", "kind": "air", "pos": ring_c + Vector3(-150.0, 175.0, 150.0), "look": ring_c},
		{"name": "roam_07_nguyen_van_tang", "kind": "ride", "pos": nvt_pos, "look": nvt_pos + nvt_dir * 20.0},
	]
	free_cam = Camera3D.new()
	free_cam.name = "PreviewCam"
	free_cam.far = 6000.0
	free_cam.fov = 60.0
	root.add_child(free_cam)
	ready_done = true


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	var n: int = poly.size() - 1 if poly.size() > 1 and poly[0] == poly[poly.size() - 1] else poly.size()
	for i: int in range(n):
		c += poly[i]
	return c / float(maxi(1, n))


static func _closest_on_polygon(q: Vector2, poly: PackedVector2Array) -> Vector2:
	var best: Vector2 = poly[0]
	var best_d: float = INF
	for i: int in range(poly.size() - 1):
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(q, poly[i], poly[i + 1])
		var d: float = q.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


## [vị trí, hướng] trên tuyến BE6 -> FPTU tại quãng đường `dist_m`.
func _route_at(dist_m: float) -> Array:
	var pts: PackedVector2Array = md.route_points(0.0)
	var acc: float = 0.0
	for i: int in range(1, pts.size()):
		var seg: float = pts[i - 1].distance_to(pts[i])
		if acc + seg >= dist_m:
			var t: float = (dist_m - acc) / maxf(seg, 0.001)
			var p: Vector2 = pts[i - 1].lerp(pts[i], t)
			var d: Vector2 = (pts[i] - pts[i - 1]).normalized()
			return [Vector3(p.x, 0.0, p.y), Vector3(d.x, 0.0, d.y)]
		acc += seg
	var last: Vector2 = pts[pts.size() - 1]
	return [Vector3(last.x, 0.0, last.y), Vector3(0.0, 0.0, -1.0)]


static func _yaw_towards(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z)


func _begin_shot(s: Dictionary) -> void:
	var kind: String = String(s["kind"])
	if kind == "air":
		free_cam.look_at_from_position(s["pos"], s["look"], Vector3.UP)
		free_cam.make_current()
		return
	if s["pos"] != null:
		var pos: Vector3 = s["pos"]
		var yaw: float = _yaw_towards(pos, s["look"])
		player.call("teleport", pos, yaw)
	player.set("pitch", -0.16)
	if kind == "ride":
		player.call("teleport", s["pos"], _yaw_towards(s["pos"], s["look"]))
		roam.set("bike_parked", false)   # the bike left at the previous ride shot is fetched to the player
		roam.call("mount_bike")
		Input.action_press("gas")
		gas_held = true
	else:
		(player.get("camera") as Camera3D).make_current()


func _end_shot(s: Dictionary) -> void:
	if String(s["kind"]) == "ride":
		if gas_held:
			Input.action_release("gas")
			gas_held = false
		roam.call("dismount_bike")
	elif String(s["kind"]) == "air":
		(player.get("camera") as Camera3D).make_current()


func _save(name: String) -> void:
	var mean_fps: float = float(MEASURE) * 1000000.0 / float(maxi(1, Time.get_ticks_usec() - t_measure))
	var img: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(name + ".png")
	var err: int = img.save_png(path)
	var fx: Node = root.get_node("GameFX")
	print("  saved %s err=%d size=%s fps=%.0f (engine counter %.0f) style=%s quality=%d" % [path, err, img.get_size(), mean_fps, Engine.get_frames_per_second(), String(fx.get("art_style")), int(fx.get("visual_quality"))])


func _process(_delta: float) -> bool:
	if not ready_done:
		if int(roam.get("build_ms")) > 0:
			_setup()
			t_ready = Time.get_ticks_msec()
		return false
	if Time.get_ticks_msec() - t_ready < 4000:   # biên dịch shader xong, bộ đếm FPS ổn định trước ảnh đầu
		return false
	frames += 1
	var local_f: int = (frames - 1) % (SETTLE + 4)
	if local_f == 0:
		if shot_idx >= 0:
			_end_shot(shots[shot_idx])
		shot_idx += 1
		if shot_idx >= shots.size():
			print("PREVIEW FREE ROAM DONE")
			quit(0)
			return true
		_begin_shot(shots[shot_idx])
	elif local_f == SETTLE - MEASURE:
		t_measure = Time.get_ticks_usec()
	elif local_f == SETTLE:
		_save(String(shots[shot_idx]["name"]))
	return false
