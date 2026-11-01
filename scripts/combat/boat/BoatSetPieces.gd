# File: res://scripts/combat/boat/BoatSetPieces.gd
# The signature set pieces of the Day 6 speedboat chase (plan 2026-11-01-w4-day6.md T6), owned by BoatChase (child node,
# stepped on the chase clock after the hazards):
#   - preview cuts (CameraDirector.preview_cut) once per attempt as each set piece comes up: the first low bridge, the
#     net (as it rises), the sampan ramp, the fireworks barge, Thị Lọ's Titanic pose;
#   - the nets lie under the water until the boat is BoatData.NET_RAISE_AT m before them, then rise over NET_RAISE_S with
#     their red top line on (the telegraph); only a net raised past NET_LIVE_W catches a hull (net_live(k));
#   - the ramp jump: slow motion through the Impact clock (JUMP_SCALE for JUMP_SLOW_S real) and a side camera on the
#     left bank past the broken pier wall, tracking the boat until the landing;
#   - the fireworks barge: sky bursts over it (CineAnimD6 "fireworks" pool) and rogue rockets: each lands where the boat
#     will be in rocket_tell() s, telegraphed by a red ring on the water; the blast hurts the boat (and takes jet skis out);
#   - the finale: her Titanic pose on the bow (RivalBoat.titanic; she coasts), the cut on her; the last ram: a
#     slow-motion orbit on her boat (Impact.slowmo_orbit).
# Log keys (BoatChase.log): cut_<kind>, net_up<k>, jump_cam, rocket, rocket_hit, rocket_miss, sky, titanic, finish_orbit.
class_name BoatSetPieces
extends Node3D

const CUT_S: float = 0.8
const NET_CUT_S: float = 1.0
const CUT_WINDOW: float = 40.0           # a cut only fires within this many metres past its trigger (not after a teleport)
const JUMP_CAM_HOLD: float = 0.35        # the side camera stays this long after the landing
const JUMP_CAM_FOV: float = 58.0
const SKY_GAP: float = 0.5
const BURST_END: float = 99.0            # an age past CineAnimD6.BURST_S: hides a sky burst slot
const ROCKETS: int = 3
const SKY_COLS: Array[Color] = [Color("#FF4FA3"), Color("#FFD43B"), Color("#4FD8FF"), Color("#FF7A2A"), Color("#B26BFF")]

var chase: BoatChase
var level: LairCanal
var cuts_done: Array[String] = []
var cut_count: int = 0
var net_w: Array[float] = []
var cam_mode: String = "chase"
var rockets: Array[Dictionary] = []
var rocket_count: int = 0
var sky_count: int = 0
var _jump_hold: float = -1.0
var _rocket_t: float = 0.0
var _sky_t: float = 0.0
var _sky: Array[Dictionary] = []
var _sky_k: int = 0
var _rng := RandomNumberGenerator.new()


func setup(c: BoatChase, seed_: int) -> void:
	chase = c
	level = c.level
	name = "SetPieces"
	_rng.seed = seed_ + 77
	for k: int in LairCanal.NETS.size():
		net_w.append(0.0)
	for i: int in ROCKETS:
		var ring := MeshInstance3D.new()
		ring.name = "RocketRing%d" % i
		var tm := TorusMesh.new()
		tm.inner_radius = BoatData.ROCKET_R - 0.3
		tm.outer_radius = BoatData.ROCKET_R
		tm.rings = 28
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = CineFX._glow_mat(Readability.DANGER, 2.6)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		var rk := MeshInstance3D.new()
		rk.name = "Rocket%d" % i
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		sm.radial_segments = 8
		sm.rings = 4
		rk.mesh = sm
		rk.material_override = CineFX._glow_mat(Color("#FFD43B"), 4.0)
		rk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rk.visible = false
		add_child(rk)
		var trail: CPUParticles3D = PlayerBoat.make_spray(rk, Vector3.ZERO, 16)
		trail.name = "Trail"
		trail.direction = Vector3.UP
		trail.spread = 25.0
		trail.initial_velocity_min = 0.2
		trail.initial_velocity_max = 0.8
		trail.gravity = Vector3(0.0, -1.0, 0.0)
		trail.lifetime = 0.4
		((trail.mesh as QuadMesh).material as StandardMaterial3D).albedo_color = Color(1.0, 0.75, 0.3, 0.8)
		rockets.append({"ring": ring, "rk": rk, "trail": trail, "live": false, "t": 0.0, "tell": 1.0, "s": 0.0, "d": 0.0, "from": Vector3.ZERO})


## Start / retry at route s0: the cuts behind s0 count as done, the nets before it lie under the water, the rest are up.
func reset(s0: float) -> void:
	cuts_done.clear()
	for kind: String in ["bridge", "net", "ramp", "barge"]:
		if s0 >= _cut_at(kind):
			cuts_done.append(kind)
	for k: int in LairCanal.NETS.size():
		net_w[k] = 1.0 if s0 > float(LairCanal.NETS[k][0]) else 0.0
		_apply_net(k)
	for r: Dictionary in rockets:
		_rocket_off(r)
	_rocket_t = 1.0
	_sky_t = 0.0
	for sk: Dictionary in _sky:
		level.fireworks.burst_at(int(sk["k"]), BURST_END, Vector3.ZERO, Color.WHITE)
	_sky.clear()
	_end_jump()
	if chase.rival:
		chase.rival.titanic(0.0)


## Everything off (the chase stopped).
func clear() -> void:
	for r: Dictionary in rockets:
		_rocket_off(r)
	_end_jump()


func _cut_at(kind: String) -> float:
	match kind:
		"bridge":
			return LairCanal.BRIDGES[0] - 80.0
		"net":
			return float(LairCanal.NETS[0][0]) - BoatData.NET_RAISE_AT
		"ramp":
			return LairCanal.RAMP_S - 100.0
		"barge":
			return LairCanal.BARGE_S - BoatData.BARGE_FROM - 10.0
	return INF


func step(dt: float) -> void:
	var s: float = chase.boat.s
	# preview cuts as the set pieces come up
	for kind: String in ["bridge", "net", "ramp", "barge"]:
		if cuts_done.has(kind) or s < _cut_at(kind):
			continue
		cuts_done.append(kind)
		if s < _cut_at(kind) + CUT_WINDOW:
			_cut(kind, _cut_target(kind), NET_CUT_S if kind == "net" else CUT_S)
	# the nets rise with the telegraph
	for k: int in LairCanal.NETS.size():
		var ns: float = float(LairCanal.NETS[k][0])
		if net_w[k] < 1.0 and s >= ns - BoatData.NET_RAISE_AT:
			if net_w[k] <= 0.0:
				chase.log.append("net_up%d" % k)
				Impact.sound(chase, "metal_creak", level.nets[k].global_position, -4.0)
				chase.set_piece.emit("net")
			net_w[k] = minf(1.0, net_w[k] + dt / BoatData.NET_RAISE_S)
			_apply_net(k)
	_fireworks(dt, s)
	_tick_rockets(dt)
	if _jump_hold >= 0.0:
		_jump_hold -= dt
		if _jump_hold < 0.0:
			_end_jump()


func _cut_target(kind: String) -> Node3D:
	match kind:
		"bridge":
			return level.bridge_nodes[0] if not level.bridge_nodes.is_empty() else null
		"net":
			return level.nets[0] if not level.nets.is_empty() else null
		"ramp":
			return level.ramp_node
		"barge":
			return level.fireworks.get_parent() as Node3D if level.fireworks else null
	return null


func _cut(kind: String, target: Node3D, secs: float) -> void:
	chase.log.append("cut_" + kind)
	var dir: CameraDirector = CameraDirector.live()
	if dir != null and target != null and dir.preview_cut(target, secs):
		cut_count += 1


## A net raised past NET_LIVE_W catches a hull (and a jet ski).
func net_live(k: int) -> bool:
	return k >= 0 and k < net_w.size() and net_w[k] >= BoatData.NET_LIVE_W


func _apply_net(k: int) -> void:
	if k < level.nets.size():
		level.nets[k].set_raise(net_w[k])
		level.nets[k].set_alarm(net_w[k] > 0.0)


# ---------------------------------------------------------------------------
# The ramp jump
# ---------------------------------------------------------------------------
func on_jump() -> void:
	chase.log.append("jump_cam")
	cam_mode = "jump"
	_jump_hold = -1.0
	var c: Impact = Impact.clock(chase)
	if c:
		c.slowmo(BoatData.JUMP_SCALE, BoatData.JUMP_SLOW_S, self)
	Impact.sound(chase, "engine_roar", chase.boat.global_position, 0.0)
	chase.set_piece.emit("jump")


func on_landed() -> void:
	if cam_mode == "jump":
		_jump_hold = JUMP_CAM_HOLD


func _end_jump() -> void:
	_jump_hold = -1.0
	if cam_mode == "jump":
		cam_mode = "chase"
		chase.cam.fov = BoatChase.CAM_FOV.x
		chase._cam_init = false
	var c: Impact = Impact.find_clock(chase) if chase and chase.is_inside_tree() else null
	if c and c.slowmo_active(self):
		c.end_slowmo(self)


## The side camera of the jump: on the left bank past the broken pier wall, low, tracking the boat. true while it owns
## the chase camera.
func camera() -> bool:
	if cam_mode != "jump":
		return false
	var cam: Camera3D = chase.cam
	cam.global_position = level.course_pos(LairCanal.RAMP_S + 6.0, -(LairCanal.HALF_W - 0.8), 2.4)
	var look: Vector3 = chase.boat.global_position + Vector3(0.0, 0.8, 0.0)
	if cam.global_position.distance_squared_to(look) > 0.01:
		cam.look_at(look, Vector3.UP)
	cam.fov = JUMP_CAM_FOV
	return true


# ---------------------------------------------------------------------------
# The fireworks barge
# ---------------------------------------------------------------------------
func _fireworks(dt: float, s: float) -> void:
	var near: bool = s > LairCanal.BARGE_S - BoatData.BARGE_FROM - 60.0 and s < LairCanal.BARGE_S + 70.0
	if near and level.fireworks:
		_sky_t -= dt
		if _sky_t <= 0.0:
			_sky_t = SKY_GAP
			var k: int = _sky_k % CineAnimD6.POOL
			_sky_k += 1
			for i: int in range(_sky.size() - 1, -1, -1):
				if int(_sky[i]["k"]) == k:
					_sky.remove_at(i)
			_sky.append({"k": k, "age": -CineAnimD6.ROCKET_S, "pos": Vector3(_rng.randf_range(-9.0, 9.0), _rng.randf_range(16.0, 26.0), _rng.randf_range(-14.0, 14.0)),
				"col": SKY_COLS[_rng.randi() % SKY_COLS.size()], "boom": false})
			sky_count += 1
			if not chase.log.has("sky"):
				chase.log.append("sky")
	for i2: int in range(_sky.size() - 1, -1, -1):
		var b: Dictionary = _sky[i2]
		b["age"] = float(b["age"]) + dt
		level.fireworks.burst_at(int(b["k"]), float(b["age"]), b["pos"], b["col"])
		if not bool(b["boom"]) and float(b["age"]) >= 0.0:
			b["boom"] = true
			Impact.sound(chase, "boom", level.fireworks.to_global(b["pos"]), -16.0)
		if float(b["age"]) >= CineAnimD6.BURST_S:
			_sky.remove_at(i2)
	# rogue rockets at the boat while it passes the barge
	if s > LairCanal.BARGE_S - BoatData.BARGE_FROM and s < LairCanal.BARGE_S + BoatData.BARGE_TO and chase.state == "running":
		_rocket_t -= dt
		if _rocket_t <= 0.0:
			_rocket_t = BoatData.rocket_gap()
			_launch_rocket()


func _launch_rocket() -> void:
	for r: Dictionary in rockets:
		if bool(r["live"]):
			continue
		var b: PlayerBoat = chase.boat
		var tell: float = BoatData.rocket_tell()
		var lim: float = LairCanal.HALF_W - 1.5
		r["live"] = true
		r["t"] = 0.0
		r["tell"] = tell
		r["s"] = b.s + b.v * tell
		r["d"] = clampf(b.d + _rng.randf_range(-1.2, 1.2), -lim, lim)
		r["from"] = level.fireworks.global_position + Vector3(0.0, 1.2, 0.0) if level.fireworks else b.global_position + Vector3(0.0, 8.0, 0.0)
		var ring: MeshInstance3D = r["ring"]
		ring.global_position = level.course_pos(float(r["s"]), float(r["d"]), 0.06)
		ring.global_rotation = Vector3(0.0, level.yaw_at(float(r["s"])), 0.0)
		ring.scale = Vector3(1.0, 0.15, 1.0)
		ring.visible = true
		(r["rk"] as MeshInstance3D).visible = true
		(r["trail"] as CPUParticles3D).emitting = true
		rocket_count += 1
		chase.log.append("rocket")
		Impact.sound(chase, "whoosh_down", r["from"], -8.0)
		return


func _tick_rockets(dt: float) -> void:
	for r: Dictionary in rockets:
		if not bool(r["live"]):
			continue
		r["t"] = float(r["t"]) + dt
		var u: float = clampf(float(r["t"]) / float(r["tell"]), 0.0, 1.0)
		var to: Vector3 = level.course_pos(float(r["s"]), float(r["d"]), 0.0)
		var p: Vector3 = (r["from"] as Vector3).lerp(to, u) + Vector3(0.0, 9.0 * 4.0 * u * (1.0 - u), 0.0)
		(r["rk"] as MeshInstance3D).global_position = p
		var ring: MeshInstance3D = r["ring"]
		var pulse: float = 1.0 - 0.12 * absf(sin(float(r["t"]) * 12.0))
		ring.scale = Vector3(pulse, 0.15, pulse)
		if u >= 1.0:
			_blast(r, to)


func _blast(r: Dictionary, at: Vector3) -> void:
	_rocket_off(r)
	Impact.particles(chase, "splash", at, Vector3.UP, 1.6)
	Impact.particles(chase, "sparks", at + Vector3(0.0, 0.6, 0.0), Vector3.UP, 1.2)
	Impact.sound(chase, "boom", at, -6.0)
	var b: PlayerBoat = chase.boat
	var hit: bool = Vector2(b.s - float(r["s"]), b.d - float(r["d"])).length() < BoatData.ROCKET_R + BoatData.BEAM_HALF * 0.5 and b.air_h < 1.5
	if hit and chase.state == "running":
		chase.rocket_hit(at)
	else:
		chase.log.append("rocket_miss")
	for sk: JetSki in chase.skis:
		if sk.is_threat() and Vector2(sk.s - float(r["s"]), sk.d - float(r["d"])).length() < BoatData.ROCKET_R:
			sk.knock_out(0, "rocket")
			chase._ski_ko(sk, "rocket")


func _rocket_off(r: Dictionary) -> void:
	r["live"] = false
	(r["ring"] as MeshInstance3D).visible = false
	(r["rk"] as MeshInstance3D).visible = false
	(r["trail"] as CPUParticles3D).emitting = false


func live_rockets() -> int:
	var n: int = 0
	for r: Dictionary in rockets:
		n += 1 if bool(r["live"]) else 0
	return n


# ---------------------------------------------------------------------------
# The finale
# ---------------------------------------------------------------------------
func on_finale() -> void:
	chase.log.append("titanic")
	chase.rival.titanic(BoatData.TITANIC_S)
	Impact.sound(chase, "applause", chase.rival.global_position, -12.0)
	chase.set_piece.emit("titanic")
	if chase.rival.driver:
		_cut("titanic", chase.rival.driver, CUT_S)


func on_last_ram() -> void:
	chase.log.append("finish_orbit")
	Impact.slowmo_orbit(chase, chase.rival, BoatData.FINISH_ORBIT_S)
	Impact.sound(chase, "boom", chase.rival.global_position, -6.0)
	chase.set_piece.emit("finish")
