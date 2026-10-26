# File: res://scripts/story/missions/MissionGunfight.gd
# The lair gunfights in two waves (spec C-D7 beat 6 in the yard, C-D8 beat 5 in the basement): Alexander's / Za Mẫn's
# guards, alerted, in cover, at most 3 shooting; ammo pickups from the level. Down = "TOANG!", retry = the wave in progress
# again from its checkpoint. The last knockout is replayed (seg_d3_gunfight / seg_d5_gunfight), then done.
# points: start (+ start_yaw), waves ([[Vector3...], [Vector3...]]), ammo, centre, leash.
class_name MissionGunfight
extends MissionLairFight


func _start() -> void:
	place_player()
	make_fight({"start_alerted": true})
	var i: int = 0
	for w: Variant in pts.get("waves", []):
		var wave: Array = []
		for at: Variant in w:
			wave.append(guard(i, at))
			i += 1
		fight.add_wave(wave)
	fight.start()
	if String(beat.get("lair", "")) == "basement":
		radio("Guard spawn ở cầu thang kìa e, dùng cover đi, đừng face tank.", "Núp sau tủ máy mà bắn.")
	else:
		radio("Wave guard incoming e ơi, hold Ctrl núp sau thùng rồi pop ra bắn.", "Giữ Ctrl để núp, nhắm bắn từng đứa.")


func _lair_tick(_dt: float) -> void:
	if fight and int(clock * 10.0) % 3 == 0:
		set_info("Đợt %d/%d · Còn %d bảo vệ" % [fight.wave + 1, fight.waves.size(), fight.enemies_left()])
