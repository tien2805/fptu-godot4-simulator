# File: res://tests/test_random_scares.gd
# Headless test of the random free-roam jump scares (RandomScares; owner request):
#   scheduler on a fake clock with a fixed seed (stub roam, dry run): nothing in the first 3.5 min, big scares at least
#     10 min apart (10-20 min gaps), small ones 3-5 min apart, about 1 in 3 build-ups fake, never the same kind twice in a
#     row, by day rarer than at night;
#   the calm-moment preference (a due scare starts at once when calm, waits up to 2 min otherwise);
#   the never-during rules (cinematic, mission, wanted with stars, busted, the map, the setting off, story Day 0) and the
#     "Giảm hù dọa" rule (no big scares, small ones stay);
#   in a real FreeRoam: each scare cleans up (the pillion sheep removed, the pedestrian restored, the phone face gone and
#     the phone normal, the glitch text gone, the staring figure gone, the radar blip gone);
#   the "Hù dọa ngẫu nhiên" setting (GameFX.random_scares, persisted in settings.cfg, the check in the settings box).
# Run:  godot --headless --path . --script tests/test_random_scares.gd
extends SceneTree

var fails: Array[String] = []
var frames: int = 0
var phase: int = 0


class FakePlayer extends Node3D:
	var horizontal_speed: float = 0.0


class FakeWanted extends Node:
	var state: String = "free"
	var stars: int = 0


class FakeStory extends Node:
	var mission_node: Node = null
	var busy: bool = false
	var running: String = ""
	var phone: Node = null


class FakeRoam extends Node3D:
	var player: FakePlayer = null
	var tod_preset: String = "night"
	var cine_player: Node = null
	var mounted: bool = false
	var bike: Node3D = null
	var wanted: Node = null
	var map_overlay: Control = null
	var story_roam: Node = null
	var pedestrians: Node = null
	var vice_hud: Node = null
	var md: Variant = null


class FakeDirector extends Node:
	var active: bool = false
	var day: int = 0
	signal step_changed(s: String)

	func days_left() -> int:
		return 8 - day


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST RANDOM SCARES ---")
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)
		fx.set("random_scares", true)
	RandomScares.last_any_msec = -100000000
	RandomScares.shared_gap_s = 0.0   # the fake clock: the shared gap with the night events is tested on its own below


func _stub(seed_val: int = 4) -> Array:
	var fr := FakeRoam.new()
	fr.player = FakePlayer.new()
	fr.add_child(fr.player)
	var w := FakeWanted.new()
	fr.wanted = w
	fr.add_child(w)
	var mo := Control.new()
	mo.visible = false
	fr.map_overlay = mo
	fr.add_child(mo)
	var dr := FakeDirector.new()
	fr.add_child(dr)
	root.add_child(fr)
	var rs := RandomScares.new()
	rs.auto_tick = false
	rs.dry_run = true
	rs.force_available = ["pillion", "head_turn", "phone", "edge_face", "subliminal", "crowd_stare", "hud_glitch", "radar_blip"]
	fr.add_child(rs)
	rs.setup(fr, dr, seed_val)
	return [fr, rs, dr]


func _run(rs: RandomScares, secs: float, dt: float = 0.5) -> void:
	var n: int = int(secs / dt)
	for i: int in n:
		rs.advance(dt)


static func _times(rs: RandomScares, prefix: String) -> Array[float]:
	var out: Array[float] = []
	for e: String in rs.log:
		if e.begins_with(prefix):
			out.append(float(e.get_slice("@", 1)))
	return out


static func _kinds(rs: RandomScares, prefix: String) -> Array[String]:
	var out: Array[String] = []
	for e: String in rs.log:
		if e.begins_with(prefix):
			out.append(e.get_slice("@", 0).substr(prefix.length()))
	return out


func _scheduler() -> void:
	var st: Array = _stub(4)
	var fr: FakeRoam = st[0]
	var rs: RandomScares = st[1]
	_run(rs, 200.0)
	_check(rs.log.is_empty(), "nothing in the first 3.5 minutes (%s)" % str(rs.log))
	_run(rs, 4.0 * 3600.0)
	var big: Array[float] = _times(rs, "big:")
	var small: Array[float] = _times(rs, "small:")
	var min_big: float = INF
	for i: int in range(1, big.size()):
		min_big = minf(min_big, big[i] - big[i - 1])
	var min_small: float = INF
	for j: int in range(1, small.size()):
		min_small = minf(min_small, small[j] - small[j - 1])
	print("  4 h at night: %d big, %d small, %d build-ups (%d fake); big gaps >= %.0f s, small gaps >= %.0f s" % [big.size(), small.size(), rs.build_count, rs.fake_count, min_big, min_small])
	_check(big.size() >= 10 and big.size() <= 26 and min_big >= RandomScares.BIG_GAP.x, "big scares 10-20 min apart (%d, min gap %.0f s)" % [big.size(), min_big])
	_check(min_small >= RandomScares.SMALL_GAP.x and small.size() >= 40, "small scares 3-5 min apart (%d, min gap %.0f s)" % [small.size(), min_small])
	var ratio: float = float(rs.fake_count) / float(maxi(1, rs.build_count))
	_check(ratio > 0.18 and ratio < 0.5, "about 1 in 3 build-ups is fake (%.2f)" % ratio)
	var bk: Array[String] = _kinds(rs, "big:")
	var sk: Array[String] = _kinds(rs, "small:")
	var rep: bool = false
	for k: int in range(1, bk.size()):
		rep = rep or bk[k] == bk[k - 1]
	for k2: int in range(1, sk.size()):
		rep = rep or sk[k2] == sk[k2 - 1]
	_check(not rep, "never the same kind twice in a row")
	# by day: rarer
	var std: Array = _stub(4)
	var rsd: RandomScares = std[1]
	(std[0] as FakeRoam).tod_preset = "noon"
	_run(rsd, 4.0 * 3600.0)
	var day_big: int = _times(rsd, "big:").size()
	_check(day_big < big.size(), "by day the big scares are rarer (%d vs %d at night)" % [day_big, big.size()])
	# calm preference: calm = starts at once; not calm = waits up to 2 min
	var sc: Array = _stub(9)
	var rsc: RandomScares = sc[1]
	var frc: FakeRoam = sc[0]
	frc.player.horizontal_speed = 5.0   # running: not calm
	rsc.big_next_t = rsc.clock + 1.0
	_run(rsc, 3.0)
	_run(rsc, 60.0)
	_check(rsc.build_count == 0 and rsc.state == "wait_calm", "a due scare waits for a calm moment")
	frc.player.horizontal_speed = 0.0   # stops: calm
	_run(rsc, 1.0)
	_check(rsc.build_count == 1, "it starts as soon as the player is calm")
	var sc2: Array = _stub(10)
	var rsc2: RandomScares = sc2[1]
	(sc2[0] as FakeRoam).player.horizontal_speed = 5.0
	rsc2.big_next_t = rsc2.clock + 1.0
	_run(rsc2, 2.0)
	var t0: float = rsc2.clock
	while rsc2.build_count == 0 and rsc2.clock < t0 + 200.0:
		rsc2.advance(0.5)
	_check(absf(rsc2.clock - t0 - RandomScares.CALM_WAIT_MAX) < 3.0, "never calm: it goes ahead after 2 minutes (%.0f s)" % (rsc2.clock - t0))
	var sc3: Array = _stub(11)
	var rsc3: RandomScares = sc3[1]
	(sc3[0] as FakeRoam).player.horizontal_speed = 5.0
	rsc3.calm_boost_t = 60.0   # just after a mission win
	rsc3.big_next_t = rsc3.clock + 1.0
	_run(rsc3, 3.0)
	_check(rsc3.build_count == 1, "just after a story step (a mission won) counts as calm")
	# never during
	for rule: String in ["cine", "mission", "stars", "busted", "map", "off", "day0"]:
		var sn: Array = _stub(12)
		var frn: FakeRoam = sn[0]
		var rsn: RandomScares = sn[1]
		var drn: FakeDirector = sn[2]
		var fx: Node = root.get_node_or_null("GameFX")
		match rule:
			"cine":
				frn.cine_player = Node.new()
				frn.add_child(frn.cine_player)
			"mission":
				var stor := FakeStory.new()
				stor.mission_node = Node.new()
				stor.add_child(stor.mission_node)
				frn.story_roam = stor
				frn.add_child(stor)
			"stars":
				(frn.wanted as FakeWanted).stars = 1
			"busted":
				(frn.wanted as FakeWanted).state = "service"
			"map":
				frn.map_overlay.visible = true
			"off":
				if fx:
					fx.set("random_scares", false)
			"day0":
				drn.active = true
				drn.day = 0
		_run(rsn, 3600.0)
		_check(rsn.log.is_empty(), "never with %s (%s)" % [rule, str(rsn.log.slice(0, 2))])
		if fx:
			fx.set("random_scares", true)
	var s1: Array = _stub(13)
	(s1[2] as FakeDirector).active = true
	(s1[2] as FakeDirector).day = 1
	_run(s1[1], 3600.0)
	_check(not (s1[1] as RandomScares).log.is_empty(), "story Day 1: the cult is watching")
	# "Giảm hù dọa"
	var sr: Array = _stub(14)
	var rsr: RandomScares = sr[1]
	rsr.scare.reduce_scares = true
	_run(rsr, 3600.0)
	_check(_times(rsr, "big:").is_empty() and rsr.build_count == 0 and not _times(rsr, "small:").is_empty(), "Giảm hù dọa: no big scares or build-ups, the small ones stay")
	for x: Node in root.get_children():
		if x is FakeRoam:
			x.queue_free()


# ---------------------------------------------------------------------------
var fr: Node3D
var rs: RandomScares


func _process(_d: float) -> bool:
	frames += 1
	match phase:
		0:
			if frames < 2:
				return false
			_scheduler()
			_settings()
			fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			fr.set("crowd_enabled", true)
			root.add_child(fr)
			phase = 1
			frames = 0
		1:
			if frames < 60:
				return false
			rs = fr.get("random_scares")
			_check(rs != null, "FreeRoam builds its RandomScares in free play")
			rs.auto_tick = false
			fr.call("set_time_of_day", "night")
			# the pillion sheep
			fr.call("mount_bike")
			rs.play("pillion")
			phase = 2
			frames = 0
		2:
			rs.advance(1.0 / 60.0)
			var bike: Node3D = fr.get("bike")
			if frames == 40:
				_check(rs.figure != null and rs.figure.visible and rs.figure.get_parent() == bike, "pillion: a sheep sits behind the rider")
			if frames == 140:
				_check(rs.active == "" and (rs.figure == null or rs.figure.get_parent() == null), "pillion: the sheep is gone afterwards")
				fr.call("dismount_bike")
				phase = 3
				frames = 0
		3:
			if frames < 20:
				return false
			# the head turn: a real crowd pedestrian
			var sp: Node = fr.get("pedestrians")
			var ped: Node3D = null
			var pl: Node3D = fr.get("player")
			if sp != null:
				for p: Node3D in sp.call("pedestrians"):
					if p.visible:
						ped = p
						break
			if ped != null:
				pl.global_position = ped.global_position + Vector3(0.0, 0.0, 6.0)
				var cam: Camera3D = root.get_viewport().get_camera_3d()
				cam.look_at(ped.global_position + Vector3(0.0, 1.5, 0.0))
			rs.set_meta("ped0", ped)
			phase = 4
			frames = 0
		4:
			var ped2: Node3D = rs.get_meta("ped0")
			if frames == 1:
				if ped2 == null:
					print("  (no visible pedestrian: head turn skipped)")
					phase = 5
					frames = 0
					return false
				rs.set_meta("xf0", ped2.global_transform)
				rs._ped = null
				rs.play("head_turn")
			else:
				rs.advance(1.0 / 60.0)
			if frames == 40 and rs.active == "head_turn":
				_check(rs._mask != null and rs._ped != null, "head turn: a pedestrian turns its head into a sheep face")
			if frames == 200:
				var p3: Node3D = rs.get_meta("ped0")
				_check(rs.active == "" and is_instance_valid(p3) and p3.visible and p3.find_child("TurnedHead", true, false) == null
					and p3.process_mode != Node.PROCESS_MODE_DISABLED, "head turn: the pedestrian is restored afterwards")
				phase = 5
				frames = 0
		5:
			# small ones: glitch, staring figure, radar blip, subliminal
			if frames == 1:
				rs.play("hud_glitch")
				_check(rs._glitch != null and rs._glitch.text == RandomScares.T_GLITCH_FREE, "glitch: \"TAO THẤY MÀY\" in free play")
			elif frames < 80:
				rs.advance(1.0 / 60.0)
			elif frames == 80:
				_check(rs._glitch == null and rs.active == "", "glitch: gone after about a second")
				rs.play("radar_blip")
				var b0: Array = rs.blips()
				_check(b0.size() == 1 and (b0[0]["color"] as Color).r > 0.9, "radar: a red blip rushes at the player")
			elif frames < 190:
				rs.advance(1.0 / 60.0)
			elif frames == 190:
				_check(rs.blips().is_empty() and rs.active == "", "radar: the blip is gone")
				rs.play("subliminal")
				_check(rs._img != null and rs._img.visible, "subliminal: the sheep face flashes")
			elif frames < 196:
				rs.advance(1.0 / 60.0)
			elif frames == 196:
				_check(rs._img == null and rs.active == "", "subliminal: 2 frames only")
				rs.play("crowd_stare")
				rs.set_meta("stare", rs.active == "crowd_stare")
			elif frames < 230:
				rs.advance(1.0 / 60.0)
			elif frames == 230:
				if bool(rs.get_meta("stare")):
					_check(rs.figure != null and rs.figure.visible, "crowd stare: a masked figure stares from the crowd")
					var pl2: Node3D = fr.get("player")
					pl2.global_position = rs.figure.global_position + Vector3(2.0, 0.0, 0.0)
			elif frames < 250:
				rs.advance(1.0 / 60.0)
			elif frames == 250:
				_check(rs.active == "" and (rs.figure == null or rs.figure.get_parent() == null), "crowd stare: gone when approached")
				rs.play("edge_face")
			elif frames < 400:
				rs.advance(1.0 / 60.0)
			elif frames == 400:
				_check(rs.active == "" and not rs.scare.scare_busy(), "edge face: over and cleaned up")
				fr.queue_free()
				phase = 6
				frames = 0
		6:
			if frames < 5:
				return false
			return _story_phone()
		_:
			return _story_phone()
	return false


## Story Day 1: the phone face, then the normal phone.
func _story_phone() -> bool:
	var sd: Node = root.get_node("StoryDirector")
	if phase == 6:
		sd.set("nav_enabled", false)
		sd.set("save_path", ("user://test_random_scares_%d.cfg" % OS.get_process_id()))
		sd.call("new_story", {"female": false, "name": "Tùng"})
		sd.call("advance_day", 1)
		sd.set("step", "d1_stakeout")   # a marker beat: nothing runs by itself (no cinematic in the way)
		sd.set("tod", "night")
		fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
		fr.set("crowd_enabled", false)
		root.add_child(fr)
		phase = 7
		frames = 0
		return false
	if phase == 7:
		if frames < 60:
			return false
		rs = fr.get("random_scares")
		rs.auto_tick = false
		var sr: StoryRoam = fr.get("story_roam")
		_check(rs != null and sr != null and sr.phone != null, "story mode: RandomScares and the phone")
		_check(not rs.blocked(), "story free roam at a marker: random scares allowed")
		rs.arm("phone")
		sr.phone.open()
		phase = 8
		frames = 0
		return false
	if phase == 8:
		rs.advance(1.0 / 60.0)
		var sr2: StoryRoam = fr.get("story_roam")
		if frames == 40:
			_check(rs.active == "phone" and rs._img != null and rs._img.visible, "phone: the screen fills with a sheep face")
		if frames == 90:
			_check(rs.active == "" and rs._img == null and sr2.phone.is_open(), "phone: then the normal phone")
			rs.play("hud_glitch")
			_check(rs._glitch.text == RandomScares.T_GLITCH_STORY % int(sd.call("days_left")), "glitch: \"MÀY CÒN N NGÀY\" in the story (%s)" % rs._glitch.text)
			rs._end_visual()
			fr.queue_free()
			sd.call("reset_state")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(("user://test_random_scares_%d.cfg" % OS.get_process_id())))
			phase = 9
			frames = 0
		return false
	if fails.is_empty():
		print("✅ SUCCESS: RANDOM SCARES (scheduler gaps and limits, calm moments, fake build-ups, no repeats, never-during rules, reduce, Day 0, cleanups, setting)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true


func _settings() -> void:
	var fx: Node = root.get_node("GameFX")
	_check(bool(fx.get("random_scares")), "random scares on by default")
	var box := VBoxContainer.new()
	root.add_child(box)
	fx.call("build_story_settings", box)
	var cb: CheckButton = box.find_child("RandomScaresCheck", true, false) as CheckButton
	_check(cb != null and cb.text == "Hù dọa ngẫu nhiên" and cb.button_pressed, "the \"Hù dọa ngẫu nhiên\" check in the settings")
	cb.button_pressed = false
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	_check(not bool(fx.get("random_scares")) and cfg.get_value("story", "random_scares", true) == false, "turning it off is saved in settings.cfg")
	cb.button_pressed = true
	cfg.load("user://settings.cfg")
	_check(bool(fx.get("random_scares")) and cfg.get_value("story", "random_scares", false) == true, "and back on")
	box.queue_free()
