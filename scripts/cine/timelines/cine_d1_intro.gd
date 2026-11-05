# File: res://scripts/cine/timelines/cine_d1_intro.gd
# cine_d1_intro (14.000 s, spec B-D5 beat 2 / B-D8 mission intro, story spec 8.4): Day 1, night, just inside the campus main
# gate. Mr.T has a laptop open on a folding table by the guard booth and replays the parking CCTV: StoryScreenCard "cctv"
# (2.0-7.6 s real) shows a courier in a helmet handing a box ("hàng") to a student in the D1 parking. He asks the
# protagonist to stake out the parking tonight and photograph the handover. In the background Chú Bảy dozes on a stool with
# his shiba Lu (foreshadowing the corridor bonk). Q5 pass: the photo instruction moved to Mr.T's radio line in the stake-out
# (StoryRadio "d1_stakeout"); the joke beat is Chú Bảy talking in his sleep; helper shots (push-in, two-shot), the
# protagonist shrugs. No ramps (story = real). Music slot cine_d1_intro (owner file, else no music).
# Stage: explicit "at" just inside the main gate (plot u 12, v 11: the nearest clear 10 x 9 box, yaw 181); landmark fallback.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const TABLE := Vector3(0.0, 0.0, 0.0)
const LAPTOP := Vector3(-0.05, 0.75, 0.08)
const MR_T := Vector3(-0.45, 0.0, -0.72)
const HERO := Vector3(0.48, 0.0, -0.7)
const BAY := Vector3(-3.0, 0.0, -1.7)
const DOG := Vector3(-2.35, 0.0, -1.25)


func build() -> void:
	slot = "cine_d1_intro"
	length = 14.0
	story_end = 14.0
	mood = "eerie"
	fade_in = 0.5
	fade_out = 0.5
	stage = {"landmark": "campus_main_gate", "at": CineTimeline.campus_at(Vector3(12.0, 0.0, 11.0)), "near": 30.0,
		"size": Vector2(10.0, 9.0), "tod": "night", "yaw_deg": 181.0, "fallback": "campus_parking_center",
		"exposure": 1.5, "ambient": 1.8}
	for id: String in ["hero", "mr_t", "chu_bay"]:
		actor(id, StoryCast.opts(id), StoryCast.speaker(id), StoryCast.color(id))
	prop("table", "table", TABLE, 0.0, {"color": Color("#BFC4C9")})
	prop("laptop", "laptop", LAPTOP, 0.0, {"glow_at": 0.3})   # screen toward Mr.T and the protagonist (-Z side)
	prop("stool", "stool", BAY, 0.0)
	prop("dog", "shiba", DOG, CineTimeline.face(DOG, TABLE),{"anim": [[0.0, "idle"]]})
	# Mr.T and the protagonist stand at the -Z side of the table, facing the screen (+Z)
	key("mr_t", 0.0, MR_T, CineTimeline.face(MR_T, LAPTOP))
	move("mr_t", 0.0, "talk")
	move("mr_t", 1.6, "point", {"fade": 0.25})        # points at the screen while the CCTV plays
	move("mr_t", 7.8, "talk", {"fade": 0.3})
	look("mr_t", 0.0, 7.8, LAPTOP + Vector3(0.0, 0.1, 0.0))
	look("mr_t", 8.0, 14.0, "hero")
	expr("mr_t", 0.5, "talk")
	expr("mr_t", 3.6, "angry")
	expr("mr_t", 8.2, "talk")
	key("hero", 0.0, HERO, CineTimeline.face(HERO, LAPTOP))
	move("hero", 0.0, "idle")
	look("hero", 0.0, 7.4, LAPTOP + Vector3(0.0, 0.1, 0.0))
	look("hero", 7.6, 14.0, "mr_t")
	expr("hero", 0.0, "open")
	expr("hero", 4.2, "surprised")
	expr("hero", 9.0, "angry")
	move("hero", 7.3, "shrug", {"fade": 0.15})
	move("hero", 8.5, "idle", {"fade": 0.2})
	move("hero", 12.6, "nod", {"fade": 0.15})
	move("hero", 13.4, "idle", {"fade": 0.2})
	# Chú Bảy dozes on his stool by the booth, head down
	key("chu_bay", 0.0, BAY, CineTimeline.face(BAY, TABLE))
	move("chu_bay", 0.0, "sit_bench")
	expr("chu_bay", 0.0, "closed")
	sfx_at(0.3, "phone_buzz", -12.0)
	sfx_at(2.0, "static_burst", -14.0)
	sfx_at(3.35, "freeze_tick", -10.0)   # the zoom clicks in
	sfx_at(7.5, "static_burst", -16.0)
	sfx_at(10.6, "dun_dun_duun", -9.0)
	shot("S1", 0.0, "static", "wide from the side: Mr.T and the protagonist at the laptop by the gate, night",
		{"pos": Vector3(2.7, 1.6, -2.5), "look": Vector3(-0.1, 1.05, -0.4), "fov": 50.0})
	shot("S2", 1.6, "static", "over the laptop: both faces lit by the screen (the CCTV card plays over it)",
		{"pos": Vector3(0.05, 1.3, 0.95), "look": Vector3(0.0, 1.45, -0.72), "fov": 42.0, "hand": 0.15})
	push_in("S3", 7.6, "hero", {"from": 2.8, "to": 2.3, "side_deg": 35.0, "look_y": 1.2})
	two_shot("S4", 8.2, "hero", "mr_t", {"hand": 0.1, "look_y": 1.2})
	shot("S5", 12.4, "static", "wide: Chú Bảy dozing by the booth, Lu at his feet; the protagonist nods",
		{"pos": Vector3(1.4, 1.7, 3.2), "look": Vector3(-1.1, 0.9, -0.9), "fov": 52.0})
	# Wave 6 (plan 2026-11-05-w6-cines T4): the replay zooms 2.2x onto the hand-off (in 3.3-3.9 s, out 6.6-7.0 s)
	card("screen", 2.0, 5.6, {"kind": "cctv", "cam": "CAM 03", "place": "BÃI XE D1", "clock": "00:12:40",
		"zoom": [0.24, 0.34, 2.2, 0.82, 0.9], "focus": Vector2(0.49, 0.6)})
	sub(0.5, 3.0, "mr_t", "Em xem cái này. Camera bãi xe D1, tối qua.")
	sub(3.6, 3.0, "mr_t", "Shipper giao 'hàng' cho sinh viên lúc nửa đêm.")
	sub(6.8, 1.3, "hero", "Hàng gì vậy thầy?")
	sub(8.2, 2.4, "mr_t", "Tool đó. Tối nay em ra bãi xe canh.")
	sub(10.7, 2.8, "chu_bay", "Khò... hàng gì... chú cũng ký nhận...")
	joke(10.7, "Chú Bảy talks in his sleep by the booth")
