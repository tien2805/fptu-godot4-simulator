# File: res://scripts/story/missions/MissionBikeChase.gd
# Day 2 bike chase "Tokyo Drift" (spec 2026-10-27 D2X-1 to D2X-7; parents C-D6 beat 3, C-D1): BikeChase on the Stage 1 real
# route (md.route_points(0.0)) from the Hải Đăng straight by Anh Duy's corner at BE6 (START_S) to END_PAST_M past the
# middle of the Rạch Hầm bridge (~2.4 km, about 2 minutes), where the horror beat and the duel follow.
#   Speed: BikeCombatData.CHASE_PROFILE (100 km/h, 110 in a slipstream), nitro on (agent B's PlayerBike interface).
#   Music: the chase track `mission_bike_chase` (the owner's Tokyo Drift) starts with NO crossfade on the chase's first
#     frame (warmed ahead by StoryRoam and here); the film opening's drop (OPEN_DROP_S = the beat drop at 4.15 s) follows its
#     playback position (music_pos), a real-time timer without a file. Wave 3 (after the Sói Xám cameo) crossfades to
#     `mission_bike_chase_b` when the owner has that file. The replay after the last fall has no slot of its own, so the
#     song never restarts under it.
#   Waves: BikeChase.day2_waves() / day2_wave_opts() (14 vehicles: riders, sticks, throwers, heavies, the pickup), the set
#     pieces BikeCombatData.DAY2_SET_PIECES, the cameo (StoryCast "soi_xam" on a scripted bike; his villain card moved here
#     from MissionBridge: StoryVillainCard over a freeze frame).
#   Memes: the start line "Tới công chuyện luôn!" (during the opening) and the win line "Đỉnh nóc kịch trần bay phấp phới".
#   `won` (also when bikers left ride off at the bridge) = done; `lost` (stability 0, knocked off, the barrier) = "TOANG!"
#   -> retry() at the wave checkpoint, the chase track resumed where it was (mounting switches FreeRoam to its roam track). The chase is stopped and freed on the win: the downed riders are cleared behind the
#   next beat's fade.
# opts (tests): manual_replay (the replay is stepped by the test), manual_card (the cameo card is stepped), seed.
class_name MissionBikeChase
extends StoryMission

const START_S: float = 64.0
const END_PAST_M: float = 30.0
const SLOT: String = "mission_bike_chase"
const SLOT_B: String = "mission_bike_chase_b"
const T_KNOCKED: String = "Bị đạp văng khỏi xe rồi!"

var chase: BikeChase
var route: BikeRoute
var card: StoryVillainCard = null
var music_b: bool = false
var music_at: float = -1.0                # where the chase track was at the knock-off (THỬ LẠI resumes it there)


## The Day 2 route: the Stage 1 real route (BE6 -> FPTU), its Rạch Hầm bridge distance set (~2389 m).
static func day2_route(md: MapData) -> BikeRoute:
	if md == null:
		return null
	var r: BikeRoute = BikeRoute.from_points(md.route_points(0.0))
	if not r.valid():
		return null
	r.bridge_s = BikeRoute.find_bridge_s(md, r)
	return r


func _start() -> void:
	hide_top_panel()
	LookPresets.apply("tokyo_drift", roam)   # Q3 look (popped in _cleanup)
	var md: MapData = roam.get("md") if roam else null
	route = day2_route(md)
	MusicDirector.warm([SLOT, SLOT_B])
	chase = BikeChase.new()
	chase.name = "Chase"
	add_child(chase)
	var o: Dictionary = {"roam": roam, "route": route, "start_line": BikeCombatData.T_START_D2, "win_line": BikeCombatData.T_WIN_D2,
		"replay_slot": "", "manual_replay": bool(opts.get("manual_replay", false)), "seed": int(opts.get("seed", 2)),
		"profile": BikeCombatData.CHASE_PROFILE, "nitro": true, "start_speed": BikeCombatData.START_SPEED_D2,
		"opening": {"drop_s": BikeCombatData.OPEN_DROP_S, "scale": BikeCombatData.OPEN_SCALE}, "music_pos_fn": music_pos,
		"set_pieces": BikeCombatData.DAY2_SET_PIECES, "waves": BikeChase.day2_waves(), "wave_opts": BikeChase.day2_wave_opts(),
		"cameo": {"s": BikeCombatData.CAMEO_S, "force_s": BikeCombatData.CAMEO_FORCE_S, "body_fn": _soi_body, "card_fn": _show_card}}
	if route:
		o["start_s"] = START_S
		if route.bridge_s >= 0.0:
			o["end_at_s"] = route.bridge_s + END_PAST_M
	chase.setup(o)
	chase.won.connect(_on_won)
	chase.lost.connect(_on_lost)
	chase.wave_started.connect(_on_wave_started)
	chase.start()                             # (mounting the bike switches FreeRoam to its roam track ...)
	_music(SLOT, 0.0)                         # ... so the chase track starts after it, with no fade-in: the drop rides on it
	radio("Ok e, a ping vị trí Bầy Sói lên map r, cứ bám route ra cầu Rạch Hầm nhé.", "Đuổi theo tụi nó tới cầu Rạch Hầm.")


## The chase track's playback position in seconds (the opening's drop), -1 when it is not playing (no owner file).
func music_pos() -> float:
	var md: MusicDirector = _director()
	if md == null or md.slot != SLOT or md.players.is_empty():
		return -1.0
	var p: AudioStreamPlayer = md.players[md.cur]
	if p.stream == null or not p.playing or md.player_slots[md.cur] != SLOT:
		return -1.0
	return maxf(0.0, p.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())


func _director() -> MusicDirector:
	var fx: Node = get_node_or_null("/root/GameFX")
	return fx.get("music") as MusicDirector if fx else null


func _music(slot: String, fade: float) -> void:
	var md: MusicDirector = _director()
	if md:
		md.play(slot, fade)


## Wave 3 (after the cameo): the owner's second chase track when there is one (else Tokyo Drift goes on).
func _on_wave_started(i: int) -> void:
	if bool(chase.wave_opt(i, "after_cameo", false)) and MusicDirector.slot_file(SLOT_B) != "":
		music_b = true
		_music(SLOT_B, MusicDirector.CROSSFADE)


## Sói Xám's look on the cameo bike (his StoryCast body riding).
func _soi_body(_look: Dictionary) -> Node3D:
	return StoryCast.build("soi_xam", {"clip": "ride"})


## The cameo's villain card over a freeze frame (his first appearance; MissionBridge no longer shows it).
func _show_card(done: Callable) -> void:
	card = StoryVillainCard.show_for(self, StoryCast.villain_data("soi_xam"), StoryCast.card_len("soi_xam"))
	if bool(opts.get("manual_card", false)):
		card.manual = true
	card.finished.connect(func() -> void:
		card = null
		done.call(), CONNECT_ONE_SHOT)


func _on_won() -> void:
	finish({"downed": chase.downed_total, "escaped": chase.escaped, "takedowns": chase.takedowns})


func _on_lost() -> void:
	music_at = music_pos()
	fail(T_KNOCKED)


func _reset() -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if chase:
		chase.retry()
	_resume_music()


## THỬ LẠI gets off and back on the bike, and FreeRoam switches to its roam track each time: the chase track comes back at
## once, where it was (wave 3's track from its start).
func _resume_music() -> void:
	var md: MusicDirector = _director()
	if md == null:
		return
	var slot: String = SLOT_B if music_b else SLOT
	md.play(slot, 0.0)
	if slot == SLOT and music_at > 0.0 and md.current_stream() != null and md.player_slots[md.cur] == SLOT:
		md.players[md.cur].seek(music_at)


func _cleanup() -> void:
	LookPresets.restore(roam, "tokyo_drift")
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if chase and is_instance_valid(chase):
		chase.stop()
		chase.queue_free()
	chase = null


## The mission HUD stays hidden while BikeHUD shows the chase (the fail card and the radio still show).
func hud_visible() -> bool:
	return state in ["running", "failed"] and (chase == null or chase.replay == null)
