# File: res://scripts/roam/RandomScares.gd
# Random jump scares in free roam (owner request), story mode (Day 1 on: the cult is watching) and free play ("Khám phá
# campus"). FreeRoam creates one in both modes; GameFX.random_scares ("Hù dọa ngẫu nhiên", main-menu and pause settings,
# default on) switches it off. One scheduler on play time (clock: only while it is allowed to run):
#   big scares   none in the first FIRST_S; then every BIG_GAP (10-20 min; at least 10 min apart). When one is due it waits
#                (up to CALM_WAIT_MAX) for a calm moment: still or walking slowly with no hostiles, just after a story step
#                (a mission won), near the BE6 lobby, reading the phone, a still camera; riding at night counts for the
#                pillion scare. Then a BUILD-UP (the music dips, the heartbeat starts, a streetlight-like flicker of the
#                screen edge) of BUILD_S; about FAKE_RATE of build-ups are fake (nothing happens). By day a due scare only
#                goes ahead DAY_CHANCE of the time. Never the same kind twice in a row.
#                  pillion    riding at night: a sheep sits on the pillion seat behind the rider
#                  head_turn  a crowd pedestrian walking past turns their head 180 degrees into a sheep face and lunges,
#                             then is gone (restored afterwards)
#                  phone      (story) opening the phone [P]: the screen fills with a sheep face pressed close, then the phone
#                  edge_face  after standing still a while, turning the camera: a sheep face snaps in right at the screen
#                  All with jump scare v2 (the duck, the inhale, the snap, the flash, the overlay, the shake, the +8 dB sting).
#   small scares every SMALL_GAP (3-5 min), no sting, a subtle sound only: a 2-frame subliminal sheep face; a masked figure
#                in the crowd staring (gone when approached or looked away); a 1 s HUD text glitch "MÀY CÒN N NGÀY" (story)
#                / "TAO THẤY MÀY" (free play); a red radar blip rushing at the player.
#   never        during a mission, a cinematic or replay (or the tree paused: menus), wanted or busted or community
#                service, the map open, story Day 0; within SHARED_GAP_S of a story night event (shared_ok / mark_shared,
#                StoryNightEvents does the same). The old stages and the Night Building are other scenes (no FreeRoam).
#   "Giảm hù dọa" big scares off; small ones gentler.
# Tests: auto_tick false + advance(dt); dry_run logs the picks without visuals; force_available limits the kinds.
class_name RandomScares
extends Node

signal fired(kind: String, big: bool)

const FIRST_S: float = 210.0
const BIG_GAP := Vector2(600.0, 1200.0)
const SMALL_GAP := Vector2(180.0, 300.0)
const CALM_WAIT_MAX: float = 120.0
const BUILD_S := Vector2(3.0, 5.0)
const FAKE_RATE: float = 1.0 / 3.0
const DAY_CHANCE: float = 0.3
const DAY_RETRY := Vector2(300.0, 600.0)
const ARM_S: float = 60.0
const STILL_S: float = 15.0
const SHARED_GAP_S: float = 60.0
const BIG_KINDS: Array[String] = ["pillion", "head_turn", "phone", "edge_face"]
const SMALL_KINDS: Array[String] = ["subliminal", "crowd_stare", "hud_glitch", "radar_blip"]
const T_GLITCH_FREE: String = "TAO THẤY MÀY"
const T_GLITCH_STORY: String = "MÀY CÒN %d NGÀY"

static var last_any_msec: int = -100000000
## The shared gap with the story night events (tests set 0: the fake clock does not move the wall clock).
static var shared_gap_s: float = SHARED_GAP_S

var roam: Node = null
var director: Node = null
var auto_tick: bool = true
var dry_run: bool = false
var force_available: Array = []
var rng := RandomNumberGenerator.new()
var clock: float = 0.0
var big_next_t: float = 0.0
var small_next_t: float = 0.0
## idle | wait_calm | build | armed | play
var state: String = "idle"
var last_big: String = ""
var last_small: String = ""
var big_count: int = 0
var small_count: int = 0
var build_count: int = 0
var fake_count: int = 0
## Tests: "big:<kind>@t", "small:<kind>@t", "build@t", "fake@t", "due@t".
var log: Array[String] = []
var scare: ScareDirector = null
var calm_boost_t: float = 0.0
var pending: String = ""
var _wait_t: float = 0.0
var _build_t: float = 0.0
var _build_fake: bool = false
var _arm_t: float = 0.0
var _still_t: float = 0.0
var _yaws: Array[Vector2] = []
var _music_db0: float = INF
## The running visual: kind, time, nodes to clean up.
var active: String = ""
var _t: float = 0.0
var _layer: CanvasLayer = null
var _face_tex: ImageTexture = null
var _img: TextureRect = null
var _glitch: Label = null
var figure: Node3D = null
var _ped: Node3D = null
var _ped_xf: Transform3D
var _ped_mode: int = 0
var _mask: Node3D = null
var _blip: Dictionary = {}


func _init() -> void:
	name = "RandomScares"


func setup(r: Node, d: Node = null, seed_val: int = -1) -> void:
	roam = r
	director = d if d != null else StoryUtil.director()
	rng.seed = seed_val if seed_val >= 0 else randi()
	clock = 0.0
	big_next_t = FIRST_S + rng.randf_range(0.0, 60.0)
	small_next_t = FIRST_S + rng.randf_range(0.0, 60.0)
	scare = ScareDirector.new()
	scare.loops_enabled = false
	scare.flicker_enabled = false
	scare.auto_clock = false
	scare.reduce_scares = StoryUtil.reduce_scares()
	add_child(scare)
	if director != null and director.has_signal("step_changed"):
		director.connect("step_changed", _on_step)
	var ph: Variant = _story_phone()
	if ph != null and (ph as Object).has_signal("opened_changed"):
		(ph as Object).connect("opened_changed", _on_phone)


func _on_step(_s: String) -> void:
	calm_boost_t = 60.0   # just after a story step (a mission won): a calm moment


static func shared_ok() -> bool:
	return Time.get_ticks_msec() - last_any_msec >= int(shared_gap_s * 1000.0)


static func mark_shared() -> void:
	last_any_msec = Time.get_ticks_msec()


# ---------------------------------------------------------------------------
# Conditions
# ---------------------------------------------------------------------------
## The setting and the mode: GameFX.random_scares on; story mode only from Day 1.
func enabled() -> bool:
	var fx: Node = StoryUtil._root_node("GameFX")
	if fx != null and not bool(fx.get("random_scares")):
		return false
	if director != null and bool(director.get("active")) and int(director.get("day")) < 1:
		return false
	return true


func _story() -> Node:
	return roam.get("story_roam") as Node if roam != null else null


func _story_phone() -> Variant:
	var st: Node = _story()
	return st.get("phone") if st != null else null


func phone_open() -> bool:
	var ph: Variant = _story_phone()
	return ph != null and is_instance_valid(ph) and bool((ph as Object).call("is_open"))


## Nothing now: a mission, a cinematic / replay, wanted / busted / service, the map, a paused tree (menus).
func blocked() -> bool:
	if roam == null:
		return true
	if roam.get("cine_player") != null:
		return true
	var sm: Node = StoryUtil._root_node("StageManager")
	if sm != null and bool(sm.get("cinematic_active")):
		return true
	if is_inside_tree() and get_tree().paused:
		return true
	var w: Variant = roam.get("wanted")
	if w != null and is_instance_valid(w) and (String((w as Object).get("state")) != "free" or int((w as Object).get("stars")) > 0):
		return true
	var mo: Variant = roam.get("map_overlay")
	if mo != null and is_instance_valid(mo) and bool((mo as Object).get("visible")):
		return true
	var st: Node = _story()
	if st != null and (st.get("mission_node") != null or bool(st.get("busy")) or String(st.get("running")) != ""):
		return true
	return false


func night() -> bool:
	return roam != null and String(roam.get("tod_preset")) in ["night", "sunset"]


func _player() -> Node3D:
	return roam.get("player") as Node3D if roam != null else null


func _speed() -> float:
	var p: Node3D = _player()
	if p == null:
		return 0.0
	if bool(roam.get("mounted")):
		var b: Node3D = roam.get("bike") as Node3D
		return absf(float(b.get("current_speed_ms"))) if b != null else 0.0
	return float(p.get("horizontal_speed")) if p.get("horizontal_speed") != null else 0.0


func _near_lobby() -> bool:
	var p: Node3D = _player()
	var md: Variant = roam.get("md")
	if p == null or md == null:
		return false
	var o: Vector3 = (md as Object).call("spawn_transform").origin
	return Vector2(p.global_position.x - o.x, p.global_position.z - o.z).length() < 10.0


## A calm moment: still or walking slowly with no hostiles, just after a story step, near the BE6 lobby, reading the
## phone, a still camera; riding at night (the pillion scare).
func calm() -> bool:
	if calm_boost_t > 0.0 or phone_open():
		return true
	if bool(roam.get("mounted")):
		return night()
	return _speed() < 1.8 or _near_lobby() or _still_t >= 3.0


func kind_available(kind: String) -> bool:
	if not force_available.is_empty():
		return kind in force_available
	match kind:
		"pillion":
			return bool(roam.get("mounted")) and night() and roam.get("bike") != null
		"head_turn":
			return not bool(roam.get("mounted")) and _pick_ped() != null
		"phone":
			return _story_phone() != null
		"edge_face":
			return not bool(roam.get("mounted"))
		"radar_blip":
			return roam.get("vice_hud") != null
		"crowd_stare", "subliminal", "hud_glitch":
			return true
	return false


# ---------------------------------------------------------------------------
# Scheduler
# ---------------------------------------------------------------------------
func advance(dt: float) -> void:
	_update_active(dt)
	if not enabled():
		_cancel_build()
		return
	if blocked():
		_cancel_build()
		return
	clock += dt
	calm_boost_t = maxf(0.0, calm_boost_t - dt)
	_track_still(dt)
	if active != "":
		return
	if state == "armed":
		_arm_t -= dt
		if _armed_trigger():
			_play_big(pending)
		elif _arm_t <= 0.0:
			state = "idle"
			big_next_t = clock + rng.randf_range(60.0, 180.0)   # its moment never came: try again a little later
		return
	if clock >= small_next_t and state in ["idle", "wait_calm"] and shared_ok():
		_fire_small()
	if scare.reduce_scares:
		return   # no big scares, no build-ups
	match state:
		"idle":
			if clock >= big_next_t:
				if not night() and rng.randf() >= DAY_CHANCE:
					big_next_t = clock + rng.randf_range(DAY_RETRY.x, DAY_RETRY.y)   # by day it is rare
					return
				state = "wait_calm"
				_wait_t = 0.0
				log.append("due@%.1f" % clock)
		"wait_calm":
			_wait_t += dt
			if (calm() or _wait_t >= CALM_WAIT_MAX) and shared_ok():
				_start_build()
		"build":
			_build_t -= dt
			_update_build()
			if _build_t <= 0.0:
				_end_build()


func _start_build() -> void:
	state = "build"
	build_count += 1
	_build_t = rng.randf_range(BUILD_S.x, BUILD_S.y)
	_build_fake = rng.randf() < FAKE_RATE
	log.append("build@%.1f" % clock)
	if dry_run:
		return
	var mb: int = AudioServer.get_bus_index("Music")
	_music_db0 = AudioServer.get_bus_volume_db(mb) if mb != -1 else INF


func _update_build() -> void:
	if dry_run:
		return
	var k: float = 1.0 - clampf(_build_t / BUILD_S.y, 0.0, 1.0)
	scare.set_threat(lerpf(13.0, 3.0, k), false)   # the heartbeat starts and speeds up
	scare.tick_heart(get_process_delta_time())
	var mb: int = AudioServer.get_bus_index("Music")
	if mb != -1 and _music_db0 < INF:
		AudioServer.set_bus_volume_db(mb, _music_db0 - 10.0 * k)   # the music dips
	scare.edge_a = 0.25 * k * (0.6 + 0.4 * sin(clock * 21.0))       # the screen edge flickers like a failing lamp
	scare.hidden = true


func _restore_build() -> void:
	scare.set_threat(INF, false)
	scare.edge_a = 0.0
	scare.hidden = false
	var mb: int = AudioServer.get_bus_index("Music")
	if mb != -1 and _music_db0 < INF:
		AudioServer.set_bus_volume_db(mb, _music_db0)
	_music_db0 = INF


func _cancel_build() -> void:
	if state == "build":
		if not dry_run:
			_restore_build()
		state = "wait_calm"


func _end_build() -> void:
	if not dry_run:
		_restore_build()
	if _build_fake:
		fake_count += 1
		log.append("fake@%.1f" % clock)
		state = "idle"
		big_next_t = clock + rng.randf_range(90.0, 240.0)   # a fake build-up is not a big scare
		return
	var kinds: Array[String] = []
	for k: String in BIG_KINDS:
		if k != last_big and kind_available(k):
			kinds.append(k)
	if kinds.is_empty():
		state = "idle"
		big_next_t = clock + rng.randf_range(60.0, 180.0)
		return
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	if kind in ["phone", "edge_face"] and not dry_run:
		pending = kind
		state = "armed"
		_arm_t = ARM_S
		return
	_play_big(kind)


func _armed_trigger() -> bool:
	match pending:
		"phone":
			return phone_open()
		"edge_face":
			return _still_t >= STILL_S and _turned()
	return false


func _track_still(dt: float) -> void:
	if _speed() < 0.3:
		_still_t += dt
	else:
		_still_t = 0.0
	var cam: Camera3D = roam.get_viewport().get_camera_3d() if roam != null and roam.is_inside_tree() else null
	if cam != null:
		var f: Vector3 = -cam.global_transform.basis.z
		_yaws.append(Vector2(clock, atan2(-f.x, -f.z)))
		while not _yaws.is_empty() and clock - _yaws[0].x > 0.5:
			_yaws.remove_at(0)


func _turned() -> bool:
	if _yaws.size() < 2:
		return false
	var now: float = _yaws.back().y
	for v: Vector2 in _yaws:
		if absf(wrapf(now - v.y, -PI, PI)) > deg_to_rad(60.0):
			return true
	return false


func _play_big(kind: String) -> void:
	state = "idle"
	pending = ""
	last_big = kind
	big_count += 1
	big_next_t = clock + rng.randf_range(BIG_GAP.x, BIG_GAP.y)
	log.append("big:%s@%.1f" % [kind, clock])
	mark_shared()
	fired.emit(kind, true)
	if not dry_run:
		_start_visual(kind)


func _fire_small() -> void:
	var kinds: Array[String] = []
	for k: String in SMALL_KINDS:
		if k != last_small and kind_available(k):
			kinds.append(k)
	small_next_t = clock + rng.randf_range(SMALL_GAP.x, SMALL_GAP.y)
	if kinds.is_empty():
		return
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	last_small = kind
	small_count += 1
	log.append("small:%s@%.1f" % [kind, clock])
	fired.emit(kind, false)
	if not dry_run:
		_start_visual(kind)


## Plays a scare now (tests and the scheduler): big or small kind.
func play(kind: String) -> void:
	if kind in BIG_KINDS:
		last_big = kind
		_start_visual(kind)
	else:
		last_small = kind
		_start_visual(kind)


## Arms a waiting big scare (tests): phone / edge_face.
func arm(kind: String) -> void:
	pending = kind
	state = "armed"
	_arm_t = ARM_S


# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------
func _ensure_layer() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "RandomScareLayer"
	_layer.layer = 35
	add_child(_layer)


## A sheep face pressed close, drawn in code once (128 x 128): pale cracked wool, black hollow eyes, red pupils, a mouth gap.
func face_texture() -> ImageTexture:
	if _face_tex != null:
		return _face_tex
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for y: int in 128:
		for x: int in 128:
			var dx: float = (float(x) - 64.0) / 52.0
			var dy: float = (float(y) - 66.0) / 60.0
			var d: float = dx * dx + dy * dy
			var c := Color(0.0, 0.0, 0.0, 0.0)
			if d < 1.0:
				var v: float = 0.72 + r.randf_range(-0.1, 0.06) - 0.25 * d
				c = Color(v, v * 0.96, v * 0.88, 1.0)
				for ex: float in [-20.0, 20.0]:
					var e: float = Vector2(float(x) - 64.0 - ex, (float(y) - 56.0) * 1.3).length()
					if e < 11.0:
						c = Color(0.02, 0.01, 0.01, 1.0)
					if e < 2.5:
						c = Color(1.0, 0.1, 0.05, 1.0)
				if absf(float(x) - 64.0) < 9.0 and absf(float(y) - 94.0) < 3.0:
					c = Color(0.03, 0.02, 0.02, 1.0)
			img.set_pixel(x, y, c)
	_face_tex = ImageTexture.create_from_image(img)
	return _face_tex


func _fullscreen_face(alpha: float) -> TextureRect:
	_ensure_layer()
	var t := TextureRect.new()
	t.name = "SheepFace"
	t.texture = face_texture()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate.a = alpha
	t.pivot_offset = Vector2(576.0, 324.0)
	_layer.add_child(t)
	return t


func _build_figure() -> Node3D:
	if figure != null and is_instance_valid(figure):
		return figure
	figure = StoryCast.build("clone")
	figure.name = "RandomScareFigure"
	var head: Node3D = CharacterBuilder.get_pivot(figure, "head")
	var m: Node3D = ScareFace.build_scare_mask()
	if head != null:
		head.add_child(m)
		var hs: float = maxf(head.scale.y, 0.01)
		m.position = Vector3(0.0, 0.1 / hs, 0.0)
		m.scale = Vector3.ONE / hs * 1.05
	return figure


func _pick_ped() -> Node3D:
	var sp: Variant = roam.get("pedestrians")
	var p: Node3D = _player()
	if sp == null or not is_instance_valid(sp) or p == null:
		return null
	var cam: Camera3D = roam.get_viewport().get_camera_3d() if roam.is_inside_tree() else null
	var best: Node3D = null
	var bd: float = INF
	for ped: Variant in (sp as Object).call("pedestrians"):
		var n: Node3D = ped as Node3D
		if n == null or not is_instance_valid(n) or not n.visible:
			continue
		var d: float = n.global_position.distance_to(p.global_position)
		if d < 3.0 or d > 12.0:
			continue
		if cam != null and not cam.is_position_in_frustum(n.global_position + Vector3(0.0, 1.5, 0.0)):
			continue
		if d < bd:
			bd = d
			best = n
	return best


func _start_visual(kind: String) -> void:
	_end_visual()
	active = kind
	_t = 0.0
	var soft: bool = scare.reduce_scares
	match kind:
		"pillion":
			scare.event_duck(true)
		"head_turn":
			_ped = _pick_ped()
			if _ped == null:
				active = ""
				return
			_ped_xf = _ped.global_transform
			_ped_mode = _ped.process_mode
			scare.event_duck(true)
		"phone":
			scare.event_duck(true)
		"edge_face":
			scare.play_face_scare("open", "jump", false)
		"subliminal":
			_img = _fullscreen_face(0.25 if soft else 0.6)
			scare.play_cue("whisper_bed", -20.0)
		"crowd_stare":
			if not _place_stare():
				active = ""
		"hud_glitch":
			_ensure_layer()
			_glitch = Label.new()
			_glitch.name = "HudGlitch"
			var days: int = int(director.call("days_left")) if director != null and bool(director.get("active")) else -1
			_glitch.text = T_GLITCH_STORY % days if days >= 0 else T_GLITCH_FREE
			_glitch.add_theme_font_size_override("font_size", 34)
			_glitch.add_theme_color_override("font_color", Color("#FF2A1E"))
			_glitch.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
			_glitch.add_theme_constant_override("outline_size", 6)
			_glitch.set_anchors_preset(Control.PRESET_CENTER_TOP)
			_glitch.position = Vector2(-180.0, 90.0)
			_glitch.size = Vector2(360.0, 48.0)
			_glitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_layer.add_child(_glitch)
			scare.play_cue("static_burst", -24.0 if soft else -18.0)
		"radar_blip":
			var p: Node3D = _player()
			var a: float = rng.randf_range(0.0, TAU)
			_blip = {"from": Vector2(p.global_position.x, p.global_position.z) + Vector2(cos(a), sin(a)) * 120.0}


func _place_stare() -> bool:
	var p: Node3D = _player()
	var cam: Camera3D = roam.get_viewport().get_camera_3d() if roam.is_inside_tree() else null
	if p == null or cam == null:
		return false
	var f: Vector3 = -cam.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var want: Vector3 = p.global_position + f * rng.randf_range(20.0, 28.0)
	var spot: Variant = roam.call("find_free_spot", want, p.global_position.y, 4) if roam.has_method("find_free_spot") else want
	if not (spot is Vector3):
		return false
	var fig: Node3D = _build_figure()
	if fig.get_parent() == null:
		roam.add_child(fig)
	fig.global_position = spot
	var d: Vector3 = p.global_position - fig.global_position
	fig.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	CharacterBuilder.set_speed(fig, 0.0)
	fig.visible = true
	return true


## Radar blips for FreeRoam (the red blip rushing at the player).
func blips() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if active == "radar_blip" and not _blip.is_empty():
		var p: Node3D = _player()
		var to := Vector2(p.global_position.x, p.global_position.z)
		out.append({"pos": (_blip["from"] as Vector2).lerp(to, clampf(_t / 1.5, 0.0, 1.0)), "color": Color("#FF1A12"), "shape": "circle"})
	return out


func _update_active(dt: float) -> void:
	if active == "":
		return
	_t += dt
	var d: float = ScareDirector.DUCK_S
	var soft: bool = scare.reduce_scares
	match active:
		"pillion":
			var bike: Node3D = roam.get("bike") as Node3D
			if _t >= d and (figure == null or not figure.visible):
				var fig: Node3D = _build_figure()
				if fig.get_parent() != bike:
					if fig.get_parent() != null:
						fig.get_parent().remove_child(fig)
					bike.add_child(fig)
				fig.position = Vector3(0.0, 0.35, 0.62)
				fig.rotation = Vector3.ZERO
				fig.scale = Vector3.ONE * 0.01
				CharacterBuilder.set_speed(fig, 0.0)
				fig.visible = true
				scare.loud_sting()
				scare.screen_hit()
			if figure != null and figure.visible:
				figure.scale = Vector3.ONE * minf(1.0, ScareFace._ease_out_back(clampf((_t - d) / 0.1, 0.0, 1.0)))
			if _t >= d + 1.6:
				_end_visual()
		"head_turn":
			if _ped == null or not is_instance_valid(_ped):
				_end_visual()
				return
			if _t >= d and _mask == null:
				_ped.process_mode = Node.PROCESS_MODE_DISABLED
				var head: Node3D = CharacterBuilder.get_pivot(_ped.get("model") if _ped.get("model") != null else _ped, "head")
				_mask = ScareFace.build_scare_mask()
				_mask.name = "TurnedHead"
				if head != null:
					head.add_child(_mask)
					var hs: float = maxf(head.scale.y, 0.01)
					_mask.position = Vector3(0.0, 0.1 / hs, 0.0)
					_mask.scale = Vector3.ONE / hs * 1.1
					_mask.rotation = Vector3(0.0, PI, 0.0)   # the head turned round: the face where the back of the head was
				else:
					_ped.add_child(_mask)
					_mask.position = Vector3(0.0, 1.6, 0.0)
				scare.loud_sting()
				scare.screen_hit()
			if _mask != null and _t < d + 0.15:
				var p: Node3D = _player()
				var to: Vector3 = p.global_position - _ped_xf.origin
				to.y = 0.0
				_ped.global_position = _ped_xf.origin + to.normalized() * clampf(to.length() - 1.2, 0.0, 1.5) * clampf((_t - d) / 0.15, 0.0, 1.0)
			if _t >= d + 0.7 and _ped.visible:
				_ped.visible = false   # gone
			if _t >= d + 2.0:
				_end_visual()
		"phone":
			if _t >= d and _img == null:
				_img = _fullscreen_face(1.0)
				scare.loud_sting()
				scare.screen_hit()
			if _img != null:
				_img.scale = Vector2.ONE * (0.6 + 0.6 * ScareFace._ease_out_back(clampf((_t - d) / 0.1, 0.0, 1.0)))
			if _t >= d + 0.7:
				_end_visual()
		"edge_face":
			if _t >= d + 2.0 or (_t > 0.1 and not scare.scare_busy()):
				_end_visual()
		"subliminal":
			if _t >= 2.0 / 60.0 + 1e-4:
				_end_visual()
		"crowd_stare":
			var p2: Node3D = _player()
			var cam: Camera3D = roam.get_viewport().get_camera_3d() if roam.is_inside_tree() else null
			var near: bool = p2 != null and figure != null and figure.global_position.distance_to(p2.global_position) < 12.0
			var unseen: bool = cam != null and figure != null and not cam.is_position_in_frustum(figure.global_position + Vector3(0.0, 1.2, 0.0))
			if near or (unseen and _t > 1.0) or _t >= 25.0:
				_end_visual()
		"hud_glitch":
			if _glitch != null:
				_glitch.position = Vector2(-180.0 + rng.randf_range(-6.0, 6.0), 90.0 + rng.randf_range(-3.0, 3.0))
				_glitch.modulate.a = 0.7 + 0.3 * float(int(_t * 30.0) % 2)
			if _t >= (0.8 if soft else 1.0):
				_end_visual()
		"radar_blip":
			if _t >= 1.6:
				_end_visual()


## Ends the running scare and cleans everything up (the pedestrian restored, the pillion sheep removed, the overlays gone).
func _end_visual() -> void:
	scare.event_duck(false)
	if _img != null and is_instance_valid(_img):
		_img.queue_free()
	_img = null
	if _glitch != null and is_instance_valid(_glitch):
		_glitch.queue_free()
	_glitch = null
	if figure != null and is_instance_valid(figure):
		figure.visible = false
		if figure.get_parent() != null:
			figure.get_parent().remove_child(figure)
	if _mask != null and is_instance_valid(_mask):
		_mask.queue_free()
	_mask = null
	if _ped != null and is_instance_valid(_ped):
		_ped.global_transform = _ped_xf
		_ped.process_mode = _ped_mode
		_ped.visible = true
	_ped = null
	_blip = {}
	active = ""


func cleanup() -> void:
	_end_visual()
	_cancel_build()


func _on_phone(open: bool) -> void:
	if open and state == "armed" and pending == "phone" and not blocked():
		_play_big("phone")


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


func _exit_tree() -> void:
	_end_visual()
	if figure != null and is_instance_valid(figure):
		figure.free()
	figure = null
