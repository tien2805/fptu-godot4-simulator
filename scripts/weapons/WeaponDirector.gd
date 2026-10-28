# File: res://scripts/weapons/WeaponDirector.gd
# Phase W weapons on foot (spec W-D2..W-D4, W-D9, section 3):
#   - the equipped slot (wheel selection or mouse-wheel scroll + toast) and its code-built hand prop (WeaponProps, posed in
#     the body frame like CineActor.hold);
#   - magazines with unlimited reserve: automatic reload when empty, R reloads a part-empty one;
#   - aim (right mouse): ThirdPersonController's over-the-shoulder camera, narrower FOV, walk speed, crosshair;
#   - fire (left mouse while the mouse is captured): without aiming the body turns to the camera first (hip fire);
#   - the per-weapon logic (melee here; hitscan / pellets Task 4, rocket Task 5, dép / sầu riêng / loa Task 6).
# Targets are duck-typed: any Node3D with take_hit(info) -> String and is_down() from targets_fn (Pedestrian, Officer);
# vehicles go through RoamTraffic.hit_vehicle. Heat leaves on the `mayhem` signal (WantedDirector.add_heat). Blocked (no
# aim, no fire) while blocked_fn says so (riding, cinematic, replay, busted, community service, map) or `locked`; nothing
# fires while the wheel is open. Times are game seconds (the wheel's slow motion slows reloads too). Input overrides
# (fire_override / aim_override / reload_override) drive it in tests. No autoload is referenced here.
# The hand prop's visibility is owned here (_apply_held_vis): hidden while the dép is in flight and while any reason in
# held_hide is set (the emote, community service). After the mouse is captured or a block / the wheel ends, the fire button
# must be released once before it fires (the capturing click never shoots).
# Phase B: with an unarmed_owner (scripts/combat/PlayerCombat) the Tay không slot belongs to it: no Phase W punch and no
# right-mouse aim while unarmed (the owner reads the mouse); without one the Phase W punch below is unchanged.
# Phase C lairs (scripts/combat/guns/GunFight): `reserve` = finite spare rounds per slot (empty / -1 = unlimited, W-D9): a
# reload takes what it needs from it, "12 / 36" in the HUD; add_reserve() for ammo pickups. set_locked_slots(): slots that
# cannot be equipped (equip refuses, scroll skips them, the wheel greys them with its own text).
# Q2 gun feel (plan 2026-10-29-q2-feel.md T4): every shot kicks the camera back (Impact.punch: RECOIL per kind, through
# the camera director, else GameFX.shake); the muzzle flash lights one frame and impacts leave bullet holes (WeaponFX);
# every hit on a person shows the HUD hit marker with its tick (red with a second tick on a knockout: WeaponHUD.hit_marker,
# ImpactAudio hit_tick / ko_tick); a bullet / pellet knockout is a finisher-tier Impact (freeze, sting).
class_name WeaponDirector
extends Node3D

signal equipped(slot: int)
signal fired(slot: int)
signal mayhem(heat: float, at: Vector3, cause: String)
signal toast(text: String)

const COMBO_S: float = 1.5
const LOG_MAX: int = 64
const HAND_UP: float = 1.3
const SOFT_R: float = 0.35               # analytic body capsule of a target (ray tests, Task 4)
const SOFT_H: float = 1.8
const SCARE_GUN_R: float = 10.0          # gunfire scares pedestrians this close (plan P11)
const PUMP_DELAY: float = 0.35
const KNOCK_UP: float = 6.0              # shotgun knockback arc: up KNOCK_UP m/s, lands `knockback` m away
const ROCKET_UP: float = 1.45            # launcher on the right shoulder
const SCARE_BLAST_R: float = 25.0        # explosions scare pedestrians this close (plan P11)
const IMPOSTOR_BLAST_R: float = 30.0
const DEP_KO_S: float = 4.0              # dép bonk: pedestrians are out 4 s (officers 10 s, plan P5)
const THROW_SPEED: float = 11.0
const THROW_UP: float = 0.42
## Q2 camera recoil per shot (Impact.punch strength).
const RECOIL: Dictionary = {"hitscan": 0.12, "pellets": 0.3, "rocket": 0.4}

var player: ThirdPersonController
var wheel: WeaponWheel
var hud: WeaponHUD
var fx: WeaponFX
var traffic: RoamTraffic
var spawner: PedestrianSpawner
var targets_fn: Callable
var blocked_fn: Callable
var locked: bool = false
var current: int = 0
var ammo: PackedInt32Array = PackedInt32Array()
var reload_left: float = 0.0
var cooldown: float = 0.0
var aiming: bool = false
var rng := RandomNumberGenerator.new()
var spread_scale: float = 1.0            # tests: 0 = no random spread
var fire_override: Variant = null        # bool: fire button held (null = read the mouse)
var aim_override: Variant = null         # bool: aim button held (null = read the mouse)
var reload_override: bool = false        # one press of R, cleared when read
var shots: int = 0
var hit_log: Array[Dictionary] = []      # {"t", "slot", "kind", "target", "reaction"} (last LOG_MAX)
var held: Node3D = null
var _t: float = 0.0
var _fire_prev: bool = false
var _r_prev: bool = false
var _combo: Dictionary = {}              # target instance id -> [hits, game time of the last]
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
var _held_att: BoneAttachment3D = null
var _pending_cues: Array = []            # [game time, cue, position] (the shotgun pump)
var rockets_fired: int = 0
var explosions: Array[Vector3] = []      # tests: every explosion position
var dep_in_flight: bool = false
var dep_returns: int = 0
var last_dep_return: Vector3 = Vector3.ZERO
var stink_clouds: int = 0
var sonic: SonicCone = null
var loa_heat_acc: float = 0.0            # seconds of loa blasting toward the next +1 heat (kept across presses)
var held_hide: Dictionary = {}           # reason -> true: the hand prop is hidden ("emote", "service")
var _need_release: bool = true           # the fire button must be up once before an edge counts
var _was_captured: bool = false
var unarmed_owner: Object = null         # Phase B PlayerCombat: owns the unarmed slot (moves, aim off)
var reserve: PackedInt32Array = PackedInt32Array()   # Phase C: spare rounds per slot (-1 or missing = unlimited)
var locked_slots: Dictionary = {}        # Phase C: slot -> true, cannot be equipped


func _ready() -> void:
	Impact.prepare(self)                     # Q2: the clock and the sound layers ready before the first shot
	rng.seed = 2026
	ammo.resize(WeaponData.COUNT)
	for i: int in WeaponData.COUNT:
		ammo[i] = WeaponData.mag_of(i)
	WeaponAudio.warm()                   # every cue now, at load: equip / scroll never synthesize (R3-I2)
	fx = WeaponFX.new()
	fx.name = "WeaponFX"
	add_child(fx)
	for i: int in 8:
		var p := AudioStreamPlayer3D.new()
		p.name = "Sfx%d" % i
		p.bus = WeaponAudio.bus()
		p.max_distance = 120.0
		p.unit_size = 6.0
		add_child(p)
		_sfx.append(p)


## opts: player (ThirdPersonController), wheel (WeaponWheel), hud (WeaponHUD), targets_fn (-> Array of Node3D), traffic
## (RoamTraffic), spawner (PedestrianSpawner), blocked_fn (-> bool). Call after add_child.
func setup(opts: Dictionary) -> void:
	player = opts.get("player")
	wheel = opts.get("wheel")
	hud = opts.get("hud")
	targets_fn = opts.get("targets_fn", Callable())
	traffic = opts.get("traffic")
	spawner = opts.get("spawner")
	blocked_fn = opts.get("blocked_fn", Callable())
	if wheel:
		wheel.current = current
		wheel.info_fn = ammo_text
		wheel.blocked_fn = is_blocked
		wheel.selected.connect(equip)
		wheel.cycled.connect(cycle)
	_update_held()
	_refresh_hud()


func is_blocked() -> bool:
	return locked or (blocked_fn.is_valid() and bool(blocked_fn.call()))


## The fire button is held on foot this frame (the emote refuses to start, spec section 9).
func is_firing() -> bool:
	return _fire_prev


func ammo_text(slot: int) -> String:
	var r: int = reserve_of(slot)
	if r >= 0 and WeaponData.mag_of(slot) > 0:
		return "%d / %d" % [ammo[slot], r]
	return WeaponData.ammo_text(slot, ammo[slot])


## Spare rounds of a slot (-1 = unlimited).
func reserve_of(slot: int) -> int:
	return reserve[slot] if slot >= 0 and slot < reserve.size() else -1


## Phase C ammo pickup: n more spare rounds for a slot with a finite reserve (an empty magazine reloads at once).
func add_reserve(slot: int, n: int) -> void:
	if reserve_of(slot) < 0 or n <= 0:
		return
	reserve[slot] += n
	if slot == current and ammo[slot] <= 0:
		start_reload()
	_refresh_hud()


## Phase C: these slots cannot be equipped (the equipped one switches to Tay không); the wheel greys them with off_text.
## An empty list unlocks everything.
func set_locked_slots(slots: Array, off_text: String = "") -> void:
	locked_slots.clear()
	for s: Variant in slots:
		if int(s) != WeaponData.Slot.UNARMED:
			locked_slots[int(s)] = true
	if wheel:
		for i: int in mini(wheel.slots.size(), WeaponData.COUNT):
			wheel.slots[i]["enabled"] = not locked_slots.has(i)
			wheel.slots[i]["off_text"] = off_text
	if locked_slots.has(current):
		equip(WeaponData.Slot.UNARMED)
	_refresh_hud()


func equip(slot: int) -> void:
	slot = posmod(slot, WeaponData.COUNT)
	if slot == current or locked_slots.has(slot):
		return
	_on_unequip()
	current = slot
	reload_left = 0.0
	cooldown = maxf(cooldown, 0.15)
	_combo.clear()
	if wheel:
		wheel.current = slot
	_update_held()
	_refresh_hud()
	equipped.emit(slot)


func cycle(step: int) -> void:
	var s: int = current
	for i: int in WeaponData.COUNT:
		s = posmod(s + step, WeaponData.COUNT)
		if not locked_slots.has(s):
			break
	equip(s)
	toast.emit(WeaponData.name_of(current))
	if hud:
		hud.show_toast(WeaponData.name_of(current))


func start_reload() -> void:
	var mag: int = WeaponData.mag_of(current)
	if mag <= 0 or ammo[current] >= mag or reload_left > 0.0 or reserve_of(current) == 0:
		return
	reload_left = float(WeaponData.SLOTS[current]["reload"])
	play_cue("reload", hand_position())
	_refresh_hud()


func _physics_process(delta: float) -> void:
	_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	if player == null:
		return
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			reload_left = 0.0
			var need: int = WeaponData.mag_of(current) - ammo[current]
			var r: int = reserve_of(current)
			if r >= 0:
				need = mini(need, r)
				reserve[current] = r - need
			ammo[current] += need
			_refresh_hud()
	var blocked: bool = is_blocked() or not player.visible
	var wheel_open: bool = wheel != null and wheel.is_open()
	var own: bool = unarmed_owner != null and current == WeaponData.Slot.UNARMED
	aiming = not own and not blocked and not wheel_open and _aim_input() and not player.is_knocked_down()
	player.aiming = aiming
	if hud:
		hud.set_aim(aiming, 4.0 if aiming else 14.0)
	var raw: bool = _fire_input()
	var forced: bool = fire_override is bool
	var captured: bool = forced or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var can: bool = not blocked and not wheel_open and not player.is_knocked_down() and captured
	if not can or (captured and not _was_captured and not forced):
		_need_release = true                 # capture click, wheel close, unblock: wait for the button to come up
	_was_captured = captured
	if not raw:
		_need_release = false
	var fire: bool = can and raw and not _need_release
	var edge: bool = fire and not _fire_prev
	_fire_prev = fire
	_tick_held(delta, fire)
	if not blocked and _reload_input():
		start_reload()
	if not own and fire and (edge or bool(WeaponData.SLOTS[current]["auto"])) and cooldown <= 0.0001 and reload_left <= 0.0:
		try_fire()
	_tick_pending()
	_apply_held_vis()
	_update_held_pose()


## Hide (on = true) or show the hand prop for a reason ("emote", "service"); the prop shows when no reason is left.
func set_held_hidden(reason: String, on: bool) -> void:
	if on:
		held_hide[reason] = true
	else:
		held_hide.erase(reason)
	_apply_held_vis()


func _apply_held_vis() -> void:
	if held:
		held.visible = held_hide.is_empty() and not (current == WeaponData.Slot.DEP and dep_in_flight)


func _fire_input() -> bool:
	if fire_override is bool:
		return fire_override
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _aim_input() -> bool:
	if aim_override is bool:
		return aim_override
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _reload_input() -> bool:
	if reload_override:
		reload_override = false
		return true
	var r: bool = Input.is_physical_key_pressed(KEY_R)
	var edge: bool = r and not _r_prev
	_r_prev = r
	return edge


## One shot / swing / throw of the equipped weapon (cooldown, ammo and reload handled here). The loa ("cone") is held, not
## fired (_tick_held); a second dép waits for the first to come back.
func try_fire() -> void:
	var w: Dictionary = WeaponData.SLOTS[current]
	var kind: String = String(w["kind"])
	var mag: int = int(w["mag"])
	if kind == "cone" or (kind == "boomerang" and dep_in_flight):
		return
	if mag > 0 and ammo[current] <= 0:
		if reserve_of(current) == 0:         # Phase C: out of spare rounds - a dry click, no reload
			cooldown = 0.3
			play_cue("dry_click", hand_position(), -4.0)
		start_reload()
		return
	if not aiming:
		_face_camera()
	cooldown = float(w["cycle"])
	match kind:
		"melee":
			_melee(w)
		"hitscan":
			_hitscan(w)
		"pellets":
			_pellets(w)
		"rocket":
			_fire_rocket(w)
		"boomerang":
			_throw_dep(w)
		"grenade":
			_throw_durian(w)
	if mag > 0:
		ammo[current] -= 1
		if ammo[current] <= 0:
			start_reload()
	shots += 1
	_refresh_hud()
	fired.emit(current)


func _face_camera() -> void:
	if player.model:
		player.model.rotation.y = player.yaw


## The right hand (muzzle / throw origin): chest height, a little forward and to the right of the body.
func hand_position() -> Vector3:
	var f: Vector3 = player.facing_dir()
	return player.global_position + Vector3(0.0, HAND_UP, 0.0) + f * 0.35 + Vector3(-f.z, 0.0, f.x) * 0.22


func aim_origin() -> Vector3:
	return player.camera.global_position


func aim_dir() -> Vector3:
	return -player.camera.global_basis.z


func soft_targets() -> Array:
	if not targets_fn.is_valid():
		return []
	var out: Array = []
	for n: Variant in targets_fn.call():
		if is_instance_valid(n) and (n as Node).is_inside_tree() and (n as Node).has_method("take_hit"):
			out.append(n)
	return out


## Unarmed: the nearest person in front (combo: 1st and 2nd hit stumble, the 3rd within COMBO_S knocks out, +1 heat).
## Knife: everyone inside the 1.4 m arc is knocked out (+2 heat each).
func _melee(w: Dictionary) -> void:
	var unarmed: bool = current == WeaponData.Slot.UNARMED
	if player.model:
		CharacterBuilder.play(player.model, "punch" if unarmed else "chop", 0.35)
	var fwd: Vector3 = player.facing_dir()
	var reach: float = float(w["range"]) + 0.3
	var half: float = deg_to_rad(float(w["half_deg"]))
	var hits: Array = []
	var best: Node3D = null
	var best_d: float = INF
	for n: Node3D in soft_targets():
		if n.has_method("is_down") and bool(n.call("is_down")):
			continue
		if not WeaponMath.in_cone(player.global_position, fwd, half, reach, n.global_position):
			continue
		if unarmed:
			var d: float = WeaponMath.flat(n.global_position, player.global_position)
			if d < best_d:
				best_d = d
				best = n
		else:
			hits.append(n)
	if unarmed and best != null:
		hits = [best]
	for key0: Variant in _combo.keys():       # forget combos older than COMBO_S (bounded)
		if _t - float((_combo[key0] as Array)[1]) > COMBO_S:
			_combo.erase(key0)
	if hits.is_empty():
		play_cue("swish", hand_position(), -4.0)
		return
	for n2: Node3D in hits:
		var info: Dictionary = {"kind": "melee", "from": player.global_position}
		if unarmed:
			var key: int = n2.get_instance_id()
			var c: Array = _combo.get(key, [0, -99.0])
			var count: int = (int(c[0]) if _t - float(c[1]) <= COMBO_S else 0) + 1
			_combo[key] = [count, _t]
			if count < 3:
				info["kind"] = "punch"
			else:
				_combo.erase(key)
		var r: String = hit_target(n2, info)
		play_cue("punch" if unarmed else "knife_hit", n2.global_position + Vector3(0.0, 1.3, 0.0))
		fx.burst("dust", n2.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP, 0.3)
		if r == "knocked_out":
			_heat(WeaponData.HEAT_KO_UNARMED if unarmed else WeaponData.HEAT_KNIFE, n2.global_position, "melee")


## Apply info to one target and add its comic FX (daze stars on a knockout / launch). Returns the reaction.
func hit_target(n: Node3D, info: Dictionary) -> String:
	if not is_instance_valid(n) or not n.has_method("take_hit"):
		return "none"
	var r: String = String(n.call("take_hit", info))
	if r == "knocked_out" or r == "launched":
		var ko: Variant = n.get("ko_left")
		fx.stars(n, (float(ko) if ko != null else 6.0) + (1.0 if r == "launched" else 0.0))
	_hit_feedback(n, info, r)
	hit_log.append({"t": _t, "slot": current, "kind": String(info.get("kind", "")), "target": String(n.name), "reaction": r})
	if hit_log.size() > LOG_MAX:
		hit_log.pop_front()
	return r


## Q2: the hit marker and its tick for any hit person; a gunshot knockout is a finisher-tier impact.
func _hit_feedback(n: Node3D, info: Dictionary, r: String) -> void:
	if r == "none" or r == "":
		return
	var ko: bool = r == "knocked_out" or r == "launched"
	if hud:
		hud.hit_marker(ko)
	Impact.sound(self, "ko_tick" if ko else "hit_tick", n.global_position, -2.0 if ko else -6.0)
	var kind: String = String(info.get("kind", ""))
	if ko and (kind == "bullet" or kind == "pellet"):
		# an encounter enemy (Gunman, a fight's MeleeEnemy) gets the finisher tier; pedestrians and officers the heavy one
		var tier: String = "finisher" if n.has_method("is_hostile") else "heavy"
		Impact.hit(self, tier, {"pos": n.global_position + Vector3(0.0, 1.2, 0.0), "dir": WeaponMath.flat_dir(n.global_position - player.global_position),
			"fx": fx, "no_punch": true, "fx_k": 0.6})


## Q2 camera recoil of a shot (kicks back along the aim).
func _recoil(kind: String, d: Vector3) -> void:
	Impact.punch(self, float(RECOIL.get(kind, 0.1)), -d)


func _heat(amount: float, at: Vector3, cause: String) -> void:
	if amount > 0.0:
		mayhem.emit(amount, at, cause)


func _people_near(p: Vector3, r: float) -> bool:
	for n: Node3D in soft_targets():
		if WeaponMath.flat(n.global_position, p) <= r:
			return true
	return false


## Play a cue (WeaponAudio: user://sfx/<cue>.ogg override, else synthesized) at a world position.
func play_cue(cue: String, at: Vector3, db: float = 0.0) -> void:
	if _sfx.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = WeaponAudio.stream(cue)
	p.volume_db = db
	p.global_position = at
	p.play()


func _refresh_hud() -> void:
	if hud:
		hud.set_weapon(current, ammo_text(current), reload_left > 0.0)
	if wheel and wheel.view:
		wheel.view.queue_redraw()


## The equipped weapon's prop in the right hand, on a BoneAttachment3D at Wrist.R (non-rigged bodies: fixed offset).
func _update_held() -> void:
	if held:
		held.queue_free()
		held = null
	if player == null or player.model == null:
		return
	held = WeaponProps.build(current)
	if held == null:
		return
	_apply_held_vis()                        # a dép still in flight is not in the hand
	var sk: Skeleton3D = player.model.get_meta("skeleton", null) as Skeleton3D
	if sk and sk.find_bone("Wrist.R") >= 0:
		if _held_att == null or not is_instance_valid(_held_att):
			_held_att = BoneAttachment3D.new()
			_held_att.name = "WeaponHold"
			_held_att.bone_name = "Wrist.R"
			sk.add_child(_held_att)
		_held_att.add_child(held)
	else:
		player.model.add_child(held)
		held.position = Vector3(0.25, 1.05, -0.25)


## Pose the prop in the body frame every frame (barrel along the body's -Z, pitched with the camera while aiming).
func _update_held_pose() -> void:
	if held == null or _held_att == null or not is_instance_valid(_held_att) or held.get_parent() != _held_att:
		return
	var sk: Skeleton3D = _held_att.get_parent() as Skeleton3D
	var b: int = sk.find_bone("Wrist.R")
	var hand: Transform3D = sk.global_transform * CharacterBuilder._bone_global_now(sk, b)
	var body: Basis = player.model.global_basis.orthonormalized()
	if aiming:
		body = body * Basis(Vector3.RIGHT, player.pitch)
	held.transform = hand.affine_inverse() * Transform3D(body, hand.origin)


## Bodies a shot's world ray ignores: the player, every physical target (they are tested analytically) and the traffic.
func _exclusions() -> Array[RID]:
	var ex: Array[RID] = [player.get_rid()]
	for n: Node3D in soft_targets():
		if n is CollisionObject3D:
			ex.append((n as CollisionObject3D).get_rid())
	if traffic:
		for b: Variant in traffic.bodies():
			ex.append((b as CollisionObject3D).get_rid())
	return ex


## First thing along a ray (unit d) within max_d: the world (physics ray, _exclusions() ignored), people as upright capsules
## SOFT_R x SOFT_H (downed ones skipped), vehicles as their boxes. {"t", "kind": "none" | "world" | "soft" | "vehicle",
## "pos", "normal", "node" (soft), "vehicle" (index)}.
func first_hit(o: Vector3, d: Vector3, max_d: float, ex: Array[RID] = []) -> Dictionary:
	var best: Dictionary = {"t": max_d, "kind": "none", "pos": o + d * max_d, "normal": -d}
	if is_inside_tree():
		var rq := PhysicsRayQueryParameters3D.create(o, o + d * max_d)
		rq.exclude = ex if not ex.is_empty() else _exclusions()
		rq.collide_with_areas = false
		var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(rq)
		if not h.is_empty():
			best = {"t": o.distance_to(h["position"]), "kind": "world", "pos": h["position"], "normal": h["normal"]}
	for n: Node3D in soft_targets():
		if n.has_method("is_down") and bool(n.call("is_down")):
			continue
		var t: float = WeaponMath.ray_capsule(o, d, n.global_position, SOFT_R, SOFT_H)
		if t >= 0.0 and t < float(best["t"]):
			best = {"t": t, "kind": "soft", "node": n, "pos": o + d * t, "normal": -d}
	if traffic:
		for idx: int in traffic.active_indices():
			var bx: Array = traffic.vehicle_box(idx)
			var t2: float = WeaponMath.ray_box(o, d, bx[0], bx[1])
			if t2 >= 0.0 and t2 < float(best["t"]):
				best = {"t": t2, "kind": "vehicle", "vehicle": idx, "pos": o + d * t2, "normal": -d}
	return best


## Pistol: one hitscan round from the camera centre (spread 0.5° aimed, 3.5° hip), tracer from the hand.
func _hitscan(w: Dictionary) -> void:
	var d0: Vector3 = aim_dir()
	var spread: float = float(w["spread_aim"] if aiming else w["spread_hip"]) * spread_scale
	var d: Vector3 = WeaponMath.spread_dir(d0, spread, rng)
	var start: Vector3 = aim_origin() + d0 * (player.camera.position.z + 0.3)   # skip the stretch behind the player
	var h: Dictionary = first_hit(start, d, float(w["range"]))
	var muzzle: Vector3 = hand_position()
	fx.muzzle(muzzle, d)
	fx.tracer(muzzle, h["pos"])
	play_cue("shot_pistol", muzzle)
	_recoil("hitscan", d0)
	if _people_near(player.global_position, WeaponData.NEAR_PEOPLE_M):
		_heat(WeaponData.HEAT_SHOT_NEAR, player.global_position, "shot")
	_resolve_bullet(h, d, WeaponData.HEAT_PISTOL_HIT)
	_scare(player.global_position, SCARE_GUN_R)


## One bullet's result: a person is knocked out, a vehicle stops (its rider flees), a wall sparks; +heat_hit per hit.
func _resolve_bullet(h: Dictionary, d: Vector3, heat_hit: float) -> void:
	match String(h["kind"]):
		"soft":
			var n: Node3D = h["node"]
			if hit_target(n, {"kind": "bullet", "from": player.global_position, "dir": WeaponMath.flat_dir(d)}) != "none":
				_heat(heat_hit, n.global_position, "hit")
			fx.impact(h["pos"], -d, true)
		"vehicle":
			if traffic and traffic.hit_vehicle(int(h["vehicle"]), "bullet", player.global_position):
				_heat(heat_hit, h["pos"], "vehicle")
			fx.impact(h["pos"], h["normal"], false)
			play_cue("ricochet", h["pos"], -6.0)
		"world":
			fx.impact(h["pos"], h["normal"], false)


## Shotgun: 8 pellets in a 9° cone (hip adds half the hip spread); each person / vehicle reacts once per shot: people are
## flung `knockback` m back and knocked out, vehicles stop. +3 heat if it hit someone or was fired near people.
func _pellets(w: Dictionary) -> void:
	var d0: Vector3 = aim_dir()
	var half: float = float(w["cone_deg"]) * 0.5 + (0.0 if aiming else float(w["spread_hip"]) * 0.5 * spread_scale)
	var start: Vector3 = aim_origin() + d0 * (player.camera.position.z + 0.3)
	var muzzle: Vector3 = hand_position()
	var ex: Array[RID] = _exclusions()
	var kh: float = float(w["knockback"]) / (2.0 * KNOCK_UP / Pedestrian.GRAVITY)
	var struck: Dictionary = {}
	var cars: Dictionary = {}
	var any: bool = false
	for i: int in int(w["pellets"]):
		var d: Vector3 = WeaponMath.spread_dir(d0, half, rng)
		var h: Dictionary = first_hit(start, d, float(w["range"]), ex)
		if i % 2 == 0:
			fx.tracer(muzzle, h["pos"])
		match String(h["kind"]):
			"soft":
				var n: Node3D = h["node"]
				if not struck.has(n.get_instance_id()):
					struck[n.get_instance_id()] = true
					var f: Vector3 = WeaponMath.flat_dir(d)
					if hit_target(n, {"kind": "pellet", "from": player.global_position, "dir": f, "vel": f * kh + Vector3(0.0, KNOCK_UP, 0.0)}) != "none":
						any = true
				fx.impact(h["pos"], -d, true)
			"vehicle":
				var idx: int = int(h["vehicle"])
				if not cars.has(idx):
					cars[idx] = true
					if traffic and traffic.hit_vehicle(idx, "bullet", player.global_position):
						any = true
				fx.impact(h["pos"], h["normal"], false)
			"world":
				fx.impact(h["pos"], h["normal"], false)
	fx.muzzle(muzzle, d0, 1.6)
	play_cue("shot_shotgun", muzzle, 2.0)
	_recoil("pellets", d0)
	_pending_cues.append([_t + PUMP_DELAY, "pump", muzzle])
	if any or _people_near(player.global_position, WeaponData.NEAR_PEOPLE_M):
		_heat(WeaponData.HEAT_SHOTGUN, player.global_position, "shotgun")
	_scare(player.global_position, SCARE_GUN_R)


## Gunfire / blasts scare the pedestrians around (they flee); officers ignore "scare".
func _scare(at: Vector3, r: float) -> void:
	for n: Node3D in soft_targets():
		if WeaponMath.flat(n.global_position, at) <= r and not (n.has_method("is_down") and bool(n.call("is_down"))):
			n.call("take_hit", {"kind": "scare", "from": at})


func _tick_pending() -> void:
	for i: int in range(_pending_cues.size() - 1, -1, -1):
		var e: Array = _pending_cues[i]
		if _t >= float(e[0]):
			play_cue(String(e[1]), e[2])
			_pending_cues.remove_at(i)


## Tên lửa: a WeaponRocket from the right shoulder toward the point under the crosshair (first_hit of the camera ray).
func _fire_rocket(w: Dictionary) -> void:
	var d0: Vector3 = aim_dir()
	var h: Dictionary = first_hit(aim_origin() + d0 * (player.camera.position.z + 0.3), d0, float(w["range"]))
	var f: Vector3 = player.facing_dir()
	var from: Vector3 = player.global_position + Vector3(0.0, ROCKET_UP, 0.0) + f * 0.5 + Vector3(-f.z, 0.0, f.x) * 0.25
	var chest: Vector3 = player.global_position + Vector3(0.0, ROCKET_UP, 0.0)
	var wall: Dictionary = _world_ray(chest, from)
	if not wall.is_empty():
		# point blank against a wall: the launch point is inside it, the rocket would fly through - comic blast right here
		var at: Vector3 = (wall["position"] as Vector3) + (wall["normal"] as Vector3) * 0.05
		fx.muzzle(at, f, 1.2)
		play_cue("rocket_launch", at, 2.0)
		rockets_fired += 1
		explode_at(at)
		return
	var to: Vector3 = h["pos"]
	var d: Vector3 = (to - from).normalized() if float(h["t"]) > 2.0 else d0
	var r := WeaponRocket.new()
	r.name = "Rocket"
	add_child(r)
	r.launch(self, from, d)
	r.exploded.connect(explode_at)
	fx.muzzle(from, d, 1.2)
	play_cue("rocket_launch", from, 2.0)
	_recoil("rocket", d)
	rockets_fired += 1
	if player.model:
		CharacterBuilder.play(player.model, "flinch", 0.3)


## World geometry between two points (people and traffic ignored, like the shots): the hit Dictionary or {}.
func _world_ray(a: Vector3, b: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var rq := PhysicsRayQueryParameters3D.create(a, b)
	rq.exclude = _exclusions()
	rq.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(rq)


## Rocket explosion (spec section 3): flash, sparks, dust, smoke, scorch, camera shake; people within the radius fly in comic
## arcs and land knocked out, vehicles flip and smoke, the player inside it is knocked down (never hurt), bystanders flee,
## impostors scatter. +6 heat.
func explode_at(pos: Vector3) -> void:
	var rad: float = float(WeaponData.SLOTS[WeaponData.Slot.ROCKET]["radius"])
	explosions.append(pos)
	if explosions.size() > LOG_MAX:
		explosions.remove_at(0)
	fx.explosion(pos, rad, _exclusions())
	play_cue("explosion", pos, 6.0)
	var pd: float = player.global_position.distance_to(pos)
	if player.visible:                       # riding: the player body is hidden, no shake / SPLAT after dismounting
		if pd < 40.0:
			player.shake(lerpf(1.0, 0.15, pd / 40.0))
		if pd <= rad:
			player.knock_down(player.global_position - pos, 4.0)
	for n: Node3D in soft_targets():
		var d: float = WeaponMath.flat(n.global_position, pos)
		if d > rad or absf(n.global_position.y - pos.y) > 4.0:
			continue
		var k: float = clampf(d / rad, 0.0, 1.0)
		var away: Vector3 = WeaponMath.flat_dir(n.global_position - pos)
		hit_target(n, {"kind": "blast", "from": pos, "vel": away * lerpf(9.0, 4.0, k) + Vector3(0.0, lerpf(10.0, 6.0, k), 0.0)})
	if traffic:
		for idx: int in traffic.vehicles_near(pos, rad):
			traffic.hit_vehicle(idx, "blast", pos)
	if spawner:
		spawner.scatter_impostors(pos, IMPOSTOR_BLAST_R)
	_scare(pos, SCARE_BLAST_R)
	_heat(WeaponData.HEAT_ROCKET, pos, "rocket")


## Dép tổ ong: thrown flat along the camera direction from the hand; the hand prop hides until it comes back.
func _throw_dep(w: Dictionary) -> void:
	var d := WeaponDep.new()
	d.name = "Dep"
	add_child(d)
	d.launch(self, hand_position(), WeaponMath.flat_dir(aim_dir()), float(w["reach"]))
	d.returned.connect(_on_dep_returned)
	dep_in_flight = true
	_apply_held_vis()
	play_cue("dep_whoosh", hand_position(), -2.0)
	if player.model:
		CharacterBuilder.play(player.model, "punch", 0.3)


func _on_dep_returned(at: Vector3) -> void:
	dep_in_flight = false
	dep_returns += 1
	last_dep_return = at
	_apply_held_vis()


## A dép bonk: knocked out DEP_KO_S with stars, "bonk", +1 heat.
func dep_hit(n: Node3D, at: Vector3) -> void:
	var r: String = hit_target(n, {"kind": "bonk", "from": at, "ko": DEP_KO_S})
	play_cue("bonk", at, 2.0)
	fx.burst("dust", at, Vector3.UP, 0.3)
	if r == "knocked_out":
		_heat(WeaponData.HEAT_DEP, n.global_position, "dep")


## Sầu riêng: lobbed forward (THROW_SPEED m/s, THROW_UP up); bursts into a StinkCloud after its fuse.
func _throw_durian(_w: Dictionary) -> void:
	var v: Vector3 = (WeaponMath.flat_dir(aim_dir()) + Vector3(0.0, THROW_UP, 0.0)).normalized() * THROW_SPEED
	var g := WeaponDurian.new()
	g.name = "Durian"
	add_child(g)
	g.launch(hand_position() + Vector3(0.0, 0.2, 0.0), v, _exclusions())
	g.burst.connect(spawn_stink)
	play_cue("dep_whoosh", hand_position(), -6.0)
	if player.model:
		CharacterBuilder.play(player.model, "punch", 0.3)


## Sầu riêng burst: a StinkCloud (8 m wide, 6 s) at pos; vehicles inside stop; +2 heat.
func spawn_stink(pos: Vector3) -> StinkCloud:
	var w: Dictionary = WeaponData.SLOTS[WeaponData.Slot.DURIAN]
	var c := StinkCloud.new()
	c.name = "StinkCloud"
	add_child(c)
	c.setup(self, pos, float(w["cloud_r"]), float(w["cloud_s"]))
	if traffic:
		traffic.add_stop_zone(pos, float(w["cloud_r"]), float(w["cloud_s"]))
	play_cue("durian_pop", pos)
	stink_clouds += 1
	_heat(WeaponData.HEAT_DURIAN, pos, "durian")
	return c


## Loa kẹo kéo: blasting while the fire button is held (music + SonicCone); stops on release, unequip and when blocked.
func _tick_held(delta: float, fire: bool) -> void:
	if current == WeaponData.Slot.LOA and fire:
		if sonic == null:
			sonic = SonicCone.new()
			sonic.name = "SonicCone"
			add_child(sonic)
			sonic.setup(self)
		if not aiming:
			_face_camera()
		sonic.tick(delta, player.global_position + Vector3(0.0, 1.2, 0.0), WeaponMath.flat_dir(aim_dir()))
		if player.model:
			CharacterBuilder.play(player.model, "carry", 0.25)
	elif sonic != null:
		sonic.stop()
		sonic = null


func _on_unequip() -> void:
	if sonic != null:
		sonic.stop()
		sonic = null
