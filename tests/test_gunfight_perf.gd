# File: res://tests/test_gunfight_perf.gd
# Phase C performance gate (spec C-D13, the lair-gunfight case): a test arena (floor, eight low cover boxes in front of the
# player, one beside him) with a GunFight of 8 alerted gunmen plus the forklift boss (AI on: driving, charging, tossing
# crates) in the first wave (tough enough not to fall) and 4 more gunmen queued in a second wave; the player (god mode) crouches in cover, pops out to aim every second and fires while aiming.
# After a settle (the gunmen in cover, peeking and shooting) one measured window of 120 physics frames against a baseline
# with the fight disabled (its gunmen, HUD and player cover; the player's cover pose too). Gate: the fight's cost < 3 ms per
# physics frame by the MEDIAN and by the 5 %-TRIMMED MEAN (the test_combat_perf method: from the physics_frame signal to a
# tail node that runs after every _physics_process, the phase-change frame dropped). The process-frame cost (HUD, poses)
# is measured the same way and gated too. Also: no GPUParticles3D, Engine.time_scale 1.0. Prints the numbers.
# Wave 3 (plan 2026-10-30-w3-shared.md perf gates): the player leaves cover at the window's start and a bullet-time dive
# (72 frames at 0.35x, then prone) runs inside the measured window, with the Thường cap of 4 shooters.
# Run:  godot --headless --path . --script tests/test_gunfight_perf.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const GATE_MS: float = 3.0
const WINDOW: int = 120

## Runs AFTER every other _physics_process / _process.
class Tail extends Node:
	var on_tail: Callable
	var physics: bool = true

	func _physics_process(_d: float) -> void:
		if physics:
			on_tail.call()

	func _process(_d: float) -> void:
		if not physics:
			on_tail.call()


var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var combat: PlayerCombat
var fight: GunFight
var targets: Array = []
var timing: bool = false
var _pt0: int = 0
var _qt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var psamples: PackedInt32Array = PackedInt32Array()
var medians: Array[float] = []
var trimmed: Array[float] = []
var pmedians: Array[float] = []
var ptrimmed: Array[float] = []
var shots0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	WeaponAudio.sfx_dir = "user://__test_no_sfx__/"
	print("--- TEST GUNFIGHT PERFORMANCE GATE ---")
	var tail := Tail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = _tail
	root.add_child(tail)
	var ptail := Tail.new()
	ptail.name = "ProcTail"
	ptail.physics = false
	ptail.process_priority = 1 << 30
	ptail.on_tail = _ptail
	root.add_child(ptail)
	physics_frame.connect(_on_physics)
	process_frame.connect(func() -> void: _qt0 = Time.get_ticks_usec())


func _tail() -> void:
	if timing:
		samples.append(Time.get_ticks_usec() - _pt0)


func _ptail() -> void:
	if timing:
		psamples.append(Time.get_ticks_usec() - _qt0)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _start_window() -> void:
	samples.clear()
	psamples.clear()
	timing = true


func _end_window() -> void:
	timing = false
	for pair: Array in [[samples, medians, trimmed], [psamples, pmedians, ptrimmed]]:
		var s: PackedInt32Array = pair[0]
		var sorted: PackedInt32Array = s.duplicate()
		sorted.sort()
		if sorted.is_empty():
			(pair[1] as Array).append(0.0)
			(pair[2] as Array).append(0.0)
			continue
		(pair[1] as Array).append(float(sorted[sorted.size() / 2]))
		(pair[2] as Array).append(trimmed_mean(sorted, 0.05))


static func trimmed_mean(sorted: PackedInt32Array, frac: float) -> float:
	var k: int = int(floor(float(sorted.size()) * frac))
	var n: int = sorted.size() - 2 * k
	if n <= 0:
		return float(sorted[sorted.size() / 2])
	var t: int = 0
	for i: int in range(k, k + n):
		t += sorted[i]
	return float(t) / float(n)


func _build() -> void:
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena, 400.0)
	var cm := CoverMap.new()
	var boxes: Array = [[Vector3(0.0, 0.5, -1.6), Vector3(2.0, 1.0, 0.8)]]
	for i: int in 8:
		var x: float = -14.0 + 4.0 * float(i)
		boxes.append([Vector3(x, 0.5, -13.0 - 2.0 * float(i % 3)), Vector3(2.2, 1.0, 0.8)])
	for b: Array in boxes:
		World.wall(arena, b[0], b[1])
		cm.add_box(Transform3D(Basis.IDENTITY, b[0]), b[1])
	player = World.player(arena, Vector3(0.5, 0.0, 0.0), 0.0)
	dir = World.director(arena, player, targets)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	combat.setup({"player": player, "weapons": dir})
	combat.god = true
	fight = GunFight.new()
	fight.name = "PerfFight"
	arena.add_child(fight)
	fight.setup({"player": player, "weapons": dir, "combat": combat, "cover": cm, "seed": 21, "accuracy_override": 0.25,
		"reserve": {WeaponData.Slot.PISTOL: -1, WeaponData.Slot.SHOTGUN: -1}})
	var w1: Array = []
	for i: int in 8:
		w1.append({"at": Vector3(-14.0 + 4.0 * float(i), 0.0, -22.0), "opts": {"alerted": true, "hp": 99999.0, "mask": GunData.MASKS[i % 3]}})
	var w2: Array = []
	for i: int in 4:
		w2.append({"at": Vector3(-6.0 + 4.0 * float(i), 0.0, -24.0), "opts": {"alerted": true}})
	w1.append({"boss": "forklift", "at": Vector3(0.0, 0.0, -30.0), "yaw": 0.0, "opts": {"hp": 99999.0}})
	fight.add_wave(w1)
	fight.add_wave(w2)
	fight.start()
	fight.cover_ctl.hold_override = true


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	if not started:
		started = true
		_build()
		_next("settle")
		return
	var t: int = frames - t0
	# the player: crouched in cover, pops out to aim for 1 s every 2 s and fires every 0.33 s while aiming
	var aim: bool = (frames / 60) % 2 == 1
	dir.aim_override = aim
	dir.fire_override = aim and frames % 20 == 0
	if dir.fire_override == true:
		dir.cooldown = 0.0
	if phase == "settle" and t >= 358 and t <= 364:
		dir.aim_override = true              # Wave 3: Space while aiming, out of cover: the dive runs in the window
	if phase == "settle" and t == 362:
		player.jump_override = true
	if phase == "settle" and t == 364:
		_check(fight.bullet_time != null and fight.bullet_time.state == "dive", "a bullet-time dive runs inside the window (%s)" % (fight.bullet_time.state if fight.bullet_time else "none"))
	match phase:
		"settle":
			if t == 360:
				var in_cover: int = 0
				var shots: int = 0
				for g: Variant in fight.gunmen:
					if (g as Gunman).slot >= 0:
						in_cover += 1
					shots += (g as Gunman).shots
				var boss: ForkliftBoss = fight.boss
				print("  arena: %d enemies alive (8 gunmen + forklift), %d in cover, %d shots so far, player in cover: %s, boss %s (%d charges, %d tosses)" % [fight.alive().size(), in_cover, shots, fight.cover_ctl.in_cover, boss.state_name(), boss.charges, boss.tosses])
				_check(fight.alive().size() == 9 and boss != null, "8 gunmen and the forklift fighting (%d)" % fight.alive().size())
				_check(boss.charges + boss.tosses >= 1, "the forklift attacked before the window")
				_check(in_cover >= 4, "most gunmen took cover (%d of 8)" % in_cover)
				_check(fight.cover_ctl.in_cover, "the player is in cover")
				shots0 = shots
				fight.cover_ctl.hold_override = false   # out of cover for the dive (Wave 3)
				_start_window()
			elif t == 360 + WINDOW:
				_end_window()
				var shots2: int = 0
				for g2: Variant in fight.gunmen:
					shots2 += (g2 as Gunman).shots
				print("  %d gunman shots during the %d-frame window" % [shots2 - shots0, WINDOW])
				_check(shots2 > shots0, "the gunmen shot during the window (%d -> %d)" % [shots0, shots2])
				_check(fight.max_shooters_seen <= GunData.max_shooters(), "never more than %d shooting (max %d)" % [GunData.max_shooters(), fight.max_shooters_seen])
				fight.process_mode = Node.PROCESS_MODE_DISABLED
				if fight.cover_ctl.pose:
					fight.cover_ctl.pose.process_mode = Node.PROCESS_MODE_DISABLED
				for g3: Variant in fight.gunmen:
					(g3 as Node3D).visible = false
				fight.boss.visible = false
				_next("base")
		"base":
			if t == 2:
				_start_window()
			elif t == 2 + WINDOW:
				_end_window()
				_report()


func _report() -> void:
	var cost: float = (medians[0] - medians[1]) / 1000.0
	var trim: float = (trimmed[0] - trimmed[1]) / 1000.0
	var pcost: float = (pmedians[0] - pmedians[1]) / 1000.0
	var ptrim: float = (ptrimmed[0] - ptrimmed[1]) / 1000.0
	print("  gunfight physics (8 gunmen + forklift boss + cover + HUD + fight): %.2f ms median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us)" % [cost, trim, medians[0], medians[1], trimmed[0], trimmed[1]])
	print("  gunfight process (HUD, pose layers, rigs): %.2f ms median, %.2f ms trimmed mean (median %.0f vs %.0f us; trimmed %.0f vs %.0f us)" % [pcost, ptrim, pmedians[0], pmedians[1], ptrimmed[0], ptrimmed[1]])
	_check(cost < GATE_MS, "gunfight < 3 ms per physics frame, median (%.2f)" % cost)
	_check(trim < GATE_MS, "gunfight < 3 ms per physics frame, 5 %%-trimmed mean (%.2f)" % trim)
	_check(pcost < GATE_MS, "gunfight < 3 ms per process frame, median (%.2f)" % pcost)
	_check(ptrim < GATE_MS, "gunfight < 3 ms per process frame, 5 %%-trimmed mean (%.2f)" % ptrim)
	_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
	if fails.is_empty():
		print("✅ SUCCESS: GUNFIGHT PERFORMANCE (physics %.2f / %.2f ms, process %.2f / %.2f ms median / trimmed mean < 3 ms)" % [cost, trim, pcost, ptrim])
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
