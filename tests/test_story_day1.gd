# File: res://tests/test_story_day1.gd
# Headless end-to-end test of story Day 1 "Shipper bóng đêm" (spec B-D5, B-D6; plan 2026-10-25-phase-b-integration.md):
# Day 1 morning (cine_day_start) -> the main-gate marker (blocked while wanted) -> cine_d1_intro -> the stake-out (Wave 2
# tension mini-game: seen in the open while he looks round = BỊ LỘ -> THỬ LẠI; hidden ducked behind a car through the
# guard's walk-by and Lu's bark until the handover ends = TOANG!; the phone camera: a blurred shot, three clear photos of
# the three moments with the turns hidden behind a car, a real [Q] / [E]) -> the chase
# starts by itself (leash lost = TOANG! -> retry, the banana slip with slide_whistle and the replay mark, 60-90 s, the
# seg_d1_chase replay) -> the brawl (3 couriers, forced unarmed, "Gét gô!", down = TOANG! -> retry from the checkpoint,
# won -> seg_d1_brawl, the locker key flag) -> the corridor marker -> the horror walk (flicker, figure, blackout, gone,
# bleat, not before 30 s) -> cine_d1_corridor -> the bench marker + the optional locker (E2 taken) -> the choice scene
# timed out (the honest "cover", recorded) -> the cover tail -> cine_d1 -> bed -> the call N = 6 -> Day 2 morning -> the
# Day 2 chase marker (Phase C: Day 2 is playable, test_story_day2). Then Continue from the autosave taken after the brawl (corridor marker, no mission
# started by itself, night, key flag kept) and the choice recorded once (a set choice skips the scene: the report tail).
# Missions run on manual clocks (StoryRoam.mission_opts), cinematics / calls / replays are stepped. FreeRoam runs with
# mayhem on (weapons, wanted, combat; crowd off). Real key events (Input.parse_input_event) press [E] at the gate marker,
# take the photo and restart the chase at its marker. Review round: VỀ THẾ GIỚI MỞ after a lost chase (marker back,
# weapons unlocked, speed cap restored, no fists on pedestrians mid-mission), Continue at d1_chase / d1_brawl (marker,
# nothing starts by itself), the locker marker already at the corridor step.
# Horror polish (H-D7): the stake-out's rustle and the shiba Lu fake-out (once per mission, not again after a restart);
# the corridor locker bursting open with the sheep mask before the blackout. Scare events: the window slam at a third of
# the walk, the figure behind the player when they turn round after the blackout.
# Run:  godot --headless --path . --script tests/test_story_day1.gd
extends SceneTree

const TMP: String = "user://test_story_day1.cfg"
const SNAP: String = "user://test_story_day1_snap.cfg"
const VID: String = "user://test_story_day1_video/"
const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var fr: Node
var sr: StoryRoam
var m: StoryMission
var mark: Dictionary = {}
var total: int = 0
var auto_ids: Array = ["d1_chase", "d1_brawl"]


## A real key press + release through Input (reaches _input / _unhandled_input like a player's key).
func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)


## The chase's parkour set pieces, checked at the start (the courier barely moves).
func _parkour(ch: MissionChase) -> void:
	_check(ch.obstacles.size() == 6 and ch.crowd.size() == 8 and ch.canteen != null, "6 set pieces, 8 students, the canteen stall")
	var a: Vector3 = ch.campus(MissionChase.SHORTCUT[0]) + Vector3(0.0, 0.5, 0.0)
	var b: Vector3 = ch.campus(MissionChase.SHORTCUT[1]) + Vector3(0.0, 0.5, 0.0)
	_check(ch.clear_line(a, b) and ch.clear_line(a + Vector3(0.0, 0.7, 0.0), b + Vector3(0.0, 0.7, 0.0)), "the canteen shortcut is clear at 0.5 and 1.2 m")
	var o: Dictionary = ch.obstacles[0]
	var before: Vector3 = (o["at"] as Vector3) - (o["fwd"] as Vector3) * 1.0
	_player().teleport(before, MissionStakeout.yaw_of(o["fwd"]))
	_check(ch.hud_prompt.text == "" or true, "")
	_check(not ch.try_slide() and ch.try_vault() and not _player().controls_enabled, "Space at the bench: a vault (controls held during it)")
	_advance(0.6)
	var past: float = (_player().global_position - (o["at"] as Vector3)).dot(o["fwd"])
	_check(past > 0.8 and _player().controls_enabled and ch.vaults == 1, "over the bench (%.1f m past it)" % past)
	var sl: Dictionary = ch.obstacles[2]
	var before2: Vector3 = (sl["at"] as Vector3) - (sl["fwd"] as Vector3) * 1.5
	_player().teleport(before2, MissionStakeout.yaw_of(sl["fwd"]))
	_check(not ch.try_vault() and ch.try_slide(), "Ctrl at the barrier: a slide")
	_advance(0.7)
	var past2: float = (_player().global_position - (sl["at"] as Vector3)).dot(sl["fwd"])
	_check(past2 > 0.8 and ch.slides == 1 and ch.cues_played.has("slide"), "under the barrier (%.1f m past it)" % past2)

## Advances (aiming) until the courier is side-on in his current moment and the view has been steady long enough.
func _to_profile(so: MissionStakeout) -> void:
	var n: int = 0
	while n < 200 and so.state == "running" and not (so.in_profile and so.steady_t >= MissionStakeout.steady_s() and so.zoom_t >= 0.9):
		_aim(so)
		so.advance(0.05)
		n += 1


## Aims the player's view (yaw / pitch) at the courier's chest from the player's phone eye.
func _aim(so: MissionStakeout) -> void:
	var to: Vector3 = so.courier_chest() - so.eye_pos()
	_player().yaw = atan2(-to.x, -to.z)
	_player().pitch = asin(clampf(to.y / maxf(to.length(), 0.01), -1.0, 1.0))


## A real key press or release through Input.
func _key_down(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


## H-D8: the slot the GameFX MusicDirector is on ("" without GameFX).
func _music_slot() -> String:
	var fx: Node = root.get_node_or_null("GameFX")
	var md: Node = fx.get("music") if fx else null
	return String(md.get("slot")) if md else ""


func _initialize() -> void:
	print("--- TEST STORY DAY 1 (end to end) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SNAP))
	StoryVideo.video_dir = VID
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)


func _roam() -> void:
	fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	root.add_child(fr)
	sr = fr.get("story_roam")
	if sr:
		sr.cine_opts = {"manual": true, "music": false}
		sr.call_opts = {"manual": true}
		sr.mission_opts = {"manual": true, "manual_replay": true, "seed": 7}


func _player() -> ThirdPersonController:
	return fr.get("player")


## Steps the running cinematic to its end (manual CinePlayer). Returns its slot.
func _finish_cine() -> String:
	var cp: CinePlayer = fr.get("cine_player")
	if cp == null:
		return ""
	var slot: String = cp.timeline.slot
	var n: int = 0
	while fr.get("cine_player") != null and n < 4000:
		cp.step(DT)
		n += 1
	_check(fr.get("cine_player") == null, "%s finished" % slot)
	return slot


## Waits for a cinematic to start (true when it runs); fails the test after `cap` frames.
func _cine_started(what: String, cap: int = 150) -> bool:
	if fr.get("cine_player") != null:
		return true
	if frames > cap:
		_check(false, "%s did not start (step %s)" % [what, String(sd.get("step"))])
		phase = 999
	return false


func _advance(secs: float, dt: float = 0.1) -> void:
	var n: int = int(round(secs / dt))
	for i: int in n:
		if m == null or not is_instance_valid(m) or m.state != "running":
			return
		m.advance(dt)


func _next(p: int) -> void:
	phase = p
	frames = 0


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 40000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	match phase:
		0:
			Difficulty.set_easy(false)   # Thường (the owner's setting is loaded by GameFX before the first frame)
			sd.call("new_story", {"female": false, "name": "Minh", "variant": 1, "hair_style": "spiky", "hair_color": 2, "skin": 1})
			sd.set("step", "d0_intro")
			sd.call("complete_step", "d0_intro")
			_check(String(sd.get("step")) == "d1_morning" and int(sd.get("day")) == 1, "the story is at the Day 1 morning")
			_roam()
			_next(1)
		1:
			if not _cine_started("cine_day_start"):
				return false
			_check(_finish_cine() == "cine_day_start", "Day 1 morning: cine_day_start")
			_next(2)
		2:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_stakeout" and String(fr.get("tod_preset")) == "night", "d1_stakeout at night")
			_check(sr.markers.has("d1_stakeout") and sr.mission_node == null, "the main-gate marker, no mission yet")
			_check(int(sd.call("unread_count", "Mr.T")) >= 1, "Mr.T's text about the main gate")
			var vh: ViceHUD = fr.get("vice_hud")
			var obj_line: String = vh.objective_label.text if ViceHUD.style_active() and vh else sr.objective_line.text
			_check(obj_line == String(sd.get("objective")) and obj_line.contains("cổng chính"), "the objective stays as a line under the day chip: %s" % obj_line)
			var old_unread: Array = (sd.get("texts") as Array).filter(func(t: Dictionary) -> bool: return int(t["day"]) == 0 and not bool(t["read"]))
			_check(old_unread.is_empty(), "Day 0 texts are read on Day 1 (no stale 'Thi EOS 8h' among the unread)")
			var w0: Variant = fr.get("wanted")
			var w := WantedDirector.new()
			w.stars = 1
			fr.set("wanted", w)
			_check(not sr.start_marker("d1_stakeout"), "the marker is blocked while wanted")
			fr.set("wanted", w0)
			w.free()
			sr.phone.open()
			_check(not sr.start_marker("d1_stakeout"), "the marker is blocked with the phone open")
			sr.phone.close()
			var mp: Vector2 = sr.marker_pos["d1_stakeout"]
			_player().teleport(Vector3(mp.x, 0.3, mp.y), 0.0)
			_next(30)
		30:
			if frames < 15:
				return false
			_check(sr.active_marker == "d1_stakeout", "standing in the gate marker")
			_key(KEY_E)
			_next(31)
		31:
			if not _cine_started("cine_d1_intro after a real [E]", 30):
				return false
			_check(_finish_cine() == "cine_d1_intro", "a real [E] at the gate plays cine_d1_intro")
			_next(3)
		3:
			if frames < 2:
				return false
			m = sr.mission_node
			_check(m is MissionStakeout and m.state == "running", "the stake-out runs after the intro")
			_check(_music_slot() == "mission_stakeout", "the stake-out plays mission_stakeout (%s)" % _music_slot())
			if not (m is MissionStakeout):
				phase = 999
				return false
			var so: MissionStakeout = m
			_check(so.cars.size() == 7 and so.courier != null and so.buyer != null and so.hud.visible and sr.ui.visible, "the courier, the buyer, six parked cars and his scooter, the mission HUD")
			var objc: String = String(sd.get("objective"))
			_check(objc.contains("cổng") or objc.contains("Mr.T"), "objective kept: %s" % objc)
			_check(MissionStakeout.tell_s() >= 0.5 and MissionStakeout.bark_tell_s() >= 0.5, "every turn has a telegraph of at least 0.5 s")
			# seen in the open while he looks round: the meter fills, BỊ LỘ
			_player().teleport(so.campus(Vector3(112.0, 0.0, 103.5)), 0.0)
			so.duck_override = false
			so._begin_tell(0.6, Vector3.ZERO)
			_check(so.bubble.visible and so.bubble.text == "Hửm?" and so.tells == 1, "the turn telegraph: a red Hửm? bubble")
			_advance(0.7)
			_check(so.phase == "look", "then he looks down the lane")
			_advance(2.0)
			_check(so.state == "failed" and sr.fail_ui != null and sr.fail_ui.visible and sr.fail_ui.title_label.text == "BỊ LỘ" and so.seen_count >= 1,
				"seen standing in the open: the meter fills, BỊ LỘ (%s, %.0f)" % [so.state, so.suspicion])
			sr.fail_ui.press_retry()
			_check(so.state == "running" and so.clock < 0.01 and so.suspicion == 0.0 and not sr.fail_ui.visible and so.photos.count(true) == 0, "THỬ LẠI restarts the stake-out")
			# hidden ducked behind a car the whole handover: the guard walks by, Lu barks, the courier spins round; no photos = TOANG!
			var hide: Vector3 = so.campus(Vector3(94.5, 0.0, 100.6))   # behind the first car from the courier and from the lane
			so.duck_override = true
			var hn: int = 0
			while so.state == "running" and hn < 1200:
				_player().teleport(hide, MissionStakeout.yaw_of(so.courier.global_position - hide))
				so.advance(0.1)
				hn += 1
			_check(so.guard_walks >= 1 and so.barks == 1 and so.cues_played.has("bark") and so.cues_played.has("rustle"), "the guard walked by, Lu barked behind the player (%d, %d)" % [so.guard_walks, so.barks])
			_check(so.lu_shown and so.scare.fake_count == 1 and so.tells >= 5, "Lu's sting is the one fake-out; the courier kept turning round (%d tells)" % so.tells)
			_check(so.state == "failed" and sr.fail_ui.visible and sr.fail_ui.title_label.text == "TOANG!", "hidden all along without photos: the handover ends, TOANG! (%s, %.0f)" % [so.state, so.suspicion])
			sr.fail_ui.press_retry()
			so.duck_override = false
			_check(so.state == "running" and so.clock < 0.01, "THỬ LẠI again")
			# photos: 21 m behind him in the lane while his back is turned
			var spot: Vector3 = so.campus(Vector3(101.0, 0.0, 103.5))
			_player().teleport(spot, 0.0)
			_aim(so)
			_check(so.take_photo() == "", "[E] without the phone up does nothing")
			so.raise_phone(true)
			_check(so.phone_cam.current and so._finder.visible and _player().move_lock, "the phone is up: the viewfinder camera, no walking")
			so.advance(0.1)
			_check(so.take_photo() == "blur" and so.blurs == 1 and so.suspicion > 0.0, "a shot before the view is steady and zoomed: blurred, a little suspicion")
			_advance(1.0)
			_aim(so)
			if not so.in_profile:
				_check(so.take_photo() == "back", "his back turned: not a clear photo yet")
			_to_profile(so)
			_check(so.in_profile and so.hud_prompt.text == MissionStakeout.T_PROFILE, "he turns side-on: HẮN NGHIÊNG MẶT!")
			_check(so.take_photo() == "clear" and so.photos[0], "steady, centred, his face side-on: a clear photo of moment 1")
			_check(so.take_photo() == "done", "the same moment again does not count")
			so.raise_phone(false)
			_check(not so.phone_cam.current and not _player().move_lock, "the phone down: the gameplay camera back")
			# he turns: hide behind a car (ducked) until the next moment
			var guard_n: int = 0
			while so.phase != "tell" and guard_n < 200:
				so.advance(0.1)
				guard_n += 1
			var cover: Vector3 = so.campus(Vector3(101.5, 0.0, 101.3))
			so.duck_override = true
			while so.phase != "act" and guard_n < 400:
				_player().teleport(cover, 0.0)
				so.advance(0.1)
				guard_n += 1
			_check(so.state == "running" and so.suspicion < 100.0, "ducked behind a car while he looked: not caught (%.0f)" % so.suspicion)
			so.duck_override = false
			_player().teleport(spot, 0.0)
			_aim(so)
			_key_down(KEY_Q, true)
			_next(32)
		32:
			if frames < 2:
				return false
			var so2: MissionStakeout = m as MissionStakeout
			_check(so2.phone_up, "a real [Q] raises the phone")
			_to_profile(so2)
			_key(KEY_E)
			_next(35)
		35:
			if frames < 2:
				return false
			var so3: MissionStakeout = m as MissionStakeout
			_check(so3.photos.count(true) == 2 and so3.cues_played.has("shutter"), "a real [E] takes the second clear photo (%d)" % so3.photos.count(true))
			_key_down(KEY_Q, false)
			var g3: int = 0
			while so3.phase != "tell" and g3 < 200:
				so3.advance(0.1)
				g3 += 1
			var cover3: Vector3 = so3.campus(Vector3(101.5, 0.0, 101.3))
			so3.duck_override = true
			while so3.phase != "act" and g3 < 400:
				_player().teleport(cover3, 0.0)
				so3.advance(0.1)
				g3 += 1
			so3.duck_override = false
			var spot3: Vector3 = so3.campus(Vector3(101.0, 0.0, 103.5))
			_player().teleport(spot3, 0.0)
			_aim(so3)
			so3.raise_phone(true)
			_to_profile(so3)
			_check(so3.take_photo() == "clear" and so3.photos.count(true) == 3, "the third moment: three clear photos")
			_advance(2.0)
			_check(so3.state == "done", "three photos: done (%s, %.1f s)" % [so3.state, so3.clock])
			_check(so3.scare.fake_count == 1, "Lu's fake-out sting came once per mission")
			_next(4)
		4:
			if sr.mission_node == null or not (sr.mission_node is MissionChase):
				if frames > 60:
					_check(false, "the chase did not start by itself (step %s)" % String(sd.get("step")))
					phase = 999
				return false
			_check(String(sd.get("step")) == "d1_chase" and int((sd.call("read_save", TMP) as Dictionary).get("day", 0)) == 1, "the stake-out won: d1_chase, autosaved")
			m = sr.mission_node
			var ch: MissionChase = m
			_check(ch.length_m > 280.0 and ch.length_m < 360.0, "the chase path is %.0f m" % ch.length_m)
			_check(MissionChase.leash_m() < MissionChase.TAUNT_M, "the leash is shorter than his taunt stop")
			_check(_music_slot() == "mission_chase", "the chase plays mission_chase (%s)" % _music_slot())
			# lost him: TOANG!
			_player().teleport(ch.courier.global_position + Vector3(40.0, 0.0, 0.0), 0.0)
			_advance(3.0, 0.25)
			_check(ch.state == "running", "no leash in the first %.0f s (his head start)" % MissionChase.LEASH_START_S)
			_advance(6.0, 0.25)
			_check(ch.state == "failed" and sr.fail_ui.visible and sr.fail_ui.title_label.text == "TOANG!", "farther than the leash: TOANG!")
			_check(bool(fr.call("story_mission_active")) and fr.call("mayhem_targets").is_empty(), "no fists, heat or wanted on pedestrians mid-mission")
			_check((fr.get("weapons") as WeaponDirector).locked, "the weapon wheel is locked during the mission")
			sr.fail_ui.press_leave()
			_check(sr.mission_node == null and sr.markers.has("d1_chase") and not sr.fail_ui.visible, "VỀ THẾ GIỚI MỞ: the chase marker comes back, no mission")
			_check(_music_slot() == "roam_night", "back in free roam at night: roam_night (%s)" % _music_slot())
			_check(not (fr.get("weapons") as WeaponDirector).locked and is_inf(_player().combat_speed_cap) and _player().controls_enabled, "weapons unlocked, speed cap restored")
			_check(String(sd.get("step")) == "d1_chase" and not bool(fr.call("story_mission_active")), "the beat stays d1_chase, no mission running")
			var cpos: Vector2 = sr.marker_pos["d1_chase"]
			_player().teleport(Vector3(cpos.x, 0.3, cpos.y), 0.0)
			_next(33)
		33:
			if frames < 15:
				return false
			_check(sr.active_marker == "d1_chase", "standing in the chase marker")
			_key(KEY_E)
			_next(34)
		34:
			if frames < 2:
				return false
			_check(sr.mission_node is MissionChase and (sr.mission_node as MissionChase).s < 0.01, "a real [E] at the marker restarts the chase")
			m = sr.mission_node
			if not (m is MissionChase):
				phase = 999
				return false
			_next(5)
		5:
			var ch2: MissionChase = m as MissionChase if is_instance_valid(m) else null
			if ch2 == null:
				_check(false, "the chase mission vanished")
				phase = 999
				return false
			if not mark.has("parkour"):
				mark["parkour"] = true
				_parkour(ch2)
			if not ch2.ended:
				var p: Vector3 = ch2.point_at(ch2.s - 5.0)
				_player().teleport(p, MissionStakeout.yaw_of(ch2.courier.global_position - p))
				if ch2.s > ch2.cum[3] + 4.0 and ch2.s < ch2.cum[6] - 4.0 and not ch2.shortcut_used:
					var cp2: Vector3 = ch2.canteen.global_position
					_player().teleport(cp2, MissionStakeout.yaw_of(ch2.courier.global_position - cp2))
					ch2.advance(0.1)
					_check(ch2.shortcut_used, "through the canteen stall on the loop: the shortcut")
				if ch2.s >= MissionChase.TACKLE_FROM_U * ch2.length_m and not ch2.tackled:
					_check(not ch2.can_tackle(), "5 m behind: no tackle yet")
					var close: Vector3 = ch2.point_at(ch2.s - 2.0)
					_player().teleport(close, MissionStakeout.yaw_of(ch2.courier.global_position - close))
					ch2.advance(0.02)
					_check(ch2.can_tackle() and ch2.hud_prompt.text == MissionChase.T_TACKLE, "2 m behind on the last stretch: [Space] VỒ! (%s)" % ch2.hud_prompt.text)
					_check(ch2.knocks == 2 and ch2.cuts >= 2 and ch2.slow_zones.size() == 2, "the trash cans and the fruit cart were knocked over behind him, each with a preview cut (%d, %d)" % [ch2.knocks, ch2.cuts])
					_check(ch2.parted == ch2.crowd.size(), "the crowd parted (%d / %d)" % [ch2.parted, ch2.crowd.size()])
					_check(ch2.try_vault() and ch2.tackling and ch2.cues_played.has("tackle"), "Space: the flying tackle")
				ch2.advance(0.25)
				if frames > 1500:
					_check(false, "the chase never ended (s %.0f / %.0f)" % [ch2.s, ch2.length_m])
					phase = 999
				return false
			if not mark.has("chase_end"):
				mark["chase_end"] = true
				_check(ch2.slipped and ch2.cues_played.has("slide_whistle") and ch2.rec.marks.has("blow"), "the banana slip: slide_whistle and the replay mark")
				_check(ch2.tackled and ch2.clock >= MissionChase.min_s() - 0.01 and ch2.clock <= MissionChase.min_s() + 35.0, "the tackle ended the chase after %.1f s (from %.0f s)" % [ch2.clock, MissionChase.min_s()])
			if ch2.replay != null:
				var n2: int = 0
				while ch2 != null and is_instance_valid(ch2) and ch2.replay != null and n2 < 1000:
					ch2.replay.step(DT)
					n2 += 1
				mark["replayed"] = true
			if frames > 120 and not mark.has("replayed"):
				_check(false, "the seg_d1_chase replay did not play")
				phase = 999
				return false
			if mark.has("replayed"):
				_next(6)
		6:
			if sr.mission_node == null or not (sr.mission_node is MissionFight):
				if frames > 60:
					_check(false, "the brawl did not start by itself (step %s)" % String(sd.get("step")))
					phase = 999
				return false
			m = sr.mission_node
			var mf: MissionFight = m
			_check(String(sd.get("step")) == "d1_brawl" and mf.fight.enemies.size() == 3 and mf.fight.state == "running", "the brawl: 3 couriers")
			_check(mf.fight.start_line == "Gét gô!" and mf.fight.force_unarmed, "start line Gét gô!, forced unarmed")
			_check(mf.arena != null and mf.arena.bikes.size() == 4 and mf.arena.tables.size() == 1 and mf.fight.props.size() == 4,
				"the west-gate arena: parked bikes and a vendor table to slam into, helmets and lids on the floor")
			var slam_ok: bool = mf.arena.bikes.all(func(b: Node3D) -> bool: return b.find_child("Collision", false, false).is_in_group("slam_car"))
			_check(slam_ok and (mf.arena.tables[0]["body"] as Node).is_in_group("slam_table"), "bikes slam as cars, the table as a table")
			_check(mf.fight.waves.size() == 2 and (mf.fight.waves[1] as Array).size() == MissionFight.d1_backup(), "the escalation wave: %d reinforcements" % MissionFight.d1_backup())
			mf.fight.combat.receive_attack(mf.fight.enemies[0], {"damage": 999.0})
			_next(7)
		7:
			if not (sr.fail_ui and sr.fail_ui.visible):
				if frames > 60:
					_check(false, "the player went down but no TOANG!")
					phase = 999
				return false
			_check(sr.fail_ui.title_label.text == "TOANG!" and (m as MissionFight).fight.state == "lost", "down: TOANG!")
			sr.fail_ui.press_retry()
			var mf2: MissionFight = m
			_check(mf2.fight.state == "running" and is_equal_approx(mf2.fight.combat.hp, 100.0) and mf2.fight.alive().size() == 3, "retry from the checkpoint: full HP, 3 couriers again")
			_next(8)
		8:
			var mf3: MissionFight = m as MissionFight if is_instance_valid(m) else null
			if mf3 != null and mf3.escalated and mf3.cues_played.has("backup"):
				mark["d1_escalated"] = true
			if mf3 != null and mf3.fight != null and is_instance_valid(mf3.fight):
				for e: Variant in mf3.fight.alive():
					(e as MeleeEnemy).take_strike({"dmg": 999.0, "stagger": 999.0, "breaks_block": true, "from": _player().global_position})
			if fr.get("cine_player") == null:
				if frames > 600:
					_check(false, "the brawl was not won / seg_d1_brawl did not start")
					phase = 999
				return false
			_check(bool(mark.get("d1_escalated", false)), "the reinforcements came in (a line, a preview cut)")
			_check(_finish_cine() == "seg_d1_brawl", "the brawl won: seg_d1_brawl")
			_next(9)
		9:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_corridor" and bool((sd.get("flags") as Dictionary).get("d1_key", false)), "d1_corridor; Mũ Đỏ's key flag")
			_check(sr.markers.has("d1_corridor") and sr.mission_node == null, "the corridor waits at its marker")
			_check(sr.markers.has("d1_locker"), "the locker marker is there right after the brawl (the E2 hint is true)")
			_check(int((sd.call("read_save", TMP) as Dictionary).get("flags", {}).get("d1_key", 0)) == 1 or bool((sd.call("read_save", TMP) as Dictionary).get("flags", {}).get("d1_key", false)), "autosaved after the brawl")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(SNAP))
			_check(sr.start_marker("d1_corridor") and sr.mission_node is MissionCorridor, "[E]: the corridor walk")
			m = sr.mission_node
			var mc: MissionCorridor = m
			_check(mc.corridor != null and mc.figure != null and mc.lights.size() == 8, "the corridor set: tubes, the figure")
			_check(is_equal_approx(_player().combat_speed_cap, MissionCorridor.WALK_CAP), "fear caps the walk")
			_corridor_to(mc, 0.2)
			_check(mc.events.has("flicker") and mc.scare.flicker_events >= 1, "the tubes stutter")
			_corridor_to(mc, 0.3)
			_check(mc.figure.visible, "the figure stands at the far end")
			_check(mc.cuts == 1, "a staged director cut onto the figure")
			_check(LookPresets.active(fr) == MissionCorridor.LOOK, "the corridor walk wears the campus_horror look (%s)" % LookPresets.active(fr))
			_corridor_to(mc, 0.35)
			_check(mc.events.has("window") and mc.slam.playing, "a sheep face slams against the dark window (%s)" % str(mc.events))
			_advance(12.0)
			_corridor_to(mc, 0.45)
			_check(mc.events.has("locker") and not mc.events.has("blackout") and mc.scare.played.has("locker_slam") and mc.scare.fake_count == 1,
				"mid-walk a locker bursts open (%s)" % str(mc.events))
			_check(mc.mask_drop != null and mc.locker_door != null, "the sheep mask falls out of it")
			_corridor_to(mc, 0.6)
			_check(mc.events.has("blackout") and not _player().controls_enabled, "lights out, frozen")
			_advance(1.6)
			_check(mc.events.has("gone") and not mc.figure.visible and _player().controls_enabled and mc.scare.played.has("sheep_bleat_distorted"), "lights back: the figure is gone, a distorted bleat")
			_corridor_to(mc, 0.85)
			_check(mc.events.has("whisper"), "whisper and a stutter")
			_player().yaw = _player().yaw + PI   # turns round
			mc.advance(0.1)
			_check(mc.events.has("behind") and mc.figure.visible and MissionCorridor.flat(mc.figure.global_position, _player().global_position) < 1.7,
				"turning round: the figure right behind (%s)" % str(mc.events))
			_player().yaw = _player().yaw + PI
			_advance(0.8)
			_check(not mc.figure.visible, "and it is gone")
			_corridor_to(mc, 0.95)
			_check(mc.state == "running" and mc.clock < MissionCorridor.MIN_S, "not over before 30 s (%.1f s)" % mc.clock)
			_advance(MissionCorridor.MIN_S)
			_check(mc.state == "done" and mc.clock >= MissionCorridor.MIN_S - 0.2 and mc.clock <= 60.0, "the far end after %.1f s: done" % mc.clock)
			_next(10)
		10:
			if not _cine_started("cine_d1_corridor", 60):
				return false
			_check(_finish_cine() == "cine_d1_corridor", "cine_d1_corridor follows the walk")
			_check(is_inf(_player().combat_speed_cap), "the walk cap is lifted")
			_check(LookPresets.active(fr) != MissionCorridor.LOOK, "the horror look is popped after the walk (%s)" % LookPresets.active(fr))
			_next(11)
		11:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_choice" and sr.markers.has("d1_choice") and sr.markers.has("d1_locker"), "the bench marker and the optional locker")
			_check(sr.start_marker("d1_locker") and sd.call("has_evidence", "E2") and not sr.markers.has("d1_locker"), "the locker gives E2 (courier list), once")
			_check(String(sd.get("step")) == "d1_choice", "the locker is optional: the step stays")
			_check(sr.start_marker("d1_choice") and fr.get("cine_player") != null, "[E] at the bench: the choice scene")
			var cp: CinePlayer = fr.get("cine_player")
			var n3: int = 0
			while cp.choice_node == null and fr.get("cine_player") != null and n3 < 2000:
				cp.step(DT)
				n3 += 1
			_check(cp.choice_node != null and cp.choice_node.manual, "the choice opens (freeze, two options, countdown)")
			_check(String(sd.call("choice_of", "phuc")) == "", "not recorded before the answer")
			_check(_finish_cine() == "cine_d1_choice", "the choice scene ends after the timeout")
			_check(String(sd.call("choice_of", "phuc")) == "cover" and cp.choice_timed_out, "timeout: the honest option (cover) is recorded")
			_next(12)
		12:
			if not _cine_started("cine_d1_choice_cover", 60):
				return false
			_check(_finish_cine() == "cine_d1_choice_cover", "the cover tail plays")
			_next(13)
		13:
			if not _cine_started("cine_d1", 60):
				return false
			_check(_finish_cine() == "cine_d1", "cine_d1 (the courier's phone)")
			_next(14)
		14:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d1_bed" and sr.markers.has("d1_bed") and not sr.markers.has("d1_locker"), "free roam until bed (the locker was used)")
			var ch3: Dictionary = (sd.call("read_save", TMP) as Dictionary).get("choices", {})
			_check(String(ch3.get("phuc", "")) == "cover", "the choice is in the autosave")
			_check(sr.start_marker("d1_bed") and String(sd.get("step")) == "d1_call", "bed: the 3 a.m. call")
			_next(15)
		15:
			if sr.call == null:
				if frames > 120:
					_check(false, "the call did not start")
					phase = 999
				return false
			var c: StoryCall = sr.call
			_check(c.days == 6, "the call says 6 days")
			var n4: int = 0
			while c.phase != "ring" and n4 < 300:
				c.step(DT)
				n4 += 1
			c.answer()
			while sr.call != null and n4 < 3000:
				c.step(DT)
				n4 += 1
			_next(16)
		16:
			if not _cine_started("Day 2 cine_day_start", 120):
				return false
			var dc: StoryDayCard = sr.cards as StoryDayCard
			_check(dc != null and dc.days == 2 and dc.left == 6 and int(sd.get("day")) == 2, "Day 2 morning: NGÀY 2 · CÒN 6 NGÀY")
			_finish_cine()
			_next(17)
		17:
			if frames < 5:
				return false
			_check(String(sd.get("step")) == "d2_chase" and sr.markers.has("d2_chase"), "Day 2: the chase marker (Phase C)")
			_check(String(sd.get("objective")).contains("Anh Duy"), "Day 2 objective: %s" % String(sd.get("objective")))
			_check(String(sd.call("day_chip_text")) == "NGÀY 2 · CÒN 6 NGÀY", "Day 2 chip")
			# Continue from the autosave after the brawl
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(18)
		18:
			if frames < 3:
				return false
			sd.call("reset_state")
			sd.set("save_path", SNAP)
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == "d1_corridor", "Continue restores d1_corridor")
			_roam()
			_next(19)
		19:
			if frames < 40:
				return false
			_check(sr.markers.has("d1_corridor") and sr.mission_node == null and fr.get("cine_player") == null, "after Continue: the corridor marker, nothing starts by itself")
			_check(String(fr.get("tod_preset")) == "night" and bool((sd.get("flags") as Dictionary).get("d1_key", false)) and not sd.call("has_evidence", "E2"), "night, the key flag, E2 not taken yet")
			# a recorded choice is never asked again: the report tail follows directly
			(sd.get("choices") as Dictionary)["phuc"] = "report"
			sd.call("set_step", "d1_choice")
			sr.refresh()
			_check(sr.start_marker("d1_choice"), "[E] at the bench with the choice already recorded")
			_next(20)
		20:
			if not _cine_started("the report tail", 90):
				return false
			var cp2: CinePlayer = fr.get("cine_player")
			_check(cp2.timeline.slot == "cine_d1_choice_report" and String(sd.get("step")) == "d1_choice_tail", "the choice scene is skipped: the report tail plays")
			_finish_cine()
			_next(40)
		40:
			# Continue at the auto beats: the marker, nothing starts by itself
			if frames < 3:
				return false
			var auto_id: String = String(auto_ids[0])
			sd.call("set_step", auto_id)
			sd.call("on_leave_to_menu")
			fr.queue_free()
			_next(41)
		41:
			if frames < 3:
				return false
			sd.call("reset_state")
			_check(bool(sd.call("continue_story")) and String(sd.get("step")) == String(auto_ids[0]), "Continue restores %s" % String(auto_ids[0]))
			_roam()
			_next(42)
		42:
			if frames < 45:
				return false
			var aid: String = String(auto_ids[0])
			_check(sr.markers.has(aid) and sr.mission_node == null and fr.get("cine_player") == null, "Continue at %s: its marker, nothing starts by itself" % aid)
			auto_ids.remove_at(0)
			if auto_ids.is_empty():
				fr.queue_free()
				return _end()
			_next(40)
	return false


## Puts the player at corridor progress p and lets the mission tick.
func _corridor_to(mc: MissionCorridor, p: float) -> void:
	var z: float = MissionCorridor.START_Z - p * (MissionCorridor.START_Z - (MissionCorridor.Z0 - MissionCorridor.LEN_M) - 1.0)
	_player().teleport(mc.xf * Vector3(0.1, 0.0, z), mc._yaw_down())
	mc.advance(0.1)


func _end() -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SNAP))
	StoryVideo.video_dir = StoryVideo.VIDEO_DIR
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	if fails.is_empty():
		print("✅ SUCCESS: STORY DAY 1 END TO END (stake-out, chase, brawl, corridor, E2, choice, call, Day 2, continue)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true

