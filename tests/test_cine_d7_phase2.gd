# File: res://tests/test_cine_d7_phase2.gd
# Headless test of seg_d7_phase2 (plan 2026-11-01-w4-day7.md T4, reworked by plan 2026-11-05-w6-fights task 5) on
# tests/support/cine_brawl.gd: exactly 14.190 s, the ramps on the music's accents, the 2.5 s finisher swell and its 2 s tail,
# the headbutt taken at normal speed with a punch-in, contacts on every tier (the flashlight bonk, the sheep's headbutt, the
# clinch for the hip throw, the caught urn slammed over the fox's head), the sheep thrown into the surface plinth's vase,
# bodies, framing, FreeRoam staging and the skip. Gags: the blackout flashlight is lit in the protagonist's hand on H1 and
# knocked to the floor by the headbutt; the surface vase is whole before the throw and burst after, the sheep clears the
# plinth itself; Lọ's urn passes from his hands to the flight to the protagonist's hands (the catch, the signature) to the
# fox's head without a jump, and stays there to the end; the stage lines up with the real gallery: LairTower.SLOT_OFFSET
# puts the surface and the spare plinth on the hall's plinths at (3, 0) and (-3, 0) with the same vase seeds, and every
# carried-set plinth on the hall plinth it stands in for (XEM LẠI PHIM); Lọ's last line sends everyone to the helicopter.
# Run:  godot --headless --path . --script tests/test_cine_d7_phase2.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_brawl.gd"

const HANDOVER: float = 0.06


func _conf() -> Dictionary:
	return {"slot": "seg_d7_phase2", "length": 14.19, "finisher": "H5", "swell_end": 12.19, "tail": 2.0, "freezes": 3,
		"ramps": {"H1": 3.07, "H2": 6.39, "A1": 8.05, "H5": 9.70},
		"taken": {"X1": 4.73},
		"touch": {"GR": 5.98},
		"strikes": {"H1": ["hero", "held:Flashlight", "wolf"], "X1": ["sheep", "head", "hero"], "GR": ["hero", "fists", "sheep"],
			"H5": ["hero", "held:AntiqueUrn", "fox"]},
		"slams": [["sheep", ["surface"], 6.3, 6.45]],
		"lying": [["sheep", 7.6], ["sheep", 14.1], ["fox", 12.3], ["fox", 14.1]],
		"hit_vars": ["slam_s", "s_land", "s_down", "s_on"],
		"burst": {"surface": "slam_s"},
		"not_solid": ["urn_fly", "torch"],
		"held": [["hero", "Flashlight", 3.07, true], ["hero", "Flashlight", 5.2, false], ["lo", "AntiqueUrn", 7.2, true],
			["lo", "AntiqueUrn", 7.7, false], ["hero", "AntiqueUrn", 8.3, true], ["hero", "AntiqueUrn", 10.45, false],
			["fox", "AntiqueUrn", 10.45, true], ["fox", "AntiqueUrn", 14.1, true]],
		"shown": [["torch", 4.5, false], ["torch", 6.0, true], ["urn_fly", 7.3, false], ["urn_fly", 7.8, true], ["urn_fly", 8.3, false]],
		"gone": [["lo", 12.5, true], ["lo", 14.15, false]],
		"keep": ["surface", "plinth_l"],
		"stages": ["seg_d7_phase2"], "checks": _gags}


func _vase_of(pl: CinePlayer, id: String) -> Node3D:
	return (pl.prop_nodes[id] as Node3D).find_child("Vase", true, false) as Node3D


func _at(pl: CinePlayer, s: float) -> void:
	pl.seek(tl.clock.real_at(s))


func _gags(_t: Object, pl: CinePlayer) -> void:
	var h: CineActor = pl.actors["hero"]
	# H1: the lit flashlight in the hand; on the floor after the headbutt
	pl.seek(3.07)
	var torch: Node3D = _held(h, "Flashlight")
	var lens: MeshInstance3D = torch.find_child("Lens", true, false) as MeshInstance3D if torch else null
	var lit: bool = lens != null and lens.material_override is StandardMaterial3D and (lens.material_override as StandardMaterial3D).emission_enabled
	_check(torch != null and lit, "the blackout flashlight is in the protagonist's hand on H1, its lens lit")
	pl.seek(6.0)
	var tf: Node3D = pl.prop_nodes["torch"]
	_check(tf.is_visible_in_tree() and tf.global_position.y < 0.08, "the headbutt knocks the flashlight to the floor (y %.2f)" % tf.global_position.y)
	# Lọ's urn: his hands -> the flight -> the protagonist's hands (the catch) -> the fox's head, no jump at a hand-over
	var urn: Node3D = pl.prop_nodes["urn_fly"]
	var s_rel: float = float(tl.get("s_rel"))
	var a1: float = float(tl.get("a1"))
	var s_on: float = float(tl.get("s_on"))
	_at(pl, s_rel - 0.004)
	var lo_h: Dictionary = _hold_of(pl.actors["lo"], "AntiqueUrn")
	var p0: Vector3 = _held_xf(pl.actors["lo"], lo_h).origin if not lo_h.is_empty() else Vector3.INF
	_at(pl, s_rel + 0.004)
	var p1: Vector3 = urn.global_position
	print("  urn release: Lọ's hands %s, flight %s (%.3f m)" % [str(p0), str(p1), p0.distance_to(p1)])
	_check(p0.distance_to(p1) < HANDOVER, "the urn leaves Lọ's hands into its flight (%.3f m)" % p0.distance_to(p1))
	_at(pl, a1 - 0.004)
	var p2: Vector3 = urn.global_position
	_at(pl, a1 + 0.004)
	var hh: Dictionary = _hold_of(h, "AntiqueUrn")
	var p3: Vector3 = _held_xf(h, hh).origin if not hh.is_empty() else Vector3.INF
	print("  urn catch: flight %s, the protagonist's hands %s (%.3f m)" % [str(p2), str(p3), p2.distance_to(p3)])
	_check(p2.distance_to(p3) < HANDOVER, "the protagonist catches the urn where it flies (%.3f m)" % p2.distance_to(p3))
	_check(tl.cues.any(func(c: Dictionary) -> bool: return c["actor"] == "hero" and String(c.get("move", "")) == "catch"), "the signature: the catch")
	_at(pl, s_on - 0.004)
	hh = _hold_of(h, "AntiqueUrn")
	var p4: Vector3 = _held_xf(h, hh).origin if not hh.is_empty() else Vector3.INF
	var fox: CineActor = pl.actors["fox"]
	_at(pl, s_on + 0.004)
	var fh: Dictionary = _hold_of(fox, "AntiqueUrn")
	var p5: Vector3 = _held_xf(fox, fh).origin if not fh.is_empty() else Vector3.INF
	print("  urn crown: the protagonist's hands %s, the fox's head %s (%.3f m)" % [str(p4), str(p5), p4.distance_to(p5)])
	_check(p4.distance_to(p5) < HANDOVER, "the urn goes from the protagonist's hands onto the fox's head (%.3f m)" % p4.distance_to(p5))
	for r: float in [10.5, 12.3, 14.1]:
		pl.seek(r)
		fh = _hold_of(fox, "AntiqueUrn")
		var d: float = _held_xf(fox, fh).origin.distance_to(fox.bone_world("Head")) if not fh.is_empty() else INF
		_check(d < 0.3, "the urn stays on the fox's head at r %.1f (%.2f m)" % [r, d])
	# the sheep flies over the surface plinth: his back sweeps the vase (the slam), never the plinth itself
	var sheep: CineActor = pl.actors["sheep"]
	var surf: Vector3 = (tl.get_script() as Script).get_script_constant_map()["SURFACE"]
	var col: Array = [["plinth", Transform3D(Basis(), surf + Vector3(0.0, CinePropsD7.PLINTH_H * 0.5, 0.0)),
		Vector3(0.37, CinePropsD7.PLINTH_H * 0.5, 0.37)]]
	var deep: float = 0.0
	var r2: float = 5.9
	while r2 <= 7.6:
		pl.seek(r2)
		deep = maxf(deep, float(Bodies.actor_boxes(Bodies.capsules(sheep), col)["d"]))
		r2 += 1.0 / 60.0
	print("  the sheep over the plinth: deepest %.3f m into it" % deep)
	_check(deep <= PEN_MAX, "the sheep clears the surface plinth itself (%.3f m)" % deep)
	# the surface vase: whole before the throw, burst after (the crate fx is a forward event: a fresh player plays through)
	var pf := CinePlayer.new()
	world.add_child(pf)
	pf.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	pf.start()
	var v: Node3D = _vase_of(pf, "surface")
	_check(v != null, "the surface plinth carries a vase")
	if v != null:
		var at_r: float = tl.clock.real_at(float(tl.get("slam_s")))
		while pf.r < at_r - 0.05:
			pf.step(1.0 / 60.0)
		var before: bool = v.visible
		while pf.r < at_r + 0.05:
			pf.step(1.0 / 60.0)
		_check(before and not v.visible, "the surface plinth's vase bursts when the sheep hits it (%s -> %s)" % [str(before), str(v.visible)])
	_check(tl.fx.any(func(f: Dictionary) -> bool: return String(f["kind"]) == "crate" and String(f["where"]) == "surface"), "a crate fx bursts the surface vase")
	_check(_vase_of(pl, "plinth_l") != null, "the spare plinth carries its vase")
	pf.queue_free()
	# lined up with the real gallery (LairTower: plinth i at PLINTH_XS[i % 4], PLINTH_ZS[i / 4], vase seed i)
	var off: Vector3 = LairTower.SLOT_OFFSET["seg_d7_phase2"]
	var hall: Dictionary = {}
	var i: int = 0
	for z: float in LairTower.PLINTH_ZS:
		for x: float in LairTower.PLINTH_XS:
			hall[i] = Vector3(x, 0.0, z)
			i += 1
	var plinths: Array = []
	for pr: Dictionary in tl.props:
		if String(pr["kind"]) == "plinth":
			plinths.append([String(pr["id"]), pr["pos"], int((pr["opts"] as Dictionary).get("vase", -1))])
	_check(plinths.size() == 12, "the fight's two plinths plus ten carried ones stand for the hall's twelve (%d)" % plinths.size())
	var used: Dictionary = {}
	for pe: Array in plinths:
		var at: Vector3 = (pe[1] as Vector3) + off
		var sd: int = int(pe[2])
		var ok: bool = hall.has(sd) and (hall[sd] as Vector3).distance_to(at) < 0.01 and not used.has(sd)
		used[sd] = true
		_check(ok, "%s stands on the hall's plinth %d in the tower (%s, want %s)" % [String(pe[0]), sd, str(at), str(hall.get(sd, "?"))])
	_check(LairTower.CINE_PLINTHS["seg_d7_phase2"] == [Vector2(3.0, 0.0), Vector2(-3.0, 0.0)], "the tower hides exactly the two plinths the fight brings")
	_check(String(tl.subs[tl.subs.size() - 1]["text"]).contains("trực thăng"), "Lọ's last line sends everyone to the helicopter on the roof")
