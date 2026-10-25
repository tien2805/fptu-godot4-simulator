# File: res://scripts/story/StoryRoam.gd
# Story layer of free roam (spec A2-D4, A2-D7, A2-D8, A2-D12, A2-D13): FreeRoam adds it as a child when StoryDirector.active.
# Owns the mission markers (glowing pink #FF4FA3 pillar + Label3D like the old hotspots, radar blip, map pin), the BE6 bed
# marker, [E] to start a beat (blocked while wanted, like the Phase W hotspot rule), the objective line (bottom centre for
# 6 s on every change), the day chip (ViceHUD in vice style, a plain label in classic), the phone [P] with toasts and an
# unread badge, the 3 a.m. call overlay, the owner's AI clip or its fallback cinematic, and the beat runner that chains
# cinematics through FreeRoam.play_cinematic and reports to StoryDirector.complete_step.
# Cost: marker distance checks at 10 Hz on precomputed positions, nothing allocated per frame.
# Anchors (computed once from MapData / the campus plot, same spots as the old hotspots): be6_door (the spawn, facing away
# from the tower), be6_plaza (the old Stage 1 hotspot), be6_bed (beside the lobby door), room311 (the courtyard face of the
# room 311 module; its stage faces the courtyard).
# Phase B (plan 2026-10-25-phase-b-integration.md): beat kinds mission / fight (one StoryMission child of FreeRoam at a
# time, mission_node; fail -> StoryFail "TOANG!" / "BỊ LỘ" with THỬ LẠI / VỀ THẾ GIỚI MỞ), horror (the Night Building scene
# through StoryDirector.launch_horror_beat), marker cinematics (a cine beat with an anchor waits for [E]), choice tails
# (slot_by_choice; a choice already recorded is never asked again), side markers (E2 locker, StoryDirector.grant_side),
# "after" cinematics on a win, "auto" beats started right after the previous one when entered live (a marker otherwise:
# Continue, VỀ THẾ GIỚI MỞ, wanted). Phase B anchors: campus_gate, chase_start, west_gate, corridor, locker, bench,
# canteen, lobby (campus-plot spots, map points for the cine stages).
class_name StoryRoam
extends Node

signal step_started(id: String)

const PINK := Color("#FF4FA3")
const MARKER_RADIUS: float = 2.5
const CHECK_S: float = 0.1
const OBJECTIVE_S: float = 6.0
const TOAST_S: float = 3.5
const RUN_DELAY: float = 0.5
const RETURN_M: float = 3.5
const WARM: Array[String] = ["phone_ring_3am", "whisper_bed", "static_burst", "heartbeat", "breath", "violin_screech",
	"ba_dum_tss", "dun_dun_duun", "toang_sting", "success_fanfare", "sad_trombone", "record_scratch", "metal_creak",
	"boom", "call_hangup"]
const AUDIO_WAIT_MAX: float = 3.0
const BLOCKED_HINT: String = "Đang bị truy nã – cắt đuôi rồi hãy làm nhiệm vụ!"
const ON_FOOT_HINT: String = "Nhiệm vụ này phải đi bộ, không gọi xe được"
const MISSION_PHONE_HINT: String = "Đang làm nhiệm vụ, chưa xem điện thoại được"
const WANTED_ABORT_HINT: String = "Bị truy nã giữa nhiệm vụ! Cắt đuôi rồi quay lại cột hồng"

var roam: Node3D
var director: Node
var anchors: Dictionary = {}       # id -> {"pos": Vector3, "yaw": float, "return": Transform3D}
var markers: Dictionary = {}       # beat id -> Node3D
var marker_pos: Dictionary = {}    # beat id -> Vector2 (map plane)
var active_marker: String = ""
var busy: bool = false
var running: String = ""           # beat whose cinematic / call / video is playing
## Tests: extra CinePlayer opts ({"manual": true, "music": false}) and StoryCall opts ({"manual": true}).
var cine_opts: Dictionary = {}
var call_opts: Dictionary = {}
var ui: CanvasLayer
var objective_panel: PanelContainer
var objective_label: Label
var day_label: Label
## Owner playtest: the objective stays readable at all times as a small line under the day chip (classic style here,
## ViceHUD.set_objective in the vice style); hidden with the story HUD during cinematics. The 6 s centre flash stays.
var objective_line: Label
var toast_panel: PanelContainer
var toast_label: Label
var phone: StoryPhone
var call: StoryCall
var video: StoryVideo
var cards: CanvasLayer   # StoryIntroCards (ai_intro) or StoryDayCard (cine_day_start)
var runs: int = 0
var _check_t: float = 0.0
var _obj_t: float = 0.0
var _toast_t: float = 0.0
var _run_t: float = -1.0
var _hud_saved: Dictionary = {}
var _audio_wait: float = 0.0
var _marker_info: Dictionary = {}   # beat id -> {"kind", "title"} (hint_text without a beat lookup per tick)
var _toasts: Array[Array] = []        # queued [text, cue] while a toast is showing
## Phase B: the running roam mission (StoryMission), the fail card, extra mission opts (tests: manual, clock_scale,
## manual_replay), side markers (side id -> side dict) and whether the current step was entered while this roam ran.
var mission_node: StoryMission = null
var mission_beat: Dictionary = {}
var fail_ui: StoryFail
var mission_opts: Dictionary = {}
var side_info: Dictionary = {}
var entered_live: bool = false
const MISSION_SCRIPTS: Dictionary = {"stakeout": "res://scripts/story/missions/MissionStakeout.gd",
	"chase": "res://scripts/story/missions/MissionChase.gd", "corridor": "res://scripts/story/missions/MissionCorridor.gd",
	"canteen": "res://scripts/story/missions/MissionCanteen.gd", "fight": "res://scripts/story/missions/MissionFight.gd"}
const MARKER_KINDS: Array[String] = ["stage", "bed", "mission", "fight", "horror", "cine"]


func setup(r: Node3D) -> void:
	roam = r
	name = "StoryRoam"
	director = get_node_or_null("/root/StoryDirector")
	if director:
		director.call("register_roam", self)
	_compute_anchors()
	_build_ui()
	if director:
		director.connect("objective_changed", _on_objective)
		director.connect("text_received", _on_text)
		director.connect("day_changed", _on_day)
		director.connect("evidence_added", _on_evidence)
		director.connect("step_changed", _on_step)
	StoryAudio.warm(beat_cues(director.call("beat") if director else {}) + WARM)   # the current beat's cues first
	refresh()
	_run_t = RUN_DELAY


func _exit_tree() -> void:
	if director and is_instance_valid(director):
		for pair: Array in [["objective_changed", _on_objective], ["text_received", _on_text], ["day_changed", _on_day],
				["evidence_added", _on_evidence], ["step_changed", _on_step]]:
			if director.is_connected(String(pair[0]), pair[1]):
				director.disconnect(String(pair[0]), pair[1])
		director.call("register_roam", null)


# ---------------------------------------------------------------------------
# Anchors and markers
# ---------------------------------------------------------------------------
func _compute_anchors() -> void:
	var md: MapData = roam.get("md")
	var sp: Transform3D = md.spawn_transform()
	var fwd: Vector3 = -sp.basis.z
	var right: Vector3 = sp.basis.x
	var sp_yaw: float = sp.basis.get_euler().y
	anchors["be6_door"] = {"pos": sp.origin, "yaw": sp_yaw}
	var plaza: Vector3 = sp.origin + fwd * 7.0 + right * 3.0
	anchors["be6_plaza"] = {"pos": plaza, "yaw": sp_yaw, "return": _return_xf(plaza, sp.origin)}
	var bed: Vector3 = sp.origin - fwd * 2.5 - right * 3.5
	anchors["be6_bed"] = {"pos": bed, "yaw": sp_yaw, "return": _return_xf(bed, sp.origin + fwd * 3.0)}
	var campus_xf: Transform3D = roam.get("campus_xf")
	var ring_c: Rect2 = FPTUCampusBuilder.ring_courtyard_rect()
	var r311: Vector3 = FPTUCampusBuilder.room311_center()
	var court: Vector3 = campus_xf * Vector3(ring_c.get_center().x, 0.0, ring_c.get_center().y)
	var room: Vector3 = campus_xf * Vector3(r311.x, 0.0, ring_c.position.y + 1.5)
	var d: Vector3 = court - room
	d.y = 0.0
	d = d.normalized() if d.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0)
	# stage -Z points from the module into the courtyard: the corridor opening is behind the actors (+Z)
	anchors["room311"] = {"pos": room, "yaw": atan2(-d.x, -d.z), "stage_pos": room + d * 5.0, "return": _return_xf(room, court)}
	# Phase B (campus-plot local spots; corridor and canteen at the cine stages' map points)
	_campus_anchor("campus_gate", campus_xf * Vector3(10.0, 0.0, 6.0), campus_xf * Vector3(10.0, 0.0, -5.0))
	_campus_anchor("chase_start", campus_xf * Vector3(112.0, 0.0, 103.5), campus_xf * Vector3(100.0, 0.0, 103.5))
	_campus_anchor("west_gate", campus_xf * Vector3(176.0, 0.0, 7.0), campus_xf * Vector3(176.0, 0.0, 14.0))
	_campus_anchor("corridor", Vector3(-7.34, 0.0, 7.06), court)
	_campus_anchor("locker", campus_xf * Vector3(60.0, 0.0, 33.0), campus_xf * Vector3(60.0, 0.0, 41.0))
	_campus_anchor("bench", campus_xf * Vector3(66.0, 0.0, 45.0), campus_xf * Vector3(60.0, 0.0, 45.0))
	_campus_anchor("canteen", Vector3(-31.17, 0.0, -4.51), Vector3(-31.17, 0.0, -10.0))
	_campus_anchor("lobby", campus_xf * Vector3(85.5, 0.0, 11.0), campus_xf * Vector3(85.5, 0.0, 3.0))


## Phase B anchor at `pos` (map point), facing and returning toward `toward`.
func _campus_anchor(id: String, pos: Vector3, toward: Vector3) -> void:
	var d: Vector3 = toward - pos
	d.y = 0.0
	anchors[id] = {"pos": pos, "yaw": atan2(-d.x, -d.z) if d.length_squared() > 0.01 else 0.0, "return": _return_xf(pos, toward)}


## Spot RETURN_M from `pos` toward `toward`, free for the player's capsule, facing the marker (FreeRoam hotspot rule).
func _return_xf(pos: Vector3, toward: Vector3) -> Transform3D:
	var away: Vector3 = toward - pos
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.001 else Vector3(0.0, 0.0, 1.0)
	var back: Vector3 = pos + away * RETURN_M
	if roam.has_method("find_free_spot"):
		var spot: Variant = roam.call("find_free_spot", back, back.y, 8)
		if spot is Vector3:
			back = spot
	var face: Vector3 = back - pos
	face.y = 0.0
	if face.length_squared() < 0.01:
		face = away
	return Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)), back)


## Transform for an anchor's return spot (StoryDirector.spawn after a win / on a fail).
func anchor_return(id: String) -> Variant:
	var a: Dictionary = anchors.get(id, {})
	return a.get("return", null)


func _rebuild_markers() -> void:
	for n: Node in markers.values():
		if is_instance_valid(n):
			n.queue_free()
	markers.clear()
	marker_pos.clear()
	_marker_info.clear()
	active_marker = ""
	side_info.clear()
	var b: Dictionary = director.call("beat") if director else {}
	var kind: String = String(b.get("kind", ""))
	if mission_node == null and kind in MARKER_KINDS and anchors.has(String(b.get("anchor", ""))):
		_add_marker(String(b["id"]), anchors[String(b["anchor"])]["pos"], String(b.get("title", "")), kind)
	if mission_node == null and director:
		for sd: Dictionary in b.get("side", []):
			if bool(director.call("side_available", sd)) and anchors.has(String(sd.get("anchor", ""))):
				side_info[String(sd["id"])] = sd
				_add_marker(String(sd["id"]), anchors[String(sd["anchor"])]["pos"], String(sd.get("title", "")), "side")
	_sync_map()


func _add_marker(id: String, pos: Vector3, title: String, kind: String) -> void:
	var m: Node3D = _make_marker(id, pos, title, kind)
	markers[id] = m
	marker_pos[id] = Vector2(pos.x, pos.z)
	_marker_info[id] = {"kind": kind, "title": title}


func _make_marker(id: String, pos: Vector3, title: String, _kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "StoryMarker_" + id
	root.set_meta("beat", id)
	roam.add_child(root)
	root.global_position = pos
	var pillar := MeshInstance3D.new()
	pillar.name = "Pillar"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.7
	pm.bottom_radius = 1.1
	pm.height = 5.0
	pillar.mesh = pm
	pillar.position = Vector3(0.0, 2.5, 0.0)
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.material_override = _glow(0.32)
	root.add_child(pillar)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var rm := CylinderMesh.new()
	rm.top_radius = MARKER_RADIUS
	rm.bottom_radius = MARKER_RADIUS
	rm.height = 0.06
	ring.mesh = rm
	ring.position = Vector3(0.0, 0.16, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = _glow(0.55)
	root.add_child(ring)
	for pair: Array in [["Title", title, 44, 5.7, Color(1.0, 0.95, 0.98)], ["Key", "[E]", 64, 6.5, PINK]]:
		var l := Label3D.new()
		l.name = String(pair[0])
		l.text = String(pair[1])
		l.font_size = int(pair[2])
		l.pixel_size = 0.011
		l.outline_size = 12
		l.modulate = pair[4]
		l.outline_modulate = Color(0.1, 0.02, 0.1, 0.95)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(0.0, float(pair[3]), 0.0)
		root.add_child(l)
	return root


func _glow(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(PINK.r, PINK.g, PINK.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = PINK
	m.emission_energy_multiplier = 1.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.set_meta("vice_done", true)
	return m


## Radar blips of the markers (FreeRoam._update_vice_hud).
func blips() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in marker_pos.keys():
		out.append({"pos": marker_pos[id], "color": PINK, "shape": "circle"})
	return out


## Map pins of the markers (FreeRoam._sync_map_hotspots).
func map_pins() -> Array:
	var out: Array = []
	for id: String in marker_pos.keys():
		out.append([marker_pos[id], PINK])
	return out


func _sync_map() -> void:
	if roam.has_method("_sync_map_hotspots"):
		roam.call("_sync_map_hotspots")


func player_xf() -> Variant:
	var pl: ThirdPersonController = roam.get("player")
	if pl == null:
		return null
	return Transform3D(Basis(Vector3.UP, pl.facing_yaw()), roam.call("roam_position"))


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "StoryUI"
	ui.layer = 3
	add_child(ui)
	var watch := UIWatch.new()   # runs while the tree is paused: the story HUD hides with the rest during cinematics
	watch.name = "UIWatch"
	watch.owner_roam = self
	add_child(watch)
	objective_panel = PanelContainer.new()
	objective_panel.name = "Objective"
	objective_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	objective_panel.offset_left = -380.0
	objective_panel.offset_right = 380.0
	objective_panel.offset_top = -156.0
	objective_panel.offset_bottom = -118.0
	objective_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.02, 0.12, 0.82)
	sb.border_color = PINK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	objective_panel.add_theme_stylebox_override("panel", sb)
	objective_panel.visible = false
	ui.add_child(objective_panel)
	objective_label = _label("", 18, Color("#FFE6F3"))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_panel.add_child(objective_label)
	day_label = _label("", 16, PINK)
	day_label.name = "DayChipClassic"
	day_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	day_label.offset_left = 26.0
	day_label.offset_top = 92.0
	ui.add_child(day_label)
	objective_line = _label("", 14, Color("#FFE6F3"))
	objective_line.name = "ObjectiveLine"
	objective_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective_line.offset_left = 26.0
	objective_line.offset_top = 116.0
	objective_line.custom_minimum_size = Vector2(420.0, 0.0)
	objective_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(objective_line)
	toast_panel = PanelContainer.new()
	toast_panel.name = "Toast"
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast_panel.offset_left = -400.0
	toast_panel.offset_right = -28.0
	toast_panel.offset_top = 176.0
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tb := sb.duplicate() as StyleBoxFlat
	tb.border_color = Color("#3FF2FF")
	toast_panel.add_theme_stylebox_override("panel", tb)
	toast_panel.visible = false
	ui.add_child(toast_panel)
	toast_label = _label("", 16, Color("#F4F1FF"))
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	phone = StoryPhone.new()
	phone.setup(director, roam.get("player"), roam)
	ui.add_child(phone)
	phone.opened_changed.connect(func(_o: bool) -> void: _update_chip())


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.1, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_chip() -> void:
	if director == null:
		return
	var text: String = String(director.call("day_chip_text"))
	var unread: int = int(director.call("unread_count"))
	var vh: ViceHUD = roam.get("vice_hud")
	if vh:
		vh.set_day(text, unread)
	day_label.text = text + (" ✉%d" % unread if unread > 0 else "")
	day_label.visible = not ViceHUD.style_active()
	var obj: String = String(director.get("objective"))
	if vh:
		vh.set_objective(obj)
	objective_line.text = obj
	objective_line.visible = not ViceHUD.style_active() and obj != ""


func show_objective(text: String) -> void:
	if text == "":
		return
	objective_label.text = text
	objective_panel.visible = true
	_obj_t = OBJECTIVE_S


func toast(text: String, cue: String = "phone_buzz") -> void:
	if toast_panel.visible and _toast_t > 0.0:
		_toasts.append([text, cue])   # two texts from one beat both show, one after the other
		return
	toast_label.text = text
	toast_panel.visible = true
	_toast_t = TOAST_S
	if cue != "" and roam.is_inside_tree():
		var sp := AudioStreamPlayer.new()
		sp.bus = CinePlayer._bus("SFX")
		sp.stream = CineAudio.sfx(cue)
		add_child(sp)
		sp.play()
		sp.finished.connect(sp.queue_free)


func _on_objective(text: String) -> void:
	show_objective(text)
	_update_chip()


func _on_text(msg: Dictionary) -> void:
	toast("%s: %s" % [String(msg["from"]), String(msg["text"])])
	if phone.is_open():
		phone.refresh()
	_update_chip()


func _on_day(_d: int) -> void:
	_update_chip()


func _on_evidence(id: String) -> void:
	toast("Bằng chứng mới %s: %s" % [id, StoryMissions.evidence_name(id)], "success_fanfare")


func _on_step(_id: String) -> void:
	entered_live = true
	_run_t = 0.05 if not busy else -1.0
	if director:
		StoryAudio.warm(beat_cues(director.call("beat")))


# ---------------------------------------------------------------------------
# Beat runner
# ---------------------------------------------------------------------------
## Markers, chip and time of day for the current beat; plays it when it is a cinematic / call / video.
func refresh() -> void:
	if director == null:
		return
	if roam.get("cine_player") == null:
		roam.call("set_time_of_day", String(director.get("tod")))
	_rebuild_markers()
	_update_chip()
	show_objective(String(director.get("objective")))


func run_step() -> void:
	_run_t = -1.0
	if director == null or busy:
		return
	if roam.get("cine_player") != null:
		_run_t = 0.25   # another cinematic (busted) is playing: try again
		return
	var b: Dictionary = director.call("beat")
	var kind: String = String(b.get("kind", ""))
	var live: bool = entered_live
	entered_live = false
	if kind == "cine" and b.has("anchor"):
		refresh()   # a marker cinematic waits for [E]
		return
	if kind in ["mission", "fight"]:
		refresh()
		if bool(b.get("auto", false)) and live and not wanted_blocked() and mission_node == null:
			start_mission(b)
		return
	if kind in ["cine", "call", "video"]:
		# the beat's cues come from their warm tasks; wait (re-armed) up to AUDIO_WAIT_MAX s rather than synthesize on
		# the main thread (review A2-R1)
		if not StoryAudio.ready_for(beat_cues(b)) and _audio_wait < AUDIO_WAIT_MAX:
			_audio_wait += 0.1
			_run_t = 0.1
			return
		_audio_wait = 0.0
		if phone.is_open():
			phone.close()   # never leave the phone open under a cinematic / the call / the video
	refresh()
	var id: String = String(b.get("id", ""))
	runs += 1
	step_started.emit(id)
	match String(b.get("kind", "")):
		"cine":
			_play_cine(b)
		"call":
			_start_call(b)
		"video":
			_play_video(b)


## The SFX cues a beat needs (timeline sfx for cinematics, the call's cues), warmed first and waited on in run_step.
static func beat_cues(b: Dictionary) -> Array:
	var out: Array = []
	match String(b.get("kind", "")):
		"cine", "video":
			var tl: CineTimeline = CineTimeline.load_slot(String(b.get("slot", "")))
			if tl:
				for e: Dictionary in tl.sfx:
					if StoryAudio.is_cue(String(e["cue"])) and not out.has(String(e["cue"])):
						out.append(String(e["cue"]))
		"call":
			out = ["phone_ring_3am", "whisper_bed", "static_burst", "call_hangup"]
	return out


## Loads `slot`, stages it at anchor `at_id` (its "stage_pos" or spot, its yaw) and plays it through FreeRoam with the 2D card
## layer it needs (ai_intro: StoryIntroCards, cine_day_start: StoryDayCard). null when FreeRoam found no stage spot.
func _start_cinematic(slot: String, at_id: String) -> CinePlayer:
	var tl: CineTimeline = CineTimeline.load_slot(slot)
	if tl == null:
		return null
	var a: Dictionary = anchors.get(at_id, {})
	if not a.is_empty():
		var at: Vector3 = a.get("stage_pos", a["pos"])
		tl.stage["at"] = Vector2(at.x, at.z)
		tl.stage["yaw_deg"] = rad_to_deg(float(a["yaw"]))
	var cp: Variant = roam.call("play_cinematic", tl, cine_opts.duplicate())
	if cp == null:
		return null
	if slot == "ai_intro":
		var ic := StoryIntroCards.new()
		ic.name = "IntroCards"
		ic.player = cp
		cards = ic
		add_child(ic)
	elif slot == "cine_day_start":
		var dc := StoryDayCard.new()
		dc.name = "DayCard"
		dc.days = int(tl.get("days"))
		dc.left = int(tl.get("left"))
		dc.player = cp
		cards = dc
		add_child(dc)
	return cp


func _play_cine(b: Dictionary) -> bool:
	var choice_id: String = String(b.get("choice", ""))
	if choice_id != "" and String(director.call("choice_of", choice_id)) != "":
		director.call("complete_step", String(b["id"]))   # recorded once: the choice scene is not asked again
		return false
	var cp: CinePlayer = _start_cinematic(cine_slot(b), String(b.get("at", "")))
	if cp == null:
		director.call("complete_step", String(b["id"]))   # never block the story on a missing timeline / stage spot
		return false
	busy = true
	running = String(b["id"])
	roam.connect("cinematic_finished", _on_cine_done.bind(String(b["id"])), CONNECT_ONE_SHOT)
	return true


## The beat's cinematic slot: a branch tail follows the recorded choice (slot_by_choice), else "slot".
func cine_slot(b: Dictionary) -> String:
	var by: Dictionary = b.get("slot_by_choice", {})
	if not by.is_empty() and director:
		var key: String = String(director.call("choice_of", String(by.get("id", ""))))
		if by.has(key) and key != "id":
			return String(by[key])
	return String(b.get("slot", ""))


func _free_cards() -> void:
	if cards:
		cards.queue_free()
		cards = null


func _on_cine_done(_slot: String, _skipped: bool, id: String) -> void:
	busy = false
	running = ""
	_free_cards()
	director.call("complete_step", id)


## Mission intro (A2-D17): the stage beat's "intro" cinematic plays once when [E] is pressed, then the stage starts. A retry
## from the fail card never comes here (StoryDirector.retry_stage), so it skips the intro; so does a second [E] after a fail.
func _play_intro(b: Dictionary) -> bool:
	# A2 stage intros are staged at the marker; Phase B intros carry their own measured stage
	var at_id: String = String(b.get("anchor", "")) if String(b.get("kind", "")) == "stage" else ""
	var cp: CinePlayer = _start_cinematic(String(b["intro"]), at_id)
	if cp == null:
		return false
	busy = true
	running = String(b["id"])
	roam.connect("cinematic_finished", _on_intro_done.bind(b), CONNECT_ONE_SHOT)
	return true


func _on_intro_done(_slot: String, _skipped: bool, b: Dictionary) -> void:
	busy = false
	running = ""
	_free_cards()
	(director.get("flags") as Dictionary)["intro_" + String(b["intro"])] = true
	if String(b.get("kind", "")) == "stage":
		_launch(b)
	else:
		start_mission(b)


func _launch(b: Dictionary) -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var win: Variant = anchor_return(String(b.get("return", "")))
	var fail: Variant = anchor_return(String(b.get("anchor", "")))
	return bool(director.call("launch_stage_beat", String(b["id"]), win, fail))


func _start_call(b: Dictionary) -> void:
	busy = true
	running = String(b["id"])
	call = StoryCall.new()
	call.name = "StoryCall"
	add_child(call)
	call.finished.connect(_on_call_done.bind(String(b["id"])), CONNECT_ONE_SHOT)
	_pause(true)
	call.start(int(b.get("days", 7)), call_opts.duplicate())


func _on_call_done(_skipped: bool, id: String) -> void:
	_pause(false)
	busy = false
	running = ""
	if call:
		call.queue_free()
		call = null
	director.call("complete_step", id)


func _play_video(b: Dictionary) -> void:
	var female: bool = bool((director.get("protagonist") as Dictionary).get("female", false))
	var path: String = StoryVideo.video_file(String(b["slot"]), female)
	if path != "":
		video = StoryVideo.new()
		video.name = "StoryVideo"
		add_child(video)
		if video.play_file(path):
			busy = true
			running = String(b["id"])
			_pause(true)
			_music(false)
			video.finished.connect(_on_video_done.bind(b), CONNECT_ONE_SHOT)
			return
		video.queue_free()
		video = null
	_play_cine(b)


func _on_video_done(_skipped: bool, b: Dictionary) -> void:
	var v: StoryVideo = video
	video = null
	if v and v.left_tree:
		return   # the window / scene closed mid-video: the intro is not "seen", Continue plays it again
	_pause(false)
	busy = false
	running = ""
	_music(true)
	if v and v.failed:
		_play_cine(b)   # the owner's file could not be decoded or stalled: the in-engine fallback instead (review A2-R3)
		return
	director.call("complete_step", String(b["id"]))


## Roam music off under the owner's clip, back to the roam style after (FreeRoam.play_cinematic does the same for cinematics).
func _music(on: bool) -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx == null or not fx.has_method("music_play"):
		return
	if on:
		fx.call("music_stop", false)
		fx.call("music_play", "ride" if bool(roam.get("mounted")) else "menu", 0.15)
	else:
		fx.call("music_stop", true)


## Pauses the game for the call / the owner's video and hides the roam HUD; unpausing restores each node's own visibility.
func _pause(on: bool) -> void:
	if roam.is_inside_tree():
		roam.get_tree().paused = on
	if on:
		_hud_saved.clear()
		for n: String in ["vice_hud", "hint_holder", "stats_holder", "tod_holder"]:
			var c: Variant = roam.get(n)
			if c is CanvasItem or c is CanvasLayer:
				_hud_saved[c] = c.visible
				c.visible = false
	else:
		for c2: Variant in _hud_saved.keys():
			if is_instance_valid(c2):
				c2.visible = _hud_saved[c2]
		_hud_saved.clear()
	ui.visible = not on


# ---------------------------------------------------------------------------
# Phase B: roam missions and fights
# ---------------------------------------------------------------------------
## Starts the mission / fight of beat b (the current step): one StoryMission under FreeRoam, markers off, phone closed.
func start_mission(b: Dictionary) -> bool:
	if mission_node != null or director == null or String(b.get("id", "")) != String(director.get("step")):
		return false
	var key: String = "fight" if String(b.get("kind", "")) == "fight" else String(b.get("mission", ""))
	if not MISSION_SCRIPTS.has(key):
		push_error("StoryRoam: no mission %s" % key)
		return false
	var m: StoryMission = (load(String(MISSION_SCRIPTS[key])) as GDScript).new()
	var o: Dictionary = mission_opts.duplicate()
	if key == "fight":
		var a: Dictionary = anchors.get(String(b.get("anchor", "")), {})
		o["centre"] = _fight_centre(b, a)
		o["face"] = float(a.get("yaw", 0.0))
	if phone.is_open():
		phone.close()
	busy = true
	running = String(b["id"])
	mission_beat = b
	mission_node = m
	_clear_markers()
	roam.add_child(m)
	m.setup(roam, b, o)
	m.done.connect(_on_mission_done.bind(b), CONNECT_ONE_SHOT)
	m.failed.connect(_on_mission_failed)
	m.begin()
	return true


## Fight centre: the beat anchor (Day 1 west gate); Day 4 fights on the canteen stage the brawl cinematic shares.
func _fight_centre(b: Dictionary, a: Dictionary) -> Vector3:
	if String(b.get("fight", "")) == "d4" and roam.has_method("cine_stage"):
		var st: Variant = roam.call("cine_stage", CineTimeline.canteen_stage(Vector2(14.0, 10.0), "sunset"))
		if st is Transform3D:
			return (st as Transform3D).origin
	return a.get("pos", roam.call("roam_position"))


func _clear_markers() -> void:
	for n: Node in markers.values():
		if is_instance_valid(n):
			n.queue_free()
	markers.clear()
	marker_pos.clear()
	_marker_info.clear()
	side_info.clear()
	active_marker = ""
	_sync_map()


func _free_mission() -> void:
	if mission_node and is_instance_valid(mission_node):
		if mission_node.state in ["running", "failed"]:
			mission_node.abort()
		else:
			mission_node.queue_free()
	mission_node = null
	mission_beat = {}


## The beat completes (autosave) before its "after" cinematic: quitting during the cinematic never replays the fight or
## the walk; Continue simply goes on without the cinematic. busy holds the next beat until the cinematic ends.
func _on_mission_done(_info: Dictionary, b: Dictionary) -> void:
	_free_mission()
	if fail_ui:
		fail_ui.visible = false
	var after: String = String(b.get("after", ""))
	if after != "":
		var cp: CinePlayer = _start_cinematic(after, "")
		if cp != null:
			running = String(b["id"])
			roam.connect("cinematic_finished", _on_after_done.bind(b), CONNECT_ONE_SHOT)
			director.call("complete_step", String(b["id"]))
			return
	busy = false
	running = ""
	_complete_mission(b)


func _on_after_done(_slot: String, _skipped: bool, b: Dictionary) -> void:
	busy = false
	running = ""
	_free_cards()
	if b.has("win_line"):
		toast(String(b["win_line"]), "")
	_run_t = 0.05   # the next beat (its step_changed came while busy)


func _complete_mission(b: Dictionary) -> void:
	director.call("complete_step", String(b["id"]))
	if b.has("win_line"):
		toast(String(b["win_line"]), "")


func _on_mission_failed(title: String, reason: String) -> void:
	if fail_ui == null:
		fail_ui = StoryFail.new()
		fail_ui.name = "StoryFail"
		add_child(fail_ui)
		fail_ui.retry_pressed.connect(retry_mission)
		fail_ui.leave_pressed.connect(abort_mission)
	fail_ui.show_fail(title, reason)


## THỬ LẠI: the mission back at the beat's checkpoint.
func retry_mission() -> void:
	if fail_ui:
		fail_ui.visible = false
	if mission_node and is_instance_valid(mission_node) and mission_node.state == "failed":
		mission_node.retry()


## VỀ THẾ GIỚI MỞ: the mission ends without a result; its marker comes back (the beat stays).
func abort_mission() -> void:
	if fail_ui:
		fail_ui.visible = false
	_free_mission()
	busy = false
	running = ""
	refresh()


# ---------------------------------------------------------------------------
# Markers: [E]
# ---------------------------------------------------------------------------
func wanted_blocked() -> bool:
	var w: Variant = roam.get("wanted")
	if w == null or not is_instance_valid(w):
		return false
	return String(w.get("state")) != "free" or int(w.get("stars")) > 0


func hint_text() -> String:
	if active_marker == "":
		return ""
	if wanted_blocked():
		return BLOCKED_HINT
	var info: Dictionary = _marker_info.get(active_marker, {})
	if String(info.get("kind", "")) == "bed":
		return "[E] Đi ngủ (kết thúc ngày) · " + String(info.get("title", ""))
	if String(info.get("kind", "")) == "side":
		return "[E] Mở: %s" % String(info.get("title", ""))
	return "[E] Nhiệm vụ: %s" % String(info.get("title", ""))


## [E] at a marker: launches its stage beat (StoryDirector.launch_stage_beat) or goes to bed. false when blocked.
func start_marker(id: String) -> bool:
	if not markers.has(id) or busy or bool(roam.get("mounted")):
		return false
	var map: Control = roam.get("map_overlay")
	if phone.is_open() or (map != null and map.visible):
		return false   # review A2-R4: never start a beat with the phone or the map on top
	if wanted_blocked():
		roam.call("flash_hint", BLOCKED_HINT)
		return false
	if side_info.has(id):
		return use_side(id)
	var b: Dictionary = StoryMissions.beat(id)
	match String(b.get("kind", "")):
		"stage", "mission", "fight":
			var intro: String = String(b.get("intro", ""))
			if intro != "" and not bool((director.get("flags") as Dictionary).get("intro_" + intro, false)) and _play_intro(b):
				return true   # the stage / mission starts when the intro ends
			if String(b["kind"]) == "stage":
				return _launch(b)
			return start_mission(b)
		"horror":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var xf: Variant = anchor_return(String(b.get("anchor", "")))
			return bool(director.call("launch_horror_beat", id, xf, xf))
		"cine":
			_play_cine(b)
			return true
		"bed":
			director.set("spawn", null)
			return bool(director.call("complete_step", id))
	return false


## [E] at a side marker (E2 locker): its evidence once, a toast with its line.
func use_side(id: String) -> bool:
	var sd: Dictionary = side_info.get(id, {})
	if sd.is_empty() or not bool(director.call("grant_side", sd)):
		return false
	if sd.has("line"):
		toast(String(sd["line"]), "")
	_rebuild_markers()
	return true


func _update_active() -> void:
	var found: String = ""
	if not bool(roam.get("mounted")) and not marker_pos.is_empty():
		var p: Vector3 = roam.call("roam_position")
		var pp := Vector2(p.x, p.z)
		for id: String in marker_pos.keys():
			if pp.distance_to(marker_pos[id]) <= MARKER_RADIUS:
				found = id
				break
	active_marker = found


func _process(delta: float) -> void:
	if _run_t >= 0.0:
		_run_t -= delta
		if _run_t < 0.0:
			run_step()
	if _obj_t > 0.0:
		_obj_t -= delta
		if _obj_t <= 0.0:
			objective_panel.visible = false
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_panel.visible = false
			if not _toasts.is_empty():
				var nx: Array = _toasts.pop_front()
				toast(String(nx[0]), String(nx[1]))
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	_update_active()
	if mission_node != null and _wanted_not_free():
		abort_mission()   # defensive: a bust mid-mission would run the chore under the mission (markers come back)
		roam.call("flash_hint", WANTED_ABORT_HINT)


func _wanted_not_free() -> bool:
	var w: Variant = roam.get("wanted")
	return w != null and is_instance_valid(w) and String(w.get("state")) != "free"


## Story HUD visible only in plain free roam (A2-D12): hidden during cinematics (FreeRoam.cine_player), the call, the video.
func hud_should_show() -> bool:
	if roam.get("cine_player") != null:
		return false
	if mission_node != null and is_instance_valid(mission_node):
		return mission_node.hud_visible()
	return not busy


## PROCESS_MODE_ALWAYS helper: keeps the story HUD visibility right while the tree is paused (one bool read per frame).
class UIWatch extends Node:
	var owner_roam: StoryRoam

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_d: float) -> void:
		if owner_roam and owner_roam.ui:
			var show: bool = owner_roam.hud_should_show()
			if owner_roam.ui.visible != show:
				owner_roam.ui.visible = show


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_E:
			if active_marker != "" and start_marker(active_marker):
				get_viewport().set_input_as_handled()
			elif active_marker != "" and wanted_blocked():
				get_viewport().set_input_as_handled()
		KEY_P:
			if mission_node != null:
				roam.call("flash_hint", MISSION_PHONE_HINT)   # MeleeFight refuses [P] itself in a fight (it reads it first)
				get_viewport().set_input_as_handled()
				return
			var map: Control = roam.get("map_overlay")
			if not busy and roam.get("cine_player") == null and not (map and map.visible) and not bool(roam.get("mounted")):
				phone.toggle()   # on foot only: the bike reads its keys directly (review A2-R2)
				get_viewport().set_input_as_handled()
