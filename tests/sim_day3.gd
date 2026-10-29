# File: res://tests/sim_day3.gd
# Tuning harness for Day 3 (plan 2026-10-30-w3-day3.md T9). Not a regression test: it plays the real yard missions
# (MissionYardSneak, MissionYardGunfight, MissionCrates, MissionForklift on the real LairYard in FreeRoam at night, the
# missions stepped on the fixed frame clock, the GunFight / gunmen / boss on physics frames) with the sloppy bot, retries
# after every fail like THỬ LẠI (from the mission's checkpoint) and prints one line per run plus a summary per mission:
# fails per run, game time, damage taken, knockouts (the par numbers for StoryRank).
# The sloppy gun bot (the shared plan's model, 2026-10-30-w3-shared.md "Sloppy gun bot"): 250-400 ms reaction on every
# decision (+0.3 s when late); 15 % wrong or late (stays popped out too long (3.5 s), picks a cover that does not protect,
# reloads in the open, a prompt pressed late); reads 65 % of the muzzle glints aimed at it (then ducks after its
# reaction, often too late); pops out 1.2-2.0 s, ducks 0.8-1.6 s; finding a target after popping up or switching is a
# decision (the reaction; it keeps its target while he is up and in sight); one round per pistol cycle (0.25 real s, in a
# dive too), hit chance 55 % at 15 m standing (x (15 / d)^0.7, clamped 15-85 %), x0.6 moving, x1.3 in a dive, on the
# gunman's chest (lowered when he crouches; a pallet facing it pushes him back in its choice); 12-round magazine, 1.6 s
# reload (ducked, 15 % in the open); a flanker who shoots it while crouched makes it leave the slot for one that covers
# him; with "dive": a dive at most once per 20 s with full focus and 3+ gunmen up (leaves cover, aims, Space), waits for
# the dive to start, then back to a slot. Its shots are abstract (a hit = Gunman.take_hit "bullet" from the player) but
# need a line of fire (no hit through a box); the gunmen, their tokens, telegraphs, cover rules and damage are the real
# ones. Wave 3 integration: these are the w3-shared T11 fixes (the old copy ducked at once on ~75 % of the glints,
# fired 0.45 s rounds with no reaction and no magazine, ignored flankers); the gun row is printed after GameFX loaded
# the settings, each run prints its RANK, and a time-scale audit runs per mission.
# It changes cover when its slot stops protecting from the nearest gunman (15 %: it stays), and hunts the last ones it
# cannot see (5 s without a line: a walk through the cover slots to one that has a line, as the edge markers would show
# a player). Day 3 additions: freezes 250-400 ms after a flashlight starts toward it (15 % late) and lets go of [X]
# when the legs meter runs low while no light is on it (15 %: misses it); goes up the crane at 60+ HP (15 %: ignores it)
# and aims drops with +-1.5 m error; the sneak: wait points outside both floodlight sweeps, a leg is taken when the
# guards' predicted walk (their patrol points and stops) and the floodlights' known sweep keep it unseen (15 %: it goes
# after 0.5-2 s anyway); crates: 0.8-1.5 s to find the next crate, 0.6-1.0 s to aim, a line of fire, ~80 % at 10 m;
# the joust: it drives the real forklift (PlayerForklift input, the Forklift's acceleration and turning), steers out of
# a charge after its reaction (15 % later), keeps driving under a toss, and rams a stalled / forks-up boss only when the
# turn and the drive to his side fit in the window left (15 %: a bad angle, his front). Moves on foot by stepping
# teleports at walking speed (no footstep noise) with a side step round boxes.
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_day3.gd -- normal 1 8 gunfight [v] [dive]
#   (difficulty normal | easy, first seed, runs, mission sneak | gunfight | crates | boss | all, optional "v": traces,
#   "dive": the bot uses bullet time)
extends SceneTree

const TimeAudit: Script = preload("res://tests/support/time_scale_audit.gd")

const DT: float = 1.0 / 60.0
const MAX_GAME_S: float = 900.0
const MISSIONS: Array[String] = ["sneak", "gunfight", "crates", "boss"]
const BEATS: Dictionary = {"sneak": "d3_sneak", "gunfight": "d3_gunfight", "crates": "d3_crates", "boss": "d3_boss"}
const SCRIPTS: Dictionary = {"sneak": "res://scripts/story/missions/MissionYardSneak.gd",
	"gunfight": "res://scripts/story/missions/MissionYardGunfight.gd", "crates": "res://scripts/story/missions/MissionCrates.gd",
	"boss": "res://scripts/story/missions/MissionForklift.gd"}
const TASKS: Dictionary = {"sneak": "sneak", "gunfight": "gunfight", "crates": "crates", "boss": "forklift"}
## The sneak route (yard-local): wait points the bot holds until the next leg looks clear. Every wait point lies outside
## both floodlight sweeps (A: z 4.6-9.4 from x -21.4 east; B: z -3..1.8 from x -12.4 east): in through the gate, across
## the lane west of the phone guard's view (he faces south), north through the gap beside the west container, behind
## him along the front of the stack to the goal.
const ROUTE: Array[Vector3] = [Vector3(-23.0, 0.0, 8.5), Vector3(-21.5, 0.0, 3.0), Vector3(-19.5, 0.0, -1.0),
	Vector3(-17.2, 0.0, -3.0), Vector3(-17.0, 0.0, -7.5), Vector3(-10.0, 0.0, -7.5), Vector3(-4.5, 0.0, -5.0)]

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
var b_walk_t: float = 0.0
var b_detour: Variant = null
var b_walk_chk: float = 0.0
var b_walk_from: Vector3 = Vector3.ZERO
var b_walk_n: int = 0
var b_cover_chk: float = 0.0
var b_los_chk: float = 0.0
var b_nolos_t: float = 0.0
var b_hunt: bool = false
var b_route: Array = []
var b_was_spotted: bool = false
var b_fought: bool = false
var b_impatient: float = -1.0
var b_target: Node3D = null
var b_aim_t: float = -1.0
var b_search_t: float = 0.0
var b_dodge_to: Variant = null
var b_windows: int = 0
var b_unstick_t: float = 0.0
var b_unstick_steer: float = 1.0
var b_slow_t: float = 0.0
var b_ram_eta: float = -1.0
var verbose: bool = false
var b_legs_seen: int = 0          # 0 not yet, 1 noticed the legs meter (lets go), 2 missed it (the 15 %)
var b_prev_hide: String = ""
var b_prev_frozen: bool = false
var b_prev_tired: float = 0.0
# Wave 3 integration: the shared gun-bot state (timers on game_t, reset with the bot)
var use_dive: bool = false
var g_mag: int = 12
var g_reload_t: float = -1.0
var g_target: Object = null              # the gunman being acquired / held (untyped: he may be freed)
var g_aim_at: float = 0.0
var g_duck_at: float = -1.0              # a glint it read: it ducks at this time
var g_hit_from := Vector3.ZERO           # the last shooter who hit it while crouched
var g_hit_t: float = -99.0
var g_flank_at: float = -1.0             # leaves a flanked slot at this time (its reaction)
var g_fight: GunFight = null             # the fight whose signals are connected
var g_last_dive: float = -99.0
var g_dive: String = ""                  # "" | "queued" | "wait" | "on"
var g_dive_at: float = 0.0
var g_dives: int = 0
var audit: Node = null
var row_printed: bool = false
var g_hunt_chk: float = 3.0
var g_hunt_from: Vector3 = Vector3.ZERO


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
	verbose = a.size() > 4 and a[4] == "v"
	use_dive = a.has("dive")
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
	Difficulty.set_easy(diff == "easy")   # again here: GameFX loads the owner's setting after _initialize
	if OS.get_environment("SIM_GUARD_ACC") != "":
		LairYard.GUARD_ACC = float(OS.get_environment("SIM_GUARD_ACC"))   # tuning trials
	if OS.get_environment("SIM_SNEAK_ACC") != "":
		LairYard.SNEAK_ACC = float(OS.get_environment("SIM_SNEAK_ACC"))
	if not row_printed:
		row_printed = true
		print("yard guards: accuracy x%.2f (sneak x%.2f)" % [LairYard.guard_accuracy(), LairYard.guard_accuracy(true)])
		print("gun row: easy %s, telegraph %.2f s, shooters %d, accuracy x%.1f, dmg %.0f, regen %.0f s, dive %s" % [str(Difficulty.easy),
			GunData.telegraph_s(), GunData.max_shooters(), GunData.accuracy_k(), GunData.gunman_dmg(), GunData.regen_delay(), str(use_dive)])
	if run_i == 0:
		audit = TimeAudit.new()
		root.add_child(audit)
		g_dives = 0
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
	b_windows = 0


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
	b_legs_seen = 0
	b_detour = null
	b_walk_n = 0
	b_walk_t = 0.0
	b_cover_chk = 0.0
	b_nolos_t = 0.0
	b_hunt = false
	b_route = []
	b_impatient = -1.0
	b_fought = false
	b_target = null
	b_aim_t = -1.0
	b_dodge_to = null
	b_unstick_t = 0.0
	b_slow_t = 0.0
	g_mag = 12
	g_reload_t = -1.0
	g_target = null
	g_aim_at = 0.0
	g_duck_at = -1.0
	g_hit_t = -99.0
	g_flank_at = -1.0
	g_last_dive = -99.0
	g_dive = ""
	g_hunt_chk = 3.0
	if fr and _p():
		_p().jump_override = false


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
			if verbose:
				var fw: int = _fight().wave if _fight() else -1
				print("    fail %d at %.0f s: wave %d, hide %s, alive %d, crane %s" % [fails, game_t, fw, str(m.get("hide_state")), _fight().alive().size() if _fight() else 0, b_crane])
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
		var pf0: PlayerForklift = (m as MissionForklift).pf
		var bb: ForkliftBoss = (m as MissionForklift).fight.boss as ForkliftBoss if (m as MissionForklift).fight and (m as MissionForklift).fight.boss else null
		extra = "rams=%d front=%d windows=%d charge_hits=%d crate_hits=%d crushed=%s" % [pf0.rams if pf0 else 0, pf0.front_rams if pf0 else 0, b_windows, pf0.charge_hits if pf0 else 0, bb.crate_hits if bb else -1, str((m as MissionForklift).crushed)]
	var done: bool = m.state == "done"
	var rk: Dictionary = m.rank_eval
	var st: Dictionary = m.stats
	print("  %s run %d (seed %d): %s fails %d, %.0f s, dmg %.0f, KOs %d, dives %d, %s %s | RANK %s %.0f stats{time %.0f dmg %.0f fails %d ko %d}" % [name, run_i + 1,
		seed0 + run_i, "done" if done else "TIMEOUT", fails, game_t, dmg, kos, g_dives, extra, str(info), String(rk.get("letter", "-")),
		float(rk.get("score", 0.0)), float(st.get("time", 0.0)), float(st.get("dmg", 0.0)), int(st.get("fails", 0)), int(st.get("ko", 0))])
	g_dives = 0
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
		if audit:
			print("  %s %s" % [name, String(audit.call("report"))])
			audit.queue_free()
			audit = null
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
## Steps toward b_move_to at `speed` m/s (teleports: no footstep noise); true when there. A blocked straight line (or no
## progress for 0.4 s: the body is pushed back by a box) takes a side step round it first (a detour point 2.5 m aside
## that both ends can walk to).
func _walk(speed: float = 1.8) -> bool:
	if not (b_move_to is Vector3):
		b_detour = null
		return true
	var p: ThirdPersonController = _p()
	var goal: Vector3 = b_move_to
	var f: GunFight = _fight()
	if b_detour == null and f and b_walk_chk <= 0.0:
		b_walk_chk = 0.4
		var moved: float = WeaponMath.flat(p.global_position, b_walk_from)
		b_walk_from = p.global_position
		if (moved < speed * 0.4 * 0.3 and b_walk_n > 0) or not f.clear_walk(p.global_position, goal):
			b_detour = _detour(f, p.global_position, goal)
		b_walk_n += 1
	b_walk_chk -= DT
	var to: Vector3 = b_detour if b_detour is Vector3 else goal
	var d := Vector3(to.x - p.global_position.x, 0.0, to.z - p.global_position.z)
	if d.length() <= speed * DT + 0.05:
		p.teleport(Vector3(to.x, p.global_position.y, to.z), atan2(-d.x, -d.z) if d.length() > 0.01 else p.facing_yaw())
		if b_detour is Vector3:
			b_detour = null
			b_walk_chk = 0.0
			return false
		b_move_to = null
		b_walk_n = 0
		return true
	var step: Vector3 = d.normalized() * speed * DT
	p.global_position += step
	p.set_facing(atan2(-d.x, -d.z))
	return false


func _detour(f: GunFight, at: Vector3, goal: Vector3) -> Variant:
	var fwd: Vector3 = WeaponMath.flat_dir(goal - at)
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var sgn: float = 1.0 if rng.randf() < 0.5 else -1.0
	for k: int in 6:
		var off: float = [2.5, 2.5, 4.0, 4.0, 6.0, 6.0][k] * (sgn if k % 2 == 0 else -sgn)
		var c: Vector3 = at + side * off + fwd * 1.0
		if f.clear_walk(at, c) and f.clear_walk(c, goal):
			return c
	for k2: int in 4:
		var off2: float = [2.5, 4.0, 2.5, 4.0][k2] * (sgn if k2 < 2 else -sgn)
		var c2: Vector3 = at + side * off2
		if f.clear_walk(at, c2):
			return c2
	return null


## The shared sloppy gun bot's shot (w3-shared sim_gunfight): the magazine and the reload, one round per pistol cycle
## (real time), the target-finding reaction, the hit chance on the gunman's chest. Called every frame it may shoot.
func _gun_shoot(f: GunFight, moving: bool = false, diving: bool = false) -> void:
	if f == null:
		return
	_watch(f)
	b_shot_t -= DT
	if g_reload_t >= 0.0:
		if game_t < g_reload_t:
			return
		g_reload_t = -1.0
		g_mag = 12
	if b_shot_t > 0.0:
		return
	if g_mag <= 0:
		if b_popped and rng.randf() >= 0.15:
			b_popped = false                     # ducks to reload (15 %: reloads in the open)
			b_cover_t = 1.7
		g_reload_t = game_t + 1.6
		return
	var eye: Vector3 = _p().global_position + Vector3(0.0, 1.35, 0.0)
	var g: Gunman = (g_target as Gunman) if _holds(f, g_target, eye) else _gun_target(f, eye)
	if g == null:
		return
	if g != g_target:                        # a new target (or the first after popping up): a reaction to find it
		g_target = g
		g_aim_at = game_t + _react()
	if game_t < g_aim_at:
		return
	b_shot_t = float(WeaponData.SLOTS[WeaponData.Slot.PISTOL]["cycle"])
	g_mag -= 1
	var d: float = _p().global_position.distance_to(g.feet())
	var p: float = clampf(0.55 * pow(15.0 / maxf(d, 1.0), 0.7), 0.15, 0.85)
	if moving and not diving:
		p *= 0.6
	if diving:
		p = minf(0.95, p * 1.3)
	if rng.randf() < p:
		g.take_hit({"kind": "bullet", "from": _p().global_position})


## The held target is still up and in sight (untyped: a knocked-out gunman may be freed already).
func _holds(f: GunFight, o: Variant, eye: Vector3) -> bool:
	if o == null or not is_instance_valid(o) or not f.alive().has(o):
		return false
	var g: Gunman = o
	return f.clear_line(eye, g.feet() + Vector3(0.0, 1.2 - g.drop, 0.0))


## The nearest gunman with a clear line to his chest; a pallet facing it pushes him back.
func _gun_target(f: GunFight, eye: Vector3) -> Gunman:
	var best: Gunman = null
	var bd: float = INF
	for e: Variant in f.alive():
		if not (e is Gunman):
			continue
		var gm: Gunman = e
		var d: float = eye.distance_to(gm.feet())
		if gm.has_shield() and gm.front_hit(_p().global_position):
			d += 6.0
		if d < bd and f.clear_line(eye, gm.feet() + Vector3(0.0, 1.2 - gm.drop, 0.0)):
			bd = d
			best = gm
	return best


## The fight's glints and hits reach the bot (connected once per gunman / fight).
func _watch(f: GunFight) -> void:
	if g_fight != f:
		g_fight = f
		if not f.player_hit.is_connected(_on_player_hit):
			f.player_hit.connect(_on_player_hit)
	for e: Variant in f.gunmen:
		if is_instance_valid(e) and not (e as Gunman).telegraph_started.is_connected(_on_glint):
			(e as Gunman).telegraph_started.connect(_on_glint)


## A glint: read 65 % of the time while popped out, then it ducks after its reaction.
func _on_glint(_g: Gunman) -> void:
	if b_popped and g_duck_at < 0.0 and rng.randf() < 0.65:
		g_duck_at = game_t + _react()


## Shot while crouched in a slot: that slot does not protect from him (the flank reaction, after the bot's reaction).
func _on_player_hit(src: Node3D, _d: float) -> void:
	var f: GunFight = _fight()
	if f == null or not is_instance_valid(src) or b_popped or not f.cover_ctl.in_cover:
		return
	g_hit_from = src.global_position
	g_hit_t = game_t
	if f.cover_ctl.slot >= 0 and not f.cover.protects(f.cover_ctl.slot, g_hit_from) and g_flank_at < 0.0:
		g_flank_at = game_t + _react()


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
	# hunting: no gunman in sight for a while (the last ones behind boxes): go after the nearest (the markers show him)
	b_los_chk -= DT
	if b_los_chk <= 0.0:
		b_los_chk = 0.5
		var any: bool = false
		for e: Variant in f.alive():
			if e is Gunman and _los(f, e):
				any = true
				break
		b_nolos_t = 0.0 if any else b_nolos_t + 0.5
		if any and b_hunt:
			b_hunt = false
			b_move_to = null
			b_route.clear()
	if not b_hunt and b_nolos_t > 5.0 + _react():
		b_hunt = true
		b_route.clear()
		b_move_to = null
		f.cover_ctl.hold_override = false
		w.aim_override = false
		b_popped = false
	if b_hunt:
		if b_route.is_empty():
			b_route = _hunt_route(f, g)
			if b_route.is_empty():
				b_route = [g.global_position]
		if b_move_to == null:
			b_move_to = b_route[0]
		# wave3: a hunt that makes no progress for 3 s (the route's first point behind a box with no side step) tries a
		# walkable slot nearby first (it stood still for 280 s at the end of a run before: a TIMEOUT)
		g_hunt_chk -= DT
		if g_hunt_chk <= 0.0:
			g_hunt_chk = 3.0
			var here: Vector3 = _p().global_position
			if WeaponMath.flat(here, g_hunt_from) < 0.5:
				var opts: Array = []
				for i: int in f.cover.pos.size():
					var q: Vector3 = f.cover.pos[i]
					var dq: float = WeaponMath.flat(q, here)
					if dq > 2.0 and dq < 12.0 and f.clear_walk(here, q):
						opts.append(q)
				if not opts.is_empty():
					b_route = [opts[rng.randi() % opts.size()]]
					b_move_to = b_route[0]
					b_detour = null
			g_hunt_from = here
		if _walk(3.5):
			b_route.remove_at(0)
			if b_route.is_empty():
				b_hunt = false    # there: back to the cover fight (a new slot facing him)
				b_nolos_t = 0.0
		return
	if g_dive != "" and g_dive != "queued":
		_dive_tick(f, w)
		return
	if not f.cover_ctl.in_cover:
		var threat: Vector3 = g_hit_from if game_t - g_hit_t < 3.0 else g.global_position   # a fresh flanker first
		var ids: PackedInt32Array = f.cover.candidates(threat, _p().global_position, 14.0, f.taken, null, 4.0)
		if ids.size() > 0 and b_move_to == null and b_walk_t >= 0.0:
			var ok: Array[int] = []
			for i: int in ids:
				if f.clear_walk(_p().global_position + Vector3(0.0, 0.5, 0.0), f.cover.pos[i] + Vector3(0.0, 0.5, 0.0)):
					ok.append(i)
					if ok.size() >= 2:
						break
			if not ok.is_empty():
				var pick: int = ok[0] if rng.randf() > 0.15 or ok.size() < 2 else ok[1]   # 15 %: a worse slot
				b_move_to = f.cover.pos[pick]
		if b_move_to != null and WeaponMath.flat(_p().global_position, b_move_to) > 0.6 and b_walk_t < 3.0:
			b_walk_t += DT
			_walk(4.5)
			if b_move_to == null:
				f.cover_ctl.hold_override = true
		else:
			if b_walk_t >= 3.0:
				b_walk_t = -4.0   # stuck on the way: fight from here a while before trying a slot again
			b_walk_t = minf(b_walk_t + DT, 0.0) if b_walk_t < 0.0 else 0.0
			b_move_to = null
			f.cover_ctl.hold_override = true
			_open_fire(g)   # no slot (or the slot did not take): shoots from where it stands
		return
	b_cover_t -= DT
	if g_flank_at >= 0.0 and game_t >= g_flank_at:
		g_flank_at = -1.0
		if not b_popped and f.cover_ctl.slot >= 0 and not f.cover.protects(f.cover_ctl.slot, g_hit_from):
			f.cover_ctl.hold_override = false    # flanked: off to a slot that covers him (the not-in-cover branch)
			w.aim_override = false
			b_walk_t = 0.0
			return
	# the slot no longer protects from the nearest gunman (he moved, a new wave on another side): move (15 %: stays)
	b_cover_chk -= DT
	if b_cover_chk <= 0.0:
		b_cover_chk = 1.0 + _react()
		if f.cover_ctl.slot >= 0 and not f.cover.protects(f.cover_ctl.slot, g.global_position) and rng.randf() < 0.85:
			f.cover_ctl.hold_override = false
			w.aim_override = false
			b_popped = false
			b_walk_t = 0.0
			return
	if b_popped:
		w.aim_override = true
		_gun_shoot(f)
		if not b_popped:
			return                               # ducked to reload
		if (g_duck_at >= 0.0 and game_t >= g_duck_at) or b_cover_t <= 0.0:
			b_popped = false
			g_duck_at = -1.0
			if g_dive == "queued":
				g_dive = ""
			b_cover_t = rng.randf_range(0.8, 1.6) + _react()
			return
		if use_dive and g_dive == "" and game_t - g_last_dive >= 20.0 and f.bullet_time and f.bullet_time.enabled \
				and f.bullet_time.focus >= BulletTime.FOCUS_MAX - 0.01 and f.alive().size() >= 3:
			g_dive = "queued"
			g_dive_at = game_t + _react()
		if g_dive == "queued" and game_t >= g_dive_at:
			f.cover_ctl.hold_override = false
			f.cover_ctl.leave()
			w.aim_override = true
			_p().jump_override = true
			g_last_dive = game_t
			g_dive_at = game_t
			g_dives += 1
			g_target = null
			g_dive = "wait"
	else:
		w.aim_override = false
		if b_cover_t <= 0.0:
			b_popped = true
			g_target = null
			g_duck_at = -1.0
			b_cover_t = 3.5 if rng.randf() < 0.15 else rng.randf_range(1.2, 2.0)


## A dive running: it aims and fires (real-time cadence); once BulletTime is idle again (or refused the press), back to a
## slot (the not-in-cover branch walks to one that protects).
func _dive_tick(f: GunFight, w: WeaponDirector) -> void:
	w.aim_override = true
	_gun_shoot(f, false, true)
	var bt: BulletTime = f.bullet_time
	if bt != null and bt.state != "idle":
		g_dive = "on"
	if bt == null or (bt.state == "idle" and (g_dive == "on" or game_t - g_dive_at > 0.3)):
		g_dive = ""
		b_popped = false
		b_cover_t = 0.4
		b_move_to = null
		b_walk_t = 0.0


## A walk from `from` to `to`: straight, or through one or two cover slots when a box is in the way.
func _route(f: GunFight, from: Vector3, to: Vector3) -> Array:
	if f.clear_walk(from, to):
		return [to]
	var best: Array = []
	var bd: float = INF
	for i: int in f.cover.pos.size():
		var mid: Vector3 = f.cover.pos[i]
		if f.clear_walk(from, mid) and f.clear_walk(mid, to):
			var d: float = WeaponMath.flat(from, mid) + WeaponMath.flat(mid, to)
			if d < bd:
				bd = d
				best = [mid, to]
	if not best.is_empty():
		return best
	for i2: int in f.cover.pos.size():
		var m1: Vector3 = f.cover.pos[i2]
		if not f.clear_walk(from, m1):
			continue
		for j: int in f.cover.pos.size():
			var m2: Vector3 = f.cover.pos[j]
			if f.clear_walk(m1, m2) and f.clear_walk(m2, to):
				return [m1, m2, to]
	return [to]


## A walk (1 or 2 straight legs through the cover slots) to the nearest slot with a line of fire on g; [] = none found.
func _hunt_route(f: GunFight, g: Gunman) -> Array:
	var me: Vector3 = _p().global_position
	var tp: Vector3 = g.feet() + Vector3(0.0, 1.2, 0.0)
	var goals: Array = []
	for i: int in f.cover.pos.size():
		var q: Vector3 = f.cover.pos[i]
		if WeaponMath.flat(q, g.global_position) < 4.0:
			continue
		if f.clear_line(q + Vector3(0.0, 1.4, 0.0), tp):
			goals.append([WeaponMath.flat(q, me), q])
	goals.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for gl: Array in goals.slice(0, 8):
		var q2: Vector3 = gl[1]
		if f.clear_walk(me, q2):
			return [q2]
		for j: int in f.cover.pos.size():
			var mid: Vector3 = f.cover.pos[j]
			if f.clear_walk(me, mid) and f.clear_walk(mid, q2):
				return [mid, q2]
	return []


func _los(f: GunFight, g: Gunman) -> bool:
	return f.clear_line(_p().global_position + Vector3(0.0, 1.4, 0.0), g.feet() + Vector3(0.0, 0.9 if g.crouched() else 1.3, 0.0))


func _open_fire(_g: Gunman) -> void:
	_gun_shoot(_fight(), false)   # the shared bot's shot (its own target choice: the nearest in sight)


# ---------------------------------------------------------------------------
# sneak
# ---------------------------------------------------------------------------
func _leg_clear(ms: MissionYardSneak, a: Vector3, b: Vector3) -> bool:
	var f: GunFight = ms.fight
	var walk_s: float = WeaponMath.flat(a, b) / 1.8 + 0.6
	var hold_s: float = 2.5      # it stands at b a moment before the next leg
	for e: Variant in f.alive():
		var g: Gunman = e
		if g.is_alerted or not g.ai:
			continue
		var track: Array = _predict_guard(g, walk_s + hold_s)
		for k: int in track.size():
			var tau: float = 0.25 * float(k)
			var q: Vector3 = a.lerp(b, clampf(tau / maxf(walk_s - 0.6, 0.1), 0.0, 1.0))
			var gp: Vector3 = track[k][0]
			var to := Vector3(q.x - gp.x, 0.0, q.z - gp.z)
			var d: float = to.length()
			if d > g.patrol_sight_m + 1.5:
				continue
			if d > 1.0 and (track[k][1] as Vector3).angle_to(to / d) > deg_to_rad(g.patrol_fov_deg * 0.5 + 10.0):
				continue
			if f.clear_line(gp + Vector3(0.0, 1.6, 0.0), q + Vector3(0.0, 1.0, 0.0)):
				return false
	# the floodlights: where each disc will be while the bot walks this leg (their sweep is a known back-and-forth)
	for bm: Dictionary in ms.beams:
		var tau: float = 0.0
		while tau <= walk_s:
			var q2: Vector3 = a.lerp(b, clampf(tau / maxf(walk_s - 0.6, 0.1), 0.0, 1.0))
			var t: float = float(bm["t"]) + tau
			var bp: Vector3 = (bm["a"] as Vector3).lerp(bm["b"], 0.5 - 0.5 * cos(PI * t / ms.sweep_s))
			if WeaponMath.flat(q2, bp) < ms.beam_r + 0.8 and f.clear_line(bm["lamp"], q2 + Vector3(0.0, 1.0, 0.0)):
				return false
			tau += 0.2
	return true


## Guard g's predicted [position, forward] every 0.25 s for `secs`: a patrol walks its points at WALK_SPEED with a 1.2 s
## stop at each; a standing guard looks around (Gunman._do_patrol's yaw swing).
func _predict_guard(g: Gunman, secs: float) -> Array:
	var out: Array = []
	var pos: Vector3 = g.global_position
	var yaw: float = g.yaw
	var fwd: Vector3 = g.forward()
	var pts: PackedVector3Array = g.patrol
	var i: int = int(g.get("_patrol_i"))
	var wait: float = float(g.get("_wait"))
	var st0: float = g.st_t
	var t: float = 0.0
	var dt: float = 0.25
	while t <= secs:
		out.append([pos, fwd])
		if pts.is_empty():
			yaw += 0.6 * sin(0.8 * (st0 + t)) * dt
			fwd = Vector3(-sin(yaw), 0.0, -cos(yaw))
		elif wait > 0.0:
			wait -= dt
		else:
			var tgt: Vector3 = pts[i % pts.size()]
			var d := Vector3(tgt.x - pos.x, 0.0, tgt.z - pos.z)
			var l: float = d.length()
			if l <= GunData.WALK_SPEED * dt:
				pos = Vector3(tgt.x, pos.y, tgt.z)
				if l > 0.01:
					fwd = d / l
				wait = 1.2
				i = (i + 1) % pts.size()
			else:
				fwd = d / l
				pos += fwd * GunData.WALK_SPEED * dt
		t += dt
	return out


func _bot_sneak() -> void:
	var ms: MissionYardSneak = m as MissionYardSneak
	if verbose and ms.clock < DT * 1.5:
		for k: int in ROUTE.size() - 1:
			var ra: Vector3 = yard.world(ROUTE[k]) + Vector3(0.0, 0.5, 0.0)
			var rb: Vector3 = yard.world(ROUTE[k + 1]) + Vector3(0.0, 0.5, 0.0)
			var h: Dictionary = ms.fight.ray(ra, rb)
			var h2: Dictionary = ms.fight.ray(ra + Vector3(0.0, 0.7, 0.0), rb + Vector3(0.0, 0.7, 0.0))
			print("    leg %d walk %s: %s / %s" % [k, str(ms.fight.clear_walk(ra - Vector3(0.0, 0.5, 0.0), rb - Vector3(0.0, 0.5, 0.0))),
				str(h.get("collider").get_path()) + " at " + str(yard.global_transform.affine_inverse() * (h["position"] as Vector3)) if not h.is_empty() else "-",
				str(h2.get("collider").get_path()) if not h2.is_empty() else "-"])
	if verbose and ms.spotted and not b_was_spotted:
		var lp: Vector3 = yard.global_transform.affine_inverse() * _p().global_position
		var who: String = ""
		for k: int in ms.fight.gunmen.size():
			var gk: Gunman = ms.fight.gunmen[k]
			if is_instance_valid(gk) and gk.sees:
				who += " g%d(%s)" % [k, "sleeper" if gk == ms.sleeper else ("phone" if gk == ms.phone_guard else "patrol")]
		print("    spotted at %.1f s: leg %d at (%.1f, %.1f) flood %s seen by%s" % [ms.clock, b_leg, lp.x, lp.z, str(ms.flood_spotted), who])
	b_was_spotted = ms.spotted
	if ms.spotted and not ms.fight.alive().is_empty():
		_cover_fight(ms.fight)   # the early fight: the same cover fight as the gunfight
		b_fought = true
		return
	if b_fought:
		b_fought = false
		_cover_fight(ms.fight)   # nobody left: releases the cover and the aim
		b_move_to = null
		b_leg = ROUTE.size() - 1   # after the fight: straight to the goal
		b_wait = _react()
	if b_move_to != null:
		b_walk_t += DT
		if b_walk_t > 12.0 and b_leg >= ROUTE.size() - 1:
			b_walk_t = 0.0
			b_route = _route(ms.fight, _p().global_position, ms.pts["goal"])   # stuck on the way: a new route from here
			b_move_to = b_route[0]
		if _walk(1.8):
			b_walk_t = 0.0
			if not b_route.is_empty():
				b_route.remove_at(0)
				if not b_route.is_empty():
					b_move_to = b_route[0]
		return
	b_wait -= DT
	if b_wait > 0.0:
		return
	if b_leg >= ROUTE.size() - 1:
		b_route = _route(ms.fight, _p().global_position, ms.pts["goal"])
		b_move_to = b_route[0]
		return
	var a: Vector3 = yard.world(ROUTE[b_leg])
	var b: Vector3 = yard.world(ROUTE[b_leg + 1])
	if b_impatient < 0.0:
		b_impatient = rng.randf_range(0.5, 2.0) if rng.randf() < 0.15 else 99.0   # the 15 %: goes without a good look
	if _leg_clear(ms, a, b) or b_clear_t > minf(14.0, b_impatient):
		b_leg += 1
		b_move_to = b
		b_clear_t = 0.0
		b_impatient = -1.0
		b_wait = _react()
	else:
		b_clear_t += DT


# ---------------------------------------------------------------------------
# gunfight
# ---------------------------------------------------------------------------
func _beam_toward_me(mg: MissionYardGunfight, margin_deg: float = 20.0) -> bool:
	var me: Vector3 = _p().global_position
	for k: int in MissionYardGunfight.SWEEPERS.size():
		var b: Dictionary = mg.beam_of(k)
		if b.is_empty():
			continue
		var to: Vector3 = me - (b["eye"] as Vector3)
		to.y = 0.0
		if to.length() > mg.sweep_range + 1.0:
			continue
		if (b["dir"] as Vector3).angle_to(to.normalized()) <= deg_to_rad(mg.sweep_half + margin_deg):
			return true
	return false


func _bot_gunfight() -> void:
	var mg: MissionYardGunfight = m as MissionYardGunfight
	var f: GunFight = mg.fight
	if verbose and b_prev_hide == "sweep" and mg.hide_state == "caught":
		var why: String = ""
		for k: int in mini(3, f.gunmen.size()):
			var gk: Gunman = f.gunmen[k]
			if is_instance_valid(gk) and (gk.is_alerted or gk.is_defeated()):
				why += " g%d-alert" % k
		print("    caught at hide_t %.1f: was frozen %s tired %.2f speed %.2f%s" % [mg.hide_t, str(b_prev_frozen), b_prev_tired, _p().horizontal_speed, why])
	b_prev_hide = mg.hide_state
	b_prev_frozen = mg.is_frozen()
	b_prev_tired = mg.tired_t
	if verbose and mg.hide_state != "sweep" and int(game_t * 60.0) % 120 == 0:
		var lp: Vector3 = yard.global_transform.affine_inverse() * _p().global_position
		var ng: Gunman = _nearest_alive(f)
		print("      t %.0f w%d hp %.0f at (%.1f, %.1f) cover %s popped %s move %s walk %.1f alive %d shooters %d near %.1f crane %s" % [game_t, f.wave, _combat().hp, lp.x, lp.z, str(f.cover_ctl.in_cover), str(b_popped), str(b_move_to != null), b_walk_t, f.alive().size(), f.shooters(), WeaponMath.flat(_p().global_position, ng.global_position) if ng else -1.0, b_crane])
	match mg.hide_state:
		"sweep":
			var toward: bool = _beam_toward_me(mg)
			if toward and not mg.is_frozen() and b_freeze_at < 0.0:
				b_freeze_at = game_t + _react()
			if b_freeze_at >= 0.0 and game_t >= b_freeze_at:
				b_freeze_at = -1.0
				mg.set_frozen(true)
			# the legs meter runs low: let go of [X] for a moment while no light is on it (15 %: it does not notice)
			if mg.is_frozen() and mg.legs_left() < 0.25 and not _beam_toward_me(mg, 4.0):
				if b_legs_seen == 0:
					b_legs_seen = 1 if rng.randf() < 0.85 else 2
				if b_legs_seen == 1:
					mg.set_frozen(false)
					b_freeze_at = -1.0
			if not mg.is_frozen() and mg.legs_left() > 0.9:
				b_legs_seen = 0
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
	if mg.crane and mg.crane.usable and b_crane == "" and f.wave >= MissionYardGunfight.CRANE_WAVE and b_crane_wave != f.wave and _combat().hp >= 60.0:
		b_crane_wave = f.wave
		if rng.randf() < 0.15:
			b_crane = "done"    # the 15 %: ignores the crane this time
		else:
			b_crane = "go"
			b_walk_t = 0.0
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
			b_walk_t += DT
			if b_walk_t > 6.0:
				b_crane = "done"    # could not get to the ladder: back to the cover fight
				b_move_to = null
				b_walk_t = 0.0
				return
			if _walk(4.5):
				b_walk_t = 0.0
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
		if is_instance_valid(g) and (g as Gunman).is_alerted and not (g as Gunman).is_defeated() and WeaponMath.flat(_p().global_position, (g as Gunman).global_position) < 16.0 and _los(f, g):
			b_move_to = null
			_open_fire(g)
			return
	# the target: the strap while the rack is up (one shot, three crates), the carried crate when near, else the nearest
	var target: Node3D = null
	if mc.strap and mc.rack_on and not mc.strap.cut and WeaponMath.flat(_p().global_position, mc.strap.global_position) < 16.0:
		target = mc.strap
	elif mc.carried and not mc.carried.broken and WeaponMath.flat(_p().global_position, mc.carried.global_position) < 14.0:
		target = mc.carried
	else:
		var bd: float = INF
		for c: Variant in mc.crates:
			var sc: SmartCrate = c
			if sc.broken or (mc.rack_crates.has(sc) and not mc.rack_on):
				continue
			var d: float = WeaponMath.flat(_p().global_position, sc.global_position)
			if d < bd:
				bd = d
				target = sc
		if target == null and mc.carried and not mc.carried.broken:
			target = mc.carried
	if target == null:
		return
	var aim_at: Vector3 = target.global_position + Vector3(0.0, 1.6 if target == mc.strap else (0.0 if target == mc.carried else 0.5), 0.0)
	var dist: float = WeaponMath.flat(_p().global_position, target.global_position)
	var hit: Dictionary = f.ray(_p().global_position + Vector3(0.0, 1.4, 0.0), aim_at)
	var seen: bool = hit.is_empty() or (hit.get("collider") is Node and (target == hit["collider"] or target.is_ancestor_of(hit["collider"])))
	if verbose and int(game_t * 60.0) % 60 == 0 and (dist > 12.0 or not seen):
		print("      t %.0f hp %.0f walk to %s d %.1f seen %s hit %s" % [game_t, _combat().hp, target.name, dist, str(seen), str(hit.get("collider").get_path()) if not hit.is_empty() else "-"])
	if dist > 12.0 or not seen:
		# walk toward it (a spot 5 m short of it, through the cover slots when a box is in the way)
		if b_target != target:
			b_target = target
			b_move_to = null
			b_search_t = rng.randf_range(0.8, 1.5) + (0.5 if rng.randf() < 0.15 else 0.0)   # finding the next one
		if b_search_t > 0.0:
			b_search_t -= DT
			return
		if b_move_to == null or b_walk_t > 8.0:
			b_walk_t = 0.0
			var dir: Vector3 = WeaponMath.flat_dir(_p().global_position - target.global_position)
			b_route = _route(f, _p().global_position, target.global_position + dir * (5.0 if seen else 2.5))
			b_move_to = b_route[0]
		b_walk_t += DT
		if _walk(4.5):
			b_route.remove_at(0) if not b_route.is_empty() else null
			if not b_route.is_empty():
				b_move_to = b_route[0]
		b_aim_t = -1.0
		return
	if verbose and int(game_t * 60.0) % 60 == 0:
		print("      t %.0f hp %.0f target %s d %.1f seen %s aim %.2f" % [game_t, _combat().hp, target.name, dist, str(seen), b_aim_t])
	b_move_to = null
	b_route.clear()
	# aim: turning onto a new target takes 0.6-1.0 s (+0.3 late 15 %), then a shot every 0.45 s
	if b_target != target or b_aim_t < 0.0:
		b_target = target
		b_aim_t = rng.randf_range(0.6, 1.0) + (0.3 if rng.randf() < 0.15 else 0.0)
	if b_aim_t > 0.0:
		b_aim_t = maxf(b_aim_t - DT, 0.0)
		return
	b_shot_t -= DT
	if b_shot_t <= 0.0:
		b_shot_t = 0.45
		var hit_p: float = clampf(0.8 * 10.0 / maxf(dist, 4.0), 0.3, 0.85) * (0.6 if target == mc.carried or target == mc.strap else 1.0)
		if rng.randf() < hit_p:
			(target as Object).call("take_hit", {"kind": "bullet", "from": _p().global_position})


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
		if verbose and int(game_t * 60.0) % 60 == 0:
			print("      t %.0f on foot: d to forklift %.1f can_enter %s" % [game_t, WeaponMath.flat(_p().global_position, pf.forklift.global_position), str(pf.can_enter())])
		if pf.can_enter():
			pf.enter()
		else:
			b_move_to = pf.forklift.global_position + WeaponMath.flat_dir(_p().global_position - pf.forklift.global_position) * 1.5
			_walk(4.5)
		return
	# it drives the real forklift (PlayerForklift input: throttle / steer, the Forklift's own acceleration and turning)
	var fl: Forklift = pf.forklift
	var me: Vector3 = fl.global_position
	var bp: Vector3 = b.forklift.global_position
	var st: String = b.state_name()
	if verbose and int(game_t * 60.0) % 60 == 0:
		var lp: Vector3 = yard.global_transform.affine_inverse() * me
		var lb: Vector3 = yard.global_transform.affine_inverse() * bp
		print("      t %.0f hp %.0f me (%.1f, %.1f) v %.1f boss (%.1f, %.1f) %s d %.1f in %s bhp %.0f" % [game_t, _combat().hp, lp.x, lp.z, fl.speed, lb.x, lb.z, st, WeaponMath.flat(me, bp), str(pf.input_override), b.hp])
	# charges: steer out late (the reaction, 15 % later still)
	if st == "charge_tell" and not b_tell_seen:
		b_tell_seen = true
		b_dodge_at = game_t + _react() + (0.25 if rng.randf() < 0.15 else 0.0)
	if st != "charge_tell" and st != "charge":
		b_tell_seen = false
		b_dodge_to = null
	if b_dodge_at >= 0.0 and game_t >= b_dodge_at:
		b_dodge_at = -1.0
		var away: Vector3 = WeaponMath.flat_dir(me - bp)
		var perp := Vector3(-away.z, 0.0, away.x)
		if perp.dot(fl.forward()) < 0.0:
			perp = -perp      # the side it is already facing: no big turn
		b_dodge_to = me + perp * 8.0
	# stuck against a box or a fence (throttle on, barely moving): back out with the wheel the other way
	if b_unstick_t > 0.0:
		b_unstick_t -= DT
		pf.input_override = {"throttle": -0.8, "steer": b_unstick_steer, "fork": 0}
		return
	if absf(fl.speed) < 1.0 and pf.input_override is Dictionary and absf(float((pf.input_override as Dictionary).get("throttle", 0.0))) > 0.4:
		b_slow_t += DT
		if b_slow_t > 1.2:
			b_slow_t = 0.0
			b_unstick_t = 0.9
			b_unstick_steer = -signf(float((pf.input_override as Dictionary).get("steer", 1.0)) + 0.01)
			return
	else:
		b_slow_t = 0.0
	if b_dodge_to is Vector3:
		pf.input_override = _drive(fl, b_dodge_to)
		return
	# his crate in the air (aimed where it stood): keep driving, it lands behind (after the reaction)
	if b.crates_in_flight() > 0 and b_toss_seen != b.tosses:
		b_toss_seen = b.tosses
		b_toss_at = game_t + _react()
	if b_toss_at >= 0.0 and game_t >= b_toss_at and b.crates_in_flight() > 0:
		pf.input_override = _drive(fl, me + fl.forward() * 8.0)
		return
	if b.crates_in_flight() == 0:
		b_toss_at = -1.0
	# rams: his forks up or he is stalled -> line up on his side (4 m out), then straight into his flank (15 % mistimed:
	# a late start)
	var open: bool = b.ram_open()
	if open and not b_lift_seen:
		b_lift_seen = true
		b_windows += 1
		b_ram_at = game_t + _react() + (0.6 if rng.randf() < 0.15 else 0.0)
	if not open:
		b_lift_seen = false
		b_ram_at = -1.0
		b_ram_eta = -1.0
	if b_ram_at >= 0.0 and game_t >= b_ram_at and open:
		var bx: Vector3 = b.forklift.global_basis.x
		var side: Vector3 = bx * (1.0 if (me - bp).dot(bx) >= 0.0 else -1.0)
		var entry: Vector3 = bp + side * 3.5
		if b_ram_eta < 0.0:
			# the time a forklift needs from here: the turn (1.8 rad/s) and the drive to his side (from its speed now)
			var to_e: Vector3 = WeaponMath.flat_dir(entry - me)
			var ang: float = absf(fl.forward().signed_angle_to(to_e, Vector3.UP))
			var need: float = ang / Forklift.TURN_RATE + WeaponMath.flat(me, entry) / maxf(absf(fl.speed) + 2.0, 4.0)
			var left: float = (b.lift_s() if st == "lift" else (GunData.OVERHEAT_S if st == "overheat" else b.st_len)) - b.st_t
			b_ram_eta = game_t + need if need <= left else INF
		if game_t < b_ram_eta:
			pf.input_override = _drive(fl, entry)
			return
		# there: the ram (15 %: a bad angle, his front: both bounce and it hurts)
		var at: Vector3 = entry if rng.randf() > 0.15 else bp + b.forklift.forward() * 3.5
		fl.global_position = Vector3(at.x, fl.floor_y, at.z)
		var to: Vector3 = bp - at
		fl.rotation.y = atan2(-to.x, -to.z)
		fl.speed = 6.0
		pf._ram_cd = 0.0
		pf.input_override = {"throttle": 1.0, "steer": 0.0, "fork": 0}
		b_ram_at = -1.0
		b_ram_eta = -1.0
		return
	# otherwise circle him at 8-10 m on his flank, always moving (a forklift that stands still is a target)
	var flank: Vector3 = b.forklift.global_basis.x * (1.0 if (me - bp).dot(b.forklift.global_basis.x) >= 0.0 else -1.0)
	var around: Vector3 = bp + (flank * 0.8 + WeaponMath.flat_dir(me - bp) * 0.6).normalized() * 9.0
	pf.input_override = _drive(fl, around, 0.7)


## Throttle / steer toward a floor point (left positive steer, as PlayerForklift reads WASD); backs up when it is right
## behind and close.
func _drive(fl: Forklift, target: Vector3, max_th: float = 1.0) -> Dictionary:
	var to: Vector3 = target - fl.global_position
	to.y = 0.0
	var dist: float = to.length()
	if dist < 0.8:
		return {"throttle": 0.0, "steer": 0.0, "fork": 0}
	var ang: float = fl.forward().signed_angle_to(to / dist, Vector3.UP)
	var steer: float = clampf(ang * 2.0, -1.0, 1.0)
	var th: float = max_th
	if absf(ang) > 2.4 and dist < 5.0:
		return {"throttle": -0.7, "steer": -steer, "fork": 0}
	if absf(ang) > 1.2:
		th = minf(th, 0.55)
	return {"throttle": th, "steer": steer, "fork": 0}
