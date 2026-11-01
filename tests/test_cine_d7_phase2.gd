# File: res://tests/test_cine_d7_phase2.gd
# Headless test of seg_d7_phase2 (plan 2026-11-01-w4-day7.md T4): the shared Phase C fight checks (tests/support/cine_fight.gd:
# 25.000 s, the ramps on their beats, contacts on every tier, bodies, weapons, the beat sheet, FreeRoam) plus the gags: the
# blackout flashlight is lit in the protagonist's hand on H1, the antique vase is in his hands on H4 and gone right after
# (it burst: debris on Lọ's head), the wolf's slam bursts the surface plinth's vase and Lọ's crash bursts the crash plinth's
# vase (each whole before, gone after), and the stage lines up with the real gallery: LairTower.SLOT_OFFSET puts the surface
# and the spare plinth on the hall's plinths at (3, 0) and (-3, 0) with the same vase seeds, and every carried-set plinth on
# the hall plinth it stands in for (XEM LẠI PHIM).
# Run:  godot --headless --path . --script tests/test_cine_d7_phase2.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_fight.gd"


func _conf() -> Dictionary:
	return {"slot": "seg_d7_phase2", "surface_extra_ids": ["plinth_l", "plinth_g"], "checks": _gags}


func _vase_of(pl: CinePlayer, id: String) -> Node3D:
	return (pl.prop_nodes[id] as Node3D).find_child("Vase", true, false) as Node3D


func _gags(_t: Object, pl: CinePlayer) -> void:
	var h: CineActor = pl.actors["hero"]
	# H1: the lit torch in the hand
	pl.seek(_real("h1"))
	var torch: Node3D = _held(h, "w1")
	var lens: MeshInstance3D = torch.find_child("Lens", true, false) as MeshInstance3D if torch else null
	var lit: bool = lens != null and lens.material_override is StandardMaterial3D and (lens.material_override as StandardMaterial3D).emission_enabled
	_check(torch != null and lit, "the blackout flashlight is in the protagonist's hand on H1, its lens lit")
	# H4: the vase in his hands, then gone (burst on Lọ's head)
	var h4s: float = tl.story_time("H4")
	pl.seek(tl.clock.real_at(h4s - 0.01))
	_check(_held(h, "w3") != null, "the antique vase is in his hands just before H4")
	pl.seek(tl.clock.real_at(h4s + 0.1))
	_check(_held(h, "w3") == null, "the vase is gone right after H4 (it burst)")
	_check(tl.fx.any(func(e: Dictionary) -> bool: return String(e["kind"]) == "debris" and String(e["at"]) == "H4" and String(e["where"]) == "a:Head"),
		"shards burst off Lọ's head on H4")
	# the two plinth vases: whole before the slam / the crash, burst after (the crate fx is a forward event: a fresh
	# player plays through)
	var pf := CinePlayer.new()
	world.add_child(pf)
	pf.setup(tl, Transform3D.IDENTITY, {"manual": true, "music": false})
	pf.start()
	for e: Array in [["surface", float(tl.get("slam_s"))], ["crates", float(tl.get("sc"))]]:
		var v: Node3D = _vase_of(pf, String(e[0]))
		_check(v != null, "the %s plinth carries a vase" % String(e[0]))
		if v == null:
			continue
		var at_r: float = tl.clock.real_at(float(e[1]))
		while pf.r < at_r - 0.05:
			pf.step(1.0 / 60.0)
		var before: bool = v.visible
		while pf.r < at_r + 0.05:
			pf.step(1.0 / 60.0)
		var after: bool = v.visible
		_check(before and not after, "the %s plinth's vase bursts when he hits it (%s -> %s)" % [String(e[0]), str(before), str(after)])
		_check(tl.fx.any(func(f: Dictionary) -> bool: return String(f["kind"]) == "crate" and String(f["where"]) == String(e[0])),
			"a crate fx bursts the %s vase" % String(e[0]))
	pf.queue_free()
	# lined up with the real gallery (LairTower: plinth i at PLINTH_XS[i % 4], PLINTH_ZS[i / 4], vase seed i)
	var off: Vector3 = LairTower.SLOT_OFFSET["seg_d7_phase2"]
	var hall: Dictionary = {}
	var i: int = 0
	for z: float in LairTower.PLINTH_ZS:
		for x: float in LairTower.PLINTH_XS:
			hall[i] = Vector3(x, 0.0, z)
			i += 1
	var cfg: Dictionary = tl.get("cfg")
	var plinths: Array = [["surface", cfg["surface"]["pos"], int((cfg["surface"]["opts"] as Dictionary).get("vase", -1))]]
	for ex: Array in cfg["surface_extra"]:
		if ex.size() > 4 and (ex[4] as Dictionary).has("vase"):
			plinths.append([String(ex[0]), ex[2], int(ex[4]["vase"])])
	for pr: Dictionary in tl.props:
		if String(pr["kind"]) == "plinth" and bool((pr["opts"] as Dictionary).get("set", false)):
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
