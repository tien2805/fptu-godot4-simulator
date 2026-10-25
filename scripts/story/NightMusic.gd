# File: res://scripts/story/NightMusic.gd
# Dynamic Night Building music (spec H-D9): the owner's tracks user://music/night_stealth|night_tense|night_chase|
# night_escape (.ogg|.mp3; a missing file is silence, never code music) follow the level's state:
#   hidden   the player is in a hiding spot (kit.is_hidden()), or the level is "caught" / "released": every track ducks
#            to silence (the heartbeat and breathing SFX stay);
#   escape   doors_unlocked, the optional `alarm` flag (read with `in` / get, the horror polish may add it) or "escaped";
#   chase    any stalker is CHASE (or CHECK: running to the player's spot);
#   tense    any stalker is SUSPICIOUS or SEARCH;
#   stealth  otherwise.
# Polled at 10 Hz from the level's public API only (stalkers[].state, kit, doors_unlocked, state; NightBuilding header),
# so any duck-typed stand-in works (tests). One AudioStreamPlayer per track on the "Music" bus, loaded lazily the first
# time its state comes up, looping; CROSSFADE s crossfades; a track that fades out is paused at zero gain and resumes where
# it left off. Pausable: the pause menu and the replay pause it with the tree.
# Attached by StoryNightEscape (story) and as a child of scenes/story/NightBuilding.tscn (standalone run; the level is the
# parent). manual = true: step(dt) drives it (tests).
class_name NightMusic
extends Node

const STATES: Array[String] = ["stealth", "tense", "chase", "hidden", "escape"]
const TRACKS: Dictionary = {"stealth": "night_stealth", "tense": "night_tense", "chase": "night_chase", "escape": "night_escape"}
const CROSSFADE: float = 1.2
const POLL_DT: float = 0.1

var level: Node = null
var manual: bool = false
var state: String = "stealth"
var state_log: Array[String] = []
var players: Dictionary = {}     # state -> AudioStreamPlayer
var gains: Dictionary = {}       # state -> linear gain 0..1
var loaded: Dictionary = {}      # state -> true once its slot was looked up (file or silence)
var _poll: float = 0.0


## The node StoryNightEscape adds next to its level.
static func for_level(lvl: Node) -> NightMusic:
	var nm := NightMusic.new()
	nm.name = "NightMusic"
	nm.level = lvl
	return nm


func _ready() -> void:
	if level == null and get_parent() and "stalkers" in get_parent():
		level = get_parent()
	for k: String in TRACKS.keys():
		var p := AudioStreamPlayer.new()
		p.name = "Track_" + k
		p.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		p.volume_db = linear_to_db(0.0001)
		add_child(p)
		players[k] = p
		gains[k] = 0.0
	state = compute_state()
	state_log.append(state)
	_refresh_track(state)


func _process(delta: float) -> void:
	if not manual:
		step(delta)


## Advance dt seconds: 10 Hz state poll, then the crossfade.
func step(dt: float) -> void:
	_poll -= dt
	if _poll <= 0.0:
		_poll = POLL_DT
		var ns: String = compute_state()
		if ns != state:
			state = ns
			state_log.append(ns)
			_refresh_track(ns)
	var rate: float = dt / CROSSFADE
	for k: String in TRACKS.keys():
		var goal: float = 1.0 if k == state else 0.0
		var g: float = move_toward(float(gains[k]), goal, rate)
		gains[k] = g
		var p: AudioStreamPlayer = players[k]
		p.volume_db = linear_to_db(maxf(g, 0.0001))
		if g <= 0.0 and goal <= 0.0 and p.playing and not p.stream_paused:
			p.stream_paused = true   # silent: hold the position so the track resumes where it left off


## The level's music state (see the header). Safe before the level is built and after it is freed.
func compute_state() -> String:
	if level == null or not is_instance_valid(level):
		return "stealth"
	var ls: String = String(level.get("state")) if "state" in level else ""
	var kit: Variant = level.get("kit") if "kit" in level else null
	if ls == "caught" or ls == "released":
		return "hidden"
	if kit is Object and is_instance_valid(kit) and (kit as Object).has_method("is_hidden") and bool((kit as Object).call("is_hidden")):
		return "hidden"
	if ls == "escaped" or ("doors_unlocked" in level and bool(level.get("doors_unlocked"))) or ("alarm" in level and bool(level.get("alarm"))):
		return "escape"
	var level_n: int = 0
	var stalkers: Variant = level.get("stalkers") if "stalkers" in level else []
	if stalkers is Array:
		for s: Variant in stalkers:
			if not (s is Object) or not is_instance_valid(s) or not ("state" in s):
				continue
			var st: String = String((s as Object).get("state"))
			if st == "CHASE" or st == "CHECK":
				level_n = 2
				break
			if st == "SUSPICIOUS" or st == "SEARCH":
				level_n = 1
	return ["stealth", "tense", "chase"][level_n]


## The incoming state's track: looked up once (file or silence), then started or resumed from where it stopped.
func _refresh_track(s: String) -> void:
	if not TRACKS.has(s):
		return   # hidden: every track fades to silence
	var p: AudioStreamPlayer = players[s]
	if not loaded.has(s):
		loaded[s] = true
		p.stream = MusicDirector.load_slot(String(TRACKS[s]))
	if p.stream == null:
		return
	if p.stream_paused:
		p.stream_paused = false   # resume where it left off (a paused player reports playing = false)
	elif not p.playing:
		p.play()


func gain(s: String) -> float:
	return float(gains.get(s, 0.0))
