# File: res://tests/preview_stages.gd
# Chụp ảnh kiểm tra đồ họa MENU + 7 MÀN (1, 2, 3, 4, 5, 6, EXTRA) (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_stages.gd          (PREVIEW_HUD=1 để giữ HUD như khi chơi,
#                                                             PREVIEW_ONLY=s1 để chỉ chụp một màn)
# Biến môi trường chỉ dùng cho ảnh preview (không ghi settings.cfg): VICE_STYLE=vice|classic ép phong cách đồ hoạ,
# PREVIEW_DIR=<thư mục tuyệt đối> thay cho user://preview, PREVIEW_NOVSYNC=1 tắt V-Sync để đo FPS thật.
# Mỗi màn: nạp scene thật, chờ vài chục frame cho SDFGI hội tụ, chụp từ camera của chính màn đó
# rồi chụp thêm 1 góc phụ (nhìn ra cửa sổ / toàn cảnh). PNG lưu vào user://preview/. FPS in ra = trung bình
# FPS_WINDOW frame ngay trước khi chụp.
# Màn 1 (tuyến thật BE6 -> FPTU) dùng "shots" đặt theo offset trên curve RoadSystem/RoadTrack/RoadPath
# và các mốc route_marks: s1_01_start_be6 (xuất phát, tháp BE6 phía sau), s1_02_nguyen_van_tang
# (đường thẳng Nguyễn Văn Tăng), s1_03_finish_d1_gate (vạch đích trước cổng chính trên D1),
# s1_04_rain_nguyen_van_tang (góc s1_02 khi đang mưa: sương của RoadEvents dày lên).
extends SceneTree

const SCENES: Array = [
	{"key": "menu", "path": "res://scenes/MainMenu.tscn", "extra": []},
	{"key": "s1", "path": "res://scenes/Main.tscn", "extra": [], "shots": [
		{"name": "s1_01_start_be6", "cam_off": 24.0, "cam_lat": 3.6, "cam_h": 2.4, "look_off": 0.0, "look_lat": -1.0, "look_h": 9.0, "fov": 72.0},
		{"name": "s1_02_nguyen_van_tang", "mark": "nvt_start", "cam_off": 520.0, "cam_lat": 1.8, "cam_h": 2.3, "look_off": 600.0, "look_lat": 0.0, "look_h": 1.6, "fov": 70.0},
		{"name": "s1_03_finish_d1_gate", "mark": "finish", "cam_off": -58.0, "cam_lat": -1.5, "cam_h": 4.2, "look_off": 10.0, "look_lat": 7.0, "look_h": 2.5, "fov": 66.0},
		# cùng góc s1_02 nhưng bật cơn mưa của RoadEvents (sương dày lên); chờ 180 frame cho tween sương 1,2 s xong
		{"name": "s1_04_rain_nguyen_van_tang", "mark": "nvt_start", "cam_off": 520.0, "cam_lat": 1.8, "cam_h": 2.3, "look_off": 600.0, "look_lat": 0.0, "look_h": 1.6, "fov": 70.0, "rain": true, "frames": 180},
	]},
	{"key": "s2", "path": "res://scenes/Stage2_Parking.tscn", "extra": [{"pos": Vector3(143.0, 2.0, -9.7), "look": Vector3(192.0, 5.0, -4.0), "fov": 72.0}, {"pos": Vector3(122.0, 2.4, 76.0), "look": Vector3(90.0, 5.0, 48.0), "fov": 72.0}]},
	{"key": "s3", "path": "res://scenes/Stage3_ClassroomFAP.tscn", "extra": [{"pos": Vector3(-1.5, 1.7, 2.2), "look": Vector3(7.0, 1.3, -2.5), "fov": 72.0}]},
	{"key": "s4", "path": "res://scenes/Stage4_Vovinam.tscn", "extra": [{"pos": Vector3(14.0, 9.0, 16.0), "look": Vector3(0.0, 1.0, -6.0), "fov": 62.0}]},
	{"key": "s5", "path": "res://scenes/Stage5_Canteen.tscn", "extra": [{"pos": Vector3(2.0, 2.6, 13.0), "look": Vector3(-2.0, 1.4, -6.0), "fov": 70.0}, {"pos": Vector3(-12.0, 1.8, 3.0), "look": Vector3(8.0, 1.5, -7.0), "fov": 72.0}]},
	{"key": "s6", "path": "res://scenes/Stage6_CapstoneBoss.tscn", "extra": [{"pos": Vector3(-4.5, 1.8, 3.5), "look": Vector3(7.0, 1.4, -2.0), "fov": 72.0}]},
	{"key": "ex", "path": "res://scenes/StageExtra_EOSExam.tscn", "extra": [{"pos": Vector3(0.0, 3.0, 0.0), "look": Vector3(0.0, 0.0, 0.01), "fov": 90.0}]}
]
const SHOT_FRAMES: int = 75
const FIRST_SHOT_FRAME: int = 90      # chụp camera của màn sau 90 frame (shader + bóng ổn định)
const EXTRA_FRAMES: int = 60          # mỗi góc phụ giữ 60 frame: FPS đo trên FPS_WINDOW frame cuối
const FPS_WINDOW: int = 40

var cam: Camera3D
var frames: int = 0
var scene_idx: int = -1
var current: Node = null
var out_dir: String
var step: int = 0
var only: String = ""
var next_save: int = 0                # Màn 1: frame lưu góc chụp hiện tại (mỗi góc giữ "frames" hoặc SHOT_FRAMES)
var _ticks: Array[int] = []

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
	only = OS.get_environment("PREVIEW_ONLY")
	cam = Camera3D.new()
	cam.name = "PreviewCam"
	cam.far = 6000.0
	root.add_child(cam)
	cam.current = false
	print("PREVIEW OUT DIR: ", out_dir)

## VICE_STYLE=vice|classic: ép phong cách cho lần chạy preview (không lưu settings.cfg). Autoload GameFX chỉ _ready
## (nạp settings.cfg) sau _initialize, nên đặt phong cách ngay sau tín hiệu ready của nó, trước khi cảnh nào dựng.
static func _apply_style_override(fx: Node) -> void:
	var style: String = OS.get_environment("VICE_STYLE")
	if style == "" or fx == null:
		return
	if fx.is_node_ready():
		fx.call("set_art_style", style, false)
	else:
		fx.ready.connect(func() -> void: fx.call("set_art_style", style, false), CONNECT_ONE_SHOT)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(name + ".png")
	var err: int = img.save_png(path)
	var mean_fps: float = 0.0
	if _ticks.size() >= 2:
		mean_fps = float(_ticks.size() - 1) * 1000000.0 / float(maxi(1, _ticks[_ticks.size() - 1] - _ticks[0]))
	var fx: Node = root.get_node("GameFX")
	print("  saved ", name, ".png err=", err, " fps=%.0f (engine %.0f) style=%s quality=%d" % [mean_fps, Engine.get_frames_per_second(), String(fx.get("art_style")), int(fx.get("visual_quality"))])

## Đặt camera theo offset trên curve của RoadSystem (Màn 1): cam_off/look_off tương đối với mốc `mark` (nếu có).
func _set_route_cam(shot: Dictionary) -> bool:
	var rs: Node = current.get_node_or_null("RoadSystem")
	var path: Path3D = current.get_node_or_null("RoadSystem/RoadTrack/RoadPath") as Path3D
	if rs == null or path == null or path.curve == null:
		return false
	var base: float = 0.0
	if shot.has("mark"):
		var marks: Dictionary = rs.get("route_marks")
		base = float(marks.get(shot["mark"], -1.0))
		if base < 0.0:
			print("  mark %s missing, skipping %s" % [shot["mark"], shot["name"]])
			return false
	var len: float = path.curve.get_baked_length() - 0.1
	var cx: Transform3D = path.curve.sample_baked_with_rotation(clampf(base + float(shot["cam_off"]), 0.0, len))
	var lx: Transform3D = path.curve.sample_baked_with_rotation(clampf(base + float(shot["look_off"]), 0.0, len))
	var pos: Vector3 = cx.origin + cx.basis.x * float(shot["cam_lat"]) + Vector3(0.0, float(shot["cam_h"]), 0.0)
	var look: Vector3 = lx.origin + lx.basis.x * float(shot["look_lat"]) + Vector3(0.0, float(shot["look_h"]), 0.0)
	cam.fov = float(shot["fov"])
	cam.look_at_from_position(pos, look, Vector3.UP)
	cam.current = true
	if bool(shot.get("rain", false)):
		_start_rain(rs)
	return true

## Ép cơn mưa của RoadEvents (bình thường 50% số lần chơi, khi xe tới đoạn Nguyễn Văn Tăng). Ở --script,
## current_scene chưa có lúc RoadEvents.setup nên nối WorldEnvironment bằng tay.
func _start_rain(rs: Node) -> void:
	var ev: Node = rs.get("road_events")
	if ev == null:
		return
	ev.set("world_env", current.get_node_or_null("WorldEnvironment"))
	ev.set("rain_possible", true)
	ev.set("rain_done", false)
	ev.call("_update_rain", float(ev.get("rain_from")) + 1.0)

func _shot_frames(shot: Dictionary) -> int:
	return int(shot.get("frames", SHOT_FRAMES))

func _finish_scene() -> void:
	cam.current = false
	Engine.time_scale = 1.0
	current.queue_free()
	current = null

func _process(_d: float) -> bool:
	frames += 1
	_ticks.append(Time.get_ticks_usec())
	if _ticks.size() > FPS_WINDOW + 1:
		_ticks.pop_front()
	if current == null:
		scene_idx += 1
		while scene_idx < SCENES.size() and only != "" and SCENES[scene_idx]["key"] != only:
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
	if SCENES[scene_idx].has("shots"):
		# Góc chụp theo tuyến đường (Màn 1): đặt camera, chờ SHOT_FRAMES frame rồi lưu
		var shots: Array = SCENES[scene_idx]["shots"]
		if frames == 50:
			next_save = 50 + _shot_frames(shots[0])
			if not _set_route_cam(shots[0]):
				_finish_scene()
		elif frames > 50 and frames == next_save:
			_save(str(shots[step]["name"]))
			step += 1
			if step < shots.size():
				next_save = frames + _shot_frames(shots[step])
				if not _set_route_cam(shots[step]):
					_finish_scene()
			else:
				_finish_scene()
		return false
	if extras.is_empty():
		# Scene không có góc phụ (menu): chụp camera riêng của nó 2 lần cách nhau để thấy chuyển cảnh
		if frames == FIRST_SHOT_FRAME:
			_save("%s_01_gameplay_cam" % key)
		elif frames == 420:
			_save("%s_02_gameplay_cam_later" % key)
			current.queue_free()
			current = null
		return false
	if step == 0 and frames == FIRST_SHOT_FRAME:
		_save("%s_01_gameplay_cam" % key)
		step = 1
		var e: Dictionary = extras[0]
		cam.global_position = e["pos"]
		cam.look_at(e["look"], Vector3.UP)
		cam.fov = e["fov"]
		cam.current = true
	elif step >= 1 and frames == FIRST_SHOT_FRAME + step * EXTRA_FRAMES:
		_save("%s_%02d_extra" % [key, step + 1])
		if step < extras.size():
			var e: Dictionary = extras[step]
			cam.global_position = e["pos"]
			cam.look_at(e["look"], Vector3.UP)
			cam.fov = e["fov"]
			step += 1
		else:
			_finish_scene()
	return false
