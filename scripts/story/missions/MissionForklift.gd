# File: res://scripts/story/missions/MissionForklift.gd
# Day 3 boss (spec C-D7 beat 9, C-D4): Alexander ABCXYZ on his forklift in the middle of the yard (GunFight boss wave:
# ForkliftBoss with Alexander's StoryCast body). He charges (telegraphed) and tosses crates; hit him while the forklift
# recovers or overheats; his endless-name intro refills a sliver of his bar (at most twice); at 0 the forklift topples.
# The parked forklift of the yard is hidden while he drives his own from the same spot. Down = "TOANG!", retry = a fresh
# boss. The win plays the beat's "after" cinematic seg_d3_boss (StoryRoam, at the yard's cine pad).
# W3 T7 (plan 2026-10-30-w3-day3.md, D3W-3): THE FORKLIFT JOUST. The player has a forklift of his own (PlayerForklift:
# [F] in / out, WASD, [Q] / [E] forks, [Chuột trái] throws the crate on the forks): a side / back ram while his forks are
# up (the yellow beacon before a toss) takes 15 % of his bar, a front ram bounces both; his tossed crates lie on the floor
# for a while: lift one and throw it back. On foot the old rules still work. The arena crane (YardCrane, one drop): a
# container on him while he is stalled = ForkliftBoss.crush(), the next phase (done info "crane"). Boss HP through
# Difficulty. Retry resets both forklifts and the crane.
# points: start (+ start_yaw), boss_at, boss_yaw, fork_at, fork_yaw, ammo, centre, leash.
class_name MissionForklift
extends MissionLairFight

var pf: PlayerForklift = null
var crane: YardCrane = null
var crushed: bool = false
## T10: Alexander (red) and the player's forklift while on foot (yellow) stay findable; the objective line.
var markers: OffscreenMarkers = null
var _info_pct: int = -1


func _init() -> void:
	armed = true
	keep_top = true


func _start() -> void:
	place_player()
	if level and level.has_method("set_parked_forklift"):
		level.call("set_parked_forklift", false)
	make_fight({"start_alerted": true})
	var at: Vector3 = pts.get("boss_at", player.global_position + Vector3(0.0, 0.0, -12.0) if player else Vector3.ZERO)
	var o: Dictionary = {"body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build("alexander"),
		"hp": float(Difficulty.pick(GunData.BOSS_HP, GunData.BOSS_HP * 0.8)), "joust": true}
	fight.add_wave([{"boss": "forklift", "at": at, "yaw": float(pts.get("boss_yaw", 0.0)), "opts": o}])
	fight.start()
	if pts.has("fork_at"):
		pf = PlayerForklift.new()
		add_child(pf)
		pf.setup(fight, pts["fork_at"], float(pts.get("fork_yaw", 0.0)))
		pf.rammed.connect(_on_rammed)
	if level:
		crane = YardCrane.new()
		add_child(crane)
		crane.setup((level as Node3D).global_transform, fight, 1, 2.0, 2.0)
		crane.dropped.connect(_on_crane_dropped)
	markers = OffscreenMarkers.make(hud, player)
	if pf:
		markers.track(pf.forklift, "prompt", "Xe nâng", 2.6)
	_track_boss()
	radio("Lấy con xe nâng cắm chìa lúc nãy kìa e, F lên xe. Nó đứng hình hay giơ càng lên là húc hông nó!", "Lên xe nâng [F]. Khi nó SƠ HỞ hoặc giơ càng, húc vào hông.", 6.0)


func _track_boss() -> void:
	var b: ForkliftBoss = fight.boss as ForkliftBoss if fight and fight.boss else null
	if markers and b:
		markers.track(b.forklift, "threat", "Alexander", 3.0)


## A retry spawns a fresh boss: the marker follows it.
func _on_wave_started(i: int) -> void:
	super._on_wave_started(i)
	_track_boss()


func _lair_tick(dt: float) -> void:
	if pf:
		pf.step(dt)
	if crane:
		crane.step(dt)
	var h: String = pf.hint() if pf and pf.hint() != "" else (crane.hint() if crane else "")
	set_prompt(h)
	if markers and pf:
		markers.set_on(pf.forklift, not pf.inside)
	if fight and fight.boss:
		var b: ForkliftBoss = fight.boss as ForkliftBoss
		var pct: int = ceili(b.hp / maxf(b.max_hp, 1.0) * 100.0)
		if pct != _info_pct:
			_info_pct = pct
			set_info("Húc hông xe Alexander khi nó SƠ HỞ hoặc giơ càng · còn %d%%" % pct)


func _on_rammed(_target: Node3D, _power: float) -> void:
	popup("Húc hông! Trúng rồi!", 1.4)
	if has_method("add_stat"):
		call("add_stat", "rams")


## The arena crane's one container: on him while he is stalled = the next phase.
func _on_crane_dropped(_pos: Vector3, _kos: int) -> void:
	var b: ForkliftBoss = fight.boss as ForkliftBoss if fight and fight.boss else null
	if b == null or not crane.footprint_has(b.forklift.global_position):
		return
	if b.crush():
		crushed = true
		popup("Container đè xe nâng! Qua phase!", 2.0)
		radio("Ủa alo? Container rơi trúng đầu luôn, nerf quá nerf.", "Thả trúng rồi!", 3.5)
		if has_method("add_stat"):
			call("add_stat", "crane_kos")


func _on_fight_won() -> void:
	if pf:
		pf.leave()
	if crane:
		crane.leave()
	won_info = {"ko": fight.ko_total, "crane": crushed}
	finish(won_info)


func _reset() -> void:
	if pf:
		pf.reset()
	if crane:
		crane.reset()
	crushed = false
	super._reset()


func _cleanup() -> void:
	if pf and is_instance_valid(pf):
		pf.leave()
	if crane and is_instance_valid(crane):
		crane.leave()
	super._cleanup()
	if state != "done" and level and is_instance_valid(level) and level.has_method("set_parked_forklift"):   # beaten: it stays gone
		level.call("set_parked_forklift", true)
