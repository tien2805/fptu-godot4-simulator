# File: res://scripts/story/missions/MissionDriftDuel.gd
# Day 2 race with Sói Xám, "đua + đánh" (Wave 2 Day 2 rework, plan 2026-10-29-w2-day2.md; the beat d2_drift between the
# bike chase and the bridge horror beat): a DriftDuel on "Rạch Hầm GP" (2 laps on real roads, first to the bridge wins).
# The duel runs the intro, the countdown, the race, its own quick retries after a loss (no fail card: back on the grid,
# or the lap 2 grid, in about 3.5 s) and the ending (his line, he rides down under the bridge, a fade); `ended` = done ->
# d2_bridge.
# Music (StoryRoam leaves it to this mission, SELF_MUSIC): with the owner's file for race_d2_drift, the track that plays
# fades out over the countdown (revs and ambience only) and race_d2_drift starts on GO with no crossfade (warmed while
# the chase ran); without the file the chase track mission_bike_chase keeps playing (started if nothing plays it, e.g.
# after Continue). drift_slot() / has_drift_track() tell which.
# opts (tests): seed, intro (false skips Sói Xám's intro line), props (false: no arches / pack / fireworks).
class_name MissionDriftDuel
extends StoryMission

const DRIFT_SLOT: String = "race_d2_drift"
const CHASE_SLOT: String = "mission_bike_chase"
const COUNTDOWN_FADE: float = 0.8         # share of the countdown the old track takes to fade out

## Tests: pretend the owner has no drift track (the fallback path on a machine that has the file).
static var force_no_track: bool = false

var duel: DriftDuel
var music_starts: int = 0
var music_fades: int = 0


## The owner has a file for the drift track (or a test stream stands in for it).
static func has_drift_track() -> bool:
	if force_no_track:
		return false
	return MusicDirector.test_streams.has(DRIFT_SLOT) or MusicDirector.slot_file(DRIFT_SLOT) != ""


## The slot the race plays: the drift track, else the chase track.
static func drift_slot() -> String:
	return DRIFT_SLOT if has_drift_track() else CHASE_SLOT


func _start() -> void:
	hide_top_panel()
	LookPresets.apply("tokyo_drift", roam)   # Q3 look (popped in _cleanup)
	MusicDirector.warm([DRIFT_SLOT, CHASE_SLOT])
	duel = DriftDuel.new()
	duel.name = "DriftDuel"
	add_child(duel)
	duel.setup({"roam": roam, "seed": int(opts.get("seed", 3131)), "intro": bool(opts.get("intro", true)),
		"props": bool(opts.get("props", true))})
	duel.countdown_started.connect(_on_countdown)
	duel.music_cue.connect(_on_music_cue)
	duel.ended.connect(_on_ended)
	duel.start()   # mounts the player when on foot (FreeRoam then asks for the roam track)
	if not has_drift_track():
		_chase_track()


## The duel is ridden: the player stays on the bike from the chase (no dismount, so the chase track is not swapped for
## the roam track on the way in).
func _off_bike() -> void:
	pass


func _on_countdown(_retry: bool) -> void:
	if not has_drift_track():
		return
	var md: Node = _director()
	if md:
		music_fades += 1
		md.set("fade_time", maxf(0.1, duel.countdown_len * COUNTDOWN_FADE))
		md.call("stop", true)


func _on_music_cue() -> void:
	if has_drift_track():
		music_starts += 1
		var md: Node = _director()
		if md:
			md.call("play", DRIFT_SLOT, 0.0)   # restarts on every GO: the first bar lands on the launch
	else:
		_chase_track()


## The fallback: the chase music goes on. Nothing changes while a chase slot (mission_bike_chase or its wave 3 track
## mission_bike_chase_b) already plays; otherwise (after Continue) mission_bike_chase starts.
func _chase_track() -> void:
	var md: Node = _director()
	if md and String(md.get("slot")).begins_with(CHASE_SLOT):
		return
	_music(CHASE_SLOT, DriftDuel.FADE_S)


func _music(slot: String, fade: float) -> void:
	var md: Node = _director()
	if md:
		md.call("play", slot, fade)


func _director() -> Node:
	var fx: Node = get_node_or_null("/root/GameFX") if is_inside_tree() else null
	return fx.get("music") if fx else null


func _on_ended() -> void:
	finish({"losses": duel.losses, "how": duel.win_how, "race_s": snappedf(duel.race_t, 0.1)})


func _reset() -> void:
	if duel:
		duel.retry()


func _cleanup() -> void:
	LookPresets.restore(roam, "tokyo_drift")
	if duel and is_instance_valid(duel):
		duel.stop()
		duel.queue_free()
	duel = null


## The mission HUD stays hidden (the duel has its own).
func hud_visible() -> bool:
	return false
