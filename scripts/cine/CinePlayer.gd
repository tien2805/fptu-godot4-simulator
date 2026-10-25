# File: res://scripts/cine/CinePlayer.gd
# Plays one CineTimeline (spec section 9): builds the actors (real game models) under a stage node placed at stage_xf, the
# props, a Camera3D, the overlay, the FX node (under the stage: CineFX works in its own local space = stage space) and the
# audio players; music (the owner's slot file, none = no music, H-D8) starts on the first frame; every frame:
# r (REAL, from Time.get_ticks_usec or step(dt), never Engine.time_scale, never clamped) -> s = clock.story_at(r) -> actors,
# story-time events (SFX, FX, prop glow), prop visibility (opts show_at / hide_at, a pure function of s), FX speed, camera
# (shot at real progress + whip / punch-in of ramps and timeline punches + handheld noise in story time when the shot has
# "hand"), overlay (letterbox, fades, subtitle at r, skip bar, debug), music gain. Ends at r = length (exact) or after a hold-Esc skip; emits finished(skipped).
# PROCESS_MODE_ALWAYS: runs while the host pauses the tree.
# setup opts: manual (step() drives the clock), debug, music (false = no music even with an owner file).
# Jump scare v2: the timeline's scare_hit marks run through a CineScare child (duck of the music and the SFX pool, the
# inhale, the screen hit, the FOV punch, the twitch of the hit's actor, the +8 dB sting); its overlay is freed and the
# camera put back at the end, on a skip or when leaving the tree. "Giảm hù dọa" (read at setup): the soft variant.
class_name CinePlayer
extends Node3D

signal finished(skipped: bool)
## Phase B: the timeline's choice scene was answered (StoryChoice: key of the option, timed_out = the honest default).
signal choice_made(id: String, key: String, timed_out: bool)

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
var _playing: bool = false
var _done: bool = false
var _seeking: bool = false
var _hold: float = 0.0
var _skipping: float = -1.0
var _last_us: int = 0
var leaving_tree: bool = false           # finished(true) emitted from _exit_tree (the host may be leaving the tree too)
var card_nodes: Array[CanvasLayer] = []  # Phase B: StoryVillainCard / StoryScreenCard layers, updated on real time
var choice_node: StoryChoice = null      # Phase B: open while the timeline's choice is asked (the clock holds)
var choice_key: String = ""
var choice_timed_out: bool = false
var _choice_state: int = 0               # 0 not asked yet (or no choice), 1 open, 2 answered
var scare: CineScare = null              # jump scare v2 marks (scare_hit), null without any
var _scare_twitch: Array[String] = []    # actor id per scare hit ("" = none)
var _sfx_db: PackedFloat32Array = PackedFloat32Array()   # each pool player's own level (the duck goes on top)
var _fov_off: float = 0.0


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
	# Phase B: drop_set (setup opt, or tl.stage["drop_set"]) leaves out the carried set dressing (props with opts "set": true,
	# e.g. the corridor walls) when the integration stages the scene inside the real building or the Night Building
	var drop_set: bool = bool(opts.get("drop_set", tl.stage.get("drop_set", false)))
	for pr: Dictionary in tl.props:
		if drop_set and bool((pr["opts"] as Dictionary).get("set", false)):
			continue
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
	fx.adopt_ambient(stage)   # looping prop particles (headlight dust) follow the clock
	camera = Camera3D.new()
	camera.name = "CineCamera"
	camera.near = 0.05
	camera.far = 800.0
	add_child(camera)
	overlay = CineOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	overlay.set_debug(debug)
	for cd: Dictionary in tl.cards:
		var cl: CanvasLayer = StoryVillainCard.new() if String(cd["kind"]) == "villain" else StoryScreenCard.new()
		cl.name = "%sCard%d" % [String(cd["kind"]).capitalize(), card_nodes.size()]
		cl.set("data", cd["data"])
		cl.set("r0", float(cd["r"]))
		cl.set("dur", float(cd["dur"]))
		add_child(cl)
		card_nodes.append(cl)
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
	_sfx_db.resize(_sfx.size())
	if not tl.scare_hits.is_empty():
		var hl: Array = []
		for sh: Dictionary in tl.scare_hits:
			var o: Dictionary = sh["opts"]
			hl.append({"r": tl.clock.real_at(tl.story_time(sh["at"])), "twitch": String(o.get("twitch", "")), "hold": float(o.get("hold", CineScare.HOLD_S))})
			_scare_twitch.append(String(o.get("twitch", "")))
		scare = CineScare.new()
		add_child(scare)
		scare.setup(camera, hl, StoryUtil.reduce_scares())
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
				if bool(o.get("glow", false)):
					CineFX.set_prop_glow(hn, true)   # A2: a held phone with its screen lit
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
		if float(p["freeze"]) > 0.0 and pre != "card":
			_events.append({"s": float(p["s"]), "kind": "sfx", "cue": "freeze_tick", "db": 0.0})
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	_ev_i = 0
	# synthesize the SFX now (main thread, cached) so no cue is built in the middle of the cinematic
	for ev: Dictionary in _events:
		if ev["kind"] == "sfx":
			CineAudio.sfx(String(ev["cue"]))


## The owner's slot file (user://music/<music_slot>.ogg|.mp3) or no music at all (H-D8: no code music).
func _prepare_music(enabled: bool) -> void:
	music.stream = null
	music_len = 0.0
	if not enabled:
		return
	var st: AudioStream = CineAudio.load_music(timeline.music_slot if timeline.music_slot != "" else timeline.slot)
	if st:
		music.stream = st
		music_len = CineAudio.stream_length(st)


## Always true once set up (kept for the hosts that wait on it: nothing is built in the background any more).
func is_ready() -> bool:
	return timeline != null


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
	step(dt)                 # full real dt, no clamp (plan review M5): real length and music sync hold through hitches


## Advance the real clock by dt seconds and render that frame.
func step(dt: float) -> void:
	if _done or not _playing:
		return
	if _choice_state == 1:
		# the choice scene is open: the cinematic holds its frame (r does not advance); a manual player drives the overlay
		if manual and is_instance_valid(choice_node):
			choice_node.step(dt)
		return
	if r == 0.0 and not music.playing and music.stream:
		music.play()
	var t0: int = Time.get_ticks_usec()
	_skip_logic(dt)
	var r_prev: float = r
	var nr: float = minf(r + dt, timeline.length)
	var at_choice: bool = choice_pending() and _skipping < 0.0 and nr >= float(timeline.choice_def["r"]) - 1e-9
	if at_choice:
		nr = float(timeline.choice_def["r"])
	r = nr
	_update(r)
	if scare != null:
		scare.step(r_prev, r, dt)
	frame_ms_total += float(Time.get_ticks_usec() - t0) / 1000.0
	frames += 1
	if at_choice:
		_open_choice()
		return
	if r >= timeline.length - 1e-9 or _skipping >= SKIP_FADE:
		if choice_pending():
			_open_choice()   # skipped before the choice: it is still asked (over the fade) before finished
			return
		_finish(_skipping >= 0.0)


## true while the timeline has a choice that has not been asked yet.
func choice_pending() -> bool:
	return not timeline.choice_def.is_empty() and _choice_state == 0


func _open_choice() -> void:
	_choice_state = 1
	if music.stream:
		music.stream_paused = true
	choice_node = StoryChoice.open(self, timeline.choice_def, manual)
	choice_node.chosen.connect(_on_chosen)


func _on_chosen(key: String, timed_out: bool) -> void:
	choice_key = key
	choice_timed_out = timed_out
	_choice_state = 2
	choice_node = null
	if music.stream:
		music.stream_paused = false
	choice_made.emit(String(timeline.choice_def.get("id", "")), key, timed_out)
	if _skipping >= SKIP_FADE:
		_finish(true)
	elif r >= timeline.length - 1e-9:
		_finish(false)


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
	if scare != null:   # the hit's actor twitches through its hold (spin is re-keyed every frame)
		for i: int in _scare_twitch.size():
			var ta: CineActor = actors.get(_scare_twitch[i])
			if ta != null and ta.spin != null:
				ta.spin.rotation += scare.twitch_at(rr, i)
	_update_props(s)
	if not _seeking:
		_fire_events(s)
	fx.update(s, speed)
	_update_camera(rr)
	_update_overlay(rr, speed)
	var duck: float = scare.duck_at(rr) if scare != null else 0.0
	if music.stream:
		var g: float = CineAudio.music_gain(rr, timeline.length, music_len)
		if _skipping >= 0.0:
			g *= clampf(1.0 - _skipping / SKIP_FADE, 0.0, 1.0)   # a skip fades the music with the picture
		g *= 1.0 - duck   # a scare ducks it to silence just before the hit
		music.volume_db = linear_to_db(maxf(g, 0.0001))
	if scare != null:
		var ddb: float = linear_to_db(maxf(1.0 - duck, 0.001))
		for i2: int in _sfx.size():
			_sfx[i2].volume_db = _sfx_db[i2] + ddb


## Props with "show_at" / "hide_at" (story s) are visible only in between (seekable, unlike the forward-only events).
## A prop with "path" [[s, pos, rot_deg], ...] (+ "arc" m over the whole path) flies along it, linear between keys (seekable).
func _update_props(ss: float) -> void:
	for pr: Dictionary in timeline.props:
		var po: Dictionary = pr["opts"]
		if not po.has("show_at") and not po.has("hide_at") and not po.has("path") and not po.has("flicker") and not po.has("dark") and not po.has("anim"):
			continue
		var pn: Node3D = prop_nodes.get(String(pr["id"]))
		if pn == null:
			continue
		if po.has("anim"):
			# Phase B: an animated prop (the shiba) poses itself from story time (seekable)
			var an: Node = pn.get_meta("shiba", pn)
			if an.has_method("cine_eval"):
				an.call("cine_eval", ss, po)
		if po.has("flicker") or po.has("dark"):
			# A2 lamp: stutters inside its "flicker" story windows; Phase B: fully off inside its "dark" windows (seekable)
			CineFX.set_lamp(pn, CineFX.lamp_on(ss, po.get("flicker", [])) and not CineFX.in_windows(ss, po.get("dark", [])))
		if po.has("show_at") or po.has("hide_at"):
			pn.visible = ss >= timeline.story_time(po.get("show_at", 0.0)) and ss < timeline.story_time(po.get("hide_at", INF))
		var path: Array = po.get("path", [])
		if path.size() >= 2:
			var s0: float = float(path[0][0])
			var s1: float = float(path[path.size() - 1][0])
			var k0: Array = path[0]
			var k1: Array = path[0]
			for i: int in path.size():
				if float(path[i][0]) <= ss:
					k0 = path[i]
					k1 = path[mini(i + 1, path.size() - 1)]
			if ss < s0:
				k1 = k0
			var u: float = clampf((ss - float(k0[0])) / maxf(float(k1[0]) - float(k0[0]), 0.0001), 0.0, 1.0)
			var w: float = clampf((ss - s0) / maxf(s1 - s0, 0.0001), 0.0, 1.0)
			pn.position = (k0[1] as Vector3).lerp(k1[1], u) + Vector3(0.0, 4.0 * float(po.get("arc", 0.0)) * w * (1.0 - w), 0.0)
			pn.rotation_degrees = (k0[2] as Vector3).lerp(k1[2], u)


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
	sp.volume_db = db + StoryAudio.cue_db(cue)   # horror cues -6 dB with "Giảm hù dọa" (A2-D14)
	_sfx_db[_sfx.find(sp)] = sp.volume_db
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
	_fov_off = scare.fov_offset(rr) if scare != null else 0.0
	camera.fov = float(c["fov"]) + float(w["fov"]) + _fov_off


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
	for cl: CanvasLayer in card_nodes:
		cl.call("update", rr)
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
	if scare != null:   # a skip mid-scare: the overlay goes, the camera and the audio levels come back
		scare.cleanup()
		if camera != null:
			camera.fov -= _fov_off
		_fov_off = 0.0
		for i: int in _sfx.size():
			_sfx[i].volume_db = _sfx_db[i]
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
	if OS.is_debug_build() and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_F10:
		set_debug(not debug)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _playing and not _done:
		# freed / removed mid-cinematic: Esc must open the pause menu again (plan review Minor 3) and an awaiting host must
		# hear the end (Tasks 5+6 review): finished(true) with leaving_tree set
		leaving_tree = true
		_finish(true)
