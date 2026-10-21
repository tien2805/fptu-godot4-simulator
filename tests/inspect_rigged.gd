# File: res://tests/inspect_rigged.gd
# In cấu trúc một mô hình glTF Quaternius sau khi Godot nhập (cây node, xương, animation, mesh):
#   GLTF=res://assets/models/quaternius/men/Casual_2.gltf godot --headless --path . --script tests/inspect_rigged.gd
extends SceneTree


func _initialize() -> void:
	var path: String = OS.get_environment("GLTF")
	if path == "":
		path = "res://assets/models/quaternius/men/Casual_2.gltf"
	var ps: PackedScene = load(path)
	if ps == null:
		print("LOAD FAIL ", path)
		quit(1)
		return
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	print("--- TREE ", path)
	_dump(inst, 0)
	var sk: Skeleton3D = _find_class(inst, "Skeleton3D") as Skeleton3D
	if sk:
		print("--- SKELETON bones=%d" % sk.get_bone_count())
		for b: int in sk.get_bone_count():
			var n: String = sk.get_bone_name(b)
			if n in ["Root", "Body", "Hips", "Abdomen", "Torso", "Chest", "Neck", "Head", "Shoulder.L", "UpperArm.L", "LowerArm.L", "Wrist.L", "UpperLeg.L", "LowerLeg.L", "Foot.L", "PT.L"]:
				var g: Transform3D = sk.get_bone_global_rest(b)
				var r: Transform3D = sk.get_bone_rest(b)
				print("  %-12s parent=%-3d rest_local_pos=%s rest_global_pos=%s local_rot_deg=%s" % [n, sk.get_bone_parent(b), _v(r.origin), _v(g.origin), _v(r.basis.get_euler() * 180.0 / PI)])
		print("  skeleton global xform: ", sk.global_transform)
	var ap: AnimationPlayer = _find_class(inst, "AnimationPlayer") as AnimationPlayer
	if ap:
		print("--- ANIMATIONS libs=", ap.get_animation_library_list())
		for a: String in ap.get_animation_list():
			var an: Animation = ap.get_animation(a)
			print("  %-28s len=%.2f loop=%s tracks=%d" % [a, an.length, an.loop_mode, an.get_track_count()])
		var an0: Animation = ap.get_animation(ap.get_animation_list()[0])
		for t: int in mini(4, an0.get_track_count()):
			print("    track[%d] %s type=%d" % [t, an0.track_get_path(t), an0.track_get_type(t)])
	for mi: MeshInstance3D in _find_all(inst, "MeshInstance3D"):
		var m: Mesh = mi.mesh
		var mats: Array = []
		for s: int in m.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			mats.append((mat.resource_name if mat else "null") + ("(%s)" % ((mat as BaseMaterial3D).albedo_color.to_html(false)) if mat is BaseMaterial3D else ""))
		print("--- MESH %-18s skeleton=%s aabb=%s surfaces=%s" % [mi.name, mi.skeleton, mi.get_aabb(), mats])
	quit(0)


func _dump(n: Node, depth: int) -> void:
	var extra: String = ""
	if n is Node3D:
		extra = " pos=%s scale=%s" % [_v((n as Node3D).position), _v((n as Node3D).scale)]
	print("%s%s (%s)%s" % ["  ".repeat(depth), n.name, n.get_class(), extra])
	for c: Node in n.get_children():
		_dump(c, depth + 1)


func _find_class(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c: Node in n.get_children():
		var r: Node = _find_class(c, cls)
		if r:
			return r
	return null


func _find_all(n: Node, cls: String) -> Array:
	var out: Array = []
	if n.is_class(cls):
		out.append(n)
	for c: Node in n.get_children():
		out.append_array(_find_all(c, cls))
	return out


func _v(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
