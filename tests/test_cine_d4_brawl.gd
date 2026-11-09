# File: res://tests/test_cine_d4_brawl.gd
# Headless test of seg_d4_brawl (spec B-D7 / B-D10, reworked by plan 2026-11-05-w6-fights) on tests/support/cine_brawl.gd:
# exactly 22.350 s, the ramps on the music's accents, the 4.5 s finisher swell and its 3 s tail, the hits taken at normal
# speed with punch-ins, contacts on every tier (the food tray into C1, C2's jab and cross onto the raised tray, the tray
# edge into C2, the bench into C2 and C3, Dolly's right, her frisbee onto his tray and batted back onto her own mask, the
# hip throw), C2 and C3 against the counter, C1 into the chairs, bodies, framing, FreeRoam staging for every Phase B slot
# and the skip. Gags: lunch in C1's mask eye holes, every clone and Dolly keep their sheep masks, he picks his own tray
# back up for the bat, C1 slides the lunch tables (on the table tops, along the row) and ends in the burst chairs; Dolly
# is gone by the tail; drop_set keeps the fight's furniture.
# Run:  godot --headless --path . --script tests/test_cine_d4_brawl.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_brawl.gd"

const PHASE_B: Array[String] = ["cine_d1_intro", "cine_d1_corridor", "cine_d1_choice", "cine_d1_choice_cover", "cine_d1_choice_report",
	"cine_d1", "cine_d4_intro", "cine_d4_stare", "seg_d4_brawl", "cine_d4"]


func _conf() -> Dictionary:
	return {"slot": "seg_d4_brawl", "length": 22.35, "finisher": "H5", "swell_end": 19.35, "tail": 3.0, "freezes": 4,
		"ramps": {"H1": 2.44, "H2": 6.21, "H3": 9.39, "A1": 13.01, "H5": 14.85},
		"taken": {"X1": 3.80, "X2": 5.24, "X4": 11.51},
		"touch": {"H3B": 9.39, "TF": 13.49},
		"strikes": {"H1": ["hero", "held:Tray", "c1"], "X1": ["c2", "fists", "hero:held:Tray"], "X2": ["c2", "fists", "hero:held:Tray"],
			"H2": ["hero", "held:Tray", "c2"], "H3": ["hero", "held:Bench", "c3"], "H3B": ["hero", "held:Bench", "c2"],
			"X4": ["dolly", "fists", "hero"], "A1": ["dolly", "prop:tray_fly", "hero:held:Tray"], "TF": ["hero", "prop:tray_fly", "dolly"],
			"H5": ["hero", "fists", "c1"]},
		"slams": [["c2", ["counter"], 9.39, 10.4], ["c3", ["counter"], 9.39, 10.4], ["c1", ["chairs_a", "chairs_b"], 16.85, 17.12]],
		"lying": [["c2", 12.5], ["c3", 12.5], ["c2", 22.0], ["c3", 22.0], ["c1", 22.1]],
		"crash": ["sc", "chairs_a"],
		"hit_vars": ["slam_s", "sc", "tf", "s_bench", "s_tray"],
		"burst": {"chairs_a": "sc", "chairs_b": "sc"},
		"not_solid": ["lunch_0", "lunch_1", "tray_fly", "tray_drop", "tray_toss", "tray_c", "pot"],
		"held": [["hero", "Tray", 2.3, true], ["hero", "Tray", 4.4, true], ["hero", "Tray", 6.21, true], ["hero", "Tray", 7.4, false],
			["hero", "Bench", 9.39, true], ["hero", "Bench", 10.6, false], ["hero", "Tray", 10.9, false], ["hero", "Tray", 11.3, true],
			["hero", "Tray", 13.01, true], ["hero", "Tray", 14.2, false], ["dolly", "Tray", 11.0, true], ["dolly", "Tray", 12.9, false],
			["c1", "FoodEyes", 2.3, false], ["c1", "FoodEyes", 3.0, true], ["c1", "FoodEyes", 22.0, true]],
		"shown": [["bench", 7.0, true], ["bench", 8.5, false], ["tray_c", 9.0, true], ["tray_c", 10.8, false], ["tray_drop", 8.0, true],
			["tray_drop", 11.3, false], ["tray_fly", 13.0, true], ["tray_toss", 14.2, true], ["chairs_a", 16.8, true]],
		"gone": [["dolly", 19.3, true], ["dolly", 19.45, false], ["dolly", 22.2, false]],
		"keep": ["counter", "table_0", "table_1", "table_2", "chairs_a", "chairs_b"],
		"stages": PHASE_B, "checks": _gags}


func _gags(_t: Object, pl: CinePlayer) -> void:
	# the sheep masks stay on all four
	for e: Array in [["c1", 2.3], ["c1", 22.0], ["c2", 6.21], ["c3", 9.39], ["dolly", 11.51], ["dolly", 13.6], ["dolly", 1.0]]:
		pl.seek(float(e[1]))
		_check(_held(pl.actors[String(e[0])], "SheepMask") != null, "%s wears the sheep mask at r %.1f" % [String(e[0]), float(e[1])])
	# lunch in C1's eye holes, the slide runs on the table tops along the row, the trays fly as he passes
	var c1: CineActor = pl.actors["c1"]
	pl.seek(4.0)
	var fe: Dictionary = _hold_of(c1, "FoodEyes")
	var mk: Dictionary = _hold_of(c1, "SheepMask")
	if not fe.is_empty() and not mk.is_empty():
		var d: float = _held_xf(c1, fe).origin.distance_to(_held_xf(c1, mk).origin)
		_check(d < 0.01, "the food sits on C1's mask eye holes (%.3f m off the mask frame)" % d)
	# the tray he picks back up lies under his hand at the pickup
	var hero: CineActor = pl.actors["hero"]
	pl.seek(11.09)
	var td: Vector3 = (pl.prop_nodes["tray_drop"] as Node3D).global_position
	var wr: Vector3 = hero.bone_world("Wrist.R")
	print("  pickup: tray (%.2f, %.2f, %.2f), right wrist (%.2f, %.2f, %.2f)" % [td.x, td.y, td.z, wr.x, wr.y, wr.z])
	_check(Vector2(td.x - wr.x, td.z - wr.z).length() < 0.2 and wr.y < 0.4, "he picks his tray up off the floor (wrist %.2f m off it)" % Vector2(td.x - wr.x, td.z - wr.z).length())
	var land: Vector3 = tl.get("LAND")
	var end: Vector3 = tl.get("SLIDE_END")
	for r: float in [16.2, 16.5, 16.75]:
		pl.seek(r)
		var hp: Vector3 = c1.bone_world("Hips")
		print("  slide r %.2f: C1 hips (%.2f, %.2f, %.2f)" % [r, hp.x, hp.y, hp.z])
		_check(hp.y > 0.72 and hp.y < 1.15 and absf(hp.z - land.z) < 0.35 and hp.x < land.x + 0.4 and hp.x > end.x - 0.4,
			"C1 slides along the lunch tables at r %.2f (hips %s)" % [r, str(hp)])
	for j: int in 2:
		var lt: Node3D = pl.prop_nodes["lunch_%d" % j]
		pl.seek(15.5)
		var before: Vector3 = lt.position
		pl.seek(19.0)
		_check(lt.position.distance_to(before) > 0.5 and lt.position.y < 0.1, "lunch tray %d is knocked off the table" % j)
	_check(tl.fx.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "crate").size() == 2, "both stacked chairs burst")
	_check(String((tl.actors["dolly"]["opts"] as Dictionary).get("shirt_color", Color.BLACK).to_html(false)) == StoryCast.CREAM.to_html(false), "Dolly wears the cream cardigan")
	# one signature each: the tray shield (code move on every tier), the bench ram, the bat back
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "hero" and String(c.get("move", "")) == "tray_guard"), "the tray shield")
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["type"] == "hold" and c["actor"] == "hero" and String(c["kind"]) == "bench"), "the bench ram")
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["type"] == "strike" and c["actor"] == "hero" and String(c["move"]) == "shove_high"), "the bat back")
	_check(not tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "hero" and String(c.get("move", "")) == "dodge"), "no duck under the frisbee")
