# File: res://scripts/cine/CineOverlay.gd
# 2D layer of the cinematic player (spec A1-D12): 2.39:1 letterbox bars that slide in from the screen edges, a black fade,
# bottom-centre subtitles (BBCode "Speaker:" in the speaker's colour, plus the "Dịch:" translation line), the "hold Esc to
# skip" bar, a tag (replays: "▶ REPLAY") and a debug read-out with a beat strip (white tick per impact, red playhead).
# Layout follows the viewport every frame; every accessor returns the live value. GameFX is reached only through
# get_node_or_null("/root/GameFX") + call() (vice font in vice style), so headless tests run without the autoload.
class_name CineOverlay
extends CanvasLayer

const ASPECT: float = 2.39
const SUB_SIZE: int = 26
const TR_SIZE: int = 20
const TR_COLOR: Color = Color("#D8D8D8")
const TAG_COLOR: Color = Color("#FFD84A")
const DEBUG_COLOR: Color = Color("#9CFF9C")
const STRIP_H: float = 14.0
const MARGIN: float = 16.0

var bar_top: ColorRect
var bar_bottom: ColorRect
var fade_rect: ColorRect
var sub_box: VBoxContainer
var sub_rich: RichTextLabel
var sub_tr: Label
var skip_box: HBoxContainer
var skip_label: Label
var skip_bar: ProgressBar
var tag_label: Label
var debug_label: Label
var strip: BeatStrip
var _letterbox: float = 0.0
var _fade: float = 0.0
var _sub_plain: String = ""
var _debug: bool = false


## Beat strip of the debug read-out: dark band, a white tick per impact (real time), red playhead at r / length.
class BeatStrip extends Control:
	var beats := PackedFloat32Array()
	var length: float = 1.0
	var r: float = 0.0

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.6))
		for b: float in beats:
			var x: float = w * clampf(b / maxf(length, 0.001), 0.0, 1.0)
			draw_line(Vector2(x, 1.0), Vector2(x, h - 1.0), Color.WHITE, 2.0)
		var px: float = w * clampf(r / maxf(length, 0.001), 0.0, 1.0)
		draw_line(Vector2(px, 0.0), Vector2(px, h), Color(1.0, 0.15, 0.15), 2.0)


func _init() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar_top = _bar("BarTop")
	bar_bottom = _bar("BarBottom")
	fade_rect = ColorRect.new()
	fade_rect.name = "Fade"
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)
	# subtitles
	sub_box = VBoxContainer.new()
	sub_box.name = "Subtitle"
	sub_box.alignment = BoxContainer.ALIGNMENT_END
	sub_box.add_theme_constant_override("separation", 2)
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub_box)
	sub_rich = RichTextLabel.new()
	sub_rich.bbcode_enabled = true
	sub_rich.fit_content = true
	sub_rich.scroll_active = false
	sub_rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_rich.add_theme_font_size_override("normal_font_size", SUB_SIZE)
	sub_rich.add_theme_constant_override("outline_size", 6)
	sub_rich.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_box.add_child(sub_rich)
	sub_tr = Label.new()
	sub_tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_tr.add_theme_font_size_override("font_size", TR_SIZE)
	sub_tr.add_theme_color_override("font_color", TR_COLOR)
	sub_tr.add_theme_constant_override("outline_size", 5)
	sub_tr.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_tr.visible = false
	sub_box.add_child(sub_tr)
	sub_box.visible = false
	# skip bar (top right)
	skip_box = HBoxContainer.new()
	skip_box.name = "Skip"
	skip_box.add_theme_constant_override("separation", 8)
	skip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skip_box)
	skip_label = Label.new()
	skip_label.text = "Giữ ESC để bỏ qua"
	skip_label.add_theme_font_size_override("font_size", 18)
	skip_label.add_theme_constant_override("outline_size", 4)
	skip_label.add_theme_color_override("font_outline_color", Color.BLACK)
	skip_box.add_child(skip_label)
	skip_bar = ProgressBar.new()
	skip_bar.min_value = 0.0
	skip_bar.max_value = 1.0
	skip_bar.step = 0.0
	skip_bar.show_percentage = false
	skip_bar.custom_minimum_size = Vector2(120.0, 12.0)
	skip_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_box.add_child(skip_bar)
	skip_box.visible = false
	# tag (top left)
	tag_label = Label.new()
	tag_label.name = "Tag"
	tag_label.add_theme_font_size_override("font_size", 22)
	tag_label.add_theme_color_override("font_color", TAG_COLOR)
	tag_label.add_theme_constant_override("outline_size", 5)
	tag_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(tag_label)
	# debug read-out
	debug_label = Label.new()
	debug_label.name = "Debug"
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
	debug_label.add_theme_font_override("font", mono)
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", DEBUG_COLOR)
	debug_label.add_theme_constant_override("outline_size", 3)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.visible = false
	add_child(debug_label)
	strip = BeatStrip.new()
	strip.name = "BeatStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.visible = false
	add_child(strip)


func _bar(nm: String) -> ColorRect:
	var b := ColorRect.new()
	b.name = nm
	b.color = Color("#000000")
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	return b


func _ready() -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("is_vice_ui") and bool(fx.call("is_vice_ui")):
		var f: Variant = fx.call("vice_font")
		if f is Font:
			sub_rich.add_theme_font_override("normal_font", f)
			tag_label.add_theme_font_override("font", f)
	_layout()


func _process(_d: float) -> void:
	_layout()


## Full-height bar of the 2.39:1 picture for the current viewport (0 when the screen is already wider).
func bar_height_full() -> float:
	var vs: Vector2 = _vp_size()
	return maxf((vs.y - vs.x / ASPECT) * 0.5, 0.0)


func _vp_size() -> Vector2:
	var vp: Viewport = get_viewport()
	return vp.get_visible_rect().size if vp else Vector2(1280.0, 720.0)


func _layout() -> void:
	var vs: Vector2 = _vp_size()
	var full: float = bar_height_full()
	var bh: float = full * _letterbox
	bar_top.position = Vector2.ZERO
	bar_top.size = Vector2(vs.x, bh)
	bar_bottom.position = Vector2(0.0, vs.y - bh)
	bar_bottom.size = Vector2(vs.x, bh)
	fade_rect.position = Vector2.ZERO
	fade_rect.size = vs
	var sw: float = minf(vs.x - 2.0 * MARGIN, 1000.0)
	var sh: float = sub_box.get_combined_minimum_size().y
	sub_box.size = Vector2(sw, sh)
	sub_box.position = Vector2((vs.x - sw) * 0.5, vs.y - 8.0 - sh)
	var kw: Vector2 = skip_box.get_combined_minimum_size()
	skip_box.size = kw
	skip_box.position = Vector2(vs.x - kw.x - MARGIN, MARGIN)
	tag_label.position = Vector2(MARGIN, MARGIN)
	debug_label.position = Vector2(MARGIN, MARGIN + 30.0)
	strip.position = Vector2(0.0, vs.y - full - STRIP_H)
	strip.size = Vector2(vs.x, STRIP_H)


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------
## f = 0 (no bars) .. 1 (bars of the 2.39:1 picture in place).
func set_letterbox(f: float) -> void:
	_letterbox = clampf(f, 0.0, 1.0)
	_layout()


func set_fade(a: float) -> void:
	_fade = clampf(a, 0.0, 1.0)
	fade_rect.modulate.a = _fade
	fade_rect.visible = _fade > 0.0


func show_sub(speaker: String, color: Color, text: String, tr: String = "") -> void:
	var plain: String = "%s: %s" % [speaker, text]
	if tr != "":
		plain += "\n" + tr
	if plain == _sub_plain and sub_box.visible:
		return
	_sub_plain = plain
	sub_rich.text = "[center][color=#%s]%s:[/color] %s[/center]" % [color.to_html(false), _esc(speaker), _esc(text)]
	sub_tr.text = tr
	sub_tr.visible = tr != ""
	sub_box.visible = true


func hide_sub() -> void:
	sub_box.visible = false
	_sub_plain = ""


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")


## progress 0..1 of the Esc hold; < 0 hides the bar.
func set_skip(progress: float) -> void:
	skip_box.visible = progress >= 0.0
	if progress >= 0.0:
		skip_bar.value = clampf(progress, 0.0, 1.0)


func set_tag(text: String) -> void:
	tag_label.text = text


func set_debug(on: bool) -> void:
	_debug = on
	debug_label.visible = on
	strip.visible = on


func update_debug(text: String, beats: PackedFloat32Array, length: float, r: float) -> void:
	debug_label.text = text
	strip.beats = beats
	strip.length = length
	strip.r = r
	strip.queue_redraw()


func letterbox_fraction() -> float:
	return _letterbox


func fade_alpha() -> float:
	return _fade


func sub_visible() -> bool:
	return sub_box.visible


func sub_text() -> String:
	return _sub_plain if sub_box.visible else ""


func debug_text() -> String:
	return debug_label.text
