# File: res://tests/test_story_day4.gd
# Headless end-to-end test of story Day 4 (spec B-D7; plan 2026-10-25-phase-b-integration.md), from the end of Day 3 (Days
# 2 and 3 are playable since Phase C: test_story_day2 / test_story_day3) with the optional E2 skipped: the call N = 4 ->
# Day 4 morning (Linh's text) -> the canteen marker ->
# cine_d4_intro -> the undercover (12 identical students + the disguised Dolly with her tells and the music-box hum, the
# tray carried, a student's note and [E] Tố cáo, a wrong accusation, the tray dropped by sprinting, a new tray at the
# counter, "BỊ LỘ" -> THỬ LẠI (Dolly elsewhere), the right accusation) -> cine_d4_stare -> the clone waves + Dolly, who
# flees -> seg_d4_brawl -> the lobby marker -> the night escape scene (caught once: no E5; a clean run: E5) with the
# seg_d4_escape replay -> cine_d4 -> bed -> the call N = 3 -> Day 5 morning -> the Day 5 basement marker. Then Continue from
# the autosave taken after the brawl (the lobby marker at night, nothing starts by itself) and at d4_brawl (the canteen
# marker, the fight does not start by itself). The night escape's catches are saved at once (no E5 by quitting).
# Run:  godot --headless --path . --script tests/test_story_day4.gd
extends SceneTree

const TMP: String = "user://test_story_day4.cfg"
const SNAP: String = "user://test_story_day4_snap.cfg"
const VID: String = "user://test_story_day4_video/"
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
var esc: StoryNightEscape
var mark: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 4 (Day 4 end to end, from the end of Day 3) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SNAP))
	StoryVideo.video_dir = VID
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)


func _roam() -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	sr = fr.get("story_roam")
	if sr:
		sr.cine_opts = {"manual": true, "music": false}
		sr.call_opts = {"manual": true}
		sr.mission_opts = {"manual": true, "manual_replay": true, "seed": 9}


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


## Answers and finishes the running 3 a.m. call; returns its N (-1 when none is running yet).
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


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 50000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	match phase:
		0:
			sd.call("new_story", {"female": true, "name": "Thảo", "variant": 0, "hair_style": "bob", "hair_color": 0, "skin": 2})
			sd.set("day", 3)
			(sd.get("evidence") as Array).append("E1")
			(sd.get("flags") as Dictionary)["d1_key"] = true   # the locker key was dropped, E2 was skipped
			(sd.get("choices") as Dictionary)["phuc"] = "report"
			sd.call("_enter", "d3_call")
			_check(String(sd.get("step")) == "d3_call", "the story is at the end of Day 3 (E2 skipped)")
			_roam()
			_next(1)
		1:
			var n: int = _do_call()
			if n < 0:
				if frames > 150:
					_check(false, "the Day 3 call did not start")
					phase = 999
				return false
			_check(n == 4, "the call after Day 3 says 4")
			_next(5)
		5:
			if not _cine_started("Day 4 morning"):
				return false
			_check((sd.get("evidence") as Array).size() == 1 and sd.call("has_evidence", "E1") and String(sd.call("choice_of", "phuc")) == "report", "the evidence and choice carried over")
			var dc4: StoryDayCard = sr.cards as StoryDayCard
			_check(dc4 != null and dc4.days == 4 and dc4.left == 4, "Day 4 morning card")
			_finish_cine()
			_next(6)
		6:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d4_canteen" and sr.markers.has("d4_canteen") and int(sd.call("unread_count", "Linh")) >= 1, "the canteen marker, Linh's text")
			_check(not sr.markers.has("d1_locker"), "the skipped locker is gone after Day 1")
			_check(sr.start_marker("d4_canteen") and fr.get("cine_player") != null, "[E]: cine_d4_intro")
			_check(_finish_cine() == "cine_d4_intro", "cine_d4_intro plays")
			_next(7)
		7:
			if frames < 2:
				return false
			m = sr.mission_node
			_check(m is MissionCanteen and m.state == "running" and String(fr.get("tod_preset")) == "noon", "the undercover runs at noon")
			if not (m is MissionCanteen):
				phase = 999
				return false
			_canteen(m as MissionCanteen)
			_next(8)
		8:
			if not _cine_started("cine_d4_stare", 90):
				return false
			_check(_finish_cine() == "cine_d4_stare", "the stare (with the villain card)")
			_next(9)
		9:
			if sr.mission_node == null or not (sr.mission_node is MissionFight):
				if frames > 90:
					_check(false, "the clone brawl did not start by itself (step %s)" % String(sd.get("step")))
					phase = 999
				return false
			m = sr.mission_node
			var mf: MissionFight = m
			_check(String(sd.get("step")) == "d4_brawl" and mf.fight.waves.size() == 2 and mf.fight.enemies.size() == 4, "the brawl: wave 1 of 4 clones")
			_check(mf.arena != null and mf.arena.tables.size() == 6 and mf.fight.props.size() == 5, "the canteen arena: 6 tables to slam into, trays and chairs on the floor")
			var slam_tables: int = 0
			for t: Dictionary in mf.arena.tables:
				if (t["body"] as Node).is_in_group("slam_table"):
					slam_tables += 1
			_check(slam_tables == 6, "every table is a slam surface")
			_next(10)
		10:
			var mf2: MissionFight = m as MissionFight if is_instance_valid(m) else null
			if mf2 != null and mf2.fight != null and is_instance_valid(mf2.fight):
				if mf2.fight.wave == 1 and not mark.has("w2"):
					mark["w2"] = true
					var arch: Array = []
					for e: Variant in mf2.fight.enemies:
						arch.append((e as MeleeEnemy).archetype_id)
					_check(arch.has("dolly") and arch.size() == 3, "wave 2: Cừu Dolly and two clones (%s)" % str(arch))
					_food_fight_start(mf2)
				if mark.has("w2") and not mark.has("food_done"):
					if frames - int(mark.get("food_t0", frames)) >= 30:
						_food_fight_throws(mf2)
					return false
				for e2: Variant in mf2.fight.alive():
					var me: MeleeEnemy = e2
					if me.archetype_id == "dolly" and mark.has("w2") and frames % 30 != 0:
						continue
					var r: String = me.take_strike({"dmg": 999.0, "stagger": 999.0, "breaks_block": true, "from": _player().global_position})
					if me.archetype_id == "dolly" and r == "flee":
						mark["dolly_fled"] = true
			if fr.get("cine_player") == null:
				if frames > 1500:
					_check(false, "the clone brawl was not won (%s)" % (str(mf2.fight.state) if mf2 else "gone"))
					phase = 999
				return false
			_check(mark.has("w2") and mark.has("dolly_fled"), "Dolly fled at 30 %")
			_check(_finish_cine() == "seg_d4_brawl", "won: seg_d4_brawl")
			_next(11)
		11:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d4_escape" and sr.markers.has("d4_escape"), "the lobby marker for the night escape")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(SNAP))
			_check(sr.start_marker("d4_escape") and String(sd.get("last_nav")) == "horror:" + StoryMissions.HORROR_SCENE, "[E]: the Night Building scene")
			_check(bool((sm.get("story_context") as Dictionary).get("horror", false)), "story_context for the horror beat")
			fr.queue_free()
			StoryNightEscape.test_opts = {"seed": 5, "manual_replay": true, "capture_mouse": false}
			_next(12)
		12:
			if frames < 3:
				return false
			esc = (load("res://scenes/story/StoryNightEscape.tscn") as PackedScene).instantiate()
			root.add_child(esc)
			_next(13)
		13:
			if esc.night == null or esc.night.state != "play" or esc.rec == null:
				if frames > 200:
					_check(false, "the Night Building did not build")
					phase = 999
				return false
			var nb: NightBuilding = esc.night
			if not mark.has("nb_look"):
				mark["nb_look"] = true
				_check(LookPresets.active(nb) == "campus_horror", "the night building wears the campus_horror look (%s)" % LookPresets.active(nb))
				_check(nb.player.cam_rig != null, "the night escape runs on the Q1 foot camera rig")
			_check(nb.stalkers.size() == 4 and bool(nb.player.character_opts.get("female", false)), "4 stalkers, the protagonist as the player")
			if not mark.has("run2"):
				nb._on_caught(nb.stalkers[0])
				_check(nb.caught_count == 1 and nb.state == "caught", "caught once")
				nb.retry_from_checkpoint()
				_check(nb.state == "play", "retry from the checkpoint")
			nb.kit.catch_enabled = false
			for k: int in 3:
				nb.collect_fuse(k)
			nb.place_fuses()
			_check(nb.doors_unlocked and nb.fuses_placed == 3, "3 fuses: the lobby doors open")
			nb.player.teleport(Vector3(0.0, 0.0, 24.5), PI)
			_next(14)
		14:
			var nb2: NightBuilding = esc.night
			if nb2.state != "escaped":
				var p: Vector3 = nb2.player.global_position
				nb2.player.teleport(Vector3(0.0, p.y, p.z + 0.25), PI)
				if frames > 300:
					_check(false, "never walked out (z %.1f)" % p.z)
					phase = 999
				return false
			if esc.replay != null:
				var n5: int = 0
				while esc.replay != null and n5 < 1000:
					esc.replay.step(DT)
					n5 += 1
			if not esc.reported:
				if frames > 120:
					_check(false, "the escape was not reported (replay %s)" % str(esc.replay))
					phase = 999
				return false
			if not mark.has("run2"):
				_check(esc.result_caught == 1 and not sd.call("has_evidence", "E5") and String(sd.get("step")) == "d4_end", "escaped after a catch: no E5, d4_end")
				_check(String(sd.get("last_nav")) == "roam", "back to story free roam")
				_check(int((sd.get("flags") as Dictionary).get("d4_catches", 0)) == 1, "the catch was saved at once (anti save-scum)")
				(sd.get("flags") as Dictionary).erase("d4_catches")   # a fresh playthrough of the night for the clean run
				mark["run2"] = true
				esc.queue_free()
				sd.call("set_step", "d4_escape")
				sd.call("launch_horror_beat", "d4_escape", null, null)
				_next(12)
			else:
				_check(esc.result_caught == 0 and sd.call("has_evidence", "E5") and String(sd.get("step")) == "d4_end", "a clean escape: E5 (the proxy roster)")
				esc.queue_free()
				StoryNightEscape.test_opts = {}
				_next(15)
		15:
			if frames < 3:
				return false
			_roam()
			_next(16)
		16:
			if not _cine_started("cine_d4", 150):
				return false
			_check(_finish_cine() == "cine_d4", "cine_d4: Dolly spills the schedule")
			_next(17)
		17:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d4_bed" and sr.markers.has("d4_bed"), "free roam until bed")
			_check(sr.start_marker("d4_bed"), "bed")
			_next(18)
		18:
			var n6: int = _do_call()
			if n6 < 0:
				if frames > 150:
					_check(false, "the Day 4 call did not start")
					phase = 999
				return false
			_check(n6 == 3, "the call after Day 4 says 3")
			_next(19)
		19:
			if not _cine_started("Day 5 morning"):
				return false
			_finish_cine()
			_next(20)
		20:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d5_stealth" and sr.markers.has("d5_stealth") and String(sd.get("objective")).contains("Anh Duy"), "Day 5: the basement marker at Anh Duy's corner")
			_check(String(sd.call("day_chip_text")) == "NGÀY 5 · CÒN 3 NGÀY", "Day 5 chip")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(21)
		21:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", SNAP)
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d4_escape", "Continue restores d4_escape")
			_roam()
			_next(22)
		22:
			if frames < 40:
				return false
			_check(sr.markers.has("d4_escape") and sr.mission_node == null and fr.get("cine_player") == null and String(fr.get("tod_preset")) == "night", "after Continue: the lobby marker at night, nothing starts by itself")
			sd.call("set_step", "d4_brawl")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(23)
		23:
			if frames < 3:
				return false
			sd.call("reset_state")
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d4_brawl", "Continue restores d4_brawl")
			_roam()
			_next(24)
		24:
			if frames < 45:
				return false
			_check(sr.markers.has("d4_brawl") and sr.mission_node == null and fr.get("cine_player") == null, "Continue at d4_brawl: its canteen marker, the fight does not start by itself")
			fr.queue_free()
			return _end()
	return false


## Wave 2 escalation: the food fight is on (throwers, a preview cut); a table flipped between a thrower and the player.
func _food_fight_start(mf: MissionFight) -> void:
	var ar: ArenaDressing = mf.arena
	_check(ar.food_on and ar.throwers.size() == ArenaDressing.thrower_count() and ar.cuts >= 1, "wave 2: the food fight (%d throwers, a preview cut)" % ar.throwers.size())
	_check(ArenaDressing.throw_tell_s() >= 0.5, "every throw is telegraphed for at least 0.5 s")
	for th: Dictionary in ar.throwers:
		th["t"] = 99.0
	var tp: Vector3 = (ar.throwers[0]["body"] as Node3D).global_position
	var best: int = -1
	var bd: float = 999.0
	for i: int in ar.tables.size():
		var d: float = MissionFight.flat((ar.tables[i]["root"] as Node3D).global_position, tp)
		if d < bd:
			bd = d
			best = i
	var tpos: Vector3 = (ar.tables[best]["root"] as Node3D).global_position
	var back: Vector3 = Vector3(tpos.x - tp.x, 0.0, tpos.z - tp.z).normalized()
	var stand: Vector3 = tpos + back * 1.1
	_player().teleport(stand, MissionFight.yaw_of(-back))
	_check(ar.flip_target() == best, "the nearest table is in reach for a flip")
	var hp0: float = mf.fight.combat.hp
	_check(ar.try_flip() and bool(ar.tables[best]["flipped"]) and ar.flips == 1 and ar.soup_splashes >= 1, "[E] flips the table: soup everywhere")
	_check(not ar.try_flip() or ar.flips == 2, "")
	mark["food_t0"] = frames
	mark["food_stand"] = stand
	mark["food_hp0"] = hp0


## A thrower's bun at the player behind the flipped table is blocked; in the open it splats them.
func _food_fight_throws(mf: MissionFight) -> void:
	mark["food_done"] = true
	var ar: ArenaDressing = mf.arena
	var stand: Vector3 = mark["food_stand"]
	_player().teleport(stand, 0.0)
	ar.throwers[0]["t"] = 0.0
	var n: int = 0
	while ar.throws < 1 or not ar.buns.is_empty():
		_player().teleport(stand, 0.0)
		mf.advance(0.05)
		n += 1
		if n > 80:
			break
	_check(ar.throws == 1 and ar.blocked == 1 and ar.food_hits == 0, "behind the flipped table the bun is blocked (%d thrown, %d blocked)" % [ar.throws, ar.blocked])
	var tp: Vector3 = (ar.throwers[0]["body"] as Node3D).global_position
	var open: Vector3 = tp - ar.fwd * 4.0
	open = Vector3(open.x, mf.ground_y(open), open.z)
	var hp1: float = mf.fight.combat.hp
	ar.throwers[0]["t"] = 0.0
	n = 0
	while ar.throws < 2 or not ar.buns.is_empty():
		_player().teleport(open, MissionFight.yaw_of(tp - open))
		mf.advance(0.05)
		n += 1
		if n > 80:
			break
	_check(ar.food_hits == 1 and mf.fight.combat.hp < hp1, "in the open the bun splats the player (%d hits, hp %.0f -> %.0f)" % [ar.food_hits, hp1, mf.fight.combat.hp])

## The canteen undercover, scripted.
func _canteen(mc: MissionCanteen) -> void:
	_check(mc.clones.size() == 12, "12 students at the tables")
	var dolly: Node3D = mc.dolly()
	_check(dolly != null and String(dolly.get_meta("cast_id", "")) == "dolly_disguised" and dolly.has_meta("wool_cuff") and dolly.has_meta("sheep_keychain"), "the disguised Dolly wears the cuff and the keychain")
	var same: bool = true
	for i: int in mc.clones.size():
		if i != mc.dolly_index:
			same = same and String(mc.clones[i].get_meta("cast_id", "")) == "clone"
	_check(same, "every other student is the same clone")
	_check(mc.hum != null and mc.hum.get_parent() == dolly, "the music-box hum sits on Dolly")
	_check(mc.has_tray and mc.tray.get_parent() == _player().model, "the tray is carried")
	var wrong_i: int = (mc.dolly_index + 1) % 12
	_face(mc, wrong_i)
	mc.advance(0.1)
	_check(mc.hud_prompt.text.contains("[E] Tố cáo") and not mc.hud_prompt.text.contains("hộp nhạc"), "a student's note: %s" % mc.hud_prompt.text)
	_check(mc.interact() == "wrong" and mc.wrong == 1 and mc.suspicion >= 30.0, "a wrong accusation raises suspicion (%.0f)" % mc.suspicion)
	_face(mc, mc.dolly_index)
	mc.advance(0.1)
	_check(mc.hud_prompt.text.contains("hộp nhạc"), "Dolly hums: %s" % mc.hud_prompt.text)
	var s0: float = mc.suspicion
	_player().is_sprinting = true
	_player().horizontal_speed = 7.0
	mc.advance(0.1)
	_player().is_sprinting = false
	_player().horizontal_speed = 0.0
	_check(mc.drops == 1 and not mc.has_tray and mc.suspicion >= s0 + 15.0, "sprinting drops the tray (+suspicion)")
	var s1: float = mc.suspicion
	for k: int in 10:
		mc.advance(0.1)
	_check(mc.suspicion > s1, "without a tray the suspicion rises")
	var cp: Vector3 = mc.xf * (MissionCanteen.COUNTER + Vector3(0.0, 0.0, 1.2))
	_player().teleport(cp, MissionCanteen.yaw_of(mc.xf * MissionCanteen.COUNTER - cp))
	mc.advance(0.1)
	_check(mc.hud_prompt.text == "[E] Lấy khay mới" and mc.interact() == "tray" and mc.has_tray, "a new tray at the counter")
	var other: int = (mc.dolly_index + 2) % 12
	var n: int = 0
	while mc.state == "running" and n < 5:
		mc.accuse(other)
		n += 1
	_check(mc.state == "failed" and sr.fail_ui.visible and sr.fail_ui.title_label.text == "BỊ LỘ", "a full meter: BỊ LỘ")
	sr.fail_ui.press_retry()
	_check(mc.state == "running" and mc.suspicion == 0.0 and mc.has_tray and mc.clones.size() == 12 and mc.retries == 1, "THỬ LẠI: meter, tray and students reset")
	_check(mc.accuse(mc.dolly_index) == "dolly" and mc.state == "done", "the right accusation: Cừu Dolly found")


## Stands the player behind student i, facing them.
func _face(mc: MissionCanteen, i: int) -> void:
	var c: Node3D = mc.clones[i]
	var back := Vector3(sin(c.global_rotation.y), 0.0, cos(c.global_rotation.y))   # opposite of the -Z facing
	var p: Vector3 = c.global_position + back * 1.2
	_player().teleport(p, MissionCanteen.yaw_of(c.global_position - p))


func _end() -> bool:
	StoryNightEscape.test_opts = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SNAP))
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 4 (canteen undercover, clone waves + Dolly, night escape E5, call, Day 5, continue)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
