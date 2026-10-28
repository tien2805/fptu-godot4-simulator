# File: res://scripts/cine/timelines/cine_d0_exam.gd
# cine_d0_exam (18.000 s, spec A2-D10): Day 0, late morning, the campus courtyard outside the room 311 module, right after
# the Extra stage. Mr.T (the fictional lecturer, role mr_t) holds up the E1 photo: "Giỏi lắm em! Ảnh tai nghe này là bằng
# chứng rõ ràng."; Phúc runs in late: "Ét o ét! Thi xong chưa?!" (ba-dum-tss); for 1.5 s a sheep-masked figure stands in a
# corridor opening behind them, then the next cut shows the opening empty; a deadpan tail (sad trombone) while Mr.T walks off.
# No ramps (story = real). Stage: StoryRoam sets "at" (the courtyard point of the room 311 marker) and "yaw_deg" (the stage
# -Z faces away from the module, so the sheep's opening at +Z is the module side); fallback search near campus_parking_center.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 0.0)
const MR_T := Vector3(0.0, 0.0, -1.35)
const MR_T_EXIT := Vector3(-4.2, 0.0, -3.6)
const PHUC_FROM := Vector3(6.2, 0.0, -0.4)
const PHUC_AT := Vector3(1.15, 0.0, -0.55)
const SHEEP := Vector3(-3.4, 0.0, 5.4)   # clear of the hero's head from S6 / S7 (review A2-R3)


func build() -> void:
	slot = "cine_d0_exam"
	length = 18.0
	story_end = 18.0
	mood = "playful"
	fade_in = 0.5
	fade_out = 0.5
	stage = {"landmark": "campus_parking_center", "near": 40.0, "size": Vector2(13.0, 12.0), "tod": "morning"}
	actor("hero", StoryUtil.hero_opts({"preset": "player", "seed": 2805}), StoryUtil.hero_name(), Color("#F37021"))
	actor("mr_t", {"preset": "lecturer", "seed": 1995, "glasses": true}, "Mr.T", Color("#B98CFF"))
	actor("phuc", {"preset": "student_m", "seed": 77, "hair_style": "spiky"}, "Phúc", Color("#FF9A3C"))
	actor("sheep", {"preset": "casual", "seed": 6606}, "???", Color("#F4F1EA"))
	# hero and Mr.T face each other
	key("hero", 0.0, HERO, CineTimeline.face(HERO, MR_T))
	move("hero", 0.0, "idle")
	expr("hero", 1.2, "happy")
	look("hero", 0.0, 8.8, "mr_t")
	key("mr_t", 0.0, MR_T, CineTimeline.face(MR_T, HERO))
	move("mr_t", 0.0, "hold_up")
	move("mr_t", 6.2, "idle", {"fade": 0.25})
	hold("mr_t", 0.0, 6.2, "photo", {"offset": Vector3(0.0, 0.05, -0.05), "rot": Vector3(-70.0, 0.0, 0.0)})
	look("mr_t", 0.0, 10.6, "hero")
	expr("mr_t", 0.6, "talk")
	expr("mr_t", 3.4, "happy")
	expr("mr_t", 3.7, "talk")
	expr("mr_t", 5.6, "happy")
	move("hero", 5.8, "victory")
	move("hero", 7.8, "idle", {"fade": 0.2})
	# Phúc runs in late
	key("phuc", 0.0, PHUC_FROM, CineTimeline.face(PHUC_FROM, HERO))
	key("phuc", 7.0, PHUC_FROM, CineTimeline.face(PHUC_FROM, HERO))
	key("phuc", 8.6, PHUC_AT, CineTimeline.face(PHUC_AT, HERO), {"mode": "out"})
	move("phuc", 0.0, "idle")
	move("phuc", 7.0, "jog")
	move("phuc", 8.6, "winded", {"fade": 0.15})
	move("phuc", 10.4, "idle", {"fade": 0.3})
	expr("phuc", 8.8, "surprised")
	look("hero", 8.8, 11.0, "phuc")
	look("mr_t", 10.6, 13.5, "phuc")
	expr("hero", 10.9, "happy")
	expr("phuc", 13.4, "talk")
	expr("hero", 14.6, "done")
	look("hero", 13.2, 18.0, "phuc")
	look("phuc", 10.4, 18.0, "hero")
	move("phuc", 15.0, "shrug", {"fade": 0.15})
	move("phuc", 16.2, "idle", {"fade": 0.3})
	move("hero", 16.5, "facepalm", {"fade": 0.15})
	# the sheep-masked figure (horror beat): 1.5 s, then gone
	key("sheep", 0.0, SHEEP, CineTimeline.face(SHEEP, HERO))
	move("sheep", 0.0, "idle")
	hold("sheep", 0.0, 18.0, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
	show("sheep", 0.0, false)
	show("sheep", 11.0, true)
	show("sheep", 12.5, false)
	# Mr.T leaves
	key("mr_t", 14.0, MR_T, CineTimeline.face(MR_T, HERO))
	key("mr_t", 14.35, MR_T, CineTimeline.face(MR_T, MR_T_EXIT))   # turns first, then walks off forwards
	key("mr_t", 17.6, MR_T_EXIT, CineTimeline.face(MR_T, MR_T_EXIT), {"mode": "in"})
	move("mr_t", 14.35, "walk", {"fade": 0.25})
	sfx_at(3.4, "success_fanfare", -7.0)
	sfx_at(10.5, "ba_dum_tss", -4.0)
	sfx_at(11.0, "metal_creak", -8.0)
	sfx_at(12.45, "static_burst", -12.0)
	sfx_at(16.4, "sad_trombone", -6.0)
	shot("S1", 0.0, "static", "two-shot from the side", {"pos": Vector3(3.0, 1.5, -0.6), "look": Vector3(0.0, 1.25, -0.65), "fov": 45.0})
	ots_shot("S2", 0.6, "hero", "mr_t", {"hand": 0.2, "look_y": 1.2})
	ots_shot("S3", 3.6, "mr_t", "hero", {"side": -1.0, "look_y": 1.2})
	shot("S4", 7.0, "static", "wide: Phúc runs in", {"pos": Vector3(5.0, 1.8, 3.5), "look": Vector3(2.5, 1.0, -0.6), "fov": 52.0})
	shot("S5", 9.6, "static", "three-shot", {"pos": Vector3(2.4, 1.6, -3.6), "look": Vector3(0.4, 1.2, -0.5), "fov": 48.0})
	shot("S6", 11.0, "static", "from the front past them: the figure in the opening", {"pos": Vector3(1.6, 1.6, -3.8), "look": Vector3(-1.4, 1.35, 3.6), "fov": 40.0})
	shot("S7", 12.55, "static", "same view: the opening is empty", {"pos": Vector3(1.55, 1.6, -3.75), "look": Vector3(-1.4, 1.35, 3.6), "fov": 40.0})
	shot("S8", 13.2, "static", "wide three-shot, deadpan tail", {"pos": Vector3(2.8, 1.6, -4.0), "look": Vector3(0.2, 1.1, -0.7), "fov": 50.0})
	sub(0.4, 3.2, "mr_t", "Giỏi lắm em! Ảnh tai nghe này là bằng chứng rõ ràng.")
	sub(3.6, 3.4, "mr_t", StoryUtil.fmt("Thầy gửi Phòng Khảo thí ngay. Cảm ơn em, {name}."))
	sub(8.8, 1.7, "phuc", "Ét o ét! Thi xong chưa?!")
	sub(10.9, 1.5, "hero", "Xong lâu rồi mày ơi…")
	sub(13.4, 3.2, "phuc", "Thôi đi ăn mì đi, tao bao… à quên, tao hết tiền rồi.")
	joke(13.4, "Phúc offers noodles, then has no money (shrug, facepalm)")
	sub(16.7, 1.0, "hero", "…")
