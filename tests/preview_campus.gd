# File: res://tests/preview_campus.gd
# Chụp ảnh kiểm tra đồ họa khuôn viên FPT trong Màn 1 (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_campus.gd
# Nạp Main.tscn thật, đặt camera ở 6 góc nhìn (đường D1, cổng chính, toàn cảnh, sân trong, HUTECH đối diện)
# và lưu PNG vào thư mục user://preview/ (in đường dẫn tuyệt đối ra console).
extends SceneTree

var cam: Camera3D
var frames: int = 0
var shot_idx: int = -1
var shots: Array = [
	{"name": "01_driver_view_d1", "pos": Vector3(140.0, 2.2, -1596.0), "look": Vector3(330.0, 8.0, -1578.0), "fov": 70.0},
	{"name": "02_main_gate", "pos": Vector3(238.0, 3.5, -1606.0), "look": Vector3(221.0, 5.0, -1578.0), "fov": 65.0},
	{"name": "03_birdseye_campus", "pos": Vector3(305.0, 95.0, -1700.0), "look": Vector3(305.0, 0.0, -1530.0), "fov": 60.0},
	{"name": "04_courtyard", "pos": Vector3(343.0, 5.0, -1532.0), "look": Vector3(262.0, 9.0, -1526.0), "fov": 72.0},
	{"name": "07_courtyard_from_lobby", "pos": Vector3(295.0, 3.0, -1544.0), "look": Vector3(340.0, 10.0, -1512.0), "fov": 74.0},
	{"name": "05_finish_both_campuses", "pos": Vector3(400.0, 30.0, -1596.0), "look": Vector3(250.0, 4.0, -1595.0), "fov": 68.0},
	{"name": "06_hutech_side", "pos": Vector3(300.0, 2.2, -1593.0), "look": Vector3(350.0, 8.0, -1625.0), "fov": 70.0}
]
var out_dir: String = ""

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var stage: Node = packed.instantiate()
	root.add_child(stage)
	var bike: Node = stage.get_node("PlayerBike")
	bike.set("is_controls_locked", true)
	var hud: CanvasLayer = stage.get_node("HUD")
	hud.visible = false
	cam = Camera3D.new()
	cam.name = "PreviewCam"
	root.add_child(cam)
	cam.current = true
	out_dir = ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("PREVIEW OUT DIR: ", out_dir)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 20:
		return false
	var local_f: int = (frames - 20) % 18
	if local_f == 0:
		shot_idx += 1
		if shot_idx >= shots.size():
			print("PREVIEW DONE")
			quit(0)
			return true
		var s: Dictionary = shots[shot_idx]
		cam.global_position = s["pos"]
		cam.look_at(s["look"], Vector3.UP)
		cam.fov = s["fov"]
		cam.current = true
	elif local_f == 16:
		var img: Image = root.get_texture().get_image()
		var path: String = out_dir.path_join(str(shots[shot_idx]["name"]) + ".png")
		var err: int = img.save_png(path)
		print("  saved ", path, " err=", err, " size=", img.get_size(), " fps=", Engine.get_frames_per_second(), " quality=", root.get_node("GameFX").get("visual_quality"))
	return false
