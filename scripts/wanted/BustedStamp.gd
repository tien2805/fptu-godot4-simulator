# File: res://scripts/wanted/BustedStamp.gd
# "BỊ TÓM!" stamp shown when the player is busted (spec section 5): a big red word with a white outline that slams in
# (scale 2.2 -> 1 in SLAM_S, tilted -8°), holds, fades over the last FADE_S of SHOW_S real seconds (Time.get_ticks_usec, or
# step_real(dt) when manual), PROCESS_MODE_ALWAYS because the game is frozen meanwhile; emits `done` and frees itself.
class_name BustedStamp
extends CanvasLayer

signal done

const SHOW_S: float = 1.0
const SLAM_S: float = 0.15
const FADE_S: float = 0.15
const TEXT: String = "BỊ TÓM!"
const RED := Color("#E8323C")

var manual: bool = false
var t: float = 0.0
var label: Label
var _last_us: int = 0
var _done: bool = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.name = "Stamp"
	label.text = TEXT
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -360.0
	label.offset_right = 360.0
	label.offset_top = -90.0
	label.offset_bottom = 90.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 110)
	label.add_theme_color_override("font_color", RED)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 18)
	label.pivot_offset = Vector2(360.0, 90.0)
	label.rotation = deg_to_rad(-8.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_last_us = Time.get_ticks_usec()
	_apply()


func _process(_d: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1e6
	_last_us = now
	if not manual:
		step_real(dt)


func step_real(dt: float) -> void:
	if _done:
		return
	t += dt
	_apply()
	if t >= SHOW_S - 1e-6:
		_done = true
		done.emit()
		queue_free()


func _apply() -> void:
	var u: float = clampf(t / SLAM_S, 0.0, 1.0)
	label.scale = Vector2.ONE * lerpf(2.2, 1.0, u * u * (3.0 - 2.0 * u))
	label.modulate.a = clampf((SHOW_S - t) / FADE_S, 0.0, 1.0)
