# File: res://scripts/story/StoryTower.gd
# The Lọ Academy tower of Day 7 (Phase D, plan 2026-11-01-w4-day7.md; scene res://scenes/story/StoryTower.tscn):
# StoryDirector.launch_lair_beat changes to this scene for a beat with "lair": "tower". Built like StoryBasement (the same
# runner, the same FreeRoam duck type for the missions and the encounters) with:
#   - LairTower (one code-built floor per segment, show_floor per task) at the origin, FxPool, the player stack
#     (ThirdPersonController, WeaponWheel, WeaponHUD, WeaponDirector, PlayerCombat) and a story HUD (objective, hints);
#   - the player's own bike (PlayerBike, parked hidden) for the parking deck: mount_bike / dismount_bike / mounted /
#     bike_parked / riding_hint / dismount_refusal as FreeRoam has them (BikeChase mounts it);
#   - the 08:00 countdown (Day7Clock): its HUD for the whole scene, ticked by the running mission's own clock (so never in a
#     cinematic, a replay, a card or behind the fail card); at 0 the mission fails ("08:00", T_LATE) and freezes; THỬ LẠI
#     (and any mission start) gives the clock at least Day7Clock.GRACE_S back, with Anh Duy's line;
#   - the runner: kind "lair" = a task (MISSION_SCRIPTS) on its floor with its music (LAIR_MUSIC; no file = silence), the
#     fail card StoryFail (THỬ LẠI = retry, VỀ THẾ GIỚI MỞ = back to free roam beside the marker, the beat stays), the beat's
#     "after" cinematic on the win (the beat completes first: autosave); kind "cine" (the monologue) = played on its floor
#     (LairTower.cine_xf) with drop_set, LairTower.hide_for_cine hiding the real pieces a timeline brings itself (the two
#     plinths under seg_d7_phase2's, the helicopter and the rain under seg_d7_finisher's) until it ends; any other beat
#     hands back (StoryDirector.leave_lair).
# Pre-merge hand-off: the last beat's next (d7_ending) belongs to the endings stream; when that beat does not exist yet the
# scene records `handoff_beat`, does not complete the step (no "unknown beat" error) and hands back.
# test_opts (static, tests): "missions" (mission opts), "cine" (CinePlayer opts), "capture_mouse" (false), "go_roam" (false).
class_name StoryTower
extends Node3D

signal cinematic_finished(slot: String, skipped: bool)
signal handed_back

const BIKE_SCENE: PackedScene = preload("res://scenes/PlayerBike.tscn")
const BIKE_FLOOR_OFFSET: float = 0.13
const MISSION_DIR: String = "res://scripts/story/missions/"
const MISSION_SCRIPTS: Dictionary = {"parking": MISSION_DIR + "MissionTowerParking.gd",
	"warehouse": MISSION_DIR + "MissionTowerForklift.gd", "servers": MISSION_DIR + "MissionTowerKatana.gd",
	"mannequins": MISSION_DIR + "MissionTowerStealth.gd", "lasers": MISSION_DIR + "MissionTowerLasers.gd",
	"boss_guns": MISSION_DIR + "MissionBossGuns.gd", "boss_dark": MISSION_DIR + "MissionBossDark.gd",
	"boss_saber": MISSION_DIR + "MissionBossSaber.gd", "typing": MISSION_DIR + "MissionTowerTyping.gd"}
const FLOOR_MUSIC: String = "mission_tower"
const BOSS_MUSIC: String = "boss_d7"
## The owner music slot of each task while it runs (no file = silence). The blackout has none: his voice and the vases.
const LAIR_MUSIC: Dictionary = {"parking": FLOOR_MUSIC, "warehouse": FLOOR_MUSIC, "servers": FLOOR_MUSIC,
	"mannequins": FLOOR_MUSIC, "lasers": FLOOR_MUSIC, "boss_guns": BOSS_MUSIC, "boss_dark": "", "boss_saber": BOSS_MUSIC,
	"typing": FLOOR_MUSIC}
const HINT_S: float = 2.6
const T_GRACE_LINE: String = "A lag server bên nó thêm chút r, lần này speedrun nha e!"
const T_GRACE_DICH: String = "Anh câu thêm giờ rồi, nhanh lên!"
const T_NO_DISMOUNT: String = "Đang đua, không xuống xe được!"

static var test_opts: Dictionary = {}

var level: LairTower
var player: ThirdPersonController
var weapons: WeaponDirector
var weapon_wheel: WeaponWheel
var weapon_hud: WeaponHUD
var combat: PlayerCombat
var bike: PlayerBike
# FreeRoam duck type for the missions and encounters
var wanted: Variant = null
var story_roam: Variant = null
var pedestrians: Variant = null
var traffic: Variant = null
var md: Variant = null
var mounted: bool = false
var bike_parked: bool = true
var riding_hint: String = ""
var dismount_refusal: String = ""
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
var clock_hud: Day7Clock
var busy: bool = false
var left: bool = false
var runs: int = 0
## The beat the last completion wanted to enter when it did not exist yet (d7_ending before the endings merge).
var handoff_beat: String = ""
## The mission failed because the clock ran out (it is frozen until THỬ LẠI).
var clock_failed: bool = false
var clock_fails: int = 0
var graces: int = 0
var looks: Array[String] = []
var extra_targets: Array = []
var _opts: Dictionary = {}
var _run_t: float = -1.0
var _hint_t: float = 0.0
var _cine_saved: Dictionary = {}
var _clock_seen: float = -1.0


func _ready() -> void:
	_opts = test_opts.duplicate()
	director = StoryUtil.director()
	_build_env()
	level = LairTower.new()
	add_child(level)
	level.build()
	add_child(FxPool.new())
	_build_player()
	_build_bike()
	_build_ui()
	clock_hud = Day7Clock.attach(self, director, _clock_visible)
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
	StoryAudio.warm(["heartbeat", "toang_sting", "success_fanfare", "sub_boom", "alarm_siren", "whisper_bed"])
	var slots: Array = []
	for v: Variant in LAIR_MUSIC.values():
		if String(v) != "" and not slots.has(v):
			slots.append(v)
	MusicDirector.warm(slots)
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
	e.background_color = Color(0.02, 0.018, 0.024)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.45)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.7
	env.environment = e
	add_child(env)
	LookPresets.set_base(self, "penthouse")   # Q3: gold and black, dramatic contrast (master plan, Day 7)


func _build_player() -> void:
	player = ThirdPersonController.new()
	player.name = "Player"
	player.character_opts = director.call("protagonist_opts") if director and bool(director.get("active")) \
		else StoryUtil.builder_opts({})
	player.capture_on_click = bool(_opts.get("capture_mouse", true))
	add_child(player)
	var pts: Dictionary = level.mission_points(_task_now())
	player.teleport(pts.get("start", pts.get("spot", level.world("parking", Vector3(0.0, 0.0, 22.0)))), 0.0)
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


## The protagonist's own bike, parked and hidden until the parking deck's chase mounts it (as FreeRoam._build_bike).
func _build_bike() -> void:
	bike = BIKE_SCENE.instantiate() as PlayerBike
	bike.name = "Bike"
	bike.road_path = null
	bike.lane_clamp_enabled = false
	bike.fallback_fall_y = -5.0
	bike.apply_speed_profile(PlayerBike.OWNER_PROFILE)
	bike.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	add_child(bike)
	bike.chase_cam.current = false
	bike.visible = false
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	bike.global_position = Vector3(0.0, -50.0, 0.0)


func _no_targets() -> Array:
	return extra_targets


func weapons_blocked() -> bool:
	return cine_player != null or player == null or not player.visible or get_tree().paused


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "TowerUI"
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
	objective_label.add_theme_color_override("font_color", Color("#FFF1D6"))
	objective_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.95))
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


func _clock_visible() -> bool:
	return cine_player == null and (mission_node == null or not is_instance_valid(mission_node) or mission_node.hud_visible())


## The task of the current beat ("" outside the tower).
func _task_now() -> String:
	if director == null:
		return "parking"
	var b: Dictionary = director.call("beat")
	if String(b.get("lair", "")) != "tower":
		return "parking"
	if String(b.get("kind", "")) == "cine":
		return "boss_guns"   # the monologue: the gallery
	return String(b.get("task", "parking"))


## The floor of the current beat shows (Continue mid-day, after each beat).
func _apply_state() -> void:
	level.show_floor(LairTower.floor_of(_task_now()))


# ----- FreeRoam duck type -----
func roam_position() -> Vector3:
	if mounted and bike:
		return bike.global_position
	return player.global_position if player else Vector3.ZERO


func find_free_spot(p: Vector3, _y: float = 0.0, _r: int = 6, _ex: Array = []) -> Variant:
	return p


func flash_hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = true
	_hint_t = HINT_S


func player_xf() -> Variant:
	return null


func look(preset: String) -> void:
	if preset in looks or not LookPresets.has(preset):
		return
	looks.append(preset)
	LookPresets.apply(preset, self)


func unlook(preset: String) -> void:
	if not (preset in looks):
		return
	looks.erase(preset)
	LookPresets.restore(self, preset)


func clear_looks() -> void:
	while not looks.is_empty():
		unlook(looks[looks.size() - 1])


## On the bike where the player stands (or where the parked bike is), the chase cam current (as FreeRoam.mount_bike).
func mount_bike() -> void:
	if mounted or bike == null or player == null:
		return
	mounted = true
	var pos: Vector3 = player.global_position
	var yaw: float = player.facing_yaw()
	bike.process_mode = Node.PROCESS_MODE_INHERIT
	bike.visible = true
	bike.global_position = pos - Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0)
	bike.rotation = Vector3(0.0, yaw, 0.0)
	bike.velocity = Vector3.ZERO
	bike.current_speed_ms = 0.0
	bike.fallback_respawn = pos + Vector3(0.0, 0.8, 0.0)
	bike.chase_cam.make_current()
	player.controls_enabled = false
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	bike_parked = false


## Off the bike beside it; the bike is put away (the tower has no other use for it).
func dismount_bike() -> bool:
	if not mounted:
		return false
	mounted = false
	bike_parked = true
	var side: Vector3 = bike.global_transform.basis.x
	side.y = 0.0
	side = side.normalized() if side.length_squared() > 0.001 else Vector3.RIGHT
	var spot: Vector3 = bike.global_position + Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0) + side * 1.1
	bike.current_speed_ms = 0.0
	bike.velocity = Vector3.ZERO
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	bike.visible = false
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.controls_enabled = true
	player.teleport(spot, bike.rotation.y)
	player.camera.make_current()
	return true


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
func _on_step(_id: String) -> void:
	if not busy:
		_run_t = 0.05


func _on_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text


func _process(delta: float) -> void:
	level.tick(delta)
	tick_clock()
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


## The 08:00 clock follows the running mission's own clock (every frame; tests call it after stepping a mission).
func tick_clock() -> void:
	if mission_node == null or not is_instance_valid(mission_node) or mission_node.state != "running" or director == null:
		_clock_seen = -1.0
		return
	var c: float = mission_node.clock
	if _clock_seen >= 0.0 and c > _clock_seen and mission_node.replay == null:
		if Day7Clock.tick(director, c - _clock_seen):
			_clock_out()
	_clock_seen = c


## 08:00: the mission fails and freezes behind the card (its encounter stops where it is) until THỬ LẠI.
func _clock_out() -> void:
	if mission_node == null or mission_node.state != "running":
		return
	clock_fails += 1
	mission_node.fail(Day7Clock.T_LATE, Day7Clock.T_TITLE)
	if mission_node.state == "failed":
		clock_failed = true
		mission_node.process_mode = Node.PROCESS_MODE_DISABLED


func run_step() -> void:
	_run_t = -1.0
	if director == null or busy or left or not bool(director.get("active")):
		return
	if cine_player != null:
		_run_t = 0.25
		return
	var b: Dictionary = director.call("beat")
	if String(b.get("lair", "")) != "tower":
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
	level.show_floor(LairTower.floor_of(task))
	if Day7Clock.grace(director):
		graces += 1
	var m: StoryMission = (load(String(MISSION_SCRIPTS[task])) as GDScript).new()
	var o: Dictionary = (_opts.get("missions", {}) as Dictionary).duplicate()
	o["level"] = level
	o["points"] = level.mission_points(task)
	busy = true
	clock_failed = false
	_clock_seen = -1.0
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
	var nxt: String = String(director.call("next_of", b))
	if nxt != "" and StoryMissions.beat(nxt).is_empty():
		handoff_beat = nxt                       # pre-merge: the endings stream's beat is not here yet
		busy = false
		_leave()
		return
	var after: String = String(b.get("after", ""))
	if after != "":
		var tl: CineTimeline = CineTimeline.load_slot(after)
		var cp: CinePlayer = play_cinematic(tl, _cine_opts(after)) if tl else null
		if cp != null:
			connect("cinematic_finished", func(_s: String, _k: bool) -> void:
				busy = false
				_run_t = 0.05, CONNECT_ONE_SHOT)
			director.call("complete_step", String(b["id"]))
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
	if mission_node == null or not is_instance_valid(mission_node) or mission_node.state != "failed":
		return
	mission_node.process_mode = Node.PROCESS_MODE_INHERIT
	var graced: bool = Day7Clock.grace(director)
	clock_failed = false
	_clock_seen = -1.0
	mission_node.retry()
	if graced:
		graces += 1
		mission_node.radio(T_GRACE_LINE, T_GRACE_DICH, 4.0)


func abort_mission() -> void:
	if fail_ui:
		fail_ui.visible = false
	_free_mission()
	busy = false
	_leave()


func _free_mission() -> void:
	if mission_node and is_instance_valid(mission_node):
		mission_node.process_mode = Node.PROCESS_MODE_INHERIT
		if mission_node.state in ["running", "failed"]:
			mission_node.abort()
		else:
			mission_node.queue_free()
	mission_node = null
	mission_beat = {}
	extra_targets = []
	clock_failed = false
	_clock_seen = -1.0
	if mounted:
		dismount_bike()
	clear_looks()
	_music("")


func _play_cine(b: Dictionary) -> void:
	var slot: String = String(b.get("slot", ""))
	var tl: CineTimeline = CineTimeline.load_slot(slot)
	var cp: CinePlayer = play_cinematic(tl, _cine_opts(slot)) if tl else null
	if cp == null:
		director.call("complete_step", String(b["id"]))
		return
	busy = true
	connect("cinematic_finished", func(_s: String, _k: bool) -> void:
		busy = false
		director.call("complete_step", String(b["id"])), CONNECT_ONE_SHOT)


func _cine_opts(slot: String) -> Dictionary:
	var o: Dictionary = (_opts.get("cine", {}) as Dictionary).duplicate()
	if LairTower.SLOT_FLOOR.has(slot):
		level.show_floor(String(LairTower.SLOT_FLOOR[slot]))
	o["xf"] = level.cine_xf(slot)
	o["drop_set"] = true
	return o


## Plays a Day 7 cinematic here (the tree paused, the player and HUD hidden, the stage's exposure / ambient applied), as
## StoryBasement.play_cinematic (a fade to black and a preroll unless manual / a hard cut).
func play_cinematic(tl: CineTimeline, opts: Dictionary = {}) -> CinePlayer:
	if tl == null or cine_player != null:
		return null
	var errs: PackedStringArray = tl.validate()
	if not errs.is_empty():
		push_error("CinePlayer: timeline %s is invalid:\n  %s" % [tl.slot, "\n  ".join(errs)])
		return null
	var xf: Transform3D = opts.get("xf", level.room_xf())
	var p := CinePlayer.new()
	p.name = "CinePlayer"
	add_child(p)
	StoryChapters.mark_cine(tl.slot)
	_cine_saved = {"vis": {}, "env": [env.environment.tonemap_exposure, env.environment.ambient_light_energy]}
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_stop"):
		fx.call("music_stop", true)
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
	for n: Variant in [player, weapon_hud, ui, clock_hud, combat.hud if combat else null, bike if mounted else null]:
		if n is Node and is_instance_valid(n) and "visible" in n:
			_cine_saved["vis"][n] = n.visible
			n.visible = false
	env.environment.tonemap_exposure *= float(tl.stage.get("exposure", 1.0))
	env.environment.ambient_light_energy *= float(tl.stage.get("ambient", 1.0))
	level.hide_for_cine(true, tl.slot)          # the real pieces the timeline brings itself (under the black frame)


func _cine_go(p: CinePlayer, tl: CineTimeline, xf: Transform3D, opts: Dictionary) -> void:
	if not is_instance_valid(p):
		return
	if cine_player != p or not p.setup(tl, xf, opts).is_empty():
		p.call("_finish", true)
		return
	p.start()


func _on_cine_finished(skipped: bool, slot: String) -> void:
	level.hide_for_cine(false)
	for n: Variant in (_cine_saved.get("vis", {}) as Dictionary).keys():
		if is_instance_valid(n):
			n.visible = _cine_saved["vis"][n]
	var ev: Array = _cine_saved.get("env", [])
	if ev.size() == 2:
		env.environment.tonemap_exposure = float(ev[0])
		env.environment.ambient_light_energy = float(ev[1])
	_cine_saved = {}
	if is_inside_tree():
		get_tree().paused = false
	if player and player.camera:
		player.camera.make_current()
	if cine_player:
		cine_player.queue_free()
	cine_player = null
	cinematic_finished.emit(slot, skipped)


func _music(slot: String) -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx == null:
		return
	if slot == "":
		if fx.has_method("music_stop"):
			fx.call("music_stop", true)
	elif fx.has_method("music_play"):
		fx.call("music_play", slot, 0.5)


## Back to story free roam (the beat after the tower, the pre-merge hand-off, or VỀ THẾ GIỚI MỞ).
func _leave() -> void:
	if left:
		return
	left = true
	_music("")
	handed_back.emit()
	if director and bool(_opts.get("go_roam", true)):
		director.call("leave_lair")
