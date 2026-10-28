# File: res://scripts/cine/timelines/cine_d5.gd
# cine_d5 (18.000 s, spec C-D8 beat 11, C-D9 end cinematic): Day 5, the server room after the katana duel; the fires are out,
# smoke and the red emergency light. Za Mẫn sits slumped against a rack holding the hilt of his broken katana: "Bảo hành...
# bảy ngày...". The protagonist opens the transaction logs (E6) on a laptop; the money flow (StoryScreenCard "flow") runs
# from "LỌ THẦN 9.0" through an anonymous wallet to "TRÀ SỮA LỌ". "...Trà Sữa Lọ?" - "Trà sữa ngon lắm... size L, ít đá..."
# - "Lọ Thần. Trà Sữa Lọ. Lọ hết trơn." - the phone buzzes: "Chủ quán là ai đây..."
# No ramps (story = real). Music slot cine_d5 (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("server"), the carried room (cine_d5_monitors.server_room).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const ZA := Vector3(-4.55, 0.0, -2.25)        # sitting against the left racks (their front face at x -4.9), facing +X
const DESK := Vector3(0.9, 0.0, -1.6)
const LAPTOP := Vector3(0.9, 0.75, -1.65)
const HERO := Vector3(0.9, 0.0, -0.95)         # at the desk, facing the laptop (-Z)
const HILT := Vector3(-0.15, 0.0, -0.05)


func build() -> void:
	slot = "cine_d5"
	length = 18.0
	story_end = 18.0
	mood = "eerie"
	fade_in = 0.5
	fade_out = 0.7
	stage = CineTimeline.phase_c_stage("server")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("za", StoryCast.opts("za_man"), StoryCast.speaker("za_man"), StoryCast.color("za_man"))
	StoryCast.dress(self, "za", "za_man")
	(load("res://scripts/cine/timelines/cine_d5_monitors.gd") as GDScript).call("server_room", self, true)
	prop("wall", "monitor_wall", Vector3(0.0, 0.0, -4.7), 180.0, {"anim": true, "freeze_at": -1.0, "set": true})
	prop("desk", "desk", DESK, 0.0)
	prop("laptop", "laptop", LAPTOP, 180.0, {"glow_at": 1.8})
	prop("blade", "katana_blade", Vector3(-3.2, 0.02, -1.0), 70.0)
	# Za Mẫn, slumped, hugging the hilt
	key("za", 0.0, ZA, -90.0)
	move("za", 0.0, "slumped")
	hold("za", 0.0, 18.0, "katana", {"broken": true, "offset": HILT, "rot": Vector3(60.0, 0.0, 0.0)})
	look("za", 0.0, 10.8, Vector3(-3.2, 0.3, -1.0))
	look("za", 10.9, 18.0, "hero")
	expr("za", 0.0, "done")
	expr("za", 11.0, "happy")
	# the protagonist reads the logs, turns to Za Mẫn, back, then the phone
	key("hero", 0.0, HERO + Vector3(1.2, 0.0, 1.5), CineTimeline.face(HERO + Vector3(1.2, 0.0, 1.5), HERO))
	key("hero", 1.4, HERO, CineTimeline.face(HERO + Vector3(1.2, 0.0, 1.5), HERO), {"mode": "out"})
	key("hero", 1.8, HERO, 0.0)
	move("hero", 0.0, "walk")
	move("hero", 1.4, "idle", {"fade": 0.25})
	look("hero", 1.8, 10.6, LAPTOP + Vector3(0.0, 0.15, 0.0))
	key("hero", 10.7, HERO, 0.0)
	key("hero", 11.1, HERO, CineTimeline.face(HERO, ZA))
	look("hero", 11.0, 13.4, "za")
	key("hero", 13.4, HERO, CineTimeline.face(HERO, ZA))
	key("hero", 13.8, HERO, 0.0)
	look("hero", 13.6, 15.4, LAPTOP + Vector3(0.0, 0.15, 0.0))
	hold("hero", 15.7, 18.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	move("hero", 15.7, "hold_up", {"fade": 0.25})
	move("hero", 13.6, "facepalm", {"fade": 0.15})
	look("hero", 15.8, 18.0, Vector3(1.05, 1.3, -1.25))
	expr("hero", 0.0, "open")
	expr("hero", 9.8, "surprised")
	expr("hero", 13.5, "angry")
	expr("hero", 16.0, "surprised")
	sfx_at(2.0, "keyboard_clack", -10.0)
	sfx_at(4.4, "phone_buzz", -14.0)
	sfx_at(9.7, "dun_dun_duun", -6.0)
	sfx_at(15.6, "phone_buzz", -4.0)
	sfx_at(16.4, "cliff_sting", -3.0)
	shot("S1", 0.0, "static", "wide: the scorched server room, Za Mẫn slumped against the racks with a broken katana",
		{"pos": Vector3(3.0, 1.7, 3.6), "look": Vector3(-1.6, 1.0, -1.6), "fov": 52.0})
	shot("S2", 0.4, "static", "close: Za Mẫn, \"Bảo hành... bảy ngày...\"",
		{"pos": Vector3(-3.4, 0.95, -2.0), "look": Vector3(-4.55, 0.8, -2.25), "fov": 40.0})
	shot("S3", 2.0, "static", "over the protagonist's shoulder: the transaction logs on the laptop",
		{"pos": Vector3(1.45, 1.65, -0.25), "look": LAPTOP + Vector3(0.0, 0.15, 0.0), "fov": 40.0})
	push_in("S4", 9.7, "hero", {"from": 2.7, "to": 2.3, "side_deg": 30.0, "look_y": 1.2})   # Q5: "...Trà Sữa Lọ?"
	shot("S5", 10.9, "static", "close: Za Mẫn, dreamy: the milk tea",
		{"pos": Vector3(-3.4, 0.95, -2.0), "look": Vector3(-4.55, 0.8, -2.25), "fov": 40.0})
	two_shot("S6", 13.4, "hero", "za", {"side": 1.0, "look_y": 1.0, "dist": 6.2})   # "Lọ Thần. Trà Sữa Lọ. Lọ hết trơn."
	push_in("S7", 15.6, "hero", {"from": 3.0, "to": 2.3, "side_deg": -30.0, "look_y": 1.2})   # the cliffhanger text
	card("screen", 4.4, 5.2, {"kind": "flow", "title": "NHẬT KÝ GIAO DỊCH", "nodes": ["LỌ THẦN 9.0", "VÍ ẨN DANH", "TRÀ SỮA LỌ"],
		"amounts": ["2,4 tỷ", "2,4 tỷ"]})
	sub(0.5, 1.5, "za", "Bảo hành... bảy ngày...")
	sub(2.2, 1.9, "hero", "Tiền của Lọ Thần chảy về đâu?")
	sub(9.8, 1.0, "hero", "...Trà Sữa Lọ?")
	sub(11.0, 2.3, "za", "Trà sữa ngon lắm... size L, ít đá...")
	sub(13.5, 2.05, "hero", "Lọ Thần. Trà Sữa Lọ. Lọ hết trơn.")
	sub(15.8, 2.17, "hero", "...'Trà sữa size L, ít đá. Tao mời.'")
	joke(11.0, "Za Mẫn, beaten, dreams of milk tea: size L, ít đá")
	cliffhanger(15.8)
