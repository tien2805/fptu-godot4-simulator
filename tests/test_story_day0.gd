# File: res://tests/test_story_day0.gd
# Headless end-to-end test of story Day 0 (spec A2-D1..A2-D16): a new story (temp save, scene changes recorded instead of
# made) -> FreeRoam in story mode (crowd and weapons off): no stage hotspots, no [T], the protagonist as the player, Day 0
# chip + objective -> the wake cinematic plays by itself (manual steps) -> Phúc's text, the race marker (pink, radar blip,
# map pin), [E] blocked while wanted, [E] -> story_context -> report_stage_result fail (TOANG!, retry keeps the context)
# then win (autosave, next beat) -> exam marker -> win: E1 -> exam-end cinematic -> sunset, bed marker -> bed -> midnight
# cinematic at night -> the 3 a.m. call -> ai_intro fallback with its cards (no owner video) -> Day 1 morning, chip
# "NGÀY 1 · CÒN 7 NGÀY", then Phase B's Day 1 (night, the main-gate marker), autosave -> leaving for the menu saves the
# player's spot -> Continue restores Day 1 and a second FreeRoam spawns there with no cinematic -> free play (no story)
# has no story layer. Day 1 itself is tested by test_story_day1.
# Run:  godot --headless --path . --script tests/test_story_day0.gd
extends SceneTree

var TMP: String = "user://test_story_day0_%d.cfg" % OS.get_process_id()
var VID: String = "user://test_story_day0_video_%d/" % OS.get_process_id()
const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var saved_spawn: Transform3D
var saves0: int = 0
var race_spot: Vector2 = Vector2.ZERO
var cine_frames: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 0 (end to end) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	StoryVideo.video_dir = VID   # an empty folder: the owner's ai_intro video never plays in the test


func _roam() -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	sr = fr.get("story_roam")
	if sr:
		sr.cine_opts = {"manual": true, "music": false}
		sr.call_opts = {"manual": true}


## Steps the running cinematic to its end (manual CinePlayer). Returns its slot.
func _finish_cine() -> String:
	var cp: CinePlayer = fr.get("cine_player")
	if cp == null:
		return ""
	var slot: String = cp.timeline.slot
	var n: int = 0
	while fr.get("cine_player") != null and n < 3000:
		cp.step(DT)
		n += 1
	_check(fr.get("cine_player") == null, "%s finished" % slot)
	return slot


func _process(_d: float) -> bool:
	frames += 1
	if frames > 20000:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	match phase:
		0:
			sd.call("new_story", {"female": true, "name": "Lan Anh", "variant": 2, "hair_style": "ponytail", "hair_color": 1, "skin": 2})
			_check(int(sd.get("saves")) == 1, "autosave on creator confirm")
			_roam()
			phase = 1
			frames = 0
		1:
			if frames < 3:
				return false
			_check(bool(fr.get("story_mode")) and sr != null, "FreeRoam in story mode with a StoryRoam")
			_check((fr.get("hotspots") as Array).is_empty(), "no stage hotspots in story mode")
			var co: Dictionary = (fr.get("player") as ThirdPersonController).character_opts
			_check(bool(co.get("female", false)) and String(co.get("hair_style", "")) == "ponytail" and int(co.get("variant", -1)) == 2, "the player is the protagonist")
			_check(String(fr.get("tod_preset")) == "morning", "Day 0 starts in the morning")
			var tk := InputEventKey.new()
			tk.physical_keycode = KEY_T
			tk.pressed = true
			fr.call("_unhandled_input", tk)
			_check(String(fr.get("tod_preset")) == "morning", "[T] does not cycle the time in story mode")
			_check(sr.day_label.text == "NGÀY 0 · THI EOS" or (fr.get("vice_hud") as ViceHUD).day_label.text == "NGÀY 0 · THI EOS", "Day 0 chip")
			phase = 2
			frames = 0
		2:
			if fr.get("cine_player") == null:
				return false
			var cp: CinePlayer = fr.get("cine_player")
			_check(cp.timeline.slot == "cine_d0_wake" and String((fr.get("cine_stage_info") as Dictionary).get("landmark", "")) == "@at", "the wake cinematic plays at the BE6 spawn (%s)" % str(fr.get("cine_stage_info")))
			_check(String(cp.timeline.actors["hero"]["name"]) == "Lan Anh", "the cinematic hero is the protagonist")
			_finish_cine()
			phase = 3
			frames = 0
		3:
			if frames < 3:
				return false
			_check(String(sd.get("step")) == "d0_race" and int(sd.call("unread_count", "Phúc")) == 1, "d0_race with Phúc's text")
			_check(sr.toast_panel.visible and sr.toast_label.text.contains("Phúc"), "the text shows a toast")
			_check(sr.markers.has("d0_race") and sr.blips().size() == 1 and sr.map_pins().size() == 1, "race marker with a radar blip and a map pin")
			var mp: Vector2 = sr.marker_pos["d0_race"]
			race_spot = mp
			(fr.get("player") as ThirdPersonController).teleport(Vector3(mp.x, 0.2, mp.y), 0.0)
			phase = 4
			frames = 0
		4:
			if frames < 20:
				return false
			_check(sr.active_marker == "d0_race" and sr.hint_text() == "[E] Nhiệm vụ: Đua tới FPTU" and String(fr.call("_hint_text")) == sr.hint_text(), "standing in the marker: hint [E] Nhiệm vụ")
			var w := WantedDirector.new()
			w.stars = 1
			fr.set("wanted", w)
			_check(not sr.start_marker("d0_race") and sr.hint_text() == StoryRoam.BLOCKED_HINT, "markers are blocked while wanted")
			fr.set("wanted", null)
			w.free()
			_check(sr.start_marker("d0_race"), "[E] starts the race beat")
			var ctx: Dictionary = sm.get("story_context")
			_check(String(sd.get("last_nav")) == "stage:1" and String(ctx.get("beat", "")) == "d0_race" and int(ctx.get("stage", 0)) == 1, "story_context for Stage 1")
			# fail, retry, win
			var res: Dictionary = {"result": "fail", "score": 0, "rank": "C", "detail": "absent"}
			sm.call("report_stage_result", 1, res)
			_check((sd.get("result_title") as Label).text == "TOANG!" and String(sd.get("step")) == "d0_race", "race fail: TOANG!, beat kept")
			(sd.get("result_buttons")["retry"] as Button).emit_signal("pressed")
			_check(String(sd.get("last_nav")) == "retry:1" and not (sm.get("story_context") as Dictionary).is_empty(), "retry keeps the context")
			saves0 = int(sd.get("saves"))
			sm.call("report_stage_result", 1, {"result": "win", "score": 900, "rank": "A", "detail": "test"})
			_check(String(sd.get("step")) == "d0_exam" and int(sd.get("saves")) > saves0, "race win: d0_exam, autosave")
			(sd.get("result_buttons")["continue"] as Button).emit_signal("pressed")
			_check(String(sd.get("last_nav")) == "roam" and (sm.get("story_context") as Dictionary).is_empty() and sm.get("roam_spawn") is Transform3D, "continue -> story free roam at the return spot")
			phase = 5
			frames = 0
		5:
			if frames < 5:
				return false
			_check(sr.markers.has("d0_exam") and not sr.markers.has("d0_race"), "the exam marker replaces the race marker")
			var map: Control = fr.get("map_overlay")
			map.visible = true
			_check(not sr.start_marker("d0_exam"), "[E] is refused with the map open")
			map.visible = false
			sr.phone.open()
			_check(not sr.start_marker("d0_exam") and bool(fr.call("mayhem_blocked")), "[E] is refused and mayhem blocked with the phone open")
			sr.phone.close()
			# A2-D17: [E] plays the mission intro cine_d0_brief, then the Extra stage starts
			_check(sr.start_marker("d0_exam") and fr.get("cine_player") != null and String(sd.get("last_nav")) == "roam", "[E] on Phòng 311 plays the mission intro first")
			_check(_finish_cine() == "cine_d0_brief" and String(sd.get("last_nav")) == "stage:7", "after cine_d0_brief the Extra stage starts")
			sm.call("report_stage_result", 7, {"result": "fail", "score": 0, "rank": "C", "detail": "test"})
			(sd.get("result_buttons")["retry"] as Button).emit_signal("pressed")
			_check(String(sd.get("last_nav")) == "retry:7" and fr.get("cine_player") == null, "retry from the fail card skips the intro")
			sm.call("report_stage_result", 7, {"result": "fail", "score": 0, "rank": "C", "detail": "test"})
			(sd.get("result_buttons")["roam"] as Button).emit_signal("pressed")
			_check(sr.start_marker("d0_exam") and fr.get("cine_player") == null and String(sd.get("last_nav")) == "stage:7", "a second [E] after a fail starts the stage without the intro")
			sm.call("report_stage_result", 7, {"result": "win", "score": 1200, "rank": "S", "detail": "test"})
			_check(sd.call("has_evidence", "E1") and String(sd.get("step")) == "d0_exam_end", "exam win: E1, d0_exam_end")
			(sd.get("result_buttons")["continue"] as Button).emit_signal("pressed")
			phase = 6
			frames = 0
		6:
			if fr.get("cine_player") == null:
				if frames > 120:
					_check(false, "the exam-end cinematic did not start")
					return _end()
				return false
			_check(_finish_cine() == "cine_d0_exam", "the exam-end cinematic plays by itself")
			phase = 7
			frames = 0
		7:
			if frames < 3:
				return false
			_check(String(sd.get("step")) == "d0_bed" and String(fr.get("tod_preset")) == "sunset", "after the exam: d0_bed at sunset")
			_check(sr.markers.has("d0_bed") and String(sd.get("objective")).contains("đi ngủ"), "bed marker + objective")
			_check(sr.start_marker("d0_bed") and String(sd.get("step")) == "d0_midnight", "[E] at the bed: midnight")
			phase = 8
			frames = 0
		8:
			if fr.get("cine_player") == null:
				return false
			cine_frames += 1
			if cine_frames < 3:
				return false
			_check(not sr.ui.visible, "the story HUD (objective, chip, toasts) hides during cinematics")
			_check(String(fr.get("tod_preset")) == "night", "midnight at night")
			_check(_finish_cine() == "cine_d0_midnight", "the midnight cinematic plays")
			phase = 9
			frames = 0
		9:
			if sr.call == null:
				if frames > 120:
					_check(false, "the 3 a.m. call did not start")
					return _end()
				return false
			var c: StoryCall = sr.call
			_check(paused and c.days == 7, "the call pauses the game, N = 7")
			var n: int = 0
			while c.phase != "ring" and n < 200:
				c.step(DT)
				n += 1
			c.answer()
			while sr.call != null and n < 2000:
				c.step(DT)
				n += 1
			_check(sr.call == null and not paused, "the call ended and the game runs again")
			var vh: ViceHUD = fr.get("vice_hud")
			_check(vh == null or vh.visible == ViceHUD.style_active(), "the roam HUD comes back as it was after the call")
			phase = 10
			frames = 0
		10:
			if fr.get("cine_player") == null:
				if frames > 120:
					_check(false, "ai_intro did not start")
					return _end()
				return false
			_check(sr.cards != null and String((fr.get("cine_player") as CinePlayer).timeline.slot) == "ai_intro", "no owner video: the ai_intro fallback with its cards")
			_finish_cine()
			phase = 105
			frames = 0
		105:
			if fr.get("cine_player") == null:
				if frames > 120:
					_check(false, "cine_day_start did not start")
					return _end()
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 1 and dc.left == 7 and int(sd.get("day")) == 1, "Day 1 morning: cine_day_start with the calendar page NGÀY 1 · CÒN 7 NGÀY")
			_check(_finish_cine() == "cine_day_start", "cine_day_start plays after ai_intro")
			phase = 11
			frames = 0
		11:
			if frames < 5:
				return false
			_check(int(sd.get("day")) == 1 and String(sd.get("step")) == "d1_stakeout", "Day 1: the stake-out beat (Phase B)")
			_check(String(fr.get("tod_preset")) == "night", "Day 1's mission is at night")
			var chip: String = String(sd.call("day_chip_text"))
			_check(chip == "NGÀY 1 · CÒN 7 NGÀY" and sr.day_label.text.begins_with(chip), "Day 1 chip: %s" % sr.day_label.text)
			_check(String(sd.get("objective")).contains("cổng chính") and sr.markers.has("d1_stakeout") and sr.markers.size() == 1, "Day 1 objective and its main-gate marker")
			_check(int((sd.call("read_save", TMP) as Dictionary).get("day", -1)) == 1, "Day 1 autosaved")
			var mr: Array = (sd.get("texts") as Array).filter(func(m: Dictionary) -> bool: return String(m["text"]) == "Thầy tin em. Tìm bằng chứng đi.")
			var ph: Array = (sd.get("texts") as Array).filter(func(m: Dictionary) -> bool: return String(m["text"]) == "Ê, tao nghe chuyện rồi... tối nay gặp ở campus nhé." and int(m["day"]) == 1)
			_check(mr.size() == 1 and ph.size() == 1, "Mr.T's text once (ai_intro) and Phúc's Day-1 text")
			# phone opens and blocks input
			var pk := InputEventKey.new()
			pk.physical_keycode = KEY_P
			pk.pressed = true
			sr._unhandled_input(pk)
			_check(sr.phone.is_open() and not (fr.get("player") as ThirdPersonController).controls_enabled, "[P] opens the phone and blocks input")
			sr.phone.close()
			# leave for the main menu: the spot is saved
			(fr.get("player") as ThirdPersonController).teleport(Vector3(race_spot.x, 0.2, race_spot.y), 0.5)
			saved_spawn = sr.player_xf()
			sd.call("on_leave_to_menu")
			_check(not bool(sd.get("active")) and (sd.get("spawn") as Transform3D).origin.is_equal_approx(saved_spawn.origin), "leaving for the menu saves the player's spot")
			fr.queue_free()
			phase = 12
			frames = 0
		12:
			if frames < 3:
				return false
			sd.call("reset_state")
			_check(bool(sd.call("continue_story")) and int(sd.get("day")) == 1 and String(sd.get("step")) == "d1_stakeout" and bool(sd.get("active")), "Continue restores Day 1")
			_check(String(sd.get("last_nav")) == "roam" and sm.get("roam_spawn") is Transform3D, "Continue enters free roam at the saved spot")
			_roam()
			phase = 13
			frames = 0
		13:
			if frames < 40:
				return false
			_check(bool(fr.get("story_mode")) and fr.get("cine_player") == null, "second FreeRoam: story mode, no cinematic on Day 1")
			var p: Vector3 = fr.call("roam_position")
			_check(Vector2(p.x, p.z).distance_to(Vector2(saved_spawn.origin.x, saved_spawn.origin.z)) < 9.0, "spawned at the saved spot (%s vs %s)" % [str(p), str(saved_spawn.origin)])
			_check(String(fr.get("tod_preset")) == "night" and sr.day_label.text.begins_with("NGÀY 1 · CÒN 7 NGÀY"), "Day 1 chip after Continue (night)")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			phase = 14
			frames = 0
		14:
			if frames < 3:
				return false
			sd.call("reset_state")
			sm.set("roam_spawn", null)
			_roam()
			phase = 15
			frames = 0
		15:
			if frames < 3:
				return false
			_check(not bool(fr.get("story_mode")) and fr.get("story_roam") == null and fr.find_child("StoryRoam", true, false) == null, "free play: no story layer")
			_check(not (fr.get("hotspots") as Array).is_empty(), "free play keeps the stage hotspots")
			fr.queue_free()
			return _end()
	return false


func _end() -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 0 END TO END (creator -> wake -> race -> exam/E1 -> bed -> midnight -> call -> ai_intro -> Day 1, continue)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
