# File: res://tests/sim_story_brawls.gd
# w5-complete T5 (plan 2026-11-03-w5-complete.md): sloppy-bot harness of the story beats whose StoryRank thresholds were
# still provisional: the Phase B / C brawls (MissionFight d1 couriers, d4 clones + Dolly, d2 Sói Xám) and the two
# discovery walks (MissionCorridor d1_corridor, MissionBridge d2_bridge), in a real FreeRoam (crowd off) at the beats'
# StoryRoam anchors, on the missions' manual clocks, one advance per physics frame. Run with --fixed-fps 60:
#   godot --headless --fixed-fps 60 --path . --script tests/sim_story_brawls.gd -- <normal|easy> <seed> <runs> [beat id | brawls]
# Each run plays the beat until it is won (THỬ LẠI after every fail, at most MAX_TRIES) and prints
#   SIM <beat> <difficulty> seed <s>: fails F time T dmg D ko K rank L score
# then a summary per beat (the numbers the pars come from).
# The models (master plan Q6; restated here, no helper shared with the other harnesses):
#   - fighter: every new enemy attack (a wind-up or a red telegraph) is read 65 % of the time and answered 250-400 ms
#     late (+0.3 s 15 % of the time); 15 % of the answers are wrong (a block against the red heavy, a dodge or nothing
#     against a light); a block is held 0.45 s; otherwise it walks to the nearest hostile at 4 m/s and throws light
#     combos every 0.35-0.6 s in range, a heavy kick at an enemy in guard (15 % of its presses come late or not at all),
#     the finisher [E] on a dazed one after its reaction; d4's food throwers: the red "!" read 65 % of the time, a guard
#     250-400 ms late held until the bun lands (15 % nothing); it never picks up the improvised weapons or flips tables
#     (the sloppy player does not read the props);
#   - walker: walks the path at 85-100 % of the allowed pace, stops 1-2.5 s now and then (15 % per 3 s), looks back
#     once in a while (a 180 degree turn for 0.6 s), waits while the controls are off (the corridor blackout).
extends SceneTree

const DT: float = 1.0 / 60.0
var MAX_TRIES: int = int(OS.get_environment("SIM_MAX_TRIES")) if OS.get_environment("SIM_MAX_TRIES") != "" else 8
const TRY_CAP_S: float = 240.0
const BEATS: Array[String] = ["d1_brawl", "d4_brawl", "d2_duel", "d1_corridor", "d2_bridge"]
const MOVE_SPEED: float = 4.0

var TMP: String = "user://sim_story_brawls_%d.cfg" % OS.get_process_id()
var rng := RandomNumberGenerator.new()
var fr: Node3D
var m: StoryMission
var started: bool = false
var finished: bool = false
var frames: int = 0
var done_flag: bool = false
var fail_flag: bool = false
var done_info: Dictionary = {}
# fighter state
var f_seen: Dictionary = {}          # enemy instance id -> the state it was in last frame
var f_plan: Array = []               # [delay, action, held]
var f_atk_t: float = 0.0
var f_fin_t: float = -1.0
# walker state
var w_pause: float = 0.0
var w_look: float = 0.0
var w_roll_t: float = 0.0


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	Difficulty.set_easy(a.size() > 0 and a[0] == "easy")
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	root.add_child(fr)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 12 and not started:
		started = true
		_run_all()
	return finished


func _run_all() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	Difficulty.set_easy(a.size() > 0 and a[0] == "easy")   # again: GameFX applies the settings file after _initialize
	var seed0: int = int(a[1]) if a.size() > 1 else 3
	var runs: int = int(a[2]) if a.size() > 2 else 4
	var list: Array = BEATS
	if a.size() > 3 and a[3] in BEATS:
		list = [a[3]]
	elif a.size() > 3 and a[3] == "brawls":
		list = BEATS.slice(0, 3)
	var tag: String = Difficulty.id()
	for id: Variant in list:
		var fl: Array[int] = []
		var tt: float = 0.0
		var dd: float = 0.0
		var clean_t: Array[float] = []
		var letters: Array[String] = []
		for r: int in runs:
			var res: Dictionary = await _run(String(id), seed0 + r)
			fl.append(int(res["fails"]))
			tt += float(res["time"])
			dd += float(res["dmg"])
			letters.append(String(res["rank"]))
			if int(res["fails"]) == 0:
				clean_t.append(float(res["time"]))
			print("SIM %s %s seed %d: fails %d time %.1f dmg %.0f ko %d rank %s %.0f" % [id, tag, seed0 + r, res["fails"], res["time"],
				res["dmg"], res["ko"], res["rank"], res["score"]])
		var tot: int = 0
		for f: int in fl:
			tot += f
		print("SIM %s %s SUMMARY: fails %s mean %.2f max %d | mean time %.1f s | clean times %s | mean dmg %.0f | ranks %s" % [id, tag,
			str(fl), float(tot) / float(fl.size()), fl.max(), tt / runs, str(clean_t), dd / runs, " ".join(PackedStringArray(letters))])
	Difficulty.set_easy(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	finished = true
	quit(0)


## The StoryRoam anchors the beats use (the same map points as StoryRoam._build_anchors).
func _anchors() -> Dictionary:
	var cx: Transform3D = fr.get("campus_xf")
	var out: Dictionary = {}
	var pts: Dictionary = {"west_gate": [cx * Vector3(176.0, 0.0, 7.0), cx * Vector3(176.0, 0.0, 14.0)],
		"bridge_road": [Vector3(2133.0, 0.0, 184.0), Vector3(2145.0, 0.0, 150.0)],
		"bridge_bank": [Vector3(2145.0, 0.0, 150.0), Vector3(2133.0, 0.0, 184.0)]}
	for k: String in pts.keys():
		var p: Vector3 = pts[k][0]
		var d: Vector3 = (pts[k][1] as Vector3) - p
		out[k] = {"pos": p, "yaw": atan2(-d.x, -d.z)}
	return out


func _run(id: String, sd: int) -> Dictionary:
	rng.seed = sd * 7919 + (1 if Difficulty.easy else 0)
	var b: Dictionary = StoryMissions.beat(id)
	var anchors: Dictionary = _anchors()
	var o: Dictionary = {"manual": true, "manual_replay": true, "seed": sd, "anchors": anchors}
	var script: GDScript
	match String(b.get("kind", "")):
		"fight":
			script = MissionFight
			if String(b["fight"]) == "d4":
				var st: Variant = fr.call("cine_stage", CineTimeline.canteen_stage(Vector2(14.0, 10.0), "sunset"))
				o["centre"] = (st as Transform3D).origin if st is Transform3D else Vector3(-31.17, 0.0, -4.51)
				o["face"] = 0.0
			else:
				var an: Dictionary = anchors[String(b["anchor"])]
				o["centre"] = an["pos"]
				o["face"] = an["yaw"]
		_:
			script = MissionCorridor if String(b["mission"]) == "corridor" else MissionBridge
			if script == MissionBridge:
				var ra: Dictionary = anchors["bridge_road"]
				(fr.get("player") as ThirdPersonController).teleport(ra["pos"], float(ra["yaw"]))
	m = script.new()
	fr.add_child(m)
	m.setup(fr, b, o)
	for k: int in 3:
		await physics_frame
	done_flag = false
	fail_flag = false
	done_info = {}
	m.done.connect(func(i: Dictionary) -> void:
		done_flag = true
		done_info = i)
	m.failed.connect(func(_t: String, _r: String) -> void: fail_flag = true)
	m.begin()
	_reset_bot()
	var fails: int = 0
	var try_t: float = 0.0
	while not done_flag and fails < MAX_TRIES:
		await physics_frame
		if m == null or not is_instance_valid(m):
			break
		if m.replay != null:
			m.replay.step(DT)
			continue
		if m.state == "running":
			m.advance(DT)
			try_t += DT
			if m.state == "running":
				_bot()
			if try_t >= TRY_CAP_S and m.state == "running":
				m.fail("sim: stuck")
		if fail_flag:
			fail_flag = false
			fails += 1
			if OS.get_cmdline_user_args().has("--verbose"):
				print("    %s seed %d try %d failed at %.1f s: %s" % [id, sd, fails, try_t, _diag()])
			try_t = 0.0
			m.retry()
			_reset_bot()
	var rk: Dictionary = m.rank_eval.duplicate() if is_instance_valid(m) else {}
	var st2: Dictionary = m.stats.duplicate() if is_instance_valid(m) else {}
	if is_instance_valid(m):
		m.abort()
	for k2: int in 3:
		await physics_frame
	return {"fails": fails, "time": float(st2.get("time", 0.0)), "dmg": float(st2.get("dmg", 0.0)), "ko": int(st2.get("ko", 0)),
		"rank": String(rk.get("letter", "")), "score": float(rk.get("score", 0.0))}


func _diag() -> String:
	if m is MissionFight and (m as MissionFight).fight:
		var f: MeleeFight = (m as MissionFight).fight
		var c: PlayerCombat = fr.get("combat")
		var res: Dictionary = {}
		for l: Variant in c.strikes:
			var k: String = str((l as Dictionary).get("kind", "?")) + ":" + str((l as Dictionary).get("result", "?"))
			res[k] = int(res.get(k, 0)) + 1
		var hp: String = ""
		for e: Variant in f.alive():
			hp += " %s %.0f %s" % [(e as MeleeEnemy).label, float((e as MeleeEnemy).hp), (e as MeleeEnemy).state_name()]
		var mf: MissionFight = m as MissionFight
		var food: int = mf.arena.food_hits if mf.arena else 0
		var pl: Node3D = fr.get("player")
		var off: float = pl.global_position.distance_to(mf.centre) if pl else -1.0
		return "wave %d alive %d ko %d food %d off %.1f m strikes %s |%s" % [f.wave, f.alive().size(), int(m.stats.get("ko", 0)), food, off, str(res), hp]
	return ""


func _reset_bot() -> void:
	f_seen.clear()
	f_plan.clear()
	f_atk_t = 0.0
	f_fin_t = -1.0
	w_pause = 0.0
	w_look = 0.0
	w_roll_t = 0.0
	var c: PlayerCombat = fr.get("combat")
	if c:
		c.block_override = false


func _react() -> float:
	return rng.randf_range(0.25, 0.4) + (0.3 if rng.randf() < 0.15 else 0.0)


func _wrong() -> bool:
	return rng.randf() < 0.15


func _reads() -> bool:
	return rng.randf() < 0.65


func _bot() -> void:
	if m is MissionFight:
		_fight(m as MissionFight)
	elif m is MissionCorridor:
		_walk_corridor(m as MissionCorridor)
	else:
		_walk_bridge(m as MissionBridge)


func _player() -> ThirdPersonController:
	return fr.get("player")


func _step_to(at: Vector3, speed: float) -> void:
	var p: Vector3 = _player().global_position
	var d := Vector3(at.x - p.x, 0.0, at.z - p.z)
	if d.length() < 0.05:
		return
	var q: Vector3 = p + d.normalized() * minf(speed * DT, d.length())
	q.y = m.ground_y(q)
	_player().teleport(q, StoryMission.yaw_of(d))


# ---------------------------------------------------------------------------
# Fighter
# ---------------------------------------------------------------------------
func _fight(mf: MissionFight) -> void:
	var f: MeleeFight = mf.fight
	var c: PlayerCombat = fr.get("combat")
	if f == null or c == null or f.state != "running":
		return
	# d4 food throwers: the red "!" tell read or not, answered late with a guard held until the bun lands (15 % nothing)
	if mf.arena:
		for i: int in mf.arena.throwers.size():
			var th: Dictionary = mf.arena.throwers[i]
			var tk: String = "th%d" % i
			var ts: String = String(th["state"])
			var tw: String = String(f_seen.get(tk, ""))
			f_seen[tk] = ts
			if ts != "tell" or tw == "tell" or not f_plan.is_empty() or not _reads():
				continue
			var r: float = _react()
			f_plan = [r, "none" if _wrong() else "block", 0.0, maxf(float(th["tell_t"]) - r, 0.0) + ArenaDressing.BUN_FLY_S + 0.15]
	# new attacks: a wind-up (light, block it) or a red telegraph (heavy, dodge it), read or not, answered late
	var alive: Array = f.alive()
	for e: Variant in alive:
		var me: MeleeEnemy = e
		var key: int = me.get_instance_id()
		var sn: String = me.state_name()
		var was: String = String(f_seen.get(key, ""))
		f_seen[key] = sn
		if sn == was or not (sn in ["windup", "telegraph"]) or not f_plan.is_empty():
			continue
		if not _reads():
			continue
		var red: bool = sn == "telegraph"
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
					if float(f_plan[2]) > (float(f_plan[3]) if f_plan.size() > 3 else 0.45):
						c.block_override = false
						f_plan.clear()
				"dodge":
					c.try_dodge()
					f_plan.clear()
				_:
					f_plan.clear()
			return
	c.block_override = false
	var target: MeleeEnemy = null
	var bd: float = INF
	for e2: Variant in alive:
		var me2: MeleeEnemy = e2
		if not me2.is_hostile():
			continue
		var d2: float = StoryMission.flat(me2.global_position, _player().global_position)
		if d2 < bd:
			bd = d2
			target = me2
	if target == null:
		return
	if c.state != PlayerCombat.St.IDLE:
		return
	if bd > 1.7:
		_step_to(target.global_position, MOVE_SPEED)
	else:
		var to: Vector3 = target.global_position - _player().global_position
		_player().teleport(_player().global_position, StoryMission.yaw_of(to))
	if target.is_dazed():
		if f_fin_t < 0.0:
			f_fin_t = _react()
		f_fin_t -= DT
		if f_fin_t <= 0.0 and bd <= 2.4:
			f_fin_t = -1.0
			if not _wrong():
				c.finisher_override = true
		return
	f_fin_t = -1.0
	f_atk_t -= DT
	if f_atk_t <= 0.0 and bd <= 2.4:
		f_atk_t = rng.randf_range(0.35, 0.6)
		if target.state_name() == "block" and not _wrong():
			c.heavy_override = true
		else:
			c.light_override = true


# ---------------------------------------------------------------------------
# Walker
# ---------------------------------------------------------------------------
## The sloppy pace: pauses, a look back now and then. true when it may walk this frame.
func _walker_tick() -> bool:
	if w_pause > 0.0:
		w_pause -= DT
		return false
	if w_look > 0.0:
		w_look -= DT
		_player().yaw += PI * DT / 0.6
		return false
	w_roll_t += DT
	if w_roll_t >= 3.0:
		w_roll_t = 0.0
		if _wrong():
			if rng.randf() < 0.3:
				w_look = 0.6
			else:
				w_pause = rng.randf_range(1.0, 2.5)
			return false
	return _player().controls_enabled


func _walk_corridor(mc: MissionCorridor) -> void:
	if not _walker_tick():
		return
	var goal: Vector3 = mc.xf * Vector3(0.0, 0.0, MissionCorridor.Z0 - MissionCorridor.LEN_M)
	_step_to(goal, MissionCorridor.WALK_CAP * rng.randf_range(0.85, 1.0))


func _walk_bridge(mb: MissionBridge) -> void:
	if mb.phase == "ringing" or mb.phase == "done":
		return
	if not _walker_tick():
		return
	_step_to(mb.bank, 4.5 * rng.randf_range(0.85, 1.0))
