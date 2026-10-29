# File: res://scripts/combat/guns/Gunman.gd
# One enemy gunman of the Phase C lair gunfights (spec C-D2): a lair guard in black with a sheep, wolf or fox mask (PS2
# rigged body from CharacterBuilder, or the caller's body_fn) holding a pistol, and an AI state machine:
#   PATROL    walks its patrol points (or stands guard looking around) until it sees the player (120° cone, 28 m, clear
#             ray) or hears him (gunfire 30 m through walls, sprint 9 m, jog 4 m) or an alerted guard calls (14 m);
#   ALERT     "Có biến!" over the head, turns to the noise for 0.6 s;
#   TO_COVER  runs to the best free CoverMap slot whose obstacle stands between it and the player (CoverMap.candidates);
#   COVER     crouched behind it (hit capsule lowered); waits 0.7-1.8 s, then asks the fight for a shooting token (at most
#             GunData.max_shooters() at once); the cover stops protecting (the player moved round) -> new cover;
#   PEEK      stands up and aims (0.3 s); each bullet = a muzzle GLINT for GunData.telegraph_s() (Thường 0.35 s, Dễ 0.45 s;
#             read at the glint's start) and only then the shot
#             (a burst of 1-3); the shot needs a clear ray from the muzzle at the moment it resolves: a wall or the cover the
#             player ducked behind stops it (sparks, no damage); a readable red tracer; hit chance from GunData.hit_chance
#             (distance, player speed, popping out of cover, first shot, x GunData.accuracy_k() by difficulty); no clear ray
#             for 1.2 s -> back down;
#   FLANK     after 2-3 peeks from one slot: runs to a slot at least 50° round the player (CoverMap.flank_candidates);
#   OPEN      no usable cover: walks to about 11 m and shoots standing, looking for cover every 2 s;
#   STAGGER   a hit that does not knock out: flinch 0.45 s, the telegraph and the token are lost;
#   KO        knocked out (comic fall, stars from WeaponDirector.hit_target, no blood): stays down, never hit again;
#   HOLD      ai off (tests, scripted beats): stands still; IDLE: the fight was lost, stands down.
# Plain Node3D like HorrorStalker (no physics body: bullets test it analytically, WeaponDirector.first_hit). It only moves
# along a straight line it can walk (GunFight.clear_walk at knee and chest height) or a HorrorNavGraph route whose every
# leg is walkable; a spot it cannot reach is never chosen (no ghosting through walls). It follows the floor height with a
# down-ray while moving (ramps, stairs) and keeps SEPARATION_M from the other gunmen while standing in the open. It only
# asks for a shooting token when its standing muzzle has a clear line to the player (cover it cannot shoot over, or a
# hidden player: after NO_LINE_TRIES waits it flanks), and only uses cover up to GUNMAN_COVER_MAX_H high. The root never
# rotates (the body child carries the yaw). The hit capsule base (the root) is lowered by `drop` while crouched
# (GunData.CROUCH_DROP) or knocked out (KO_DROP); feet() is the floor point. Senses run at 10 Hz (staggered), one ray each;
# line / walk / floor checks while waiting or walking at most 10 Hz; no allocation per frame except on decisions.
# Usage (GunFight does this): var g := Gunman.new(); g.setup(opts); g.position = at; parent.add_child(g); g.bind(fight).
# opts: "body" (CharacterBuilder opts over GunData.GUARD_LOOK), "body_fn" (Callable(look) -> rigged Node3D), "mask"
# ("sheep" | "wolf" | "fox" | "none"; default by seed), "label", "hp", "accuracy" (scale), "kind" ("shield": the pallet
# guard below), "patrol" (Array of Vector3),
# "ai" (false = HOLD), "alerted" (start alerted), "seed", "yaw", "sight_m" / "fov_deg" (sight before the alert; default
# GunData.SIGHT_M / FOV_DEG).
# Pallet-shield guard (opts "kind": "shield", Wave 3 plan 2026-10-30-w3-shared.md T3): carries a code-built pallet in
# front (GunProps.pallet, rimmed). A hit from within SHIELD_FRONT_DEG of his front lands on the pallet: no damage, wood chips
# (FxPool "debris"), a thunk, "Không xuyên!" over his head once; flank and back hits count as usual. He never takes cover
# while he holds it: he walks in to SHIELD_KEEP_M, turns slowly (SHIELD_TURN_RATE: flank him) and fires short bursts round
# the pallet's right edge. A shotgun hit on the pallet from under SHIELD_SHOTGUN_M or GunData.shield_hits() hits (4, Dễ 3)
# knock it away (Impact heavy, the pallet flies off, he staggers) and he fights on as a normal gunman. A knockout drops it.
# Q2 feel (plan 2026-10-29-q2-feel.md T4): every hit jolts the body away from the shot (a quick lean that settles in
# JOLT_S, over the flinch clip); a knockout sends the mask (or a cap when there is none) flying off with a spin and one
# bounce; it then lies on the floor.
class_name Gunman
extends Node3D

signal ko(g: Gunman)
signal alerted(g: Gunman)
signal telegraph_started(g: Gunman)
signal shot(g: Gunman, result: String)
signal shield_dropped(g: Gunman)

enum St { PATROL, ALERT, TO_COVER, COVER, PEEK, OPEN, FLANK, STAGGER, KO, HOLD, IDLE }
const ST_NAMES: Array[String] = ["patrol", "alert", "to_cover", "cover", "peek", "open", "flank", "stagger", "ko", "hold", "idle"]
const LOG_MAX: int = 48
const SHOUT_S: float = 1.2

var fight: Object = null
var body: Node3D
var pose: GunPose
var gun: Node3D = null
var glint: MeshInstance3D
var shout: Label3D
var label: String = ""
var mask_kind: String = ""
var hp: float = GunData.GUNMAN_HP
var max_hp: float = GunData.GUNMAN_HP
var accuracy_k: float = 1.0
## Tests: >= 0 replaces the hit chance of every shot.
var accuracy_override: float = -1.0
var ai: bool = true
var start_alerted: bool = false
## Sight while not alerted (opts "sight_m" / "fov_deg"; Phase C story sneaks use the horror toolkit's 14 m / 70 deg).
var patrol_sight_m: float = GunData.SIGHT_M
var patrol_fov_deg: float = GunData.FOV_DEG
var st: int = St.HOLD
var st_t: float = 0.0
var state_log: Array[String] = []
var yaw: float = 0.0
var floor_y: float = 0.0
var drop: float = 0.0
var slot: int = -1
var has_token: bool = false
var telegraphing: bool = false
var tele_t: float = 0.0
var burst_left: int = 0
var peeks: int = 0
var peeks_max: int = 2
var patrol: PackedVector3Array = PackedVector3Array()
var sees: bool = false
var last_seen: Vector3 = Vector3.ZERO
var is_alerted: bool = false
var first_shot: bool = true
var shots: int = 0
var hits: int = 0
var tele_starts: int = 0
## Telegraph seconds actually shown before each resolved shot (tests: every value >= telegraph_s()).
var tele_before_shot: Array[float] = []
## The current glint's length (GunData.telegraph_s() when it started).
var tele_len: float = GunData.TELEGRAPH_S
var ko_left: float = GunData.KO_STARS_S
var speed_now: float = 0.0
var _patrol_i: int = 0
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _wait: float = 0.0
var _gap: float = 0.0
var _sense_acc: float = 0.0
var _recheck: float = 0.0
var _stuck_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _since_seen: float = 99.0
var _shout_left: float = 0.0
var _open_look: float = 0.0
var _ray_t: float = 0.0
var _floor_t: float = 0.0
var _sep_t: float = 0.0
var _sep_v: Vector3 = Vector3.ZERO
var _step_to: Vector3 = Vector3.ZERO
var _step_ok: bool = false
var _no_line: int = 0
var _rng := RandomNumberGenerator.new()
var _anim: Node = null
var _sk: Skeleton3D = null
var _wrist: int = -1
var _gun_att: BoneAttachment3D = null
## Wave 3 pallet-shield guard: kind "" | "shield"; the pallet (a child of the body while held), hits on it.
var kind: String = ""
var shield: Node3D = null
var shield_up: bool = false
var shield_hits: int = 0
var blocked_hits: int = 0
var _said_no_pierce: bool = false
var _pallet_v: Vector3 = Vector3.ZERO
var _pallet_spin: Vector3 = Vector3.ZERO
var _pallet_bounced: bool = false
var _pallet_fly: bool = false
## Q2: the hit jolt and the flying mask / cap.
const JOLT_S: float = 0.28
const JOLT_LEAN: float = 0.3
var jolts: int = 0
var jolt_t: float = 0.0
var flying_hat: Node3D = null
var _jolt_dir: Vector3 = Vector3.ZERO
var _hat_v: Vector3 = Vector3.ZERO
var _hat_spin: Vector3 = Vector3.ZERO
var _hat_bounced: bool = false
var _hat_rest: bool = false


## Build the body, mask, pistol, glint and shout label (before add_child). See the header for opts.
func setup(opts: Dictionary = {}) -> void:
	_rng.seed = int(opts.get("seed", 1))
	label = String(opts.get("label", ""))
	max_hp = float(opts.get("hp", GunData.GUNMAN_HP))
	hp = max_hp
	accuracy_k = float(opts.get("accuracy", 1.0))
	accuracy_override = float(opts.get("accuracy_override", -1.0))
	ai = bool(opts.get("ai", true))
	start_alerted = bool(opts.get("alerted", false))
	patrol_sight_m = float(opts.get("sight_m", GunData.SIGHT_M))
	patrol_fov_deg = float(opts.get("fov_deg", GunData.FOV_DEG))
	yaw = float(opts.get("yaw", 0.0))
	peeks_max = _rng.randi_range(GunData.PEEKS_BEFORE_FLANK.x, GunData.PEEKS_BEFORE_FLANK.y)
	_sense_acc = _rng.randf() * GunData.SENSE_DT
	for v: Variant in opts.get("patrol", []):
		patrol.append(v)
	var look: Dictionary = GunData.GUARD_LOOK.duplicate()
	look["seed"] = 7000 + _rng.randi_range(0, 999)
	var bo: Dictionary = opts.get("body", {})
	for k: String in bo.keys():
		look[k] = bo[k]
	look["rigged"] = true
	look["name"] = "Body"
	var bf: Callable = opts.get("body_fn", Callable())
	body = bf.call(look) if bf.is_valid() else CharacterBuilder.build(look)
	body.name = "Body"
	add_child(body)
	body.rotation.y = yaw
	mask_kind = String(opts.get("mask", GunData.MASKS[_rng.randi_range(0, GunData.MASKS.size() - 1)]))
	if mask_kind != "none" and mask_kind != "":
		GunProps.attach_mask(body, mask_kind)
	pose = GunPose.attach(body)
	_anim = CharacterBuilder.get_animator(body)
	_attach_gun()
	Readability.rim(body, "enemy")   # Q3 rim
	kind = String(opts.get("kind", ""))
	if kind == "shield":
		shield = GunProps.pallet()
		shield.position = Vector3(-0.1, 0.28, -0.5)
		shield.rotation.x = -0.08
		body.add_child(shield)
		Readability.rim(shield, "enemy")   # the pallet's edge reads like the enemy it shields
		shield_up = true
	glint = GunProps.glint()
	add_child(glint)
	shout = Label3D.new()
	shout.name = "Shout"
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.no_depth_test = true
	shout.font_size = 44
	shout.outline_size = 10
	shout.modulate = Color("#FFE14D")
	shout.outline_modulate = Color("#1B0F33")
	shout.pixel_size = 0.006
	shout.visible = false
	shout.position = Vector3(0.0, 2.25, 0.0)
	add_child(shout)


func _attach_gun() -> void:
	gun = WeaponProps.build(WeaponData.Slot.PISTOL)
	if gun == null:
		return
	_sk = body.get_meta("skeleton", null) as Skeleton3D
	_wrist = _sk.find_bone("Wrist.R") if _sk else -1
	if _wrist >= 0:
		_gun_att = BoneAttachment3D.new()
		_gun_att.name = "GunHold"
		_gun_att.bone_name = "Wrist.R"
		_sk.add_child(_gun_att)
		_gun_att.add_child(gun)
	else:
		body.add_child(gun)
		gun.position = Vector3(0.25, 1.05, -0.25)


## Wire to the fight (GunFight); the spawn height is the floor.
func bind(f: Object) -> void:
	fight = f
	floor_y = global_position.y
	_last_pos = global_position
	if not ai:
		_enter(St.HOLD)
		return
	_enter(St.PATROL)
	if start_alerted:
		alert(f.call("player_feet"))


func state_name() -> String:
	return ST_NAMES[st]


func feet() -> Vector3:
	return Vector3(global_position.x, floor_y, global_position.z)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## The pistol's muzzle (standing aim), for the glint, the flash and the ray.
func muzzle_pos() -> Vector3:
	var f: Vector3 = forward()
	var side: float = GunData.SHIELD_MUZZLE_SIDE if shield_up else 0.12
	return feet() + Vector3(0.0, GunData.MUZZLE_Y, 0.0) + f * 0.55 + Vector3(-f.z, 0.0, f.x) * side


func is_down() -> bool:
	return st == St.KO


## The node the player's weapons test (WeaponDirector targets): the gunman itself.
func hit_node() -> Node3D:
	return self


func is_hostile() -> bool:
	return st != St.KO and st != St.IDLE


func is_defeated() -> bool:
	return st == St.KO


## Holding a shooting token (peeking / telegraphing / firing).
func is_shooting() -> bool:
	return has_token


func crouched() -> bool:
	return drop > 0.01 and st != St.KO


# ---------------------------------------------------------------------------
# FRAME
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if fight == null:
		return
	st_t += delta
	_since_seen += delta
	if _shout_left > 0.0:
		_shout_left -= delta
		if _shout_left <= 0.0:
			shout.visible = false
	if jolt_t > 0.0:
		_tick_jolt(delta)
	if flying_hat != null and not _hat_rest:
		_tick_hat(delta)
	if _pallet_fly:
		_tick_pallet(delta)
	if st == St.KO or st == St.IDLE or st == St.HOLD:
		_apply_drop()
		if _anim:
			_anim.set("speed", 0.0)
		return
	_sense_acc += delta
	if _sense_acc >= GunData.SENSE_DT:
		_sense_acc -= GunData.SENSE_DT
		_sense()
	speed_now = 0.0
	match st:
		St.PATROL:
			_do_patrol(delta)
		St.ALERT:
			_turn_toward(last_seen - feet(), delta)
			_separate(delta)
			if st_t >= GunData.REACT_S:
				_seek_cover(false)
		St.TO_COVER, St.FLANK:
			_do_travel(delta)
		St.COVER:
			_do_cover(delta)
		St.PEEK:
			_do_peek(delta)
		St.OPEN:
			_do_open(delta)
		St.STAGGER:
			if st_t >= GunData.STAGGER_S:
				_after_hit()
	_apply_drop()
	if _anim:
		_anim.set("speed", speed_now)
	_update_gun()


func _enter(s: int) -> void:
	st = s
	st_t = 0.0
	state_log.append(ST_NAMES[s])
	if state_log.size() > LOG_MAX:
		state_log.pop_front()
	match s:
		St.COVER:
			_wait = _rng.randf_range(GunData.COVER_WAIT.x, GunData.COVER_WAIT.y)
			_recheck = GunData.RECHECK_S
			pose.set_pose("cover_crouch")
		St.PEEK:
			pose.set_pose("aim")
			_gap = 0.0
			_ray_t = 0.0
			_no_line = 0
			burst_left = _rng.randi_range(GunData.SHIELD_BURST.x, GunData.SHIELD_BURST.y) if shield_up \
				else _rng.randi_range(GunData.BURST.x, GunData.BURST.y)
		St.OPEN:
			_wait = _rng.randf_range(GunData.COVER_WAIT.x, GunData.COVER_WAIT.y)
			_open_look = 2.0
			pose.set_pose("aim")
		St.STAGGER:
			pose.clear()
			CharacterBuilder.play(body, "flinch", GunData.STAGGER_S)
		St.TO_COVER, St.FLANK, St.PATROL, St.ALERT:
			pose.clear()
		St.IDLE, St.HOLD:
			pose.clear()


## Crouched in cover (not peeking) = the hit capsule lowered; standing otherwise; KO on the floor.
func _apply_drop() -> void:
	var want: float = 0.0
	if st == St.KO:
		want = GunData.KO_DROP
	elif st == St.COVER or (st == St.STAGGER and slot >= 0):
		want = GunData.CROUCH_DROP
	if not is_equal_approx(want, drop):
		drop = want
	var p: Vector3 = global_position
	if not is_equal_approx(p.y, floor_y - drop):
		global_position = Vector3(p.x, floor_y - drop, p.z)
		body.position.y = drop
		glint.position.y = drop
		shout.position.y = drop + 2.25


# ---------------------------------------------------------------------------
# SENSES
# ---------------------------------------------------------------------------
func _sense() -> void:
	var pp: Vector3 = fight.call("player_feet")
	var tp: Vector3 = fight.call("player_target")
	var eye: Vector3 = feet() + Vector3(0.0, GunData.EYE_Y - drop, 0.0)
	var to := Vector3(tp.x - eye.x, 0.0, tp.z - eye.z)
	var d: float = to.length()
	var in_view: bool = d <= (GunData.SIGHT_M if is_alerted else patrol_sight_m)
	if in_view and not is_alerted and d > 0.5:
		in_view = forward().angle_to(to / d) <= deg_to_rad(patrol_fov_deg * 0.5)
	sees = in_view and bool(fight.call("clear_line", eye, tp))
	if sees:
		last_seen = pp
		_since_seen = 0.0
	if is_alerted:
		return
	if sees:
		alert(pp)
		return
	var noise: float = float(fight.call("noise_radius"))
	if noise > 0.0 and WeaponMath.flat(pp, feet()) <= noise:
		alert(pp)


## Heard gunfire / a scream at p (GunFight: the player's shots within HEAR_SHOT_M; WeaponDirector "scare").
func hear(p: Vector3) -> void:
	if st == St.KO or st == St.IDLE or st == St.HOLD:
		return
	if not is_alerted:
		alert(p)


## Alerted (saw / heard the player, or a guard called): "Có biến!", turn, then cover. Shared with the guards nearby.
func alert(at: Vector3) -> void:
	if is_alerted or st == St.KO or st == St.IDLE or st == St.HOLD:
		return
	is_alerted = true
	last_seen = at
	shout.text = GunData.T_ALERT
	shout.visible = true
	_shout_left = SHOUT_S
	_enter(St.ALERT)
	alerted.emit(self)
	if fight and fight.has_method("on_alert"):
		fight.call("on_alert", self)


# ---------------------------------------------------------------------------
# STATES
# ---------------------------------------------------------------------------
func _do_patrol(delta: float) -> void:
	if patrol.is_empty():
		yaw += sin(st_t * 0.8) * 0.6 * delta   # stands guard, looking around
		body.rotation.y = yaw
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if _path_i >= _path.size():
		_patrol_i = (_patrol_i + 1) % patrol.size()
		if not _go(patrol[_patrol_i]):
			_wait = 1.2                      # that patrol point cannot be walked to: try the next one later
			return
	if _move(delta, GunData.WALK_SPEED):
		_wait = 1.2


func _do_travel(delta: float) -> void:
	if _move(delta, GunData.RUN_SPEED):
		_enter(St.COVER)
		return
	if global_position.distance_to(_last_pos) > 0.5:
		_last_pos = global_position
		_stuck_t = 0.0
	else:
		_stuck_t += delta
		if _stuck_t >= GunData.STUCK_S:
			_release_slot()
			_enter(St.OPEN)


func _do_cover(delta: float) -> void:
	if slot >= 0:
		_turn_toward(-(fight.get("cover") as CoverMap).normal[slot], delta)
	_recheck -= delta
	if _recheck <= 0.0:
		_recheck = GunData.RECHECK_S
		if slot < 0 or not (fight.get("cover") as CoverMap).protects(slot, fight.call("player_feet")):
			_seek_cover(false)
			return
	_wait -= delta
	if _wait > 0.0:
		return
	if peeks >= peeks_max:
		peeks = 0
		peeks_max = _rng.randi_range(GunData.PEEKS_BEFORE_FLANK.x, GunData.PEEKS_BEFORE_FLANK.y)
		_seek_cover(true)
		return
	if not _line_from_standing():
		_no_line += 1
		_wait = 0.5
		if _no_line >= GunData.NO_LINE_TRIES:
			_no_line = 0
			peeks = 0
			_seek_cover(true)
		return
	if bool(fight.call("request_token", self)):
		has_token = true
		_enter(St.PEEK)
	else:
		_wait = 0.3


## Would the standing muzzle see the player now (one ray)? Checked before asking for a token.
func _line_from_standing() -> bool:
	return bool(fight.call("clear_line", muzzle_pos(), fight.call("player_target")))


func _do_peek(delta: float) -> void:
	var pp: Vector3 = fight.call("player_feet")
	_turn_toward(pp - feet(), delta)
	if st_t < GunData.AIM_S:
		return
	if telegraphing:
		tele_t += delta
		var k: float = 1.0 + 0.35 * sin(tele_t * 40.0)
		glint.scale = Vector3.ONE * k * lerpf(0.6, 1.3, clampf(tele_t / tele_len, 0.0, 1.0))
		glint.global_position = muzzle_pos()
		if tele_t >= tele_len - 1e-4:
			tele_before_shot.append(tele_t)
			if tele_before_shot.size() > LOG_MAX:
				tele_before_shot.pop_front()
			telegraphing = false
			glint.visible = false
			_fire()
			burst_left -= 1
			_gap = GunData.SHOT_GAP_S
			if burst_left <= 0:
				_end_peek()
		return
	if _gap > 0.0:
		_gap -= delta
		return
	_ray_t -= delta
	if _ray_t > 0.0:
		return
	_ray_t = GunData.RAY_DT
	if bool(fight.call("clear_line", muzzle_pos(), fight.call("player_target"))):
		telegraphing = true
		tele_t = 0.0
		tele_len = GunData.telegraph_s()
		tele_starts += 1
		glint.visible = true
		glint.global_position = muzzle_pos()
		fight.call("play_cue", "dry_click", muzzle_pos(), -6.0)
		telegraph_started.emit(self)
	elif st_t >= GunData.AIM_S + GunData.PEEK_ABORT_S:
		_end_peek()


func _end_peek() -> void:
	_cancel_shot()
	peeks += 1
	if slot >= 0 and (fight.get("cover") as CoverMap).protects(slot, fight.call("player_feet")):
		_enter(St.COVER)
	elif slot >= 0:
		_seek_cover(false)
	else:
		_enter(St.OPEN)


func _do_open(delta: float) -> void:
	var pp: Vector3 = fight.call("player_feet")
	var to: Vector3 = pp - feet()
	var d: float = Vector2(to.x, to.z).length()
	_open_look -= delta
	if _open_look <= 0.0:
		_open_look = 2.0
		if not shield_up and (fight.get("cover") as CoverMap).count() > 0 and _seek_cover(false, true):
			return
	_ray_t -= delta
	var keep: float = GunData.SHIELD_KEEP_M if shield_up else GunData.OPEN_KEEP_M
	if d > keep + 2.0 or (shield_up and d > keep):
		if _ray_t <= 0.0:
			_ray_t = GunData.RAY_DT
			_step_to = feet() + WeaponMath.flat_dir(to) * minf(2.0, d - keep)
			_step_ok = bool(fight.call("clear_walk", feet(), _step_to))
		if _step_ok:
			_step_toward(_step_to, delta, GunData.SHIELD_WALK if shield_up else GunData.WALK_SPEED * 1.6)
	else:
		_separate(delta)
	_turn_toward(to, delta)
	_wait -= delta
	if _wait <= 0.0:
		if not _line_from_standing():
			_wait = 0.5
		elif bool(fight.call("request_token", self)):
			has_token = true
			_enter(St.PEEK)
		else:
			_wait = 0.3


## Pick a cover slot (flank = round the player) and run there. quiet: called from OPEN, stays OPEN when nothing is found.
## Returns true when a slot was taken.
func _seek_cover(flank: bool, quiet: bool = false) -> bool:
	if shield_up:                            # the pallet is his cover: he walks in instead
		if not quiet:
			_release_slot()
			_enter(St.OPEN)
		return false
	var cover: CoverMap = fight.get("cover")
	var taken: Dictionary = fight.get("taken")
	var threat: Vector3 = fight.call("player_feet")
	var ids: PackedInt32Array
	if cover == null or cover.count() == 0:
		ids = PackedInt32Array()
	elif flank:
		ids = cover.flank_candidates(threat, feet(), GunData.FLANK_MAX_M, taken, self, GunData.FLANK_MIN_DEG, GunData.GUNMAN_COVER_MAX_H)
	else:
		ids = cover.candidates(threat, feet(), GunData.COVER_SEARCH_M, taken, self, GunData.COVER_MIN_PLAYER_M, GunData.GUNMAN_COVER_MAX_H)
	var tries: int = 0
	for id: int in ids:
		if tries >= 4:
			break
		tries += 1
		if id == slot and not flank:
			_enter(St.COVER)
			return true
		var route: PackedVector3Array = _plan_route(cover.pos[id])
		if not route.is_empty():
			_release_slot()
			slot = id
			taken[id] = self
			_path = route
			_path_i = 0
			_stuck_t = 0.0
			_last_pos = global_position
			_enter(St.FLANK if flank else St.TO_COVER)
			return true
	if quiet:
		return false
	if flank and slot >= 0:
		_enter(St.COVER)                     # no flank spot: keep this cover
	else:
		_release_slot()
		_enter(St.OPEN)
	return false


## A walkable route to target: the straight line when clear, else the nav graph's route with every leg walkable; empty =
## unreachable (never a blocked straight line).
func _plan_route(target: Vector3) -> PackedVector3Array:
	var t := Vector3(target.x, floor_y, target.z)
	if bool(fight.call("clear_walk", feet(), t)):
		return PackedVector3Array([t])
	var nav: HorrorNavGraph = fight.get("nav")
	if nav == null or nav.size() == 0 or not is_inside_tree():
		return PackedVector3Array()
	var r: PackedVector3Array = nav.route(feet(), t, get_world_3d().direct_space_state)
	var prev: Vector3 = feet()
	for i: int in r.size():
		var q := Vector3(r[i].x, floor_y, r[i].z)
		if not bool(fight.call("clear_walk", prev, q)):
			return PackedVector3Array()
		r[i] = q
		prev = q
	return r


func _release_slot() -> void:
	if slot >= 0:
		var taken: Dictionary = fight.get("taken")
		if taken.get(slot) == self:
			taken.erase(slot)
	slot = -1


## After a stagger: back into the cover when it still protects, else find another.
func _after_hit() -> void:
	if slot >= 0 and (fight.get("cover") as CoverMap).protects(slot, fight.call("player_feet")):
		_enter(St.COVER)
	else:
		_seek_cover(false)


# ---------------------------------------------------------------------------
# SHOOTING
# ---------------------------------------------------------------------------
func _fire() -> void:
	var muzzle: Vector3 = muzzle_pos()
	var tp: Vector3 = fight.call("player_target")
	var fx: WeaponFX = fight.get("fx")
	shots += 1
	var d0: Vector3 = (tp - muzzle).normalized()
	if fx:
		fx.muzzle(muzzle, d0, 0.8)
	fight.call("play_cue", "shot_pistol", muzzle, -3.0)
	var block: Dictionary = fight.call("ray", muzzle, tp)
	var result: String
	if not block.is_empty():
		var at: Vector3 = block["position"]
		GunData.tracer(fx, muzzle, at)
		if fx:
			fx.impact(at, block["normal"], false)
		result = "blocked"
	else:
		var p: float = accuracy_override if accuracy_override >= 0.0 else GunData.hit_chance(muzzle.distance_to(tp),
			float(fight.call("player_speed")), bool(fight.call("player_popped")), first_shot, accuracy_k * GunData.accuracy_k())
		if _rng.randf() < p:
			GunData.tracer(fx, muzzle, tp)
			fight.call("hit_player", self, GunData.gunman_dmg())
			hits += 1
			result = "hit"
		else:
			var side: Vector3 = d0.cross(Vector3.UP)
			side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
			var off: Vector3 = side * _rng.randf_range(GunData.MISS_OFFSET.x, GunData.MISS_OFFSET.y) * (1.0 if _rng.randf() < 0.5 else -1.0)
			off.y = _rng.randf_range(-0.3, 0.6)
			var end: Vector3 = muzzle + ((tp + off) - muzzle).normalized() * GunData.SHOT_RANGE
			var h: Dictionary = fight.call("ray", muzzle, end)
			var stop: Vector3 = end if h.is_empty() else h["position"]
			GunData.tracer(fx, muzzle, stop)
			if fx and not h.is_empty():
				fx.impact(stop, h["normal"], false)
			fight.call("play_cue", "ricochet", tp + off * 0.5, -8.0)
			result = "miss"
	first_shot = false
	shot.emit(self, result)


func _cancel_shot() -> void:
	telegraphing = false
	glint.visible = false
	if has_token:
		has_token = false
		if fight:
			fight.call("release_token", self)


# ---------------------------------------------------------------------------
# HITS
# ---------------------------------------------------------------------------
## Phase W duck-typed target: "bullet" / "pellet" / melee kinds hurt (GUNMAN_DMG_TAKEN), "scare" (gunfire nearby) and the
## funny weapons only alert. Returns "knocked_out", "stumble" or "none".
func take_hit(info: Dictionary) -> String:
	if st == St.KO:
		return "none"
	var hit_kind: String = String(info.get("kind", "melee"))
	var from: Vector3 = info.get("from", feet())
	if not GunData.GUNMAN_DMG_TAKEN.has(hit_kind):
		hear(from)
		return "none"
	if shield_up and hit_kind != "blast" and front_hit(from):
		return _pallet_hit(hit_kind, from)
	hp -= float(GunData.GUNMAN_DMG_TAKEN[hit_kind])
	_jolt(from)
	if not is_alerted and st != St.HOLD:
		alert(from)
	if hp <= 0.0:
		_knock_out(from)
		return "knocked_out"
	if st != St.HOLD and st != St.IDLE:
		_cancel_shot()
		_enter(St.STAGGER)
	else:
		CharacterBuilder.play(body, "flinch", GunData.STAGGER_S)
	return "stumble"


## The one place a knockout is finalised: the Q3 rim leaves the body here, before the mask flies off (a retry spawns fresh,
## rimmed gunmen).
func _knock_out(from: Vector3) -> void:
	_cancel_shot()
	_release_slot()
	if shield_up:
		_release_pallet(from, 1.5)
	hp = 0.0
	_enter(St.KO)
	pose.reset()
	var away: Vector3 = WeaponMath.flat_dir(feet() - from)
	yaw = atan2(away.x, away.z)              # faces the shot, falls on its back away from it
	body.rotation.y = yaw
	CharacterBuilder.play(body, "knockdown")
	shout.visible = false
	jolt_t = 0.0
	body.rotation = Vector3(0.0, yaw, 0.0)
	Readability.unrim(body)                  # before _fling_hat detaches the mask from the head (it would keep its rim)
	_fling_hat(away)
	_apply_drop()
	if fight:
		fight.call("play_cue", "body_fall", feet(), -2.0)
	ko.emit(self)


# ---------------------------------------------------------------------------
# WAVE 3: THE PALLET SHIELD
# ---------------------------------------------------------------------------
## A hit from `from` lands on the pallet's side: within SHIELD_FRONT_DEG of his front.
func front_hit(from: Vector3) -> bool:
	var to: Vector3 = WeaponMath.flat_dir(from - feet())
	if to.length_squared() < 0.01:
		return true
	return forward().angle_to(to) <= deg_to_rad(GunData.SHIELD_FRONT_DEG)


## The pallet stops a hit: chips, a thunk, "Không xuyên!" once; a close shotgun hit or the last allowed hit knocks it away.
func _pallet_hit(hit_kind: String, from: Vector3) -> String:
	blocked_hits += 1
	if not is_alerted and st != St.HOLD:
		alert(from)
	var at: Vector3 = shield.global_position + shield.global_basis.y * 0.7
	var d: Vector3 = WeaponMath.flat_dir(at - from)
	Impact.particles(self, "debris", at, -d, 0.6, fight.get("fx") if fight else null)
	Impact.sound(self, "thud", at, -2.0)
	if not _said_no_pierce:
		_said_no_pierce = true
		shout.text = GunData.T_NO_PIERCE
		shout.visible = true
		_shout_left = SHOUT_S
	var knock: bool = hit_kind == "pellet" and WeaponMath.flat(from, feet()) < GunData.SHIELD_SHOTGUN_M
	if not knock:
		shield_hits += 1
		knock = shield_hits >= GunData.shield_hits()
	if not knock:
		return "none"
	_release_pallet(from, 3.5)
	Impact.hit(self, "heavy", {"pos": at, "dir": d, "fx": fight.get("fx") if fight else null})
	_jolt(from)
	if st != St.HOLD and st != St.IDLE:
		_cancel_shot()
		_enter(St.STAGGER)
	else:
		CharacterBuilder.play(body, "flinch", GunData.STAGGER_S)
	shield_dropped.emit(self)
	return "stumble"


## The pallet leaves his hands: it flies away from `from` (push m/s), bounces once and lies on the floor.
func _release_pallet(from: Vector3, push: float) -> void:
	shield_up = false
	if shield == null or not is_instance_valid(shield):
		return
	var g: Transform3D = shield.global_transform
	shield.get_parent().remove_child(shield)
	add_child(shield)
	shield.top_level = true
	shield.global_transform = g
	Readability.unrim(shield)
	var away: Vector3 = WeaponMath.flat_dir(shield.global_position - from)
	if away.length_squared() < 0.01:
		away = forward()
	_pallet_v = away * push + Vector3(0.0, 2.6, 0.0)
	_pallet_spin = Vector3(_rng.randf_range(-5.0, -3.0), _rng.randf_range(-2.0, 2.0), _rng.randf_range(-3.0, 3.0))
	_pallet_bounced = false
	_pallet_fly = true


func _tick_pallet(delta: float) -> void:
	if shield == null or not is_instance_valid(shield):
		_pallet_fly = false
		return
	_pallet_v.y -= 18.0 * delta
	var p: Vector3 = shield.global_position + _pallet_v * delta
	if p.y < floor_y + 0.05 and _pallet_v.y < 0.0:
		p.y = floor_y + 0.05
		if not _pallet_bounced:
			_pallet_bounced = true
			_pallet_v = Vector3(_pallet_v.x * 0.4, -_pallet_v.y * 0.25, _pallet_v.z * 0.4)
			_pallet_spin *= 0.3
		else:
			_pallet_fly = false              # lies flat on the floor from here on
			shield.global_position = p
			shield.global_rotation = Vector3(-PI * 0.5, shield.global_rotation.y, 0.0)
			return
	shield.global_position = p
	shield.rotation += _pallet_spin * delta


func has_shield() -> bool:
	return shield_up


# ---------------------------------------------------------------------------
# Q2: HIT JOLT, FLYING MASK
# ---------------------------------------------------------------------------
## A quick lean away from the shot (body frame), settling in JOLT_S.
func _jolt(from: Vector3) -> void:
	_jolt_dir = WeaponMath.flat_dir(feet() - from)
	if _jolt_dir.length_squared() < 0.01:
		_jolt_dir = -forward()
	jolt_t = JOLT_S
	jolts += 1


func _tick_jolt(delta: float) -> void:
	jolt_t = maxf(0.0, jolt_t - delta)
	var u: float = 1.0 - jolt_t / JOLT_S
	var k: float = (u / 0.2 if u < 0.2 else 1.0 - (u - 0.2) / 0.8) * JOLT_LEAN
	var loc: Vector3 = Basis(Vector3.UP, yaw).inverse() * _jolt_dir    # the push in the body frame (facing -Z)
	body.rotation = Vector3(loc.z * k, yaw, -loc.x * k)                 # +x tips the top back (+Z), +z tips it left (-X)


## The knockout knocks the mask (or a cap) off: it flies up and away from the shot, spinning, bounces once, then lies.
## Readability.unrim(body) has run before this (_knock_out): the mask leaves the body here without a rim overlay.
func _fling_hat(away: Vector3) -> void:
	var at: Vector3 = body.global_position + Vector3(0.0, 1.6, 0.0)
	var m: Node3D = body.find_child("*Mask", true, false) as Node3D
	if m != null:
		at = m.global_position
		var g: Transform3D = m.global_transform
		m.get_parent().remove_child(m)
		add_child(m)
		m.top_level = true
		m.global_transform = g
		flying_hat = m
	else:
		var cap := Node3D.new()
		cap.name = "FlyingCap"
		CineFX._sphere(cap, "Cap", 0.12, Vector3.ZERO, CineFX._mat(Color("#1C1C20"), 0.8), Vector3(1.0, 0.6, 1.0))
		CineFX._box(cap, "Brim", Vector3(0.16, 0.015, 0.1), Vector3(0.0, -0.02, -0.12), CineFX._mat(Color("#1C1C20"), 0.8))
		add_child(cap)
		cap.top_level = true
		cap.global_position = at
		flying_hat = cap
	_hat_v = away * 2.6 + Vector3(0.0, 4.4, 0.0)
	_hat_spin = Vector3(_rng.randf_range(7.0, 11.0), _rng.randf_range(-5.0, 5.0), _rng.randf_range(-8.0, 8.0))
	_hat_bounced = false
	_hat_rest = false


func _tick_hat(delta: float) -> void:
	if not is_instance_valid(flying_hat):
		flying_hat = null
		return
	_hat_v.y -= 18.0 * delta
	var p: Vector3 = flying_hat.global_position + _hat_v * delta
	var fl: float = floor_y + 0.06
	if p.y < fl and _hat_v.y < 0.0:
		p.y = fl
		if not _hat_bounced:
			_hat_bounced = true
			_hat_v = Vector3(_hat_v.x * 0.5, -_hat_v.y * 0.3, _hat_v.z * 0.5)
			_hat_spin *= 0.4
		else:
			_hat_rest = true                 # lies on the floor from here on
	flying_hat.global_position = p
	if not _hat_rest:
		flying_hat.rotation += _hat_spin * delta


## The fight was lost: stop shooting and stand down.
func stand_down() -> void:
	if st == St.KO:
		return
	_cancel_shot()
	_enter(St.IDLE)


# ---------------------------------------------------------------------------
# MOVEMENT
# ---------------------------------------------------------------------------
## Walk to target along _plan_route; false (and no path) when it cannot be reached.
func _go(target: Vector3) -> bool:
	_path = _plan_route(target)
	_path_i = 0
	return not _path.is_empty()


## One step along the path; true when the end is reached.
func _move(delta: float, speed: float) -> bool:
	var budget: float = speed * delta
	while budget > 0.0 and _path_i < _path.size():
		var tgt: Vector3 = _path[_path_i]
		var d := Vector3(tgt.x - global_position.x, 0.0, tgt.z - global_position.z)
		var dist: float = d.length()
		if dist < 0.05:
			_path_i += 1
			continue
		var stp: float = minf(budget, dist)
		global_position += d / dist * stp
		budget -= stp
		_turn_toward(d, delta)
		speed_now = speed
		if stp >= dist - 0.0001:
			_path_i += 1
	_follow_floor(delta)
	return _path_i >= _path.size()


func _step_toward(p: Vector3, delta: float, speed: float) -> void:
	var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	var dist: float = d.length()
	if dist < 0.05:
		return
	global_position += d / dist * minf(dist, speed * delta)
	speed_now = speed
	_follow_floor(delta)


## While walking: the floor height under the feet from a down-ray at 10 Hz (ramps, stairs; GunFight.ray ignores the
## player). A gap keeps the last floor.
func _follow_floor(delta: float) -> void:
	_floor_t -= delta
	if _floor_t > 0.0 or fight == null:
		return
	_floor_t = GunData.RAY_DT
	var f: Vector3 = feet()
	var h: Dictionary = fight.call("ray", f + Vector3(0.0, GunData.FLOOR_PROBE_UP, 0.0), f - Vector3(0.0, GunData.FLOOR_PROBE_DOWN, 0.0))
	if not h.is_empty() and (h["normal"] as Vector3).y > 0.6:
		floor_y = (h["position"] as Vector3).y


## Standing in the open: step away from gunmen closer than SEPARATION_M (the push is worked out at 10 Hz, only along a
## walkable line).
func _separate(delta: float) -> void:
	_sep_t -= delta
	if _sep_t <= 0.0:
		_sep_t = GunData.RAY_DT
		var push := Vector3.ZERO
		var me: Vector3 = feet()
		for o: Variant in fight.get("gunmen"):
			if o == self or not is_instance_valid(o) or (o as Gunman).is_down():
				continue
			var dv: Vector3 = me - (o as Gunman).feet()
			dv.y = 0.0
			var l: float = dv.length()
			if l < GunData.SEPARATION_M:
				var away: Vector3 = dv / l if l > 0.01 else Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, float(get_instance_id() % 628) * 0.01)
				push += away * (GunData.SEPARATION_M - l)
		_sep_v = Vector3.ZERO
		if push.length_squared() > 1e-4:
			var dir: Vector3 = push.normalized()
			if bool(fight.call("clear_walk", me, me + dir * 0.6)):
				_sep_v = dir * minf(1.5, push.length() * 4.0)
	if _sep_v.length_squared() > 0.0:
		global_position += _sep_v * delta


func _turn_toward(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 1e-6:
		return
	var want: float = atan2(-dir.x, -dir.z)
	var rate: float = GunData.SHIELD_TURN_RATE if shield_up else GunData.TURN_RATE
	yaw += clampf(wrapf(want - yaw, -PI, PI), -rate * delta, rate * delta)
	body.rotation.y = yaw


## The pistol in the right hand, barrel along the body's facing (WeaponDirector._update_held_pose without the pitch).
func _update_gun() -> void:
	if gun == null or _gun_att == null or _sk == null:
		return
	var hand: Transform3D = _sk.global_transform * CharacterBuilder._bone_global_now(_sk, _wrist)
	var bs: Basis = body.global_basis.orthonormalized()
	gun.transform = hand.affine_inverse() * Transform3D(bs, hand.origin)
