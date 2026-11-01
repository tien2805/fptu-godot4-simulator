# File: res://tests/test_side_activities.gd
# Headless test of the free-roam side activities (plan 2026-11-01-w4-endings.md T5):
#   A. data: the three night race routes build on the Day 2 roads (length, par, distinct start spots), the rank and drift
#      bonus rules, SideRecords (best per activity: rank first, then time; the run count; the S count), plain texts;
#   B. races in real story free roam at night (Day 5, d5_bed): the start rings only at night, the hint near a start, [E]
#      starts the race (story busy, on the bike at the grid, countdown with the bike held), a driven run along the path
#      (gates, drift seconds, off the road -> back to the last gate), the finish recorded in the unlock file and the story
#      free again; leaving the bike gives the race up. Perf: the race tick and the activity check stay far under 3 ms.
# Run:  godot --headless --path . --script tests/test_side_activities.gd
extends SceneTree

var TMP: String = "user://test_side_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_side_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_side_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_side_backup_%d.cfg" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const ALLOWED_SYMBOLS: Array[int] = [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026]
var fails: Array[String] = []
var sd: Node
var fr: Node
var sr: StoryRoam
var sa: StorySideActivities
var phase: int = 0
var frames: int = 0
var total: int = 0
var done_ev: Array = []
var fail_ev: Array = []
var perf_race: Array[float] = []
var perf_check: Array[float] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _clean(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c >= 0x2000 and not (c in ALLOWED_SYMBOLS):
			return false
	return true


func _initialize() -> void:
	print("--- TEST SIDE ACTIVITIES (night races, records) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B


func _part_a() -> void:
	var starts: Array[Vector3] = []
	for rid: String in SideRace.ORDER:
		var c: DriftCourse = SideRace.route_course(rid)
		_check(c != null and c.length > 300.0 and c.gates.size() >= 2, "%s builds (%.0f m, %d gates)" % [rid, c.length if c else 0.0, c.gates.size() if c else 0])
		var pt: float = SideRace.par(c)
		_check(pt > 10.0 and pt < 200.0, "%s par %.1f s" % [rid, pt])
		print("  %s: %.0f m, par %.1f s, S under %.1f s" % [rid, c.length, pt, pt * float(SideRace.RANK_K["S"])])
		_check(_clean(SideRace.title(rid)) and _clean(String(SideRace.ROUTES[rid]["line"])), "%s plain title" % rid)
	for sp: Dictionary in StorySideActivities.spots():
		for o: Vector3 in starts:
			_check(o.distance_to(sp["at"]) > 30.0, "%s starts away from the other activities" % String(sp["id"]))
		starts.append(sp["at"])
		_check(_clean(String(sp["title"])), "%s plain title" % String(sp["id"]))
	_check(SideRace.rank_for(10.0, 10.0) == "S" and SideRace.rank_for(14.0, 10.0) == "A" and SideRace.rank_for(17.0, 10.0) == "B"
		and SideRace.rank_for(30.0, 10.0) == "C", "ranks by par x RANK_K")
	_check(is_equal_approx(SideRace.drift_bonus(4.0, 100.0), 2.0) and is_equal_approx(SideRace.drift_bonus(100.0, 100.0), 15.0), "drift bonus 0.5 s per s, capped at 15 % of par")
	_check(SideRace.time_text(83.44) == "1:23.4" and SideRace.time_text(9.0) == "0:09.0", "time text")
	# records
	_check(SideRecords.record("dua_cau", {"rank": "B", "time": 40.0}), "a first result is a best")
	_check(not SideRecords.record("dua_cau", {"rank": "B", "time": 41.0}), "a slower B is not")
	_check(SideRecords.record("dua_cau", {"rank": "B", "time": 39.0}), "a faster B is")
	_check(not SideRecords.record("dua_cau", {"rank": "C", "time": 20.0}), "a worse rank is not, whatever the time")
	_check(SideRecords.record("dua_cau", {"rank": "S", "time": 50.0}), "a better rank is, whatever the time")
	var b: Dictionary = SideRecords.best("dua_cau")
	_check(String(b.get("rank", "")) == "S" and int(b.get("runs", 0)) == 5 and SideRecords.s_count() == 1, "best S, 5 runs, 1 S (%s)" % str(b))
	_check(SideRecords.record("x_score", {"rank": "A", "score": 5}) and SideRecords.record("x_score", {"rank": "A", "score": 7})
		and not SideRecords.record("x_score", {"rank": "A", "score": 6}), "score activities: higher is better")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_U))


func _next(p: int) -> void:
	phase = p
	frames = 0


func _race() -> SideRace:
	return sa.current as SideRace


## Drives the bike along the race path at v m/s for sec seconds (teleports: no physics needed), ticking the race.
func _drive(r: SideRace, v: float, sec: float, drifting: bool = false) -> void:
	var bike: Node3D = r.bike
	var y: float = bike.global_position.y
	var s: float = r.s_p
	var n: int = int(sec / DT)
	bike.set("is_drifting", drifting)
	for i: int in n:
		if r.state != "racing":
			break
		s += v * DT
		var p: Vector2 = r.course.world(s, 0.0)
		bike.global_position = Vector3(p.x, y, p.y)
		var t0: int = Time.get_ticks_usec()
		r.advance(DT)
		perf_race.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	bike.set("is_drifting", false)


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 20000:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	match phase:
		0:
			_part_a()
			sd.call("reset_state")
			sd.call("new_story", {"female": true, "name": "Mai", "variant": 1, "hair_style": "bob", "hair_color": 1, "skin": 1})
			sd.set("day", 5)
			sd.set("step", "")
			sd.call("_enter", "d5_bed")
			sd.call("save_game")
			fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			sr = fr.get("story_roam")
			sa = sr.side_activities if sr else null
			_check(sa != null, "StoryRoam has the side activities")
			if sa == null:
				return _end()
			sa.auto_tick = false
			sr.night_events.auto_tick = false
			sr.night_secrets.auto_tick = false
			sa.activity_done.connect(func(id: String, res: Dictionary, nb: bool) -> void: done_ev.append([id, res, nb]))
			sa.activity_failed.connect(func(id: String, why: String) -> void: fail_ev.append([id, why]))
			_next(1)
		1:
			if frames < 5:
				return false
			fr.set("tod_preset", "morning")
			sa.advance(1.0)
			_check(not sa.can_start("dua_cau") and not sa.can_start("giao_dem") and sa.markers.size() == SideTakedown.ORDER.size() + 1 + SideVovinam.ORDER.size()
				and sa.can_start("td_soi") and sa.can_start("giao_com"), "by day: no race / night run, the takedown and day delivery rings (%d)" % sa.markers.size())
			fr.set("tod_preset", "night")
			var t0: int = Time.get_ticks_usec()
			sa.advance(1.0)
			perf_check.append(float(Time.get_ticks_usec() - t0) / 1000.0)
			_check(sa.can_start("dua_cau") and sa.markers.size() == StorySideActivities.spots().size(), "at night: every ring (%d)" % sa.markers.size())
			var sp: Dictionary = StorySideActivities.spot("dua_cau")
			var pl: Node = fr.get("player")
			pl.call("teleport", (sp["at"] as Vector3) + Vector3(3.0, 0.5, 0.0), 0.0)
			_next(2)
		2:
			if frames < 3:
				return false
			for i: int in 5:
				var t1: int = Time.get_ticks_usec()
				sa.advance(1.0)
				perf_check.append(float(Time.get_ticks_usec() - t1) / 1000.0)
			_check(sa.near_id == "dua_cau", "near the start: the race is offered (%s)" % sa.near_id)
			_check(sa.hint_text("dua_cau").begins_with("[E] Đua đêm: ") and _clean(sa.hint_text("dua_cau")), "the hint (%s)" % sa.hint_text("dua_cau"))
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_E
			ev.pressed = true
			sa._unhandled_input(ev)
			var r: SideRace = _race()
			_check(r != null and sa.current_id == "dua_cau" and bool(sr.busy), "[E] starts the race, the story is busy")
			if r == null:
				return _end()
			r.auto_tick = false
			_check(bool(fr.get("mounted")) and r.state == "countdown" and float(r.bike.get("speed_cap")) == 0.0, "on the bike at the grid, held for the countdown")
			_check(sa.markers.is_empty(), "the rings go while it runs")
			_next(3)
		3:
			if frames < 2:
				return false
			var r2: SideRace = _race()
			_check(r2.bike.global_position.distance_to(Vector3(r2.course.world(0.0, 0.0).x, r2.bike.global_position.y, r2.course.world(0.0, 0.0).y)) < 1.0, "the bike sits on the grid")
			for i: int in 200:
				r2.advance(DT)
			_check(r2.state == "racing" and float(r2.bike.get("speed_cap")) > 1000.0, "GO after the countdown, the bike let go")
			_drive(r2, 20.0, 6.0, true)
			_drive(r2, 20.0, 4.0)
			_check(r2.gate_i >= 1 and r2.drift_s > 5.0, "gates passed (%d), drift seconds (%.1f)" % [r2.gate_i, r2.drift_s])
			# off the road: back to the last gate
			var g: float = r2.course.gates[r2.gate_i - 1]
			var off: Vector2 = r2.course.world(r2.s_p, 30.0)
			r2.bike.global_position = Vector3(off.x, r2.bike.global_position.y, off.y)
			for i2: int in 80:
				r2.advance(DT)
			_check(r2.resets == 1 and is_equal_approx(r2.s_p, g), "off the road 1.2 s: back to the last gate (%d, %.0f)" % [r2.resets, r2.s_p])
			_check(_clean(" ".join(PackedStringArray(r2.texts()))), "race HUD plain text")
			_drive(r2, 22.0, 60.0)
			_check(r2.state == "done", "the race finishes (%s, s %.0f / %.0f)" % [r2.state, r2.s_p, r2.course.length])
			_next(4)
		4:
			if frames < 3:
				return false
			_check(done_ev.size() == 1 and String(done_ev[0][0]) == "dua_cau" and bool(done_ev[0][2]), "activity_done with a new best")
			var res: Dictionary = done_ev[0][1] if done_ev.size() == 1 else {}
			print("  dua_cau run: %s" % str(res))
			_check(String(res.get("rank", "")) in StoryRank.LETTERS and float(res.get("time", 0.0)) < float(res.get("raw", 0.0)), "rank and drift-scored time")
			var b: Dictionary = SideRecords.best("dua_cau")
			_check(not b.is_empty() and String(b["rank"]) == String(res.get("rank", "?")), "the best is in the unlock file")
			_check(sa.current == null and not bool(sr.busy) and r_nitro_back(), "the story is free again, the bike given back")
			_check(sa.hint_text("dua_cau").contains("Kỷ lục: Hạng"), "the hint shows the best rank")
			# give up: start dua_vong, leave the bike
			_check(sa.start("dua_vong"), "dua_vong starts")
			var r3: SideRace = _race()
			r3.auto_tick = false
			for i: int in 200:
				r3.advance(DT)
			fr.call("dismount_bike")
			_next(5)
		5:
			if frames < 2:
				return false
			var r4: SideRace = _race()
			if r4:
				for i: int in 150:
					if r4.state != "racing":
						break
					r4.advance(DT)
			_next(6)
		6:
			if frames < 3:
				return false
			_check(fail_ev.size() == 1 and String(fail_ev[0][1]) == "off_bike" and sa.current == null and not bool(sr.busy), "leaving the bike gives the race up (%s)" % str(fail_ev))
			_check(SideRecords.best("dua_vong").is_empty(), "a given-up race records nothing")
			var mx_r: float = 0.0
			var sum_r: float = 0.0
			for v: float in perf_race:
				mx_r = maxf(mx_r, v)
				sum_r += v
			var mx_c: float = 0.0
			for v2: float in perf_check:
				mx_c = maxf(mx_c, v2)
			print("  perf: race tick avg %.3f ms, max %.3f ms (%d ticks); activity check max %.3f ms" % [sum_r / maxf(perf_race.size(), 1.0), mx_r, perf_race.size(), mx_c])
			_check(sum_r / maxf(perf_race.size(), 1.0) < 0.5 and mx_c < 3.0, "perf under budget")
			# T5b: a takedown challenge, by day
			fr.set("tod_preset", "morning")
			var sp: Dictionary = StorySideActivities.spot("td_soi")
			(fr.get("player") as Node).call("teleport", (sp["at"] as Vector3) + Vector3(2.0, 0.5, 0.0), 0.0)
			_next(7)
		7:
			if frames < 3:
				return false
			sa.advance(1.0)
			_check(sa.near_id == "td_soi" and sa.hint_text("td_soi").begins_with("[E] Hạ gục: "), "near the takedown start: offered by day (%s)" % sa.near_id)
			_check(sa.start("td_soi"), "td_soi starts")
			var td: SideTakedown = sa.current as SideTakedown
			_check(td != null and td.chase != null and bool(sr.busy) and bool(fr.get("mounted")), "a free-mode chase runs, the player on the bike, the story busy")
			if td:
				td.auto_tick = false
			_next(8)
		8:
			var td2: SideTakedown = sa.current as SideTakedown
			if td2 == null:
				_next(9)
				return false
			td2.advance(DT)
			for b: Variant in td2.chase.alive():
				(b as BikerEnemy).crash("kick")
			if frames > 1500:
				_check(false, "td_soi did not finish (%s, %d/%d down)" % [td2.state, td2.downed, td2.total])
				return _end()
			return false
		9:
			if frames < 3:
				return false
			var last: Array = done_ev[-1] if not done_ev.is_empty() else []
			_check(not last.is_empty() and String(last[0]) == "td_soi" and int((last[1] as Dictionary).get("downed", 0)) == 3, "td_soi done, 3 down (%s)" % str(last))
			_check(SideRecords.best("td_soi").get("rank", "") in StoryRank.LETTERS and not bool(sr.busy), "td_soi recorded, the story free")
			# knocked off: given up
			_check(sa.start("td_bay"), "td_bay starts")
			var td3: SideTakedown = sa.current as SideTakedown
			td3.auto_tick = false
			td3.chase.combat.damage(1000.0, "test")
			_next(10)
		10:
			if sa.current != null:
				if frames > 600:
					_check(false, "td_bay was not given up (%s)" % (sa.current as SideTakedown).state)
					return _end()
				return false
			_check(String(fail_ev[-1][0]) == "td_bay" and String(fail_ev[-1][1]) == "knocked" and not bool(sr.busy), "knocked off: td_bay given up (%s)" % str(fail_ev))
			_part_c_data()
			_next(11)
		11:
			if frames < 3:
				return false
			# T5c: a delivery run by day, driven drop to drop, one crash
			_check(sa.start("giao_com"), "giao_com starts")
			var dv: SideDelivery = sa.current as SideDelivery
			if dv == null:
				return _end()
			dv.auto_tick = false
			_check(dv.beacon != null and dv.beacon.global_position.distance_to(Vector3(1932.0, 0.0, -159.0)) < 0.1, "the beam over the first drop")
			_check(_clean(" ".join(PackedStringArray(dv.texts()))) and dv.texts()[0].contains("Điểm giao 1/2"), "delivery HUD (%s)" % str(dv.texts()))
			var b: Node3D = fr.get("bike") if bool(fr.get("mounted")) else fr.get("player")
			dv.advance(5.0)
			(fr.get("bike") as Node).emit_signal("crash_occurred")
			for q: Vector2 in SideDelivery.drops("giao_com"):
				b.global_position = Vector3(q.x + 2.0, b.global_position.y, q.y)
				dv.advance(DT)
			_next(12)
		12:
			if frames < 3:
				return false
			var last: Array = done_ev[-1] if not done_ev.is_empty() else []
			_check(not last.is_empty() and String(last[0]) == "giao_com" and int((last[1] as Dictionary).get("crashes", 0)) == 1
				and is_equal_approx(float((last[1] as Dictionary)["time"]), float((last[1] as Dictionary)["raw"]) + SideDelivery.CRASH_PENALTY_S),
				"giao_com delivered, the crash costs %.0f s (%s)" % [SideDelivery.CRASH_PENALTY_S, str(last)])
			_check(not SideRecords.best("giao_com").is_empty() and not bool(sr.busy), "giao_com recorded, the story free")
			# out of time
			_check(sa.start("giao_com"), "giao_com starts again")
			var dv2: SideDelivery = sa.current as SideDelivery
			dv2.auto_tick = false
			dv2.advance(SideDelivery.par("giao_com") * SideDelivery.LIMIT_K + 1.0)
			_check(String(fail_ev[-1][0]) == "giao_com" and String(fail_ev[-1][1]) == "time" and sa.current == null, "out of time: the run is given up")
			_check(SideVovinam.rank_for(27.0, 3, 80.0) == "S" and SideVovinam.rank_for(27.0, 3, 50.0) == "A" and SideVovinam.rank_for(50.0, 3, 90.0) == "B"
				and SideVovinam.rank_for(90.0, 3, 90.0) == "C", "Vovinam ranks (time per opponent and HP)")
			# T5d: a Vovinam street fight, on foot (from the bike), the traffic parked
			_check(sa.start("vo_hem"), "vo_hem starts")
			var vv: SideVovinam = sa.current as SideVovinam
			if vv == null:
				return _end()
			vv.auto_tick = false
			_check(not bool(fr.get("mounted")) and vv.fight != null and vv.total == 3 and bool(sr.busy), "on foot, 3 opponents, the story busy")
			var tr: Node = fr.get("traffic")
			_check(tr == null or not tr.is_physics_processing(), "the traffic is parked for the fight")
			_check(_clean(" ".join(PackedStringArray(vv.texts()))), "Vovinam HUD plain")
			_next(13)
		13:
			var v2: SideVovinam = sa.current as SideVovinam
			if v2 == null:
				_next(14)
				return false
			v2.advance(DT)
			for e: Variant in v2.fight.alive():
				(e as MeleeEnemy).take_strike({"kind": "weapon", "dmg": 999.0, "stagger": 100.0, "push": 0.5, "breaks_block": true,
					"knockdown": true, "from": (e as Node3D).global_position + Vector3(0.0, 0.0, 1.0)})
			if frames > 2400:
				_check(false, "vo_hem did not finish (%s, %d/%d)" % [v2.state, v2.kos, v2.total])
				return _end()
			return false
		14:
			if frames < 3:
				return false
			var last: Array = done_ev[-1] if not done_ev.is_empty() else []
			_check(not last.is_empty() and String(last[0]) == "vo_hem" and int((last[1] as Dictionary).get("kos", 0)) == 3, "vo_hem won, 3 down (%s)" % str(last))
			var tr2: Node = fr.get("traffic")
			_check(tr2 == null or tr2.is_physics_processing(), "the traffic runs again")
			_check(not SideRecords.best("vo_hem").is_empty() and not bool(sr.busy), "vo_hem recorded, the story free")
			# knocked out: given up
			_check(sa.start("vo_cau"), "vo_cau starts")
			var v3: SideVovinam = sa.current as SideVovinam
			v3.auto_tick = false
			v3.fight.combat.hp = 0.0
			v3.fight.combat.state = PlayerCombat.St.DOWN
			_next(15)
		15:
			if sa.current != null:
				if frames > 600:
					_check(false, "vo_cau was not given up")
					return _end()
				return false
			_check(String(fail_ev[-1][0]) == "vo_cau" and String(fail_ev[-1][1]) == "ko" and not bool(sr.busy), "knocked out: vo_cau given up (%s)" % str(fail_ev[-1]))
			var pc: Node = fr.get("combat")
			_check(pc == null or not bool(pc.call("is_down")), "the player stands again after the give-up")
			fr.queue_free()
			fr = null
			return _end()
	return false


func _part_c_data() -> void:
	for did: String in SideDelivery.ORDER:
		var pt: float = SideDelivery.par(did)
		_check(pt > 20.0 and pt < 200.0 and SideDelivery.drops(did).size() >= 2, "%s: par %.1f s, %d drops" % [did, pt, SideDelivery.drops(did).size()])
		for l: String in (SideDelivery.RUNS[did]["lines"] as Array):
			_check(_clean(l), "%s customer line plain" % did)
	_check(SideDelivery.dir_word(Vector2.ZERO, Vector2(0.0, -10.0)) == "Bắc" and SideDelivery.dir_word(Vector2.ZERO, Vector2(10.0, 0.0)) == "Đông"
		and SideDelivery.dir_word(Vector2.ZERO, Vector2(-10.0, 10.0)) == "Tây Nam", "direction words")
	_check(SideDelivery.rank_for(10.0, 10.0) == "S" and SideDelivery.rank_for(12.0, 10.0) == "A" and SideDelivery.rank_for(30.0, 10.0) == "C", "delivery ranks")


func r_nitro_back() -> bool:
	var b: Node = fr.get("bike")
	return b != null and float(b.get("speed_cap")) > 1000.0


func _end() -> bool:
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	paused = false
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: SIDE ACTIVITIES (night races, takedowns, deliveries, Vovinam, records)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
