# File: res://scripts/story/StoryVillainCard.gd
# Villain intro card (spec B-D8, story spec 8.4): over a freeze frame, a colour wash, a diagonal band in the villain's
# colour, the name, the nickname and a one-line joke slide in. Optional pointer (Cừu Dolly): a drawn arrow points at
# `point_wrong` first with `wrong_line` beside it ("…à nhầm, con kia"), then swings to `point_right`. Plain text only.
#
# data: {"name": "Cừu Dolly", "nick": "trùm thi hộ", "joke": "...", "color": Color, "point_wrong": Vector2 (screen fraction),
#        "point_right": Vector2, "wrong_line": "…à nhầm, con kia", "switch_u": 0.45 (card fraction where the pointer moves),
#        "name_run": " DEFGH IJKLMN ..." (Phase C, Alexander: the rest of an endless name types on after the name and runs off
#        the band, then the whole name shrinks to fit: name_chars_at / name_scale_at)}
#
# In a timeline: CineTimeline.villain(name, r, dur, data) adds a "card" clock ramp (story time stops for dur real seconds)
# and this card on [r, r + dur); CinePlayer calls update(r) every frame (pure: state_at(u)). In gameplay:
# StoryVillainCard.show_for(parent, data, dur) pauses the tree for dur real seconds, then frees itself (signal finished).
class_name StoryVillainCard
extends CanvasLayer

signal finished

const IN_U: float = 0.12               # slide-in fraction of the card
const OUT_U: float = 0.1               # fade-out fraction at the end
const TEXT_W: float = 600.0
## The band and text stay in the lower-left of the frame (x <= BAND_X1, y >= BAND_Y0, screen fractions) so the clones and
## the pointed-at villain stay visible; the bottom letterbox bar starts at about y 0.87.
const BAND_Y0: float = 0.6
const BAND_X1: float = 0.55
## Phase C endless name: types on over [RUN_U0, RUN_U1), then shrinks to fit over [RUN_U1, SHRINK_U1).
const RUN_U0: float = 0.14
const RUN_U1: float = 0.5
const SHRINK_U1: float = 0.62
## Width the shrunk name fits in (px at the 1280-wide reference; inside the band).
const FIT_W: float = 560.0

var data: Dictionary = {}
var r0: float = 0.0
var dur: float = 2.4
var standalone: bool = false
var manual: bool = false
var wash: ColorRect
var band: Polygon2D
var box: VBoxContainer
var name_label: Label
var nick_label: Label
var joke_label: Label
var pointer: Node2D
var wrong_label: Label
var last_state: Dictionary = {}
var name_full: String = ""          # name + name_run, upper case (Phase C)
var name_fit: float = 1.0           # scale of the whole long name that fits FIT_W
var _t: float = 0.0
var _was_paused: bool = false
var _last_us: int = 0


## Card state at fraction u (0..1) of its window: {shown, alpha, slide (0..1), pointer (0 = wrong, 1 = right, -1 none),
## wrong_line (bool)}.
static func state_at(u: float, has_pointer: bool, switch_u: float = 0.45) -> Dictionary:
	var shown: bool = u >= 0.0 and u < 1.0
	var a_in: float = clampf(u / IN_U, 0.0, 1.0)
	var a_out: float = clampf((1.0 - u) / OUT_U, 0.0, 1.0)
	var st: Dictionary = {"shown": shown, "alpha": minf(a_in, a_out), "slide": 1.0 - pow(1.0 - a_in, 3.0), "pointer": -1.0,
		"wrong_line": false}
	if has_pointer and shown:
		var m: float = clampf((u - switch_u) / 0.12, 0.0, 1.0)
		st["pointer"] = m * m * (3.0 - 2.0 * m)
		st["wrong_line"] = u >= switch_u - 0.2 and u < switch_u + 0.22
	return st


## Characters of the endless name shown at card fraction u (n_base: the name, n_run: the rest).
static func name_chars_at(u: float, n_base: int, n_run: int) -> int:
	var k: float = clampf((u - RUN_U0) / (RUN_U1 - RUN_U0), 0.0, 1.0)
	return n_base + int(floor(float(n_run) * k))


## Scale of the name label at card fraction u: 1 while it runs on, then down to fit (the whole name inside FIT_W).
static func name_scale_at(u: float, fit: float) -> float:
	var k: float = clampf((u - RUN_U1) / (SHRINK_U1 - RUN_U1), 0.0, 1.0)
	return lerpf(1.0, minf(fit, 1.0), k * k * (3.0 - 2.0 * k))


static func show_for(parent: Node, d: Dictionary, length: float = 2.6) -> StoryVillainCard:
	var c := StoryVillainCard.new()
	c.data = d
	c.dur = length
	c.standalone = true
	parent.add_child(c)
	return c


func _ready() -> void:
	layer = 108   # above the HUD and the screen cards, below the cinematic overlay (110: letterbox, subtitles, skip fade)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if standalone:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_last_us = Time.get_ticks_usec()
	update(r0 if not standalone else 0.0)


func col() -> Color:
	return data.get("color", Color("#F2D7A6"))


func has_pointer() -> bool:
	return data.has("point_wrong") and data.has("point_right")


func _build() -> void:
	wash = ColorRect.new()
	wash.name = "Wash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	band = Polygon2D.new()
	band.name = "Band"
	add_child(band)
	box = VBoxContainer.new()
	box.name = "Text"
	box.custom_minimum_size = Vector2(TEXT_W, 0.0)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	name_label = _lbl(String(data.get("name", "???")).to_upper(), 60, Color.WHITE, false)
	name_label.name = "Name"
	box.add_child(name_label)
	if data.has("name_run"):
		name_full = (String(data.get("name", "")) + String(data["name_run"])).to_upper()
		name_label.text = name_full
		name_fit = FIT_W / maxf(name_label.get_combined_minimum_size().x, 1.0)
		name_label.text = String(data.get("name", "???")).to_upper()
	nick_label = _lbl(String(data.get("nick", "")), 30, col().lightened(0.35), false)
	nick_label.name = "Nick"
	box.add_child(nick_label)
	joke_label = _lbl(String(data.get("joke", "")), 22, Color("#F4F1FF"), true)
	joke_label.name = "Joke"
	box.add_child(joke_label)
	pointer = Node2D.new()
	pointer.name = "Pointer"
	add_child(pointer)
	var arrow := Polygon2D.new()   # a drawn arrow pointing down at the target (shape, not a text symbol)
	arrow.polygon = PackedVector2Array([Vector2(-9, -70), Vector2(9, -70), Vector2(9, -26), Vector2(22, -26), Vector2(0, 0),
		Vector2(-22, -26), Vector2(-9, -26)])
	arrow.color = Color("#FFD84A")
	pointer.add_child(arrow)
	var rim := Line2D.new()
	rim.points = arrow.polygon
	rim.add_point(arrow.polygon[0])
	rim.width = 3.0
	rim.default_color = Color(0.1, 0.05, 0.0)
	pointer.add_child(rim)
	wrong_label = _lbl(String(data.get("wrong_line", "")), 28, Color("#FFD84A"), false)
	wrong_label.name = "WrongLine"
	wrong_label.position = Vector2(30.0, -66.0)
	pointer.add_child(wrong_label)


func _lbl(text: String, size: int, c: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		l.custom_minimum_size = Vector2(TEXT_W, 0.0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.06, 0.95))
	l.add_theme_constant_override("outline_size", 10 if size >= 60 else 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _vp() -> Vector2:
	var vp: Viewport = get_viewport()
	var s: Vector2 = vp.get_visible_rect().size if vp else Vector2(1280.0, 720.0)
	return s if s.x > 10.0 else Vector2(1280.0, 720.0)


## Apply the card at real time r (its window is [r0, r0 + dur)).
func update(r: float) -> void:
	var u: float = (r - r0) / maxf(dur, 0.001)
	var st: Dictionary = state_at(u, has_pointer(), float(data.get("switch_u", 0.45)))
	last_state = st
	var on: bool = bool(st["shown"])
	for n: CanvasItem in [wash, band, box, pointer]:
		n.visible = on
	if not on:
		return
	var a: float = float(st["alpha"])
	var vs: Vector2 = _vp()
	wash.color = Color(col().r, col().g, col().b, 0.38 * a)
	var sl: float = float(st["slide"])
	var off: float = (1.0 - sl) * -vs.x * 0.6
	band.polygon = PackedVector2Array([Vector2(off, vs.y * (BAND_Y0 + 0.02)), Vector2(off + vs.x * BAND_X1, vs.y * BAND_Y0),
		Vector2(off + vs.x * (BAND_X1 - 0.04), vs.y * 0.9), Vector2(off, vs.y * 0.9)])
	band.color = Color(col().darkened(0.45).r, col().darkened(0.45).g, col().darkened(0.45).b, 0.92 * a)
	box.position = Vector2(off + vs.x * 0.035, vs.y * (BAND_Y0 + 0.015))
	box.modulate.a = a
	if name_full != "":
		var nb: int = String(data.get("name", "")).length()
		name_label.text = name_full.substr(0, name_chars_at(u, nb, name_full.length() - nb))
		var k: float = name_scale_at(u, name_fit * vs.x / 1280.0)
		var fs: int = maxi(8, int(round(60.0 * k)))   # shrink by font size: the layout shrinks too (no gap above the nick)
		if fs != name_label.get_theme_font_size("font_size"):
			name_label.add_theme_font_size_override("font_size", fs)
		st["name_scale"] = k
		st["name_size"] = fs
		st["name_chars"] = name_label.text.length()
	var pv: float = float(st["pointer"])
	pointer.visible = pv >= 0.0
	if pv >= 0.0:
		var pw: Vector2 = data["point_wrong"]
		var pr: Vector2 = data["point_right"]
		pointer.position = pw.lerp(pr, pv) * vs
		pointer.modulate.a = a
		wrong_label.visible = bool(st["wrong_line"])


func _process(_d: float) -> void:
	if not standalone or manual:
		return
	var now: int = Time.get_ticks_usec()
	step(float(now - _last_us) / 1e6)
	_last_us = now


## Standalone timing (gameplay or manual tests).
func step(dt: float) -> void:
	if _t >= dur:
		return
	_t += dt
	update(_t)
	if _t >= dur:
		if standalone and is_inside_tree():
			get_tree().paused = _was_paused
		finished.emit()
		queue_free()


func _exit_tree() -> void:
	# freed mid-card (standalone): give the pause state back
	if standalone and _t < dur and get_tree():
		get_tree().paused = _was_paused
