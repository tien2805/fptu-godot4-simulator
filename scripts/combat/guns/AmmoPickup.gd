# File: res://scripts/combat/guns/AmmoPickup.gd
# An ammo pickup of the lair gunfights (spec C-D2): a code-built olive ammo box that bobs and turns; the player walking
# within GunData.PICKUP_R takes it: `amount` spare rounds for `slot` (WeaponDirector.add_reserve), a toast "+24 viên Súng
# lục", a reload sound, and the box hides. GunFight owns the pickups (reset() on retry from a checkpoint taken before it).
class_name AmmoPickup
extends Node3D

signal picked(p: AmmoPickup)

var slot: int = WeaponData.Slot.PISTOL
var amount: int = 24
var taken: bool = false
var fight: Object = null
var model: Node3D
var _t: float = 0.0


func setup(f: Object, s: int, n: int) -> void:
	fight = f
	slot = s
	amount = n


func _ready() -> void:
	model = GunProps.ammo_box()
	add_child(model)
	Readability.rim(model, "pickup")   # Q3 rim


func reset() -> void:
	taken = false
	visible = true


func _physics_process(delta: float) -> void:
	if taken or fight == null:
		return
	_t += delta
	if String(fight.get("state")) != "running":
		return
	model.position.y = 0.15 + 0.08 * sin(_t * 3.0)
	model.rotation.y = _t * 1.6
	var pl: Node3D = fight.get("player")
	if pl == null or not pl.visible:
		return
	if WeaponMath.flat(pl.global_position, global_position) <= GunData.PICKUP_R and absf(pl.global_position.y - global_position.y) < 1.5:
		take()


func take() -> void:
	if taken:
		return
	taken = true
	visible = false
	if fight and fight.has_method("on_pickup"):
		fight.call("on_pickup", self)
	picked.emit(self)
