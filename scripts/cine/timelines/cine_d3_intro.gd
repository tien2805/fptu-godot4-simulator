# File: res://scripts/cine/timelines/cine_d3_intro.gd
# cine_d3_intro (14.000 s, spec C-D7 beat 2, C-D9 mission intro): Day 3, night drive to the canal. The protagonist rides a
# scooter down the road toward the Rạch Hầm bridge (three passes along the 26 m stage, each cut hides the jump back), Anh Duy
# on the radio (StoryScreenCard "radio" in the upper left; every jargon line with its "Dịch:" translation): he tracks the
# GPS and can loop the yard's cameras for thirty seconds only. "Ba mươi giây?!" - "Ừ. Hên xui."
# Wave 6 (plan 2026-11-05-w6-cines T2): six shots instead of three: a low headlight insert at 2.3, the push-in, the track
# behind the scooter at 7.6, a push-in on "Ba mươi giây?!" (9.95, the third pass starts there) with the clock card counting
# the thirty seconds down (StoryScreenCard "clock", upper right) and a tick per second, a low tracking shot to the bridge.
# No ramps (story = real). Music slot cine_d3_intro (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("drive") (7 x 26, -Z toward the bridge). Anh Duy is a hidden actor (his subtitle colour).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LANE_X: float = 1.0
const Z_FROM: float = 11.0
const Z_TO: float = -10.5
const RIDER_UP := Vector3(0.0, 0.3, 0.3)      # on the seat (as cine_d1)
const PASSES: Array = [[0.0, 4.6], [4.6, 9.95], [9.95, 14.0]]
const LOOP_R: float = 9.95   # "Ba mươi giây?!": the camera loop's countdown starts


func build() -> void:
	slot = "cine_d3_intro"
	length = 14.0
	story_end = 14.0
	mood = "punchy"
	fade_in = 0.6
	fade_out = 0.6
	stage = CineTimeline.phase_c_stage("drive")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("duy", StoryCast.opts("anh_duy"), StoryCast.speaker("anh_duy"), StoryCast.color("anh_duy"))
	show("duy", 0.0, false)
	key("duy", 0.0, Vector3(-3.0, 0.0, 12.5), 0.0)
	var path: Array = []
	for i: int in PASSES.size():
		var s0: float = float(PASSES[i][0]) + (0.0005 if i > 0 else 0.0)
		var s1: float = float(PASSES[i][1])
		var a := Vector3(LANE_X, 0.0, Z_FROM)
		var b := Vector3(LANE_X, 0.0, Z_TO)
		path.append([s0, a, Vector3.ZERO])
		path.append([s1, b, Vector3.ZERO])
		key("hero", s0, a + RIDER_UP, 0.0, {"mode": "linear"})
		key("hero", s1, b + RIDER_UP, 0.0, {"mode": "linear"})
	prop("scooter", "scooter", Vector3(LANE_X, 0.0, Z_FROM), 0.0, {"headlight": true, "path": path})
	move("hero", 0.0, "ride")
	look("hero", 0.0, 14.0, Vector3(LANE_X, 1.2, -30.0))
	expr("hero", 0.0, "open")
	expr("hero", 9.95, "surprised")
	expr("hero", 12.75, "done")
	sfx_at(0.2, "engine_roar", -8.0)
	sfx_at(4.7, "engine_roar", -9.0)
	sfx_at(10.05, "engine_roar", -8.0)
	sfx_at(11.4, "ba_dum_tss", -12.0)
	for i: int in 3:   # the loop's seconds tick away
		sfx_at(LOOP_R + 1.0 + float(i), "freeze_tick", -14.0)
	shot("S1", 0.0, "dolly", "roadside wide: the scooter's headlight comes down the road at night",
		{"from": Vector3(-2.8, 1.25, -3.0), "to": Vector3(-2.8, 1.25, -3.6), "look_from": Vector3(1.0, 1.0, 7.0),
		"look_to": Vector3(1.0, 1.0, -9.0), "fov": 48.0})
	shot("S2", 2.3, "track", "low insert: the headlight and the front wheel eating the road",
		{"actor": "hero", "offset": Vector3(0.5, 0.55, -2.4), "look": Vector3(0.0, 0.55, -1.0), "fov": 42.0, "hand": 0.35})
	push_in("S3", 4.6, "hero", {"from": 4.4, "to": 3.5, "side_deg": 20.0, "look_y": 1.1, "hand": 0.3})   # Q5: rides with the scooter
	shot("S4", 7.6, "track", "behind the scooter: the road ahead",
		{"actor": "hero", "offset": Vector3(0.5, 1.5, 3.0), "look": Vector3(0.0, 0.9, -7.0), "fov": 50.0, "hand": 0.3})
	push_in("S5", LOOP_R, "hero", {"from": 3.7, "to": 2.9, "side_deg": -15.0, "look_y": 0.98, "hand": 0.35})   # "Ba mươi giây?!"
	shot("S6", 11.6, "track", "low tracking beside the front wheel: the road to the bridge",
		{"actor": "hero", "offset": Vector3(-0.75, 0.2, -0.3), "look": Vector3(0.35, 0.55, -10.0), "fov": 52.0, "hand": 0.4})
	card("screen", 0.3, 12.45, {"kind": "radio", "sender": "Anh Duy"})
	card("screen", LOOP_R, 3.95, {"kind": "clock", "title": "CAMERA BẾN: LOOP", "count": 30})
	# Anh Duy's lines show with their Dịch line: timed for both (0.06 s per character of the two)
	sub(0.4, 3.75, "duy", "Tới đâu rồi? Anh track GPS mày.", "Dịch: Anh thấy mày trên bản đồ.")
	sub(4.25, 1.3, "hero", "Gần cầu Rạch Hầm rồi.")
	sub(5.65, 4.2, "duy", "Anh loop camera bến được 30 giây.", "Dịch: Camera đứng hình 30 giây thôi.")
	sub(9.95, 0.9, "hero", "Ba mươi giây?!")
	sub(10.95, 1.7, "duy", "Ừ. Hên xui.", "Dịch: Ừ. Hên xui.")
	joke(10.95, "the Dịch: line translates nothing: Ừ. Hên xui.")
	sub(12.75, 1.0, "hero", "...Chạy lẹ thôi.")
