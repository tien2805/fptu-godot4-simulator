# File: res://scripts/cine/timelines/cine_d6_choice.gd
# cine_d6_choice (14.000 s, plan 2026-11-01-w4-day6 beat d6_choice, story spec 8.4 choice 3): Day 6, the finish bank of
# the canal after the chase. Thị Lọ's pink speedboat lies nose up on the stones, steaming; she climbs off it soaked, the
# cash bag in her hand, and stops the protagonist: "Khoan! Bình tĩnh, nói chuyện người lớn." She opens the bag (a
# dripping briefcase of cash): "Một vali. Coi như mày chưa thấy gì." - "Sao vali nhỏ nước tong tong vậy?" - "Tiền mới
# rửa mà." Then the price: forget the ledger. "Không thì... còn cái nịt." The frame freezes on choice 3 (StoryChoice at
# 13.600 s real, the clock holds): "Nhận vali" (key take) / "Từ chối" (key refuse); on timeout the honest option is
# taken: "Từ chối", with a comic line. The answer goes to StoryDirector.choices.bribe (evaluate_ending: "take" caps the
# ending at D) and CinePlayer.choice_made("bribe", key, timed_out); the beat d6_choice_tail then plays
# cine_d6_choice_take or cine_d6_choice_refuse (she escapes on a Bầy Sói jet ski either way).
# No ramps (story = real). Music slot cine_d6_choice (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("bridge") with the carried bank (set); inside the lair StoryCanal plays it at
# LairCanal.bank_xf() (the finish bank) with drop_set. Positions shared with the tails (set_dressing).
# Bank frame: X along the bank, -Z toward the water (y = -1), the bank top at y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LO := Vector3(0.5, 0.0, 0.9)
const HERO := Vector3(-0.7, 0.0, 2.9)
const HERO_FROM := Vector3(-3.6, 0.0, 1.3)
const CHOICE_R: float = 13.6


func build() -> void:
	slot = "cine_d6_choice"
	length = 14.0
	story_end = 14.0
	mood = "playful"
	fade_in = 0.5
	fade_out = 0.3
	stage = CineTimeline.phase_c_stage("bridge")
	actor("hero", StoryCast.opts("hero", {"shirt_color": StoryCanal.SHIPPER_SHIRT}), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("lo", StoryCast.opts("thi_lo"), StoryCast.speaker("thi_lo"), StoryCast.color("thi_lo"))
	StoryCast.dress(self, "lo", "thi_lo")
	set_dressing(self)
	var y_lo: float = CineTimeline.face(LO, HERO)
	var y_hero: float = CineTimeline.face(HERO, LO)
	# Thị Lọ climbs off her boat soaked, stops the protagonist, opens the bag, names her price
	key("lo", 0.0, LO + Vector3(0.6, 0.0, -0.5), CineTimeline.face(LO, HERO_FROM))
	key("lo", 0.8, LO, CineTimeline.face(LO, HERO_FROM), {"mode": "out"})
	key("lo", 2.0, LO, y_lo)
	move("lo", 0.0, "stunned")
	move("lo", 0.4, "hold_up", {"fade": 0.15})
	move("lo", 2.4, "present", {"fade": 0.25})
	move("lo", 7.2, "laugh", {"fade": 0.15})
	move("lo", 8.5, "point", {"fade": 0.2})
	move("lo", 10.4, "arms_crossed", {"fade": 0.25})
	hold("lo", 0.0, 2.4, "cash_bag", {"offset": Vector3(0.0, -0.05, -0.08)})
	hold("lo", 2.4, story_end, "cash_bag", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.16), "open": true})
	look("lo", 0.0, story_end, "hero")
	expr("lo", 0.0, "surprised")
	expr("lo", 1.0, "talk")
	expr("lo", 7.2, "happy")
	expr("lo", 10.4, "done")
	# the protagonist walks up from the boat, the ledger in the left hand, the rubber band still on the right wrist
	key("hero", 0.0, HERO_FROM, CineTimeline.face(HERO_FROM, HERO))
	key("hero", 1.9, HERO, y_hero, {"mode": "out"})
	move("hero", 0.0, "walk")
	move("hero", 1.9, "idle", {"fade": 0.25})
	move("hero", 5.1, "point", {"fade": 0.2})
	move("hero", 6.6, "arms_crossed", {"fade": 0.25})
	move("hero", 12.3, "idle", {"fade": 0.3})
	hold("hero", 0.0, story_end, "ledger", {"bone": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.09)})
	look("hero", 0.0, 1.0, LO + Vector3(0.0, 1.5, 0.0))
	look("hero", 1.0, story_end, "lo")
	expr("hero", 0.0, "angry")
	expr("hero", 5.1, "surprised")
	expr("hero", 7.4, "done")
	expr("hero", 12.3, "open")
	sfx_at(0.1, "metal_creak", -10.0)
	sfx_at(0.3, "body_fall", -12.0)
	sfx_at(2.6, "rustle", -8.0)
	sfx_at(7.6, "ba_dum_tss", -12.0)
	sfx_at(12.2, "heartbeat", -8.0)
	fx_at(0.2, "dust", BOAT_AT + Vector3(0.0, 0.6, 1.4), {"power": 0.6})
	shot("S1", 0.0, "static", "wide: the pink boat nose up on the bank, steaming; Thị Lọ climbs off soaked as the protagonist walks up",
		{"pos": Vector3(-4.6, 1.7, 5.6), "look": Vector3(1.2, 0.6, -0.2), "fov": 52.0, "hand": 0.15})
	two_shot("S2", 2.3, "hero", "lo", {"side": 1.0, "look_y": 1.2})   # the open bag
	ots_shot("S3", 4.95, "lo", "hero", {"side": 1.0, "look_y": 1.35})   # "Sao vali nhỏ nước tong tong vậy?"
	push_in("S4", 7.1, "lo", {"from": 2.8, "to": 2.3, "side_deg": 20.0, "look_y": 1.2})   # Q5: "Tiền mới rửa mà."
	dutch_shot("S5", 8.5, "lo", {"side_deg": -25.0, "dist": 2.6, "roll": 12.0, "push": 0.15, "look_y": 1.2})   # the price
	push_in("S6", 12.2, "hero", {"from": 2.8, "to": 2.4, "side_deg": -15.0, "look_y": 1.2})   # the frame that freezes
	sub(0.45, 2.2, "lo", "Khoan! Bình tĩnh, nói chuyện người lớn.")
	sub(2.8, 2.1, "lo", "Một vali. Coi như mày chưa thấy gì.")
	sub(5.1, 1.9, "hero", "Sao vali nhỏ nước tong tong vậy?")
	sub(7.2, 1.2, "lo", "Tiền mới rửa mà.")
	joke(7.2, "the bribe is dripping canal water: freshly laundered money")
	sub(8.6, 1.8, "lo", "Cầm đi, rồi quên cái sổ cái.")
	sub(10.5, 1.7, "lo", "Không thì... còn cái nịt.")
	choice(CHOICE_R, {"id": "bribe", "title": "Lựa chọn 3",
		"prompt": "Thị Lọ chìa vali tiền, đổi lại mày quên cuốn sổ cái. Mày chọn sao?",
		"options": [{"key": "take", "label": "Nhận vali"}, {"key": "refuse", "label": "Từ chối"}],
		"honest": "refuse", "timeout_line": "Im lặng mười giây... Thị Lọ hiểu là mày từ chối. Tiền ướt, khỏi cầm!"})


## The finish bank shared by cine_d6_choice and its tails: the bank piece (set; the lair has its own finish bank) and Thị
## Lọ's crashed speedboat nose up on the stones.
const BOAT_AT := Vector3(3.2, -0.45, -1.0)


static func set_dressing(tl: CineTimeline) -> void:
	tl.prop("bank", "canal_bank", Vector3.ZERO, 0.0, {"set": true, "w": 30.0, "d": 24.0})
	var rot := Vector3(16.0, 160.0, -6.0)
	tl.prop("lboat", "speedboat", BOAT_AT, 160.0, {"color": Color("#FFB3D6"), "trim": Color("#FF4FA3"), "name": "LỌ",
		"path": [[0.0, BOAT_AT, rot], [1.0, BOAT_AT, rot]]})
