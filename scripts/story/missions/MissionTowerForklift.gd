# File: res://scripts/story/missions/MissionTowerForklift.gd
# Day 7 floor 2, the warehouse (plan 2026-11-01-w4-day7.md T1 / T3): Alexander ABCXYZ is back on a new forklift (bought on
# instalments). MissionForklift's joust in LairTower's warehouse: the boss wave (ForkliftBoss, Alexander's StoryCast body),
# the player's own forklift (PlayerForklift: [F] in / out, rams on his side / back while his forks are up), his tossed
# crates thrown back; no yard crane here (the warehouse has none). His return card (CastD7 "alexander_back", flag
# alexander_back_card) once over the first frame. Down = "TOANG!", retry = a fresh boss and both forklifts reset.
# points: start (+ start_yaw), boss_at, boss_yaw, fork_at, fork_yaw, ammo, centre, leash.
class_name MissionTowerForklift
extends MissionForklift

const CARD_FLAG: String = "alexander_back_card"

var card: StoryVillainCard = null


func _start() -> void:
	place_player()
	make_fight({"start_alerted": true})
	var at: Vector3 = pts.get("boss_at", player.global_position + Vector3(0.0, 0.0, -12.0) if player else Vector3.ZERO)
	var o: Dictionary = {"body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build("alexander"),
		"hp": float(Difficulty.pick(GunData.BOSS_HP, GunData.BOSS_HP * 0.8)), "joust": true}
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
	_show_card()


func _show_card() -> void:
	var sd: Node = StoryUtil.director()
	var flags: Dictionary = sd.get("flags") if sd else {}
	if bool(flags.get(CARD_FLAG, false)):
		return
	flags[CARD_FLAG] = true
	card = StoryVillainCard.show_for(self, CastD7.villain_data("alexander_back"), CastD7.card_len("alexander_back"))
	if bool(opts.get("manual_card", false)):
		card.manual = true
	card.finished.connect(func() -> void: card = null, CONNECT_ONE_SHOT)


func _cleanup() -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	super._cleanup()
