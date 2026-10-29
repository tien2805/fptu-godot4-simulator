# File: res://scripts/combat/bike/RouteGuide.gd
# Navigation and enemy awareness for the Day 2 bike chase and race (plan 2026-10-30-d2-playtest-fixes.md; owner playtest:
# "phải có chỉ đường dễ nhìn hơn hoặc đường trên map chứ", "tôi còn chả tìm thấy chúng để đá nữa"). Owned by BikeChase and
# DriftDuel; works on any path object with `length`, point(s), tangent(s), world(s, d) (BikeRoute, DriftCourse).
#   - On the road: a glowing GPS line of CHEV_N pooled chevrons (one MultiMesh, an unshaded additive shader with a pulse
#     running forward) every CHEV_STEP m along the path from CHEV_NEAR to CHEV_FAR ahead of the player, fading in near the
#     bike (so it fades out behind) and out at the far end. Chevrons sit at fixed path distances (no sliding); each slot's
#     floor height comes from one cached ray (at most RAYS_PER_FRAME a frame), a slot without one stays hidden.
#   - The next turn: find_turns() lists the real turns of the path once (heading change over +/-TURN_SPAN m above
#     TURN_RUN_DEG, at least TURN_MIN_DEG in all; same-way turns closer than TURN_MERGE_M merge). From TURN_SHOW_M before a
#     turn the HUD panel (beside the top panel) shows a drawn bent arrow, "RẼ TRÁI" / "RẼ PHẢI" (or "CUA GẮT ..." past
#     TURN_SHARP_DEG) and the distance to it ("80 m"); a second turn within TURN_THEN_M after it shows as "RỒI RẼ ...".
#   - Enemies: every active target (the owner's live `targets` array, BikerEnemy.is_active()) and the `boss` (Sói Xám) off
#     screen or behind the camera gets a red edge arrow on the screen border pointing at it, bigger when nearer, pulsing
#     while it closes in; the boss on screen gets a marker over his head (his name and distance), off screen his edge
#     arrow carries both.
#   - Radar (FreeRoam's ViceHUD, vice style): the path as ViceRadar.guide_route while active, a red dot per enemy
#     (extra_blips, a pooled array refreshed at BLIP_HZ).
#   - Metrics (tests, the tuning sims): combat_t / onscreen_t (seconds with at least one active target / with at least one
#     of them on screen, while metrics_on), max_off_s (the longest stretch with none on screen), boss_hidden_t /
#     boss_hidden_max, the turn passes (turn_passes, turn_announced: shown at least TURN_ANNOUNCE_M before the turn).
# The owner calls setup(), set_active(on) (chevrons, HUD, radar), set_hud_visible(on) (e.g. under a cinematic card) and
# sets metrics_on. No allocation per frame: the HUD texts are rebuilt only when their number changes.
class_name RouteGuide
extends Node3D

const CHEV_STEP: float = 6.0
const CHEV_NEAR: float = 4.0
const CHEV_FULL: float = 13.0             # fully lit from here ...
const CHEV_FADE: float = 85.0             # ... to here, then fading out ...
const CHEV_FAR: float = 118.0             # ... to here
const CHEV_N: int = 20
const CHEV_W: float = 1.7
const CHEV_L: float = 1.1
const CHEV_T: float = 0.36                # arm thickness (along the road)
const CHEV_Y: float = 0.07                # above the asphalt
const CHEV_ALPHA: float = 0.85
const CHEV_COL := Color(0.15, 0.9, 1.0)
const CHEV_ENERGY: float = 2.2
const RAYS_PER_FRAME: int = 2
const TURN_SPAN: float = 15.0
const TURN_STEP: float = 2.0
const TURN_RUN_DEG: float = 25.0
const TURN_MIN_DEG: float = 35.0
const TURN_MERGE_M: float = 25.0
const TURN_SHARP_DEG: float = 110.0
const TURN_SHOW_M: float = 170.0
const TURN_THEN_M: float = 70.0
const TURN_ANNOUNCE_M: float = 40.0
const EDGE_INSET: float = 44.0
const EDGE_NEAR_M: float = 4.0
const EDGE_FAR_M: float = 40.0
const EDGE_BIG: float = 30.0
const EDGE_SMALL: float = 15.0
const VIEW_M: float = 160.0
const MAX_EDGES: int = 12
const BLIP_HZ: float = 10.0
const MAX_BLIPS: int = 10
const PANEL_SIZE := Vector2(236.0, 108.0)
const PANEL_GAP: float = 14.0
const RED := Color(1.0, 0.14, 0.1)
const T_LEFT: String = "RẼ TRÁI"
const T_RIGHT: String = "RẼ PHẢI"
const T_SHARP_LEFT: String = "CUA GẮT TRÁI"
const T_SHARP_RIGHT: String = "CUA GẮT PHẢI"
const T_THEN: String = "RỒI %s"
const T_DIST: String = "%d m"
const T_BOSS: String = "SÓI XÁM"
const T_BOSS_DIST: String = "%s  %d m"

var path: Object = null
var bike: PlayerBike
var roam: Node = null
var s_fn: Callable
var floor_fn: Callable
var end_s: float = 0.0
var targets: Array = []
var boss: Node3D = null
var panel_half_w: float = 220.0
var active: bool = false
var hud_on: bool = true
var metrics_on: bool = false
## Turns: [s_apex, dir (+1 right, -1 left), deg, s_in]; per turn the farthest distance the panel showed it from.
var turns: Array = []
var turn_shown := PackedFloat32Array()
var turn_i: int = 0
var turn_passes: int = 0
var turn_announced: int = 0
var turn_missed: Array[float] = []        # apex s of the turns passed without the arrow in time (tests, sims)
## The turn panel (tests): shown, its texts, the direction (-1 / +1) and sharpness.
var turn_visible: bool = false
var turn_text: String = ""
var turn_dist_text: String = ""
var then_text: String = ""
var turn_dir: int = 0
var turn_sharp: bool = false
var _turn_dist_n: int = -1
var _turn_key: int = -1
var _then_key: int = -1
## Edge arrows of this frame (screen position, direction, size, 1 = closing / boss).
var edge_pos := PackedVector2Array()
var edge_dir := PackedVector2Array()
var edge_size := PackedFloat32Array()
var edge_kind := PackedInt32Array()
var edge_count: int = 0
var arrows_drawn: int = 0                 # edge arrows drawn so far (frames x arrows)
var boss_on_screen: bool = false
var boss_screen: Vector2 = Vector2.ZERO
var boss_edge: int = -1                   # index into edge_* of the boss arrow, -1 none
var boss_dist_text: String = ""
var _boss_dist_n: int = -1
## Metrics.
var combat_t: float = 0.0
var onscreen_t: float = 0.0
var off_run: float = 0.0
var max_off_s: float = 0.0
var boss_hidden_t: float = 0.0
var boss_hidden_max: float = 0.0
var on_screen_n: int = 0
var active_n: int = 0
# chevrons
var mm: MultiMesh
var mmi: MultiMeshInstance3D
var _mat: ShaderMaterial
var _hy := PackedFloat32Array()           # floor height per chevron slot (NAN = not cast yet)
var _try := PackedByteArray()             # ray attempts per slot
var lit: int = 0                          # chevrons shown this frame (tests)
var lit_near: float = INF                 # nearest / farthest lit chevron distance ahead (tests)
var lit_far: float = -INF
var _s: float = 0.0
var _prev_s: float = -1.0
# HUD
var hud: CanvasLayer
var _draw: Control
var _blips: Array[Dictionary] = []
var _blip_t: float = 0.0
var _radar: Object = null

const SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 col : source_color = vec4(0.15, 0.9, 1.0, 1.0);
uniform float energy = 2.2;
void fragment() {
	float pulse = 0.72 + 0.28 * sin(TIME * 7.0 - COLOR.r * 18.85);
	ALBEDO = col.rgb * energy * pulse * COLOR.a;
	ALPHA = COLOR.a;
}
"""


func setup(opts: Dictionary) -> void:
	path = opts.get("path", null)
	bike = opts.get("bike", null)
	roam = opts.get("roam", null)
	s_fn = opts.get("s_fn", Callable())
	floor_fn = opts.get("floor_fn", Callable())
	targets = opts.get("targets", [])
	boss = opts.get("boss", null)
	panel_half_w = float(opts.get("panel_half_w", 220.0))
	var plen: float = float(path.get("length")) if path else 0.0
	end_s = minf(float(opts.get("end_s", plen)), plen) if float(opts.get("end_s", -1.0)) >= 0.0 else plen
	turns = find_turns(path, end_s) if path else []
	turn_shown.resize(turns.size())
	turn_shown.fill(-1.0)
	var n_slots: int = int(end_s / CHEV_STEP) + 2
	_hy.resize(n_slots)
	_hy.fill(NAN)
	_try.resize(n_slots)
	_try.fill(0)
	_build_chevrons()
	_build_hud()
	for i: int in MAX_BLIPS:
		_blips.append({"pos": Vector2.ZERO, "color": RED, "r": 6.0, "on": false})
	set_active(false)


func _ready() -> void:
	process_physics_priority = 3             # after the bike (0, its camera too) and the owner (1)


## Chevrons, HUD and radar on / off.
func set_active(on: bool) -> void:
	active = on
	if mmi:
		mmi.visible = on
	if hud:
		hud.visible = on and hud_on
	_radar_route(on)
	if not on:
		turn_visible = false
		edge_count = 0
		boss_on_screen = false


## The HUD part (turn panel, edge arrows, the boss marker) on / off while active.
func set_hud_visible(on: bool) -> void:
	hud_on = on
	if hud:
		hud.visible = active and on


# ---------------------------------------------------------------------------
# TURNS
# ---------------------------------------------------------------------------
## The real turns of a path up to `length`: [s_apex, dir (+1 right, -1 left), total degrees, s_in (where it starts)].
static func find_turns(p: Object, length: float) -> Array:
	var out: Array = []
	if p == null or length <= 2.0 * TURN_SPAN:
		return out
	var in_run: bool = false
	var sgn: float = 0.0
	var s0: float = 0.0
	var s1: float = 0.0
	var best: float = 0.0
	var apex: float = 0.0
	var s: float = 0.0
	while s <= length:
		var h: float = heading_change(p, s - TURN_SPAN, s + TURN_SPAN, length)
		var a: float = absf(h)
		var hs: float = signf(h)
		if a >= TURN_RUN_DEG and in_run and hs == sgn:
			s1 = s
			if a > best:
				best = a
				apex = s
		else:
			if in_run:
				_close_turn(out, p, length, sgn, s0, s1, apex)
				in_run = false
			if a >= TURN_RUN_DEG:
				in_run = true
				sgn = hs
				s0 = s
				s1 = s
				best = a
				apex = s
		s += TURN_STEP
	if in_run:
		_close_turn(out, p, length, sgn, s0, s1, apex)
	# same-way turns close together are one (a hairpin drawn as two bends)
	var i: int = 1
	while i < out.size():
		var a0: Array = out[i - 1]
		var a1: Array = out[i]
		if float(a0[1]) == float(a1[1]) and float(a1[0]) - float(a0[0]) < TURN_MERGE_M:
			var tot: float = heading_change(p, float(a0[3]), float(a1[0]) + TURN_SPAN, length) * float(a0[1])
			a0[2] = tot
			a0[0] = (float(a0[0]) + float(a1[0])) * 0.5
			out.remove_at(i)
			if tot < TURN_MIN_DEG:
				out.remove_at(i - 1)             # two bends of a wiggle, not a turn
				i = maxi(1, i - 1)
		else:
			i += 1
	return out


## A run of one-way heading change is a turn when it adds up to TURN_MIN_DEG that way (an S-bend's halves each count).
static func _close_turn(out: Array, p: Object, length: float, sgn: float, s0: float, s1: float, apex: float) -> void:
	var total: float = heading_change(p, s0 - TURN_SPAN, s1 + TURN_SPAN, length) * sgn
	if total >= TURN_MIN_DEG:
		out.append([apex, sgn, total, maxf(0.0, s0 - TURN_SPAN * 0.5)])


## Signed heading change (degrees, + = right turn; x east, z south) from s_a to s_b, summed in TURN_STEP steps (no wrap at
## 180 degrees).
static func heading_change(p: Object, s_a: float, s_b: float, length: float) -> float:
	var a: float = clampf(s_a, 0.0, length)
	var b: float = clampf(s_b, 0.0, length)
	var sum: float = 0.0
	var t0: Vector2 = p.call("tangent", a)
	var s: float = a + TURN_STEP
	while s <= b + 0.001:
		var t1: Vector2 = p.call("tangent", minf(s, b))
		sum += atan2(t0.x * t1.y - t0.y * t1.x, t0.dot(t1))
		t0 = t1
		s += TURN_STEP
	return rad_to_deg(sum)


## Turn label for a direction and size.
static func turn_label(dir: float, deg: float) -> String:
	if deg >= TURN_SHARP_DEG:
		return T_SHARP_RIGHT if dir > 0.0 else T_SHARP_LEFT
	return T_RIGHT if dir > 0.0 else T_LEFT


## Every UI text (tests: plain, no emoji or decorative symbols).
static func texts() -> Array[String]:
	return [T_LEFT, T_RIGHT, T_SHARP_LEFT, T_SHARP_RIGHT, T_THEN % T_LEFT, T_DIST % 80, T_BOSS, T_BOSS_DIST % [T_BOSS, 45]]


# ---------------------------------------------------------------------------
# PER FRAME
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if path == null or bike == null or not is_instance_valid(bike):
		return
	_s = float(s_fn.call()) if s_fn.is_valid() else -1.0
	if not active:
		_prev_s = _s
		return
	if _s >= 0.0:
		_tick_turns()
		_tick_chevrons()
	_tick_targets(delta)
	_blip_t -= delta
	if _blip_t <= 0.0:
		_blip_t = 1.0 / BLIP_HZ
		_radar_blips()
	if hud and hud.visible and _draw:
		_draw.queue_redraw()
	_prev_s = _s


func _tick_turns() -> void:
	if turns.is_empty():
		turn_visible = false
		return
	# a jump back (a retry at a checkpoint): find the next turn again
	if _prev_s >= 0.0 and _s < _prev_s - 30.0:
		turn_i = 0
	while turn_i < turns.size() and float(turns[turn_i][0]) < _s - 0.5:
		var passed: bool = _prev_s >= 0.0 and _prev_s <= float(turns[turn_i][0]) + 0.5 and _s - _prev_s < 30.0
		if passed:
			_count_pass(turn_i)
		turn_i += 1
	if turn_i >= turns.size():
		turn_visible = false
		return
	var t: Array = turns[turn_i]
	var to_apex: float = float(t[0]) - _s
	turn_visible = to_apex <= TURN_SHOW_M
	if not turn_visible:
		return
	turn_shown[turn_i] = maxf(turn_shown[turn_i], to_apex)
	if turn_i != _turn_key:
		_turn_key = turn_i
		turn_dir = int(t[1])
		turn_sharp = float(t[2]) >= TURN_SHARP_DEG
		turn_text = turn_label(float(t[1]), float(t[2]))
	var dn: int = int(roundf(maxf(0.0, float(t[3]) - _s) / 10.0)) * 10
	if dn != _turn_dist_n:
		_turn_dist_n = dn
		turn_dist_text = T_DIST % dn if dn >= 10 else ""
	var nk: int = -1
	if turn_i + 1 < turns.size() and float(turns[turn_i + 1][0]) - float(t[0]) <= TURN_THEN_M:
		nk = turn_i + 1
		turn_shown[nk] = maxf(turn_shown[nk], float(turns[nk][0]) - _s)
	if nk != _then_key:
		_then_key = nk
		then_text = T_THEN % turn_label(float(turns[nk][1]), float(turns[nk][2])) if nk >= 0 else ""


func _count_pass(i: int) -> void:
	var apex: float = float(turns[i][0])
	turn_passes += 1
	if turn_shown[i] >= TURN_ANNOUNCE_M:
		turn_announced += 1
	else:
		turn_missed.append(apex)
	turn_shown[i] = -1.0


func _tick_chevrons() -> void:
	var fy: float = bike.global_position.y + 0.13
	var k0: int = int(ceil((_s + CHEV_NEAR) / CHEV_STEP))
	var rays: int = 0
	lit = 0
	lit_near = INF
	lit_far = -INF
	for i: int in CHEV_N:
		var k: int = k0 + i
		var cs: float = float(k) * CHEV_STEP
		var dist: float = cs - _s
		var a: float = 0.0
		if k >= 0 and k < _hy.size() and cs <= end_s and dist <= CHEV_FAR:
			if is_nan(_hy[k]) and rays < RAYS_PER_FRAME and floor_fn.is_valid():
				rays += 1
				_cast(k, cs, fy)
			if not is_nan(_hy[k]):
				a = CHEV_ALPHA * smoothstep(CHEV_NEAR, CHEV_FULL, dist) * (1.0 - smoothstep(CHEV_FADE, CHEV_FAR, dist))
		if a <= 0.01:
			mm.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
			continue
		var p: Vector2 = path.call("point", cs)
		var tg: Vector2 = path.call("tangent", cs)
		var pitch: float = 0.0
		if k > 0 and k + 1 < _hy.size() and not is_nan(_hy[k - 1]) and not is_nan(_hy[k + 1]):
			pitch = atan2(_hy[k + 1] - _hy[k - 1], 2.0 * CHEV_STEP)
		var b := Basis(Vector3.UP, atan2(-tg.x, -tg.y)) * Basis(Vector3.RIGHT, pitch)
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, _hy[k] + CHEV_Y, p.y)))
		mm.set_instance_color(i, Color(fmod(cs / 30.0, 1.0), 0.0, 0.0, a))
		lit += 1
		lit_near = minf(lit_near, dist)
		lit_far = maxf(lit_far, dist)


## One floor ray for chevron slot k: first from above the bike's level, then (missed) from below it (a slope down).
func _cast(k: int, cs: float, fy: float) -> void:
	var p: Vector2 = path.call("point", cs)
	var tries: int = _try[k]
	if tries >= 6:
		return
	_try[k] = tries + 1
	var off: float = 4.0 if tries % 2 == 0 else -3.0
	var y: Variant = floor_fn.call(Vector3(p.x, fy + off, p.y))
	if y is float:
		_hy[k] = float(y)


## The targets on screen or not, the edge arrows, the boss marker, the metrics.
func _tick_targets(delta: float) -> void:
	edge_pos.clear()
	edge_dir.clear()
	edge_size.clear()
	edge_kind.clear()
	boss_edge = -1
	boss_on_screen = false
	on_screen_n = 0
	active_n = 0
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null:
		edge_count = 0
		return
	var vs: Vector2 = vp.get_visible_rect().size
	var screen := Rect2(Vector2.ZERO, vs).grow(-12.0)
	var bp: Vector3 = bike.global_position
	for v: Variant in targets:
		if not is_instance_valid(v):
			continue
		var e: Node3D = v as Node3D
		if e == null or not e.is_inside_tree() or not e.visible or e == boss:
			continue
		if e.has_method("is_active") and not bool(e.call("is_active")):
			continue
		active_n += 1
		var closing: bool = e.get("st") != null and int(e.get("st")) == BikerEnemy.St.APPROACH
		if _place(cam, vs, screen, e.global_position + Vector3(0.0, 1.2, 0.0), bp, 1 if closing else 0):
			on_screen_n += 1
	if boss != null and is_instance_valid(boss) and boss.is_inside_tree() and boss.visible:
		var head: Vector3 = boss.global_position + Vector3(0.0, 1.3, 0.0)
		var on: bool = _place(cam, vs, screen, head, bp, 2)
		if on:
			boss_on_screen = true
			boss_screen = cam.unproject_position(head + Vector3(0.0, 1.1, 0.0))
		else:
			boss_edge = edge_pos.size() - 1
		var dn: int = int(roundf(Vector2(boss.global_position.x - bp.x, boss.global_position.z - bp.z).length()))
		if dn != _boss_dist_n:
			_boss_dist_n = dn
			boss_dist_text = T_BOSS_DIST % [T_BOSS, dn]
		if metrics_on:
			boss_hidden_t = 0.0 if on else boss_hidden_t + delta
			boss_hidden_max = maxf(boss_hidden_max, boss_hidden_t)
	edge_count = edge_pos.size()
	if hud and hud.visible:
		arrows_drawn += edge_count
	if metrics_on and active_n > 0:
		combat_t += delta
		if on_screen_n > 0:
			onscreen_t += delta
			off_run = 0.0
		else:
			off_run += delta
			max_off_s = maxf(max_off_s, off_run)
	elif metrics_on:
		off_run = 0.0


## On screen (true) or an edge arrow (false) for a point: behind the camera, outside the frame or beyond VIEW_M.
func _place(cam: Camera3D, vs: Vector2, screen: Rect2, pos: Vector3, bp: Vector3, kind: int) -> bool:
	var d: Vector2
	var c: Vector2 = vs * 0.5
	if cam.is_position_behind(pos):
		var lp: Vector3 = cam.global_transform.affine_inverse() * pos
		d = Vector2(lp.x, absf(lp.z) * 0.35 + maxf(0.0, -lp.y))   # behind: along the bottom edge, on its side
		if d.length_squared() < 1e-4:
			d = Vector2(0.0, 1.0)
	else:
		var sp: Vector2 = cam.unproject_position(pos)
		if screen.has_point(sp) and cam.global_position.distance_to(pos) < VIEW_M:
			return true
		d = sp - c
		if d.length_squared() < 1e-4:
			d = Vector2(0.0, -1.0)
	if edge_pos.size() >= MAX_EDGES:
		return false
	d = d.normalized()
	var half: Vector2 = c - Vector2(EDGE_INSET, EDGE_INSET)
	var t: float = minf(half.x / maxf(absf(d.x), 1e-4), half.y / maxf(absf(d.y), 1e-4))
	var dist: float = Vector2(pos.x - bp.x, pos.z - bp.z).length()
	edge_pos.append(c + d * t)
	edge_dir.append(d)
	edge_size.append(lerpf(EDGE_BIG, EDGE_SMALL, clampf((dist - EDGE_NEAR_M) / (EDGE_FAR_M - EDGE_NEAR_M), 0.0, 1.0)))
	edge_kind.append(kind)
	return false


# ---------------------------------------------------------------------------
# RADAR
# ---------------------------------------------------------------------------
func _find_radar() -> Object:
	if _radar != null and is_instance_valid(_radar):
		return _radar
	var vh: Variant = roam.get("vice_hud") if roam and is_instance_valid(roam) else null
	if vh is Node and is_instance_valid(vh):
		_radar = (vh as Node).get("radar")
	return _radar


func _radar_route(on: bool) -> void:
	var r: Object = _find_radar()
	if r == null:
		return
	if on and path:
		var pts := PackedVector2Array()
		var s: float = 0.0
		while s < end_s:
			pts.append(path.call("point", s))
			s += 10.0
		pts.append(path.call("point", end_s))
		r.set("guide_route", pts)
	else:
		r.set("guide_route", PackedVector2Array())
		for b: Dictionary in _blips:
			b["on"] = false
		r.set("extra_blips", _blips)


func _radar_blips() -> void:
	var r: Object = _find_radar()
	if r == null:
		return
	var k: int = 0
	for v: Variant in targets:
		if k >= MAX_BLIPS - 1:
			break
		if not is_instance_valid(v) or v == boss:
			continue
		var e: Node3D = v as Node3D
		if e == null or not e.is_inside_tree() or (e.has_method("is_active") and not bool(e.call("is_active"))):
			continue
		var b: Dictionary = _blips[k]
		b["pos"] = Vector2(e.global_position.x, e.global_position.z)
		b["r"] = 6.0
		b["on"] = true
		k += 1
	if boss != null and is_instance_valid(boss) and boss.is_inside_tree():
		var bb: Dictionary = _blips[k]
		bb["pos"] = Vector2(boss.global_position.x, boss.global_position.z)
		bb["r"] = 8.0
		bb["on"] = true
		k += 1
	for i: int in range(k, _blips.size()):
		_blips[i]["on"] = false
	r.set("extra_blips", _blips)


## Enemy dots shown on the radar now (tests).
func blips_on() -> int:
	var n: int = 0
	for b: Dictionary in _blips:
		if bool(b["on"]):
			n += 1
	return n


# ---------------------------------------------------------------------------
# BUILD
# ---------------------------------------------------------------------------
func _build_chevrons() -> void:
	var am := ArrayMesh.new()
	var hw: float = CHEV_W * 0.5
	var hl: float = CHEV_L * 0.5
	var a := Vector3(-hw, 0.0, hl - CHEV_T)
	var b := Vector3(0.0, 0.0, -hl)
	var c := Vector3(hw, 0.0, hl - CHEV_T)
	var a2 := Vector3(-hw, 0.0, hl)
	var b2 := Vector3(0.0, 0.0, -hl + CHEV_T)
	var c2 := Vector3(hw, 0.0, hl)
	var v := PackedVector3Array([a, b, b2, a, b2, a2, b, c, c2, b, c2, b2])
	var nrm := PackedVector3Array()
	for i: int in v.size():
		nrm.append(Vector3.UP)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("col", CHEV_COL)
	_mat.set_shader_parameter("energy", CHEV_ENERGY)
	_mat.set_meta("vice_done", true)
	am.surface_set_material(0, _mat)
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = am
	mm.instance_count = CHEV_N
	for i: int in CHEV_N:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
	mmi = MultiMeshInstance3D.new()
	mmi.name = "GuideChevrons"
	mmi.multimesh = mm
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000.0, -200.0, -5000.0), Vector3(10000.0, 400.0, 10000.0))
	add_child(mmi)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "GuideHUD"
	hud.layer = 4
	add_child(hud)
	_draw = Overlay.new()
	_draw.name = "GuideOverlay"
	_draw.set("guide", self)
	_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_draw)


func _exit_tree() -> void:
	_radar_route(false)


## The turn panel (beside the owner's top panel), the edge arrows and the boss marker, drawn in one Control.
class Overlay extends Control:
	var guide: RouteGuide

	func _draw() -> void:
		if guide == null:
			return
		var f: Font = CombatHUD.font()
		var pulse: float = 0.72 + 0.28 * sin(float(Time.get_ticks_msec()) / 1000.0 * 14.0)
		if guide.turn_visible:
			_turn_panel(f)
		for i: int in guide.edge_pos.size():
			_edge(i, pulse, f)
		if guide.boss_on_screen:
			var p: Vector2 = guide.boss_screen
			var tri := PackedVector2Array([p + Vector2(-13.0, -18.0), p + Vector2(13.0, -18.0), p])
			draw_colored_polygon(tri, CombatHUD.INK)
			var tri2 := PackedVector2Array([p + Vector2(-9.0, -15.0), p + Vector2(9.0, -15.0), p + Vector2(0.0, -3.0)])
			draw_colored_polygon(tri2, Color(RouteGuide.RED, pulse))
			_text(f, p + Vector2(-90.0, -24.0), guide.boss_dist_text, 17, Color(1.0, 0.75, 0.7), 180.0)

	func _text(f: Font, pos: Vector2, s: String, sz: int, col: Color, w: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
		draw_string_outline(f, pos, s, align, w, sz, 5, CombatHUD.INK)
		draw_string(f, pos, s, align, w, sz, col)

	func _edge(i: int, pulse: float, f: Font) -> void:
		var p: Vector2 = guide.edge_pos[i]
		var d: Vector2 = guide.edge_dir[i]
		var s: float = guide.edge_size[i]
		var n := Vector2(-d.y, d.x)
		var k: int = guide.edge_kind[i]
		var a: float = pulse if k >= 1 else 0.9
		var tri := PackedVector2Array([p + d * (s + 4.0), p - d * (s * 0.4 + 2.0) + n * (s * 0.85 + 3.0), p - d * (s * 0.4 + 2.0) - n * (s * 0.85 + 3.0)])
		draw_colored_polygon(tri, CombatHUD.INK)
		var tri2 := PackedVector2Array([p + d * s, p - d * s * 0.4 + n * s * 0.85, p - d * s * 0.4 - n * s * 0.85])
		draw_colored_polygon(tri2, Color(RouteGuide.RED, a))
		if k == 1:
			var ang: float = d.angle()
			draw_arc(p - d * 2.0, s * 1.35, ang - 0.8, ang + 0.8, 12, Color(RouteGuide.RED, pulse), 3.0, true)
		if k == 2:
			_text(f, p - d * (s + 34.0) + Vector2(-80.0, 6.0), guide.boss_dist_text, 16, Color(1.0, 0.75, 0.7), 160.0)

	func _turn_panel(f: Font) -> void:
		var x0: float = size.x * 0.5 + guide.panel_half_w + RouteGuide.PANEL_GAP
		var ps: Vector2 = RouteGuide.PANEL_SIZE
		if x0 + ps.x > size.x - 8.0:
			x0 = size.x - 8.0 - ps.x
		var r := Rect2(Vector2(x0, 16.0), ps)
		draw_rect(r, Color(0.03, 0.02, 0.08, 0.72))
		draw_rect(r, Color(RouteGuide.CHEV_COL, 0.95), false, 3.0)
		# the bent arrow (left part of the panel)
		var cx: float = r.position.x + 46.0
		var by: float = r.position.y + ps.y - 14.0
		var dir: float = float(guide.turn_dir)
		var pts := PackedVector2Array()
		var head_at: Vector2
		var head_dir: Vector2
		if guide.turn_sharp:
			var top: float = r.position.y + 34.0
			var rad: float = 15.0
			pts.append(Vector2(cx - dir * rad, by))
			pts.append(Vector2(cx - dir * rad, top))
			for j: int in range(1, 9):
				var u: float = PI * float(j) / 8.0
				pts.append(Vector2(cx - dir * rad * cos(u), top - rad * sin(u)))
			pts.append(Vector2(cx + dir * rad, top + 16.0))
			head_at = Vector2(cx + dir * rad, top + 34.0)
			head_dir = Vector2(0.0, 1.0)
		else:
			var my: float = r.position.y + 42.0
			pts.append(Vector2(cx - dir * 10.0, by))
			pts.append(Vector2(cx - dir * 10.0, my))
			pts.append(Vector2(cx + dir * 12.0, my))
			head_at = Vector2(cx + dir * 34.0, my)
			head_dir = Vector2(dir, 0.0)
		var hn := Vector2(-head_dir.y, head_dir.x)
		var last: Vector2 = pts[pts.size() - 1]
		draw_polyline(pts, CombatHUD.INK, 17.0, true)
		draw_colored_polygon(PackedVector2Array([head_at + head_dir * 4.0, last - head_dir * 3.0 + hn * 19.0, last - head_dir * 3.0 - hn * 19.0]), CombatHUD.INK)
		draw_polyline(pts, CombatHUD.GOLD, 11.0, true)
		draw_colored_polygon(PackedVector2Array([head_at, last + hn * 14.0, last - hn * 14.0]), CombatHUD.GOLD)
		# texts (right part)
		var tx: float = r.position.x + 92.0
		var tw: float = ps.x - 98.0
		_text(f, Vector2(tx, r.position.y + 36.0), guide.turn_text, 21 if guide.turn_text.length() <= 8 else 17, CombatHUD.GOLD, tw)
		if guide.turn_dist_text != "":
			_text(f, Vector2(tx, r.position.y + 72.0), guide.turn_dist_text, 32, RouteGuide.CHEV_COL, tw)
		if guide.then_text != "":
			_text(f, Vector2(tx, r.position.y + 98.0), guide.then_text, 14, Color.WHITE, tw)
