# File: res://scripts/combat/PlayerCombat.gd
# The player's unarmed Vovinam combat (story Phase B, spec B-D1). Lives next to the player (FreeRoam builds one in
# _build_mayhem; MeleeFight builds its own when the scene has none). While Tay không is equipped (or with no WeaponDirector):
#   - left mouse: light combo jab -> cross -> elbow (each press after the previous impact chains; 0.5 s after a move ends the
#     combo is forgotten; after the elbow it starts again);
#   - right mouse: heavy kick (đá tạt): every enemy in its 70° arc, breaks blocks, knocks a staggered enemy down;
#   - hold Q: block (speed capped). Pressed at most 0.2 s before an enemy hit lands = perfect block: automatic
#     counter-strike "PHẢN ĐÒN" (a press arms it only after Q was up 0.35 s: no mashing). Telegraphed heavies go through
#     any block;
#   - Space with a hostile within 6 m: dodge-roll (0.35 s invulnerable) through ThirdPersonController.jump_filter; Space
#     jumps otherwise;
#   - E on a dazed enemy within 2.2 m: takedown finisher (throw or sweep, alternating) with 0.3 real seconds of slow motion;
#     that E press is consumed (set_input_as_handled), so a story marker or a call never gets it too;
#   - soft lock-on: the nearest hostile in front (input direction, else the body's facing) within 7 m, 2.5 m any direction
#     as a fallback; attacks turn to it and step in up to 0.9 m.
# HP 100, regenerates 10 HP/s after 4 s without damage; 0 = `down` (the player is knocked down and stays out of the fight
# until revive(); MeleeFight.retry() / stop() / freeing the fight revive). A weapon switched in mid-move cancels the move.
# The HUD hides while paused or disabled (cinematics) and comes back on the next physics frame. Enemies attack through receive_attack(). Pedestrians and officers (targets_fn) keep the Phase W
# reactions: light hits use the Phase W combo (stumble, stumble, knock out within 1.5 s), the heavy kick knocks out, +1
# heat per knockout (WeaponDirector.mayhem when there is one, else this node's `mayhem`); they never fight back.
# The WeaponDirector (optional) gets unarmed_owner = self: its own punch and right-mouse aim stay off while unarmed.
# Engine.time_scale is written only through RadialWheel.scale_owner (a wheel that owns the time scale wins; restored on exit).
# Test hooks: light_override / heavy_override / finisher_override (one press each), block_override (held), god (no damage).
# Move set (Phase C, spec C-D3): set_moveset(d) swaps the moves, texts, poses and sounds (SwordDuel puts in the Vovinam
# staff of SwordData.STAFF); reset_moveset() restores the unarmed defaults below. A move's optional "pose" key plays that
# code pose once over the move (CombatPose), `idle_pose` is held while idle. `boss` (set by MeleeFight / SwordDuel) gets
# the HUD's boss bar.
# Q2 feel (plan 2026-10-29-q2-feel.md T2): every landed strike goes through Impact.hit with a tier (strike_tier: jab / cross
# light; elbow-daze, heavy kick, counter, guard break, knockdown, improvised weapons heavy; a knockout finisher), the
# enemy's impact_react giving the directional reaction and knockback; hits on the player get a hit-stop, a camera jolt and a
# red edge flash; blocked hits spark (a clash). The finisher's slow motion runs on the Impact clock after its freeze;
# last_fn (MeleeFight) marks the last enemy, whose knockout gets the 0.5 s slow-motion orbit instead. [E] priorities: a dazed
# enemy in reach = finisher, else a staggered / blocking / recovering one within THROW_RANGE = throw (St.THROW), else an
# improvised weapon within PICKUP_R = pick it up (props: add_prop / remove_prop; held_prop swaps the move set until it
# breaks; drop_prop() for retries).
# Autoloads are never referenced here.
class_name PlayerCombat
extends Node

signal down
signal hp_changed(hp: float)
signal attack_started(kind: String, target: Node3D)
signal hit_landed(target: Node3D, kind: String, result: String)
signal countered(enemy: Node3D)
signal finisher(enemy: Node3D)
signal mayhem(heat: float, at: Vector3, cause: String)

enum St { IDLE, LIGHT, HEAVY, COUNTER, FINISHER, HITSTUN, DODGE, DOWN, THROW }

const LOG_MAX: int = 64
const TRACK_TURN: float = 12.0

var player: ThirdPersonController
var weapons: WeaponDirector
var targets_fn: Callable
var blocked_fn: Callable
var hud: CombatHUD
var fx: WeaponFX
var pose: CombatPose
var enabled: bool = true
## A MeleeFight is running (the HUD shows; set by MeleeFight).
var fight_active: bool = false
var hp: float = CombatData.PLAYER_HP
var max_hp: float = CombatData.PLAYER_HP
var state: int = St.IDLE
var state_t: float = 0.0
var move: Dictionary = {}
var combo_i: int = -1
var hit_done: bool = false
var queued: String = ""
var blocking: bool = false
var invuln_left: float = 0.0
var since_damage: float = 99.0
var lock: Node3D = null
var strike_target: Node3D = null
var enemies: Array = []
var god: bool = false
var light_override: bool = false
var heavy_override: bool = false
var finisher_override: bool = false
var block_override: Variant = null
## Every resolved strike and incoming attack (last LOG_MAX): {"t", "kind", "target", "result"}.
var strikes: Array[Dictionary] = []
var finishers: int = 0
var slowmo_count: int = 0
var _t: float = 0.0
var _last_end: float = -99.0
var _face_yaw: float = 0.0
var _block_press_t: float = -99.0
var _q_prev: bool = false
var _lmb_prev: bool = false
var _rmb_prev: bool = false
var _e_event: bool = false               # an E press for a finisher (consumed in _input)
var _q_release_t: float = -99.0
## E presses this node consumed for a finisher (tests).
var e_consumed: int = 0
var _mouse_block: bool = true
var _was_captured: bool = false
var _dodge_cd: float = 0.0
var _chase_left: float = 0.0
var _dt: float = 1.0 / 60.0
var _slow_left: float = 0.0
var _fin_target: Node3D = null
var _fin_kind: String = ""
var _ped_combo: Dictionary = {}          # pedestrian instance id -> [hits, game time of the last]
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
## The fight's boss (CombatHUD draws its boss bar); null = none.
var boss: Node3D = null
# ----- move set (defaults: unarmed Vovinam; set_moveset() / reset_moveset()) -----
var light_moves: Array = CombatData.LIGHT
var heavy_move: Dictionary = CombatData.HEAVY
var counter_move: Dictionary = CombatData.COUNTER
var controls_text: String = CombatData.T_CONTROLS
var counter_text: String = CombatData.T_COUNTER
var block_pose: String = "block"
var idle_pose: String = ""
var dodge_m: float = CombatData.DODGE_HOSTILE_M
## Wave 3 knobs (plan 2026-10-30-w3-shared.md): seconds without damage before HP regenerates (GunFight sets the gun
## difficulty value while it runs and restores this default) and a factor on the dodge-roll speed (Day 5's puddles).
var regen_delay: float = CombatData.REGEN_DELAY
var dodge_speed_k: float = 1.0
## Landed hits spark as well as raising dust (blades).
var blade: bool = false
## Sound remap {cue: cue} applied by _cue (the staff's clash instead of the punch...).
var cue_map: Dictionary = {}
## The cues _cue played (after the remap; last 32, tests).
var cues: Array[String] = []
## Q2: the last enemy test (MeleeFight: Callable(enemy) -> bool), throws, improvised weapons on the floor and in the hand.
var last_fn: Callable = Callable()
var throws: int = 0
var props: Array = []
var held_prop: ImprovisedWeapon = null
var prop_picks: int = 0
var prop_breaks: int = 0
## The tiers of the landed strikes (last 32, tests).
var tiers: Array[String] = []
var _throw_target: Node3D = null


func _ready() -> void:
	process_physics_priority = 5         # after ThirdPersonController (0): its turn / move of this frame is overridden
	Impact.prepare(self)                 # Q2: the clock and the sound layers ready before the first hit
	for i: int in 4:
		var p := AudioStreamPlayer3D.new()
		p.name = "CombatSfx%d" % i
		p.bus = WeaponAudio.bus()
		p.max_distance = 80.0
		p.unit_size = 6.0
		add_child(p)
		_sfx.append(p)
	for c: String in CombatData.CINE_CUES:
		CineAudio.sfx(c)
	for c2: String in ["punch", "swish", "knife_hit", "bonk"]:
		WeaponAudio.stream(c2)


## The slow motion never outlives a pause (a cinematic right after a finisher pauses the tree) or a disabled combat.
## The HUD hides too (FreeRoam's cinematic pauses the tree and only hides its own list); _physics_process shows it again.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_DISABLED:
		_end_slowmo()
		if hud:
			hud.visible = false


func _exit_tree() -> void:
	_end_slowmo()
	if player and is_instance_valid(player):
		player.combat_speed_cap = INF
		if player.jump_filter == Callable(self, "try_dodge"):
			player.jump_filter = Callable()


## opts: player (ThirdPersonController, required), weapons (WeaponDirector), targets_fn (-> Array of pedestrians /
## officers), blocked_fn (-> bool). Call after add_child.
func setup(opts: Dictionary) -> void:
	player = opts.get("player")
	weapons = opts.get("weapons")
	targets_fn = opts.get("targets_fn", Callable())
	blocked_fn = opts.get("blocked_fn", Callable())
	if weapons:
		weapons.unarmed_owner = self
		fx = weapons.fx
	if fx == null:
		fx = WeaponFX.new()
		fx.name = "CombatFX"
		add_child(fx)
	if player:
		player.jump_filter = try_dodge
		pose = CombatPose.attach(player.model)
	hud = CombatHUD.new()
	hud.name = "CombatHUD"
	hud.combat = self
	add_child(hud)


## Swap the move set. Keys (each optional; a missing key keeps the unarmed default): light (Array of moves), heavy,
## counter (moves as in CombatData, plus an optional "pose"), controls, counter_text, block_pose, idle_pose, dodge_m, blade,
## cues ({cue: cue}). The move in flight is dropped.
func set_moveset(d: Dictionary) -> void:
	if player != null and (state == St.LIGHT or state == St.HEAVY or state == St.COUNTER):
		_cancel_move()
	light_moves = d.get("light", CombatData.LIGHT)
	heavy_move = d.get("heavy", CombatData.HEAVY)
	counter_move = d.get("counter", CombatData.COUNTER)
	controls_text = String(d.get("controls", CombatData.T_CONTROLS))
	counter_text = String(d.get("counter_text", CombatData.T_COUNTER))
	block_pose = String(d.get("block_pose", "block"))
	idle_pose = String(d.get("idle_pose", ""))
	dodge_m = float(d.get("dodge_m", CombatData.DODGE_HOSTILE_M))
	blade = bool(d.get("blade", false))
	cue_map = d.get("cues", {})
	combo_i = -1
	if pose:
		pose.clear()


## Back to the unarmed Vovinam move set.
func reset_moveset() -> void:
	set_moveset({})


# ---------------------------------------------------------------------------
# ENEMIES
# ---------------------------------------------------------------------------
func add_enemy(e: Node3D) -> void:
	if not enemies.has(e):
		enemies.append(e)


func remove_enemy(e: Node3D) -> void:
	enemies.erase(e)
	if lock == e:
		lock = null
	if strike_target == e:
		strike_target = null


func clear_enemies() -> void:
	enemies.clear()
	lock = null
	strike_target = null


static func _alive(e: Variant) -> bool:
	return e != null and is_instance_valid(e) and (e as Node).is_inside_tree() and bool((e as Object).call("is_hostile"))


## A hostile enemy (not knocked out, fled or down) within r metres of the player.
func hostile_near(r: float) -> bool:
	return _nearest_hostile(r) != null


func _nearest_hostile(r: float) -> Node3D:
	if player == null:
		return null
	var best: Node3D = null
	var bd: float = r
	for e: Variant in enemies:
		if not _alive(e) or bool((e as Object).call("is_down")):
			continue
		var d: float = WeaponMath.flat((e as Node3D).global_position, player.global_position)
		if d <= bd:
			bd = d
			best = e
	return best


## Soft lock-on: the hostile in front of the player (input direction, else the body's facing) within LOCK_RANGE and
## LOCK_HALF_DEG with the lowest distance x angle score (the current lock scores 30 % better: no flicker), else the nearest
## within LOCK_CLOSE in any direction.
func lock_target() -> Node3D:
	if player == null or enemies.is_empty():
		return null
	var ref: Vector3 = _input_dir()
	if ref.length_squared() < 0.01:
		ref = player.facing_dir()
	var half: float = deg_to_rad(CombatData.LOCK_HALF_DEG)
	var best: Node3D = null
	var best_s: float = INF
	var close: Node3D = null
	var close_d: float = CombatData.LOCK_CLOSE
	var pp: Vector3 = player.global_position
	for e: Variant in enemies:
		if not _alive(e) or bool((e as Object).call("is_down")):
			continue
		var n: Node3D = e
		var d: float = WeaponMath.flat(n.global_position, pp)
		if d > CombatData.LOCK_RANGE:
			continue
		if d <= close_d:
			close_d = d
			close = n
		var ang: float = acos(clampf(ref.dot(WeaponMath.flat_dir(n.global_position - pp)), -1.0, 1.0))
		if ang > half:
			continue
		var s: float = d * (1.0 + ang) * (0.7 if n == lock else 1.0)
		if s < best_s:
			best_s = s
			best = n
	return best if best != null else close


## The nearest dazed enemy within FINISHER_RANGE (null = none).
func finisher_target() -> Node3D:
	if player == null:
		return null
	var best: Node3D = null
	var bd: float = CombatData.FINISHER_RANGE
	for e: Variant in enemies:
		if not _alive(e) or not bool((e as Object).call("is_dazed")):
			continue
		var d: float = WeaponMath.flat((e as Node3D).global_position, player.global_position)
		if d <= bd:
			bd = d
			best = e
	return best


func is_down() -> bool:
	return state == St.DOWN


## The player can be attacked (enemies only commit to attacks then): not down, not lying after a knock-down, on foot.
func can_be_attacked() -> bool:
	return state != St.DOWN and player != null and player.visible and not player.is_knocked_down()


## Back on the feet with full (or the given) HP: state, queue, block and slow motion cleared.
func revive(hp_v: float = CombatData.PLAYER_HP) -> void:
	hp = clampf(hp_v, 1.0, max_hp)
	state = St.IDLE
	state_t = 0.0
	queued = ""
	blocking = false
	combo_i = -1
	invuln_left = 0.0
	since_damage = 99.0
	if _fin_target != null and is_instance_valid(_fin_target) and _fin_target.has_method("release_hold"):
		_fin_target.call("release_hold")
	_fin_target = null
	_release_throw()
	_end_slowmo()
	if pose:
		pose.reset()
	hp_changed.emit(hp)


# ---------------------------------------------------------------------------
# FRAME
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	_dt = delta
	if player == null or not is_instance_valid(player):
		return
	state_t += delta
	invuln_left = maxf(0.0, invuln_left - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	since_damage += delta
	if state != St.DOWN and since_damage >= regen_delay and hp < max_hp:
		hp = minf(max_hp, hp + CombatData.REGEN_RATE * delta)
		hp_changed.emit(hp)
	var blocked: bool = blocked_fn.is_valid() and bool(blocked_fn.call())   # once per frame
	var can: bool = _can_act(blocked)
	if weapons != null and weapons.current != WeaponData.Slot.UNARMED and (state == St.LIGHT or state == St.HEAVY or state == St.COUNTER or state == St.FINISHER or state == St.THROW):
		_cancel_move()                       # a weapon switched in mid-move: the pending hit never lands
	var light: bool = _light_edge(can)
	var heavy: bool = _heavy_edge(can)
	var fin: bool = _finisher_edge(can)
	var blk: bool = _block_held(can)
	lock = lock_target() if can else null
	match state:
		St.IDLE:
			_idle(light, heavy, fin, blk)
		St.LIGHT, St.HEAVY, St.COUNTER:
			_attacking(light, heavy, fin, blk)
		St.FINISHER:
			_finishing()
		St.THROW:
			_throwing()
		St.HITSTUN:
			if state_t >= CombatData.HITSTUN_S and not player.is_knocked_down():
				_to_idle()
		St.DODGE:
			if player.move_state != "LAND_ROLL" or state_t >= CombatData.DODGE_S + 0.05:
				_dodge_cd = CombatData.DODGE_COOLDOWN
				_to_idle()
	_apply_body()
	if hud:
		var shown: bool = fight_active or hp < max_hp - 0.01 or state == St.DOWN
		hud.visible = shown and enabled and player.visible and not blocked


func _can_act(blocked: bool = false) -> bool:
	if not enabled or not player.visible or not player.controls_enabled or blocked:
		return false
	if weapons != null:
		if weapons.current != WeaponData.Slot.UNARMED:
			return false
		if weapons.wheel != null and weapons.wheel.is_open():
			return false
	return true


func _idle(light: bool, heavy: bool, fin: bool, blk: bool) -> void:
	blocking = blk
	if blocking:
		return
	var ft: Node3D = finisher_target() if fin else null
	var tt: Node3D = throw_target() if fin and ft == null else null
	var pt: ImprovisedWeapon = prop_target() if fin and ft == null and tt == null else null
	if ft != null:
		_start_finisher(ft)
	elif tt != null:
		_start_throw(tt)
	elif pt != null:
		_pick_prop(pt)
	elif heavy:
		_start_move(heavy_move, St.HEAVY)
	elif light:
		_start_light(false)


func _attacking(light: bool, heavy: bool, fin: bool, blk: bool) -> void:
	blocking = false
	if light and state == St.LIGHT:
		queued = "light"
	elif heavy:
		queued = "heavy"
	elif light and queued == "":
		queued = "light"
	if fin:
		queued = "finisher"
	if not hit_done:
		_track(strike_target, float(move.get("reach", 1.5)))
	if not hit_done and state_t >= float(move.get("hit", 0.0)):
		hit_done = true
		_resolve_hit()
	if state != St.LIGHT and state != St.HEAVY and state != St.COUNTER:
		return                               # the hit changed the state (should not, but stay safe)
	var after: float = float(move.get("hit", 0.0)) + CombatData.CHAIN_AFTER_HIT
	if hit_done and state_t >= after:
		if blk and queued == "":
			_to_idle()
			blocking = true                  # block cancels the recovery
			return
		if queued == "finisher":
			var ft: Node3D = finisher_target()
			if ft != null:
				_start_finisher(ft)
				return
			queued = ""
		if queued == "heavy":
			_start_move(heavy_move, St.HEAVY)
			return
		if queued == "light" and state == St.LIGHT and combo_i < light_moves.size() - 1:
			_start_light(true)
			return
	if state_t >= float(move.get("dur", 0.3)):
		var q: String = queued
		_last_end = _t
		_to_idle()
		if q == "light":
			_start_light(false)
		elif q == "heavy":
			_start_move(heavy_move, St.HEAVY)


## Drop the move in flight (its hit never lands); a held finisher target is let go.
func _cancel_move() -> void:
	if state == St.FINISHER and _fin_target != null and is_instance_valid(_fin_target) and _fin_target.has_method("release_hold"):
		_fin_target.call("release_hold")
	_fin_target = null
	_release_throw()
	hit_done = true
	if player.model:
		CharacterBuilder.stop_clip(player.model)
	if pose:
		pose.clear()
	_to_idle()


func _to_idle() -> void:
	state = St.IDLE
	state_t = 0.0
	queued = ""
	move = {}


func _start_light(chain: bool) -> void:
	var i: int = 0
	if chain:
		i = combo_i + 1
	elif combo_i >= 0 and combo_i < light_moves.size() - 1 and _t - _last_end <= CombatData.COMBO_GRACE:
		i = combo_i + 1
	combo_i = clampi(i, 0, light_moves.size() - 1)
	_start_move(light_moves[combo_i], St.LIGHT)


func _start_move(m: Dictionary, st: int) -> void:
	if st == St.HEAVY:
		combo_i = -1
	state = st
	state_t = 0.0
	move = m
	hit_done = false
	queued = ""
	blocking = false
	strike_target = lock
	_face(strike_target)
	_chase_left = CombatData.LUNGE_MAX
	_track(strike_target, float(m.get("reach", 1.5)))
	_move_clip(m)
	_move_pose(m)
	_cue("whoosh_down" if st == St.HEAVY else "swish", player.global_position + Vector3(0.0, 1.2, 0.0), -8.0)
	var kind: String = String(m["id"])
	attack_started.emit(kind, strike_target)
	var eta: float = float(m["hit"])
	if st == St.HEAVY:
		var fwd: Vector3 = player.facing_dir()
		for e: Variant in enemies:
			if _alive(e) and WeaponMath.in_cone(player.global_position, fwd, deg_to_rad(float(m["half_deg"])), float(m["reach"]) + 1.0, (e as Node3D).global_position):
				(e as Object).call("on_player_attack", kind, eta)
	elif strike_target != null and _alive(strike_target):
		strike_target.call("on_player_attack", kind, eta)


## The move's pack clip fitted to its impact; clip "" (a staff thrust: the punch clip's body twist would turn the staff
## away) stops the one-shot clip and lets the code pose carry the move.
func _move_clip(m: Dictionary) -> void:
	if String(m["clip"]) == "":
		CharacterBuilder.stop_clip(player.model)
		return
	CombatData.play_clip(player.model, String(m["clip"]), float(m["dur"]), float(m.get("from", 0.0)), float(m.get("hit_at", -1.0)), float(m["hit"]))


## The move's code pose ("pose" key) played once over the move, else the pose layer eases out (unarmed moves).
func _move_pose(m: Dictionary) -> void:
	if pose == null:
		return
	if m.has("pose"):
		pose.set_pose(String(m["pose"]), 0.0, float(m["dur"]))
	else:
		pose.clear()


## Hit frame: enemies first (the heavy kick hits every one in its arc; a light move the strike target if it is still in
## reach, else the nearest in front), else the nearest pedestrian / officer in the Phase W unarmed cone, else a swish.
func _resolve_hit() -> void:
	var info: Dictionary = {"kind": String(move["id"]), "dmg": float(move["dmg"]), "stagger": float(move["stagger"]),
		"push": float(move.get("push", 0.3)), "breaks_block": bool(move.get("breaks_block", false)), "from": player.global_position}
	var pp: Vector3 = player.global_position
	var fwd: Vector3 = player.facing_dir()
	var reach: float = float(move.get("reach", 1.5)) + CombatData.ENEMY_RADIUS
	var hit_any: bool = false
	if state == St.HEAVY:
		var half: float = deg_to_rad(float(move["half_deg"]))
		for e: Variant in enemies.duplicate():
			if _alive(e) and WeaponMath.in_cone(pp, fwd, half, reach, (e as Node3D).global_position):
				_strike(e, info)
				hit_any = true
	else:
		var t: Node3D = null
		if strike_target != null and _alive(strike_target) and WeaponMath.in_cone(pp, fwd, deg_to_rad(80.0), reach + 0.2, strike_target.global_position):
			t = strike_target
		else:
			var bd: float = INF
			var half2: float = deg_to_rad(float(move.get("half_deg", 60.0)))
			for e2: Variant in enemies:
				if not _alive(e2):
					continue
				var n: Node3D = e2
				if not WeaponMath.in_cone(pp, fwd, half2, reach, n.global_position):
					continue
				var d: float = WeaponMath.flat(n.global_position, pp)
				if d < bd:
					bd = d
					t = n
		if t != null:
			_strike(t, info)
			hit_any = true
	if not hit_any:
		hit_any = _hit_people(state == St.HEAVY)
	if not hit_any:
		_cue("swish", pp + fwd * 0.8 + Vector3(0.0, 1.2, 0.0), -4.0)


func _strike(e: Node3D, info: Dictionary) -> String:
	var r: String = String(e.call("take_strike", info))
	var kind: String = String(info["kind"])
	_log(kind, e, r)
	var at: Vector3 = e.global_position + Vector3(0.0, 1.3, 0.0)
	var dir: Vector3 = WeaponMath.flat_dir(e.global_position - player.global_position)
	if dir.length_squared() < 0.01:
		dir = player.facing_dir()
	match r:
		"blocked":
			_cue("punch", at, -10.0)
			Impact.particles(self, "sparks", at, -player.facing_dir(), 0.7 if blade else 0.4, fx)   # a clash
			if blade:
				Impact.punch(self, 0.12, dir)
		"dodged", "ignored":
			_cue("swish", at, -4.0)
		_:
			var tier: String = strike_tier(kind, r)
			_cue("impact_heavy" if tier != "light" else "impact_light", at, 0.0 if tier != "light" else -3.0)
			var extra: Array = [["keng", 2.0]] if r == "parried" else []
			Impact.hit(self, tier, {"pos": at, "dir": dir, "target": e, "fx": fx, "last": r == "ko" and is_last(e), "cues": extra, "result": r})
			tiers.append(tier)
			if tiers.size() > 32:
				tiers.pop_front()
			if blade and tier == "light":
				Impact.particles(self, "sparks", at, -player.facing_dir(), 0.5, fx)
			if r == "guard_break" and hud:
				hud.popup(CombatData.T_GUARD_BREAK, CombatHUD.WARN)
			if held_prop != null and kind.begins_with("prop_"):
				_use_prop()
	hit_landed.emit(e, kind, r)
	return r


## The Impact tier of a landed strike: a knockout is the finisher tier; the heavy kick / staff thrust, a counter or parry,
## an improvised weapon, and hits that knock down, break the guard, daze or make Sói Xám howl are heavy; the rest light.
func strike_tier(kind: String, r: String) -> String:
	if r == "ko":
		return "finisher"
	if kind == String(heavy_move["id"]) or kind == String(counter_move["id"]) or kind == "counter" or kind.begins_with("prop_"):
		return "heavy"
	if r == "knockdown" or r == "guard_break" or r == "daze" or r == "parried" or r == "howl" or r == "flee":
		return "heavy"
	return "light"


## The last enemy of the fight (MeleeFight's last_fn): its knockout gets the slow-motion orbit.
func is_last(e: Object) -> bool:
	return last_fn.is_valid() and bool(last_fn.call(e))


## Pedestrians and officers (Phase W reactions): the nearest one in the unarmed cone. Light = Phase W combo ("punch" twice,
## then "melee" within PED_COMBO_S), heavy = "melee". +1 heat for a knockout.
func _hit_people(heavy: bool) -> bool:
	if not targets_fn.is_valid():
		return false
	var pp: Vector3 = player.global_position
	var fwd: Vector3 = player.facing_dir()
	var half: float = deg_to_rad(CombatData.PED_HALF_DEG)
	var best: Node3D = null
	var bd: float = INF
	for v: Variant in targets_fn.call():
		if not is_instance_valid(v) or not (v as Node).is_inside_tree() or not (v as Node).has_method("take_hit"):
			continue
		var n: Node3D = v
		if n.has_method("is_down") and bool(n.call("is_down")):
			continue
		if not WeaponMath.in_cone(pp, fwd, half, CombatData.PED_REACH, n.global_position):
			continue
		var d: float = WeaponMath.flat(n.global_position, pp)
		if d < bd:
			bd = d
			best = n
	for key0: Variant in _ped_combo.keys():   # forget combos older than PED_COMBO_S (bounded)
		if _t - float((_ped_combo[key0] as Array)[1]) > CombatData.PED_COMBO_S:
			_ped_combo.erase(key0)
	if best == null:
		return false
	var info: Dictionary = {"kind": "melee", "from": pp}
	if not heavy:
		var key: int = best.get_instance_id()
		var c: Array = _ped_combo.get(key, [0, -99.0])
		var count: int = (int(c[0]) if _t - float(c[1]) <= CombatData.PED_COMBO_S else 0) + 1
		_ped_combo[key] = [count, _t]
		if count < 3:
			info["kind"] = "punch"
		else:
			_ped_combo.erase(key)
	var r: String
	if weapons:
		r = weapons.hit_target(best, info)
	else:
		r = String(best.call("take_hit", info))
		if r == "knocked_out":
			var ko: Variant = best.get("ko_left")
			fx.stars(best, float(ko) if ko != null else 6.0)
	_log(String(info["kind"]), best, r)
	_cue("punch", best.global_position + Vector3(0.0, 1.3, 0.0))
	fx.burst("dust", best.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP, 0.3)
	if r != "none":
		Impact.hit(self, "heavy" if (r == "knocked_out" or heavy) else "light", {"pos": best.global_position + Vector3(0.0, 1.2, 0.0),
			"dir": WeaponMath.flat_dir(best.global_position - pp), "fx": fx, "no_fx": true})
	if r == "knocked_out":
		_heat(WeaponData.HEAT_KO_UNARMED, best.global_position, "melee")
	return true


func _heat(amount: float, at: Vector3, cause: String) -> void:
	if weapons:
		weapons.mayhem.emit(amount, at, cause)
	else:
		mayhem.emit(amount, at, cause)


# ---------------------------------------------------------------------------
# DEFENCE
# ---------------------------------------------------------------------------
## An enemy's hit lands (called by MeleeEnemy at its impact frame). info: "damage", "heavy" (telegraphed, unblockable),
## "unblockable" (Phase C gunfire: a block never stops it, no knock-down).
## Returns "ignored" (down / knocked down) | "dodged" (invulnerable: roll, finisher) | "blocked" | "perfect" (counter) | "hit".
func receive_attack(attacker: Node3D, info: Dictionary) -> String:
	if player == null or state == St.DOWN or player.is_knocked_down() or not player.visible:
		return "ignored"
	if invuln_left > 0.0 or state == St.FINISHER:
		_log("enemy", attacker, "dodged")
		return "dodged"
	var heavy: bool = bool(info.get("heavy", false))
	if blocking and not heavy and not bool(info.get("unblockable", false)):
		if _t - _block_press_t <= CombatData.PERFECT_BLOCK_S + 1e-4:
			_counter(attacker)
			_log("enemy", attacker, "perfect")
			return "perfect"
		_cue("punch", player.global_position + Vector3(0.0, 1.3, 0.0), -8.0)
		var cp: Vector3 = player.global_position + Vector3(0.0, 1.3, 0.0) + player.facing_dir() * 0.3
		Impact.particles(self, "sparks", cp, player.facing_dir(), 0.7 if blade else 0.4, fx)   # a clash
		Impact.punch(self, 0.15 if blade else 0.08, -player.facing_dir())
		_log("enemy", attacker, "blocked")
		return "blocked"
	_take_damage(float(info.get("damage", 8.0)), attacker, heavy, bool(info.get("unblockable", false)))
	_log("enemy", attacker, "hit")
	return "hit"


func _counter(attacker: Node3D) -> void:
	blocking = false
	state = St.COUNTER
	state_t = 0.0
	move = counter_move
	hit_done = true
	queued = ""
	strike_target = attacker
	_face(attacker)
	_move_clip(move)
	_move_pose(move)
	if is_instance_valid(attacker) and attacker.has_method("take_strike"):
		_strike(attacker, {"kind": String(move["id"]), "dmg": float(move["dmg"]), "stagger": float(move["stagger"]), "push": float(move["push"]),
			"stun": float(move["stun"]), "breaks_block": true, "from": player.global_position})
	_cue("knife_hit", player.global_position + Vector3(0.0, 1.4, 0.0))
	if hud:
		hud.popup(counter_text, CombatHUD.GOLD)
	countered.emit(attacker)


func _take_damage(dmg: float, attacker: Node3D, heavy: bool, ranged: bool = false) -> void:
	if not god:
		hp = maxf(0.0, hp - dmg)
	since_damage = 0.0
	hp_changed.emit(hp)
	queued = ""
	blocking = false
	_release_throw()
	var away: Vector3 = player.global_position - (attacker.global_position if is_instance_valid(attacker) else player.global_position - player.facing_dir())
	_cue("impact_heavy" if heavy else "impact_medium", player.global_position + Vector3(0.0, 1.3, 0.0))
	# Q2: the player feels the hit: a short freeze (none for gunfire), a camera jolt toward the hit, the red screen edge
	Impact.hit(self, "heavy" if heavy else "light", {"pos": player.global_position + Vector3(0.0, 1.3, 0.0), "dir": WeaponMath.flat_dir(away),
		"fx": fx, "no_sound": true, "hitstop_k": 0.7, "punch_k": 1.3, "no_hitstop": ranged})
	Impact.edge_flash(self, Impact.EDGE_RED, 0.8 if heavy else 0.55)
	if hp <= 0.0:
		state = St.DOWN
		state_t = 0.0
		player.knock_down(away, CombatData.HEAVY_KNOCK_POWER)
		_cue("groan", player.global_position + Vector3(0.0, 1.0, 0.0))
		if pose:
			pose.reset()
		down.emit()
		return
	state = St.HITSTUN
	state_t = 0.0
	if heavy:
		player.knock_down(away, CombatData.HEAVY_KNOCK_POWER)
	else:
		CombatData.play_clip(player.model, "flinch", CombatData.HITSTUN_S)
		var a: Vector3 = WeaponMath.flat_dir(away)
		player.velocity.x += a.x * 2.5
		player.velocity.z += a.z * 2.5


## ThirdPersonController.jump_filter: a jump press near a hostile (within dodge_m: DODGE_HOSTILE_M unarmed) becomes a
## dodge-roll along the input direction (no input: away from the nearest hostile). Returns true when the press was used.
func try_dodge() -> bool:
	if state == St.DOWN:
		return enabled                       # down in a fight: no jumping around either
	if player == null or not _can_act(blocked_fn.is_valid() and bool(blocked_fn.call())) or _dodge_cd > 0.0:
		return false
	if state == St.FINISHER or state == St.HITSTUN or state == St.DODGE:
		return false
	if player.move_state != "GROUND" and player.move_state != "LAND_SOFT":
		return false
	var near: Node3D = _nearest_hostile(dodge_m)
	if near == null:
		return false
	var dir: Vector3 = _input_dir()
	if dir.length_squared() < 0.01:
		dir = WeaponMath.flat_dir(player.global_position - near.global_position)
	player.dodge_roll(dir, CombatData.DODGE_S, CombatData.DODGE_SPEED * dodge_speed_k)
	CombatData.play_clip(player.model, "roll", CombatData.DODGE_S)
	state = St.DODGE
	state_t = 0.0
	queued = ""
	blocking = false
	invuln_left = CombatData.DODGE_IFRAMES
	if pose:
		pose.clear()
	_cue("whoosh_down", player.global_position + Vector3(0.0, 0.8, 0.0), -6.0)
	return true


# ---------------------------------------------------------------------------
# FINISHER
# ---------------------------------------------------------------------------
func _start_finisher(e: Node3D) -> void:
	if not bool(e.call("take_finisher_start", self)):
		return
	state = St.FINISHER
	state_t = 0.0
	queued = ""
	blocking = false
	hit_done = false
	_fin_target = e
	_fin_kind = "throw" if finishers % 2 == 0 else "sweep"
	finishers += 1
	_face(e)
	_chase_left = CombatData.LUNGE_MAX
	_track(e, 1.0)
	if _fin_kind == "throw":
		if pose:
			pose.set_pose("hip_throw", 0.0, CombatData.FINISHER_S * 0.9)
	else:
		CombatData.play_clip(player.model, "kick_l", 0.7, 0.1, 0.45, CombatData.FINISHER_IMPACT)
	finisher.emit(e)


func _finishing() -> void:
	if not hit_done:
		_track(_fin_target, 1.0)
	if not hit_done and state_t >= CombatData.FINISHER_IMPACT:
		hit_done = true
		if _fin_target != null and is_instance_valid(_fin_target):
			var r: String = String(_fin_target.call("take_finisher", _fin_kind, player.global_position))
			_log("finisher", _fin_target, r)
			var at: Vector3 = _fin_target.global_position + Vector3(0.0, 1.0, 0.0)
			_cue("impact_heavy", at, 2.0)
			_cue("bonk", at, -2.0)
			var last: bool = r == "ko" and is_last(_fin_target)
			Impact.hit(self, "finisher", {"pos": at, "dir": WeaponMath.flat_dir(_fin_target.global_position - player.global_position),
				"target": _fin_target, "fx": fx, "last": last})
			tiers.append("finisher")
			if last:
				slowmo_count += 1                # the orbit's slow motion replaces the finisher's
			else:
				_slowmo()
			if hud:
				hud.popup(CombatData.T_FINISHED, CombatHUD.GOLD)
	if state_t >= CombatData.FINISHER_S:
		_fin_target = null
		_last_end = _t
		_to_idle()


## The finisher's slow motion (SLOWMO_SCALE for SLOWMO_REAL_S real seconds) on the Impact clock, after its freeze; refused
## while a wheel owns the time scale.
func _slowmo() -> void:
	var c: Impact = Impact.clock(self)
	if c != null and c.slowmo(CombatData.SLOWMO_SCALE, CombatData.SLOWMO_REAL_S, self):
		slowmo_count += 1


func _end_slowmo() -> void:
	var c: Impact = Impact.find_clock(self)
	if c != null:
		c.end_slowmo(self)
		c.end_slowmo(c)                      # a last-enemy orbit


## A combat slow motion runs (the finisher's or a last-enemy orbit; queued behind a freeze counts).
func slowmo_active() -> bool:
	var c: Impact = Impact.find_clock(self)
	return c != null and c.slowmo_active()


# ---------------------------------------------------------------------------
# Q2: THROWS AND IMPROVISED WEAPONS
# ---------------------------------------------------------------------------
## The nearest enemy within THROW_RANGE that can be grabbed now (MeleeEnemy.can_be_thrown), or null.
func throw_target() -> Node3D:
	if player == null:
		return null
	var best: Node3D = null
	var bd: float = CombatData.THROW_RANGE
	for e: Variant in enemies:
		if not _alive(e) or not (e as Object).has_method("can_be_thrown") or not bool((e as Object).call("can_be_thrown")):
			continue
		var d: float = WeaponMath.flat((e as Node3D).global_position, player.global_position)
		if d <= bd:
			bd = d
			best = e
	return best


func _start_throw(e: Node3D) -> void:
	if not bool(e.call("take_grab", self)):
		return
	state = St.THROW
	state_t = 0.0
	queued = ""
	blocking = false
	hit_done = false
	_throw_target = e
	throws += 1
	_face(e)
	_chase_left = CombatData.LUNGE_MAX
	if pose:
		pose.set_pose("hip_throw", 0.0, CombatData.THROW_S * 0.9)
	_cue("whoosh_down", player.global_position + Vector3(0.0, 1.0, 0.0), -4.0)


## The throw's release at THROW_IMPACT along the movement input (else the facing): the enemy flies; a heavy impact.
func _throwing() -> void:
	if not hit_done:
		_track(_throw_target, 0.9)
	if not hit_done and state_t >= CombatData.THROW_IMPACT:
		hit_done = true
		if _throw_target != null and is_instance_valid(_throw_target):
			var d: Vector3 = _input_dir()
			if d.length_squared() < 0.01:
				d = player.facing_dir()
			var r: String = String(_throw_target.call("take_throw", d, player.global_position))
			_log("throw", _throw_target, r)
			var at: Vector3 = _throw_target.global_position + Vector3(0.0, 1.1, 0.0)
			_cue("impact_heavy", at, 0.0)
			Impact.hit(self, "finisher" if r == "ko" else "heavy", {"pos": at, "dir": WeaponMath.flat_dir(d), "fx": fx,
				"last": r == "ko" and is_last(_throw_target), "orbit_target": _throw_target})
			tiers.append("finisher" if r == "ko" else "heavy")
			if hud and r != "ignored":
				hud.popup(CombatData.T_THROW, CombatHUD.GOLD)
		_throw_target = null
	if state_t >= CombatData.THROW_S:
		_throw_target = null
		_last_end = _t
		_to_idle()


## A grab that will not be thrown lets the enemy go (cancel, hit, revive).
func _release_throw() -> void:
	if _throw_target != null and is_instance_valid(_throw_target) and _throw_target.has_method("release_hold"):
		_throw_target.call("release_hold")
	_throw_target = null


func add_prop(p: ImprovisedWeapon) -> void:
	if not props.has(p):
		props.append(p)


func remove_prop(p: ImprovisedWeapon) -> void:
	props.erase(p)
	if held_prop == p:
		held_prop = null
		reset_moveset()


## The nearest improvised weapon on the floor within PICKUP_R (empty hands, the unarmed move set), or null.
func prop_target() -> ImprovisedWeapon:
	if player == null or held_prop != null or light_moves != CombatData.LIGHT:
		return null
	var best: ImprovisedWeapon = null
	var bd: float = CombatData.PICKUP_R
	for v: Variant in props:
		if not is_instance_valid(v) or not (v as ImprovisedWeapon).can_pick():
			continue
		var d: float = WeaponMath.flat((v as ImprovisedWeapon).global_position, player.global_position)
		if d <= bd:
			bd = d
			best = v
	return best


func _pick_prop(p: ImprovisedWeapon) -> void:
	p.hold(player)
	held_prop = p
	prop_picks += 1
	set_moveset(p.moveset())
	_cue("bag_drop", player.global_position + Vector3(0.0, 1.0, 0.0), -6.0)
	if hud:
		hud.popup(p.display_name(), CombatHUD.GOLD)


## A landed improvised-weapon hit: one use; used up = the comic break, unarmed again.
func _use_prop() -> void:
	if held_prop == null or not is_instance_valid(held_prop):
		held_prop = null
		return
	if held_prop.use():
		var p: ImprovisedWeapon = held_prop
		held_prop = null
		prop_breaks += 1
		p.break_apart(self)
		reset_moveset()
		if hud:
			hud.popup(CombatData.T_PROP_BREAK, CombatHUD.WARN)


## Put a held improvised weapon back where it was spawned (retry / stop): unarmed moves again.
func drop_prop() -> void:
	if held_prop != null and is_instance_valid(held_prop):
		held_prop.reset()
	if held_prop != null:
		held_prop = null
		reset_moveset()


# ---------------------------------------------------------------------------
# BODY: facing, step-in, speed cap, block pose
# ---------------------------------------------------------------------------
## Turn the body to the target; without one to the movement input, else to the camera (as the Phase W punch did).
func _face(t: Node3D) -> void:
	if player.model == null:
		return
	var d: Vector3 = Vector3.ZERO
	if t != null and is_instance_valid(t):
		d = t.global_position - player.global_position
	if Vector2(d.x, d.z).length() < 0.05:
		d = _input_dir()
	if Vector2(d.x, d.z).length() < 0.05:
		_face_yaw = player.yaw
	else:
		_face_yaw = atan2(-d.x, -d.z)
	player.model.rotation.y = _face_yaw


## Until the impact the strike follows its target: the body turns to it (TRACK_TURN rad/s) and steps in when it is out of
## reach, at the speed the controller's deceleration stops exactly at reach (v = sqrt(2 a gap)), at most LUNGE_MAX metres
## per move.
func _track(t: Node3D, reach: float) -> void:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return
	var dv: Vector3 = t.global_position - player.global_position
	var dist: float = Vector2(dv.x, dv.z).length()
	if dist < 0.05:
		return
	var dt: float = _dt
	var want: float = atan2(-dv.x, -dv.z)
	_face_yaw += clampf(wrapf(want - _face_yaw, -PI, PI), -TRACK_TURN * dt, TRACK_TURN * dt)
	var gap: float = minf(dist - (reach - 0.35), _chase_left)
	if gap <= 0.05:
		return
	var v: float = minf(sqrt(2.0 * CombatData.LUNGE_DECEL * gap), 6.0)
	var f := Vector3(-sin(_face_yaw), 0.0, -cos(_face_yaw))
	if player.velocity.x * f.x + player.velocity.z * f.z < v:
		player.velocity.x = f.x * v
		player.velocity.z = f.z * v
	_chase_left -= v * dt


func _apply_body() -> void:
	var cap: float = INF
	match state:
		St.LIGHT:
			cap = float(CombatData.SPEED_CAP["light"])
		St.HEAVY:
			cap = float(CombatData.SPEED_CAP["heavy"])
		St.COUNTER:
			cap = float(CombatData.SPEED_CAP["counter"])
		St.FINISHER, St.THROW:
			cap = float(CombatData.SPEED_CAP["finisher"])
		St.HITSTUN:
			cap = float(CombatData.SPEED_CAP["hitstun"])
		St.DOWN:
			cap = float(CombatData.SPEED_CAP["down"])
		St.IDLE:
			if blocking:
				cap = float(CombatData.SPEED_CAP["block"])
	player.combat_speed_cap = cap
	if held_prop != null and is_instance_valid(held_prop):
		var md: float = float(move.get("dur", 0.0))
		held_prop.swing_u = clampf(state_t / md, 0.0, 1.0) if (state == St.LIGHT or state == St.HEAVY) and md > 0.0 else 0.0
	if player.model and (state == St.LIGHT or state == St.HEAVY or state == St.COUNTER or state == St.FINISHER or state == St.THROW):
		player.model.rotation.y = _face_yaw          # hold the strike facing against the controller's turn
	elif blocking and lock != null and player.model:
		var dl: Vector3 = lock.global_position - player.global_position
		var want: float = atan2(-dl.x, -dl.z)
		var cur: float = player.model.rotation.y
		player.model.rotation.y = cur + clampf(wrapf(want - cur, -PI, PI), -10.0 * _dt, 10.0 * _dt)
	if pose:
		if blocking and state == St.IDLE:
			pose.set_pose(block_pose)
		elif idle_pose != "" and state == St.IDLE and (not pose.active() or pose.pose_name == block_pose):
			pose.set_pose(idle_pose)
		elif pose.pose_name == block_pose:
			pose.clear()


# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
## Camera-relative movement input of this frame (flat, length <= 1).
func _input_dir() -> Vector3:
	var i: Vector2 = player.input_dir
	if i.length_squared() < 0.0001:
		return Vector3.ZERO
	var f := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var r := Vector3(cos(player.yaw), 0.0, -sin(player.yaw))
	return (f * (-i.y) + r * i.x).limit_length(1.0)


## Mouse buttons count only while the mouse is captured, and the capturing click never attacks (like WeaponDirector).
func _mouse_gate(can: bool) -> bool:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not can or not captured or (captured and not _was_captured):
		_mouse_block = true
	_was_captured = captured
	var any: bool = captured and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	if not any:
		_mouse_block = false
	return captured and not _mouse_block


func _light_edge(can: bool) -> bool:
	var gate: bool = _mouse_gate(can)
	var raw: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var edge: bool = gate and raw and not _lmb_prev
	_lmb_prev = raw
	if light_override:
		light_override = false
		return can
	return edge


func _heavy_edge(can: bool) -> bool:
	var raw: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var edge: bool = can and not _mouse_block and raw and not _rmb_prev
	_rmb_prev = raw
	if heavy_override:
		heavy_override = false
		return can
	return edge


## E arrives as an event (_input): consumed only when it starts a finisher, so a marker or a call never gets the same press.
func _finisher_edge(can: bool) -> bool:
	var edge: bool = can and _e_event
	_e_event = false
	if finisher_override:
		finisher_override = false
		return can
	return edge


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo or k.physical_keycode != KEY_E or player == null:
		return
	if state == St.DOWN or state == St.FINISHER or state == St.HITSTUN or state == St.DODGE or state == St.THROW:
		return
	if not _can_act(blocked_fn.is_valid() and bool(blocked_fn.call())):
		return
	if finisher_target() == null and throw_target() == null and prop_target() == null:
		return
	_e_event = true
	e_consumed += 1
	get_viewport().set_input_as_handled()


## Q held = block. A press arms the perfect-block window only after Q was up BLOCK_REARM_S (taps do not renew it).
func _block_held(can: bool) -> bool:
	var raw: bool = bool(block_override) if block_override is bool else Input.is_physical_key_pressed(KEY_Q)
	var held: bool = can and raw
	if held and not _q_prev:
		_block_press_t = _t if _t - _q_release_t >= CombatData.BLOCK_REARM_S else -99.0
	elif not held and _q_prev:
		_q_release_t = _t
	_q_prev = held
	return held


# ---------------------------------------------------------------------------
# FX / LOG
# ---------------------------------------------------------------------------
## A sound at a world position: Phase W cues (WeaponAudio), Phase C duel cues (SwordAudio: clashes, glint, katana, howl)
## or A1 cues (CineAudio: impacts, groan, body fall, whoosh); cue_map remaps a cue first. Played cues: `cues` (last 32).
func _cue(cue: String, at: Vector3, db: float = 0.0) -> void:
	if _sfx.is_empty():
		return
	if not cue_map.is_empty():
		cue = String(cue_map.get(cue, cue))
	cues.append(cue)
	if cues.size() > 32:
		cues.pop_front()
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	if WeaponAudio.CUES.has(cue):
		p.stream = WeaponAudio.stream(cue)
	elif SwordAudio.is_cue(cue):
		p.stream = SwordAudio.stream(cue)
	else:
		p.stream = CineAudio.sfx(cue)
	p.volume_db = db
	p.global_position = at
	p.play()


func _log(kind: String, target: Node3D, result: String) -> void:
	strikes.append({"t": _t, "kind": kind, "target": String(target.name) if is_instance_valid(target) else "", "result": result})
	if strikes.size() > LOG_MAX:
		strikes.pop_front()


## Results of the logged strikes of `kind` (tests).
func results_of(kind: String) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in strikes:
		if String(s["kind"]) == kind:
			out.append(String(s["result"]))
	return out
