# File: res://scripts/cine/timelines/cine_d0_exam.gd
# cine_d0_exam (15.600 s, spec A2-D10): Day 0, late morning, the campus courtyard outside the room 311 module, right after
# the Extra stage. Mr.T (the fictional lecturer, role mr_t) holds up the E1 photo: "Giỏi lắm {name}! Ảnh này thầy gửi Khảo
# thí ngay." (Wave 6, plan 2026-11-05-w6-cines T4: one line instead of two, the scene 18 -> 15.6 s); Phúc runs in late:
# "Ét o ét! Thi xong chưa?!" (ba-dum-tss); for 1.5 s a sheep-masked figure stands in a corridor opening behind them, then the next cut shows the opening empty; a deadpan tail (sad trombone) while Mr.T walks off.
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
	length = 15.6
	story_end = 15.6
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
	look("hero", 0.0, 6.4, "mr_t")
	key("mr_t", 0.0, MR_T, CineTimeline.face(MR_T, HERO))
	move("mr_t", 0.0, "hold_up")
	move("mr_t", 3.8, "idle", {"fade": 0.25})
	hold("mr_t", 0.0, 3.8, "photo", {"offset": Vector3(0.0, 0.05, -0.05), "rot": Vector3(-70.0, 0.0, 0.0)})
	look("mr_t", 0.0, 8.2, "hero")
	expr("mr_t", 0.6, "talk")
	expr("mr_t", 3.2, "happy")
	move("hero", 3.45, "victory")
	move("hero", 5.4, "idle", {"fade": 0.2})
	# Phúc runs in late
	key("phuc", 0.0, PHUC_FROM, CineTimeline.face(PHUC_FROM, HERO))
	key("phuc", 4.6, PHUC_FROM, CineTimeline.face(PHUC_FROM, HERO))
	key("phuc", 6.2, PHUC_AT, CineTimeline.face(PHUC_AT, HERO), {"mode": "out"})
	move("phuc", 0.0, "idle")
	move("phuc", 4.6, "jog")
	move("phuc", 6.2, "winded", {"fade": 0.15})
	move("phuc", 8.0, "idle", {"fade": 0.3})
	expr("phuc", 6.4, "surprised")
	look("hero", 6.4, 8.6, "phuc")
	look("mr_t", 8.2, 11.1, "phuc")
	expr("hero", 8.5, "happy")
	expr("phuc", 11.0, "talk")
	expr("hero", 12.2, "done")
	look("hero", 10.8, 15.6, "phuc")
	look("phuc", 8.0, 15.6, "hero")
	move("phuc", 12.6, "shrug", {"fade": 0.15})
	move("phuc", 13.8, "idle", {"fade": 0.3})
	move("hero", 14.1, "facepalm", {"fade": 0.15})
	# the sheep-masked figure (horror beat): 1.5 s, then gone
	key("sheep", 0.0, SHEEP, CineTimeline.face(SHEEP, HERO))
	move("sheep", 0.0, "idle")
	hold("sheep", 0.0, 15.6, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
	show("sheep", 0.0, false)
	show("sheep", 8.6, true)
	show("sheep", 10.1, false)
	# Mr.T leaves
	key("mr_t", 11.6, MR_T, CineTimeline.face(MR_T, HERO))
	key("mr_t", 11.95, MR_T, CineTimeline.face(MR_T, MR_T_EXIT))   # turns first, then walks off forwards
	key("mr_t", 15.2, MR_T_EXIT, CineTimeline.face(MR_T, MR_T_EXIT), {"mode": "in"})
	move("mr_t", 11.95, "walk", {"fade": 0.25})
	sfx_at(3.4, "success_fanfare", -7.0)
	sfx_at(8.1, "ba_dum_tss", -4.0)
	sfx_at(8.6, "metal_creak", -8.0)
	sfx_at(10.05, "static_burst", -12.0)
	sfx_at(14.0, "sad_trombone", -6.0)
	shot("S1", 0.0, "static", "two-shot from the side", {"pos": Vector3(3.0, 1.5, -0.6), "look": Vector3(0.0, 1.25, -0.65), "fov": 45.0})
	ots_shot("S2", 0.6, "hero", "mr_t", {"hand": 0.2, "look_y": 1.2})
	ots_shot("S3", 3.4, "mr_t", "hero", {"side": -1.0, "look_y": 1.2})
	shot("S4", 4.6, "static", "wide: Phúc runs in", {"pos": Vector3(5.0, 1.8, 3.5), "look": Vector3(2.5, 1.0, -0.6), "fov": 52.0})
	shot("S5", 7.2, "static", "three-shot", {"pos": Vector3(2.4, 1.6, -3.6), "look": Vector3(0.4, 1.2, -0.5), "fov": 48.0})
	shot("S6", 8.6, "static", "from the front past them: the figure in the opening", {"pos": Vector3(1.6, 1.6, -3.8), "look": Vector3(-1.4, 1.35, 3.6), "fov": 40.0})
	shot("S7", 10.15, "static", "same view: the opening is empty", {"pos": Vector3(1.55, 1.6, -3.75), "look": Vector3(-1.4, 1.35, 3.6), "fov": 40.0})
	shot("S8", 10.8, "static", "wide three-shot, deadpan tail", {"pos": Vector3(2.8, 1.6, -4.0), "look": Vector3(0.2, 1.1, -0.7), "fov": 50.0})
	sub(0.4, 3.0, "mr_t", StoryUtil.fmt("Giỏi lắm {name}! Ảnh này thầy gửi Khảo thí ngay."))
	sub(6.4, 1.7, "phuc", "Ét o ét! Thi xong chưa?!")
	sub(8.5, 1.5, "hero", "Xong lâu rồi mày ơi...")
	sub(11.0, 3.25, "phuc", "Thôi đi ăn mì đi, tao bao... à quên, tao hết tiền rồi.")
	joke(11.0, "Phúc offers noodles, then has no money (shrug, facepalm)")
	sub(14.3, 1.0, "hero", "...")
