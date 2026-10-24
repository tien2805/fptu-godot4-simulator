# File: res://tests/test_weapons_rocket.gd
# Headless test of the Phase W rocket launcher (spec section 3, section 7 "rocket explosion radius"): the visible rocket
# flies at 35 m/s to the person on the crosshair and explodes there; everyone within 6 m flies in a comic arc and lands
# knocked out, a person 7 m away is not launched but flees, one 32 m away is untouched; a car within the radius flips onto
# its roof and smokes; camera shake, smoke puff and scorch mark; +6 heat; 1 round, 2.5 s reload; a blast within 6 m of the
# player knocks him down (comic, he gets up); a rocket into the sky explodes after 140 m.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_rocket.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var traffic: RoamTraffic
var targets: Array = []
var heat: Array[float] = []
var peds: Dictionary = {}
var max_shake: float = 0.0
var empty_t: int = -1
var refill_t: int = -1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WEAPONS: ROCKET ---")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _ped(key: String, at: Vector3) -> Pedestrian:
	var p: Pedestrian = World.ped(arena, at, 90 + peds.size(), player)
	peds[key] = p
	targets.append(p)
	return p


func _fire() -> void:
	dir.cooldown = 0.0
	dir.fire_override = true


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		traffic = World.traffic(arena, player, -30.0)
		World.place_vehicle(traffic, 0, -80.0)
		World.place_vehicle(traffic, 1, 4.5)
		dir = World.director(arena, player, targets, traffic)
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		dir.equip(WeaponData.Slot.ROCKET)
		_ped("T", Vector3(0.0, 0.0, -28.0))
		_ped("A", Vector3(-3.0, 0.0, -24.0))
		_ped("B", Vector3(-5.5, 0.0, -28.0))
		_ped("C", Vector3(0.0, 0.0, -35.0))
		_ped("D", Vector3(0.0, 0.0, -60.0))
		_next("fire")
		return
	var t: int = frames - t0
	if dir.fire_override == true and t > 0:
		dir.fire_override = false
	max_shake = maxf(max_shake, float(player.get("_shake_t")))
	if empty_t < 0 and dir.ammo[WeaponData.Slot.ROCKET] == 0:
		empty_t = frames
	if empty_t > 0 and refill_t < 0 and dir.ammo[WeaponData.Slot.ROCKET] == 1:
		refill_t = frames
	match phase:
		"fire":
			if t == 10:
				_fire()
			if t == 12:
				_check(dir.rockets_fired == 1 and arena.find_children("Rocket*", "", true, false).size() == 1, "a visible rocket is in flight")
			if t == 70:
				_check(dir.explosions.size() == 1, "the rocket exploded (%d)" % dir.explosions.size())
				var e: Vector3 = dir.explosions[0] if not dir.explosions.is_empty() else Vector3.INF
				_check(WeaponMath.flat(e, (peds["T"] as Pedestrian).global_position) < 1.5 or (peds["T"] as Pedestrian).is_down(), "it exploded on the person on the crosshair (%s)" % e)
				for k: String in ["T", "A", "B"]:
					var p: Pedestrian = peds[k]
					_check(p.state == Pedestrian.State.LAUNCHED or p.state == Pedestrian.State.KNOCKED_OUT, "%s inside 6 m is launched / knocked out (state %d)" % [k, p.state])
				_check((peds["C"] as Pedestrian).state == Pedestrian.State.FLEE, "C at ~7 m is not launched but flees")
				_check((peds["D"] as Pedestrian).state == Pedestrian.State.IDLE, "D 32 m away is untouched")
				var car: RoamTraffic.Vehicle = traffic.vehicles[1]
				_check(car.wreck_t >= 0.0 and car.body.get_node_or_null("Smoke") != null, "the car inside the radius is wrecked and smokes")
				_check(max_shake > 0.0, "the camera shakes")
				_check(dir.fx.transient_count("smoke") == 1 and dir.fx.transient_count("scorch") == 1, "a smoke puff and a scorch mark")
				_check(heat.has(WeaponData.HEAT_ROCKET), "+6 heat for the explosion (%s)" % str(heat))
				_check(arena.find_children("Rocket*", "", true, false).is_empty(), "the rocket is gone")
			if t == 140:
				var car2: RoamTraffic.Vehicle = traffic.vehicles[1]
				_check(car2.body.global_transform.basis.y.y < -0.9, "the car ended on its roof")
				_check((peds["T"] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT and (peds["A"] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT, "the launched people landed knocked out")
			if t == 200:
				_check(refill_t > 0 and absi(refill_t - empty_t - 150) <= 2, "1 round, 2.5 s reload (%d frames)" % (refill_t - empty_t))
				targets.clear()
				_ped("T2", Vector3(0.0, 0.0, -4.0))
				_next("close")
		"close":
			if t == 5:
				_fire()
			if t == 25:
				_check(dir.explosions.size() == 2 and player.is_knocked_down(), "a blast within 6 m knocks the player down (comic, no damage)")
			if t == 190:
				_check(player.move_state == "GROUND", "the player gets up again")
				targets.clear()
				player.pitch = 0.5
				_next("sky")
		"sky":
			if t == 10:
				_fire()
			if t == 270:
				_check(dir.explosions.size() == 3, "the rocket into the sky exploded")
				var far: float = dir.explosions.back().distance_to(player.global_position + Vector3(0.0, WeaponDirector.ROCKET_UP, 0.0)) if dir.explosions.size() == 3 else 0.0
				_check(far > 134.0 and far < 142.0, "... after 140 m (%.1f m)" % far)
				_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: WEAPONS ROCKET (flight, 6 m radius, launch arcs, flee, wreck, shake, smoke, scorch, heat, reload, player knock-down, max range)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
