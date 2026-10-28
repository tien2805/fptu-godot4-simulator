# File: res://scripts/cine/timelines/ai_intro.gd
# ai_intro – in-engine fallback (24.000 s, spec A2-D10, story spec 8.2): the next morning outside BE6. The protagonist reads
# the phone; StoryIntroCards draws the 2D cards on top at fixed real times (StoryIntroCards.CARDS): the email "Phòng Khảo thí:
# Quyết định đình chỉ thi", a huge red "TOANG!" stamp slamming onto it (toang_sting here at its slam time), Mr.T's text
# "Thầy tin em. Tìm bằng chứng đi.", a 7-day countdown flipping to 7, the title card "TOOL ĐEN – 7 ngày minh oan".
# When the owner's video user://video/ai_intro_m.ogv / ai_intro_f.ogv exists, StoryVideo plays it instead (StoryRoam).
# Music slot ai_intro (owner file user://music/ai_intro.ogg|.mp3, else no music). No ramps (story = real).
# Q5 pass: the joke beat ("Mới được khen hôm qua mà..."), push-in and hero angle helpers, and the Day 0 cliffhanger: under
# the title card a text from an unknown number, "Đừng đào sâu. Mày còn 7 ngày thôi.", then the cliff_sting.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 0.0)


func build() -> void:
	slot = "ai_intro"
	length = 24.0
	story_end = 24.0
	mood = "playful"
	fade_in = 0.8
	fade_out = 0.6
	letterbox = true
	stage = {"landmark": "be6_center", "near": 70.0, "size": Vector2(7.0, 7.0), "tod": "morning"}
	actor("hero", StoryUtil.hero_opts({"preset": "player", "seed": 2805}), StoryUtil.hero_name(), Color("#F37021"))
	key("hero", 0.0, HERO, 0.0)
	move("hero", 0.0, "hold_up")   # reading the phone
	hold("hero", 0.0, 24.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	look("hero", 1.2, 12.0, Vector3(0.12, 1.25, -0.38))
	expr("hero", 1.2, "open")
	expr("hero", 5.2, "surprised")
	expr("hero", 8.2, "done")
	move("hero", 13.0, "idle", {"fade": 0.2})
	expr("hero", 13.2, "angry")
	look("hero", 13.0, 20.6, Vector3(0.0, 1.6, -5.0))
	move("hero", 17.6, "victory")
	move("hero", 19.6, "idle", {"fade": 0.3})
	move("hero", 10.9, "facepalm", {"fade": 0.15})
	move("hero", 12.4, "hold_up", {"fade": 0.15})
	move("hero", 20.6, "hold_up", {"fade": 0.2})
	look("hero", 20.7, 24.0, Vector3(0.12, 1.25, -0.38))
	expr("hero", 21.0, "surprised")
	sfx_at(1.5, "phone_buzz", -4.0)
	sfx_at(5.2, "toang_sting", -1.0)
	sfx_at(8.0, "phone_buzz", -3.0)
	sfx_at(14.0, "boom", -4.0)
	sfx_at(17.6, "dun_dun_duun", -5.0)
	sfx_at(20.7, "phone_buzz", -3.0)
	sfx_at(21.3, "cliff_sting", -3.0)
	shot("S1", 0.0, "static", "wide: morning, reading the phone", {"pos": Vector3(2.4, 1.5, -3.2), "look": Vector3(0.0, 1.1, 0.0), "fov": 48.0})
	shot("S2", 1.4, "static", "close over the shoulder: the email", {"pos": Vector3(0.35, 1.7, 0.75), "look": Vector3(0.05, 1.1, -0.4), "fov": 40.0, "hand": 0.15})
	push_in("S3", 8.0, "hero", {"from": 3.0, "to": 2.1, "side_deg": 12.0, "hand": 0.2, "look_y": 1.2})
	hero_shot("S4", 12.4, "hero", {"side_deg": -25.0, "dist": 2.4})
	shot("S5", 17.4, "orbit", "orbit under the title card", {"center": Vector3(0.0, 1.0, 0.0), "radius": 3.2, "deg_from": 200.0, "deg_to": 160.0, "height": 1.5, "fov": 50.0})
	sub(9.2, 2.2, "hero", "Mình... bị đình chỉ thi á?!")
	sub(11.45, 1.7, "hero", "Mới được khen hôm qua mà...")
	sub(14.5, 2.9, "hero", "Được. Bảy ngày. Phải tìm ra kẻ cài cái kính đó!")
	sub(21.0, 2.5, "Số lạ (tin nhắn)", "Đừng đào sâu. Mày còn 7 ngày thôi.")
	joke(11.45, "Mới được khen hôm qua mà... with a facepalm")
	cliffhanger(21.0)
