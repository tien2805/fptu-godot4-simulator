# File: res://scripts/story/missions/MissionBikeChase.gd
# Day 2 bike chase (spec C-D6 beat 3, C-D1): BikeChase on the real Nguyễn Xiển road, run SOUTHBOUND on the reversed default
# route (Nguyễn Văn Tăng, the turn onto Nguyễn Xiển, then the Rạch Hầm bridge), from CHASE_M before the bridge to END_PAST_M
# past it, so the chase ends at the bridge where the horror beat and the duel follow. Two waves (BikeChase.day2_waves: 3 + 3
# Bầy Sói bikers in BikerEnemy's wolf-rider look: its LED eyes flash for the kick telegraph), the memes as the chase's
# start / win lines ("Tới công chuyện luôn!", "Đỉnh nóc kịch trần bay phấp phới"). BikeChase plays the short replay seg_d2_chase itself after the last fall; `won`
# (also when the bikers left run off at the bridge) = done; `lost` (stability 0, knocked off) = "TOANG!" -> retry() at the
# wave checkpoint. The chase is stopped and freed on the win: the downed riders are cleared behind the next beat's fade.
# opts (tests): manual_replay (the replay is stepped by the test), seed.
class_name MissionBikeChase
extends StoryMission

const CHASE_M: float = 850.0
const END_PAST_M: float = 30.0
const T_KNOCKED: String = "Bị đạp văng khỏi xe rồi!"

var chase: BikeChase
var route: BikeRoute


## The Day 2 route: Nguyễn Xiển's default route reversed (southbound, the bridge at about 1724 m), its bridge distance set.
static func day2_route(md: MapData) -> BikeRoute:
	var fwd: BikeRoute = BikeRoute.nguyen_xien(md) if md else null
	if fwd == null:
		return null
	var pts := PackedVector2Array()
	for i: int in range(fwd.pts.size() - 1, -1, -1):
		pts.append(fwd.pts[i])
	var r: BikeRoute = BikeRoute.from_points(pts)
	r.bridge_s = BikeRoute.find_bridge_s(md, r)
	return r


func _start() -> void:
	hide_top_panel()
	var md: MapData = roam.get("md") if roam else null
	route = day2_route(md)
	chase = BikeChase.new()
	chase.name = "Chase"
	add_child(chase)
	var waves: Array = BikeChase.day2_waves()   # BikerEnemy's own Bầy Sói rider look (wolf helmet, LED eyes, the ride clip)
	var o: Dictionary = {"roam": roam, "route": route, "start_line": BikeCombatData.T_START_D2, "win_line": BikeCombatData.T_WIN_D2,
		"replay_slot": String(beat.get("replay", "seg_d2_chase")), "manual_replay": bool(opts.get("manual_replay", false)),
		"seed": int(opts.get("seed", 2)), "waves": waves}
	if route and route.bridge_s >= 0.0:
		o["start_s"] = maxf(20.0, route.bridge_s - CHASE_M)
		o["end_at_s"] = route.bridge_s + END_PAST_M
	chase.setup(o)
	chase.won.connect(_on_won)
	chase.lost.connect(_on_lost)
	chase.start()
	radio("Ok e, a ping vị trí Bầy Sói lên map r, cứ bám route Nguyễn Xiển nhé.", "Đuổi theo tụi nó trên Nguyễn Xiển.")


func _on_won() -> void:
	finish({"downed": chase.downed_total, "escaped": chase.escaped})


func _on_lost() -> void:
	fail(T_KNOCKED)


func _reset() -> void:
	if chase:
		chase.retry()


func _cleanup() -> void:
	if chase and is_instance_valid(chase):
		chase.stop()
		chase.queue_free()
	chase = null


## The mission HUD stays hidden while BikeHUD shows the chase (the fail card and the radio still show).
func hud_visible() -> bool:
	return state in ["running", "failed"] and (chase == null or chase.replay == null)
