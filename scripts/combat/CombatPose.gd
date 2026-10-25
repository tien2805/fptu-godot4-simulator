# File: res://scripts/combat/CombatPose.gd
# Code-pose layer of the Phase B combat (B-D1 / B-D2) on a rigged CharacterBuilder body: one CombatData.pose() at a time
# (guard, block, brace, wind-up, dazed, taunt, side-step lean, hip throw) laid over whatever the body's AnimationPlayer and
# RigAnimator wrote this frame, with a weight eased in and out (EASE per second). Runs after the RigAnimator
# (process_priority 11 > 10) and writes the bones through CharacterBuilder._apply_bone_pose, the single place of that
# maths. A pose either holds (u fixed), loops (loop_s > 0: u = phase) or plays once (play_s > 0: u runs 0..1, then the
# layer eases out). Nothing is written while the weight is 0. Owner: PlayerCombat (player) or MeleeEnemy (its body).
class_name CombatPose
extends Node

const EASE: float = 12.0

var skeleton: Skeleton3D
var pose_name: String = ""
var u: float = 0.0
var weight: float = 0.0
var target_w: float = 0.0
var loop_s: float = 0.0
var play_s: float = 0.0


func _ready() -> void:
	process_priority = 11


## Attach to a rigged body (CharacterBuilder.build rigged): the layer is a child of the body root. null without a skeleton.
static func attach(body: Node3D) -> CombatPose:
	var sk: Skeleton3D = body.get_meta("skeleton", null) as Skeleton3D if body else null
	if sk == null:
		return null
	var p := CombatPose.new()
	p.name = "CombatPose"
	p.skeleton = sk
	body.add_child(p)
	return p


## Hold a pose (u fixed), loop it (loop_secs > 0) or play it once over play_secs (> 0).
func set_pose(p: String, loop_secs: float = 0.0, play_secs: float = 0.0, u0: float = 0.5) -> void:
	if p == pose_name and target_w > 0.0 and loop_secs == loop_s and play_secs <= 0.0:
		return
	pose_name = p
	loop_s = loop_secs
	play_s = play_secs
	u = 0.0 if (loop_secs > 0.0 or play_secs > 0.0) else u0
	target_w = 1.0


func clear() -> void:
	target_w = 0.0
	play_s = 0.0


## Drop the layer at once (teleport / retry).
func reset() -> void:
	target_w = 0.0
	weight = 0.0
	pose_name = ""
	play_s = 0.0


func active() -> bool:
	return target_w > 0.0 and pose_name != ""


func _process(delta: float) -> void:
	if skeleton == null or pose_name == "":
		return
	if loop_s > 0.0:
		u = fposmod(u + delta / loop_s, 1.0)
	elif play_s > 0.0:
		u += delta / play_s
		if u >= 1.0:
			u = 1.0
			target_w = 0.0
	weight = move_toward(weight, target_w, EASE * delta)
	if weight <= 0.001:
		if target_w <= 0.0:
			pose_name = ""
		return
	var cp: Dictionary = CombatData.pose(pose_name, u)
	if not cp.is_empty():
		CharacterBuilder._apply_bone_pose(skeleton, cp, weight)
