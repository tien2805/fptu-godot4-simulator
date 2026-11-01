# File: res://scripts/story/missions/MissionTowerKatana.gd
# Day 7 floor 3, the server floor (plan 2026-11-01-w4-day7.md T1 / T3): Lê Minh Za Mẫn is back with a cheaper katana
# ("katana 49 nghìn", freeship). MissionDuel's SwordDuel (the player's staff against KatanaBoss) without the sprinklers
# (no fire on this floor) (his HP x KATANA_HP_K: Day 5's HP after the T5 sloppy-bot runs; 0.75 was too soft; on Thường KATANA_PACE), the QTE finisher
# at 0 HP as on Day 5, his return card (CastD7 "za_man_back", flag za_man_back_card) once while he stands staged.
# `won` = done; down = "TOANG!" -> retry() = a fresh Za Mẫn.
# opts: "points" (start, start_yaw, boss_at, boss_yaw), "manual_card", "seed".
class_name MissionTowerKatana
extends StoryMission

const T_DOWN: String = "Bị chém gục rồi!"
const START_LINE: String = "Lần này bảo hành mười bốn ngày!"
const CARD_FLAG: String = "za_man_back_card"
## The cheap katana: his HP scale against Day 5's (SwordData.HP_SCALE / HP_SCALE_EASY).
const KATANA_HP_K: float = 1.0
## T5 (sim_day7): on Thường he decides faster than on Day 5 (a shorter think; his HP, tells, damage and the phases'
## cooldowns stay Day 5's); Dễ keeps Day 5's pace.
const KATANA_PACE: Dictionary = {"think": Vector2(0.4, 0.9)}

var duel: SwordDuel
var card: StoryVillainCard = null
var pts: Dictionary = {}
var guide: BasementGuide = null


func setup(r: Node3D, b: Dictionary, o: Dictionary = {}) -> void:
	super.setup(r, b, o)
	pts = opts.get("points", {})


func _start() -> void:
	hide_top_panel()
	if pts.has("start"):
		teleport_player(pts["start"], float(pts.get("start_yaw", 0.0)))
	duel = SwordDuel.new()
	duel.name = "Duel"
	add_child(duel)
	var o: Dictionary = {"roam": roam, "start_line": START_LINE, "seed": int(opts.get("seed", 5)),
		"boss": {"label": "Lê Minh Za Mẫn", "body_fn": func(_look: Dictionary) -> Node3D: return StoryCast.build("za_man"),
			"hp_scale": float(Difficulty.pick(SwordData.HP_SCALE, SwordData.HP_SCALE_EASY)) * KATANA_HP_K,
			"stats": {} if Difficulty.easy else KATANA_PACE.duplicate()}}
	if pts.has("boss_at"):
		o["at"] = pts["boss_at"]
	if pts.has("boss_yaw"):
		o["yaw"] = float(pts["boss_yaw"])
	duel.setup(o)
	duel.sprinkler_starts = 1                  # no sprinklers on this floor (the 50 % trigger runs once per run)
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	guide.hide_fn = func() -> bool: return duel == null or not is_instance_valid(duel) or duel.in_qte or card != null
	duel.won.connect(_on_won)
	duel.lost.connect(_on_lost)
	var sd: Node = StoryUtil.director()
	var flags: Dictionary = sd.get("flags") if sd else {}
	if bool(flags.get(CARD_FLAG, false)):
		duel.start()
		return
	duel.prepare()
	flags[CARD_FLAG] = true
	card = StoryVillainCard.show_for(self, CastD7.villain_data("za_man_back"), CastD7.card_len("za_man_back"))
	if bool(opts.get("manual_card", false)):
		card.manual = true
	card.finished.connect(func() -> void:
		card = null
		if state == "running" and duel:
			duel.start(), CONNECT_ONE_SHOT)


func _tick(_dt: float) -> void:
	if guide and duel and guide.extra != duel.boss:
		guide.watch_node(duel.boss)


func _on_won() -> void:
	finish({"phase": duel.phase, "qte_clean": duel.qte_clean})


func _on_lost() -> void:
	fail(T_DOWN)


func _reset() -> void:
	if duel:
		duel.retry()
		duel.sprinkler_starts = 1


func _cleanup() -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if duel and is_instance_valid(duel):
		duel.stop()
		duel.queue_free()
	duel = null
