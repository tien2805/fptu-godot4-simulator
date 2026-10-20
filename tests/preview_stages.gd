# File: res://tests/preview_stages.gd
# Chụp ảnh kiểm tra đồ họa MÀN 3, 4, 5, 6, EXTRA (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_stages.gd          (PREVIEW_HUD=1 để giữ HUD như khi chơi)
# Mỗi màn: nạp scene thật, chờ vài chục frame cho SDFGI hội tụ, chụp từ camera của chính màn đó
# rồi chụp thêm 1 góc phụ (nhìn ra cửa sổ / toàn cảnh). PNG lưu vào user://preview/.
extends SceneTree

const SCENES: Array = [
	{"key": "menu", "path": "res://scenes/MainMenu.tscn", "extra": []},
	{"key": "s3", "path": "res://scenes/Stage3_ClassroomFAP.tscn", "extra": [{"pos": Vector3(-1.5, 1.7, 2.2), "look": Vector3(7.0, 1.3, -2.5), "fov": 72.0}]},
	{"key": "s4", "path": "res://scenes/Stage4_Vovinam.tscn", "extra": [{"pos": Vector3(14.0, 9.0, 16.0), "look": Vector3(0.0, 1.0, -6.0), "fov": 62.0}]},
	{"key": "s5", "path": "res://scenes/Stage5_Canteen.tscn", "extra": [{"pos": Vector3(2.0, 2.6, 13.0), "look": Vector3(-2.0, 1.4, -6.0), "fov": 70.0}, {"pos": Vector3(-12.0, 1.8, 3.0), "look": Vector3(8.0, 1.5, -7.0), "fov": 72.0}]},
	{"key": "s6", "path": "res://scenes/Stage6_CapstoneBoss.tscn", "extra": [{"pos": Vector3(-4.5, 1.8, 3.5), "look": Vector3(7.0, 1.4, -2.0), "fov": 72.0}]},
	{"key": "ex", "path": "res://scenes/StageExtra_EOSExam.tscn", "extra": [{"pos": Vector3(0.0, 3.0, 0.0), "look": Vector3(0.0, 0.0, 0.01), "fov": 90.0}]}
]

var cam: Camera3D
var frames: int = 0
var scene_idx: int = -1
var current: Node = null
var out_dir: String
var step: int = 0

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	out_dir = ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	cam = Camera3D.new()
	cam.name = "PreviewCam"
	root.add_child(cam)
	cam.current = false
	print("PREVIEW OUT DIR: ", out_dir)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(name + ".png")
	var err: int = img.save_png(path)
	print("  saved ", name, ".png err=", err, " fps=", Engine.get_frames_per_second(), " quality=", root.get_node("GameFX").get("visual_quality"))

func _process(_d: float) -> bool:
	frames += 1
	if current == null:
		scene_idx += 1
		if scene_idx >= SCENES.size():
			print("PREVIEW DONE")
			quit(0)
			return true
		var packed: PackedScene = load(SCENES[scene_idx]["path"])
		current = packed.instantiate()
		root.add_child(current)
		var hud: Node = current.get_node_or_null("HUD")
		if hud and OS.get_environment("PREVIEW_HUD") != "1":
			hud.visible = false
		frames = 0
		step = 0
		return false
	var key: String = SCENES[scene_idx]["key"]
	var extras: Array = SCENES[scene_idx]["extra"]
	if extras.is_empty():
		# Scene không có góc phụ (menu): chụp camera riêng của nó 2 lần cách nhau để thấy chuyển cảnh
		if frames == 60:
			_save("%s_01_gameplay_cam" % key)
		elif frames == 420:
			_save("%s_02_gameplay_cam_later" % key)
			current.queue_free()
			current = null
		return false
	if step == 0 and frames == 60:
		_save("%s_01_gameplay_cam" % key)
		step = 1
		var e: Dictionary = extras[0]
		cam.global_position = e["pos"]
		cam.look_at(e["look"], Vector3.UP)
		cam.fov = e["fov"]
		cam.current = true
	elif step >= 1 and frames == 60 + step * 30:
		_save("%s_%02d_extra" % [key, step + 1])
		if step < extras.size():
			var e: Dictionary = extras[step]
			cam.global_position = e["pos"]
			cam.look_at(e["look"], Vector3.UP)
			cam.fov = e["fov"]
			step += 1
		else:
			cam.current = false
			Engine.time_scale = 1.0
			current.queue_free()
			current = null
	return false
