# File: res://scripts/story/StoryStage.gd
# Story missions inside stages (spec A2-D11): helpers the stages call when StageManager.story_context names them.
# Short replays (A2-D10, A1-D18 shared system): a CineReplayRecorder tracks the stage's actors from the start; at the
# winning moment the stage marks "blow", lets the action run REPLAY_AFTER s, then plays a CineReplay (4-6 s, the beat's
# replay music slot: owner file user://music/<slot>, else silent) before reporting the result.
# Outside the story nothing here runs and the stages behave exactly as before.
class_name StoryStage
extends RefCounted

const REPLAY_AFTER: float = 0.8
const REPLAY_LEN: float = 5.0


## The story context when it names `stage_id`, else {}.
static func context_for(stage_id: int) -> Dictionary:
	var c: Dictionary = StoryUtil.stage_context()
	if c.is_empty() or int(c.get("stage", -1)) != stage_id:
		return {}
	return c


static func in_story(stage_id: int) -> bool:
	return not context_for(stage_id).is_empty()


## A recorder under `parent` tracking `nodes` (nulls skipped).
static func make_recorder(parent: Node, nodes: Array) -> CineReplayRecorder:
	var rec := CineReplayRecorder.new()
	rec.name = "StoryReplayRecorder"
	rec.window = 8.0
	parent.add_child(rec)
	for n: Variant in nodes:
		if n is Node3D and is_instance_valid(n):
			rec.track(n)
	return rec


## Starts the replay (pauses the tree while it plays); null when there is no footage.
static func play_replay(parent: Node, rec: CineReplayRecorder, slot: String, focus: Node3D, other: Node3D = null, opts: Dictionary = {}) -> CineReplay:
	if rec == null or not is_instance_valid(rec) or rec.frame_count() < 2:
		return null
	var rp := CineReplay.new()
	rp.name = "StoryReplay"
	parent.add_child(rp)
	var o: Dictionary = opts.duplicate()
	o["slot"] = slot
	o["focus"] = focus
	if other:
		o["other"] = other
	o["length"] = float(o.get("length", REPLAY_LEN))
	if not rp.start(rec, o):
		rp.queue_free()
		return null
	return rp
