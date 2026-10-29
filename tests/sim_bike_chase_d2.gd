# File: res://tests/sim_bike_chase_d2.gd
# Tuning harness for the Day 2 "Tokyo Drift" chase (spec 2026-10-27, plan 2026-10-27-d2x-chase.md "Tuning results"). Not a
# regression test: it plays the real chase (MissionBikeChase's route, waves, set pieces and cameo, without the story) in
# FreeRoam at night with a bot, retries after every knock-off like THỬ LẠI, and prints one line per run plus a summary.
# Bots (real steering, gas / brake / drift actions, kicks through PlayerBikeCombat.kick):
#   first    a first-time player: reacts to a telegraph 55 % of the time after 0.38 s, kicks a rider in reach after 0.3 s
#            with 70 % odds, ducks under the barrier 70 % of the time, drifts in a drift zone 30 % of the time;
#   skilled  reacts 90 % after 0.2 s, kicks at once, always ducks, drifts in every zone;
#   sloppy   the Q6 standard (plan 2026-10-29-w2-day2.md): 250-400 ms reaction delay on every decision, 15 % of them wrong
#            or late (a dodge the wrong way, a kick to the wrong side, no duck, a roadblock gap missed, +0.3 s), reads 65 %
#            of the telegraphs, a slow lateral wander off the line so it hits traffic sometimes.
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_bike_chase_d2.gd -- sloppy 1 3 normal
#   (bot, first seed, runs, difficulty normal | easy)
extends SceneTree

const BOTS: Dictionary = {
	"first": {"react": 0.55, "delay": 0.38, "kick_p": 0.7, "kick_delay": 0.3, "duck": 0.7, "drift": 0.3, "corner_brake": 0.6},
	"skilled": {"react": 0.9, "delay": 0.2, "kick_p": 1.0, "kick_delay": 0.08, "duck": 1.0, "drift": 1.0, "corner_brake": 1.0},
	"sloppy": {"react": 0.65, "delay": 0.25, "delay_max": 0.4, "kick_p": 0.8, "kick_delay": 0.25, "duck": 0.85, "drift": 0.7,
		"corner_brake": 0.85, "wrong": 0.15, "wander": 1.1, "gap_p": 0.85},
}
const MAX_GAME_S: float = 480.0

var bot: String = "first"
var diff: String = "normal"
var _wander_ph: float = 0.0
var _block_aim: Dictionary = {}          # roadblock s -> [aim from (game s), lateral aim]
var bp: Dictionary = {}
var seed0: int = 1
var runs: int = 3
var run_i: int = 0
var roam: Node3D
var chase: BikeChase
var bike: PlayerBike
var rng := RandomNumberGenerator.new()
var frames: int = 0
var phase: String = "settle"
var t0: int = 0
var game_t: float = 0.0
var real_f: int = 0
var fails: int = 0
var fail_causes: Array[String] = []
var dmg: Dictionary = {}
var last_cause: String = ""
var retry_at: int = -1
var duck_now: bool = false
var results: Array[Dictionary] = []
# bot state
var _seen: Dictionary = {}               # telegraphing biker -> [t first seen, reacted?, will react]
var _reach_t: Dictionary = {}            # kick target -> time in reach
var _brake_left: float = 0.0
var _shift_left: float = 0.0
var _shift: float = 0.0
var _helmets_seen: Dictionary = {}
var _zone_roll: Dictionary = {}
var _barrier_roll: int = -1
var wave_t: Array[float] = []
var clear_t: Array[float] = []
var attacks_seen: int = 0
var cameo_t: float = -1.0


func _initialize() -> void:
	Engine.max_fps = 0
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 1 and BOTS.has(a[0]):
		bot = a[0]
	if a.size() >= 2:
		seed0 = int(a[1])
	if a.size() >= 3:
		runs = int(a[2])
	if a.size() >= 4:
		diff = a[3]
	bp = BOTS[bot]
	print("--- SIM DAY 2 CHASE (bot %s, seeds %d..%d) ---" % [bot, seed0, seed0 + runs - 1])
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	roam.set("mayhem_enabled", false)
	root.add_child(roam)
	roam.call("set_time_of_day", "night")
	physics_frame.connect(_on_physics)


func _start_run() -> void:
	Difficulty.set_easy(diff == "easy")      # after GameFX loaded the owner's setting
	rng.seed = seed0 + run_i
	_wander_ph = rng.randf_range(0.0, TAU)
	_block_aim.clear()
	fails = 0
	fail_causes.clear()
	dmg.clear()
	game_t = 0.0
	real_f = 0
	_seen.clear()
	_reach_t.clear()
	_helmets_seen.clear()
	_zone_roll.clear()
	_barrier_roll = -1
	wave_t.clear()
	clear_t.clear()
	cameo_t = -1.0
	var md: MapData = roam.get("md")
	var route: BikeRoute = MissionBikeChase.day2_route(md)
	chase = BikeChase.new()
	chase.name = "SimChase%d" % run_i
	roam.add_child(chase)
	chase.setup({"roam": roam, "route": route, "start_line": BikeCombatData.T_START_D2, "win_line": BikeCombatData.T_WIN_D2,
		"replay_slot": "", "auto_replay": false, "seed": seed0 + run_i, "profile": BikeCombatData.CHASE_PROFILE,
		"start_speed": BikeCombatData.START_SPEED_D2, "opening": {"drop_s": BikeCombatData.OPEN_DROP_S, "scale": BikeCombatData.OPEN_SCALE},
		"set_pieces": BikeCombatData.DAY2_SET_PIECES, "waves": BikeChase.day2_waves(), "wave_opts": BikeChase.day2_wave_opts(),
		"cameo": {"s": BikeCombatData.CAMEO_S, "force_s": BikeCombatData.CAMEO_FORCE_S}, "start_s": MissionBikeChase.START_S,
		"end_at_s": route.bridge_s + MissionBikeChase.END_PAST_M, "duck_fn": func() -> bool: return duck_now, "takedown_cam": false})
	chase.combat.damaged.connect(func(amount: float, cause: String) -> void:
		dmg[cause] = float(dmg.get(cause, 0.0)) + amount
		last_cause = cause)
	chase.lost.connect(_on_lost)
	chase.wave_started.connect(func(i: int) -> void: wave_t.append(game_t))
	chase.wave_cleared.connect(func(i: int) -> void: clear_t.append(game_t))
	chase.cameo_started.connect(func() -> void: cameo_t = game_t)
	bike = roam.get("bike")
	chase.start()
	phase = "run"
	t0 = frames


func _on_lost() -> void:
	fails += 1
	fail_causes.append("%s@%.0f" % [last_cause, chase.s_p])
	retry_at = frames + 90                    # TOANG! card, THỬ LẠI


func _on_physics() -> void:
	frames += 1
	match phase:
		"settle":
			if frames == 150:
				_start_run()
		"run":
			_run()
		"next":
			if frames - t0 >= 30:
				_start_run()
		"done":
			pass


func _run() -> void:
	var dt: float = 1.0 / 60.0
	real_f += 1
	game_t += dt * Engine.time_scale
	if retry_at >= 0 and frames >= retry_at:
		retry_at = -1
		chase.retry()
		_brake_left = 0.0
		_shift_left = 0.0
	if chase.state == "won" or chase.state == "finishing" or game_t > MAX_GAME_S:
		_end_run()
		return
	if chase.state != "running":
		_controls(false, false, false, 0.0)
		return
	_bot(dt)


func _end_run() -> void:
	var rev: Dictionary = StoryRank.evaluate("d2_chase", {"time": float(real_f) / 60.0, "fails": fails, "ko": chase.takedowns})
	print("  RANK d2_chase %s %s seed %d: %s %.0f (time %.0f s, fails %d, takedowns %d)" % [bot, diff, seed0 + run_i, String(rev["letter"]),
		float(rev["score"]), float(real_f) / 60.0, fails, chase.takedowns])   # Wave 3 T10 calibration
	var r: Dictionary = {"seed": seed0 + run_i, "fails": fails, "causes": fail_causes.duplicate(), "real_s": float(real_f) / 60.0,
		"state": chase.state, "escaped": chase.escaped, "downed": chase.downed_total, "takedowns": chase.takedowns,
		"kicks": chase.combat.kicks, "hits": chase.combat.hits, "dmg": dmg.duplicate(), "waves": wave_t.duplicate(), "cameo": cameo_t,
		"melons": chase.set_pieces.melon_hits, "cones": chase.set_pieces.cone_hits, "curbs": chase.set_pieces.curb_hits,
		"barrier": chase.set_pieces.results.duplicate(), "helmets": "%d/%d" % [chase.helmets_hit, chase.helmets_thrown],
		"gap": chase.set_pieces.gap_results.duplicate(), "block": chase.set_pieces.block_results.duplicate()}
	var left: Array[String] = []
	for b: Variant in chase.bikers:
		if is_instance_valid(b) and not (b as BikerEnemy).is_down():
			var e: BikerEnemy = b
			var rel: Vector2 = e.pos2 - chase.p_pos
			left.append("%s %s along %.0f lat %.1f throws %d attacks %d" % [e.label, e.state_name(), rel.dot(chase.p_fwd), rel.dot(chase.p_right), e.throws, e.attacks])
	results.append(r)
	var dm: Array[String] = []
	for k: String in dmg.keys():
		dm.append("%s %.0f" % [k, float(dmg[k])])
	print("  gap %s, roadblock %s, previews %d" % [str(r["gap"]), str(r["block"]), chase.set_pieces.previews])
	print("  run %d (seed %d): %s in %.0f s real (%d fails %s), downed %d, escaped %d, takedowns %d, kicks %d/%d, dmg {%s}, waves at %s (cleared %s), cameo %.0f, enemy attacks %d (%d hit), melons %d, cones %d, curbs %d, barrier %s, helmets %s, left %s" % [
		run_i, seed0 + run_i, chase.state, float(real_f) / 60.0, fails, str(fail_causes), chase.downed_total, chase.escaped, chase.takedowns,
		chase.combat.hits, chase.combat.kicks, ", ".join(dm), str(wave_t.map(func(x: float) -> int: return int(x))), str(clear_t.map(func(x2: float) -> int: return int(x2))), cameo_t, chase.attack_starts, chase.attack_hits,
		chase.set_pieces.melon_hits, chase.set_pieces.cone_hits, chase.set_pieces.curb_hits, str(chase.set_pieces.results), r["helmets"], str(left)])
	_controls(false, false, false, 0.0)
	chase.stop()
	chase.queue_free()
	chase = null
	run_i += 1
	if run_i >= runs:
		_summary()
		return
	phase = "next"
	t0 = frames


func _enemy_attacks() -> int:
	var n: int = 0
	for b: Variant in chase.bikers + chase._downed:
		if is_instance_valid(b):
			n += (b as BikerEnemy).attacks
	return n


func _enemy_hits() -> int:
	var n: int = 0
	for b: Variant in chase.bikers + chase._downed:
		if is_instance_valid(b):
			n += (b as BikerEnemy).results.count("hit")
	return n


func _summary() -> void:
	phase = "done"
	var f: int = 0
	var t: float = 0.0
	var won: int = 0
	for r: Dictionary in results:
		f += int(r["fails"])
		t += float(r["real_s"])
		if String(r["state"]) == "won" or String(r["state"]) == "finishing":
			won += 1
	var per: Array = []
	for r2: Dictionary in results:
		per.append(int(r2["fails"]))
	print("SUMMARY bot %s (%s): %d runs, %d finished, fails per run %s = %.2f on average, average %.0f s real per run (with retries)" % [bot, diff, results.size(), won, str(per),
		float(f) / maxf(results.size(), 1.0), t / maxf(results.size(), 1.0)])
	Difficulty.set_easy(false)
	quit(0)


# ---------------------------------------------------------------------------
# BOT
# ---------------------------------------------------------------------------
func _roll(p: float) -> bool:
	return rng.randf() < p


func _bot(dt: float) -> void:
	var route: BikeRoute = chase.route
	var s: float = chase.s_p
	var spd: float = absf(bike.current_speed_ms)
	_brake_left -= dt
	_shift_left -= dt
	# reactions to telegraphs (a rider / stick / heavy / pickup / police rider winding up near the player)
	for b: Variant in chase.bikers + chase.cops:
		var e: BikerEnemy = b as BikerEnemy
		if e == null or not is_instance_valid(e):
			continue
		if e.telegraphing() and e.kind != "thrower" and e.pos2.distance_to(chase.p_pos) < 8.0:
			if not _seen.has(e):
				_seen[e] = [game_t, false, _roll(float(bp["react"])), _delay()]
			var sv: Array = _seen[e]
			if bool(sv[2]) and not bool(sv[1]) and game_t - float(sv[0]) >= float(sv[3]):
				sv[1] = true
				var lat: float = (e.pos2 - chase.p_pos).dot(chase.p_right)
				var wrong: bool = _roll(float(bp.get("wrong", 0.0)))
				if e.kind == "stick" or e.kind == "pickup":
					_brake_left = 0.55 if not wrong else 0.0
				else:
					_shift = -signf(lat) * 2.2 * (-1.0 if wrong else 1.0)
					_shift_left = 0.55
		elif _seen.has(e) and not e.is_attacking():
			_seen.erase(e)
	# red helmet markers in the player's path
	for h: Dictionary in chase.helmets:
		if not bool(h["active"]):
			continue
		var key: int = int((h["node"] as Node).get_instance_id())
		if _helmets_seen.has(key):
			continue
		_helmets_seen[key] = true
		if _roll(float(bp["react"])):
			_brake_left = maxf(_brake_left, 0.6)
	for k: Variant in _helmets_seen.keys():
		var still: bool = false
		for h2: Dictionary in chase.helmets:
			if bool(h2["active"]) and int((h2["node"] as Node).get_instance_id()) == int(k):
				still = true
		if not still:
			_helmets_seen.erase(k)
	# kicks
	if chase.combat.kick_cd <= 0.0 and not chase.combat.kicking():
		for sd: int in [-1, 1]:
			var tg: Node3D = chase.combat.kick_target(sd)
			if tg == null:
				continue
			_reach_t[tg] = float(_reach_t.get(tg, 0.0)) + dt
			if float(_reach_t[tg]) >= (_delay() if bp.has("delay_max") else float(bp["kick_delay"])):
				_reach_t.erase(tg)
				if _roll(float(bp["kick_p"])):
					chase.combat.kick(-sd if _roll(float(bp.get("wrong", 0.0))) else sd)
				break
	# set pieces: the barrier and the drift zones
	duck_now = false
	var drift: bool = false
	for p: Dictionary in chase.set_pieces.pieces:
		var ph: String = p["phase"]
		if String(p["kind"]) == "barrier" and ph == "tele":
			if _barrier_roll < 0:
				_barrier_roll = 1 if _roll(float(bp["duck"])) else 0
			duck_now = _barrier_roll == 1 and s > float(p["s"]) - 12.0
		elif String(p["kind"]) == "barrier" and ph != "tele":
			if ph == "armed":
				_barrier_roll = -1
		if String(p["kind"]) == "drift" and (ph == "tele" or ph == "active"):
			var key2: float = float(p["s"])
			if not _zone_roll.has(key2):
				_zone_roll[key2] = _roll(float(bp["drift"]))
			drift = bool(_zone_roll[key2]) and ph == "active"
	# steering toward the route ahead (+ a dodge shift)
	var look: float = 9.0 + spd * 0.35
	var want_d: float = 0.0
	if bp.has("wander"):                      # the sloppy bot is never exactly on the line (it meets traffic)
		want_d = (sin(game_t * 0.45 + _wander_ph) * 0.75 + sin(game_t * 1.2 + _wander_ph * 1.7) * 0.25) * float(bp["wander"])
	if _shift_left > 0.0:
		want_d = _shift
	# the roadblock: aim for its gap once seen (after a reaction delay; sometimes off)
	for p3: Dictionary in chase.set_pieces.pieces:
		if String(p3["kind"]) == "roadblock" and String(p3["phase"]) == "tele":
			var key3: float = float(p3["s"])
			if not _block_aim.has(key3):
				var off: float = 1.8 if not _roll(float(bp.get("gap_p", 1.0))) else 0.0
				_block_aim[key3] = [game_t + _delay(), float(p3.get("gap_d", 0.0)) + off]
			if game_t >= float(_block_aim[key3][0]):
				want_d = float(_block_aim[key3][1]) * chase.dir_sign
	for p2: Dictionary in chase.set_pieces.pieces:
		if String(p2["kind"]) == "wrong_way" and String(p2["phase"]) == "active":
			want_d = minf(want_d, -1.4) if chase.dir_sign > 0.0 else want_d
	var tgt: Vector2 = route.world(clampf(s + look, 0.0, route.length), want_d)
	var to: Vector2 = tgt - chase.p_pos
	var want: float = atan2(-to.x, -to.y)
	var err: float = wrapf(want - bike.rotation.y, -PI, PI)
	var steer: float = clampf(err * 3.0, -1.0, 1.0)
	# corners: brake into a sharp turn unless drifting it
	var sharp: float = route.max_turn(s + 5.0, s + 35.0)
	var brake: bool = _brake_left > 0.0
	if sharp > 55.0 and spd > 15.0 and not drift and _roll(float(bp["corner_brake"]) * 0.2 + 0.8 * float(bp["corner_brake"])):
		brake = true
	_controls(not brake, brake, drift and absf(steer) > 0.15, steer)


## A reaction delay: the bot's own, the sloppy bot's 250-400 ms (+0.3 s when late).
func _delay() -> float:
	if not bp.has("delay_max"):
		return float(bp["delay"])
	var d: float = rng.randf_range(float(bp["delay"]), float(bp["delay_max"]))
	if _roll(float(bp.get("wrong", 0.0)) * 0.5):
		d += 0.3
	return d


func _controls(gas: bool, brake: bool, drift: bool, steer: float) -> void:
	if gas:
		Input.action_press("gas")
	else:
		Input.action_release("gas")
	if brake:
		Input.action_press("brake")
	else:
		Input.action_release("brake")
	if drift:
		Input.action_press("drift")
	else:
		Input.action_release("drift")
	if steer > 0.02:
		Input.action_press("steer_left", steer)
		Input.action_release("steer_right")
	elif steer < -0.02:
		Input.action_press("steer_right", -steer)
		Input.action_release("steer_left")
	else:
		Input.action_release("steer_left")
		Input.action_release("steer_right")
