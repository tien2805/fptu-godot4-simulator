# File: res://scripts/combat/bike/PlayerBikeCombat.gd
# The player's side of the Phase C bike combat (spec C-D1) on one PlayerBike, owned by a BikeChase:
#   - kicks: Q left, E right (key events, consumed only while `enabled` and riding; kick(side) for scripts / tests).
#     Wind-up KICK_WINDUP, hit window up to KICK_ACTIVE_END, leg back at KICK_DUR, cooldown KICK_COOLDOWN from the press.
#     During the window the closest kickable target on that side (0.3-2.4 m to the side, +/-1.7 m along, in the bike's own
#     frame) takes the kick (one target per kick); no target by the end of the window = a miss.
#   - stability (the bike's HP, 100): damage(amount, cause, from_side) from an enemy kick (+ a sideways shove), a crash
#     (PlayerBike.crash_occurred: traffic, curb, pothole, fall), a ram; HURT_IFRAMES after a hit; REGEN_RATE per second
#     after REGEN_DELAY without damage. At 0 the player is knocked off: the bike locks (PlayerBike.is_controls_locked, the
#     previous value restored by reset()), lies on its side, daze stars; `knocked_off` is emitted.
#   - the kick leg as a bone pose over the rider (process priority 11, after its RigAnimator), a lean on a non-rigged one.
# Refusals: kick() while not riding / not enabled / knocked off counts in `refusals` and does nothing.
# Spin kick (spec D2X-9, plan 2026-10-27-d2x-drift.md): Q / E while the bike drifts. The rider turns a full circle on the
# seat with the leg out (Q counter-clockwise, E clockwise) for SPIN_DUR; at SPIN_HIT_AT every kickable target within
# SPIN_REACH to either side (+/-SPIN_ALONG along the bike), the SPIN_MAX nearest, takes the kick through the normal path
# (take_kick + kick_hit.emit(target, 0); kicked.emit(0) at the start; side 0 = a spin), then a SPIN_HITSTOP hit-stop and
# a SPIN_COOLDOWN cooldown that blocks side kicks too. A spin that hits nothing emits kick_missed(0). Look: an arc ribbon
# around the rider, a dust ring under the bike, two swishes, sparks on each hit, camera shake.
# Q2 feel (plan 2026-10-29-q2-feel.md T3):
#   - a kick that connects is a heavy Impact (80 ms freeze, camera whip / punch toward the target through the camera
#     director, else the bike's own shake) and rocks the player's bike KICKBACK_ROLL away from it (visual, the line is kept;
#     -1.5 % speed); the target wobbles and crashes (BikerEnemy);
#   - counter-kick "PHẢN ĐÒN!": a kick toward an attacker whose hit is at most COUNTER_WINDOW away (BikerEnemy.time_to_hit)
#     sends him flying at once (crash cause "counter", a takedown), a finisher Impact and a short slow motion; `countered`;
#   - grab weapon: drop_stick(pos, vel) (a kicked stick rider): the stick flies in an arc into the rider's hands (caught
#     within STICK_CATCH_LAT / STICK_CATCH_ALONG of its landing spot; else it lies on the road for STICK_LIFE, riding over
#     it picks it up) (`stick_picked`): STICK_SWINGS swings on Q / E with STICK_REACH_BONUS more reach and STICK_POWER damage,
#     then it breaks (`stick_broke`);
#   - the spin kick leaves a fading motion-trail arc behind the leg; one hit is heavy, two at once the finisher tier;
#   - a hit on the player: a red screen-edge flash, a camera jolt and a HURT_WOBBLE_S bike wobble.
class_name PlayerBikeCombat
extends Node

signal kicked(side: int)
signal kick_hit(target: Node3D, side: int)
signal kick_missed(side: int)
signal damaged(amount: float, cause: String)
signal knocked_off
signal countered(target: Node3D)
signal stick_picked
signal stick_broke

const SPIN_DUR: float = 0.5
const SPIN_HIT_AT: float = 0.18
const SPIN_REACH: float = 3.6
const SPIN_ALONG: float = 2.2
const SPIN_MAX: int = 2
const SPIN_HITSTOP: float = 0.15
const SPIN_COOLDOWN: float = 1.2
const SPIN_ARC_R: float = 1.15

var bike: PlayerBike
var roam: Node = null
## Kick targets: the chase's current bikers (shared Array, read every window frame).
var targets: Array = []
var enabled: bool = false
var god: bool = false
var stability: float = BikeCombatData.STABILITY_MAX
var max_stability: float = BikeCombatData.STABILITY_MAX
var kick_t: float = -1.0
var kick_side: int = 0
var kick_cd: float = 0.0
var kick_done: bool = false
var kicks: int = 0
var hits: int = 0
var misses: int = 0
var refusals: int = 0
## Last kick results ("hit" | "miss"; last 16).
var results: Array[String] = []
var knocked: bool = false
var hurt_t: float = 99.0
var iframes: float = 0.0
var ram_cd: float = 0.0
var fx: WeaponFX = null
var _shove: Vector3 = Vector3.ZERO
var _shove_t: float = 0.0
var _prev_locked: bool = false
var _locked: bool = false
var _sk: Skeleton3D = null
var _anim: Node = null
var _lay: Tween = null
var _anchor: Node3D = null
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
var _connected: bool = false
## Spin kick state (D2X-9).
var spin_t: float = -1.0
var spin_dir: float = 1.0
var spin_done: bool = false
var spins: int = 0
var spin_hits: int = 0
## The targets of the last spin's hit moment (tests).
var last_spin_targets: Array = []
var _arc: MeshInstance3D = null
var _arc_mat: StandardMaterial3D = null
var _dust: CPUParticles3D = null
## Q2: counters, the grabbed stick, the spin trail, the hurt wobble.
var counters: int = 0
var last_counter: Node3D = null
var stick_swings: int = 0
var stick_picks: int = 0
var stick_hits: int = 0
var drops: Array[Dictionary] = []        # {"node", "t"} sticks lying on the road
var kickbacks: int = 0
var wobble_t: float = 0.0
var _stick_node: Node3D = null
var _trail: MeshInstance3D = null
var _trail_mat: StandardMaterial3D = null
var _wob_ph: float = 0.0
var _kb_t: float = 0.0
var _kb_sign: float = 0.0
var counter_slowmos: int = 0
var _counter_slow_rt: float = -99.0      # Impact clock real time of the last counter slow motion


func setup(b: PlayerBike, opts: Dictionary = {}) -> void:
	bike = b
	roam = opts.get("roam", null)
	fx = opts.get("fx", null)
	if opts.has("targets"):
		targets = opts["targets"]
	max_stability = float(opts.get("max_stability", BikeCombatData.STABILITY_MAX))
	stability = max_stability
	if bike and bike.rider_node:
		_sk = bike.rider_node.get_meta("skeleton", null) as Skeleton3D
		_anim = CharacterBuilder.get_animator(bike.rider_node)
	if bike and not _connected:
		bike.crash_occurred.connect(_on_crash)
		_connected = true


func _ready() -> void:
	process_priority = 11
	process_physics_priority = 2
	Impact.prepare(self)
	for i: int in 3:
		var p := AudioStreamPlayer3D.new()
		p.name = "BikeSfx%d" % i
		p.bus = WeaponAudio.bus()
		p.max_distance = 80.0
		p.unit_size = 6.0
		add_child(p)
		_sfx.append(p)


## Riding right now: the bike is in the tree, shown and processing, and (with a roam) the roam says mounted.
func riding() -> bool:
	if bike == null or not is_instance_valid(bike) or not bike.is_inside_tree():
		return false
	if not bike.visible or bike.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if roam != null and is_instance_valid(roam) and not bool(roam.get("mounted")):
		return false
	return true


func can_kick() -> bool:
	return enabled and riding() and not knocked and not bike.is_controls_locked and kick_cd <= 0.0 \
		and not (is_inside_tree() and get_tree().paused)


## Kick to side -1 (left) or +1 (right). false (a refusal when not riding / not enabled / knocked off; just false in the
## cooldown) when it cannot.
func kick(side: int) -> bool:
	if not enabled or not riding() or knocked or bike.is_controls_locked or (is_inside_tree() and get_tree().paused):
		refusals += 1
		return false
	if kick_cd > 0.0 or spin_t >= 0.0:
		return false
	var ct: Node3D = counter_target(-1 if side < 0 else 1)
	if ct != null:
		return _counter(ct, -1 if side < 0 else 1)
	if bike.is_drifting and stick_swings <= 0:
		return spin_kick(side)
	kick_side = -1 if side < 0 else 1
	kick_t = 0.0
	kick_cd = BikeCombatData.KICK_COOLDOWN
	kick_done = false
	kicks += 1
	_cue("swish", bike.global_position + Vector3(0.0, 0.8, 0.0), -4.0 if stick_swings <= 0 else 0.0)
	kicked.emit(kick_side)
	return true


func kicking() -> bool:
	return kick_t >= 0.0


func spinning() -> bool:
	return spin_t >= 0.0


## The spin kick (Q / E while drifting; side -1 spins counter-clockwise, +1 clockwise). Same refusals as kick().
func spin_kick(side: int) -> bool:
	if not enabled or not riding() or knocked or bike.is_controls_locked or (is_inside_tree() and get_tree().paused):
		refusals += 1
		return false
	if kick_cd > 0.0 or spin_t >= 0.0:
		return false
	spin_dir = -1.0 if side < 0 else 1.0
	spin_t = 0.0
	spin_done = false
	kick_t = -1.0
	kick_cd = SPIN_COOLDOWN
	kicks += 1
	spins += 1
	last_spin_targets.clear()
	_cue("swish", bike.global_position + Vector3(0.0, 0.8, 0.0), -2.0)
	bike.add_camera_shake(0.2)
	_spin_fx_start()
	kicked.emit(0)
	return true


## The kickable targets a spin hits now: within SPIN_REACH to either side and SPIN_ALONG along the bike, nearest first,
## at most SPIN_MAX.
func spin_targets() -> Array:
	update_frame()
	var p := Vector2(bike.global_position.x, bike.global_position.z)
	var found: Array = []
	for t: Variant in targets:
		if not is_instance_valid(t) or not bool((t as Object).call("kickable")):
			continue
		var g: Vector3 = (t as Object).call("ground_pos")
		if absf(g.y - bike.global_position.y) > 2.5:
			continue
		var rel := Vector2(g.x, g.z) - p
		if absf(rel.dot(right2)) > SPIN_REACH or absf(rel.dot(fwd2)) > SPIN_ALONG:
			continue
		found.append([rel.length_squared(), t])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for e: Array in found:
		if out.size() >= SPIN_MAX:
			break
		out.append(e[1])
	return out


## Bike frame on the map plane (unit vectors, refreshed by update_frame(); no allocation).
var fwd2: Vector2 = Vector2(0.0, -1.0)
var right2: Vector2 = Vector2(1.0, 0.0)


func update_frame() -> void:
	var z: Vector3 = bike.global_transform.basis.z
	var f := Vector2(-z.x, -z.z)
	fwd2 = f.normalized() if f.length_squared() > 1e-6 else Vector2(0.0, -1.0)
	right2 = Vector2(-fwd2.y, fwd2.x)


## The kickable target the window would hit now on `side`, or null.
func kick_target(side: int) -> Node3D:
	update_frame()
	var p := Vector2(bike.global_position.x, bike.global_position.z)
	var best: Node3D = null
	var best_score: float = INF
	for t: Variant in targets:
		if not is_instance_valid(t) or not bool((t as Object).call("kickable")):
			continue
		var g: Vector3 = (t as Object).call("ground_pos")
		if absf(g.y - bike.global_position.y) > 2.5:
			continue
		var rel := Vector2(g.x, g.z) - p
		var lat: float = rel.dot(right2) * float(side)
		var along: float = rel.dot(fwd2)
		var reach: float = BikeCombatData.KICK_REACH + (BikeCombatData.STICK_REACH_BONUS if stick_swings > 0 else 0.0)
		var reach_a: float = BikeCombatData.KICK_ALONG + (BikeCombatData.STICK_ALONG_BONUS if stick_swings > 0 else 0.0)
		if lat < BikeCombatData.KICK_MIN or lat > reach or absf(along) > reach_a:
			continue
		var score: float = absf(lat - 1.4) + absf(along) * 0.5
		if score < best_score:
			best_score = score
			best = t
	return best


## Stability damage (from_side: +1 from the right, -1 from the left, 0 none). false when ignored (god, i-frames, off).
func damage(amount: float, cause: String, from_side: int = 0) -> bool:
	if not enabled or knocked or god or iframes > 0.0:
		return false
	stability = maxf(0.0, stability - amount)
	iframes = BikeCombatData.HURT_IFRAMES
	hurt_t = 0.0
	if bike:
		bike.add_camera_shake(0.55)
		# Q2: the red screen edge, a camera jolt from the hit's side, the bike wobbles
		update_frame()
		var hd: Vector3 = Vector3(right2.x, 0.0, right2.y) * -float(from_side) if from_side != 0 else Vector3(-fwd2.x, 0.0, -fwd2.y)
		Impact.punch(self, 0.45, hd, _no_shake)   # no director: the bike's own shake above already jolts
		Impact.edge_flash(self, Impact.EDGE_RED, 0.7 if cause != "crash" else 0.5)
		wobble_t = BikeCombatData.HURT_WOBBLE_S
		if cause == "kick":
			bike.current_speed_ms *= 0.85
		if from_side != 0:
			update_frame()
			var r: Vector2 = right2 * -float(from_side)
			_shove = Vector3(r.x, 0.0, r.y) * (BikeCombatData.SHOVE_M / BikeCombatData.SHOVE_S)
			_shove_t = BikeCombatData.SHOVE_S
		_cue("impact_heavy", bike.global_position + Vector3(0.0, 0.9, 0.0), -2.0)
	damaged.emit(amount, cause)
	if stability <= 0.0:
		knock_off()
	return true


func _on_crash() -> void:
	if enabled:
		damage(BikeCombatData.CRASH_DMG, "crash")


## Stability 0: the bike locks and lies on its side with the rider, daze stars.
func knock_off() -> void:
	if knocked:
		return
	knocked = true
	kick_t = -1.0
	_lock(true)
	if bike:
		bike.current_speed_ms *= 0.5
		if _lay and _lay.is_valid():
			_lay.kill()
		_lay = create_tween()
		_lay.tween_property(bike.visual_pivot, "rotation:z", 1.35, 0.35)
		_cue("bin_crash", bike.global_position, -2.0)
		_cue("groan", bike.global_position + Vector3(0.0, 0.5, 0.0), -3.0)
		if fx:
			_anchor = Node3D.new()
			_anchor.name = "KnockedStars"
			_anchor.top_level = true
			add_child(_anchor)
			update_frame()
			var r: Vector2 = right2
			_anchor.global_position = bike.global_position + Vector3(-r.x * 0.7, -1.5, -r.y * 0.7)
			fx.stars(_anchor, 6.0)
	knocked_off.emit()


## Full stability, upright and unlocked bike, no kick in progress (retry / stop).
func reset() -> void:
	stability = max_stability
	knocked = false
	kick_t = -1.0
	spin_t = -1.0
	wobble_t = 0.0
	_kb_t = 0.0
	_set_stick(0)
	clear_drops()
	if _arc:
		_arc.visible = false
	if _trail:
		_trail.visible = false
	if bike and is_instance_valid(bike) and bike.rider_node:
		bike.rider_node.rotation.y = 0.0
	kick_cd = 0.0
	kick_done = false
	iframes = 0.0
	ram_cd = 0.0
	hurt_t = 99.0
	_shove_t = 0.0
	if _lay and _lay.is_valid():
		_lay.kill()
	_lay = null
	if bike and is_instance_valid(bike):
		bike.visual_pivot.rotation.z = 0.0
		if bike.rider_node and not _sk:
			bike.rider_node.rotation.z = 0.0
	if _anchor and is_instance_valid(_anchor):
		_anchor.queue_free()
	_anchor = null
	_lock(false)


func _lock(on: bool) -> void:
	if bike == null or not is_instance_valid(bike):
		_locked = false
		return
	if on and not _locked:
		_prev_locked = bike.is_controls_locked
		bike.is_controls_locked = true
		_locked = true
	elif not on and _locked:
		bike.is_controls_locked = _prev_locked
		_locked = false


func _physics_process(delta: float) -> void:
	if kick_cd > 0.0:
		kick_cd -= delta
	if spin_t >= 0.0:
		_tick_spin(delta)
	iframes -= delta
	ram_cd -= delta
	hurt_t += delta
	if kick_t >= 0.0:
		kick_t += delta
		if not kick_done and kick_t >= BikeCombatData.KICK_WINDUP:
			var t: Node3D = kick_target(kick_side) if kick_t <= BikeCombatData.KICK_ACTIVE_END and not knocked else null
			if t != null:
				kick_done = true
				hits += 1
				_log("hit")
				var away := Vector2(t.global_position.x - bike.global_position.x, t.global_position.z - bike.global_position.z)
				away = away.normalized() if away.length_squared() > 1e-4 else right2 * float(kick_side)
				var stick: bool = stick_swings > 0
				if stick:
					stick_hits += 1
					(t as Object).call("take_kick", away, BikeCombatData.STICK_POWER)
				else:
					(t as Object).call("take_kick", away)
				_connect_feel(t, away, "heavy", 1.25 if stick else 1.0, [["stick_crack", -6.0]] if stick else [])
				kick_hit.emit(t, kick_side)
			elif kick_t > BikeCombatData.KICK_ACTIVE_END:
				kick_done = true
				misses += 1
				_log("miss")
				kick_missed.emit(kick_side)
		if kick_t >= BikeCombatData.KICK_DUR:
			kick_t = -1.0
			if stick_swings > 0:
				_use_stick()
	if enabled and not knocked and hurt_t >= BikeCombatData.REGEN_DELAY and stability < max_stability:
		stability = minf(max_stability, stability + BikeCombatData.REGEN_RATE * delta)
	if _shove_t > 0.0 and bike and is_instance_valid(bike):
		_shove_t -= delta
		bike.move_and_collide(_shove * delta)
	if not drops.is_empty():
		_tick_drops(delta)
	if wobble_t > 0.0 and bike and is_instance_valid(bike) and not knocked:
		wobble_t = maxf(0.0, wobble_t - delta)
		_wob_ph += delta
		var k: float = wobble_t / BikeCombatData.HURT_WOBBLE_S
		bike.visual_pivot.rotation.z += sin(_wob_ph * 30.0) * 0.16 * k   # after the bike wrote its lean this frame
	if _kb_t > 0.0 and bike and is_instance_valid(bike) and not knocked:
		_kb_t = maxf(0.0, _kb_t - delta)
		bike.visual_pivot.rotation.z += _kb_sign * BikeCombatData.KICKBACK_ROLL * sin(PI * (1.0 - _kb_t / BikeCombatData.KICKBACK_S))


func _tick_spin(delta: float) -> void:
	spin_t += delta
	if not spin_done and spin_t >= SPIN_HIT_AT:
		spin_done = true
		if not knocked:
			_spin_hit()
	if spin_t >= SPIN_DUR:
		spin_t = -1.0
		if bike and is_instance_valid(bike) and bike.rider_node:
			bike.rider_node.rotation.y = 0.0
		if _arc:
			_arc.visible = false
		if _trail:
			_trail.visible = false


## The spin's hit moment: every target spin_targets() returns takes the kick (normal path, side 0).
func _spin_hit() -> void:
	last_spin_targets = spin_targets()
	var tier: String = "finisher" if last_spin_targets.size() >= 2 else "heavy"   # Q2: a double spin hit is the big one
	for t: Variant in last_spin_targets:
		var n3: Node3D = t as Node3D
		hits += 1
		spin_hits += 1
		_log("hit")
		var away := Vector2(n3.global_position.x - bike.global_position.x, n3.global_position.z - bike.global_position.z)
		away = away.normalized() if away.length_squared() > 1e-4 else right2
		(t as Object).call("take_kick", away)
		if fx:
			fx.burst("sparks", n3.global_position + Vector3(0.0, 0.9, 0.0), Vector3(away.x, 0.4, away.y), 0.8)
		_connect_feel(n3, away, tier, 1.2, [], false)
		kick_hit.emit(n3, 0)
	if last_spin_targets.is_empty():
		misses += 1
		_log("miss")
		kick_missed.emit(0)
	else:
		bike.add_camera_shake(0.45)
		_cue("impact_heavy", bike.global_position + Vector3(0.0, 0.9, 0.0), -1.0)   # the freeze: _connect_feel (Impact clock)
	_cue("swish", bike.global_position + Vector3(0.0, 0.8, 0.0), -3.0)


## The arc ribbon (a flat glowing ring around the rider) and the dust ring under the bike, built once.
func _spin_fx_start() -> void:
	if bike == null or bike.visual_pivot == null:
		return
	if _arc == null:
		_arc = MeshInstance3D.new()
		_arc.name = "SpinArc"
		var tm := TorusMesh.new()
		tm.inner_radius = SPIN_ARC_R - 0.07
		tm.outer_radius = SPIN_ARC_R + 0.07
		tm.rings = 24
		tm.ring_segments = 4
		_arc_mat = StandardMaterial3D.new()
		_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_arc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_arc_mat.albedo_color = Color(0.75, 0.9, 1.0, 0.8)
		_arc_mat.set_meta("vice_done", true)
		tm.material = _arc_mat
		_arc.mesh = tm
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc.scale = Vector3(1.0, 0.25, 1.0)
		_arc.position = Vector3(0.0, 0.62, 0.1)
		bike.visual_pivot.add_child(_arc)
		_dust = CPUParticles3D.new()
		_dust.name = "SpinDust"
		_dust.emitting = false
		_dust.one_shot = true
		_dust.explosiveness = 0.9
		_dust.amount = 22
		_dust.lifetime = 0.6
		_dust.local_coords = false
		_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_dust.emission_ring_axis = Vector3.UP
		_dust.emission_ring_radius = 0.9
		_dust.emission_ring_inner_radius = 0.6
		_dust.emission_ring_height = 0.05
		_dust.direction = Vector3(0.0, 0.3, 0.0)
		_dust.spread = 180.0
		_dust.initial_velocity_min = 2.0
		_dust.initial_velocity_max = 3.5
		_dust.gravity = Vector3(0.0, -1.5, 0.0)
		_dust.scale_amount_min = 0.5
		_dust.scale_amount_max = 1.1
		_dust.color = Color(0.82, 0.8, 0.76, 0.6)
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 6
		sm.rings = 3
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.vertex_color_use_as_albedo = true
		dm.set_meta("vice_done", true)
		sm.material = dm
		_dust.mesh = sm
		_dust.position = Vector3(0.0, 0.1, 0.0)
		bike.visual_pivot.add_child(_dust)
	_arc.visible = true
	_dust.restart()
	_dust.emitting = true
	_trail_start()


# ---------------------------------------------------------------------------
# Q2 FEEL: connecting hits, counter-kick, the grabbed stick, the spin trail
# ---------------------------------------------------------------------------
## A connecting kick / swing / spin hit: the Impact tier (freeze, camera punch toward the target, particles, layers) and,
## for side kicks, a small shove of the player's bike the other way.
func _connect_feel(t: Node3D, away: Vector2, tier: String, punch_k: float = 1.0, cues: Array = [], kickback: bool = true) -> void:
	var at: Vector3 = t.global_position + Vector3(0.0, 1.0, 0.0)
	var d3 := Vector3(away.x, 0.0, away.y)
	var shake: Callable = bike.add_camera_shake if bike and is_instance_valid(bike) else Callable()
	Impact.hit(self, tier, {"pos": at, "dir": d3, "fx": fx, "shake_fn": shake, "punch_k": punch_k, "cues": cues})
	if kickback and bike and is_instance_valid(bike):
		kickbacks += 1                       # the recoil: the bike rocks away from the kick (visual) and loses a little speed
		update_frame()
		_kb_sign = signf(Vector2(away.x, away.y).dot(right2))   # +z rolls the bike left: a right kick rocks it left
		_kb_t = BikeCombatData.KICKBACK_S
		bike.current_speed_ms *= 0.985


## The attacker a kick toward `side` would counter now: a kickable biker on that side within COUNTER_LAT / COUNTER_ALONG
## whose hit lands within COUNTER_WINDOW (BikerEnemy.time_to_hit), the soonest first; null = none.
func counter_target(side: int) -> Node3D:
	if bike == null or not is_instance_valid(bike):
		return null
	update_frame()
	var p := Vector2(bike.global_position.x, bike.global_position.z)
	var best: Node3D = null
	var best_t: float = BikeCombatData.COUNTER_WINDOW + 1e-4
	for t: Variant in targets:
		if not is_instance_valid(t) or not (t as Object).has_method("time_to_hit") or not bool((t as Object).call("kickable")):
			continue
		var tt: float = float((t as Object).call("time_to_hit"))
		if tt > best_t or tt < 0.0:
			continue
		var g: Vector3 = (t as Object).call("ground_pos")
		var rel := Vector2(g.x, g.z) - p
		var lat: float = rel.dot(right2) * float(side)
		if lat < 0.1 or lat > BikeCombatData.COUNTER_LAT or absf(rel.dot(fwd2)) > BikeCombatData.COUNTER_ALONG:
			continue
		best_t = tt
		best = t
	return best


## PHẢN ĐÒN: the attacker is sent flying before his hit lands (a takedown); the kick leg plays, a finisher Impact, a short
## slow motion (BikeChase's takedown slow motion takes over when it may), i-frames over his swing.
func _counter(t: Node3D, side: int) -> bool:
	kick_side = side
	kick_t = 0.0
	kick_done = true
	kick_cd = BikeCombatData.KICK_COOLDOWN
	kicks += 1
	hits += 1
	counters += 1
	last_counter = t
	_log("counter")
	iframes = maxf(iframes, 0.3)
	update_frame()
	var away := Vector2(t.global_position.x - bike.global_position.x, t.global_position.z - bike.global_position.z)
	away = away.normalized() if away.length_squared() > 1e-4 else right2 * float(side)
	_cue("swish", bike.global_position + Vector3(0.0, 0.8, 0.0), -2.0)
	kicked.emit(side)
	var downs: bool = int(t.get("hp")) <= 2 if t.get("hp") != null else true   # a counter is worth 2 kicks (a heavy survives)
	_connect_feel(t, away, "finisher" if downs else "heavy", 1.3, [["keng", -4.0]])
	var c: Impact = Impact.clock(self)
	if c != null and downs and c.rt - _counter_slow_rt >= BikeCombatData.TD_GAP_S:   # rate-limited like takedowns
		if c.slowmo(0.35, 0.35, self):
			_counter_slow_rt = c.rt
			counter_slowmos += 1
	if t.has_method("take_counter"):
		t.call("take_counter", away)
	else:
		t.call("take_kick", away)
	countered.emit(t)
	kick_hit.emit(t, side)
	return true


## A kicked stick rider lets go of his stick at pos: it flies in an arc (STICK_FLIGHT_S, STICK_ARC_H) to where the rider's
## hands will be (the bike's spot STICK_FLIGHT_S ahead at its speed) and is caught when the bike arrives within STICK_CATCH_LAT
## to the side and STICK_CATCH_ALONG along it with free hands; otherwise it drops onto the road there, with a pickup ring:
## riding over it within STICK_PICK_R still picks it up, until STICK_LIFE.
func drop_stick(pos: Vector3, _vel: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = "DroppedStick"
	n.top_level = true
	add_child(n)
	var from: Vector3 = Vector3(pos.x, pos.y + 1.2, pos.z)
	n.global_position = from
	var wood: StandardMaterial3D = CineFX._mat(Color("#7A5230"), 0.8)
	var st: MeshInstance3D = CineFX._cyl(n, "Wood", 0.03, 0.036, 1.15, Vector3.ZERO, wood)
	st.rotation = Vector3(0.0, 0.0, PI * 0.5)
	var ring := MeshInstance3D.new()
	ring.name = "PickupRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.65
	tm.rings = 20
	tm.ring_segments = 4
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.86, 0.2, 0.8)
	rm.set_meta("vice_done", true)
	tm.material = rm
	ring.mesh = tm
	ring.scale = Vector3(1.0, 0.2, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false                     # only once it lies on the road
	ring.top_level = true
	n.add_child(ring)
	drops.append({"node": n, "ring": ring, "t": 0.0, "from": from, "to": hands_ahead(BikeCombatData.STICK_FLIGHT_S), "flying": true})
	return n


## Where the rider's hands will be in `secs` at the bike's current speed and heading (the stick's catch point).
func hands_ahead(secs: float) -> Vector3:
	if bike == null or not is_instance_valid(bike):
		return Vector3.ZERO
	var z: Vector3 = bike.global_transform.basis.z
	var f := Vector3(-z.x, 0.0, -z.z)
	f = f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD
	return bike.global_position + f * bike.current_speed_ms * secs + Vector3(0.0, 1.3, 0.0)


func clear_drops() -> void:
	for d: Dictionary in drops:
		if is_instance_valid(d["node"]):
			(d["node"] as Node).queue_free()
	drops.clear()


func _tick_drops(delta: float) -> void:
	var bp := Vector2(bike.global_position.x, bike.global_position.z) if bike and is_instance_valid(bike) else Vector2(INF, INF)
	for i: int in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d["t"] = float(d["t"]) + delta
		var n: Node3D = d["node"] if is_instance_valid(d["node"]) else null
		if n == null:
			drops.remove_at(i)
			continue
		var hands_free: bool = stick_swings <= 0 and enabled and not knocked and riding()
		if bool(d["flying"]):
			var u: float = clampf(float(d["t"]) / BikeCombatData.STICK_FLIGHT_S, 0.0, 1.0)
			n.global_position = (d["from"] as Vector3).lerp(d["to"], u) + Vector3(0.0, BikeCombatData.STICK_ARC_H * sin(PI * u), 0.0)
			n.rotation = Vector3(0.0, u * TAU * 1.5, 0.4 * sin(u * 9.0))
			if u < 1.0:
				continue
			update_frame()
			var rel := Vector2(n.global_position.x - bp.x, n.global_position.z - bp.y)
			if hands_free and absf(rel.dot(right2)) <= BikeCombatData.STICK_CATCH_LAT and absf(rel.dot(fwd2)) <= BikeCombatData.STICK_CATCH_ALONG:
				_take_stick(i, n)
				continue
			d["flying"] = false              # missed (steered away, braked, hands full): it drops onto the road
			d["t"] = 0.0
			n.global_position = Vector3(n.global_position.x, bike.global_position.y + 0.18, n.global_position.z)
			n.rotation = Vector3(0.0, n.rotation.y, 0.0)
			var ring: Node3D = d["ring"]
			ring.visible = true
			ring.global_position = n.global_position - Vector3(0.0, 0.04, 0.0)
			continue
		if float(d["t"]) >= BikeCombatData.STICK_LIFE:
			n.queue_free()
			drops.remove_at(i)
			continue
		if hands_free and Vector2(n.global_position.x - bp.x, n.global_position.z - bp.y).length() <= BikeCombatData.STICK_PICK_R:
			_take_stick(i, n)


func _take_stick(i: int, n: Node3D) -> void:
	n.queue_free()
	drops.remove_at(i)
	stick_picks += 1
	_set_stick(BikeCombatData.STICK_SWINGS)
	_cue("bag_drop", bike.global_position + Vector3(0.0, 1.0, 0.0), -2.0)
	stick_picked.emit()


## The stick still in the air (tests).
func stick_flying() -> bool:
	for d: Dictionary in drops:
		if bool(d["flying"]):
			return true
	return false


## The grabbed stick on the rider (raised on the right) with n swings left; 0 hides it.
func _set_stick(n: int) -> void:
	stick_swings = n
	if n > 0 and bike and is_instance_valid(bike) and bike.rider_node:
		if _stick_node == null or not is_instance_valid(_stick_node):
			_stick_node = Node3D.new()
			_stick_node.name = "GrabbedStick"
			bike.rider_node.add_child(_stick_node)
			CineFX._cyl(_stick_node, "Wood", 0.028, 0.036, 1.15, Vector3(0.0, 0.5, 0.0), CineFX._mat(Color("#7A5230"), 0.8))
			_stick_node.position = Vector3(0.32, 1.2, 0.05)
			_stick_node.rotation = Vector3(0.35, 0.0, -0.3)
		_stick_node.visible = true
	elif _stick_node and is_instance_valid(_stick_node):
		_stick_node.visible = false


## A swing done: one less; the last one breaks the stick (crack, splinters).
func _use_stick() -> void:
	_set_stick(stick_swings - 1)
	if stick_swings <= 0:
		var at: Vector3 = bike.global_position + Vector3(0.0, 1.3, 0.0)
		_cue("stick_crack", at, 0.0)
		Impact.particles(self, "debris", at, Vector3.UP, 0.7, fx)
		stick_broke.emit()


## The stick's swing pose: cocked during the wind-up, swept flat toward the kick side through the hit window.
func _pose_stick() -> void:
	if _stick_node == null or not is_instance_valid(_stick_node) or not _stick_node.visible:
		return
	var sd: float = float(kick_side)
	if kick_t < 0.0:
		_stick_node.position = Vector3(0.32, 1.2, 0.05)
		_stick_node.rotation = Vector3(0.35, 0.0, -0.3)
		return
	var k: float = clampf((kick_t - BikeCombatData.KICK_WINDUP * 0.5) / (BikeCombatData.KICK_ACTIVE_END - BikeCombatData.KICK_WINDUP * 0.5), 0.0, 1.0)
	_stick_node.position = Vector3(0.32 * sd, 1.2, 0.05)
	_stick_node.rotation = Vector3(lerpf(0.75, 0.0, k), 0.0, -sd * lerpf(-0.45, 1.45, k))


## The spin's motion trail: a 120 degree ribbon behind the leg, bright at the head and fading to the tail (vertex alpha),
## built once and turned with the rider (no allocation per frame).
func _trail_start() -> void:
	if bike == null or bike.visual_pivot == null:
		return
	if _trail == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg: int = 16
		var arc: float = deg_to_rad(120.0)
		for i: int in seg:
			var a0: float = -arc * float(i) / float(seg)
			var a1: float = -arc * float(i + 1) / float(seg)
			var c0 := Color(0.85, 0.95, 1.0, 0.9 * (1.0 - float(i) / float(seg)))
			var c1 := Color(0.85, 0.95, 1.0, 0.9 * (1.0 - float(i + 1) / float(seg)))
			var ri: float = SPIN_ARC_R - 0.12
			var ro: float = SPIN_ARC_R + 0.22
			var p0i := Vector3(sin(a0) * ri, 0.0, -cos(a0) * ri)
			var p0o := Vector3(sin(a0) * ro, 0.04, -cos(a0) * ro)
			var p1i := Vector3(sin(a1) * ri, 0.0, -cos(a1) * ri)
			var p1o := Vector3(sin(a1) * ro, 0.04, -cos(a1) * ro)
			for v: Array in [[p0i, c0], [p0o, c0], [p1o, c1], [p0i, c0], [p1o, c1], [p1i, c1]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
		_trail = MeshInstance3D.new()
		_trail.name = "SpinTrail"
		_trail.mesh = st.commit()
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_trail_mat.vertex_color_use_as_albedo = true
		_trail_mat.set_meta("vice_done", true)
		_trail.material_override = _trail_mat
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail.position = Vector3(0.0, 0.55, 0.1)
		bike.visual_pivot.add_child(_trail)
	_trail.visible = true
	_trail.rotation.y = 0.0
	_trail_mat.albedo_color.a = 1.0


func _no_shake(_s: float) -> void:
	pass


func trail_visible() -> bool:
	return _trail != null and _trail.visible


func _log(r: String) -> void:
	results.append(r)
	if results.size() > 16:
		results.pop_front()


## Kick leg over the rider (rigged: bone layer after its RigAnimator, only on frames it ran; else a lean of the body).
func _process(_d: float) -> void:
	if bike == null or not is_instance_valid(bike) or bike.rider_node == null:
		return
	if spin_t >= 0.0 and not knocked:
		_process_spin()
		return
	_pose_stick()
	var w: float = 0.0 if knocked or kick_t < 0.0 else BikeCombatData.kick_weight(kick_t, BikeCombatData.KICK_WINDUP, BikeCombatData.KICK_ACTIVE_END, BikeCombatData.KICK_DUR)
	if _sk:
		if w > 0.001 and (_anim == null or int(_anim.get("_lod_skip")) == 1):
			CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.kick_pose(float(kick_side)), w)
	else:
		bike.rider_node.rotation.z = -float(kick_side) * 0.35 * w


## Spin look: the rider turns a full circle on the seat (eased), the leg out on the leading side, the arc ribbon fading
## and growing around him.
func _process_spin() -> void:
	var u: float = clampf(spin_t / SPIN_DUR, 0.0, 1.0)
	var turn: float = spin_dir * TAU * (1.0 - pow(1.0 - u, 2.2))
	bike.rider_node.rotation.y = turn
	var w: float = sin(u * PI)
	if _sk:
		if _anim == null or int(_anim.get("_lod_skip")) == 1:
			CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.kick_pose(spin_dir), clampf(w * 1.4, 0.0, 1.0))
	else:
		bike.rider_node.rotation.z = -spin_dir * 0.35 * w
	if _arc and _arc_mat:
		_arc.rotation.y = turn
		var sc: float = lerpf(0.7, 1.35, u)
		_arc.scale = Vector3(sc, 0.25, sc)
		_arc_mat.albedo_color.a = 0.85 * (1.0 - u)
	if _trail and _trail_mat:
		_trail.visible = u < 1.0
		_trail.rotation.y = turn
		_trail_mat.albedo_color.a = 1.0 - smoothstep(0.65, 1.0, u)


func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo or (k.physical_keycode != KEY_Q and k.physical_keycode != KEY_E):
		return
	if not riding():
		return                             # on foot: Q / E belong to the Vovinam block / finisher and the markers
	kick(-1 if k.physical_keycode == KEY_Q else 1)
	get_viewport().set_input_as_handled()


func _cue(cue: String, at: Vector3, db: float = 0.0) -> void:
	if _sfx.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	var st: AudioStream = ImpactAudio.ready_stream(cue) if ImpactAudio.is_cue(cue) else (WeaponAudio.stream(cue) if WeaponAudio.CUES.has(cue) else CineAudio.sfx(cue))
	if st == null:
		return                               # a Q2 layer still building on its worker: skipped, never waited for
	p.stream = st
	p.volume_db = db
	p.global_position = at
	p.play()


func _exit_tree() -> void:
	clear_drops()
	if _lay and _lay.is_valid():
		_lay.kill()
	if bike and is_instance_valid(bike):
		if knocked:
			bike.visual_pivot.rotation.z = 0.0
		if _connected and bike.crash_occurred.is_connected(_on_crash):
			bike.crash_occurred.disconnect(_on_crash)
	_connected = false
	_lock(false)
