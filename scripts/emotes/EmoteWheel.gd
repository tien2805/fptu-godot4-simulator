# File: res://scripts/emotes/EmoteWheel.gd
# The emote wheel (spec W-D10, section 9): the shared RadialWheel opened by holding B; slot 0 "Siuuu!", slots 1-7 greyed
# "Sắp có" (a new emote later = one EmoteDirector.EMOTES entry plus its animation). Nothing is highlighted in the dead zone
# and any highlighted slot plays on release (keep_current off); no scroll cycling.
class_name EmoteWheel
extends RadialWheel


func _init() -> void:
	trigger_key = KEY_B
	keep_current = false
	scroll_cycles = false
	hint = "Thả B trên một ô để diễn"
	icon_fn = func(ci: CanvasItem, icon: int, c: Vector2, s: float, col: Color, dark: Color) -> void: EmoteIcons.draw(ci, icon, c, s, col, dark)
	for i: int in 8:
		if i < EmoteDirector.EMOTES.size():
			slots.append({"name": String(EmoteDirector.EMOTES[i]["name"]), "icon": i, "enabled": true})
		else:
			slots.append({"name": RadialWheel.SOON, "icon": -1, "enabled": false})
