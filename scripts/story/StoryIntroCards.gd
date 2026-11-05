# File: res://scripts/story/StoryIntroCards.gd
# 2D cards over the ai_intro fallback cinematic (spec A2-D10), all drawn in code, timed on the CinePlayer's REAL time r:
#   1.4-5.0   the email "Phòng Khảo thí: Quyết định đình chỉ thi" on a phone screen, its body typed out over 1.5-2.8
#             (then it holds 1.2 s for reading before the stamp);
#   4.0       a huge red "TOANG!" stamp slams onto it (scale 3 -> 1 in 0.18 s, tilted) and stays until 5.0;
#   4.9-8.0   Mr.T's text "Thầy tin em. Tìm bằng chứng đi.";
#   8.6-13.0  the countdown "CÒN N NGÀY" flips 10 -> 7 (lands on 7 at 10.0) and holds;
#   13.4-20   the title card "TOOL ĐEN" / "7 ngày minh oan".
# (Wave 6, plan 2026-11-05-w6-cines T4: the 24 s fallback is now 20 s; the email is typed out in 3.5 s instead of 6.)
# state_at(r) is a pure function (tests); update(r) applies it. Reads `player.r` itself each frame when a player is set
# (PROCESS_MODE_ALWAYS: the cinematic pauses the tree). Layer 105: above the HUD, below the cinematic's own overlay (110+).
class_name StoryIntroCards
extends CanvasLayer

const GameFXScript: Script = preload("res://scripts/GameFX.gd")
const EMAIL := [1.4, 5.0]
const TYPE := [1.5, 2.8]   # the email body types out, then holds until the stamp (STAMP_AT)
const STAMP_AT: float = 4.0
const STAMP_SLAM: float = 0.18
const TEXT := [4.9, 8.0]
const COUNT := [8.6, 13.0]
const COUNT_FROM: int = 10
const COUNT_LAND: float = 10.0
const TITLE := [13.4, 20.0]
## Mr.T's text and the countdown sit in the top band of the screen (anchor 0 .. TOP_BAND), above the faces.
const TOP_BAND: float = 0.42
const PINK := Color("#FF4FA3")
const RED := Color("#E8202E")

var player: Node = null
var email_box: PanelContainer
var email_body: Label
var stamp: Label
var text_box: PanelContainer
var count_label: Label
var title_box: Control
var last_state: Dictionary = {}


## Card state at real time r: {email, typed (0..1 of the email body shown), stamp_scale (0 = hidden), text, count (-1 =
## hidden), title, title_alpha}.
static func state_at(r: float) -> Dictionary:
	var st: Dictionary = {"email": r >= EMAIL[0] and r < EMAIL[1], "stamp_scale": 0.0, "text": r >= TEXT[0] and r < TEXT[1],
		"count": -1, "title": r >= TITLE[0], "title_alpha": 0.0,
		"typed": clampf((r - float(TYPE[0])) / (float(TYPE[1]) - float(TYPE[0])), 0.0, 1.0)}
	if r >= STAMP_AT and r < EMAIL[1]:
		var u: float = clampf((r - STAMP_AT) / STAMP_SLAM, 0.0, 1.0)
		st["stamp_scale"] = lerpf(3.0, 1.0, u * u)
	if r >= COUNT[0] and r < COUNT[1]:
		var k: float = clampf((r - COUNT[0]) / (COUNT_LAND - COUNT[0]), 0.0, 1.0)
		st["count"] = COUNT_FROM - int(floor(k * float(COUNT_FROM - 7) + 1e-6))
	if st["title"]:
		st["title_alpha"] = clampf((r - TITLE[0]) / 0.5, 0.0, 1.0)
	return st


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	update(0.0)
	if player and is_instance_valid(player):
		visible = not bool(player.get("prerolling"))   # no one-frame flash over gameplay before the first _process


func _panel(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


## wrap: only the email body and Mr.T's text wrap (they sit in boxes with a minimum width); a wrapping label in a bare
## CenterContainer would shrink to one letter per line (review A2-R3).
func _lbl(text: String, size: int, col: Color, italic: bool = false, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08, 0.95))
	l.add_theme_constant_override("outline_size", 6 if size >= 30 else 2)
	if italic:
		l.add_theme_font_override("font", GameFXScript.vice_font(0.9, 0.26))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A full-width CenterContainer from the top of the screen down to `bottom` (anchor fraction).
func _centered(min_size: Vector2, bottom: float = 1.0) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.anchor_bottom = bottom
	c.offset_bottom = 0.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var holder := Control.new()
	holder.custom_minimum_size = min_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(holder)
	return c


func _build() -> void:
	var c1: CenterContainer = _centered(Vector2.ZERO)
	email_box = PanelContainer.new()
	email_box.name = "Email"
	email_box.custom_minimum_size = Vector2(460.0, 0.0)
	email_box.add_theme_stylebox_override("panel", _panel(Color("#F7F5FA"), Color("#3A2950"), 18))
	email_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c1.add_child(email_box)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 8)
	email_box.add_child(ev)
	ev.add_child(_lbl("Hộp thư · 07:02", 14, Color("#6A5A80")))
	ev.add_child(_lbl("Phòng Khảo thí", 20, Color("#2A1C3C")))
	ev.add_child(_lbl("QUYẾT ĐỊNH ĐÌNH CHỈ THI", 26, RED))
	email_body = _lbl(StoryUtil.fmt("Sinh viên {name} bị đình chỉ thi môn EOS do nghi vấn mang thiết bị gian lận (kính thông minh) vào phòng 311. Hội đồng kỷ luật họp sau 7 ngày."), 15, Color("#2A1C3C"), false, true)
	email_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # the box keeps its size while it types
	ev.add_child(email_body)
	var c2: CenterContainer = _centered(Vector2.ZERO)
	stamp = _lbl("TOANG!", 120, RED, true)
	stamp.name = "Stamp"
	stamp.add_theme_color_override("font_outline_color", Color("#5A0008"))
	stamp.add_theme_constant_override("outline_size", 14)
	stamp.rotation_degrees = -12.0
	c2.add_child(stamp)
	var c3: CenterContainer = _centered(Vector2.ZERO, TOP_BAND)   # upper third: clear of the face in the close-ups
	text_box = PanelContainer.new()
	text_box.name = "MrTText"
	text_box.custom_minimum_size = Vector2(420.0, 0.0)
	text_box.add_theme_stylebox_override("panel", _panel(Color(0.12, 0.06, 0.2, 0.96), Color("#B98CFF"), 22))
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c3.add_child(text_box)
	var tv := VBoxContainer.new()
	text_box.add_child(tv)
	tv.add_child(_lbl("Mr.T", 18, Color("#B98CFF")))
	tv.add_child(_lbl("Thầy tin em. Tìm bằng chứng đi.", 24, Color("#F4F1FF"), false, true))
	var c4: CenterContainer = _centered(Vector2.ZERO, TOP_BAND)
	count_label = _lbl("", 72, PINK, true)
	count_label.name = "Countdown"
	c4.add_child(count_label)
	title_box = Control.new()
	title_box.name = "Title"
	title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_box)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.0, 0.08, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(dim)
	var tc := CenterContainer.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(tc)
	var tvb := VBoxContainer.new()
	tvb.name = "TitleColumn"
	tvb.custom_minimum_size = Vector2(720.0, 0.0)   # the pastel strip under the title needs a width
	tvb.add_theme_constant_override("separation", 4)
	tc.add_child(tvb)
	tvb.add_child(_lbl("TOOL ĐEN", 110, PINK, true))
	tvb.add_child(GameFXScript.pastel_strip(8.0))
	tvb.add_child(_lbl("7 ngày minh oan", 36, Color("#3FF2FF"), true))


func update(r: float) -> void:
	var st: Dictionary = state_at(r)
	last_state = st
	email_box.visible = bool(st["email"])
	email_body.visible_ratio = float(st["typed"])
	var sc: float = float(st["stamp_scale"])
	stamp.visible = sc > 0.0
	if sc > 0.0:
		stamp.pivot_offset = stamp.size * 0.5
		stamp.scale = Vector2(sc, sc)
		stamp.modulate.a = clampf(1.2 - (sc - 1.0) * 0.4, 0.0, 1.0)
	text_box.visible = bool(st["text"])
	count_label.visible = int(st["count"]) >= 0
	if count_label.visible:
		count_label.text = "CÒN %d NGÀY" % int(st["count"])
	title_box.visible = bool(st["title"])
	title_box.modulate.a = float(st["title_alpha"])


func _process(_d: float) -> void:
	if player and is_instance_valid(player):
		visible = not bool(player.get("prerolling"))   # hidden while the host fades to black before the cinematic
		update(float(player.get("r")))
