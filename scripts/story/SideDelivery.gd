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
var beacon: Node3D = null
var hud: CanvasLayer = null
var top_label: Label = null
var _bike: Node = null


static func title(rid: String) -> String:
	return String((RUNS.get(rid, {}) as Dictionary).get("title", rid))


static func start_at(rid: String) -> Vector2:
	return (RUNS.get(rid, {}) as Dictionary).get("at", Vector2.ZERO)


static func drops(rid: String) -> Array:
	return (RUNS.get(rid, {}) as Dictionary).get("drops", [])


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
	var f: Node3D = _focus()
	if f != null and f.is_inside_tree():
		var p := Vector2(f.global_position.x, f.global_position.z)
		if p.distance_to(target()) <= DROP_M:
			_deliver()
	_hud_tick(dt)


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
	finished.emit(id, result)


func _fail(reason: String) -> void:
	if state in ["done", "failed"]:
		return
	state = "failed"
	_free_beacon()
	failed.emit(id, reason)


func stop() -> void:
	if _bike and is_instance_valid(_bike) and _bike.is_connected("crash_occurred", _on_crash):
		_bike.disconnect("crash_occurred", _on_crash)
	_free_beacon()
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
	beacon.name = "DropBeacon"
	var beam := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.6
	cy.bottom_radius = 0.6
	cy.height = 30.0
	beam.mesh = cy
	var m: StandardMaterial3D = CineFX._glow_mat(Color("#F1C40F"), 1.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = m
	beam.position.y = 15.0
	beacon.add_child(beam)
	roam.add_child(beacon)
	var tg: Vector2 = target()
	beacon.global_position = Vector3(tg.x, 0.0, tg.y)


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
	var f: Node3D = _focus()
	var p: Vector2 = Vector2(f.global_position.x, f.global_position.z) if f and f.is_inside_tree() else target()
	top_label.text = "%s   %s   Điểm giao %d/%d   Còn %d m, hướng %s" % [title(id).to_upper(), SideRace.time_text(t),
		mini(leg + 1, drops(id).size()), drops(id).size(), int(p.distance_to(target())), dir_word(p, target())]
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
