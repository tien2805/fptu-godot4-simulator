# File: res://tests/test_officers.gd
# Headless test of the Phase W officers on foot (spec W-D7, section 4): on campus 2 / 4 / 6 security guards by stars and
# Mr.T from 2 stars (at most 2 spawns per second, never more than 12 officers); they chase the player they see
# (guards ~5 m/s, Mr.T faster), Mr.T shouts "Em kia! Đứng lại! Thẻ sinh viên đâu?" first; a weapon knocks an
# officer out for 10 s (+5 heat), then he is back on his feet; officers dive at a player sprinting past (comic tackle: the
# player is knocked down, never hurt); once the stars are gone they give up and vanish – unless a new crime brings the stars
# back while they walk away, then they rejoin the hunt; an officer pinned in a corner out of view is replaced (fix round
# R4-I1 / R4-I3). Busting is off here
# (catch_enabled = false; Task 10 tests it). Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_officers.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var wanted: WantedDirector
var campus: bool = true
var spawn_k: int = 0
var seen_at: Dictionary = {}             # officer instance id -> [frame of first sight in the test, distance then]
var checked_speed: Dictionary = {}       # role -> true
var stuck_o: Officer = null


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST OFFICERS ---")
	physics_frame.connect(_on_physics)


## Deterministic spawn points: a ring 30 m around the player, in the open arena (clear line of sight).
func _spawn_point(_role: String, near: Vector3) -> Variant:
	spawn_k += 1
	var a: float = float(spawn_k) * 0.9
	return near + Vector3(sin(a) * 30.0, 0.0, cos(a) * 30.0)


## A U of walls behind the player (out of the camera's view), open away from him, with a guard inside: walking straight at
## the player he hits the back wall, his sidesteps slide him from corner to corner, he never gets closer.
func _stuck_setup() -> void:
	World.wall(arena, Vector3(0.0, 1.5, 18.6), Vector3(4.0, 3.0, 0.4))
	World.wall(arena, Vector3(-1.8, 1.5, 20.2), Vector3(0.4, 3.0, 3.6))
	World.wall(arena, Vector3(1.8, 1.5, 20.2), Vector3(0.4, 3.0, 3.6))
	wanted.spawning = false
	wanted.add_heat(4.0)
	stuck_o = wanted.spawn_officer("guard", Vector3(0.0, 0.0, 20.5))


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _track_speeds() -> void:
	for o: Officer in wanted.officers():
		var id: int = o.get_instance_id()
		var d: float = WeaponMath.flat(o.global_position, player.global_position)
		if not seen_at.has(id):
			if o.state == Officer.State.CHASE and d > 15.0:
				seen_at[id] = [frames, d]
		elif not checked_speed.has(o.role) and frames - int(seen_at[id][0]) == 60:
			checked_speed[o.role] = true
			var moved: float = float(seen_at[id][1]) - d
			var v: float = float(Officer.SPEEDS[o.role])
			_check(moved > v * 0.8 and moved < v * 1.1, "%s chases at ~%.1f m/s (%.2f m in 1 s)" % [o.role, v, moved])


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		wanted = WantedDirector.new()
		wanted.name = "Wanted"
		arena.add_child(wanted)
		wanted.setup({"player": player, "is_campus_fn": func(_p: Vector3) -> bool: return campus})
		wanted.spawn_fn = _spawn_point
		wanted.catch_enabled = false
		_next("one")
		return
	var t: int = frames - t0
	_track_speeds()
	match phase:
		"one":
			if t == 2:
				wanted.add_heat(4.0)
			if t == 70:
				_check(wanted.count_role("guard") == 2 and wanted.count_role("mr_t") == 0, "1 star on campus: 2 guards, no Mr.T (%d, %d)" % [wanted.count_role("guard"), wanted.count_role("mr_t")])
				wanted.add_heat(8.0)
				_next("two")
		"two":
			if t == 130:
				_check(wanted.count_role("guard") == 4 and wanted.count_role("mr_t") == 1, "2 stars: 4 guards and Mr.T (%d, %d)" % [wanted.count_role("guard"), wanted.count_role("mr_t")])
				wanted.add_heat(13.0)
				_next("three")
		"three":
			if t == 130:
				_check(wanted.count_role("guard") == 6 and wanted.count_role("mr_t") == 1, "3 stars: 6 guards and Mr.T")
				_check(wanted.officers().size() <= WantedDirector.MAX_OFFICERS and wanted.officers_spawned == 7, "no more than needed (%d spawned)" % wanted.officers_spawned)
				_check(checked_speed.has("guard") and checked_speed.has("mr_t"), "speeds measured for a guard and Mr.T")
				var mr_t: Officer = null
				for o: Officer in wanted.officers():
					if o.role == "mr_t":
						mr_t = o
				_check(mr_t != null and mr_t.shouts >= 1 and mr_t.bubble.text == String((Officer.LINES["mr_t"] as Array)[0]), "Mr.T's first shout (0.6 s after he sees the player): 'Em kia! Đứng lại! Thẻ sinh viên đâu?'")
				var g: Officer = null
				for o: Officer in wanted.officers():
					if o.role == "guard" and g == null:
						g = o
				var h0: float = wanted.heat
				var r: String = g.take_hit({"kind": "bullet", "from": player.global_position})
				_check(r == "knocked_out" and g.is_down() and is_equal_approx(g.ko_left, Officer.KO_S), "a bullet knocks a guard out for 10 s")
				_check(is_equal_approx(wanted.heat, h0 + WantedDirector.OFFICER_KO_HEAT), "+5 heat for knocking out an officer")
				_check(g.take_hit({"kind": "scare", "from": player.global_position}) == "none", "officers ignore scares")
				g.ko_left = 0.5
				g.set_meta("t", true)
				_next("up")
		"up":
			if t == 60:
				var back: bool = false
				for o: Officer in wanted.officers():
					if o.has_meta("t"):
						back = not o.is_down() and o.collision_layer == 1
				_check(back, "the knocked-out guard gets up when his time is over")
				player.input_override = Vector2(0.0, -1.0)
				player.sprint_override = true
				_next("tackle")
		"tackle":
			if player.is_knocked_down() and not has_meta("tackled"):
				set_meta("tackled", true)
				var dove: bool = false
				for o: Officer in wanted.officers():
					if o.hits.has("tackle"):
						dove = true
				_check(dove, "an officer dove at the sprinting player")
			if t == 120:
				_check(has_meta("tackled"), "the sprinting player was tackled (comic knock-down)")
				player.input_override = Vector2.ZERO
				player.sprint_override = false
				wanted.clear()
				_next("give_up")
		"give_up":
			if t == 3:
				var all_gave_up: bool = true
				var walking: int = 0
				for o: Officer in wanted.officers():
					if o.state != Officer.State.GIVE_UP and not o.is_down():
						all_gave_up = false
					if o.state == Officer.State.GIVE_UP:
						walking += 1
						o.set_meta("walking", true)
				_check(all_gave_up, "no stars: the officers give up (or already left out of view)")
				_check(walking > 0, "test setup: some officers are still walking away in view (%d)" % walking)
				wanted.add_heat(4.0)
			if t == 6:
				var rejoined: bool = true
				var n_walk: int = 0
				for o: Officer in wanted.officers():
					if o.has_meta("walking"):
						n_walk += 1
						if o.state == Officer.State.GIVE_UP:
							rejoined = false
				_check(n_walk > 0 and rejoined, "a new crime while they walk away: they rejoin the hunt (R4-I1)")
				wanted.clear()
			if t == 9:
				wanted.set("_give_up_t", WantedDirector.GIVE_UP_DESPAWN_S)
			if t == 12:
				_check(wanted.officers().is_empty(), "they are gone after the give-up time")
				_stuck_setup()
				_next("stuck")
		"stuck":
			if t == 2:
				_check(stuck_o != null and is_instance_valid(stuck_o) and stuck_o.can_catch(), "test setup: a guard inside the walled corner behind the player")
			if t == 60 * 7:
				_check(wanted.officers_replaced >= 1 and not is_instance_valid(stuck_o), "an officer pinned in a corner out of view is replaced after ~3 s (R4-I3, %d replaced)" % wanted.officers_replaced)
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: OFFICERS (campus counts by star, Mr.T from 2 stars, chase speeds, shout, knock-out +5, get up, tackle, give up)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
