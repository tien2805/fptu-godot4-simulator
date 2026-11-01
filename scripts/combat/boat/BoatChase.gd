# File: res://scripts/combat/boat/BoatChase.gd
# Encounter node of the Day 6 speedboat chase on the Rạch Hầm canal (plan 2026-11-01-w4-day6.md T4): the player's
# PlayerBoat after Thị Lọ's RivalBoat down the LairCanal course, Bầy Sói jet skis in waves, the course's hazards, the
# chase camera, checkpoints and the fail / retry rules. Everything runs on step(dt) (MissionBoatChase calls it on the
# mission clock; tests drive it by hand).
#
# ===== API =====
#   var chase := BoatChase.new(); parent.add_child(chase)
#   chase.setup(level: LairCanal, {"seed": 1, "rider_opts": {...} (the protagonist's CharacterBuilder look)})
#   chase.start()                  the boat at checkpoint 0, the rival ahead, the camera current, state "running"
#   chase.step(dt)                 one chase step (input -> boat -> hazards -> rival -> jet skis -> rams -> camera)
#   chase.kick(side) -> bool       [Q] -1 / [E] +1
#   chase.retry()                  back to the last checkpoint passed (full hull, the jet skis of that stretch again)
#   chase.stop()                   end without a result (jet skis retired)
#   chase.input_override           a Dictionary {"throttle", "steer", "duck"} replaces the keyboard (tests, the bot)
#   signals: lost(reason) (the hull at 0: BoatData.T_SINK; Thị Lọ too far ahead / the canal's end: T_LOST), won (after the
#            last ram and the crash), hazard_hit(kind) (bridge | net | wall | barge | ski | rocket), ski_down(ski, cause)
#            (kick | net | wall | barge | rocket | finale), rammed(n), checkpoint_passed(i), wave_started(i), finale_started,
#            set_piece(kind) (net | jump | titanic | finish)
#   set_pieces (BoatSetPieces): the preview cuts, the rising nets, the jump cam + slow motion, the fireworks and the rogue
#            rockets, the Titanic pose, the finish orbit
#   state: idle | running | finishing (her boat on the bank, FINISH_S of footage) | won | lost; log (events, tests)
# Hazards (route space, LairCanal constants): the low bridges (an upright head under the deck: BONK, the hull, the speed;
# ducked: "duck_ok"), the nets (the half of the canal they cover), the sampan ramp (on its line fast enough: the jump over
# the broken pier wall; too slow: a flop), the broken pier wall (only the gap by the left bank is open; the wall stops the
# boat), the fireworks barge (a bump), the bank walls (a scrape: BoatData.bank_dps per second). Jet skis crash into the
# nets, the pier wall and the barge too (free takedowns). One jet ski telegraphs a ram at a time (the attack token).
# Camera: behind and above the boat along the route heading (not the steering), lower under the bridges, a wider FOV with
# speed. Jet skis come from a pool of MAX_SKIS (no rigged body is built during the chase).
class_name BoatChase
extends Node3D

signal lost(reason: String)
signal won
signal hazard_hit(kind: String)
signal ski_down(ski: JetSki, cause: String)
signal rammed(n: int)
signal checkpoint_passed(i: int)
signal wave_started(i: int)
signal finale_started
signal set_piece(kind: String)          # net | jump | titanic | finish (BoatSetPieces; the mission's popups / radio)

const LIP_H: float = 1.22                # the sampan ramp's lip above the water line (CinePropsD6.sampan meta lip_y)
const CAM_BACK: float = 7.4
const CAM_UP: float = 3.0
const CAM_LOW: float = 1.25              # under the bridge decks (BRIDGE_CLEAR 1.75)
const CAM_FOV: Vector2 = Vector2(62.0, 74.0)
const FINISH_S: float = 2.0
const MAX_SKIS: int = 4
const RESPAWN_BEHIND: float = 90.0       # a jet ski left this far behind (the jump) comes back behind the camera
const SPARK_S: float = 0.15

var level: LairCanal
var boat: PlayerBoat
var rival: RivalBoat
var skis: Array[JetSki] = []
var set_pieces: BoatSetPieces
var cam: Camera3D
var state: String = "idle"
var cp_i: int = 0
var wave_i: int = 0
var lose_t: float = 0.0
var finish_t: float = -1.0
var ram_cd: float = 0.0
var finale: bool = false
var log: Array[String] = []
var hits: Dictionary = {}
var input_override: Variant = null
var rng := RandomNumberGenerator.new()
var kos: int = 0
var hazard_hits: int = 0
var on_ramp: bool = false
var _attacker: JetSki = null
var _spark_t: float = 0.0
var _barge_cd: float = 0.0
var _wall_cd: float = 0.0
var _cam_pos: Vector3 = Vector3.ZERO
var _cam_look: Vector3 = Vector3.ZERO
var _cam_init: bool = false
var _kick_q: int = 0


func setup(lv: LairCanal, opts: Dictionary = {}) -> void:
	level = lv
	name = "BoatChase"
	rng.seed = int(opts.get("seed", 1))
	boat = PlayerBoat.new()
	add_child(boat)
	boat.setup(lv, opts.get("rider_opts", {}))
	rival = RivalBoat.new()
	add_child(rival)
	rival.setup(lv)
	for i: int in MAX_SKIS:
		var sk := JetSki.new()
		add_child(sk)
		sk.setup(lv, 1 if i % 2 == 0 else -1, 0, 3300 + i + rng.randi_range(0, 999))
		sk.name = "JetSki%d" % i
		sk.retire()
		skis.append(sk)
	set_pieces = BoatSetPieces.new()
	add_child(set_pieces)
	set_pieces.setup(self, int(opts.get("seed", 1)))
	cam = Camera3D.new()
	cam.name = "BoatCam"
	cam.fov = CAM_FOV.x
	cam.near = 0.1
	cam.far = 700.0
	add_child(cam)
	Impact.prepare(self)
	CameraDirector.ensure(self)              # the set pieces' preview cuts and the finish orbit


func start() -> void:
	cp_i = 0
	_place_at(0)
	state = "running"
	cam.make_current()
	log.append("start")


func retry() -> void:
	_place_at(cp_i)
	state = "running"
	cam.make_current()
	log.append("retry%d" % cp_i)


func stop() -> void:
	state = "idle"
	for sk: JetSki in skis:
		sk.retire()
	set_pieces.clear()


func _place_at(i: int) -> void:
	var s0: float = BoatData.CHECKPOINTS[i]
	boat.place(s0, 0.0, BoatData.V_CRUISE)
	boat.hull = BoatData.HULL
	rival.place(s0 + BoatData.RIVAL_GAP, 1.5, BoatData.V_CRUISE + 4.0)
	for sk: JetSki in skis:
		sk.retire()
	wave_i = 0
	while wave_i < BoatData.WAVES.size() and float(BoatData.WAVES[wave_i][0]) <= s0:
		wave_i += 1
	hits.clear()
	lose_t = 0.0
	finish_t = -1.0
	ram_cd = 0.0
	finale = s0 >= BoatData.FINALE_S
	on_ramp = false
	_attacker = null
	_kick_q = 0
	_wall_cd = 0.0
	_barge_cd = 0.0
	set_pieces.reset(s0)
	_cam_init = false


## [Q] -1 / [E] +1: the kick leg out to that side (the hit is resolved in the window, see _skis).
func kick(side: int) -> bool:
	if state != "running":
		return false
	if boat.kick(side):
		log.append("kick")
		Impact.sound(self, "whoosh_down", boat.global_position, -6.0)
		return true
	return false


# ---------------------------------------------------------------------------
# Step
# ---------------------------------------------------------------------------
func step(dt: float) -> void:
	if state != "running" and state != "finishing":
		return
	_read_input()
	var prev_s: float = boat.s
	var r: Dictionary = boat.step(dt)
	if bool(r["scrape"]):
		boat.damage(BoatData.bank_dps() * dt)
		_spark_t -= dt
		if _spark_t <= 0.0:
			_spark_t = SPARK_S
			Impact.particles(self, "sparks", boat.global_position + Vector3(0.0, 0.4, 0.0), Vector3.UP, 0.6)
			if not log.has("scrape"):
				log.append("scrape")
	if bool(r["landed"]):
		log.append("landed")
		set_pieces.on_landed()
		Impact.particles(self, "splash", boat.global_position, Vector3.UP, 1.5)
		Impact.hit(self, "light", {"pos": boat.global_position, "no_hitstop": true, "no_fx": true})
	_hazards(prev_s, dt)
	if not finale and boat.s >= BoatData.FINALE_S:
		finale = true
		log.append("finale")
		finale_started.emit()
		set_pieces.on_finale()
	rival.think(dt, boat, finale)
	_skis(dt)
	_waves()
	_checkpoints()
	_rams(dt)
	set_pieces.step(dt)
	_camera(dt)
	if state == "finishing":
		finish_t += dt
		if finish_t >= FINISH_S:
			state = "won"
			log.append("won")
			won.emit()
		return
	_fail_checks(dt)


func _read_input() -> void:
	if input_override is Dictionary:
		boat.input = input_override
		return
	var thr: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var st: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	boat.input = {"throttle": thr, "steer": st, "duck": Input.is_action_pressed("walk") or Input.is_physical_key_pressed(KEY_CTRL)}


# ---------------------------------------------------------------------------
# Hazards
# ---------------------------------------------------------------------------
func _hazards(prev_s: float, dt: float) -> void:
	var s: float = boat.s
	_barge_cd = maxf(0.0, _barge_cd - dt)
	_wall_cd = maxf(0.0, _wall_cd - dt)
	# the low bridges
	for i: int in LairCanal.BRIDGES.size():
		var bs: float = LairCanal.BRIDGES[i]
		var key: String = "b%d" % i
		if hits.has(key):
			continue
		if absf(s - bs) < BoatData.BRIDGE_HALF and not boat.ducked() and not boat.airborne:
			hits[key] = true
			boat.damage(BoatData.dmg_bridge())
			boat.v *= 0.45
			boat.stun(BoatData.STUN_S)
			_hit("bridge", "heavy", boat.global_position + Vector3(0.0, 1.6, 0.0))
		elif prev_s < bs + BoatData.BRIDGE_HALF and s >= bs + BoatData.BRIDGE_HALF:
			hits[key] = true
			log.append("duck_ok")
	# the nets
	for k: int in LairCanal.NETS.size():
		var ns: float = float(LairCanal.NETS[k][0])
		var side: float = float(LairCanal.NETS[k][1])
		var nkey: String = "n%d" % k
		if not hits.has(nkey) and set_pieces.net_live(k) and absf(s - ns) < BoatData.NET_HALF + BoatData.LEN_HALF * 0.5 and boat.d * side > BoatData.NET_INNER - BoatData.BEAM_HALF and boat.air_h < 2.0:
			hits[nkey] = true
			boat.damage(BoatData.dmg_net())
			boat.v *= 0.3
			boat.stun(BoatData.STUN_S)
			_hit("net", "light", boat.global_position + Vector3(0.0, 0.8, 0.0))
	# the sampan ramp (lip at RAMP_S - 6: 6 m of tipped hull before it) and the broken pier wall
	var lip: float = LairCanal.RAMP_S - 6.0
	var on_line: bool = absf(boat.d - LairCanal.RAMP_D) < BoatData.RAMP_HALF_D
	on_ramp = false
	if not boat.airborne:
		if s > lip - 6.0 and s < lip and on_line:
			on_ramp = true
			boat.air_h = LIP_H * clampf((s - (lip - 6.0)) / 6.0, 0.0, 1.0)
		elif prev_s < lip and s >= lip and absf(boat.d - LairCanal.RAMP_D) < BoatData.RAMP_HALF_D + 0.3 and boat.air_h > 0.5:
			if boat.v >= BoatData.RAMP_MIN_V:
				boat.launch(LIP_H, boat.v * BoatData.RAMP_UP)
				log.append("jump")
				set_pieces.on_jump()
			else:
				boat.launch(LIP_H, 0.0)
				log.append("flop")
		else:
			boat.air_h = 0.0
			var off: float = boat.d - LairCanal.RAMP_D
			if s > lip - 6.5 and s < lip + 0.5 and absf(off) >= BoatData.RAMP_HALF_D and absf(off) < 0.8 + BoatData.BEAM_HALF:
				boat.d = LairCanal.RAMP_D + signf(off) * (0.8 + BoatData.BEAM_HALF)   # the sampan's side: pushed off it
				boat.lat_v = signf(off) * absf(boat.lat_v) * 0.3
	var w0: float = LairCanal.RAMP_S - BoatData.WALL_HALF
	if prev_s + BoatData.LEN_HALF < w0 + 0.5 and s + BoatData.LEN_HALF >= w0 and boat.d > LairCanal.GAP_D1 + BoatData.BEAM_HALF * 0.6 and boat.air_h < BoatData.CLEAR_H:
		var impact: float = boat.v
		boat.s = w0 - BoatData.LEN_HALF - 0.1
		boat.airborne = false
		boat.air_h = 0.0
		boat.air_vy = 0.0
		if impact > BoatData.WALL_SOFT_V and _wall_cd <= 0.0:
			_wall_cd = BoatData.WALL_CD
			boat.v = 1.5
			boat.damage(BoatData.dmg_wall())
			boat.stun(BoatData.STUN_S)
			_hit("wall", "heavy", boat.bow())
		else:
			boat.v = minf(boat.v, 1.5)          # against the wall: blocked until it steers to the gap
	# the fireworks barge
	if _barge_cd <= 0.0 and absf(s - LairCanal.BARGE_S) < BoatData.BARGE_HALF_S + BoatData.LEN_HALF * 0.5 and absf(boat.d - LairCanal.BARGE_D) < BoatData.BARGE_HALF_D + BoatData.BEAM_HALF and boat.air_h < 1.0:
		_barge_cd = 1.0
		var away: float = -1.0 if boat.d < LairCanal.BARGE_D else 1.0
		boat.d = LairCanal.BARGE_D + away * (BoatData.BARGE_HALF_D + BoatData.BEAM_HALF + 0.05)
		boat.lat_v = away * 3.0
		boat.v *= 0.6
		boat.damage(BoatData.dmg_barge())
		_hit("barge", "light", boat.global_position + Vector3(0.0, 0.6, 0.0))


## A rogue rocket's blast on the boat (BoatSetPieces): the hull, a shove, the hit.
func rocket_hit(at: Vector3) -> void:
	boat.damage(BoatData.dmg_rocket())
	boat.lat_v += signf(boat.global_position.x - at.x + 0.01) * 3.0
	_hit("rocket", "light", at + Vector3(0.0, 0.6, 0.0))


func _hit(kind: String, tier: String, at: Vector3) -> void:
	hazard_hits += 1
	log.append(kind + "_hit")
	Impact.hit(self, tier, {"pos": at, "dir": -boat.global_transform.basis.z, "cues": [["impact_heavy" if tier == "heavy" else "impact_medium", -4.0]]})
	Impact.edge_flash(self)
	hazard_hit.emit(kind)


# ---------------------------------------------------------------------------
# Jet skis
# ---------------------------------------------------------------------------
func _waves() -> void:
	if wave_i >= BoatData.WAVES.size() or boat.s < float(BoatData.WAVES[wave_i][0]):
		return
	var w: Array = BoatData.WAVES[wave_i]
	var n: int = BoatData.wave_count(w)
	var side: int = 1 if rng.randf() < 0.5 else -1
	var spawned: int = 0
	for sk: JetSki in skis:
		if spawned >= n:
			break
		if not sk.gone:
			continue
		var slot: int = 0
		for o: JetSki in skis:
			if o != sk and not o.gone and o.side == side:
				slot += 1
		sk.revive(side, mini(slot, 1))
		sk.place(boat.s - BoatData.SKI_SPAWN_BEHIND - 4.0 * float(spawned), clampf(boat.d + float(side) * 4.5, -9.5, 9.5), boat.v + 4.0)
		side = -side
		spawned += 1
	log.append("wave%d" % wave_i)
	wave_started.emit(wave_i)
	wave_i += 1


func _skis(dt: float) -> void:
	if _attacker and (_attacker.gone or not (_attacker.mode in ["tell", "ram"])):
		_attacker = null
	for sk: JetSki in skis:
		if sk.gone:
			continue
		var may: bool = state == "running" and (_attacker == null or _attacker == sk)
		var was: String = sk.mode
		if sk.is_threat() and sk.s < boat.s - RESPAWN_BEHIND:
			sk.place(boat.s - BoatData.SKI_SPAWN_BEHIND, sk.d, boat.v + 4.0)
		var hit: int = sk.think(dt, boat, may)
		if sk.mode == "tell" and was != "tell":
			_attacker = sk
			log.append("ski_tell")
			Impact.sound(self, "engine_roar", sk.global_position, -10.0)
		if hit > 0 and state == "running":
			boat.damage(BoatData.dmg_ram())
			boat.lat_v = -float(sk.side) * 6.0
			_hit("ski", "light", boat.global_position + Vector3(float(sk.side) * 0.8, 0.6, 0.0))
		if not sk.is_threat():
			continue
		# the course takes them out too
		var cause: String = _ski_crash(sk)
		if cause != "":
			sk.knock_out(0, cause)
			_ski_ko(sk, cause)
	# the kick's window: the nearest jet ski on that side within reach takes it
	if boat.kick_active():
		var best: JetSki = null
		var best_d: float = INF
		for sk2: JetSki in skis:
			if not sk2.is_threat():
				continue
			var lat: float = (sk2.d - boat.d) * float(boat.kick_side)
			var along: float = absf(sk2.s - boat.s)
			if along <= BoatData.KICK_ALONG and lat >= BoatData.KICK_MIN and lat <= BoatData.KICK_MAX and along + lat < best_d:
				best = sk2
				best_d = along + lat
		if best:
			boat.kick_hit = true
			best.knock_out(boat.kick_side, "kick")
			Impact.hit(self, "heavy", {"pos": best.global_position + Vector3(0.0, 1.0, 0.0), "dir": best.global_position - boat.global_position, "cues": [["helmet_clonk", -4.0]]})
			_ski_ko(best, "kick")


func _ski_crash(sk: JetSki) -> String:
	for k: int in LairCanal.NETS.size():
		var n: Array = LairCanal.NETS[k]
		if set_pieces.net_live(k) and absf(sk.s - float(n[0])) < BoatData.NET_HALF and sk.d * float(n[1]) > BoatData.NET_INNER:
			return "net"
	if absf(sk.s - LairCanal.RAMP_S) < BoatData.WALL_HALF and sk.d > LairCanal.GAP_D1 + 0.5:
		return "wall"
	if absf(sk.s - LairCanal.BARGE_S) < BoatData.BARGE_HALF_S and absf(sk.d - LairCanal.BARGE_D) < BoatData.BARGE_HALF_D + 0.5:
		return "barge"
	return ""


func _ski_ko(sk: JetSki, cause: String) -> void:
	kos += 1
	log.append("ski_ko_" + cause)
	if _attacker == sk:
		_attacker = null
	ski_down.emit(sk, cause)


func active_skis() -> Array[JetSki]:
	var out: Array[JetSki] = []
	for sk: JetSki in skis:
		if sk.is_threat():
			out.append(sk)
	return out


# ---------------------------------------------------------------------------
# Rams, checkpoints, fails
# ---------------------------------------------------------------------------
func _rams(dt: float) -> void:
	ram_cd = maxf(0.0, ram_cd - dt)
	if rival.crashed:
		return
	var ds: float = rival.s - boat.s
	var dd: float = absf(rival.d - boat.d)
	if ds < BoatData.RAM_ALONG and ds > -BoatData.RAM_ALONG and dd < BoatData.RAM_D and not boat.airborne and not rival.airborne:
		if finale and state == "running" and ram_cd <= 0.0 and ds > 0.0 and boat.v - rival.v > BoatData.RAM_CLOSING:
			ram_cd = BoatData.RAM_COOLDOWN
			rival.rammed()
			boat.v = maxf(rival.v - 6.0, BoatData.V_SLOW)
			log.append("ram%d" % rival.rams)
			Impact.hit(self, "heavy", {"pos": (boat.bow() + rival.global_position) * 0.5, "dir": rival.global_position - boat.global_position, "cues": [["crate_smash", -6.0]]})
			rammed.emit(rival.rams)
			if rival.rams >= BoatData.rams_needed():
				rival.crash()
				state = "finishing"
				finish_t = 0.0
				log.append("crash")
				set_pieces.on_last_ram()
				for sk: JetSki in skis:
					if sk.is_threat():
						sk.knock_out(0, "finale")
		elif ds > 0.0:
			boat.s = rival.s - BoatData.RAM_ALONG   # no ghosting through her hull
			boat.v = minf(boat.v, rival.v)


func _checkpoints() -> void:
	for i: int in range(cp_i + 1, BoatData.CHECKPOINTS.size()):
		if boat.s >= BoatData.CHECKPOINTS[i]:
			cp_i = i
			log.append("cp%d" % i)
			checkpoint_passed.emit(i)


func _fail_checks(dt: float) -> void:
	if boat.hull <= 0.0:
		_lose(BoatData.T_SINK)
		return
	if rival.s - boat.s > BoatData.LOSE_GAP:
		lose_t += dt
		if lose_t >= BoatData.LOSE_S:
			_lose(BoatData.T_LOST)
			return
	else:
		lose_t = 0.0
	if boat.s > level.route.length - BoatData.END_MARGIN:
		_lose(BoatData.T_LOST)


func _lose(reason: String) -> void:
	state = "lost"
	log.append("lost")
	lost.emit(reason)


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------
func _camera(dt: float) -> void:
	if set_pieces.camera():
		return                               # the ramp jump's side camera
	var yaw: float = level.yaw_at(boat.s)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var up_h: float = CAM_UP
	for bs: float in LairCanal.BRIDGES:
		if boat.s > bs - 10.0 and boat.s < bs + CAM_BACK + 4.0:
			up_h = CAM_LOW
	var p: Vector3 = boat.global_position
	var want := Vector3(p.x, LairCanal.WATER_Y + up_h + boat.air_h * 0.6, p.z) - fwd * CAM_BACK
	var look: Vector3 = Vector3(p.x, LairCanal.WATER_Y + 1.0 + boat.air_h * 0.8, p.z) + fwd * 6.0
	if not _cam_init:
		_cam_pos = want
		_cam_look = look
		_cam_init = true
	else:
		_cam_pos = _cam_pos.lerp(want, 1.0 - exp(-dt * 5.0))
		_cam_look = _cam_look.lerp(look, 1.0 - exp(-dt * 8.0))
	cam.global_position = _cam_pos
	if _cam_pos.distance_squared_to(_cam_look) > 0.01:
		cam.look_at(_cam_look, Vector3.UP)
	cam.fov = lerpf(CAM_FOV.x, CAM_FOV.y, clampf((boat.v - BoatData.V_CRUISE) / (BoatData.v_max() - BoatData.V_CRUISE), 0.0, 1.0))
