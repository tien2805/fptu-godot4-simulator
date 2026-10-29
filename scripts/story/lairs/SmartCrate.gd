# File: res://scripts/story/lairs/SmartCrate.gd
# A crate of Alexander's smart glasses (spec C-D7 beat 7): a 1 m wooden crate, code-built, low cover (group "cover", a
# BoxShape3D: CoverMap scans it, gunmen and the player crouch behind it, bullets stop on it). During the Day 3 crates
# beat it is a GunFight external target (wave entry {"target": crate}): WeaponDirector / PlayerCombat find it through the
# fight's targets (take_hit / is_down; as a soft target its body is left out of the world ray, so a bullet reaches its
# capsule), and any bullet or blow breaks it: the planks fly off, the glasses spill with a glint, "crate_smash", signal
# ko. reset() puts it back whole. A carried crate (opts "carried": true, the coffin dance) has no collider.
class_name SmartCrate
extends StaticBody3D

signal ko(crate: Node3D)

const SIZE: float = 1.0
const WOOD := Color("#9B7445")
const PLANK := Color("#7A5832")

var broken: bool = false
var carried: bool = false
var dormant: bool = false
var shape: CollisionShape3D
var whole: Node3D
var debris: Array[MeshInstance3D] = []
var _debris_v: Array[Vector3] = []
var _debris_t: float = -1.0
var _sparkle: CPUParticles3D


func _init() -> void:
	collision_layer = 1
	collision_mask = 0


## opts: "carried" (no collider: the coffin-dance crate on the guards' shoulders).
func setup(opts: Dictionary = {}) -> void:
	carried = bool(opts.get("carried", false))
	name = String(opts.get("name", "SmartCrate"))
	whole = Node3D.new()
	whole.name = "Whole"
	add_child(whole)
	var wood: StandardMaterial3D = CineFX._mat(WOOD, 0.9)
	var plank: StandardMaterial3D = CineFX._mat(PLANK, 0.9)
	CineFX._box(whole, "Body", Vector3(SIZE, SIZE * 0.96, SIZE), Vector3(0.0, SIZE * 0.48, 0.0), wood)
	for sy: float in [0.12, 0.5, 0.86]:
		for sz: float in [-1.0, 1.0]:
			CineFX._box(whole, "Slat", Vector3(SIZE + 0.02, 0.09, 0.02), Vector3(0.0, sy * SIZE, sz * (SIZE * 0.5 + 0.01)), plank)
		for sx: float in [-1.0, 1.0]:
			CineFX._box(whole, "Slat", Vector3(0.02, 0.09, SIZE + 0.02), Vector3(sx * (SIZE * 0.5 + 0.01), sy * SIZE, 0.0), plank)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = "KÍNH THÔNG MINH\nHÀNG DỄ VỠ"
	tag.font_size = 40
	tag.pixel_size = 0.004
	tag.modulate = Color("#2A1A0C")
	tag.outline_size = 0
	tag.position = Vector3(0.0, SIZE * 0.55, SIZE * 0.5 + 0.025)
	whole.add_child(tag)
	for i: int in 6:
		var d: MeshInstance3D = CineFX._box(self, "Plank%d" % i, Vector3(0.5, 0.06, 0.12), Vector3.ZERO, plank)
		d.visible = false
		debris.append(d)
		_debris_v.append(Vector3.ZERO)
	_sparkle = CPUParticles3D.new()
	_sparkle.name = "Glasses"
	_sparkle.emitting = false
	_sparkle.one_shot = true
	_sparkle.amount = 18
	_sparkle.lifetime = 0.9
	_sparkle.explosiveness = 0.95
	_sparkle.direction = Vector3.UP
	_sparkle.spread = 70.0
	_sparkle.initial_velocity_min = 2.0
	_sparkle.initial_velocity_max = 4.5
	_sparkle.gravity = Vector3(0.0, -9.0, 0.0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.04)
	_sparkle.mesh = qm
	_sparkle.material_override = CineFX._glow_mat(Color("#9FE8FF"), 3.0)
	_sparkle.position = Vector3(0.0, SIZE * 0.5, 0.0)
	add_child(_sparkle)
	if not carried:
		shape = CollisionShape3D.new()
		shape.name = "Shape"
		var bs := BoxShape3D.new()
		bs.size = Vector3(SIZE, SIZE, SIZE)
		shape.shape = bs
		shape.position = Vector3(0.0, SIZE * 0.5, 0.0)
		add_child(shape)
		add_to_group("cover")
	set_physics_process(false)


# ----- the GunFight external enemy duck type -----
## dormant (review fix, the crates beat's pallet rack before it rolls out): not a live target (counts as out of the
## fight, ignores hits), not broken either.
func is_defeated() -> bool:
	return broken or dormant


func hit_node() -> Node3D:
	return self


func stand_down() -> void:
	pass


func is_down() -> bool:
	return broken or dormant


## Any bullet or blow breaks it ("knocked_out"); a broken or dormant crate ignores hits ("none"). Scare pulses are
## ignored.
func take_hit(info: Dictionary) -> String:
	if broken or dormant or String(info.get("kind", "")) == "scare":
		return "none"
	smash(info.get("from", global_position + Vector3(0.0, 0.0, 1.0)))
	return "knocked_out"


## Breaks it now (from: where the hit came from; the planks fly away from it).
func smash(from: Vector3 = Vector3.ZERO) -> void:
	if broken:
		return
	broken = true
	whole.visible = false
	if shape:
		shape.set_deferred("disabled", true)
	var away := Vector3(global_position.x - from.x, 0.0, global_position.z - from.z)
	away = away.normalized() if away.length_squared() > 0.01 else Vector3(0.0, 0.0, 1.0)
	for i: int in debris.size():
		var a: float = TAU * float(i) / float(debris.size())
		debris[i].visible = true
		debris[i].position = Vector3(cos(a) * 0.25, SIZE * 0.6, sin(a) * 0.25)
		debris[i].rotation = Vector3(0.0, a, 0.0)
		_debris_v[i] = (away * 2.2 + Vector3(cos(a), 0.0, sin(a)) * 1.6) + Vector3(0.0, 3.0 + 0.3 * float(i % 3), 0.0)
	_debris_t = 0.0
	if is_inside_tree():
		_sparkle.restart()
		_sparkle.emitting = true
		var sp := AudioStreamPlayer3D.new()
		sp.bus = WeaponAudio.bus()
		sp.stream = CineAudio.sfx("crate_smash")
		sp.unit_size = 6.0
		add_child(sp)
		sp.play()
		sp.finished.connect(sp.queue_free)
	set_physics_process(true)
	ko.emit(self)


## Whole again (a retry of the beat).
func reset() -> void:
	broken = false
	whole.visible = true
	if shape:
		shape.set_deferred("disabled", false)
	for d: MeshInstance3D in debris:
		d.visible = false
	_debris_t = -1.0
	set_physics_process(false)


## The planks fly for 1.2 s, then lie where they fell (on the crate's floor).
func _physics_process(delta: float) -> void:
	if _debris_t < 0.0:
		set_physics_process(false)
		return
	_debris_t += delta
	for i: int in debris.size():
		var d: MeshInstance3D = debris[i]
		if d.position.y <= 0.03 and _debris_v[i].y <= 0.0:
			continue
		_debris_v[i].y -= 9.8 * delta
		d.position += _debris_v[i] * delta
		d.rotation.x += delta * 6.0
		if d.position.y <= 0.03:
			d.position.y = 0.03
			d.rotation.x = 0.0
			_debris_v[i] = Vector3.ZERO
	if _debris_t > 1.4:
		_debris_t = -1.0
		set_physics_process(false)
