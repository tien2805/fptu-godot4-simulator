# File: res://tests/test_d2_guidance.gd
# Headless test of the Day 2 playtest fixes (plan 2026-10-30-d2-playtest-fixes.md): a first-time player must always see
# where to go and where the enemies are.
#   0 data: RouteGuide texts plain; find_turns on an L route (one right turn of about 90 degrees) and its mirror (left);
#     the real chase route has its turns, the race's lap junction turns match the race's own prompts (right for lap 2,
#     left for home); ViceRadar keeps the guide route's near segments and the extra blips.
#   A (arena chase on an L route, a real PlayerBike moved by the test): the guide is on while running; chevrons lit only
#     ahead (from CHEV_NEAR to CHEV_FAR); the turn panel appears TURN_SHOW_M before the turn ("RẼ PHẢI", the distance), not
#     earlier, and the pass counts as announced; edge arrows: a biker behind the camera gets one (bottom half), a biker in
#     front is on screen without one; the radar dots; the leash: AI bikers forced 45 m ahead / 30 m behind come back inside
#     LEASH_AHEAD / LEASH_BEHIND, and over a ride with the player at nitro speed none leaves the band; a flanker settles in
#     a slot inside kick reach and holds it >= HOLD_MIN before its wind-up; kick assist: a biker 3.2 m to the side and
#     2.5 m ahead (outside the plain leg's reach) is pulled in and kicked, one 4 m out is a miss; a wave of 6 never has more
#     than MAX_ALIVE riding, arrivals honk and come from behind inside the leash; the bike camera's combat framing eases in
#     near the bikers (+height, +distance, +FOV) and out after stop().
#   B (arena race on DriftCourse): the guide with the Sói Xám marker on screen, his edge arrow (with his name) behind the
#     camera; his lead capped at RIVAL_LEASH_M; the turn panel before the Y junction ("CUA GẮT TRÁI"); the kick assist
#     pulls him in.
# Run:  godot --headless --path . --script tests/test_d2_guidance.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const Z0: float = 250.0
const TURN_Z: float = -300.0              # the L route turns east here (s = 550)

var fails: Array[String] = []
var arena: Node3D
var bike: PlayerBike
var chase: BikeChase
var duel: DriftDuel
var drive_s: float = 0.0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  x ", msg)
	else:
		print("  ok ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST D2 GUIDANCE (route line, turn arrows, edge arrows, leash, kick assist, race leash) ---")
	PlayerBike.sfx_dir = OS.get_cache_dir().replace("\\", "/").trim_suffix("/") + "/fptu_test_d2guide_no_sfx/"
	PlayerBike.clear_owner_sfx()
	Difficulty.set_easy(false)
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
	Difficulty.set_easy(false)
	_part_0()
	await _part_a()
	await _part_b()
	_finish()


static func _plain(s: String) -> bool:
	for i: int in s.length():
		if s.unicode_at(i) >= 0x2000:
			return false
	return true


# ---------------------------------------------------------------------------
# 0: data
# ---------------------------------------------------------------------------
func _part_0() -> void:
	for t: String in RouteGuide.texts():
		_check(_plain(t), "plain text: '%s'" % t)
	var r: BikeRoute = BikeRoute.from_points([Vector2(0.0, Z0), Vector2(0.0, TURN_Z), Vector2(400.0, TURN_Z)])
	var tl: Array = RouteGuide.find_turns(r, r.length)
	_check(tl.size() == 1 and int(tl[0][1]) == 1 and absf(float(tl[0][0]) - 550.0) < 6.0 and absf(float(tl[0][2]) - 90.0) < 3.0,
		"an L route north then east: one right turn of 90 degrees at s 550 (%s)" % str(tl))
	var r2: BikeRoute = BikeRoute.from_points([Vector2(0.0, Z0), Vector2(0.0, TURN_Z), Vector2(-400.0, TURN_Z)])
	var tl2: Array = RouteGuide.find_turns(r2, r2.length)
	_check(tl2.size() == 1 and int(tl2[0][1]) == -1, "its mirror turns left (%s)" % str(tl2))
	_check(RouteGuide.turn_label(1.0, 90.0) == RouteGuide.T_RIGHT and RouteGuide.turn_label(-1.0, 150.0) == RouteGuide.T_SHARP_LEFT, "turn labels")
	var md: MapData = MapData.load_default()
	var dr: BikeRoute = MissionBikeChase.day2_route(md)
	var dt: Array = RouteGuide.find_turns(dr, dr.bridge_s + MissionBikeChase.END_PAST_M)
	var after_start: int = 0
	for t2: Array in dt:
		if float(t2[0]) > MissionBikeChase.START_S + RouteGuide.TURN_ANNOUNCE_M:
			after_start += 1
	_check(after_start >= 8, "the chase route has its real turns (%d after the start)" % after_start)
	var c: DriftCourse = DriftCourse.rach_ham()
	var ct: Array = RouteGuide.find_turns(c, c.length)
	var lap2: int = 0
	var home: int = 0
	for t3: Array in ct:
		if absf(float(t3[0]) - c.lap_s[1]) < 25.0:
			lap2 = int(t3[1])
		if absf(float(t3[0]) - c.lap_s[2]) < 25.0:
			home = int(t3[1])
	_check(ct.size() >= 7 and lap2 == 1 and home == -1, "the race: %d turns, right into lap 2 and left for home like its prompts (%d, %d)" % [ct.size(), lap2, home])
	var rad := ViceRadar.new()
	rad.md = md
	rad.size = Vector2(200.0, 200.0)
	rad.center = dr.point(500.0)
	var pts := PackedVector2Array()
	for k: int in 60:
		pts.append(dr.point(float(k) * 10.0 + 300.0))
	rad.guide_route = pts
	_check(rad._guide_near.size() >= 20, "ViceRadar keeps the guide route's near segments (%d points)" % rad._guide_near.size())
	var eb: Array[Dictionary] = [{"pos": dr.point(510.0), "color": Color.RED, "on": true}]
	rad.extra_blips = eb
	_check(rad.extra_blips.size() == 1, "ViceRadar takes extra blips")
	rad.guide_route = PackedVector2Array()
	_check(rad._guide_near.is_empty(), "clearing the guide route clears its segments")
	rad.free()


# ---------------------------------------------------------------------------
# A: the chase
# ---------------------------------------------------------------------------
func _build_arena() -> void:
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena, 4000.0)
	bike = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
	bike.name = "Bike"
	bike.lane_clamp_enabled = false
	bike.fallback_fall_y = -5.0
	arena.add_child(bike)
	bike.global_position = Vector3(0.0, -0.13, 190.0)
	bike.chase_cam.make_current()


## The bike on the chase route at s, facing along it, moving at v (the test drives it).
func _put(s: float, v: float = 24.0, d: float = 0.0) -> void:
	drive_s = s
	var p: Vector2 = chase.route.world(s, d)
	var tg: Vector2 = chase.route.tangent(s)
	bike.global_position = Vector3(p.x, -0.13, p.y)
	bike.rotation = Vector3(0.0, atan2(-tg.x, -tg.y), 0.0)
	bike.current_speed_ms = v
	bike.velocity = Vector3(tg.x, 0.0, tg.y) * v


func _ride(to_s: float, v: float, each: Callable = Callable()) -> void:
	var n: int = 0
	while drive_s < to_s and n < 20000:
		_put(minf(drive_s + v / 60.0, to_s), v)
		await _frames(1)
		if each.is_valid():
			each.call()
		n += 1


func _new_chase(waves: Array, opts: Dictionary = {}) -> BikeChase:
	if chase and is_instance_valid(chase):
		chase.stop()
		chase.queue_free()
		await _frames(2)
	var c := BikeChase.new()
	c.name = "Chase"
	arena.add_child(c)
	var o: Dictionary = {"bike": bike, "route": [Vector2(0.0, Z0), Vector2(0.0, TURN_Z), Vector2(400.0, TURN_Z)], "start_s": 60.0,
		"manual_replay": true, "auto_replay": false, "seed": 5}
	o.merge(opts, true)
	c.setup(o)
	for w: Variant in waves:
		c.add_wave(w)
	chase = c
	return c


func _hold(b: BikerEnemy, along: float, lat: float) -> void:
	b.hold_along = along
	b.hold_lat = lat
	var p: Vector2 = chase.target_at(along, lat)
	b.place(Vector3(p.x, 0.0, p.y), bike.rotation.y, chase.p_vel.length())


func _part_a() -> void:
	_build_arena()
	await _frames(2)
	# --- guide: chevrons, turn panel ---
	var held: Array = []
	for i: int in 2:
		held.append({"lane": [-1, 1][i], "opts": {"ai": false, "label": "H%d" % i, "hp": 9}})
	await _new_chase([held])
	chase.start()
	chase.combat.god = true
	_put(60.0)
	await _frames(1)
	var g: RouteGuide = chase.guide
	_check(g != null and g.active and g.mmi.visible and g.hud.visible, "the guide is on while the chase runs")
	_check(g.turns.size() == 1 and int(g.turns[0][1]) == 1, "the guide knows the route's right turn")
	await _ride(130.0, 24.0)
	_check(g.lit >= 12 and g.lit_near >= RouteGuide.CHEV_NEAR - 0.01 and g.lit_far <= RouteGuide.CHEV_FAR + 0.01 and g.lit_far >= 80.0,
		"chevrons glow on the road ahead only (%d lit, %.1f .. %.1f m ahead)" % [g.lit, g.lit_near, g.lit_far])
	var behind_lit: bool = false
	for i2: int in RouteGuide.CHEV_N:
		var col: Color = g.mm.get_instance_color(i2)
		if col.a > 0.01:
			var o3: Vector3 = g.mm.get_instance_transform(i2).origin
			var pr: Vector2 = chase.route.project(Vector2(o3.x, o3.z), chase.s_p)
			if pr.x < chase.s_p + 1.0:
				behind_lit = true
	_check(not behind_lit, "no chevron lit under or behind the bike")
	var apex: float = float(g.turns[0][0])
	await _ride(apex - RouteGuide.TURN_SHOW_M - 15.0, 24.0)
	_check(not g.turn_visible, "no turn panel %.0f m before the turn" % (apex - chase.s_p))
	await _ride(apex - 150.0, 24.0)
	_check(g.turn_visible and g.turn_text == RouteGuide.T_RIGHT and g.turn_dist_text.ends_with(" m") and g.turn_dir == 1,
		"150 m before: the turn panel '%s %s'" % [g.turn_text, g.turn_dist_text])
	await _ride(apex + 10.0, 24.0)
	_check(g.turn_passes == 1 and g.turn_announced == 1, "the turn passed with the arrow shown in time (%d / %d)" % [g.turn_announced, g.turn_passes])
	# --- edge arrows ---
	_put(150.0)
	chase._hint = -1.0                       # a 400 m jump back along the same line: search the whole route
	await _frames(2)
	_hold(chase.bikers[0], -8.0, 0.0)        # behind the camera
	_hold(chase.bikers[1], 9.0, 1.0)         # in front
	await _frames(3)
	var vs: Vector2 = bike.get_viewport().get_visible_rect().size
	_check(g.edge_count == 1 and g.edge_pos[0].y > vs.y * 0.5 and g.on_screen_n == 1 and g.active_n == 2,
		"a biker behind the camera: one red edge arrow at the bottom; the one in front is on screen (%d arrows, %d on screen)" % [g.edge_count, g.on_screen_n])
	_hold(chase.bikers[0], -6.0, -3.5)
	await _frames(3)
	_check(g.edge_count == 1 and g.edge_pos[0].x < vs.x * 0.5, "behind on the left: the arrow on the left (%s)" % str(g.edge_pos[0] if g.edge_count > 0 else Vector2.ZERO))
	var fake := Node.new()
	fake.set_script(_fake_roam_script())
	root.add_child(fake)
	var rad := ViceRadar.new()
	rad.md = MapData.load_default()
	fake.set("vice_hud", {"radar": rad})
	var vh := Node.new()
	vh.set_script(_fake_hud_script())
	root.add_child(vh)
	vh.set("radar", rad)
	fake.set("vice_hud", vh)
	g.roam = fake
	g._radar = null
	g.set_active(true)
	await _frames(8)
	_check(rad.guide_route.size() > 10 and g.blips_on() == 2 and rad.extra_blips.size() >= 2, "the radar: the route and a red dot per biker (%d dots)" % g.blips_on())
	chase.stop()
	_check(rad.guide_route.is_empty() and g.blips_on() == 0, "stop(): the radar route and the dots are cleared")
	g.roam = null
	g._radar = null
	rad.free()
	vh.queue_free()
	fake.queue_free()
	# --- leash ---
	var ai_w: Array = []
	for i3: int in 3:
		ai_w.append({"lane": [-1, 1, 0][i3], "opts": {"label": "L%d" % i3, "hp": 9, "aggression": 0.5}})
	await _new_chase([ai_w])
	chase.start()
	chase.combat.god = true
	_put(60.0)
	await _frames(30)
	var far: BikerEnemy = chase.bikers[0]
	far.pos2 = chase.target_at(45.0, -1.0)
	var back: BikerEnemy = chase.bikers[1]
	back.pos2 = chase.target_at(-30.0, 1.0)
	await _frames(1)
	var al_f: float = (far.pos2 - chase.p_pos).dot(chase.p_fwd)
	var al_b: float = (back.pos2 - chase.p_pos).dot(chase.p_fwd)
	_check(al_f <= BikeCombatData.LEASH_AHEAD + 0.5 and al_b >= -BikeCombatData.LEASH_BEHIND - 0.5, "forced 45 m ahead / 30 m behind: back at the band at once (%.1f, %.1f)" % [al_f, al_b])
	var worst: Array = [0.0, 0.0]
	var watch: Callable = func() -> void:
		for b: Variant in chase.bikers:
			var e: BikerEnemy = b as BikerEnemy
			if e != null and e.is_active():
				var al: float = (e.pos2 - chase.p_pos).dot(chase.p_fwd)
				worst[0] = maxf(float(worst[0]), al)
				worst[1] = minf(float(worst[1]), al)
	await _ride(260.0, 24.0, watch)
	await _ride(420.0, 38.0, watch)          # nitro speed: they must keep up
	_check(float(worst[0]) <= BikeCombatData.LEASH_AHEAD + 0.5 and float(worst[1]) >= -BikeCombatData.LEASH_BEHIND - 0.5,
		"riding at 24 then 38 m/s: every biker stays within %.0f m ahead / %.0f m behind (%.1f .. %.1f)" % [BikeCombatData.LEASH_AHEAD, BikeCombatData.LEASH_BEHIND, float(worst[1]), float(worst[0])])
	var near_one: bool = false
	for b2: Variant in chase.bikers:
		if (b2 as BikerEnemy).pos2.distance_to(chase.p_pos) < 12.0:
			near_one = true
	_check(near_one, "after the nitro burst the bikers are still around the player")
	# --- the hold window in a slot inside kick reach ---
	var one: Array = [{"lane": 1, "opts": {"label": "F", "hp": 9, "aggression": 0.9}}]
	await _new_chase([one])
	chase.start()
	chase.combat.god = true
	_put(60.0)
	var f: BikerEnemy = chase.bikers[0]
	var hm: Dictionary = {"settled": -1.0, "windup": -1.0, "lat": 0.0, "t": 0.0}
	var hw: Callable = func() -> void:
		hm["t"] = float(hm["t"]) + 1.0 / 60.0
		if f.st == BikerEnemy.St.PACE and f.settled_t > 0.0 and float(hm["settled"]) < 0.0:
			hm["settled"] = hm["t"]
		if float(hm["settled"]) >= 0.0 and float(hm["windup"]) < 0.0:
			if f.st == BikerEnemy.St.WINDUP:
				hm["windup"] = hm["t"]
			else:
				hm["lat"] = maxf(float(hm["lat"]), absf((f.pos2 - chase.p_pos).dot(chase.p_right)))
	await _ride(260.0, 22.0, hw)
	var held_s: float = float(hm["windup"]) - float(hm["settled"])
	_check(float(hm["settled"]) >= 0.0 and float(hm["windup"]) > 0.0 and held_s >= BikeCombatData.HOLD_MIN * 0.9 - 0.05,
		"a flanker settles beside the player and holds %.2f s before winding up (>= %.1f)" % [held_s, BikeCombatData.HOLD_MIN * 0.9])
	_check(float(hm["lat"]) > 1.5 and float(hm["lat"]) <= BikeCombatData.KICK_REACH, "its slot is inside the kick reach (%.2f m to the side)" % float(hm["lat"]))
	# --- kick assist ---
	await _new_chase([held.duplicate(true)])
	chase.start()
	chase.combat.god = true
	_put(80.0, 0.0)
	await _frames(2)
	bike.is_controls_locked = false
	_hold(chase.bikers[0], 2.5, 3.2)          # outside the plain leg (2.8 / 1.7), inside the assist zone
	_hold(chase.bikers[1], 0.0, -6.0)
	await _frames(2)
	var hits0: int = chase.combat.hits
	_check(chase.combat.kick_target(1) == chase.bikers[0], "the assist picks the biker 3.2 m to the side and 2.5 m ahead")
	_check(chase.combat.kick(1), "[E] kicks")
	await _frames(24)
	_check(chase.combat.hits == hits0 + 1 and (chase.bikers[0] as BikerEnemy).magnets == 1 and chase.combat.assists >= 1, "it is pulled in and the kick lands (hits %d, magnets %d)" % [chase.combat.hits - hits0, (chase.bikers[0] as BikerEnemy).magnets])
	await _frames(40)
	_hold(chase.bikers[1], 0.0, -4.0)
	await _frames(2)
	var miss0: int = chase.combat.misses
	chase.combat.kick(-1)
	await _frames(24)
	_check(chase.combat.misses == miss0 + 1, "a biker 4 m out is a miss")
	# --- max alive, arrivals from behind, combat framing ---
	var six: Array = []
	for i4: int in 6:
		six.append({"from": "behind", "lane": [-1, 1, 0][i4 % 3], "delay": 0.2 * float(i4), "opts": {"label": "M%d" % i4, "hp": 1}})
	await _new_chase([six])
	chase.start()
	chase.combat.god = true
	_put(60.0)
	var most: Array = [0, 99.0]
	var cnt: Callable = func() -> void:
		most[0] = maxi(int(most[0]), chase.alive_count())
		for b3: Variant in chase.bikers:
			if (b3 as BikerEnemy).st_t < 0.02:
				most[1] = minf(float(most[1]), ((b3 as BikerEnemy).pos2 - chase.p_pos).dot(chase.p_fwd))
	await _ride(160.0, 22.0, cnt)
	_check(int(most[0]) <= BikeCombatData.MAX_ALIVE and chase.alive_count() == BikeCombatData.MAX_ALIVE and chase.pending.size() == 2,
		"a wave of 6: at most %d ride at once, the rest wait (%d riding, %d waiting)" % [BikeCombatData.MAX_ALIVE, chase.alive_count(), chase.pending.size()])
	_check(chase.arrivals == 4, "each arrival honks (%d)" % chase.arrivals)
	_check(bike.cam_rig.combat_on and bike.cam_rig.combat_k > 0.95, "bikers near: the camera's combat framing is on (k %.2f)" % bike.cam_rig.combat_k)
	(chase.bikers[0] as BikerEnemy).crash("kick")
	await _ride(220.0, 22.0, cnt)
	_check(chase.pending.size() == 1 and int(most[0]) <= BikeCombatData.MAX_ALIVE, "one down: the next rider comes (%d waiting)" % chase.pending.size())
	_check(float(most[1]) >= -BehindMax() - 0.1, "every rider arrived from inside the leash (furthest back %.1f m)" % float(most[1]))
	chase.stop()
	await _frames(50)
	_check(not bike.cam_rig.combat_on and bike.cam_rig.combat_k < 0.05, "after stop() the framing eases back (k %.2f)" % bike.cam_rig.combat_k)
	var fov_d: float = CameraRules.BIKE_COMBAT_FOV
	_check(fov_d >= 5.0 and CameraRules.BIKE_COMBAT_UP > 0.3 and CameraRules.BIKE_COMBAT_DIST > 0.6, "combat framing: +%.1f m up, +%.1f m back, +%.0f deg" % [CameraRules.BIKE_COMBAT_UP, CameraRules.BIKE_COMBAT_DIST, fov_d])
	chase.queue_free()
	chase = null
	arena.queue_free()
	await _frames(3)


static func BehindMax() -> float:
	return BikeChase.BEHIND_MAX


static func _fake_roam_script() -> GDScript:
	var sc := GDScript.new()
	sc.source_code = "extends Node\nvar vice_hud: Variant = null\n"
	sc.reload()
	return sc


static func _fake_hud_script() -> GDScript:
	var sc := GDScript.new()
	sc.source_code = "extends Node\nvar radar: Variant = null\n"
	sc.reload()
	return sc


# ---------------------------------------------------------------------------
# B: the race
# ---------------------------------------------------------------------------
func _drive(s: float, d: float = 0.0, v: float = 20.0) -> void:
	drive_s = s
	var c: DriftCourse = duel.course
	var p: Vector2 = c.world(s, d)
	var y: Variant = duel.floor_at(Vector3(p.x, 0.0, p.y), 20.0, 20.0)
	bike.global_position = Vector3(p.x, (float(y) if y is float else 0.0) - DriftDuel.BIKE_FLOOR_OFFSET, p.y)
	bike.rotation = Vector3(0.0, c.yaw_at(s), 0.0)
	bike.current_speed_ms = v
	var t: Vector2 = c.tangent(s) * v
	bike.velocity = Vector3(t.x, 0.0, t.y)


func _part_b() -> void:
	arena = Node3D.new()
	arena.name = "Arena2"
	root.add_child(arena)
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(700.0, 1.0, 700.0)
	cs.shape = bs
	fl.add_child(cs)
	fl.position = Vector3(1915.0, -0.5, 10.0)
	arena.add_child(fl)
	bike = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
	arena.add_child(bike)
	bike.chase_cam.make_current()
	duel = DriftDuel.new()
	duel.name = "Duel"
	arena.add_child(duel)
	duel.setup({"bike": bike, "intro": false, "props": false})
	await _frames(2)
	duel.start()
	var g: RouteGuide = duel.guide
	_check(g != null and g.active and g.boss == duel.rival, "the race's guide is on from the countdown, Sói Xám its boss")
	for i: int in 200:
		await _frames(1)
		if duel.state == "racing":
			break
	_check(duel.state == "racing" and is_equal_approx(duel.rival.lead_cap, DriftDuel.RIVAL_LEASH_M), "racing; his lead is capped at %.0f m" % DriftDuel.RIVAL_LEASH_M)
	bike.is_controls_locked = true
	duel.rival.kick_cd = 99.0
	_drive(40.0)
	duel.rival.s = 52.0
	duel.rival.d = 0.0
	await _frames(3)
	_check(g.boss_on_screen and g.boss_dist_text.begins_with(RouteGuide.T_BOSS), "Sói Xám ahead on screen: the marker over him ('%s')" % g.boss_dist_text)
	_drive(60.0)
	duel.rival.s = 50.0
	await _frames(3)
	_check(not g.boss_on_screen and g.boss_edge >= 0 and g.edge_kind[g.boss_edge] == 2, "Sói Xám behind the camera: his edge arrow with his name")
	_drive(80.0)
	await _frames(1)
	duel.rival.s = duel.s_p + 26.0
	duel.rival.v = 31.0
	duel.rival._prev_lead = 26.0
	var lead_max: float = 0.0
	for k0: int in 90:
		_drive(drive_s + 20.0 / 60.0)
		await _frames(1)
		lead_max = maxf(lead_max, duel.rival.s - duel.s_p)
	_check(lead_max <= DriftDuel.RIVAL_LEASH_M + 0.5 and lead_max > 27.0, "riding away at 31 m/s he stops at the %.0f m leash (max lead %.1f, clamps %d)" % [DriftDuel.RIVAL_LEASH_M, lead_max, duel.rival.lead_clamps])
	duel.rival.s = duel.s_p + 60.0           # put far ahead (a stop, a reset): never pulled back, he rides slower until inside
	await _frames(1)
	var l0: float = duel.rival.s - duel.s_p
	for k1: int in 60:
		_drive(drive_s + 20.0 / 60.0)
		await _frames(1)
	_check(l0 > 55.0 and duel.rival.s - duel.s_p < l0 - 0.5, "beyond the leash he is not pulled back but rides slower than the player (%.1f -> %.1f)" % [l0, duel.rival.s - duel.s_p])
	var apex: float = float(g.turns[0][0])
	var n: int = 0
	if drive_s > apex - 160.0:
		_drive(apex - 170.0)
		await _frames(2)
	while drive_s < apex - 140.0 and n < 4000:
		_drive(drive_s + 0.4)
		await _frames(1)
		n += 1
	_check(g.turn_visible and g.turn_text == RouteGuide.T_SHARP_LEFT and g.turn_dir == -1, "140 m before the Y junction: '%s %s'" % [g.turn_text, g.turn_dist_text])
	# the kick assist on him: 3 m to the side, 2.5 m ahead
	duel.rival.wobble_t = 0.0
	duel.rival.s = duel.s_p + 2.5
	duel.rival.d = duel.d_p + 3.0
	duel.rival.line_d = duel.rival.d
	duel.rival.d_target = duel.rival.d
	duel.rival.v = 12.0
	bike.is_controls_locked = false
	await _frames(1)
	var h0: int = duel.rival.hits_total
	_check(duel.combat.kick(1), "[E] at him")
	for k: int in 24:
		_drive(drive_s + 0.2, duel.d_p, 12.0)
		await _frames(1)
	_check(duel.rival.magnets == 1 and duel.rival.hits_total == h0 + 1, "the assist pulls him in and the kick lands (%d hits)" % (duel.rival.hits_total - h0))
	duel.stop()
	await _frames(2)
	_check(not g.active and not bike.cam_rig.combat_on, "stop(): the guide off, the camera's framing off")
	duel.queue_free()
	arena.queue_free()
	await _frames(3)


func _finish() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro"]:
		Input.action_release(a)
	PlayerBike.clear_owner_sfx()
	PlayerBike.sfx_dir = "user://sfx/"
	Difficulty.set_easy(false)
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("SUCCESS: D2 GUIDANCE (route line, turn arrows, edge arrows, radar, leash, hold window, kick assist, max alive, combat framing, race leash and marker)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
