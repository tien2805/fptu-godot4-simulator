# File: res://scripts/cine/SkipHold.gd
# Hold-to-skip shared by every cinematic surface (master plan 2026-10-29 Q5 "Skip", plan 2026-10-29-w2-story T3): hold
# [ESC] or [ENTER] for HOLD seconds. step(dt, held) advances the hold and returns true once it is complete; progress() feeds
# the SkipHold.Ring control: a small progress ring with the plain text "Giữ để bỏ qua", shown only while a key is held.
# CinePlayer, CineReplay, StoryCall and StoryVideo use it (their force_skip_hold test hooks stay).
class_name SkipHold
extends RefCounted

const HOLD: float = 0.6
const TEXT: String = "Giữ để bỏ qua"

var t: float = 0.0
var done: bool = false


## true while [ESC] or [ENTER] (either Enter key) is physically held.
static func held() -> bool:
	return Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_ENTER) \
		or Input.is_physical_key_pressed(KEY_KP_ENTER)


## Advance by dt with the key state; true from the frame the hold reaches HOLD.
func step(dt: float, is_held: bool) -> bool:
	if done:
		return true
	t = t + dt if is_held else 0.0
	if t >= HOLD - 1e-6:
		done = true
	return done


## 0..1 of the hold, < 0 when nothing is held (the ring hides).
func progress() -> float:
	return clampf(t / HOLD, 0.0, 1.0) if t > 0.0 and not done else -1.0


## The progress ring and its text (top right). set_progress(p): p < 0 hides it.
class Ring extends HBoxContainer:
	var ring: RingArc
	var label: Label

	func _init() -> void:
		name = "SkipRing"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 8)
		ring = RingArc.new()
		ring.custom_minimum_size = Vector2(22.0, 22.0)
		ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ring)
		label = Label.new()
		label.text = TEXT
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		visible = false

	func set_progress(p: float) -> void:
		visible = p >= 0.0
		if visible and absf(ring.value - p) > 0.001:
			ring.value = p
			ring.queue_redraw()


class RingArc extends Control:
	var value: float = 0.0

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.25), 3.0, true)
		if value > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(value, 0.0, 1.0), 32, Color.WHITE, 3.0, true)
