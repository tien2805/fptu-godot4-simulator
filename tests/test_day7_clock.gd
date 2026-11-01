# File: res://tests/test_day7_clock.gd
# Headless unit test of the Day 7 building blocks (plan 2026-11-01-w4-day7.md T1):
#   A  Day7Clock: the time text (05:30 .. 08:00), tick / expired / grace on a fake director, is_day7, the HUD (visible
#      only on Day 7 and when the host lets it, red under WARN_S);
#   B  the laser rules of MissionTowerLasers (static, blink with its telegraph, sweep; the height and the radius checks)
#      on LairTower's own corridor (a gap exists through every row);
#   C  LairTower: seven floors side by side, show_floor, the mission points of every Day 7 task on their floor, the
#      gallery's vases (cover), speakers and breakers, set_power, the roof helicopter / searchlight / rain;
#   D  CastD7 (Lọ's body and gear, the villain cards with plain text) and the Day 7 timelines validate.
# Run:  godot --headless --path . --script tests/test_day7_clock.gd
extends SceneTree

var fails: Array[String] = []


class FakeDir extends Node:
	var flags: Dictionary = {}
	var active: bool = true
	var day: int = 7
	var ending: String = ""


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


var _ran: bool = false


func _initialize() -> void:
	print("--- TEST DAY 7 CLOCK, TOWER, LASERS, CAST ---")


## The parts run on the first frame (the root is in the tree then: global transforms, _ready).
func _process(_d: float) -> bool:
	if _ran:
		return false
	_ran = true
	_part_a()
	_part_b()
	_part_c()
	_part_d()
	if fails.is_empty():
		print("✅ SUCCESS: DAY 7 CLOCK, TOWER, LASERS, CAST")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return false


func _part_a() -> void:
	print("  [part] A Day7Clock")
	_check(Day7Clock.clock_text(Day7Clock.START_S) == "05:30" and Day7Clock.clock_text(0.0) == "08:00", "05:30 at the start, 08:00 at 0")
	_check(Day7Clock.clock_text(Day7Clock.START_S - Day7Clock.SECS_PER_MIN * 30.0) == "06:00", "SECS_PER_MIN real seconds per game minute")
	_check(Day7Clock.clock_text(5.0) == "07:59", "the last minute shows 07:59")
	var d := FakeDir.new()
	root.add_child(d)
	_check(is_equal_approx(Day7Clock.remaining(d), Day7Clock.START_S) and is_equal_approx(Day7Clock.remaining(null), Day7Clock.START_S), "a fresh Day 7: START_S left")
	_check(not Day7Clock.tick(d, 100.0) and is_equal_approx(Day7Clock.remaining(d), Day7Clock.START_S - 100.0), "tick counts down in the director's flags")
	_check(not Day7Clock.tick(d, 0.0) and not Day7Clock.tick(d, -3.0) and is_equal_approx(Day7Clock.remaining(d), Day7Clock.START_S - 100.0), "no tick for dt <= 0")
	Day7Clock.set_remaining(d, 2.0)
	_check(Day7Clock.tick(d, 3.0) and Day7Clock.expired(d) and is_equal_approx(Day7Clock.remaining(d), 0.0), "08:00: tick reports it once")
	_check(not Day7Clock.tick(d, 1.0), "past 08:00 no second report")
	_check(Day7Clock.grace(d) and is_equal_approx(Day7Clock.remaining(d), Day7Clock.GRACE_S) and not Day7Clock.expired(d), "grace: GRACE_S back")
	_check(not Day7Clock.grace(d), "grace only tops up below GRACE_S")
	_check(Day7Clock.is_day7(d), "Day 7 of a running story")
	d.day = 6
	_check(not Day7Clock.is_day7(d), "not on Day 6")
	d.day = 7
	d.ending = "A"
	_check(not Day7Clock.is_day7(d) and not Day7Clock.is_day7(null), "not after the ending, not without a story")
	d.ending = ""
	# the HUD
	var host := Node.new()
	root.add_child(host)
	var show_it: Array = [true]
	var c: Day7Clock = Day7Clock.attach(host, d, func() -> bool: return bool(show_it[0]))
	Day7Clock.set_remaining(d, 900.0)
	c.refresh()
	_check(c.visible and c.time_label.text == Day7Clock.clock_text(900.0) and c.sub_label.text == Day7Clock.T_SUB, "the HUD shows the time on Day 7")
	_check(c.time_label.get_theme_color("font_color").is_equal_approx(Day7Clock.GOLD), "gold above WARN_S")
	show_it[0] = false
	c.refresh()
	_check(not c.visible, "hidden when the host says so (a cinematic)")
	show_it[0] = true
	Day7Clock.set_remaining(d, Day7Clock.WARN_S - 1.0)
	c.refresh()
	var col: Color = c.time_label.get_theme_color("font_color")
	_check(c.visible and col.r > 0.9 and col.g < 0.75, "red under WARN_S (%s)" % str(col))
	d.day = 5
	c.refresh()
	_check(not c.visible, "hidden on other days")
	for t: String in [Day7Clock.T_LATE, Day7Clock.T_SUB, Day7Clock.T_GRACE, Day7Clock.T_TITLE]:
		_check(not t.contains("…"), "plain text: %s" % t)
	host.queue_free()
	d.queue_free()


func _part_b() -> void:
	print("  [part] B lasers")
	var st := {"a": Vector3(-3.0, 0.0, 10.0), "b": Vector3(0.7, 0.0, 10.0), "y0": 0.45, "y1": 0.45, "mode": "static"}
	_check(MissionTowerLasers.beam_state(st, 0.0) == "on" and MissionTowerLasers.beam_state(st, 99.0) == "on", "a static beam is always lit")
	_check(MissionTowerLasers.beam_hits(st, 0.0, Vector3(-1.0, 0.0, 10.1)), "standing in it: hit")
	_check(not MissionTowerLasers.beam_hits(st, 0.0, Vector3(1.6, 0.0, 10.0)), "past its end (the gap): no hit")
	_check(not MissionTowerLasers.beam_hits(st, 0.0, Vector3(-1.0, 0.0, 10.5)), "0.5 m beside it: no hit")
	var hi := st.duplicate()
	hi["y0"] = 2.1
	hi["y1"] = 2.1
	_check(not MissionTowerLasers.beam_hits(hi, 0.0, Vector3(-1.0, 0.0, 10.0)), "over the head: no hit")
	var bl := {"a": Vector3(-3.0, 0.0, 5.0), "b": Vector3(3.0, 0.0, 5.0), "y0": 0.8, "y1": 0.8, "mode": "blink", "period": 3.2, "on": 0.55, "phase": 0.0}
	_check(MissionTowerLasers.beam_state(bl, 0.1) == "on" and MissionTowerLasers.beam_state(bl, 2.0) == "off", "blink: lit, then dark")
	_check(MissionTowerLasers.beam_state(bl, 3.2 - MissionTowerLasers.TELE_S + 0.05) == "warn", "the TELE_S telegraph before it lights")
	_check(not MissionTowerLasers.beam_hits(bl, 3.0, Vector3(0.0, 0.0, 5.0)) and MissionTowerLasers.beam_hits(bl, 3.3, Vector3(0.0, 0.0, 5.0)), "the telegraph is harmless, the lit beam is not")
	var sw := {"a": Vector3(0.0, 0.0, 0.0), "b": Vector3(0.0, 0.0, 0.0), "y0": 0.0, "y1": 3.2, "mode": "sweep", "period": 4.0, "phase": 0.0, "sweep": Vector3(2.6, 0.0, 0.0)}
	_check(MissionTowerLasers.beam_point(sw, 1.0).distance_to(Vector3(2.6, 0.0, 0.0)) < 0.01 and MissionTowerLasers.beam_point(sw, 3.0).distance_to(Vector3(-2.6, 0.0, 0.0)) < 0.01, "a sweep moves along its offset")
	_check(MissionTowerLasers.beam_hits(sw, 1.0, Vector3(2.5, 0.0, 0.05)) and not MissionTowerLasers.beam_hits(sw, 3.0, Vector3(2.5, 0.0, 0.05)), "a vertical sweep hits only where it is")
	# LairTower's corridor: at every row there is a time and a place to pass
	var lv := LairTower.new()
	root.add_child(lv)
	lv.build()
	var defs: Array = lv.laser_defs()
	_check(defs.size() >= 14, "the corridor has its beams (%d)" % defs.size())
	var zs: Dictionary = {}
	for dd: Dictionary in defs:
		zs[snappedf((dd["a"] as Vector3).z, 0.5)] = true
	var blocked_rows: int = 0
	for z: Variant in zs.keys():
		var row_ok: bool = false
		for k: int in 64:
			var t: float = float(k) * 0.1
			for x10: int in range(-27, 28, 3):
				var p: Vector3 = lv.world("gallery", Vector3(float(x10) * 0.1, 0.0, 0.0))
				p.z = float(z)
				var hit: bool = false
				for dd2: Dictionary in defs:
					if absf((dd2["a"] as Vector3).z - float(z)) < 4.0 and MissionTowerLasers.beam_hits(dd2, t, p):
						hit = true
						break
				if not hit:
					row_ok = true
					break
			if row_ok:
				break
		if not row_ok:
			blocked_rows += 1
	_check(blocked_rows == 0, "every laser row has a gap at some time (%d blocked)" % blocked_rows)
	lv.queue_free()


func _part_c() -> void:
	print("  [part] C LairTower")
	var lv := LairTower.new()
	root.add_child(lv)
	lv.build()
	_check(lv.cells.size() == LairTower.FLOORS.size() and lv.current_floor == "parking" and (lv.cells["parking"] as Node3D).visible and not (lv.cells["roof"] as Node3D).visible, "seven floors, the parking deck shown")
	var xs: Array = []
	for f: String in LairTower.FLOORS:
		xs.append((lv.cells[f] as Node3D).global_position.x)
		_check(absf((lv.cells[f] as Node3D).global_position.y) < 0.001, "%s at y 0 (side by side, never stacked)" % f)
	_check(xs == [0.0, 160.0, 320.0, 480.0, 640.0, 800.0, 960.0], "CELL_X apart along +X")
	for task: String in ["parking", "warehouse", "servers", "mannequins", "lasers", "boss_guns", "boss_dark", "boss_saber", "typing"]:
		var f2: String = LairTower.floor_of(task)
		var pts: Dictionary = lv.mission_points(task)
		var spot: Vector3 = pts.get("start", pts.get("spot", Vector3(-999.0, 0.0, 0.0)))
		var cx: float = (lv.cells[f2] as Node3D).global_position.x
		_check(absf(spot.x - cx) < 40.0 and String(pts["floor"]) == f2, "%s starts on its floor %s" % [task, f2])
	var pk: Dictionary = lv.mission_points("parking")
	var rt: PackedVector2Array = pk["route"]
	_check(rt.size() == 36 * 16 + 1 and absf(Vector2(rt[0].x - 0.0, rt[0].y).length() - LairTower.RING_R) < 0.01, "the ring route: 16 laps round the core (R %.0f)" % LairTower.RING_R)
	var br: BikeRoute = BikeRoute.from_points(rt)
	_check(br.valid() and br.length > 2000.0, "the ring is a valid BikeRoute (%.0f m)" % br.length)
	lv.show_floor("gallery")
	_check(lv.current_floor == "gallery" and lv.cover_root == lv.cells["gallery"] and (lv.cells["gallery"] as Node3D).visible and not (lv.cells["parking"] as Node3D).visible, "show_floor: one cell, cover_root follows")
	_check(lv.vases.size() == 12 and (lv.vases[0]["plinth"] as Node).is_in_group("cover"), "twelve vases on plinths (cover)")
	_check(lv.speakers.size() == 8 and lv.breakers.size() == 2 and lv.gallery_lights.size() == 4, "speakers, breakers, the gold lights")
	lv.set_power(false)
	_check(not lv.power_on and not lv.gallery_lights[0].visible, "set_power(false): the lights die")
	lv.set_power(true)
	lv.show_floor("roof")
	_check(lv.heli != null and lv.heli_light != null and lv.heli_light.shadow_enabled and lv.rain.size() == 2 and lv.rain[0].emitting, "the roof: helicopter, searchlight, rain on")
	var y0: float = lv.heli_light.global_transform.basis.z.x
	for i: int in 30:
		lv.tick(0.1)
	_check(absf(lv.heli_light.global_transform.basis.z.x - y0) > 0.01 and lv.heli_rotor.rotation.y != 0.0, "tick: the searchlight sweeps, the rotor turns")
	lv.show_floor("parking")
	_check(not lv.rain[0].emitting, "the rain stops off the roof")
	_check(lv.cine_xf("cine_d7_monologue").origin.is_equal_approx((lv.cells["gallery"] as Node3D).global_position), "the monologue is staged in the gallery")
	lv.queue_free()


func _part_d() -> void:
	print("  [part] D cast and timelines")
	var body: Node3D = CastD7.build("van_lo")
	_check(body != null and String(body.get_meta("cast_id", "")) == "van_lo" and (body.get_meta("gear", []) as Array).size() == 3, "Lọ: a rigged body with his three pieces of gear")
	if body:
		body.free()
	for id: String in ["van_lo", "soi_xam_back", "alexander_back", "za_man_back"]:
		var d: Dictionary = CastD7.villain_data(id)
		_check(not d.is_empty() and CastD7.card_len(id) >= 3.0 and CastD7.card_len(id) <= 4.0, "villain card %s" % id)
		for k: String in ["name", "nick", "joke"]:
			_check(not String(d.get(k, "")).contains("…"), "%s %s: plain text" % [id, k])
	_check(StoryRadio.prefix("van_lo") == "LÙM VĂN LỌ (loa)" and StoryRadio.prefix("anh_duy") == "ANH DUY (bộ đàm)", "radio prefixes")
	for bid: String in ["d7_parking", "d7_boss2", "d7_typing"]:
		_check(not StoryRadio.lines(bid).is_empty(), "radio chatter for %s" % bid)
	for slot: String in ["cine_d7_intro", "cine_d7_monologue"]:
		var tl: CineTimeline = CineTimeline.load_slot(slot)
		_check(tl != null, "%s loads" % slot)
		if tl:
			var errs: PackedStringArray = tl.validate()
			_check(errs.is_empty(), "%s validates: %s" % [slot, "; ".join(errs)])
	for k2: String in CinePropsD7.KINDS:
		_check(CineFX.PROP_KINDS.has(k2), "prop kind %s registered" % k2)
	_check(MusicDirector.SLOTS.has("mission_tower") and MusicDirector.SLOTS.has("boss_d7") and MusicDirector.REPLAY_SLOTS.has("seg_d7_floors") and MusicDirector.REPLAY_SLOTS.has("seg_d7_phase1"), "the Day 7 music slots")
	for v: Variant in StoryTower.LAIR_MUSIC.values():
		_check(String(v) == "" or MusicDirector.SLOTS.has(String(v)), "tower music %s is a slot" % String(v))
	_check(LookPresets.has("penthouse") and LookPresets.has("penthouse_blackout") and LookPresets.has("rooftop_rain"), "the Day 7 looks")
