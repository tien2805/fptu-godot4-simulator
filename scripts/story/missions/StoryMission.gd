# File: res://scripts/story/missions/StoryMission.gd
# Base of the Phase B roam missions (plan 2026-10-25-phase-b-integration.md, Task 3): StoryRoam adds one under FreeRoam
# for a "mission" / "fight" beat, calls setup(roam, beat, opts) then begin(), and listens to:
#   done(info)              the mission is won (StoryRoam plays the beat's "after" cinematic, then completes the step)
#   failed(title, reason)   "TOANG!" / "BỊ LỘ": StoryRoam shows StoryFail; THỬ LẠI calls retry() (back to the beat's
#                           checkpoint), VỀ THẾ GIỚI MỞ calls abort() (the marker comes back)
# While it runs the player is on foot and unarmed (the weapon wheel locked, Phase B story rule S-D5) and a small HUD shows
# the title, an info line (timer / meter), a prompt and an optional meter. Mission logic runs on its own clock:
# advance(dt) from _physics_process (dt * clock_scale), or from the test when opts.manual is true.
# opts (tests): manual (bool), clock_scale (float), manual_replay (bool: short replays stepped by the test), seed (int).
# Subclasses override _start(), _reset(), _tick(dt), _cleanup(); they call fail(reason, title) and finish(info).
# Phase C: `armed` missions (the lair gunfights) skip the unarmed lock (GunFight forces its own loadout: story lairs allow
# the Phase W guns, campus stays unarmed); radio(line, dich) shows Anh Duy on the radio with his "Dịch:" line; the host
# may be FreeRoam or a lair scene (StoryBasement) with the same fields (player, weapons, combat, mounted).
# Q5 (plan 2026-10-29-w2-story T4): radio lines type out with the speaker's blip voice (StoryRadio); radio_as(speaker, ...)
# for other speakers (Mr.T on the phone, Linh, Chú Bảy); the beat's StoryRadio.SCRIPTS lines play on the mission clock.
# Wave 3 ranks (plan 2026-10-30-w3-shared.md T7): `stats` feeds StoryRank. The base fills "time" (seconds on the mission
# clock while running, failed attempts included, short replays not), "fails" (retries) and "dmg" (every drop of the
# host's combat.hp, sampled each tick and at a fail: no mission needs code for damage); subclasses call add_stat("ko") per
# takedown or set_stat(key, v). A retry keeps the stats (only the per-attempt mission state resets).
# T8: finish(info) on a ranked beat (StoryRank.MISSIONS) evaluates the run (rank, rank_eval; info gains "rank") and shows
# the StoryRankCard (unless StoryRankCard.skip_all); `done` waits for the card to close, except in `manual` /
# `manual_replay` runs (tests), where the card shows without holding `done`.
class_name StoryMission
extends Node3D

signal done(info: Dictionary)
signal failed(title: String, reason: String)

const T_TOANG: String = "TOANG!"
const T_LO: String = "BỊ LỘ"
const PINK := Color("#FF4FA3")
const INK := Color("#F4F1FF")
const WARN := Color("#FF5C7A")

var roam: Node3D
var player: ThirdPersonController
var beat: Dictionary = {}
var opts: Dictionary = {}
## idle | running | failed | done | aborted
var state: String = "idle"
var clock: float = 0.0
var clock_scale: float = 1.0
var manual: bool = false
var fails: int = 0
var retries: int = 0
var replay: CineReplay = null
var cues_played: Array[String] = []
var hud: CanvasLayer
var hud_title: Label
var hud_info: Label
var hud_prompt: Label
var hud_meter: ProgressBar
var popup_label: Label
var _popup_t: float = 0.0
var _locked: bool = false
var _prev_locked: bool = false
## Phase C: lair missions keep the weapons (GunFight forces the loadout).
var armed: bool = false
var radio_panel: PanelContainer
var radio_label: Label
var _radio_t: float = 0.0
var radio_typer: StoryRadio = null
var _radio_script: Array = []
var _radio_i: int = 0
## Wave 3 ranks: the run's stats (StoryRank.report reads them).
var stats: Dictionary = {"time": 0.0, "fails": 0, "dmg": 0.0}
var _hp_seen: float = -1.0
## The finished run's letter ("" = unranked beat), its StoryRank.evaluate result and the results card while it shows.
var rank: String = ""
var rank_eval: Dictionary = {}
var rank_card: StoryRankCard = null


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	roam = r
	player = r.get("player") if r else null
	beat = b
	opts = o.duplicate()
	clock_scale = float(opts.get("clock_scale", 1.0))
	manual = bool(opts.get("manual", false))
	name = "Mission_" + String(b.get("id", "x"))


## Starts the mission (the node is in the tree).
func begin() -> void:
	_build_hud()
	_off_bike()
	_lock_weapons(true)
	clock = 0.0
	stats = {"time": 0.0, "fails": 0, "dmg": 0.0}
	_hp_seen = -1.0
	_sample_hp()
	state = "running"
	_radio_script = StoryRadio.lines(String(beat.get("id", "")))
	_radio_i = 0
	_start()


## THỬ LẠI after a fail: back to the beat's checkpoint.
func retry() -> void:
	retries += 1
	clock = 0.0
	_radio_i = 0   # the beat's scripted radio lines play again after a fail
	_lock_weapons(true)
	_off_bike()
	state = "running"
	_reset()
	_hp_seen = -1.0                          # the checkpoint revives the player: sample afresh
	_sample_hp()


## VỀ THẾ GIỚI MỞ (or the scene leaving): ends without a result and frees the node.
func abort() -> void:
	state = "aborted"
	_end()
	queue_free()


func fail(reason: String, title: String = T_TOANG) -> void:
	if state != "running":
		return
	_sample_hp()
	state = "failed"
	fails += 1
	stats["fails"] = fails
	failed.emit(title, reason)


func finish(info: Dictionary = {}) -> void:
	if state != "running":
		return
	state = "done"
	_end()
	var id: String = String(beat.get("id", ""))
	rank_eval = StoryRank.evaluate(id, stats, info)
	if rank_eval.is_empty():
		done.emit(info)
		return
	rank = String(rank_eval["letter"])
	var out: Dictionary = info.duplicate()
	out["rank"] = rank
	var best_before: String = StoryRank.best(id)
	var sd: Node = get_node_or_null("/root/StoryDirector") if is_inside_tree() else null
	if sd != null and sd.has_method("record_rank"):
		sd.call("record_rank", id, rank)       # T9: the best rank goes into the save (and the chapter unlock file)
	if StoryRankCard.skip_all:
		done.emit(out)
		return
	rank_card = StoryRankCard.make(rank_eval, String(beat.get("title", "")), best_before)
	add_child(rank_card)
	if manual or bool(opts.get("manual_replay", false)):
		rank_card.manual = true
		done.emit(out)
		return
	rank_card.closed.connect(func() -> void: done.emit(out), CONNECT_ONE_SHOT)


func _end() -> void:
	_lock_weapons(false)
	if player and is_instance_valid(player):
		player.combat_speed_cap = INF
		player.controls_enabled = true
	_cleanup()
	if hud:
		hud.visible = false


## Mission HUD visible (StoryRoam keeps its objective line on top while this is true).
func hud_visible() -> bool:
	return state in ["running", "failed"] and replay == null


func advance(dt: float) -> void:
	if radio_typer != null:
		radio_typer.step(dt)
	if _radio_t > 0.0:
		_radio_t -= dt
		if _radio_t <= 0.0 and radio_panel:
			radio_panel.visible = false
	if _popup_t > 0.0:
		_popup_t -= dt
		if _popup_t <= 0.0 and popup_label:
			popup_label.visible = false
	if state != "running":
		return
	clock += dt
	if replay == null:
		stats["time"] = float(stats.get("time", 0.0)) + dt
	_sample_hp()
	if _radio_i < _radio_script.size() and _radio_t <= 0.0 and clock >= float(_radio_script[_radio_i][0]):
		var rl: Array = _radio_script[_radio_i]
		_radio_i += 1
		radio_as(String(rl[1]), String(rl[2]), String(rl[3]))
	_tick(dt)


func _physics_process(delta: float) -> void:
	if not manual:
		advance(delta * clock_scale)


func _exit_tree() -> void:
	if state == "running" or state == "failed":
		_end()


# ----- Wave 3 ranks: stats -----
func add_stat(key: String, n: Variant = 1) -> void:
	stats[key] = stats.get(key, 0) + n


func set_stat(key: String, v: Variant) -> void:
	stats[key] = v


## Adds every drop of the host's combat.hp since the last sample to stats.dmg.
func _sample_hp() -> void:
	var c: Object = roam.get("combat") if roam != null and is_instance_valid(roam) else null
	if c == null or not is_instance_valid(c) or not ("hp" in c):
		return
	var hp: float = float(c.get("hp"))
	if _hp_seen >= 0.0 and hp < _hp_seen:
		stats["dmg"] = float(stats.get("dmg", 0.0)) + (_hp_seen - hp)
	_hp_seen = hp


# ----- virtuals -----
func _start() -> void:
	pass


func _reset() -> void:
	pass


func _tick(_dt: float) -> void:
	pass


func _cleanup() -> void:
	pass


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
## Map point of a campus-plot local point (FPTUCampusBuilder u, v).
func campus(local: Vector3) -> Vector3:
	var xf: Transform3D = roam.get("campus_xf") if roam else Transform3D.IDENTITY
	return xf * local


## Map yaw (radians) of a campus-plot direction.
func campus_dir(local_dir: Vector3) -> Vector3:
	var xf: Transform3D = roam.get("campus_xf") if roam else Transform3D.IDENTITY
	return (xf.basis * local_dir).normalized()


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Floor height under p (the highest floor within 3 m above / 4 m below), p.y when none.
func ground_y(p: Vector3) -> float:
	if not is_inside_tree():
		return p.y
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 3.0, 0.0), p - Vector3(0.0, 4.0, 0.0))
	if player:
		q.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y


## A spot free for the player's capsule near p (FreeRoam.find_free_spot), p otherwise.
func free_spot(p: Vector3, r: int = 6) -> Vector3:
	if roam and roam.has_method("find_free_spot"):
		var s: Variant = roam.call("find_free_spot", p, p.y, r)
		if s is Vector3:
			return s
	return p


func teleport_player(p: Vector3, yaw: float) -> void:
	if player == null:
		return
	player.teleport(p + Vector3(0.0, 0.05, 0.0), yaw)
	player.visible = true


## A cast body (StoryCast id) on the floor at p facing `yaw` (characters face -Z at 0).
func spawn_body(cast_id: String, p: Vector3, yaw: float, extra: Dictionary = {}) -> Node3D:
	var body: Node3D = StoryCast.build(cast_id, extra)
	if body == null:
		return null
	add_child(body)
	body.global_position = p
	body.rotation.y = yaw
	return body


## true when `to` is in sight of an eye at `from` looking along `fwd` (flat): within range_m, inside the half angle, and
## the first thing a ray from the eye hits is the player (or nothing).
func sees_player(from: Vector3, fwd: Vector3, range_m: float, half_deg: float) -> bool:
	if player == null:
		return false
	var to: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dist: float = d.length()
	if dist > range_m:
		return false
	if dist > 0.01:
		var f := Vector3(fwd.x, 0.0, fwd.z).normalized()
		if f.dot(d / dist) < cos(deg_to_rad(half_deg)):
			return false
	return clear_line(from, to)


## A ray from `a` to `b` hits nothing but the player.
func clear_line(a: Vector3, b: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b)
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty() or (player != null and hit.get("collider") == player)


## One-shot cue: story cues once warmed (never synthesized on the main thread), A1 cues from the CineAudio cache.
## Counted in cues_played (tests) even when the sound is skipped.
func play_cue(cue: String, db: float = 0.0) -> void:
	cues_played.append(cue)
	if not is_inside_tree():
		return
	var st: AudioStream = null
	if StoryAudio.is_cue(cue):
		if not StoryAudio.ready_for([cue]):
			return
		st = StoryAudio.stream_once(cue)
		db += StoryAudio.cue_db(cue)
	else:
		st = CineAudio.sfx(cue)
	if st == null:
		return
	var sp := AudioStreamPlayer.new()
	sp.bus = CinePlayer._bus("SFX")
	sp.stream = st
	sp.volume_db = db
	add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)


## Centre popup for `secs` (plain text).
func popup(text: String, secs: float = 2.0, col: Color = INK) -> void:
	if popup_label == null:
		return
	popup_label.text = text
	popup_label.add_theme_color_override("font_color", col)
	popup_label.visible = true
	_popup_t = secs


## Anh Duy on the radio (story spec S-D12): his jargon line and a second "Dịch:" line, bottom left for `secs`.
func radio(line: String, dich: String, secs: float = 5.0) -> void:
	radio_as("anh_duy", line, dich, secs)


## A radio line from any speaker (StoryRadio.PREFIX), typed with the speaker's voice; stays at least until it is read.
func radio_as(speaker_id: String, line: String, dich: String = "", secs: float = 5.0) -> void:
	cues_played.append("radio")
	if radio_panel == null:
		return
	if radio_typer == null:
		radio_typer = StoryRadio.new()
		add_child(radio_typer)
	radio_typer.say(radio_label, speaker_id, line, dich)
	radio_panel.visible = true
	_radio_t = maxf(secs, radio_typer.min_secs())


## Hides the top panel (title / info / meter) when the mission's own HUD shows those (BikeHUD, GunHUD).
func hide_top_panel() -> void:
	var top: Node = hud.get_node_or_null("Top") if hud else null
	if top:
		(top as CanvasItem).visible = false


func set_info(text: String) -> void:
	if hud_info:
		hud_info.text = text


func set_prompt(text: String) -> void:
	if hud_prompt:
		hud_prompt.text = text
		hud_prompt.visible = text != ""


func set_meter(v: float, label: String = "") -> void:
	if hud_meter:
		hud_meter.visible = v >= 0.0
		hud_meter.value = clampf(v, 0.0, 100.0)
		if label != "":
			hud_meter.tooltip_text = label


# ---------------------------------------------------------------------------
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "MissionHUD"
	hud.layer = 4
	add_child(hud)
	var panel := PanelContainer.new()
	panel.name = "Top"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = 64.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.02, 0.12, 0.8)
	sb.border_color = PINK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(panel)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	hud_title = _label(String(beat.get("title", "")).to_upper(), 20, PINK)
	vb.add_child(hud_title)
	hud_info = _label("", 16, INK)
	vb.add_child(hud_info)
	hud_meter = ProgressBar.new()
	hud_meter.custom_minimum_size = Vector2(320.0, 14.0)
	hud_meter.show_percentage = false
	hud_meter.max_value = 100.0
	hud_meter.visible = false
	hud_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = WARN
	fill.set_corner_radius_all(5)
	hud_meter.add_theme_stylebox_override("fill", fill)
	vb.add_child(hud_meter)
	hud_prompt = _label("", 18, Color("#FFE66D"))
	hud_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud_prompt.offset_top = -210.0
	hud_prompt.offset_bottom = -180.0
	hud_prompt.offset_left = -360.0
	hud_prompt.offset_right = 360.0
	hud_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_prompt.visible = false
	hud.add_child(hud_prompt)
	popup_label = _label("", 34, INK)
	popup_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup_label.offset_left = -420.0
	popup_label.offset_right = 420.0
	popup_label.offset_top = -120.0
	popup_label.offset_bottom = -70.0
	popup_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_label.add_theme_constant_override("outline_size", 8)
	popup_label.visible = false
	hud.add_child(popup_label)
	radio_panel = PanelContainer.new()
	radio_panel.name = "Radio"
	radio_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	radio_panel.offset_left = 24.0
	radio_panel.offset_right = 560.0
	radio_panel.offset_top = -250.0
	radio_panel.offset_bottom = -170.0
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rb := sb.duplicate() as StyleBoxFlat
	rb.border_color = Color("#3FF2FF")
	radio_panel.add_theme_stylebox_override("panel", rb)
	radio_panel.visible = false
	hud.add_child(radio_panel)
	radio_label = _label("", 16, INK)
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_panel.add_child(radio_label)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.1, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _off_bike() -> void:
	if roam and bool(roam.get("mounted")) and roam.has_method("dismount_bike"):
		roam.call("dismount_bike")


## Story campus missions are unarmed (S-D5): Tay không equipped, the wheel and scroll locked (not for `armed` missions).
func _lock_weapons(on: bool) -> void:
	if armed and on:
		return
	var w: WeaponDirector = roam.get("weapons") if roam else null
	if w == null or not is_instance_valid(w):
		return
	if on and not _locked:
		_prev_locked = w.locked
		w.equip(WeaponData.Slot.UNARMED)
		w.locked = true
		_locked = true
	elif not on and _locked:
		w.locked = _prev_locked
		_locked = false


## Short replay of `rec` (StoryStage, pauses the tree); calls `then` when it ends (at once without footage).
func play_short_replay(rec: CineReplayRecorder, slot: String, focus: Node3D, other: Node3D, then: Callable) -> void:
	replay = StoryStage.play_replay(self, rec, slot, focus, other, {"manual": bool(opts.get("manual_replay", false))})
	if replay == null:
		then.call()
		return
	if hud:
		hud.visible = false   # the replay has its own overlay
	replay.finished.connect(func() -> void:
		replay = null
		if hud:
			hud.visible = true
		then.call(), CONNECT_ONE_SHOT)
