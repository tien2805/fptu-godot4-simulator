# File: res://tests/test_d7_previews.gd
# Headless test of the Day 7 floors' preview cuts and villain-return beats (plan 2026-11-03-w5-day7.md T1), in the real
# tower (StoryTower from d7_parking, each floor finished in turn):
#   - every cut runs through the camera director (cut_kind "preview") and frames its target on every frame it runs:
#     CameraFraming.report on the director camera (head, chest and hips of a character, or the beam marker's points, inside
#     the 8 % safe area, the line of sight clear of static geometry, the camera not in geometry);
#   - the parking deck: a cut as each wave rolls in (the first wolf, Sói Bự, Sói Xám); Sói Xám's is his return beat: the card
#     follows the cut over a frozen camera that still frames him, then the bike's chase camera is back;
#   - the warehouse (Alexander in his seat) and the server floor (Za Mẫn staged, the duel only after the card): cut, then the
#     card over the frozen frame; THỬ LẠI plays neither again;
#   - the showroom: the first guard at the start, the second at the first gap, the third past the middle wall (guards blind
#     for the test); none once seen;
#   - the laser corridor: the first blink wall at the start, the sweep and the diagonal once past that wall.
# Run:  godot --headless --path . --script tests/test_d7_previews.gd
extends SceneTree

var TMP: String = "user://test_d7_previews_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_d7_previews_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_d7_previews_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_d7_previews_backup_%d.cfg" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const TOWER: String = "res://scenes/story/StoryTower.tscn"
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var tw: StoryTower = null
var m: StoryMission
var mark: Dictionary = {}
## The cut being watched: {"target", "n" (frames), "ok" (framed frames), "bad" (first failure)}.
var watch: Dictionary = {}
var cuts_seen: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("--- TEST D7 PREVIEWS (floor preview cuts, villain-return beats, framing) ---")
	Engine.max_fps = 60
	sd = root.get_node("StoryDirector")
	sm = root.get_node("StageManager")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = TMP_U
	StoryChapters.chapters_path = TMP_C
	StoryChapters.backup_path = TMP_B
	StoryTower.test_opts = {"missions": {"manual": true, "manual_replay": true, "manual_card": true, "seed": 3},
		"cine": {"manual": true, "music": false}, "capture_mouse": false}
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)


func _next(p: int) -> void:
	phase = p
	frames = 0


func _wait_mission(cls: String, cap: int = 240) -> StoryMission:
	var mn: StoryMission = tw.mission_node if tw else null
	if mn != null and is_instance_valid(mn) and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start in the tower (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


## Framing of the running preview cut, every frame (label: what the cut must show).
func _watch_cut(label: String) -> void:
	var cd: CameraDirector = CameraDirector.live()
	var on: bool = cd != null and cd.cut_kind == "preview" and cd.cam != null and cd.cam.current
	if on:
		var t: Node3D = cd.get("_cut_target")
		if watch.is_empty() or watch["target"] != t:
			_close_watch()
			watch = {"target": t, "label": label, "n": 0, "ok": 0, "bad": ""}
		if t != null and is_instance_valid(t):
			var excl: Array[RID] = []
			if t is CollisionObject3D:
				excl.append((t as CollisionObject3D).get_rid())
			var pts: PackedVector3Array = CameraFraming.subject_points(t)
			var rep: Dictionary = CameraFraming.report(cd.cam, pts, cd.cam.get_world_3d().direct_space_state, excl)
			watch["n"] = int(watch["n"]) + 1
			if bool(rep["ok"]):
				watch["ok"] = int(watch["ok"]) + 1
			elif String(watch["bad"]) == "":
				watch["bad"] = "frame %d: %s" % [int(watch["n"]), CameraFraming.describe(cd.cam, pts, rep)]
	elif not watch.is_empty():
		_close_watch()


func _close_watch() -> void:
	if watch.is_empty():
		return
	var lab: String = String(watch["label"])
	_check(int(watch["n"]) >= 3 and int(watch["ok"]) == int(watch["n"]),
		"%s: the preview cut frames its target on every frame (%d / %d) %s" % [lab, int(watch["ok"]), int(watch["n"]), String(watch["bad"])])
	cuts_seen.append(lab)
	watch = {}


## The card follows the cut: the frozen camera still frames the villain; stepped through, the camera of before is back.
func _card_beat(mn: StoryMission, villain: Node3D, before: Camera3D, label: String) -> bool:
	var card: StoryVillainCard = mn.get("card")
	if card == null:
		return false
	_close_watch()
	var bf: D7Beat = mn.get("beat_fx")
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	_check(paused, "%s: the card pauses the tree" % label)
	_check(bf != null and bf.cuts >= 1 and bf.freeze_cam != null and cam == bf.freeze_cam, "%s: the card shows over the frozen cut (camera %s)" % [label, cam.name if cam else "none"])
	if cam != null and villain != null and is_instance_valid(villain):
		var pts: PackedVector3Array = CameraFraming.subject_points(villain)
		var rep: Dictionary = CameraFraming.report(cam, pts, null)
		_check(int(rep["inside"]) == int(rep["total"]), "%s: the frozen frame still shows the villain %s" % [label, CameraFraming.describe(cam, pts, rep)])
	var n: int = 0
	while mn.get("card") != null and n < 600:
		(mn.get("card") as StoryVillainCard).step(DT)
		n += 1
	_check(not paused and root.get_viewport().get_camera_3d() == before, "%s: after the card the gameplay camera is back (%s)" % [label, str(root.get_viewport().get_camera_3d())])
	return true


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 30000:
		_check(false, "timeout in phase %d" % phase)
		phase = 999
	if phase == 999:
		return _end()
	if tw and is_instance_valid(tw) and tw.mission_node and is_instance_valid(tw.mission_node) and tw.mission_node.state == "running" \
			and tw.mission_node.replay == null and not paused:
		tw.mission_node.advance(DT)
	match phase:
		0:
			if frames < 3:
				return false
			sd.call("new_story", {"female": true, "name": "Lan", "variant": 0, "hair_style": "short", "hair_color": 2, "skin": 2})
			sd.set("day", 7)
			sd.call("_enter", "d7_parking")
			tw = (load(TOWER) as PackedScene).instantiate()
			root.add_child(tw)
			_next(1)
		# ----- the parking deck -----
		1:
			m = _wait_mission("MissionTowerParking")
			if m == null:
				return false
			var mp: MissionTowerParking = m
			var ch: BikeChase = mp.chase
			if ch == null or ch.state != "running":
				return false
			if frames == 1 or not mark.has("ccam"):
				mark["ccam"] = tw.bike.chase_cam
			_watch_cut("parking wave %d" % ch.wave)
			ch.combat.god = true
			# a wave's riders crash once its cut is over: the next wave rolls in
			if not paused and not (CameraDirector.live() and CameraDirector.live().cutting()) and mp.card == null 					and mp.beat_fx.cuts > ch.wave and not mp.beat_fx.busy() and mp.wave_cut < 0:
				for b: Variant in ch.alive():
					(b as BikerEnemy).crash("test")
			if mp.card != null:
				var sx: BikerEnemy = mp.wave_lead(2)
				_check(ch.wave == 2 and sx != null and sx.label == "Sói Xám", "parking: the card comes with Sói Xám's wave")
				_card_beat(mp, sx, mark["ccam"], "parking: Sói Xám")
				_check(mp.beat_fx.cuts == 3 and mp.beat_fx.cards == 1, "parking: a cut per wave (%d), one card" % mp.beat_fx.cuts)
				_check(cuts_seen.size() >= 3, "parking: three cuts framed (%s)" % str(cuts_seen))
				ch.combat.god = false
				mp.finish({})
				_next(2)
			elif frames > 2400:
				_check(false, "parking: no Sói Xám card (wave %d, cuts %d)" % [ch.wave, mp.beat_fx.cuts])
				mp.finish({})
				_next(2)
		# ----- the warehouse -----
		2:
			m = _wait_mission("MissionTowerForklift")
			if m == null:
				return false
			var mf: MissionTowerForklift = m
			if frames == 1 or not mark.has("pcam"):
				mark["pcam"] = tw.player.camera
				mark["cut0"] = cuts_seen.size()
			_watch_cut("warehouse: Alexander")
			var b: ForkliftBoss = mf.fight.boss as ForkliftBoss
			if mf.card == null:
				if frames > 300:
					_check(false, "warehouse: no card after the cut")
					_next(3)
				return false
			_card_beat(mf, b.driver, mark["pcam"], "warehouse: Alexander")
			_check(cuts_seen.size() == int(mark["cut0"]) + 1, "warehouse: the cut on Alexander ran before the card")
			mf.fight.combat.receive_attack(b, {"damage": 999.0})
			_next(21)
		21:
			if not (tw.fail_ui and tw.fail_ui.visible):
				return frames > 120 and _bail("warehouse: no fail card")
			tw.fail_ui.press_retry()
			_next(22)
		22:
			var mf2: MissionTowerForklift = m
			_watch_cut("warehouse retry")
			if frames < 90:
				return false
			_check(mf2.beat_fx.cuts == 1 and mf2.beat_fx.cards == 1 and mf2.card == null, "warehouse: THỬ LẠI plays no second cut or card")
			mf2.finish({})
			_next(3)
		# ----- the server floor -----
		3:
			m = _wait_mission("MissionTowerKatana")
			if m == null:
				return false
			var mk: MissionTowerKatana = m
			if frames == 1 or not mark.has("pcam3"):
				mark["pcam3"] = tw.player.camera
				mark["cut3"] = cuts_seen.size()
			_watch_cut("servers: Za Mẫn")
			if mk.card == null:
				_check(mk.duel.state != "running", "servers: Za Mẫn stands staged during the cut")
				if frames > 300:
					_check(false, "servers: no card after the cut")
					_next(4)
				return false
			_check(mk.duel.state != "running", "servers: the duel waits for the card")
			_card_beat(mk, mk.duel.boss, mark["pcam3"], "servers: Za Mẫn")
			_check(mk.duel.state == "running", "servers: the duel starts after the card")
			_check(cuts_seen.size() == int(mark["cut3"]) + 1, "servers: the cut on Za Mẫn ran before the card")
			mk.finish({})
			_next(4)
		# ----- the showroom -----
		4:
			m = _wait_mission("MissionTowerStealth")
			if m == null:
				return false
			var ms: MissionTowerStealth = m
			for g: Node3D in ms.guards:
				if g is Gunman:
					(g as Gunman).patrol_sight_m = 0.0
			if not mark.has("cut4"):
				mark["cut4"] = cuts_seen.size()
			_watch_cut("showroom guard %d" % ms.beat_fx.cuts)
			var cdl: CameraDirector = CameraDirector.live()
			var idle: bool = cdl == null or not cdl.cutting()
			if idle and ms.beat_fx.cuts == 1 and not mark.has("g2"):
				mark["g2"] = true
				tw.player.teleport(tw.level.world("mannequins", Vector3(5.0, 0.0, 7.5)), 0.0)
			elif idle and ms.beat_fx.cuts == 2 and not mark.has("g3"):
				mark["g3"] = true
				tw.player.teleport(tw.level.world("mannequins", Vector3(-5.5, 0.0, -5.0)), 0.0)
			elif idle and ms.beat_fx.cuts == 3 and frames > 10:
				_close_watch()
				_check(cuts_seen.size() == int(mark["cut4"]) + 3, "showroom: three guard cuts framed (%s)" % str(cuts_seen))
				_check(not ms.spotted, "showroom: unseen (blind guards)")
				ms.finish({})
				_next(5)
			elif frames > 900:
				_check(false, "showroom: %d cuts only" % ms.beat_fx.cuts)
				ms.finish({})
				_next(5)
		# ----- the laser corridor -----
		5:
			m = _wait_mission("MissionTowerLasers")
			if m == null:
				return false
			var ml: MissionTowerLasers = m
			if not mark.has("cut5"):
				mark["cut5"] = cuts_seen.size()
			_watch_cut("lasers cut %d" % ml.beat_fx.cuts)
			var cd5: CameraDirector = CameraDirector.live()
			var idle5: bool = cd5 == null or not cd5.cutting()
			if idle5 and ml.beat_fx.cuts == 1 and not mark.has("l2"):
				mark["l2"] = true
				tw.player.teleport(tw.level.world("gallery", Vector3(0.0, 0.0, 32.4)), 0.0)
			elif idle5 and ml.beat_fx.cuts == 2 and frames > 10:
				_close_watch()
				_check(cuts_seen.size() == int(mark["cut5"]) + 2, "lasers: two corridor cuts framed (%s)" % str(cuts_seen))
				_check(ml.trips == 0, "lasers: no trip during the cuts")
				_next(999)
			elif frames > 900:
				_check(false, "lasers: %d cuts only" % ml.beat_fx.cuts)
				_next(999)
	return false


func _bail(what: String) -> bool:
	_check(false, what)
	phase = 999
	return false


func _end() -> bool:
	if tw and is_instance_valid(tw):
		tw.queue_free()
	paused = false
	for p: String in [TMP, TMP_U, TMP_C, TMP_B]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	StoryChapters.unlocks_path = StoryChapters.UNLOCKS_PATH
	StoryChapters.chapters_path = StoryChapters.CHAPTERS_PATH
	StoryChapters.backup_path = StoryChapters.BACKUP_PATH
	StoryTower.test_opts = {}
	sm.set("story_context", {})
	sd.call("hide_result")
	sd.call("reset_state")
	sd.set("save_path", "user://story_save.cfg")
	print("  cuts framed: %s" % str(cuts_seen))
	if fails.is_empty():
		print("SUCCESS test_d7_previews (every floor's preview cuts framed, the villain cards over the frozen cuts)")
		quit(0)
	else:
		print("FAILED test_d7_previews: %d issues" % fails.size())
		quit(1)
	return true
