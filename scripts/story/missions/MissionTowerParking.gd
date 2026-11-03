# File: res://scripts/story/missions/MissionTowerParking.gd
# Day 7 floor 1, the parking deck B3 of Lọ Academy (plan 2026-11-01-w4-day7.md T1 / T3): the Bầy Sói's last ride, up the
# deck's one-way spiral (w5-day7 T2: LairTower.route3, the lane with its heights as a BikeRoute, LAPS laps, one level per
# lap: a flat half turn, then a ramp up to the next), on the protagonist's own bike
# (StoryTower's PlayerBike, mounted by BikeChase.start). Three waves: two of Bầy Sói, then Sói Xám back on a fixed-up bike
# (StoryCast "soi_xam" body, the heavy kind, more HP) with his return card (CastD7 "soi_xam_back", once: flag
# soi_xam_back_card) at the start of the last wave. `won` = done; bikers still riding at the route's end ride off up the
# ramp = "TOANG!" (they warn Lọ); knocked off = "TOANG!"; THỬ LẠI = BikeChase.retry() at the wave checkpoint.
# A slower deck profile (PROFILE: the ring's 22 m radius) and no nitro; no opening, no replay (the floors' replay is the
# lasers' seg_d7_floors).
# w5-day7 T1, the wave beats (D7Beat): every wave's headline rider gets a preview cut as the wave rolls in (WAVE_LEAD: the
# first of wave 1, Sói Bự, Sói Xám; once the chase's own cameras are free), and Sói Xám's is his return beat: the cut,
# then (once: flag soi_xam_back_card) his card over the cut's frozen last frame. The deck's low ceiling: CUT_OPTS.
# opts (tests): manual_card (the card is stepped by the test), seed.
class_name MissionTowerParking
extends StoryMission

const START_S: float = 8.0
const LAPS: int = 16
const HALF_W: float = 3.8
## The deck's bike profile: 61 km/h, 70 in a slipstream (the ring is tight; the owner's 120 would not hold the lane).
const PROFILE: Dictionary = {"max_speed_ms": 17.0, "slipstream_max_ms": 19.5, "engine_accel": 11.0, "air_drag": 0.02}
## Thường: the wolves hold their slot this much of their usual 1.5-2.5 s before the wind-up (the deck has no set pieces,
## so the riders themselves are the threat; Dễ keeps the usual hold).
const HOLD_K: float = 0.1
## Thường: each wolf takes this many more kicks (more of them get a swing in), and the bike's stability bar is shorter.
const HP_PLUS: int = 2
const STABILITY: float = 50.0
## Thường: one more wolf in each wave.
const EXTRA: Array = [
	{"from": "behind", "lane": -1, "delay": 3.0, "opts": {"label": "Sói Lửa", "aggression": 0.7}},
	{"from": "side", "lane": 1, "delay": 3.0, "opts": {"kind": "stick", "label": "Sói Gậy 2", "aggression": 0.7}},
	{"from": "behind", "lane": 1, "delay": 4.0, "opts": {"label": "Sói Vuốt", "aggression": 0.8}}]
const CARD_FLAG: String = "soi_xam_back_card"
## The rider each wave's preview cut shows ("" = the wave's first rider).
const WAVE_LEAD: Array[String] = ["", "Sói Bự", "Sói Xám"]
## The preview cut under the deck above (4.1 m clear).
const CUT_OPTS: Dictionary = {"up": 1.3, "dist": 7.0}
## Mission seconds a wave's cut waits for its headline rider (spawned with a delay), then any rider of the wave.
const LEAD_WAIT_S: float = 3.0
const T_KNOCKED: String = "Bị đạp văng khỏi xe rồi!"
const T_ESCAPED: String = "Bầy Sói chạy lên tầng báo Lọ rồi!"
const T_START: String = "Hầm B3: đá văng hết Bầy Sói!"
const T_WIN: String = "Sói Xám nằm sàn! Lên tầng thôi!"

var chase: BikeChase
var card: StoryVillainCard = null
var pts: Dictionary = {}
var escaped_fail: bool = false
var beat_fx: D7Beat = null
## The wave whose cut waits for its rider (-1: none) and how long it has waited.
var wave_cut: int = -1
var _wave_cut_t: float = 0.0


## waves() as the deck rides them: every wolf steers by the ring's own direction at its spot (BikerEnemy route_ff: the
## heavies coming from behind settle in their slots on the 22 m ring); on Thường one more wolf per wave (EXTRA), each
## HP_PLUS kicks tougher and holding its slot HOLD_K as long before the wind-up (sim_day7: 1-3 mean fails, Dễ 0).
static func deck_waves() -> Array:
	var out: Array = waves()
	if not Difficulty.easy:
		for i: int in out.size():
			(out[i] as Array).append((EXTRA[i] as Dictionary).duplicate(true))
	for w: Array in out:
		for sp: Dictionary in w:
			var o: Dictionary = sp.get("opts", {})
			o["route_ff"] = true
			if not Difficulty.easy:
				o["hold_k"] = HOLD_K
				o["hp"] = int(o.get("hp", int(BikeCombatData.kind(String(o.get("kind", "rider")))["hp"]))) + HP_PLUS
			sp["opts"] = o
	return out


## The deck's waves: Bầy Sói, then the heavies, then Sói Xám (his StoryCast body on the heavy bike) with a wingman.
static func waves() -> Array:
	return [
		[{"from": "side", "lane": -1, "opts": {"label": "Sói Đen", "aggression": 0.6}},
		{"from": "side", "lane": 1, "delay": 0.5, "opts": {"kind": "stick", "label": "Sói Gậy", "aggression": 0.6}},
		{"from": "behind", "lane": 1, "delay": 5.0, "opts": {"label": "Sói Còi", "hp": 2, "aggression": 0.55}}],
		[{"from": "behind", "lane": -1, "opts": {"kind": "thrower", "label": "Sói Ném", "aggression": 0.7}},
		{"from": "behind", "lane": 1, "delay": 1.0, "opts": {"kind": "heavy", "label": "Sói Bự", "aggression": 0.6}},
		{"from": "behind", "lane": -1, "delay": 6.0, "opts": {"label": "Sói Bạc", "hp": 2, "aggression": 0.75}}],
		[{"from": "behind", "lane": 1, "opts": {"kind": "heavy", "label": "Sói Xám", "hp": 6, "aggression": 0.85,
			"body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build("soi_xam", {"clip": "ride"})}},
		{"from": "behind", "lane": -1, "delay": 2.0, "opts": {"kind": "stick", "label": "Sói Nanh", "hp": 2, "aggression": 0.8}}]]


static func wave_opts() -> Array:
	return [{}, {}, {"max_attackers": 2}]


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	pts = opts.get("points", {})


func _start() -> void:
	hide_top_panel()
	chase = BikeChase.new()
	chase.name = "Chase"
	add_child(chase)
	var route: Variant = pts.get("route3", pts.get("route", null))
	var o: Dictionary = {"roam": roam, "start_line": T_START, "win_line": T_WIN, "replay_slot": "", "auto_replay": false,
		"seed": int(opts.get("seed", 7)), "profile": PROFILE, "nitro": false, "half_width": HALF_W, "start_s": START_S,
		"waves": deck_waves(), "wave_opts": wave_opts(),
		"max_stability": BikeCombatData.STABILITY_MAX if Difficulty.easy else STABILITY}
	if route is PackedVector3Array and (route as PackedVector3Array).size() > 2:
		o["route"] = BikeRoute.from_points(route, HALF_W, true)        # the spiral: the lane's heights kept
	elif route is PackedVector2Array and (route as PackedVector2Array).size() > 2:
		o["route"] = route
	chase.setup(o)
	chase.won.connect(_on_won)
	chase.lost.connect(_on_lost)
	chase.wave_started.connect(_on_wave_started)
	chase.takedown.connect(func(_b: BikerEnemy, _c: String) -> void: add_stat("ko"))
	chase.wave_started.connect(func(_i: int) -> void: mark_ko_checkpoint())
	beat_fx = D7Beat.new()
	add_child(beat_fx)
	beat_fx.card_shown.connect(func(c: StoryVillainCard) -> void: card = c)
	beat_fx.finished.connect(func() -> void: card = null)
	chase.start()


## The wave's headline rider (any = the first rider riding when he is not there), or null.
func wave_lead(i: int, any: bool = false) -> BikerEnemy:
	var want: String = WAVE_LEAD[i] if i >= 0 and i < WAVE_LEAD.size() and not any else ""
	for b: Variant in chase.bikers:
		var e: BikerEnemy = b as BikerEnemy
		if e != null and is_instance_valid(e) and e.is_active() and (want == "" or e.label == want):
			return e
	return null


## The chase's own cameras free (no opening, cameo, takedown or opening cam).
func cut_free() -> bool:
	return chase != null and chase.state == "running" and not chase.opening_on and chase.cameo_state != "running" \
		and chase.cam_mode == ""


## The wave's preview cut waits for its headline rider (_tick).
func _on_wave_started(i: int) -> void:
	wave_cut = i
	_wave_cut_t = 0.0


## The wave's preview cut once its rider rides; the last wave's is Sói Xám's return beat (his card once).
func _tick(dt: float) -> void:
	if wave_cut < 0 or chase == null or beat_fx == null or beat_fx.busy() or card != null:
		return
	_wave_cut_t += dt
	var lead: BikerEnemy = wave_lead(wave_cut, _wave_cut_t > LEAD_WAIT_S)
	if lead == null:
		return
	var o: Dictionary = CUT_OPTS.duplicate()
	o["gate"] = cut_free
	if wave_cut == chase.waves.size() - 1 and lead.label == WAVE_LEAD[WAVE_LEAD.size() - 1]:
		o.merge({"card": "soi_xam_back", "flag": CARD_FLAG, "manual_card": bool(opts.get("manual_card", false))})
	wave_cut = -1
	beat_fx.play(lead, o)


func _on_won() -> void:
	if chase.ended_early and chase.escaped > 0:     # the deck's end with wolves still up (escaped is not reset by retry)
		escaped_fail = true
		fail(T_ESCAPED)
		return
	finish({"downed": chase.downed_total, "takedowns": chase.takedowns})


func _on_lost() -> void:
	fail(T_KNOCKED)


func _reset() -> void:
	escaped_fail = false
	wave_cut = -1
	if beat_fx:
		beat_fx.cancel()                       # a beat waiting or carding when the wolves knocked the bike over
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if chase:
		chase.retry()
		chase.escaped = 0


func _cleanup() -> void:
	if beat_fx and is_instance_valid(beat_fx):
		beat_fx.cancel()
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if chase and is_instance_valid(chase):
		chase.stop()
		chase.queue_free()
	chase = null


## BikeHUD shows the chase (the mission's top panel stays hidden; the fail card and the radio still show).
func hud_visible() -> bool:
	return state in ["running", "failed"] and (chase == null or chase.replay == null)
