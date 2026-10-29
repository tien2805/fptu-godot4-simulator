# File: res://scripts/story/lairs/YardMannequins.gd
# D3W-1 (plan 2026-10-30-w3-day3.md T3): about 40 mannequins in smart glasses in front of the opened discovery stack, the
# crowd the player hides in at the start of d3_gunfight. One CineCrowd (three MultiMeshes) holds CROWD_N of them; LIVE_N
# more are single CineCrowds (the gags): their heads can turn on their own (turn_head: only one the camera is not looking
# at, at most HEAD_TURNS_MAX per hide, never with "Giảm hù dọa"), and one of them is the guard in disguise (`disguised`).
# frozen / frozen_ok(player): the player's "ĐỨNG IM!" (held [X], set by the mission): frozen and not moving.
# Built in yard-local space (the node sits on the yard's transform); nothing runs per frame.
class_name YardMannequins
extends Node3D

const CROWD_N: int = 36
const LIVE_N: int = 4
const HEAD_TURNS_MAX: int = 2
const OFF_CAMERA_DEG: float = 55.0
const MOVE_EPS: float = 0.3
## The field in front of the stack doors (yard-local): x from X0 step DX, z from Z0 step DZ.
const X0: float = -7.0
const DX: float = 1.15
const Z0: float = -6.1
const DZ: float = 0.9
const COLS: int = 8
const ROWS: int = 6
const KEEP_CLEAR_M: float = 0.75

var crowd: CineCrowd
var live: Array[CineCrowd] = []
var disguised: CineCrowd = null
var frozen: bool = false
var head_turns: int = 0
var turned: Array[bool] = []
var reduce_scares_override: Variant = null
var _live_home: Array[Vector3] = []


## Lays the crowd out on the yard's transform `xf`, leaving the spot `clear_local` (the player's start) free.
func setup(xf: Transform3D, clear_local: Vector3) -> void:
	name = "YardMannequins"
	transform = xf
	var pts := PackedVector3Array()
	var ys := PackedFloat32Array()
	var free_pts: Array[Vector3] = []
	for j: int in ROWS:
		for i: int in COLS:
			var jit := Vector3(sin(float(i * 5 + j * 11)) * 0.14, 0.0, cos(float(i * 3 + j * 7)) * 0.12)
			var p := Vector3(X0 + DX * float(i) + (0.5 * DX if j % 2 == 1 else 0.0), 0.0, Z0 + DZ * float(j)) + jit
			if Vector2(p.x - clear_local.x, p.z - clear_local.z).length() < KEEP_CLEAR_M:
				continue
			free_pts.append(p)
	# the live ones: the spots nearest the player (the gags happen where the player can see them)
	free_pts.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x - clear_local.x, a.z - clear_local.z).length() < Vector2(b.x - clear_local.x, b.z - clear_local.z).length())
	var live_pts: Array[Vector3] = []
	for k: int in mini(LIVE_N, free_pts.size()):
		live_pts.append(free_pts[k])
	for k2: int in range(LIVE_N, mini(LIVE_N + CROWD_N, free_pts.size())):
		pts.append(free_pts[k2])
		ys.append(PI + sin(float(k2) * 1.7) * 0.25)   # facing south (the yard), a little varied
	crowd = CineCrowd.new()
	crowd.name = "Crowd"
	add_child(crowd)
	crowd.layout(pts, ys)
	for k3: int in live_pts.size():
		var c := CineCrowd.new()
		c.name = "Live%d" % k3
		add_child(c)
		c.layout(PackedVector3Array([Vector3.ZERO]), PackedFloat32Array([0.0]))
		c.position = live_pts[k3]
		c.rotation.y = PI + 0.2 * float(k3 % 2)
		live.append(c)
		_live_home.append(live_pts[k3])
		turned.append(false)
	disguised = live[live.size() - 1] if not live.is_empty() else null
	reset()


## Everyone facing front, the disguised one back at its spot and visible, no head turned.
func reset() -> void:
	frozen = false
	head_turns = 0
	for k: int in live.size():
		live[k].cine_eval(10.0, {"turn_at": 0.0})
		live[k].visible = true
		live[k].position = _live_home[k]
		turned[k] = false


func count() -> int:
	return (crowd.count() if crowd else 0) + live.size()


## "ĐỨNG IM!" held and the player standing still.
func frozen_ok(player: Node3D) -> bool:
	if not frozen or player == null:
		return false
	var v: Variant = player.get("horizontal_speed")
	return v == null or float(v) < MOVE_EPS


func _reduce() -> bool:
	if reduce_scares_override is bool:
		return bool(reduce_scares_override)
	return StoryUtil.reduce_scares()


## A live mannequin (not the disguised guard) the camera is not looking at turns its head toward the camera; false when
## none qualifies, the budget is spent or "Giảm hù dọa" is on.
func turn_head_from(cam_pos: Vector3, cam_fwd: Vector3) -> bool:
	if head_turns >= HEAD_TURNS_MAX or _reduce():
		return false
	var f := Vector3(cam_fwd.x, 0.0, cam_fwd.z).normalized()
	for k: int in live.size():
		var c: CineCrowd = live[k]
		if c == disguised or turned[k] or not c.visible:
			continue
		var to: Vector3 = c.global_position - cam_pos
		to.y = 0.0
		if to.length() < 0.2:
			continue
		if f.dot(to.normalized()) >= cos(deg_to_rad(OFF_CAMERA_DEG)):
			continue   # on camera: never while watched
		c.cine_eval(0.0, {"turn_at": 99.0, "turn_from": 80.0})   # the head snaps round, 80 deg off its front
		turned[k] = true
		head_turns += 1
		return true
	return false


## turn_head_from the current camera.
func turn_head() -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	return turn_head_from(cam.global_position, -cam.global_basis.z)
