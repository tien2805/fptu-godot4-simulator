# File: res://tests/test_story_day1.gd
# Headless end-to-end test of story Day 1 "Shipper bóng đêm" (spec B-D5, B-D6; plan 2026-10-25-phase-b-integration.md):
# Day 1 morning (cine_day_start) -> the main-gate marker (blocked while wanted) -> cine_d1_intro -> the stake-out (seen =
# restart, the window missed = TOANG! -> THỬ LẠI, a photo too early refused, the photo in the window, 60 s) -> the chase
# starts by itself (leash lost = TOANG! -> retry, the banana slip with slide_whistle and the replay mark, 60-90 s, the
# seg_d1_chase replay) -> the brawl (3 couriers, forced unarmed, "Gét gô!", down = TOANG! -> retry from the checkpoint,
# won -> seg_d1_brawl, the locker key flag) -> the corridor marker -> the horror walk (flicker, figure, blackout, gone,
# bleat, not before 30 s) -> cine_d1_corridor -> the bench marker + the optional locker (E2 taken) -> the choice scene
# timed out (the honest "cover", recorded) -> the cover tail -> cine_d1 -> bed -> the call N = 6 -> Day 2 morning -> the
# Day 2 placeholder (sleepable). Then Continue from the autosave taken after the brawl (corridor marker, no mission
# started by itself, night, key flag kept) and the choice recorded once (a set choice skips the scene: the report tail).
# Missions run on manual clocks (StoryRoam.mission_opts), cinematics / calls / replays are stepped.
# Run:  godot --headless --path . --script tests/test_story_day1.gd
extends SceneTree

const TMP: String = "user://test_story_day1.cfg"
const SNAP: String = "user://test_story_day1_snap.cfg"
const VID: String = "user://test_story_day1_video/"
const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var m: StoryMission
var mark: Dictionary = {}
var total: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 1 (end to end) ---")
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
		sr.mission_opts = {"manual": true, "manual_replay": true, "seed": 7}


func _player() -> ThirdPersonController:
	return fr.get("player")


## Steps the running cinematic to its end (manual CinePlayer). Returns its slot.
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


## Waits for a cinematic to start (true when it runs); fails the test after `cap` frames.
func _cine_started(what: String, cap: int = 150) -> bool:
	if fr.get("cine_player") != null:
		return true
	if frames > cap:
		_check(false, "%s did not start (step %s)" % [what, String(sd.get("step"))])
		phase = 999
	return false


func _advance(secs: float, dt: float = 0.1) -> void:
	var n: int = int(round(secs / dt))
	for i: int in n:
		if m == null or not is_instance_valid(m) or m.state != "running":
			return
		m.advance(dt)


func _next(p: int) -> void:
	phase = p
	frames = 0


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 40000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	match phase:
		0:
			sd.call("new_story", {"female": false, "name": "Minh", "variant": 1, "hair_style": "spiky", "hair_color": 2, "skin": 1})
			sd.set("step", "d0_intro")
			sd.call("complete_step", "d0_intro")
			_check(String(sd.get("step")) == "d1_morning" and int(sd.get("day")) == 1, "the story is at the Day 1 morning")
			_roam()
			_next(1)
		1:
			if not _cine_started("cine_day_start"):
				return false
			_check(_finish_cine() == "cine_day_start", "Day 1 morning: cine_day_start")
			_next(2)
		2:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_stakeout" and String(fr.get("tod_preset")) == "night", "d1_stakeout at night")
			_check(sr.markers.has("d1_stakeout") and sr.mission_node == null, "the main-gate marker, no mission yet")
			_check(int(sd.call("unread_count", "Mr.T")) >= 1, "Mr.T's text about the main gate")
			var w := WantedDirector.new()
			w.stars = 1
			fr.set("wanted", w)
			_check(not sr.start_marker("d1_stakeout"), "the marker is blocked while wanted")
			fr.set("wanted", null)
			w.free()
			sr.phone.open()
			_check(not sr.start_marker("d1_stakeout"), "the marker is blocked with the phone open")
			sr.phone.close()
			_check(sr.start_marker("d1_stakeout") and fr.get("cine_player") != null, "[E] at the gate plays the mission intro")
			_check(_finish_cine() == "cine_d1_intro", "cine_d1_intro")
			_next(3)
		3:
			if frames < 2:
				return false
			m = sr.mission_node
			_check(m is MissionStakeout and m.state == "running", "the stake-out runs after the intro")
			if not (m is MissionStakeout):
				phase = 999
				return false
			var so: MissionStakeout = m
			_check(so.guards.size() == 2 and so.courier != null and so.hud.visible and sr.ui.visible, "two guards, the courier, the mission HUD and the objective")
			var objc: String = String(sd.get("objective"))
			_check(objc.contains("cổng") or objc.contains("Mr.T"), "objective kept: %s" % objc)
			# seen = restart
			var g: Node3D = so.guards[0]
			_player().teleport(g.global_position + MissionStakeout.fwd_of(g) * 4.0, 0.0)
			so.advance(0.1)
			_check(so.seen_count == 1 and so.clock < 0.2 and MissionStakeout.flat(_player().global_position, so.campus(MissionStakeout.START)) < 6.0, "seen by a guard: the stake-out restarts at the start")
			# the window passes without a photo: TOANG!
			var guard_n: int = 0
			while so.state == "running" and guard_n < 1200:
				so.advance(0.1)
				guard_n += 1
			_check(so.state == "failed" and sr.fail_ui != null and sr.fail_ui.visible and sr.fail_ui.title_label.text == "TOANG!", "the handover missed: TOANG! (%s)" % so.state)
			sr.fail_ui.press_retry()
			_check(so.state == "running" and so.clock < 0.01 and not sr.fail_ui.visible, "THỬ LẠI restarts the stake-out")
			_advance(10.0)
			_check(not so.take_photo() and not so.photo_taken, "a photo before the handover is refused")
			while so.clock < 35.0 and so.state == "running":
				so.advance(0.1)
			for gd: Dictionary in so._g:
				gd["t"] = 1.0
				gd["dir"] = 1.0
				gd["pause"] = 999.0
			so.advance(0.1)
			var spot: Vector3 = so.campus(Vector3(106.0, 0.0, 103.5))
			_player().teleport(spot, MissionStakeout.yaw_of(so.courier.global_position - spot))
			_check(so.box.visible and so.hud_prompt.text.contains("[S]"), "the handover is on: the package and the [S] prompt")
			_check(so.take_photo() and so.photo_taken, "the photo in the window, the courier in frame (16 m)")
			_advance(30.0)
			_check(so.state == "done", "60 s with the photo: done (%s, %.1f s)" % [so.state, so.clock])
			_next(4)
		4:
			if sr.mission_node == null or not (sr.mission_node is MissionChase):
				if frames > 60:
					_check(false, "the chase did not start by itself (step %s)" % String(sd.get("step")))
					phase = 999
				return false
			_check(String(sd.get("step")) == "d1_chase" and int((sd.call("read_save", TMP) as Dictionary).get("day", 0)) == 1, "the stake-out won: d1_chase, autosaved")
			m = sr.mission_node
			var ch: MissionChase = m
			_check(ch.length_m > 280.0 and ch.length_m < 360.0, "the chase path is %.0f m" % ch.length_m)
			# lost him: TOANG!
			_player().teleport(ch.courier.global_position + Vector3(40.0, 0.0, 0.0), 0.0)
			_advance(3.0, 0.25)
			_check(ch.state == "failed" and sr.fail_ui.visible and sr.fail_ui.title_label.text == "TOANG!", "farther than 25 m for 2.5 s: TOANG!")
			sr.fail_ui.press_retry()
			_check(ch.state == "running" and ch.s < 0.01, "retry: the chase from the start")
			_next(5)
		5:
			var ch2: MissionChase = m as MissionChase if is_instance_valid(m) else null
			if ch2 == null:
				_check(false, "the chase mission vanished")
				phase = 999
				return false
			if not ch2.ended:
				var p: Vector3 = ch2.point_at(ch2.s - 5.0)
				_player().teleport(p, MissionStakeout.yaw_of(ch2.courier.global_position - p))
				ch2.advance(0.25)
				if frames > 1500:
					_check(false, "the chase never ended (s %.0f / %.0f)" % [ch2.s, ch2.length_m])
					phase = 999
				return false
			if not mark.has("chase_end"):
				mark["chase_end"] = true
				_check(ch2.slipped and ch2.cues_played.has("slide_whistle") and ch2.rec.marks.has("blow"), "the banana slip: slide_whistle and the replay mark")
				_check(ch2.clock >= 60.0 - 0.01 and ch2.clock <= 90.0, "the chase lasted %.1f s (60-90)" % ch2.clock)
			if ch2.replay != null:
				var n2: int = 0
				while ch2 != null and is_instance_valid(ch2) and ch2.replay != null and n2 < 1000:
					ch2.replay.step(DT)
					n2 += 1
				mark["replayed"] = true
			if frames > 120 and not mark.has("replayed"):
				_check(false, "the seg_d1_chase replay did not play")
				phase = 999
				return false
			if mark.has("replayed"):
				_next(6)
		6:
			if sr.mission_node == null or not (sr.mission_node is MissionFight):
				if frames > 60:
					_check(false, "the brawl did not start by itself (step %s)" % String(sd.get("step")))
					phase = 999
				return false
			m = sr.mission_node
			var mf: MissionFight = m
			_check(String(sd.get("step")) == "d1_brawl" and mf.fight.enemies.size() == 3 and mf.fight.state == "running", "the brawl: 3 couriers")
			_check(mf.fight.start_line == "Gét gô!" and mf.fight.force_unarmed, "start line Gét gô!, forced unarmed")
			mf.fight.combat.receive_attack(mf.fight.enemies[0], {"damage": 999.0})
			_next(7)
		7:
			if not (sr.fail_ui and sr.fail_ui.visible):
				if frames > 60:
					_check(false, "the player went down but no TOANG!")
					phase = 999
				return false
			_check(sr.fail_ui.title_label.text == "TOANG!" and (m as MissionFight).fight.state == "lost", "down: TOANG!")
			sr.fail_ui.press_retry()
			var mf2: MissionFight = m
			_check(mf2.fight.state == "running" and is_equal_approx(mf2.fight.combat.hp, 100.0) and mf2.fight.alive().size() == 3, "retry from the checkpoint: full HP, 3 couriers again")
			_next(8)
		8:
			var mf3: MissionFight = m as MissionFight if is_instance_valid(m) else null
			if mf3 != null and mf3.fight != null and is_instance_valid(mf3.fight):
				for e: Variant in mf3.fight.alive():
					(e as MeleeEnemy).take_strike({"dmg": 999.0, "stagger": 999.0, "breaks_block": true, "from": _player().global_position})
			if fr.get("cine_player") == null:
				if frames > 600:
					_check(false, "the brawl was not won / seg_d1_brawl did not start")
					phase = 999
				return false
			_check(_finish_cine() == "seg_d1_brawl", "the brawl won: seg_d1_brawl")
			_next(9)
		9:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_corridor" and bool((sd.get("flags") as Dictionary).get("d1_key", false)), "d1_corridor; Mũ Đỏ's key flag")
			_check(sr.markers.has("d1_corridor") and sr.mission_node == null, "the corridor waits at its marker")
			_check(int((sd.call("read_save", TMP) as Dictionary).get("flags", {}).get("d1_key", 0)) == 1 or bool((sd.call("read_save", TMP) as Dictionary).get("flags", {}).get("d1_key", false)), "autosaved after the brawl")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(SNAP))
			_check(sr.start_marker("d1_corridor") and sr.mission_node is MissionCorridor, "[E]: the corridor walk")
			m = sr.mission_node
			var mc: MissionCorridor = m
			_check(mc.corridor != null and mc.figure != null and mc.lights.size() == 8, "the corridor set: tubes, the figure")
			_check(is_equal_approx(_player().combat_speed_cap, MissionCorridor.WALK_CAP), "fear caps the walk")
			_corridor_to(mc, 0.2)
			_check(mc.events.has("flicker") and mc.scare.flicker_events >= 1, "the tubes stutter")
			_corridor_to(mc, 0.3)
			_check(mc.figure.visible, "the figure stands at the far end")
			_advance(12.0)
			_corridor_to(mc, 0.6)
			_check(mc.events.has("blackout") and not _player().controls_enabled, "lights out, frozen")
			_advance(1.6)
			_check(mc.events.has("gone") and not mc.figure.visible and _player().controls_enabled and mc.scare.played.has("sheep_bleat_distorted"), "lights back: the figure is gone, a distorted bleat")
			_corridor_to(mc, 0.85)
			_check(mc.events.has("whisper"), "whisper and a stutter")
			_corridor_to(mc, 0.95)
			_check(mc.state == "running" and mc.clock < MissionCorridor.MIN_S, "not over before 30 s (%.1f s)" % mc.clock)
			_advance(MissionCorridor.MIN_S)
			_check(mc.state == "done" and mc.clock >= MissionCorridor.MIN_S - 0.2 and mc.clock <= 60.0, "the far end after %.1f s: done" % mc.clock)
			_next(10)
		10:
			if not _cine_started("cine_d1_corridor", 60):
				return false
			_check(_finish_cine() == "cine_d1_corridor", "cine_d1_corridor follows the walk")
			_check(is_inf(_player().combat_speed_cap), "the walk cap is lifted")
			_next(11)
		11:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_choice" and sr.markers.has("d1_choice") and sr.markers.has("d1_locker"), "the bench marker and the optional locker")
			_check(sr.start_marker("d1_locker") and sd.call("has_evidence", "E2") and not sr.markers.has("d1_locker"), "the locker gives E2 (courier list), once")
			_check(String(sd.get("step")) == "d1_choice", "the locker is optional: the step stays")
			_check(sr.start_marker("d1_choice") and fr.get("cine_player") != null, "[E] at the bench: the choice scene")
			var cp: CinePlayer = fr.get("cine_player")
			var n3: int = 0
			while cp.choice_node == null and fr.get("cine_player") != null and n3 < 2000:
				cp.step(DT)
				n3 += 1
			_check(cp.choice_node != null and cp.choice_node.manual, "the choice opens (freeze, two options, countdown)")
			_check(String(sd.call("choice_of", "phuc")) == "", "not recorded before the answer")
			_check(_finish_cine() == "cine_d1_choice", "the choice scene ends after the timeout")
			_check(String(sd.call("choice_of", "phuc")) == "cover" and cp.choice_timed_out, "timeout: the honest option (cover) is recorded")
			_next(12)
		12:
			if not _cine_started("cine_d1_choice_cover", 60):
				return false
			_check(_finish_cine() == "cine_d1_choice_cover", "the cover tail plays")
			_next(13)
		13:
			if not _cine_started("cine_d1", 60):
				return false
			_check(_finish_cine() == "cine_d1", "cine_d1 (the courier's phone)")
			_next(14)
		14:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_bed" and sr.markers.has("d1_bed") and not sr.markers.has("d1_locker"), "free roam until bed (the locker was used)")
			var ch3: Dictionary = (sd.call("read_save", TMP) as Dictionary).get("choices", {})
			_check(String(ch3.get("phuc", "")) == "cover", "the choice is in the autosave")
			_check(sr.start_marker("d1_bed") and String(sd.get("step")) == "d1_call", "bed: the 3 a.m. call")
			_next(15)
		15:
			if sr.call == null:
				if frames > 120:
					_check(false, "the call did not start")
					phase = 999
				return false
			var c: StoryCall = sr.call
			_check(c.days == 6, "the call says 6 days")
			var n4: int = 0
			while c.phase != "ring" and n4 < 300:
				c.step(DT)
				n4 += 1
			c.answer()
			while sr.call != null and n4 < 3000:
				c.step(DT)
				n4 += 1
			_next(16)
		16:
			if not _cine_started("Day 2 cine_day_start", 120):
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 2 and dc.left == 6 and int(sd.get("day")) == 2, "Day 2 morning: NGÀY 2 · CÒN 6 NGÀY")
			_finish_cine()
			_next(17)
		17:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d2_wait" and sr.markers.has("d2_wait"), "Day 2 placeholder with the bed marker")
			_check(String(sd.get("objective")) == "Ngày 2: Bầy Sói – sắp có trong bản cập nhật sau. Về BE6 ngủ để sang ngày tiếp.", "B-D6 objective: %s" % String(sd.get("objective")))
			_check(String(sd.call("day_chip_text")) == "NGÀY 2 · CÒN 6 NGÀY", "Day 2 chip")
			# Continue from the autosave after the brawl
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(18)
		18:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", SNAP)
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d1_corridor", "Continue restores d1_corridor")
			_roam()
			_next(19)
		19:
			if frames < 40:
				return false
			_check(sr.markers.has("d1_corridor") and sr.mission_node == null and fr.get("cine_player") == null, "after Continue: the corridor marker, nothing starts by itself")
			_check(String(fr.get("tod_preset")) == "night" and bool((sd.get("flags") as Dictionary).get("d1_key", false)) and not sd.call("has_evidence", "E2"), "night, the key flag, E2 not taken yet")
			# a recorded choice is never asked again: the report tail follows directly
			(sd.get("choices") as Dictionary)["phuc"] = "report"
			sd.call("set_step", "d1_choice")
			sr.refresh()
			_check(sr.start_marker("d1_choice"), "[E] at the bench with the choice already recorded")
			_next(20)
		20:
			if not _cine_started("the report tail", 90):
				return false
			var cp2: CinePlayer = fr.get("cine_player")
			_check(cp2.timeline.slot == "cine_d1_choice_report" and String(sd.get("step")) == "d1_choice_tail", "the choice scene is skipped: the report tail plays")
			_finish_cine()
			fr.queue_free()
			return _end()
	return false


## Puts the player at corridor progress p and lets the mission tick.
func _corridor_to(mc: MissionCorridor, p: float) -> void:
	var z: float = MissionCorridor.START_Z - p * (MissionCorridor.START_Z - (MissionCorridor.Z0 - MissionCorridor.LEN_M) - 1.0)
	_player().teleport(mc.xf * Vector3(0.1, 0.0, z), mc._yaw_down())
	mc.advance(0.1)


func _end() -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SNAP))
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 1 END TO END (stake-out, chase, brawl, corridor, E2, choice, call, Day 2, continue)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true

