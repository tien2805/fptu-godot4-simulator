# File: res://scripts/cine/CinePrep.gd
# A cinematic prepared ahead (plan 2026-10-26-cine-transition): FreeRoam.prepare_cinematic keeps one with the loaded
# timeline and its resolved stage frame, so play_cinematic skips that work. Only cheap work happens ahead: no actor is
# built during live play (a CharacterBuilder.build costs 50-80 ms windowed and would stutter the game); the actors are
# built under the black frame, one per frame (CinePlayer.preroll). play_cinematic adopts the stage frame when the slot, the
# stage signature and the opts "xf" match.
class_name CinePrep
extends RefCounted

var slot: String = ""
var timeline: CineTimeline = null
var stage_sig: String = ""
## The opts "xf" the prep was made with (null = none): play_cinematic adopts only with the same opts "xf".
var opts_xf: Variant = null
## Resolved stage frame (Transform3D) or null (no clear spot: play_cinematic decides).
var xf: Variant = null
## FreeRoam.cine_stage_info of that resolution (play_cinematic reports it when it adopts this prep).
var info: Dictionary = {}


func _init(tl: CineTimeline = null, given_xf: Variant = null, stage_xf: Variant = null, stage_info: Dictionary = {}) -> void:
	if tl == null:
		return
	timeline = tl
	slot = tl.slot
	stage_sig = CineStage.signature(tl.stage)
	opts_xf = given_xf
	xf = stage_xf
	info = stage_info


## true when a play of tl with opts can use this prep.
func matches(tl: CineTimeline, opts: Dictionary) -> bool:
	var ox: Variant = opts.get("xf")
	var same_xf: bool = typeof(ox) == typeof(opts_xf) and (typeof(ox) == TYPE_NIL or ox == opts_xf)
	return tl != null and tl.slot == slot and CineStage.signature(tl.stage) == stage_sig and same_xf
