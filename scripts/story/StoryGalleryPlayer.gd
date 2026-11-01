# File: res://scripts/story/StoryGalleryPlayer.gd
# "XEM LẠI PHIM" playback (plan 2026-10-26-chapter-select.md): like CinePreview, FreeRoam with the crowd off plays one
# story cinematic through FreeRoam.play_cinematic, with the owner music (CinePlayer) and the 2D cards StoryRoam adds
# (StoryIntroCards for ai_intro, StoryDayCard for cine_day_start), then goes back to the gallery tab of ChapterSelect.
# The timelines read the protagonist through StoryUtil (StoryDirector active + protagonist): the director is borrowed for
# the playback (the save's protagonist, active) and its exact state is put back afterwards (a choice scene writes
# StoryDirector.choices); nothing here saves, so the story save is never touched. No pause menu (meta no_pause): its
# VỀ MENU CHÍNH would autosave the borrowed state.
class_name StoryGalleryPlayer
extends Node3D

## Slot to play (ChapterSelect.play_cine sets it before the scene change).
static var slot: String = ""
## w4-endings: the slots that follow (ChapterSelect.play_ending: an ending's whole sequence), played one after another.
static var queue: Array[String] = []
## ChapterSelect tab to come back to ("gallery", or "endings" after an ending sequence).
static var return_tab: String = "gallery"

## false (tests): navigation is recorded in last_nav instead of changing scenes.
var nav_enabled: bool = true
var last_nav: String = ""
## Tests: extra CinePlayer opts ({"manual": true, "music": false}).
var cine_opts: Dictionary = {}
## Slots played so far by this player (the sequence, for tests).
var played: Array[String] = []
var freeroam: Node = null
var player: CinePlayer = null
var cards: CanvasLayer = null
var _saved: Dictionary = {}
var _saved_active: bool = false
var _borrowed: bool = false


func _ready() -> void:
	set_meta("no_pause", true)
	freeroam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	freeroam.set("crowd_enabled", false)
	add_child(freeroam)   # built before the director is borrowed: free play (no story layer, no markers)
	call_deferred("_play")


func _play() -> void:
	_borrow()
	var tl: CineTimeline = CineTimeline.load_slot(slot)
	if tl != null:
		player = freeroam.call("play_cinematic", tl, cine_opts.duplicate())
	if player == null:
		_next_or_back()
		return
	played.append(slot)
	if slot == "ai_intro":
		var ic := StoryIntroCards.new()
		ic.name = "IntroCards"
		ic.player = player
		cards = ic
		add_child(ic)
	elif slot == "cine_day_start":
		var dc := StoryDayCard.new()
		dc.name = "DayCard"
		dc.days = int(tl.get("days"))
		dc.left = int(tl.get("left"))
		dc.player = player
		cards = dc
		add_child(dc)
	player.finished.connect(_on_finished, CONNECT_ONE_SHOT)


## The save's protagonist for the timelines (StoryUtil.hero_opts / hero_name), the director's own state kept aside.
func _borrow() -> void:
	var sd: Node = get_node_or_null("/root/StoryDirector")
	if sd == null or _borrowed:
		return
	_saved = sd.call("to_dict")
	_saved_active = bool(sd.get("active"))
	var save: Dictionary = sd.call("read_save", String(sd.get("save_path")))
	var pr: Variant = save.get("protagonist", _saved.get("protagonist", {}))
	sd.set("protagonist", (pr as Dictionary).duplicate(true) if pr is Dictionary else {})
	sd.set("day", 0)   # cine_day_start reads as the Day 1 morning
	sd.set("active", true)
	_borrowed = true


func _restore() -> void:
	if not _borrowed:
		return
	_borrowed = false
	var sd: Node = get_node_or_null("/root/StoryDirector")
	if sd:
		sd.call("from_dict", _saved)
		sd.set("active", _saved_active)


func _on_finished(_skipped: bool) -> void:
	player = null
	if cards:
		cards.queue_free()
		cards = null
	_next_or_back()


## The next slot of the queue (deferred: the finished CinePlayer frees itself first), or back to ChapterSelect.
func _next_or_back() -> void:
	if queue.is_empty():
		_back()
		return
	slot = queue.pop_front()
	call_deferred("_play")


func _back() -> void:
	_restore()
	queue = []
	ChapterSelect.open_tab = return_tab
	return_tab = "gallery"
	last_nav = "chapters"
	if nav_enabled and is_inside_tree():
		get_tree().paused = false
		get_tree().change_scene_to_file(ChapterSelect.SCENE)


func _exit_tree() -> void:
	_restore()
