# File: res://scripts/story/StorySideActivities.gd
# Free-roam side activities of story mode (plan 2026-11-01-w4-endings.md T5), StoryRoam adds one as its child. Each
# activity has a start spot with a glowing ring and a light beam, shown while it can start: story free roam from Day 1, no
# mission / cinematic / beat run / police, at night for the night ones. Within START_M of a spot FreeRoam's hint reads
# "[E] <kind>: <title>" (+ the best rank); [E] starts it (the story is busy meanwhile, so no night scare comes on top),
# its end records the result in the unlock file (SideRecords, best per activity) and toasts it.
#   races (T5a)      SideRace dua_cau, dua_vong, dua_gp: at night, the bike.
#   takedowns (T5b)  SideTakedown td_soi, td_bay: any time, the bike (Day 2 bike combat in free mode).
#   deliveries (T5c) SideDelivery giao_com (by day or night), giao_dem (at night): timed drops on the Day 2 roads.
#   Vovinam (T5d)    SideVovinam vo_hem, vo_cau: any time, on foot (Phase B melee, bare hands, the traffic parked).
# API: setup(roam, story, director); spots() rows {id, kind, title, at, night}; can_start(id); start(id) -> bool; advance(dt)
#   (auto_tick false in tests); current (the running activity node), current_id; signals activity_started(id),
#   activity_done(id, result, new_best), activity_failed(id, reason).
class_name StorySideActivities
extends Node

signal activity_started(id: String)
signal activity_done(id: String, result: Dictionary, new_best: bool)
signal activity_failed(id: String, reason: String)

const CHECK_S: float = 0.25
const START_M: float = 8.0
const KIND_NAME: Dictionary = {"race": "Đua đêm", "takedown": "Hạ gục", "delivery": "Giao hàng", "vovinam": "Võ đường phố"}
const KIND_COLOR: Dictionary = {"race": Color("#3FF2FF"), "takedown": Color("#FF6B6B"), "delivery": Color("#F1C40F"),
	"vovinam": Color("#6FA8FF")}
## The owner's track while it runs (MusicDirector slot; no file = silence), free-roam music again after.
const KIND_MUSIC: Dictionary = {"race": "side_drift", "takedown": "mission_bike_chase", "delivery": "side_delivery",
	"vovinam": "mission_fight"}
const FAIL_LINE: Dictionary = {"off_bike": "Bỏ cuộc: rời xe giữa chừng.", "no_course": "Không mở được thử thách.",
	"knocked": "Toang! Bị đạp văng khỏi xe.", "time": "Hết giờ rồi. Lần sau nhanh hơn nhé.",
	"ko": "Toang! Nằm sàn rồi. Tập thêm rồi quay lại."}

static var _courses: Dictionary = {}

var roam: Node = null
var story: Node = null
var director: Node = null
var auto_tick: bool = true
## Tests: extra setup opts for the activity node (e.g. {"guide": false}).
var activity_opts: Dictionary = {}
var current: Node = null
var current_id: String = ""
var near_id: String = ""
var markers: Dictionary = {}
var last_result: Dictionary = {}
var _check_t: float = 0.0


func _init() -> void:
	name = "SideActivities"


func setup(r: Node, s: Node, d: Node) -> void:
	roam = r
	story = s
	director = d


static func race_course(rid: String) -> DriftCourse:
	if not _courses.has(rid):
		_courses[rid] = SideRace.route_course(rid)
	return _courses[rid]


## Every activity with its start spot: {id, kind, title, at (Vector3), yaw, night}.
static func spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rid: String in SideRace.ORDER:
		var c: DriftCourse = race_course(rid)
		var p: Vector2 = c.world(0.0, 0.0)
		out.append({"id": rid, "kind": "race", "title": SideRace.title(rid), "at": Vector3(p.x, 0.0, p.y), "yaw": c.yaw_at(0.0),
			"night": true})
	for cid: String in SideTakedown.ORDER:
		var a: Vector2 = SideTakedown.start_at(cid)
		out.append({"id": cid, "kind": "takedown", "title": SideTakedown.title(cid), "at": Vector3(a.x, 0.0, a.y), "yaw": 0.0,
			"night": false})
	for did: String in SideDelivery.ORDER:
		var d: Vector2 = SideDelivery.start_at(did)
		out.append({"id": did, "kind": "delivery", "title": SideDelivery.title(did), "at": Vector3(d.x, 0.0, d.y), "yaw": 0.0,
			"night": bool(SideDelivery.RUNS[did]["night"])})
	for fid: String in SideVovinam.ORDER:
		var v: Vector2 = SideVovinam.start_at(fid)
		out.append({"id": fid, "kind": "vovinam", "title": SideVovinam.title(fid), "at": Vector3(v.x, 0.0, v.y), "yaw": 0.0,
			"night": false})
	return out


static func spot(id: String) -> Dictionary:
	for s: Dictionary in spots():
		if String(s["id"]) == id:
			return s
	return {}


## Story free roam with nothing else going on (and night for the night ones).
func can_start(id: String) -> bool:
	var sp: Dictionary = spot(id)
	if sp.is_empty() or current != null or roam == null or director == null:
		return false
	if not bool(director.get("active")) or int(director.get("day")) < 1:
		return false
	if roam.get("cine_player") != null:
		return false
	if bool(sp["night"]) and String(roam.get("tod_preset")) != "night":
		return false
	if story != null and (story.get("mission_node") != null or bool(story.get("busy")) or String(story.get("running")) != ""):
		return false
	var w: Variant = roam.get("wanted")
	if w != null and is_instance_valid(w) and (String((w as Object).get("state")) != "free" or int((w as Object).get("stars")) > 0):
		return false
	return true


func hint_text(id: String) -> String:
	var sp: Dictionary = spot(id)
	var b: Dictionary = SideRecords.best(id)
	var t: String = "[E] %s: %s" % [String(KIND_NAME.get(sp.get("kind", ""), "")), String(sp.get("title", id))]
	if not b.is_empty():
		t += " · Kỷ lục: Hạng %s" % String(b.get("rank", "-"))
	return t


func _focus() -> Node3D:
	if roam == null:
		return null
	if bool(roam.get("mounted")):
		var b: Node3D = roam.get("bike") as Node3D
		if b != null and b.is_inside_tree():
			return b
	return roam.get("player") as Node3D


func advance(dt: float) -> void:
	_check_t -= dt
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	var f: Node3D = _focus()
	var was: String = near_id
	near_id = ""
	for sp: Dictionary in spots():
		var id: String = String(sp["id"])
		var ok: bool = can_start(id)
		_marker(id, sp if ok else {})
		if ok and f != null and f.is_inside_tree():
			var at: Vector3 = sp["at"]
			if Vector2(f.global_position.x - at.x, f.global_position.z - at.z).length() <= START_M:
				near_id = id
	if near_id != "" and near_id != was and roam.has_method("flash_hint"):
		roam.call("flash_hint", hint_text(near_id))


func start(id: String) -> bool:
	if not can_start(id):
		return false
	var sp: Dictionary = spot(id)
	match String(sp["kind"]):
		"race":
			var r := SideRace.new()
			roam.add_child(r)
			var o: Dictionary = {"roam": roam, "id": id, "course": race_course(id)}
			o.merge(activity_opts, true)
			r.setup(o)
			r.finished.connect(_on_done)
			r.failed.connect(_on_failed)
			current = r
		"takedown":
			var td := SideTakedown.new()
			roam.add_child(td)
			td.setup({"roam": roam, "id": id})
			td.finished.connect(_on_done)
			td.failed.connect(_on_failed)
			current = td
		"delivery":
			var dv := SideDelivery.new()
			roam.add_child(dv)
			dv.setup({"roam": roam, "id": id})
			dv.finished.connect(_on_done)
			dv.failed.connect(_on_failed)
			current = dv
		"vovinam":
			var vv := SideVovinam.new()
			roam.add_child(vv)
			vv.setup({"roam": roam, "id": id})
			vv.finished.connect(_on_done)
			vv.failed.connect(_on_failed)
			current = vv
		_:
			return false
	current_id = id
	near_id = ""
	_clear_markers()
	if story:
		story.set("busy", true)
	current.call("start")   # (mounting plays the roam music: the activity's track goes on after)
	if current != null:
		var ms: String = String(KIND_MUSIC.get(String(sp["kind"]), ""))
		var fx: Node = get_node_or_null("/root/GameFX")
		if ms != "" and fx and fx.has_method("music_play"):
			fx.call("music_play", ms, 0.5)
		activity_started.emit(id)
	return true


func _on_done(id: String, res: Dictionary) -> void:
	last_result = res.duplicate()
	var nb: bool = SideRecords.record(id, res)
	var line: String = "Xong %s · %s · Hạng %s" % [String(spot(id).get("title", id)), SideRace.time_text(float(res.get("time", 0.0))),
		String(res.get("rank", "C"))] if res.has("time") else "Xong %s · Hạng %s" % [String(spot(id).get("title", id)), String(res.get("rank", "C"))]
	if nb:
		line += " · Kỷ lục mới!"
	_toast(line, "success_fanfare")
	_end_current()
	activity_done.emit(id, res, nb)


func _on_failed(id: String, reason: String) -> void:
	_toast(String(FAIL_LINE.get(reason, "Bỏ cuộc.")), "")
	_end_current()
	activity_failed.emit(id, reason)


func _toast(text: String, cue: String) -> void:
	if story and story.has_method("toast"):
		story.call("toast", text, cue)


func _end_current() -> void:
	if current and is_instance_valid(current):
		current.call("stop")
		current.queue_free()
	current = null
	current_id = ""
	if story:
		story.set("busy", false)
		if story.has_method("_music"):
			story.call("_music", true)


## A glowing ring on the ground with a light beam over the start ({} removes it).
func _marker(id: String, sp: Dictionary) -> void:
	var old: Variant = markers.get(id)
	var alive: bool = old != null and is_instance_valid(old)
	if sp.is_empty():
		if alive:
			(old as Node).queue_free()
		markers.erase(id)
		return
	if alive or roam == null or not (roam is Node3D):
		return
	var col: Color = KIND_COLOR.get(String(sp["kind"]), Color("#F1C40F"))
	var m := Node3D.new()
	m.name = "SideSpot_" + id
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.6
	tm.outer_radius = 3.0
	ring.mesh = tm
	ring.material_override = CineFX._glow_mat(col, 1.8)
	ring.position.y = 0.08
	m.add_child(ring)
	var beam := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.35
	cy.bottom_radius = 0.35
	cy.height = 14.0
	beam.mesh = cy
	var bm: StandardMaterial3D = CineFX._glow_mat(col, 1.2)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color.a = 0.35
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = bm
	beam.position.y = 7.0
	m.add_child(beam)
	roam.add_child(m)
	m.global_position = sp["at"]
	markers[id] = m


func _clear_markers() -> void:
	for k: String in markers.keys():
		var m: Variant = markers[k]
		if m != null and is_instance_valid(m):
			(m as Node).queue_free()
	markers.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo or k.physical_keycode != KEY_E:
		return
	if near_id == "" or current != null:
		return
	if story != null and String(story.get("active_marker")) != "":
		return   # a story marker takes [E] first
	if start(near_id):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


func _exit_tree() -> void:
	_clear_markers()
	if current and is_instance_valid(current):
		current.call("stop")
