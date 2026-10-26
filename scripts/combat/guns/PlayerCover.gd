# File: res://scripts/combat/guns/PlayerCover.gd
# The player's cover in a lair gunfight (spec C-D2; C is the camera orbit, so cover is on Ctrl):
#   - hold Ctrl within GunData.COVER_ENTER_R of a free CoverMap slot (on the ground, on foot, not knocked down or out of
#     the fight): the player snaps to the slot and crouches behind the obstacle facing it (GunPose "cover_crouch");
#     walking is locked (ThirdPersonController.move_lock), the camera still turns;
#   - aiming (right mouse, WeaponDirector) pops out: the player stands and is exposed; a shot fired without aiming keeps the
#     player exposed GunData.EXPOSE_AFTER_FIRE_S;
#   - releasing Ctrl, a jump, a knock-down, being blocked (bike, cinematic, hidden) or `enabled = false` leaves the cover.
# Enemy bullets aim at target_point(): chest height when exposed; crouched, GunData.TARGET_CROUCH_Y but at least
# COVER_TARGET_BELOW under the obstacle's top (so the obstacle really stops them). The slot is marked in the shared `taken`
# Dictionary (slot -> occupant) so no gunman takes it. Only a slot the player can walk to in a straight line (reach_fn:
# GunFight.clear_walk; never across a wall or the box itself) is offered: prompt_slot = the nearest such free slot, the one
# the HUD prompts "[Ctrl] nấp" for (re-checked at 10 Hz). Test hook: hold_override (bool = Ctrl held, null = key).
class_name PlayerCover
extends Node

signal entered(slot: int)
signal left

var player: ThirdPersonController
var weapons: WeaponDirector
var combat: PlayerCombat
var map: CoverMap
var taken: Dictionary = {}
var enabled: bool = true
var hold_override: Variant = null
## (from: Vector3, to: Vector3) -> bool: the player can walk the straight line (GunFight.clear_walk); empty = always.
var reach_fn: Callable = Callable()
var in_cover: bool = false
var slot: int = -1
var prompt_slot: int = -1
var pose: GunPose
var entries: int = 0
var _since_fire: float = 99.0
var _prompt_t: float = 0.0


func _ready() -> void:
	process_physics_priority = 6         # after the controller (0) and PlayerCombat (5): the spot and facing win


## p: the player; cover_map; w: WeaponDirector (optional: shots expose); c: PlayerCombat (optional: down leaves cover);
## taken_dict: slot occupancy shared with the gunmen.
func setup(p: ThirdPersonController, cover_map: CoverMap, w: WeaponDirector, c: PlayerCombat, taken_dict: Dictionary) -> void:
	player = p
	map = cover_map
	weapons = w
	combat = c
	taken = taken_dict
	if player and player.model:
		pose = GunPose.attach(player.model)
	if weapons and not weapons.fired.is_connected(_on_fired):
		weapons.fired.connect(_on_fired)


func _on_fired(_slot: int) -> void:
	_since_fire = 0.0


func _exit_tree() -> void:
	leave()
	if pose and is_instance_valid(pose):
		pose.queue_free()
	if weapons and is_instance_valid(weapons) and weapons.fired.is_connected(_on_fired):
		weapons.fired.disconnect(_on_fired)


func _hold() -> bool:
	if hold_override is bool:
		return hold_override
	return player.controls_enabled and Input.is_physical_key_pressed(KEY_CTRL)


func can_cover() -> bool:
	if not enabled or map == null or player == null or not player.visible:
		return false
	if player.is_knocked_down() or (combat != null and combat.is_down()):
		return false
	if weapons != null and weapons.is_blocked():
		return false
	return player.move_state == "GROUND" or player.move_state == "LAND_SOFT"


func _physics_process(delta: float) -> void:
	_since_fire += delta
	if player == null or not is_instance_valid(player):
		return
	var can: bool = can_cover()
	var hold: bool = _hold()
	if in_cover:
		prompt_slot = -1
		if not hold or not can:
			leave()
		else:
			_hold_spot()
	else:
		_prompt_t -= delta
		if not can:
			prompt_slot = -1
		elif _prompt_t <= 0.0 or (prompt_slot >= 0 and taken.has(prompt_slot) and taken[prompt_slot] != player):
			_prompt_t = GunData.RAY_DT
			prompt_slot = _reachable_slot()
		if hold and prompt_slot >= 0:
			enter(prompt_slot)
	_apply_pose()


## The nearest free slot within COVER_ENTER_R the player can walk to (-1 = none).
func _reachable_slot() -> int:
	var p: Vector3 = player.global_position
	for i: int in map.near_ids(p, GunData.COVER_ENTER_R, taken, player):
		if not reach_fn.is_valid() or bool(reach_fn.call(p, map.pos[i])):
			return i
	return -1


func enter(i: int) -> void:
	if map == null or i < 0 or i >= map.count():
		return
	if in_cover:
		leave()
	in_cover = true
	slot = i
	taken[i] = player
	entries += 1
	player.move_lock = true
	var p: Vector3 = map.pos[i]
	player.global_position = Vector3(p.x, player.global_position.y, p.z)
	player.velocity = Vector3(0.0, minf(player.velocity.y, 0.0), 0.0)
	_face_obstacle()
	entered.emit(i)


func leave() -> void:
	if not in_cover:
		return
	in_cover = false
	if taken.get(slot) == player:
		taken.erase(slot)
	slot = -1
	if player and is_instance_valid(player):
		player.move_lock = false
	if pose and is_instance_valid(pose):
		pose.clear()
	left.emit()


## Exposed to enemy fire: out of cover, aiming from it, or just fired from it.
func exposed() -> bool:
	return not in_cover or (player != null and player.aiming) or _since_fire < GunData.EXPOSE_AFTER_FIRE_S


## Crouched behind the obstacle (not exposed).
func hidden() -> bool:
	return in_cover and not exposed()


## Where enemy bullets aim.
func target_point() -> Vector3:
	if hidden():
		var y: float = minf(GunData.TARGET_CROUCH_Y, map.height[slot] - GunData.COVER_TARGET_BELOW)
		return player.global_position + Vector3(0.0, y, 0.0)
	return player.global_position + Vector3(0.0, GunData.TARGET_STAND_Y, 0.0)


func _hold_spot() -> void:
	var p: Vector3 = map.pos[slot]
	player.global_position = Vector3(p.x, player.global_position.y, p.z)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	if not exposed():
		_face_obstacle()


func _face_obstacle() -> void:
	if player.model == null or slot < 0:
		return
	var n: Vector3 = map.normal[slot]
	player.model.rotation.y = atan2(n.x, n.z)   # facing -normal (towards the obstacle)


func _apply_pose() -> void:
	if pose == null:
		return
	if hidden():
		pose.set_pose("cover_crouch")
	elif pose.pose_name == "cover_crouch":
		pose.clear()
