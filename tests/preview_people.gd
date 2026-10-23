# File: res://tests/preview_people.gd
# Ảnh người PS2 (phong cách Vice City) – cần cửa sổ render:
#   godot --path . --script tests/preview_people.gd          (PREVIEW_DIR=<thư mục tuyệt đối> thay user://preview)
# Ảnh: vice_people_lineup, vice_people_faces_a/b (8 biểu cảm), vice_people_hats (bảo vệ, công an, đầu bếp, người đi xe),
# vice_people_clips, vice_people_vs_classic.
extends SceneTree

const PRESETS: Array[String] = ["student_m", "student_f", "player", "lecturer", "proctor", "guard", "cop", "cook", "vovinam", "master", "casual", "rider", "student"]
const CLIPS: Array = [["walk", 1.3], ["run", 3.2], ["sit", 0.0], ["type", 0.0], ["phone", 0.0], ["cheer", 0.0], ["wave", 0.0], ["carry", 0.0], ["facepalm", 0.0]]
const SPACING: float = 0.9
## Ảnh cận mặt: 4 người đứng sát nhau (0.5 m) cho vừa khung ở 1.9 m (hàng 0.9 m rộng 2.7 m, khung chỉ ~2.5 m: hai người ngoài bị cắt)
const FACE_SPACING: float = 0.5
const HAT_IDX: Array[int] = [5, 6, 7, 11]

var cam: Camera3D
var chars: Array[Node3D] = []
var frames: int = 0
var out_dir: String
var world: Node3D
var classic: Node3D


func _initialize() -> void:
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	world = Node3D.new()
	world.name = "PeopleStudio"
	root.add_child(world)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 60.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.82, 0.78, 0.72)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	for i: int in range(PRESETS.size()):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i], "seed": 100 + i * 7, "name": "P_" + PRESETS[i]})
		c.position = Vector3((float(i) - float(PRESETS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		c.rotation.y = PI
		world.add_child(c)
		chars.append(c)
		var label := Label3D.new()
		label.text = PRESETS[i]
		label.font_size = 26
		label.pixel_size = 0.004
		label.position = Vector3(0.0, 2.05, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.1, 0.1, 0.1)
		label.outline_modulate = Color(1, 1, 1, 0.8)
		c.add_child(label)
	# đổi phong cách như trong game (GameFX.set_art_style quên cache vật liệu): không thì người cổ điển dùng lại vật liệu vice
	# (không viền, không toon) mà 13 người ở trên để lại trong cache
	CharacterBuilder.ps2 = false
	CharacterBuilder.toon = true
	CharacterBuilder._mat_cache = {}
	classic = CharacterBuilder.build({"preset": "student_m", "seed": 100, "name": "Classic_student_m"})
	classic.position = Vector3(-0.6, 0.0, 3.0)
	classic.rotation.y = PI
	classic.visible = false
	# ngoài nút world: pass vật liệu vice (upgrade_scene_visuals -> ViceStyle.apply, theo dõi cả node thêm sau) bỏ viền toon của
	# mọi vật liệu dưới world; ở đây người cổ điển giữ vật liệu toon + viền (ánh sáng vẫn chung một môi trường)
	root.add_child(classic)
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder._mat_cache = {}
	var gfx = load("res://scripts/GameFX.gd")   # untyped on purpose: static calls through a typed Script var fail
	gfx.upgrade_scene_visuals(world, "morning")
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true
	_shot(Vector3(0.0, 1.45, 7.6), Vector3(0.0, 0.95, 0.0), 50.0)
	print("PREVIEW OUT DIR: ", out_dir)


func _shot(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.look_at_from_position(pos, look, Vector3.UP)


func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])


## Đặt 4 người idx sát nhau (FACE_SPACING) quanh tâm của họ (người khác ẩn), đặt biểu cảm, nhìn camera, chụp cận mặt từ 1.9 m.
func _faces(idx: Array, exprs: Array) -> void:
	var mid: float = 0.0
	for i: int in range(chars.size()):
		chars[i].visible = i in idx
	for i: int in idx:
		mid += _row_x(i) / float(idx.size())
	for n: int in range(idx.size()):
		var c: Node3D = chars[int(idx[n])]
		c.position.x = mid + (float(n) - float(idx.size() - 1) * 0.5) * FACE_SPACING
		CharacterBuilder.set_expression(c, String(exprs[n]))
	_shot(Vector3(mid, 1.62, 1.9), Vector3(mid, 1.52, 0.0), 36.0)
	for i: int in idx:
		CharacterBuilder.look_at_point(chars[i], cam.global_position)


func _row_x(i: int) -> float:
	return (float(i) - float(PRESETS.size() - 1) * 0.5) * SPACING


## Trả mọi người về hàng (hiện lại), mặt "open", không nhìn theo camera.
func _back_to_row() -> void:
	for i: int in range(chars.size()):
		chars[i].visible = true
		chars[i].position.x = _row_x(i)
		CharacterBuilder.set_expression(chars[i], "open")
		CharacterBuilder.look_at_point(chars[i], null)


func _process(_d: float) -> bool:
	frames += 1
	match frames:
		60:
			_save("vice_people_lineup")
			_faces([0, 1, 2, 3], ["open", "happy", "angry", "pain"])
		75:
			_save("vice_people_faces_a")
			_faces([0, 1, 2, 3], ["surprised", "done", "talk", "open"])
		90:
			_save("vice_people_faces_b")
			_back_to_row()
			_faces(HAT_IDX, ["open", "open", "happy", "open"])
		105:
			_save("vice_people_hats")
			_back_to_row()
			for i: int in range(chars.size()):
				var cl: Array = CLIPS[i % CLIPS.size()]
				CharacterBuilder.set_speed(chars[i], float(cl[1]))
				if float(cl[1]) == 0.0:
					CharacterBuilder.play(chars[i], String(cl[0]), 30.0)
			_shot(Vector3(0.0, 1.5, 7.6), Vector3(0.0, 0.85, 0.0), 50.0)
		140:
			_save("vice_people_clips")
			for c: Node3D in chars:
				c.visible = false
			chars[0].visible = true
			chars[0].position = Vector3(0.6, 0.0, 3.0)
			CharacterBuilder.stop_clip(chars[0])
			CharacterBuilder.set_speed(chars[0], 0.0)
			classic.visible = true
			_shot(Vector3(0.0, 1.3, 6.2), Vector3(0.0, 0.9, 3.0), 42.0)
		200:
			# 60 frame cho người vice dừng bước (clip đi trộn về Idle) trước khi chụp cạnh người cổ điển
			_save("vice_people_vs_classic")
			print("PREVIEW PEOPLE DONE")
			quit(0)
	return false
