# File: res://tests/test_basement_guide.gd
# W3 Day 5 T9 (plan 2026-10-30-w3-day5.md, readability): BasementGuide in the StoryBasement scene (no story running).
# Checks: the stealth's goal (the control room) shows over the spot while it is ahead and as an edge arrow while the player
# faces away; a nearby unalerted guard off screen gets a dim edge chevron; in the gunfight an alerted gunman behind the
# camera gets a red one; gunmen hidden behind a rack row are pinged once none has been in sight for LOST_S (and not
# before); the guide hides during a director cut and once the mission ended; the hack's way back to the desk is the goal.
# Run:  godot --headless --path . --script tests/test_basement_guide.gd
extends SceneTree

const DT: float = 1.0 / 60.0
const BASEMENT: String = "res://scenes/story/StoryBasement.tscn"
var TMP: String = "user://test_basement_guide_%d.cfg" % OS.get_process_id()
var fails: Array[String] = []
var phase: int = 0
var frames: int = 0
var total: int = 0
var bs: StoryBasement
var m: StoryMission
var hold: Callable = Callable()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("--- TEST BASEMENT GUIDE (readability) ---")
	Engine.max_fps = 60
	var sd: Node = root.get_node_or_null("StoryDirector")
	if sd:
		sd.set("save_path", TMP)
	StoryBasement.test_opts = {"missions": {"manual": true, "manual_replay": true, "seed": 3}, "capture_mouse": false, "go_roam": false}


func _next(p: int) -> void:
	phase = p
	frames = 0


func _start(id: String) -> StoryMission:
	_check(bs.start_mission(StoryMissions.beat(id)), "%s starts" % id)
	var mn: StoryMission = bs.mission_node
	for c: Dictionary in mn.done.get_connections():
		mn.done.disconnect(c["callable"])
	return mn


## The player at local p looking along the camera yaw (0 = toward the server room, PI = toward the stairs).
func _place(p: Vector3, yaw: float) -> void:
	bs.player.teleport(bs.level.world(p), yaw)
	bs.player.yaw = yaw


## Guard g at local p facing -z (toward the server room: away from a player standing further up the hall).
func _pin(g: Gunman, p: Vector3) -> void:
	g.patrol = PackedVector3Array()
	g.position = bs.level.world(p)
	g.yaw = 0.0
	if g.body:
		g.body.rotation.y = 0.0


func _guide() -> BasementGuide:
	return m.get("guide") as BasementGuide if m else null


func _process(_d: float) -> bool:
	frames += 1
	total += 1
	if total > 4000:
		_check(false, "timeout in phase %d" % phase)
		phase = 99
	if hold.is_valid():
		hold.call()
	if m and is_instance_valid(m) and m.state == "running":
		m.advance(DT)
	match phase:
		0:
			Difficulty.set_easy(false)          # GameFX applied the settings file after _initialize
			bs = (load(BASEMENT) as PackedScene).instantiate()
			root.add_child(bs)
			_next(1)
		1:
			if frames < 3:
				return false
			m = _start("d5_stealth")
			_check(_guide() != null and _guide().has_goal, "the stealth owns a guide with the control room as its goal")
			_place(LairBasement.START, 0.0)
			var ms: MissionBasementStealth = m as MissionBasementStealth
			for e: Variant in ms.fight.alive():
				_pin(e as Gunman, Vector3(-10.0, 0.0, 12.0))   # far from the player: no near chevron yet
			hold = func() -> void:
				for e2: Variant in ms.fight.alive():
					_pin(e2 as Gunman, Vector3(-10.0, 0.0, 12.0))
			_next(2)
		2:
			if frames < 20:
				return false
			var gd: BasementGuide = _guide()
			gd.refresh()
			_check(gd.shown and gd.goal_mode == "on" and gd.goal_label.begins_with(MissionBasementStealth.T_GOAL), "facing the hall: the goal marker over the control room (%s, %s)" % [gd.goal_mode, gd.goal_label])
			_check(gd.edge_threats == 0, "no threat chevrons with the guards far away")
			_place(LairBasement.START, PI)            # back to the hall
			_next(3)
		3:
			if frames < 20:
				return false
			var gd3: BasementGuide = _guide()
			gd3.refresh()
			_check(gd3.goal_mode == "edge", "facing away: the goal as an edge arrow (%s)" % gd3.goal_mode)
			_check(gd3.goal_dir.y > 0.0, "the arrow points down the screen (turn around)")
			var ms3: MissionBasementStealth = m as MissionBasementStealth
			var near: Gunman = ms3.fight.alive()[0]
			hold = func() -> void:
				for e3: Variant in ms3.fight.alive():
					_pin(e3 as Gunman, LairBasement.START + Vector3(0.0, 0.0, -6.0) if e3 == near else Vector3(-10.0, 0.0, 12.0))
			_next(4)
		4:
			if frames < 4:
				return false
			var gd4: BasementGuide = _guide()
			gd4.refresh()
			_check(not (m as MissionBasementStealth).spotted, "unseen so far")
			_check(gd4.edge_threats == 1 and gd4.edge_dim.size() == 1 and gd4.edge_dim[0] == 1, "an unalerted guard 6 m behind: one dim chevron (%d)" % gd4.edge_threats)
			var cd: CameraDirector = CameraDirector.live()
			if cd and cd.preview_cut((m as MissionBasementStealth).fight.alive()[1], 0.6):
				gd4.refresh()
				_check(not gd4.shown, "hidden during a preview cut")
			hold = Callable()
			bs._free_mission()
			gd4 = null
			_next(5)
		5:
			if frames < 50:
				return false
			m = _start("d5_gunfight")
			var mg: MissionBasementGunfight = m as MissionBasementGunfight
			_check(_guide() != null and _guide().fight == mg.fight and not _guide().has_goal, "the gunfight's guide watches the fight (no goal)")
			_place(Vector3(0.0, 0.0, 8.0), PI)         # looking down the hall toward the stairs
			hold = func() -> void:
				var al: Array = mg.fight.alive()
				for i: int in al.size():
					if i == 0:
						_pin(al[i] as Gunman, Vector3(0.0, 0.0, 2.0))              # behind the camera, in the room's mouth
					else:
						_pin(al[i] as Gunman, Vector3(-0.3 + 0.3 * (i % 3), 0.0, 18.5))   # behind the x 0 rack row
			_next(6)
		6:
			if frames < 60:
				return false                          # wave 1's preview cut (0.6 s) first: the guide hides meanwhile
			var gd6: BasementGuide = _guide()
			gd6.lost_t = 0.0
			gd6.refresh()
			_check(gd6.edge_threats >= 1 and gd6.edge_dim.has(0), "an alerted gunman behind the camera: a red edge chevron (%d)" % gd6.edge_threats)
			_check(gd6.pinged == 0, "no ping before LOST_S")
			gd6.lost_t = BasementGuide.LOST_S
			gd6.refresh()
			_check(gd6.pinged >= 1, "none in sight for LOST_S: the hidden gunmen are pinged (%d)" % gd6.pinged)
			hold = Callable()
			bs._free_mission()
			_next(7)
		7:
			if frames < 50:
				return false
			m = _start("d5_hack")
			var mh: MissionHack = m as MissionHack
			_check(_guide() != null and not _guide().has_goal, "the hack: no goal while typing")
			mh.time_left = mh.countdown_s - MissionHack.BREACH_AT[0] + 0.01
			_next(8)
		8:
			var mh8: MissionHack = m as MissionHack
			if mh8.phase != "breach" and frames < 30:
				return false
			_check(mh8.phase == "breach" and _guide().fight == mh8.fight, "a breach: the guide watches the breach fight")
			for e8: Variant in mh8.fight.alive():
				(e8 as Gunman).take_hit({"kind": "blast", "from": bs.player.global_position})
			_next(9)
		9:
			var mh9: MissionHack = m as MissionHack
			if mh9.phase != "return" and frames < 60:
				return false
			_check(mh9.phase == "return" and _guide().has_goal and _guide().goal_text == MissionHack.T_DESK, "the breach cleared: the desk is the goal")
			mh9.return_to_desk()
			_check(not _guide().has_goal and _guide().fight == null, "back at the desk: no goal, no fight")
			bs._free_mission()
			_next(10)
		10:
			if frames < 5:
				return false
			phase = 99
		99:
			return _end()
	return false


func _end() -> bool:
	hold = Callable()
	StoryBasement.test_opts = {}
	if bs and is_instance_valid(bs):
		bs.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS: basement guide (goal on screen / edge, dim and red chevrons, the lost-contact ping, hidden in cuts, the hack's desk)")
		quit(0)
	else:
		print("FAILED: %d check(s)" % fails.size())
		quit(1)
	return true
