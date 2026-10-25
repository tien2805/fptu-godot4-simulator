# File: res://scripts/horror/HorrorHUD.gd
# HUD of a horror level (spec B-D4): fuses n/3, the flashlight battery, the objective, the [E] prompt, the key hint
# "[F] Đèn pin", short toasts, the peek overlay while hidden (locker vent slats, a dark band above the gap under a stall
# door or a desk panel), the caught and escaped cards. Plain Vietnamese text, no emoji or decorative symbols (owner rule
# 2026-10-25). Code-built Controls only; no autoload identifiers (class_name script).
# Hold breath (H-D4): while hidden a breath bar with the plain line "Giữ Shift: nín thở" (set_breath).
class_name HorrorHUD
extends CanvasLayer

const HINT: String = "[F] Đèn pin    [Ctrl] Đi rón rén    [Shift] Chạy"
const BREATH_HINT: String = "Giữ Shift: nín thở"

var fuse_label: Label
var battery_label: Label
var battery_bar: ProgressBar
var objective_label: Label
var prompt_label: Label
var hint_label: Label
var toast_label: Label
var card_label: Label
var fade: ColorRect
var peek: Control
var peek_kind: String = ""
var breath_label: Label
var breath_bar: ProgressBar
var _toast_t: float = 0.0
var _fill: StyleBoxFlat
var _breath_fill: StyleBoxFlat


func _init() -> void:
	name = "HorrorHUD"
	layer = 10


func _ready() -> void:
	peek = Control.new()
	peek.name = "Peek"
	peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	peek.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(peek)
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	fuse_label = _label("Fuses", 26, Color("#FFD34D"))
	fuse_label.position = Vector2(24, 18)
	battery_label = _label("Battery", 20, Color("#E8F2FF"))
	battery_label.position = Vector2(24, 58)
	battery_bar = ProgressBar.new()
	battery_bar.name = "BatteryBar"
	battery_bar.show_percentage = false
	battery_bar.min_value = 0.0
	battery_bar.max_value = 100.0
	battery_bar.position = Vector2(24, 88)
	battery_bar.size = Vector2(220, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.08, 0.8)
	_fill = StyleBoxFlat.new()
	_fill.bg_color = Color("#9BE7A0")
	battery_bar.add_theme_stylebox_override("background", bg)
	battery_bar.add_theme_stylebox_override("fill", _fill)
	add_child(battery_bar)
	objective_label = _label("Objective", 22, Color("#F2EEE2"))
	_place(objective_label, Control.PRESET_CENTER_TOP, Rect2(-460, 18, 920, 60))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label = _label("Prompt", 30, Color.WHITE)
	_place(prompt_label, Control.PRESET_CENTER_BOTTOM, Rect2(-300, -130, 600, 44))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = _label("Hint", 18, Color(0.85, 0.88, 0.95, 0.85))
	_place(hint_label, Control.PRESET_BOTTOM_LEFT, Rect2(24, -44, 700, 30))
	hint_label.text = HINT
	toast_label = _label("Toast", 26, Color("#FFE9B0"))
	_place(toast_label, Control.PRESET_CENTER, Rect2(-430, -170, 860, 100))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_label = _label("Card", 64, Color("#FF5A4E"))
	_place(card_label, Control.PRESET_CENTER, Rect2(-500, -60, 1000, 160))
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.visible = false
	breath_label = _label("BreathHint", 22, Color("#DDEBFF"))
	_place(breath_label, Control.PRESET_CENTER_BOTTOM, Rect2(-200, -196, 400, 30))
	breath_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breath_label.text = BREATH_HINT
	breath_bar = ProgressBar.new()
	breath_bar.name = "BreathBar"
	breath_bar.show_percentage = false
	breath_bar.min_value = 0.0
	breath_bar.max_value = 100.0
	_place(breath_bar, Control.PRESET_CENTER_BOTTOM, Rect2(-130, -162, 260, 12))
	var bbg := StyleBoxFlat.new()
	bbg.bg_color = Color(0.05, 0.06, 0.08, 0.8)
	_breath_fill = StyleBoxFlat.new()
	_breath_fill.bg_color = Color("#9CC9FF")
	breath_bar.add_theme_stylebox_override("background", bbg)
	breath_bar.add_theme_stylebox_override("fill", _breath_fill)
	breath_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(breath_bar)
	set_breath(1.0, false, false)
	set_fuses(0)
	set_battery(1.0, false)


## Anchors from a preset, then offsets from those anchors (x, y, width, height).
func _place(c: Control, preset: Control.LayoutPreset, r: Rect2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _label(n: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.name = n
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_fuses(n: int, total: int = 3) -> void:
	if fuse_label:
		fuse_label.text = "Cầu chì: %d/%d" % [n, total]


func set_battery(frac: float, on: bool) -> void:
	if battery_bar == null:
		return
	var pct: int = int(round(clampf(frac, 0.0, 1.0) * 100.0))
	battery_bar.value = pct
	battery_label.text = "Pin đèn: %d%%%s" % [pct, "" if on else " (tắt)"]
	_fill.bg_color = Color("#FF6B5E") if frac < 0.2 else Color("#9BE7A0")


## Breath bar while hidden: frac 0..1 left, shown (hidden in a spot), held (Shift down).
func set_breath(frac: float, shown: bool, held: bool) -> void:
	if breath_bar == null:
		return
	breath_bar.visible = shown
	breath_label.visible = shown
	breath_bar.value = clampf(frac, 0.0, 1.0) * 100.0
	_breath_fill.bg_color = Color("#FF6B5E") if frac < 0.25 else (Color("#FFFFFF") if held else Color("#9CC9FF"))


func set_prompt(t: String) -> void:
	if prompt_label and prompt_label.text != t:
		prompt_label.text = t


func set_objective(t: String) -> void:
	if objective_label:
		objective_label.text = t


func toast(t: String, secs: float = 3.5) -> void:
	if toast_label:
		toast_label.text = t
		toast_label.modulate.a = 1.0
		_toast_t = secs


## Peek overlay while hidden: "locker" | "stall" | "desk" | "" (none).
func set_peek(kind: String) -> void:
	peek_kind = kind
	if peek == null:
		return
	for c: Node in peek.get_children():
		c.queue_free()
	match kind:
		"locker":
			for i: int in 7:
				var bar := ColorRect.new()
				bar.color = Color(0.02, 0.025, 0.03, 0.96)
				bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bar.anchor_left = 0.0
				bar.anchor_right = 1.0
				bar.anchor_top = float(i) / 7.0
				bar.anchor_bottom = float(i) / 7.0 + 0.09
				peek.add_child(bar)
		"stall", "desk":
			var band := ColorRect.new()
			band.color = Color(0.02, 0.025, 0.03, 0.97)
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.anchor_left = 0.0
			band.anchor_right = 1.0
			band.anchor_top = 0.0
			band.anchor_bottom = 0.42 if kind == "stall" else 0.3
			peek.add_child(band)


func show_caught(on: bool) -> void:
	if card_label == null:
		return
	card_label.visible = on
	card_label.text = "BỊ BẮT!" if on else ""
	card_label.add_theme_color_override("font_color", Color("#FF5A4E"))
	fade.color.a = 0.55 if on else 0.0
	if on:
		toast("Quay lại điểm lưu gần nhất...", 2.5)


func show_escaped(caught_count: int) -> void:
	if card_label == null:
		return
	card_label.visible = true
	card_label.text = "THOÁT RA NGOÀI!"
	card_label.add_theme_color_override("font_color", Color("#7CFFB2"))
	fade.color.a = 0.35
	set_prompt("")
	toast("Bị bắt %d lần" % caught_count if caught_count > 0 else "Không bị bắt lần nào", 6.0)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.6:
			toast_label.modulate.a = maxf(0.0, _toast_t / 0.6)
		if _toast_t <= 0.0:
			toast_label.text = ""
