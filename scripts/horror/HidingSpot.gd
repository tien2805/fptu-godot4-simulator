# File: res://scripts/horror/HidingSpot.gd
# A place to hide (spec B-D3): a locker, a toilet stall or under a desk. The node sits where the hidden player is; its
# local -Z points the way out. [E] in and out is HorrorKit's job (hide_in / leave_hiding); this node gives the exit point,
# the low peek camera and the door.
#   locker: the camera peeks through the vents at eye height (1.55 m), the HUD draws vent slats;
#   stall:  the camera peeks under the door gap (0.3 m);
#   desk:   the camera peeks under the modesty panel (0.2 m), looking back into the room.
# Mouse look while hidden: ±45° yaw, ±20° pitch (peek_look). reveal(): the door is yanked open (a stalker checks the spot).
# The geometry (locker body, stall walls, desk) is built by the level; `door` is its optional door node (swung on enter).
class_name HidingSpot
extends Node3D

const USE_RADIUS: float = 1.4
const KINDS: Array[String] = ["locker", "stall", "desk"]
## Per kind: exit distance in front (m), peek camera local position, peek yaw (rad, local; 0 = looks out along -Z).
const EXIT_DIST: Dictionary = {"locker": 0.85, "stall": 1.2, "desk": 1.0}
const PEEK_POS: Dictionary = {"locker": Vector3(0.0, 1.55, -0.32), "stall": Vector3(0.0, 0.3, -0.9), "desk": Vector3(0.0, 0.2, 0.42)}
const PEEK_YAW: Dictionary = {"locker": 0.0, "stall": 0.0, "desk": PI}
const LOOK_YAW: float = deg_to_rad(45.0)
const LOOK_PITCH: float = deg_to_rad(20.0)

var kind: String = "locker"
var occupied: bool = false
var door: Node3D = null
var peek_cam: Camera3D
var revealed: bool = false
var _look: Vector2 = Vector2.ZERO
var _door_rest: float = 0.0


## A spot of `kind` at `xform` (local -Z = the way out), with an optional door node to swing.
static func make(spot_kind: String, xform: Transform3D, door_node: Node3D = null) -> HidingSpot:
	var s := HidingSpot.new()
	s.kind = spot_kind if spot_kind in KINDS else "locker"
	s.transform = xform
	s.door = door_node
	s.name = "Hide_" + s.kind
	return s


func _init() -> void:
	peek_cam = Camera3D.new()
	peek_cam.name = "PeekCam"
	peek_cam.fov = 62.0
	peek_cam.near = 0.03
	peek_cam.far = 200.0
	peek_cam.current = false
	add_child(peek_cam)


func _ready() -> void:
	if door != null:
		_door_rest = door.rotation.y
	peek_reset()


## Where the player stands when leaving (and where it must be to enter): EXIT_DIST in front of the spot, on the floor.
func exit_point() -> Vector3:
	var out: Vector3 = -global_transform.basis.z
	out.y = 0.0
	out = out.normalized() if out.length_squared() > 1e-6 else Vector3.FORWARD
	var p: Vector3 = global_position + out * float(EXIT_DIST.get(kind, 1.0))
	p.y = global_position.y
	return p


## Body yaw facing out of the spot (ThirdPersonController convention: 0 = -Z).
func exit_yaw() -> float:
	var out: Vector3 = -global_transform.basis.z
	return atan2(-out.x, -out.z)


func can_use(p: Vector3) -> bool:
	var e: Vector3 = exit_point()
	return Vector2(p.x - e.x, p.z - e.z).length() <= USE_RADIUS and absf(p.y - e.y) < 1.5


func peek_reset() -> void:
	_look = Vector2.ZERO
	_apply_peek()


## Mouse look while hidden (radians, added and clamped).
func peek_look(dyaw: float, dpitch: float) -> void:
	_look.x = clampf(_look.x + dyaw, -LOOK_YAW, LOOK_YAW)
	_look.y = clampf(_look.y + dpitch, -LOOK_PITCH, LOOK_PITCH)
	_apply_peek()


func _apply_peek() -> void:
	peek_cam.position = PEEK_POS.get(kind, Vector3(0.0, 1.0, 0.0))
	peek_cam.rotation = Vector3(_look.y, float(PEEK_YAW.get(kind, 0.0)) + _look.x, 0.0)


## Door swing: open a little on enter / leave (closes again), wide open on reveal.
func swing(wide: bool = false) -> void:
	if door == null or not is_instance_valid(door) or not is_inside_tree():
		return
	var tw: Tween = create_tween()
	if wide:
		tw.tween_property(door, "rotation:y", _door_rest + 1.7, 0.18)
	else:
		tw.tween_property(door, "rotation:y", _door_rest + 1.0, 0.15)
		tw.tween_property(door, "rotation:y", _door_rest, 0.25)


## A stalker yanks the spot open.
func reveal() -> void:
	revealed = true
	swing(true)


## Closes the door again (retry).
func reset_spot() -> void:
	revealed = false
	occupied = false
	if door != null and is_instance_valid(door):
		door.rotation.y = _door_rest
	peek_reset()
