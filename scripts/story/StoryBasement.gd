# File: res://scripts/story/StoryBasement.gd
# The Day 5 server basement (spec C-D5 / C-D8; scene res://scenes/story/StoryBasement.tscn): StoryDirector.launch_lair_beat
# changes to this scene for a beat with "lair": "basement". It builds the code-built LairBasement at the origin, its own
# player stack duck-typed like FreeRoam for the story missions and the combat encounters (player: ThirdPersonController,
# weapons: WeaponDirector + wheel + HUD, combat: PlayerCombat; wanted / story_roam / pedestrians null, mounted false) and a
# small story HUD (the objective, hints), then runs the CURRENT beat and every following basement beat:
#   kind "lair"  task stealth (MissionSneak) | gunfight (MissionGunfight) | hack (MissionHack) | duel (MissionDuel), each
#                with the level's mission_points(task), its owner music slot (LAIR_MUSIC; no file = silence), the fail card
#                StoryFail ("TOANG!", THỬ LẠI = retry at the checkpoint, VỀ THẾ GIỚI MỞ = back to story free roam beside the
#                marker, the beat stays), the beat's "after" cinematic on the win (the beat completes first: autosave);
#   kind "cine"  played here at room_xf() with drop_set (the real room replaces the timelines' carried one); a choice beat
#                whose choice is recorded is not asked again; a choice tail plays the slot of the recorded answer and
#                StoryDirector follows its next_by_choice.
# Each beat completes through StoryDirector.complete_step (autosave per beat). When the current beat is no longer a basement
# beat (d5_end_c after "Nhận lời", d5_bed after cine_d5) the scene hands back: StoryDirector.leave_lair() (story free roam).
# The monitor wall is off before cine_d5_monitors and frozen on the crash screen after it; the room burns from the hack's
# win on (Continue restores both from the step). Esc opens the usual pause menu (StageManager); leaving for the menu keeps
# the save beside the marker (StoryDirector.spawn = the launch's fail spot), Continue resumes at the beat.
# test_opts (static, tests): "missions" (mission opts: manual, manual_replay, manual_card, seed), "cine" (CinePlayer opts:
# manual, music), "capture_mouse" (false), "go_roam" (false: stay instead of handing back).
class_name StoryBasement
extends Node3D

signal cinematic_finished(slot: String, skipped: bool)
signal handed_back

const MISSION_SCRIPTS: Dictionary = {"stealth": "res://scripts/story/missions/MissionSneak.gd",
	"gunfight": "res://scripts/story/missions/MissionGunfight.gd", "hack": "res://scripts/story/missions/MissionHack.gd",
	"duel": "res://scripts/story/missions/MissionDuel.gd"}
## C-D11: the owner music slot of each task while it runs.
const LAIR_MUSIC: Dictionary = {"stealth": "mission_basement", "gunfight": "mission_gunfight_d5", "hack": "mission_typing",
	"duel": "boss_d5"}
const AFTER_MONITORS: Array[String] = ["d5_gunfight", "d5_hack", "d5_choice", "d5_choice_tail", "d5_duel", "d5_end"]
const BURNING: Array[String] = ["d5_choice", "d5_choice_tail", "d5_duel", "d5_end"]
const HINT_S: float = 2.6

static var test_opts: Dictionary = {}

var level: LairBasement
var player: ThirdPersonController
var weapons: WeaponDirector
var weapon_wheel: WeaponWheel
var weapon_hud: WeaponHUD
var combat: PlayerCombat
# FreeRoam duck type for the missions and encounters
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
var ui: CanvasLayer
var objective_label: Label
var hint_label: Label
var busy: bool = false
var left: bool = false
var runs: int = 0
var _opts: Dictionary = {}
var _run_t: float = -1.0
var _hint_t: float = 0.0
var _cine_saved: Dictionary = {}


func _ready() -> void:
	_opts = test_opts.duplicate()
	director = StoryUtil.director()
	_build_env()
	level = LairBasement.new()
	add_child(level)
	level.build()
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
	StoryAudio.warm(["heartbeat", "toang_sting", "success_fanfare"])
	MusicDirector.warm(LAIR_MUSIC.values())   # every task track decodes on a worker now, not when its task starts
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
	e.background_color = Color(0.01, 0.01, 0.015)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.45, 0.55)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.7
	env.environment = e
	add_child(env)


func _build_player() -> void:
	player = ThirdPersonController.new()
	player.name = "Player"
	player.character_opts = director.call("protagonist_opts") if director and bool(director.get("active")) \
		else StoryUtil.builder_opts({})
	player.capture_on_click = bool(_opts.get("capture_mouse", true))
	add_child(player)
	player.teleport(level.world(LairBasement.START), 0.0)
	player.camera.make_current()
	weapon_wheel = WeaponWheel.new()
	weapon_wheel.name = "WeaponWheel"
	add_child(weapon_wheel)
	weapon_hud = WeaponHUD.new()
	weapon_hud.name = "WeaponHUD"
	add_child(weapon_hud)
	weapons = WeaponDirector.new()
	weapons.name = "Weapons"
	add_child(weapons)
	weapons.setup({"player": player, "wheel": weapon_wheel, "hud": weapon_hud, "targets_fn": _no_targets,
		"blocked_fn": weapons_blocked})
	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup({"player": player, "weapons": weapons, "targets_fn": _no_targets, "blocked_fn": weapons_blocked})


func _no_targets() -> Array:
	return []


## Weapons off during a cinematic / replay, with the player hidden, and outside the armed tasks' fights.
func weapons_blocked() -> bool:
	return cine_player != null or player == null or not player.visible or get_tree().paused


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "BasementUI"
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


## The monitor wall and the fire as the step implies (Continue mid-day, after each beat).
func _apply_state() -> void:
	var st: String = String(director.get("step")) if director else ""
	level.set_wall("error" if st in AFTER_MONITORS else "off")
	if (st in BURNING) != level.fire_on:
		level.set_fire(st in BURNING)


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


## Runs the current beat: a lair task or a cinematic of the basement; any other beat hands back to free roam.
func run_step() -> void:
	_run_t = -1.0
	if director == null or busy or left or not bool(director.get("active")):
		return   # no story running (a smoke test of the scene): the level stays, nothing runs
	if cine_player != null:
		_run_t = 0.25
		return
	var b: Dictionary = director.call("beat")
	if String(b.get("lair", "")) != "basement":
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
	_music(String(LAIR_MUSIC.get(task, "")))
	return true


func _on_mission_done(_info: Dictionary, b: Dictionary) -> void:
	_free_mission()
	if fail_ui:
		fail_ui.visible = false
	var after: String = String(b.get("after", ""))
	if after != "":
		var tl: CineTimeline = CineTimeline.load_slot(after)
		var cp: CinePlayer = play_cinematic(tl, _cine_opts()) if tl else null
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
	_music("")


func _play_cine(b: Dictionary) -> void:
	var choice_id: String = String(b.get("choice", ""))
	if choice_id != "" and String(director.call("choice_of", choice_id)) != "":
		director.call("complete_step", String(b["id"]))   # recorded once: the choice scene is not asked again
		return
	var tl: CineTimeline = CineTimeline.load_slot(cine_slot(b))
	var cp: CinePlayer = play_cinematic(tl, _cine_opts()) if tl else null
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


func _cine_opts() -> Dictionary:
	var o: Dictionary = (_opts.get("cine", {}) as Dictionary).duplicate()
	o["xf"] = level.room_xf()
	o["drop_set"] = true
	return o


## Plays a Day 5 cinematic here (the tree paused, the player and HUD hidden, the level's own copies of what the timeline
## brings hidden, the stage's exposure / ambient factors applied); restores everything on finished.
func play_cinematic(tl: CineTimeline, opts: Dictionary = {}) -> CinePlayer:
	if tl == null or cine_player != null:
		return null
	var xf: Transform3D = opts.get("xf", level.room_xf())
	var p := CinePlayer.new()
	p.name = "CinePlayer"
	add_child(p)
	if not p.setup(tl, xf, opts).is_empty():
		p.queue_free()
		return null
	StoryChapters.mark_cine(tl.slot)
	_cine_saved = {"vis": {}, "env": [env.environment.tonemap_exposure, env.environment.ambient_light_energy]}
	for n: Variant in [player, weapon_hud, ui, combat.hud if combat else null]:
		if n is Node and is_instance_valid(n) and "visible" in n:
			_cine_saved["vis"][n] = n.visible
			n.visible = false
	level.hide_for_cine(true, tl.slot == "cine_d5_monitors")
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_stop"):
		fx.call("music_stop", true)
	env.environment.tonemap_exposure *= float(tl.stage.get("exposure", 1.0))
	env.environment.ambient_light_energy *= float(tl.stage.get("ambient", 1.0))
	get_tree().paused = true
	cine_player = p
	p.finished.connect(_on_cine_finished.bind(tl.slot), CONNECT_ONE_SHOT)
	p.start()
	return p


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


## The task's owner track ("" = stop).
func _music(slot: String) -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx == null:
		return
	if slot == "":
		if fx.has_method("music_stop"):
			fx.call("music_stop", true)
	elif fx.has_method("music_play"):
		fx.call("music_play", slot, 0.5)   # warmed in _ready


## Back to story free roam (the beat after the basement, or VỀ THẾ GIỚI MỞ).
func _leave() -> void:
	if left:
		return
	left = true
	_music("")
	handed_back.emit()
	if director and bool(_opts.get("go_roam", true)):
		director.call("leave_lair")
