# File: res://scripts/MusicDirector.gd
# Background music from the owner's files only (spec H-D8, "tuyệt đối không xài nhạc code nữa"): every slot plays
# user://music/<slot>.ogg or .mp3 (local, never committed or exported), looping; a missing file means silence. There is
# no synthesis anywhere in this file.
# Two AudioStreamPlayers crossfade (CROSSFADE s) on the bus "MusicBed" (send -> "Music", so the settings volume applies),
# which carries one low-pass filter. Tension 0..1 maps to volume (tension_db) for every slot and, only for TENSION_SLOTS
# (stage 1 speed and near-miss chain, the capstone boss HP), to the low-pass cutoff (tension_cutoff); it never changes the
# notes. SLOT_DB: fixed per-slot trims (mission_canteen -6 dB so Dolly's hum stays audible). duck(on): a replay with its
# own track fades the bed out (players keep running) and back in. RESUME_SLOTS (free roam) continue where they stopped.
# GameFX creates one node at startup:  GameFX.music_play("stage1_race", 0.3) · GameFX.music_tension(0.7) · GameFX.music_stop()
# Loading (review I2): both OGG and MP3 are read and parsed whole (an 8-50 MB file is tens of ms or more), so streams live
# in a small static cache and warm(slots) loads them on WorkerThreadPool tasks ahead of time (FreeRoam warms both roam
# tracks, StoryRoam the next mission track, NightMusic the four night tracks). load_slot() takes the cached stream, waits
# for a pending task, and only reads on the main thread as a last resort (counted in main_thread_loads).
# Statics (NightMusic, tests): SLOTS / all_slots(), slot_file, load_slot, warm, is_warm, roam_slot(tod), tension_db,
# tension_cutoff.
class_name MusicDirector
extends Node

const BUS: String = "MusicBed"
const CROSSFADE: float = 1.2
const DUCK_TIME: float = 0.3
## Slots the MusicDirector plays (menu, free roam, stages, story missions).
const SLOTS: Array[String] = ["menu", "roam_day", "roam_night",
	"stage1_race", "stage2_parking", "stage3_classroom", "stage4_vovinam", "stage5_canteen", "stage6_capstone", "stage_extra_exam",
	"mission_stakeout", "mission_chase", "mission_fight", "mission_canteen", "mission_corridor",
	# Phase C (spec C-D11): missions, bosses and the coffin-dance meme of Days 2, 3 and 5
	"mission_bike_chase", "boss_d2", "mission_sneak", "mission_gunfight", "meme_coffin_dance", "boss_d3", "mission_basement",
	"mission_gunfight_d5", "mission_typing", "boss_d5",
	# Day 2 Tokyo Drift (plan 2026-10-27-d2x-drift.md): the drift duel with Sói Xám
	"race_d2_drift"]
## Night Building tracks (NightMusic).
const NIGHT_SLOTS: Array[String] = ["night_stealth", "night_tense", "night_chase", "night_escape"]
## Short replays (CineReplay through StoryStage.play_replay; they have no timeline file).
const REPLAY_SLOTS: Array[String] = ["seg_d0_race", "seg_d0_exam", "seg_d1_chase", "seg_d4_escape",
	"seg_d2_chase", "seg_d3_gunfight", "seg_d3_crates", "seg_d5_gunfight", "seg_d5_hack"]
## Slots whose tension also drives the low-pass (the others play with the filter open).
const TENSION_SLOTS: Array[String] = ["stage1_race", "stage6_capstone"]
## Fixed per-slot trims in dB.
const SLOT_DB: Dictionary = {"mission_canteen": -6.0}
## Slots that resume where they stopped instead of restarting from 0:00.
const RESUME_SLOTS: Array[String] = ["roam_day", "roam_night"]
const TENSION_DB_MIN: float = -4.5
const CUTOFF_MIN: float = 5000.0
const CUTOFF_OPEN: float = 20000.0
const CUTOFF_OPEN_AT: float = 0.6
const CACHE_MAX: int = 8

## Tests only: slot -> AudioStream used instead of the owner's file (no cache; also read by CineAudio.load_music).
static var test_streams: Dictionary = {}
## Tests only: Callable(slot) -> AudioStream standing in for the file reader (goes through the cache and warm()).
static var test_loader: Callable = Callable()
## Loads done on the main thread inside load_slot (a warmed slot never adds one).
static var main_thread_loads: int = 0
static var _cache: Dictionary = {}     # slot -> AudioStream (looping), insertion order = age
static var _pending: Dictionary = {}   # slot -> {task, box}
static var _resume: Dictionary = {}    # slot -> playback position (s) for RESUME_SLOTS

var slot: String = ""            # requested slot ("" = stopped); kept while it fades out
var target_gain: float = 0.0     # 1 while a slot plays, 0 after stop()
var tension: float = 0.0
var fade_time: float = CROSSFADE
var players: Array[AudioStreamPlayer] = []
var gains := PackedFloat32Array([0.0, 0.0])   # crossfade gain per player (linear)
var goals := PackedFloat32Array([0.0, 0.0])
var player_slots: Array[String] = ["", ""]    # slot each player holds
var cur: int = 0                 # index of the incoming / current player
var duck_gain: float = 1.0
var duck_target: float = 1.0
var _duck_time: float = DUCK_TIME
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


## The owner's file for a slot (user://music/<slot>.ogg, then .mp3, then CineAudio.SLOT_FALLBACK), "" = silence.
static func slot_file(s: String) -> String:
	return CineAudio.music_file(s)


## The slot's looping stream (null = silence), from the cache / a pending warm task, else read now on the main thread.
static func load_slot(s: String) -> AudioStream:
	if test_streams.has(s):
		return test_streams[s]
	poll()
	if _pending.has(s):
		_adopt(s, true)
	if _cache.has(s):
		var st: AudioStream = _cache[s]
		_cache.erase(s)
		_cache[s] = st   # most recently used goes last
		return st
	if not test_loader.is_valid() and slot_file(s) == "":
		return null
	main_thread_loads += 1
	var st2: AudioStream = _read(s)
	if st2:
		_store(s, st2)
	return st2


## Starts a WorkerThreadPool task per slot that is neither cached, pending nor without a file. Returns the tasks started.
static func warm(slots: Array) -> int:
	poll()
	var n: int = 0
	for v: Variant in slots:
		var s: String = String(v)
		if s == "" or test_streams.has(s) or _cache.has(s) or _pending.has(s):
			continue
		if not test_loader.is_valid() and slot_file(s) == "":
			continue
		var box: Array = [null]
		_pending[s] = {"task": WorkerThreadPool.add_task(_warm_job(box, s, test_loader)), "box": box}
		n += 1
	return n


## true when the slot is cached (or has nothing to load).
static func is_warm(s: String) -> bool:
	poll()
	return _cache.has(s) or test_streams.has(s) or (not _pending.has(s) and not test_loader.is_valid() and slot_file(s) == "")


## Adopts finished warm tasks (main thread). Called by load_slot / warm and every MusicDirector frame.
static func poll() -> void:
	for s: String in _pending.keys():
		if WorkerThreadPool.is_task_completed(int((_pending[s] as Dictionary)["task"])):
			_adopt(s, false)


## Waits for every pending task (exit, tests) and empties the cache.
static func clear_cache() -> void:
	for s: String in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(int((_pending[s] as Dictionary)["task"]))
	_pending.clear()
	_cache.clear()
	_resume.clear()


static func _warm_job(box: Array, s: String, loader: Callable) -> Callable:
	return func() -> void: box[0] = loader.call(s) if loader.is_valid() else _read_file(s)


static func _adopt(s: String, _waiting: bool) -> void:
	var t: Dictionary = _pending[s]
	WorkerThreadPool.wait_for_task_completion(int(t["task"]))
	_pending.erase(s)
	var st: AudioStream = (t["box"] as Array)[0]
	if st:
		_store(s, st)


static func _read(s: String) -> AudioStream:
	return test_loader.call(s) if test_loader.is_valid() else _read_file(s)


## Pure file read (worker-safe): the slot's file as a looping stream, or null.
static func _read_file(s: String) -> AudioStream:
	var p: String = CineAudio.music_file(s)
	if p == "":
		return null
	var st: AudioStream = CineAudio._load_file(p)
	if st and "loop" in st:
		st.set("loop", true)
	return st


static func _store(s: String, st: AudioStream) -> void:
	_cache[s] = st
	while _cache.size() > CACHE_MAX:
		_cache.erase(_cache.keys()[0])


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
		p.volume_db = -80.0
		add_child(p)
		players.append(p)


func _exit_tree() -> void:
	for s: String in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(int((_pending[s] as Dictionary)["task"]))
	_pending.clear()


## Crossfades to `s` (fade s). Same slot already playing: nothing; same slot fading out: it fades back in. No owner file:
## the current track fades out and the slot is silent. Both players busy (a switch inside a crossfade): the quieter one
## is reused, the louder keeps fading out (no hard cut).
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
	if players[cur].playing:
		if players[nxt].playing and gains[nxt] > gains[cur]:
			_halt(cur)          # the incoming track barely started: reuse it, the older louder one keeps fading
		else:
			if players[nxt].playing:
				_halt(nxt)
			cur = nxt
	var p: AudioStreamPlayer = players[cur]
	_halt(cur)
	p.stream = st
	player_slots[cur] = s
	gains[cur] = 0.0
	if st:
		goals[cur] = 1.0
		if fade_time <= 0.0:
			gains[cur] = 1.0
		p.volume_db = -80.0 if fade_time > 0.0 else _slot_db(cur)   # never a blip at the reused player's old level
		var from: float = float(_resume.get(s, 0.0)) if RESUME_SLOTS.has(s) else 0.0
		p.play(from if from < st.get_length() - 1.0 else 0.0)
	if fade_time <= 0.0:
		for i2: int in 2:
			if i2 != cur:
				gains[i2] = 0.0
				_halt(i2)
	_apply_volumes()


func stop(fade: bool = true) -> void:
	target_gain = 0.0
	for i: int in 2:
		goals[i] = 0.0
	if not fade:
		for i2: int in 2:
			gains[i2] = 0.0
			if players.size() > i2:
				_halt(i2)
		slot = ""


func set_tension(v: float) -> void:
	tension = clampf(v, 0.0, 1.0)


## Replays with their own track: the bed fades to silence over `time` (players keep running) and back on release.
func duck(on: bool, time: float = DUCK_TIME) -> void:
	duck_target = 0.0 if on else 1.0
	if time <= 0.0:
		duck_gain = duck_target
	_duck_time = maxf(time, 0.0)
	_apply_volumes()



## The stream of the current slot (null = silence or stopped).
func current_stream() -> AudioStream:
	return players[cur].stream if not players.is_empty() else null


func is_audible() -> bool:
	return not players.is_empty() and players[cur].playing and gains[cur] > 0.0 and duck_gain > 0.0


func _process(delta: float) -> void:
	if players.is_empty():
		return
	poll()
	_tension_cur = lerpf(_tension_cur, tension, minf(1.0, delta * 1.5))
	var rate: float = delta / fade_time if fade_time > 0.0 else 1.0
	duck_gain = move_toward(duck_gain, duck_target, delta / _duck_time if _duck_time > 0.0 else 1.0)
	for i: int in 2:
		gains[i] = move_toward(gains[i], goals[i], rate)
		if gains[i] <= 0.0 and goals[i] <= 0.0 and players[i].playing:
			_halt(i)
	if target_gain <= 0.0 and not players[0].playing and not players[1].playing:
		slot = ""
	_apply_volumes()


## Stops player i, remembering where a RESUME_SLOTS track was, and releases its stream.
func _halt(i: int) -> void:
	var p: AudioStreamPlayer = players[i]
	if p.playing and RESUME_SLOTS.has(player_slots[i]):
		_resume[player_slots[i]] = p.get_playback_position()
	p.stop()
	p.stream = null
	p.volume_db = -80.0


func _slot_db(i: int) -> float:
	return float(SLOT_DB.get(player_slots[i], 0.0)) + tension_db(_tension_cur)


func _apply_volumes() -> void:
	for i: int in 2:
		players[i].volume_db = linear_to_db(maxf(gains[i] * duck_gain, 0.0001)) + _slot_db(i)
	if _filter:
		var c: float = tension_cutoff(_tension_cur) if TENSION_SLOTS.has(player_slots[cur]) else CUTOFF_OPEN
		if absf(c - _cutoff_set) > 1.0:
			_filter.cutoff_hz = c
			_cutoff_set = c
