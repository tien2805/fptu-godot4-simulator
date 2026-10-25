# File: res://scripts/cine/timelines/cine_d1_corridor.gd
# cine_d1_corridor (7.500 s, spec B-D5 beat 6, B-D8 discovery beat): the scripted end of the Day 1 corridor horror beat.
# A ground-floor campus corridor at night (the "corridor" set prop: walls, doors, tube lamps, exit sign), the protagonist
# creeping forward; a sheep-masked figure stands still at the far end; the tubes stutter, go dark (3.0-3.5); in the dark it
# comes close, and as the tubes come back on (3.5) its face, now the scare mask, snaps at the camera (jump scare v2:
# scare_hit, the 0.4 s duck inside the blackout, the screen hit, the FOV punch, the +8 dB sting, a 0.5 s twitch), then it
# is gone (4.0); a distorted bleat; heartbeat. Then Chú Bảy's shiba Lu trots up from behind and bonks the protagonist's
# calf (5.6): a startled hop, "Á!!!", and Chú Bảy calling the dog off-screen: the comic release.
# "Giảm hù dọa" (A2-D14 / B-D3, read at build time): no stutter, no blackout, no snap (the scare mark is a soft sting), one
# heartbeat; the figure leaves while the camera is on the protagonist's face, so it never pops out in view; the bleat plays
# at the reduced level.
# No ramps (story = real). Music slot cine_d1_corridor (owner file, else no music).
# Stage: explicit "at" in the ring courtyard, the corridor's long axis along the courtyard; a 4.5 x 16 m flat spot is all
# the set needs (it brings its own closed corridor, opts "set": true). Staged inside a real corridor (or the Night
# Building), pass stage "drop_set": true / play_cinematic opt "drop_set" so the carried walls are left out.
# Stage frame: X right, -Z forward (down the corridor), ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO_FROM := Vector3(0.1, 0.0, 1.5)
const HERO := Vector3(0.1, 0.0, 0.35)
const SHEEP := Vector3(-0.2, 0.0, -6.2)
## Where the figure stands when the tubes come back (1.5 m in front of the S3 camera, right of the protagonist).
const SHEEP_NEAR := Vector3(0.6, 0.0, -0.55)
const S3_CAM := Vector3(0.3, 1.6, 0.9)
const SCARE: float = 3.5
const GONE: float = 4.0
const DOG_FROM := Vector3(-0.9, 0.0, 2.65)    # just inside the closed +Z end, behind the S1 / S3 cameras
const DOG_AT := Vector3(-0.05, 0.0, 1.16)     # the lunge brings the skull onto the calf surface (test: gap 0..0.05 m)
## The set (z +3.0 to -6.8, |x| <= 1.72) lies inside the stage box (4.5 x 16, |z| <= 8).
const SET_Z0: float = 3.0
const SET_LEN: float = 9.8
const BONK: float = 5.6

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "cine_d1_corridor"
	length = 7.5
	story_end = 7.5
	mood = "eerie"
	fade_in = 0.6
	fade_out = 0.4
	stage = {"landmark": "campus_parking_center", "at": Vector2(-7.34, 7.06), "near": 30.0,   # ring courtyard (map point measured with cine_stage: ring 0)
		"size": Vector2(4.5, 16.0), "tod": "night", "yaw_deg": 271.0, "exposure": 1.3, "ambient": 1.1}
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("sheep", StoryCast.opts("clone_masked"), "???", StoryCast.color("clone_masked"))
	prop("corridor", "corridor", Vector3.ZERO, 0.0, {"len": SET_LEN, "z0": SET_Z0, "closed": true, "set": true, "width": 3.2, "lamps": 3,
		"flicker": [] if calm else [[1.0, 1.7], [2.6, 3.0]], "dark": [] if calm else [[3.0, 3.5]]})
	var dog_yaw: float = CineTimeline.face(DOG_FROM, DOG_AT)
	prop("dog", "shiba", DOG_FROM, dog_yaw, {"anim": [[0.0, "walk"], [5.2, "idle"], [5.28, "bonk"], [6.1, "idle"]], "show_at": 3.5,
		"path": [[3.6, DOG_FROM, Vector3(0.0, dog_yaw, 0.0)], [5.25, DOG_AT, Vector3(0.0, dog_yaw, 0.0)]]})
	# the protagonist creeps down the corridor, stops, stares
	key("hero", 0.0, HERO_FROM, 0.0)
	key("hero", 2.2, HERO, 0.0, {"mode": "out"})
	move("hero", 0.0, "walk", {"dur": 1.4})
	move("hero", 2.2, "idle", {"fade": 0.3})
	look("hero", 0.0, 5.4, SHEEP + Vector3(0.0, 1.5, 0.0))
	expr("hero", 0.0, "open")
	expr("hero", 2.4, "surprised")
	# bonk: a hop forward, turns round to the dog
	key("hero", BONK, HERO, 0.0)
	key("hero", BONK + 0.45, HERO + Vector3(0.0, 0.0, -0.35), 0.0, {"mode": "linear", "arc": 0.3})
	key("hero", BONK + 1.15, HERO + Vector3(0.0, 0.0, -0.35), 165.0)
	move("hero", BONK, "startled", {"dur": 0.6, "fade": 0.06})
	move("hero", BONK + 0.6, "idle", {"fade": 0.2})
	expr("hero", BONK, "surprised")
	expr("hero", BONK + 1.2, "done")
	look("hero", BONK + 1.1, 7.5, DOG_AT + Vector3(0.0, 0.3, 0.0))
	# the figure: there until the blackout (calm: until the camera is on the face, then gone); scary: close in the dark, its
	# scare-mask face snaps at the camera as the tubes come back, gone half a second later
	key("sheep", 0.0, SHEEP, CineTimeline.face(SHEEP, HERO))
	move("sheep", 0.0, "idle")
	if calm:
		hold("sheep", 0.0, 7.5, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
		show("sheep", 3.25, false)
	else:
		var near_yaw: float = CineTimeline.face(SHEEP_NEAR, Vector3(S3_CAM.x, 0.0, S3_CAM.z))
		var back: Vector3 = (SHEEP_NEAR - Vector3(S3_CAM.x, 0.0, S3_CAM.z)).normalized()
		hold("sheep", 0.0, 3.2, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
		hold("sheep", 3.2, GONE, "scare_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
		key("sheep", 3.1, SHEEP, CineTimeline.face(SHEEP, HERO))
		key("sheep", 3.2, SHEEP_NEAR + back * 0.45, near_yaw, {"mode": "linear"})   # moved up in the dark
		key("sheep", SCARE - 0.02, SHEEP_NEAR + back * 0.45, near_yaw)
		key("sheep", SCARE + 0.07, SHEEP_NEAR - back * 0.07, near_yaw, {"mode": "linear"})   # the snap, a little past
		key("sheep", SCARE + 0.14, SHEEP_NEAR, near_yaw)
		show("sheep", GONE, false)
	sfx_at(0.4, "heartbeat", -6.0)
	if not calm:
		sfx_at(1.0, "fluoro_buzz", -8.0)
		sfx_at(1.3, "heartbeat", -3.0)
		sfx_at(2.2, "heartbeat", -1.0)
		sfx_at(3.0, "fluoro_buzz", -6.0)
	scare_hit(SCARE, {"twitch": "sheep", "hold": 0.5})
	sfx_at(3.6, "sheep_bleat_distorted", -2.0)
	sfx_at(4.6, "breath", -8.0)
	sfx_at(BONK, "bonk", 0.0)
	sfx_at(BONK + 0.1, "slide_whistle", -10.0)
	shot("S1", 0.0, "static", "over the shoulder down the corridor: the sheep figure at the far end",
		{"pos": Vector3(0.65, 1.7, 2.6), "look": Vector3(-0.2, 1.3, -6.0), "fov": 42.0, "hand": 0.3})
	shot("S2", 2.4, "static", "close: the protagonist's face",
		{"pos": Vector3(0.35, 1.6, -0.75), "look": Vector3(0.1, 1.55, 0.35), "fov": 38.0, "hand": 0.3})
	if calm:
		shot("S3", 3.4, "static", "the protagonist's view: the corridor is empty",
			{"pos": Vector3(0.3, 1.6, 0.9), "look": Vector3(-0.2, 1.3, -6.0), "fov": 40.0, "hand": 0.2})
	else:
		shot("S3", 3.0, "static", "the protagonist's view: the tubes go dark, come back, the corridor is empty",
			{"pos": Vector3(0.3, 1.6, 0.9), "look": Vector3(-0.2, 1.3, -6.0), "fov": 40.0, "hand": 0.2})
	shot("S4", 4.4, "static", "low behind the protagonist: Lu trots in and bonks a calf",
		{"pos": Vector3(1.35, 0.55, 2.6), "look": Vector3(0.0, 0.55, 0.6), "fov": 50.0})
	shot("S5", 6.0, "static", "two-shot: the protagonist and Lu, tail wagging",
		{"pos": Vector3(1.25, 1.2, -1.0), "look": Vector3(-0.1, 0.7, 0.5), "fov": 50.0})
	sub(0.9, 1.3, "hero", "Có ai… ở đó không?")
	sub(BONK + 0.1, 0.5, "hero", "Á!!!")
	sub(6.2, 1.3, "Chú Bảy", "Lu! Về đây, đừng phá!")
