# File: res://scripts/combat/bike/DriftRival.gd
# Sói Xám on his grey tuned scooter, the rival of the Day 2 race "Rạch Hầm GP" (Wave 2 Day 2 rework, plan
# 2026-10-29-w2-day2.md: "đua + đánh"). Kinematic, no physics body: the node is the bike (top_level), placed every frame on
# the DriftCourse path at its progress s and its own lateral line d, on the floor found by a throttled ray. DriftDuel owns
# it: add_child, setup(course), then each physics frame sets band / fight / p_s / p_d / p_v (the player on the path) and
# calls tick(delta, gap).
#   - Look: StoryCast "soi_xam" (wolf helmet, LED eyes) riding (the "ride" code clip) or standing beside the bike (intro);
#     a PropBuilder scooter in grey with a red underglow strip and glow light, a headlight, a tail light, a blue nitro flame
#     (NitroFX), tyre smoke, a name label that shows his taunts, a red telegraph ring on the road while he winds up a kick.
#   - Racing: the course's speed profile x PACE (difficulty) x band (DriftDuel's rubber band), reached with ACCEL / BRAKE
#     limits; visible drifts in the tight corners; NITROS nitro bursts a race (on long straights when the player is close
#     or ahead, and a launch burst off the grid).
#   - Aggression: he BLOCKS (on a straight with the player within BLOCK_M behind he moves onto the player's line), and
#     KICKS (the player alongside: a KICK_WINDUP telegraph - the ring, a rev, his headlight flashing, DriftDuel's side
#     warning - the line locked LOCK_S before it, then the kick: kick_fn(side) when the player is still in reach; a steer
#     away, a brake or a counter-kick beats it), KICK_COOLDOWN apart.
#   - The player's kick target (PlayerBikeCombat duck typing): kickable(), take_kick(away, power), take_counter(away),
#     time_to_hit(), ground_pos(), hp (kicks left), impact_react(tier, dir, opts). Each kick flinches him and cancels his
#     wind-up; KICKS_TO_WOBBLE kicks (a counter is worth 2) make him WOBBLE for WOBBLE_S: he flails, sparks fly, he loses
#     speed (x WOBBLE_SPEED) and cannot kick; then the count starts again.
#   - Sound: the owner's exhaust loop (else the res:// engine wav) pitched by speed; rev_answer() for the countdown (the
#     owner's sfx bike_rev at pitch 0.85, else a blip of his exhaust loop). Recorded audio only; the kick swish and thuds
#     are the synthesized combat cues.
# Every tuned number goes through Difficulty.pick(normal, easy) (read when a race starts: refresh_tuning()).
# Playtest fixes (plan 2026-10-30-d2-playtest-fixes.md): lead_cap (DriftDuel sets it, 0 = off), while the player races
# (at LEASH_MIN_V or faster): from LEAD_SOFT_M before it his speed is held toward the player's, and he never rides past it
# (the clamp stops him at the cap; it never pulls him back, so a player who stops or falls far behind is still beaten);
# beyond the cap (a reset, a stop) he rides a little slower than the player until back inside it. magnet(side, secs): the
# player's kick assist pulls him toward the leg.
# w5-side (plan 2026-11-03-w5-side.md): the rivals of the free-roam side races reuse him through setup opts, the defaults
# unchanged (Day 2): "cast" (StoryCast id, "cast_extra" its extra opts) or "look" (CharacterBuilder rider opts) for the body, "name" (the label and the
# taunts' prefix), "paint" / "glow" (scooter and underglow colours), "calm" (no kicks and no blocks: he rides `lane`, his
# own lateral line, and still drifts and fires nitro), "lane", "taunts" (his random lines).
class_name DriftRival
extends Node3D

signal kicked_player(side: int, hit: bool)
signal wobbled

const SEAT := Vector3(0.0, 0.32, 0.14)
const PAINT := Color("#5C626B")
const GLOW := Color("#FF2340")
const NAME: String = "Sói Xám"
const TAUNTS: Array[String] = ["Theo kịp không cưng?", "Đua với tao à? Mơ đi!", "Né đường cho đại ca!", "Chậm như rùa!",
	"Ê, còn thở không?"]
const T_CLOSE: String = "Bám dai thế!"
const T_FAR: String = "Về nhà ngủ đi cưng!"
const T_KICK: String = "Ăn đạp này!"
const T_WOBBLE: String = "Á... xe tao!"
const T_BLOCK: String = "Qua được thì qua!"
const ACCEL: float = 12.0
const BRAKE: float = 14.0
const DRIFT_YAW_MAX: float = 0.6          # ~35 degrees, the nose into the corner
const LEAN_MAX: float = 0.45
const NITRO_BONUS: float = 4.0
const NITRO_S: float = 1.6
const NITRO_GAP_S: float = 7.0
const LAT_EDGE: float = 0.9               # he keeps this far inside the road edge
const LAT_GRID_BLEND_M: float = 60.0      # from his grid offset onto his line over this many metres
const AI_EVERY: float = 0.2
const BLOCK_M: float = 14.0
const ATTACK_LAT: float = 1.5             # he rides this far beside the player's line while winding up
const KICK_ALONG: float = 1.8             # the kick lands within this along ...
const KICK_LAT_MIN: float = 0.45          # ... and this to KICK_LAT_MAX to the side
const KICK_LAT_MAX: float = 2.6
const KICK_ACTIVE_S: float = 0.35         # the leg out after the wind-up (the hit moment at KICK_HIT_AT)
const KICK_HIT_AT: float = 0.1
const LOCK_S: float = 0.2                 # his lateral line is fixed this long before the kick (steer away = dodge)
const RECOVER_S: float = 0.5
const KICKS_TO_WOBBLE: int = 3
const WOBBLE_S: float = 2.0
const WOBBLE_LURCH: float = 0.8
const FLINCH_S: float = 0.25
const RAY_EVERY: int = 6
const REV_PITCH: float = 0.85
const REV_DB_UNDER: float = 4.0
const MAX_RISE: float = 1.0                # a floor hit higher than this above the current floor is ignored
const TAUNT_EVERY: Vector2 = Vector2(5.0, 9.0)
const TAUNT_S: float = 1.8
const LEAD_SOFT_M: float = 8.0            # from this much before lead_cap his speed eases down to the player's
const LEASH_MIN_V: float = 2.0            # the leash holds unless the player has stopped (m/s; a crawl through a corner counts)
const PAST_CAP_K: float = 0.75            # beyond the cap he rides at this share of the player's speed until back inside
const MAGNET_LAT: float = 1.5
const MAGNET_SPEED: float = 7.0

var course: DriftCourse
var s: float = 0.0                        # progress along the path (0 .. course.total)
var d: float = 0.0                        # his lateral line (+ right of travel)
var d0: float = 0.0
var line_d: float = 0.0                   # the line his AI steers (d blends onto it from the grid offset)
var d_target: float = 0.0
var s_start: float = 0.0
var v: float = 0.0
var band: float = 1.0
## The most he may lead the player by (m along the path, DriftDuel's leash; 0 = no cap) and how often the clamp acted.
var lead_cap: float = 0.0
var lead_clamps: int = 0
var _prev_lead: float = 0.0
var magnet_t: float = 0.0
var magnet_side: float = 0.0
var magnets: int = 0
## DriftDuel sets it while the player is on his tail or ahead: he takes the corners harder (DriftCourse.speed_fight).
var fight: bool = false
## The player on the path (DriftDuel, every frame): progress, lateral offset, speed.
var p_s: float = -999.0
var p_d: float = 0.0
var p_v: float = 0.0
## Called at his kick's hit moment with the side (+1: the player is on his right): returns true when it hurt the player.
var kick_fn: Callable
var racing: bool = false
var finished: bool = false
var standing: bool = false
var drift_amt: float = 0.0
var drift_dir: float = 0.0
var drifting: bool = false
var drift_time: float = 0.0
var nitro_t: float = 0.0
var nitros: int = 0
var nitro_left: int = 0
var revs: int = 0
var rev_source: String = ""
var yaw: float = 0.0
var lean: float = 0.0
var floor_y: float = 0.0
# aggression state
var mode: String = "line"                 # "line" | "block" | "windup" | "kick" | "recover"
var mode_t: float = 0.0
var kick_side: float = 1.0
var kick_cd: float = 3.0
var kicks: int = 0                        # kicks thrown (tests, tuning)
var kick_hits: int = 0                    # ... that hurt the player
var blocks: int = 0
var hits_taken: int = 0                   # the player's kicks since the last wobble
var hits_total: int = 0
var wobble_t: float = 0.0
var wobbles: int = 0
var flinch_t: float = 0.0
var flinch_dir: float = 0.0
var _hit_done: bool = false
var _ai_t: float = 0.0
var _nitro_gap: float = 0.0
## Difficulty-picked tuning (refresh_tuning at each race start).
var pace: float = 1.0
var kick_dmg: float = 20.0
## w5-side setup opts (Day 2 defaults).
var rival_name: String = NAME
var calm: bool = false
var lane: float = 0.0
var taunts: Array = TAUNTS
var glow_col: Color = GLOW
var kick_windup: float = 0.5
var kick_cooldown: float = 2.4
var attack_chance: float = 0.8
var lat_speed: float = 3.5
var wobble_speed: float = 0.55
var nitros_per_race: int = 4
var body: Node3D
var label3d: Label3D
var headlight: SpotLight3D
var glow_light: OmniLight3D
var nitro_fx: NitroFX
var smoke: CPUParticles3D
var ring: MeshInstance3D
var engine: AudioStreamPlayer3D
var skid: AudioStreamPlayer3D
var rev_player: AudioStreamPlayer3D
var whoosh: AudioStreamPlayer3D
var cue_player: AudioStreamPlayer3D
var ray_exclude: Array[RID] = []
## Extra path the rival rides after the race (the ending: down off the bridge), map points; empty = none.
var exit_path := PackedVector2Array()
var exit_speed: float = 7.0
var _exit_i: int = 0
var _exit_p: Vector2 = Vector2.ZERO
var _ap: AnimationPlayer = null
var _sk: Skeleton3D = null
var _anim: Node = null
var _rng := RandomNumberGenerator.new()
var _frame: int = 0
var _taunt_t: float = 6.0
var _taunt_left: float = 0.0
var _blip_t: float = -1.0
var _ray_q: PhysicsRayQueryParameters3D
var _owner_exhaust: bool = false
var _was_tight: bool = false
var _ring_mat: StandardMaterial3D
var _spark_t: float = 0.0
var _pose_w: float = 0.0


func setup(c: DriftCourse, opts: Dictionary = {}) -> void:
	course = c
	top_level = true
	name = "SoiXamRival"
	_rng.seed = int(opts.get("seed", 3131))
	rival_name = String(opts.get("name", NAME))
	calm = bool(opts.get("calm", false))
	lane = float(opts.get("lane", 0.0))
	if opts.has("taunts"):
		taunts = opts["taunts"]
	glow_col = opts.get("glow", GLOW)
	refresh_tuning()
	PropBuilder.build_scooter(self, Vector3.ZERO, 0.0, opts.get("paint", PAINT), {"baked": true, "name": "Scooter", "traffic_lamps": true})
	_build_tuning()
	if opts.has("look"):
		var lk: Dictionary = (opts["look"] as Dictionary).duplicate()
		lk["rigged"] = true
		lk["clip"] = "ride"
		body = CharacterBuilder.build(lk)
	else:
		var ce: Dictionary = (opts.get("cast_extra", {}) as Dictionary).duplicate()
		ce["clip"] = "ride"
		body = StoryCast.build(String(opts.get("cast", "soi_xam")), ce)
	if body:
		body.name = "Rider"
		body.position = SEAT
		add_child(body)
		CharacterBuilder.set_param(body, "ride_shoulder", 1.2)
		CharacterBuilder.set_param(body, "ride_elbow", 0.28)
		CharacterBuilder.set_param(body, "ride_lean", 0.5)
		_anim = CharacterBuilder.get_animator(body)
		_ap = _anim.get("player") as AnimationPlayer if _anim else null
		_sk = body.get_meta("skeleton") as Skeleton3D if body.has_meta("skeleton") else null
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
	label3d.text = rival_name
	add_child(label3d)
	_build_audio()
	_ray_q = PhysicsRayQueryParameters3D.new()
	_ray_q.exclude = ray_exclude
	process_priority = 11
	Readability.rim(self, "enemy")


## The difficulty's numbers (Thường, Dễ).
func refresh_tuning() -> void:
	pace = float(Difficulty.pick(1.04, 0.95))
	kick_dmg = float(Difficulty.pick(20.0, 12.0))
	kick_windup = float(Difficulty.pick(0.5, 0.75))
	kick_cooldown = float(Difficulty.pick(2.4, 4.2))
	attack_chance = float(Difficulty.pick(0.85, 0.45))
	lat_speed = float(Difficulty.pick(3.5, 2.2))
	wobble_speed = float(Difficulty.pick(0.55, 0.45))
	nitros_per_race = int(Difficulty.pick(4, 2))


## Underglow strip and light, headlight, tail lamp, nitro flame, tyre smoke, the kick telegraph ring.
func _build_tuning() -> void:
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = glow_col
	glow_mat.emission_enabled = true
	glow_mat.emission = glow_col
	glow_mat.emission_energy_multiplier = 4.0
	glow_mat.set_meta("vice_done", true)
	for sx: float in [-0.13, 0.13]:
		CineFX._box(self, "Underglow", Vector3(0.03, 0.02, 1.0), Vector3(sx, 0.16, 0.0), glow_mat)
	glow_light = OmniLight3D.new()
	glow_light.name = "UnderglowLight"
	glow_light.light_color = glow_col
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
	# the kick telegraph: a red ring on the road around his bike (Q3 red = danger), grown and pulsed by the wind-up
	ring = MeshInstance3D.new()
	ring.name = "KickRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 1.25
	tm.outer_radius = 1.45
	tm.rings = 24
	tm.ring_segments = 4
	_ring_mat = Readability.telegraph_material("danger", 4.0)
	tm.material = _ring_mat
	ring.mesh = tm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.position = Vector3(0.0, 0.06, 0.0)
	ring.visible = false
	add_child(ring)


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
	cue_player = _player3d("Cue", 7.0, -2.0)
	for c: String in ["whoosh_down", "impact_medium", "helmet_clonk"]:
		CineAudio.sfx(c)                 # synthesized at setup, never mid-race


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


func _cue(c: String, db: float = -2.0) -> void:
	if cue_player and cue_player.is_inside_tree():
		cue_player.stream = CineAudio.sfx(c)
		cue_player.volume_db = db
		cue_player.play()


# ---------------------------------------------------------------------------
# PLACEMENT / STATES
# ---------------------------------------------------------------------------
## On the path at progress s0, lateral lat0 (blended onto his line over LAT_GRID_BLEND_M once racing), stopped; the
## race state reset (kick count, wobble, nitro charges).
func place_at(s0: float, lat0: float) -> void:
	s = s0
	s_start = s0
	d0 = lat0
	d = lat0
	line_d = 0.0
	d_target = 0.0
	v = 0.0
	band = 1.0
	racing = false
	finished = false
	drift_amt = 0.0
	drifting = false
	nitro_t = 0.0
	nitro_left = nitros_per_race
	_nitro_gap = 0.0
	mode = "line"
	mode_t = 0.0
	kick_cd = 3.0
	hits_taken = 0
	wobble_t = 0.0
	flinch_t = 0.0
	_pose_w = 0.0
	magnet_t = 0.0
	_prev_lead = 0.0
	exit_path = PackedVector2Array()
	_exit_i = 0
	if ring:
		ring.visible = false
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
	_fire_nitro(false)   # a launch burst off the line (free)


## A short line in the label (taunts, the ending).
func say(text: String, secs: float = TAUNT_S) -> void:
	label3d.text = rival_name + "\n" + text
	_taunt_left = secs


func flash_headlight(on: bool) -> void:
	if headlight:
		headlight.light_energy = 7.0 if on else 3.0


func wobbling() -> bool:
	return wobble_t > 0.0


# ---------------------------------------------------------------------------
# THE PLAYER'S KICK TARGET (PlayerBikeCombat duck typing)
# ---------------------------------------------------------------------------
func kickable() -> bool:
	return racing and not finished and wobble_t <= 0.0 and exit_path.size() < 2


func ground_pos() -> Vector3:
	return Vector3(global_position.x, floor_y, global_position.z)


## Kicks left before he wobbles (PlayerBikeCombat reads it: a counter that downs him is the finisher tier).
var hp: int:
	get:
		return maxi(1, KICKS_TO_WOBBLE - hits_taken)


## Seconds until his kick lands (the counter-kick window), -1 when he is not attacking.
func time_to_hit() -> float:
	if mode == "windup":
		return maxf(0.0, kick_windup - mode_t) + KICK_HIT_AT
	if mode == "kick" and not _hit_done:
		return maxf(0.0, KICK_HIT_AT - mode_t)
	return -1.0


## A player kick (away = unit direction from the player to him). "wobble" (his 3rd: he wobbles for WOBBLE_S), "hit" (a
## flinch, his wind-up cancelled) or "ignored". power 2 = a counter or a stick swing.
func take_kick(away: Vector2, power: int = 1) -> String:
	if not kickable():
		return "ignored"
	hits_taken += maxi(1, power)
	hits_total += 1
	flinch_t = FLINCH_S
	var r: Vector2 = course.right(s) if course else Vector2.RIGHT
	flinch_dir = signf(away.dot(r)) if absf(away.dot(r)) > 0.05 else 1.0
	d_target = clampf(line_d + flinch_dir * 1.2, -_edge(), _edge())
	if mode == "windup" or mode == "kick":
		_enter("recover")
	_cue("impact_medium", -3.0)
	if hits_taken >= KICKS_TO_WOBBLE:
		hits_taken = 0
		_wobble()
		return "crash"                    # PlayerBikeCombat's tier: the big one
	return "wobble"


## Kick assist (PlayerBikeCombat): pulled for `secs` toward MAGNET_LAT beside the player on `side` (-1 left, +1 right of
## his bike), level with him, so the kick connects.
func magnet(side_: int, secs: float) -> void:
	if not kickable():
		return
	magnet_side = -1.0 if side_ < 0 else 1.0
	magnet_t = secs
	magnets += 1


## PHẢN ĐÒN: worth 2 kicks.
func take_counter(away: Vector2) -> String:
	return take_kick(away, 2)


## The Q2 impact reaction: a flinch away from the hit (lean and line), harder on the heavier tiers.
func impact_react(tier: String, dir: Vector3, _opts: Dictionary = {}) -> String:
	flinch_t = FLINCH_S * (1.6 if tier == "finisher" else 1.0)
	if course:
		var r: Vector2 = course.right(s)
		var k: float = Vector2(dir.x, dir.z).dot(r)
		if absf(k) > 0.05:
			flinch_dir = signf(k)
	return "wobble" if wobble_t > 0.0 else "flinch"


func _wobble() -> void:
	wobble_t = WOBBLE_S
	wobbles += 1
	v *= WOBBLE_LURCH                     # the lurch: speed lost at once, then held down for WOBBLE_S
	if nitro_t > 0.0:
		nitro_t = 0.0
		if nitro_fx:
			nitro_fx.set_on(false)
	say(T_WOBBLE, 1.6)
	_cue("helmet_clonk", 0.0)
	wobbled.emit()


# ---------------------------------------------------------------------------
# PER FRAME (DriftDuel calls it)
# ---------------------------------------------------------------------------
## gap = his progress minus the player's (m): the taunts; the band factor and the player's p_s / p_d / p_v are set by
## DriftDuel before the call.
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
	if flinch_t > 0.0:
		flinch_t -= delta
	kick_cd -= delta
	_nitro_gap -= delta
	_think(delta)
	# speed
	var target: float = course.speed_at(s + v * 0.35, fight) * pace * band
	if nitro_t > 0.0:
		nitro_t -= delta
		target += NITRO_BONUS
		if nitro_t <= 0.0 and nitro_fx:
			nitro_fx.set_on(false)
	if wobble_t > 0.0:
		wobble_t -= delta
		target *= wobble_speed
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.15
			Impact.particles(self, "sparks", global_position + Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.6, 0.0) - global_transform.basis.z * 0.5, 0.7)
	var lead: float = s - p_s
	var leashed: bool = lead_cap > 0.0 and p_s > -900.0 and not finished and p_v >= LEASH_MIN_V
	if leashed and lead > lead_cap - LEAD_SOFT_M:
		# the leash: past lead_cap - LEAD_SOFT_M he rides no faster than the player, a bit slower near and past the cap
		var u2: float = clampf((lead - (lead_cap - LEAD_SOFT_M)) / LEAD_SOFT_M, 0.0, 1.0)
		target = minf(target, p_v * (lerpf(1.0, 0.9, u2) if lead <= lead_cap + 0.5 else PAST_CAP_K))
	if finished:
		target = 0.0
	v = move_toward(v, target, (ACCEL if target > v else BRAKE) * delta)
	s += v * delta
	var lead2: float = s - p_s
	if leashed and lead2 > lead_cap and _prev_lead <= lead_cap + 0.5 and lead2 - _prev_lead < 2.0:
		s = p_s + lead_cap                   # he stops at the cap (never pulled back from beyond it)
		v = minf(v, p_v)
		lead_clamps += 1
	_prev_lead = s - p_s
	if magnet_t > 0.0:
		magnet_t -= delta
		var to_d: float = clampf(p_d + magnet_side * MAGNET_LAT, -_edge() - 0.5, _edge() + 0.5)
		d = move_toward(d, to_d, MAGNET_SPEED * delta)
		line_d = d
		s = move_toward(s, p_s + clampf(s - p_s, -0.8, 0.8), MAGNET_SPEED * delta)
	# lateral line: blended from the grid offset, then his AI's line
	var u: float = clampf((s - s_start) / LAT_GRID_BLEND_M, 0.0, 1.0)
	var e: float = _edge()
	if mode != "windup" or mode_t < kick_windup - LOCK_S:
		line_d = move_toward(line_d, clampf(d_target, -e, e), lat_speed * delta)
	line_d = clampf(line_d, -e, e)
	d = lerpf(d0, line_d, smoothstep(0.0, 1.0, u)) if u < 1.0 else line_d
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
			smoke.emitting = now or wobble_t > 0.0
		if skid and skid.stream:
			if now:
				skid.play()
			else:
				skid.stop()
	if drifting:
		drift_time += delta
	_was_tight = tight if tight else (_was_tight and r < 60.0)
	var wob: float = 0.0
	var wob_lean: float = 0.0
	if wobble_t > 0.0:
		var k: float = clampf(wobble_t / WOBBLE_S, 0.0, 1.0)
		wob = sin(wobble_t * 17.0) * 0.3 * k
		wob_lean = sin(wobble_t * 11.0 + 0.7) * 0.4 * k
	var fl: float = flinch_dir * 0.35 * clampf(flinch_t / FLINCH_S, 0.0, 1.0)
	yaw = lerp_angle(yaw, ya + drift_dir * DRIFT_YAW_MAX * drift_amt + wob, minf(1.0, delta * 10.0))
	lean = lerpf(lean, clampf(turn * 3.0, -1.0, 1.0) * LEAN_MAX * clampf(v / 15.0, 0.0, 1.0) + wob_lean - fl, minf(1.0, delta * 9.0))
	if (_frame + 3) % RAY_EVERY == 0:
		var p: Vector2 = course.world(s, d)
		var y: Variant = _floor_ray(Vector3(p.x, floor_y, p.y), 3.0, 6.0, MAX_RISE)
		if y is float:
			floor_y = lerpf(floor_y, float(y), 0.6) if absf(float(y) - floor_y) < 1.5 else float(y)
	_place()
	_tick_ring()
	if engine and engine.playing and _blip_t < 0.0:
		var ratio: float = clampf(v / DriftCourse.RIVAL_V_TOP, 0.0, 1.2)
		engine.pitch_scale = lerpf(engine.pitch_scale, PlayerBike.exhaust_pitch(ratio, 1.0) if _owner_exhaust else 0.85 + ratio * 0.95, minf(1.0, delta * 8.0))
		engine.volume_db = lerpf(engine.volume_db, PlayerBike.exhaust_db(0.85) if _owner_exhaust else -2.0, minf(1.0, delta * 6.0))


func _edge() -> float:
	return maxf(0.5, course.half_width_at(s) - LAT_EDGE) if course else 3.0


## The aggression state machine: racing line, block, kick (wind-up, kick, recover); nitro bursts.
func _think(delta: float) -> void:
	mode_t += delta
	var rel_s: float = p_s - s                 # > 0: the player is ahead of him
	var rel_d: float = p_d - d                 # > 0: the player is on his right
	match mode:
		"windup":
			if mode_t >= kick_windup:
				_enter("kick")
				_hit_done = false
				kicks += 1
				_pose_w = 1.0
				_cue("whoosh_down", -1.0)
			return
		"kick":
			if not _hit_done and mode_t >= KICK_HIT_AT:
				_hit_done = true
				var lat: float = rel_d * kick_side
				var hit: bool = false
				if absf(rel_s) <= KICK_ALONG and lat >= KICK_LAT_MIN and lat <= KICK_LAT_MAX and kick_fn.is_valid():
					hit = bool(kick_fn.call(int(kick_side)))
				if hit:
					kick_hits += 1
				kicked_player.emit(int(kick_side), hit)
			if mode_t >= KICK_ACTIVE_S:
				_enter("recover")
			return
		"recover":
			if mode_t >= RECOVER_S:
				_enter("line")
			return
	_ai_t -= delta
	if _ai_t > 0.0:
		return
	_ai_t = AI_EVERY
	if wobble_t > 0.0 or finished:
		d_target = 0.0
		return
	if calm:
		mode = "line"
		d_target = lane
		_maybe_nitro(rel_s)
		return
	var straight: bool = course.radius_at(s + 10.0) > 50.0 and course.radius_at(s + 25.0) > 50.0
	# kick: the player alongside, his cooldown done
	if kick_cd <= 0.0 and absf(rel_s) < 2.4 and absf(rel_d) < 3.4 and p_v > 6.0 and course.corner_at(s) < 0:
		kick_cd = kick_cooldown * 0.5           # a failed roll waits a little
		if _rng.randf() < attack_chance:
			kick_side = 1.0 if rel_d >= 0.0 else -1.0
			d_target = p_d - kick_side * ATTACK_LAT
			kick_cd = kick_cooldown
			_enter("windup")
			rev_answer()
			flash_headlight(true)
			if _rng.randf() < 0.4:
				say(T_KICK, 1.0)
			return
	# block: the player close behind on a straight -> onto his line
	if straight and rel_s < -1.5 and rel_s > -BLOCK_M and p_v > 8.0:
		if mode != "block":
			blocks += 1
			if _rng.randf() < 0.3:
				say(T_BLOCK, 1.2)
		mode = "block"
		d_target = p_d
	else:
		mode = "line"
		d_target = 0.0
	_maybe_nitro(rel_s)


## Nitro: a long straight ahead, the player close or ahead (rel_s > -10), a charge left.
func _maybe_nitro(rel_s: float) -> void:
	if nitro_left > 0 and nitro_t <= 0.0 and _nitro_gap <= 0.0 and v > 10.0 and course.radius_at(s + 30.0) > 150.0 \
			and course.radius_at(s + 60.0) > 150.0 and rel_s > -10.0:
		_fire_nitro(true)


func _enter(m: String) -> void:
	mode = m
	mode_t = 0.0
	if m != "windup":
		flash_headlight(false)


## The telegraph ring: shown and pulsing during the wind-up, growing to full size at the kick.
func _tick_ring() -> void:
	if ring == null:
		return
	var on: bool = mode == "windup"
	ring.visible = on
	if on:
		var u: float = clampf(mode_t / maxf(kick_windup, 0.05), 0.0, 1.0)
		var sc: float = lerpf(0.7, 1.3, u)
		ring.scale = Vector3(sc, 0.15, sc)
		ring.position = Vector3(kick_side * 0.9, 0.06, 0.0)
		if _ring_mat:
			_ring_mat.emission_energy_multiplier = 3.0 + 4.0 * absf(sin(mode_t * 18.0))


func _place() -> void:
	var p: Vector2
	if exit_path.size() >= 2:
		p = _exit_p
	else:
		p = course.world(s, d)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), lean)
	global_transform = Transform3D(b, Vector3(p.x, floor_y, p.y))


func _fire_nitro(spend: bool) -> void:
	if spend:
		nitro_left -= 1
	nitro_t = NITRO_S
	nitros += 1
	_nitro_gap = NITRO_GAP_S
	if nitro_fx:
		nitro_fx.set_on(true)
	if whoosh and whoosh.stream and whoosh.is_inside_tree():
		whoosh.play()


func _taunts(delta: float, gap: float) -> void:
	if _taunt_left > 0.0:
		_taunt_left -= delta
		if _taunt_left <= 0.0:
			label3d.text = rival_name
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
		say(String(taunts[_rng.randi() % taunts.size()]))


## The kick leg over the ride clip (BikerEnemy's pose), after the rig's own update.
func _process(delta: float) -> void:
	if mode == "kick":
		_pose_w = BikeCombatData.kick_weight(mode_t, 0.05, 0.25, KICK_ACTIVE_S)
	elif _pose_w > 0.0:
		_pose_w = maxf(0.0, _pose_w - delta * 4.0)
	if _sk == null or standing or _pose_w <= 0.001:
		return
	if _anim and int(_anim.get("_lod_skip")) != 1:
		return
	CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.kick_pose(kick_side), _pose_w)


# ---------------------------------------------------------------------------
# COUNTDOWN SOUND
# ---------------------------------------------------------------------------
## Countdown answer (about 0.5 s after each count) and his kick wind-up: the owner's bike_rev at REV_PITCH, REV_DB_UNDER
## under the player's rev level, at his bike; else a blip of his exhaust loop.
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
		if not racing:
			_idle_engine()
		return
	engine.pitch_scale = PlayerBike.rev_blip_pitch(_blip_t, _idle_pitch()) * REV_PITCH
	engine.volume_db = rev_db()


# ---------------------------------------------------------------------------
# ENDING
# ---------------------------------------------------------------------------
## The ending: rides the exit path (map points) at exit_speed, then stops at its end.
func ride_exit(path: PackedVector2Array, spd: float = 7.0) -> void:
	exit_path = path
	exit_speed = spd
	_exit_i = 0
	racing = false
	mode = "line"
	if ring:
		ring.visible = false
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
