# File: res://scripts/story/StoryEndingRunner.gd
# Plays an "ending": "auto" beat (d7_ending, plan 2026-11-01-w4-endings.md T1) in story free roam: StoryRoam adds one as
# its child instead of playing the beat's own slot. It resolves the letter once (StoryDirector.resolve_ending), plays
# StoryEndings.slots(X) one after another (a video slot: the owner's clip through StoryVideo when it exists and decodes,
# else its in-engine fallback timeline, like ai_intro), then shows StoryEndSummary over the paused world, then emits done;
# StoryRoam completes the beat, so StoryDirector.finish_story(X) marks the save finished and opens the main menu.
# Each cinematic goes through StoryRoam._start_cinematic (staging, the gallery mark, the owner music slot); a slot that
# cannot play (no timeline, no stage spot) is skipped, never blocking the ending. played = the slots that ran (tests).
class_name StoryEndingRunner
extends Node

signal done(letter: String)

var story: Node = null          # StoryRoam
var roam: Node = null           # FreeRoam
var director: Node = null       # StoryDirector
var beat: Dictionary = {}
var letter: String = ""
var queue: Array[String] = []
var index: int = -1
var played: Array[String] = []
var summary: StoryEndSummary = null
var video: StoryVideo = null
var finished: bool = false


func setup(s: Node, b: Dictionary) -> void:
	name = "EndingRunner"
	story = s
	roam = s.get("roam")
	director = s.get("director")
	beat = b
	process_mode = Node.PROCESS_MODE_ALWAYS


func start() -> void:
	letter = String(director.call("resolve_ending", beat)) if director else "E"
	queue = StoryEndings.slots(letter)
	index = -1
	_next()


func current_slot() -> String:
	return queue[index] if index >= 0 and index < queue.size() else ""


func _next() -> void:
	if finished:
		return
	index += 1
	if index >= queue.size():
		_show_summary()
		return
	var slot: String = queue[index]
	if StoryEndings.is_video(slot) and _play_video(slot):
		return
	_play_timeline(slot)


func _play_timeline(slot: String) -> void:
	var cp: CinePlayer = story.call("_start_cinematic", slot, "")
	if cp == null:
		_next.call_deferred()   # never block the ending on a missing timeline / stage spot
		return
	played.append(slot)
	roam.connect("cinematic_finished", _on_cine_done, CONNECT_ONE_SHOT)


func _on_cine_done(_slot: String, _skipped: bool) -> void:
	if story and story.has_method("_free_cards"):
		story.call("_free_cards")
	_next.call_deferred()


func _female() -> bool:
	return director != null and bool((director.get("protagonist") as Dictionary).get("female", false))


## The owner's AI clip of `slot`; false when there is none (the fallback timeline plays instead).
func _play_video(slot: String) -> bool:
	var path: String = StoryVideo.video_file(slot, _female())
	if path == "":
		return false
	video = StoryVideo.new()
	video.name = "StoryVideo"
	add_child(video)
	if not video.play_file(path):
		video.queue_free()
		video = null
		return false
	StoryChapters.mark_cine(slot)   # the gallery plays the in-engine version of the clip
	played.append(slot)
	story.call("_pause", true)
	story.call("_music", false)
	video.finished.connect(_on_video_done.bind(slot), CONNECT_ONE_SHOT)
	return true


func _on_video_done(_skipped: bool, slot: String) -> void:
	var v: StoryVideo = video
	video = null
	if v and v.left_tree:
		return   # the window / scene closed mid-clip: the beat is not done, Continue plays the ending again
	story.call("_pause", false)
	if v and v.failed:
		_play_timeline(slot)   # the owner's file could not be decoded or stalled: the in-engine fallback
		return
	_next.call_deferred()


func _show_summary() -> void:
	story.call("_pause", true)
	summary = StoryEndSummary.new()
	add_child(summary)
	summary.show_for(letter, director.call("ending_state") if director else {}, director.get("ranks") if director else {})
	summary.closed.connect(_on_summary_closed, CONNECT_ONE_SHOT)


func _on_summary_closed() -> void:
	finished = true
	story.call("_pause", false)
	done.emit(letter)
