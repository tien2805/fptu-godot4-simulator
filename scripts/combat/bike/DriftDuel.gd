# File: res://scripts/combat/bike/DriftDuel.gd
# Encounter node of the Day 2 drift duel with Sói Xám (spec D2X-10, plan 2026-10-27-d2x-drift.md): one lap of the
# DriftCourse "Cầu Rạch Hầm" in FreeRoam, Sói Xám (DriftRival) leading, the player tailing him ("bám đuôi").
#
# ===== API (MissionDriftDuel; tests) =====
#   var duel := DriftDuel.new(); roam.add_child(duel)
#   duel.setup({"roam": roam,          # FreeRoam (bike, player, traffic read from it); or "bike" [+ "player", "traffic"]
#       "course": null,                 # default DriftCourse.rach_ham()
#       "intro": true,                  # Sói Xám beside his bike with his line before the first countdown
#       "target": TARGET_POINTS,        # drift points needed at the finish
#       "seed": 3131})
#   duel.start()                        # mounts and places the player, the intro, then the countdown
#   signals: countdown_started(retry), music_cue (GO + MUSIC_START_OFFSET), go, won(how) ("points" | "overtake"),
#            lost(reason) ("gap" | "points"; the duel retries by itself after LOSE_PAUSE_S + a FADE_S fade), ended (after
#            the ending: his line, he rides down off the bridge, the fade), gate_passed(i), reset_to_gate(i)
#   duel.retry() (quick retry by hand), duel.stop() (end without a result: props stay until freed, hooks and the bike's
#   profile / nitro state restored, traffic back)
#   state: "idle" | "intro" | "countdown" | "racing" | "lost" | "won" | "ending" | "done"
#   s_p / d_p (the player's progress / lateral offset on the lap), gap() (his progress minus the player's), points,
#   gate_i (next gate), losses, resets, knocked_cones
#
# Rules: gap <= TAIL_GAP_M doubles the drift points ("BÁM ĐUÔI!"); gap > LOSE_GAP_M for LOSE_GAP_S loses (not during
# RESET_GRACE_S after a reset); points = drift time x speed inside the drift zones (the bike's drift_charge_mult is 1.5
# there); finishing with `target` points wins, without them loses; OVERTAKE_S ahead of him wins at once ("VƯỢT MẶT!").
# The rubber band (band_for) holds him within about 35 m unless the player resets. Leaving the course (more than
# OFF_COURSE_M off the line for OFF_COURSE_S) or riding the wrong way for WRONG_WAY_S resets to the last gate behind a
# FADE_S fade. Countdown (owner preview mix): counts at 0, 1, 2 s with a bike_rev each (PlayerBike.rev_blip forced; W
# revs too, rate-limited), Sói Xám answers 0.5 s after each count, GO at COUNTDOWN_S (RETRY_COUNTDOWN_S on a retry).
# While it runs: traffic parked, FreeRoam's riding hint shows the duel keys, [F] refused, the bike on DUEL_PROFILE with
# nitro on. Never touches the story state, the music (MissionDriftDuel does on the signals) or autoloads by name.
# ===========================================
class_name DriftDuel
extends Node3D

signal countdown_started(retry: bool)
signal music_cue
signal go
signal won(how: String)
signal lost(reason: String)
signal ended
signal gate_passed(index: int)
signal reset_to_gate(index: int)

const COUNTDOWN_S: float = 3.0
const RETRY_COUNTDOWN_S: float = 2.0
## Seconds after GO when the duel's track starts (negative = before GO); the coordinator's note: on GO.
const MUSIC_START_OFFSET: float = 0.0
const RIVAL_ANSWER_S: float = 0.5
const INTRO_S: float = 2.8
const RIVAL_LEAD_M: float = 8.0
const RIVAL_LAT: float = -2.6
const TAIL_GAP_M: float = 12.0
const NORMAL_GAP_M: float = 35.0
const LOSE_GAP_M: float = 40.0
const LOSE_GAP_S: float = 3.0
const OVERTAKE_M: float = 3.0
const OVERTAKE_S: float = 4.0
const POINTS_PER: float = 10.0            # points per (m/s x s) of drifting inside a zone
const TAIL_MULT: float = 2.0
const TARGET_POINTS: float = 1600.0
const ZONE_CHARGE_MULT: float = 1.5
const BAND_RATE: float = 4.0              # 1/s the rival's band factor follows band_for
const BAND_START_M: float = 22.0          # he starts waiting past this gap ...
const BAND_FULL_M: float = 38.0           # ... and nearly stops (BAND_MIN) here: a rider still moving never drops past 40 m
const BAND_MIN: float = 0.15
const OFF_COURSE_M: float = 13.0
const OFF_COURSE_S: float = 1.2
const WRONG_WAY_S: float = 1.5
const RESET_GRACE_S: float = 3.0
const FADE_S: float = 0.2                 # each way (0.4 s in all, under the 0.5 s of the spec)
const LOSE_PAUSE_S: float = 1.2
const FINISH_WAIT_S: float = 6.0
const TAIL_POPUP_EVERY: float = 4.0
const CONE_HIT_R: float = 0.6
const CONE_PENALTY: float = 25.0
const BIKE_FLOOR_OFFSET: float = 0.13
## 86 km/h (nitro: +8 m/s): a drift race on 8 m roads between buildings, about 50-55 s for the 1 km lap.
const DUEL_PROFILE: Dictionary = {"max_speed_ms": 24.0, "slipstream_max_ms": 26.4, "engine_accel": 13.5, "air_drag": 0.014}
## The ending: the deck middle southbound, Sói Xám facing the player, then down off the deck to the bank under it.
const ENDING_AT: Vector2 = Vector2(2121.9, 154.0)
const EXIT_PATH: Array[Vector2] = [Vector2(2127.3, 173.5), Vector2(2134.0, 181.0), Vector2(2143.0, 177.0), Vector2(2147.0, 165.0),
	Vector2(2145.0, 152.0)]
const ENDING_LINE_S: float = 2.6
const T_START: String = "Đua một vòng. Thắng thì tao nói hàng về đâu."
const T_END: String = "Hự... được, xuống gầm cầu tao nói."
const T_GO: String = "ĐI!"
const T_TAIL: String = "BÁM ĐUÔI!"
const T_OVERTAKE: String = "VƯỢT MẶT!"
const T_FAR: String = "Bị bỏ xa! %.1f"
const T_LOSE_GAP: String = "Sói Xám bỏ xa quá! Làm lại"
const T_LOSE_POINTS: String = "Chưa đủ điểm drift! Làm lại"
const T_WIN_POINTS: String = "THẮNG! Đủ điểm drift"
const T_OFF: String = "Ra khỏi đường đua! Về cổng trước"
const T_WRONG: String = "Đi ngược đường rồi!"
const T_GATE: String = "Cổng %d/%d"
const T_ZONE: String = "DRIFT! %s"
const T_CONE: String = "Đụng nón!"
const T_POINTS: String = "Điểm drift: %d / %d"
const T_GAP: String = "Cách Sói Xám %d m"
const T_AHEAD: String = "Dẫn trước Sói Xám %d m"
const T_RIDING: String = "[SPACE] drift trong vùng DRIFT · [SHIFT] nitro · [W]/[S] ga/phanh · [A]/[D] lái · [CTRL] cúi"
const T_NO_DISMOUNT: String = "Đang đua với Sói Xám, không xuống xe được!"

var roam: Node = null
var bike: PlayerBike
var player: Node3D
var traffic: RoamTraffic
var course: DriftCourse
var rival: DriftRival
var hud: CanvasLayer
var target: float = TARGET_POINTS
var use_intro: bool = true
var state: String = "idle"
var t: float = 0.0                        # time in the current state
var s_p: float = 0.0
var d_p: float = 0.0
var points: float = 0.0
var gate_i: int = 0
var losses: int = 0
var resets: int = 0
var tail_t: float = 0.0                   # seconds spent tailing (tests, tuning)
var far_t: float = 0.0
var ahead_t: float = 0.0
var off_t: float = 0.0
var wrong_t: float = 0.0
var grace_t: float = 0.0
var finish_wait: float = -1.0
var win_how: String = ""
var lose_reason: String = ""
var retry_count: bool = false
var race_t: float = 0.0
var min_gap: float = INF
var max_gap: float = -INF
var drift_in_zone_t: float = 0.0
var knocked_cones: int = 0
var countdown_len: float = COUNTDOWN_S
## Tests: 1 = count the bike as drifting, 0 = as not drifting, -1 = read bike.is_drifting.
var force_drift: int = -1
var _counts_done: int = 0
var _answers_done: int = 0
var _music_sent: bool = false
var _zone: int = -1
var _tail_pop_t: float = 0.0
var _was_tail: bool = false
var _combo: float = 0.0
var _combo_t: float = 0.0
var _fade: float = 0.0                    # 0 clear .. 1 black
var _fade_dir: float = 0.0
var _fade_then: Callable = Callable()
var _hooks: bool = false
var _bike_profile: Dictionary = {}
var _bike_nitro_prev: bool = false
var _traffic_off: bool = false
var _props: Node3D
var _cone_mm: MultiMeshInstance3D
var _band_mm: MultiMeshInstance3D
var _cone_xf: Array[Transform3D] = []
var _cone_state: PackedFloat32Array = PackedFloat32Array()   # -1 standing, >= 0 seconds since knocked (flying), 99 gone
var _cone_vel: Array[Vector3] = []
var _ray_q: PhysicsRayQueryParameters3D
var _ending_line_t: float = -1.0
# HUD widgets
var _panel: Control
var _gap_label: Label
var _points_label: Label
var _gate_label: Label
var _far_label: Label
var _popup: Label
var _popup_left: float = 0.0
var _combo_label: Label
var _sub_label: Label
var _fade_rect: ColorRect


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
	course = opts.get("course", null)
	if course == null:
		course = DriftCourse.rach_ham()
	target = float(opts.get("target", TARGET_POINTS))
	use_intro = bool(opts.get("intro", true))
	_ray_q = PhysicsRayQueryParameters3D.new()
	var excl: Array[RID] = []
	if bike:
		excl.append(bike.get_rid())
	if player is CollisionObject3D:
		excl.append((player as CollisionObject3D).get_rid())
	_ray_q.exclude = excl
	rival = DriftRival.new()
	add_child(rival)
	if bike:
		rival.ray_exclude.append(bike.get_rid())
	rival.setup(course, {"seed": int(opts.get("seed", 3131))})
	_build_props()
	_build_hud()


# ---------------------------------------------------------------------------
# FLOW
# ---------------------------------------------------------------------------
func start() -> void:
	if bike == null:
		push_warning("DriftDuel.start: no bike")
		return
	_set_hooks(true)
	_reset_race()
	if use_intro:
		_enter("intro")
		rival.stand_beside(true)
		rival.say(T_START, INTRO_S)
		_subtitle("Sói Xám: " + T_START, INTRO_S)
		bike.set_staged(true)
		_fade = 1.0
		_fade_to(0.0)
	else:
		_begin_countdown(false)


## Quick retry by hand (also what a loss does by itself): the start grid, a short countdown.
func retry() -> void:
	_reset_race()
	_begin_countdown(true)


func stop() -> void:
	_enter("idle")
	_set_hooks(false)
	if bike and is_instance_valid(bike):
		if bike.staged:
			bike.set_staged(false)
		bike.drift_charge_mult = 1.0
	if hud:
		hud.visible = false


func gap() -> float:
	return rival.s - s_p if rival else 0.0


## The rubber band: his speed factor for a gap (m, his progress minus the player's).
static func band_for(g: float, grace: bool) -> float:
	if grace:
		return 0.45
	if g < 0.0:
		return 1.2
	if g < 4.0:
		return 1.06
	if g < TAIL_GAP_M:
		return 1.03
	if g <= BAND_START_M:
		return 1.0
	return lerpf(1.0, BAND_MIN, clampf((g - BAND_START_M) / (BAND_FULL_M - BAND_START_M), 0.0, 1.0))


func _enter(s: String) -> void:
	state = s
	t = 0.0


func _reset_race() -> void:
	points = 0.0
	gate_i = 0
	far_t = 0.0
	ahead_t = 0.0
	off_t = 0.0
	wrong_t = 0.0
	grace_t = 0.0
	finish_wait = -1.0
	race_t = 0.0
	_zone = -1
	_combo = 0.0
	_was_tail = false
	min_gap = INF
	max_gap = -INF
	_reset_cones()
	_place_player(0.0, 0.0)
	s_p = 0.0
	d_p = 0.0
	rival.place_at(RIVAL_LEAD_M, RIVAL_LAT)
	bike.drift_charge = 0.0
	bike.drift_charge_mult = 1.0
	_update_hud()


func _begin_countdown(is_retry: bool) -> void:
	retry_count = is_retry
	countdown_len = RETRY_COUNTDOWN_S if is_retry else COUNTDOWN_S
	_counts_done = 0
	_answers_done = 0
	_music_sent = false
	rival.stand_beside(false)
	bike.set_staged(true)
	_enter("countdown")
	countdown_started.emit(is_retry)


## The count shown at a countdown time (3, 2, 1 for the full countdown; 2, 1 on a retry).
func count_label(i: int) -> String:
	return str(int(round(countdown_len)) - i)


func _physics_process(delta: float) -> void:
	if bike == null or not is_instance_valid(bike):
		return
	t += delta
	_tick_fade(delta)
	_tick_popup(delta)
	_tick_cones(delta)
	match state:
		"intro":
			rival.tick(delta, RIVAL_LEAD_M)
			if t >= INTRO_S:
				_begin_countdown(false)
		"countdown":
			_tick_countdown(delta)
		"racing":
			_tick_race(delta)
		"lost":
			_follow_player()
			rival.tick(delta, gap())
			if t >= LOSE_PAUSE_S and _fade_dir == 0.0 and _fade < 0.5:
				_fade_to(1.0, func() -> void:
					retry()
					_fade_to(0.0))
		"won":
			_follow_player()
			rival.tick(delta, gap())
			if t >= 1.0 and _fade_dir == 0.0 and _fade < 0.5:
				_fade_to(1.0, _begin_ending)
		"ending":
			_tick_ending(delta)
		_:
			pass


func _tick_countdown(delta: float) -> void:
	rival.tick(delta, RIVAL_LEAD_M)
	var n: int = int(round(countdown_len))
	while _counts_done < n and t >= float(_counts_done):
		_popup_show(count_label(_counts_done), Color("#FFE14D"), 0.8)
		bike.rev_blip(true)
		rival.flash_headlight(true)
		_counts_done += 1
	if t >= float(_counts_done - 1) + 0.25:
		rival.flash_headlight(false)
	while _answers_done < n and t >= float(_answers_done) + RIVAL_ANSWER_S:
		rival.rev_answer()
		_answers_done += 1
	if not _music_sent and MUSIC_START_OFFSET < 0.0 and t >= countdown_len + MUSIC_START_OFFSET:
		_music_sent = true
		music_cue.emit()
	if t >= countdown_len:
		bike.set_staged(false)
		rival.start_race()
		rival.flash_headlight(false)
		_popup_show(T_GO, Color("#7CFF6B"), 0.9)
		_enter("racing")
		go.emit()
		if not _music_sent and MUSIC_START_OFFSET <= 0.0:
			_music_sent = true
			music_cue.emit()


func _tick_race(delta: float) -> void:
	race_t += delta
	if not _music_sent and race_t >= MUSIC_START_OFFSET:
		_music_sent = true
		music_cue.emit()
	_follow_player()
	var g: float = gap()
	if grace_t > 0.0:
		grace_t -= delta
	rival.band = lerpf(rival.band, band_for(g, grace_t > 0.0), minf(1.0, delta * BAND_RATE))
	rival.fight = g < TAIL_GAP_M
	rival.tick(delta, g)
	if rival.s >= course.length and not rival.finished:
		rival.finished = true
		finish_wait = FINISH_WAIT_S
	min_gap = minf(min_gap, g)
	max_gap = maxf(max_gap, g)
	# gates
	while gate_i < course.gates.size() and s_p >= course.gates[gate_i]:
		gate_i += 1
		gate_passed.emit(gate_i - 1)
		_popup_show(T_GATE % [gate_i, course.gates.size() + 1], Color("#BFE8FF"), 0.7)
	# drift points inside the zones
	var z: int = course.zone_at(course.wrap_s(s_p)) if s_p < course.length else -1
	bike.drift_charge_mult = ZONE_CHARGE_MULT if z >= 0 else 1.0
	if z != _zone:
		_zone = z
		if z >= 0:
			_popup_show(T_ZONE % String(course.zones[z][2]), Color("#FF9F1C"), 0.8)
	var tail: bool = g >= 0.0 and g <= TAIL_GAP_M and not rival.finished
	if tail:
		tail_t += delta
	if tail and not _was_tail and _tail_pop_t <= 0.0:
		_popup_show(T_TAIL, Color("#7CFF6B"), 0.9)
		_tail_pop_t = TAIL_POPUP_EVERY
	_was_tail = tail
	_tail_pop_t -= delta
	var drifting: bool = bike.is_drifting if force_drift < 0 else force_drift == 1
	if z >= 0 and drifting:
		var add: float = absf(bike.current_speed_ms) * delta * POINTS_PER * (TAIL_MULT if tail else 1.0)
		points += add
		drift_in_zone_t += delta
		_combo += add
		_combo_t = 0.6
	elif _combo_t > 0.0:
		_combo_t -= delta
		if _combo_t <= 0.0:
			_combo = 0.0
	# off the course / wrong way
	var along: float = Vector2(bike.velocity.x, bike.velocity.z).dot(course.tangent(s_p))
	off_t = off_t + delta if absf(d_p) > OFF_COURSE_M else 0.0
	wrong_t = wrong_t + delta if along < -3.0 else 0.0
	if off_t >= OFF_COURSE_S or wrong_t >= WRONG_WAY_S:
		_reset_to_gate(T_WRONG if wrong_t >= WRONG_WAY_S else T_OFF)
		return
	# win / lose
	if s_p < -OVERTAKE_M or g >= -OVERTAKE_M or rival.finished:
		ahead_t = 0.0
	else:
		ahead_t += delta
	if ahead_t >= OVERTAKE_S:
		_win("overtake")
		return
	if s_p >= course.length and gate_i >= course.gates.size():
		if points >= target:
			_win("points")
		else:
			_lose("points")
		return
	if rival.finished:
		finish_wait -= delta
		if finish_wait <= 0.0:
			_lose("gap")
			return
	elif g > LOSE_GAP_M and grace_t <= 0.0:
		far_t += delta
		if far_t >= LOSE_GAP_S:
			_lose("gap")
			return
	else:
		far_t = maxf(0.0, far_t - delta * 2.0)
	_check_cones()
	_update_hud()


## The player's progress and lateral offset on the lap (windowed search; a full search when far off).
func _follow_player() -> void:
	var bp := Vector2(bike.global_position.x, bike.global_position.z)
	var pr: Vector2 = course.project_near(bp, s_p)
	if absf(pr.y) > 30.0:
		var any: Vector2 = course.project_any(bp)
		if absf(any.y) + 5.0 < absf(pr.y) and absf(any.x - course.wrap_s(s_p)) < 120.0:
			pr = Vector2(any.x + (s_p - course.wrap_s(s_p)), any.y)
	s_p = pr.x
	d_p = pr.y


func _win(how: String) -> void:
	win_how = how
	_enter("won")
	bike.drift_charge_mult = 1.0
	_popup_show(T_OVERTAKE if how == "overtake" else T_WIN_POINTS, Color("#7CFF6B"), 1.6)
	won.emit(how)


func _lose(reason: String) -> void:
	lose_reason = reason
	losses += 1
	_enter("lost")
	bike.drift_charge_mult = 1.0
	_popup_show(T_LOSE_POINTS if reason == "points" else T_LOSE_GAP, Color("#FF5C7A"), LOSE_PAUSE_S + 0.3)
	lost.emit(reason)


## Off the course or the wrong way: back to the last gate (the start before the first) behind a quick fade, stopped,
## with RESET_GRACE_S of grace on the gap rule (he waits).
func _reset_to_gate(msg: String) -> void:
	resets += 1
	off_t = 0.0
	wrong_t = 0.0
	var g: int = gate_i - 1
	_popup_show(msg, Color("#FF9F1C"), 1.0)
	_fade_to(1.0, func() -> void:
		var s0: float = course.gates[g] if g >= 0 else 0.0
		_place_player(s0, 0.0)
		s_p = s0
		d_p = 0.0
		grace_t = RESET_GRACE_S
		far_t = 0.0
		reset_to_gate.emit(g)
		_fade_to(0.0))


func _begin_ending() -> void:
	_enter("ending")
	var es: float = course.project_any(ENDING_AT).x
	_place_player(es, 0.0)
	bike.is_controls_locked = true
	rival.place_at(es + 9.0, -1.0)
	rival.yaw = course.yaw_at(es) + PI
	rival._place()
	rival.say(T_END, ENDING_LINE_S + 0.5)
	_subtitle("Sói Xám: " + T_END, ENDING_LINE_S + 0.5)
	_ending_line_t = ENDING_LINE_S
	_fade_to(0.0)


func _tick_ending(delta: float) -> void:
	rival.tick(delta, 0.0)
	if _ending_line_t > 0.0:
		_ending_line_t -= delta
		if _ending_line_t <= 0.0:
			rival.ride_exit(PackedVector2Array(EXIT_PATH), 9.0)
		return
	if (rival.exit_done() or t > ENDING_LINE_S + 7.0) and _fade_dir == 0.0 and _fade < 0.5:
		_fade_to(1.0, func() -> void:
			_enter("done")
			_set_hooks(false)
			ended.emit())


# ---------------------------------------------------------------------------
# PLAYER PLACEMENT / HOOKS
# ---------------------------------------------------------------------------
## The bike on the line at progress s, lateral d, facing along it, stopped (mounting the player when on foot).
func _place_player(s: float, d: float) -> void:
	var p: Vector2 = course.world(s, d)
	var y: Variant = floor_at(Vector3(p.x, 0.0, p.y), 6.0, 6.0)
	var fy: float = float(y) if y is float else 0.05
	var yaw: float = course.yaw_at(s)
	var origin := Vector3(p.x, fy - BIKE_FLOOR_OFFSET, p.y)
	if roam and is_instance_valid(roam) and not bool(roam.get("mounted")):
		var spot: Vector3 = origin + Vector3(0.0, BIKE_FLOOR_OFFSET, 0.0)
		if bool(roam.get("bike_parked")):
			bike.global_position = origin
			bike.rotation = Vector3(0.0, yaw, 0.0)
		if player and player.has_method("teleport"):
			player.call("teleport", spot, yaw)
		roam.call("mount_bike")
	bike.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	bike.velocity = Vector3.ZERO
	bike.current_speed_ms = 0.0
	bike.respawn_invulnerable_timer = 0.0


func floor_at(p: Vector3, up: float = 3.0, down: float = 6.0) -> Variant:
	if not is_inside_tree():
		return null
	_ray_q.from = p + Vector3(0.0, up, 0.0)
	_ray_q.to = p - Vector3(0.0, down, 0.0)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray_q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.5:
		return null
	var col: Object = hit["collider"]
	if col is Node and (col as Node).is_in_group("traffic_obstacle"):
		return null
	return (hit["position"] as Vector3).y


## FreeRoam hint + [F] refusal, the bike's duel profile and nitro, the traffic parked; all given back when off.
func _set_hooks(on: bool) -> void:
	if on == _hooks:
		return
	_hooks = on
	if bike and is_instance_valid(bike):
		if on:
			_bike_profile = bike.speed_profile()
			bike.apply_speed_profile(DUEL_PROFILE)
			_bike_nitro_prev = bike.nitro_enabled
			bike.set_nitro_enabled(true)
		else:
			if not _bike_profile.is_empty():
				bike.apply_speed_profile(_bike_profile)
				_bike_profile = {}
			bike.set_nitro_enabled(_bike_nitro_prev)
			bike.drift_charge_mult = 1.0
			if bike.staged:
				bike.set_staged(false)
			bike.is_controls_locked = false
	if roam and is_instance_valid(roam):
		if on:
			roam.set("riding_hint", T_RIDING)
			roam.set("dismount_refusal", T_NO_DISMOUNT)
		else:
			if String(roam.get("riding_hint")) == T_RIDING:
				roam.set("riding_hint", "")
			if String(roam.get("dismount_refusal")) == T_NO_DISMOUNT:
				roam.set("dismount_refusal", "")
	_traffic(not on)
	if hud:
		hud.visible = on


## Traffic parked for the duel (the course is closed), running again after.
func _traffic(run: bool) -> void:
	if traffic == null or not is_instance_valid(traffic):
		return
	if not run and not _traffic_off:
		_traffic_off = true
		for v: Variant in traffic.vehicles:
			var c: RoamTraffic.Vehicle = v
			if c.active:
				traffic.call("_park", c)
		traffic.set_physics_process(false)
	elif run and _traffic_off:
		_traffic_off = false
		traffic.set_physics_process(true)


func _exit_tree() -> void:
	_set_hooks(false)


# ---------------------------------------------------------------------------
# FADE / POPUPS / HUD
# ---------------------------------------------------------------------------
func _fade_to(v: float, then: Callable = Callable()) -> void:
	_fade_dir = 1.0 if v > _fade else -1.0
	_fade_then = then
	if is_equal_approx(v, _fade):
		_fade_dir = 0.0
		if then.is_valid():
			then.call()


func fading() -> bool:
	return _fade_dir != 0.0


func _tick_fade(delta: float) -> void:
	if _fade_dir != 0.0:
		_fade = clampf(_fade + _fade_dir * delta / FADE_S, 0.0, 1.0)
		if (_fade_dir > 0.0 and _fade >= 1.0) or (_fade_dir < 0.0 and _fade <= 0.0):
			_fade_dir = 0.0
			var cb: Callable = _fade_then
			_fade_then = Callable()
			if cb.is_valid():
				cb.call()
	if _fade_rect:
		_fade_rect.color.a = _fade
		_fade_rect.visible = _fade > 0.001


func _popup_show(text: String, col: Color, secs: float) -> void:
	popup_text = text
	popups += 1
	if _popup:
		_popup.text = text
		_popup.add_theme_color_override("font_color", col)
		_popup.visible = true
	_popup_left = secs


var popup_text: String = ""
var popups: int = 0
var subtitle_text: String = ""


func _subtitle(text: String, secs: float) -> void:
	subtitle_text = text
	if _sub_label:
		_sub_label.text = text
		_sub_label.visible = true
	_sub_t = secs


var _sub_t: float = 0.0


func _tick_popup(delta: float) -> void:
	if _popup_left > 0.0:
		_popup_left -= delta
		if _popup_left <= 0.0 and _popup:
			_popup.visible = false
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0 and _sub_label:
			_sub_label.visible = false


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "DriftHUD"
	hud.layer = 3
	add_child(hud)
	_panel = GapPanel.new()
	_panel.name = "GapPanel"
	_panel.set("duel", self)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -240.0
	_panel.offset_right = 240.0
	_panel.offset_top = 16.0
	_panel.offset_bottom = 112.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_panel)
	_gap_label = _label(_panel, 18, Color("#F4F1FF"), Vector2(14.0, 6.0), Vector2(300.0, 24.0), HORIZONTAL_ALIGNMENT_LEFT)
	_gate_label = _label(_panel, 15, Color("#BFE8FF"), Vector2(330.0, 8.0), Vector2(136.0, 22.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_points_label = _label(_panel, 18, Color("#FFE14D"), Vector2(14.0, 64.0), Vector2(452.0, 24.0), HORIZONTAL_ALIGNMENT_LEFT)
	_far_label = Label.new()
	_style(_far_label, 26, Color("#FF5C7A"))
	_far_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_far_label.offset_left = -240.0
	_far_label.offset_right = 240.0
	_far_label.offset_top = 118.0
	_far_label.offset_bottom = 150.0
	_far_label.visible = false
	hud.add_child(_far_label)
	_popup = Label.new()
	_style(_popup, 52, Color.WHITE)
	_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_popup.offset_left = -420.0
	_popup.offset_right = 420.0
	_popup.offset_top = -200.0
	_popup.offset_bottom = -130.0
	_popup.visible = false
	hud.add_child(_popup)
	_combo_label = Label.new()
	_style(_combo_label, 30, Color("#FF9F1C"))
	_combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_combo_label.offset_left = -200.0
	_combo_label.offset_right = 200.0
	_combo_label.offset_top = 70.0
	_combo_label.offset_bottom = 110.0
	_combo_label.visible = false
	hud.add_child(_combo_label)
	_sub_label = Label.new()
	_style(_sub_label, 22, Color("#F4F1FF"))
	_sub_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_label.offset_left = -460.0
	_sub_label.offset_right = 460.0
	_sub_label.offset_top = -260.0
	_sub_label.offset_bottom = -224.0
	_sub_label.visible = false
	hud.add_child(_sub_label)
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "DriftFade"
	fade_layer.layer = 12
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	fade_layer.add_child(_fade_rect)
	hud.visible = false


func _label(parent: Control, size: int, col: Color, pos: Vector2, sz: Vector2, align: int) -> Label:
	var l := Label.new()
	_style(l, size, col)
	l.horizontal_alignment = align
	l.position = pos
	l.size = sz
	parent.add_child(l)
	return l


func _style(l: Label, size: int, col: Color) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.1, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


var _hud_g: int = -9999
var _hud_p: int = -1
var _hud_gate: int = -1
var _hud_far: int = -1
var _hud_combo: int = -1
var _hud_tail: bool = false


## Texts rebuilt only when their number changes (no string building per frame).
func _update_hud() -> void:
	if _gap_label == null:
		return
	var g: int = int(round(gap()))
	if g != _hud_g:
		_hud_g = g
		_gap_label.text = T_AHEAD % -g if g < 0 else T_GAP % g
		_panel.queue_redraw()
	var p: int = int(points)
	if p != _hud_p or _was_tail != _hud_tail:
		_hud_p = p
		_hud_tail = _was_tail
		_points_label.text = T_POINTS % [p, int(target)] + ("   x2 BÁM ĐUÔI" if _was_tail else "")
		_panel.queue_redraw()
	if gate_i != _hud_gate:
		_hud_gate = gate_i
		_gate_label.text = T_GATE % [gate_i, course.gates.size() + 1]
	var f: int = int(ceil((LOSE_GAP_S - far_t) * 10.0)) if far_t > 0.0 and state == "racing" else -1
	if f != _hud_far:
		_hud_far = f
		_far_label.visible = f >= 0
		if f >= 0:
			_far_label.text = T_FAR % (float(f) / 10.0)
	var c: int = int(_combo) if _combo_t > 0.0 else -1
	if c != _hud_combo:
		_hud_combo = c
		_combo_label.visible = c > 0
		if c > 0:
			_combo_label.text = "+%d" % c


class GapPanel:
	extends Control
	var duel: DriftDuel

	func _draw() -> void:
		if duel == null:
			return
		var sz: Vector2 = size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.02, 0.12, 0.78))
		draw_rect(Rect2(Vector2.ZERO, sz), Color("#FF4FA3"), false, 2.0)
		var bar := Rect2(14.0, 36.0, sz.x - 28.0, 20.0)
		var scale_m: float = 45.0
		var x12: float = bar.position.x + bar.size.x * DriftDuel.TAIL_GAP_M / scale_m
		var x35: float = bar.position.x + bar.size.x * DriftDuel.NORMAL_GAP_M / scale_m
		var x40: float = bar.position.x + bar.size.x * DriftDuel.LOSE_GAP_M / scale_m
		draw_rect(Rect2(bar.position, Vector2(x12 - bar.position.x, bar.size.y)), Color(0.25, 0.85, 0.35, 0.75))
		draw_rect(Rect2(Vector2(x12, bar.position.y), Vector2(x35 - x12, bar.size.y)), Color(0.85, 0.85, 0.9, 0.35))
		draw_rect(Rect2(Vector2(x35, bar.position.y), Vector2(x40 - x35, bar.size.y)), Color(1.0, 0.8, 0.2, 0.6))
		draw_rect(Rect2(Vector2(x40, bar.position.y), Vector2(bar.end.x - x40, bar.size.y)), Color(1.0, 0.25, 0.3, 0.7))
		var g: float = clampf(duel.gap(), 0.0, scale_m)
		var mx: float = bar.position.x + bar.size.x * g / scale_m
		draw_rect(Rect2(Vector2(mx - 3.0, bar.position.y - 4.0), Vector2(6.0, bar.size.y + 8.0)), Color.WHITE)
		draw_rect(bar, Color(1.0, 1.0, 1.0, 0.4), false, 1.0)


# ---------------------------------------------------------------------------
# PROPS: cones (MultiMesh, knocked analytically), barrier rows (colliders + MultiMesh), chevron boards, gate poles
# ---------------------------------------------------------------------------
func _build_props() -> void:
	_props = Node3D.new()
	_props.name = "DriftProps"
	add_child(_props)
	_props.top_level = true
	_props.global_transform = Transform3D.IDENTITY
	# cones
	var n: int = course.cones.size()
	_cone_xf.clear()
	_cone_vel.clear()
	_cone_state.resize(n)
	for i: int in n:
		var c: Vector2 = course.cones[i]
		var y: Variant = floor_at(Vector3(c.x, 0.0, c.y), 6.0, 6.0)
		_cone_xf.append(Transform3D(Basis(), Vector3(c.x, (float(y) if y is float else 0.05), c.y)))
		_cone_vel.append(Vector3.ZERO)
		_cone_state[i] = -1.0
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.17
	cone.height = 0.55
	cone.radial_segments = 10
	cone.material = _emissive(Color("#FF6A13"), 0.6)
	_cone_mm = _multimesh("Cones", cone, n, Vector3(0.0, 0.275, 0.0))
	var band := CylinderMesh.new()
	band.top_radius = 0.105
	band.bottom_radius = 0.125
	band.height = 0.09
	band.radial_segments = 10
	band.material = _emissive(Color("#F4F6F8"), 1.2)
	_band_mm = _multimesh("ConeBands", band, n, Vector3(0.0, 0.3, 0.0))
	_reset_cones()
	# barrier rows: one collider per row, red / white segments
	var segs: Array[Transform3D] = []
	var cols: Array[Color] = []
	for b: Array in course.barriers:
		var a: Vector2 = b[0]
		var e: Vector2 = b[1]
		var mid: Vector2 = (a + e) * 0.5
		var len: float = a.distance_to(e)
		var dir: Vector2 = (e - a) / maxf(len, 0.01)
		var yaw: float = atan2(-dir.y, dir.x)
		var my: Variant = floor_at(Vector3(mid.x, 0.0, mid.y), 6.0, 6.0)
		var fy: float = float(my) if my is float else 0.05
		var sb := StaticBody3D.new()
		sb.name = "Barrier"
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(len, 0.9, 0.6)
		cs.shape = bs
		cs.position = Vector3(0.0, 0.45, 0.0)
		sb.add_child(cs)
		_props.add_child(sb)
		sb.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, fy, mid.y))
		var k: int = maxi(1, int(round(len / 2.0)))
		for j: int in k:
			var q: Vector2 = a.lerp(e, (float(j) + 0.5) / float(k))
			segs.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(q.x, fy, q.y)))
			cols.append(Color("#E8282B") if j % 2 == 0 else Color("#F4F6F8"))
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.85, 0.5)
	var bmat := StandardMaterial3D.new()
	bmat.vertex_color_use_as_albedo = true
	bmat.emission_enabled = true
	bmat.emission = Color(0.25, 0.25, 0.25)
	bmat.set_meta("vice_done", true)
	bm.material = bmat
	var bmi: MultiMeshInstance3D = _multimesh("Barriers", bm, segs.size(), Vector3(0.0, 0.425, 0.0), true)
	for j2: int in segs.size():
		bmi.multimesh.set_instance_transform(j2, segs[j2].translated_local(Vector3(0.0, 0.425, 0.0)))
		bmi.multimesh.set_instance_color(j2, cols[j2])
	# chevron boards on the islands and the closed road
	for ch: Array in course.chevrons:
		_chevron(ch[0], float(ch[1]))
	# gate poles: a pair at each gate, an orange glowing top
	var poles: Array[Transform3D] = []
	for gi: int in course.gates.size():
		var gs: float = course.gates[gi]
		for side: float in [-5.2, 5.2]:
			var pp: Vector2 = course.world(gs, side)
			var py: Variant = floor_at(Vector3(pp.x, 0.0, pp.y), 6.0, 6.0)
			poles.append(Transform3D(Basis(), Vector3(pp.x, (float(py) if py is float else 0.05) + 1.1, pp.y)))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.06
	pole.height = 2.2
	pole.radial_segments = 6
	pole.material = _emissive(Color("#FF9F1C"), 1.4)
	var pmi: MultiMeshInstance3D = _multimesh("GatePoles", pole, poles.size(), Vector3.ZERO)
	for pi: int in poles.size():
		pmi.multimesh.set_instance_transform(pi, poles[pi])


func _multimesh(nm: String, mesh: Mesh, count: int, _lift: Vector3, colors: bool = false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props.add_child(mi)
	return mi


static func _emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	m.set_meta("vice_done", true)
	return m


## A yellow-on-black chevron board on two legs, its face toward riders travelling at `travel_yaw`.
func _chevron(at: Vector2, travel_yaw: float) -> void:
	var root := Node3D.new()
	root.name = "Chevron"
	_props.add_child(root)
	var y: Variant = floor_at(Vector3(at.x, 0.0, at.y), 6.0, 6.0)
	root.global_transform = Transform3D(Basis(Vector3.UP, travel_yaw), Vector3(at.x, (float(y) if y is float else 0.05), at.y))
	var black := _emissive(Color("#15151A"), 0.0)
	var yellow := _emissive(Color("#FFD21F"), 1.6)
	CineFX._box(root, "Board", Vector3(1.8, 0.7, 0.05), Vector3(0.0, 1.05, 0.0), black)
	for sx: float in [-0.75, 0.75]:
		CineFX._box(root, "Leg", Vector3(0.06, 0.75, 0.06), Vector3(sx, 0.38, 0.0), black)
	for k: int in 3:
		var x: float = -0.5 + 0.5 * float(k)
		CineFX._box(root, "ArrowA", Vector3(0.08, 0.36, 0.02), Vector3(x - 0.06, 1.13, 0.04), yellow, Vector3(0.0, 0.0, 0.7))
		CineFX._box(root, "ArrowB", Vector3(0.08, 0.36, 0.02), Vector3(x - 0.06, 0.97, 0.04), yellow, Vector3(0.0, 0.0, -0.7))


func _reset_cones() -> void:
	knocked_cones = 0
	for i: int in _cone_state.size():
		_cone_state[i] = -1.0
		_cone_vel[i] = Vector3.ZERO
		_set_cone(i, _cone_xf[i])


func _set_cone(i: int, xf: Transform3D) -> void:
	if _cone_mm:
		_cone_mm.multimesh.set_instance_transform(i, xf.translated_local(Vector3(0.0, 0.275, 0.0)))
		_band_mm.multimesh.set_instance_transform(i, xf.translated_local(Vector3(0.0, 0.3, 0.0)))


## A standing cone the bike touches flies off (comic tumble), costs CONE_PENALTY points.
func _check_cones() -> void:
	var bp: Vector3 = bike.global_position
	var r2: float = CONE_HIT_R * CONE_HIT_R
	for i: int in _cone_state.size():
		if _cone_state[i] >= 0.0:
			continue
		var o: Vector3 = _cone_xf[i].origin
		var dx: float = o.x - bp.x
		var dz: float = o.z - bp.z
		if dx * dx + dz * dz > r2:
			continue
		_cone_state[i] = 0.0
		knocked_cones += 1
		var push := Vector3(bike.velocity.x, 0.0, bike.velocity.z) * 0.6
		_cone_vel[i] = push + Vector3(dx, 0.0, dz).normalized() * 2.0 + Vector3(0.0, 4.5, 0.0)
		points = maxf(0.0, points - CONE_PENALTY)
		_popup_show(T_CONE, Color("#FF9F1C"), 0.6)


func _tick_cones(delta: float) -> void:
	for i: int in _cone_state.size():
		var st: float = _cone_state[i]
		if st < 0.0 or st >= 99.0:
			continue
		st += delta
		_cone_state[i] = st
		var o: Vector3 = _cone_xf[i].origin + _cone_vel[i] * st + Vector3(0.0, -9.0 * st * st, 0.0)
		if st >= 1.0:
			_cone_state[i] = 99.0
			_set_cone(i, Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), _cone_xf[i].origin))
			continue
		_set_cone(i, Transform3D(Basis(Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, float(i)), st * 12.0), Vector3(o.x, maxf(o.y, _cone_xf[i].origin.y), o.z)))
