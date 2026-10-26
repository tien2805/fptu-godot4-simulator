# File: res://tests/test_story_day2.gd
# Headless end-to-end test of story Day 2 "Bầy Sói" (spec C-D6; plan 2026-10-26-phase-c-integration.md), from the end of
# Day 1: the call N = 6 -> the Day 2 morning (Anh Duy's text with its Dịch: line, CÒN 6 NGÀY) -> the marker at Anh Duy's
# corner of the BE6 lobby -> cine_d2_intro -> the bike chase on Nguyễn Xiển southbound (the reversed route ending just past
# the Rạch Hầm bridge, "Tới công chuyện luôn!", knocked off = TOANG! -> THỬ LẠI, the Bầy Sói crashed wave after wave, the
# seg_d2_chase replay) -> the drift duel with Sói Xám (Tokyo Drift: his intro line, 3-2-1, a loss = a quick retry with no
# fail card, the win, his ending) -> the bridge horror beat (fog, howl, LED eyes going out, the snap, the synth ringtone, the Sói Xám
# villain card) -> the duel (soi_xam, the boss bar, down = TOANG! -> retry, KO) -> seg_d2_boss -> the pillar marker with the
# optional E3 ledger (taken) -> cine_d2 -> bed -> the call N = 5 -> Day 3. Then Continue at d2_end with E3 skipped (no E3
# after the call), Continue at d2_duel (the bank marker, the fight does not start by itself) and Chọn cảnh: the new beats
# are snapshotted and a rewind to d2_bridge resumes at its marker.
# Run:  godot --headless --path . --script tests/test_story_day2.gd
extends SceneTree

const TMP: String = "user://test_story_day2.cfg"
const SNAP: String = "user://test_story_day2_snap.cfg"
const TMP_U: String = "user://test_story_day2_unlocks.cfg"
const TMP_C: String = "user://test_story_day2_chapters.cfg"
const TMP_B: String = "user://test_story_day2_backup.cfg"
const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var m: StoryMission
var mark: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 2 (Bầy Sói: chase, bridge, Sói Xám, E3, continue, chapters) ---")
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
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)


func _roam() -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", true)
	root.add_child(fr)
	sr = fr.get("story_roam")
	if sr:
		sr.cine_opts = {"manual": true, "music": false}
		sr.call_opts = {"manual": true}
		sr.mission_opts = {"manual": true, "manual_replay": true, "manual_card": true, "seed": 9}


func _player() -> ThirdPersonController:
	return fr.get("player")


func _finish_cine() -> String:
	var cp: CinePlayer = fr.get("cine_player")
	if cp == null:
		return ""
	var slot: String = cp.timeline.slot
	var n: int = 0
	while fr.get("cine_player") != null and n < 4000:
		cp.step(DT)
		n += 1
	_check(fr.get("cine_player") == null, "%s finished" % slot)
	return slot


func _cine_started(what: String, cap: int = 150) -> bool:
	if fr.get("cine_player") != null:
		return true
	if frames > cap:
		_check(false, "%s did not start (step %s)" % [what, String(sd.get("step"))])
		phase = 999
	return false


func _do_call() -> int:
	var c: StoryCall = sr.call
	if c == null:
		return -1
	var days: int = c.days
	var n: int = 0
	while c.phase != "ring" and n < 300:
		c.step(DT)
		n += 1
	c.answer()
	while sr.call != null and n < 3000:
		c.step(DT)
		n += 1
	return days


func _next(p: int) -> void:
	phase = p
	frames = 0


func _wait_mission(cls: String, cap: int = 120) -> StoryMission:
	var mn: StoryMission = sr.mission_node
	if mn != null and mn.get_script() != null and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 60000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	match phase:
		0:
			sd.call("new_story", {"female": false, "name": "Khang", "variant": 1, "hair_style": "short", "hair_color": 0, "skin": 1})
			sd.set("day", 1)
			(sd.get("evidence") as Array).append("E1")
			(sd.get("choices") as Dictionary)["phuc"] = "cover"
			sd.call("_enter", "d1_call")
			_roam()
			_next(1)
		1:
			var n: int = _do_call()
			if n < 0:
				if frames > 150:
					_check(false, "the Day 1 call did not start")
					phase = 999
				return false
			_check(n == 6, "the call after Day 1 says 6")
			_next(2)
		2:
			if not _cine_started("Day 2 morning"):
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 2 and dc.left == 6, "Day 2 morning card (CÒN 6 NGÀY)")
			var duy: Array = (sd.get("texts") as Array).filter(func(t: Dictionary) -> bool: return String(t["from"]) == "Anh Duy" and int(t["day"]) == 2)
			_check(duy.size() == 1 and String(duy[0]["text"]).contains("(Dịch: "), "Anh Duy's morning text with its Dịch: line")
			_finish_cine()
			_next(3)
		3:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d2_chase" and sr.markers.has("d2_chase") and String(fr.get("tod_preset")) == "night", "the chase marker at night")
			var mp: Vector2 = sr.marker_pos.get("d2_chase", Vector2.ZERO)
			var dp: Vector3 = sr.anchors["duy_corner"]["pos"]
			_check(mp.distance_to(Vector2(dp.x, dp.z)) < 0.1 and String(sd.get("objective")).contains("Anh Duy"), "the marker is at Anh Duy's corner of the BE6 lobby")
			_check(sr.start_marker("d2_chase") and fr.get("cine_player") != null, "[E]: cine_d2_intro")
			_check(_finish_cine() == "cine_d2_intro", "cine_d2_intro plays")
			_next(4)
		4:
			m = _wait_mission("MissionBikeChase")
			if m == null:
				return false
			var mc: MissionBikeChase = m
			var ch: BikeChase = mc.chase
			_check(ch != null and ch.state == "running" and bool(fr.get("mounted")), "the chase runs, the player rides")
			_check(mc.route != null and mc.route.bridge_s > 1500.0 and absf(ch.start_s - (mc.route.bridge_s - MissionBikeChase.CHASE_M)) < 1.0
				and absf(ch.end_at_s - (mc.route.bridge_s + MissionBikeChase.END_PAST_M)) < 1.0, "southbound on Nguyễn Xiển: ends just past the Rạch Hầm bridge (bridge at %.0f m)" % (mc.route.bridge_s if mc.route else -1.0))
			_check(ch.start_line == BikeCombatData.T_START_D2 and ch.start_line == "Tới công chuyện luôn!" and ch.win_line == "Đỉnh nóc kịch trần bay phấp phới", "the memes: start and win lines")
			_check(ch.waves.size() == 2 and (ch.waves[0] as Array).size() + (ch.waves[1] as Array).size() == 6, "two waves, six bikers")
			_check(StoryRoam.mission_slot(sd.call("beat")) == "mission_bike_chase" and m.cues_played.has("radio"), "the chase track slot, Anh Duy on the radio")
			ch.combat.damage(999.0, "kick", 1)
			_next(5)
		5:
			if not (sr.fail_ui and sr.fail_ui.visible):
				if frames > 120:
					_check(false, "knocked off but no TOANG!")
					phase = 999
				return false
			var ch2: BikeChase = (m as MissionBikeChase).chase
			_check(sr.fail_ui.title_label.text == "TOANG!" and ch2.state == "lost", "knocked off: TOANG!")
			sr.fail_ui.press_retry()
			_check(ch2.state == "running" and is_equal_approx(ch2.combat.stability, BikeCombatData.STABILITY_MAX), "THỬ LẠI: the chase again from the checkpoint, stability full")
			_next(6)
		6:
			var mc6: MissionBikeChase = m as MissionBikeChase if is_instance_valid(m) else null
			var ch6: BikeChase = mc6.chase if mc6 else null
			if ch6 and is_instance_valid(ch6):
				if ch6.state == "running":
					for b: Variant in ch6.alive():
						(b as BikerEnemy).crash("test")
				if ch6.replay != null:
					mark["replay"] = true
					var n6: int = 0
					while ch6.replay != null and n6 < 1200:
						ch6.replay.step(DT)
						n6 += 1
			if String(sd.get("step")) != "d2_drift":
				if frames > 3000:
					_check(false, "the chase was not won (state %s)" % (ch6.state if ch6 else "gone"))
					phase = 999
				return false
			_check(mark.has("replay"), "the last fall: the seg_d2_chase replay")
			_next(60)
		# ----- Tokyo Drift (plan 2026-10-27-d2x-drift.md): the drift duel with Sói Xám, then the bridge -----
		60:
			m = _wait_mission("MissionDriftDuel")
			if m == null:
				return false
			var md60: MissionDriftDuel = m
			var du: DriftDuel = md60.duel
			_check(String(sd.get("step")) == "d2_drift" and du != null and du.state == "intro" and du.rival.standing, "d2_drift: the duel starts with Sói Xám standing beside his bike")
			_check(du.subtitle_text.contains(DriftDuel.T_START) and bool(fr.get("mounted")) and String(fr.call("_hint_text")) == DriftDuel.T_RIDING, "his line, the player still riding, the duel's hint")
			_check(StoryRoam.mission_slot(sd.call("beat")) == "race_d2_drift" and StoryRoam.SELF_MUSIC.has("drift_duel"), "the drift track slot, started by the duel itself")
			_check(fr.get("bike").nitro_enabled and is_equal_approx(fr.get("bike").max_speed_ms, float(DriftDuel.DUEL_PROFILE["max_speed_ms"])), "nitro on, the duel profile")
			_next(61)
		61:
			var du61: DriftDuel = (m as MissionDriftDuel).duel
			if du61.state != "racing":
				if frames > 600:
					_check(false, "the duel never raced (%s)" % du61.state)
					phase = 999
				return false
			_check(du61.rival.racing and not fr.get("bike").staged, "3-2-1-ĐI: racing")
			du61.call("_lose", "gap")
			_next(62)
		62:
			var du62: DriftDuel = (m as MissionDriftDuel).duel
			if du62.state != "countdown":
				if frames > 300:
					_check(false, "no quick retry after the loss (%s)" % du62.state)
					phase = 999
				return false
			_check(du62.losses == 1 and du62.retry_count and not (sr.fail_ui and sr.fail_ui.visible) and m.state == "running", "lost: a quick retry on the grid, no fail card")
			_next(63)
		63:
			var du63: DriftDuel = (m as MissionDriftDuel).duel if is_instance_valid(m) else null
			if du63 and du63.state == "racing":
				du63.points = du63.target
				du63.call("_win", "points")
			if String(sd.get("step")) != "d2_bridge":
				if frames > 1500:
					_check(false, "the duel did not end (%s)" % (du63.state if du63 else "gone"))
					phase = 999
				return false
			_check(StoryChapters.is_beat_unlocked("d2_drift") and not StoryChapters.snapshot("d2_drift").is_empty(), "Chọn cảnh: d2_drift unlocked and snapshotted")
			_next(7)
		7:
			m = _wait_mission("MissionBridge")
			if m == null:
				return false
			var mb: MissionBridge = m
			_check(mb.eyes.size() == 4 and mb.soi != null and String(mb.soi.get_meta("cast_id", "")) == "soi_xam", "LED eyes in the dark: Sói Xám and the pack")
			var we: WorldEnvironment = fr.get_node_or_null("WorldEnvironment") as WorldEnvironment
			_check(we != null and we.environment.fog_enabled, "fog over the bank")
			mark["fog_saved"] = mb._fog_saved.duplicate()
			_check(StoryRoam.mission_slot(sd.call("beat")) == "night_tense", "the horror beat plays the night tense track")
			var away: Vector3 = mb.bank + Vector3(0.0, 0.0, 16.0)
			_player().teleport(away, 0.0)
			for k: int in 60:
				mb.advance(DT)
			_check(mb.cues_played.has("wolf_howl") and mb.phase == "walk", "a wolf howl")
			_player().teleport(mb.bank + Vector3(0.0, 0.0, 9.0), 0.0)
			mb.advance(DT)
			_check(mb.phase == "snapped" and mb.cues_played.has("violin_screech"), "closer: every eye snaps on (sting)")
			_check(not mb.eyes[0].visible, "the pack's eyes went out on the way in")
			_player().teleport(mb.bank + Vector3(0.0, 0.0, 5.0), 0.0)
			mb.advance(DT)
			_check(mb.phase == "ringing" and mb.cues_played.has("ringtone_synth") and mb.bubble.visible, "his ringtone: a cheesy synth tune, a phone call")
			for k2: int in 200:
				mb.advance(DT)
				if mb.card != null:
					break
			_check(mb.card != null and String(mb.card.data.get("name", "")) == "Sói Xám" and String(mb.card.data.get("nick", "")) == "đầu đàn Bầy Sói", "the villain card: Sói Xám, đầu đàn Bầy Sói")
			var n7: int = 0
			while mb.card != null and n7 < 600:
				mb.card.step(DT)
				n7 += 1
			_check(mb.state == "done", "the card ends the horror beat")
			_next(8)
		8:
			m = _wait_mission("MissionFight")
			if m == null:
				return false
			var mf: MissionFight = m
			_check(String(sd.get("step")) == "d2_duel" and mf.fight.enemies.size() == 1 and (mf.fight.enemies[0] as MeleeEnemy).archetype_id == "soi_xam", "the duel: Sói Xám alone")
			_check(mf.fight.combat.boss == mf.fight.enemies[0] and mf.fight.force_unarmed, "the boss bar, bare hands")
			_check(StoryRoam.mission_slot(sd.call("beat")) == "boss_d2", "the duel plays boss_d2")
			var we2: WorldEnvironment = fr.get_node_or_null("WorldEnvironment") as WorldEnvironment
			var fs: Array = mark.get("fog_saved", [])
			_check(we2 != null and fs.size() == 5 and we2.environment.fog_enabled == bool(fs[0]) and is_equal_approx(we2.environment.fog_density, float(fs[1]))
				and is_equal_approx(we2.environment.fog_depth_end, float(fs[4])), "the bank fog is lifted after the horror beat (the time of day's own fog back)")
			mf.fight.combat.receive_attack(mf.fight.enemies[0], {"damage": 999.0})
			_next(9)
		9:
			if not (sr.fail_ui and sr.fail_ui.visible):
				if frames > 60:
					_check(false, "down but no TOANG!")
					phase = 999
				return false
			_check(sr.fail_ui.title_label.text == "TOANG!", "down in the duel: TOANG!")
			sr.fail_ui.press_retry()
			var mf9: MissionFight = m
			_check(mf9.fight.state == "running" and is_equal_approx(mf9.fight.combat.hp, 100.0) and mf9.fight.alive().size() == 1, "retry: full HP, Sói Xám again")
			_next(10)
		10:
			var mf10: MissionFight = m as MissionFight if is_instance_valid(m) else null
			if mf10 and mf10.fight and is_instance_valid(mf10.fight):
				for e: Variant in mf10.fight.alive():
					(e as MeleeEnemy).take_strike({"dmg": 999.0, "stagger": 999.0, "breaks_block": true, "from": _player().global_position})
			if fr.get("cine_player") == null:
				if frames > 2000:
					_check(false, "the duel was not won")
					phase = 999
				return false
			_check(_finish_cine() == "seg_d2_boss", "won: seg_d2_boss")
			_next(11)
		11:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d2_end" and sr.markers.has("d2_end") and sr.markers.has("d2_ledger"), "the pillar marker and the optional ledger")
			_check(not sd.call("has_evidence", "E3"), "E3 is optional (not given)")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(SNAP))
			_check(sr.use_side("d2_ledger") and sd.call("has_evidence", "E3") and not sr.markers.has("d2_ledger"), "the ledger page: E3, once")
			_check(sr.start_marker("d2_end") and _finish_cine() == "cine_d2", "[E] at the pillar: cine_d2 (Sói Xám tied up)")
			_next(12)
		12:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d2_bed" and sr.markers.has("d2_bed") and not sr.markers.has("d2_ledger"), "bed marker, the ledger taken")
			for id: String in ["d2_chase", "d2_drift", "d2_bridge", "d2_duel", "d2_end"]:
				_check(StoryChapters.is_beat_unlocked(id) and not StoryChapters.snapshot(id).is_empty(), "Chọn cảnh: %s unlocked and snapshotted" % id)
			_check(StoryChapters.is_cine_unlocked("cine_d2_intro") and StoryChapters.is_cine_unlocked("seg_d2_boss") and StoryChapters.is_cine_unlocked("cine_d2"), "the gallery lists the Day 2 cinematics")
			_check(sr.start_marker("d2_bed"), "bed")
			_next(13)
		13:
			var n13: int = _do_call()
			if n13 < 0:
				if frames > 150:
					_check(false, "the Day 2 call did not start")
					phase = 999
				return false
			_check(n13 == 5, "the call after Day 2 says 5")
			_next(14)
		14:
			if not _cine_started("Day 3 morning"):
				return false
			_finish_cine()
			_next(15)
		15:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d3_sneak" and String(sd.call("day_chip_text")) == "NGÀY 3 · CÒN 5 NGÀY", "Day 3: the yard marker")
			_check(sd.call("has_evidence", "E3"), "E3 kept")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(16)
		16:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", SNAP)
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d2_end", "Continue restores d2_end (E3 not taken)")
			_roam()
			_next(17)
		17:
			if frames < 40:
				return false
			_check(sr.markers.has("d2_end") and sr.markers.has("d2_ledger") and fr.get("cine_player") == null, "after Continue: the pillar marker and the ledger again")
			_check(sr.start_marker("d2_end") and _finish_cine() == "cine_d2", "E3 skipped: cine_d2")
			_next(18)
		18:
			if frames < 5:
				return false
			_check(sr.markers.has("d2_ledger"), "the ledger is still offered until bed")
			sr.start_marker("d2_bed")
			_next(19)
		19:
			var n19: int = _do_call()
			if n19 < 0:
				if frames > 150:
					_check(false, "the call did not start (skip run)")
					phase = 999
				return false
			_next(20)
		20:
			if not _cine_started("Day 3 morning (skip run)"):
				return false
			_finish_cine()
			_next(21)
		21:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d3_sneak" and not sd.call("has_evidence", "E3") and not sr.markers.has("d2_ledger"), "skipped: no E3, the ledger is gone with Day 2")
			sd.call("set_step", "d2_duel")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(22)
		22:
			if frames < 3:
				return false
			sd.call("reset_state")
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d2_duel", "Continue restores d2_duel")
			_roam()
			_next(23)
		23:
			if frames < 45:
				return false
			_check(sr.markers.has("d2_duel") and sr.mission_node == null and fr.get("cine_player") == null, "Continue at d2_duel: the bank marker, the duel does not start by itself")
			fr.queue_free()
			_next(24)
		24:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", TMP)
			_check(bool(StoryChapters.rewind(sd, "d2_bridge")) and String(sd.get("step")) == "d2_bridge" and String(sd.get("last_nav")) == "roam", "Chọn cảnh: rewind to the bridge beat")
			_check(not sd.call("has_evidence", "E3") and int(sd.get("day")) == 2, "the snapshot is the state at the bridge beat (Day 2, no E3 yet)")
			_roam()
			_next(25)
		25:
			if frames < 45:
				return false
			_check(sr.markers.has("d2_bridge") and sr.mission_node == null, "after the rewind: the bridge marker, nothing starts by itself")
			fr.queue_free()
			return _end()
	return false


func _end() -> bool:
	for p: String in [TMP, SNAP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 2 (chase on Nguyễn Xiển, bridge horror, Sói Xám duel, E3 taken / skipped, call, continue, chapters)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
