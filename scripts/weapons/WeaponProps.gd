# File: res://scripts/weapons/WeaponProps.gd
# Code-built hand props of the Phase W weapons (no imported art, no image files): origin at the grip, barrel / blade along
# -Z, sizes in metres. add_durian() is shared with the thrown sầu riêng.
class_name WeaponProps
extends RefCounted

static var _mats: Dictionary = {}


static func _mat(col: Color, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%.2f" % [col.to_html(), metal, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	_mats[key] = m
	return m


static func _box(root: Node3D, size: Vector3, pos: Vector3, col: Color, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, metal)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _sphere(root: Node3D, r: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = _mat(col)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## The hand prop of a slot (WeaponData.Slot); null for Tay không.
static func build(slot: int) -> Node3D:
	if slot == WeaponData.Slot.UNARMED:
		return null
	var root := Node3D.new()
	root.name = "Weapon_%s" % String(WeaponData.SLOTS[slot]["id"])
	match slot:
		WeaponData.Slot.KNIFE:
			_box(root, Vector3(0.03, 0.026, 0.1), Vector3(0.0, 0.0, 0.02), Color("#1B1B1F"))
			_box(root, Vector3(0.008, 0.032, 0.17), Vector3(0.0, 0.004, -0.11), Color("#C9CDD2"), 0.8)
		WeaponData.Slot.PISTOL:
			_box(root, Vector3(0.032, 0.1, 0.045), Vector3(0.0, -0.03, 0.0), Color("#22252A"))
			_box(root, Vector3(0.036, 0.042, 0.19), Vector3(0.0, 0.035, -0.06), Color("#2E3238"), 0.6)
		WeaponData.Slot.SHOTGUN:
			_box(root, Vector3(0.04, 0.04, 0.62), Vector3(0.0, 0.04, -0.3), Color("#2B2B2E"), 0.6)
			_box(root, Vector3(0.05, 0.05, 0.16), Vector3(0.0, 0.0, -0.32), Color("#6B4A2B"))
			_box(root, Vector3(0.05, 0.09, 0.3), Vector3(0.0, -0.01, 0.18), Color("#6B4A2B"))
		WeaponData.Slot.ROCKET:
			_box(root, Vector3(0.13, 0.13, 0.95), Vector3(0.0, 0.12, -0.12), Color("#4B5D3A"))
			_box(root, Vector3(0.04, 0.1, 0.05), Vector3.ZERO, Color("#1E1E1E"))
			_sphere(root, 0.075, Vector3(0.0, 0.12, -0.62), Color("#B8382E"))
		WeaponData.Slot.DEP:
			_box(root, Vector3(0.1, 0.025, 0.26), Vector3(0.0, 0.0, -0.06), Color("#3A7BD5"))
			_box(root, Vector3(0.104, 0.03, 0.045), Vector3(0.0, 0.02, -0.1), Color("#F2F4F5"))
		WeaponData.Slot.DURIAN:
			var d := Node3D.new()
			d.position = Vector3(0.0, 0.02, -0.08)
			root.add_child(d)
			add_durian(d, 0.12)
		WeaponData.Slot.LOA:
			_box(root, Vector3(0.22, 0.32, 0.18), Vector3(0.0, -0.12, -0.06), Color("#1F1F24"))
			var grill := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.08
			cm.bottom_radius = 0.08
			cm.height = 0.02
			grill.mesh = cm
			grill.material_override = _mat(Color("#8C8F96"), 0.4)
			grill.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, -0.1, -0.155))
			root.add_child(grill)
			_box(root, Vector3(0.14, 0.02, 0.02), Vector3(0.0, 0.05, -0.06), Color("#3A3A40"))
	return root


## A durian (spiky ball) of radius r on root: a sphere and 18 cone spikes (shared with the thrown sầu riêng).
static func add_durian(root: Node3D, r: float) -> void:
	_sphere(root, r, Vector3.ZERO, Color("#8A9A3B"))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r * 0.28
	cm.height = r * 0.55
	var mat: StandardMaterial3D = _mat(Color("#6E7C2C"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i: int in 18:
		var u: float = rng.randf_range(-0.95, 0.95)
		var a: float = rng.randf() * TAU
		var d := Vector3(sqrt(1.0 - u * u) * cos(a), u, sqrt(1.0 - u * u) * sin(a))
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, d)), d * r)
		root.add_child(mi)
