# File: res://scripts/story/StoryNightEvents.gd
# Night scares in story free roam (spec H-D7): StoryRoam adds one as its child. From Day 1 on, at night (FreeRoam's time of
# day "night"), never during a mission, a cinematic, a call / video / beat run, while wanted (stars or a busted / service
# state), with the story phone open or with the map open, at most one event every
# GAP_S (3 min; through a ScareDirector's fake-out budget with fake_gap_s = GAP_S), seeded picks:
#   figure  a sheep-masked figure stands still under a lamp post 42-58 m ahead in view; it vanishes when the player comes
#           within VANISH_M (25 m), when it has been out of view for UNSEEN_S, or after FIGURE_MAX_S;
#   photo   "Số lạ" texts a photo of the player from behind: PHOTO_TEXT (StoryDirector.add_text: the phone buzz and the
#           toast come from StoryRoam), at most once per story day (flag night_photo_d<day>);
#   clone   rarely (CLONE_W), only while riding: a masked clone sprints across the road in the bike's headlight.
# "Giảm hù dọa": no sting on the figure or the clone, quieter cues (ScareDirector.reduce_scares).
# Distances and spawns go by _focus(): the bike while riding (the player node stays parked where they got on), else the
# player. Coming back from something that blocked them (a mission, a cinematic, daylight), the next event is at least
# REENTRY_S away. The figure's lamp post and the headlight clone stand on free spots only.
# Cost: a check every CHECK_S, the figure's view test at 10 Hz while it stands. Nothing persists but the photo flag/text.
# Tests: advance(dt) with auto_tick false; dry_run records the picked events in `fired` without spawning anything.
class_name StoryNightEvents
extends Node

signal event_fired(kind: String)

const GAP_S: float = 180.0
const FIRST_S: Vector2 = Vector2(45.0, 90.0)
const CHECK_S: float = 0.5
const VANISH_M: float = 25.0
const UNSEEN_S: float = 0.6
const FIGURE_MAX_S: float = 40.0
const FIGURE_DIST: Array[float] = [50.0, 44.0, 56.0, 48.0]
const CLONE_W: float = 0.2
const CLONE_SPEED: float = 7.0
const CLONE_S: float = 2.2
const REENTRY_S: float = 30.0
const PHOTO_FROM: String = "Số lạ"
const PHOTO_TEXT: String = "[Ảnh chụp từ sau lưng bạn] Đẹp đấy {name}."

var roam: Node = null
var story: Node = null
var director: Node = null
var scare: ScareDirector
var auto_tick: bool = true
var dry_run: bool = false
var rng := RandomNumberGenerator.new()
## Seconds of eligible night since the last event (starts so the first one comes FIRST_S into the night).
var since: float = 0.0
var events: int = 0
var fired: Array[String] = []
var figure: Node3D = null
var crossing: Node3D = null
var _check_t: float = 0.0
var _figure_t: float = 0.0
var _unseen_t: float = 0.0
var _view_t: float = 0.0
var _seen_once: bool = false
var _cross_dir: Vector3 = Vector3.ZERO
var _cross_t: float = 0.0
var _was_eligible: bool = true


func _init() -> void:
	name = "NightEvents"


## roam = FreeRoam (player, tod_preset, cine_player, mounted, bike, wanted, find_free_spot), story = StoryRoam (mission_node,
## busy, running), director = StoryDirector (default the autoload).
func setup(r: Node, s: Node, d: Node = null, seed_val: int = -1) -> void:
	roam = r
	story = s
	director = d if d != null else StoryUtil.director()
	rng.seed = seed_val if seed_val >= 0 else randi()
	since = GAP_S - rng.randf_range(FIRST_S.x, FIRST_S.y)
	scare = ScareDirector.new()
	scare.auto_clock = false   # advance() drives its clock
	scare.loops_enabled = false
	scare.flicker_enabled = false
	scare.fake_budget = 1 << 20
	scare.fake_gap_s = GAP_S
	scare.reduce_scares = StoryUtil.reduce_scares()
	add_child(scare)


## Story night free roam with nothing else going on.
func eligible() -> bool:
	if roam == null or director == null or not bool(director.get("active")) or int(director.get("day")) < 1:
		return false
	if String(roam.get("tod_preset")) != "night" or roam.get("cine_player") != null:
		return false
	if story != null:
		if story.get("mission_node") != null or bool(story.get("busy")) or String(story.get("running")) != "":
			return false
	var w: Variant = roam.get("wanted")
	if w != null and is_instance_valid(w) and (String((w as Object).get("state")) != "free" or int((w as Object).get("stars")) > 0):
		return false
	var ph: Variant = story.get("phone") if story != null else null
	if ph != null and is_instance_valid(ph) and (ph as Object).has_method("is_open") and bool((ph as Object).call("is_open")):
		return false
	var mo: Variant = roam.get("map_overlay")
	if mo != null and is_instance_valid(mo) and bool((mo as Object).get("visible")):
		return false
	return true


func advance(dt: float) -> void:
	scare.clock += dt
	_update_figure(dt)
	_update_crossing(dt)
	if not eligible():
		_clear()   # a mission, a cinematic, daylight: nothing stays out there
		_was_eligible = false
		return
	if not _was_eligible:
		_was_eligible = true
		since = minf(since, GAP_S - REENTRY_S)   # never right after a mission or a cinematic ends
	since += dt
	_check_t -= dt
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	if since < GAP_S or figure != null or crossing != null:
		return
	var kind: String = pick()
	if kind == "":
		return
	if not scare.try_fake_out(kind):
		return
	if not dry_run and not _start(kind):
		scare.fake_count -= 1   # nothing could be placed: try again a little later
		scare.last_fake_t = -INF
		since = GAP_S - 15.0
		return
	since = -rng.randf_range(0.0, 60.0)   # the next one comes 3-4 minutes later
	events += 1
	fired.append(kind)
	event_fired.emit(kind)


## The event to try now ("" = none possible).
func pick() -> String:
	var riding: bool = roam != null and bool(roam.get("mounted"))
	var photo_ok: bool = director != null and not bool((director.get("flags") as Dictionary).get(photo_flag(), false))
	if riding and rng.randf() < CLONE_W:
		return "clone"
	if photo_ok and rng.randf() < 0.45:
		return "photo"
	return "figure"


func photo_flag() -> String:
	return "night_photo_d%d" % int(director.get("day")) if director != null else "night_photo"


func _start(kind: String) -> bool:
	match kind:
		"photo":
			(director.get("flags") as Dictionary)[photo_flag()] = true
			director.call("add_text", PHOTO_FROM, PHOTO_TEXT)
			return true
		"figure":
			return _spawn_figure()
		"clone":
			return _spawn_crossing()
	return false


func _player() -> Node3D:
	return roam.get("player") as Node3D if roam != null else null


## Where the player is now: the bike while riding (the player node stays where they got on), else the player.
func _focus() -> Node3D:
	if roam != null and bool(roam.get("mounted")):
		var b: Node3D = roam.get("bike") as Node3D
		if b != null and b.is_inside_tree():
			return b
	return _player()


## A free spot at p (FreeRoam.free_spot_at) or null; p itself without a roam that can tell.
func _free_at(p: Vector3) -> Variant:
	if roam != null and roam.has_method("free_spot_at"):
		return roam.call("free_spot_at", p, p.y)
	return p


func _camera() -> Camera3D:
	return roam.get_viewport().get_camera_3d() if roam != null and roam.is_inside_tree() else null


# ---------------------------------------------------------------------------
# The far figure
# ---------------------------------------------------------------------------
## true when the figure should go: the player within VANISH_M, out of view for UNSEEN_S, or standing FIGURE_MAX_S.
static func figure_should_vanish(dist: float, unseen_s: float, alive_s: float) -> bool:
	return dist <= VANISH_M or unseen_s >= UNSEEN_S or alive_s >= FIGURE_MAX_S


func _spawn_figure() -> bool:
	var cam: Camera3D = _camera()
	var p: Node3D = _focus()
	if cam == null or p == null:
		return false
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return false
	fwd = fwd.normalized()
	for k: int in FIGURE_DIST.size():
		var ang: float = [0.0, 0.18, -0.18, 0.0][k]
		var dir: Vector3 = fwd.rotated(Vector3.UP, ang)
		var want: Vector3 = p.global_position + dir * FIGURE_DIST[k]
		var spot: Variant = roam.call("find_free_spot", want, p.global_position.y, 4) if roam.has_method("find_free_spot") else want
		if not (spot is Vector3):
			continue
		var at: Vector3 = spot
		if not cam.is_position_in_frustum(at + Vector3(0.0, 1.2, 0.0)) or not _line_clear(cam.global_position, at + Vector3(0.0, 1.4, 0.0)):
			continue
		figure = Node3D.new()
		figure.name = "NightFigure"
		roam.add_child(figure)
		figure.global_position = at
		var body: Node3D = StoryCast.build("clone_masked")
		if body != null:
			figure.add_child(body)
			CharacterBuilder.set_speed(body, 0.0)
		figure.rotation.y = atan2(p.global_position.x - at.x, p.global_position.z - at.z) + PI   # faces the player (-Z)
		for side: float in [1.3, -1.3]:   # the lamp post on a free spot beside the figure (no lamp when neither side is free)
			var lp: Vector3 = figure.global_transform * Vector3(side, 0.0, 0.0)
			if _free_at(lp) is Vector3:
				var lamp := Node3D.new()
				lamp.name = "Lamp"
				figure.add_child(lamp)
				PropBuilder.build_lamp_post(lamp, Vector3(side, 0.0, 0.0), 6.5, false, PI if side > 0.0 else 0.0)
				break
		_light_pool(figure)
		_figure_t = 0.0
		_unseen_t = 0.0
		_seen_once = false
		if not scare.reduce_scares:
			scare.play_cue("whisper_bed", -16.0)
		return true
	return false


## A soft pool of lamp light on the ground under the figure (unshaded, no light node).
func _light_pool(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.6
	cm.bottom_radius = 2.6
	cm.height = 0.02
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.92, 0.7, 0.16)
	mi.material_override = m
	mi.position = Vector3(0.4, 0.03, 0.0)
	parent.add_child(mi)


func _line_clear(a: Vector3, b: Vector3) -> bool:
	if roam == null or not roam.is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(a, b)
	var pl: Node3D = _player()
	if pl is CollisionObject3D:
		q.exclude = [(pl as CollisionObject3D).get_rid()]
	return (roam as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _update_figure(dt: float) -> void:
	if figure == null:
		return
	if not is_instance_valid(figure):
		figure = null
		return
	_figure_t += dt
	_view_t -= dt
	if _view_t > 0.0:
		return
	_view_t = 0.1
	var p: Node3D = _focus()
	var cam: Camera3D = _camera()
	var dist: float = INF
	if p != null:
		dist = Vector2(p.global_position.x - figure.global_position.x, p.global_position.z - figure.global_position.z).length()
	var in_view: bool = cam != null and cam.is_position_in_frustum(figure.global_position + Vector3(0.0, 1.2, 0.0))
	if in_view:
		_seen_once = true
		_unseen_t = 0.0
	else:
		_unseen_t += 0.1
	if figure_should_vanish(dist, _unseen_t, _figure_t):
		figure.queue_free()
		figure = null


# ---------------------------------------------------------------------------
# The clone in the headlight
# ---------------------------------------------------------------------------
func _spawn_crossing() -> bool:
	var bike: Node3D = roam.get("bike") as Node3D
	if bike == null or not bike.is_inside_tree():
		return false
	var fwd: Vector3 = -bike.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		return false
	fwd = fwd.normalized()
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var found: Variant = null
	for sd: float in [side, -side]:   # starts on a free spot at the roadside, else nothing
		found = _free_at(bike.global_position + fwd * 16.0 + right * sd * 6.0)
		if found is Vector3:
			side = sd
			break
	if not (found is Vector3):
		return false
	var at: Vector3 = found
	crossing = Node3D.new()
	crossing.name = "NightClone"
	roam.add_child(crossing)
	crossing.global_position = at
	var body: Node3D = StoryCast.build("clone_masked")
	if body != null:
		crossing.add_child(body)
		CharacterBuilder.set_speed(body, CLONE_SPEED)
	_cross_dir = -right * side
	crossing.rotation.y = atan2(-_cross_dir.x, -_cross_dir.z)
	_cross_t = CLONE_S
	if not scare.reduce_scares:
		scare.fake_sting(-12.0)
	return true


func _update_crossing(dt: float) -> void:
	if crossing == null:
		return
	if not is_instance_valid(crossing):
		crossing = null
		return
	crossing.global_position += _cross_dir * CLONE_SPEED * dt
	_cross_t -= dt
	if _cross_t <= 0.0:
		crossing.queue_free()
		crossing = null


func _clear_props() -> void:
	for n: Node3D in [figure, crossing]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	figure = null
	crossing = null


func _clear() -> void:
	if figure != null or crossing != null:
		_clear_props()


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


func _exit_tree() -> void:
	_clear_props()
