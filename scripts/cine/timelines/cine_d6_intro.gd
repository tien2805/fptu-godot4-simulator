# File: res://scripts/cine/timelines/cine_d6_intro.gd
# cine_d6_intro (16.000 s, plan 2026-11-01-w4-day6 beat d6_shop intro, story spec 8.4 the intro, C-D9 mission intro): Day 6,
# night, the road to the Rạch Hầm bridge by the "Trà Sữa Lọ" shop. Phúc waits at the roadside sipping a milk tea: "Ê! Bên
# này!" - the shop is hiring shippers and he got the protagonist a shift. He hands over the uniform: a folded pink shirt
# with a pink helmet with sheep ears on top. "...Màu hồng?" - "Size hơi... hồng." Cut: the protagonist in the pink shirt
# and the pink helmet, arms crossed, deadpan; Phúc takes a photo for his story (the flash). Anh Duy on the radio (with his
# "Dịch:" line): win the boss over and the back door opens by itself.
# No ramps (story = real). Music slot cine_d6_intro (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("drive") (7 x 26, -Z toward the bridge; shared with cine_d3_intro). The protagonist in
# the uniform is a second actor ("hero_s", the shipper shirt of StoryCanal.SHIPPER_SHIRT) shown from the cut on.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const PHUC := Vector3(-1.6, 0.0, -1.6)
const HERO := Vector3(-0.2, 0.0, -0.6)
const HERO_FROM := Vector3(0.6, 0.0, 6.5)
const CUT: float = 9.6


func build() -> void:
	slot = "cine_d6_intro"
	length = 16.0
	story_end = 16.0
	mood = "playful"
	fade_in = 0.6
	fade_out = 0.6
	stage = CineTimeline.phase_c_stage("drive")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("hero_s", StoryCast.opts("hero", {"shirt_color": StoryCanal.SHIPPER_SHIRT}), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	actor("duy", StoryCast.opts("anh_duy"), StoryCast.speaker("anh_duy"), StoryCast.color("anh_duy"))
	show("duy", 0.0, false)
	key("duy", 0.0, Vector3(3.0, 0.0, 12.0), 0.0)
	var y_hero: float = CineTimeline.face(HERO, PHUC)
	var y_phuc: float = CineTimeline.face(PHUC, HERO)
	# the protagonist walks up the road to Phúc, takes the uniform; from the cut on the uniformed double stands there
	key("hero", 0.0, HERO_FROM, CineTimeline.face(HERO_FROM, HERO))
	key("hero", 2.5, HERO, y_hero, {"mode": "out"})
	move("hero", 0.0, "walk")
	move("hero", 2.5, "idle", {"fade": 0.25})
	move("hero", 7.5, "hold_up", {"fade": 0.2})
	hold("hero", 7.6, CUT, "uniform_pack", {"mid": "Wrist.L", "offset": Vector3(0.0, 0.0, -0.14)})
	look("hero", 0.0, 1.0, Vector3(-1.0, 1.4, -6.0))
	look("hero", 1.0, 7.5, "phuc")
	look("hero", 7.6, 8.6, Vector3(-0.2, 1.1, -1.1))
	look("hero", 8.7, CUT, "phuc")
	expr("hero", 0.0, "open")
	expr("hero", 7.7, "surprised")
	expr("hero", 8.6, "done")
	show("hero", CUT, false)
	show("hero_s", 0.0, false)
	show("hero_s", CUT, true)
	key("hero_s", 0.0, HERO, y_hero)
	move("hero_s", 0.0, "arms_crossed")
	hold("hero_s", CUT, story_end, "helmet", {"bone": "Head", "offset": Vector3(0.0, 0.085, 0.0), "color": CinePropsD6.PINK})
	look("hero_s", CUT, story_end, "phuc")
	expr("hero_s", CUT, "done")
	# Phúc sips his milk tea, waves, pitches the job, hands over the uniform, takes a photo
	key("phuc", 0.0, PHUC, y_phuc)
	move("phuc", 0.0, "sip")
	hold("phuc", 0.0, 2.3, "milk_tea", {"offset": Vector3(0.0, -0.03, -0.04), "tea": CinePropsD6.TEA_COLORS["dau"]})
	move("phuc", 0.5, "point", {"fade": 0.15})
	move("phuc", 2.4, "talk", {"fade": 0.25})
	move("phuc", 5.0, "point", {"fade": 0.2})
	move("phuc", 6.3, "present", {"fade": 0.25})
	hold("phuc", 6.3, 7.6, "uniform_pack", {"mid": "Wrist.L", "offset": Vector3(0.0, 0.0, -0.14)})
	move("phuc", 8.2, "shrug", {"fade": 0.15})
	move("phuc", CUT, "hold_up", {"fade": 0.1})
	hold("phuc", CUT, 12.6, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	move("phuc", 12.6, "laugh", {"fade": 0.2})
	look("phuc", 0.0, story_end, "hero")
	expr("phuc", 0.0, "happy")
	expr("phuc", 2.4, "talk")
	expr("phuc", 8.2, "happy")
	sfx_at(0.4, "slide_whistle", -14.0)
	sfx_at(7.7, "record_scratch", -10.0)
	sfx_at(10.6, "freeze_tick", -2.0)
	fx_at(10.6, "flash", "phuc:Wrist.R", {"power": 0.7})
	sfx_at(11.0, "ba_dum_tss", -12.0)
	shot("S1", 0.0, "static", "roadside wide at night: the protagonist walks up the road, Phúc sipping a milk tea by the kerb",
		{"pos": Vector3(-3.0, 1.5, -4.2), "look": Vector3(0.2, 1.1, 2.0), "fov": 50.0, "hand": 0.2})
	two_shot("S2", 2.4, "hero", "phuc", {"side": 1.0, "look_y": 1.2})   # the pitch
	shot("S3", 6.4, "static", "insert: the folded pink shirt TRÀ SỮA LỌ and the pink helmet with sheep ears",
		{"pos": Vector3(-0.55, 1.45, 0.25), "look": Vector3(-0.9, 1.05, -1.1), "fov": 40.0})
	push_in("S4", 7.5, "hero", {"from": 2.8, "to": 2.4, "side_deg": 30.0, "look_y": 1.2})   # "...Màu hồng?"
	two_shot("S5", CUT, "hero_s", "phuc", {"side": -1.0, "look_y": 1.25})   # the uniform reveal, the photo flash
	hero_shot("S6", 12.4, "hero_s", {"side_deg": 25.0})   # the pink shipper, low and proud (Anh Duy's line)
	sub(0.5, 1.0, "phuc", "Ê! Bên này!")
	sub(2.6, 2.1, "phuc", "Quán Trà Sữa Lọ đang tuyển shipper.")
	sub(4.8, 1.8, "phuc", "Tao xin cho mày một ca rồi.")
	sub(7.75, 0.9, "hero", "...Màu hồng?")
	sub(8.75, 1.3, "phuc", "Size hơi... hồng.")
	joke(8.75, "the shipper uniform is pink with sheep ears: Size hơi... hồng")
	sub(10.1, 2.0, "phuc", "Đứng yên, tao chụp đăng story.")
	card("screen", 12.2, 3.6, {"kind": "radio", "sender": "Anh Duy"})
	sub(12.3, 3.4, "duy", "Lấy lòng bà chủ, cửa sau tự mở.", "Dịch: Bán trà sữa cho khéo vô.")
