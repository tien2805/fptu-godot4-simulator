# File: res://scripts/story/SideDelivery.gd
# Free-roam delivery runs (plan 2026-11-01-w4-endings.md T5c): pick the order up at the start spot, then ride it to each
# drop in turn (a tall beam over the next drop, the HUD with the time, the drop count, the distance and the direction in
# words). Within DROP_M of a drop: delivered, a customer's line as a toast. Every crash of the bike spills the order:
# +CRASH_PENALTY_S. Rank against the par (the straight-line legs at PAR_SPEED m/s plus PAR_EXTRA_S) x RANK_K; past
# LIMIT_K x par the customers cancel (given up). Roads only: the drops sit on the measured Day 2 roads.
#   giao_com  "Cơm tấm giao tận nơi": from the Đỗ Thế Diện plaza, two drops (Đường số 20, the Y junction).
#   giao_dem  "Bánh mì nửa đêm": from the south end of the Rạch Hầm bridge, three drops up Nguyễn Xiển and into the loop.
# API: like SideRace: setup({"roam", "id"}), start(), advance(dt) (auto_tick false in tests), stop(); target(), leg;
#   signals started(id), finished(id, result {"rank", "time", "raw", "crashes"}), failed(id, reason "time").
# w5-side T2 (plan 2026-11-03-w5-side.md): guided like the Day 2 chase: route_course(id) is a DriftCourse on the measured
# roads from the start through every drop (ROUTE_PTS), a RouteGuide shows its chevrons on the road, the next-turn panel and
# the route on the radar; each drop gets a low gold ring with a parcel over it (no tall beam); the HUD reads the distance
# along the route ("Còn 240 m") instead of compass words. drop_s[i] = the route's s at drop i; s_p = the player on it.
class_name SideDelivery
extends Node3D

signal started(id: String)
signal delivered(id: String, index: int)
signal finished(id: String, result: Dictionary)
signal failed(id: String, reason: String)

const GameFXScript = preload("res://scripts/GameFX.gd")
const RUNS: Dictionary = {
	"giao_com": {"title": "Cơm tấm giao tận nơi", "at": Vector2(1736.0, 48.6), "night": false,
		"drops": [Vector2(1932.0, -159.0), Vector2(2034.0, -155.0)],
		"lines": ["Khách: Cơm tấm sườn bì chả, thêm mỡ hành. Cảm ơn em nha!", "Khách: Ủa sao tới nhanh vậy? Đánh giá năm sao!"]},
	"giao_dem": {"title": "Bánh mì nửa đêm", "at": Vector2(2134.5, 193.0), "night": true,
		"drops": [Vector2(2081.7, 12.8), Vector2(1976.0, -107.0), Vector2(1825.0, 24.0)],
		"lines": ["Khách: Bánh mì lúc nửa đêm là chân ái.", "Khách: Thêm pate không em? À giao rồi hả, thôi khỏi.",
			"Khách: Chạy deadline mà có bánh mì là sống rồi!"]},
}
const ORDER: Array[String] = ["giao_com", "giao_dem"]
const DROP_M: float = 6.0
const PAR_SPEED: float = 14.0
const PAR_EXTRA_S: float = 8.0
const RANK_K: Dictionary = {"S": 1.0, "A": 1.3, "B": 1.7}
const LIMIT_K: float = 2.6
const CRASH_PENALTY_S: float = 5.0
const DIRS: Array[String] = ["Bắc", "Đông Bắc", "Đông", "Đông Nam", "Nam", "Tây Nam", "Tây", "Tây Bắc"]
const GOLD := Color("#F1C40F")
const DROP_PIN_M: float = 4.0
## The road route of each run (map points, x east / z south) and the half width per point: the start, then every drop in
## order on the Day 2 measured roads (DriftCourse's named points and loop).
static var _route_cache: Dictionary = {}

const HUD_S: float = 0.1
var _hud_t: float = 0.0   # HUD refresh countdown (_hud_tick)
var id: String = ""
var roam: Node = null
var auto_tick: bool = true
## idle | running | done | failed
var state: String = "idle"
var t: float = 0.0
var leg: int = 0
var crashes: int = 0
var par_t: float = 0.0
var result: Dictionary = {}
## The drop marker (a gold ring on the road with a parcel over it).
var beacon: Node3D = null
var course: DriftCourse = null
var guide: RouteGuide = null
var use_guide: bool = true
var drop_s := PackedFloat32Array()
var s_p: float = 0.0
var d_p: float = 0.0
var _ray_q := PhysicsRayQueryParameters3D.new()
var hud: CanvasLayer = null
var top_label: Label = null
var _bike: Node = null


static func title(rid: String) -> String:
	return String((RUNS.get(rid, {}) as Dictionary).get("title", rid))


static func start_at(rid: String) -> Vector2:
	return (RUNS.get(rid, {}) as Dictionary).get("at", Vector2.ZERO)


static func drops(rid: String) -> Array:
	return (RUNS.get(rid, {}) as Dictionary).get("drops", [])


## The raw route points and half widths of a run: [Array[Vector2], Array[float]].
static func route_points(rid: String) -> Array:
	var pts: Array[Vector2] = []
	var w: Array[float] = []
	match rid:
		"giao_com":
			# the Đỗ Thế Diện plaza, round the hairpin, up Đỗ Thế Diện to Đường số 20 (drop 1), down Đường số 20 to Nguyễn Văn
			# Tăng, east to the Y junction (drop 2)
			var lp: Array[Vector2] = DriftCourse.LOOP_PTS
			for i: int in range(lp.find(start_at(rid)), lp.find(DriftCourse.P_B) + 1):
				pts.append(lp[i])
				w.append(DriftCourse.HW_MAIN if i < DriftCourse.LOOP_SIDE_FROM else DriftCourse.HW_SIDE)
			for p: Vector2 in [Vector2(1954.0, -133.0), DriftCourse.P_LAP, DriftCourse.P_Y]:
				pts.append(p)
				w.append(DriftCourse.HW_SIDE if p.x < 1960.0 else DriftCourse.HW_MAIN)
		"giao_dem":
			# the south end of the Rạch Hầm bridge, north over the deck, up Nguyễn Xiển (drop 1 at Đường Số 21), the Y
			# junction, Nguyễn Văn Tăng to Đường số 20 (drop 2), on into the loop (drop 3)
			for p2: Vector2 in [DriftCourse.RUNOFF_PTS[1], DriftCourse.RUNOFF_PTS[0], DriftCourse.P_GRID, DriftCourse.P_BRIDGE_N]:
				pts.append(p2)
				w.append(DriftCourse.HW_DECK)
			for p3: Vector2 in [DriftCourse.P_J1, DriftCourse.P_Y, DriftCourse.P_LAP, DriftCourse.LOOP_PTS[0], DriftCourse.LOOP_PTS[1],
					DriftCourse.LOOP_PTS[2]]:
				pts.append(p3)
				w.append(DriftCourse.HW_MAIN)
	# a drop at a junction: points DROP_PIN_M before and after it along the roads, so the route runs through the drop itself
	# (DriftCourse keeps a vertex between short segments as it is) instead of a racing line cutting the corner
	var ds: Array = drops(rid)
	var i2: int = pts.size() - 2
	while i2 >= 1:
		if ds.has(pts[i2]):
			var a: Vector2 = pts[i2 - 1]
			var b: Vector2 = pts[i2]
			var e: Vector2 = pts[i2 + 1]
			pts.insert(i2 + 1, b + (e - b).normalized() * minf(DROP_PIN_M, b.distance_to(e) * 0.4))
			w.insert(i2 + 1, w[i2])
			pts.insert(i2, b + (a - b).normalized() * minf(DROP_PIN_M, b.distance_to(a) * 0.4))
			w.insert(i2, w[i2])
		i2 -= 1
	return [pts, w]


## The run's road route (a DriftCourse from the start to the last drop; built once per run id).
static func route_course(rid: String) -> DriftCourse:
	if _route_cache.has(rid):
		return _route_cache[rid]
	var rw: Array = route_points(rid)
	var pts: Array[Vector2] = rw[0]
	if pts.size() < 2:
		return null
	var c := DriftCourse.new()
	c.build(pts, rw[1], [0, pts.size() - 1] as Array[int], pts.size() - 1)
	_route_cache[rid] = c
	return c


## The route's s at each drop, in order (each searched from the previous one to the end of the route).
static func drops_s(rid: String) -> PackedFloat32Array:
	var c: DriftCourse = route_course(rid)
	var out := PackedFloat32Array()
	var hint: float = 0.0
	for q: Vector2 in drops(rid):
		if c:
			hint = c.project_near(q, (hint + c.total) * 0.5, (c.total - hint) * 0.5 + 4.0).x
		out.append(hint)
	return out


## The par time: the straight-line legs from the start through every drop at PAR_SPEED, plus PAR_EXTRA_S.
static func par(rid: String) -> float:
	var p: Vector2 = start_at(rid)
	var d: float = 0.0
	for q: Vector2 in drops(rid):
		d += p.distance_to(q)
		p = q
	return d / PAR_SPEED + PAR_EXTRA_S


static func rank_for(sec: float, par_s: float) -> String:
	for l: String in ["S", "A", "B"]:
		if sec <= par_s * float(RANK_K[l]):
			return l
	return "C"


## The direction from `from` to `to` in words (x east, z south).
static func dir_word(from: Vector2, to: Vector2) -> String:
	var d: Vector2 = to - from
	var ang: float = rad_to_deg(atan2(d.x, -d.y))   # 0 = north (-z), 90 = east (+x)
	var i: int = int(round(fposmod(ang, 360.0) / 45.0)) % 8
	return DIRS[i]


func setup(opts: Dictionary) -> void:
	roam = opts.get("roam", null)
	id = String(opts.get("id", "giao_com"))
	use_guide = bool(opts.get("guide", true))
	name = "SideDelivery_" + id


func start() -> void:
	if not RUNS.has(id) or roam == null:
		_fail("no_course")
		return
	state = "running"
	t = 0.0
	leg = 0
	crashes = 0
	par_t = par(id)
	_bike = roam.get("bike")
	if _bike and _bike.has_signal("crash_occurred"):
		_bike.connect("crash_occurred", _on_crash)
	course = route_course(id)
	drop_s = drops_s(id)
	s_p = 0.0
	d_p = 0.0
	_follow()
	if use_guide and course != null and _bike is PlayerBike:
		guide = RouteGuide.new()
		guide.name = "DeliveryGuide"
		add_child(guide)
		guide.setup({"path": course, "bike": _bike, "roam": roam, "s_fn": func() -> float: return s_p, "end_s": course.length,
			"floor_fn": floor_at})
		guide.set_active(true)
	_build_hud()
	_place_beacon()
	started.emit(id)


func target() -> Vector2:
	var ds: Array = drops(id)
	return ds[mini(leg, ds.size() - 1)]


func _focus() -> Node3D:
	if bool(roam.get("mounted")):
		return roam.get("bike") as Node3D
	return roam.get("player") as Node3D


func advance(dt: float) -> void:
	if state != "running":
		return
	t += dt
	if t + crashes * CRASH_PENALTY_S > par_t * LIMIT_K:
		_fail("time")
		return
	_follow()
	var f: Node3D = _focus()
	if f != null and f.is_inside_tree():
		var p := Vector2(f.global_position.x, f.global_position.z)
		if p.distance_to(target()) <= DROP_M:
			_deliver()
	_hud_tick(dt)


## The player (on the bike or on foot) on the route: progress s_p and lateral d_p (a wide search when far off the line).
func _follow() -> void:
	if course == null:
		return
	var f: Node3D = _focus()
	if f == null or not f.is_inside_tree():
		return
	var bp := Vector2(f.global_position.x, f.global_position.z)
	var pr: Vector2 = course.project_near(bp, s_p)
	if absf(pr.y) > 25.0:
		var any: Vector2 = course.project_any(bp, s_p)
		if absf(any.y) + 5.0 < absf(pr.y):
			pr = any
	s_p = pr.x
	d_p = pr.y


## Metres left to the next drop: along the route when on it, never less than the straight line.
func dist_left() -> float:
	var f: Node3D = _focus()
	var p: Vector2 = Vector2(f.global_position.x, f.global_position.z) if f and f.is_inside_tree() else target()
	var straight: float = p.distance_to(target())
	if course == null or leg >= drop_s.size() or absf(d_p) > 20.0:
		return straight
	return maxf(drop_s[leg] - s_p, straight)


## Floor height under p for the chevrons and the drop ring (a ray from `up` above to `down` below; not the bike).
func floor_at(p: Vector3, up: float = 3.0, down: float = 6.0) -> Variant:
	if not is_inside_tree():
		return null
	_ray_q.from = p + Vector3(0.0, up, 0.0)
	_ray_q.to = p - Vector3(0.0, down, 0.0)
	if _bike is CollisionObject3D and _ray_q.exclude.is_empty():
		_ray_q.exclude = [(_bike as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray_q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.5:
		return null
	return (hit["position"] as Vector3).y


func _deliver() -> void:
	var lines: Array = (RUNS[id] as Dictionary).get("lines", [])
	if leg < lines.size() and roam and roam.get("story_roam") != null:
		var sr: Node = roam.get("story_roam")
		if sr.has_method("toast"):
			sr.call("toast", String(lines[leg]), "phone_buzz")
	delivered.emit(id, leg)
	leg += 1
	if leg >= drops(id).size():
		_finish()
	else:
		_place_beacon()


func _on_crash() -> void:
	if state == "running":
		crashes += 1


func _finish() -> void:
	state = "done"
	var score_t: float = t + crashes * CRASH_PENALTY_S
	result = {"rank": rank_for(score_t, par_t), "time": snappedf(score_t, 0.1), "raw": snappedf(t, 0.1), "crashes": crashes}
	_free_beacon()
	_guide_off()
	finished.emit(id, result)


func _fail(reason: String) -> void:
	if state in ["done", "failed"]:
		return
	state = "failed"
	_free_beacon()
	_guide_off()
	failed.emit(id, reason)


func _guide_off() -> void:
	if guide and is_instance_valid(guide):
		guide.set_active(false)
		guide.queue_free()
	guide = null


func stop() -> void:
	if _bike and is_instance_valid(_bike) and _bike.is_connected("crash_occurred", _on_crash):
		_bike.disconnect("crash_occurred", _on_crash)
	_free_beacon()
	_guide_off()
	if hud:
		hud.queue_free()
		hud = null
	if state == "running":
		state = "idle"


func _place_beacon() -> void:
	_free_beacon()
	if not (roam is Node3D):
		return
	beacon = Node3D.new()
	beacon.name = "DropRing"
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = DROP_M - 0.6
	tm.outer_radius = DROP_M - 0.2
	ring.mesh = tm
	ring.material_override = CineFX._glow_mat(GOLD, 2.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.position.y = 0.08
	beacon.add_child(ring)
	# the parcel: a glowing box floating at head height over the drop
	CineFX._box(beacon, "Parcel", Vector3(0.6, 0.45, 0.6), Vector3(0.0, 1.9, 0.0), CineFX._glow_mat(GOLD, 1.4))
	roam.add_child(beacon)
	var tg: Vector2 = target()
	var fy: Variant = floor_at(Vector3(tg.x, (_focus().global_position.y if _focus() else 0.0) + 2.0, tg.y), 4.0, 10.0)
	beacon.global_position = Vector3(tg.x, float(fy) if fy is float else 0.0, tg.y)


func _free_beacon() -> void:
	if beacon and is_instance_valid(beacon):
		beacon.queue_free()
	beacon = null


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "DeliveryHUD"
	hud.layer = 40
	add_child(hud)
	top_label = GameFXScript.make_label("", 22, Color("#F1C40F"))
	top_label.name = "Top"
	top_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_label.position.y = 18.0
	hud.add_child(top_label)
	_hud_text()



## The HUD line at HUD_S (about 10 Hz), not every frame (the first call shows it at once).
func _hud_tick(dt: float) -> void:
	_hud_t -= dt
	if _hud_t > 0.0:
		return
	_hud_t = HUD_S
	_hud_text()


func _hud_text() -> void:
	if top_label == null or roam == null:
		return
	top_label.text = "%s   %s   Điểm giao %d/%d   Còn %d m" % [title(id).to_upper(), SideRace.time_text(t),
		mini(leg + 1, drops(id).size()), drops(id).size(), int(dist_left())]
	if crashes > 0:
		top_label.text += "   Đổ hàng x%d" % crashes


func texts() -> Array[String]:
	var out: Array[String] = []
	if top_label:
		out.append(top_label.text)
	return out


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


func _exit_tree() -> void:
	stop()
