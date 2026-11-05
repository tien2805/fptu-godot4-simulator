# File: res://scripts/cine/timelines/cine_d3_mannequins.gd
# cine_d3_mannequins (9.000 s, spec C-D7 beats 4-5, C-D9 discovery beat + villain card): Day 3, the container yard at night.
# Six containers (two rows of three) stand in the dark; the middle one's door creaks open on rows of mannequins in smart
# glasses, their heads turned away. At 1.6 every head snaps to the camera at once (jump scare v2: scare_hit, the duck, the
# screen hit, the +8 dB sting) and the other five containers bang open: hundreds of red LEDs staring. Alexander ABCXYZ hops
# out of the middle container blowing a party horn: "Surprise!" - the frame freezes on his villain card (3.0-6.0 s real, Wave 6 T6: 4 -> 3 s, the scene 10 -> 9 s;
# StoryVillainCard: his endless name types on, runs off the band, then shrinks to fit: data "name_run"). Tail at 1x: he
# starts reciting the name again, "Ta là Alexander ABCXYZ DEFGH IJK..." - "Dài ghê." (the gunfight starts next).
# "Giảm hù dọa" (read at build time): the heads turn slowly over a second, the other doors swing open quietly, the scare mark
# plays its soft variant.
# Music slot cine_d3_mannequins (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("yard") (14 x 12), shared with seg_d3_boss and cine_d3; the containers are set dressing
# (drop_set inside the real yard scene), the mannequins inside them stay.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const CREAK: float = 0.3
const SCARE: float = 1.6
const POP: float = 2.05
const CARD_R: float = 3.0
const CARD_S: float = 3.0   # the card freeze (Wave 6: shorter than StoryCast.card_len; the tail carries the joke)
const HERO := Vector3(0.0, 0.0, 3.6)
const ALEX_FROM := Vector3(0.35, 0.0, 0.05)
const ALEX := Vector3(0.35, 0.0, 0.95)
const COLS: Array[float] = [-2.6, 0.0, 2.6]
const COLORS: Array[Color] = [Color("#2E5E8C"), Color("#9E3B2E"), Color("#3F7A4A")]

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "cine_d3_mannequins"
	length = 9.0
	var card_len: float = CARD_S
	story_end = length - card_len   # the card freeze adds card_len real seconds without story time
	mood = "eerie"
	fade_in = 0.4
	fade_out = 0.3
	stage = CineTimeline.phase_c_stage("yard")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("alex", StoryCast.opts("alexander"), StoryCast.speaker("alexander"), StoryCast.color("alexander"))
	StoryCast.dress(self, "alex", "alexander")
	for row: int in 2:
		for i: int in 3:
			var mid: bool = row == 0 and i == 1
			var y: float = CinePropsC.CONTAINER_H * row
			var open_at: float = CREAK if mid else SCARE + 0.03 * (i + 3 * row)
			prop("box%d%d" % [row, i], "container", Vector3(COLS[i], y, 0.0), 180.0, {"set": true, "anim": true, "color": COLORS[(i + row) % 3],
				"open_at": open_at, "open_dur": 1.3 if mid else (1.2 if calm else 0.3), "inner_light": mid})
			prop("crowd%d%d" % [row, i], "mannequins", Vector3(COLS[i], y + 0.08, -0.45), 180.0, {"anim": true, "cols": 5, "rows": 11,
				"dx": 0.42, "dz": 0.48, "turn_at": SCARE, "turn_from": 75.0, "turn_dur": 1.0 if calm else CineCrowd.TURN_DUR})
	villain("V1", CARD_R, card_len, StoryCast.villain_data("alexander"))
	var s_card: float = story_time("V1")
	# the protagonist creeps up, jumps at the scare, gapes at Alexander
	key("hero", 0.0, HERO + Vector3(0.0, 0.0, 0.9), 0.0)
	key("hero", 1.0, HERO, 0.0, {"mode": "out"})
	move("hero", 0.0, "walk")
	move("hero", 1.0, "idle", {"fade": 0.25})
	move("hero", SCARE, "startled", {"dur": 0.6, "fade": 0.05})
	move("hero", SCARE + 0.6, "idle", {"fade": 0.2})
	move("hero", s_card + 2.6, "facepalm", {"fade": 0.15})
	look("hero", 0.0, POP, Vector3(0.0, 1.5, -1.0))
	look("hero", POP, story_end, "alex")
	expr("hero", 0.0, "open")
	expr("hero", SCARE, "surprised")
	expr("hero", s_card + 2.4, "done")
	# Alexander hops out of the middle container blowing a party horn, then recites his name
	show("alex", 0.0, false)
	show("alex", POP, true)
	key("alex", POP, ALEX_FROM, 180.0)
	key("alex", POP + 0.35, ALEX, 180.0, {"mode": "linear", "arc": 0.3})
	move("alex", POP, "startled", {"dur": 0.35})
	move("alex", POP + 0.3, "blow", {"fade": 0.1})
	hold("alex", POP + 0.3, s_card + 0.3, "party_horn", {"bone": "Head", "offset": Vector3(0.0, 0.05, -0.115)})
	move("alex", s_card + 0.3, "talk", {"fade": 0.2})
	look("alex", POP, story_end, "hero")
	expr("alex", POP, "happy")
	expr("alex", s_card + 0.4, "talk")
	sfx_at(CREAK, "metal_creak", -2.0)
	sfx_at(0.9, "heartbeat", -4.0)
	scare_hit(SCARE, {})
	if not calm:
		sfx_at(SCARE + 0.05, "door_bang", -1.0)
		sfx_at(SCARE + 0.15, "door_bang", -4.0)
	else:
		sfx_at(SCARE + 0.1, "metal_creak", -8.0)
	sfx_at(POP + 0.3, "party_horn", 0.0)
	shot("S1", 0.0, "static", "over the protagonist's shoulder: six containers in the dark, the middle door creaks open",
		{"pos": Vector3(1.1, 1.7, 5.6), "look": Vector3(0.0, 1.7, -1.0), "fov": 52.0, "hand": 0.2})
	shot("S2", 0.9, "dolly", "push to the open door: rows of mannequins in smart glasses, heads turned away",
		{"from": Vector3(0.35, 1.6, 2.2), "to": Vector3(0.25, 1.6, 1.6), "look_from": Vector3(0.0, 1.5, -3.0),
		"look_to": Vector3(0.0, 1.55, -3.0), "fov": 46.0})
	shot("S3", SCARE - 0.2, "static", "at the door: every head snaps to the camera at once",
		{"pos": Vector3(0.0, 1.6, 0.4), "look": Vector3(0.0, 1.55, -1.2), "fov": 46.0})
	shot("S4", SCARE + 0.35, "static", "wide: all six containers open, hundreds of red LEDs staring",
		{"pos": Vector3(2.6, 1.9, 5.6), "look": Vector3(0.0, 2.5, -2.0), "fov": 60.0})
	# Q5: Alexander pops out "Surprise!"; the villain card freezes this frame while the dutch angle keeps pushing in
	dutch_shot("S5", POP, "alex", {"side_deg": 30.0, "dist": 3.2, "push": 0.2, "roll": 12.0, "look_y": 1.2})
	two_shot("S6", s_card + 0.12, "hero", "alex", {"side": 1.0, "look_y": 1.2})   # he recites his endless name again
	push_in("S7", s_card + 2.5, "hero", {"from": 2.8, "to": 2.3, "side_deg": 30.0, "look_y": 1.2})   # deadpan
	sub(0.12, 1.46, "hero", "Có ai trong đó không...?")
	sub(2.2, 0.75, "alex", "Surprise!")
	joke(2.2, "the horror reveal is Alexander with a party horn: Surprise!")
	sub(CARD_R + CARD_S + 0.1, 2.2, "alex", "Ta là Alexander ABCXYZ DEFGH IJK...")   # real s, right after the card
	sub(CARD_R + CARD_S + 2.4, 0.55, "hero", "Dài ghê.")
