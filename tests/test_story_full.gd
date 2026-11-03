# File: res://tests/test_story_full.gd
# w5-complete T9 (plan 2026-11-03-w5-complete.md): the whole story on the director, from new_story to an ending, once per
# ending path. Each beat gets its kind's real result call: complete_step for the cinematics, videos, beds, calls; the
# StageManager story_context + on_stage_result win for the stage beats; record_rank (StoryRank.report on sample stats) +
# the mission's flag_by_info flags + complete_step for the missions, fights and lair tasks (StoryRoam._on_mission_done);
# on_horror_result for the Night Building escape; the choice beats write StoryDirector.choices like StoryChoice; the side
# markers are taken with grant_side when the path collects them. Checked per path: the days 0..7 in order (day_changed),
# each call's N (= days left), the autosave after every beat (the save's step = the director's), the evidence, every beat
# of the chain visited once (83 on the full chain), a Continue round trip at the start of Day 4 (a fresh director loads
# the same state and continue_story enters roam), and the ending: A, B, D, E by resolve_ending on d7_ending, C on Day 5
# (d5_end_c); the save is marked finished and Continue refuses it. Temp save, temp chapter files, no navigation.
# Run:  godot --headless --path . --script tests/test_story_full.gd
extends SceneTree

const MAX_BEATS: int = 200
var TMP: String = "user://test_story_full_save_%d.cfg" % OS.get_process_id()
var TMP_CH: String = "user://test_story_full_%d" % OS.get_process_id()
var fails: Array[String] = []
var keep_paths: Array[String] = []
var keep_ctx: Variant = null
var frames: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY FULL (Day 0 to every ending on the director) ---")


## Runs on the second frame: the directors must be inside the tree (StageManager lookups, the result card).
func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		_run()
	elif frames == 5:
		_end()
	return false


func _run() -> void:
	keep_paths = [StoryChapters.unlocks_path, StoryChapters.chapters_path, StoryChapters.backup_path]
	StoryChapters.unlocks_path = TMP_CH + "_unlocks.cfg"
	StoryChapters.chapters_path = TMP_CH + "_chapters.cfg"
	StoryChapters.backup_path = TMP_CH + "_backup.cfg"
	var sm: Node = root.get_node_or_null("StageManager")
	keep_ctx = sm.get("story_context") if sm else null
	var ok: Dictionary = {"phuc": "cover", "zaman_offer": "refuse", "bribe": "refuse"}
	var all7: Array = ["E1", "E2", "E3", "E4", "E5", "E6", "E7"]
	_path("A", ok, true, 0, all7, 83)
	_path("B", {"phuc": "report", "zaman_offer": "refuse", "bribe": "refuse"}, true, 0, all7, -1)
	_path("D", {"phuc": "cover", "zaman_offer": "refuse", "bribe": "take"}, true, 0, all7, -1)
	_path("D", ok, false, 0, ["E1", "E5", "E6", "E7"], -1)   # no side markers: 4 pieces
	_path("E", ok, false, 2, ["E1", "E6", "E7"], -1)          # no sides, caught twice: 3 pieces
	_path("C", {"phuc": "cover", "zaman_offer": "accept", "bribe": ""}, true, 0, ["E1", "E2", "E3", "E4", "E5"], -1)
	if sm:
		sm.set("story_context", keep_ctx if keep_ctx is Dictionary else {})
	StoryChapters.unlocks_path = keep_paths[0]
	StoryChapters.chapters_path = keep_paths[1]
	StoryChapters.backup_path = keep_paths[2]
	for p: String in [TMP, TMP_CH + "_unlocks.cfg", TMP_CH + "_chapters.cfg", TMP_CH + "_backup.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## A few frames after the walk: the directors' deferred UI calls ran and the directors are freed.
func _end() -> void:
	if fails.is_empty():
		print("✅ SUCCESS: STORY FULL (Day 0 to the endings A, B, D, E and C: every beat's result, days, calls, autosaves, evidence, Continue)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _director() -> Node:
	var sd: Node = (load("res://scripts/story/StoryDirector.gd") as Script).new()
	sd.name = "StoryDirectorFull"
	root.add_child(sd)
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	return sd


## Plays the story with the choices `plan`; sides = take every optional side marker when it opens; catches = the Night
## Building catches. Expects the ending `want`, the evidence `ev` and (when >= 0) that many distinct beats visited.
func _path(want: String, plan: Dictionary, sides: bool, catches: int, ev: Array, beats_n: int) -> void:
	var tag: String = "%s (%s, sides %s, catches %d)" % [want, str(plan), str(sides), catches]
	for p: String in [TMP, TMP_CH + "_unlocks.cfg", TMP_CH + "_chapters.cfg", TMP_CH + "_backup.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var sd: Node = _director()
	var days: Array[int] = []
	var visited: Array[String] = []
	sd.connect("day_changed", func(d: int) -> void: days.append(d))
	sd.connect("step_changed", func(s: String) -> void: visited.append(s))
	sd.call("new_story", {"name": "Khoa", "female": false})
	var sm: Node = root.get_node_or_null("StageManager")
	var round_trip: bool = false
	var n: int = 0
	while String(sd.get("ending")) == "" and n < MAX_BEATS:
		n += 1
		var id: String = String(sd.get("step"))
		var b: Dictionary = StoryMissions.beat(id)
		var kind: String = String(b.get("kind", ""))
		_check(not b.is_empty() and kind != "locked", "%s: beat %s exists and is not a placeholder (%s)" % [tag, id, kind])
		if b.is_empty() or kind == "locked":
			break
		if int(sd.get("day")) == 4 and not round_trip:
			round_trip = true
			_continue_round_trip(sd, tag)
		if b.has("choice"):
			(sd.get("choices") as Dictionary)[String(b["choice"])] = String(plan.get(String(b["choice"]), ""))
		if sides:
			for sdef: Variant in b.get("side", []):
				if bool(sd.call("side_available", sdef)):
					sd.call("grant_side", sdef)
		if kind == "call":
			_check(int(b.get("days", -1)) == 7 - int(sd.get("day")), "%s: %s says %d days left on Day %d" % [tag, id, int(b.get("days", -1)), int(sd.get("day"))])
		match kind:
			"horror":
				_check(bool(sd.call("on_horror_result", catches, false)), "%s: the horror result is taken at %s" % [tag, id])
			"stage":
				if sm:
					sm.set("story_context", {"beat": id, "stage": int(b["stage"])})
					sd.call("on_stage_result", int(b["stage"]), {"result": "win"})
					sd.call("hide_result")
				else:
					sd.call("complete_step", id)
			"mission", "fight", "lair":
				var fl: Dictionary = sd.get("flags")
				for k: Variant in (b.get("flag_by_info", {}) as Dictionary).keys():
					if sides:
						fl[String(b["flag_by_info"][k])] = true
				if StoryRank.is_ranked(id):
					sd.call("record_rank", id, StoryRank.report(id, {"time": 60.0, "dmg": 50.0, "fails": 1}))
				sd.call("complete_step", id)
			_:
				sd.call("complete_step", id)
		if String(sd.get("ending")) == "":
			_check(String(sd.get("step")) != id, "%s: %s (%s) moved the story on" % [tag, id, kind])
			if String(sd.get("step")) == id:
				break
			var saved: Dictionary = sd.call("read_save", TMP)
			_check(String(saved.get("step", "")) == String(sd.get("step")), "%s: autosave after %s (saved %s, now %s)" % [tag, id, String(saved.get("step", "")), String(sd.get("step"))])
	_check(String(sd.get("ending")) == want, "%s: ending %s (got '%s' after %d beats, at %s)" % [tag, want, String(sd.get("ending")), n, String(sd.get("step"))])
	var want_days: Array = [1, 2, 3, 4, 5] if want == "C" else [1, 2, 3, 4, 5, 6, 7]
	_check(str(days) == str(want_days), "%s: the days in order %s (got %s)" % [tag, str(want_days), str(days)])
	var got_ev: Array = (sd.get("evidence") as Array).duplicate()
	got_ev.sort()
	var want_ev: Array = ev.duplicate()
	want_ev.sort()
	_check(got_ev == want_ev, "%s: evidence %s (got %s)" % [tag, str(want_ev), str(got_ev)])
	var uniq: Dictionary = {}
	for s: String in visited:
		_check(not uniq.has(s), "%s: beat %s entered once" % [tag, s])
		uniq[s] = true
	if beats_n >= 0:
		var chain: int = 0
		for k2: Variant in StoryMissions.BEATS.keys():
			if not String(StoryMissions.BEATS[k2].get("kind", "")) in ["locked"] and String(k2) != "d5_end_c":
				chain += 1
		_check(uniq.size() == beats_n and uniq.size() == chain, "%s: %d beats visited (want %d, the chain has %d)" % [tag, uniq.size(), beats_n, chain])
	_check(round_trip or want == "C", "%s: the Continue round trip ran on Day 4" % tag)
	# the finished save: marked, Continue refuses it
	var fin: Dictionary = sd.call("read_save", TMP)
	_check(String((fin.get("flags", {}) as Dictionary).get("ending", "")) == want and not bool(sd.get("active")), "%s: the save is marked finished (%s)" % [tag, str((fin.get("flags", {}) as Dictionary).get("ending", ""))])
	var sd2: Node = _director()
	_check(not bool(sd2.call("continue_story")) and not bool(sd2.get("active")), "%s: Continue refuses the finished story" % tag)
	sd2.queue_free()
	sd.queue_free()


## Day 4's first beat: a fresh director loads the autosave into the same state and Continue enters free roam.
func _continue_round_trip(sd: Node, tag: String) -> void:
	var sd2: Node = _director()
	_check(bool(sd2.call("continue_story")) and String(sd2.get("last_nav")) == "roam", "%s: Continue on Day 4 loads and enters roam" % tag)
	var a: Dictionary = sd.call("to_dict")
	var b: Dictionary = sd2.call("to_dict")
	_check(var_to_str(a) == var_to_str(b), "%s: the Day 4 save round trip keeps the state (step %s / %s)" % [tag, String(a.get("step", "")), String(b.get("step", ""))])
	sd2.queue_free()
