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
const BLOCKED_HINT: String = "Đang bị truy nã – cắt đuôi rồi hãy làm nhiệm vụ!"

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
var toast_panel: PanelContainer
var toast_label: Label
var phone: StoryPhone
var call: StoryCall
var video: StoryVideo
var cards: StoryIntroCards
var runs: int = 0
var _check_t: float = 0.0
var _obj_t: float = 0.0
var _toast_t: float = 0.0
var _run_t: float = -1.0
var _hud_saved: Dictionary = {}


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
	StoryAudio.warm(WARM)
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
	active_marker = ""
	var b: Dictionary = director.call("beat") if director else {}
	var kind: String = String(b.get("kind", ""))
	if (kind == "stage" or kind == "bed") and anchors.has(String(b.get("anchor", ""))):
		var id: String = String(b["id"])
		var pos: Vector3 = anchors[String(b["anchor"])]["pos"]
		var m: Node3D = _make_marker(id, pos, String(b.get("title", "")), kind)
		markers[id] = m
		marker_pos[id] = Vector2(pos.x, pos.z)
	_sync_map()


func _make_marker(id: String, pos: Vector3, title: String, kind: String) -> Node3D:
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
	for pair: Array in [["Title", ("💤 " if kind == "bed" else "★ ") + title, 44, 5.7, Color(1.0, 0.95, 0.98)], ["Key", "[E]", 64, 6.5, PINK]]:
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
	phone.setup(director, roam.get("player"))
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


func show_objective(text: String) -> void:
	if text == "":
		return
	objective_label.text = "🎯 " + text
	objective_panel.visible = true
	_obj_t = OBJECTIVE_S


func toast(text: String, cue: String = "phone_buzz") -> void:
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


func _on_text(msg: Dictionary) -> void:
	toast("✉ %s: %s" % [String(msg["from"]), String(msg["text"])])
	_update_chip()
	if phone.is_open():
		phone.refresh()


func _on_day(_d: int) -> void:
	_update_chip()


func _on_evidence(id: String) -> void:
	toast("📎 Bằng chứng mới %s: %s" % [id, StoryMissions.evidence_name(id)], "success_fanfare")


func _on_step(_id: String) -> void:
	_run_t = 0.05 if not busy else -1.0


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
	refresh()
	var b: Dictionary = director.call("beat")
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


func _play_cine(b: Dictionary) -> bool:
	var tl: CineTimeline = CineTimeline.load_slot(String(b["slot"]))
	if tl == null:
		director.call("complete_step", String(b["id"]))
		return false
	var a: Dictionary = anchors.get(String(b.get("at", "")), {})
	if not a.is_empty():
		var at: Vector3 = a.get("stage_pos", a["pos"])
		tl.stage["at"] = Vector2(at.x, at.z)
		tl.stage["yaw_deg"] = rad_to_deg(float(a["yaw"]))
	var cp: Variant = roam.call("play_cinematic", tl, cine_opts.duplicate())
	if cp == null:
		director.call("complete_step", String(b["id"]))   # never block the story on a missing stage spot
		return false
	busy = true
	running = String(b["id"])
	if String(b["slot"]) == "ai_intro":
		cards = StoryIntroCards.new()
		cards.name = "IntroCards"
		cards.player = cp
		add_child(cards)
	roam.connect("cinematic_finished", _on_cine_done.bind(String(b["id"])), CONNECT_ONE_SHOT)
	return true


func _on_cine_done(_slot: String, _skipped: bool, id: String) -> void:
	busy = false
	running = ""
	if cards:
		cards.queue_free()
		cards = null
	director.call("complete_step", id)


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
			video.finished.connect(_on_video_done.bind(String(b["id"])), CONNECT_ONE_SHOT)
			return
		video.queue_free()
		video = null
	_play_cine(b)


func _on_video_done(_skipped: bool, id: String) -> void:
	_pause(false)
	busy = false
	running = ""
	video = null
	director.call("complete_step", id)


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
	var b: Dictionary = StoryMissions.beat(active_marker)
	if String(b.get("kind", "")) == "bed":
		return "[E] Đi ngủ (kết thúc ngày) · " + String(b.get("title", ""))
	return "[E] Nhiệm vụ: %s" % String(b.get("title", ""))


## [E] at a marker: launches its stage beat (StoryDirector.launch_stage_beat) or goes to bed. false when blocked.
func start_marker(id: String) -> bool:
	if not markers.has(id) or busy or bool(roam.get("mounted")):
		return false
	if wanted_blocked():
		roam.call("flash_hint", BLOCKED_HINT)
		return false
	var b: Dictionary = StoryMissions.beat(id)
	match String(b.get("kind", "")):
		"stage":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var win: Variant = anchor_return(String(b.get("return", "")))
			var fail: Variant = anchor_return(String(b.get("anchor", "")))
			return bool(director.call("launch_stage_beat", id, win, fail))
		"bed":
			director.set("spawn", null)
			return bool(director.call("complete_step", id))
	return false


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
	var in_cine: bool = roam.get("cine_player") != null or busy
	ui.visible = not in_cine
	if _obj_t > 0.0:
		_obj_t -= delta
		if _obj_t <= 0.0:
			objective_panel.visible = false
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_panel.visible = false
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	_update_active()


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
			var map: Control = roam.get("map_overlay")
			if not busy and roam.get("cine_player") == null and not (map and map.visible):
				phone.toggle()
				get_viewport().set_input_as_handled()
