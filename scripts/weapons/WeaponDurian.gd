# File: res://scripts/weapons/WeaponDurian.gd
# Sầu riêng stink grenade (spec section 3): thrown along a ballistic arc (gravity GRAVITY), bounces off the world (ray per
# step, BOUNCE kept) and comes to rest; after FUSE_S it bursts (`burst` -> WeaponDirector.spawn_stink). Code-built spiky ball.
class_name WeaponDurian
extends Node3D

signal burst(at: Vector3)

const FUSE_S: float = 2.0
const GRAVITY: float = 20.0
const BOUNCE: float = 0.35
const RADIUS: float = 0.13

var vel: Vector3 = Vector3.ZERO
var t: float = 0.0
var resting: bool = false
var ex: Array[RID] = []


func launch(from: Vector3, v: Vector3, exclusions: Array[RID]) -> void:
	top_level = true
	global_position = from
	vel = v
	ex = exclusions
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	WeaponProps.add_durian(body, RADIUS)


func _physics_process(delta: float) -> void:
	t += delta
	if t >= FUSE_S:
		burst.emit(global_position)
		queue_free()
		return
	if resting:
		return
	vel.y -= GRAVITY * delta
	var a: Vector3 = global_position
	var b: Vector3 = a + vel * delta
	var h: Dictionary = {}
	if is_inside_tree():
		var rq := PhysicsRayQueryParameters3D.create(a, b + vel.normalized() * RADIUS)
		rq.exclude = ex
		rq.collide_with_areas = false
		h = get_world_3d().direct_space_state.intersect_ray(rq)
	if h.is_empty():
		global_position = b
		rotation += Vector3(7.0, 3.0, 0.0) * delta
		return
	var n: Vector3 = h["normal"]
	global_position = (h["position"] as Vector3) + n * RADIUS
	vel = vel.bounce(n) * BOUNCE
	if n.y > 0.7 and vel.length() < 2.0:
		resting = true
		vel = Vector3.ZERO
