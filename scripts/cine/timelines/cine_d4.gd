# File: res://scripts/cine/timelines/cine_d4.gd
# cine_d4 (18.000 s, spec B-D7 beat 9, story spec Day 4 end cinematic "Dolly unmasked", mood eerie then deadpan): night,
# outside the main building's front lobby after the Night Building escape. Cừu Dolly is cornered against the lobby front
# by the protagonist and Linh; she pulls the sheep mask off (the same face as every clone), gives up and spills the proxy
# schedule (Thursday, second shift, rooms 311 and 402, twelve clones sitting the exams) and where the answers come from (a
# server under The Beverly tower, 10.13.0.7); Linh has recorded everything on her phone. Deadpan bleat at the end.
# No ramps (story = real). Music slot cine_d4: the owner's local file user://music/cine_d4.mp3 when present, else the
# synthesized default (eerie).
# Stage: explicit "at" in front of the front wing (plot u 77.5, v 8.5: the nearest clear 9 x 9 box to the lobby module), a
# carried lobby-front wall behind Dolly (opts "set": dropped with drop_set when staged at the real doors).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const DOLLY := Vector3(0.0, 0.0, -3.0)
const HERO_FROM := Vector3(-0.9, 0.0, 1.6)
const HERO := Vector3(-0.55, 0.0, -1.35)
const LINH_FROM := Vector3(1.4, 0.0, 1.9)
const LINH := Vector3(0.85, 0.0, -1.55)
const UNMASK: float = 3.8


func build() -> void:
	slot = "cine_d4"
	length = 18.0
	story_end = 18.0
	mood = "eerie"
	fade_in = 0.6
	fade_out = 0.8
	stage = {"landmark": "campus_main_gate", "at": CineTimeline.campus_at(Vector3(77.5, 0.0, 8.5)), "near": 26.0,
		"size": Vector2(9.0, 9.0), "tod": "night", "yaw_deg": 1.0, "fallback": "campus_parking_center",
		"exposure": 1.5, "ambient": 1.8}
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("linh", StoryCast.opts("linh"), StoryCast.speaker("linh"), StoryCast.color("linh"))
	actor("dolly", StoryCast.opts("dolly"), StoryCast.speaker("dolly"), StoryCast.color("dolly"))
	prop("lamp", "lamp", Vector3(-2.6, 0.0, -2.2), 0.0, {"energy": 2.2})
	# the lobby front she is cornered against (carried: the stage box must be empty; drop_set leaves it out)
	prop("wall", "lobby_wall", Vector3(0.0, 0.0, -3.45), 0.0, {"width": 7.0, "set": true})
	# the two walk in and stop at arm's length from her
	key("hero", 0.0, HERO_FROM, CineTimeline.face(HERO_FROM, HERO))
	key("hero", 1.7, HERO, CineTimeline.face(HERO, DOLLY), {"mode": "linear"})
	move("hero", 0.0, "walk")
	move("hero", 1.7, "fight_idle", {"fade": 0.25})
	move("hero", 6.9, "idle", {"fade": 0.3})
	look("hero", 1.0, 18.0, "dolly")
	expr("hero", 0.0, "angry")
	expr("hero", 4.4, "surprised")
	expr("hero", 7.1, "talk")
	expr("hero", 8.4, "open")
	expr("hero", 16.4, "done")
	key("linh", 0.0, LINH_FROM, CineTimeline.face(LINH_FROM, LINH))
	key("linh", 1.9, LINH, CineTimeline.face(LINH, DOLLY), {"mode": "linear"})
	move("linh", 0.0, "walk")
	move("linh", 1.9, "arms_crossed", {"fade": 0.25})
	move("linh", 11.6, "hold_up", {"fade": 0.3})   # her phone, recording
	hold("linh", 11.6, 18.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	look("linh", 1.2, 16.0, "dolly")
	look("linh", 16.2, 18.0, "hero")
	expr("linh", 1.8, "talk")
	expr("linh", 3.8, "angry")
	expr("linh", 16.3, "happy")
	# Dolly: cornered, masked; pulls the mask off (it leaves the head at the gesture's peak and stays in her hand)
	key("dolly", 0.0, DOLLY, CineTimeline.face(DOLLY, Vector3(0.0, 0.0, 1.0)))
	move("dolly", 0.0, "cornered")
	move("dolly", UNMASK, "mask_on", {"fade": 0.1})
	hold("dolly", 0.0, UNMASK + 0.45, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
	hold("dolly", UNMASK + 0.45, 18.0, "sheep_mask", {"offset": Vector3(0.0, -0.08, -0.06), "rot": Vector3(80.0, 0.0, 0.0)})
	move("dolly", UNMASK + 0.9, "cornered", {"fade": 0.2})
	move("dolly", 8.4, "talk", {"fade": 0.3})
	move("dolly", 16.3, "cornered", {"fade": 0.3})
	look("dolly", 0.0, 18.0, "hero")
	expr("dolly", UNMASK + 0.5, "surprised")
	expr("dolly", 4.6, "talk")
	expr("dolly", 7.2, "done")
	expr("dolly", 8.4, "talk")
	expr("dolly", 16.3, "done")
	sfx_at(0.2, "music_box", -12.0)
	sfx_at(UNMASK + 0.45, "record_scratch", -6.0)
	sfx_at(11.6, "phone_buzz", -12.0)
	sfx_at(17.2, "sad_trombone", -12.0)
	shot("S1", 0.0, "static", "wide: night outside the lobby, Dolly cornered, the protagonist and Linh close in",
		{"pos": Vector3(-3.4, 1.7, 1.2), "look": Vector3(0.1, 1.1, -1.8), "fov": 50.0})
	shot("S2", 3.6, "static", "close: Dolly pulls the sheep mask off",
		{"pos": Vector3(0.35, 1.6, -1.9), "look": Vector3(0.0, 1.5, -3.0), "fov": 38.0, "hand": 0.15})
	shot("S3", 6.9, "static", "side-on along the wall: the protagonist asks for the schedule, Dolly in profile",
		{"pos": Vector3(2.5, 1.6, -2.9), "look": Vector3(-0.3, 1.4, -1.6), "fov": 46.0})
	shot("S4", 8.4, "static", "close: Dolly spills the schedule and the server",
		{"pos": Vector3(-0.4, 1.58, -1.9), "look": Vector3(0.0, 1.5, -3.0), "fov": 36.0, "hand": 0.12})
	shot("S5", 16.2, "static", "medium: Linh, the phone recording, deadpan",
		{"pos": Vector3(0.15, 1.55, -0.6), "look": Vector3(0.85, 1.4, -1.55), "fov": 42.0})
	sub(1.8, 1.8, "linh", "Hết đường chạy rồi, Dolly.")
	sub(4.6, 2.3, "dolly", "Được rồi, được rồi! Tôi khai hết!")
	sub(7.1, 1.2, "hero", "Lịch thi hộ đâu?")
	sub(8.5, 3.8, "dolly", "Thứ Năm, ca hai, phòng 311 và 402. Mười hai đứa thi thay.")
	sub(12.5, 3.7, "dolly", "Đáp án đẩy về từ server dưới hầm The Beverly, 10.13.0.7.")
	sub(16.3, 1.3, "linh", "Ghi âm hết rồi nhé.")
