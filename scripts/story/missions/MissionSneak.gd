# File: res://scripts/story/missions/MissionSneak.gd
# The lair sneaks (spec C-D7 beat 3, C-D8 beat 3): Day 3 into the container yard (mission "sneak"), Day 5 through the
# server hall (lair task "stealth"). Guards patrol (GunFight wave 1, not alerted) with the horror toolkit's sight rules
# while they patrol (HorrorStalker.SIGHT 14 m, a 70 deg cone, a clear ray; noise from sprinting / jogging / gunfire as
# GunFight hears it). Goal: reach points.goal (the mannequin stack / the server room's mouth) unseen -> done
# {"spotted": false}. Being seen (GunFight `spotted`) starts the gunfight early: every guard is alerted and the beat ends at
# the goal once they are all knocked out -> done {"spotted": true}. Down = "TOANG!", retry = the patrol again from the
# start, unalerted. Anh Duy talks the player in on the radio.
class_name MissionSneak
extends MissionLairFight

const FOV_DEG: float = 70.0
const T_SPOTTED: String = "Bị phát hiện! Đánh luôn!"
const T_GOAL_CLEAR: String = "Dọn sạch rồi. Tới chỗ cần tới đi!"

var spotted: bool = false
var cleared_said: bool = false


func _start() -> void:
	place_player()
	make_fight({"start_alerted": false})
	var wave: Array = []
	var i: int = 0
	for p: Array in pts.get("patrols", []):
		wave.append(guard(i, p[0], p[1], {"sight_m": HorrorStalker.SIGHT, "fov_deg": FOV_DEG, "alerted": false}))
		i += 1
	fight.add_wave(wave)
	fight.spotted.connect(_on_spotted)
	fight.start()
	if pts.has("goal"):
		goal_marker(pts["goal"], float(pts.get("goal_r", 2.5)) * 0.6)
	_reset_state()
	if String(beat.get("lair", "")) == "basement":
		radio("A loop camera hầm r, e đi stealth qua mấy con guard, đừng để aggro nhé.", "Đi nhẹ thôi, đừng để bảo vệ thấy.")
	else:
		radio("A mute camera bến r, e lách qua mấy con guard, target là cái container giữa bãi.", "Lẻn tới container giữa bãi, đừng để bị thấy.")


func _reset_state() -> void:
	spotted = false
	cleared_said = false
	set_info("Đi lén, đừng để bảo vệ thấy")
	set_prompt("Tới chỗ cột sáng xanh")


func _on_spotted(_g: Node3D) -> void:
	if spotted or state != "running":
		return
	spotted = true
	popup(T_SPOTTED, 2.0, WARN)
	radio("Toang r e, combat mode thôi!", "Bị lộ rồi, đánh đi!", 3.5)
	for e: Variant in fight.alive():
		if e is Gunman:
			(e as Gunman).alert(player.global_position)


func _on_fight_won() -> void:
	pass   # the patrol is down: the beat still ends at the goal


func _lair_tick(_dt: float) -> void:
	if spotted:
		var left: int = fight.alive().size() if fight else 0
		set_info("Bị lộ! Còn %d bảo vệ" % left if left > 0 else T_GOAL_CLEAR)
		if left > 0:
			return
		if not cleared_said:
			cleared_said = true
			popup(T_GOAL_CLEAR, 2.0)
	if player and pts.has("goal") and flat(player.global_position, pts["goal"]) <= float(pts.get("goal_r", 2.5)):
		finish({"spotted": spotted})


func _reset() -> void:
	super._reset()
	_reset_state()
