# File: res://scripts/cine/timelines/cine_d2.gd
# cine_d2 (18.000 s, spec C-D6 beat 8, C-D9 end cinematic): Day 2, after the duel, under the Rạch Hầm bridge. Sói Xám sits
# tied to a pillar (rope loops round him and the pillar), his wolf helmet's LED eyes still on; his motorbike's headlight lights
# the scene. "Hàng đi đâu? Nói." - he refuses, then his phone rings (his cheesy synth ringtone): "Ngài Alexander". The
# protagonist picks the phone up and reads the message; Sói Xám gives in: "Hàng về bến container của ngài Alexander." -
# "Alexander nào?" - "Alexander ABCXYZ... tên dài lắm, tao chưa đọc hết bao giờ." The protagonist walks off; a feeble howl,
# the LED eyes flicker out.
# No ramps (story = real). Music slot cine_d2 (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("bridge") (the bank beside the real bridge, 14 x 10), shared with seg_d2_boss: the deck
# overhead is set dressing (drop_set), the pillar, the bike and the rope are choreography.
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

const PILLAR := Vector3(-2.0, 0.0, -2.6)
const SOI := Vector3(-2.0, 0.0, -1.83)          # sitting against the pillar's front face (z -2.15), facing +Z
const BIKE := Vector3(3.0, 0.0, -1.6)
const PHONE := Vector3(-1.45, 0.012, -1.3)
const HERO := Vector3(-1.2, 0.0, -0.62)
const EXIT := Vector3(3.2, 0.0, 1.6)
const LED_OFF: float = 16.9


func build() -> void:
	slot = "cine_d2"
	length = 18.0
	story_end = 18.0
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.6
	stage = CineTimeline.phase_c_stage("bridge")
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("soi", StoryCast.opts("soi_xam"), StoryCast.speaker("soi_xam"), StoryCast.color("soi_xam"))
	StoryCast.dress(self, "soi", "soi_xam", 0.0, LED_OFF)
	# the LED eyes flicker out at the end (the helmet without the glow)
	for w: Array in [[LED_OFF, 17.15, false], [17.15, 17.35, true], [17.35, 18.0, false]]:
		hold("soi", float(w[0]), float(w[1]), "wolf_helmet", {"bone": "Head", "offset": Vector3(0.0, 0.06, 0.0), "led_on": bool(w[2])})
	prop("deck", "bridge_deck", Vector3.ZERO, 0.0, {"set": true, "width": 14.0, "depth": 7.0})
	prop("pillar", "pillar", PILLAR, 0.0)
	prop("pillar_b", "pillar", Vector3(4.6, 0.0, -3.4), 0.0, {"set": true})
	prop("rope", "rope", Vector3(-2.0, 0.0, -2.36), 0.0, {"rx": 0.66, "rz": 0.74, "y": [0.45, 0.7]})
	prop("bike", "motorbike", BIKE, 130.0, {"headlight": true})
	prop("phone", "phone", PHONE, 30.0, {"glow_at": 3.5, "hide_at": 4.6})
	# Sói Xám, tied
	key("soi", 0.0, SOI, 180.0)
	move("soi", 0.0, "tied_sit")
	look("soi", 0.0, 3.4, "hero")
	look("soi", 3.5, 4.4, PHONE)
	look("soi", 4.5, 16.0, "hero")
	expr("soi", 0.0, "angry")
	expr("soi", 3.6, "surprised")
	expr("soi", 8.5, "done")
	# the protagonist: asks, picks the phone up (4.6), reads it, asks again, walks off
	var y_soi: float = CineTimeline.face(HERO, SOI)
	key("hero", 0.0, HERO, y_soi)
	move("hero", 0.0, "arms_crossed")
	look("hero", 0.0, 3.4, "soi")
	look("hero", 3.6, 4.5, PHONE)
	move("hero", 3.9, "idle", {"fade": 0.2})
	key("hero", 3.9, HERO, y_soi)
	key("hero", 4.3, HERO, CineTimeline.face(HERO, PHONE))
	strike("hero", 4.6, "pickup", {"dur": 0.6})
	hold("hero", 4.6, 12.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	move("hero", 5.0, "hold_up", {"fade": 0.25})
	look("hero", 5.2, 8.4, Vector3(-1.05, 1.3, -1.0))
	key("hero", 8.3, HERO, CineTimeline.face(HERO, PHONE))
	key("hero", 8.7, HERO, y_soi)
	look("hero", 8.6, 16.3, "soi")
	move("hero", 12.0, "arms_crossed", {"fade": 0.3})
	expr("hero", 0.0, "angry")
	expr("hero", 5.4, "surprised")
	expr("hero", 9.0, "open")
	expr("hero", 15.0, "done")
	var y_ex: float = CineTimeline.face(HERO, EXIT)
	key("hero", 16.3, HERO, y_soi)
	key("hero", 16.75, HERO, y_ex)
	key("hero", 18.0, HERO.lerp(EXIT, 0.42), y_ex, {"mode": "in"})
	move("hero", 16.8, "walk", {"fade": 0.2})
	sfx_at(3.5, "ringtone_synth", -4.0)
	sfx_at(5.3, "ringtone_synth", -6.0)
	sfx_at(9.2, "ba_dum_tss", -10.0)
	sfx_at(17.0, "wolf_howl", -6.0)
	shot("S1", 0.0, "static", "wide under the bridge: Sói Xám tied to the pillar, the bike's headlight on him",
		{"pos": Vector3(-4.3, 1.7, 2.3), "look": Vector3(-1.5, 0.9, -1.4), "fov": 50.0, "hand": 0.2})
	shot("S2", 1.9, "static", "close: the wolf helmet, LED eyes, \"Tao không nói đâu!\"",
		{"pos": Vector3(-2.35, 1.0, -0.75), "look": Vector3(-2.0, 0.85, -1.8), "fov": 38.0, "hand": 0.15})
	shot("S3", 3.45, "static", "insert: his phone lights up and rings, a cheesy synth tune",
		{"pos": Vector3(-1.95, 0.55, -0.7), "look": PHONE, "fov": 36.0})
	shot("S4", 5.1, "static", "side on: the protagonist reads the message from \"Ngài Alexander\", Sói Xám watching",
		{"pos": Vector3(0.45, 1.5, -1.25), "look": Vector3(-1.4, 1.1, -1.1), "fov": 44.0, "hand": 0.15})
	shot("S5", 8.5, "static", "close: Sói Xám gives in",
		{"pos": Vector3(-2.45, 1.0, -0.7), "look": Vector3(-2.0, 0.85, -1.8), "fov": 38.0, "hand": 0.15})
	shot("S6", 11.9, "static", "close: the protagonist, \"Alexander nào?\"",
		{"pos": Vector3(-1.7, 1.55, -1.45), "look": Vector3(-1.2, 1.5, -0.62), "fov": 38.0})
	shot("S7", 13.2, "static", "two-shot from the side: the endless name",
		{"pos": Vector3(1.4, 1.35, -1.0), "look": Vector3(-1.6, 1.0, -1.3), "fov": 44.0})
	shot("S8", 16.5, "static", "wide: the protagonist walks off, a feeble howl, the LED eyes flicker out",
		{"pos": Vector3(-4.1, 1.5, 0.9), "look": Vector3(-1.2, 0.9, -1.0), "fov": 48.0})
	card("screen", 5.4, 3.0, {"kind": "phone", "sender": "Ngài Alexander", "text": "Hàng về bến container chưa? Nhớ khóa kho kỹ.", "time": "02:41"})
	sub(0.5, 1.3, "hero", "Hàng đi đâu? Nói.")
	sub(2.0, 1.3, "soi", "Tao không nói đâu!")
	sub(3.8, 0.9, "soi", "...Đừng nghe!")
	sub(8.6, 3.2, "soi", "Thôi được! Hàng về bến container của ngài Alexander.")
	sub(12.0, 1.1, "hero", "Alexander nào?")
	sub(13.3, 3.6, "soi", "Alexander ABCXYZ... tên dài lắm, tao chưa đọc hết bao giờ.")
	sub(17.0, 0.8, "soi", "Ao... u...")
