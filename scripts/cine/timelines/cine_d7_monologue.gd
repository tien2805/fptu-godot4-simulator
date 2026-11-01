# File: res://scripts/cine/timelines/cine_d7_monologue.gd
# cine_d7_monologue (13.000 s, plan 2026-11-01-w4-day7.md T1, between boss phases 1 and 2): the vase gallery of Lọ
# Academy after the gunfight. Lùm Văn Lọ gets up at the back of the hall, dusts off the white suit, adjusts the gold glasses and
# smiles: "Mọi thứ đều nằm trong kế hoạch." He snaps his fingers; the breakers thunk, the gold lights die one by one and the
# last thing in the dark is his laugh from the speakers. The scene ends on black (the blackout phase starts in the dark).
# No ramps (story = real). Music slot cine_d7_monologue (owner file, else silence).
# Stage: the gallery hall of LairTower (28 x 24); played in StoryTower at LairTower.cine_xf (the real hall, drop_set). For
# XEM LẠI PHIM it carries the hall as a set (LairTower.cine_gallery_set, opts "set"). The stage dict is inline (Phase D
# stages are not in CineTimeline.PHASE_C_STAGES).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const LO_FROM := Vector3(0.0, 0.0, -9.6)
const LO := Vector3(0.0, 0.0, -8.4)
const HERO := Vector3(0.6, 0.0, -1.0)
const SNAP: float = 8.6
const DARK: float = 10.2

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "cine_d7_monologue"
	length = 13.0
	story_end = 13.0
	mood = "eerie"
	fade_in = 0.4
	fade_out = 0.8
	stage = {"at": Vector2(3930.0, -440.0), "size": Vector2(28.0, 24.0), "yaw_deg": 21.0, "landmark": "be6_center",
		"near": 30.0, "tod": "dawn", "exposure": 1.0, "ambient": 1.0}
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("lo", CastD7.opts("van_lo"), CastD7.SPEAKER, CastD7.COLOR)
	CastD7.dress(self, "lo")
	for d: Array in LairTower.cine_gallery_set():   # the hall for XEM LẠI PHIM (the tower shows the real one)
		var o: Dictionary = (d[4] as Dictionary).duplicate()
		o["set"] = true
		prop(String(d[0]), String(d[1]), d[2], float(d[3]), o)
	# Lọ gets up at the back of the hall, steps forward, the snap
	key("lo", 0.0, LO_FROM, 0.0)
	move("lo", 0.0, "winded")
	move("lo", 1.6, "idle", {"fade": 0.4})
	key("lo", 2.4, LO_FROM, 0.0)
	key("lo", 4.0, LO, 0.0)
	move("lo", 2.4, "walk", {"fade": 0.2})
	move("lo", 4.0, "present", {"fade": 0.3})
	move("lo", SNAP, "point", {"dur": 0.6, "fade": 0.1})
	move("lo", SNAP + 0.6, "arms_crossed", {"fade": 0.3})
	look("lo", 0.0, 13.0, "hero")
	expr("lo", 0.0, "angry")
	expr("lo", 4.0, "happy")
	# the protagonist, guard up
	key("hero", 0.0, HERO, CineTimeline.face(HERO, LO))
	move("hero", 0.0, "fight_idle")
	look("hero", 0.0, 13.0, "lo")
	expr("hero", 0.0, "angry")
	expr("hero", DARK, "surprised")
	sfx_at(0.4, "metal_creak", -10.0)
	sfx_at(SNAP, "impact_light", -6.0)
	sfx_at(SNAP + 0.5, "door_bang", -6.0)
	sfx_at(DARK, "whoosh_down", -8.0)
	if not calm:
		sfx_at(DARK + 0.6, "evil_laugh", -8.0)
	shot("S1", 0.0, "static", "wide over the plinths: Lọ gets up at the back of the hall",
		{"pos": Vector3(3.2, 1.7, 0.8), "look": Vector3(0.0, 1.1, -9.2), "fov": 46.0})
	push_in("S2", 4.0, "lo", {"from": 3.2, "to": 2.6, "side_deg": 15.0, "look_y": 1.3, "hand": 0.1})
	ots_shot("S3", 7.2, "hero", "lo", {"look_y": 1.35})
	shot("S4", DARK, "static", "the hall goes dark: only the red floor glow and the speaker rings",
		{"pos": Vector3(-4.0, 2.4, 2.0), "look": Vector3(0.0, 1.0, -6.0), "fov": 52.0})
	sub(4.3, 3.0, "lo", "Mọi thứ đều nằm trong kế hoạch.")
	sub(7.5, 1.4, "hero", "Kế hoạch gì nữa?")
	sub(9.0, 1.6, "lo", "Tắt đèn đi em.")
	joke(4.3, "Everything is going according to plan")
