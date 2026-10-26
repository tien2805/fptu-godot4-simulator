# File: res://scripts/combat/bike/BikeChase.gd
# Encounter node of the Phase C bike combat (spec C-D1): the Day 2 chase on the real Nguyễn Xiển road (FreeRoam), the
# player kicking Bầy Sói bikers off their scooters, wave after wave, then the short replay seg_d2_chase.
#
# ===== API (for the story integration) =====
#   var chase := BikeChase.new()
#   roam.add_child(chase)                       # FreeRoam (any Node3D parent works)
#   chase.setup({"roam": roam,                  # FreeRoam: bike, player, traffic, md and the combat FX read from it; or
#                                               #   pass "bike" (PlayerBike) [+ "player", "traffic"] without a FreeRoam
#       "route": null,                          # default: BikeRoute.nguyen_xien(roam.md) (Nguyễn Xiển northbound, the
#                                               #   Rạch Hầm bridge at ~356 m, then Nguyễn Văn Tăng as run-off, 2.1 km);
#                                               #   a BikeRoute, points (Vector2(x, z) / Vector3 / [x, z]) or [] (free
#                                               #   mode: the AI works in the player's heading frame)
#       "half_width": 3.6,                      # lateral room the AI keeps to on the route (m)
#       "start_s": 60.0, "place": true,         # start() puts the rider there on the route, facing along it (false: the
#                                               #   chase starts wherever the player rides); "start_speed": 0.0 (m/s)
#       "max_attackers": 2,                     # bikers kicking at once (attack starts at least 0.8 s apart)
#       "auto_checkpoint": true,                # every wave start is a checkpoint
#       "start_line": "", "win_line": "",       # centre popups; Day 2: BikeCombatData.T_START_D2 / T_WIN_D2
#       "replay_slot": "seg_d2_chase",          # owner music file of the replay (none = silent)
#       "auto_replay": true,                    # the replay plays by itself when the last biker falls
#       "manual_replay": false,                 # tests: CineReplay.step() drives it
#       "seed": 1,
#       "waves": []})                           # optional: the waves right away (same as add_wave per entry)
#   chase.add_wave([                            # once per wave, in order (BikeChase.day2_waves(): the Day 2 layout 3 + 3)
#       {"from": "behind",                      # "behind" (default, ~16 m back, out of view) | "ahead" (~60 m ahead)
#        "lane": -1,                            # -1 left, 0 middle, +1 right of the player
#        "gap": 0.0, "delay": 0.0,              # extra spawn distance (m), seconds after the wave start
#        "opts": {"label": "Sói Đen", "hp": 1, "aggression": 0.5, "eye_color": Color(...), "paint": Color(...),
#                 "body": {...}, "body_fn": Callable}},   # BikerEnemy opts (look passed in by the caller)
#       ...])
#   chase.won.connect(...)                      # after the replay (at once with auto_replay false / no footage)
#   chase.lost.connect(...)                     # stability 0, the player knocked off: show "TOANG!", then retry()
#   chase.biker_down.connect(func(b: BikerEnemy, cause: String): ...)   # cause "kick" | "traffic" | ...
#   chase.wave_started / wave_cleared (index)
#   chase.start()                               # mounts the player (FreeRoam.mount_bike) and places the bike if asked
#   chase.checkpoint()                          # remember the wave + the bike's transform (automatic per wave)
#   chase.retry()                               # bikers removed, stability full, bike back at the checkpoint, that wave
#   chase.stop()                                # end without a result (bikers freed, bike unlocked, hooks cleared)
#   chase.play_replay() -> CineReplay           # the replay by hand (auto_replay false); null without footage
#   chase.alive() -> Array, chase.remaining() -> int, chase.state, chase.wave, chase.combat (PlayerBikeCombat)
#   state: "idle" | "running" | "finishing" (last biker down: 0.8 s more footage, then the replay) | "won" | "lost"
# While it runs: Q / E kick (PlayerBikeCombat), FreeRoam's hint shows the kick keys (FreeRoam.riding_hint) and [F]
# refuses to get off the bike (FreeRoam.dismount_refusal); the traffic brakes for the bikers
# (RoamTraffic.extra_obstacles_fn). The phone and the emotes are already off while riding. stop(), lost and freeing the
# chase clear those hooks; stop() / retry() / freeing also unlock and right the bike. The chase never changes the story
# state, the time of day, the music or the camera, and never references an autoload by name.
# ===========================================
class_name BikeChase
extends Node3D

signal won
signal lost
signal biker_down(biker: BikerEnemy, cause: String)
signal wave_started(index: int)
signal wave_cleared(index: int)

const BIKE_FLOOR_OFFSET: float = 0.13    # = FreeRoam.BIKE_FLOOR_OFFSET: the PlayerBike origin sits 0.13 m under the floor
const BEHIND_M: float = 16.0
const AHEAD_M: float = 60.0
const SPAWN_STEP_M: float = 4.0
const LANE_M: float = 2.2

var roam: Node = null
var bike: PlayerBike
var player: Node3D
var traffic: RoamTraffic
var route: BikeRoute
var half_width: float = BikeCombatData.ROAD_HALF
var start_s: float = 60.0
var start_speed: float = 0.0
var place_rider: bool = true
var max_attackers: int = BikeCombatData.MAX_ATTACKERS
var auto_checkpoint: bool = true
var start_line: String = ""
var win_line: String = ""
var replay_slot: String = "seg_d2_chase"
var auto_replay: bool = true
var manual_replay: bool = false
var chase_seed: int = 1
var waves: Array = []
var wave: int = -1
var state: String = "idle"
## BikerEnemy of the current wave (the same Array is PlayerBikeCombat.targets: never reassigned).
var bikers: Array = []
var pending: Array = []                  # [spawn Dictionary, seconds left] of the current wave
var combat: PlayerBikeCombat
var hud: BikeHUD
var fx: WeaponFX
var rec: CineReplayRecorder
var replay: CineReplay
var downed_total: int = 0
var boxed: bool = false
var boxed_count: int = 0
var max_attackers_seen: int = 0
var last_down: BikerEnemy = null
# the player's frame, updated every physics frame (BikerEnemy reads it)
var p_pos: Vector2 = Vector2.ZERO
var p_vel: Vector2 = Vector2.ZERO
var p_fwd: Vector2 = Vector2(0.0, -1.0)
var p_right: Vector2 = Vector2(1.0, 0.0)
var b_fwd: Vector2 = Vector2(0.0, -1.0)           # the player bike's own heading (kick checks)
var b_right: Vector2 = Vector2(1.0, 0.0)
var s_p: float = -1.0
var d_p: float = 0.0
var dir_sign: float = 1.0
var on_route: bool = false
var _cp: Dictionary = {}
var _holders: Array = []
var _t: float = 0.0
var _last_attack_t: float = -99.0
var _role_t: float = 0.0
var _gap_left: float = -1.0
var _finish_left: float = -1.0
var _box_cd: float = 0.0
var _spawned: int = 0
var _wave_spawned: int = 0
var _ray_excl: Array[RID] = []
var _ray_q: PhysicsRayQueryParameters3D
var _obstacles: Array = []
var _act: Array = []
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_i: int = 0
var _hooks: bool = false


func setup(opts: Dictionary) -> void:
	roam = opts.get("roam", null)
	if roam:
		bike = roam.get("bike")
		player = roam.get("player")
		traffic = roam.get("traffic")
	if opts.has("bike"):
		bike = opts["bike"]
	if opts.has("player"):
		player = opts["player"]
	if opts.has("traffic"):
		traffic = opts["traffic"]
	half_width = float(opts.get("half_width", BikeCombatData.ROAD_HALF))
	route = null
	if not opts.has("route") or opts["route"] == null:
		var md: MapData = roam.get("md") if roam else null
		route = BikeRoute.nguyen_xien(md) if md else null
	elif opts["route"] is BikeRoute:
		route = opts["route"]
	else:
		route = BikeRoute.from_points(opts["route"], half_width)
	if route and not route.valid():
		route = null
	if route:
		route.half_width = half_width
	start_s = float(opts.get("start_s", 60.0))
	start_speed = float(opts.get("start_speed", 0.0))
	place_rider = bool(opts.get("place", true))
	max_attackers = int(opts.get("max_attackers", BikeCombatData.MAX_ATTACKERS))
	auto_checkpoint = bool(opts.get("auto_checkpoint", true))
	start_line = String(opts.get("start_line", ""))
	win_line = String(opts.get("win_line", ""))
	replay_slot = String(opts.get("replay_slot", "seg_d2_chase"))
	auto_replay = bool(opts.get("auto_replay", true))
	manual_replay = bool(opts.get("manual_replay", false))
	chase_seed = int(opts.get("seed", 1))
	var pc: Node = roam.get("combat") if roam else null
	fx = pc.get("fx") as WeaponFX if pc else null
	if fx == null:
		fx = WeaponFX.new()
		fx.name = "BikeFX"
		add_child(fx)
	combat = PlayerBikeCombat.new()
	combat.name = "BikeCombat"
	add_child(combat)
	combat.setup(bike, {"roam": roam, "targets": bikers, "fx": fx})
	if bool(opts.get("hud", true)):
		hud = BikeHUD.new()
		hud.name = "BikeHUD"
		hud.chase = self
		add_child(hud)
	for i: int in 4:
		var p := AudioStreamPlayer3D.new()
		p.name = "ChaseSfx%d" % i
		p.bus = WeaponAudio.bus()
		p.max_distance = 90.0
		p.unit_size = 7.0
		add_child(p)
		_sfx.append(p)
	for c: String in BikeCombatData.CINE_CUES + BikeCombatData.STORY_CUES:
		CineAudio.sfx(c)                 # synthesized once here, not mid-chase
	for c2: String in BikeCombatData.WEAPON_CUES:
		WeaponAudio.stream(c2)
	_ray_excl.clear()
	if bike:
		_ray_excl.append(bike.get_rid())
	if player is CollisionObject3D:
		_ray_excl.append((player as CollisionObject3D).get_rid())
	if traffic:
		for b: Variant in traffic.bodies():
			_ray_excl.append((b as CollisionObject3D).get_rid())
	_ray_q = PhysicsRayQueryParameters3D.new()
	_ray_q.exclude = _ray_excl
	for w: Variant in opts.get("waves", []):
		add_wave(w)


func add_wave(spawns: Array) -> void:
	waves.append(spawns.duplicate(true))


## The default Day 2 layout (spec C-D6: 5-6 bikers in 2 waves): 3 bikers from behind, then 2 more from behind and a
## tough one waiting ahead (the second wave's "Sói Phó" and "Sói Mập" take two kicks).
static func day2_waves() -> Array:
	return [
		[{"from": "behind", "lane": -1, "opts": {"label": "Sói Đen"}},
		{"from": "behind", "lane": 1, "opts": {"label": "Sói Lửa"}},
		{"from": "behind", "lane": 0, "gap": 6.0, "opts": {"label": "Sói Còi", "aggression": 0.3}}],
		[{"from": "behind", "lane": 1, "opts": {"label": "Sói Bạc", "aggression": 0.7}},
		{"from": "ahead", "lane": 0, "opts": {"label": "Sói Mập", "hp": 2}},
		{"from": "behind", "lane": -1, "delay": 1.5, "opts": {"label": "Sói Phó", "hp": 2, "aggression": 0.8}}]]


func start() -> void:
	if waves.is_empty() or bike == null:
		push_warning("BikeChase.start: no wave or no bike")
		return
	state = "running"
	downed_total = 0
	var xf: Transform3D = route_transform(start_s) if (place_rider and route) else bike.global_transform
	_ensure_riding(xf, place_rider and route != null)
	if start_speed > 0.0:
		bike.current_speed_ms = start_speed
	combat.reset()
	combat.enabled = true
	_set_hooks(true)
	s_p = -1.0
	_update_frame()
	if hud:
		hud.show_hud()
		if start_line != "":
			hud.popup(start_line, CombatHUD.GOLD, 1.6)
	_start_wave(0)


## Remember the current wave and the bike's transform: retry() comes back here.
func checkpoint() -> void:
	if bike == null:
		return
	_cp = {"wave": maxi(wave, 0), "xf": bike.global_transform}


func has_checkpoint() -> bool:
	return not _cp.is_empty()


## After `lost` (or any time): bikers removed, stability full, the bike upright at the checkpoint, its wave again.
func retry() -> void:
	if bike == null:
		return
	if _cp.is_empty():
		checkpoint()
	_kill_replay()
	_clear_bikers()
	pending.clear()
	_gap_left = -1.0
	_finish_left = -1.0
	combat.reset()
	var keep: Dictionary = _cp.duplicate()
	var xf: Transform3D = keep["xf"]
	_ensure_riding(xf, true, false)
	combat.enabled = true
	state = "running"
	_set_hooks(true)
	s_p = -1.0
	_update_frame()
	if hud:
		hud.show_hud()
	_start_wave(int(keep["wave"]))
	_cp = keep


## End without a result: bikers freed, the bike unlocked and upright, the hooks and the HUD cleared.
func stop() -> void:
	_kill_replay()
	_clear_bikers()
	pending.clear()
	_gap_left = -1.0
	_finish_left = -1.0
	state = "idle"
	_finish()


func alive() -> Array:
	var out: Array = []
	for b: Variant in bikers:
		if is_instance_valid(b) and (b as BikerEnemy).is_active():
			out.append(b)
	return out


func alive_count() -> int:
	var n: int = 0
	for b: Variant in bikers:
		if is_instance_valid(b) and (b as BikerEnemy).is_active():
			n += 1
	return n


## Bikers still to beat: the current wave (riding or waiting for their delay) and every later wave.
func remaining() -> int:
	var n: int = alive_count() + pending.size()
	for i: int in range(maxi(wave + 1, 0), waves.size()):
		n += (waves[i] as Array).size()
	return n


func attackers() -> int:
	var n: int = 0
	for b: Variant in bikers:
		if is_instance_valid(b) and (b as BikerEnemy).is_attacking():
			n += 1
	return n


## HUD warning sides of bikers winding up a kick right now: bit 1 = on the player's left, bit 2 = on the right.
func warn_mask() -> int:
	var m: int = 0
	for b: Variant in bikers:
		if not is_instance_valid(b) or not (b as BikerEnemy).telegraphing():
			continue
		var lat: float = ((b as BikerEnemy).pos2 - p_pos).dot(p_right)
		m |= 1 if lat < 0.0 else 2
	return m


# ----- attack tokens (BikerEnemy) -----
func request_token(e: Object) -> bool:
	if state != "running" or combat.knocked:
		return false
	if _holders.has(e):
		return true
	for i: int in range(_holders.size() - 1, -1, -1):
		if not is_instance_valid(_holders[i]):
			_holders.remove_at(i)
	if _holders.size() >= max_attackers or _t - _last_attack_t < BikeCombatData.ATTACK_GAP_S:
		return false
	_holders.append(e)
	_last_attack_t = _t
	return true


func release_token(e: Object) -> void:
	_holders.erase(e)


## An enemy's kick lands now (its hit moment): within ENEMY_REACH to the side and ENEMY_ALONG along the player's bike =
## stability damage and a shove. "hit" | "miss" | "ignored" (i-frames, god, not running).
func enemy_kick(b: BikerEnemy) -> String:
	if state != "running" or combat.knocked:
		return "ignored"
	var rel: Vector2 = b.pos2 - p_pos
	var lat: float = rel.dot(b_right)
	var along: float = rel.dot(b_fwd)
	if absf(lat) > BikeCombatData.ENEMY_REACH or absf(along) > BikeCombatData.ENEMY_ALONG or absf(b.floor_y - (bike.global_position.y + BIKE_FLOOR_OFFSET)) > 2.5:
		return "miss"
	return "hit" if combat.damage(BikeCombatData.ENEMY_KICK_DMG, "kick", 1 if lat > 0.0 else -1) else "ignored"


## A biker crashed (BikerEnemy.crash): biker_down, then the wave clear / the finish.
func on_biker_crash(b: BikerEnemy) -> void:
	downed_total += 1
	last_down = b
	biker_down.emit(b, b.crash_cause)
	if hud:
		hud.popup(BikeCombatData.T_TRAFFIC_DOWN if b.crash_cause == "traffic" else BikeCombatData.T_DOWN, CombatHUD.GOLD)
	if state != "running" or not pending.is_empty() or alive_count() > 0:
		return
	wave_cleared.emit(wave)
	if wave + 1 < waves.size():
		_gap_left = BikeCombatData.WAVE_GAP_S
		return
	state = "finishing"
	combat.enabled = false
	_set_hooks(false)
	if rec:
		rec.mark("blow")
	_finish_left = BikeCombatData.REPLAY_AFTER


## The short replay of the last fall (pauses the tree while it plays; StoryStage helper). null without footage.
func play_replay() -> CineReplay:
	if rec == null or not is_instance_valid(rec) or rec.frame_count() < 2:
		return null
	var focus: Node3D = bike
	if last_down and is_instance_valid(last_down) and last_down.body:
		focus = last_down.body
	replay = StoryStage.play_replay(self, rec, replay_slot, focus, bike, {"manual": manual_replay, "length": BikeCombatData.REPLAY_LEN})
	if replay and hud:
		hud.visible = false
	return replay


func _end_finishing() -> void:
	_finish_left = -1.0
	if auto_replay and play_replay() != null:
		replay.finished.connect(_on_replay_done, CONNECT_ONE_SHOT)
		return
	_on_replay_done()


func _on_replay_done() -> void:
	replay = null
	state = "won"
	_finish()
	if hud and win_line != "":
		hud.show_hud()
		hud.popup(win_line, CombatHUD.GOLD, 2.2)
		hud.linger(2.2)
	won.emit()


func _on_lost() -> void:
	state = "lost"
	combat.enabled = false
	_holders.clear()
	for b: Variant in bikers:
		if is_instance_valid(b):
			(b as BikerEnemy).stand_down()
	_set_hooks(false)
	if hud:
		hud.popup(BikeCombatData.T_KNOCKED_OFF, CombatHUD.WARN, 1.6)
		hud.linger(1.6)
	lost.emit()


func _finish() -> void:
	if combat:
		combat.enabled = false
		combat.reset()
	_set_hooks(false)
	if hud:
		hud.hide_hud()
	if rec and is_instance_valid(rec):
		rec.queue_free()
	rec = null


func _kill_replay() -> void:
	if replay and is_instance_valid(replay):
		if replay.finished.is_connected(_on_replay_done):
			replay.finished.disconnect(_on_replay_done)   # stopped: no `won`
		replay.queue_free()               # its _exit_tree gives back the pause, the camera and the flag
	replay = null


## FreeRoam hint + [F] refusal and the traffic obstacle hook while the chase runs (only cleared if still ours).
func _set_hooks(on: bool) -> void:
	if on == _hooks:
		return
	_hooks = on
	if roam and is_instance_valid(roam):
		if on:
			roam.set("riding_hint", BikeCombatData.T_RIDING)
			roam.set("dismount_refusal", BikeCombatData.T_NO_DISMOUNT)
		else:
			if String(roam.get("riding_hint")) == BikeCombatData.T_RIDING:
				roam.set("riding_hint", "")
			if String(roam.get("dismount_refusal")) == BikeCombatData.T_NO_DISMOUNT:
				roam.set("dismount_refusal", "")
	if traffic and is_instance_valid(traffic):
		if on:
			traffic.extra_obstacles_fn = _traffic_obstacles
		elif traffic.extra_obstacles_fn == Callable(self, "_traffic_obstacles"):
			traffic.extra_obstacles_fn = Callable()


## RoamTraffic look-ahead obstacles: the riding bikers as small oriented boxes (kind "biker").
func _traffic_obstacles() -> Array:
	_obstacles.clear()
	for b: Variant in bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e == null or not is_instance_valid(e) or e.gone or not e.riding():
			continue
		_obstacles.append([e.pos2, 1.0, 0.45, "biker", null, Vector2(-sin(e.yaw), -cos(e.yaw))])
	return _obstacles


# ---------------------------------------------------------------------------
# RIDER PLACEMENT
# ---------------------------------------------------------------------------
## Bike transform on the route at distance s: on the floor (ray), facing along the route.
func route_transform(s: float) -> Transform3D:
	var p: Vector2 = route.point(s)
	var t: Vector2 = route.tangent(s)
	var y: Variant = floor_at(Vector3(p.x, 0.0, p.y), 30.0, 10.0)
	var fy: float = float(y) if y is float else MapBuilder.ROAD_Y
	return Transform3D(Basis(Vector3.UP, atan2(-t.x, -t.y)), Vector3(p.x, fy - BIKE_FLOOR_OFFSET, p.y))


## The player on the bike (FreeRoam.mount_bike when on foot); place = put the bike at xf (stopped, unless keep_speed).
func _ensure_riding(xf: Transform3D, place: bool, keep_speed: bool = false) -> void:
	var yaw: float = xf.basis.get_euler().y
	if roam and is_instance_valid(roam) and not bool(roam.get("mounted")):
		var spot: Vector3 = xf.origin + Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0)
		if not place:
			spot = player.global_position if player else spot
		if bool(roam.get("bike_parked")):
			bike.global_position = spot - Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0)
			bike.rotation = Vector3(0.0, yaw if place else bike.rotation.y, 0.0)
		if player and player.has_method("teleport"):
			player.call("teleport", spot, yaw if place else (player.call("facing_yaw") if player.has_method("facing_yaw") else yaw))
		roam.call("mount_bike")
		if place:
			bike.global_transform = Transform3D(Basis(Vector3.UP, yaw), xf.origin)
	elif place:
		bike.global_transform = Transform3D(Basis(Vector3.UP, yaw), xf.origin)
	if place:
		bike.velocity = Vector3.ZERO
		if not keep_speed:
			bike.current_speed_ms = 0.0


# ---------------------------------------------------------------------------
# WAVES
# ---------------------------------------------------------------------------
func _start_wave(i: int) -> void:
	_clear_bikers()
	_gap_left = -1.0
	wave = i
	_wave_spawned = 0
	if auto_checkpoint:
		checkpoint()
	if i == waves.size() - 1:
		_make_recorder()
	pending.clear()
	for sp: Variant in waves[i]:
		pending.append([sp, float((sp as Dictionary).get("delay", 0.0))])
	_spawn_due(0.0)
	wave_started.emit(i)


func _make_recorder() -> void:
	if rec and is_instance_valid(rec):
		rec.queue_free()
	var nodes: Array = [bike]
	if bike:
		nodes.append(bike.visual_pivot)
		if bike.rider_node:
			nodes.append(bike.rider_node)
	rec = StoryStage.make_recorder(self, nodes)


func _spawn_due(delta: float) -> void:
	for k: int in range(pending.size() - 1, -1, -1):
		var e: Array = pending[k]
		e[1] = float(e[1]) - delta
		if float(e[1]) <= 0.0:
			pending.remove_at(k)
			_spawn(e[0])


func _spawn(sp: Dictionary) -> BikerEnemy:
	var b := BikerEnemy.new()
	b.name = "Biker%d" % _spawned
	var o: Dictionary = (sp.get("opts", {}) as Dictionary).duplicate()
	if not o.has("seed"):
		o["seed"] = chase_seed * 1000 + _spawned
	if not o.has("label"):
		o["label"] = BikeCombatData.NAMES[_spawned % BikeCombatData.NAMES.size()]
	b.ch = self
	b.setup(o)
	add_child(b)
	var ahead: bool = String(sp.get("from", "behind")) == "ahead"
	var lane: float = float(sp.get("lane", [-1, 1, 0][_wave_spawned % 3]))
	var along: float = (AHEAD_M if ahead else -BEHIND_M) + (1.0 if ahead else -1.0) * (float(sp.get("gap", 0.0)) + SPAWN_STEP_M * float(_wave_spawned))
	var p2: Vector2 = target_at(along, lane * LANE_M)
	for k: int in 4:
		if _clear_of_traffic(p2):
			break
		along += -8.0 if not ahead else 8.0
		p2 = target_at(along, lane * LANE_M)
	var y: Variant = floor_at(Vector3(p2.x, bike.global_position.y + BIKE_FLOOR_OFFSET, p2.y))
	var fy: float = float(y) if y is float else bike.global_position.y + BIKE_FLOOR_OFFSET
	var spd: float = p_vel.length() * (0.6 if ahead else 1.0)
	b.place(Vector3(p2.x, fy, p2.y), atan2(-p_fwd.x, -p_fwd.y), spd)
	b.side = -1.0 if lane < 0.0 else 1.0
	bikers.append(b)
	_spawned += 1
	_wave_spawned += 1
	if rec:
		rec.track(b)
		rec.track(b.body)
	return b


func _clear_of_traffic(p2: Vector2) -> bool:
	if traffic == null:
		return true
	for v: Variant in traffic.vehicles:
		var c: RoamTraffic.Vehicle = v
		if c.active and c.pos.distance_to(p2) < c.half_len + 2.5:
			return false
	return true


func _clear_bikers() -> void:
	for b: Variant in bikers:
		if is_instance_valid(b):
			(b as Node).queue_free()
	bikers.clear()
	_holders.clear()


# ---------------------------------------------------------------------------
# PER FRAME
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if state == "idle" or state == "won" or bike == null or not is_instance_valid(bike):
		return
	_t += delta
	_update_frame()
	if state == "running":
		if combat.knocked:
			_on_lost()
		else:
			_spawn_due(delta)
			_role_t -= delta
			if _role_t <= 0.0:
				_role_t = BikeCombatData.ROLE_EVERY
				_assign_roles()
	_box_cd -= delta
	for b: Variant in bikers:
		if is_instance_valid(b):
			(b as BikerEnemy).tick(delta)
	_player_contact()
	_separate()
	max_attackers_seen = maxi(max_attackers_seen, attackers())
	if state == "finishing" and _finish_left >= 0.0:
		_finish_left -= delta
		if _finish_left < 0.0:
			_end_finishing()
		return
	if state == "running" and _gap_left >= 0.0:
		_gap_left -= delta
		if _gap_left < 0.0:
			_start_wave(wave + 1)


## The player's position, velocity and frame: on the route (route tangent, oriented with the player's travel, plus his
## route coordinates s_p / d_p) or off it / without one (his bike's heading).
func _update_frame() -> void:
	var bp: Vector3 = bike.global_position
	p_pos = Vector2(bp.x, bp.z)
	p_vel = Vector2(bike.velocity.x, bike.velocity.z)
	var z: Vector3 = bike.global_transform.basis.z
	var hf := Vector2(-z.x, -z.z)
	hf = hf.normalized() if hf.length_squared() > 1e-6 else Vector2(0.0, -1.0)
	b_fwd = hf
	b_right = Vector2(-hf.y, hf.x)
	on_route = false
	if route:
		var pr: Vector2 = route.project(p_pos, s_p)
		s_p = pr.x
		d_p = pr.y
		on_route = absf(d_p) <= route.half_width + 6.0 and s_p > 0.5 and s_p < route.length - 0.5
		if absf(d_p) > route.half_width + 30.0:
			s_p = -1.0                     # far off: search the whole route next frame
	if on_route:
		var t: Vector2 = route.tangent(s_p)
		var hd: float = hf.dot(t)
		if absf(hd) > 0.3:
			dir_sign = signf(hd)
		p_fwd = t * dir_sign
	else:
		p_fwd = hf
	p_right = Vector2(-p_fwd.y, p_fwd.x)


## World point (map plane) at `along` m ahead and `lat` m to the right of the player: on the route clamped to its
## half width, else in his heading frame.
func target_at(along: float, lat: float) -> Vector2:
	if on_route:
		var s: float = clampf(s_p + along * dir_sign, 0.0, route.length)
		var d: float = clampf(d_p + lat * dir_sign, -route.half_width, route.half_width)
		return route.world(s, d)
	return p_pos + p_fwd * along + p_right * lat


## A flank slot on `side` has room: on the road (not squeezed past the edge by more than SLOT_SQUEEZE) and no car in it
## or running into it soon (a slower car ahead in that lane, an oncoming one, one alongside the player).
func slot_fits(side: float) -> bool:
	if on_route:
		var d: float = d_p + side * BikeCombatData.SLOT_LAT * dir_sign
		if absf(d) - route.half_width > BikeCombatData.SLOT_SQUEEZE:
			return false
	return not lane_busy(side)


func lane_busy(side: float) -> bool:
	if traffic == null:
		return false
	var p_speed: float = p_vel.dot(p_fwd)
	for v: Variant in traffic.vehicles:
		var c: RoamTraffic.Vehicle = v
		if not c.active:
			continue
		var rel: Vector2 = c.pos - p_pos
		if rel.length_squared() > 3600.0:
			continue
		var cd: float = absf(c.dir.dot(p_fwd))
		var cx: float = absf(c.dir.cross(p_fwd))
		var ext_a: float = c.half_len * cd + c.half_w * cx
		var ext_l: float = c.half_w * cd + c.half_len * cx
		if absf(rel.dot(p_right) - side * BikeCombatData.SLOT_LAT) > ext_l + 0.9:
			continue
		var along: float = rel.dot(p_fwd)
		var closing: float = maxf(0.0, p_speed - c.speed * c.dir.dot(p_fwd))
		if along < BikeCombatData.SLOT_ALONG - ext_a - 3.0 or along > BikeCombatData.SLOT_ALONG + ext_a + 2.0 + closing * 1.2:
			continue
		return true
	return false


## Point p (map plane) is on the road, within `tol` m past the AI's half width (always true off the route / without one).
func on_road(p: Vector2, tol: float = 0.3) -> bool:
	if not on_route:
		return true
	var pr: Vector2 = route.project(p, s_p, 40.0)
	return absf(pr.y) <= route.half_width + tol


## Point p (map plane) is beside the player's line (within 1.4 m to the side and 12 m + 1.5 s of closing along): no room to
## pass a car there (car_speed: the car's speed along the player's heading).
func near_player(p: Vector2, car_speed: float = 0.0) -> bool:
	var rel: Vector2 = p - p_pos
	var reach: float = 12.0 + maxf(0.0, p_vel.dot(b_fwd) - car_speed) * 1.5
	return absf(rel.dot(b_fwd)) < reach and absf(rel.dot(b_right)) < 1.4


## Floor height under p (a ray from up above to down below; not the bikes, the player or a car roof). null = none.
func floor_at(p: Vector3, up: float = 2.5, down: float = 6.0) -> Variant:
	if not is_inside_tree():
		return null
	_ray_q.from = p + Vector3(0.0, up, 0.0)
	_ray_q.to = p - Vector3(0.0, down, 0.0)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray_q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.6:
		return null
	var col: Object = hit["collider"]
	if col is Node and (col as Node).is_in_group("traffic_obstacle"):
		return null
	return (hit["position"] as Vector3).y


## Roles every ROLE_EVERY (sticky: attackers keep their side, holders keep a role while it is still valid): with 3+ riders
## one FRONT (the box-in blocker; a new one is the rider furthest ahead), a LEFT and a RIGHT flanker (new ones: the
## leftmost / rightmost free rider; a side with no road room or with a car in or running into its slot stays empty), the
## rest BACK.
func _assign_roles() -> void:
	_act.clear()
	for b: Variant in bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e != null and is_instance_valid(e) and e.is_active() and e.st != BikerEnemy.St.WOBBLE and e.st != BikerEnemy.St.HOLD:
			_act.append(e)
	if _act.is_empty():
		boxed = false
		return
	var fit_l: bool = slot_fits(-1.0)
	var fit_r: bool = slot_fits(1.0)
	var front: BikerEnemy = null
	var left: BikerEnemy = null
	var right: BikerEnemy = null
	for e: BikerEnemy in _act:
		if e.is_attacking():
			if e.side < 0.0:
				left = e
			else:
				right = e
	for e: BikerEnemy in _act:
		if e == left or e == right:
			continue
		if e.role == BikerEnemy.Role.FRONT and front == null and _act.size() >= 3:
			front = e
		elif e.role == BikerEnemy.Role.LEFT and left == null and fit_l:
			left = e
		elif e.role == BikerEnemy.Role.RIGHT and right == null and fit_r:
			right = e
	if front == null and _act.size() >= 3:
		var best: float = -INF
		for e: BikerEnemy in _act:
			if e == left or e == right:
				continue
			var al: float = (e.pos2 - p_pos).dot(p_fwd)
			if al > best:
				best = al
				front = e
	var lo: float = INF
	var hi: float = -INF
	var cand_l: BikerEnemy = null
	var cand_r: BikerEnemy = null
	for e: BikerEnemy in _act:
		if e == front or e == left or e == right:
			continue
		var lat: float = (e.pos2 - p_pos).dot(p_right)
		if lat < lo:
			lo = lat
			cand_l = e
		if lat > hi:
			hi = lat
			cand_r = e
	if cand_l != null and cand_l == cand_r:          # one free rider: its own side first
		if hi >= 0.0 and right == null and fit_r:
			right = cand_l
		elif left == null and fit_l:
			left = cand_l
		elif right == null and fit_r:
			right = cand_l
	else:
		if left == null and fit_l and cand_l != null:
			left = cand_l
		if right == null and fit_r and cand_r != null and cand_r != left:
			right = cand_r
	var k: int = 0
	for e: BikerEnemy in _act:
		if e == front:
			e.role = BikerEnemy.Role.FRONT
		elif e == left:
			e.role = BikerEnemy.Role.LEFT
			e.side = -1.0
		elif e == right:
			e.role = BikerEnemy.Role.RIGHT
			e.side = 1.0
		else:
			e.role = BikerEnemy.Role.BACK
			e.back_k = k
			k += 1
	boxed = false
	if front and left and right:
		var fa: float = (front.pos2 - p_pos).dot(p_fwd)
		var la: Vector2 = Vector2((left.pos2 - p_pos).dot(p_fwd), (left.pos2 - p_pos).dot(p_right))
		var ra: Vector2 = Vector2((right.pos2 - p_pos).dot(p_fwd), (right.pos2 - p_pos).dot(p_right))
		boxed = fa > 1.5 and fa < 10.0 and absf(la.x) < 3.0 and absf(ra.x) < 3.0 and absf(la.y) < BikeCombatData.BOX_LAT and absf(ra.y) < BikeCombatData.BOX_LAT
	if boxed and _box_cd <= 0.0:
		_box_cd = BikeCombatData.BOX_COOLDOWN
		boxed_count += 1
		if hud:
			hud.popup(BikeCombatData.T_BOXED, CombatHUD.WARN)


## The player's bike against the bikers (no physics bodies): riding into a biker's back wheel is a ram (speed matched,
## RAM_DMG); a biker overlapping the bike from the side is pushed out to PLAYER_GAP_LAT.
func _player_contact() -> void:
	if combat.knocked:
		return
	var p_speed: float = p_vel.dot(b_fwd)
	for b: Variant in bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e == null or not is_instance_valid(e) or not e.riding() or e.gone:
			continue
		var rel: Vector2 = e.pos2 - p_pos
		var along: float = rel.dot(b_fwd)
		var lat: float = rel.dot(b_right)
		if absf(along) > 2.0 or absf(lat) > BikeCombatData.PLAYER_GAP_LAT:
			continue
		if along > 0.6 and absf(lat) < 0.6:
			var e_speed: float = e.vel.dot(b_fwd)
			if p_speed > e_speed + 0.5:
				bike.current_speed_ms = maxf(0.0, e_speed - 0.5)
				if state == "running" and combat.ram_cd <= 0.0:
					combat.ram_cd = BikeCombatData.RAM_COOLDOWN
					if combat.damage(BikeCombatData.RAM_DMG, "ram") and hud:
						hud.popup(BikeCombatData.T_RAM, CombatHUD.WARN)
			e.pos2 += b_fwd * (1.9 - along) * 0.5
		elif e.avoid_t > 0.0 and e.avoid_car >= 0:
			e.pos2 -= b_fwd * 0.25           # squeezed between the player and a car: drop back, not sideways into it
		elif not e.is_attacking():
			var sgn: float = signf(lat) if absf(lat) > 0.01 else e.side
			e.pos2 += b_right * (sgn * BikeCombatData.PLAYER_GAP_LAT - lat)


func _separate() -> void:
	var n: int = bikers.size()
	for i: int in n:
		var a: BikerEnemy = bikers[i] as BikerEnemy
		if a == null or not is_instance_valid(a) or not a.riding() or a.gone:
			continue
		for j: int in range(i + 1, n):
			var b: BikerEnemy = bikers[j] as BikerEnemy
			if b == null or not is_instance_valid(b) or not b.riding() or b.gone:
				continue
			var d: Vector2 = b.pos2 - a.pos2
			var l: float = d.length()
			if l >= BikeCombatData.SEPARATION:
				continue
			var n2: Vector2 = d / l if l > 0.01 else p_right
			var push: Vector2 = n2 * (BikeCombatData.SEPARATION - l) * 0.5
			a.pos2 -= push
			b.pos2 += push


# ---------------------------------------------------------------------------
# FX / SOUND (BikerEnemy calls these)
# ---------------------------------------------------------------------------
func cue(c: String, at: Vector3, db: float = 0.0) -> void:
	if _sfx.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = WeaponAudio.stream(c) if WeaponAudio.CUES.has(c) else CineAudio.sfx(c)
	p.volume_db = db
	p.global_position = at
	p.play()


func sparks(at: Vector3, dir: Vector3) -> void:
	if fx:
		fx.burst("sparks", at, dir, 0.7)


func stars(anchor: Node3D, secs: float) -> void:
	if fx:
		fx.stars(anchor, secs)


func _exit_tree() -> void:
	_set_hooks(false)
