# File: res://scripts/story/missions/MissionCrates.gd
# Day 3 "Đập thùng kính" (spec C-D7 beat 7): destroy the crates of smart glasses (the yard's SmartCrates, shoot or hit
# them; a counter) before Alexander comes back with his forklift (TIME_S). Four guards carry one more crate on their
# shoulders round a loop in a coffin-dance parody (the swaying walk), with the meme music slot meme_coffin_dance (owner
# file, else silence) while their crate is whole; break it and they drop everything and run off, the mission track comes
# back. Every crate is a GunFight external target, so the fight's loadout, HUD and targets do the work and its `won` =
# every crate broken -> the short replay seg_d3_crates on the last one -> done {"all": true} (flag d3_all_crates: the
# optional E4 manifest). Time up -> done {"all": false} ("Alexander quay lại rồi!"), no replay.
# points: start (+ start_yaw), crates (SmartCrate nodes), dance (loop points), centre, leash.
class_name MissionCrates
extends MissionLairFight

const TIME_S: float = 90.0
const DANCE_SPEED: float = 1.1
const SWAY_HZ: float = 0.9
const T_DROPPED: String = "Rơi hòm rồi! Chạy thôi!"
const T_TIME_UP: String = "Alexander lái xe nâng quay lại rồi!"
const MUSIC_MEME: String = "meme_coffin_dance"

var crates: Array = []
var carried: SmartCrate
var dance: Node3D
var dancers: Array[Node3D] = []
var dance_pts: PackedVector3Array = PackedVector3Array()
var dance_s: float = 0.0
var dance_len: float = 0.0
var fleeing: float = -1.0
var time_left: float = TIME_S
var meme_on: bool = false


func _start() -> void:
	place_player()
	crates = (pts.get("crates", []) as Array).duplicate()
	_build_dance()
	make_fight({"start_alerted": true})
	var wave: Array = []
	for c: Variant in crates:
		wave.append({"target": c})
	wave.append({"target": carried})
	fight.add_wave(wave)
	rec = null
	fight.start()
	_track_all()
	_reset_dance()
	radio("Hàng fake đó e, destroy hết đi, cái hòm mấy ông kia khiêng cũng tính nha.", "Phá hết các thùng kính, cả cái hòm đang khiêng.")


## Every crate counts: the yard's crates plus the carried one.
func total() -> int:
	return crates.size() + 1


func broken_count() -> int:
	var n: int = 0
	for c: Variant in crates:
		if (c as SmartCrate).broken:
			n += 1
	return n + (1 if carried and carried.broken else 0)


func _build_dance() -> void:
	dance_pts.clear()
	dance_len = 0.0
	for p: Variant in pts.get("dance", []):
		var q: Vector3 = p
		q.y = ground_y(q)
		dance_pts.append(q)
	if dance_pts.size() >= 2:
		dance_pts.append(dance_pts[0])   # a loop
		for i: int in range(1, dance_pts.size()):
			dance_len += flat(dance_pts[i - 1], dance_pts[i])
	dance = Node3D.new()
	dance.name = "CoffinDance"
	add_child(dance)
	for i: int in 4:
		var b: Node3D = StoryCast.build(GUARD_IDS[i % 3])
		if b == null:
			continue
		dance.add_child(b)
		b.position = Vector3(-0.42 if i % 2 == 0 else 0.42, 0.0, -0.55 if i < 2 else 0.55)
		dancers.append(b)
	carried = SmartCrate.new()
	carried.setup({"carried": true, "name": "CarriedCrate"})
	dance.add_child(carried)
	carried.position = Vector3(0.0, 1.62, 0.0)
	carried.whole.scale = Vector3(1.0, 0.9, 1.9)   # a long box on four shoulders (the visual only: a body is never scaled)
	carried.ko.connect(_on_carried_broken)


func _reset_dance() -> void:
	dance_s = 0.0
	fleeing = -1.0
	dance.visible = true
	for b: Node3D in dancers:
		b.visible = true
		b.position.y = 0.0
		CharacterBuilder.set_speed(b, DANCE_SPEED)
	_place_dance(0.0)
	_set_meme(true)
	time_left = TIME_S


## The recorder tracks the player, the dance and every crate's planks (the replay shows the last one breaking).
func _track_all() -> void:
	var nodes: Array = [player, dance]
	for c: Variant in crates + [carried]:
		for d: MeshInstance3D in (c as SmartCrate).debris:
			nodes.append(d)
	rec = StoryStage.make_recorder(self, nodes)


func _on_wave_started(_i: int) -> void:
	pass   # the recorder runs from the start (one wave)


func _on_enemy_ko(e: Node3D) -> void:
	last_ko = e
	if fight and fight.alive().is_empty() and rec:
		rec.mark("blow")


func _on_fight_won() -> void:
	won_info = {"all": true, "broken": broken_count()}
	_set_meme(false)
	if rec and String(beat.get("replay", "")) != "":
		replay_wait = StoryStage.REPLAY_AFTER
	else:
		finish(won_info)


func _on_carried_broken(_c: Node3D) -> void:
	popup(T_DROPPED, 2.0, WARN)
	fleeing = 0.0
	_set_meme(false)
	for b: Node3D in dancers:
		CharacterBuilder.set_speed(b, 4.5)


func _set_meme(on: bool) -> void:
	if on == meme_on:
		return
	meme_on = on
	cues_played.append(MUSIC_MEME if on else "mission_gunfight")
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_play"):
		fx.call("music_play", MUSIC_MEME if on else "mission_gunfight", 0.6)


func _lair_tick(dt: float) -> void:
	time_left -= dt
	set_info("Thùng kính: %d / %d · Còn %d s" % [broken_count(), total(), maxi(0, ceili(time_left))])
	set_meter(clampf(time_left / TIME_S * 100.0, 0.0, 100.0))
	if fleeing >= 0.0:
		fleeing += dt
		var away := Vector3(-1.0, 0.0, 0.3).normalized()
		dance.global_position += away * 4.5 * dt
		if fleeing > 3.5:
			dance.visible = false
	elif dance_len > 0.0:
		dance_s = fmod(dance_s + DANCE_SPEED * dt, dance_len)
		_place_dance(clock)
	if time_left <= 0.0:
		popup(T_TIME_UP, 2.0, WARN)
		_set_meme(false)
		if fight:
			fight.stop()
		finish({"all": false, "broken": broken_count()})


## The dance at loop distance dance_s, facing along the loop, the coffin-dance sway (side to side, a little bob).
func _place_dance(t: float) -> void:
	if dance_pts.size() < 2:
		return
	var s: float = dance_s
	for i: int in range(1, dance_pts.size()):
		var seg: float = flat(dance_pts[i - 1], dance_pts[i])
		if s <= seg or i == dance_pts.size() - 1:
			var u: float = clampf(s / maxf(seg, 0.01), 0.0, 1.0)
			var p: Vector3 = dance_pts[i - 1].lerp(dance_pts[i], u)
			var dir: Vector3 = dance_pts[i] - dance_pts[i - 1]
			var yaw: float = yaw_of(dir)
			var side := Vector3(cos(yaw), 0.0, -sin(yaw))
			var sway: float = sin(t * TAU * SWAY_HZ) * 0.22
			dance.global_position = p + side * sway + Vector3(0.0, absf(sin(t * TAU * SWAY_HZ)) * 0.05, 0.0)
			dance.rotation.y = yaw + sin(t * TAU * SWAY_HZ) * 0.12
			return
		s -= seg


func _reset() -> void:
	super._reset()
	_reset_dance()


func _cleanup() -> void:
	_set_meme(false)
	super._cleanup()
