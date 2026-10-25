# File: res://scripts/cine/CineReplay.gd
# Short slow-motion replay (spec A1-D18) of the footage a CineReplayRecorder holds: a fixed REAL length (4-6 s, default 5)
# at base speed 0.5 with one heavy ramp on the marked blow at 55 % of the length (CineReplayRecorder.replay_clock). While it
# plays the game is paused (the recorder is PAUSABLE, so it stops recording), the tracked actors are posed from the buffer
# (transforms + bone poses), a replay camera cuts orbit (before the ramp) -> low (the ramp, with the whip-pan of the impact)
# -> wide (after it), the overlay shows the letterbox, fades and the "▶ REPLAY" tag, and the music is the slot's owner file
# user://music/<slot>.ogg|.mp3 or nothing (H-D8: no code music, no synthesized sting). At the end (or after a
# 0.8 s hold-Esc skip) the live state, the previous camera, the pause and StageManager.cinematic_active are restored, then
# `finished` is emitted and the node frees itself. Removed from the tree mid-play, it releases the same things (_exit_tree).
# Real time: Time.get_ticks_usec, full dt (no clamp: the length and the music hold through hitches); manual = step() drives.
# Phase B: var rp := CineReplay.new(); add_child(rp); rp.start(recorder, {"slot": "seg_d1_chase", "focus": body, "other": foe})
class_name CineReplay
extends Node3D

signal finished

const ESC_HOLD: float = 0.8
const LETTERBOX_IN: float = 0.4
const FADE_IN: float = 0.25
const FADE_OUT: float = 0.3
const ORBIT_RADIUS: float = 3.6
const ORBIT_DEG: float = 60.0
const FOV: Dictionary = {"orbit": 50.0, "low": 60.0, "wide": 50.0}
var length: float = 5.0
var r: float = 0.0
var s: float = 0.0
var clock: CineClock
var t0: float = 0.0
var phase_shot: String = "orbit"
var camera: Camera3D
var overlay: CineOverlay
var music: AudioStreamPlayer
var manual: bool = false
var force_skip_hold: bool = false
var rec: CineReplayRecorder
var focus: Node3D
var other: Node3D
var _impact: Vector3 = Vector3.ZERO
var _side: Vector3 = Vector3.RIGHT
var _snap: Dictionary = {}
var _prev_cam: Camera3D
var _music_len: float = 0.0
var _rows: Array[Dictionary] = []
var _pause: bool = true
var _was_paused: bool = false
var _rec_was: bool = true              # recorder state before the replay (it stops recording while a replay plays)
var _playing: bool = false
var _done: bool = false
var _hold: float = 0.0
var _last_us: int = 0


## Start the replay of `recorder` around its mark. opts: length (4-6, default 5), slot (music slot, "" or no file = silent), focus,
## other (default: the first two tracked actors), mark ("blow"), base (0.5), pause (true), manual (false).
## Returns false (and does nothing) without footage or without an actor to show.
func start(recorder: CineReplayRecorder, opts: Dictionary = {}) -> bool:
	if _playing or _done or recorder == null or recorder.frame_count() < 2:
		return false
	var tracked_nodes: Array[Node3D] = recorder.tracked()
	var fo: Node3D = opts.get("focus", null)
	if fo == null and not tracked_nodes.is_empty():
		fo = tracked_nodes[0]
	if fo == null:
		return false
	var ot: Node3D = opts.get("other", null)
	if ot == null:
		for n: Node3D in tracked_nodes:
			if n != fo:
				ot = n
				break
	rec = recorder
	focus = fo
	other = ot
	length = clampf(float(opts.get("length", 5.0)), 4.0, 6.0)
	manual = bool(opts.get("manual", false))
	_pause = bool(opts.get("pause", true))
	var f: float = float(rec.marks.get(String(opts.get("mark", "blow")), rec.newest_time()))
	var rc: Dictionary = CineReplayRecorder.replay_clock(length, f, rec.newest_time() - f, float(opts.get("base", 0.5)))
	clock = rc["clock"]
	t0 = rc["t0"]
	_rows = clock.beat_rows()
	var pf: Vector3 = _pos_at(focus, f)
	_impact = pf
	_side = Vector3.RIGHT
	if other:
		var po: Vector3 = _pos_at(other, f)
		_impact = (pf + po) * 0.5
		var d := Vector3(po.x - pf.x, 0.0, po.z - pf.z)
		if d.length() > 1e-3:
			_side = Vector3(-d.z, 0.0, d.x).normalized()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_snap = rec.snapshot()
	_prev_cam = get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.name = "ReplayCamera"
	camera.near = 0.05
	camera.far = 800.0
	add_child(camera)
	camera.make_current()
	overlay = CineOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	overlay.set_tag("REPLAY")
	music = AudioStreamPlayer.new()
	music.name = "Music"
	music.bus = CinePlayer._bus("Music")
	add_child(music)
	var slot: String = String(opts.get("slot", ""))
	var st: AudioStream = CineAudio.load_music(slot) if slot != "" else null
	_music_len = CineAudio.stream_length(st) if st else length
	music.stream = st
	_was_paused = get_tree().paused
	if _pause:
		get_tree().paused = true
	# pause: false keeps the game running: stop the recorder too, so the replay never records its own playback
	_rec_was = rec.recording
	rec.recording = false
	_set_flag(true)
	r = 0.0
	_hold = 0.0
	_playing = true
	_last_us = Time.get_ticks_usec()
	if st:
		music.play()
	_apply(0.0)
	return true


## Position of a node at recorder time t (from the buffer when tracked, otherwise its live position).
func _pos_at(n: Node3D, t: float) -> Vector3:
	if rec.tracked().has(n):
		return rec.transform_at(n, t).origin
	return n.global_position if n.is_inside_tree() else n.position


func _process(_d: float) -> void:
	if manual or not _playing or _done:
		return
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1e6
	_last_us = now
	step(dt)                 # full real dt, no clamp (plan review M5)


## Advance the real clock by dt seconds and render that frame.
func step(dt: float) -> void:
	if not _playing or _done:
		return
	var held: bool = force_skip_hold or Input.is_physical_key_pressed(KEY_ESCAPE)
	_hold = _hold + dt if held else 0.0
	overlay.set_skip(_hold / ESC_HOLD if _hold > 0.0 else -1.0)
	if _hold >= ESC_HOLD - 1e-6:
		_finish()
		return
	r = minf(r + dt, length)
	_apply(r)
	if r >= length - 1e-9:
		_finish()


func _apply(rr: float) -> void:
	if not is_instance_valid(rec):
		_finish()
		return
	s = clock.story_at(rr)
	rec.apply_at(t0 + s)
	_update_camera(rr)
	overlay.set_letterbox(clampf(rr / LETTERBOX_IN, 0.0, 1.0))
	overlay.set_fade(clampf(maxf(1.0 - rr / FADE_IN, (rr - (length - FADE_OUT)) / FADE_OUT), 0.0, 1.0))
	music.volume_db = linear_to_db(maxf(CineAudio.music_gain(rr, length, _music_len), 0.0001))


func _update_camera(rr: float) -> void:
	var ramp: Dictionary = clock.ramp("focus")
	var r0: float = ramp["r0"]
	var r1: float = ramp["r1"]
	var pos: Vector3
	var look: Vector3
	var yaw: float = 0.0
	var fov_add: float = 0.0
	if rr < r0:
		phase_shot = "orbit"
		var c: Vector3 = (focus.global_position if is_instance_valid(focus) else _impact) + Vector3(0.0, 1.1, 0.0)
		var a: float = atan2(_side.x, _side.z) + deg_to_rad(ORBIT_DEG) * clampf(rr / maxf(r0, 1e-3), 0.0, 1.0)
		pos = c + Vector3(sin(a) * ORBIT_RADIUS, 0.4, cos(a) * ORBIT_RADIUS)
		look = c
	elif rr < r1:
		phase_shot = "low"
		var w: Dictionary = CineShots.whip(rr, r0, r1, _rows)
		pos = _impact + _side * 2.0 + Vector3(0.0, 0.3, 0.0) + (w["shake"] as Vector3)
		look = _impact + Vector3(0.0, 1.0, 0.0)
		yaw = float(w["yaw"])
		fov_add = float(w["fov"])
	else:
		phase_shot = "wide"
		var u: float = clampf((rr - r1) / maxf(length - r1, 1e-3), 0.0, 1.0)
		var e: float = u * u * (3.0 - 2.0 * u)
		pos = _impact + _side * lerpf(3.0, 6.0, e) + Vector3(0.0, lerpf(2.2, 3.0, e), 0.0)
		look = _impact + Vector3(0.0, 0.9, 0.0)
	pos = _avoid_walls(look, pos)
	var d: Vector3 = look - pos
	if d.length() > 0.01:
		var up: Vector3 = Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
		var b: Basis = Basis(Vector3.UP, deg_to_rad(yaw)) * Basis.looking_at(d, up)
		camera.global_transform = Transform3D(b, pos)
	camera.fov = float(FOV[phase_shot]) + fov_add


## Pull the camera in front of a wall between the look target and the camera (tracked bodies are ignored).
func _avoid_walls(look: Vector3, pos: Vector3) -> Vector3:
	var w3: World3D = get_world_3d()
	if w3 == null or not w3.space.is_valid():
		return pos
	var space: PhysicsDirectSpaceState3D = w3.direct_space_state
	if space == null:
		return pos
	var q := PhysicsRayQueryParameters3D.create(look, pos)
	var ex: Array[RID] = []
	for n: Node3D in rec.tracked():
		if n is CollisionObject3D:
			ex.append((n as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return pos
	var dir: Vector3 = (pos - look).normalized()
	return (hit["position"] as Vector3) - dir * 0.3


func _finish() -> void:
	if _done:
		return
	_release()
	finished.emit()
	queue_free()


## Restore the live state, the previous camera, the pause and the cinematic flag (once).
func _release() -> void:
	_done = true
	_playing = false
	if music:
		music.stop()
	if is_instance_valid(rec):
		rec.restore(_snap)
		rec.recording = _rec_was
	if is_instance_valid(_prev_cam) and _prev_cam.is_inside_tree():
		_prev_cam.make_current()
	elif camera:
		camera.clear_current()
	if _pause and is_inside_tree():
		get_tree().paused = _was_paused
	_set_flag(false)


func _set_flag(on: bool) -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("cinematic_active", on)


func _exit_tree() -> void:
	if _playing and not _done:
		_release()           # removed mid-replay: never leave the game paused or Esc blocked (plan review Minor 3)
		finished.emit()
