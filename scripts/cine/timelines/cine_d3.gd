# File: res://scripts/cine/timelines/cine_d3.gd
# cine_d3 (18.000 s, spec C-D7 beat 10, C-D9 end cinematic): Day 3, the container yard after the forklift boss. The forklift
# lies on its side; Alexander ABCXYZ sits dazed in the wreck of the crates he was dropped on, gold sunglasses askew (as
# seg_d3_boss leaves him: sitting at its A_FLOOR facing -Z, the protagonist and his party horn where the fight ends them). "Các người có biết ta là ai không?" - "Không." - he starts his endless name and the protagonist cuts
# it off with a blast of his own party horn. "Ngắn thôi. Hàng của ai?" - while he dodges, a USB slips out of his shirt
# pocket: "ZA MẪN LABS". "Đừng cắm vô máy trường nha!"
# No ramps (story = real). Music slot cine_d3 (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("yard") (14 x 12), as cine_d3_mannequins / seg_d3_boss; containers are set dressing.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

# the layout follows seg_d3_boss's end (tests/test_cine_d3_boss.gd checks the hand-off): Alexander sitting in the burst
# crates facing -Z, the protagonist over him, the horn under his foot a moment ago
const ALEX := Vector3(-0.5, 0.0, 3.596)        # sitting on the ground, facing -Z (yaw 0)
const HERO := Vector3(-1.4, 0.0, 2.196)
const HORN := Vector3(-1.7, 0.05, 2.696)       # the curl rests on the ground
const HORN_YAW: float = 240.0
const USB_FROM := Vector3(-0.53, 0.55, 3.426)   # his shirt pocket (he sits on the ground)
const USB := Vector3(-0.83, 0.006, 3.046)
const FORKLIFT := Vector3(3.6, 0.6, -1.3)
const WRECK := Vector3(-0.5, 0.0, 3.5)         # seg_d3_boss's crate stack, burst: its planks on the ground


func build() -> void:
	slot = "cine_d3"
	length = 18.0
	story_end = 18.0
	mood = "playful"
	fade_in = 0.5
	fade_out = 0.6
	stage = CineTimeline.phase_c_stage("yard")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("alex", StoryCast.opts("alexander"), StoryCast.speaker("alexander"), StoryCast.color("alexander"))
	# his gear, the sunglasses knocked askew
	hold("alex", 0.0, 18.0, "hawaii_print", {"bone": "Chest", "offset": Vector3.ZERO, "depth": -0.175})
	hold("alex", 0.0, 18.0, "gold_shades", {"bone": "Head", "offset": Vector3(0.012, StoryCast.EYE_UP - 0.012, StoryCast.EYE_FRONT), "rot": Vector3(0.0, 0.0, 16.0)})
	# two containers lying lengthwise along the back of the stage (their doors face the sides)
	prop("box0", "container", Vector3(-6.08, 0.0, -4.6), 90.0, {"set": true, "color": Color("#2E5E8C")})
	prop("box1", "container", Vector3(0.02, 0.0, -4.6), 90.0, {"set": true, "color": Color("#9E3B2E")})
	prop("forklift", "forklift", FORKLIFT, 0.0, {"path": [[0.0, FORKLIFT, Vector3(0.0, 35.0, 88.0)], [18.0, FORKLIFT, Vector3(0.0, 35.0, 88.0)]]})
	prop("crates", "crate_stack", Vector3(-3.6, 0.0, 0.4), 25.0, {"color": Color("#7A5A3A")})
	prop("horn", "party_horn", HORN, HORN_YAW, {"hide_at": 5.4})
	prop("wreck", "crate_stack", WRECK, 90.0, {"broken": true, "color": Color("#8A6A43")})
	prop("usb", "usb", USB, 30.0, {"show_at": 11.0, "hide_at": 13.4, "path": [[11.0, USB_FROM, Vector3(0.0, 0.0, 0.0)], [11.35, USB, Vector3(0.0, 30.0, 0.0)]]})
	# Alexander, dazed on the ground
	key("alex", 0.0, ALEX, 0.0)
	move("alex", 0.0, "slumped")
	look("alex", 0.0, 18.0, "hero")
	expr("alex", 0.0, "done")
	expr("alex", 0.5, "talk")
	expr("alex", 6.5, "surprised")
	expr("alex", 9.1, "talk")
	expr("alex", 11.0, "surprised")
	expr("alex", 14.7, "angry")
	expr("alex", 16.5, "done")
	# the protagonist: listens, snatches the horn (5.4), blasts it (6.5), picks up the USB (13.4), goes
	var y_al: float = CineTimeline.face(HERO, ALEX)
	key("hero", 0.0, HERO, y_al)
	move("hero", 0.0, "arms_crossed")
	look("hero", 0.0, 4.9, "alex")
	move("hero", 4.8, "idle", {"fade": 0.2})
	key("hero", 4.8, HERO, y_al)
	key("hero", 5.15, HERO, CineTimeline.face(HERO, HORN))
	strike("hero", 5.4, "pickup", {"dur": 0.5})
	key("hero", 5.7, HERO, CineTimeline.face(HERO, HORN))
	key("hero", 6.0, HERO, y_al)
	move("hero", 6.05, "blow", {"fade": 0.12})
	hold("hero", 5.4, 6.05, "party_horn", {"offset": Vector3(0.0, 0.0, -0.03)})   # in the hand off the ground
	hold("hero", 6.05, 7.3, "party_horn", {"bone": "Head", "offset": Vector3(0.0, 0.05, -0.115)})   # at the mouth for the blast
	move("hero", 7.3, "arms_crossed", {"fade": 0.25})
	look("hero", 6.0, 11.0, "alex")
	look("hero", 11.0, 13.0, USB)
	move("hero", 13.0, "idle", {"fade": 0.2})
	key("hero", 13.0, HERO, y_al)
	key("hero", 13.2, HERO, CineTimeline.face(HERO, USB))
	strike("hero", 13.4, "pickup", {"dur": 0.5})
	hold("hero", 13.4, 18.0, "usb", {"offset": Vector3(0.0, 0.0, -0.02)})
	move("hero", 13.75, "hold_up", {"fade": 0.2})
	look("hero", 13.8, 14.6, Vector3(-1.55, 1.3, 2.596))
	look("hero", 14.7, 16.3, "alex")
	move("hero", 15.0, "shrug", {"fade": 0.15})
	move("hero", 16.2, "hold_up", {"fade": 0.2})
	expr("hero", 0.0, "open")
	expr("hero", 6.1, "angry")
	expr("hero", 13.6, "surprised")
	expr("hero", 16.5, "surprised")
	# Q5 cliffhanger: Alexander warns that Za Mẫn is already watching; the protagonist looks round
	look("hero", 16.4, 18.0, Vector3(-3.45, 2.2, 5.846))
	sfx_at(6.5, "party_horn", 0.0)
	sfx_at(6.7, "record_scratch", -6.0)
	sfx_at(11.05, "slide_whistle", -10.0)
	sfx_at(11.35, "freeze_tick", -6.0)
	sfx_at(13.7, "dun_dun_duun", -6.0)
	sfx_at(16.9, "cliff_sting", -3.0)
	shot("S1", 0.0, "static", "wide: the yard after the fight, Alexander dazed in the burst crates, the protagonist over him",
		{"pos": Vector3(1.8, 2.0, 0.4), "look": Vector3(-0.9, 0.7, 3.1), "fov": 50.0})
	shot("S2", 0.4, "static", "close: Alexander, \"Các người có biết ta là ai không?\"",
		{"pos": Vector3(-0.8, 0.95, 2.496), "look": Vector3(-0.5, 0.8, 3.596), "fov": 40.0, "hand": 0.15})
	shot("S3", 2.7, "static", "close: the protagonist, \"Không.\"",
		{"pos": Vector3(-1.05, 1.45, 3.046), "look": Vector3(-1.4, 1.5, 2.196), "fov": 38.0})
	two_shot("S4", 3.5, "hero", "alex", {"side": 1.0, "look_y": 0.95, "dist": 3.8})   # the endless name begins
	shot("S5", 6.3, "static", "close over Alexander: the party horn blast cuts the name off",
		{"pos": Vector3(-0.2, 1.25, 2.946), "look": Vector3(-1.4, 1.5, 2.196), "fov": 40.0})
	shot("S6", 7.3, "static", "close: the protagonist, \"Ngắn thôi. Hàng của ai?\"",
		{"pos": Vector3(-1.05, 1.45, 3.046), "look": Vector3(-1.4, 1.5, 2.196), "fov": 38.0})
	shot("S7", 9.0, "static", "close: Alexander squirms; something slips out of his pocket",
		{"pos": Vector3(-0.85, 0.95, 2.446), "look": Vector3(-0.53, 0.75, 3.546), "fov": 42.0})
	shot("S8", 11.45, "static", "insert: the USB on the ground, \"ZA MẪN LABS\"",
		{"pos": Vector3(-0.93, 0.32, 2.796), "look": USB, "fov": 30.0})
	shot("S9", 13.5, "static", "close: the protagonist reads the USB",
		{"pos": Vector3(-1.5, 1.5, 1.246), "look": Vector3(-1.4, 1.35, 2.196), "fov": 40.0})
	shot("S10", 14.6, "static", "close: Alexander, \"Đừng cắm vô máy trường nha!\"",
		{"pos": Vector3(-0.8, 0.95, 2.496), "look": Vector3(-0.5, 0.8, 3.596), "fov": 40.0})
	dutch_shot("S11", 16.3, "alex", {"side_deg": -25.0, "dist": 2.5, "height": 0.85, "look_y": 0.6, "roll": -12.0, "push": 0.15})   # the warning
	sub(0.5, 2.1, "alex", "Các người có biết ta là ai không?")
	sub(2.8, 0.6, "hero", "Không.")
	sub(3.6, 3.0, "alex", "Ta là Alexander ABCXYZ DEFGH IJKLMN OPQRS TUVW...")
	sub(7.4, 1.5, "hero", "Ngắn thôi. Hàng của ai?")
	sub(9.1, 2.6, "alex", "...Ta chỉ là trung gian. Ông chủ thật là...")
	sub(13.6, 0.9, "hero", "Za Mẫn Labs?")
	sub(14.7, 1.7, "alex", "Đừng cắm vô máy trường nha!")
	sub(16.45, 1.5, "alex", "Za Mẫn đang nhìn cậu đó.")
	joke(6.5, "the party horn blast cuts the endless name off")
	cliffhanger(16.45)
