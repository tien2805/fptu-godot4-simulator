# File: res://scripts/combat/bike/BikeHUD.gd
# HUD of the Phase C bike chase (spec C-D1), owned by BikeChase. Code-drawn, plain text (no emoji or decorative symbols;
# key glyphs only in the kick hints), vice / classic styles through CombatHUD's helpers:
#   - top centre: "Độ vững xe" with the stability bar and number (blinks below 25 %), under it "Bầy Sói còn: N" and
#     "Đợt i/n";
#   - bottom centre (above FreeRoam's hint line): "[Q] Đạp trái" and "[E] Đạp phải", dimmed during the kick cooldown,
#     lit on the side being kicked;
#   - left / right edge: a red arrow and "BÊN TRÁI" / "BÊN PHẢI" while a biker on that side winds up a kick;
#   - centre popups: the start line, "ĐẠP BAY!", "BỊ VÂY!", "Húc đuôi!", the knocked-off line, the win line.
# State for tests: popup_text, popups, warn_left, warn_right.
class_name BikeHUD
extends CanvasLayer

const PANEL_SIZE := Vector2(440.0, 78.0)
const PANEL_TOP: float = 18.0
const HINT_SIZE := Vector2(400.0, 40.0)
const HINT_BOTTOM: float = 112.0          # px above the bottom edge (FreeRoam's hint line sits below)
const WARN_SIZE := Vector2(190.0, 70.0)
const STAB_COL := Color("#3FE07A")
const LOW_COL := Color("#FF3B3B")

var chase: BikeChase
var panel: Control
var hints: Control
var warn_l: Control
var warn_r: Control
var popup_label: Label
var popup_text: String = ""
var popup_left: float = 0.0
var popup_len: float = 1.0
var popups: int = 0
var warn_left: bool = false
var warn_right: bool = false
var _linger: float = -1.0


func _ready() -> void:
	layer = 1
	panel = _make(Panel_.new(), "BikePanel", Control.PRESET_CENTER_TOP)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = PANEL_TOP
	panel.offset_bottom = PANEL_TOP + PANEL_SIZE.y
	hints = _make(Hints.new(), "BikeKickHints", Control.PRESET_CENTER_BOTTOM)
	hints.offset_left = -HINT_SIZE.x * 0.5
	hints.offset_right = HINT_SIZE.x * 0.5
	hints.offset_top = -HINT_BOTTOM - HINT_SIZE.y
	hints.offset_bottom = -HINT_BOTTOM
	warn_l = _make(Warn.new(), "BikeWarnLeft", Control.PRESET_CENTER_LEFT)
	(warn_l as Warn).right = false
	warn_l.offset_left = 12.0
	warn_l.offset_right = 12.0 + WARN_SIZE.x
	warn_l.offset_top = -WARN_SIZE.y * 0.5
	warn_l.offset_bottom = WARN_SIZE.y * 0.5
	warn_r = _make(Warn.new(), "BikeWarnRight", Control.PRESET_CENTER_RIGHT)
	(warn_r as Warn).right = true
	warn_r.offset_left = -12.0 - WARN_SIZE.x
	warn_r.offset_right = -12.0
	warn_r.offset_top = -WARN_SIZE.y * 0.5
	warn_r.offset_bottom = WARN_SIZE.y * 0.5
	popup_label = Label.new()
	popup_label.name = "BikePopup"
	popup_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup_label.offset_left = -380.0
	popup_label.offset_right = 380.0
	popup_label.offset_top = -190.0
	popup_label.offset_bottom = -130.0
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_label.add_theme_font_size_override("font_size", 40)
	popup_label.add_theme_color_override("font_outline_color", CombatHUD.INK)
	popup_label.add_theme_constant_override("outline_size", 10)
	popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_label.visible = false
	add_child(popup_label)
	visible = false


func _make(c: Control, nm: String, preset: int) -> Control:
	c.name = nm
	c.set("hud", self)
	c.set_anchors_and_offsets_preset(preset)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func show_hud() -> void:
	_linger = -1.0
	visible = true


func hide_hud() -> void:
	if _linger < 0.0:
		visible = false


## Stay visible `secs` more (a last popup), then hide.
func linger(secs: float) -> void:
	_linger = secs
	visible = true


## A centre popup for `secs` (default colour: the style accent).
func popup(text: String, col: Color = Color(0.0, 0.0, 0.0, 0.0), secs: float = 1.0) -> void:
	popup_text = text
	popup_len = maxf(secs, 0.3)
	popup_left = popup_len
	popups += 1
	popup_label.text = text
	popup_label.add_theme_font_override("font", CombatHUD.font())
	popup_label.add_theme_color_override("font_color", col if col.a > 0.0 else CombatHUD.accent())
	popup_label.visible = true
	popup_label.modulate.a = 1.0


func _process(delta: float) -> void:
	if _linger >= 0.0:
		_linger -= delta
		if _linger < 0.0:
			visible = false
	if popup_left > 0.0:
		popup_left -= delta
		var u: float = clampf(1.0 - popup_left / popup_len, 0.0, 1.0)
		popup_label.modulate.a = clampf(popup_left / 0.3, 0.0, 1.0)
		popup_label.pivot_offset = popup_label.size * 0.5
		popup_label.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - u * 6.0))
		if popup_left <= 0.0:
			popup_label.visible = false
	var m: int = chase.warn_mask() if chase and chase.state == "running" else 0
	warn_left = (m & 1) != 0
	warn_right = (m & 2) != 0
	if visible:
		panel.queue_redraw()
		hints.queue_redraw()
		warn_l.visible = warn_left
		warn_r.visible = warn_right
		if warn_left:
			warn_l.queue_redraw()
		if warn_right:
			warn_r.queue_redraw()


static func _text(ci: CanvasItem, f: Font, pos: Vector2, s: String, sz: int, col: Color, align: HorizontalAlignment, w: float) -> void:
	ci.draw_string_outline(f, pos, s, align, w, sz, 4, CombatHUD.INK)
	ci.draw_string(f, pos, s, align, w, sz, col)


## Stability bar, bikers left, wave.
class Panel_ extends Control:
	var hud: BikeHUD

	func _draw() -> void:
		var ch: BikeChase = hud.chase
		if ch == null or ch.combat == null:
			return
		var c: PlayerBikeCombat = ch.combat
		var f: Font = CombatHUD.font()
		var acc: Color = CombatHUD.accent()
		var k: float = clampf(c.stability / maxf(c.max_stability, 1.0), 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.55))
		draw_rect(Rect2(Vector2.ZERO, size), Color(acc, 0.8), false, 2.0)
		BikeHUD._text(self, f, Vector2(12.0, 28.0), BikeCombatData.T_STABILITY, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 110.0)
		var r := Rect2(Vector2(122.0, 14.0), Vector2(size.x - 122.0 - 56.0, 16.0))
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
		var col: Color = STAB_COL.lerp(LOW_COL, 1.0 - k) if k < 0.6 else STAB_COL
		if k < 0.25 and fmod(float(Time.get_ticks_msec()) / 1000.0, 0.5) < 0.25:
			col = col.lightened(0.45)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.5), false, 1.0)
		BikeHUD._text(self, f, Vector2(size.x - 50.0, 28.0), "%d" % int(ceil(c.stability)), 17, acc, HORIZONTAL_ALIGNMENT_RIGHT, 42.0)
		var left: String = BikeCombatData.T_LEFT % ch.remaining()
		BikeHUD._text(self, f, Vector2(12.0, 60.0), left, 17, CombatHUD.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 240.0)
		if ch.waves.size() > 1:
			var wv: String = BikeCombatData.T_WAVE % [clampi(ch.wave + 1, 1, ch.waves.size()), ch.waves.size()]
			BikeHUD._text(self, f, Vector2(size.x - 160.0, 60.0), wv, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 148.0)


## "[Q] Đạp trái" / "[E] Đạp phải": dim in the cooldown, lit on the side kicking.
class Hints extends Control:
	var hud: BikeHUD

	func _draw() -> void:
		var ch: BikeChase = hud.chase
		if ch == null or ch.combat == null:
			return
		var c: PlayerBikeCombat = ch.combat
		var f: Font = CombatHUD.font()
		var acc: Color = CombatHUD.accent()
		var can: bool = c.kick_cd <= 0.0 and not c.knocked
		var half: float = size.x * 0.5 - 6.0
		for i: int in 2:
			var side: int = -1 if i == 0 else 1
			var r := Rect2(Vector2(float(i) * (half + 12.0), 0.0), Vector2(half, size.y))
			var lit: bool = c.kicking() and c.kick_side == side
			var a: float = 1.0 if (can or lit) else 0.35
			draw_rect(r, Color(acc, 0.85 * a) if lit else Color(0.03, 0.02, 0.08, 0.55 * a))
			draw_rect(r, Color(acc, 0.9 * a), false, 2.0)
			var t: String = BikeCombatData.T_KICK_L if side < 0 else BikeCombatData.T_KICK_R
			BikeHUD._text(self, f, Vector2(r.position.x, r.position.y + 27.0), t, 18, Color(1.0, 1.0, 1.0, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Edge warning while a biker on that side winds up: a pulsing red arrow pointing out and the side's name.
class Warn extends Control:
	var hud: BikeHUD
	var right: bool = false

	func _draw() -> void:
		var pulse: float = 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) / 1000.0 * 20.0)
		var col := Color(CombatHUD.TELEGRAPH, pulse)
		var cy: float = size.y * 0.5
		var tip: float = size.x - 6.0 if right else 6.0
		var base: float = size.x - 46.0 if right else 46.0
		draw_colored_polygon(PackedVector2Array([Vector2(tip, cy), Vector2(base, cy - 24.0), Vector2(base, cy + 24.0)]), CombatHUD.INK)
		var tip2: float = tip - 4.0 if right else tip + 4.0
		var base2: float = base + 3.0 if right else base - 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(tip2, cy), Vector2(base2, cy - 18.0), Vector2(base2, cy + 18.0)]), col)
		var t: String = BikeCombatData.T_WARN_R if right else BikeCombatData.T_WARN_L
		var x0: float = 0.0 if right else 52.0
		BikeHUD._text(self, CombatHUD.font(), Vector2(x0, cy + 8.0), t, 22, col.lightened(0.2), HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, size.x - 56.0)
