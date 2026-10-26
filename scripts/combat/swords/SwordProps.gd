# File: res://scripts/combat/swords/SwordProps.gd
# Code-built hand props of the Phase C sword duels (no imported art, no image files): the player's Vovinam staff (gậy: a
# lacquered wooden pole with red bands and a yellow grip wrap) and attach_to_hand(), which puts a prop (origin at the grip,
# shaft along -Z) on a pivot at the right fist, under a BoneAttachment3D of the forearm. The pivot is aligned at the rest
# pose: -Z along the forearm, tilted `tilt` rad toward the thumb side (the character's forward at rest), so the prop swings
# with the arm (the katana: KatanaProp). Bodies without a skeleton get the prop at a fixed spot on the body.
class_name SwordProps
extends RefCounted

static var _mats: Dictionary = {}


static func mat(col: Color, metal: float = 0.0, rough: float = 0.6, emit: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%.2f|%.2f" % [col.to_html(), metal, rough, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func box(root: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## A cylinder along -Z (radius r, length l) centred at pos.
static func rod(root: Node3D, r: float, l: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = l
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## The Vovinam staff: SwordData.STAFF_LEN long, SwordData.STAFF_BACK of it behind the grip; "Staff" root, tip node "Tip".
static func staff() -> Node3D:
	var root := Node3D.new()
	root.name = "Staff"
	var l: float = SwordData.STAFF_LEN
	var back: float = SwordData.STAFF_BACK
	rod(root, 0.016, l, Vector3(0.0, 0.0, back - l * 0.5), mat(Color("#7A4A26"), 0.0, 0.45))
	rod(root, 0.019, 0.2, Vector3(0.0, 0.0, -0.02), mat(Color("#E8C547"), 0.0, 0.8))        # grip wrap
	for z: float in [back - 0.03, -(l - back) + 0.04, -(l - back) * 0.5]:
		rod(root, 0.0185, 0.04, Vector3(0.0, 0.0, z), mat(Color("#B3261E"), 0.0, 0.5))   # red bands
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0.0, 0.0, -(l - back))
	root.add_child(tip)
	return root


## Put `prop` on the right hand of a rigged CharacterBuilder body: a pivot "PropGrip" at the fist, under a BoneAttachment3D
## of the FOREARM (LowerArm.R: the clips' wrist turns never twist the prop away), aligned on the forearm at rest and tilted
## `tilt` rad toward the thumb. Returns the pivot (free it to remove the prop).
static func attach_to_hand(body: Node3D, prop: Node3D, tilt: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "PropGrip"
	pivot.add_child(prop)
	var sk: Skeleton3D = body.get_meta("skeleton", null) as Skeleton3D if body else null
	var wb: int = sk.find_bone("Wrist.R") if sk else -1
	var eb: int = sk.find_bone("LowerArm.R") if sk else -1
	if sk == null or wb < 0 or eb < 0:
		pivot.position = Vector3(0.22, 1.0, -0.25)   # no rig: held at the right hip, pointing forward
		body.add_child(pivot)
		return pivot
	var att := BoneAttachment3D.new()
	att.name = "Att_prop_r"
	att.bone_name = "LowerArm.R"
	sk.add_child(att)
	var to_root: Transform3D = CharacterBuilder._local_xform(sk, body)
	var wrist: Vector3 = (to_root * sk.get_bone_global_rest(wb)).origin
	var forearm: Transform3D = to_root * sk.get_bone_global_rest(eb)
	var fa: Vector3 = (wrist - forearm.origin).normalized()
	var fwd := Vector3(0.0, 0.0, -1.0)
	var side: Vector3 = fwd - fa * fwd.dot(fa)
	side = side.normalized() if side.length_squared() > 1e-6 else Vector3.UP
	var dir: Vector3 = (fa * cos(tilt) + side * sin(tilt)).normalized()
	var up: Vector3 = (side * cos(tilt) - fa * sin(tilt)).normalized()   # the thumb side, square to the shaft
	var grip := Transform3D(Basis.looking_at(dir, up), wrist + fa * 0.07)
	pivot.transform = forearm.affine_inverse() * grip
	att.add_child(pivot)
	return pivot
