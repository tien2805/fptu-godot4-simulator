# File: res://scripts/story/missions/MissionTowerParking.gd
# Day 7 floor 1, the parking deck B3 of Lọ Academy (plan 2026-11-01-w4-day7.md T1 / T3): the Bầy Sói's last ride, on the
# deck's one-way ring road (LairTower.route: the ring sampled as a BikeRoute, LAPS laps), on the protagonist's own bike
# (StoryTower's PlayerBike, mounted by BikeChase.start). Three waves: two of Bầy Sói, then Sói Xám back on a fixed-up bike
# (StoryCast "soi_xam" body, the heavy kind, more HP) with his return card (CastD7 "soi_xam_back", once: flag
# soi_xam_back_card) at the start of the last wave. `won` = done; bikers still riding at the route's end ride off up the
# ramp = "TOANG!" (they warn Lọ); knocked off = "TOANG!"; THỬ LẠI = BikeChase.retry() at the wave checkpoint.
# A slower deck profile (PROFILE: the ring's 22 m radius) and no nitro; no opening, no replay (the floors' replay is the
# lasers' seg_d7_floors).
# opts (tests): manual_card (the card is stepped by the test), seed.
class_name MissionTowerParking
extends StoryMission

const START_S: float = 8.0
const LAPS: int = 16
const HALF_W: float = 3.8
## The deck's bike profile: 61 km/h, 70 in a slipstream (the ring is tight; the owner's 120 would not hold the lane).
const PROFILE: Dictionary = {"max_speed_ms": 17.0, "slipstream_max_ms": 19.5, "engine_accel": 11.0, "air_drag": 0.02}
const CARD_FLAG: String = "soi_xam_back_card"
const T_KNOCKED: String = "Bị đạp văng khỏi xe rồi!"
const T_ESCAPED: String = "Bầy Sói chạy lên tầng báo Lọ rồi!"
const T_START: String = "Hầm B3: đá văng hết Bầy Sói!"
const T_WIN: String = "Sói Xám nằm sàn! Lên tầng thôi!"

var chase: BikeChase
var card: StoryVillainCard = null
var pts: Dictionary = {}
var escaped_fail: bool = false


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
	var route: Variant = pts.get("route", null)
	var o: Dictionary = {"roam": roam, "start_line": T_START, "win_line": T_WIN, "replay_slot": "", "auto_replay": false,
		"seed": int(opts.get("seed", 7)), "profile": PROFILE, "nitro": false, "half_width": HALF_W, "start_s": START_S,
		"waves": waves(), "wave_opts": wave_opts()}
	if route != null and (route as PackedVector2Array).size() > 2:
		o["route"] = route
	chase.setup(o)
	chase.won.connect(_on_won)
	chase.lost.connect(_on_lost)
	chase.wave_started.connect(_on_wave_started)
	chase.takedown.connect(func(_b: BikerEnemy, _c: String) -> void: add_stat("ko"))
	chase.wave_started.connect(func(_i: int) -> void: mark_ko_checkpoint())
	chase.start()


## Sói Xám's return card once (the last wave's start).
func _on_wave_started(i: int) -> void:
	if i != chase.waves.size() - 1 or card != null:
		return
	var sd: Node = StoryUtil.director()
	var flags: Dictionary = sd.get("flags") if sd else {}
	if bool(flags.get(CARD_FLAG, false)):
		return
	flags[CARD_FLAG] = true
	card = StoryVillainCard.show_for(self, CastD7.villain_data("soi_xam_back"), CastD7.card_len("soi_xam_back"))
	if bool(opts.get("manual_card", false)):
		card.manual = true
	card.finished.connect(func() -> void: card = null, CONNECT_ONE_SHOT)


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
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if chase:
		chase.retry()
		chase.escaped = 0


func _cleanup() -> void:
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
