# File: res://tests/sim_day3.gd
# Tuning harness for Day 3 (plan 2026-10-30-w3-day3.md T9). Not a regression test: it plays the real yard missions
# (MissionYardSneak, MissionYardGunfight, MissionCrates, MissionForklift on the real LairYard in FreeRoam at night, the
# missions stepped on the fixed frame clock, the GunFight / gunmen / boss on physics frames) with the sloppy bot, retries
# after every fail like THỬ LẠI (from the mission's checkpoint) and prints one line per run plus a summary per mission:
# fails per run, game time, damage taken, knockouts (the par numbers for StoryRank).
# The sloppy gun bot (the shared plan's model, 2026-10-30-w3-shared.md "Sloppy gun bot"): 250-400 ms reaction on every
# decision (+0.3 s when late); 15 % wrong or late (stays popped out too long, picks a cover that does not protect, a
# prompt pressed late); reads 65 % of the muzzle glints (it ducks back on a glint it reads); a shaky aim (about 55 % hit
# at 15 m standing, worse moving). Its shots are abstract (a hit = Gunman.take_hit "bullet" from the player); the gunmen,
# their tokens, telegraphs, cover rules and damage are the real ones. Day 3 additions: freezes 250-400 ms after a
# flashlight starts toward it (15 % late), aims crane drops with +-1.5 m error, steers out of charges late, mistimes 15 %
# of rams. Moves by stepping teleports at walking speed (no footstep noise).
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_day3.gd -- normal 1 8 gunfight
#   (difficulty normal | easy, first seed, runs, mission sneak | gunfight | crates | boss | all)
extends SceneTree

const DT: float = 1.0 / 60.0
const MAX_GAME_S: float = 600.0
const MISSIONS: Array[String] = ["sneak", "gunfight", "crates", "boss"]
const BEATS: Dictionary = {"sneak": "d3_sneak", "gunfight": "d3_gunfight", "crates": "d3_crates", "boss": "d3_boss"}
const SCRIPTS: Dictionary = {"sneak": "res://scripts/story/missions/MissionYardSneak.gd",
	"gunfight": "res://scripts/story/missions/MissionYardGunfight.gd", "crates": "res://scripts/story/missions/MissionCrates.gd",
	"boss": "res://scripts/story/missions/MissionForklift.gd"}
const TASKS: Dictionary = {"sneak": "sneak", "gunfight": "gunfight", "crates": "crates", "boss": "forklift"}
## The sneak route (yard-local): wait points the bot holds until the next leg looks clear.
const ROUTE: Array[Vector3] = [Vector3(-23.0, 0.0, 8.5), Vector3(-19.5, 0.0, 5.2), Vector3(-11.0, 0.0, 5.2),
	Vector3(-10.3, 0.0, 1.0), Vector3(-7.5, 0.0, -0.6), Vector3(-3.0, 0.0, -4.4)]

var diff: String = "normal"
var seed0: int = 1
var runs: int = 4
var which: Array[String] = []
var fr: Node3D
var yard: LairYard
var m: StoryMission
var rng := RandomNumberGenerator.new()
var frames: int = 0
var phase: String = "boot"
var mi: int = 0
var run_i: int = 0
var game_t: float = 0.0
var fails: int = 0
var dmg: float = 0.0
var last_hp: float = 100.0
var results: Dictionary = {}      # mission -> Array of [fails, time, dmg, kos, extra]
# bot state
var b_wait: float = 0.0           # s until the next decision may run
var b_leg: int = 0
var b_move_to: Variant = null
var b_shot_t: float = 0.0
var b_cover_t: float = 0.0
var b_popped: bool = false
var b_freeze_at: float = -1.0
var b_clear_t: float = 0.0
var b_mash_t: float = 0.0
var b_crane: String = ""          # "" | "go" | "climb" | "aim" | "drop" | "done"
var b_crane_wave: int = -1
var b_aim: Vector2 = Vector2.ZERO
var b_target_i: int = 0
var b_dodge_at: float = -1.0
var b_ram_at: float = -1.0
var b_toss_at: float = -1.0
var b_tell_seen: bool = false
var b_lift_seen: bool = false
var b_toss_seen: int = 0
var b_fail_t: float = -1.0
var b_kos: int = 0


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		diff = a[0]
	if a.size() > 1:
		seed0 = int(a[1])
	if a.size() > 2:
		runs = int(a[2])
	var w: String = a[3] if a.size() > 3 else "all"
	which.assign(MISSIONS if w == "all" else [w])
	Difficulty.set_easy(diff == "easy")
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	print("--- SIM DAY 3: %s, seeds %d.., %d runs, %s ---" % [diff, seed0, runs, ", ".join(which)])


func _p() -> ThirdPersonController:
	return fr.get("player")


func _combat() -> PlayerCombat:
	return fr.get("combat")


func _fight() -> GunFight:
	return m.get("fight") as GunFight if m else null


func _react() -> float:
	var d: float = rng.randf_range(0.25, 0.4)
	return d + (0.3 if rng.randf() < 0.15 else 0.0)


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		"boot":
			fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			phase = "yard"
			frames = 0
		"yard":
			if frames < 20:
				return false
			fr.call("set_time_of_day", "night")
			yard = LairYard.new()
			yard.build_in(fr)
			yard.set_stack_open(true)
			phase = "start"
		"start":
			if mi >= which.size():
				return _report()
			_start_run()
			phase = "run"
		"run":
			_tick()
		"gap":
			if frames > 10:
				phase = "start"
	return false


func _start_run() -> void:
	var name: String = which[mi]
	rng.seed = (seed0 + run_i) * 7919 + mi
	(fr.get("combat") as PlayerCombat).god = false
	_combat().revive()
	m = (load(String(SCRIPTS[name])) as GDScript).new()
	fr.add_child(m)
	var o: Dictionary = {"manual": true, "manual_replay": true, "seed": seed0 + run_i, "level": yard,
		"points": yard.mission_points(String(TASKS[name]))}
	if name == "crates":
		for c: SmartCrate in yard.crates:
			c.reset()
	m.setup(fr, StoryMissions.beat(String(BEATS[name])), o)
	m.begin()
	game_t = 0.0
	fails = 0
	dmg = 0.0
	last_hp = _combat().hp
	_reset_bot()
	b_fail_t = -1.0
	b_kos = 0


func _reset_bot() -> void:
	b_wait = _react()
	b_leg = 0
	b_move_to = null
	b_shot_t = 0.0
	b_cover_t = 0.0
	b_popped = false
	b_freeze_at = -1.0
	b_clear_t = 0.0
	b_mash_t = 0.0
	b_crane = ""
	b_crane_wave = -1
	b_dodge_at = -1.0
	b_ram_at = -1.0
	b_toss_at = -1.0
	b_tell_seen = false
	b_lift_seen = false
	b_toss_seen = 0


func _tick() -> void:
	game_t += DT
	var hp: float = _combat().hp
	if hp < last_hp:
		dmg += last_hp - hp
	last_hp = hp
	if _fight():
		b_kos = maxi(b_kos, _fight().ko_total)
	if m.replay != null:
		m.replay.step(DT)   # the short replay (manual_replay): the mission waits for it
		return
	if m.state == "failed":
		if b_fail_t < 0.0:
			b_fail_t = 0.5
			fails += 1
		b_fail_t -= DT
		if b_fail_t <= 0.0:
			b_fail_t = -1.0
			m.retry()
			_reset_bot()
			last_hp = _combat().hp
		return
	if m.state != "running" or game_t > MAX_GAME_S:
		_end_run()
		return
	match which[mi]:
		"sneak":
			_bot_sneak()
		"gunfight":
			_bot_gunfight()
		"crates":
			_bot_crates()
		"boss":
			_bot_boss()
	m.advance(DT)


func _end_run() -> void:
	var name: String = which[mi]
	var kos: int = b_kos
	var extra: String = ""
	var info: Dictionary = m.get("won_info") if m.get("won_info") is Dictionary else {}
	if name == "sneak":
		extra = "spotted=%s" % str((m as MissionSneak).spotted)
	elif name == "gunfight":
		extra = "hidden=%s crane_kos=%d" % [str((m as MissionYardGunfight).hidden), (m as MissionYardGunfight).crane.kos_total if (m as MissionYardGunfight).crane else 0]
	elif name == "crates":
		extra = "broken=%d/%d" % [(m as MissionCrates).broken_count(), (m as MissionCrates).total()]
	elif name == "boss":
		extra = "rams=%d crushed=%s" % [(m as MissionForklift).pf.rams if (m as MissionForklift).pf else 0, str((m as MissionForklift).crushed)]
	var done: bool = m.state == "done"
	print("  %s run %d (seed %d): %s fails %d, %.0f s, dmg %.0f, KOs %d, %s %s" % [name, run_i + 1, seed0 + run_i, "done" if done else "TIMEOUT", fails, game_t, dmg, kos, extra, str(info)])
	if not results.has(name):
		results[name] = []
	(results[name] as Array).append([fails, game_t, dmg, kos, done])
	if m.state == "running":
		m.abort()
	else:
		m.queue_free()
	m = null
	_p().controls_enabled = true
	_p().visible = true
	run_i += 1
	if run_i >= runs:
		run_i = 0
		mi += 1
	phase = "gap"
	frames = 0


func _report() -> bool:
	print("=== SIM DAY 3 SUMMARY (%s) ===" % diff)
	for name: String in which:
		var rs: Array = results.get(name, [])
		if rs.is_empty():
			continue
		var fsum: float = 0.0
		var fmax: int = 0
		var tsum: float = 0.0
		var dsum: float = 0.0
		var ksum: float = 0.0
		var done_n: int = 0
		for r: Array in rs:
			fsum += float(r[0])
			fmax = maxi(fmax, int(r[0]))
			tsum += float(r[1])
			dsum += float(r[2])
			ksum += float(r[3])
			done_n += 1 if bool(r[4]) else 0
		var n: float = float(rs.size())
		print("  %s: mean fails %.2f (max %d), time %.0f s, dmg %.0f, KOs %.1f, done %d/%d" % [name, fsum / n, fmax, tsum / n, dsum / n, ksum / n, done_n, rs.size()])
	Difficulty.set_easy(false)
	quit(0)
	return true


# ---------------------------------------------------------------------------
# shared bot pieces
# ---------------------------------------------------------------------------
## Steps toward b_move_to at `speed` m/s (teleports: no footstep noise); true when there.
func _walk(speed: float = 1.8) -> bool:
	if not (b_move_to is Vector3):
		return true
	var p: ThirdPersonController = _p()
	var to: Vector3 = b_move_to
	var d := Vector3(to.x - p.global_position.x, 0.0, to.z - p.global_position.z)
	if d.length() <= speed * DT + 0.05:
		p.teleport(Vector3(to.x, p.global_position.y, to.z), atan2(-d.x, -d.z) if d.length() > 0.01 else p.facing_yaw())
		b_move_to = null
		return true
	var step: Vector3 = d.normalized() * speed * DT
	p.global_position += step
	p.set_facing(atan2(-d.x, -d.z))
	return false


## The abstract shot: one pistol round at gunman g (55 % at 15 m standing, worse farther / moving).
func _shoot(g: Gunman, moving: bool = false) -> void:
	var d: float = WeaponMath.flat(_p().global_position, g.global_position)
	var p: float = clampf(0.55 * 15.0 / maxf(d, 6.0), 0.2, 0.8) * (0.75 if moving else 1.0)
	if g.crouched():
		p *= 0.5
	if rng.randf() < p:
		g.take_hit({"kind": "bullet", "from": _p().global_position})


func _nearest_alive(f: GunFight) -> Gunman:
	var best: Gunman = null
	var bd: float = INF
	for e: Variant in f.alive():
		if e is Gunman:
			var d: float = WeaponMath.flat(_p().global_position, (e as Gunman).global_position)
			if d < bd:
				bd = d
				best = e
	return best


## Cover combat: crouched in a slot that protects from the nearest gunman; pops out 1.0-1.6 s to shoot, ducks on a glint
## it reads (65 %), 15 % stays out too long.
func _cover_fight(f: GunFight) -> void:
	var g: Gunman = _nearest_alive(f)
	if g == null:
		f.cover_ctl.hold_override = null
		(fr.get("weapons") as WeaponDirector).aim_override = null
		return
	var w: WeaponDirector = fr.get("weapons")
	if not f.cover_ctl.in_cover:
		var ids: PackedInt32Array = f.cover.candidates(g.global_position, _p().global_position, 14.0, f.taken, null, 4.0)
		if ids.size() > 0 and b_move_to == null:
			var pick: int = ids[0] if rng.randf() > 0.15 or ids.size() < 2 else ids[1]   # 15 %: a worse slot
			b_move_to = f.cover.pos[pick]
		if b_move_to != null:
			_walk(4.5)
			if b_move_to == null:
				f.cover_ctl.hold_override = true
		else:
			_open_fire(g)
		return
	b_cover_t -= DT
	if b_popped:
		w.aim_override = true
		b_shot_t -= DT
		if b_shot_t <= 0.0:
			b_shot_t = 0.45
			_shoot(g)
		var glint: bool = false
		for e: Variant in f.alive():
			if e is Gunman and (e as Gunman).telegraphing:
				glint = true
		if b_cover_t <= 0.0 or (glint and rng.randf() < 0.65 * DT * 6.0):
			b_popped = false
			b_cover_t = rng.randf_range(0.7, 1.4) + _react()
	else:
		w.aim_override = false
		if b_cover_t <= 0.0:
			b_popped = true
			b_cover_t = rng.randf_range(1.0, 1.6) + (1.5 if rng.randf() < 0.15 else 0.0)


func _open_fire(g: Gunman) -> void:
	b_shot_t -= DT
	if b_shot_t <= 0.0:
		b_shot_t = 0.5
		_shoot(g, false)


# ---------------------------------------------------------------------------
# sneak
# ---------------------------------------------------------------------------
func _leg_clear(ms: MissionYardSneak, a: Vector3, b: Vector3) -> bool:
	var f: GunFight = ms.fight
	for e: Variant in f.alive():
		var g: Gunman = e
		if g.is_alerted:
			continue
		for u: float in [0.5, 1.0]:
			var q: Vector3 = a.lerp(b, u)
			var to := Vector3(q.x - g.global_position.x, 0.0, q.z - g.global_position.z)
			var d: float = to.length()
			if d <= g.patrol_sight_m + 2.0 and (d < 1.0 or g.forward().angle_to(to / d) <= deg_to_rad(g.patrol_fov_deg * 0.5 + 25.0)):
				return false
	for bm: Dictionary in ms.beams:
		for u2: float in [0.25, 0.5, 0.75, 1.0]:
			var q2: Vector3 = a.lerp(b, u2)
			if WeaponMath.flat(q2, bm["p"]) < ms.beam_r + 3.0:
				return false
	return true


func _bot_sneak() -> void:
	var ms: MissionYardSneak = m as MissionYardSneak
	if ms.spotted and not ms.fight.alive().is_empty():
		b_move_to = null
		var ng: Gunman = _nearest_alive(ms.fight)
		if ng:
			_open_fire(ng)
		return
	if b_move_to != null:
		_walk(1.8)
		return
	b_wait -= DT
	if b_wait > 0.0:
		return
	if b_leg >= ROUTE.size() - 1:
		b_move_to = ms.pts["goal"]
		return
	var a: Vector3 = yard.world(ROUTE[b_leg])
	var b: Vector3 = yard.world(ROUTE[b_leg + 1])
	var wrong: bool = rng.randf() < 0.15 * DT * 4.0   # now and then it just goes
	if _leg_clear(ms, a, b) or wrong or b_clear_t > 14.0:
		b_leg += 1
		b_move_to = b
		b_clear_t = 0.0
		b_wait = _react()
	else:
		b_clear_t += DT


# ---------------------------------------------------------------------------
# gunfight
# ---------------------------------------------------------------------------
func _beam_toward_me(mg: MissionYardGunfight) -> bool:
	var me: Vector3 = _p().global_position
	for k: int in MissionYardGunfight.SWEEPERS.size():
		var b: Dictionary = mg.beam_of(k)
		if b.is_empty():
			continue
		var to: Vector3 = me - (b["eye"] as Vector3)
		to.y = 0.0
		if to.length() > mg.sweep_range + 1.0:
			continue
		if (b["dir"] as Vector3).angle_to(to.normalized()) <= deg_to_rad(mg.sweep_half + 20.0):
			return true
	return false


func _bot_gunfight() -> void:
	var mg: MissionYardGunfight = m as MissionYardGunfight
	var f: GunFight = mg.fight
	match mg.hide_state:
		"sweep":
			var toward: bool = _beam_toward_me(mg)
			if toward and not mg.is_frozen() and b_freeze_at < 0.0:
				b_freeze_at = game_t + _react()
			if b_freeze_at >= 0.0 and game_t >= b_freeze_at:
				b_freeze_at = -1.0
				mg.set_frozen(true)
			if not toward:
				b_clear_t += DT
				if b_clear_t > 0.5 and mg.is_frozen():
					mg.set_frozen(false)
			else:
				b_clear_t = 0.0
			return
		"scare":
			return
		"scuffle":
			b_mash_t -= DT
			if b_mash_t <= 0.0:
				b_mash_t = 1.0 / (6.0 if rng.randf() > 0.15 else 3.5)
				mg.mash()
			return
	if mg.crane and mg.crane.usable and b_crane == "" and f.wave >= MissionYardGunfight.CRANE_WAVE and b_crane_wave != f.wave:
		b_crane_wave = f.wave
		b_crane = "go"
		b_move_to = mg.crane.ladder_foot()
		f.cover_ctl.hold_override = null
		f.cover_ctl.leave()
	if b_crane != "" and b_crane != "done":
		_bot_crane(mg.crane, f)
		return
	_cover_fight(f)


func _bot_crane(cr: YardCrane, f: GunFight) -> void:
	match b_crane:
		"go":
			if _walk(4.5):
				if cr.enter(_p()):
					b_crane = "climb"
				else:
					b_crane = "done"
		"climb":
			if cr.in_cabin():
				b_crane = "aim"
				b_wait = _react()
		"aim":
			b_wait -= DT
			if b_wait > 0.0:
				return
			var alive: Array = f.alive()
			if alive.is_empty() or cr.drops_left <= 0 or _combat().hp < 45.0:
				cr.leave()
				b_crane = "done"
				return
			var c := Vector3.ZERO
			for e: Variant in alive:
				c += (e as Node3D).global_position
			c /= float(alive.size())
			c += Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.5, 1.5))
			var l: Vector3 = cr.global_transform.affine_inverse() * c
			b_aim = Vector2(clampf(l.x, YardCrane.X_RANGE.x, YardCrane.X_RANGE.y), clampf(l.z, YardCrane.Z_RANGE.x, YardCrane.Z_RANGE.y))
			b_crane = "move"
		"move":
			var dx: float = b_aim.x - cr.trolley_x
			var dz: float = b_aim.y - cr.gantry_z
			cr.move_override = Vector2(signf(dx) if absf(dx) > 0.1 else 0.0, signf(dz) if absf(dz) > 0.1 else 0.0)
			if absf(dx) <= 0.1 and absf(dz) <= 0.1:
				cr.move_override = Vector2.ZERO
				if cr.drop():
					b_crane = "drop"
		"drop":
			if cr.drop_t < 0.0 and cr.reload_t < 0.0:
				b_crane = "aim"
				b_wait = _react()
			elif cr.drop_t < 0.0 and cr.drops_left <= 0:
				b_crane = "aim"


# ---------------------------------------------------------------------------
# crates
# ---------------------------------------------------------------------------
func _bot_crates() -> void:
	var mc: MissionCrates = m as MissionCrates
	var f: GunFight = mc.fight
	for g: Variant in f.gunmen:
		if is_instance_valid(g) and (g as Gunman).is_alerted and not (g as Gunman).is_defeated() and WeaponMath.flat(_p().global_position, (g as Gunman).global_position) < 16.0:
			_open_fire(g)
			return
	b_shot_t -= DT
	if mc.strap and mc.rack_on and not mc.strap.cut and WeaponMath.flat(_p().global_position, mc.strap.global_position) < 14.0:
		if b_shot_t <= 0.0:
			b_shot_t = 0.5
			if rng.randf() < 0.6:
				mc.strap.take_hit({"kind": "bullet", "from": _p().global_position})
		return
	if mc.carried and not mc.carried.broken and WeaponMath.flat(_p().global_position, mc.carried.global_position) < 15.0:
		if b_shot_t <= 0.0:
			b_shot_t = 0.5
			if rng.randf() < 0.45:
				mc.carried.take_hit({"kind": "bullet", "from": _p().global_position})
		return
	var target: SmartCrate = null
	var bd: float = INF
	for c: Variant in mc.crates:
		var sc: SmartCrate = c
		if sc.broken or (mc.rack_crates.has(sc) and not mc.rack_on):
			continue
		var d: float = WeaponMath.flat(_p().global_position, sc.global_position)
		if d < bd:
			bd = d
			target = sc
	if target == null:
		return
	if bd > 12.0 and b_clear_t < 6.0:
		if b_move_to == null:
			var dir: Vector3 = WeaponMath.flat_dir(_p().global_position - target.global_position)
			b_move_to = target.global_position + dir * 5.0
		b_clear_t += DT
		if _walk(4.5):
			b_clear_t = 0.0
		return
	b_move_to = null
	b_clear_t = 0.0
	if b_shot_t <= 0.0:
		b_shot_t = 0.45
		if rng.randf() < 0.75:
			target.take_hit({"kind": "bullet", "from": _p().global_position})


# ---------------------------------------------------------------------------
# boss
# ---------------------------------------------------------------------------
func _bot_boss() -> void:
	var mf: MissionForklift = m as MissionForklift
	var pf: PlayerForklift = mf.pf
	var b: ForkliftBoss = mf.fight.boss as ForkliftBoss if mf.fight.boss else null
	if pf == null or b == null or b.is_down():
		return
	if not pf.inside:
		if pf.can_enter():
			pf.enter()
		else:
			b_move_to = pf.forklift.global_position
			_walk(4.5)
		return
	var fl: Forklift = pf.forklift
	pf.input_override = {"throttle": 0.0, "steer": 0.0, "fork": 0}
	var me: Vector3 = fl.global_position
	var bp: Vector3 = b.forklift.global_position
	var st: String = b.state_name()
	# charges: steer out late
	if st == "charge_tell" and not b_tell_seen:
		b_tell_seen = true
		b_dodge_at = game_t + _react() + (0.25 if rng.randf() < 0.15 else 0.0)
	if st != "charge_tell" and st != "charge":
		b_tell_seen = false
	if b_dodge_at >= 0.0 and game_t >= b_dodge_at:
		b_dodge_at = -1.0
		var side: Vector3 = b.forklift.global_basis.x * (1.0 if rng.randf() < 0.5 else -1.0)
		b_move_to = me + side * 5.0
	# tosses: move off the shadow
	if b.crates_in_flight() > 0 and b_toss_seen != b.tosses:
		b_toss_seen = b.tosses
		b_toss_at = game_t + _react()
	if b_toss_at >= 0.0 and game_t >= b_toss_at:
		b_toss_at = -1.0
		b_move_to = me + fl.global_basis.x * 3.5
	# rams: the forks go up -> line up on his side and ram (15 % mistimed)
	if b.forks_up() and not b_lift_seen:
		b_lift_seen = true
		var travel: float = maxf(0.0, WeaponMath.flat(me, bp) - 3.5) / PlayerForklift.TOP_SPEED + 0.25   # + the turn in
		b_ram_at = game_t + _react() + travel + (0.6 if rng.randf() < 0.15 else 0.0)   # the drive round to his side
	if not b.forks_up() and st != "lift":
		b_lift_seen = false
	if b_ram_at >= 0.0 and game_t >= b_ram_at:
		b_ram_at = -1.0
		if not b.forks_up():
			return   # too late: the window closed
		var right: Vector3 = b.forklift.global_basis.x * (1.0 if rng.randf() < 0.5 else -1.0)
		var at: Vector3 = bp + right * 3.5
		fl.global_position = Vector3(at.x, fl.floor_y, at.z)
		var to: Vector3 = bp - at
		fl.rotation.y = atan2(-to.x, -to.z)
		fl.speed = 6.0
		pf._ram_cd = 0.0
		pf.input_override = {"throttle": 1.0, "steer": 0.0, "fork": 0}
		return
	if b_move_to != null:
		var to2: Vector3 = (b_move_to as Vector3) - fl.global_position
		to2.y = 0.0
		if to2.length() < 0.3:
			b_move_to = null
		else:
			var stepv: Vector3 = to2.normalized() * minf(6.0 * DT, to2.length())
			fl.global_position += stepv
			fl.speed = 0.0
		return
	# hover about 6 m off his flank (close enough to reach his side while the forks are up)
	var d: float = WeaponMath.flat(me, bp)
	if d < 4.5 or d > 8.0:
		var flank: Vector3 = b.forklift.global_basis.x * (1.0 if (me - bp).dot(b.forklift.global_basis.x) >= 0.0 else -1.0)
		var want: Vector3 = bp + flank * 6.0
		b_move_to = Vector3(want.x, fl.floor_y, want.z)
