# File: res://scripts/cine/timelines/cine_d1_choice_report.gd
# cine_d1_choice_report (4.500 s, spec B-D8 choice scene, branch tail of cine_d1_choice for choice 1 = "report"): same
# courtyard bench, same places. The protagonist calls Mr.T with the phone at the ear, "Alo, thầy ạ… em có chuyện cần báo.";
# Phúc slumps onto the bench, "…Ừ. Tao đáng bị vậy." (a soft sad trombone). No ramps. Music slot cine_d1_choice_report.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const BENCH := Vector3(0.0, 0.0, 1.2)
const HERO := Vector3(0.55, 0.0, 0.1)
const PHUC := Vector3(-0.5, 0.0, -0.35)
const SEAT := Vector3(-0.3, 0.0, 1.18)


func build() -> void:
	slot = "cine_d1_choice_report"
	length = 4.5
	story_end = 4.5
	mood = "eerie"
	fade_in = 0.3
	fade_out = 0.5
	stage = (load("res://scripts/cine/timelines/cine_d1_choice.gd") as GDScript).call("choice_stage")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	prop("bench", "bench", BENCH, 0.0)
	prop("lamp", "lamp", Vector3(2.2, 0.0, 1.6), 0.0, {"energy": 2.0})
	var y_away: float = CineTimeline.face(HERO, Vector3(2.0, 0.0, -1.0))
	key("hero", 0.0, HERO, CineTimeline.face(HERO, PHUC))
	key("hero", 0.5, HERO, y_away)
	move("hero", 0.0, "idle")
	move("hero", 0.35, "phone_call", {"fade": 0.25})
	hold("hero", 0.3, 4.5, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	expr("hero", 0.0, "done")
	expr("hero", 0.6, "talk")
	expr("hero", 2.9, "open")
	# Phúc turns away and sits down on the bench, head low
	key("phuc", 0.0, PHUC, CineTimeline.face(PHUC, HERO))
	key("phuc", 0.6, PHUC, 180.0)
	key("phuc", 1.3, SEAT, 180.0, {"mode": "out"})
	key("phuc", 1.75, SEAT, 0.0)
	move("phuc", 0.0, "confess")
	move("phuc", 0.6, "walk", {"fade": 0.2})
	move("phuc", 1.5, "sit_bench", {"fade": 0.4})
	look("phuc", 2.0, 4.5, Vector3(-0.3, 0.2, -1.5))
	expr("phuc", 0.0, "done")
	sfx_at(3.0, "sad_trombone", -10.0)
	shot("S1", 0.0, "static", "wide: the protagonist on the phone, Phúc turns to the bench",
		{"pos": Vector3(2.2, 1.55, -3.0), "look": Vector3(0.0, 1.0, 0.3), "fov": 48.0})
	shot("S2", 2.9, "static", "close: Phúc on the bench, head low",
		{"pos": Vector3(-0.3, 1.0, -0.6), "look": Vector3(-0.3, 0.9, 1.1), "fov": 40.0})
	sub(0.4, 2.5, "hero", "Alo, thầy ạ… em có chuyện cần báo.")
	sub(3.0, 1.4, "phuc", "…Ừ. Tao đáng bị vậy.")
