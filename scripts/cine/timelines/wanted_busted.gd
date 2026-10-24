# File: res://scripts/cine/timelines/wanted_busted.gd
# wanted_busted (7.000 s, Phase W spec section 5 / W-D8, plan Task 10): "BỊ TÓM!" – the officer who made the catch walks up behind
# the player and cuffs him on the B1 click (one medium ramp at real 2.400 s); if Mr.T (the story's
# fictional lecturer) made the catch, a guard cuffs and Mr.T stands in front shaking his head. WantedDirector sets
# `catcher` ("guard" | "police" | "mr_t") before build() and plays it through FreeRoam.play_cinematic with opts "xf" (the
# player's spot and facing), so `stage` stays empty. CineTimeline.load_slot("wanted_busted") builds the guard variant (beat sheet
# docs/cinematics/wanted_busted.txt). The ramp ends at 3.260 s real: a 3.740 s normal-speed tail (A1-D8: 3-4 s).
# Stage frame: X right, -Z forward (where the player faces), ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 0.0)
const COP_FROM := Vector3(0.9, 0.0, 2.6)
const COP_AT := Vector3(0.3, 0.0, 0.8)
const MR_T_AT := Vector3(-0.9, 0.0, -1.6)

var catcher: String = "guard"


func build() -> void:
	slot = "wanted_busted"
	length = 7.0
	story_end = 6.251
	mood = "playful"
	fade_in = 0.3
	fade_out = 0.5
	stage = {}
	var police: bool = catcher == "police"
	# story mode (A2-D5): the busted hero is the protagonist; without a story the default roam player "Bạn"
	actor("hero", StoryUtil.hero_opts({"preset": "player", "seed": 2805}), StoryUtil.hero_name() if StoryUtil.story_active() else "Bạn", Color("#F37021"))
	actor("cop", {"preset": "cop", "seed": 32} if police else {"preset": "guard", "seed": 31}, "Cảnh sát" if police else "Bảo vệ", Color("#7FB2E5"))
	hit("B1", 2.2, "medium", "cuffs click", {"r": 2.4})
	key("hero", 0.0, HERO, 0.0)
	move("hero", 0.0, "idle")
	move("hero", 2.25, "stunned", {"fade": 0.15})
	expr("hero", 2.25, "pain")
	fx_at("B1", "stars", "hero", {"until": 6.0})
	key("cop", 0.0, COP_FROM, CineTimeline.face(COP_FROM, HERO))
	key("cop", 1.75, COP_AT, CineTimeline.face(COP_AT, HERO), {"mode": "out"})
	move("cop", 0.0, "walk")
	strike("cop", "B1", "yank")
	move("cop", 2.55, "grab")
	expr("cop", 2.55, "angry")
	sfx_at("B1", "neck_crack", -2.0)
	sfx_at(4.4, "slide_whistle", -8.0)
	shot("S1", 0.0, "static", "wide: the officer walks up behind", {"pos": Vector3(-2.8, 1.7, -3.2), "look": Vector3(0.3, 1.0, 0.9), "fov": 50.0})
	shot("S2", 1.85, "orbit", "close on the cuffs", {"center": Vector3(0.15, 1.0, 0.4), "radius": 1.9, "deg_from": 70.0, "deg_to": 110.0, "height": 1.25, "fov": 42.0})
	shot("S3", 3.3, "static", "front two-shot", {"pos": Vector3(0.35, 1.55, -3.4), "look": Vector3(0.15, 1.15, 0.3), "fov": 45.0, "hand": 0.3})
	if catcher == "mr_t":
		actor("mr_t", {"preset": "lecturer", "seed": 1995, "glasses": true}, "Mr.T", Color("#9B59B6"))
		key("mr_t", 0.0, MR_T_AT, CineTimeline.face(MR_T_AT, HERO))
		move("mr_t", 0.0, "idle")
		move("mr_t", 3.5, "head_shake")
		move("mr_t", 4.1, "head_shake")
		move("mr_t", 4.7, "idle")
		look("mr_t", 0.0, 6.2, "hero")
		look("hero", 3.4, 6.2, "mr_t")
		sub(3.3, 1.3, "mr_t", "Em kia! Thẻ sinh viên đâu?")
		sub(4.7, 1.1, "mr_t", "Mười năm đi dạy, chưa thấy em nào lì như em.")
	else:
		look("hero", 3.4, 6.2, "cop")
		sub(3.6, 1.8, "cop", "Mời anh đi lao động công ích!" if police else "Đi lao động công ích với chú nào!")
	sub(5.9, 0.9, "hero", "Ét o ét…")
