# File: res://scripts/combat/MeleeEnemy.gd
# One melee enemy of the Phase B fights (spec B-D2): a PS2 rigged person (CharacterBuilder, or the caller's body_fn for
# masks / cardigans) with an archetype from CombatData.ARCHETYPES (courier, clone, dolly) and an AI state machine:
#   APPROACH -> CIRCLE (strafe on a ring around the player, taunt, ask the fight for an attack token)
#   -> ENGAGE (close in) -> WINDUP (light) or TELEGRAPH (red flash 0.5 s, then an unblockable heavy) -> ATTACK -> RECOVER;
#   reactions: BLOCK / DODGE (side-step) against the player's attack, STAGGER (hit), DAZE (stagger meter full, 2.5 s,
#   finisher window), KNOCKDOWN (heavy kick on a staggered enemy, counters... lie 1.2 s + getup 0.9 s), KO (stays down,
#   stars), FLEE then FLED (Dolly at 30 % HP: runs 3 s, then gone), HELD (in the player's finisher), HOLD (ai off: stands
#   in guard; tests), IDLE (fight over: stands down); Phase C: HOWL (stats "howl_at", Sói Xám: once under that HP fraction he
#   howls for HOWL_S, armoured (hits hurt, never interrupt), then fights on with the "howl" buff: multipliers of speed,
#   damage, wind-up, recovery, cooldown, +1 chain) and FINALE (a scripted boss finale: not hostile, not defeated, no AI;
#   the subclass ends it with a knockout: KatanaBoss's broken katana).
#   Stats "glow" (Sói Xám): LED eyes (the body's "LedEye*" meshes, else two built on the head) light up from the start of
#   every wind-up / telegraph until the impact: the tell of each attack.
# The attack token (MeleeFight.request_token / release_token) is held from ENGAGE to the start of RECOVER, so at most
# max_attackers enemies commit at once; hit / daze / knockdown / KO release it. Hits on the player go through
# PlayerCombat.receive_attack at the impact frame (reach + 0.45 m, within 75° of the facing). Strikes from the player come
# in through take_strike(info). No gore: knockouts, stars, groans.
# Usage (MeleeFight does this): var e := MeleeEnemy.new(); e.setup("courier", opts); e.top_level = true; e.position = at;
# parent.add_child(e); e.set_yaw(yaw); e.bind(combat, fight, fight.enemies, combat.fx). The root never rotates: the body
# child carries the yaw (facing -Z). opts: "body" (CharacterBuilder opts merged over the archetype look; rigged
# is forced), "body_fn" (Callable(look: Dictionary) -> rigged Node3D), "label" (name over the head), "stats" (overrides of
# archetype numbers), "seed" (int), "hp_scale" (float), "ai" (false = stands in guard until force_attack: tests, scripted
# beats).
# Per frame: no allocation (the sibling list is the fight's array).
class_name MeleeEnemy
extends CharacterBody3D

signal ko(enemy: MeleeEnemy)
signal fled(enemy: MeleeEnemy)

enum St { APPROACH, CIRCLE, ENGAGE, WINDUP, TELEGRAPH, ATTACK, RECOVER, BLOCK, DODGE, STAGGER, DAZE, KNOCKDOWN, KO, FLEE, FLED,
	HOLD, IDLE, HELD, HOWL, FINALE }
const ST_NAMES: Array[String] = ["approach", "circle", "engage", "windup", "telegraph", "attack", "recover", "block", "dodge",
	"stagger", "daze", "knockdown", "ko", "flee", "fled", "hold", "idle", "held", "howl", "finale"]
const GLOW_ON_ENERGY: float = 9.0
const GLOW_OFF_ENERGY: float = 0.8
const GRAVITY: float = 20.0
const TURN_RATE: float = 10.0
const PUSH_DECEL: float = 10.0

var archetype_id: String = "clone"
var stats: Dictionary = {}
var label: String = ""
var body: Node3D
var pose: CombatPose
var combat: PlayerCombat
var director: Object = null
var siblings: Array = []
var fx: WeaponFX
var ai: bool = true
var hp: float = 50.0
var max_hp: float = 50.0
var stagger: float = 0.0
var stagger_max: float = 50.0
var st: int = St.APPROACH
var st_t: float = 0.0
var st_len: float = 0.0
var has_token: bool = false
var attack_kind: String = "light"
var chain_left: int = 0
var hit_done: bool = false
var flash_on: bool = false
var yaw: float = 0.0
var push_v: Vector3 = Vector3.ZERO
## Results of this enemy's attacks on the player ("hit", "blocked", "perfect", "dodged", "ignored", "miss"; last 32).
var results: Array[String] = []
var attacks: int = 0
var _t: float = 0.0
var _last_hit_t: float = -99.0
var _think_t: float = 0.5
var _cool_t: float = 0.0
var _circle_dir: float = 1.0
var _slot_angle: float = 0.0
var _taunt_left: float = 0.0
var _hit_t: float = 0.2
var _blocked: bool = false
var _forced: bool = false
var _alt: bool = false
var _getting_up: bool = false
var _side: Vector3 = Vector3.ZERO
var _flee_dir: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _meshes: Array[MeshInstance3D] = []
var _settle_t: float = 0.0
var _anim: Node = null                   # the body's animator (set_speed without a node lookup per frame)
var _stuck_t: float = 0.0
## Spawn point (bind): where a stuck / fallen enemy is put back. respawns: how often that happened.
var home: Vector3 = Vector3.ZERO
var respawns: int = 0
## Code poses of the stance and the guard (subclasses: KatanaBoss holds a katana).
var guard_pose: String = "guard"
var block_pose: String = "block"
## LED-eye glow (stats "glow", Sói Xám): lit from the start of every wind-up / telegraph until the impact. glow_t: game time
## it last lit (tests read the lead to the impact).
var glow_on: bool = false
var glow_t: float = -99.0
var glow_nodes: Array[MeshInstance3D] = []
var _glow_mat: StandardMaterial3D = null
## Howl phase (stats "howl_at", Sói Xám): howled once, howls counted (tests).
var howled: bool = false
var howls: int = 0
var _marks := PackedFloat32Array()
static var _flash_mat: StandardMaterial3D = null


## Build the body and the collider (before add_child). See the header for opts.
func setup(arch: String, opts: Dictionary = {}) -> void:
	archetype_id = arch if CombatData.ARCHETYPES.has(arch) else "clone"
	stats = CombatData.archetype(archetype_id).duplicate(true)
	var over: Dictionary = opts.get("stats", {})
	for k: String in over.keys():
		stats[k] = over[k]
	label = String(opts.get("label", ""))
	ai = bool(opts.get("ai", ai))
	_rng.seed = int(opts.get("seed", hash(archetype_id)))
	max_hp = float(stats["hp"]) * float(opts.get("hp_scale", 1.0))
	hp = max_hp
	stagger_max = float(stats["stagger_max"])
	_circle_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_think_t = _rng.randf_range(0.3, 0.9)
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	cs.name = "Capsule"
	var cap := CapsuleShape3D.new()
	cap.radius = CombatData.ENEMY_RADIUS
	cap.height = CombatData.ENEMY_HEIGHT
	cs.shape = cap
	cs.position = Vector3(0.0, CombatData.ENEMY_HEIGHT * 0.5, 0.0)
	add_child(cs)
	var look: Dictionary = (stats["look"] as Dictionary).duplicate()
	var bo: Dictionary = opts.get("body", {})
	for k2: String in bo.keys():
		look[k2] = bo[k2]
	look["rigged"] = true
	look["name"] = "Body"
	var bf: Callable = opts.get("body_fn", Callable())
	body = bf.call(look) if bf.is_valid() else CharacterBuilder.build(look)
	body.name = "Body"
	add_child(body)
	pose = CombatPose.attach(body)
	if pose == null:                         # a body without a skeleton: a layer that writes nothing
		pose = CombatPose.new()
		pose.name = "CombatPose"
		add_child(pose)
	for mi: Node in body.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mi as MeshInstance3D)
	_anim = CharacterBuilder.get_animator(body)
	if bool(stats.get("glow", false)):
		_build_glow()
	if stats.has("howl_at"):
		_marks.append(float(stats["howl_at"]))
	if stats.has("sfx"):
		SwordAudio.warm(stats["sfx"])


## The LED eyes: the body's own "LedEye*" meshes (a body_fn look), else two small spheres in front of the head; one
## emissive material per enemy, dim until _set_glow(true).
func _build_glow() -> void:
	for n: Node in body.find_children("LedEye*", "MeshInstance3D", true, false):
		glow_nodes.append(n as MeshInstance3D)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.35, 0.02, 0.02)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.12, 0.06)
	_glow_mat.emission_energy_multiplier = GLOW_OFF_ENERGY
	_glow_mat.set_meta("vice_done", true)    # ViceStyle must not flatten it
	if glow_nodes.is_empty():
		var head: Node3D = (body.get_meta("rig", {}) as Dictionary).get("head") as Node3D
		var sm := SphereMesh.new()
		sm.radius = 0.017
		sm.height = 0.03
		sm.radial_segments = 8
		sm.rings = 4
		for sx: float in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.name = "LedEyeL" if sx < 0.0 else "LedEyeR"
			mi.mesh = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if head != null:
				mi.position = Vector3(sx * 0.042, 0.12, -(CharacterBuilder.HEAD_R * 1.18 + 0.016))
				head.add_child(mi)
			else:
				mi.position = Vector3(sx * 0.042, 1.62, -0.16)
				body.add_child(mi)
			glow_nodes.append(mi)
	for mi2: MeshInstance3D in glow_nodes:
		mi2.material_override = _glow_mat


func _set_glow(on: bool) -> void:
	if _glow_mat == null or on == glow_on:
		return
	glow_on = on
	if on:
		glow_t = _t
	_glow_mat.emission_energy_multiplier = GLOW_ON_ENERGY if on else GLOW_OFF_ENERGY
	_glow_mat.albedo_color = Color(1.0, 0.3, 0.22) if on else Color(0.35, 0.02, 0.02)
	for mi: MeshInstance3D in glow_nodes:
		if is_instance_valid(mi):
			mi.scale = Vector3.ONE * (1.7 if on else 1.0)


## HP fractions the boss bar marks with a tick (the howl threshold; KatanaBoss: its phases). Cached: no allocation.
func boss_marks() -> PackedFloat32Array:
	return _marks


## Wire to the player's combat, the token director (MeleeFight; null = always allowed), the shared sibling list and the FX.
func bind(c: PlayerCombat, dir: Object, sibs: Array, effects: WeaponFX) -> void:
	combat = c
	director = dir
	siblings = sibs
	fx = effects
	body.rotation.y = yaw
	home = global_position
	_enter(St.APPROACH if ai else St.HOLD)


func set_yaw(y: float) -> void:
	yaw = y
	if body:
		body.rotation.y = y


func facing_dir() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func state_name() -> String:
	return ST_NAMES[st]


func is_down() -> bool:
	return st == St.KO or st == St.KNOCKDOWN or st == St.FLEE or st == St.FLED


## Still in the fight against the player (not knocked out, fleeing, fled, stood down or in a scripted finale).
func is_hostile() -> bool:
	return st != St.KO and st != St.FLED and st != St.FLEE and st != St.IDLE and st != St.FINALE


func is_ko() -> bool:
	return st == St.KO


## Out of the fight for good (knocked out or fled).
func is_defeated() -> bool:
	return st == St.KO or st == St.FLED


func is_attacking() -> bool:
	return st == St.ENGAGE or st == St.WINDUP or st == St.TELEGRAPH or st == St.ATTACK


func is_dazed() -> bool:
	return st == St.DAZE


## An attack on its way to the player, for the HUD: 0 none, 1 light (wind-up or swing before the impact), 2 heavy
## (telegraph or swing before the impact).
func incoming() -> int:
	if st == St.TELEGRAPH or (st == St.ATTACK and not hit_done and attack_kind == "heavy"):
		return 2
	if st == St.WINDUP or (st == St.ATTACK and not hit_done):
		return 1
	return 0


# ---------------------------------------------------------------------------
# FRAME
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	st_t += delta
	if st == St.FLED:
		return
	if stagger > 0.0 and st != St.DAZE and _t - _last_hit_t > CombatData.STAGGER_DECAY_DELAY:
		stagger = maxf(0.0, stagger - CombatData.STAGGER_DECAY * delta)
	var p: Node3D = combat.player if combat else null
	var want := Vector3.ZERO
	var face_player: bool = true
	var to_p := Vector3.ZERO
	var dist: float = 99.0
	if p:
		to_p = Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
		dist = to_p.length()
		if dist > 0.01:
			to_p /= dist
	var speed: float = float(stats["speed"])
	match st:
		St.APPROACH:
			if dist <= float(stats["circle_r"]) + 0.3:
				_enter(St.CIRCLE)
			else:
				want = to_p * speed
		St.CIRCLE:
			want = _circle(delta, p, dist)
		St.ENGAGE:
			if dist <= float(stats["reach"]) + 0.15:
				_choose_attack()
			elif st_t >= CombatData.ENGAGE_TIMEOUT:
				_to_idle_state()
			else:
				want = to_p * speed * 1.1
		St.WINDUP:
			if st_t >= st_len:
				_start_attack()
		St.TELEGRAPH:
			if st_t >= CombatData.TELEGRAPH_S:
				_start_attack()
		St.ATTACK:
			face_player = false
			if not hit_done and st_t >= _hit_t:
				_strike()
			if st == St.ATTACK and st_t >= st_len:
				_after_attack()
		St.RECOVER, St.BLOCK, St.STAGGER, St.HOWL:
			if st_t >= st_len:
				_to_idle_state()
		St.FINALE:
			face_player = false
		St.DODGE:
			want = _side * CombatData.DODGE_SIDE_SPEED
			if st_t >= st_len:
				_to_idle_state()
		St.DAZE:
			face_player = false
			if st_t >= CombatData.DAZE_S:
				stagger = 0.0
				_to_idle_state()
		St.KNOCKDOWN:
			face_player = false
			if not _getting_up and st_t >= CombatData.KNOCKDOWN_LIE_S:
				_getting_up = true
				CharacterBuilder.play(body, "getup")
			if st_t >= CombatData.KNOCKDOWN_LIE_S + CombatData.GETUP_S:
				_getting_up = false
				collision_layer = 1
				if _should_flee():
					_start_flee()
				elif _should_howl():
					_start_howl()
				else:
					_to_idle_state()
		St.KO:
			face_player = false
			_settle_t += delta
			if _settle_t > 1.2 and push_v.length_squared() < 0.01 and is_on_floor():
				return                       # lying still: no more physics
		St.FLEE:
			face_player = false
			want = _flee_dir * speed * 1.1
			if want.length_squared() > 0.01:
				_turn_to(atan2(-want.x, -want.z), delta)
			if st_t >= CombatData.FLEE_S:
				_enter(St.FLED)
				visible = false
				collision_layer = 0
				fled.emit(self)
				return
		St.HELD:
			if st_t >= CombatData.HELD_MAX_S:
				release_hold()               # the finisher never landed (player hit, fight reset)
		St.HOLD, St.IDLE:
			if _taunt_left > 0.0:
				_taunt_left -= delta
				if _taunt_left <= 0.0:
					pose.set_pose(guard_pose)
	if st == St.APPROACH or st == St.CIRCLE or st == St.ENGAGE or st == St.HOLD or st == St.IDLE:
		want += _separation(p, dist)
	velocity.x = want.x + push_v.x
	velocity.z = want.z + push_v.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	push_v = push_v.move_toward(Vector3.ZERO, PUSH_DECEL * delta)
	_stuck_check(delta, want, dist)
	if face_player and p and dist > 0.05:
		_turn_to(atan2(-to_p.x, -to_p.z), delta)
	var moving: bool = st == St.APPROACH or st == St.CIRCLE or st == St.ENGAGE or st == St.FLEE or st == St.DODGE
	if _anim:
		_anim.set("speed", Vector2(velocity.x, velocity.z).length() if moving else 0.0)


## Wedged (wants >= 1 m/s, moves < a quarter of it), off the leash or fallen below its spawn point: after STUCK_S (1 s when
## fallen) it is put back at its spawn point; after RESPAWN_MAX of those it counts as knocked out (the wave never hangs).
func _stuck_check(delta: float, want: Vector3, dist: float) -> void:
	if st == St.KO or st == St.FLED or st == St.FLEE or st == St.IDLE or st == St.FINALE:
		_stuck_t = 0.0
		return
	var fallen: bool = global_position.y < home.y - CombatData.FALL_BELOW_M
	var ws: float = Vector2(want.x, want.z).length()
	var wedged: bool = ws >= 1.0 and Vector2(get_real_velocity().x, get_real_velocity().z).length() < ws * 0.25
	if fallen:
		_stuck_t += delta * CombatData.STUCK_S
	elif wedged or dist > CombatData.LEASH_M:
		_stuck_t += delta
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)
	if _stuck_t < CombatData.STUCK_S:
		return
	_stuck_t = 0.0
	respawns += 1
	if respawns > CombatData.RESPAWN_MAX:
		hp = 0.0
		_knock_out(-facing_dir())
		return
	global_position = home + Vector3(0.0, 0.05, 0.0)
	velocity = Vector3.ZERO
	push_v = Vector3.ZERO
	collision_layer = 1
	_release_token()
	_enter(St.APPROACH if ai else St.HOLD)


func _turn_to(target: float, delta: float) -> void:
	yaw += clampf(wrapf(target - yaw, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta)
	body.rotation.y = yaw


## Strafe on the ring (radius circle_r) around the player; ask for the attack token every think interval.
func _circle(delta: float, p: Node3D, dist: float) -> Vector3:
	if p == null:
		return Vector3.ZERO
	var r: float = float(stats["circle_r"])
	if dist > r + 2.5:
		_enter(St.APPROACH)
		return Vector3.ZERO
	_slot_angle += _circle_dir * float(stats["circle_speed"]) / r * delta
	var tgt: Vector3 = p.global_position + Vector3(sin(_slot_angle), 0.0, cos(_slot_angle)) * r
	var v := Vector3(tgt.x - global_position.x, 0.0, tgt.z - global_position.z)
	var want := Vector3.ZERO
	var l: float = v.length()
	if l > 0.15:
		want = v / l * minf(float(stats["speed"]), maxf(float(stats["circle_speed"]), l * 2.0))
	_think_t -= delta
	_cool_t -= delta
	if _taunt_left > 0.0:
		_taunt_left -= delta
		if _taunt_left <= 0.0:
			pose.set_pose(guard_pose)
	if _think_t <= 0.0:
		var th: Vector2 = stats["think"]
		_think_t = _rng.randf_range(th.x, th.y)
		if _rng.randf() < 0.2:
			_circle_dir = -_circle_dir
		if ai and _cool_t <= 0.0 and combat.can_be_attacked() and _request_token():
			_enter(St.ENGAGE)
		elif _taunt_left <= 0.0 and _rng.randf() < float(stats["taunt_chance"]):
			_taunt_left = 1.6
			pose.set_pose("taunt", 0.8)
	return want


func _separation(p: Node3D, dist: float) -> Vector3:
	var s := Vector3.ZERO
	var gp: Vector3 = global_position
	for o: Variant in siblings:
		if o == self or not is_instance_valid(o):
			continue
		var e: MeleeEnemy = o
		if e.st == St.FLED or e.st == St.KO:
			continue
		var dx: float = gp.x - e.global_position.x
		var dz: float = gp.z - e.global_position.z
		var l: float = sqrt(dx * dx + dz * dz)
		if l < CombatData.SEPARATION_M and l > 0.01:
			var k: float = (CombatData.SEPARATION_M - l) * 2.5 / l
			s.x += dx * k
			s.z += dz * k
	if p and st != St.ENGAGE and dist < 1.0 and dist > 0.01:     # keep off the player unless closing in to attack
		s.x += (gp.x - p.global_position.x) / dist * (1.0 - dist) * 3.0
		s.z += (gp.z - p.global_position.z) / dist * (1.0 - dist) * 3.0
	return s


func _request_token() -> bool:
	if has_token:
		return true
	if director == null or bool(director.call("request_token", self)):
		has_token = true
	return has_token


func _release_token() -> void:
	if has_token and director != null:
		director.call("release_token", self)
	has_token = false


func _enter(s: int, length: float = 0.0) -> void:
	st = s
	st_t = 0.0
	st_len = length
	if s != St.TELEGRAPH and s != St.ATTACK:
		_set_flash(false)
	if _glow_mat != null:
		if s == St.WINDUP or s == St.TELEGRAPH:
			_set_glow(true)
		elif s != St.ATTACK:
			_set_glow(false)
	match s:
		St.APPROACH, St.ENGAGE, St.HOLD:
			pose.set_pose(guard_pose)
		St.WINDUP:
			pose.set_pose("jab_windup_l" if _alt else "jab_windup_r")   # the side of the coming punch
		St.CIRCLE:
			if _taunt_left <= 0.0:
				pose.set_pose(guard_pose)
			if combat and combat.player:
				var d: Vector3 = global_position - combat.player.global_position
				_slot_angle = atan2(d.x, d.z)
		St.BLOCK:
			pose.set_pose(block_pose)
		St.TELEGRAPH:
			pose.set_pose("windup")
			_set_flash(true)
		St.DAZE:
			pose.set_pose("stunned", 1.2)
		St.DODGE:
			pose.set_pose("dodge_lean", 0.0, length)
		St.IDLE:
			pose.set_pose("taunt", 0.8)
		St.HOWL:
			pose.set_pose("howl", 0.6)
		St.ATTACK, St.STAGGER, St.KNOCKDOWN, St.FLEE, St.HELD, St.FINALE:
			pose.clear()
		St.KO, St.FLED:
			pose.reset()


## Back to the neutral state after a timed one: HOLD with the AI off, else CIRCLE (APPROACH when far); token released.
func _to_idle_state() -> void:
	_release_token()
	if st == St.RECOVER:
		var cd: Vector2 = stats["cooldown"]
		_cool_t = _rng.randf_range(cd.x, cd.y)
	_forced = false
	if not ai:
		_enter(St.HOLD)
		return
	_enter(St.CIRCLE)


func _choose_attack() -> void:
	attack_kind = "heavy" if _rng.randf() < float(stats["heavy_chance"]) else "light"
	chain_left = int(stats["chain"]) - 1 if attack_kind == "light" else 0
	_begin_attack()


func _begin_attack() -> void:
	_blocked = false
	if attack_kind == "heavy":
		_enter(St.TELEGRAPH)
	else:
		_enter(St.WINDUP, float(stats["windup"]))


## Tests / scripted beats: attack now ("light", "heavy" or "combo": the archetype's whole light chain), without a token.
func force_attack(kind: String) -> void:
	if not is_hostile() or st == St.DAZE or st == St.KNOCKDOWN or st == St.HELD:
		return
	_forced = true
	attack_kind = "light" if kind == "combo" else kind
	chain_left = int(stats["chain"]) - 1 if kind == "combo" else 0
	_begin_attack()


## Tests / scripted beats: raise the guard for secs.
func force_block(secs: float) -> void:
	if not is_hostile() or st == St.DAZE or st == St.KNOCKDOWN or st == St.HELD:
		return
	_release_token()
	_enter(St.BLOCK, secs)


func _start_attack() -> void:
	var p: Node3D = combat.player if combat else null
	_enter(St.ATTACK)
	hit_done = false
	var a: Dictionary = CombatData.ENEMY_HEAVY if attack_kind == "heavy" else (CombatData.ENEMY_LIGHT_ALT if _alt else CombatData.ENEMY_LIGHT)
	_alt = not _alt
	_hit_t = float(a["hit"])
	st_len = maxf(float(a["dur"]) / float(stats.get("attack_speed", 1.0)), _hit_t + 0.05)   # quicker follow-through (Sói Xám)
	if attack_kind == "heavy":
		_set_flash(true)                     # still red until the impact
	CombatData.play_clip(body, String(a["clip"]), float(a["dur"]), float(a["from"]), float(a["hit_at"]), float(a["hit"]))
	if p:
		var d := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
		if d.length() > 0.05:
			set_yaw(atan2(-d.x, -d.z))
		var gap: float = d.length() - float(stats["reach"]) + 0.2
		if gap > 0.05:
			push_v = facing_dir() * minf(sqrt(2.0 * PUSH_DECEL * minf(gap, 0.8)), 4.0)


## Impact frame: the player within reach + 0.45 m and 75° of the facing gets the hit through PlayerCombat.receive_attack.
func _strike() -> void:
	hit_done = true
	_set_flash(false)
	_set_glow(false)
	attacks += 1
	var r: String = "miss"
	var p: Node3D = combat.player if combat else null
	if p:
		var d := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
		var l: float = d.length()
		if l <= float(stats["reach"]) + 0.45 and (l < 0.05 or facing_dir().dot(d / l) >= cos(deg_to_rad(75.0))) and _clear_to(p):
			var heavy: bool = attack_kind == "heavy"
			r = combat.receive_attack(self, {"damage": float(stats["heavy_dmg"] if heavy else stats["light_dmg"]), "heavy": heavy,
				"kind": attack_kind})
	results.append(r)
	if results.size() > 32:
		results.pop_front()
	if r == "blocked":
		_blocked = true
	elif r == "miss" or r == "dodged":
		combat._cue("swish", global_position + Vector3(0.0, 1.2, 0.0), -6.0)


## Nothing solid between this enemy's chest and the player's (walls, props); people and bodies do not count.
func _clear_to(p: Node3D) -> bool:
	if not is_inside_tree():
		return true
	var rq := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.3, 0.0), p.global_position + Vector3(0.0, 1.3, 0.0))
	rq.exclude = [get_rid(), (p as CollisionObject3D).get_rid()] if p is CollisionObject3D else [get_rid()]
	rq.collide_with_areas = false
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
	return h.is_empty() or h["collider"] is CharacterBody3D


func _after_attack() -> void:
	var last: String = results.back() if not results.is_empty() else "miss"
	if attack_kind == "light" and chain_left > 0 and (last == "hit" or last == "blocked"):
		chain_left -= 1
		_enter(St.WINDUP, CombatData.CHAIN_WINDUP)
		return
	_release_token()
	_enter(St.RECOVER, float(stats["recover"]) + (CombatData.BLOCKED_RECOVER_ADD if _blocked else 0.0))


## The player started an attack on this enemy (impact in eta s): with the AI on, a free enemy may block or side-step.
func on_player_attack(_kind: String, eta: float) -> void:
	if not ai or not (st == St.APPROACH or st == St.CIRCLE or st == St.ENGAGE):
		return
	var r: float = _rng.randf()
	var dc: float = float(stats["dodge_chance"])
	if r < dc:
		_release_token()
		var p: Node3D = combat.player
		var away: Vector3 = WeaponMath.flat_dir(global_position - p.global_position)
		_side = Vector3(-away.z, 0.0, away.x) * (1.0 if _rng.randf() < 0.5 else -1.0) * 0.8 + away * 0.6
		_side = _side.normalized()
		_enter(St.DODGE, maxf(CombatData.DODGE_SIDE_S, eta + 0.1))
	elif r < dc + float(stats["block_chance"]):
		force_block(eta + 0.35)


# ---------------------------------------------------------------------------
# HIT
# ---------------------------------------------------------------------------
## A strike from the player. info: "kind" (jab | cross | elbow | heavy | counter | weapon), "dmg", "stagger", "push" (m),
## "breaks_block", "stun" (stagger seconds), "knockdown", "from". Returns "ignored" | "dodged" | "blocked" | "guard_break" |
## "hit" | "daze" | "knockdown" | "ko" | "flee".
func take_strike(info: Dictionary) -> String:
	if st == St.KO or st == St.FLED or st == St.FLEE or st == St.KNOCKDOWN or st == St.FINALE:
		return "ignored"
	if st == St.DODGE:
		return "dodged"
	var from: Vector3 = info.get("from", global_position - facing_dir())
	var away: Vector3 = WeaponMath.flat_dir(global_position - from)
	_last_hit_t = _t
	var dmg: float = float(info.get("dmg", 8.0))
	var push: float = float(info.get("push", 0.3))
	var kind: String = String(info.get("kind", "jab"))
	if st == St.BLOCK:
		if not bool(info.get("breaks_block", false)):
			stagger = minf(stagger_max - 1.0, stagger + CombatData.BLOCK_CHIP_STAGGER)
			push_v = away * sqrt(2.0 * PUSH_DECEL * 0.2)
			return "blocked"
		hp -= dmg * 0.5
		stagger = minf(stagger_max, stagger + float(info.get("stagger", 20.0)))
		push_v = away * sqrt(2.0 * PUSH_DECEL * push)
		var r0: String = _after_damage(away)
		if r0 != "":
			return r0
		_stagger_for(CombatData.GUARD_BREAK_S)
		return "guard_break"
	if st == St.DAZE:
		dmg *= 1.25
	hp -= dmg
	push_v = away * sqrt(2.0 * PUSH_DECEL * push)
	var r: String = _after_damage(away)
	if r != "":
		return r
	if st == St.DAZE or st == St.HELD or st == St.HOWL:
		return "hit"                         # dazed / held / howling (armoured): hurt, not interrupted
	stagger += float(info.get("stagger", 15.0))
	if stagger >= stagger_max:
		stagger = stagger_max
		_daze()
		return "daze"
	if bool(info.get("knockdown", false)) or (kind == "heavy" and st == St.STAGGER):
		_knockdown(away)
		return "knockdown"
	if st == St.TELEGRAPH or _armored():
		return "hit"                         # armoured wind-up: the heavy still comes (dodge it)
	_stagger_for(float(info.get("stun", CombatData.STAGGER_S)))
	return "hit"


## Hits that do not interrupt (besides a telegraph): none here; KatanaBoss armours its wind-ups and swings.
func _armored() -> bool:
	return false


## HP checks after damage: flee threshold (Dolly), knockout or the howl threshold (Sói Xám). "" = still fighting.
func _after_damage(away: Vector3) -> String:
	if _should_flee():
		hp = maxf(hp, 1.0)
		_start_flee()
		return "flee"
	if hp <= 0.0:
		hp = 0.0
		_knock_out(away)
		return "ko"
	if _should_howl() and st != St.HELD:
		_start_howl()
		return "howl"
	return ""


func _should_howl() -> bool:
	return not howled and stats.has("howl_at") and hp <= max_hp * float(stats["howl_at"])


## The howl (Sói Xám): stops, howls for HOWL_S (armoured, eyes lit, the howl cue and the archetype's line), and the "howl"
## buff applies at once: float / Vector2 stats are multiplied, int stats (chain) get the value added.
func _start_howl() -> void:
	howled = true
	howls += 1
	_release_token()
	stagger = 0.0
	push_v = Vector3.ZERO
	_enter(St.HOWL, CombatData.HOWL_S)
	CharacterBuilder.stop_clip(body)
	_set_glow(true)
	var buff: Dictionary = stats.get("howl", {})
	for k: String in buff.keys():
		if not stats.has(k):
			continue
		var v: Variant = stats[k]
		if v is int:
			stats[k] = int(v) + int(buff[k])
		elif v is Vector2:
			stats[k] = (v as Vector2) * float(buff[k])
		else:
			stats[k] = float(v) * float(buff[k])
	if combat:
		combat._cue("howl", global_position + Vector3(0.0, 1.6, 0.0), 2.0)
		if combat.hud and stats.has("howl_line"):
			combat.hud.popup(String(stats["howl_line"]), CombatHUD.WARN)


func _should_flee() -> bool:
	var fa: float = float(stats["flee_at"])
	return fa > 0.0 and hp <= max_hp * fa


func _stagger_for(secs: float) -> void:
	_release_token()
	_enter(St.STAGGER, secs)
	CharacterBuilder.play(body, "flinch" if _rng.randf() < 0.5 else "hit_b", minf(secs + 0.1, 0.6))


func _daze() -> void:
	_release_token()
	_enter(St.DAZE)
	CharacterBuilder.stop_clip(body)
	if fx:
		fx.stars(self, CombatData.DAZE_S)
	if combat:
		combat._cue("groan", global_position + Vector3(0.0, 1.5, 0.0), -4.0)


func _knockdown(away: Vector3) -> void:
	_release_token()
	_enter(St.KNOCKDOWN)
	_getting_up = false
	collision_layer = 0
	push_v = away * 3.0
	set_yaw(atan2(away.x, away.z))        # faces the hit: falls on the back away from it
	CharacterBuilder.play(body, "knockdown")
	if combat:
		combat._cue("body_fall", global_position + Vector3(0.0, 0.3, 0.0))


func _knock_out(away: Vector3) -> void:
	_release_token()
	_enter(St.KO)
	_settle_t = 0.0
	collision_layer = 0
	push_v = away * 3.5
	set_yaw(atan2(away.x, away.z))
	CharacterBuilder.play(body, "knockdown")
	CharacterBuilder.set_expression(body, "pain")
	if fx:
		fx.stars(self, CombatData.KO_STARS_S)
	if combat:
		combat._cue("groan", global_position + Vector3(0.0, 1.0, 0.0), -2.0)
		combat._cue("body_fall", global_position + Vector3(0.0, 0.3, 0.0), -2.0)
	ko.emit(self)


func _start_flee() -> void:
	_release_token()
	_enter(St.FLEE)
	collision_layer = 0
	var p: Node3D = combat.player if combat else null
	_flee_dir = WeaponMath.flat_dir(global_position - p.global_position) if p else -facing_dir()
	CharacterBuilder.stop_clip(body)


## PlayerCombat starts a finisher on this (dazed) enemy: it is held until take_finisher. false = not possible.
func take_finisher_start(_c: Object) -> bool:
	if st != St.DAZE:
		return false
	_release_token()
	_enter(St.HELD)
	return true


## A finisher that will not land lets the held enemy go (it fights on, the stagger meter emptied).
func release_hold() -> void:
	if st != St.HELD:
		return
	stagger = 0.0
	_to_idle_state()


## The finisher's impact ("throw" | "sweep"): knocked out (archetypes with finisher_ko) or FINISHER_DMG + knockdown (Dolly;
## she flees after getting up when under her flee threshold). Returns "ko" | "knockdown" | "ignored".
func take_finisher(_kind: String, from: Vector3) -> String:
	if st != St.HELD and st != St.DAZE:
		return "ignored"
	var away: Vector3 = WeaponMath.flat_dir(global_position - from)
	stagger = 0.0
	if bool(stats["finisher_ko"]):
		hp = 0.0
		_knock_out(away)
		push_v = away * 5.0
		return "ko"
	hp = maxf(1.0, hp - CombatData.FINISHER_DMG)
	_knockdown(away)
	return "knockdown"


## Phase W duck type (a weapon in a fight that does not force unarmed): bullets / melee / bonk / blasts hurt like a heavy
## strike that breaks the guard; scares, stink and sonic do nothing. Returns "knocked_out" | "stumble" | "none".
func take_hit(info: Dictionary) -> String:
	if not is_hostile():
		return "none"
	var kind: String = String(info.get("kind", "melee"))
	if kind == "scare" or kind == "stink" or kind == "sonic":
		return "none"
	var big: bool = kind == "blast" or kind == "pellet"
	var r: String = take_strike({"kind": "weapon", "dmg": 40.0 if big else 25.0, "stagger": 30.0, "push": 1.5 if big else 0.6,
		"breaks_block": true, "knockdown": big, "from": info.get("from", global_position)})
	return "knocked_out" if r == "ko" else ("none" if r == "ignored" else "stumble")


## The fight is over (player down / fight stopped): stand down, no more attacks.
func stand_down() -> void:
	if st == St.KO or st == St.FLED or st == St.FLEE or st == St.FINALE:
		return
	_release_token()
	_enter(St.IDLE)


func _set_flash(on: bool) -> void:
	if on == flash_on:
		return
	flash_on = on
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.albedo_color = Color(0.95, 0.08, 0.05, 0.7)
		_flash_mat.set_meta("vice_done", true)
	for mi: MeshInstance3D in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _flash_mat if on else null
