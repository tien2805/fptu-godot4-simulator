# File: res://tests/test_cine_d3_boss.gd
# Headless test of seg_d3_boss (spec C-D7 / C-D9, reworked by plan 2026-11-05-w6-fights and its review round) on
# tests/support/cine_brawl.gd: exactly 21.100 s, the ramps on the music's accents, the 4.5 s finisher swell and its 3 s tail,
# the hits taken at normal speed with punch-ins, contacts on every tier (the crane hook into the fox, the wolf and
# Alexander's collar, the collar grab, the shove on the sheep, the three punches the protagonist takes, Alexander's
# hurricane kick into his own sheep), the sheep against the toppled forklift, Alexander onto the crates, bodies, framing,
# FreeRoam staging for every Phase C slot and the skip. Gags: the hook creaks before the shove and swings as one pendulum
# (the protagonist's hands on it at the shove), its cable's top stays at the crane's anchor through the hoist, Alexander
# hangs off it above the ground, his hurricane kick misses the protagonist (who never ducks) and lands on the sheep, nobody
# runs off, the masks and the gold sunglasses stay on, the party horn ends on the ground under the protagonist's foot (the
# last toot), and the hand-off to cine_d3 (Alexander sitting where the fight leaves him, the protagonist, the horn).
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
			"X3": ["alex", "fists", "hero"], "A1": ["alex", "feet", "sheep"], "H5": ["hero", "prop:crane_hook", "alex"]},
		"slams": [["sheep", ["forklift"], 8.2, 8.6], ["alex", ["crates"], 16.7, 16.9]],
		"lying": [["fox", 5.0], ["wolf", 7.7], ["sheep", 13.2], ["alex", 19.5], ["fox", 21.0], ["wolf", 21.0], ["sheep", 21.0]],
		"seated": [["alex", 21.05]],
		"crash": ["sc", "crates"],
		"hit_vars": ["slam_s", "sc", "s_yk", "s_shv", "s_sh"],
		"pen_skip": [["hero", "crane_hook", 2.2, 2.75], ["alex", "crane_hook", 13.3, 15.32]],
		"burst": {"crates": "sc"},
		"not_solid": ["horn_fly"],
		"moving": ["crane_hook"],
		"held": [["alex", "PartyHorn", 16.5, true], ["alex", "PartyHorn", 17.2, false], ["alex", "HawaiiPrint", 20.0, true]],
		"shown": [["crane_hook", 1.0, true], ["horn_fly", 16.5, false], ["horn_fly", 20.0, true], ["crates", 16.0, true]],
		"gone": [["sheep", 21.0, true]],
		"keep": ["forklift", "crates"],
		"stages": PHASE_C, "checks": _gags}


func _gags(_t: Object, pl: CinePlayer) -> void:
	# the masks and the sunglasses stay on (the shades lowered at 9.42, askew after the crates)
	for e: Array in [["fox", "FoxMask", 2.9], ["fox", "FoxMask", 20.5], ["wolf", "WolfMask", 6.0], ["wolf", "WolfMask", 20.5],
			["sheep", "SheepMask", 8.3], ["sheep", "SheepMask", 12.5], ["sheep", "SheepMask", 20.5], ["alex", "GoldShades", 1.0],
			["alex", "GoldShades", 10.0], ["alex", "GoldShades", 14.5], ["alex", "GoldShades", 20.5]]:
		pl.seek(float(e[2]))
		_check(_held(pl.actors[String(e[0])], String(e[1])) != null, "%s wears %s at r %.1f" % [String(e[0]), String(e[1]), float(e[2])])
	var hero: CineActor = pl.actors["hero"]
	var alex: CineActor = pl.actors["alex"]
	var sheep: CineActor = pl.actors["sheep"]
	var hook: Node3D = pl.prop_nodes["crane_hook"]
	# the hook creaks on its cable before the shove (it rocks a little), then swings: both hands on it at the shove, far
	# out at its apexes, back through the middle
	var s_sh: float = float(tl.get("s_sh"))
	var cz0: float = 99.0
	var cz1: float = -99.0
	for k: int in 24:
		pl.seek(tl.clock.real_at(s_sh * k / 24.0))
		cz0 = minf(cz0, hook.position.z)
		cz1 = maxf(cz1, hook.position.z)
	print("  creak: the hook rocks %.2f m before the shove" % (cz1 - cz0))
	_check(cz1 - cz0 > 0.1 and cz1 - cz0 < 0.6, "the hook creaks, rocking on its cable before the shove (%.2f m)" % (cz1 - cz0))
	pl.seek(1.0)
	var rest: Vector3 = hook.position
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
	# the cable: its top stays at the crane's anchor (the pivot, 0.15 m up the cable) while the hoist shortens it
	var cable: MeshInstance3D = hook.get_node_or_null("Cable")
	_check(cable != null, "the hook has its cable")
	if cable != null:
		var consts: Dictionary = (tl.get_script() as GDScript).get_script_constant_map()
		var pivot: Vector3 = (consts["HOOK_R"] as Vector3) + Vector3(0.0, float(consts["HOOK_L"]), 0.0)
		var worst: float = 0.0
		var h5: float = float(tl.get("h5"))
		for s: float in [1.0, s_sh + 0.3, h5 - 0.1, h5 + 0.12, float(tl.get("s_hoist")) + 0.1, float(tl.get("s_rel")), tl.story_end - 0.1]:
			pl.seek(tl.clock.real_at(s))
			var top: Vector3 = cable.global_transform * Vector3(0.0, (cable.mesh as CylinderMesh).height * 0.5, 0.0)
			worst = maxf(worst, absf(top.distance_to(pivot) - 0.15))
		print("  cable: its top off the crane's anchor by at most %.3f m" % worst)
		_check(worst < 0.02, "the cable's top stays at the crane's anchor through the hoist (%.3f m)" % worst)
	# Alexander hangs off the hook: above the ground while it hoists him, the dangle loop on him, back on the floor after
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "alex" and String(c.get("move", "")) == "dangle"), "Alexander dangles off the hook")
	for r: float in [14.5, 14.95]:
		pl.seek(r)
		var low: float = 99.0
		for b: String in ["Foot.L", "Foot.R", "Hips"]:
			low = minf(low, alex.bone_world(b).y)
		print("  hoist r %.1f: Alexander's lowest (feet, hips) %.2f m, hips %s" % [r, low, str(alex.bone_world("Hips"))])
		_check(low > 0.35, "Alexander is off the ground on the hook at r %.1f (%.2f m)" % [r, low])
	# the signature: his hurricane kick misses the protagonist (who never ducks: no dodge near it) and lands on his own sheep
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "alex" and String(c.get("move", "")) == "hurricane_kick"), "Alexander's hurricane kick")
	var a1: float = float(tl.get("a1"))
	var ducks: int = 0
	var thrown: bool = false
	var runs: int = 0
	for c: Dictionary in tl.cues:
		var mv: String = String(c.get("move", ""))
		var cs: float = float(c.get("s", -1.0))
		if c["actor"] == "hero" and mv in ["dodge", "duck"] and absf(cs - a1) < 0.3:
			ducks += 1
		if c["actor"] == "sheep" and mv == "thrown" and String(c.get("at", "")) == "A1":
			thrown = true
		if mv in ["sprint", "run", "jog_away"] and cs > float(tl.get("h3")):
			runs += 1
	_check(ducks == 0, "the protagonist does not duck the hurricane kick")
	var miss: float = 99.0
	for k: int in 21:
		pl.seek(tl.clock.real_at(a1 - 0.35 + k * 0.035))
		for b: String in ["Foot.L", "Foot.R", "LowerLeg.L", "LowerLeg.R"]:
			miss = minf(miss, alex.bone_world(b).distance_to(hero.bone_world("Head")))
	print("  hurricane kick: nearest foot / shin to the protagonist's head %.2f m" % miss)
	_check(miss > 0.25, "the hurricane kick misses the protagonist (%.2f m)" % miss)
	_check(thrown, "the kick spins the sheep down")
	# nobody runs off: every guard is still in the yard at the end
	_check(runs == 0, "nobody runs off after H3")
	_check(not tl.subs.any(func(sb: Dictionary) -> bool: return String(sb["text"]).contains("Chạy")), "no \"Chạy!\"")
	# the party horn falls out of his pocket, lands on the ground; the protagonist's foot comes down on it: the last toot
	var horn: Node3D = pl.prop_nodes["horn_fly"]
	var s_toot: float = float(tl.get("s_toot"))
	var foot: float = 99.0
	for k: int in 9:
		pl.seek(tl.clock.real_at(s_toot - 0.12 + k * 0.02))
		for b: String in ["Foot.L", "Foot.R"]:
			var fp: Vector3 = hero.bone_world(b)
			foot = minf(foot, Vector2(fp.x - horn.global_position.x, fp.z - horn.global_position.z).length() + maxf(fp.y - 0.15, 0.0))
	print("  toot: the protagonist's foot %.2f m from the horn" % foot)
	_check(foot < 0.15, "the protagonist's foot comes down on the party horn (%.2f m)" % foot)
	_check(tl.sfx.any(func(e: Dictionary) -> bool: return String(e["cue"]) == "party_horn" and e["at"] is float and absf(float(e["at"]) - s_toot) < 0.01), "the toot under his foot")
	pl.seek(20.5)
	_check(horn.visible and horn.global_position.y < 0.15, "the party horn is on the ground at the end (y %.2f)" % horn.global_position.y)
	_check(sheep.visible, "the sheep is still in the yard at the end")
	_check(tl.fx.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "crate").size() == 1, "the crates burst")
	# the hand-off: cine_d3 opens on this end state (Alexander sitting in the wreck, the protagonist over him, the horn)
	var nx: CineTimeline = CineTimeline.load_slot("cine_d3")
	_check(nx != null, "cine_d3 loads")
	if nx == null:
		return
	pl.seek(tl.length - 0.01)
	var ak: Array = nx.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "key" and c["actor"] == "alex")
	var hk: Array = nx.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "key" and c["actor"] == "hero")
	var am: Array = nx.cues.filter(func(c: Dictionary) -> bool: return c["type"] == "move" and c["actor"] == "alex")
	var nh: Array = nx.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "horn")
	var ya: float = rad_to_deg(alex.rotation.y)
	if not ak.is_empty():
		print("  hand-off: Alexander %s yaw %.1f, cine_d3 %s yaw %.1f" % [str(alex.position), ya, str(ak[0]["pos"]), float(ak[0]["yaw"])])
	_check(not ak.is_empty() and alex.position.distance_to(ak[0]["pos"]) < 0.05 and absf(wrapf(ya - float(ak[0]["yaw"]), -180.0, 180.0)) < 5.0,
		"cine_d3 opens with Alexander where the fight leaves him")
	_check(not am.is_empty() and String(am[0]["move"]) == "slumped" and alex.active_move(tl.story_end - 0.01).get("move", "") == "slumped",
		"Alexander sits (slumped) at the fight's end and at cine_d3's start")
	var yh: float = rad_to_deg(hero.rotation.y)
	if not hk.is_empty():
		print("  hand-off: the protagonist %s yaw %.1f, cine_d3 %s yaw %.1f" % [str(hero.position), yh, str(hk[0]["pos"]), float(hk[0]["yaw"])])
	_check(not hk.is_empty() and hero.position.distance_to(hk[0]["pos"]) < 0.05 and absf(wrapf(yh - float(hk[0]["yaw"]), -180.0, 180.0)) < 5.0,
		"cine_d3 opens with the protagonist where the fight leaves him")
	if not nh.is_empty():
		print("  hand-off: the horn %s, cine_d3 %s yaw %.1f" % [str(horn.position), str(nh[0]["pos"]), float(nh[0]["yaw"])])
	_check(not nh.is_empty() and (nh[0]["pos"] as Vector3).distance_to(horn.position) < 0.05
		and absf(wrapf(float(nh[0]["yaw"]) - horn.rotation_degrees.y, -180.0, 180.0)) < 5.0, "cine_d3 opens with the party horn where it fell")
