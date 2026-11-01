# File: res://tests/test_tower_level.gd
# Headless test of the Lọ Academy tower's floors (plan 2026-11-01-w4-day7.md T3):
#   A. the level alone: seven floor cells side by side, show_floor shows one; every mission point of every task stands on
#      its own floor (a down ray finds the slab under it), inside its cell, not inside a solid; the mannequin patrols are
#      walkable legs; the parking ring's lane is clear of the core and the parapet;
#   B. the laser rules: every lethal beam is telegraphed >= 0.5 s (a blink wall's dim warn phase right before every "on",
#      a sweep's ghost beam running TELE_S ahead of it), and every row of beams leaves a way through at some time;
#   C. the floors in the real tower (StoryTower from d7_parking, each mission finished in turn): the findability helper of
#      every floor tracks its threats and goal (the parking's edge arrows for the wolves off screen; the deck's heavy from
#      behind settles in his slot on the ring, stays within 3 m of it and on the road while he paces, then winds up; the warehouse's
#      Alexander and forklift markers, the server floor's Za Mẫn, the showroom's alerted guard arrow and the lift, the
#      laser corridor's door, the gallery's guards, Lọ by name and the ammo);
#   D. the laser corridor played: a static beam trips "BỊ LỘ"; standing in a blink wall through its off and warn phases is
#      safe (the warn buzz plays) and its "on" trips at once; a sweep's ghost passes the player TELE_S before the lit beam
#      trips; the door ends the floor (replay seg_d7_floors) and the gallery starts.
# Run:  godot --headless --path . --script tests/test_tower_level.gd
extends SceneTree

var TMP: String = "user://test_tower_level_%d.cfg" % OS.get_process_id()
var TMP_U: String = "user://test_tower_level_unlocks_%d.cfg" % OS.get_process_id()
var TMP_C: String = "user://test_tower_level_chapters_%d.cfg" % OS.get_process_id()
var TMP_B: String = "user://test_tower_level_backup_%d.cfg" % OS.get_process_id()
const DT: float = 1.0 / 60.0
const TOWER: String = "res://scenes/story/StoryTower.tscn"
var fails: Array[String] = []
var frames: int = 0
var total: int = 0
var phase: int = 0
var sd: Node
var sm: Node
var lv: LairTower = null
var tw: StoryTower = null
var m: StoryMission
var mark: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST TOWER LEVEL (floors, points, lasers, findable threats) ---")
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


func _timeout(cap: int, what: String) -> bool:
	if frames > cap:
		_check(false, what)
		phase = 999
		return true
	return false


func _wait_mission(cls: String, cap: int = 200) -> StoryMission:
	var mn: StoryMission = tw.mission_node if tw else null
	if mn != null and is_instance_valid(mn) and String(mn.get_script().get_global_name()) == cls:
		return mn
	if frames > cap:
		_check(false, "%s did not start in the tower (step %s)" % [cls, String(sd.get("step"))])
		phase = 999
	return null


func _step_card(mn: Object) -> void:
	var n: int = 0
	while mn.get("card") != null and n < 600:
		(mn.get("card") as StoryVillainCard).step(DT)
		n += 1


func _fail_shown(what: String, cap: int = 90) -> bool:
	if tw.fail_ui and tw.fail_ui.visible:
		return true
	if frames > cap:
		_check(false, "%s but no fail card" % what)
		phase = 999
	return false


## Rides the bike round the deck's ring (gas, steering at the lane's centre ahead), for the parking checks.
func _ride(ch: BikeChase) -> void:
	if ch.route == null or ch.bike == null or ch.s_p < 0.0:
		return
	var tgt: Vector2 = ch.route.world(clampf(ch.s_p + 9.0 + absf(ch.bike.current_speed_ms) * 0.35, 0.0, ch.route.length), 0.0)
	var to: Vector2 = tgt - ch.p_pos
	var steer: float = clampf(wrapf(atan2(-to.x, -to.y) - ch.bike.rotation.y, -PI, PI) * 3.0, -1.0, 1.0)
	Input.action_press("gas")
	if steer > 0.02:
		Input.action_press("steer_left", steer)
		Input.action_release("steer_right")
	elif steer < -0.02:
		Input.action_press("steer_right", -steer)
		Input.action_release("steer_left")
	else:
		Input.action_release("steer_left")
		Input.action_release("steer_right")


## Floor under p: the hit y of a ray from 2 m above to 1 m below (INF = none).
func _floor_y(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, -1.0, 0.0))
	var h: Dictionary = space.intersect_ray(q)
	return float((h["position"] as Vector3).y) if not h.is_empty() else INF


func _solid_at(space: PhysicsDirectSpaceState3D, p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collide_with_areas = false
	return not space.intersect_point(q, 1).is_empty()


func _clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b)).is_empty()


## Every Vector3 in a mission point dict (nested arrays included), with its key.
func _points_of(d: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in d.keys():
		if String(k) in ["centre", "route", "lasers"]:
			continue
		_collect(String(k), d[k], out)
	return out


func _collect(k: String, v: Variant, out: Array) -> void:
	if v is Vector3:
		out.append([k, v])
	elif v is Array:
		for e: Variant in v:
			_collect(k, e, out)


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
			lv = LairTower.new()
			root.add_child(lv)
			lv.build()
			_next(1)
		# ===== A. the level =====
		1:
			if frames < 3:
				return false
			_check(lv.cells.size() == LairTower.FLOORS.size(), "seven floor cells")
			for f: String in LairTower.FLOORS:
				lv.show_floor(f)
				var vis: int = 0
				for k: Variant in lv.cells.keys():
					vis += int((lv.cells[k] as Node3D).visible)
				_check(vis == 1 and (lv.cells[f] as Node3D).visible and lv.cover_root == lv.cells[f], "show_floor(%s): only that cell" % f)
				_check(absf(lv.floor_xf(f).origin.x - LairTower.CELL_X * float(LairTower.FLOORS.find(f))) < 0.01, "%s sits at its own CELL_X" % f)
			var space: PhysicsDirectSpaceState3D = lv.get_world_3d().direct_space_state
			for task: String in LairTower.TASK_FLOOR.keys():
				var f: String = LairTower.floor_of(task)
				var cx: float = lv.floor_xf(f).origin.x
				var d: Dictionary = lv.mission_points(task)
				var pts: Array = _points_of(d)
				_check(not pts.is_empty(), "%s has mission points" % task)
				for e: Array in pts:
					var p: Vector3 = e[1]
					var fy: float = _floor_y(space, p)
					_check(absf(fy - p.y) < 0.15, "%s.%s stands on the floor (%s, floor %.2f)" % [task, String(e[0]), str(p), fy])
					_check(absf(p.x - cx) < LairTower.CELL_X * 0.4, "%s.%s inside its cell" % [task, String(e[0])])
					if String(e[0]) != "spot":                 # the typing chair is at the desk
						_check(not _solid_at(space, p + Vector3(0.0, 0.5, 0.0)) and not _solid_at(space, p + Vector3(0.0, 1.2, 0.0)), "%s.%s is not inside a solid" % [task, String(e[0])])
			# the showroom patrols: walkable legs (knee and chest height)
			var mp: Dictionary = lv.mission_points("mannequins")
			var blocked: Array[String] = []
			var pi_: int = 0
			for pr: Array in mp["patrols"]:
				var route: Array = (pr[1] as Array) + [(pr[1] as Array)[0]]        # a patrol loops back to its first point
				for i: int in route.size() - 1:
					for h: float in [0.5, 1.2]:
						if not _clear(space, (route[i] as Vector3) + Vector3(0.0, h, 0.0), (route[i + 1] as Vector3) + Vector3(0.0, h, 0.0)):
							blocked.append("patrol %d leg %d" % [pi_, i])
				pi_ += 1
			_check(blocked.is_empty(), "every showroom patrol leg is walkable %s" % str(blocked))
			# the parking ring: the lane clear of the core and the parapet, on the slab
			var ring: PackedVector2Array = lv.route(1)
			var lane_ok: bool = ring.size() >= 36
			for k2: int in range(0, ring.size(), 3):
				var q: Vector3 = Vector3(ring[k2].x, 0.0, ring[k2].y)
				for side: float in [-LairTower.RING_R + LairTower.RING_IN + 1.0, 0.0, LairTower.RING_OUT - LairTower.RING_R - 1.0]:
					var o: Vector3 = lv.floor_xf("parking").origin
					var rp: Vector3 = o + ((q - o) * Vector3(1.0, 0.0, 1.0)).normalized() * (LairTower.RING_R + side)
					lane_ok = lane_ok and not _solid_at(space, rp + Vector3(0.0, 0.7, 0.0)) and absf(_floor_y(space, rp)) < 0.15
			_check(lane_ok, "the ring lane (%.0f..%.0f m) is clear and paved" % [LairTower.RING_IN + 1.0, LairTower.RING_OUT - 1.0])
			_next(2)
		# ===== B. the laser rules =====
		2:
			var defs: Array = lv.laser_defs()
			var kinds: Dictionary = {}
			for d: Dictionary in defs:
				kinds[String(d.get("mode", "static"))] = true
			_check(kinds.has("static") and kinds.has("blink") and kinds.has("sweep"), "static, blinking and sweeping beams")
			_check(MissionTowerLasers.TELE_S >= 0.5, "the telegraph is >= 0.5 s (%.2f)" % MissionTowerLasers.TELE_S)
			var blink_ok: bool = true
			var ghost_ok: bool = true
			for d2: Dictionary in defs:
				var mode: String = String(d2.get("mode", "static"))
				if mode == "blink":
					# every off -> on passes through warn for >= TELE_S
					var prev: String = MissionTowerLasers.beam_state(d2, 0.0)
					var warn_n: int = 0
					for i: int in range(1, 1200):
						var st: String = MissionTowerLasers.beam_state(d2, float(i) / 60.0)
						if st == "warn":
							warn_n += 1
						if st == "on" and prev != "on":
							blink_ok = blink_ok and prev == "warn" and warn_n >= roundi(MissionTowerLasers.TELE_S * 60.0) - 1
						if st != "warn":
							warn_n = 0
						prev = st
				elif mode == "sweep":
					for i2: int in 240:
						var at: float = float(i2) / 60.0
						ghost_ok = ghost_ok and MissionTowerLasers.ghost_point(d2, at).is_equal_approx(MissionTowerLasers.beam_point(d2, at + MissionTowerLasers.TELE_S))
			_check(blink_ok, "every blink lights only after >= %.1f s of its dim warn" % MissionTowerLasers.TELE_S)
			_check(ghost_ok, "every sweep's ghost runs %.1f s ahead of it" % MissionTowerLasers.TELE_S)
			# every row of beams (same z) leaves a way through at some time in 6 s
			var rows: Dictionary = {}
			for d3: Dictionary in defs:
				var z: float = snappedf(((d3["a"] as Vector3).z + (d3["b"] as Vector3).z) * 0.5, 0.5)
				if not rows.has(z):
					rows[z] = []
				(rows[z] as Array).append(d3)
			var cx2: float = lv.floor_xf("gallery").origin.x
			var pass_ok: bool = true
			for z2: Variant in rows.keys():
				var found: bool = false
				for ti: int in 60:
					var tt: float = float(ti) * 0.1
					for xi: int in 11:
						var p: Vector3 = Vector3(cx2 - 2.5 + 0.5 * float(xi), 0.0, float(z2))
						var hit: bool = false
						for d4: Dictionary in rows[z2]:
							hit = hit or MissionTowerLasers.beam_hits(d4, tt, p)
						if not hit:
							found = true
					if found:
						break
				pass_ok = pass_ok and found
			_check(pass_ok, "every laser row has a way through (%d rows)" % rows.size())
			lv.queue_free()
			lv = null
			_next(3)
		# ===== C. the floors in the real tower =====
		3:
			if frames < 3:
				return false
			sd.call("new_story", {"female": true, "name": "Lan", "variant": 0, "hair_style": "short", "hair_color": 2, "skin": 2})
			sd.set("day", 7)
			sd.call("_enter", "d7_parking")
			tw = (load(TOWER) as PackedScene).instantiate()
			root.add_child(tw)
			_next(4)
		4:
			m = _wait_mission("MissionTowerParking")
			if m == null:
				return false
			var mp: MissionTowerParking = m
			var g: RouteGuide = mp.chase.guide if mp.chase else null
			if g == null:
				_check(false, "the parking chase has its RouteGuide")
				phase = 999
				return false
			if g.active_n >= 1 and frames > 30:
				_check(g.edge_count + g.on_screen_n >= g.active_n, "parking: every wolf off screen has its edge arrow (%d active, %d on screen, %d arrows)" % [g.active_n, g.on_screen_n, g.edge_count])
				mark["park_seen"] = true
			if mark.has("park_seen") and g.edge_count >= 1:
				mark["park_edge"] = true
			if mark.has("park_edge") or frames > 900:
				_check(mark.has("park_edge"), "parking: a wolf behind gets a red edge arrow")
				_next(40)
		40:
			# the deck's heavy from behind (Sói Xám as deck_waves() spawns him: route_ff) settles in his slot on the ring and
			# stays there, on the deck's road, while he paces; then he winds up (god mode, the bike ridden round the ring)
			var mp2: MissionTowerParking = m
			var ch: BikeChase = mp2.chase
			if frames == 1:
				ch.combat.god = true
				mark["hv"] = ch._spawn((MissionTowerParking.deck_waves()[2] as Array)[0])
				mark["pace_n"] = 0
				mark["near_n"] = 0
				mark["road_n"] = 0
			_ride(ch)
			var hv: BikerEnemy = mark["hv"]
			if hv.settled_t > 0.0 and not mark.has("hv_settled"):
				mark["hv_settled"] = frames
			if mark.has("hv_settled") and hv.state_name() == "pace":
				mark["pace_n"] = int(mark["pace_n"]) + 1
				mark["near_n"] = int(mark["near_n"]) + (1 if hv.pos2.distance_to(hv.slot_target()) < 3.0 else 0)
				mark["road_n"] = int(mark["road_n"]) + (1 if ch.on_road(hv.pos2) else 0)
			if frames > 900 or (mark.has("hv_settled") and frames - int(mark["hv_settled"]) > 480):
				var pn: int = int(mark["pace_n"])
				_check(mark.has("hv_settled"), "parking: the heavy from behind settles in his slot on the ring")
				_check(pn >= 30 and float(mark["near_n"]) >= 0.85 * pn, "parking: the heavy stays within 3 m of his slot while he paces (%d / %d frames)" % [int(mark["near_n"]), pn])
				_check(pn >= 30 and float(mark["road_n"]) >= 0.95 * pn, "parking: the heavy stays on the deck's road while he paces (%d / %d frames)" % [int(mark["road_n"]), pn])
				_check(hv.attacks >= 1, "parking: the heavy winds up from his slot (%d attacks)" % hv.attacks)
				for a: String in ["gas", "brake", "steer_left", "steer_right"]:
					Input.action_release(a)
				ch.combat.god = false
				mp2.finish({})
				_next(5)
		5:
			m = _wait_mission("MissionTowerForklift")
			if m == null:
				return false
			var mf: MissionTowerForklift = m
			_step_card(mf)
			var tracked: Dictionary = {}
			for it: Dictionary in mf.markers._items:
				tracked[String(it["label"])] = String(it["kind"])
			_check(tracked.get("Alexander", "") == "threat" and tracked.get("Xe nâng", "") == "prompt", "warehouse: Alexander tracked as the threat, the forklift as the prompt (%s)" % str(tracked))
			mf.finish({})
			_next(6)
		6:
			m = _wait_mission("MissionTowerKatana")
			if m == null:
				return false
			var mk: MissionTowerKatana = m
			_step_card(mk)
			if frames < 4:
				return false
			_check(mk.guide != null and mk.guide.extra == mk.duel.boss, "servers: the guide tracks Za Mẫn")
			mk.finish({})
			_next(7)
		7:
			m = _wait_mission("MissionTowerStealth")
			if m == null:
				return false
			var ms: MissionTowerStealth = m
			if frames < 4:
				return false
			ms.guide.refresh()
			_check(ms.guide.fight == ms.fight and is_equal_approx(ms.guide.near_m, 9.0) and ms.guide.goal_mode != "", "showroom: the guide watches the patrols and shows the lift (%s)" % ms.guide.goal_mode)
			# turn back to the lift doors: the patrols are behind; unalerted and far = no arrow, alerted = a red edge arrow
			tw.player.teleport(ms.pts["start"], PI)
			_next(8)
		8:
			var ms8: MissionTowerStealth = m
			if frames < 30:
				return false
			var gd: Gunman = ms8.fight.gunmen[0]
			var cam: Camera3D = tw.get_viewport().get_camera_3d()
			var behind: bool = cam != null and cam.is_position_behind(gd.global_position + Vector3(0.0, 1.5, 0.0))
			_check(behind, "showroom: the first guard is behind the camera")
			if not mark.has("alerted"):
				ms8.guide.refresh()
				_check(ms8.guide.edge_threats == 0, "showroom: far, unalerted guards get no arrow (%d)" % ms8.guide.edge_threats)
				mark["alerted"] = true
				gd.alert(tw.player.global_position)
				return false
			if frames < 40:
				return false
			ms8.guide.refresh()
			_check(gd.is_alerted and ms8.guide.edge_threats >= 1, "showroom: the alerted guard behind gets an edge arrow (%d)" % ms8.guide.edge_threats)
			ms8.finish({})
			_next(9)
		# ===== D. the laser corridor =====
		9:
			m = _wait_mission("MissionTowerLasers")
			if m == null:
				return false
			var ml: MissionTowerLasers = m
			ml.guide.refresh()
			_check(ml.guide.goal_mode != "", "lasers: the door is marked (%s)" % ml.guide.goal_mode)
			var sweeps: int = 0
			for i: int in ml.defs.size():
				if String(ml.defs[i].get("mode", "")) == "sweep":
					sweeps += 1
					_check(ml.ghosts[i] != null and ml.ghosts[i].visible, "sweep %d has its ghost beam" % i)
			var want_sw: int = 3 if Difficulty.easy else 5   # T5b: Thường adds the z 37 and z 20 sweeps
			_check(sweeps == want_sw and ml.rails.size() == want_sw, "%d sweeps, %d floor rails (%d / %d)" % [want_sw, want_sw, sweeps, ml.rails.size()])
			# a static beam: BỊ LỘ
			var st_i: int = -1
			for i2: int in ml.defs.size():
				if String(ml.defs[i2].get("mode", "")) == "static":
					st_i = i2
					break
			var d0: Dictionary = ml.defs[st_i]
			var mid: Vector3 = ((d0["a"] as Vector3) + (d0["b"] as Vector3)) * 0.5
			tw.player.teleport(mid, 0.0)
			_next(10)
		10:
			if not _fail_shown("in a static beam", 30):
				return false
			var ml: MissionTowerLasers = m
			_check(ml.trips == 1 and tw.fail_ui.title_label.text == StoryMission.T_LO and ml.cues_played.has("alarm_siren"), "a static beam: BỊ LỘ with the alarm")
			tw.fail_ui.press_retry()
			_check(ml.state == "running" and is_equal_approx(ml.t, 0.0), "retry: back at the lift, the beams' clock from zero")
			_next(11)
		11:
			# a blink wall: stand in it while it is off; safe through the warn, tripped as it lights
			var ml: MissionTowerLasers = m
			var bi: int = -1
			for i: int in ml.defs.size():
				if String(ml.defs[i].get("mode", "")) == "blink":
					bi = i
					break
			var d: Dictionary = ml.defs[bi]
			if not mark.has("in_blink"):
				if MissionTowerLasers.beam_state(d, ml.t) == "off" and MissionTowerLasers.beam_state(d, ml.t + MissionTowerLasers.TELE_S + 0.2) == "off":
					mark["in_blink"] = true
					var mid: Vector3 = ((d["a"] as Vector3) + (d["b"] as Vector3)) * 0.5
					tw.player.teleport(mid, 0.0)
					mark["buzz0"] = ml.buzzes
					mark["trips0"] = ml.trips
				_timeout(400, "the blink wall never turned off")
				return false
			var st: String = MissionTowerLasers.beam_state(d, ml.t)
			if st == "warn" and not mark.has("warn_f"):
				mark["warn_f"] = total
			if ml.trips > int(mark["trips0"]):
				var wf: int = total - int(mark.get("warn_f", total))
				_check(mark.has("warn_f") and wf >= roundi(MissionTowerLasers.TELE_S * 60.0) - 1, "in the wall: safe through %d frames of warn" % wf)
				_check(ml.buzzes > int(mark["buzz0"]) and ml.cues_played.has("fluoro_buzz"), "the warn buzzes before it lights")
				_check(MissionTowerLasers.beam_state(d, ml.t) == "on" or MissionTowerLasers.beam_state(d, ml.t - 2.0 / MissionTowerLasers.BEAM_HZ) == "on", "it trips once it is on")
				_next(12)
				return false
			_timeout(600, "the blink wall never tripped")
		12:
			if not _fail_shown("in a lit blink wall", 30):
				return false
			tw.fail_ui.press_retry()
			_next(13)
		13:
			# a sweep: the ghost passes the player TELE_S before the lit beam trips
			var ml: MissionTowerLasers = m
			var si: int = -1
			for i: int in ml.defs.size():
				if String(ml.defs[i].get("mode", "")) == "sweep":
					si = i
					break
			var d: Dictionary = ml.defs[si]
			if not mark.has("sweep_at"):
				# where the lit beam will be 1.0 s from now: stand there now (the beam is elsewhere)
				var at: Vector3 = MissionTowerLasers.beam_point(d, ml.t + 1.0)
				mark["sweep_at"] = at
				mark["sweep_t"] = ml.t
				mark["trips1"] = ml.trips
				tw.player.teleport(at, 0.0)
				return false
			# the ghost "touches" the player by the same rule as the lit beam (within PLAYER_R of the line)
			var at2: Vector3 = mark["sweep_at"]
			var gp: Vector3 = MissionTowerLasers.ghost_point(d, ml.t)
			if not mark.has("ghost_t") and Vector2(gp.x - at2.x, gp.z - at2.z).length() <= MissionTowerLasers.PLAYER_R:
				mark["ghost_t"] = ml.t
				_check(ml.trips == int(mark["trips1"]) and ml.state == "running", "the ghost touches the player harmlessly")
			if ml.trips > int(mark["trips1"]):
				var lead: float = ml.t - float(mark.get("ghost_t", ml.t))
				_check(mark.has("ghost_t") and lead >= MissionTowerLasers.TELE_S - 2.0 / MissionTowerLasers.BEAM_HZ, "the ghost passed %.2f s before the sweep tripped" % lead)
				_next(14)
				return false
			_timeout(300, "the sweep never reached the player")
		14:
			if not _fail_shown("in a sweep", 30):
				return false
			tw.fail_ui.press_retry()
			var ml: MissionTowerLasers = m
			tw.player.teleport(ml.pts["goal"], 0.0)
			_next(15)
		15:
			var ml: MissionTowerLasers = m as MissionTowerLasers if is_instance_valid(m) else null
			if ml and ml.replay != null:
				var n: int = 0
				while is_instance_valid(ml) and ml.replay != null and n < 1200:
					ml.replay.step(DT)
					n += 1
				mark["replay_l"] = true
			m = tw.mission_node
			if m == null or not is_instance_valid(m) or String(m.get_script().get_global_name()) != "MissionBossGuns":
				_timeout(600, "the door did not end the corridor (step %s)" % String(sd.get("step")))
				return false
			_check(mark.has("replay_l") and String(sd.get("step")) == "d7_boss1", "the door: seg_d7_floors, then the gallery")
			_next(16)
		# ===== C (end). the gallery's markers =====
		16:
			var mg: MissionBossGuns = m
			_step_card(mg)
			if frames < 3:
				return false
			_check(mg.markers != null and mg.markers.threat_label == MissionBossGuns.T_GUARD, "gallery: OffscreenMarkers on the mission HUD")
			var ammo: int = 0
			for it: Dictionary in mg.markers._items:
				if String(it["label"]) == MissionBossGuns.T_AMMO and String(it["kind"]) == "prompt":
					ammo += 1
			_check(ammo == mg.fight.pickups.size() and ammo >= 3, "gallery: the ammo drops marked (%d)" % ammo)
			# turn the back on the guards: they get edge arrows
			tw.player.teleport(mg.pts["start"], PI)
			_next(17)
		17:
			var mg: MissionBossGuns = m
			if frames < 60:
				return false
			var cam: Camera3D = tw.get_viewport().get_camera_3d()
			var behind: int = 0
			for g: Variant in mg.fight.alive():
				if cam and cam.is_position_behind((g as Node3D).global_position + Vector3(0.0, 1.5, 0.0)):
					behind += 1
			_check(behind >= 1 and mg.markers.edge_count >= behind, "gallery: the guards behind get edge arrows (%d behind, %d arrows)" % [behind, mg.markers.edge_count])
			for e: Variant in mg.fight.alive():
				var n: int = 0
				while not (e as Gunman).is_defeated() and n < 80:
					(e as Gunman).take_hit({"kind": "bullet", "from": tw.player.global_position})
					n += 1
			_next(18)
		18:
			var mg: MissionBossGuns = m
			if mg.lo == null:
				_timeout(400, "Lọ did not come")
				return false
			if not mark.has("lo_f"):
				mark["lo_f"] = frames
			if frames - int(mark["lo_f"]) < 60:          # past his 0.6 s preview cut (no markers over a cut)
				return false
			var named: bool = false
			for it: Dictionary in mg.markers._items:
				named = named or (it["node"] == mg.lo and String(it["kind"]) == "threat" and String(it["label"]) == MissionBossGuns.LO_LABEL)
			_check(named, "gallery: Lọ tracked by name")
			_check(not mg._guards().has(mg.lo), "Lọ is not doubled in the guards' markers")
			var shown: bool = false
			for s: String in mg.markers.shown_labels():
				shown = shown or s.begins_with(MissionBossGuns.LO_LABEL)
			_check(shown or mg.markers.chevron_count >= 1, "gallery: his marker shows (%s)" % str(mg.markers.shown_labels()))
			phase = 999
	return false


func _end() -> bool:
	if lv and is_instance_valid(lv):
		lv.queue_free()
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
	if fails.is_empty():
		print("✅ SUCCESS: TOWER LEVEL (floors and points on the floor, walkable patrols, the ring lane, laser telegraphs and rows, every floor's markers, static / blink / sweep trips, the door)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
