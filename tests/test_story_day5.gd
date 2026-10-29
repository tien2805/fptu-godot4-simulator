# File: res://tests/test_story_day5.gd
# Headless end-to-end test of story Day 5 "Hầm server" (spec C-D8; plan 2026-10-26-phase-c-integration.md), from the end
# of Day 4: the call N = 3 -> the Day 5 morning (Mr.T and Anh Duy) -> the marker at Anh Duy's corner -> cine_d5_intro ->
# StoryDirector.launch_lair_beat -> the basement scene (StoryBasement: LairBasement at the origin, its own player stack)
# -> the stealth (unseen to the server room's mouth) -> cine_d5_monitors (staged in the real room with drop_set, the level's
# wall hidden, then frozen on the crash screen) -> the gunfight (2 waves, the seg_d5_gunfight replay) -> the typing battle
# (StoryHack on TypingCore: a typo resets the combo, leaks -> TOANG! -> retry, the processes killed, the final command, the
# room catches fire, the seg_d5_hack replay) -> choice 2 timing out on the honest "Từ chối" -> the refuse tail -> the Za
# Mẫn card -> the katana duel (down = TOANG! -> retry, the katana snaps) -> seg_d5_boss -> E6 -> cine_d5 -> back to free
# roam -> bed -> the call N = 2 -> the Day 6 placeholder. Then Continue mid-day (d5_hack: the marker, the scene resumes at
# the terminal, the wall frozen, no fire yet) and Chọn cảnh back to d5_choice: "Nhận lời" -> the accept tail -> end_c in
# free roam -> the save finished with ending C -> the main menu; Continue refuses it, the chapter snapshots remain.
# Wave 3 integration: a time-scale audit (tests/support/time_scale_audit.gd) watches the whole run (the domino and QTE slow
# motions, the director cuts, Impact): no frame with the scale off 1 and no owner, no owner holding it over 6 s, clean at
# the end.
# Run:  godot --headless --path . --script tests/test_story_day5.gd
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")

var TMP: String = "user://test_story_day5_%d.cfg" % OS.get_process_id()
var SNAP: String = "user://test_story_day5_snap_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_story_day5_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_story_day5_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_story_day5_backup_%d.cfg" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const BASEMENT: String = "res://scenes/story/StoryBasement.tscn"
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var bs: StoryBasement
var m: StoryMission
var mark: Dictionary = {}
var audit: Node = null


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 5 (Hầm server: basement scene, hack, choice 2 both branches, ending C, continue) ---")
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
	StoryBasement.test_opts = {"missions": {"manual": true, "manual_replay": true, "manual_card": true, "seed": 3},
		"cine": {"manual": true, "music": false}, "capture_mouse": false}
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
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


func _basement() -> void:
	bs = (load(BASEMENT) as PackedScene).instantiate()
	root.add_child(bs)


func _finish_cine_in(host: Node) -> String:
	var cp: CinePlayer = host.get("cine_player")
	if cp == null:
		return ""
	var slot: String = cp.timeline.slot
	var n: int = 0
	while host.get("cine_player") != null and n < 6000:
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


func _wait_bs_mission(cls: String, cap: int = 120) -> StoryMission:
	var mn: StoryMission = bs.mission_node if bs else null
	if mn != null and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start in the basement (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


func _ko_all(f: GunFight) -> void:
	for e: Variant in f.alive():
		if e is Gunman:
			var n: int = 0
			while not (e as Gunman).is_defeated() and n < 10:
				(e as Gunman).take_hit({"kind": "bullet", "from": bs.player.global_position})
				n += 1


func _step_replay(mn: StoryMission) -> bool:
	if mn == null or not is_instance_valid(mn) or mn.replay == null:
		return false
	var n: int = 0
	while is_instance_valid(mn) and mn.replay != null and n < 1200:
		mn.replay.step(DT)
		n += 1
	return true


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 70000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	if bs and is_instance_valid(bs) and bs.mission_node and bs.mission_node.state == "running" and bs.mission_node.replay == null:
		bs.mission_node.advance(DT)
	match phase:
		0:
			sd.call("new_story", {"female": false, "name": "Minh", "variant": 0, "hair_style": "short", "hair_color": 2, "skin": 2})
			sd.set("day", 4)
			for e: String in ["E1", "E3", "E4", "E5"]:
				(sd.get("evidence") as Array).append(e)
			(sd.get("choices") as Dictionary)["phuc"] = "cover"
			sd.call("_enter", "d4_call")
			_roam()
			_next(1)
		1:
			var n: int = _do_call()
			if n < 0:
				if frames > 150:
					_check(false, "the Day 4 call did not start")
					phase = 999
				return false
			_check(n == 3, "the call after Day 4 says 3")
			_next(2)
		2:
			if not _cine_started(fr, "Day 5 morning"):
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 5 and dc.left == 3, "Day 5 morning card (CÒN 3 NGÀY)")
			var duy: Array = (sd.get("texts") as Array).filter(func(t: Dictionary) -> bool: return String(t["from"]) == "Anh Duy" and int(t["day"]) == 5)
			_check(duy.size() == 1 and String(duy[0]["text"]).contains("The Beverly"), "Anh Duy's Day 5 text: the server under The Beverly")
			_finish_cine_in(fr)
			_next(3)
		3:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d5_stealth" and sr.markers.has("d5_stealth") and sr.mission_node == null, "the basement marker at Anh Duy's corner")
			_check(sr.start_marker("d5_stealth") and _finish_cine_in(fr) == "cine_d5_intro", "[E]: cine_d5_intro")
			_check(String(sd.get("last_nav")) == "lair:" + BASEMENT and String((sm.get("story_context") as Dictionary).get("lair", "")) == "basement", "the basement scene is launched")
			_check(String((sd.call("read_save", TMP) as Dictionary).get("step", "")) == "d5_stealth" and sd.get("spawn") is Transform3D, "saved at d5_stealth beside the marker")
			fr.queue_free()
			_next(4)
		4:
			if frames < 3:
				return false
			_basement()
			_next(5)
		5:
			m = _wait_bs_mission("MissionBasementStealth")
			if m == null:
				return false
			_check(bs.level != null and bs.level.wall.state == "off" and not bs.level.fire_on, "the basement: the monitor wall off, no fire yet")
			_check(StoryBasement.LAIR_MUSIC["stealth"] == "mission_basement" and (m as MissionSneak).fight.gunmen.size() == 3, "the stealth: 3 guards, mission_basement")
			_check(bs.weapons.current == WeaponData.Slot.PISTOL, "lair rule: armed in the basement")
			# W3 T1: the task looks go over the base and come off with the task
			_check(LookPresets.active(bs) == "server_red", "the basement base look: server_red")
			bs.look("server_blackout")
			_check(LookPresets.active(bs) == "server_blackout" and bs.looks == ["server_blackout"], "a task look applies over the base")
			var hk: String = String(StoryBasement.LAIR_MUSIC["hack"])
			_check(hk == (StoryBasement.FIRE_HACK_SLOT if MusicDirector.SLOTS.has(StoryBasement.FIRE_HACK_SLOT) else "mission_typing"), "the hack plays mission_fire_hack once the slot exists")
			bs.player.teleport((m as MissionSneak).pts["goal"], 0.0)
			_next(6)
		6:
			if not _cine_started(bs, "cine_d5_monitors", 120):
				return false
			_check(String(sd.get("step")) == "d5_monitors" and not bs.level.wall.get_parent().visible, "unseen: cine_d5_monitors, the level's wall hidden under the timeline's")
			var cp6: CinePlayer = bs.cine_player
			_check(cp6.stage_xf.is_equal_approx(bs.level.room_xf()) and cp6.stage.find_child("Room", true, false) == null, "staged in the real room (drop_set: no carried room)")
			_check(_finish_cine_in(bs) == "cine_d5_monitors", "the face on 50 monitors")
			_next(7)
		7:
			m = _wait_bs_mission("MissionBasementGunfight")
			if m == null:
				return false
			_check(bs.level.wall.state == "error" and bs.level.wall.get_parent().visible, "the wall frozen on Lọ Thần đã gặp sự cố")
			_check(LookPresets.active(bs) == "server_red" and bs.looks.is_empty(), "the stealth's look restored when it ended")
			var mg: MissionBasementGunfight = m
			_check(mg.fight.waves.size() == 3 and mg.fight.alive().size() == MissionBasementGunfight.WAVES[0], "the basement gunfight on Thường: 3 waves, the first down the stairs")
			_check(mg.fight.max_shooters == MissionBasementGunfight.SHOOTERS, "Thường: the mission's shooter cap")
			var w2: Array = mg.fight.waves[1]
			_check(String((w2.back() as Dictionary)["opts"].get("kind", "")) == "shield" and mg.fight.bullet_time != null and mg.fight.bullet_time.enabled,
				"wave 2 ends with the pallet-shield guard, bullet time on (the shared gun core live)")
			Difficulty.set_easy(true)
			var easy_sizes: Array = Difficulty.pick(MissionBasementGunfight.WAVES, MissionBasementGunfight.WAVES_EASY)
			Difficulty.set_easy(false)
			_check(easy_sizes.size() == 2 and mg.wave_sizes.size() == 3, "Dễ: 2 waves (the mission reads Difficulty.pick)")
			_check(mg.cuts == 1 and mg.beats.has("stairs"), "wave 1: a preview cut down the stairs")
			_check(bs.extra_targets.size() == LairBasement.RACK_ROWS.size(), "one labelled rack per row, shootable")
			# the domino: row 0 (x -7, tips +x into the left aisle); one guard under it, one beside it
			var tg: Node3D = bs.level.racks[0]["target"]
			var o: Vector3 = bs.player.global_position + Vector3(0.0, 1.5, 0.0)
			var h: Dictionary = bs.weapons.first_hit(o, (tg.global_position + Vector3(0.0, 0.9, 0.0) - o).normalized(), 60.0)
			_check(String(h["kind"]) == "soft" and h.get("node") == tg, "a bullet at the label hits it (soft target)")
			mark["cover0"] = mg.fight.cover.count()
			mark["under"] = mg.fight.alive()[0]
			mark["beside"] = mg.fight.alive()[1]
			bs.weapons.hit_target(tg, {"kind": "bullet", "from": bs.player.global_position})
			_check(float(bs.level.racks[0]["t"]) >= 0.0 and mg.dominoes == 1 and mg.beats.has("domino"), "shooting the label tips the row")
			_next(71)
		71:
			var gu: Gunman = mark["under"]
			var gb: Gunman = mark["beside"]
			if RadialWheel.scale_owner is Impact and Engine.time_scale < 0.5:
				mark["slow"] = true
			if not bool(bs.level.racks[0]["fallen"]):
				gu.global_position = bs.level.world(Vector3(-5.5, 0.0, 14.0))
				gb.global_position = bs.level.world(Vector3(-3.0, 0.0, 14.0))
				if frames > 600:
					_check(false, "the row did not fall")
					phase = 999
				return false
			var mg71: MissionBasementGunfight = m
			_check(gu.is_defeated() and not gb.is_defeated() and mg71.domino_kos == 1, "the domino knocks out only the guard under the racks")
			_check(mark.has("slow"), "the fall in slow motion (Impact clock, after the preview cut)")
			_check(mg71.cover_rows.has(0) and mg71.fight.cover.count() > int(mark["cover0"]), "the fallen racks are new low cover slots")
			_next(72)
		72:
			if frames < 90:
				return false
			_check(RadialWheel.scale_owner == null and is_equal_approx(Engine.time_scale, 1.0), "the slow motion handed the time scale back")
			_next(8)
		8:
			var mg8: MissionGunfight = m as MissionGunfight if is_instance_valid(m) else null
			if mg8 and mg8.fight and mg8.fight.state == "running":
				_ko_all(mg8.fight)
			if mg8 and mg8 is MissionBasementGunfight:
				mark["gf_cuts"] = (mg8 as MissionBasementGunfight).cuts
				mark["gf_beats"] = (mg8 as MissionBasementGunfight).beats.duplicate()
			if mg8 and _step_replay(mg8):
				mark["gf"] = true
			if String(sd.get("step")) != "d5_hack":
				if frames > 1500:
					_check(false, "the basement gunfight was not won")
					phase = 999
				return false
			_check(mark.has("gf"), "the seg_d5_gunfight replay")
			_check(mark.has("gf_cuts") and int(mark["gf_cuts"]) == 3, "a preview cut per wave (stairs, door, labelled rack): %s" % str(mark.get("gf_cuts", -1)))
			_check(mark.has("gf_beats") and (mark["gf_beats"] as Array).has("door") and (mark["gf_beats"] as Array).has("both_ends") and (mark["gf_beats"] as Array).has("taunt") and bs.level.door_open, "the side door kicked open, both ends, Za Mẫn's taunts")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(SNAP))
			_next(9)
		9:
			m = _wait_bs_mission("MissionHack")
			if m == null:
				return false
			var mh: MissionHack = m
			var h: StoryHack = mh.hack
			_check(h != null and h.active and h.visible and not bs.player.controls_enabled, "the typing battle: the terminal open, the player at the desk")
			_check(bs.player.global_position.distance_to(bs.level.world(LairBasement.TERMINAL_SPOT)) < 0.3, "at the terminal")
			h.step(2.0)
			_check(h.bullets.size() >= 1 and String(h.bullets[0]["word"]) in (StoryHack.WORDS[0] as Array), "Lọ Thần's processes fall (wave 1 words)")
			_check(h.type_char("z") == "typo" and h.typos == 1 and h.combo == 0, "a typo resets the combo")
			var n9: int = 0
			while h.active and n9 < 600:
				h.step(0.1)
				n9 += 1
			_check(h.leaks >= StoryHack.MAX_LEAKS and mh.state == "failed", "leaked processes: Lọ Thần sends the exam out")
			_next(10)
		10:
			if not (bs.fail_ui and bs.fail_ui.visible):
				if frames > 60:
					_check(false, "the hack failed but no TOANG!")
					phase = 999
				return false
			_check(bs.fail_ui.title_label.text == "TOANG!", "TOANG! in the basement")
			bs.fail_ui.press_retry()
			var h10: StoryHack = (m as MissionHack).hack
			_check(h10.active and h10.leaks == 0 and is_equal_approx(h10.hp, h10.hp_max), "retry: a fresh run")
			# kill every process until the final command
			var n10: int = 0
			while h10.final_bullet.is_empty() and n10 < 400:
				h10.step(0.4)
				for b: Dictionary in h10.bullets.duplicate():
					if not bool(b["dead"]):
						h10.type_text(String(b["word"]))
				n10 += 1
			_check(not h10.final_bullet.is_empty() and h10.kills >= 5 and h10.max_combo >= 6, "every process killed (%d, combo %d): the final command shows" % [h10.kills, h10.max_combo])
			_check(TypingCore.mult(12) == 3 and TypingCore.damage("abc", true, 2) == 36, "the Stage 6 rules (TypingCore)")
			_check(h10.type_text(StoryHack.FINAL_COMMAND) == "won", "sudo rm -rf lothan: wiped")
			_check(bs.level.fire_on, "the server room catches fire")
			_next(11)
		11:
			var mh11: MissionHack = m as MissionHack if is_instance_valid(m) else null
			if mh11 and _step_replay(mh11):
				mark["hack"] = true
			if not _cine_started(bs, "cine_d5_choice", 300):
				return false
			_check(mark.has("hack"), "the seg_d5_hack replay")
			var cp11: CinePlayer = bs.cine_player
			_check(cp11.timeline.slot == "cine_d5_choice" and String(sd.call("choice_of", "zaman_offer")) == "", "the burning room: choice 2 not answered yet")
			_check(_finish_cine_in(bs) == "cine_d5_choice" and String(sd.call("choice_of", "zaman_offer")) == "refuse" and cp11.choice_timed_out, "timeout: the honest Từ chối is taken")
			_next(12)
		12:
			if not _cine_started(bs, "the refuse tail", 120):
				return false
			_check(_finish_cine_in(bs) == "cine_d5_choice_refuse", "Từ chối: the refuse tail")
			_next(13)
		13:
			m = _wait_bs_mission("MissionDuel")
			if m == null:
				return false
			var md: MissionDuel = m
			_check(md.card != null and String(md.card.data.get("name", "")) == "Lê Minh Za Mẫn" and String(md.card.data.get("nick", "")) == "CTO · đang pivot", "the villain card: Lê Minh Za Mẫn, CTO · đang pivot")
			_check(md.duel.boss != null and md.duel.boss.staged and md.duel.state != "running", "Za Mẫn stands staged during the card")
			_check(LookPresets.active(bs) == "server_red", "the duel starts on the base look")
			bs.look("server_sprinkler")
			var n13: int = 0
			while md.card != null and n13 < 600:
				md.card.step(DT)
				n13 += 1
			_check(md.duel.state == "running" and String(md.duel.boss.body.get_meta("cast_id", "")) == "za_man", "the katana duel starts (Za Mẫn's StoryCast look)")
			md.duel.combat.receive_attack(md.duel.boss, {"damage": 999.0})
			_next(14)
		14:
			if not (bs.fail_ui and bs.fail_ui.visible):
				if frames > 60:
					_check(false, "down in the duel but no TOANG!")
					phase = 999
				return false
			bs.fail_ui.press_retry()
			var md14: MissionDuel = m
			_check(md14.duel.state == "running" and is_equal_approx(md14.duel.combat.hp, 100.0) and md14.card == null, "retry: a fresh Za Mẫn, no second card")
			_next(15)
		15:
			var md15: MissionDuel = m as MissionDuel if is_instance_valid(m) else null
			if md15 and md15.duel and md15.duel.in_qte:
				for k: String in ["q", "lmb", "e"]:
					md15.duel.qte.press(k)          # W3 T6: the QTE finisher at 0 HP
				mark["qte"] = md15.duel.qte_clean
			elif md15 and md15.duel and md15.duel.boss and md15.duel.state == "running":
				md15.duel.boss.take_strike({"kind": "slash1", "dmg": 999.0, "stagger": 0.0, "from": bs.player.global_position})
			if bs.cine_player == null:
				if frames > 1200:
					_check(false, "the duel was not won (%s)" % (md15.duel.state if md15 and md15.duel else "gone"))
					phase = 999
				return false
			_check(bs.cine_player.timeline.slot == "seg_d5_boss" and sd.call("has_evidence", "E6"), "the katana snaps: seg_d5_boss, E6 guaranteed")
			_check(bs.looks.is_empty() and LookPresets.active(bs) == "server_red", "the duel's look restored when it ended")
			_check(bool(mark.get("qte", false)), "the katana QTE finisher passed first time")
			_finish_cine_in(bs)
			_next(16)
		16:
			if not _cine_started(bs, "cine_d5", 120):
				return false
			_check(_finish_cine_in(bs) == "cine_d5", "cine_d5: the money flow points to Trà Sữa Lọ")
			_next(17)
		17:
			if not bs.left:
				if frames > 60:
					_check(false, "the basement did not hand back after cine_d5")
					phase = 999
				return false
			_check(String(sd.get("step")) == "d5_bed" and String(sd.get("last_nav")) == "roam", "back to story free roam for bed")
			for id: String in ["d5_stealth", "d5_monitors", "d5_gunfight", "d5_hack", "d5_choice", "d5_duel", "d5_end"]:
				_check(StoryChapters.is_beat_unlocked(id) and not StoryChapters.snapshot(id).is_empty(), "Chọn cảnh: %s snapshotted" % id)
			bs.queue_free()
			bs = null
			_next(18)
		18:
			if frames < 3:
				return false
			_roam()
			_next(19)
		19:
			if frames < 40:
				return false
			_check(sr.markers.has("d5_bed"), "the bed marker")
			_check(sr.start_marker("d5_bed"), "bed")
			_next(20)
		20:
			var n20: int = _do_call()
			if n20 < 0:
				if frames > 150:
					_check(false, "the Day 5 call did not start")
					phase = 999
				return false
			_check(n20 == 2, "the call after Day 5 says 2")
			_next(21)
		21:
			if not _cine_started(fr, "Day 6 morning"):
				return false
			_finish_cine_in(fr)
			_next(22)
		22:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d6_locked" and String(sd.get("objective")) == "Ngày 6: Trà Sữa Lọ – sắp có trong bản cập nhật sau" and sr.markers.is_empty(), "the Day 6 placeholder")
			_check(String(sd.call("evaluate_ending", sd.call("to_dict"))) != "C" and sd.call("has_evidence", "E6"), "refused: not ending C, E6 kept")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(23)
		23:
			# Continue mid-day: d5_hack
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", SNAP)
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d5_hack", "Continue restores d5_hack")
			_roam()
			_next(24)
		24:
			if frames < 40:
				return false
			_check(sr.markers.has("d5_hack") and sr.mission_node == null and fr.get("cine_player") == null, "Continue: the basement marker, nothing starts by itself")
			_check(sr.start_marker("d5_hack") and String(sd.get("last_nav")) == "lair:" + BASEMENT, "[E]: back into the basement (no intro again)")
			fr.queue_free()
			_next(25)
		25:
			if frames < 3:
				return false
			_basement()
			_next(26)
		26:
			m = _wait_bs_mission("MissionHack")
			if m == null:
				return false
			_check(bs.level.wall.state == "error" and not bs.level.fire_on, "resumed at the terminal: the wall frozen, no fire yet")
			bs.abort_mission()
			_check(bs.left and String(sd.get("step")) == "d5_hack" and String(sd.get("last_nav")) == "roam", "VỀ THẾ GIỚI MỞ: back to free roam, the beat stays")
			bs.queue_free()
			bs = null
			_next(27)
		27:
			# Chọn cảnh: back to choice 2, this time "Nhận lời"
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", TMP)
			_check(bool(StoryChapters.rewind(sd, "d5_choice")) and String(sd.get("step")) == "d5_choice" and String(sd.call("choice_of", "zaman_offer")) == "",
				"Chọn cảnh: rewind to choice 2 (unanswered)")
			_roam()
			_next(28)
		28:
			if frames < 40:
				return false
			_check(sr.markers.has("d5_choice") and sr.start_marker("d5_choice") and String(sd.get("last_nav")) == "lair:" + BASEMENT, "the choice marker launches the basement")
			fr.queue_free()
			_next(29)
		29:
			if frames < 3:
				return false
			_basement()
			_next(30)
		30:
			if not _cine_started(bs, "cine_d5_choice (accept run)", 120):
				return false
			_check(bs.level.fire_on, "the room burns for the choice (restored from the step)")
			var cp30: CinePlayer = bs.cine_player
			var n30: int = 0
			while cp30.choice_node == null and bs.cine_player != null and n30 < 3000:
				cp30.step(DT)
				n30 += 1
			_check(cp30.choice_node != null, "choice 2 opens")
			cp30.choice_node.pick("accept")
			_check(_finish_cine_in(bs) == "cine_d5_choice" and String(sd.call("choice_of", "zaman_offer")) == "accept", "Nhận lời is recorded")
			_next(31)
		31:
			if not _cine_started(bs, "the accept tail", 120):
				return false
			_check(_finish_cine_in(bs) == "cine_d5_choice_accept", "the accept tail (the handshake)")
			_next(32)
		32:
			if not bs.left:
				if frames > 60:
					_check(false, "the basement did not hand back for end_c")
					phase = 999
				return false
			_check(String(sd.get("step")) == "d5_end_c", "accept -> d5_end_c")
			bs.queue_free()
			bs = null
			_next(33)
		33:
			if frames < 3:
				return false
			_roam()
			_next(34)
		34:
			if not _cine_started(fr, "end_c", 200):
				return false
			_check(fr.get("cine_player").timeline.slot == "end_c", "end_c plays in free roam (CEO of Lọ Thần 10.0, credits)")
			_finish_cine_in(fr)
			_next(35)
		35:
			if frames < 3:
				return false
			_check(String(sd.get("ending")) == "C" and not bool(sd.get("active")) and String(sd.get("last_nav")) == "menu", "ending C: the story ends, the main menu")
			var sv: Dictionary = sd.call("read_save", TMP)
			_check(String(sv.get("ending", "")) == "C" and String(sd.call("evaluate_ending", sv)) == "C", "the save is marked finished with ending C")
			sd.call("reset_state")
			_check(not bool(sd.call("continue_story")), "Continue refuses the finished story")
			_check(not StoryChapters.snapshot("d5_choice").is_empty() and StoryChapters.has_unlocks(), "Chọn cảnh can still rewind it")
			fr.queue_free()
			return _end()
	return false


func _end() -> bool:
	if audit:
		print("  ", audit.call("report"))
		_check(bool(audit.call("clean", 6.0)), "the time scale stayed in the owner protocol (%s)" % String(audit.call("report")))
	for p: String in [TMP, SNAP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	StoryBasement.test_opts = {}
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 5 (basement scene, stealth, monitors, gunfight, hack, choice 2 refuse + accept, katana, E6, ending C, continue)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
