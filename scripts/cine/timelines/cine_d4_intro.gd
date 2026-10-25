# File: res://scripts/cine/timelines/cine_d4_intro.gd
# cine_d4_intro (14.000 s, spec B-D7 beat 2, B-D8 mission intro, story spec 8.4): Day 4, noon, the canteen. Linh, arms
# crossed, pitches the undercover plan to the protagonist: Dolly hides among the identical clones (two of them eat at a
# table behind), so they carry trays like customers and spot the real one. Then the "distracted boyfriend" situation,
# re-staged with our own cast only: Phúc, tray in hand next to Linh, turns right round to stare at a yellow "THI HỘ BAO
# ĐẬU" flyer on a stand while Linh glares at him (record scratch), "Phúc!!!" / "Tao… chỉ đọc thôi mà!" (ba-dum-tss), and
# Linh snaps everyone back to work. No ramps (story = real). Music slot cine_d4_intro (synthesized default, playful).
# Stage: explicit "at" at the canteen (FPTUCampusBuilder.canteen_center), stage -Z toward D1 (into the hall).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(1.75, 0.0, 1.35)
const LINH := Vector3(0.75, 0.0, 0.05)
const PHUC := Vector3(0.0, 0.0, 0.0)
const FLYER := Vector3(-1.9, 0.0, -0.9)
const FAR_TABLE := Vector3(-2.2, 0.0, -3.6)
const CLONE_A := Vector3(-2.6, 0.0, -4.2)
const CLONE_B := Vector3(-1.8, 0.0, -4.2)
const GAG: float = 6.9

## Background extras (the two clones at the far table): close shots may cover them (tests/test_story_cines.gd occlusion).
var extras: Array[String] = ["clone_a", "clone_b"]


func build() -> void:
	slot = "cine_d4_intro"
	length = 14.0
	story_end = 14.0
	mood = "playful"
	fade_in = 0.5
	fade_out = 0.5
	stage = {"landmark": "campus_parking_center", "at": CineTimeline.campus_at(FPTUCampusBuilder.canteen_center()), "near": 24.0,
		"size": Vector2(10.0, 9.0), "tod": "noon", "yaw_deg": CineTimeline.campus_yaw(0.0)}
	for id: String in ["hero", "linh", "phuc"]:
		actor(id, StoryCast.opts(id), StoryCast.speaker(id), StoryCast.color(id))
	actor("clone_a", StoryCast.opts("clone"), StoryCast.speaker("clone"), StoryCast.color("clone"))
	actor("clone_b", StoryCast.opts("clone"), StoryCast.speaker("clone"), StoryCast.color("clone"))
	prop("flyer", "flyer", FLYER, CineTimeline.face(FLYER, Vector3(0.6, 0.0, 2.6)))
	prop("table", "table", FAR_TABLE, 0.0)
	prop("stool_a", "stool", CLONE_A, 0.0)
	prop("stool_b", "stool", CLONE_B, 0.0)
	prop("counter", "counter", Vector3(2.6, 0.0, -3.4), 0.0, {"len": 3.0})
	# Linh pitches, the protagonist listens
	var y_lh: float = CineTimeline.face(LINH, HERO)
	key("linh", 0.0, LINH, y_lh)
	move("linh", 0.0, "arms_crossed")
	move("linh", 3.1, "talk", {"fade": 0.3})
	move("linh", GAG + 0.6, "arms_crossed", {"fade": 0.3})
	move("linh", 11.0, "point", {"fade": 0.25})
	move("linh", 12.6, "arms_crossed", {"fade": 0.3})
	look("linh", 0.0, GAG + 0.3, "hero")
	look("linh", GAG + 0.5, 10.8, "phuc")
	look("linh", 11.0, 14.0, "hero")
	expr("linh", 0.4, "talk")
	expr("linh", GAG + 0.5, "angry")
	expr("linh", 11.0, "talk")
	key("hero", 0.0, HERO, CineTimeline.face(HERO, LINH))
	move("hero", 0.0, "idle")
	look("hero", 0.0, GAG, "linh")
	look("hero", GAG + 0.2, 10.8, "phuc")
	look("hero", 11.0, 14.0, "linh")
	expr("hero", 0.0, "open")
	expr("hero", GAG + 1.0, "done")
	move("hero", 12.0, "nod", {"fade": 0.15})
	move("hero", 12.8, "idle", {"fade": 0.2})
	# Phúc, tray in both hands, turns right round to the flyer: the distracted-boyfriend situation
	var y_pl: float = CineTimeline.face(PHUC, HERO)
	var y_fl: float = CineTimeline.face(PHUC, FLYER)
	key("phuc", 0.0, PHUC, y_pl)
	key("phuc", GAG, PHUC, y_pl)
	key("phuc", GAG + 0.45, PHUC, y_fl + 55.0)   # turns his body most of the way, the head does the rest
	move("phuc", 0.0, "tray_hold")
	hold("phuc", 0.0, 14.0, "tray", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.12), "food": true})
	look("phuc", 0.0, GAG, "hero")
	look("phuc", GAG + 0.2, 9.0, FLYER + Vector3(0.0, 1.0, 0.0))
	look("phuc", 9.1, 11.0, "linh")
	look("phuc", 11.1, 14.0, "hero")
	expr("phuc", 0.0, "open")
	expr("phuc", GAG + 0.3, "happy")
	expr("phuc", 8.6, "surprised")
	expr("phuc", 9.3, "talk")
	# the clones at the far table eat in perfect sync
	for id: String in ["clone_a", "clone_b"]:
		var at: Vector3 = CLONE_A if id == "clone_a" else CLONE_B
		key(id, 0.0, at, 180.0)
		move(id, 0.0, "eat_sit")
		expr(id, 0.0, "open")
	sfx_at(GAG + 0.5, "record_scratch", -4.0)
	sfx_at(10.6, "ba_dum_tss", -5.0)
	shot("S1", 0.0, "static", "wide: the canteen at noon, Linh pitches the plan, two identical clones eat behind",
		{"pos": Vector3(4.4, 1.7, 3.0), "look": Vector3(0.0, 1.1, -0.6), "fov": 52.0})
	shot("S2", 3.0, "static", "close: Linh, sharp",
		{"pos": Vector3(1.5, 1.6, 1.0), "look": Vector3(0.75, 1.5, 0.05), "fov": 38.0, "hand": 0.15})
	shot("S3", GAG - 0.2, "static", "front: the flyer on the left, Phúc turned to it, Linh glaring at him (the meme situation)",
		{"pos": Vector3(0.0, 1.5, 3.6), "look": Vector3(-0.35, 1.25, -0.2), "fov": 46.0})
	shot("S4", 9.1, "static", "close: Phúc caught",
		{"pos": Vector3(0.7, 1.55, 1.0), "look": Vector3(0.0, 1.5, 0.0), "fov": 38.0})
	shot("S5", 10.8, "static", "wide three-shot: back to work",
		{"pos": Vector3(3.6, 1.6, 3.8), "look": Vector3(0.6, 1.15, 0.3), "fov": 48.0})
	sub(0.4, 2.6, "linh", "Dolly trốn giữa đám nhân bản ở căn tin.")
	sub(3.2, 3.1, "linh", "Mình bưng khay giả làm khách, tìm ra con thật.")
	sub(GAG + 1.3, 0.8, "linh", "Phúc!!!")
	sub(9.2, 1.5, "phuc", "Tao… chỉ đọc thôi mà!")
	sub(11.0, 2.4, "linh", "Tập trung! Bưng khay lên, bắt đầu.")
