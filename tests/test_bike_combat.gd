# File: res://tests/test_bike_combat.gd
# Headless test of the Phase C bike combat (spec 2026-10-26-story-phase-c-days-2-3-5-design.md, C-D1, C-D13
# test_bike_combat):
#   0 data: plain texts, telegraph >= 0.45 s; BikeRoute maths (world / project round trip, the search window); the real
#     Nguyễn Xiển route from mapdata (starts at the south end of the northbound carriageway heading north, crosses the Rạch
#     Hầm bridge at ~356 m, runs on as Nguyễn Văn Tăng, 1.8-2.1 km).
#   A (arena: a floor, a straight route along -Z, a real PlayerBike, no FreeRoam):
#     A1 a right kick on a biker 1.8 m to the right hits in the window -> wobble -> crash (biker_down "kick") -> the rider
#        flies (> 0.6 m up), lands clear of the bike (> 1.5 m), the bike slides (> 1 m) and lies on its side -> DOWN; a
#        second kick in the cooldown is refused; misses: wrong side, out of reach, ahead, a target entering after the
#        window; a 2-kick biker wobbles and recovers, then crashes.
#     A2 the AI kick: a telegraph (WINDUP, HUD "BÊN TRÁI" warning) >= 0.45 s before the hit, -20 stability; a crash
#        (PlayerBike.crash_occurred) -25, i-frames swallow a second one.
#     A3 stability 0 -> knocked off (bike locked and on its side, kicks refused) -> `lost`, bikers ride off (LEAVE);
#        retry() -> stability 100, bike unlocked and upright at the wave checkpoint, the wave spawned again; stop().
#     A4 two waves: wave_cleared(0), the 2.5 s gap, wave_started(1), the checkpoint moves to wave 1, the recorder tracks
#        the last wave; the last fall -> "finishing", mark "blow", the replay (manual) 0.8 s later, focus = the fallen
#        rider, then `won`, the tree unpaused; a downed rider of the cleared wave still in view is kept (stars), the one
#        behind the camera is removed; after `won` the last rider keeps going to DOWN; clear_downed(); end_s.
#     A4b freeing the chase during the replay: no `won`, the tree unpaused.
#     A5 traffic: a parked car in a biker's path is passed (avoidance, no crash); a slow touch is a scrape (pushed out);
#        a kicked biker wobbling into a car crashes ("traffic"); the traffic sees the bikers (extra_obstacles_fn, kind
#        "biker") while the chase runs, not after.
#     A6 three AI bikers with the player riding (god mode): they keep pace, take FRONT / LEFT / RIGHT, box the player in,
#        brake-check, attack (never more than 2 at once) and stay on the road.
#     A7 input refusals: kick() not riding / chase not running -> refused (counted); a real [E] press kicks while riding;
#        freeing a running chase unlocks the bike and clears the hooks; setup(waves).
#     A8 moving kicks: riding at speed with real steering, the bike turned +/-10 deg off the road, a real [Q] / [E] lands
#        on an AI flanker riding alongside in its slot (4 kicks, both 2-kick bikers down -> `won`).
#     A9 the dodge with real steering: an AI kick on a rider going straight hits (-20); steering away (real steer input
#        from 0.25 s into the wind-up, the kick line already fixed) makes it miss.
#     A10 a full chase with the AI on (2 + 2 bikers), real steering and real kick keys, played to `won` (the replay
#        stepped); the bikers all end DOWN after `won`.
#     A11 end_at_s: riding past it with 2 bikers left -> `won` at once, ended_early, escaped 2, end_s, no replay; the
#        bikers ride off and are hidden only out of view.
#   B (FreeRoam at night): start() mounts and places the rider on Nguyễn Xiển (300 m), FreeRoam's hint shows the kicks,
#     [F] is refused with a hint; bridge_s() / bridge_transform() on the deck; riding on autopilot over the Rạch Hầm bridge
#     the bikers catch up, follow over the deck and keep to the road; the HUD fits the viewport; stop() clears the hint and
#     [F] works again.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_bike_combat.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const BIKE_SCENE: String = "res://scenes/PlayerBike.tscn"
const Z0: float = 250.0                  # the arena route runs from z = 250 north to z = -1500 along x = 0

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var arena: Node3D
var bike: PlayerBike
var chase: BikeChase
var mark: Dictionary = {}
var downs: Array = []
var lost_n: int = 0
var won_n: int = 0
var cleared: Array[int] = []
var started_w: Array[int] = []
var tr: RoamTraffic
var roam: Node3D
var nx: BikeRoute
var autopilot: bool = false
var auto_yaw: float = 0.0                # deg: >0 left of the route; with tangent_mode the heading is the route's + this
var tangent_mode: bool = false
var key_up: int = -1


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)
	return ok


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST BIKE COMBAT ---")
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	_data_checks()
	physics_frame.connect(_on_physics)


static func _plain(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c > 0x2000 or (c < 0x80 and not (char(c) in " ,.:-[]/!?%0123456789\n") and not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122))):
			return false
	return true


func _data_checks() -> void:
	for s: String in BikeCombatData.texts():
		_check(_plain(s), "plain text without emoji or decorative symbols: '%s'" % s)
	_check(BikeCombatData.WINDUP_S + BikeCombatData.ENEMY_HIT_AT >= 0.45, "an enemy kick is telegraphed >= 0.45 s before it lands")
	_check(BikeCombatData.KICK_WINDUP < BikeCombatData.KICK_ACTIVE_END and BikeCombatData.KICK_ACTIVE_END < BikeCombatData.KICK_DUR, "kick: wind-up < hit window end < duration")
	_check(BikeCombatData.T_START_D2 == "Tới công chuyện luôn!" and BikeCombatData.T_WIN_D2 == "Đỉnh nóc kịch trần bay phấp phới", "the Day 2 meme lines")
	_day2_data_checks()
	# route maths
	var r: BikeRoute = BikeRoute.from_points([Vector2(0.0, 0.0), Vector2(0.0, -100.0), Vector2(100.0, -100.0)])
	_check(r.valid() and absf(r.length - 200.0) < 0.01, "route length 200 m (%.2f)" % r.length)
	var p: Vector2 = r.world(50.0, 2.0)
	_check(p.distance_to(Vector2(2.0, -50.0)) < 0.01, "world(50, +2) is 2 m to the right of a northbound leg (%s)" % str(p))
	var pr: Vector2 = r.project(p, 40.0)
	_check(absf(pr.x - 50.0) < 0.01 and absf(pr.y - 2.0) < 0.01, "project round trip (%s)" % str(pr))
	var pr2: Vector2 = r.project(Vector2(150.0, -103.0), 160.0)
	_check(absf(pr2.x - 200.0) < 0.6 or absf(pr2.x - 150.0) < 0.6, "project on the second leg (%s)" % str(pr2))
	var pr3: Vector2 = r.project(Vector2(50.0, -97.0), 5.0, 30.0)
	_check(pr3.x <= 35.0 + BikeRoute.RESAMPLE_M + 0.01, "the search window keeps project near the hint (%s)" % str(pr3))
	# the real route
	nx = BikeRoute.nguyen_xien(MapData.load_default())
	if _check(nx != null and nx.valid(), "BikeRoute.nguyen_xien builds from mapdata"):
		_check(nx.length > 1800.0 and nx.length <= 2101.0, "Nguyễn Xiển route 1.8-2.1 km (%.0f m)" % nx.length)
		_check(nx.point(0.0).distance_to(Vector2(2176.59, 520.87)) < 1.0, "starts at the south end of the northbound carriageway (%s)" % str(nx.point(0.0)))
		_check(nx.tangent(5.0).y < -0.5, "heads north (%s)" % str(nx.tangent(5.0)))
		_check(nx.bridge_s > 330.0 and nx.bridge_s < 385.0, "the route knows the Rạch Hầm bridge (bridge_s %.0f)" % nx.bridge_s)
		var bp: Vector2 = nx.project(Vector2(2123.5, 153.5))
		_check(absf(bp.y) < 6.0 and bp.x > 320.0 and bp.x < 400.0, "crosses the Rạch Hầm bridge at ~356 m (s %.0f, d %.1f)" % [bp.x, bp.y])
		_check(nx.point(nx.length).x < 2034.0, "runs on west past the Nguyễn Văn Tăng junction (%s)" % str(nx.point(nx.length)))


func _next(p: String) -> void:
	phase = p
	t0 = frames
	mark.clear()


static func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


## A chase on the arena route with ai-off bikers (HOLD) unless `ai`.
func _arena_chase(n_per_wave: Array, ai: bool = false, opts: Dictionary = {}, bopts: Dictionary = {}) -> BikeChase:
	var c := BikeChase.new()
	c.name = "Chase%d" % frames
	arena.add_child(c)
	var o: Dictionary = {"bike": bike, "route": [Vector2(0.0, Z0), Vector2(0.0, -1500.0)], "start_s": 60.0, "manual_replay": true, "seed": 3}
	for k: String in opts.keys():
		o[k] = opts[k]
	c.setup(o)
	for n: int in n_per_wave:
		var w: Array = []
		for i: int in n:
			var bo: Dictionary = {"ai": ai, "label": "T%d" % i}
			bo.merge(bopts, true)
			w.append({"lane": [-1, 1, 0, -1][i % 4], "opts": bo})
		c.add_wave(w)
	c.biker_down.connect(func(b: BikerEnemy, cause: String) -> void: downs.append([b, cause]))
	c.lost.connect(func() -> void: lost_n += 1)
	c.won.connect(func() -> void: won_n += 1)
	c.wave_cleared.connect(func(i: int) -> void: cleared.append(i))
	c.wave_started.connect(func(i: int) -> void: started_w.append(i))
	return c


## Put biker b at (along, lat) of the player (route frame), at the player's speed, holding there.
func _hold(b: BikerEnemy, along: float, lat: float) -> void:
	b.hold_along = along
	b.hold_lat = lat
	var p: Vector2 = chase.target_at(along, lat)
	b.place(Vector3(p.x, 0.0, p.y), 0.0, chase.p_vel.length())


## Autopilot with the real steering actions (strength = proportional): toward the route 14 m ahead (+ auto_yaw), or with
## tangent_mode the route's own heading + auto_yaw (the bike turned off the road direction).
func _autopilot() -> void:
	if not autopilot or chase == null or not is_instance_valid(chase) or chase.route == null or chase.s_p < 0.0:
		return
	var want: float
	if tangent_mode:
		var tg: Vector2 = chase.route.tangent(chase.s_p)
		want = atan2(-tg.x, -tg.y) + deg_to_rad(auto_yaw)
	else:
		var to: Vector2 = chase.route.point(chase.s_p + 14.0) - Vector2(bike.global_position.x, bike.global_position.z)
		want = atan2(-to.x, -to.y) + deg_to_rad(auto_yaw)
	_steer(clampf(wrapf(want - bike.rotation.y, -PI, PI) * 4.0, -1.0, 1.0))


## Yaw error (deg) of the bike against the route heading + auto_yaw.
func _yaw_err() -> float:
	var tg: Vector2 = chase.route.tangent(chase.s_p)
	return rad_to_deg(wrapf(atan2(-tg.x, -tg.y) + deg_to_rad(auto_yaw) - bike.rotation.y, -PI, PI))


static func _steer(k: float) -> void:
	if k > 0.02:
		Input.action_press("steer_left", k)
		Input.action_release("steer_right")
	elif k < -0.02:
		Input.action_press("steer_right", -k)
		Input.action_release("steer_left")
	else:
		Input.action_release("steer_left")
		Input.action_release("steer_right")


static func _ride(on: bool) -> void:
	if on:
		Input.action_press("gas")
	else:
		Input.action_release("gas")
		_steer(0.0)


func _on_physics() -> void:
	frames += 1
	var t: int = frames - t0
	if frames > 60000:
		_check(false, "timed out in phase %s" % phase)
		_finish()
		return
	if key_up >= 0:
		_key(key_up as Key, false)
		key_up = -1
	_autopilot()
	match phase:
		"":
			_build_arena()
			_next("a1")
		"a1":
			_phase_a1(t)
		"a2":
			_phase_a2(t)
		"a3":
			_phase_a3(t)
		"a4":
			_phase_a4(t)
		"a5":
			_phase_a5(t)
		"a6":
			_phase_a6(t)
		"a7":
			_phase_a7(t)
		"a4b":
			_phase_a4b(t)
		"a8":
			_phase_a8(t)
		"a9":
			_phase_a9(t)
		"a10":
			_phase_a10(t)
		"a11":
			_phase_a11(t)
		"c2":
			_phase_c2(t)
		"c3":
			_phase_c3(t)
		"c4":
			_phase_c4(t)
		"c5":
			_phase_c5(t)
		"c6":
			_phase_c6(t)
		"c7":
			_phase_c7(t)
		"c8":
			_phase_c8(t)
		"c9":
			_phase_c9(t)
		"c10":
			_phase_c10(t)
		"c9b":
			_phase_c9b(t)
		"c11b":
			_phase_c11b(t)
		"c11":
			_phase_c11(t)
		"b":
			_phase_b(t)


func _build_arena() -> void:
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


# ---------------------------------------------------------------------------
# A1: kicks
# ---------------------------------------------------------------------------
func _phase_a1(t: int) -> void:
	if t == 1:
		chase = _arena_chase([4])
		chase.start()
		_check(chase.state == "running" and chase.bikers.size() == 4, "start(): running, 4 bikers (%s, %d)" % [chase.state, chase.bikers.size()])
		_check(bike.global_position.distance_to(Vector3(0.0, -0.13, Z0 - 60.0)) < 0.3, "start() places the bike at start_s on the route (%s)" % str(bike.global_position))
		_check(chase.combat.enabled and chase.combat.stability == 100.0, "the combat is on, stability 100")
	if t == 2:
		_hold(chase.bikers[0], 0.0, 1.8)    # right, in reach
		_hold(chase.bikers[1], 0.0, -4.0)   # left, out of reach
		_hold(chase.bikers[2], 0.0, 6.0)    # parked far right for the hp 2 test
		_hold(chase.bikers[3], 0.0, -6.0)   # parked far left for A2
		(chase.bikers[2] as BikerEnemy).hp = 2
	if t == 6:
		_check(chase.on_route and absf(chase.s_p - 60.0) < 0.5, "the player is on the route at s 60 (%.2f)" % chase.s_p)
		_check(chase.combat.kick(1), "right kick starts")
		_check(not chase.combat.kick(1) and chase.combat.refusals == 0, "a second kick in the cooldown is refused (not a 'not riding' refusal)")
		mark["b0"] = chase.bikers[0]
	if t == 6 + 14:
		var b0: BikerEnemy = mark["b0"]
		_check(chase.combat.hits == 1 and chase.combat.results.back() == "hit", "the kick lands in its window (hits %d)" % chase.combat.hits)
		_check(b0.st == BikerEnemy.St.WOBBLE, "the kicked biker wobbles (%s)" % b0.state_name())
		_check(not chase.combat.kick(1), "still in the cooldown at 0.23 s")
	if t > 20 and mark.has("b0") and not mark.has("crashed"):
		var b0: BikerEnemy = mark["b0"]
		if b0.st == BikerEnemy.St.CRASH:
			mark["crashed"] = t
			mark["crash_pos"] = b0.pos2
			mark["max_up"] = 0.0
	if mark.has("crashed") and not mark.has("down"):
		var b0: BikerEnemy = mark["b0"]
		mark["max_up"] = maxf(float(mark["max_up"]), b0.rider_pos.y - b0.floor_y)
		if b0.st == BikerEnemy.St.DOWN:
			mark["down"] = t
			_check(int(mark["crashed"]) - 20 >= 25, "it wobbles ~0.55 s before the crash (%d frames)" % (int(mark["crashed"]) - 20))
			_check(downs.size() == 1 and downs[0][0] == b0 and String(downs[0][1]) == "kick", "biker_down(biker, 'kick') (%s)" % str(downs))
			_check(float(mark["max_up"]) > 0.6, "the rider flies off in a tumble (%.2f m up)" % float(mark["max_up"]))
			_check(b0.rider_gap() > 1.5, "the rider lands clear of the bike (%.2f m)" % b0.rider_gap())
			_check(b0.pos2.distance_to(mark["crash_pos"]) > 0.5, "the bike slides (%.2f m)" % b0.pos2.distance_to(mark["crash_pos"]))
			_check(absf(absf(b0.lean) - BikeCombatData.BIKE_ROLL) < 0.05, "the bike lies on its side (lean %.2f)" % b0.lean)
			_check(chase.remaining() == 3 and chase.state == "running", "3 bikers left, still running (%d)" % chase.remaining())
	if t == 60:
		_check(chase.combat.kick(-1), "left kick at a biker out of reach")
	if t == 60 + 24:
		_check(chase.combat.misses == 1 and chase.combat.results.back() == "miss", "out of reach: a miss (%d)" % chase.combat.misses)
		_hold(chase.bikers[1], 0.0, -1.8)
	if t == 100:
		_check(chase.combat.kick(1), "kick to the wrong side starts")
	if t == 100 + 24:
		_check(chase.combat.misses == 2, "a target on the other side: a miss (%d)" % chase.combat.misses)
		_hold(chase.bikers[1], 3.0, -1.8)     # ahead of the window
	if t == 140:
		_check(chase.combat.kick(-1), "kick at a biker ahead starts")
	if t == 140 + 24:
		_check(chase.combat.misses == 3, "a target 3 m ahead: a miss (%d)" % chase.combat.misses)
		_hold(chase.bikers[1], 0.0, -4.0)
	if t == 180:
		_check(chase.combat.kick(-1), "kick before the target arrives starts")
	if t == 180 + 20:                         # 0.33 s: after the window
		_hold(chase.bikers[1], 0.0, -1.8)
	if t == 180 + 26:
		_check(chase.combat.misses == 4 and (chase.bikers[1] as BikerEnemy).st == BikerEnemy.St.HOLD, "a target entering after the window: a miss (%d)" % chase.combat.misses)
		_hold(chase.bikers[2], 0.0, 1.8)
		_hold(chase.bikers[1], 0.0, -6.0)
	if t == 230:
		_check(chase.combat.kick(1), "kick at the 2-kick biker starts")
	if t == 230 + 60:
		var b2: BikerEnemy = chase.bikers[2]
		_check(b2.hp == 1 and not b2.is_down() and (b2.st == BikerEnemy.St.RECOVER or b2.st == BikerEnemy.St.HOLD), "a 2-kick biker wobbles and recovers (%s, hp %d)" % [b2.state_name(), b2.hp])
		_hold(b2, 0.0, 1.8)
	if t == 300:
		chase.combat.kick(1)
	if t == 300 + 60:
		var b2: BikerEnemy = chase.bikers[2]
		_check(b2.is_down() and downs.size() == 2, "... and crashes on the second kick (%s)" % b2.state_name())
		_next("a2")


# ---------------------------------------------------------------------------
# A2: the AI kick, dodge, crash damage
# ---------------------------------------------------------------------------
func _phase_a2(t: int) -> void:
	var b3: BikerEnemy = chase.bikers[3]
	if t == 1:
		_hold(b3, BikeCombatData.SLOT_ALONG, -BikeCombatData.SLOT_LAT)
	if t == 5:
		b3.start_attack(-1.0)
		_check(b3.st == BikerEnemy.St.WINDUP and b3.telegraphing(), "the attack starts with the telegraph (%s)" % b3.state_name())
		mark["f0"] = frames
	if t == 15:
		_check(chase.hud.warn_left and not chase.hud.warn_right, "the HUD warns on the left during the wind-up")
		_check(chase.warn_mask() == 1, "warn_mask = left (%d)" % chase.warn_mask())
	if t > 5 and not mark.has("hit_f") and chase.combat.stability < 100.0:
		mark["hit_f"] = frames
		var lead: float = float(frames - int(mark["f0"])) / 60.0
		_check(lead >= 0.45, "the kick lands %.2f s after the telegraph started (>= 0.45)" % lead)
		_check(is_equal_approx(chase.combat.stability, 78.0), "an enemy kick costs 22 stability (%.1f)" % chase.combat.stability)
	if t == 70:
		_check(mark.has("hit_f") and b3.results.back() == "hit", "the AI kick hit (%s)" % str(b3.results))
	if t == 110:
		_check(b3.st == BikerEnemy.St.HOLD, "back to its hold after the recovery (%s)" % b3.state_name())
		bike.crash_occurred.emit()
		_check(is_equal_approx(chase.combat.stability, 63.0), "a crash at a standstill costs 15 stability (15-25 by speed) (%.1f)" % chase.combat.stability)
		bike.crash_occurred.emit()
		_check(is_equal_approx(chase.combat.stability, 63.0), "i-frames swallow a second crash at once (%.1f)" % chase.combat.stability)
		_next("a3")


# ---------------------------------------------------------------------------
# A3: knocked off -> lost -> retry -> stop
# ---------------------------------------------------------------------------
func _phase_a3(t: int) -> void:
	if t == 50:
		mark["cp"] = chase._cp["xf"].origin
		chase.combat.damage(100.0, "test")
		_check(chase.combat.knocked and bike.is_controls_locked, "stability 0: knocked off, the bike locks")
		_check(not chase.combat.kick(1) and chase.combat.refusals == 1, "no kick while knocked off (refusals %d)" % chase.combat.refusals)
	if t == 52:
		_check(lost_n == 1 and chase.state == "lost", "`lost` (%d, %s)" % [lost_n, chase.state])
		var leaving: int = 0
		for b: Variant in chase.bikers:
			if (b as BikerEnemy).st == BikerEnemy.St.LEAVE:
				leaving += 1
		_check(leaving == 2, "the bikers still riding ride off (LEAVE: %d)" % leaving)
	if t == 80:
		_check(absf(bike.visual_pivot.rotation.z - 1.35) < 0.05, "the bike lies on its side (%.2f)" % bike.visual_pivot.rotation.z)
		bike.global_position += Vector3(0.0, 0.0, -20.0)
		chase.retry()
		_check(chase.state == "running" and chase.combat.stability == 100.0 and not chase.combat.knocked, "retry(): running, stability 100")
		_check(not bike.is_controls_locked and is_equal_approx(bike.visual_pivot.rotation.z, 0.0), "retry(): the bike unlocked and upright")
		_check(bike.global_position.distance_to(mark["cp"]) < 0.05, "retry(): back at the wave checkpoint (%s vs %s)" % [str(bike.global_position), str(mark["cp"])])
		_check(chase.bikers.size() == 4 and chase.remaining() == 4 and downs.size() == 2, "retry(): the wave again (4 bikers)")
	if t == 84:
		chase.stop()
		_check(chase.state == "idle" and not chase.combat.enabled and chase.bikers.is_empty(), "stop(): idle, bikers gone")
		_check(not chase.hud.visible, "stop(): the HUD hides")
	if t == 86:
		chase.queue_free()
		_next("a4")


# ---------------------------------------------------------------------------
# A4: waves, checkpoint, replay, won
# ---------------------------------------------------------------------------
func _phase_a4(t: int) -> void:
	if t == 2:
		downs.clear()
		cleared.clear()
		started_w.clear()
		chase = _arena_chase([2, 1])
		chase.start()
		_check(started_w == [0] and chase.rec == null, "wave 0 starts; no recorder before the last wave")
	if t == 3:
		_hold(chase.bikers[0], 9.0, 0.0)       # ahead of the camera
		_hold(chase.bikers[1], -14.0, 0.0)     # behind it
		mark["w0"] = [chase.bikers[0], chase.bikers[1]]
	if t == 4:
		for b: Variant in chase.bikers:
			(b as BikerEnemy).crash("test")
		_check(cleared == [0] and chase.state == "running" and chase._gap_left > 0.0, "wave 0 cleared, the gap runs (%s)" % str(cleared))
	if t == 4 + 152:
		_check(started_w == [0, 1] and chase.wave == 1 and chase.bikers.size() == 1, "wave 1 starts after the 2.5 s gap (%s)" % str(started_w))
		_check(int(chase._cp["wave"]) == 1, "the checkpoint moved to wave 1")
		_check(chase.rec != null and chase.rec.tracked().size() >= 5, "the recorder tracks the bike, its pivot, rider and the last wave (%d)" % (chase.rec.tracked().size() if chase.rec else 0))
		_hold(chase.bikers[0], 0.0, 1.8)
	if t == 4 + 152 + 20:
		var w0: Array = mark["w0"]
		_check(is_instance_valid(w0[0]) and (w0[0] as BikerEnemy).st == BikerEnemy.St.DOWN, "a downed rider of the cleared wave in view is kept (stars)")
		_check(not is_instance_valid(w0[1]), "the one behind the camera is removed")
	if t == 4 + 156:
		chase.combat.kick(1)
	if t > 4 + 156 and not mark.has("fin") and chase.state == "finishing":
		mark["fin"] = frames
		_check(chase.rec.marks.has("blow"), "the last fall marks the replay")
		_check(cleared == [0, 1] and downs.size() == 3, "the last wave cleared (%s)" % str(cleared))
	if mark.has("fin") and not mark.has("rp") and chase.replay != null:
		mark["rp"] = frames
		var lag: int = frames - int(mark["fin"])
		_check(lag >= 62 and lag <= 74, "the replay starts 0.8 s (game) after the last fall, its first 0.5 s real in the Q2 last-enemy slow motion (%d frames)" % lag)
		_check(paused, "the replay pauses the tree")
		_check(chase.replay.focus == (chase.last_down as BikerEnemy).body and chase.replay.other == bike, "replay focus = the fallen rider, other = the player's bike")
		_check(chase.replay_slot == "seg_d2_chase" and won_n == 0, "slot seg_d2_chase, `won` waits for the replay")
	if mark.has("rp") and chase.replay != null:
		chase.replay.step(0.1)
	if mark.has("rp") and not mark.has("won") and won_n == 1:
		mark["won"] = frames
		_check(chase.state == "won" and not paused, "`won` after the replay, the tree unpaused (%s)" % chase.state)
		_check(chase.rec == null and not chase.combat.enabled, "the recorder is freed, the combat off")
		_check(absf(chase.end_s - 60.0) < 1.0 and chase.end_position().distance_to(bike.global_position) < 0.5 and not chase.ended_early, "end_s / end_position: where the chase ended (%.1f)" % chase.end_s)
	if mark.has("won") and frames == int(mark["won"]) + 200:
		var last: BikerEnemy = chase.last_down
		_check(is_instance_valid(last) and last.st == BikerEnemy.St.DOWN, "after `won` the last rider keeps going: tumble, slide, DOWN (%s)" % (last.state_name() if is_instance_valid(last) else "freed"))
		chase.clear_downed()
	if mark.has("won") and frames == int(mark["won"]) + 202:
		var w0: Array = mark["w0"]
		_check(chase.bikers.is_empty() and chase._downed.is_empty() and not is_instance_valid(w0[0]), "clear_downed() removes every downed rider")
		chase.queue_free()
		_next("a4b")
	if t > 1500:
		_check(false, "A4 timed out (%s, replay %s)" % [chase.state, str(chase.replay)])
		chase.queue_free()
		_next("a4b")


func _phase_a4b(t: int) -> void:
	if t == 2:
		mark["won0"] = won_n
		chase = _arena_chase([1])
		chase.start()
	if t == 4:
		(chase.bikers[0] as BikerEnemy).crash("test")
	if t > 4 and not mark.has("rp") and chase.replay != null:
		mark["rp"] = t
		chase.queue_free()                    # freed in the middle of the replay
	if mark.has("rp") and t == int(mark["rp"]) + 3:
		_check(won_n == int(mark["won0"]) and not paused, "freeing the chase during the replay: no `won`, the tree unpaused (%d)" % (won_n - int(mark["won0"])))
		_next("a5")
	if t > 300:
		_check(false, "A4b: the replay never started")
		_next("a5")


# ---------------------------------------------------------------------------
# A5: traffic
# ---------------------------------------------------------------------------
func _arena_traffic() -> RoamTraffic:
	var md := MapData.new()
	md.data = {"roads": [{"id": 1, "name": "Đường thử", "class": "primary", "width": 8.0, "lanes": 2, "oneway": false,
		"roundabout": false, "bridge": false, "region": "corridor", "points": [[0.0, Z0], [0.0, -1500.0]]}]}
	var stub := Node.new()
	stub.name = "StubRoam"
	stub.set_script(load("res://tests/support/stub_roam.gd"))
	arena.add_child(stub)
	var t := RoamTraffic.new()
	t.name = "Traffic"
	t.position = Vector3(0.0, -100.0, 0.0)
	arena.add_child(t)
	t.setup(md, bike, {"roam": stub, "kinds": [RoamTraffic.Kind.CAR, RoamTraffic.Kind.CAR], "plot": PackedVector2Array(), "seed": 5})
	for c: RoamTraffic.Vehicle in t.vehicles:
		t._park(c)
	return t


## Park car idx on the lane nearest world point p (map plane), stopped.
func _park_car(idx: int, p: Vector2) -> void:
	var best_l: int = 0
	var best_s: float = 0.0
	var best_d: float = INF
	for l: int in tr.lane_pts.size():
		var s: float = 0.0
		while s < tr.lane_len[l]:
			var q: Vector2 = tr._lane_point(l, s)
			if q.distance_to(p) < best_d:
				best_d = q.distance_to(p)
				best_l = l
				best_s = s
			s += 0.5
	var c: RoamTraffic.Vehicle = tr.vehicles[idx]
	tr._activate(c, best_l, best_s)
	c.cruise = 0.0
	c.speed = 0.0


func _phase_a5(t: int) -> void:
	if t == 2:
		downs.clear()
		tr = _arena_traffic()
		chase = _arena_chase([2], false, {"traffic": tr})
		chase.start()
		var b0: BikerEnemy = chase.bikers[0]
		var b1: BikerEnemy = chase.bikers[1]
		_hold(b0, 0.0, -2.0)
		b0.hold_along = 22.0                  # it rides 22 m ahead along x = -2 ...
		_hold(b1, -6.0, 3.0)
		_park_car(0, chase.target_at(9.0, -2.0))   # ... where a parked car stands
		_park_car(1, chase.target_at(-40.0, 2.0))  # (both active: the traffic spawns nothing on its own)
		mark["car"] = tr.vehicles[0].pos
		_check(tr.vehicles[0].active and Vector2(tr.vehicles[0].pos).distance_to(chase.target_at(9.0, -2.0)) < 1.5, "test setup: a car parked 9 m ahead in the biker's line")
	if t == 4:
		var obs: Array = tr._obstacles()
		var n: int = 0
		for o: Array in obs:
			if String(o[3]) == "biker":
				n += 1
		_check(tr.extra_obstacles_fn.is_valid() and n == 2, "the traffic sees the 2 bikers as obstacles (%d)" % n)
	if t == 240:
		var b0: BikerEnemy = chase.bikers[0]
		var car: Vector2 = mark["car"]
		_check(not b0.is_down() and b0.avoids >= 1, "the biker passes the parked car (avoids %d, %s)" % [b0.avoids, b0.state_name()])
		_check((b0.pos2 - chase.p_pos).dot(chase.p_fwd) > (car - chase.p_pos).dot(chase.p_fwd) + 3.0, "... and is past it")
		var b1: BikerEnemy = chase.bikers[1]
		b1.pos2 = Vector2(2.6, b1.pos2.y)
		_park_car(1, Vector2(2.0, b1.pos2.y + 0.5))
	if t == 242:
		var b1: BikerEnemy = chase.bikers[1]
		_check(not b1.is_down() and b1.scrapes >= 1 and downs.is_empty(), "a slow touch against a car is a scrape: pushed out, still riding (%s, scrapes %d)" % [b1.state_name(), b1.scrapes])
		b1.pos2 = Vector2(2.5, b1.pos2.y)
		_check(b1.take_kick(Vector2(-1.0, 0.0)) == "crash", "test setup: the biker kicked toward the car")
		_park_car(1, Vector2(2.0, b1.pos2.y))
	if t == 245:
		var b1: BikerEnemy = chase.bikers[1]
		_check(b1.is_down() and b1.crash_cause == "traffic" and downs.size() == 1 and String(downs[0][1]) == "traffic", "a kicked biker wobbling into a car crashes: biker_down 'traffic' (%s)" % b1.state_name())
	if t == 246:
		chase.stop()
		_check(not tr.extra_obstacles_fn.is_valid(), "stop() takes the bikers out of the traffic look-ahead")
	if t == 248:
		chase.queue_free()
		for c: RoamTraffic.Vehicle in tr.vehicles:
			tr._park(c)
		tr.process_mode = Node.PROCESS_MODE_DISABLED
		_next("a6")


# ---------------------------------------------------------------------------
# A6: AI pacing, box-in, attacks, road
# ---------------------------------------------------------------------------
func _phase_a6(t: int) -> void:
	if t == 2:
		downs.clear()
		chase = _arena_chase([3], true, {"start_s": 40.0})
		chase.combat.god = true
		chase.start()
		mark["roles"] = {}
		mark["off_road"] = 0
		mark["brake"] = false
		Input.action_press("gas")
	if t > 2 and t < 600:
		var roles: Dictionary = mark["roles"]
		for b: Variant in chase.bikers:
			var e: BikerEnemy = b
			roles[e.role] = true
			if e.st == BikerEnemy.St.BRAKE:
				mark["brake"] = true
			if e.riding() and absf(chase.route.project(e.pos2, chase.s_p).y) > chase.route.half_width + 0.5:
				mark["off_road"] = int(mark["off_road"]) + 1
	if t == 600:
		Input.action_release("gas")
		var near: int = 0
		var att: int = 0
		for b: Variant in chase.bikers:
			var e: BikerEnemy = b
			if e.pos2.distance_to(chase.p_pos) < 15.0:
				near += 1
			att += e.attacks
		var roles: Dictionary = mark["roles"]
		print("  A6: player at %.1f m/s, s %.0f; %d near, attacks %d, boxed %d, max attackers %d, off-road frames %d" % [chase.p_vel.length(), chase.s_p, near, att, chase.boxed_count, chase.max_attackers_seen, int(mark["off_road"])])
		_check(chase.p_vel.length() > 15.0, "test setup: the player rides at speed (%.1f m/s)" % chase.p_vel.length())
		_check(near == 3 and downs.is_empty(), "the 3 bikers keep pace with the player (%d within 15 m)" % near)
		_check(roles.has(BikerEnemy.Role.FRONT) and roles.has(BikerEnemy.Role.LEFT) and roles.has(BikerEnemy.Role.RIGHT), "roles FRONT, LEFT and RIGHT taken (%s)" % str(roles.keys()))
		_check(chase.boxed_count >= 1, "they box the player in (%d)" % chase.boxed_count)
		_check(bool(mark["brake"]), "the front biker brake-checks")
		_check(att >= 2 and chase.max_attackers_seen <= BikeCombatData.MAX_ATTACKERS, "they attack, never more than the cap at once (%d attacks, max %d)" % [att, chase.max_attackers_seen])
		_check(int(mark["off_road"]) == 0, "they stay on the road (%d frames off)" % int(mark["off_road"]))
		chase.stop()
	if t == 602:
		chase.queue_free()
		_next("a7")


# ---------------------------------------------------------------------------
# A7: input refusals, free while running
# ---------------------------------------------------------------------------
func _phase_a7(t: int) -> void:
	if t == 20:
		var c2 := BikeChase.new()
		arena.add_child(c2)
		c2.setup({"bike": bike, "route": [Vector2(0.0, Z0), Vector2(0.0, -1500.0)], "waves": BikeChase.day2_waves()})
		_check(c2.waves.size() == 3 and c2.remaining() == 14, "setup(waves) adds the Day 2 waves (%d, %d left)" % [c2.waves.size(), c2.remaining()])
		c2.queue_free()
	if t == 30:
		chase = _arena_chase([1])
		_check(not chase.combat.kick(1) and chase.combat.refusals == 1, "no kick before the chase runs (refusal)")
		chase.start()
		_hold(chase.bikers[0], 0.0, 1.8)
		bike.visible = false
		_check(not chase.combat.kick(1) and chase.combat.refusals == 2, "no kick when not riding (refusal)")
		bike.visible = true
		_key(KEY_E, true)
	if t == 31:
		_key(KEY_E, false)
		_check(chase.combat.kicks == 1, "a real [E] press kicks while riding (%d)" % chase.combat.kicks)
	if t == 60:
		chase.combat.enabled = false
		_key(KEY_Q, true)
	if t == 61:
		_key(KEY_Q, false)
		_check(chase.combat.kicks == 1 and chase.combat.refusals == 2, "[Q] does nothing to the bike combat when it is off")
		chase.combat.enabled = true
		chase.combat.damage(100.0, "test")
		_check(bike.is_controls_locked, "test setup: knocked off, the bike locked")
		chase.queue_free()
	if t == 63:
		_check(not bike.is_controls_locked and is_equal_approx(bike.visual_pivot.rotation.z, 0.0), "freeing a running chase unlocks and rights the bike")
		_next("a8")


# ---------------------------------------------------------------------------
# A8: kicks at speed, bike turned +/-10 deg, on AI flankers alongside
# ---------------------------------------------------------------------------
const A8_CASES: Array = [[-1, 10.0], [1, -10.0], [-1, -10.0], [1, 10.0]]


func _phase_a8(t: int) -> void:
	if t == 2:
		downs.clear()
		mark["won0"] = won_n
		chase = _arena_chase([2], true, {"auto_replay": false, "seed": 5}, {"hp": 2, "aggression": 0.0})
		chase.combat.god = true
		chase.start()
		for b0: Variant in chase.bikers:          # Day 2 riders pace just out of kick reach: this geometry test keeps the
			var e0: BikerEnemy = b0               # old in-reach slot to aim moving kicks at a flanker alongside
			e0.kp = e0.kp.duplicate()
			e0.kp["slot_lat"] = BikeCombatData.SLOT_LAT
		_ride(true)
		autopilot = true
		tangent_mode = false
		auto_yaw = 0.0
		mark["ci"] = 0
		mark["ph"] = "wait"
		mark["pt"] = 240
		mark["lats"] = []
		return
	if t < 3:
		return
	var ci: int = int(mark["ci"])
	if ci >= A8_CASES.size():
		if not mark.has("done"):
			mark["done"] = t
		if chase.state == "won" or t - int(mark["done"]) > 120:
			print("  A8: kick lateral in the bike frame %s" % str(mark["lats"]))
			_check(chase.state == "won" and downs.size() == 2 and String(downs[0][1]) == "kick" and String(downs[1][1]) == "kick", "4 kicks at speed down both 2-kick flankers -> won (%s, %d down)" % [chase.state, downs.size()])
			_ride(false)
			autopilot = false
			chase.stop()
			chase.queue_free()
			_next("a9")
		return
	var sd: int = int(A8_CASES[ci][0])
	var ph: String = mark["ph"]
	var pt: int = int(mark["pt"])
	match ph:
		"wait":
			if t < pt:
				return
			for b: Variant in chase.bikers:
				var e: BikerEnemy = b
				var want_role: int = BikerEnemy.Role.LEFT if sd < 0 else BikerEnemy.Role.RIGHT
				if e.role == want_role and e.st == BikerEnemy.St.PACE and e.pos2.distance_to(e.slot_target()) < 0.8:
					mark["tgt"] = e
					mark["ph"] = "yaw"
					mark["pt"] = t
					tangent_mode = true
					auto_yaw = float(A8_CASES[ci][1])
					return
			if t - pt > 900:
				_check(false, "A8 case %d: no flanker settled on side %d" % [ci, sd])
				mark["ci"] = ci + 1
				mark["pt"] = t
		"yaw":
			if absf(_yaw_err()) < 2.0 or t - pt > 60:
				_check(absf(_yaw_err()) < 2.5, "A8 case %d: the bike turned %.0f deg off the road (err %.1f)" % [ci, auto_yaw, _yaw_err()])
				var e: BikerEnemy = mark["tgt"]
				chase.combat.update_frame()
				var rel := Vector2(e.ground_pos().x - bike.global_position.x, e.ground_pos().z - bike.global_position.z)
				(mark["lats"] as Array).append(snappedf(rel.dot(chase.combat.right2), 0.01))
				mark["hits0"] = chase.combat.hits
				mark["spd"] = chase.p_vel.length()
				_key(KEY_Q if sd < 0 else KEY_E, true)
				key_up = KEY_Q if sd < 0 else KEY_E
				mark["ph"] = "kick"
				mark["pt"] = t
		"kick":
			if t - pt == 24:
				var e: BikerEnemy = mark["tgt"]
				_check(chase.combat.hits == int(mark["hits0"]) + 1 and (e.st == BikerEnemy.St.WOBBLE or e.is_down()), "A8 case %d: a real %s at %.1f m/s with the bike at %.0f deg hits the flanker alongside (%s)" % [ci, "[Q]" if sd < 0 else "[E]", float(mark["spd"]), auto_yaw, e.state_name()])
				tangent_mode = false
				auto_yaw = 0.0
				mark["ph"] = "wait"
				mark["pt"] = t + 100
				mark["ci"] = ci + 1


# ---------------------------------------------------------------------------
# A9: the AI kick against real steering
# ---------------------------------------------------------------------------
func _phase_a9(t: int) -> void:
	if t == 2:
		chase = _arena_chase([1], false, {"seed": 6}, {"hp": 99})
		chase.start()
		_ride(true)
		autopilot = true
	if t == 200:
		_hold(chase.bikers[0], BikeCombatData.SLOT_ALONG, -BikeCombatData.SLOT_LAT)
	if t == 260:
		_check(chase.p_vel.length() > 15.0, "test setup: riding at speed (%.1f m/s)" % chase.p_vel.length())
		(chase.bikers[0] as BikerEnemy).start_attack(-1.0)
	if t == 260 + 50:
		var b: BikerEnemy = chase.bikers[0]
		_check(b.results.back() == "hit" and is_equal_approx(chase.combat.stability, 78.0), "riding straight: the AI kick hits (%s, %.1f)" % [str(b.results), chase.combat.stability])
	if t == 400:
		var b: BikerEnemy = chase.bikers[0]
		_check(b.st == BikerEnemy.St.HOLD, "test setup: the biker back beside the player (%s)" % b.state_name())
		b.start_attack(-1.0)
	if t == 400 + 15:
		autopilot = false
		_steer(-1.0)                           # away from the left attacker, 0.25 s into the wind-up
	if t == 400 + 50:
		var b: BikerEnemy = chase.bikers[0]
		var rel: Vector2 = b.pos2 - chase.p_pos
		_check(b.results.back() == "miss" and is_equal_approx(chase.combat.stability, 78.0), "steering away during the wind-up dodges the kick (%s, %.1f, %.2f m apart)" % [str(b.results), chase.combat.stability, rel.length()])
		_steer(0.0)
		autopilot = true
	if t == 470:
		_ride(false)
		autopilot = false
		chase.stop()
		chase.queue_free()
		_next("a10")


# ---------------------------------------------------------------------------
# A10: a full AI chase to `won`, real steering and kick keys
# ---------------------------------------------------------------------------
func _phase_a10(t: int) -> void:
	if t == 2:
		downs.clear()
		mark["won0"] = won_n
		chase = _arena_chase([2, 2], true, {"seed": 7}, {"aggression": 0.6})
		chase.combat.max_stability = 400.0
		chase.start()
		mark["s0"] = chase.s_p
		_ride(true)
		autopilot = true
		return
	if t < 3:
		return
	if (chase.state == "running") and key_up < 0 and chase.combat.kick_cd <= 0.0 and not chase.combat.kicking():
		for sd: int in [-1, 1]:
			if chase.combat.kick_target(sd) != null:
				_key(KEY_Q if sd < 0 else KEY_E, true)
				key_up = KEY_Q if sd < 0 else KEY_E
				break
	if chase.replay != null:
		chase.replay.step(0.1)
	if not mark.has("won") and won_n > int(mark["won0"]):
		mark["won"] = t
		var kicked: int = 0
		for d: Array in downs:
			if String(d[1]) == "kick" or String(d[1]) == "counter":   # Q2: a kick in an attacker's last 0.25 s is a counter
				kicked += 1
		print("  A10: won after %.1f s, %d m ridden, %d kicks (%d hits, %d counters), %d biker attacks, stability %.0f, %d down (%d by kicks: %s)" % [float(t) / 60.0, int(chase.end_s - float(mark["s0"])), chase.combat.kicks, chase.combat.hits, chase.combat.counters, _attacks_total(), chase.combat.stability, downs.size(), kicked, str(downs.map(func(d: Array) -> String: return String(d[1])))])
		_check(chase.state == "won" and not chase.ended_early and downs.size() == 4 and kicked >= 3, "a full AI chase is won with real steering and kicks (%d down, %d by kicks)" % [downs.size(), kicked])
		_ride(false)
		autopilot = false
	if mark.has("won") and t == int(mark["won"]) + 200:
		var all_down: bool = true
		for b: Variant in chase.bikers:
			all_down = all_down and (b as BikerEnemy).st == BikerEnemy.St.DOWN
		_check(all_down and not chase.bikers.is_empty(), "after `won` the last wave's riders all end DOWN")
		chase.stop()
		chase.queue_free()
		_next("a11")
	if t > 4800 and not mark.has("won"):
		_check(false, "A10: the full chase was not won in 80 s (%s, %d left, stability %.0f)" % [chase.state, chase.remaining(), chase.combat.stability])
		_ride(false)
		autopilot = false
		chase.stop()
		chase.queue_free()
		_next("a11")


func _attacks_total() -> int:
	var n: int = 0
	for b: Variant in chase.bikers:
		n += (b as BikerEnemy).attacks
	return n


# ---------------------------------------------------------------------------
# A11: end_at_s
# ---------------------------------------------------------------------------
func _phase_a11(t: int) -> void:
	if t == 2:
		mark["won0"] = won_n
		chase = _arena_chase([2], false, {"end_at_s": 160.0, "seed": 8}, {"hp": 99})
		chase.start()
		_ride(true)
		autopilot = true
		mark["gone"] = 0
	if t == 120:
		_hold(chase.bikers[0], -0.6, -1.95)
		_hold(chase.bikers[1], -0.6, 1.95)
	if t > 120 and not mark.has("won") and won_n > int(mark["won0"]):
		mark["won"] = t
		var leaving: int = 0
		for b: Variant in chase.bikers:
			if (b as BikerEnemy).st == BikerEnemy.St.LEAVE:
				leaving += 1
		_check(chase.state == "won" and chase.ended_early and chase.escaped == 2 and chase.end_s >= 160.0 and chase.replay == null, "end_at_s: `won` at once past it, ended_early, escaped 2, end_s %.0f, no replay" % chase.end_s)
		_check(leaving == 2, "the bikers left ride off (LEAVE %d)" % leaving)
	if mark.has("won"):
		var cam: Camera3D = bike.chase_cam
		for b: Variant in chase.bikers:
			var e: BikerEnemy = b
			if e.gone and not e.has_meta("seen_gone"):
				e.set_meta("seen_gone", true)
				mark["gone"] = int(mark["gone"]) + 1
				var p: Vector3 = e.ground_pos() + Vector3(0.0, 1.0, 0.0)
				_check(not (cam.is_position_in_frustum(p) and cam.global_position.distance_to(p) < BikeCombatData.VIEW_M), "a biker riding off is hidden only out of view")
		if int(mark["gone"]) == 2 or t > int(mark["won"]) + 60 * 26:
			_check(int(mark["gone"]) == 2, "both bikers rode off and were hidden (%d)" % int(mark["gone"]))
			_ride(false)
			autopilot = false
			chase.stop()
			chase.queue_free()
			_next("c2")
	if t > 3000 and not mark.has("won"):
		_check(false, "A11: never reached end_at_s (s %.0f)" % chase.s_p)
		_ride(false)
		autopilot = false
		chase.queue_free()
		_next("c2")


# ---------------------------------------------------------------------------
# B: FreeRoam on Nguyễn Xiển at night
# ---------------------------------------------------------------------------
func _phase_b(t: int) -> void:
	if t == 2:
		roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
		roam.set("mayhem_enabled", false)
		root.add_child(roam)
		roam.call("set_time_of_day", "night")
	if t == 120:
		downs.clear()
		chase = BikeChase.new()
		chase.name = "RoamChase"
		roam.add_child(chase)
		chase.setup({"roam": roam, "start_s": 300.0, "start_line": BikeCombatData.T_START_D2, "seed": 9})
		chase.add_wave([{"lane": -1, "opts": {"label": "Sói Đen"}}, {"lane": 1, "opts": {"label": "Sói Lửa"}}])
		chase.combat.god = true
		chase.start()
		var want: Transform3D = chase.route_transform(300.0)
		_check(chase.route != null and absf(chase.route.length - nx.length) < 0.5, "the default route is Nguyễn Xiển")
		_check(bool(roam.get("mounted")), "start() mounts the player")
		_check(roam.get("bike").global_position.distance_to(want.origin) < 0.5, "the bike is on Nguyễn Xiển at 300 m (%s vs %s)" % [str(roam.get("bike").global_position), str(want.origin)])
		_check(absf(want.origin.y + 0.13 - MapBuilder.ROAD_Y) < 0.3, "on the road surface (floor %.2f)" % (want.origin.y + 0.13))
		_check(String(roam.call("_hint_text")) == BikeCombatData.T_RIDING, "FreeRoam's hint shows the kick keys")
		_check(chase.hud.visible and chase.hud.popup_text == BikeCombatData.T_START_D2, "the HUD shows with the start line")
		roam.call("toggle_bike")
		_check(bool(roam.get("mounted")) and String(roam.get("_hint_flash")) == BikeCombatData.T_NO_DISMOUNT, "[F] refused during the chase, with a hint")
		_check(chase.traffic != null and chase.traffic.extra_obstacles_fn.is_valid(), "the roam traffic sees the bikers")
		var bs: float = chase.bridge_s()
		var bxf: Transform3D = chase.bridge_transform()
		_check(bs > 330.0 and bs < 385.0 and bxf.origin.y > 2.0, "bridge_s() %.0f m, bridge_transform() on the deck (y %.2f)" % [bs, bxf.origin.y])
		mark["max_bike_y"] = -9.0
		mark["max_biker_y"] = -9.0
		mark["off_road"] = 0
		Input.action_press("gas")
	if t > 120 and t < 120 + 540:
		var b: PlayerBike = roam.get("bike")
		var ahead: Vector2 = chase.route.point(chase.s_p + 14.0)
		var to := ahead - chase.p_pos
		b.rotation.y = lerp_angle(b.rotation.y, atan2(-to.x, -to.y), 0.25)
		mark["max_bike_y"] = maxf(float(mark["max_bike_y"]), b.global_position.y)
		for e: Variant in chase.bikers:
			var be: BikerEnemy = e
			if be.riding():
				mark["max_biker_y"] = maxf(float(mark["max_biker_y"]), be.floor_y)
				if chase.on_route and absf(chase.route.project(be.pos2, chase.s_p).y) > chase.route.half_width + 1.0:
					mark["off_road"] = int(mark["off_road"]) + 1
	if t == 120 + 540:
		Input.action_release("gas")
		var near: int = 0
		for e: Variant in chase.bikers:
			if (e as BikerEnemy).pos2.distance_to(chase.p_pos) < 14.0:
				near += 1
		print("  B: s %.0f, bike max y %.2f, biker max floor %.2f, %d near, off-road frames %d" % [chase.s_p, float(mark["max_bike_y"]), float(mark["max_biker_y"]), near, int(mark["off_road"])])
		_check(chase.s_p > 420.0, "the player rode over the bridge (s %.0f)" % chase.s_p)
		_check(float(mark["max_bike_y"]) > 1.5, "the bike went over the Rạch Hầm deck (max y %.2f)" % float(mark["max_bike_y"]))
		_check(float(mark["max_biker_y"]) > 1.0, "the bikers followed over the deck (max floor %.2f)" % float(mark["max_biker_y"]))
		_check(near >= 1, "the bikers caught up (%d near)" % near)
		_check(int(mark["off_road"]) <= 6, "the bikers keep to the road (%d frames off)" % int(mark["off_road"]))
		var vp: Rect2 = chase.hud.panel.get_viewport_rect()
		for c: Control in [chase.hud.panel, chase.hud.hints, chase.hud.warn_l, chase.hud.warn_r]:
			var r := Rect2(c.global_position, c.size)
			_check(vp.grow(1.0).encloses(r), "%s fits the viewport (%s in %s)" % [c.name, str(r), str(vp)])
	if t == 120 + 560:
		chase.stop()
		_check(String(roam.get("riding_hint")) == "" and String(roam.get("dismount_refusal")) == "", "stop() clears the hint and the [F] refusal")
		roam.get("bike").current_speed_ms = 0.0
	if t == 120 + 620:
		roam.call("toggle_bike")
		_check(not bool(roam.get("mounted")), "after the chase [F] gets off the bike")
		_finish()


# ---------------------------------------------------------------------------
# DAY 2 "Tokyo Drift" (spec 2026-10-27, D2X-2 to D2X-7, D2X-13 agent A)
# ---------------------------------------------------------------------------
func _day2_data_checks() -> void:
	var w: Array = BikeChase.day2_waves()
	var n: int = 0
	var kinds: Dictionary = {}
	for wv: Variant in w:
		for sp: Variant in wv:
			n += 1
			kinds[String(((sp as Dictionary).get("opts", {}) as Dictionary).get("kind", "rider"))] = true
	_check(w.size() == 3 and n >= 12 and n <= 14, "the Day 2 layout: 12-14 vehicles in 3 waves (%d in %d)" % [n, w.size()])
	_check(kinds.has("rider") and kinds.has("stick") and kinds.has("thrower") and kinds.has("heavy") and kinds.has("pickup"), "every enemy kind is in the Day 2 layout (%s)" % str(kinds.keys()))
	var wo: Array = BikeChase.day2_wave_opts()
	_check(wo.size() == 3 and float((wo[1] as Dictionary).get("force_s", -1.0)) > 0.0 and bool((wo[2] as Dictionary).get("after_cameo", false)) and int((wo[2] as Dictionary).get("max_attackers", 0)) == 4,
		"wave 2 is forced by distance, wave 3 follows the cameo with 4 attackers")
	_check(BikeCombatData.MAX_ATTACKERS == 3 and is_equal_approx(BikeCombatData.ATTACK_GAP_S, 0.6) and is_equal_approx(BikeCombatData.REGEN_RATE, 0.0), "3 attackers 0.6 s apart, no regeneration")
	for k: String in BikeCombatData.KINDS.keys():
		var kp: Dictionary = BikeCombatData.KINDS[k]
		var lead: float = float(kp["windup"]) + (BikeCombatData.THROW_FLIGHT if k == "thrower" else BikeCombatData.ENEMY_HIT_AT)
		_check(lead >= 0.45 and float(kp["dmg"]) > 0.0 and float(kp["reach"]) > 0.0, "%s: telegraphed >= 0.45 s before it lands (%.2f)" % [k, lead])
	_check(float(BikeCombatData.KINDS["pickup"]["windup"]) >= 1.0 and not bool(BikeCombatData.KINDS["pickup"]["kickable"]), "the pickup: a 1 s telegraph, cannot be kicked")
	_check(int(BikeCombatData.KINDS["heavy"]["hp"]) == 3 and float(BikeCombatData.KINDS["heavy"]["top"]) < BikeCombatData.MAX_SPEED, "the heavy: 3 kicks, slower")
	_check(is_equal_approx(float(BikeCombatData.CHASE_PROFILE["max_speed_ms"]), 27.8) and is_equal_approx(float(BikeCombatData.CHASE_PROFILE["slipstream_max_ms"]), 30.6) and BikeCombatData.MAX_SPEED >= 31.5, "chase profile 27.8 / 30.6 m/s, bikers top at 32")
	_check(is_equal_approx(BikeCombatData.OPEN_DROP_S, 4.15), "the opening drop at 4.15 s (the owner's track)")
	# the real Day 2 route and its set pieces
	var md: MapData = MapData.load_default()
	var r: BikeRoute = MissionBikeChase.day2_route(md)
	if not _check(r != null and r.valid(), "MissionBikeChase.day2_route builds from mapdata"):
		return
	_check(absf(r.length - 5476.0) < 30.0 and absf(r.bridge_s - 2389.0) < 25.0, "the Stage 1 real route, the bridge at ~2389 m (%.0f, %.0f)" % [r.length, r.bridge_s])
	var chase_len: float = r.bridge_s + MissionBikeChase.END_PAST_M - MissionBikeChase.START_S
	_check(chase_len > 2200.0 and chase_len < 2500.0, "the chase is ~2.4 km long, about 2 minutes (%.0f m)" % chase_len)
	var last: float = MissionBikeChase.START_S
	var events: Array[float] = [MissionBikeChase.START_S, BikeCombatData.CAMEO_S, r.bridge_s + MissionBikeChase.END_PAST_M]
	var drift: int = 0
	var have: Dictionary = {}
	for p: Variant in BikeCombatData.DAY2_SET_PIECES:
		var d: Dictionary = p
		var k2: String = d["kind"]
		var s: float = float(d["s"])
		have[k2] = true
		_check(s >= last, "the set pieces are in route order (%s at %.0f)" % [k2, s])
		last = s
		events.append(s)
		if d.has("end_s"):
			events.append(float(d["end_s"]))
		match k2:
			"drift":
				drift += 1
				var mt: float = r.max_turn(s, s + float(d["len"]))
				_check(mt >= 60.0, "drift zone at %.0f sits on a real turn (%.0f deg)" % [s, mt])
			"barrier", "ramp":
				_check(r.max_turn(s - 40.0, s + 10.0) < 15.0, "%s at %.0f on a straight (%.0f deg)" % [k2, s, r.max_turn(s - 40.0, s + 10.0)])
			"wrong_way":
				_check(r.max_turn(s - 30.0, s + float(d["len"])) < 20.0, "wrong way at %.0f on a straight" % s)
	_check(have.has("melons") and have.has("barrier") and have.has("wrong_way") and have.has("ramp") and have.has("police") and drift >= 3 and drift <= 4,
		"all six set pieces, 3-4 drift zones (%s, %d drift)" % [str(have.keys()), drift])
	events.sort()
	var gap: float = 0.0
	for i: int in range(1, events.size()):
		gap = maxf(gap, events[i] - events[i - 1])
	_check(gap <= 450.0, "something new at least every ~450 m (15-20 s at chase speed; largest gap %.0f m)" % gap)
	_check(BikeCombatData.CAMEO_S > 1400.0 and BikeCombatData.CAMEO_FORCE_S > BikeCombatData.CAMEO_S and BikeCombatData.CAMEO_FORCE_S < r.bridge_s - 400.0, "the cameo after wave 2 on the long straight")


## A chase on the arena route with explicit spawns per wave ({"lane", "from", "opts"} each) and per-wave options.
func _kind_chase(spec: Array, opts: Dictionary = {}, wopts: Array = []) -> BikeChase:
	var c := BikeChase.new()
	c.name = "KChase%d" % frames
	arena.add_child(c)
	var o: Dictionary = {"bike": bike, "route": [Vector2(0.0, Z0), Vector2(0.0, -1500.0)], "start_s": 60.0, "manual_replay": true, "seed": 11}
	for k: String in opts.keys():
		o[k] = opts[k]
	c.setup(o)
	for i: int in spec.size():
		c.add_wave(spec[i], wopts[i] if i < wopts.size() else {})
	c.biker_down.connect(func(b: BikerEnemy, cause: String) -> void: downs.append([b, cause]))
	c.lost.connect(func() -> void: lost_n += 1)
	c.won.connect(func() -> void: won_n += 1)
	c.wave_cleared.connect(func(i2: int) -> void: cleared.append(i2))
	c.wave_started.connect(func(i3: int) -> void: started_w.append(i3))
	return c


func _end_chase(nxt: String) -> void:
	_ride(false)
	autopilot = false
	tangent_mode = false
	auto_yaw = 0.0
	Input.action_release("brake")
	if chase and is_instance_valid(chase):
		chase.stop()
		chase.queue_free()
	_next(nxt)


## Brake with the real action (the gas let go: PlayerBike ignores the brake while the gas is held), or back on the gas.
static func _brake(on: bool) -> void:
	if on:
		Input.action_release("gas")
		Input.action_press("brake")
	else:
		Input.action_release("brake")
		Input.action_press("gas")


func _by_label(lbl: String) -> BikerEnemy:
	for b: Variant in chase.bikers:
		if is_instance_valid(b) and (b as BikerEnemy).label == lbl:
			return b
	return null


func _active_helmet() -> Dictionary:
	for h: Dictionary in chase.helmets:
		if bool(h["active"]):
			return h
	return {}


# C2: the stick: raised wind-up, a 25 swing; braking in the wind-up dodges (speed-locked line); a kick interrupts it.
func _phase_c2(t: int) -> void:
	if t < 2:
		return
	var b: BikerEnemy = chase.bikers[0] if (chase and is_instance_valid(chase) and not chase.bikers.is_empty()) else null
	if t == 2:
		downs.clear()
		chase = _kind_chase([[{"lane": -1, "opts": {"kind": "stick", "ai": false, "hp": 99, "label": "Gậy"}}]])
		chase.start()
		_ride(true)
		autopilot = true
		return
	if b == null:
		return
	if t == 200:
		_hold(b, BikeCombatData.SLOT_ALONG, -2.2)
	if t == 250:
		_check(chase.p_vel.length() > 15.0, "stick: riding at speed (%.1f m/s)" % chase.p_vel.length())
		mark["rx"] = b.stick.rotation.x
		mark["f0"] = frames
		mark["stab0"] = chase.combat.stability
		b.start_attack(-1.0)
	if t == 268:
		_check(b.telegraphing() and b.stick.rotation.x > float(mark["rx"]) + 0.15, "stick: the wind-up raises the stick (%.2f -> %.2f)" % [float(mark["rx"]), b.stick.rotation.x])
		_check(chase.hud.warn_left, "stick: the HUD warns on its side")
	if t > 250 and t < 340 and not mark.has("hit") and chase.combat.stability < float(mark["stab0"]):
		mark["hit"] = true
		var lead: float = float(frames - int(mark["f0"])) / 60.0
		_check(lead >= 0.45, "stick: the swing lands %.2f s after the wind-up began (>= 0.45)" % lead)
		_check(is_equal_approx(chase.combat.stability, float(mark["stab0"]) - 25.0), "stick: a swing costs 25 (%.1f)" % chase.combat.stability)
	if t == 340:
		_check(mark.has("hit"), "stick: riding straight, the swing hits")
	if t == 420:
		_check(b.st == BikerEnemy.St.HOLD, "stick: back beside the player (%s)" % b.state_name())
		mark["stab1"] = chase.combat.stability
		b.start_attack(-1.0)
	if t == 429:
		_brake(true)                          # 0.15 s in: the line and the speed are locked
	if t == 470:
		_brake(false)
		_check(b.results.back() == "miss" and is_equal_approx(chase.combat.stability, float(mark["stab1"])), "stick: braking in the wind-up dodges the swing (%s, %.0f m/s)" % [str(b.results), chase.p_vel.length()])
	if t == 600:
		_hold(b, BikeCombatData.SLOT_ALONG, -2.2)
	if t == 640:
		mark["nres"] = b.results.size()
		b.start_attack(-1.0)
	if t == 652:
		_check(chase.combat.kick(-1), "stick: a kick during the wind-up")
	if t == 690:
		_check(b.results.size() == int(mark["nres"]) and not b.is_attacking(), "stick: the kick interrupts the swing (%s)" % b.state_name())
		_end_chase("c3")


# C3: the thrower: the pillion faces back; the helmet lands where the player would be, its red marker 0.8 s ahead; riding
# on = hit (15), braking out of the marker = dodge; a kick drops both riders.
func _phase_c3(t: int) -> void:
	if t < 2:
		return
	var b: BikerEnemy = chase.bikers[0] if (chase and is_instance_valid(chase) and not chase.bikers.is_empty()) else null
	if t == 2:
		chase = _kind_chase([[{"lane": -1, "opts": {"kind": "thrower", "ai": false, "label": "Ném"}}]])
		chase.start()
		_ride(true)
		autopilot = true
		return
	if b == null:
		return
	if t == 3:
		_check(b.pillion != null and absf(absf(b.pillion.rotation.y) - PI) < 0.01 and b.helmet_prop != null, "thrower: two on one bike, the pillion faces back with a helmet")
	if t == 200:
		_hold(b, BikeCombatData.THROW_AHEAD, -2.4)
	if t == 250:
		mark["stab0"] = chase.combat.stability
		b.start_attack(-1.0)
	if not mark.has("thr") and chase.helmets_thrown == 1:
		mark["thr"] = frames
		var h: Dictionary = _active_helmet()
		var mk: Node3D = h.get("mark") as Node3D
		var land := Vector2(mk.global_position.x, mk.global_position.z) if mk else Vector2.INF
		var pred: Vector2 = chase.p_pos + chase.p_vel * BikeCombatData.THROW_FLIGHT
		_check(mk != null and mk.visible and land.distance_to(pred) < 1.0, "thrower: the red marker shows where the player will be (%.2f m off)" % land.distance_to(pred))
	if mark.has("thr") and not mark.has("land") and chase.helmets_thrown == 1 and _active_helmet().is_empty():
		mark["land"] = frames
		var lead: float = float(frames - int(mark["thr"])) / 60.0
		_check(lead >= 0.75, "thrower: the marker shows %.2f s before the helmet lands" % lead)
		_check(chase.helmets_hit == 1 and is_equal_approx(chase.combat.stability, float(mark["stab0"]) - 15.0), "thrower: riding on into the marker = hit, 15 (%d, %.1f)" % [chase.helmets_hit, chase.combat.stability])
	if t == 440:
		_check(mark.has("land"), "thrower: the first helmet landed")
		mark["stab1"] = chase.combat.stability
		b.start_attack(-1.0)
	if not mark.has("thr2") and chase.helmets_thrown == 2:
		mark["thr2"] = frames
		_brake(true)
	if mark.has("thr2") and not mark.has("land2") and _active_helmet().is_empty():
		mark["land2"] = frames
		_brake(false)
		_check(chase.helmets_hit == 1 and is_equal_approx(chase.combat.stability, float(mark["stab1"])), "thrower: braking out of the red marker dodges the helmet (%d)" % chase.helmets_hit)
	if t == 640:
		_hold(b, 0.0, -1.8)
	if t == 650:
		_check(chase.combat.kick(-1), "thrower: kick alongside")
	if t == 720:
		_check(b.is_down() and b.pillion.get_parent() == b.body and b.crash_cause == "kick", "thrower: a kick drops both riders (%s)" % b.state_name())
		_end_chase("c4")


# C4: the heavy: 3 kicks (a short wobble), a 30 shoulder ram; a nitro touch is a takedown (the heavy included).
func _phase_c4(t: int) -> void:
	if t < 2:
		return
	if t == 2:
		downs.clear()
		chase = _kind_chase([[{"lane": 1, "opts": {"kind": "heavy", "ai": false, "label": "Bự"}},
			{"lane": -1, "opts": {"kind": "heavy", "ai": false, "hp": 99, "label": "Bự 2"}},
			{"lane": -1, "opts": {"ai": false, "hp": 99, "label": "R"}}]])
		chase.start()
		return
	var h1: BikerEnemy = _by_label("Bự")
	var h2: BikerEnemy = _by_label("Bự 2")
	var r1: BikerEnemy = _by_label("R")
	if h1 == null or h2 == null or r1 == null:
		return
	if t == 4:
		_hold(h1, 0.0, 1.8)
		_hold(h2, 0.0, -6.0)
		_hold(r1, 0.0, -9.0)
		_check(h1.max_hp == 3 and (h1.get_node("Scooter") as Node3D).scale.x > 1.1, "heavy: 3 kicks, a bigger bike")
	if t == 10 or t == 80 or t == 150:
		chase.combat.kick(1)
	if t == 10 + 14:
		_check(h1.st == BikerEnemy.St.WOBBLE and h1.hp == 2, "heavy: kick 1 wobbles it (hp %d)" % h1.hp)
	if t == 10 + 34:
		_check(h1.st != BikerEnemy.St.WOBBLE and not h1.is_down(), "heavy: a short wobble (0.35 s), back on (%s)" % h1.state_name())
	if t == 230:
		_check(h1.is_down() and h1.crash_cause == "kick" and chase.takedowns == 0, "heavy: down on the 3rd kick (a plain kick crash is no takedown) (%s, hp %d)" % [h1.state_name(), h1.hp])
		_hold(h2, BikeCombatData.SLOT_ALONG, -2.1)
		mark["stab0"] = chase.combat.stability
	if t == 240:
		h2.start_attack(-1.0)
	if t == 320:
		_check(h2.results.back() == "hit" and is_equal_approx(chase.combat.stability, float(mark["stab0"]) - 30.0), "heavy: the shoulder ram costs 30 (%.1f)" % chase.combat.stability)
		_hold(r1, 0.0, 0.6)
		chase.nitro_fn = func() -> bool: return true
	if t == 322:
		chase.nitro_fn = func() -> bool: return false
		_check(r1.is_down() and r1.crash_cause == "nitro" and chase.takedowns == 1 and is_equal_approx(chase.charge_given, BikeCombatData.TD_CHARGE), "nitro ram: a touch during nitro is a takedown, +15 charge (%s, %d, %.0f)" % [r1.crash_cause, chase.takedowns, chase.charge_given])
	if t == 400:
		_hold(h2, 0.0, -0.6)
		chase.nitro_fn = func() -> bool: return true
	if t == 402:
		chase.nitro_fn = Callable()
		_check(h2.is_down() and h2.crash_cause == "nitro" and chase.takedowns == 2, "nitro ram downs the heavy too")
		_end_chase("c5")


# C5: the pickup: cannot be kicked; horn + headlight flash for 1 s; riding on = 35; braking after the lock dodges; two
# dodged rams and it hits a pole (a takedown).
func _phase_c5(t: int) -> void:
	if t < 2:
		return
	var b: BikerEnemy = chase.bikers[0] if (chase and is_instance_valid(chase) and not chase.bikers.is_empty()) else null
	if t == 2:
		downs.clear()
		chase = _kind_chase([[{"lane": 1, "opts": {"kind": "pickup", "ai": false, "label": "BT"}}]])
		chase.start()
		_ride(true)
		autopilot = true
		return
	if b == null:
		return
	if t == 200:
		_hold(b, BikeCombatData.SLOT_ALONG, 3.3)
	if t == 230:
		_hold(b, 0.0, 2.0)
		mark["miss0"] = chase.combat.misses
	if t == 232:
		chase.combat.kick(1)
	if t == 260:
		_check(not b.kickable() and chase.combat.misses == int(mark["miss0"]) + 1 and b.st == BikerEnemy.St.HOLD, "pickup: a kick does nothing to it")
		_hold(b, BikeCombatData.SLOT_ALONG, 3.3)
	if t == 300:
		mark["stab0"] = chase.combat.stability
		mark["f0"] = frames
		b.start_attack(1.0)
	if t > 300 and t < 420 and b.telegraphing() and b._head_mat and b._head_mat.emission_energy_multiplier > 4.0:
		mark["flash"] = true
	if t == 330:
		_check(chase.hud.warn_right, "pickup: the HUD warns on its side")
	if t > 300 and t < 420 and not mark.has("hit") and chase.combat.stability < float(mark["stab0"]):
		mark["hit"] = true
		var lead: float = float(frames - int(mark["f0"])) / 60.0
		_check(lead >= 0.95, "pickup: the ram lands %.2f s after the horn" % lead)
		_check(is_equal_approx(chase.combat.stability, float(mark["stab0"]) - float(BikeCombatData.KINDS["pickup"]["dmg"])), "pickup: the side ram costs %.0f (%.1f)" % [float(BikeCombatData.KINDS["pickup"]["dmg"]), chase.combat.stability])
	if t == 420:
		_check(mark.has("hit") and mark.has("flash"), "pickup: horn and headlight flash, then the ram hits a rider going straight")
	for k: int in 2:
		var t0: int = 520 + 240 * k
		if t == t0:
			_hold(b, BikeCombatData.SLOT_ALONG, 3.3)
		if t == t0 + 40:
			mark["stab%d" % (k + 1)] = chase.combat.stability
			b.start_attack(1.0)
		if t == t0 + 40 + 36:
			_brake(true)                      # after the lock at 0.5 s
		if t == t0 + 40 + 130:
			_brake(false)
			var want: float = float(mark["stab%d" % (k + 1)]) + (BikeCombatData.WAVE_REFILL if k == 1 else 0.0)   # its crash clears the wave
			_check(b.strikes == k + 1 and is_equal_approx(chase.combat.stability, minf(want, chase.combat.max_stability)), "pickup: braking after the lock dodges ram %d (strikes %d, stability %.0f -> %.0f, %s)" % [k + 1, b.strikes, float(mark["stab%d" % (k + 1)]), chase.combat.stability, str(b.results)])
	if t == 1000:
		_check(b.is_down() and b.crash_cause == "pole" and chase.takedowns == 1 and chase.hud.popups > 0, "pickup: two dodged rams and it hits a pole: a takedown (%s, %s)" % [b.state_name(), b.crash_cause])
		_end_chase("c6")


# C6: attacker caps (3, or 4 by wave opts) and attack starts at least 0.6 s apart, with AI riders, a thrower, a stick and the
# pickup all eager.
func _phase_c6(t: int) -> void:
	if t < 2:
		return
	var cap: int = 3 if not mark.has("second") else 4
	if t == 2:
		var w: Array = [{"lane": -1, "opts": {"hp": 99, "aggression": 1.0}}, {"lane": 1, "opts": {"hp": 99, "aggression": 1.0}},
			{"lane": -1, "opts": {"kind": "thrower", "hp": 99, "aggression": 1.0}}, {"lane": 1, "opts": {"kind": "stick", "hp": 99, "aggression": 1.0}},
			{"lane": 1, "opts": {"kind": "pickup", "aggression": 1.0}}]
		chase = _kind_chase([w], {"seed": 13 + cap}, [{"max_attackers": cap}] if cap == 4 else [])
		chase.combat.god = true
		chase.start()
		_ride(true)
		autopilot = true
		mark["att"] = 0
		mark["starts"] = []
		return
	var a: int = 0
	for e: Variant in chase.bikers:
		a += (e as BikerEnemy).attacks
	while a > int(mark["att"]):
		(mark["starts"] as Array).append(frames)
		mark["att"] = int(mark["att"]) + 1
	if t == 2 + 900:
		var st: Array = mark["starts"]
		var gap: int = 999
		for i: int in range(1, st.size()):
			gap = mini(gap, int(st[i]) - int(st[i - 1]))
		print("  C6 cap %d: %d attacks, max %d at once, min gap %d frames" % [cap, st.size(), chase.max_attackers_seen, gap])
		_check(st.size() >= 4 and chase.max_attackers_seen >= 2 and chase.max_attackers_seen <= cap, "cap %d: at most %d attackers at once (max %d, %d attacks)" % [cap, cap, chase.max_attackers_seen, st.size()])
		_check(gap >= int(BikeCombatData.ATTACK_GAP_S * 60.0) - 1, "attacks start at least 0.6 s apart (%d frames)" % gap)
		if cap == 3:
			mark.clear()
			mark["second"] = true
			_ride(false)
			autopilot = false
			chase.stop()
			chase.queue_free()
			t0 = frames
		else:
			_end_chase("c7")


# C7: takedowns: counter, popup, charge, 0.5 s slow motion + side cut (rate limited, none while 2 wind up near the player),
# spin kicks on 2 riders, an air kick off the ramp jump.
func _phase_c7(t: int) -> void:
	if t < 2:
		return
	if t == 2:
		var w: Array = []
		for i: int in 6:
			w.append({"lane": [-1, 1][i % 2], "opts": {"ai": false, "hp": 99, "label": "T%d" % i}})
		chase = _kind_chase([w])
		chase.start()
		return
	var bs: Array = chase.bikers
	if t == 4:
		for i: int in 6:
			_hold(bs[i], -4.0 - 3.0 * float(i), [-5.0, 5.0][i % 2])
	if t == 10:
		(bs[0] as BikerEnemy).crash("traffic")
		_check(chase.takedowns == 1 and chase.td_slowmos == 1 and is_equal_approx(Engine.time_scale, BikeCombatData.TD_SCALE), "takedown: counted, slow motion 0.3x (%d, %.2f)" % [chase.takedowns, Engine.time_scale])
		_check(chase.cam.current and chase.cam_mode == "td", "takedown: a side camera cut")
		_check(BikeCombatData.T_TAKEDOWN.has(chase.hud.popup_text) and is_equal_approx(chase.charge_given, 15.0), "takedown: the popup and +15 nitro charge (%s)" % chase.hud.popup_text)
	if t == 15:
		(bs[1] as BikerEnemy).crash("melon")
		_check(chase.takedowns == 2 and chase.td_slowmos == 1 and chase.hud.popup_text != BikeCombatData.T_TAKEDOWN[0], "takedown 2: counted, the popup rotates, no second slow motion within 3 s")
	if t == 10 + 32:
		_check(is_equal_approx(Engine.time_scale, 1.0) and bike.chase_cam.current and chase.cam_mode == "", "after 0.5 s real: normal time, the bike's camera (%.2f)" % Engine.time_scale)
	if t == 250:
		_hold(bs[2], BikeCombatData.SLOT_ALONG, -1.95)
		_hold(bs[3], BikeCombatData.SLOT_ALONG, 1.95)
		chase.combat.god = true
	if t == 255:
		(bs[2] as BikerEnemy).start_attack(-1.0)
		(bs[3] as BikerEnemy).start_attack(1.0)
	if t == 258:
		(bs[4] as BikerEnemy).crash("pole")
		_check(chase.takedowns == 3 and chase.td_slowmos == 1 and is_equal_approx(Engine.time_scale, 1.0), "no takedown slow motion while 2 attackers wind up near the player (%d)" % chase.td_slowmos)
	if t == 360:
		_hold(bs[2], 0.0, -1.8)
		_hold(bs[3], 0.0, 1.8)
	if t == 362:
		for k: int in 2:
			var e: BikerEnemy = bs[2 + k]
			e.take_kick(Vector2(-1.0 if k == 0 else 1.0, 0.0))
			chase.combat.kick_hit.emit(e, 0)
	if t == 420:
		var e2: BikerEnemy = bs[2]
		var e3: BikerEnemy = bs[3]
		_check(e2.crash_cause == "spin" and e3.crash_cause == "spin" and chase.takedowns == 5 and chase.td_slowmos == 2, "a spin kick on 2 riders: both down, 2 takedowns (%s %s, %d, slow %d)" % [e2.crash_cause, e3.crash_cause, chase.takedowns, chase.td_slowmos])
	if t == 470:
		_hold(bs[5], 0.0, 1.8)
	if t == 472:
		chase.start_jump()
		_check(chase.jumping() and (bs[5] as BikerEnemy).airborne and is_equal_approx(Engine.time_scale, BikeCombatData.JUMP_SCALE), "the jump: slow motion 0.4x, the rider alongside flies too")
	if t == 472 + 36:
		_check(bike.visual_pivot.position.y > 1.0 and (bs[5] as BikerEnemy).air_y > 1.0, "the jump: the bike and the rider in the air (%.2f)" % bike.visual_pivot.position.y)
		chase.combat.kick(1)
	if t == 472 + 60:
		var e5: BikerEnemy = bs[5]
		_check(e5.is_down() or e5.st == BikerEnemy.St.WOBBLE, "air kick lands (%s)" % e5.state_name())
	if t == 472 + 130:
		var e6: BikerEnemy = bs[5]
		_check(e6.crash_cause == "air" and chase.takedowns == 6 and not chase.jumping() and is_equal_approx(bike.visual_pivot.position.y, 0.0) and is_equal_approx(Engine.time_scale, 1.0),
			"an air kick is a takedown; the landing is safe, time back to 1 (%s, %d)" % [e6.crash_cause, chase.takedowns])
		_end_chase("c8")


# C8: the film opening: slow motion, the low camera, letterbox and the start line until the drop; the drop by a real-time
# timer, by the music position (before the timer), or by the timer when the track stalls; wave 0 bursts from the sides.
func _phase_c8(t: int) -> void:
	if t < 2:
		return
	var round_i: int = int(mark.get("round", 0))
	if t == 2:
		mark["mpos"] = -1.0
		var o: Dictionary = {"opening": {"drop_s": 1.0, "scale": 0.35}, "start_line": BikeCombatData.T_START_D2, "start_speed": 10.0}
		if round_i >= 1:
			o["music_pos_fn"] = func() -> float: return float(mark.get("mpos", -1.0))
		chase = _kind_chase([[{"from": "side", "lane": -1, "opts": {"ai": false}}, {"from": "side", "lane": 1, "opts": {"ai": false}}]], o)
		chase.start()
		mark["f0"] = frames
		_check(chase.opening_on and is_equal_approx(Engine.time_scale, 0.35) and chase.cam.current and chase.hud.letterboxed, "opening %d: slow motion 0.35x, the low camera, letterbox" % round_i)
		_check(chase.bikers.is_empty() and chase.remaining() == 2 and chase.hud.popup_text == BikeCombatData.T_START_D2, "opening: the start line, no biker yet")
		_check(not bike.is_controls_locked, "opening: the player can steer")
		return
	if round_i == 0 and t == 32:
		_check(absf(chase.hud.popup_left - 0.5) < 0.1, "the start line counts real seconds under slow motion (%.2f s left of 1.0)" % chase.hud.popup_left)
	if round_i == 1:
		if t == 10:
			mark["mpos"] = 0.5
		if t == 20:
			mark["mpos"] = 1.02
	if round_i == 2 and t == 10:
		mark["mpos"] = 0.2                    # the track stalls: the timer takes over 1.5 s after drop_s
	if round_i == 3 and t == 10:
		chase.stop()
		_check(is_equal_approx(Engine.time_scale, 1.0) and bike.chase_cam.current and not chase.hud.letterboxed, "stop() during the opening: normal time, the bike's camera, no letterbox")
		mark.clear()
		_end_chase("c9")
		return
	if not mark.has("drop") and not chase.opening_on and chase.drop_at >= 0.0:
		mark["drop"] = frames
		var real_f: int = frames - int(mark["f0"])
		var want: int = [60, 19, 150][round_i]
		print("  C8 round %d: drop after %d frames (by music %s)" % [round_i, real_f, str(chase.drop_by_music)])
		_check(absi(real_f - want) <= 3 and chase.drop_by_music == (round_i == 1), "opening %d: the drop at %d frames (%d), by music %s" % [round_i, want, real_f, str(chase.drop_by_music)])
		_check(is_equal_approx(Engine.time_scale, 1.0) and bike.chase_cam.current and chase.bikers.size() == 2, "the drop: normal time, the bike's camera, wave 0 spawned")
		var out_view: bool = true
		for e: Variant in chase.bikers:
			var be: BikerEnemy = e
			out_view = out_view and not chase.in_view(be.ground_pos() + Vector3(0.0, 1.0, 0.0)) and be.flare_t > 0.0
			_check(absf(chase.route.project(be.pos2).y) > chase.route.half_width + 1.0, "wave 0 bursts out of the side roads (%.1f m off the centre)" % absf(chase.route.project(be.pos2).y))
		_check(out_view, "the side riders spawn out of view, LED eyes flaring")
	if mark.has("drop") and frames == int(mark["drop"]) + 20:
		_check(not chase.hud.letterboxed, "the letterbox goes")
		chase.stop()
		chase.queue_free()
		mark.clear()
		mark["round"] = round_i + 1
		t0 = frames
	if t > 400:
		_check(false, "opening %d: no drop" % round_i)
		_end_chase("c9")


# C9: the time scale is never left below 1: retry during a takedown slow motion, lost in the air, freed in the air.
func _phase_c9(t: int) -> void:
	if t == 2:
		chase = _kind_chase([[{"lane": -1, "opts": {"ai": false, "hp": 99}}, {"lane": 1, "opts": {"ai": false, "hp": 99}}]])
		chase.start()
	if t == 4:
		_hold(chase.bikers[0], -6.0, -5.0)
		_hold(chase.bikers[1], -9.0, 5.0)
	if t == 6:
		(chase.bikers[0] as BikerEnemy).crash("traffic")
		_check(Engine.time_scale < 0.5, "test setup: takedown slow motion")
		chase.retry()
		_check(is_equal_approx(Engine.time_scale, 1.0) and bike.chase_cam.current and RadialWheel.scale_owner == null, "retry() during slow motion: time 1, the bike's camera")
	if t == 10:
		chase.start_jump()
	if t == 20:
		chase.combat.damage(999.0, "test")
	if t == 22:
		_check(lost_n > 0 and is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(bike.visual_pivot.position.y, 0.0), "lost in the air: time 1, the bike back on the ground")
		chase.retry()
	if t == 30:
		chase.start_jump()
	if t == 40:
		chase.queue_free()
	if t == 42:
		_check(is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(bike.visual_pivot.position.y, 0.0) and RadialWheel.scale_owner == null, "freed in the air: time 1, the bike on the ground")
		_next("c9b")


# C10: the set pieces on the arena route, ridden for real: each triggers at its distance (drift curb, melons, the ramp, the
# barrier with a ducking stub, the wrong way with the AI clamped left and cones, the police for 10 s), then re-arm on
# retry and the barrier without ducking knocks the player off.
const C10_PIECES: Array = [
	{"kind": "drift", "s": 150.0, "len": 30.0},
	{"kind": "melons", "s": 330.0},
	{"kind": "ramp", "s": 520.0, "d": 0.0},
	{"kind": "barrier", "s": 700.0},
	{"kind": "wrong_way", "s": 850.0, "len": 150.0},
	{"kind": "police", "s": 1080.0, "end_s": 1500.0, "dur": 10.0},
]


func _phase_c10(t: int) -> void:
	if t < 2:
		return
	if t == 2:
		downs.clear()
		mark["at"] = {}
		var ws: Array = []
		for i: int in 5:                     # wave after wave (no checkpoint moves): the chase keeps running through every piece
			ws.append([{"lane": -1, "opts": {"hp": 99, "aggression": 0.0, "label": "A%d" % i}}, {"lane": 1, "opts": {"hp": 99, "aggression": 0.0, "label": "B%d" % i}}])
		chase = _kind_chase(ws, {"set_pieces": C10_PIECES, "duck_fn": func() -> bool: return bool(mark.get("duck", false)), "seed": 21, "auto_checkpoint": false})
		chase.combat.max_stability = 1000.0
		chase.combat.stability = 1000.0
		chase.set_piece.connect(func(k: String, ph: String) -> void:
			if ph == "active" and is_instance_valid(chase):
				(mark["at"] as Dictionary)[k] = chase.s_p)
		chase.start()
		mark["duck"] = true
		_ride(true)
		autopilot = true
		mark["clamp"] = false
		mark["max_y"] = 0.0
		return
	if chase == null or not is_instance_valid(chase):
		return
	var sp: BikeSetPieces = chase.set_pieces
	var at: Dictionary = mark.get("at", {})
	if not mark.has("rearm"):
		if chase.s_p > 120.0 and chase.s_p < 178.0 and sp.prompt == BikeCombatData.T_DRIFT:
			mark["drift_prompt"] = true
		if chase.s_p > 640.0 and chase.s_p < 698.0 and sp.prompt == BikeCombatData.T_DUCK:
			mark["duck_prompt"] = true
		if chase.jumping():
			mark["max_y"] = maxf(float(mark["max_y"]), bike.visual_pivot.position.y)
		if chase.s_p > 860.0 and chase.s_p < 990.0:
			if is_equal_approx(chase.d_hi, -0.4):
				mark["clamp"] = true
			if chase.s_p > 900.0 and chase.s_p < 930.0:
				tangent_mode = true
				auto_yaw = -8.0                   # drift onto the closed half: the cones
			else:
				tangent_mode = false
				auto_yaw = 0.0
		if sp.melon_t >= 0.0 and not mark.has("melon_poke"):
			mark["melon_poke"] = true
			mark["drop_truck_s"] = sp.truck_s
			sp.melon_pos[0] = Vector3(chase.p_pos.x, sp.melon_floor + 0.3, chase.p_pos.y)
			sp.melon_vel[0] = Vector3.ZERO
			mark["mh0"] = sp.melon_hits
			var tgt: BikerEnemy = null
			for e: Variant in chase.bikers:
				if (e as BikerEnemy).is_active():
					tgt = e
					break
			if tgt:
				sp.melon_pos[1] = Vector3(tgt.pos2.x, sp.melon_floor + 0.3, tgt.pos2.y)
				sp.melon_vel[1] = Vector3.ZERO
				mark["melon_tgt"] = true
		if mark.has("melon_poke") and not mark.has("melon_chk"):
			mark["melon_chk"] = true
		if chase.police_active() > 0:
			mark["cops"] = maxi(int(mark.get("cops", 0)), chase.police_active())
		if sp.fired("police") == 1 and sp.pieces[5]["phase"] == "done" and not mark.has("cops_gone"):
			mark["cops_gone"] = frames
		if mark.has("cops_gone") and frames == int(mark["cops_gone"]) + 2:
			var leaving: int = 0
			var ram: int = 0
			for c: Variant in chase.cops:
				var ce: BikerEnemy = c
				if ce.st == BikerEnemy.St.LEAVE or ce.gone:
					leaving += 1
				ram += ce.attacks
			print("  C10: fired %s at %s, melon hits %d, cones %d, curb %d, barrier %s, cops %d (rams %d), jump max %.2f" % [str(sp.counts), str(at), sp.melon_hits, sp.cone_hits, sp.curb_hits, str(sp.results), int(mark.get("cops", 0)), ram, float(mark["max_y"])])
			_check(at.has("drift") and absf(float(at["drift"]) - 150.0) < 3.0 and sp.curb_hits == 1 and bool(mark.get("drift_prompt", false)), "drift zone: \"DRIFT!\", through it fast without drifting = the curb (%d)" % sp.curb_hits)
			_check(sp.fired("melons") == 1 and sp.melon_hits >= int(mark.get("mh0", 0)) + 1 and float(mark.get("drop_truck_s", 0.0)) > 280.0 and float(mark.get("drop_truck_s", 0.0)) <= 331.0, "melons: the tailgate drops by s 330 (truck at %.0f), a melon hit (%d)" % [float(mark.get("drop_truck_s", 0.0)), sp.melon_hits])
			var mel: int = 0
			for dn: Array in downs:
				if String(dn[1]) == "melon":
					mel += 1
			_check(mark.has("melon_tgt") and mel >= 1, "melons: a biker hitting one crashes (a takedown) (%d)" % mel)
			_check(at.has("ramp") and absf(float(at["ramp"]) - 520.0) < 3.0 and float(mark["max_y"]) > 1.2, "the ramp: a jump at s 520 (apex %.2f m)" % float(mark["max_y"]))
			_check(at.has("barrier") and absf(float(at["barrier"]) - 700.0) < 3.0 and sp.results.size() == 1 and sp.results[0] == "ducked" and lost_n == int(mark.get("lost0", lost_n)) and bool(mark.get("duck_prompt", false)),
				"the barrier: \"[CTRL] CÚI XUỐNG\" from the signs; ducking (stub) passes under it (%s)" % str(sp.results))
			_check(at.has("wrong_way") and bool(mark["clamp"]) and sp.cone_hits >= 1, "the wrong way: the AI keeps to the left half, riding into the cones hurts (%d)" % sp.cone_hits)
			_check(int(mark.get("cops", 0)) == 2 and leaving == 2 and at.has("police") and absf(float(at["police"]) - 1080.0) < 3.0, "the police: 2 cops join at s 1080 and drop back after their time (%d leaving)" % leaving)
			_check(ram >= 1, "the police ram (%d)" % ram)
			# retry: every piece after the checkpoint is armed again
			mark["rearm"] = true
			mark["duck"] = false
			_ride(false)
			autopilot = false
			chase.retry()
			var armed: int = 0
			for p: Dictionary in sp.pieces:
				if String(p["phase"]) == "armed":
					armed += 1
			_check(armed == sp.pieces.size() and chase.cops.is_empty() and sp.melon_t < 0.0, "retry(): every set piece is armed again (%d / %d)" % [armed, sp.pieces.size()])
			_check(is_equal_approx(sp.safe_checkpoint_s(660.0), 620.0) and is_equal_approx(sp.safe_checkpoint_s(600.0), 600.0) and is_equal_approx(sp.safe_checkpoint_s(720.0), 720.0),
				"a checkpoint inside the barrier's warning stretch moves back to its first sign")
			sp.rearm(1200.0)
			_check(is_equal_approx(float(sp.pieces[5].get("at", -1.0)), 1200.0 + BikeSetPieces.POLICE_REJOIN_M), "a retry past the police start: they rejoin 80 m later, not on top of it")
			sp.rearm(60.0)
			bike.global_transform = chase.route_transform(650.0)
			bike.current_speed_ms = 17.0
			mark["lost0"] = lost_n
			_ride(true)
			autopilot = true
		if t > 60 * 90:
			_check(false, "C10 timed out (s %.0f, %s, barrier %s, %s, lost %d, knocked %s)" % [chase.s_p, str(sp.counts), str(sp.results), chase.state, lost_n, str(chase.combat.knocked)])
			_end_chase("c11")
		return
	if lost_n > int(mark["lost0"]) and not mark.has("knocked"):
		mark["knocked"] = true
		_check(sp.results.back() == "hit" and chase.state == "lost" and chase.combat.knocked, "the barrier without ducking knocks the player off: lost, back to the checkpoint (%s)" % str(sp.results))
		_end_chase("c11")
	elif t > 60 * 120:
		_check(false, "C10: the barrier never knocked the player off (%s)" % str(sp.results))
		_end_chase("c11")


# C11: the Sói Xám cameo: after wave 0 (cleared) once past cameo s; he rides up from behind out of view, wheelies past, the
# card (stub) freezes, the taunt, the nitro flame, then wave 1 (after_cameo) starts; no attack token meanwhile. Then the
# forced path: at force_s with wave 0 still riding (it carries into wave 1).
func _phase_c11(t: int) -> void:
	if t < 2:
		return
	var forced: bool = mark.has("forced")
	if t == 2:
		started_w.clear()
		mark["cards"] = 0
		var cf := func(done: Callable) -> void:
			mark["cards"] = int(mark["cards"]) + 1
			mark["done_cb"] = done
			mark["card_f"] = frames
		chase = _kind_chase([[{"lane": -1, "opts": {"ai": false, "hp": 99, "label": "W0"}}], [{"lane": 1, "opts": {"ai": false, "hp": 99, "label": "W1"}}]],
			{"cameo": {"s": 150.0, "force_s": 300.0, "card_fn": cf}, "start_s": 60.0 if not forced else 280.0, "seed": 31}, [{}, {"after_cameo": true}])
		chase.start()
		_ride(true)
		autopilot = true
		mark["wheelie"] = 0.0
		return
	if chase == null or not is_instance_valid(chase):
		return
	if t == 4:
		_hold(chase.bikers[0], -8.0, -5.0)
	if t == 20 and not forced:
		(chase.bikers[0] as BikerEnemy).crash("test")
	if t == 24 and not forced:
		_check(chase.cameo_state == "waiting" and chase.s_p < 150.0 and chase.wave == 0, "wave 0 cleared before the cameo point: Sói Xám waits (%s)" % chase.cameo_state)
	if chase.cameo_state == "running" and not mark.has("cam0"):
		mark["cam0"] = frames
		var cm: BikeCameo = chase.cameo
		var p3: Vector3 = cm.rider.global_position + Vector3(0.0, 1.0, 0.0)
		_check(cm != null and not chase.in_view(p3) and cm.along < -20.0, "the cameo: he comes from behind, out of view (along %.0f)" % cm.along)
		_check(forced or absf(chase.s_p - 150.0) < 3.0, "the cameo starts at its point (s %.0f)" % chase.s_p)
		_check(not chase.request_token(chase.bikers[0] if not chase.bikers.is_empty() else null), "no attack token during the cameo")
	if chase.cameo and is_instance_valid(chase.cameo):
		mark["wheelie"] = maxf(float(mark["wheelie"]), chase.cameo.wheelie)
	if mark.has("card_f") and frames == int(mark["card_f"]) + 30:
		var cm2: BikeCameo = chase.cameo
		_check(int(mark["cards"]) == 1 and cm2.phase == "card" and cm2.along >= 6.5 and float(mark["wheelie"]) > 0.3, "the card shows once he is ahead, after a wheelie (%.2f)" % float(mark["wheelie"]))
		(mark["done_cb"] as Callable).call()
		_check(cm2.phase == "taunt" and cm2.bubble.visible and chase.hud.popup_text == BikeCombatData.T_CAMEO_TAUNT, "the card ends: his taunt")
	if chase.cameo and is_instance_valid(chase.cameo) and chase.cameo.phase == "nitro" and not mark.has("nitro"):
		mark["nitro"] = true
		_check(chase.cameo.flame.visible, "the nitro: a blue flame")
	if not mark.has("w1") and started_w.has(1):
		mark["w1"] = frames
		_check(chase.cameo_state == "done" and mark.has("nitro") and chase.wave == 1, "wave 1 starts as he pulls away (%s)" % chase.cameo_state)
		if forced:
			_check(chase.bikers.size() == 2, "forced cameo: wave 0's rider carries into wave 1 (%d)" % chase.bikers.size())
		else:
			_check(chase.bikers.size() == 1, "wave 1 alone after the cleared wave 0 (%d)" % chase.bikers.size())
	if mark.has("w1") and frames == int(mark["w1"]) + 10:
		if not forced:
			mark.clear()
			mark["forced"] = true
			_ride(false)
			autopilot = false
			chase.stop()
			chase.queue_free()
			t0 = frames
		else:
			_end_chase("c11b")
	if t > 60 * 40:
		_check(false, "C11 timed out (%s, s %.0f)" % [chase.cameo_state, chase.s_p])
		_end_chase("c11b")

# C9b: a ramp jump started inside a takedown cut gives the bike's camera back at once (and after the jump), so the downed
# rider is judged out of view by the bike's camera again.
func _phase_c9b(t: int) -> void:
	if t < 2:
		return
	if t == 2:
		chase = _kind_chase([[{"lane": -1, "opts": {"ai": false, "hp": 99, "label": "J0"}}, {"lane": 1, "opts": {"ai": false, "hp": 99, "label": "J1"}}]])
		chase.start()
		return
	if t == 4:
		_hold(chase.bikers[0], -6.0, -5.0)
		_hold(chase.bikers[1], -9.0, 5.0)
	if t == 6:
		(chase.bikers[0] as BikerEnemy).crash("traffic")
		_check(chase.cam_mode == "td" and chase.cam.current, "test setup: a takedown cut")
	if t == 9:
		chase.start_jump()
		_check(chase.cam_mode == "" and bike.chase_cam.current and chase.slow_kind == "jump", "a jump inside a takedown cut: the bike's camera at once (%s)" % chase.cam_mode)
	if t == 9 + 90:
		_check(not chase.jumping() and chase.cam_mode == "" and bike.chase_cam.current and is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null,
			"after that jump: normal time, the bike's camera")
		_end_chase("c10")


# C11b: knocked off during the cameo before his card: the retry replays the cameo (card shown once); knocked off after the
# card: the retry starts the next wave at once.
func _phase_c11b(t: int) -> void:
	if t < 2:
		return
	if t == 2:
		mark["cards"] = 0
		var cf := func(done: Callable) -> void:
			mark["cards"] = int(mark["cards"]) + 1
			mark["done_cb"] = done
			mark["card_f"] = frames
		chase = _kind_chase([[{"lane": -1, "opts": {"ai": false, "hp": 99, "label": "W0"}}], [{"lane": 1, "opts": {"ai": false, "hp": 99, "label": "W1"}}]],
			{"cameo": {"s": 150.0, "force_s": 300.0, "card_fn": cf}, "start_s": 60.0, "seed": 33}, [{}, {"after_cameo": true}])
		chase.start()
		_ride(true)
		autopilot = true
		return
	if chase == null or not is_instance_valid(chase):
		return
	if t == 4:
		_hold(chase.bikers[0], -8.0, -5.0)
	if t == 20:
		(chase.bikers[0] as BikerEnemy).crash("test")
	if not mark.has("ko1") and chase.cameo_state == "running" and chase.cameo and is_instance_valid(chase.cameo) and chase.cameo.phase == "approach" and chase.cameo.along > -15.0:
		mark["ko1"] = frames
		chase.combat.damage(999.0, "test")
	if mark.has("ko1") and frames == int(mark["ko1"]) + 3:
		_check(chase.state == "lost", "test setup: knocked off during the cameo approach")
		chase.retry()
		_check(chase.cameo_state == "running" and chase.wave == 0 and chase.bikers.is_empty() and chase.cameo != null and chase.cameo.phase == "approach" and int(mark["cards"]) == 0,
			"knocked off before his card: the retry replays the cameo, not wave 1 (%s, wave %d)" % [chase.cameo_state, chase.wave])
	if mark.has("ko1") and mark.has("card_f") and not mark.has("ko2"):
		(mark["done_cb"] as Callable).call()
		_check(chase.cameo_card_seen and int(mark["cards"]) == 1, "the replayed cameo shows the card")
		mark["ko2"] = frames
		chase.combat.damage(999.0, "test")
	if mark.has("ko2") and frames == int(mark["ko2"]) + 3:
		chase.retry()
		_check(chase.cameo_state == "done" and chase.wave == 1 and chase.bikers.size() == 1 and int(mark["cards"]) == 1, "knocked off after the card: the retry starts the next wave at once (%s, wave %d)" % [chase.cameo_state, chase.wave])
		_end_chase("b")
		arena.queue_free()
	if t > 60 * 40:
		_check(false, "C11b timed out (%s)" % chase.cameo_state)
		_end_chase("b")
		arena.queue_free()



func _finish() -> void:
	_ride(false)
	if fails.is_empty():
		print("✅ SUCCESS: BIKE COMBAT (kicks hit / miss / cooldown, wobble -> comic crash, AI kick + telegraph + dodge, stability + crash damage, knocked off -> lost -> retry, waves + checkpoint, replay -> won, traffic avoidance + crash, box-in AI, refusals, Nguyễn Xiển in FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
