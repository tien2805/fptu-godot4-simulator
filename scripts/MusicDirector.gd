# File: res://scripts/MusicDirector.gd
# Background music from the owner's files only (spec H-D8, "tuyệt đối không xài nhạc code nữa"): every slot plays
# user://music/<slot>.ogg or .mp3 (local, never committed or exported), looping; a missing file means silence. There is
# no synthesis anywhere in this file.
# Two AudioStreamPlayers crossfade (CROSSFADE s) on the bus "MusicBed" (send -> "Music", so the settings volume applies),
# which carries one low-pass filter. Tension 0..1 (stage 1 speed and near-miss chain, capstone boss HP) maps to volume
# (tension_db) and the low-pass cutoff (tension_cutoff), smoothed; it never changes the notes.
# GameFX creates one node at startup:  GameFX.music_play("stage1_race", 0.3) · GameFX.music_tension(0.7) · GameFX.music_stop()
# Statics (NightMusic, tests): SLOTS / all_slots(), slot_file, load_slot, roam_slot(tod), tension_db, tension_cutoff.
# Streams load lazily on play (OGG streams from disk; an MP3 file is read into memory), never on a worker thread.
class_name MusicDirector
extends Node

const BUS: String = "MusicBed"
const CROSSFADE: float = 1.2
## Slots the MusicDirector plays (menu, free roam, stages, story missions).
const SLOTS: Array[String] = ["menu", "roam_day", "roam_night",
	"stage1_race", "stage2_parking", "stage3_classroom", "stage4_vovinam", "stage5_canteen", "stage6_capstone", "stage_extra_exam",
	"mission_stakeout", "mission_chase", "mission_fight", "mission_canteen", "mission_corridor"]
## Night Building tracks (NightMusic).
const NIGHT_SLOTS: Array[String] = ["night_stealth", "night_tense", "night_chase", "night_escape"]
## Short replays (CineReplay through StoryStage.play_replay; they have no timeline file).
const REPLAY_SLOTS: Array[String] = ["seg_d0_race", "seg_d0_exam", "seg_d1_chase", "seg_d4_escape"]
const TENSION_DB_MIN: float = -4.5
const CUTOFF_MIN: float = 5000.0
const CUTOFF_OPEN: float = 20000.0
const CUTOFF_OPEN_AT: float = 0.6

## Tests only: slot -> AudioStream used instead of the owner's file (crossfade / resume checks without user://music).
static var test_streams: Dictionary = {}

var slot: String = ""            # requested slot ("" = stopped); kept while it fades out
var target_gain: float = 0.0     # 1 while a slot plays, 0 after stop()
var tension: float = 0.0
var fade_time: float = CROSSFADE
var players: Array[AudioStreamPlayer] = []
var gains := PackedFloat32Array([0.0, 0.0])   # crossfade gain per player (linear)
var goals := PackedFloat32Array([0.0, 0.0])
var cur: int = 0                 # index of the incoming / current player
var _tension_cur: float = 0.0
var _filter: AudioEffectLowPassFilter
var _cutoff_set: float = -1.0


# ---------------------------------------------------------------------------
# Slots
# ---------------------------------------------------------------------------
## Every music slot of the game: the MusicDirector ones, the night tracks, the cinematic timelines, the short replays.
static func all_slots() -> PackedStringArray:
	var out: PackedStringArray = []
	for s: String in SLOTS + NIGHT_SLOTS:
		out.append(s)
	for s2: String in CineTimeline.slots():
		var tl: CineTimeline = CineTimeline.load_slot(s2)
		var ms: String = tl.music_slot if tl and tl.music_slot != "" else s2
		if not out.has(ms):
			out.append(ms)
	for s3: String in REPLAY_SLOTS:
		if not out.has(s3):
			out.append(s3)
	return out


## The owner's file for a slot (user://music/<slot>.ogg, then .mp3), "" = silence.
static func slot_file(s: String) -> String:
	return CineAudio.music_file(s)


## The slot's stream, looping (null = silence). A fresh stream each call (the caller owns it).
static func load_slot(s: String) -> AudioStream:
	if test_streams.has(s):
		return test_streams[s]
	var p: String = slot_file(s)
	if p == "":
		return null
	var st: AudioStream = CineAudio._load_file(p)
	if st and "loop" in st:
		st.set("loop", true)
	return st


## Free roam slot for a FreeRoam time-of-day preset: "night" -> roam_night, every other preset (sunset too) -> roam_day.
static func roam_slot(tod: String) -> String:
	return "roam_night" if tod == "night" else "roam_day"   # GameFX.TOD_ALIASES never maps to or from "night"


## Tension -> volume offset (dB): TENSION_DB_MIN at 0, 0 dB at 1.
static func tension_db(t: float) -> float:
	return lerpf(TENSION_DB_MIN, 0.0, clampf(t, 0.0, 1.0))


## Tension -> low-pass cutoff (Hz): CUTOFF_MIN at 0, rising exponentially, fully open from CUTOFF_OPEN_AT.
static func tension_cutoff(t: float) -> float:
	var u: float = clampf(t / CUTOFF_OPEN_AT, 0.0, 1.0)
	return CUTOFF_MIN * pow(CUTOFF_OPEN / CUTOFF_MIN, u)


## The bus every bed track plays on (created on first use, sends to "Music" or "Master").
static func ensure_bus() -> int:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx >= 0:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = CUTOFF_OPEN
	AudioServer.add_bus_effect(idx, lp)
	return idx


# ---------------------------------------------------------------------------
# Playback
# ---------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var idx: int = ensure_bus()
	for i: int in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectLowPassFilter:
			_filter = AudioServer.get_bus_effect(idx, i)
	for i2: int in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Track%d" % i2
		p.bus = BUS
		add_child(p)
		players.append(p)


## Crossfades to `s` (fade s). Same slot already playing: nothing; same slot fading out: it fades back in. No owner file:
## the current track fades out and the slot is silent.
func play(s: String, fade: float = CROSSFADE) -> void:
	if s == "":
		stop(true)
		return
	if players.is_empty():
		return
	fade_time = maxf(fade, 0.0)
	if s == slot and players[cur].playing:
		target_gain = 1.0
		goals[cur] = 1.0
		return
	if s == slot and target_gain > 0.0:
		return   # the silent slot (no file) is already "playing"
	slot = s
	target_gain = 1.0
	for i: int in 2:
		goals[i] = 0.0
	var st: AudioStream = load_slot(s)
	var nxt: int = 1 - cur
	if players[cur].playing and not players[nxt].playing:
		cur = nxt   # the free player takes the new track; the old one fades out
	elif players[cur].playing:
		players[nxt].stop()   # both busy (fast switches): the older fade is cut, the newer one fades out
		gains[nxt] = 0.0
		cur = nxt
	var p: AudioStreamPlayer = players[cur]
	p.stop()
	p.stream = st
	gains[cur] = 0.0
	if st:
		goals[cur] = 1.0
		if fade_time <= 0.0:
			gains[cur] = 1.0
		p.play()
	if fade_time <= 0.0:
		for i2: int in 2:
			if i2 != cur:
				gains[i2] = 0.0
				players[i2].stop()
	_apply_volumes()


func stop(fade: bool = true) -> void:
	target_gain = 0.0
	for i: int in 2:
		goals[i] = 0.0
	if not fade:
		for i2: int in 2:
			gains[i2] = 0.0
			if players.size() > i2:
				players[i2].stop()
				players[i2].stream = null
		slot = ""


func set_tension(v: float) -> void:
	tension = clampf(v, 0.0, 1.0)


## The stream of the current slot (null = silence or stopped).
func current_stream() -> AudioStream:
	return players[cur].stream if not players.is_empty() else null


func is_audible() -> bool:
	return not players.is_empty() and players[cur].playing and gains[cur] > 0.0


func _process(delta: float) -> void:
	if players.is_empty():
		return
	_tension_cur = lerpf(_tension_cur, tension, minf(1.0, delta * 1.5))
	var rate: float = delta / fade_time if fade_time > 0.0 else 1.0
	for i: int in 2:
		gains[i] = move_toward(gains[i], goals[i], rate)
		if gains[i] <= 0.0 and goals[i] <= 0.0 and players[i].playing:
			players[i].stop()
			players[i].stream = null
	if target_gain <= 0.0 and not players[0].playing and not players[1].playing:
		slot = ""
	_apply_volumes()


func _apply_volumes() -> void:
	var tdb: float = tension_db(_tension_cur)
	for i: int in 2:
		players[i].volume_db = linear_to_db(maxf(gains[i], 0.0001)) + tdb
	if _filter:
		var c: float = tension_cutoff(_tension_cur)
		if absf(c - _cutoff_set) > 1.0:
			_filter.cutoff_hz = c
			_cutoff_set = c
