# File: res://scripts/weapons/WeaponWheel.gd
# The weapon wheel (spec W-D1, section 2): a RadialWheel with the 8 WeaponData slots (W-D4 order) and their code-drawn
# icons, opened by holding the middle mouse button; mouse-wheel scroll cycles the weapons; inside the dead zone the
# equipped weapon stays highlighted; the centre shows the name and the ammo (info_fn, set by WeaponDirector).
class_name WeaponWheel
extends RadialWheel


func _init() -> void:
	trigger_mouse = MOUSE_BUTTON_MIDDLE
	scroll_cycles = true
	keep_current = true
	for i: int in WeaponData.COUNT:
		slots.append({"name": WeaponData.name_of(i), "icon": i, "enabled": true})
