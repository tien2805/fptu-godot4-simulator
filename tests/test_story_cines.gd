# File: res://tests/test_story_cines.gd
# Headless test of the Day 0 cinematics (spec A2-D10, A2-D14, A2-D16): cine_d0_wake 8 s, cine_d0_exam 18 s, cine_d0_midnight
# 22 s and the ai_intro fallback 24 s validate (exact length, music slot = slot, landmark fallback, known cues, Day-0
# beats point at them), their beat sheets in docs/cinematics are in sync, every line is Vietnamese without a gendered
# pronoun for the protagonist, the hero is the protagonist (opts + {name}), "Giảm hù dọa" drops the violin screech, the
# camera punch and the lamp flicker, each plays to its exact end in a CinePlayer (empty world, manual steps, no music) with
# its new props built, the lamp flicker is seekable, StoryIntroCards shows the email / TOANG stamp / Mr.T text / countdown
# 7 / title at their times, and StoryVideo only picks user://video/ai_intro_m|f.ogv when the file exists (temp dir).
# Phase C (spec C-D9 to C-D13): the 15 new slots (intros, discovery beats with v2 jump scares and their reduced variants,
# choice 2 and its tails with the honest default "Từ chối", end cinematics, ending C with its credits, the three fights)
# validate at their exact lengths with beat sheets in sync, staged at explicit measured points; the new cast (gear on the
# bodies, the wolf helmets hide the rider helmet, Za Mẫn's white sneakers, the mannequin crowd); the villain cards for Sói
# Xám, Alexander (the endless name runs off and shrinks to fit) and Za Mẫn keep their widths in the lower-left band; the
# animated props (mannequin heads, monitor wall, STONKS, container doors); the radio / flow / credits screen cards; no
# emoji anywhere; no actor hidden behind another in any Phase C dialogue shot.
# Run:  godot --headless --path . --script tests/test_story_cines.gd
extends SceneTree

const SLOTS: Dictionary = {"cine_d0_wake": 8.0, "cine_d0_exam": 18.0, "cine_d0_midnight": 22.0, "ai_intro": 24.0,
	"cine_d0_brief": 12.0, "cine_day_start": 9.0,   # A2-D17: mission intro + day start
	# Phase B (B-D8 / B-D10): Day 1 and Day 4 intros, discovery beats, the choice scene and its tails, end cinematics, the brawl
	"cine_d1_intro": 14.0, "cine_d1_corridor": 7.5, "cine_d1_choice": 12.0, "cine_d1_choice_cover": 4.0,
	"cine_d1_choice_report": 4.5, "cine_d1": 18.0, "cine_d4_intro": 14.0, "cine_d4_stare": 10.0, "seg_d4_brawl": 25.0, "cine_d4": 18.0,
	# Phase C (C-D9): Days 2, 3, 5 intros, discovery beats, choice 2 and its tails, end cinematics, ending C, the three fights
	"cine_d2_intro": 14.0, "cine_d2": 18.0, "cine_d3_intro": 14.0, "cine_d3_mannequins": 10.0, "cine_d3": 18.0, "cine_d5_intro": 14.0,
	"cine_d5_monitors": 10.0, "cine_d5_choice": 14.0, "cine_d5_choice_accept": 4.0, "cine_d5_choice_refuse": 4.0, "cine_d5": 18.0,
	"end_c": 26.0, "seg_d2_boss": 25.0, "seg_d3_boss": 25.0, "seg_d5_boss": 25.0}
## Phase C dialogue slots (the fights have their own tests: tests/test_cine_d2_boss.gd etc.).
const C_DIALOGUE: Array[String] = ["cine_d2_intro", "cine_d2", "cine_d3_intro", "cine_d3_mannequins", "cine_d3", "cine_d5_intro",
	"cine_d5_monitors", "cine_d5_choice", "cine_d5_choice_accept", "cine_d5_choice_refuse", "cine_d5", "end_c"]
## Phase B slots whose shots are checked for an actor hidden behind another (the brawl has its own test).
const B_DIALOGUE: Array[String] = ["cine_d1_intro", "cine_d1_corridor", "cine_d1_choice", "cine_d1_choice_cover", "cine_d1_choice_report",
	"cine_d1", "cine_d4_intro", "cine_d4_stare", "cine_d4"]
const BANNED: Array[String] = ["anh ấy", "cô ấy", "cậu ấy", "chàng", "nàng", " hắn", "anh ta", "cô ta"]
## Punctuation allowed above U+2000 in UI / subtitle text (owner rule B-D11: no emoji or decorative symbols).
const ALLOWED_SYMBOLS: Array[int] = [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026]
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
	_phase_b_lines()
	_corridor_calm()
	_scare_hits()
	_cast()
	_shiba()
	_choice_overlay()
	_choice_in_cinematic()
	_villain_card()
	_screen_card()
	_occlusion()
	_fix_round()
	_phase_c_slots()
	_phase_c_scares()
	_phase_c_choice()
	_phase_c_cards()
	_phase_c_props()
	_phase_c_cast()
	# the same shots with a male (taller, spiky-haired) protagonist
	sd.call("new_story", {"female": false, "name": "Minh", "hair_style": "spiky", "variant": 0, "skin": 1, "hair_color": 0})
	_occlusion()
	sd.call("reset_state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_story_cines.cfg"))
	if fails.is_empty():
		print("✅ SUCCESS: STORY CINEMATICS (Day 0, Phase B and Phase C slots valid + in sync, reduce scares, playback, cards, video, cast, shiba, choice 1 and 2, villain cards, screen cards, occlusion, scares, props)")
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
			_check(_plain(String(sb["text"])), "%s: no emoji / decorative symbol in '%s'" % [s, String(sb["text"])])
		for sb7: int in range(1, tl.subs.size()):
			var a7: Dictionary = tl.subs[sb7 - 1]
			_check(float(tl.subs[sb7]["r"]) >= float(a7["r"]) + float(a7["dur"]) - 1e-6, "%s: subtitle '%s' does not overlap the one before" % [s, String(tl.subs[sb7]["text"])])
		for cd: Dictionary in tl.cards:
			for v: Variant in (cd["data"] as Dictionary).values():
				if v is String:
					_check(_plain(String(v)) and not BANNED.any(func(w: String) -> bool: return String(v).to_lower().contains(w)), "%s: card text '%s' is plain" % [s, String(v)])
		if not tl.choice_def.is_empty():
			var ct: String = String(tl.choice_def.get("prompt", "")) + String(tl.choice_def.get("timeout_line", ""))
			for o: Dictionary in tl.choice_def["options"]:
				ct += String(o["label"])
			_check(_plain(ct), "%s: choice texts are plain" % s)
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
	_check(scary.scare_hits.size() == 1 and absf(scary.story_time(scary.scare_hits[0]["at"]) - 10.0) < 1e-6 and scary.punches.is_empty(), "midnight: the v2 scare hit at 10.0 (the old punch is gone)")
	var lamp_s: Dictionary = scary.props.filter(func(p: Dictionary) -> bool: return p["id"] == "lamp")[0]
	var lamp_c: Dictionary = calm.props.filter(func(p: Dictionary) -> bool: return p["id"] == "lamp")[0]
	_check(not (lamp_s["opts"]["flicker"] as Array).is_empty(), "midnight: the lamp flickers by default")
	_check(not _cues_of(calm).has("violin_screech") and calm.punches.is_empty() and (lamp_c["opts"]["flicker"] as Array).is_empty(), "Giảm hù dọa: no screech, no punch, no flicker (the scare mark plays soft)")
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
		var held: int = 0
		var flick_seen: Dictionary = {}
		while done.is_empty() and n < int(tl.length * 60.0) + 30 + held:
			if p.choice_node != null:
				held += 1
				p.choice_node.pick(1)   # the choice scenes: the second option (the timeout defaults have their own checks)
				p.step(1.0 / 60.0)
				continue
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
		if s == "cine_d4_stare":
			p.seek(5.5)
			var s_in: float = p.s
			var card: CanvasLayer = p.card_nodes[0] if not p.card_nodes.is_empty() else null
			_check(card is StoryVillainCard and bool((card as StoryVillainCard).last_state.get("shown", false)) and tl.clock.speed_at(5.5) == 0.0,
				"stare: the villain card shows over a freeze frame at 5.5 s")
			p.seek(6.8)
			_check(absf(p.s - s_in) < 1e-6, "stare: story time stands still through the card")
			p.seek(8.0)
			_check(card != null and not bool((card as StoryVillainCard).last_state.get("shown", true)), "stare: the card is gone at 8.0 s")
		if s == "cine_d1_intro" or s == "cine_d1":
			var sc: CanvasLayer = p.card_nodes[0] if not p.card_nodes.is_empty() else null
			p.seek(5.0)
			_check(sc is StoryScreenCard and bool((sc as StoryScreenCard).last_state.get("shown", false)), "%s: the screen card shows at 5.0 s" % s)
			p.seek(13.0)
			_check(sc != null and not bool((sc as StoryScreenCard).last_state.get("shown", true)), "%s: the screen card is gone at 13.0 s" % s)
		if s == "cine_d1_corridor":
			var dog: StoryShiba = (p.prop_nodes["dog"] as Node3D).get_meta("shiba")
			p.seek(5.0)
			var n0: Vector3 = dog.nose_world()
			p.seek(5.6)
			var n1: Vector3 = dog.nose_world()
			var hero_calf: Vector3 = (p.actors["hero"] as CineActor).bone_world("LowerLeg.R")
			print("  corridor bonk: nose moved %.2f m, %.2f m from the protagonist's calf (xz)" % [n0.distance_to(n1), Vector2(n1.x, n1.z).distance_to(Vector2(hero_calf.x, hero_calf.z))])
			# a real surface contact: the dog's head boxes meet the leg capsules (gap 0..0.05 m) and never sink in
			p.seek(5.6)
			var g_hit: float = _bonk_gap(p, dog)
			var g_min: float = INF
			var rr2: float = 5.3
			while rr2 <= 6.2:
				p.seek(rr2)
				g_min = minf(g_min, _bonk_gap(p, dog))
				rr2 += 1.0 / 60.0
			print("  corridor bonk: head-to-leg surface gap %.3f m at the hit, smallest %.3f m" % [g_hit, g_min])
			_check(g_hit >= -0.005 and g_hit <= 0.05 and g_min >= -0.02, "corridor: the bonk lands on the calf surface (gap %.3f at the hit, min %.3f)" % [g_hit, g_min])
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


# ---------------------------------------------------------------------------
# Phase B (spec B-D8 / B-D9 / B-D10)
# ---------------------------------------------------------------------------
## No emoji / decorative symbol: every code point above U+2000 must be plain punctuation (dashes, quotes, the ellipsis).
func _plain(t: String) -> bool:
	for i: int in t.length():
		var c: int = t.unicode_at(i)
		if c >= 0x2000 and not ALLOWED_SYMBOLS.has(c):
			return false
	return true


func _said(slot: String) -> String:
	var tl: CineTimeline = CineTimeline.load_slot(slot)
	var out: String = ""
	for sb: Dictionary in tl.subs:
		out += String(sb["text"]) + "|"
	return out


func _phase_b_lines() -> void:
	var d1i: CineTimeline = CineTimeline.load_slot("cine_d1_intro")
	_check(_said("cine_d1_intro").contains("Camera bãi xe D1") and d1i.cards.size() == 1 and String(d1i.cards[0]["data"]["kind"]) == "cctv",
		"d1 intro: Mr.T replays the D1 parking CCTV (screen card)")
	var d1: CineTimeline = CineTimeline.load_slot("cine_d1")
	_check(String(d1.cards[0]["data"]["sender"]) == "Sói Xám" and String(d1.cards[0]["data"]["text"]).contains("Nguyễn Xiển")
		and d1.sfx.filter(func(e: Dictionary) -> bool: return String(e["cue"]) == "engine_roar").size() >= 2,
		"cine_d1: the courier's phone says 'Sói Xám: hàng đêm nay ở Nguyễn Xiển', engines roar")
	var ch: CineTimeline = CineTimeline.load_slot("cine_d1_choice")
	var labels: Array = (ch.choice_def["options"] as Array).map(func(o: Dictionary) -> String: return String(o["label"]))
	_check(String(ch.choice_def["id"]) == "phuc" and labels == ["Che giấu cho Phúc", "Báo Mr.T"] and String(ch.choice_def["honest"]) == "cover"
		and float(ch.choice_def["r"]) <= ch.length, "choice 1: Che giấu cho Phúc / Báo Mr.T, honest default = cover")
	_check(_said("cine_d1_choice").contains("Tao mua tool rồi") and _said("cine_d1_choice_cover").contains("Hai tô")
		and _said("cine_d1_choice_report").contains("Alo, thầy ạ"), "Phúc confesses; both branch tails exist")
	var d4i: CineTimeline = CineTimeline.load_slot("cine_d4_intro")
	_check(d4i.props.any(func(pr: Dictionary) -> bool: return String(pr["kind"]) == "flyer") and d4i.actors.has("linh") and d4i.actors.has("phuc")
		and _said("cine_d4_intro").contains("Phúc!!!"), "d4 intro: Linh's plan and the flyer gag with Phúc")
	var st: CineTimeline = CineTimeline.load_slot("cine_d4_stare")
	var vc: Dictionary = st.cards[0]["data"]
	_check(String(vc["name"]) == "Cừu Dolly" and String(vc["nick"]) == "trùm thi hộ" and String(vc["wrong_line"]) == "…à nhầm, con kia",
		"stare: villain card Cừu Dolly - trùm thi hộ, '…à nhầm, con kia'")
	_check(_said("cine_d4").contains("10.13.0.7") and _said("cine_d4").contains("Thứ Năm"), "cine_d4: Dolly spills the schedule and the server")
	for s: String in SLOTS.keys():
		if s.begins_with("cine_d1") or s.begins_with("cine_d4") or s == "seg_d4_brawl":
			var tl: CineTimeline = CineTimeline.load_slot(s)
			_check(tl.stage.get("at") is Vector2 and tl.stage.has("landmark"), "%s: staged at an explicit map point with a landmark fallback" % s)
			var dlg: Array = tl.subs.filter(func(sb: Dictionary) -> bool: return String(sb["speaker"]) == "hero")
			for sb2: Dictionary in dlg:
				_check(not String(sb2["text"]).contains("{name}"), "%s: {name} formatted" % s)
	var flyer: Node3D = CineFX.build_prop("flyer")
	var head: Label3D = flyer.find_child("Headline", true, false) as Label3D
	_check(head != null and head.text == "THI HỘ\nBAO ĐẬU", "the flyer prop reads THI HỘ BAO ĐẬU")
	flyer.free()


## "Giảm hù dọa" on the corridor beat: no stutter, no blackout, no punch, no buzz; the figure leaves off-screen.
func _corridor_calm() -> void:
	var was: bool = bool(fx.get("reduce_scares"))
	fx.set("reduce_scares", false)
	var scary: CineTimeline = CineTimeline.load_slot("cine_d1_corridor")
	fx.set("reduce_scares", true)
	var calm: CineTimeline = CineTimeline.load_slot("cine_d1_corridor")
	fx.set("reduce_scares", was)
	var cs: Dictionary = scary.props.filter(func(p: Dictionary) -> bool: return p["id"] == "corridor")[0]["opts"]
	var cc: Dictionary = calm.props.filter(func(p: Dictionary) -> bool: return p["id"] == "corridor")[0]["opts"]
	_check(not (cs["flicker"] as Array).is_empty() and not (cs["dark"] as Array).is_empty() and scary.scare_hits.size() == 1
		and _cues_of(scary).has("fluoro_buzz"), "corridor: stutter, blackout, the v2 scare hit and tube buzz by default")
	_check((cc["flicker"] as Array).is_empty() and (cc["dark"] as Array).is_empty() and calm.punches.is_empty() and not _cues_of(calm).has("fluoro_buzz"),
		"corridor, Giảm hù dọa: no stutter, no blackout, no punch, no buzz")
	_check(calm.validate().is_empty() and _cues_of(calm).has("bonk") and _cues_of(calm).has("sheep_bleat_distorted"), "the calm corridor still validates, keeps the bleat and the bonk")
	var gone: float = calm.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "show" and c["actor"] == "sheep" and not bool(c["on"]))[0]["s"]
	var s3: Dictionary = calm.shots.filter(func(sh: Dictionary) -> bool: return sh["id"] == "S3")[0]
	_check(float(s3["s"]) > gone, "calm: the corridor view comes back only after the figure has gone (no pop in view)")


## Jump scare v2 in the cinematics (CineScare): the mark, the duck then the +8 dB sting, the inhale, the flash / red frames /
## overlay and their cleanup, the FOV punch and the twitch, everything back after the end and after a skip mid-scare; the
## reduced soft variant.
func _scare_hits() -> void:
	var was: bool = bool(fx.get("reduce_scares"))
	fx.set("reduce_scares", false)
	var world := Node3D.new()
	world.name = "ScareWorld"
	root.add_child(world)
	var tl: CineTimeline = CineTimeline.load_slot("cine_d0_midnight")
	var p := CinePlayer.new()
	world.add_child(p)
	_check(p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false}).is_empty() and p.scare != null, "scare: the midnight player has its CineScare")
	var rh: float = tl.clock.real_at(10.0)
	p.start()
	p.seek(rh - 0.6)
	var sc: CineScare = p.scare
	var duck_before: float = -1.0
	var inhale_before: bool = false
	var hit_r: float = -1.0
	var ov_hit: Dictionary = {}
	var ov1: Dictionary = {}
	var ov2: Dictionary = {}
	var ov3: Dictionary = {}
	var fov_min: float = 999.0
	var base_fov: float = 46.0
	var twitched: bool = false
	var k: int = 0
	var phuc: CineActor = p.actors["phuc"]
	while p.r < rh + 1.5:
		var before: int = sc.fired.size()
		p.step(1.0 / 60.0)
		if before == 0 and sc.fired.size() == 1:
			hit_r = sc.fired[0]
			duck_before = sc.duck_at(hit_r - 0.01)
			inhale_before = sc.played.has("gasp") and sc.played.find("gasp") < sc.played.find("violin_screech")
			ov_hit = sc.face_fx.overlay_visible()
			k = 1
		elif k >= 1 and k <= 3:
			if k == 1:
				ov1 = sc.face_fx.overlay_visible()
			elif k == 2:
				ov2 = sc.face_fx.overlay_visible()
			else:
				ov3 = sc.face_fx.overlay_visible()
			k += 1
		if hit_r > 0.0 and p.r < hit_r + 0.5:
			fov_min = minf(fov_min, p.camera.fov)
			twitched = twitched or not phuc.spin.rotation.is_zero_approx()
	_check(absf(hit_r - rh) < 0.02, "scare: the hit fires at its mark (%.3f vs %.3f)" % [hit_r, rh])
	_check(duck_before > 0.9 and inhale_before, "scare: the music and SFX duck to silence before it, a sharp inhale just before (%.2f)" % duck_before)
	_check(sc.last_sting.get("cues", []).has("sub_boom") and is_equal_approx(sc.sting_volume_db(0), ScareDirector.STING_BOOST_DB)
		and is_equal_approx(sc.sting_volume_db(2), ScareDirector.STING_BOOST_DB), "scare: then the +8 dB layered sting with the sub boom (%s)" % str(sc.last_sting))
	_check(ov_hit.get("flash", false) and ov_hit.get("aber", false) and ov1.get("red", false) and ov2.get("red", false) and not ov3.get("red", true),
		"scare: one white frame, two red frames, the overlay on (%s %s %s %s)" % [str(ov_hit), str(ov1), str(ov2), str(ov3)])
	_check(fov_min < base_fov - 12.0 and twitched, "scare: the FOV punches in (%.1f) and Phúc's face twitches through the hold" % fov_min)
	_check(sc.screen_idle() and is_equal_approx(p.camera.fov, base_fov) and p.camera.h_offset == 0.0 and p.camera.v_offset == 0.0 and phuc.spin.rotation.is_zero_approx(),
		"scare: the overlay, the shake, the FOV punch and the twitch are over a second later")
	_check(absf(sc.duck_at(p.r)) < 0.01, "scare: the audio levels are back")
	p.queue_free()
	# a skip in the middle of the scare: the overlay is freed, the camera comes back
	var tl2: CineTimeline = CineTimeline.load_slot("cine_d1_corridor")
	var p2 := CinePlayer.new()
	world.add_child(p2)
	p2.setup(tl2, Transform3D.IDENTITY, {"manual": true, "music": false})
	var rh2: float = tl2.clock.real_at(3.5)
	var done: Array = []
	p2.finished.connect(func(sk: bool) -> void: done.append(sk))
	p2.start()
	p2.seek(rh2 - 0.5)
	while p2.r < rh2 + 0.05:
		p2.step(1.0 / 60.0)
	var sheep: CineActor = p2.actors["sheep"]
	_check(p2.scare.fired.size() == 1 and p2.camera.fov < 40.0 - 3.0, "corridor: the scare hits as the tubes come back (fov %.1f)" % p2.camera.fov)
	_check(Vector2(sheep.position.x - 0.3, sheep.position.z - 0.9).length() < 2.2, "corridor: the figure is right in front of the camera")
	var held_scare: bool = false
	for h: Dictionary in tl2.cues:
		if h["type"] == "hold" and h["actor"] == "sheep" and String(h["kind"]) == "scare_mask":
			held_scare = float(h["s"]) <= 3.5 and float(h["s1"]) >= 3.9
	_check(held_scare, "corridor: the scare mask on the figure through the scare")
	p2._skipping = 0.0   # the skip fade starts now: it ends 0.25 s later, in the middle of the punch and the shake
	var n: int = 0
	while done.is_empty() and n < 200:
		p2.step(1.0 / 60.0)
		n += 1
	_check(done == [true] and p2.scare.layer == null and p2.scare.screen_idle() and p2.camera.h_offset == 0.0 and p2.camera.v_offset == 0.0
		and absf(p2.camera.fov - 40.0) < 0.5 and p2._fov_off == 0.0, "skip mid-scare: the overlay is freed, the camera offsets and FOV come back (fov %.1f)" % p2.camera.fov)
	p2.queue_free()
	# "Giảm hù dọa": the soft variant
	fx.set("reduce_scares", true)
	var tl3: CineTimeline = CineTimeline.load_slot("cine_d0_midnight")
	var p3 := CinePlayer.new()
	world.add_child(p3)
	p3.setup(tl3, Transform3D.IDENTITY, {"manual": true, "music": false})
	p3.start()
	p3.seek(tl3.clock.real_at(10.0) - 0.6)
	var max_duck: float = 0.0
	var fov_lo: float = 999.0
	while p3.r < tl3.clock.real_at(10.0) + 1.0:
		p3.step(1.0 / 60.0)
		max_duck = maxf(max_duck, p3.scare.duck_at(p3.r))
		fov_lo = minf(fov_lo, p3.camera.fov)
	_check(p3.scare.soft and p3.scare.fired.size() == 1 and max_duck == 0.0 and p3.scare.face_fx == null and p3.scare.last_sting.is_empty()
		and p3.scare.played == ["metal_creak"] and fov_lo >= 46.0 - 0.01 and p3.camera.h_offset == 0.0,
		"reduced: a soft sting only, no duck, flash, overlay, shake, FOV punch or boom (%s)" % str(p3.scare.played))
	p3.queue_free()
	world.queue_free()
	fx.set("reduce_scares", was)


func _cast() -> void:
	for id: String in StoryCast.IDS:
		var o: Dictionary = StoryCast.opts(id)
		_check(id in StoryCast.NOT_PEOPLE or not o.is_empty(), "cast %s has opts" % id)
		var b: Node3D = StoryCast.build(id)
		_check(b != null, "cast %s builds" % id)
		if b == null:
			continue
		if id == "shiba":
			_check(b is StoryShiba, "shiba builds a StoryShiba")
		elif id == "mannequins":
			_check(b is CineCrowd and (b as CineCrowd).count() >= 40, "mannequins build a CineCrowd")
		else:
			_check(bool(b.get_meta("rigged", false)), "cast %s is a rigged body" % id)
			_check(b.has_meta("sheep_mask") == StoryCast.masked(id), "cast %s: sheep mask %s" % [id, str(StoryCast.masked(id))])
		if id == "dolly_disguised":
			_check(b.has_meta("wool_cuff") and b.has_meta("sheep_keychain"), "Dolly in disguise has her tells (cuff, keychain)")
		b.free()
	_check(StoryCast.opts("clone") == StoryCast.opts("clone", {"seed": 9}) and StoryCast.opts("clone") == StoryCast.opts("dolly_disguised"),
		"one identical clone look (seed pinned), Dolly in disguise wears it too")
	var dl: Dictionary = StoryCast.opts("dolly")
	_check((dl["shirt_color"] as Color).is_equal_approx(StoryCast.CREAM), "Dolly's cream wool cardigan")
	var li: Dictionary = StoryCast.opts("linh")
	_check(String(li["preset"]) == "student_f" and String(li["hair_style"]) == "ponytail" and bool(li["glasses"]), "Linh: student_f, ponytail, glasses")
	_check(String(StoryCast.opts("chu_bay")["preset"]) == "guard", "Chú Bảy: guard preset (cap)")
	var hc: Array = ["courier_vang", "courier_do", "courier_xanh"].map(func(i: String) -> String: return (StoryCast.opts(i)["helmet_color"] as Color).to_html(false))
	_check(hc == ["f1c40f", "e74c3c", "3498db"], "couriers Mũ Vàng / Mũ Đỏ / Mũ Xanh helmets (%s)" % str(hc))
	_check(StoryCast.speaker("chu_bay") == "Chú Bảy" and StoryCast.speaker("dolly") == "Cừu Dolly" and StoryCast.speaker("hero") == "Minh Thư",
		"cast speaker names")


func _shiba() -> void:
	var dog := StoryShiba.new()
	root.add_child(dog)
	dog.pose("bonk", 0.0)
	var z0: float = dog.to_local(dog.nose_world()).z
	dog.pose("bonk", StoryShiba.BONK_HIT)
	var z1: float = dog.to_local(dog.nose_world()).z
	dog.pose("bonk", StoryShiba.BONK_DUR)
	var z2: float = dog.to_local(dog.nose_world()).z
	_check(z0 - z1 > 0.15 and absf(z2 - z0) < 0.03, "shiba bonk: the head lunges forward at BONK_HIT (%.2f m) and comes back" % (z0 - z1))
	dog.pose("walk", 0.1)
	var l0: float = dog.legs[0].rotation.x
	dog.pose("walk", 0.1 + StoryShiba.WALK_PERIOD * 0.5)
	_check(absf(l0 - dog.legs[0].rotation.x) > 0.5, "shiba walk: the legs swing")
	dog.cine_eval(1.0 + StoryShiba.BONK_HIT, {"anim": [[0.0, "walk"], [1.0, "bonk"]]})
	_check(dog.body.position.z < -0.15, "shiba cine_eval plays the keyed motion (bonk at its hit)")
	dog.queue_free()


func _choice_def() -> Dictionary:
	return (CineTimeline.load_slot("cine_d1_choice").choice_def as Dictionary).duplicate(true)


## The overlay alone: freezes the tree, keyboard pick, layout widths, pause state restored.
func _choice_overlay() -> void:
	paused = false
	var got: Array = []
	var c: StoryChoice = StoryChoice.open(root, _choice_def(), true)
	c.chosen.connect(func(k: String, t: bool) -> void: got.append([k, t]))
	_check(paused, "StoryChoice freezes the frame (tree paused)")
	_check(c.prompt_label.get_combined_minimum_size().x >= 700.0 and c.buttons.size() == 2
		and c.buttons.all(func(b: Button) -> bool: return b.get_combined_minimum_size().x >= 330.0)
		and c.title_label.get_combined_minimum_size().x > 100.0 and c.hint_label.get_combined_minimum_size().x > 200.0,
		"choice layout: prompt, buttons and hints keep their width (no one-letter lines)")
	_check(c.buttons[0].text == "Che giấu cho Phúc" and c.buttons[1].text == "Báo Mr.T" and _plain(c.prompt_label.text + c.hint_label.text),
		"choice buttons read the two options in plain text")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_2
	ev.pressed = true
	c._input(ev)
	_check(c.result == "report" and not c.timed_out, "key 2 picks 'Báo Mr.T'")
	c.step(StoryChoice.PICK_HOLD + 0.05)
	_check(got == [["report", false]] and not paused, "the pick is emitted after the highlight and the pause state comes back (%s)" % str(got))
	# mouse: a button press picks too
	var got2: Array = []
	var c2: StoryChoice = StoryChoice.open(root, _choice_def(), true)
	c2.chosen.connect(func(k: String, t: bool) -> void: got2.append([k, t]))
	c2.buttons[0].pressed.emit()
	c2.step(1.0)
	_check(got2 == [["cover", false]], "clicking the first button picks 'Che giấu cho Phúc'")
	# timeout: the honest option with the comic line, recorded in StoryDirector.choices
	(sd.get("choices") as Dictionary)["phuc"] = ""
	var got3: Array = []
	var c3: StoryChoice = StoryChoice.open(root, _choice_def(), true)
	c3.chosen.connect(func(k: String, t: bool) -> void: got3.append([k, t]))
	for i: int in 600:
		c3.step(1.0 / 60.0)
	_check(c3.result == "cover" and c3.timed_out and c3.line_label.visible and c3.line_label.text.contains("Phúc"), "timeout after 10 s takes the honest option with the comic line")
	_check(got3.is_empty(), "the comic line holds before the overlay closes")
	c3.step(c3.line_hold() + 0.05)
	_check(got3 == [["cover", true]] and String((sd.get("choices") as Dictionary)["phuc"]) == "cover" and not paused,
		"timeout default recorded: StoryDirector.choices.phuc = cover")


## Inside the cinematic: the clock holds at the choice time, the music pauses, choice_made fires, then it plays on to 12 s.
func _choice_in_cinematic() -> void:
	(sd.get("choices") as Dictionary)["phuc"] = ""
	var world := Node3D.new()
	root.add_child(world)
	var tl: CineTimeline = CineTimeline.load_slot("cine_d1_choice")
	var p := CinePlayer.new()
	world.add_child(p)
	p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	var made: Array = []
	var done: Array = []
	p.choice_made.connect(func(id: String, k: String, t: bool) -> void: made.append([id, k, t]))
	p.finished.connect(func(sk: bool) -> void: done.append(sk))
	p.start()
	var n: int = 0
	var held: int = 0
	var r_at_open: float = -1.0
	while done.is_empty() and n < 2000:
		p.step(1.0 / 60.0)
		n += 1
		if p.choice_node != null:
			held += 1
			if r_at_open < 0.0:
				r_at_open = p.r
	_check(absf(r_at_open - float(tl.choice_def["r"])) < 1e-6, "the frame holds at the choice time %.3f (%.3f)" % [float(tl.choice_def["r"]), r_at_open])
	_check(made == [["phuc", "cover", true]] and done == [false] and absf(p.r - tl.length) < 1e-6, "no answer: choice_made(phuc, cover, timed out), then the cinematic ends at 12 s (%s)" % str(made))
	var want_held: int = int(round((StoryChoice.TIMEOUT + maxf(StoryChoice.LINE_HOLD, 0.06 * String(tl.choice_def["timeout_line"]).length())) * 60.0))
	_check(absi(held - want_held) <= 2 and absi((n - held) - 720) <= 2, "held %d steps for the choice (~%d), %d steps of cinematic" % [held, want_held, n - held])
	# skipped before the choice: it is still asked, then finished(true)
	var p2 := CinePlayer.new()
	world.add_child(p2)
	p2.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	var made2: Array = []
	var done2: Array = []
	p2.choice_made.connect(func(id: String, k: String, t: bool) -> void: made2.append(k))
	p2.finished.connect(func(sk: bool) -> void: done2.append(sk))
	p2.start()
	p2.force_skip_hold = true
	var m: int = 0
	while done2.is_empty() and m < 400:
		p2.step(1.0 / 60.0)
		if p2.choice_node != null:
			p2.choice_node.pick(1)
		m += 1
	_check(made2 == ["report"] and done2 == [true], "a skip before the choice still asks it, then finishes skipped (%s, %s)" % [str(made2), str(done2)])
	world.queue_free()
	paused = false


func _villain_card() -> void:
	var st: CineTimeline = CineTimeline.load_slot("cine_d4_stare")
	var cd: Dictionary = st.cards[0]
	var data: Dictionary = cd["data"]
	var pw: Vector2 = data["point_wrong"]
	var pr: Vector2 = data["point_right"]
	_check(pw.x > 0.05 and pw.x < 0.95 and pr.x > 0.05 and pr.x < 0.95 and pw.y > 0.05 and pr.y < 0.9 and pw.x < pr.x,
		"the arrow points inside the frame, at the wrong clone (left) then at Dolly (%s -> %s)" % [str(pw), str(pr)])
	var a: Dictionary = StoryVillainCard.state_at(0.3, true, 0.45)
	var b: Dictionary = StoryVillainCard.state_at(0.8, true, 0.45)
	_check(float(a["pointer"]) == 0.0 and bool(a["wrong_line"]) and float(b["pointer"]) == 1.0 and not bool(b["wrong_line"]),
		"pointer at the wrong clone first with '…à nhầm, con kia', then on Dolly")
	_check(not bool(StoryVillainCard.state_at(-0.1, true)["shown"]) and not bool(StoryVillainCard.state_at(1.0, true)["shown"]), "card only inside its window")
	var vc := StoryVillainCard.new()
	vc.data = data
	vc.r0 = float(cd["r"])
	vc.dur = float(cd["dur"])
	root.add_child(vc)
	vc.update(vc.r0 + vc.dur * 0.5)
	_check(vc.name_label.text == "CỪU DOLLY" and vc.name_label.get_combined_minimum_size().x > 300.0 and vc.nick_label.get_combined_minimum_size().x > 150.0
		and vc.joke_label.get_combined_minimum_size().x >= 600.0 and vc.wrong_label.get_combined_minimum_size().x > 150.0,
		"villain card layout keeps its width: name %.0f, nick %.0f, joke %.0f px" % [vc.name_label.get_combined_minimum_size().x,
		vc.nick_label.get_combined_minimum_size().x, vc.joke_label.get_combined_minimum_size().x])
	_check(vc.wash.visible and vc.wash.color.a > 0.2 and vc.box.visible, "colour wash and text shown mid-card")
	vc.queue_free()
	# gameplay: show_for pauses, then frees itself and gives the pause back
	paused = false
	var fin: Array = []
	var g := StoryVillainCard.show_for(root, data, 1.0)
	g.manual = true
	g.finished.connect(func() -> void: fin.append(true))
	_check(paused, "show_for freezes the game")
	g.step(1.1)
	_check(fin == [true] and not paused, "show_for ends, unpauses")


func _screen_card() -> void:
	_check(StoryScreenCard.clock_at("21:47:05", 75.4) == "21:48:20" and StoryScreenCard.clock_at("23:59:50", 15.0) == "00:00:05", "CCTV clock runs on")
	var st: Dictionary = StoryScreenCard.state_at(3.0, 2.0, 4.0)
	_check(bool(st["shown"]) and is_equal_approx(float(st["u"]), 0.25) and not bool(StoryScreenCard.state_at(6.5, 2.0, 4.0)["shown"]), "screen card window")
	for kind: String in ["cctv", "phone"]:
		var sc := StoryScreenCard.new()
		sc.data = {"kind": kind, "sender": "Sói Xám", "text": "Hàng đêm nay ở Nguyễn Xiển. 2h. Đừng trễ.", "time": "23:41"}
		sc.r0 = 1.0
		sc.dur = 4.0
		root.add_child(sc)
		sc.update(2.5)
		_check(sc.frame.visible and sc.screen.get_combined_minimum_size().x >= 300.0, "%s card shows" % kind)
		if kind == "phone":
			_check(sc.text_label.get_combined_minimum_size().x >= 250.0 and sc.sender_label.text == "Sói Xám", "phone card: message keeps its width")
		else:
			_check(sc.head_label.text.contains("BÃI XE D1") and sc.clock_label.text != "", "cctv card: camera name and clock")
		sc.update(9.0)
		_check(not sc.frame.visible, "%s card hidden after its window" % kind)
		sc.queue_free()


## No actor hidden behind another in any shot: at the middle of every shot, the line from the camera to each visible
## actor's head (in frame) must not pass within OCCLUDE_R of a nearer actor's head or chest.
const OCCLUDE_R: float = 0.2


func _occlusion() -> void:
	var world := Node3D.new()
	root.add_child(world)
	for s: String in B_DIALOGUE + C_DIALOGUE:
		var tl: CineTimeline = CineTimeline.load_slot(s)
		var p := CinePlayer.new()
		world.add_child(p)
		p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
		for i: int in tl.shots.size():
			var r0: float = tl.clock.real_at(float(tl.shots[i]["s"]))
			var r1: float = tl.clock.real_at(float(tl.shots[i + 1]["s"])) if i + 1 < tl.shots.size() else tl.length
			for rr: float in [lerpf(r0, r1, 0.3), lerpf(r0, r1, 0.7)]:
				p.seek(rr)
				var cam: Vector3 = p.camera.global_position
				var fwd: Vector3 = -p.camera.global_transform.basis.z
				var bad: String = ""
				var extras: Variant = tl.get("extras")   # background extras may be covered (they still count as occluders)
				for ida: String in p.actors.keys():
					var a: CineActor = p.actors[ida]
					if not a.visible or (extras is Array and (extras as Array).has(ida)):
						continue
					var ha: Vector3 = a.bone_world("Head")
					var d: Vector3 = ha - cam
					if d.normalized().dot(fwd) < cos(deg_to_rad(p.camera.fov * 0.5 * 1.6)):
						continue   # out of frame
					for idb: String in p.actors.keys():
						var b: CineActor = p.actors[idb]
						if idb == ida or not b.visible:
							continue
						for bone: String in ["Head", "Chest"]:
							var q: Vector3 = b.bone_world(bone)
							var t: float = (q - cam).dot(d) / d.length_squared()
							if t <= 0.05 or t >= 0.92:
								continue   # behind the camera, or not nearer than the target
							if (cam + d * t).distance_to(q) < OCCLUDE_R:
								bad = "%s's %s hides %s's face" % [idb, bone, ida]
				_check(bad == "", "%s shot %s at r %.2f: %s" % [s, String(tl.shots[i]["id"]), rr, bad])
		p.queue_free()
	world.queue_free()


const Bodies = preload("res://tests/support/cine_bodies.gd")


## Surface gap from the shiba's head boxes (skull, cheeks, snout, nose) to the protagonist's leg capsules.
func _bonk_gap(p: CinePlayer, dog: StoryShiba) -> float:
	var boxes: Array = []
	for n: String in ["Skull", "Cheeks", "Snout", "Nose"]:
		var mi: MeshInstance3D = dog.head.find_child(n, false, false) as MeshInstance3D
		var ab: AABB = mi.mesh.get_aabb()
		var gx: Transform3D = mi.global_transform
		boxes.append([n, Transform3D(gx.basis.orthonormalized(), gx * ab.get_center()), ab.size * gx.basis.get_scale() * 0.5])
	var legs: Array = Bodies.capsules(p.actors["hero"]).filter(func(c: Array) -> bool: return String(c[0]).begins_with("shin") or String(c[0]).begins_with("thigh"))
	return float(Bodies.gap_boxes(legs, boxes)["g"])


## Fix-round checks (review B-cine): sets inside their stage boxes, drop_set, the card freeze row (no code music, H-D8), Dolly's tells,
## the card band clear of the clones, reading time of the card and of the timeout line, choice_made before finished,
## record: false.
func _fix_round() -> void:
	# the corridor set and the sheep sit inside the 4.5 x 16 stage box; the set is closed at both ends
	var co: CineTimeline = CineTimeline.load_slot("cine_d1_corridor")
	var half: Vector2 = (co.stage["size"] as Vector2) * 0.5
	var set_node: Node3D = CineFX.build_prop("corridor", co.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "corridor")[0]["opts"])
	var worst: float = -INF
	for n: Node in set_node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var ab: AABB = mi.transform * mi.mesh.get_aabb()
		worst = maxf(worst, maxf(absf(ab.position.x), absf(ab.end.x)) - half.x)
		worst = maxf(worst, maxf(absf(ab.position.z), absf(ab.end.z)) - half.y)
	_check(worst <= 0.0 and set_node.find_child("BackWall", true, false) != null, "corridor set inside its stage box (margin %.2f m), closed at +Z" % -worst)
	set_node.free()
	var sheep_at: Vector3 = co.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "key" and c["actor"] == "sheep")[0]["pos"]
	_check(absf(sheep_at.z) < half.y - 0.5, "the sheep figure stands inside the stage box (z %.1f)" % sheep_at.z)
	var s5: Dictionary = co.shots.filter(func(sh: Dictionary) -> bool: return sh["id"] == "S5")[0]
	_check(absf(((s5["params"] as Dictionary)["pos"] as Vector3).x) < 1.5, "corridor S5 camera inside the walls")
	# drop_set leaves the carried corridor out (setup opt or stage flag)
	var world := Node3D.new()
	root.add_child(world)
	var pc := CinePlayer.new()
	world.add_child(pc)
	_check(pc.setup(co, Transform3D.IDENTITY, {"manual": true, "music": false, "drop_set": true}).is_empty() and not pc.prop_nodes.has("corridor")
		and pc.prop_nodes.has("dog"), "drop_set: the corridor walls are left out, the dog stays")
	var co2: CineTimeline = CineTimeline.load_slot("cine_d1_corridor")
	co2.stage["drop_set"] = true
	var pc2 := CinePlayer.new()
	world.add_child(pc2)
	pc2.setup(co2, Transform3D.IDENTITY, {"manual": true, "music": false})
	_check(not pc2.prop_nodes.has("corridor"), "the stage flag drop_set does the same")
	var d4: CineTimeline = CineTimeline.load_slot("cine_d4")
	var pc3 := CinePlayer.new()
	world.add_child(pc3)
	pc3.setup(d4, Transform3D.IDENTITY, {"manual": true, "music": false})
	_check(pc3.prop_nodes.has("wall") and (d4.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "wall")[0]["pos"] as Vector3).z < -3.2,
		"cine_d4: a lobby wall stands behind Dolly")
	# H-D8: no synthesized cue any more, so no music hit layout either; the villain card freeze stays a ramp row
	var st: CineTimeline = CineTimeline.load_slot("cine_d4_stare")
	var probe := CinePlayer.new()
	_check(probe.has_method("setup") and not probe.has_method("music_hits"), "CinePlayer has no synthesized-cue hit layout (no code music)")
	probe.free()
	_check(st.clock.beat_rows().any(func(row: Dictionary) -> bool: return String(row["preset"]) == "card"), "cine_d4_stare keeps its card freeze row")
	# Dolly's tells on the cinematic Dolly; the protagonist does not single her out before the card
	var tells: Array = st.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "hold" and c["actor"] == "dolly" and String(c["kind"]) in ["wool_cuff", "sheep_keychain"])
	_check(tells.size() == 2, "cine_d4_stare: the real Dolly shows the cuff and the keychain")
	var pre: Array = st.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "look" and c["actor"] == "hero" and float(c["s"]) < st.story_time("V1") - 1e-6)
	_check(pre.all(func(c: Dictionary) -> bool: return not (c["target"] is Vector3) or absf((c["target"] as Vector3).x) < 0.3), "the protagonist does not single out Dolly before the card")
	# reading time: the card (name + nick + joke) and the timeout line at >= 0.06 s per character
	var cd: Dictionary = st.cards[0]
	var dd: Dictionary = cd["data"]
	var chars: int = String(dd["name"]).length() + String(dd["nick"]).length() + String(dd["joke"]).length()
	_check(float(cd["dur"]) >= 0.06 * chars - 1e-6, "villain card %.1f s for %d characters" % [float(cd["dur"]), chars])
	var cdef: Dictionary = _choice_def()
	var ch := StoryChoice.open(root, cdef, true)
	_check(ch.line_hold() >= 0.06 * String(cdef["timeout_line"]).length() - 1e-6, "timeout line holds %.2f s (>= 0.06 s per character)" % ch.line_hold())
	ch.queue_free()
	paused = false
	# the band and the text stay in the lower left, clear of the clones and of Dolly, above the letterbox
	var vc := StoryVillainCard.new()
	vc.data = dd
	vc.r0 = 0.0
	vc.dur = float(cd["dur"])
	root.add_child(vc)
	vc.update(vc.dur * 0.5)
	var vs: Vector2 = vc._vp()
	var bx: float = 0.0
	var by: float = 1e9
	for pt: Vector2 in vc.band.polygon:
		bx = maxf(bx, pt.x)
		by = minf(by, pt.y)
	var tr: Rect2 = Rect2(vc.box.position, vc.box.get_combined_minimum_size())
	print("  card band right %.2f, top %.2f; text x %.2f-%.2f, y %.2f-%.2f (screen fractions)" % [bx / vs.x, by / vs.y, tr.position.x / vs.x,
		tr.end.x / vs.x, tr.position.y / vs.y, tr.end.y / vs.y])
	_check(bx <= 0.56 * vs.x and by >= 0.59 * vs.y and tr.end.x <= 0.56 * vs.x and tr.position.y >= 0.59 * vs.y and tr.end.y <= 0.875 * vs.y,
		"villain card band and text stay below y 0.6, left of x 0.55, above the letterbox")
	_check(vc.layer < 110, "villain card under the cinematic overlay (it fades with a skip)")
	vc.queue_free()
	# choice_made comes before finished; record: false leaves StoryDirector.choices alone
	(sd.get("choices") as Dictionary)["phuc"] = "untouched"
	var tl: CineTimeline = CineTimeline.load_slot("cine_d1_choice")
	tl.choice_def["record"] = false
	var p := CinePlayer.new()
	world.add_child(p)
	p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	var order: Array = []
	p.choice_made.connect(func(_i: String, k: String, _t: bool) -> void: order.append("choice:" + k))
	p.finished.connect(func(_sk: bool) -> void: order.append("finished"))
	p.start()
	var n2: int = 0
	while order.size() < 2 and n2 < 1600:
		p.step(1.0 / 60.0)
		if p.choice_node != null:
			p.choice_node.pick(0)
		n2 += 1
	_check(order == ["choice:cover", "finished"], "choice_made fires before finished (%s)" % str(order))
	_check(String((sd.get("choices") as Dictionary)["phuc"]) == "untouched", "record: false leaves StoryDirector.choices alone")
	world.queue_free()
	paused = false



# ---------------------------------------------------------------------------
# Phase C (spec C-D9 to C-D13)
# ---------------------------------------------------------------------------
const C_STAGES: Dictionary = {"cine_d2_intro": "duy_room", "cine_d5_intro": "duy_room", "cine_d2": "bridge", "seg_d2_boss": "bridge",
	"cine_d3_intro": "drive", "cine_d3_mannequins": "yard", "cine_d3": "yard", "seg_d3_boss": "yard", "cine_d5_monitors": "server",
	"cine_d5_choice": "server", "cine_d5_choice_accept": "server", "cine_d5_choice_refuse": "server", "cine_d5": "server", "seg_d5_boss": "server"}


## Every string in a card's data, arrays included (credits lines, flow nodes).
func _card_strings(data: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for v: Variant in data.values():
		if v is String:
			out.append(String(v))
		elif v is Array:
			for x: Variant in v:
				if x is String:
					out.append(String(x))
	return out


func _phase_c_slots() -> void:
	for s: String in SLOTS.keys():
		if not (s in C_DIALOGUE or s.begins_with("seg_d2") or s.begins_with("seg_d3") or s.begins_with("seg_d5")):
			continue
		var tl: CineTimeline = CineTimeline.load_slot(s)
		_check(tl.stage.get("at") is Vector2 and tl.stage.has("landmark") and String(tl.stage.get("tod", "")) == "night",
			"%s: staged at night at an explicit map point with a landmark fallback" % s)
		if C_STAGES.has(s):
			var want: Dictionary = CineTimeline.PHASE_C_STAGES[C_STAGES[s]]
			_check((tl.stage["at"] as Vector2).is_equal_approx(want["at"]) and (tl.stage["size"] as Vector2).x <= (want["size"] as Vector2).x + 0.01
				and (tl.stage["size"] as Vector2).y <= (want["size"] as Vector2).y + 0.01, "%s: at the measured %s spot, inside its clear box" % [s, C_STAGES[s]])
		for cd: Dictionary in tl.cards:
			for t: String in _card_strings(cd["data"]):
				_check(_plain(t) and not t.contains("…"), "%s: card text '%s' is plain ('...' not the ellipsis glyph)" % [s, t])
		for sb: Dictionary in tl.subs:
			_check(not String(sb["text"]).contains("…") and not String(sb["tr"]).contains("…"), "%s: '...' not the ellipsis glyph in '%s'" % [s, String(sb["text"])])
			_check(_plain(String(sb["tr"])), "%s: the Dịch line is plain in '%s'" % [s, String(sb["tr"])])
		_check(tl.music_slot == s, "%s: its own music slot (no synthesized default)" % s)
		var heroes: Array = tl.subs.filter(func(sb: Dictionary) -> bool: return String(sb["text"]).contains("Minh Thư"))
		for sb2: Dictionary in heroes:
			_check(float(sb2["dur"]) >= 0.06 * (String(sb2["text"]).length() + 8) - 1e-6, "%s: '%s' still reads with a 16-letter name" % [s, String(sb2["text"])])
	# Anh Duy: every line carries its Dịch translation (validator), and he speaks in all three intros
	for s2: String in ["cine_d2_intro", "cine_d3_intro", "cine_d5_intro"]:
		var t2: CineTimeline = CineTimeline.load_slot(s2)
		var duy: Array = t2.subs.filter(func(sb: Dictionary) -> bool: return t2.speaker_name(String(sb["speaker"])) == "Anh Duy")
		_check(duy.size() >= 2 and duy.all(func(sb: Dictionary) -> bool: return String(sb["tr"]).begins_with("Dịch: ")), "%s: Anh Duy's jargon lines carry Dịch: (%d)" % [s2, duy.size()])
	_check(_said("cine_d2").contains("Hàng về bến container của ngài Alexander"), "cine_d2: Sói Xám gives up the container yard of ngài Alexander")
	var d3: CineTimeline = CineTimeline.load_slot("cine_d3")
	_check(_said("cine_d3").contains("Alexander ABCXYZ") and d3.props.any(func(pr: Dictionary) -> bool: return String(pr["kind"]) == "usb")
		and d3.cues.any(func(c: Dictionary) -> bool: return c["type"] == "hold" and c["actor"] == "hero" and String(c["kind"]) == "usb"),
		"cine_d3: the endless name is cut off, the USB drops and is picked up")
	var usb: Node3D = CineFX.build_prop("usb")
	_check((usb.find_child("UsbLabel", true, false) as Label3D).text == "ZA MẪN LABS", "the USB reads ZA MẪN LABS")
	usb.free()
	_check(_said("cine_d5_intro").contains("The Beverly"), "cine_d5_intro: the server under The Beverly tower")
	var d5: CineTimeline = CineTimeline.load_slot("cine_d5")
	_check(d5.cards.size() == 1 and String(d5.cards[0]["data"]["kind"]) == "flow" and (d5.cards[0]["data"]["nodes"] as Array).has("TRÀ SỮA LỌ")
		and _said("cine_d5").contains("Trà Sữa Lọ"), "cine_d5: the money flow points to Trà Sữa Lọ")
	var ec: CineTimeline = CineTimeline.load_slot("end_c")
	_check(ec.cards.size() == 1 and String(ec.cards[0]["data"]["kind"]) == "credits" and _said("end_c").contains("CEO Lọ Thần 10.0")
		and _said("end_c").contains("Minh Thư"), "end_c: the CEO of Lọ Thần 10.0 ({name}), then the credits")
	_check(ec.props.any(func(pr: Dictionary) -> bool: return String(pr["kind"]) == "keynote" and bool(pr["opts"].get("set", false))), "end_c: the keynote set is set dressing")
	var ch: CineTimeline = CineTimeline.load_slot("cine_d5_choice")
	_check(_said("cine_d5_choice").contains("Ổn mà, mọi thứ vẫn ổn.") and _said("cine_d5_choice").contains("equity 0,01%")
		and ch.props.any(func(pr: Dictionary) -> bool: return String(pr["kind"]) == "stonks_screen"), "cine_d5_choice: the coffee among the fires, STONKS, the equity offer")


## The two v2 jump scares of Phase C: one mark each, fired at its time in a CinePlayer, the reduced soft variant.
func _phase_c_scares() -> void:
	var was: bool = bool(fx.get("reduce_scares"))
	var world := Node3D.new()
	root.add_child(world)
	for e: Array in [["cine_d3_mannequins", 1.9], ["cine_d5_monitors", 3.3]]:
		for calm: bool in [false, true]:
			fx.set("reduce_scares", calm)
			var tl: CineTimeline = CineTimeline.load_slot(String(e[0]))
			_check(tl.validate().is_empty() and tl.scare_hits.size() == 1 and absf(tl.story_time(tl.scare_hits[0]["at"]) - float(e[1])) < 1e-6,
				"%s%s: one v2 scare mark at %.1f" % [String(e[0]), " (reduced)" if calm else "", float(e[1])])
			var p := CinePlayer.new()
			world.add_child(p)
			p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
			p.start()
			var rh: float = tl.clock.real_at(float(e[1]))
			p.seek(rh - 0.6)
			while p.r < rh + 0.6:
				p.step(1.0 / 60.0)
			_check(p.scare != null and p.scare.fired.size() == 1 and absf(float(p.scare.fired[0]) - rh) < 0.02 and p.scare.soft == calm,
				"%s%s: the scare fires at %.2f (%s)" % [String(e[0]), " (reduced: soft)" if calm else "", rh, str(p.scare.fired if p.scare else [])])
			p.queue_free()
	fx.set("reduce_scares", false)
	var m: CineTimeline = CineTimeline.load_slot("cine_d3_mannequins")
	fx.set("reduce_scares", true)
	var mc: CineTimeline = CineTimeline.load_slot("cine_d3_mannequins")
	var mo: CineTimeline = CineTimeline.load_slot("cine_d5_monitors")
	fx.set("reduce_scares", was)
	var turn: float = float(m.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "crowd01")[0]["opts"]["turn_dur"])
	var turn_c: float = float(mc.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "crowd01")[0]["opts"]["turn_dur"])
	_check(turn < 0.2 and turn_c >= 0.9 and not _cues_of(mc).has("door_bang") and _cues_of(m).has("door_bang"),
		"Giảm hù dọa: the mannequin heads turn slowly (%.2f -> %.2f s), no door bangs" % [turn, turn_c])
	_check(not mo.shots.any(func(sh: Dictionary) -> bool: return ((sh["params"] as Dictionary).get("pos", Vector3.ZERO) as Vector3).z < -3.5),
		"Giảm hù dọa: no close snap on a monitor face in cine_d5_monitors")
	world.queue_free()


## Choice 2: the options, the honest default on timeout (recorded), both tails.
func _phase_c_choice() -> void:
	var tl: CineTimeline = CineTimeline.load_slot("cine_d5_choice")
	var labels: Array = (tl.choice_def["options"] as Array).map(func(o: Dictionary) -> String: return String(o["label"]))
	var keys: Array = (tl.choice_def["options"] as Array).map(func(o: Dictionary) -> String: return String(o["key"]))
	_check(String(tl.choice_def["id"]) == "za_man" and labels == ["Nhận lời", "Từ chối"] and keys == ["accept", "refuse"]
		and String(tl.choice_def["honest"]) == "refuse" and absf(float(tl.choice_def["r"]) - 13.6) < 1e-6,
		"choice 2: Nhận lời / Từ chối at 13.6 s, honest default = refuse")
	var ct: String = String(tl.choice_def["prompt"]) + String(tl.choice_def["timeout_line"]) + String(tl.choice_def.get("title", ""))
	_check(_plain(ct) and not ct.contains("…"), "choice 2 texts are plain")
	var choices: Dictionary = sd.get("choices")
	var had: bool = choices.has("za_man")
	var old: Variant = choices.get("za_man", "")
	choices["za_man"] = ""
	var world := Node3D.new()
	root.add_child(world)
	var p := CinePlayer.new()
	world.add_child(p)
	p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	var made: Array = []
	var done: Array = []
	p.choice_made.connect(func(id: String, k: String, t: bool) -> void: made.append([id, k, t]))
	p.finished.connect(func(sk: bool) -> void: done.append(sk))
	p.start()
	var n: int = 0
	while done.is_empty() and n < 3000:
		p.step(1.0 / 60.0)
		n += 1
	_check(made == [["za_man", "refuse", true]] and done == [false] and String(choices["za_man"]) == "refuse",
		"no answer: choice_made(za_man, refuse, timed out), recorded in StoryDirector.choices (%s)" % str(made))
	world.queue_free()
	paused = false
	if had:
		choices["za_man"] = old
	else:
		choices.erase("za_man")
	var acc: CineTimeline = CineTimeline.load_slot("cine_d5_choice_accept")
	var ref: CineTimeline = CineTimeline.load_slot("cine_d5_choice_refuse")
	_check(acc.length >= 3.0 and acc.length <= 5.0 and ref.length >= 3.0 and ref.length <= 5.0, "choice 2 branch tails are 3-5 s")
	_check(_said("cine_d5_choice_accept").contains("Chào mừng sếp mới") and _said("cine_d5_choice_refuse").contains("Không.")
		and ref.cues.any(func(c: Dictionary) -> bool: return c["type"] == "hold" and c["actor"] == "za" and String(c["kind"]) == "katana"),
		"tails: the handshake / the refusal and the drawn katana")
	_check(String(CineAudio.SLOT_FALLBACK.get("cine_d5_choice_accept", "")) == "cine_d5_choice" and String(CineAudio.SLOT_FALLBACK.get("cine_d5_choice_refuse", "")) == "cine_d5_choice",
		"the tails fall back to the cine_d5_choice music")


## The Phase C villain cards: widths, the lower-left band, reading time, Alexander's running name, show_for.
func _phase_c_cards() -> void:
	for id: String in ["soi_xam", "alexander", "za_man"]:
		var d: Dictionary = StoryCast.villain_data(id)
		var chars: int = String(d["name"]).length() + String(d["nick"]).length() + String(d["joke"]).length()
		var ln: float = StoryCast.card_len(id)
		_check(ln >= 0.06 * chars - 1e-6 and ln <= CineClock.CARD_FREEZE.y + 1e-6, "%s card reads in %.1f s (%d characters, fits a 4 s card freeze)" % [id, ln, chars])
		var all: String = String(d["name"]) + String(d["nick"]) + String(d["joke"]) + String(d.get("name_run", ""))
		_check(_plain(all) and not all.contains("…"), "%s card text is plain" % id)
		var vc := StoryVillainCard.new()
		vc.data = d
		vc.r0 = 0.0
		vc.dur = ln
		root.add_child(vc)
		vc.update(ln * 0.8)
		var vs: Vector2 = vc._vp()
		var nw: float = vc.name_label.get_combined_minimum_size().x * vc.name_label.scale.x
		print("  card %s: name %.0f px (scale %.2f), nick %.0f, joke %.0f" % [id, nw, vc.name_label.scale.x, vc.nick_label.get_combined_minimum_size().x,
			vc.joke_label.get_combined_minimum_size().x])
		_check(nw > 150.0 and vc.nick_label.get_combined_minimum_size().x > 150.0 and vc.joke_label.get_combined_minimum_size().x >= 600.0,
			"%s card keeps its widths (no one-letter lines)" % id)
		_check(vc.box.position.x + nw <= 0.56 * vs.x + 1.0 and vc.box.position.y >= 0.59 * vs.y, "%s card: the name fits the lower-left band" % id)
		if id == "alexander":
			var nb: int = String(d["name"]).length()
			vc.update(0.05 * ln)
			var c0: int = vc.name_label.text.length()
			vc.update(0.4 * ln)
			var c1: int = vc.name_label.text.length()
			var w1: float = vc.name_label.get_combined_minimum_size().x * vc.name_label.scale.x
			vc.update(0.9 * ln)
			var c2: int = vc.name_label.text.length()
			print("  alexander's name: %d -> %d -> %d characters, %.0f px running, scale %.2f at the end" % [c0, c1, c2, w1, vc.name_label.scale.x])
			_check(c0 == nb and c1 > nb + 10 and c2 == vc.name_full.length(), "Alexander's endless name types on after the name")
			_check(vc.box.position.x + w1 > 0.56 * vs.x and vc.name_label.scale.x < 0.95, "it runs off the band, then shrinks to fit")
		vc.queue_free()
	for id2: String in ["soi_xam", "za_man"]:
		paused = false
		var fin: Array = []
		var g := StoryVillainCard.show_for(root, StoryCast.villain_data(id2), StoryCast.card_len(id2))
		g.manual = true
		g.finished.connect(func() -> void: fin.append(true))
		_check(paused, "show_for(%s) freezes the game" % id2)
		g.step(StoryCast.card_len(id2) + 0.1)
		_check(fin == [true] and not paused, "show_for(%s) ends, unpauses" % id2)
	var st: CineTimeline = CineTimeline.load_slot("cine_d3_mannequins")
	_check(st.cards.size() == 1 and String(st.cards[0]["data"]["name"]) == "Alexander ABCXYZ" and st.cards[0]["data"].has("name_run")
		and st.clock.beat_rows().any(func(row: Dictionary) -> bool: return String(row["preset"]) == "card"), "cine_d3_mannequins: Alexander's card over a freeze frame")
	# the screen cards: radio, flow, credits
	for e: Array in [["cine_d3_intro", "radio"], ["cine_d5", "flow"], ["end_c", "credits"], ["cine_d2", "phone"]]:
		var tl: CineTimeline = CineTimeline.load_slot(String(e[0]))
		var cd: Dictionary = tl.cards[0]
		var sc := StoryScreenCard.new()
		sc.data = cd["data"]
		sc.r0 = float(cd["r"])
		sc.dur = float(cd["dur"])
		root.add_child(sc)
		sc.update(sc.r0 + sc.dur * 0.5)
		_check(String(cd["data"]["kind"]) == String(e[1]) and sc.frame.visible and sc.screen.get_combined_minimum_size().x >= 300.0, "%s: the %s card shows" % [String(e[0]), String(e[1])])
		if String(e[1]) == "credits":
			var y0: float = sc.roll.position.y
			sc.update(sc.r0 + sc.dur * 0.8)
			_check(sc.roll.position.y < y0 and sc.title_label.get_combined_minimum_size().x > 300.0, "the credits roll up")
		if String(e[1]) == "flow":
			_check(sc.flow_labels.size() == 5 and sc.flow_labels.all(func(l: Label) -> bool: return l.get_combined_minimum_size().x > 40.0), "the flow card labels keep their width")
		sc.update(sc.r0 + sc.dur + 1.0)
		_check(not sc.frame.visible, "%s: the %s card is gone after its window" % [String(e[0]), String(e[1])])
		sc.queue_free()
	paused = false


## Animated props: mannequin heads, monitor wall, STONKS, container doors, the crowd size; the forklift and sets build.
func _phase_c_props() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var tl: CineTimeline = CineTimeline.load_slot("cine_d3_mannequins")
	var p := CinePlayer.new()
	world.add_child(p)
	p.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	var total: int = 0
	for k: String in p.prop_nodes.keys():
		if k.begins_with("crowd"):
			total += ((p.prop_nodes[k] as Node3D).get_meta("anim_node") as CineCrowd).count()
	_check(total >= 300, "cine_d3_mannequins: hundreds of mannequins (%d)" % total)
	var crowd: CineCrowd = (p.prop_nodes["crowd01"] as Node3D).get_meta("anim_node")
	var door: CineAnimProp = (p.prop_nodes["box01"] as Node3D).get_meta("anim_node")
	p.seek(0.2)
	var shut: String = door.state
	p.seek(1.75)
	var away: float = crowd.head_turn
	var dst: String = door.state
	p.seek(2.3)
	var front: float = crowd.head_turn
	_check(shut == "shut" and dst == "open" and rad_to_deg(away) > 60.0 and rad_to_deg(front) < 1.0,
		"the middle door creaks open, the heads face away (%.0f deg), then all snap to the front (%.1f deg)" % [rad_to_deg(away), rad_to_deg(front)])
	var other: CineAnimProp = (p.prop_nodes["box10"] as Node3D).get_meta("anim_node")
	p.seek(1.7)
	var o0: String = other.state
	p.seek(2.4)
	_check(o0 == "shut" and other.state == "open", "the other containers bang open at the scare")
	p.queue_free()
	var mt: CineTimeline = CineTimeline.load_slot("cine_d5_monitors")
	var pm := CinePlayer.new()
	world.add_child(pm)
	pm.setup(mt, Transform3D.IDENTITY, {"manual": true, "music": false})
	var wall: CineAnimProp = (pm.prop_nodes["wall"] as Node3D).get_meta("anim_node")
	var states: Array = []
	for r: float in [1.0, 2.5, 2.62, 7.0]:
		pm.seek(r)
		states.append(wall.state)
	_check(states[0] == "off" and String(states[1]).begins_with("face") and states[1] != states[2] and states[3] == "error" and wall.error_label.visible
		and wall.error_label.text == "Lọ Thần đã gặp sự cố" and wall.find_children("Screen*", "MeshInstance3D", true, false).size() == 50,
		"50 monitors: off, Za Mẫn's face laughing (frames swap), then frozen on the error (%s)" % str(states))
	pm.queue_free()
	var ct: CineTimeline = CineTimeline.load_slot("cine_d5_choice")
	var pc := CinePlayer.new()
	world.add_child(pc)
	pc.setup(ct, Transform3D.IDENTITY, {"manual": true, "music": false})
	var stonks: CineAnimProp = (pc.prop_nodes["stonks"] as Node3D).get_meta("anim_node")
	pc.seek(3.0)
	var up: String = stonks.state
	var y_end0: float = stonks.segs[stonks.segs.size() - 1].position.y
	pc.seek(8.0)
	_check(up == "up" and stonks.state == "dive" and stonks.ticker.visible and stonks.segs[stonks.segs.size() - 1].position.y < y_end0 - 0.3,
		"the STONKS chart climbs, then dives with a red ticker")
	var fire: CineAnimProp = (pc.prop_nodes["fire0"] as Node3D).get_meta("anim_node")
	_check(fire.state == "burning" and fire.light.light_energy > 1.0, "the server room is burning")
	pc.queue_free()
	world.queue_free()
	for k2: String in CinePropsC.KINDS:
		_check(CineFX.PROP_KINDS.has(k2), "prop kind %s is known to the validator" % k2)
		var n: Node3D = CineFX.build_prop(k2, {})
		_check(n.get_child_count() > 0, "prop %s builds" % k2)
		n.free()
	var helm_on: Node3D = CineFX.build_prop("wolf_helmet", {})
	var helm_off: Node3D = CineFX.build_prop("wolf_helmet", {"led_on": false})
	_check(bool(helm_on.get_meta("led_on")) and not bool(helm_off.get_meta("led_on")), "wolf helmet LED eyes on / off")
	helm_on.free()
	helm_off.free()


## The Phase C cast: gear on the gameplay bodies, wolf helmets hide the rider helmet, looks from the spec, gear placement.
func _phase_c_cast() -> void:
	var world := Node3D.new()
	root.add_child(world)
	for id: String in StoryCast.PHASE_C:
		if id == "mannequins":
			continue
		var b: Node3D = StoryCast.build(id)
		world.add_child(b)
		var gear: Array = b.get_meta("gear", [])
		_check(gear.size() == StoryCast.gear(id).size() + StoryCast.hand_props(id).size() and gear.size() > 0, "%s wears its gear (%d)" % [id, gear.size()])
		if id in StoryCast.WOLF_HELMET:
			var shown: Array = b.find_children("*", "MeshInstance3D", true, false).filter(func(mi: Node) -> bool: return mi.has_meta("helmet_part") and (mi as MeshInstance3D).visible)
			_check(shown.is_empty(), "%s: the rider helmet is hidden under the wolf helmet" % id)
		if id == "za_man":
			var feet: String = ""
			for mi2: Node in b.find_children("*", "MeshInstance3D", true, false):
				if String(mi2.name).ends_with("_Feet"):
					var fm: Material = (mi2 as MeshInstance3D).get_surface_override_material(0)
					feet = (fm as StandardMaterial3D).albedo_color.to_html(false) if fm is StandardMaterial3D else ""
			_check(feet == "f2f2f2", "Za Mẫn wears white sneakers (%s)" % feet)
		b.queue_free()
	var o: Dictionary = StoryCast.opts("za_man")
	_check((o["shirt_color"] as Color).is_equal_approx(StoryCast.ZA_BLACK) and String(o["hair_style"]) == "bun", "Za Mẫn: black turtleneck, man bun")
	_check(StoryCast.gear("za_man").map(func(g: Dictionary) -> String: return String(g["kind"])) == ["round_glasses", "turtleneck"], "Za Mẫn: round glasses, the turtleneck collar")
	_check(StoryCast.gear("alexander").map(func(g: Dictionary) -> String: return String(g["kind"])) == ["gold_shades", "hawaii_print"]
		and String(StoryCast.opts("alexander")["hair_style"]) == "side_part" and StoryCast.hand_props("alexander")[0]["kind"] == "cigar_vape",
		"Alexander: gold sunglasses, Hawaiian flowers, slicked hair, the cigar vape")
	_check(StoryCast.gear("anh_duy").map(func(g: Dictionary) -> String: return String(g["kind"])) == ["headphones", "belly", "key_lanyard"]
		and float(StoryCast.opts("anh_duy")["body_width"]) >= 1.25 and StoryCast.hand_props("anh_duy")[0]["kind"] == "energy_drink",
		"Anh Duy: headphones, a big belly, the key lanyard, an energy drink")
	_check(StoryCast.gear("guard_fox")[0]["kind"] == "fox_mask" and StoryCast.gear("guard_wolf")[0]["kind"] == "wolf_mask"
		and StoryCast.gear("guard_sheep")[0]["kind"] == "sheep_mask" and (StoryCast.opts("guard_fox")["shirt_color"] as Color).is_equal_approx(StoryCast.GUARD_BLACK),
		"lair guards in black with fox, wolf and sheep masks")
	_check(StoryCast.speaker("soi_xam") == "Sói Xám" and StoryCast.speaker("alexander") == "Alexander" and StoryCast.speaker("za_man") == "Za Mẫn"
		and StoryCast.speaker("anh_duy") == "Anh Duy", "Phase C speaker names")
	# eye-level gear lines up with the PS2 head's own glasses frame (front pieces), within 2.5 cm
	var a := CineActor.new()
	world.add_child(a)
	a.setup({"preset": "student_m", "seed": 6161, "body": "casual", "glasses": true, "body_width": 0.95, "height": 1.02})
	a.move(0.0, "idle")
	a.evaluate(0.0)
	var hb: Vector3 = a.to_local(a.bone_world("Head"))
	var acc := Vector3.ZERO
	var n: int = 0
	for mi3: Node in a.find_children("*", "MeshInstance3D", true, false):
		var mm: MeshInstance3D = mi3
		if mm.mesh is BoxMesh and (mm.mesh as BoxMesh).size.z <= 0.0045 and mm.material_override is StandardMaterial3D \
				and (mm.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("#16161A")):
			acc += a.to_local(mm.global_position) - hb
			n += 1
	var frame: Vector3 = acc / maxf(n, 1)
	print("  PS2 glasses frame %s from the Head bone (gear eyes %.3f, %.3f)" % [str(frame), StoryCast.EYE_UP, StoryCast.EYE_FRONT])
	_check(n >= 8 and Vector2(frame.y, frame.z).distance_to(Vector2(StoryCast.EYE_UP, StoryCast.EYE_FRONT)) < 0.025, "eye-level gear sits on the glasses line (%d pieces)" % n)
	world.queue_free()
