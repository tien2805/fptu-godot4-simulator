# File: res://scripts/story/StoryNightEscape.gd
# Day 4 night escape (spec B-D7 beat 7; scene res://scenes/story/StoryNightEscape.tscn): the story's wrapper around the
# Night Building level (scripts/horror/NightBuilding.gd, which must sit at the world origin, so it runs as its own scene
# instead of inside the FreeRoam city). StoryDirector.launch_horror_beat changes to this scene; it:
#   - builds NightBuilding with the protagonist and "Giảm hù dọa" from the story (catches auto-retry from the checkpoint,
#     the level's own fail / retry);
#   - records the player and the stalkers (CineReplayRecorder) and, on escaped(caught_count), lets the run go on
#     StoryStage.REPLAY_AFTER s, then plays the short replay seg_d4_escape;
#   - saves every catch at once (StoryDirector.note_horror_catch; a new run starts from the saved count, so quitting after
#     a catch does not give E5 back) and stops the roam music;
#   - shows the d4_escape results card (StoryRankCard, ranked on the catches; w5-complete), then
#   - reports StoryDirector.on_horror_result(caught_count): E5 only when the player was never caught, the beat completes
#     (autosave), story free roam resumes at the lobby marker's return spot.
# Esc opens the usual pause menu; leaving for the menu keeps the save at the marker (the beat restarts on Continue).
# test_opts (static, tests): NightBuilding opts merged over the story's, plus "manual_replay" and "go_roam" (false: stay).
class_name StoryNightEscape
extends Node3D

signal finished(caught_count: int)

static var test_opts: Dictionary = {}

var night: NightBuilding
var rec: CineReplayRecorder
var replay: CineReplay
var result_caught: int = -1
var reported: bool = false
## The d4_escape results card while it shows (w5-complete G1); the hand-off to the story waits for it to close.
var rank_card: StoryRankCard = null
var _opts: Dictionary = {}


func _ready() -> void:
	_opts = test_opts.duplicate()
	night = NightBuilding.new()
	night.name = "NightBuilding"
	var sd: Node = StoryUtil.director()
	var catches: int = int((sd.get("flags") as Dictionary).get("d4_catches", 0)) if sd and bool(sd.get("active")) else 0
	var o: Dictionary = {"protagonist": StoryUtil.hero_opts({"preset": "player", "rigged": true, "seed": 2805, "name": "PlayerModel"}),
		"seed": int(_opts.get("seed", randi())), "caught_count": catches}
	for k: Variant in _opts.keys():
		if String(k) in ["manual_replay", "go_roam"]:
			continue
		o[k] = _opts[k]
	night.setup(o)
	add_child(night)
	night.escaped.connect(_on_escaped)
	night.caught.connect(_on_caught)
	add_child(NightMusic.for_level(night))   # H-D9: the owner's night tracks follow stealth / tense / chase / hidden / escape
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method("music_stop"):
		fx.call("music_stop", true)
	_attach_recorder.call_deferred()


## After the level's deferred build: track the player and every stalker.
func _attach_recorder() -> void:
	if not is_inside_tree():
		return
	if night.state == "build" or night.player == null:
		_attach_recorder.call_deferred()
		return
	var nodes: Array = [night.player]
	for s: HorrorStalker in night.stalkers:
		nodes.append(s)
	rec = StoryStage.make_recorder(self, nodes)
	if night.hud:
		night.hud.toast("Dolly chạy vào tòa nhà rồi tắt cầu dao. Bầy nhân bản đang lùng sục!", 4.0)


## Every catch is saved at once (StoryDirector.note_horror_catch): quitting and continuing keeps the count (E5).
func _on_caught() -> void:
	var sd: Node = StoryUtil.director()
	if sd and bool(sd.get("active")):
		sd.call("note_horror_catch", night.caught_count)


func _on_escaped(caught_count: int) -> void:
	result_caught = caught_count
	if rec:
		rec.mark("blow")
	if night.hud:
		night.hud.toast("Thoát rồi! Không bị bắt lần nào: lấy được danh sách thi hộ của Dolly." if caught_count == 0
			else "Thoát rồi! Nhưng bị bắt %d lần, Dolly kịp giấu danh sách thi hộ." % caught_count, 4.0)
	var manual: bool = bool(_opts.get("manual_replay", false))
	var t := get_tree().create_timer(0.0 if manual else StoryStage.REPLAY_AFTER)
	t.timeout.connect(_play_replay)


func _nearest_stalker() -> Node3D:
	var best: Node3D = null
	var bd: float = INF
	for s: HorrorStalker in night.stalkers:
		var d: float = s.global_position.distance_squared_to(night.player.global_position)
		if d < bd:
			bd = d
			best = s
	return best


func _play_replay() -> void:
	if not is_inside_tree() or reported:
		return
	var ctx: Dictionary = StoryUtil.stage_context()
	var slot: String = String(ctx.get("replay", "seg_d4_escape"))
	replay = StoryStage.play_replay(self, rec, slot, night.player, _nearest_stalker(), {"manual": bool(_opts.get("manual_replay", false))})
	if replay == null:
		_report()
		return
	replay.finished.connect(_report, CONNECT_ONE_SHOT)


func _report() -> void:
	if reported:
		return
	reported = true
	replay = null
	night.release()
	rank_card = _make_rank_card()
	if rank_card == null:
		_hand_off()
		return
	add_child(rank_card)
	rank_card.closed.connect(_hand_off, CONNECT_ONE_SHOT)


## w5-complete (gap G1): the results card of d4_escape, ranked on the catches only (the count on_horror_result uses: this
## run's or a saved earlier one's, the larger); null without a running story, with StoryRankCard.skip_all or unranked.
func _make_rank_card() -> StoryRankCard:
	var sd: Node = StoryUtil.director()
	if StoryRankCard.skip_all or sd == null or not bool(sd.get("active")):
		return null
	var id: String = String(StoryUtil.stage_context().get("beat", sd.get("step")))
	var catches: int = maxi(result_caught, int((sd.get("flags") as Dictionary).get("d4_catches", 0)))
	var ev: Dictionary = StoryRank.evaluate(id, {"fails": catches})
	if ev.is_empty():
		return null
	var c: StoryRankCard = StoryRankCard.make(ev, String(StoryMissions.beat(id).get("title", "")), StoryRank.best(id))
	c.manual = bool(_opts.get("manual_replay", false))   # tests close it themselves (skip / step)
	return c


func _hand_off() -> void:
	rank_card = null
	finished.emit(result_caught)
	var sd: Node = StoryUtil.director()
	if sd and bool(sd.get("active")):
		sd.call("on_horror_result", result_caught, bool(_opts.get("go_roam", true)))
