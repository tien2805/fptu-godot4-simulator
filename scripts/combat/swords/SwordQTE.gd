# File: res://scripts/combat/swords/SwordQTE.gd
# W3 D5W-3 (plan 2026-10-30-w3-day5.md T6): the katana duel's finisher QTE. start(prompts, window) shows the prompts one
# after another, each for `window` REAL seconds (counted in physics frames, so the duel's slow motion never stretches it):
# the right key in time moves to the next prompt (`prompt_shown(i)`), the last one emits `passed`; a wrong key or a window
# running out emits `missed` (the result of each prompt in `results`). Keys: "q" ([Q]), "lmb" (left mouse), "e" ([E]);
# press(key) is the input path (tests call it). Plain text only. Its own CanvasLayer (a big prompt and a shrinking bar).
# manual: the owner steps it with step(dt) (tests that drive frames themselves).
class_name SwordQTE
extends CanvasLayer

signal passed
signal missed
signal prompt_shown(index: int)

## The duel's three prompts: [Q] gạt (parry), [Chuột trái] chém (slash), [E] hạ gục (take down).
const PROMPTS: Array = [{"key": "q", "label": "[Q] GẠT"}, {"key": "lmb", "label": "[Chuột trái] CHÉM"}, {"key": "e", "label": "[E] HẠ GỤC"}]

var prompts: Array = []
var window: float = 0.9
var index: int = -1
var t: float = 0.0
var active: bool = false
var manual: bool = false
var results: Array[String] = []
## Physics frames each prompt stayed up (tests: the windows in frames).
var frames_up: Array[int] = []
var label: Label
var bar: ProgressBar
var _frames: int = 0


func _init() -> void:
	layer = 8
	name = "SwordQTE"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = 60.0
	box.offset_bottom = 160.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color("#FFE66D"))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 9)
	box.add_child(label)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(320.0, 12.0)
	bar.show_percentage = false
	bar.max_value = 1.0
	box.add_child(bar)
	visible = false


## Shows prompts[0] for `window` real seconds, then the next ones on success.
func start(p: Array = PROMPTS, w: float = 0.9) -> void:
	prompts = p.duplicate()
	window = maxf(0.1, w)
	results.clear()
	frames_up.clear()
	active = true
	visible = true
	_show(0)


func stop() -> void:
	active = false
	visible = false
	index = -1


func _show(i: int) -> void:
	index = i
	t = 0.0
	_frames = 0
	if label:
		label.text = String((prompts[i] as Dictionary)["label"])
	if bar:
		bar.value = 1.0
	prompt_shown.emit(i)


## The key the current prompt wants ("" when none).
func wanted() -> String:
	return String((prompts[index] as Dictionary)["key"]) if active and index >= 0 and index < prompts.size() else ""


## A key press: "hit" (next prompt / passed), "wrong" (missed), "none" (no QTE running).
func press(key: String) -> String:
	if not active:
		return "none"
	if key != wanted():
		_end(false, "wrong")
		return "wrong"
	results.append("hit")
	frames_up.append(_frames)
	if index + 1 >= prompts.size():
		active = false
		visible = false
		index = -1
		passed.emit()
	else:
		_show(index + 1)
	return "hit"


func _end(ok: bool, why: String) -> void:
	results.append(why)
	frames_up.append(_frames)
	active = false
	visible = false
	index = -1
	if ok:
		passed.emit()
	else:
		missed.emit()


func _physics_process(_delta: float) -> void:
	if not manual and active:
		step(1.0 / float(Engine.physics_ticks_per_second))   # real time: the slow motion never stretches a window


func step(dt: float) -> void:
	if not active:
		return
	t += dt
	_frames += 1
	if bar:
		bar.value = clampf(1.0 - t / window, 0.0, 1.0)
	if t >= window - 1e-5:
		_end(false, "late")


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var key: String = ""
	if event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed or k.echo:
			return
		match k.physical_keycode:
			KEY_Q:
				key = "q"
			KEY_E:
				key = "e"
			KEY_SPACE, KEY_F, KEY_R:
				key = "other"                    # the duel's other action keys count as a wrong press
			_:
				return                           # movement and the rest are ignored
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			key = "lmb"
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			key = "other"
		else:
			return
	else:
		return
	press(key)
	get_viewport().set_input_as_handled()
