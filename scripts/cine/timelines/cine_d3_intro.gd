# File: res://scripts/cine/timelines/cine_d3_intro.gd
# cine_d3_intro (14.000 s, spec C-D7 beat 2, C-D9 mission intro): Day 3, night drive to the canal. The protagonist rides a
# scooter down the road toward the Rạch Hầm bridge (three passes along the 26 m stage, each cut hides the jump back), Anh Duy
# on the radio (StoryScreenCard "radio" in the upper left; every jargon line with its "Dịch:" translation): he tracks the
# GPS and can loop the yard's cameras for thirty seconds only. "Ba mươi giây?!" - "Ừ. Hên xui."
# No ramps (story = real). Music slot cine_d3_intro (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("drive") (7 x 26, -Z toward the bridge). Anh Duy is a hidden actor (his subtitle colour).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LANE_X: float = 1.0
const Z_FROM: float = 11.0
const Z_TO: float = -10.5
const RIDER_UP := Vector3(0.0, 0.3, 0.3)      # on the seat (as cine_d1)
const PASSES: Array = [[0.0, 4.6], [4.6, 9.3], [9.3, 14.0]]


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
	expr("hero", 8.8, "surprised")
	expr("hero", 11.6, "done")
	sfx_at(0.2, "engine_roar", -8.0)
	sfx_at(4.7, "engine_roar", -9.0)
	sfx_at(9.4, "engine_roar", -8.0)
	sfx_at(10.6, "ba_dum_tss", -12.0)
	shot("S1", 0.0, "dolly", "roadside wide: the scooter's headlight comes down the road at night",
		{"from": Vector3(-2.8, 1.25, -3.0), "to": Vector3(-2.8, 1.25, -3.6), "look_from": Vector3(1.0, 1.0, 7.0),
		"look_to": Vector3(1.0, 1.0, -9.0), "fov": 48.0})
	shot("S2", 4.6, "track", "side tracking close: the protagonist rides, Anh Duy on the radio",
		{"actor": "hero", "offset": Vector3(-1.7, 1.15, -0.4), "look": Vector3(0.0, 1.05, 0.0), "fov": 42.0, "hand": 0.3})
	shot("S3", 9.3, "track", "behind the scooter: the road ahead to the bridge",
		{"actor": "hero", "offset": Vector3(0.5, 1.5, 3.0), "look": Vector3(0.0, 0.9, -7.0), "fov": 50.0, "hand": 0.3})
	card("screen", 0.9, 12.4, {"kind": "radio", "sender": "Anh Duy"})
	sub(1.0, 2.6, "duy", "Tới đâu rồi? Anh track GPS mày nãy giờ.", "Dịch: Anh đang theo dõi mày trên bản đồ.")
	sub(3.8, 1.4, "hero", "Gần cầu Rạch Hầm rồi.")
	sub(5.4, 3.2, "duy", "Bến container có camera, anh loop feed được 30 giây.", "Dịch: Anh làm camera đứng hình được ba mươi giây thôi.")
	sub(8.8, 1.1, "hero", "Ba mươi giây?!")
	sub(10.2, 1.0, "duy", "Ừ. Hên xui.", "Dịch: Ừ. Hên xui.")
	sub(11.6, 1.3, "hero", "...Chạy lẹ thôi.")
