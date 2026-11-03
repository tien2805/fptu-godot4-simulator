# File: res://scripts/story/StoryVideo.gd
# Owner AI clip player (spec A2-D10, story spec 8.2): if user://video/<clip>_m.ogv (male protagonist) or <clip>_f.ogv
# (female) exists, a full-screen VideoStreamPlayer plays it (aspect ratio kept, black bars) with a fade in, a fade out to
# black, then a fade back from black to the game, and a hold-Esc skip (hint shown). Otherwise StoryRoam plays the clip's
# in-engine fallback cinematic. The files are local only (never committed or exported).
# A file that cannot be decoded (play_file -> false) or stalls (stream position frozen for STALL_S) ends with failed = true,
# so StoryRoam falls back to the cinematic (review A2-R3). Removed from the tree mid-clip (window closed, scene change) it
# emits finished(true) with left_tree = true, so the host does not count the clip as seen.
# Music (story spec 8.2, w5-complete G2): when the clip's music slot has an owner file (user://music/<clip>.ogg|.mp3, or its
# CineAudio.SLOT_FALLBACK parent: ai_true_end -> end_a), it starts on the clip's first frame on the Music bus, follows the
# fades, stops with the clip (a longer file is cut by the fade out), and the clip's own audio track is muted; without a
# slot file the clip's own audio plays.
# PROCESS_MODE_ALWAYS; sets StageManager.cinematic_active while it plays; emits finished(skipped).
class_name StoryVideo
extends CanvasLayer

signal finished(skipped: bool)

const VIDEO_DIR: String = "user://video/"
const FADE: float = 0.5
const ESC_HOLD: float = SkipHold.HOLD
const STALL_S: float = 1.5

static var video_dir: String = VIDEO_DIR

var player: VideoStreamPlayer
var frame: AspectRatioContainer
var black: ColorRect
var bg: ColorRect
var hint: Label
var ring: SkipHold.Ring
var t: float = 0.0
var failed: bool = false
var left_tree: bool = false
var _hold: float = 0.0
var _ending: float = -1.0
var _reveal: float = -1.0
var _skipped: bool = false
var _done: bool = false
var _last_pos: float = -1.0
var _still_t: float = 0.0
var _aspect_set: bool = false
## The clip's music slot player (null: no slot file, the clip's own audio plays).
var music: AudioStreamPlayer = null


## The owner's file for `clip` and the protagonist's sex ("" when there is none).
static func video_file(clip: String, female: bool) -> String:
	var p: String = video_dir + clip + ("_f" if female else "_m") + ".ogv"
	return p if FileAccess.file_exists(p) else ""


## The clip a file belongs to: "user://video/ai_intro_f.ogv" -> "ai_intro" (its music slot).
static func clip_of(path: String) -> String:
	var b: String = path.get_file().get_basename()
	return b.substr(0, b.length() - 2) if b.ends_with("_m") or b.ends_with("_f") else b


## Starts the clip's music slot when it has a file (play_file calls it once the clip decodes; tests call it alone):
## true when music plays, and then the clip's own audio is muted.
func start_music(clip: String) -> bool:
	var st: AudioStream = CineAudio.load_music(clip)
	if st == null:
		return false
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = false
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = false
	music = AudioStreamPlayer.new()
	music.name = "ClipMusic"
	music.bus = CinePlayer._bus("Music")
	music.stream = st
	add_child(music)
	music.play()
	if player:
		player.volume_db = -80.0   # the slot replaces the clip's own audio track
	return true


## Plays `path`; false (everything built is removed) when the file is missing or cannot be decoded.
func play_file(path: String) -> bool:
	if path == "" or not FileAccess.file_exists(path):
		return false
	var vs := VideoStreamTheora.new()
	vs.file = path
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	add_child(bg)
	frame = AspectRatioContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.ratio = 16.0 / 9.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(frame)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.stream = vs
	player.bus = CinePlayer._bus("Music")
	frame.add_child(player)
	black = ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.0, 0.0, 0.0, 1.0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	hint = Label.new()
	hint.text = "Giữ Esc hoặc Enter để bỏ qua"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.9, 0.88, 0.95, 0.7))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -220.0
	hint.offset_top = -40.0
	hint.offset_right = -20.0
	hint.offset_bottom = -18.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)
	ring = SkipHold.Ring.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ring.offset_left = -200.0
	ring.offset_top = 16.0
	ring.offset_right = -16.0
	ring.offset_bottom = 40.0
	ring.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(ring)
	player.finished.connect(func() -> void: _begin_end(false))
	player.play()
	if not player.is_playing() or player.get_stream_length() <= 0.0:
		player.stop()
		for c: Node in get_children():
			remove_child(c)
			c.queue_free()
		player = null
		return false   # undecodable: the host plays the fallback cinematic
	start_music(clip_of(path))
	_set_flag(true)
	return true


func _begin_end(skipped: bool) -> void:
	if _ending >= 0.0:
		return
	_skipped = skipped
	_ending = 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	if _reveal >= 0.0:
		# after finished: the game runs again under the black, which fades away
		_reveal += delta
		black.color.a = clampf(1.0 - _reveal / FADE, 0.0, 1.0)
		if _reveal >= FADE:
			queue_free()
		return
	t += delta
	if _ending >= 0.0:
		_ending += delta
		black.color.a = clampf(_ending / FADE, 0.0, 1.0)
		if music:
			music.volume_db = linear_to_db(maxf(1.0 - black.color.a, 0.0001))   # the music fades out with the picture
		if _ending >= FADE:
			_finish()
		return
	black.color.a = clampf(1.0 - t / FADE, 0.0, 1.0)
	if not _aspect_set:
		var tex: Texture2D = player.get_video_texture()
		if tex and tex.get_width() > 0 and tex.get_height() > 0:
			frame.ratio = float(tex.get_width()) / float(tex.get_height())   # keep the clip's own aspect ratio
			_aspect_set = true
	# stall watchdog: the stream position must move
	var pos: float = player.stream_position
	if absf(pos - _last_pos) < 1e-4:
		_still_t += delta
		if _still_t >= STALL_S:
			failed = true
			_begin_end(false)
	else:
		_still_t = 0.0
		_last_pos = pos
	_hold = _hold + delta if SkipHold.held() else 0.0
	ring.set_progress(_hold / ESC_HOLD if _hold > 0.0 else -1.0)
	if _hold >= ESC_HOLD:
		_begin_end(true)


func _finish() -> void:
	if _done:
		return
	_done = true
	if music:
		music.stop()
	if player:
		player.stop()
		frame.visible = false
		bg.visible = false
		hint.visible = false
	_set_flag(false)
	finished.emit(_skipped)
	_reveal = 0.0


func _set_flag(on: bool) -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("cinematic_active", on)


func _exit_tree() -> void:
	if not _done and player != null:
		_done = true
		left_tree = true
		_set_flag(false)
		finished.emit(true)
