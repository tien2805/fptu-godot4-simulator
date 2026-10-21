# File: res://tests/preview_stage2.gd
# Chụp ảnh kiểm tra đồ họa MÀN 2 (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_stage2.gd
# Nạp Stage2_Parking.tscn thật (campus FPT dựng tại gốc toạ độ, HUTECH đối diện qua D1), đặt camera ở các góc:
# đường D1 nhìn vào cổng bãi xe, cổng + barie, lối xe ven cánh phải, bãi xe có mái, lối đi sau toà nhà,
# sân trong + hồ sen, cầu thang ngoài trời, đỉnh thang + cửa Lab 402, toàn cảnh. Lưu PNG vào user://preview/.
extends SceneTree

var cam: Camera3D
var frames: int = 0
var shot_idx: int = -1
# v8: cổng tây u = 181, làn xe mép Tây u = 183, bãi xe v 94..113 (làn 103.5), lối vào sau u ≈ 121.5, sân trong u 42..147 ×
# v 30..79, sảnh thông tầng cửa kính v ≈ 69.4, cầu thang u = 164, sảnh trống đồng u ≈ 85.5, mặt tiền v = 16.
var shots: Array = [
	{"name": "s2_01_d1_approach", "pos": Vector3(143.0, 2.0, -9.7), "look": Vector3(192.0, 5.0, -4.0), "fov": 72.0},
	{"name": "s2_02_park_gate", "pos": Vector3(173.0, 2.4, -16.0), "look": Vector3(183.0, 2.6, 6.0), "fov": 66.0},
	{"name": "s2_03_lane_along_wing", "pos": Vector3(183.0, 2.6, 18.0), "look": Vector3(178.0, 7.0, 95.0), "fov": 70.0},
	{"name": "s2_04_parking_lot", "pos": Vector3(172.0, 2.8, 103.5), "look": Vector3(110.0, 2.0, 103.5), "fov": 70.0},
	{"name": "s2_05_back_passage", "pos": Vector3(121.5, 2.0, 84.0), "look": Vector3(121.5, 2.5, 108.0), "fov": 72.0},
	{"name": "s2_06_courtyard_pond", "pos": Vector3(122.0, 2.4, 76.0), "look": Vector3(90.0, 5.0, 48.0), "fov": 72.0},
	{"name": "s2_07_atrium_stair_hall", "pos": Vector3(150.0, 1.7, 69.4), "look": Vector3(164.0, 5.0, 50.0), "fov": 72.0},
	{"name": "s2_08_stair_top_door", "pos": Vector3(164.0, 19.3, 46.0), "look": Vector3(164.0, 19.0, 34.0), "fov": 70.0},
	{"name": "s2_10_lobby_trong_dong", "pos": Vector3(85.5, 1.7, 36.0), "look": Vector3(85.5, 1.1, 20.0), "fov": 68.0},
	{"name": "s2_11_facade_front", "pos": Vector3(55.0, 6.0, -14.0), "look": Vector3(125.0, 12.0, 20.0), "fov": 64.0},
	{"name": "s2_09_birdseye", "pos": Vector3(95.0, 215.0, 25.0), "look": Vector3(95.0, 0.0, 62.0), "fov": 60.0},
	{"name": "s2_12_birdseye_back", "pos": Vector3(95.0, 95.0, 200.0), "look": Vector3(95.0, 0.0, 70.0), "fov": 62.0}
]
var out_dir: String = ""

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Stage2_Parking.tscn")
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
	if frames < 30:
		return false
	var local_f: int = (frames - 30) % 24
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
	elif local_f == 22:
		var img: Image = root.get_texture().get_image()
		var path: String = out_dir.path_join(str(shots[shot_idx]["name"]) + ".png")
		var err: int = img.save_png(path)
		print("  saved ", path, " err=", err, " size=", img.get_size(), " fps=", Engine.get_frames_per_second(), " quality=", root.get_node("GameFX").get("visual_quality"))
	return false
