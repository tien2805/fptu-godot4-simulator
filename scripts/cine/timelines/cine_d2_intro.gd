# File: res://scripts/cine/timelines/cine_d2_intro.gd
# cine_d2_intro (14.000 s, spec C-D6 beat 2, C-D9 mission intro): Day 2, night, Anh Duy's corner by the BE6 lobby of The
# Beverly. Anh Duy "Deploy" (big belly, faded FPT hoodie, headphones, key lanyard) types at three glowing laptops, an
# energy drink by his hand; the protagonist walks up and looks over his shoulder. He traces the Bầy Sói route; every jargon
# line carries its "Dịch:" translation. The protagonist turns to go: "Tới công chuyện luôn!" (the chase starts next).
# No ramps (story = real). Music slot cine_d2_intro (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("duy_room") (8 x 8; the desk, the laptops and a lobby wall are carried; the wall is
# set dressing, drop_set leaves it out inside a real room).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const DESK := Vector3(0.0, 0.0, 0.0)
const DUY := Vector3(0.0, 0.0, -0.72)          # seated in front of the desk, facing it (+Z)
const HERO_FROM := Vector3(2.9, 0.0, -2.3)
const HERO := Vector3(0.78, 0.0, -1.42)        # behind Anh Duy's left shoulder, looking at the screens
const EXIT := Vector3(3.2, 0.0, -2.6)


func build() -> void:
	slot = "cine_d2_intro"
	length = 14.0
	story_end = 14.0
	mood = "playful"
	fade_in = 0.5
	fade_out = 0.5
	stage = CineTimeline.phase_c_stage("duy_room")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("duy", StoryCast.opts("anh_duy"), StoryCast.speaker("anh_duy"), StoryCast.color("anh_duy"))
	StoryCast.dress(self, "duy", "anh_duy")
	prop("wall", "lobby_wall", Vector3(0.0, 0.0, 2.2), 180.0, {"set": true, "width": 7.0})
	prop("desk", "desk", DESK, 0.0)
	prop("chair", "stool", DUY + Vector3(0.0, 0.0, -0.05), 0.0)
	for i: int in 3:
		prop("laptop%d" % i, "laptop", Vector3(-0.48 + 0.48 * i, 0.75, 0.05 + 0.08 * absf(i - 1.0)), 18.0 * (i - 1.0), {"glow_at": 0.0})
	prop("can", "energy_drink", Vector3(0.62, 0.81, -0.12), 0.0, {"hide_at": 8.1})
	# Anh Duy types, grabs the can for a sip (8.1-9.6), types on
	key("duy", 0.0, DUY, 180.0)
	move("duy", 0.0, "type_sit")
	move("duy", 8.0, "sit_bench_hold", {"fade": 0.25})
	hold("duy", 8.1, 9.7, "energy_drink", {"offset": Vector3(0.0, -0.02, -0.05)})
	move("duy", 9.7, "type_sit", {"fade": 0.25})
	prop("can_back", "energy_drink", Vector3(0.62, 0.81, -0.12), 0.0, {"show_at": 9.7})
	look("duy", 0.0, 4.3, Vector3(0.0, 0.95, 0.1))
	look("duy", 4.4, 5.9, "hero")
	look("duy", 6.0, 14.0, Vector3(0.0, 0.95, 0.1))
	expr("duy", 0.0, "open")
	expr("duy", 4.6, "happy")
	expr("duy", 6.2, "open")
	# the protagonist walks up, watches the screens, then turns to go
	var y_in: float = CineTimeline.face(HERO_FROM, HERO)
	key("hero", 0.0, HERO_FROM, y_in)
	key("hero", 1.7, HERO, y_in, {"mode": "out"})
	key("hero", 2.2, HERO, CineTimeline.face(HERO, DESK + Vector3(0.0, 0.0, 0.3)))
	move("hero", 0.0, "walk")
	move("hero", 1.7, "idle", {"fade": 0.25})
	move("hero", 2.6, "arms_crossed", {"fade": 0.3})
	look("hero", 1.8, 12.0, Vector3(0.0, 0.95, 0.15))
	expr("hero", 0.0, "open")
	expr("hero", 4.6, "done")
	expr("hero", 11.9, "angry")
	var y_ex: float = CineTimeline.face(HERO, EXIT)
	move("hero", 12.0, "idle", {"fade": 0.2})
	key("hero", 12.1, HERO, CineTimeline.face(HERO, DESK + Vector3(0.0, 0.0, 0.3)))
	key("hero", 12.6, HERO, y_ex)
	key("hero", 13.95, EXIT, y_ex, {"mode": "in"})
	move("hero", 12.65, "walk", {"fade": 0.15})
	sfx_at(0.3, "keyboard_clack", -10.0)
	sfx_at(2.4, "keyboard_clack", -11.0)
	sfx_at(6.0, "keyboard_clack", -10.0)
	sfx_at(9.9, "keyboard_clack", -9.0)
	sfx_at(12.1, "engine_roar", -9.0)
	shot("S1", 0.0, "static", "wide: a lobby corner at night, three laptops glow, the protagonist walks up",
		{"pos": Vector3(2.4, 1.65, 1.9), "look": Vector3(0.3, 1.0, -0.9), "fov": 50.0})
	shot("S2", 1.9, "static", "close over the laptops: Anh Duy typing, the route on three screens",
		{"pos": Vector3(0.22, 1.32, 0.62), "look": Vector3(0.0, 1.18, -0.72), "fov": 40.0, "hand": 0.15})
	shot("S3", 4.5, "static", "close: the protagonist, \"Nói tiếng người đi anh.\"",
		{"pos": Vector3(1.05, 1.6, -0.3), "look": Vector3(0.78, 1.55, -1.42), "fov": 38.0, "hand": 0.15})
	shot("S4", 6.1, "static", "two-shot side on: Anh Duy explains, the protagonist listens",
		{"pos": Vector3(-2.3, 1.45, -1.4), "look": Vector3(0.3, 1.2, -1.0), "fov": 44.0})
	shot("S5", 9.6, "static", "insert: the energy drink goes down, fingers on the keys",
		{"pos": Vector3(-0.75, 1.2, 0.55), "look": Vector3(0.0, 0.95, -0.35), "fov": 38.0})
	shot("S6", 11.9, "static", "wide: the protagonist turns and goes, \"Tới công chuyện luôn!\"",
		{"pos": Vector3(2.7, 1.7, 1.2), "look": Vector3(1.4, 1.2, -1.8), "fov": 48.0})
	sub(0.6, 3.0, "duy", "Anh trace route Bầy Sói qua ba con laptop rồi.", "Dịch: Anh biết tụi nó chạy đường nào.")
	sub(4.6, 1.5, "hero", "Nói tiếng người đi anh.")
	sub(6.2, 3.4, "duy", "Tụi nó ping nhau lúc 2h, payload chạy trên Nguyễn Xiển.", "Dịch: Hai giờ sáng tụi nó chở hàng trên đường Nguyễn Xiển.")
	sub(9.7, 2.2, "duy", "Chặn được là anh deploy hotfix liền.", "Dịch: Mày chặn tụi nó, phần còn lại anh lo.")
	sub(12.1, 1.4, "hero", "Tới công chuyện luôn!")
