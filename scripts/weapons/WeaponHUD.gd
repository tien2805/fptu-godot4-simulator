# File: res://scripts/weapons/WeaponHUD.gd
# Phase W on-foot weapon HUD:
#   - a widget under the top-right HUD column (WIDGET_TOP px, below the ViceHUD clock / money / stars): the code-drawn icon of
#     the equipped weapon, its name, the ammo "12 / ∞" (or "Đang nạp…") and a small "[Chuột giữa] vũ khí" hint;
#   - a crosshair at the screen centre while aiming (gap = spread);
#   - a short toast with the weapon name when the mouse wheel cycles.
# Plain custom-drawn Controls (no PanelContainer), vice italic font in vice style (GameFX.vice_font through preload), FPT
# orange accent in classic. FreeRoam hides it on the bike, in cinematics and while the map is open.
# Q2: hit_marker(ko) draws an X at the screen centre (aimed or not): white for a hit, red and bigger for a knockout,
# fading over MARK_S / MARK_KO_S.
class_name WeaponHUD
extends CanvasLayer

const GameFXScript: Script = preload("res://scripts/GameFX.gd")
const WIDGET_SIZE := Vector2(236.0, 70.0)
const WIDGET_TOP: float = 168.0
const WIDGET_RIGHT: float = 28.0
const TOAST_S: float = 1.2
const INK := Color("#1B0F33")
const VICE_ACCENT := Color("#3FF2FF")
const CLASSIC_ACCENT := Color("#F37021")

var slot: int = 0
var ammo: String = "∞"
var reloading: bool = false
var aiming: bool = false
var spread_px: float = 14.0
var widget: Control
var crosshair: Control
var toast_label: Label
var _toast_left: float = 0.0
## Q2 hit marker: the view, seconds left, knockout flag, how many were shown (tests).
const MARK_S: float = 0.22
const MARK_KO_S: float = 0.4
var marker: Control
var marker_left: float = 0.0
var marker_ko: bool = false
var markers_shown: int = 0


func _ready() -> void:
	layer = 1
	var w := Widget.new()
	w.name = "WeaponWidget"
	w.hud = self
	w.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	w.offset_left = -WIDGET_RIGHT - WIDGET_SIZE.x
	w.offset_right = -WIDGET_RIGHT
	w.offset_top = WIDGET_TOP
	w.offset_bottom = WIDGET_TOP + WIDGET_SIZE.y
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(w)
	widget = w
	var c := Crosshair.new()
	c.name = "Crosshair"
	c.hud = self
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.offset_left = -40.0
	c.offset_right = 40.0
	c.offset_top = -40.0
	c.offset_bottom = 40.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	add_child(c)
	crosshair = c
	toast_label = Label.new()
	toast_label.name = "Toast"
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -200.0
	toast_label.offset_right = 200.0
	toast_label.offset_top = 96.0
	toast_label.offset_bottom = 132.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_outline_color", INK)
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	add_child(toast_label)
	var hm := HitMarker.new()
	hm.name = "HitMarker"
	hm.hud = self
	hm.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hm.offset_left = -40.0
	hm.offset_right = 40.0
	hm.offset_top = -40.0
	hm.offset_bottom = 40.0
	hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hm.visible = false
	add_child(hm)
	marker = hm


static func vice() -> bool:
	return ViceHUD.style_active()


func accent() -> Color:
	return VICE_ACCENT if vice() else CLASSIC_ACCENT


func font() -> Font:
	return GameFXScript.vice_font(0.6, 0.22) if vice() else ThemeDB.fallback_font


func set_weapon(s: int, ammo_text: String, is_reloading: bool) -> void:
	slot = s
	ammo = ammo_text
	reloading = is_reloading
	if widget:
		widget.queue_redraw()


func set_aim(on: bool, px: float) -> void:
	if on == aiming and is_equal_approx(px, spread_px):
		return
	aiming = on
	spread_px = px
	if crosshair:
		crosshair.visible = on
		crosshair.queue_redraw()


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.add_theme_font_override("font", font())
	toast_label.add_theme_color_override("font_color", accent())
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	_toast_left = TOAST_S


## A hit on a person: the X at the centre (red, bigger and longer for a knockout).
func hit_marker(ko: bool) -> void:
	marker_ko = ko
	marker_left = MARK_KO_S if ko else MARK_S
	markers_shown += 1
	if marker:
		marker.visible = true
		marker.modulate.a = 1.0
		marker.queue_redraw()


func _process(delta: float) -> void:
	if marker_left > 0.0:
		marker_left -= delta
		if marker:
			marker.modulate.a = clampf(marker_left / 0.12, 0.0, 1.0)
			if marker_left <= 0.0:
				marker.visible = false
	if _toast_left <= 0.0:
		return
	_toast_left -= delta
	toast_label.modulate.a = clampf(_toast_left / 0.3, 0.0, 1.0)
	if _toast_left <= 0.0:
		toast_label.visible = false


class Widget extends Control:
	var hud: WeaponHUD

	func _draw() -> void:
		var f: Font = hud.font()
		var acc: Color = hud.accent()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.55))
		draw_rect(Rect2(Vector2.ZERO, size), Color(acc, 0.8), false, 2.0)
		WeaponIcons.draw(self, hud.slot, Vector2(36.0, size.y * 0.5), 48.0, Color("#F4F1FF"), Color(0.08, 0.05, 0.15, 0.95))
		_text(f, Vector2(72.0, 24.0), WeaponData.name_of(hud.slot), 19, Color.WHITE)
		_text(f, Vector2(72.0, 47.0), "Đang nạp…" if hud.reloading else hud.ammo, 18, acc)
		_text(ThemeDB.fallback_font, Vector2(72.0, 64.0), "[Chuột giữa] vũ khí", 11, Color(0.85, 0.85, 0.9))

	func _text(f: Font, pos: Vector2, s: String, sz: int, col: Color) -> void:
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, size.x - pos.x - 6.0, sz, 4, WeaponHUD.INK)
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, size.x - pos.x - 6.0, sz, col)


class HitMarker extends Control:
	var hud: WeaponHUD

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var ko: bool = hud.marker_ko
		var col: Color = Color("#FF3B3B") if ko else Color(1.0, 1.0, 1.0)
		var g: float = 7.0 if ko else 6.0
		var l: float = 13.0 if ko else 9.0
		for d: Vector2 in [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]:
			var n: Vector2 = d.normalized()
			draw_line(c + n * g, c + n * (g + l), WeaponHUD.INK, 5.0)
			draw_line(c + n * g, c + n * (g + l), col, 2.5 if ko else 2.0)


class Crosshair extends Control:
	var hud: WeaponHUD

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var g: float = 4.0 + hud.spread_px
		var col: Color = hud.accent()
		for d: Vector2 in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
			draw_line(c + d * g, c + d * (g + 9.0), WeaponHUD.INK, 4.0)
			draw_line(c + d * g, c + d * (g + 9.0), col, 2.0)
		draw_circle(c, 2.0, col)
