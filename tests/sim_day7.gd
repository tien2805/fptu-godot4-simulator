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
#   - laser runner: the lanes past the static beams at 4 m/s; a leg near a blink wall or a sweep is judged: read 65 % =
#     the whole crossing checked ahead (now and 0.4 s later), unread = the beams as they are now (a warn looks dark, a
#     sweep's way is not followed), 15 % wrong = judged 0.7 s early; it goes after the reaction;
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
		"guns":
			var mg: MissionBossGuns = m as MissionBossGuns
			return "slots %d slot %d pick %d pos %s wave %d left %d volleys %d shots %d hits %d dodges %d stays %d shattered %d bot %s cover %s e_shots %d e_hits %d" % [mg.fight.cover.count() if mg.fight.cover else -1, b_slot, _pick_slot(mg.fight, false, 14.0) if mg.fight.cover else -9, str(tw.level.floor_xf("gallery").affine_inverse() * tw.player.global_position), mg.fight.wave,
				mg.fight.enemies_left(), mg.volleys, mg.volley_shots, mg.volley_hits, v_dodges, v_stays, mg.shattered, b_state,
				str(mg.fight.cover_ctl.in_cover if mg.fight.cover_ctl else false), e_shots, e_hits]
		"lasers":
			var ml: MissionTowerLasers = m as MissionTowerLasers
			return "wp %d moving %s read %s wrong %s at %s t %.2f" % [l_i, str(l_moving), str(l_read), str(l_wrong),
				str(tw.level.floor_xf("gallery").affine_inverse() * tw.player.global_position), ml.t]
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
	_gun_reset()
	_laser_reset()
	v_plan.clear()
	v_t = 0.0
	if m and m is MissionBossGuns:
		v_seen = (m as MissionBossGuns).volleys


func _extra_bot(mission: String) -> void:
	match mission:
		"guns":
			_guns()
		"lasers":
			_lasers()


# ---------------------------------------------------------------------------
# Gun bot: sim_day5's (the w3-shared sloppy gun bot) with the basement's map swapped for the floor's grid.
# ---------------------------------------------------------------------------
const NO_LOS_S: float = 3.0
const MOVE_S: float = 7.0
const HUNT_S: float = 10.0

var b_fight: GunFight = null
var e_shots: int = 0
var st_hist: Dictionary = {}
var e_hits: int = 0
var b_state: String = "cover"
var b_until: float = 0.0
var b_pending: Array = []
var b_slot: int = -1
var b_reload_until: float = -1.0
var b_shot_cd: float = 0.0
var b_nolos: float = 0.0
var bt: float = 0.0
# Wave 3 integration (the w3-shared T11 model): the target-finding reaction, the flank reaction, the dive
var use_dive: bool = false
var b_aim_g: Object = null               # the target being acquired / held (untyped: it may be freed)
var b_aim_at: float = 0.0                # first shot at it from this time (a reaction after a pop or a target switch)
var b_hit_from := Vector3.ZERO           # where the last shot that hit it while crouched came from
var b_hit_t: float = -99.0
var b_hit_fight: GunFight = null         # the fight whose player_hit is connected
var b_last_dive: float = -99.0           # on the bot clock bt (reset with it: a stale value stopped the dives)
var b_dive_seen: bool = false            # the queued dive really started (BulletTime picks the press up a frame later)
var b_dives_run: int = 0
var b_dive_from: int = -1                # the slot it dived out of (it takes it again after the dive)
var b_label: Dictionary = {}             # rack row -> [read it?, reaction left] while that domino chance lasts
var gr_nodes: Array[Vector3] = []
var gr_edges: Array = []
var gr_key: int = -1
var r_path: Array[Vector3] = []
var r_goal: Vector3 = Vector3.INF
var r_replan: float = 0.0
var r_last_p: Vector3 = Vector3.ZERO
var r_stuck_t: float = 0.0


func _gun_reset() -> void:
	b_fight = null
	b_pending.clear()
	b_reload_until = -1.0
	b_shot_cd = 0.0
	b_nolos = 0.0
	b_slot = -1
	bt = 0.0                                 # the clock first: every timer below is set from it
	b_aim_g = null
	b_hit_t = -99.0
	b_last_dive = -99.0
	b_dive_seen = false
	b_label.clear()
	if tw and tw.player:
		tw.player.jump_override = false
	r_path.clear()
	r_goal = Vector3.INF
	_stop_walk()
	_set_state("cover", rng.randf_range(0.8, 1.6))


func _gun(f: GunFight) -> void:
	if f == null or f.state != "running" or f.cover_ctl == null:
		_stop_walk()
		return
	if f != b_fight:
		b_fight = f
		gr_key = -1
		b_slot = -1
		b_pending.clear()
		b_aim_g = null
		_set_state("cover", _react())
	if b_hit_fight != f:
		b_hit_fight = f
		if not f.player_hit.is_connected(_on_player_hit):
			f.player_hit.connect(_on_player_hit)
	bt += DT
	_watch_glints(f)
	b_shot_cd -= DT
	for i: int in range(b_pending.size() - 1, -1, -1):
		var pd: Array = b_pending[i]
		if bt >= float(pd[0]):
			b_pending.remove_at(i)
			_do(f, String(pd[1]))
	if b_reload_until > 0.0 and bt >= b_reload_until:
		b_reload_until = -1.0
		_reload_now()
	if f.alive().is_empty():
		_stop_walk()
		tw.weapons.aim_override = false
		return
	for e5: Variant in f.alive():
		if e5 is Gunman:
			var sn: String = Gunman.ST_NAMES[(e5 as Gunman).st]
			st_hist[sn] = float(st_hist.get(sn, 0.0)) + DT
	if f.cover_ctl.in_cover:
		b_slot = f.cover_ctl.slot
	match b_state:
		"cover":
			_stop_walk()
			tw.weapons.aim_override = false
			f.cover_ctl.hold_override = true
			if not _has("move") and ((b_slot >= 0 and (not f.cover.protects(b_slot, _threat(f)) or _flanked(f, b_slot))) or not f.cover_ctl.in_cover):
				_later("move")
			if bt >= b_until and not _has("pop"):
				_later("pop", 0.3 if _wrong() else 0.0)
				b_until = INF
		"pop":
			_stop_walk()
			tw.weapons.aim_override = true
			if _shoot(f):
				b_nolos = 0.0
			else:
				b_nolos += DT
			if b_nolos >= NO_LOS_S:
				b_nolos = 0.0
				b_pending.clear()
				f.cover_ctl.hold_override = false
				_set_state("hunt", HUNT_S)
				return
			if bt >= b_until and not _has("duck"):
				_later("duck")
				b_until = INF
			if use_dive and bt - b_last_dive >= 20.0 and f.bullet_time and f.bullet_time.enabled 					and f.bullet_time.focus >= BulletTime.FOCUS_MAX - 0.01 and f.alive().size() >= 3 and not _has("dive"):
				_later("dive", 0.3 if _wrong() else 0.0)
		"dive":
			_stop_walk()
			tw.weapons.aim_override = true
			_shoot(f, true)
			var btm: BulletTime = f.bullet_time
			if btm != null and btm.state != "idle":
				b_dive_seen = true
			if btm == null or (btm.state == "idle" and (b_dive_seen or bt >= b_until - 1.7)):   # over, or refused
				b_slot = _back_slot(f)
				if b_slot >= 0:
					_set_state("move", MOVE_S)     # back to a slot it walks to (never snaps in from afar)
				else:
					_set_state("pop", rng.randf_range(1.2, 2.0))
		"move":
			tw.weapons.aim_override = false
			f.cover_ctl.hold_override = false
			if b_slot < 0:
				_set_state("pop", rng.randf_range(1.2, 2.0))
				return
			var goal: Vector3 = f.cover.pos[b_slot]
			var arrived: bool = _walk(f, goal)
			if arrived or bt >= b_until:
				_stop_walk()
				if StoryMission.flat(goal, tw.player.global_position) <= GunData.COVER_ENTER_R and not (f.taken.has(b_slot) and f.taken[b_slot] != tw.player):
					f.cover_ctl.hold_override = true
					f.cover_ctl.enter(b_slot)
					_set_state("cover", rng.randf_range(0.6, 1.2))
				else:
					b_slot = -1
					_set_state("pop", rng.randf_range(1.2, 2.0))
		"ammo":
			tw.weapons.aim_override = false
			f.cover_ctl.hold_override = false
			var box: AmmoPickup = null
			var bd2: float = INF
			for pk: AmmoPickup in f.pickups:
				var d4: float = StoryMission.flat(pk.global_position, tw.player.global_position)
				if not pk.taken and d4 < bd2:
					bd2 = d4
					box = pk
			if box == null or bt >= b_until or _any_ammo():
				_stop_walk()
				_set_state("cover", _react())
				return
			_walk(f, box.global_position)
		"hunt":
			tw.weapons.aim_override = false
			f.cover_ctl.hold_override = false
			var tg: Gunman = _target(f)
			if tg != null and StoryMission.flat(tg.global_position, tw.player.global_position) < 20.0 or bt >= b_until:
				_stop_walk()
				b_slot = _pick_slot(f, _wrong(), 7.0)
				if b_slot >= 0 and not _slot_sees(f, b_slot):
					b_slot = -1                      # no cover with a view here: it fights from where it stands
				if b_slot >= 0 and not f.cover_ctl.in_cover:
					_set_state("move", MOVE_S)
				else:
					_set_state("pop", rng.randf_range(1.2, 2.0))
				return
			var near: Node3D = null
			var nd: float = INF
			for e: Variant in f.alive():
				var d: float = StoryMission.flat((e as Node3D).global_position, tw.player.global_position)
				if d < nd:
					nd = d
					near = e as Node3D
			if near:
				_walk(f, near.global_position)


func _set_state(s: String, secs: float) -> void:
	b_state = s
	b_until = bt + secs


func _later(action: String, extra: float = 0.0) -> void:
	b_pending.append([bt + _react() + extra, action])


func _has(action: String) -> bool:
	for pd: Array in b_pending:
		if String(pd[1]) == action:
			return true
	return false


func _do(f: GunFight, action: String) -> void:
	match action:
		"pop":
			if b_state == "cover":
				_set_state("pop", 3.5 if _wrong() else rng.randf_range(1.2, 2.0))
				b_aim_g = null
				b_label.clear()                  # every pop is a new look at the labels
		"dive":
			if b_state == "pop" and f.bullet_time:
				f.cover_ctl.hold_override = false
				f.cover_ctl.leave()
				tw.weapons.aim_override = true
				tw.player.input_override = null
				tw.player.jump_override = true
				b_last_dive = bt
				b_dive_from = b_slot
				b_dives_run += 1
				b_aim_g = null
				b_dive_seen = false
				_set_state("dive", 2.0)
		"duck":
			if b_state == "pop":
				_set_state("cover", rng.randf_range(0.8, 1.6))
		"move":
			if b_state == "cover":
				var s: int = _pick_slot(f, _wrong(), 14.0)
				if s >= 0 and s != f.cover_ctl.slot:
					b_slot = s
					f.cover_ctl.hold_override = false
					f.cover_ctl.leave()
					_set_state("move", MOVE_S)


func _watch_glints(f: GunFight) -> void:
	for g: Variant in f.gunmen:
		if is_instance_valid(g) and not (g as Gunman).telegraph_started.is_connected(_on_glint):
			(g as Gunman).telegraph_started.connect(_on_glint)
			(g as Gunman).shot.connect(_on_enemy_shot)


func _on_enemy_shot(_g: Gunman, result: String) -> void:
	e_shots += 1
	if result == "hit":
		e_hits += 1


func _on_glint(_g: Gunman) -> void:
	if b_state == "pop" and rng.randf() < 0.65:
		_later("duck", 0.3 if _wrong() else 0.0)


## Shot while crouched: that cover does not protect against him (the flank reaction).
func _on_player_hit(src: Node3D, _d: float) -> void:
	if b_state == "cover" and is_instance_valid(src):
		b_hit_from = src.global_position
		b_hit_t = bt


## Hit while crouched in slot i within the last 1.5 s by a shooter that slot does not protect against.
func _flanked(f: GunFight, i: int) -> bool:
	return bt - b_hit_t < 1.5 and not f.cover.protects(i, b_hit_from)


func _threat(f: GunFight) -> Vector3:
	var acc := Vector3.ZERO
	var n: int = 0
	for e: Variant in f.alive():
		acc += (e as Node3D).global_position
		n += 1
	return acc / float(n) if n > 0 else tw.player.global_position


## The nearest gunman with a clear line to his chest (crouched: lowered by his drop); a pallet facing the bot pushes him back.
func _target(f: GunFight) -> Gunman:
	var best: Gunman = null
	var bd: float = INF
	var eye: Vector3 = tw.player.global_position + Vector3(0.0, 1.35, 0.0)
	for e: Variant in f.alive():
		if not (e is Gunman):
			continue
		var gm: Gunman = e
		var d: float = eye.distance_to(gm.feet())
		if gm.has_method("has_shield") and bool(gm.call("has_shield")) and bool(gm.call("front_hit", tw.player.global_position)):
			d += 6.0
		if d < bd and f.clear_line(eye, gm.feet() + Vector3(0.0, 1.2 - gm.drop, 0.0)):
			bd = d
			best = gm
	return best


## The held target is still up and in sight (a human keeps aiming at him; the nearest one is picked only when he is lost).
func _holds(f: GunFight, o: Variant, eye: Vector3) -> bool:
	if o == null or not is_instance_valid(o) or not f.alive().has(o):
		return false                         # (untyped: a knocked-out target may be freed already)
	var g: Gunman = o
	return f.clear_line(eye, g.feet() + Vector3(0.0, 1.2 - g.drop, 0.0))


## The best free slot within max_d that protects against the threat (wrong: one that does not) and, in the basement's
## aisles, from which a gunman can be seen when it pops out (else the nearest protecting one).
func _pick_slot(f: GunFight, wrong: bool, max_d: float) -> int:
	var th: Vector3 = _threat(f)
	var p: Vector3 = tw.player.global_position
	var best: int = -1
	var bd: float = INF
	var any: int = -1
	var ad: float = INF
	for i: int in f.cover.count():
		if f.taken.has(i) and f.taken[i] != tw.player:
			continue
		var prot: bool = f.cover.protects(i, th) and not (bt - b_hit_t < 3.0 and not f.cover.protects(i, b_hit_from))
		if prot == wrong:
			continue
		var d: float = StoryMission.flat(f.cover.pos[i], p)
		if d >= max_d or StoryMission.flat(f.cover.pos[i], th) <= 4.0:
			continue
		if d < ad:
			ad = d
			any = i
		if d < bd and _slot_sees(f, i):
			bd = d
			best = i
	return best if best >= 0 else any


## After a dive: the slot it dived out of when it is free and still protects, else the nearest protecting one (any view).
func _back_slot(f: GunFight) -> int:
	var th: Vector3 = _threat(f)
	if b_dive_from >= 0 and b_dive_from < f.cover.count() and f.cover.protects(b_dive_from, th) 			and not (f.taken.has(b_dive_from) and f.taken[b_dive_from] != tw.player):
		return b_dive_from
	var p: Vector3 = tw.player.global_position
	var best: int = -1
	var bd: float = 14.0
	for i: int in f.cover.count():
		if (f.taken.has(i) and f.taken[i] != tw.player) or not f.cover.protects(i, th):
			continue
		var d: float = StoryMission.flat(f.cover.pos[i], p)
		if d < bd:
			bd = d
			best = i
	return best


## A gunman's standing chest is in sight from the slot's standing eye.
func _slot_sees(f: GunFight, i: int) -> bool:
	var eye: Vector3 = f.cover.pos[i] + Vector3(0.0, 1.5, 0.0)
	for e: Variant in f.alive():
		if e is Gunman and f.clear_line(eye, (e as Gunman).feet() + Vector3(0.0, 1.2, 0.0)):
			return true
	return false


## One round per pistol cycle while popped: a label (the domino), else the target. True when it had something in sight.


## One round per pistol cycle while popped (sim_day5's without the basement's rack domino). True when it had something in sight.
func _shoot(f: GunFight, diving: bool = false) -> bool:
	if b_reload_until > 0.0:
		return true
	if _ammo() <= 0:
		var w: WeaponDirector = tw.weapons
		if w.reserve_of(w.current) != 0:
			if b_state == "pop" and not _wrong():
				_set_state("cover", 1.7)          # ducks to reload (15 %: reloads in the open)
			b_reload_until = bt + float(WeaponData.SLOTS[w.current]["reload"])
		else:
			_swap_or_scavenge(f)
		return true
	var eye: Vector3 = tw.player.global_position + Vector3(0.0, 1.35, 0.0)
	if b_shot_cd > 0.0:
		return true
	var g: Gunman = (b_aim_g as Gunman) if _holds(f, b_aim_g, eye) else _target(f)
	if g == null:
		return false
	if g != b_aim_g:
		b_aim_g = g
		b_aim_at = bt + _react()
	if bt < b_aim_at:
		return true
	_fire()
	var d: float = tw.player.global_position.distance_to(g.feet())
	var shotgun: bool = tw.weapons.current == WeaponData.Slot.SHOTGUN
	var p: float = clampf(1.25 - d / 14.0, 0.05, 0.95) if shotgun else _hit_p(d)
	if tw.player.horizontal_speed > 1.0 and not diving:
		p *= 0.6
	if diving:
		p = minf(0.95, p * 1.3)
	if rng.randf() < p:
		tw.weapons.hit_target(g, {"kind": "pellet" if shotgun else "bullet", "from": tw.player.global_position})
	return true


func _fire() -> void:
	var w: WeaponDirector = tw.weapons
	b_shot_cd = float(WeaponData.SLOTS[w.current]["cycle"])
	if w.current < w.ammo.size() and w.ammo[w.current] > 0:
		w.ammo[w.current] -= 1


func _any_ammo() -> bool:
	var w: WeaponDirector = tw.weapons
	for sl: int in [WeaponData.Slot.PISTOL, WeaponData.Slot.SHOTGUN]:
		if sl < w.ammo.size() and (w.ammo[sl] > 0 or w.reserve_of(sl) != 0):
			return true
	return false


func _ammo() -> int:
	var w: WeaponDirector = tw.weapons
	return w.ammo[w.current] if w.current < w.ammo.size() else 0


## The magazine refilled from the spare rounds (the real numbers; -1 = unlimited).
func _reload_now() -> void:
	var w: WeaponDirector = tw.weapons
	var c: int = w.current
	if c >= w.ammo.size():
		return
	var need: int = int(WeaponData.SLOTS[c]["mag"]) - w.ammo[c]
	var res: int = w.reserve_of(c)
	var n: int = need if res < 0 else mini(need, res)
	w.ammo[c] += n
	if res >= 0 and c < w.reserve.size():
		w.reserve[c] -= n


## Dry: the other gun of the loadout if it has rounds, else to the nearest ammo box.
func _swap_or_scavenge(f: GunFight) -> void:
	var w: WeaponDirector = tw.weapons
	for sl: int in [WeaponData.Slot.PISTOL, WeaponData.Slot.SHOTGUN]:
		if sl != w.current and sl < w.ammo.size() and (w.ammo[sl] > 0 or w.reserve_of(sl) != 0):
			w.equip(sl)
			b_shot_cd = 0.6
			return
	if b_state != "ammo":
		f.cover_ctl.hold_override = false
		f.cover_ctl.leave()
		_set_state("ammo", 20.0)


func _hit_p(d: float) -> float:
	return clampf(0.55 * pow(15.0 / maxf(d, 1.0), 0.7), 0.15, 0.85)


# ----- walking -----
func _stop_walk() -> void:
	if tw and tw.player:
		tw.player.input_override = null
		tw.player.sprint_override = false
	r_path.clear()
	r_stuck_t = 0.0


## One frame of walking toward `to` (sprint, the real controller); true once within 0.7 m.
func _walk(f: GunFight, to: Vector3) -> bool:
	var p: Vector3 = tw.player.global_position
	if StoryMission.flat(p, to) < 0.7:
		_stop_walk()
		return true
	r_replan -= DT
	if r_path.is_empty() or r_replan <= 0.0 or StoryMission.flat(r_goal, to) > 1.0:
		r_path = _plan(f, p, to)
		r_goal = to
		r_replan = 1.0
	while r_path.size() > 1 and StoryMission.flat(p, r_path[0]) < 0.7:
		r_path.pop_front()
	var d: Vector3 = r_path[0] - p
	d.y = 0.0
	tw.player.yaw = atan2(-d.x, -d.z)
	tw.player.input_override = Vector2(0.0, -1.0)
	tw.player.sprint_override = true
	r_stuck_t += DT
	if r_stuck_t >= 1.0:
		if StoryMission.flat(p, r_last_p) < 0.4:
			r_replan = 0.0
			tw.player.yaw += rng.randf_range(-1.2, 1.2)
		r_last_p = p
		r_stuck_t = 0.0
	return false


## World points from `from` to `to`: straight when walkable, else the shortest waypoint route (Dijkstra over the graph).
func _plan(f: GunFight, from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if f.clear_walk(from, to):
		out.append(to)
		return out
	_graph(f)
	var n: int = gr_nodes.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var seen := PackedByteArray()
	seen.resize(n)
	var ends: Dictionary = {}
	for i: int in n:
		var ds: float = StoryMission.flat(gr_nodes[i], from)
		if ds < 16.0 and f.clear_walk(from, gr_nodes[i]):
			dist[i] = ds
		var de: float = StoryMission.flat(gr_nodes[i], to)
		if de < 16.0 and f.clear_walk(gr_nodes[i], to):
			ends[i] = de
	var best_end: int = -1
	var best_cost: float = INF
	while true:
		var u: int = -1
		var ud: float = INF
		for i: int in n:
			if seen[i] == 0 and dist[i] < ud:
				ud = dist[i]
				u = i
		if u < 0 or ud >= best_cost:
			break
		seen[u] = 1
		if ends.has(u) and ud + float(ends[u]) < best_cost:
			best_cost = ud + float(ends[u])
			best_end = u
		for v: int in gr_edges[u]:
			var nd: float = ud + StoryMission.flat(gr_nodes[u], gr_nodes[v])
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if best_end >= 0:
		var k: int = best_end
		while k >= 0:
			out.push_front(gr_nodes[k])
			k = prev[k]
	out.append(to)
	return out


## The waypoint graph (world), its walkable edges rebuilt when the fallen rows change.


## The waypoint graph of the floor (a grid between the plinths / display walls), its walkable edges (GunFight.clear_walk),
## rebuilt when a plinth breaks.
func _graph(f: GunFight) -> void:
	var fl: String = String((m.get("pts") as Dictionary).get("floor", "gallery")) if m.get("pts") is Dictionary else "gallery"
	var key: int = int(m.get("shattered")) if m.get("shattered") != null else 0
	if key == gr_key and not gr_nodes.is_empty():
		return
	gr_key = key
	gr_nodes.clear()
	var xs: Array = [-12.0, -6.0, 0.0, 6.0, 12.0]
	var zs: Array = [9.0, 3.0, -3.0, -9.0]
	if fl == "mannequins":
		xs = [-5.5, 0.0, 5.5]
		zs = [23.0, 18.0, 12.0, 8.5, 3.5, -0.5, -5.5, -9.5, -14.0, -17.0, -22.0]
	for z: Variant in zs:
		for x: Variant in xs:
			gr_nodes.append(tw.level.world(fl, Vector3(float(x), 0.0, float(z))))
	gr_edges.clear()
	for i: int in gr_nodes.size():
		gr_edges.append([])
	for i: int in gr_nodes.size():
		for j: int in range(i + 1, gr_nodes.size()):
			if StoryMission.flat(gr_nodes[i], gr_nodes[j]) < 12.5 and f.clear_walk(gr_nodes[i], gr_nodes[j]):
				(gr_edges[i] as Array).append(j)
				(gr_edges[j] as Array).append(i)


# ---------------------------------------------------------------------------
# Boss guns: the gun bot plus Lọ's volley (the red beam read 65 %, a sprint across it)
# ---------------------------------------------------------------------------
var v_seen: int = 0
var v_plan: Array = []
var v_t: float = 0.0
var v_dir := Vector3.ZERO
var v_stays: int = 0
var v_dodges: int = 0


func _guns() -> void:
	var mg: MissionBossGuns = m as MissionBossGuns
	_gun(mg.fight)
	var f: GunFight = mg.fight
	if mg.volley_state == "tele" and mg.volleys != v_seen:
		v_seen = mg.volleys
		if _reads():
			var lo_p: Vector3 = mg.lo.global_position if mg.lo and is_instance_valid(mg.lo) else mg.aim_from
			var covered: bool = f.cover_ctl != null and f.cover_ctl.in_cover and f.cover.protects(f.cover_ctl.slot, lo_p)
			if covered and rng.randf() < 0.5:
				v_stays += 1                     # stays down: the plinth takes the volley
			else:
				v_plan = [_react(), 0.3 if _wrong() else 0.9]
	if not v_plan.is_empty():
		v_plan[0] = float(v_plan[0]) - DT
		if float(v_plan[0]) <= 0.0:
			v_t = float(v_plan[1])
			var d: Vector3 = mg.aim_to - mg.aim_from
			d.y = 0.0
			v_dir = Vector3(-d.z, 0.0, d.x).normalized()
			if rng.randf() < 0.5:
				v_dir = -v_dir
			if not _floor_has(tw.player.global_position + v_dir * 3.5) and _floor_has(tw.player.global_position - v_dir * 3.5):
				v_dir = -v_dir
			v_plan.clear()
			v_dodges += 1
			if f.cover_ctl and f.cover_ctl.in_cover:
				f.cover_ctl.hold_override = false
				f.cover_ctl.leave()
	if v_t > 0.0:
		v_t -= DT
		tw.weapons.aim_override = false
		tw.player.yaw = atan2(-v_dir.x, -v_dir.z)
		tw.player.input_override = Vector2(0.0, -1.0)
		tw.player.sprint_override = true
		if v_t <= 0.0:
			_stop_walk()
			b_slot = -1
			_set_state("cover", _react())        # not in cover: it picks a slot and walks to it


func _floor_has(q: Vector3) -> bool:
	return _in_hall(q)


# ---------------------------------------------------------------------------
# Laser runner (T5b): the corridor's lanes (L_PATH, corridor-local x / z on the gallery floor). Before each leg it judges
# the crossing: a leg near a blink wall or a sweep is judged (else it just walks on): it waits and goes after its reaction
# once the leg looks clear. Read (65 %): the leg checked over its whole duration (the blinks' next "on", the sweeps' next spots) with a margin,
# for a start now and L_ANTICIPATE_S later; unread: only the beams as they are now (a warn looks dark, a sweep's way is not followed). Wrong (15 %): it judges the
# beams L_WRONG_S ahead of the real clock (goes early). 4 m/s, no footstep noise.
# ---------------------------------------------------------------------------
const L_SPEED: float = 4.0
const L_WRONG_S: float = 0.7
const L_MARGIN_R: float = 0.15
const L_MARGIN_S: float = 0.2
## A read leg is also judged for a start this much later (the bot knows it reacts late).
const L_ANTICIPATE_S: float = 0.4
const L_PATH: Array = [Vector2(2.0, 45.5), Vector2(2.0, 41.0), Vector2(-2.0, 41.0), Vector2(-2.0, 37.9), Vector2(-2.0, 36.1),
	Vector2(-2.0, 34.75), Vector2(-2.0, 33.0), Vector2(0.0, 29.6), Vector2(0.0, 27.4), Vector2(2.2, 26.0), Vector2(2.2, 20.9),
	Vector2(2.2, 18.75), Vector2(2.2, 17.2), Vector2(0.0, 16.1), Vector2(0.0, 13.6)]
var l_i: int = 0
var l_moving: bool = false
var l_judged: bool = false
var l_go_t: float = -1.0
var l_read: bool = true
var l_wrong: bool = false


func _laser_reset() -> void:
	l_i = 0
	l_moving = false
	l_judged = false
	l_go_t = -1.0


func _l_pt(i: int) -> Vector3:
	var q: Vector2 = L_PATH[i]
	var w: Vector3 = tw.level.world("gallery", Vector3(q.x, 0.0, q.y))
	return Vector3(w.x, tw.player.global_position.y, w.z)


## The leg a -> b started at mission time t0 clear of every lit beam (ahead: over the walk; else the beams frozen at t0).
func _l_clear(ml: MissionTowerLasers, a: Vector3, b: Vector3, t0: float, ahead: bool) -> bool:
	var dur: float = Vector2(b.x - a.x, b.z - a.z).length() / L_SPEED
	var n: int = maxi(1, ceili(dur / 0.04))
	for i: int in n + 1:
		var u: float = float(i) / float(n)
		var p: Vector3 = a.lerp(b, u)
		for d: Dictionary in ml.defs:
			if ahead:
				var tt: float = t0 + dur * u
				if MissionTowerLasers.beam_hits(d, tt, p, MissionTowerLasers.PLAYER_R + L_MARGIN_R) 						or MissionTowerLasers.beam_hits(d, tt + L_MARGIN_S, p, MissionTowerLasers.PLAYER_R + L_MARGIN_R):
					return false
			elif MissionTowerLasers.beam_hits(d, t0, p, MissionTowerLasers.PLAYER_R + L_MARGIN_R):
				return false
	return true


## A blink wall or a sweep within 1.2 m of the leg's z span (a crossing the bot has to judge).
func _l_timed(ml: MissionTowerLasers, a: Vector3, b: Vector3) -> bool:
	var z0: float = minf(a.z, b.z) - 1.2
	var z1: float = maxf(a.z, b.z) + 1.2
	for d: Dictionary in ml.defs:
		if String(d.get("mode", "static")) != "static":
			var z: float = (d["a"] as Vector3).z
			if z >= z0 and z <= z1:
				return true
	return false


func _lasers() -> void:
	var ml: MissionTowerLasers = m as MissionTowerLasers
	if ml == null or ml.replay_wait >= 0.0 or l_i >= L_PATH.size():
		return
	var tgt: Vector3 = _l_pt(l_i)
	if l_moving:
		if _step_to(tgt, L_SPEED):
			l_moving = false
			l_judged = false
			l_i += 1
		return
	if l_go_t >= 0.0:
		l_go_t -= DT
		if l_go_t < 0.0:
			l_moving = true
		return
	var from: Vector3 = tw.player.global_position
	if not l_judged:
		l_judged = true
		if not _l_timed(ml, from, tgt):
			l_moving = true                       # only static beams near this leg: walk on
			return
		l_read = _reads()
		l_wrong = _wrong()
		if verbose:
			print("      laser wait at wp %d (read %s wrong %s) t %.2f" % [l_i, str(l_read), str(l_wrong), ml.t])
	var tj: float = ml.t + (L_WRONG_S if l_wrong else 0.0)
	if _l_clear(ml, from, tgt, tj, l_read) and (not l_read or _l_clear(ml, from, tgt, tj + L_ANTICIPATE_S, true)):
		l_go_t = _react()
