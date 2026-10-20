# File: res://tests/preview_people.gd
# Chụp NGƯỜI & ĐỒ VẬT trong từng màn (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_people.gd            (PEOPLE_ONLY=s2 để chỉ chụp 1 màn)
# Mỗi màn: nạp scene thật, chờ SDFGI/animation ổn định, chụp từ camera gameplay (ẩn HUD) rồi các góc cận cảnh
# nhân vật. PNG vào user://preview/people_<màn>_<n>.png
extends SceneTree

const SHOTS: Array = [
	{"key": "s1", "path": "res://scenes/Main.tscn", "wait": 70, "cams": [
		{"pos": Vector3(1.6, 1.35, 2.6), "look": Vector3(0.0, 1.0, 0.0), "fov": 55.0, "rel": "PlayerBike"},
		{"pos": Vector3(-2.2, 1.2, -1.4), "look": Vector3(0.0, 1.0, 0.2), "fov": 50.0, "rel": "PlayerBike"}]},
	{"key": "s2", "path": "res://scenes/Stage2_Parking.tscn", "wait": 80, "cams": [
		{"gameplay": true},
		{"pos": Vector3(2.5, 1.6, 3.0), "look": Vector3(0.0, 1.0, 0.0), "fov": 50.0, "rel": "RivalBike"}]},
	{"key": "s3", "path": "res://scenes/Stage3_ClassroomFAP.tscn", "wait": 80, "cams": [
		{"gameplay": true},
		{"pos": Vector3(-1.5, 1.7, 2.2), "look": Vector3(7.0, 1.3, -2.5), "fov": 72.0}]},
	{"key": "s4", "path": "res://scenes/Stage4_Vovinam.tscn", "wait": 80, "cams": [
		{"gameplay": true},
		{"pos": Vector3(4.0, 1.6, 4.0), "look": Vector3(0.0, 1.0, 0.0), "fov": 55.0}]},
	{"key": "s5", "path": "res://scenes/Stage5_Canteen.tscn", "wait": 80, "cams": [
		{"gameplay": true},
		{"pos": Vector3(2.0, 1.7, 4.0), "look": Vector3(-2.0, 1.1, -3.0), "fov": 60.0}]},
	{"key": "s6", "path": "res://scenes/Stage6_CapstoneBoss.tscn", "wait": 80, "cams": [
		{"gameplay": true},
		{"pos": Vector3(-3.0, 1.7, 3.0), "look": Vector3(2.0, 1.0, -2.0), "fov": 60.0}]},
	{"key": "ex", "path": "res://scenes/StageExtra_EOSExam.tscn", "wait": 80, "cams": [
		{"gameplay": true},
		{"pos": Vector3(-3.0, 1.9, 2.0), "look": Vector3(2.0, 0.9, -2.0), "fov": 60.0}]},
	{"key": "menu", "path": "res://scenes/MainMenu.tscn", "wait": 90, "cams": [{"gameplay": true}]}
]

var cam: Camera3D
var frames: int = 0
var idx: int = -1
var cam_idx: int = 0
var current: Node = null
var out_dir: String
var only: String = ""

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	only = OS.get_environment("PEOPLE_ONLY")
	out_dir = ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	cam = Camera3D.new()
	cam.name = "PeopleCam"
	root.add_child(cam)
	cam.current = false
	print("PREVIEW OUT DIR: ", out_dir)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])

func _process(_d: float) -> bool:
	frames += 1
	if current == null:
		idx += 1
		while idx < SHOTS.size() and only != "" and not (String(SHOTS[idx]["key"]) in only.split(",")):
			idx += 1
		if idx >= SHOTS.size():
			print("PREVIEW PEOPLE DONE")
			quit(0)
			return true
		var packed: PackedScene = load(SHOTS[idx]["path"])
		current = packed.instantiate()
		root.add_child(current)
		var hud: Node = current.get_node_or_null("HUD")
		if hud:
			hud.visible = false
		frames = 0
		cam_idx = 0
		cam.current = false
		return false
	var spec: Dictionary = SHOTS[idx]
	var cams: Array = spec["cams"]
	var wait: int = int(spec["wait"])
	if frames == wait + cam_idx * 25:
		var c: Dictionary = cams[cam_idx]
		if c.get("gameplay", false):
			cam.current = false
			var gc: Camera3D = get_root_camera()
			if gc:
				gc.current = true
		else:
			var base: Transform3D = Transform3D.IDENTITY
			if c.has("rel"):
				var rel: Node3D = current.find_child(String(c["rel"]), true, false) as Node3D
				if rel:
					base = rel.global_transform
					base.basis = Basis.IDENTITY.rotated(Vector3.UP, rel.global_rotation.y)
			cam.fov = float(c["fov"])
			cam.look_at_from_position(base * c["pos"], base * c["look"], Vector3.UP)
			cam.current = true
	elif frames == wait + cam_idx * 25 + 12:
		_save("people_%s_%02d" % [spec["key"], cam_idx + 1])
		cam_idx += 1
		if cam_idx >= cams.size():
			cam.current = false
			current.queue_free()
			current = null
			Engine.time_scale = 1.0
			var sm: Node = root.get_node_or_null("StageManager")
			if sm:
				sm.set("typing_mode", false)
	return false

func get_root_camera() -> Camera3D:
	return root.get_camera_3d()
