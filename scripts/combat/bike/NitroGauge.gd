# File: res://scripts/combat/bike/NitroGauge.gd
# The nitro gauge (spec D2X-8): a self-contained CanvasLayer the PlayerBike owns, so any mode that enables nitro (free
# roam, the chase, the drift duel) gets it with no HUD change of its own. Bottom right, above FreeRoam's area label and
# clear of BikeHUD's side warnings. Code-drawn: the title "NITRO", a bar of the bike's drift_charge with a tick at the
# firing threshold (34), "[SHIFT]" once it can fire, blue and draining while nitro burns, a pulse when full.
# The bike decides when it shows (PlayerBike._sync_gauge): nitro enabled, the bike ridden (processing, not parked) and its
# chase camera the current camera (hidden in cinematics and replays).
class_name NitroGauge
extends CanvasLayer

const SIZE := Vector2(250.0, 58.0)
const RIGHT: float = 34.0
const BOTTOM: float = 190.0
const T_TITLE: String = "NITRO"
const T_READY: String = "[SHIFT]"
const T_HINT: String = "drift để nạp"
const COL_FILL := Color("#3FA9FF")
const COL_READY := Color("#7FE3FF")
const COL_BURN := Color("#9FD8FF")
const COL_BG := Color(0.05, 0.03, 0.12, 0.72)

var bike: PlayerBike
var box: Control
var charge: float = 0.0
var burning: bool = false
var burn_frac: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	layer = 2
	box = Box.new()
	box.name = "NitroBox"
	box.set("gauge", self)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -RIGHT - SIZE.x
	box.offset_right = -RIGHT
	box.offset_top = -BOTTOM - SIZE.y
	box.offset_bottom = -BOTTOM
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	visible = false


## The bike's state, read by the bike once per frame while shown (no allocation).
func refresh(c: float, burn: bool, frac: float, delta: float) -> void:
	_t += delta
	if absf(c - charge) > 0.05 or burn != burning or (burn and absf(frac - burn_frac) > 0.005) or c >= 99.9:
		charge = c
		burning = burn
		burn_frac = frac
		box.queue_redraw()


func ready_to_fire() -> bool:
	return charge >= PlayerBike.NITRO_MIN and not burning


class Box:
	extends Control
	var gauge: NitroGauge

	func _draw() -> void:
		if gauge == null:
			return
		var sz: Vector2 = size
		draw_rect(Rect2(Vector2.ZERO, sz), COL_BG)
		var accent: Color = CombatHUD.accent()
		draw_rect(Rect2(Vector2.ZERO, sz), accent, false, 2.0)
		var f: Font = CombatHUD.font()
		draw_string(f, Vector2(10.0, 21.0), T_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, COL_READY if gauge.ready_to_fire() or gauge.burning else Color(0.8, 0.82, 0.9))
		var hint: String = T_READY if gauge.ready_to_fire() else ("" if gauge.burning else T_HINT)
		draw_string(f, Vector2(0.0, 21.0), hint, HORIZONTAL_ALIGNMENT_RIGHT, sz.x - 10.0, 15, accent if gauge.ready_to_fire() else Color(0.7, 0.72, 0.8))
		var bar := Rect2(10.0, 30.0, sz.x - 20.0, 18.0)
		draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55))
		var frac: float = gauge.burn_frac if gauge.burning else clampf(gauge.charge / 100.0, 0.0, 1.0)
		var col: Color = COL_BURN if gauge.burning else (COL_READY if gauge.ready_to_fire() else COL_FILL)
		if gauge.charge >= 99.9 and not gauge.burning:
			col = col.lerp(Color.WHITE, 0.35 + 0.35 * sin(gauge._t * 9.0))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), col)
		var tick_x: float = bar.position.x + bar.size.x * PlayerBike.NITRO_MIN / 100.0
		draw_line(Vector2(tick_x, bar.position.y - 3.0), Vector2(tick_x, bar.end.y + 3.0), Color(1.0, 1.0, 1.0, 0.85), 2.0)
		draw_rect(bar, Color(1.0, 1.0, 1.0, 0.35), false, 1.0)
