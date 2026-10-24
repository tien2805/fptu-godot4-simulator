# File: res://scripts/story/StoryDayCard.gd
# The tear-off calendar page of cine_day_start (spec A2-D17, story spec 8.4): a code-drawn page "NGÀY N · CÒN M NGÀY" in the
# upper part of the screen from SHOW_AT, torn off at TEAR_AT (it tips, falls and fades over FALL_LEN). N and M come from
# StoryDirector through the timeline (days, left), so every later day reuses it. state_at(r) is pure (tests); update(r)
# applies it; with `player` set it reads the CinePlayer's REAL time each frame (PROCESS_MODE_ALWAYS: the cinematic pauses
# the tree). Layer 105: above the HUD, below the cinematic overlay (110: letterbox, subtitles, fades).
class_name StoryDayCard
extends CanvasLayer

const GameFXScript: Script = preload("res://scripts/GameFX.gd")
const SHOW_AT: float = 0.8
const TEAR_AT: float = 3.6
const FALL_LEN: float = 1.2
const RED := Color("#E8202E")

var player: Node = null
var days: int = 1
var left: int = 7
var page: PanelContainer
var page_label: Label
var digit_label: Label
var last_state: Dictionary = {}
var _page_pos: Vector2 = Vector2.ZERO


## {shown, fall (0..1 after the tear), alpha}.
static func state_at(r: float) -> Dictionary:
	var fall: float = clampf((r - TEAR_AT) / FALL_LEN, 0.0, 1.0)
	var shown: bool = r >= SHOW_AT and r < TEAR_AT + FALL_LEN
	var a_in: float = clampf((r - SHOW_AT) / 0.25, 0.0, 1.0)
	return {"shown": shown, "fall": fall, "alpha": a_in * (1.0 - fall * fall)}


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	update(0.0)


func _build() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.anchor_bottom = 0.5
	c.offset_bottom = 0.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	page = PanelContainer.new()
	page.name = "CalendarPage"
	page.custom_minimum_size = Vector2(380.0, 0.0)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FBF8F2")
	sb.border_color = Color("#3A2950")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 0
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.shadow_size = 10
	page.add_theme_stylebox_override("panel", sb)
	c.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	page.add_child(v)
	var head := ColorRect.new()   # the red binding strip with two rings
	head.custom_minimum_size = Vector2(0.0, 34.0)
	head.color = RED
	v.add_child(head)
	var head_lbl: Label = _lbl("LỊCH · TOOL ĐEN", 16, Color.WHITE)
	head_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	head.add_child(head_lbl)
	digit_label = _lbl(str(days), 120, Color("#2A1C3C"))
	digit_label.name = "Digit"
	v.add_child(digit_label)
	page_label = _lbl("", 34, RED)
	page_label.name = "PageText"
	page_label.add_theme_font_override("font", GameFXScript.vice_font(0.7, 0.18))
	v.add_child(page_label)
	_apply_text()


func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _apply_text() -> void:
	if page_label:
		page_label.text = "NGÀY %d · CÒN %d NGÀY" % [days, left]
		digit_label.text = str(days)


func update(r: float) -> void:
	var st: Dictionary = state_at(r)
	last_state = st
	page.visible = bool(st["shown"])
	if not page.visible:
		return
	var f: float = float(st["fall"])
	page.pivot_offset = Vector2(0.0, 0.0)   # torn from its top-left corner
	page.rotation = deg_to_rad(-38.0 * f)
	page.modulate.a = float(st["alpha"])
	page.scale = Vector2.ONE * (1.0 - 0.15 * f)
	(page.get_parent() as Control).position.y = 720.0 * 0.9 * f * f   # falls out of the frame


func _process(_d: float) -> void:
	if player and is_instance_valid(player):
		update(float(player.get("r")))
