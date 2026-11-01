# File: res://scripts/cine/timelines/seg_d6_chase.gd
# seg_d6_chase (22.000 s real, plan 2026-11-01-w4-day6 beat d6_boat "after", story spec 8.3 seg_d6_chase): the speedboat
# chase on the Rạch Hầm canal at night, retold as a cinematic after the mission. Five passes along the same 120 m reach (each
# cut hides the jump back):
#   P1 the run: Thị Lọ's pink boat ahead, two Bầy Sói jet skis flank the protagonist's boat ("Đứng lại!").
#   P2 the kick: a jet ski rams from the left, the protagonist stands up and kicks the rider into the canal (hit K1, light).
#   P3 the low bridge ("CẦU THẤP": both duck under it) and the sampan ramp: the protagonist's boat flies over it in slow
#      motion (J1, accent) while the fireworks barge goes off behind.
#   P4 the Titanic: Thị Lọ stands on her bow with her arms out, "Tao là nữ hoàng kênh Rạch Hầm!" - nobody is steering
#      ("Ai lái vậy trời?"); the protagonist rams her stern (R1, accent).
#   P5 her boat swerves into the right bank, nose up on the stones, the cash flies, Thị Lọ is thrown onto the bank and sits
#      there dazed; the protagonist pulls up alongside: "Hết đường chạy rồi nha." (tail 3-4 s at 1x)
# Music slot seg_d6_chase ("Ring of Fire", Des Rocs: the owner file, else silence). No gore: the rider splashes in and swims.
# Stage: CineTimeline.phase_c_stage("bridge") for the gallery; StoryCanal plays it at its CHASE_XF (far from the level) with
# the carried canal (both banks with their water, house rows, the low bridge, the sampan ramp, the fireworks barge; not
# dropped).
# Stage frame: X right, -Z forward (the boats run toward -Z), the water at y = -1, the banks' tops at y = 0; yaw in degrees.
extends CineTimeline

const WATER_Y: float = -1.0
const BANK_X: float = 11.0
const SEAT := Vector3(-0.45, 0.2, 1.0)      # actor root on the speedboat's driver seat (the ride pose: hips on the seat)
const DECK := Vector3(-0.35, 0.47, 0.4)     # standing on the deck beside the console
const BOW := Vector3(0.0, 0.62, -1.55)      # standing on the bow (the Titanic)
const SKI_SEAT := Vector3(0.0, 0.05, 0.5)
const HERO_BOAT := {"color": Color("#F4F1EA"), "trim": Color("#F37021")}
const LO_BOAT := {"color": Color("#FFB3D6"), "trim": Color("#FF4FA3"), "name": "LỌ"}
const BRIDGE_Z: float = -2.0
const RAMP_Z: float = -24.0
const BARGE := Vector3(-7.5, WATER_Y, -48.0)
const K1: float = 7.0
const J1: float = 12.9
const R1: float = 16.6
const CRASH: float = 17.5
const CRASH_AT := Vector3(10.0, -0.45, -24.0)
const LO_BANK := Vector3(12.6, 0.0, -24.6)


func build() -> void:
	slot = "seg_d6_chase"
	length = 22.0
	story_end = 20.516
	mood = "punchy"
	fade_in = 0.4
	fade_out = 0.6
	stage = CineTimeline.phase_c_stage("bridge")
	actor("hero", StoryCast.opts("hero", {"shirt_color": StoryCanal.SHIPPER_SHIRT}), StoryCast.speaker("hero"), StoryCast.color("hero"))
	actor("lo", StoryCast.opts("thi_lo"), StoryCast.speaker("thi_lo"), StoryCast.color("thi_lo"))
	actor("w1", StoryCast.opts("bay_soi", {"seed": 3201}), StoryCast.speaker("bay_soi"), StoryCast.color("bay_soi"))
	actor("w2", StoryCast.opts("bay_soi", {"seed": 3202}), StoryCast.speaker("bay_soi"), StoryCast.color("bay_soi"))
	StoryCast.dress(self, "lo", "thi_lo")
	StoryCast.dress(self, "w1", "bay_soi")
	StoryCast.dress(self, "w2", "bay_soi")
	hit("K1", K1, "light", "the protagonist kicks the jet ski rider off his ski")
	hit("J1", J1, "accent", "the protagonist's boat flies off the sampan ramp, fireworks behind")
	hit("R1", R1, "accent", "the protagonist rams the stern of Thị Lọ's boat")
	_canal_set()
	# --- the boats: [s, pos, rot_deg (pitch, yaw, roll)]; "|" marks a pass cut (the jump back)
	var hb: Array = [
		[0.0, Vector3(1.0, WATER_Y, 30.0), Vector3(-3.0, 0.0, 0.0)], [2.2, Vector3(2.0, WATER_Y, 2.0), Vector3(-3.0, -4.0, 3.0)],
		[4.4, Vector3(0.5, WATER_Y, -25.0), Vector3(-3.0, 2.0, -2.0)],
		[4.4005, Vector3(1.5, WATER_Y, 30.0), Vector3(-3.0, 0.0, 0.0)], [K1, Vector3(1.5, WATER_Y, -4.0), Vector3(-3.0, 0.0, -4.0)],
		[9.0, Vector3(1.5, WATER_Y, -30.0), Vector3(-3.0, 0.0, 0.0)],
		[9.0005, Vector3(0.5, WATER_Y, 24.0), Vector3(-3.0, 0.0, 0.0)], [11.0, Vector3(0.5, WATER_Y, BRIDGE_Z), Vector3(-3.0, 0.0, 0.0)],
		[12.35, Vector3(0.5, WATER_Y, -20.0), Vector3(-3.0, 0.0, 0.0)], [12.6, Vector3(0.5, -0.1, -27.0), Vector3(13.0, 0.0, 0.0)],
		[J1, Vector3(0.5, 1.2, -31.0), Vector3(4.0, 0.0, -3.0)], [13.25, Vector3(0.5, WATER_Y, -36.0), Vector3(-6.0, 0.0, 2.0)],
		[13.6, Vector3(0.5, WATER_Y, -40.0), Vector3(-3.0, 0.0, 0.0)],
		[13.6005, Vector3(1.0, WATER_Y, 20.0), Vector3(-3.0, 0.0, 0.0)], [R1 - 0.1, Vector3(0.0, WATER_Y, -7.2), Vector3(-3.0, 0.0, 0.0)],
		[R1 + 0.2, Vector3(0.1, WATER_Y, -9.3), Vector3(4.0, 0.0, 3.0)], [18.4, Vector3(4.5, WATER_Y, -17.5), Vector3(-2.0, -25.0, 0.0)],
		[19.4, Vector3(6.4, WATER_Y, -20.0), Vector3(0.0, -35.0, 0.0)], [story_end, Vector3(6.6, WATER_Y, -20.3), Vector3(0.0, -35.0, 1.0)]]
	var lb: Array = [
		[0.0, Vector3(-2.0, WATER_Y, 16.0), Vector3(-3.0, 0.0, 0.0)], [2.2, Vector3(-3.0, WATER_Y, -12.0), Vector3(-3.0, 4.0, -3.0)],
		[4.4, Vector3(-1.0, WATER_Y, -39.0), Vector3(-3.0, -3.0, 2.0)],
		[4.4005, Vector3(-1.5, WATER_Y, 15.0), Vector3(-3.0, 0.0, 0.0)], [9.0, Vector3(-2.0, WATER_Y, -45.0), Vector3(-3.0, 0.0, 0.0)],
		[9.0005, Vector3(-2.0, WATER_Y, 12.0), Vector3(-3.0, 0.0, 0.0)], [10.0, Vector3(-2.0, WATER_Y, BRIDGE_Z), Vector3(-3.0, 0.0, 0.0)],
		[11.6, Vector3(-3.4, WATER_Y, -20.0), Vector3(-3.0, 6.0, -3.0)], [13.6, Vector3(-3.0, WATER_Y, -42.0), Vector3(-3.0, 0.0, 0.0)],
		[13.6005, Vector3(-0.8, WATER_Y, 8.0), Vector3(-3.0, 0.0, 0.0)], [R1, Vector3(-0.5, WATER_Y, -14.0), Vector3(-3.0, 0.0, 0.0)],
		[R1 + 0.3, Vector3(0.6, WATER_Y, -16.0), Vector3(-2.0, -30.0, -6.0)], [CRASH - 0.15, Vector3(8.0, WATER_Y, -22.6), Vector3(-2.0, -55.0, -4.0)],
		[CRASH, CRASH_AT, Vector3(16.0, -60.0, -6.0)], [story_end, CRASH_AT, Vector3(16.0, -60.0, -6.0)]]
	prop("hboat", "speedboat", hb[0][1], 0.0, _with(HERO_BOAT, {"path": hb}))
	prop("lboat", "speedboat", lb[0][1], 0.0, _with(LO_BOAT, {"path": lb}))
	# --- the jet skis (P1 flank, P2 the ram and the kick; ski 1 drifts off empty after K1)
	var s1: Array = [
		[0.0, Vector3(-3.4, WATER_Y, 33.0), Vector3(-4.0, 0.0, 0.0)], [4.4, Vector3(-2.6, WATER_Y, -21.0), Vector3(-4.0, 3.0, 4.0)],
		[4.4005, Vector3(-4.5, WATER_Y, 35.0), Vector3(-4.0, 0.0, 0.0)], [6.3, Vector3(-1.4, WATER_Y, 9.5), Vector3(-4.0, -12.0, 10.0)],
		[K1, Vector3(-0.35, WATER_Y, -3.6), Vector3(-4.0, -6.0, 6.0)], [K1 + 0.6, Vector3(-2.2, WATER_Y, -9.0), Vector3(0.0, 25.0, -12.0)],
		[9.0, Vector3(-5.5, WATER_Y, -12.0), Vector3(0.0, 40.0, -4.0)]]
	var s2: Array = [
		[0.0, Vector3(4.6, WATER_Y, 34.0), Vector3(-4.0, 0.0, 0.0)], [4.4, Vector3(4.0, WATER_Y, -20.0), Vector3(-4.0, -3.0, -4.0)],
		[4.4005, Vector3(4.8, WATER_Y, 37.0), Vector3(-4.0, 0.0, 0.0)], [9.0, Vector3(5.0, WATER_Y, -18.0), Vector3(-4.0, 0.0, 0.0)]]
	prop("ski1", "jet_ski", s1[0][1], 0.0, {"color": Color("#25282E"), "path": s1, "hide_at": 9.0})
	prop("ski2", "jet_ski", s2[0][1], 0.0, {"color": Color("#3A3D42"), "path": s2, "hide_at": 9.0})
	# --- the riders
	_ride("w2", s2, SKI_SEAT)
	move("w2", 0.0, "ride")
	show("w2", 9.0, false)
	_ride("w1", s1.slice(0, 5), SKI_SEAT)
	move("w1", 0.0, "ride")
	move("w1", K1 - 0.05, "launched_back", {"fade": 0.03})
	var r_kick: Vector3 = (s1[4][1] as Vector3) + SKI_SEAT
	key("w1", K1 + 0.05, r_kick, -90.0)
	key("w1", K1 + 0.55, r_kick + Vector3(-3.2, 0.6, -2.0), -90.0, {"mode": "linear", "arc": 0.6})
	key("w1", K1 + 0.8, r_kick + Vector3(-3.6, -1.6, -2.4), -90.0, {"mode": "linear"})
	show("w1", K1 + 0.82, false)
	look("w1", 5.0, K1, "hero")
	# the protagonist: drives, stands up for the kick, sits back, ducks the bridge, flies, rams, stands to face her
	_ride("hero", hb.slice(0, 4), SEAT)
	key("hero", K1, _on(hb, K1, DECK), 90.0)
	_ride("hero", hb.slice(5, 17), SEAT)
	key("hero", 6.25, _on(hb, 6.25, SEAT), 0.0)
	key("hero", 6.45, _on(hb, 6.45, DECK), 90.0)
	key("hero", K1 + 0.6, _on(hb, K1 + 0.6, DECK), 90.0)
	key("hero", K1 + 0.9, _on(hb, K1 + 0.9, SEAT), 0.0)
	move("hero", 0.0, "ride")
	move("hero", 6.3, "fight_idle", {"fade": 0.15})
	strike("hero", "K1", "roundhouse")
	move("hero", K1 + 0.7, "ride", {"fade": 0.2})
	move("hero", 10.75, "dodge", {"dur": 0.6, "fade": 0.05})
	move("hero", 11.35, "ride", {"fade": 0.2})
	move("hero", 18.7, "idle", {"fade": 0.3})
	key("hero", 18.7, _on(hb, 18.7, SEAT), -30.0)
	key("hero", 19.1, _on(hb, 19.1, DECK) + Vector3(0.6, 0.0, 0.0), -70.0)
	key("hero", story_end, _on(hb, story_end, DECK) + Vector3(0.6, 0.0, 0.0), -70.0)
	look("hero", 0.0, 6.0, "lo")
	look("hero", 6.0, K1 + 0.4, "w1")
	look("hero", K1 + 0.5, story_end, "lo")
	expr("hero", 0.0, "angry")
	expr("hero", 12.5, "surprised")
	expr("hero", 13.4, "angry")
	expr("hero", 15.4, "done")
	expr("hero", 18.8, "happy")
	# Thị Lọ: drives, ducks, stands on the bow (Titanic), sits back, is thrown onto the bank and sits there dazed
	var titanic: float = 14.0
	var sit_back: float = 15.9
	_ride("lo", lb.slice(0, 9), SEAT)
	_ride("lo", [lb[9]], SEAT)
	key("lo", titanic - 0.05, _on(lb, titanic - 0.05, SEAT), 0.0)
	key("lo", titanic + 0.35, _on(lb, titanic + 0.35, BOW), 0.0)
	key("lo", sit_back - 0.3, _on(lb, sit_back - 0.3, BOW), 0.0)
	key("lo", sit_back + 0.1, _on(lb, sit_back + 0.1, SEAT), 0.0)
	_ride("lo", lb.slice(10, 13), SEAT)
	key("lo", CRASH + 0.02, CRASH_AT + Vector3(-0.3, 0.7, 0.3), -60.0)
	key("lo", CRASH + 0.7, LO_BANK, -60.0, {"mode": "linear", "arc": 0.9})
	key("lo", story_end, LO_BANK, -110.0)
	move("lo", 0.0, "ride")
	move("lo", 9.75, "dodge", {"dur": 0.6, "fade": 0.05})
	move("lo", 10.35, "ride", {"fade": 0.2})
	move("lo", titanic, "victory", {"fade": 0.25})
	move("lo", sit_back, "ride", {"fade": 0.25})
	move("lo", R1, "startled", {"fade": 0.05})
	move("lo", CRASH, "thrown", {"fade": 0.03})
	move("lo", CRASH + 0.7, "stunned", {"fade": 0.15})
	move("lo", CRASH + 1.6, "sit_bench", {"fade": 0.3})
	hold("lo", 0.0, CRASH, "cash_bag", {"bone": "Wrist.L", "offset": Vector3(0.0, -0.05, -0.08)})
	look("lo", 0.0, 13.9, "hero")
	look("lo", 14.0, sit_back, Vector3(0.0, 4.0, -80.0))
	look("lo", sit_back, story_end, "hero")
	expr("lo", 0.0, "happy")
	expr("lo", R1, "surprised")
	expr("lo", CRASH + 1.6, "done")
	# the cash bag on the bank, burst open
	prop("bag", "cash_bag", LO_BANK + Vector3(-1.3, 0.25, 0.9), 70.0, {"open": true, "show_at": CRASH + 0.6})
	# --- sound and FX
	sfx_at(0.05, "engine_roar", -4.0)
	sfx_at(4.45, "engine_roar", -6.0)
	sfx_at(6.2, "wolf_howl", -10.0)
	sfx_at(K1, "impact_heavy", -2.0)
	sfx_at(K1 + 0.75, "slide_whistle", -10.0)
	sfx_at(9.05, "engine_roar", -6.0)
	sfx_at(10.0, "whoosh_down", -6.0)
	sfx_at(11.0, "whoosh_down", -6.0)
	sfx_at(12.55, "impact_medium", -6.0)
	sfx_at(J1, "boom", -10.0)
	sfx_at(13.25, "impact_heavy", -4.0)
	sfx_at(titanic + 0.2, "applause", -14.0)
	sfx_at(R1, "impact_heavy", 0.0)
	sfx_at(CRASH, "crate_smash", 0.0)
	sfx_at(CRASH + 0.05, "boom", -6.0)
	sfx_at(CRASH + 0.75, "body_fall", -6.0)
	sfx_at(CRASH + 1.4, "sad_trombone", -12.0)
	fx_at(K1, "stars", "w1:Head", {})
	fx_at(K1 + 0.8, "dust", r_kick + Vector3(-3.6, -1.4, -2.4), {"power": 0.8})
	fx_at(13.25, "dust", Vector3(0.5, WATER_Y + 0.2, -36.0), {"power": 1.0})
	fx_at(R1, "sparks", Vector3(-0.3, -0.3, -10.4), {"power": 0.8})
	fx_at(CRASH, "debris", CRASH_AT + Vector3(0.0, 0.8, 0.0), {"power": 1.2})
	fx_at(CRASH + 0.05, "dust", CRASH_AT + Vector3(1.0, 0.4, -0.4), {"power": 1.2})
	fx_at(CRASH + 0.65, "debris", LO_BANK + Vector3(-1.2, 0.5, 0.9), {"power": 0.7})
	# --- shots
	shot("S1", 0.0, "static", "high wide over the canal: the pink boat comes at the camera, the protagonist's boat behind, two jet skis flanking",
		{"pos": Vector3(-6.0, 7.0, -42.0), "look": Vector3(0.0, -0.5, 6.0), "fov": 52.0, "hand": 0.2})
	shot("S2", 2.0, "track", "behind the protagonist's boat: the spray, the pink boat ahead, the jet skis either side",
		{"actor": "hero", "offset": Vector3(1.2, 2.0, 7.5), "look": Vector3(-0.5, 0.0, -14.0), "fov": 56.0, "hand": 0.3})
	shot("S3", 4.4, "track", "low on the water: the jet ski closes in on the left",
		{"actor": "w1", "offset": Vector3(-2.6, 0.2, 2.0), "look": Vector3(2.0, 0.6, -5.0), "fov": 52.0, "hand": 0.35})
	two_shot("S4", 6.2, "hero", "w1", {"side": 1.0, "look_y": 1.0, "dist": 4.6, "fov": 50.0})   # the kick
	shot("S5", K1 + 0.35, "track", "the rider sails off his ski into the canal",
		{"actor": "hero", "offset": Vector3(-4.5, 1.6, 3.5), "look": Vector3(-2.5, 0.2, -2.0), "fov": 54.0, "hand": 0.3})
	shot("S6", 9.0, "track", "ahead of the pink boat looking back: the low bridge comes over them, both duck",
		{"actor": "lo", "offset": Vector3(1.0, 1.4, -7.0), "look": Vector3(0.0, 0.8, 6.0), "fov": 56.0, "hand": 0.3})
	shot("S7", 10.4, "static", "under the far side of the bridge, low on the water: the protagonist's boat shoots under it, ducked",
		{"pos": Vector3(3.6, -0.3, BRIDGE_Z - 7.0), "look": Vector3(0.5, -0.2, BRIDGE_Z + 3.0), "fov": 50.0, "hand": 0.2})
	shot("S8", 12.2, "static", "side wide at the sampan: up the ramp, airborne, the fireworks barge bursting behind",
		{"pos": Vector3(-9.5, 0.6, -29.5), "look": Vector3(0.5, 1.5, -31.0), "fov": 56.0})
	hero_shot("S9", J1 - 0.12, "hero", {"side_deg": 30.0, "dist": 3.4, "fov": 58.0})   # the slow-motion apex
	shot("S10", 13.6, "track", "ahead of the pink boat: Thị Lọ climbs onto her bow, arms wide, nobody at the wheel",
		{"actor": "lo", "offset": Vector3(-2.8, 1.0, -6.5), "look": Vector3(0.0, 0.6, 4.0), "fov": 54.0, "hand": 0.3})
	push_in("S11", titanic + 0.6, "lo", {"from": 3.2, "to": 2.6, "side_deg": 20.0, "look_y": 1.4})   # "Tao là nữ hoàng..."
	push_in("S12", 15.5, "hero", {"from": 3.6, "to": 3.1, "side_deg": -20.0, "look_y": 0.9, "fov": 48.0})   # "Ai lái vậy trời?"
	shot("S13", 16.1, "static", "side wide: the protagonist's bow rams her stern, her boat swerves for the bank",
		{"pos": Vector3(-8.5, 1.8, -13.0), "look": Vector3(1.5, -0.4, -13.0), "fov": 56.0})
	shot("S14", CRASH - 0.45, "static", "on the far bank: the pink boat climbs the stones nose up, cash everywhere, Thị Lọ flies onto the bank",
		{"pos": Vector3(4.5, 2.4, -32.0), "look": Vector3(11.0, 0.0, -23.0), "fov": 52.0})
	two_shot("S15", 18.8, "hero", "lo", {"side": -1.0, "look_y": 1.0})   # "Hết đường chạy rồi nha."
	# --- subtitles (real time from the clock)
	sub(_r(0.3), 1.0, "hero", "Đứng lại!")
	sub(_r(1.6), 1.5, "lo", "Bắt được thì bắt!")
	sub(_r(9.4), 0.8, "hero", "Cúi!")
	sub(_r(titanic + 0.6), 2.0, "lo", "Tao là nữ hoàng kênh Rạch Hầm!")
	sub(_r(15.55), 1.2, "hero", "Ai lái vậy trời?")
	joke(_r(15.55), "Thị Lọ does the Titanic pose on her bow while nobody steers her boat")
	sub(_r(18.95), 1.45, "hero", "Hết đường chạy rồi nha.")


## Real time of story time s (the clock with this timeline's ramps).
func _r(s: float) -> float:
	clock.length = length
	clock.story_end = story_end
	return clock.real_at(s)


## Position on a path (linear between its keys) plus a local offset turned with the key's yaw.
static func _on(path: Array, s: float, local: Vector3) -> Vector3:
	var k0: Array = path[0]
	var k1: Array = path[0]
	for i: int in path.size():
		if float(path[i][0]) <= s:
			k0 = path[i]
			k1 = path[mini(i + 1, path.size() - 1)]
	var u: float = clampf((s - float(k0[0])) / maxf(float(k1[0]) - float(k0[0]), 0.0001), 0.0, 1.0)
	var p: Vector3 = (k0[1] as Vector3).lerp(k1[1], u)
	var yaw: float = lerpf((k0[2] as Vector3).y, (k1[2] as Vector3).y, u)
	return p + Basis(Vector3.UP, deg_to_rad(yaw)) * local


## Keys `actor_id` onto every key of a vehicle path (linear, so the rider stays on the seat; the jump-back cuts included).
func _ride(actor_id: String, path: Array, local: Vector3) -> void:
	for k: Array in path:
		var rot: Vector3 = k[2]
		key(actor_id, float(k[0]), (k[1] as Vector3) + Basis(Vector3.UP, deg_to_rad(rot.y)) * local, rot.y, {"mode": "linear"})


## The carried canal reach: both banks with their water, the house rows, the low bridge (P3), the sampan ramp (P3) and the
## fireworks barge (P3-P4).
func _canal_set() -> void:
	for side: float in [-1.0, 1.0]:
		prop("bank_%s" % ("l" if side < 0.0 else "r"), "canal_bank", Vector3(side * BANK_X, 0.0, -20.0), side * 90.0,
			{"w": 130.0, "d": BANK_X})
		prop("houses_%s" % ("l" if side < 0.0 else "r"), "house_row", Vector3(side * (BANK_X + 3.0), 0.0, -20.0), side * 90.0,
			{"n": 18, "seed": 61 if side < 0.0 else 62})
	prop("bridge", "low_bridge", Vector3(0.0, WATER_Y, BRIDGE_Z), 0.0, {"span": BANK_X * 2.0, "clear": 1.75, "show_at": 9.0, "hide_at": 13.6})
	prop("ramp", "sampan", Vector3(0.5, WATER_Y, RAMP_Z), 0.0, {"ramp": true, "show_at": 9.0, "hide_at": 13.6})
	prop("barge", "fireworks", BARGE, 0.0, {"anim": true, "show_at": 9.0, "bursts": [
		[12.3, Vector3(0.0, 16.0, 0.0), Color("#FF4FA3")], [12.6, Vector3(5.0, 19.0, 4.0), Color("#FFE66D")],
		[12.9, Vector3(-4.0, 15.0, 6.0), Color("#5FE0FF")], [13.4, Vector3(2.0, 18.0, -3.0), Color("#FF7A2A")],
		[14.6, Vector3(-3.0, 17.0, 20.0), Color("#FF4FA3")], [15.2, Vector3(4.0, 20.0, 24.0), Color("#FFFFFF")]]})
