# File: res://scripts/cine/timelines/end_f.gd
# end_f (22.000 s, story spec section 6, secret ending F "Học thật, đậu thật", plan 2026-11-01-w4-endings.md T1): the extra
# scene after ending A (end_a, ai_true_end). Morning on the campus courtyard: Mr.T hands the protagonist a big presentation
# board "HỌC BỔNG": "Ba màn học, ba hạng S. Học bổng toàn phần, em nhận đi." - "Học thật, đậu thật... đúng không thầy?" -
# "Đúng. Đó mới là khẩu hiệu thật." Behind them a patrol car, siren on: Lùm Văn Lọ, escorted by Chú Bảy, screams "Tôi có
# quen hiệu trưởng! Tôi có quen... ai đó!" - Chú Bảy: "Lên xe đi anh Lọ. Xe này không đậu hộ được đâu." - "KHÔNGGG!" A photo
# flash on the scholarship pose; the credits roll (17.6-22.0 s).
# No ramps (story = real). Music slot end_f (owner file "Celebration", else silence).
# Stage: CineTimeline.canteen_stage (campus courtyard, 14 x 10, morning; the end_a stage); the patrol car is carried.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(-0.8, 0.0, 0.6)
const MRT := Vector3(-0.8, 0.0, -0.75)
const CAR := Vector3(3.6, 0.0, -2.6)
const LO := Vector3(2.35, 0.0, -1.9)
const LO_IN := Vector3(3.1, 0.0, -2.1)
const BAY := Vector3(2.0, 0.0, -1.0)
const CREDITS_R: float = 17.6


func build() -> void:
	slot = "end_f"
	length = 22.0
	story_end = 22.0
	mood = "playful"
	fade_in = 0.6
	fade_out = 1.0
	stage = CineTimeline.canteen_stage(Vector2(14.0, 10.0), "morning")
	stage["exposure"] = 1.15
	var hero_name: String = StoryCast.speaker("hero")
	actor("hero", StoryCast.opts("hero"), hero_name, StoryCast.color("hero"))
	actor("mr_t", StoryCast.opts("mr_t"), StoryCast.speaker("mr_t"), StoryCast.color("mr_t"))
	actor("chu_bay", StoryCast.opts("chu_bay"), StoryCast.speaker("chu_bay"), StoryCast.color("chu_bay"))
	actor("lo", StoryEndings.van_lo_opts(), StoryEndings.VAN_LO_NAME, StoryEndings.VAN_LO_COLOR)
	prop("car", "police_car", CAR, 90.0, {"set": true, "door": true})
	# Mr.T hands the scholarship over
	key("mr_t", 0.0, MRT, CineTimeline.face(MRT, HERO))
	move("mr_t", 0.0, "tray_hold")
	hold("mr_t", 0.0, 4.6, "scholarship", {"mid": "Wrist.L", "offset": Vector3(0.0, 0.0, -0.22)})
	move("mr_t", 0.6, "talk", {"fade": 0.2})
	move("mr_t", 4.6, "idle", {"fade": 0.25})
	move("mr_t", 7.6, "talk", {"fade": 0.2})
	move("mr_t", 9.4, "fold_arms", {"fade": 0.3})
	look("mr_t", 0.0, 9.6, "hero")
	look("mr_t", 9.7, 16.6, "lo")
	look("mr_t", 16.7, story_end, Vector3(1.6, 1.4, 4.0))
	expr("mr_t", 0.0, "happy")
	key("hero", 0.0, HERO, CineTimeline.face(HERO, MRT))
	move("hero", 0.0, "idle")
	move("hero", 4.4, "tray_hold", {"fade": 0.2})
	hold("hero", 4.6, story_end, "scholarship", {"mid": "Wrist.L", "offset": Vector3(0.0, 0.0, -0.22)})
	move("hero", 5.2, "talk", {"fade": 0.2})
	move("hero", 7.2, "tray_hold", {"fade": 0.2})
	look("hero", 0.0, 9.6, "mr_t")
	look("hero", 9.7, 16.6, "lo")
	key("hero", 16.4, HERO, CineTimeline.face(HERO, MRT))
	key("hero", 16.8, HERO, CineTimeline.face(HERO, Vector3(1.6, 0.0, 4.0)))
	look("hero", 16.9, story_end, Vector3(1.6, 1.4, 4.0))
	expr("hero", 0.0, "surprised")
	expr("hero", 4.6, "happy")
	# Lùm Văn Lọ at the patrol car, Chú Bảy escorts him in
	key("lo", 0.0, LO, CineTimeline.face(LO, HERO))
	move("lo", 0.0, "cornered")
	move("lo", 9.8, "point", {"fade": 0.15})
	move("lo", 12.4, "cornered", {"fade": 0.2})
	key("lo", 15.0, LO, CineTimeline.face(LO, HERO))
	key("lo", 15.4, LO, CineTimeline.face(LO, LO_IN))
	key("lo", 16.2, LO_IN, CineTimeline.face(LO, LO_IN), {"mode": "out"})
	move("lo", 15.4, "walk", {"fade": 0.2})
	show("lo", 16.3, false)
	look("lo", 0.0, 15.2, "hero")
	expr("lo", 0.0, "angry")
	expr("lo", 9.8, "surprised")
	key("chu_bay", 0.0, BAY, CineTimeline.face(BAY, LO))
	move("chu_bay", 0.0, "fold_arms")
	move("chu_bay", 12.8, "talk", {"fade": 0.2})
	move("chu_bay", 15.2, "shove", {"fade": 0.1})
	move("chu_bay", 16.2, "fold_arms", {"fade": 0.3})
	look("chu_bay", 0.0, story_end, "lo")
	expr("chu_bay", 0.0, "done")
	sfx_at(4.6, "success_fanfare", -5.0)
	sfx_at(9.4, "alarm_siren", -14.0)
	sfx_at(15.8, "door_bang", -6.0)
	sfx_at(17.0, "applause", -7.0)
	fx_at(17.2, "flash", Vector3(1.6, 1.4, 3.2), {"power": 0.8})
	shot("S1", 0.0, "static", "wide: the courtyard in the morning, Mr.T holds a big HỌC BỔNG board, a patrol car behind",
		{"pos": Vector3(-3.6, 1.7, 3.2), "look": Vector3(0.4, 1.2, -1.2), "fov": 52.0})
	two_shot("S2", 0.5, "mr_t", "hero", {"side": 1.0, "look_y": 1.25})
	push_in("S3", 5.1, "hero", {"from": 2.5, "to": 2.1, "side_deg": -20.0, "look_y": 1.3})
	two_shot("S4", 7.5, "hero", "mr_t", {"side": -1.0, "look_y": 1.25})
	dutch_shot("S5", 9.7, "lo", {"side_deg": 25.0, "roll": 10.0})   # "Tôi có quen hiệu trưởng!"
	two_shot("S6", 12.7, "chu_bay", "lo", {"side": -1.0, "look_y": 1.3})
	shot("S7", 16.6, "static", "the photo: the protagonist and Mr.T with the scholarship board, a flash",
		{"pos": Vector3(1.6, 1.45, 3.4), "look": Vector3(-0.8, 1.25, 0.0), "fov": 44.0})
	sub(0.6, 3.0, "mr_t", "Ba màn học, ba hạng S. Học bổng toàn phần, em nhận đi.")
	sub(5.2, 2.2, "hero", "Học thật, đậu thật... đúng không thầy?")
	sub(7.6, 1.8, "mr_t", "Đúng. Đó mới là khẩu hiệu thật.")
	sub(9.9, 2.4, "lo", "Tôi có quen hiệu trưởng! Tôi có quen... ai đó!")
	sub(12.9, 2.4, "chu_bay", "Lên xe đi anh Lọ. Xe này không đậu hộ được đâu.")
	sub(15.6, 1.2, "lo", "KHÔNGGG!")
	joke(12.9, "Chú Bảy: 'Xe này không đậu hộ được đâu' (the cheat king gets no help passing)")
	card("screen", CREDITS_R, length - CREDITS_R, {"kind": "credits", "title": "KẾT F: HỌC THẬT, ĐẬU THẬT", "lines": [
		"%s: học bổng toàn phần." % hero_name, "Lùm Văn Lọ: học lại môn Pháp luật, ở nơi khác.", " ",
		"Kết bí mật. Cảm ơn đã chơi tới cùng."]})
