# File: res://tests/test_bike_feel.gd
# Headless test of the Q2 bike feel (plan 2026-10-29-q2-feel.md T3) on a BikeChase in a flat arena (no FreeRoam):
#   - a kick that connects: a heavy Impact (5 frozen frames), the bike's recoil roll, the target wobbling on a curve (its
#     yaw swinging both ways), then the crash throws its parts (2 mirrors + the helmet) that fly and are freed after PART_S;
#   - counter-kick: a kick toward an attacker in his last 0.25 s is "PHẢN ĐÒN!" (crash cause "counter", a takedown, no
#     damage to the player); a kick earlier in his wind-up is not a counter;
#   - grab weapon: a kicked stick rider drops his stick; riding over it picks it up (3 swings, +1 m reach, 2 kicks of damage
#     per hit: a heavy goes down in 2), then it breaks;
#   - the spin kick's motion trail shows while it spins;
#   - a hit on the player: the red screen edge, the bike wobble, a camera shake.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_bike_feel.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const BIKE_SCENE: String = "res://scenes/PlayerBike.tscn"
const Z0: float = 250.0

var fails: Array[String] = []
var arena: Node3D
var bike: PlayerBike
var chase: BikeChase
var downs: Array = []


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
	print("--- TEST BIKE FEEL (Q2) ---")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _hold(b: BikerEnemy, along: float, lat: float) -> void:
	b.hold_along = along
	b.hold_lat = lat
	var p: Vector2 = chase.target_at(along, lat)
	b.place(Vector3(p.x, 0.0, p.y), 0.0, chase.p_vel.length())


func _chase(kinds: Array) -> BikeChase:
	var c := BikeChase.new()
	c.name = "FeelChase"
	arena.add_child(c)
	c.setup({"bike": bike, "route": [Vector2(0.0, Z0), Vector2(0.0, -1500.0)], "start_s": 60.0, "manual_replay": true, "seed": 5,
		"auto_replay": false})
	var w: Array = []
	for i: int in kinds.size():
		w.append({"lane": [-1, 1][i % 2], "opts": {"ai": false, "kind": String(kinds[i]), "label": "F%d" % i}})
	c.add_wave(w)
	c.add_wave([{"lane": 1, "opts": {"ai": false, "label": "Spare"}}])   # the chase never finishes in this test
	c.biker_down.connect(func(b: BikerEnemy, cause: String) -> void: downs.append([b, cause]))
	return c


func _run() -> void:
	await _frames(1)
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena, 4000.0)
	bike = (load(BIKE_SCENE) as PackedScene).instantiate() as PlayerBike
	bike.name = "Bike"
	bike.lane_clamp_enabled = false
	bike.fallback_fall_y = -5.0
	arena.add_child(bike)
	bike.global_position = Vector3(0.0, -0.13, 190.0)
	bike.chase_cam.make_current()
	_check(BikeCombatData.TAKEDOWN_CAUSES.has("counter") and BikeCombatData.STICK_SWINGS == 3 and is_equal_approx(BikeCombatData.COUNTER_WINDOW, 0.25), "data: counter is a takedown, 3 stick swings, 0.25 s window")
	chase = _chase(["rider", "rider", "stick", "heavy"])
	chase.start()
	await _frames(3)
	var bs: Array = chase.bikers
	_check(bs.size() == 4, "4 bikers (%d)" % bs.size())
	for i: int in bs.size():
		_hold(bs[i], -12.0 - 3.0 * float(i), [-3.0, 3.0][i % 2])
	await _frames(5)
	var riders: Array = bs.filter(func(x: BikerEnemy) -> bool: return x.kind == "rider")   # spawn order is not the wave's
	var stick_b: Array = bs.filter(func(x: BikerEnemy) -> bool: return x.kind == "stick")
	var heavy_b: Array = bs.filter(func(x: BikerEnemy) -> bool: return x.kind == "heavy")
	_check(riders.size() == 2 and stick_b.size() == 1 and heavy_b.size() == 1, "kinds: 2 riders, a stick rider, a heavy")
	await _connect(riders[0] as BikerEnemy)
	await _counter(riders[1] as BikerEnemy)
	await _counter_heavy(heavy_b[0] as BikerEnemy)
	_hold(heavy_b[0] as BikerEnemy, -18.0, -3.0)
	await _stick(stick_b[0] as BikerEnemy, heavy_b[0] as BikerEnemy)
	await _spin_and_hurt()
	chase.stop()
	_finish()


func _connect(b: BikerEnemy) -> void:
	var clock: Impact = Impact.clock(chase)
	_hold(b, 0.0, 1.8)
	await _frames(20)
	var kb0: int = chase.combat.kickbacks
	_check(chase.combat.kick(1), "a right kick")
	var low: int = 0
	var hit_f: int = -1
	var yaws: Array[float] = []
	var crashed: bool = false
	for i: int in 70:
		await physics_frame
		if i < 30 and Engine.time_scale < 0.5:
			low += 1
		if hit_f < 0 and chase.combat.hits > 0:
			hit_f = i
		if b.st == BikerEnemy.St.WOBBLE:
			yaws.append(b.yaw)
		if b.st == BikerEnemy.St.CRASH:
			crashed = true
	_check(chase.combat.hits == 1 and String(clock.last_hit.get("tier", "")) == "heavy" and low == 5, "it connects: a heavy impact, 5 frozen frames (%d)" % low)
	_check(chase.combat.kickbacks == kb0 + 1, "the player's bike rocks back from the kick")
	var swings: int = 0
	for k: int in range(2, yaws.size()):
		if signf(yaws[k] - yaws[k - 1]) != signf(yaws[k - 1] - yaws[k - 2]):
			swings += 1
	_check(swings >= 2, "the kicked bike wobbles on a curve (%d direction changes over %d frames)" % [swings, yaws.size()])
	var max_part_y: float = -99.0
	for i2: int in 120:
		await physics_frame
		if b.st == BikerEnemy.St.CRASH:
			crashed = true
		for e: Dictionary in b.parts:
			if is_instance_valid(e["node"]):
				max_part_y = maxf(max_part_y, (e["node"] as Node3D).global_position.y - b.floor_y)
	_check(crashed and b.parts_thrown == 3, "the crash throws 3 parts: 2 mirrors and the helmet (%d)" % b.parts_thrown)
	var helmet: Node3D = b.body.find_child("WolfHelmet", true, false) as Node3D
	_check(max_part_y > 1.5 and helmet != null and not helmet.visible, "the parts fly up (%.1f m), the wolf helmet left the head" % max_part_y)
	await _frames(int(BikeCombatData.PART_S * 60.0))
	_check(b.parts.is_empty(), "the parts are gone after %.1f s" % BikeCombatData.PART_S)


func _counter(b: BikerEnemy) -> void:
	_hold(b, BikeCombatData.SLOT_ALONG, -BikeCombatData.SLOT_LAT)
	await _frames(25)
	var st0: float = chase.combat.stability
	# too early: 0.65 s before the hit
	b.start_attack(-1.0)
	await _frames(2)
	_check(b.time_to_hit() > 0.4 and chase.combat.counter_target(-1) == null, "early in his wind-up: no counter target (%.2f s to the hit)" % b.time_to_hit())
	while b.time_to_hit() > 0.2:
		await physics_frame
	var td0: int = chase.takedowns
	_check(chase.combat.counter_target(-1) == b and chase.combat.counter_target(1) == null, "in his last 0.25 s, only a kick toward him counters")
	_check(chase.combat.kick(-1), "the kick toward him")
	await _frames(1)
	_check(chase.combat.counters == 1 and b.countered_n == 1 and b.crash_cause == "counter" and b.is_down(), "PHẢN ĐÒN: he is sent flying (%s, %s)" % [b.crash_cause, b.state_name()])
	_check(chase.takedowns == td0 + 1 and chase.hud.popup_text == BikeCombatData.T_COUNTER, "a takedown, '%s'" % chase.hud.popup_text)
	_check(chase.combat.counter_slowmos == 1, "the counter's slow motion (%d)" % chase.combat.counter_slowmos)
	await _frames(60)
	_check(is_equal_approx(chase.combat.stability, st0) and b.results.is_empty(), "his kick never lands (stability %.0f)" % chase.combat.stability)
	await _frames(40)


## A counter is worth 2 kicks: a heavy (3) wobbles on with 1 left, no slow motion for a rider who stays up.
func _counter_heavy(h: BikerEnemy) -> void:
	_hold(h, 0.0, 1.8)
	await _frames(25)
	var n0: int = chase.combat.counter_slowmos
	chase.combat._counter(h, 1)
	await _frames(2)
	_check(h.hp == h.max_hp - 2 and h.st == BikerEnemy.St.WOBBLE and not h.is_down() and chase.combat.counter_slowmos == n0,
		"a counter on a heavy counts as 2 kicks: he wobbles on (hp %d, %s)" % [h.hp, h.state_name()])
	await _frames(90)
	h.hp = h.max_hp                          # whole again for the stick test


func _stick(s: BikerEnemy, heavy: BikerEnemy) -> void:
	# at chase speed (no teleport): the kicked stick flies into the rider's hands
	Input.action_press("gas")
	bike.current_speed_ms = 22.0
	await _frames(30)                            # up to speed first: _hold places him at the player's speed
	_hold(s, 0.0, 1.8)
	await _frames(25)
	var got: Array = []
	chase.combat.stick_picked.connect(func() -> void: got.append(chase.hud.popup_text))   # after the chase's own handler
	chase.combat.kick(1)
	var z_drop: float = INF
	var z_catch: float = INF
	for i0: int in 70:
		await physics_frame
		if z_drop == INF and s.stick_dropped:
			z_drop = bike.global_position.z
			_check(not s.stick.visible and chase.combat.drops.size() == 1 and chase.combat.stick_flying(), "the kicked stick rider lets go of his stick: it flies")
		if z_catch == INF and chase.combat.stick_picks > 0:
			z_catch = bike.global_position.z
	_check(chase.combat.stick_picks == 1 and chase.combat.stick_swings == BikeCombatData.STICK_SWINGS and got == [BikeCombatData.T_STICK_GOT],
		"caught at %.0f km/h: 3 swings (%d, %s)" % [absf(bike.current_speed_ms) * 3.6, chase.combat.stick_swings, str(got)])
	_check(z_drop != INF and z_catch != INF and z_drop - z_catch > 4.0, "the bike rode on %.1f m while it flew" % (z_drop - z_catch))
	# hands full: a second stick misses and lies on the road with its pickup ring
	chase.combat.drop_stick(bike.global_position + Vector3(2.0, 0.13, -2.0))
	await _frames(40)
	var d0: Dictionary = chase.combat.drops[0] if not chase.combat.drops.is_empty() else {}
	_check(not d0.is_empty() and not bool(d0["flying"]) and (d0["ring"] as Node3D).visible and chase.combat.stick_picks == 1, "hands full: the stick drops onto the road, ringed")
	chase.combat.clear_drops()
	# the heavy (3 kicks) beyond a kick's reach but inside the stick's
	_hold(heavy, 0.0, BikeCombatData.KICK_REACH + 0.6)
	await _frames(25)
	_check(chase.combat.kick_target(1) == heavy, "the stick reaches %.1f m (a kick: %.1f m)" % [BikeCombatData.KICK_REACH + 0.6, BikeCombatData.KICK_REACH])
	chase.combat.kick(1)
	await _frames(40)
	_check(chase.combat.stick_hits == 1 and heavy.hp == 1 and chase.combat.stick_swings == 2, "a swing hits like 2 kicks (heavy hp %d, %d swings left)" % [heavy.hp, chase.combat.stick_swings])
	var broke: Array = []
	chase.combat.stick_broke.connect(func() -> void: broke.append(chase.hud.popup_text))   # after the chase's own handler
	for i: int in 2:
		await _frames(30)
		if not heavy.is_down():
			_hold(heavy, 0.0, 1.8)
		await _frames(10)
		chase.combat.kick(1)
	await _frames(40)
	_check(chase.combat.stick_swings == 0 and broke.size() == 1 and broke[0] == BikeCombatData.T_STICK_BROKE, "the third swing breaks the stick (%s)" % str(broke))
	_check(heavy.is_down(), "the heavy went down (%s)" % heavy.state_name())
	Input.action_release("gas")
	bike.current_speed_ms = 0.0
	await _frames(30)


func _spin_and_hurt() -> void:
	await _frames(80)
	_check(chase.combat.spin_kick(1) and chase.combat.trail_visible(), "the spin kick shows its motion trail")
	await _frames(40)
	_check(not chase.combat.trail_visible(), "... and the trail is gone after the spin")
	# a hit on the player
	var clock: Impact = Impact.clock(chase)
	var e0: int = clock.edge_flashes
	var st0: float = chase.combat.stability
	chase.combat.iframes = 0.0
	chase.combat.damage(10.0, "kick", 1)
	_check(chase.combat.stability < st0 and clock.edge_flashes == e0 + 1 and clock.edge_strength() > 0.5, "a hit on the player: the red screen edge")
	_check(chase.combat.wobble_t > 0.4 and bike.camera_shake_trauma > 0.3, "... the bike wobbles, the camera shakes")
	await _frames(40)
	_check(chase.combat.wobble_t == 0.0, "the wobble ends")


func _finish() -> void:
	Engine.time_scale = 1.0
	RadialWheel.scale_owner = null
	if arena and is_instance_valid(arena):
		arena.free()
	if fails.is_empty():
		print("SUCCESS: BIKE FEEL (connect, wobble, crash parts, counter-kick, grab stick, spin trail, hit on the player)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
