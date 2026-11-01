# File: res://scripts/story/SideRace.gd
# Free-roam street drift races at night (plan 2026-11-01-w4-endings.md T5a), on the Day 2 race tech: a DriftCourse path on
# the real, measured Rạch Hầm roads, RouteGuide chevrons / next-turn panel / radar route, the bike's drift and nitro (drift
# corners charge it, as in the Day 2 race). Against the clock: a countdown, then the time to the finish line; every drift
# second takes DRIFT_BONUS_S off the scored time (up to BONUS_CAP of the par). Off the road for OFF_COURSE_S: back to the
# last gate. Off the bike for OFF_BIKE_S: the race is given up. Rank S / A / B / C against the route's par (the Day 2
# rival's full-pace time, DriftCourse.pace_time) x RANK_K.
#   dua_cau   "Nước rút Nguyễn Xiển": from the Đường số 20 lap line down Nguyễn Xiển to the Rạch Hầm bridge (one way).
#   dua_vong  "Vòng Đỗ Thế Diện": one lap of the Nguyễn Văn Tăng / Đỗ Thế Diện loop with the hairpin, from Đường số 20.
#   dua_gp    "Rạch Hầm GP đêm": the full Day 2 GP (2 laps, about 2.1 km), from the grid on the bridge.
# API: var r := SideRace.new(); roam.add_child(r); r.setup({"roam": roam, "id": "dua_cau"}); r.start()
#   signals started(id), finished(id, result {"rank", "time", "raw", "drift", "resets"}), failed(id, reason "off_bike")
#   advance(dt) (auto_tick false in tests), stop() gives the bike back (speed cap, nitro), frees the HUD and the guide.
# Never touches the story state (StorySideActivities records the result).
class_name SideRace
extends Node3D

signal started(id: String)
signal finished(id: String, result: Dictionary)
signal failed(id: String, reason: String)

const GameFXScript = preload("res://scripts/GameFX.gd")
const ROUTES: Dictionary = {
	"dua_cau": {"title": "Nước rút Nguyễn Xiển", "line": "Từ Đường số 20 xuống cầu Rạch Hầm"},
	"dua_vong": {"title": "Vòng Đỗ Thế Diện", "line": "Một vòng có cua kẹp tóc"},
	"dua_gp": {"title": "Rạch Hầm GP đêm", "line": "Hai vòng đường đua của Sói Xám"},
}
const ORDER: Array[String] = ["dua_cau", "dua_vong", "dua_gp"]
const COUNTDOWN_S: float = 3.0
const OFF_COURSE_M: float = 3.0
const OFF_COURSE_S: float = 1.2
const OFF_BIKE_S: float = 2.0
const DRIFT_BONUS_S: float = 0.5
const BONUS_CAP: float = 0.15
## Scored time / par at most this for the rank (the player's bike tops out near 83 % of the rival's pace profile).
const RANK_K: Dictionary = {"S": 1.3, "A": 1.5, "B": 1.8}
const BIKE_FLOOR_OFFSET: float = 0.05

var id: String = ""
var course: DriftCourse = null
var roam: Node = null
var bike: Node3D = null
var auto_tick: bool = true
var use_guide: bool = true
var guide: RouteGuide = null
## idle | countdown | racing | done | failed
var state: String = "idle"
var count_t: float = 0.0
var t: float = 0.0
var s_p: float = 0.0
var d_p: float = 0.0
var gate_i: int = 0
var drift_s: float = 0.0
var resets: int = 0
var result: Dictionary = {}
var hud: CanvasLayer = null
var top_label: Label = null
var big_label: Label = null
var _off_t: float = 0.0
var _off_bike_t: float = 0.0
var _cap: float = INF
var _nitro_was: bool = false
var _ray_q := PhysicsRayQueryParameters3D.new()


static func title(rid: String) -> String:
	return String((ROUTES.get(rid, {}) as Dictionary).get("title", rid))


## The route's path (DriftCourse data on the Day 2 measured points).
static func route_course(rid: String) -> DriftCourse:
	match rid:
		"dua_gp":
			return DriftCourse.rach_ham()
		"dua_cau":
			var c := DriftCourse.new()
			var raw: Array[Vector2] = [DriftCourse.P_LAP, DriftCourse.P_Y, DriftCourse.P_J1, DriftCourse.P_BRIDGE_N, DriftCourse.P_GRID]
			var w: Array[float] = [DriftCourse.HW_MAIN, DriftCourse.HW_MAIN, DriftCourse.HW_MAIN, DriftCourse.HW_DECK, DriftCourse.HW_DECK]
			for p: Vector2 in DriftCourse.RUNOFF_PTS:
				raw.append(p)
				w.append(DriftCourse.HW_DECK)
			c.build(raw, w, [4, 4] as Array[int], 4)
			return c
		"dua_vong":
			var c2 := DriftCourse.new()
			var lp: Array[Vector2] = DriftCourse.LOOP_PTS
			var ib: int = lp.find(DriftCourse.P_B)
			var raw2: Array[Vector2] = [DriftCourse.P_B, lp[ib + 1], DriftCourse.P_LAP]
			var w2: Array[float] = [DriftCourse.HW_SIDE, DriftCourse.HW_SIDE, DriftCourse.HW_MAIN]
			for i: int in ib + 1:
				raw2.append(lp[i])
				w2.append(DriftCourse.HW_MAIN if i < DriftCourse.LOOP_SIDE_FROM else DriftCourse.HW_SIDE)
			var fin: int = raw2.size() - 1     # back at Đỗ Thế Diện / Đường số 20
			raw2.append(lp[ib + 1])
			w2.append(DriftCourse.HW_SIDE)
			c2.build(raw2, w2, [2, fin] as Array[int], fin)
			return c2
	return null


## The par time of a route (s): the Day 2 rival's full-pace time on it.
static func par(c: DriftCourse) -> float:
	return c.pace_time() if c else 1.0


static func rank_for(score_t: float, par_t: float) -> String:
	for l: String in ["S", "A", "B"]:
		if score_t <= par_t * float(RANK_K[l]):
			return l
	return "C"


static func drift_bonus(drift: float, par_t: float) -> float:
	return minf(drift * DRIFT_BONUS_S, par_t * BONUS_CAP)


## "1:23.4"
static func time_text(sec: float) -> String:
	var m: int = int(sec / 60.0)
	return "%d:%04.1f" % [m, sec - 60.0 * m]


func setup(opts: Dictionary) -> void:
	roam = opts.get("roam", null)
	id = String(opts.get("id", "dua_cau"))
	bike = opts.get("bike", roam.get("bike") if roam else null)
	course = opts.get("course", null)
	if course == null:
		course = route_course(id)
	use_guide = bool(opts.get("guide", true))
	name = "SideRace_" + id


func start() -> void:
	if course == null or bike == null:
		_fail("no_course")
		return
	_place(0.0)
	s_p = 0.0
	gate_i = 0
	t = 0.0
	drift_s = 0.0
	resets = 0
	state = "countdown"
	count_t = COUNTDOWN_S
	_cap = float(bike.get("speed_cap"))
	bike.set("speed_cap", 0.0)
	_nitro_was = bool(bike.get("nitro_enabled"))
	if bike.has_method("set_nitro_enabled"):
		bike.call("set_nitro_enabled", true)
	_build_hud()
	if use_guide:
		guide = RouteGuide.new()
		guide.name = "RaceGuide"
		add_child(guide)
		guide.setup({"path": course, "bike": bike, "roam": roam, "s_fn": func() -> float: return s_p})
	started.emit(id)


func advance(dt: float) -> void:
	match state:
		"countdown":
			count_t -= dt
			if big_label:
				big_label.text = str(ceili(count_t)) if count_t > 0.0 else "ĐI!"
			if count_t <= 0.0:
				state = "racing"
				bike.set("speed_cap", _cap)
				if guide:
					guide.set_active(true)
		"racing":
			t += dt
			if big_label and t > 1.0:
				big_label.text = ""
			_track(dt)
	_hud_text()


func _track(dt: float) -> void:
	if roam != null and not bool(roam.get("mounted")):
		_off_bike_t += dt
		if _off_bike_t >= OFF_BIKE_S:
			_fail("off_bike")
		return
	_off_bike_t = 0.0
	var p: Vector3 = bike.global_position
	var v: Vector2 = course.project_near(Vector2(p.x, p.z), s_p)
	s_p = v.x
	d_p = v.y
	while gate_i < course.gates.size() and s_p >= course.gates[gate_i]:
		gate_i += 1
	if absf(d_p) > course.half_width_at(s_p) + OFF_COURSE_M:
		_off_t += dt
		if _off_t >= OFF_COURSE_S:
			reset_to_gate()
			return
	else:
		_off_t = 0.0
	if bool(bike.get("is_drifting")):
		drift_s += dt
	if s_p >= course.length:
		_finish()


## Back to the last gate passed (the grid before the first one), stopped, facing along the road.
func reset_to_gate() -> void:
	var gs: float = course.gates[gate_i - 1] if gate_i > 0 else 0.0
	resets += 1
	_off_t = 0.0
	_place(gs)
	s_p = gs


func _finish() -> void:
	state = "done"
	var pt: float = par(course)
	var score_t: float = maxf(t - drift_bonus(drift_s, pt), 0.0)
	result = {"rank": rank_for(score_t, pt), "time": snappedf(score_t, 0.1), "raw": snappedf(t, 0.1), "drift": snappedf(drift_s, 0.1),
		"resets": resets}
	if big_label:
		big_label.text = "VỀ ĐÍCH"
	_hud_text()
	finished.emit(id, result)


func _fail(reason: String) -> void:
	state = "failed"
	failed.emit(id, reason)


func stop() -> void:
	if bike and is_instance_valid(bike):
		if state == "countdown":
			bike.set("speed_cap", _cap)
		if bike.has_method("set_nitro_enabled"):
			bike.call("set_nitro_enabled", _nitro_was)
	if guide:
		guide.set_active(false)
		guide.queue_free()
		guide = null
	if hud:
		hud.queue_free()
		hud = null
	if state in ["countdown", "racing"]:
		state = "idle"


func _place(s: float) -> void:
	var p: Vector2 = course.world(s, 0.0)
	var y: Variant = _floor_at(Vector3(p.x, 0.0, p.y))
	var fy: float = float(y) if y is float else 0.05
	var yaw: float = course.yaw_at(s)
	var origin := Vector3(p.x, fy - BIKE_FLOOR_OFFSET, p.y)
	if roam and is_instance_valid(roam) and not bool(roam.get("mounted")):
		var pl: Node = roam.get("player")
		if bool(roam.get("bike_parked")):
			bike.global_position = origin
			bike.rotation = Vector3(0.0, yaw, 0.0)
		if pl and pl.has_method("teleport"):
			pl.call("teleport", origin + Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0), yaw)
		if roam.has_method("mount_bike"):
			roam.call("mount_bike")
	bike.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	if "velocity" in bike:
		bike.set("velocity", Vector3.ZERO)
	if "current_speed_ms" in bike:
		bike.set("current_speed_ms", 0.0)


func _floor_at(p: Vector3) -> Variant:
	if not is_inside_tree():
		return null
	_ray_q.from = p + Vector3(0.0, 6.0, 0.0)
	_ray_q.to = p - Vector3(0.0, 6.0, 0.0)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray_q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.5:
		return null
	return (hit["position"] as Vector3).y


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "SideRaceHUD"
	hud.layer = 40
	add_child(hud)
	top_label = GameFXScript.make_label("", 22, Color("#3FF2FF"))
	top_label.name = "Top"
	top_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_label.position.y = 18.0
	hud.add_child(top_label)
	big_label = GameFXScript.make_label("", 72, Color("#F1C40F"))
	big_label.name = "Big"
	big_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud.add_child(big_label)


func _hud_text() -> void:
	if top_label == null:
		return
	top_label.text = "%s   %s   Cổng %d/%d   Drift %.1f s" % [title(id).to_upper(), time_text(t), gate_i, course.gates.size(), drift_s]


func texts() -> Array[String]:
	var out: Array[String] = []
	for l: Label in [top_label, big_label]:
		if l:
			out.append(l.text)
	return out


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


func _exit_tree() -> void:
	stop()
