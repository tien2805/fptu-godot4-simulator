# File: res://tests/test_story_day6.gd
# Headless end-to-end test of story Day 6 "Trà Sữa Lọ" (plan 2026-11-01-w4-day6.md T5), from the end of Day 5: the call
# N = 2 -> the Day 6 morning (Phúc's text) -> the marker by the Trà Sữa Lọ shop -> cine_d6_intro ->
# StoryDirector.launch_lair_beat -> the canal scene (StoryCanal: LairCanal at the origin, its own player stack in the pink
# shipper shirt) -> the shop shift (trust at 0 = BỊ LỘ -> THỬ LẠI -> full trust opens the back door) -> the back room (the
# ledger, the mirror, the seg_d6_infiltrate replay, E7) -> cine_d6_caught in the real back room -> the speedboat chase (the
# hull at 0 = TOANG! -> THỬ LẠI -> the last ram crashes Thị Lọ on the bank) -> seg_d6_chase -> choice 3 timing out on the
# honest "refuse" -> the refuse tail -> back to free roam -> ai_reveal (no owner clip: the in-engine fallback) -> bed ->
# the call N = 1 -> the hand-off to Day 7 (`d7_start`, the w4-day7 stream's: until the streams merge the test stops at the
# call). Then Continue mid-day (d6_boat: the marker, the scene resumes at the pier with the back door open and the ledger
# gone, VỀ THẾ GIỚI MỞ keeps the beat) and Chọn cảnh back to d6_choice: "take" -> the take tail -> d6_reveal.
# A time-scale audit (tests/support/time_scale_audit.gd) watches the run (the chase's hit stops, the cuts).
# Run:  godot --headless --path . --script tests/test_story_day6.gd
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")

var TMP: String = "user://test_story_day6_%d.cfg" % OS.get_process_id()
var SNAP: String = "user://test_story_day6_snap_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_story_day6_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_story_day6_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_story_day6_backup_%d.cfg" % OS.get_process_id()
var VID: String = "user://test_story_day6_video_%d/" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const CANAL: String = "res://scenes/story/StoryCanal.tscn"
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var cn: StoryCanal
var m: StoryMission
var mark: Dictionary = {}
var audit: Node = null
var hold: Callable = Callable()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 6 (Trà Sữa Lọ: canal scene, shop, back room, boat chase, choice 3 both branches, continue) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, SNAP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	StoryVideo.video_dir = VID   # an empty folder: the owner's ai_reveal clip never plays in the test
	StoryCanal.test_opts = {"missions": {"manual": true, "manual_replay": true, "manual_card": true, "seed": 3},
		"cine": {"manual": true, "music": false}, "capture_mouse": false}
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	Difficulty.set_easy(false)
	audit = TimeAudit.new()
	audit.name = "TimeScaleAudit"
	root.add_child(audit)


func _roam() -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	root.add_child(fr)
	sr = fr.get("story_roam")
	if sr:
		sr.cine_opts = {"manual": true, "music": false}
		sr.call_opts = {"manual": true}
		sr.mission_opts = {"manual": true, "manual_replay": true, "seed": 9}


func _canal() -> void:
	cn = (load(CANAL) as PackedScene).instantiate()
	root.add_child(cn)


func _finish_cine_in(host: Node) -> String:
	var cp: CinePlayer = host.get("cine_player")
	if cp == null:
		return ""
	var slot: String = cp.timeline.slot
	var n: int = 0
	while host.get("cine_player") != null and n < 8000:
		cp.step(DT)
		n += 1
	_check(host.get("cine_player") == null, "%s finished" % slot)
	return slot


func _cine_started(host: Node, what: String, cap: int = 150) -> bool:
	if host.get("cine_player") != null:
		return true
	if frames > cap:
		_check(false, "%s did not start (step %s)" % [what, String(sd.get("step"))])
		phase = 999
	return false


func _ring() -> StoryCall:
	var c: StoryCall = sr.call
	if c == null:
		return null
	var n: int = 0
	while c.phase != "ring" and n < 300:
		c.step(DT)
		n += 1
	return c


func _do_call() -> int:
	var c: StoryCall = _ring()
	if c == null:
		return -1
	var days: int = c.days
	c.answer()
	var n: int = 0
	while sr.call != null and n < 3000:
		c.step(DT)
		n += 1
	return days


func _next(p: int) -> void:
	phase = p
	frames = 0


func _wait_mission(cls: String, cap: int = 150) -> StoryMission:
	var mn: StoryMission = cn.mission_node if cn else null
	if mn != null and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start in the canal scene (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


func _step_replay(mn: StoryMission) -> bool:
	if mn == null or not is_instance_valid(mn) or mn.replay == null:
		return false
	var n: int = 0
	while is_instance_valid(mn) and mn.replay != null and n < 1500:
		mn.replay.step(DT)
		n += 1
	return true


func _fail_shown(title: String, cap: int = 60) -> bool:
	if cn.fail_ui and cn.fail_ui.visible:
		_check(cn.fail_ui.title_label.text == title, "%s in the canal scene (%s)" % [title, cn.fail_ui.title_label.text])
		return true
	if frames > cap:
		_check(false, "no %s card" % title)
		phase = 999
	return false


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 60000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	if hold.is_valid():
		hold.call()
	if cn and is_instance_valid(cn) and cn.mission_node and cn.mission_node.state == "running" and cn.mission_node.replay == null:
		cn.mission_node.advance(DT)
	match phase:
		0:
			sd.call("new_story", {"female": true, "name": "Lan", "variant": 1, "hair_style": "ponytail", "hair_color": 1, "skin": 1})
			sd.set("day", 5)
			for e: String in ["E1", "E3", "E4", "E5", "E6"]:
				(sd.get("evidence") as Array).append(e)
			(sd.get("choices") as Dictionary)["phuc"] = "cover"
			(sd.get("choices") as Dictionary)["zaman_offer"] = "refuse"
			sd.call("_enter", "d5_call")
			_roam()
			_next(1)
		1:
			var n: int = _do_call()
			if n < 0:
				if frames > 150:
					_check(false, "the Day 5 call did not start")
					phase = 999
				return false
			_check(n == 2, "the call after Day 5 says 2")
			_next(2)
		2:
			if not _cine_started(fr, "Day 6 morning"):
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 6 and dc.left == 2, "Day 6 morning card (CÒN 2 NGÀY)")
			var ph: Array = (sd.get("texts") as Array).filter(func(t: Dictionary) -> bool: return String(t["from"]) == "Phúc" and int(t["day"]) == 6)
			_check(ph.size() == 1 and String(ph[0]["text"]).contains("shipper"), "Phúc's Day 6 text: the shipper uniform")
			_finish_cine_in(fr)
			_next(3)
		3:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d6_shop" and sr.markers.has("d6_shop") and sr.mission_node == null, "the shop marker by the Rạch Hầm bridge")
			_check(sr.start_marker("d6_shop") and _finish_cine_in(fr) == "cine_d6_intro", "[E]: cine_d6_intro (Phúc hands over the uniform)")
			_check(String(sd.get("last_nav")) == "lair:" + CANAL and String((sm.get("story_context") as Dictionary).get("lair", "")) == "canal", "the canal scene is launched")
			_check(String((sd.call("read_save", TMP) as Dictionary).get("step", "")) == "d6_shop", "saved at d6_shop")
			fr.queue_free()
			_next(4)
		4:
			if frames < 3:
				return false
			_canal()
			_next(5)
		# ------------------------------------------------------------------ the shop
		5:
			m = _wait_mission("MissionShop")
			if m == null:
				return false
			var shop: MissionShop = m
			_check(cn.level != null and not cn.level.is_back_door_open() and cn.level.ledger.visible, "the canal: the back door shut, the ledger in the safe")
			_check(cn.player.character_opts.get("shirt_color") == StoryCanal.SHIPPER_SHIRT and bool(cn.player.character_opts.get("female", false)), "the protagonist in the pink shipper shirt")
			_check(cn.music_slot == "mission_shop" and shop.cam.current, "the shift: mission_shop, the shop camera")
			_check(cn.weapons == null and not cn.mounted, "Day 6 is unarmed")
			shop._add_trust(-shop.trust)
			_next(6)
		6:
			if not _fail_shown(StoryMission.T_LO):
				return false
			cn.fail_ui.press_retry()
			var shop6: MissionShop = m
			_check(shop6.state == "running" and is_equal_approx(shop6.trust, MissionShop.TRUST_START), "THỬ LẠI: a new shift at trust 30")
			shop6.trust = MissionShop.TRUST_WIN - 1.0
			shop6._add_trust(5.0)
			_check(cn.level.is_back_door_open(), "full trust opens the back door")
			_next(7)
		# ------------------------------------------------------------------ the back room
		7:
			m = _wait_mission("MissionBackroom", 300)
			if m == null:
				return false
			var room: MissionBackroom = m
			_check(String(sd.get("step")) == "d6_backroom" and cn.music_slot == "night_stealth", "the back room on the stealth track")
			_check(String((sd.call("read_save", TMP) as Dictionary).get("step", "")) == "d6_backroom", "saved at d6_backroom")
			room.patrol = []
			var rx: Transform3D = room.pts["room_xf"]
			var gp: Vector3 = rx * Vector3(-3.4, 0.0, 2.9)
			var face_at: Vector3 = rx * Vector3(-3.4, 0.0, 4.0)
			var wr: WeakRef = weakref(room)          # the mission is freed after its beat: no freed lambda capture
			hold = func() -> void:
				var r: MissionBackroom = wr.get_ref() as MissionBackroom
				if r != null and r.state == "running" and r.guard:
					r.guard.global_position = gp
					r.guard.rotation.y = MissionBackroom.yaw_of(face_at - gp)
			room.start_music()
			room.crack = 1.0
			room._take_ledger()
			_check(room.has_ledger and not cn.level.ledger.visible, "the ledger taken")
			_next(8)
		8:
			var room8: MissionBackroom = m as MissionBackroom if is_instance_valid(m) else null
			if room8 and _step_replay(room8):
				mark["infiltrate"] = true
			if not _cine_started(cn, "cine_d6_caught", 400):
				return false
			hold = Callable()
			_check(mark.has("infiltrate"), "the seg_d6_infiltrate replay")
			_check(bool(sd.call("has_evidence", "E7")) and String(sd.get("step")) == "d6_caught", "the ledger is E7")
			var cp8: CinePlayer = cn.cine_player
			_check(cp8.timeline.slot == "cine_d6_caught" and cp8.stage_xf.is_equal_approx(cn.level.room_xf()), "cine_d6_caught staged in the real back room")
			_check(_finish_cine_in(cn) == "cine_d6_caught", "the mirror: \"Gì?\", Còn cái nịt")
			_next(9)
		# ------------------------------------------------------------------ the speedboat chase
		9:
			m = _wait_mission("MissionBoatChase", 200)
			if m == null:
				return false
			var mb: MissionBoatChase = m
			_check(String(sd.get("step")) == "d6_boat" and cn.music_slot == "mission_boat" and mb.chase.cam.current, "the chase: mission_boat, the boat camera")
			_check(cn.level.is_back_door_open() and not cn.level.ledger.visible, "the shop state holds (the door open, the ledger gone)")
			_check(not cn.player.visible and mb.markers.is_tracked(mb.chase.rival), "the walking body hidden, Thị Lọ marked")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(SNAP))
			_check(String((sd.call("read_save", SNAP) as Dictionary).get("step", "")) == "d6_boat", "saved at d6_boat")
			mb.chase.boat.hull = 0.0
			_next(10)
		10:
			if not _fail_shown(StoryMission.T_TOANG):
				return false
			_check(cn.fail_ui.reason_label.text.contains(BoatData.T_SINK), "the sunk-boat reason")
			cn.fail_ui.press_retry()
			var mb10: MissionBoatChase = m
			var c: BoatChase = mb10.chase
			_check(c.state == "running" and is_equal_approx(c.boat.hull, BoatData.HULL) and c.cam.current, "THỬ LẠI: a full hull at the checkpoint")
			# straight to the finish: the last ram
			c.input_override = {"throttle": 1.0, "steer": 0.0, "duck": false}
			for sk: JetSki in c.skis:
				sk.retire()
			c.wave_i = BoatData.WAVES.size()
			c.hits.clear()
			c.boat.place(1400.0, 0.0, BoatData.v_max())
			c.rival.place(1404.0, 0.0, 20.0)
			c.rival.rams = BoatData.rams_needed() - 1
			_next(11)
		11:
			if not _cine_started(cn, "seg_d6_chase", 400):
				return false
			_check(cn.cine_player.timeline.slot == "seg_d6_chase" and String(sd.get("step")) == "d6_choice", "the last ram: seg_d6_chase (the beat completed first)")
			_check(String((sd.call("read_save", TMP) as Dictionary).get("step", "")) == "d6_choice", "saved at d6_choice")
			_finish_cine_in(cn)
			_next(12)
		12:
			if not _cine_started(cn, "cine_d6_choice", 200):
				return false
			var cp12: CinePlayer = cn.cine_player
			_check(cp12.timeline.slot == "cine_d6_choice" and String(sd.call("choice_of", "bribe")) == "", "choice 3 on the bank, not answered yet")
			_check(_finish_cine_in(cn) == "cine_d6_choice" and String(sd.call("choice_of", "bribe")) == "refuse" and cp12.choice_timed_out, "timeout: the honest refuse is taken")
			_next(13)
		13:
			if not _cine_started(cn, "the refuse tail", 120):
				return false
			_check(_finish_cine_in(cn) == "cine_d6_choice_refuse", "refuse: the refuse tail")
			_next(14)
		14:
			if not cn.left:
				if frames > 120:
					_check(false, "the canal did not hand back after the tail")
					phase = 999
				return false
			_check(String(sd.get("step")) == "d6_reveal" and String(sd.get("last_nav")) == "roam", "back to story free roam for ai_reveal")
			for id: String in ["d6_shop", "d6_backroom", "d6_caught", "d6_boat", "d6_choice"]:
				_check(StoryChapters.is_beat_unlocked(id) and not StoryChapters.snapshot(id).is_empty(), "Chọn cảnh: %s snapshotted" % id)
			cn.queue_free()
			cn = null
			_next(15)
		15:
			if frames < 3:
				return false
			_roam()
			_next(16)
		16:
			if not _cine_started(fr, "ai_reveal", 300):
				return false
			_check(fr.get("cine_player").timeline.slot == "ai_reveal", "no owner clip: the ai_reveal fallback")
			_finish_cine_in(fr)
			_next(17)
		17:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d6_bed" and sr.markers.has("d6_bed"), "the bed marker")
			var duy: Array = (sd.get("texts") as Array).filter(func(t: Dictionary) -> bool: return String(t["from"]) == "Anh Duy" and int(t["day"]) == 6)
			_check(duy.size() == 1 and String(duy[0]["text"]).contains("Lọ Academy"), "Anh Duy: the money flows to Lọ Academy")
			_check(sr.start_marker("d6_bed"), "bed")
			_next(18)
		18:
			if StoryMissions.beat("d7_start").is_empty():
				# until the streams merge: the last call starts and says 1; Day 7 is the w4-day7 stream's
				var c18: StoryCall = _ring()
				if c18 == null:
					if frames > 150:
						_check(false, "the Day 6 call did not start")
						phase = 999
					return false
				_check(c18.days == 1 and String(sd.get("step")) == "d6_call" and String(StoryMissions.beat("d6_call")["next"]) == "d7_start", "the call after Day 6 says 1, then d7_start")
			else:
				var n18: int = _do_call()
				if n18 < 0:
					if frames > 150:
						_check(false, "the Day 6 call did not start")
						phase = 999
					return false
				_check(n18 == 1 and String(sd.get("step")).begins_with("d7"), "the call after Day 6 says 1, Day 7 starts (%s)" % String(sd.get("step")))
			_check(String(sd.call("evaluate_ending", sd.call("to_dict"))) != "C" and sd.call("has_evidence", "E7"), "refused: not ending C, E7 kept")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			paused = false
			_next(19)
		# ------------------------------------------------------------------ Continue mid-day: d6_boat
		19:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", SNAP)
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d6_boat", "Continue restores d6_boat")
			_roam()
			_next(20)
		20:
			if frames < 40:
				return false
			_check(sr.markers.has("d6_boat") and sr.mission_node == null and fr.get("cine_player") == null, "Continue: the shop marker, nothing starts by itself")
			_check(sr.start_marker("d6_boat") and fr.get("cine_player") == null and String(sd.get("last_nav")) == "lair:" + CANAL, "[E]: back into the canal (no intro again)")
			fr.queue_free()
			_next(21)
		21:
			if frames < 3:
				return false
			_canal()
			_next(22)
		22:
			m = _wait_mission("MissionBoatChase")
			if m == null:
				return false
			_check(cn.level.is_back_door_open() and not cn.level.ledger.visible, "resumed at the pier: the back door open, the ledger gone")
			cn.abort_mission()
			_check(cn.left and String(sd.get("step")) == "d6_boat" and String(sd.get("last_nav")) == "roam" and cn.player.visible, "VỀ THẾ GIỚI MỞ: back to free roam, the beat stays")
			cn.queue_free()
			cn = null
			_next(23)
		# ------------------------------------------------------------------ Chọn cảnh: choice 3, "take"
		23:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", TMP)
			_check(bool(StoryChapters.rewind(sd, "d6_choice")) and String(sd.get("step")) == "d6_choice" and String(sd.call("choice_of", "bribe")) == "",
				"Chọn cảnh: rewind to choice 3 (unanswered)")
			_roam()
			_next(24)
		24:
			if frames < 40:
				return false
			_check(sr.markers.has("d6_choice") and sr.start_marker("d6_choice") and String(sd.get("last_nav")) == "lair:" + CANAL, "the choice marker launches the canal")
			fr.queue_free()
			_next(25)
		25:
			if frames < 3:
				return false
			_canal()
			_next(26)
		26:
			if not _cine_started(cn, "cine_d6_choice (take run)", 150):
				return false
			var cp26: CinePlayer = cn.cine_player
			var n26: int = 0
			while cp26.choice_node == null and cn.cine_player != null and n26 < 4000:
				cp26.step(DT)
				n26 += 1
			_check(cp26.choice_node != null, "choice 3 opens")
			if cp26.choice_node:
				cp26.choice_node.pick("take")
			_check(_finish_cine_in(cn) == "cine_d6_choice" and String(sd.call("choice_of", "bribe")) == "take", "take is recorded")
			_next(27)
		27:
			if not _cine_started(cn, "the take tail", 120):
				return false
			_check(_finish_cine_in(cn) == "cine_d6_choice_take", "take: the take tail")
			_next(28)
		28:
			if not cn.left:
				if frames > 120:
					_check(false, "the canal did not hand back after the take tail")
					phase = 999
				return false
			_check(String(sd.get("step")) == "d6_reveal", "take -> d6_reveal (Day 6 goes on)")
			cn.queue_free()
			cn = null
			phase = 999
	return false


func _end() -> bool:
	hold = Callable()
	paused = false
	if audit:
		print("  ", audit.call("report"))
		_check(bool(audit.call("clean", 6.0)), "the time scale stayed in the owner protocol (%s)" % String(audit.call("report")))
	for p: String in [TMP, SNAP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VID))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
	StoryCanal.test_opts = {}
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("SUCCESS: STORY DAY 6 (canal scene, shop, back room, E7, boat chase, choice 3 refuse + take, ai_reveal, call, continue)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
	return true
