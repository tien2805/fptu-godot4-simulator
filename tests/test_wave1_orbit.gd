# File: res://tests/test_wave1_orbit.gd
# Wave 1 integration (Q1 camera director + Q2 impact + Q3 rim) in a small walled room:
#   - Impact.slowmo_remaining() is what CameraDirector.owner_remaining reads (not the clock's private counters);
#   - the last enemy's knockout in a MeleeFight: ONE director orbit, lasting the clock's whole freeze + 0.5 s slow motion
#     (no second slow motion: the clock owns the time scale), never inside a wall, the target always in view; the time
#     scale and the player's camera come back after;
#   - the knockout drops the enemy's Q3 rim; a retry spawns rimmed enemies again.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_wave1_orbit.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var arena: Node3D
var player: ThirdPersonController


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
	print("--- TEST WAVE 1 ORBIT (camera director + impact + rim) ---")
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	await _frames(1)
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena)
	# a small room: walls 2.5 m behind the player and to both sides
	var walls: Array = [World.wall(arena, Vector3(0.0, 1.5, 2.5), Vector3(8.0, 3.0, 0.3)),
		World.wall(arena, Vector3(-3.5, 1.5, -1.0), Vector3(0.3, 3.0, 8.0)),
		World.wall(arena, Vector3(3.5, 1.5, -1.0), Vector3(0.3, 3.0, 8.0))]
	player = World.player(arena, Vector3.ZERO, 0.0)
	var combat := PlayerCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	combat.setup({"player": player})
	var fight := MeleeFight.new()
	fight.name = "Fight"
	arena.add_child(fight)
	fight.setup({"player": player, "combat": combat, "force_unarmed": false})
	fight.add_wave([{"archetype": "clone", "at": Vector3(0.0, 0.0, -1.4), "opts": {"ai": false, "stats": {"block_chance": 0.0, "dodge_chance": 0.0}}}])
	fight.start()
	await _frames(30)
	var d: CameraDirector = CameraDirector.live()
	_check(d != null, "the camera director is installed")
	var clock: Impact = Impact.clock(combat)
	# ----- slowmo_remaining is the director's source -----
	clock.slowmo(0.3, 0.5, self)
	await _frames(1)
	var r1: float = clock.slowmo_remaining()
	_check(r1 > 0.45 and r1 <= 0.5 and absf(CameraDirector.owner_remaining(clock) - r1) < 1e-4, "Impact.slowmo_remaining() (%.3f s) is what the director reads" % r1)
	clock.end_slowmo(self)
	await _frames(2)
	_check(is_zero_approx(clock.slowmo_remaining()), "nothing running: 0 s left")
	# ----- the last enemy's knockout -----
	var e: MeleeEnemy = fight.enemies[0]
	_check(Readability.rimmed_count(e.body) > 0, "the enemy has the Q3 rim")
	await _frames(100)                           # clear of the finisher gap
	var orbits0: int = d.orbits if d else 0
	e.hp = 1.0
	combat._strike(e, {"kind": "heavy", "dmg": 5.0, "stagger": 5.0, "push": 1.2, "breaks_block": true, "from": player.global_position})
	_check(Readability.rimmed_count(e.body) == 0, "the knockout drops the rim")
	var cut: int = 0
	var frozen: int = 0
	var slowed: int = 0
	var in_wall: int = 0
	var blocked: int = 0
	var excl: Array[RID] = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	for i: int in 90:
		await physics_frame
		if Engine.time_scale < 0.1:
			frozen += 1
		elif Engine.time_scale < 0.5:
			slowed += 1
		if d and d.cut_kind == "orbit":
			cut += 1
			var rep: Dictionary = CameraFraming.report(d.cam, CameraFraming.subject_points(e), space, excl)
			if bool(rep["in_geo"]):
				in_wall += 1
			if not bool(rep["los"]):
				blocked += 1
	_check(d != null and d.orbits == orbits0 + 1, "one director orbit (%d)" % ((d.orbits if d else 0) - orbits0))
	_check(frozen == 9 and slowed == 30, "the clock's freeze (9 frames) then its 0.5 s slow motion, no second one (%d, %d)" % [frozen, slowed])
	_check(cut >= 36 and cut <= 42, "the orbit lasts the freeze + the slow motion (%d frames, ~39)" % cut)
	_check(in_wall == 0 and blocked == 0, "never in a wall, the target always in view (%d, %d)" % [in_wall, blocked])
	_check(is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null and player.camera.current, "the time scale and the player's camera come back")
	await _frames(20)
	_check(fight.state == "won", "the fight is won")
	# ----- a retry spawns rimmed enemies -----
	fight.retry()
	await _frames(3)
	var e2: MeleeEnemy = fight.enemies[0]
	_check(e2 != e and Readability.rimmed_count(e2.body) > 0, "a retry spawns a fresh, rimmed enemy")
	fight.stop()
	for w: Variant in walls:
		(w as Node).queue_free()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	RadialWheel.scale_owner = null
	if arena and is_instance_valid(arena):
		arena.free()
	if fails.is_empty():
		print("SUCCESS: WAVE 1 ORBIT (slowmo_remaining, one full orbit, no wall, rim off on the knockout and back on retry)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
