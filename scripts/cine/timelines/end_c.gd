# File: res://scripts/cine/timelines/end_c.gd
# end_c (26.000 s, spec C-D8 choice 2 "accept", ending C "Kẻ phản diện mới"): dark comedy. A keynote stage at night on the
# campus courtyard, the big screen reads "LỌ THẦN 10.0". The protagonist, now in Za Mẫn's style (black turtleneck, round
# glasses), walks on as CEO to an audience of mannequins in smart glasses that clap on cue: "Xin chào. Tôi là {name}, CEO
# Lọ Thần 10.0." - "Thi hộ bằng AI. Đậu hay rớt... đều không hoàn tiền." Phúc in the front row, smart glasses on, applauds
# with dead eyes: "Tuyệt vời... tuyệt vời...". Za Mẫn, demoted, brings the coffee: "Sếp ơi, server lại cháy." - "Ổn mà, mọi
# thứ vẫn ổn." A smug bow; the credits roll (StoryScreenCard "credits", 17.0-22.0 s). After the credits (Wave 6, plan
# 2026-11-05-w6-cines T5, 22.0-26.0 s): Phúc takes the smart glasses off, sees the hall full of mannequins: "Ủa... sao
# toàn ma-nơ-canh vậy?", and puts them straight back on: "Thôi, đeo lại cho lành." (ba-dum-tss).
# No ramps (story = real). Music slot end_c (owner file "Money, Money, Money", else silence).
# Stage: CineTimeline.canteen_stage (campus courtyard, 14 x 10); the keynote set is carried (set dressing: drop_set inside
# a real hall), the mannequin audience stays.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const STAGE_Y: float = 0.45
const HERO_FROM := Vector3(-3.3, STAGE_Y, -2.0)
const HERO := Vector3(0.0, STAGE_Y, -2.0)
const ZA_FROM := Vector3(-3.6, STAGE_Y, -2.4)
const ZA := Vector3(-0.85, STAGE_Y, -2.15)
const PHUC := Vector3(3.75, 0.0, 0.75)
const CREDITS_R: float = 17.0
const CREDITS_END: float = 22.0
const OFF_R: float = 22.45   # the glasses come off (the peak of the first mask_on)
const ON_R: float = 24.35    # and go back on (the peak of the second)


func build() -> void:
	slot = "end_c"
	length = 26.0
	story_end = 26.0
	mood = "playful"
	fade_in = 0.8
	fade_out = 1.0
	stage = CineTimeline.canteen_stage(Vector2(14.0, 10.0), "night")
	stage["exposure"] = 1.3
	stage["ambient"] = 1.4
	var hero_name: String = StoryCast.speaker("hero")
	actor("hero", StoryCast.opts("hero", {"shirt_color": StoryCast.ZA_BLACK, "trousers_color": Color("#22232A")}), hero_name, StoryCast.color("hero"))
	actor("za", StoryCast.opts("za_man"), StoryCast.speaker("za_man"), StoryCast.color("za_man"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	StoryCast.dress(self, "za", "za_man")
	# the new villain: Za Mẫn's turtleneck and round glasses
	hold("hero", 0.0, story_end, "turtleneck", {"bone": "Neck"})
	hold("hero", 0.0, story_end, "round_glasses", {"bone": "Head", "offset": Vector3(0.0, StoryCast.EYE_UP, StoryCast.EYE_FRONT)})
	var phuc_eyes: Dictionary = {"bone": "Head", "offset": Vector3(0.0, StoryCast.EYE_UP, StoryCast.EYE_FRONT - 0.005)}
	hold("phuc", 0.0, OFF_R, "glasses", phuc_eyes)
	hold("phuc", OFF_R, ON_R, "glasses", {"bone": "Wrist.R", "offset": Vector3(0.0, 0.0, -0.06)})
	hold("phuc", ON_R, story_end, "glasses", phuc_eyes)
	prop("keynote", "keynote", Vector3(0.0, 0.0, -2.6), 180.0, {"set": true})
	prop("crowd", "mannequins", Vector3(0.0, 0.0, 0.6), 0.0, {"anim": true, "cols": 12, "rows": 6, "dx": 0.55, "dz": 0.6,
		"claps": [[3.1, 5.6], [9.8, 12.2], [16.5, 19.0]]})
	# the protagonist walks on, presents, takes the coffee line, bows
	key("hero", 0.0, HERO_FROM, -90.0)
	key("hero", 2.5, HERO, -90.0, {"mode": "out"})
	key("hero", 3.0, HERO, 180.0)
	move("hero", 0.0, "walk")
	move("hero", 2.5, "idle", {"fade": 0.25})
	move("hero", 3.2, "present", {"fade": 0.3})
	move("hero", 12.3, "idle", {"fade": 0.3})
	key("hero", 12.4, HERO, 180.0)
	key("hero", 12.9, HERO, CineTimeline.face(HERO, ZA))
	look("hero", 12.6, 16.0, "za")
	key("hero", 16.0, HERO, CineTimeline.face(HERO, ZA))
	key("hero", 16.4, HERO, 180.0)
	move("hero", 16.4, "bow_ceo", {"fade": 0.15})
	move("hero", 18.0, "present", {"fade": 0.4})
	expr("hero", 0.0, "open")
	expr("hero", 3.2, "happy")
	expr("hero", 12.9, "done")
	expr("hero", 16.4, "happy")
	# Za Mẫn, demoted to coffee duty
	show("za", 0.0, false)
	show("za", 12.2, true)
	var y_in: float = CineTimeline.face(ZA_FROM, ZA)
	key("za", 12.2, ZA_FROM, y_in)
	key("za", 13.4, ZA, y_in, {"mode": "out"})
	key("za", 13.7, ZA, CineTimeline.face(ZA, HERO))
	move("za", 12.2, "walk")
	move("za", 13.4, "sip", {"fade": 0.25})
	hold("za", 12.2, story_end, "coffee_cup", {"offset": Vector3(0.0, 0.02, -0.04)})
	look("za", 13.4, story_end, "hero")
	expr("za", 12.2, "done")
	# Phúc in the front row, smart glasses on
	key("phuc", 0.0, PHUC, 0.0)
	move("phuc", 0.0, "idle")
	move("phuc", 10.0, "nod", {"fade": 0.2})
	move("phuc", 10.8, "nod", {"fade": 0.1})
	move("phuc", 11.6, "idle", {"fade": 0.2})
	look("phuc", 0.0, 22.4, "hero")
	expr("phuc", 0.0, "done")
	# after the credits: the glasses off, a look around the mannequin rows, the glasses back on
	move("phuc", 22.0, "mask_on", {"fade": 0.1})
	move("phuc", 22.9, "idle", {"fade": 0.2})
	look("phuc", 22.5, 23.2, Vector3(2.4, 1.1, 1.9))
	look("phuc", 23.2, 23.9, Vector3(1.2, 1.1, 0.9))
	expr("phuc", 22.5, "surprised")
	move("phuc", 23.9, "mask_on", {"fade": 0.1})
	move("phuc", 24.8, "idle", {"fade": 0.2})
	look("phuc", 23.9, story_end, "hero")
	expr("phuc", 24.4, "done")
	sfx_at(3.1, "applause", -6.0)
	sfx_at(9.8, "applause", -7.0)
	sfx_at(16.5, "applause", -5.0)
	sfx_at(16.9, "dun_dun_duun", -6.0)
	sfx_at(OFF_R + 0.05, "freeze_tick", -10.0)
	sfx_at(25.2, "ba_dum_tss", -6.0)
	shot("S1", 0.0, "static", "wide: a keynote stage at night, LỌ THẦN 10.0 on the screen, an audience of mannequins",
		{"pos": Vector3(4.6, 2.2, 4.6), "look": Vector3(-0.4, 1.4, -2.0), "fov": 54.0})
	push_in("S2", 3.25, "hero", {"from": 2.9, "to": 2.3, "side_deg": 15.0, "look_y": 1.2})   # Q5: the CEO
	shot("S3", 6.5, "static", "reverse over the stage: rows of mannequins, red LEDs, clapping on cue",
		{"pos": Vector3(-1.6, 2.3, -1.4), "look": Vector3(0.4, 1.2, 2.4), "fov": 56.0})
	shot("S4", 10.1, "static", "close: Phúc in smart glasses, dead eyes, \"Tuyệt vời...\"",
		{"pos": Vector3(3.45, 1.55, -0.35), "look": Vector3(3.75, 1.5, 0.75), "fov": 38.0})
	two_shot("S5", 12.4, "hero", "za", {"side": -1.0, "look_y": 1.2})   # "Sếp ơi, server lại cháy."
	hero_shot("S6", 14.4, "hero", {"side_deg": 20.0, "dist": 2.4})   # "Ổn mà, mọi thứ vẫn ổn."
	shot("S7", 16.2, "dolly", "wide pull back: the smug bow, applause; the credits roll",
		{"from": Vector3(2.2, 2.0, 2.2), "to": Vector3(3.4, 2.6, 4.4), "look_from": Vector3(0.0, 1.5, -2.0), "look_to": Vector3(0.0, 1.5, -1.8),
		"fov": 50.0})
	push_in("S8", CREDITS_END, "phuc", {"from": 2.8, "to": 2.3, "side_deg": 25.0, "look_y": 1.3, "hand": 0.12})   # after the credits
	sub(3.4, 3.25, "hero", "Xin chào. Tôi là %s, CEO Lọ Thần 10.0." % hero_name)
	sub(6.7, 3.1, "hero", "Thi hộ bằng AI. Đậu hay rớt... đều không hoàn tiền.")
	joke(6.7, "the CEO pitch: pass or fail, no refunds")
	sub(10.3, 1.6, "phuc", "Tuyệt vời... tuyệt vời...")
	sub(12.6, 1.6, "za", "Sếp ơi, server lại cháy.")
	sub(14.5, 1.5, "hero", "Ổn mà, mọi thứ vẫn ổn.")
	sub(22.5, 1.85, "phuc", "Ủa... sao toàn ma-nơ-canh vậy?")
	sub(24.45, 1.45, "phuc", "Thôi, đeo lại cho lành.")
	joke(22.5, "after the credits: Phúc takes the glasses off, sees only mannequins, puts them back on")
	card("screen", CREDITS_R, CREDITS_END - CREDITS_R, {"kind": "credits", "title": "KẾT C: KẺ PHẢN DIỆN MỚI", "lines": [
		"%s nhận 0,01%% cổ phần Lọ Thần." % hero_name, "Án đình chỉ: đã xoá.", "Lương tâm: đang bảo trì.", "Phúc: vẫn đeo kính.",
		"Za Mẫn: đi pha cà phê.", "Mr.T: đang soạn email.", "Trà Sữa Lọ: vẫn mở cửa.",
		"Cảm ơn đã chơi FPTU Student Simulator.", "Chọn cảnh trong menu để chơi lại Ngày 5."]})
