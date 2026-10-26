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
		if c > 0x2000 or (c < 0x80 and not (char(c) in " ,.:-[]/!0123456789\n") and not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122))):
			return false
	return true


func _data_checks() -> void:
	for s: String in BikeCombatData.texts():
		_check(_plain(s), "plain text without emoji or decorative symbols: '%s'" % s)
	_check(BikeCombatData.WINDUP_S + BikeCombatData.ENEMY_HIT_AT >= 0.45, "an enemy kick is telegraphed >= 0.45 s before it lands")
	_check(BikeCombatData.KICK_WINDUP < BikeCombatData.KICK_ACTIVE_END and BikeCombatData.KICK_ACTIVE_END < BikeCombatData.KICK_DUR, "kick: wind-up < hit window end < duration")
	_check(BikeCombatData.T_START_D2 == "Tới công chuyện luôn!" and BikeCombatData.T_WIN_D2 == "Đỉnh nóc kịch trần bay phấp phới", "the Day 2 meme lines")
	var w: Array = BikeChase.day2_waves()
	_check(w.size() == 2 and (w[0] as Array).size() + (w[1] as Array).size() == 6, "the Day 2 layout: 6 bikers in 2 waves")
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
	if frames > 20000:
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
		_check(is_equal_approx(chase.combat.stability, 80.0), "an enemy kick costs 20 stability (%.1f)" % chase.combat.stability)
	if t == 70:
		_check(mark.has("hit_f") and b3.results.back() == "hit", "the AI kick hit (%s)" % str(b3.results))
	if t == 110:
		_check(b3.st == BikerEnemy.St.HOLD, "back to its hold after the recovery (%s)" % b3.state_name())
		bike.crash_occurred.emit()
		_check(is_equal_approx(chase.combat.stability, 55.0), "a crash costs 25 stability (%.1f)" % chase.combat.stability)
		bike.crash_occurred.emit()
		_check(is_equal_approx(chase.combat.stability, 55.0), "i-frames swallow a second crash at once (%.1f)" % chase.combat.stability)
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
		_check(lag >= 45 and lag <= 52, "the replay starts 0.8 s after the last fall (%d frames)" % lag)
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
		_check(att >= 2 and chase.max_attackers_seen <= 2, "they attack, never more than 2 at once (%d attacks, max %d)" % [att, chase.max_attackers_seen])
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
		_check(c2.waves.size() == 2 and c2.remaining() == 6, "setup(waves) adds the Day 2 waves (%d, %d left)" % [c2.waves.size(), c2.remaining()])
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
		_check(b.results.back() == "hit" and is_equal_approx(chase.combat.stability, 80.0), "riding straight: the AI kick hits (%s, %.1f)" % [str(b.results), chase.combat.stability])
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
		_check(b.results.back() == "miss" and is_equal_approx(chase.combat.stability, 80.0), "steering away during the wind-up dodges the kick (%s, %.1f, %.2f m apart)" % [str(b.results), chase.combat.stability, rel.length()])
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
			if String(d[1]) == "kick":
				kicked += 1
		print("  A10: won after %.1f s, %d m ridden, %d kicks (%d hits), %d biker attacks, stability %.0f, %d down (%d by kicks)" % [float(t) / 60.0, int(chase.end_s - float(mark["s0"])), chase.combat.kicks, chase.combat.hits, _attacks_total(), chase.combat.stability, downs.size(), kicked])
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
			arena.queue_free()
			_next("b")
	if t > 3000 and not mark.has("won"):
		_check(false, "A11: never reached end_at_s (s %.0f)" % chase.s_p)
		_ride(false)
		autopilot = false
		chase.queue_free()
		arena.queue_free()
		_next("b")


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


func _finish() -> void:
	_ride(false)
	if fails.is_empty():
		print("✅ SUCCESS: BIKE COMBAT (kicks hit / miss / cooldown, wobble -> comic crash, AI kick + telegraph + dodge, stability + crash damage, knocked off -> lost -> retry, waves + checkpoint, replay -> won, traffic avoidance + crash, box-in AI, refusals, Nguyễn Xiển in FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
