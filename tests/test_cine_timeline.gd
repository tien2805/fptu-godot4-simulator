# File: res://tests/test_cine_timeline.gd
# Headless test of CineTimeline: the test timeline validates, its beat sheet has the exact real times, and the validator
# catches a wrong story_end, a missing strike, an unknown move, an untranslated Anh Duy line, a shot not starting at 0 and a
# cue after the story end, and an fx placed on a missing actor. Slot registry tolerates missing slots.
# Independent of user://music (the owner's local music files never change these results).
# Run:  godot --headless --path . --script tests/test_cine_timeline.gd
extends SceneTree

const TL_SCRIPT: String = "res://tests/support/cine_test_timeline.gd"
var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _tl() -> CineTimeline:
	var tl: CineTimeline = (load(TL_SCRIPT) as GDScript).new()
	tl.build()
	return tl


func _initialize() -> void:
	print("--- TEST CINE TIMELINE ---")
	var tl: CineTimeline = _tl()
	var errs: PackedStringArray = tl.validate()
	_check(errs.is_empty(), "test timeline valid: %s" % str(errs))
	var sheet: String = tl.beat_sheet()
	_check(sheet == _tl().beat_sheet(), "beat sheet is deterministic")
	_check(sheet.contains("Real length: 6.000 s"), "header has the real length")
	_check(sheet.contains("tail 3.810 s"), "header has the tail (3.810 s)")
	var h1_row: String = ""
	for line: String in sheet.split("\n"):
		if line.begins_with("H1 "):
			h1_row = line
	_check(h1_row.contains("1.690") and h1_row.contains("1.790"), "H1 real impact 1.690, freeze end 1.790: '%s'" % h1_row)
	_check(sheet.contains("SHOT S2") and sheet.contains("1.400"), "shot S2 at real 1.400")
	_check(sheet.contains("Dịch: Anh ổn"), "subtitle translation line listed")
	_check(is_equal_approx(CineTimeline.face(Vector3.ZERO, Vector3(1.0, 0.0, 0.0)), -90.0), "face(+X) = -90° (characters face -Z)")
	# validator failures
	var a: CineTimeline = _tl()
	a.story_end = 5.0
	_check(str(a.validate()).contains("set story_end to 5.61500"), "wrong story_end reported with the fix")
	var b: CineTimeline = _tl()
	b.cues.assign(b.cues.filter(func(c: Dictionary) -> bool: return String(c["type"]) != "strike"))
	_check(str(b.validate()).contains("H1 has no strike"), "impact ramp without a strike rejected")
	var c2: CineTimeline = _tl()
	c2.move("hero", 3.0, "moonwalk")
	_check(str(c2.validate()).contains("unknown move moonwalk"), "unknown move rejected")
	var d: CineTimeline = _tl()
	d.sub(4.6, 1.0, "dummy", "Ping prod đi e.")
	_check(str(d.validate()).contains("needs a translation"), "Anh Duy line without Dịch rejected")
	var e: CineTimeline = _tl()
	e.shots[0]["s"] = 0.2
	_check(str(e.validate()).contains("first shot"), "first shot must start at 0")
	var f: CineTimeline = _tl()
	f.expr("hero", 9.0, "happy")
	_check(str(f.validate()).contains("outside the story"), "cue after story_end rejected")
	# fx `where` must name an existing actor (plan review Minor 9) or a prop / a stage-local point
	var g: CineTimeline = _tl()
	g.fx_at("H1", "dust", "ghost:Head")
	_check(str(g.validate()).contains("unknown actor ghost"), "fx on a missing actor bone rejected: %s" % str(g.validate()))
	var h: CineTimeline = _tl()
	h.fx_at("H1", "flash", "nobody")
	_check(str(h.validate()).contains("unknown actor nobody"), "fx on a missing actor / prop rejected: %s" % str(h.validate()))
	var ok_fx: CineTimeline = _tl()
	ok_fx.fx_at("H1", "dust", "hero")
	ok_fx.fx_at("H1", "flash", Vector3(0.0, 1.0, 0.0))
	ok_fx.fx_at("H1", "crate", "crates")
	_check(ok_fx.validate().is_empty(), "fx on an actor, a point and a crate prop accepted: %s" % str(ok_fx.validate()))
	# registry
	_check(CineTimeline.load_slot("no_such_slot") == null, "load_slot of a missing slot returns null")
	_check(CineTimeline.slots() is PackedStringArray, "slots() lists the timelines folder")
	if fails.is_empty():
		print("✅ SUCCESS: CINE TIMELINE (validator, beat sheet, registry)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
