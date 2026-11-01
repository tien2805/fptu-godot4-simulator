# File: res://scripts/story/Day7Clock.gd
# Day 7's 08:00 countdown (Phase D, plan 2026-11-01-w4-day7.md): Lọ Academy pushes its tool onto the exam system at 08:00.
# The time left lives in StoryDirector.flags["d7_clock"] (seconds, saved with the story). It runs only while a tower mission
# runs (StoryTower ticks it by the mission's own clock: never during cinematics, replays, cards or the fail card) and is
# shown on the HUD for the whole of Day 7 (free roam too), generous but always visible:
#   - START_S real seconds of missions from 05:30 to 08:00 (SECS_PER_MIN real seconds per game minute);
#   - under WARN_S the label turns red and pulses;
#   - at 0 the running mission fails with T_LATE under the title T_TITLE; THỬ LẠI gives the clock back GRACE_S (Anh Duy "lags" Lọ's server: a fair
#     checkpoint, the retry never starts at 08:00 again).
# Static helpers take the director (or null: tests and the scene smoke run without a story); the node is the HUD.
class_name Day7Clock
extends CanvasLayer

const FLAG: String = "d7_clock"
const START_S: float = 1500.0
const SECS_PER_MIN: float = 10.0
const START_MIN: int = 5 * 60 + 30            # 05:30
const DEADLINE_MIN: int = 8 * 60               # 08:00
const GRACE_S: float = 240.0
const WARN_S: float = 200.0
const T_LATE: String = "08:00 rồi! Tool đã lên hệ thống thi..."
const T_TITLE: String = "08:00"
const T_SUB: String = "Kỳ thi mở lúc 08:00"
const T_GRACE: String = "Anh Duy câu thêm giờ cho mày rồi!"
const GOLD := Color("#FFD27A")
const RED := Color("#FF4A5A")

## Shown only while this returns true (the host: no cinematic, its HUD visible).
var visible_fn: Callable = Callable()
var director: Node = null
var time_label: Label
var sub_label: Label
var panel: PanelContainer
var _acc: float = 0.0
var _shown: String = ""
var _pulse: float = 0.0


# ---------------------------------------------------------------------------
# State (static)
# ---------------------------------------------------------------------------
static func remaining(dir: Node) -> float:
	if dir == null:
		return START_S
	return float((dir.get("flags") as Dictionary).get(FLAG, START_S))


static func set_remaining(dir: Node, secs: float) -> void:
	if dir != null:
		(dir.get("flags") as Dictionary)[FLAG] = maxf(0.0, secs)


## Counts dt seconds down; true when this tick reached 0 (the mission fails).
static func tick(dir: Node, dt: float) -> bool:
	if dir == null or dt <= 0.0:
		return false
	var before: float = remaining(dir)
	if before <= 0.0:
		return false
	set_remaining(dir, before - dt)
	return remaining(dir) <= 0.0


static func expired(dir: Node) -> bool:
	return dir != null and remaining(dir) <= 0.0


## THỬ LẠI after the clock ran out (or any retry): at least GRACE_S on the clock. True when time was added.
static func grace(dir: Node) -> bool:
	if dir == null or remaining(dir) >= GRACE_S:
		return false
	set_remaining(dir, GRACE_S)
	return true


## Day 7 of a running story (the HUD shows).
static func is_day7(dir: Node) -> bool:
	return dir != null and bool(dir.get("active")) and int(dir.get("day")) == 7 and String(dir.get("ending")) == ""


## The game time for `secs` left: "05:30" .. "08:00".
static func clock_text(secs: float) -> String:
	var mins_left: int = ceili(maxf(secs, 0.0) / SECS_PER_MIN)
	var m: int = clampi(DEADLINE_MIN - mins_left, START_MIN, DEADLINE_MIN)
	return "%02d:%02d" % [m / 60, m % 60]


## The HUD under `host` (a CanvasLayer of its own).
static func attach(host: Node, dir: Node, vis: Callable = Callable()) -> Day7Clock:
	var c := Day7Clock.new()
	c.director = dir
	c.visible_fn = vis
	host.add_child(c)
	return c


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------
func _init() -> void:
	name = "Day7Clock"
	layer = 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -214.0
	panel.offset_right = -24.0
	panel.offset_top = 132.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.02, 0.78)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	time_label = _label(30, GOLD)
	vb.add_child(time_label)
	sub_label = _label(13, Color("#F4E9D8"))
	sub_label.text = T_SUB
	vb.add_child(sub_label)
	refresh()


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	_acc += delta
	_pulse += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	refresh()


## Text, colour and visibility now (10 Hz from _process; tests call it).
func refresh() -> void:
	var show: bool = is_day7(director) and (not visible_fn.is_valid() or bool(visible_fn.call()))
	if visible != show:
		visible = show
	if not show or time_label == null:
		return
	var secs: float = remaining(director)
	var t: String = clock_text(secs)
	if t != _shown:
		_shown = t
		time_label.text = t
	var warn: bool = secs <= WARN_S
	var col: Color = RED if warn else GOLD
	if warn:
		col = col.lerp(Color.WHITE, 0.35 * (0.5 + 0.5 * sin(_pulse * 7.0)))
	time_label.add_theme_color_override("font_color", col)
