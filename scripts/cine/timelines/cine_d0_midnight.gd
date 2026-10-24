# File: res://scripts/cine/timelines/cine_d0_midnight.gd
# cine_d0_midnight (22.000 s, spec A2-D10, story spec Day 0 horror beat): night, the bench outside the BE6 lobby. The
# protagonist cannot sleep (heartbeat, breath); the backpack starts glowing red from inside, a whisper "Lọ… Thần…", the
# lobby lamp flickers; a white face rises behind the bench (violin screech + camera punch) – it is Phúc in a sheet mask
# slurping instant noodles: "Ủa, chưa ngủ hả?" (ba-dum-tss); then the protagonist pulls a pair of smart glasses that are not
# theirs out of the backpack (dun dun duun). "Giảm hù dọa" (A2-D14, read at build time): no screech, no punch, no flicker.
# No ramps (story = real). Stage: StoryRoam sets "at" (the BE6 spawn) and "yaw_deg"; fallback near be6_center. Night with
# exposure x1.5 / ambient x2 so faces stay readable.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const SEAT := Vector3(-0.25, 0.42, 0.0)      # sitting on the bench (the "slumped" sit raised to seat height)
const BAG := Vector3(0.45, 0.455, -0.02)
const PHUC_LOW := Vector3(0.05, -1.1, 1.05)  # hidden behind the bench back
const PHUC_UP := Vector3(0.05, 0.0, 1.05)
const LAMP := Vector3(1.9, 0.0, 0.9)

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "cine_d0_midnight"
	length = 22.0
	story_end = 22.0
	mood = "eerie"
	fade_in = 0.8
	fade_out = 0.6
	stage = {"landmark": "be6_center", "near": 70.0, "size": Vector2(8.0, 8.0), "tod": "night", "exposure": 1.5, "ambient": 2.0}
	actor("hero", StoryUtil.hero_opts({"preset": "player", "seed": 2805}), StoryUtil.hero_name(), Color("#F37021"))
	actor("phuc", {"preset": "student_m", "seed": 77, "hair_style": "spiky"}, "Phúc", Color("#FF9A3C"))
	prop("bench", "bench", Vector3(0.0, 0.0, 0.0))
	prop("bag", "backpack", BAG, 0.0, {"glow_at": 5.5})
	prop("lamp", "lamp", LAMP, 0.0, {"flicker": [] if calm else [[6.2, 7.4], [8.1, 8.7], [9.5, 10.1]]})
	# the protagonist, awake on the bench
	key("hero", 0.0, SEAT, 0.0)
	move("hero", 0.0, "slumped")
	expr("hero", 0.0, "open")
	expr("hero", 2.6, "closed")
	expr("hero", 4.2, "open")
	look("hero", 5.6, 8.6, BAG + Vector3(0.0, 0.3, 0.0))
	expr("hero", 6.0, "surprised")
	expr("hero", 10.0, "surprised")
	look("hero", 10.1, 13.6, "phuc")
	expr("hero", 12.6, "angry")
	look("hero", 14.2, 17.8, BAG + Vector3(-0.2, 0.4, -0.3))
	hold("hero", 15.2, 22.0, "glasses", {"offset": Vector3(0.0, 0.03, -0.03)})
	expr("hero", 16.0, "surprised")
	expr("hero", 19.6, "done")
	look("hero", 18.4, 22.0, "phuc")
	# Phúc rises behind the bench in a white sheet mask, slurping noodles
	key("phuc", 0.0, PHUC_LOW, 0.0)
	key("phuc", 9.0, PHUC_LOW, 0.0)
	key("phuc", 10.0, PHUC_UP, 0.0, {"mode": "out"})
	show("phuc", 0.0, false)
	show("phuc", 9.0, true)
	move("phuc", 0.0, "idle")
	hold("phuc", 0.0, 22.0, "face_mask", {"bone": "Head", "offset": Vector3(0.0, 0.02, 0.0)})
	hold("phuc", 0.0, 22.0, "noodles", {"offset": Vector3(0.0, 0.0, -0.03)})
	look("phuc", 10.0, 22.0, "hero")
	expr("phuc", 10.6, "talk")
	expr("phuc", 12.6, "happy")
	expr("phuc", 19.0, "talk")
	for i: int in 6:
		sfx_at(1.0 + 0.9 * i, "heartbeat", -2.0 + float(i))
	sfx_at(3.2, "breath", -6.0)
	sfx_at(5.9, "whisper_bed", -3.0)
	sfx_at(9.0, "heartbeat", 0.0)
	sfx_at(9.55, "heartbeat", 1.0)
	if not calm:
		sfx_at(10.0, "violin_screech", -3.0)
		punch(10.0, "heavy")
	sfx_at(12.4, "ba_dum_tss", -3.0)
	sfx_at(16.0, "dun_dun_duun", -2.0)
	shot("S1", 0.0, "static", "wide: the bench at night", {"pos": Vector3(3.4, 1.6, -3.8), "look": Vector3(0.0, 0.8, 0.3), "fov": 50.0})
	shot("S2", 2.0, "static", "close: cannot sleep", {"pos": Vector3(0.35, 1.05, -1.25), "look": Vector3(-0.2, 0.95, 0.0), "fov": 38.0, "hand": 0.15})
	shot("S3", 5.4, "static", "close: the backpack glows red", {"pos": Vector3(1.0, 0.95, -0.8), "look": Vector3(0.45, 0.6, 0.0), "fov": 36.0})
	shot("S4", 8.8, "static", "low front two-shot: the face rises behind", {"pos": Vector3(0.15, 0.9, -2.6), "look": Vector3(0.0, 1.2, 0.8), "fov": 46.0})
	shot("S5", 13.8, "static", "close: glasses that are not theirs", {"pos": Vector3(0.45, 1.1, -0.8), "look": Vector3(-0.1, 0.85, -0.15), "fov": 32.0})
	shot("S6", 18.6, "static", "wide: deadpan", {"pos": Vector3(3.0, 1.5, -3.2), "look": Vector3(0.0, 0.9, 0.5), "fov": 48.0})
	sub(1.5, 2.0, "hero", "…Không ngủ được.")
	sub(6.3, 2.4, "???", "Lọ… Thần…")
	sub(10.6, 1.8, "phuc", "Ủa, chưa ngủ hả?")
	sub(12.7, 1.4, "hero", "Phúc!!! Hết hồn!!!")
	sub(16.3, 2.3, "hero", "…Kính ai đây? Đâu phải của mình…")
	sub(19.0, 2.4, "phuc", "Kính xịn vậy, cho tao mượn đeo thử coi!")
