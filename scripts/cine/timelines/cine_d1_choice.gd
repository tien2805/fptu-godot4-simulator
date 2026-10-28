# File: res://scripts/cine/timelines/cine_d1_choice.gd
# cine_d1_choice (12.000 s, spec B-D5 beat 8, B-D8 choice scene, story spec 8.4 choice 1): Day 1, night, a bench in the ring
# courtyard. Phúc walks up, wrings his hands and confesses: he bought the "Lọ Thần" tool and the couriers are blackmailing
# him. The protagonist snaps "Mày điên hả?!", Phúc begs "Đừng nói với Mr.T nha…", and the frame freezes on the choice
# (StoryChoice at 11.600 s real, CinePlayer holds its clock): "Che giấu cho Phúc" (key cover) / "Báo Mr.T" (key report);
# on timeout the honest option is taken: "Che giấu cho Phúc" (the loyal one), with a comic line. The answer goes to
# StoryDirector.choices.phuc and CinePlayer.choice_made("phuc", key, timed_out); the integration then plays the branch tail
# cine_d1_choice_cover or cine_d1_choice_report (same stage, same positions: CHOICE_STAGE / the constants below).
# No ramps (story = real). Music slot cine_d1_choice (owner file, else no music).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const BENCH := Vector3(0.0, 0.0, 1.2)
const HERO := Vector3(0.55, 0.0, 0.1)
const PHUC_FROM := Vector3(-4.2, 0.0, -1.6)
const PHUC := Vector3(-0.5, 0.0, -0.35)
const CHOICE_R: float = 11.6

## Shared with the branch tails: the courtyard bench at night.
static func choice_stage() -> Dictionary:
	return {"landmark": "campus_parking_center", "at": CineTimeline.campus_at(Vector3(70.0, 0.0, 45.0)), "near": 30.0,
		"size": Vector2(8.0, 8.0), "tod": "night", "yaw_deg": CineTimeline.campus_yaw(0.0), "exposure": 1.5, "ambient": 1.8}


func build() -> void:
	slot = "cine_d1_choice"
	length = 12.0
	story_end = 12.0
	mood = "eerie"
	fade_in = 0.5
	fade_out = 0.4
	stage = choice_stage()
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	prop("bench", "bench", BENCH, 0.0)
	prop("lamp", "lamp", Vector3(2.2, 0.0, 1.6), 0.0, {"energy": 2.0})
	var y_hp: float = CineTimeline.face(HERO, PHUC)
	var y_ph: float = CineTimeline.face(PHUC, HERO)
	key("hero", 0.0, HERO, y_hp - 40.0)
	key("hero", 1.4, HERO, y_hp)
	move("hero", 0.0, "idle")
	look("hero", 0.6, 12.0, "phuc")
	expr("hero", 0.0, "open")
	expr("hero", 3.9, "surprised")
	expr("hero", 5.6, "angry")
	expr("hero", 7.2, "open")
	expr("hero", 10.4, "done")
	move("hero", 5.6, "head_shake", {"fade": 0.12})
	move("hero", 6.3, "arms_crossed", {"fade": 0.25})
	# Phúc walks up, then confesses with his head down
	key("phuc", 0.0, PHUC_FROM, CineTimeline.face(PHUC_FROM, PHUC))
	key("phuc", 2.0, PHUC, CineTimeline.face(PHUC_FROM, PHUC), {"mode": "linear"})   # 3.9 m in 2 s: a hurried jog
	key("phuc", 2.4, PHUC, y_ph)
	move("phuc", 0.0, "jog")
	move("phuc", 2.0, "confess", {"fade": 0.3})
	move("phuc", 6.9, "talk", {"fade": 0.3})
	move("phuc", 10.1, "confess", {"fade": 0.3})
	look("phuc", 2.3, 3.2, "hero")
	look("phuc", 6.8, 12.0, "hero")
	expr("phuc", 0.4, "talk")
	expr("phuc", 3.1, "done")
	expr("phuc", 6.8, "talk")
	expr("phuc", 10.1, "surprised")
	sfx_at(5.6, "record_scratch", -6.0)
	sfx_at(8.0, "heartbeat", -8.0)
	shot("S1", 0.0, "static", "wide: the courtyard bench at night, Phúc walks up",
		{"pos": Vector3(1.6, 1.6, -4.4), "look": Vector3(-0.8, 1.0, -0.2), "fov": 50.0})
	ots_shot("S2", 2.9, "hero", "phuc", {"hand": 0.15, "look_y": 1.2})
	shot("S3", 5.5, "static", "close: the protagonist, \"Mày điên hả?!\"",
		{"pos": Vector3(-0.15, 1.58, -0.75), "look": Vector3(0.55, 1.5, 0.1), "fov": 38.0, "hand": 0.2})
	shot("S4", 6.7, "static", "close: Phúc, the blackmail",
		{"pos": Vector3(0.35, 1.55, -1.25), "look": Vector3(-0.5, 1.45, -0.35), "fov": 36.0, "hand": 0.15})
	two_shot("S5", 10.0, "hero", "phuc", {"side": -1.0, "push": 0.1, "look_y": 1.2})   # the frame that freezes for the choice
	sub(0.5, 2.4, "phuc", "Ê… tao có chuyện phải nói với mày.")
	sub(3.1, 2.3, "phuc", "Tao mua tool rồi... gói Premium.")
	joke(3.1, "he bought the Premium plan of the cheat tool")
	sub(5.6, 1.0, "hero", "Mày điên hả?!")
	sub(6.8, 3.2, "phuc", "Giờ tụi nó tống tiền tao, không trả là báo trường.")
	sub(10.1, 1.5, "phuc", "Đừng nói với Mr.T nha…")
	choice(CHOICE_R, {"id": "phuc", "title": "Lựa chọn 1",
		"prompt": "Phúc mua tool và đang bị tống tiền. Mày chọn sao?",
		"options": [{"key": "cover", "label": "Che giấu cho Phúc"}, {"key": "report", "label": "Báo Mr.T"}],
		"honest": "cover", "timeout_line": "Đứng hình mười giây… Phúc coi như mày gật đầu rồi đó!"})
