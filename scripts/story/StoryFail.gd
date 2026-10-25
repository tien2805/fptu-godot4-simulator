# File: res://scripts/story/StoryFail.gd
# Fail card of the Phase B roam missions (plan 2026-10-25-phase-b-integration.md): the title ("TOANG!", or "BỊ LỘ" for the
# canteen), a one-line reason and two buttons: "THỬ LẠI" (retry from the beat's checkpoint; also [Enter] / [R]) and
# "VỀ THẾ GIỚI MỞ" (leave the mission, its marker comes back). The game keeps running underneath (the mission is frozen in
# its "failed" state); the mouse is freed while it shows and captured again on retry. Plain text only.
class_name StoryFail
extends CanvasLayer

const GameFXScript: Script = preload("res://scripts/GameFX.gd")

signal retry_pressed
signal leave_pressed

var title_label: Label
var reason_label: Label
var retry_button: Button
var leave_button: Button
var shown: int = 0
var _mouse_was: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 116
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.05, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = -110.0
	panel.offset_bottom = 110.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.03, 0.14, 0.96)
	sb.border_color = Color("#FF3B5C")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	title_label = Label.new()
	title_label.name = "FailTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", GameFXScript.vice_font(0.9, 0.26))
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color("#FF3B5C"))
	title_label.add_theme_color_override("font_outline_color", Color("#2A0E3A"))
	title_label.add_theme_constant_override("outline_size", 8)
	vb.add_child(title_label)
	reason_label = Label.new()
	reason_label.name = "FailReason"
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.custom_minimum_size = Vector2(600.0, 0.0)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.add_theme_font_size_override("font_size", 18)
	reason_label.add_theme_color_override("font_color", Color("#F4F1FF"))
	vb.add_child(reason_label)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	retry_button = _button("Fail_retry", "THỬ LẠI")
	retry_button.pressed.connect(func() -> void: _close(true))
	hb.add_child(retry_button)
	leave_button = _button("Fail_leave", "VỀ THẾ GIỚI MỞ")
	leave_button.pressed.connect(func() -> void: _close(false))
	hb.add_child(leave_button)


func _button(n: String, text: String) -> Button:
	var b := Button.new()
	b.name = n
	b.text = text
	b.custom_minimum_size = Vector2(250.0, 44.0)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", GameFXScript.make_panel_style(Color("#FF4FA3"), Color(0.12, 0.05, 0.2, 0.95), 10))
	b.add_theme_stylebox_override("hover", GameFXScript.make_panel_style(Color("#3FF2FF"), Color(0.2, 0.08, 0.3, 0.98), 10))
	return b


func show_fail(title: String, reason: String) -> void:
	title_label.text = title
	reason_label.text = reason
	visible = true
	shown += 1
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if retry_button.is_inside_tree():
		retry_button.grab_focus.call_deferred()


func _close(retry: bool) -> void:
	if not visible:
		return
	visible = false
	if retry:
		if _mouse_was == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		retry_pressed.emit()
	else:
		leave_pressed.emit()


func press_retry() -> void:
	_close(true)


func press_leave() -> void:
	_close(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and (k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER or k.physical_keycode == KEY_R):
		_close(true)
		get_viewport().set_input_as_handled()
