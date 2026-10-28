# File: res://scripts/combat/bike/DriftDuel.gd
# Encounter node of the Day 2 race with Sói Xám, "đua + đánh" (Wave 2 Day 2 rework, plan 2026-10-29-w2-day2.md; it
# replaces the 2026-10-27 drift-points duel): DriftCourse "Rạch Hầm GP" in FreeRoam, from the grid on the Rạch Hầm bridge,
# 2 laps of the real Nguyễn Văn Tăng / Đỗ Thế Diện loop and back to the finish line on the bridge. First over the line
# wins. Sói Xám (DriftRival) rides aggressively: he blocks, kicks and fires nitro; the player kicks back (Q / E,
# PlayerBikeCombat): 3 kicks make him wobble and lose speed for 2 s. Drift corners charge nitro (x CORNER_CHARGE_MULT in a
# corner, + CORNER_BONUS for a drifted corner). A loss (he crosses the line first, or his kicks knock the player off)
# retries quickly: on the grid, or on the lap 2 grid once the player reached lap 2; each loss (up to MERCY_MAX) eases his
# pace by mercy_step, so a struggling player gets there within a few retries.
#
# ===== API (MissionDriftDuel; tests) =====
#   var duel := DriftDuel.new(); roam.add_child(duel)
#   duel.setup({"roam": roam,          # FreeRoam (bike, player, traffic read from it); or "bike" [+ "player", "traffic"]
#       "course": null,                 # default DriftCourse.rach_ham()
#       "intro": true,                  # Sói Xám beside his bike with his line before the first countdown
#       "props": true,                  # the arches, arrows, the pack and the fireworks (DriftRaceProps)
#       "seed": 3131})
#   duel.start()                        # mounts and places the player, the intro, then the countdown
#   signals: countdown_started(retry), music_cue (GO + MUSIC_START_OFFSET), go, won(how) ("race"), lost(reason) ("beaten" |
#            "knocked"; the duel retries by itself after LOSE_PAUSE_S + a FADE_S fade), ended (after the ending: his line,
#            he rides down off the bridge, the fade), gate_passed(i), reset_to_gate(i), lap_started(lap)
#   duel.retry() (quick retry by hand), duel.stop() (end without a result: hooks, the bike's profile / nitro state and the
#   traffic given back)
#   state: "idle" | "intro" | "countdown" | "racing" | "lost" | "won" | "ending" | "done"
#   s_p / d_p (the player on the path), gap() (his progress minus the player's), lap (0 grid run, 1..2 laps, 3 the run
#   home), lap2_reached (the retry checkpoint), losses, resets, corner_bonuses, combat (PlayerBikeCombat), rival, props
# While it runs: traffic parked, FreeRoam's riding hint shows the race keys, [F] refused, the bike on DUEL_PROFILE with
# nitro on, the kicks on (PlayerBikeCombat with Sói Xám its only target). Never touches the story state, the music
# (MissionDriftDuel does on the signals) or autoloads by name. Every tuned number goes through Difficulty.pick.
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
signal lap_started(lap: int)

const COUNTDOWN_S: float = 3.0
const RETRY_COUNTDOWN_S: float = 2.0
## Seconds after GO when the race's track starts (negative = before GO); owner-approved: on GO.
const MUSIC_START_OFFSET: float = 0.0
const RIVAL_ANSWER_S: float = 0.5
const INTRO_S: float = 2.8
const GRID_LAT: float = 1.4               # the player on the right of the line, Sói Xám on the left ...
const RIVAL_GRID_AHEAD: float = 2.5       # ... and this much ahead (he took pole)
const LAP2_GRID_AFTER: float = 22.0       # the lap 2 retry grid: this far past the lap line (on the straight)
const OFF_COURSE_M: float = 3.0           # beyond the road's half width ...
const OFF_COURSE_S: float = 1.2           # ... this long: back to the last gate
const WRONG_WAY_S: float = 1.5
const RESET_GRACE_S: float = 3.0          # he eases off after a reset
const FADE_S: float = 0.2                 # each way
const LOSE_PAUSE_S: float = 1.6
const WIN_HOLD_S: float = 2.4             # the finish (orbit, fireworks) before the fade to the ending
const FINISH_ORBIT_S: float = 0.9
const CORNER_CHARGE_MULT: float = 1.5
const CORNER_DRIFT_MIN: float = 0.35      # seconds of drifting in a corner for the bonus
const CONTACT_LAT: float = 0.95
const CONTACT_ALONG: float = 1.7
const CONTACT_CD: float = 0.8
const TAIL_GAP_M: float = 12.0            # he races harder (fight profile) when the player is this close
const BAND_START_M: float = 20.0          # he eases off past this lead ...
const BAND_FULL_M: float = 60.0           # ... down to band_far here
const MERCY_MAX: int = 3                  # losses that ease him (mercy_step of pace each)
const CRASH_DMG_MIN: float = 8.0          # a wall at 6 m/s ...
const CRASH_DMG_MAX: float = 18.0         # ... and at 26 m/s (Dễ x0.6)
const BIKE_FLOOR_OFFSET: float = 0.13
## The race profile (the chase's 100 km/h, 110 in a slipstream; nitro +8 m/s on top).
const DUEL_PROFILE: Dictionary = {"max_speed_ms": 27.8, "slipstream_max_ms": 30.6, "engine_accel": 14.5, "air_drag": 0.0125}
## The ending: the deck middle southbound, Sói Xám facing the player, then down off the deck to the bank under it.
const ENDING_AT: Vector2 = Vector2(2121.9, 154.0)
const EXIT_PATH: Array[Vector2] = [Vector2(2127.3, 173.5), Vector2(2134.0, 181.0), Vector2(2143.0, 177.0), Vector2(2147.0, 165.0),
	Vector2(2145.0, 152.0)]
const ENDING_LINE_S: float = 2.6
const T_START: String = "Hai vòng, ai về cầu trước thì thắng. Thắng thì tao nói hàng về đâu."
const T_END: String = "Hự... được, xuống gầm cầu tao nói."
const T_GO: String = "ĐI!"
const T_LAP: String = "VÒNG %d/%d"
const T_LAST_LAP: String = "VÒNG CUỐI!"
const T_HOME: String = "VỀ CẦU! VỀ ĐÍCH!"
const T_LEAD: String = "DẪN ĐẦU"
const T_SECOND: String = "THỨ HAI"
const T_GAP_AHEAD: String = "Hơn Sói Xám %d m"
const T_GAP_BEHIND: String = "Sau Sói Xám %d m"
const T_WIN: String = "VỀ NHẤT!"
const T_LOSE_BEATEN: String = "Sói Xám về trước! Làm lại"
const T_LOSE_KNOCKED: String = "Bị đạp văng khỏi xe! Làm lại"
const T_RETRY_LAP2: String = "Làm lại từ vòng 2"
const T_OFF: String = "Ra khỏi đường đua! Về cổng trước"
const T_WRONG: String = "Đi ngược đường rồi!"
const T_CORNER: String = "DRIFT! %s"
const T_CORNER_BONUS: String = "DRIFT ĐẸP! +NITRO"
const T_KICK_HIT: String = "ĐẠP TRÚNG! %d/%d"
const T_WOBBLE: String = "SÓI XÁM LOẠNG CHOẠNG!"
const T_HE_KICKED: String = "Ăn đạp của Sói Xám!"
const T_DODGED: String = "NÉ ĐẸP!"
const T_TURN_LAP2: String = "VÒNG 2: RẼ PHẢI"
const T_TURN_HOME: String = "VỀ ĐÍCH: RẼ TRÁI"
const T_STAB: String = "Độ vững xe"
const T_KICKS: String = "Đạp Sói Xám"
const T_RIDING: String = "[Q]/[E] đạp · [SPACE] drift · [SHIFT] nitro · [W]/[S] ga/phanh · [A]/[D] lái · [CTRL] cúi"
const T_NO_DISMOUNT: String = "Đang đua với Sói Xám, không xuống xe được!"

var roam: Node = null
var bike: PlayerBike
var player: Node3D
var traffic: RoamTraffic
var course: DriftCourse
var rival: DriftRival
var combat: PlayerBikeCombat
var props: DriftRaceProps
var fx: WeaponFX
var hud: CanvasLayer
var use_intro: bool = true
var state: String = "idle"
var t: float = 0.0                        # time in the current state
var s_p: float = 0.0
var d_p: float = 0.0
var lap: int = 0
var lap2_reached: bool = false
var gate_i: int = 0
var losses: int = 0
var resets: int = 0
var corner_bonuses: int = 0
var contacts: int = 0
var dodges: int = 0
var off_t: float = 0.0
var wrong_t: float = 0.0
var grace_t: float = 0.0
var win_how: String = ""
var lose_reason: String = ""
var retry_count: bool = false
var race_t: float = 0.0
var min_gap: float = INF
var max_gap: float = -INF
var lead_t: float = 0.0                   # seconds in the lead (tests, tuning)
var countdown_len: float = COUNTDOWN_S
var start_s: float = 0.0                  # the grid of the current attempt (0, or the lap 2 grid)
## Difficulty-picked tuning (refresh_tuning at each start).
var corner_bonus: float = 12.0
var band_far: float = 0.93
var band_lead: float = 1.08
var mercy_step: float = 0.025
## Tests: 1 = count the bike as drifting, 0 = as not drifting, -1 = read bike.is_drifting.
var force_drift: int = -1
var _targets: Array = []
var _counts_done: int = 0
var _answers_done: int = 0
var _music_sent: bool = false
var _corner: int = -1
var _corner_drift: float = 0.0
var _turn_prompt: int = 0
var _contact_cd: float = 0.0
var _fade: float = 0.0                    # 0 clear .. 1 black
var _fade_dir: float = 0.0
var _fade_then: Callable = Callable()
var _hooks: bool = false
var _bike_profile: Dictionary = {}
var _bike_nitro_prev: bool = false
var _traffic_off: bool = false
var _ray_q: PhysicsRayQueryParameters3D
var _ending_line_t: float = -1.0
var _win_t: float = 0.0
# HUD widgets
var _panel: Control
var _lap_label: Label
var _pos_label: Label
var _gap_label: Label
var _popup: Label
var _popup_left: float = 0.0
var _prompt: Label
var _sub_label: Label
var _warn_l: Label
var _warn_r: Label
var _fade_rect: ColorRect
var popup_text: String = ""
var popups: int = 0
var subtitle_text: String = ""
var prompt_text: String = ""
var warn_side: int = 0
var _sub_t: float = 0.0


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
	use_intro = bool(opts.get("intro", true))
	refresh_tuning()
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
	rival.kick_fn = rival_kick
	rival.kicked_player.connect(_on_rival_kicked)
	rival.wobbled.connect(_on_rival_wobble)
	var pc: Node = roam.get("combat") if roam else null
	fx = pc.get("fx") as WeaponFX if pc else null
	if fx == null:
		fx = WeaponFX.new()
		fx.name = "RaceFX"
		add_child(fx)
	_targets = [rival]
	if bike and not bike.crash_occurred.is_connected(_on_bike_crash):
		bike.crash_occurred.connect(_on_bike_crash)   # before PlayerBikeCombat's own flat crash damage (it lands in the i-frames)
	combat = PlayerBikeCombat.new()
	combat.name = "RaceCombat"
	add_child(combat)
	combat.setup(bike, {"roam": roam, "targets": _targets, "fx": fx})
	combat.kick_hit.connect(_on_kick_hit)
	Impact.prepare(self)
	if bool(opts.get("props", true)):
		props = DriftRaceProps.new()
		add_child(props)
		props.setup(course, func(p: Vector3) -> Variant: return floor_at(p, 8.0, 8.0), excl)
	_build_hud()


## The difficulty's numbers (Thường, Dễ) for the race rules; the rival reads his own.
func refresh_tuning() -> void:
	corner_bonus = float(Difficulty.pick(12.0, 18.0))
	band_far = float(Difficulty.pick(0.92, 0.8))
	band_lead = float(Difficulty.pick(1.08, 1.05))
	mercy_step = float(Difficulty.pick(0.025, 0.04))
	if rival:
		rival.refresh_tuning()


# ---------------------------------------------------------------------------
# FLOW
# ---------------------------------------------------------------------------
func start() -> void:
	if bike == null:
		push_warning("DriftDuel.start: no bike")
		return
	refresh_tuning()
	_set_hooks(true)
	lap2_reached = false
	_reset_race(0.0)
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


## Quick retry (also what a loss does by itself): the grid, or the lap 2 grid once the player got there; a short countdown.
func retry() -> void:
	_reset_race(course.lap_s[1] + LAP2_GRID_AFTER if lap2_reached else 0.0)
	if lap2_reached:
		_subtitle(T_RETRY_LAP2, RETRY_COUNTDOWN_S)
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


## The rubber band: his speed factor for a gap (m, his progress minus the player's). He eases off when far ahead (the race
## stays close enough to win with clean riding) and pushes when passed.
func band_for(g: float, grace: bool) -> float:
	if grace:
		return 0.7
	if g < -25.0:
		return band_lead + 0.04
	if g < 0.0:
		return band_lead
	if g < BAND_START_M:
		return 1.0
	return lerpf(1.0, band_far, clampf((g - BAND_START_M) / (BAND_FULL_M - BAND_START_M), 0.0, 1.0))


func _enter(s: String) -> void:
	state = s
	t = 0.0


## Both on the grid at progress s0 (0 = the bridge; else the lap 2 grid): stopped, stability full, nitro empty.
func _reset_race(s0: float) -> void:
	start_s = s0
	gate_i = 0
	while gate_i < course.gates.size() and course.gates[gate_i] <= s0:
		gate_i += 1
	off_t = 0.0
	wrong_t = 0.0
	grace_t = 0.0
	race_t = 0.0
	_corner = -1
	_corner_drift = 0.0
	_turn_prompt = 0
	min_gap = INF
	max_gap = -INF
	_win_t = 0.0
	combat.reset()
	combat.enabled = false
	_place_player(s0, GRID_LAT)
	s_p = s0
	d_p = GRID_LAT
	lap = course.lap_at(s0)
	rival.refresh_tuning()
	rival.pace *= 1.0 - mercy_step * float(mini(losses, MERCY_MAX))   # each loss eases him a little (at most MERCY_MAX steps)
	rival.place_at(s0 + RIVAL_GRID_AHEAD, -GRID_LAT)
	if s0 > 0.0:
		rival.nitro_left = maxi(1, rival.nitros_per_race / 2)
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
	combat.enabled = false
	_enter("countdown")
	countdown_started.emit(is_retry)


## The count shown at a countdown time (3, 2, 1 for the full countdown; 2, 1 on a retry).
func count_label(i: int) -> String:
	return str(int(round(countdown_len)) - i)


func _physics_process(delta: float) -> void:
	if bike == null or not is_instance_valid(bike):
		return
	var rdt: float = delta / maxf(Engine.time_scale, 0.01)
	t += rdt
	_tick_fade(rdt)
	_tick_popup(rdt)
	if props:
		props.tick(rdt, s_p, bike.global_position)
	match state:
		"intro":
			rival.tick(delta, RIVAL_GRID_AHEAD)
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
			_feed_rival()
			rival.tick(delta, gap())
			if t >= WIN_HOLD_S and _fade_dir == 0.0 and _fade < 0.5:
				_fade_to(1.0, _begin_ending)
		"ending":
			_tick_ending(delta)
		_:
			pass


func _tick_countdown(delta: float) -> void:
	rival.tick(delta, RIVAL_GRID_AHEAD)
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
		combat.enabled = true
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
	if grace_t > 0.0:
		grace_t -= delta
	_contact_cd -= delta
	var g: float = gap()
	_feed_rival()
	rival.band = lerpf(rival.band, band_for(g, grace_t > 0.0), minf(1.0, delta * 3.0))
	rival.fight = g < TAIL_GAP_M
	rival.tick(delta, g)
	min_gap = minf(min_gap, g)
	max_gap = maxf(max_gap, g)
	if g < 0.0:
		lead_t += delta
	_contact()
	# he crosses the line first: lost
	if rival.s >= course.length and not rival.finished:
		rival.finished = true
		if s_p < course.length:
			_lose("beaten")
			return
	if combat.knocked:
		_lose("knocked")
		return
	# gates, laps
	while gate_i < course.gates.size() and s_p >= course.gates[gate_i]:
		gate_i += 1
		gate_passed.emit(gate_i - 1)
	var l: int = course.lap_at(s_p)
	if l != lap:
		lap = l
		if lap >= 2:
			lap2_reached = true
		lap_started.emit(lap)
		if lap >= 1 and lap <= DriftCourse.LAPS:
			_popup_show(T_LAST_LAP if lap == DriftCourse.LAPS else T_LAP % [lap, DriftCourse.LAPS], Color("#FFE14D"), 1.2)
		elif lap > DriftCourse.LAPS:
			_popup_show(T_HOME, Color("#FFE14D"), 1.2)
	_tick_turn_prompt()
	_tick_corners(delta)
	# off the course / the wrong way
	var along: float = Vector2(bike.velocity.x, bike.velocity.z).dot(course.tangent(s_p))
	off_t = off_t + delta if absf(d_p) > course.half_width_at(s_p) + OFF_COURSE_M else 0.0
	wrong_t = wrong_t + delta if along < -3.0 else 0.0
	if off_t >= OFF_COURSE_S or wrong_t >= WRONG_WAY_S:
		_reset_to_gate(T_WRONG if wrong_t >= WRONG_WAY_S else T_OFF)
		return
	# the finish line
	if s_p >= course.length and gate_i >= course.gates.size():
		_win("race")
		return
	_update_hud()


func _feed_rival() -> void:
	rival.p_s = s_p
	rival.p_d = d_p
	rival.p_v = absf(bike.current_speed_ms)


## The drift corners: the bike's charge x CORNER_CHARGE_MULT inside one, the corner's name on the way in, and a drifted
## corner (CORNER_DRIFT_MIN s or more of drift in it) gives corner_bonus nitro charge on the way out.
func _tick_corners(delta: float) -> void:
	var z: int = course.corner_at(s_p) if s_p < course.length else -1
	bike.drift_charge_mult = CORNER_CHARGE_MULT if z >= 0 else 1.0
	var drifting: bool = bike.is_drifting if force_drift < 0 else force_drift == 1
	if z != _corner:
		if _corner >= 0 and _corner_drift >= CORNER_DRIFT_MIN:
			corner_bonuses += 1
			if bike.has_method("add_drift_charge"):
				bike.add_drift_charge(corner_bonus)
			_popup_show(T_CORNER_BONUS, Color("#27E8FF"), 0.9)
		_corner = z
		_corner_drift = 0.0
		if z >= 0:
			_popup_show(T_CORNER % String(course.corners[z][3]), Color("#FF9F1C"), 0.8)
	if z >= 0 and drifting:
		_corner_drift += delta


## The lap junction's turn prompt: right for lap 2, left for the finish (the arrows show it too).
func _tick_turn_prompt() -> void:
	var want: int = 0
	if s_p > course.lap_s[1] - 90.0 and s_p < course.lap_s[1] + 5.0:
		want = 1
	elif s_p > course.lap_s[2] - 90.0 and s_p < course.lap_s[2] + 5.0:
		want = 2
	if want != _turn_prompt:
		_turn_prompt = want
		prompt_text = ["", T_TURN_LAP2, T_TURN_HOME][want]
		if _prompt:
			_prompt.text = prompt_text
			_prompt.visible = want != 0


## The player's progress and lateral offset on the path (windowed search; a wide one when far off).
func _follow_player() -> void:
	var bp := Vector2(bike.global_position.x, bike.global_position.z)
	var pr: Vector2 = course.project_near(bp, s_p)
	if absf(pr.y) > 25.0:
		var any: Vector2 = course.project_any(bp, s_p)
		if absf(any.y) + 5.0 < absf(pr.y):
			pr = any
	s_p = pr.x
	d_p = pr.y


## Side by side touching: both pushed apart with sparks (no damage); riding into his back wheel caps the player's speed.
func _contact() -> void:
	if not rival.racing:
		return
	var along: float = rival.s - s_p
	var lat: float = rival.d - d_p
	if absf(along) < CONTACT_ALONG and absf(lat) < CONTACT_LAT and _contact_cd <= 0.0:
		_contact_cd = CONTACT_CD
		contacts += 1
		var sgn: float = -signf(lat) if lat != 0.0 else 1.0
		var r: Vector2 = course.right(s_p) * sgn
		bike.global_position += Vector3(r.x, 0.0, r.y) * 0.35
		bike.velocity += Vector3(r.x, 0.0, r.y) * 2.5
		rival.d_target = clampf(rival.line_d - sgn * 1.0, -3.0, 3.0)
		var at: Vector3 = (bike.global_position + rival.global_position) * 0.5 + Vector3(0.0, 0.5, 0.0)
		Impact.particles(self, "sparks", at, Vector3(0.0, 0.7, 0.0), 0.8, fx)
		Impact.sound(self, "metal_slam", at, -8.0)
		bike.add_camera_shake(0.3)
	elif along > 0.4 and along < 2.2 and absf(lat) < 0.8 and bike.current_speed_ms > rival.v:
		bike.current_speed_ms = maxf(rival.v - 0.5, 0.0)


func _win(how: String) -> void:
	win_how = how
	_enter("won")
	combat.enabled = false
	bike.drift_charge_mult = 1.0
	rival.finished = true
	_popup_show(T_WIN, Color("#7CFF6B"), WIN_HOLD_S)
	if props:
		var fp: Vector2 = course.point(course.length)
		props.fireworks(Vector3(fp.x, bike.global_position.y, fp.y))
	Impact.slowmo_orbit(self, bike, FINISH_ORBIT_S)   # the signature moment: the line crossed in slow motion, the camera round
	won.emit(how)


func _lose(reason: String) -> void:
	lose_reason = reason
	losses += 1
	_enter("lost")
	combat.enabled = false
	bike.drift_charge_mult = 1.0
	_popup_show(T_LOSE_KNOCKED if reason == "knocked" else T_LOSE_BEATEN, Color("#FF5C7A"), LOSE_PAUSE_S + 0.3)
	lost.emit(reason)


## Off the course or the wrong way: back to the last gate (the attempt's grid before the first) behind a quick fade,
## stopped, with RESET_GRACE_S of grace (he eases off).
func _reset_to_gate(msg: String) -> void:
	resets += 1
	off_t = 0.0
	wrong_t = 0.0
	var g: int = gate_i - 1
	_popup_show(msg, Color("#FF9F1C"), 1.0)
	_fade_to(1.0, func() -> void:
		var s0: float = maxf(course.gates[g] if g >= 0 else start_s, start_s)
		_place_player(s0, 0.0)
		s_p = s0
		d_p = 0.0
		grace_t = RESET_GRACE_S
		reset_to_gate.emit(g)
		_fade_to(0.0))


func _begin_ending() -> void:
	_enter("ending")
	var es: float = course.project_any(ENDING_AT, course.length).x
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
# KICKS
# ---------------------------------------------------------------------------
## Sói Xám's kick lands (DriftRival.kick_fn; side +1 = the player is on his right): stability damage from that side, the
## shove, the red edge and the jolt (PlayerBikeCombat.damage). true when it hurt.
func rival_kick(side: int) -> bool:
	if state != "racing":
		return false
	var hurt: bool = combat.damage(rival.kick_dmg, "kick", -side)
	if hurt:
		_popup_show(T_HE_KICKED, Color("#FF5C7A"), 0.9)
	return hurt


func _on_rival_kicked(_side: int, hit: bool) -> void:
	if hit or state != "racing":
		return
	if absf(rival.s - s_p) < 4.0 and absf(rival.d - d_p) < 5.5:   # it missed a player in reach of a dodge: a reward
		dodges += 1
		_popup_show(T_DODGED, Color("#7CFF6B"), 0.7)
		bike.add_drift_charge(5.0)


func _on_kick_hit(target: Node3D, _side: int) -> void:
	if target != rival or state != "racing":
		return
	if not rival.wobbling():
		_popup_show(T_KICK_HIT % [rival.hits_taken, DriftRival.KICKS_TO_WOBBLE], Color("#FFE14D"), 0.8)


## A crash into a wall or a kerb while racing: CRASH_DMG_MIN..MAX by the speed (x the difficulty), not PlayerBikeCombat's flat
## 25 (that one falls inside the i-frames this hit gives).
func _on_bike_crash() -> void:
	if state != "racing" or combat == null or not combat.enabled:
		return
	var u: float = clampf((absf(bike.current_speed_ms) - 6.0) / 20.0, 0.0, 1.0)
	combat.damage(lerpf(CRASH_DMG_MIN, CRASH_DMG_MAX, u) * float(Difficulty.pick(1.0, 0.6)), "crash")


func _on_rival_wobble() -> void:
	_popup_show(T_WOBBLE, Color("#7CFF6B"), 1.4)
	bike.add_drift_charge(10.0)


# ---------------------------------------------------------------------------
# PLAYER PLACEMENT / HOOKS
# ---------------------------------------------------------------------------
## The bike on the path at progress s, lateral d, facing along it, stopped (mounting the player when on foot).
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


## FreeRoam hint + [F] refusal, the bike's race profile and nitro, the kicks, the traffic parked; all given back when off.
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
	if combat and is_instance_valid(combat):
		combat.enabled = false
		if not on:
			combat.reset()
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


## Traffic parked for the race (the course is closed), running again after.
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


func _tick_fade(rdt: float) -> void:
	if _fade_dir != 0.0:
		_fade = clampf(_fade + _fade_dir * rdt / FADE_S, 0.0, 1.0)
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


func _subtitle(text: String, secs: float) -> void:
	subtitle_text = text
	if _sub_label:
		_sub_label.text = text
		_sub_label.visible = true
	_sub_t = secs


func _tick_popup(rdt: float) -> void:
	if _popup_left > 0.0:
		_popup_left -= rdt
		if _popup_left <= 0.0 and _popup:
			_popup.visible = false
	if _sub_t > 0.0:
		_sub_t -= rdt
		if _sub_t <= 0.0 and _sub_label:
			_sub_label.visible = false
	# the side warning while he winds up a kick (Q3: red = danger)
	var w: int = 0
	if state == "racing" and rival and rival.mode == "windup":
		w = -int(rival.kick_side)            # he is on the player's left when the player is on his right
	if w != warn_side:
		warn_side = w
		if _warn_l:
			_warn_l.visible = w < 0
			_warn_r.visible = w > 0


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "RaceHUD"
	hud.layer = 3
	add_child(hud)
	_panel = RacePanel.new()
	_panel.name = "RacePanel"
	_panel.set("duel", self)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -250.0
	_panel.offset_right = 250.0
	_panel.offset_top = 16.0
	_panel.offset_bottom = 128.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_panel)
	_lap_label = _label(_panel, 20, Color("#FFE14D"), Vector2(14.0, 6.0), Vector2(200.0, 26.0), HORIZONTAL_ALIGNMENT_LEFT)
	_pos_label = _label(_panel, 20, Color("#7CFF6B"), Vector2(286.0, 6.0), Vector2(200.0, 26.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_gap_label = _label(_panel, 16, Color("#F4F1FF"), Vector2(14.0, 32.0), Vector2(472.0, 22.0), HORIZONTAL_ALIGNMENT_CENTER)
	_label(_panel, 14, Color("#F4F1FF"), Vector2(14.0, 58.0), Vector2(150.0, 20.0), HORIZONTAL_ALIGNMENT_LEFT).text = T_STAB
	_label(_panel, 14, Color("#F4F1FF"), Vector2(14.0, 84.0), Vector2(150.0, 20.0), HORIZONTAL_ALIGNMENT_LEFT).text = T_KICKS
	_popup = Label.new()
	_style(_popup, 52, Color.WHITE)
	_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_popup.offset_left = -420.0
	_popup.offset_right = 420.0
	_popup.offset_top = -200.0
	_popup.offset_bottom = -130.0
	_popup.visible = false
	hud.add_child(_popup)
	_prompt = Label.new()
	_style(_prompt, 30, Color("#FFD21F"))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -300.0
	_prompt.offset_right = 300.0
	_prompt.offset_top = 70.0
	_prompt.offset_bottom = 110.0
	_prompt.visible = false
	hud.add_child(_prompt)
	_sub_label = Label.new()
	_style(_sub_label, 22, Color("#F4F1FF"))
	_sub_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_label.offset_left = -460.0
	_sub_label.offset_right = 460.0
	_sub_label.offset_top = -260.0
	_sub_label.offset_bottom = -224.0
	_sub_label.visible = false
	hud.add_child(_sub_label)
	_warn_l = _warn(BikeCombatData.T_WARN_L, Control.PRESET_CENTER_LEFT, 24.0)
	_warn_r = _warn(BikeCombatData.T_WARN_R, Control.PRESET_CENTER_RIGHT, -224.0)
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "RaceFade"
	fade_layer.layer = 12
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	fade_layer.add_child(_fade_rect)
	hud.visible = false


func _warn(text: String, preset: int, x: float) -> Label:
	var l := Label.new()
	_style(l, 30, Color("#FF3B3B"))
	l.text = text
	l.set_anchors_and_offsets_preset(preset)
	l.offset_left = x
	l.offset_right = x + 200.0
	l.offset_top = -30.0
	l.offset_bottom = 30.0
	l.visible = false
	hud.add_child(l)
	return l


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
var _hud_lap: int = -1
var _hud_lead: int = -1
var _hud_stab: int = -1
var _hud_kicks: int = -1


## Texts rebuilt only when their number changes (no string building per frame).
func _update_hud() -> void:
	if _gap_label == null:
		return
	var g: int = int(round(gap()))
	if g != _hud_g:
		_hud_g = g
		_gap_label.text = T_GAP_AHEAD % -g if g < 0 else T_GAP_BEHIND % g
	var lp: int = clampi(lap, 1, DriftCourse.LAPS)
	if lp != _hud_lap:
		_hud_lap = lp
		_lap_label.text = T_LAP % [lp, DriftCourse.LAPS]
	var lead: int = 1 if g < 0 else 0
	if lead != _hud_lead:
		_hud_lead = lead
		_pos_label.text = T_LEAD if lead == 1 else T_SECOND
		_pos_label.add_theme_color_override("font_color", Color("#7CFF6B") if lead == 1 else Color("#FF9F1C"))
	var st: int = int(ceil(combat.stability))
	var kk: int = rival.hits_taken + (10 if rival.wobbling() else 0)
	if st != _hud_stab or kk != _hud_kicks:
		_hud_stab = st
		_hud_kicks = kk
		_panel.queue_redraw()


class RacePanel:
	extends Control
	var duel: DriftDuel

	func _draw() -> void:
		if duel == null:
			return
		var sz: Vector2 = size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.02, 0.12, 0.78))
		draw_rect(Rect2(Vector2.ZERO, sz), Color("#FF3FD2"), false, 2.0)
		# stability bar
		var bar := Rect2(170.0, 60.0, sz.x - 184.0, 16.0)
		var f: float = clampf(duel.combat.stability / maxf(duel.combat.max_stability, 1.0), 0.0, 1.0)
		draw_rect(bar, Color(1.0, 1.0, 1.0, 0.15))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color("#3FE07A") if f > 0.25 else Color("#FF3B3B"))
		draw_rect(bar, Color(1.0, 1.0, 1.0, 0.4), false, 1.0)
		# his kick pips: lit per kick landed, all lit (green) while he wobbles
		var wob: bool = duel.rival.wobbling()
		for i: int in DriftRival.KICKS_TO_WOBBLE:
			var r := Rect2(170.0 + 34.0 * float(i), 86.0, 26.0, 16.0)
			var lit: bool = wob or i < duel.rival.hits_taken
			draw_rect(r, (Color("#7CFF6B") if wob else Color("#FFE14D")) if lit else Color(1.0, 1.0, 1.0, 0.12))
			draw_rect(r, Color(1.0, 1.0, 1.0, 0.4), false, 1.0)
