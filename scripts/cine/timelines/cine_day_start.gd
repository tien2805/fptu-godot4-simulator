# File: res://scripts/cine/timelines/cine_day_start.gd
# cine_day_start (9.000 s, spec amendment A2-D17, story spec S-D15 / 8.4): ONE parameterized template for every morning of
# Days 1-7, at the BE6 lobby. The protagonist steps out of the lobby; StoryDayCard draws the calendar page
# "NGÀY N · CÒN M NGÀY" that tears off and falls (TEAR_AT); the phone buzzes with the day's first text, read with the phone
# held up. N, M and the text come from StoryDirector (its day, days_left() and the current beat's first text), falling back
# to Day 1 (StoryMissions.day_start_text) without a story, so the beat sheet is generated for Day 1. No ramps.
# Stage: StoryRoam sets "at" (the BE6 spawn) and "yaw_deg" (-Z away from the tower; the lobby door is behind at +Z).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const DOOR := Vector3(0.0, 0.0, 3.0)
const OUT := Vector3(0.2, 0.0, 0.6)

## Day number, days left and the day's first text (set in build()); StoryRoam hands days / left to StoryDayCard.
var days: int = 1
var left: int = 7
var sender: String = "Phúc"
var line: String = ""


func build() -> void:
	slot = "cine_day_start"
	length = 9.0
	story_end = 9.0
	mood = "playful"
	fade_in = 0.5
	fade_out = 0.5
	stage = {"landmark": "be6_center", "near": 70.0, "size": Vector2(8.0, 8.0), "tod": "morning"}
	_params()
	actor("hero", StoryUtil.hero_opts({"preset": "player", "seed": 2805}), StoryUtil.hero_name(), Color("#F37021"))
	key("hero", 0.0, DOOR, 0.0)
	key("hero", 2.2, OUT, 0.0, {"mode": "out"})
	move("hero", 0.0, "walk")
	move("hero", 2.2, "idle", {"fade": 0.2})
	look("hero", 2.4, 4.6, Vector3(0.0, 2.6, -3.0))   # up at the morning sky while the page tears off
	expr("hero", 3.6, "done")
	hold("hero", 4.9, 9.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	move("hero", 5.0, "hold_up", {"fade": 0.2})
	look("hero", 5.2, 9.0, Vector3(0.12, 1.25, 0.2))
	expr("hero", 5.8, "open")
	sfx_at(3.6, "whoosh_down", -6.0)   # the page tears off (StoryDayCard.TEAR_AT)
	sfx_at(4.9, "phone_buzz", -3.0)
	shot("S1", 0.0, "static", "wide: stepping out of the lobby, the page above", {"pos": Vector3(1.6, 1.4, -3.4), "look": Vector3(0.0, 1.4, 1.4), "fov": 52.0})
	push_in("S1b", 2.3, "hero", {"from": 3.6, "to": 2.4, "look_y": 1.2})   # Q5: in on "Hôm nay chắc yên bình..."
	shot("S2", 4.8, "static", "over the shoulder: the day's first text", {"pos": Vector3(0.55, 1.75, 1.6), "look": Vector3(0.12, 1.2, 0.3), "fov": 44.0, "hand": 0.15})
	# >= 0.06 s per character, never past the 9 s end (a longer text of a later day reads in 3.4 s)
	sub(2.5, 2.0, "hero", "Hôm nay chắc yên bình...")
	joke(2.5, "Hôm nay chắc yên bình... and the phone buzzes at once")
	sub(5.6, minf(3.4, maxf(3.0, 0.065 * float(line.length()))), sender + " (tin nhắn)", line)


## N / M / text from StoryDirector while a story runs (its current beat is the day's morning), else Day 1.
func _params() -> void:
	var sd: Node = StoryUtil.director()
	var t: Array = StoryMissions.day_start_text(1)
	if sd and bool(sd.get("active")) and int(sd.get("day")) >= 1:
		days = int(sd.get("day"))
		left = int(sd.call("days_left"))
		var b: Dictionary = sd.call("beat")
		var bt: Array = b.get("texts", [])
		t = bt[0] if not bt.is_empty() else StoryMissions.day_start_text(days)
	else:
		days = 1
		left = 7
	sender = String(t[0])
	line = StoryUtil.fmt(String(t[1]))
