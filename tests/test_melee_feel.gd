# File: res://tests/test_melee_feel.gd
# Headless test of the Q2 melee feel (plan 2026-10-29-q2-feel.md T2) on PlayerCombat / MeleeEnemy / MeleeFight:
#   - strike tiers: a jab is light, the heavy kick heavy, a knockout the finisher tier (Impact clock freezes 2 / 5 / 9 frames);
#   - directional reactions: hits from the front, back, left and right give react_front / react_back / react_l / react_r;
#   - heavy knockback (~1.5 m); slams into a wall, a table (PropBuilder.build_table) and a car (traffic_obstacle body):
#     SLAM_DMG, a second heavy impact, the surface's popup; a knockout is a comic flying tumble (off the floor, one floor
#     bounce, the body upright again after, stars);
#   - throws: [E] on a blocking enemy grabs and throws it ~3.5 m (THROW_DMG, knocked down, "QUẬT NGÃ"); a throw into a
#     second enemy downs both; [E] does nothing with nobody to grab;
#   - improvised weapons: every kind has 3-5 hits; a MeleeFight "props" chair is picked up with [E] (swings move set, the
#     controls hint), breaks comically after its 4 landed hits (pieces fly, unarmed again), retry() puts it back;
#   - the last enemy of a fight: its knockout gets the 0.5 s slow-motion orbit; hits on the player flash the screen edge.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_melee_feel.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var arena: Node3D
var player: ThirdPersonController
var combat: PlayerCombat
var sibs: Array = []


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
	print("--- TEST MELEE FEEL (Q2) ---")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _enemy(at: Vector3, stats: Dictionary = {}, face_player: bool = true) -> MeleeEnemy:
	var st: Dictionary = {"block_chance": 0.0, "dodge_chance": 0.0, "hp": 300.0, "stagger_max": 999.0}
	for k: String in stats.keys():
		st[k] = stats[k]
	var n := MeleeEnemy.new()
	n.name = "Feel%d" % sibs.size()
	n.setup("clone", {"stats": st, "seed": 11 + sibs.size(), "ai": false})
	n.top_level = true
	n.position = at
	arena.add_child(n)
	if face_player:
		var to: Vector3 = player.global_position - at
		n.set_yaw(atan2(-to.x, -to.z))
	n.bind(combat, null, sibs, combat.fx)
	sibs.append(n)
	combat.add_enemy(n)
	return n


func _drop(n: MeleeEnemy) -> void:
	combat.remove_enemy(n)
	sibs.erase(n)
	n.queue_free()


func _info(kind: String, dmg: float = 1.0, stagger: float = 5.0, push: float = 0.25, knockdown: bool = false) -> Dictionary:
	return {"kind": kind, "dmg": dmg, "stagger": stagger, "push": push, "breaks_block": kind == "heavy", "knockdown": knockdown,
		"from": player.global_position}


func _run() -> void:
	await _frames(1)
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena)
	player = World.player(arena, Vector3.ZERO, 0.0)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	combat.setup({"player": player})
	await _frames(3)
	await _tiers()
	await _reactions()
	await _slams()
	await _tumble()
	await _throws()
	await _props()
	await _last_and_player()
	_finish()


## A jab: light (2 frozen frames), the heavy kick: heavy (5), a knockout: the finisher tier (9).
func _tiers() -> void:
	var e: MeleeEnemy = _enemy(Vector3(0.0, 0.0, -1.3))
	await _frames(2)
	var clock: Impact = Impact.clock(combat)
	var expect: Array = [["jab", "light", 2], ["heavy", "heavy", 5]]
	for x: Array in expect:
		await _frames(30)
		combat._strike(e, _info(String(x[0]), 2.0, 5.0))
		var low: int = 0
		for i: int in 20:
			await physics_frame
			if Engine.time_scale < 0.5:
				low += 1
		_check(combat.tiers.back() == String(x[1]) and low == int(x[2]), "%s: tier %s, %d frozen frames (%s, %d)" % [x[0], x[1], int(x[2]), combat.tiers.back(), low])
	await _frames(30)
	e.hp = 1.0
	var r: String = combat._strike(e, _info("jab", 5.0))
	_check(r == "ko" and combat.tiers.back() == "finisher" and clock.last_hit.get("tier") == "finisher", "a knockout is the finisher tier (%s)" % r)
	await _frames(40)
	_drop(e)
	await _frames(2)


## Hits from the front, behind, the right and the left of the enemy give their own reaction.
func _reactions() -> void:
	var e: MeleeEnemy = _enemy(Vector3(0.0, 0.0, -1.3))
	# player at the origin, the enemy at -Z: yaw PI faces him; PI - 90 deg faces -X (the player on his left), PI + 90 deg +X
	var cases: Array = [[0.0, "react_front"], [PI, "react_back"], [-PI * 0.5, "react_l"], [PI * 0.5, "react_r"]]
	for c: Array in cases:
		await _frames(25)
		e.global_position = Vector3(0.0, 0.0, -1.3)
		e.push_v = Vector3.ZERO
		e.set_yaw(PI + float(c[0]))
		e._enter(MeleeEnemy.St.HOLD)
		await _frames(1)
		combat._strike(e, _info("jab", 1.0, 5.0))
		_check(e.last_reaction.begins_with(String(c[1])) and e.pose.pose_name == String(c[1]), "hit with the enemy turned %.0f deg: %s (%s)" % [rad_to_deg(float(c[0])), c[1], e.last_reaction])
	# heavy knockback
	await _frames(30)
	e.global_position = Vector3(0.0, 0.0, -1.3)
	e.set_yaw(PI)
	e._enter(MeleeEnemy.St.HOLD)
	e.push_v = Vector3.ZERO
	await _frames(1)
	var z0: float = e.global_position.z
	combat._strike(e, _info("heavy", 2.0, 5.0, 1.2))
	await _frames(60)
	var moved: float = absf(e.global_position.z - z0)
	_check(moved > 1.2 and moved < 2.2, "the heavy tier knocks him about 1.5 m back (%.2f m)" % moved)
	_drop(e)
	await _frames(2)


## Knocked into a wall, a table and a car: a slam each.
func _slams() -> void:
	var cases: Array = ["wall", "table", "car"]
	for i: int in cases.size():
		var surface: String = cases[i]
		var x0: float = 20.0 * float(i + 1)
		player.teleport(Vector3(x0, 0.0, 0.0), 0.0)
		combat.revive()
		var blocker: Node3D
		match surface:
			"wall":
				blocker = World.wall(arena, Vector3(x0, 1.0, -2.6), Vector3(4.0, 2.0, 0.2))
			"table":
				blocker = PropBuilder.build_table(arena, Vector3(x0, 0.0, -3.2), Vector3(3.0, 0.76, 1.2))
			"car":
				var b := AnimatableBody3D.new()
				b.name = "Car"
				b.add_to_group("traffic_obstacle")
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(4.0, 1.5, 1.8)
				cs.shape = bs
				cs.position = Vector3(0.0, 0.75, 0.0)
				b.add_child(cs)
				b.position = Vector3(x0, 0.0, -3.4)
				arena.add_child(b)
				blocker = b
		var e: MeleeEnemy = _enemy(Vector3(x0, 0.0, -1.3))
		await _frames(25)
		var hp0: float = e.hp
		var hits0: int = Impact.clock(combat).hits
		var got: Array = []
		e.slammed.connect(func(_e: MeleeEnemy, s: String) -> void: got.append(s))
		combat._strike(e, _info("heavy", 2.0, 5.0, 1.2))
		await _frames(50)
		_check(e.slams == 1 and e.last_slam == surface and got == [surface], "knocked into a %s: a slam (%d, %s)" % [surface, e.slams, e.last_slam])
		_check(is_equal_approx(e.hp, hp0 - 2.0 - CombatData.SLAM_DMG) and e.st == MeleeEnemy.St.KNOCKDOWN, "the slam hurts %d and knocks him down (hp %.0f, %s)" % [int(CombatData.SLAM_DMG), e.hp, e.state_name()])
		_check(Impact.clock(combat).hits >= hits0 + 2 and combat.hud.popup_text == String(CombatData.T_SLAM[surface]), "a second impact and '%s'" % combat.hud.popup_text)
		_drop(e)
		blocker.queue_free()
		await _frames(5)
	player.teleport(Vector3.ZERO, 0.0)
	combat.revive()
	await _frames(3)


## A knockout: the comic flying tumble with one floor bounce, the body upright again after, stars.
func _tumble() -> void:
	var e: MeleeEnemy = _enemy(Vector3(0.0, 0.0, -1.3))
	await _frames(25)
	e.hp = 1.0
	var y0: float = e.global_position.y
	var rim0: int = Readability.rimmed_count(e.body)
	var r: String = combat._strike(e, _info("heavy", 5.0, 5.0, 1.2))
	_check(rim0 > 0 and Readability.rimmed_count(e.body) == 0, "integration: the knockout drops the Q3 rim (%d -> %d)" % [rim0, Readability.rimmed_count(e.body)])
	var top: float = 0.0
	var flipped: float = 0.0
	for i: int in 120:
		await physics_frame
		top = maxf(top, e.global_position.y - y0)
		flipped = maxf(flipped, absf(e.body.rotation.x))
	_check(r == "ko" and e.tumbles == 1 and top > 0.3, "the knockout tumbles off the floor (%.2f m up)" % top)
	_check(e.bounces == 1 and not e.tumbling and flipped > 0.5, "one floor bounce, flipped in the air, then lying still (%d, %.2f rad)" % [e.bounces, flipped])
	_check(e.body.position.is_zero_approx() and is_zero_approx(e.body.rotation.x), "the body is upright on its root again (the Death pose lies it down)")
	_check(combat.fx.cine.find_children("Star*", "", true, false).size() >= 3, "knockout stars")
	_check(e.global_position.distance_to(Vector3(0.0, 0.0, -1.3)) > 1.5, "it flew back (%.1f m)" % e.global_position.distance_to(Vector3(0.0, 0.0, -1.3)))
	_drop(e)
	await _frames(3)


func _throws() -> void:
	combat.revive()
	player.teleport(Vector3.ZERO, 0.0)
	await _frames(2)
	combat.finisher_override = true
	await _frames(3)
	_check(combat.state == PlayerCombat.St.IDLE and combat.throws == 0, "[E] with nobody to grab or pick up does nothing")
	var e: MeleeEnemy = _enemy(Vector3(0.0, 0.0, -1.2))
	await _frames(20)
	e.force_block(3.0)
	_check(e.can_be_thrown() and combat.throw_target() == e, "a blocking enemy within 1.5 m can be grabbed")
	combat.fight_active = true                   # the combat HUD shows
	await _frames(2)
	_check(combat.hud.throw_shown and combat.hud.throw_node == e and not combat.hud.finisher_shown, "'%s' shows under him" % CombatData.T_THROW_PROMPT)
	combat.fight_active = false
	var p0: Vector3 = e.global_position
	var hp0: float = e.hp
	combat.finisher_override = true
	await _frames(3)
	_check(combat.state == PlayerCombat.St.THROW and e.st == MeleeEnemy.St.HELD, "[E] grabs him (throw beats block)")
	await _frames(70)
	var d: float = e.global_position.distance_to(p0)
	_check(e.throws_taken == 1 and is_equal_approx(e.hp, hp0 - CombatData.THROW_DMG) and (e.st == MeleeEnemy.St.KNOCKDOWN or e.st == MeleeEnemy.St.HOLD), "thrown: %d damage, knocked down (%s)" % [int(CombatData.THROW_DMG), e.state_name()])
	_check(d > 2.5 and d < 5.0, "he flew about 3.5 m (%.1f m)" % d)
	_check(combat.throws == 1 and combat.results_of("throw") == ["thrown"] and combat.hud.popup_text == CombatData.T_THROW, "the throw is logged, 'QUẬT NGÃ'")
	await _frames(150)
	# a throw into a second enemy: both go down
	player.teleport(Vector3.ZERO, 0.0)
	e.global_position = Vector3(0.0, 0.0, -1.2)
	e.push_v = Vector3.ZERO
	e.set_yaw(PI)
	e._enter(MeleeEnemy.St.HOLD)
	var e2: MeleeEnemy = _enemy(Vector3(0.0, 0.0, -3.4))
	await _frames(20)
	e.force_block(3.0)
	combat.finisher_override = true
	await _frames(80)
	_check(e.last_slam == "enemy" and e2.st == MeleeEnemy.St.KNOCKDOWN, "thrown into another enemy: both go down (%s, %s)" % [e.last_slam, e2.state_name()])
	_drop(e)
	_drop(e2)
	await _frames(3)
	# Sói Xám (a boss): only staggered can he be thrown, and a throw over his howl line still makes him howl (on the get-up)
	player.teleport(Vector3.ZERO, 0.0)
	var w := MeleeEnemy.new()
	w.name = "FeelWolf"
	w.setup("soi_xam", {"stats": {"block_chance": 0.0, "dodge_chance": 0.0}, "seed": 21, "ai": false})
	w.top_level = true
	w.position = Vector3(0.0, 0.0, -1.2)
	arena.add_child(w)
	w.set_yaw(PI)
	w.bind(combat, null, sibs, combat.fx)
	sibs.append(w)
	combat.add_enemy(w)
	await _frames(20)
	w.force_block(1.0)
	_check(not w.can_be_thrown(), "a boss in his guard cannot be grabbed")
	await _frames(70)
	w.hp = w.max_hp * float(w.stats["howl_at"]) + 5.0
	combat._strike(w, _info("jab", 1.0, 5.0))
	combat.finisher_override = true
	await _frames(3)
	_check(combat.state == PlayerCombat.St.THROW and w.st == MeleeEnemy.St.HELD, "staggered, he is grabbed")
	await _frames(170)
	_check(w.throws_taken == 1 and w.howls == 1, "thrown under his howl line: he howls after getting up (%d, %s)" % [w.howls, w.state_name()])
	_drop(w)
	await _frames(3)


func _props() -> void:
	for k: String in ImprovisedWeapon.KINDS.keys():
		var h: int = int(ImprovisedWeapon.KINDS[k]["hits"])
		_check(h >= 3 and h <= 5, "%s breaks after %d hits (3-5)" % [k, h])
	for k2: String in ["chair", "tray", "helmet", "lid"]:
		_check(ImprovisedWeapon.KINDS.has(k2), "improvised weapon %s exists" % k2)
	_check(_plain(CombatData.T_THROW) and _plain(CombatData.T_PROP_BREAK) and _plain(CombatData.T_CONTROLS_PROP), "plain texts")
	player.teleport(Vector3.ZERO, 0.0)
	combat.revive()
	var fight := MeleeFight.new()
	fight.name = "PropFight"
	arena.add_child(fight)
	fight.setup({"player": player, "combat": combat, "force_unarmed": false,
		"props": [{"kind": "chair", "at": Vector3(0.0, 0.0, 1.0)}]})
	fight.add_wave([{"archetype": "clone", "at": Vector3(0.0, 0.0, -1.5), "opts": {"ai": false, "stats": {"hp": 400.0, "stagger_max": 999.0, "block_chance": 0.0, "dodge_chance": 0.0}}}])
	fight.start()
	await _frames(3)
	var chair: ImprovisedWeapon = fight.props[0]
	_check(combat.props.has(chair) and chair.can_pick() and combat.prop_target() == chair, "the fight's chair lies on the floor, in reach")
	_check(combat.hud.prop_shown and combat.hud.prop_node == chair, "'%s' shows over it" % (CombatData.T_PICKUP % chair.display_name()))
	combat.finisher_override = true
	await _frames(3)
	_check(combat.held_prop == chair and chair.state == "held" and String(combat.light_moves[0]["id"]) == "prop_swing" and combat.controls_text == CombatData.T_CONTROLS_PROP,
		"[E] picks it up: the swing move set and its hint")
	_check(not chair.ring.visible and chair.model.get_parent() is BoneAttachment3D, "in the right hand, the pickup ring hidden")
	var e: MeleeEnemy = fight.enemies[0]
	player.model.rotation.y = 0.0
	var hp0: float = e.hp
	var landed: int = 0
	for i: int in 12:
		if combat.held_prop == null:
			break
		e.global_position = Vector3(0.0, 0.0, -1.5)
		e.push_v = Vector3.ZERO
		e._enter(MeleeEnemy.St.HOLD)
		combat.light_override = true
		await _frames(45)
		landed = combat.results_of("prop_swing").size() + combat.results_of("prop_swing_b").size()
	_check(landed == 4 and combat.prop_breaks == 1 and chair.state == "broken" and combat.held_prop == null, "the chair breaks after its 4 landed hits (%d, %s)" % [landed, chair.state])
	_check(e.hp < hp0 - 40.0 and combat.tiers.slice(-4).count("heavy") >= 3, "each swing hits like a heavy (hp %.0f)" % e.hp)
	_check(combat.light_moves == CombatData.LIGHT and combat.hud.popup_text == CombatData.T_PROP_BREAK, "unarmed again, 'GÃY RỒI'")
	_check(chair.pieces_alive() == 0 or chair.breaks == 1, "comic pieces flew (%d left)" % chair.pieces_alive())
	fight.retry()
	await _frames(3)
	_check(chair.state == "ground" and chair.hits_left == 4 and chair.global_position.is_equal_approx(Vector3(0.0, 0.0, 1.0)) and chair.model.visible, "retry() puts the chair back, whole")
	fight.stop()
	await _frames(2)
	_check(fight.props.is_empty() and combat.props.is_empty(), "stop() removes the props")
	fight.queue_free()
	await _frames(3)


func _last_and_player() -> void:
	player.teleport(Vector3.ZERO, 0.0)
	combat.revive()
	var fight := MeleeFight.new()
	fight.name = "LastFight"
	arena.add_child(fight)
	fight.setup({"player": player, "combat": combat, "force_unarmed": false})
	fight.add_wave([{"archetype": "clone", "at": Vector3(0.0, 0.0, -1.3), "opts": {"ai": false, "stats": {"block_chance": 0.0, "dodge_chance": 0.0}}},
		{"archetype": "clone", "at": Vector3(3.0, 0.0, -1.3), "opts": {"ai": false, "stats": {"block_chance": 0.0, "dodge_chance": 0.0}}}])
	fight.start()
	await _frames(3)
	var a: MeleeEnemy = fight.enemies[0]
	var b: MeleeEnemy = fight.enemies[1]
	var clock: Impact = Impact.clock(combat)
	var orbits0: int = clock.orbit_count
	a.hp = 1.0
	combat._strike(a, _info("jab", 5.0))
	await _frames(30)
	_check(clock.orbit_count == orbits0 and combat.is_last(b), "not the last: no orbit; the other one is the last")
	b.global_position = Vector3(0.0, 0.0, -1.3)
	b.hp = 1.0
	combat._strike(b, _info("jab", 5.0))
	var slow: int = 0
	for i: int in 50:
		await physics_frame
		if Engine.time_scale > 0.1 and Engine.time_scale < 0.5:
			slow += 1
	_check(clock.orbit_count == orbits0 + 1 and slow >= 28 and slow <= 31, "the last enemy's knockout: the 0.5 s slow-motion orbit (%d frames)" % slow)
	await _frames(10)
	_check(fight.state == "won" and combat.last_fn.is_valid() == false, "won; last_fn cleared")
	fight.stop()
	fight.queue_free()
	await _frames(2)
	# hits on the player
	var e: MeleeEnemy = _enemy(Vector3(0.0, 0.0, -1.0))
	await _frames(20)
	var fl0: int = clock.edge_flashes
	e.force_attack("light")
	await _frames(40)
	_check(e.results.back() == "hit" and clock.edge_flashes == fl0 + 1, "a hit on the player flashes the screen edge (%s)" % str(e.results))
	_drop(e)
	await _frames(2)


static func _plain(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c > 0x2000:
			return false
	return true


func _finish() -> void:
	Engine.time_scale = 1.0
	RadialWheel.scale_owner = null
	if arena and is_instance_valid(arena):
		arena.free()
	if fails.is_empty():
		print("SUCCESS: MELEE FEEL (tiers, directional reactions, knockback, slams, tumble, throws, improvised weapons, last-enemy orbit)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
