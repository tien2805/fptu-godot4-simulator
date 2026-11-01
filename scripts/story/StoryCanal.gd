# File: res://scripts/story/StoryCanal.gd
# The Day 6 lair scene (plan 2026-11-01-w4-day6.md; res://scenes/story/StoryCanal.tscn): StoryDirector.launch_lair_beat
# changes to it for a beat with "lair": "canal" (the marker by the Trà Sữa Lọ shop, anchor lo_shop). Built like
# StoryBasement: the code-built LairCanal at the origin (the shop, the back room, the pier, the canal course), its own player
# stack duck-typed like FreeRoam for the story missions (player: ThirdPersonController in the pink shipper shirt; weapons,
# combat, wanted, story_roam, pedestrians null; mounted false; Day 6 is unarmed), a small story HUD (the objective, hints),
# then it runs the CURRENT beat and every following canal beat:
#   kind "lair"  task shop (MissionShop) | backroom (MissionBackroom) | boat (MissionBoatChase), with the level's
#                mission_points(task), its owner music slot (LAIR_MUSIC; no file = silence), the fail card StoryFail (THỬ
#                LẠI = retry at the checkpoint, VỀ THẾ GIỚI MỞ = back to story free roam beside the marker, the beat stays),
#                the beat's "after" cinematic on the win (the beat completes first: autosave);
#   kind "cine"  played here: in the back room (room_xf, cine_d6_caught) or on the finish bank (bank_xf, the choice and its
#                tails) with drop_set (the real room / bank replace the timelines' carried set); a recorded choice is not
#                asked again; a choice tail plays the slot of the recorded answer.
# Each beat completes through StoryDirector.complete_step (autosave per beat). When the current beat is no longer a canal
# beat (d6_reveal after the choice tail) the scene hands back: StoryDirector.leave_lair() (story free roam, where ai_reveal
# plays). The back door is open from d6_backroom on, the ledger gone and the safe open after it (Continue restores them).
# test_opts (static, tests): "missions" (mission opts: manual, manual_replay, manual_card, seed, bot), "cine" (CinePlayer
# opts: manual, music), "capture_mouse" (false), "go_roam" (false: stay instead of handing back).
class_name StoryCanal
extends Node3D

signal cinematic_finished(slot: String, skipped: bool)
signal handed_back

const TASKS: Array[String] = ["shop", "backroom", "boat"]
const MISSION_SCRIPTS: Dictionary = {"shop": "res://scripts/story/missions/MissionShop.gd",
	"backroom": "res://scripts/story/missions/MissionBackroom.gd", "boat": "res://scripts/story/missions/MissionBoatChase.gd"}
## The owner music slot of each task while it runs (no file = silence); the back room plays the Night Building's stealth
## track until the music box starts (then the bed stops: only the music box).
static var LAIR_MUSIC: Dictionary = {"shop": "mission_shop", "backroom": "night_stealth", "boat": "mission_boat"}
## Steps from which the shop's back door stands open / the ledger is taken (Continue mid-day).
const DOOR_OPEN: Array[String] = ["d6_backroom", "d6_caught", "d6_boat", "d6_choice", "d6_choice_tail"]
const LEDGER_TAKEN: Array[String] = ["d6_caught", "d6_boat", "d6_choice", "d6_choice_tail"]
## Cinematics staged in the back room (room_xf) / on the finish bank (bank_xf) / far from the level with their own canal
## set (CHASE_XF: seg_d6_chase carries its water, banks and houses).
const ROOM_SLOTS: Array[String] = ["cine_d6_caught"]
const CHASE_XF := Transform3D(Basis.IDENTITY, Vector3(900.0, 0.0, -400.0))
const SHIPPER_SHIRT := Color("#FF7AB6")
const HINT_S: float = 2.6

static var test_opts: Dictionary = {}

var level: LairCanal
var player: ThirdPersonController
# FreeRoam duck type for the missions
var weapons: Variant = null
var combat: Variant = null
var wanted: Variant = null
var story_roam: Variant = null
var pedestrians: Variant = null
var traffic: Variant = null
var md: Variant = null
var mounted: bool = false
var campus_xf: Transform3D = Transform3D.IDENTITY
var cine_player: CinePlayer = null
var director: Node
var mission_node: StoryMission = null
var mission_beat: Dictionary = {}
var fail_ui: StoryFail
var env: WorldEnvironment
var moon: DirectionalLight3D
var ui: CanvasLayer
var objective_label: Label
var hint_label: Label
var busy: bool = false
var left: bool = false
var runs: int = 0
var music_slot: String = ""
var _opts: Dictionary = {}
var _run_t: float = -1.0
var _hint_t: float = 0.0
var _cine_saved: Dictionary = {}


func _ready() -> void:
	_opts = test_opts.duplicate()
	director = StoryUtil.director()
	_build_env()
	level = LairCanal.new()
	level.name = "LairCanal"
	add_child(level)
	level.build()
	add_child(FxPool.new())   # Q3 VFX pool (group "fx_pool"): splashes, sparks, smoke
	_build_player()
	_build_ui()
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_stop"):
		fx.call("music_stop", true)
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("hub_key_blocked", true)
	if director:
		director.connect("step_changed", _on_step)
		director.connect("objective_changed", _on_objective)
		_on_objective(String(director.get("objective")))
	_apply_state()
	StoryAudio.warm(["heartbeat", "toang_sting", "success_fanfare", "music_box", "whisper_bed", "sheep_bleat_distorted",
		"cliff_sting", "sub_boom"])
	MusicDirector.warm(LAIR_MUSIC.values())
	_run_t = 0.3


func _exit_tree() -> void:
	if director and is_instance_valid(director):
		for pair: Array in [["step_changed", _on_step], ["objective_changed", _on_objective]]:
			if director.is_connected(String(pair[0]), pair[1]):
				director.disconnect(String(pair[0]), pair[1])
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm:
		sm.set("hub_key_blocked", false)
	if cine_player != null and is_inside_tree():
		get_tree().paused = false


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
func _build_env() -> void:
	env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.3, 0.6)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.75
	env.environment = e
	add_child(env)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	moon.light_color = Color("#9ab8ff")
	moon.light_energy = 0.3
	moon.shadow_enabled = false
	add_child(moon)
	LookPresets.set_base(self, "canal_night")   # Q3: water reflections, festival lights


func _build_player() -> void:
	player = ThirdPersonController.new()
	player.name = "Player"
	var o: Dictionary = director.call("protagonist_opts") if director and bool(director.get("active")) else StoryUtil.builder_opts({})
	o = o.duplicate()
	o["shirt_color"] = SHIPPER_SHIRT   # Phúc's pink Trà Sữa Lọ shipper uniform
	player.character_opts = o
	player.capture_on_click = bool(_opts.get("capture_mouse", true))
	add_child(player)
	player.teleport(level.world(LairCanal.SHOP_STAND), 0.0)
	player.camera.make_current()


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "CanalUI"
	ui.layer = 3
	add_child(ui)
	objective_label = Label.new()
	objective_label.name = "Objective"
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective_label.offset_left = 26.0
	objective_label.offset_top = 92.0
	objective_label.custom_minimum_size = Vector2(440.0, 0.0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color("#FFE6F3"))
	objective_label.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.1, 0.95))
	objective_label.add_theme_constant_override("outline_size", 4)
	ui.add_child(objective_label)
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -400.0
	hint_label.offset_right = 400.0
	hint_label.offset_top = -120.0
	hint_label.offset_bottom = -90.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color("#FFE66D"))
	hint_label.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.1, 0.95))
	hint_label.add_theme_constant_override("outline_size", 5)
	hint_label.visible = false
	ui.add_child(hint_label)


## The back door, the ledger and the safe as the step implies (Continue mid-day, after each beat).
func _apply_state() -> void:
	var st: String = String(director.get("step")) if director else ""
	level.back_door_open(st in DOOR_OPEN)
	var taken: bool = st in LEDGER_TAKEN
	if level.ledger:
		level.ledger.visible = not taken
	level.safe_open(1.0 if taken else 0.0)


# ----- FreeRoam duck type -----
func roam_position() -> Vector3:
	return player.global_position if player else Vector3.ZERO


func find_free_spot(p: Vector3, _y: float = 0.0, _r: int = 6, _ex: Array = []) -> Variant:
	return p


func flash_hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = true
	_hint_t = HINT_S


func player_xf() -> Variant:
	return null   # leaving for the menu keeps the save beside the marker in free roam


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
func _on_step(_id: String) -> void:
	_apply_state()
	if not busy:
		_run_t = 0.05


func _on_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text


func _process(delta: float) -> void:
	if player and (mission_node == null or not mission_node.has_method("focus_point")):
		level.focus = player.global_position
	elif mission_node:
		level.focus = mission_node.call("focus_point")
	level.tick(delta)
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			hint_label.visible = false
	if ui:
		ui.visible = cine_player == null and (mission_node == null or mission_node.hud_visible())
	if _run_t >= 0.0:
		_run_t -= delta
		if _run_t < 0.0:
			run_step()


## Runs the current beat: a canal task or a canal cinematic; any other beat hands back to free roam.
func run_step() -> void:
	_run_t = -1.0
	if director == null or busy or left or not bool(director.get("active")):
		return   # no story running (a smoke test of the scene): the level stays, nothing runs
	if cine_player != null:
		_run_t = 0.25
		return
	var b: Dictionary = director.call("beat")
	if String(b.get("lair", "")) != "canal":
		_leave()
		return
	runs += 1
	match String(b.get("kind", "")):
		"lair":
			start_mission(b)
		"cine":
			_play_cine(b)
		_:
			_leave()


func start_mission(b: Dictionary) -> bool:
	var task: String = String(b.get("task", ""))
	if mission_node != null or not MISSION_SCRIPTS.has(task):
		return false
	var m: StoryMission = (load(String(MISSION_SCRIPTS[task])) as GDScript).new()
	var o: Dictionary = (_opts.get("missions", {}) as Dictionary).duplicate()
	o["level"] = level
	o["points"] = level.mission_points(task)
	busy = true
	mission_beat = b
	mission_node = m
	add_child(m)
	m.setup(self, b, o)
	m.done.connect(_on_mission_done.bind(b), CONNECT_ONE_SHOT)
	m.failed.connect(_on_mission_failed)
	m.begin()
	music(String(LAIR_MUSIC.get(task, "")))
	return true


func _on_mission_done(_info: Dictionary, b: Dictionary) -> void:
	_free_mission()
	if fail_ui:
		fail_ui.visible = false
	var after: String = String(b.get("after", ""))
	if after != "":
		var tl: CineTimeline = CineTimeline.load_slot(after)
		var cp: CinePlayer = play_cinematic(tl, cine_opts(after)) if tl else null
		if cp != null:
			connect("cinematic_finished", func(_s: String, _k: bool) -> void:
				busy = false
				_run_t = 0.05, CONNECT_ONE_SHOT)
			director.call("complete_step", String(b["id"]))   # completes (autosave) before the cinematic, as in free roam
			return
	busy = false
	director.call("complete_step", String(b["id"]))


func _on_mission_failed(title: String, reason: String) -> void:
	if fail_ui == null:
		fail_ui = StoryFail.new()
		fail_ui.name = "StoryFail"
		add_child(fail_ui)
		fail_ui.retry_pressed.connect(retry_mission)
		fail_ui.leave_pressed.connect(abort_mission)
	fail_ui.show_fail(title, reason)


func retry_mission() -> void:
	if fail_ui:
		fail_ui.visible = false
	if mission_node and is_instance_valid(mission_node) and mission_node.state == "failed":
		mission_node.retry()


## VỀ THẾ GIỚI MỞ: back to story free roam beside the marker; the beat stays.
func abort_mission() -> void:
	if fail_ui:
		fail_ui.visible = false
	_free_mission()
	busy = false
	_leave()


func _free_mission() -> void:
	if mission_node and is_instance_valid(mission_node):
		if mission_node.state in ["running", "failed"]:
			mission_node.abort()
		else:
			mission_node.queue_free()
	mission_node = null
	mission_beat = {}
	music("")
	if player and is_instance_valid(player):
		player.visible = true                # the boat chase keeps the walking body hidden (parked on the bank) until here
		player.controls_enabled = true
		if player.camera:
			player.camera.make_current()


func _play_cine(b: Dictionary) -> void:
	var choice_id: String = String(b.get("choice", ""))
	if choice_id != "" and String(director.call("choice_of", choice_id)) != "":
		director.call("complete_step", String(b["id"]))   # recorded once: the choice scene is not asked again
		return
	var slot: String = cine_slot(b)
	var tl: CineTimeline = CineTimeline.load_slot(slot)
	var cp: CinePlayer = play_cinematic(tl, cine_opts(slot)) if tl else null
	if cp == null:
		director.call("complete_step", String(b["id"]))   # never block the story on a missing timeline
		return
	busy = true
	connect("cinematic_finished", func(_s: String, _k: bool) -> void:
		busy = false
		director.call("complete_step", String(b["id"])), CONNECT_ONE_SHOT)


## A choice tail plays the slot of the recorded answer (slot_by_choice), else "slot".
func cine_slot(b: Dictionary) -> String:
	var by: Dictionary = b.get("slot_by_choice", {})
	if not by.is_empty() and director:
		var key: String = String(director.call("choice_of", String(by.get("id", ""))))
		if by.has(key) and key != "id":
			return String(by[key])
	return String(b.get("slot", ""))


## Where a Day 6 cinematic plays: the back room, far out with its own canal set (seg_d6_chase), else the finish bank.
func cine_opts(slot: String) -> Dictionary:
	var o: Dictionary = (_opts.get("cine", {}) as Dictionary).duplicate()
	if slot in ROOM_SLOTS:
		o["xf"] = level.room_xf()
		o["drop_set"] = true
	elif slot == "seg_d6_chase":
		o["xf"] = CHASE_XF
		o["drop_set"] = false
	else:
		o["xf"] = level.bank_xf()
		o["drop_set"] = true
	return o


## Plays a Day 6 cinematic here (the tree paused, the player and HUD hidden, the level's own copies of what the timeline
## brings hidden, the stage's exposure / ambient factors applied); restores everything on finished. Fades to black first
## and builds under the black frame (CinePlayer.preroll) unless manual / "fade": false / a hard cut, like StoryBasement.
func play_cinematic(tl: CineTimeline, opts: Dictionary = {}) -> CinePlayer:
	if tl == null or cine_player != null:
		return null
	var errs: PackedStringArray = tl.validate()
	if not errs.is_empty():
		push_error("CinePlayer: timeline %s is invalid:\n  %s" % [tl.slot, "\n  ".join(errs)])
		return null
	var xf: Transform3D = opts.get("xf", level.bank_xf())
	var p := CinePlayer.new()
	p.name = "CinePlayer"
	add_child(p)
	StoryChapters.mark_cine(tl.slot)
	_cine_saved = {"vis": {}, "env": [env.environment.tonemap_exposure, env.environment.ambient_light_energy]}
	music("")
	get_tree().paused = true
	cine_player = p
	p.finished.connect(_on_cine_finished.bind(tl.slot), CONNECT_ONE_SHOT)
	var black: Callable = _cine_black.bind(p, tl)
	var go: Callable = _cine_go.bind(p, tl, xf, opts)
	if bool(opts.get("fade", CinePlayer.wants_preroll(tl, opts))):
		p.preroll(tl, CinePlayer.FADE_S, black, go)
	else:
		black.call()
		go.call()
	return p


func _cine_black(p: CinePlayer, tl: CineTimeline) -> void:
	if not is_instance_valid(p):
		return
	for n: Variant in [player, ui]:
		if n is Node and is_instance_valid(n) and "visible" in n:
			_cine_saved["vis"][n] = n.visible
			n.visible = false
	level.hide_for_cine(true, tl.slot)
	env.environment.tonemap_exposure *= float(tl.stage.get("exposure", 1.0))
	env.environment.ambient_light_energy *= float(tl.stage.get("ambient", 1.0))


func _cine_go(p: CinePlayer, tl: CineTimeline, xf: Transform3D, opts: Dictionary) -> void:
	if not is_instance_valid(p):
		return
	if cine_player != p or not p.setup(tl, xf, opts).is_empty():
		p.call("_finish", true)   # never leave the tree paused without finished
		return
	p.start()


func _on_cine_finished(skipped: bool, slot: String) -> void:
	for n: Variant in (_cine_saved.get("vis", {}) as Dictionary).keys():
		if is_instance_valid(n):
			n.visible = _cine_saved["vis"][n]
	var ev: Array = _cine_saved.get("env", [])
	if ev.size() == 2:
		env.environment.tonemap_exposure = float(ev[0])
		env.environment.ambient_light_energy = float(ev[1])
	level.hide_for_cine(false)
	_cine_saved = {}
	if is_inside_tree():
		get_tree().paused = false
	if player and player.camera:
		player.camera.make_current()
	if cine_player:
		cine_player.queue_free()
	cine_player = null
	cinematic_finished.emit(slot, skipped)


## The task's owner track ("" = stop); missions call it too (the back room stops it when the music box plays).
func music(slot: String) -> void:
	music_slot = slot
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx == null:
		return
	if slot == "":
		if fx.has_method("music_stop"):
			fx.call("music_stop", true)
	elif fx.has_method("music_play"):
		fx.call("music_play", slot, 0.5)   # warmed in _ready


## Back to story free roam (the beat after the canal, or VỀ THẾ GIỚI MỞ).
func _leave() -> void:
	if left:
		return
	left = true
	music("")
	handed_back.emit()
	if director and bool(_opts.get("go_roam", true)):
		director.call("leave_lair")
