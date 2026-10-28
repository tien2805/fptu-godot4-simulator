# File: res://scripts/cine/timelines/cine_d0_brief.gd
# cine_d0_brief (12.000 s, spec amendment A2-D17, story spec S-D15 / 8.4): the mission intro of d0_exam, played when [E] is
# pressed on the Phòng 311 marker; the Extra stage starts right after it (a retry from the fail card skips it). Morning, the
# courtyard in front of the room 311 module. Mr.T (the fictional lecturer, role mr_t): "{name}! Phòng 311 thiếu giám thị,
# em phụ thầy được không?" then "Thầy nghe đồn có tool tên 'Lọ Thần'. Thấy gì lạ thì chụp lại giúp thầy."; the protagonist
# nods; the camera pushes in on the room 311 door. No ramps (story = real). Stage: StoryRoam sets "at" (5 m into the
# courtyard from the module) and "yaw_deg" (-Z into the courtyard, so the module door is behind the actors at +Z).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.45, 0.0, 0.4)
const MR_T := Vector3(-0.55, 0.0, -0.7)
const DOOR := Vector3(0.0, 1.5, 5.6)


func build() -> void:
	slot = "cine_d0_brief"
	length = 12.0
	story_end = 12.0
	mood = "playful"
	fade_in = 0.5
	fade_out = 0.4
	stage = {"landmark": "campus_parking_center", "near": 40.0, "size": Vector2(10.0, 12.0), "tod": "morning"}
	actor("hero", StoryUtil.hero_opts({"preset": "player", "seed": 2805}), StoryUtil.hero_name(), Color("#F37021"))
	actor("mr_t", {"preset": "lecturer", "seed": 1995, "glasses": true}, "Mr.T", Color("#B98CFF"))
	key("hero", 0.0, HERO, CineTimeline.face(HERO, MR_T))
	move("hero", 0.0, "idle")
	look("hero", 0.0, 9.6, "mr_t")
	expr("hero", 1.0, "surprised")
	expr("hero", 4.0, "open")
	move("hero", 9.3, "nod")
	move("hero", 10.1, "idle", {"fade": 0.2})
	expr("hero", 9.3, "happy")
	look("hero", 10.0, 12.0, DOOR)
	move("mr_t", 0.4, "talk", {"fade": 0.2})
	move("mr_t", 4.8, "point", {"fade": 0.25})   # toward room 311
	move("mr_t", 7.2, "talk", {"fade": 0.25})
	move("mr_t", 10.2, "laugh", {"fade": 0.2})
	move("mr_t", 11.4, "idle", {"fade": 0.3})
	key("mr_t", 0.0, MR_T, CineTimeline.face(MR_T, HERO))
	move("mr_t", 0.0, "idle")
	look("mr_t", 0.0, 12.0, "hero")
	expr("mr_t", 0.4, "talk")
	expr("mr_t", 4.8, "talk")
	expr("mr_t", 9.3, "happy")
	sfx_at(9.8, "dun_dun_duun", -10.0)
	two_shot("S1", 0.0, "hero", "mr_t", {"side": -1.0, "push": 0.15, "look_y": 1.2})
	ots_shot("S2", 4.6, "hero", "mr_t", {"hand": 0.15, "look_y": 1.2})
	shot("S3", 9.0, "static", "close: the nod", {"pos": Vector3(-0.2, 1.55, -0.6), "look": Vector3(0.45, 1.5, 0.4), "fov": 40.0})
	shot("S4", 9.8, "dolly", "push-in on the room 311 door", {"from": Vector3(0.6, 1.6, -1.6), "to": Vector3(0.25, 1.65, 3.2), "look_from": DOOR, "look_to": DOOR, "fov": 44.0})
	sub(0.4, 4.3, "mr_t", StoryUtil.fmt("{name}! Phòng 311 thiếu giám thị, em phụ thầy được không?"))
	sub(4.8, 4.4, "mr_t", "Thầy nghe đồn có tool tên 'Lọ Thần'. Thấy gì lạ thì chụp lại giúp thầy.")
	sub(9.4, 2.2, "hero", "Dạ! ...Có được cộng điểm không thầy?")
	joke(9.4, "asks for bonus marks; Mr.T laughs it off")
