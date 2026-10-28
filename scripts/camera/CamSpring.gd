# File: res://scripts/camera/CamSpring.gd
# Exact critically damped spring of the Q1 camera director (spec 2026-10-29 Q1): every camera follow, pull-out, dip and
# punch moves through it. The step is the closed form of x'' = -2w x' - w^2 (x - target), so it is stable at any frame time,
# never overshoots a still target and reaches 99 % of a step after about 6.6 / w seconds.
#   var s := CamSpring.new(); s.snap(p); each frame: s.step(target, omega, dt) -> position; s.impulse(dv) for a kick.
#   CamSpring.damp(x, v, target, omega, dt) -> Vector2(x, v): the same for one float (no allocation).
#   CamSpring.damp_angle(...): the same for an angle (radians), along the short way round.
class_name CamSpring
extends RefCounted

var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO


func _init(p: Vector3 = Vector3.ZERO) -> void:
	pos = p


func snap(p: Vector3) -> void:
	pos = p
	vel = Vector3.ZERO


func impulse(dv: Vector3) -> void:
	vel += dv


func step(target: Vector3, omega: float, dt: float) -> Vector3:
	if dt <= 0.0:
		return pos
	var x0: Vector3 = pos - target
	var e: float = exp(-omega * dt)
	var j: Vector3 = (vel + x0 * omega) * dt
	pos = target + (x0 + j) * e
	vel = (vel - j * omega) * e
	return pos


static func damp(x: float, v: float, target: float, omega: float, dt: float) -> Vector2:
	if dt <= 0.0:
		return Vector2(x, v)
	var x0: float = x - target
	var e: float = exp(-omega * dt)
	var j: float = (v + omega * x0) * dt
	return Vector2(target + (x0 + j) * e, (v - omega * j) * e)


static func damp_angle(a: float, v: float, target: float, omega: float, dt: float) -> Vector2:
	return damp(a, v, a + wrapf(target - a, -PI, PI), omega, dt)


## Peak of an impulse dv given to a spring at rest on its target: dv / (omega * e), reached after 1 / omega seconds.
static func impulse_peak(dv: float, omega: float) -> float:
	return dv / (omega * exp(1.0))
