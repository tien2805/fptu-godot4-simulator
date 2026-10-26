# File: res://scripts/story/missions/MissionForklift.gd
# Day 3 boss (spec C-D7 beat 9, C-D4): Alexander ABCXYZ on his forklift in the middle of the yard (GunFight boss wave:
# ForkliftBoss with Alexander's StoryCast body). He charges (telegraphed) and tosses crates; hit him while the forklift
# recovers or overheats; his endless-name intro refills a sliver of his bar (at most twice); at 0 the forklift topples.
# The parked forklift of the yard is hidden while he drives his own from the same spot. Down = "TOANG!", retry = a fresh
# boss. The win plays the beat's "after" cinematic seg_d3_boss (StoryRoam, at the yard's cine pad).
# points: start (+ start_yaw), boss_at, boss_yaw, ammo, centre, leash.
class_name MissionForklift
extends MissionLairFight


func _start() -> void:
	place_player()
	if level and level.has_method("set_parked_forklift"):
		level.call("set_parked_forklift", false)
	make_fight({"start_alerted": true})
	var at: Vector3 = pts.get("boss_at", player.global_position + Vector3(0.0, 0.0, -12.0) if player else Vector3.ZERO)
	var o: Dictionary = {"body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build("alexander")}
	fight.add_wave([{"boss": "forklift", "at": at, "yaw": float(pts.get("boss_yaw", 0.0)), "opts": o}])
	fight.start()
	radio("Con forklift có pattern đó e: nó lao xong là stun, burst damage lúc đó.", "Né cú lao, bắn lúc xe nâng khựng lại.")


func _lair_tick(_dt: float) -> void:
	if fight and fight.boss and int(clock * 10.0) % 3 == 0:
		var b: ForkliftBoss = fight.boss as ForkliftBoss
		set_info("Alexander: %d / %d" % [int(b.hp), int(b.max_hp)])


func _cleanup() -> void:
	super._cleanup()
	if state != "done" and level and is_instance_valid(level) and level.has_method("set_parked_forklift"):   # beaten: it stays gone
		level.call("set_parked_forklift", true)
