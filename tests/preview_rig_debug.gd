# File: res://tests/preview_rig_debug.gd
# Soi viền của thân rigged: viền next_pass rộng 0.04 / viền bằng MeshInstance3D riêng chung xương.
#   godot --path . --script tests/preview_rig_debug.gd
extends SceneTree

var cam: Camera3D
var c: Node3D
var frames: int = 0
var out_dir: String
var world: Node3D

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("user://preview")
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	c = CharacterBuilder.build({"preset": "student_m", "seed": 100, "name": "R", "rigged": true})
	c.rotation.y = PI
	world.add_child(c)
	cam = Camera3D.new()
	cam.fov = 30.0
	world.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(0.0, 1.1, 3.4), Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("  saved ", name)

func _strip_outline() -> void:
	for mi: MeshInstance3D in CharacterBuilder._mesh_instances(c):
		if mi.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = mi.material_override.duplicate()
			m.next_pass = null
			mi.material_override = m
		elif mi.mesh:
			for si: int in mi.mesh.get_surface_count():
				var sm: Material = mi.get_active_material(si)
				if sm is StandardMaterial3D:
					var m2: StandardMaterial3D = sm.duplicate()
					m2.next_pass = null
					mi.set_surface_override_material(si, m2)

func _hull_instances() -> void:
	var sk: Skeleton3D = c.get_meta("skeleton")
	for mi: MeshInstance3D in CharacterBuilder._mesh_instances(sk):
		if not mi.visible or mi.get_parent() != sk:
			continue
		var hull := MeshInstance3D.new()
		hull.name = mi.name + "_Outline"
		hull.mesh = mi.mesh
		hull.skin = mi.skin
		hull.material_override = CharacterBuilder._outline_mat(0.012)
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sk.add_child(hull)
		hull.skeleton = hull.get_path_to(sk)

func _process(_d: float) -> bool:
	frames += 1
	match frames:
		30:
			CharacterBuilder._outline_mat(0.012).set_shader_parameter("width", 0.04)
		40:
			_save("rigdbg_01_wide")
			CharacterBuilder._outline_mat(0.012).set_shader_parameter("width", 0.012)
			_strip_outline()
			_hull_instances()
		55:
			_save("rigdbg_02_hull_instance")
			quit(0)
	return false
