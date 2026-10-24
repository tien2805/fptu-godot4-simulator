# File: res://scripts/weapons/StinkCloud.gd
# Sầu riêng stink cloud (spec section 3): 8 m wide (radius 4) for 6 s. Every TICK_S everyone inside it who has not been
# affected yet reacts once ("stink": pinches the nose, coughs, then flees; officers are stunned); the first MAX_COUGHS
# play a cough. Vehicles inside stop through RoamTraffic.add_stop_zone (WeaponDirector.spawn_stink). Green puffs: WeaponFX.
class_name StinkCloud
extends Node3D

const TICK_S: float = 0.25
const MAX_COUGHS: int = 3

var director: WeaponDirector
var radius: float = 4.0
var life: float = 6.0
var t: float = 0.0
var affected: Dictionary = {}
var _acc: float = 0.0
var _coughs: int = 0


func setup(d: WeaponDirector, pos: Vector3, r: float, secs: float) -> void:
	director = d
	radius = r
	life = secs
	top_level = true
	global_position = pos
	d.fx.stink(pos, r, secs)
	_affect()


func _physics_process(delta: float) -> void:
	t += delta
	_acc += delta
	if _acc >= TICK_S:
		_acc = 0.0
		_affect()
	if t >= life:
		queue_free()


func contains(p: Vector3) -> bool:
	return WeaponMath.flat(p, global_position) <= radius


func _affect() -> void:
	for n: Node3D in director.soft_targets():
		var id: int = n.get_instance_id()
		if affected.has(id) or not contains(n.global_position) or absf(n.global_position.y - global_position.y) > 3.0:
			continue
		affected[id] = true
		if director.hit_target(n, {"kind": "stink", "from": global_position}) == "stink" and _coughs < MAX_COUGHS:
			_coughs += 1
			director.play_cue("cough", n.global_position + Vector3(0.0, 1.5, 0.0), -3.0)
