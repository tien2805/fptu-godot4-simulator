# File: res://scripts/combat/bike/DriftRival.gd
# Sói Xám on his grey tuned scooter, the rival of the Day 2 drift duel (spec D2X-10). Kinematic, no physics body: the
# node is the bike (top_level), placed every frame on the DriftCourse racing line at its progress s and lateral offset d,
# on the floor found by a throttled ray. DriftDuel owns it: add_child first, then setup(course), then tick(delta, gap)
# every physics frame with `band` (the rubber-band factor) set.
#   - Look: StoryCast "soi_xam" (wolf helmet, LED eyes) riding (the "ride" code clip) or standing beside the bike (intro);
#     a PropBuilder scooter in grey with a red underglow strip and glow light, a headlight, a tail light, a blue nitro
#     flame (NitroFX), tyre smoke, a name label that shows his taunts.
#   - Driving: the course's speed profile x the band factor, reached with ACCEL / BRAKE limits; visible drifts wherever
#     the radius is under DriftCourse.DRIFT_R at speed (the nose turned into the corner up to DRIFT_YAW_MAX, lean, smoke,
#     a skid loop); a nitro burst out of the tight corners onto the straights (flame, whoosh, NITRO_BONUS for NITRO_S).
#   - Sound: the owner's exhaust loop (else the res:// engine wav) pitched by speed; rev_answer() for the countdown: the
#     owner's sfx bike_rev at pitch 0.85 and REV_DB_UNDER under the player's rev level as a 3D sound, else a blip of his
#     exhaust loop (pitch 0.85 x the PlayerBike blip curve). Recorded audio only.
class_name DriftRival
extends Node3D

const SEAT := Vector3(0.0, 0.32, 0.14)
const PAINT := Color("#5C626B")
const GLOW := Color("#FF2340")
const NAME: String = "Sói Xám"
const TAUNTS: Array[String] = ["Theo kịp không cưng?", "Bám đuôi cho chắc vào!", "Drift vậy mà cũng đòi đua?", "Chậm như rùa!",
	"Ê, còn thở không?"]
const T_CLOSE: String = "Bám dai thế!"
const T_FAR: String = "Về nhà ngủ đi cưng!"
const ACCEL: float = 12.0               # as quick off the line as the player's bike on the duel profile
const BRAKE: float = 14.0
const DRIFT_YAW_MAX: float = 0.6          # ~35 degrees, the nose into the corner
const LEAN_MAX: float = 0.45
const NITRO_BONUS: float = 3.0
const NITRO_S: float = 1.4
const LAT_BLEND_M: float = 60.0           # from his start offset onto the racing line over this many metres
const RAY_EVERY: int = 6
const REV_PITCH: float = 0.85
const REV_DB_UNDER: float = 4.0
const MAX_RISE: float = 1.0                # a floor hit higher than this above the current floor is ignored
const TAUNT_EVERY: Vector2 = Vector2(5.0, 9.0)
const TAUNT_S: float = 1.8

var course: DriftCourse
var s: float = 0.0                        # progress along the lap (0 .. course.length, unwrapped)
var d: float = 0.0
var d0: float = 0.0
var s_start: float = 0.0
var v: float = 0.0
var band: float = 1.0
## DriftDuel sets it while the player is on his tail or ahead: he drifts harder (DriftCourse.speed_fight).
var fight: bool = false
var racing: bool = false
var finished: bool = false
var standing: bool = false
var drift_amt: float = 0.0
var drift_dir: float = 0.0
var drifting: bool = false
var drift_time: float = 0.0
var nitro_t: float = 0.0
var nitros: int = 0
var revs: int = 0
var rev_source: String = ""
var yaw: float = 0.0
var lean: float = 0.0
var floor_y: float = 0.0
var body: Node3D
var label3d: Label3D
var headlight: SpotLight3D
var glow_light: OmniLight3D
var nitro_fx: NitroFX
var smoke: CPUParticles3D
var engine: AudioStreamPlayer3D
var skid: AudioStreamPlayer3D
var rev_player: AudioStreamPlayer3D
var whoosh: AudioStreamPlayer3D
var ray_exclude: Array[RID] = []
## Extra path the rival rides after the race (the ending: down off the bridge), map points; empty = none.
var exit_path := PackedVector2Array()
var exit_speed: float = 7.0
var _exit_i: int = 0
var _exit_p: Vector2 = Vector2.ZERO
var _ap: AnimationPlayer = null
var _rng := RandomNumberGenerator.new()
var _frame: int = 0
var _taunt_t: float = 6.0
var _taunt_left: float = 0.0
var _blip_t: float = -1.0
var _ray_q: PhysicsRayQueryParameters3D
var _owner_exhaust: bool = false
var _was_tight: bool = false


func setup(c: DriftCourse, opts: Dictionary = {}) -> void:
	course = c
	top_level = true
	name = "SoiXamRival"
	_rng.seed = int(opts.get("seed", 3131))
	PropBuilder.build_scooter(self, Vector3.ZERO, 0.0, PAINT, {"baked": true, "name": "Scooter", "traffic_lamps": true})
	_build_tuning()
	body = StoryCast.build("soi_xam", {"clip": "ride"})
	if body:
		body.name = "Rider"
		body.position = SEAT
		add_child(body)
		CharacterBuilder.set_param(body, "ride_shoulder", 1.2)
		CharacterBuilder.set_param(body, "ride_elbow", 0.28)
		CharacterBuilder.set_param(body, "ride_lean", 0.5)
		var an: Node = CharacterBuilder.get_animator(body)
		_ap = an.get("player") as AnimationPlayer if an else null
		if _ap:
			_ap.active = false          # the ride code clip owns the joints while riding
	label3d = Label3D.new()
	label3d.name = "Name"
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.font_size = 44
	label3d.pixel_size = 0.006
	label3d.outline_size = 8
	label3d.modulate = Color("#D8DEE6")
	label3d.position = Vector3(0.0, 2.3, 0.0)
	label3d.text = NAME
	add_child(label3d)
	_build_audio()
	_ray_q = PhysicsRayQueryParameters3D.new()
	_ray_q.exclude = ray_exclude
	process_priority = 11


## Underglow strip and light, headlight, tail lamp, nitro flame, tyre smoke.
func _build_tuning() -> void:
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = GLOW
	glow_mat.emission_enabled = true
	glow_mat.emission = GLOW
	glow_mat.emission_energy_multiplier = 4.0
	glow_mat.set_meta("vice_done", true)
	for sx: float in [-0.13, 0.13]:
		CineFX._box(self, "Underglow", Vector3(0.03, 0.02, 1.0), Vector3(sx, 0.16, 0.0), glow_mat)
	glow_light = OmniLight3D.new()
	glow_light.name = "UnderglowLight"
	glow_light.light_color = GLOW
	glow_light.omni_range = 2.6
	glow_light.light_energy = 1.2
	glow_light.shadow_enabled = false
	glow_light.position = Vector3(0.0, 0.1, 0.0)
	add_child(glow_light)
	headlight = SpotLight3D.new()
	headlight.name = "Headlight"
	headlight.light_color = Color("#E8F0FF")
	headlight.spot_range = 45.0
	headlight.spot_angle = 26.0
	headlight.light_energy = 3.0
	headlight.shadow_enabled = false
	headlight.position = Vector3(0.0, 1.0, -0.6)
	headlight.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	add_child(headlight)
	var tail_mat: StandardMaterial3D = CineFX._glow_mat(Color("#FF1A1A"), 3.0)
	CineFX._box(self, "Tail", Vector3(0.14, 0.05, 0.03), Vector3(0.0, 0.78, 0.86), tail_mat)
	nitro_fx = NitroFX.build(self, Vector3(0.16, 0.42, 0.8), Vector3(0.0, 0.15, 1.0))
	smoke = CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.emitting = false
	smoke.amount = 26
	smoke.lifetime = 0.8
	smoke.local_coords = false
	smoke.direction = Vector3(0.0, 0.6, 1.0)
	smoke.spread = 35.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.4
	smoke.gravity = Vector3(0.0, 0.9, 0.0)
	smoke.scale_amount_min = 0.3
	smoke.scale_amount_max = 0.8
	smoke.color = Color(0.86, 0.86, 0.88, 0.55)
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.set_meta("vice_done", true)
	sm.material = mat
	smoke.mesh = sm
	smoke.position = Vector3(0.0, 0.18, 0.66)
	add_child(smoke)


func _build_audio() -> void:
	engine = _player3d("Engine", 8.0, -4.0)
	var ex: AudioStream = PlayerBike.owner_sfx(PlayerBike.SFX_EXHAUST, false)
	if ex:
		engine.stream = ex
		_owner_exhaust = true
	else:
		engine.stream = _wav("res://assets/audio/bike_engine_loop.wav", true)
	skid = _player3d("Skid", 6.0, -6.0)
	skid.stream = _wav("res://assets/audio/tire_skid.wav", true)
	rev_player = _player3d("Rev", 8.0, 0.0)
	whoosh = _player3d("Whoosh", 7.0, -2.0)
	whoosh.stream = NitroFX.whoosh_stream()


func _player3d(nm: String, unit: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = nm
	p.unit_size = unit
	p.max_distance = 80.0
	p.volume_db = db
	add_child(p)
	var fx: Node = get_node_or_null("/root/GameFX") if is_inside_tree() else null
	if fx:
		fx.route_audio_to_bus(p, "SFX")
	return p


func _wav(path: String, loop: bool) -> AudioStream:
	var fx: Node = get_node_or_null("/root/GameFX") if is_inside_tree() else null
	if fx and fx.has_method("load_wav"):
		return fx.call("load_wav", path, loop)
	return null


# ---------------------------------------------------------------------------
# PLACEMENT / STATES
# ---------------------------------------------------------------------------
## On the line at progress s0, lateral d0 (blended onto the line over LAT_BLEND_M once racing), stopped.
func place_at(s0: float, lat0: float) -> void:
	s = s0
	s_start = s0
	d0 = lat0
	d = lat0
	v = 0.0
	band = 1.0
	racing = false
	finished = false
	drift_amt = 0.0
	drifting = false
	nitro_t = 0.0
	exit_path = PackedVector2Array()
	_exit_i = 0
	if nitro_fx:
		nitro_fx.set_on(false)
	if smoke:
		smoke.emitting = false
	if skid and skid.playing:
		skid.stop()
	yaw = course.yaw_at(s)
	lean = 0.0
	var p: Vector2 = course.world(s, d)
	var y: Variant = _floor_ray(Vector3(p.x, 0.0, p.y), 6.0, 6.0)
	floor_y = float(y) if y is float else 0.05
	_place()
	if engine and engine.stream and engine.is_inside_tree() and not engine.playing:
		engine.play()
	_idle_engine()


## Intro: he stands beside his bike (left side), facing back down the line toward the player.
func stand_beside(on: bool) -> void:
	standing = on
	if body == null:
		return
	if on:
		body.position = Vector3(-0.9, 0.0, 0.3)
		body.rotation = Vector3(0.0, PI, 0.0)
		if _ap:
			_ap.active = true
		CharacterBuilder.stop_clip(body)
	else:
		body.position = SEAT
		body.rotation = Vector3.ZERO
		CharacterBuilder.play(body, "ride")
		if _ap:
			_ap.active = false


func start_race() -> void:
	racing = true
	finished = false
	stand_beside(false)
	_fire_nitro()   # a launch burst off the line


## A short line in the label (taunts, the ending).
func say(text: String, secs: float = TAUNT_S) -> void:
	label3d.text = NAME + "\n" + text
	_taunt_left = secs


func flash_headlight(on: bool) -> void:
	if headlight:
		headlight.light_energy = 7.0 if on else 3.0


# ---------------------------------------------------------------------------
# PER FRAME (DriftDuel calls it)
# ---------------------------------------------------------------------------
## gap = his progress minus the player's (m): drives the taunts only; the band factor is set by DriftDuel.
func tick(delta: float, gap: float) -> void:
	_frame += 1
	_taunts(delta, gap)
	if nitro_fx and nitro_fx.on:
		nitro_fx.tick(delta)
	_tick_blip(delta)
	if exit_path.size() >= 2:
		_ride_exit(delta)
		return
	if not racing:
		_idle_engine()
		return
	var target: float = course.speed_at(s + v * 0.35, fight) * band
	if nitro_t > 0.0:
		nitro_t -= delta
		target += NITRO_BONUS
		if nitro_t <= 0.0 and nitro_fx:
			nitro_fx.set_on(false)
	if finished:
		target = maxf(0.0, v - BRAKE * 0.6 * delta)
	v = move_toward(v, target, (ACCEL if target > v else BRAKE) * delta)
	s += v * delta
	var u: float = clampf((s - s_start) / LAT_BLEND_M, 0.0, 1.0)
	d = lerpf(d0, 0.0, smoothstep(0.0, 1.0, u))
	# drift: the nose into tight corners at speed
	var r: float = course.radius_at(s + 3.0)
	var tight: bool = r < DriftCourse.DRIFT_R and v > 8.0
	var ya: float = course.yaw_at(s)
	var yb: float = course.yaw_at(s + 4.0)
	var turn: float = wrapf(yb - ya, -PI, PI)
	if tight:
		drift_dir = signf(turn)
	var want: float = clampf((DriftCourse.DRIFT_R - r) / (DriftCourse.DRIFT_R - 8.0), 0.0, 1.0) if tight else 0.0
	drift_amt = move_toward(drift_amt, want, delta * (4.0 if want > drift_amt else 2.5))
	var now: bool = drift_amt > 0.25
	if now != drifting:
		drifting = now
		if smoke:
			smoke.emitting = now
		if skid and skid.stream:
			if now:
				skid.play()
			else:
				skid.stop()
	if drifting:
		drift_time += delta
	if _was_tight and not tight and v > 10.0 and nitro_t <= 0.0 and r > 60.0 and course.radius_at(s + 40.0) > 150.0:
		_fire_nitro()   # out of a tight corner onto a long straight
	_was_tight = tight if tight else (_was_tight and r < 60.0)
	yaw = lerp_angle(yaw, ya + drift_dir * DRIFT_YAW_MAX * drift_amt, minf(1.0, delta * 10.0))
	lean = lerpf(lean, clampf(turn * 3.0, -1.0, 1.0) * LEAN_MAX * clampf(v / 15.0, 0.0, 1.0), minf(1.0, delta * 8.0))
	if (_frame + 3) % RAY_EVERY == 0:
		var p: Vector2 = course.world(s, d)
		var y: Variant = _floor_ray(Vector3(p.x, floor_y, p.y), 3.0, 6.0, MAX_RISE)
		if y is float:
			floor_y = lerpf(floor_y, float(y), 0.6) if absf(float(y) - floor_y) < 1.5 else float(y)
	_place()
	if engine and engine.playing and _blip_t < 0.0:
		var ratio: float = clampf(v / DriftCourse.RIVAL_V_TOP, 0.0, 1.2)
		engine.pitch_scale = lerpf(engine.pitch_scale, PlayerBike.exhaust_pitch(ratio, 1.0) if _owner_exhaust else 0.85 + ratio * 0.95, minf(1.0, delta * 8.0))
		engine.volume_db = lerpf(engine.volume_db, PlayerBike.exhaust_db(0.85) if _owner_exhaust else -2.0, minf(1.0, delta * 6.0))


func _place() -> void:
	var p: Vector2
	if exit_path.size() >= 2:
		p = _exit_p
	else:
		p = course.world(s, d)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), lean)
	global_transform = Transform3D(b, Vector3(p.x, floor_y, p.y))


func _fire_nitro() -> void:
	nitro_t = NITRO_S
	nitros += 1
	if nitro_fx:
		nitro_fx.set_on(true)
	if whoosh and whoosh.stream and whoosh.is_inside_tree():
		whoosh.play()


func _taunts(delta: float, gap: float) -> void:
	if _taunt_left > 0.0:
		_taunt_left -= delta
		if _taunt_left <= 0.0:
			label3d.text = NAME
		return
	if not racing or finished:
		return
	_taunt_t -= delta
	if _taunt_t > 0.0:
		return
	_taunt_t = _rng.randf_range(TAUNT_EVERY.x, TAUNT_EVERY.y)
	if gap < 6.0 and gap > 0.0:
		say(T_CLOSE)
	elif gap > 30.0:
		say(T_FAR)
	else:
		say(TAUNTS[_rng.randi() % TAUNTS.size()])


## Countdown answer (about 0.5 s after each count): the owner's bike_rev at REV_PITCH, REV_DB_UNDER under the player's
## rev level, at his bike; else a blip of his exhaust loop.
func rev_answer() -> void:
	revs += 1
	var st: AudioStream = PlayerBike.owner_sfx(PlayerBike.SFX_REV, false)
	if st and rev_player:
		rev_player.stream = st
		rev_player.pitch_scale = REV_PITCH
		rev_player.volume_db = rev_db()
		if rev_player.is_inside_tree():
			rev_player.play()
		rev_source = "file"
	else:
		_blip_t = 0.0
		rev_source = "blip"


func rev_db() -> float:
	var riding: float = PlayerBike.exhaust_db(1.0) if _owner_exhaust else -1.5
	return riding + PlayerBike.REV_DB_OVER - REV_DB_UNDER


func _idle_pitch() -> float:
	return PlayerBike.exhaust_pitch(0.0, 0.0) if _owner_exhaust else 0.85


func _idle_engine() -> void:
	if engine and engine.playing and _blip_t < 0.0:
		engine.pitch_scale = _idle_pitch() * REV_PITCH
		engine.volume_db = PlayerBike.exhaust_db(0.0) if _owner_exhaust else -5.0


func _tick_blip(delta: float) -> void:
	if _blip_t < 0.0:
		return
	_blip_t += delta
	if _blip_t >= PlayerBike.REV_BLIP_S or engine == null:
		_blip_t = -1.0
		_idle_engine()
		return
	engine.pitch_scale = PlayerBike.rev_blip_pitch(_blip_t, _idle_pitch()) * REV_PITCH
	engine.volume_db = rev_db()


## The ending: rides the exit path (map points) at exit_speed, then stops at its end.
func ride_exit(path: PackedVector2Array, spd: float = 7.0) -> void:
	exit_path = path
	exit_speed = spd
	_exit_i = 0
	racing = false
	_exit_p = course.world(s, d)
	if smoke:
		smoke.emitting = false
	if skid and skid.playing:
		skid.stop()


func exit_done() -> bool:
	return exit_path.size() >= 2 and _exit_i >= exit_path.size()


func _ride_exit(delta: float) -> void:
	if _exit_i >= exit_path.size():
		return
	var tgt: Vector2 = exit_path[_exit_i]
	var to: Vector2 = tgt - _exit_p
	var step: float = exit_speed * delta
	if to.length() <= step:
		_exit_p = tgt
		_exit_i += 1
	else:
		_exit_p += to.normalized() * step
		yaw = lerp_angle(yaw, atan2(-to.x, -to.y), minf(1.0, delta * 6.0))
	if (_frame + 3) % RAY_EVERY == 0:
		var y: Variant = _floor_ray(Vector3(_exit_p.x, floor_y, _exit_p.y), 3.0, 8.0, MAX_RISE)
		if y is float:
			floor_y = lerpf(floor_y, float(y), 0.5)
	lean = lerpf(lean, 0.0, minf(1.0, delta * 4.0))
	_place()


## Floor height under p (a ray from `up` above to `down` below; not the player's bike). Character bodies (pedestrians,
## the player on foot) are looked through; a hit more than max_rise above the current floor is not floor (a car roof, a
## head). null = none.
func _floor_ray(p: Vector3, up: float, down: float, max_rise: float = INF) -> Variant:
	if not is_inside_tree():
		return null
	_ray_q.from = p + Vector3(0.0, up, 0.0)
	_ray_q.to = p - Vector3(0.0, down, 0.0)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var added: int = 0
	var out: Variant = null
	for k: int in 4:
		var hit: Dictionary = space.intersect_ray(_ray_q)
		if hit.is_empty():
			break
		if hit["collider"] is CharacterBody3D:
			ray_exclude.append(hit["rid"])   # rare: only when a body stands in the ray
			added += 1
			_ray_q.exclude = ray_exclude
			continue
		var y: float = (hit["position"] as Vector3).y
		if (hit["normal"] as Vector3).y >= 0.5 and y <= floor_y + max_rise:
			out = y
		break
	if added > 0:
		ray_exclude.resize(ray_exclude.size() - added)
		_ray_q.exclude = ray_exclude
	return out


func ground_pos() -> Vector3:
	return Vector3(global_position.x, floor_y, global_position.z)
