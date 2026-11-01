# File: res://tests/sim_day6.gd
# W4 Day 6 T8 (plan 2026-11-01-w4-day6.md): sloppy-bot tuning harness of the three canal missions (the shop shift, the
# back room, the speedboat chase) in the StoryCanal scene (no story running), on the missions' manual clocks, one advance
# per physics frame. Run with --fixed-fps 60:
#   godot --headless --fixed-fps 60 --path . --script tests/sim_day6.gd -- <normal|easy> <seed> <runs> [shop|backroom|boat] [--verbose]
# Each run plays a mission until it is won (THỬ LẠI after every fail, at most MAX_TRIES) and prints
#   SIM d6 <mission> <difficulty> seed <s>: fails F time T dmg D ko K rank R
# then a summary line per mission (the par numbers for StoryRank and the table in the plan). The rank letter is
# StoryRank.evaluate on the mission's own stats and done info.
# The models (master plan Q6: 250-400 ms reactions, 15 % wrong or late, telegraphs read 65 % of the time):
#   - counter bot (MissionShop opts.bot, the mission's own): a ticket takes the reaction plus 1.0-2.6 s to scan the four
#     cups (1.25-3.0 s), 85 % the right cup, else a decoy; the biker's "như cũ" costs it 0.8 s more and 15 % more wrong
#     on Thường (it has to remember Phúc's line);
#   - sneaker: waits in the shop's doorway for the music box (Anh Duy's plan on the radio: it notices the box playing 65 %
#     of the time per 2 s look, then the reaction), then walks along the left wall and the back wall to the safe at 2.0 m/s
#     (teleport steps, as the sim_day5 sneaker); it watches the guard's cone on the floor (padded 1 m and 8 degrees, walls
#     block it, the way he turns at a corner and his "Hửm?" glance at the box count too: what a player sees coming):
#     when the cone is on its spot or on the next 1.2 m of its route it reads it 65 % of the time (once per look), after
#     the reaction it stops (the next step) or steps out of the cone the shortest way (its spot), 15 % of the reads it
#     goes anyway; at the safe it holds [E] while nothing is read, lets go and steps out when it reads the cone coming;
#   - driver: full throttle; follows Thị Lọ's lane (her current d) with the reaction lag; reads each set piece 65 % of the
#     time when it comes up (the net: the free half; the ramp: its line, 15 % of those a bit off the line; the barge: its
#     far side); dodges a rocket's red ring it reads (65 %, once per rocket); ducks before each low bridge when it reads
#     the prompt (65 %; 15 % of those late = the bonk); kicks a jet ski in reach (only a telegraphing one comes that close)
#     after the reaction when it reads it (65 % per look, a new look every second; 15 % the wrong side); blocked by the
#     pier wall it steers for the gap; the finale: rams her.
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")
const DT: float = 1.0 / 60.0
const CANAL: String = "res://scenes/story/StoryCanal.tscn"
const TRY_CAP_S: float = 240.0
const READ_P: float = 0.65
const WRONG_P: float = 0.15
const REACT: Vector2 = Vector2(0.25, 0.4)
const SHOP_SCAN: Vector2 = Vector2(1.0, 2.6)
const SNEAK_MS: float = 2.0
const AHEAD_M: float = 1.2
const CONE_PAD_M: float = 1.0
const CONE_PAD_DEG: float = 8.0
const LOOK_BOX_S: float = 2.0
## The sneaker's route in the back room's frame (x, z): in by the left wall, along the back wall, the safe.
const ROOM_ROUTE: Array[Vector2] = [Vector2(-3.0, 2.9), Vector2(-3.7, 2.3), Vector2(-3.7, -2.4), Vector2(1.9, -2.4)]
const DUCK_LEAD: float = 0.3
const DUCK_LATE_M: float = 2.0
const LOOK_AGAIN_S: float = 1.0
const LANE_GAIN: float = 0.45

var MAX_TRIES: int = int(OS.get_environment("SIM_MAX_TRIES")) if OS.get_environment("SIM_MAX_TRIES") != "" else 8
var TMP: String = "user://sim_day6_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://sim_day6_u_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://sim_day6_c_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://sim_day6_b_%d.cfg" % OS.get_process_id()
var rng := RandomNumberGenerator.new()
var sc: StoryCanal
var m: StoryMission
var done_flag: bool = false
var done_info: Dictionary = {}
var fail_flag: bool = false
var fail_reason: String = ""
var finished: bool = false
var started: bool = false
var frames: int = 0
var verbose: bool = false
var hit_kinds: Dictionary = {}
# sneaker
var w_i: int = 0
var r_read: Array = []
var r_go: bool = false
var r_look: Array = []
# driver
var bt_in: Dictionary = {"throttle": 1.0, "steer": 0.0, "duck": false}
var bt_target: float = 0.0
var bt_pend: Dictionary = {}
var bt_read: Dictionary = {}       # set piece key -> [reads, wrong]
var bt_duck: Dictionary = {}       # bridge index -> press distance
var bt_ski: Dictionary = {}        # JetSki -> [reads, react, wrong]
var bt_ski_cd: Dictionary = {}     # JetSki -> seconds before a new look
var bt_rocket: Dictionary = {}     # rocket key -> [reads, react]
var bt_dodge: Dictionary = {}      # {"d": lane, "t": seconds}


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	Difficulty.set_easy(a.size() > 0 and a[0] == "easy")
	verbose = a.has("--verbose")
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	StoryChapters.unlocks_path = TMP_U                  # a won mission records its rank: never into the real unlock file
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	StoryRankCard.skip_all = true
	StoryCanal.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 3}, "capture_mouse": false, "go_roam": false}


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		sc = (load(CANAL) as PackedScene).instantiate()
		root.add_child(sc)
	if frames == 10 and not started:
		started = true
		_run_all()
	return finished


func _run_all() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var seed0: int = int(a[1]) if a.size() > 1 else 3
	var runs: int = int(a[2]) if a.size() > 2 else 4
	var list: Array = [a[3]] if a.size() > 3 and a[3] in ["shop", "backroom", "boat"] else ["shop", "backroom", "boat"]
	Difficulty.set_easy(a.size() > 0 and a[0] == "easy")   # again: GameFX applies the settings file after _initialize
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	var tag: String = Difficulty.id()
	for mission: Variant in list:
		var audit: Node = TimeAudit.new()
		root.add_child(audit)
		var fl: Array[int] = []
		var tt: float = 0.0
		var st_t: float = 0.0
		var st_d: float = 0.0
		var st_k: float = 0.0
		var letters: Array[String] = []
		for r: int in runs:
			var res: Dictionary = await _run(String(mission), seed0 + r)
			fl.append(int(res["fails"]))
			tt += float(res["time"])
			st_t += float(res["st_time"])
			st_d += float(res["st_dmg"])
			st_k += float(res["st_ko"])
			letters.append(String(res.get("rank", "")))
			print("SIM d6 %s %s seed %d: fails %d time %.1f | stats time %.0f dmg %.0f ko %d | rank %s %.0f |%s" % [mission, tag, seed0 + r,
				res["fails"], res["time"], res["st_time"], res["st_dmg"], int(res["st_ko"]), String(res.get("rank", "")), float(res.get("score", 0.0)), res.get("info", "")])
		var tot: int = 0
		for f: int in fl:
			tot += f
		print("SIM d6 %s %s SUMMARY: fails %s mean %.2f max %d | mean time %.1f s | stats mean time %.0f dmg %.0f ko %.1f | ranks %s" % [mission, tag,
			str(fl), float(tot) / float(fl.size()), fl.max(), tt / runs, st_t / runs, st_d / runs, st_k / runs, " ".join(PackedStringArray(letters))])
		print("SIM d6 %s %s %s" % [mission, tag, String(audit.call("report"))])
		audit.queue_free()
	StoryCanal.test_opts = {}
	StoryRankCard.skip_all = DisplayServer.get_name() == "headless"
	Difficulty.set_easy(false)
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	finished = true
	quit(0)


## One run: tries until done (fails counted), the totals.
func _run(mission: String, sd: int) -> Dictionary:
	rng.seed = sd * 7919 + (1 if Difficulty.easy else 0)
	var opts: Dictionary = (StoryCanal.test_opts["missions"] as Dictionary).duplicate()
	opts["seed"] = sd
	if mission == "shop":
		opts["bot"] = {"skill": 1.0 - WRONG_P, "react": [REACT.x + SHOP_SCAN.x, REACT.y + SHOP_SCAN.y]}
	if mission == "boat":
		bt_in = {"throttle": 1.0, "steer": 0.0, "duck": false}
		opts["input"] = bt_in
	sc._opts["missions"] = opts
	if not sc.start_mission(StoryMissions.beat("d6_" + mission)):
		return {"fails": -1, "time": 0.0, "st_time": 0.0, "st_dmg": 0.0, "st_ko": 0}
	m = sc.mission_node
	for c: Dictionary in m.done.get_connections():
		m.done.disconnect(c["callable"])
	for c2: Dictionary in m.failed.get_connections():
		m.failed.disconnect(c2["callable"])
	done_flag = false
	done_info = {}
	hit_kinds = {}
	m.done.connect(func(i: Dictionary) -> void:
		done_flag = true
		done_info = i)
	m.failed.connect(func(_t: String, r: String) -> void:
		fail_flag = true
		fail_reason = r)
	if m is MissionBoatChase:
		(m as MissionBoatChase).chase.hazard_hit.connect(func(k: String) -> void: hit_kinds[k] = int(hit_kinds.get(k, 0)) + 1)
	var fails: int = 0
	var time: float = 0.0
	var try_t: float = 0.0
	var why: Array[String] = []
	_reset_bot()
	while not done_flag and fails < MAX_TRIES:
		await physics_frame
		if m == null or not is_instance_valid(m):
			break
		if m.replay != null:
			m.replay.step(DT)
			continue
		if m.state == "running":
			_bot(mission)
			m.advance(DT)
			time += DT
			try_t += DT
			if try_t >= TRY_CAP_S and m.state == "running":
				m.fail("sim: stuck", StoryMission.T_TOANG)
		if fail_flag:
			fail_flag = false
			fails += 1
			why.append("%s@%.0f" % [fail_reason.left(18), try_t])
			if verbose:
				print("    %s seed %d try %d failed at %.1f s: %s | %s" % [mission, sd, fails, try_t, fail_reason, _diag(mission)])
			try_t = 0.0
			m.retry()
			_reset_bot()
	var rk: Dictionary = m.rank_eval.duplicate() if m != null and is_instance_valid(m) else {}
	var st: Dictionary = m.stats.duplicate() if m != null and is_instance_valid(m) else {}
	var diag: String = _diag(mission) if m != null and is_instance_valid(m) else ""
	sc._free_mission()
	for k: int in 3:
		await physics_frame
	var info: String = ""
	for k2: Variant in done_info.keys():
		if String(k2) != "rank":
			info += " %s=%s" % [str(k2), str(done_info[k2])]
	if not hit_kinds.is_empty():
		info += " hits=%s" % str(hit_kinds)
	if not why.is_empty():
		info += " fails=%s" % ",".join(PackedStringArray(why))
	if not done_flag:
		info += " NOT DONE (%s)" % diag
	return {"fails": fails, "time": time, "st_time": float(st.get("time", 0.0)), "st_dmg": float(st.get("dmg", 0.0)),
		"st_ko": int(st.get("ko", 0)), "info": info, "rank": String(rk.get("letter", "")), "score": float(rk.get("score", 0.0))}


func _diag(mission: String) -> String:
	match mission:
		"shop":
			var ms: MissionShop = m as MissionShop
			return "trust %.0f ok %d wrong %d late %d" % [ms.trust, ms.served_ok, ms.served_wrong, ms.timeouts]
		"backroom":
			var mr: MissionBackroom = m as MissionBackroom
			var inv: Transform3D = (mr.pts["room_xf"] as Transform3D).affine_inverse()
			var gl: Vector3 = inv * mr.guard.global_position
			var pl: Vector3 = inv * sc.player.global_position
			return "wp %d player (%.1f, %.1f) guard (%.1f, %.1f) %s sus %.2f crack %.2f music %s" % [w_i, pl.x, pl.z, gl.x, gl.z, mr.guard_mode, mr.sus, mr.crack, str(mr.music_on)]
		"boat":
			var ch: BoatChase = (m as MissionBoatChase).chase
			return "s %.0f d %.1f v %.1f hull %.0f gap %.0f cp %d" % [ch.boat.s, ch.boat.d, ch.boat.v, ch.boat.hull, ch.rival.s - ch.boat.s, ch.cp_i]
	return ""


func _reset_bot() -> void:
	w_i = 0
	r_read = []
	r_go = false
	r_look = []
	bt_target = 0.0
	bt_pend = {}
	bt_read = {}
	bt_duck = {}
	bt_ski = {}
	bt_ski_cd = {}
	bt_rocket = {}
	bt_dodge = {}
	bt_in["throttle"] = 1.0
	bt_in["steer"] = 0.0
	bt_in["duck"] = false


func _react() -> float:
	return rng.randf_range(REACT.x, REACT.y)


func _reads() -> bool:
	return rng.randf() < READ_P


func _wrong() -> bool:
	return rng.randf() < WRONG_P


func _bot(mission: String) -> void:
	match mission:
		"backroom":
			_sneak()
		"boat":
			_drive()
	# the shop: the mission's own counter bot (opts.bot)


# ---------------------------------------------------------------------------
# Sneaker (the back room)
# ---------------------------------------------------------------------------
func _sneak() -> void:
	var mr: MissionBackroom = m as MissionBackroom
	if mr.has_ledger or mr.seen or mr.guard == null:
		mr.hold_e = false
		return
	var rx: Transform3D = mr.pts["room_xf"]
	var p: Vector3 = sc.player.global_position
	if not r_go:
		if not mr.music_on:
			return                               # waits in the doorway (the radio's plan)
		if r_look.is_empty():
			r_look = [_reads(), _react(), LOOK_BOX_S]
		r_look[1] = float(r_look[1]) - DT
		r_look[2] = float(r_look[2]) - DT
		if bool(r_look[0]) and float(r_look[1]) <= 0.0:
			r_go = true
		elif float(r_look[2]) <= 0.0:
			r_look = []                          # missed it: the next look
		return
	var last: int = ROOM_ROUTE.size() - 1
	var nxt: Vector3 = rx * Vector3(ROOM_ROUTE[w_i].x, 0.0, ROOM_ROUTE[w_i].y)
	var to := Vector3(nxt.x - p.x, 0.0, nxt.z - p.z)
	var at_safe: bool = w_i == last and to.length() < 0.2
	var ahead: Vector3 = p if at_safe else p + to.normalized() * minf(AHEAD_M, to.length())
	var here_w: bool = _watched(mr, p)
	var danger: bool = false
	if here_w or (not at_safe and _watched(mr, ahead)):
		if r_read.is_empty():
			r_read = [_reads(), _react(), _wrong()]   # read it?, the reaction, goes anyway (once per look)
		r_read[1] = float(r_read[1]) - DT
		danger = bool(r_read[0]) and float(r_read[1]) <= 0.0 and not bool(r_read[2])
	else:
		r_read = []
	if danger:
		mr.hold_e = false
		if here_w:
			var out: Variant = _escape(mr, rx, p, nxt)
			if out is Vector3:
				_step_to(out, SNEAK_MS)          # out of the cone the shortest way
			else:
				var bi: int = maxi(w_i - 1, 0)
				_step_to(rx * Vector3(ROOM_ROUTE[bi].x, 0.0, ROOM_ROUTE[bi].y), SNEAK_MS)
		return
	if at_safe:
		mr.hold_e = true
		return
	mr.hold_e = false
	if _step_to(nxt, SNEAK_MS) and w_i < last:
		w_i += 1


## The guard's cone on the floor (padded) covers p (walls and furniture block it), or will as he turns at a corner.
func _watched(mr: MissionBackroom, p: Vector3) -> bool:
	var g: Node3D = mr.guard
	var to := Vector3(p.x - g.global_position.x, 0.0, p.z - g.global_position.z)
	var dist: float = to.length()
	if dist < MissionBackroom.BUMP_M + 0.6:
		return true
	var range_m: float = mr.sight_m * (MissionBackroom.BULB_SIGHT_K if mr.bulb_t >= 0.0 else 1.0) + CONE_PAD_M
	if dist > range_m:
		return false
	var dirs: Array[Vector3] = [-g.global_transform.basis.z]
	if not mr.patrol.is_empty() and mr.guard_mode in ["patrol", "pause"]:
		var n: int = mr.patrol.size()
		var at: Vector3 = mr.patrol[mr.patrol_i]
		if mr.guard_mode == "pause":
			dirs.append((mr.patrol[(mr.patrol_i + 1) % n] as Vector3) - g.global_position)
		elif StoryMission.flat(g.global_position, at) < 1.0:
			dirs.append((mr.patrol[(mr.patrol_i + 1) % n] as Vector3) - at)
	if mr.guard_mode == "lure" and mr.glance_phase != "":
		dirs.append(mr.glance_at - g.global_position)   # "Hửm?": he is about to look back there
	var in_cone: bool = false
	for f: Vector3 in dirs:
		var ff := Vector3(f.x, 0.0, f.z)
		if ff.length() > 0.01 and rad_to_deg(ff.normalized().angle_to(to / dist)) < mr.sight_deg + CONE_PAD_DEG:
			in_cone = true
	if not in_cone:
		return false
	var eye: Vector3 = g.global_position + Vector3(0.0, MissionBackroom.EYE_Y, 0.0)
	return mr.clear_line(eye, p + Vector3(0.0, 1.0, 0.0))


## The nearest spot out of the (padded) cone: rings of 0.6 / 1.2 / 1.8 m in 16 directions, inside the room's walls and
## off the music box table; the nearer to the route's next point wins a tie. null when every one is watched.
func _escape(mr: MissionBackroom, rx: Transform3D, p: Vector3, goal: Vector3) -> Variant:
	var inv: Transform3D = rx.affine_inverse()
	for r: float in [0.6, 1.2, 1.8]:
		var best: Variant = null
		var best_d: float = INF
		for k: int in 16:
			var a: float = TAU * float(k) / 16.0
			var q: Vector3 = p + Vector3(cos(a), 0.0, sin(a)) * r
			var ql: Vector3 = inv * q
			if absf(ql.x) > 3.9 or absf(ql.z) > 3.0 or (absf(ql.x) < 0.8 and absf(ql.z - 0.4) < 0.7):
				continue
			if _watched(mr, q):
				continue
			var gd: float = q.distance_to(goal)
			if gd < best_d:
				best_d = gd
				best = q
		if best != null:
			return best
	return null


func _step_to(at: Vector3, speed: float) -> bool:
	var p: Vector3 = sc.player.global_position
	var d := Vector3(at.x - p.x, 0.0, at.z - p.z)
	if d.length() < 0.2:
		return true
	sc.player.teleport(p + d.normalized() * minf(speed * DT, d.length()), StoryMission.yaw_of(d))
	return false


# ---------------------------------------------------------------------------
# Driver (the speedboat chase)
# ---------------------------------------------------------------------------
func _drive() -> void:
	var ch: BoatChase = (m as MissionBoatChase).chase
	if ch == null or ch.state != "running":
		return
	var b: PlayerBoat = ch.boat
	var s: float = b.s
	var lim: float = LairCanal.HALF_W - 2.0
	var want: float = clampf(ch.rival.d, -lim, lim)
	# the nets: the free half of the nearest one ahead (read once each)
	for k: int in LairCanal.NETS.size():
		var ns: float = float(LairCanal.NETS[k][0])
		if s > ns - 65.0 and s < ns + 3.0:
			if _piece("net%d" % k)[0]:
				want = -float(LairCanal.NETS[k][1]) * 4.5
			break
	# the ramp: its line (a bit off it on a wrong read)
	var lip: float = LairCanal.RAMP_S - 6.0
	if s > lip - 90.0 and s < lip:
		var rd: Array = _piece("ramp")
		if rd[0]:
			if not bt_read.has("ramp_line"):
				var off: float = (1.4 if rng.randf() < 0.5 else -1.4) if rd[1] else 0.0
				bt_read["ramp_line"] = LairCanal.RAMP_D + off
			want = float(bt_read["ramp_line"])
	# blocked by the pier wall: the gap by the left bank
	var w0: float = LairCanal.RAMP_S - BoatData.WALL_HALF
	if not b.airborne and s > w0 - BoatData.LEN_HALF - 4.0 and s < w0 and b.v < 3.0 and b.d > LairCanal.GAP_D1 - 0.5:
		want = -(LairCanal.HALF_W - 1.7)
		bt_target = want                     # obvious: no reading needed (it still reacts)
	# the barge: its far side
	if s > LairCanal.BARGE_S - 70.0 and s < LairCanal.BARGE_S + 8.0:
		if _piece("barge")[0] and absf(want - LairCanal.BARGE_D) < BoatData.BARGE_HALF_D + 2.0:
			want = LairCanal.BARGE_D - BoatData.BARGE_HALF_D - 2.2
	# the rockets: dodge a ring it reads
	_rockets(ch, b)
	if not bt_dodge.is_empty():
		bt_dodge["t"] = float(bt_dodge["t"]) - DT
		if float(bt_dodge["t"]) <= 0.0:
			bt_dodge = {}
		else:
			want = float(bt_dodge["d"])
	if ch.finale:
		want = clampf(ch.rival.d, -lim - 1.0, lim + 1.0)
	# the reaction lag on every change of lane
	if absf(want - bt_target) > 0.8:
		if bt_pend.is_empty():
			bt_pend = {"d": want, "t": _react()}
		bt_pend["d"] = want
		bt_pend["t"] = float(bt_pend["t"]) - DT
		if float(bt_pend["t"]) <= 0.0:
			bt_target = float(bt_pend["d"])
			bt_pend = {}
	else:
		bt_pend = {}
		bt_target = want
	bt_in["steer"] = clampf((bt_target - b.d) * LANE_GAIN - b.lat_v * 0.05, -1.0, 1.0)
	bt_in["throttle"] = 1.0
	# the low bridges: duck before each (15 % late)
	var duck: bool = false
	for i: int in LairCanal.BRIDGES.size():
		var bs: float = LairCanal.BRIDGES[i]
		if bs - s < 60.0 and s < bs + 3.0:
			if not bt_duck.has(i):
				bt_duck[i] = -99.0 if not _reads() else (DUCK_LATE_M if _wrong() else 8.0 + b.v * DUCK_LEAD)
			if bs - s < float(bt_duck[i]):
				duck = true
	bt_in["duck"] = duck
	_kicks(ch, b)


## A set piece read once as it comes up: [read it?, wrong (a bit off)].
func _piece(key: String) -> Array:
	if not bt_read.has(key):
		bt_read[key] = [_reads(), _wrong()]
	return bt_read[key]


func _rockets(ch: BoatChase, b: PlayerBoat) -> void:
	var rs: Array = ch.set_pieces.rockets
	for i: int in rs.size():
		var r: Dictionary = rs[i]
		if not bool(r["live"]):
			continue
		var key: String = "%d:%.1f" % [i, float(r["s"])]
		if not bt_rocket.has(key):
			bt_rocket[key] = [_reads(), _react()]
		var rr: Array = bt_rocket[key]
		rr[1] = float(rr[1]) - DT
		if not bool(rr[0]) or float(rr[1]) > 0.0 or rr.size() > 2:
			continue
		rr.append(true)                          # acted on
		var rd: float = float(r["d"])
		if absf(rd - b.d) < BoatData.ROCKET_R + 1.6:
			var lim: float = LairCanal.HALF_W - 2.0
			var side: float = 1.0 if b.d >= rd else -1.0
			var to: float = rd + side * 4.2
			if absf(to) > lim:
				to = rd - side * 4.2
			bt_dodge = {"d": to, "t": float(r["tell"]) + 0.4}
			bt_target = to                       # the dodge is the reaction itself
			bt_pend = {}


func _kicks(ch: BoatChase, b: PlayerBoat) -> void:
	for sk: JetSki in ch.skis:
		if bt_ski_cd.has(sk):
			bt_ski_cd[sk] = float(bt_ski_cd[sk]) - DT
			if float(bt_ski_cd[sk]) <= 0.0:
				bt_ski_cd.erase(sk)
		if not sk.is_threat():
			bt_ski.erase(sk)
			continue
		var lat: float = absf(sk.d - b.d)
		var reach: bool = absf(sk.s - b.s) <= BoatData.KICK_ALONG and lat >= BoatData.KICK_MIN and lat <= BoatData.KICK_MAX
		if not reach or bt_ski_cd.has(sk):
			bt_ski.erase(sk)
			continue
		if not bt_ski.has(sk):
			bt_ski[sk] = [_reads(), _react(), _wrong()]
		var kr: Array = bt_ski[sk]
		kr[1] = float(kr[1]) - DT
		if float(kr[1]) > 0.0:
			continue
		bt_ski.erase(sk)
		bt_ski_cd[sk] = LOOK_AGAIN_S
		if bool(kr[0]):
			var side: int = 1 if sk.d > b.d else -1
			ch.kick(-side if bool(kr[2]) else side)
