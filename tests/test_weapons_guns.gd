# File: res://tests/test_weapons_guns.gd
# Headless test of the Phase W pistol and shotgun (spec section 3, section 7 "Weapons"): ray-capsule / ray-box / spread
# math; a hip shot knocks the person on the camera centre out (+2 per hit, +2 for a shot near people), scares a bystander,
# draws a muzzle flash and a tracer and plays the synthesized shot; an aimed shot hits on the over-the-shoulder crosshair
# line; a bullet halts a motorbike and its rider flees (+2); the shotgun launches a person ~4 m back once per shot (8 pellets,
# +3), pumps 0.35 s later, fires every 0.8 s; walls stop bullets (occlusion); no GPUParticles3D.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_guns.gd
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
var fled: int = 0
var a: Pedestrian
var b: Pedestrian
var d_start: Vector3
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
	print("--- TEST WEAPONS: PISTOL + SHOTGUN ---")
	_math()
	physics_frame.connect(_on_physics)


func _math() -> void:
	var t: float = WeaponMath.ray_capsule(Vector3(0.0, 1.0, 10.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, 0.35, 1.8)
	_check(absf(t - 9.65) < 0.02, "ray_capsule head-on hit at 9.65 m (%.3f)" % t)
	_check(WeaponMath.ray_capsule(Vector3(0.4, 1.0, 10.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, 0.35, 1.8) < 0.0, "ray_capsule: 0.4 m to the side misses")
	_check(WeaponMath.ray_capsule(Vector3(0.0, 2.0, 10.0), Vector3(0.0, 0.0, -1.0), Vector3.ZERO, 0.35, 1.8) < 0.0, "ray_capsule: over the head misses")
	var box := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, -5.0))
	_check(absf(WeaponMath.ray_box(Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.0, -1.0), box, Vector3(1.0, 0.5, 1.0)) - 4.0) < 1e-4, "ray_box hits the near face at 4 m")
	var rot := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.5, -5.0))
	_check(absf(WeaponMath.ray_box(Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.0, -1.0), rot, Vector3(2.0, 0.5, 1.0)) - 3.0) < 1e-4, "ray_box in the box frame (rotated 90°: 2 m half length across the ray)")
	_check(WeaponMath.ray_box(Vector3(3.0, 0.5, 0.0), Vector3(0.0, 0.0, -1.0), box, Vector3(1.0, 0.5, 1.0)) < 0.0, "ray_box miss")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var d0 := Vector3(0.0, 0.0, -1.0)
	_check(WeaponMath.spread_dir(d0, 0.0, rng).is_equal_approx(d0), "spread 0° = the aim direction")
	var worst: float = 0.0
	var mean: float = 0.0
	for i: int in 300:
		var ang: float = rad_to_deg(WeaponMath.spread_dir(d0, 4.5, rng).angle_to(d0))
		worst = maxf(worst, ang)
		mean += ang / 300.0
	_check(worst <= 4.51 and mean > 1.5, "spread stays inside the 4.5° cone and fills it (max %.2f°, mean %.2f°)" % [worst, mean])


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _fire_edge() -> void:
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
		traffic = World.traffic(arena, player, -25.0)
		World.place_vehicle(traffic, 0, 0.0)
		World.place_vehicle(traffic, 1, 80.0)
		traffic.rider_fled.connect(func(_i: int, _at: Vector3, _f: Vector3) -> void: fled += 1)
		dir = World.director(arena, player, targets, traffic)
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		dir.equip(WeaponData.Slot.PISTOL)
		_next("hip")
		return
	var t: int = frames - t0
	if dir.fire_override == true and t > 0 and phase != "shotgun_hold":
		dir.fire_override = false
	match phase:
		"hip":
			if t == 5:
				a = World.ped(arena, Vector3(0.0, 0.0, -10.0), 81, player)
				b = World.ped(arena, Vector3(2.5, 0.0, -6.0), 82, player)
				targets.append_array([a, b])
			if t == 8:
				_fire_edge()
			if t == 10:
				_check(dir.fx.transient_count("tracer") >= 1, "a tracer is drawn")
				_check(not dir.fx.cine.find_children("Flash*", "", true, false).is_empty(), "a muzzle flash")
				var played: bool = false
				for p: AudioStreamPlayer3D in dir._sfx:
					if p.stream == WeaponAudio.stream("shot_pistol"):
						played = true
				_check(played, "the synthesized pistol shot plays")
			if t == 12:
				_check(a.state == Pedestrian.State.KNOCKED_OUT, "a hip shot knocks out the person on the camera centre")
				_check(b.state == Pedestrian.State.FLEE, "the bystander 6.5 m away is scared and flees")
				_check(heat.size() == 2 and is_equal_approx(heat[0] + heat[1], WeaponData.HEAT_SHOT_NEAR + WeaponData.HEAT_PISTOL_HIT), "+2 shot near people, +2 hit (%s)" % str(heat))
				_check(dir.ammo[WeaponData.Slot.PISTOL] == 11, "one round used")
				targets.clear()
				heat.clear()
				dir.aim_override = true
				var c: Pedestrian = World.ped(arena, Vector3(ThirdPersonController.AIM_SIDE, 0.0, -15.0), 83, player)
				targets.append(c)
				_next("aim")
		"aim":
			if t == 25:
				_fire_edge()
			if t == 28:
				_check((targets[0] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT, "an aimed shot hits on the over-the-shoulder crosshair line")
				dir.aim_override = false
				targets.clear()
				heat.clear()
				player.pitch = -0.05
				_next("vehicle")
		"vehicle":
			if t == 20:
				_fire_edge()
			if t == 23:
				var c0: RoamTraffic.Vehicle = traffic.vehicles[0]
				var rider: Node3D = c0.body.get_node_or_null("Rider") as Node3D
				_check(c0.halted and c0.speed == 0.0, "a bullet stops the motorbike")
				_check(rider != null and not rider.visible and fled == 1, "its rider jumps off and flees")
				_check(heat.size() == 1 and is_equal_approx(heat[0], WeaponData.HEAT_PISTOL_HIT), "+2 for hitting a vehicle, no 'near people' heat (%s)" % str(heat))
				heat.clear()
				player.pitch = 0.0
				dir.equip(WeaponData.Slot.SHOTGUN)
				var dd: Pedestrian = World.ped(arena, Vector3(0.0, 0.0, -6.0), 84, player)
				targets.append(dd)
				_next("shotgun")
		"shotgun":
			var dp: Pedestrian = targets[0]
			if t == 12:
				d_start = dp.global_position
				_fire_edge()
			if t == 14:
				_check(dp.state == Pedestrian.State.LAUNCHED and dp.hits.count("launched") == 1, "the shotgun launches the person once (8 pellets, one reaction)")
				_check(dir.ammo[WeaponData.Slot.SHOTGUN] == 5 and dir._pending_cues.size() == 1, "one shell used, the pump is scheduled")
			if t == 50:                       # Q2: the knockout's 150 ms freeze delays the game clock by ~9 frames
				_check(dir._pending_cues.is_empty(), "the pump sound played 0.35 s (game time) after the shot")
			if t == 80:
				var moved: float = d_start.z - dp.global_position.z
				_check(dp.state == Pedestrian.State.KNOCKED_OUT and moved > 3.0 and moved < 6.0, "flung ~4 m back, knocked out (%.2f m)" % moved)
				var sum: float = 0.0
				for h: float in heat:
					sum += h
				_check(is_equal_approx(sum, WeaponData.HEAT_SHOTGUN), "+3 heat for the shotgun shot (%s)" % str(heat))
				targets.clear()
				shots0 = dir.shots
				dir.cooldown = 0.0
				dir.fire_override = true
				_next("shotgun_hold")
		"shotgun_hold":
			if t == 100:
				dir.fire_override = false
				_check(dir.shots - shots0 == 3, "the shotgun fires every 0.8 s (3 shots in 100 frames, got %d)" % (dir.shots - shots0))
				dir.equip(WeaponData.Slot.PISTOL)
				for old: Node in arena.find_children("*", "Pedestrian", true, false):
					old.queue_free()                 # the earlier steps' people (one fled into the line of fire after Q2's freezes)
				World.wall(arena, Vector3(0.0, 1.5, -8.0), Vector3(6.0, 3.0, 0.5))
				targets.append(World.ped(arena, Vector3(0.0, 0.0, -12.0), 85, player))
				_next("wall")
		"wall":
			if t == 3:
				var o: Vector3 = dir.aim_origin() + dir.aim_dir() * (player.camera.position.z + 0.3)
				var h: Dictionary = dir.first_hit(o, dir.aim_dir(), 80.0)
				_check(String(h["kind"]) == "world" and absf((h["pos"] as Vector3).z + 7.75) < 0.1, "a wall in front stops the bullet before the person behind it (%s at %s)" % [h["kind"], h["pos"]])
				var front: Pedestrian = World.ped(arena, Vector3(0.0, 0.0, -5.0), 86, player)
				targets.append(front)
			if t == 6:
				var o2: Vector3 = dir.aim_origin() + dir.aim_dir() * (player.camera.position.z + 0.3)
				var h2: Dictionary = dir.first_hit(o2, dir.aim_dir(), 80.0)
				_check(String(h2["kind"]) == "soft", "a person in front of the wall is hit first (%s)" % h2["kind"])
				_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: WEAPONS PISTOL + SHOTGUN (math, hip / aimed hits, heat, bystanders, vehicle stop, knockback, pump, cadence, occlusion)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
