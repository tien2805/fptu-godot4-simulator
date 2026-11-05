# File: res://scripts/cine/timelines/cine_d1.gd
# cine_d1 (18.000 s, spec B-D5 beat 9, story spec Day 1 end cinematic): night, the road edge outside the west gate where
# the brawl happened (seg_d1_brawl's stage). Mũ Đỏ sits dazed against his scooter; the protagonist picks up the courier's
# dropped phone, which lights up: StoryScreenCard "phone" (4.0-9.4 s real) shows the notification "Sói Xám: Hàng đêm nay ở
# Nguyễn Xiển. 2h. Đừng trễ."; the protagonist reads it aloud; engines roar down the road and a headlight sweeps past
# (another courier); "Tối nay vui rồi đây." Q5 pass: the joke beat (Mũ Đỏ begs for his phone back, a head shake), then the
# day-end cliffhanger: the phone buzzes again, "Tao thấy mày rồi.", push-in on the protagonist and the cliff_sting.
# No ramps (story = real).
# Music slot cine_d1: the owner's local file user://music/cine_d1.mp3 when present, else no music.
# Stage: the west gate road edge (seg_d1_brawl's dict) with an explicit "at" at the gate (plot u 181, v 0).
# Stage frame: X right (+X toward the gate), -Z forward along the road, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const SCOOTER := Vector3(-3.3, 0.0, -1.6)
const SCOOTER_YAW: float = 160.0
const C2_SIT := Vector3(-3.71, 0.0, -0.47)   # seg_d1_brawl's sit spot, back to the scooter's front wheel (_sc(1.2))
const C2_YAW: float = 160.0
const PHONE := Vector3(-0.55, 0.0, -0.1)
const HERO_FROM := Vector3(1.6, 0.0, 1.4)
const HERO := Vector3(-0.2, 0.0, 0.32)
const PASS_FROM := Vector3(-6.3, 0.0, 4.8)    # another courier rides past along the roadway, inside the 14 x 10 box
const PASS_TO := Vector3(-6.3, 0.0, -4.8)
const RIDER_UP := Vector3(0.0, 0.3, 0.3)        # on the seat (0.79 m, rear of the scooter, which faces -Z at yaw 0)


func build() -> void:
	slot = "cine_d1"
	length = 18.0
	story_end = 18.0
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.8
	stage = {"landmark": "campus_west_gate", "at": CineTimeline.campus_at(FPTUCampusBuilder.west_gate_local()), "near": 30.0,
		"size": Vector2(14.0, 10.0), "tod": "night", "yaw_deg": 46.0, "offset": Vector2(-12.0, 0.0), "fallback": "campus_parking_center",
		"exposure": 1.4, "ambient": 1.8}
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("c2", StoryCast.opts("courier_do"), StoryCast.speaker("courier_do"), StoryCast.color("courier_do"))
	prop("scooter", "scooter", SCOOTER, SCOOTER_YAW, {"headlight": true})
	prop("phone", "phone", PHONE, 25.0, {"glow_at": 2.0, "hide_at": 2.55})
	prop("passer", "scooter", PASS_FROM, 0.0, {"headlight": true, "show_at": 9.6, "hide_at": 12.4,
		"path": [[9.6, PASS_FROM, Vector3.ZERO], [12.4, PASS_TO, Vector3.ZERO]]})
	actor("rider", StoryCast.opts("courier_vang"), StoryCast.speaker("courier_vang"), StoryCast.color("courier_vang"))
	key("rider", 9.6, PASS_FROM + RIDER_UP, 0.0)
	key("rider", 12.4, PASS_TO + RIDER_UP, 0.0, {"mode": "linear"})
	move("rider", 0.0, "ride")
	show("rider", 0.0, false)
	show("rider", 9.6, true)
	show("rider", 12.4, false)
	# the protagonist walks to the phone, picks it up (2.55), reads it with the phone held up
	var y_ph: float = CineTimeline.face(HERO_FROM, PHONE)
	key("hero", 0.0, HERO_FROM, y_ph)
	key("hero", 1.9, HERO, y_ph, {"mode": "linear"})
	move("hero", 0.0, "walk")
	move("hero", 1.9, "idle", {"fade": 0.2})
	strike("hero", 2.55, "pickup", {"dur": 0.6})
	hold("hero", 2.55, 18.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	move("hero", 3.0, "hold_up", {"fade": 0.25})
	look("hero", 3.2, 9.4, Vector3(-0.1, 1.25, -0.1))
	expr("hero", 2.6, "open")
	expr("hero", 4.6, "surprised")
	expr("hero", 7.8, "angry")
	# engines: looks down the road at the passing headlight, then back
	var y_road: float = CineTimeline.face(HERO, Vector3(-6.3, 0.0, -2.0))
	key("hero", 9.4, HERO, y_ph)
	key("hero", 10.0, HERO, y_road)
	look("hero", 9.6, 12.6, "c2")
	look("hero", 12.8, 14.6, Vector3(-6.0, 1.4, -5.0))
	look("hero", 15.0, 16.1, "c2")
	look("hero", 16.3, 18.0, Vector3(-0.1, 1.25, -0.1))
	move("hero", 12.4, "idle", {"fade": 0.3})
	expr("hero", 12.4, "happy")
	# Q5: the joke (a head shake at Mũ Đỏ), then the phone buzzes again: the cliffhanger text
	key("hero", 14.6, HERO, y_road)
	key("hero", 15.1, HERO, CineTimeline.face(HERO, C2_SIT))
	move("hero", 15.0, "head_no", {"fade": 0.15})
	key("hero", 16.0, HERO, CineTimeline.face(HERO, C2_SIT))
	key("hero", 16.4, HERO, y_ph)
	move("hero", 16.2, "hold_up", {"fade": 0.2})
	expr("hero", 16.4, "surprised")
	# Mũ Đỏ dazed against the front wheel, stars, then a worried look
	key("c2", 0.0, C2_SIT, C2_YAW)
	move("c2", 0.0, "slumped")
	look("c2", 1.6, 18.0, "hero")
	expr("c2", 0.0, "done")
	expr("c2", 2.0, "surprised")
	expr("c2", 8.0, "pain")
	expr("c2", 9.4, "surprised")
	expr("c2", 14.4, "pain")
	fx_at(0.1, "stars", "c2", {"until": 2.0})
	sfx_at(1.9, "phone_buzz", -5.0)
	sfx_at(4.0, "phone_buzz", -6.0)
	sfx_at(8.15, "groan", -8.0)
	sfx_at(9.3, "engine_roar", -6.0)
	sfx_at(10.4, "engine_roar", -3.0)
	sfx_at(11.5, "engine_roar", -5.0)
	sfx_at(16.2, "phone_buzz", -3.0)
	sfx_at(16.7, "cliff_sting", -3.0)
	shot("S1", 0.0, "static", "wide: the road edge after the brawl, Mũ Đỏ against his scooter, the phone lights up",
		{"pos": Vector3(1.6, 1.8, 4.6), "look": Vector3(-1.4, 0.6, -0.3), "fov": 50.0})
	shot("S2", 2.4, "static", "medium: the protagonist picks the phone up and reads it (the phone card plays over it)",
		{"pos": Vector3(0.9, 1.55, -1.2), "look": Vector3(-0.2, 1.3, 0.32), "fov": 42.0, "hand": 0.15})
	# Wave 6 (plan 2026-11-05-w6-cines T4): the 7 s reading shot is split: the phone card ends at 8.0, then Mũ Đỏ, dazed
	# against his wheel, watches his secret get read (a low push-in, he groans)
	push_in("S2b", 8.0, "c2", {"from": 2.8, "to": 2.3, "side_deg": 10.0, "height": 0.8, "look_y": 0.55, "hand": 0.15})
	shot("S3", 9.4, "static", "low wide down the road: a headlight sweeps past, engines roar",
		{"pos": Vector3(-1.0, 0.6, 3.0), "look": Vector3(-6.3, 0.9, -3.0), "fov": 52.0, "hand": 0.3})
	hero_shot("S4", 12.4, "hero", {"side_deg": -30.0, "dist": 2.4})
	two_shot("S5", 14.3, "hero", "c2", {"side": -1.0, "look_y": 0.95, "height": 1.25, "push": 0.1})
	push_in("S6", 16.2, "hero", {"from": 3.6, "to": 2.3, "side_deg": 10.0, "look_y": 1.2})
	card("screen", 4.0, 4.0, {"kind": "phone", "sender": "Sói Xám", "text": "Hàng đêm nay ở Nguyễn Xiển. 2h. Đừng trễ.", "time": "23:41"})
	sub(2.1, 1.3, "c2", "Ê... đừng... đọc...")
	sub(5.6, 2.6, "hero", "Sói Xám... hàng đêm nay ở Nguyễn Xiển.")
	sub(12.7, 1.6, "hero", "Tối nay vui rồi đây.")
	sub(14.5, 1.8, "c2", "Ê... trả tao điện thoại đi...")
	sub(16.4, 1.5, "hero", "...'Tao thấy mày rồi.'")
	joke(14.5, "Mũ Đỏ begs for his phone back; a flat head shake")
	cliffhanger(16.4)
