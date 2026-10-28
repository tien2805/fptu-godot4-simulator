# File: res://tests/test_gun_feel.gd
# Headless test of the Q2 gun feel (plan 2026-10-29-q2-feel.md T4) with a real WeaponDirector in a small arena:
#   - every shot kicks the camera back (a camera director stub gets punch(0.12 pistol / 0.3 shotgun, -aim));
#   - the muzzle light is on for the frame of the shot only; tracers are thicker and visible (a tracer transient);
#   - a shot into a wall leaves a pooled bullet-hole decal (DECAL_MAX, reused, never more);
#   - a hit on a gunman: he jolts away from the shot, the HUD hit marker shows with its tick; a knockout: the red marker
#     and the knockout tick, a finisher-tier impact, his mask flies off (up, then lying on the floor);
#   - GunFight: the last gunman's knockout gets the slow-motion orbit; a hit on the player flashes the screen edge.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_gun_feel.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var targets: Array = []


class Director:
	extends Node
	var punches: Array = []

	func punch(strength: float, d: Vector3) -> void:
		punches.append([strength, d])


class FightStub:
	extends Node
	var fx: WeaponFX
	var cues: Array[String] = []

	func play_cue(cue: String, _at: Vector3, _db: float = 0.0) -> void:
		cues.append(cue)

	func release_token(_g: Object) -> void:
		pass


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  x ", msg)
	else:
		print("  ok ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST GUN FEEL (Q2) ---")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _gunman(at: Vector3, mask: String, stub: FightStub) -> Gunman:
	var g := Gunman.new()
	g.name = "Guard%d" % targets.size()
	g.setup({"ai": false, "mask": mask, "seed": 3 + targets.size(), "yaw": 0.0})
	g.position = at
	arena.add_child(g)
	g.bind(stub)
	targets.append(g)
	return g


func _run() -> void:
	await _frames(1)
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena)
	World.wall(arena, Vector3(0.0, 1.5, -12.0), Vector3(10.0, 3.0, 0.3))
	player = World.player(arena, Vector3.ZERO, 0.0)
	dir = World.director(arena, player, targets)
	var dirn := Director.new()
	dirn.name = "CamDirector"
	dirn.add_to_group("camera_director")
	arena.add_child(dirn)
	await _frames(3)
	dir.equip(WeaponData.Slot.PISTOL)
	await _frames(3)
	var fx: WeaponFX = dir.fx
	# ----- a shot into the wall -----
	var lf0: int = fx.light_flashes
	dir.try_fire()
	_check(fx.light_flashes == lf0 + 1 and fx.muzzle_light.visible, "the shot lights the muzzle")
	_check(fx.transient_count("tracer") >= 1, "a visible tracer")
	_check(dirn.punches.size() == 1 and is_equal_approx(float(dirn.punches[0][0]), WeaponDirector.RECOIL["hitscan"]) and (dirn.punches[0][1] as Vector3).dot(dir.aim_dir()) < -0.9,
		"pistol recoil: the camera kicks back (%s)" % str(dirn.punches))
	_check(fx.decal_count() == 1, "a bullet hole on the wall")
	await physics_frame
	_check(fx.muzzle_light.visible, "the muzzle light is still on the next frame")
	await physics_frame
	await physics_frame
	await physics_frame
	_check(not fx.muzzle_light.visible, "the muzzle light is off after ~50 ms (%d frames)" % WeaponFX.MUZZLE_LIGHT_FRAMES)
	for i: int in WeaponFX.DECAL_MAX + 6:
		fx.decal(Vector3(float(i) * 0.1, 1.5, -11.84), Vector3(0.0, 0.0, 1.0))
	_check(fx.decal_count() == WeaponFX.DECAL_MAX, "bullet holes are pooled (%d, max %d)" % [fx.decal_count(), WeaponFX.DECAL_MAX])
	# ----- the shotgun's recoil -----
	await _frames(30)
	dir.equip(WeaponData.Slot.SHOTGUN)
	await _frames(30)
	dir.try_fire()
	_check(is_equal_approx(float(dirn.punches.back()[0]), WeaponDirector.RECOIL["pellets"]), "shotgun recoil 0.3")
	dirn.queue_free()
	await _frames(40)
	# ----- a gunman: hit, then knockout -----
	dir.equip(WeaponData.Slot.PISTOL)
	await _frames(40)
	var stub := FightStub.new()
	stub.name = "FightStub"
	stub.fx = fx
	arena.add_child(stub)
	var g: Gunman = _gunman(Vector3(0.0, 0.0, -6.0), "wolf", stub)
	await _frames(5)
	var clock: Impact = Impact.clock(dir)
	var hp0: float = g.hp
	var m0: int = dir.hud.markers_shown
	dir.try_fire()
	await physics_frame
	_check(g.hp < hp0 and g.jolts == 1 and g.jolt_t > 0.0 and absf(g.body.rotation.x) > 0.02, "a hit jolts him away from the shot (lean %.2f)" % g.body.rotation.x)
	_check(dir.hud.markers_shown == m0 + 1 and not dir.hud.marker_ko and dir.hud.marker.visible and clock.cue_log.has("hit_tick"), "the hit marker and its tick")
	await _frames(25)
	_check(is_zero_approx(g.body.rotation.x) and is_zero_approx(g.body.rotation.z), "the jolt settles")
	_check(not dir.hud.marker.visible, "the marker fades")
	await _frames(30)
	g.hp = 1.0
	var mask: Node3D = g.body.find_child("*Mask", true, false) as Node3D
	_check(mask != null, "test setup: he wears a wolf mask")
	_check(Readability.rimmed_count(g.body) > 0, "integration: a standing gunman has the Q3 rim")
	dir.try_fire()
	var top: float = -99.0
	for i2: int in 90:
		await physics_frame
		if g.flying_hat:
			top = maxf(top, g.flying_hat.global_position.y)
	_check(g.st == Gunman.St.KO and dir.hud.marker_ko and clock.cue_log.has("ko_tick"), "a knockout: the red marker and the knockout tick")
	_check(Readability.rimmed_count(g.body) == 0 and Readability.rimmed_count(mask) == 0, "integration: the knockout drops the Q3 rim, the flying mask carries none")
	_check(String(clock.last_hit.get("tier", "")) == "finisher", "a gunshot knockout is a finisher-tier impact")
	_check(g.flying_hat == mask and top > 2.0 and absf(mask.global_position.y - 0.06) < 0.05, "the mask flies off (%.1f m up) and lies on the floor" % top)
	# ----- GunFight: the last gunman -----
	targets.clear()
	g.queue_free()
	stub.queue_free()
	await _frames(3)
	var combat := PlayerCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	combat.setup({"player": player, "weapons": dir})
	var fight := GunFight.new()
	fight.name = "Fight"
	arena.add_child(fight)
	fight.setup({"player": player, "combat": combat, "weapons": dir, "cover_root": arena, "force_loadout": false})
	fight.add_wave([{"at": Vector3(-1.0, 0.0, -6.0), "opts": {"ai": false, "mask": "fox", "hp": 1.0}},
		{"at": Vector3(1.0, 0.0, -6.0), "opts": {"ai": false, "mask": "none", "hp": 1.0}}])
	fight.start()
	await _frames(5)
	var o0: int = clock.orbit_count
	var gs: Array = fight.gunmen.duplicate()
	(gs[0] as Gunman).take_hit({"kind": "bullet", "from": player.global_position})
	await _frames(20)
	_check(clock.orbit_count == o0, "not the last one: no orbit")
	(gs[1] as Gunman).take_hit({"kind": "bullet", "from": player.global_position})
	await _frames(2)
	_check(clock.orbit_count == o0 + 1 and clock.slowmo_active(), "the last gunman's knockout: the slow-motion orbit")
	_check((gs[1] as Gunman).flying_hat != null and String((gs[1] as Gunman).flying_hat.name) == "FlyingCap", "no mask: a cap flies off")
	await _frames(60)
	var e0: int = clock.edge_flashes
	combat.receive_attack(gs[0] as Node3D, {"damage": 10.0, "unblockable": true})   # a bullet (the fight is won: hit_player is off)
	_check(clock.edge_flashes == e0 + 1, "a bullet on the player flashes the screen edge")
	fight.stop()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	RadialWheel.scale_owner = null
	if arena and is_instance_valid(arena):
		arena.free()
	if fails.is_empty():
		print("SUCCESS: GUN FEEL (recoil, muzzle light, tracers, decals, jolt, hit markers, flying mask, last-enemy orbit)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
