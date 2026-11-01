# File: res://scripts/cine/timelines/end_e.gd
# end_e (24.000 s, story spec section 6, ending E "Còn cái nịt", plan 2026-11-01-w4-endings.md T1): expelled, credits over
# memes. Morning at the FPTU main gate: the protagonist walks out with a cardboard box; Chú Bảy takes the student card back:
# "Thẻ sinh viên đây con. Chú giữ lại nhé." - "Bảy ngày... mà bằng chứng không đủ." A gust (whoosh): the box drops, empty
# but for a belt; the protagonist holds it up: "Còn... cái nịt." (toang sting, sad trombone). Phúc jogs in: "Ít ra mày còn
# cái nịt! Tao mất cả cái nịt!" and gets a shiba-style bonk with stars. The meme credits roll (15.6-24.0 s).
# No ramps (story = real). Music slot end_e (owner file "Never Gonna Give You Up" for the credits, else silence).
# Stage: the cine_d1_intro stage by the campus main gate (10 x 9), in the morning.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO_FROM := Vector3(-0.4, 0.0, -2.8)
const HERO := Vector3(-0.2, 0.0, 0.2)
const BAY := Vector3(1.4, 0.0, 0.6)
const PHUC_FROM := Vector3(-4.2, 0.0, 1.4)
const PHUC := Vector3(-1.3, 0.0, 0.9)
const CREDITS_R: float = 15.6


func build() -> void:
	slot = "end_e"
	length = 24.0
	story_end = 24.0
	mood = "playful"
	fade_in = 0.8
	fade_out = 1.0
	stage = {"landmark": "campus_main_gate", "at": CineTimeline.campus_at(Vector3(12.0, 0.0, 11.0)), "near": 30.0,
		"size": Vector2(10.0, 9.0), "tod": "morning", "yaw_deg": 181.0, "fallback": "campus_parking_center"}
	var hero_name: String = StoryCast.speaker("hero")
	actor("hero", StoryCast.opts("hero"), hero_name, StoryCast.color("hero"))
	actor("chu_bay", StoryCast.opts("chu_bay"), StoryCast.speaker("chu_bay"), StoryCast.color("chu_bay"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	prop("box_ground", "box", HERO + Vector3(0.1, 0.16, -0.35), 25.0, {"show_at": 7.6})
	# the protagonist walks out with the box, hands the card over, drops the box, finds the belt
	key("hero", 0.0, HERO_FROM, CineTimeline.face(HERO_FROM, HERO))
	key("hero", 2.0, HERO, CineTimeline.face(HERO_FROM, HERO), {"mode": "out"})
	key("hero", 2.4, HERO, CineTimeline.face(HERO, BAY))
	move("hero", 0.0, "walk")
	move("hero", 2.0, "tray_hold", {"fade": 0.25})
	hold("hero", 0.0, 7.6, "box", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.05, -0.22)})
	look("hero", 2.4, 7.4, "chu_bay")
	move("hero", 5.0, "talk", {"fade": 0.2})
	move("hero", 7.6, "startled", {"fade": 0.1})
	key("hero", 8.0, HERO, CineTimeline.face(HERO, BAY))
	key("hero", 8.4, HERO, 0.0)
	move("hero", 8.2, "pickup", {"fade": 0.2})
	move("hero", 9.2, "hold_up", {"fade": 0.2})
	hold("hero", 9.0, story_end, "belt", {"offset": Vector3(0.0, 0.0, -0.04)})
	look("hero", 9.2, 11.6, HERO + Vector3(0.1, 1.4, -0.4))
	look("hero", 11.7, 16.0, "phuc")
	expr("hero", 0.0, "done")
	expr("hero", 7.6, "surprised")
	expr("hero", 9.4, "done")
	expr("hero", 12.6, "happy")
	# Chú Bảy at the gate
	key("chu_bay", 0.0, BAY, CineTimeline.face(BAY, HERO))
	move("chu_bay", 0.0, "idle")
	move("chu_bay", 2.4, "talk", {"fade": 0.2})
	move("chu_bay", 4.8, "nod", {"fade": 0.2})
	move("chu_bay", 5.8, "fold_arms", {"fade": 0.3})
	move("chu_bay", 14.4, "point", {"fade": 0.15})
	hold("chu_bay", 3.6, story_end, "photo", {"offset": Vector3(0.0, 0.05, -0.05), "rot": Vector3(-70.0, 0.0, 0.0)})
	look("chu_bay", 0.0, 13.0, "hero")
	look("chu_bay", 13.1, story_end, "phuc")
	expr("chu_bay", 0.0, "done")
	expr("chu_bay", 14.4, "angry")
	# Phúc jogs in, gets bonked
	show("phuc", 0.0, false)
	show("phuc", 11.2, true)
	key("phuc", 11.2, PHUC_FROM, CineTimeline.face(PHUC_FROM, PHUC))
	key("phuc", 12.4, PHUC, CineTimeline.face(PHUC_FROM, PHUC), {"mode": "out"})
	key("phuc", 12.7, PHUC, CineTimeline.face(PHUC, HERO))
	move("phuc", 11.2, "jog")
	move("phuc", 12.4, "talk", {"fade": 0.2})
	move("phuc", 14.8, "hit_head", {"fade": 0.05})
	move("phuc", 15.8, "head_shake", {"fade": 0.2})
	look("phuc", 12.4, story_end, "hero")
	expr("phuc", 11.2, "happy")
	expr("phuc", 14.8, "pain")
	sfx_at(3.6, "phone_buzz", -14.0)
	sfx_at(7.4, "whoosh_down", -3.0)
	sfx_at(7.6, "body_fall", -8.0)
	sfx_at(9.3, "toang_sting", -3.0)
	sfx_at(10.6, "sad_trombone", -5.0)
	sfx_at(14.8, "bonk", -2.0)
	fx_at(14.8, "stars", "phuc", {"until": 17.0})
	shot("S1", 0.0, "static", "wide: morning at the FPTU main gate, the protagonist walks out with a box",
		{"pos": Vector3(3.2, 1.7, 3.0), "look": Vector3(0.0, 1.0, -1.0), "fov": 50.0})
	two_shot("S2", 2.4, "chu_bay", "hero", {"side": 1.0, "look_y": 1.25})
	push_in("S3", 5.0, "hero", {"from": 2.6, "to": 2.1, "side_deg": -18.0, "look_y": 1.3})
	shot("S4", 7.4, "static", "the box drops, empty but for a belt",
		{"pos": Vector3(0.7, 0.8, 1.3), "look": Vector3(-0.1, 0.3, -0.2), "fov": 44.0})
	hero_shot("S5", 9.1, "hero", {"side_deg": 15.0, "dist": 2.3})   # "Còn... cái nịt."
	two_shot("S6", 12.4, "phuc", "hero", {"side": -1.0, "look_y": 1.25})
	shot("S7", 14.6, "static", "Chú Bảy bonks Phúc: stars",
		{"pos": Vector3(0.6, 1.5, 2.6), "look": Vector3(-0.4, 1.3, 0.6), "fov": 48.0})
	sub(2.5, 2.3, "chu_bay", "Thẻ sinh viên đây con. Chú giữ lại nhé.")
	sub(5.0, 2.2, "hero", "Bảy ngày... mà bằng chứng không đủ.")
	sub(9.4, 1.8, "hero", "Còn... cái nịt.")
	sub(12.5, 2.2, "phuc", "Ít ra mày còn cái nịt! Tao mất cả cái nịt!")
	sub(14.8, 0.8, "chu_bay", "Ồn ào!")
	joke(9.4, "expelled with only a belt left: 'Còn cái nịt'")
	card("screen", CREDITS_R, length - CREDITS_R, {"kind": "credits", "title": "KẾT E: CÒN CÁI NỊT", "lines": [
		"%s: bị đuổi học." % hero_name, "Tài sản còn lại: một cái nịt.", "Sói Xám: vẫn chạy xe không gương.",
		"Alexander: vẫn đang giới thiệu tên.", "Za Mẫn: đang pivot.", "Cừu Dolly: đang thi hộ ở đâu đó.",
		"Lùm Văn Lọ: mở thêm ba cơ sở.", " ", "Tìm đủ bằng chứng để mở kết khác."]})
