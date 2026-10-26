# File: res://scripts/combat/swords/SwordDuel.gd
# Encounter node of the Phase C sword duel (spec C-D3 / C-D4 Day 5): the player's Vovinam staff against Lê Minh Za Mẫn's
# katana. Built on the Phase B combat: one MeleeFight (checkpoint, retry, lost / won, force unarmed, the [F] / [P] / [B]
# refusals, the HUD) with a single KatanaBoss, and the player's PlayerCombat switched to the staff move set.
#
# ===== API (for the story integration) =====
#   var duel := SwordDuel.new()
#   roam.add_child(duel)                        # any Node3D parent; FreeRoam is the usual one
#   duel.setup({"roam": roam,                   # FreeRoam (player, combat, weapons read from it), or "player"
#                                               #   (ThirdPersonController) [+ "combat", "weapons"]; without a combat one is built
#       "at": Vector3(...),                     # Za Mẫn's spot (default: 5 m in front of the player)
#       "yaw": 0.0,                             # optional (default: faces the player)
#       "boss": {"label": "Lê Minh Za Mẫn",     # KatanaBoss opts (MeleeEnemy opts): "body" (CharacterBuilder opts over his
#                "body_fn": Callable(look) -> rigged Node3D,   #   default look), "body_fn" (StoryCast look), "stats"
#                "stats": {...}, "hp_scale": 1.0},             #   (SwordData.ZA_MAN overrides), "seed", "ai"
#       "start_line": "",                       # centre popup at start() ("" = none)
#       "seed": 5})
#   duel.prepare()                              # optional: Za Mẫn appears now (villain card), standing in his guard,
#                                               #   invulnerable, until start()
#   duel.won.connect(...)                       # the katana snapped and he is knocked out (after the comic finale); the
#                                               #   staff is put away and the unarmed moves are back at that moment
#   duel.lost.connect(...)                      # the player's HP reached 0 (show "TOANG!", then call retry())
#   duel.phase_changed.connect(func(phase: int): ...)   # 2 at 66 % HP, 3 at 33 %
#   duel.start()
#   duel.retry()                                # a fresh Za Mẫn (phase 1, straight katana), HP 100, the player back at the
#                                               #   start spot
#   duel.stop()                                 # end without a result: boss freed, unarmed moves and wheel back
#   duel.state                                  # "idle" | "running" | "won" | "lost"; duel.phase (1..3); duel.boss
# The staff (and the staff move set: LMB 3 slashes, RMB thrust, hold Q block, perfect block = parry, Space dodge within
# 14 m, E finisher on a dazed Za Mẫn) is in the player's hand from start() / retry() until `won`, stop() or freeing the
# duel (the knocked-out boss stays until stop() or free).
# The boss bar shows while the duel runs. The duel never changes the story state, the time of day or the camera; it never
# references an autoload.
# ===========================================
class_name SwordDuel
extends Node3D

signal won
signal lost
signal phase_changed(phase: int)

var fight: MeleeFight
var combat: PlayerCombat
var player: ThirdPersonController
var boss: KatanaBoss = null
var phase: int = 1
var state: String = "idle"
var staff: Node3D = null
var _staff_pivot: Node3D = null
var _armed: bool = false


func setup(opts: Dictionary) -> void:
	fight = MeleeFight.new()
	fight.name = "DuelFight"
	add_child(fight)
	var fo: Dictionary = {"force_unarmed": true, "max_attackers": 1, "auto_checkpoint": true,
		"start_line": String(opts.get("start_line", "")), "seed": int(opts.get("seed", 5))}
	for k: String in ["roam", "player", "combat", "weapons"]:
		if opts.has(k):
			fo[k] = opts[k]
	fight.setup(fo)
	combat = fight.combat
	player = fight.player
	SwordAudio.warm()
	var at: Vector3 = opts.get("at", player.global_position + player.facing_dir() * 5.0 if player else Vector3.ZERO)
	var spawn: Dictionary = {"archetype": "za_man", "make": func() -> MeleeEnemy: return KatanaBoss.new(), "at": at,
		"opts": (opts.get("boss", {}) as Dictionary).duplicate()}
	if opts.has("yaw"):
		spawn["yaw"] = float(opts["yaw"])
	fight.add_wave([spawn])
	fight.wave_started.connect(_on_wave)
	fight.won.connect(_on_won)
	fight.lost.connect(_on_lost)


## Spawn Za Mẫn before the fight (a villain card can frame him): he stands in his guard, invulnerable, until start().
func prepare() -> void:
	if fight == null or combat == null or state == "running":
		return
	fight.prepare()


func start() -> void:
	if fight == null or combat == null:
		push_warning("SwordDuel.start: setup() first")
		return
	_arm(true)
	state = "running"
	fight.start()


## After `lost` (or any time): a fresh boss, the player back at the start spot with full HP.
func retry() -> void:
	if fight == null:
		return
	_arm(true)
	state = "running"
	fight.retry()


## End without a result: the boss freed, the unarmed move set, the wheel and the HUD back to normal.
func stop() -> void:
	if fight:
		fight.stop()
	state = "idle"
	boss = null
	phase = 1
	_arm(false)


func _on_wave(_i: int) -> void:
	boss = fight.enemies[0] as KatanaBoss if not fight.enemies.is_empty() else null
	phase = 1
	if boss:
		boss.phase_changed.connect(_on_phase)


func _on_phase(ph: int) -> void:
	phase = ph
	phase_changed.emit(ph)


func _on_won() -> void:
	state = "won"
	_arm(false)                                  # the staff goes away with the win: nothing left glued to the hand
	won.emit()


func _on_lost() -> void:
	state = "lost"
	lost.emit()


## The staff move set and the staff in the right hand (on), or the unarmed set and no staff (off).
func _arm(on: bool) -> void:
	if combat == null or not is_instance_valid(combat):
		return
	if on and not _armed:
		combat.set_moveset(SwordData.STAFF)
		if player and player.model:
			staff = SwordProps.staff()
			_staff_pivot = SwordProps.attach_to_hand(player.model, staff, SwordData.STAFF_TILT)
		_armed = true
	elif not on and _armed:
		combat.reset_moveset()
		SwordProps.detach(_staff_pivot)
		_staff_pivot = null
		staff = null
		_armed = false


func _exit_tree() -> void:
	_arm(false)
