# File: res://tests/test_night_events_w4.gd
# Headless test of the night second chances (plan 2026-11-01-w4-endings.md T4, StoryNightSecrets):
#   A. stubs: what each spot offers by day (canal: E3 from Day 3, E4 from Day 4; lift: E2 from Day 2, E5 from Day 5), only
#      at night when StoryNightEvents.eligible (not by day, not during a mission), the lantern markers and the "Số lạ" hint
#      once per day, walking within NEAR_M plays the spot's cinematic (busy), its end adds the evidence, uses the spot for
#      the day and saves; the next day the spot offers the next missing piece;
#   B. the two cinematics: validate, <= 15 s, a joke, music night_tense, clean Vietnamese, beat sheets in sync, the scare hit
#      by default and none (no whisper bed) with "Giảm hù dọa";
#   C. real story free roam (Day 5, d5_bed at night): the lift plays night_lift13 through StoryRoam, E2 lands in the save.
# Run:  godot --headless --path . --script tests/test_night_events_w4.gd
extends SceneTree

var TMP: String = "user://test_night_w4_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_night_w4_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_night_w4_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_night_w4_backup_%d.cfg" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const SLOTS: Array[String] = ["night_ghost_boat", "night_lift13"]
const ALLOWED_SYMBOLS: Array[int] = [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026]
var fails: Array[String] = []
var sd: Node
var fx: Node
var fr: Node
var sr: StoryRoam
var phase: int = 0
var frames: int = 0
var total: int = 0


class FakeRoam extends Node3D:
	signal cinematic_finished(slot: String, skipped: bool)
	var player: Node3D = null
	var tod_preset: String = "night"
	var cine_player: Node = null
	var mounted: bool = false
	var bike: Node3D = null
	var wanted: Node = null
	var map_overlay: Control = null


class FakeStory extends Node:
	var mission_node: Node = null
	var busy: bool = false
	var running: String = ""
	var phone: Node = null
	var anchors: Dictionary = {}
	var started: Array[String] = []
	var freed: int = 0

	func _start_cinematic(slot: String, _at: String) -> Variant:
		started.append(slot)
		return self

	func _free_cards() -> void:
		freed += 1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _clean(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c >= 0x2000 and not (c in ALLOWED_SYMBOLS):
			return false
	return true


func _initialize() -> void:
	print("--- TEST NIGHT EVENTS W4 (ghost boat, lift to 13: second chances at missed evidence) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	fx = root.get_node_or_null("GameFX")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	if fx:
		fx.set("reduce_scares", false)


func _new_story(day: int, ev: Array[String]) -> void:
	sd.call("reset_state")
	sd.call("new_story", {"female": false, "name": "Huy", "variant": 0, "hair_style": "short", "hair_color": 1, "skin": 1})
	sd.set("day", day)
	sd.set("evidence", ev.duplicate())


func _part_a() -> void:
	var r := FakeRoam.new()
	var st := FakeStory.new()
	var pl := Node3D.new()
	r.player = pl
	r.add_child(pl)
	root.add_child(r)
	root.add_child(st)
	st.anchors = {"bridge_bank": {"pos": Vector3(100.0, 0.0, 50.0), "yaw": 0.0}, "duy_corner": {"pos": Vector3(-80.0, 0.0, 20.0), "yaw": 0.0}}
	var ev := StoryNightEvents.new()
	ev.auto_tick = false
	ev.dry_run = true
	root.add_child(ev)
	ev.setup(r, st, sd, 7)
	var ns := StoryNightSecrets.new()
	ns.auto_tick = false
	root.add_child(ns)
	ns.setup(r, st, sd, ev)
	# offers by day
	_new_story(2, [] as Array[String])
	_check(ns.offer("canal") == "" and ns.offer("lift") == "E2", "Day 2: the lift offers E2, the canal nothing yet (%s %s)" % [ns.offer("canal"), ns.offer("lift")])
	sd.set("day", 3)
	_check(ns.offer("canal") == "E3", "Day 3: the canal offers E3")
	sd.set("evidence", ["E2", "E3"] as Array[String])
	_check(ns.offer("canal") == "" and ns.offer("lift") == "", "Day 3 with E2 and E3: nothing to offer")
	sd.set("day", 5)
	_check(ns.offer("canal") == "E4" and ns.offer("lift") == "E5", "Day 5: the canal offers E4, the lift E5")
	sd.set("evidence", ["E1", "E2", "E3", "E4", "E5", "E6", "E7"] as Array[String])
	_check(ns.offer("canal") == "" and ns.offer("lift") == "", "everything found: nothing to offer")
	# day 5, E2 and E3 missing: by day nothing shows
	_new_story(5, ["E1", "E4", "E5"] as Array[String])
	pl.position = Vector3(0.0, 0.0, 0.0)
	r.tod_preset = "morning"
	var texts0: int = (sd.get("texts") as Array).size()
	ns.advance(1.0)
	_check(ns.markers.is_empty() and (sd.get("texts") as Array).size() == texts0, "by day: no lantern, no hint")
	# at night: both lanterns, one hint each, once
	r.tod_preset = "night"
	ns.advance(1.0)
	_check(ns.markers.has("canal") and ns.markers.has("lift"), "at night: a lantern over each spot with something to offer")
	var lm: Node3D = ns.markers.get("canal")
	_check(lm != null and lm.global_position.distance_to(Vector3(100.0, 1.6, 50.0)) < 0.01, "the canal lantern floats over bridge_bank")
	_check((sd.get("texts") as Array).size() == texts0 + 2, "at night: one 'Số lạ' hint per spot (%d)" % ((sd.get("texts") as Array).size() - texts0))
	var last: Dictionary = (sd.get("texts") as Array)[-1]
	_check(String(last["from"]) == StoryNightSecrets.HINT_FROM and _clean(String(last["text"])), "the hint comes from Số lạ, plain text")
	ns.advance(1.0)
	ns.advance(1.0)
	_check((sd.get("texts") as Array).size() == texts0 + 2, "the hints come once per day")
	# a mission blocks it
	st.mission_node = Node.new()
	pl.position = Vector3(102.0, 0.0, 52.0)
	ns.advance(1.0)
	_check(st.started.is_empty() and ns.markers.is_empty(), "never during a mission (no cinematic, lanterns gone)")
	st.mission_node.free()
	st.mission_node = null
	# far from both: nothing plays; within NEAR_M of the bank: the ghost boat
	pl.position = Vector3(0.0, 0.0, 0.0)
	ns.advance(1.0)
	_check(st.started.is_empty(), "far from the spots: nothing plays")
	pl.position = Vector3(103.0, 0.0, 53.0)
	ns.advance(1.0)
	_check(st.started == (["night_ghost_boat"] as Array[String]) and st.busy and ns.playing == "canal", "within %.0f m of the bank: night_ghost_boat plays (%s)" % [StoryNightSecrets.NEAR_M, str(st.started)])
	_check(ns.markers.is_empty(), "the lanterns go while it plays")
	ns.advance(1.0)
	_check(st.started.size() == 1, "nothing else starts while it plays")
	var got: Array = []
	ns.secret_played.connect(func(k: String, e: String) -> void: got.append([k, e]))
	r.cinematic_finished.emit("night_ghost_boat", false)
	_check(bool(sd.call("has_evidence", "E3")) and not st.busy and ns.playing == "" and st.freed == 1, "its end adds E3 and frees the story")
	_check(got == [["canal", "E3"]], "secret_played(canal, E3) (%s)" % str(got))
	_check(bool((sd.get("flags") as Dictionary).get("night_canal_d5", false)) and ns.offer("canal") == "", "the canal is used for Day 5")
	var save: Dictionary = sd.call("read_save", TMP)
	_check("E3" in (save.get("evidence", []) as Array), "the story saved with E3")
	# the next night (Day 6): the next missing piece (E4 found, so nothing; take E4 away: E4)
	sd.set("day", 6)
	_check(ns.offer("canal") == "", "Day 6: E3 and E4 found, the canal has nothing")
	sd.set("evidence", ["E1", "E3", "E5"] as Array[String])
	_check(ns.offer("canal") == "E4", "Day 6 without E4: the canal offers E4")
	# riding: the bike is the focus
	var bike := Node3D.new()
	r.add_child(bike)
	bike.position = Vector3(-81.0, 0.0, 21.0)
	r.bike = bike
	r.mounted = true
	pl.position = Vector3(0.0, 0.0, 0.0)
	ns.advance(1.0)
	_check(st.started.size() == 2 and st.started[1] == "night_lift13", "riding up to BE6: the bike is the focus, night_lift13 plays")
	r.cinematic_finished.emit("night_lift13", false)
	_check(bool(sd.call("has_evidence", "E2")), "the lift adds E2")
	ns.queue_free()
	ev.queue_free()
	st.queue_free()
	r.queue_free()


func _part_b() -> void:
	sd.call("reset_state")   # beat sheets with no protagonist (as tools/cine_beats.gd writes them)
	for s: String in SLOTS:
		fx.set("reduce_scares", false)
		var tl: CineTimeline = CineTimeline.load_slot(s)
		_check(tl != null, "%s loads" % s)
		if tl == null:
			continue
		var sheet: String = FileAccess.get_file_as_string("res://docs/cinematics/%s.txt" % s).replace("\r\n", "\n")
		_check(sheet == tl.beat_sheet(), "%s beat sheet in sync (run tools/cine_beats.gd)" % s)
		_check(tl.validate().is_empty(), "%s validates (%s)" % [s, str(tl.validate())])
		_check(tl.length <= 15.0 and tl.music_slot == "night_tense" and not tl.jokes.is_empty(), "%s: <= 15 s, night_tense, a joke" % s)
		_check(tl.scare_hits.size() == 1, "%s: one scare hit by default" % s)
		var lines: Array[String] = []
		for sb: Dictionary in tl.subs:
			lines.append(String(sb["text"]))
		_check(_clean(" ".join(PackedStringArray(lines))), "%s: plain Vietnamese lines" % s)
		fx.set("reduce_scares", true)
		var calm: CineTimeline = CineTimeline.load_slot(s)
		var cues: Array[String] = []
		for c: Dictionary in calm.sfx:
			cues.append(String(c["cue"]))
		_check(calm.scare_hits.is_empty() and not ("whisper_bed" in cues) and calm.validate().is_empty(), "%s with Giảm hù dọa: no scare hit, no whisper" % s)
		fx.set("reduce_scares", false)
		_check(CineFX.PROP_KINDS.has("boat") and CineFX.PROP_KINDS.has("lift_frame") and CineFX.PROP_KINDS.has("lift_door") and CineFX.PROP_KINDS.has("dossier"), "the night props are known kinds")
	for k: String in ["boat", "lift_frame", "lift_door", "dossier"]:
		var n := Node3D.new()
		CinePropsE.build(k, n, {})
		_check(n.get_child_count() > 0, "prop %s builds" % k)
		n.free()


func _next(p: int) -> void:
	phase = p
	frames = 0


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 20000:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	match phase:
		0:
			_part_a()
			_part_b()
			_new_story(5, ["E1", "E3", "E4", "E5"] as Array[String])
			sd.set("step", "")
			sd.call("_enter", "d5_bed")
			sd.call("save_game")
			fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			sr = fr.get("story_roam")
			_check(sr != null and sr.night_secrets != null, "StoryRoam has the night secrets")
			if sr == null or sr.night_secrets == null:
				return _end()
			sr.night_secrets.auto_tick = false
			sr.cine_opts = {"manual": true, "music": false}
			_next(1)
		1:
			if frames < 5:
				return false
			_check(sr.night_secrets.offer("lift") == "E2", "C: the lift offers E2 on Day 5")
			_check(sr.night_secrets.play("lift"), "C: the lift cinematic starts")
			_next(2)
		2:
			var cp: CinePlayer = fr.get("cine_player")
			if cp == null:
				if frames > 300:
					_check(false, "C: night_lift13 did not start")
					return _end()
				return false
			_check(cp.timeline.slot == "night_lift13" and bool(sr.get("busy")), "C: night_lift13 plays, the story is busy")
			var n: int = 0
			while fr.get("cine_player") != null and n < 3000:
				cp.step(DT)
				n += 1
			_next(3)
		3:
			if frames < 3:
				return false
			_check(bool(sd.call("has_evidence", "E2")) and not bool(sr.get("busy")) and sr.night_secrets.playing == "", "C: E2 found, the story free again")
			var save: Dictionary = sd.call("read_save", TMP)
			_check("E2" in (save.get("evidence", []) as Array) and String(save.get("step", "")) == "d5_bed", "C: the save has E2, still at d5_bed (%s)" % String(save.get("step", "")))
			_check(sr.night_secrets.offer("lift") == "", "C: the lift is used for the night")
			fr.queue_free()
			fr = null
			return _end()
	return false


func _end() -> bool:
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	paused = false
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: NIGHT EVENTS W4 (offers by day, night only, hints, lanterns, ghost boat, lift 13, reduce scares, story hand-off)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
