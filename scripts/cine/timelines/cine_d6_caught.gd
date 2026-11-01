# File: res://scripts/cine/timelines/cine_d6_caught.gd
# cine_d6_caught (21.000 s real, plan 2026-11-01-w4-day6 beat d6_caught, master plan section 5 Day 6, story spec 8.4 the
# mirror): Day 6, the back room of "Trà Sữa Lọ". The protagonist reads the ledger (E7) at the vanity, the music box
# tinkling; the sheep dolls on the shelves turn their heads to the protagonist one by one; the bulbs stutter; in the mirror
# a figure stands behind the protagonist (jump scare v2: scare_hit). The protagonist spins round: Thị Lọ, powdering her
# nose with her compact: "Gì?" Two sheep guards come in from the shop and grab the protagonist; Thị Lọ takes the day's
# tip money, slides the rubber band off the wad and hands the band back: "Còn cái nịt." - the frame freezes on her villain
# card (StoryVillainCard, over a dutch angle on her laugh). Tail at 1x: Anh Duy on the radio cuts the power (the main bulb
# dark, only the red vanity bulb left), the protagonist shoves a guard and bolts out the pier door, Thị Lọ in the dark:
# "Bắt nó!" - outside an engine roars (the protagonist's boat at the pier; the chase is next).
# "Giảm hù dọa" (read at build time): the dolls turn slowly, the bulbs only dim once, no distorted bleat, the scare mark
# plays its soft variant.
# Music slot cine_d6_caught (owner file, else silence).
# Stage: CineTimeline.phase_c_stage("yard") (14 x 12) with the carried back room (props "set": true); inside the lair
# StoryCanal plays it at LairCanal.room_xf() with drop_set (the real room) and hides the room's own furniture, the timeline
# brings the same layout (CinePropsD6.backroom_layout) with its cues.
# Room frame: X right, -Z toward the pier door (x = 0.3), the shop door on +Z (x = -3); ground y = 0; yaw in degrees,
# characters face -Z at 0.
extends CineTimeline

const SCARE: float = 4.0
const SPIN: float = 4.35
const CARD_R: float = 14.1
const BLACKOUT: float = 14.5
const HERO := Vector3(-2.4, 0.0, -1.95)      # at the vanity, facing the mirror
const LO := Vector3(-1.25, 0.0, 0.95)        # behind the protagonist, by the music box table
const LO_FRONT := Vector3(-2.2, 0.0, -0.7)
const G_DOOR := Vector3(-3.0, 0.0, 3.3)
const G1 := Vector3(-2.95, 0.0, -2.3)     # behind the protagonist, an arm each
const G2 := Vector3(-1.85, 0.0, -2.3)
const G2_VIA := Vector3(-1.2, 0.0, -0.4)
const PIER_IN := Vector3(0.3, 0.0, -3.0)
const PIER_OUT := Vector3(0.3, 0.0, -5.2)
const HEAD := Vector3(-2.4, 1.5, -1.95)

var calm: bool = false


func build() -> void:
	calm = StoryUtil.reduce_scares()
	slot = "cine_d6_caught"
	length = 21.0
	var card_len: float = StoryCast.card_len("thi_lo")
	story_end = length - card_len   # the card freeze adds card_len real seconds without story time
	mood = "eerie"
	fade_in = 0.5
	fade_out = 0.4
	stage = CineTimeline.phase_c_stage("yard")
	actor("hero", StoryCast.opts("hero", {"shirt_color": StoryCanal.SHIPPER_SHIRT}), StoryCast.speaker("hero"), StoryCast.color("hero"))   # the shipper uniform
	actor("lo", StoryCast.opts("thi_lo"), StoryCast.speaker("thi_lo"), StoryCast.color("thi_lo"))
	actor("duy", StoryCast.opts("anh_duy"), StoryCast.speaker("anh_duy"), StoryCast.color("anh_duy"))
	actor("g1", StoryCast.opts("guard_sheep"), StoryCast.speaker("guard_sheep"), StoryCast.color("guard_sheep"))
	actor("g2", StoryCast.opts("guard_sheep", {"seed": 8105}), StoryCast.speaker("guard_sheep"), StoryCast.color("guard_sheep"))
	StoryCast.dress(self, "lo", "thi_lo")
	StoryCast.dress(self, "g1", "guard_sheep")
	StoryCast.dress(self, "g2", "guard_sheep")
	villain("V1", CARD_R, card_len, StoryCast.villain_data("thi_lo"))
	var g_in: float = 6.6
	var give: float = 11.6
	var snatch: float = 12.1
	var band: float = 12.6
	var bolt: float = BLACKOUT + 0.25
	room_dressing(self, {"turn_at": 2.0, "turn_dur": 2.2 if calm else 0.8, "look_at": HEAD, "play_at": 0.0,
		"flicker": [[3.3, 3.5]] if calm else [[3.3, 3.95]], "dark": [[BLACKOUT, story_end + 1.0]]})
	show("duy", 0.0, false)
	key("duy", 0.0, Vector3(3.5, 0.0, 3.0), 0.0)
	# the protagonist reads the ledger at the vanity, spins round at the figure in the mirror
	key("hero", 0.0, HERO, 0.0)
	key("hero", SPIN, HERO, 0.0)
	key("hero", SPIN + 0.3, HERO, 180.0, {"mode": "out"})
	move("hero", 0.0, "hold_up")
	move("hero", SPIN, "startled", {"dur": 0.6, "fade": 0.05})
	move("hero", SPIN + 0.6, "idle", {"fade": 0.2})
	hold("hero", 0.0, SPIN, "ledger", {"offset": Vector3(0.0, -0.02, -0.09)})
	hold("hero", SPIN, story_end, "ledger", {"bone": "Wrist.L", "offset": Vector3(0.0, -0.02, -0.09)})
	look("hero", 0.0, 1.9, Vector3(-2.4, 1.15, -2.3))
	look("hero", 2.0, SPIN, Vector3(-2.4, 1.5, -3.2))
	look("hero", SPIN + 0.2, bolt, "lo")
	expr("hero", 0.0, "open")
	expr("hero", SCARE + 0.05, "surprised")
	expr("hero", 8.6, "open")
	# Thị Lọ powders her nose, deadpan, then walks up to the protagonist
	show("lo", 0.0, false)
	show("lo", SCARE, true)
	key("lo", 0.0, LO, CineTimeline.face(LO, HERO))
	key("lo", 6.4, LO, CineTimeline.face(LO, HERO))
	key("lo", 7.7, LO_FRONT, CineTimeline.face(LO_FRONT, HERO))
	move("lo", 0.0, "sip")
	hold("lo", SCARE, 6.3, "powder_puff", {"offset": Vector3(0.0, 0.0, -0.02)})
	move("lo", 5.6, "shrug", {"fade": 0.1})
	move("lo", 6.5, "walk", {"fade": 0.2})
	move("lo", 7.7, "talk", {"fade": 0.25})
	look("lo", SCARE, BLACKOUT, "hero")
	expr("lo", 0.0, "done")
	expr("lo", 6.2, "talk")
	# two sheep guards come in from the shop and grab the protagonist
	for g: Array in [["g1", G1, 0.0], ["g2", G2, 0.25]]:
		var id: String = g[0]
		var t0: float = g_in + float(g[2])
		show(id, 0.0, false)
		show(id, t0, true)
		key(id, t0, G_DOOR, 180.0)
		if id == "g2":
			key(id, t0 + 1.1, G2_VIA, CineTimeline.face(G_DOOR, G2_VIA), {"mode": "linear"})
		key(id, t0 + 1.6, g[1], CineTimeline.face(g[1], HERO))
		move(id, t0, "jog")
		move(id, t0 + 1.6, "grab", {"fade": 0.15})
		look(id, t0, story_end, "hero")
	move("hero", g_in + 1.9, "cornered", {"fade": 0.2})
	# the tip money: the protagonist hands it over, Thị Lọ slides the rubber band off and hands the band back
	move("lo", 10.2, "point", {"fade": 0.2})
	move("lo", 11.6, "talk", {"fade": 0.2})
	move("hero", give - 0.3, "present", {"fade": 0.2})
	hold("hero", give, snatch, "cash_wad", {"offset": Vector3(0.0, -0.02, -0.08)})
	hold("lo", snatch, band, "cash_wad", {"offset": Vector3(0.0, -0.02, -0.08)})
	hold("lo", band, story_end, "cash_wad", {"offset": Vector3(0.0, -0.02, -0.08), "no_band": true})
	hold("hero", band, bolt, "cash_wad", {"offset": Vector3(0.0, -0.02, -0.06), "band_only": true})
	move("hero", band + 0.4, "hold_up", {"fade": 0.2})
	expr("hero", band + 0.5, "done")
	move("lo", 13.3, "laugh", {"fade": 0.15})
	expr("lo", 13.3, "happy")
	# the tail: the power dies, the protagonist shoves the guard and bolts out the pier door
	move("hero", bolt, "shove", {"fade": 0.05})
	move("g2", bolt + 0.25, "slip_fall", {"fade": 0.05})
	move("g1", bolt + 0.2, "startled", {"fade": 0.1})
	key("g2", bolt + 0.25, G2, CineTimeline.face(G2, HERO))
	key("g2", bolt + 0.75, G2 + Vector3(0.5, 0.0, 0.3), CineTimeline.face(G2, HERO))
	key("hero", bolt + 0.3, HERO, 180.0)
	key("hero", bolt + 0.5, HERO + Vector3(0.3, 0.0, -0.1), CineTimeline.face(HERO, PIER_IN))
	key("hero", bolt + 1.4, PIER_IN, 180.0, {"mode": "linear"})
	key("hero", bolt + 2.0, PIER_OUT, 180.0, {"mode": "linear"})
	move("hero", bolt + 0.35, "sprint", {"fade": 0.1})
	show("hero", bolt + 2.05, false)
	expr("hero", bolt, "angry")
	# Thị Lọ in the dark: "Bắt nó!"
	move("lo", BLACKOUT + 0.05, "startled", {"fade": 0.05})
	move("lo", 16.6, "point", {"fade": 0.15})
	key("lo", 16.3, LO_FRONT, CineTimeline.face(LO_FRONT, HERO))
	key("lo", 16.7, LO_FRONT, CineTimeline.face(LO_FRONT, PIER_IN))
	look("lo", BLACKOUT + 0.1, story_end, PIER_IN + Vector3(0.0, 1.4, 0.0))
	expr("lo", BLACKOUT + 0.1, "angry")
	sfx_at(0.05, "music_box", -6.0)
	sfx_at(1.6, "heartbeat", -10.0 if calm else -5.0)
	if not calm:
		sfx_at(2.3, "sheep_bleat_distorted", -10.0)
	sfx_at(3.3, "fluoro_buzz", -10.0)
	scare_hit(SCARE, {})
	sfx_at(5.0, "record_scratch", -10.0)
	sfx_at(g_in + 0.1, "door_bang", -6.0)
	sfx_at(snatch, "rustle", -6.0)
	sfx_at(band + 0.3, "ba_dum_tss", -12.0)
	sfx_at(BLACKOUT, "sub_boom", -10.0)
	sfx_at(BLACKOUT + 0.02, "freeze_tick", -4.0)
	sfx_at(bolt + 0.3, "body_fall", -6.0)
	sfx_at(bolt + 1.5, "door_bang", -4.0)
	sfx_at(story_end - 0.6, "engine_roar", -6.0)
	# shots (story times; the card freezes the dutch angle on Thị Lọ's laugh)
	shot("S1", 0.0, "static", "wide from the shop door: the back room, the shelves of sheep dolls (backs turned), the music box, the protagonist at the vanity",
		{"pos": Vector3(-0.6, 1.85, 2.9), "look": Vector3(-2.2, 1.2, -2.2), "fov": 56.0, "hand": 0.15})
	shot("S2", 1.9, "static", "along the left shelves: the dolls turn their heads one by one",
		{"pos": Vector3(-2.6, 1.55, 2.2), "look": Vector3(-4.1, 1.35, -1.0), "fov": 46.0})
	shot("S3", 3.2, "static", "mirror point of view: the protagonist's face, the bulbs stutter, the room behind",
		{"pos": Vector3(-2.35, 1.55, -3.05), "look": Vector3(-2.0, 1.4, -0.4), "fov": 48.0})
	push_in("S4", SPIN + 0.25, "lo", {"from": 2.6, "to": 2.1, "side_deg": 25.0, "look_y": 1.3})   # Q5: powder puff, "Gì?"
	two_shot("S5", 6.2, "hero", "lo", {"side": 1.0, "look_y": 1.2})
	shot("S6", g_in + 0.3, "static", "wide from the pier side: two sheep guards come in from the shop and grab the protagonist",
		{"pos": Vector3(0.9, 1.8, -2.6), "look": Vector3(-2.3, 1.1, 0.0), "fov": 56.0})
	ots_shot("S7", 8.5, "lo", "hero", {"side": 1.0, "look_y": 1.35})   # "Em... đi lạc đó chị."
	push_in("S8", 10.1, "lo", {"from": 2.0, "to": 1.7, "side_deg": -35.0, "look_y": 1.3})   # the hand out for the tip money
	two_shot("S9", give - 0.25, "hero", "lo", {"side": -1.0, "look_y": 1.1})   # the wad, the band, "Còn cái nịt."
	dutch_shot("S10", 13.7, "lo", {"side_deg": 40.0, "dist": 1.8, "push": 0.2, "roll": -12.0, "look_y": 1.25})
	shot("S11", BLACKOUT - 0.1, "static", "wide in the red light: the power dies, the protagonist shoves a guard and bolts for the pier door",
		{"pos": Vector3(-0.2, 2.2, 2.9), "look": Vector3(-0.6, 1.0, -2.6), "fov": 58.0, "hand": 0.2})
	push_in("S12", 16.4, "lo", {"from": 2.4, "to": 2.0, "side_deg": 30.0, "look_y": 1.3})   # "Bắt nó!" in the red light
	# subtitles (real time: after the card, story + card_len)
	var cr: float = card_len
	sub(0.3, 1.5, "hero", "Sổ cái... tên ai cũng có.")
	sub(4.95, 0.9, "lo", "Gì?")
	joke(4.95, "the figure in the mirror is the boss powdering her nose: Gì?")
	sub(6.3, 2.2, "lo", "Shipper gì mà giao tận phòng trong?")
	sub(8.6, 1.5, "hero", "Em... đi lạc đó chị.")
	sub(10.2, 1.7, "lo", "Tiền tip hôm nay. Đưa đây.")
	sub(band + 0.15, 1.3, "lo", "Còn cái nịt.")
	joke(band + 0.15, "she slides the tip money out of its rubber band and hands back the band: Còn cái nịt")
	card("screen", CARD_R + cr + 0.05, 2.5, {"kind": "radio", "sender": "Anh Duy"})
	sub(CARD_R + cr + 0.15, 2.4, "duy", "Cúp cầu dao nè!", "Dịch: Anh tắt điện. Chạy đi!")
	sub(16.65 + cr, 0.95, "lo", "Bắt nó!")


## The back room as the cinematics carry it: the shell (set) and CinePropsD6.backroom_layout() with its cues. cue: turn_at,
## turn_dur, look_at (room frame: every shelf turns its dolls to it), play_at (the music box), open_at (the safe), flicker /
## dark (the main bulb's story windows; the red vanity bulb stays lit through "dark").
static func room_dressing(tl: CineTimeline, cue: Dictionary) -> void:
	tl.prop("room", "backroom", Vector3.ZERO, 0.0, {"set": true})
	var shelf: int = 0
	var bulb: int = 0
	for it: Array in CinePropsD6.backroom_layout():
		var kind: String = it[0]
		var pos: Vector3 = it[1]
		var yaw: float = float(it[2])
		var o: Dictionary = (it[3] as Dictionary).duplicate()
		var id: String = kind
		match kind:
			"doll_shelf":
				id = "shelf%d" % shelf
				shelf += 1
				o["anim"] = true
				o["turn_at"] = float(cue.get("turn_at", INF))
				o["turn_dur"] = float(cue.get("turn_dur", 1.2))
				var look: Vector3 = cue.get("look_at", Vector3(0.0, 1.4, 0.0))
				o["look_at"] = Basis(Vector3.UP, deg_to_rad(yaw)).inverse() * (look - pos)
			"music_box":
				o["anim"] = true
				o["play_at"] = float(cue.get("play_at", INF))
			"safe":
				o["anim"] = true
				o["open_at"] = float(cue.get("open_at", INF))
			"bulb":
				id = "bulb%d" % bulb
				bulb += 1
				if not bool(o.get("bare", false)):
					if cue.has("flicker"):
						o["flicker"] = cue["flicker"]
					if cue.has("dark"):
						o["dark"] = cue["dark"]
		tl.prop(id, kind, pos, yaw, o)
