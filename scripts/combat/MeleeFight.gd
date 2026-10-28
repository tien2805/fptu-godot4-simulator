# File: res://scripts/combat/MeleeFight.gd
# Encounter node of the Phase B melee fights (spec B-D1 / B-D2): the Day 1 courier brawl, the Day 4 clone waves and Dolly.
#
# ===== API (for the story integration) =====
#   var fight := MeleeFight.new()
#   roam.add_child(fight)                       # any Node3D parent; FreeRoam is the usual one
#   fight.setup({"roam": roam,                  # FreeRoam: player, combat (PlayerCombat), weapons read from it; or pass
#                                               #   "player" (ThirdPersonController) [+ "combat", "weapons"] instead.
#                                               #   Without a combat the fight builds its own PlayerCombat.
#       "force_unarmed": true,                  # default true: Tay không equipped, weapon wheel + scroll locked, and the line
#                                               #   "Nhiệm vụ này chỉ dùng tay không" when the player tries (story spec S-D5)
#       "max_attackers": 2,                     # enemies committed to an attack at once (the others circle and taunt)
#       "auto_checkpoint": true,                # every wave start is a checkpoint
#       "start_line": "Gét gô!",                # centre popup at start() ("" = none)
#       "seed": 1,                              # enemy AI randomness
#       "props": [{"kind": "chair", "at": Vector3(...), "yaw": 0.0}, ...]})   # Q2 improvised weapons on the floor ("chair",
#                                               #   "tray", "helmet", "lid"; [E] picks one up), spawned at prepare() / start()
#   fight.add_prop("tray", Vector3(...)) -> ImprovisedWeapon   # one more at any time after setup (retry() puts them back)
#   fight.add_wave([                            # call once per wave, in order
#       {"archetype": "courier", "at": Vector3(...), "yaw": 0.0,          # yaw optional: default faces the player
#        "opts": {"label": "Mũ Đỏ", "body": {"helmet_color": Color("#E74C3C"), "seed": 102}}},
#       ...])
#   #   opts = MeleeEnemy opts: "body" (CharacterBuilder opts merged over the archetype look), "body_fn"
#   #   (Callable(look) -> rigged Node3D: masks, cardigans), "label", "stats" (archetype overrides), "hp_scale".
#   #   Archetypes: "courier" (helmet rider), "clone" (identical student, give it a sheep mask via body_fn), "dolly"
#   #   (mini-boss: fast, side-steps, flees at 30 % HP; fled counts as beaten), "soi_xam" (Phase C mini-boss: fast 4-hit
#   #   combos, LED-eye glow before every attack, a howl buff at 50 % HP; gets the boss bar).
#   #   Optional spawn key "make": Callable() -> MeleeEnemy subclass to spawn instead (SwordDuel: KatanaBoss).
#   #   The first enemy whose stats have "boss" becomes combat.boss (the HUD's boss bar) until it is removed.
#   fight.won.connect(...)                      # last wave beaten (every enemy knocked out or fled); the knocked-out
#                                               #   bodies stay until you stop() or queue_free() the fight
#   fight.lost.connect(...)                     # the player's HP reached 0 (show "TOANG!", then call retry())
#   fight.enemy_ko.connect(func(e: MeleeEnemy): ...)   # also enemy_fled(e), wave_started(i), wave_cleared(i)
#   fight.prepare()                             # optional: spawn the first wave now for a villain card; they stand in guard,
#                                               #   not hostile, invulnerable (MeleeEnemy.staged) until start()
#   fight.start()
#   fight.checkpoint()                          # remember the current wave + the player's spot (automatic per wave)
#   fight.retry()                               # enemies removed, HP 100, player back at the checkpoint, that wave again
#   fight.stop()                                # end without a result (enemies freed, wheel unlocked)
#   fight.alive() -> Array                      # MeleeEnemy still fighting in the current wave
#   fight.state                                 # "idle" | "running" | "won" | "lost";  fight.wave = current wave index
# The PlayerCombat HUD shows while the fight runs (combat.fight_active, from start() until won / stop(); it stays set after
# lost until retry() or stop()). While it is set the player cannot:
#   - mount or summon the bike [F] (FreeRoam.toggle_bike refuses with a hint); start() / retry() take a rider off the bike
#     and close an open story phone;
#   - open the phone [P] or the emote wheel [B] (this node consumes the keys and shows a hint; the emote wheel is blocked
#     through FreeRoam's emote blocker as well).
# Winning or stopping unlocks the weapon wheel; losing stands the enemies down (they stop attacking) and unlocks it too;
# retry() locks it again. stop() and freeing the fight revive a downed player (no soft-lock if the story skips the retry)
# and take the fight's enemies out of the PlayerCombat. Knocked-out bodies of a cleared wave are removed
# WAVE_GAP_S after it is cleared, when the next wave spawns. The fight never changes the story state, the time of day or
# the camera; it never references an autoload.
# Q2: while it runs, combat.last_fn tells PlayerCombat which knockout is the last enemy of the last wave (its slow-motion
# orbit); retry() and stop() take a held improvised weapon out of the player's hand (back on the floor / freed).
# ===========================================
class_name MeleeFight
extends Node3D

signal won
signal lost
signal enemy_ko(enemy: MeleeEnemy)
signal enemy_fled(enemy: MeleeEnemy)
signal wave_started(index: int)
signal wave_cleared(index: int)

const WAVE_GAP_S: float = 2.0
const LINE_COOLDOWN_S: float = 1.5

var roam: Node = null
var player: ThirdPersonController
var combat: PlayerCombat
var weapons: WeaponDirector
var force_unarmed: bool = true
var max_attackers: int = 2
var auto_checkpoint: bool = true
var start_line: String = ""
var fight_seed: int = 1
var waves: Array = []
var wave: int = -1
var state: String = "idle"
## Refusals shown while the fight runs ([P] phone, [B] emotes) (tests).
var refusals: int = 0
## Enemies of the current wave (shared with them as their sibling list for separation).
var enemies: Array = []
var holders: Array = []
var ko_total: int = 0
var unarmed_lines: int = 0
var max_attackers_seen: int = 0
var _cp: Dictionary = {}
var _locked: bool = false
var _prev_locked: bool = false
var _line_cd: float = 0.0
var _mid_prev: bool = false
var _gap_left: float = -1.0
var _spawned: int = 0
var _staging: bool = false
var _prepared: bool = false
## Q2 improvised weapons: the setup's "props" spec and the spawned ones.
var props_spec: Array = []
var props: Array = []


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
	force_unarmed = bool(opts.get("force_unarmed", true))
	max_attackers = int(opts.get("max_attackers", 2))
	auto_checkpoint = bool(opts.get("auto_checkpoint", true))
	start_line = String(opts.get("start_line", ""))
	fight_seed = int(opts.get("seed", 1))
	props_spec = opts.get("props", [])
	if combat == null and player != null:
		combat = PlayerCombat.new()
		combat.name = "FightCombat"
		add_child(combat)
		combat.setup({"player": player, "weapons": weapons})


func add_wave(spawns: Array) -> void:
	waves.append(spawns.duplicate(true))


## Spawn the first wave before start() (a villain card can frame them): staged enemies stand in guard, are not hostile and
## take no hits; start() wakes them instead of spawning again. wave_started(0) fires here.
func prepare() -> void:
	if waves.is_empty() or player == null or combat == null or state == "running":
		return
	_staging = true
	_start_wave(0)
	_staging = false
	_prepared = true
	_spawn_props()


func start() -> void:
	if waves.is_empty() or player == null or combat == null:
		push_warning("MeleeFight.start: no wave, player or combat")
		return
	state = "running"
	combat.fight_active = true
	combat.revive()
	combat.last_fn = _is_last
	_spawn_props()
	_lock_weapons(true)
	_off_bike()
	if start_line != "" and combat.hud:
		combat.hud.popup(start_line)
	if _prepared and wave == 0 and not enemies.is_empty():
		_prepared = false
		if auto_checkpoint:
			checkpoint()
		for e: Variant in enemies:
			if is_instance_valid(e):
				(e as MeleeEnemy).unstage()
	else:
		_start_wave(0)


## Remember the current wave and the player's spot: retry() comes back here.
func checkpoint() -> void:
	if player == null:
		return
	_cp = {"wave": maxi(wave, 0), "pos": player.global_position, "yaw": player.facing_yaw()}


func has_checkpoint() -> bool:
	return not _cp.is_empty()


## After `lost` (or any time): enemies removed, the player back at the checkpoint with full HP, its wave spawned again.
func retry() -> void:
	if player == null or combat == null:
		return
	if _cp.is_empty():
		checkpoint()
	_off_bike()
	player.teleport(_cp["pos"], float(_cp["yaw"]))
	combat.revive()
	combat.drop_prop()
	for p: Variant in props:
		if is_instance_valid(p):
			(p as ImprovisedWeapon).reset()
	combat.last_fn = _is_last
	state = "running"
	ko_total = 0
	combat.fight_active = true
	_lock_weapons(true)
	var w: int = int(_cp["wave"])
	var keep: Dictionary = _cp.duplicate()
	_start_wave(w)
	_cp = keep                               # the checkpoint stays where it was (auto_checkpoint saved the same wave anyway)


## End without a result: enemies freed, the HUD and the wheel back to normal.
func stop() -> void:
	_clear_enemies()
	_clear_props()
	state = "idle"
	_finish()
	_revive_if_down()


## A downed player (lost, then the story skips the retry) stands up again: PlayerCombat would keep him frozen in DOWN.
func _revive_if_down() -> void:
	if combat and is_instance_valid(combat) and combat.is_down():
		combat.revive()


## Ready to fight: off the bike, and the story phone closed (an open phone blocks the moves and [P] is refused now).
func _off_bike() -> void:
	if roam == null or not is_instance_valid(roam):
		return
	if bool(roam.get("mounted")) and roam.has_method("dismount_bike"):
		roam.call("dismount_bike")
	var sr: Object = roam.get("story_roam")
	var ph: Object = sr.get("phone") if sr else null
	if ph and ph.has_method("is_open") and bool(ph.call("is_open")):
		ph.call("close")


func alive() -> Array:
	var out: Array = []
	for e: Variant in enemies:
		if is_instance_valid(e) and not (e as MeleeEnemy).is_defeated():
			out.append(e)
	return out


## Enemies committed to an attack right now (ENGAGE, WINDUP, TELEGRAPH, ATTACK).
func attackers() -> int:
	var n: int = 0
	for e: Variant in enemies:
		if is_instance_valid(e) and (e as MeleeEnemy).is_attacking():
			n += 1
	return n


# ----- attack tokens (MeleeEnemy) -----
func request_token(e: Object) -> bool:
	if state != "running":
		return false
	if holders.has(e):
		return true
	for i: int in range(holders.size() - 1, -1, -1):
		if not is_instance_valid(holders[i]):
			holders.remove_at(i)
	if holders.size() >= max_attackers:
		return false
	holders.append(e)
	return true


func release_token(e: Object) -> void:
	holders.erase(e)


# ---------------------------------------------------------------------------
func _start_wave(i: int) -> void:
	_clear_enemies()
	_gap_left = -1.0
	wave = i
	if auto_checkpoint:
		checkpoint()
	var spawns: Array = waves[i]
	for s: Variant in spawns:
		var d: Dictionary = s
		var e: MeleeEnemy = (d["make"] as Callable).call() if d.has("make") else MeleeEnemy.new()
		e.name = "Enemy%d" % _spawned
		var o: Dictionary = (d.get("opts", {}) as Dictionary).duplicate()
		if not o.has("seed"):
			o["seed"] = fight_seed * 1000 + _spawned
		_spawned += 1
		e.setup(String(d.get("archetype", "clone")), o)
		var at: Vector3 = d.get("at", global_position)
		var yaw: float
		if d.has("yaw"):
			yaw = float(d["yaw"])
		else:
			var to: Vector3 = player.global_position - at
			yaw = atan2(-to.x, -to.z)
		e.top_level = true                       # global placement whatever the fight's own transform
		e.position = at + Vector3(0.0, 0.05, 0.0)
		add_child(e)
		e.set_yaw(yaw)
		e.bind(combat, self, enemies, combat.fx)
		if _staging:
			e.stage()
		e.ko.connect(_on_ko)
		e.fled.connect(_on_fled)
		enemies.append(e)
		combat.add_enemy(e)
		if bool(e.stats.get("boss", false)) and combat.boss == null:
			combat.boss = e
		if player.cam_ray:
			player.cam_ray.add_exception(e)
	wave_started.emit(i)


func _clear_enemies() -> void:
	_prepared = false
	for e: Variant in enemies:
		if combat.boss == e:
			combat.boss = null
		if is_instance_valid(e):
			combat.remove_enemy(e)
			if player and player.cam_ray:
				player.cam_ray.remove_exception(e)
			(e as Node).queue_free()
	enemies.clear()
	holders.clear()


func _on_ko(e: MeleeEnemy) -> void:
	ko_total += 1
	holders.erase(e)
	enemy_ko.emit(e)


func _on_fled(e: MeleeEnemy) -> void:
	holders.erase(e)
	enemy_fled.emit(e)


func _physics_process(delta: float) -> void:
	if state != "running":
		return
	_line_cd -= delta
	if force_unarmed:
		var mid: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		if mid and not _mid_prev:
			show_unarmed_line()
		_mid_prev = mid
		if weapons and weapons.current != WeaponData.Slot.UNARMED:
			weapons.equip(WeaponData.Slot.UNARMED)
	max_attackers_seen = maxi(max_attackers_seen, attackers())
	if combat.is_down():
		state = "lost"
		for e: Variant in enemies:
			if is_instance_valid(e):
				(e as MeleeEnemy).stand_down()
		holders.clear()
		_lock_weapons(false)
		lost.emit()
		return
	if _gap_left >= 0.0:
		_gap_left -= delta
		if _gap_left < 0.0:
			_start_wave(wave + 1)
		return
	for e: Variant in enemies:
		if is_instance_valid(e) and not (e as MeleeEnemy).is_defeated():
			return
	wave_cleared.emit(wave)
	if wave + 1 < waves.size():
		_gap_left = WAVE_GAP_S
	else:
		state = "won"
		_finish()
		won.emit()


func _finish() -> void:
	if combat:
		combat.fight_active = false
		if combat.last_fn == Callable(self, "_is_last"):
			combat.last_fn = Callable()
		if combat.boss != null and enemies.has(combat.boss):
			combat.boss = null                   # the boss bar goes with the fight (won / stop)
	_lock_weapons(false)


## Force unarmed: Tay không equipped and the WeaponDirector locked (wheel and scroll blocked through its is_blocked()).
func _lock_weapons(on: bool) -> void:
	if not force_unarmed or weapons == null:
		return
	if on and not _locked:
		_prev_locked = weapons.locked
		weapons.equip(WeaponData.Slot.UNARMED)
		weapons.locked = true
		_locked = true
	elif not on and _locked:
		weapons.locked = _prev_locked
		_locked = false


# ---------------------------------------------------------------------------
# Q2: the last enemy, improvised weapons
# ---------------------------------------------------------------------------
## The knockout of `e` ends the fight: the last wave runs and no other enemy of it is still fighting.
func _is_last(e: Object) -> bool:
	if state != "running" or wave < waves.size() - 1:
		return false
	for x: Variant in enemies:
		if x != e and is_instance_valid(x) and not (x as MeleeEnemy).is_defeated():
			return false
	return true


## An improvised weapon on the floor at `at` ("chair" | "tray" | "helmet" | "lid"), pickable with [E].
func add_prop(kind: String, at: Vector3, yaw: float = 0.0) -> ImprovisedWeapon:
	var p := ImprovisedWeapon.new()
	p.setup(kind)
	p.top_level = true
	p.position = at
	p.rotation.y = yaw
	p.home = at
	p.home_yaw = yaw
	add_child(p)
	props.append(p)
	if combat:
		combat.add_prop(p)
	return p


func _spawn_props() -> void:
	if not props.is_empty() or props_spec.is_empty():
		return
	for d: Variant in props_spec:
		var dd: Dictionary = d
		add_prop(String(dd.get("kind", "chair")), dd.get("at", global_position), float(dd.get("yaw", 0.0)))


func _clear_props() -> void:
	if combat and combat.held_prop != null and props.has(combat.held_prop):
		combat.drop_prop()
	for p: Variant in props:
		if combat:
			combat.props.erase(p)
		if is_instance_valid(p):
			(p as Node).queue_free()
	props.clear()


## The force-unarmed line (the player tried the wheel or scrolled), at most every LINE_COOLDOWN_S.
func show_unarmed_line() -> void:
	if _line_cd > 0.0:
		return
	_line_cd = LINE_COOLDOWN_S
	unarmed_lines += 1
	if weapons and weapons.hud:
		weapons.hud.show_toast(CombatData.T_UNARMED_ONLY)
	elif combat and combat.hud:
		combat.hud.popup(CombatData.T_UNARMED_ONLY, CombatHUD.WARN)


func _input(event: InputEvent) -> void:
	if combat == null or not combat.fight_active:
		return
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo and (k.physical_keycode == KEY_P or k.physical_keycode == KEY_B):
			_refuse(CombatData.T_FIGHT_PHONE if k.physical_keycode == KEY_P else CombatData.T_FIGHT_EMOTE)
			get_viewport().set_input_as_handled()
		return
	if state != "running" or not force_unarmed or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_MIDDLE):
		show_unarmed_line()


## A refused key during the fight: a short hint (FreeRoam's hint line, else a combat popup).
func _refuse(text: String) -> void:
	refusals += 1
	if roam and is_instance_valid(roam) and roam.has_method("flash_hint"):
		roam.call("flash_hint", text)
	elif combat and combat.hud:
		combat.hud.popup(text, CombatHUD.WARN)


func _exit_tree() -> void:
	if state == "running":
		_finish()
	_revive_if_down()
	if combat and is_instance_valid(combat):
		if combat.last_fn == Callable(self, "_is_last"):
			combat.last_fn = Callable()
		if combat.held_prop != null and props.has(combat.held_prop):
			combat.drop_prop()
		for p: Variant in props:
			combat.props.erase(p)
		for e: Variant in enemies:
			if combat.boss == e:
				combat.boss = null
			if is_instance_valid(e):
				combat.remove_enemy(e)
			else:
				combat.enemies.erase(e)
		combat.fight_active = false
