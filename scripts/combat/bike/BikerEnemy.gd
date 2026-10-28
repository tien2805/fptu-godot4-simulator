# File: res://scripts/combat/bike/BikerEnemy.gd
# One Bầy Sói biker of the Phase C bike chase (spec C-D1). Analytic, no physics body: a kinematic follower of a target
# point that BikeChase computes from the route (or the player's heading frame). The node itself is the bike (top_level,
# global transform = the bike on the road); the rider is a rigged CharacterBuilder body sitting on it ("ride" code clip,
# its AnimationPlayer kept inactive while riding so far LOD frames never flash the idle pose), with the wolf helmet
# (grey shell, cone ears, snout, red LED eyes) unless opts give a body / body_fn; a name label with short taunts.
# AI states (BikeChase assigns the role FRONT / LEFT / RIGHT / BACK and the attack tokens):
#   APPROACH (catch up to the slot) -> PACE (hold it) -> WINDUP (the telegraph: LED eyes flash, engine rev, HUD side
#   warning; swerves in; its last `lock` seconds fix the attack line in world space, so steering away dodges) -> KICK (hit
#   check through BikeChase.enemy_kick, on that fixed line) -> RECOVER; BRAKE (the FRONT biker brake-checks the player);
#   WOBBLE (kicked, then CRASH, or RECOVER while hp is left); CRASH (the rider flies in a comic somersault, bounces once and
#   slides; the bike slides on its side with sparks); DOWN (stars, no gore); LEAVE (after `lost` or the chase's end: rides
#   off ahead, or drops back at the route end, and is hidden once out of view); HOLD (ai off, tests: holds hold_along /
#   hold_lat beside the player).
# Day 2 kinds (spec 2026-10-27 D2X-4, numbers in BikeCombatData.KINDS), opts "kind":
#   rider    flank and kick (as above);
#   stick    a raised wooden stick; the wind-up raises it (whoosh on the swing); its line AND speed lock 0.35 s before the
#            swing, so braking or steering out dodges; a kick in the wind-up interrupts it (any kick wobbles);
#   thrower  two on one bike: paces THROW_AHEAD in front, the pillion (facing back) raises a helmet, throws it in an arc
#            at where the player will be in THROW_FLIGHT s (BikeChase.throw_helmet: the red road marker), then drops back
#            alongside for THROW_BACK_S (the kick window); a kick drops both;
#   heavy    a bigger, louder tuned bike, 3 kicks, a shoulder ram;
#   pickup   the gang's pickup truck: cannot be kicked; paces one lane over; horn + headlight flash for 1.0 s, then a
#            side ram whose line and speed lock 0.5 s before it (brake, speed up or steer out); PICKUP_STRIKES dodged rams,
#            its PICKUP_MAX_RAMS-th ram (or a car) and it loses it and hits a pole (cause "pole": a takedown);
#   police   (BikeChase.spawn_police) cannot be kicked, never crashes; rams a biker (crash "police") or the player (with an
#            attack token, like the gang: the cap and ATTACK_GAP_S hold).
# Traffic: every AVOID_EVERY frames it looks for the nearest car in its path and passes on the free side (within the
# road) or brakes behind it; touching a car anyway (a kicked biker wobbling into one) is a crash.
# opts: "kind", "label", "hp" (kicks to crash, default the kind's), "seed", "ai" (false = HOLD), "aggression" (0..1:
# shorter pacing), "eye_color", "paint", "body" (CharacterBuilder opts merged over the wolf rider look), "body_fn"
# (Callable(look) -> rigged Node3D; the wolf helmet is not added then), "traffic_proof" (perf tests: a car only scrapes it,
# so a measured window keeps every biker riding).
# Takedown tags: takedown_tag ("spin" | "air") set before a kick crash turns its cause into that takedown; air_y lifts the
# bike (the ramp jump, BikeChase).
# Q2 feel (plan 2026-10-29-q2-feel.md T3): a kick makes the bike veer on a decaying wobble curve (veering off further when
# it will crash) while the rider flails (BikeCombatData.flail_pose over the ride clip); a crash throws parts (both mirrors
# and the wolf helmet / a helmet shell) that fly, spin and bounce for PART_S; time_to_hit() (the counter-kick window),
# take_counter(away) (PHẢN ĐÒN: sent flying, crash cause "counter"); a stick rider downed by a kick drops his stick on the
# road (PlayerBikeCombat.drop_stick: the player can grab it).
class_name BikerEnemy
extends Node3D

enum St { APPROACH, PACE, WINDUP, KICK, RECOVER, BRAKE, WOBBLE, CRASH, DOWN, LEAVE, HOLD }
enum Role { BACK, LEFT, RIGHT, FRONT, THROW, SOLO }
const ST_NAMES: Array[String] = ["approach", "pace", "windup", "kick", "recover", "brake", "wobble", "crash", "down", "leave", "hold"]
const SEAT := Vector3(0.0, 0.32, 0.14)
const LABEL_Y: float = 2.25
const SPIN_PIVOT: float = 0.9            # the somersault turns about a point this high above the rider's root
## Kinds BikeChase gives the flank / front / back roles (the others keep their own slot).
const ROLE_KINDS: Array[String] = ["rider", "stick", "heavy"]

var ch: BikeChase
var kind: String = "rider"
var kp: Dictionary = {}
var label: String = ""
var hp: int = 1
var max_hp: int = 1
var ai: bool = true
var aggression: float = 0.5
var st: int = St.APPROACH
var st_t: float = 0.0
var role: int = Role.BACK
var back_k: int = 0                      # rank among the BACK reserves
var side: float = -1.0                   # LEFT -1 / RIGHT +1 (the side it kicks from)
var has_token: bool = false
var hit_done: bool = false
var pace_t: float = 1.5
var pos2: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var lean: float = 0.0
var floor_y: float = 0.0
var hold_along: float = 0.0
var hold_lat: float = 2.0
var crash_cause: String = ""
var kicked_by_player: bool = false
## Results of this biker's attacks on the player ("hit" | "miss" | "ignored"; last 16).
var results: Array[String] = []
var attacks: int = 0
var body: Node3D
var rider_landed: bool = false
var rider_v: Vector3 = Vector3.ZERO
var rider_pos: Vector3 = Vector3.ZERO
var rider_yaw: float = 0.0
var rider_flip: float = 0.0
var rider_spin: float = 0.0
var bike_v: Vector2 = Vector2.ZERO
var bike_spin: float = 0.0
var crash_roll: float = 1.0
var bounces: int = 0
var _flip_target: float = 0.0
var pose_w: float = 0.0
var avoid_car: int = -1                 # traffic vehicle being passed (-1: braking behind / none)
var avoid_side: float = 0.0
var avoid_need: float = 0.0
var avoid_r: Vector2 = Vector2.RIGHT
var _last_target: Vector2 = Vector2.ZERO
var avoid_cap: float = -1.0
var avoid_t: float = 0.0
var avoids: int = 0
var scrapes: int = 0
var gone: bool = false
## Spawned behind for an "ahead" slot (in view there): takes the FRONT role first.
var prefer_front: bool = false
var leave_along: float = 45.0
## Day 2: takedown tag of the next kick crash ("spin" | "air"), the ramp jump lift, LED flare, kind state.
var takedown_tag: String = ""
var traffic_proof: bool = false
var air_y: float = 0.0
var airborne: bool = false
var flare_t: float = 0.0
var strikes: int = 0                     # pickup: rams dodged
var fall_back_t: float = 0.0             # thrower: seconds left alongside after a throw
var throws: int = 0
var ram_target: BikerEnemy = null        # police: the biker it goes for (null = the player)
var _ram_t: float = 3.0
var _approach_t: float = 0.0
var stick: Node3D = null
var pillion: Node3D = null
var helmet_prop: Node3D = null
var _head_mat: StandardMaterial3D = null
var _siren: Array[Node3D] = []
var _line_locked: bool = false
var _line_o: Vector2 = Vector2.ZERO
var _line_t: Vector2 = Vector2(0.0, -1.0)
var _line_speed: bool = false
var _line_a0: float = 0.0
var _line_v: float = 0.0
var _line_clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sk: Skeleton3D = null
var _anim: Node = null
var _ap: AnimationPlayer = null
var _eye_mat: StandardMaterial3D
var _eye_col: Color = BikeCombatData.EYE_COL
var _label3d: Label3D
var _taunt_t: float = 5.0
var _taunt_left: float = 0.0
var _frame: int = 0
var _spark_t: float = 0.0
var _prev_vel: Vector2 = Vector2.ZERO
var _anchor: Node3D = null
var _frozen: bool = false
var _wob_sign: float = 1.0
## Q2: flying crash parts {"node", "v", "spin", "t", "floor"}, counters taken, sticks dropped.
var parts: Array[Dictionary] = []
var parts_thrown: int = 0
var countered_n: int = 0
var stick_dropped: bool = false


func setup(opts: Dictionary = {}) -> void:
	top_level = true
	kind = String(opts.get("kind", "rider"))
	if not BikeCombatData.KINDS.has(kind):
		kind = "rider"
	kp = BikeCombatData.kind(kind)
	label = String(opts.get("label", ""))
	max_hp = maxi(1, int(opts.get("hp", int(kp["hp"]))))
	hp = max_hp
	ai = bool(opts.get("ai", true))
	traffic_proof = bool(opts.get("traffic_proof", false))
	aggression = clampf(float(opts.get("aggression", 0.5)), 0.0, 1.0)
	_rng.seed = int(opts.get("seed", 1))
	_eye_col = opts.get("eye_color", BikeCombatData.EYE_COL)
	_taunt_t = _rng.randf_range(BikeCombatData.TAUNT_EVERY.x, BikeCombatData.TAUNT_EVERY.y)
	_ram_t = _rng.randf_range(1.2, 2.2)       # the police's first ram comes soon after they join
	if kind == "thrower":
		role = Role.THROW
	elif kind == "pickup" or kind == "police":
		role = Role.SOLO
	if kind == "pickup":
		_build_pickup(opts)
	else:
		_build_bike_and_rider(opts)
	Readability.rim(self, "enemy")   # Q3 rim on the bike and rider
	_label3d = Label3D.new()
	_label3d.name = "Name"
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.font_size = 40
	_label3d.pixel_size = 0.006
	_label3d.outline_size = 8
	_label3d.modulate = Color("#FFD0C8") if kind != "police" else Color("#CFE2FF")
	_label3d.position = Vector3(0.0, LABEL_Y + (0.6 if kind == "pickup" else 0.0), 0.0)
	_label3d.text = label
	_label3d.no_depth_test = false
	add_child(_label3d)
	process_priority = 11                  # the kick pose layer runs after the RigAnimator (10)


func _build_bike_and_rider(opts: Dictionary) -> void:
	var paint: Color = opts.get("paint", BikeCombatData.BIKE_PAINT if kind != "police" else RoamTraffic.POLICE_PAINT)
	if kind == "heavy" and not opts.has("paint"):
		paint = Color("#5A1E1E")
	PropBuilder.build_scooter(self, Vector3.ZERO, 0.0, paint, {"baked": true, "name": "Scooter", "traffic_lamps": true})
	var big: float = 1.25 if kind == "heavy" else 1.0
	var sc: Node3D = get_node_or_null("Scooter") as Node3D
	if sc and big != 1.0:
		sc.scale = Vector3.ONE * big
	var look: Dictionary = {"preset": "rider", "seed": _rng.randi(), "female": false, "body": "hoodie", "backpack": false,
		"glasses": false, "helmet_color": BikeCombatData.HELMET_COL,
		"shirt_color": BikeCombatData.JACKETS[_rng.randi() % BikeCombatData.JACKETS.size()], "clip": "ride"}
	if kind == "police":
		look = {"preset": "cop", "seed": _rng.randi(), "clip": "ride"}
	var bo: Dictionary = opts.get("body", {})
	for k: String in bo.keys():
		look[k] = bo[k]
	look["rigged"] = true
	look["name"] = "Rider"
	var bf: Callable = opts.get("body_fn", Callable())
	body = bf.call(look) if bf.is_valid() else CharacterBuilder.build(look)
	body.name = "Rider"
	body.position = Vector3(SEAT.x, SEAT.y * big, SEAT.z * big)
	if big != 1.0:
		body.scale *= 1.12
	add_child(body)
	CharacterBuilder.set_param(body, "ride_shoulder", 1.2)
	CharacterBuilder.set_param(body, "ride_elbow", 0.28)
	CharacterBuilder.set_param(body, "ride_lean", 0.4)
	if not bf.is_valid() and kind != "police":
		attach_wolf_helmet(body, _eye_col)
	_eye_mat = body.get_meta("wolf_eye_mat") as StandardMaterial3D if body.has_meta("wolf_eye_mat") else null
	_sk = body.get_meta("skeleton") as Skeleton3D if body.has_meta("skeleton") else null
	_anim = CharacterBuilder.get_animator(body)
	_ap = _anim.get("player") as AnimationPlayer if _anim else null
	if _ap:
		_ap.active = false                # the "ride" code clip owns every joint that matters while riding
	match kind:
		"stick":
			stick = Node3D.new()
			stick.name = "Stick"
			add_child(stick)
			var wood: StandardMaterial3D = CineFX._mat(Color("#7A5230"), 0.8)
			CineFX._cyl(stick, "Wood", 0.028, 0.036, 1.15, Vector3(0.0, 0.5, 0.0), wood)
			CineFX._cyl(stick, "Tape", 0.04, 0.04, 0.14, Vector3(0.0, 0.0, 0.0), CineFX._mat(Color("#1C1C1C"), 0.6))
			_stick_pose(0.0)
		"thrower":
			pillion = CharacterBuilder.build_baked_rider(self, Vector3(0.0, 0.36, 0.55),
				{"seed": _rng.randi(), "helmet_color": BikeCombatData.HELMET_DARK, "shirt_color": BikeCombatData.JACKETS[0]})
			pillion.name = "Pillion"
			pillion.rotation.y = PI          # faces back, toward the player behind
			helmet_prop = Node3D.new()
			helmet_prop.name = "HelmetProp"
			add_child(helmet_prop)
			CineFX._sphere(helmet_prop, "Shell", 0.16, Vector3.ZERO, CineFX._mat(BikeCombatData.HELMET_COL, 0.4), Vector3(1.0, 0.9, 1.1))
			CineFX._box(helmet_prop, "Visor", Vector3(0.2, 0.07, 0.04), Vector3(0.0, 0.0, 0.15), CineFX._glow_mat(BikeCombatData.EYE_COL, 2.0))
			helmet_prop.position = Vector3(0.0, 1.45, 0.95)
		"police":
			for k2: int in 2:
				var mi := MeshInstance3D.new()
				mi.name = "SirenR" if k2 == 0 else "SirenB"
				var bm := BoxMesh.new()
				bm.size = Vector3(0.09, 0.07, 0.09)
				mi.mesh = bm
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color("#FF2E3C") if k2 == 0 else Color("#2E6BFF")
				m.set_meta("vice_done", true)
				mi.material_override = m
				mi.position = Vector3(-0.06 + 0.12 * float(k2), 1.2, 0.75)
				add_child(mi)
				_siren.append(mi)


## The gang's pickup: a dark cab and open bed, wolf LED eyes on the grille, headlights that flash for the ram telegraph.
## `body` is an empty node (the driver sits behind the tinted glass).
func _build_pickup(opts: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "PickupModel"
	var pm: Material = PropBuilder.paint(opts.get("paint", Color("#30343A")))
	var dark: Material = PropBuilder.black_plastic()
	var glass: Material = PropBuilder.glass_dark()
	CharacterBuilder._box(root, Vector3(0.0, 0.7, 0.0), Vector3(1.9, 0.62, 5.2), pm)                 # chassis
	CharacterBuilder._box(root, Vector3(0.0, 1.25, -0.75), Vector3(1.84, 0.62, 1.9), pm)            # cab
	CharacterBuilder._box(root, Vector3(0.0, 1.3, -0.72), Vector3(1.86, 0.44, 1.7), glass)          # windows
	CharacterBuilder._box(root, Vector3(0.0, 1.06, -2.2), Vector3(1.86, 0.18, 0.9), pm)             # hood
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(root, Vector3(sx * 0.9, 1.18, 1.25), Vector3(0.08, 0.36, 2.5), pm)    # bed walls
		CharacterBuilder._box(root, Vector3(sx * 0.68, 0.98, 2.58), Vector3(0.3, 0.14, 0.05), PropBuilder.traffic_lamp("tail"))
		for z: float in [-1.7, 1.7]:
			PropBuilder.build_wheel(root, Vector3(sx * 0.86, 0.38, z), 0.38, 0.26, 5, Color("#8A9096"))
	CharacterBuilder._box(root, Vector3(0.0, 1.18, 2.52), Vector3(1.86, 0.36, 0.08), pm)            # tailgate
	CharacterBuilder._box(root, Vector3(0.0, 0.55, -2.62), Vector3(1.92, 0.26, 0.1), dark)          # bumper
	CharacterBuilder._box(root, Vector3(0.0, 1.62, -0.75), Vector3(1.5, 0.1, 0.2), dark)            # light bar
	PropBuilder.bake_into(self, root, "PickupModel", Vector3.ZERO)
	_head_mat = CineFX._glow_mat(Color(1.0, 0.95, 0.8), 0.8)
	for sx2: float in [-0.66, 0.66]:
		CineFX._box(self, "Headlight", Vector3(0.36, 0.16, 0.05), Vector3(sx2, 0.92, -2.63), _head_mat)
	var eye: StandardMaterial3D = CineFX._glow_mat(_eye_col, 3.0)
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx3: float in [-0.22, 0.22]:
		CineFX._sphere(self, "GrilleEye", 0.07, Vector3(sx3, 0.82, -2.64), eye)
	_eye_mat = eye
	body = Node3D.new()
	body.name = "Rider"
	body.position = Vector3(0.0, 0.9, -0.6)
	add_child(body)


## The Bầy Sói helmet on a rigged body's head pivot: cone ears, a snout with a nose, two red LED eyes (an emissive material
## of its own, kept as meta "wolf_eye_mat" for the telegraph flash). The rider preset's helmet shell is the grey dome.
static func attach_wolf_helmet(b: Node3D, eye_col: Color = BikeCombatData.EYE_COL) -> Node3D:
	var head: Node3D = CharacterBuilder.get_pivot(b, "head")
	if head == null:
		return null
	var w := Node3D.new()
	w.name = "WolfHelmet"
	head.add_child(w)
	var hs: float = maxf(head.scale.y, 0.01)
	w.position = Vector3(0.0, 0.1 / hs, 0.0)
	w.scale = Vector3.ONE / hs
	var shell: StandardMaterial3D = CineFX._mat(BikeCombatData.HELMET_COL, 0.5)
	var dark: StandardMaterial3D = CineFX._mat(BikeCombatData.HELMET_DARK, 0.6)
	for sx: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = CineFX._cyl(w, "Ear", 0.0, 0.04, 0.1, Vector3(sx * 0.075, 0.17, 0.01), dark)
		ear.rotation = Vector3(0.0, 0.0, -sx * 0.35)
	CineFX._box(w, "Snout", Vector3(0.09, 0.06, 0.1), Vector3(0.0, -0.005, -0.15), shell)
	CineFX._sphere(w, "Nose", 0.018, Vector3(0.0, 0.02, -0.203), CineFX._mat(Color("#141414"), 0.4))
	var eye: StandardMaterial3D = CineFX._glow_mat(eye_col, 3.0)
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx2: float in [-0.04, 0.04]:
		CineFX._sphere(w, "LedEye", 0.017, Vector3(sx2, 0.062, -0.128), eye)
	b.set_meta("wolf_eye_mat", eye)
	return w


## Put the biker on the road at pos (floor height y), facing yaw, moving at speed along its facing.
func place(pos: Vector3, face_yaw: float, speed: float) -> void:
	pos2 = Vector2(pos.x, pos.z)
	floor_y = pos.y
	yaw = face_yaw
	vel = Vector2(-sin(face_yaw), -cos(face_yaw)) * speed
	_prev_vel = vel
	_enter(St.APPROACH if ai else St.HOLD)
	_place_bike()


func state_name() -> String:
	return ST_NAMES[st]


func is_down() -> bool:
	return st == St.CRASH or st == St.DOWN


## Still part of the fight (not crashed, not riding off).
func is_active() -> bool:
	return not is_down() and st != St.LEAVE


## A player kick can land on it (the pickup and the police cannot be kicked).
func kickable() -> bool:
	return is_active() and not gone and bool(kp.get("kickable", true))


func is_attacking() -> bool:
	return st == St.WINDUP or st == St.KICK


func telegraphing() -> bool:
	return st == St.WINDUP


## Seconds until this biker's attack lands on its fixed timeline (WINDUP: the rest of it + ENEMY_HIT_AT; KICK before the
## hit: what is left of ENEMY_HIT_AT); INF when it is not attacking or its attack is not a strike beside the player (the
## thrower's helmet, the pickup's ram, the police).
func time_to_hit() -> float:
	if kind == "thrower" or kind == "pickup" or kind == "police" or ram_target != null:
		return INF
	if st == St.WINDUP:
		return maxf(0.0, float(kp["windup"]) - st_t) + BikeCombatData.ENEMY_HIT_AT
	if st == St.KICK and not hit_done:
		return maxf(0.0, BikeCombatData.ENEMY_HIT_AT - st_t)
	return INF


func riding() -> bool:
	return st != St.CRASH and st != St.DOWN


func ground_pos() -> Vector3:
	return Vector3(pos2.x, floor_y, pos2.y)


func speed() -> float:
	return vel.length()


## Half extents on the map plane (lateral, along): a bike or the pickup.
func half_extents() -> Vector2:
	return BikeCombatData.PICKUP_HALF if kind == "pickup" else Vector2(0.35, 0.95)


## LED eyes flaring for `secs` (the opening burst).
func flare(secs: float = BikeCombatData.FLARE_S) -> void:
	flare_t = secs


func _enter(s: int) -> void:
	if (st == St.WINDUP or st == St.KICK) and s != St.WINDUP and s != St.KICK:
		_release_token()
	if st == St.WINDUP and _eye_mat:
		_eye_mat.emission_energy_multiplier = 3.0
	if st == St.WINDUP and _head_mat:
		_head_mat.emission_energy_multiplier = 0.8
	st = s
	st_t = 0.0
	hit_done = false
	match s:
		St.PACE:
			pace_t = _rng.randf_range(BikeCombatData.PACE_MIN, BikeCombatData.PACE_MAX) * lerpf(1.25, 0.6, aggression)
		St.WINDUP:
			attacks += 1
			_line_locked = false
			if ch:
				match kind:
					"pickup":
						ch.cue("horn", ground_pos() + Vector3(0.0, 1.0, 0.0), 2.0, 0.62)
						ch.cue("engine_roar", ground_pos(), -2.0)
					"heavy":
						ch.cue("engine_roar", ground_pos(), 0.0)
					"police":
						ch.cue("horn", ground_pos() + Vector3(0.0, 1.0, 0.0), -2.0, 1.25)
					_:
						ch.cue("engine_roar", ground_pos(), -6.0)


func _release_token() -> void:
	if has_token and ch:
		ch.release_token(self)
	has_token = false


## The chase gave it an attack token: swerve in from its side (tests call it directly with ai off too).
func start_attack(from_side: float) -> void:
	side = signf(from_side) if from_side != 0.0 else side
	has_token = true
	_enter(St.WINDUP)


## A player kick (away = unit direction from the player to this biker on the map plane). "wobble" (hp left: it recovers),
## "crash" (it wobbles, then crashes) or "ignored". Airborne (the ramp jump): always a crash, tagged "air".
func take_kick(away: Vector2, power: int = 1) -> String:
	if not kickable() or st == St.WOBBLE:
		return "ignored"
	hp -= maxi(1, power)
	if airborne:
		hp = 0
		takedown_tag = "air"
	kicked_by_player = true
	_release_token()
	vel += away * float(kp.get("push", BikeCombatData.KICK_PUSH))
	_wob_sign = signf(away.dot(Vector2(-vel.y, vel.x))) if vel.length() > 0.5 else 1.0
	if _wob_sign == 0.0:
		_wob_sign = 1.0
	_enter(St.WOBBLE)
	if stick and hp <= 0 and stick.visible:
		_drop_stick(away)
	if ch:
		ch.cue("impact_medium", ground_pos() + Vector3(0.0, 1.0, 0.0))
	return "crash" if hp <= 0 else "wobble"


## Comic crash: the rider is thrown off in a somersault, the bike slides on its side (the pickup spins out and stops).
## cause "kick" | "traffic" | "pole" | "melon" | "barrier" | "police" | "nitro" | ...; a kick crash takes the takedown tag.
## The one place a crash is finalised: the Q3 rim leaves the bike and rider here (the Q2 flying parts are separate
## top-level meshes built without a rim; a retry spawns fresh, rimmed bikers).
func crash(cause: String, push: Vector2 = Vector2.ZERO) -> void:
	if is_down():
		return
	if kind == "police":
		return                             # the police never crash (no arrests, no wrecks)
	Readability.unrim(self)
	crash_cause = takedown_tag if (cause == "kick" and takedown_tag != "") else cause
	_release_token()
	bike_v = vel + push * 0.6
	_spark_t = 0.0
	airborne = false
	air_y = 0.0
	if kind == "pickup":
		rider_pos = body.global_position
		rider_landed = true
		rider_v = Vector3.ZERO
		bike_spin = _rng.randf_range(2.2, 3.4) * (1.0 if _rng.randf() < 0.5 else -1.0)
		crash_roll = 0.0
		pose_w = 0.0
		_label3d.visible = false
		if _head_mat:
			_head_mat.emission_energy_multiplier = 0.2
		_enter(St.CRASH)
		if ch:
			ch.cue("bin_crash", ground_pos(), 2.0)
			ch.cue("impact_heavy", ground_pos() + Vector3(0.0, 1.0, 0.0))
			ch.on_biker_crash(self)
		return
	var g: Transform3D = body.global_transform
	body.top_level = true
	body.global_transform = g
	if pillion:
		var pg: Transform3D = pillion.global_transform
		pillion.reparent(body)
		pillion.global_transform = pg
	if helmet_prop:
		helmet_prop.visible = false
	if stick:
		stick.visible = false
	rider_pos = g.origin
	rider_yaw = yaw
	rider_v = Vector3(vel.x * 0.85 + push.x, BikeCombatData.TUMBLE_UP, vel.y * 0.85 + push.y)
	rider_spin = BikeCombatData.TUMBLE_SPIN * (1.0 if _rng.randf() < 0.5 else -1.0)
	rider_flip = 0.0
	rider_landed = false
	bounces = 0
	bike_spin = _rng.randf_range(1.2, 2.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
	crash_roll = -1.0 if (push.dot(Vector2(cos(yaw), -sin(yaw))) >= 0.0) else 1.0   # falls toward the push (+roll = left)
	pose_w = 0.0
	if _ap:
		_ap.active = true
	CharacterBuilder.play(body, "knockdown")
	_label3d.visible = false
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 1.5
	_throw_parts(push)
	_enter(St.CRASH)
	if ch:
		ch.cue("helmet_clonk", ground_pos() + Vector3(0.0, 0.8, 0.0))
		ch.cue("bin_crash", ground_pos(), -3.0)
		ch.cue("slide_whistle", rider_pos + Vector3(0.0, 1.0, 0.0), -2.0)
		ch.on_biker_crash(self)


## PHẢN ĐÒN (PlayerBikeCombat's counter-kick), worth 2 kicks: a rider with 2 HP or less is sent flying at once (no wobble;
## a takedown, cause "counter"); a heavy takes the 2 and wobbles.
func take_counter(away: Vector2) -> String:
	if not kickable():
		return "ignored"
	countered_n += 1
	kicked_by_player = true
	if hp > 2:
		return take_kick(away, 2)            # a counter is worth 2 kicks: a heavy wobbles on
	hp = 0
	if stick and stick.visible:
		_drop_stick(away)
	crash("counter", away * BikeCombatData.COUNTER_PUSH)
	rider_v += Vector3(away.x * 2.0, 2.2, away.y * 2.0)   # higher and further than a plain crash
	return "crash"


## The kicked stick rider lets go of his stick: it lands on the road beside him (PlayerBikeCombat.drop_stick).
func _drop_stick(away: Vector2) -> void:
	stick.visible = false
	stick_dropped = true
	var pc: Object = ch.get("combat") if ch else null
	if pc != null and pc.has_method("drop_stick"):
		var at: Vector3 = Vector3(pos2.x, floor_y, pos2.y) + Vector3(away.x, 0.0, away.y) * 0.8
		pc.call("drop_stick", at, Vector3(vel.x, 0.0, vel.y) * 0.3)


## After the player lost: ride off ahead, then vanish.
func stand_down() -> void:
	if is_down() or st == St.LEAVE:
		return
	# the player still riding (or the route ending): they give up and drop back behind the camera; the player stopped
	# (knocked off): they ride on far ahead, out of view
	leave_along = 200.0 if ch == null or (ch.p_vel.length() <= 5.0 and ch.room_ahead(220.0)) else -70.0
	_enter(St.LEAVE)


# ---------------------------------------------------------------------------
# PER FRAME (called by BikeChase._physics_process)
# ---------------------------------------------------------------------------
func tick(delta: float) -> void:
	if gone:
		return
	_frame += 1
	st_t += delta
	match st:
		St.CRASH:
			_tumble(delta)
			_floor_ray(3)
			return
		St.DOWN:
			if not parts.is_empty():
				_tick_parts(delta)
			if not _frozen and st_t >= BikeCombatData.DOWN_FREEZE_S:
				_frozen = true
				body.process_mode = Node.PROCESS_MODE_DISABLED   # the Death pose holds; no animation cost
			return
	if flare_t > 0.0:
		flare_t -= delta
		if _eye_mat and st != St.WINDUP:
			_eye_mat.emission_energy_multiplier = 3.0 + 9.0 * clampf(flare_t / 0.4, 0.0, 1.0)
	if fall_back_t > 0.0:
		fall_back_t -= delta
	_think(delta)
	if st == St.CRASH:
		return
	_floor_ray(BikeCombatData.RAY_EVERY)
	_taunts(delta)
	if stick:
		_stick_pose(delta)
	if not _siren.is_empty():
		var on: bool = (Time.get_ticks_msec() / (90 if st == St.WINDUP else RoamTraffic.SIREN_MS)) % 2 == 0
		_siren[0].visible = on
		_siren[1].visible = not on
	if st != St.WOBBLE and st != St.LEAVE and ch.traffic and (_frame + get_index()) % BikeCombatData.AVOID_EVERY == 0:
		_avoid_check()
	if ch.traffic and st != St.LEAVE:
		_traffic_contact()


func _think(delta: float) -> void:
	var target: Vector2 = pos2
	var max_rel: float = BikeCombatData.CATCH_SPEED
	var gain: float = BikeCombatData.POS_GAIN
	var windup: float = float(kp["windup"])
	var atk: float = float(kp["atk"])
	if _line_locked and _line_speed:
		_line_clock += delta
	match st:
		St.HOLD:
			target = ch.target_at(hold_along, hold_lat)
		St.APPROACH:
			target = slot_target()
			if pos2.distance_to(target) < 3.0:
				_enter(St.PACE)
		St.PACE:
			target = slot_target()
			if kind == "police":
				target = _police_pace(delta)
			elif ai and st_t >= pace_t:
				if kind == "thrower" or kind == "pickup":
					if fall_back_t <= 0.0 and pos2.distance_to(target) < 4.0 and ch.request_token(self):
						start_attack(side)
					else:
						pace_t += 0.4
				elif (role == Role.LEFT or role == Role.RIGHT) and ch.request_token(self):
					start_attack(-1.0 if role == Role.LEFT else 1.0)
				elif role == Role.FRONT:
					_enter(St.BRAKE)
				else:
					pace_t += 0.4
		St.RECOVER:
			target = slot_target() if ai else ch.target_at(hold_along, hold_lat)
			var rec: float = BikeCombatData.PICKUP_RECOVER_S if kind == "pickup" else BikeCombatData.RECOVER_S
			if st_t >= rec:
				_enter(St.PACE if ai else St.HOLD)
		St.BRAKE:
			target = slot_target()
			if st_t >= BikeCombatData.BRAKE_S:
				_enter(St.PACE)
		St.WINDUP:
			var u: float = clampf(st_t / windup, 0.0, 1.0)
			var ui: float = clampf(u / BikeCombatData.WINDUP_IN, 0.0, 1.0)
			var lock: float = float(kp["lock"])
			if not _line_locked and lock > 0.0 and st_t >= windup - lock:
				_lock_line()
			if ram_target != null:
				target = _ram_point(1.5)
			elif kind == "thrower":
				target = slot_target()
				if helmet_prop:
					helmet_prop.position = Vector3(0.0, lerpf(1.45, 1.95, u), lerpf(0.95, 0.85, u))
			elif kind == "pickup":
				var wide: float = float(kp["slot_lat"]) + 0.2 * ui
				if _line_locked:   # committed: its speed is fixed, it holds its lane until the ram
					target = _on_line(BikeCombatData.SLOT_ALONG) + _line_right() * side * (wide - float(kp["swerve"]))
				else:
					target = ch.target_at(BikeCombatData.SLOT_ALONG, side * wide)
				if _head_mat:
					_head_mat.emission_energy_multiplier = 0.8 + 7.0 * float(int(st_t * 8.0) % 2)
			elif _line_locked:
				target = _on_line(BikeCombatData.SLOT_ALONG * 0.5)
			else:
				var sw: float = float(kp["swerve"])
				target = ch.target_at(BikeCombatData.SLOT_ALONG * 0.5, side * lerpf(float(kp["slot_lat"]), sw + (0.25 if kind != "stick" else 0.0), ui))
			gain = BikeCombatData.SWERVE_GAIN if kind != "pickup" else BikeCombatData.POS_GAIN * 1.4
			if kind == "rider" or kind == "heavy" or kind == "police":
				pose_w = 0.25 * u
			if _eye_mat:
				_eye_mat.emission_energy_multiplier = 3.0 + 7.0 * absf(sin(st_t * 24.0))
			if st_t >= windup:
				_enter(St.KICK)
				if kind == "stick" and ch:
					ch.cue("swish", ground_pos() + Vector3(0.0, 1.3, 0.0), 2.0)
		St.KICK:
			if kind == "thrower":
				target = slot_target()
				if not hit_done and st_t >= 0.1:
					hit_done = true
					throws += 1
					if helmet_prop:
						helmet_prop.visible = false
					ch.throw_helmet(self)
				if st_t >= atk:
					if helmet_prop:
						helmet_prop.visible = true
						helmet_prop.position = Vector3(0.0, 1.45, 0.95)
					fall_back_t = BikeCombatData.THROW_BACK_S
					_enter(St.RECOVER)
				_drive(delta, target, max_rel, gain)
				return
			if ram_target != null:
				target = _ram_point(0.2)
				gain = BikeCombatData.SWERVE_GAIN
				if not hit_done and st_t >= BikeCombatData.ENEMY_HIT_AT:
					hit_done = true
					if is_instance_valid(ram_target) and ram_target.is_active() and ram_target.pos2.distance_to(pos2) < 2.0:
						ram_target.crash("police", (ram_target.pos2 - pos2).normalized() * 3.0)
				if st_t >= atk:
					ram_target = null
					_enter(St.RECOVER)
			else:
				if not _line_locked:
					_lock_line()
				target = _on_line(0.0)
				gain = BikeCombatData.SWERVE_GAIN
				if kind == "rider" or kind == "heavy" or kind == "police":
					pose_w = BikeCombatData.kick_weight(st_t, 0.1, 0.25, atk)
				var check: bool = (st_t >= BikeCombatData.ENEMY_HIT_AT) if kind != "pickup" else (st_t >= 0.12)
				if not hit_done and check:
					var res: String = ch.enemy_kick(self)
					if kind != "pickup" or res == "hit" or st_t >= atk - 0.05:
						hit_done = true
						results.append(res)
						if results.size() > 16:
							results.pop_front()
						if kind == "pickup" and res != "hit":
							strikes += 1
						elif kind == "pickup":
							if attacks >= BikeCombatData.PICKUP_MAX_RAMS:
								crash("pole", ch.p_right * side * 3.0 + vel.normalized() * 2.0)
								return
							_enter(St.RECOVER)   # it connected: it bounces off instead of driving through the bike
							_drive(delta, slot_target(), max_rel, BikeCombatData.POS_GAIN)
							return
				if st_t >= atk:
					pose_w = 0.0
					if kind == "pickup" and (strikes >= BikeCombatData.PICKUP_STRIKES or attacks >= BikeCombatData.PICKUP_MAX_RAMS):
						crash("pole", ch.p_right * side * -3.0 + vel.normalized() * 2.0)
						return
					_enter(St.RECOVER)
		St.WOBBLE:
			target = pos2 + vel * 0.5
			vel = vel * maxf(0.0, 1.0 - 0.8 * delta)
			if st_t >= float(kp.get("wobble", BikeCombatData.WOBBLE_S)):
				if hp <= 0:
					crash("kick", vel.normalized() * 1.5 if vel.length() > 0.1 else Vector2.ZERO)
					return
				_enter(St.RECOVER)
		St.LEAVE:
			target = ch.target_at(leave_along, side * 2.5)
			max_rel = BikeCombatData.LEAVE_SPEED
			if (st_t >= BikeCombatData.LEAVE_S and not ch.in_view(ground_pos() + Vector3(0.0, 1.0, 0.0))) or st_t >= BikeCombatData.LEAVE_MAX_S:
				gone = true
				visible = false              # out of view: no pop
				return
	if st != St.KICK and st != St.WINDUP and pose_w > 0.0:
		pose_w = maxf(0.0, pose_w - delta * 4.0)
	if avoid_t > 0.0:
		avoid_t -= delta
		if avoid_car >= 0:
			var c: RoamTraffic.Vehicle = ch.traffic.vehicles[avoid_car]
			if c.active:
				var lt: float = (target - c.pos).dot(avoid_r)
				if avoid_side < 0.0 and lt > -avoid_need:
					target += avoid_r * (-avoid_need - lt)
				elif avoid_side > 0.0 and lt < avoid_need:
					target += avoid_r * (avoid_need - lt)
				gain = maxf(gain, BikeCombatData.AVOID_GAIN)
	else:
		avoid_cap = -1.0
		avoid_car = -1
	_last_target = target
	if st == St.WOBBLE:
		# Q2: a decaying wobble curve; a bike that will crash veers off more and more toward its fall
		pos2 += vel * delta
		var wl: float = maxf(float(kp.get("wobble", BikeCombatData.WOBBLE_S)), 0.05)
		var u: float = clampf(st_t / wl, 0.0, 1.0)
		var env: float = 1.0 - 0.55 * u
		var veer: float = BikeCombatData.WOBBLE_VEER * u * (1.0 if hp <= 0 else 0.0)
		yaw += (sin(st_t * 20.0) * 2.6 * env + veer) * delta * _wob_sign
		lean = sin(st_t * 16.0) * 0.5 * env + (0.35 * u * _wob_sign if hp <= 0 else 0.0)
		_place_bike()
		return
	_drive(delta, target, max_rel, gain)


## Kinematic follower: the player's velocity fed forward plus a pull to the target (gain 1/s), capped relative to the
## player and in absolute speed (the kind's top), reached with an acceleration limit.
func _drive(delta: float, target: Vector2, max_rel: float, gain: float) -> void:
	var pv: Vector2 = ch.p_vel
	var v_des: Vector2 = pv + (target - pos2) * gain
	var rel: Vector2 = v_des - pv
	if rel.length() > max_rel:
		v_des = pv + rel.normalized() * max_rel
	if avoid_cap >= 0.0:
		var f: Vector2 = vel.normalized() if vel.length() > 1.0 else ch.p_fwd
		var along: float = v_des.dot(f)
		if along > avoid_cap:
			v_des -= f * (along - avoid_cap)
	var sp: float = v_des.length()
	var top: float = minf(float(kp.get("top", BikeCombatData.MAX_SPEED)), BikeCombatData.MAX_SPEED + 1.0) if st != St.LEAVE else BikeCombatData.MAX_SPEED
	if sp > top:
		v_des *= top / sp
	vel = vel.move_toward(v_des, BikeCombatData.ACCEL * delta)
	pos2 += vel * delta
	var spd: float = vel.length()
	if spd > 1.0:
		yaw = lerp_angle(yaw, atan2(-vel.x, -vel.y), minf(1.0, delta * 10.0))
	var acc: Vector2 = (vel - _prev_vel) / maxf(delta, 1e-3)
	_prev_vel = vel
	var right := Vector2(cos(yaw), -sin(yaw))
	var lean_max: float = 0.45 if kind != "pickup" else 0.06
	lean = lerpf(lean, clampf(-acc.dot(right) * 0.05, -lean_max, lean_max), minf(1.0, delta * 8.0))
	_place_bike()


## Slot of its role around the player (BikeChase.target_at clamps it to the road on the route).
func slot_target() -> Vector2:
	match kind:
		"thrower":
			if fall_back_t > 0.0:
				return ch.target_at(BikeCombatData.SLOT_ALONG, side * 2.2)
			return ch.target_at(BikeCombatData.THROW_AHEAD, side * float(kp["slot_lat"]))
		"pickup":
			var want: float = side * float(kp["slot_lat"])
			if ch.lat_room(side) < 2.3:
				return ch.target_at(-8.0, want)   # no room on its side: hang back in that lane
			return ch.target_at(BikeCombatData.SLOT_ALONG, want)
		"police":
			return ch.target_at(-BikeCombatData.POLICE_BEHIND, side * 1.5)
	match role:
		Role.LEFT, Role.RIGHT:
			return ch.target_at(BikeCombatData.SLOT_ALONG, side * float(kp["slot_lat"]))
		Role.FRONT:
			var along: float = BikeCombatData.FRONT_ALONG
			if st == St.BRAKE:
				var u: float = clampf(st_t / BikeCombatData.BRAKE_S, 0.0, 1.0)
				along = lerpf(BikeCombatData.FRONT_ALONG, BikeCombatData.BRAKE_ALONG, sin(u * PI))
			return ch.target_at(along, 0.0)
	var lat: float = BikeCombatData.BACK_LAT if back_k % 2 == 0 else -BikeCombatData.BACK_LAT
	return ch.target_at(-BikeCombatData.BACK_ALONG - 3.0 * float(back_k / 2), lat)


## Police pacing: behind the pack; every POLICE_RAM_EVERY it picks a biker (or the player) and closes in beside it.
func _police_pace(delta: float) -> Vector2:
	if ram_target != null and (not is_instance_valid(ram_target) or not ram_target.is_active()):
		ram_target = null
		_approach_t = 0.0
	if ram_target == null and _approach_t <= 0.0:
		_ram_t -= delta
		if _ram_t <= 0.0 and ai:
			_ram_t = _rng.randf_range(1.2, 2.2)       # the police's first ram comes soon after they join
			var best: BikerEnemy = null
			var bd: float = 30.0
			for b: Variant in ch.bikers:
				var e: BikerEnemy = b as BikerEnemy
				if e != null and is_instance_valid(e) and e.is_active() and e.kind != "pickup" and e.pos2.distance_to(pos2) < bd:
					bd = e.pos2.distance_to(pos2)
					best = e
			var at_player: bool = ch.police_player_ok() and (best == null or _rng.randf() < BikeCombatData.POLICE_PLAYER_CHANCE)
			if best != null and not at_player:
				ram_target = best
			elif at_player:
				ch.police_player_t = BikeCombatData.POLICE_PLAYER_GAP_S
				side = 1.0 if (pos2 - ch.p_pos).dot(ch.p_right) >= 0.0 else -1.0
			else:
				return slot_target()          # nobody to ram this time
			_approach_t = BikeCombatData.POLICE_APPROACH_S
		return slot_target()
	_approach_t -= delta
	var p: Vector2
	if ram_target != null:
		p = _ram_point(1.5)
	else:
		p = ch.target_at(BikeCombatData.SLOT_ALONG, side * float(kp["slot_lat"]))
	if pos2.distance_to(p) < 1.2:
		if ram_target == null:
			if not ch.request_token(self):   # at the player: within the attacker cap and ATTACK_GAP_S like the gang
				return p                      # (keeps pacing beside him until a token frees up or the approach times out)
			has_token = true
		_approach_t = 0.0
		_enter(St.WINDUP)
	elif _approach_t <= 0.0:
		ram_target = null
	return p


## Point beside the police's target biker at `lat` m on the police's side (its own frame).
func _ram_point(lat: float) -> Vector2:
	if ram_target == null or not is_instance_valid(ram_target):
		return slot_target()
	var f: Vector2 = ram_target.vel.normalized() if ram_target.vel.length() > 1.0 else ch.p_fwd
	var r := Vector2(-f.y, f.x)
	var sd: float = signf((pos2 - ram_target.pos2).dot(r))
	if sd == 0.0:
		sd = 1.0
	return ram_target.pos2 + r * sd * lat


## Fix the attack line in world space: through the point `swerve` m beside the player now, along his travel direction
## (lock_speed kinds also fix the speed along it: the attacker no longer follows the player's braking).
func _lock_line() -> void:
	_line_locked = true
	_line_o = ch.target_at(0.0, side * float(kp["swerve"]))
	_line_t = ch.p_fwd
	_line_speed = bool(kp.get("lock_speed", false))
	_line_a0 = (ch.p_pos - _line_o).dot(_line_t)
	_line_v = ch.p_vel.dot(_line_t)
	_line_clock = 0.0


## Right-hand normal of the fixed attack line (= the player's right at the lock).
func _line_right() -> Vector2:
	return Vector2(-_line_t.y, _line_t.x)


## Point on the fixed attack line level with the player (+ along metres ahead); speed-locked kinds advance at the speed
## of the lock instead.
func _on_line(along: float) -> Vector2:
	if _line_speed:
		return _line_o + _line_t * (_line_a0 + _line_v * _line_clock + along)
	return _line_o + _line_t * ((ch.p_pos - _line_o).dot(_line_t) + along)


func _place_bike() -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), lean)
	global_transform = Transform3D(b, Vector3(pos2.x, floor_y + air_y, pos2.y))


## The stick: raised over the rider's shoulder on the player's side; the wind-up cocks it back, the swing sweeps it flat
## toward the player.
func _stick_pose(_d: float) -> void:
	var px: float = -side                  # the player is on this side of the biker (local x)
	stick.position = Vector3(px * 0.3, 1.2, 0.05)
	var rx: float = 0.3
	var tilt: float = -0.25
	if st == St.WINDUP:
		var u: float = clampf(st_t / float(kp["windup"]), 0.0, 1.0)
		rx = lerpf(0.3, 0.75, u)
		tilt = -0.25 - 0.2 * u + 0.06 * sin(st_t * 40.0)
	elif st == St.KICK:
		var k: float = clampf(st_t / 0.15, 0.0, 1.0)
		rx = lerpf(0.75, 0.0, k)
		tilt = lerpf(-0.45, 1.45, k)
	stick.rotation = Vector3(rx, 0.0, -px * tilt)


func _floor_ray(every: int) -> void:
	if (_frame + get_index()) % every != 0 or not is_inside_tree():
		return
	var y: Variant = ch.floor_at(Vector3(pos2.x, floor_y, pos2.y))
	if y is float:
		floor_y = lerpf(floor_y, float(y), 0.6) if absf(float(y) - floor_y) < 1.5 else float(y)


func _taunts(delta: float) -> void:
	if _taunt_left > 0.0:
		_taunt_left -= delta
		if _taunt_left <= 0.0:
			_label3d.text = label
		return
	if st != St.PACE or kind == "police":
		return
	_taunt_t -= delta
	if _taunt_t <= 0.0:
		_taunt_t = _rng.randf_range(BikeCombatData.TAUNT_EVERY.x, BikeCombatData.TAUNT_EVERY.y)
		_taunt_left = BikeCombatData.TAUNT_S
		var line: String = BikeCombatData.TAUNTS[_rng.randi() % BikeCombatData.TAUNTS.size()]
		_label3d.text = line if label == "" else label + "\n" + line


## Nearest car in its path within the look-ahead (its path: from where it is to where its target is, laterally): pass on
## the free side (road room on the route, not through the player's bike) or brake behind it.
func _avoid_check() -> void:
	var f: Vector2 = vel.normalized() if vel.length() > 2.0 else ch.p_fwd
	var r := Vector2(-f.y, f.x)
	var sp: float = vel.dot(f)
	var tl: float = (_last_target - pos2).dot(r)
	var lo: float = minf(0.0, tl)
	var hi: float = maxf(0.0, tl)
	var hw: float = half_extents().x
	var best_along: float = INF
	var best_lat: float = 0.0
	var best_need: float = 0.0
	var best_v: float = 0.0
	var best_i: int = -1
	for v: Variant in ch.traffic.vehicles:
		var c: RoamTraffic.Vehicle = v
		if not c.active:
			continue
		var rel: Vector2 = c.pos - pos2
		if rel.length_squared() > 1600.0:
			continue
		var along: float = rel.dot(f)
		var v_along: float = c.speed * c.dir.dot(f)
		var look: float = BikeCombatData.AVOID_LOOK + maxf(sp - v_along, 0.0) * BikeCombatData.AVOID_T
		if along < -(c.half_len + 1.2) or along > look or along >= best_along:
			continue
		var ext: float = c.half_w * absf(c.dir.dot(f)) + c.half_len * absf(c.dir.cross(f))
		var lat: float = rel.dot(r)
		var gap: float = 0.0 if (lat >= lo and lat <= hi) else minf(absf(lat - lo), absf(lat - hi))
		if gap > ext + 0.75 + hw - 0.35:
			continue
		best_along = along
		best_lat = lat
		best_need = ext + 0.65 + hw
		best_v = v_along
		best_i = c.idx
	if best_i < 0:
		return
	# already passing this car: keep the side while it still has room (a little tolerance, so the choice never flip-flops)
	if avoid_car == best_i and avoid_t > 0.0 and avoid_side != 0.0:
		var keep: Vector2 = pos2 + r * (best_lat + avoid_side * best_need) + f * maxf(best_along, 0.0)
		if ch.on_road(keep, 0.7):
			avoid_need = best_need
			avoid_r = r
			avoid_t = BikeCombatData.AVOID_HOLD
			return
	# pass on the side nearer to where it is heading; the other side if that one leaves the road; else brake behind
	var first: float = 1.0 if absf(best_lat + best_need - tl) < absf(best_lat - best_need - tl) else -1.0
	var oncoming: bool = best_v < -1.0     # braking does not help: squeeze past, even beside the player
	for k: int in 2:
		var sd: float = first if k == 0 else -first
		var p: Vector2 = pos2 + r * (best_lat + sd * best_need) + f * maxf(best_along, 0.0)
		if ch.on_road(p) and (oncoming or not ch.near_player(p, best_v)):
			avoid_car = best_i
			avoid_side = sd
			avoid_need = best_need
			avoid_r = r
			avoid_t = BikeCombatData.AVOID_HOLD
			avoid_cap = -1.0
			avoids += 1
			return
	avoid_car = -1
	avoid_cap = maxf(best_v - 0.5, 0.0)
	avoid_t = BikeCombatData.AVOID_HOLD
	avoids += 1


## Touching a car: a crash when it hits it hard (faster than GRAZE_SPEED into it) or while wobbling from a kick; a slow
## scrape only pushes it out along the shallower side and takes the speed into the car away. The police only scrape.
func _traffic_contact() -> void:
	var he: Vector2 = half_extents()
	for v: Variant in ch.traffic.vehicles:
		var c: RoamTraffic.Vehicle = v
		if not c.active:
			continue
		var rel: Vector2 = pos2 - c.pos
		if rel.length_squared() > 49.0:
			continue
		var cr := Vector2(-c.dir.y, c.dir.x)
		var ra: float = rel.dot(c.dir)
		var rl: float = rel.dot(cr)
		# this biker's own box projected on the car's axes (a bike is long and thin, the pickup big)
		var f := Vector2(-sin(yaw), -cos(yaw))
		var ext_a: float = he.y * absf(f.dot(c.dir)) + he.x * absf(f.cross(c.dir))
		var ext_l: float = he.y * absf(f.dot(cr)) + he.x * absf(f.cross(cr))
		var pa: float = c.half_len + minf(ext_a, 0.55 if kind != "pickup" else ext_a) - absf(ra)
		var pl: float = c.half_w + minf(ext_l, 0.28 if kind != "pickup" else ext_l) - absf(rl)
		if pa <= 0.0 or pl <= 0.0:
			continue
		var n: Vector2 = cr * (1.0 if rl >= 0.0 else -1.0) if pl < pa else c.dir * (1.0 if ra >= 0.0 else -1.0)
		var into: float = -(vel - c.dir * c.speed).dot(n)
		if kind != "police" and not traffic_proof and (st == St.WOBBLE or into > BikeCombatData.GRAZE_SPEED):
			crash("traffic", n * 3.0 + c.dir * c.speed * 0.5)
			return
		pos2 += n * minf(pl, pa)
		if into > 0.0:
			vel += n * into
		scrapes += 1


# ---------------------------------------------------------------------------
# CRASH
# ---------------------------------------------------------------------------
func _tumble(delta: float) -> void:
	if not parts.is_empty():
		_tick_parts(delta)
	var bs: float = bike_v.length()
	if bs > 0.0:
		bike_v = bike_v.move_toward(Vector2.ZERO, BikeCombatData.BIKE_DECEL * delta)
		pos2 += bike_v * delta
		_spark_t -= delta
		if _spark_t <= 0.0 and bs > 3.0 and ch:
			_spark_t = BikeCombatData.SPARK_EVERY
			ch.sparks(Vector3(pos2.x, floor_y + 0.1, pos2.y), Vector3(-bike_v.x, 0.4, -bike_v.y).normalized())
	yaw += bike_spin * delta
	bike_spin = move_toward(bike_spin, 0.0, 2.5 * delta)
	lean = move_toward(lean, crash_roll * BikeCombatData.BIKE_ROLL, 6.0 * delta)
	_place_bike()
	if kind == "pickup":
		if bike_v.length() < 0.3 and absf(bike_spin) < 0.3:
			_enter(St.DOWN)
			_add_stars(Vector3(pos2.x, floor_y + 0.4, pos2.y))
		return
	if not rider_landed:
		rider_v.y -= BikeCombatData.GRAVITY * delta
	rider_pos += rider_v * delta
	if rider_pos.y <= floor_y and rider_v.y <= 0.0:
		rider_pos.y = floor_y
		if bounces == 0 and absf(rider_v.y) > 2.0:
			rider_v.y = -rider_v.y * BikeCombatData.BOUNCE
			bounces += 1
			if ch:
				ch.cue("body_fall", rider_pos + Vector3(0.0, 0.3, 0.0))
		else:
			rider_v.y = 0.0
			rider_landed = true
			_flip_target = roundf(rider_flip / TAU) * TAU
	if rider_landed:
		var h := Vector2(rider_v.x, rider_v.z).move_toward(Vector2.ZERO, BikeCombatData.RIDER_DECEL * delta)
		rider_v = Vector3(h.x, 0.0, h.y)
		rider_flip = move_toward(rider_flip, _flip_target, 12.0 * delta)
	else:
		rider_flip += rider_spin * delta
	var piv := Vector3(0.0, SPIN_PIVOT, 0.0)
	var rb := Basis(Vector3.UP, rider_yaw) * Basis(Vector3.RIGHT, rider_flip)
	body.global_transform = Transform3D(rb, rider_pos + piv) * Transform3D(Basis.IDENTITY, -piv)
	if rider_landed and rider_v.length() < 0.3 and bike_v.length() < 0.3 and rider_flip == _flip_target:
		_enter(St.DOWN)
		_add_stars(rider_pos)
		if ch:
			ch.cue("groan", rider_pos + Vector3(0.0, 0.4, 0.0), -3.0)


func _add_stars(at: Vector3) -> void:
	_anchor = Node3D.new()
	_anchor.name = "StarsAnchor"
	_anchor.top_level = true
	add_child(_anchor)
	_anchor.global_position = at + Vector3(0.0, -1.55, 0.0)   # WeaponFX stars ring 2.18 m above: ~0.6 m over the body
	if ch:
		ch.stars(_anchor, BikeCombatData.STARS_S)


## Distance the rider ended up from its bike (tests: the rider is thrown clear).
func rider_gap() -> float:
	return Vector2(rider_pos.x - pos2.x, rider_pos.z - pos2.y).length()


# ---------------------------------------------------------------------------
# KICK POSE (after the RigAnimator; only on frames it ran, so the layer never compounds)
# ---------------------------------------------------------------------------
func _process(_d: float) -> void:
	if _sk == null or not riding():
		return
	if st == St.WOBBLE:
		if _anim == null or int(_anim.get("_lod_skip")) == 1:
			CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.flail_pose(st_t), clampf(st_t * 10.0, 0.0, 1.0))   # Q2: flailing
		return
	if pose_w <= 0.001:
		return
	if _anim and int(_anim.get("_lod_skip")) != 1:
		return
	CharacterBuilder._apply_bone_pose(_sk, BikeCombatData.kick_pose(-side), pose_w)


# ---------------------------------------------------------------------------
# Q2: CRASH PARTS
# ---------------------------------------------------------------------------
## Both mirrors snap off the handlebar and the helmet (the wolf helmet, else a plain shell) flies off the rider: each a
## small top-level mesh with its own velocity, spin and one bounce, freed after PART_S.
func _throw_parts(push: Vector2) -> void:
	var b: Basis = global_transform.basis
	var fv := Vector3(vel.x, 0.0, vel.y) * 0.6 + Vector3(push.x, 0.0, push.y) * 0.5
	var mirror_mat: StandardMaterial3D = CineFX._mat(Color("#1C1F24"), 0.4)
	var glass: StandardMaterial3D = CineFX._mat(Color("#AFC6D8"), 0.1)
	for sx: float in [-1.0, 1.0]:
		var m := Node3D.new()
		m.name = "Mirror"
		CineFX._cyl(m, "Stalk", 0.01, 0.01, 0.16, Vector3(0.0, -0.08, 0.0), mirror_mat)
		CineFX._box(m, "Glass", Vector3(0.12, 0.07, 0.02), Vector3(0.0, 0.02, 0.0), glass)
		var at: Vector3 = global_position + b * Vector3(sx * 0.3, 1.08, -0.45)
		_add_part(m, at, fv + b * Vector3(sx * 2.4, 3.2, 0.0), Vector3(9.0, 4.0 * sx, 7.0))
	var helmet: Node3D = body.find_child("WolfHelmet", true, false) as Node3D if body else null
	var hat_at: Vector3 = body.global_position + Vector3(0.0, 1.55, 0.0) if body else global_position + Vector3(0.0, 1.6, 0.0)
	if helmet != null:
		hat_at = helmet.global_position
		helmet.visible = false
	var h := Node3D.new()
	h.name = "FlyingHelmet"
	CineFX._sphere(h, "Shell", 0.15, Vector3.ZERO, CineFX._mat(BikeCombatData.HELMET_COL, 0.5), Vector3(1.0, 0.85, 1.1))
	if helmet != null:
		for sx2: float in [-1.0, 1.0]:
			CineFX._cyl(h, "Ear", 0.0, 0.04, 0.1, Vector3(sx2 * 0.075, 0.15, 0.01), CineFX._mat(BikeCombatData.HELMET_DARK, 0.6))
	_add_part(h, hat_at, fv * 1.1 + Vector3(0.0, 4.6, 0.0), Vector3(11.0, 6.0, -5.0))


func _add_part(n: Node3D, at: Vector3, v: Vector3, spin: Vector3) -> void:
	n.top_level = true
	add_child(n)
	n.global_position = at
	parts.append({"node": n, "v": v, "spin": spin, "t": 0.0, "floor": floor_y + 0.06})
	parts_thrown += 1


func _tick_parts(delta: float) -> void:
	for i: int in range(parts.size() - 1, -1, -1):
		var e: Dictionary = parts[i]
		var n: Node3D = e["node"] if is_instance_valid(e["node"]) else null
		e["t"] = float(e["t"]) + delta
		if n == null or float(e["t"]) >= BikeCombatData.PART_S:
			if n:
				n.queue_free()
			parts.remove_at(i)
			continue
		var v: Vector3 = e["v"]
		v.y -= BikeCombatData.GRAVITY * delta
		var p: Vector3 = n.global_position + v * delta
		if p.y < float(e["floor"]) and v.y < 0.0:
			p.y = float(e["floor"])
			v = Vector3(v.x * 0.55, -v.y * 0.3, v.z * 0.55)
			e["spin"] = (e["spin"] as Vector3) * 0.5
		e["v"] = v
		n.global_position = p
		n.rotation += (e["spin"] as Vector3) * delta
