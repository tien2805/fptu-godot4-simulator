# File: res://scripts/cine/timelines/cine_d5_choice.gd
# cine_d5_choice (14.000 s, spec C-D8 beats 7-8, C-D9 choice scene 2): Day 5, the server room is burning. Lê Minh Za Mẫn
# stands among the small fires sipping a coffee: "Ổn mà, mọi thứ vẫn ổn." (the "everything is fine" situation, re-staged);
# "Phòng cháy kìa!" - "Cháy là dấu hiệu tăng trưởng nóng."; behind him a "STONKS" chart climbs, then dives (red ticker
# "LỌ THẦN 9.0 -99,9%"): "...Điều chỉnh kỹ thuật thôi." Then the offer: join him, he erases the suspension, "equity 0,01%".
# The frame freezes on choice 2 (StoryChoice at 13.600 s real, the clock holds): "Nhận lời" (key accept) / "Từ chối" (key
# refuse); on timeout the honest option is taken: "Từ chối", with a comic line. The answer goes to
# StoryDirector.choices.zaman_offer (evaluate_ending: "accept" = ending C) and CinePlayer.choice_made("zaman_offer", key, timed_out); the integration then plays cine_d5_choice_accept (then end_c) or
# cine_d5_choice_refuse (then the villain card via show_for and the katana duel).
# No ramps (story = real). Music slot cine_d5_choice (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("server"), the carried room (cine_d5_monitors.server_room); positions shared with the tails.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const ZA := Vector3(-0.6, 0.0, -1.3)
const HERO := Vector3(0.35, 0.0, 1.3)
const STONKS := Vector3(2.3, 0.0, -2.7)
const CHOICE_R: float = 13.6
const DIVE: float = 5.8
const FIRES: Array = [[Vector3(-4.6, 0.0, -2.8), 1.0], [Vector3(4.5, 0.0, -1.7), 0.8], [Vector3(-4.5, 0.0, 0.6), 0.7], [Vector3(-2.6, 0.0, -3.9), 0.9]]


func build() -> void:
	slot = "cine_d5_choice"
	length = 14.0
	story_end = 14.0
	mood = "eerie"
	fade_in = 0.5
	fade_out = 0.3
	stage = CineTimeline.phase_c_stage("server")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("za", StoryCast.opts("za_man"), StoryCast.speaker("za_man"), StoryCast.color("za_man"))
	StoryCast.dress(self, "za", "za_man")
	set_dressing(self)
	prop("stonks", "stonks_screen", STONKS, 200.0, {"anim": true, "dive_at": DIVE, "dive_dur": 1.3})
	# Za Mẫn sips his coffee among the fires, glances at the chart, makes the offer
	var y_za: float = CineTimeline.face(ZA, HERO)
	key("za", 0.0, ZA, y_za)
	move("za", 0.0, "sip")
	hold("za", 0.0, story_end, "coffee_cup", {"offset": Vector3(0.0, 0.02, -0.04)})
	look("za", 0.0, 6.3, "hero")
	key("za", 6.4, ZA, y_za)
	key("za", 6.9, ZA, CineTimeline.face(ZA, STONKS))
	look("za", 6.5, 8.6, STONKS + Vector3(0.0, 1.5, 0.0))
	key("za", 8.6, ZA, CineTimeline.face(ZA, STONKS))
	key("za", 9.0, ZA, y_za)
	look("za", 9.0, 14.0, "hero")
	move("za", 9.0, "talk", {"fade": 0.3})
	move("za", 11.4, "sip", {"fade": 0.3})
	expr("za", 0.0, "happy")
	expr("za", 7.0, "done")
	expr("za", 9.0, "happy")
	# the protagonist
	key("hero", 0.0, HERO, CineTimeline.face(HERO, ZA))
	move("hero", 0.0, "idle")
	look("hero", 0.0, 5.7, "za")
	look("hero", 5.8, 7.2, STONKS + Vector3(0.0, 1.5, 0.0))
	look("hero", 7.3, 14.0, "za")
	move("hero", 2.3, "point", {"fade": 0.2})
	move("hero", 3.6, "idle", {"fade": 0.3})
	move("hero", 9.0, "arms_crossed", {"fade": 0.3})
	expr("hero", 0.0, "surprised")
	expr("hero", 2.3, "angry")
	expr("hero", 9.0, "open")
	sfx_at(0.1, "fire_crackle", -8.0)
	sfx_at(2.1, "fire_crackle", -9.0)
	sfx_at(4.2, "fire_crackle", -9.0)
	sfx_at(DIVE, "slide_whistle", -8.0)
	sfx_at(DIVE + 1.2, "sad_trombone", -8.0)
	sfx_at(9.5, "fire_crackle", -10.0)
	sfx_at(11.6, "fire_crackle", -10.0)
	shot("S1", 0.0, "static", "wide: the burning server room, Za Mẫn sipping a coffee in the middle of it",
		{"pos": Vector3(2.6, 1.7, 4.0), "look": Vector3(-0.4, 1.2, -1.4), "fov": 52.0})
	shot("S2", 0.5, "static", "close: Za Mẫn, \"Ổn mà, mọi thứ vẫn ổn.\"",
		{"pos": Vector3(-0.25, 1.6, -0.35), "look": Vector3(-0.6, 1.55, -1.3), "fov": 38.0, "hand": 0.15})
	shot("S3", 2.2, "static", "close: the protagonist points at the flames",
		{"pos": Vector3(0.0, 1.6, 0.35), "look": Vector3(0.35, 1.55, 1.3), "fov": 40.0})
	shot("S4", 3.4, "static", "two-shot side on: \"Cháy là dấu hiệu tăng trưởng nóng.\"",
		{"pos": Vector3(-3.2, 1.5, 0.6), "look": Vector3(-0.1, 1.3, -0.1), "fov": 44.0})
	shot("S5", 5.7, "static", "insert: the STONKS chart dives, a red ticker",
		{"pos": STONKS + Vector3(-1.0, 1.45, 2.2), "look": STONKS + Vector3(0.0, 1.4, 0.0), "fov": 42.0})
	shot("S6", 7.0, "static", "close: Za Mẫn glances back, \"...Điều chỉnh kỹ thuật thôi.\"",
		{"pos": Vector3(-0.2, 1.6, -0.4), "look": Vector3(-0.6, 1.55, -1.3), "fov": 38.0})
	shot("S7", 8.9, "static", "close: the offer",
		{"pos": Vector3(-0.25, 1.6, -0.35), "look": Vector3(-0.6, 1.55, -1.3), "fov": 36.0, "hand": 0.1})
	shot("S8", 11.4, "static", "two-shot side on: the frame that freezes for the choice",
		{"pos": Vector3(3.0, 1.5, -0.3), "look": Vector3(-0.1, 1.3, 0.0), "fov": 46.0})
	sub(0.6, 1.5, "za", "Ổn mà, mọi thứ vẫn ổn.")
	sub(2.3, 1.0, "hero", "Phòng cháy kìa!")
	sub(3.5, 2.2, "za", "Cháy là dấu hiệu tăng trưởng nóng.")
	sub(7.1, 1.8, "za", "...Điều chỉnh kỹ thuật thôi.")
	sub(9.0, 2.3, "za", "Về phe tôi đi, %s." % StoryCast.speaker("hero"))
	sub(11.45, 2.1, "za", "Xoá án đình chỉ, tặng equity 0,01%.")
	choice(CHOICE_R, {"id": "zaman_offer", "title": "Lựa chọn 2",
		"prompt": "Za Mẫn mời mày vào phe, đổi lại xoá án đình chỉ. Mày chọn sao?",
		"options": [{"key": "accept", "label": "Nhận lời"}, {"key": "refuse", "label": "Từ chối"}],
		"honest": "refuse", "timeout_line": "Im lặng mười giây... Za Mẫn hiểu là mày từ chối. Có cốt khí đó!"})


## The burning server room shared by cine_d5_choice and its tails: the room and racks (cine_d5_monitors.server_room), the
## frozen monitor wall, small fires by the racks, and Za Mẫn's desk behind him with his katana lying on it (taken at
## katana_take in the refuse tail) and, from cup_put on, the coffee cup he puts down there (the tails).
const DESK := Vector3(-1.2, 0.0, -1.75)
const DESK_YAW: float = 40.0
const CUP_ON_DESK := Vector3(-0.91, 0.76, -1.67)
const KATANA_ON_DESK := Vector3(-1.33, 0.785, -1.51)


static func set_dressing(tl: CineTimeline, katana_take: float = -1.0, cup_put: float = -1.0) -> void:
	tl.prop("desk", "desk", DESK, DESK_YAW)
	var rot := Vector3(0.0, DESK_YAW + 90.0, 90.0)   # lying flat along the desk
	var ko: Dictionary = {"bend": 22.0, "path": [[0.0, KATANA_ON_DESK, rot], [1.0, KATANA_ON_DESK, rot]]}
	if katana_take >= 0.0:
		ko["hide_at"] = katana_take
	tl.prop("katana_desk", "katana", KATANA_ON_DESK, DESK_YAW + 90.0, ko)
	if cup_put >= 0.0:
		tl.prop("cup", "coffee_cup", CUP_ON_DESK, 0.0, {"show_at": cup_put})
	(load("res://scripts/cine/timelines/cine_d5_monitors.gd") as GDScript).call("server_room", tl, true)
	tl.prop("wall", "monitor_wall", Vector3(0.0, 0.0, -4.7), 180.0, {"anim": true, "freeze_at": -1.0, "set": true})
	for i: int in FIRES.size():
		tl.prop("fire%d" % i, "fire", FIRES[i][0], 0.0, {"anim": true, "spread": float(FIRES[i][1]), "flames": 5})
