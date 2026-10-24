# File: res://scripts/cine/timelines/ai_intro.gd
# ai_intro – in-engine fallback (24.000 s, spec A2-D10, story spec 8.2): the next morning outside BE6. The protagonist reads
# the phone; StoryIntroCards draws the 2D cards on top at fixed real times (StoryIntroCards.CARDS): the email "Phòng Khảo thí:
# Quyết định đình chỉ thi", a huge red "TOANG!" stamp slamming onto it (toang_sting here at its slam time), Mr.T's text
# "Thầy tin em. Tìm bằng chứng đi.", a 7-day countdown flipping to 7, the title card "TOOL ĐEN – 7 ngày minh oan".
# When the owner's video user://video/ai_intro_m.ogv / ai_intro_f.ogv exists, StoryVideo plays it instead (StoryRoam).
# Music slot ai_intro (owner file user://music/ai_intro.ogg|.mp3, else a synthesized cue). No ramps (story = real).
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
	move("hero", 0.0, "idle")
	hold("hero", 0.0, 24.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	look("hero", 1.2, 12.0, Vector3(0.1, 1.05, -0.45))
	expr("hero", 1.2, "open")
	expr("hero", 5.2, "surprised")
	expr("hero", 8.2, "done")
	move("hero", 12.4, "head_shake")
	expr("hero", 13.2, "angry")
	look("hero", 13.0, 24.0, Vector3(0.0, 1.6, -5.0))
	move("hero", 17.6, "victory")
	move("hero", 19.6, "idle", {"fade": 0.3})
	sfx_at(1.5, "phone_buzz", -4.0)
	sfx_at(5.2, "toang_sting", -1.0)
	sfx_at(8.0, "phone_buzz", -3.0)
	sfx_at(14.0, "boom", -4.0)
	sfx_at(17.6, "dun_dun_duun", -5.0)
	shot("S1", 0.0, "static", "wide: morning, reading the phone", {"pos": Vector3(2.4, 1.5, -3.2), "look": Vector3(0.0, 1.1, 0.0), "fov": 48.0})
	shot("S2", 1.4, "static", "close over the shoulder: the email", {"pos": Vector3(0.35, 1.7, 0.75), "look": Vector3(0.05, 1.1, -0.4), "fov": 40.0, "hand": 0.15})
	shot("S3", 8.0, "static", "close: the face", {"pos": Vector3(0.3, 1.55, -1.1), "look": Vector3(0.0, 1.5, 0.0), "fov": 40.0, "hand": 0.2})
	shot("S4", 12.4, "static", "low hero shot: determined", {"pos": Vector3(-0.8, 0.7, -2.4), "look": Vector3(0.0, 1.4, 0.0), "fov": 46.0})
	shot("S5", 17.4, "orbit", "orbit under the title card", {"center": Vector3(0.0, 1.0, 0.0), "radius": 3.2, "deg_from": 200.0, "deg_to": 160.0, "height": 1.5, "fov": 50.0})
	sub(9.2, 2.2, "hero", "Mình… bị đình chỉ thi á?!")
	sub(14.6, 2.6, "hero", "Được. Bảy ngày. Phải tìm ra kẻ cài cái kính đó!")
