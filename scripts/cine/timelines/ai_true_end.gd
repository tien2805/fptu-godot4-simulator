# File: res://scripts/cine/timelines/ai_true_end.gd
# ai_true_end – in-engine fallback (20.000 s, story spec 8.2 AI clip #3, ending A, plan 2026-11-01-w4-endings.md T1): when
# the owner's video user://video/ai_true_end_m.ogv / ai_true_end_f.ogv exists, StoryEndingRunner plays it instead (the
# ai_intro pattern). Sunset on the bank of the Rạch Hầm canal: the "LỌ ACADEMY – Học thật, đậu thật" billboard with Lùm Văn
# Lọ's smug face stands across the water. Anh Duy "deploys" the takedown order from his laptop (jargon + Dịch:), metal
# creaks, the billboard wobbles and topples backward with a boom and a dust cloud. Phúc: "Đỉnh nóc, kịch trần, bay phấp
# phới!" Then the post-credits sting: a white sheep mask floats down the canal, stops, turns to the camera, a distorted
# bleat (softened by "Giảm hù dọa" through StoryAudio.cue_db), "Hẹn gặp lại... năm sau." and dun dun duun.
# No ramps (story = real). Music slot ai_true_end (owner file; CineAudio falls back to end_a's file, else silence).
# Stage: CineTimeline.phase_c_stage("bridge", "sunset") (the canal bank by the Rạch Hầm bridge, 14 x 10); the canal strip
# and the billboard are carried (set: true).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 2.6)
const PHUC := Vector3(-1.3, 0.0, 2.9)
const DUY := Vector3(1.4, 0.0, 2.8)
const BOARD := Vector3(0.5, 0.0, -6.2)
const FALL_FROM: float = 7.0
const FALL_TO: float = 8.2


func build() -> void:
	slot = "ai_true_end"
	length = 20.0
	story_end = 20.0
	mood = "playful"
	fade_in = 0.8
	fade_out = 1.0
	stage = CineTimeline.phase_c_stage("bridge", "sunset")
	for id: String in ["hero", "phuc", "anh_duy"]:
		actor(id, StoryCast.opts(id), StoryCast.speaker(id), StoryCast.color(id))
	StoryCast.dress(self, "anh_duy", "anh_duy")
	prop("canal", "canal", Vector3(0.0, 0.0, -2.2), 0.0, {"set": true, "width": 16.0, "length": 5.4})
	# the billboard faces the bank (yaw 180) and topples backward, away from the viewers (+x about its foot line)
	prop("board", "end_billboard", BOARD, 180.0, {"set": true, "path": [[0.0, BOARD, Vector3(0.0, 180.0, 0.0)],
		[5.4, BOARD, Vector3(0.0, 180.0, 0.0)], [5.8, BOARD, Vector3(-4.0, 180.0, 0.0)], [6.3, BOARD, Vector3(3.0, 180.0, 0.0)],
		[FALL_FROM, BOARD, Vector3(6.0, 180.0, 0.0)], [FALL_TO, BOARD, Vector3(88.0, 180.0, 0.0)],
		[FALL_TO + 0.25, BOARD, Vector3(82.0, 180.0, 0.0)], [FALL_TO + 0.5, BOARD, Vector3(90.0, 180.0, 0.0)]]})
	# the post-credits sheep mask, floating from the left, stopping, turning to the camera
	prop("mask", "sheep_mask", Vector3(-7.0, 0.02, -1.4), 90.0, {"show_at": 13.0, "path": [
		[13.0, Vector3(-7.0, 0.02, -1.4), Vector3(0.0, 90.0, 0.0)], [15.6, Vector3(-0.4, 0.04, -1.4), Vector3(0.0, 90.0, 8.0)],
		[16.2, Vector3(-0.2, 0.02, -1.4), Vector3(0.0, 120.0, -4.0)], [16.8, Vector3(-0.15, 0.03, -1.4), Vector3(0.0, 0.0, 0.0)],
		[20.0, Vector3(-0.1, 0.02, -1.4), Vector3(0.0, 0.0, 3.0)]]})
	# the three on the bank
	key("hero", 0.0, HERO, 0.0)
	key("phuc", 0.0, PHUC, CineTimeline.face(PHUC, BOARD))
	key("anh_duy", 0.0, DUY, CineTimeline.face(DUY, BOARD))
	move("hero", 0.0, "idle")
	move("phuc", 0.0, "idle")
	move("anh_duy", 0.0, "type_sit")
	move("anh_duy", 5.0, "fold_arms", {"fade": 0.3})
	hold("anh_duy", 0.0, 5.0, "laptop", {"bone": "Wrist.L", "mid": "Wrist.R", "offset": Vector3(0.0, -0.03, -0.16)})
	look("hero", 0.0, 1.0, BOARD + Vector3(0.0, 5.5, 0.0))
	look("hero", 1.0, 3.8, "anh_duy")
	look("hero", 3.9, 12.0, BOARD + Vector3(0.0, 4.0, 0.0))
	look("phuc", 0.0, 8.6, BOARD + Vector3(0.0, 4.0, 0.0))
	look("phuc", 8.7, 11.0, "hero")
	look("anh_duy", 0.0, 4.6, Vector3(1.4, 1.0, 2.4))
	look("anh_duy", 4.7, 12.0, BOARD + Vector3(0.0, 4.0, 0.0))
	move("hero", 3.8, "talk", {"fade": 0.2})
	move("hero", 4.9, "idle", {"fade": 0.2})
	move("hero", 8.4, "startled", {"fade": 0.1})
	move("hero", 9.6, "idle", {"fade": 0.3})
	move("phuc", 8.6, "victory", {"fade": 0.15})
	move("phuc", 10.8, "idle", {"fade": 0.3})
	move("hero", 10.8, "talk", {"fade": 0.2})
	move("hero", 12.8, "idle", {"fade": 0.3})
	expr("hero", 0.0, "open")
	expr("hero", 8.3, "surprised")
	expr("hero", 10.8, "happy")
	expr("phuc", 0.0, "open")
	expr("phuc", 8.6, "happy")
	expr("anh_duy", 0.0, "happy")
	sfx_at(4.6, "keyboard_clack", -6.0)
	sfx_at(5.2, "metal_creak", -6.0)
	sfx_at(7.0, "metal_creak", -3.0)
	sfx_at(8.2, "boom", -2.0)
	sfx_at(8.3, "crate_smash", -6.0)
	sfx_at(16.6, "sheep_bleat_distorted", -10.0)
	sfx_at(17.6, "dun_dun_duun", -5.0)
	fx_at(8.2, "dust", BOARD + Vector3(0.0, 0.3, -1.5), {"power": 3.0})
	fx_at(8.25, "debris", BOARD + Vector3(0.0, 0.5, -1.0), {"power": 2.0})
	shot("S1", 0.0, "static", "wide at sunset: the LỌ ACADEMY billboard across the canal, three friends on the bank",
		{"pos": Vector3(3.6, 1.6, 5.6), "look": Vector3(0.2, 3.0, -4.0), "fov": 52.0})
	two_shot("S2", 1.0, "anh_duy", "hero", {"side": 1.0, "look_y": 1.2})
	shot("S3", 5.2, "static", "low: the billboard wobbles and topples backward, Lùm Văn Lọ's smile goes down",
		{"pos": Vector3(-1.2, 0.7, 1.4), "look": Vector3(0.5, 4.6, -6.0), "fov": 56.0})
	push_in("S4", 8.4, "phuc", {"from": 2.8, "to": 2.2, "side_deg": -20.0, "look_y": 1.3})   # "Đỉnh nóc, kịch trần!"
	hero_shot("S5", 10.7, "hero", {"side_deg": 18.0, "dist": 2.6})
	shot("S6", 13.0, "static", "post-credits: the dark water of the canal, a white sheep mask floats in from the left",
		{"pos": Vector3(0.6, 0.7, 1.2), "look": Vector3(-0.6, 0.0, -1.4), "fov": 42.0})
	shot("S7", 16.7, "static", "close: the mask has turned to the camera",
		{"pos": Vector3(-0.15, 0.35, -0.3), "look": Vector3(-0.15, 0.08, -1.4), "fov": 34.0})
	sub(1.2, 2.5, "anh_duy", "Lệnh gỡ biển approve r, a bấm deploy nha.", "Dịch: Gỡ tấm biển xuống.")
	sub(3.9, 0.9, "hero", "Bấm đi anh.")
	sub(8.7, 2.0, "phuc", "Đỉnh nóc, kịch trần, bay phấp phới!")
	sub(10.9, 2.0, "hero", "Học thật, đậu thật. Giờ mới đúng nghĩa.")
	sub(17.4, 2.2, "Số lạ (tin nhắn)", "Hẹn gặp lại... năm sau.")
	joke(8.7, "the billboard face-plants, Phúc: 'Đỉnh nóc, kịch trần, bay phấp phới!'")
	cliffhanger(17.4)
