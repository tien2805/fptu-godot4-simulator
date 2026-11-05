# File: res://scripts/cine/timelines/cine_d7_intro.gd
# cine_d7_intro (13.000 s, plan 2026-11-01-w4-day7.md T1, the Day 7 mission intro): dawn at Anh Duy's corner by the BE6
# lobby (as cine_d5_intro). Anh Duy has the go-live time on his laptops: Lọ Academy pushes "Lọ Thần 10.0" onto the exam
# system at 08:00. Mr.T came down in his coat: two and a half hours. The protagonist asks the way; Anh Duy has hacked the
# tower's lift. Mr.T's joke: hold the lift door, he is old. Every jargon line of Anh Duy carries its "Dịch:" translation.
# No ramps (story = real). Music slot cine_d7_intro (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("duy_room", "dawn") (8 x 8; desk, laptops, lobby wall carried; the wall is dressing).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const DESK := Vector3(0.0, 0.0, 0.0)
const DUY := Vector3(0.0, 0.0, -0.72)
const HERO := Vector3(0.78, 0.0, -1.42)
const MRT := Vector3(-0.95, 0.0, -1.6)
const FLIP_R: float = 3.2   # the insert's clock flips to 08:00


func build() -> void:
	slot = "cine_d7_intro"
	length = 13.0
	story_end = 13.0
	mood = "tense"
	fade_in = 0.5
	fade_out = 0.5
	stage = CineTimeline.phase_c_stage("duy_room", "dawn")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("duy", StoryCast.opts("anh_duy"), StoryCast.speaker("anh_duy"), StoryCast.color("anh_duy"))
	actor("mrt", StoryCast.opts("mr_t"), StoryCast.speaker("mr_t"), StoryCast.color("mr_t"))
	StoryCast.dress(self, "duy", "anh_duy")
	prop("wall", "lobby_wall", Vector3(0.0, 0.0, 2.2), 180.0, {"set": true, "width": 7.0})
	prop("desk", "desk", DESK, 0.0)
	prop("chair", "stool", DUY + Vector3(0.0, 0.0, -0.05), 0.0)
	for i: int in 3:
		prop("laptop%d" % i, "laptop", Vector3(-0.48 + 0.48 * i, 0.75, 0.05 + 0.08 * absf(i - 1.0)), 18.0 * (i - 1.0), {"glow_at": 0.0})
	prop("can", "energy_drink", Vector3(0.62, 0.81, -0.12), 0.0)
	# Anh Duy at the laptops
	key("duy", 0.0, DUY, 180.0)
	move("duy", 0.0, "type_sit")
	look("duy", 0.0, 4.0, Vector3(0.0, 0.95, 0.1))
	look("duy", 4.0, 13.0, "hero")
	expr("duy", 0.0, "open")
	expr("duy", 8.0, "happy")
	# the protagonist over his shoulder, Mr.T beside
	key("hero", 0.0, HERO, CineTimeline.face(HERO, DESK + Vector3(0.0, 0.0, 0.3)))
	move("hero", 0.0, "arms_crossed")
	look("hero", 0.0, 4.2, Vector3(0.0, 0.95, 0.15))
	look("hero", 4.2, 6.9, "mrt")
	look("hero", 6.9, 13.0, "duy")
	expr("hero", 0.0, "open")
	expr("hero", 4.2, "angry")
	expr("hero", 11.6, "happy")
	key("mrt", 0.0, MRT, CineTimeline.face(MRT, HERO))
	move("mrt", 0.0, "idle")
	move("mrt", 4.1, "talk", {"fade": 0.3})
	move("mrt", 6.8, "arms_crossed", {"fade": 0.3})
	move("mrt", 11.3, "laugh", {"fade": 0.25})
	look("mrt", 0.0, 13.0, "hero")
	expr("mrt", 0.0, "open")
	expr("mrt", 11.3, "happy")
	sfx_at(0.3, "keyboard_clack", -10.0)
	sfx_at(FLIP_R, "freeze_tick", -8.0)
	sfx_at(FLIP_R, "dun_dun_duun", -12.0)
	sfx_at(12.3, "ba_dum_tss", -10.0)
	shot("S1", 0.0, "static", "close over the laptops: Anh Duy, the go-live countdown on three screens",
		{"pos": Vector3(0.22, 1.32, 0.62), "look": Vector3(0.0, 1.18, -0.72), "fov": 40.0, "hand": 0.15})
	# Wave 6 (plan 2026-11-05-w6-cines T4): an insert on the middle laptop, the go-live clock flips 07:59 -> 08:00
	shot("S1b", 2.2, "static", "insert over Anh Duy's right shoulder: the go-live clock on the middle laptop flips 07:59 -> 08:00",
		{"pos": Vector3(0.42, 1.45, -1.1), "look": Vector3(0.0, 1.0, 0.0), "fov": 42.0, "hand": 0.1})
	card("screen", 2.2, 1.7, {"kind": "clock", "title": "LỌ THẦN 10.0 · GIỜ G", "from": "07:59", "to": "08:00",
		"flip_u": (FLIP_R - 2.2) / 1.7})
	two_shot("S2", 3.9, "mrt", "hero", {"look_y": 1.3, "dist": 3.2})
	push_in("S3", 6.8, "hero", {"from": 2.6, "to": 2.2, "side_deg": 40.0, "look_y": 1.25, "hand": 0.12})
	two_shot("S4", 7.65, "duy", "hero", {"look_y": 1.05, "dist": 3.4})
	shot("S5", 11.2, "static", "wide: Mr.T laughs at his own joke, the dawn behind the lobby glass",
		{"pos": Vector3(2.4, 1.65, 1.9), "look": Vector3(-0.2, 1.1, -1.0), "fov": 50.0})
	sub(0.2, 3.88, "duy", "Lọ deploy tool lên hệ thống thi lúc 08:00.", "Dịch: 8 giờ tool chạy.")
	sub(4.1, 2.6, "mrt", "Em còn hai tiếng rưỡi. Thầy tin em.")
	sub(6.85, 0.8, "hero", "Tòa nào?")
	sub(7.7, 3.6, "duy", "Lọ Academy. A hack thang máy r.", "Dịch: Anh hack thang máy rồi.")
	sub(11.3, 1.7, "mrt", "Giữ thang máy, thầy già rồi.")
	joke(11.3, "Mr.T: hold the lift, I'm old")
