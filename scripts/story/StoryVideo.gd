# File: res://scripts/story/StoryVideo.gd
# Owner AI clip player (spec A2-D10, story spec 8.2): if user://video/<clip>_m.ogv (male protagonist) or <clip>_f.ogv
# (female) exists, a full-screen VideoStreamPlayer plays it with a fade in / out and a hold-Esc skip; otherwise StoryRoam
# plays the clip's in-engine fallback cinematic. The files are local only (never committed or exported).
# PROCESS_MODE_ALWAYS; sets StageManager.cinematic_active while it plays; emits finished(skipped).
class_name StoryVideo
extends CanvasLayer

signal finished(skipped: bool)

const VIDEO_DIR: String = "user://video/"
const FADE: float = 0.5
const ESC_HOLD: float = 0.8

static var video_dir: String = VIDEO_DIR

var player: VideoStreamPlayer
var black: ColorRect
var t: float = 0.0
var _hold: float = 0.0
var _ending: float = -1.0
var _skipped: bool = false
var _done: bool = false


## The owner's file for `clip` and the protagonist's sex ("" when there is none).
static func video_file(clip: String, female: bool) -> String:
	var p: String = video_dir + clip + ("_f" if female else "_m") + ".ogv"
	return p if FileAccess.file_exists(p) else ""


## Plays `path`; false (nothing built) when the file cannot be opened.
func play_file(path: String) -> bool:
	if path == "" or not FileAccess.file_exists(path):
		return false
	var vs := VideoStreamTheora.new()
	vs.file = path
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	add_child(bg)
	player = VideoStreamPlayer.new()
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.expand = true
	player.stream = vs
	player.bus = CinePlayer._bus("Music")
	add_child(player)
	black = ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.0, 0.0, 0.0, 1.0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	player.finished.connect(func() -> void: _begin_end(false))
	player.play()
	_set_flag(true)
	return true


func _begin_end(skipped: bool) -> void:
	if _ending >= 0.0:
		return
	_skipped = skipped
	_ending = 0.0


func _process(delta: float) -> void:
	if _done or player == null:
		return
	t += delta
	if _ending >= 0.0:
		_ending += delta
		black.color.a = clampf(_ending / FADE, 0.0, 1.0)
		if _ending >= FADE:
			_finish()
		return
	black.color.a = clampf(1.0 - t / FADE, 0.0, 1.0)
	_hold = _hold + delta if Input.is_physical_key_pressed(KEY_ESCAPE) else 0.0
	if _hold >= ESC_HOLD:
		_begin_end(true)


func _finish() -> void:
	if _done:
		return
	_done = true
	if player:
		player.stop()
	_set_flag(false)
	finished.emit(_skipped)
	queue_free()


func _set_flag(on: bool) -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("cinematic_active", on)


func _exit_tree() -> void:
	if not _done and player != null:
		_done = true
		_set_flag(false)
		finished.emit(true)
