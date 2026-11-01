# File: res://scripts/cine/timelines/end_d.gd
# end_d (26.000 s, story spec section 6, ending D "Minh oan nửa vời", plan 2026-11-01-w4-endings.md T1): sequel hook.
# Morning outside BE6. The protagonist reads the decision "CẢNH CÁO": Mr.T: "Án đình chỉ giảm còn cảnh cáo. Bằng chứng chưa
# đủ để buộc tội hắn." - "Còn thiếu... một chút." A helicopter roars in low over the tower: Lùm Văn Lọ hangs from its skid in
# his white suit: "Mọi thứ đều nằm trong kế hoạch!" (an evil laugh). A flyer flutters down onto the protagonist: "'Lọ Academy
# 2: khai giảng tháng sau'..." - Phúc: "Ủa, có phần 2 hả?" The helicopter flies off; Anh Duy on the radio (jargon + Dịch:);
# "...Phần 2 thì phải học lại từ đầu à?" The credits roll with "CÒN TIẾP..." (21.0-26.0 s).
# No ramps (story = real). Music slot end_d (owner file "Fly Me to the Moon", else silence).
# Stage: the BE6 stage of cine_day_start (be6_center, 8 x 8, morning); the helicopter flies far over it (prop path).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 0.6)
const MRT := Vector3(1.3, 0.0, -0.4)
const PHUC := Vector3(-1.4, 0.0, -0.2)
const HANG := Vector3(0.0, -2.35, -0.2)   # Lùm Văn Lọ below the helicopter origin (holding the skid)
const H0 := Vector3(-34.0, 22.0, -46.0)
const H1 := Vector3(-3.0, 13.0, -15.0)
const H2 := Vector3(1.0, 12.5, -13.0)
const H3 := Vector3(40.0, 28.0, 18.0)
const CREDITS_R: float = 21.0


func build() -> void:
	slot = "end_d"
	length = 26.0
	story_end = 26.0
	mood = "playful"
	fade_in = 0.8
	fade_out = 1.0
	stage = {"landmark": "be6_center", "near": 70.0, "size": Vector2(8.0, 8.0), "tod": "morning"}
	var hero_name: String = StoryCast.speaker("hero")
	actor("hero", StoryCast.opts("hero"), hero_name, StoryCast.color("hero"))
	actor("mr_t", StoryCast.opts("mr_t"), StoryCast.speaker("mr_t"), StoryCast.color("mr_t"))
	actor("phuc", StoryCast.opts("phuc"), StoryCast.speaker("phuc"), StoryCast.color("phuc"))
	actor("lo", StoryEndings.van_lo_opts(), StoryEndings.VAN_LO_NAME, StoryEndings.VAN_LO_COLOR)
	var heli: Array = [[0.0, H0, Vector3(0.0, -35.0, 0.0)], [5.0, H0, Vector3(0.0, -35.0, 0.0)],
		[7.0, H1, Vector3(-6.0, -35.0, 4.0)], [13.6, H2, Vector3(-4.0, -40.0, -3.0)], [18.0, H3, Vector3(-12.0, -70.0, 10.0)]]
	prop("heli", "helicopter", H0, -35.0, {"path": heli})
	# Lùm Văn Lọ dangles under it (keyed along the same path)
	for k: Array in heli:
		key("lo", float(k[0]), (k[1] as Vector3) + HANG, float((k[2] as Vector3).y))
	move("lo", 0.0, "hold_up")
	move("lo", 7.2, "laugh", {"fade": 0.2})
	move("lo", 9.4, "hold_up", {"fade": 0.2})
	look("lo", 6.0, 15.0, "hero")
	expr("lo", 0.0, "happy")
	# the flyer he drops, fluttering down onto the protagonist
	prop("flyer", "certificate", H2 + HANG + Vector3(0.0, 1.0, 0.0), 0.0, {"title": "LỌ ACADEMY 2", "sub": "Khai giảng tháng sau",
		"show_at": 9.4, "hide_at": 11.4, "arc": 1.0, "path": [[9.4, H2 + HANG + Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 0.0)],
		[11.4, HERO + Vector3(0.1, 1.3, -0.35), Vector3(-40.0, 720.0, 30.0)]]})
	# the protagonist with the decision, then the flyer
	key("hero", 0.0, HERO, 0.0)
	move("hero", 0.0, "hold_up")
	hold("hero", 0.0, 4.8, "certificate", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.08), "title": "CẢNH CÁO",
		"sub": "Quyết định kỷ luật"})
	look("hero", 0.0, 3.4, HERO + Vector3(0.1, 1.25, -0.38))
	look("hero", 3.5, 5.0, "mr_t")
	move("hero", 3.6, "talk", {"fade": 0.2})
	move("hero", 5.2, "startled", {"fade": 0.1})
	look("hero", 5.2, 11.0, "lo")
	move("hero", 6.4, "idle", {"fade": 0.3})
	move("hero", 11.4, "hold_up", {"fade": 0.2})
	hold("hero", 11.4, 18.0, "certificate", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.08), "title": "LỌ ACADEMY 2",
		"sub": "Khai giảng tháng sau"})
	look("hero", 11.4, 13.6, HERO + Vector3(0.1, 1.25, -0.38))
	look("hero", 13.7, 15.0, "phuc")
	look("hero", 15.1, 18.2, "lo")
	move("hero", 18.2, "shrug", {"fade": 0.2})
	expr("hero", 0.0, "done")
	expr("hero", 5.2, "surprised")
	expr("hero", 11.6, "angry")
	expr("hero", 18.2, "done")
	key("mr_t", 0.0, MRT, CineTimeline.face(MRT, HERO))
	move("mr_t", 0.0, "talk")
	move("mr_t", 3.5, "idle", {"fade": 0.2})
	look("mr_t", 0.0, 5.2, "hero")
	look("mr_t", 5.3, 16.0, "lo")
	expr("mr_t", 0.0, "done")
	expr("mr_t", 5.3, "surprised")
	key("phuc", 0.0, PHUC, CineTimeline.face(PHUC, HERO))
	move("phuc", 0.0, "idle")
	look("phuc", 0.0, 5.2, "hero")
	look("phuc", 5.3, 13.6, "lo")
	look("phuc", 13.7, 15.2, "hero")
	move("phuc", 13.7, "shrug", {"fade": 0.2})
	move("phuc", 15.2, "idle", {"fade": 0.3})
	expr("phuc", 0.0, "open")
	expr("phuc", 5.3, "surprised")
	expr("phuc", 13.7, "open")
	sfx_at(5.0, "engine_roar", -4.0)
	sfx_at(7.2, "evil_laugh", -4.0)
	sfx_at(9.4, "whoosh_down", -8.0)
	sfx_at(13.7, "record_scratch", -6.0)
	sfx_at(15.0, "engine_roar", -8.0)
	sfx_at(18.4, "dun_dun_duun", -5.0)
	shot("S1", 0.0, "static", "the protagonist reads the decision: CẢNH CÁO",
		{"pos": Vector3(1.8, 1.55, 2.6), "look": Vector3(0.2, 1.2, 0.0), "fov": 46.0})
	two_shot("S2", 2.4, "hero", "mr_t", {"side": 1.0, "look_y": 1.25})
	shot("S3", 5.2, "static", "low, looking up past the tower: a helicopter, a man in a white suit hanging from the skid",
		{"pos": Vector3(0.6, 1.0, 2.2), "look": Vector3(-2.0, 11.0, -14.0), "fov": 58.0})
	shot("S4", 7.0, "static", "Lùm Văn Lọ dangling: Mọi thứ đều nằm trong kế hoạch!",
		{"pos": Vector3(1.5, 9.4, -7.0), "look": Vector3(-2.6, 10.8, -15.0), "fov": 44.0})
	push_in("S5", 11.3, "hero", {"from": 2.4, "to": 2.0, "side_deg": 20.0, "look_y": 1.3})   # the Lọ Academy 2 flyer
	two_shot("S6", 13.6, "phuc", "hero", {"side": -1.0, "look_y": 1.25})
	shot("S7", 15.2, "static", "wide: the helicopter flies off into the morning sky",
		{"pos": Vector3(-1.4, 1.4, 3.4), "look": Vector3(8.0, 14.0, -6.0), "fov": 56.0})
	hero_shot("S8", 18.0, "hero", {"side_deg": -20.0, "dist": 2.4})
	sub(0.5, 3.0, "mr_t", "Án đình chỉ giảm còn cảnh cáo. Bằng chứng chưa đủ để buộc tội hắn.")
	sub(3.6, 1.5, "hero", "Còn thiếu... một chút.")
	sub(7.2, 2.2, "lo", "Mọi thứ đều nằm trong kế hoạch!")
	sub(11.6, 2.0, "hero", "'Lọ Academy 2: khai giảng tháng sau'...")
	sub(13.8, 1.4, "phuc", "Ủa, có phần 2 hả?")
	sub(15.3, 2.6, "Anh Duy", "Target bay r e, a mất tracking. Hẹn sprint sau.", "Dịch: Hắn trốn mất rồi, lần sau tính.")
	sub(18.3, 2.2, "hero", "...Phần 2 thì phải học lại từ đầu à?")
	joke(11.6, "the villain escapes and drops an ad for the sequel: Lọ Academy 2")
	card("screen", CREDITS_R, length - CREDITS_R, {"kind": "credits", "title": "KẾT D: MINH OAN NỬA VỜI", "lines": [
		"%s: cảnh cáo, được đi học lại." % hero_name, "Lùm Văn Lọ: trên trực thăng, chưa rõ đi đâu.",
		"Bằng chứng còn thiếu, hoặc túi tiền đã nhận.", " ", "CÒN TIẾP..."]})
