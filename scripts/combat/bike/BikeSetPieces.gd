# File: res://scripts/combat/bike/BikeSetPieces.gd
# Day 2 road set pieces of the bike chase (spec 2026-10-27, D2X-6), owned and ticked by BikeChase (setup opt "set_pieces").
# A data list keyed by route distance (BikeCombatData.DAY2_SET_PIECES): each piece has a telegraph, triggers at its
# distance and re-arms on retry (rearm(checkpoint_s): every piece not wholly behind the checkpoint comes back).
#   melons    {"s"}: a melon truck shows MELON_TRUCK_LEAD m before s ahead in the right lane (hazard lights blinking); at s
#             (or the player 35 m behind it) the tailgate drops with a horn and MELON_N melons (one MultiMesh, analytic
#             bounces, no rigid bodies) roll across the lanes for MELON_S s. A melon hit: MELON_DMG, a wobble, a green and
#             pink splash; a biker that hits one crashes ("melon": a takedown).
#   barrier   {"s"}: a half-lowered barrier arm at chest height across the road but for a slow gap by the right curb
#             (cones); warning signs BARRIER_WARN_M and half of it before; the HUD prompt "[CTRL] CÚI XUỐNG" from the first
#             sign. At s: in the gap = through; ducking (PlayerBike.is_ducking via BikeChase.bike_ducking) = "CÚI NÉ!";
#             else knocked off (a fail, back to the checkpoint; not in god mode). Bikers behind it crash into it one in two.
#   wrong_way {"s", "len"}: cones on the centre line and a taper close the player's (right) carriageway for len m with
#             flashing arrows; the AI targets clamp to the left half (BikeChase.d_lo / d_hi) and a few cars come the other
#             way; riding through the cones costs CONE_DMG.
#   ramp      {"s", "d"}: a marked sand ramp in one lane (d m right of the centre line) by a construction site: over it
#             faster than RAMP_MIN_SPEED = BikeChase.start_jump() (riders alongside fly too: air kick).
#   police    {"s", "end_s", "dur"}: BikeChase.spawn_police(POLICE_N) at s (a retry from past s: POLICE_REJOIN_M after the
#             checkpoint); they drop back after dur s or at end_s. safe_checkpoint_s keeps checkpoints out of a barrier's
#             warning stretch.
#   drift     {"s", "len"}: a real turn marked with chevrons and the prompt "DRIFT!"; through its middle faster than
#             DRIFT_FAST without drifting = into the curb (CURB_DMG, speed x CURB_SLOW: braking into the turn is fine);
#             drifting in it adds DRIFT_ZONE_BONUS charge/s.
# State for tests: pieces (each a Dictionary with "phase": armed | tele | active | done and its own fields), fired(kind),
# melon_hits, cone_hits, curb_hits, results (barrier outcomes). No per-frame allocation; the props are pooled and built
# once in setup().
class_name BikeSetPieces
extends Node3D

const TRUCK_HALF := Vector2(1.15, 3.4)
const MELON_RAD: float = 0.24
const SPLASH_N: int = 2
const POLICE_REJOIN_M: float = 80.0
const ONCOMING_AT: Array[float] = [168.0, 182.0, 196.0]   # beyond the camera's view range (160 m), inside the despawn (200)

var ch: BikeChase
var pieces: Array = []
var counts: Dictionary = {}
var melon_hits: int = 0
var cone_hits: int = 0
var curb_hits: int = 0
var results: Array[String] = []
var oncoming_cars: int = 0
var prompt: String = ""
# melons (one active melon piece at a time)
var melon_mm: MultiMeshInstance3D
var melon_pos := PackedVector3Array()
var melon_vel := PackedVector3Array()
var melon_on := PackedByteArray()
var melon_t: float = -1.0
var melon_floor: float = 0.0
var truck: Node3D
var truck_gate: Node3D
var truck_s: float = 0.0
var truck_d: float = 1.5
var truck_v: float = 0.0
var _hazard: StandardMaterial3D
var _arrow_mat: StandardMaterial3D
var _splash: Array[CPUParticles3D] = []
var _splash_i: int = 0
var _blink_t: float = 0.0
var _cone_cd: float = 0.0
var _xf := Transform3D.IDENTITY


func setup(chase: BikeChase, data: Array) -> void:
	ch = chase
	for d: Variant in data:
		var p: Dictionary = (d as Dictionary).duplicate(true)
		p["phase"] = "armed"
		pieces.append(p)
	_hazard = Readability.telegraph_material("danger", 4.0)    # Q3 telegraph colours: red = danger
	_arrow_mat = Readability.telegraph_material("prompt", 3.0) # yellow = prompt
	for p2: Dictionary in pieces:
		match String(p2.get("kind", "")):
			"melons":
				if truck == null:
					_build_truck()
					_build_melons()
			"barrier":
				_build_barrier(p2)
			"wrong_way":
				_build_wrong_way(p2)
			"ramp":
				_build_ramp(p2)
			"drift":
				_build_drift(p2)
	for i: int in SPLASH_N:
		_splash.append(_make_splash(i))


## Triggers of a kind so far (tests).
func fired(kind: String) -> int:
	return int(counts.get(kind, 0))


func _fire(p: Dictionary, phase: String) -> void:
	var k: String = String(p.get("kind", ""))
	if phase == "active":
		counts[k] = int(counts.get(k, 0)) + 1
	ch.set_piece.emit(k, phase)


## Back to "armed" every piece that ends after cp_s (the checkpoint's route distance; -INF = all), props reset.
## The police: a checkpoint past their start makes them join POLICE_REJOIN_M after it (never on top of the retry).
func rearm(cp_s: float) -> void:
	for p: Dictionary in pieces:
		if _end_s(p) > cp_s + 0.5:
			p["phase"] = "armed"
			p.erase("t")
			p.erase("drifted")
			p.erase("vmid")
			p.erase("bikers_s")
			p.erase("at")
			if String(p.get("kind", "")) == "police" and cp_s > float(p["s"]):
				p["at"] = cp_s + POLICE_REJOIN_M
				if float(p["at"]) >= _end_s(p) - 40.0:
					p["phase"] = "done"          # too little road left for them
	_reset_props()


## A checkpoint at route distance s moved back out of any barrier's warning stretch (to its first sign), else s.
func safe_checkpoint_s(s: float) -> float:
	var out: float = s
	for p: Dictionary in pieces:
		if String(p.get("kind", "")) != "barrier":
			continue
		var bs: float = float(p["s"])
		if s > bs - BikeCombatData.BARRIER_WARN_M and s <= bs + 1.0:
			out = minf(out, bs - BikeCombatData.BARRIER_WARN_M)
	return out


## Everything off (stop).
func clear() -> void:
	for p: Dictionary in pieces:
		p["phase"] = "done"
	_reset_props()


func _reset_props() -> void:
	melon_t = -1.0
	for i: int in melon_on.size():
		melon_on[i] = 0
	if melon_mm:
		melon_mm.visible = false
	if truck:
		truck.visible = false
		truck_gate.rotation.x = 0.0
	ch.d_lo = -INF
	ch.d_hi = INF
	prompt = ""
	if ch.hud:
		ch.hud.set_prompt("")


func _end_s(p: Dictionary) -> float:
	match String(p.get("kind", "")):
		"wrong_way", "drift":
			return float(p["s"]) + float(p.get("len", 0.0))
		"police":
			return float(p.get("end_s", float(p["s"]) + 500.0))
	return float(p["s"])


# ---------------------------------------------------------------------------
# PER FRAME (BikeChase, while running)
# ---------------------------------------------------------------------------
func tick(delta: float, _rdt: float) -> void:
	var s: float = ch.s_p
	if s < 0.0:
		return
	_blink_t += delta
	_cone_cd -= delta
	var blink: bool = int(_blink_t * 3.0) % 2 == 0
	if _hazard:
		_hazard.emission_energy_multiplier = 5.0 if blink else 0.3
	if _arrow_mat:
		_arrow_mat.emission_energy_multiplier = 4.0 if int(_blink_t * 2.5) % 2 == 0 else 0.4
	var want: String = ""
	var want_pri: int = 0
	for p: Dictionary in pieces:
		var ph: String = p["phase"]
		if ph == "done":
			continue
		var k: String = p["kind"]
		var ps: float = float(p["s"])
		match k:
			"melons":
				_tick_melons(p, s, ps, delta)
			"barrier":
				if ph == "armed" and s >= ps - BikeCombatData.BARRIER_WARN_M:
					p["phase"] = "tele"
					_fire(p, "tele")
				if p["phase"] == "tele":
					if want_pri < 3:
						want = BikeCombatData.T_DUCK
						want_pri = 3
					if s >= ps:
						_barrier_cross(p)
				elif p["phase"] == "active":
					_barrier_bikers(p, ps, delta)
			"wrong_way":
				var ln: float = float(p.get("len", 250.0))
				if ph == "armed" and s >= ps - 90.0:
					p["phase"] = "tele"
					_fire(p, "tele")
					if ch.hud:
						ch.hud.popup(BikeCombatData.T_WRONG_WAY, CombatHUD.WARN, 2.0)
				if p["phase"] == "tele" and s >= ps - 30.0:
					p["phase"] = "active"
					_fire(p, "active")
					_oncoming(ps, ln)
				if p["phase"] == "active":
					_clamp_left(true)
					if s >= ps and s <= ps + ln and ch.d_p * ch.dir_sign > 0.35 and _cone_cd <= 0.0:
						_cone_cd = BikeCombatData.CONE_CD
						cone_hits += 1
						if ch.combat.damage(BikeCombatData.CONE_DMG, "cones"):   # the slowdown comes with the damage (not in god mode)
							ch.bike.current_speed_ms *= 0.85
						ch.cue("tray_clang", ch.bike.global_position, -2.0)
						if ch.hud:
							ch.hud.popup(BikeCombatData.T_CONES, CombatHUD.WARN, 0.7)
					if s > ps + ln:
						_clamp_left(false)
						p["phase"] = "done"
						_fire(p, "done")
					elif want_pri < 2 and s < ps + 40.0:
						want = BikeCombatData.T_WRONG_WAY
						want_pri = 2
			"ramp":
				if ph == "armed" and s >= ps - 60.0:
					p["phase"] = "tele"
					_fire(p, "tele")
				if p["phase"] == "tele" and s >= ps:
					p["phase"] = "done"
					var lat: float = ch.d_p * ch.dir_sign
					var sp: float = absf(ch.bike.current_speed_ms)
					if absf(lat - float(p.get("d", 1.4))) <= BikeCombatData.RAMP_HALF_W and sp >= BikeCombatData.RAMP_MIN_SPEED and not ch.jumping():
						_fire(p, "active")
						ch.start_jump()
					elif absf(lat - float(p.get("d", 1.4))) <= BikeCombatData.RAMP_HALF_W:
						ch.bike.add_camera_shake(0.35)
					_fire(p, "done")
			"police":
				if ph == "armed" and s >= float(p.get("at", ps)):
					p["phase"] = "active"
					p["t"] = 0.0
					_fire(p, "active")
					ch.spawn_police(BikeCombatData.POLICE_N)
				elif ph == "active":
					p["t"] = float(p["t"]) + delta
					if float(p["t"]) >= float(p.get("dur", BikeCombatData.POLICE_S)) or s >= float(p.get("end_s", INF)):
						p["phase"] = "done"
						ch.release_police()
						_fire(p, "done")
						if ch.hud:
							ch.hud.popup(BikeCombatData.T_POLICE_GONE, CombatHUD.GOLD, 1.4)
			"drift":
				var ln2: float = float(p.get("len", 30.0))
				if ph == "armed" and s >= ps - 45.0:
					p["phase"] = "tele"
					p["drifted"] = false
					_fire(p, "tele")
				if p["phase"] == "tele" and s >= ps:
					p["phase"] = "active"
					_fire(p, "active")
				if p["phase"] == "tele" or p["phase"] == "active":
					if want_pri < 1:
						want = BikeCombatData.T_DRIFT
						want_pri = 1
				if p["phase"] == "active":
					if not p.has("vmid") and s >= ps + ln2 * 0.5:
						p["vmid"] = absf(ch.bike.current_speed_ms)   # the apex: braking into the turn is fine
					if ch.bike.is_drifting:
						p["drifted"] = true
						ch.add_charge(BikeCombatData.DRIFT_ZONE_BONUS * delta)
					if s >= ps + ln2:
						p["phase"] = "done"
						if not bool(p["drifted"]) and float(p.get("vmid", absf(ch.bike.current_speed_ms))) > BikeCombatData.DRIFT_FAST:
							curb_hits += 1
							if ch.combat.damage(BikeCombatData.CURB_DMG, "curb"):
								ch.bike.current_speed_ms *= BikeCombatData.CURB_SLOW
							ch.bike.add_camera_shake(0.6)
							ch.sparks(ch.bike.global_position + Vector3(0.0, 0.2, 0.0), Vector3.UP)
							ch.cue("impact_medium", ch.bike.global_position, 0.0)
							if ch.hud:
								ch.hud.popup(BikeCombatData.T_CURB, CombatHUD.WARN, 1.0)
						_fire(p, "done")
	if want != prompt:
		prompt = want
		if ch.hud:
			ch.hud.set_prompt(want, CombatHUD.WARN if want_pri >= 2 else CombatHUD.GOLD)
	if melon_t >= 0.0:
		_tick_melon_balls(delta)


func _clamp_left(on: bool) -> void:
	if on:
		if ch.dir_sign >= 0.0:
			ch.d_hi = -0.4
			ch.d_lo = -INF
		else:
			ch.d_lo = 0.4
			ch.d_hi = INF
	else:
		ch.d_lo = -INF
		ch.d_hi = INF


# ----- barrier -----
func _barrier_cross(p: Dictionary) -> void:
	p["phase"] = "active"
	p["t"] = 0.0
	p["bikers_s"] = {}
	_fire(p, "active")
	var lat: float = ch.d_p * ch.dir_sign
	var hw: float = ch.route.half_width if ch.route else BikeCombatData.ROAD_HALF
	var res: String
	if lat >= hw - BikeCombatData.BARRIER_GAP_W - 0.15:
		res = "gap"
	elif ch.bike_ducking():
		res = "ducked"
		if ch.hud:
			ch.hud.popup(BikeCombatData.T_DUCKED, CombatHUD.GOLD, 1.0)
		ch.cue("whoosh_down", ch.bike.global_position + Vector3(0.0, 1.2, 0.0), 0.0)
	else:
		res = "hit"
		ch.cue("impact_heavy", ch.bike.global_position + Vector3(0.0, 1.2, 0.0), 2.0)
		if ch.hud:
			ch.hud.popup(BikeCombatData.T_BARRIER_HIT, CombatHUD.WARN, 1.6)
		if not ch.combat.god:
			ch.combat.knock_off()
	results.append(res)


## Bikers crossing behind the player: one in two slams into the arm (a takedown), the others duck under it.
func _barrier_bikers(p: Dictionary, ps: float, delta: float) -> void:
	p["t"] = float(p["t"]) + delta
	var seen: Dictionary = p["bikers_s"]
	for b: Variant in ch.bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e == null or not is_instance_valid(e) or not e.is_active() or seen.has(e):
			continue
		var es: float = ch.route.project(e.pos2, ps, 30.0).x if ch.route else 0.0
		if absf(es - ps) < 1.2:
			seen[e] = true
			if e.kind != "pickup" and seen.size() % 2 == 1:
				e.crash("barrier", -ch.p_fwd * 4.0)
	if float(p["t"]) > 8.0:
		p["phase"] = "done"
		_fire(p, "done")


# ----- wrong way: a few cars the other way -----
## RoamTraffic has no public "spawn here" call (only spawn_police), so this uses its internal _activate / _park the way its
## own _maintain does: each car appears ONCOMING_AT m ahead (beyond the 160 m view range both RoamTraffic and BikeChase use
## for "in view", so no pop-in), and a civil car out of view behind the player is parked for it so the active count stays
## at RoamTraffic's target (its _maintain would park the farthest car otherwise, maybe this one).
func _oncoming(ps: float, _ln: float) -> void:
	var tr: RoamTraffic = ch.traffic
	if tr == null or ch.route == null:
		return
	var n: int = 0
	for k: int in ONCOMING_AT.size():
		var at: float = clampf(ch.s_p + ONCOMING_AT[k] * ch.dir_sign, 0.0, ch.route.length)
		if (at - ps) * ch.dir_sign < 20.0:
			continue
		var want: Vector2 = ch.route.world(at, -1.5 * ch.dir_sign)
		if ch.in_view(Vector3(want.x, ch.bike.global_position.y + 1.0, want.y)):
			continue
		var opp: Vector2 = -ch.route.tangent(at) * ch.dir_sign
		var best_l: int = -1
		var best_s: float = 0.0
		var best_d: float = 6.0
		for l: int in tr.lane_pts.size():
			var pts: PackedVector2Array = tr.lane_pts[l]
			var cum: PackedFloat32Array = tr.lane_cum[l]
			for i: int in pts.size() - 1:
				var a: Vector2 = pts[i]
				var ab: Vector2 = pts[i + 1] - a
				if ab.normalized().dot(opp) < 0.8:
					continue
				var u: float = clampf((want - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
				var dd: float = (a + ab * u).distance_to(want)
				if dd < best_d:
					best_d = dd
					best_l = l
					best_s = cum[i] + ab.length() * u
		if best_l < 0:
			continue
		var spare: RoamTraffic.Vehicle = null
		var far: RoamTraffic.Vehicle = null
		var far_d: float = 60.0
		for v: Variant in tr.vehicles:
			var c: RoamTraffic.Vehicle = v
			if c.police:
				continue
			if not c.active and c.kind == RoamTraffic.Kind.CAR and spare == null:
				spare = c
			elif c.active and (c.pos - ch.p_pos).dot(ch.p_fwd) < 0.0 and c.pos.distance_to(ch.p_pos) > far_d 					and not ch.in_view(Vector3(c.pos.x, ch.bike.global_position.y + 1.0, c.pos.y)):
				far_d = c.pos.distance_to(ch.p_pos)
				far = c
		if spare == null:
			continue
		if far != null:
			tr._park(far)
		tr._activate(spare, best_l, best_s)
		n += 1
	oncoming_cars = n


# ----- melons -----
func _tick_melons(p: Dictionary, s: float, ps: float, delta: float) -> void:
	var ph: String = p["phase"]
	if ph == "armed" and s >= ps - BikeCombatData.MELON_TRUCK_LEAD - 40.0:
		p["phase"] = "tele"
		_fire(p, "tele")
		truck_s = minf(s + 75.0, ps)
		truck_d = 1.5
		truck_v = BikeCombatData.TRUCK_SPEED
		truck.visible = true
		truck_gate.rotation.x = 0.0
		_place_truck()
		ch.cue("horn", truck.global_position + Vector3(0.0, 1.5, 0.0), 0.0, 0.7)
	if p["phase"] == "tele":
		truck_s += truck_v * delta * ch.dir_sign
		_place_truck()
		var gap: float = (truck_s - s) * ch.dir_sign
		if truck_s * ch.dir_sign >= ps * ch.dir_sign or gap < 35.0:
			p["phase"] = "active"
			p["t"] = 0.0
			_fire(p, "active")
			_drop_melons()
	elif p["phase"] == "active":
		p["t"] = float(p["t"]) + delta
		truck_v = minf(truck_v + 6.0 * delta, 24.0)
		truck_s += truck_v * delta * ch.dir_sign
		truck_gate.rotation.x = minf(truck_gate.rotation.x + delta * 6.0, 1.5)
		_place_truck()
		if float(p["t"]) > BikeCombatData.MELON_S + 0.5:
			p["phase"] = "done"
			_fire(p, "done")
			truck.visible = false


func _place_truck() -> void:
	if ch.route == null:
		return
	var q: Vector2 = ch.route.world(clampf(truck_s, 0.0, ch.route.length), truck_d * ch.dir_sign)
	var t: Vector2 = ch.route.tangent(clampf(truck_s, 0.0, ch.route.length)) * ch.dir_sign
	var y: float = ch.bike.global_position.y + BikeChase.BIKE_FLOOR_OFFSET
	truck.global_transform = Transform3D(Basis(Vector3.UP, atan2(-t.x, -t.y)), Vector3(q.x, y, q.y))
	# the truck is an analytic obstacle: the player riding into it
	var rel: Vector2 = ch.p_pos - q
	var tr := Vector2(-t.y, t.x)
	if absf(rel.dot(t)) < TRUCK_HALF.y + 0.9 and absf(rel.dot(tr)) < TRUCK_HALF.x + 0.4 and ch.combat.ram_cd <= 0.0:
		ch.combat.ram_cd = BikeCombatData.RAM_COOLDOWN
		if ch.combat.damage(BikeCombatData.CRASH_DMG_MIN, "crash"):
			ch.bike.current_speed_ms = minf(ch.bike.current_speed_ms, truck_v * 0.8)
		ch.bike.add_camera_shake(0.6)


func _drop_melons() -> void:
	melon_t = 0.0
	melon_floor = ch.bike.global_position.y + BikeChase.BIKE_FLOOR_OFFSET
	var tail: Vector3 = truck.global_transform * Vector3(0.0, 1.3, TRUCK_HALF.y)
	var t: Vector2 = ch.route.tangent(clampf(truck_s, 0.0, ch.route.length)) * ch.dir_sign
	var r := Vector2(-t.y, t.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = ch.chase_seed * 31 + 7
	for i: int in BikeCombatData.MELON_N:
		var fwd: float = truck_v * rng.randf_range(0.15, 0.55)
		var side: float = rng.randf_range(-4.5, 3.0)
		melon_pos[i] = tail + Vector3(r.x, 0.0, r.y) * rng.randf_range(-0.8, 0.8) + Vector3(0.0, rng.randf_range(0.0, 0.5), 0.0)
		melon_vel[i] = Vector3(t.x * fwd + r.x * side, rng.randf_range(0.5, 3.0), t.y * fwd + r.y * side)
		melon_on[i] = 1
	melon_mm.visible = true
	ch.cue("horn", tail, 2.0, 0.6)
	ch.cue("crate_smash", tail, 0.0)
	if ch.hud:
		ch.hud.popup(BikeCombatData.T_MELONS, CombatHUD.WARN, 1.6)


func _tick_melon_balls(delta: float) -> void:
	melon_t += delta
	var hw: float = (ch.route.half_width if ch.route else BikeCombatData.ROAD_HALF) + 1.2
	var any: bool = false
	var mm: MultiMesh = melon_mm.multimesh
	for i: int in melon_on.size():
		if melon_on[i] == 0:
			continue
		any = true
		var p: Vector3 = melon_pos[i]
		var v: Vector3 = melon_vel[i]
		v.y -= BikeCombatData.GRAVITY * delta
		p += v * delta
		if p.y < melon_floor + MELON_RAD:
			p.y = melon_floor + MELON_RAD
			v.y = absf(v.y) * 0.45 if absf(v.y) > 1.2 else 0.0
			v.x *= 1.0 - 0.35 * delta
			v.z *= 1.0 - 0.35 * delta
		if ch.route:
			var pr: Vector2 = ch.route.project(Vector2(p.x, p.z), truck_s, 60.0)
			if absf(pr.y) > hw:   # off the kerb: bounce back
				var n2: Vector2 = ch.route.right(pr.x) * signf(pr.y)
				var vn: float = Vector2(v.x, v.z).dot(n2)
				if vn > 0.0:
					v.x -= n2.x * vn * 1.6
					v.z -= n2.y * vn * 1.6
		melon_pos[i] = p
		melon_vel[i] = v
		if melon_t > BikeCombatData.MELON_S:
			melon_on[i] = 0
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), p))
			continue
		var spin: float = melon_t * 9.0 + float(i)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3(1.0, 0.0, 0.3).normalized(), spin).scaled(Vector3(1.0, 0.85, 1.15)), p))
		var p2 := Vector2(p.x, p.z)
		# the player
		if ch.state == "running" and p2.distance_to(ch.p_pos) < BikeCombatData.MELON_R and absf(p.y - melon_floor) < 1.2:
			melon_on[i] = 0
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), p))
			melon_hits += 1
			if ch.combat.damage(BikeCombatData.MELON_DMG, "melon"):
				ch.bike.current_speed_ms *= 0.8
			ch.bike.add_camera_shake(0.5)
			_splat(p)
			if ch.hud:
				ch.hud.popup(BikeCombatData.T_MELON_HIT, CombatHUD.WARN, 0.8)
			continue
		# the bikers (a crash: takedown "melon")
		for b: Variant in ch.bikers:
			var e: BikerEnemy = b as BikerEnemy
			if e == null or not is_instance_valid(e) or not e.is_active():
				continue
			if e.pos2.distance_to(p2) < BikeCombatData.MELON_R + (1.0 if e.kind == "pickup" else 0.0):
				melon_on[i] = 0
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), p))
				_splat(p)
				e.crash("melon", e.vel.normalized() * 2.0 if e.vel.length() > 0.5 else Vector2.ZERO)
				break
	if not any or melon_t > BikeCombatData.MELON_S + 0.5:
		melon_t = -1.0
		melon_mm.visible = false


func _splat(p: Vector3) -> void:
	var e: CPUParticles3D = _splash[_splash_i]
	_splash_i = (_splash_i + 1) % _splash.size()
	e.global_position = p
	e.restart()
	ch.cue("impact_light", p, 0.0)


# ---------------------------------------------------------------------------
# PROPS (built once)
# ---------------------------------------------------------------------------
## Map transform on the route at s, d (d right of the travel direction), on the floor, facing along the route.
func route_xf(s: float, d: float) -> Transform3D:
	var q: Vector2 = ch.route.world(clampf(s, 0.0, ch.route.length), d * ch.dir_sign) if ch.route else Vector2.ZERO
	var t: Vector2 = (ch.route.tangent(clampf(s, 0.0, ch.route.length)) if ch.route else Vector2(0.0, -1.0)) * ch.dir_sign
	var y: Variant = ch.floor_at(Vector3(q.x, MapBuilder.ROAD_Y, q.y), 30.0, 10.0)
	var fy: float = float(y) if y is float else MapBuilder.ROAD_Y
	return Transform3D(Basis(Vector3.UP, atan2(-t.x, -t.y)), Vector3(q.x, fy, q.y))


func _hw() -> float:
	return ch.route.half_width if ch.route else BikeCombatData.ROAD_HALF


func _build_truck() -> void:
	truck = Node3D.new()
	truck.name = "MelonTruck"
	truck.top_level = true
	add_child(truck)
	var body: Material = PropBuilder.paint(Color("#3E6E3A"))
	var dark: Material = PropBuilder.black_plastic()
	CharacterBuilder._box(truck, Vector3(0.0, 0.75, 0.0), Vector3(2.2, 0.5, 6.6), dark)              # chassis
	CharacterBuilder._box(truck, Vector3(0.0, 1.55, -2.55), Vector3(2.2, 1.5, 1.5), PropBuilder.paint(Color("#E8E3D2")))   # cab
	CharacterBuilder._box(truck, Vector3(0.0, 1.85, -3.28), Vector3(2.0, 0.6, 0.05), PropBuilder.glass_dark())
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._box(truck, Vector3(sx * 1.08, 1.45, 0.7), Vector3(0.06, 0.9, 4.9), body)   # bed walls
		for z: float in [-2.4, 0.4, 2.2]:
			PropBuilder.build_wheel(truck, Vector3(sx * 0.98, 0.45, z), 0.45, 0.3, 5, Color("#7A8086"))
		CineFX._box(truck, "Hazard", Vector3(0.22, 0.14, 0.05), Vector3(sx * 0.85, 1.0, 3.32), _hazard)
		var sign := Label3D.new()
		sign.name = "Sign"
		sign.text = BikeCombatData.T_TRUCK_SIGN
		sign.font_size = 96
		sign.pixel_size = 0.008
		sign.outline_size = 12
		sign.modulate = Color("#FFF3B0")
		sign.position = Vector3(sx * 1.13, 1.55, 0.7)
		sign.rotation.y = -sx * PI * 0.5
		truck.add_child(sign)
	var melon_mat: StandardMaterial3D = CineFX._mat(Color("#2E7D32"), 0.6)
	for i: int in 9:
		CineFX._sphere(truck, "Load", 0.3, Vector3(-0.7 + 0.7 * float(i % 3), 1.25 + 0.25 * float(i / 6), -0.6 + 1.3 * float(i / 3)), melon_mat, Vector3(1.0, 0.85, 1.15))
	truck_gate = Node3D.new()
	truck_gate.name = "Tailgate"
	truck_gate.position = Vector3(0.0, 1.0, 3.15)
	truck.add_child(truck_gate)
	CharacterBuilder._box(truck_gate, Vector3(0.0, 0.45, 0.0), Vector3(2.2, 0.9, 0.06), body)
	truck.visible = false


func _build_melons() -> void:
	melon_mm = MultiMeshInstance3D.new()
	melon_mm.name = "Melons"
	melon_mm.top_level = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = MELON_RAD
	sm.height = MELON_RAD * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mm.mesh = sm
	mm.instance_count = BikeCombatData.MELON_N
	melon_mm.multimesh = mm
	var mat: StandardMaterial3D = CineFX._mat(Color("#2F8A34"), 0.55)
	melon_mm.material_override = mat
	melon_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(melon_mm)
	melon_mm.global_transform = Transform3D.IDENTITY
	melon_pos.resize(BikeCombatData.MELON_N)
	melon_vel.resize(BikeCombatData.MELON_N)
	melon_on.resize(BikeCombatData.MELON_N)
	for i: int in BikeCombatData.MELON_N:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	melon_mm.visible = false


func _make_splash(i: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "MelonSplash%d" % i
	p.top_level = true
	p.emitting = false
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0.0, -14.0, 0.0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	p.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	var g := Gradient.new()
	g.set_color(0, Color("#FF5C8A"))
	g.set_color(1, Color("#2E7D32"))
	p.color_initial_ramp = g
	add_child(p)
	return p


func _build_barrier(p: Dictionary) -> void:
	var s: float = float(p["s"])
	var hw: float = _hw()
	var root := Node3D.new()
	root.name = "Barrier"
	root.top_level = true
	add_child(root)
	var xf: Transform3D = route_xf(s, 0.0)
	root.global_transform = xf
	var yel: Material = CineFX._mat(Color("#F2C230"), 0.6)
	var blk: Material = CineFX._mat(Color("#1A1A1A"), 0.6)
	var post: Material = PropBuilder.steel()
	var x0: float = -hw - 0.3
	var x1: float = hw - BikeCombatData.BARRIER_GAP_W
	CharacterBuilder._box(root, Vector3(x0, BikeCombatData.BARRIER_Y * 0.5, 0.0), Vector3(0.18, BikeCombatData.BARRIER_Y + 0.2, 0.18), post)
	CharacterBuilder._box(root, Vector3(x1 + 0.1, BikeCombatData.BARRIER_Y * 0.5, 0.0), Vector3(0.14, BikeCombatData.BARRIER_Y, 0.14), post)
	var n: int = 10
	var w: float = (x1 - x0) / float(n)
	for i: int in n:
		CharacterBuilder._box(root, Vector3(x0 + w * (float(i) + 0.5), BikeCombatData.BARRIER_Y, 0.0), Vector3(w, 0.16, 0.12), yel if i % 2 == 0 else blk)
	CineFX._box(root, "Lamp", Vector3(0.16, 0.16, 0.16), Vector3(x0, BikeCombatData.BARRIER_Y + 0.25, 0.0), _hazard)
	# the slow gap: cones funnel to the right curb
	for k: int in 4:
		_cone(root, Vector3(x1 + 0.1, 0.0, 2.0 + 2.0 * float(k)))
		_cone(root, Vector3(hw + 0.4, 0.0, 2.0 + 2.0 * float(k)))
	for warn: float in [BikeCombatData.BARRIER_WARN_M, BikeCombatData.BARRIER_WARN_M * 0.5]:
		_sign(route_xf(s - warn, hw + 0.8), BikeCombatData.T_BARRIER_SIGN)


func _build_wrong_way(p: Dictionary) -> void:
	var s: float = float(p["s"])
	var ln: float = float(p.get("len", 250.0))
	var hw: float = _hw()
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WrongWayCones"
	mmi.top_level = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _cone_mesh()
	var xfs: Array[Transform3D] = []
	var taper: int = 6
	for k: int in taper:   # the taper across the right half before the closure
		var u: float = float(k) / float(taper - 1)
		xfs.append(route_xf(s - 24.0 + 4.0 * float(k), lerpf(hw - 0.3, 0.3, u)))
	var z: float = s
	while z <= s + ln:
		xfs.append(route_xf(z, 0.25))
		z += 6.0
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	mmi.multimesh = mm
	mmi.material_override = CineFX._mat(Color("#FF6A1A"), 0.5)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY
	for a: float in [s - 60.0, s - 20.0, s + ln * 0.5]:
		_arrow(route_xf(a, hw * 0.55))


func _build_ramp(p: Dictionary) -> void:
	var s: float = float(p["s"])
	var d: float = float(p.get("d", 1.4))
	var root := Node3D.new()
	root.name = "SandRamp"
	root.top_level = true
	add_child(root)
	root.global_transform = route_xf(s, d)
	var sand: StandardMaterial3D = CineFX._mat(Color("#D9B26F"), 0.95)
	var ramp := MeshInstance3D.new()
	ramp.name = "Ramp"
	var pm := PrismMesh.new()
	pm.left_to_right = 1.0
	pm.size = Vector3(4.0, 0.9, 2.4)      # rotated: 4 m long up to its lip at s, 2.4 m wide
	ramp.mesh = pm
	ramp.material_override = sand
	ramp.rotation = Vector3(0.0, PI * 0.5, 0.0)
	ramp.position = Vector3(0.0, 0.45, 2.0)
	root.add_child(ramp)
	for sx: float in [-1.0, 1.0]:
		CharacterBuilder._cyl(root, Vector3(sx * 1.4, 0.7, 0.4), 0.02, 0.02, 1.4, PropBuilder.steel())
		CineFX._box(root, "Flag", Vector3(0.02, 0.3, 0.45), Vector3(sx * 1.4, 1.25, 0.6), CineFX._glow_mat(Color(1.0, 0.45, 0.1), 1.5))
	var edge: float = _hw() - d                # the right kerb seen from the ramp
	for k: int in 3:   # the construction site beside it: sand piles and a fence
		CineFX._sphere(root, "Pile", 1.1, Vector3(edge + 2.6 + 1.2 * float(k), 0.0, -2.0 + 2.4 * float(k)), sand, Vector3(1.4, 0.55, 1.2))
	CharacterBuilder._box(root, Vector3(edge + 1.3, 0.9, 0.0), Vector3(0.08, 1.8, 10.0), CineFX._mat(Color("#2D6CB5"), 0.7))


func _build_drift(p: Dictionary) -> void:
	if ch.route == null:
		return
	var s: float = float(p["s"])
	var ln: float = float(p.get("len", 30.0))
	var t0: Vector2 = ch.route.tangent(maxf(s, 0.0))
	var t1: Vector2 = ch.route.tangent(minf(s + ln, ch.route.length))
	var turn: float = t0.cross(t1) * ch.dir_sign   # > 0: the route turns right (screen) ... the outside is the left
	var outside: float = -1.0 if turn > 0.0 else 1.0
	var hw: float = _hw()
	for k: int in 3:
		var a: float = s + ln * (0.25 + 0.3 * float(k))
		var xf: Transform3D = route_xf(a, outside * (hw + 1.0))
		_chevron(xf, -outside)


func _cone_mesh() -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.2
	cm.height = 0.6
	cm.radial_segments = 8
	cm.rings = 1
	return cm


func _cone(parent: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Cone"
	mi.mesh = _cone_mesh()
	mi.material_override = CineFX._mat(Color("#FF6A1A"), 0.5)
	mi.position = pos + Vector3(0.0, 0.3, 0.0)
	parent.add_child(mi)


func _sign(xf: Transform3D, text: String) -> void:
	var root := Node3D.new()
	root.name = "WarnSign"
	root.top_level = true
	add_child(root)
	root.global_transform = xf             # its face (+Z) toward the player coming from behind
	CharacterBuilder._cyl(root, Vector3(0.0, 0.9, 0.0), 0.04, 0.04, 1.8, PropBuilder.steel())
	CharacterBuilder._box(root, Vector3(0.0, 2.05, 0.0), Vector3(1.6, 0.9, 0.06), CineFX._mat(Color("#F2C230"), 0.6))
	CineFX._box(root, "Blink", Vector3(0.14, 0.14, 0.1), Vector3(0.0, 2.62, 0.0), _hazard)
	var l := Label3D.new()
	l.name = "Text"
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.005
	l.modulate = Color("#1A1A1A")
	l.outline_size = 0
	l.position = Vector3(0.0, 2.05, 0.05)
	root.add_child(l)


func _arrow(xf: Transform3D) -> void:
	var root := Node3D.new()
	root.name = "ArrowSign"
	root.top_level = true
	add_child(root)
	root.global_transform = xf
	CharacterBuilder._box(root, Vector3(0.0, 0.55, 0.0), Vector3(1.6, 1.0, 0.12), CineFX._mat(Color("#1A1A1A"), 0.6))
	for k: int in 2:   # a "<" of two bars pointing to the open (left) half, seen by the oncoming player
		var bar := MeshInstance3D.new()
		bar.name = "Bar"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 0.14, 0.05)
		bar.mesh = bm
		bar.material_override = _arrow_mat
		bar.position = Vector3(0.05, 0.55 + (0.17 if k == 0 else -0.17), 0.07)
		bar.rotation.z = 0.5 if k == 0 else -0.5
		root.add_child(bar)


func _chevron(xf: Transform3D, point: float) -> void:
	var root := Node3D.new()
	root.name = "Chevron"
	root.top_level = true
	add_child(root)
	root.global_transform = xf
	CharacterBuilder._cyl(root, Vector3(0.0, 0.6, 0.0), 0.04, 0.04, 1.2, PropBuilder.steel())
	CharacterBuilder._box(root, Vector3(0.0, 1.45, 0.0), Vector3(1.2, 0.7, 0.06), CineFX._mat(Color("#0E3A44"), 0.6))
	var white: StandardMaterial3D = Readability.telegraph_material("zone", 1.6)   # Q3: cyan = drift zone
	for k: int in 2:
		for j: int in 2:
			var bar := MeshInstance3D.new()
			bar.name = "Chev"
			var bm := BoxMesh.new()
			bm.size = Vector3(0.36, 0.09, 0.03)
			bar.mesh = bm
			bar.material_override = white
			bar.position = Vector3(-0.25 + 0.4 * float(k), 1.45 + (0.11 if j == 0 else -0.11), 0.05)
			bar.rotation.z = (-0.7 if j == 0 else 0.7) * point
			root.add_child(bar)
