# File: res://tests/test_lair_perf.gd
# Phase C performance gates of the story lairs (spec C-D13; plan 2026-10-26-phase-c-integration.md):
#   A the Day 3 gunfight in the REAL container yard: FreeRoam with the full crowd and traffic, the LairYard built on the
#     canal plot, a GunFight on the yard's cover (8 alerted guards in the StoryCast lair looks, tough, plus a queued wave of
#     4), the player in god mode crouched in cover popping out to aim and fire every second. One window of 120 physics
#     frames against a baseline with the fight disabled (its gunmen, HUD and player cover): the fight's cost;
#   B the Day 5 server basement scene (StoryBasement: LairBasement, its own player stack, no city) with the same fight in
#     the server hall: the basement scene's whole script time per physics frame (absolute) and the fight's cost against
#     the fight disabled.
# Each cost < 3 ms per physics frame and per process frame by the MEDIAN and the 5 %-TRIMMED MEAN (the method of
# tests/test_combat_perf.gd: from the physics_frame / process_frame signal to a tail node that runs after every other
# _physics_process / _process, the phase-change frame dropped). Also: no GPUParticles3D, Engine.time_scale 1.0. Prints
# the numbers for PLAN.md. Run on AC power (Get-CimInstance BatteryStatus PowerOnline).
# Run:  godot --headless --path . --script tests/test_lair_perf.gd
extends SceneTree

const GATE_MS: float = 3.0
const WINDOW: int = 120
const SETTLE: int = 360

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
var phase: String = "boot"
var t0: int = 0
var case_name: String = "A"
var host: Node3D
var yard: LairYard
var fight: GunFight
var player: ThirdPersonController
var weapons: WeaponDirector
var combat: PlayerCombat
var timing: bool = false
var _pt0: int = 0
var _qt0: int = 0
var samples: PackedInt32Array = PackedInt32Array()
var psamples: PackedInt32Array = PackedInt32Array()
var res: Dictionary = {}          # case -> {"fight": [median, trimmed], "base": [...], "pfight", "pbase"}
var shots0: int = 0
## W3 Day 3: the yard's set pieces in case A (40 mannequins, the crane, both forklifts), disabled for the baseline.
var extras: Array[Node] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	WeaponAudio.sfx_dir = "user://__test_no_sfx__/"
	print("--- TEST LAIR PERFORMANCE GATES (container yard in FreeRoam, server basement scene) ---")
	var tail := Tail.new()
	tail.name = "PhysTail"
	tail.process_physics_priority = 1 << 30
	tail.on_tail = func() -> void:
		if timing:
			samples.append(Time.get_ticks_usec() - _pt0)
	root.add_child(tail)
	var ptail := Tail.new()
	ptail.name = "ProcTail"
	ptail.physics = false
	ptail.process_priority = 1 << 30
	ptail.on_tail = func() -> void:
		if timing:
			psamples.append(Time.get_ticks_usec() - _qt0)
	root.add_child(ptail)
	physics_frame.connect(_on_physics)
	process_frame.connect(func() -> void: _qt0 = Time.get_ticks_usec())


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _start_window() -> void:
	samples.clear()
	psamples.clear()
	timing = true


## [median, trimmed] of the physics and the process samples of the window just ended.
func _end_window() -> Array:
	timing = false
	var out: Array = []
	for s: PackedInt32Array in [samples, psamples]:
		var sorted: PackedInt32Array = s.duplicate()
		sorted.sort()
		if sorted.size() > 1:
			sorted.remove_at(0)   # the phase-change frame
		if sorted.is_empty():
			out.append([0.0, 0.0])
			continue
		out.append([float(sorted[sorted.size() / 2]), trimmed_mean(sorted, 0.05)])
	return out


static func trimmed_mean(sorted: PackedInt32Array, frac: float) -> float:
	var k: int = int(floor(float(sorted.size()) * frac))
	var n: int = sorted.size() - 2 * k
	if n <= 0:
		return float(sorted[sorted.size() / 2])
	var t: int = 0
	for i: int in range(k, k + n):
		t += sorted[i]
	return float(t) / float(n)


func _guard_body(i: int) -> Callable:
	var id: String = MissionLairFight.GUARD_IDS[i % 3]
	return func(_look: Dictionary) -> Node3D: return StoryCast.build(id)


## The fight: 8 alerted tough guards at the level's wave spots, a queued wave of 4, the player in cover.
func _make_fight(cover_root: Node3D, w1: Array, w2: Array, start: Vector3, yaw: float) -> void:
	player.teleport(start, yaw)
	combat.god = true
	fight = GunFight.new()
	fight.name = "PerfFight"
	host.add_child(fight)
	fight.setup({"roam": host, "cover_root": cover_root, "seed": 21, "accuracy_override": 0.25,
		"reserve": {WeaponData.Slot.PISTOL: -1, WeaponData.Slot.SHOTGUN: -1}})
	var a: Array = []
	for i: int in 8:
		a.append({"at": w1[i % w1.size()] + Vector3(0.0, 0.0, 1.6 * float(i / w1.size())),
			"opts": {"alerted": true, "hp": 99999.0, "mask": "none", "body_fn": _guard_body(i)}})
	var b: Array = []
	for j: int in 4:
		b.append({"at": w2[j % w2.size()], "opts": {"alerted": true, "mask": "none", "body_fn": _guard_body(j)}})
	fight.add_wave(a)
	fight.add_wave(b)
	fight.start()
	fight.cover_ctl.hold_override = true


func _on_physics() -> void:
	_pt0 = Time.get_ticks_usec()
	frames += 1
	var t: int = frames - t0
	if weapons and fight and is_instance_valid(fight) and fight.process_mode != Node.PROCESS_MODE_DISABLED:
		var aim: bool = (frames / 60) % 2 == 1
		weapons.aim_override = aim
		weapons.fire_override = aim and frames % 20 == 0
		if weapons.fire_override == true:
			weapons.cooldown = 0.0
	match phase:
		"boot":
			for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
				if not root.has_node(pair[0]):
					var n: Node = (load(pair[1]) as Script).new()
					n.name = pair[0]
					root.add_child(n)
			host = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			root.add_child(host)
			_next("yard_build")
		"yard_build":
			if t < 20:
				return
			player = host.get("player")
			weapons = host.get("weapons")
			combat = host.get("combat")
			host.call("set_time_of_day", "night")
			yard = LairYard.new()
			yard.build_in(host)
			var pts: Dictionary = yard.mission_points("gunfight")
			var w: Array = pts["waves"]
			var all1: Array = (w[0] as Array) + (w[1] as Array)
			_make_fight(yard.cover_root, all1, w[1], yard.world(Vector3(-1.0, 0.0, 9.9)), yard.world_yaw(0.0))   # behind a barrier
			var mq := YardMannequins.new()
			host.add_child(mq)
			mq.setup(yard.global_transform, LairYard.FIGHT_START)
			var cr := YardCrane.new()
			host.add_child(cr)
			cr.setup(yard.global_transform, fight, 3)
			var pf := PlayerForklift.new()
			host.add_child(pf)
			pf.setup(fight, yard.world(LairYard.PLAYER_FORK), yard.world_yaw(LairYard.PLAYER_FORK_YAW))
			var bf := Forklift.new()
			bf.top_level = true
			host.add_child(bf)
			bf.global_position = yard.world(LairYard.FORKLIFT_PARK)
			bf.floor_y = bf.global_position.y
			extras = [mq, cr, pf, bf]
			_check(mq.count() >= 38, "case A: the mannequins in the yard (%d)" % mq.count())
			_next("settle")
		"settle":
			if t == SETTLE:
				var shots: int = 0
				var in_cover: int = 0
				for g: Variant in fight.gunmen:
					shots += (g as Gunman).shots
					if (g as Gunman).slot >= 0:
						in_cover += 1
				var peds: Variant = host.get("pedestrians")
				var trf: Variant = host.get("traffic")
				print("  case %s: %d guards alive, %d in cover, %d shots, player in cover %s" % [case_name, fight.alive().size(), in_cover, shots, str(fight.cover_ctl.in_cover)])
				_check(fight.alive().size() == 8, "case %s: 8 guards fighting" % case_name)
				_check(in_cover >= 3, "case %s: the guards use the level's cover (%d of 8)" % [case_name, in_cover])
				if case_name == "A":
					_check(peds != null and trf != null, "case A: the full crowd and traffic run around the yard")
				shots0 = shots
				_start_window()
			elif t == SETTLE + WINDOW:
				var r: Array = _end_window()
				res[case_name] = {"fight": r[0], "pfight": r[1]}
				var shots2: int = 0
				for g2: Variant in fight.gunmen:
					shots2 += (g2 as Gunman).shots
				_check(shots2 > shots0, "case %s: the guards shot during the window" % case_name)
				_check(fight.max_shooters_seen <= 3, "case %s: never more than 3 shooting" % case_name)
				fight.process_mode = Node.PROCESS_MODE_DISABLED
				if fight.cover_ctl.pose:
					fight.cover_ctl.pose.process_mode = Node.PROCESS_MODE_DISABLED
				for g3: Variant in fight.gunmen:
					(g3 as Node3D).visible = false
					(g3 as Node).process_mode = Node.PROCESS_MODE_DISABLED
				for x: Node in extras:
					if is_instance_valid(x):
						(x as Node3D).visible = false
						x.process_mode = Node.PROCESS_MODE_DISABLED
				weapons.aim_override = false
				weapons.fire_override = false
				_next("base")
		"base":
			if t == 2:
				_start_window()
			elif t == 2 + WINDOW:
				var r2: Array = _end_window()
				(res[case_name] as Dictionary)["base"] = r2[0]
				(res[case_name] as Dictionary)["pbase"] = r2[1]
				if case_name == "A":
					_check(host.find_children("*", "GPUParticles3D", true, false).is_empty(), "case A: no GPUParticles3D")
					host.queue_free()
					host = null
					fight = null
					_next("basement_boot")
				else:
					_report()
		"basement_boot":
			if t < 3:
				return
			case_name = "B"
			host = (load("res://scenes/story/StoryBasement.tscn") as PackedScene).instantiate()
			root.add_child(host)
			_next("basement_build")
		"basement_build":
			if t < 10:
				return
			var bs: StoryBasement = host as StoryBasement
			player = bs.player
			weapons = bs.weapons
			combat = bs.combat
			var pts2: Dictionary = bs.level.mission_points("gunfight")
			var w2: Array = pts2["waves"]
			_make_fight(bs.level, (w2[0] as Array) + (w2[1] as Array), w2[1], bs.level.world(Vector3(-4.0, 0.0, 6.0)), PI)   # behind a cabinet
			_next("settle")


func _report() -> void:
	var lines: Array[String] = []
	for c: String in ["A", "B"]:
		var d: Dictionary = res[c]
		var cost: float = (float(d["fight"][0]) - float(d["base"][0])) / 1000.0
		var trim: float = (float(d["fight"][1]) - float(d["base"][1])) / 1000.0
		var pcost: float = (float(d["pfight"][0]) - float(d["pbase"][0])) / 1000.0
		var ptrim: float = (float(d["pfight"][1]) - float(d["pbase"][1])) / 1000.0
		var what: String = "yard gunfight in FreeRoam (crowd + traffic)" if c == "A" else "basement gunfight"
		print("  %s: physics %.2f ms median, %.2f ms trimmed; process %.2f / %.2f ms (fight %.0f vs base %.0f us)" % [what, cost, trim, pcost, ptrim, float(d["fight"][0]), float(d["base"][0])])
		_check(cost < GATE_MS and trim < GATE_MS, "case %s: the fight < 3 ms per physics frame (%.2f / %.2f)" % [c, cost, trim])
		_check(pcost < GATE_MS and ptrim < GATE_MS, "case %s: the fight < 3 ms per process frame (%.2f / %.2f)" % [c, pcost, ptrim])
		lines.append("%s %.2f/%.2f ms" % [c, cost, trim])
	var b: Dictionary = res["B"]
	var abs_med: float = (float(b["fight"][0]) + float(b["pfight"][0])) / 1000.0
	var abs_trim: float = (float(b["fight"][1]) + float(b["pfight"][1])) / 1000.0
	print("  basement scene, whole script time with the gunfight (physics + process): %.2f ms median, %.2f ms trimmed" % [abs_med, abs_trim])
	_check(abs_med < GATE_MS and abs_trim < GATE_MS, "case B: the basement scene < 3 ms per frame, whole (%.2f / %.2f)" % [abs_med, abs_trim])
	_check(host.find_children("*", "GPUParticles3D", true, false).is_empty(), "case B: no GPUParticles3D")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
	if fails.is_empty():
		print("✅ SUCCESS: LAIR PERFORMANCE (%s; basement scene %.2f / %.2f ms; median / trimmed < 3 ms)" % [", ".join(lines), abs_med, abs_trim])
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
