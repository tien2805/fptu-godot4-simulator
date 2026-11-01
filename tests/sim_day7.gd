# File: res://tests/sim_day7.gd
# W4 Day 7 T5 (plan 2026-11-01-w4-day7.md): sloppy-bot tuning harness of the tower missions in the StoryTower scene (no
# story running), on the missions' manual clocks, one advance per physics frame. Not a regression test. Run with
# --fixed-fps 60:
#   godot --headless --fixed-fps 60 --path . --script tests/sim_day7.gd -- <normal|easy> <seed> <runs> [mission|all] [--verbose]
#   missions: typing dark saber katana guns lasers mannequins warehouse parking
# Each run plays a mission until it is won (THỬ LẠI after every fail, at most MAX_TRIES) and prints
#   SIM d7 <mission> <difficulty> seed <s>: fails F time T dmg D rank R
# then a summary line per mission (the par numbers for StoryRank and the plan's quality-bar table) and, for "all", the
# summed mean time of the missions against the 08:00 clock (Day7Clock.START_S). The 08:00 clock itself is parked high per
# run (the per-mission fails are the missions' own); the card flags are set (no villain cards).
# The models (master plan Q6: 250-400 ms reactions (+0.3 s when late), 15 % wrong or late, telegraphs read 65 %):
#   - typist (sim_day5's): 3.5-5 chars/s, 15 % of the words mistyped once (the word typed again), the lowest bullet first;
#   - fighter (sim_day5's): reads 65 % of the tells, answers after the reaction, 15 % the wrong answer (block a red one,
#     dodge or nothing on a white one), light combos in reach; QTE presses after the reaction, 15 % the wrong key;
#   - blackout: walks to the breakers nearest first (teleport steps, 3.6 m/s), the flashlight where it walks or on the
#     breaker while it holds [E]; Lọ in the beam (cone, range, line): it keeps the light on him (15 %: it does not); the
#     telegraph (the crack and his voice from the speaker by him) read 65 %: after the reaction it sidesteps across his line
#     for 1.3 s at 4.5 m/s, past the lunge (15 %: too short, 0.4 s) and then turns the light on him, aimed with a 6-12 degree error;
#   - gun bot (sim_day5's, the gallery's grid for its walks) plus Lọ's volley: the red beam read 65 %, after the reaction a
#     sprint across it for 0.9 s (15 %: 0.3 s); crouched behind a plinth that covers it from him it stays half the time
#     (the plinth takes the volley);
#   - laser runner: the lanes past the static beams; before a blink wall it waits 0.6 m short and goes when the beam goes
#     dark (+ the reaction; 15 % late +0.3-0.9 s), a warn flicker read 65 % stops it short of the beam; a sweep: it goes
#     when the beam moves away from its lane and is 1.2 m off it (15 % it misjudges the direction); 2.4-4 m/s;
#   - sneaker (sim_day5's): the showroom's zigzag lane behind the display walls, stops when a guard faces it (read 65 %);
#     seen: the gun bot in the open;
#   - forklift (sim_day3's joust): out of his charges after the reaction, rams a stalled / forks-up boss when it fits;
#   - rider (sim_bike_chase_d2's sloppy bot on the deck ring): kicks in reach, dodges the wind-ups it reads.
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")
const DT: float = 1.0 / 60.0
const TOWER: String = "res://scenes/story/StoryTower.tscn"
const TRY_CAP_S: float = 300.0
const MISSIONS: Dictionary = {"typing": "d7_typing", "dark": "d7_boss2", "saber": "d7_boss3", "katana": "d7_servers",
	"guns": "d7_boss1", "lasers": "d7_lasers", "mannequins": "d7_mannequins", "warehouse": "d7_warehouse", "parking": "d7_parking"}
const CARD_FLAGS: Array[String] = ["soi_xam_back_card", "alexander_back_card", "za_man_back_card", "van_lo_card"]

var MAX_TRIES: int = 8
var TMP: String = "user://sim_day7_%d.cfg" % OS.get_process_id()
var rng := RandomNumberGenerator.new()
var tw: StoryTower
var m: StoryMission
var sd: Node
var done_flag: bool = false
var fail_flag: bool = false
var finished: bool = false
var started: bool = false
var frames: int = 0
var verbose: bool = false
var cur: String = ""
var mt: float = 0.0                       # the bot's clock (mission time of this attempt)


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	verbose = a.has("--verbose")
	sd = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	StoryTower.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 3}, "capture_mouse": false, "go_roam": false}


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		tw = (load(TOWER) as PackedScene).instantiate()
		root.add_child(tw)
	if frames == 10 and not started:
		started = true
		_run_all()
	return finished


func _run_all() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var seed0: int = int(a[1]) if a.size() > 1 else 1
	var runs: int = int(a[2]) if a.size() > 2 else 4
	var list: Array = MISSIONS.keys()
	if a.size() > 3 and MISSIONS.has(a[3]):
		list = [a[3]]
	Difficulty.set_easy(a.size() > 0 and a[0] == "easy")     # again: GameFX applies the settings file after _initialize
	var tag: String = Difficulty.id()
	var total_t: float = 0.0
	for mission: Variant in list:
		var audit: Node = TimeAudit.new()
		root.add_child(audit)
		var fl: Array[int] = []
		var tt: float = 0.0
		var dd: float = 0.0
		var letters: Array[String] = []
		for r: int in runs:
			var res: Dictionary = await _run(String(mission), seed0 + r)
			fl.append(int(res["fails"]))
			tt += float(res["time"])
			dd += float(res["dmg"])
			letters.append(String(res.get("rank", "")))
			print("SIM d7 %s %s seed %d: fails %d time %.1f dmg %.0f rank %s %.0f |%s" % [mission, tag, seed0 + r, res["fails"], res["time"],
				res["dmg"], String(res.get("rank", "")), float(res.get("score", 0.0)), res.get("info", "")])
		var tot: int = 0
		for f: int in fl:
			tot += f
		total_t += tt / runs
		print("SIM d7 %s %s SUMMARY: fails %s mean %.2f max %d | mean time %.1f s | mean dmg %.0f | ranks %s" % [mission, tag, str(fl),
			float(tot) / float(fl.size()), fl.max(), tt / runs, dd / runs, " ".join(PackedStringArray(letters))])
		print("SIM d7 %s %s %s" % [mission, tag, String(audit.call("report"))])
		audit.queue_free()
	if list.size() > 1:
		print("SIM d7 %s CLOCK: the missions' mean times add up to %.0f s of the 08:00 clock's %.0f s" % [tag, total_t, Day7Clock.START_S])
	StoryTower.test_opts = {}
	Difficulty.set_easy(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	finished = true
	quit(0)


## One run: tries until done (fails counted), the totals.
func _run(mission: String, s: int) -> Dictionary:
	cur = mission
	rng.seed = s * 7919 + (1 if Difficulty.easy else 0)
	var opts: Dictionary = (StoryTower.test_opts["missions"] as Dictionary)
	opts["seed"] = s
	tw._opts["missions"] = opts
	if sd:
		var flags: Dictionary = sd.get("flags")
		for k: String in CARD_FLAGS:
			flags[k] = true
		Day7Clock.set_remaining(sd, 99999.0)
	tw.combat.revive()
	if not tw.start_mission(StoryMissions.beat(String(MISSIONS[mission]))):
		return {"fails": -1, "time": 0.0, "dmg": 0.0}
	m = tw.mission_node
	for sig: Signal in [m.done, m.failed]:
		for c: Dictionary in sig.get_connections():
			if (c["callable"] as Callable).get_object() == tw:
				sig.disconnect(c["callable"])
	done_flag = false
	fail_flag = false
	var info_d: Dictionary = {}
	m.done.connect(func(i: Dictionary) -> void:
		done_flag = true
		info_d.merge(i))
	m.failed.connect(func(_t: String, _r: String) -> void: fail_flag = true)
	var fails: int = 0
	var time: float = 0.0
	var dmg: float = 0.0
	var hp0: float = tw.combat.hp
	var causes: Array[String] = []
	mt = 0.0
	_reset_bot()
	while not done_flag and fails < MAX_TRIES:
		await physics_frame
		if m == null or not is_instance_valid(m):
			break
		if m.replay != null:
			m.replay.step(DT)
			continue
		if m.state == "running":
			m.advance(DT)
			time += DT
			mt += DT
			if m.state == "running":
				_bot(mission)
			if mt >= TRY_CAP_S and m.state == "running":
				m.fail("sim: stuck")
		if tw.combat.hp < hp0:
			dmg += hp0 - tw.combat.hp
		hp0 = tw.combat.hp
		if fail_flag:
			fail_flag = false
			fails += 1
			causes.append("%.0fs" % mt)
			if verbose:
				print("    %s seed %d try %d failed at %.1f s: %s" % [mission, s, fails, mt, _diag(mission)])
			mt = 0.0
			m.retry()
			hp0 = tw.combat.hp
			_reset_bot()
	var rk: Dictionary = m.rank_eval.duplicate() if m != null and is_instance_valid(m) else {}
	var st: Dictionary = m.stats.duplicate() if m != null and is_instance_valid(m) else {}
	tw._free_mission()
	tw.combat.revive()
	for k: int in 3:
		await physics_frame
	var info: String = " fails at %s" % str(causes) if not causes.is_empty() else ""
	for k2: Variant in info_d.keys():
		info += " %s=%s" % [str(k2), str(info_d[k2])]
	if not st.is_empty():
		info += " stats{time %.0f dmg %.0f fails %d}" % [float(st.get("time", 0.0)), float(st.get("dmg", 0.0)), int(st.get("fails", 0))]
	return {"fails": fails, "time": time, "dmg": dmg, "info": info, "rank": String(rk.get("letter", "")), "score": float(rk.get("score", 0.0))}


func _diag(mission: String) -> String:
	match mission:
		"dark":
			var md: MissionBossDark = m as MissionBossDark
			return "lo %s hits %d staggers %d restored %s hp %.0f" % [md.lo_state, md.hits, md.staggers, str(md.restored), tw.combat.hp]
		"typing":
			var mh: MissionTowerTyping = m as MissionTowerTyping
			return "hp %.0f/%.0f kills %d leaks %d" % [mh.hack.hp, mh.hack.hp_max, mh.hack.kills, mh.hack.leaks]
	return "hp %.0f" % tw.combat.hp


func _reset_bot() -> void:
	t_word = ""
	t_pos = 0
	t_budget = 0.0
	t_rate = rng.randf_range(3.5, 5.0)
	f_last_t = -1.0
	f_plan.clear()
	f_atk_t = 0.0
	q_idx = -1
	q_t = -1.0
	k_goal = -1
	k_dodge_t = 0.0
	k_cue_n = -1
	k_plan.clear()
	k_track_t = 0.0
	k_seen_state = ""
	if tw.combat:
		tw.combat.block_override = false
	_extra_reset()


func _react() -> float:
	return rng.randf_range(0.25, 0.4) + (0.3 if rng.randf() < 0.15 else 0.0)


func _wrong() -> bool:
	return rng.randf() < 0.15


func _reads() -> bool:
	return rng.randf() < 0.65


func _bot(mission: String) -> void:
	match mission:
		"typing":
			_type()
		"dark":
			_dark()
		"saber", "katana":
			_duel()
		_:
			_extra_bot(mission)


## Teleport steps toward `at` at `speed` (no footstep noise); true when there.
func _step_to(at: Vector3, speed: float) -> bool:
	var p: Vector3 = tw.player.global_position
	var d := Vector3(at.x - p.x, 0.0, at.z - p.z)
	if d.length() < 0.2:
		return true
	tw.player.teleport(p + d.normalized() * minf(speed * DT, d.length()), StoryMission.yaw_of(d))
	return false


# ---------------------------------------------------------------------------
# Typist (sim_day5's)
# ---------------------------------------------------------------------------
var t_word: String = ""
var t_pos: int = 0
var t_budget: float = 0.0
var t_rate: float = 4.0
var t_typo_at: int = -1


func _type() -> void:
	var h: StoryHack = (m as MissionTowerTyping).hack
	if h == null or not h.active or h.paused:
		return
	t_budget += t_rate * DT
	while t_budget >= 1.0:
		t_budget -= 1.0
		if t_word == "" or t_pos >= t_word.length():
			_next_word(h)
			if t_word == "":
				return
		if t_pos == t_typo_at:
			t_typo_at = -1
			h.type_char("#")
			t_pos = 0
			continue
		var r: String = h.type_char(t_word[t_pos])
		t_pos += 1
		if r == "typo" or r == "kill" or r == "won":
			t_word = ""


func _next_word(h: StoryHack) -> void:
	t_word = ""
	t_pos = 0
	h.typed = ""
	h.locked = {}
	if not h.final_bullet.is_empty():
		t_word = h.final_command
	else:
		var best: Dictionary = {}
		for b: Dictionary in h.bullets:
			if not bool(b["dead"]) and (best.is_empty() or float(b["y"]) > float(best["y"])):
				best = b
		if not best.is_empty():
			t_word = String(best["word"])
	t_typo_at = rng.randi_range(1, maxi(1, t_word.length() - 1)) if t_word != "" and _wrong() else -1


# ---------------------------------------------------------------------------
# Fighter (sim_day5's): the katana floor and the rooftop duel
# ---------------------------------------------------------------------------
var f_last_t: float = -1.0
var f_plan: Array = []
var f_atk_t: float = 0.0
var q_t: float = -1.0
var q_idx: int = -1


func _duel() -> void:
	var card: Variant = m.get("card")
	if card != null and is_instance_valid(card):
		(card as StoryVillainCard).step(DT)
		return
	var duel: SwordDuel = m.get("duel")
	if duel == null or duel.boss == null:
		return
	var c: PlayerCombat = tw.combat
	if duel.in_qte:
		if q_idx != duel.qte.index:
			q_idx = duel.qte.index
			q_t = _react()
		q_t -= DT
		if q_t <= 0.0 and q_idx >= 0:
			var key: String = duel.qte.wanted()
			if _wrong():
				var keys: Array[String] = ["q", "e", "lmb"]
				keys.erase(key)
				key = keys[rng.randi() % keys.size()]
			duel.qte.press(key)
			q_idx = -2
		return
	q_idx = -1
	var boss: KatanaBoss = duel.boss
	var last_t: float = float(boss.tells.back()["t"]) if not boss.tells.is_empty() else -1.0
	if last_t > f_last_t:
		f_last_t = last_t
		var tl: Dictionary = boss.tells.back()
		if _reads():
			var red: bool = bool(tl.get("red", false))
			var act: String = "dodge" if red else "block"
			if _wrong():
				act = "block" if red else ("dodge" if rng.randf() < 0.5 else "none")
			f_plan = [_react(), act, 0.0]
	if not f_plan.is_empty():
		f_plan[0] = float(f_plan[0]) - DT
		if float(f_plan[0]) <= 0.0:
			match String(f_plan[1]):
				"block":
					c.block_override = true
					f_plan[2] = float(f_plan[2]) + DT
					if float(f_plan[2]) > 0.45:
						c.block_override = false
						f_plan.clear()
				"dodge":
					c.try_dodge()
					f_plan.clear()
				_:
					f_plan.clear()
		return
	c.block_override = false
	var d: float = StoryMission.flat(boss.global_position, tw.player.global_position)
	if d > 1.9:
		_step_to(boss.global_position, 3.5)
	f_atk_t -= DT
	if f_atk_t <= 0.0 and d <= 2.4 and boss.incoming() == 0:
		f_atk_t = rng.randf_range(0.35, 0.6)
		c.light_override = true


# ---------------------------------------------------------------------------
# Blackout
# ---------------------------------------------------------------------------
const K_WALK: float = 3.6
const K_DASH: float = 4.5
var k_goal: int = -1
var k_aim: Node3D = null
var k_look := Vector3.FORWARD             # where the flashlight points (flat)
var k_cue_n: int = -1                     # md.cracks seen
var k_plan: Array = []                    # [t left, action, dir]
var k_dodge_t: float = 0.0
var k_dodge_dir := Vector3.ZERO
var k_track_t: float = 0.0                # keeps the light on him while > 0
var k_err: float = 0.0
var k_seen_ignore: bool = false
var k_seen_state: String = ""


func _dark() -> void:
	var md: MissionBossDark = m as MissionBossDark
	if k_aim == null or not is_instance_valid(k_aim):
		k_aim = Node3D.new()
		root.add_child(k_aim)
	if md.flashlight.aim != k_aim:
		md.flashlight.aim = k_aim
	var p: Vector3 = tw.player.global_position
	var lo: Node3D = md.lo
	var lo_vis: bool = lo != null and lo.visible and md.lo_state in ["stalk", "wind", "lunge"]
	# the telegraph: the crack and his voice (once per cue), read 65 %
	if md.cracks != k_cue_n:
		if verbose and k_cue_n >= 0:
			print("      t %.1f cue: lo %s d %.1f hp %.0f hold %s" % [mt, md.lo_state, StoryMission.flat(p, lo.global_position) if lo else -1.0, tw.combat.hp, str(md.hold)])
		if k_cue_n >= 0 and lo_vis and _reads():
			var away: Vector3 = p - lo.global_position
			away.y = 0.0
			var side := Vector3(-away.z, 0.0, away.x).normalized()
			if rng.randf() < 0.5:
				side = -side
			if not _in_hall(p + side * 3.0) and _in_hall(p - side * 3.0):
				side = -side                         # never into the wall it stands at
			k_plan = [_react(), "dodge", side]
		k_cue_n = md.cracks
	if not k_plan.is_empty():
		k_plan[0] = float(k_plan[0]) - DT
		if float(k_plan[0]) <= 0.0:
			k_dodge_dir = k_plan[2]
			if verbose:
				print("      t %.1f dodge %s (lo %s)" % [mt, str(k_dodge_dir.snapped(Vector3.ONE * 0.1)), md.lo_state])
			k_dodge_t = 0.4 if _wrong() else 1.3     # runs on until the lunge has passed (15 %: stops short)
			k_err = deg_to_rad(rng.randf_range(6.0, 12.0) * (1.0 if rng.randf() < 0.5 else -1.0))
			k_track_t = 2.0                      # then the light on him
			k_plan.clear()
	# in the beam: it keeps the light on him (once per sighting: 15 % it does not)
	var in_cone: bool = lo_vis and md.flashlight.is_lit() and _in_cone(md, lo.global_position + Vector3(0.0, 1.4, 0.0))
	if in_cone and k_seen_state != md.lo_state:
		k_seen_state = md.lo_state
		k_seen_ignore = _wrong()
		if not k_seen_ignore:
			k_err = deg_to_rad(rng.randf_range(-8.0, 8.0))
			k_track_t = maxf(k_track_t, 1.6)
	if not lo_vis:
		k_seen_state = ""
		k_track_t = 0.0
	k_track_t -= DT
	# the breakers, nearest first, [E] held next to one
	var br: Array = md.pts.get("breakers", [])
	if k_goal < 0 or md.restored[k_goal]:
		k_goal = -1
		var bd: float = INF
		for i: int in br.size():
			if not md.restored[i] and StoryMission.flat(p, br[i]) < bd:
				bd = StoryMission.flat(p, br[i])
				k_goal = i
	var walk_dir := Vector3.ZERO
	md.hold_override = false
	if k_dodge_t > 0.0:
		k_dodge_t -= DT
		_step_to(p + k_dodge_dir * 2.0, K_DASH)
	elif k_goal >= 0:
		var goal: Vector3 = _dark_route(p, br[k_goal])
		walk_dir = goal - p
		walk_dir.y = 0.0
		if StoryMission.flat(p, br[k_goal]) <= MissionBossDark.BREAKER_R - 0.3:
			md.hold_override = true
		else:
			_step_to(goal, K_WALK)
	# the light: on him while tracking, else where it walks (or on the breaker)
	var look: Vector3 = k_look
	if k_track_t > 0.0 and lo_vis:
		look = (lo.global_position - p).rotated(Vector3.UP, k_err)
	elif k_goal >= 0:
		look = br[k_goal] - p if md.hold_override else walk_dir
	look.y = 0.0
	if look.length() > 0.1:
		k_look = look.normalized()
	var eye: Vector3 = p + Vector3(0.0, 1.5, 0.0)
	k_aim.global_transform = Transform3D(Basis.looking_at(k_look + Vector3(0.0, -0.05, 0.0), Vector3.UP), eye)


func _in_hall(q: Vector3) -> bool:
	var l: Vector3 = tw.level.floor_xf("gallery").affine_inverse() * q
	return absf(l.x) < 12.6 and absf(l.z) < 10.6


func _in_cone(md: MissionBossDark, at: Vector3) -> bool:
	var from: Vector3 = md.flashlight.global_position
	var d: Vector3 = at - from
	var l: float = d.length()
	return l <= MissionBossDark.LIT_RANGE and l > 0.01 and (-md.flashlight.global_transform.basis.z).dot(d / l) >= cos(deg_to_rad(MissionBossDark.LIT_DEG))


## Round the plinths: through the aisle at gallery z 3 / -3 (x -6, 0, 6) when the breaker is across the hall.
func _dark_route(p: Vector3, goal: Vector3) -> Vector3:
	var lp: Vector3 = tw.level.floor_xf("gallery").affine_inverse() * p
	var lg: Vector3 = tw.level.floor_xf("gallery").affine_inverse() * goal
	if absf(lp.x - lg.x) < 4.0:
		return goal
	var az: float = 3.0 if lg.z > 0.0 else -3.0
	if absf(lp.z - az) > 0.6:
		return tw.level.floor_xf("gallery") * Vector3(clampf(lp.x, -10.5, 10.5), 0.0, az)
	return goal


# ---------------------------------------------------------------------------
# The other missions (filled step by step)
# ---------------------------------------------------------------------------
func _extra_reset() -> void:
	pass


func _extra_bot(_mission: String) -> void:
	pass
