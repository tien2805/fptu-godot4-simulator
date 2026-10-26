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
#     A2 the AI kick: a telegraph (WINDUP, HUD "BÊN TRÁI" warning) >= 0.45 s before the hit, -20 stability; a dodge
#        (the player 3.5 m away during the wind-up) misses; a crash (PlayerBike.crash_occurred) -25, i-frames swallow a
#        second one.
#     A3 stability 0 -> knocked off (bike locked and on its side, kicks refused) -> `lost`, bikers ride off (LEAVE);
#        retry() -> stability 100, bike unlocked and upright at the wave checkpoint, the wave spawned again; stop().
#     A4 two waves: wave_cleared(0), the 2.5 s gap, wave_started(1), the checkpoint moves to wave 1, the recorder tracks
#        the last wave; the last fall -> "finishing", mark "blow", the replay (manual) 0.8 s later, focus = the fallen
#        rider, then `won`, the tree unpaused.
#     A5 traffic: a parked car in a biker's path is passed (avoidance, no crash); a slow touch is a scrape (pushed out);
#        a kicked biker wobbling into a car crashes ("traffic"); the traffic sees the bikers (extra_obstacles_fn, kind
#        "biker") while the chase runs, not after.
#     A6 three AI bikers with the player riding (god mode): they keep pace, take FRONT / LEFT / RIGHT, box the player in,
#        brake-check, attack (never more than 2 at once) and stay on the road.
#     A7 input refusals: kick() not riding / chase not running -> refused (counted); a real [E] press kicks while riding;
#        freeing a running chase unlocks the bike and clears the hooks.
#   B (FreeRoam at night): start() mounts and places the rider on Nguyễn Xiển (300 m), FreeRoam's hint shows the kicks,
#     [F] is refused with a hint; riding on autopilot over the Rạch Hầm bridge the bikers catch up, follow over the deck
#     and keep to the road; the HUD fits the viewport; stop() clears the hint and [F] works again.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_bike_combat.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const BIKE_SCENE: String = "res://scenes/PlayerBike.tscn"
const Z0: float = 250.0                  # the arena route runs from z = 250 north to z = -400 along x = 0

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
func _arena_chase(n_per_wave: Array, ai: bool = false, opts: Dictionary = {}) -> BikeChase:
	var c := BikeChase.new()
	c.name = "Chase%d" % frames
	arena.add_child(c)
	var o: Dictionary = {"bike": bike, "route": [Vector2(0.0, Z0), Vector2(0.0, -400.0)], "start_s": 60.0, "manual_replay": true, "seed": 3}
	for k: String in opts.keys():
		o[k] = opts[k]
	c.setup(o)
	for n: int in n_per_wave:
		var w: Array = []
		for i: int in n:
			w.append({"lane": [-1, 1, 0, -1][i % 4], "opts": {"ai": ai, "label": "T%d" % i}})
		c.add_wave(w)
	c.biker_down.connect(func(b: BikerEnemy, cause: String) -> void: downs.append([b, cause]))
	c.lost.connect(func() -> void: lost_n += 1)
	c.won.connect(func() -> void: won_n += 1)
	c.wave_cleared.connect(func(i: int) -> void: cleared.append(i))
	c.wave_started.connect(func(i: int) -> void: started_w.append(i))
	return c


## Put biker b at (along, lat) of the player (route frame), stopped, holding there.
func _hold(b: BikerEnemy, along: float, lat: float) -> void:
	b.hold_along = along
	b.hold_lat = lat
	var p: Vector2 = chase.target_at(along, lat)
	b.place(Vector3(p.x, 0.0, p.y), 0.0, 0.0)


func _on_physics() -> void:
	frames += 1
	var t: int = frames - t0
	if frames > 9000:
		_check(false, "timed out in phase %s" % phase)
		_finish()
		return
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
		"b":
			_phase_b(t)


func _build_arena() -> void:
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena, 1400.0)
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
		_hold(b3, BikeCombatData.SLOT_ALONG, -BikeCombatData.SLOT_LAT)
	if t == 112:
		b3.start_attack(-1.0)
	if t == 112 + 18:
		bike.global_position += Vector3(3.5, 0.0, 0.0)   # the player swerves away during the wind-up
	if t == 112 + 60:
		_check(b3.results.back() == "miss" and is_equal_approx(chase.combat.stability, 80.0), "a dodge during the wind-up: the kick misses (%s, %.1f)" % [str(b3.results), chase.combat.stability])
		bike.global_position -= Vector3(3.5, 0.0, 0.0)
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
	if t == 4:
		for b: Variant in chase.bikers:
			(b as BikerEnemy).crash("test")
		_check(cleared == [0] and chase.state == "running" and chase._gap_left > 0.0, "wave 0 cleared, the gap runs (%s)" % str(cleared))
	if t == 4 + 152:
		_check(started_w == [0, 1] and chase.wave == 1 and chase.bikers.size() == 1, "wave 1 starts after the 2.5 s gap (%s)" % str(started_w))
		_check(int(chase._cp["wave"]) == 1, "the checkpoint moved to wave 1")
		_check(chase.rec != null and chase.rec.tracked().size() >= 5, "the recorder tracks the bike, its pivot, rider and the last wave (%d)" % (chase.rec.tracked().size() if chase.rec else 0))
		_hold(chase.bikers[0], 0.0, 1.8)
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
	if mark.has("won") and frames == int(mark["won"]) + 2:
		chase.queue_free()
		_next("a5")
	if t > 1200:
		_check(false, "A4 timed out (%s, replay %s)" % [chase.state, str(chase.replay)])
		chase.queue_free()
		_next("a5")


# ---------------------------------------------------------------------------
# A5: traffic
# ---------------------------------------------------------------------------
func _arena_traffic() -> RoamTraffic:
	var md := MapData.new()
	md.data = {"roads": [{"id": 1, "name": "Đường thử", "class": "primary", "width": 8.0, "lanes": 2, "oneway": false,
		"roundabout": false, "bridge": false, "region": "corridor", "points": [[0.0, Z0], [0.0, -400.0]]}]}
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
		c2.setup({"bike": bike, "route": [Vector2(0.0, Z0), Vector2(0.0, -400.0)], "waves": BikeChase.day2_waves()})
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
	Input.action_release("gas")
	if fails.is_empty():
		print("✅ SUCCESS: BIKE COMBAT (kicks hit / miss / cooldown, wobble -> comic crash, AI kick + telegraph + dodge, stability + crash damage, knocked off -> lost -> retry, waves + checkpoint, replay -> won, traffic avoidance + crash, box-in AI, refusals, Nguyễn Xiển in FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
