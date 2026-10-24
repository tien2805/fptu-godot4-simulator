# File: res://scripts/story/StoryCall.gd
# The 3 a.m. call (spec A2-D8): an overlay above the HUD. Black fade (0.8 s), then a phone screen "SỐ LẠ · 03:00" ringing
# (phone_ring_3am, loops); answer with [E] or a click, or it auto-answers after RING_MAX s. Then a distorted "voice" made of
# whisper_bed + static_burst only (no recorded or real voice) under slowly typed subtitles "…Mày… còn… N ngày…", the line
# goes dead (call_hangup) and the screen fades out: about 10 s when answered at once. Hold Esc 0.8 s to skip. On answer a
# small screen shake and a white flash, both off with "Giảm hù dọa" (horror cues are also 6 dB quieter via StoryAudio).
# Generic in N (later days). PROCESS_MODE_ALWAYS (the host pauses the game); manual = step(dt) drives it (tests). While it
# runs StageManager.cinematic_active is set, so Esc never opens the pause menu.
class_name StoryCall
extends CanvasLayer

signal finished(skipped: bool)

const GameFXScript: Script = preload("res://scripts/GameFX.gd")

const FADE_IN: float = 0.8
const RING_MAX: float = 6.0
const VOICE_LEN: float = 7.0
const TYPE_FROM: float = 0.6
const TYPE_LEN: float = 5.0
const HANGUP_LEN: float = 1.4
const FADE_OUT: float = 0.8
const ESC_HOLD: float = 0.8
const RED := Color("#FF3B5C")

var days: int = 7
var manual: bool = false
var reduce: bool = false
var force_skip_hold: bool = false
var phase: String = "idle"       # idle | fade | ring | voice | hangup | out | done
var t: float = 0.0               # seconds in the current phase
var total: float = 0.0
var answered_at: float = -1.0
var subtitle: String = ""
var shake_used: bool = false
var flash_used: bool = false
var auto_answered: bool = false
var black: ColorRect
var flash_rect: ColorRect
var screen: PanelContainer
var caller_label: Label
var status_label: Label
var hint_label: Label
var sub_label: Label
var skip_bar: ProgressBar
var loop_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var _hold: float = 0.0
var _shake: float = 0.0
var _screen_pos: Vector2 = Vector2.ZERO
var _ended: bool = false


## opts: manual (step() drives), reduce (default: the "Giảm hù dọa" setting).
func start(n: int, opts: Dictionary = {}) -> void:
	days = n
	manual = bool(opts.get("manual", false))
	reduce = bool(opts.get("reduce", StoryUtil.reduce_scares()))
	layer = 121   # above StageManager.modal_layer / CinePreview (120) and the cinematic overlay (110)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_flag(true)
	_go("fade")


func full_line() -> String:
	return "…Mày… còn… %d ngày…" % days


func _build() -> void:
	black = ColorRect.new()
	black.name = "Black"
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	screen = PanelContainer.new()
	screen.name = "Screen"
	screen.custom_minimum_size = Vector2(300.0, 470.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.06, 1.0)
	sb.border_color = Color("#3A2950")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(34)
	screen.add_theme_stylebox_override("panel", sb)
	screen.modulate.a = 0.0
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(screen)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	screen.add_child(vb)
	caller_label = _label("SỐ LẠ", 40, RED)
	vb.add_child(caller_label)
	vb.add_child(_label("03:00", 30, Color("#E9E1FF")))
	status_label = _label("Cuộc gọi đến…", 18, Color("#B8A9D9"))
	vb.add_child(status_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 60.0)
	vb.add_child(spacer)
	hint_label = _label("[E] / click: nghe máy", 16, Color("#5BD38A"))
	vb.add_child(hint_label)
	sub_label = _label("", 30, Color("#F4E9FF"))
	sub_label.name = "Subtitle"
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sub_label.offset_top = -120.0
	sub_label.offset_bottom = -60.0
	sub_label.offset_left = -520.0
	sub_label.offset_right = 520.0
	sub_label.add_theme_font_override("font", GameFXScript.vice_font(0.5, 0.18))
	add_child(sub_label)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	skip_bar = ProgressBar.new()
	skip_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_bar.offset_left = -220.0
	skip_bar.offset_top = -40.0
	skip_bar.offset_right = -24.0
	skip_bar.offset_bottom = -26.0
	skip_bar.max_value = 1.0
	skip_bar.show_percentage = false
	skip_bar.visible = false
	add_child(skip_bar)
	var skip_hint: Label = _label("Giữ Esc để bỏ qua", 14, Color(0.85, 0.8, 0.95, 0.75))
	skip_hint.name = "SkipHint"
	skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.offset_left = -240.0
	skip_hint.offset_top = -66.0
	skip_hint.offset_right = -24.0
	skip_hint.offset_bottom = -44.0
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(skip_hint)
	loop_player = AudioStreamPlayer.new()
	loop_player.bus = CinePlayer._bus("SFX")
	add_child(loop_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = CinePlayer._bus("SFX")
	add_child(sfx_player)



func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _play_loop(cue: String) -> void:
	loop_player.stream = StoryAudio.stream(cue)
	loop_player.volume_db = StoryAudio.cue_db(cue) - 4.0
	loop_player.play()


func _play(cue: String, db: float = 0.0) -> void:
	sfx_player.stream = StoryAudio.stream(cue)
	sfx_player.volume_db = StoryAudio.cue_db(cue) + db
	sfx_player.play()


func _go(p: String) -> void:
	phase = p
	t = 0.0
	match p:
		"ring":
			_play_loop("phone_ring_3am")
			screen.modulate.a = 1.0
		"voice":
			answered_at = total
			_play("static_burst", -2.0)
			_play_loop("whisper_bed")
			status_label.text = "00:00"
			hint_label.text = ""
			if not reduce:
				_screen_pos = screen.position
				_shake = 0.45
				shake_used = true
				flash_rect.color.a = 0.55
				flash_used = true
		"hangup":
			loop_player.stop()
			_play("call_hangup", -4.0)
			status_label.text = "Cuộc gọi đã kết thúc"
			caller_label.modulate = Color(1, 1, 1, 0.5)
		"out":
			loop_player.stop()
		"done":
			_finish(false)


## [E] / click while ringing.
func answer() -> bool:
	if phase != "ring":
		return false
	_go("voice")
	return true


func _process(delta: float) -> void:
	if manual or phase == "idle" or phase == "done":
		return
	step(delta)


func step(dt: float) -> void:
	if phase == "idle" or phase == "done":
		return
	total += dt
	t += dt
	_skip_logic(dt)
	if phase == "done":
		return
	match phase:
		"fade":
			black.color.a = clampf(t / FADE_IN, 0.0, 1.0)
			if t >= FADE_IN:
				_go("ring")
		"ring":
			screen.modulate.a = 0.75 + 0.25 * absf(sin(t * TAU * 0.9))
			if t >= RING_MAX:
				auto_answered = true
				_go("voice")
		"voice":
			status_label.text = "00:%02d" % int(t)
			var u: float = clampf((t - TYPE_FROM) / TYPE_LEN, 0.0, 1.0)
			var line: String = full_line()
			subtitle = line.substr(0, int(round(u * line.length())))
			sub_label.text = subtitle
			if t >= VOICE_LEN:
				_go("hangup")
		"hangup":
			if t >= HANGUP_LEN:
				_go("out")
		"out":
			var a: float = clampf(1.0 - t / FADE_OUT, 0.0, 1.0)
			black.color.a = a
			screen.modulate.a = a
			sub_label.modulate.a = a
			if t >= FADE_OUT:
				_go("done")
	flash_rect.color.a = maxf(0.0, flash_rect.color.a - dt * 2.0)
	if _shake > 0.0 and screen:
		_shake = maxf(0.0, _shake - dt)
		var k: float = _shake * 18.0
		screen.position = _screen_pos + Vector2(sin(total * 71.0) * k, cos(total * 53.0) * k)
		if _shake <= 0.0:
			screen.position = _screen_pos


func _skip_logic(dt: float) -> void:
	var held: bool = force_skip_hold or (not manual and Input.is_physical_key_pressed(KEY_ESCAPE))
	_hold = _hold + dt if held else 0.0
	skip_bar.visible = _hold > 0.0
	skip_bar.value = _hold / ESC_HOLD
	if _hold >= ESC_HOLD - 1e-6:
		_finish(true)


func _finish(skipped: bool) -> void:
	if _ended:
		return
	_ended = true
	phase = "done"
	if loop_player:
		loop_player.stop()
	if sfx_player and skipped:
		sfx_player.stop()
	_set_flag(false)
	visible = false
	finished.emit(skipped)


func _set_flag(on: bool) -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("cinematic_active", on)


func _input(event: InputEvent) -> void:
	if phase != "ring":
		return
	var hit: bool = false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).physical_keycode == KEY_E:
		hit = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		hit = true
	if hit and answer():
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if not _ended and phase != "idle":
		_set_flag(false)
