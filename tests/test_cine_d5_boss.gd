# File: res://tests/test_cine_d5_boss.gd
# Headless test of seg_d5_boss (spec C-D8 / C-D9): the shared Phase C fight checks (tests/support/cine_fight.gd, modelled on
# test_cine_d4_brawl) plus the gag: Za Mẫn's bent katana is whole until the staff comes down (H4), then a snapped stub,
# the blade spinning away; he raises it two-handed to block just before the blow.
# Run:  godot --headless --path . --script tests/test_cine_d5_boss.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_fight.gd"


func _conf() -> Dictionary:
	return {"slot": "seg_d5_boss", "surface_extra_ids": ["rack_b"], "checks": _gags}


func _katana(a: CineActor) -> String:
	for h: Dictionary in a.holds:
		var n: Node3D = h["node"]
		if String(n.name).begins_with("Katana") and (h["att"] as Node3D).visible:
			return "bent" if n.find_child("Tip", false, false) != null else "broken"
	return "none"


func _gags(_t: Object, pl: CinePlayer) -> void:
	var a: CineActor = pl.actors["a"]
	pl.seek(_real("h4") - 0.3)
	var before: String = _katana(a)
	var blade_before: bool = (pl.prop_nodes["blade"] as Node3D).visible
	pl.seek(_real("h4") + 1.2)
	var after: String = _katana(a)
	_check(before == "bent" and after == "broken", "the bent katana snaps on the staff at H4 (%s -> %s)" % [before, after])
	_check(not blade_before and (pl.prop_nodes["blade"] as Node3D).visible, "the broken-off blade appears and spins away")
	pl.seek(tl.clock.real_at(tl.story_time("H4") - 0.15))
	_check(String(a.active_move(pl.s).get("move", "")) == "staff_guard", "Za Mẫn raises the katana two-handed to block just before the blow (%s)" % String(a.active_move(pl.s).get("move", "")))
