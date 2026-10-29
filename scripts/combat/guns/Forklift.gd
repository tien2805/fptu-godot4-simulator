# File: res://scripts/combat/guns/Forklift.gd
# Code-built forklift of the Day 3 container yard (spec C-D4, C-D10): yellow chassis, dark counterweight, four wheels, a
# two-rail mast with a carriage and two forks that slide up and down, an overhead guard on four posts, a seat, a steering
# wheel, an exhaust pipe and a roof beacon (amber, red while the boss telegraphs, off when stalled). Facing -Z.
# Physics: a floating CharacterBody3D on the world layer (bullets and people stop at its chassis and mast rails; the
# driver's seat stays open above the chassis), driven by drive(throttle, steer, top_speed): acceleration / braking, a
# rear-wheel steering turn rate that grows with speed, move_and_slide against the level; a head-on hit on a wall at more than
# CRASH_MIN m/s stops it and emits crashed(speed). lift_to(h) moves the forks (FORK_SPEED m/s); carry() / release_crate()
# hold a crate on them. topple(side) tips the whole visual over its side's bottom edge like a falling rigid body (an
# inverted pendulum, ending with a small bounce), collision off; emits toppled. Exceptions: add_collision_exception_with()
# the player so a charge passes through him (the boss applies the hit). No autoload, no allocation per frame.
class_name Forklift
extends CharacterBody3D

signal crashed(speed: float)
signal toppled

const YELLOW := Color("#F2B705")
const DARK := Color("#2B2B2E")
const TYRE := Color("#151517")
const ACCEL: float = 7.0
const ACCEL_CHARGE: float = 16.0
const BRAKE: float = 12.0
const TURN_RATE: float = 1.8             # rad/s at full lock and >= 2 m/s
const CRASH_MIN: float = 4.0
const FORK_SPEED: float = 1.6
const FORK_MAX: float = 2.6
const SEAT_Y: float = 1.05               # seat top
const SEAT_Z: float = 0.25
const FORK_TIP_Z: float = -2.2
const TOPPLE_G: float = 9.0              # pendulum: angular acceleration = TOPPLE_G * sin(theta + TOPPLE_LEAN)
const TOPPLE_LEAN: float = 0.18
const HALF_W: float = 0.6

var visual: Node3D
var forks: Node3D
var beacon: MeshInstance3D
var wheels: Array[Node3D] = []
var speed: float = 0.0
var throttle: float = 0.0
var steer: float = 0.0
var top_speed: float = 3.0
var charging: bool = false
var fork_h: float = 0.15
var fork_target: float = 0.15
var beacon_mode: String = "amber"
var crate: Node3D = null
var toppling: bool = false
var topple_done: bool = false
var topple_angle: float = 0.0
var crashes: int = 0
var last_crash_speed: float = 0.0
var floor_y: float = 0.0
var _topple_side: float = 1.0
var _topple_w: float = 0.0
var _bounced: bool = false
var _t: float = 0.0
var _beacon_red: StandardMaterial3D
var _beacon_amber: StandardMaterial3D
var _beacon_off: StandardMaterial3D
var _beacon_yellow: StandardMaterial3D   # W3 T7: the boss's ram window (forks going up)


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1
	safe_margin = 0.02
	floor_y = global_position.y
	_build_collision()
	_build_model()


func _build_collision() -> void:
	_shape(Vector3(1.2, 0.75, 2.6), Vector3(0.0, 0.55, 0.25), "Chassis")
	for s: float in [-1.0, 1.0]:
		_shape(Vector3(0.1, 2.4, 0.14), Vector3(0.38 * s, 1.3, -1.0), "Rail")


func _shape(size: Vector3, at: Vector3, n: String) -> void:
	var cs := CollisionShape3D.new()
	cs.name = n
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	add_child(cs)


func _build_model() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var y: StandardMaterial3D = GunProps.mat(YELLOW, 0.55)
	var d: StandardMaterial3D = GunProps.mat(DARK, 0.6)
	var tyre: StandardMaterial3D = GunProps.mat(TYRE, 0.9)
	GunProps.box(visual, Vector3(1.15, 0.55, 2.0), Vector3(0.0, 0.56, 0.12), y, "Chassis")
	GunProps.box(visual, Vector3(1.17, 0.8, 0.55), Vector3(0.0, 0.68, 1.25), d, "Counterweight")
	GunProps.box(visual, Vector3(1.0, 0.06, 0.9), Vector3(0.0, 0.86, 0.2), d, "Floorboard")
	for w: Array in [[0.5, -0.62, 0.32], [-0.5, -0.62, 0.32], [0.5, 0.92, 0.26], [-0.5, 0.92, 0.26]]:
		var pivot := Node3D.new()
		pivot.name = "Wheel"
		pivot.position = Vector3(float(w[0]), float(w[2]), float(w[1]))
		visual.add_child(pivot)
		var mi := GunProps.cyl(pivot, float(w[2]), float(w[2]), 0.24, Vector3.ZERO, tyre, "Tyre", 14)
		mi.rotation.z = PI * 0.5
		GunProps.cyl(pivot, float(w[2]) * 0.5, float(w[2]) * 0.5, 0.25, Vector3.ZERO, y, "Hub", 10).rotation.z = PI * 0.5
		wheels.append(pivot)
	for s: float in [-1.0, 1.0]:
		GunProps.box(visual, Vector3(0.08, 2.5, 0.12), Vector3(0.38 * s, 1.3, -1.0), d, "Rail")
	GunProps.box(visual, Vector3(0.84, 0.08, 0.1), Vector3(0.0, 2.5, -1.0), d, "MastTop")
	GunProps.box(visual, Vector3(0.84, 0.06, 0.1), Vector3(0.0, 1.4, -1.0), d, "MastMid")
	forks = Node3D.new()
	forks.name = "Forks"
	forks.position = Vector3(0.0, fork_h, -1.08)
	visual.add_child(forks)
	GunProps.box(forks, Vector3(0.86, 0.42, 0.06), Vector3(0.0, 0.21, 0.0), d, "Carriage")
	for s2: float in [-1.0, 1.0]:
		GunProps.box(forks, Vector3(0.1, 0.05, 1.1), Vector3(0.26 * s2, 0.0, -0.58), GunProps.mat(Color("#3A3A3E"), 0.4), "Fork")
	for p: Vector2 in [Vector2(0.5, -0.55), Vector2(-0.5, -0.55), Vector2(0.5, 0.7), Vector2(-0.5, 0.7)]:
		GunProps.box(visual, Vector3(0.06, 1.32, 0.06), Vector3(p.x, 1.5, p.y), d, "Post")
	for s3: float in [-1.0, 1.0]:
		GunProps.box(visual, Vector3(0.06, 0.06, 1.3), Vector3(0.5 * s3, 2.16, 0.075), d, "RoofSide")
	for z: float in [-0.55, -0.1, 0.3, 0.7]:
		GunProps.box(visual, Vector3(1.06, 0.05, 0.05), Vector3(0.0, 2.16, z), d, "RoofBar")
	GunProps.box(visual, Vector3(0.52, 0.12, 0.46), Vector3(0.0, SEAT_Y - 0.06, SEAT_Z), GunProps.mat(Color("#1C1C1E"), 0.8), "Seat")
	GunProps.box(visual, Vector3(0.5, 0.5, 0.1), Vector3(0.0, SEAT_Y + 0.25, SEAT_Z + 0.25), GunProps.mat(Color("#1C1C1E"), 0.8), "Backrest")
	var col := GunProps.cyl(visual, 0.03, 0.03, 0.5, Vector3(0.0, 1.15, -0.32), d, "Column", 8)
	col.rotation.x = 0.5
	var sw := GunProps.cyl(visual, 0.17, 0.17, 0.03, Vector3(0.0, 1.38, -0.42), GunProps.mat(Color("#111113"), 0.5), "SteeringWheel", 16)
	sw.rotation.x = 0.9
	GunProps.cyl(visual, 0.04, 0.04, 0.6, Vector3(0.45, 1.25, 1.35), d, "Exhaust", 8)
	_beacon_amber = GunProps.mat(Color("#FF9A1F"), 0.3, 3.0)
	_beacon_red = GunProps.mat(Color("#FF2A1A"), 0.3, 4.0)
	_beacon_off = GunProps.mat(Color("#4A3A20"), 0.6)
	_beacon_yellow = GunProps.mat(Color("#FFE21F"), 0.3, 4.0)
	beacon = GunProps.cyl(visual, 0.08, 0.1, 0.14, Vector3(0.0, 2.27, 0.1), _beacon_amber, "Beacon", 10)


func forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


## Driving input for this frame: throttle -1..1, steer -1..1 (left positive), top speed m/s; charge = hard acceleration.
func drive(th: float, st: float, top: float, charge: bool = false) -> void:
	throttle = clampf(th, -1.0, 1.0)
	steer = clampf(st, -1.0, 1.0)
	top_speed = top
	charging = charge


## Seat point (where the driver's hips sit) in world space.
func seat_point() -> Vector3:
	return global_transform * Vector3(0.0, SEAT_Y, SEAT_Z)


func fork_tips() -> Vector3:
	return global_transform * Vector3(0.0, fork_h, FORK_TIP_Z)


func lift_to(h: float) -> void:
	fork_target = clampf(h, 0.05, FORK_MAX)


## Hold a crate on the forks (reparented under them).
func carry(c: Node3D) -> void:
	release_crate()
	crate = c
	if c.get_parent():
		c.get_parent().remove_child(c)
	forks.add_child(c)
	c.position = Vector3(0.0, 0.03, -0.6)
	c.rotation = Vector3.ZERO


## Let go of the crate: it keeps its world transform under `new_parent` (or is freed when null). Returns it.
func release_crate(new_parent: Node = null) -> Node3D:
	var c: Node3D = crate
	crate = null
	if c == null or not is_instance_valid(c):
		return null
	var xf: Transform3D = c.global_transform
	forks.remove_child(c)
	if new_parent:
		new_parent.add_child(c)
		c.global_transform = xf
	else:
		c.queue_free()
		return null
	return c


func topple(side: float = 1.0) -> void:
	if toppling or topple_done:
		return
	toppling = true
	_topple_side = 1.0 if side >= 0.0 else -1.0
	_topple_w = 0.6
	topple_angle = 0.0
	collision_layer = 0
	collision_mask = 0
	speed = 0.0
	beacon_mode = "off"


func _physics_process(delta: float) -> void:
	_t += delta
	if toppling:
		_do_topple(delta)
		return
	if topple_done:
		return
	var want: float = throttle * top_speed
	var a: float = (ACCEL_CHARGE if charging else ACCEL) if absf(want) > absf(speed) and signf(want) == signf(speed if absf(speed) > 0.01 else want) else BRAKE
	speed = move_toward(speed, want, a * delta)
	var turn: float = steer * TURN_RATE * clampf(absf(speed) / 2.0, 0.25, 1.0) * (1.0 if speed >= -0.01 else -1.0)
	rotation.y += turn * delta
	var f: Vector3 = forward()
	velocity = f * speed
	var before: float = absf(speed)
	if before > 0.01:
		move_and_slide()
		var p: Vector3 = global_position
		if absf(p.y - floor_y) > 0.001:
			global_position = Vector3(p.x, floor_y, p.z)
		var head_on: bool = false
		for i: int in get_slide_collision_count():
			var n: Vector3 = get_slide_collision(i).get_normal()
			if n.dot(-f * signf(speed)) > 0.6:
				head_on = true
		if head_on and before >= CRASH_MIN:
			crashes += 1
			last_crash_speed = before
			speed = 0.0
			crashed.emit(before)
		else:
			speed = velocity.dot(f) if absf(velocity.dot(f)) < absf(speed) else speed
	for w: Node3D in wheels:
		w.rotation.x -= speed * delta / 0.3
	if not is_equal_approx(fork_h, fork_target):
		fork_h = move_toward(fork_h, fork_target, FORK_SPEED * delta)
		forks.position.y = fork_h


func _process(_d: float) -> void:
	if beacon == null:
		return
	var m: StandardMaterial3D
	match beacon_mode:
		"red":
			m = _beacon_red if fmod(_t, 0.24) < 0.12 else _beacon_off
		"amber":
			m = _beacon_amber if fmod(_t, 0.8) < 0.4 else _beacon_off
		"yellow":
			m = _beacon_yellow if fmod(_t, 0.16) < 0.1 else _beacon_off
		_:
			m = _beacon_off
	if beacon.material_override != m:
		beacon.material_override = m


## Inverted pendulum about the bottom edge on _topple_side, then a small bounce and rest at 90 degrees.
func _do_topple(delta: float) -> void:
	_topple_w += TOPPLE_G * sin(topple_angle + TOPPLE_LEAN) * delta
	topple_angle += _topple_w * delta
	if topple_angle >= PI * 0.5:
		topple_angle = PI * 0.5
		if not _bounced:
			_bounced = true
			_topple_w = -_topple_w * 0.18
		else:
			toppling = false
			topple_done = true
			toppled.emit()
	var pivot := Vector3(HALF_W * _topple_side, 0.0, 0.0)
	var r := Basis(Vector3(0.0, 0.0, 1.0), -_topple_side * topple_angle)
	visual.transform = Transform3D(Basis.IDENTITY, pivot) * Transform3D(r, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
