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
#       "end_at_s": -1.0,                       # route distance where the chase ends at the latest (Day 2: a little past
#                                               #   bridge_s()); -1 = END_MARGIN before the route end. Reached with bikers
#                                               #   left: they ride off (out of view), no replay, `won` with escaped > 0
#       "seed": 1,
#       "waves": []})                           # optional: the waves right away (same as add_wave per entry)
#   chase.add_wave([                            # once per wave, in order (BikeChase.day2_waves(): the Day 2 layout 3 + 3)
#       {"from": "behind",                      # "behind" (default, ~16 m back, behind the camera) | "ahead" (60-150 m
#                                               #   ahead where out of view, else from behind as the front blocker)
#        "lane": -1,                            # -1 left, 0 middle, +1 right of the player
#        "gap": 0.0, "delay": 0.0,              # extra spawn distance (m), seconds after the wave start
#        "opts": {"label": "Sói Đen", "hp": 1, "aggression": 0.5, "eye_color": Color(...), "paint": Color(...),
#                 "body": {...}, "body_fn": Callable}},   # BikerEnemy opts (look passed in by the caller)
#       ...])
#   chase.won.connect(...)                      # after the replay (at once with auto_replay false / no footage / an
#                                               #   early end). The crashed and downed riders keep tumbling, sliding and
#                                               #   lying with stars after `won`: the integration MUST call stop() or free
#                                               #   the chase afterwards (clear_downed() only removes the downed riders,
#                                               #   e.g. to clean the bridge area for the duel)
#   chase.lost.connect(...)                     # stability 0, the player knocked off: show "TOANG!", then retry()
#   chase.biker_down.connect(func(b: BikerEnemy, cause: String): ...)   # cause "kick" | "traffic" | ...
#   chase.wave_started / wave_cleared (index)
#   chase.start()                               # mounts the player (FreeRoam.mount_bike) and places the bike if asked
#   chase.checkpoint()                          # remember the wave + the bike's transform (automatic per wave)
#   chase.retry()                               # bikers removed, stability full, bike back at the checkpoint, that wave
#   chase.stop()                                # end without a result (bikers freed, bike unlocked, hooks cleared)
#   chase.play_replay() -> CineReplay           # the replay by hand (auto_replay false); null without footage
#   chase.clear_downed()                        # free every crashed / downed rider now (do it out of sight or in a fade)
#   chase.bridge_s() -> float, chase.bridge_transform() -> Transform3D   # the Rạch Hầm bridge on the route (-1 / identity
#                                               #   when the route does not cross it); the bike on the deck there
#   chase.end_s, chase.end_position() -> Vector3  # where the chase ended (route distance / the bike), set at the finish
#   chase.ended_early, chase.escaped            # ended at end_at_s / the route end with `escaped` bikers left
#   chase.alive() -> Array, chase.remaining() -> int, chase.state, chase.wave, chase.combat (PlayerBikeCombat)
#   state: "idle" | "running" | "finishing" (last biker down: 0.8 s more footage, then the replay) | "won" | "lost"
# Off the route (the player off the road, past its ends) the AI's targets stay clamped to the route, so the bikers never
# ride through buildings. Cleared waves' downed riders are removed only once out of view.
# While it runs: Q / E kick (PlayerBikeCombat), FreeRoam's hint shows the kick keys (FreeRoam.riding_hint) and [F]
# refuses to get off the bike (FreeRoam.dismount_refusal); the traffic brakes for the bikers
# (RoamTraffic.extra_obstacles_fn). The phone and the emotes are already off while riding. stop(), lost and freeing the
# chase clear those hooks; stop() / retry() / freeing also unlock and right the bike. The chase never changes the story
# state, the time of day, the music or the camera, and never references an autoload by name.
# ===== Day 2 "Tokyo Drift" (spec 2026-10-27, D2X-2 to D2X-7) =====
#   setup opts: "profile" (the bike's speed profile while the chase runs, default PlayerBike.STAGE_PROFILE; Day 2
#       BikeCombatData.CHASE_PROFILE), "opening" ({"drop_s": OPEN_DROP_S, "scale": OPEN_SCALE}: slow motion, a low camera
#       and letterbox until the drop, then wave 0 spawns; the drop follows "music_pos_fn" (-> the chase track's playback
#       seconds, < 0 = no music) or a real-time timer), "set_pieces" (BikeSetPieces data, e.g. DAY2_SET_PIECES), "cameo"
#       ({"s", "force_s", "body_fn", "card_fn": Callable(done: Callable)}: Sói Xám before an "after_cameo" wave; its start is
#       a checkpoint for that wave, so a knock-off after it never replays it),
#       "nitro" (bike.set_nitro_enabled(true) at the start), "takedown_cam" (default true);
#       tests: "duck_fn" / "nitro_fn" / "charge_fn" stand in for PlayerBike.is_ducking / nitro_active / add_drift_charge.
#   add_wave(spawns, {"max_attackers": 4, "force_s": 1000.0, "after_cameo": true}); spawn "from": "side" (bursts out beside
#       the player, out of view), spawn opts "kind" (BikerEnemy: rider | stick | thrower | heavy | pickup).
#   Takedowns (crash causes in BikeCombatData.TAKEDOWN_CAUSES, or a spin kick on 2 riders, or an air kick): `takedown`,
#       the counter `takedowns`, a rotating popup, +TD_CHARGE nitro charge, 0.5 s slow motion + a side camera cut (at most
#       one every TD_GAP_S, none while 2+ attackers wind up near the player).
#   Slow motion goes through RadialWheel.scale_owner (a wheel that owns the time scale wins) and the time scale is back at
#       1 on the drop, stop(), retry(), lost, the finish and freeing. No regeneration; a cleared wave refills WAVE_REFILL;
#       a traffic crash costs CRASH_DMG_MIN..MAX by speed; touching a biker during nitro is a takedown (not the pickup).
#   spawn_police(n) / release_police() (the police set piece), throw_helmet(thrower) (the red road marker), lat_room(side),
#       bike_ducking(), bike_nitro(), add_charge(points), slow_motion(scale, real_s, kind), cams: `cam` (opening / cuts).
# ===========================================
class_name BikeChase
extends Node3D

signal won
signal lost
signal biker_down(biker: BikerEnemy, cause: String)
signal wave_started(index: int)
signal wave_cleared(index: int)
signal takedown(biker: BikerEnemy, cause: String)
signal set_piece(kind: String, phase: String)
signal cameo_started
signal cameo_done
signal opening_drop

const BIKE_FLOOR_OFFSET: float = 0.13    # = FreeRoam.BIKE_FLOOR_OFFSET: the PlayerBike origin sits 0.13 m under the floor
const BEHIND_M: float = 16.0
const AHEAD_M: float = 60.0              # "ahead" spawns: the first of these distances that is out of view ...
const AHEAD_TRY: Array[float] = [60.0, 90.0, 120.0, 150.0]   # ... else from behind as the front blocker
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
var _bike_profile: Dictionary = {}       # the bike's own speed profile while the chase caps it (OB-D2)
var end_at_s: float = -1.0
var end_s: float = -1.0
var end_xf: Transform3D = Transform3D.IDENTITY
var ended_early: bool = false
var escaped: int = 0
var _downed: Array = []                  # downed riders of cleared waves, freed once out of view
var _obs_pool: Array = []                # reused look-ahead entries for RoamTraffic (no allocation per call)
var _clean_t: float = 0.0
var _hint: float = -1.0
var _dying: bool = false
# ----- Day 2 -----
var profile: Dictionary = PlayerBike.STAGE_PROFILE
var wave_opts: Array = []                # per wave: {"max_attackers", "force_s", "after_cameo"}
var opening: Dictionary = {}             # {"drop_s", "scale"} (empty: no film opening)
var opening_on: bool = false
var open_t: float = 0.0                  # real seconds since the opening started
var drop_at: float = -1.0                # real seconds after the start when the drop came (tests)
var drop_by_music: bool = false
var music_pos_fn: Callable
var duck_fn: Callable
var nitro_fn: Callable
var charge_fn: Callable
var nitro_on_start: bool = false
var takedown_cam: bool = true
var takedowns: int = 0
var td_slowmos: int = 0
var charge_given: float = 0.0            # nitro charge handed to the bike (tests)
var cam: Camera3D                        # the opening's low camera and the takedown side cuts
var cam_mode: String = ""                # "" | "open" | "td"
var _cam_prev: Camera3D = null
var _cam_target: BikerEnemy = null
var _cam_side: Vector2 = Vector2.ZERO
var cam_pick: int = 0                    # Q1: the takedown cut's angle (CameraRules.TD_CANDIDATES index) and re-picks
var cam_repicks: int = 0
var _cam_check_t: float = 0.0
var slow_kind: String = ""               # "" | "open" | "td" | "jump"
var _slow_left: float = 0.0              # real seconds
var _rt: float = 0.0                     # real seconds the chase has run
var _last_td_slow: float = -99.0
var _td_i: int = 0
var _spin_hits: Array = []               # [biker, real time] of recent spin-kick hits
var set_pieces: BikeSetPieces
var cameo: BikeCameo
var cameo_opts: Dictionary = {}
var cameo_state: String = ""             # "" | "waiting" | "running" | "done"
var cameo_card_seen: bool = false        # Sói Xám's card has been shown (a retry before it replays the cameo)
var cops: Array = []                     # police riders (BikerEnemy kind "police"), not wave members
var d_lo: float = -INF                   # extra clamp of the AI's lateral targets (route frame; the wrong-way set piece)
var d_hi: float = INF
var jump_left: float = 0.0               # real seconds left of the ramp jump (BikeSetPieces)
var jump_len: float = 1.0
var _air: Array = []                     # bikers airborne with the player
var helmets: Array = []                  # pooled thrown helmets {"node", "mark", "t", "from", "to", "active", "by"}
var helmets_thrown: int = 0
var helmets_hit: int = 0
var attack_starts: int = 0               # attack tokens granted (telemetry: tests, the tuning bots)
var police_player_t: float = 0.0         # the police's next go at the player waits this long
var attack_hits: int = 0                 # enemy attacks that cost stability
var _prev_speed: float = 0.0
var _horn: AudioStream = null


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
	end_at_s = float(opts.get("end_at_s", -1.0))
	if route and route.bridge_s < 0.0 and roam and roam.get("md"):
		route.bridge_s = BikeRoute.find_bridge_s(roam.get("md"), route)
	var pc: Node = roam.get("combat") if roam else null
	fx = pc.get("fx") as WeaponFX if pc else null
	if fx == null:
		fx = WeaponFX.new()
		fx.name = "BikeFX"
		add_child(fx)
	profile = opts.get("profile", PlayerBike.STAGE_PROFILE)
	opening = opts.get("opening", {})
	music_pos_fn = opts.get("music_pos_fn", Callable())
	duck_fn = opts.get("duck_fn", Callable())
	nitro_fn = opts.get("nitro_fn", Callable())
	charge_fn = opts.get("charge_fn", Callable())
	nitro_on_start = bool(opts.get("nitro", false))
	takedown_cam = bool(opts.get("takedown_cam", true))
	cameo_opts = opts.get("cameo", {})
	combat = PlayerBikeCombat.new()
	combat.name = "BikeCombat"
	add_child(combat)
	if bike and not bike.crash_occurred.is_connected(_on_bike_crash):
		bike.crash_occurred.connect(_on_bike_crash)   # before PlayerBikeCombat's own handler: the speed-scaled damage first
	combat.setup(bike, {"roam": roam, "targets": bikers, "fx": fx})
	combat.kick_hit.connect(_on_kick_hit)
	cam = Camera3D.new()
	cam.name = "ChaseCam"
	cam.top_level = true
	cam.fov = 62.0
	cam.far = 900.0
	cam.near = 0.08
	add_child(cam)
	combat.kick_hit.connect(_cam_on_kick)   # Q1: the chase cam's 0.12 s whip toward a kicked rider
	_horn = bike.horn_player.stream if (bike and bike.horn_player) else null   # the bike's own horn wav (no file load)
	for i: int in 4:
		helmets.append(_make_helmet(i))
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
	var sp_data: Array = opts.get("set_pieces", [])
	if not sp_data.is_empty():
		set_pieces = BikeSetPieces.new()
		set_pieces.name = "SetPieces"
		add_child(set_pieces)
		set_pieces.setup(self, sp_data)
	var wo: Array = opts.get("wave_opts", [])
	var wi: int = 0
	for w: Variant in opts.get("waves", []):
		add_wave(w, wo[wi] if wi < wo.size() else {})
		wi += 1


## A wave of spawns; wopts: "max_attackers" (this wave's attacker cap), "force_s" (the wave starts when the player reaches
## this route distance even if the previous one is still riding: those riders stay in the fight), "after_cameo" (it starts
## after the Sói Xám cameo, see setup "cameo").
func add_wave(spawns: Array, wopts: Dictionary = {}) -> void:
	waves.append(spawns.duplicate(true))
	wave_opts.append(wopts.duplicate())


func wave_opt(i: int, key: String, def: Variant) -> Variant:
	if i < 0 or i >= wave_opts.size():
		return def
	return (wave_opts[i] as Dictionary).get(key, def)


## The Day 2 layout (spec 2026-10-27 D2X-4: 14 vehicles in 3 waves; tuned with tests/sim_bike_chase_d2.gd, see the plan).
## W1 bursts out of the side roads at the opening drop: 3 riders and a stick, a 4th rider later. W2 (by s 1000 at the
## latest): reinforcements over ~20 s (2 riders, a heavy, a thrower, a stick) so the fight runs to the cameo. W3 after the
## Sói Xám cameo, 4 attackers at once: the pickup, 2 riders, a thrower and a heavy. Owner-tunable: kinds, hp, aggression,
## delays (s after the wave start).
static func day2_waves() -> Array:
	return [
		[{"from": "side", "lane": -1, "opts": {"label": "Sói Đen", "aggression": 0.6}},
		{"from": "side", "lane": 1, "opts": {"label": "Sói Lửa", "hp": 2, "aggression": 0.65}},
		{"from": "side", "lane": -1, "delay": 0.4, "opts": {"kind": "stick", "label": "Sói Gậy", "aggression": 0.6}},
		{"from": "behind", "lane": 1, "delay": 6.0, "opts": {"label": "Sói Còi", "hp": 2, "aggression": 0.5}}],
		[{"from": "behind", "lane": 1, "opts": {"label": "Sói Bạc", "hp": 2, "aggression": 0.7}},
		{"from": "behind", "lane": -1, "delay": 1.0, "opts": {"kind": "heavy", "label": "Sói Bự", "aggression": 0.6}},
		{"from": "ahead", "lane": 0, "delay": 7.0, "opts": {"kind": "thrower", "label": "Sói Ném", "aggression": 0.7}},
		{"from": "behind", "lane": 1, "delay": 13.0, "opts": {"kind": "stick", "label": "Sói Gậy 2", "hp": 2, "aggression": 0.7}},
		{"from": "behind", "lane": -1, "delay": 19.0, "opts": {"label": "Sói Phó", "hp": 2, "aggression": 0.8}}],
		[{"from": "behind", "lane": 1, "opts": {"kind": "pickup", "label": "Bán Tải Sói", "aggression": 0.6}},
		{"from": "ahead", "lane": 0, "opts": {"kind": "thrower", "label": "Sói Ném 2", "aggression": 0.75}},
		{"from": "behind", "lane": -1, "delay": 0.6, "opts": {"label": "Sói Nanh", "aggression": 0.8}},
		{"from": "behind", "lane": -1, "delay": 5.0, "opts": {"kind": "heavy", "label": "Sói Bự 2", "aggression": 0.7}},
		{"from": "behind", "lane": 1, "delay": 6.0, "opts": {"label": "Sói Vuốt", "aggression": 0.9}}]]


## The Day 2 wave options matching day2_waves().
static func day2_wave_opts() -> Array:
	return [{}, {"force_s": 1000.0}, {"after_cameo": true, "max_attackers": 4}]


func start() -> void:
	if waves.is_empty() or bike == null:
		push_warning("BikeChase.start: no wave or no bike")
		return
	state = "running"
	downed_total = 0
	ended_early = false
	escaped = 0
	end_s = -1.0
	_clear_bikers()
	var xf: Transform3D = route_transform(start_s) if (place_rider and route) else bike.global_transform
	_ensure_riding(xf, place_rider and route != null)
	if start_speed > 0.0:
		bike.current_speed_ms = start_speed
	combat.reset()
	combat.enabled = true
	_set_hooks(true)
	s_p = -1.0
	_hint = -1.0
	_update_frame()
	wave = -1
	_cp.clear()
	checkpoint()                          # the start itself (auto_checkpoint off: retry() comes back here)
	takedowns = 0
	cameo_state = ""
	cameo_card_seen = false
	_rt = 0.0
	drop_at = -1.0
	if nitro_on_start and bike.has_method("set_nitro_enabled"):
		bike.call("set_nitro_enabled", true)
	if set_pieces:
		set_pieces.rearm(-INF)
	if hud:
		hud.show_hud()
		if start_line != "":
			hud.popup(start_line, CombatHUD.GOLD, float(opening.get("drop_s", BikeCombatData.OPEN_DROP_S)) if not opening.is_empty() else 1.6)
	if not opening.is_empty():
		_begin_opening()
		return
	_start_wave(0)


## Remember the current wave and the bike's transform: retry() comes back here.
func checkpoint() -> void:
	if bike == null:
		return
	_cp = {"wave": maxi(wave, 0), "xf": bike.global_transform, "s": s_p}
	_clamp_checkpoint()


## A checkpoint inside a barrier's warning stretch (BARRIER_WARN_M before it) moves back to the first sign, so a retry
## starts with the full warning.
func _clamp_checkpoint() -> void:
	if set_pieces == null or route == null or float(_cp.get("s", -1.0)) < 0.0:
		return
	var safe: float = set_pieces.safe_checkpoint_s(float(_cp["s"]))
	if safe < float(_cp["s"]) - 0.5:
		_cp["s"] = safe
		_cp["xf"] = route_transform(safe)


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
	_reset_day2()
	combat.reset()
	var keep: Dictionary = _cp.duplicate()
	var xf: Transform3D = keep["xf"]
	_ensure_riding(xf, true, false)
	combat.enabled = true
	state = "running"
	ended_early = false
	_set_hooks(true)
	s_p = -1.0
	_hint = -1.0
	_update_frame()
	if hud:
		hud.show_hud()
	var cw: int = int(keep["wave"])
	var after: bool = bool(wave_opt(cw, "after_cameo", false))
	if set_pieces:
		set_pieces.rearm(float(keep.get("s", -INF)))
	if after and not cameo_opts.is_empty() and not cameo_card_seen:
		# knocked off before Sói Xám's card: his cameo again from its checkpoint, then that wave (_on_cameo_done)
		wave = cw - 1
		_retire_wave()
		_begin_cameo()
	else:
		cameo_state = "done" if after else ""   # the cameo comes again unless past it
		_start_wave(cw)
	_cp = keep


## End without a result: bikers freed, the bike unlocked and upright, the hooks and the HUD cleared.
func stop() -> void:
	_kill_replay()
	_clear_bikers()
	pending.clear()
	_gap_left = -1.0
	_finish_left = -1.0
	_reset_day2()
	if set_pieces:
		set_pieces.clear()
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
	if state != "running" or combat.knocked or opening_on or cameo_state == "running":
		return false
	if _holders.has(e):
		return true
	for i: int in range(_holders.size() - 1, -1, -1):
		if not is_instance_valid(_holders[i]):
			_holders.remove_at(i)
	if _holders.size() >= attacker_cap() or _t - _last_attack_t < BikeCombatData.ATTACK_GAP_S:
		return false
	_holders.append(e)
	_last_attack_t = _t
	attack_starts += 1
	return true


func release_token(e: Object) -> void:
	_holders.erase(e)


## The current wave's attacker cap (wave opts "max_attackers", else the setup value).
func attacker_cap() -> int:
	return int(wave_opt(wave, "max_attackers", max_attackers))


## An enemy's attack lands now (its hit moment): within its kind's reach to the side and along the player's bike =
## stability damage and a shove (rider kick, stick swing, heavy / police ram, pickup side ram). "hit" | "miss" | "ignored"
## (i-frames, god, not running).
func enemy_kick(b: BikerEnemy) -> String:
	if state != "running" or combat.knocked:
		return "ignored"
	var rel: Vector2 = b.pos2 - p_pos
	var lat: float = rel.dot(b_right)
	var along: float = rel.dot(b_fwd)
	var reach: float = float(b.kp.get("reach", BikeCombatData.ENEMY_REACH))
	var reach_a: float = float(b.kp.get("along", BikeCombatData.ENEMY_ALONG))
	if absf(lat) > reach or absf(along) > reach_a or absf(b.floor_y - (bike.global_position.y + BIKE_FLOOR_OFFSET)) > 2.5:
		return "miss"
	var cause: String = {"stick": "stick", "heavy": "ram", "pickup": "pickup", "police": "police"}.get(b.kind, "kick")
	if not combat.damage(float(b.kp.get("dmg", BikeCombatData.ENEMY_KICK_DMG)), cause, 1 if lat > 0.0 else -1):
		return "ignored"
	attack_hits += 1
	if hud:
		var t: String = {"stick": BikeCombatData.T_STICK_HIT, "heavy": BikeCombatData.T_HEAVY_HIT, "pickup": BikeCombatData.T_HEAVY_HIT}.get(b.kind, "")
		if t != "":
			hud.popup(t, CombatHUD.WARN, 0.9)
	if b.kind == "pickup" or b.kind == "heavy":
		bike.current_speed_ms *= 0.8
		bike.add_camera_shake(0.6)
	return "hit"


## A biker crashed (BikerEnemy.crash): biker_down, then the wave clear / the finish.
func on_biker_crash(b: BikerEnemy) -> void:
	downed_total += 1
	last_down = b
	biker_down.emit(b, b.crash_cause)
	if BikeCombatData.TAKEDOWN_CAUSES.has(b.crash_cause):
		_takedown(b)
	elif hud:
		hud.popup(BikeCombatData.T_DOWN, CombatHUD.GOLD)
	if state != "running" or not pending.is_empty() or alive_count() > 0:
		return
	wave_cleared.emit(wave)
	combat.stability = minf(combat.max_stability, combat.stability + BikeCombatData.WAVE_REFILL)
	if wave + 1 < waves.size():
		if bool(wave_opt(wave + 1, "after_cameo", false)) and not cameo_opts.is_empty() and cameo_state != "done":
			if cameo_state == "":
				cameo_state = "waiting"      # Sói Xám comes once the player is past the cameo point
			return
		_gap_left = BikeCombatData.WAVE_GAP_S
		return
	state = "finishing"
	combat.enabled = false
	end_slow_motion()
	_cam_restore()
	_set_hooks(false)
	_mark_end()
	if rec:
		rec.mark("blow")
	_finish_left = BikeCombatData.REPLAY_AFTER


## A takedown (spec D2X-5): the counter, a rotating popup, nitro charge, and (rate-limited) 0.5 s of slow motion with a
## quick side camera cut on the falling rider.
func _takedown(b: BikerEnemy) -> void:
	takedowns += 1
	add_charge(BikeCombatData.TD_CHARGE)
	takedown.emit(b, b.crash_cause)
	if hud:
		var line: String = BikeCombatData.T_AIR_KICK if b.crash_cause == "air" else BikeCombatData.T_TAKEDOWN[_td_i % BikeCombatData.T_TAKEDOWN.size()]
		if b.kind == "pickup":
			line = BikeCombatData.T_PICKUP_DOWN
		_td_i += 1
		hud.popup(line, CombatHUD.GOLD, 1.3)
	if not takedown_slow_allowed():
		return
	var prev_jump: bool = slow_kind == "jump"
	if slow_motion(BikeCombatData.TD_SCALE, BikeCombatData.TD_REAL_S, "td"):
		td_slowmos += 1
		_last_td_slow = _rt
		if takedown_cam and not prev_jump:
			_cam_cut(b)


## A takedown slow motion may run now: the chase is running, the last one TD_GAP_S ago or more, no opening / cameo, and
## fewer than 2 attackers winding up within TD_BUSY_M of the player.
func takedown_slow_allowed() -> bool:
	if state != "running" or opening_on or cameo_state == "running" or _rt - _last_td_slow < BikeCombatData.TD_GAP_S:
		return false
	var busy: int = 0
	for e: Variant in bikers:
		var be: BikerEnemy = e as BikerEnemy
		if be != null and is_instance_valid(be) and be.telegraphing() and be.pos2.distance_to(p_pos) < BikeCombatData.TD_BUSY_M:
			busy += 1
	return busy < 2


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
	if _is_dying():
		return                             # freed mid-replay: no `won`
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
	end_slow_motion()
	_cam_restore()
	_end_opening_visuals()
	if jump_left > 0.0 or not _air.is_empty():
		_land()
	for b: Variant in bikers:
		if is_instance_valid(b):
			(b as BikerEnemy).stand_down()
	_set_hooks(false)
	if hud:
		hud.popup(BikeCombatData.T_KNOCKED_OFF, CombatHUD.WARN, 1.6)
		hud.linger(1.6)
	lost.emit()


func _finish() -> void:
	end_slow_motion()
	_cam_restore()
	_end_opening_visuals()
	if jump_left > 0.0 or not _air.is_empty():
		_land()
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
	_cap_bike(on)
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


## Spec owner-bike OB-D2: the bikers top out at BikeCombatData.MAX_SPEED (31 m/s, 8 m/s above the player while closing
## in), tuned against the 22.5 / 27 m/s bike. The owner's 120 km/h bike would outrun every wave, so while the chase runs
## the player's bike rides on PlayerBike.STAGE_PROFILE; its own profile comes back with the hooks.
func _cap_bike(on: bool) -> void:
	if bike == null or not is_instance_valid(bike):
		return
	if on:
		_bike_profile = bike.speed_profile()
		bike.apply_speed_profile(profile)
	elif not _bike_profile.is_empty():
		bike.apply_speed_profile(_bike_profile)
		_bike_profile = {}


## RoamTraffic look-ahead obstacles: the riding bikers as small oriented boxes (kind "biker").
func _traffic_obstacles() -> Array:
	_obstacles.clear()
	var k: int = 0
	for b: Variant in bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e == null or not is_instance_valid(e) or e.gone or not e.riding():
			continue
		if k >= _obs_pool.size():
			_obs_pool.append([Vector2.ZERO, 1.0, 0.45, "biker", null, Vector2.ZERO])
		var o: Array = _obs_pool[k]
		o[0] = e.pos2
		o[5] = Vector2(-sin(e.yaw), -cos(e.yaw))
		_obstacles.append(o)
		k += 1
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
## carry: the previous wave's riders still riding stay in the fight (a forced wave start, the cameo).
func _start_wave(i: int, carry: bool = false) -> void:
	if carry:
		for k: int in range(bikers.size() - 1, -1, -1):
			var e: BikerEnemy = bikers[k] as BikerEnemy
			if e == null or not is_instance_valid(e):
				bikers.remove_at(k)
			elif e.is_down():
				_downed.append(e)
				bikers.remove_at(k)
	else:
		_retire_wave()
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
		var kn: String = String(BikeCombatData.KIND_NAMES.get(String(o.get("kind", "rider")), ""))
		o["label"] = kn if kn != "" else BikeCombatData.NAMES[_spawned % BikeCombatData.NAMES.size()]
	b.ch = self
	b.setup(o)
	add_child(b)
	var from: String = String(sp.get("from", "behind"))
	var ahead: bool = from == "ahead"
	var lane: float = float(sp.get("lane", [-1, 1, 0][_wave_spawned % 3]))
	var gap: float = float(sp.get("gap", 0.0)) + SPAWN_STEP_M * float(_wave_spawned)
	var base_y: float = bike.global_position.y + BIKE_FLOOR_OFFSET
	var along: float = -BEHIND_M - gap
	var p2: Vector2 = Vector2.ZERO
	var placed: bool = false
	if from == "side":
		# out of the side road beside the player, just out of view (the camera sits behind the bike)
		var sd: float = -1.0 if lane < 0.0 else 1.0
		var a: float = -1.0 - 1.5 * float(_wave_spawned % 2)
		for k0: int in 6:
			var q0: Vector2 = side_point(a, sd)
			if not in_view(Vector3(q0.x, base_y + 1.0, q0.y)) and _clear_of_traffic(q0):
				p2 = q0
				placed = true
				break
			a -= 2.5
		if placed:
			along = a
	elif ahead:
		# out of view ahead (pop-in) and still on the route; else it comes from behind and takes the front
		for a: float in AHEAD_TRY:
			if not room_ahead(a + gap + 5.0):
				break
			var q: Vector2 = target_at(a + gap, lane * LANE_M)
			if not in_view(Vector3(q.x, base_y + 1.0, q.y)) and _clear_of_traffic(q):
				along = a + gap
				p2 = q
				placed = true
				break
		if not placed:
			ahead = false
			b.prefer_front = true
	if not placed:
		p2 = target_at(along, lane * LANE_M)
		for k: int in 4:
			if _clear_of_traffic(p2):
				break
			along -= 8.0
			p2 = target_at(along, lane * LANE_M)
	var y: Variant = floor_at(Vector3(p2.x, base_y, p2.y))
	var fy: float = float(y) if y is float else base_y
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


## Map point `along` m ahead of the player, past the road's edge on side sd (a side road / the kerb): "side" spawns.
func side_point(along: float, sd: float) -> Vector2:
	if route != null and s_p >= 0.0:
		var s: float = clampf(s_p + along * dir_sign, 0.0, route.length)
		return route.world(s, sd * (route.half_width + BikeCombatData.SIDE_SPAWN_LAT) * dir_sign)
	return p_pos + p_fwd * along + p_right * sd * (BikeCombatData.ROAD_HALF + BikeCombatData.SIDE_SPAWN_LAT)


## The police set piece: n police riders from behind (out of view), sirens on; they ram bikers and the player alike.
func spawn_police(n: int) -> void:
	for i: int in n:
		var b := BikerEnemy.new()
		b.name = "Police%d" % cops.size()
		b.ch = self
		b.setup({"kind": "police", "label": BikeCombatData.KIND_NAMES["police"], "seed": chase_seed * 7000 + cops.size(), "aggression": 0.7})
		add_child(b)
		var sd: float = -1.0 if i % 2 == 0 else 1.0
		var along: float = -22.0 - 6.0 * float(i)
		var p2: Vector2 = target_at(along, sd * 1.5)
		var base_y: float = bike.global_position.y + BIKE_FLOOR_OFFSET
		var y: Variant = floor_at(Vector3(p2.x, base_y, p2.y))
		b.place(Vector3(p2.x, float(y) if y is float else base_y, p2.y), atan2(-p_fwd.x, -p_fwd.y), p_vel.length() + 4.0)
		b.side = sd
		cops.append(b)
	if hud:
		hud.popup(BikeCombatData.T_POLICE, CombatHUD.WARN, 1.6)


## The police drop back (ride off behind, hidden out of view).
func release_police() -> void:
	for c: Variant in cops:
		if is_instance_valid(c):
			var e: BikerEnemy = c
			e.ram_target = null
			e.stand_down()
			e.leave_along = -90.0


## The police may go for the player now (POLICE_PLAYER_GAP_S since the last time).
func police_player_ok() -> bool:
	return police_player_t <= 0.0


func police_active() -> int:
	var n: int = 0
	for c: Variant in cops:
		if is_instance_valid(c) and (c as BikerEnemy).is_active():
			n += 1
	return n


func _clear_bikers() -> void:
	for c: Variant in cops:
		if is_instance_valid(c):
			(c as Node).queue_free()
	cops.clear()
	for b: Variant in bikers:
		if is_instance_valid(b):
			(b as Node).queue_free()
	bikers.clear()
	for b2: Variant in _downed:
		if is_instance_valid(b2):
			(b2 as Node).queue_free()
	_downed.clear()
	_holders.clear()


## Next wave: the cleared wave's downed riders stay (stars, groan) until out of view; anything else goes.
func _retire_wave() -> void:
	for b: Variant in bikers:
		if not is_instance_valid(b):
			continue
		if (b as BikerEnemy).is_down():
			_downed.append(b)
		else:
			(b as Node).queue_free()
	bikers.clear()
	_holders.clear()


## Free every crashed / downed rider now (cleared waves and the current one), e.g. before the bridge duel.
func clear_downed() -> void:
	for b: Variant in _downed:
		if is_instance_valid(b):
			(b as Node).queue_free()
	_downed.clear()
	for i: int in range(bikers.size() - 1, -1, -1):
		var e: BikerEnemy = bikers[i] as BikerEnemy
		if e != null and is_instance_valid(e) and e.is_down():
			e.queue_free()
			bikers.remove_at(i)


## Downed riders of cleared waves: freed once out of view (never mid-stars in front of the camera).
func _clean_downed() -> void:
	for i: int in range(_downed.size() - 1, -1, -1):
		var e: BikerEnemy = _downed[i] as BikerEnemy
		if e == null or not is_instance_valid(e):
			_downed.remove_at(i)
		elif not in_view(e.rider_pos + Vector3(0.0, 0.5, 0.0)) and not in_view(e.ground_pos() + Vector3(0.0, 0.5, 0.0)):
			e.queue_free()
			_downed.remove_at(i)


# ---------------------------------------------------------------------------
# PER FRAME
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if bike == null or not is_instance_valid(bike):
		return
	var rdt: float = delta / maxf(Engine.time_scale, 0.01)   # real seconds (slow motion scales the physics delta)
	_update_frame()
	_tick_slow(rdt)
	_tick_cam(rdt)
	_clean_t -= delta
	if _clean_t <= 0.0:
		_clean_t = 0.25
		_clean_downed()
	if state == "idle" or state == "won":
		_tick_after(delta)
		_prev_speed = absf(bike.current_speed_ms)
		return
	_t += delta
	_rt += rdt
	if state == "running":
		if combat.knocked:
			_on_lost()
		else:
			if opening_on:
				_tick_opening(rdt)
			_spawn_due(delta)
			_role_t -= delta
			if _role_t <= 0.0:
				_role_t = BikeCombatData.ROLE_EVERY
				_assign_roles()
			_tick_waves_by_distance()
			if set_pieces:
				set_pieces.tick(delta, rdt)
			if cameo:
				cameo.tick(delta, rdt)
			_check_end()
			if state != "running":
				_prev_speed = absf(bike.current_speed_ms)
				return
	_box_cd -= delta
	police_player_t -= delta
	_tick_jump(rdt)
	for b: Variant in bikers:
		if is_instance_valid(b):
			(b as BikerEnemy).tick(delta)
	for c: Variant in cops:
		if is_instance_valid(c):
			(c as BikerEnemy).tick(delta)
	for b2: Variant in _downed:
		if is_instance_valid(b2):
			(b2 as BikerEnemy).tick(delta)
	_tick_helmets(delta)
	_player_contact()
	_separate()
	max_attackers_seen = maxi(max_attackers_seen, attackers())
	_prev_speed = absf(bike.current_speed_ms)
	if state == "finishing" and _finish_left >= 0.0:
		_finish_left -= delta
		if _finish_left < 0.0:
			_end_finishing()
		return
	if state == "running" and _gap_left >= 0.0:
		_gap_left -= delta
		if _gap_left < 0.0:
			_start_wave(wave + 1)


## force_s waves (the player got there with the previous wave still riding: it joins them) and the cameo: after its wave's
## predecessor is cleared once the player is past the cameo point, or at its force point anyway.
func _tick_waves_by_distance() -> void:
	if s_p < 0.0 or wave + 1 >= waves.size() or cameo_state == "running":
		return
	var nxt: int = wave + 1
	if bool(wave_opt(nxt, "after_cameo", false)) and not cameo_opts.is_empty():
		var c_s: float = float(cameo_opts.get("s", BikeCombatData.CAMEO_S))
		var c_force: float = float(cameo_opts.get("force_s", BikeCombatData.CAMEO_FORCE_S))
		if (cameo_state == "waiting" and s_p >= c_s) or (cameo_state == "" and s_p >= c_force):
			_begin_cameo()
		elif cameo_state == "done" and _gap_left < 0.0 and alive_count() == 0 and pending.is_empty():
			_start_wave(nxt)
		return
	var fs: float = float(wave_opt(nxt, "force_s", -1.0))
	if fs >= 0.0 and s_p >= fs:
		_start_wave(nxt, true)


## After `won` / stop: the crashed riders finish their tumble and slide, the downed ones keep their stars and groan, the
## ones riding off keep going until out of view.
func _tick_after(delta: float) -> void:
	for b: Variant in bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e != null and is_instance_valid(e) and (e.is_down() or (e.st == BikerEnemy.St.LEAVE and not e.gone)):
			e.tick(delta)
	for b2: Variant in _downed:
		if is_instance_valid(b2):
			(b2 as BikerEnemy).tick(delta)


## The chase's last point: end_at_s, or END_MARGIN before the route end. Reached with bikers left, they ride off (out of
## view), no replay, `won` with escaped = the bikers not beaten.
func _check_end() -> void:
	if route == null or s_p < 0.0 or absf(d_p) > route.half_width + 10.0:
		return
	var lim: float = end_at_s if end_at_s >= 0.0 else route.length - BikeCombatData.END_MARGIN
	if s_p < lim:
		return
	escaped = alive_count() + pending.size()
	for i: int in range(wave + 1, waves.size()):
		escaped += (waves[i] as Array).size()
	ended_early = true
	pending.clear()
	_gap_left = -1.0
	for b: Variant in bikers:
		if is_instance_valid(b):
			(b as BikerEnemy).stand_down()
	_holders.clear()
	_mark_end()
	state = "won"
	_finish()
	if hud and win_line != "":
		hud.show_hud()
		hud.popup(win_line, CombatHUD.GOLD, 2.2)
		hud.linger(2.2)
	won.emit()


func _mark_end() -> void:
	end_s = s_p
	end_xf = bike.global_transform


func end_position() -> Vector3:
	return end_xf.origin


## The Rạch Hầm bridge on the route (route distance), -1 when the route does not cross it.
func bridge_s() -> float:
	return route.bridge_s if route else -1.0


## The bike on the bridge deck there, facing along the route (identity when there is no bridge).
func bridge_transform() -> Transform3D:
	return route_transform(bridge_s()) if bridge_s() >= 0.0 else Transform3D.IDENTITY


## There is route ahead of the player (or no route at all).
func room_ahead(m: float) -> bool:
	if route == null or s_p < 0.0:
		return true
	var s: float = s_p + m * dir_sign
	return s > 0.0 and s < route.length


## In front of the current camera and nearer than VIEW_M (pop-in / pop-out checks).
func in_view(p: Vector3) -> bool:
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	return cam != null and cam.global_position.distance_to(p) < BikeCombatData.VIEW_M and cam.is_position_in_frustum(p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_dying = true


## Being freed (this node or an ancestor queued for deletion).
func _is_dying() -> bool:
	if _dying:
		return true
	var n: Node = self
	while n != null:
		if n.is_queued_for_deletion():
			return true
		n = n.get_parent()
	return false


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
		var pr: Vector2 = route.project(p_pos, _hint)
		s_p = pr.x
		d_p = pr.y
		on_route = absf(d_p) <= route.half_width + 6.0 and s_p > 0.5 and s_p < route.length - 0.5
		_hint = s_p if absf(d_p) <= route.half_width + 30.0 else -1.0   # far off: search the whole route next frame
		var t: Vector2 = route.tangent(s_p)
		var hd: float = hf.dot(t)
		if on_route and absf(hd) > 0.3:
			dir_sign = signf(hd)
		p_fwd = t * dir_sign               # off the road too: the AI stays in the route frame (clamped to the road)
	else:
		p_fwd = hf
	p_right = Vector2(-p_fwd.y, p_fwd.x)


## World point (map plane) at `along` m ahead and `lat` m to the right of the player: on the route clamped to its
## half width, else in his heading frame.
func target_at(along: float, lat: float) -> Vector2:
	if route != null and s_p >= 0.0:
		var s: float = clampf(s_p + along * dir_sign, 0.0, route.length)
		var d: float = clampf(d_p + lat * dir_sign, maxf(-route.half_width, d_lo), minf(route.half_width, d_hi))
		return route.world(s, d)
	return p_pos + p_fwd * along + p_right * lat


## A flank slot on `side` has room: on the road (not squeezed past the edge by more than SLOT_SQUEEZE) and no car in it
## or running into it soon (a slower car ahead in that lane, an oncoming one, one alongside the player).
func slot_fits(side: float) -> bool:
	if route != null and s_p >= 0.0:
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
	if route == null or s_p < 0.0:
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
		if e != null and is_instance_valid(e) and e.is_active() and e.st != BikerEnemy.St.WOBBLE and e.st != BikerEnemy.St.HOLD 				and BikerEnemy.ROLE_KINDS.has(e.kind):
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
		if e.role == BikerEnemy.Role.FRONT and front == null and (_act.size() >= 3 or e.prefer_front):
			front = e
		elif e.role == BikerEnemy.Role.LEFT and left == null and fit_l:
			left = e
		elif e.role == BikerEnemy.Role.RIGHT and right == null and fit_r:
			right = e
	if front == null:
		var best: float = -INF
		for e: BikerEnemy in _act:
			if e == left or e == right or not (_act.size() >= 3 or e.prefer_front):
				continue
			var al: float = (e.pos2 - p_pos).dot(p_fwd) + (1000.0 if e.prefer_front else 0.0)
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


## The player's bike against the bikers and the police (no physics bodies): riding into a biker's back wheel is a ram
## (speed matched, RAM_DMG); a biker overlapping the bike from the side is pushed out (its half width + 0.5 m). During
## nitro any touch is a takedown ("nitro"), the pickup and the police excepted.
func _player_contact() -> void:
	if combat.knocked:
		return
	var p_speed: float = p_vel.dot(b_fwd)
	var nitro: bool = state == "running" and bike_nitro()
	for k: int in bikers.size() + cops.size():
		var e: BikerEnemy = (bikers[k] if k < bikers.size() else cops[k - bikers.size()]) as BikerEnemy
		if e == null or not is_instance_valid(e) or not e.riding() or e.gone:
			continue
		var he: Vector2 = e.half_extents()
		var rel: Vector2 = e.pos2 - p_pos
		var along: float = rel.dot(b_fwd)
		var lat: float = rel.dot(b_right)
		var gap_lat: float = he.x + 0.5
		if absf(along) > he.y + 1.05 or absf(lat) > gap_lat:
			continue
		if nitro and e.kind != "pickup" and e.kind != "police" and e.is_active():
			e.crash("nitro", b_right * (signf(lat) if absf(lat) > 0.05 else 1.0) * 4.0 + b_fwd * 3.0)
			continue
		if along > he.y - 0.35 and absf(lat) < he.x + 0.25:
			var e_speed: float = e.vel.dot(b_fwd)
			if p_speed > e_speed + 0.5:
				bike.current_speed_ms = maxf(0.0, e_speed - 0.5)
				if state == "running" and combat.ram_cd <= 0.0:
					combat.ram_cd = BikeCombatData.RAM_COOLDOWN
					if combat.damage(BikeCombatData.RAM_DMG, "ram") and hud:
						hud.popup(BikeCombatData.T_RAM, CombatHUD.WARN)
			e.pos2 += b_fwd * (he.y + 0.95 - along) * 0.5
		elif e.avoid_t > 0.0 and e.avoid_car >= 0:
			e.pos2 -= b_fwd * 0.25           # squeezed between the player and a car: drop back, not sideways into it
		elif not e.is_attacking():
			var sgn: float = signf(lat) if absf(lat) > 0.01 else e.side
			e.pos2 += b_right * (sgn * gap_lat - lat)


func _separate() -> void:
	var n: int = bikers.size() + cops.size()
	for i: int in n:
		var a: BikerEnemy = (bikers[i] if i < bikers.size() else cops[i - bikers.size()]) as BikerEnemy
		if a == null or not is_instance_valid(a) or not a.riding() or a.gone:
			continue
		for j: int in range(i + 1, n):
			var b: BikerEnemy = (bikers[j] if j < bikers.size() else cops[j - bikers.size()]) as BikerEnemy
			if b == null or not is_instance_valid(b) or not b.riding() or b.gone:
				continue
			var d: Vector2 = b.pos2 - a.pos2
			var l: float = d.length()
			var sep: float = BikeCombatData.SEPARATION if (a.kind != "pickup" and b.kind != "pickup") else 2.6
			if l >= sep:
				continue
			var n2: Vector2 = d / l if l > 0.01 else p_right
			var push: Vector2 = n2 * (sep - l) * 0.5
			a.pos2 -= push
			b.pos2 += push


# ---------------------------------------------------------------------------
# FX / SOUND (BikerEnemy calls these)
# ---------------------------------------------------------------------------
func cue(c: String, at: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	if _sfx.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	if c == "horn":
		p.stream = _horn
	else:
		p.stream = WeaponAudio.stream(c) if WeaponAudio.CUES.has(c) else CineAudio.sfx(c)
	p.pitch_scale = pitch
	p.volume_db = db
	p.global_position = at
	p.play()


func sparks(at: Vector3, dir: Vector3) -> void:
	if fx:
		fx.burst("sparks", at, dir, 0.7)


func stars(anchor: Node3D, secs: float) -> void:
	if fx:
		fx.stars(anchor, secs)


# ---------------------------------------------------------------------------
# DAY 2: agent B's bike interface, slow motion, cameras, the opening, the cameo, thrown helmets, the ramp jump
# ---------------------------------------------------------------------------
func _ready() -> void:
	process_physics_priority = 1             # after the PlayerBike (0): the jump lift is written after its own bob


## PlayerBike.is_ducking() (agent B's interface; duck_fn stands in for it in tests).
func bike_ducking() -> bool:
	if duck_fn.is_valid():
		return bool(duck_fn.call())
	return bike != null and is_instance_valid(bike) and bike.has_method("is_ducking") and bool(bike.call("is_ducking"))


## PlayerBike.nitro_active() (agent B's interface; nitro_fn stands in for it in tests).
func bike_nitro() -> bool:
	if nitro_fn.is_valid():
		return bool(nitro_fn.call())
	return bike != null and is_instance_valid(bike) and bike.has_method("nitro_active") and bool(bike.call("nitro_active"))


## PlayerBike.add_drift_charge(points) (agent B's interface; charge_fn stands in for it in tests). Counted in charge_given.
func add_charge(points: float) -> void:
	charge_given += points
	if charge_fn.is_valid():
		charge_fn.call(points)
	elif bike != null and is_instance_valid(bike) and bike.has_method("add_drift_charge"):
		bike.call("add_drift_charge", points)


## Free metres from the player's line to the AI's road edge on `side` (player frame; 99 without a route).
func lat_room(side: float) -> float:
	if route == null or s_p < 0.0:
		return 99.0
	if side * dir_sign > 0.0:
		return minf(route.half_width, d_hi) - d_p
	return d_p - maxf(-route.half_width, d_lo)


## PlayerBike.crash_occurred (connected before PlayerBikeCombat's own handler): 15-25 stability by the speed before the
## crash; PlayerBikeCombat's flat CRASH_DMG then falls inside the i-frames.
func _on_bike_crash() -> void:
	if state != "running" or combat == null or not combat.enabled:
		return
	var top: float = float(profile.get("max_speed_ms", 27.8))
	var u: float = clampf((_prev_speed - 6.0) / maxf(top - 6.0, 1.0), 0.0, 1.0)
	combat.damage(lerpf(BikeCombatData.CRASH_DMG_MIN, BikeCombatData.CRASH_DMG_MAX, u), "crash")


## PlayerBikeCombat.kick_hit: a spin kick (side 0, agent B) that hits two riders within SPIN_PAIR_S downs both, tagged
## "spin" (a takedown each).
func _on_kick_hit(target: Node3D, side: int) -> void:
	if side != 0 or not (target is BikerEnemy):
		return
	for i: int in range(_spin_hits.size() - 1, -1, -1):
		var e: Array = _spin_hits[i]
		if _rt - float(e[1]) > BikeCombatData.SPIN_PAIR_S or not is_instance_valid(e[0]) or e[0] == target:
			_spin_hits.remove_at(i)
	_spin_hits.append([target, _rt])
	if _spin_hits.size() >= 2:
		for e2: Array in _spin_hits:
			var b: BikerEnemy = e2[0]
			if b.kickable() or b.st == BikerEnemy.St.WOBBLE:
				b.takedown_tag = "spin"
				b.hp = 0
		_spin_hits.clear()


## Slow motion for `real_s` real seconds (INF: until end_slow_motion). false when a weapon wheel owns the time scale.
func slow_motion(scale: float, real_s: float, kind: String) -> bool:
	if RadialWheel.scale_owner != null and RadialWheel.scale_owner != self and is_instance_valid(RadialWheel.scale_owner):
		return false
	RadialWheel.scale_owner = self
	Engine.time_scale = clampf(scale, 0.05, 1.0)
	_slow_left = real_s
	slow_kind = kind
	return true


## Back to normal time (only if this chase owns the time scale).
func end_slow_motion() -> void:
	_slow_left = 0.0
	slow_kind = ""
	if RadialWheel.scale_owner == self:
		Engine.time_scale = 1.0
		RadialWheel.scale_owner = null


func _tick_slow(rdt: float) -> void:
	if slow_kind == "" or _slow_left == INF:
		return
	_slow_left -= rdt
	if _slow_left > 0.0:
		return
	end_slow_motion()
	if cam_mode == "td":                     # a takedown cut ends with its slow motion (or the jump that replaced it)
		_cam_restore()
	if jump_left > 0.05 and state == "running":
		slow_motion(BikeCombatData.JUMP_SCALE, jump_left, "jump")


func _cam_use(mode: String) -> void:
	if cam == null or not is_inside_tree():
		return
	if cam_mode == "":
		var cur: Camera3D = get_viewport().get_camera_3d()
		_cam_prev = cur if cur != cam else null
	cam_mode = mode
	cam.make_current()


## Back to the camera that was current before (the bike's chase camera when that one is gone).
func _cam_restore() -> void:
	if cam_mode == "":
		return
	cam_mode = ""
	_cam_target = null
	if cam and is_instance_valid(cam) and cam.current:
		var back: Camera3D = _cam_prev if (_cam_prev != null and is_instance_valid(_cam_prev) and _cam_prev.is_inside_tree()) else null
		if back != null and back.has_meta(CameraDirector.META_CUT):
			back = null                       # a director cut ran when this cut began: back to the bike, not its camera
		if back == null and bike != null and is_instance_valid(bike) and bike.chase_cam:
			back = bike.chase_cam
		if back:
			back.make_current()
		else:
			cam.clear_current(false)
	_cam_prev = null


## A quick camera cut on a falling rider (takedown): the first of CameraRules.TD_CANDIDATES (side, front-low, high-rear) with
## a clear view of the rider (CameraFraming occlusion test), re-checked every TD_RECHECK_S.
func _cam_cut(b: BikerEnemy) -> void:
	_cam_target = b
	_cam_side = p_right * (1.0 if (b.pos2 - p_pos).dot(p_right) >= 0.0 else -1.0)
	cam_pick = _cam_pick_td()
	_cam_check_t = CameraRules.TD_RECHECK_S
	_cam_use("td")
	_tick_cam()


## The kick whip (PlayerBikeCombat.kick_hit): the chase cam turns 0.12 s toward the rider.
func _cam_on_kick(target: Node3D, _side: int) -> void:
	if bike != null and is_instance_valid(bike) and target != null and is_instance_valid(target) and bike.has_method("cam_whip"):
		bike.cam_whip(target.global_position - bike.global_position)


## The takedown target point (the flying rider, else the bike on the ground) and the camera spot of candidate i.
func _cam_td_center() -> Vector3:
	var c: Vector3 = _cam_target.rider_pos if (_cam_target.st == BikerEnemy.St.CRASH and _cam_target.kind != "pickup") else _cam_target.ground_pos()
	return Vector3(c.x, maxf(c.y, _cam_target.floor_y), c.z)


func _cam_td_pos(i: int, c: Vector3) -> Vector3:
	var o: Vector3 = CameraRules.TD_CANDIDATES[i]
	var s3 := Vector3(_cam_side.x, 0.0, _cam_side.y)
	var f3 := Vector3(p_fwd.x, 0.0, p_fwd.y)
	return c + s3 * o.x + Vector3.UP * o.y + f3 * o.z


func _cam_pick_td() -> int:
	if _cam_target == null or not is_instance_valid(_cam_target) or not is_inside_tree():
		return 0
	var c: Vector3 = _cam_td_center()
	var cands: Array[Vector3] = []
	for i: int in CameraRules.TD_CANDIDATES.size():
		cands.append(_cam_td_pos(i, c))
	return maxi(0, CameraFraming.pick(get_world_3d().direct_space_state, cands, _cam_td_points(c), _cam_td_excl()))


## Candidate i still sees the rider (the re-check keeps a clear angle: no flicking between two clear ones).
func _cam_td_ok(i: int) -> bool:
	if _cam_target == null or not is_instance_valid(_cam_target) or not is_inside_tree():
		return false
	var c: Vector3 = _cam_td_center()
	return CameraFraming.view_ok(get_world_3d().direct_space_state, _cam_td_pos(i, c), _cam_td_points(c), _cam_td_excl())


static func _cam_td_points(c: Vector3) -> PackedVector3Array:
	return PackedVector3Array([c + Vector3.UP * 0.5, c + Vector3.UP * 1.2])


func _cam_td_excl() -> Array[RID]:
	var excl: Array[RID] = _ray_excl.duplicate()
	var bw: Variant = roam.get("bank_walls") if roam else null
	if bw is CollisionObject3D:
		excl.append((bw as CollisionObject3D).get_rid())
	return excl


func _tick_cam(rdt: float = 0.0) -> void:
	if cam_mode == "" or bike == null or not is_instance_valid(bike):
		return
	var f3 := Vector3(p_fwd.x, 0.0, p_fwd.y)
	var r3 := Vector3(p_right.x, 0.0, p_right.y)
	var bp: Vector3 = bike.global_position
	if cam_mode == "open":
		cam.global_position = bp - f3 * BikeCombatData.OPEN_CAM_BACK + Vector3.UP * BikeCombatData.OPEN_CAM_UP + r3 * 0.35
		cam.look_at(bp + f3 * 8.0 + Vector3.UP * 0.9, Vector3.UP)
	elif cam_mode == "td":
		if _cam_target == null or not is_instance_valid(_cam_target):
			_cam_restore()
			return
		_cam_check_t -= rdt
		if _cam_check_t <= 0.0:              # re-check at 10 Hz: only a blocked angle is re-picked (no flicking)
			_cam_check_t = CameraRules.TD_RECHECK_S
			if not _cam_td_ok(cam_pick):
				var np: int = _cam_pick_td()
				if np != cam_pick:
					cam_pick = np
					cam_repicks += 1
		var c: Vector3 = _cam_td_center()
		cam.global_position = _cam_td_pos(cam_pick, c)
		cam.look_at(c + Vector3.UP * 0.5, Vector3.UP)


func _begin_opening() -> void:
	opening_on = true
	open_t = 0.0
	drop_by_music = false
	slow_motion(float(opening.get("scale", BikeCombatData.OPEN_SCALE)), INF, "open")
	_cam_use("open")
	_tick_cam()
	if hud:
		hud.letterbox(true)
	set_piece.emit("opening", "start")


## Film opening (D2X-3): the drop at drop_s by the chase track's playback position when music_pos_fn reports one (a
## track that stalls falls back to the timer 1.5 s later), else by the real-time timer.
func _tick_opening(rdt: float) -> void:
	open_t += rdt
	var drop_s: float = float(opening.get("drop_s", BikeCombatData.OPEN_DROP_S))
	var mp: float = float(music_pos_fn.call()) if music_pos_fn.is_valid() else -1.0
	if mp >= 0.0 and open_t < drop_s + 1.5:
		if mp >= drop_s:
			drop_by_music = true
			_drop()
	elif open_t >= drop_s:
		_drop()


## The drop: time snaps back with a camera shake, wave 0 bursts out of the side roads (LED eyes flaring, horns).
func _drop() -> void:
	opening_on = false
	drop_at = open_t
	if slow_kind == "open":
		end_slow_motion()
	_cam_restore()
	if hud:
		hud.letterbox(false)
	bike.add_camera_shake(0.9)
	_start_wave(0)
	var k: int = 0
	for b: Variant in bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e == null:
			continue
		e.flare()
		if k < 2:
			cue("horn", e.ground_pos() + Vector3(0.0, 1.0, 0.0), 3.0, 0.85 + 0.25 * float(k))
		k += 1
	opening_drop.emit()
	set_piece.emit("opening", "drop")


func _end_opening_visuals() -> void:
	opening_on = false
	if hud:
		hud.letterbox(false)


## A knock-off from the cameo start on retries at its point: with the card not seen yet the cameo comes again (retry()),
## after the card the next wave starts at once.
func _begin_cameo() -> void:
	cameo_state = "running"
	if auto_checkpoint and bike:
		_cp = {"wave": wave + 1, "xf": bike.global_transform, "s": s_p}
		_clamp_checkpoint()
	if cameo and is_instance_valid(cameo):
		cameo.queue_free()
	cameo = BikeCameo.new()
	cameo.name = "Cameo"
	add_child(cameo)
	cameo.setup(self, cameo_opts)
	cameo.finished.connect(_on_cameo_done, CONNECT_ONE_SHOT)
	cameo.card_done.connect(func() -> void: cameo_card_seen = true, CONNECT_ONE_SHOT)
	cameo.begin()
	cameo_started.emit()
	set_piece.emit("cameo", "start")


func _on_cameo_done() -> void:
	cameo_state = "done"
	cameo_done.emit()
	set_piece.emit("cameo", "done")
	if state == "running" and wave + 1 < waves.size():
		_start_wave(wave + 1, true)


func _make_helmet(i: int) -> Dictionary:
	var n := Node3D.new()
	n.name = "Helmet%d" % i
	n.top_level = true
	add_child(n)
	CineFX._sphere(n, "Shell", 0.17, Vector3.ZERO, CineFX._mat(BikeCombatData.HELMET_COL, 0.4), Vector3(1.0, 0.9, 1.1))
	CineFX._box(n, "Visor", Vector3(0.2, 0.07, 0.04), Vector3(0.0, 0.0, 0.16), CineFX._glow_mat(BikeCombatData.EYE_COL, 2.0))
	n.visible = false
	var m := MeshInstance3D.new()
	m.name = "HelmetMark%d" % i
	var cm := CylinderMesh.new()
	cm.top_radius = BikeCombatData.THROW_R
	cm.bottom_radius = BikeCombatData.THROW_R
	cm.height = 0.02
	cm.radial_segments = 28
	cm.rings = 1
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.08, 0.06, 0.45)
	mat.set_meta("vice_done", true)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	m.visible = false
	add_child(m)
	return {"node": n, "mark": m, "mat": mat, "t": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "active": false, "by": null}


## The thrower's helmet: it lands THROW_FLIGHT s from now where the player will be (kept on the road); the red marker
## shows there at once. Returns the landing point (map plane).
func throw_helmet(b: BikerEnemy) -> Vector2:
	var land: Vector2 = p_pos + p_vel * BikeCombatData.THROW_FLIGHT
	if route != null and s_p >= 0.0:
		var pr: Vector2 = route.project(land, s_p, 80.0)
		land = route.world(pr.x, clampf(pr.y, -route.half_width, route.half_width))
	for h: Dictionary in helmets:
		if bool(h["active"]):
			continue
		var fy: float = bike.global_position.y + BIKE_FLOOR_OFFSET
		h["active"] = true
		h["t"] = 0.0
		h["by"] = b
		h["from"] = b.helmet_prop.global_position if (b.helmet_prop and is_instance_valid(b.helmet_prop)) else b.ground_pos() + Vector3(0.0, 1.9, 0.0)
		h["to"] = Vector3(land.x, fy, land.y)
		(h["node"] as Node3D).visible = true
		(h["node"] as Node3D).global_position = h["from"]
		var mk: MeshInstance3D = h["mark"]
		mk.visible = true
		mk.global_position = Vector3(land.x, fy + 0.04, land.y)
		helmets_thrown += 1
		cue("swish", b.ground_pos() + Vector3(0.0, 1.8, 0.0), 0.0)
		break
	return land


func _tick_helmets(delta: float) -> void:
	for h: Dictionary in helmets:
		if not bool(h["active"]):
			continue
		h["t"] = float(h["t"]) + delta
		var u: float = clampf(float(h["t"]) / BikeCombatData.THROW_FLIGHT, 0.0, 1.0)
		var a: Vector3 = h["from"]
		var b: Vector3 = h["to"]
		var n: Node3D = h["node"]
		n.global_position = a.lerp(b, u) + Vector3.UP * (4.0 * BikeCombatData.THROW_ARC * u * (1.0 - u))
		n.rotation.x += delta * 12.0
		var mat: StandardMaterial3D = h["mat"]
		mat.albedo_color.a = 0.3 + 0.3 * absf(sin(float(h["t"]) * 14.0))
		if u < 1.0:
			continue
		h["active"] = false
		n.visible = false
		(h["mark"] as Node3D).visible = false
		sparks(b + Vector3(0.0, 0.2, 0.0), Vector3.UP)
		cue("helmet_clonk", b + Vector3(0.0, 0.3, 0.0), 0.0)
		if state == "running" and Vector2(b.x, b.z).distance_to(p_pos) <= BikeCombatData.THROW_R:
			var by: BikerEnemy = h["by"] as BikerEnemy if is_instance_valid(h["by"]) else null
			var lat: float = (Vector2(b.x, b.z) - p_pos).dot(b_right)
			var dmg: float = float(BikeCombatData.KINDS["thrower"]["dmg"])
			if combat.damage(dmg, "helmet", 1 if lat > 0.0 else -1):
				helmets_hit += 1
				if by:
					by.results.append("hit")
				if hud:
					hud.popup(BikeCombatData.T_HELMET_HIT, CombatHUD.WARN, 0.9)


## The ramp (BikeSetPieces): a scripted jump of JUMP_REAL_S real seconds in slow motion; riders alongside fly too (a kick
## on one in the air is an "air" takedown). The landing is always safe.
func start_jump() -> void:
	if cam_mode == "td":
		_cam_restore()                       # the jump is seen from the bike's own camera
	jump_len = BikeCombatData.JUMP_REAL_S
	jump_left = jump_len
	_air.clear()
	for b: Variant in bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e == null or not is_instance_valid(e) or not e.is_active() or e.kind == "pickup":
			continue
		var rel: Vector2 = e.pos2 - p_pos
		if absf(rel.dot(p_right)) < 4.5 and absf(rel.dot(p_fwd)) < 4.5:
			e.airborne = true
			_air.append(e)
	slow_motion(BikeCombatData.JUMP_SCALE, jump_len, "jump")
	if hud:
		hud.popup(BikeCombatData.T_RAMP, CombatHUD.GOLD, 1.0)
	cue("engine_roar", bike.global_position, 0.0)


func jumping() -> bool:
	return jump_left > 0.0


func _tick_jump(rdt: float) -> void:
	if jump_left <= 0.0:
		return
	jump_left -= rdt
	var u: float = clampf(1.0 - jump_left / maxf(jump_len, 0.01), 0.0, 1.0)
	var h: float = BikeCombatData.JUMP_H * 4.0 * u * (1.0 - u)
	if jump_left <= 0.0:
		h = 0.0
	if bike.visual_pivot:
		bike.visual_pivot.position.y = h
	for b: Variant in _air:
		var e: BikerEnemy = b as BikerEnemy
		if e != null and is_instance_valid(e) and e.airborne:
			e.air_y = h
	if jump_left <= 0.0:
		_land()


func _land() -> void:
	jump_left = 0.0
	for b: Variant in _air:
		var e: BikerEnemy = b as BikerEnemy
		if e != null and is_instance_valid(e):
			e.airborne = false
			e.air_y = 0.0
	_air.clear()
	if bike and is_instance_valid(bike):
		bike.add_camera_shake(0.5)
		if bike.visual_pivot:
			bike.visual_pivot.position.y = 0.0
	if slow_kind == "jump":
		end_slow_motion()
	if cam_mode == "td":
		_cam_restore()


## Day 2 state back to neutral: normal time, the bike's camera, no opening, no jump, no helmet in the air, no lane clamp,
## no cameo rider (stop, retry).
func _reset_day2() -> void:
	end_slow_motion()
	_cam_restore()
	_end_opening_visuals()
	if jump_left > 0.0 or not _air.is_empty():
		_land()
	for h: Dictionary in helmets:
		h["active"] = false
		(h["node"] as Node3D).visible = false
		(h["mark"] as Node3D).visible = false
	d_lo = -INF
	d_hi = INF
	_spin_hits.clear()
	if cameo and is_instance_valid(cameo):
		cameo.queue_free()
	cameo = null
	if cameo_state == "running" or cameo_state == "waiting":
		cameo_state = ""


## Freed or removed without stop(): the hooks go, and with them the speed cap (the bike gets its own profile back), the
## slow motion and the camera.
func _exit_tree() -> void:
	end_slow_motion()
	_cam_restore()
	if jump_left > 0.0 and bike and is_instance_valid(bike) and bike.visual_pivot:
		bike.visual_pivot.position.y = 0.0
	_set_hooks(false)
