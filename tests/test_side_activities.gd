# File: res://tests/test_side_activities.gd
# Headless test of the free-roam side activities (plan 2026-11-01-w4-endings.md T5):
#   A. data: the three night race routes build on the Day 2 roads (length, par, distinct start spots), the rank and drift
#      bonus rules, SideRecords (best per activity: rank first, then time; the run count; the S count), plain texts;
#   B. races in real story free roam at night (Day 5, d5_bed): the start rings only at night, the hint near a start, [E]
#      starts the race (story busy, on the bike at the grid, countdown with the bike held), a driven run along the path
#      (gates, drift seconds, off the road -> back to the last gate), the finish recorded in the unlock file and the story
#      free again; leaving the bike gives the race up. Perf: the race tick and the activity check stay far under 3 ms.
#   w5-side T1: the races have 2-3 rivals (SideRaceRivals): on the grid ahead of the player, the place on the HUD, the
#      guide's marker on the next rival, every rival kept near the player while driven (the rubber band, the regroup after
#      a reset), the podium panel after the line, the place in the result and the place-capped rank; the rubber band and
#      the standings as data.
#   w5-side T2: the delivery routes follow the roads through every drop (DriftCourse), the run shows the RouteGuide
#      (chevrons, turn panel, radar route) and a drop ring, the HUD reads the distance along the route.
#   w5-side T3: the open start spots (within RADAR_M) and the lit lanterns reach the radar with plain labels.
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
var rival_gap_max: float = 0.0
var rival_lead_max: float = -INF
var boss_marked: int = 0


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
	# w5-side T1: rivals as data
	_check(SideRace.capped_rank("S", 1) == "S" and SideRace.capped_rank("S", 2) == "A" and SideRace.capped_rank("B", 2) == "B"
		and SideRace.capped_rank("S", 3) == "B" and SideRace.capped_rank("A", 4) == "C", "the rank is capped by the place")
	for rid2: String in SideRace.ORDER:
		var ro: Array = SideRaceRivals.roster(rid2)
		_check(ro.size() >= 2 and ro.size() <= 3, "%s has 2-3 rivals (%d)" % [rid2, ro.size()])
		for e: Dictionary in ro:
			_check(_clean(String(e["name"])) and String(e["name"]) != "", "%s rival name plain (%s)" % [rid2, String(e["name"])])
	var rv := SideRaceRivals.new()
	rv.band_far = 0.8
	rv.band_lead = 1.05
	_check(is_equal_approx(rv.band_for(2.0), 1.0) and is_equal_approx(rv.band_for(SideRaceRivals.BAND_FULL_M + 5.0), 0.8)
		and is_equal_approx(rv.band_for(-3.0), 1.05) and is_equal_approx(rv.band_for(-SideRaceRivals.CATCH_FULL_M - 5.0), SideRaceRivals.CATCH_BAND),
		"the rubber band: eases off ahead, pushes behind, catches up far behind")
	rv.free()
	for l2: String in [SideRace.T_PLACE % [2, 4], SideRace.T_PODIUM, SideRace.T_NOT_IN]:
		_check(_clean(l2), "race text plain (%s)" % l2)
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
		bike.set("current_speed_ms", v)
		var t0: int = Time.get_ticks_usec()
		r.advance(DT)
		perf_race.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if r.rivals and r.state == "racing" and r.t > 4.0:
			rival_gap_max = maxf(rival_gap_max, r.rivals.max_gap(r.s_p))
			for rr: DriftRival in r.rivals.rivals:
				rival_lead_max = maxf(rival_lead_max, rr.s - r.s_p)
			if r.guide and r.guide.boss != null and r.guide.boss_name == (r.guide.boss as DriftRival).rival_name.to_upper() \
					and r.guide.boss == r.rivals.near_rival(r.s_p):
				boss_marked += 1
	bike.set("is_drifting", false)


## w5-side T3: the open start spots and the lit lanterns on the radar, with plain labels.
func _radar_part(fr: Node) -> void:
	var sb: Array[Dictionary] = sa.blips()
	var near_lab: String = ""
	var labs: Dictionary = {}
	var sp0: Vector3 = StorySideActivities.spot("dua_cau")["at"]
	for b: Dictionary in sb:
		labs[String(b.get("label", ""))] = true
		if (b["pos"] as Vector2).distance_to(Vector2(sp0.x, sp0.z)) < 0.5:
			near_lab = String(b.get("label", ""))
		_check(_clean(String(b.get("label", ""))) and String(b.get("label", "")) != "", "radar label plain (%s)" % String(b.get("label", "")))
	_check(near_lab == "Đua" and sb.size() >= 1 and sb.size() <= sa.markers.size(), "the race start on the radar, labelled (%s, %d blips)" % [near_lab, sb.size()])
	var pl: Vector3 = (fr.get("player") as Node3D).global_position
	var far_ok: bool = true
	for b2: Dictionary in sb:
		far_ok = far_ok and (b2["pos"] as Vector2).distance_to(Vector2(pl.x, pl.z)) <= StorySideActivities.RADAR_M + 5.0
	_check(far_ok, "only the starts within %d m" % int(StorySideActivities.RADAR_M))
	var ns: StoryNightSecrets = sr.night_secrets
	ns._marker("canal", pl + Vector3(20.0, 0.0, 0.0))
	var lb: Array[Dictionary] = ns.blips()
	_check(lb.size() == 1 and String(lb[0]["label"]) == StoryNightSecrets.RADAR_LABEL and (lb[0]["pos"] as Vector2).distance_to(Vector2(pl.x + 20.0, pl.z)) < 0.1,
		"a lit lantern on the radar (%s)" % str(lb))
	var all: Array[Dictionary] = sr.blips()
	var n_lab: int = 0
	for b3: Dictionary in all:
		if String(b3.get("label", "")) != "":
			n_lab += 1
	_check(n_lab == sb.size() + 1, "StoryRoam.blips carries the starts and the lantern (%d)" % n_lab)
	var vh: Variant = fr.get("vice_hud")
	if vh != null and is_instance_valid(vh) and (vh as Node).get("radar") != null:
		var rad: ViceRadar = (vh as Node).get("radar")
		fr.call("_update_vice_hud", true)
		var on_r: int = 0
		for b4: Dictionary in rad.blips:
			if String(b4.get("label", "")) != "":
				on_r += 1
		_check(on_r == n_lab, "the radar gets the labelled blips (%d)" % on_r)
		print("  radar: %d start spots within %d m (%s) + 1 lantern, %d labelled blips on the radar" % [sb.size(), int(StorySideActivities.RADAR_M), ", ".join(PackedStringArray(labs.keys())), on_r])
		rad.queue_redraw()
	ns._marker("canal", null)
	_check(ns.blips().is_empty(), "the lantern gone: off the radar")
	_check(_clean(StoryNightSecrets.RADAR_LABEL), "lantern label plain")
	for k: String in StorySideActivities.RADAR_LABEL.keys():
		_check(_clean(String(StorySideActivities.RADAR_LABEL[k])), "kind label plain (%s)" % k)


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
			_radar_part(fr)
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
			var gp: Vector2 = r2.course.world(0.0, SideRaceRivals.PLAYER_GRID_D)
			_check(r2.bike.global_position.distance_to(Vector3(gp.x, r2.bike.global_position.y, gp.y)) < 1.0, "the bike sits on the grid")
			for i: int in 200:
				r2.advance(DT)
			_check(r2.state == "racing" and float(r2.bike.get("speed_cap")) > 1000.0, "GO after the countdown, the bike let go")
			var rv2: SideRaceRivals = r2.rivals
			_check(rv2 != null and rv2.rivals.size() == SideRaceRivals.roster("dua_cau").size() and r2.racers == rv2.rivals.size() + 1,
				"dua_cau: %d rivals on the grid" % (rv2.rivals.size() if rv2 else 0))
			if rv2:
				var ahead: bool = true
				for rr2: DriftRival in rv2.rivals:
					ahead = ahead and rr2.s > 0.0 and rr2.racing and rr2.calm
				_check(ahead and r2.place == r2.racers and r2.texts().has(SideRace.T_PLACE % [r2.racers, r2.racers]),
					"the rivals start ahead, the player last (%s)" % str(r2.texts()))
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
			if rv2:
				_check(rv2.max_gap(r2.s_p) <= SideRaceRivals.REGROUP_BEHIND_M + 0.5, "after the reset every rival is near again (%.1f m, %d regroups)" % [rv2.max_gap(r2.s_p), rv2.regroups])
			_check(_clean(" ".join(PackedStringArray(r2.texts()))), "race HUD plain text")
			_drive(r2, 22.0, 60.0)
			print("  rivals: farthest from the player %.1f m, most ahead %.1f m, the guide marked a rival %d ticks, contacts %d" % [rival_gap_max,
				rival_lead_max, boss_marked, rv2.contacts if rv2 else 0])
			_check(rival_gap_max < 32.0 and rival_lead_max <= SideRaceRivals.LEAD_CAP_M + 1.0, "the rivals stay near the player (%.1f m, lead %.1f m)" % [rival_gap_max, rival_lead_max])
			_check(boss_marked > 200, "the guide marks the next rival with his name (%d)" % boss_marked)
			_check(r2.state == "podium" and r2.result.has("place") and int(r2.result["of"]) == r2.racers, "over the line: the podium (%s, %s)" % [r2.state, str(r2.result)])
			var pod: String = r2.podium_label.text if r2.podium_label else ""
			_check(pod.begins_with(SideRace.T_PODIUM) and pod.split("\n").size() == r2.racers + 1 and pod.contains("Mai") and _clean(pod), "the podium lists every racer (%s)" % pod.replace("\n", " | "))
			_check(String(r2.result["rank"]) == SideRace.capped_rank(SideRace.rank_for(float(r2.result["time"]), SideRace.par(r2.course)), int(r2.result["place"])), "the rank is capped by the place")
			for i3: int in int(SideRace.PODIUM_S / DT) + 5:
				if r2.state != "podium":
					break
				r2.advance(DT)
			_check(r2.state == "done", "the race finishes after the podium (%s, s %.0f / %.0f)" % [r2.state, r2.s_p, r2.course.length])
			_next(4)
		4:
			if frames < 3:
				return false
			_check(done_ev.size() == 1 and String(done_ev[0][0]) == "dua_cau" and bool(done_ev[0][2]), "activity_done with a new best")
			var res: Dictionary = done_ev[0][1] if done_ev.size() == 1 else {}
			print("  dua_cau run: %s" % str(res))
			_check(String(res.get("rank", "")) in StoryRank.LETTERS and float(res.get("time", 0.0)) < float(res.get("raw", 0.0)) and res.has("place"), "rank, place and drift-scored time")
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
			var fin_ms: float = perf_race.pop_back() if not perf_race.is_empty() else 0.0   # the finish tick: records + toasts once
			var mx_r: float = 0.0
			var sum_r: float = 0.0
			for v: float in perf_race:
				mx_r = maxf(mx_r, v)
				sum_r += v
			var mx_c: float = 0.0
			for v2: float in perf_check:
				mx_c = maxf(mx_c, v2)
			print("  perf: race tick avg %.3f ms, max %.3f ms (%d ticks); the finish tick (record, toast, clean-up) %.3f ms; activity check max %.3f ms"
				% [sum_r / maxf(perf_race.size(), 1.0), mx_r, perf_race.size(), fin_ms, mx_c])
			_check(sum_r / maxf(perf_race.size(), 1.0) < 0.5 and mx_r < 3.0 and mx_c < 3.0, "perf under budget (3 ms)")
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
			_check(dv.beacon != null and Vector2(dv.beacon.global_position.x, dv.beacon.global_position.z).distance_to(Vector2(1932.0, -159.0)) < 0.1,
				"the drop ring on the first drop")
			_check(_clean(" ".join(PackedStringArray(dv.texts()))) and dv.texts()[0].contains("Điểm giao 1/2") and dv.texts()[0].contains("Còn ")
				and not dv.texts()[0].contains("hướng"), "delivery HUD: the distance along the route, no compass words (%s)" % str(dv.texts()))
			_check(dv.guide != null and dv.guide.active and dv.course != null and is_equal_approx(dv.guide.end_s, dv.course.length)
				and dv.guide.turns.size() >= 1, "the route guide runs (%d turns)" % (dv.guide.turns.size() if dv.guide else -1))
			var vh: Variant = fr.get("vice_hud")
			if vh != null and is_instance_valid(vh) and (vh as Node).get("radar") != null:
				_check(((vh as Node).get("radar").get("guide_route") as PackedVector2Array).size() >= 2, "the route on the radar")
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
			# hold [Backspace] QUIT_HOLD_S: quit (a short press does nothing)
			_check(sa.start("giao_com"), "giao_com starts for the quit")
			(sa.current as SideDelivery).auto_tick = false
			sa.quit_held = true
			sa.advance(StorySideActivities.QUIT_HOLD_S * 0.5)
			_check(sa.current != null, "half the quit hold: still running")
			sa.advance(StorySideActivities.QUIT_HOLD_S * 0.6)
			sa.quit_held = false
			_check(fail_ev[-1] == ["giao_com", "quit"] and sa.current == null and not bool(sr.busy), "holding [Backspace] quits the run (%s)" % str(fail_ev[-1]))
			# busted by the police mid-run: the run fails with "police" (the story missions' rule)
			_check(sa.start("td_soi"), "td_soi starts for the police check")
			(sa.current as SideTakedown).auto_tick = false
			var wd: Node = fr.get("wanted")
			_check(wd != null, "FreeRoam has the wanted director")
			if wd:
				var keep_state: String = String(wd.get("state"))
				sa.advance(StorySideActivities.CHECK_S + 0.01)
				_check(sa.current != null, "free: the takedown runs on")
				wd.set("state", "stamp")
				sa.advance(StorySideActivities.CHECK_S + 0.01)
				wd.set("state", keep_state)
				_check(fail_ev[-1] == ["td_soi", "police"] and sa.current == null and not bool(sr.busy), "busted: the takedown fails with police (%s)" % str(fail_ev[-1]))
			_check(StorySideActivities.spots() == StorySideActivities.spots() and is_same(StorySideActivities.spots(), StorySideActivities.spots()), "spots() is built once")
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
			_part_e()
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
	for did2: String in SideDelivery.ORDER:
		var c: DriftCourse = SideDelivery.route_course(did2)
		var ds: PackedFloat32Array = SideDelivery.drops_s(did2)
		var ok: bool = c != null and ds.size() == SideDelivery.drops(did2).size() and c.point(0.0).distance_to(SideDelivery.start_at(did2)) < 3.0
		var prev: float = -1.0
		for i: int in ds.size():
			var q: Vector2 = SideDelivery.drops(did2)[i]
			ok = ok and ds[i] > prev + 30.0 and c.point(ds[i]).distance_to(q) < 1.0
			prev = ds[i]
		_check(ok and absf(ds[ds.size() - 1] - c.length) < 5.0 and c.min_radius() > 2.0,
			"%s: the road route from the start through every drop in order (%.0f m, drops at %s, tightest %.1f m)" % [did2, c.length if c else 0.0, str(ds), c.min_radius() if c else 0.0])
		_check(SideDelivery.route_course(did2) == c, "%s route built once" % did2)


## T5e: the rewards by the S-rank count, the phone's Tủ đồ, the rider's look.
func _part_e() -> void:
	var n0: int = SideRewards.s_count()
	_check(SideRewards.chosen("helmet") == "xanh_fpt" and SideRewards.chosen("jacket") == "mac_dinh", "the defaults are worn first")
	SideRecords.record("dua_gp", {"rank": "S", "time": 90.0})
	SideRecords.record("dua_vong", {"rank": "S", "time": 30.0})
	var cfg := ConfigFile.new()
	cfg.load(TMP_U)
	cfg.set_value("ranks", "d1_brawl", "S")   # a story mission's best S counts too
	cfg.save(TMP_U)
	var n: int = SideRewards.s_count()
	_check(n == n0 + 3, "S count: side S ranks + story S ranks (%d -> %d)" % [n0, n])
	_check(SideRewards.unlocked_between(0, 3) == (["Mũ Cam FPT", "Mũ Đen nhám", "Áo Đỏ đô"] as Array[String]), "unlocks by count (%s)" % str(SideRewards.unlocked_between(0, 3)))
	_check(not SideRewards.choose("helmet", "vang_kim") and SideRewards.chosen("helmet") == "xanh_fpt", "a locked helmet cannot be picked")
	var ph: Node = sr.get("phone")
	_check(ph != null, "the story phone")
	if ph == null:
		return
	ph.call("set_tab", 3)
	var txt: PackedStringArray = []
	for l: Node in ph.find_children("*", "Label", true, false):
		txt.append((l as Label).text)
	for b: Node in ph.find_children("Wear_*", "Button", true, false):
		txt.append((b as Button).text)
	var all: String = " | ".join(txt)
	_check(all.contains("Hạng S đã đạt: %d" % n) and all.contains("Mũ bảo hiểm") and all.contains("Áo khoác") and _clean(all), "Tủ đồ lists the count and both lists (%s)" % all)
	_check(all.contains("??? · cần 9 hạng S") or n >= 9, "a locked item says what it needs")
	var cam: Button = ph.find_child("Wear_helmet_cam_fpt", true, false) as Button
	_check(cam != null and not cam.disabled, "Cam FPT is open")
	if cam:
		cam.pressed.emit()
	_check(SideRewards.chosen("helmet") == "cam_fpt", "a tap wears Cam FPT")
	var red: Button = ph.find_child("Wear_jacket_do_do", true, false) as Button
	if red:
		red.pressed.emit()
	var ro: Dictionary = {"helmet_color": Color("#0066CC")}
	SideRewards.apply_rider(ro)
	_check(ro["helmet_color"] == Color("#F37021") and ro.get("shirt_color") == Color("#7A1F2B"), "the rider wears them (%s)" % str(ro))
	ph.call("set_tab", 0)


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
		print("✅ SUCCESS: SIDE ACTIVITIES (night races, takedowns, deliveries, Vovinam, records, rewards)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
