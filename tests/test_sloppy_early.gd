# File: res://tests/test_sloppy_early.gd
# Q6 "sloppy bot" tuning of the Wave 2 early-days missions (plan 2026-10-29-w2-early.md Task 9): the stake-out, the foot
# chase and the canteen undercover, each played by a sloppy player model on the mission's manual clock in a real FreeRoam
# (crowd off), on Thường and on Dễ, several seeds each. The model, per the master plan Q6:
#   - every reaction (a turn telegraph, a guard, an obstacle, a prompt) comes 250-400 ms late;
#   - 15 % of its decisions are wrong or late (a duck 0.6 s late, a missed vault, a shot before the view is steady, a
#     sprint that drops the tray, the pop tune taken for the music box, an impatient accusation);
#   - it reads telegraphs imperfectly (the late duck), aims with a shaky hand and lingers when it reads a note.
# Each run plays attempts (THỬ LẠI after every fail) until the mission is won, at most MAX_TRIES. Targets: Thường a mean of
# 1-3 fails per mission over the seeds and every run done within 5 retries; Dễ at most 1 fail in every run. It prints the
# table the plan records ("SLOPPY <mission> <difficulty>: fails [...] mean m").
# The Stage 1 race has its own sloppy mode (tests/test_stage1_race.gd -- --sloppy); the brawls use the shared melee AI.
# Run:  godot --headless --path . --script tests/test_sloppy_early.gd
extends SceneTree

const DT: float = 0.05
const MAX_TRIES: int = 8
const SEEDS: Array[int] = [3, 7, 11, 19, 23, 31]
const STAKE_P := Vector3(100.8, 0.0, 102.0)    # beside the west end of a parked car: shoot over it, duck behind it
const STAKE_HIDE := Vector3(102.0, 0.0, 99.9)  # the car's far side from the lane (the guard walks the lane)

var fails: Array[String] = []
var fr: Node
var rng := RandomNumberGenerator.new()
var frames: int = 0
var results: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST SLOPPY BOT: STAKE-OUT, CHASE, CANTEEN (Thường / Dễ) ---")
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	root.add_child(fr)


func _player() -> ThirdPersonController:
	return fr.get("player")


var started: bool = false
var finished: bool = false


func _process(_d: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	if not started:
		started = true
		_run_all()
	return finished


## The runs (a coroutine: a new mission's bodies join the physics space only after a physics frame).
func _run_all() -> void:
	for easy: bool in [false, true]:
		Difficulty.set_easy(easy)
		var tag: String = "De" if easy else "Thuong"
		for mission: String in ["stakeout", "chase", "canteen"]:
			var list: Array[int] = []
			for sd: int in SEEDS:
				list.append(await _run(mission, sd))
			results["%s_%s" % [mission, tag]] = list
			var total: int = 0
			for f: int in list:
				total += f
			var mean: float = float(total) / float(list.size())
			print("SLOPPY %s %s: fails %s mean %.2f" % [mission, tag, str(list), mean])
			if easy:
				_check(list.max() <= 1, "%s Dễ: at most 1 fail per run (%s)" % [mission, str(list)])
			else:
				_check(mean >= 1.0 and mean <= 3.0, "%s Thường: a mean of 1-3 fails (%.2f %s)" % [mission, mean, str(list)])
				_check(list.max() <= 5, "%s Thường: done within 5 retries (%s)" % [mission, str(list)])
	Difficulty.set_easy(false)
	if fails.is_empty():
		print("✅ SUCCESS: SLOPPY BOT TUNING (stake-out, chase, canteen on Thường and Dễ)")
		quit(0)
	else:
		print("❌ FAILED: %d check(s)" % fails.size())
		quit(1)
	finished = true


func _make(script: GDScript, beat: Dictionary, sd: int, extra: Dictionary = {}) -> StoryMission:
	var m: StoryMission = script.new()
	fr.add_child(m)
	var o: Dictionary = {"manual": true, "manual_replay": true, "seed": sd}
	o.merge(extra)
	m.setup(fr, beat, o)
	m.begin()
	return m


## Plays one mission with the sloppy model until it is won (or MAX_TRIES): the fails before the win (MAX_TRIES = never won).
func _run(mission: String, sd: int) -> int:
	rng.seed = sd * 7919 + (1 if Difficulty.easy else 0)
	var m: StoryMission
	match mission:
		"stakeout":
			m = _make(MissionStakeout, {"id": "sim_stakeout", "title": "Rình"}, sd)
		"chase":
			m = _make(MissionChase, {"id": "sim_chase", "title": "Đuổi", "replay": "seg_d1_chase"}, sd)
		_:
			m = _make(MissionCanteen, {"id": "sim_canteen", "title": "Căn tin"}, sd)
	var done_info: Array = [{}]
	m.done.connect(func(info: Dictionary) -> void: done_info[0] = info)
	for k: int in 3:
		await physics_frame
	var tries: int = 0
	while tries < MAX_TRIES:
		match mission:
			"stakeout":
				_play_stakeout(m as MissionStakeout)
			"chase":
				_play_chase(m as MissionChase)
			_:
				_play_canteen(m as MissionCanteen)
		if m.state == "done" or (mission == "chase" and (m as MissionChase).ended):
			break
		if OS.get_cmdline_user_args().has("--verbose"):
			print("    %s seed %d try %d: %s clock %.1f %s" % [mission, sd, tries, m.state, m.clock, _diag(m)])
			if m is MissionStakeout and tries == 0 and false:
				print("      spot %s (campus %s)" % [str(m.get_meta("sim_spot", Vector3.ZERO)), str((fr.get("campus_xf") as Transform3D).affine_inverse() * (m.get_meta("sim_spot", Vector3.ZERO) as Vector3))])
		tries += 1
		m.retry()
	var rid: String = {"stakeout": "d1_stakeout", "chase": "d1_chase"}.get(mission, "d4_canteen")
	var rev: Dictionary = StoryRank.evaluate(rid, m.stats, done_info[0])
	print("  RANK %s %s seed %d: %s %.0f (time %.0f s, fails %d, dmg %.0f, info %s)" % [rid, "De" if Difficulty.easy else "Thuong", sd,
		String(rev.get("letter", "")), float(rev.get("score", 0.0)), float(m.stats.get("time", 0.0)), int(m.stats.get("fails", 0)),
		float(m.stats.get("dmg", 0.0)), str(done_info[0])])   # Wave 3 T10 calibration
	m.abort()
	return tries


func _diag(m: StoryMission) -> String:
	if m is MissionStakeout:
		var so: MissionStakeout = m
		return "photos %d sus %.0f guard %d barks %d tells %d blurs %d phase %s" % [so.photos.count(true), so.suspicion, so.guard_walks, so.barks, so.tells, so.blurs, so.phase]
	if m is MissionChase:
		var ch: MissionChase = m
		return "s %.0f dist %.0f" % [ch.s, ch.distance()]
	var mc: MissionCanteen = m
	return "sus %.0f wrong %d drops %d hints %d" % [mc.suspicion, mc.wrong, mc.drops, mc.hints_given]


func _react() -> float:
	return rng.randf_range(0.25, 0.4)


func _wrong() -> bool:
	return rng.randf() < 0.15


func _walk_to(m: StoryMission, at: Vector3, speed: float, max_s: float) -> float:
	var p: Vector3 = _player().global_position
	var t: float = 0.0
	while t < max_s and m.state == "running":
		var d := Vector3(at.x - p.x, 0.0, at.z - p.z)
		if d.length() < 0.15:
			break
		p += d.normalized() * minf(speed * DT, d.length())
		p.y = (m as MissionStakeout).floor_y(p) if m is MissionStakeout else m.ground_y(p)
		_player().teleport(p, StoryMission.yaw_of(d))
		m.advance(DT)
		t += DT
	return t


# ---------------------------------------------------------------------------
# STAKE-OUT
# ---------------------------------------------------------------------------
func _aim_with(so: MissionStakeout, err_deg: float, ang: float) -> void:
	var to: Vector3 = so.courier_chest() - so.eye_pos()
	var yaw: float = atan2(-to.x, -to.z)
	var pitch: float = asin(clampf(to.y / maxf(to.length(), 0.01), -1.0, 1.0))
	_player().yaw = yaw + deg_to_rad(err_deg) * cos(ang)
	_player().pitch = pitch + deg_to_rad(err_deg) * sin(ang)


## A spot a player finds by trying: ducked there the courier's eye cannot see the head (a car between), standing there
## the phone sees his chest over the roof, within photo range. Searched once per mission object (cached).
func _stake_spot(so: MissionStakeout) -> Vector3:
	if so.has_meta("sim_spot"):
		return so.get_meta("sim_spot")
	var eye: Vector3 = so.courier.global_position + Vector3(0.0, 1.6, 0.0)
	var chest: Vector3 = so.courier_chest()
	var best := Vector3.INF
	var bd: float = INF
	for iu: int in 40:
		for iv: int in 26:
			var c: Vector3 = so.campus(Vector3(96.0 + 0.5 * float(iu), 0.0, 99.0 + 0.3 * float(iv)))
			c.y = so.floor_y(c)
			if MissionStakeout.flat(c, so.courier.global_position) > MissionStakeout.photo_m() - 1.0:
				continue
			var head_duck: Vector3 = c + Vector3(0.0, MissionStakeout.HEAD_DUCK + 0.1, 0.0)
			var cam: Vector3 = c + Vector3(0.0, MissionStakeout.EYE_STAND, 0.0)
			if so.clear_line(eye, head_duck) or not so.clear_line(cam + (chest - cam).normalized() * 0.3, chest):
				continue
			if not so.clear_line(eye, c + Vector3(0.0, MissionStakeout.HEAD_STAND, 0.0)):
				continue   # standing there the head shows over the roof (the duck matters)

			var d: float = MissionStakeout.flat(c, so.campus(STAKE_P))
			if d < bd:
				bd = d
				best = c
	if best == Vector3.INF:
		_probe(so)
		best = so.campus(STAKE_P)
		_check(false, "the stake-out has a spot to shoot from and duck behind a car")
	so.set_meta("sim_spot", best)
	if OS.get_cmdline_user_args().has("--verbose"):
		print("      stake-out spot campus %s" % str((fr.get("campus_xf") as Transform3D).affine_inverse() * best))
	return best


func _probe(so: MissionStakeout) -> void:
	var eye: Vector3 = so.courier.global_position + Vector3(0.0, 1.6, 0.0)
	var face: Vector3 = so.courier_chest()
	var space: PhysicsDirectSpaceState3D = so.get_world_3d().direct_space_state
	for l: Vector3 in [Vector3(101.0, 0.0, 101.3), Vector3(100.0, 0.0, 101.3), Vector3(108.0, 0.0, 101.3), Vector3(101.0, 0.0, 103.5)]:
		var c: Vector3 = so.campus(l)
		c.y = so.floor_y(c)
		var out: PackedStringArray = []
		for pair: Array in [["duck", eye, c + Vector3(0.0, 1.0, 0.0)], ["stand", eye, c + Vector3(0.0, 1.55, 0.0)], ["photo", c + Vector3(0.0, 1.55, 0.0), face]]:
			var q := PhysicsRayQueryParameters3D.create(pair[1], pair[2])
			q.exclude = [_player().get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			out.append("%s:%s" % [pair[0], "clear" if hit.is_empty() else "%s@%.1f" % [(hit["collider"] as Node).name if hit["collider"] is Node else "?", (hit["position"] as Vector3).y]])
		print("      probe %s y %.2f courier y %.2f: %s" % [str(l), c.y, so.courier.global_position.y, " ".join(out)])


## Where to duck while the guard walks the lane by: near `from`, the ducked head hidden from the guard's eye along the lane
## east of it and from the courier (circling the car). `from` when none.
func _guard_hide(so: MissionStakeout, from: Vector3) -> Vector3:
	if so.has_meta("sim_hide"):
		return so.get_meta("sim_hide")
	var inv: Transform3D = (fr.get("campus_xf") as Transform3D).affine_inverse()
	var eye: Vector3 = so.courier.global_position + Vector3(0.0, 1.6, 0.0)
	var lf: Vector3 = inv * from
	var best: Vector3 = from
	var bd: float = INF
	for iu: int in 21:
		for iv: int in 21:
			var l := Vector3(lf.x - 5.0 + 0.5 * float(iu), 0.0, lf.z - 5.0 + 0.5 * float(iv))
			var c: Vector3 = so.campus(l)
			c.y = so.floor_y(c)
			var head: Vector3 = c + Vector3(0.0, MissionStakeout.HEAD_DUCK + 0.1, 0.0)
			if so.clear_line(eye, head):
				continue
			var seen: bool = false
			for du: float in [2.0, 4.0, 7.0, 10.0, 13.0]:
				var g: Vector3 = so.campus(Vector3(l.x + du, 0.0, 103.5))
				g.y = so.floor_y(g) + 1.6
				if so.clear_line(g, head):
					seen = true
					break
			if seen:
				continue
			var d: float = MissionStakeout.flat(c, from)
			if d < bd:
				bd = d
				best = c
	so.set_meta("sim_hide", best)
	return best


func _play_stakeout(so: MissionStakeout) -> void:
	var p: Vector3 = _stake_spot(so)
	so.duck_override = false
	so.raise_phone(false)
	_walk_to(so, p, 3.6, 10.0)
	var duck_at: float = -1.0
	var stand_at: float = -1.0
	var hiding: bool = false
	var guard_seen_t: float = -1.0
	var err: float = rng.randf_range(2.0, 6.0)
	var base_err: float = absf(rng.randfn(0.0, 1.3))
	var err_t: float = 0.0
	var ang: float = rng.randf() * TAU
	var shoot_at: float = -1.0
	var early: bool = false
	var next_shot: float = 0.0
	var prev_phase: String = so.phase
	var prev_barks: int = so.barks
	var guard_done: int = 0
	var t: float = 0.0
	while so.state == "running" and t < 140.0:
		# the turn telegraphs (and Lu's bark): duck after the reaction (a late duck 15 % of the time)
		if (so.phase == "tell" and prev_phase != "tell") or so.barks != prev_barks:
			duck_at = t + _react() + (rng.randf_range(0.5, 1.2) if _wrong() else 0.0)
			stand_at = -1.0
		if so.phase == "act" and prev_phase != "act":
			stand_at = t + _react()
		if so.phase == "look" and prev_phase != "look" and _wrong():
			stand_at = t + maxf(0.0, MissionStakeout.look_s() - rng.randf_range(0.3, 1.0))   # peeks up before he turns back
		prev_phase = so.phase
		prev_barks = so.barks
		if duck_at >= 0.0 and t >= duck_at:
			duck_at = -1.0
			so.raise_phone(false)
			so.duck_override = true
		if stand_at >= 0.0 and t >= stand_at and not hiding:
			stand_at = -1.0
			so.duck_override = false
		# the guard walking down the lane: around the car (standing walk), ducked there until he has passed
		if so.guard_state == "walking" and so.guard_walks > guard_done and not hiding:
			var gd: float = MissionStakeout.flat(so.guard.global_position, _player().global_position)
			if gd < 16.0 and guard_seen_t < 0.0:
				guard_seen_t = t + _react() + (rng.randf_range(0.5, 1.2) if _wrong() else 0.0)
			if guard_seen_t >= 0.0 and t >= guard_seen_t:
				guard_seen_t = -1.0
				hiding = true                 # circles the car, ducked, to its side away from the lane
				so.raise_phone(false)
				so.duck_override = true
				t += _walk_to(so, _guard_hide(so, p), MissionStakeout.DUCK_SPEED, 6.0)
		if hiding and (so.guard_state != "walking" or (so.guard.global_position - _player().global_position).dot(so.campus_dir(Vector3(-1.0, 0.0, 0.0))) > 3.0):
			hiding = false
			guard_done = so.guard_walks
			t += _walk_to(so, p, MissionStakeout.DUCK_SPEED, 6.0)
			stand_at = t + _react() if so.phase == "act" else -1.0
		# shooting: phone up while he does a moment not yet photographed, a shaky aim settling in
		if not hiding and not so.duck_override and so.phase == "act" and not so.photos[so.moment] and (so.in_profile or so.phase_t >= so.profile_from - 1.0):
			if not so.phone_up:
				so.raise_phone(true)
				err = rng.randf_range(2.0, 6.0)
				err_t = 0.0
				shoot_at = -1.0
				early = _wrong()          # 15 %: shoots before the view is steady
				next_shot = 0.0
			err_t += DT
			if fmod(err_t, 1.5) < DT:
				base_err = absf(rng.randfn(0.0, 1.3))
				ang = rng.randf() * TAU
			var e: float = lerpf(err, base_err, clampf(err_t / 0.6, 0.0, 1.0))
			_aim_with(so, e, ang)
			if shoot_at < 0.0 and err_t >= next_shot and so.in_profile and (so.steady_t >= MissionStakeout.steady_s() or (early and err_t > 0.4)):
				shoot_at = t + _react()
			if shoot_at >= 0.0 and t >= shoot_at:
				shoot_at = -1.0
				early = false
				next_shot = err_t + 1.0   # a second look at the screen before the next try
				so.take_photo()
		elif so.phone_up and so.phase != "act":
			so.raise_phone(false)
		so.advance(DT)
		t += DT
	so.duck_override = null


# ---------------------------------------------------------------------------
# FOOT CHASE
# ---------------------------------------------------------------------------
func _play_chase(ch: MissionChase) -> void:
	var ps: float = 0.0
	var stamina: float = 1.0
	var regen_wait: float = 0.0
	var exhausted: bool = false
	var detour: float = 0.0
	var done_obst: Array[int] = []
	var took_shortcut: bool = rng.randf() < 0.4
	var tackle_at: float = -1.0
	var start: Vector3 = _player().global_position
	# from the start spot onto the path behind him
	ps = -MissionChase.flat(start, ch.pts[0])
	var t: float = 0.0
	while ch.state == "running" and not ch.ended and t < 150.0:
		var dist_path: float = ch.s - ps
		var want_sprint: bool = dist_path > 5.0 and not exhausted
		var speed: float = ThirdPersonController.SPRINT_SPEED if want_sprint else ThirdPersonController.JOG_SPEED
		if want_sprint:
			stamina = maxf(0.0, stamina - DT / ThirdPersonController.STAMINA_MAX_S)
			regen_wait = ThirdPersonController.STAMINA_REGEN_DELAY
			if stamina <= 0.0:
				exhausted = true
		else:
			regen_wait -= DT
			if regen_wait <= 0.0:
				stamina = minf(1.0, stamina + ThirdPersonController.STAMINA_REGEN / ThirdPersonController.STAMINA_MAX_S * DT)
			if exhausted and stamina >= ThirdPersonController.STAMINA_RESUME:
				exhausted = false
		if dist_path < 2.5:
			speed = minf(speed, ch.speed_for(ch.distance()) + 0.5)
		if detour > 0.0:
			detour -= DT
			speed = 0.0
		# set pieces ahead
		for i: int in ch.obstacles.size():
			if done_obst.has(i):
				continue
			var o: Dictionary = ch.obstacles[i]
			var d: float = float(o["d"])
			var kind: String = String(o["kind"])
			if ps < d - 1.2 or ps > d + 1.5:
				continue
			var standing: bool = kind in ["vault", "slide"] or o["state"] == "down"
			done_obst.append(i)
			if not standing:
				continue
			var react_lost: float = _react() * speed * 0.3   # a beat of hesitation at the obstacle
			ps -= react_lost
			if _wrong() or (kind in ["trash", "fruit"] and rng.randf() < 0.3):
				if kind in ["trash", "fruit"]:
					detour = 2.0 * MissionChase.SLOW_R / MissionChase.slow_cap() - 2.0 * MissionChase.SLOW_R / ThirdPersonController.JOG_SPEED   # wades through
				else:
					detour = 2.0   # missed the prompt: round the bench / barrier
			else:
				var before: Vector3 = (o["at"] as Vector3) - (o["fwd"] as Vector3) * 1.0
				_player().teleport(before, StoryMission.yaw_of(o["fwd"]))
				var ok: bool = ch.try_slide() if kind == "slide" else ch.try_vault()
				if ok:
					for k: int in int(ceil((MissionChase.SLIDE_S if kind == "slide" else MissionChase.VAULT_S) / DT)) + 1:
						ch.advance(DT)
						t += DT
					ps = d + 1.3
		# the canteen shortcut across the courtyard loop
		if took_shortcut and ps >= ch.cum[3] and ps < ch.cum[3] + 1.0 and ch.s < ch.cum[6]:
			ps = ch.cum[6] - 12.5 * (ThirdPersonController.SPRINT_SPEED / ThirdPersonController.JOG_SPEED) + 12.5
			ps = minf(ps, ch.s - 1.0)
		ps += speed * DT
		ps = minf(ps, ch.s - 0.6)
		var pos: Vector3 = ch.point_at(maxf(ps, 0.0)) if ps >= 0.0 else start.lerp(ch.pts[0], clampf(1.0 + ps / maxf(MissionChase.flat(start, ch.pts[0]), 0.1), 0.0, 1.0))
		_player().teleport(pos, StoryMission.yaw_of(ch.courier.global_position - pos))
		# the tackle prompt: Space after the reaction (15 %: a beat late, he gets ahead again)
		if ch.can_tackle() and tackle_at < 0.0:
			tackle_at = t + _react() + (0.5 if _wrong() else 0.0)
		if tackle_at >= 0.0 and t >= tackle_at:
			tackle_at = -1.0
			ch.try_vault()
		ch.advance(DT)
		t += DT
	var n: int = 0
	while ch.tackling and n < 40:
		ch.advance(DT)
		n += 1


# ---------------------------------------------------------------------------
# CANTEEN
# ---------------------------------------------------------------------------
func _play_canteen(mc: MissionCanteen) -> void:
	var order: Array[int] = []
	for i: int in mc.clones.size():
		order.append(i)
	for i2: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i2)
		var tmp: int = order[i2]
		order[i2] = order[j]
		order[j] = tmp
	var seen: Dictionary = {}    # index -> clues as read (the pop tune taken for the music box 15 % of the time)
	var t: float = 0.0
	var k: int = 0
	while mc.state == "running" and t < 150.0:
		if not mc.has_tray:
			var cp: Vector3 = mc.xf * (MissionCanteen.COUNTER + Vector3(0.0, 0.0, 1.2))
			t += _walk_to(mc, cp, 1.8, 12.0)
			mc.interact()
		var i: int = order[k % order.size()]
		k += 1
		var c: Node3D = mc.clones[i]
		var back := Vector3(sin(c.global_rotation.y), 0.0, cos(c.global_rotation.y))
		var spot: Vector3 = c.global_position + back * 1.2
		var sprint: bool = _wrong() and rng.randf() < 0.35   # in a hurry: sprints and drops the tray
		if sprint:
			_player().is_sprinting = true
			_player().horizontal_speed = 7.0
			mc.advance(DT)
			_player().is_sprinting = false
			_player().horizontal_speed = 0.0
		t += _walk_to(mc, spot, 1.8, 10.0)
		_player().teleport(spot, StoryMission.yaw_of(c.global_position - spot))
		var linger: float = rng.randf_range(1.2, 3.2) + _react()
		var lt: float = 0.0
		while lt < linger and mc.state == "running":
			mc.advance(DT)
			lt += DT
		t += lt
		var cl: Dictionary = (mc.clues[i] as Dictionary).duplicate()
		if bool(cl["pop"]) and _wrong():
			cl["hum"] = true
		seen[i] = cl
		# accuse: the one matching every hint so far (all three: sure; two: an impatient guess 30 % of the time)
		var hints: int = mc.hints_given
		var best: int = -1
		var matches: int = 0
		for idx: Variant in seen:
			var sc: Dictionary = seen[idx]
			var ok: bool = (hints < 1 or bool(sc["hum"])) and (hints < 2 or bool(sc["wool"])) and (hints < 3 or bool(sc["salad"]))
			if ok and (bool(sc["hum"]) or bool(sc["wool"]) or bool(sc["salad"])):
				matches += 1
				best = int(idx)
		var hurry: bool = mc.clock > MissionCanteen.lunch_s() - 12.0
		var go: bool = best >= 0 and ((hints >= 3 and matches == 1) or (hints == 2 and rng.randf() < 0.3) or hurry)
		if go:
			var target: int = best
			if _wrong():
				target = order[rng.randi_range(0, order.size() - 1)]
			var fc: Node3D = mc.clones[target]
			var fb := Vector3(sin(fc.global_rotation.y), 0.0, cos(fc.global_rotation.y))
			_player().teleport(fc.global_position + fb * 1.2, StoryMission.yaw_of(-fb))
			mc.accuse(target)
			seen.erase(target)
