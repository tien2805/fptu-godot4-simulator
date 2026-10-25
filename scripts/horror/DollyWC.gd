# File: res://scripts/horror/DollyWC.gd
# Dolly's toilet monologue in the Night Building (owner request): when Dolly comes for a player hiding in a toilet stall,
# she plays the owner's escalating monologue once ("Hello?" -> "Are you pooping?" -> "Hello... I know you're pooping." ->
# "That smells good."), as positional audio from her head, and the time table TABLE drives what she does:
#   0.0 s  she enters the toilet block                       "Alô?"
#   2.6 s  knocks on the first stall                         "Đang đi ỉa đấy à?"
#   6.7 s  knocks on the next stall
#   12.7 s arrives at the player's stall and knocks          "Alô... tao biết mày đang ỉa mà."
#   15.8 s                                                   "Thơm phết đấy."
#   17.8 s outcome: she saw the player enter, the breath was not held at the stall (from the player's knock + BREATH_GRACE
#          to the outcome) or a gasp happened -> she catches (the stall catch scare); otherwise she sniffs and walks away
#          (deaf to the player for HorrorStalker.DEAF_AFTER_S).
# Who performs (owner playtest: the clones too, the owner cannot tell Dolly from them): any of the four hunters, the first
# that qualifies (one monologue at a time); the voice is positional from it, only Dolly pauses and resumes her hum, the
# catch shows its face (a clone's mask for a clone). The other hunters keep hunting but cannot check the player's stall
# until the outcome (HorrorStalker.blocked_spot), so nothing cuts the scene short. `performer` is the one now.
# The file is user://sfx/dolly_wc_full.ogg (else .mp3, else .wav; StoryAudio.owner_stream; never committed). Without it
# the same timings run with the subtitles alone. Only for a player hidden in a
# stall of that block (an empty block does nothing), every time she comes: seen (Dolly checks the stall she saw the player
# enter, or heard them in) or unseen (her patrol / search walks into the block while the player hides in one of its
# stalls; after she leaves, a new visit needs her to have left the block first). The catch comes only at the outcome mark,
# after the monologue's last line: the stall scare (the head pops up over the partition, the duck and the loud sting of
# ScareDirector); the monologue tail is ducked and stops when the scare ends. "Giảm hù dọa" keeps the monologue and the
# knocks; the catch is the soft variant. Dolly is scripted meanwhile (state CHECK, moves to the knock spots in time);
# seeing the player out of the stall ends it (CHASE). abort() stops the monologue (catch by another, retry, escape,
# release); the tree pause pauses it.
# The heartbeat ramps up by itself as she comes closer.
# Plain subtitles (no emoji or decorative symbols; "..." for the ellipsis). Retune TABLE after listening.
class_name DollyWC
extends Node

signal started(seen: bool)
signal finished(outcome: String)   # "catch" | "leave" | "abort"

const FILE: String = "dolly_wc_full"
## The time table (s from the start of the monologue): act "enter" | "knock" | "player_knock" | "outcome" | "" and the
## subtitle shown from that mark ("" = none).
const TABLE: Array[Dictionary] = [
	{"t": 0.0, "act": "enter", "sub": "Alô?"},
	{"t": 2.6, "act": "knock", "sub": "Đang đi ỉa đấy à?"},
	{"t": 6.7, "act": "knock", "sub": ""},
	{"t": 12.7, "act": "player_knock", "sub": "Alô... tao biết mày đang ỉa mà."},
	{"t": 15.8, "act": "", "sub": "Thơm phết đấy."},
	{"t": 17.8, "act": "outcome", "sub": ""},
]
## Seconds after the player's knock before an unheld breath counts (time to press Shift).
const BREATH_GRACE: float = 0.5
const SUB_MAX_S: float = 4.0
const SPEED_MIN: float = 1.0
const SPEED_MAX: float = 4.5

var level: Node = null          # NightBuilding
## Every hunter that may perform (all four: the owner cannot tell Dolly from the clones) and the one performing now.
var hunters: Array[HorrorStalker] = []
var performer: HorrorStalker = null
## Per hunter (instance id) the block of its last unseen visit: no new unseen visit there until it has left that block.
var _cool: Dictionary = {}
var kit: HorrorKit = null
var scare: ScareDirector = null
var hud: HorrorHUD = null
var stream: AudioStream = null
var voice: AudioStreamPlayer3D = null
var running: bool = false
var t: float = 0.0
var seen: bool = false
var heard: bool = false
var gasped: bool = false
var outcome: String = ""
var spot: HidingSpot = null              # the player's stall
var targets: Array[HidingSpot] = []      # knock order: two other stalls, then the player's
## The block of the last unseen visit: no new unseen visit there until Dolly has left it.
var cool_block: String = ""
## Visits so far (tests).
var visits: int = 0
## Tests: "start:<seen|unseen>:<block>@t", "sub:<text>@t", "knock:<spot>@t", "outcome:<catch|leave>@t", "abort@t".
var log: Array[String] = []
var _next: int = 0
var _knock_i: int = 0


func _init() -> void:
	name = "DollyWC"


func setup(lvl: Node, hs: Array, k: HorrorKit, sd: ScareDirector, h: HorrorHUD) -> void:
	level = lvl
	hunters.clear()
	for x: Variant in hs:
		hunters.append(x as HorrorStalker)
	kit = k
	scare = sd
	hud = h
	stream = StoryAudio.owner_stream(FILE)
	kit.gasped.connect(_on_gasp)


static func table_time(act: String) -> float:
	for e: Dictionary in TABLE:
		if String(e["act"]) == act:
			return float(e["t"])
	return -1.0


## The knock marks in order (the last is the player's stall).
static func knock_marks() -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in TABLE:
		if String(e["act"]) in ["knock", "player_knock"]:
			out.append(float(e["t"]))
	return out


static func block_of(s: HidingSpot) -> String:
	return String(s.get_meta("room", "")) if s != null and s.kind == "stall" else ""


static func in_block(p: Vector3, block: String) -> bool:
	var r: Dictionary = NightBuildingMap.room_by_id(block)
	if r.is_empty():
		return false
	var z: float = p.z * float(r["side"])
	return p.x >= float(r["x0"]) and p.x <= float(r["x1"]) and z >= NightBuildingMap.COR_Z and z <= NightBuildingMap.OUT_Z


## Every physics frame from the level while it plays: the first hunter that comes for the hidden player starts the
## monologue (one at a time).
func watch() -> void:
	if running or not kit.is_hidden():
		return
	var sp: HidingSpot = kit.hidden_spot
	var block: String = block_of(sp)
	for h: HorrorStalker in hunters:
		if not is_instance_valid(h) or h.frozen or h.scripted:
			continue
		var hid: int = h.get_instance_id()
		if _cool.has(hid) and not in_block(h.global_position, String(_cool[hid])):
			_cool.erase(hid)
		if block == "":
			continue
		if h.state == HorrorStalker.CHECK and h.check_spot == sp:
			start(sp, true, h)   # it saw the player go in (or heard them in there)
			return
		if String(_cool.get(hid, "")) != block and h.state in [HorrorStalker.PATROL, HorrorStalker.SUSPICIOUS, HorrorStalker.SEARCH] \
				and in_block(h.global_position, block):
			start(sp, false, h)
			return


func start(sp: HidingSpot, was_seen: bool, who: HorrorStalker = null) -> bool:
	var block: String = block_of(sp)
	if who == null:
		who = hunters[0] if not hunters.is_empty() else null
	if block == "" or who == null or not who.begin_script(sp):
		return false
	performer = who
	visits += 1
	cool_block = block
	_cool[who.get_instance_id()] = block
	for h: HorrorStalker in hunters:   # the others keep hunting, but leave this stall alone until the outcome
		if h != who and is_instance_valid(h):
			h.blocked_spot = sp
	spot = sp
	seen = was_seen
	heard = false
	gasped = false
	outcome = ""
	t = 0.0
	_next = 0
	_knock_i = 0
	var others: Array[HidingSpot] = []
	for s: HidingSpot in kit.spots:
		if s != sp and block_of(s) == block:
			others.append(s)
	var dp: Vector3 = performer.global_position
	others.sort_custom(func(a: HidingSpot, b: HidingSpot) -> bool: return a.exit_point().distance_squared_to(dp) < b.exit_point().distance_squared_to(dp))
	targets.clear()
	for i: int in mini(2, others.size()):
		targets.append(others[i])
	targets.append(sp)
	running = true
	if performer.is_dolly:
		performer.set_hum(false)
	if stream != null:
		if voice == null or not is_instance_valid(voice):
			voice = AudioStreamPlayer3D.new()
			voice.name = "WCVoice"
			voice.position = Vector3(0.0, 1.55, 0.0)
			voice.max_distance = HorrorStalker.HUM_MAX_M
			voice.unit_size = 6.0
			if AudioServer.get_bus_index("SFX") != -1:
				voice.bus = "SFX"
			scare.register_duck(voice)
		if voice.get_parent() != performer:   # positional from whoever performs
			if voice.get_parent() != null:
				voice.get_parent().remove_child(voice)
			performer.add_child(voice)
		voice.volume_db = 0.0
		voice.stream = stream
		voice.play()
	log.append("start:%s:%s@%.1f" % ["seen" if seen else "unseen", block, t])
	started.emit(seen)
	_fire_due()
	return true


func _on_gasp(_reason: String) -> void:
	if running:
		gasped = true


## Advances the time table (from _physics_process; the tree pause stops it with the voice).
func tick(delta: float) -> void:
	if not running:
		return
	if String(level.get("state")) != "play" or not is_instance_valid(performer) or not performer.scripted:
		abort()   # caught by another, retry, escape, release, or she saw the player out of the stall (CHASE)
		return
	t += delta
	var pk: float = table_time("player_knock")
	if t >= pk + BREATH_GRACE and kit.is_hidden() and kit.hidden_spot == spot and not kit.breath_held:
		heard = true
	_fire_due()


func _fire_due() -> void:
	while running and _next < TABLE.size() and t >= float(TABLE[_next]["t"]):
		var e: Dictionary = TABLE[_next]
		_next += 1
		var sub: String = String(e["sub"])
		if sub != "":
			hud.subtitle(sub, _sub_len(_next - 1))
			log.append("sub:%s@%.1f" % [sub, t])
		match String(e["act"]):
			"enter":
				_walk_to(0)
			"knock", "player_knock":
				var s: HidingSpot = targets[mini(_knock_i, targets.size() - 1)]
				if String(e["act"]) == "player_knock":
					s = spot
					_knock_i = targets.size() - 1
				scare.play_cue("door_knock", -2.0)
				log.append("knock:%s@%.1f" % [s.name, t])
				_knock_i += 1
				_walk_to(_knock_i)
			"outcome":
				_outcome()


## Subtitle length: until the next subtitle mark (at most SUB_MAX_S).
func _sub_len(i: int) -> float:
	var t0: float = float(TABLE[i]["t"])
	for j: int in range(i + 1, TABLE.size()):
		if String(TABLE[j]["sub"]) != "" or String(TABLE[j]["act"]) == "outcome":
			return clampf(float(TABLE[j]["t"]) - t0 - 0.1, 1.0, SUB_MAX_S)
	return 2.0


## Sends Dolly to knock target i, at the speed that gets her there by its knock mark.
func _walk_to(i: int) -> void:
	if i >= targets.size():
		if spot != null:
			performer.script_face = spot.global_position
		return
	var s: HidingSpot = targets[i]
	var at: Vector3 = s.exit_point()
	var marks: Array[float] = knock_marks()
	var due: float = marks[clampi(marks.size() - targets.size() + i, 0, marks.size() - 1)]
	var dist: float = Vector2(at.x - performer.global_position.x, at.z - performer.global_position.z).length()
	var left: float = maxf(0.6, due - t - 0.4) if due > t else 0.6
	performer.script_target = at
	performer.script_speed = clampf(dist / left, SPEED_MIN, SPEED_MAX)
	performer.script_face = s.global_position


func _outcome() -> void:
	running = false
	_unblock()
	var inside: bool = kit.is_hidden() and kit.hidden_spot == spot
	if inside and (seen or heard or gasped):
		outcome = "catch"
		log.append("outcome:catch@%.1f" % t)
		scare.catch_beat.connect(_on_scare_beat)   # the tail plays ducked under the scare, then stops
		performer.catch_in_spot()
	else:
		outcome = "leave"
		log.append("outcome:leave@%.1f" % t)
		scare.play_cue("sniff", -2.0)
		performer.end_script(true)
		if performer.is_dolly:
			performer.set_hum(true)
	finished.emit(outcome)


func _on_scare_beat(beat: String) -> void:
	if beat == "end":
		_stop_voice()
		if scare.catch_beat.is_connected(_on_scare_beat):
			scare.catch_beat.disconnect(_on_scare_beat)


func _stop_voice() -> void:
	if voice != null and is_instance_valid(voice):
		voice.stop()


## Ends the monologue at once (catch by another, retry, escape, release): the voice stops, Dolly is herself again.
func abort() -> void:
	cool_block = ""   # a retry (or a catch) starts fresh: the next visit plays it again
	_cool.clear()
	_stop_voice()   # also a tail still playing under a catch scare
	if scare != null and scare.catch_beat.is_connected(_on_scare_beat):
		scare.catch_beat.disconnect(_on_scare_beat)
	if not running:
		return
	running = false
	outcome = "abort"
	log.append("abort@%.1f" % t)
	if hud != null and hud.subtitle_label != null:
		hud.subtitle_label.visible = false
	_unblock()
	if is_instance_valid(performer) and performer.scripted:
		performer.end_script(false)
		if performer.is_dolly:
			performer.set_hum(true)
	finished.emit("abort")


func _unblock() -> void:
	for h: HorrorStalker in hunters:
		if is_instance_valid(h):
			h.blocked_spot = null
