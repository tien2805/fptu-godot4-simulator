# File: res://tests/test_story_director.gd
# Headless test of the StoryDirector autoload (spec A2-D1, A2-D2, A2-D3, A2-D16): state and signals, {name}
# substitution, the Day-0 beat chain of StoryMissions (every next exists, Day 0 reaches Day 1 and its locked placeholder,
# placeholders 1-7 without markers), autosaves, save / load round trip on a temp file, the version guard (missing,
# garbage, newer version = no save), protagonist opts, day chip text and the evaluate_ending truth table (story spec 6).
# Run:  godot --headless --path . --script tests/test_story_director.gd
extends SceneTree

const TMP: String = "user://test_story_director_save.cfg"
var fails: Array[String] = []
var sd: Node
var counts: Dictionary = {"day": 0, "evidence": 0, "objective": 0, "text": 0, "step": 0}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DIRECTOR ---")
	sd = (load("res://scripts/story/StoryDirector.gd") as Script).new()
	sd.name = "StoryDirectorTest"
	root.add_child(sd)
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	sd.connect("day_changed", func(_d: int) -> void: counts["day"] += 1)
	sd.connect("evidence_added", func(_e: String) -> void: counts["evidence"] += 1)
	sd.connect("objective_changed", func(_t: String) -> void: counts["objective"] += 1)
	sd.connect("text_received", func(_m: Dictionary) -> void: counts["text"] += 1)
	sd.connect("step_changed", func(_s: String) -> void: counts["step"] += 1)
	_registry()
	_state()
	_save_load()
	_guard()
	_endings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("✅ SUCCESS: STORY DIRECTOR (state, signals, Day-0 chain, save/load, version guard, endings)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _registry() -> void:
	var ids: PackedStringArray = StoryMissions.all_ids()
	for id: String in ids:
		var b: Dictionary = StoryMissions.beat(id)
		_check(not b.is_empty() and String(b["kind"]) in StoryMissions.KINDS, "beat %s has a known kind" % id)
		var nx: String = String(b.get("next", ""))
		_check(nx == "" or not StoryMissions.beat(nx).is_empty(), "beat %s: next %s exists" % [id, nx])
		if String(b["kind"]) == "stage":
			_check(b.has("stage") and b.has("anchor") and b.has("return") and b.has("replay"), "stage beat %s has stage, anchor, return, replay" % id)
		if String(b["kind"]) in ["cine", "video"]:
			_check(b.has("slot") and b.has("at"), "cinematic beat %s has slot + at" % id)
	var chain: Array[String] = []
	var cur: String = StoryMissions.first_beat()
	while cur != "" and chain.size() < 40:
		chain.append(cur)
		cur = String(StoryMissions.beat(cur).get("next", ""))
	var want: Array[String] = ["d0_wake", "d0_race", "d0_exam", "d0_exam_end", "d0_bed", "d0_midnight", "d0_call", "d0_intro", "d1_start", "d1_locked"]
	_check(chain == want, "Day-0 chain is %s (got %s)" % [str(want), str(chain)])
	_check(int(StoryMissions.beat("d0_race")["stage"]) == 1 and int(StoryMissions.beat("d0_exam")["stage"]) == 7, "race = Stage 1, exam = Extra (7)")
	_check(String(StoryMissions.beat("d0_exam").get("evidence", "")) == "E1", "the exam win grants E1")
	_check(int(StoryMissions.beat("d0_call")["days"]) == 7, "the 3 a.m. call after Day 0 says 7")
	for n: int in range(1, 8):
		var p: Dictionary = StoryMissions.beat("d%d_locked" % n)
		_check(String(p.get("kind", "")) == "locked" and not p.has("anchor"), "Day %d placeholder is locked without a marker" % n)
		_check(String(p.get("objective", "")) == "Ngày %d: %s – sắp có trong bản cập nhật sau" % [n, StoryMissions.DAY_TITLES[n]], "Day %d objective text" % n)
	_check(StoryMissions.beat("d8_locked").is_empty() and StoryMissions.beat("nope").is_empty(), "unknown beats are empty")
	var tods: Dictionary = {"d0_wake": "morning", "d0_race": "morning", "d0_exam_end": "morning", "d0_bed": "sunset", "d0_midnight": "night", "d1_start": "morning"}
	for k: String in tods.keys():
		_check(String(StoryMissions.beat(k)["tod"]) == String(tods[k]), "A2-D13: %s at %s" % [k, String(tods[k])])


func _state() -> void:
	_check(not bool(sd.get("active")), "inactive before a story starts")
	_check(String(sd.call("display_name")) == "Bạn" and String(sd.call("fmt", "Chào {name}!")) == "Chào Bạn!", "default name Bạn")
	var p0: Dictionary = sd.call("protagonist_opts")
	_check(String(p0["preset"]) == "player" and bool(p0["rigged"]) and not p0.has("female"), "default opts = the roam player")
	sd.call("new_story", {"female": true, "name": "  Hoa Mai  ", "variant": 2, "hair_style": "ponytail", "hair_color": 3, "skin": 1})
	_check(bool(sd.get("active")) and String(sd.get("step")) == "d0_wake" and int(sd.get("day")) == 0, "new story at d0_wake, Day 0")
	_check(String(sd.call("display_name")) == "Hoa Mai", "name trimmed")
	_check(int(sd.get("saves")) == 1 and FileAccess.file_exists(TMP), "autosave on creator confirm")
	var po: Dictionary = sd.call("protagonist_opts")
	_check(bool(po["female"]) and int(po["variant"]) == 2 and String(po["hair_style"]) == "ponytail" and int(po["hair_color"]) == 3
		and int(po["skin"]) == 1 and String(po["preset"]) == "player" and bool(po["backpack"]), "protagonist opts carry the creator picks")
	_check(String(sd.call("day_chip_text")) == "NGÀY 0 · THI EOS", "Day 0 chip")
	_check(String(sd.get("objective")).contains("Hoa Mai"), "objective substitutes {name}: %s" % String(sd.get("objective")))
	var c0: Dictionary = counts.duplicate()
	_check(not bool(sd.call("complete_step", "d0_race")), "completing a beat that is not current is ignored")
	_check(bool(sd.call("complete_step", "d0_wake")), "complete d0_wake")
	_check(String(sd.get("step")) == "d0_race" and counts["step"] == c0["step"] + 1 and counts["text"] == c0["text"] + 1, "d0_race entered once, Phúc's text received")
	var texts: Array = sd.get("texts")
	_check(texts.size() == 1 and String(texts[0]["from"]) == "Phúc" and int(sd.call("unread_count")) == 1, "one unread text from Phúc")
	sd.call("mark_read", "Phúc")
	_check(int(sd.call("unread_count")) == 0, "mark_read clears unread")
	sd.call("complete_step", "d0_race")
	sd.call("complete_step", "d0_exam")
	_check(sd.call("has_evidence", "E1") and counts["evidence"] == c0["evidence"] + 1, "E1 granted once by the exam win")
	sd.call("add_evidence", "E1")
	sd.call("add_evidence", "E9")
	_check((sd.get("evidence") as Array).size() == 1, "evidence has no duplicates or unknown ids")
	var mr: Array = (sd.get("texts") as Array).filter(func(m: Dictionary) -> bool: return String(m["from"]) == "Mr.T")
	_check(mr.size() == 1 and String(mr[0]["text"]).contains("Hoa Mai ơi") and String(mr[0]["text"]).contains(" em "), "Mr.T's text uses {name} and em")
	for id: String in ["d0_exam_end", "d0_bed", "d0_midnight", "d0_call"]:
		sd.call("complete_step", id)
	_check(String(sd.get("tod")) == "morning" and String(sd.get("step")) == "d0_intro", "after the call: d0_intro in the morning")
	var day0: int = counts["day"]
	sd.call("complete_step", "d0_intro")
	_check(int(sd.get("day")) == 1 and counts["day"] == day0 + 1 and String(sd.get("step")) == "d1_locked", "d0_intro -> Day 1 -> d1_locked")
	_check(String(sd.call("day_chip_text")) == "NGÀY 1 · CÒN 7 NGÀY" and int(sd.call("days_left")) == 7, "Day 1 chip: CÒN 7 NGÀY")
	_check(String(sd.get("objective")) == "Ngày 1: Shipper bóng đêm – sắp có trong bản cập nhật sau", "Day 1 locked objective")
	_check(String(sd.get("tod")) == "morning", "Day 1 morning")
	var d1: Array = (sd.get("texts") as Array).filter(func(m: Dictionary) -> bool: return String(m["text"]) == "Thầy tin em. Tìm bằng chứng đi.")
	_check(d1.size() == 1 and int(d1[0]["day"]) == 1, "the Day-1 text is stamped Day 1, not Day 0")


func _save_load() -> void:
	sd.set("spawn", Transform3D(Basis(Vector3.UP, 0.7), Vector3(12.5, 0.0, -40.25)))
	sd.call("save_game")
	var before: Dictionary = sd.call("to_dict")
	var sd2: Node = (load("res://scripts/story/StoryDirector.gd") as Script).new()
	sd2.set("save_path", TMP)
	_check(bool(sd2.call("load_game")), "load_game reads the temp save")
	var after: Dictionary = sd2.call("to_dict")
	_check(var_to_str(after) == var_to_str(before), "save -> load round trip keeps the state")
	_check(sd2.get("spawn") is Transform3D and (sd2.get("spawn") as Transform3D).origin.is_equal_approx(Vector3(12.5, 0.0, -40.25)), "spawn survives the save")
	_check(bool(sd2.get("active")) and int(sd2.get("day")) == 1, "loaded story is active on Day 1")
	sd2.free()
	_check(String(sd.call("fmt", "{name}")) == "Hoa Mai", "fmt after save")


func _guard() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("story", "version", 2)
	cfg.set_value("story", "data", var_to_str({"step": "d0_wake"}))
	cfg.save(TMP)
	_check(sd.call("read_save", TMP).is_empty(), "a newer version is refused")
	cfg = ConfigFile.new()
	cfg.set_value("story", "version", 1)
	cfg.set_value("story", "data", "Vector3(1, 2")
	cfg.save(TMP)
	_check(sd.call("read_save", TMP).is_empty(), "unreadable data is refused")
	cfg = ConfigFile.new()
	cfg.set_value("story", "version", 1)
	cfg.set_value("story", "data", var_to_str({"step": "no_such_beat"}))
	cfg.save(TMP)
	_check(sd.call("read_save", TMP).is_empty(), "an unknown step is refused")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	_check(sd.call("read_save", TMP).is_empty() and not bool(sd.call("has_save")), "a missing file = no save")
	var sd3: Node = (load("res://scripts/story/StoryDirector.gd") as Script).new()
	sd3.call("from_dict", {"step": "d0_wake", "evidence": ["E1", "E1", "E9", "E7"]})
	_check(Array(sd3.get("evidence")) == ["E1", "E7"], "from_dict filters unknown and duplicate evidence")
	sd3.free()
	_check(sd.call("read_save", "user://story_save.cfg") is Dictionary, "default path readable without crashing")


func _endings() -> void:
	var all7: Array = ["E1", "E2", "E3", "E4", "E5", "E6", "E7"]
	var ok: Dictionary = {"phuc": "cover", "zaman_offer": "refuse", "bribe": "refuse"}
	var s_ranks: Dictionary = {3: "S", 6: "S", 7: "S"}
	var cases: Array = [
		[{"evidence": all7, "choices": {"phuc": "cover", "zaman_offer": "accept", "bribe": "refuse"}}, "C"],
		[{"evidence": ["E1"], "choices": {"phuc": "report", "zaman_offer": "accept", "bribe": "take"}}, "C"],
		[{"evidence": ["E1", "E6", "E7"], "choices": ok}, "E"],
		[{"evidence": ["E1", "E6", "E7"], "choices": {"phuc": "report", "zaman_offer": "refuse", "bribe": "take"}}, "E"],
		[{"evidence": all7, "choices": {"phuc": "report", "zaman_offer": "refuse", "bribe": "refuse"}}, "B"],
		[{"evidence": ["E1", "E2", "E6", "E7"], "choices": {"phuc": "report", "zaman_offer": "refuse", "bribe": "take"}}, "B"],
		[{"evidence": ["E1", "E2", "E6", "E7"], "choices": ok}, "D"],
		[{"evidence": ["E1", "E2", "E3", "E5", "E6", "E7"], "choices": ok}, "D"],
		[{"evidence": all7, "choices": {"phuc": "cover", "zaman_offer": "refuse", "bribe": "take"}}, "D"],
		[{"evidence": all7, "choices": ok}, "A"],
		[{"evidence": all7, "choices": ok, "study_ranks": {3: "S", 6: "A", 7: "S"}}, "A"],
		[{"evidence": all7, "choices": ok, "study_ranks": s_ranks}, "F"],
		[{"evidence": all7, "choices": ok, "study_ranks": {"3": "S", "6": "S", "7": "S"}}, "F"],
		[{"evidence": all7, "choices": {"phuc": "cover", "zaman_offer": "refuse", "bribe": "take"}, "study_ranks": s_ranks}, "D"],
	]
	for c: Array in cases:
		var got: String = sd.call("evaluate_ending", c[0])
		_check(got == String(c[1]), "ending %s expected for %s, got %s" % [String(c[1]), str(c[0]), got])
