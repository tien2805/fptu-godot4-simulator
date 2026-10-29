# File: res://scripts/story/lairs/BasementGuide.gd
# W3 Day 5 readability (plan 2026-10-30-w3-day5.md T9; the owner on another level: enemies off screen "chạy mất tiêu",
# directions unclear). A code-drawn overlay a basement mission owns (plain shapes and Vietnamese text, no emoji):
#   - the objective: set_goal(world_pos, text) shows a cyan diamond with the text and the distance over the spot while it is
#     on screen, and an arrow on the screen edge toward it (with the text and the distance) while it is off screen or behind
#     the camera; clear_goal(). In the blackout it is the one bright thing on screen (unshaded, Readability.ZONE);
#   - threats: watch(fight, near_m) marks every alerted gunman of the fight that is off screen with a red chevron on the edge
#     (Readability.DANGER); with near_m > 0 (the stealth) an unalerted guard within near_m gets a dim one; when no alerted
#     gunman has been in sight (on screen with a clear line from the camera) for LOST_S, every alerted one also gets a red
#     marker over his head through the racks ("pinged") until one is seen again; watch_node(node) marks one more threat
#     (the duel's boss: an arrow when he is off screen);
#   - hidden while the mission is not running or its HUD is hidden, during a CameraDirector cut, or when hide_fn says so
#     (the duel's QTE).
# Updated at UPDATE_HZ from the viewport camera (unproject_position, is_position_behind), one ray per on-screen gunman per
# update; the arrays are reused (no allocation per update); the overlay redraws only after an update.
# Test state (after refresh()): goal_mode ("" | "on" | "edge"), edge_threats, pinged, lost_t, shown.
class_name BasementGuide
extends CanvasLayer

const UPDATE_HZ: float = 15.0
const LOST_S: float = 5.0
const EDGE_INSET: float = 64.0
const ON_MARGIN: float = 40.0
const HEAD_Y: float = 1.85
const FONT_SIZE: int = 15

var mission: StoryMission = null
var fight: GunFight = null
var near_m: float = 0.0
var extra: Node3D = null
var hide_fn: Callable = Callable()
var goal_pos: Vector3 = Vector3.ZERO
var goal_text: String = ""
var has_goal: bool = false
var goal_mode: String = ""
var goal_at: Vector2 = Vector2.ZERO
var goal_dir: Vector2 = Vector2.ZERO
var goal_label: String = ""
var edge_threats: int = 0
var pinged: int = 0
var lost_t: float = 0.0
var shown: bool = false
var edge_pos: PackedVector2Array = PackedVector2Array()
var edge_dir: PackedVector2Array = PackedVector2Array()
var edge_dim: PackedByteArray = PackedByteArray()
var ping_pos: PackedVector2Array = PackedVector2Array()
var view: Control
var _acc: float = 0.0
var _rq := PhysicsRayQueryParameters3D.new()
var _shown_m: int = -1


func _init() -> void:
	layer = 4
	name = "BasementGuide"


func _ready() -> void:
	view = Control.new()
	view.name = "View"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)


func setup(m: StoryMission) -> void:
	mission = m


func set_goal(p: Vector3, text: String) -> void:
	goal_pos = p
	goal_text = text
	has_goal = true
	_shown_m = -1


func clear_goal() -> void:
	has_goal = false
	goal_mode = ""


## The gunmen of `f` become tracked threats (null = none); near_m > 0 adds unalerted guards that close.
func watch(f: GunFight, near: float = 0.0) -> void:
	fight = f
	near_m = near
	lost_t = 0.0


func watch_node(n: Node3D) -> void:
	extra = n


func _process(delta: float) -> void:
	_acc += delta
	if shown:
		lost_t += delta
	if _acc >= 1.0 / UPDATE_HZ:
		_acc = 0.0
		refresh()


## One update: what shows and where (tests call it directly).
func refresh() -> void:
	edge_pos.clear()
	edge_dir.clear()
	edge_dim.clear()
	ping_pos.clear()
	edge_threats = 0
	pinged = 0
	goal_mode = ""
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	shown = cam != null and _active()
	view.visible = shown
	if not shown:
		lost_t = 0.0
		view.queue_redraw()
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if has_goal:
		var lift: Vector3 = goal_pos + Vector3(0.0, 1.2, 0.0)
		var m: int = roundi(StoryMission.flat(goal_pos, cam.global_position))
		if m != _shown_m:
			_shown_m = m
			goal_label = "%s  %d m" % [goal_text, m]
		if _on_screen(cam, vs, lift, ON_MARGIN):
			goal_mode = "on"
			goal_at = cam.unproject_position(lift)
		else:
			goal_mode = "edge"
			goal_dir = _dir_to(cam, vs, lift)
			goal_at = _edge_at(vs, goal_dir)
	var seen_any: bool = false
	var tracked: int = 0
	if fight != null and is_instance_valid(fight):
		var pp: Vector3 = fight.player_feet()
		for e: Variant in fight.enemies:
			if not (e is Gunman) or not is_instance_valid(e) or (e as Gunman).is_defeated():
				continue
			var g: Gunman = e
			var alert: bool = g.is_alerted
			if not alert and (near_m <= 0.0 or StoryMission.flat(g.global_position, pp) > near_m):
				continue
			var head: Vector3 = g.feet() + Vector3(0.0, HEAD_Y, 0.0)
			if _on_screen(cam, vs, head, 0.0):
				if alert:
					tracked += 1
					if _clear(cam.global_position, head):
						seen_any = true
					elif lost_t >= LOST_S:
						ping_pos.append(cam.unproject_position(head))
			else:
				if alert:
					tracked += 1
				var d: Vector2 = _dir_to(cam, vs, head)
				edge_pos.append(_edge_at(vs, d))
				edge_dir.append(d)
				edge_dim.append(0 if alert else 1)
	if extra != null and is_instance_valid(extra) and extra.is_inside_tree():
		var hp: Vector3 = extra.global_position + Vector3(0.0, HEAD_Y, 0.0)
		if not _on_screen(cam, vs, hp, 0.0):
			var d2: Vector2 = _dir_to(cam, vs, hp)
			edge_pos.append(_edge_at(vs, d2))
			edge_dir.append(d2)
			edge_dim.append(0)
	if seen_any or tracked == 0:
		lost_t = 0.0
	edge_threats = edge_pos.size()
	pinged = ping_pos.size()
	view.queue_redraw()


func _active() -> bool:
	if mission == null or not is_instance_valid(mission) or mission.state != "running" or not mission.hud_visible():
		return false
	if hide_fn.is_valid() and bool(hide_fn.call()):
		return false
	var cd: CameraDirector = CameraDirector.live()
	return cd == null or not cd.cutting()


func _on_screen(cam: Camera3D, vs: Vector2, p: Vector3, margin: float) -> bool:
	if cam.is_position_behind(p):
		return false
	return Rect2(Vector2.ZERO, vs).grow(-margin).has_point(cam.unproject_position(p))


## The screen direction (from the centre) toward p, also for a point behind the camera.
func _dir_to(cam: Camera3D, vs: Vector2, p: Vector3) -> Vector2:
	var d: Vector2
	if cam.is_position_behind(p):
		var lp: Vector3 = cam.global_transform.affine_inverse() * p
		d = Vector2(lp.x, -lp.y)
		if absf(d.x) < 0.2:
			d.x = 0.2 if d.x >= 0.0 else -0.2   # straight behind: lean to a side so the arrow reads "turn around"
		d.y = maxf(d.y, 0.3)                    # behind = toward the bottom of the screen
	else:
		d = cam.unproject_position(p) - vs * 0.5
	return d.normalized() if d.length_squared() > 1e-6 else Vector2(0.0, 1.0)


func _edge_at(vs: Vector2, d: Vector2) -> Vector2:
	var c: Vector2 = vs * 0.5
	var half: Vector2 = c - Vector2(EDGE_INSET, EDGE_INSET)
	var t: float = minf(half.x / maxf(absf(d.x), 1e-4), half.y / maxf(absf(d.y), 1e-4))
	return c + d * t


func _clear(a: Vector3, b: Vector3) -> bool:
	var w: World3D = get_viewport().world_3d if get_viewport() else null
	if w == null:
		return true
	_rq.from = a
	_rq.to = b
	_rq.collision_mask = 1
	return w.direct_space_state.intersect_ray(_rq).is_empty()


# ----- drawing -----
func _draw_view() -> void:
	if not shown:
		return
	var font: Font = ThemeDB.fallback_font
	var zone: Color = Readability.ZONE
	var danger: Color = Readability.DANGER
	var ink := Color(0.02, 0.03, 0.06, 0.85)
	for i: int in edge_pos.size():
		var col: Color = danger if edge_dim[i] == 0 else Color(danger.r, danger.g, danger.b, 0.5)
		_chevron(edge_pos[i], edge_dir[i], 15.0, col, ink)
	for p: Vector2 in ping_pos:
		var pts := PackedVector2Array([p + Vector2(0.0, -11.0), p + Vector2(9.0, 0.0), p + Vector2(0.0, 11.0), p + Vector2(-9.0, 0.0)])
		view.draw_colored_polygon(pts, danger)
		view.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ink, 2.0)
		view.draw_string(font, p + Vector2(-3.0, 5.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, ink)
	if goal_mode == "on":
		var g: Vector2 = goal_at
		var dm := PackedVector2Array([g + Vector2(0.0, -12.0), g + Vector2(10.0, 0.0), g + Vector2(0.0, 12.0), g + Vector2(-10.0, 0.0)])
		view.draw_colored_polygon(dm, zone)
		view.draw_polyline(PackedVector2Array([dm[0], dm[1], dm[2], dm[3], dm[0]]), ink, 2.0)
		view.draw_string_outline(font, g + Vector2(-160.0, -20.0), goal_label, HORIZONTAL_ALIGNMENT_CENTER, 320.0, FONT_SIZE, 5, ink)
		view.draw_string(font, g + Vector2(-160.0, -20.0), goal_label, HORIZONTAL_ALIGNMENT_CENTER, 320.0, FONT_SIZE, zone)
	elif goal_mode == "edge":
		_chevron(goal_at, goal_dir, 20.0, zone, ink)
		var tp: Vector2 = goal_at - goal_dir * 44.0 + Vector2(-160.0, 5.0)
		view.draw_string_outline(font, tp, goal_label, HORIZONTAL_ALIGNMENT_CENTER, 320.0, FONT_SIZE, 5, ink)
		view.draw_string(font, tp, goal_label, HORIZONTAL_ALIGNMENT_CENTER, 320.0, FONT_SIZE, zone)


## A filled arrow head at p pointing along d (outward), outlined.
func _chevron(p: Vector2, d: Vector2, s: float, col: Color, ink: Color) -> void:
	var n := Vector2(-d.y, d.x)
	var tri := PackedVector2Array([p + d * s, p - d * s * 0.6 + n * s * 0.8, p - d * s * 0.6 - n * s * 0.8])
	view.draw_colored_polygon(tri, col)
	view.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), ink, 2.0)
