# File: res://scripts/LookZone.gd
# A look preset that holds while the camera is near a point (Q3, plan 2026-10-29-q3-look.md Task 1): the Day 3 container
# yard sits inside free roam, so port_night is pushed on the FreeRoam owner within enter_r of the yard and popped past
# exit_r (hysteresis: no flicker on the edge). Checked at CHECK_HZ against the current Camera3D, nothing per frame
# otherwise; popped when the zone leaves the tree. Usage: parent.add_child(LookZone.make(env_owner, preset, centre, r_in, r_out)).
class_name LookZone
extends Node

const CHECK_HZ: float = 2.0

var env_owner: Node = null
var preset: String = ""
var center: Vector3 = Vector3.ZERO
var enter_r: float = 110.0
var exit_r: float = 150.0
var inside: bool = false
var _t: float = 0.0


static func make(owner_node: Node, preset_name: String, at: Vector3, r_in: float, r_out: float) -> LookZone:
	var z := LookZone.new()
	z.name = "LookZone_" + preset_name
	z.env_owner = owner_node
	z.preset = preset_name
	z.center = at
	z.enter_r = r_in
	z.exit_r = maxf(r_out, r_in)
	return z


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0 / CHECK_HZ
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		check(cam.global_position)


## Updates the zone for a viewer position (tests call it directly).
func check(p: Vector3) -> void:
	var d: float = Vector2(p.x - center.x, p.z - center.z).length()
	if not inside and d <= enter_r:
		inside = true
		LookPresets.apply(preset, env_owner)
	elif inside and d > exit_r:
		inside = false
		LookPresets.restore(env_owner, preset)


func _exit_tree() -> void:
	if inside:
		inside = false
		LookPresets.restore(env_owner, preset)
