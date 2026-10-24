# File: res://scripts/weapons/WeaponRocket.gd
# The visible rocket of the Tên lửa slot (spec section 3): flies straight at SPEED (35 m/s) from the shoulder toward the aim
# point, tests each physics step against the world (ray; player, people and traffic excluded) and against the people /
# vehicles (WeaponDirector.first_hit), and explodes on the first hit or after MAX_RANGE m (exploded -> explode_at).
# Code-built body (olive tube, red nose, fins) and a CPUParticles3D trail.
class_name WeaponRocket
extends Node3D

signal exploded(at: Vector3)

const SPEED: float = WeaponData.SLOTS[WeaponData.Slot.ROCKET]["speed"]
const MAX_RANGE: float = WeaponData.SLOTS[WeaponData.Slot.ROCKET]["range"]

var director: WeaponDirector
var dir: Vector3 = Vector3.FORWARD
var travelled: float = 0.0
var ex: Array[RID] = []
var _done: bool = false


func launch(d: WeaponDirector, from: Vector3, direction: Vector3) -> void:
	director = d
	dir = direction.normalized()
	ex = d._exclusions()
	top_level = true
	global_position = from
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_basis = Basis.looking_at(dir, up)
	_build()


func _build() -> void:
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 0.55
	body.mesh = cm
	body.material_override = WeaponProps._mat(Color("#4B5D3A"))
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)      # cylinder axis Y -> Z (the flight axis)
	add_child(body)
	WeaponProps._sphere(self, 0.065, Vector3(0.0, 0.0, -0.28), Color("#B8382E"))
	WeaponProps._box(self, Vector3(0.24, 0.01, 0.1), Vector3(0.0, 0.0, 0.24), Color("#2E3A24"))
	WeaponProps._box(self, Vector3(0.01, 0.24, 0.1), Vector3(0.0, 0.0, 0.24), Color("#2E3A24"))
	director.fx.rocket_trail(self)


func _physics_process(delta: float) -> void:
	if _done or director == null:
		return
	var step: float = SPEED * delta
	var a: Vector3 = global_position
	var h: Dictionary = director.first_hit(a, dir, step, ex)
	if String(h["kind"]) != "none":
		global_position = h["pos"]
		_explode()
		return
	global_position = a + dir * step
	travelled += step
	if travelled >= MAX_RANGE:
		_explode()


func _explode() -> void:
	_done = true
	exploded.emit(global_position)
	queue_free()
