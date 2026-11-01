# File: res://scripts/cine/timelines/night_ghost_boat.gd
# night_ghost_boat (14.000 s, plan 2026-11-01-w4-endings.md T4): the canal ghost boat, a night second chance at a missed
# piece of evidence (StoryNightSecrets "canal"). Midnight on the Rạch Hầm bank: a sampan with a green lantern glides in out
# of nowhere, a sheep-masked ferryman poling it. It stops at the bank; the ferryman's head SNAPS toward the protagonist
# (jump scare v2: scare_hit, twitch) and he holds out a wet folder: "Đồ của em... rơi dưới sông." - "Tiền đò năm nghìn.
# Chuyển khoản cũng được." - "Ma mà cũng chuyển khoản?" (ba-dum-tss); the boat glides off into the dark.
# "Giảm hù dọa" (read at build time): no scare hit, no whisper bed, the ferryman turns slowly.
# No ramps (story = real). Music slot night_tense (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("bridge") (the canal bank by the bridge, 14 x 10, night); the canal strip is carried.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 1.5)
const BOAT_Z: float = -1.3
const STOP := Vector3(-0.4, 0.02, BOAT_Z)
const STERN := Vector3(-1.2, 0.17, 0.0)   # the ferryman on the boat (boat-local, the boat keeps its yaw)
const SCARE: float = 6.0

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "night_ghost_boat"
	music_slot = "night_tense"
	length = 14.0
	story_end = 14.0
	mood = "eerie"
	fade_in = 0.8
	fade_out = 0.8
	stage = CineTimeline.phase_c_stage("bridge", "night")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("ferry", StoryCast.opts("clone_masked"), "Người lái đò", StoryCast.color("clone_masked"))
	prop("canal", "canal", Vector3(0.0, 0.0, -2.2), 0.0, {"set": true, "width": 16.0, "length": 5.4})
	var boat: Array = [[0.0, Vector3(-10.0, 0.02, BOAT_Z), Vector3.ZERO], [5.0, STOP, Vector3(0.0, 0.0, 1.5)],
		[10.6, STOP, Vector3(0.0, 0.0, -1.0)], [14.0, Vector3(7.0, 0.02, BOAT_Z), Vector3.ZERO]]
	prop("boat", "boat", boat[0][1], 0.0, {"path": boat})
	# the ferryman rides the stern (keyed along the boat path), facing the bow (+X) until he turns to the bank
	for k: Array in boat:
		key("ferry", float(k[0]), (k[1] as Vector3) + STERN, -90.0)
	var turn: float = CineTimeline.face(STOP + STERN, HERO)
	if calm:
		key("ferry", SCARE - 0.6, STOP + STERN, -90.0)
		key("ferry", SCARE + 0.4, STOP + STERN, turn)
	else:   # the snap: a head turn in 0.1 s at the hit
		key("ferry", SCARE - 0.05, STOP + STERN, -90.0)
		key("ferry", SCARE + 0.05, STOP + STERN, turn, {"mode": "linear"})
	key("ferry", 10.4, STOP + STERN, turn)
	key("ferry", 10.9, STOP + STERN, -90.0)
	move("ferry", 0.0, "idle")
	move("ferry", 6.5, "hold_up", {"fade": 0.2})
	move("ferry", 8.6, "idle", {"fade": 0.3})
	move("ferry", 9.0, "talk", {"fade": 0.2})
	move("ferry", 11.0, "nod", {"fade": 0.2})
	hold("ferry", 0.0, 14.0, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
	hold("ferry", 0.0, 6.4, "staff", {"offset": Vector3(0.0, 0.0, -0.05)})
	hold("ferry", 6.5, 8.5, "dossier", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.12)})
	look("ferry", SCARE, 10.4, "hero")
	# the protagonist on the bank
	key("hero", 0.0, HERO, CineTimeline.face(HERO, Vector3(-6.0, 0.0, BOAT_Z)))
	key("hero", 4.6, HERO, CineTimeline.face(HERO, STOP))
	move("hero", 0.0, "idle")
	move("hero", 6.0, "startled", {"fade": 0.08})
	move("hero", 8.3, "pickup", {"fade": 0.2})
	move("hero", 9.2, "idle", {"fade": 0.3})
	move("hero", 11.0, "shrug", {"fade": 0.2})
	hold("hero", 8.5, 14.0, "dossier", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.12)})
	look("hero", 0.0, 5.0, "ferry")
	look("hero", 5.1, 8.3, "ferry")
	look("hero", 8.4, 9.0, HERO + Vector3(0.1, 1.2, -0.4))
	look("hero", 9.1, 14.0, "ferry")
	expr("hero", 0.0, "open")
	expr("hero", SCARE, "surprised")
	expr("hero", 9.2, "done")
	expr("hero", 11.0, "happy")
	if not calm:
		sfx_at(0.4, "whisper_bed", -8.0)
	sfx_at(1.2, "chain_rattle", -16.0)
	for i: int in 3:
		sfx_at(3.4 + 0.8 * i, "heartbeat", -6.0 + 2.0 * i)
	if not calm:
		scare_hit(SCARE, {"twitch": "ferry", "hold": 0.4})
	sfx_at(11.2, "ba_dum_tss", -4.0)
	sfx_at(12.8, "dun_dun_duun", -6.0)
	shot("S1", 0.0, "static", "wide: midnight canal, a green lantern glides in out of the dark",
		{"pos": Vector3(3.2, 1.6, 3.4), "look": Vector3(-3.0, 0.9, BOAT_Z), "fov": 50.0})
	push_in("S2", 3.0, "hero", {"from": 2.6, "to": 2.1, "side_deg": 20.0, "look_y": 1.35})
	shot("S3", 5.6, "static", "the ferryman's sheep mask snaps toward the bank",
		{"pos": Vector3(0.2, 1.5, 0.4), "look": STOP + STERN + Vector3(0.0, 1.55, 0.0), "fov": 42.0})
	ots_shot("S4", 6.6, "hero", "ferry", {"side": 1.0})
	two_shot("S5", 8.8, "hero", "ferry", {"side": -1.0, "look_y": 1.2})
	shot("S6", 11.6, "static", "wide: the boat glides off, the protagonist holds the wet folder",
		{"pos": Vector3(-2.4, 1.5, 3.6), "look": Vector3(2.0, 0.9, BOAT_Z), "fov": 50.0})
	sub(1.4, 2.2, "hero", "Nửa đêm... ai chèo đò ở đây?")
	sub(6.6, 1.8, "ferry", "Đồ của em... rơi dưới sông.")
	sub(9.0, 2.0, "ferry", "Tiền đò năm nghìn. Chuyển khoản cũng được.")
	sub(11.1, 1.6, "hero", "Ma mà cũng chuyển khoản?")
	joke(9.0, "the ghost ferryman asks for the ferry fare, bank transfer accepted")
