# File: res://tests/test_cine_d2_boss.gd
# Headless test of seg_d2_boss (spec C-D6 / C-D9): the shared Phase C fight checks (tests/support/cine_fight.gd, modelled on
# test_cine_d4_brawl) plus the gag: Sói Xám's LED eyes glow until the chain fist (H4) and are dark after it.
# Run:  godot --headless --path . --script tests/test_cine_d2_boss.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_fight.gd"


func _conf() -> Dictionary:
	return {"slot": "seg_d2_boss", "surface_extra_ids": ["pillar_b"], "checks": _gags}


func _led(a: CineActor) -> int:
	for h: Dictionary in a.holds:
		var n: Node3D = h["node"]
		if String(n.name).begins_with("WolfHelmet") and (h["att"] as Node3D).visible:
			return 1 if bool(n.get_meta("led_on", false)) else 0
	return -1


func _gags(_t: Object, pl: CinePlayer) -> void:
	var a: CineActor = pl.actors["a"]
	pl.seek(_real("h4") - 0.3)
	var before: int = _led(a)
	pl.seek(_real("h4") + 0.6)
	var after: int = _led(a)
	_check(before == 1 and after == 0, "Sói Xám's LED eyes glow before the chain fist and go dark after it (%d -> %d)" % [before, after])
	pl.seek(1.0)
	var bikers: bool = ["b", "d"].all(func(r: String) -> bool: return _led(pl.actors[r]) == 1) and _led(pl.actors["c"]) == -1
	_check(bikers, "two bikers wear wolf helmets with glowing eyes, the third lost his (the one in the protagonist's hands)")
