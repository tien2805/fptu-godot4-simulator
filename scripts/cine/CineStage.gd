# File: res://scripts/cine/CineStage.gd
# Baked cinematic stage placements (plan 2026-10-26-cine-transition): FreeRoam.cine_stage looks a stage up here before it
# searches. A stage is keyed by its signature (the fields the search reads: landmark, at, yaw, size, near, offset,
# fallback; tod / exposure do not move it). requests() lists every stage the game resolves: each timeline's own stage
# (the gallery, F9, CinePreview), each story beat's cinematic staged at its anchor (StoryRoam.stage_cinematic: cine /
# video slots and their choice tails, mission intros, "after" cinematics) and the mission spots that share the search
# (MissionCorridor's set, the Day 4 canteen box of MissionCanteen and the d4 fight). tests/test_cine_transition.gd
# recomputes every entry with the full search and prints a replacement CineStageBake.gd when the map changed.
class_name CineStage
extends RefCounted


## Stable key of a stage dictionary (2-decimal fields; -0.00 folded to 0.00).
static func signature(stage: Dictionary) -> String:
	var at: Variant = stage.get("at")
	return "%s|%s|%s|%s|%s|%s|%s" % [String(stage.get("landmark", "")), _v2(at) if at is Vector2 else "-",
		_f(float(stage.get("yaw_deg", 0.0))), _v2(stage.get("size", Vector2(14.0, 10.0))), _f(float(stage.get("near", 30.0))),
		_v2(stage.get("offset", Vector2.ZERO)), String(stage.get("fallback", ""))]


static func _f(v: float) -> String:
	return "%.2f" % (snappedf(v, 0.01) + 0.0)


static func _v2(v: Vector2) -> String:
	return _f(v.x) + "," + _f(v.y)


## {"xf": Transform3D, "info": cine_stage_info} of a baked stage, {"none": true} for a stage baked with no clear spot,
## {} when the stage is not in the table.
static func baked(stage: Dictionary) -> Dictionary:
	var e: Variant = CineStageBake.TABLE.get(signature(stage))
	if not (e is Array):
		return {}
	if (e as Array).is_empty():
		return {"none": true}
	return {"xf": entry_xf(e), "info": entry_info(e)}


## Table entry: [x, y, z, yaw (rad), landmark, ring, road_aligned, ground_y, centre x, centre z].
static func entry_xf(e: Array) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(e[3])), Vector3(float(e[0]), float(e[1]), float(e[2])))


static func entry_info(e: Array) -> Dictionary:
	return {"landmark": String(e[4]), "ring": float(e[5]), "road_aligned": bool(e[6]), "ground_y": float(e[7]),
		"centre": Vector2(float(e[8]), float(e[9])), "yaw_deg": snappedf(rad_to_deg(float(e[3])), 0.01),
		"floor_y": snappedf(float(e[1]), 0.001), "pos": Vector2(snappedf(float(e[0]), 0.01), snappedf(float(e[2]), 0.01))}


## One table line for a searched stage (xf and the search's cine_stage_info).
static func entry_text(sig: String, xf: Transform3D, info: Dictionary) -> String:
	var c: Vector2 = info.get("centre", Vector2.ZERO)
	return "\t\"%s\": [%.6f, %.6f, %.6f, %.9f, \"%s\", %.1f, %s, %.6f, %.4f, %.4f]," % [sig, xf.origin.x, xf.origin.y, xf.origin.z,
		xf.basis.get_euler().y, String(info.get("landmark", "")), float(info.get("ring", 0.0)),
		"true" if bool(info.get("road_aligned", false)) else "false", float(info.get("ground_y", 0.0)), c.x, c.y]


## Every stage the game resolves through FreeRoam.cine_stage: [{"label", "stage"}], one per signature (first label kept).
## story: a StoryRoam with its anchors computed (StoryRoam.stage_cinematic); anchors with a fixed "xf" (the yard pad) and
## empty stages (busted: the player's spot) never search and are left out.
static func requests(story: StoryRoam) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for slot: String in CineTimeline.slots():
		var tl: CineTimeline = CineTimeline.load_slot(slot)
		if tl != null and not tl.stage.is_empty():
			_add(out, seen, slot, tl.stage)
	for rq: Array in StoryRoam.cine_requests():
		var tl2: CineTimeline = CineTimeline.load_slot(String(rq[0]))
		if tl2 == null:
			continue
		var o: Dictionary = {}
		story.stage_cinematic(tl2, String(rq[1]), o)
		if o.has("xf") or tl2.stage.is_empty():
			continue
		_add(out, seen, "%s@%s" % [rq[0], rq[1]], tl2.stage)
	_add(out, seen, "MissionCorridor", MissionCorridor.corridor_stage())
	_add(out, seen, "MissionCanteen / fight d4", CineTimeline.canteen_stage(Vector2(14.0, 10.0), "noon"))
	return out


static func _add(out: Array, seen: Dictionary, label: String, stage: Dictionary) -> void:
	var sig: String = signature(stage)
	if seen.has(sig):
		return
	seen[sig] = true
	out.append({"label": label, "stage": stage.duplicate()})
