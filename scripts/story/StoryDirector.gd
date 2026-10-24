# File: res://scripts/story/StoryDirector.gd
# Autoload "StoryDirector" (spec A2-D1, A2-D2): the state of the story "TOOL ĐEN" and its progression through the beats of
# StoryMissions; one save slot user://story_save.cfg (section [story]: version = 1, data = var_to_str(to_dict())).
# It never builds world content: StoryRoam (free roam) and the stages read it. No class_name (it would hide the autoload);
# class_name scripts reach it through StoryUtil / get_node_or_null("/root/StoryDirector").
# Flow: new_story() -> d0_wake ... ; complete_step(id) grants the beat's evidence, enters the next beat (its tod, objective,
# texts; a "day" beat advances the day and passes straight on) and autosaves. Stage beats: launch_stage_beat() sets
# StageManager.story_context and starts the stage; StageManager.report_stage_result forwards to on_stage_result().
extends Node

signal day_changed(day: int)
signal evidence_added(id: String)
signal objective_changed(text: String)
signal text_received(msg: Dictionary)
signal step_changed(step: String)

const SAVE_PATH: String = "user://story_save.cfg"
const SAVE_VERSION: int = 1
const CREATOR_SCENE: String = "res://scenes/story/CharacterCreator.tscn"
const DAYS: int = 7
const NAME_MAX: int = 16

# ----- state (to_dict / from_dict) -----
var active: bool = false
var day: int = 0
var tod: String = "morning"
var step: String = ""
var evidence: Array[String] = []
var choices: Dictionary = {"phuc": "", "zaman_offer": "", "bribe": ""}
var flags: Dictionary = {}
var protagonist: Dictionary = {}
var texts: Array[Dictionary] = []
var objective: String = ""
var spawn: Variant = null

# ----- runtime -----
## Save file (tests point it at a temp file).
var save_path: String = SAVE_PATH
## false (tests): navigation is recorded in last_nav instead of changing scenes.
var nav_enabled: bool = true
var last_nav: String = ""
var saves: int = 0
## StoryRoam of the current free roam (weak): asked for the player's spot when leaving for the main menu.
var _roam: WeakRef = null
var result_layer: CanvasLayer
var result_title: Label
var result_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
func reset_state() -> void:
	active = false
	day = 0
	tod = "morning"
	step = ""
	evidence = []
	choices = {"phuc": "", "zaman_offer": "", "bribe": ""}
	flags = {}
	protagonist = {}
	texts = []
	objective = ""
	spawn = null


## Starts a new story with the creator's protagonist {female, name, variant, hair_style, hair_color, skin}; autosaves.
func new_story(p: Dictionary) -> void:
	reset_state()
	protagonist = p.duplicate(true)
	protagonist["name"] = clean_name(String(p.get("name", "")))
	active = true
	_enter(StoryMissions.first_beat())
	save_game()


static func clean_name(text: String) -> String:
	var s: String = text.strip_edges()
	if s == "":
		return StoryUtil.DEFAULT_NAME
	return s.substr(0, NAME_MAX).strip_edges()


func display_name() -> String:
	var n: String = String(protagonist.get("name", ""))
	return n if n != "" else StoryUtil.DEFAULT_NAME


func fmt(text: String) -> String:
	return text.replace("{name}", display_name())


## CharacterBuilder opts of the protagonist (story spec 3.1: preset "player" = orange FPT polo, jeans, white sneakers,
## black backpack; the creator only picks sex, face, hair and skin).
func protagonist_opts() -> Dictionary:
	return StoryUtil.builder_opts(protagonist)


func beat() -> Dictionary:
	return StoryMissions.beat(step)


func set_step(id: String) -> void:
	if id == step:
		return
	step = id
	step_changed.emit(id)


## Finishes beat `id` (ignored unless it is the current step): grants its evidence, enters the next beat, autosaves.
func complete_step(id: String) -> bool:
	if id != step or id == "":
		return false
	var b: Dictionary = StoryMissions.beat(id)
	if b.has("evidence"):
		add_evidence(String(b["evidence"]))
	var nxt: String = String(b.get("next", ""))
	if nxt != "":
		_enter(nxt)
	save_game()
	return true


## Makes `id` the current beat: tod, objective, texts; a "day" beat advances the day, autosaves and enters its next beat.
func _enter(id: String) -> void:
	var b: Dictionary = StoryMissions.beat(id)
	if b.is_empty():
		push_error("StoryDirector: unknown beat %s" % id)
		return
	if b.has("tod"):
		tod = String(b["tod"])
	for t: Array in b.get("texts", []):
		add_text(String(t[0]), String(t[1]))
	if b.has("objective"):
		set_objective(fmt(String(b["objective"])))
	set_step(id)
	if String(b["kind"]) == "day":
		advance_day(int(b["day"]))
		save_game()
		_enter(String(b["next"]))


func advance_day(to_day: int = -1) -> void:
	var d: int = to_day if to_day >= 0 else day + 1
	d = clampi(d, 0, DAYS)
	if d == day:
		return
	day = d
	day_changed.emit(day)


func add_evidence(id: String) -> void:
	if id in evidence or not (id in StoryMissions.EVIDENCE_IDS):
		return
	evidence.append(id)
	evidence_added.emit(id)


func has_evidence(id: String) -> bool:
	return id in evidence


func add_text(from: String, text: String) -> void:
	var msg: Dictionary = {"from": from, "text": fmt(text), "day": day, "read": false}
	texts.append(msg)
	text_received.emit(msg)


func unread_count(from: String = "") -> int:
	var n: int = 0
	for m: Dictionary in texts:
		if not bool(m["read"]) and (from == "" or String(m["from"]) == from):
			n += 1
	return n


func mark_read(from: String = "") -> void:
	for m: Dictionary in texts:
		if from == "" or String(m["from"]) == from:
			m["read"] = true


func set_objective(text: String) -> void:
	if text == objective:
		return
	objective = text
	objective_changed.emit(text)


## Days left before the hearing: Day 1 -> 7 ... Day 7 -> 1 (Day 0 -> 8: the countdown starts on Day 1).
func days_left() -> int:
	return DAYS + 1 - day


func day_chip_text() -> String:
	if day <= 0:
		return "NGÀY 0 · THI EOS"
	return "NGÀY %d · CÒN %d NGÀY" % [day, days_left()]


# ---------------------------------------------------------------------------
# Save / load (A2-D2)
# ---------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"active": active, "day": day, "tod": tod, "step": step, "evidence": evidence.duplicate(),
		"choices": choices.duplicate(true), "flags": flags.duplicate(true), "protagonist": protagonist.duplicate(true),
		"texts": texts.duplicate(true), "objective": objective, "spawn": spawn}


func from_dict(d: Dictionary) -> void:
	reset_state()
	day = clampi(int(d.get("day", 0)), 0, DAYS)
	tod = String(d.get("tod", "morning"))
	step = String(d.get("step", StoryMissions.first_beat()))
	for e: Variant in d.get("evidence", []):
		evidence.append(String(e))
	var ch: Variant = d.get("choices", {})
	if ch is Dictionary:
		choices.merge(ch, true)
	var fl: Variant = d.get("flags", {})
	flags = (fl as Dictionary).duplicate(true) if fl is Dictionary else {}
	var pr: Variant = d.get("protagonist", {})
	protagonist = (pr as Dictionary).duplicate(true) if pr is Dictionary else {}
	for m: Variant in d.get("texts", []):
		if m is Dictionary:
			texts.append((m as Dictionary).duplicate(true))
	objective = String(d.get("objective", ""))
	var sp: Variant = d.get("spawn", null)
	spawn = sp if sp is Transform3D else null
	active = bool(d.get("active", true))


func save_game(path: String = "") -> bool:
	var p: String = path if path != "" else save_path
	if DisplayServer.get_name() == "headless" and p == SAVE_PATH:
		return false   # headless bots never overwrite the player's save (tests pass a temp path)
	var cfg := ConfigFile.new()
	cfg.set_value("story", "version", SAVE_VERSION)
	cfg.set_value("story", "data", var_to_str(to_dict()))
	var ok: bool = cfg.save(p) == OK
	if ok:
		saves += 1
	return ok


## The saved state, or {} when the file is missing, unreadable, has no step or a version other than SAVE_VERSION.
static func read_save(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {}
	if int(cfg.get_value("story", "version", 0)) != SAVE_VERSION:
		return {}
	var v: Variant = str_to_var(String(cfg.get_value("story", "data", "")))
	if not (v is Dictionary) or not (v as Dictionary).has("step"):
		return {}
	if StoryMissions.beat(String(v["step"])).is_empty():
		return {}
	return v


func has_save() -> bool:
	return not read_save(save_path).is_empty()


func load_game(path: String = "") -> bool:
	var d: Dictionary = read_save(path if path != "" else save_path)
	if d.is_empty():
		return false
	from_dict(d)
	active = true
	return true


# ---------------------------------------------------------------------------
# Endings (story spec section 6)
# ---------------------------------------------------------------------------
## state: {"evidence": [...], "choices": {phuc, zaman_offer, bribe}, "study_ranks": {3: "S", 6: "S", 7: "S"} (optional)}.
## Returns "C", "E", "B", "D", "A" or "F", checked in that order.
static func evaluate_ending(state: Dictionary) -> String:
	var ch: Dictionary = state.get("choices", {})
	var ev: int = (state.get("evidence", []) as Array).size()
	if String(ch.get("zaman_offer", "")) == "accept":
		return "C"
	if ev < 4:
		return "E"
	if String(ch.get("phuc", "")) == "report":
		return "B"
	if ev < 7 or String(ch.get("bribe", "")) == "take":
		return "D"
	var ranks: Dictionary = state.get("study_ranks", {})
	var all_s: bool = true
	for sid: int in [3, 6, 7]:
		if String(ranks.get(sid, ranks.get(str(sid), ""))) != "S":
			all_s = false
	return "F" if all_s else "A"


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------
func _sm() -> Node:
	return get_node_or_null("/root/StageManager")


func register_roam(r: Node) -> void:
	_roam = weakref(r) if r else null


## Enters story free roam at `spawn` (BE6 when none).
func enter_roam() -> void:
	var sm: Node = _sm()
	if sm:
		sm.set("story_context", {})
		sm.set("roam_spawn", spawn if spawn is Transform3D else null)
	_nav("roam")


## Main menu "TIẾP TỤC": restore the save and enter free roam. false without a valid save.
func continue_story() -> bool:
	if not load_game():
		return false
	enter_roam()
	return true


## Leaving for the main menu (StageManager.go_to_main_menu): remember the player's spot in story free roam, autosave,
## stop the story.
func on_leave_to_menu() -> void:
	hide_result()
	var sm: Node = _sm()
	if sm:
		sm.set("story_context", {})
	if not active:
		return
	var r: Node = _roam.get_ref() if _roam else null
	if r and is_instance_valid(r) and r.has_method("player_xf"):
		var xf: Variant = r.call("player_xf")
		if xf is Transform3D:
			spawn = xf
	save_game()
	active = false


func _nav(where: String) -> void:
	last_nav = where
	if not nav_enabled:
		return
	var sm: Node = _sm()
	if sm == null:
		return
	if where == "roam":
		sm.call("go_to_roam")
	elif where.begins_with("stage:"):
		sm.call("start_stage_from_roam", int(where.get_slice(":", 1)), sm.get("roam_spawn"))
	elif where == "creator" and is_inside_tree():
		get_tree().change_scene_to_file(CREATOR_SCENE)


func hide_result() -> void:
	if result_layer:
		result_layer.visible = false
