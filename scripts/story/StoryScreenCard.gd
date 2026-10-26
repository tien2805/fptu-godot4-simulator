# File: res://scripts/story/StoryScreenCard.gd
# Full-screen "screen" inserts for the Phase B cinematics, drawn in code (no images), timed on the CinePlayer's REAL time:
#   kind "cctv"   a security-camera frame: grain, scanlines, "CAM 03  BÃI XE D1", a running timestamp, a blinking REC dot,
#                 and two silhouettes: a courier in a helmet hands a box ("hàng") to a buyer, who walks off with it
#                 (cine_d1_intro: Mr.T replays the CCTV);
#   kind "phone"  a phone lock screen with one notification (sender, message, time) (cine_d1: the courier's phone);
#   kind "radio"  (Phase C) a small walkie-talkie box in the upper left: the caller's name and a live waveform
#                 (cine_d3_intro: Anh Duy on the radio);
#   kind "credits" (Phase C) the end credits: a title, then "lines" roll up the black frame (end_c, ending C);
#   kind "flow"   (Phase C) a money-flow chart on a dark screen: "nodes" (3 boxes) light up one after another, joined by
#                 arrows that draw in, with "amounts" beside the arrows; the last node pulses (cine_d5: "TRÀ SỮA LỌ").
# data: {"kind", "cam", "place", "clock" ("21:47:05", seconds run on), "sender", "text", "time", "title", "lines"}.
# CineTimeline.card("screen", r, dur, data) places it; CinePlayer calls update(r). state_at(u) is pure (tests).
# Layer 106: above the HUD and StoryIntroCards / StoryDayCard (105), below the cinematic overlay (110: subtitles, fades).
class_name StoryScreenCard
extends CanvasLayer

const FADE: float = 0.25               # real seconds of fade in / out
const CCTV_SIZE := Vector2(760.0, 428.0)
const PHONE_SIZE := Vector2(330.0, 600.0)
const RADIO_SIZE := Vector2(420.0, 120.0)
const CREDITS_SIZE := Vector2(980.0, 540.0)
const FLOW_SIZE := Vector2(860.0, 360.0)

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
var title_label: Label
var roll: VBoxContainer
var flow_labels: Array[Label] = []


## Code-drawn screen content (redrawn when u changes).
class ScreenDraw extends Control:
	var kind: String = "cctv"
	var u: float = 0.0

	func _draw() -> void:
		var s: Vector2 = size
		if kind == "credits":
			draw_rect(Rect2(Vector2.ZERO, s), Color("#050507"))
			return
		if kind == "flow":
			draw_rect(Rect2(Vector2.ZERO, s), Color("#0A0F14"))
			for g: int in 9:
				draw_line(Vector2(0.0, s.y * g / 8.0), Vector2(s.x, s.y * g / 8.0), Color(0.3, 0.6, 0.5, 0.08), 1.0)
			for k: int in 3:
				var on: float = clampf((u - 0.12 - 0.27 * k) / 0.08, 0.0, 1.0)
				var r := Rect2(Vector2(s.x * (0.04 + 0.33 * k), s.y * 0.36), Vector2(s.x * 0.25, s.y * 0.28))
				var col: Color = Color("#FF8A3D") if k == 2 else Color("#5BD38A")
				if k == 2 and on >= 1.0:
					col = col.lightened(0.25 * absf(sin(u * 40.0)))
				draw_rect(r, Color(col.r, col.g, col.b, 0.18 * on))
				draw_rect(r, Color(col.r, col.g, col.b, on), false, 3.0)
				if k < 2:
					var a0 := Vector2(r.end.x + 6.0, r.get_center().y)
					var a1 := Vector2(s.x * (0.04 + 0.33 * (k + 1)) - 6.0, a0.y)
					var d: float = clampf((u - 0.2 - 0.27 * k) / 0.15, 0.0, 1.0)
					if d > 0.0:
						var tip: Vector2 = a0.lerp(a1, d)
						draw_line(a0, tip, Color("#FFD23F"), 4.0)
						if d >= 1.0:
							draw_colored_polygon(PackedVector2Array([a1, a1 + Vector2(-14.0, -9.0), a1 + Vector2(-14.0, 9.0)]), Color("#FFD23F"))
			return
		if kind == "radio":
			draw_rect(Rect2(Vector2.ZERO, s), Color("#10161A"))
			for i: int in 48:   # the live waveform (pure in u)
				var x: float = 150.0 + float(i) * 5.4
				var a: float = absf(sin(u * 61.0 + float(i) * 0.7)) * absf(sin(u * 17.0 + float(i) * 0.23)) * 34.0 + 3.0
				draw_rect(Rect2(x, s.y * 0.62 - a * 0.5, 3.0, a), Color("#5BD38A"))
			draw_circle(Vector2(60.0, s.y * 0.5), 34.0, Color("#1E2A30"))
			draw_rect(Rect2(52.0, s.y * 0.5 - 22.0, 16.0, 44.0), Color("#5BD38A"))
			return
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
	if kind() == "radio":
		cc.anchor_right = 0.4
		cc.anchor_bottom = 0.4
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
	if kind() == "radio":
		screen.custom_minimum_size = RADIO_SIZE
	elif kind() == "credits":
		screen.custom_minimum_size = CREDITS_SIZE
	elif kind() == "flow":
		screen.custom_minimum_size = FLOW_SIZE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.clip_contents = true
	frame.add_child(screen)
	if kind() == "flow":
		var nodes: Array = data.get("nodes", [])
		var amounts: Array = data.get("amounts", [])
		for k: int in nodes.size():
			var l: Label = _lbl(String(nodes[k]), 26, Color("#F4F1EA"))
			l.name = "Node%d" % k
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.position = Vector2(FLOW_SIZE.x * (0.04 + 0.33 * k), FLOW_SIZE.y * 0.36)
			l.size = Vector2(FLOW_SIZE.x * 0.25, FLOW_SIZE.y * 0.28)
			screen.add_child(l)
			flow_labels.append(l)
		for k2: int in amounts.size():
			var m: Label = _lbl(String(amounts[k2]), 20, Color("#FFD23F"))
			m.name = "Amount%d" % k2
			m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			m.position = Vector2(FLOW_SIZE.x * (0.27 + 0.33 * k2), FLOW_SIZE.y * 0.66)
			m.size = Vector2(FLOW_SIZE.x * 0.12, 30.0)
			screen.add_child(m)
			flow_labels.append(m)
		head_label = _lbl(String(data.get("title", "")), 22, Color("#9FE8C0"))
		head_label.name = "FlowTitle"
		head_label.position = Vector2(20.0, 14.0)
		screen.add_child(head_label)
		return
	if kind() == "radio":
		sender_label = _lbl("BỘ ĐÀM: " + String(data.get("sender", "")).to_upper(), 22, Color("#DDF5E4"))
		sender_label.name = "Sender"
		sender_label.position = Vector2(110.0, 14.0)
		screen.add_child(sender_label)
		return
	if kind() == "credits":
		title_label = _lbl(String(data.get("title", "")), 54, Color("#FFB23B"))
		title_label.name = "Title"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.size = Vector2(CREDITS_SIZE.x, 80.0)
		title_label.position = Vector2(0.0, 40.0)
		screen.add_child(title_label)
		roll = VBoxContainer.new()
		roll.name = "Roll"
		roll.add_theme_constant_override("separation", 14)
		roll.custom_minimum_size = Vector2(CREDITS_SIZE.x, 0.0)
		roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(roll)
		for line: Variant in data.get("lines", []):
			var l: Label = _lbl(String(line), 30, Color("#E8E4F0"))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(CREDITS_SIZE.x, 0.0)
			roll.add_child(l)
		return
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
	for k3: int in flow_labels.size():   # flow: each node / amount appears with its box / arrow
		var nn: int = (data.get("nodes", []) as Array).size()
		var t0: float = 0.12 + 0.27 * k3 if k3 < nn else 0.3 + 0.27 * (k3 - nn)
		flow_labels[k3].modulate.a = clampf((float(st["u"]) - t0) / 0.08, 0.0, 1.0)
	if roll:   # the credits roll up from below the title to past the top
		var u: float = float(st["u"])
		roll.position = Vector2(0.0, lerpf(CREDITS_SIZE.y, -roll.get_combined_minimum_size().y + 140.0, u))
		title_label.modulate.a = clampf(1.0 - (u - 0.25) / 0.15, 0.0, 1.0)
	if clock_label:
		clock_label.text = clock_at(String(data.get("clock", "21:47:05")), maxf(r - r0, 0.0) * 1.0)
