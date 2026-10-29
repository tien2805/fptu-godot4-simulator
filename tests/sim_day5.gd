# File: res://tests/sim_day5.gd
# W3 Day 5 T8 (plan 2026-10-30-w3-day5.md): sloppy-bot tuning harness of the four basement missions, in the StoryBasement
# scene (no story running), on the missions' manual clocks, one advance per physics frame. Run with --fixed-fps 60 so a
# 90 s mission does not take 90 real seconds:
#   godot --headless --fixed-fps 60 --path . --script tests/sim_day5.gd -- <normal|easy> <seed> <runs> [stealth|gunfight|hack|duel]
# Each run plays a mission until it is won (THỬ LẠI after every fail, at most MAX_TRIES) and prints
#   SIM d5 <mission> <difficulty> seed <s>: fails F time T dmg D ko K
# then a summary line per mission (the par numbers for StoryRank and the table in the plan).
# The models (master plan Q6, shared plan "Sloppy gun bot", restated here; no helper shared across the parallel branches):
#   - gun bot: 250-400 ms reaction on every decision (+0.3 s when late); 15 % wrong or late (stays popped out 0.8 s too
#     long, reloads in the open, takes the nearest slot even when it does not protect); reads 65 % of the muzzle glints
#     (hides when it reads one); a shaky aim (hit chance 55 % at 15 m standing, clamped 25-85 %, x0.8 moving); real cover
#     through PlayerCover (hold_override) and real exposure through WeaponDirector.aim_override; the gunmen are the real AI;
#     shoots a labelled rack when two or more gunmen stand in its fall (read 65 %); no dive (bullet time is the shared
#     stream's: re-run at integration);
#   - sneaker: walks the east lane at 2.2 m/s, reads 65 % of the guards turning its way or walking up close (stops after
#     250-400 ms until he looks away), 15 % of those looks it moves anyway; waits before the cross aisle while its patrol
#     walks toward the lane (read 65 %) and never stops inside it; flashes the [F] torch in the dark now and then (15 % per
#     5 s, 1.5 s); once seen it fights like the gun bot;
#   - typist: 3.5-5 chars/s, 15 % of the words mistyped once (a typo resets the combo, the word is typed again), 250-400 ms
#     to notice a breach and to press [E] back at the desk;
#   - fighter: 250-400 ms reactions to the tells, reads 65 % of them, 15 % wrong guard or dodge; light combos in range;
#     QTE presses land 250-400 ms after each prompt, 15 % wrong key.
extends SceneTree

const DT: float = 1.0 / 60.0
var MAX_TRIES: int = int(OS.get_environment("SIM_MAX_TRIES")) if OS.get_environment("SIM_MAX_TRIES") != "" else 8
const TRY_CAP_S: float = 240.0           # an attempt still running after this long counts as a fail (a stuck bot)
const BASEMENT: String = "res://scenes/story/StoryBasement.tscn"
const LANE_X: float = 8.3
const SNEAK_SPEED: float = 2.2
const CROSS_Z0: float = 17.2
const CROSS_Z1: float = 21.8
const ROUTE: Array[Vector3] = [Vector3(LANE_X, 0.0, 31.0), Vector3(LANE_X, 0.0, 8.2), Vector3(3.0, 0.0, 6.2), Vector3(0.0, 0.0, 5.6)]

var TMP: String = "user://sim_day5_%d.cfg" % OS.get_process_id()
var rng := RandomNumberGenerator.new()
var bs: StoryBasement
var m: StoryMission
var done_flag: bool = false
var done_info: Dictionary = {}
var ko_count: int = 0
var fail_flag: bool = false
var finished: bool = false
var started: bool = false
var frames: int = 0
# per-attempt bot state
var w_i: int = 0
var s_wait: float = 0.0
var s_read: Dictionary = {}
var s_torch_t: float = 0.0
var s_torch_cd: float = 5.0
var t_word: String = ""
var t_pos: int = 0
var t_budget: float = 0.0
var t_rate: float = 4.0
var t_typo_at: int = -1
var t_notice: float = -1.0
var t_phase: String = ""
var f_last_t: float = -1.0
var f_plan: Array = []
var f_atk_t: float = 0.0
var q_t: float = -1.0
var q_idx: int = -1


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	Difficulty.set_easy(a.size() > 0 and a[0] == "easy")
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	StoryBasement.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 3}, "capture_mouse": false, "go_roam": false}


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		bs = (load(BASEMENT) as PackedScene).instantiate()
		root.add_child(bs)
	if frames == 10 and not started:
		started = true
		_run_all()
	return finished


func _run_all() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var seed0: int = int(a[1]) if a.size() > 1 else 3
	var runs: int = int(a[2]) if a.size() > 2 else 4
	var list: Array = [a[3]] if a.size() > 3 else ["stealth", "gunfight", "hack", "duel"]
	Difficulty.set_easy(a.size() > 0 and a[0] == "easy")   # again: GameFX applies the settings file after _initialize
	var tag: String = Difficulty.id()
	for mission: Variant in list:
		var fl: Array[int] = []
		var tt: float = 0.0
		var dd: float = 0.0
		for r: int in runs:
			var res: Dictionary = await _run(String(mission), seed0 + r)
			fl.append(int(res["fails"]))
			tt += float(res["time"])
			dd += float(res["dmg"])
			print("SIM d5 %s %s seed %d: fails %d time %.1f dmg %.0f ko %d |%s" % [mission, tag, seed0 + r, res["fails"], res["time"], res["dmg"], res["ko"], res.get("info", "")])
		var tot: int = 0
		for f: int in fl:
			tot += f
		print("SIM d5 %s %s SUMMARY: fails %s mean %.2f max %d | mean time %.1f s | mean dmg %.0f" % [mission, tag, str(fl), float(tot) / float(fl.size()), fl.max(), tt / runs, dd / runs])
	StoryBasement.test_opts = {}
	Difficulty.set_easy(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	finished = true
	quit(0)


## One run: tries until done (fails counted), the totals.
func _run(mission: String, sd: int) -> Dictionary:
	rng.seed = sd * 7919 + (1 if Difficulty.easy else 0)
	var opts: Dictionary = (StoryBasement.test_opts["missions"] as Dictionary)
	opts["seed"] = sd
	bs._opts["missions"] = opts
	_overrides()
	if not bs.start_mission(StoryMissions.beat("d5_" + mission)):
		return {"fails": -1, "time": 0.0, "dmg": 0.0, "ko": 0}
	m = bs.mission_node
	for c: Dictionary in m.done.get_connections():
		m.done.disconnect(c["callable"])
	for c2: Dictionary in m.failed.get_connections():
		m.failed.disconnect(c2["callable"])
	done_flag = false
	done_info = {}
	ko_count = 0
	e_shots = 0
	e_hits = 0
	var last_fight: GunFight = null
	m.done.connect(func(i: Dictionary) -> void:
		done_flag = true
		done_info = i)
	m.failed.connect(func(_t: String, _r: String) -> void: fail_flag = true)
	var fails: int = 0
	var time: float = 0.0
	var dmg: float = 0.0
	var ko: int = 0
	var hp0: float = bs.combat.hp
	var try_t: float = 0.0
	var trace: bool = OS.get_cmdline_user_args().has("--trace")
	var tf: int = 0
	_reset_bot()
	while not done_flag and fails < MAX_TRIES:
		await physics_frame
		if m == null or not is_instance_valid(m):
			break
		if m.replay != null:
			m.replay.step(DT)
			continue
		var lf: GunFight = (m as MissionLairFight).fight if m is MissionLairFight else null
		if lf != last_fight and lf != null:
			lf.enemy_ko.connect(func(_e: Node3D) -> void: ko_count += 1)
		last_fight = lf
		if m.state == "running":
			m.advance(DT)
			time += DT
			try_t += DT
			if m.state == "running":
				_bot(mission)
				tf += 1
				if trace and tf % int(OS.get_environment("TRACE_EVERY") if OS.get_environment("TRACE_EVERY") != "" else "120") == 0:
					print("      t %.0f %s" % [try_t, _diag(mission)])
			if try_t >= TRY_CAP_S and m.state == "running":
				m.fail("sim: stuck")
		if bs.combat.hp < hp0:
			dmg += hp0 - bs.combat.hp
		hp0 = bs.combat.hp
		if fail_flag:
			fail_flag = false
			fails += 1
			if OS.get_cmdline_user_args().has("--verbose"):
				print("    %s seed %d try %d failed at %.1f s: %s" % [mission, sd, fails, try_t, _diag(mission)])
			try_t = 0.0
			m.retry()
			hp0 = bs.combat.hp
			_reset_bot()
	ko = ko_count
	bs._free_mission()
	for k: int in 3:
		await physics_frame
	var info: String = ""
	for k2: Variant in done_info.keys():
		info += " %s=%s" % [str(k2), str(done_info[k2])]
	if e_shots > 0:
		info += " enemy_shots=%d hits=%d" % [e_shots, e_hits]
	if OS.get_cmdline_user_args().has("--states"):
		var keys: Array = st_hist.keys()
		for k3: Variant in keys:
			info += " %s=%.0f" % [str(k3), float(st_hist[k3])]
		st_hist.clear()
	return {"fails": fails, "time": time, "dmg": dmg, "ko": ko, "info": info}


func _diag(mission: String) -> String:
	match mission:
		"stealth":
			var ms: MissionBasementStealth = m as MissionBasementStealth
			var gs: String = ""
			for e6: Variant in ms.fight.alive():
				if e6 is Gunman:
					gs += " %s%s f%.1f" % [_lp((e6 as Gunman).global_position), "!" if (e6 as Gunman).is_alerted else "", (e6 as Gunman).forward().x]
			return "wp %d spotted %s blackout %s pos %s |%s" % [w_i, str(ms.spotted), str(ms.blackout), _lp(bs.player.global_position), gs]
		"hack":
			var mh: MissionHack = m as MissionHack
			var hs: String = "phase %s left %.0f kills %d leaks %d hp %.0f gas %d" % [mh.phase, mh.time_left, mh.hack.kills, mh.hack.leaks, mh.hack.hp, mh.gas_fired]
			if mh.phase == "breach" and mh.fight:
				hs += " | " + _fight_diag(mh.fight)
			return hs
		"duel":
			var md: MissionDuel = m as MissionDuel
			if md.duel == null or md.duel.boss == null:
				return "no duel"
			var kb: KatanaBoss = md.duel.boss
			return "boss hp %.0f st %s stagger %.0f phase %d attacks %d qte %d | hp %.0f" % [kb.hp, kb.state_name(), kb.stagger, md.duel.phase,
				kb.attacks, md.duel.qte_attempts, bs.combat.hp]
	return _fight_diag((m as MissionLairFight).fight)


func _fight_diag(f: GunFight) -> String:
	if f == null:
		return ""
	var tg: Gunman = _target(f) if f.state == "running" else null
	var s: String = "wave %d left %d ko %d hp %.0f bot %s slot %d cover %s mag %d nolos %.1f tgt %s at %s until %.1f bt %.1f pend %s |" % [f.wave, f.enemies_left(), f.ko_total,
		bs.combat.hp, b_state, b_slot, str(f.cover_ctl.in_cover), _ammo(), b_nolos, _lp(tg.global_position) if tg else "-", _lp(bs.player.global_position), b_until, bt, str(b_pending)]
	for e: Variant in f.alive():
		var g: Gunman = e as Gunman
		if g:
			s += " %s@%s" % [Gunman.ST_NAMES[g.st], _lp(g.global_position)]
	return s


func _lp(p: Vector3) -> String:
	var l: Vector3 = bs.level.to_local(p)
	return "(%.1f,%.1f)" % [l.x, l.z]


## Tuning trials (env SIM_PACE / SIM_LOAD): the hack's StoryHack pace and integrity load over the mission's constants.
func _overrides() -> void:
	if OS.get_environment("SIM_GUARD_ACC") != "":
		MissionBasementGunfight.GUARD_OPTS["accuracy"] = float(OS.get_environment("SIM_GUARD_ACC"))
	if OS.get_environment("SIM_GUARD_HP") != "":
		MissionBasementGunfight.GUARD_OPTS["hp"] = float(OS.get_environment("SIM_GUARD_HP"))
	if m != null and is_instance_valid(m) and m is MissionHack and (m as MissionHack).hack:
		var h: StoryHack = (m as MissionHack).hack
		if OS.get_environment("SIM_PACE") != "":
			h.pace = float(OS.get_environment("SIM_PACE"))
		if OS.get_environment("SIM_LOAD") != "":
			h.hp_max = StoryHack.MAX_HP * float(OS.get_environment("SIM_LOAD"))
			h.hp = h.hp_max


func _reset_bot() -> void:
	_overrides()
	_gun_reset()
	w_i = 0
	s_wait = 0.0
	s_read.clear()
	s_torch_t = 0.0
	s_torch_cd = 5.0
	t_word = ""
	t_pos = 0
	t_budget = 0.0
	t_rate = rng.randf_range(3.5, 5.0)
	t_notice = -1.0
	t_phase = ""
	f_last_t = -1.0
	f_plan.clear()
	q_t = -1.0
	q_idx = -1
	if bs.weapons:
		bs.weapons.aim_override = null
		bs.weapons.fire_override = null


func _react() -> float:
	return rng.randf_range(0.25, 0.4) + (0.3 if rng.randf() < 0.15 else 0.0)


func _wrong() -> bool:
	return rng.randf() < 0.15


func _reads() -> bool:
	return rng.randf() < 0.65


func _bot(mission: String) -> void:
	match mission:
		"stealth":
			_sneak()
		"gunfight":
			_gun((m as MissionLairFight).fight)
		"hack":
			_hack()
		_:
			_duel()


func _step_to(at: Vector3, speed: float) -> bool:
	var p: Vector3 = bs.player.global_position
	var d := Vector3(at.x - p.x, 0.0, at.z - p.z)
	if d.length() < 0.2:
		return true
	bs.player.teleport(p + d.normalized() * minf(speed * DT, d.length()), StoryMission.yaw_of(d))
	return false


# ---------------------------------------------------------------------------
# Gun bot: the shared sloppy gun bot (w3-shared tests/sim_gunfight.gd, the model as it is there) on the basement map.
# Basement adaptations: it walks with the player's real controls (input_override: collisions, no teleport) along a
# waypoint graph of the hall's aisles (NODES; edges re-checked with GunFight.clear_walk when a rack row falls), it only
# takes a slot it has walked to (never snaps across the hall), "hunt" (no gunman in sight for NO_LOS_S while popped: it
# walks toward the nearest one until one is in sight, then takes the best cover there), and the rack domino (a label with
# two or more gunmen in its fall, read 65 %).
# ---------------------------------------------------------------------------
const NO_LOS_S: float = 3.0
const MOVE_S: float = 7.0
const HUNT_S: float = 10.0
const NODES: Array[Vector2] = LairBasement.NAV_PTS    # the gunmen's waypoints, walked the same way by the bot

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
	bt = 0.0
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
		_set_state("cover", _react())
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
		bs.weapons.aim_override = false
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
			bs.weapons.aim_override = false
			f.cover_ctl.hold_override = true
			if not _has("move") and ((b_slot >= 0 and not f.cover.protects(b_slot, _threat(f))) or not f.cover_ctl.in_cover):
				_later("move")
			if bt >= b_until and not _has("pop"):
				_later("pop", 0.3 if _wrong() else 0.0)
				b_until = INF
		"pop":
			_stop_walk()
			bs.weapons.aim_override = true
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
		"move":
			bs.weapons.aim_override = false
			f.cover_ctl.hold_override = false
			if b_slot < 0:
				_set_state("pop", rng.randf_range(1.2, 2.0))
				return
			var goal: Vector3 = f.cover.pos[b_slot]
			var arrived: bool = _walk(f, goal)
			if arrived or bt >= b_until:
				_stop_walk()
				if StoryMission.flat(goal, bs.player.global_position) <= GunData.COVER_ENTER_R and not (f.taken.has(b_slot) and f.taken[b_slot] != bs.player):
					f.cover_ctl.hold_override = true
					f.cover_ctl.enter(b_slot)
					_set_state("cover", rng.randf_range(0.6, 1.2))
				else:
					b_slot = -1
					_set_state("pop", rng.randf_range(1.2, 2.0))
		"ammo":
			bs.weapons.aim_override = false
			f.cover_ctl.hold_override = false
			var box: AmmoPickup = null
			var bd2: float = INF
			for pk: AmmoPickup in f.pickups:
				var d4: float = StoryMission.flat(pk.global_position, bs.player.global_position)
				if not pk.taken and d4 < bd2:
					bd2 = d4
					box = pk
			if box == null or bt >= b_until or _any_ammo():
				_stop_walk()
				_set_state("cover", _react())
				return
			_walk(f, box.global_position)
		"hunt":
			bs.weapons.aim_override = false
			f.cover_ctl.hold_override = false
			var tg: Gunman = _target(f)
			if tg != null and StoryMission.flat(tg.global_position, bs.player.global_position) < 20.0 or bt >= b_until:
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
				var d: float = StoryMission.flat((e as Node3D).global_position, bs.player.global_position)
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


func _threat(f: GunFight) -> Vector3:
	var acc := Vector3.ZERO
	var n: int = 0
	for e: Variant in f.alive():
		acc += (e as Node3D).global_position
		n += 1
	return acc / float(n) if n > 0 else bs.player.global_position


## The nearest gunman with a clear line to his chest (crouched: lowered by his drop); a pallet facing the bot pushes him back.
func _target(f: GunFight) -> Gunman:
	var best: Gunman = null
	var bd: float = INF
	var eye: Vector3 = bs.player.global_position + Vector3(0.0, 1.35, 0.0)
	for e: Variant in f.alive():
		if not (e is Gunman):
			continue
		var gm: Gunman = e
		var d: float = eye.distance_to(gm.feet())
		if gm.has_method("has_shield") and bool(gm.call("has_shield")) and bool(gm.call("front_hit", bs.player.global_position)):
			d += 6.0
		if d < bd and f.clear_line(eye, gm.feet() + Vector3(0.0, 1.2 - gm.drop, 0.0)):
			bd = d
			best = gm
	return best


## The best free slot within max_d that protects against the threat (wrong: one that does not) and, in the basement's
## aisles, from which a gunman can be seen when it pops out (else the nearest protecting one).
func _pick_slot(f: GunFight, wrong: bool, max_d: float) -> int:
	var th: Vector3 = _threat(f)
	var p: Vector3 = bs.player.global_position
	var best: int = -1
	var bd: float = INF
	var any: int = -1
	var ad: float = INF
	for i: int in f.cover.count():
		if f.taken.has(i) and f.taken[i] != bs.player:
			continue
		if f.cover.protects(i, th) == wrong:
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


## A gunman's standing chest is in sight from the slot's standing eye.
func _slot_sees(f: GunFight, i: int) -> bool:
	var eye: Vector3 = f.cover.pos[i] + Vector3(0.0, 1.5, 0.0)
	for e: Variant in f.alive():
		if e is Gunman and f.clear_line(eye, (e as Gunman).feet() + Vector3(0.0, 1.2, 0.0)):
			return true
	return false


## One round per pistol cycle while popped: a label (the domino), else the target. True when it had something in sight.
func _shoot(f: GunFight) -> bool:
	if b_reload_until > 0.0:
		return true
	if _ammo() <= 0:
		var w: WeaponDirector = bs.weapons
		if w.reserve_of(w.current) != 0:
			if b_state == "pop" and not _wrong():
				_set_state("cover", 1.7)          # ducks to reload (15 %: reloads in the open)
			b_reload_until = bt + float(WeaponData.SLOTS[w.current]["reload"])
		else:
			_swap_or_scavenge(f)
		return true
	if b_shot_cd > 0.0:
		return true
	var eye: Vector3 = bs.player.global_position + Vector3(0.0, 1.35, 0.0)
	var lv: LairBasement = bs.level
	var foes: Array = f.alive()
	for i: int in lv.racks.size():
		var rd: Dictionary = lv.racks[i]
		if float(rd["t"]) >= 0.0:
			continue
		var fp: Rect2 = lv.row_footprint(i, 1.0)
		var n: int = 0
		for e: Variant in foes:
			var lp: Vector3 = lv.to_local((e as Node3D).global_position)
			if fp.has_point(Vector2(lp.x, lp.z)):
				n += 1
		var lt: Node3D = rd["target"]
		if n >= 2 and f.clear_line(eye, lt.global_position + Vector3(0.0, 0.9, 0.0)) and _reads():
			_fire()
			if rng.randf() < _hit_p(eye.distance_to(lt.global_position)):
				bs.weapons.hit_target(lt, {"kind": "bullet", "from": bs.player.global_position})
			return true
	var g: Gunman = _target(f)
	if g == null:
		return false
	_fire()
	var d: float = bs.player.global_position.distance_to(g.feet())
	var shotgun: bool = bs.weapons.current == WeaponData.Slot.SHOTGUN
	var p: float = clampf(1.25 - d / 14.0, 0.05, 0.95) if shotgun else _hit_p(d)
	if bs.player.horizontal_speed > 1.0:
		p *= 0.6
	if rng.randf() < p:
		bs.weapons.hit_target(g, {"kind": "pellet" if shotgun else "bullet", "from": bs.player.global_position})
	return true


## One round of the real weapon (WeaponDirector's magazine; the HUD and the checkpoint see it).
func _fire() -> void:
	var w: WeaponDirector = bs.weapons
	b_shot_cd = float(WeaponData.SLOTS[w.current]["cycle"])
	if w.current < w.ammo.size() and w.ammo[w.current] > 0:
		w.ammo[w.current] -= 1


func _any_ammo() -> bool:
	var w: WeaponDirector = bs.weapons
	for sl: int in [WeaponData.Slot.PISTOL, WeaponData.Slot.SHOTGUN]:
		if sl < w.ammo.size() and (w.ammo[sl] > 0 or w.reserve_of(sl) != 0):
			return true
	return false


func _ammo() -> int:
	var w: WeaponDirector = bs.weapons
	return w.ammo[w.current] if w.current < w.ammo.size() else 0


## The magazine refilled from the spare rounds (the real numbers; -1 = unlimited).
func _reload_now() -> void:
	var w: WeaponDirector = bs.weapons
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
	var w: WeaponDirector = bs.weapons
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
	if bs and bs.player:
		bs.player.input_override = null
		bs.player.sprint_override = false
	r_path.clear()
	r_stuck_t = 0.0


## One frame of walking toward `to` (sprint, the real controller); true once within 0.7 m.
func _walk(f: GunFight, to: Vector3) -> bool:
	var p: Vector3 = bs.player.global_position
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
	bs.player.yaw = atan2(-d.x, -d.z)
	bs.player.input_override = Vector2(0.0, -1.0)
	bs.player.sprint_override = true
	r_stuck_t += DT
	if r_stuck_t >= 1.0:
		if StoryMission.flat(p, r_last_p) < 0.4:
			r_replan = 0.0
			bs.player.yaw += rng.randf_range(-1.2, 1.2)
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
func _graph(f: GunFight) -> void:
	var key: int = 0
	for r: Variant in bs.level.fallen_rows():
		key |= 1 << int(r)
	if key == gr_key and not gr_nodes.is_empty():
		return
	gr_key = key
	gr_nodes.clear()
	for q: Vector2 in NODES:
		gr_nodes.append(bs.level.world(Vector3(q.x, 0.0, q.y)))
	gr_edges.clear()
	for i: int in gr_nodes.size():
		gr_edges.append([])
	for i: int in gr_nodes.size():
		for j: int in range(i + 1, gr_nodes.size()):
			if StoryMission.flat(gr_nodes[i], gr_nodes[j]) < 12.5 and f.clear_walk(gr_nodes[i], gr_nodes[j]):
				(gr_edges[i] as Array).append(j)
				(gr_edges[j] as Array).append(i)


# ---------------------------------------------------------------------------
# Sneaker
# ---------------------------------------------------------------------------
func _sneak() -> void:
	var ms: MissionBasementStealth = m as MissionBasementStealth
	if ms.spotted and not ms.fight.alive().is_empty():
		_gun(ms.fight)
		return
	if ms.fight.cover_ctl:
		ms.fight.cover_ctl.hold_override = false
	bs.weapons.aim_override = false
	_stop_walk()
	if ms.blackout:
		s_torch_cd -= DT
		if s_torch_cd <= 0.0:
			s_torch_cd = 5.0
			if _wrong():
				s_torch_t = 1.5
				ms.flashlight.set_on(true)
		if s_torch_t > 0.0:
			s_torch_t -= DT
			if s_torch_t <= 0.0:
				ms.flashlight.set_on(false)
	var p: Vector3 = bs.player.global_position
	var danger: bool = false
	for e: Variant in ms.fight.alive():
		var g: Gunman = e as Gunman
		if g == null or g.is_alerted:
			continue
		var to: Vector3 = p - g.feet()
		to.y = 0.0
		var d: float = to.length()
		var ang: float = rad_to_deg(g.forward().angle_to(to / maxf(d, 0.01))) if d > 0.5 else 0.0
		var facing: bool = (d < g.patrol_sight_m + 3.0 and ang < g.patrol_fov_deg * 0.5 + 15.0) or (d < 5.0 and ang < 110.0)
		if facing:
			if not s_read.has(g):
				s_read[g] = [_reads(), _react(), _wrong()]   # read it?, the reaction, moves anyway (once per look)
			var rd: Array = s_read[g]
			rd[1] = float(rd[1]) - DT
			if bool(rd[0]) and float(rd[1]) <= 0.0 and not bool(rd[2]):
				danger = true
		else:
			s_read.erase(g)
	# the cross aisle is a patrol line: never freeze inside it (cross it briskly); before it, wait behind the rack end while a
	# guard walks the aisle toward the lane (read 65 %, else it goes anyway)
	var lz: float = bs.level.to_local(p).z
	var in_band: bool = lz > CROSS_Z0 and lz < CROSS_Z1
	if not in_band and lz >= CROSS_Z1 and lz < CROSS_Z1 + 3.4:
		for e7: Variant in ms.fight.alive():
			var g7: Gunman = e7 as Gunman
			if g7 == null or g7.is_alerted:
				continue
			var gl: Vector3 = bs.level.to_local(g7.global_position)
			var toward: bool = (LANE_X - gl.x) * g7.forward().x > 0.0
			if absf(gl.z - 18.5) < 1.6 and (absf(gl.x - LANE_X) < 5.0 or (toward and absf(gl.x - LANE_X) < 12.0)):
				if not s_read.has("cross"):
					s_read["cross"] = [_reads(), _react()]
				var cr: Array = s_read["cross"]
				cr[1] = float(cr[1]) - DT
				if bool(cr[0]) and float(cr[1]) <= 0.0:
					danger = true
				break
		if not danger:
			s_read.erase("cross")
	if danger and not in_band:
		return
	if w_i < ROUTE.size() and _step_to(bs.level.world(ROUTE[w_i]), SNEAK_SPEED * (1.4 if in_band else 1.0)):
		w_i += 1


# ---------------------------------------------------------------------------
# Typist
# ---------------------------------------------------------------------------
func _hack() -> void:
	var mh: MissionHack = m as MissionHack
	if mh.phase != t_phase:
		t_phase = mh.phase
		t_notice = _react()                       # 250-400 ms to notice the breach / the cleared room
	match mh.phase:
		"breach":
			t_notice -= DT
			if t_notice <= 0.0:
				_gun(mh.fight)
			return
		"return":
			if mh.fight and mh.fight.cover_ctl:
				mh.fight.cover_ctl.hold_override = false
			bs.weapons.aim_override = false
			_stop_walk()
			t_notice -= DT
			if t_notice <= 0.0 and _step_to(mh.pts["spot"], 4.5):
				t_word = ""
				mh.return_to_desk()                  # [E] at the desk (reaction spent on the way back)
			return
	var h: StoryHack = mh.hack
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
		if r == "typo":
			t_word = ""
		elif r == "kill" or r == "won":
			t_word = ""


func _next_word(h: StoryHack) -> void:
	t_word = ""
	t_pos = 0
	h.typed = ""
	h.locked = {}
	if not h.final_bullet.is_empty():
		t_word = StoryHack.FINAL_COMMAND
	else:
		var best: Dictionary = {}
		for b: Dictionary in h.bullets:
			if not bool(b["dead"]) and (best.is_empty() or float(b["y"]) > float(best["y"])):
				best = b
		if not best.is_empty():
			t_word = String(best["word"])
	t_typo_at = rng.randi_range(1, maxi(1, t_word.length() - 1)) if t_word != "" and _wrong() else -1


# ---------------------------------------------------------------------------
# Fighter
# ---------------------------------------------------------------------------
func _duel() -> void:
	var md: MissionDuel = m as MissionDuel
	if md.card != null:
		md.card.step(DT)
		return
	var duel: SwordDuel = md.duel
	if duel == null or duel.boss == null:
		return
	var c: PlayerCombat = bs.combat
	if duel.in_qte:
		if q_idx != duel.qte.index:
			q_idx = duel.qte.index
			q_t = _react() - 0.0
		q_t -= DT
		if q_t <= 0.0 and q_idx >= 0:
			var key: String = duel.qte.wanted()
			if _wrong():
				key = "q" if key != "q" else "e"
			duel.qte.press(key)
			q_idx = -2
		return
	q_idx = -1
	var boss: KatanaBoss = duel.boss
	# the tells: each new one is read or not, answered after the reaction, sometimes wrongly
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
	var d: float = StoryMission.flat(boss.global_position, bs.player.global_position)
	if d > 1.9:
		_step_to(boss.global_position, 3.5)
	f_atk_t -= DT
	if f_atk_t <= 0.0 and d <= 2.4 and boss.incoming() == 0:
		f_atk_t = rng.randf_range(0.35, 0.6)
		c.light_override = true
