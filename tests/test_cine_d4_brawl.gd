# File: res://tests/test_cine_d4_brawl.gd
# Headless test of seg_d4_brawl (spec B-D7 / B-D10, reworked by plan 2026-11-05-w6-fights) on tests/support/cine_brawl.gd:
# exactly 24.600 s, the ramps on the music's accents, the 4.5 s finisher swell and its 3 s tail, the hits taken at normal
# speed with punch-ins, contacts on every tier (the food tray into C1, C2's three punches onto the raised tray, the tray
# edge into C2, the bench into C2 and C3, Dolly's right, her frisbee off C1's mask, the hip throw), C2 and C3 against the
# counter, C1 into the chairs, bodies, framing, FreeRoam staging for every Phase B slot and the skip. Gags: the rice bowl
# stays on C1's mask, every clone and Dolly keep their sheep masks, C1 slides the lunch tables (on the table tops, along
# the row) and ends in the burst chairs; Dolly is gone by the tail; drop_set keeps the fight's furniture.
# Run:  godot --headless --path . --script tests/test_cine_d4_brawl.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_brawl.gd"

const PHASE_B: Array[String] = ["cine_d1_intro", "cine_d1_corridor", "cine_d1_choice", "cine_d1_choice_cover", "cine_d1_choice_report",
	"cine_d1", "cine_d4_intro", "cine_d4_stare", "seg_d4_brawl", "cine_d4"]


func _conf() -> Dictionary:
	return {"slot": "seg_d4_brawl", "length": 24.6, "finisher": "H5", "swell_end": 21.6, "tail": 3.0, "freezes": 4,
		"ramps": {"H1": 2.44, "H2": 6.21, "H3": 9.39, "A1": 13.01, "H5": 17.10},
		"taken": {"X1": 3.80, "X2": 4.43, "X3": 4.89, "X4": 11.51},
		"touch": {"H3B": 9.39, "TF": 13.49},
		"strikes": {"H1": ["hero", "held:Tray", "c1"], "X1": ["c2", "fists", "hero:held:Tray"], "X2": ["c2", "fists", "hero:held:Tray"],
			"X3": ["c2", "fists", "hero:held:Tray"], "H2": ["hero", "held:Tray", "c2"], "H3": ["hero", "held:Bench", "c3"],
			"H3B": ["hero", "held:Bench", "c2"], "X4": ["dolly", "fists", "hero"], "TF": ["dolly", "prop:tray_fly", "c1"],
			"H5": ["hero", "fists", "c1"]},
		"slams": [["c2", ["counter"], 9.39, 10.4], ["c3", ["counter"], 9.39, 10.4], ["c1", ["chairs_a", "chairs_b"], 20.0, 20.32]],
		"lying": [["c2", 12.5], ["c3", 12.5], ["c2", 24.2], ["c3", 24.2], ["c1", 24.3]],
		"crash": ["sc", "chairs_a"],
		"hit_vars": ["slam_s", "sc", "tf", "s_bench", "s_tray"],
		"burst": {"chairs_a": "sc", "chairs_b": "sc"},
		"not_solid": ["lunch_0", "lunch_1", "tray_fly", "tray_drop", "tray_c", "pot"],
		"held": [["hero", "Tray", 2.3, true], ["hero", "Tray", 4.4, true], ["hero", "Tray", 6.21, true], ["hero", "Tray", 7.4, false],
			["hero", "Bench", 9.39, true], ["hero", "Bench", 10.6, false], ["dolly", "Tray", 11.0, true], ["dolly", "Tray", 12.9, false],
			["c1", "RiceBowl", 2.3, false], ["c1", "RiceBowl", 3.0, true], ["c1", "RiceBowl", 24.0, true]],
		"shown": [["bench", 7.0, true], ["bench", 8.5, false], ["tray_c", 9.0, true], ["tray_c", 10.8, false], ["tray_fly", 13.0, true],
			["chairs_a", 20.0, true]],
		"gone": [["dolly", 21.55, true], ["dolly", 21.7, false], ["dolly", 24.4, false]],
		"keep": ["counter", "table_0", "table_1", "table_2", "chairs_a", "chairs_b"],
		"stages": PHASE_B, "checks": _gags}


func _gags(_t: Object, pl: CinePlayer) -> void:
	# the sheep masks stay on all four
	for e: Array in [["c1", 2.3], ["c1", 24.0], ["c2", 6.21], ["c3", 9.39], ["dolly", 11.51], ["dolly", 1.0]]:
		pl.seek(float(e[1]))
		_check(_held(pl.actors[String(e[0])], "SheepMask") != null, "%s wears the sheep mask at r %.1f" % [String(e[0]), float(e[1])])
	# the rice bowl sits on C1's face, the slide runs on the table tops along the row, the trays fly as he passes
	var c1: CineActor = pl.actors["c1"]
	pl.seek(4.0)
	var bowl: Dictionary = _hold_of(c1, "RiceBowl")
	if not bowl.is_empty():
		var bc: Vector3 = _held_xf(c1, bowl).origin
		_check(bc.distance_to(c1.bone_world("Head")) < 0.35, "the rice bowl is on C1's mask (%.2f m from his head)" % bc.distance_to(c1.bone_world("Head")))
	var land: Vector3 = tl.get("LAND")
	var end: Vector3 = tl.get("SLIDE_END")
	for r: float in [18.9, 19.4, 19.85]:
		pl.seek(r)
		var hp: Vector3 = c1.bone_world("Hips")
		print("  slide r %.2f: C1 hips (%.2f, %.2f, %.2f)" % [r, hp.x, hp.y, hp.z])
		_check(hp.y > 0.72 and hp.y < 1.15 and absf(hp.z - land.z) < 0.35 and hp.x < land.x + 0.4 and hp.x > end.x - 0.4,
			"C1 slides along the lunch tables at r %.2f (hips %s)" % [r, str(hp)])
	for j: int in 2:
		var lt: Node3D = pl.prop_nodes["lunch_%d" % j]
		pl.seek(18.0)
		var before: Vector3 = lt.position
		pl.seek(21.0)
		_check(lt.position.distance_to(before) > 0.5 and lt.position.y < 0.1, "lunch tray %d is knocked off the table" % j)
	_check(tl.fx.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "crate").size() == 2, "both stacked chairs burst")
	_check(String((tl.actors["dolly"]["opts"] as Dictionary).get("shirt_color", Color.BLACK).to_html(false)) == StoryCast.CREAM.to_html(false), "Dolly wears the cream cardigan")
	# one signature each: the tray shield (code move on every tier) and the bench ram
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "hero" and String(c.get("move", "")) == "tray_guard"), "the tray shield")
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["type"] == "hold" and c["actor"] == "hero" and String(c["kind"]) == "bench"), "the bench ram")

