# File: res://tests/test_story_day7.gd
# Headless end-to-end test of story Day 7 "Học thật, đậu thật" (plan 2026-11-01-w4-day7.md T1), from d7_start: the Day 7
# morning (CÒN 1 NGÀY, Anh Duy's text) -> the 08:00 clock on the free-roam HUD -> the marker at Anh Duy's corner ->
# cine_d7_intro -> StoryDirector.launch_lair_beat -> the tower scene (StoryTower: LairTower, the player stack, the bike, the
# clock) -> the parking deck (BikeChase on the ring: knocked off = TOANG -> retry; the Bầy Sói riding off = TOANG -> retry;
# Sói Xám's return card on the last wave) -> the warehouse (Alexander's return card, down -> retry, the forklift topples)
# -> the server floor (Za Mẫn's return card, the cheaper katana: no sprinklers, down -> retry, the QTE) -> the mannequin
# showroom (the lift) -> the laser corridor (a beam = BỊ LỘ -> retry at the lift; the blink wall's telegraph buzzes once;
# the goal -> seg_d7_floors) -> boss phase 1 (Lọ's card, the vase plinths as cover, his guards, then Lọ himself with six
# guards' HP -> seg_d7_phase1) -> cine_d7_monologue in the real gallery (the clock frozen, its HUD hidden) -> phase 2, the
# blackout (the look, the flashlight, Lọ stalks: the telegraph cracks a vase and lights a speaker, his lunge hits, the
# beam staggers him, down -> retry with the power off again, the two breakers -> the power back -> seg_d7_phase2 in the
# real gallery, T4: the two plinths under its own hidden, then back) -> phase 3 on the roof
# (the rain, the searchlight, the rain-mode SwordDuel, down -> retry, the QTE "Đòn chân kẹp cổ số 21") ->
# seg_d7_finisher on the real roof (T4: the level's helicopter, light and rain hidden, then back) -> the typing
# showdown (Lọ Thần 10.0's pools, the clock runs out = "08:00" and the terminal freezes -> THỬ LẠI with the grace and Anh
# Duy's line -> every process killed -> sudo rm -rf lothan10) -> the hand-off to d7_ending (the endings stream; until it is
# merged the scene records it and leaves the step at d7_typing).
# A time-scale audit (tests/support/time_scale_audit.gd) watches the whole run.
# Run:  godot --headless --path . --script tests/test_story_day7.gd
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")

var TMP: String = "user://test_story_day7_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_story_day7_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_story_day7_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_story_day7_backup_%d.cfg" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const TOWER: String = "res://scenes/story/StoryTower.tscn"
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var tw: StoryTower
var m: StoryMission
var mark: Dictionary = {}
var audit: Node = null


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 7 (Lọ Academy: floors, boss phases 1-3, typing, the 08:00 clock, the hand-off) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	StoryTower.test_opts = {"missions": {"manual": true, "manual_replay": true, "manual_card": true, "seed": 3},
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


func _next(p: int) -> void:
	phase = p
	frames = 0


func _wait_mission(cls: String, cap: int = 120) -> StoryMission:
	var mn: StoryMission = tw.mission_node if tw else null
	if mn != null and is_instance_valid(mn) and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start in the tower (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


## Waits for the fail card; false (and a failed check after `cap` frames) until it shows.
func _fail_shown(what: String, cap: int = 90) -> bool:
	if tw.fail_ui and tw.fail_ui.visible:
		return true
	if frames > cap:
		_check(false, "%s but no fail card" % what)
		phase = 999
	return false


## Waits until the director's step is `id` (the tower moved on).
func _at_step(id: String, what: String, cap: int = 1500) -> bool:
	if String(sd.get("step")) == id:
		return true
	if frames > cap:
		_check(false, "%s (step %s)" % [what, String(sd.get("step"))])
		phase = 999
	return false


func _step_card(mn: Object) -> void:
	var n: int = 0
	while mn.get("card") != null and n < 600:
		(mn.get("card") as StoryVillainCard).step(DT)
		n += 1


func _ko_all(f: GunFight, hits: int = 12) -> void:
	for e: Variant in f.alive():
		if e is Gunman:
			var n: int = 0
			while not (e as Gunman).is_defeated() and n < hits:
				(e as Gunman).take_hit({"kind": "bullet", "from": tw.player.global_position})
				n += 1


func _step_replay(mn: StoryMission) -> bool:
	if mn == null or not is_instance_valid(mn) or mn.replay == null:
		return false
	var n: int = 0
	while is_instance_valid(mn) and mn.replay != null and n < 1200:
		mn.replay.step(DT)
		n += 1
	return true


func _advance(mn: StoryMission, secs: float) -> void:
	var n: int = 0
	while n < int(secs / DT) and is_instance_valid(mn) and mn.state == "running":
		mn.advance(DT)
		n += 1


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 70000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	if tw and is_instance_valid(tw) and tw.mission_node and is_instance_valid(tw.mission_node) and tw.mission_node.state == "running" \
			and tw.mission_node.replay == null and not paused:
		tw.mission_node.advance(DT)
	match phase:
		0:
			sd.call("new_story", {"female": true, "name": "Lan", "variant": 0, "hair_style": "short", "hair_color": 2, "skin": 2})
			sd.set("day", 6)
			for e: String in ["E1", "E2", "E3", "E4", "E5", "E6", "E7"]:
				(sd.get("evidence") as Array).append(e)
			(sd.get("choices") as Dictionary)["phuc"] = "cover"
			(sd.get("choices") as Dictionary)["zaman_offer"] = "refuse"
			(sd.get("choices") as Dictionary)["bribe"] = "refuse"
			sd.call("_enter", "d7_start")
			_check(int(sd.get("day")) == 7 and String(sd.get("step")) == "d7_morning", "d7_start: Day 7, the morning beat")
			_check(is_equal_approx(Day7Clock.remaining(sd), Day7Clock.START_S) and Day7Clock.clock_text(Day7Clock.remaining(sd)) == "05:30", "the clock starts at 05:30")
			_roam()
			_next(1)
		1:
			if not _cine_started(fr, "Day 7 morning"):
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 7 and dc.left == 1, "Day 7 morning card (CÒN 1 NGÀY)")
			var duy: Array = (sd.get("texts") as Array).filter(func(t: Dictionary) -> bool: return String(t["from"]) == "Anh Duy" and int(t["day"]) == 7)
			_check(duy.size() == 1 and String(duy[0]["text"]).contains("08:00") and String(duy[0]["text"]).contains("Dịch:"), "Anh Duy's Day 7 text: 08:00, with its translation")
			_finish_cine_in(fr)
			_next(2)
		2:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d7_parking" and sr.markers.has("d7_parking") and sr.mission_node == null, "the tower marker at Anh Duy's corner")
			var ck: Day7Clock = sr.day7_clock
			if ck:
				ck.refresh()
			_check(ck != null and ck.visible and ck.time_label.text == "05:30" and ck.sub_label.text == Day7Clock.T_SUB, "the 08:00 clock on the free-roam HUD (05:30)")
			_check(sr.start_marker("d7_parking") and _finish_cine_in(fr) == "cine_d7_intro", "[E]: cine_d7_intro")
			_check(String(sd.get("last_nav")) == "lair:" + TOWER and String((sm.get("story_context") as Dictionary).get("lair", "")) == "tower", "the tower scene is launched")
			_check(String((sd.call("read_save", TMP) as Dictionary).get("step", "")) == "d7_parking", "saved at d7_parking")
			_check(is_equal_approx(Day7Clock.remaining(sd), Day7Clock.START_S), "the clock did not run in free roam or the intro")
			fr.queue_free()
			_next(3)
		3:
			if frames < 3:
				return false
			tw = (load(TOWER) as PackedScene).instantiate()
			root.add_child(tw)
			_next(4)
		# ----- the parking deck -----
		4:
			m = _wait_mission("MissionTowerParking")
			if m == null:
				return false
			var mp: MissionTowerParking = m
			var ch: BikeChase = mp.chase
			_check(tw.level.current_floor == "parking" and String(StoryTower.LAIR_MUSIC["parking"]) == "mission_tower", "the parking deck shows, mission_tower")
			_check(ch != null and ch.state == "running" and tw.mounted and tw.bike.visible, "the chase runs on the protagonist's own bike")
			_check(ch.route != null and ch.route.length > 2000.0 and absf(ch.start_s - MissionTowerParking.START_S) < 0.5 and ch.waves.size() == 3, "the ring route (%.0f m), 3 waves" % (ch.route.length if ch.route else -1.0))
			_check(is_equal_approx(tw.bike.max_speed_ms, MissionTowerParking.PROFILE["max_speed_ms"]), "the deck profile caps the bike")
			_check(tw.bike.global_position.distance_to(ch.route_transform(MissionTowerParking.START_S).origin) < 2.0, "placed on the ring")
			var hud_ok: bool = tw.clock_hud != null
			if hud_ok:
				tw.clock_hud.refresh()
			_check(hud_ok and tw.clock_hud.visible and tw.clock_hud.time_label.text == "05:30", "the clock HUD in the tower")
			ch.combat.damage(999.0, "kick", 1)
			_next(5)
		5:
			if not _fail_shown("knocked off the bike"):
				return false
			var mp5: MissionTowerParking = m
			_check(tw.fail_ui.title_label.text == "TOANG!" and tw.fail_ui.reason_label.text == MissionTowerParking.T_KNOCKED, "knocked off: TOANG!")
			tw.fail_ui.press_retry()
			_check(mp5.chase.state == "running" and is_equal_approx(mp5.chase.combat.stability, BikeCombatData.STABILITY_MAX) and tw.mounted, "THỬ LẠI: the chase again, stability full, on the bike")
			mp5.chase.end_at_s = maxf(mp5.chase.s_p, 0.0)           # ride to the deck's end with the wolves still up
			_next(51)
		51:
			if not _fail_shown("the bikers rode off"):
				return false
			var mp51: MissionTowerParking = m
			_check(tw.fail_ui.reason_label.text == MissionTowerParking.T_ESCAPED and mp51.escaped_fail and mp51.chase.escaped > 0, "the Bầy Sói ride up to warn Lọ: TOANG!")
			mp51.chase.end_at_s = -1.0
			tw.fail_ui.press_retry()
			_check(mp51.chase.state == "running" and not mp51.escaped_fail, "THỬ LẠI after the escape")
			_next(6)
		6:
			var mp6: MissionTowerParking = m as MissionTowerParking if is_instance_valid(m) else null
			var ch6: BikeChase = mp6.chase if mp6 else null
			if ch6 and is_instance_valid(ch6) and ch6.state == "running" and not paused:
				for b: Variant in ch6.alive():
					(b as BikerEnemy).crash("test")
			if mp6 != null and mp6.card != null and not mark.has("card6"):
				mark["card6"] = true
				_check(String(mp6.card.data.get("name", "")) == "Sói Xám" and String(mp6.card.data.get("nick", "")).begins_with("tái xuất") and ch6.wave == 2,
					"the last wave: Sói Xám's return card")
				_check(paused, "the card pauses the tree")
				_step_card(mp6)
				var sx: Array = ch6.bikers.filter(func(b: Variant) -> bool: return is_instance_valid(b) and String((b as BikerEnemy).label) == "Sói Xám")
				_check(sx.size() == 1 and String((sx[0] as BikerEnemy).body.get_meta("cast_id", "")) == "soi_xam", "Sói Xám rides with his own look")
			if frames % 600 == 0 and ch6 and is_instance_valid(ch6):
				print("    parking: state %s wave %d alive %d pending %d remaining %d paused %s mission %s" % [ch6.state, ch6.wave, ch6.alive_count(), ch6.pending.size(), ch6.remaining(), str(paused), mp6.state if mp6 else "-"])
			if not _at_step("d7_warehouse", "the parking chase was not won", 4000):
				return false
			_check(Day7Clock.remaining(sd) < Day7Clock.START_S, "the clock ran during the chase (%.1f s used)" % (Day7Clock.START_S - Day7Clock.remaining(sd)))
			_check(mark.has("card6") and bool((sd.get("flags") as Dictionary).get(MissionTowerParking.CARD_FLAG, false)), "Sói Xám's card shown once (flag)")
			_check(not tw.mounted and tw.player.visible, "off the bike after the deck")
			var sv: Dictionary = sd.call("read_save", TMP)
			_check(float((sv.get("flags", {}) as Dictionary).get(Day7Clock.FLAG, -1.0)) < Day7Clock.START_S, "the clock is saved with the story")
			_check((sd.get("ranks") as Dictionary).has("d7_parking"), "a rank for the parking deck")
			_next(7)
		# ----- the warehouse -----
		7:
			m = _wait_mission("MissionTowerForklift")
			if m == null:
				return false
			var mf: MissionTowerForklift = m
			_check(tw.level.current_floor == "warehouse", "the warehouse floor shows")
			_check(mf.card != null and String(mf.card.data.get("name", "")) == "Alexander ABCXYZ" and String(mf.card.data.get("nick", "")).begins_with("tái xuất"), "Alexander's return card")
			_step_card(mf)
			var boss: ForkliftBoss = mf.fight.boss as ForkliftBoss
			_check(boss != null and String(boss.driver.get_meta("cast_id", "")) == "alexander" and mf.pf != null and mf.crane == null, "Alexander on his new forklift, the player's forklift, no crane")
			_check(mf.markers != null and mf.markers.is_tracked(boss.forklift), "Alexander marked off screen")
			mf.fight.combat.receive_attack(boss, {"damage": 999.0})
			_next(8)
		8:
			if not _fail_shown("down vs the forklift"):
				return false
			tw.fail_ui.press_retry()
			var mf8: MissionTowerForklift = m
			var b8: ForkliftBoss = mf8.fight.boss as ForkliftBoss
			_check(mf8.fight.state == "running" and b8 != null and is_equal_approx(b8.hp, b8.max_hp) and mf8.card == null, "retry: a fresh Alexander, no second card")
			b8.apply_damage(99999.0)
			_next(9)
		9:
			if not _at_step("d7_servers", "the forklift did not topple", 900):
				return false
			_next(10)
		# ----- the server floor -----
		10:
			m = _wait_mission("MissionTowerKatana")
			if m == null:
				return false
			var mk: MissionTowerKatana = m
			_check(tw.level.current_floor == "servers", "the server floor shows")
			_check(mk.card != null and String(mk.card.data.get("name", "")) == "Lê Minh Za Mẫn" and String(mk.card.data.get("nick", "")).contains("49"), "Za Mẫn's return card (katana 49 nghìn)")
			_check(mk.duel.boss != null and mk.duel.boss.staged and mk.duel.state != "running", "Za Mẫn stands staged during the card")
			_step_card(mk)
			var zm: KatanaBoss = mk.duel.boss
			_check(mk.duel.state == "running" and String(zm.body.get_meta("cast_id", "")) == "za_man", "the duel starts")
			var want_hp: float = float(SwordData.ZA_MAN["hp"]) * SwordData.HP_SCALE * MissionTowerKatana.KATANA_HP_K
			_check(absf(zm.max_hp - want_hp) < 0.5, "the cheap katana: less HP (%.0f, want %.0f)" % [zm.max_hp, want_hp])
			mk.duel.call("_on_hp", 0.3)               # under SPRINKLE_AT: Day 5 would start the sprinklers here
			_check(not mk.duel.sprinklers_on, "no sprinklers on this floor")
			mk.duel.combat.receive_attack(zm, {"damage": 999.0})
			_next(11)
		11:
			if not _fail_shown("down in the katana duel"):
				return false
			tw.fail_ui.press_retry()
			var mk11: MissionTowerKatana = m
			_check(mk11.duel.state == "running" and is_equal_approx(mk11.duel.combat.hp, 100.0) and mk11.card == null and mk11.duel.sprinkler_starts == 1, "retry: a fresh Za Mẫn, still no sprinklers")
			_next(12)
		12:
			var mk12: MissionTowerKatana = m as MissionTowerKatana if is_instance_valid(m) else null
			if mk12 and mk12.duel and mk12.duel.in_qte:
				for k: String in ["q", "lmb", "e"]:
					mk12.duel.qte.press(k)
				mark["qte12"] = mk12.duel.qte_clean
			elif mk12 and mk12.duel and mk12.duel.boss and mk12.duel.state == "running":
				mk12.duel.boss.take_strike({"kind": "slash1", "dmg": 999.0, "stagger": 0.0, "from": tw.player.global_position})
			if not _at_step("d7_mannequins", "the katana duel was not won", 1200):
				return false
			_check(bool(mark.get("qte12", false)), "the katana QTE passed")
			_check(is_equal_approx(Engine.time_scale, 1.0), "the QTE slow motion handed the time back")
			_next(13)
		# ----- the mannequin showroom -----
		13:
			m = _wait_mission("MissionTowerStealth")
			if m == null:
				return false
			var ms: MissionTowerStealth = m
			_check(tw.level.current_floor == "mannequins" and ms.fight.gunmen.size() == LairTower.MN_PATROLS.size(), "the showroom: %d guards on patrol" % LairTower.MN_PATROLS.size())
			_check(ms.guide != null and not ms.spotted, "the lift is guided, unseen so far")
			_check(tw.player.global_position.distance_to(ms.pts["start"]) < 1.0, "at the showroom's start")
			tw.player.teleport(ms.pts["goal"], 0.0)
			_next(14)
		14:
			if not _at_step("d7_lasers", "the lift was not reached", 300):
				return false
			_next(15)
		# ----- the laser corridor -----
		15:
			m = _wait_mission("MissionTowerLasers")
			if m == null:
				return false
			var ml: MissionTowerLasers = m
			_check(tw.level.current_floor == "gallery" and ml.beams.size() == ml.defs.size() and ml.defs.size() >= 14, "the laser corridor: %d beams" % ml.beams.size())
			_check(tw.player.global_position.distance_to(ml.pts["start"]) < 1.0, "at the lift end of the corridor")
			# into the first static beam (z 43, from the left wall to x 0.7)
			tw.player.teleport(tw.level.world("gallery", Vector3(-1.0, 0.0, 43.0)), 0.0)
			_next(16)
		16:
			if not _fail_shown("a beam touched"):
				return false
			var ml16: MissionTowerLasers = m
			_check(tw.fail_ui.title_label.text == "BỊ LỘ" and tw.fail_ui.reason_label.text == MissionTowerLasers.T_TRIPPED and ml16.trips == 1 and ml16.cues_played.has("alarm_siren"), "a lit beam: BỊ LỘ with the alarm")
			tw.fail_ui.press_retry()
			_check(ml16.state == "running" and is_equal_approx(ml16.t, 0.0) and tw.player.global_position.distance_to(ml16.pts["start"]) < 1.0, "THỬ LẠI: back at the lift, the beams from zero")
			# beside the first blinking wall (z 34): its telegraph buzzes once for the four beams
			tw.player.teleport(tw.level.world("gallery", Vector3(0.0, 0.0, 36.0)), 0.0)
			mark["buzz0"] = ml16.buzzes
			_next(17)
		17:
			var ml17: MissionTowerLasers = m
			if ml17.t < 3.3:
				if ml17.state != "running":
					_check(false, "tripped beside the blink wall (%s)" % tw.fail_ui.reason_label.text if tw.fail_ui else "?")
					phase = 999
				return false
			_check(ml17.buzzes - int(mark["buzz0"]) == 1, "the blink wall's telegraph buzzed once (%d)" % (ml17.buzzes - int(mark["buzz0"])))
			_check(ml17.cues_played.has("fluoro_buzz"), "the telegraph cue")
			tw.player.teleport(ml17.pts["goal"], 0.0)
			_next(18)
		18:
			var ml18: MissionTowerLasers = m as MissionTowerLasers if is_instance_valid(m) else null
			if ml18 and _step_replay(ml18):
				mark["floors"] = true
			if not _at_step("d7_boss1", "the laser corridor was not crossed", 600):
				return false
			_check(mark.has("floors"), "the seg_d7_floors replay")
			_next(19)
		# ----- boss phase 1: the vase gallery -----
		19:
			m = _wait_mission("MissionBossGuns")
			if m == null:
				return false
			var mg: MissionBossGuns = m
			_check(mg.card != null and String(mg.card.data.get("name", "")) == "Lùm Văn Lọ" and String(mg.card.data.get("nick", "")) == "hiệu trưởng Lọ Academy", "the villain card: Lùm Văn Lọ, hiệu trưởng Lọ Academy")
			_step_card(mg)
			_check(String(StoryTower.LAIR_MUSIC["boss_guns"]) == "boss_d7" and LookPresets.active(tw) == "penthouse", "boss_d7, the gold-and-black look")
			_check(mg.fight.waves.size() == 2 and mg.fight.alive().size() == 3 and tw.weapons.current == WeaponData.Slot.PISTOL, "wave 1: his three guards, armed")
			_check(mg.fight.cover.count() >= tw.level.vases.size(), "the vase plinths are cover (%d slots)" % mg.fight.cover.count())
			mg.fight.combat.receive_attack(mg.fight.gunmen[0], {"damage": 999.0})
			_next(20)
		20:
			if not _fail_shown("down in the gallery"):
				return false
			tw.fail_ui.press_retry()
			var mg20: MissionBossGuns = m
			_check(mg20.fight.state == "running" and mg20.card == null, "retry: the gunfight again, no second card")
			_next(21)
		21:
			var mg21: MissionBossGuns = m as MissionBossGuns if is_instance_valid(m) else null
			if mg21 and mg21.fight and mg21.fight.state == "running":
				if mg21.lo != null and not mark.has("lo"):
					mark["lo"] = true
					var lo: Gunman = mg21.lo
					_check(String(lo.body.get_meta("cast_id", "")) == "van_lo" and is_equal_approx(lo.max_hp, GunData.GUNMAN_HP * MissionBossGuns.LO_HP_K), "wave 2: Lọ himself (%.0f HP)" % lo.max_hp)
					_check(((lo.body.get_meta("gear", []) as Array).size() == 3), "Lọ wears his gold glasses, pink collar and chain")
					(lo as Gunman).take_hit({"kind": "bullet", "from": tw.player.global_position})
					_check(not lo.is_defeated(), "one bullet does not drop Lọ")
				_ko_all(mg21.fight, 80)
			if mg21 and _step_replay(mg21):
				mark["phase1"] = true
			if not _cine_started(tw, "cine_d7_monologue", 1500):
				return false
			_check(mark.has("lo") and mark.has("phase1"), "Lọ beaten, the seg_d7_phase1 replay")
			_check(String(sd.get("step")) == "d7_monologue", "the monologue beat")
			var cp21: CinePlayer = tw.cine_player
			_check(cp21.timeline.slot == "cine_d7_monologue" and cp21.stage_xf.is_equal_approx(tw.level.cine_xf("cine_d7_monologue")) and tw.level.current_floor == "gallery", "staged in the real gallery")
			_check(not tw.clock_hud.visible and not tw.player.visible, "the clock HUD and the player hidden in the cinematic")
			mark["clock21"] = Day7Clock.remaining(sd)
			_check(_finish_cine_in(tw) == "cine_d7_monologue", "Mọi thứ đều nằm trong kế hoạch")
			_check(is_equal_approx(Day7Clock.remaining(sd), float(mark["clock21"])), "the clock stood still in the cinematic")
			_next(23)
		# ----- boss phase 2: the blackout -----
		23:
			m = _wait_mission("MissionBossDark")
			if m == null:
				return false
			var md: MissionBossDark = m
			_check(String(sd.get("step")) == "d7_boss2" and String(StoryTower.LAIR_MUSIC["boss_dark"]) == "", "the blackout: no music, his voice and the vases")
			_check(LookPresets.active(tw) == "penthouse_blackout" and tw.looks == ["penthouse_blackout"] and not tw.level.power_on and not tw.level.gallery_lights[0].visible, "the power is cut: the blackout look")
			_check(md.flashlight.is_lit() and md.lo != null and md.lo.visible and md.lo_state == "stalk", "the flashlight on, Lọ stalks")
			_check(tw.clock_hud.visible, "the clock HUD back after the cinematic")
			md.lit_override = 0
			var p: Vector3 = tw.player.global_position
			md.lo.global_position = p + Vector3(0.0, 0.0, -2.6)
			mark["hp23"] = tw.combat.hp
			_next(24)
		24:
			var md24: MissionBossDark = m
			if md24.hits < 1:
				if frames > 240:
					_check(false, "Lọ's lunge did not land (state %s)" % md24.lo_state)
					phase = 999
				return false
			_check(md24.lunges >= 1 and md24.cracks >= 1 and md24.cues_played.has("glass_crack"), "the telegraph: a vase cracks before the lunge")
			var lit_rings: int = 0
			for s: Node3D in tw.level.speakers:
				if (s.get_node("Ring") as Node3D).visible:
					lit_rings += 1
			_check(md24.voices >= 1 and lit_rings == 1 and md24.cues_played.has("evil_laugh"), "his voice from one speaker (its ring lit), the laugh")
			_check(tw.combat.hp < float(mark["hp23"]) and md24.lo_state == "vanish" and not md24.lo.visible, "the lunge hits, he melts into the dark")
			md24.lit_override = 1
			_next(25)
		25:
			var md25: MissionBossDark = m
			if md25.staggers < 1:
				if frames > 600:
					_check(false, "the flashlight did not stagger Lọ (state %s)" % md25.lo_state)
					phase = 999
				return false
			_check(md25.lo_state == "stagger" and md25.popup_label.text == MissionBossDark.T_STAGGER, "the beam staggers him")
			tw.combat.receive_attack(md25.lo, {"damage": 999.0})
			_next(26)
		26:
			if not _fail_shown("down in the blackout"):
				return false
			_check(tw.fail_ui.reason_label.text == MissionBossDark.T_DOWN, "down in the dark: TOANG!")
			tw.fail_ui.press_retry()
			var md26: MissionBossDark = m
			_check(md26.state == "running" and tw.combat.hp > 0.0 and not tw.level.power_on and md26.restored == [false, false] and md26.lo_state == "stalk", "retry: the power off again, the breakers down, HP back")
			_check(md26.lo.global_position.distance_to(md26.pts["boss_at"]) < 0.5, "Lọ back at his desk")
			md26.lit_override = 1                 # keep him off while the breakers are held
			md26.hold_override = true
			tw.player.teleport(md26.pts["breakers"][0], 0.0)
			_next(27)
		27:
			var md27: MissionBossDark = m as MissionBossDark if is_instance_valid(m) else null
			if md27 and md27.state == "running":
				if md27.restored[0] and not mark.has("br0"):
					mark["br0"] = true
					var lever: Node3D = tw.level.breakers[0].get_node("Lever")
					_check(lever.rotation.x < 0.0 and not tw.level.power_on, "breaker 1 on (its lever up), still dark")
					tw.player.teleport(md27.pts["breakers"][1], 0.0)
			if not _at_step("d7_boss3", "the power did not come back", 900):
				return false
			_check(mark.has("br0"), "both breakers held")
			_check(tw.level.power_on and tw.level.gallery_lights[0].visible and tw.looks.is_empty() and LookPresets.active(tw) == "penthouse", "the power back: the lights, the look restored")
			_check((sd.get("ranks") as Dictionary).has("d7_boss2"), "a rank for the blackout")
			# the lights back: seg_d7_phase2 in the real gallery, the two hall plinths under the fight's own hidden while it plays
			var cp27: CinePlayer = tw.cine_player
			_check(cp27 != null and cp27.timeline.slot == "seg_d7_phase2" and cp27.stage_xf.is_equal_approx(tw.level.cine_xf("seg_d7_phase2"))
				and tw.level.current_floor == "gallery", "the power back: seg_d7_phase2 in the real gallery (moved by its SLOT_OFFSET)")
			var hid27: Array = tw.level.cine_hidden().duplicate()
			_check(hid27.size() == 2 and hid27.all(func(e: Array) -> bool: return not (e[0] as Node3D).visible), "the two hall plinths under the fight's own hidden (%d)" % hid27.size())
			_check(not tw.player.visible and not tw.clock_hud.visible and paused, "the player and the clock HUD hidden, the tree paused in the fight")
			_check(_finish_cine_in(tw) == "seg_d7_phase2", "Gọi trực thăng. Lên sân thượng!")
			_check(hid27.all(func(e: Array) -> bool: return (e[0] as Node3D).visible) and tw.level.cine_hidden().is_empty(), "the hall plinths back after the fight")
			_next(28)
		# ----- boss phase 3: the roof -----
		28:
			m = _wait_mission("MissionBossSaber")
			if m == null:
				return false
			var mb: MissionBossSaber = m
			_check(tw.level.current_floor == "roof" and tw.level.rain[0].emitting and tw.level.heli_light.visible, "the roof: rain, the helicopter's searchlight")
			_check(mb.duel.rain_mode and mb.duel.sprinklers_on and mb.duel.find_child("SprinklerHead*", true, false) == null and not mb.duel.emitters[0].emitting, "the rain-mode duel: wet from the start, no sprinkler heads")
			_check(LookPresets.active(tw) == "rooftop_rain" and tw.looks == ["rooftop_rain"], "the rooftop_rain look")
			var lo3: KatanaBoss = mb.duel.boss
			_check(lo3 != null and lo3.label == "Lùm Văn Lọ" and String(lo3.body.get_meta("cast_id", "")) == "van_lo", "Lùm Văn Lọ with the saber")
			var want3: float = float(SwordData.ZA_MAN["hp"]) * SwordData.HP_SCALE * MissionBossSaber.LO_HP_K
			_check(absf(lo3.max_hp - want3) < 0.5, "Lọ has more HP than Za Mẫn (%.0f)" % lo3.max_hp)
			_check(String(StoryTower.LAIR_MUSIC["boss_saber"]) == "boss_d7", "boss_d7 on the roof")
			mb.duel.won.connect(func() -> void: mark["finish_popup"] = mb.popup_label.text if mb.popup_label else "")   # after the mission's own handler
			mb.duel.combat.receive_attack(lo3, {"damage": 999.0})
			_next(29)
		29:
			if not _fail_shown("down on the roof"):
				return false
			_check(tw.fail_ui.reason_label.text == MissionBossSaber.T_DOWN, "cut down on the roof: TOANG!")
			tw.fail_ui.press_retry()
			var mb29: MissionBossSaber = m
			_check(mb29.duel.state == "running" and mb29.duel.sprinklers_on and is_equal_approx(mb29.duel.combat.hp, 100.0), "retry: a fresh Lọ, still raining")
			_next(30)
		30:
			var mb30: MissionBossSaber = m as MissionBossSaber if is_instance_valid(m) else null
			if mb30 and mb30.duel and mb30.duel.in_qte:
				if not mark.has("qte_label"):
					mark["qte_label"] = mb30.duel.qte.label.text if mb30.duel.qte.label else ""
				for k: String in ["q", "lmb", "e"]:
					mb30.duel.qte.press(k)
				mark["qte30"] = mb30.duel.qte_clean
			elif mb30 and mb30.duel and mb30.duel.boss and mb30.duel.state == "running":
				mb30.duel.boss.take_strike({"kind": "slash1", "dmg": 999.0, "stagger": 0.0, "from": tw.player.global_position})
			if not _at_step("d7_typing", "the rooftop duel was not won", 1200):
				return false
			_check(bool(mark.get("qte30", false)), "the rooftop QTE passed")
			_check(String(mark.get("qte_label", "")) == "[Q] GẠT KIẾM", "the Day 7 QTE prompts (%s)" % String(mark.get("qte_label", "")))
			_check(String(mark.get("finish_popup", "")) == MissionBossSaber.T_FINISH, "Đòn chân kẹp cổ số 21!")
			_check(is_equal_approx(Engine.time_scale, 1.0) and tw.looks.is_empty(), "the time scale and the look restored after the duel")
			# the duel won: seg_d7_finisher on the real roof, the level's helicopter, searchlight and rain hidden (it flies its own)
			var cp30: CinePlayer = tw.cine_player
			_check(cp30 != null and cp30.timeline.slot == "seg_d7_finisher" and cp30.stage_xf.is_equal_approx(tw.level.cine_xf("seg_d7_finisher"))
				and tw.level.current_floor == "roof", "the duel won: seg_d7_finisher on the real roof")
			var hid30: Array = tw.level.cine_hidden().duplicate()
			_check(not tw.level.heli.visible and not tw.level.heli_light.visible and tw.level.rain.all(func(e: CPUParticles3D) -> bool: return not e.visible and not e.emitting),
				"the level's helicopter, searchlight and rain hidden while the cinematic flies its own")
			_check(cp30 != null and cp30.prop_nodes.has("heli") and cp30.prop_nodes.has("rain") and not cp30.prop_nodes.has("roof"), "its own helicopter and rain, the roof set dropped")
			_check(_finish_cine_in(tw) == "seg_d7_finisher", "Xin vĩnh biệt cụ.")
			_check(hid30.all(func(e: Array) -> bool: return (e[0] as Node3D).visible == bool(e[1]) and (not e[0] is CPUParticles3D or (e[0] as CPUParticles3D).emitting == bool(e[2])))
				and tw.level.heli.visible and tw.level.heli_light.visible, "the helicopter, the searchlight and the rain back after it")
			_next(31)
		# ----- the typing showdown -----
		31:
			m = _wait_mission("MissionTowerTyping")
			if m == null:
				return false
			var mt: MissionTowerTyping = m
			var h: StoryHack = mt.hack
			_check(tw.level.current_floor == "penthouse" and h != null and h.active and h.visible and not tw.player.controls_enabled, "the exam rack: the terminal open, the player at the desk")
			_check(h.words == MissionTowerTyping.WORDS and h.final_command == "sudo rm -rf lothan10" and h.tool_name == "Lọ Thần 10.0", "Lọ Thần 10.0's pools and the final command")
			_check(h.hp_label.text.begins_with("Lọ Thần 10.0"), "the integrity bar names Lọ Thần 10.0")
			_advance(mt, 2.0)
			_check(h.bullets.size() >= 1 and String(h.bullets[0]["word"]) in (MissionTowerTyping.WORDS[0] as Array), "Day 7 processes fall (wave 1 words)")
			Day7Clock.set_remaining(sd, 0.4)
			mark["fails31"] = tw.clock_fails
			_next(32)
		32:
			if not _fail_shown("08:00 came", 120):
				return false
			var mt32: MissionTowerTyping = m
			_check(tw.fail_ui.title_label.text == Day7Clock.T_TITLE and tw.fail_ui.reason_label.text == Day7Clock.T_LATE, "08:00: the tool goes live (the fail card)")
			_check(tw.clock_failed and tw.clock_fails == int(mark["fails31"]) + 1 and mt32.process_mode == Node.PROCESS_MODE_DISABLED and mt32.hack.paused, "the terminal freezes behind the card")
			var g0: int = tw.graces
			var radio0: int = mt32.cues_played.count("radio")
			tw.fail_ui.press_retry()
			_check(is_equal_approx(Day7Clock.remaining(sd), Day7Clock.GRACE_S) and tw.graces == g0 + 1 and not tw.clock_failed, "THỬ LẠI: Anh Duy buys GRACE_S")
			_check(mt32.cues_played.count("radio") > radio0 and mt32.radio_panel.visible, "Anh Duy on the radio")
			var h32: StoryHack = mt32.hack
			_check(h32.active and not h32.paused and h32.leaks == 0 and is_equal_approx(h32.hp, h32.hp_max) and mt32.process_mode == Node.PROCESS_MODE_INHERIT, "a fresh run")
			var n32: int = 0
			while h32.final_bullet.is_empty() and n32 < 400:
				mt32.advance(0.4)
				for b: Dictionary in h32.bullets.duplicate():
					if not bool(b["dead"]):
						h32.type_text(String(b["word"]))
				n32 += 1
			_check(not h32.final_bullet.is_empty() and h32.kills >= 5, "every process killed (%d): the final command shows" % h32.kills)
			_check(h32.type_text(MissionTowerTyping.FINAL_COMMAND) == "won", "sudo rm -rf lothan10: wiped")
			_next(33)
		33:
			if not tw.left:
				if frames > 120:
					_check(false, "the tower did not hand back after the typing")
					phase = 999
				return false
			var nb: Dictionary = StoryMissions.beat("d7_ending")
			if nb.is_empty():
				_check(tw.handoff_beat == "d7_ending", "the hand-off: d7_ending (the endings stream)")
				_check(String(sd.get("step")) == "d7_typing", "pre-merge: the step stays at d7_typing (no unknown beat)")
			else:   # merged (wave4): the typing completes and the step moves on to the endings' beat
				_check(tw.handoff_beat == "" and String(sd.get("step")) == "d7_ending", "the hand-off: the step is d7_ending (%s)" % String(sd.get("step")))
				_check(String(nb.get("ending", "")) == "auto" and String(nb.get("lair", "")) == "", "d7_ending is the endings' auto beat, played in free roam")
			_check(String(sd.get("last_nav")) == "roam", "back to story free roam")
			_check((sd.get("ranks") as Dictionary).has("d7_typing") and (sd.get("ranks") as Dictionary).has("d7_boss3"), "ranks for the roof and the typing")
			for id: String in ["d7_parking", "d7_warehouse", "d7_servers", "d7_mannequins", "d7_lasers", "d7_boss1", "d7_monologue", "d7_boss2", "d7_boss3", "d7_typing"]:
				_check(StoryChapters.is_beat_unlocked(id), "Chọn cảnh: %s reached" % id)
			for f: String in [MissionTowerForklift.CARD_FLAG, MissionTowerKatana.CARD_FLAG, MissionBossGuns.CARD_FLAG]:
				_check(bool((sd.get("flags") as Dictionary).get(f, false)), "card flag %s" % f)
			tw.queue_free()
			tw = null
			return _end()
	return false


func _end() -> bool:
	if audit:
		print("  ", audit.call("report"))
		_check(bool(audit.call("clean", 6.0)), "the time scale stayed in the owner protocol (%s)" % String(audit.call("report")))
	if tw and is_instance_valid(tw):
		tw.queue_free()
	paused = false
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	StoryTower.test_opts = {}
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 7 (tower floors, boss phases 1-3, typing, the 08:00 clock, the hand-off)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
