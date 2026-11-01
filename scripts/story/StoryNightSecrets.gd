# File: res://scripts/story/StoryNightSecrets.gd
# Night second chances at missed evidence (plan 2026-11-01-w4-endings.md T4). StoryRoam adds one as its child. At night in
# story free roam (StoryNightEvents.eligible: night, Day 1+, no mission / cinematic / beat run / police / phone / map), a
# spot with something to offer shows a faint green lantern and "Số lạ" texts a hint once per story day; walking or riding
# within NEAR_M of it plays its cinematic, then the evidence is added (StoryRoam toasts "Bằng chứng mới"), the spot is used
# for that day (flag night_<kind>_d<day>) and the story saves:
#   canal  the ghost boat at the Rạch Hầm bank (anchor bridge_bank), cine night_ghost_boat: the first missing of E3 (from
#          Day 3, the day after the bridge) or E4 (from Day 4, the day after the container yard);
#   lift   the BE6 lift that stops at floor 13 (anchor be6_lift, the far side of the BE6 front, away from every mission
#          marker), cine night_lift13: the first missing of E2 (from Day 2, the day after the locker) or E5 (from Day 5).
# A spot stays dark while the player stands at a story marker (StoryRoam.active_marker) or a story marker sits within
# NEAR_M + StoryRoam.MARKER_RADIUS of it, so a mission's [E] always comes first.
# Horror softened by "Giảm hù dọa" (the cinematics read it at build time: no scare hit, no whisper bed).
# Cost: one distance check every CHECK_S. Tests: advance(dt) with auto_tick false; play(kind) runs the hand-off directly.
class_name StoryNightSecrets
extends Node

signal secret_played(kind: String, evidence: String)

const CHECK_S: float = 0.5
const NEAR_M: float = 6.0
const HINT_FROM: String = "Số lạ"
const SPOTS: Dictionary = {
	"canal": {"anchor": "bridge_bank", "slot": "night_ghost_boat", "offers": [["E3", 3], ["E4", 4]],
		"hint": "Nửa đêm ra bờ kênh Rạch Hầm đi. Có con đò chở thứ mày đánh rơi."},
	"lift": {"anchor": "be6_lift", "slot": "night_lift13", "offers": [["E2", 2], ["E5", 5]],
		"hint": "Thang máy BE6 nửa đêm có dừng ở tầng 13. Ghé thử đi."},
}
const ORDER: Array[String] = ["canal", "lift"]

## roam = FreeRoam (player, bike, mounted, cinematic_finished), story = StoryRoam (anchors, busy, _start_cinematic,
## _free_cards), director = StoryDirector, events = the StoryNightEvents whose eligible() gates the night.
var roam: Node = null
var story: Node = null
var director: Node = null
var events: StoryNightEvents = null
var auto_tick: bool = true
## The kind whose cinematic plays now ("" = none).
var playing: String = ""
var markers: Dictionary = {}   # kind -> Node3D lantern
var played: Array[String] = []
var _check_t: float = 0.0
var _pending_ev: String = ""


func _init() -> void:
	name = "NightSecrets"


func setup(r: Node, s: Node, d: Node, ev: StoryNightEvents) -> void:
	roam = r
	story = s
	director = d
	events = ev


## The evidence `kind` would give now ("" = nothing: all found, too early, or used today).
func offer(kind: String) -> String:
	if director == null or not SPOTS.has(kind):
		return ""
	var day: int = int(director.get("day"))
	if bool((director.get("flags") as Dictionary).get(used_flag(kind), false)):
		return ""
	for o: Array in SPOTS[kind]["offers"]:
		if day >= int(o[1]) and not bool(director.call("has_evidence", String(o[0]))):
			return String(o[0])
	return ""


func used_flag(kind: String) -> String:
	return "night_%s_d%d" % [kind, int(director.get("day")) if director else 0]


func hint_flag(kind: String) -> String:
	return "night_%s_hint_d%d" % [kind, int(director.get("day")) if director else 0]


func eligible() -> bool:
	return playing == "" and events != null and events.eligible()


func spot_pos(kind: String) -> Variant:
	var an: Variant = story.get("anchors") if story else null
	if not (an is Dictionary):
		return null
	var a: Dictionary = (an as Dictionary).get(String(SPOTS[kind]["anchor"]), {})
	return a.get("pos") if a.get("pos") is Vector3 else null


func advance(dt: float) -> void:
	_check_t -= dt
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	var ok: bool = eligible() and not _at_story_marker()
	for kind: String in ORDER:
		var ev: String = offer(kind) if ok else ""
		var at: Variant = spot_pos(kind) if ev != "" else null
		if at != null and near_story_marker(at as Vector3):
			at = null
		if at == null:
			_marker(kind, null)
			continue
		_marker(kind, at)
		var fl: Dictionary = director.get("flags")
		if not bool(fl.get(hint_flag(kind), false)):
			fl[hint_flag(kind)] = true
			director.call("add_text", HINT_FROM, String(SPOTS[kind]["hint"]))
		var f: Node3D = events._focus() if events else null
		if f != null and f.is_inside_tree():
			var p: Vector3 = f.global_position
			var d: Vector2 = Vector2(p.x - (at as Vector3).x, p.z - (at as Vector3).z)
			if d.length() <= NEAR_M:
				play(kind)
				return


## The player stands at a story marker (its [E] prompt is up).
func _at_story_marker() -> bool:
	var am: Variant = story.get("active_marker") if story else null
	return am is String and am != ""


## A story marker (StoryRoam.marker_pos, map plane) close enough that the spot would fire before its [E].
func near_story_marker(at: Vector3) -> bool:
	var mp: Variant = story.get("marker_pos") if story else null
	if not (mp is Dictionary):
		return false
	var r: float = NEAR_M + StoryRoam.MARKER_RADIUS
	for p: Variant in (mp as Dictionary).values():
		if p is Vector2 and (p as Vector2).distance_to(Vector2(at.x, at.z)) <= r:
			return true
	return false


## Plays the spot's cinematic, then gives its evidence. false when nothing is offered or the cinematic cannot start.
func play(kind: String) -> bool:
	var ev: String = offer(kind)
	if ev == "" or playing != "" or story == null:
		return false
	_clear_markers()
	story.set("busy", true)
	var cp: Variant = story.call("_start_cinematic", String(SPOTS[kind]["slot"]), "")
	if cp == null:
		story.set("busy", false)
		return false
	playing = kind
	_pending_ev = ev
	roam.connect("cinematic_finished", _on_cine_done, CONNECT_ONE_SHOT)
	return true


func _on_cine_done(_slot: String, _skipped: bool) -> void:
	var kind: String = playing
	var ev: String = _pending_ev
	playing = ""
	_pending_ev = ""
	if story and story.has_method("_free_cards"):
		story.call("_free_cards")
	(director.get("flags") as Dictionary)[used_flag(kind)] = true
	director.call("add_evidence", ev)
	director.call("save_game")
	story.set("busy", false)
	played.append(kind)
	secret_played.emit(kind, ev)


## A faint green lantern floating over the spot (null removes it).
func _marker(kind: String, at: Variant) -> void:
	var old: Variant = markers.get(kind)
	var alive: bool = old != null and is_instance_valid(old)
	if at == null:
		if alive:
			(old as Node).queue_free()
		markers.erase(kind)
		return
	if alive or roam == null or not (roam is Node3D):
		return
	var m := Node3D.new()
	m.name = "NightSecret_" + kind
	var mesh := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.18
	sp.height = 0.46
	mesh.mesh = sp
	mesh.material_override = CineFX._glow_mat(Color("#7CFF9E"), 2.0)
	m.add_child(mesh)
	var l := OmniLight3D.new()
	l.light_color = Color("#7CFF9E")
	l.light_energy = 1.2
	l.omni_range = 6.0
	m.add_child(l)
	roam.add_child(m)
	m.global_position = (at as Vector3) + Vector3(0.0, 1.6, 0.0)
	markers[kind] = m


func _clear_markers() -> void:
	for k: String in markers.keys():
		var m: Variant = markers[k]
		if m != null and is_instance_valid(m):
			(m as Node).queue_free()
	markers.clear()


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


func _exit_tree() -> void:
	_clear_markers()
