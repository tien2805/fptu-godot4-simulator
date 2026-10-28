# File: res://scripts/story/StoryChoice.gd
# Choice scene overlay (spec B-D8, story spec 8.4): a freeze frame (the tree is paused while it is open; the previous pause
# state comes back on close), a dim, a title and prompt, two option buttons and a TIMEOUT-second countdown bar. On timeout
# the `honest` option is taken and a comic line shows for LINE_HOLD s. Plain text only (no emoji, no decorative symbols).
#
#   var c := StoryChoice.open(self, {
#       "id": "phuc",                                  # StoryDirector.choices key (record: true writes it)
#       "title": "Phúc thú nhận",                      # small line above the prompt (optional)
#       "prompt": "Phúc mua tool và đang bị tống tiền. Mày chọn sao?",
#       "options": [{"key": "cover", "label": "Che giấu cho Phúc"}, {"key": "report", "label": "Báo Mr.T"}],
#       "honest": "cover",                             # taken on timeout
#       "timeout_line": "Đứng hình mười giây… Phúc coi như mày đồng ý giấu rồi đó!",
#   })
#   c.chosen.connect(func(key: String, timed_out: bool) -> void: ...)
#
# Input: mouse click on a button; keys 1 / 2; Left / Right (or A / D) move the focus, Enter / Space picks (after ARM_S). A pick shows the
# highlighted button for PICK_HOLD s, then `chosen(key, timed_out)` is emitted and the overlay frees itself.
# Timing runs on real time (Time.get_ticks_usec, PROCESS_MODE_ALWAYS), or on step(dt) when `manual` (tests, CinePlayer manual).
# Inside a cinematic, CinePlayer opens it at the timeline's choice time and holds its own clock until `chosen`.
class_name StoryChoice
extends CanvasLayer

signal chosen(key: String, timed_out: bool)

const TIMEOUT: float = 10.0
const PICK_HOLD: float = 0.45
## Enter / Space only pick after ARM_S real seconds (review W2S-1): a player tapping Space / Enter to reveal the cinematic's
## lines (CinePlayer) must not pick the focused option unread. Keys 1 / 2 and clicks pick at once.
const ARM_S: float = 0.5
const LINE_HOLD: float = 1.8          # minimum; a longer timeout line holds 0.06 s per character (line_hold())
const BAR_W: float = 640.0
const ORANGE := Color("#F37021")
const RED := Color("#E8202E")
const INK := Color("#F4F1FF")

var def: Dictionary = {}
var manual: bool = false
var result: String = ""
var timed_out: bool = false
var t: float = 0.0
var phase: int = 0                     # 0 choosing, 1 picked (highlight hold), 2 timed out (comic line), 3 closed
var focus_i: int = 0
var dim: ColorRect
var panel: PanelContainer
var title_label: Label
var prompt_label: Label
var buttons: Array[Button] = []
var bar_back: ColorRect
var bar_fill: ColorRect
var secs_label: Label
var hint_label: Label
var line_label: Label
var _hold: float = 0.0
var _was_paused: bool = false
var _paused_by_me: bool = false
var _last_us: int = 0
var _mouse_was: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


## Builds the overlay under `parent` with the definition `d` and returns it (open at once).
static func open(parent: Node, d: Dictionary, is_manual: bool = false) -> StoryChoice:
	var c := StoryChoice.new()
	c.def = d
	c.manual = is_manual
	c.name = "StoryChoice"
	parent.add_child(c)
	return c


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	var tree: SceneTree = get_tree()
	_was_paused = tree.paused
	if not tree.paused:
		tree.paused = true
		_paused_by_me = true
	_last_us = Time.get_ticks_usec()
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # FreeRoam captures the mouse: the buttons must be clickable
	_set_focus(0)
	_refresh()


func options() -> Array:
	return def.get("options", [])


func honest() -> String:
	return String(def.get("honest", String((options()[0] as Dictionary)["key"]) if not options().is_empty() else ""))


func _build() -> void:
	dim = ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.0, 0.05, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	panel = PanelContainer.new()
	panel.name = "ChoicePanel"
	panel.custom_minimum_size = Vector2(780.0, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.04, 0.14, 0.94)
	sb.border_color = ORANGE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	title_label = _lbl(String(def.get("title", "LỰA CHỌN")).to_upper(), 18, ORANGE, false)
	title_label.name = "Title"
	v.add_child(title_label)
	prompt_label = _lbl(StoryUtil.fmt(String(def.get("prompt", ""))), 28, INK, true)
	prompt_label.name = "Prompt"
	v.add_child(prompt_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	v.add_child(row)
	for i: int in options().size():
		var o: Dictionary = options()[i]
		var b := Button.new()
		b.name = "Option%d" % (i + 1)
		b.text = StoryUtil.fmt(String(o.get("label", o.get("key", "?"))))
		b.custom_minimum_size = Vector2(330.0, 72.0)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_theme_font_size_override("font_size", 26)
		b.focus_mode = Control.FOCUS_ALL
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		b.pressed.connect(_on_pressed.bind(i))
		b.mouse_entered.connect(_set_focus.bind(i))
		row.add_child(b)
		buttons.append(b)
	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_row.add_theme_constant_override("separation", 12)
	v.add_child(bar_row)
	bar_back = ColorRect.new()
	bar_back.name = "CountdownBar"
	bar_back.custom_minimum_size = Vector2(BAR_W, 12.0)
	bar_back.color = Color(1.0, 1.0, 1.0, 0.15)
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(bar_back)
	bar_fill = ColorRect.new()
	bar_fill.name = "Fill"
	bar_fill.color = ORANGE
	bar_fill.size = Vector2(BAR_W, 12.0)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_back.add_child(bar_fill)
	secs_label = _lbl("10", 22, INK, false)
	secs_label.name = "Seconds"
	secs_label.custom_minimum_size = Vector2(36.0, 0.0)
	bar_row.add_child(secs_label)
	hint_label = _lbl("Bấm 1 hoặc 2, hoặc bấm chuột vào lựa chọn", 16, Color("#B9B2C8"), false)
	hint_label.name = "Hint"
	v.add_child(hint_label)
	line_label = _lbl("", 24, Color("#FFD84A"), true)
	line_label.name = "TimeoutLine"
	line_label.visible = false
	v.add_child(line_label)


## Labels never shrink to one letter per line: wrapping ones sit in the panel's 780 px minimum width.
func _lbl(text: String, size: int, col: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		l.custom_minimum_size = Vector2(700.0, 0.0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.06, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Real seconds the timeout line stays up: at least LINE_HOLD, and 0.06 s per character.
func line_hold() -> float:
	return maxf(LINE_HOLD, 0.06 * float(StoryUtil.fmt(String(def.get("timeout_line", "Hết giờ!"))).length()))


func remaining() -> float:
	return maxf(TIMEOUT - t, 0.0)


func _process(_d: float) -> void:
	if manual:
		return
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1e6
	_last_us = now
	step(dt)


## Advance the overlay by dt real seconds.
func step(dt: float) -> void:
	match phase:
		0:
			t += dt
			if t >= TIMEOUT - 1e-6:
				t = TIMEOUT
				timed_out = true
				_take(honest())
				phase = 2
				_hold = 0.0
				line_label.text = StoryUtil.fmt(String(def.get("timeout_line", "Hết giờ!")))
				line_label.visible = true
				hint_label.visible = false
		1:
			_hold += dt
			if _hold >= PICK_HOLD:
				_close()
		2:
			_hold += dt
			if _hold >= line_hold():
				_close()
	_refresh()


## Pick an option by key or index (mouse, keys and tests). Ignored once a choice is made.
func pick(which: Variant) -> void:
	if phase != 0:
		return
	var i: int = int(which) if (which is int or which is float) else _index_of(String(which))
	if i < 0 or i >= options().size():
		return
	_take(String((options()[i] as Dictionary)["key"]))
	phase = 1
	_hold = 0.0
	_refresh()


func _index_of(key: String) -> int:
	for i: int in options().size():
		if String((options()[i] as Dictionary)["key"]) == key:
			return i
	return -1


func _take(key: String) -> void:
	result = key
	_set_focus(maxi(_index_of(key), 0))
	if bool(def.get("record", true)):
		var sd: Node = StoryUtil.director()
		if sd:
			var ch: Variant = sd.get("choices")
			if ch is Dictionary and (ch as Dictionary).has(String(def.get("id", ""))):
				(ch as Dictionary)[String(def["id"])] = key


func _on_pressed(i: int) -> void:
	pick(i)


func _set_focus(i: int) -> void:
	focus_i = clampi(i, 0, maxi(buttons.size() - 1, 0))
	if phase == 0 and buttons.size() > focus_i and buttons[focus_i].is_inside_tree():
		buttons[focus_i].grab_focus()
	_refresh()


func _refresh() -> void:
	if bar_fill == null:
		return
	var k: float = remaining() / TIMEOUT
	bar_fill.size = Vector2(BAR_W * k, 12.0)
	bar_fill.color = RED if remaining() < 3.0 else ORANGE
	secs_label.text = str(int(ceil(remaining() - 1e-6)))
	var picked: int = _index_of(result)
	for i: int in buttons.size():
		var on: bool = (i == picked) if phase != 0 else (i == focus_i)
		buttons[i].modulate = Color(1.0, 0.75, 0.5) if on else (Color(1, 1, 1, 0.55) if phase != 0 else Color.WHITE)
		buttons[i].disabled = phase != 0


func _input(event: InputEvent) -> void:
	if phase != 0 or not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var k: Key = (event as InputEventKey).physical_keycode
	match k:
		KEY_1, KEY_KP_1:
			pick(0)
		KEY_2, KEY_KP_2:
			pick(1)
		KEY_LEFT, KEY_A:
			_set_focus(focus_i - 1)
		KEY_RIGHT, KEY_D:
			_set_focus(focus_i + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if t < ARM_S:
				return   # not armed yet: a tap meant for the subtitles
			pick(focus_i)
		_:
			return
	get_viewport().set_input_as_handled()


func _close() -> void:
	if phase == 3:
		return
	phase = 3
	if _paused_by_me and is_inside_tree():
		get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_was
	chosen.emit(result, timed_out)
	queue_free()


func _exit_tree() -> void:
	# freed before a choice (the host left): give the pause state back
	if phase != 3:
		Input.mouse_mode = _mouse_was
		if _paused_by_me and get_tree():
			get_tree().paused = _was_paused
