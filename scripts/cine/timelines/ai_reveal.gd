# File: res://scripts/cine/timelines/ai_reveal.gd
# ai_reveal - in-engine fallback (24.000 s, plan 2026-11-01-w4-day6 beat d6_reveal, story spec Day 6 "AI clip #2: the
# reveal"): the end of Day 6, late at night on the bank under the Rạch Hầm bridge. The protagonist, the ledger in hand:
# "Sổ cái có rồi. Xong một vụ..." A jet ski glides in on the canal, Thị Lọ on the back behind a Bầy Sói rider: "Tưởng vậy
# là xong hả?" She points across the water: the giant LỌ ACADEMY billboard on the far bank flickers on ("ĐẬU 100%, KHÔNG
# CẦN HỌC", the face of Lùm Văn Lọ), fireworks burst behind it. "Anh tao sẽ cho cả trường mày đậu... bằng tool!" -
# "Lùm Văn Lọ... là anh bả?" - "Hẹn gặp ở Lọ Academy nha!" and the jet ski roars off. Joke beat: Phúc texts that Trà Sữa
# Lọ is 50% off tonight (the protagonist facepalms). Q5 cliffhanger: a text from an unknown number, "8 giờ sáng mai cả
# trường thi. Cản nổi không?", then the cliff_sting.
# When the owner's video user://video/ai_reveal_m.ogv / ai_reveal_f.ogv exists, StoryVideo plays it instead (StoryRoam).
# Music slot ai_reveal (owner file user://music/ai_reveal.ogg|.mp3, else no music). No ramps (story = real).
# Stage: CineTimeline.phase_c_stage("bridge") (the real bridge bank, shared with cine_d2) with the carried bank and water
# (set), the billboard and the fireworks across the canal.
# Stage frame: X along the bank, -Z toward the water (y = -1) and the far bank; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const HERO := Vector3(0.0, 0.0, 2.2)
const HERO_FROM := Vector3(-2.6, 0.0, 4.6)
const BOARD := Vector3(0.0, 0.0, -21.0)
const ON_AT: float = 6.6
const ARRIVE: float = 4.4
const LEAVE: float = 16.6


func build() -> void:
	slot = "ai_reveal"
	length = 24.0
	story_end = 24.0
	mood = "eerie"
	fade_in = 0.8
	fade_out = 0.6
	stage = CineTimeline.phase_c_stage("bridge")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("lo", StoryCast.opts("thi_lo"), StoryCast.speaker("thi_lo"), StoryCast.color("thi_lo"))
	actor("w1", StoryCast.opts("bay_soi", {"seed": 3204}), StoryCast.speaker("bay_soi"), StoryCast.color("bay_soi"))
	StoryCast.dress(self, "lo", "thi_lo")
	StoryCast.dress(self, "w1", "bay_soi")
	prop("bank", "canal_bank", Vector3.ZERO, 0.0, {"set": true, "w": 40.0, "d": 30.0})
	prop("board", "billboard", BOARD, 180.0, {"anim": true, "on_at": ON_AT})
	prop("sky", "fireworks", BOARD + Vector3(0.0, 0.0, -8.0), 0.0, {"anim": true, "bursts": [
		[ON_AT + 0.5, Vector3(-6.0, 15.0, 0.0), Color("#FF4FA3")], [ON_AT + 0.9, Vector3(5.0, 17.0, 2.0), Color("#FFE66D")],
		[ON_AT + 1.4, Vector3(0.0, 19.0, -2.0), Color("#5FE0FF")], [12.7, Vector3(-3.0, 16.0, 1.0), Color("#FFFFFF")],
		[12.9, Vector3(4.0, 18.0, -1.0), Color("#FF4FA3")], [13.2, Vector3(0.0, 20.0, 0.0), Color("#FFB020")]]})
	# the jet ski: glides in from the left, idles by the bank, roars off to the right
	var stop := Vector3(-0.6, -1.0, -2.2)
	var rot := Vector3(-3.0, -90.0, 0.0)
	var path: Array = [[0.0, Vector3(-30.0, -1.0, -6.0), Vector3(-4.0, -85.0, 3.0)], [ARRIVE, stop, rot], [LEAVE, stop, rot],
		[LEAVE + 2.6, Vector3(34.0, -1.0, -8.0), Vector3(-6.0, -95.0, -5.0)]]
	prop("ski", "jet_ski", path[0][1], -85.0, {"color": Color("#25282E"), "path": path})
	for rider: Array in [["w1", Vector3(0.0, 0.05, 0.25)], ["lo", Vector3(0.0, 0.1, 0.85)]]:
		for k: Array in path:
			var r: Vector3 = k[2]
			key(String(rider[0]), float(k[0]), (k[1] as Vector3) + Basis(Vector3.UP, deg_to_rad(r.y)) * (rider[1] as Vector3), r.y, {"mode": "linear"})
		move(String(rider[0]), 0.0, "ride")
	look("w1", ARRIVE, LEAVE, "hero")
	# Thị Lọ: points across the water at the billboard, delivers the line, laughs off
	move("lo", 6.2, "point", {"fade": 0.2})
	move("lo", 8.6, "ride", {"fade": 0.25})
	move("lo", 9.9, "taunt", {"fade": 0.2})
	move("lo", 13.4, "laugh", {"fade": 0.2})
	move("lo", 15.4, "ride", {"fade": 0.25})
	look("lo", 2.0, 6.0, "hero")
	look("lo", 6.1, 8.6, BOARD + Vector3(0.0, 6.0, 0.0))
	look("lo", 8.7, story_end, "hero")
	expr("lo", 0.0, "happy")
	expr("lo", 9.9, "angry")
	expr("lo", 13.4, "happy")
	# the protagonist: walks to the edge reading the ledger, turns to the jet ski, to the billboard, gets the texts
	key("hero", 0.0, HERO_FROM, CineTimeline.face(HERO_FROM, HERO))
	key("hero", 2.2, HERO, 0.0, {"mode": "out"})
	key("hero", 3.6, HERO, 0.0)
	key("hero", 4.2, HERO, CineTimeline.face(HERO, stop))
	key("hero", 6.4, HERO, CineTimeline.face(HERO, stop))
	key("hero", 6.9, HERO, 0.0)
	key("hero", 13.6, HERO, 0.0)
	key("hero", 14.0, HERO, CineTimeline.face(HERO, stop))
	move("hero", 0.0, "walk")
	move("hero", 2.2, "hold_up", {"fade": 0.25})
	move("hero", 4.0, "idle", {"fade": 0.2})
	move("hero", 6.9, "step_back", {"fade": 0.15})
	move("hero", 8.0, "idle", {"fade": 0.3})
	move("hero", 14.1, "point", {"fade": 0.2})
	move("hero", 15.4, "idle", {"fade": 0.3})
	move("hero", 18.4, "hold_up", {"fade": 0.2})
	move("hero", 19.2, "facepalm", {"fade": 0.15})
	move("hero", 20.4, "hold_up", {"fade": 0.2})
	hold("hero", 0.0, story_end, "ledger", {"bone": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.09)})
	hold("hero", 18.2, story_end, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	look("hero", 0.0, 3.6, Vector3(0.0, 1.0, 1.9))
	look("hero", 3.7, 6.5, "lo")
	look("hero", 6.6, 13.6, BOARD + Vector3(0.0, 6.0, 0.0))
	look("hero", 13.7, 18.2, "lo")
	look("hero", 18.3, story_end, Vector3(0.12, 1.25, 1.8))
	expr("hero", 0.0, "done")
	expr("hero", 3.8, "surprised")
	expr("hero", 7.0, "surprised")
	expr("hero", 14.0, "angry")
	expr("hero", 19.2, "done")
	expr("hero", 21.1, "surprised")
	sfx_at(2.6, "engine_roar", -10.0)
	sfx_at(ON_AT - 0.1, "static_burst", -8.0)
	sfx_at(ON_AT + 0.3, "dun_dun_duun", -4.0)
	sfx_at(ON_AT + 0.6, "boom", -10.0)
	sfx_at(12.7, "boom", -8.0)
	sfx_at(13.4, "evil_laugh", -8.0)
	sfx_at(LEAVE + 0.1, "engine_roar", -3.0)
	sfx_at(18.2, "phone_buzz", -3.0)
	sfx_at(19.3, "ba_dum_tss", -12.0)
	sfx_at(20.8, "phone_buzz", -3.0)
	sfx_at(21.4, "cliff_sting", -3.0)
	shot("S1", 0.0, "static", "wide at night under the bridge: the protagonist walks to the edge reading the ledger, the dark far bank across the water",
		{"pos": Vector3(3.4, 1.6, 5.6), "look": Vector3(-0.8, 1.0, -2.0), "fov": 52.0, "hand": 0.15})
	shot("S2", 2.6, "static", "low on the water: a jet ski glides in from the dark, Thị Lọ on the back",
		{"pos": Vector3(3.8, -0.4, -4.4), "look": Vector3(-4.0, -0.4, -2.6), "fov": 50.0, "hand": 0.2})
	two_shot("S3", ARRIVE, "hero", "lo", {"side": 1.0, "look_y": 0.9})   # "Tưởng vậy là xong hả?"
	shot("S4", ON_AT - 0.4, "dolly", "crane up over the protagonist's shoulder: the LỌ ACADEMY billboard flickers on across the canal, fireworks",
		{"from": Vector3(0.7, 1.7, 3.4), "to": Vector3(0.9, 2.6, 2.9), "look_from": Vector3(0.0, 2.5, -12.0),
		"look_to": BOARD + Vector3(0.0, 6.5, 0.0), "fov": 50.0})
	push_in("S5", 9.8, "lo", {"from": 3.2, "to": 2.6, "side_deg": 25.0, "look_y": 1.0})   # "Anh tao sẽ cho cả trường..."
	push_in("S6", 13.9, "hero", {"from": 2.8, "to": 2.3, "side_deg": -25.0, "look_y": 1.2})   # "Lùm Văn Lọ... là anh bả?"
	shot("S7", 16.3, "static", "wide: the jet ski roars off right in a fan of spray, the billboard glowing over the water",
		{"pos": Vector3(-4.0, 1.4, 4.4), "look": Vector3(4.0, 2.4, -10.0), "fov": 56.0})
	hero_shot("S8", 18.3, "hero", {"side_deg": -20.0, "dist": 2.6})   # Phúc's text, the facepalm
	shot("S9", 20.7, "static", "close: the phone lights the protagonist's face, the billboard over the shoulder",
		{"pos": Vector3(0.5, 1.6, 0.9), "look": Vector3(-0.1, 1.45, 2.3), "fov": 44.0, "hand": 0.2})
	card("screen", 18.3, 2.3, {"kind": "phone", "sender": "Phúc", "text": "Ê, Trà Sữa Lọ đang giảm 50% nè. Đi không mày?", "time": "23:52"})
	card("screen", 20.9, 2.9, {"kind": "phone", "sender": "Số lạ", "text": "8 giờ sáng mai cả trường thi. Cản nổi không?", "time": "23:59"})
	sub(0.6, 1.9, "hero", "Sổ cái có rồi. Xong một vụ...")
	sub(4.6, 1.6, "lo", "Tưởng vậy là xong hả?")
	sub(10.0, 2.5, "lo", "Anh tao sẽ cho cả trường mày đậu...")
	sub(12.6, 1.2, "lo", "...bằng tool!")
	sub(14.1, 2.0, "hero", "Lùm Văn Lọ... là anh bả?")
	sub(16.3, 1.7, "lo", "Hẹn gặp ở Lọ Academy nha!")
	sub(19.2, 1.5, "hero", "...Phúc ơi là Phúc.")
	joke(19.2, "Phúc texts that Trà Sữa Lọ is 50% off tonight")
	sub(21.0, 2.6, "Số lạ (tin nhắn)", "8 giờ sáng mai cả trường thi. Cản nổi không?")
	cliffhanger(21.0)
