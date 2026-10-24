# File: res://scripts/story/StoryPhone.gd
# The protagonist's phone in story free roam ([P], spec A2-D7): a vice-styled panel on the right with three tabs
#   "Tin nhắn"   one thread per sender (Mr.T, Phúc, Anh Duy, Số lạ: only senders who wrote); showing a thread marks it read,
#   "Bằng chứng" E1-E7, a slot not owned yet reads "???",
#   "Nhiệm vụ"   day, objective, days left.
# While open, player movement / camera input are blocked (block_target.controls_enabled, like the map) and the mouse is
# free; the game is not paused. [P] or [Esc] closes it (handled in _input, before StageManager's pause key).
# Built in code; texts are already formatted ({name}) by StoryDirector.add_text.
class_name StoryPhone
extends Control

const GameFXScript: Script = preload("res://scripts/GameFX.gd")

signal opened_changed(open: bool)

const TABS: Array[String] = ["Tin nhắn", "Bằng chứng", "Nhiệm vụ"]
const PINK := Color("#FF4FA3")
const CYAN := Color("#3FF2FF")
const INK := Color("#1B0F33")
const SENDER_COLORS: Dictionary = {"Mr.T": Color("#B98CFF"), "Phúc": Color("#FF9A3C"), "Anh Duy": Color("#5BD38A"), "Số lạ": Color("#FF5F7E")}
const WIDTH: float = 380.0

var director: Node
var block_target: Object
var tab: int = 0
var thread: String = ""
var panel: PanelContainer
var tab_buttons: Array[Button] = []
var list: VBoxContainer
var scroll: ScrollContainer
var header: Label
var _open: bool = false
var _controls_was: bool = true


func setup(sd: Node, block: Object = null) -> void:
	director = sd
	block_target = block
	name = "StoryPhone"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "Phone"
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -WIDTH - 28.0
	panel.offset_right = -28.0
	panel.offset_top = 70.0
	panel.offset_bottom = -70.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.03, 0.13, 0.96)
	sb.border_color = PINK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 16)
	for side2: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side2, 14)
	panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	m.add_child(col)
	header = _label("📱 ĐIỆN THOẠI", 22, PINK, true)
	col.add_child(header)
	var notch := ColorRect.new()
	notch.custom_minimum_size = Vector2(0.0, 3.0)
	notch.color = CYAN
	col.add_child(notch)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for i: int in TABS.size():
		var b := Button.new()
		b.name = "Tab%d" % i
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(set_tab.bind(i))
		tabs.add_child(b)
		tab_buttons.append(b)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	list = VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	col.add_child(_label("[P] / [Esc] đóng", 12, Color("#B8A9D9"), false))


func _label(text: String, size: int, col: Color, italic: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4 if size >= 18 else 2)
	if italic:
		l.add_theme_font_override("font", GameFXScript.vice_font(0.7, 0.22))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	if block_target and "controls_enabled" in block_target:
		_controls_was = bool(block_target.get("controls_enabled"))
		block_target.set("controls_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if thread == "" or director.call("unread_count") > 0:
		thread = _default_thread()
	refresh()
	opened_changed.emit(true)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if block_target and "controls_enabled" in block_target:
		block_target.set("controls_enabled", _controls_was)
	opened_changed.emit(false)


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func set_tab(i: int) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	refresh()


func select_thread(from: String) -> void:
	thread = from
	set_tab(0)


## Senders with at least one message, in StoryMissions.SENDERS order (unknown senders after them).
func thread_names() -> PackedStringArray:
	var out := PackedStringArray()
	var texts: Array = director.get("texts") if director else []
	for s: String in StoryMissions.SENDERS:
		for m: Dictionary in texts:
			if String(m["from"]) == s:
				out.append(s)
				break
	for m2: Dictionary in texts:
		if not out.has(String(m2["from"])):
			out.append(String(m2["from"]))
	return out


## The thread with the newest unread message, else the newest message's sender.
func _default_thread() -> String:
	var texts: Array = director.get("texts") if director else []
	for i: int in range(texts.size() - 1, -1, -1):
		if not bool(texts[i]["read"]):
			return String(texts[i]["from"])
	return String(texts[texts.size() - 1]["from"]) if not texts.is_empty() else ""


## "E1 · <name>" when owned, "E1 · ???" when not.
func evidence_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in StoryMissions.EVIDENCE_IDS:
		var owned: bool = director != null and bool(director.call("has_evidence", id))
		out.append("%s · %s" % [id, StoryMissions.evidence_name(id) if owned else "???"])
	return out


func mission_text() -> String:
	if director == null:
		return ""
	var d: int = int(director.get("day"))
	var lines: PackedStringArray = [String(director.call("day_chip_text"))]
	var b: Dictionary = director.call("beat")
	if not b.is_empty():
		lines.append("Nhiệm vụ: %s" % String(b.get("title", "")))
	lines.append(String(director.get("objective")))
	if d >= 1:
		lines.append("Còn %d ngày tới buổi xét kỷ luật. Bằng chứng: %d/7." % [int(director.call("days_left")), (director.get("evidence") as Array).size()])
	else:
		lines.append("Hôm nay: thi EOS ở phòng 311. Bằng chứng: %d/7." % (director.get("evidence") as Array).size())
	return "\n\n".join(lines)


func refresh() -> void:
	if list == null:
		return
	for i: int in tab_buttons.size():
		var sel: bool = i == tab
		var n: int = int(director.call("unread_count")) if i == 0 and director else 0
		tab_buttons[i].text = TABS[i] + (" (%d)" % n if n > 0 else "")
		tab_buttons[i].add_theme_color_override("font_color", PINK if sel else Color("#E9E1FF"))
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()
	match tab:
		0:
			_fill_messages()
		1:
			for t: String in evidence_texts():
				var locked: bool = t.ends_with("???")
				list.add_child(_label(("🔒 " if locked else "📎 ") + t, 16, Color("#8F84A8") if locked else CYAN, false))
		2:
			list.add_child(_label(mission_text(), 16, Color("#F4F1FF"), false))


func _fill_messages() -> void:
	var names: PackedStringArray = thread_names()
	if names.is_empty():
		list.add_child(_label("Chưa có tin nhắn nào.", 15, Color("#B8A9D9"), false))
		return
	if thread == "" or not names.has(thread):
		thread = _default_thread()
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	list.add_child(row)
	for s: String in names:
		var b := Button.new()
		var n: int = int(director.call("unread_count", s))
		b.text = s + (" ●%d" % n if n > 0 and s != thread else "")
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", SENDER_COLORS.get(s, Color.WHITE) if s == thread else Color("#C9B8E8"))
		b.pressed.connect(select_thread.bind(s))
		row.add_child(b)
	director.call("mark_read", thread)
	var col: Color = SENDER_COLORS.get(thread, Color.WHITE)
	list.add_child(_label(thread, 18, col, true))
	for m: Dictionary in director.get("texts"):
		if String(m["from"]) != thread:
			continue
		var bubble := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r * 0.25, col.g * 0.2, col.b * 0.3, 0.95)
		sb.border_color = col
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		bubble.add_theme_stylebox_override("panel", sb)
		bubble.add_child(_label(String(m["text"]), 15, Color("#F4F1FF"), false))
		list.add_child(bubble)
		list.add_child(_label("Ngày %d" % int(m.get("day", 0)), 11, Color("#8F84A8"), false))


func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_P):
		close()
		get_viewport().set_input_as_handled()
