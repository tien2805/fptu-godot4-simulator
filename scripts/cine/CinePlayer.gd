# File: res://scripts/cine/CinePlayer.gd
# Plays one CineTimeline (spec section 9): builds the actors (real game models) under a stage node placed at stage_xf, the
# props, a Camera3D, the overlay, the FX node (under the stage: CineFX works in its own local space = stage space) and the
# audio players; music (owner file or synthesized cue built on a worker thread) starts on the first frame; every frame:
# r (REAL, from Time.get_ticks_usec or step(dt), never Engine.time_scale, never clamped) -> s = clock.story_at(r) -> actors,
# story-time events (SFX, FX, prop glow), prop visibility (opts show_at / hide_at, a pure function of s), FX speed, camera
# (shot at real progress + whip / punch-in of ramps and timeline punches + handheld noise in story time when the shot has
# "hand"), overlay (letterbox, fades, subtitle at r, skip bar, debug), music gain. Ends at r = length (exact) or after a hold-Esc skip; emits finished(skipped).
# PROCESS_MODE_ALWAYS: runs while the host pauses the tree.
# Threading (plan review B1): the cue worker only writes into a holder box ([null]) through a lambda built in a static
# function (no reference to this node); _poll_music reads the box; _exit_tree / PREDELETE wait for the task, so freeing the
# player mid-synthesis is safe. setup opts: manual (step() drives the clock), debug, music (false = no cue at all).
class_name CinePlayer
extends Node3D

signal finished(skipped: bool)

const ESC_HOLD: float = 0.8
const SKIP_FADE: float = 0.25
const LETTERBOX_IN: float = 0.4
const SFX_POOL: int = 6
const AUTO_SFX: Dictionary = {"light": "impact_light", "medium": "impact_medium", "heavy": "impact_heavy", "finisher": "impact_heavy"}

var timeline: CineTimeline
var stage_xf: Transform3D = Transform3D.IDENTITY
var manual: bool = false
var force_skip_hold: bool = false
var debug: bool = false
var r: float = 0.0
var s: float = 0.0
var current_shot: String = ""
var stage: Node3D
var camera: Camera3D
var overlay: CineOverlay
var fx: CineFX
var actors: Dictionary = {}
var prop_nodes: Dictionary = {}
var music: AudioStreamPlayer
var music_len: float = 0.0
var frame_ms_total: float = 0.0
var frames: int = 0
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _events: Array[Dictionary] = []
var _ev_i: int = 0
var _rows: Array[Dictionary] = []
var _cam_rows: Array[Dictionary] = []    # ramp rows + timeline punches (camera whip / FOV punch)
var _beats := PackedFloat32Array()
var _shot_r := PackedFloat32Array()      # real start of each shot
var _task: int = -1
var _box: Array = [null]                 # the worker writes the synthesized cue here (B1)
var _music_ready: bool = false
var _playing: bool = false
var _done: bool = false
var _seeking: bool = false
var _hold: float = 0.0
var _skipping: float = -1.0
var _last_us: int = 0
var leaving_tree: bool = false           # finished(true) emitted from _exit_tree (the host may be leaving the tree too)


## Build everything for tl at stage_xf. Returns the validation errors (empty = ready); an invalid timeline builds nothing.
func setup(tl: CineTimeline, xf: Transform3D = Transform3D.IDENTITY, opts: Dictionary = {}) -> PackedStringArray:
	var errs: PackedStringArray = tl.validate()
	if not errs.is_empty():
		push_error("CinePlayer: timeline %s is invalid:\n  %s" % [tl.slot, "\n  ".join(errs)])
		return errs
	timeline = tl
	stage_xf = xf
	manual = bool(opts.get("manual", false))
	debug = bool(opts.get("debug", OS.get_environment("CINE_DEBUG") == "1"))
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage = Node3D.new()
	stage.name = "Stage"
	add_child(stage)
	stage.transform = xf
	for id: String in tl.actors.keys():
		var a := CineActor.new()
		a.name = id
		stage.add_child(a)
		a.setup(tl.actors[id]["opts"])
		a.display_name = String(tl.actors[id]["name"])
		actors[id] = a
	for pr: Dictionary in tl.props:
		var pn: Node3D = CineFX.build_prop(String(pr["kind"]), pr["opts"])
		pn.name = String(pr["id"])
		pn.position = pr["pos"]
		pn.rotation.y = deg_to_rad(float(pr["yaw"]))
		stage.add_child(pn)
		prop_nodes[String(pr["id"])] = pn
	_dispatch_cues()
	fx = CineFX.new()
	fx.name = "FX"
	stage.add_child(fx)
	camera = Camera3D.new()
	camera.name = "CineCamera"
	camera.near = 0.05
	camera.far = 800.0
	add_child(camera)
	overlay = CineOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	overlay.set_debug(debug)
	music = AudioStreamPlayer.new()
	music.name = "Music"
	music.bus = _bus("Music")
	add_child(music)
	for i: int in SFX_POOL:
		var sp := AudioStreamPlayer.new()
		sp.name = "Sfx%d" % i
		sp.bus = _bus("SFX")
		add_child(sp)
		_sfx.append(sp)
	_rows = tl.clock.beat_rows()
	for row: Dictionary in _rows:
		_beats.append(float(row["r_hit"]))
	_cam_rows = _rows.duplicate()
	for pu: Dictionary in tl.punches:
		_cam_rows.append({"r_hit": tl.clock.real_at(tl.story_time(pu["at"])), "preset": String(pu["preset"]), "freeze": 0.0})
	_cam_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["r_hit"]) < float(b["r_hit"]))
	for sh: Dictionary in tl.shots:
		_shot_r.append(tl.clock.real_at(float(sh["s"])))
	_build_events()
	_prepare_music(bool(opts.get("music", true)))
	_seeking = true
	_update(0.0)
	_seeking = false
	overlay.set_fade(1.0)
	return PackedStringArray()


static func _bus(nm: String) -> StringName:
	return StringName(nm) if AudioServer.get_bus_index(nm) >= 0 else &"Master"


func _dispatch_cues() -> void:
	for c: Dictionary in timeline.cues:
		var a: CineActor = actors.get(String(c["actor"]))
		if a == null:
			continue
		var o: Dictionary = c.get("opts", {})
		match String(c["type"]):
			"move":
				a.move(float(c["s"]), String(c["move"]), o)
			"strike":
				# CineActor.strike starts the move at story_time(at) - hit_u * dur, as the validator checks
				a.strike(timeline.story_time(c["at"]), String(c["move"]), o)
			"key":
				var spin_deg: Vector3 = o.get("spin", Vector3.ZERO)
				a.key(float(c["s"]), c["pos"], deg_to_rad(float(c["yaw"])), spin_deg * (PI / 180.0), String(o.get("mode", "smooth")), float(o.get("arc", 0.0)))
			"expr":
				a.expr(float(c["s"]), String(c["cell"]))
			"look":
				var tg: Variant = c["target"]
				a.look(float(c["s"]), float(c["s1"]), actors.get(String(tg)) if tg is String else tg)
			"show":
				a.show_at(float(c["s"]), bool(c["on"]))
			"hold":
				var hn: Node3D = CineFX.build_prop(String(c["kind"]), o)
				a.hold(float(c["s"]), float(c["s1"]), hn, String(o.get("bone", "Wrist.R")), o)
			"part":
				a.part_show(float(c["s"]), String(c["part"]), bool(c["on"]))


func _build_events() -> void:
	_events.clear()
	for e: Dictionary in timeline.sfx:
		_events.append({"s": timeline.story_time(e["at"]), "kind": "sfx", "cue": String(e["cue"]), "db": float(e.get("db", 0.0))})
	for e2: Dictionary in timeline.fx:
		_events.append({"s": timeline.story_time(e2["at"]), "kind": "fx", "fx": e2})
	for pr: Dictionary in timeline.props:
		var po: Dictionary = pr["opts"]
		if po.has("glow_at"):
			_events.append({"s": timeline.story_time(po["glow_at"]), "kind": "glow", "id": String(pr["id"])})
	for p: Dictionary in timeline.clock.ramps:
		var pre: String = p["preset"]
		if pre == "heavy" or pre == "finisher":
			_events.append({"s": float(p["s0"]), "kind": "sfx", "cue": "whoosh_down", "db": 0.0})
		if AUTO_SFX.has(pre):
			_events.append({"s": float(p["s"]), "kind": "sfx", "cue": String(AUTO_SFX[pre]), "db": 0.0})
		if float(p["freeze"]) > 0.0:
			_events.append({"s": float(p["s"]), "kind": "sfx", "cue": "freeze_tick", "db": 0.0})
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	_ev_i = 0
	# synthesize the SFX now (main thread, cached) so no cue is built in the middle of the cinematic
	for ev: Dictionary in _events:
		if ev["kind"] == "sfx":
			CineAudio.sfx(String(ev["cue"]))


func _prepare_music(enabled: bool) -> void:
	if not enabled:
		_music_ready = true
		return
	var st: AudioStream = CineAudio.load_music(timeline.music_slot if timeline.music_slot != "" else timeline.slot)
	if st:
		music.stream = st
		music_len = CineAudio.stream_length(st)
		_music_ready = true
		return
	var hits: Array[Dictionary] = []
	for row: Dictionary in _rows:
		hits.append({"r": row["r_hit"], "preset": row["preset"], "freeze": row["freeze"], "r_start": row["r_start"], "r_end": row["r_end"]})
	_box = [null]
	_task = WorkerThreadPool.add_task(_synth_job(_box, timeline.length, hits, timeline.mood))


## Worker job: pure synthesis into the holder box; built in a static function so the lambda holds no reference to the node.
static func _synth_job(box: Array, length: float, hits: Array[Dictionary], mood: String) -> Callable:
	return func() -> void: box[0] = CineAudio.synth_cue(length, hits, mood)


func is_ready() -> bool:
	_poll_music()
	return _music_ready


func _poll_music() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_take_cue()


func _take_cue() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	music.stream = _box[0]
	music_len = timeline.length
	_music_ready = true


func start() -> void:
	_playing = true
	_last_us = Time.get_ticks_usec()
	r = 0.0
	_set_flag(true)
	camera.make_current()


func _process(_d: float) -> void:
	if manual or not _playing or _done:
		return
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1e6
	_last_us = now
	if not _music_ready:
		_poll_music()
		if not _music_ready:
			r = 0.0          # fade-in hold: the screen stays black until the cue is ready
			return
	step(dt)                 # full real dt, no clamp (plan review M5): real length and music sync hold through hitches


## Advance the real clock by dt seconds and render that frame.
func step(dt: float) -> void:
	if _done or not _playing:
		return
	if not _music_ready:
		_poll_music()
		if not _music_ready:
			return
	if r == 0.0 and not music.playing and music.stream:
		music.play()
	var t0: int = Time.get_ticks_usec()
	_skip_logic(dt)
	r = minf(r + dt, timeline.length)
	_update(r)
	frame_ms_total += float(Time.get_ticks_usec() - t0) / 1000.0
	frames += 1
	if r >= timeline.length - 1e-9 or _skipping >= SKIP_FADE:
		_finish(_skipping >= 0.0)


## Jump to real time rr (debug, tests): events before it are not fired.
func seek(rr: float) -> void:
	r = rr
	var s0: float = timeline.clock.story_at(rr)
	_ev_i = 0
	while _ev_i < _events.size() and float(_events[_ev_i]["s"]) <= s0:
		_ev_i += 1
	_seeking = true
	_update(rr)
	_seeking = false


func _update(rr: float) -> void:
	s = timeline.clock.story_at(rr)
	var speed: float = timeline.clock.speed_at(rr)
	for a: CineActor in actors.values():
		a.evaluate(s)
	_update_props(s)
	if not _seeking:
		_fire_events(s)
	fx.update(s, speed)
	_update_camera(rr)
	_update_overlay(rr, speed)
	if music.stream:
		var g: float = CineAudio.music_gain(rr, timeline.length, music_len)
		if _skipping >= 0.0:
			g *= clampf(1.0 - _skipping / SKIP_FADE, 0.0, 1.0)   # a skip fades the music with the picture
		music.volume_db = linear_to_db(maxf(g, 0.0001))


## Props with "show_at" / "hide_at" (story s) are visible only in between (seekable, unlike the forward-only events).
func _update_props(ss: float) -> void:
	for pr: Dictionary in timeline.props:
		var po: Dictionary = pr["opts"]
		if not po.has("show_at") and not po.has("hide_at"):
			continue
		var pn: Node3D = prop_nodes.get(String(pr["id"]))
		if pn:
			pn.visible = ss >= timeline.story_time(po.get("show_at", 0.0)) and ss < timeline.story_time(po.get("hide_at", INF))


func _fire_events(ss: float) -> void:
	while _ev_i < _events.size() and float(_events[_ev_i]["s"]) <= ss + 1e-9:
		var ev: Dictionary = _events[_ev_i]
		_ev_i += 1
		match String(ev["kind"]):
			"sfx":
				_play_sfx(String(ev["cue"]), float(ev["db"]))
			"fx":
				_fire_fx(ev["fx"], float(ev["s"]))
			"glow":
				var pn: Node3D = prop_nodes.get(String(ev["id"]))
				if pn:
					CineFX.set_prop_glow(pn, true)


func _play_sfx(cue: String, db: float) -> void:
	var sp: AudioStreamPlayer = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	sp.stream = CineAudio.sfx(cue)
	sp.volume_db = db
	sp.play()


## FX at its story time se. Positions and directions go to CineFX in its local space (= stage space).
func _fire_fx(e: Dictionary, se: float) -> void:
	var kind: String = e["kind"]
	var where: Variant = e["where"]
	var params: Dictionary = e["params"]
	var dir: Vector3 = params.get("dir", Vector3(0.0, 0.6, 0.0))
	var power: float = float(params.get("power", 1.0))
	match kind:
		"crate":
			var pn: Node3D = prop_nodes.get(String(where))
			if pn:
				fx.crate_break(pn, dir, power, se)
		"stars":
			var a: CineActor = actors.get(String(where).get_slice(":", 0)) if where is String else null
			if a:
				fx.stars(a, se, float(params.get("until", se + 4.0)))
		_:
			fx.burst(kind, _fx_local(where), dir, power, se)


func _fx_local(where: Variant) -> Vector3:
	if where is Vector3:
		return fx.to_local(stage.to_global(where))
	var w: String = String(where)
	if w.contains(":"):
		var a: CineActor = actors.get(w.get_slice(":", 0))
		return fx.to_local(a.bone_world(w.get_slice(":", 1))) if a else Vector3.ZERO
	var n: Node3D = actors.get(w, prop_nodes.get(w))
	return fx.to_local(n.global_position) if n else Vector3.ZERO


func _update_camera(rr: float) -> void:
	var shots: Array[Dictionary] = timeline.shots
	var i: int = 0
	for k: int in shots.size():
		if float(shots[k]["s"]) <= s + 1e-9:
			i = k
	var shot: Dictionary = shots[i]
	current_shot = String(shot["id"])
	var r0: float = _shot_r[i]
	var r1: float = _shot_r[i + 1] if i + 1 < shots.size() else timeline.length
	var u: float = clampf((rr - r0) / maxf(r1 - r0, 0.001), 0.0, 1.0)
	var c: Dictionary = CineShots.eval(shot, u, {"actors": actors})
	var w: Dictionary = CineShots.whip(rr, r0, r1, _cam_rows, bool((shot["params"] as Dictionary).get("whip", true)))
	var hh: Dictionary = CineShots.handheld(s, float((shot["params"] as Dictionary).get("hand", 0.0)))
	var pos_w: Vector3 = stage_xf * ((c["pos"] as Vector3) + (w["shake"] as Vector3))
	var look_w: Vector3 = stage_xf * (c["look"] as Vector3)
	var d: Vector3 = look_w - pos_w
	if d.length() > 0.01:
		var up: Vector3 = Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
		var b: Basis = Basis.looking_at(d, up)
		b = Basis(Vector3.UP, deg_to_rad(float(w["yaw"]))) * b
		b = b * Basis.from_euler((hh["rot"] as Vector3) * (PI / 180.0))
		camera.global_transform = Transform3D(b, pos_w + b * (hh["pos"] as Vector3))
	camera.fov = float(c["fov"]) + float(w["fov"])


func _update_overlay(rr: float, speed: float) -> void:
	var L: float = timeline.length
	overlay.set_letterbox(clampf(rr / LETTERBOX_IN, 0.0, 1.0) if timeline.letterbox else 0.0)
	var a: float = 0.0
	if timeline.fade_in > 0.0:
		a = maxf(a, 1.0 - rr / timeline.fade_in)
	if timeline.fade_out > 0.0:
		a = maxf(a, (rr - (L - timeline.fade_out)) / timeline.fade_out)
	if _skipping >= 0.0:
		a = maxf(a, _skipping / SKIP_FADE)
	overlay.set_fade(clampf(a, 0.0, 1.0))
	var shown: bool = false
	for sb: Dictionary in timeline.subs:
		var r0: float = sb["r"]
		if rr >= r0 and rr < r0 + float(sb["dur"]):
			var sp: String = sb["speaker"]
			var col: Color = (timeline.actors[sp]["color"] as Color) if timeline.actors.has(sp) else Color.WHITE
			overlay.show_sub(timeline.speaker_name(sp), col, String(sb["text"]), String(sb["tr"]))
			shown = true
			break
	if not shown:
		overlay.hide_sub()
	overlay.set_skip(_hold / ESC_HOLD if _hold > 0.0 and _skipping < 0.0 else -1.0)
	if debug:
		var nxt: String = "-"
		for row: Dictionary in _rows:
			if float(row["r_hit"]) > rr:
				nxt = "%s @%.3f" % [String(row["name"]), float(row["r_hit"])]
				break
		overlay.update_debug("r=%.3f  s=%.3f  x%.2f  shot %s  next %s" % [rr, s, speed, current_shot, nxt], _beats, L, rr)


func _skip_logic(dt: float) -> void:
	if _skipping >= 0.0:
		_skipping += dt
		return
	var held: bool = force_skip_hold or Input.is_physical_key_pressed(KEY_ESCAPE)
	_hold = _hold + dt if held else 0.0
	if _hold >= ESC_HOLD - 1e-6:
		_skipping = 0.0


func _finish(skipped: bool) -> void:
	_done = true
	_playing = false
	music.stop()
	_set_flag(false)
	finished.emit(skipped)


func _set_flag(on: bool) -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("cinematic_active", on)


func set_debug(on: bool) -> void:
	debug = on
	if overlay:
		overlay.set_debug(on)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_F10:
		set_debug(not debug)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _task >= 0:
		_take_cue()
	if _playing and not _done:
		# freed / removed mid-cinematic: Esc must open the pause menu again (plan review Minor 3) and an awaiting host must
		# hear the end (Tasks 5+6 review): finished(true) with leaving_tree set
		leaving_tree = true
		_finish(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
