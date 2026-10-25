# File: res://scripts/horror/HorrorFlashlight.gd
# The player's flashlight (spec B-D3): [F] toggles it (HorrorKit reads the key). The battery lasts BATTERY_S seconds of
# light; below FLICKER_BELOW it flickers (short deterministic blips that get denser as it runs down; with `gentle` = "Giảm
# hù dọa" a slow dim pulse instead), at 0 it goes out and refuses to turn on until a pickup (add_battery). is_lit() is the
# stalker-sight flag (on with charge, blips included: the stalker still sees a flickering torch).
# The only moving light of a horror level: a SpotLight3D with shadows that follows `anchor` (the player, at chest height)
# and points where `aim` (the camera) looks. top_level, so it never inherits a parent's transform.
class_name HorrorFlashlight
extends Node3D

signal toggled(on: bool)
signal emptied

const BATTERY_S: float = 90.0
const FLICKER_BELOW: float = 0.2
const ENERGY: float = 4.0
const RANGE: float = 18.0
const ANGLE_DEG: float = 26.0
const CHEST_Y: float = 1.4
const SIDE: float = 0.25

## 0..1 (1 = BATTERY_S seconds of light).
var battery: float = 1.0
var on: bool = false
## Visual blip of the low-battery flicker (the light is dark this frame).
var flicker_off: bool = false
## "Giảm hù dọa": a slow dim pulse instead of blips.
var gentle: bool = false
## false: the owner calls tick() itself (tests).
var auto_tick: bool = true
var anchor: Node3D = null
var aim: Node3D = null
var light: SpotLight3D
var _t: float = 0.0


func _init() -> void:
	name = "Flashlight"
	top_level = true
	light = SpotLight3D.new()
	light.name = "Beam"
	light.light_color = Color(1.0, 0.95, 0.82)
	light.light_energy = ENERGY
	light.spot_range = RANGE
	light.spot_angle = ANGLE_DEG
	light.spot_angle_attenuation = 1.6
	light.spot_attenuation = 0.8
	light.shadow_enabled = true
	light.visible = false
	add_child(light)


func is_lit() -> bool:
	return on and battery > 0.0


func toggle() -> bool:
	return set_on(not on)


## Turns the light on or off; on is refused with an empty battery. Returns the new state.
func set_on(v: bool) -> bool:
	if v and battery <= 0.0:
		v = false
	if v != on:
		on = v
		toggled.emit(on)
	_apply()
	return on


func add_battery(frac: float) -> void:
	battery = clampf(battery + frac, 0.0, 1.0)
	_apply()


func _physics_process(delta: float) -> void:
	if auto_tick:
		tick(delta)


## Drain while on, low-battery flicker, empty -> off.
func tick(delta: float) -> void:
	_t += delta
	if on:
		battery = maxf(0.0, battery - delta / BATTERY_S)
		if battery <= 0.0:
			on = false
			toggled.emit(false)
			emptied.emit()
	flicker_off = false
	if on and battery < FLICKER_BELOW and not gentle:
		# denser blips as the charge runs down: ~10 % of the time at 20 %, ~40 % near empty
		var k: float = 1.0 - battery / FLICKER_BELOW
		var slot: int = int(floor(_t * 11.0))
		var h: float = fposmod(sin(float(slot) * 12.9898) * 43758.5453, 1.0)
		flicker_off = h < 0.1 + 0.3 * k
	_apply()


func _apply() -> void:
	if light == null:
		return
	light.visible = on and not flicker_off
	var e: float = ENERGY
	if on and battery < FLICKER_BELOW:
		e = ENERGY * (0.55 + 0.45 * battery / FLICKER_BELOW)
		if gentle:
			e *= 0.75 + 0.25 * sin(_t * 2.4)
	light.light_energy = e


func _process(_delta: float) -> void:
	follow()


## Puts the beam at the anchor's chest, a little to the right of the camera, pointing where the camera looks.
func follow() -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var b: Basis = aim.global_transform.basis.orthonormalized() if aim != null and is_instance_valid(aim) and aim.is_inside_tree() else anchor.global_transform.basis.orthonormalized()
	global_transform = Transform3D(b, anchor.global_position + Vector3(0.0, CHEST_Y, 0.0) + b.x * SIDE)
