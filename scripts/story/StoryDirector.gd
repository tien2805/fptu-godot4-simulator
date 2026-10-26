# File: res://scripts/story/StoryDirector.gd
# Autoload "StoryDirector" (spec A2-D1, A2-D2): the state of the story "TOOL ĐEN" and its progression through the beats of
# StoryMissions; one save slot user://story_save.cfg (section [story]: version = 1, data = var_to_str(to_dict())).
# It never builds world content: StoryRoam (free roam) and the stages read it. No class_name (it would hide the autoload);
# class_name scripts reach it through StoryUtil / get_node_or_null("/root/StoryDirector").
# Flow: new_story() -> d0_wake ... ; complete_step(id) grants the beat's evidence, enters the next beat (its tod, objective,
# texts; a "day" beat advances the day and passes straight on) and autosaves. Stage beats: launch_stage_beat() sets
# StageManager.story_context and starts the stage; StageManager.report_stage_result forwards to on_stage_result().
# Phase B: horror beats run the Night Building as its own scene (launch_horror_beat -> on_horror_result: E5 only when the
# player was never caught); side markers grant their evidence once (grant_side); a beat's "flag" is set when it completes;
# old saves at dN_locked of a day that is now playable resume at the day's first beat (StoryMissions.migrate).
extends Node

const GameFXScript: Script = preload("res://scripts/GameFX.gd")

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
## from_dict moved an old save's step (StoryMissions.migrate); load_game saves the migrated state once.
var migrated: bool = false
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
	if b.has("flag"):
		flags[String(b["flag"])] = true
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
	var is_day: bool = String(b["kind"]) == "day"
	if is_day:
		advance_day(int(b["day"]))   # before the texts: they are stamped with the new day (review A2-R1)
	for t: Array in b.get("texts", []):
		add_text(String(t[0]), String(t[1]))
	if b.has("objective"):
		set_objective(fmt(String(b["objective"])))
	set_step(id)
	StoryChapters.on_enter(self, id)   # chapter select: the beat is reached, a replayable beat keeps its start state
	if is_day:
		_enter(String(b["next"]))   # no save of the transient "day" step: complete_step saves the next beat


func advance_day(to_day: int = -1) -> void:
	var d: int = to_day if to_day >= 0 else day + 1
	d = clampi(d, 0, DAYS)
	if d == day:
		return
	day = d
	_read_old_days()
	day_changed.emit(day)


## Texts of the previous days count as read: the badge only counts today's unread (an old text never reads as today's).
func _read_old_days() -> void:
	for m: Dictionary in texts:
		if int(m.get("day", 0)) < day:
			m["read"] = true


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
		var eid: String = String(e)
		if eid in StoryMissions.EVIDENCE_IDS and not (eid in evidence):   # an edited save cannot inflate the count
			evidence.append(eid)
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
	_read_old_days()
	migrated = false
	var mig: String = StoryMissions.migrate(step)
	if mig != step:
		_resume_at(mig)
		migrated = true   # load_game saves at once: the beat's texts are added once, not on every load


## An A2 save stopped at a day placeholder that is now playable: resume at its first beat (tod, objective, texts).
func _resume_at(id: String) -> void:
	var b: Dictionary = StoryMissions.beat(id)
	if b.is_empty():
		return
	step = id
	if b.has("tod"):
		tod = String(b["tod"])
	for t: Array in b.get("texts", []):
		add_text(String(t[0]), String(t[1]))
	if b.has("objective"):
		objective = fmt(String(b["objective"]))


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
	StoryChapters.ensure_seeded(d)   # a save from before the chapter select: unlock what it has played so far
	from_dict(d)
	active = true
	if migrated:
		save_game(path)
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
	if not is_inside_tree():
		return null
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
	elif where.begins_with("horror:") and is_inside_tree():
		sm.set("roam_spawn", null)
		var fx: Node = get_node_or_null("/root/GameFX")
		if fx and fx.has_method("music_stop"):
			fx.call("music_stop", true)   # the roam track does not play in the Night Building; FreeRoam restarts it on return
		get_tree().paused = false
		get_tree().change_scene_to_file(where.substr(7))
	elif where.begins_with("stage:"):
		sm.call("start_stage_from_roam", int(where.get_slice(":", 1)), sm.get("roam_spawn"))
	elif where == "creator" and is_inside_tree():
		get_tree().change_scene_to_file(CREATOR_SCENE)


# ---------------------------------------------------------------------------
# Stage beats (A2-D11)
# ---------------------------------------------------------------------------
## Starts the stage of beat `id` (the current step) with StageManager.story_context set. win_xf / fail_xf: free-roam return
## spots after a win (next beat) / a fail or a quit (the marker stays). The save resumes at fail_xf until the win.
func launch_stage_beat(id: String, win_xf: Variant = null, fail_xf: Variant = null) -> bool:
	var b: Dictionary = StoryMissions.beat(id)
	if id != step or String(b.get("kind", "")) != "stage":
		return false
	var ctx: Dictionary = {"beat": id, "stage": int(b["stage"]), "replay": String(b.get("replay", "")), "name": display_name(),
		"opts": protagonist_opts(), "win_xf": win_xf, "fail_xf": fail_xf}
	if fail_xf is Transform3D:
		spawn = fail_xf
	var sm: Node = _sm()
	if sm:
		sm.set("story_context", ctx)
		sm.set("roam_spawn", fail_xf if fail_xf is Transform3D else null)
	_nav("stage:%d" % int(b["stage"]))
	return true


## StageManager.report_stage_result forwards here while story_context is set: a win completes the beat (evidence, next
## beat, autosave) and moves the return spot to win_xf; the result gets "story" = "win" | "fail" (card titles) and the story
## result buttons replace the stage card's own.
func on_stage_result(stage_id: int, result: Dictionary) -> void:
	var sm: Node = _sm()
	var ctx: Dictionary = sm.get("story_context") if sm else {}
	if ctx.is_empty() or int(ctx.get("stage", -1)) != stage_id:
		return
	var won: bool = String(result.get("result", "")) == "win"
	result["story"] = "win" if won else "fail"
	if won:
		if ctx.get("win_xf") is Transform3D:
			spawn = ctx["win_xf"]
		complete_step(String(ctx["beat"]))
	show_result(won)


## Story result card title (story spec 7): win "QUA MÔN! Uy tín +", fail "TOANG!".
static func result_title_for(won: bool) -> String:
	return "QUA MÔN! Uy tín +" if won else "TOANG!"


func show_result(won: bool) -> void:
	if result_layer == null:
		_build_result_layer()
	result_title.text = result_title_for(won)
	result_title.add_theme_color_override("font_color", Color("#FF4FA3") if won else Color("#FF3B5C"))
	(result_buttons["continue"] as Button).visible = won
	(result_buttons["retry"] as Button).visible = not won
	(result_buttons["roam"] as Button).visible = not won
	result_layer.visible = true
	_hide_card_buttons.call_deferred()


## The stage's own card buttons (Chơi lại, Màn tiếp, Campaign Hub...) are replaced by the story's (deferred: stages show
## theirs right after reporting).
func _hide_card_buttons() -> void:
	var sm: Node = _sm()
	if sm == null or not sm.has_method("_result_card_box") or result_layer == null or not result_layer.visible:
		return
	var vb: Node = sm.call("_result_card_box")
	if vb:
		for b: Node in vb.find_children("*", "Button", true, false):
			(b as Button).visible = false


func _build_result_layer() -> void:
	result_layer = CanvasLayer.new()
	result_layer.name = "StoryResult"
	result_layer.layer = 117
	result_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(result_layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -22.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.03, 0.14, 0.96)
	sb.border_color = Color("#FF4FA3")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	result_layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	result_title = Label.new()
	result_title.name = "StoryResultTitle"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_override("font", GameFXScript.vice_font(0.9, 0.26))
	result_title.add_theme_font_size_override("font_size", 40)
	result_title.add_theme_color_override("font_outline_color", Color("#2A0E3A"))
	result_title.add_theme_constant_override("outline_size", 8)
	vb.add_child(result_title)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	for pair: Array in [["continue", "TIẾP TỤC CỐT TRUYỆN", continue_from_stage], ["retry", "THỬ LẠI", retry_stage],
			["roam", "VỀ THẾ GIỚI MỞ", back_to_roam]]:
		var b := Button.new()
		b.name = "Story_" + String(pair[0])
		b.text = String(pair[1])
		b.custom_minimum_size = Vector2(260.0, 44.0)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_stylebox_override("normal", GameFXScript.make_panel_style(Color("#FF4FA3"), Color(0.12, 0.05, 0.2, 0.95), 10))
		b.add_theme_stylebox_override("hover", GameFXScript.make_panel_style(Color("#3FF2FF"), Color(0.2, 0.08, 0.3, 0.98), 10))
		b.pressed.connect(pair[2])
		hb.add_child(b)
		result_buttons[String(pair[0])] = b


## Win: back to story free roam at the beat's return spot (next beat).
func continue_from_stage() -> void:
	hide_result()
	enter_roam()


## Fail: the same stage with the same context.
func retry_stage() -> void:
	hide_result()
	var sm: Node = _sm()
	var ctx: Dictionary = sm.get("story_context") if sm else {}
	last_nav = "retry:%d" % int(ctx.get("stage", 0))
	if nav_enabled and sm and not ctx.is_empty():
		sm.call("change_stage", int(ctx["stage"]), true)


## Fail: back to free roam beside the marker (it stays).
func back_to_roam() -> void:
	hide_result()
	enter_roam()


# ---------------------------------------------------------------------------
# Phase B: side markers, choices, the horror scene
# ---------------------------------------------------------------------------
## Side marker of a beat (StoryMissions "side"): grants its evidence and marks it done, once. false when its flag is
## missing or it was already taken.
func grant_side(side: Dictionary) -> bool:
	var sid: String = String(side.get("id", ""))
	if sid == "" or bool(flags.get(sid, false)) or not side_available(side):
		return false
	flags[sid] = true
	if side.has("evidence"):
		add_evidence(String(side["evidence"]))
	save_game()
	return true


## true while a side marker can be used (its "need" flag is set and it was not taken yet).
func side_available(side: Dictionary) -> bool:
	var need: String = String(side.get("need", ""))
	return not bool(flags.get(String(side.get("id", "")), false)) and (need == "" or bool(flags.get(need, false)))


## The recorded answer of choice `id` ("" when not asked yet).
func choice_of(id: String) -> String:
	return String(choices.get(id, ""))


## Starts the horror beat `id` (the Night Building scene). win_xf / fail_xf as launch_stage_beat: the save resumes at
## fail_xf (beside the marker) until the escape.
func launch_horror_beat(id: String, win_xf: Variant = null, fail_xf: Variant = null) -> bool:
	var b: Dictionary = StoryMissions.beat(id)
	if id != step or String(b.get("kind", "")) != "horror":
		return false
	if fail_xf is Transform3D:
		spawn = fail_xf
	var sm: Node = _sm()
	if sm:
		sm.set("story_context", {"beat": id, "horror": true, "replay": String(b.get("replay", "")), "win_xf": win_xf,
			"fail_xf": fail_xf})
	save_game()
	_nav("horror:" + String(b.get("scene", StoryMissions.HORROR_SCENE)))
	return true


## A catch in the Night Building is saved at once (flags.d4_catches): quitting to the menu and continuing does not reset
## the count, so E5 (never caught) cannot be save-scummed.
func note_horror_catch(caught_count: int) -> void:
	flags["d4_catches"] = maxi(caught_count, int(flags.get("d4_catches", 0)))
	save_game()


## The horror scene reports the escape: E5 only when the player was never caught (B-D7), the beat completes (autosave),
## the return spot moves to win_xf, then story free roam. false when no horror beat is running.
func on_horror_result(caught_count: int, go_roam: bool = true) -> bool:
	var sm: Node = _sm()
	var ctx: Dictionary = sm.get("story_context") if sm else {}
	var b: Dictionary = beat()
	if String(b.get("kind", "")) != "horror":
		return false
	caught_count = maxi(caught_count, int(flags.get("d4_catches", 0)))   # catches of earlier, abandoned runs count too
	if caught_count == 0:
		add_evidence("E5")
	flags["d4_caught"] = caught_count
	if ctx.get("win_xf") is Transform3D:
		spawn = ctx["win_xf"]
	complete_step(step)
	if go_roam:
		enter_roam()
	return true


## Main menu: story start goes through the character creator.
func open_creator() -> void:
	_nav("creator")


func hide_result() -> void:
	if result_layer:
		result_layer.visible = false
