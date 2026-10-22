# File: res://tests/preview_cine_retarget.gd
# Ảnh kiểm tra retarget (nguyên mẫu cinematic): mỗi clip một ảnh, N thời điểm; mỗi thời điểm một cặp
#   trái = ma-nơ-canh gốc của thư viện (AnimationPlayer gốc), phải = người PS2 của game (CineRetarget).
# Cần cửa sổ render (KHÔNG --headless):
#   godot --path . --resolution 1800x560 --script tests/preview_cine_retarget.gd
# Biến môi trường: CLIPS="ual1:Punch_Jab,ual2:Melee_Hook,native:Kick_Right" (mặc định danh sách dưới), STEPS=6,
#   VIEW=front|side|threequarter, PREVIEW_DIR (mặc định user://preview), PRESET (mặc định player).
extends SceneTree

const DEFAULT_CLIPS: String = "ual1:Idle,ual1:Punch_Jab,ual1:Punch_Cross,ual2:Melee_Hook,ual2:NinjaJump_Start,ual2:Hit_Knockback,ual1:Sprint,ual2:Slide_Start"

var clips: PackedStringArray = []
var steps: int = 6
var view: String = "threequarter"
var out_dir: String = ""
var preset: String = "player"
var clip_i: int = -1
var frames: int = 0
var world: Node3D


func _initialize() -> void:
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	var c: String = OS.get_environment("CLIPS")
	clips = (c if c != "" else DEFAULT_CLIPS).split(",", false)
	var st: String = OS.get_environment("STEPS")
	if st != "":
		steps = int(st)
	if OS.get_environment("VIEW") != "":
		view = OS.get_environment("VIEW")
	if OS.get_environment("PRESET") != "":
		preset = OS.get_environment("PRESET")
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)


var _started: bool = false


func _next() -> void:
	clip_i += 1
	frames = 0
	if world:
		world.queue_free()
		world = null
	if clip_i >= clips.size():
		quit()
		return
	var parts: PackedStringArray = clips[clip_i].split(":")
	var lib_name: String = parts[0]
	var anim_name: String = parts[1]
	world = Node3D.new()
	root.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3a3f4a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8c8d0")
	env.ambient_light_energy = 0.6
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 20.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#56606e")
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	var length: float = 1.0
	var gap: float = 2.6
	for i: int in steps:
		var x: float = (float(i) - float(steps - 1) * 0.5) * gap
		# nhân vật game
		var ch: Node3D = CharacterBuilder.build({"preset": preset, "seed": 11, "rigged": true, "animate": false})
		world.add_child(ch)
		ch.position = Vector3(x + 0.5, 0.0, 0.0)
		ch.rotation.y = PI * 0.5 if view == "side" else 0.0
		var sk: Skeleton3D = ch.get_meta("skeleton")
		var ap: AnimationPlayer = ch.get_node("Model").find_child("AnimationPlayer", true, false) as AnimationPlayer
		var bd: Dictionary = CineRetarget.bind(sk, ap)
		length = CineRetarget.anim_length(lib_name, anim_name, bd)
		var t: float = length * float(i) / float(maxi(steps - 1, 1))
		CineRetarget.apply(sk, bd, CineRetarget.sample(bd, lib_name, anim_name, t))
		var lab := Label3D.new()
		lab.text = "%.2fs" % t
		lab.pixel_size = 0.004
		lab.position = Vector3(x, 2.15, 0.0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(lab)
		# ma-nơ-canh gốc
		if lib_name != "native":
			var src: Node3D = (load(CineRetarget.LIB_DIR + String(CineRetarget.LIB_FILES[lib_name])) as PackedScene).instantiate()
			world.add_child(src)
			src.position = Vector3(x - 0.5, 0.0, 0.0)
			src.rotation.y = PI * 1.5 if view == "side" else PI
			var sap: AnimationPlayer = src.find_child("AnimationPlayer", true, false) as AnimationPlayer
			sap.play(anim_name, 0.0)
			sap.seek(t, true)
			sap.pause()
	var title := Label3D.new()
	title.text = "%s  %s  (%.2f s)" % [lib_name, anim_name, length]
	title.pixel_size = 0.006
	title.position = Vector3(0.0, 2.6, 0.0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.add_child(title)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var vs: Vector2 = Vector2(root.get_viewport().get_visible_rect().size)
	cam.size = maxf(2.9, (float(steps) * gap + 0.4) / (vs.x / vs.y))
	world.add_child(cam)
	match view:
		"front":
			cam.position = Vector3(0.0, 1.1, -12.0)
			cam.look_at(Vector3(0.0, 1.1, 0.0))
		"side":
			cam.position = Vector3(0.0, 1.1, -12.0)
			cam.look_at(Vector3(0.0, 1.1, 0.0))
		_:
			cam.position = Vector3(-4.0, 2.2, -12.0)
			cam.look_at(Vector3(0.0, 1.0, 0.0))
	cam.current = true


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_next()
		return false
	if world == null:
		return false
	frames += 1
	if frames == 6:
		var img: Image = root.get_viewport().get_texture().get_image()
		var nm: String = clips[clip_i].replace(":", "_")
		img.save_png(out_dir.path_join("retarget_%s_%s.png" % [nm, view]))
		print("saved ", nm)
		_next()
	return false
