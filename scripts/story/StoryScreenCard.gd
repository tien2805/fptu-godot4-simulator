# File: res://scripts/story/StoryScreenCard.gd
# Full-screen "screen" inserts for the Phase B cinematics, drawn in code (no images), timed on the CinePlayer's REAL time:
#   kind "cctv"   a security-camera frame: grain, scanlines, "CAM 03  BÃI XE D1", a running timestamp, a blinking REC dot,
#                 and two silhouettes: a courier in a helmet hands a box ("hàng") to a buyer, who walks off with it
#                 (cine_d1_intro: Mr.T replays the CCTV);
#   kind "phone"  a phone lock screen with one notification (sender, message, time) (cine_d1: the courier's phone).
# data: {"kind", "cam", "place", "clock" ("21:47:05", seconds run on), "sender", "text", "time"}.
# CineTimeline.card("screen", r, dur, data) places it; CinePlayer calls update(r). state_at(u) is pure (tests).
# Layer 106: above the HUD and StoryIntroCards / StoryDayCard (105), below the cinematic overlay (110: subtitles, fades).
class_name StoryScreenCard
extends CanvasLayer

const FADE: float = 0.25               # real seconds of fade in / out
const CCTV_SIZE := Vector2(760.0, 428.0)
const PHONE_SIZE := Vector2(330.0, 600.0)

var data: Dictionary = {}
var r0: float = 0.0
var dur: float = 4.0
var frame: Control
var screen: ScreenDraw
var head_label: Label
var clock_label: Label
var rec_label: Label
var sender_label: Label
var text_label: Label
var time_label: Label
var last_state: Dictionary = {}


## Code-drawn screen content (redrawn when u changes).
class ScreenDraw extends Control:
	var kind: String = "cctv"
	var u: float = 0.0

	func _draw() -> void:
		var s: Vector2 = size
		if kind == "phone":
			draw_rect(Rect2(Vector2.ZERO, s), Color("#0E1430"))
			for i: int in 6:   # soft wallpaper bands
				draw_rect(Rect2(0.0, s.y * (0.15 + 0.13 * i), s.x, s.y * 0.06), Color(0.3, 0.2, 0.6, 0.12))
			return
		draw_rect(Rect2(Vector2.ZERO, s), Color("#16231C"))
		# parking lot: lane lines, a roof edge, two parked bikes
		draw_rect(Rect2(0.0, s.y * 0.62, s.x, s.y * 0.38), Color("#1F3127"))
		for i: int in 5:
			draw_line(Vector2(s.x * (0.1 + 0.2 * i), s.y * 0.62), Vector2(s.x * (0.02 + 0.24 * i), s.y), Color(0.6, 0.75, 0.6, 0.35), 2.0)
		draw_rect(Rect2(0.0, 0.0, s.x, s.y * 0.12), Color("#0C140F"))
		for bx: float in [0.12, 0.84]:
			draw_rect(Rect2(s.x * bx, s.y * 0.55, s.x * 0.09, s.y * 0.1), Color("#2C3D33"))
			draw_circle(Vector2(s.x * bx + 6.0, s.y * 0.66), 8.0, Color("#26352C"))
			draw_circle(Vector2(s.x * (bx + 0.09) - 6.0, s.y * 0.66), 8.0, Color("#26352C"))
		# the courier (helmet) and the buyer; the box passes between them, then the buyer walks off with it
		var hand_off: float = clampf((u - 0.3) / 0.25, 0.0, 1.0)
		var leave: float = clampf((u - 0.62) / 0.3, 0.0, 1.0)
		var cx: float = s.x * 0.4
		var bxp: float = s.x * (0.58 + 0.3 * leave)
		_person(Vector2(cx, s.y * 0.7), true)
		_person(Vector2(bxp, s.y * 0.71), false)
		var box_x: float = lerpf(cx + 26.0, bxp - 22.0, hand_off) if leave <= 0.0 else bxp - 22.0
		draw_rect(Rect2(box_x - 14.0, s.y * 0.53, 28.0, 22.0), Color("#C9A27A"))
		draw_line(Vector2(box_x - 14.0, s.y * 0.53 + 11.0), Vector2(box_x + 14.0, s.y * 0.53 + 11.0), Color("#7A5A3A"), 2.0)
		# scanlines and grain
		var y: float = 0.0
		while y < s.y:
			draw_line(Vector2(0.0, y), Vector2(s.x, y), Color(0.0, 0.0, 0.0, 0.18), 1.0)
			y += 4.0
		var rng := RandomNumberGenerator.new()
		rng.seed = int(u * 240.0)
		for i: int in 140:
			draw_rect(Rect2(rng.randf() * s.x, rng.randf() * s.y, 2.0, 2.0), Color(0.8, 1.0, 0.85, 0.08))
		# REC dot (blinks once a second) beside the steady "REC" label
		if fmod(u * 12.0, 1.0) < 0.6:
			draw_circle(Vector2(s.x - 92.0, 26.0), 8.0, Color("#FF3030"))

	func _person(feet: Vector2, helmet: bool) -> void:
		var c: Color = Color("#0A0F0C")
		draw_rect(Rect2(feet.x - 18.0, feet.y - 92.0, 36.0, 60.0), c)
		draw_rect(Rect2(feet.x - 15.0, feet.y - 34.0, 12.0, 34.0), c)
		draw_rect(Rect2(feet.x + 3.0, feet.y - 34.0, 12.0, 34.0), c)
		draw_circle(Vector2(feet.x, feet.y - 106.0), 15.0 if helmet else 12.0, Color("#3A4A3F") if helmet else c)
		if helmet:
			draw_rect(Rect2(feet.x - 15.0, feet.y - 110.0, 30.0, 6.0), Color("#5E7266"))


## {shown, alpha, u (0..1 through the window)}.
static func state_at(r: float, start: float, length: float) -> Dictionary:
	var u: float = (r - start) / maxf(length, 0.001)
	var a: float = clampf(minf((r - start) / FADE, (start + length - r) / FADE), 0.0, 1.0)
	return {"shown": u >= 0.0 and u < 1.0, "alpha": a, "u": clampf(u, 0.0, 1.0)}


func kind() -> String:
	return String(data.get("kind", "cctv"))


func _ready() -> void:
	layer = 106
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	update(r0 - 1.0)


func _build() -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.anchor_bottom = 0.92
	cc.offset_bottom = 0.0
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var phone: bool = kind() == "phone"
	frame = PanelContainer.new()
	frame.name = "Frame"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#101010")
	sb.border_color = Color("#2A2A2A") if not phone else Color("#3A3A44")
	sb.set_border_width_all(10 if phone else 6)
	sb.set_corner_radius_all(36 if phone else 4)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 18
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(frame)
	screen = ScreenDraw.new()
	screen.name = "Screen"
	screen.kind = kind()
	screen.custom_minimum_size = PHONE_SIZE if phone else CCTV_SIZE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.clip_contents = true
	frame.add_child(screen)
	if phone:
		time_label = _lbl(String(data.get("time", "23:58")), 64, Color.WHITE)
		time_label.position = Vector2(0.0, 60.0)
		time_label.size = Vector2(PHONE_SIZE.x, 80.0)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		screen.add_child(time_label)
		var note := PanelContainer.new()
		note.name = "Notification"
		var nb := StyleBoxFlat.new()
		nb.bg_color = Color(0.95, 0.95, 0.98, 0.94)
		nb.set_corner_radius_all(16)
		nb.content_margin_left = 14
		nb.content_margin_right = 14
		nb.content_margin_top = 10
		nb.content_margin_bottom = 12
		note.add_theme_stylebox_override("panel", nb)
		note.position = Vector2(16.0, 210.0)
		note.custom_minimum_size = Vector2(PHONE_SIZE.x - 32.0, 0.0)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(note)
		var nv := VBoxContainer.new()
		note.add_child(nv)
		sender_label = _lbl(String(data.get("sender", "")), 22, Color("#1A1A24"))
		sender_label.name = "Sender"
		nv.add_child(sender_label)
		text_label = _lbl(String(data.get("text", "")), 24, Color("#1A1A24"), true)
		text_label.name = "Message"
		text_label.custom_minimum_size = Vector2(PHONE_SIZE.x - 60.0, 0.0)
		nv.add_child(text_label)
	else:
		head_label = _lbl("%s   %s" % [String(data.get("cam", "CAM 03")), String(data.get("place", "BÃI XE D1"))], 22, Color("#DDF5E4"))
		head_label.name = "CamName"
		head_label.position = Vector2(18.0, 12.0)
		screen.add_child(head_label)
		rec_label = _lbl("REC", 22, Color("#FF5050"))
		rec_label.name = "Rec"
		rec_label.position = Vector2(CCTV_SIZE.x - 76.0, 12.0)
		screen.add_child(rec_label)
		clock_label = _lbl("", 22, Color("#DDF5E4"))
		clock_label.name = "Clock"
		clock_label.position = Vector2(18.0, CCTV_SIZE.y - 40.0)
		screen.add_child(clock_label)


func _lbl(text: String, size: int, c: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## "21:47:05" advanced by `secs` seconds.
static func clock_at(base: String, secs: float) -> String:
	var p: PackedStringArray = base.split(":")
	var total: int = 0
	if p.size() >= 2:
		total = int(p[0]) * 3600 + int(p[1]) * 60 + (int(p[2]) if p.size() >= 3 else 0)
	total += int(floor(secs))
	return "%02d:%02d:%02d" % [(total / 3600) % 24, (total / 60) % 60, total % 60]


func update(r: float) -> void:
	var st: Dictionary = state_at(r, r0, dur)
	last_state = st
	frame.visible = bool(st["shown"])
	if not frame.visible:
		return
	frame.modulate.a = float(st["alpha"])
	screen.u = float(st["u"])
	screen.queue_redraw()
	if clock_label:
		clock_label.text = clock_at(String(data.get("clock", "21:47:05")), maxf(r - r0, 0.0) * 1.0)
