# File: res://tests/test_chapter_select.gd
# Headless test of the chapter select "CHỌN CẢNH" and the gallery "XEM LẠI PHIM" (plan 2026-10-26-chapter-select.md):
# unlocks recorded on beat entry that never shrink (rewind, new story), snapshots of the state at the start of each
# replayable beat (none for day / bed / call beats, latest wins), the main menu button only with unlocks (the menu still
# fits 1280x720), a rewind through the screen (confirm text, the backup, the save replaced, Continue lands on the beat:
# its marker, its day and time of day; a cinematic beat plays), the restore of the backup, the gallery rows and a playback
# that returns to the gallery without touching the save, old-save seeding (best-effort snapshots, "???" and "Chơi tới cảnh
# này một lần để mở" rows), the pause-menu entry in story mode only, and no emoji in the new texts.
# Phase C: the new beat kinds are replayable (the Day 2 / 3 missions and fight, the Day 5 lair tasks and basement
# cinematics), snapshotted on entry with the best-effort rebuild keeping the E4 flag, and the gallery lists the Phase C
# cinematics by day.
# Every file is a temp file (StoryDirector.save_path, StoryChapters paths): the owner's user:// files are never touched.
# Run:  godot --headless --path . --script tests/test_chapter_select.gd
extends SceneTree

const TMP_SAVE: String = "user://test_chapter_select_save.cfg"
const TMP_U: String = "user://test_chapter_select_unlocks.cfg"
const TMP_C: String = "user://test_chapter_select_chapters.cfg"
const TMP_B: String = "user://test_chapter_select_backup.cfg"
const VID: String = "user://test_chapter_select_video/"
const DT: float = 1.0 / 60.0
const P: Dictionary = {"female": true, "name": "Lan", "variant": 1, "hair_style": "bob", "hair_color": 1, "skin": 2}
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var menu: Node
var cs: ChapterSelect
var fr: Node
var gp: StoryGalleryPlayer
var save_bytes: PackedByteArray
var dir_before: String = ""


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _rm(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _initialize() -> void:
	print("--- TEST CHAPTER SELECT ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP_SAVE)
	sd.set("nav_enabled", false)
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	StoryVideo.video_dir = VID
	for p: String in [TMP_SAVE, TMP_U, TMP_C, TMP_B]:
		_rm(p)


func _next(p: int) -> void:
	phase = p
	frames = 0


func _walk_to(id: String) -> void:
	var n: int = 0
	while String(sd.get("step")) != id and n < 80:
		sd.call("complete_step", String(sd.get("step")))
		n += 1


func _snap(id: String) -> Dictionary:
	return StoryChapters.snapshot(id)


func _open_cs() -> void:
	cs = (load(ChapterSelect.SCENE) as PackedScene).instantiate()
	cs.nav_enabled = false
	root.add_child(cs)


func _free_cs() -> void:
	if cs:
		cs.queue_free()
		cs = null


func _roam(manual: bool = true) -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	root.add_child(fr)
	var sr: StoryRoam = fr.get("story_roam")
	if sr and manual:
		sr.cine_opts = {"manual": true, "music": false}
		sr.call_opts = {"manual": true}
		sr.mission_opts = {"manual": true, "manual_replay": true, "seed": 7}


static func _clean(s: String) -> bool:
	for i: int in s.length():
		if s.unicode_at(i) >= 0x2190:   # arrows, symbols, dingbats, emoji (Vietnamese letters, "·", "–", "…" are below)
			return false
	return true


## Every Label / Button text under `n` free of emoji and decorative symbols.
func _texts_clean(n: Node, where: String) -> void:
	for c: Node in n.find_children("*", "", true, false):
		var t: String = ""
		if c is Label:
			t = (c as Label).text
		elif c is Button:
			t = (c as Button).text
		if t != "":
			_check(_clean(t), "%s: no emoji / symbol in '%s'" % [where, t])


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 20000:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	match phase:
		0:
			_check(not StoryChapters.has_unlocks(), "no unlocks at the start")
			menu = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
			root.add_child(menu)
			_next(1)
		1:
			if frames < 5:
				return false
			_check(not (menu.get("btn_chapters") as Button).visible, "main menu: CHỌN CẢNH hidden without unlocks")
			_story_walk()
			menu.call("_refresh_story_buttons")
			_check((menu.get("btn_chapters") as Button).visible, "main menu: CHỌN CẢNH shown once a chapter is unlocked")
			_check((menu.get("btn_continue") as Button).visible, "main menu: TIẾP TỤC shown with the save")
			_next(2)
		2:
			if frames < 4:
				return false
			var vp: Rect2 = root.get_visible_rect()
			for k: String in ["btn_continue", "btn_story", "btn_chapters", "btn_roam", "btn_guide", "btn_settings", "btn_quit"]:
				var b: Button = menu.get(k)
				_check(vp.grow(1.0).encloses(b.get_global_rect()), "main menu fits 1280x720 with every button: %s at %s" % [k, str(b.get_global_rect())])
			_check(_clean((menu.get("btn_chapters") as Button).text), "main menu button text without emoji")
			menu.queue_free()
			menu = null
			_open_cs()
			_next(3)
		3:
			if frames < 4:
				return false
			_rewind_through_ui()
			_next(30)
		30:
			if frames < 4:
				return false
			_rewind_confirm_yes()
			_next(4)
		4:
			if frames < 3:
				return false
			_roam()
			_next(5)
		5:
			if frames < 40:
				return false
			var sr: StoryRoam = fr.get("story_roam")
			_check(sr != null and sr.markers.has("d1_corridor"), "after the rewind: the d1_corridor marker is up")
			_check(sr != null and sr.mission_node == null and fr.get("cine_player") == null, "after the rewind: nothing starts by itself")
			_check(int(sd.get("day")) == 1 and String(sd.get("tod")) == "night" and String(fr.get("tod_preset")) == "night", "after the rewind: Day 1 at night (day %d, tod %s / %s)" % [int(sd.get("day")), String(sd.get("tod")), String(fr.get("tod_preset"))])
			_check(bool((sd.get("flags") as Dictionary).get("d1_key", false)) and not bool(sd.call("has_evidence", "E2")), "after the rewind: the key flag, E2 not taken")
			fr.queue_free()
			fr = null
			paused = false
			_after_rewind()
			_next(6)
		6:
			if frames < 4:
				return false
			_restore_through_ui()
			_check(StoryChapters.rewind(sd, "d0_wake"), "rewind to the first cinematic beat")
			_roam()
			_next(7)
		7:
			if fr.get("cine_player") == null:
				if frames > 900:
					_check(false, "the cinematic beat did not play after the rewind")
					return _end()
				return false
			var cp: CinePlayer = fr.get("cine_player")
			_check(cp.timeline.slot == "cine_d0_wake", "rewind to d0_wake: cine_d0_wake plays (%s)" % cp.timeline.slot)
			_check(StoryChapters.is_cine_unlocked("cine_d0_wake"), "the cinematic is unlocked when it starts")
			var n: int = 0
			while fr.get("cine_player") != null and n < 2000:
				cp.step(DT)
				n += 1
			_next(8)
		8:
			if frames < 3:
				return false
			_check(String(sd.get("step")) == "d0_race", "the beat goes on after the cinematic (%s)" % String(sd.get("step")))
			sd.call("on_leave_to_menu")
			fr.queue_free()
			fr = null
			paused = false
			_open_cs()
			_next(9)
		9:
			if frames < 3:
				return false
			_gallery_list()
			_next(10)
		10:
			if gp.player == null:
				if frames > 300:
					_check(false, "gallery playback did not start")
					return _end()
				return false
			_check(bool(sd.get("active")), "gallery: the director is borrowed (active) for the playback")
			_check(not (StoryUtil.hero_opts() as Dictionary).is_empty() and StoryUtil.hero_name() == "Khoa", "gallery: the save's protagonist plays (%s)" % StoryUtil.hero_name())
			var p2: CinePlayer = gp.player
			var n2: int = 0
			while gp.player != null and n2 < 2000:
				p2.step(DT)
				n2 += 1
			_next(11)
		11:
			if frames < 3:
				return false
			_check(gp.last_nav == "chapters" and ChapterSelect.open_tab == "gallery", "gallery: back to the gallery tab (%s)" % gp.last_nav)
			_check(not bool(sd.get("active")) and var_to_str(sd.call("to_dict")) == dir_before, "gallery: the director state is put back")
			_check(FileAccess.get_file_as_bytes(TMP_SAVE) == save_bytes, "gallery: the story save is untouched")
			gp.queue_free()
			gp = null
			paused = false
			_open_cs()
			_next(12)
		12:
			if frames < 3:
				return false
			_check(cs.tab == "gallery" and ChapterSelect.open_tab == "chapters", "the screen reopens on the gallery tab")
			_free_cs()
			_seeding()
			_open_cs()
			_next(13)
		13:
			if frames < 3:
				return false
			_seeded_rows()
			_free_cs()
			_pause_entry()
			_next(14)
		14:
			if frames < 10:
				return false
			var cur: Node = current_scene
			_check(cur is ChapterSelect and ChapterSelect.from_story, "pause menu CHỌN CẢNH opens the chapter select from the story (%s)" % (cur.name if cur else "null"))
			_check(not bool(sd.get("active")) and String(_read_save(TMP_SAVE).get("step", "")) != "", "leaving the story autosaved it")
			if cur is ChapterSelect:
				sd.set("last_nav", "")
				(cur as ChapterSelect).go_back()
				_check(String(sd.get("last_nav")) == "roam" and (cur as ChapterSelect).last_nav == "story" and not ChapterSelect.from_story, "QUAY LẠI resumes the story (Continue)")
			_phase_c()
			return _end()
	return false


func _read_save(path: String) -> Dictionary:
	return sd.call("read_save", path)


## new story -> d2_morning through complete_step: unlocks and snapshots on entry.
func _story_walk() -> void:
	sd.call("new_story", P)
	_check(StoryChapters.is_beat_unlocked("d0_wake") and _snap("d0_wake").get("step", "") == "d0_wake", "new story: d0_wake unlocked with its snapshot")
	_walk_to("d1_corridor")
	for id: String in ["d0_race", "d0_exam", "d0_bed", "d0_call", "d1_start", "d1_morning", "d1_stakeout", "d1_brawl", "d1_corridor"]:
		_check(StoryChapters.is_beat_unlocked(id), "%s unlocked on entry" % id)
	for id2: String in ["d0_race", "d0_exam", "d0_exam_end", "d0_midnight", "d0_intro", "d1_morning", "d1_stakeout", "d1_chase", "d1_brawl", "d1_corridor"]:
		_check(_snap(id2).get("step", "") == id2, "snapshot of the replayable beat %s" % id2)
	for id3: String in ["d0_bed", "d0_call", "d1_start"]:
		_check(_snap(id3).is_empty(), "no snapshot for the %s beat %s" % [String(StoryMissions.beat(id3)["kind"]), id3])
	var race: Dictionary = _snap("d0_race")
	_check(int(race["day"]) == 0 and (race["evidence"] as Array).is_empty() and String(race["tod"]) == "morning", "d0_race snapshot: Day 0, morning, no evidence yet")
	var exam_end: Dictionary = _snap("d0_exam_end")
	_check("E1" in (exam_end["evidence"] as Array), "d0_exam_end snapshot: E1 from the exam just won")
	var morning: Dictionary = _snap("d1_morning")
	_check(int(morning["day"]) == 1 and String(morning["step"]) == "d1_morning", "day start snapshot: Day 1 morning")
	var cor: Dictionary = _snap("d1_corridor")
	_check(int(cor["day"]) == 1 and String(cor["tod"]) == "night" and bool((cor["flags"] as Dictionary).get("d1_key", false)) and (cor["evidence"] as Array) == ["E1"], "d1_corridor snapshot: Day 1, night, key flag, E1")
	_check(String((cor["protagonist"] as Dictionary).get("name", "")) == "Lan", "snapshot keeps the protagonist")
	sd.call("complete_step", "d1_corridor")
	(sd.get("choices") as Dictionary)["phuc"] = "report"
	sd.call("complete_step", "d1_choice")
	_check(String((_snap("d1_choice")["choices"] as Dictionary).get("phuc", "x")) == "" and String((_snap("d1_choice_tail")["choices"] as Dictionary).get("phuc", "")) == "report", "choice beat snapshot before the answer, tail snapshot after")
	_walk_to("d2_morning")
	_check(String(_read_save(TMP_SAVE).get("step", "")) == "d2_morning", "the save is at d2_morning")


func _rewind_through_ui() -> void:
	_check(cs.tab == "chapters", "the screen opens on CHỌN CẢNH")
	var d0: Label = cs.list_box.get_node_or_null("Day0") as Label
	_check(d0 != null and d0.text == "Ngày 0 · Phòng 311", "day group header 'Ngày 0 · Phòng 311' (%s)" % (d0.text if d0 else "none"))
	_check(cs.list_box.get_node_or_null("Day4") == null, "a day with nothing unlocked is hidden")
	_check(cs.row_button("d0_bed") == null and cs.row_button("d1_start") == null, "bed / day beats are not chapters")
	var row: Button = cs.row_button("d1_corridor")
	_check(row != null and not row.disabled and row.text == "Hành lang tối", "the d1_corridor row with its beat title")
	_check(not cs.restore_btn.visible, "no restore button without a backup")
	var vp: Rect2 = root.get_visible_rect().grow(1.0)
	for c: Control in [cs.back_btn, cs.scroll, cs.tab_buttons["gallery"]]:
		_check(vp.encloses(c.get_global_rect()), "chapter screen fits 1280x720: %s at %s" % [c.name, str(c.get_global_rect())])
	_texts_clean(cs, "chapter screen")
	if row == null:
		return
	row.pressed.emit()
	_check(cs.confirm_dim.visible and cs.confirm_title.text == "Tua về 'Hành lang tối'?" and cs.confirm_note.text == "Tiến độ hiện tại được lưu lại, có thể quay về.", "confirm: %s %s" % [cs.confirm_title.text, cs.confirm_note.text])
	_texts_clean(cs.confirm_dim, "rewind confirm")



## The confirm laid out (a few frames after it opened): inside 1280x720; then TUA VỀ.
func _rewind_confirm_yes() -> void:
	var panel: Control = cs.confirm_dim.find_child("ConfirmPanel", true, false) as Control
	_check(panel != null and root.get_visible_rect().grow(1.0).encloses(panel.get_global_rect()), "the confirm fits 1280x720 (%s)" % (str(panel.get_global_rect()) if panel else "none"))
	sd.set("last_nav", "")
	cs.confirm_yes.pressed.emit()
	_check(String(_read_save(TMP_B).get("step", "")) == "d2_morning", "rewind: the current save is backed up")
	_check(String(_read_save(TMP_SAVE).get("step", "")) == "d1_corridor", "rewind: the snapshot is the save now")
	_check(String(sd.get("last_nav")) == "roam" and cs.last_nav == "story" and String(sd.get("step")) == "d1_corridor" and bool(sd.get("active")), "rewind: the story continues at d1_corridor")
	_check(StoryChapters.is_beat_unlocked("d2_morning") and not _snap("d2_morning").is_empty(), "rewind: unlocks and snapshots of later beats stay")
	_free_cs()


func _after_rewind() -> void:
	# latest snapshot wins
	(sd.get("flags") as Dictionary)["test_mark"] = true
	sd.call("complete_step", "d1_corridor")
	_check(bool((_snap("d1_choice")["flags"] as Dictionary).get("test_mark", false)), "the latest snapshot of a beat wins")
	# a new story never shrinks the unlocks
	var before: int = StoryChapters.unlocked_beats().size()
	sd.call("new_story", {"female": false, "name": "Khoa"})
	_check(StoryChapters.unlocked_beats().size() == before and StoryChapters.is_beat_unlocked("d2_morning"), "new story: the unlocks never shrink")
	_check(not _snap("d2_morning").is_empty(), "new story: earlier snapshots stay")
	_check(String(_read_save(TMP_SAVE).get("step", "")) == "d0_wake", "new story saved at d0_wake")
	sd.call("on_leave_to_menu")
	_open_cs()


func _restore_through_ui() -> void:
	_check(cs.restore_btn.visible, "restore button shown with a backup")
	cs.restore_btn.pressed.emit()
	_check(cs.confirm_dim.visible and cs.confirm_title.text == ChapterSelect.RESTORE_TITLE, "restore asks first")
	_texts_clean(cs.confirm_dim, "restore confirm")
	sd.set("last_nav", "")
	cs.confirm_yes.pressed.emit()
	_check(String(_read_save(TMP_SAVE).get("step", "")) == "d2_morning", "restore: the save before the rewind is back")
	_check(not FileAccess.file_exists(TMP_B), "restore: the backup is used up")
	_check(String(sd.get("last_nav")) == "roam" and String(sd.get("step")) == "d2_morning", "restore: the story continues at d2_morning")
	_free_cs()


func _gallery_list() -> void:
	cs.show_tab("gallery")
	var b: Button = cs.row_button("cine_d0_wake")
	_check(b != null and not b.disabled and b.text == "Tôi là ai, đây là đâu?", "gallery: the unlocked cinematic row")
	var locked: Button = cs.row_button("cine_d0_brief")
	_check(locked != null and locked.disabled and locked.text == "???", "gallery: a locked cinematic reads ???")
	_check(cs.list_box.get_node_or_null("Day1") == null and cs.list_box.get_node_or_null("Day0") != null, "gallery: grouped by day, days without a cinematic hidden")
	_texts_clean(cs, "gallery")
	var titles: Array = []
	for row: Dictionary in StoryChapters.gallery():
		titles.append(String(row["title"]))
		_check(CineTimeline.load_slot(String(row["slot"])) != null, "gallery slot %s exists" % String(row["slot"]))
	_check(_clean(" ".join(PackedStringArray(titles))) and _clean(StoryChapters.NEED_PLAY_LINE), "gallery titles without emoji")
	if b == null:
		return
	b.pressed.emit()
	_check(cs.last_nav == "gallery:cine_d0_wake" and StoryGalleryPlayer.slot == "cine_d0_wake" and ChapterSelect.open_tab == "gallery", "gallery: a row opens the player")
	_free_cs()
	save_bytes = FileAccess.get_file_as_bytes(TMP_SAVE)
	sd.set("protagonist", {})   # the playback must take the protagonist from the save, not from the director
	dir_before = var_to_str(sd.call("to_dict"))
	gp = (load(ChapterSelect.GALLERY_SCENE) as PackedScene).instantiate()
	gp.nav_enabled = false
	gp.cine_opts = {"manual": true, "music": false}
	root.add_child(gp)


func _seeding() -> void:
	for p: String in [TMP_U, TMP_C, TMP_B]:
		_rm(p)
	sd.call("from_dict", {"active": true, "day": 1, "tod": "night", "step": "d1_choice_tail", "evidence": ["E1", "E2"],
		"choices": {"phuc": "cover", "zaman_offer": "", "bribe": ""},
		"flags": {"d1_key": true, "d1_locker": true, "intro_cine_d1_intro": true, "night_photo_d1": true},
		"protagonist": P, "texts": [], "objective": "Phúc…", "spawn": null})
	sd.call("save_game")
	sd.call("reset_state")
	_check(bool(sd.call("load_game")), "old save loads")
	_check(FileAccess.file_exists(TMP_U), "old save: the unlock file is seeded")
	for id: String in ["d0_wake", "d0_intro", "d1_start", "d1_corridor", "d1_choice", "d1_choice_tail"]:
		_check(StoryChapters.is_beat_unlocked(id), "old save: %s unlocked" % id)
	_check(not StoryChapters.is_beat_unlocked("d1_end"), "old save: later beats stay locked")
	for s: String in ["cine_d0_wake", "cine_d0_brief", "cine_d0_exam", "cine_d0_midnight", "ai_intro", "cine_day_start", "cine_d1_intro", "seg_d1_brawl", "cine_d1_corridor", "cine_d1_choice"]:
		_check(StoryChapters.is_cine_unlocked(s), "old save: cinematic %s unlocked" % s)
	for s2: String in ["cine_d1_choice_cover", "cine_d1_choice_report", "cine_d1", "cine_d4"]:
		_check(not StoryChapters.is_cine_unlocked(s2), "old save: cinematic %s not unlocked" % s2)
	var own: Dictionary = _snap("d1_choice_tail")
	_check(String(own.get("step", "")) == "d1_choice_tail" and (own.get("evidence", []) as Array) == ["E1", "E2"] and not own.has("seeded"), "old save: the current beat's snapshot is the save")
	var cor: Dictionary = _snap("d1_corridor")
	_check(bool(cor.get("seeded", false)) and int(cor.get("day", -1)) == 1 and String(cor.get("tod", "")) == "night", "best effort d1_corridor: Day 1, night")
	_check((cor.get("evidence", []) as Array) == ["E1"] and not (cor["flags"] as Dictionary).has("d1_locker"), "best effort d1_corridor: E1 only, the locker still to open")
	_check(bool((cor["flags"] as Dictionary).get("d1_key", false)) and bool((cor["flags"] as Dictionary).get("intro_cine_d1_intro", false)), "best effort d1_corridor: key flag and intro seen")
	_check(String((cor["choices"] as Dictionary).get("phuc", "x")) == "" and String((cor["protagonist"] as Dictionary).get("name", "")) == "Lan", "best effort d1_corridor: no choice yet, the protagonist")
	_check(not (cor["flags"] as Dictionary).has("night_photo_d1"), "best effort d1_corridor: today's night photo can still come")
	var race: Dictionary = _snap("d0_race")
	_check(int(race.get("day", -1)) == 0 and (race.get("evidence", []) as Array).is_empty() and String(race.get("objective", "")).begins_with("Phóng xe"), "best effort d0_race: Day 0, no evidence, its objective")
	var dm: Dictionary = _snap("d1_morning")
	var last: Dictionary = (dm.get("texts", []) as Array).back() if not (dm.get("texts", []) as Array).is_empty() else {}
	_check(String(last.get("from", "")) == "Phúc" and not bool(last.get("read", true)) and int(last.get("day", 0)) == 1, "best effort d1_morning: the day's text, unread")
	var stake: Dictionary = _snap("d1_stakeout")
	_check(not (stake["flags"] as Dictionary).has("intro_cine_d1_intro"), "best effort d1_stakeout: its intro plays again")
	_check(not StoryChapters.ensure_seeded(_read_save(TMP_SAVE)), "seeding happens once")
	StoryChapters.mark_beat("d4_canteen")   # reached without a snapshot


func _seeded_rows() -> void:
	var end_row: Button = cs.row_button("d1_end")
	_check(end_row != null and end_row.disabled and end_row.text == "???", "a locked beat of an open day reads ???")
	var need: Button = cs.row_button("d4_canteen")
	_check(need != null and need.disabled and need.text.contains("Chơi tới cảnh này một lần để mở"), "a beat without a snapshot: disabled, 'Chơi tới cảnh này một lần để mở'")
	var cor: Button = cs.row_button("d1_corridor")
	_check(cor != null and not cor.disabled, "a best-effort chapter can be picked")
	_texts_clean(cs, "seeded chapter screen")
	cs.ask_restore()
	_texts_clean(cs.confirm_dim, "restore confirm")
	cs.close_confirm()


func _pause_entry() -> void:
	var btn: Button = sm.get("pause_chapters_btn")
	var hub: Button = sm.get("pause_hub_btn")
	sd.set("active", false)
	sm.call("pause_game")
	_check(btn != null and not btn.visible and hub.visible, "pause menu: no CHỌN CẢNH outside the story")
	sm.call("resume_game")
	sd.set("active", true)
	sm.call("pause_game")
	_check(btn != null and btn.visible and not hub.visible, "pause menu: CHỌN CẢNH in story mode")
	_check(_clean(btn.text), "pause button text without emoji")
	btn.pressed.emit()


## Phase C kinds: replayable, listed, snapshotted; the gallery's Phase C rows; best_effort keeps the crates flag (E4).
func _phase_c() -> void:
	sm.set("story_context", {})
	for p: String in [TMP_U, TMP_C, TMP_B]:
		_rm(p)
	for id: String in ["d2_chase", "d2_bridge", "d2_duel", "d2_end", "d3_sneak", "d3_mannequins", "d3_gunfight", "d3_crates", "d3_boss",
			"d5_stealth", "d5_monitors", "d5_gunfight", "d5_hack", "d5_choice", "d5_choice_tail", "d5_duel", "d5_end"]:
		_check(StoryChapters.is_replayable(id), "Phase C: %s is replayable" % id)
	for id2: String in ["d2_bed", "d2_call", "d3_bed", "d5_call", "d6_start"]:
		_check(not StoryChapters.is_replayable(id2), "Phase C: %s is not a chapter" % id2)
	var listed: Array = []
	for row: Dictionary in StoryChapters.chapters():
		listed.append(String(row["id"]))
	_check(listed.has("d5_hack") and listed.has("d3_crates") and listed.has("d2_duel") and not listed.has("d5_end_c"), "the chapter list has the Phase C beats in story order")
	_check(listed.find("d2_chase") < listed.find("d3_sneak") and listed.find("d3_end") < listed.find("d4_canteen") and listed.find("d4_end") < listed.find("d5_stealth"), "Phase C chapters in story order")
	sd.call("new_story", P)
	_walk_to("d5_hack")
	for id3: String in ["d2_chase", "d3_crates", "d5_stealth", "d5_hack"]:
		var sn: Dictionary = _snap(id3)
		_check(not sn.is_empty() and String(sn.get("step", "")) == id3, "Phase C: %s snapshotted on entry" % id3)
	var days: Dictionary = {}
	for row2: Dictionary in StoryChapters.gallery():
		days[int(row2["day"])] = true
	for sl: String in ["cine_d2_intro", "seg_d2_boss", "cine_d2", "cine_d3_intro", "cine_d3_mannequins", "seg_d3_boss", "cine_d3",
			"cine_d5_intro", "cine_d5_monitors", "cine_d5_choice", "seg_d5_boss", "cine_d5", "end_c"]:
		_check(StoryChapters.gallery_title(sl) != sl, "the gallery lists %s" % sl)
	_check(days.has(2) and days.has(3) and days.has(5), "gallery days 2, 3 and 5")
	var save: Dictionary = {"active": true, "day": 3, "tod": "night", "step": "d3_end", "evidence": ["E1", "E3", "E4"], "choices": {},
		"flags": {"d3_all_crates": true, "d3_manifest": true}, "protagonist": P, "texts": [], "objective": "", "spawn": null}
	var be: Dictionary = StoryChapters.best_effort(save, "d3_boss")
	_check(bool((be["flags"] as Dictionary).get("d3_all_crates", false)) and not (be["evidence"] as Array).has("E4"), "best effort at d3_boss: the crates flag kept, E4 offered again")
	# a finished story (ending C) put back by QUAY VỀ: restored, not a failure (review fix)
	sd.call("reset_state")
	sd.call("from_dict", {"active": true, "day": 5, "tod": "night", "step": "d5_end_c", "evidence": ["E1"], "choices": {"zaman_offer": "accept"},
		"flags": {"ending": "C"}, "protagonist": P, "texts": [], "objective": "", "spawn": null, "ending": "C"})
	sd.call("save_game", TMP_B)
	sd.call("reset_state")
	sd.call("new_story", P)
	_open_cs()
	_check(cs.restore_btn.visible, "the restore button shows with a backup")
	cs.ask_restore()
	cs._on_confirm()
	_check(StoryChapters.last_restore_finished and String(_read_save(TMP_SAVE).get("ending", "")) == "C" and not bool(sd.get("active")),
		"QUAY VỀ to a finished story: the save is back (ending C), the story does not continue")
	_check(cs.notice_label.visible and cs.notice_label.text == ChapterSelect.RESTORED_FINISHED_LINE and cs.last_nav != "story" and not cs.restore_btn.visible,
		"the screen says the finished save was restored (no failure)")
	_check(_clean(ChapterSelect.RESTORED_FINISHED_LINE), "the restore line without emoji")
	_free_cs()
	sd.call("reset_state")


func _end() -> bool:
	if fr and is_instance_valid(fr):
		fr.queue_free()
	paused = false
	for p: String in [TMP_SAVE, TMP_U, TMP_C, TMP_B]:
		_rm(p)
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
	sm.set("story_context", {})
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: CHAPTER SELECT (unlocks, snapshots, menu button, rewind, restore, gallery, old saves, pause entry)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
