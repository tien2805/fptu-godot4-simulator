# File: res://scripts/cine/timelines/cine_d2.gd
# cine_d2 (18.000 s, spec C-D6 beat 8, C-D9 end cinematic): Day 2, right after seg_d2_boss, under the Rạch Hầm bridge, on the
# same set: the two pillars, the deck overhead, Sói Xám's bike with its headlight on (seg_d2_boss's places). Sói Xám sits
# tied to the pillar he never got to (rope loops round him and it); his wolf helmet's LED eyes stay dark since the chain
# fist. "Hàng đi đâu? Nói." - he refuses, then his phone rings (his cheesy synth ringtone): "Ngài Alexander". The
# protagonist picks the phone up and reads the message; Sói Xám gives in: "Hàng về bến container của ngài Alexander." -
# "Alexander nào?" - "Alexander ABCXYZ... tên dài lắm, tao chưa đọc hết bao giờ." The protagonist walks off; a feeble howl.
# No ramps (story = real). Music slot cine_d2 (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("bridge") (14 x 10), shared with seg_d2_boss: the deck overhead is set dressing
# (drop_set); the pillars, the bike and the rope are choreography. The blocking is authored in a pillar frame (the pillar's
# front toward +Z) and turned onto seg_d2_boss's pillar (its front toward -X) by _m() / _y().
# Stage frame: X right, -Z forward, ground y = 0; yaw in degrees, characters face -Z at 0.
extends CineTimeline

## seg_d2_boss's pillars and bike (CineFightC.SURFACE_FACE_X + 0.51).
const PILLAR_AT := Vector3(2.735, 0.0, 0.75)
const PILLAR_B := Vector3(2.735, 0.0, -1.25)
const BIKE := Vector3(-4.9, 0.0, 2.7)
const BIKE_YAW: float = -61.0
## Authoring frame: the pillar at P_SRC with its front toward +Z.
const P_SRC := Vector3(-2.0, 0.0, -2.6)
const TURN: float = -90.0
const SOI := Vector3(-2.0, 0.0, -1.83)          # sitting against the pillar's front face, facing +Z (authoring frame)
const PHONE := Vector3(-1.45, 0.012, -1.3)
const HERO := Vector3(-1.2, 0.0, -0.62)
const EXIT := Vector3(-2.4, 0.0, 3.6)           # stage frame: off toward the bike


## Authoring frame -> stage frame.
static func _m(v: Vector3) -> Vector3:
	return PILLAR_AT + Basis(Vector3.UP, deg_to_rad(TURN)) * (v - P_SRC)


static func _y(yaw: float) -> float:
	return yaw + TURN


func build() -> void:
	slot = "cine_d2"
	length = 18.0
	story_end = 18.0
	mood = "punchy"
	fade_in = 0.5
	fade_out = 0.6
	stage = CineTimeline.phase_c_stage("bridge")
	var soi: Vector3 = _m(SOI)
	var phone: Vector3 = _m(PHONE)
	var hero: Vector3 = _m(HERO)
	actor("hero", StoryCast.opts("hero"), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("soi", StoryCast.opts("soi_xam"), StoryCast.speaker("soi_xam"), StoryCast.color("soi_xam"))
	StoryCast.dress(self, "soi", "soi_xam", 0.0, -1.0, {"wolf_helmet": {"led_on": false}})   # dark since seg_d2_boss's H4
	prop("deck", "bridge_deck", Vector3.ZERO, 0.0, {"set": true, "width": 14.0, "depth": 8.0})
	prop("pillar", "pillar", PILLAR_AT, 0.0)
	prop("pillar_b", "pillar", PILLAR_B, 0.0)
	prop("rope", "rope", _m(Vector3(-2.0, 0.0, -2.36)), _y(0.0), {"rx": 0.66, "rz": 0.74, "y": [0.45, 0.7]})
	prop("bike", "motorbike", BIKE, BIKE_YAW, {"headlight": true})
	prop("phone", "phone", phone, _y(30.0), {"glow_at": 3.5, "hide_at": 4.6})
	# Sói Xám, tied
	key("soi", 0.0, soi, _y(180.0))
	move("soi", 0.0, "tied_sit")
	look("soi", 0.0, 3.4, "hero")
	look("soi", 3.5, 4.4, phone)
	look("soi", 4.5, 16.0, "hero")
	expr("soi", 0.0, "angry")
	expr("soi", 3.6, "surprised")
	expr("soi", 8.5, "done")
	# the protagonist: asks, picks the phone up (4.6), reads it, asks again, walks off
	var y_soi: float = CineTimeline.face(hero, soi)
	key("hero", 0.0, hero, y_soi)
	move("hero", 0.0, "arms_crossed")
	look("hero", 0.0, 3.4, "soi")
	look("hero", 3.6, 4.5, phone)
	move("hero", 3.9, "idle", {"fade": 0.2})
	key("hero", 3.9, hero, y_soi)
	key("hero", 4.3, hero, CineTimeline.face(hero, phone))
	strike("hero", 4.6, "pickup", {"dur": 0.6})
	hold("hero", 4.6, 18.0, "phone", {"offset": Vector3(0.0, 0.0, -0.02), "glow": true})
	move("hero", 5.0, "hold_up", {"fade": 0.25})
	look("hero", 5.2, 8.4, _m(Vector3(-1.05, 1.3, -1.0)))
	key("hero", 8.3, hero, CineTimeline.face(hero, phone))
	key("hero", 8.7, hero, y_soi)
	look("hero", 8.6, 15.9, "soi")
	look("hero", 16.3, 18.0, hero + Vector3(0.0, 1.25, 0.0) + (EXIT - hero).normalized() * 0.4)
	move("hero", 12.0, "arms_crossed", {"fade": 0.3})
	expr("hero", 0.0, "angry")
	expr("hero", 5.4, "surprised")
	expr("hero", 9.0, "open")
	expr("hero", 15.0, "done")
	# Q5 cliffhanger: the phone buzzes again; the protagonist turns away to read it
	var y_ex: float = CineTimeline.face(hero, EXIT)
	key("hero", 15.9, hero, y_soi)
	key("hero", 16.3, hero, y_ex)
	move("hero", 16.1, "hold_up", {"fade": 0.2})
	expr("hero", 16.5, "surprised")
	sfx_at(3.5, "ringtone_synth", -4.0)
	sfx_at(5.3, "ringtone_synth", -6.0)
	sfx_at(9.2, "ba_dum_tss", -10.0)
	sfx_at(16.1, "phone_buzz", -3.0)
	sfx_at(16.8, "cliff_sting", -3.0)
	shot("S1", 0.0, "static", "wide under the bridge: Sói Xám tied to the pillar, the bike's headlight on him",
		{"pos": _m(Vector3(-4.3, 1.7, 2.3)), "look": _m(Vector3(-1.5, 0.9, -1.4)), "fov": 50.0, "hand": 0.2})
	shot("S2", 1.9, "static", "close: the wolf helmet, LED eyes dark, \"Tao không nói đâu!\"",
		{"pos": _m(Vector3(-2.35, 1.0, -0.75)), "look": _m(Vector3(-2.0, 0.85, -1.8)), "fov": 38.0, "hand": 0.15})
	shot("S3", 3.45, "static", "insert: his phone lights up and rings, a cheesy synth tune",
		{"pos": _m(Vector3(-1.95, 0.55, -0.7)), "look": phone, "fov": 36.0})
	shot("S4", 5.1, "static", "side on: the protagonist reads the message from \"Ngài Alexander\", Sói Xám watching",
		{"pos": _m(Vector3(0.45, 1.5, -1.25)), "look": _m(Vector3(-1.4, 1.1, -1.1)), "fov": 44.0, "hand": 0.15})
	dutch_shot("S5", 8.5, "soi", {"look_y": 0.75, "height": 0.95, "dist": 2.6, "roll": 14.0, "hand": 0.15})   # Q5: the villain gives in
	shot("S6", 11.9, "static", "close: the protagonist, \"Alexander nào?\"",
		{"pos": _m(Vector3(-1.7, 1.55, -1.45)), "look": _m(Vector3(-1.2, 1.5, -0.62)), "fov": 38.0})
	two_shot("S7", 13.2, "hero", "soi", {"look_y": 1.0, "dist": 3.6})   # the endless name (the joke)
	push_in("S8", 16.1, "hero", {"from": 3.4, "to": 2.4, "side_deg": 50.0, "look_y": 1.2})   # the cliffhanger text
	card("screen", 5.4, 3.0, {"kind": "phone", "sender": "Ngài Alexander", "text": "Hàng về bến container chưa? Nhớ khóa kho kỹ.", "time": "02:41"})
	sub(0.5, 1.3, "hero", "Hàng đi đâu? Nói.")
	sub(2.0, 1.3, "soi", "Tao không nói đâu!")
	sub(3.8, 0.9, "soi", "...Đừng nghe!")
	sub(8.6, 3.2, "soi", "Thôi được! Hàng về bến container của ngài Alexander.")
	sub(12.0, 1.1, "hero", "Alexander nào?")
	sub(13.3, 3.0, "soi", "Alexander ABCXYZ... tên dài lắm, tao chưa đọc hết.")
	sub(16.4, 1.4, "hero", "...'Sói? Ta đang tới.'")
	joke(13.3, "Sói Xám has never read Alexander's whole name either")
	cliffhanger(16.4)
