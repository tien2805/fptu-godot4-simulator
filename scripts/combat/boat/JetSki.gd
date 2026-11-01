# File: res://scripts/combat/boat/JetSki.gd
# A Bầy Sói jet ski in the Day 6 canal chase (plan 2026-11-01-w4-day6.md T4): route space like PlayerBoat (s, d, v). BoatChase
# spawns it behind the boat (out of the chase camera's view) and calls think(dt, boat) on the chase clock.
#   mode  approach  gun it to its flank slot beside the boat (side -1 left / +1 right, `slot` staggers two on one side);
#                   further than BoatData.SKI_LEASH behind it races to catch up (the leash)
#         flank     hold the slot (BoatData.SKI_FLANK_D: out of kick reach); after a random wait it asks BoatChase for the
#                   attack token (one telegraph at a time)
#         tell      the telegraph: a red ring on the water around it and a red "!" over the rider for BoatData.ski_tell(),
#                   closing in to SKI_TELL_D beside the boat (in kick reach: the kick's window)
#         ram       the dash across into the boat; returns 1 from think() when it connects (BoatChase: damage + shove)
#         recover   bounced off / missed: drifts back out, then approaches again
#         ko        kicked (or crashed into a net, the pier wall, the barge): the ski flips and slides, the rider flies off
#                   into the water with a splash; `gone` after KO_S
# Look: the dark jet ski with the amber stripe (CinePropsD6), a Bầy Sói rider (StoryCast "bay_soi": wolf helmet) on the
# "ride" clip, a small bow spray.
class_name JetSki
extends Node3D

const SEAT := Vector3(0.0, -0.1, 0.3)     # the "ride" clip's hips 0.62 m over the origin, on the seat (0.52)
const KO_S: float = 2.6
const RECOVER_S: float = 1.3
const RAM_MAX_S: float = 0.7

var level: LairCanal
var s: float = 0.0
var d: float = 0.0
var v: float = 0.0
var lat_v: float = 0.0
var side: int = 1
var slot: int = 0
var mode: String = "approach"
var mode_t: float = 0.0
var wait_t: float = 1.0
var gone: bool = false
var ko_cause: String = ""
var rider: Node3D
var ski: Node3D
var ring: MeshInstance3D
var mark: Label3D
var spray: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _ko_vel: Vector3 = Vector3.ZERO
var _rider_vel: Vector3 = Vector3.ZERO
var _splashed: bool = false
var _bob_t: float = 0.0


func setup(lv: LairCanal, side_: int, slot_: int, seed_: int) -> void:
	level = lv
	side = side_
	slot = slot_
	_rng.seed = seed_
	_bob_t = _rng.randf() * 5.0
	name = "JetSki"
	ski = CineFX.build_prop("jet_ski", {"color": Color("#25282E")})
	ski.name = "Ski"
	add_child(ski)
	rider = StoryCast.build("bay_soi", {"seed": seed_, "clip": "ride"})
	if rider:
		rider.position = SEAT
		ski.add_child(rider)
		CharacterBuilder.set_param(rider, "ride_shoulder", 1.2)
		CharacterBuilder.set_param(rider, "ride_elbow", 0.3)
		CharacterBuilder.set_param(rider, "ride_lean", 0.45)
		var an: Node = CharacterBuilder.get_animator(rider)
		var ap: AnimationPlayer = an.get("player") as AnimationPlayer if an else null
		if ap:
			ap.active = false
	Readability.rim(ski, "enemy")   # Q3 rim on the jet ski and its rider (not the tell ring)
	ring = MeshInstance3D.new()
	ring.name = "TellRing"
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.85
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.material_override = CineFX._glow_mat(Readability.DANGER, 2.5)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, 0.05, 0.0)
	ring.visible = false
	add_child(ring)
	mark = Label3D.new()
	mark.name = "Tell"
	mark.text = "!"
	mark.font_size = 96
	mark.pixel_size = 0.006
	mark.modulate = Readability.DANGER
	mark.outline_size = 14
	mark.outline_modulate = Color(0.06, 0.02, 0.1, 0.95)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.position = Vector3(0.0, 2.6, 0.0)
	mark.visible = false
	add_child(mark)
	spray = PlayerBoat.make_spray(ski, Vector3(0.0, 0.05, -1.1), 14)


func place(s0: float, d0: float, v0: float) -> void:
	s = s0
	d = d0
	v = v0
	_apply_xf()


## Back in the race from the pool (BoatChase reuses its jet skis): the rider on the seat, the ski upright, approaching.
func revive(side_: int, slot_: int) -> void:
	side = side_
	slot = slot_
	gone = false
	ko_cause = ""
	_splashed = false
	lat_v = 0.0
	visible = true
	ski.position = Vector3.ZERO
	ski.rotation = Vector3.ZERO
	if rider:
		if rider.get_parent() != ski:
			rider.get_parent().remove_child(rider)
			ski.add_child(rider)
		rider.position = SEAT
		rider.rotation = Vector3.ZERO
		rider.visible = true
	_set_mode("approach")


## Out of the pool: hidden, not thinking.
func retire() -> void:
	gone = true
	visible = false
	_set_mode("approach")
	if spray:
		spray.emitting = false


## One chase step; 1 when the ram dash connects with the boat this step, else 0. `may_attack`: BoatChase's token.
func think(dt: float, boat: PlayerBoat, may_attack: bool) -> int:
	_bob_t += dt
	mode_t += dt
	if gone:
		return 0
	if mode == "ko":
		_ko_tick(dt)
		return 0
	var hit: int = 0
	var ts: float = boat.s + (-0.4 + 1.6 * float(slot))
	var lim: float = LairCanal.HALF_W - 0.7
	var td: float = clampf(boat.d + float(side) * BoatData.SKI_FLANK_D, -lim, lim)
	var gap: float = ts - s
	var want_v: float = boat.v + clampf(gap * 1.1, -7.0, BoatData.SKI_V_EXTRA)
	if s < boat.s - BoatData.SKI_LEASH:
		want_v = boat.v + BoatData.SKI_V_EXTRA * 1.5
	match mode:
		"approach":
			_steer_to(td, 6.0, dt)
			if absf(gap) < 2.6 and absf(d - td) < 1.3:
				_set_mode("flank")
				wait_t = _rng.randf_range(0.6, BoatData.ski_ram_gap())
		"flank":
			_steer_to(td, 6.0, dt)
			wait_t -= dt
			if absf(gap) > 6.0:
				_set_mode("approach")
			elif wait_t <= 0.0 and may_attack:
				_set_mode("tell")
		"tell":
			_steer_to(clampf(boat.d + float(side) * BoatData.SKI_TELL_D, -lim, lim), 6.0, dt)
			ring.visible = true
			mark.visible = fmod(mode_t, 0.24) < 0.16
			var k: float = clampf(mode_t / BoatData.ski_tell(), 0.0, 1.0)
			ring.scale = Vector3(1.25 - 0.45 * k, 0.15, 1.25 - 0.45 * k)
			if mode_t >= BoatData.ski_tell():
				_set_mode("ram")
		"ram":
			lat_v = -float(side) * BoatData.SKI_RAM_DASH
			if absf(s - boat.s) < BoatData.SKI_RAM_ALONG and absf(d - boat.d) < BoatData.SKI_RAM_D and not boat.airborne:
				hit = 1
				_set_mode("recover")
				lat_v = float(side) * 6.0
			elif mode_t >= RAM_MAX_S or float(side) * (d - boat.d) < -0.5:
				_set_mode("recover")   # missed: the boat dodged
				lat_v = float(side) * 4.0
		"recover":
			want_v = boat.v - 2.0
			_steer_to(clampf(boat.d + float(side) * (BoatData.SKI_FLANK_D + 2.5), -lim, lim), 3.0, dt)
			if mode_t >= RECOVER_S:
				_set_mode("approach")
	v = move_toward(v, maxf(want_v, 0.0), 14.0 * dt)
	s += v * dt
	d = clampf(d + lat_v * dt, -lim, lim)
	_apply_xf()
	return hit


func _steer_to(td: float, gain: float, dt: float) -> void:
	lat_v = lerpf(lat_v, clampf((td - d) * gain, -7.0, 7.0), minf(1.0, dt * 6.0))


func _set_mode(m: String) -> void:
	mode = m
	mode_t = 0.0
	if ring:
		ring.visible = m == "tell"
	if mark:
		mark.visible = m == "tell"


## Out of the race: kicked toward `push` (-1 left, +1 right; 0 = a crash: cause "net" / "wall" / "barge").
func knock_out(push: int, cause: String = "kick") -> void:
	if mode == "ko" or gone:
		return
	ko_cause = cause
	_set_mode("ko")
	if spray:
		spray.emitting = false
	var fwd: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var away: float = float(push) if push != 0 else (1.0 if _rng.randf() < 0.5 else -1.0)
	_ko_vel = fwd * v * 0.5 + right * away * 5.0
	_rider_vel = fwd * v * 0.6 + right * away * 6.5 + Vector3.UP * 6.0
	if rider:
		var xf: Transform3D = rider.global_transform
		ski.remove_child(rider)
		add_child(rider)
		rider.global_transform = xf


func _ko_tick(dt: float) -> void:
	_ko_vel = _ko_vel.move_toward(Vector3.ZERO, 6.0 * dt)
	ski.position += _ko_vel * dt
	ski.rotation.z += dt * 7.0
	ski.rotation.x += dt * 2.5
	if mode_t > 0.9:
		ski.position.y -= dt * 0.8   # sinking
	if rider:
		_rider_vel.y -= 14.0 * dt
		rider.position += _rider_vel * dt
		rider.rotation.x += dt * 6.0
		if not _splashed and rider.position.y < -0.2 and _rider_vel.y < 0.0:
			_splashed = true
			Impact.particles(self, "splash", rider.global_position, Vector3.UP, 1.0)
			rider.visible = false
	if mode_t >= KO_S:
		gone = true
		visible = false


func is_threat() -> bool:
	return not gone and mode != "ko"


func _apply_xf() -> void:
	if level == null:
		return
	var pos: Vector3 = level.course_pos(s, d, sin(_bob_t * 3.1) * 0.04)
	var yaw: float = level.yaw_at(s) - atan2(lat_v, maxf(v, 4.0)) * 0.9
	global_transform = Transform3D(Basis.from_euler(Vector3(0.05, yaw, clampf(-lat_v * 0.04, -0.35, 0.35))), pos)
	if spray:
		spray.emitting = v > 6.0
