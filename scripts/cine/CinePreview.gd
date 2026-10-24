# File: res://scripts/cine/CinePreview.gd
# Dev preview of one cinematic in the real world (owner only; agents never run it):
#   godot --path . res://scenes/dev/CinePreview.tscn          (slot from CINE_SLOT, default seg_d1_brawl; CINE_DEBUG=1)
# Builds FreeRoam (no crowd) and plays the slot through FreeRoam.play_cinematic. R replays, F10 toggles the debug read-out.
extends Node3D

var slot: String = "seg_d1_brawl"
var freeroam: Node = null
var player: CinePlayer = null
var _layer: CanvasLayer
var _label: Label


func _ready() -> void:
	var env_slot: String = OS.get_environment("CINE_SLOT")
	if env_slot != "":
		slot = env_slot
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.visible = false
	_layer.add_child(_label)
	freeroam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	freeroam.set("crowd_enabled", false)
	add_child(freeroam)
	call_deferred("_play")


func _play() -> void:
	var tl: CineTimeline = CineTimeline.load_slot(slot)
	if tl == null:
		_label.text = "Không có cinematic %s" % slot
		_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_label.visible = true
		return
	_label.visible = false
	player = freeroam.call("play_cinematic", tl, {"debug": OS.get_environment("CINE_DEBUG") == "1"})
	if player == null:
		_show_help(tl)
		return
	player.finished.connect(_on_finished.bind(tl))


func _on_finished(_skipped: bool, tl: CineTimeline) -> void:
	player = null
	_show_help(tl)


func _show_help(tl: CineTimeline) -> void:
	var folder: String = ProjectSettings.globalize_path(CineAudio.MUSIC_DIR)
	var has_file: bool = CineAudio.music_file(tl.music_slot) != ""
	_label.text = "R: xem lại · F10: debug · nhạc: %s%s.ogg|.mp3 (%s)" % [folder, tl.music_slot, "có file" if has_file else "nhạc tổng hợp"]
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position = Vector2(16.0, get_viewport().get_visible_rect().size.y - 40.0)
	_label.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_R and player == null:
		_play()
		get_viewport().set_input_as_handled()
