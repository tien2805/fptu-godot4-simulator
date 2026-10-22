# File: res://tests/support/stub_mover.gd
# Thân giả cho test người đi đường / xe chạy: speed_value đóng vai horizontal_speed (người chơi) và current_speed_ms (xe).
extends CharacterBody3D

var speed_value: float = 0.0
var horizontal_speed: float:
	get:
		return speed_value
var current_speed_ms: float:
	get:
		return speed_value
	set(v):
		speed_value = v
