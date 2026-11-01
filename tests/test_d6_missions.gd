# File: res://tests/test_d6_missions.gd
# W4 Day 6 T3 (plan 2026-11-01-w4-day6.md): the shop shift (MissionShop) and the back room (MissionBackroom) in the
# StoryCanal scene, no story running.
# Shop: the fixed shop camera sees the four cups (the player never hides one) and the front customer; a ticket has one
# matching cup and three decoys that differ in exactly one thing; right / wrong / too slow move the trust; 0 trust =
# "BỊ LỘ", THỬ LẠI = a new shift; the events (the "nhiều tâm tư" customer, the Bầy Sói biker's "như cũ", the rush, Thị
# Lọ's intercom code word, the VIP's two cups); full trust opens the back door and ends the shift; Dễ: the 9 s ticket.
# Back room: the guard's cone sees the player ("BỊ LỘ", retry = fresh room); the music box starts by proximity, the dolls
# turn to face the player, the guard is lured to the box; the bleat and the bulb beats; the safe ([E] held) -> the
# ledger -> the mirror figure -> the seg_d6_infiltrate replay -> done; "Giảm hù dọa" softens the box, the dolls, the
# bleat and the mirror.
# Run:  godot --headless --path . --script tests/test_d6_missions.gd
extends SceneTree

const DT: float = 1.0 / 60.0
const CANAL: String = "res://scenes/story/StoryCanal.tscn"
var TMP: String = "user://test_d6_missions_%d.cfg" % OS.get_process_id()
var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var total: int = 0
var sc: StoryCanal
var shop: MissionShop
var room: MissionBackroom
var fx: Node
var fail_title: String = ""
var done_info: Dictionary = {}
var got_done: bool = false
var hold: Callable = Callable()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("--- TEST D6 MISSIONS (shop, back room) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	fx = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
	StoryRankCard.skip_all = true
	StoryCanal.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 5}, "capture_mouse": false, "go_roam": false}


func _next(p: int) -> void:
	phase = p
	frames = 0


func _start(id: String) -> StoryMission:
	_check(sc.start_mission(StoryMissions.beat(id)), "%s starts in the canal scene" % id)
	var mn: StoryMission = sc.mission_node
	for c: Dictionary in mn.done.get_connections():
		mn.done.disconnect(c["callable"])     # no story running: the test reads the result itself
	for c2: Dictionary in mn.failed.get_connections():
		mn.failed.disconnect(c2["callable"])
	mn.failed.connect(func(t: String, _r: String) -> void: fail_title = t)
	mn.done.connect(func(info: Dictionary) -> void:
		got_done = true
		done_info = info)
	fail_title = ""
	got_done = false
	done_info = {}
	return mn


func _step_replay(mn: StoryMission) -> void:
	var n: int = 0
	while is_instance_valid(mn) and mn.replay != null and n < 1500:
		mn.replay.step(DT)
		n += 1


## Index of the cup matching the first wanted one (or the first decoy with wrong = true).
func _cup(wrong: bool = false) -> int:
	for i: int in shop.cups.size():
		if shop.cups[i] == null:
			continue
		var ok: bool = false
		for w: Dictionary in shop.order["left"]:
			ok = ok or MissionShop._same(w, shop.cups[i])
		if ok != wrong:
			return i
	return -1


func _diff_count(a: Dictionary, b: Dictionary) -> int:
	var n: int = 0
	for k: String in ["size", "tea", "topping"]:
		if a[k] != b[k]:
			n += 1
	return n


## Free the order flow until the next ticket is up (the front customer at the counter).
func _wait_order() -> bool:
	return not shop.order.is_empty()


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 9000:
		_check(false, "timeout in phase %d" % phase)
		phase = 99
	if hold.is_valid():
		hold.call()
	for v: Variant in [shop, room]:
		if is_instance_valid(v) and (v as StoryMission).state == "running":
			(v as StoryMission).advance(DT)
	match phase:
		0:
			sc = (load(CANAL) as PackedScene).instantiate()
			root.add_child(sc)
			_next(1)
		# ------------------------------------------------------------------ shop
		1:
			if frames < 3:
				return false
			shop = _start("d6_shop") as MissionShop
			_check(shop != null, "MissionShop for the shop task")
			_check(shop.cam.current and not sc.player.controls_enabled, "the fixed shop camera, the player at the counter")
			var vis: int = 0
			for c: Dictionary in shop.customers:
				vis += 1 if (c["body"] as Node3D).visible else 0
			_check(vis == MissionShop.QUEUE_N and not (shop.biker["body"] as Node3D).visible, "three sheep-masked customers queue, the biker waits outside")
			_check(is_equal_approx(shop.trust, MissionShop.TRUST_START) and is_equal_approx(shop.order_s, 5.5), "trust TRUST_START, a 5.5 s ticket on Thường")
			_check(not sc.level.is_back_door_open(), "the back door shut")
			_next(2)
		2:
			if not _wait_order():
				if frames > 200:
					_check(false, "a ticket comes up")
					phase = 99
				return false
			_check(shop.panel.visible and shop.ticket_label.text.begins_with("Ly "), "the ticket shows (%s)" % shop.ticket_label.text)
			var right: Array = []
			var decoy_ok: bool = true
			for c: Dictionary in shop.cups:
				if MissionShop._same(c, shop.order["want"][0]):
					right.append(c)
				else:
					decoy_ok = decoy_ok and _diff_count(c, shop.order["want"][0]) == 1
			_check(right.size() == 1 and decoy_ok and shop.cups.size() == 4, "one matching cup, three decoys one thing off")
			# readability: every cup and the front customer's head inside the shop camera, no cup hidden by the player
			var space: PhysicsDirectSpaceState3D = shop.cam.get_world_3d().direct_space_state
			var seen_all: bool = true
			for n: Node3D in shop.cup_nodes:
				var p: Vector3 = n.global_position + Vector3(0.0, 0.15 * n.scale.y * 0.5, 0.0)
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(shop.cam.global_position, p))
				seen_all = seen_all and shop.cam.is_position_in_frustum(p) and hit.is_empty()
			_check(seen_all, "the shop camera sees all four cups (none behind the player)")
			var front: Node3D = shop._front()["body"]
			_check(shop.cam.is_position_in_frustum(front.global_position + Vector3(0.0, 1.6, 0.0)), "the front customer's head in frame")
			shop.serve(_cup())
			_check(is_equal_approx(shop.trust, MissionShop.TRUST_START + shop.gain) and shop.served_ok == 1 and shop.combo == 1, "right cup: + gain (%.1f)" % shop.trust)
			_next(3)
		3:
			if not _wait_order():
				return false
			shop.serve(_cup(true))
			_check(is_equal_approx(shop.trust, maxf(0.0, MissionShop.TRUST_START + shop.gain - shop.wrong_cost)) and shop.combo == 0 and shop.served_wrong == 1, "wrong cup: - wrong_cost (%.1f)" % shop.trust)
			shop.trust = 20.0                 # room for the late ticket
			_next(4)
		4:
			if shop.timeouts == 0:
				if frames > 600:
					_check(false, "the ticket runs out")
					phase = 99
				return false   # let the ticket run out
			_check(frames >= int(shop.order_s * 60.0) and is_equal_approx(shop.trust, 20.0 - shop.late_cost), "too slow: - late_cost after order_s (%.1f)" % shop.trust)
			_next(6)
		6:
			if not _wait_order():
				return false
			shop.serve(_cup(true))
			_check(shop.state == "failed" and fail_title == StoryMission.T_LO and shop.trust <= 0.0, "trust 0: BỊ LỘ")
			shop.retry()
			_check(shop.state == "running" and is_equal_approx(shop.trust, MissionShop.TRUST_START) and shop.beats == ["open"] and shop.order.is_empty(), "THỬ LẠI: a new shift at TRUST_START")
			shop.clock = MissionShop.FIRST_EVENT_S - 0.01
			_next(7)
		7:
			if not _wait_order():
				return false
			_check(shop.beats.has("tam_tu") and shop.order["kind"] == "tam_tu" and shop.ticket_label.text.contains("nhiều tâm tư"), "15 s: the \"nhiều tâm tư\" customer")
			shop.serve(_cup(true) if _cup(true) >= 0 else 0)
			_check(shop.served_ok == 1 and shop.cues_played.has("ba_dum_tss"), "any cup does for him (the joke)")
			shop.next_event_at = shop.clock
			_next(8)
		8:
			if not _wait_order():
				return false
			_check(shop.beats.has("biker") and shop.order["kind"] == "biker" and shop.ticket_label.text == "NHƯ CŨ", "the Bầy Sói biker: \"NHƯ CŨ\"")
			_check((shop.biker["body"] as Node3D).visible and is_same(shop._front(), shop.biker) and shop.cues_played.has("engine_roar"), "the biker at the counter, his engine outside")
			var ui: int = -1
			for i: int in shop.cups.size():
				if MissionShop._same(shop.cups[i], MissionShop.USUAL):
					ui = i
			_check(ui >= 0, "the usual (L, trà truyền thống, trân châu) on the counter")
			shop.serve(ui)
			_check(shop.served_ok == 2, "the usual served")
			shop.next_event_at = shop.clock
			_next(9)
		9:
			if not _wait_order():
				return false
			_check(shop.beats.has("rush") and shop.order["kind"] == "normal" and float(shop.order["len"]) < shop.order_s, "GIỜ CAO ĐIỂM: shorter tickets")
			shop.serve(_cup())
			shop.next_event_at = shop.clock
			_next(10)
		10:
			if not _wait_order():
				return false
			if not shop.beats.has("intercom"):
				shop.serve(_cup())   # still in the rush
				shop.next_event_at = minf(shop.next_event_at, shop.clock)
				_next(10)
				return false
			_check(shop.codeword and shop.ticket_label.text.contains(MissionShop.CODE_DAU) and shop.order["want"][0]["tea"] == "dau", "the intercom: strawberry is \"Hồng phấn\" now")
			_check(shop.cues_played.has("radio"), "Thị Lọ on the speaker")
			var tags_real: bool = true
			for t: Label3D in shop.cup_tags:
				tags_real = tags_real and not t.text.contains(MissionShop.CODE_DAU)
			_check(tags_real, "the cup tags keep the real names")
			shop.serve(_cup())
			shop.next_event_at = shop.clock
			_next(11)
		11:
			if not _wait_order():
				return false
			if shop.order["kind"] != "vip":
				shop.serve(_cup())
				_next(11)
				return false
			_check((shop.order["want"] as Array).size() == 2 and shop.ticket_label.text.contains("2)"), "the VIP orders two drinks")
			var ok0: int = shop.served_ok
			shop.serve(_cup())
			_check(not shop.order.is_empty() and shop.served_ok == ok0, "one of two: the ticket stays")
			shop.serve(_cup())
			_check(shop.order.is_empty() and shop.served_ok == ok0 + 1, "both cups: the VIP is served")
			shop.trust = 97.0
			_next(12)
		12:
			if not _wait_order():
				return false
			shop.serve(_cup())
			_check(shop.won_t >= 0.0 and sc.level.is_back_door_open() and shop.beats.has("door"), "full trust: the back door opens")
			_next(13)
		13:
			if not got_done:
				if frames > 300:
					_check(false, "the shift ends after the door")
					phase = 99
				return false
			_check(int(done_info.get("orders", 0)) >= 6 and done_info.has("best_combo"), "done with the shift stats %s" % str(done_info))
			sc._free_mission()
			_check(sc.player.camera.current and sc.player.controls_enabled, "back to the player's camera and controls")
			Difficulty.set_easy(true)
			shop = _start("d6_shop") as MissionShop
			_check(is_equal_approx(shop.order_s, 9.0) and shop.late_cost < 10.0, "Dễ: a 9 s ticket, softer costs")
			shop.clock = MissionShop.FIRST_EVENT_S - 0.01
			shop.event_i = 1   # straight to the biker
			_next(14)
		14:
			if not _wait_order():
				return false
			_check(shop.order["kind"] == "biker" and shop.ticket_hint.text.contains("Trà truyền thống"), "Dễ: \"như cũ\" spelled out on the ticket")
			sc._free_mission()
			Difficulty.set_easy(false)
			sc.level.back_door_open(true)
			_next(20)
		# ------------------------------------------------------------- back room
		20:
			if frames < 3:
				return false
			room = _start("d6_backroom") as MissionBackroom
			_check(room != null and room.guard != null and room.cone != null, "MissionBackroom with the sheep-masked guard and his cone")
			_check(sc.player.controls_enabled and not room.music_on and sc.level.dolls_state() == "wall" and sc.level.ledger.visible, "on foot, the box silent, dolls to the wall, the ledger in the safe")
			# the guard's cone: pinned at a patrol corner facing along the room, the player 2.6 m in front
			room.patrol = []
			var rx: Transform3D = room.pts["room_xf"]
			var gp: Vector3 = rx * Vector3(1.6, 0.0, 1.9)
			var pp: Vector3 = rx * Vector3(-1.0, 0.0, 1.9)
			hold = func() -> void:
				room.guard.global_position = gp
				room.guard.rotation.y = MissionBackroom.yaw_of(pp - gp)
				sc.player.teleport(pp, 0.0)
			_next(21)
		21:
			if room.state == "running" and frames < 120:
				return false
			_check(room.state == "failed" and fail_title == StoryMission.T_LO and room.seen, "seen in his cone: BỊ LỘ")
			_check(frames >= 3, "not on the first frame (the grace)")
			hold = Callable()
			room.patrol = room.pts["patrol"]
			room.retry()
			_check(room.state == "running" and not room.seen and is_zero_approx(room.sus) and room.beats == ["enter"], "THỬ LẠI: a fresh room")
			# out of his cone: behind him
			room.patrol = []
			var rx2: Transform3D = room.pts["room_xf"]
			var gp2: Vector3 = rx2 * Vector3(1.6, 0.0, 1.9)
			var ahead: Vector3 = rx2 * Vector3(-1.0, 0.0, 1.9)
			var behind: Vector3 = rx2 * Vector3(3.6, 0.0, 1.0)
			hold = func() -> void:
				room.guard.global_position = gp2
				room.guard.rotation.y = MissionBackroom.yaw_of(ahead - gp2)
				sc.player.teleport(behind, 0.0)
			_next(22)
		22:
			if frames < 60:
				return false
			_check(room.state == "running" and room.sus < 0.05, "behind him: unseen")
			hold = Callable()
			# the music box by proximity
			var gp3: Vector3 = room.pts["room_xf"] * Vector3(-3.6, 0.0, 2.8)
			room.guard.global_position = gp3
			room.guard.rotation.y = 0.0
			sc.player.teleport(room.pts["music_box"] - room.pts["room_xf"].basis * Vector3(0.0, 0.85, -1.4), 0.0)
			_next(23)
		23:
			if frames < 3:
				return false
			_check(room.music_on and room.beats.has("music") and room.beats.has("lure") and room.guard_mode == "lure", "near the box: it plays, the guard goes to it")
			_check(sc.music_slot == "", "the stealth track stops")
			if frames < 3 + int(room.turn_s() * 60.0) + 10:
				return false
			_check(sc.level.dolls_state() == "facing" and is_equal_approx(room.turn_w, 1.0), "every doll turned to face the player")
			room.music_t = MissionBackroom.BLEAT_AFTER_S - 0.01
			_next(24)
		24:
			if frames < 3:
				return false
			_check(room.beats.has("bleat") and room.cues_played.has("sheep_bleat_distorted"), "the dolls bleat")
			room.music_t = MissionBackroom.BULB_AFTER_S - 0.01
			_next(25)
		25:
			if frames < 3:
				return false
			_check(room.beats.has("bulb") and room.bulb_t >= 0.0 and room.guard_mode == "bulb", "the bulb dies, the guard stops to tap it")
			_check(room._ceiling != null and room._ceiling.light_energy < room._ceiling_e * 0.7, "the room goes dark")
			_check(room._vanity_light != null and room.mirror_node != null, "the vanity bulb and the mirror figure found")
			# the safe: the guard pinned far off facing the shop wall
			room.patrol = []
			var rx3: Transform3D = room.pts["room_xf"]
			var gp4: Vector3 = rx3 * Vector3(-3.4, 0.0, 2.9)
			var face_at: Vector3 = rx3 * Vector3(-3.4, 0.0, 4.0)
			var at_safe: Vector3 = rx3 * Vector3(2.4, 0.0, -1.6)
			hold = func() -> void:
				room.guard.global_position = gp4
				room.guard.rotation.y = MissionBackroom.yaw_of(face_at - gp4)
				if not room.has_ledger:
					sc.player.teleport(at_safe, 0.0)
			room.hold_e = true
			_next(26)
		26:
			if not room.has_ledger:
				if frames > int(room.crack_s() * 60.0) + 30:
					_check(false, "the safe opens while [E] is held (crack %.2f)" % room.crack)
					phase = 99
				return false
			_check(frames >= int(room.crack_s() * 60.0) - 2, "the dial takes crack_s (%d frames)" % frames)
			_check(not sc.level.ledger.visible and room.beats.has("ledger") and room.cues_played.has("keyboard_clack"), "the ledger taken, the dial clicked")
			_next(27)
		27:
			if not room.beats.has("mirror"):
				return false
			_check(room.mirror_node.visible and room.cues_played.has("violin_screech"), "a figure in the vanity mirror (the screech)")
			_next(270)
		270:
			if room.replay == null and not got_done:
				if frames > 300:
					_check(false, "the replay after the mirror")
					phase = 99
				return false
			hold = Callable()
			_check(room.replay != null or got_done, "the seg_d6_infiltrate replay")
			_step_replay(room)
			_next(28)
		28:
			if not got_done:
				if frames > 120:
					_check(false, "done after the replay")
					phase = 99
				return false
			_check(done_info.has("crack_s") and bool(done_info.get("music", false)), "done %s" % str(done_info))
			sc._free_mission()
			# Giảm hù dọa
			if fx:
				fx.set("reduce_scares", true)
			room = _start("d6_backroom") as MissionBackroom
			room.patrol = []
			room.guard.global_position = room.pts["room_xf"] * Vector3(3.6, 0.0, 2.8)
			room.guard.rotation.y = 0.0   # facing the shop wall, far from the door
			room.start_music()
			_next(29)
		29:
			if frames < int(room.turn_s() * 60.0) + 20:
				return false
			_check(room.turn_w <= 0.61 and sc.level.dolls_state() == "turning", "Giảm hù dọa: the dolls turn only half way, slowly")
			_check(room.box_db() <= -12.0, "Giảm hù dọa: a softer music box")
			room.music_t = MissionBackroom.BLEAT_AFTER_S - 0.01
			_next(30)
		30:
			if frames < 3:
				return false
			_check(room.beats.has("bleat") and not room.cues_played.has("sheep_bleat_distorted") and room.cues_played.has("heartbeat"), "Giảm hù dọa: no bleat, a soft heartbeat")
			room.crack = 1.0
			room._take_ledger()
			_next(31)
		31:
			if not room.beats.has("mirror"):
				return false
			_check(not room.cues_played.has("violin_screech"), "Giảm hù dọa: no screech at the mirror")
			var mats: Array = room.mirror_node.get_meta("mats", [])
			_check(not mats.is_empty() and (mats[0] as StandardMaterial3D).albedo_color.a < 0.5, "Giảm hù dọa: a faint figure")
			sc._free_mission()
			phase = 99
		99:
			return _end()
	return false


func _end() -> bool:
	if fx:
		fx.set("reduce_scares", false)
	Difficulty.set_easy(false)
	StoryCanal.test_opts = {}
	StoryRankCard.skip_all = false
	if sc and is_instance_valid(sc):
		sc.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS: d6 missions (shop tickets, trust, events, door; back room cone, music box, dolls, safe, mirror, replay, Giảm hù dọa)")
		quit(0)
	else:
		print("FAILED: %d check(s)" % fails.size())
		quit(1)
	return true
