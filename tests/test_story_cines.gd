# File: res://tests/test_story_cines.gd
# Headless test of the Day 0 cinematics (spec A2-D10, A2-D14, A2-D16): cine_d0_wake 8 s, cine_d0_exam 18 s, cine_d0_midnight
# 22 s and the ai_intro fallback 24 s validate (exact length, music slot = slot, landmark fallback, known cues, Day-0
# beats point at them), their beat sheets in docs/cinematics are in sync, every line is Vietnamese without a gendered
# pronoun for the protagonist, the hero is the protagonist (opts + {name}), "Giảm hù dọa" drops the violin screech, the
# camera punch and the lamp flicker, each plays to its exact end in a CinePlayer (empty world, manual steps, no music) with
# its new props built, the lamp flicker is seekable, StoryIntroCards shows the email / TOANG stamp / Mr.T text / countdown
# 7 / title at their times, and StoryVideo only picks user://video/ai_intro_m|f.ogv when the file exists (temp dir).
# Run:  godot --headless --path . --script tests/test_story_cines.gd
extends SceneTree

const SLOTS: Dictionary = {"cine_d0_wake": 8.0, "cine_d0_exam": 18.0, "cine_d0_midnight": 22.0, "ai_intro": 24.0,
	"cine_d0_brief": 12.0, "cine_day_start": 9.0}   # A2-D17: mission intro + day start
const BANNED: Array[String] = ["anh ấy", "cô ấy", "cậu ấy", "chàng", "nàng", " hắn", "anh ta", "cô ta"]
const VID_DIR: String = "user://test_story_video/"
var fails: Array[String] = []
var frames: int = 0
var sd: Node
var fx: Node


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _process(_d: float) -> bool:
	frames += 1
	if frames < 2:
		return false
	sd = root.get_node("StoryDirector")
	fx = root.get_node("GameFX")
	sd.set("nav_enabled", false)
	sd.set("save_path", "user://test_story_cines.cfg")
	sd.call("reset_state")
	_sync()
	sd.call("new_story", {"female": true, "name": "Minh Thư", "hair_style": "bun", "variant": 1, "skin": 2, "hair_color": 1})
	_timelines()
	_reduce()
	_play_all()
	_cards()
	_video()
	sd.call("reset_state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_story_cines.cfg"))
	if fails.is_empty():
		print("✅ SUCCESS: STORY CINEMATICS (6 Day-0 slots valid + in sync, reduce scares, playback, intro cards, video pick)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true


func _timelines() -> void:
	var slots: PackedStringArray = CineTimeline.slots()
	for s: String in SLOTS.keys():
		_check(slots.has(s), "timeline %s registered" % s)
		var tl: CineTimeline = CineTimeline.load_slot(s)
		if tl == null:
			continue
		var errs: PackedStringArray = tl.validate()
		_check(errs.is_empty(), "%s validates: %s" % [s, str(errs)])
		_check(is_equal_approx(tl.length, float(SLOTS[s])) and absf(tl.clock.real_duration() - tl.length) < 0.001, "%s is exactly %.1f s" % [s, float(SLOTS[s])])
		_check(tl.music_slot == s and tl.stage.has("landmark") and tl.stage.has("tod"), "%s: music slot = slot, landmark fallback, tod" % s)
		var hero: Dictionary = tl.actors["hero"]
		var ho: Dictionary = hero["opts"]
		_check(bool(ho.get("female", false)) and String(ho.get("hair_style", "")) == "bun" and int(ho.get("variant", -1)) == 1 and String(hero["name"]) == "Minh Thư",
			"%s: the hero is the protagonist (%s)" % [s, str(ho)])
		for sb: Dictionary in tl.subs:
			_check(float(sb["dur"]) >= 0.06 * float(String(sb["text"]).length()) - 1e-6, "%s: '%s' reads at >= 0.06 s per character (%.2f s)" % [s, String(sb["text"]), float(sb["dur"])])
			var line: String = String(sb["text"]).to_lower()
			_check(not line.contains("{name}"), "%s: {name} formatted in '%s'" % [s, String(sb["text"])])
			for w: String in BANNED:
				_check(not line.contains(w), "%s: no gendered pronoun '%s' in '%s'" % [s, w, String(sb["text"])])
		for e: Dictionary in tl.sfx:
			_check(CineAudio.SFX_CUES.has(String(e["cue"])) or StoryAudio.is_cue(String(e["cue"])), "%s: cue %s exists" % [s, String(e["cue"])])
	var ex: CineTimeline = CineTimeline.load_slot("cine_d0_exam")
	var said: String = ""
	for sb2: Dictionary in ex.subs:
		said += String(sb2["text"]) + "\n"
	_check(said.contains("Giỏi lắm em! Ảnh tai nghe này là bằng chứng rõ ràng.") and said.contains("Ét o ét! Thi xong chưa?!") and said.contains("Minh Thư"), "exam lines (Mr.T, Phúc, {name})")
	_check(ex.actors.has("mr_t") and String(ex.actors["mr_t"]["name"]) == "Mr.T" and String((ex.actors["mr_t"]["opts"] as Dictionary)["preset"]) == "lecturer", "Mr.T is role mr_t, lecturer preset")
	var shows: Array = ex.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "show" and c["actor"] == "sheep")
	_check(shows.size() == 3 and is_equal_approx(float(shows[2]["s"]) - float(shows[1]["s"]), 1.5), "the sheep figure is seen for 1.5 s")
	var wk: CineTimeline = CineTimeline.load_slot("cine_d0_wake")
	_check(wk.subs.any(func(sb3: Dictionary) -> bool: return String(sb3["text"]) == "Tôi là ai, đây là đâu?") and wk.subs.any(func(sb4: Dictionary) -> bool: return String(sb4["text"]) == "Ê!!! Thi EOS 8h đó, 7h05 rồi!!!"), "wake lines")
	var br: CineTimeline = CineTimeline.load_slot("cine_d0_brief")
	var bsaid: String = ""
	for sb5: Dictionary in br.subs:
		bsaid += String(sb5["text"]) + "|"
	_check(bsaid.contains("Minh Thư! Phòng 311 thiếu giám thị, em phụ thầy được không?") and bsaid.contains("Thầy nghe đồn có tool tên 'Lọ Thần'. Thấy gì lạ thì chụp lại giúp thầy."), "brief lines (Mr.T, {name})")
	_check(br.cues.any(func(c: Dictionary) -> bool: return c["type"] == "move" and c["move"] == "nod") and br.shots.any(func(sh: Dictionary) -> bool: return sh["rig"] == "dolly"), "the protagonist nods; push-in on the door")
	# the day-start template takes N, M and the text from StoryDirector
	sd.call("set_step", "d1_morning")
	sd.set("day", 1)
	var ds: CineTimeline = CineTimeline.load_slot("cine_day_start")
	_check(int(ds.get("days")) == 1 and int(ds.get("left")) == 7 and ds.subs.any(func(sb6: Dictionary) -> bool: return String(sb6["text"]) == "Ê, tao nghe chuyện rồi… tối nay gặp ở campus nhé." and String(sb6["speaker"]).begins_with("Phúc")), "day start Day 1: NGÀY 1 · CÒN 7 NGÀY + Phúc's text")
	_check(ds.cues.any(func(c2: Dictionary) -> bool: return c2["type"] == "move" and c2["move"] == "hold_up"), "the phone is read with hold_up")
	sd.set("day", 3)
	var ds3: CineTimeline = CineTimeline.load_slot("cine_day_start")
	_check(int(ds3.get("days")) == 3 and int(ds3.get("left")) == 5 and ds3.validate().is_empty(), "the same template serves a later day (N 3, M 5)")
	sd.set("day", 0)
	sd.call("set_step", "d0_wake")
	for id: String in ["d0_wake", "d0_exam_end", "d0_midnight", "d0_intro", "d1_morning"]:
		_check(SLOTS.has(String(StoryMissions.beat(id)["slot"])), "beat %s plays a Day-0 slot" % id)
	for gone: String in ["Thầy Toàn", "ToanHLM"]:
		for s2: String in SLOTS.keys():
			_check(not FileAccess.get_file_as_string("res://scripts/cine/timelines/%s.gd" % s2).contains(gone), "%s never names %s" % [s2, gone])


## Beat sheets are generated without a story (hero "Bạn", tools/cine_beats.gd).
func _sync() -> void:
	for s: String in SLOTS.keys():
		var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/%s.txt" % s).replace("\r\n", "\n")
		var fresh: CineTimeline = CineTimeline.load_slot(s)
		_check(fresh != null and committed == fresh.beat_sheet(), "docs/cinematics/%s.txt is in sync (run tools/cine_beats.gd)" % s)


func _cues_of(tl: CineTimeline) -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in tl.sfx:
		out.append(String(e["cue"]))
	return out


func _reduce() -> void:
	var was: bool = bool(fx.get("reduce_scares"))
	fx.set("reduce_scares", false)
	var scary: CineTimeline = CineTimeline.load_slot("cine_d0_midnight")
	fx.set("reduce_scares", true)
	var calm: CineTimeline = CineTimeline.load_slot("cine_d0_midnight")
	fx.set("reduce_scares", was)
	_check(_cues_of(scary).has("violin_screech") and not scary.punches.is_empty(), "midnight: violin screech + punch by default")
	var lamp_s: Dictionary = scary.props.filter(func(p: Dictionary) -> bool: return p["id"] == "lamp")[0]
	var lamp_c: Dictionary = calm.props.filter(func(p: Dictionary) -> bool: return p["id"] == "lamp")[0]
	_check(not (lamp_s["opts"]["flicker"] as Array).is_empty(), "midnight: the lamp flickers by default")
	_check(not _cues_of(calm).has("violin_screech") and calm.punches.is_empty() and (lamp_c["opts"]["flicker"] as Array).is_empty(), "Giảm hù dọa: no screech, no punch, no flicker")
	_check(calm.validate().is_empty() and _cues_of(calm).has("ba_dum_tss") and _cues_of(calm).has("dun_dun_duun"), "the calm variant still validates and keeps the jokes")


func _play_all() -> void:
	var world := Node3D.new()
	world.name = "CineWorld"
	root.add_child(world)
	for s: String in SLOTS.keys():
		var tl: CineTimeline = CineTimeline.load_slot(s)
		var p := CinePlayer.new()
		world.add_child(p)
		var errs: PackedStringArray = p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
		_check(errs.is_empty(), "%s sets up" % s)
		if not errs.is_empty():
			p.queue_free()
			continue
		var done: Array = []
		p.finished.connect(func(sk: bool) -> void: done.append(sk))
		p.start()
		var n: int = 0
		var flick_seen: Dictionary = {}
		while done.is_empty() and n < int(tl.length * 60.0) + 30:
			p.step(1.0 / 60.0)
			n += 1
			if s == "cine_d0_midnight" and p.prop_nodes.has("lamp"):
				var ol: OmniLight3D = (p.prop_nodes["lamp"] as Node3D).get_meta("lamp_light")
				flick_seen[ol.visible] = true
		_check(done == [false] and absi(n - int(round(tl.length * 60.0))) <= 1, "%s plays to its end (%d steps)" % [s, n])
		if s == "cine_d0_midnight":
			_check(p.prop_nodes.has("bench") and p.prop_nodes.has("bag") and flick_seen.has(false) and flick_seen.has(true), "midnight props built, the lamp went off and on")
			p.seek(6.25)
			var on1: bool = ((p.prop_nodes["lamp"] as Node3D).get_meta("lamp_light") as OmniLight3D).visible
			_check(on1 == CineFX.lamp_on(p.s, [[6.2, 7.4], [8.1, 8.7], [9.5, 10.1]]) and CineFX.lamp_on(3.0, [[6.2, 7.4]]), "lamp flicker is a pure function of story time (seek)")
		p.queue_free()
	world.queue_free()


func _cards() -> void:
	var cs: Script = load("res://scripts/story/StoryIntroCards.gd")
	var s0: Dictionary = cs.call("state_at", 0.5)
	_check(not bool(s0["email"]) and float(s0["stamp_scale"]) == 0.0 and int(s0["count"]) == -1 and not bool(s0["title"]), "nothing at 0.5 s")
	var s1: Dictionary = cs.call("state_at", 3.0)
	_check(bool(s1["email"]) and float(s1["stamp_scale"]) == 0.0, "the email at 3 s, no stamp yet")
	var s2: Dictionary = cs.call("state_at", 5.21)
	var s3: Dictionary = cs.call("state_at", 6.0)
	_check(float(s2["stamp_scale"]) > 2.0 and is_equal_approx(float(s3["stamp_scale"]), 1.0) and bool(s3["email"]), "TOANG! slams at 5.2 s and stays on the email")
	var s4: Dictionary = cs.call("state_at", 9.0)
	_check(bool(s4["text"]) and not bool(s4["email"]), "Mr.T's text at 9 s")
	var c13: int = int((cs.call("state_at", 12.7) as Dictionary)["count"])
	var c14: int = int((cs.call("state_at", 14.2) as Dictionary)["count"])
	var c16: int = int((cs.call("state_at", 16.5) as Dictionary)["count"])
	_check(c13 == 10 and c14 == 7 and c16 == 7, "the countdown flips 10 -> 7 (%d, %d, %d)" % [c13, c14, c16])
	var s5: Dictionary = cs.call("state_at", 20.0)
	_check(bool(s5["title"]) and float(s5["title_alpha"]) == 1.0 and int(s5["count"]) == -1, "title card TOOL ĐEN at 20 s")
	var cards: StoryIntroCards = StoryIntroCards.new()
	root.add_child(cards)
	cards.update(5.5)
	_check(cards.stamp.visible and cards.email_box.visible and cards.email_body.text.contains("Minh Thư") and cards.stamp.text == "TOANG!", "cards node: email with {name} + stamp")
	cards.update(14.5)
	_check(cards.count_label.visible and cards.count_label.text == "CÒN 7 NGÀY" and not cards.email_box.visible, "cards node: CÒN 7 NGÀY")
	# no one-letter-per-line labels (review A2-R3): the big words keep their text width
	var widths: Array = [cards.stamp.get_combined_minimum_size().x, cards.count_label.get_combined_minimum_size().x]
	for l: Node in cards.title_box.find_children("*", "Label", true, false):
		widths.append((l as Label).get_combined_minimum_size().x)
	var tc: Control = cards.title_box.find_child("TitleColumn", true, false) as Control
	_check(widths.size() == 4 and widths.all(func(w: float) -> bool: return w > 200.0) and tc != null and tc.get_combined_minimum_size().x >= 700.0,
		"stamp, countdown and title keep their width: %s" % str(widths))
	cards.queue_free()
	var day: StoryDayCard = StoryDayCard.new()
	day.days = 1
	day.left = 7
	root.add_child(day)
	day.update(1.5)
	var d1: Dictionary = StoryDayCard.state_at(1.5)
	var d2: Dictionary = StoryDayCard.state_at(StoryDayCard.TEAR_AT + 0.4)
	var d3: Dictionary = StoryDayCard.state_at(8.5)
	_check(bool(d1["shown"]) and float(d1["fall"]) == 0.0 and float(d2["fall"]) > 0.0 and not bool(d3["shown"]), "calendar page shows, tears off and falls, then is gone")
	_check(day.page_label.text == "NGÀY 1 · CÒN 7 NGÀY" and day.page_label.get_combined_minimum_size().x > 200.0, "calendar page NGÀY 1 · CÒN 7 NGÀY")
	day.queue_free()


func _video() -> void:
	StoryVideo.video_dir = VID_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VID_DIR))
	_check(StoryVideo.video_file("ai_intro", false) == "" and StoryVideo.video_file("ai_intro", true) == "", "no owner video -> fallback cinematic")
	var f := FileAccess.open(VID_DIR + "ai_intro_f.ogv", FileAccess.WRITE)
	f.store_string("not really a video")
	f.close()
	_check(StoryVideo.video_file("ai_intro", true) == VID_DIR + "ai_intro_f.ogv" and StoryVideo.video_file("ai_intro", false) == "", "the female protagonist picks ai_intro_f.ogv only")
	var v := StoryVideo.new()
	root.add_child(v)
	var played: bool = v.play_file(VID_DIR + "ai_intro_f.ogv")
	_check(not played and v.get_children().all(func(c: Node) -> bool: return c.is_queued_for_deletion()),
		"an undecodable owner file is refused (the fallback cinematic plays)")
	var sm: Node = root.get_node_or_null("StageManager")
	_check(sm == null or not bool(sm.get("cinematic_active")), "a refused video leaves no cinematic flag")
	v.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VID_DIR + "ai_intro_f.ogv"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VID_DIR))
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
