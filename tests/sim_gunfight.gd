# File: res://tests/sim_gunfight.gd
# Wave 3 gun tuning harness (plan docs/superpowers/plans/2026-10-30-w3-shared.md T11). Not a regression test: it plays the
# reference gunfight (a neutral yard-like arena of low crates; 3 waves shaped like the Day 3 / Day 5 Thường waves: 3 gunmen
# and a pallet-shield guard; 3 gunmen and a flanker from the left; 4 gunmen, a flanker from the right and a second shield
# guard; the real GunFight, Gunman AI, PlayerCover and BulletTime) with the SLOPPY GUN BOT below, retries from the wave
# checkpoint after every loss (THỬ LẠI) and prints one line per run, its flow (HP at each wave start, each loss with the
# hits taken by bot state; "cover!" = shot while believing it is in cover but out of the slot) and a summary against the
# tuning target.
#
# ===== The sloppy gun bot (the day harnesses copy this model verbatim; no shared helper across parallel branches) =====
#   - every decision (pop out, duck, change cover, reload, dive, a new target) waits a 250-400 ms reaction, +0.3 s when late;
#     its clock is real time (physics frames), so hit-stops and bullet time slow the world, not the bot;
#   - 15 % of the decisions are wrong or late: stays popped out too long (3.5 s), picks a cover that does not protect,
#     flanks the wrong way (the next slot away from the threat), reloads in the open, a dive pressed late;
#   - reads 65 % of the muzzle glints aimed at it (then ducks after its reaction delay, often too late on Thường);
#   - shaky aim, abstracted: one round per pistol cycle (0.25 real s, in a dive too: shots per real second are unchanged)
#     while popped out with a clear line, after the reaction that finds the target (on popping up and on every switch); hit
#     chance about 55 % at 15 m standing (x (15 / d)^0.7, clamped 0.15-0.85), x0.6 while moving, x1.3 inside a dive; a hit
#     is a "bullet" take_hit from its position (the shield guard's pallet blocks it from the front);
#   - 12-round magazine, 1.6 s reload (ducked unless it reloads in the open);
#   - pops out for 1.2-2.0 s, then ducks for 0.8-1.6 s; it moves to the best free slot when its cover stops protecting it:
#     against the mean enemy position, or against a flanker who just shot it while crouched (the new slot must cover him);
#     knocked out of its slot (a dive) it takes the slot again, or walks to one (never snaps in from further than
#     GunData.COVER_ENTER_R);
#   - with "dive": a dive at most once per 20 s, only with full focus and 3+ enemies up (it leaves cover, aims, Space);
#     it waits for the dive to start (BulletTime reads the press on the next frame), then runs back to cover.
#   History: the first version set the bot's timers from the previous run's clock (every run after the first froze the
#   bot in cover for ~100 s, the fake "1 fail per run" of the first tuning notes), set Dễ before GameFX loaded the owner's
#   difficulty (its "easy" runs were Thường), fired 2.9x faster in a dive, lay in the open after a dive believing it was in
#   cover and kept sitting in a flanked slot. Copies in the day harnesses must take these fixes (plan, Integration).
# =================================================================================================================
# Run (fast, no real-time sync):
#   godot --headless --path . --fixed-fps 60 --script tests/sim_gunfight.gd -- normal 1 8 [dive] [states] [acc=K] [regen=S]
#   (difficulty normal | easy, first seed, runs; "dive" lets the bot dive; "states" prints the gunmen's and the bot's time
#   per state; trial knobs: acc = an extra factor on every gunman's hit chance, regen = the regeneration delay in s)
# Target (plan "Tuning target"): Thường a mean of 1-3 fails over 8 seeds, every run done within 5 retries; Dễ at most 1
# fail in every run.
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const DT: float = 1.0 / 60.0
const MAX_FAILS: int = 6
const MAX_S: float = 900.0
const BOXES: Array = [[Vector3(-4.0, 0.5, 0.0)], [Vector3(4.0, 0.5, 0.0)], [Vector3(-9.0, 0.5, -6.0)], [Vector3(0.0, 0.5, -7.0)],
	[Vector3(9.0, 0.5, -6.0)], [Vector3(-6.0, 0.5, -15.0)], [Vector3(6.0, 0.5, -15.0)], [Vector3(0.0, 0.5, -20.0)],
	[Vector3(-12.0, 0.5, -18.0)], [Vector3(12.0, 0.5, -18.0)]]
const BOX_SIZE := Vector3(2.0, 1.0, 0.8)

var diff: String = "normal"
var seed0: int = 1
var runs: int = 8
var use_dive: bool = false
var rng := RandomNumberGenerator.new()
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var combat: PlayerCombat
var targets: Array = []
var fight: GunFight
var results: Array = []
var shot_res: Dictionary = {}     # enemy glints and shot results ("hit", "miss", "blocked") of the current run
var st_time: Dictionary = {}      # "states": seconds per gunman state and per bot state of the current run
# bot state
var b_state: String = "cover"     # cover | pop | move | dive
var b_until: float = 0.0          # when the current state's timer ends
var b_pending: Array = []         # [time, action]
var b_slot: int = -1
var b_mag: int = 12
var b_reload_until: float = -1.0
var b_shot_cd: float = 0.0
var b_last_dive: float = -99.0
var b_dives: int = 0
var b_hits: int = 0
var b_shots: int = 0
var b_hit_from := Vector3.ZERO    # where the last shot that hit it in cover came from
var b_hit_t: float = -99.0
var b_dive_seen: bool = false     # the queued dive really started (BulletTime picks the press up a frame later)
var b_aim_g: Gunman = null        # the target being acquired / held
var b_aim_at: float = 0.0         # first shot at it from this time (a reaction after a pop or a target switch)
var t: float = 0.0


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		diff = a[0]
	if a.size() > 1:
		seed0 = int(a[1])
	if a.size() > 2:
		runs = int(a[2])
	use_dive = a.has("dive")
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	WeaponAudio.sfx_dir = "user://__test_no_sfx__/"
	print("--- SIM GUNFIGHT (%s, seeds %d..%d, dive %s) ---" % [diff, seed0, seed0 + runs - 1, str(use_dive)])
	await process_frame
	Difficulty.set_easy(diff == "easy")      # after the first frame: GameFX (autoload) loads the owner's settings in _ready
	print("gun row: easy %s, telegraph %.2f s, shooters %d, accuracy x%.1f, dmg %.0f, regen %.0f s" % [str(Difficulty.easy),
		GunData.telegraph_s(), GunData.max_shooters(), GunData.accuracy_k(), GunData.gunman_dmg(), GunData.regen_delay()])
	_build()
	for i: int in runs:
		await _run(seed0 + i)
	_summary()
	Difficulty.set_easy(false)
	quit(0)


func _build() -> void:
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena, 400.0)
	for b: Array in BOXES:
		World.wall(arena, b[0], BOX_SIZE)
	player = World.player(arena, Vector3(-4.0, 0.0, 1.0), 0.0)
	dir = World.director(arena, player, targets)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	combat.setup({"player": player, "weapons": dir})


func _waves() -> Array:
	var w1: Array = [_g(-6.0, -22.0), _g(2.0, -24.0), _g(8.0, -21.0), _s(0.0, -23.0)]
	var w2: Array = [_g(-10.0, -22.0), _g(10.0, -22.0), _g(-2.0, -25.0), _g(-16.0, -6.0)]
	var w3: Array = [_g(-12.0, -24.0), _g(-4.0, -25.0), _g(4.0, -25.0), _g(12.0, -24.0), _g(16.0, -6.0), _s(0.0, -24.0)]
	return [w1, w2, w3]


func _s(x: float, z: float) -> Dictionary:
	return {"at": Vector3(x, 0.0, z), "opts": {"alerted": true, "kind": "shield", "accuracy": _arg_f("acc", 1.0)}}


func _g(x: float, z: float) -> Dictionary:
	return {"at": Vector3(x, 0.0, z), "opts": {"alerted": true, "accuracy": _arg_f("acc", 1.0)}}


## A trial knob "name=value" from the command line (default when absent).
func _arg_f(key: String, def: float) -> float:
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with(key + "="):
			return float(s.substr(key.length() + 1))
	return def


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run(sd: int) -> void:
	rng.seed = sd * 7907 + (1 if diff == "easy" else 0)
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
		await _frames(2)
	player.teleport(Vector3(-4.0, 0.0, 1.0), 0.0)
	combat.revive()
	var cm := CoverMap.new()
	for b: Array in BOXES:
		cm.add_box(Transform3D(Basis.IDENTITY, b[0]), BOX_SIZE)
	fight = GunFight.new()
	fight.name = "SimFight"
	arena.add_child(fight)
	fight.setup({"player": player, "weapons": dir, "combat": combat, "cover": cm, "seed": sd})
	for w: Array in _waves():
		fight.add_wave(w)
	var fails_n: int = 0
	var log_w: Array = []                    # "w<i>@<hp>" per wave start, "X<i>" per loss: where the run is hard
	var hit_by: Dictionary = {}
	fight.wave_started.connect(func(i: int) -> void:
		_watch_glints()
		log_w.append("w%d@%.0f" % [i + 1, combat.hp]))
	fight.player_hit.connect(func(src: Node3D, _d: float) -> void:
		var hk: String = b_state + ("!" if b_state == "cover" and not fight.cover_ctl.in_cover else "")
		hit_by[hk] = int(hit_by.get(hk, 0)) + 1
		if b_state == "cover" and is_instance_valid(src):
			b_hit_from = src.global_position     # shot while crouched: that cover does not protect against him
			b_hit_t = t)
	t = 0.0                                  # before _bot_reset: its timers are set from t (a stale t froze the bot in cover)
	b_dives = 0
	b_hits = 0
	b_shots = 0
	b_last_dive = -99.0
	fight.start()
	if _arg_f("regen", -1.0) > 0.0:
		combat.regen_delay = _arg_f("regen", -1.0)
	_bot_reset()
	var start_t: float = 0.0
	var hp_min: float = 100.0
	var shots_at: int = 0
	while t < MAX_S:
		await physics_frame
		t += DT
		if fight.state == "won":
			break
		if fight.state == "lost":
			fails_n += 1
			log_w.append("X%d(%.0fs %s)" % [fight.wave + 1, t, str(hit_by)])
			hit_by.clear()
			if fails_n >= MAX_FAILS:
				break
			await _frames(30)                # the fail card, then THỬ LẠI
			t += 30.0 * DT
			fight.retry()
			_bot_reset()
			continue
		_bot(DT)
		hp_min = minf(hp_min, combat.hp)
		if OS.get_cmdline_user_args().has("states"):
			for e: Variant in fight.alive():
				if e is Gunman:
					var sn: String = (e as Gunman).state_name()
					if sn == "cover" and not (e as Gunman).call("_line_from_standing"):
						sn = "cover_noline"
					st_time[sn] = float(st_time.get(sn, 0.0)) + DT
			var bk: String = "bot_" + b_state + ("_exposed" if fight.cover_ctl.exposed() else "_hidden")
			st_time[bk] = float(st_time.get(bk, 0.0)) + DT
	var won: bool = fight.state == "won"
	for g: Variant in fight.gunmen:
		if is_instance_valid(g):
			shots_at += (g as Gunman).shots
	var r: Dictionary = {"seed": sd, "won": won, "fails": fails_n, "time": t - start_t, "dives": b_dives,
		"acc": float(b_hits) / float(maxi(1, b_shots)), "hp_end": combat.hp, "hp_min": hp_min, "hits": fight.hits_taken}
	results.append(r)
	print("  RUN %s seed %d: %s after %d fails, %.0f s, dives %d, accuracy %.2f, hits taken %d, min hp %.0f, last wave's shots %d" % [diff, sd,
		"WON" if won else "GAVE UP", fails_n, float(r["time"]), b_dives, float(r["acc"]), fight.hits_taken, hp_min, shots_at])
	print("    flow: %s end %s; enemy shots %s" % [" ".join(PackedStringArray(log_w)), str(hit_by), str(shot_res)])
	if not st_time.is_empty():
		var parts: PackedStringArray = []
		for k: String in st_time.keys():
			parts.append("%s %.0f" % [k, float(st_time[k])])
		print("    seconds by state (gunmen summed; bot_*: the bot): %s" % ", ".join(parts))
		st_time.clear()
	shot_res.clear()
	dir.aim_override = false
	player.input_override = null
	fight.cover_ctl.hold_override = null


func _summary() -> void:
	var per: Array[int] = []
	var tot: int = 0
	var all_won: bool = true
	for r: Dictionary in results:
		per.append(int(r["fails"]))
		tot += int(r["fails"])
		all_won = all_won and bool(r["won"])
	var mean: float = float(tot) / float(maxi(1, per.size()))
	var on: bool
	if diff == "easy":
		on = all_won and per.max() <= 1
	else:
		on = all_won and mean >= 1.0 and mean <= 3.0 and per.max() <= 5
	print("SUMMARY gunfight %s dive %s: fails %s mean %.2f, all won %s -> %s" % [diff, str(use_dive), str(per), mean, str(all_won),
		"ON TARGET" if on else "OFF TARGET"])


# ---------------------------------------------------------------------------
# THE SLOPPY GUN BOT
# ---------------------------------------------------------------------------
func _bot_reset() -> void:
	b_pending.clear()
	b_aim_g = null
	b_hit_t = -99.0
	b_mag = 12
	b_reload_until = -1.0
	b_shot_cd = 0.0
	dir.aim_override = false
	player.input_override = null
	player.sprint_override = false
	b_slot = fight.cover.nearest(player.global_position, 2.5)
	fight.cover_ctl.hold_override = true
	if b_slot >= 0:
		fight.cover_ctl.enter(b_slot)
	_set_state("cover", rng.randf_range(0.8, 1.6))


func _react() -> float:
	return rng.randf_range(0.25, 0.4)


func _wrong() -> bool:
	return rng.randf() < 0.15


func _later(action: String, extra: float = 0.0) -> void:
	b_pending.append([t + _react() + extra, action])


func _set_state(s: String, secs: float) -> void:
	b_state = s
	b_until = t + secs


func _watch_glints() -> void:
	for g: Variant in fight.gunmen:
		var gm: Gunman = g
		if not gm.telegraph_started.is_connected(_on_glint):
			gm.telegraph_started.connect(_on_glint)
			gm.shot.connect(_on_enemy_shot)



func _on_enemy_shot(_g: Gunman, result: String) -> void:
	shot_res[result] = int(shot_res.get(result, 0)) + 1


func _on_glint(_g: Gunman) -> void:
	shot_res["glints"] = int(shot_res.get("glints", 0)) + 1
	if b_state == "pop" and rng.randf() < 0.65:
		_later("duck", 0.3 if _wrong() else 0.0)


func _target() -> Gunman:
	var best: Gunman = null
	var bd: float = INF
	var eye: Vector3 = player.global_position + Vector3(0.0, 1.35, 0.0)
	for e: Variant in fight.alive():
		if not (e is Gunman):
			continue
		var gm: Gunman = e
		var d: float = eye.distance_to(gm.feet())
		if gm.has_shield() and gm.front_hit(player.global_position):
			d += 6.0                          # the pallet faces it: another target first
		if d < bd and fight.clear_line(eye, gm.feet() + Vector3(0.0, 1.2 - gm.drop, 0.0)):
			bd = d
			best = gm
	return best


func _threat() -> Vector3:
	var acc := Vector3.ZERO
	var n: int = 0
	for e: Variant in fight.alive():
		acc += (e as Node3D).global_position
		n += 1
	return acc / float(n) if n > 0 else player.global_position + Vector3(0.0, 0.0, -20.0)


func _bot(dt: float) -> void:
	_watch_glints()
	b_shot_cd -= dt
	# pending decisions
	for i: int in range(b_pending.size() - 1, -1, -1):
		var p: Array = b_pending[i]
		if t >= float(p[0]):
			b_pending.remove_at(i)
			_do(String(p[1]))
	if b_reload_until > 0.0 and t >= b_reload_until:
		b_reload_until = -1.0
		b_mag = 12
	match b_state:
		"cover":
			dir.aim_override = false
			if not fight.cover_ctl.in_cover and b_slot >= 0:   # dropped out of the slot (a dive, a knock): take it again
				if fight.cover.pos[b_slot].distance_to(player.global_position) < GunData.COVER_ENTER_R and fight.cover_ctl.can_cover():
					fight.cover_ctl.hold_override = true
					fight.cover_ctl.enter(b_slot)
				elif not _has("move"):
					_later("move")
			if b_slot >= 0 and not _has("move") and (not fight.cover.protects(b_slot, _threat()) or _flanked(b_slot)):
				_later("move")
			if t >= b_until and not _has("pop"):
				_later("pop", 0.3 if _wrong() else 0.0)
				b_until = INF
		"pop":
			dir.aim_override = true
			_shoot(dt, false)
			if t >= b_until and not _has("duck"):
				_later("duck")
				b_until = INF
			if use_dive and t - b_last_dive >= 20.0 and fight.bullet_time and fight.bullet_time.focus >= BulletTime.FOCUS_MAX - 0.01 \
					and fight.alive().size() >= 3 and not _has("dive"):
				_later("dive", 0.3 if _wrong() else 0.0)
		"move":
			dir.aim_override = false
			if b_slot < 0:
				_set_state("cover", 0.5)
				return
			var to: Vector3 = fight.cover.pos[b_slot] - player.global_position
			to.y = 0.0
			if to.length() < 0.9 or t >= b_until:
				player.input_override = null
				player.sprint_override = false
				fight.cover_ctl.hold_override = true
				if to.length() < GunData.COVER_ENTER_R:   # never snaps in from further away (stuck: the cover state re-picks)
					fight.cover_ctl.enter(b_slot)
				_set_state("cover", rng.randf_range(0.6, 1.2))
			else:
				player.yaw = atan2(-to.x, -to.z)
				player.input_override = Vector2(0.0, -1.0)
				player.sprint_override = true
		"dive":
			dir.aim_override = true
			_shoot(dt, true)
			var bt: BulletTime = fight.bullet_time
			if bt != null and bt.state != "idle":
				b_dive_seen = true
			if bt == null or (bt.state == "idle" and (b_dive_seen or t >= b_until - 1.7)):   # over, or refused
				b_slot = _pick_slot(false)
				_set_state("move", 4.0)


func _has(action: String) -> bool:
	for p: Array in b_pending:
		if String(p[1]) == action:
			return true
	return false


func _do(action: String) -> void:
	match action:
		"pop":
			if b_state == "cover":
				var long: bool = _wrong()
				_set_state("pop", 3.5 if long else rng.randf_range(1.2, 2.0))
				b_aim_g = null
		"duck":
			if b_state == "pop":
				_set_state("cover", rng.randf_range(0.8, 1.6))
		"move":
			if b_state == "cover":
				b_slot = _pick_slot(_wrong())
				fight.cover_ctl.hold_override = false
				_set_state("move", 4.0)
		"dive":
			if b_state == "pop" and fight.bullet_time:
				fight.cover_ctl.hold_override = false
				fight.cover_ctl.leave()
				dir.aim_override = true
				player.input_override = null
				player.jump_override = true
				b_last_dive = t
				b_dives += 1
				b_aim_g = null
				b_dive_seen = false
				_set_state("dive", 2.0)


## Hit while crouched in slot i within the last 1.5 s by a shooter that slot does not protect against.
func _flanked(i: int) -> bool:
	return t - b_hit_t < 1.5 and not fight.cover.protects(i, b_hit_from)


## The best free slot that protects against the threat and the last flanker (wrong: one that does not).
func _pick_slot(wrong: bool) -> int:
	var th: Vector3 = _threat()
	var best: int = -1
	var bd: float = INF
	for i: int in fight.cover.count():
		if fight.taken.has(i) and fight.taken[i] != player:
			continue
		var prot: bool = fight.cover.protects(i, th) and not (t - b_hit_t < 3.0 and not fight.cover.protects(i, b_hit_from))
		if prot == wrong:
			continue
		var d: float = fight.cover.pos[i].distance_to(player.global_position)
		if d < bd and d < 14.0:
			bd = d
			best = i
	return best if best >= 0 else b_slot


func _shoot(_dt: float, diving: bool) -> void:
	if b_reload_until > 0.0 or b_shot_cd > 0.0:
		return
	if b_mag <= 0:
		if b_state == "pop" and not _wrong():
			_set_state("cover", 1.7)          # ducks to reload
		b_reload_until = t + 1.6
		return
	var g: Gunman = _target()
	if g == null:
		return
	if g != b_aim_g:                         # a new target (or the first after popping up): a reaction to find it
		b_aim_g = g
		b_aim_at = t + _react() + (0.3 if _wrong() else 0.0)
	if t < b_aim_at:
		return
	b_shot_cd = float(WeaponData.SLOTS[WeaponData.Slot.PISTOL]["cycle"])   # real seconds (the bot's clock), in a dive too
	b_mag -= 1
	b_shots += 1
	var d: float = player.global_position.distance_to(g.feet())
	var p: float = clampf(0.55 * pow(15.0 / maxf(d, 1.0), 0.7), 0.15, 0.85)
	if player.horizontal_speed > 1.0 and not diving:
		p *= 0.6
	if diving:
		p = minf(0.95, p * 1.3)
	if rng.randf() < p:
		b_hits += 1
		g.take_hit({"kind": "bullet", "from": player.global_position})
