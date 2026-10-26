# File: res://scripts/cine/CinePrep.gd
# A cinematic prepared ahead (plan 2026-10-26-cine-transition): FreeRoam.prepare_cinematic creates one as its child with the
# timeline and the resolved stage frame; it builds the timeline's actors one per frame (CineActor.setup with the clone
# cache: seeded duplicates are cloned from the first one) under itself, hidden. Building only runs while the tree is not
# paused (the node inherits FreeRoam's pausable process mode), so it never stutters a cinematic, the 3 a.m. call or the
# owner's video. play_cinematic adopts the actors (take_actors) when the slot and the stage match; whatever is not built
# yet is built by CinePlayer.setup. Nothing is allocated per frame beyond the actor builds; processing stops when done.
class_name CinePrep
extends Node3D

var slot: String = ""
var timeline: CineTimeline = null
var stage_sig: String = ""
## Resolved stage frame (Transform3D) or null (no clear spot: play_cinematic decides).
var xf: Variant = null
## FreeRoam.cine_stage_info of that resolution (play_cinematic reports it when it adopts this prep).
var info: Dictionary = {}
## actor id -> CineActor (setup done, no cues yet), in timeline order.
var actors: Dictionary = {}
## Builds done so far (tests: one per unpaused frame).
var built: int = 0
var _ids: Array[String] = []
var _templates: Dictionary = {}   # CineActor.clone_key -> first CineActor built with those opts


## Start preparing tl at stage frame stage_xf (Transform3D or null).
func begin(tl: CineTimeline, stage_xf: Variant) -> void:
	name = "CinePrep"
	timeline = tl
	slot = tl.slot
	stage_sig = CineStage.signature(tl.stage)
	xf = stage_xf
	visible = false
	for id: String in tl.actors.keys():
		_ids.append(id)
	set_process(not _ids.is_empty())


func done() -> bool:
	return built >= _ids.size()


func _process(_d: float) -> void:
	if done():
		set_process(false)
		return
	var id: String = _ids[built]
	var o: Dictionary = timeline.actors[id]["opts"]
	var key: String = CineActor.clone_key(o)
	var a := CineActor.new()
	a.name = id
	add_child(a)
	a.setup(o, _templates.get(key))
	if key != "" and not _templates.has(key):
		_templates[key] = a
	actors[id] = a
	built += 1


## The built actors (id -> CineActor), handed over once: the caller reparents them; the rest stay to be freed with this node.
func take_actors() -> Dictionary:
	var out: Dictionary = actors
	actors = {}
	_templates.clear()
	set_process(false)
	return out
