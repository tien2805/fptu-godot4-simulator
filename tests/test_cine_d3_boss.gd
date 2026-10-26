# File: res://tests/test_cine_d3_boss.gd
# Headless test of seg_d3_boss (spec C-D7 / C-D9): the shared Phase C fight checks (tests/support/cine_fight.gd, modelled on
# test_cine_d4_brawl) plus the gags: the gold sunglasses fly off at H1, the party horn stays in Alexander's mouth after H4.
# Run:  godot --headless --path . --script tests/test_cine_d3_boss.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_fight.gd"


func _conf() -> Dictionary:
	return {"slot": "seg_d3_boss", "checks": _gags}


func _wears(a: CineActor, prefix: String) -> bool:
	return a.holds.any(func(h: Dictionary) -> bool: return String((h["node"] as Node3D).name).begins_with(prefix) and (h["att"] as Node3D).visible)


func _gags(_t: Object, pl: CinePlayer) -> void:
	var a: CineActor = pl.actors["a"]
	pl.seek(_real("h1") - 0.5)
	_check(_wears(a, "GoldShades") and not (pl.prop_nodes["shades_fly"] as Node3D).visible, "Alexander wears his gold sunglasses before H1")
	pl.seek(_real("h1") + 0.4)
	_check(not _wears(a, "GoldShades") and (pl.prop_nodes["shades_fly"] as Node3D).visible, "the sunglasses fly off at H1")
	pl.seek(_real("h4") + 1.0)
	var horn: bool = _wears(a, "PartyHorn") and _held(pl.actors["hero"], "w3") == null
	_check(horn, "after H4 the party horn sits in Alexander's mouth")
	_check(_wears(a, "HawaiiPrint"), "the Hawaiian shirt flowers stay on")
