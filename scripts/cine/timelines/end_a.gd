# File: res://scripts/cine/timelines/end_a.gd
# end_a (26.000 s, story spec section 6, ending A "Minh oan trọn vẹn", plan 2026-11-01-w4-endings.md T1): the 08:00 hearing
# on the campus courtyard. The protagonist stands alone before the council table under the banner "HỘI ĐỒNG KỶ LUẬT"; Mr.T
# asks for a statement: "Dạ có. Bảy thứ." Anh Duy walks in with a laptop and casts the seven pieces of evidence on the big
# screen (jargon + Dịch:). Mr.T reads them, a record scratch: the banner swaps to "LỄ KHEN THƯỞNG", Phúc pops a party horn
# ("Gét gô!"). Mr.T walks round the table, hands over a certificate, a handshake, a victory pose; Linh: "Phúc, mày khóc à?"
# - "Bụi... bụi bay vào mắt." The credits roll (StoryScreenCard "credits", 21.0-26.0 s); ai_true_end follows (post-credits).
# Ending F plays this too, then ai_true_end, then end_f.
# No ramps (story = real). Music slot end_a (owner file "September", else silence).
# Stage: CineTimeline.canteen_stage (campus courtyard, 14 x 10, the end_c stage); the hearing set is carried (set: true).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, -0.6)
const MRT := Vector3(0.0, 0.0, -3.35)
const MRT_FRONT := Vector3(0.35, 0.0, -1.4)
const DUY_FROM := Vector3(5.2, 0.0, -0.4)
const DUY := Vector3(2.0, 0.0, -1.7)
const PHUC := Vector3(-3.0, 0.0, 0.9)
const LINH := Vector3(-2.2, 0.0, 1.3)
const SCREEN_LINES: Array[String] = ["E1  Ảnh tai nghe phát sáng xanh", "E2  Danh sách shipper giao tool",
	"E3  Trang sổ dưới gầm cầu Rạch Hầm", "E4  Bảng kê hàng container", "E5  Danh sách thi hộ của Cừu Dolly",
	"E6  Log giao dịch Lọ Thần 9.0", "E7  Sổ cái Trà Sữa Lọ"]
const CREDITS_R: float = 21.0


func build() -> void:
	slot = "end_a"
	length = 26.0
	story_end = 26.0
	mood = "playful"
	fade_in = 0.8
	fade_out = 1.0
	stage = CineTimeline.canteen_stage(Vector2(14.0, 10.0), "morning")
	stage["exposure"] = 1.15
	var hero_name: String = StoryCast.speaker("hero")
	for id: String in ["hero", "mr_t", "anh_duy", "phuc", "linh"]:
		actor(id, StoryCast.opts(id), StoryCast.speaker(id) if id != "hero" else hero_name, StoryCast.color(id))
	StoryCast.dress(self, "anh_duy", "anh_duy")
	prop("hearing", "hearing_set", Vector3(0.0, 0.0, -2.6), 180.0, {"set": true, "title": "", "screen_title": "BẰNG CHỨNG 7/7",
		"screen": SCREEN_LINES})
	prop("sign_a", "sign", Vector3(0.0, 0.45, -2.1), 180.0, {"set": true, "text": "HỘI ĐỒNG KỶ LUẬT", "hide_at": 11.0})
	prop("sign_b", "sign", Vector3(0.0, 0.45, -2.1), 180.0, {"set": true, "text": "LỄ KHEN THƯỞNG", "color": Color("#B3261E"),
		"show_at": 11.0})
	# the protagonist before the council
	key("hero", 0.0, HERO, 0.0)
	move("hero", 0.0, "idle")
	move("hero", 3.4, "talk", {"fade": 0.2})
	move("hero", 4.8, "idle", {"fade": 0.2})
	look("hero", 0.0, 4.6, "mr_t")
	look("hero", 4.7, 7.4, "anh_duy")
	look("hero", 7.5, 10.6, Vector3(0.0, 2.6, -4.2))
	look("hero", 10.7, 14.3, Vector3(0.0, 0.7, -2.1))
	key("hero", 14.4, HERO, 0.0)
	key("hero", 14.9, HERO, CineTimeline.face(HERO, MRT_FRONT))
	look("hero", 14.6, 17.4, "mr_t")
	move("hero", 16.0, "handshake", {"fade": 0.2})
	move("hero", 17.6, "victory", {"fade": 0.2})
	move("hero", 19.6, "idle", {"fade": 0.3})
	hold("hero", 16.6, story_end, "certificate", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.08)})
	expr("hero", 0.0, "open")
	expr("hero", 3.4, "talk")
	expr("hero", 8.0, "surprised")
	expr("hero", 11.2, "happy")
	# Mr.T behind the table, then round it with the certificate
	key("mr_t", 0.0, MRT, 180.0)
	move("mr_t", 0.0, "idle")
	move("mr_t", 0.6, "talk", {"fade": 0.2})
	move("mr_t", 3.2, "idle", {"fade": 0.2})
	move("mr_t", 8.0, "talk", {"fade": 0.2})
	move("mr_t", 10.4, "idle", {"fade": 0.2})
	look("mr_t", 0.0, 7.6, "hero")
	look("mr_t", 7.7, 10.4, Vector3(0.0, 2.6, -4.2))
	look("mr_t", 10.5, story_end, "hero")
	var y_round: float = CineTimeline.face(MRT, MRT + Vector3(2.8, 0.0, 0.0))
	key("mr_t", 12.4, MRT, 180.0)
	key("mr_t", 12.8, MRT, y_round)
	key("mr_t", 13.4, MRT + Vector3(2.8, 0.0, 0.0), y_round)
	key("mr_t", 14.4, MRT_FRONT, CineTimeline.face(MRT + Vector3(2.8, 0.0, 0.0), MRT_FRONT), {"mode": "out"})
	key("mr_t", 14.8, MRT_FRONT, CineTimeline.face(MRT_FRONT, HERO))
	move("mr_t", 12.6, "walk", {"fade": 0.2})
	move("mr_t", 14.4, "talk", {"fade": 0.2})
	move("mr_t", 16.0, "handshake", {"fade": 0.2})
	move("mr_t", 17.6, "nod", {"fade": 0.2})
	move("mr_t", 18.6, "idle", {"fade": 0.3})
	hold("mr_t", 12.6, 16.6, "certificate", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.02, -0.08)})
	expr("mr_t", 0.0, "done")
	expr("mr_t", 8.6, "surprised")
	expr("mr_t", 11.2, "happy")
	# Anh Duy casts the evidence
	key("anh_duy", 0.0, DUY_FROM, CineTimeline.face(DUY_FROM, DUY))
	key("anh_duy", 4.4, DUY_FROM, CineTimeline.face(DUY_FROM, DUY))
	key("anh_duy", 6.2, DUY, CineTimeline.face(DUY_FROM, DUY), {"mode": "out"})
	key("anh_duy", 6.6, DUY, CineTimeline.face(DUY, HERO))
	show("anh_duy", 0.0, false)
	show("anh_duy", 4.3, true)
	move("anh_duy", 4.4, "walk")
	move("anh_duy", 6.2, "type_sit", {"fade": 0.25})
	move("anh_duy", 7.6, "present", {"fade": 0.25})
	move("anh_duy", 10.6, "fold_arms", {"fade": 0.3})
	hold("anh_duy", 4.3, 7.6, "laptop", {"bone": "Wrist.L", "mid": "Wrist.R", "offset": Vector3(0.0, -0.03, -0.16)})
	look("anh_duy", 6.6, story_end, "hero")
	expr("anh_duy", 4.4, "happy")
	# the audience: Phúc (party horn) and Linh
	key("phuc", 0.0, PHUC, CineTimeline.face(PHUC, HERO))
	key("linh", 0.0, LINH, CineTimeline.face(LINH, HERO))
	move("phuc", 0.0, "idle")
	move("linh", 0.0, "fold_arms")
	move("phuc", 12.4, "victory", {"fade": 0.15})
	move("phuc", 14.2, "idle", {"fade": 0.3})
	hold("phuc", 12.2, 14.4, "party_horn", {"offset": Vector3(0.0, 0.02, -0.06), "rot": Vector3(-60.0, 0.0, 0.0)})
	look("phuc", 0.0, 17.8, "hero")
	look("linh", 0.0, 17.6, "hero")
	look("linh", 17.7, story_end, "phuc")
	look("phuc", 17.9, story_end, "linh")
	move("phuc", 19.3, "facepalm", {"fade": 0.15})
	expr("phuc", 0.0, "open")
	expr("phuc", 12.4, "happy")
	expr("phuc", 19.3, "closed")
	expr("linh", 0.0, "done")
	expr("linh", 17.8, "happy")
	sfx_at(7.6, "keyboard_clack", -8.0)
	sfx_at(10.8, "record_scratch", -4.0)
	sfx_at(11.2, "success_fanfare", -5.0)
	sfx_at(12.6, "party_horn", -4.0)
	sfx_at(17.6, "applause", -6.0)
	shot("S1", 0.0, "static", "wide: the hearing on the courtyard, the protagonist alone before the council",
		{"pos": Vector3(3.4, 1.9, 3.6), "look": Vector3(0.0, 1.1, -2.2), "fov": 50.0})
	push_in("S2", 3.3, "hero", {"from": 2.6, "to": 2.1, "side_deg": 18.0, "look_y": 1.3})   # "Dạ có. Bảy thứ."
	two_shot("S3", 4.8, "anh_duy", "hero", {"side": 1.0, "look_y": 1.2})
	shot("S4", 7.7, "static", "over the protagonist: the seven pieces of evidence on the big screen",
		{"pos": Vector3(0.6, 1.8, 0.9), "look": Vector3(0.0, 2.4, -4.2), "fov": 46.0})
	shot("S5", 10.7, "static", "the banner: HỘI ĐỒNG KỶ LUẬT swaps to LỄ KHEN THƯỞNG",
		{"pos": Vector3(0.5, 1.2, 0.2), "look": Vector3(0.0, 0.7, -2.1), "fov": 40.0})
	shot("S6", 12.3, "static", "Phúc in the audience pops a party horn: Gét gô!",
		{"pos": Vector3(-1.6, 1.5, 2.6), "look": Vector3(-3.0, 1.4, 0.9), "fov": 42.0})
	two_shot("S7", 14.4, "hero", "mr_t", {"side": -1.0, "look_y": 1.2})
	hero_shot("S8", 17.5, "hero", {"side_deg": 20.0, "dist": 2.5})
	two_shot("S9", 17.9, "linh", "phuc", {"side": -1.0, "look_y": 1.3})
	shot("S10", 20.8, "dolly", "wide pull back over the courtyard: the credits roll",
		{"from": Vector3(2.0, 2.0, 2.4), "to": Vector3(3.6, 3.0, 5.0), "look_from": Vector3(0.0, 1.4, -1.6), "look_to": Vector3(0.0, 1.6, -2.0),
		"fov": 50.0})
	sub(0.6, 2.6, "mr_t", "Phiên kỷ luật bắt đầu. Em có gì để trình bày không?")
	sub(3.4, 1.4, "hero", "Dạ có. Bảy thứ.")
	sub(5.0, 2.5, "anh_duy", "Ok để a cast lên màn hình chính, plug-and-play.", "Dịch: Anh chiếu bằng chứng lên.")
	sub(8.0, 2.4, "mr_t", "Ảnh tai nghe, sổ cái Trà Sữa Lọ... đủ cả bảy.")
	sub(11.3, 1.2, "mr_t", "Đổi băng rôn đi.")
	sub(12.6, 1.4, "phuc", "Gét gô!")
	sub(15.0, 2.4, "mr_t", "Xin lỗi em vì bảy ngày qua. Và cảm ơn em.")
	sub(17.9, 1.3, "linh", "Phúc, mày khóc à?")
	sub(19.3, 1.6, "phuc", "Bụi... bụi bay vào mắt.")
	joke(12.6, "the hearing turns into an award ceremony: a record scratch, the banner swap, Phúc's party horn")
	joke(19.3, "Phúc crying: 'Bụi bay vào mắt'")
	card("screen", CREDITS_R, length - CREDITS_R, {"kind": "credits", "title": "KẾT A: MINH OAN TRỌN VẸN", "lines": [
		"%s được minh oan. Án đình chỉ: huỷ." % hero_name, "Phúc: được bao che, đã khai hết, được tha.",
		"Anh Duy: deploy thành công.", "Mr.T: lần đầu tan làm đúng giờ.", "Hội Lọ Thần: tan rã.", " ",
		"Khoan đã, đừng tắt máy..."]})
