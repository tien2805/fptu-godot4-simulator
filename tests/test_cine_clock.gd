# File: res://tests/test_cine_clock.gd
# Headless test of CineClock (analytic slow-motion ramps) and its validator: closed-form spans, monotonic story time,
# real <-> story round trips, freezes, the seg_d1_brawl ramp set landing on exactly 25.000 s, validator failures, impacts
# placed by real time ("r") within 0.5 ms and unreachable real targets reported.
# Run:  godot --headless --path . --script tests/test_cine_clock.gd
extends SceneTree

var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _d1_clock() -> CineClock:
	var c := CineClock.new()
	c.length = 25.0
	c.story_end = 16.49325
	c.add("H1", 2.40, "heavy")
	c.add("A1", 3.70, "accent")
	c.add("H2", 4.25, "light")
	c.add("H3", 4.70, "light")
	c.add("H4", 5.30, "medium")
	c.add("A2", 6.60, "accent")
	c.add("H5", 7.60, "heavy")
	c.add("H6", 8.40, "medium")
	c.add("A3", 10.30, "accent")
	c.add("H7", 11.40, "medium")
	c.add("H8", 12.525, "finisher")
	return c


func _initialize() -> void:
	print("--- TEST CINE CLOCK ---")
	# 1. one heavy ramp: exact spans
	var c := CineClock.new()
	c.length = 10.0
	c.add("X", 5.0, "heavy")
	c.build()
	var p: Dictionary = c.ramp("X")
	_check(is_equal_approx(float(p["s0"]), 5.0 - 0.16875), "heavy pre span 0.16875 (got %.5f)" % (5.0 - float(p["s0"])))
	_check(is_equal_approx(float(p["s1"]), 5.0 + 0.3875), "heavy post span 0.3875")
	_check(absf(float(p["r_hit"]) - (float(p["r0"]) + 0.45)) < 1e-9, "impact = ramp start + ri + hp")
	_check(absf(c.real_at(5.0) - float(p["r_hit"])) < 1e-6, "real_at(impact) = freeze start")
	_check(absf(c.story_at(float(p["r_hit"]) + 0.09) - 5.0) < 1e-9, "story frozen inside the freeze")
	_check(c.speed_at(float(p["r_hit"]) + 0.09) == 0.0, "speed 0 in the freeze")
	_check(absf(c.speed_at(float(p["r_hit"]) + 0.5) - 0.25) < 1e-9, "speed k in the post hold")
	_check(absf(c.speed_at(1.0) - 1.0) < 1e-9, "speed 1 before the ramp")
	# extra real time of a heavy ramp = 1.17375 s -> story 8.82625 lasts 10 s
	c.story_end = 10.0 - 1.17375
	_check(absf(c.real_duration() - 10.0) < 1e-6, "real duration = story_end + extra (got %.6f)" % c.real_duration())
	# 2. monotonic story time + round trip over the d1 ramp set
	var d1: CineClock = _d1_clock()
	var errs: PackedStringArray = d1.validate()
	_check(errs.is_empty(), "d1 ramp set valid: %s" % str(errs))
	_check(absf(d1.real_duration() - 25.0) < 0.0005, "d1 real duration 25.000 (got %.5f)" % d1.real_duration())
	_check(absf(d1.story_at(25.0) - 16.49325) < 0.0005, "story_at(25) = story_end")
	var prev: float = -1.0
	var mono: bool = true
	var trip: float = 0.0
	var r: float = 0.0
	while r <= 25.0:
		var s: float = d1.story_at(r)
		if s < prev - 1e-9:
			mono = false
		prev = s
		if d1.speed_at(r) > 0.0:
			trip = maxf(trip, absf(d1.real_at(s) - r))
		r += 1.0 / 240.0
	_check(mono, "story time never decreases")
	_check(trip < 1e-4, "real_at(story_at(r)) == r outside freezes (max err %.6f)" % trip)
	var expect: Dictionary = {"H1": 2.68125, "A1": 5.09125, "H4": 7.975, "H6": 13.548, "A3": 16.2315, "H8": 19.950}
	for nm: String in expect.keys():
		_check(absf(float(d1.ramp(nm)["r_hit"]) - float(expect[nm])) < 0.002, "%s real impact %.3f (got %.4f)" % [nm, float(expect[nm]), float(d1.ramp(nm)["r_hit"])])
	_check(absf(float(d1.ramp("H8")["r1"]) - 21.5005) < 0.002, "last ramp ends at 21.500 -> 3.5 s tail")
	# integrate speed numerically: must match story_at (catches a wrong closed form)
	var acc: float = 0.0
	var dt: float = 1.0 / 2000.0
	var t: float = 0.0
	while t < 25.0:
		acc += d1.speed_at(t + dt * 0.5) * dt
		t += dt
	_check(absf(acc - d1.story_at(25.0)) < 0.002, "∫speed dr = story_at (%.5f vs %.5f)" % [acc, d1.story_at(25.0)])
	# 3. validator failures
	var bad := _d1_clock()
	bad.story_end = 16.0
	var e1: PackedStringArray = bad.validate()
	_check(e1.size() >= 1 and String(e1[0]).contains("set story_end to 16.49325"), "wrong length reports the fix: %s" % str(e1))
	var ov := _d1_clock()
	ov.add("X", 4.40, "light")   # overlaps H2/H3
	_check(not ov.validate().is_empty(), "overlapping ramps rejected")
	var slow := CineClock.new()
	slow.length = 6.0
	slow.add("Z", 1.0, "heavy", {"k": 0.1})
	slow.story_end = 6.0 - 1.17375
	_check(str(slow.validate()).contains("outside 0.25-0.40"), "k = 0.1 rejected")
	var tail := CineClock.new()
	tail.length = 6.0
	tail.add("T", 3.5, "light")
	tail.story_end = 6.0 - 0.385
	_check(str(tail.validate()).contains("tail"), "tail shorter than 3 s rejected")
	# 4. base speed 0.5 (replays): duration formula
	var rp := CineClock.new()
	rp.base = 0.5
	rp.tail_rule = false
	rp.length = 5.0
	rp.add("F", 1.0, "heavy")
	rp.build()
	var q: Dictionary = rp.ramp("F")
	var story_spans: float = float(q["s1"]) - float(q["s0"])
	rp.story_end = 1.0 + 0.3875 + 0.4   # anything after the ramp
	var want: float = (rp.story_end - story_spans) / 0.5 + 1.73
	_check(absf(rp.real_duration() - want) < 1e-5, "base 0.5 real duration (%.5f vs %.5f)" % [rp.real_duration(), want])
	# 5. impacts placed by REAL time ("r" override: the story time follows from the constant base speed between ramps)
	var rt := CineClock.new()
	rt.length = 14.0
	rt.tail_rule = false
	rt.add("R1", 0.0, "heavy", {"r": 1.45})
	rt.add("R2", 0.0, "medium", {"r": 6.15})
	rt.add("R3", 0.0, "light", {"r": 7.72})
	rt.build()
	for want_r: Array in [["R1", 1.45], ["R2", 6.15], ["R3", 7.72]]:
		var got_r: float = float(rt.ramp(want_r[0])["r_hit"])
		_check(absf(got_r - float(want_r[1])) < 0.0005, "%s impact at real %.3f (got %.5f)" % [want_r[0], want_r[1], got_r])
		_check(absf(rt.real_at(float(rt.ramp(want_r[0])["s"])) - float(want_r[1])) < 0.0005, "%s story time maps back to real %.3f" % [want_r[0], want_r[1]])
	rt.story_end = float(rt.ramp("R3")["s1"]) + 1.0
	rt.length = rt.real_duration()
	_check(rt.validate().is_empty(), "real-placed ramps valid: %s" % str(rt.validate()))
	var rb := CineClock.new()
	rb.length = 5.0
	rb.base = 0.5
	rb.tail_rule = false
	rb.add("B1", 0.0, "heavy", {"r": 2.75})
	_check(absf(float(rb.ramp("B1")["r_hit"]) - 2.75) < 0.0005, "real placement at base 0.5 (got %.5f)" % float(rb.ramp("B1")["r_hit"]))
	var un := CineClock.new()
	un.length = 10.0
	un.tail_rule = false
	un.add("U1", 1.0, "heavy", {"r": 2.0})
	un.add("U2", 2.0, "heavy", {"r": 2.5})   # U1 ends at real 3.28: unreachable
	un.story_end = 6.0
	_check(str(un.validate()).contains("U2: impact at real 2.500 would need a gap < 0"), "unreachable real impact reported: %s" % str(un.validate()))
	var un0 := CineClock.new()
	un0.length = 10.0
	un0.tail_rule = false
	un0.add("Z0", 1.0, "heavy", {"r": 0.2})   # needs ri + hp = 0.45 s before it
	un0.story_end = 6.0
	_check(str(un0.validate()).contains("Z0: impact at real 0.200 would need a gap < 0"), "first ramp too early reported: %s" % str(un0.validate()))
	if fails.is_empty():
		print("✅ SUCCESS: CINE CLOCK (analytic ramps, round trips, d1 = 25.000 s, validator)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
