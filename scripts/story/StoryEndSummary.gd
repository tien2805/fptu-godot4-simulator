# File: res://scripts/story/StoryEndSummary.gd
# End summary screen (plan 2026-11-01-w4-endings.md T2): after an ending's cinematics, before the main menu. One full-screen
# card drawn in code, plain Vietnamese, no emoji or decorative symbols:
#   the ending title and its one line;
#   LỰA CHỌN: the three story choices (Phúc, Za Mẫn's offer, Thị Lọ's bribe) and what was picked ("Chưa tới" if never asked);
#   BẰNG CHỨNG x/7: E1-E7 with their names, a missing one reads "E3 · Chưa tìm thấy" in a muted colour;
#   HẠNG NHIỆM VỤ: the best rank of each ranked mission ("-" when none).
# One button VỀ MENU CHÍNH ([Enter] / [Esc] / [E] too). closed fires once. Processes while the tree is paused (layer 118,
# above the story result card).
# show_for(x, state, ranks): state = StoryDirector.ending_state() (evidence, choices), ranks = StoryDirector.ranks.
class_name StoryEndSummary
extends CanvasLayer

signal closed

const GameFXScript: Script = preload("res://scripts/GameFX.gd")
const PINK := Color("#FF4FA3")
const CYAN := Color("#3FF2FF")
const TEXT := Color("#F4F5F6")
const MUTED := Color("#7F8C8D")
const FOUND := Color("#7CFF6B")
const T_CHOICES: String = "LỰA CHỌN"
const T_EVIDENCE: String = "BẰNG CHỨNG %d/7"
const T_RANKS: String = "HẠNG NHIỆM VỤ"
const T_BUTTON: String = "VỀ MENU CHÍNH"
const T_HINT: String = "[Enter] về menu chính"

var data: Dictionary = {}
var is_open: bool = false
var button: Button
var _lines: Array[String] = []   # every text shown (tests)


func _init() -> void:
	name = "StoryEndSummary"
	layer = 118
	process_mode = Node.PROCESS_MODE_ALWAYS


## Builds the card for ending x. Add the node to the tree before or after; it shows at once.
func show_for(x: String, state: Dictionary, ranks: Dictionary) -> void:
	data = StoryEndings.summary(x, state, ranks)
	_build()
	is_open = true


## Every string on the card (tests check them for emoji and wording).
func texts() -> Array[String]:
	return _lines.duplicate()


func _label(parent: Node, text: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = GameFXScript.make_label(text, size, col, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	_lines.append(text)
	return l


func _column(parent: Node, head: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	_label(v, head, 19, CYAN)
	return v


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Dim"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.05, 0.94)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 56)
	m.add_theme_constant_override("margin_top", 26)
	m.add_theme_constant_override("margin_bottom", 22)
	add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)
	var title: Label = _label(col, String(data.get("title", "")).to_upper(), 36, PINK, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	title.add_theme_font_override("font", GameFXScript.vice_font(0.9, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("#2A0E3A"))
	_label(col, String(data.get("line", "")), 16, Color("#BDC3C7"), HORIZONTAL_ALIGNMENT_CENTER)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	row.add_child(left)
	var ch: VBoxContainer = _column(left, T_CHOICES)
	ch.name = "Choices"
	for c: Array in data.get("choices", []):
		_label(ch, "%s: %s" % [String(c[0]), String(c[1])], 15, TEXT)
	var ev: VBoxContainer = _column(left, T_EVIDENCE % int(data.get("found", 0)))
	ev.name = "Evidence"
	for e: Array in data.get("evidence", []):
		var found: bool = bool(e[2])
		var l: Label = _label(ev, "%s · %s" % [String(e[0]), String(e[1]) if found else StoryEndings.MISSING_LINE], 15,
			FOUND if found else MUTED)
		l.name = "Ev_" + String(e[0])
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var rk: VBoxContainer = _column(scroll, T_RANKS)
	rk.name = "Ranks"
	for r: Array in data.get("ranks", []):
		var letter: String = String(r[1])
		_label(rk, "%s: %s" % [String(r[0]), letter], 14, TEXT if letter != StoryEndings.NO_RANK else MUTED)
	button = Button.new()
	button.name = "MenuButton"
	button.text = T_BUTTON
	button.custom_minimum_size = Vector2(300.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", GameFXScript.make_panel_style(PINK, Color(0.12, 0.05, 0.2, 0.95), 10))
	button.add_theme_stylebox_override("hover", GameFXScript.make_panel_style(CYAN, Color(0.2, 0.08, 0.3, 0.98), 10))
	button.add_theme_stylebox_override("focus", GameFXScript.make_panel_style(CYAN, Color(0.2, 0.08, 0.3, 0.98), 10))
	button.pressed.connect(confirm)
	col.add_child(button)
	_lines.append(T_BUTTON)
	_label(col, T_HINT, 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	button.call_deferred("grab_focus")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## VỀ MENU CHÍNH: closes the card (once).
func confirm() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_E]:
		get_viewport().set_input_as_handled()
		confirm()
