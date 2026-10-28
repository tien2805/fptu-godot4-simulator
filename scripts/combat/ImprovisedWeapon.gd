# File: res://scripts/combat/ImprovisedWeapon.gd
# Q2 improvised weapon of the melee fights (spec 2026-10-29 Q2, "Nobody" style): a code-built chair, tray, helmet or
# trash-can lid lying on the floor with a yellow pickup ring. [E] within CombatData.PICKUP_R picks it up (PlayerCombat):
# it rides in the player's right hand (posed in the body frame, swung with the move: swing_u), the light / heavy moves
# become swings and a smash (moveset()), every landed hit costs one of its KINDS hits, and at 0 it breaks comically
# (pieces fly and bounce, the break sound) and the player is unarmed again. reset() puts it back where it was spawned
# (MeleeFight.retry). No physics body: it never blocks anyone. Plain Vietnamese names, no emoji.
class_name ImprovisedWeapon
extends Node3D

const KINDS: Dictionary = {
	"chair": {"name": "Ghế nhựa", "hits": 4, "dmg": 16.0, "stagger": 34.0, "reach": 1.9, "push": 0.9, "hit_cue": "chair_smash", "break_cue": "wood_break"},
	"tray": {"name": "Khay cơm", "hits": 3, "dmg": 12.0, "stagger": 28.0, "reach": 1.7, "push": 0.6, "hit_cue": "tray_clang", "break_cue": "tray_clang"},
	"helmet": {"name": "Mũ bảo hiểm", "hits": 3, "dmg": 14.0, "stagger": 30.0, "reach": 1.6, "push": 0.7, "hit_cue": "helmet_clonk", "break_cue": "helmet_clonk"},
	"lid": {"name": "Nắp thùng rác", "hits": 5, "dmg": 11.0, "stagger": 26.0, "reach": 1.7, "push": 0.6, "hit_cue": "pot_clonk", "break_cue": "pot_clonk"},
}
const PIECE_S: float = 1.4
const GRAVITY: float = 16.0
## Hand offset and rotation in the body frame (x right, y up, -z forward) per kind, raised for a swing.
const HOLD: Dictionary = {
	"chair": [Vector3(0.0, 0.05, -0.12), Vector3(-0.4, 0.0, 0.3)],
	"tray": [Vector3(0.0, 0.0, -0.18), Vector3(-1.3, 0.0, 0.0)],
	"helmet": [Vector3(0.0, 0.02, -0.12), Vector3(0.0, 0.0, 0.0)],
	"lid": [Vector3(0.0, 0.0, -0.1), Vector3(-1.4, 0.0, 0.2)],
}

## Model offset lying / standing on the floor (the model's origin is the grip).
const GROUND: Dictionary = {"chair": Vector3(0.0, 0.78, 0.0), "tray": Vector3(0.0, 0.02, 0.15), "helmet": Vector3(0.0, 0.03, 0.0),
	"lid": Vector3(0.0, 0.02, 0.06)}

var kind: String = "chair"
var hits_left: int = 4
var max_hits: int = 4
var state: String = "ground"             # "ground" | "held" | "broken"
var home: Vector3 = Vector3.ZERO
var home_yaw: float = 0.0
var model: Node3D
var ring: MeshInstance3D
var holder: ThirdPersonController = null
## PlayerCombat sets it every physics frame while held: 0 idle, else the swing progress (0..1) of the move.
var swing_u: float = 0.0
var breaks: int = 0
var uses: int = 0
var _att: BoneAttachment3D = null
var _pieces: Array[Dictionary] = []       # {"node", "v", "spin", "t"}
var _ring_mat: StandardMaterial3D
var _t: float = 0.0
var _wobble: float = 0.0


func setup(k: String) -> void:
	kind = k if KINDS.has(k) else "chair"
	max_hits = int(KINDS[kind]["hits"])
	hits_left = max_hits
	name = "Prop_%s" % kind
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	_build(model)
	model.position = GROUND[kind]
	ring = MeshInstance3D.new()
	ring.name = "PickupRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 4
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1.0, 0.86, 0.2, 0.75)
	_ring_mat.set_meta("vice_done", true)
	tm.material = _ring_mat
	ring.mesh = tm
	ring.scale = Vector3(1.0, 0.2, 1.0)
	ring.position = Vector3(0.0, 0.03, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	process_priority = 12                    # after the body's RigAnimator (10) and the combat pose (11)


func display_name() -> String:
	return String(KINDS[kind]["name"])


func data() -> Dictionary:
	return KINDS[kind]


func can_pick() -> bool:
	return state == "ground" and visible and is_inside_tree()


## Ground position (the pickup check).
func ground_pos() -> Vector3:
	return global_position


## The light / heavy moves while it is held (PlayerCombat.set_moveset): two alternating swings and an overhead smash that
## breaks blocks; the impact sounds become the prop's own.
func moveset() -> Dictionary:
	var d: Dictionary = KINDS[kind]
	var dmg: float = float(d["dmg"])
	var light: Array = [
		{"id": "prop_swing", "clip": "chop", "from": 0.2, "hit_at": 0.5, "dur": 0.48, "hit": 0.22, "dmg": dmg, "stagger": float(d["stagger"]),
			"reach": float(d["reach"]), "half_deg": 70.0, "push": float(d["push"])},
		{"id": "prop_swing_b", "clip": "chop", "from": 0.2, "hit_at": 0.5, "dur": 0.5, "hit": 0.24, "dmg": dmg, "stagger": float(d["stagger"]),
			"reach": float(d["reach"]), "half_deg": 70.0, "push": float(d["push"])},
	]
	var heavy: Dictionary = {"id": "prop_smash", "clip": "chop", "from": 0.1, "hit_at": 0.5, "dur": 0.7, "hit": 0.34, "dmg": dmg * 1.6,
		"stagger": 55.0, "reach": float(d["reach"]) + 0.1, "half_deg": 75.0, "push": 1.4, "breaks_block": true}
	return {"light": light, "heavy": heavy, "controls": CombatData.T_CONTROLS_PROP,
		"cues": {"impact_light": String(d["hit_cue"]), "impact_heavy": String(d["hit_cue"])}}


## Into the player's right hand (Wrist.R bone attachment; else at the hand spot of the body).
func hold(p: ThirdPersonController) -> void:
	holder = p
	state = "held"
	ring.visible = false
	swing_u = 0.0
	var sk: Skeleton3D = p.model.get_meta("skeleton", null) as Skeleton3D if p and p.model else null
	if sk and sk.find_bone("Wrist.R") >= 0:
		_att = BoneAttachment3D.new()
		_att.name = "ImprovisedHold"
		_att.bone_name = "Wrist.R"
		sk.add_child(_att)
		model.reparent(_att, false)
	elif p and p.model:
		model.reparent(p.model, false)
		model.position = Vector3(0.25, 1.05, -0.25)


## One landed hit: true when it is used up (the caller then calls break_apart).
func use() -> bool:
	uses += 1
	hits_left = maxi(0, hits_left - 1)
	_wobble = 0.25
	return hits_left <= 0


## The comic break: the model hides, 4-6 pieces fly off with a spin and bounce, the break sound. Returns the pieces made.
func break_apart(ctx: Node = null) -> int:
	var at: Vector3 = model.global_position if model and model.is_inside_tree() else global_position + Vector3(0.0, 1.0, 0.0)
	_detach()
	state = "broken"
	breaks += 1
	model.visible = false
	ring.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + breaks
	var col: Color = _main_color()
	var n: int = 5
	for i: int in n:
		var mi := MeshInstance3D.new()
		mi.name = "Piece%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.06, 0.2), rng.randf_range(0.03, 0.08), rng.randf_range(0.06, 0.22))
		mi.mesh = bm
		mi.material_override = CineFX._mat(col.darkened(rng.randf_range(0.0, 0.3)), 0.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		mi.global_position = at
		var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.4, 0.4)
		_pieces.append({"node": mi, "v": Vector3(cos(a) * rng.randf_range(1.5, 3.2), rng.randf_range(2.5, 4.5), sin(a) * rng.randf_range(1.5, 3.2)),
			"spin": Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0)), "t": 0.0, "floor": at.y - 1.0})
	if ctx != null and is_instance_valid(ctx):
		Impact.sound(ctx, String(KINDS[kind]["break_cue"]), at, 1.0)
		Impact.particles(ctx, "debris", at, Vector3.UP, 0.8, null)
	return n


func pieces_alive() -> int:
	return _pieces.size()


## Back on the floor where it was spawned, whole again (MeleeFight.retry).
func reset() -> void:
	_detach()
	for e: Dictionary in _pieces:
		if is_instance_valid(e["node"]):
			(e["node"] as Node).queue_free()
	_pieces.clear()
	state = "ground"
	hits_left = max_hits
	swing_u = 0.0
	model.visible = true
	ring.visible = true
	global_position = home
	rotation.y = home_yaw


func _detach() -> void:
	if model.get_parent() != self:
		model.reparent(self, false)
	model.transform = Transform3D(Basis.IDENTITY, GROUND[kind])
	if _att and is_instance_valid(_att):
		_att.queue_free()
	_att = null
	holder = null


func _process(delta: float) -> void:
	_t += delta
	if state == "ground" and ring.visible:
		var k: float = 0.5 + 0.5 * sin(_t * 4.0)
		_ring_mat.albedo_color.a = 0.45 + 0.35 * k
		ring.scale = Vector3(1.0 + 0.06 * k, 0.2, 1.0 + 0.06 * k)
	elif state == "held":
		_pose_held(delta)
	if not _pieces.is_empty():
		_tick_pieces(delta)


## Posed in the body frame at the hand (like WeaponDirector's props), raised then swung down with swing_u, a wobble per hit.
func _pose_held(delta: float) -> void:
	if _att == null or not is_instance_valid(_att) or holder == null or not is_instance_valid(holder) or holder.model == null:
		return
	var sk: Skeleton3D = _att.get_parent() as Skeleton3D
	var b: int = sk.find_bone("Wrist.R")
	var hand: Transform3D = sk.global_transform * CharacterBuilder._bone_global_now(sk, b)
	var bodyb: Basis = holder.model.global_basis.orthonormalized()
	var h: Array = HOLD[kind]
	var e: Vector3 = h[1]
	var swing: float = 0.0
	if swing_u > 0.0:
		swing = lerpf(-0.9, 1.1, smoothstep(0.25, 0.6, swing_u))   # raised, then down through the hit
	_wobble = maxf(0.0, _wobble - delta)
	var wob: float = sin(_t * 60.0) * _wobble * 0.6
	var rb: Basis = bodyb * Basis(Vector3.RIGHT, -swing) * Basis.from_euler(e + Vector3(0.0, 0.0, wob))
	model.transform = hand.affine_inverse() * Transform3D(rb, hand.origin + bodyb * (h[0] as Vector3))


func _tick_pieces(delta: float) -> void:
	for i: int in range(_pieces.size() - 1, -1, -1):
		var e: Dictionary = _pieces[i]
		var node: Node3D = e["node"] if is_instance_valid(e["node"]) else null
		e["t"] = float(e["t"]) + delta
		if node == null or float(e["t"]) >= PIECE_S:
			if node:
				node.queue_free()
			_pieces.remove_at(i)
			continue
		var v: Vector3 = e["v"]
		v.y -= GRAVITY * delta
		var p: Vector3 = node.global_position + v * delta
		if p.y < float(e["floor"]) + 0.04 and v.y < 0.0:
			p.y = float(e["floor"]) + 0.04
			v = Vector3(v.x * 0.5, -v.y * 0.35, v.z * 0.5)   # a bounce
		e["v"] = v
		node.global_position = p
		node.rotation += (e["spin"] as Vector3) * delta


func _main_color() -> Color:
	match kind:
		"tray":
			return Color("#B03A2E")
		"helmet":
			return Color("#E8C547")
		"lid":
			return Color("#5F6A6A")
	return Color("#1F5FA8")


## The code-built model (origin at the grip).
func _build(root: Node3D) -> void:
	match kind:
		"chair":                             # a blue plastic canteen chair, held by its backrest
			var m: StandardMaterial3D = CineFX._mat(Color("#1F5FA8"), 0.5)
			CineFX._box(root, "Back", Vector3(0.4, 0.34, 0.035), Vector3(0.0, -0.12, 0.0), m)
			CineFX._box(root, "Seat", Vector3(0.4, 0.035, 0.4), Vector3(0.0, -0.36, -0.2), m)
			for sx: float in [-0.17, 0.17]:
				for sz: float in [0.0, -0.38]:
					CineFX._cyl(root, "Leg", 0.016, 0.016, 0.42, Vector3(sx, -0.57, sz - 0.02), m)
		"tray":
			var tr: Node3D = PropBuilder.build_tray(root, "com")
			tr.position = Vector3(0.0, 0.0, -0.15)
		"helmet":                            # a yellow scooter helmet held by the chin strap
			var hm: StandardMaterial3D = CineFX._mat(Color("#E8C547"), 0.35)
			CineFX._sphere(root, "Shell", 0.15, Vector3(0.0, 0.09, -0.02), hm, Vector3(1.0, 0.85, 1.12))
			CineFX._box(root, "Visor", Vector3(0.2, 0.06, 0.03), Vector3(0.0, 0.08, -0.17), CineFX._mat(Color("#26313A"), 0.2))
		"lid":                               # a grey trash-can lid held by its handle, like a shield
			var lm: StandardMaterial3D = CineFX._mat(Color("#5F6A6A"), 0.45)
			CineFX._cyl(root, "Disc", 0.3, 0.3, 0.04, Vector3(0.0, 0.0, -0.06), lm)
			CineFX._box(root, "Handle", Vector3(0.14, 0.04, 0.04), Vector3(0.0, 0.035, -0.06), CineFX._mat(Color("#2C3333"), 0.6))
