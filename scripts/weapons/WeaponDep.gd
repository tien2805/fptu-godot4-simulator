# File: res://scripts/weapons/WeaponDep.gd
# Dép tổ ong boomerang (spec section 3): flies straight out 12 m along the throw direction, curves back on the right and
# homes onto the thrower's hand over the last quarter of FLIGHT_S; bonks every person it passes within HIT_R (once each:
# WeaponDirector.dep_hit -> knocked out 4 s, stars, +1). One in flight at a time (WeaponDirector.dep_in_flight). Spins.
class_name WeaponDep
extends Node3D

signal returned(at: Vector3)

const FLIGHT_S: float = 1.4
const SIDE_M: float = 2.5
const HIT_R: float = 0.55
const SPIN: float = 22.0

var director: WeaponDirector
var start: Vector3
var fwd: Vector3
var right: Vector3
var reach: float = 12.0
var t: float = 0.0
var hit_ids: Dictionary = {}


func launch(d: WeaponDirector, from: Vector3, forward: Vector3, reach_m: float) -> void:
	director = d
	start = from
	fwd = WeaponMath.flat_dir(forward)
	right = Vector3(-fwd.z, 0.0, fwd.x)
	reach = reach_m
	top_level = true
	global_position = from
	var prop: Node3D = WeaponProps.build(WeaponData.Slot.DEP)
	add_child(prop)


func _physics_process(delta: float) -> void:
	t += delta
	var u: float = clampf(t / FLIGHT_S, 0.0, 1.0)
	var p: Vector3 = WeaponMath.boomerang_point(start, fwd, right, reach, SIDE_M, u)
	p = p.lerp(director.hand_position(), smoothstep(0.75, 1.0, u))
	global_position = p
	rotation.y += SPIN * delta
	for n: Node3D in director.soft_targets():
		var id: int = n.get_instance_id()
		if hit_ids.has(id) or (n.has_method("is_down") and bool(n.call("is_down"))):
			continue
		var c: Vector3 = n.global_position + Vector3(0.0, 1.2, 0.0)
		if Vector2(c.x - p.x, c.z - p.z).length() <= HIT_R + WeaponDirector.SOFT_R and absf(c.y - p.y) <= 0.9:
			hit_ids[id] = true
			director.dep_hit(n, p)
	if u >= 1.0:
		returned.emit(global_position)
		queue_free()
