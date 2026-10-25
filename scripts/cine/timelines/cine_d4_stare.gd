# File: res://scripts/cine/timelines/cine_d4_stare.gd
# cine_d4_stare (10.000 s, spec B-D7 beats 4-5, B-D8 discovery beat + villain card): Day 4, closing time at the canteen.
# Six identical clones eat at three tables in a row facing the protagonist (tray in hand); at 1.2 s every clone stops
# eating at once and stares (look cues), one burps (2.6), they pull sheep masks on together (3.4-4.3), then the freeze
# frame: StoryVillainCard "Cừu Dolly – trùm thi hộ" (3.7-7.0 s real; a "card" clock ramp stops story time) whose arrow
# points at the wrong clone first with "…à nhầm, con kia" and swings to the real Dolly (the clone with the cream wool cuff
# and the sheep keychain). Tail at 1x: the clones stand, Dolly points, "Bắt lấy!" - the brawl starts.
# The arrow targets are projected from shot S4's static camera at build time (16:9 screen fractions).
# Music slot cine_d4_stare (owner file, else no music).
# Stage: CineTimeline.canteen_stage (the nearest clear spot to the canteen, courtyard side; the hall itself is cluttered).
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 1.2)
const SEAT_Z: float = -2.9
const TABLE_Z: float = -2.05
const CLONE_X: Array[float] = [-2.0, -1.2, -0.4, 0.4, 1.2, 2.0]
const DOLLY_I: int = 4          # the real Dolly (x 1.2)
const WRONG_I: int = 2          # the clone the card points at first (x -0.4)
const BURP_I: int = 1
const STARE: float = 1.0
const BURP: float = 2.15
const MASK: float = 2.75
const CARD_R: float = 3.7
const CARD_LEN: float = 3.3      # name + nick + joke (47 characters) read at >= 0.06 s per character
const S4_POS := Vector3(0.0, 1.45, 0.4)
const S4_LOOK := Vector3(0.0, 1.0, -2.6)
const S4_FOV: float = 58.0


func build() -> void:
	slot = "cine_d4_stare"
	length = 10.0
	story_end = 10.0 - CARD_LEN   # the card freeze adds CARD_LEN real seconds without story time
	mood = "eerie"
	fade_in = 0.4
	fade_out = 0.3
	stage = CineTimeline.canteen_stage(Vector2(10.0, 9.0), "sunset")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	for i: int in CLONE_X.size():
		var id: String = _cid(i)
		var cast: String = "dolly_disguised" if i == DOLLY_I else "clone"
		actor(id, StoryCast.opts(cast), "Cừu Dolly" if i == DOLLY_I else StoryCast.speaker("clone"), StoryCast.color(cast))
	# her tells, now visible on the cinematic Dolly: the cream wool cuff and the sheep keychain
	hold(_cid(DOLLY_I), 0.0, story_end, "wool_cuff", {"bone": "Wrist.L", "offset": Vector3(0.0, 0.0, 0.05)})
	hold(_cid(DOLLY_I), 0.0, story_end, "sheep_keychain", {"bone": "Hips", "offset": Vector3(0.16, 0.0, -0.1)})
	for t: int in 3:
		prop("table%d" % t, "table", Vector3(-1.6 + 1.6 * t, 0.0, TABLE_Z), 0.0)
	for i2: int in CLONE_X.size():
		prop("stool%d" % i2, "stool", Vector3(CLONE_X[i2], 0.0, SEAT_Z), 0.0)
		prop("tray%d" % i2, "tray", Vector3(CLONE_X[i2], 0.756, TABLE_Z - 0.18), 0.0, {"food": true})
	villain("V1", CARD_R, CARD_LEN, {"name": "Cừu Dolly", "nick": "trùm thi hộ",
		"joke": "Đếm cừu này thì… trượt môn.", "color": Color("#F2D7A6"),
		"point_wrong": _screen(_head(WRONG_I)), "point_right": _screen(_head(DOLLY_I)), "wrong_line": "…à nhầm, con kia",
		"switch_u": 0.45})
	var s_card: float = story_time("V1")   # story time stands still on the card
	# the protagonist with a tray, frozen to the spot
	key("hero", 0.0, HERO, 0.0)
	move("hero", 0.0, "tray_hold")
	hold("hero", 0.0, story_end, "tray", {"mid": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.12), "food": true})
	look("hero", 0.0, s_card, Vector3(0.0, 1.15, SEAT_Z))   # the whole row (nothing gives the real one away before the card)
	look("hero", s_card, story_end, _head(DOLLY_I) - Vector3(0.0, 0.3, 0.0))
	expr("hero", 0.0, "open")
	expr("hero", STARE + 0.3, "surprised")
	expr("hero", s_card + 0.2, "done")
	key("hero", s_card + 0.5, HERO, 0.0)
	key("hero", s_card + 1.1, HERO + Vector3(0.0, 0.0, 0.35), 0.0)   # one step back (step_back moves the legs)
	move("hero", s_card + 0.5, "step_back", {"dur": 0.6, "fade": 0.1})
	move("hero", s_card + 1.1, "tray_hold", {"fade": 0.15})
	for i3: int in CLONE_X.size():
		var cid: String = _cid(i3)
		var seat := Vector3(CLONE_X[i3], 0.0, SEAT_Z)
		key(cid, 0.0, seat, 180.0)
		move(cid, 0.0, "eat_sit", {"dur": 1.6})
		move(cid, STARE + 0.02 * i3, "stare_sit", {"fade": 0.12})   # all at once (2 frames apart)
		look(cid, STARE, story_end, "hero")
		expr(cid, 0.0, "open")
		expr(cid, STARE, "angry" if i3 != BURP_I else "open")
		# masks on together (the mask appears at the gesture's peak)
		move(cid, MASK, "mask_on", {"fade": 0.1})
		hold(cid, MASK + 0.45, story_end, "sheep_mask", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0)})
		move(cid, MASK + 0.9, "stare_sit", {"fade": 0.15})
		# tail: they stand up and lean in (keys forward while the seated pose blends to standing)
		move(cid, s_card + 0.4 + 0.05 * i3, "fight_idle" if i3 != DOLLY_I else "point", {"fade": 0.6})
		key(cid, s_card + 0.4 + 0.05 * i3, seat, 180.0)
		key(cid, s_card + 1.0 + 0.05 * i3, seat + Vector3(0.0, 0.0, 0.32), 180.0, {"mode": "out"})
	expr(_cid(BURP_I), BURP, "happy")
	sfx_at(STARE, "freeze_tick", -4.0)
	sfx_at(STARE + 0.1, "whisper_bed", -12.0)
	sfx_at(BURP, "burp", -2.0)
	sfx_at(MASK + 0.4, "metal_creak", -10.0)
	sfx_at(s_card, "dun_dun_duun", -3.0)
	sfx_at(s_card + 0.6, "heartbeat", -6.0)
	shot("S1", 0.0, "static", "over the protagonist's shoulder: six identical clones eating in a row",
		{"pos": Vector3(1.3, 1.85, 3.2), "look": Vector3(0.0, 1.0, -2.4), "fov": 55.0})
	shot("S2", STARE, "static", "low from the tables: every clone stops and stares",
		{"pos": Vector3(0.0, 1.05, -0.9), "look": Vector3(0.0, 1.05, -2.9), "fov": 72.0})
	shot("S3", BURP - 0.15, "static", "close: one burps",
		{"pos": Vector3(-0.95, 1.12, -1.55), "look": Vector3(-1.2, 1.12, -2.9), "fov": 40.0})
	shot("S4", MASK - 0.1, "static", "wide row: masks on; the villain card freezes this frame",
		{"pos": S4_POS, "look": S4_LOOK, "fov": S4_FOV})
	shot("S5", s_card + 0.01, "static", "close: the protagonist, \"…Thôi xong.\"",
		{"pos": Vector3(0.35, 1.6, 0.05), "look": Vector3(0.0, 1.55, 1.2), "fov": 38.0})
	shot("S6", s_card + 1.1, "static", "wide side: the clones stand, Dolly points",
		{"pos": Vector3(3.3, 1.6, 1.6), "look": Vector3(0.3, 1.1, -1.6), "fov": 52.0})
	sub(7.2, 1.0, "hero", "…Thôi xong.")
	sub(8.5, 1.0, _cid(DOLLY_I), "Bắt lấy!")


static func _cid(i: int) -> String:
	return "dolly" if i == DOLLY_I else "clone%d" % i


## Stage point a little above clone i's seated head (the arrow tip).
static func _head(i: int) -> Vector3:
	return Vector3(CLONE_X[i], 1.55, SEAT_Z)


## Screen fraction (16:9, Godot's vertical FOV) of a stage point seen from shot S4's static camera.
static func _screen(p: Vector3) -> Vector2:
	var f: Vector3 = (S4_LOOK - S4_POS).normalized()
	var rt: Vector3 = f.cross(Vector3.UP).normalized()
	var up: Vector3 = rt.cross(f)
	var d: Vector3 = p - S4_POS
	var z: float = d.dot(f)
	var th: float = tan(deg_to_rad(S4_FOV) * 0.5)
	var ndc := Vector2(d.dot(rt) / (z * th * 16.0 / 9.0), d.dot(up) / (z * th))
	return Vector2(0.5 + 0.5 * ndc.x, 0.5 - 0.5 * ndc.y)
