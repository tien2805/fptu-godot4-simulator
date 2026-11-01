# File: res://scripts/cine/timelines/night_lift13.gd
# night_lift13 (13.000 s, plan 2026-11-01-w4-endings.md T4): the BE6 lift that stops at floor 13, a night second chance at
# a missed piece of evidence (StoryNightSecrets "lift"). Midnight in the BE6 lobby: the lift comes down by itself, the
# floor display counts 9, 12... 13 ("BE6 làm gì có tầng 13..."). The doors slide open on a dark cabin: a sheep-masked
# figure stands inside and lunges (jump scare v2: scare_hit, twitch) - it is Phúc: "Prank thôi mà! Hết hồn chưa?"
# (ba-dum-tss). He hands over a folder: "Tao nhặt trên tầng 13. Của mày phải không?" - "...Tầng 13 ở đâu ra vậy?"
# (dun dun duun). "Giảm hù dọa" (read at build time): no scare hit, no whisper bed, Phúc steps out slowly.
# No ramps (story = real). Music slot night_tense (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("duy_room") (the BE6 lobby corner, 8 x 8, night); the lift front is carried.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 0.9)
const LIFT := Vector3(0.0, 0.0, -1.6)       # the lift front (yaw 180: its face toward the protagonist, the cabin behind)
const DOOR_Z: float = -1.7
const IN_CAB := Vector3(0.0, 0.0, -2.5)
const OUT := Vector3(0.0, 0.0, -0.3)
const OPEN: float = 4.8
const SCARE: float = 5.6

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "night_lift13"
	music_slot = "night_tense"
	length = 13.0
	story_end = 13.0
	mood = "eerie"
	fade_in = 0.8
	fade_out = 0.8
	stage = CineTimeline.phase_c_stage("duy_room", "night")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	prop("lift", "lift_frame", LIFT, 180.0, {"set": true})
	for side: float in [-1.0, 1.0]:
		var shut := Vector3(0.3 * side, 0.0, DOOR_Z)
		var open := Vector3(0.9 * side, 0.0, DOOR_Z)
		prop("door_%s" % ("l" if side < 0.0 else "r"), "lift_door", shut, 180.0, {"path": [[0.0, shut, Vector3(0.0, 180.0, 0.0)],
			[OPEN, shut, Vector3(0.0, 180.0, 0.0)], [OPEN + 0.7, open, Vector3(0.0, 180.0, 0.0)]]})
	# the floor display above the doors counts down to a floor that does not exist
	var floors: Array = [["9", 0.0, 1.4], ["12", 1.4, 2.8], ["13", 2.8, 13.0]]
	for f: Array in floors:
		prop("floor_%s" % String(f[0]), "sign", Vector3(0.0, 2.62, -1.38), 180.0, {"text": String(f[0]), "width": 0.42,
			"color": Color("#3A0A0A") if String(f[0]) == "13" else Color("#1A1C20"), "show_at": float(f[1]), "hide_at": float(f[2])})
	# Phúc in a sheep mask inside the dark cabin
	key("phuc", 0.0, IN_CAB, 180.0)
	if calm:
		key("phuc", SCARE, IN_CAB, 180.0)
		key("phuc", SCARE + 1.2, OUT + Vector3(0.0, 0.0, -0.4), 180.0, {"mode": "out"})
		move("phuc", SCARE, "walk", {"fade": 0.2})
	else:   # the lunge: out of the cabin in 0.15 s at the hit
		key("phuc", SCARE - 0.05, IN_CAB, 180.0)
		key("phuc", SCARE + 0.12, OUT + Vector3(0.0, 0.0, -0.4), 180.0, {"mode": "linear"})
	move("phuc", 0.0, "idle")
	move("phuc", SCARE + 1.2, "laugh", {"fade": 0.15})
	move("phuc", 8.8, "hold_up", {"fade": 0.2})
	move("phuc", 10.4, "shrug", {"fade": 0.2})
	hold("phuc", 0.0, 7.0, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
	hold("phuc", 7.0, 13.0, "sheep_mask", {"bone": "Wrist.R", "offset": Vector3(0.0, 0.0, -0.08)})
	hold("phuc", 8.8, 10.0, "dossier", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.12)})
	look("phuc", OPEN, 13.0, "hero")
	expr("phuc", 7.0, "happy")
	expr("phuc", 10.4, "open")
	# the protagonist waits in front of the lift
	key("hero", 0.0, HERO, 0.0)
	move("hero", 0.0, "idle")
	move("hero", SCARE, "startled", {"fade": 0.08})
	move("hero", 7.4, "facepalm", {"fade": 0.15})
	move("hero", 9.8, "pickup", {"fade": 0.2})
	move("hero", 10.6, "idle", {"fade": 0.3})
	hold("hero", 10.0, 13.0, "dossier", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.12)})
	look("hero", 0.0, 3.6, Vector3(0.0, 2.62, -1.38))
	look("hero", 3.7, 13.0, "phuc")
	expr("hero", 0.0, "open")
	expr("hero", 2.8, "surprised")
	expr("hero", 7.4, "angry")
	expr("hero", 11.2, "done")
	sfx_at(0.2, "fluoro_buzz", -14.0)
	if not calm:
		sfx_at(1.6, "whisper_bed", -8.0)
	for i: int in 3:
		sfx_at(2.9 + 0.7 * i, "heartbeat", -6.0 + 2.0 * i)
	sfx_at(OPEN, "door_bang", -16.0)
	if not calm:
		scare_hit(SCARE, {"twitch": "phuc", "hold": 0.4})
	sfx_at(7.6, "ba_dum_tss", -4.0)
	sfx_at(11.6, "dun_dun_duun", -5.0)
	shot("S1", 0.0, "static", "wide: the dark BE6 lobby, the lift display counts down by itself",
		{"pos": Vector3(1.8, 1.6, 3.0), "look": Vector3(0.0, 1.8, -1.6), "fov": 50.0})
	shot("S2", 2.6, "dolly", "push-in on the display: 13", {"from": Vector3(0.4, 1.9, 0.6), "to": Vector3(0.25, 2.2, -0.2),
		"look_from": Vector3(0.0, 2.5, -1.4), "look_to": Vector3(0.0, 2.6, -1.4), "fov": 40.0})
	shot("S3", 4.6, "static", "over the shoulder: the doors slide open on a dark cabin",
		{"pos": Vector3(0.5, 1.6, 2.0), "look": Vector3(0.0, 1.3, -2.2), "fov": 46.0})
	two_shot("S4", 7.2, "phuc", "hero", {"side": 1.0, "look_y": 1.25})
	push_in("S5", 10.8, "hero", {"from": 2.4, "to": 2.0, "side_deg": -20.0, "look_y": 1.3})
	sub(0.8, 1.8, "hero", "Thang máy... tự chạy?")
	sub(3.0, 1.8, "hero", "Tầng 13? BE6 làm gì có tầng 13...")
	sub(7.4, 1.8, "phuc", "Prank thôi mà! Hết hồn chưa?")
	sub(9.0, 1.8, "phuc", "Tao nhặt trên tầng 13. Của mày phải không?")
	sub(11.0, 1.8, "hero", "...Tầng 13 ở đâu ra vậy?")
	joke(7.4, "the ghost in the lift is Phúc pranking in a sheep mask")
