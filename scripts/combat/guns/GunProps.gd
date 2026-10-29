# File: res://scripts/combat/guns/GunProps.gd
# Code-built props of the Phase C gunfights (no textures, no imported models): the guards' wolf and fox masks (the sheep is
# StoryCast's), a wooden crate of smart glasses, an ammo box, the muzzle glint of the telegraph and the falling-crate
# shadow. Materials are cached per colour. Mesh primitives only.
class_name GunProps
extends RefCounted

static var _mats: Dictionary = {}


static func mat(col: Color, rough: float = 0.8, emissive: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key: String = "%s_%.2f_%.2f_%s" % [col.to_html(), rough, emissive, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = Color(col.r, col.g, col.b)
		m.emission_energy_multiplier = emissive
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.set_meta("vice_done", true)
	_mats[key] = m
	return m


static func box(parent: Node3D, size: Vector3, at: Vector3, m: Material, node_name: String = "Box") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, at: Vector3, m: Material, node_name: String = "Cyl", segs: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, r: float, at: Vector3, m: Material, node_name: String = "Sphere") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


## A guard mask on the body's head pivot: "sheep" (StoryCast), "wolf" (grey, long snout, pointed ears) or "fox" (orange,
## white muzzle, big ears). Returns the mask node (null for "" or a body without a head pivot).
static func attach_mask(body: Node3D, kind: String) -> Node3D:
	if kind == "sheep":
		return StoryCast.attach_mask(body)
	if kind != "wolf" and kind != "fox":
		return null
	var head: Node3D = CharacterBuilder.get_pivot(body, "head")
	if head == null:
		return null
	var m := Node3D.new()
	m.name = "WolfMask" if kind == "wolf" else "FoxMask"
	var fur: Color = Color("#7D8188") if kind == "wolf" else Color("#D9762B")
	var light: Color = Color("#C9CCD1") if kind == "wolf" else Color("#F4EDE1")
	var dark: StandardMaterial3D = mat(Color("#141416"), 0.6)
	var shell := sphere(m, 0.13, Vector3(0.0, 0.0, -0.01), mat(fur, 0.9), "Shell")
	shell.scale = Vector3(1.05, 1.1, 1.0)
	var snout := cyl(m, 0.035 if kind == "wolf" else 0.025, 0.07, 0.15 if kind == "wolf" else 0.12, Vector3(0.0, -0.03, -0.17), mat(light, 0.9), "Snout", 10)
	snout.rotation.x = -PI * 0.5                # along -Z (the face)
	sphere(m, 0.022, Vector3(0.0, -0.025, -0.25 if kind == "wolf" else -0.235), dark, "Nose")
	for s: float in [-1.0, 1.0]:
		var ear := cyl(m, 0.0, 0.045 if kind == "wolf" else 0.06, 0.11 if kind == "wolf" else 0.13, Vector3(0.075 * s, 0.13, -0.01), mat(fur, 0.9), "Ear", 6)
		ear.rotation.z = -0.25 * s
		sphere(m, 0.02, Vector3(0.045 * s, 0.035, -0.12), dark, "Eye")   # eye holes
	head.add_child(m)
	var hs: float = maxf(head.scale.y, 0.01)
	m.position = Vector3(0.0, 0.1 / hs, 0.0)
	m.scale = Vector3.ONE / hs
	body.set_meta("guard_mask", m)
	return m


## A wooden crate of smart glasses (size m, centred on its base), planks and a stencilled lid band.
static func crate(size: float = 0.9) -> Node3D:
	var root := Node3D.new()
	root.name = "Crate"
	var wood: StandardMaterial3D = mat(Color("#A0703F"), 0.9)
	var plank: StandardMaterial3D = mat(Color("#7A5230"), 0.9)
	box(root, Vector3(size, size, size), Vector3(0.0, size * 0.5, 0.0), wood, "Body")
	for y: float in [0.12, 0.5, 0.88]:
		box(root, Vector3(size + 0.02, 0.07, size + 0.02), Vector3(0.0, size * y, 0.0), plank, "Band")
	box(root, Vector3(size * 0.6, 0.1, 0.02), Vector3(0.0, size * 0.62, -size * 0.5 - 0.012), mat(Color("#1E1E22"), 0.7), "Stencil")
	return root


## A wooden pallet held upright as a shield (Wave 3 pallet-shield guard): 1.0 m wide, 1.2 m tall, base at the origin, the
## slatted face toward -Z (the holder's front).
static func pallet() -> Node3D:
	var root := Node3D.new()
	root.name = "Pallet"
	var slat: StandardMaterial3D = mat(Color("#B48C58"), 0.9)
	var post: StandardMaterial3D = mat(Color("#86633A"), 0.9)
	for i: int in 5:
		box(root, Vector3(1.0, 0.16, 0.03), Vector3(0.0, 0.1 + 0.25 * float(i), -0.06), slat, "Slat%d" % i)
	for x: float in [-0.44, 0.0, 0.44]:
		box(root, Vector3(0.1, 1.2, 0.09), Vector3(x, 0.6, 0.0), post, "Post")
	for y: float in [0.1, 0.6, 1.1]:
		box(root, Vector3(1.0, 0.12, 0.03), Vector3(0.0, y, 0.06), slat, "Back")
	return root


## An olive ammo box with a yellow band (pickups); a few brass rounds on the lid.
static func ammo_box() -> Node3D:
	var root := Node3D.new()
	root.name = "AmmoBox"
	box(root, Vector3(0.42, 0.24, 0.26), Vector3(0.0, 0.12, 0.0), mat(Color("#4E5B2E"), 0.7), "Body")
	box(root, Vector3(0.44, 0.05, 0.28), Vector3(0.0, 0.2, 0.0), mat(Color("#E3B71E"), 0.5, 0.4), "Band")
	for i: int in 3:
		var r := cyl(root, 0.018, 0.018, 0.08, Vector3(-0.08 + 0.08 * float(i), 0.29, 0.0), mat(Color("#C9A04A"), 0.3, 0.2), "Round", 8)
		r.rotation.z = PI * 0.5
	return root


## The telegraph glint at a muzzle: a bright unshaded star of two crossed quads (hidden until shown).
static func glint() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Glint"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.32, 0.32)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = GunData.GLINT_COL
	m.albedo_texture = _glint_tex()
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


static var _glint_cache: ImageTexture = null


## A four-point star drawn into a 32x32 image (code-built, cached).
static func _glint_tex() -> ImageTexture:
	if _glint_cache != null:
		return _glint_cache
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var dx: float = absf(float(x) - 15.5) / 15.5
			var dy: float = absf(float(y) - 15.5) / 15.5
			var a: float = maxf(maxf(0.0, 1.0 - dx * 6.0) * (1.0 - dy), maxf(0.0, 1.0 - dy * 6.0) * (1.0 - dx))
			a = maxf(a, maxf(0.0, 1.0 - sqrt(dx * dx + dy * dy) * 2.2))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	_glint_cache = ImageTexture.create_from_image(img)
	return _glint_cache


## A soft dark disc on the floor (falling-crate shadow), radius 1 m before scaling.
static func shadow_disc() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "CrateShadow"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.01
	cm.radial_segments = 24
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
