# File: res://scripts/cine/timelines/cine_d5_intro.gd
# cine_d5_intro (14.000 s, spec C-D8 beat 2, C-D9 mission intro): Day 5, night, Anh Duy's corner by the BE6 lobby (as
# cine_d2_intro). He holds up the USB "ZA MẪN LABS", plugs it in, decrypts it (strong lock, weak password), and finds an
# internal IP pointing at a server in the basement under The Beverly tower: right under where the protagonist sleeps. Every
# jargon line carries its "Dịch:" translation.
# No ramps (story = real). Music slot cine_d5_intro (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("duy_room") (8 x 8; desk, laptops, lobby wall carried; the wall is set dressing).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const DESK := Vector3(0.0, 0.0, 0.0)
const DUY := Vector3(0.0, 0.0, -0.72)
const HERO := Vector3(0.78, 0.0, -1.42)
const USB_PORT := Vector3(0.2, 0.76, 0.02)
const PLUG: float = 1.9


func build() -> void:
	slot = "cine_d5_intro"
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
	prop("usb", "usb", USB_PORT, 90.0, {"show_at": PLUG})
	prop("can", "energy_drink", Vector3(0.62, 0.81, -0.12), 0.0)
	# Anh Duy shows the USB, plugs it in, types
	key("duy", 0.0, DUY, 180.0)
	move("duy", 0.0, "sit_bench_hold")
	hold("duy", 0.0, PLUG, "usb", {"offset": Vector3(0.0, 0.0, -0.03)})
	move("duy", PLUG - 0.35, "type_sit", {"fade": 0.3})
	look("duy", 0.0, 1.4, Vector3(0.15, 1.15, -0.3))
	look("duy", 1.5, 14.0, Vector3(0.0, 0.95, 0.1))
	expr("duy", 0.0, "happy")
	expr("duy", 2.4, "open")
	expr("duy", 10.6, "happy")
	# the protagonist watches over his shoulder
	key("hero", 0.0, HERO, CineTimeline.face(HERO, DESK + Vector3(0.0, 0.0, 0.3)))
	move("hero", 0.0, "arms_crossed")
	look("hero", 0.0, 14.0, Vector3(0.0, 0.95, 0.15))
	expr("hero", 0.0, "open")
	expr("hero", 9.85, "surprised")
	expr("hero", 12.5, "angry")
	move("hero", 9.85, "startled", {"dur": 0.6, "fade": 0.08})
	move("hero", 10.45, "arms_crossed", {"fade": 0.3})
	sfx_at(PLUG, "freeze_tick", -6.0)
	sfx_at(2.3, "keyboard_clack", -10.0)
	sfx_at(5.0, "keyboard_clack", -11.0)
	sfx_at(6.4, "success_fanfare", -14.0)
	sfx_at(9.85, "record_scratch", -8.0)
	shot("S1", 0.0, "static", "close over the laptops: Anh Duy holds up the USB \"ZA MẪN LABS\"",
		{"pos": Vector3(0.22, 1.32, 0.62), "look": Vector3(0.0, 1.18, -0.72), "fov": 40.0, "hand": 0.15})
	shot("S2", 1.75, "static", "insert: the USB slides into the laptop",
		{"pos": Vector3(0.5, 0.95, -0.15), "look": USB_PORT, "fov": 34.0})
	shot("S3", 2.4, "static", "two-shot side on: decrypting",
		{"pos": Vector3(-2.3, 1.45, -1.4), "look": Vector3(0.3, 1.2, -1.0), "fov": 44.0})
	shot("S4", 9.75, "static", "close: the protagonist, \"Ngay dưới chỗ tao ngủ?!\"",
		{"pos": Vector3(1.05, 1.6, -0.3), "look": Vector3(0.78, 1.55, -1.42), "fov": 38.0, "hand": 0.15})
	shot("S5", 11.35, "static", "close over the laptops: Anh Duy, pleased with himself",
		{"pos": Vector3(0.22, 1.32, 0.62), "look": Vector3(0.0, 1.18, -0.72), "fov": 40.0})
	shot("S6", 12.4, "static", "wide: \"Đêm nay xuống hầm.\"",
		{"pos": Vector3(2.4, 1.65, 1.9), "look": Vector3(0.3, 1.0, -0.9), "fov": 50.0})
	sub(0.3, 1.5, "duy", "Đồ tốt đây.", "Dịch: Cái USB này xịn đó.")
	sub(2.4, 2.4, "duy", "USB mã hoá AES-256, mà pass là 123456.", "Dịch: Khóa xịn, mật khẩu dỏm.")
	sub(5.0, 1.3, "hero", "Rồi trong đó có gì?")
	sub(6.5, 3.3, "duy", "Một IP nội bộ, trỏ về server dưới hầm tòa The Beverly.", "Dịch: Máy chủ của tụi nó nằm dưới tầng hầm tòa nhà mày ở.")
	sub(9.9, 1.4, "hero", "Ngay dưới chỗ tao ngủ?!")
	sub(11.4, 1.0, "duy", "Ping 1ms.", "Dịch: Sát vách luôn.")
	sub(12.5, 1.3, "hero", "Đêm nay xuống hầm.")
