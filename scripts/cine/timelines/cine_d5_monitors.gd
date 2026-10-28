# File: res://scripts/cine/timelines/cine_d5_monitors.gd
# cine_d5_monitors (10.000 s, spec C-D8 beat 4, C-D9 discovery beat): Day 5, the server basement under The Beverly tower.
# The protagonist creeps into a dark server room lit by a red emergency light; a wall of 50 monitors flickers on: Lê Minh Za
# Mẫn's face laughing on every screen (a code-drawn caricature: man bun, round glasses). The camera is right at one screen
# when the face snaps on it (jump scare v2: scare_hit, the duck, the screen hit, the +8 dB sting). "Ha ha ha! Chào mừng tới
# Lọ Thần 9.0!" - then every screen freezes on the blue "Lọ Thần đã gặp sự cố". "...Nó tự sập kìa."
# "Giảm hù dọa" (read at build time): the faces come on without the close snap (the camera stays wide), the laughs are
# 11 dB softer with no static burst, the scare mark plays its soft variant.
# No ramps (story = real). Music slot cine_d5_monitors (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("server") (14 x 10): the room, the racks and the monitor wall are carried; the room is
# set dressing (drop_set inside the real basement scene).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const FACE: float = 2.4
const SCARE: float = 3.3
const FREEZE: float = 6.4
const HERO_FROM := Vector3(0.0, 0.0, 3.6)
const HERO := Vector3(0.0, 0.0, 0.8)
const WALL := Vector3(0.0, 0.0, -4.7)
## Centre of the monitor in column 5, row 2 (the close scare shot looks right at it).
const MON := Vector3(-0.305, 1.525, -4.684)

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "cine_d5_monitors"
	length = 10.0
	story_end = 10.0
	mood = "eerie"
	fade_in = 0.6
	fade_out = 0.4
	stage = CineTimeline.phase_c_stage("server")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("za", StoryCast.opts("za_man"), StoryCast.speaker("za_man"), StoryCast.color("za_man"))
	show("za", 0.0, false)   # only on the screens (his subtitle colour)
	key("za", 0.0, Vector3(5.5, 0.0, 4.2), 0.0)
	server_room(self, true)
	prop("wall", "monitor_wall", WALL, 180.0, {"anim": true, "face_at": FACE, "freeze_at": FREEZE})
	key("hero", 0.0, HERO_FROM, 0.0)
	key("hero", 2.2, HERO, 0.0, {"mode": "out"})
	move("hero", 0.0, "walk", {"dur": 1.3})
	move("hero", 2.2, "idle", {"fade": 0.3})
	move("hero", SCARE, "startled", {"dur": 0.6, "fade": 0.05})
	move("hero", SCARE + 0.6, "idle", {"fade": 0.2})
	look("hero", 0.0, 10.0, Vector3(0.0, 1.5, -4.6))
	expr("hero", 0.0, "open")
	expr("hero", FACE, "surprised")
	expr("hero", FREEZE + 1.2, "done")
	sfx_at(0.3, "heartbeat", -6.0)
	var laugh_db: float = -11.0 if calm else 0.0   # "Giảm hù dọa": the laughs come in soft, no static burst
	if not calm:
		sfx_at(FACE, "static_burst", -6.0)
	sfx_at(FACE + 0.15, "evil_laugh", -3.0 + laugh_db)
	scare_hit(SCARE, {})
	sfx_at(4.0, "evil_laugh", -2.0 + laugh_db)
	sfx_at(5.6, "evil_laugh", -4.0 + laugh_db)
	sfx_at(FREEZE, "toang_sting", -2.0)
	shot("S1", 0.0, "static", "behind the protagonist: a dark server room, red emergency light, a dead wall of monitors",
		{"pos": Vector3(1.2, 1.7, 4.4), "look": Vector3(0.0, 1.4, -3.0), "fov": 52.0, "hand": 0.2})
	shot("S2", 2.25, "static", "low in front: the protagonist's face lit as the screens flicker on",
		{"pos": Vector3(0.3, 1.45, -0.55), "look": Vector3(0.0, 1.55, 0.8), "fov": 40.0})
	if calm:
		shot("S3", SCARE - 0.25, "static", "wide: fifty laughing faces (no close snap with Giảm hù dọa)",
			{"pos": Vector3(2.8, 1.4, 2.6), "look": Vector3(0.0, 1.5, -3.0), "fov": 56.0})
	else:
		shot("S3", SCARE - 0.25, "static", "right at one screen: the laughing face snaps on it",
			{"pos": MON + Vector3(0.0, 0.0, 0.62), "look": MON, "fov": 40.0})
		shot("S4", SCARE + 0.5, "static", "wide: the protagonist small against fifty laughing faces",
			{"pos": Vector3(2.8, 1.4, 2.6), "look": Vector3(0.0, 1.5, -3.0), "fov": 56.0})
	shot("S5", FREEZE - 0.1, "static", "the wall: every screen freezes on \"Lọ Thần đã gặp sự cố\"",
		{"pos": Vector3(0.0, 1.6, 0.0), "look": Vector3(0.0, 1.5, -4.6), "fov": 60.0})
	push_in("S6", 7.6, "hero", {"from": 2.6, "to": 2.2, "side_deg": 15.0, "look_y": 1.2})   # Q5: "...Nó tự sập kìa."
	sub(3.9, 2.2, "za", "Ha ha ha! Chào mừng tới Lọ Thần 9.0!")
	sub(7.8, 1.3, "hero", "...Nó tự sập kìa.")
	joke(7.8, "the evil tool crashes on its own: Lọ Thần đã gặp sự cố")


## The carried server room shared by the Day 5 slots: walls and ceiling (set dressing), two rows of racks along the sides
## (set dressing unless racks_set is false), stage-local. Racks face the middle aisle.
static func server_room(tl: CineTimeline, racks_set: bool = true) -> void:
	tl.prop("room", "server_room", Vector3.ZERO, 0.0, {"set": true, "width": 13.0, "depth": 9.3, "z1": 4.5})
	for i: int in 4:
		var z: float = -3.4 + 1.15 * i
		tl.prop("rack_l%d" % i, "server_rack", Vector3(-5.4, 0.0, z), -90.0, {"set": racks_set, "seed": i})
		tl.prop("rack_r%d" % i, "server_rack", Vector3(5.4, 0.0, z), 90.0, {"set": racks_set, "seed": i + 1})
