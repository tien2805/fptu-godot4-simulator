# File: res://tests/test_story_day3.gd
# Headless end-to-end test of story Day 3 "Bến container" (spec C-D7; plan 2026-10-26-phase-c-integration.md), from the
# end of Day 2: the call N = 5 -> the Day 3 morning -> the container yard (LairYard, built in FreeRoam on the waterfront
# east of the Rạch Hầm bridge) and its gate marker -> cine_d3_intro -> the sneak (guards with the horror sight: seen =
# the gunfight starts early; down = TOANG! -> THỬ LẠI, the patrol unalerted again; the patrol knocked out, then the goal)
# -> cine_d3_mannequins (the yard's stack hidden while it plays, then open with the mannequins) -> the gunfight in two
# waves (armed: the Phase W pistol / shotgun, finite ammo, pickups; down = TOANG! -> retry; the seg_d3_gunfight replay) ->
# the crates (9 counted with the coffin-dance one, the meme slot while it is carried, every crate broken -> seg_d3_crates,
# the flag for E4) -> the boss marker with the optional E4 manifest (taken) -> the forklift boss (Alexander's body, down =
# TOANG! -> retry, topple) -> seg_d3_boss -> cine_d3 -> bed -> the call N = 4 -> Day 4 (the yard is gone). Then Continue
# at d3_crates: Alexander comes back before every crate is broken (no E4 offered), and Chọn cảnh snapshots of the yard
# beats.
# Wave 3 integration: a time-scale audit (tests/support/time_scale_audit.gd) watches the whole run (the crane, the
# forklifts, the coffin crate's orbit, the director cuts, Impact): no frame with the scale off 1 and no owner, no owner
# holding it over 6 s, clean at the end.
# Run:  godot --headless --path . --script tests/test_story_day3.gd
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")

var TMP: String = "user://test_story_day3_%d.cfg" % OS.get_process_id()
var SNAP: String = "user://test_story_day3_snap_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_story_day3_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_story_day3_chapters_%d.cfg" % OS.get_process_id()
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
var audit: Node = null


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STORY DAY 3 (Bến container: sneak, mannequins, gunfight, crates, forklift, E4, continue) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, SNAP, TMP_U, TMP_C]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	audit = TimeAudit.new()
	audit.name = "TimeScaleAudit"
	root.add_child(audit)


func _roam() -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", true)
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
	if mn != null and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


## Knocks out every gunman of the fight that is still up (pistol hits from the player).
func _ko_all(f: GunFight) -> void:
	for e: Variant in f.alive():
		if e is Gunman:
			var n: int = 0
			while not (e as Gunman).is_defeated() and n < 10:
				(e as Gunman).take_hit({"kind": "bullet", "from": _player().global_position})
				n += 1


## Steps the mission's short replay to its end (manual_replay).
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
	if total > 60000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	if m != null and is_instance_valid(m) and m.state == "running" and phase in [4, 5, 7, 8, 9, 13, 21]:
		m.advance(DT)
	match phase:
		0:
			sd.call("new_story", {"female": true, "name": "Vy", "variant": 2, "hair_style": "bob", "hair_color": 1, "skin": 1})
			sd.set("day", 2)
			for e: String in ["E1", "E3"]:
				(sd.get("evidence") as Array).append(e)
			sd.call("_enter", "d2_call")
			_roam()
			_next(1)
		1:
			var n: int = _do_call()
			if n < 0:
				if frames > 150:
					_check(false, "the Day 2 call did not start")
					phase = 999
				return false
			_check(n == 5, "the call after Day 2 says 5")
			_next(2)
		2:
			if not _cine_started("Day 3 morning"):
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 3 and dc.left == 5, "Day 3 morning card (CÒN 5 NGÀY)")
			_finish_cine()
			_next(3)
		3:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d3_sneak" and sr.markers.has("d3_sneak") and sr.yard != null, "the yard is built for Day 3, its gate marker")
			var y: LairYard = sr.yard
			_check(y.crates.size() == 8 and not y.stack_open and y.stack_doors.size() == 6 and y.stack_doors[1].state == "shut", "8 crates of smart glasses, the mannequin stack shut")
			var gp: Vector3 = sr.anchors["yard_gate"]["pos"]
			_check(Vector2(gp.x, gp.z).distance_to(LairYard.CENTER) < 35.0 and Vector2(gp.x, gp.z).distance_to(Vector2(2123.0, 153.0)) < 60.0, "the yard is on the canal by the Rạch Hầm bridge")
			var covers: int = 0
			for n2: Node in y.find_children("*", "StaticBody3D", true, false):
				if n2.is_in_group("cover"):
					covers += 1
			_check(covers >= 19, "cover tagged for CoverMap (%d)" % covers)
			_check(sr.start_marker("d3_sneak") and _finish_cine() == "cine_d3_intro", "[E]: cine_d3_intro (night drive, Anh Duy on the radio)")
			_next(4)
		4:
			m = _wait_mission("MissionYardSneak")
			if m == null:
				return false
			var ms: MissionSneak = m
			_check(ms.fight.gunmen.size() == 6 and ms.fight.state == "running", "the sneak: 3 patrols + the pair partner + the sleeper + the phone guard (%d)" % ms.fight.gunmen.size())
			# W3 T2: the floodlight sweep, the sleeper, the phone guard
			var my: MissionYardSneak = m
			var yd: LairYard = sr.yard
			_check(my.beams.size() == 2 and my.preview_cuts == 0, "two floodlight beams, no cut yet")
			my.advance(1.05)
			_check(my.preview_cuts == 1 and my.events_done.has("flood") and not my.spotted, "the first sweep opens with a preview cut (the start spot is dark)")
			var b0: Dictionary = my.beams[0]
			var open_p: Vector3 = yd.world(Vector3(-15.5, 0.0, 7.0))
			my.set_beam_point(b0, open_p)
			_check(my.beam_sees(b0, open_p + Vector3(0.0, 1.0, 0.0)), "the floodlight finds a player in its disc")
			var hid_p: Vector3 = yd.world(Vector3(-15.0, 0.0, 1.0))
			my.set_beam_point(b0, hid_p)
			_check(not my.beam_sees(b0, hid_p + Vector3(0.0, 1.0, 0.0)), "a container between the lamp and the player hides him")
			_check(not my.beam_sees(b0, open_p + Vector3(0.0, 1.0, 0.0)), "outside the disc: not seen")
			my._place_beam(b0)
			_check(my.sleeper != null and my.asleep and my.sleeper.state_name() == "hold", "a guard asleep on the pallets")
			var slp: Vector3 = my.sleeper.global_position
			_check(not my.wake_check(slp + Vector3(2.0, 0.0, 0.0), false), "walking right past the sleeper: he sleeps on")
			_check(my.wake_check(slp + Vector3(4.0, 0.0, 0.0), true), "a sprint within 6 m wakes him")
			_check(not my.wake_check(slp + Vector3(9.0, 0.0, 0.0), true), "a sprint far off does not")
			_check(my.phone_guard != null and is_equal_approx(my.phone_guard.patrol_sight_m, HorrorStalker.SIGHT * 0.5), "the guard on his phone: half sight")
			var g0: Gunman = ms.fight.gunmen[0]
			_check(not g0.is_alerted and is_equal_approx(g0.patrol_sight_m, HorrorStalker.SIGHT) and is_equal_approx(g0.patrol_fov_deg, 70.0), "the horror sight rules while patrolling (14 m, 70 deg)")
			var w: WeaponDirector = fr.get("weapons")
			_check(w.current == WeaponData.Slot.PISTOL and not w.locked, "lair rule: the Phase W pistol in hand")
			_check(StoryRoam.mission_slot(sd.call("beat")) == "mission_sneak" and ms.cues_played.has("radio"), "mission_sneak, Anh Duy on the radio")
			_check(sr.yard.look_held and LookPresets.active(fr) == "port_night", "W3 T1: port_night held while the yard mission runs (%s)" % LookPresets.active(fr))
			# walk right in front of a guard: seen
			var g: Gunman = ms.fight.gunmen[1]
			_player().teleport(g.global_position + g.forward() * 5.0, 0.0)
			_next(5)
		5:
			var ms5: MissionSneak = m
			if not ms5.spotted:
				if frames > 120:
					_check(false, "standing in front of a guard: not spotted")
					phase = 999
				return false
			var near_ok: bool = true
			var queued: int = 0
			for e2: Variant in ms5.fight.alive():
				var g5: Gunman = e2
				if g5.is_alerted:
					continue
				queued += 1
				near_ok = near_ok and (ms5 as MissionYardSneak).reinforcements.has(g5) and WeaponMath.flat(g5.global_position, _player().global_position) > MissionYardSneak.NEAR_ALERT_M
			_check(near_ok and ms5.state == "running", "seen: the gunfight starts early: the guards near alerted, the far ones queued as reinforcements (%d)" % queued)
			_check((ms5 as MissionYardSneak).hud_info.is_visible_in_tree() and (ms5 as MissionYardSneak).markers != null and (ms5 as MissionYardSneak).markers.threat_source.is_valid(), "T10: the objective line on screen, the guards marked once seen")
			ms5.fight.combat.receive_attack(ms5.fight.gunmen[0], {"damage": 999.0})
			_next(6)
		6:
			if not (sr.fail_ui and sr.fail_ui.visible):
				if frames > 60:
					_check(false, "down in the sneak but no TOANG!")
					phase = 999
				return false
			_check(sr.fail_ui.title_label.text == "TOANG!", "down: TOANG!")
			sr.fail_ui.press_retry()
			var ms6: MissionSneak = m
			var calm: bool = true
			for e3: Variant in ms6.fight.alive():
				calm = calm and not (e3 as Gunman).is_alerted
			_check(not ms6.spotted and calm and ms6.fight.alive().size() == 6, "THỬ LẠI: the patrol again, unalerted")
			var my6: MissionYardSneak = m
			_check(my6.asleep and my6.sleeper != null and my6.sleeper.state_name() == "hold" and not my6.flood_spotted, "THỬ LẠI: the sleeper dozes again, the beams cyan")
			# spotted again, the patrol knocked out, then the goal
			var g2: Gunman = ms6.fight.gunmen[0]
			_player().teleport(g2.global_position + g2.forward() * 4.0, 0.0)
			_next(7)
		7:
			var ms7: MissionSneak = m
			if not ms7.spotted:
				if frames > 120:
					_check(false, "not spotted the second time")
					phase = 999
				return false
			var goal: Vector3 = ms7.pts["goal"]
			_player().teleport(goal, 0.0)
			ms7.advance(DT)
			_check(ms7.state == "running", "seen: the goal does not end the sneak while guards are up")
			_ko_all(ms7.fight)
			_next(8)
		8:
			if not _cine_started("cine_d3_mannequins", 120):
				return false
			_check(String(sd.get("step")) == "d3_mannequins" and not sr.yard.stack.visible, "the stack is hidden while the discovery beat plays")
			var cp8: CinePlayer = fr.get("cine_player")
			_check(cp8.timeline.slot == "cine_d3_mannequins" and cp8.stage_xf.origin.distance_to(sr.yard.pad_xf().origin) < 0.05, "cine_d3_mannequins at the yard's cine pad")
			_finish_cine()
			_next(9)
		9:
			if frames < 3:
				return false
			_check(sr.yard.stack.visible and sr.yard.stack_open and sr.yard.stack_doors[1].state == "open" and sr.yard.stack_crowds[0].visible, "after the discovery: the stack open, the mannequins staring out")
			m = _wait_mission("MissionYardGunfight")
			if m == null:
				return false
			var mg: MissionGunfight = m
			var my9: MissionYardGunfight = m
			_check(mg.fight.waves.size() >= 3 and mg.fight.alive().size() == 3 and mg.fight.pickups.size() == 5 and my9.hide_state == "sweep", "the gunfight opens with the mannequin hide (3 sweepers in wave 0), then the waves; 3 ammo pickups + 2 radio drops")
			_check(my9.mannequins != null and my9.mannequins.count() >= 38, "the mannequins in front of the open stack")
			_check(my9.markers != null and my9.hud_info.is_visible_in_tree() and my9.markers.is_tracked(my9._ladder_mark) and not my9.markers.is_on(my9._ladder_mark),
				"T10: the objective line on screen; the crane's ladder marked, off until wave 2")
			var w9: WeaponDirector = fr.get("weapons")
			_check(w9.reserve.size() > 0 and w9.reserve[WeaponData.Slot.PISTOL] >= 0, "finite spare rounds in the lair")
			_check(StoryRoam.mission_slot(sd.call("beat")) == "mission_gunfight", "mission_gunfight")
			mg.fight.combat.receive_attack(mg.fight.gunmen[0], {"damage": 999.0})
			_next(10)
		10:
			if not (sr.fail_ui and sr.fail_ui.visible):
				if frames > 60:
					_check(false, "down in the gunfight but no TOANG!")
					phase = 999
				return false
			sr.fail_ui.press_retry()
			_check((m as MissionGunfight).fight.state == "running" and (m as MissionGunfight).fight.alive().size() == 3 and (m as MissionYardGunfight).hide_state == "sweep", "retry: the hide again")
			_next(11)
		11:
			var mg11: MissionGunfight = m as MissionGunfight if is_instance_valid(m) else null
			if mg11 and mg11.state == "running":
				mg11.advance(DT)
				if mg11.fight and mg11.fight.state == "running":
					_ko_all(mg11.fight)
				var my11: MissionYardGunfight = mg11 as MissionYardGunfight
				if my11:
					mark["gf_cuts"] = my11.preview_cuts
					mark["gf_crane"] = my11.crane_offered or bool(mark.get("gf_crane", false))
					mark["gf_waves"] = my11.fight.waves.size() if my11.fight else int(mark.get("gf_waves", 0))
					mark["gf_hidden"] = my11.hidden
					if my11.fight and my11.fight.wave == MissionYardGunfight.CRANE_WAVE and my11.markers:
						mark["gf_ladder_on"] = bool(mark.get("gf_ladder_on", false)) or my11.markers.is_on(my11._ladder_mark)
			if mg11 and _step_replay(mg11):
				mark["gf_replay"] = true
			if String(sd.get("step")) != "d3_crates":
				if frames > 1500:
					_check(false, "the gunfight was not won (%s)" % (mg11.fight.state if mg11 and mg11.fight else "gone"))
					phase = 999
				return false
			_check(mark.has("gf_replay"), "the yard cleared: the seg_d3_gunfight replay")
			_check(int(mark.get("gf_waves", 0)) == 4 and int(mark.get("gf_cuts", 0)) == 3, "W3 T5: the hide + 3 waves on Thường, a preview cut at each combat wave (%d waves, %d cuts)" % [int(mark.get("gf_waves", 0)), int(mark.get("gf_cuts", 0))])
			_check(bool(mark.get("gf_crane", false)) and not bool(mark.get("gf_hidden", true)), "W3 T5: the crane offered in wave 2; shooting the sweepers blew the hide")
			_check(bool(mark.get("gf_ladder_on", false)), "T10: the ladder marker shows in the crane wave")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(SNAP))
			_next(12)
		12:
			m = _wait_mission("MissionCrates")
			if m == null:
				return false
			var mc: MissionCrates = m
			_check(mc.total() == 12 and mc.broken_count() == 0 and mc.dancers.size() == 4 and mc.dance.visible, "12 crates counted (8 + the rack's 3 + the coffin-dance one), 4 carriers")
			_check(mc.preview_cuts == 1 and not mc.rack.visible and mc.gate_guards().size() == 2, "W3 T6: a preview cut on the carriers at the start; the rack and the gate guards held back")
			var top: Control = mc.hud.get_node_or_null("Top") as Control
			_check(top != null and top.is_visible_in_tree() and mc.hud_info.is_visible_in_tree() and mc.hud_meter.is_visible_in_tree()
				and mc.hud_info.text == "Thùng kính: 0 / 12 · Còn %d s" % int(MissionCrates.TIME_S) and top.offset_top >= GunHUD.TOP + GunHUD.PANEL.y,
				"the counter and the %d s countdown are on screen, under the gunfight panel (%s)" % [int(MissionCrates.TIME_S), mc.hud_info.text])
			_check(mc.markers != null and mc.markers.is_tracked(mc.carried) and mc.markers.is_tracked(mc.strap), "T10: markers for the coffin crate and the strap")
			mc.advance(1.5)
			_check(mc.hud_info.text == "Thùng kính: 0 / 12 · Còn %d s" % (int(MissionCrates.TIME_S) - 1) and mc.hud_meter.value < 100.0, "the countdown runs (%s)" % mc.hud_info.text)
			_check(mc.meme_on and mc.cues_played.has("meme_coffin_dance") and StoryRoam.mission_slot(sd.call("beat")) == "meme_coffin_dance", "the coffin-dance meme slot while they carry it")
			var p0: Vector3 = mc.dance.global_position
			for k: int in 60:
				mc.advance(DT)
			_check(mc.dance.global_position.distance_to(p0) > 0.5, "the carriers walk their loop")
			# W3 T6: the events on the clock
			while mc.clock < mc.gate_at + 0.1:
				mc.advance(0.1)
			var gg: Array = mc.gate_guards()
			_check(mc.gate_on and (gg[0] as Gunman).is_alerted and (gg[1] as Gunman).is_alerted and mc.preview_cuts == 2, "%.0f s: 2 guards from the gate, alerted, a preview cut on them" % mc.gate_at)
			_ko_all(mc.fight)
			_check(mc.state == "running", "the gate guards down: the beat goes on (the crates are the goal)")
			while mc.clock < mc.rack_at + 0.1:
				mc.advance(0.1)
			_check(mc.rack_on and mc.rack.visible and mc.preview_cuts == 3, "%.0f s: the pallet rack rolls out (a preview cut on its strap)" % mc.rack_at)
			_check(mc.strap.take_hit({"kind": "bullet", "from": _player().global_position}) == "knocked_out", "the strap shot")
			mc.advance(0.05)
			var rb: int = 0
			for rc: SmartCrate in mc.rack_crates:
				rb += 1 if rc.broken else 0
			_check(rb == 1, "the chain: the top crate first (%d)" % rb)
			mc.advance(0.7)
			rb = 0
			for rc2: SmartCrate in mc.rack_crates:
				rb += 1 if rc2.broken else 0
			_check(rb == 3 and mc.broken_count() == 3 and mc.hello_shown, "then the other two: the whole rack down; the glasses greet the world")
			while mc.clock < mc.fast_at + 0.1:
				mc.advance(0.1)
			_check(mc.fast and mc._dance_speed > MissionCrates.DANCE_SPEED, "%.0f s: the dancers speed up" % mc.fast_at)
			while mc.time_left > mc.time_up_warn - 0.1:
				mc.advance(0.1)
			_check(mc.time_up_cut and mc.cues_played.has("forklift_horn") and mc._lights.visible and mc.preview_cuts == 4, "%.0f s left: Alexander's horn and headlights at the gate, a preview cut" % mc.time_up_warn)
			_check(mc.carried.take_hit({"kind": "bullet", "from": _player().global_position}) == "knocked_out" and not mc.meme_on and mc.fleeing >= 0.0, "their crate shot: they drop it and run, the meme stops")
			for c: Variant in mc.crates:
				(c as SmartCrate).take_hit({"kind": "melee", "from": _player().global_position})
			_check(mc.broken_count() == 12, "every crate broken (shot or hit)")
			_next(13)
		13:
			var mc13: MissionCrates = m as MissionCrates if is_instance_valid(m) else null
			if mc13 and _step_replay(mc13):
				mark["cr_replay"] = true
			if String(sd.get("step")) != "d3_boss":
				if frames > 600:
					_check(false, "the crates beat did not end")
					phase = 999
				return false
			_check(mark.has("cr_replay") and bool((sd.get("flags") as Dictionary).get("d3_all_crates", false)), "the last crate: seg_d3_crates, the E4 flag")
			_next(14)
		14:
			if frames < 5:
				return false
			_check(sr.markers.has("d3_boss") and sr.markers.has("d3_manifest"), "the boss marker and the optional manifest (every crate broken)")
			_check(sr.use_side("d3_manifest") and sd.call("has_evidence", "E4"), "the manifest: E4")
			_check(sr.start_marker("d3_boss"), "[E]: the forklift boss")
			_next(15)
		15:
			m = _wait_mission("MissionForklift")
			if m == null:
				return false
			var mf: MissionForklift = m
			var boss: ForkliftBoss = mf.fight.boss as ForkliftBoss
			_check(boss != null and String(boss.driver.get_meta("cast_id", "")) == "alexander", "Alexander drives the forklift")
			_check(not sr.yard.forklift_park.visible, "the parked forklift is gone (he drives it)")
			_check(StoryRoam.mission_slot(sd.call("beat")) == "boss_d3", "boss_d3")
			_check(mf.markers != null and mf.markers.is_tracked(boss.forklift) and mf.markers.is_tracked(mf.pf.forklift) and mf.hud_info.is_visible_in_tree(),
				"T10: Alexander and the player's forklift marked, the objective line on screen")
			mf.fight.combat.receive_attack(boss, {"damage": 999.0})
			_next(16)
		16:
			if not (sr.fail_ui and sr.fail_ui.visible):
				if frames > 60:
					_check(false, "down vs the forklift but no TOANG!")
					phase = 999
				return false
			sr.fail_ui.press_retry()
			var mf16: MissionForklift = m
			_check(mf16.fight.state == "running" and mf16.fight.boss != null and is_equal_approx((mf16.fight.boss as ForkliftBoss).hp, (mf16.fight.boss as ForkliftBoss).max_hp), "retry: a fresh boss")
			_check(mf16.markers.is_tracked((mf16.fight.boss as ForkliftBoss).forklift), "T10: the marker follows the fresh boss")
			(mf16.fight.boss as ForkliftBoss).apply_damage(99999.0)
			_next(17)
		17:
			var mf17: MissionForklift = m as MissionForklift if is_instance_valid(m) else null
			if mf17 and mf17.state == "running":
				mf17.advance(DT)
			if fr.get("cine_player") == null:
				if frames > 900:
					_check(false, "the forklift did not topple / seg_d3_boss did not start")
					phase = 999
				return false
			var cp17: CinePlayer = fr.get("cine_player")
			_check(cp17.timeline.slot == "seg_d3_boss" and cp17.stage_xf.origin.distance_to(sr.yard.pad_xf().origin) < 0.05, "toppled: seg_d3_boss at the yard pad")
			_finish_cine()
			_next(18)
		18:
			if not _cine_started("cine_d3", 120):
				return false
			_check(_finish_cine() == "cine_d3", "cine_d3: the endless name cut off, the USB")
			_next(19)
		19:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d3_bed" and sr.markers.has("d3_bed") and sr.yard != null, "bed marker, the yard still there for the night")
			_check(not sr.yard.forklift_park.visible, "the parked forklift stays gone after the boss")
			_check(not sr.yard.look_held and sr.mission_node == null, "W3 T1: no yard mission, the held look is popped")
			for id: String in ["d3_sneak", "d3_mannequins", "d3_gunfight", "d3_crates", "d3_boss", "d3_end"]:
				_check(StoryChapters.is_beat_unlocked(id) and not StoryChapters.snapshot(id).is_empty(), "Chọn cảnh: %s snapshotted" % id)
			_check(sr.start_marker("d3_bed"), "bed")
			_next(20)
		20:
			var n20: int = _do_call()
			if n20 < 0:
				if frames > 150:
					_check(false, "the Day 3 call did not start")
					phase = 999
				return false
			_check(n20 == 4, "the call after Day 3 says 4")
			_check(sr.yard == null, "the yard is freed after Day 3")
			_check(not ((fr.get_meta("look_stack", []) as Array).has("port_night")), "W3 T1: the roam look restored (no port_night left on the stack)")
			_next(22)
		22:
			if not _cine_started("Day 4 morning"):
				return false
			_finish_cine()
			_next(23)
		23:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d4_canteen" and sd.call("has_evidence", "E4") and sd.call("has_evidence", "E3"), "Day 4 as built, E3 and E4 kept")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(24)
		24:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", SNAP)
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d3_crates", "Continue restores d3_crates")
			_roam()
			_next(25)
		25:
			if frames < 45:
				return false
			_check(sr.yard != null and sr.markers.has("d3_crates") and sr.mission_node == null, "Continue: the yard rebuilt, the crates marker, nothing starts by itself")
			_check(sr.start_marker("d3_crates"), "[E]: the crates again")
			_next(26)
		26:
			m = _wait_mission("MissionCrates")
			if m == null:
				return false
			var mc26: MissionCrates = m
			(mc26.crates[0] as SmartCrate).smash(_player().global_position)
			var n26: int = 0
			while mc26.state == "running" and n26 < 200:
				mc26.advance(0.5)
				n26 += 1
			_check(mc26.state == "done" and String(sd.get("step")) == "d3_boss", "time up: Alexander comes back, the beat ends")
			_next(27)
		27:
			if frames < 60:   # the time-up preview cut (fired when the loop above ran the clock past 20 s left) is over
				return false
			_check(not bool((sd.get("flags") as Dictionary).get("d3_all_crates", false)) and sr.markers.has("d3_boss") and not sr.markers.has("d3_manifest"), "not every crate broken: no E4 offered")
			sd.call("set_step", "d3_bed")
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(28)
		28:
			if frames < 3:
				return false
			sd.call("reset_state")
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d3_bed", "Continue restores d3_bed")
			_roam()
			_next(29)
		29:
			if frames < 45:
				return false
			_check(sr.yard != null and not sr.yard.forklift_park.visible, "Continue at d3_bed: the yard rebuilt without the parked forklift")
			fr.queue_free()
			return _end()
	return false


func _end() -> bool:
	if audit:
		print("  ", audit.call("report"))
		_check(bool(audit.call("clean", 6.0)), "the time scale stayed in the owner protocol (%s)" % String(audit.call("report")))
	for p: String in [TMP, SNAP, TMP_U, TMP_C]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 3 (yard, sneak seen / cleared, mannequins, gunfight, crates + coffin dance, E4, forklift, call, continue)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
