# File: res://tests/test_cine_d3_boss.gd
# Headless test of seg_d3_boss (spec C-D7 / C-D9, reworked by plan 2026-11-05-w6-fights) on tests/support/cine_brawl.gd:
# exactly 21.100 s, the ramps on the music's accents, the 4.5 s finisher swell and its 3 s tail, the hits taken at normal
# speed with punch-ins, contacts on every tier (the crane hook into the fox, the wolf and Alexander's collar, the collar
# grab, the shove on the sheep, the three punches the protagonist takes), the sheep against the toppled forklift, Alexander
# onto the crates, bodies, framing, FreeRoam staging for every Phase C slot and the skip. Gags: the hook swings as one
# pendulum (the protagonist's hands on it at the shove), Alexander hangs off it above the ground, his hurricane kick misses,
# the masks and the gold sunglasses stay on, the party horn ends on the ground.
# Run:  godot --headless --path . --script tests/test_cine_d3_boss.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_brawl.gd"

const PHASE_C: Array[String] = ["cine_d2_intro", "cine_d2", "seg_d2_boss", "cine_d3_intro", "cine_d3_mannequins", "cine_d3", "seg_d3_boss",
	"cine_d5_intro", "cine_d5_monitors", "cine_d5_choice", "cine_d5_choice_accept", "cine_d5_choice_refuse", "cine_d5", "seg_d5_boss", "end_c"]


func _conf() -> Dictionary:
	return {"slot": "seg_d3_boss", "length": 21.1, "finisher": "H5", "swell_end": 18.1, "tail": 3.0, "freezes": 4,
		"ramps": {"H1": 2.83, "H2": 5.90, "H3": 8.23, "A1": 12.08, "H5": 13.54},
		"taken": {"X1": 4.22, "X2": 7.54, "X3": 10.81},
		"touch": {"YK": 5.31, "HS": 7.96},
		"strikes": {"H1": ["hero", "prop:crane_hook", "fox"], "X1": ["wolf", "fists", "hero"], "YK": ["hero", "fists", "wolf"],
			"H2": ["hero", "prop:crane_hook", "wolf"], "X2": ["sheep", "fists", "hero"], "HS": ["hero", "fists", "sheep"],
			"X3": ["alex", "fists", "hero"], "H5": ["hero", "prop:crane_hook", "alex"]},
		"slams": [["sheep", ["forklift"], 8.2, 8.6], ["alex", ["crates"], 16.7, 16.9]],
		"lying": [["fox", 5.0], ["wolf", 7.7], ["fox", 21.0], ["wolf", 21.0], ["alex", 20.9]],
		"crash": ["sc", "crates"],
		"hit_vars": ["slam_s", "sc", "s_yk", "s_shv", "s_sh"],
		"pen_skip": [["hero", "crane_hook", 2.2, 2.75], ["alex", "crane_hook", 13.3, 15.32]],
		"burst": {"crates": "sc"},
		"not_solid": ["horn_fly"],
		"moving": ["crane_hook"],
		"held": [["alex", "PartyHorn", 16.5, true], ["alex", "PartyHorn", 17.2, false], ["alex", "HawaiiPrint", 20.0, true]],
		"shown": [["crane_hook", 1.0, true], ["horn_fly", 16.5, false], ["horn_fly", 20.0, true], ["crates", 16.0, true]],
		"gone": [["sheep", 18.0, true], ["sheep", 21.0, false]],
		"keep": ["forklift", "crates"],
		"stages": PHASE_C, "checks": _gags}


func _gags(_t: Object, pl: CinePlayer) -> void:
	# the masks and the sunglasses stay on (the shades lowered at 9.42, askew after the crates)
	for e: Array in [["fox", "FoxMask", 2.9], ["fox", "FoxMask", 20.5], ["wolf", "WolfMask", 6.0], ["wolf", "WolfMask", 20.5],
			["sheep", "SheepMask", 8.3], ["sheep", "SheepMask", 18.8], ["alex", "GoldShades", 1.0], ["alex", "GoldShades", 10.0],
			["alex", "GoldShades", 14.5], ["alex", "GoldShades", 20.5]]:
		pl.seek(float(e[2]))
		_check(_held(pl.actors[String(e[0])], String(e[1])) != null, "%s wears %s at r %.1f" % [String(e[0]), String(e[1]), float(e[2])])
	var hero: CineActor = pl.actors["hero"]
	var alex: CineActor = pl.actors["alex"]
	var hook: Node3D = pl.prop_nodes["crane_hook"]
	# the hook hangs still, then swings: both hands on it at the shove, far out at its apexes, back through the middle
	pl.seek(1.0)
	var rest: Vector3 = hook.position
	var s_sh: float = float(tl.get("s_sh"))
	pl.seek(tl.clock.real_at(s_sh))
	var hands: float = 99.0
	for w: String in ["Wrist.L", "Wrist.R"]:
		var wp: Vector3 = hero.bone_world(w)
		for k: int in 13:   # the shank and the block: 0.45 m under the block's centre up to its top
			hands = minf(hands, wp.distance_to(hook.global_transform * Vector3(0.0, -0.45 + k * 0.05, 0.0)))
	print("  shove: hook (%.2f, %.2f, %.2f), wrists %s %s, nearest %.2f m" % [hook.global_position.x, hook.global_position.y,
		hook.global_position.z, str(hero.bone_world("Wrist.L")), str(hero.bone_world("Wrist.R")), hands])
	_check(hands < 0.25, "the protagonist's hands are on the hook at the shove (%.2f m)" % hands)
	var zmin: float = 99.0
	var zmax: float = -99.0
	for k: int in 120:
		pl.seek(3.0 + k * 0.1)
		zmin = minf(zmin, hook.position.z)
		zmax = maxf(zmax, hook.position.z)
	_check(zmin < rest.z - 2.5 and zmax > rest.z + 2.0, "the hook swings out both ways (z %.2f .. %.2f, rest %.2f)" % [zmin, zmax, rest.z])
	# Alexander hangs off the hook: above the ground while it hoists him, the dangle loop on him, back on the floor after
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "alex" and String(c.get("move", "")) == "dangle"), "Alexander dangles off the hook")
	for r: float in [14.5, 14.95]:
		pl.seek(r)
		var low: float = 99.0
		for b: String in ["Foot.L", "Foot.R", "Hips"]:
			low = minf(low, alex.bone_world(b).y)
		print("  hoist r %.1f: Alexander's lowest (feet, hips) %.2f m, hips %s" % [r, low, str(alex.bone_world("Hips"))])
		_check(low > 0.35, "Alexander is off the ground on the hook at r %.1f (%.2f m)" % [r, low])
	# the signature: his hurricane kick, the protagonist ducks under it (no foot within 0.1 m of his head)
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "alex" and String(c.get("move", "")) == "hurricane_kick"), "Alexander's hurricane kick")
	var a1: float = float(tl.get("a1"))
	var miss: float = 99.0
	for k: int in 21:
		pl.seek(tl.clock.real_at(a1 - 0.35 + k * 0.035))
		for b: String in ["Foot.L", "Foot.R", "LowerLeg.L", "LowerLeg.R"]:
			miss = minf(miss, alex.bone_world(b).distance_to(hero.bone_world("Head")))
	print("  hurricane kick: nearest foot / shin to the protagonist's head %.2f m" % miss)
	_check(miss > 0.25, "the hurricane kick misses (%.2f m)" % miss)
	# the party horn falls out of his pocket and ends on the ground
	pl.seek(20.5)
	var horn: Node3D = pl.prop_nodes["horn_fly"]
	_check(horn.visible and horn.global_position.y < 0.15, "the party horn is on the ground at the end (y %.2f)" % horn.global_position.y)
	_check(tl.fx.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "crate").size() == 1, "the crates burst")
