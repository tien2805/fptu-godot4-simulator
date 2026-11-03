# File: res://scripts/story/missions/MissionTowerForklift.gd
# Day 7 floor 2, the warehouse (plan 2026-11-01-w4-day7.md T1 / T3): Alexander ABCXYZ is back on a new forklift (bought on
# instalments). MissionForklift's joust in LairTower's warehouse: the boss wave (ForkliftBoss, Alexander's StoryCast body),
# the player's own forklift (PlayerForklift: [F] in / out, rams on his side / back while his forks are up), his tossed
# crates thrown back; no yard crane here (the warehouse has none). Down = "TOANG!", retry = a fresh boss and both forklifts
# reset.
# w5-day7 T1, his return beat (D7Beat): on the first attempt a preview cut on Alexander in his seat, then (once: flag
# alexander_back_card) his return card (CastD7 "alexander_back") over the cut's frozen last frame.
# w5-day7 T5: no crane on this floor to skip a phase, so a ram takes RAM_FRAC of his bar (ForkliftBoss opt "ram_frac";
# Day 3 keeps its own): sim_day7 warehouse at Day 3's share, 24 runs: Thường 3.96 mean fails (6 at the bot's cap of 8).
# points: start (+ start_yaw), boss_at, boss_yaw, fork_at, fork_yaw, ammo, centre, leash.
class_name MissionTowerForklift
extends MissionForklift

const CARD_FLAG: String = "alexander_back_card"
## A ram's share of his bar here (Day 3: ForkliftBoss.RAM_FRAC 0.15; Dễ x1.2 as there).
const RAM_FRAC: float = 0.2

var card: StoryVillainCard = null
var beat_fx: D7Beat = null


func _start() -> void:
	place_player()
	make_fight({"start_alerted": true})
	var at: Vector3 = pts.get("boss_at", player.global_position + Vector3(0.0, 0.0, -12.0) if player else Vector3.ZERO)
	var o: Dictionary = {"body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build("alexander"),
		"hp": float(Difficulty.pick(GunData.BOSS_HP, GunData.BOSS_HP * 0.8)), "joust": true, "ram_frac": RAM_FRAC}
	fight.add_wave([{"boss": "forklift", "at": at, "yaw": float(pts.get("boss_yaw", 0.0)), "opts": o}])
	fight.start()
	if pts.has("fork_at"):
		pf = PlayerForklift.new()
		add_child(pf)
		pf.setup(fight, pts["fork_at"], float(pts.get("fork_yaw", 0.0)))
		pf.rammed.connect(_on_rammed)
	markers = OffscreenMarkers.make(hud, player)
	if pf:
		markers.track(pf.forklift, "prompt", "Xe nâng", 2.6)
	_track_boss()
	radio("Alexander mua xe nâng mới r e. Lấy con xe nâng đỗ bên trái, F lên xe, húc hông nó lúc nó giơ càng!",
		"Lên xe nâng [F]. Khi nó SƠ HỞ hoặc giơ càng, húc vào hông.", 6.0)
	beat_fx = D7Beat.new()
	add_child(beat_fx)
	beat_fx.card_shown.connect(func(c: StoryVillainCard) -> void: card = c)
	beat_fx.finished.connect(func() -> void: card = null)
	var b: ForkliftBoss = fight.boss as ForkliftBoss if fight and fight.boss else null
	beat_fx.play(b.driver if b and b.driver else b, {"card": "alexander_back", "flag": CARD_FLAG,
		"manual_card": bool(opts.get("manual_card", false))})


## THỬ LẠI: a beat still running ends (no card over the retry), then MissionForklift's reset.
func _reset() -> void:
	if beat_fx:
		beat_fx.cancel()
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	super._reset()


func _cleanup() -> void:
	if beat_fx and is_instance_valid(beat_fx):
		beat_fx.cancel()
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	super._cleanup()
