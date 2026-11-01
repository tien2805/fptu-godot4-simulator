# File: res://scripts/cine/timelines/end_b.gd
# end_b (24.000 s, story spec section 6, ending B "Thắng nhưng mất bạn", plan 2026-11-01-w4-endings.md T1): bittersweet.
# Morning outside BE6 after the hearing. Phúc comes out carrying a cardboard box of his things: "Đình chỉ một kỳ. Tao đáng
# mà." - "Phúc... tao xin lỗi." - "Mày làm đúng. Tao mua tool thật mà." The bottom of the box gives way: instant noodles roll
# out (slide whistle, ba dum tss): "...Mì của tao." They pick them up together; "Học kỳ sau tao quay lại. Giữ chỗ ngồi cho
# tao." A handshake, Phúc walks off; Mr.T's text: "Em được minh oan rồi. Chúc mừng em." The credits roll (20.0-24.0 s).
# No ramps (story = real). Music slot end_b (owner file "Lean on Me", else silence).
# Stage: the ai_intro stage outside BE6 (be6_center, 7 x 7, morning).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.6, 0.0, 0.4)
const PHUC_FROM := Vector3(-2.2, 0.0, -2.8)
const PHUC := Vector3(-0.5, 0.0, -0.6)
const PHUC_GO := Vector3(-2.6, 0.0, -3.2)
const DROP := Vector3(-0.15, 0.0, -0.15)
const CREDITS_R: float = 20.0


func build() -> void:
	slot = "end_b"
	length = 24.0
	story_end = 24.0
	mood = "eerie"
	fade_in = 0.8
	fade_out = 1.0
	stage = {"landmark": "be6_center", "near": 70.0, "size": Vector2(7.0, 7.0), "tod": "morning"}
	var hero_name: String = StoryCast.speaker("hero")
	actor("hero", StoryCast.opts("hero"), hero_name, StoryCast.color("hero"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	# the noodles that roll out of the box when its bottom gives way at 8.4
	for i: int in 3:
		var land: Vector3 = DROP + Vector3(-0.35 + 0.35 * i, 0.04, 0.2 * (i % 2))
		prop("noodle%d" % i, "noodles", land, 30.0 * i, {"show_at": 8.4, "hide_at": 12.2, "arc": 0.12, "path": [
			[8.4, DROP + Vector3(0.0, 0.9, 0.0), Vector3.ZERO], [9.0, land, Vector3(90.0, 30.0 * i, 0.0)]]})
	prop("box_floor", "box", DROP + Vector3(0.0, 0.16, 0.0), 20.0, {"show_at": 8.4, "hide_at": 12.2})
	# Phúc walks out with his box, stops before the protagonist
	key("phuc", 0.0, PHUC_FROM, CineTimeline.face(PHUC_FROM, PHUC))
	key("phuc", 1.6, PHUC, CineTimeline.face(PHUC_FROM, PHUC), {"mode": "out"})
	key("phuc", 2.0, PHUC, CineTimeline.face(PHUC, HERO))
	move("phuc", 0.0, "walk")
	move("phuc", 1.6, "tray_hold", {"fade": 0.25})
	hold("phuc", 0.0, 8.4, "box", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.05, -0.22)})
	move("phuc", 8.4, "startled", {"fade": 0.1})
	move("phuc", 9.4, "facepalm", {"fade": 0.15})
	move("phuc", 10.8, "pickup", {"fade": 0.2})
	move("phuc", 12.6, "talk", {"fade": 0.2})
	move("phuc", 15.4, "handshake", {"fade": 0.2})
	key("phuc", 17.0, PHUC, CineTimeline.face(PHUC, HERO))
	key("phuc", 17.4, PHUC, CineTimeline.face(PHUC, PHUC_GO))
	key("phuc", 19.6, PHUC_GO, CineTimeline.face(PHUC, PHUC_GO), {"mode": "out"})
	move("phuc", 17.2, "walk", {"fade": 0.2})
	hold("phuc", 12.4, 19.8, "box", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.05, -0.22)})
	look("phuc", 2.0, 17.2, "hero")
	expr("phuc", 0.0, "done")
	expr("phuc", 6.0, "open")
	expr("phuc", 8.4, "surprised")
	expr("phuc", 12.6, "happy")
	# the protagonist
	key("hero", 0.0, HERO, CineTimeline.face(HERO, PHUC))
	move("hero", 0.0, "idle")
	move("hero", 4.2, "talk", {"fade": 0.2})
	move("hero", 5.8, "idle", {"fade": 0.2})
	move("hero", 10.8, "pickup", {"fade": 0.2})
	move("hero", 12.4, "idle", {"fade": 0.3})
	move("hero", 15.4, "handshake", {"fade": 0.2})
	move("hero", 17.0, "idle", {"fade": 0.3})
	look("hero", 0.0, 17.0, "phuc")
	look("hero", 17.1, 18.6, "phuc")
	move("hero", 18.7, "hold_up", {"fade": 0.2})
	hold("hero", 18.7, story_end, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	look("hero", 18.8, story_end, HERO + Vector3(0.12, 1.25, -0.38))
	expr("hero", 0.0, "done")
	expr("hero", 4.2, "talk")
	expr("hero", 9.4, "happy")
	expr("hero", 18.8, "done")
	sfx_at(8.4, "slide_whistle", -4.0)
	sfx_at(9.2, "ba_dum_tss", -6.0)
	sfx_at(18.6, "phone_buzz", -4.0)
	shot("S1", 0.0, "static", "wide: morning outside BE6, Phúc carries a box of his things out",
		{"pos": Vector3(2.6, 1.6, 2.6), "look": Vector3(-0.8, 1.1, -1.2), "fov": 50.0})
	two_shot("S2", 1.8, "phuc", "hero", {"side": 1.0, "look_y": 1.25})
	push_in("S3", 4.1, "hero", {"from": 2.6, "to": 2.1, "side_deg": -20.0, "look_y": 1.3})   # "Phúc... tao xin lỗi."
	ots_shot("S4", 6.0, "hero", "phuc", {"side": 1.0})
	shot("S5", 8.3, "static", "the bottom of the box gives way: instant noodles everywhere",
		{"pos": Vector3(0.9, 0.9, 1.0), "look": Vector3(-0.2, 0.4, -0.2), "fov": 46.0})
	two_shot("S6", 12.4, "hero", "phuc", {"side": -1.0, "look_y": 1.2})
	shot("S7", 17.2, "static", "wide: Phúc walks off with his box, the protagonist watches",
		{"pos": Vector3(2.4, 1.5, 2.2), "look": Vector3(-1.4, 1.1, -2.0), "fov": 48.0})
	push_in("S8", 18.7, "hero", {"from": 2.4, "to": 2.0, "side_deg": 25.0, "look_y": 1.25})
	sub(1.9, 2.2, "phuc", "Đình chỉ một kỳ. Tao đáng mà.")
	sub(4.2, 1.6, "hero", "Phúc... tao xin lỗi.")
	sub(6.0, 2.2, "phuc", "Mày làm đúng. Tao mua tool thật mà.")
	sub(9.4, 1.3, "phuc", "...Mì của tao.")
	sub(12.7, 2.6, "phuc", "Học kỳ sau tao quay lại. Giữ chỗ ngồi cho tao.")
	sub(18.9, 1.9, "Mr.T (tin nhắn)", "Em được minh oan rồi. Chúc mừng em.")
	joke(9.4, "the box bottom gives way, instant noodles roll out: '...Mì của tao.'")
	card("screen", CREDITS_R, length - CREDITS_R, {"kind": "credits", "title": "KẾT B: THẮNG NHƯNG MẤT BẠN", "lines": [
		"%s được minh oan." % hero_name, "Phúc: đình chỉ một kỳ, về quê nuôi cá.", "Chỗ ngồi bàn cuối: vẫn để trống.", " ",
		"Bao che cho bạn để mở một kết khác."]})
