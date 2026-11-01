# File: res://tests/test_story_endings.gd
# Headless test of the endings (plan 2026-11-01-w4-endings.md T1-T3):
#   A. data: evaluate_ending through StoryDirector.ending_state (bribe, study_ranks in flags), StoryEndings.slots, every
#      ending timeline validates at <= 30 s with a joke beat, Vietnamese lines without emoji, beat sheets in sync;
#   B. the hand-off: a fake save at d7_ending for each of A, B, D, E, F in story free roam plays its slots in order (A and F:
#      end_a, the ai_true_end fallback, F then end_f), then the end summary (choices, E1-E7 with the missing ones marked,
#      ranks), then the save is finished with that letter, the main menu; Continue refuses it; the ending is in the unlock
#      file and the gallery;
#   C. a broken owner clip for ai_true_end falls back to the in-engine timeline;
#   D. ending C on Day 5 (d5_end_c) still plays end_c and finishes "C";
#   E. the KẾT THÚC tab of CHỌN CẢNH: a reached ending is a row ("Kết A: ..."), the others "???"; picking A replays end_a
#      then ai_true_end in StoryGalleryPlayer and comes back to the KẾT THÚC tab, the story save untouched.
# Run:  godot --headless --path . --script tests/test_story_endings.gd
extends SceneTree

var TMP: String = "user://test_story_endings_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_story_endings_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_story_endings_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_story_endings_backup_%d.cfg" % OS.get_process_id()
var TMP_U2: String = "user://test_story_endings_unlocks2_%d.cfg" % OS.get_process_id()
var VID: String = "user://test_story_endings_video_%d/" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const ALLOWED_SYMBOLS: Array[int] = [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026]
const ALL7: Array[String] = ["E1", "E2", "E3", "E4", "E5", "E6", "E7"]
## letter -> [evidence, choices, study_ranks]
var CASES: Dictionary = {
	"A": [ALL7, {"phuc": "cover", "zaman_offer": "refuse", "bribe": "refuse"}, {}],
	"B": [["E1", "E2", "E6", "E7", "E3"], {"phuc": "report", "zaman_offer": "refuse", "bribe": "refuse"}, {}],
	"D": [ALL7, {"phuc": "cover", "zaman_offer": "refuse", "bribe": "take"}, {"3": "S", "6": "S", "7": "S"}],
	"E": [["E1", "E6", "E7"], {"phuc": "cover", "zaman_offer": "refuse", "bribe": "refuse"}, {}],
	"F": [ALL7, {"phuc": "cover", "zaman_offer": "refuse", "bribe": "refuse"}, {"3": "S", "6": "S", "7": "S"}],
}
const ORDER: Array[String] = ["A", "B", "D", "E", "F"]
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var case_i: int = 0
var slot_i: int = 0
var letter: String = ""
var cs: ChapterSelect
var gp: StoryGalleryPlayer
var save_bytes: PackedByteArray


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY ENDINGS (d7_ending auto: A, B, D, E, F; summary; gallery; ending C) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	# the study ranks also come from StageManager.best_stats (StoryDirector.study_ranks): start from none, in memory only
	# (headless never writes the real progress.cfg), so the owner's own records cannot turn A into F here
	sm.set("best_stats", {})
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	StoryVideo.video_dir = VID
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)


func _clean(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c >= 0x2000 and not (c in ALLOWED_SYMBOLS):
			return false
	return true


func _part_a() -> void:
	sd.call("reset_state")   # beat sheets first, with no protagonist (the default name, as tools/cine_beats.gd writes them)
	for s0: String in StoryEndings.all_slots():
		var tl0: CineTimeline = CineTimeline.load_slot(s0)
		var sheet: String = FileAccess.get_file_as_string("res://docs/cinematics/%s.txt" % s0).replace("\r\n", "\n")
		_check(tl0 != null and sheet == tl0.beat_sheet(), "%s beat sheet in sync (run tools/cine_beats.gd)" % s0)
	# evaluate through the director's own state (bribe, study ranks from flags)
	for x: String in ORDER:
		_set_state(x)
		var got: String = String(sd.call("resolve_ending", StoryMissions.beat("d7_ending")))
		_check(got == x, "state of %s evaluates to %s" % [x, got])
	_check(StoryEndings.slots("A") == ["end_a", "ai_true_end"] and StoryEndings.slots("F") == ["end_a", "ai_true_end", "end_f"]
		and StoryEndings.slots("C") == ["end_c"], "ending sequences")
	var b: Dictionary = StoryMissions.beat("d7_ending")
	_check(String(b.get("kind", "")) == "cine" and String(b.get("ending", "")) == "auto" and String(b.get("next", "x")) == ""
		and int(b.get("day", 0)) == 7, "d7_ending: an auto ending cine beat on Day 7")
	_check(StoryChapters.is_replayable("d7_ending"), "d7_ending is a chapter (Chọn cảnh can rewind to it)")
	for s: String in StoryEndings.all_slots():
		var tl: CineTimeline = CineTimeline.load_slot(s)
		_check(tl != null, "%s timeline exists" % s)
		if tl == null:
			continue
		var errs: PackedStringArray = tl.validate()
		_check(errs.is_empty(), "%s validates: %s" % [s, str(errs)])
		_check(tl.length <= 30.0 + 1e-6, "%s is at most 30 s (%.1f)" % [s, tl.length])
		_check(not tl.jokes.is_empty(), "%s has a joke beat" % s)
		_check(tl.music_slot == s, "%s music slot is its own" % s)
		for sb: Dictionary in tl.subs:
			_check(_clean(String(sb["text"])) and _clean(String(sb["tr"])), "%s: no emoji in '%s'" % [s, String(sb["text"])])
		for cd: Dictionary in tl.cards:
			for l: Variant in (cd["data"] as Dictionary).get("lines", []):
				_check(_clean(String(l)), "%s credits: no emoji in '%s'" % [s, String(l)])
	_check(CineAudio.SLOT_FALLBACK.get("ai_true_end", "") == "end_a", "ai_true_end falls back to end_a's song")
	# the summary rows
	var sum: Dictionary = StoryEndings.summary("E", {"evidence": ["E1", "E6"], "choices": {"phuc": "report", "zaman_offer": "refuse", "bribe": ""}},
		{"d1_brawl": "S"})
	var ev: Array = sum["evidence"]
	_check(ev.size() == 7 and bool(ev[0][2]) and not bool(ev[1][2]) and int(sum["found"]) == 2, "summary evidence: 7 rows, 2 found")
	_check(String(sum["choices"][0][1]) == "Báo Phúc cho Mr.T" and String(sum["choices"][2][1]) == StoryEndings.NOT_ASKED, "summary choices")
	var rk: Array = (sum["ranks"] as Array).filter(func(r: Array) -> bool: return String(r[0]).contains("Ba shipper"))
	_check(rk.size() == 1 and String(rk[0][1]) == "S", "summary ranks: Day 1 brawl S")
	var card := StoryEndSummary.new()
	root.add_child(card)
	card.show_for("E", {"evidence": ["E1", "E6"], "choices": {}}, {})
	var miss: Label = card.find_child("Ev_E3", true, false) as Label
	_check(miss != null and miss.text == "E3 · " + StoryEndings.MISSING_LINE, "summary: a missing piece reads Chưa tìm thấy")
	for t: String in card.texts():
		_check(_clean(t), "summary text without emoji: %s" % t)
	var closed: Array = [0]
	card.closed.connect(func() -> void: closed[0] += 1)
	card.confirm()
	card.confirm()
	_check(int(closed[0]) == 1 and not card.is_open, "summary closes once")
	card.queue_free()


func _set_state(x: String) -> void:
	var c: Array = CASES[x]
	sd.call("reset_state")
	sd.call("new_story", {"female": x == "B", "name": "Minh", "variant": 0, "hair_style": "short", "hair_color": 2, "skin": 2})
	sd.set("day", 7)
	var ev: Array[String] = []
	for e: String in c[0]:
		ev.append(e)
	sd.set("evidence", ev)
	sd.set("choices", (c[1] as Dictionary).duplicate())
	(sd.get("flags") as Dictionary)["study_ranks"] = (c[2] as Dictionary).duplicate()
	sd.set("ranks", {"d1_brawl": "A", "d5_duel": "S"})


func _start_case() -> void:
	letter = ORDER[case_i]
	slot_i = 0
	_set_state(letter)
	sd.set("step", "")
	sd.call("_enter", "d7_ending")
	sd.call("save_game")
	# the auto ending beat warms the cues of every slot of the resolved ending, not only its own "slot" (end_a)
	var cues: Array = StoryRoam.beat_cues(sd.call("beat"), sd)
	var missing: Array[String] = []
	for slot: String in StoryEndings.slots(letter):
		var tl: CineTimeline = CineTimeline.load_slot(slot)
		if tl:
			for e: Dictionary in tl.sfx:
				if StoryAudio.is_cue(String(e["cue"])) and not cues.has(String(e["cue"])):
					missing.append("%s:%s" % [slot, String(e["cue"])])
	_check(missing.is_empty(), "%s: beat_cues warms every slot's cues (missing %s)" % [letter, str(missing)])


func _roam() -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	root.add_child(fr)
	current_scene = fr   # as in play (StageManager._can_pause reads the current scene's meta no_pause)
	sr = fr.get("story_roam")
	if sr:
		sr.cine_opts = {"manual": true, "music": false}


func _finish_cine() -> String:
	var cp: CinePlayer = fr.get("cine_player")
	if cp == null:
		return ""
	var slot: String = cp.timeline.slot
	var n: int = 0
	while fr.get("cine_player") != null and n < 6000:
		cp.step(DT)
		n += 1
	_check(fr.get("cine_player") == null, "%s finished" % slot)
	return slot


func _next(p: int) -> void:
	phase = p
	frames = 0


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 40000:
		_check(false, "timeout in phase %d (case %s)" % [phase, letter])
		return _end()
	match phase:
		0:
			_part_a()
			_start_case()
			_roam()
			_check(sr != null, "the story layer runs in free roam")
			if sr == null:
				return _end()
			_next(1)
		1:
			# the next slot of the current ending plays
			var want: Array[String] = StoryEndings.slots(letter)
			if fr.get("cine_player") == null:
				if frames > 300:
					_check(false, "%s: slot %s did not start" % [letter, want[slot_i]])
					return _end()
				return false
			var cp: CinePlayer = fr.get("cine_player")
			_check(cp.timeline.slot == want[slot_i], "%s: plays %s (got %s)" % [letter, want[slot_i], cp.timeline.slot])
			_check(sr.ending_runner != null and sr.busy, "%s: the ending runner holds the story" % letter)
			_finish_cine()
			slot_i += 1
			_next(2 if slot_i >= want.size() else 1)
		2:
			var r: StoryEndingRunner = sr.ending_runner
			if r == null or r.summary == null:
				if frames > 120:
					_check(false, "%s: no end summary" % letter)
					return _end()
				return false
			_check(r.played == StoryEndings.slots(letter), "%s: played %s" % [letter, str(r.played)])
			_check(paused, "%s: the world is paused under the summary" % letter)
			_check(String(r.summary.data.get("ending", "")) == letter and int(r.summary.data.get("found", -1)) == (CASES[letter][0] as Array).size(),
				"%s: summary shows the ending and the evidence count" % letter)
			_check(String(sd.get("ending")) == "", "%s: not finished before the summary closes" % letter)
			_check(fr.has_meta("no_pause") and not bool(sm.call("_can_pause")), "%s: no pause menu over the summary (Esc closes it)" % letter)
			r.summary.confirm()
			_check(not fr.has_meta("no_pause"), "%s: no_pause lifted when the summary closes" % letter)
			_next(3)
		3:
			if frames < 2:
				return false
			_check(String(sd.get("ending")) == letter and not bool(sd.get("active")) and String(sd.get("last_nav")) == "menu",
				"%s: the story ends on %s, the main menu" % [letter, letter])
			_check(not paused, "%s: unpaused after the summary" % letter)
			var sv: Dictionary = sd.call("read_save", TMP)
			_check(String(sv.get("ending", "")) == letter, "%s: the save is marked finished" % letter)
			sd.call("reset_state")
			_check(not bool(sd.call("continue_story")), "%s: Continue refuses the finished story" % letter)
			_check(letter in StoryChapters.reached_endings(), "%s: recorded in the ending gallery" % letter)
			for s: String in StoryEndings.slots(letter):
				_check(StoryChapters.is_cine_unlocked(s), "%s: %s unlocked in XEM LẠI PHIM" % [letter, s])
			_check(sr.ending_runner == null and not sr.busy, "%s: the runner is gone" % letter)
			case_i += 1
			if case_i < ORDER.size():
				_start_case()
				_next(1)
			else:
				_next(10)
		10:
			# C. a broken owner clip for ai_true_end: the fallback timeline plays instead
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VID))
			var f: FileAccess = FileAccess.open(VID + "ai_true_end_m.ogv", FileAccess.WRITE)
			f.store_string("not a video")
			f.close()
			case_i = 0
			_start_case()   # A, male
			_next(11)
		11:
			if fr.get("cine_player") == null:
				if frames > 300:
					_check(false, "C: end_a did not start")
					return _end()
				return false
			_check(_finish_cine() == "end_a", "C: end_a first")
			_next(12)
		12:
			if fr.get("cine_player") == null:
				if frames > 300:
					_check(false, "C: the ai_true_end fallback did not start")
					return _end()
				return false
			_check(_finish_cine() == "ai_true_end", "C: a broken clip falls back to the ai_true_end timeline")
			_next(13)
		13:
			var r2: StoryEndingRunner = sr.ending_runner
			if r2 == null or r2.summary == null:
				if frames > 120:
					_check(false, "C: no summary")
					return _end()
				return false
			r2.summary.confirm()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(VID + "ai_true_end_m.ogv"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(VID))
			_next(20)
		20:
			if frames < 3:
				return false
			# D. ending C on Day 5 is unchanged
			sd.call("reset_state")
			sd.call("new_story", {"female": true, "name": "Lan", "variant": 1, "hair_style": "bob", "hair_color": 1, "skin": 1})
			sd.set("day", 5)
			(sd.get("choices") as Dictionary)["zaman_offer"] = "accept"
			sd.set("step", "")
			sd.call("_enter", "d5_end_c")
			_next(21)
		21:
			if fr.get("cine_player") == null:
				if frames > 300:
					_check(false, "D: end_c did not start")
					return _end()
				return false
			_check(sr.ending_runner == null, "D: ending C does not use the auto runner")
			_check(_finish_cine() == "end_c", "D: end_c plays")
			_next(22)
		22:
			if frames < 3:
				return false
			_check(String(sd.get("ending")) == "C" and not bool(sd.get("active")) and String(sd.get("last_nav")) == "menu", "D: ending C finishes")
			_check("C" in StoryChapters.reached_endings(), "D: ending C recorded in the gallery")
			sd.call("reset_state")
			_check(not bool(sd.call("continue_story")), "D: Continue refuses ending C")
			fr.queue_free()
			fr = null
			_next(30)
		30:
			if frames < 3:
				return false
			paused = false
			StoryChapters.unlocks_path = TMP_U2   # a fresh unlock file: only ending A reached
			StoryChapters.record_ending("A")
			cs = (load(ChapterSelect.SCENE) as PackedScene).instantiate()
			cs.nav_enabled = false
			root.add_child(cs)
			_next(31)
		31:
			if frames < 3:
				return false
			_gallery_tab()
			save_bytes = FileAccess.get_file_as_bytes(TMP)
			gp = (load(ChapterSelect.GALLERY_SCENE) as PackedScene).instantiate()
			gp.nav_enabled = false
			gp.cine_opts = {"manual": true, "music": false}
			root.add_child(gp)
			_next(32)
		32:
			if gp.player != null:
				var p: CinePlayer = gp.player
				var n: int = 0
				while gp.player != null and n < 3000:
					p.step(DT)
					n += 1
				return false
			if gp.last_nav != "chapters":
				if frames > 900:
					_check(false, "E: the ending sequence did not finish (%s)" % str(gp.played))
					return _end()
				return false
			_check(gp.played == (["end_a", "ai_true_end"] as Array[String]), "E: ending A replays end_a then ai_true_end (%s)" % str(gp.played))
			_check(ChapterSelect.open_tab == "endings" and StoryGalleryPlayer.queue.is_empty() and StoryGalleryPlayer.return_tab == "gallery",
				"E: back to the KẾT THÚC tab (%s)" % ChapterSelect.open_tab)
			_check(FileAccess.get_file_as_bytes(TMP) == save_bytes, "E: the story save is untouched")
			gp.queue_free()
			gp = null
			cs = (load(ChapterSelect.SCENE) as PackedScene).instantiate()
			cs.nav_enabled = false
			root.add_child(cs)
			_next(33)
		33:
			if frames < 3:
				return false
			_check(cs.tab == "endings" and cs.row_button("A") != null, "E: the screen reopens on the KẾT THÚC tab")
			cs.queue_free()
			cs = null
			return _end()
	return false


## E: the KẾT THÚC rows with only A reached, then A picked.
func _gallery_tab() -> void:
	_check(cs.tab_buttons.has("endings") and (cs.tab_buttons["endings"] as Button).text == "KẾT THÚC", "E: the KẾT THÚC tab")
	cs.show_tab("endings")
	_check(cs.tab == "endings" and cs.list_box.get_child_count() == StoryEndings.IDS.size(), "E: one row per ending (%d)" % cs.list_box.get_child_count())
	var a: Button = cs.row_button("A")
	_check(a != null and not a.disabled and a.text == StoryEndings.title("A") and a.text.count("Kết A") == 1 and _clean(a.text), "E: ending A reached (%s)" % (a.text if a else "none"))
	for x: String in ["B", "C", "D", "E", "F"]:
		var b: Button = cs.row_button(x)
		_check(b != null and b.disabled and b.text == "???", "E: ending %s not reached reads ???" % x)
	_check(not cs.empty_label.visible, "E: no empty line with an ending reached")
	if a == null:
		return
	a.pressed.emit()
	_check(cs.last_nav == "ending:A" and StoryGalleryPlayer.slot == "end_a" and StoryGalleryPlayer.queue == (["ai_true_end"] as Array[String])
		and ChapterSelect.open_tab == "endings", "E: picking A queues its sequence (%s %s)" % [StoryGalleryPlayer.slot, str(StoryGalleryPlayer.queue)])
	cs.queue_free()
	cs = null


func _end() -> bool:
	for p: String in [TMP, TMP_U, TMP_C, TMP_B, TMP_U2]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
	paused = false
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY ENDINGS (A, B, D, E, F from d7_ending; summary; gallery records; clip fallback; ending C; KẾT THÚC gallery)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
