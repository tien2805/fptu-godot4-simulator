# File: res://scripts/story/missions/MissionDuel.gd
# Day 5 katana duel (spec C-D8 beat 9, C-D3 / C-D4): after "Từ chối", Lê Minh Za Mẫn draws the katana he bought online in
# the burning server room: SwordDuel (the player's Vovinam staff vs KatanaBoss, telegraphed patterns, phases at 66 / 33 %,
# the katana bends and snaps at 0). He stands staged (prepare) while his villain card "Lê Minh Za Mẫn - CTO · đang pivot"
# runs once (StoryVillainCard.show_for; flag zaman_card so a retry or a Continue does not show it again), then the duel
# starts. `won` = done (StoryBasement plays the beat's "after" seg_d5_boss, then E6 is granted with the beat); `lost` =
# "TOANG!" -> retry() = a fresh Za Mẫn, full HP.
# W3 (plan 2026-10-30-w3-day5.md T5 / T6): the sprinklers at 50 % (SwordDuel: the look on the host, steam at the level's
# first two fires) and the QTE finisher at 0 HP (SwordQTE through SwordDuel).
# opts: "points" (start, start_yaw, boss_at, boss_yaw), "level" (steam spots), "manual_card" (tests step `card`), "seed".
class_name MissionDuel
extends StoryMission

const T_DOWN: String = "Bị chém gục rồi!"
const START_LINE: String = "Bảo hành bảy ngày đó nha!"

var duel: SwordDuel
var card: StoryVillainCard = null
var pts: Dictionary = {}


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
			"hp_scale": float(Difficulty.pick(1.0, SwordData.HP_SCALE_EASY))}}
	if pts.has("boss_at"):
		o["at"] = pts["boss_at"]
	if pts.has("boss_yaw"):
		o["yaw"] = float(pts["boss_yaw"])
	var lv: Variant = opts.get("level", null)
	if lv is LairBasement:
		var st: Array = []
		for f: Array in LairBasement.FIRES.slice(0, 2):
			st.append((lv as LairBasement).world(f[0]))
		o["steam_at"] = st                     # W3 T5: steam where the sprinklers meet the burning racks
	duel.setup(o)
	duel.won.connect(_on_won)
	duel.lost.connect(_on_lost)
	var sd: Node = StoryUtil.director()
	var seen: bool = sd != null and bool((sd.get("flags") as Dictionary).get("zaman_card", false))
	if seen:
		duel.start()
		return
	duel.prepare()
	if sd:
		(sd.get("flags") as Dictionary)["zaman_card"] = true
	card = StoryVillainCard.show_for(self, StoryCast.villain_data("za_man"), StoryCast.card_len("za_man"))
	if bool(opts.get("manual_card", false)):
		card.manual = true
	card.finished.connect(func() -> void:
		card = null
		if state == "running" and duel:
			duel.start(), CONNECT_ONE_SHOT)


func _on_won() -> void:
	finish({"phase": duel.phase, "qte_clean": duel.qte_clean})


func _on_lost() -> void:
	fail(T_DOWN)


func _reset() -> void:
	if duel:
		duel.retry()


func _cleanup() -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if duel and is_instance_valid(duel):
		duel.stop()
		duel.queue_free()
	duel = null
