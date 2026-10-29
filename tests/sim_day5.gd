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
#   - sneaker: walks the east lane, reads 65 % of the guards turning its way (stops after 250-400 ms until he looks away),
#     15 % moves anyway; flashes the [F] torch in the dark now and then (15 % per 5 s, 1.5 s);
#   - typist: 3.5-5 chars/s, 15 % of the words mistyped once (a typo resets the combo, the word is typed again), 250-400 ms
#     to notice a breach and to press [E] back at the desk;
#   - fighter: 250-400 ms reactions to the tells, reads 65 % of them, 15 % wrong guard or dodge; light combos in range;
#     QTE presses land 250-400 ms after each prompt, 15 % wrong key.
extends SceneTree

const DT: float = 1.0 / 60.0
const MAX_TRIES: int = 8
const TRY_CAP_S: float = 240.0           # an attempt still running after this long counts as a fail (a stuck bot)
const BASEMENT: String = "res://scenes/story/StoryBasement.tscn"
const LANE_X: float = 8.3
const ROUTE: Array[Vector3] = [Vector3(LANE_X, 0.0, 31.0), Vector3(LANE_X, 0.0, 8.2), Vector3(3.0, 0.0, 6.2), Vector3(0.0, 0.0, 5.6)]

var TMP: String = "user://sim_day5_%d.cfg" % OS.get_process_id()
var rng := RandomNumberGenerator.new()
var bs: StoryBasement
var m: StoryMission
var done_flag: bool = false
var fail_flag: bool = false
var finished: bool = false
var started: bool = false
var frames: int = 0
# per-attempt bot state
var g_state: String = "move"
var g_t: float = 0.0
var g_slot: int = -1
var g_react: float = 0.0
var g_shot_t: float = 0.0
var g_mag: int = 12
var g_read: Dictionary = {}
var g_nolos: float = 0.0
var g_reload: float = 0.0
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
			print("SIM d5 %s %s seed %d: fails %d time %.1f dmg %.0f ko %d" % [mission, tag, seed0 + r, res["fails"], res["time"], res["dmg"], res["ko"]])
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
	if not bs.start_mission(StoryMissions.beat("d5_" + mission)):
		return {"fails": -1, "time": 0.0, "dmg": 0.0, "ko": 0}
	m = bs.mission_node
	for c: Dictionary in m.done.get_connections():
		m.done.disconnect(c["callable"])
	for c2: Dictionary in m.failed.get_connections():
		m.failed.disconnect(c2["callable"])
	done_flag = false
	m.done.connect(func(_i: Dictionary) -> void: done_flag = true)
	m.failed.connect(func(_t: String, _r: String) -> void: fail_flag = true)
	var fails: int = 0
	var time: float = 0.0
	var dmg: float = 0.0
	var ko: int = 0
	var hp0: float = bs.combat.hp
	var try_t: float = 0.0
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
			try_t += DT
			if m.state == "running":
				_bot(mission)
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
			if m is MissionLairFight and (m as MissionLairFight).fight:
				ko += (m as MissionLairFight).fight.ko_total
			m.retry()
			hp0 = bs.combat.hp
			_reset_bot()
	if m is MissionLairFight and (m as MissionLairFight).fight:
		ko += (m as MissionLairFight).fight.ko_total
	bs._free_mission()
	for k: int in 3:
		await physics_frame
	return {"fails": fails, "time": time, "dmg": dmg, "ko": ko}


func _diag(mission: String) -> String:
	match mission:
		"stealth":
			var ms: MissionBasementStealth = m as MissionBasementStealth
			return "wp %d spotted %s blackout %s pos %s" % [w_i, str(ms.spotted), str(ms.blackout), str(bs.level.to_local(bs.player.global_position))]
		"hack":
			var mh: MissionHack = m as MissionHack
			return "phase %s left %.0f kills %d leaks %d hp %.0f gas %d" % [mh.phase, mh.time_left, mh.hack.kills, mh.hack.leaks, mh.hack.hp, mh.gas_fired]
		"duel":
			var md: MissionDuel = m as MissionDuel
			return "boss hp %.0f phase %d qte %d" % [md.duel.boss.hp if md.duel and md.duel.boss else -1.0, md.duel.phase if md.duel else 0, md.duel.qte_attempts if md.duel else 0]
	var f: GunFight = (m as MissionLairFight).fight
	return "wave %d left %d ko %d" % [f.wave, f.enemies_left(), f.ko_total] if f else ""


func _reset_bot() -> void:
	g_state = "move"
	g_t = 0.0
	g_slot = -1
	g_react = _react()
	g_shot_t = 0.0
	g_mag = 12
	g_read.clear()
	g_nolos = 0.0
	g_reload = 0.0
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


## A step toward `to` around the racks: straight when walkable, else via an aisle corner or the cross aisle.
func _route_step(f: GunFight, to: Vector3, speed: float) -> void:
	var p: Vector3 = bs.player.global_position
	var cross_z: float = bs.level.world(Vector3(0.0, 0.0, 18.5)).z
	for c: Vector3 in [to, Vector3(p.x, p.y, to.z), Vector3(to.x, p.y, p.z), Vector3(p.x, p.y, cross_z), Vector3(to.x, p.y, cross_z)]:
		if StoryMission.flat(c, p) > 0.3 and f.clear_walk(p, c):
			_step_to(c, speed)
			return
	_step_to(to, speed)


# ---------------------------------------------------------------------------
# Gun bot
# ---------------------------------------------------------------------------
func _gun(f: GunFight) -> void:
	if f == null or f.state != "running" or f.cover_ctl == null:
		return
	var foes: Array = f.alive()
	if foes.is_empty():
		f.cover_ctl.hold_override = false
		bs.weapons.aim_override = false
		return
	var threat := Vector3.ZERO
	for e: Variant in foes:
		threat += (e as Node3D).global_position
	threat /= float(foes.size())
	g_t += DT
	if g_mag <= 0:
		g_reload += DT
		if g_reload >= 1.5:
			g_mag = 12
			g_reload = 0.0
	if g_nolos >= 3.0 and g_state != "advance":
		g_state = "advance"                          # nobody in sight for 3 s: push toward the nearest gunman
		g_t = 0.0
		g_slot = -1
		f.cover_ctl.hold_override = false
	match g_state:
		"advance":
			bs.weapons.aim_override = true
			var near: Gunman = null
			var nd: float = INF
			for e3: Variant in foes:
				var d3: float = StoryMission.flat((e3 as Node3D).global_position, bs.player.global_position)
				if d3 < nd:
					nd = d3
					near = e3 as Gunman
			var eye: Vector3 = bs.player.global_position + Vector3(0.0, 1.5, 0.0)
			if near and (nd > 8.0 or not _sees(f, eye, near)) and nd > 2.5 and g_t < 6.0:
				_route_step(f, near.global_position, 4.0)
			else:
				g_nolos = 0.0
				g_state = "pop"
				g_t = 0.0
				g_react = rng.randf_range(1.5, 2.5)
				g_shot_t = -_react()
		"move":
			if g_slot < 0:
				g_slot = _pick_slot(f, threat)
			if g_slot < 0:
				g_state = "pop"
				g_t = 0.0
				return
			if _step_to(f.cover.pos[g_slot], 4.5):
				f.cover_ctl.hold_override = true
				g_state = "cover"
				g_t = 0.0
				g_react = rng.randf_range(0.8, 1.5) + (0.3 if _wrong() else 0.0)
		"cover":
			bs.weapons.aim_override = false
			if g_mag <= 0:
				return
			if g_t >= g_react:
				g_state = "pop"
				g_t = 0.0
				g_react = rng.randf_range(0.7, 1.3) + (0.8 if _wrong() else 0.0)
				g_shot_t = -_react()
		"pop":
			bs.weapons.aim_override = true
			for e2: Variant in foes:
				var gm: Gunman = e2 as Gunman
				if gm and gm.telegraphing and not g_read.has(gm):
					g_read[gm] = _reads()
					if g_read[gm] and g_t > 0.3:
						g_react = minf(g_react, g_t + _react())
				elif gm and not gm.telegraphing:
					g_read.erase(gm)
			g_shot_t += DT
			if g_shot_t >= 0.4:
				g_shot_t = 0.0
				if _shoot(f, foes):
					g_nolos = 0.0
			if g_shot_t >= 0.0:
				g_nolos += DT
			if g_t >= g_react or (g_mag <= 0 and not _wrong()):
				g_state = "cover" if g_slot >= 0 else "move"
				g_t = 0.0
				g_react = rng.randf_range(0.8, 1.5) + (0.3 if _wrong() else 0.0)
				if g_slot >= 0 and not f.cover.protects(g_slot, threat) and rng.randf() > 0.15:
					f.cover_ctl.hold_override = false
					g_slot = -1
					g_state = "move"


func _pick_slot(f: GunFight, threat: Vector3) -> int:
	var p: Vector3 = bs.player.global_position
	var best: int = -1
	var bd: float = INF
	var sloppy: bool = _wrong()
	for i: int in f.cover.count():
		if f.taken.has(i):
			continue
		var d: float = StoryMission.flat(f.cover.pos[i], p)
		if d > 12.0 or StoryMission.flat(f.cover.pos[i], threat) < 5.0:
			continue
		if not sloppy and not f.cover.protects(i, threat):
			continue
		if d < bd:
			bd = d
			best = i
	return best


## One shot (a label, else the nearest gunman in sight); true when it had a target in sight.
func _shoot(f: GunFight, foes: Array) -> bool:
	if g_mag <= 0:
		return true
	g_mag -= 1
	var eye: Vector3 = bs.player.global_position + Vector3(0.0, 1.5, 0.0)
	# the domino: two or more gunmen in a standing row's fall, the label in sight
	var lv: LairBasement = bs.level
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
		var tg: Node3D = rd["target"]
		if n >= 2 and _reads() and f.clear_line(eye, tg.global_position + Vector3(0.0, 0.9, 0.0)):
			if rng.randf() < _hit_p(StoryMission.flat(tg.global_position, eye)):
				bs.weapons.hit_target(tg, {"kind": "bullet", "from": bs.player.global_position})
			return true
	var best: Gunman = null
	var bd: float = INF
	for e2: Variant in foes:
		var g: Gunman = e2 as Gunman
		if g == null:
			continue
		var d: float = StoryMission.flat(g.global_position, eye)
		if d < bd and _sees(f, eye, g):
			bd = d
			best = g
	if best and rng.randf() < _hit_p(bd):
		bs.weapons.hit_target(best, {"kind": "bullet", "from": bs.player.global_position})
	return best != null


## A line of sight to the gunman's chest or to his head peeking over the cover.
func _sees(f: GunFight, eye: Vector3, g: Gunman) -> bool:
	return f.clear_line(eye, g.feet() + Vector3(0.0, 1.2, 0.0)) or f.clear_line(eye, g.feet() + Vector3(0.0, 1.55, 0.0))


func _hit_p(d: float) -> float:
	return clampf(0.55 * 15.0 / maxf(d, 4.0), 0.25, 0.85)


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
		var facing: bool = d < g.patrol_sight_m + 3.0 and (d < 0.5 or rad_to_deg(g.forward().angle_to(to / maxf(d, 0.01))) < g.patrol_fov_deg * 0.5 + 15.0)
		if facing:
			if not s_read.has(g):
				s_read[g] = [_reads(), _react()]
			var rd: Array = s_read[g]
			rd[1] = float(rd[1]) - DT
			if bool(rd[0]) and float(rd[1]) <= 0.0:
				danger = true
		else:
			s_read.erase(g)
	if danger and s_wait <= 0.0 and _wrong():
		s_wait = -0.6                                # moves anyway
	if s_wait < 0.0:
		s_wait += DT
		danger = false
	if danger:
		return
	if w_i < ROUTE.size() and _step_to(bs.level.world(ROUTE[w_i]), 3.0):
		w_i += 1


# ---------------------------------------------------------------------------
# Typist
# ---------------------------------------------------------------------------
func _hack() -> void:
	var mh: MissionHack = m as MissionHack
	match mh.phase:
		"breach":
			if t_notice < 0.0:
				t_notice = _react()
			t_notice -= DT
			if t_notice <= 0.0:
				_gun(mh.fight)
			return
		"return":
			if mh.fight and mh.fight.cover_ctl:
				mh.fight.cover_ctl.hold_override = false
			bs.weapons.aim_override = false
			if _step_to(mh.pts["spot"], 4.5):
				if t_notice < 0.0 or t_notice > 0.5:
					t_notice = _react()
				t_notice -= DT
				if t_notice <= 0.0:
					mh.return_to_desk()
					t_notice = -1.0
			return
		"typing":
			t_notice = -1.0
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
