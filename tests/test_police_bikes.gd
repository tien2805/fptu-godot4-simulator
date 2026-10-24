# File: res://tests/test_police_bikes.gd
# Headless test of the Phase W police motorbikes (spec W-D7, section 4): A (RoamTraffic) a police bike (white paint, police
# rider, siren) appears on a lane heading toward the player, rides at 12 m/s, dismounts within 15 m (police_arrived beside
# the bike, the bike stays halted, the rider leaves the seat), or within 60 m once it stops getting closer; civil traffic
# counts ignore police; shooting a riding police bike makes its rider dismount; release_police parks the riders.
# B (WantedDirector on the streets) 1 / 2 / 3 bikes by stars, each arrival becomes a police officer on foot with its bike
# index, a second wave of 3 after 30 s at 3 stars, and without traffic the police arrive on foot.
# Busting is off (catch_enabled = false). Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_police_bikes.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var traffic: RoamTraffic
var arrivals: Array = []                 # [idx, at]
var idx_a: int = -1
var wanted: WantedDirector


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST POLICE BIKES ---")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena, 600.0)
		player = World.player(arena, Vector3(0.0, 0.0, 12.0), 0.0)
		traffic = World.traffic(arena, player, 0.0)
		for i: int in 2:
			var c: RoamTraffic.Vehicle = traffic.vehicles[i]
			World.place_vehicle(traffic, i, -95.0 if i == 0 else 95.0)
			c.halted = true                 # parked civil traffic at the road ends: nothing in the police lanes
		traffic.police_target_fn = func() -> Vector3: return player.global_position
		traffic.police_arrived.connect(func(i: int, at: Vector3) -> void: arrivals.append([i, at]))
		_next("spawn")
		return
	var t: int = frames - t0
	match phase:
		"spawn":
			if t == 2:
				idx_a = traffic.spawn_police()
				_check(idx_a >= 0, "a police bike spawns on a lane")
				if idx_a < 0:
					_finish()
					return
				var c: RoamTraffic.Vehicle = traffic.vehicles[idx_a]
				var rider: Node3D = c.body.get_node_or_null("Rider") as Node3D
				_check(c.police and c.police_state == "ride" and c.kind == RoamTraffic.Kind.POLICE, "police kind, riding")
				_check(rider != null and rider.visible and c.body.get_node_or_null("SirenR") != null, "police rider and siren lights")
				_check(is_equal_approx(c.cruise, RoamTraffic.POLICE_SPEED), "rides at 12 m/s")
				var d: float = c.pos.distance_to(Vector2(player.global_position.x, player.global_position.z))
				_check(d >= RoamTraffic.SPAWN_MIN - 0.5 and d <= RoamTraffic.SPAWN_MAX, "appears 40-150 m away (%.1f m)" % d)
				_check(traffic._civil_count() == 2, "civil traffic counts ignore police bikes")
			if t > 2 and not arrivals.is_empty():
				var c2: RoamTraffic.Vehicle = traffic.vehicles[idx_a]
				var at: Vector3 = arrivals[0][1]
				_check(int(arrivals[0][0]) == idx_a and WeaponMath.flat(at, player.global_position) <= RoamTraffic.POLICE_DISMOUNT_M + RoamTraffic.RIDER_SIDE_M + 0.5, "the rider dismounts within 15 m (%.1f m)" % WeaponMath.flat(at, player.global_position))
				var rider2: Node3D = c2.body.get_node_or_null("Rider") as Node3D
				_check(c2.halted and c2.police_state == "parked" and not rider2.visible, "the bike stays parked, the rider left the seat")
				arrivals.clear()
				_next("shot")
			elif t == 720:
				_check(false, "the police bike never arrived")
				_next("shot")
		"shot":
			if t == 2:
				var i2: int = traffic.spawn_police()
				_check(i2 >= 0 and traffic.hit_vehicle(i2, "bullet", player.global_position), "a bullet hits a riding police bike")
				_check(arrivals.size() == 1 and int(arrivals[0][0]) == i2, "... and its rider dismounts at once to chase on foot")
				arrivals.clear()
				var i3: int = traffic.spawn_police()
				traffic.release_police()
				_check(i3 >= 0 and not traffic.is_police_riding(i3) and arrivals.is_empty(), "release_police parks the riding bikes without officers")
				player.teleport(Vector3(0.0, 0.0, 50.0), 0.0)
			if t == 4:
				idx_a = traffic.spawn_police()
			if t > 4 and not arrivals.is_empty():
				var d2: float = WeaponMath.flat(arrivals[0][1], player.global_position)
				_check(d2 > RoamTraffic.POLICE_DISMOUNT_M and d2 <= RoamTraffic.POLICE_NEAR_M + RoamTraffic.RIDER_SIDE_M + 0.5, "off the road: dismounts within 60 m once it stops getting closer (%.1f m)" % d2)
				arrivals.clear()
				_start_b()
			elif t == 900:
				_check(false, "the no-progress dismount never happened")
				_start_b()
		"b":
			_part_b(t)


func _start_b() -> void:
	traffic.release_police()
	player.teleport(Vector3(0.0, 0.0, 12.0), 0.0)
	wanted = WantedDirector.new()
	wanted.name = "Wanted"
	arena.add_child(wanted)
	wanted.setup({"player": player, "traffic": traffic, "is_campus_fn": func(_p: Vector3) -> bool: return false})
	wanted.catch_enabled = false
	_next("b")


func _part_b(t: int) -> void:
	if t == 2:
		wanted.add_heat(4.0)
	if t == 6:
		_check(wanted.pending_bikes.size() == 1 and wanted.count_role("police") == 0, "1 star on the streets: one police bike on its way")
	if t > 6 and t < 900 and wanted.count_role("police") == 1 and not has_meta("b1"):
		set_meta("b1", true)
		var o: Officer = wanted.officers()[0]
		_check(o.role == "police" and o.bike_idx >= 0 and traffic.vehicles[o.bike_idx].police, "the arrival becomes a police officer on foot, linked to his bike")
		wanted.add_heat(21.0)
		set_meta("t3", t)
	if has_meta("t3") and t == int(get_meta("t3")) + 130:
		_check(wanted.stars == 3 and wanted.count_role("police") + wanted.pending_bikes.size() == 3, "3 stars: 3 police (bikes on the way + on foot) (%d + %d)" % [wanted.count_role("police"), wanted.pending_bikes.size()])
		wanted.three_star_t = WantedDirector.SECOND_WAVE_S - 0.01
	if has_meta("t3") and t == int(get_meta("t3")) + 270:
		_check(wanted.second_wave and wanted.count_role("police") + wanted.pending_bikes.size() == 6, "a second wave of 3 after 30 s at 3 stars (%d + %d)" % [wanted.count_role("police"), wanted.pending_bikes.size()])
		var w2 := WantedDirector.new()
		w2.name = "WantedNoTraffic"
		arena.add_child(w2)
		w2.setup({"player": player, "is_campus_fn": func(_p: Vector3) -> bool: return false})
		w2.catch_enabled = false
		w2.spawn_fn = func(_r: String, near: Vector3) -> Variant: return near + Vector3(30.0, 0.0, 0.0)
		w2.add_heat(4.0)
		set_meta("w2", w2)
	if has_meta("t3") and t == int(get_meta("t3")) + 275:
		var w3: WantedDirector = get_meta("w2")
		_check(w3.count_role("police") == 1 and w3.pending_bikes.is_empty(), "without traffic the police arrive on foot (plan P9)")
		_finish()
	if t == 900 and not has_meta("b1"):
		_check(false, "no police officer arrived in part B")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: POLICE BIKES (spawn heading to the player, 12 m/s, dismount <= 15 m or on no progress, civil counts, shot rider dismounts, release, wanted counts, second wave, foot fallback)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
