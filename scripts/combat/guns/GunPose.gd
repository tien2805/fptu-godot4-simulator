# File: res://scripts/combat/guns/GunPose.gd
# Code-pose layer of the Phase C gunfights on a rigged CharacterBuilder body (the CombatPose pattern with the GunData
# library): one pose at a time (crouch behind cover, pistol aim, dazed, driving, the name speech) laid over whatever the
# body's AnimationPlayer, RigAnimator and an earlier CombatPose wrote this frame, with a weight eased in and out (EASE per
# second). process_priority 12: after the RigAnimator (10) and CombatPose (11). Writes the bones through
# CharacterBuilder._apply_bone_pose. A pose holds (u fixed) or loops (loop_s > 0). Nothing is written while the weight is 0.
class_name GunPose
extends Node

const EASE: float = 10.0

var skeleton: Skeleton3D
var pose_name: String = ""
var u: float = 0.0
var weight: float = 0.0
var target_w: float = 0.0
var loop_s: float = 0.0


func _ready() -> void:
	process_priority = 12


## Attach to a rigged body: the layer is a child of the body root. A layer that writes nothing without a skeleton.
static func attach(body: Node3D) -> GunPose:
	var p := GunPose.new()
	p.name = "GunPose"
	p.skeleton = body.get_meta("skeleton", null) as Skeleton3D if body else null
	if body:
		body.add_child(p)
	return p


func set_pose(p: String, loop_secs: float = 0.0) -> void:
	if p == pose_name and target_w > 0.0 and loop_secs == loop_s:
		return
	if p != pose_name:
		weight = minf(weight, 0.35)          # a new pose blends in from a little of the old one
	pose_name = p
	loop_s = loop_secs
	u = 0.0 if loop_secs > 0.0 else 0.5
	target_w = 1.0


func clear() -> void:
	target_w = 0.0


## Drop the layer at once (retry / knock-out).
func reset() -> void:
	target_w = 0.0
	weight = 0.0
	pose_name = ""


func active() -> bool:
	return target_w > 0.0 and pose_name != ""


func _process(delta: float) -> void:
	if skeleton == null or pose_name == "":
		return
	if loop_s > 0.0:
		u = fposmod(u + delta / loop_s, 1.0)
	weight = move_toward(weight, target_w, EASE * delta)
	if weight <= 0.001:
		if target_w <= 0.0:
			pose_name = ""
		return
	var cp: Dictionary = GunData.pose(pose_name, u)
	if not cp.is_empty():
		CharacterBuilder._apply_bone_pose(skeleton, cp, weight)
