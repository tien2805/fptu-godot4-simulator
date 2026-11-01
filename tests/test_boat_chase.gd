# File: res://tests/test_boat_chase.gd
# W4 Day 6 T4 (plan 2026-11-01-w4-day6.md): the speedboat chase (MissionBoatChase on BoatChase) in the StoryCanal scene,
# no story running. The boat is teleported along the LairCanal course to each set piece (chase.input_override drives it).
#   start: the chase camera, the hidden walking body, the boat at checkpoint 0, Thị Lọ ahead, the markers, the music slot;
#   handling: full throttle -> v_max, the camera behind the boat, a wider FOV; the bank wall scrapes the hull;
#   the low bridges: "CÚI! [CTRL]" before them, upright = BONK (hull, speed, stun, the low camera), ducked = "duck_ok";
#   the nets: the covered half stops the boat, the free half passes; the sampan ramp: on its line fast = the jump over the
#   broken pier wall, off the line = the wall, the gap by the left bank passes, too slow = a flop into the wall;
#   the fireworks barge bumps the boat off; jet skis: a wave behind the boat, the markers, one red-ring telegraph at a time,
#   the ram hurts, [E] kicks the one on the right off (KO, splash, gone), a jet ski driving into a net is out;
#   the finale: rams push Thị Lọ to the bank, the last one crashes her -> won -> done;
#   T6 set pieces: a preview cut as the first bridge comes up; the net lies under the water and rises with its red top
#   line (a net still down catches nothing); the ramp jump in slow motion on the side camera; the fireworks barge's sky
#   bursts and rogue rockets (a red ring where each lands: a straight boat is hit, a swerve dodges); her Titanic pose on
#   the bow at the finale; the finish orbit;
#   fails: the hull at 0 -> "TOANG!" / "Cano nát bét rồi.", THỬ LẠI at the last checkpoint; falling too far behind ->
#   "Thị Lọ chạy mất tiêu rồi."; leaving restores the player; Dễ values.
# Run:  godot --headless --path . --script tests/test_boat_chase.gd
extends SceneTree

const DT: float = 1.0 / 60.0
const CANAL: String = "res://scenes/story/StoryCanal.tscn"
var TMP: String = "user://test_boat_chase_%d.cfg" % OS.get_process_id()
var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var total: int = 0
var sc: StoryCanal
var mn: MissionBoatChase
var chase: BoatChase
var inp: Dictionary = {"throttle": 0.0, "steer": 0.0, "duck": false}
var fail_title: String = ""
var fail_reason: String = ""
var done_info: Dictionary = {}
var got_done: bool = false
var hold: Callable = Callable()
var mark: Dictionary = {}
var kicked: JetSki = null


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("--- TEST BOAT CHASE (Day 6) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	StoryRankCard.skip_all = true
	StoryCanal.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 5}, "capture_mouse": false, "go_roam": false}


func _next(p: int) -> void:
	phase = p
	frames = 0


func _start() -> MissionBoatChase:
	_check(sc.start_mission(StoryMissions.beat("d6_boat")), "d6_boat starts in the canal scene")
	var m: StoryMission = sc.mission_node
	for c: Dictionary in m.done.get_connections():
		m.done.disconnect(c["callable"])     # no story running: the test reads the result itself
	for c2: Dictionary in m.failed.get_connections():
		m.failed.disconnect(c2["callable"])
	m.failed.connect(func(t: String, r: String) -> void:
		fail_title = t
		fail_reason = r)
	m.done.connect(func(info: Dictionary) -> void:
		got_done = true
		done_info = info)
	fail_title = ""
	fail_reason = ""
	got_done = false
	done_info = {}
	var b: MissionBoatChase = m as MissionBoatChase
	if b:
		chase = b.chase
		chase.input_override = inp
	return b


## The boat at (s, d, v) with a full hull, Thị Lọ `ahead` m in front, the jet skis gone (waves off unless `waves`).
func _tp(s: float, d: float, v: float, ahead: float = 24.0, waves: bool = false) -> void:
	chase.boat.place(s, d, v)
	chase.boat.hull = BoatData.HULL
	chase.rival.place(s + ahead, 0.0, v)
	for sk: JetSki in chase.skis:
		sk.retire()
	chase._attacker = null
	var wi: int = 0
	while wi < BoatData.WAVES.size() and float(BoatData.WAVES[wi][0]) <= s:
		wi += 1
	chase.wave_i = wi if waves else BoatData.WAVES.size()
	chase.hits.clear()
	chase.finale = false                  # past FINALE_S the next step starts the finale (its log, signal, popup)
	chase.lose_t = 0.0
	chase._wall_cd = 0.0
	chase._barge_cd = 0.0
	chase._cam_init = false
	chase.set_pieces.reset(s)
	inp["throttle"] = 1.0
	inp["steer"] = 0.0
	inp["duck"] = false


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	root.push_input(up)


func _cnt(key: String) -> int:
	return chase.log.count(key)


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 14000:
		_check(false, "timeout in phase %d" % phase)
		phase = 99
	if hold.is_valid():
		hold.call()
	if is_instance_valid(mn) and mn.state == "running":
		mn.advance(DT)
	match phase:
		0:
			sc = (load(CANAL) as PackedScene).instantiate()
			root.add_child(sc)
			_next(1)
		# ------------------------------------------------------------------ start
		1:
			if frames < 3:
				return false
			mn = _start()
			_check(mn != null, "MissionBoatChase for the boat task")
			if mn == null:
				phase = 99
				return false
			_check(chase.state == "running" and chase.cam.current, "the chase runs on its own camera")
			_check(not sc.player.visible and not sc.player.controls_enabled, "the walking body hidden, its controls off")
			_check(is_equal_approx(chase.boat.s, float(BoatData.CHECKPOINTS[0])) and is_equal_approx(chase.boat.hull, BoatData.HULL), "the boat at checkpoint 0, a full hull")
			_check(is_equal_approx(chase.rival.s - chase.boat.s, BoatData.RIVAL_GAP), "Thị Lọ %d m ahead" % int(BoatData.RIVAL_GAP))
			_check(chase.boat.rider != null and chase.rival.driver != null and chase.skis.size() == BoatChase.MAX_SKIS and chase.skis[0].rider != null, "the protagonist at the wheel, Thị Lọ at hers, the pooled jet ski riders")
			_check(chase.boat.spray != null and chase.rival.spray != null, "bow sprays")
			_check(mn.markers.is_tracked(chase.rival) and mn.markers.is_on(chase.rival), "Thị Lọ always marked")
			var sk_ok: bool = true
			for sk: JetSki in chase.skis:
				sk_ok = sk_ok and mn.markers.is_tracked(sk) and not mn.markers.is_on(sk)
			_check(sk_ok, "every pooled jet ski tracked, none shown before a wave")
			_check(chase.skis[0].ski.is_in_group(Readability.GROUP) and chase.rival.hull_node.is_in_group(Readability.GROUP), "the Q3 enemy rim on the jet skis and on Thị Lọ's boat")
			_check(mn.markers.is_tracked(mn.hazard_mark) and not mn.markers.is_on(mn.hazard_mark), "the next-hazard marker off (the first bridge is far)")
			_check(sc.music_slot == "mission_boat", "the mission_boat music slot (%s)" % sc.music_slot)
			_check(mn.hud_info.text.begins_with("Thị Lọ:"), "HUD: the gap to Thị Lọ (%s)" % mn.hud_info.text)
			inp["throttle"] = 1.0
			_next(2)
		# ------------------------------------------------------------------ handling
		2:
			if frames < 180:
				return false
			var b: PlayerBoat = chase.boat
			_check(absf(b.v - BoatData.v_max()) < 0.5, "full throttle reaches v_max (%.1f)" % b.v)
			var gap: float = chase.rival.s - b.s
			_check(gap > BoatData.RIVAL_GAP_MIN - 0.5 and gap < 40.0, "the rubber band keeps her ahead (%.1f m)" % gap)
			var yaw: float = sc.level.yaw_at(b.s)
			var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
			_check((b.global_position - chase.cam.global_position).dot(fwd) > 4.0 and chase.cam.global_position.y > b.global_position.y + 1.5, "the camera behind and above the boat")
			_check(chase.cam.fov > 70.0, "a wider FOV at top speed (%.1f)" % chase.cam.fov)
			_check(chase.boat.spray.emitting, "the bow spray at speed")
			inp["steer"] = 1.0
			_next(3)
		3:
			if not chase.log.has("scrape"):
				if frames > 240:
					_check(false, "the bank wall scrapes")
					_next(4)
				return false
			_check(absf(chase.boat.d - (LairCanal.HALF_W - BoatData.BEAM_HALF)) < 0.05 and chase.boat.hull < BoatData.HULL, "the right bank stops the boat and scrapes the hull (%.1f)" % chase.boat.hull)
			_tp(310.0, 0.0, 20.0)
			_next(4)
		# ------------------------------------------------------------------ low bridges
		4:
			if frames == 2:
				_check(mn.hud_prompt.text == BoatData.T_DUCK and mn.hud_prompt.visible, "\"CÚI! [CTRL]\" before the low bridge (%s)" % mn.hud_prompt.text)
				_check(mn.markers.is_on(mn.hazard_mark) and mn.hazard_kind == "bridge", "the next-hazard marker on the bridge")
			if not chase.log.has("bridge_hit"):
				if chase.boat.s > 336.0 or frames > 200:
					_check(false, "an upright head hits the bridge")
					_next(5)
				return false
			var b4: PlayerBoat = chase.boat
			_check(is_equal_approx(b4.hull, BoatData.HULL - BoatData.dmg_bridge()) and b4.stun_t > 0.0 and b4.v < 12.0, "BONK: the hull, the speed, a stun (%.1f, v %.1f)" % [b4.hull, b4.v])
			_check(mn.popup_label.text == BoatData.T_BONK, "the bonk popup")
			_check(chase.cam.global_position.y < LairCanal.WATER_Y + 2.2, "the camera drops under the deck (y %.2f)" % chase.cam.global_position.y)
			_next(5)
		5:
			if chase.boat.s < 337.0 and frames < 300:
				return false
			_check(_cnt("bridge_hit") == 1, "one bonk per bridge")
			_tp(740.0, 0.0, 20.0)
			inp["duck"] = true
			mark["low"] = false
			_next(6)
		6:
			var b6: PlayerBoat = chase.boat
			if b6.s > 755.0 and b6.s < 765.0 and b6.ducked() and b6.rider.position.y < PlayerBoat.SEAT.y - 0.2:
				mark["low"] = true
			if b6.s < 766.0 and frames < 300:
				return false
			_check(chase.log.has("duck_ok") and _cnt("bridge_hit") == 1 and is_equal_approx(b6.hull, BoatData.HULL), "ducked under the bridge: duck_ok, no hit")
			_check(bool(mark["low"]), "the duck folds the rider down")
			_tp(540.0, -5.0, 20.0)
			_check(not chase.set_pieces.net_live(0) and sc.level.nets[0].net.position.y < -1.0, "the net lies under the water")
			mark["net_rising"] = false
			_next(7)
		# ------------------------------------------------------------------ nets
		7:
			if chase.log.has("net_up0") and not bool(mark["net_rising"]):
				mark["net_rising"] = true
				_check(sc.level.nets[0].net_top.visible and chase.log.has("cut_net") and mn.popup_label.text.begins_with("Lưới"), "the net rises with its red top line, a preview cut, a warning")
			if not chase.log.has("net_hit"):
				if chase.boat.s > 626.0 or frames > 300:
					_check(false, "the net on the left half stops the boat")
					_next(8)
				return false
			_check(chase.boat.v < 9.0 and mn.popup_label.text == BoatData.T_NET, "Dính lưới: the speed gone (%.1f)" % chase.boat.v)
			_tp(650.0, -5.0, 20.0)
			_next(8)
		8:
			if chase.boat.s < 676.0 and frames < 300:
				return false
			_check(_cnt("net_hit") == 1, "the right half's net leaves the left half free")
			_tp(870.0, LairCanal.RAMP_D, 24.0, 60.0)
			mark["air"] = 0.0
			_next(9)
		# ------------------------------------------------------------------ sampan ramp, pier wall
		9:
			mark["air"] = maxf(float(mark["air"]), chase.boat.air_h)
			if chase.boat.airborne and not mark.has("jump_cam"):
				var ic: Impact = Impact.find_clock(chase)
				mark["jump_cam"] = chase.set_pieces.cam_mode == "jump" and ic != null and ic.slowmo_active(chase.set_pieces)
				mark["jump_side"] = chase.cam.global_position.distance_to(sc.level.course_pos(LairCanal.RAMP_S + 6.0, -(LairCanal.HALF_W - 0.8), 2.4)) < 0.1
			if not (chase.log.has("jump") and chase.log.has("landed")):
				if frames > 300:
					_check(false, "the ramp jump lands")
					_next(10)
				return false
			_check(_cnt("wall_hit") == 0 and chase.boat.s > LairCanal.RAMP_S, "the jump clears the broken pier wall")
			_check(float(mark["air"]) > 2.5, "a real jump (%.1f m)" % float(mark["air"]))
			_check(bool(mark.get("jump_cam", false)) and bool(mark.get("jump_side", false)), "the jump: slow motion (Impact clock) on the side camera")
			_next(90)
		90:
			if frames < int(BoatSetPieces.JUMP_CAM_HOLD * 60.0) + 3:
				return false
			_check(chase.set_pieces.cam_mode == "chase", "back on the chase camera after the landing")
			_tp(880.0, 0.0, 20.0)
			_next(10)
		10:
			if not chase.log.has("wall_hit"):
				if frames > 150:
					_check(false, "off the ramp line the pier wall stops the boat")
					_next(11)
				return false
			var b10: PlayerBoat = chase.boat
			_check(b10.s < LairCanal.RAMP_S - 2.0 and b10.v <= 2.0 and is_equal_approx(b10.hull, BoatData.HULL - BoatData.dmg_wall()), "the wall: stopped, the hull (%.1f, s %.1f)" % [b10.hull, b10.s])
			mark["hull"] = b10.hull
			_next(100)
		100:
			if frames < 90:
				return false
			var b100: PlayerBoat = chase.boat
			_check(b100.s < LairCanal.RAMP_S - 2.0 and is_equal_approx(b100.hull, float(mark["hull"])) and _cnt("wall_hit") == 1, "pressed against the wall: blocked, no more damage (%.1f)" % b100.hull)
			_tp(870.0, -9.0, 20.0)
			_next(11)
		11:
			if chase.boat.s < 912.0 and frames < 300:
				return false
			_check(_cnt("wall_hit") == 1, "the gap by the left bank passes the wall")
			_tp(884.0, LairCanal.RAMP_D, 10.0)
			inp["throttle"] = -1.0
			_next(12)
		12:
			if not (chase.log.has("flop") and _cnt("wall_hit") == 2):
				if frames > 300:
					_check(false, "too slow off the ramp: a flop into the wall (%s)" % str(chase.log.slice(-6)))
					_next(13)
				return false
			_tp(1205.0, LairCanal.BARGE_D, 20.0)
			_next(13)
		# ------------------------------------------------------------------ fireworks barge
		13:
			if not chase.log.has("barge_hit"):
				if chase.boat.s > 1245.0 or frames > 200:
					_check(false, "the fireworks barge bumps the boat")
					_next(14)
				return false
			_check(absf(chase.boat.d - LairCanal.BARGE_D) > BoatData.BARGE_HALF_D + BoatData.BEAM_HALF - 0.01, "pushed off the barge's side")
			_tp(LairCanal.BARGE_S - BoatData.BARGE_FROM + 5.0, -3.0, BoatData.V_CRUISE)
			inp["throttle"] = 0.0
			_next(130)
		# ------------------------------------------------------------------ fireworks: sky bursts, rogue rockets
		130:
			if not chase.log.has("rocket"):
				if frames > 150:
					_check(false, "a rogue rocket flies at the boat")
					_next(14)
				return false
			if frames < 3 or not chase.log.has("rocket"):
				return false
			var ring_on: bool = false
			for r: Dictionary in chase.set_pieces.rockets:
				ring_on = ring_on or (bool(r["live"]) and (r["ring"] as MeshInstance3D).visible)
			_check(ring_on and chase.set_pieces.live_rockets() == 1, "a red ring where it will land")
			_check(chase.log.has("sky") and chase.set_pieces.sky_count > 0, "the barge lights the sky")
			mark["hull"] = chase.boat.hull
			_next(131)
		131:
			if not (chase.log.has("rocket_hit") or chase.log.has("rocket_miss")):
				if frames > 120:
					_check(false, "the rocket lands")
					_next(14)
				return false
			_check(chase.log.has("rocket_hit") and is_equal_approx(chase.boat.hull, float(mark["hull"]) - BoatData.dmg_rocket()), "a boat going straight is hit (%.1f)" % chase.boat.hull)
			mark["rockets"] = _cnt("rocket")
			_next(132)
		132:
			if _cnt("rocket") == int(mark["rockets"]):
				if frames > 200:
					_check(false, "the next rocket")
					_next(14)
				return false
			inp["steer"] = 1.0                   # the swerve
			_next(133)
		133:
			if _cnt("rocket_hit") + _cnt("rocket_miss") < int(mark["rockets"]) + 1:
				if frames > 150:
					_check(false, "the second rocket lands")
					_next(14)
				return false
			_check(_cnt("rocket_miss") >= 1 and _cnt("rocket_hit") == 1, "a swerve dodges the ring")
			_tp(LairCanal.BRIDGES[0] - 85.0, 0.0, BoatData.V_CRUISE)
			inp["throttle"] = 0.0
			_next(134)
		134:
			if not chase.log.has("cut_bridge"):
				if frames > 120:
					_check(false, "a preview cut as the first bridge comes up")
					_next(14)
				return false
			var dir: CameraDirector = CameraDirector.live()
			_check(dir != null and chase.set_pieces.cut_count >= 1 and dir.cutting(), "the director cuts to the bridge (%d cuts)" % chase.set_pieces.cut_count)
			_tp(100.0, 0.0, 13.0, 24.0, true)
			inp["throttle"] = 0.0
			_next(14)
		# ------------------------------------------------------------------ jet skis
		14:
			if frames == 70:
				_check(chase.log.has("wave0") and chase.active_skis().size() == BoatData.wave_count(BoatData.WAVES[0]), "wave 0: %d jet skis" % chase.active_skis().size())
				var on_ok: bool = true
				for sk: JetSki in chase.skis:
					on_ok = on_ok and mn.markers.is_on(sk) == sk.is_threat()
				_check(on_ok, "a marker on every jet ski in the race")
				var behind_ok: bool = true
				for sk2: JetSki in chase.active_skis():
					behind_ok = behind_ok and sk2.s < chase.boat.s
				_check(behind_ok, "they come from behind the boat")
			if not chase.log.has("ski_tell"):
				if frames > 900:
					_check(false, "a jet ski telegraphs its ram")
					_next(15)
				return false
			var tells: int = 0
			var ring_ok: bool = false
			for sk3: JetSki in chase.skis:
				if sk3.mode == "tell":
					tells += 1
					ring_ok = sk3.ring.visible
			_check(tells == 1 and ring_ok, "one red-ring telegraph at a time")
			mark["hull"] = chase.boat.hull
			_next(15)
		15:
			if not chase.log.has("ski_hit"):
				if frames > 240:
					_check(false, "the telegraphed ram connects")
					_next(16)
				return false
			_check(is_equal_approx(chase.boat.hull, float(mark["hull"]) - BoatData.dmg_ram()), "the ram hurts (%.1f)" % chase.boat.hull)
			_next(16)
		16:
			if frames < 2:
				return false
			kicked = null
			for sk: JetSki in chase.skis:
				if sk.is_threat():
					kicked = sk
					break
			if kicked == null:
				_check(false, "a jet ski to kick")
				_next(18)
				return false
			kicked.side = 1
			kicked.place(chase.boat.s + 0.5, chase.boat.d + BoatData.SKI_TELL_D, chase.boat.v)
			kicked._set_mode("tell")                # telegraphing beside the boat: in kick reach
			chase._attacker = kicked
			for o: JetSki in chase.skis:
				if o != kicked and o.is_threat():
					o.retire()
			mark["ko"] = int(mn.stats.get("ko", 0))
			_key(KEY_E)
			_next(17)
		17:
			if frames == 1:
				_check(chase.log.has("kick"), "[E] kicks")
				_check(mn.hud_prompt.text == BoatData.T_KICK, "the kick prompt with a jet ski telegraphing alongside (%s)" % mn.hud_prompt.text)
			if not chase.log.has("ski_ko_kick"):
				if frames > 40:
					_check(false, "the kick knocks the jet ski on the right out (%s, lat %.2f)" % [kicked.mode, kicked.d - chase.boat.d])
					_next(18)
				return false
			if frames < 20:
				return false
			_check(kicked.mode == "ko" and int(mn.stats.get("ko", 0)) == int(mark["ko"]) + 1, "KO counted")
			_check(not mn.markers.is_on(kicked), "a KO'd jet ski loses its marker")
			_next(170)
		170:
			if frames < int(JetSki.KO_S * 60.0) + 5:
				return false
			_check(kicked.gone and not kicked.visible and kicked._splashed, "the rider splashed down, the ski gone")
			var sk4: JetSki = null
			for sk: JetSki in chase.skis:
				if sk.gone:
					sk4 = sk
					break
			chase.set_pieces.net_w[0] = 1.0
			chase.set_pieces._apply_net(0)
			sk4.revive(-1, 0)
			sk4.place(619.8, -5.0, 13.0)
			kicked = sk4
			_next(171)
		171:
			if frames < 3:
				return false
			_check(chase.log.has("ski_ko_net") and kicked.ko_cause == "net", "a jet ski in a net is out")
			_tp(1400.0, 0.0, 24.0, 10.0)
			mark["ram_prompt"] = false
			mark["ram_info"] = false
			mark["titanic"] = false
			hold = func() -> void:
				if chase == null or not is_instance_valid(chase):
					return
				if chase.rival.titanic_w > 0.9 and chase.rival.driver.position.distance_to(RivalBoat.BOW) < 0.05:
					mark["titanic"] = true
				inp["steer"] = clampf((chase.rival.d - chase.boat.d) * 0.9, -1.0, 1.0)
				var duck: bool = false
				for bs: float in LairCanal.BRIDGES:
					duck = duck or absf(chase.boat.s - bs) < 8.0
				inp["duck"] = duck
			_next(18)
		# ------------------------------------------------------------------ finale
		18:
			if mn.hud_prompt.text == BoatData.T_RAM:
				mark["ram_prompt"] = true
			if mn.hud_info.text.contains("Húc:"):
				mark["ram_info"] = true
			if not got_done:
				if frames > 2400:
					_check(false, "the finale rams win (%s, rams %d)" % [str(chase.log.slice(-8)), chase.rival.rams])
					hold = Callable()
					_next(19)
				return false
			hold = Callable()
			for k: String in ["finale", "ram1", "ram2", "ram3", "crash", "won"]:
				_check(chase.log.has(k), "finale log has %s" % k)
			_check(not chase.log.has("ram4"), "three rams on Thường")
			_check(chase.log.has("titanic") and bool(mark["titanic"]), "her Titanic pose on the bow at the finale")
			_check(chase.log.has("finish_orbit"), "the last ram: the finish orbit")
			_check(chase.rival.crashed and chase.rival.d > LairCanal.HALF_W - BoatData.BEAM_HALF - 1.0, "she ends on the right bank (d %.1f)" % chase.rival.d)
			_check(bool(mark["ram_prompt"]) and bool(mark["ram_info"]), "the ram prompt and the ram count")
			_check(done_info.has("hull") and done_info.has("kos"), "done %s" % str(done_info))
			var stand: Vector3 = sc.level.bank_xf() * LairCanal.BANK_STAND
			_check(chase.cam.current and not sc.player.visible and not sc.player.controls_enabled, "the win: the chase camera holds the finish through the results card")
			_check(StoryMission.flat(sc.player.global_position, stand) < 1.5, "the walking body parked on the finish bank's quay (%s)" % str(sc.player.global_position))
			sc._free_mission()
			_check(sc.player.visible and sc.player.controls_enabled and sc.player.camera.current, "the walking body back on the bank when the mission is freed")
			_next(19)
		# ------------------------------------------------------------------ fails, retry
		19:
			if frames < 3:
				return false
			mn = _start()
			_tp(865.0, LairCanal.HALF_W - BoatData.BEAM_HALF - 0.2, 13.0)
			chase.boat.hull = 1.0
			inp["throttle"] = 0.0
			inp["steer"] = 1.0
			_next(20)
		20:
			if fail_title == "":
				if frames > 60:
					_check(false, "the hull at 0 fails")
					_next(21)
				return false
			_check(fail_title == StoryMission.T_TOANG and fail_reason == BoatData.T_SINK, "TOANG! %s" % fail_reason)
			_check(chase.state == "lost" and mn.state == "failed" and chase.cp_i == 2, "lost after checkpoint 2")
			mn.retry()
			_check(chase.state == "running" and is_equal_approx(chase.boat.s, float(BoatData.CHECKPOINTS[2])) and is_equal_approx(chase.boat.hull, BoatData.HULL) and chase.log.has("retry2"), "THỬ LẠI at checkpoint 2 with a full hull")
			_check(chase.cam.current and not sc.player.visible, "back on the boat camera")
			fail_title = ""
			fail_reason = ""
			chase.rival.place(chase.boat.s + BoatData.LOSE_GAP + 10.0, 0.0, 20.0)
			inp["throttle"] = -1.0
			inp["steer"] = 0.0
			_next(21)
		21:
			if fail_title == "":
				if frames > 500:
					_check(false, "falling too far behind fails")
					_next(22)
				return false
			_check(fail_reason == BoatData.T_LOST and frames >= int(BoatData.LOSE_S * 60.0) - 3, "%s after %d frames" % [fail_reason, frames])
			mn.retry()
			sc._free_mission()
			_check(sc.player.visible and sc.player.controls_enabled and sc.player.camera.current, "leaving the chase restores the player")
			_next(22)
		22:
			if frames < 3:
				return false
			Difficulty.set_easy(true)
			_check(BoatData.rams_needed() == 2 and is_equal_approx(BoatData.v_max(), 24.0) and BoatData.dmg_bridge() < 30.0 and BoatData.ski_tell() > 1.0, "Dễ: 2 rams, gentler hits, a longer telegraph")
			Difficulty.set_easy(false)
			phase = 99
		99:
			return _end()
	return false


func _end() -> bool:
	hold = Callable()
	Difficulty.set_easy(false)
	StoryCanal.test_opts = {}
	StoryRankCard.skip_all = false
	if sc and is_instance_valid(sc):
		sc.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS: boat chase (handling, bridges, nets, ramp, wall, barge, rockets, jet skis, kicks, Titanic, finale rams, fails, retry)")
		quit(0)
	else:
		print("FAILED: %d check(s)" % fails.size())
		quit(1)
	return true
