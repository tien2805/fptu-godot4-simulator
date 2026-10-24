# File: res://scripts/weapons/RadialWheel.gd
# Data-driven GTA-style radial wheel shared by the weapon wheel (WeaponWheel, spec W-D1, section 2) and the emote wheel
# (EmoteWheel, W-D10, section 9). Subclasses only fill the slot list and the trigger:
#   - slots: up to 8 {"name": String, "icon": int, "enabled": bool}, one wedge each (slot 0 at the top, clockwise); icons
#     drawn in code by icon_fn(ci, icon, center, size, col, dark) (empty = WeaponIcons.draw); disabled slots are drawn
#     greyed with "Sắp có" and cannot be chosen;
#   - hold trigger_mouse (a mouse button) or trigger_key (a physical key) >= HOLD_S real seconds to open; a tap is ignored;
#   - the mouse delta accumulates into a virtual stick (clamped to STICK_MAX px): inside DEAD_ZONE px nothing new is
#     highlighted (keep_current: the current slot stays highlighted; otherwise none); outside it, the enabled wedge under
#     the stick angle;
#   - releasing the trigger emits `selected(slot)` (keep_current: only when it differs from current; otherwise whenever a
#     slot is highlighted); Esc or right click close without choosing; scroll_cycles: mouse-wheel scroll (closed) emits
#     `cycled(step)`.
# While open the game runs at Engine.time_scale SLOW (0.2), eased in and out over EASE_S real seconds; the wheel itself runs
# in real time (PROCESS_MODE_ALWAYS, Time.get_ticks_usec, or step_real(dt) when `manual`). blocked_fn (cinematic, replay,
# busted, community service, riding, map, the other wheel open, tree paused) stops it from opening and closes it at once
# (time scale back to 1.0). This file lives OUTSIDE scripts/cine/: A1-D6 forbids cinematic code to write Engine.time_scale.
# It restores 1.0 when it leaves the tree. GameFX / StageManager are never named here.
class_name RadialWheel
extends CanvasLayer

signal selected(slot: int)
signal cycled(step: int)
signal opened
signal closed(changed: bool)

const HOLD_S: float = 0.12
const DEAD_ZONE: float = 40.0
const STICK_MAX: float = 140.0
const SLOW: float = 0.2
const EASE_S: float = 0.1
const R_OUT: float = 190.0
const R_IN: float = 78.0
const ICON_SIZE: float = 54.0
const RING_BG := Color(0.04, 0.03, 0.09, 0.78)
const RING_OFF := Color(0.02, 0.02, 0.04, 0.6)
const SEP := Color(1.0, 1.0, 1.0, 0.12)
const ICON_COL := Color("#F4F1FF")
const ICON_OFF := Color(0.55, 0.55, 0.6, 0.55)
const ICON_DARK := Color(0.08, 0.05, 0.15, 0.95)
const VICE_HI := Color("#FF5FB0")
const VICE_RIM := Color("#3FF2FF")
const CLASSIC_HI := Color("#F37021")
const CLASSIC_RIM := Color("#FFFFFF")
const SOON: String = "Sắp có"

var slots: Array[Dictionary] = []
var trigger_mouse: MouseButton = MOUSE_BUTTON_NONE
var trigger_key: Key = KEY_NONE
var keep_current: bool = true
var scroll_cycles: bool = false
var hint: String = ""                    # centre text while nothing is highlighted
var icon_fn: Callable                    # (ci, icon, center, size, col, dark); empty = WeaponIcons.draw
var current: int = 0
var highlight: int = 0
var stick: Vector2 = Vector2.ZERO
var info_fn: Callable                    # slot -> String (second centre line, e.g. "12 / ∞")
var blocked_fn: Callable                 # -> bool
var manual: bool = false
var vice: bool = true
var view: Control
var _open: bool = false
var _pressing: bool = false
var _press_t: float = 0.0
var _scale_from: float = 1.0
var _scale_to: float = 1.0
var _ease_t: float = -1.0
var _wrote: bool = false
var _last_us: int = 0


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	var v := WheelView.new()
	v.name = "WheelView"
	v.wheel = self
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.visible = false
	add_child(v)
	view = v
	_last_us = Time.get_ticks_usec()


func _exit_tree() -> void:
	if _wrote and not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0
	_open = false
	_pressing = false
	_ease_t = -1.0


func is_open() -> bool:
	return _open


func is_enabled(slot: int) -> bool:
	return slot >= 0 and slot < slots.size() and bool(slots[slot].get("enabled", true))


func is_blocked() -> bool:
	return blocked_fn.is_valid() and bool(blocked_fn.call())


func press() -> void:
	if _open or is_blocked():
		return
	_pressing = true
	_press_t = 0.0


func release() -> void:
	if _open:
		close(true)
	_pressing = false


func cancel() -> void:
	_pressing = false
	if _open:
		close(false)


func feed_mouse(rel: Vector2) -> void:
	if not _open:
		return
	stick = (stick + rel).limit_length(STICK_MAX)
	var w: int = WeaponMath.wedge_for(stick, DEAD_ZONE, slots.size())
	if w >= 0 and is_enabled(w):
		highlight = w
	else:
		highlight = current if keep_current else -1
	view.queue_redraw()


func scroll(step: int) -> void:
	if not scroll_cycles or _open or _pressing or is_blocked():
		return
	cycled.emit(step)


func open() -> void:
	if _open:
		return
	_open = true
	_pressing = false
	stick = Vector2.ZERO
	highlight = current if keep_current else -1
	vice = ViceHUD.style_active()
	view.visible = true
	view.queue_redraw()
	_ease_to(SLOW)
	opened.emit()


func close(apply: bool) -> void:
	if not _open:
		return
	_open = false
	view.visible = false
	_ease_to(1.0)
	var changed: bool = apply and highlight >= 0 and (highlight != current or not keep_current)
	if changed:
		selected.emit(highlight)
	closed.emit(changed)


## Real-time tick (wall-clock seconds): time-scale ease (an ease started in this tick begins on the next one), hold timer,
## block check.
func step_real(dt: float) -> void:
	if _ease_t >= 0.0:
		_ease_t += dt
		var u: float = clampf(_ease_t / EASE_S, 0.0, 1.0)
		_set_scale(lerpf(_scale_from, _scale_to, u * u * (3.0 - 2.0 * u)))
		if u >= 1.0:
			_ease_t = -1.0
	if _pressing:
		_press_t += dt
		if _press_t >= HOLD_S - 1e-6:
			open()
	if (_open or _pressing) and is_blocked():
		_force_close()


func _process(_d: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1e6
	_last_us = now
	if not manual:
		step_real(dt)


func _ease_to(target: float) -> void:
	_scale_from = Engine.time_scale
	_scale_to = target
	_ease_t = 0.0


func _set_scale(v: float) -> void:
	Engine.time_scale = v
	_wrote = true


func _force_close() -> void:
	_pressing = false
	if _open:
		_open = false
		view.visible = false
		closed.emit(false)
	_ease_t = -1.0
	if _wrote:
		_set_scale(1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if trigger_mouse != MOUSE_BUTTON_NONE and mb.button_index == trigger_mouse:
			if mb.pressed:
				press()
			else:
				release()
			get_viewport().set_input_as_handled()
			return
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				if _open and mb.pressed:
					cancel()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if _open:
					get_viewport().set_input_as_handled()   # no mouse capture / fire click while choosing
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					scroll(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					scroll(1)
	elif event is InputEventMouseMotion and _open:
		feed_mouse((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()   # the camera does not turn while choosing
	elif event is InputEventKey:
		var k: InputEventKey = event
		if trigger_key != KEY_NONE and k.physical_keycode == trigger_key and not k.echo:
			if k.pressed:
				press()
			else:
				release()
			get_viewport().set_input_as_handled()
			return
		if _open and k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()   # Esc closes the wheel, not the pause menu


## The ring: one wedge per slot (highlighted one in the accent colour, disabled ones greyed with "Sắp có"), separators,
## code-drawn icons, the centre name + info line.
class WheelView extends Control:
	var wheel: RadialWheel

	func _draw() -> void:
		var n: int = wheel.slots.size()
		if n == 0:
			return
		var c: Vector2 = size * 0.5
		var hi: Color = RadialWheel.VICE_HI if wheel.vice else RadialWheel.CLASSIC_HI
		var rim: Color = RadialWheel.VICE_RIM if wheel.vice else RadialWheel.CLASSIC_RIM
		var font: Font = ThemeDB.fallback_font
		var w: float = TAU / float(n)
		for i: int in n:
			var on: bool = wheel.is_enabled(i)
			var a0: float = WeaponMath.wedge_angle(i, n) - w * 0.5
			var pts := PackedVector2Array()
			for k: int in 9:
				pts.append(c + WeaponMath.wedge_point(a0 + w * float(k) / 8.0) * RadialWheel.R_OUT)
			for k2: int in range(8, -1, -1):
				pts.append(c + WeaponMath.wedge_point(a0 + w * float(k2) / 8.0) * RadialWheel.R_IN)
			var bg: Color = Color(hi, 0.85) if i == wheel.highlight else (RadialWheel.RING_BG if on else RadialWheel.RING_OFF)
			draw_colored_polygon(pts, bg)
			draw_line(c + WeaponMath.wedge_point(a0) * RadialWheel.R_IN, c + WeaponMath.wedge_point(a0) * RadialWheel.R_OUT, RadialWheel.SEP, 2.0)
			var ic: Vector2 = c + WeaponMath.wedge_point(WeaponMath.wedge_angle(i, n)) * (RadialWheel.R_IN + RadialWheel.R_OUT) * 0.5
			var col: Color = RadialWheel.ICON_COL if on else RadialWheel.ICON_OFF
			var icon: int = int(wheel.slots[i].get("icon", i))
			if wheel.icon_fn.is_valid():
				wheel.icon_fn.call(self, icon, ic, RadialWheel.ICON_SIZE, col, RadialWheel.ICON_DARK)
			else:
				WeaponIcons.draw(self, icon, ic, RadialWheel.ICON_SIZE, col, RadialWheel.ICON_DARK)
			if not on:
				draw_string(font, ic + Vector2(-40.0, 40.0), RadialWheel.SOON, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, RadialWheel.ICON_OFF)
		draw_arc(c, RadialWheel.R_OUT + 2.0, 0.0, TAU, 96, rim, 3.0, true)
		draw_circle(c, RadialWheel.R_IN - 6.0, Color(0.02, 0.01, 0.05, 0.85))
		var h: int = wheel.highlight
		var title: String = String(wheel.slots[h].get("name", "")) if h >= 0 and h < n else wheel.hint
		var info: String = String(wheel.info_fn.call(h)) if wheel.info_fn.is_valid() and h >= 0 else ""
		draw_string(font, c + Vector2(-RadialWheel.R_IN, -4.0), title, HORIZONTAL_ALIGNMENT_CENTER, RadialWheel.R_IN * 2.0, 20, Color.WHITE)
		draw_string(font, c + Vector2(-RadialWheel.R_IN, 22.0), info, HORIZONTAL_ALIGNMENT_CENTER, RadialWheel.R_IN * 2.0, 18, rim)
		if wheel.stick.length() >= RadialWheel.DEAD_ZONE:
			draw_circle(c + wheel.stick.normalized() * (RadialWheel.R_IN - 14.0), 5.0, hi)
