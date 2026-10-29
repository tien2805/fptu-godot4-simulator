# File: res://scripts/story/OffscreenMarkers.gd
# T10 readability helper (plan 2026-10-30-w3-day3.md; the owner's note on another level: enemies off screen "chạy mất
# tiêu", the direction unclear). A Control on a mission HUD that keeps what matters findable, with plain shapes and plain
# text (no emoji), in Readability's colours (threat = red DANGER, goal = cyan ZONE, prompt = yellow PROMPT):
#   - a tracked node behind the camera or off screen: an arrow on the screen border pointing at it, its label and the
#     distance from the player ("Cần cẩu 14 m");
#   - a goal / prompt node on screen: a small diamond above it with the label and the distance;
#   - threats on screen: a red chevron over the head, only while at most `chevrons_at` threats are left (the last ones are
#     the ones that get lost behind the containers);
#   - threat_source: an optional Callable returning the current enemy nodes (GunFight.alive), polled at 10 Hz; a node is a
#     threat when it has `is_alerted` set (a sneak's unalerted patrol and a hide's sweepers are not marked); a boss is
#     tracked explicitly with track(node, "threat", label).
# Usage (a mission): markers = OffscreenMarkers.make(hud, player); markers.track(node, "goal", "Container", 1.2);
# untrack(node); set_on(node, false) hides one for a while; clear(). It lives under the mission HUD (hidden with it) and
# draws nothing while a CameraDirector cut holds the screen.
# Per frame: one unproject per entry (at most MAX), no allocation; a label string is rebuilt only when its metres change.
# Test state: edge_count, onscreen_count, chevron_count (updated in _process), shown_labels().
class_name OffscreenMarkers
extends Control

const MAX: int = 16
const EDGE_INSET: float = 54.0
const POLL_S: float = 0.1
const KIND_COL: Dictionary = {"threat": Readability.DANGER, "goal": Readability.ZONE, "prompt": Readability.PROMPT}

var ref: Node3D = null                 # distances are measured from it (the player)
var threat_source: Callable = Callable()
var threat_label: String = ""
var chevrons_at: int = 2
var edge_count: int = 0
var onscreen_count: int = 0
var chevron_count: int = 0
var _items: Array[Dictionary] = []     # {"node", "kind", "label", "y", "on", "m", "text"}
var _threats: Array[Dictionary] = []   # same shape, refreshed from threat_source
var _poll_t: float = 0.0
# the draw list (filled in _process, read in _draw)
var _n: int = 0
var _pos := PackedVector2Array()
var _dir := PackedVector2Array()
var _col := PackedColorArray()
var _mode := PackedInt32Array()        # 0 edge arrow, 1 diamond, 2 chevron
var _txt: Array[String] = []
var _q := PackedVector2Array()
var _drawn: bool = false


## A marker layer under `hud` (the mission's CanvasLayer), distances from `player`.
static func make(hud: Node, player: Node3D = null) -> OffscreenMarkers:
	var m := OffscreenMarkers.new()
	m.name = "OffscreenMarkers"
	m.ref = player
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hud:
		hud.add_child(m)
	return m


func _init() -> void:
	_pos.resize(MAX)
	_dir.resize(MAX)
	_col.resize(MAX)
	_mode.resize(MAX)
	_txt.resize(MAX)
	_q.resize(4)


## Track `node` (kind "threat" | "goal" | "prompt"), the marker `y_off` m above its origin. Re-tracking updates it.
func track(node: Node3D, kind: String = "prompt", label: String = "", y_off: float = 1.9) -> void:
	if node == null:
		return
	for i: int in range(_items.size() - 1, -1, -1):
		if not is_instance_valid(_items[i]["node"]):
			_items.remove_at(i)      # a freed node (a boss respawned on a retry)
	for it: Dictionary in _items:
		if it["node"] == node:
			it["kind"] = kind
			it["label"] = label
			it["y"] = y_off
			it["on"] = true
			it["m"] = -1
			return
	if _items.size() >= MAX:
		return
	_items.append({"node": node, "kind": kind, "label": label, "y": y_off, "on": true, "m": -1, "text": ""})


func untrack(node: Node3D) -> void:
	for i: int in range(_items.size() - 1, -1, -1):
		if _items[i]["node"] == node:
			_items.remove_at(i)


func set_on(node: Node3D, on: bool) -> void:
	for it: Dictionary in _items:
		if it["node"] == node:
			it["on"] = on


func is_on(node: Node3D) -> bool:
	for it: Dictionary in _items:
		if it["node"] == node:
			return bool(it["on"])
	return false


func is_tracked(node: Node3D) -> bool:
	for it: Dictionary in _items:
		if it["node"] == node:
			return true
	return false


func clear() -> void:
	_items.clear()
	_threats.clear()


## The texts drawn this frame (tests).
func shown_labels() -> Array[String]:
	var out: Array[String] = []
	for i: int in _n:
		out.append(_txt[i])
	return out


func _process(delta: float) -> void:
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = POLL_S
		_poll_threats()
	_n = 0
	edge_count = 0
	onscreen_count = 0
	chevron_count = 0
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	var dir: CameraDirector = CameraDirector.live()
	if cam == null or not is_visible_in_tree() or (dir != null and dir.cutting()):
		_redraw()                # review fix: nothing over a director cut (a preview, the last-KO orbit)
		return
	var vs: Vector2 = vp.get_visible_rect().size
	for it: Dictionary in _items:
		_place(it, cam, vs, true)
	var live: int = 0
	for t: Dictionary in _threats:
		if is_instance_valid(t["node"]):
			live += 1
	for t2: Dictionary in _threats:
		_place(t2, cam, vs, live <= chevrons_at)
	_redraw()


## Redraw while something is shown (and once more to clear it).
func _redraw() -> void:
	if _n > 0 or _drawn:
		_drawn = _n > 0
		queue_redraw()


## Threats from threat_source (alerted, not defeated), reusing the entries of the ones still there.
func _poll_threats() -> void:
	if not threat_source.is_valid():
		if not _threats.is_empty():
			_threats.clear()
		return
	var src: Variant = threat_source.call()
	if not (src is Array):
		return
	var keep: Array[Dictionary] = []
	for n: Variant in src:
		if not (n is Node3D) or not is_instance_valid(n) or not ("is_alerted" in n) or not bool(n.get("is_alerted")):
			continue
		var found: Dictionary = {}
		for t: Dictionary in _threats:
			if t["node"] == n:
				found = t
				break
		if found.is_empty():
			found = {"node": n, "kind": "threat", "label": threat_label, "y": 2.1, "on": true, "m": -1, "text": ""}
		keep.append(found)
		if keep.size() + _items.size() >= MAX:
			break
	_threats = keep


func _place(it: Dictionary, cam: Camera3D, vs: Vector2, onscreen_mark: bool) -> void:
	if _n >= MAX or not bool(it["on"]):
		return
	var node: Variant = it["node"]
	if not is_instance_valid(node) or not (node as Node3D).is_inside_tree() or not (node as Node3D).is_visible_in_tree():
		return
	var n3: Node3D = node
	var p: Vector3 = n3.global_position + Vector3(0.0, float(it["y"]), 0.0)
	var kind: String = it["kind"]
	var c: Vector2 = vs * 0.5
	var behind: bool = cam.is_position_behind(p)
	var sp: Vector2 = Vector2.ZERO if behind else cam.unproject_position(p)
	var inside: bool = not behind and Rect2(Vector2.ZERO, vs).grow(-24.0).has_point(sp)
	if inside:
		if kind == "threat" and not onscreen_mark:
			return
		_pos[_n] = sp
		_mode[_n] = 2 if kind == "threat" else 1
		onscreen_count += 1
		if kind == "threat":
			chevron_count += 1
	else:
		var d: Vector2
		if behind:
			var lp: Vector3 = cam.global_transform.affine_inverse() * p
			d = Vector2(lp.x, -lp.y)
			if d.length_squared() < 1e-4:
				d = Vector2(0.0, 1.0)
			d = Vector2(d.x, absf(d.y) + 0.35)   # behind: toward the bottom edge, to the side it is on
		else:
			d = sp - c
		d = d.normalized()
		var half: Vector2 = c - Vector2(EDGE_INSET, EDGE_INSET)
		var t: float = minf(half.x / maxf(absf(d.x), 1e-4), half.y / maxf(absf(d.y), 1e-4))
		_pos[_n] = c + d * t
		_dir[_n] = d
		_mode[_n] = 0
		edge_count += 1
	_col[_n] = KIND_COL.get(kind, Readability.PROMPT)
	var metres: int = int(round(WeaponMath.flat(ref.global_position, n3.global_position))) if ref and is_instance_valid(ref) else -1
	if metres != int(it["m"]):
		it["m"] = metres
		var lab: String = String(it["label"])
		it["text"] = (lab + " " if lab != "" else "") + ("%d m" % metres if metres >= 0 else "")
	_txt[_n] = String(it["text"]) if _mode[_n] != 2 else ""
	_n += 1


func _draw() -> void:
	var f: Font = CombatHUD.font()
	var shade := Color(0.0, 0.0, 0.0, 0.55)
	for i: int in _n:
		var p: Vector2 = _pos[i]
		var col: Color = _col[i]
		match _mode[i]:
			0:
				var d: Vector2 = _dir[i]
				var side := Vector2(-d.y, d.x)
				_quad(p + d * 16.0, p - d * 10.0 + side * 12.0, p - d * 4.0, p - d * 10.0 - side * 12.0, shade)
				_quad(p + d * 14.0, p - d * 8.0 + side * 9.0, p - d * 3.0, p - d * 8.0 - side * 9.0, col)
				_label(f, p - d * 30.0 + Vector2(-80.0, 6.0), _txt[i], col)
			1:
				_quad(p + Vector2(0.0, -10.0), p + Vector2(10.0, 0.0), p + Vector2(0.0, 10.0), p + Vector2(-10.0, 0.0), shade)
				_quad(p + Vector2(0.0, -8.0), p + Vector2(8.0, 0.0), p + Vector2(0.0, 8.0), p + Vector2(-8.0, 0.0), col)
				_label(f, p + Vector2(-80.0, -16.0), _txt[i], col)
			2:
				_quad(p + Vector2(-11.0, -14.0), p + Vector2(11.0, -14.0), p + Vector2(0.5, 0.0), p + Vector2(-0.5, 0.0), shade)
				_quad(p + Vector2(-8.0, -12.0), p + Vector2(8.0, -12.0), p + Vector2(0.4, -2.0), p + Vector2(-0.4, -2.0), col)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_q[0] = a
	_q[1] = b
	_q[2] = c
	_q[3] = d
	draw_colored_polygon(_q, col)


func _label(f: Font, at: Vector2, t: String, col: Color) -> void:
	if t == "":
		return
	draw_string_outline(f, at, t, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 15, 4, CombatHUD.INK)
	draw_string(f, at, t, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 15, col)
