# File: res://scripts/combat/guns/GunFight.gd
# Encounter node of the Phase C lair gunfights (spec C-D2) and the Day 3 forklift boss (C-D4).
#
# ===== API (for the story integration) =====
#   var fight := GunFight.new()
#   roam.add_child(fight)                       # any Node3D parent; FreeRoam is the usual one
#   fight.setup({"roam": roam,                  # FreeRoam: player, combat (PlayerCombat), weapons, wanted read from it; or
#                                               #   pass "player" (ThirdPersonController) [+ "combat", "weapons"]. Without a
#                                               #   combat the fight builds its own PlayerCombat (the player's HP lives there).
#       "cover": cover_map,                     # a CoverMap, or "cover_root": node (CoverMap.scan: group "cover" under it);
#                                               #   neither = every node of the group "cover" in the scene tree
#       "nav": graph,                           # optional HorrorNavGraph for detours (gunmen walk straight clear lines)
#       "loadout": [WeaponData.Slot.PISTOL, WeaponData.Slot.SHOTGUN],   # default; the first is equipped, mags filled
#       "force_loadout": true,                  # default: only the loadout + Tay không can be equipped
#       "lock_funny": true,                     # default: rocket, dép, sầu riêng, loa locked (when force_loadout is false)
#       "reserve": {WeaponData.Slot.PISTOL: 48, WeaponData.Slot.SHOTGUN: 12},   # spare rounds (default); -1 = unlimited
#       "max_shooters": 4,                      # gunmen shooting at once (tokens); default GunData.max_shooters() (4 / 3)
#       "auto_checkpoint": true,                # every wave start is a checkpoint
#       "start_alerted": false,                 # wave 1 starts alerted (seen while sneaking); later waves always do
#       "bullet_time": true,                    # Wave 3: build fight.bullet_time (BulletTime: Space while aiming dives)
#       "seed": 1})
#   fight.add_wave([                            # once per wave, in order
#       {"at": Vector3(...), "yaw": 0.0, "patrol": [Vector3(...), ...],
#        "opts": {"mask": "wolf", "label": "", "body": {...CharacterBuilder opts}, "body_fn": Callable(look) -> Node3D,
#                 "hp": 60.0, "accuracy": 1.0, "ai": true, "alerted": false,
#                 "kind": "shield"}},             # Wave 3: the pallet-shield guard (blocks from the front, see Gunman)
#       {"boss": "forklift", "at": Vector3(...), "yaw": 0.0,
#        "opts": {"hp": 500.0, "body": {...Alexander's CharacterBuilder opts}, "body_fn": Callable, "seed": 3}}])
#   A wave entry {"target": node} adds an external enemy of the level (never freed; reset() at every wave start): any
#   Node3D with is_defeated(), hit_node() (a Node3D with take_hit(info) / is_down()) and stand_down() (Day 3 crates).
#   fight.add_ammo(Vector3(...), WeaponData.Slot.PISTOL, 24)   # pickups (taken ones come back on retry() before them)
#   fight.won.connect(...)                      # the last wave is beaten (KO'd bodies stay until stop() / free)
#   fight.lost.connect(...)                     # the player's HP reached 0: show "TOANG!", then call retry()
#   fight.enemy_ko.connect(func(e): ...)        # also wave_started(i), wave_cleared(i), boss_spawned(boss),
#                                               #   player_hit(source, damage), alerted(gunman) (each guard that notices),
#                                               #   spotted(gunman) (the first one per wave: the Day 3 sneak failing; also
#                                               #   fires for a wave spawned alerted)
#   Unalerted guards without a "yaw" face along their patrol (first leg), else yaw 0; alerted ones face the player.
#   Gunmen follow the floor height while walking (ramps, stairs) and never walk through level geometry (a nav graph's
#   route is used only when every leg is walkable).
#   Boss: {"boss": "forklift", ..., "opts": {"ai": false}} sits still (villain card, cinematic); boss.activate() starts
#   its AI loop; boss.force_attack("charge" | "toss") triggers one attack (see ForkliftBoss).
#   fight.start(); fight.checkpoint(); fight.retry(); fight.stop()
#   fight.alive() -> Array; fight.shooters() -> int; fight.boss (ForkliftBoss or null); fight.state ("idle" | "running" |
#   "won" | "lost"); fight.wave; fight.cover_ctl (PlayerCover); fight.hud (GunHUD); fight.bullet_time (BulletTime or null:
#   .enabled, .active(), .focus, .refill(n); full focus at start / retry, stopped on won / lost / retry / stop / free, a
#   knockout refills it, a last-enemy knockout during a dive ends the dive's slow part before the orbit; while the player
#   lies prone the enemies aim at the crouch height)
# Gun difficulty (Wave 3 T2): the token cap, the gunmen's telegraph and accuracy and the regeneration delay come from
# GunData.max_shooters() / telegraph_s() / accuracy_k() / regen_delay() (Thường / Dễ). While engaged the fight sets
# combat.regen_delay to GunData.regen_delay() and restores the previous value with the rest (won, stop, free). Gunman
# bullets cost GunData.gunman_dmg() HP. Retry mercy (T11): a wave lost n times in a row respawns on retry() with its gunmen's
# hit chance x GunData.retry_mercy(n) (fail_wave / fail_streak; reset by start()).
# Player HP = PlayerCombat's (100, regeneration 10 HP/s after combat.regen_delay, `down`): bullets and boss hits go through
# PlayerCombat.receive_attack (boss hits are heavy: a comic knock-down). From start() until won / stop() (lost keeps it until
# retry() or stop()) the fight sets combat.fight_active (no bike, no emotes), hides the CombatHUD HP bar (GunHUD shows HP,
# enemies left, damage direction, cover hints, the boss bar), forces the loadout and locks the other slots (the wheel shows
# them as "Khoá"), gives finite spare rounds (WeaponDirector.reserve), adds its enemies to the weapons' and the combat's
# targets, cuts the wanted heat (the weapons' mayhem -> WantedDirector link) and consumes [P] / [B] with a hint. All of it
# is undone on won, stop() and when the node leaves the tree; stop() and freeing also revive a downed player. The fight
# never changes the story state, the time of day or the camera; it never references an autoload.
# ===========================================
class_name GunFight
extends Node3D

signal won
signal lost
signal enemy_ko(enemy: Node3D)
signal wave_started(index: int)
signal wave_cleared(index: int)
signal boss_spawned(boss: Node3D)
signal player_hit(source: Node3D, damage: float)
signal alerted(gunman: Node3D)
signal spotted(gunman: Node3D)

const WAVE_GAP_S: float = 2.0
const WORLD_MASK: int = 1

var roam: Node = null
var player: ThirdPersonController
var combat: PlayerCombat
var weapons: WeaponDirector
var cover: CoverMap
var nav: HorrorNavGraph = null
var fx: WeaponFX
var hud: GunHUD
var cover_ctl: PlayerCover
var taken: Dictionary = {}
var loadout: Array = [WeaponData.Slot.PISTOL, WeaponData.Slot.SHOTGUN]
var force_loadout: bool = true
var lock_funny: bool = true
var reserve_init: Dictionary = GunData.DEFAULT_RESERVE
var max_shooters: int = GunData.max_shooters()
var auto_checkpoint: bool = true
var start_alerted: bool = false
## Tests: >= 0 = every gunman's hit chance.
var accuracy_override: float = -1.0
var fight_seed: int = 1
var waves: Array = []
var wave: int = -1
var state: String = "idle"
var enemies: Array = []
var gunmen: Array = []
var boss: Node3D = null
var holders: Array = []
var pickups: Array[AmmoPickup] = []
var ko_total: int = 0
var max_shooters_seen: int = 0
var hits_taken: int = 0
var refusals: int = 0
var engaged: bool = false
var _cp: Dictionary = {}
var _gap_left: float = -1.0
var _spawned: int = 0
var _rq := PhysicsRayQueryParameters3D.new()
var _ex: Array[RID] = []
var _prev_wfn: Callable = Callable()
var _prev_cfn: Callable = Callable()
var _heat_cut: Object = null
var _bar_was: bool = true
var _regen_was: float = CombatData.REGEN_DELAY
## Wave 3 bullet time (null when the setup passes "bullet_time": false).
var bullet_time: BulletTime = null
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
var _prune_t: float = 0.0
var _spotted: bool = false
## Retry mercy (T11): the wave lost last and how many times in a row (its gunmen respawn with GunData.retry_mercy()).
var fail_wave: int = -1
var fail_streak: int = 0


func _ready() -> void:
	for i: int in 6:
		var p := AudioStreamPlayer3D.new()
		p.name = "GunSfx%d" % i
		p.bus = WeaponAudio.bus()
		p.max_distance = 90.0
		p.unit_size = 6.0
		add_child(p)
		_sfx.append(p)
	for c: String in ["shot_pistol", "dry_click", "ricochet", "reload"]:
		WeaponAudio.stream(c)
	for c2: String in ["body_fall", "crate_smash", "impact_heavy", "impact_medium", "helmet_clonk", "engine_roar"]:
		CineAudio.sfx(c2)
	GunAudio.warm()


func setup(opts: Dictionary) -> void:
	roam = opts.get("roam")
	if roam:
		player = roam.get("player")
		combat = roam.get("combat")
		weapons = roam.get("weapons")
	if opts.has("player"):
		player = opts["player"]
	if opts.has("combat"):
		combat = opts["combat"]
	if opts.has("weapons"):
		weapons = opts["weapons"]
	nav = opts.get("nav")
	loadout = (opts.get("loadout", loadout) as Array).duplicate()
	force_loadout = bool(opts.get("force_loadout", true))
	lock_funny = bool(opts.get("lock_funny", true))
	reserve_init = (opts.get("reserve", GunData.DEFAULT_RESERVE) as Dictionary).duplicate()
	max_shooters = int(opts.get("max_shooters", GunData.max_shooters()))
	auto_checkpoint = bool(opts.get("auto_checkpoint", true))
	start_alerted = bool(opts.get("start_alerted", false))
	accuracy_override = float(opts.get("accuracy_override", -1.0))
	fight_seed = int(opts.get("seed", 1))
	if opts.has("cover"):
		cover = opts["cover"]
	else:
		cover = CoverMap.new()
		var root: Node = opts.get("cover_root", get_tree().root if is_inside_tree() else null)
		cover.scan(root)
	Impact.prepare(self)                     # Q2: the clock and the sound layers ready before the first hit
	fx = weapons.fx if weapons else null
	if fx == null:
		fx = WeaponFX.new()
		fx.name = "GunFX"
		add_child(fx)
	if combat == null and player != null:
		combat = PlayerCombat.new()
		combat.name = "FightCombat"
		add_child(combat)
		combat.setup({"player": player, "weapons": weapons})
	hud = GunHUD.new()
	hud.name = "GunHUD"
	hud.fight = self
	hud.visible = false
	add_child(hud)
	cover_ctl = PlayerCover.new()
	cover_ctl.name = "PlayerCover"
	cover_ctl.enabled = false
	add_child(cover_ctl)
	cover_ctl.setup(player, cover, weapons, combat, taken)
	cover_ctl.reach_fn = clear_walk
	if bool(opts.get("bullet_time", true)) and player != null:
		bullet_time = BulletTime.new()
		bullet_time.name = "BulletTime"
		add_child(bullet_time)
		bullet_time.setup(self)
	_rq.collision_mask = WORLD_MASK
	_rq.collide_with_areas = false
	_rq.hit_from_inside = true
	if player:
		_ex = [player.get_rid()]
	_rq.exclude = _ex


func add_wave(spawns: Array) -> void:
	waves.append(spawns.duplicate(true))


## An ammo pickup at pos (on the floor): `amount` spare rounds for `slot` (default GunData.PICKUP_AMOUNT).
func add_ammo(pos: Vector3, slot: int = WeaponData.Slot.PISTOL, amount: int = -1) -> AmmoPickup:
	var p := AmmoPickup.new()
	p.name = "Ammo%d" % pickups.size()
	p.setup(self, slot, amount if amount > 0 else int(GunData.PICKUP_AMOUNT.get(slot, 12)))
	p.top_level = true
	p.position = pos
	add_child(p)
	pickups.append(p)
	return p


func start() -> void:
	if waves.is_empty() or player == null or combat == null:
		push_warning("GunFight.start: no wave, player or combat")
		return
	state = "running"
	fail_wave = -1
	fail_streak = 0
	combat.revive()
	_engage(true)
	_off_bike()
	if bullet_time:
		bullet_time.reset()
	_start_wave(0)


## Remember the current wave, the player's spot, the ammo and the pickups: retry() comes back here.
func checkpoint() -> void:
	if player == null:
		return
	var taken_flags: Array = []
	for p: AmmoPickup in pickups:
		taken_flags.append(p.taken)
	_cp = {"wave": maxi(wave, 0), "pos": player.global_position, "yaw": player.facing_yaw(),
		"ammo": weapons.ammo.duplicate() if weapons else PackedInt32Array(),
		"reserve": _topped_up(weapons.reserve) if weapons else PackedInt32Array(), "pickups": taken_flags}


## Each loadout slot with a finite reserve gets at least one magazine of spare rounds (a checkpoint reached empty-handed
## after the pickups are gone never makes every retry start dry).
func _topped_up(res: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = res.duplicate()
	for s: Variant in loadout:
		var i: int = int(s)
		if i < out.size() and out[i] >= 0:
			out[i] = maxi(out[i], WeaponData.mag_of(i))
	return out


func has_checkpoint() -> bool:
	return not _cp.is_empty()


## After `lost` (or any time): enemies removed, the player back at the checkpoint with full HP and its ammo, that wave
## spawned again.
func retry() -> void:
	if player == null or combat == null:
		return
	if _cp.is_empty():
		checkpoint()
	_off_bike()
	if bullet_time:
		bullet_time.reset()
	cover_ctl.leave()
	player.teleport(_cp["pos"], float(_cp["yaw"]))
	combat.revive()
	state = "running"
	_engage(true)
	if weapons:
		weapons.ammo = (_cp["ammo"] as PackedInt32Array).duplicate()
		weapons.reserve = _topped_up(_cp["reserve"])
		weapons.reload_left = 0.0
		weapons.call("_refresh_hud")
	var flags: Array = _cp["pickups"]
	for i: int in pickups.size():
		if i < flags.size() and not bool(flags[i]):
			pickups[i].reset()
	var keep: Dictionary = _cp.duplicate()
	_start_wave(int(_cp["wave"]))
	_cp = keep


## End without a result: enemies freed, everything the fight changed is restored.
func stop() -> void:
	_clear_enemies()
	state = "idle"
	_engage(false)
	_revive_if_down()


func alive() -> Array:
	var out: Array = []
	for e: Variant in enemies:
		if is_instance_valid(e) and not bool((e as Object).call("is_defeated")):
			out.append(e)
	return out


## Enemies still to beat: the current wave's plus every later wave's.
func enemies_left() -> int:
	var n: int = 0
	for e: Variant in enemies:
		if is_instance_valid(e) and not bool((e as Object).call("is_defeated")):
			n += 1
	for i: int in range(wave + 1, waves.size()):
		n += (waves[i] as Array).size()
	return n


## Gunmen holding a shooting token right now.
func shooters() -> int:
	var n: int = 0
	for e: Variant in holders:
		if is_instance_valid(e):
			n += 1
	return n


# ----- shooting tokens (Gunman) -----
func request_token(e: Object) -> bool:
	if state != "running":
		return false
	if holders.has(e):
		return true
	for i: int in range(holders.size() - 1, -1, -1):
		if not is_instance_valid(holders[i]):
			holders.remove_at(i)
	if holders.size() >= max_shooters:
		return false
	holders.append(e)
	return true


func release_token(e: Object) -> void:
	holders.erase(e)


# ----- what the enemies know and do (Gunman / ForkliftBoss call these) -----
func player_feet() -> Vector3:
	return player.global_position if player else global_position


func player_target() -> Vector3:
	if player and player.is_prone():
		return player_feet() + Vector3(0.0, GunData.TARGET_CROUCH_Y, 0.0)   # lying after a dive
	if cover_ctl and cover_ctl.player:
		return cover_ctl.target_point()
	return player_feet() + Vector3(0.0, GunData.TARGET_STAND_Y, 0.0)


func player_speed() -> float:
	return player.horizontal_speed if player else 0.0


func player_popped() -> bool:
	return cover_ctl != null and cover_ctl.in_cover and cover_ctl.exposed()


## How far the player's footsteps carry (sprint / jog; 0 while still, walking or in cover).
func noise_radius() -> float:
	if player == null or (cover_ctl and cover_ctl.in_cover):
		return 0.0
	if player.is_sprinting and player.horizontal_speed > 5.0:
		return GunData.HEAR_SPRINT_M
	if player.horizontal_speed > 2.5:
		return GunData.HEAR_JOG_M
	return 0.0


## The first world hit on a -> b ({} = clear); the player's body is ignored.
func ray(a: Vector3, b: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	_rq.from = a
	_rq.to = b
	return get_world_3d().direct_space_state.intersect_ray(_rq)


func clear_line(a: Vector3, b: Vector3) -> bool:
	return ray(a, b).is_empty()


## A person can walk the straight line a -> b (nothing at knee or chest height above each end's floor).
func clear_walk(a: Vector3, b: Vector3) -> bool:
	return clear_line(a + Vector3(0.0, 0.5, 0.0), b + Vector3(0.0, 0.5, 0.0)) and clear_line(a + Vector3(0.0, 1.2, 0.0), b + Vector3(0.0, 1.2, 0.0))


## An enemy hit lands on the player (heavy = a boss hit: knock-down). Returns PlayerCombat's result ("hit", "ignored", ...).
func hit_player(source: Node3D, damage: float, heavy: bool = false) -> String:
	if state != "running" or combat == null:
		return "ignored"
	var r: String = combat.receive_attack(source, {"damage": damage, "heavy": heavy, "unblockable": true})
	if r == "hit":
		hits_taken += 1
		if hud and is_instance_valid(source):
			hud.add_damage(source.global_position, player.global_position)
		player_hit.emit(source, damage)
	return r


## A gunman was alerted: the others within ALERT_SHARE_M hear it.
func on_alert(g: Object) -> void:
	alerted.emit(g)
	if not _spotted:
		_spotted = true
		spotted.emit(g)
	var at: Vector3 = (g as Node3D).global_position
	for o: Variant in gunmen:
		if o != g and is_instance_valid(o) and WeaponMath.flat((o as Node3D).global_position, at) <= GunData.ALERT_SHARE_M:
			(o as Gunman).alert(player_feet())


func on_pickup(p: AmmoPickup) -> void:
	if weapons:
		weapons.add_reserve(p.slot, p.amount)
	play_cue("reload", p.global_position, -2.0)
	if hud:
		hud.toast(GunData.T_AMMO % [p.amount, WeaponData.name_of(p.slot)])


## A sound at a world position: Phase W cues (WeaponAudio), story / A1 cues (CineAudio) or GunAudio's.
func play_cue(cue: String, at: Vector3, db: float = 0.0) -> void:
	if _sfx.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	if WeaponAudio.CUES.has(cue):
		p.stream = WeaponAudio.stream(cue)
	elif GunAudio.CUES.has(cue):
		p.stream = GunAudio.stream(cue)
	else:
		p.stream = CineAudio.sfx(cue)
	p.volume_db = db
	p.global_position = at
	p.play()


# ---------------------------------------------------------------------------
func _start_wave(i: int) -> void:
	_clear_enemies()
	_gap_left = -1.0
	_spotted = false
	wave = i
	if auto_checkpoint:
		checkpoint()
	for s: Variant in waves[i]:
		var d: Dictionary = s
		if d.has("boss"):
			_spawn_boss(d)
		elif d.has("target"):
			_add_target(d["target"])
		else:
			_spawn_gunman(d, i)
	wave_started.emit(i)
	if waves.size() > 1 and hud:
		hud.popup(GunData.T_WAVE_POP % (i + 1))


func _spawn_gunman(d: Dictionary, wave_i: int) -> void:
	var g := Gunman.new()
	g.name = "Gunman%d" % _spawned
	var o: Dictionary = (d.get("opts", {}) as Dictionary).duplicate()
	if not o.has("seed"):
		o["seed"] = fight_seed * 1000 + _spawned
	if accuracy_override >= 0.0 and not o.has("accuracy_override"):
		o["accuracy_override"] = accuracy_override
	if wave_i == fail_wave and fail_streak > 0:
		o["accuracy"] = float(o.get("accuracy", 1.0)) * GunData.retry_mercy(fail_streak)
	if not o.has("alerted"):
		o["alerted"] = start_alerted or wave_i > 0
	o["patrol"] = d.get("patrol", [])
	var at: Vector3 = d.get("at", global_position)
	if d.has("yaw"):
		o["yaw"] = float(d["yaw"])
	elif bool(o["alerted"]):
		var to: Vector3 = player.global_position - at
		o["yaw"] = atan2(-to.x, -to.z)
	else:
		var pts: Array = o["patrol"]
		var to2 := Vector3.ZERO
		for v: Variant in pts:
			to2 = (v as Vector3) - at
			if Vector2(to2.x, to2.z).length() > 0.3:
				break
		o["yaw"] = atan2(-to2.x, -to2.z) if Vector2(to2.x, to2.z).length() > 0.3 else 0.0
	_spawned += 1
	g.setup(o)
	g.top_level = true
	g.position = at
	add_child(g)
	g.bind(self)
	g.ko.connect(_on_ko)
	enemies.append(g)
	gunmen.append(g)


func _spawn_boss(d: Dictionary) -> void:
	var b := ForkliftBoss.new()
	b.name = "ForkliftBoss"
	var o: Dictionary = (d.get("opts", {}) as Dictionary).duplicate()
	if not o.has("seed"):
		o["seed"] = fight_seed * 1000 + _spawned
	_spawned += 1
	var at: Vector3 = d.get("at", global_position)
	var yaw: float
	if d.has("yaw"):
		yaw = float(d["yaw"])
	else:
		var to: Vector3 = player.global_position - at
		yaw = atan2(-to.x, -to.z)
	b.setup(o)
	b.top_level = true
	b.position = at
	add_child(b)
	b.set_yaw(yaw)
	b.bind(self)
	b.ko.connect(_on_ko)
	enemies.append(b)
	boss = b
	boss_spawned.emit(b)


## An external enemy of the level (wave entry {"target": node}; Phase C: the Day 3 smart-glasses crates): duck-typed like a
## gunman (is_defeated(), hit_node(), stand_down(); optional reset() at every wave start, optional signal ko(node)); the
## fight never frees it.
func _add_target(n: Variant) -> void:
	if not (n is Node3D) or not is_instance_valid(n):
		return
	var t: Node3D = n
	if t.has_method("reset"):
		t.call("reset")
	if t.has_signal("ko") and not t.is_connected("ko", _on_ko):
		t.connect("ko", _on_ko)
	t.set_meta("gunfight_external", true)
	enemies.append(t)


func _clear_enemies() -> void:
	for e: Variant in enemies:
		if is_instance_valid(e) and not (e as Node).has_meta("gunfight_external"):
			(e as Node).queue_free()
	enemies.clear()
	gunmen.clear()
	holders.clear()
	boss = null
	for k: Variant in taken.keys():
		if taken[k] is Gunman or not is_instance_valid(taken[k]):
			taken.erase(k)


## Cover slots that stand inside level geometry (a slot of one box inside the next box or a wall, the forklift parked on
## it) are not offered: they are marked taken by the fight itself, re-checked every PRUNE_S while the fight runs (a
## blocker that moves away or a crate that breaks frees the slot again). reprune() checks at once.
func reprune() -> void:
	_prune_t = 0.0
	_prune_slots()


func _prune_slots() -> void:
	if not is_inside_tree() or cover == null:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = WORLD_MASK
	q.collide_with_areas = false
	q.exclude = _ex
	for i: int in cover.count():
		var blocked: bool = false
		for h: float in [0.4, 0.9]:
			q.position = cover.pos[i] + Vector3(0.0, h, 0.0)
			if not space.intersect_point(q, 1).is_empty():
				blocked = true
				break
		if blocked and not taken.has(i):
			taken[i] = self
		elif not blocked and taken.get(i) == self:
			taken.erase(i)


func _on_ko(e: Node3D) -> void:
	ko_total += 1
	holders.erase(e)
	if bullet_time:
		bullet_time.on_ko()
	if state == "running" and wave == waves.size() - 1 and _others_defeated(e):
		if bullet_time:
			bullet_time.end_dive()                     # the orbit takes the time scale from a running dive
		Impact.slowmo_orbit(self, e, Impact.ORBIT_S)   # Q2: the last enemy's knockout in slow motion
	enemy_ko.emit(e)


func _others_defeated(e: Node3D) -> bool:
	for x: Variant in enemies:
		if x != e and is_instance_valid(x) and not bool((x as Object).call("is_defeated")):
			return false
	return true


func _physics_process(delta: float) -> void:
	if state != "running":
		return
	_prune_t -= delta
	if _prune_t <= 0.0:
		_prune_t = GunData.PRUNE_S
		_prune_slots()
	max_shooters_seen = maxi(max_shooters_seen, shooters())
	if combat.is_down():
		_on_lost()
		return
	if _gap_left >= 0.0:
		_gap_left -= delta
		if _gap_left < 0.0:
			_start_wave(wave + 1)
		return
	for e: Variant in enemies:
		if is_instance_valid(e) and not bool((e as Object).call("is_defeated")):
			return
	wave_cleared.emit(wave)
	if wave + 1 < waves.size():
		_gap_left = WAVE_GAP_S
	else:
		state = "won"
		_engage(false)
		won.emit()


func _on_lost() -> void:
	state = "lost"
	fail_streak = fail_streak + 1 if wave == fail_wave else 1
	fail_wave = wave
	if bullet_time:
		bullet_time.stop()
	for e: Variant in enemies:
		if is_instance_valid(e):
			(e as Object).call("stand_down")
	holders.clear()
	cover_ctl.leave()
	lost.emit()


## The player's gunfire carries HEAR_SHOT_M (through walls).
func _on_player_fired(slot: int) -> void:
	if WeaponData.mag_of(slot) <= 0 or player == null:
		return
	var at: Vector3 = player.global_position
	for g: Variant in gunmen:
		if is_instance_valid(g) and WeaponMath.flat((g as Node3D).global_position, at) <= GunData.HEAR_SHOT_M:
			(g as Gunman).hear(at)


## Everything the fight changes on the player side, applied (on) or restored (off). Idempotent.
func _engage(on: bool) -> void:
	if on == engaged:
		return
	engaged = on
	if on:
		combat.fight_active = true
		_regen_was = combat.regen_delay
		combat.regen_delay = GunData.regen_delay()
		if combat.hud and combat.hud.bar:
			_bar_was = combat.hud.bar.visible
			combat.hud.bar.visible = false
		_prev_cfn = combat.targets_fn
		combat.targets_fn = _combat_targets
		if weapons:
			var locks: Array = []
			for s: int in WeaponData.COUNT:
				if s == WeaponData.Slot.UNARMED or loadout.has(s):
					continue
				if force_loadout or (lock_funny and GunData.FUNNY.has(s)):
					locks.append(s)
			weapons.set_locked_slots(locks, GunData.T_LOCKED)
			var res := PackedInt32Array()
			res.resize(WeaponData.COUNT)
			res.fill(-1)
			for k: Variant in reserve_init.keys():
				res[int(k)] = int(reserve_init[k])
			weapons.reserve = res
			var am: PackedInt32Array = weapons.ammo.duplicate()
			for s2: Variant in loadout:
				am[int(s2)] = WeaponData.mag_of(int(s2))
			weapons.ammo = am
			if not loadout.is_empty():
				weapons.equip(int(loadout[0]))
			weapons.call("_refresh_hud")
			_prev_wfn = weapons.targets_fn
			weapons.targets_fn = _weapon_targets
			if not weapons.fired.is_connected(_on_player_fired):
				weapons.fired.connect(_on_player_fired)
			var wanted: Object = roam.get("wanted") if roam and is_instance_valid(roam) else null
			if wanted and String(wanted.get("state")) == "free" and (float(wanted.get("heat")) > 0.0 or int(wanted.get("stars")) > 0) \
					and wanted.has_method("clear"):
				wanted.call("clear")             # no officers walking into a lair fight with old heat
			if wanted and weapons.mayhem.is_connected(Callable(wanted, "add_heat")):
				weapons.mayhem.disconnect(Callable(wanted, "add_heat"))
				_heat_cut = wanted
		hud.visible = true
		cover_ctl.enabled = true
		if bullet_time:
			bullet_time.engage(true)
	else:
		if combat and is_instance_valid(combat):
			combat.fight_active = false
			combat.regen_delay = _regen_was
			if combat.hud and combat.hud.bar:
				combat.hud.bar.visible = _bar_was
			if combat.targets_fn == Callable(self, "_combat_targets"):
				combat.targets_fn = _prev_cfn
		if weapons and is_instance_valid(weapons):
			weapons.set_locked_slots([])
			weapons.reserve = PackedInt32Array()
			weapons.call("_refresh_hud")
			if weapons.targets_fn == Callable(self, "_weapon_targets"):
				weapons.targets_fn = _prev_wfn
			if weapons.fired.is_connected(_on_player_fired):
				weapons.fired.disconnect(_on_player_fired)
			if _heat_cut != null and is_instance_valid(_heat_cut) and not weapons.mayhem.is_connected(Callable(_heat_cut, "add_heat")):
				weapons.mayhem.connect(Callable(_heat_cut, "add_heat"))
		_heat_cut = null
		if bullet_time and is_instance_valid(bullet_time):
			bullet_time.engage(false)
		if hud:
			hud.visible = false
		if cover_ctl:
			cover_ctl.leave()
			cover_ctl.enabled = false


func _weapon_targets() -> Array:
	var out: Array = (_prev_wfn.call() as Array).duplicate() if _prev_wfn.is_valid() else []
	_add_targets(out)
	return out


func _combat_targets() -> Array:
	var out: Array = (_prev_cfn.call() as Array).duplicate() if _prev_cfn.is_valid() else []
	_add_targets(out)
	return out


func _add_targets(out: Array) -> void:
	for e: Variant in enemies:
		if is_instance_valid(e) and (e as Node).is_inside_tree():
			out.append((e as Object).call("hit_node"))


func _revive_if_down() -> void:
	if combat and is_instance_valid(combat) and combat.is_down():
		combat.revive()


## Ready to fight: off the bike, and the story phone closed.
func _off_bike() -> void:
	if roam == null or not is_instance_valid(roam):
		return
	if bool(roam.get("mounted")) and roam.has_method("dismount_bike"):
		roam.call("dismount_bike")
	var sr: Object = roam.get("story_roam")
	var ph: Object = sr.get("phone") if sr else null
	if ph and ph.has_method("is_open") and bool(ph.call("is_open")):
		ph.call("close")


func _input(event: InputEvent) -> void:
	if not engaged or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and (k.physical_keycode == KEY_P or k.physical_keycode == KEY_B):
		refusals += 1
		var text: String = GunData.T_FIGHT_PHONE if k.physical_keycode == KEY_P else GunData.T_FIGHT_EMOTE
		if roam and is_instance_valid(roam) and roam.has_method("flash_hint"):
			roam.call("flash_hint", text)
		elif hud:
			hud.toast(text)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_engage(false)
	_revive_if_down()
