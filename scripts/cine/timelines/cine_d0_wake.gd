# File: res://scripts/cine/timelines/cine_d0_wake.gd
# cine_d0_wake (8.000 s, spec 2026-10-24-story-phase-a2-framework-design.md A2-D10): Day 0, 07:05, outside the BE6 lobby.
# The protagonist bursts out of the lobby with the phone alarm buzzing, stops dead (record scratch), looks left and right:
# "Tôi là ai, đây là đâu?". The phone buzzes again with Phúc's text "Ê!!! Thi EOS 8h đó, 7h05 rồi!!!"; panic, runs off.
# No slow-motion ramps (story time = real time). Stage: StoryRoam sets stage "at" (the BE6 spawn) and "yaw_deg" (the spawn's
# facing: -Z points away from the tower, the lobby door is behind at +Z); without them it searches near be6_center.
# Hero = the creator's protagonist (StoryUtil.hero_opts), named by {name}; no gendered pronoun anywhere.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const DOOR := Vector3(0.0, 0.0, 3.2)
const STOP := Vector3(0.0, 0.0, 0.4)
const EXIT := Vector3(-0.6, 0.0, -3.4)


func build() -> void:
	slot = "cine_d0_wake"
	length = 8.0
	story_end = 8.0
	mood = "playful"
	fade_in = 0.4
	fade_out = 0.4
	stage = {"landmark": "be6_center", "near": 70.0, "size": Vector2(8.0, 9.0), "tod": "morning"}
	actor("hero", StoryUtil.hero_opts({"preset": "player", "seed": 2805}), StoryUtil.hero_name(), Color("#F37021"))
	hold("hero", 0.0, 8.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})   # the alarm lights the screen
	key("hero", 0.0, DOOR, 0.0)
	key("hero", 1.3, STOP, 0.0, {"mode": "out"})
	move("hero", 0.0, "sprint")
	move("hero", 1.3, "idle", {"fade": 0.15})
	expr("hero", 1.35, "surprised")
	look("hero", 1.6, 2.5, Vector3(-3.0, 1.5, -1.0))
	look("hero", 2.5, 3.5, Vector3(3.0, 1.5, -1.0))
	expr("hero", 2.6, "open")
	look("hero", 3.8, 5.8, Vector3(0.0, 1.0, -0.4))
	expr("hero", 5.85, "surprised")
	move("hero", 5.9, "head_shake")
	key("hero", 6.25, STOP, 0.0)
	key("hero", 8.0, EXIT, 0.0, {"mode": "in"})
	move("hero", 6.3, "sprint", {"fade": 0.12})
	for t: float in [0.1, 0.75, 1.4]:
		sfx_at(t, "phone_buzz", -4.0)
	sfx_at(1.35, "record_scratch", -2.0)
	sfx_at(3.75, "phone_buzz", -2.0)
	sfx_at(5.85, "dun_dun_duun", -8.0)
	sfx_at(7.2, "slide_whistle", -9.0)
	shot("S1", 0.0, "static", "wide front: bursting out of the lobby", {"pos": Vector3(1.8, 1.3, -3.6), "look": Vector3(0.0, 1.0, 1.6), "fov": 55.0})
	shot("S2", 1.5, "static", "close: Tôi là ai, đây là đâu?", {"pos": Vector3(0.35, 1.55, -1.05), "look": Vector3(0.0, 1.5, 0.4), "fov": 40.0, "hand": 0.25})
	shot("S3", 3.7, "static", "over the shoulder: Phúc's text", {"pos": Vector3(0.5, 1.75, 1.35), "look": Vector3(0.0, 1.15, 0.2), "fov": 45.0})
	shot("S4", 5.8, "static", "close: panic", {"pos": Vector3(-0.3, 1.5, -1.2), "look": Vector3(0.0, 1.45, 0.3), "fov": 42.0, "hand": 0.35})
	shot("S5", 6.4, "static", "wide: running off to the race", {"pos": Vector3(3.0, 1.4, -5.2), "look": Vector3(0.0, 1.0, -1.0), "fov": 55.0})
	sub(1.6, 2.0, "hero", "Tôi là ai, đây là đâu?")
	sub(4.0, 1.8, "Phúc (tin nhắn)", "Ê!!! Thi EOS 8h đó, 7h05 rồi!!!")
	sub(5.95, 1.0, "hero", "CHẾT RỒI!!!")
	sub(7.0, 0.9, "hero", "Ét o ét…")
