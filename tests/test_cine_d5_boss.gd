# File: res://tests/test_cine_d5_boss.gd
# Headless test of seg_d5_boss (spec C-D8 / C-D9): the shared Phase C fight checks (tests/support/cine_fight.gd, modelled on
# test_cine_d4_brawl) plus the gag: Za Mẫn's bent katana is whole until the staff comes down (H4) while he blocks with it
# (the "block_high" move, the blade across over his head), then a snapped stub; the broken-off blade starts where the katana
# broke (mid-blade, within 0.15 m on the UAL tier) and spins away to land clear of everyone.
# Run:  godot --headless --path . --script tests/test_cine_d5_boss.gd   (CINE_FAST=1 / CINE_NO_FREEROAM=1 / CINE_NO_MIXAMO=1)
extends "res://tests/support/cine_fight.gd"


func _conf() -> Dictionary:
	return {"slot": "seg_d5_boss", "surface_extra_ids": ["rack_b", "desk"], "checks": _gags}


func _katana_hold(a: CineActor) -> Dictionary:
	for h: Dictionary in a.holds:
		var n: Node3D = h["node"]
		if String(n.name).begins_with("Katana") and (h["att"] as Node3D).visible:
			return h
	return {}


func _katana(a: CineActor) -> String:
	var h: Dictionary = _katana_hold(a)
	if h.is_empty():
		return "none"
	return "bent" if (h["node"] as Node3D).find_child("Tip", false, false) != null else "broken"


func _gags(_t: Object, pl: CinePlayer) -> void:
	var a: CineActor = pl.actors["a"]
	var h4s: float = tl.story_time("H4")
	pl.seek(tl.clock.real_at(h4s - 0.15))
	var before: String = _katana(a)
	var mv: String = String(a.active_move(pl.s).get("move", ""))
	var blade_before: bool = (pl.prop_nodes["blade"] as Node3D).visible
	pl.seek(tl.clock.real_at(h4s - 0.005))
	var kh: Dictionary = _katana_hold(a)
	var mid := Vector3.INF
	if not kh.is_empty():
		mid = _held_xf(a, kh) * Vector3(0.0, 0.0, -(0.08 + CinePropsC.KATANA_BLADE * 0.4))
	var path: Array = tl.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "blade")[0]["opts"]["path"]
	var start: Vector3 = path[0][1]
	var a_d: Vector3 = tl.get("A_D")
	var p3: Vector3 = tl.get("P3")
	var local: Vector3 = Basis(Vector3.UP, deg_to_rad(CineTimeline.face(a_d, p3))).inverse() * (mid - a_d)
	print("  katana mid-blade at H4 %s (Za Mẫn's frame %s), blade start %s: %.3f m" % [str(mid), str(local), str(start), mid.distance_to(start)])
	_check(mid.distance_to(start) < 0.15, "the snapped blade starts at the katana's mid-blade (%.3f m)" % mid.distance_to(start))
	pl.seek(_real("h4") + 1.2)
	var after: String = _katana(a)
	_check(before == "bent" and after == "broken", "the bent katana snaps on the staff at H4 (%s -> %s)" % [before, after])
	_check(mv == "block_high", "Za Mẫn blocks with the katana over his head just before the blow (%s)" % mv)
	_check(not blade_before and (pl.prop_nodes["blade"] as Node3D).visible, "the broken-off blade appears and spins away")
	var land: Vector3 = path[path.size() - 1][1]
	for r: float in [_real("a1"), _real("h5") + 1.0, 24.0]:
		pl.seek(r)
		for id: String in ["a", "d", "hero"]:
			var ap: Vector3 = (pl.actors[id] as CineActor).position
			_check(Vector2(ap.x - land.x, ap.z - land.z).length() > 0.45, "%s does not stand on the landed blade at r %.1f" % [id, r])
	var room: Dictionary = tl.props.filter(func(pr: Dictionary) -> bool: return pr["id"] == "room")[0]
	_check(absf(float(room["opts"].get("door_x", 99.0)) - CineFightC.EXIT.x) < 0.01, "the server room has a doorway where the fox runs out")
