# File: res://tests/test_horror_toolkit.gd
# Headless test of the horror toolkit (spec B-D3, B-D12):
#   flashlight: 90 s battery drain, flicker only below 20 % (none in the gentle variant), empty -> off and refused, pickups;
#   senses: the 70° cone, 14 m / 22 m lit, a blocked ray, hearing a sprint at 10 m and a walk at 3 m, the noise radius
#           HorrorKit derives from the real ThirdPersonController (sprint, jog, Ctrl walk, still);
#   states: patrol -> suspicious (noise) -> chase (sight) -> search (lost) -> patrol after 15 s;
#   catch: within 1.2 m (all around), not at 1.5 m, not through a wall;
#   hiding: hide and exit with the real player (hidden, peek camera current, breath, back at the exit point, too far is
#           refused); a stalker that saw the player enter checks the spot and catches, one that did not walks past it;
#   scare director: budget 2 and the 60 s gap, the catch scare outside the budget, budget 1, "Giảm hù dọa" (soft sting:
#           no flash, no screech; horror cues -6 dB; flicker becomes a dim).
# Run:  godot --headless --path . --script tests/test_horror_toolkit.gd
extends SceneTree

var fails: Array[String] = []
var _caught_by: HorrorStalker = null
var _trash: Array[Node] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST HORROR TOOLKIT ---")
	_run()


func _run() -> void:
	await process_frame
	_flashlight()
	_senses()
	_states()
	_catch()
	_scares()
	await _hiding()
	for n: Node in _trash:
		if is_instance_valid(n):
			n.queue_free()
	await _frames(2)
	if fails.is_empty():
		print("✅ SUCCESS: HORROR TOOLKIT (flashlight, senses, states, catch, hiding, scare budget, reduced scares)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


# ---------------------------------------------------------------------------
func _flashlight() -> void:
	var fl := HorrorFlashlight.new()
	fl.auto_tick = false
	root.add_child(fl)
	_check(not fl.is_lit() and fl.battery == 1.0, "flashlight starts off and full")
	_check(fl.set_on(true) and fl.is_lit() and fl.light.visible, "[F] turns it on and lit")
	fl.tick(45.0)
	_check(absf(fl.battery - 0.5) < 0.001, "45 s on drains half the 90 s battery (%.3f)" % fl.battery)
	var off_high: int = 0
	var off_low: int = 0
	var on_low: int = 0
	var emptied: Array[bool] = [false]
	fl.emptied.connect(func() -> void: emptied[0] = true)
	var guard: int = 0
	while fl.on and guard < 2000:
		guard += 1
		var before: float = fl.battery
		fl.tick(0.05)
		if before >= HorrorFlashlight.FLICKER_BELOW:
			off_high += int(fl.flicker_off)
		elif fl.on:
			if fl.flicker_off:
				off_low += 1
			else:
				on_low += 1
	print("  flicker blips: %d above 20 %%, %d / %d below" % [off_high, off_low, off_low + on_low])
	_check(off_high == 0, "no flicker above 20 %% (%d)" % off_high)
	_check(off_low > 5 and on_low > off_low, "flickers below 20 %% but mostly stays on (%d off, %d on)" % [off_low, on_low])
	_check(emptied[0] and not fl.on and not fl.is_lit() and fl.battery == 0.0, "empty battery turns it off")
	_check(not fl.set_on(true), "cannot turn on with an empty battery")
	fl.add_battery(0.6)
	_check(absf(fl.battery - 0.6) < 0.001 and fl.set_on(true), "a pickup adds 60 %% and it lights again")
	fl.battery = 0.1
	fl.gentle = true
	var gentle_off: int = 0
	for i: int in 100:
		fl.tick(0.02)
		gentle_off += int(fl.flicker_off)
	_check(gentle_off == 0 and fl.light.visible, "gentle variant: no blips below 20 %%")
	_trash.append(fl)


# ---------------------------------------------------------------------------
func _make_stalker(pos: Vector3, facing: Vector3, s: HorrorSenses, g: HorrorNavGraph = null, patrol: PackedInt32Array = PackedInt32Array()) -> HorrorStalker:
	var st := HorrorStalker.new()
	st.build_model = false
	st.auto_update = false
	st.los_fn = func(_a: Vector3, _b: Vector3) -> bool: return true
	root.add_child(st)
	if g != null and not patrol.is_empty():
		st.setup(g, s, patrol, 0)
	else:
		st.senses = s
		st.graph = g
	st.global_position = pos
	st.face(facing)
	return st


func _cross_graph() -> HorrorNavGraph:
	var g := HorrorNavGraph.new()
	var prev: int = -1
	for i: int in 13:
		var id: int = g.add_node(Vector3(-30.0 + 5.0 * i, 0.0, 0.0), "x%d" % i)
		if prev >= 0:
			g.connect_nodes(prev, id)
		prev = id
	var center: int = g.id_of("x6")
	prev = -1
	for i: int in 13:
		var p := Vector3(0.0, 0.0, -30.0 + 5.0 * i)
		var id2: int = center if i == 6 else g.add_node(p, "z%d" % i)
		if prev >= 0:
			g.connect_nodes(prev, id2)
		prev = id2
	return g


func _senses() -> void:
	var s := HorrorSenses.new()
	var st: HorrorStalker = _make_stalker(Vector3.ZERO, Vector3(0, 0, -1), s)
	s.pos = Vector3(0, 0, -13)
	_check(st.can_see(), "sees the player ahead at 13 m")
	s.pos = Vector3(0, 0, -15)
	_check(not st.can_see(), "does not see an unlit player at 15 m")
	s.lit = true
	_check(st.can_see(), "sees a lit player at 15 m")
	s.pos = Vector3(0, 0, -21.5)
	_check(st.can_see(), "sees a lit player at 21.5 m")
	s.pos = Vector3(0, 0, -23)
	_check(not st.can_see(), "not at 23 m even lit")
	s.lit = false
	s.pos = Vector3(sin(deg_to_rad(30.0)) * 8.0, 0, -cos(deg_to_rad(30.0)) * 8.0)
	_check(st.can_see(), "sees 30° off the facing (inside the 70° cone)")
	s.pos = Vector3(sin(deg_to_rad(40.0)) * 8.0, 0, -cos(deg_to_rad(40.0)) * 8.0)
	_check(not st.can_see(), "not 40° off the facing (outside the 70° cone)")
	s.pos = Vector3(0, 0, 5)
	_check(not st.can_see(), "not behind")
	s.pos = Vector3(0, 0, -6)
	s.hidden = true
	_check(not st.can_see(), "never sees a hidden player")
	s.hidden = false
	st.los_fn = func(_a: Vector3, _b: Vector3) -> bool: return false
	_check(not st.can_see(), "not through a wall")
	st.los_fn = func(_a: Vector3, _b: Vector3) -> bool: return true
	# hearing (behind, so it cannot see)
	s.noise = HorrorKit.NOISE_SPRINT
	s.pos = Vector3(0, 0, 9)
	_check(st.can_hear(), "hears a sprint at 9 m")
	s.pos = Vector3(0, 0, 11)
	_check(not st.can_hear(), "not a sprint at 11 m")
	s.noise = HorrorKit.NOISE_WALK
	s.pos = Vector3(0, 0, 2.5)
	_check(st.can_hear(), "hears a walk (Ctrl) at 2.5 m")
	s.pos = Vector3(0, 0, 4)
	_check(not st.can_hear(), "not a walk at 4 m")
	s.noise = 0.0
	s.pos = Vector3(0, 0, 1.5)
	_check(not st.can_hear(), "a still player is silent")
	_trash.append(st)


# ---------------------------------------------------------------------------
func _states() -> void:
	var s := HorrorSenses.new()
	var g: HorrorNavGraph = _cross_graph()
	var st: HorrorStalker = _make_stalker(Vector3.ZERO, Vector3(0, 0, -1), s, g, PackedInt32Array([g.id_of("x2"), g.id_of("x10")]))
	st.global_position = Vector3.ZERO
	st.face(Vector3(0, 0, -1))
	st.reset_at(Vector3.ZERO)
	st.face(Vector3(0, 0, -1))
	st.catch_enabled = false   # this case follows the states; the catch has its own case
	_check(st.state == HorrorStalker.PATROL, "starts on patrol")
	# a sprint behind it
	s.pos = Vector3(0, 0, 8)
	s.noise = HorrorKit.NOISE_SPRINT
	for i: int in 3:
		st.step(1.0 / 60.0)
	st.step(0.1)
	_check(st.state == HorrorStalker.SUSPICIOUS, "a noise behind it makes it suspicious (%s)" % st.state)
	s.noise = 0.0
	var t: float = 0.0
	while st.state == HorrorStalker.SUSPICIOUS and t < 3.0:
		st.step(1.0 / 60.0)
		t += 1.0 / 60.0
	_check(st.state == HorrorStalker.CHASE, "it turns to the noise, sees the player and chases (%s after %.2f s)" % [st.state, t])
	_check(t > 0.3, "it turned before seeing (%.2f s)" % t)
	# the player slips away out of sight
	s.pos = Vector3(30, 0, 30)
	t = 0.0
	while st.state == HorrorStalker.CHASE and t < 8.0:
		st.step(1.0 / 60.0)
		t += 1.0 / 60.0
	_check(st.state == HorrorStalker.SEARCH, "loses the player and searches the last known spot (%s)" % st.state)
	_check(st.last_known.distance_to(Vector3(0, 0, 8)) < 2.5, "the last known spot is where it saw the player (%s)" % str(st.last_known))
	t = 0.0
	while st.state == HorrorStalker.SEARCH and t < 20.0:
		st.step(1.0 / 60.0)
		t += 1.0 / 60.0
	_check(st.state == HorrorStalker.PATROL and absf(t - HorrorStalker.SEARCH_S) < 0.2, "back on patrol after a 15 s search (%.2f s, %s)" % [t, st.state])
	var want: Array[String] = ["SUSPICIOUS", "CHASE", "SEARCH", "PATROL"]
	_check(st.state_log == want, "state flow patrol -> suspicious -> chase -> search -> patrol (%s)" % str(st.state_log))
	# patrol actually walks the loop
	var p0: Vector3 = st.global_position
	for i: int in 180:
		st.step(1.0 / 60.0)
	_check(st.global_position.distance_to(p0) > 1.0, "patrol walks")
	_trash.append(st)


# ---------------------------------------------------------------------------
func _catch() -> void:
	var s := HorrorSenses.new()
	var st: HorrorStalker = _make_stalker(Vector3.ZERO, Vector3(0, 0, -1), s)
	var got: Array[int] = [0]
	st.caught_player.connect(func(_x: HorrorStalker) -> void: got[0] += 1)
	s.pos = Vector3(0, 0, 1.5)   # behind, out of sight, silent
	for i: int in 5:
		st.step(1.0 / 60.0)
	_check(got[0] == 0, "no catch at 1.5 m")
	st.los_fn = func(_a: Vector3, _b: Vector3) -> bool: return false
	s.pos = Vector3(0, 0, 1.0)
	st.step(1.0 / 60.0)
	_check(got[0] == 0, "no catch through a wall")
	st.los_fn = func(_a: Vector3, _b: Vector3) -> bool: return true
	s.pos = Vector3(0, 0, 1.1)
	st.step(1.0 / 60.0)
	_check(got[0] == 1 and st.frozen, "catches within 1.2 m, even behind it, then freezes")
	st.step(1.0 / 60.0)
	_check(got[0] == 1, "catches once")
	st.reset_at(Vector3(5, 0, 5))
	_check(not st.frozen and not st.is_catching(), "reset_at unfreezes")
	s.pos = Vector3(5, 0, 6.0)
	s.hidden = true
	st.step(1.0 / 60.0)
	_check(got[0] == 1, "never catches a hidden player it did not see enter")
	_trash.append(st)


# ---------------------------------------------------------------------------
func _scares() -> void:
	var sd := ScareDirector.new()
	sd.auto_clock = false
	root.add_child(sd)
	_check(sd.budget == 2, "default budget of 2 jump scares")
	sd.clock = 0.0
	_check(sd.try_jump_scare(), "first jump scare plays")
	_check(sd.last_scare.get("flash") == true and sd.last_scare.get("screech") == true and sd.played.has("violin_screech"), "full scare: flash and screech")
	sd.clock = 30.0
	_check(not sd.try_jump_scare(), "no second scare 30 s later (60 s gap)")
	sd.clock = 61.0
	_check(sd.try_jump_scare(), "second scare after 60 s")
	sd.clock = 300.0
	_check(not sd.try_jump_scare() and sd.jump_count == 2, "budget spent after 2")
	var before: int = sd.scares_played
	sd.play_catch_scare()
	_check(sd.scares_played == before + 1 and sd.jump_count == 2, "the catch scare plays outside the budget")
	_check(sd.cue_db("heartbeat") == 0.0, "normal: horror cues at full volume")
	sd.set_threat(4.0, false)
	var hd_norm: float = sd.heart_db()
	sd.set_threat(40.0, false)
	_check(sd.heart_db() < -79.0, "no heartbeat far from every stalker")
	sd.set_threat(4.0, true)
	_check(absf(sd.heart_db() - hd_norm - ScareDirector.HIDDEN_DB) < 0.01 and sd.breath_on, "hiding: heartbeat louder, breath on")
	sd.set_threat(4.0, false)
	# flicker (normal: a strobe)
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 2.0
	sd.register_light_groups([{"pos": Vector3.ZERO, "mat": mat, "energy": 2.0}, {"pos": Vector3(100, 0, 0), "mat": StandardMaterial3D.new(), "energy": 1.0}])
	_check(sd.flicker_near(Vector3.ZERO) == 1, "a flicker event hits the groups near the player only")
	var lo: float = 9.0
	for i: int in 120:
		sd._update_flicker(1.0 / 60.0)
		lo = minf(lo, mat.emission_energy_multiplier)
	_check(lo < 0.2 and is_equal_approx(mat.emission_energy_multiplier, 2.0), "normal flicker strobes and restores (min %.2f)" % lo)
	_trash.append(sd)

	var one := ScareDirector.new()
	one.auto_clock = false
	one.budget = 1
	root.add_child(one)
	_check(one.try_jump_scare(), "budget 1: first plays")
	one.clock = 100.0
	_check(not one.try_jump_scare(), "budget 1: no second")
	_trash.append(one)

	var red := ScareDirector.new()
	red.auto_clock = false
	red.reduce_scares = true
	root.add_child(red)
	_check(red.try_jump_scare(), "reduced: the scare still counts")
	_check(red.last_scare.get("soft") == true and red.last_scare.get("flash") == false and red.last_scare.get("screech") == false \
		and red.last_scare.get("shake") == false, "reduced: a soft sting, no flash, no screech, no shake")
	_check(not red.played.has("violin_screech") and not red.played.has("sheep_bleat_distorted"), "reduced: no screech cue played (%s)" % str(red.played))
	_check(red.cue_db("heartbeat") == -6.0 and red.cue_db("whisper_bed") == -6.0 and red.cue_db("bonk") == 0.0, "reduced: horror cues -6 dB, meme cues unchanged")
	red.set_threat(4.0, false)
	_check(absf(red.heart_db() - (hd_norm - 6.0)) < 0.01, "reduced: heartbeat 6 dB quieter (%.1f vs %.1f)" % [red.heart_db(), hd_norm])
	var mat2 := StandardMaterial3D.new()
	mat2.emission_energy_multiplier = 2.0
	red.register_light_groups([{"pos": Vector3.ZERO, "mat": mat2, "energy": 2.0}])
	red.flicker_near(Vector3.ZERO)
	var lo2: float = 9.0
	for i: int in 90:
		red._update_flicker(1.0 / 60.0)
		lo2 = minf(lo2, mat2.emission_energy_multiplier)
	_check(lo2 >= 0.69, "reduced: flicker is a slow dim, never dark (min %.2f)" % lo2)
	_trash.append(red)


# ---------------------------------------------------------------------------
func _floor() -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Floor"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	sb.add_child(cs)
	root.add_child(sb)
	return sb


func _hiding() -> void:
	var floor_body: StaticBody3D = _floor()
	var player := ThirdPersonController.new()
	player.capture_on_click = false
	root.add_child(player)
	player.teleport(Vector3(40, 0, 40), 0.0)
	var fl := HorrorFlashlight.new()
	root.add_child(fl)
	var sd := ScareDirector.new()
	sd.auto_clock = false
	root.add_child(sd)
	var kit := HorrorKit.new()
	root.add_child(kit)
	kit.setup(player, fl, sd, null)
	kit.caught.connect(func(s: HorrorStalker) -> void: _caught_by = s)
	_check(player.collision_layer == HorrorKit.PLAYER_LAYER, "the player moves to its own layer (stalker rays see the world only)")
	await _frames(5)

	# noise radius from the real controller
	player.input_override = Vector2(0, -1)
	player.sprint_override = true
	await _frames(45)
	_check(kit.player_noise() == HorrorKit.NOISE_SPRINT, "sprinting makes 10 m of noise (%.1f, %.2f m/s)" % [kit.player_noise(), player.horizontal_speed])
	player.sprint_override = false
	player.walk_override = true
	await _frames(45)
	_check(kit.player_noise() == HorrorKit.NOISE_WALK, "walking on Ctrl makes 3 m of noise (%.1f, %.2f m/s)" % [kit.player_noise(), player.horizontal_speed])
	player.walk_override = false
	await _frames(45)
	_check(kit.player_noise() == HorrorKit.NOISE_JOG, "jogging makes 6 m of noise (%.1f)" % kit.player_noise())
	player.input_override = Vector2.ZERO
	await _frames(45)
	_check(kit.player_noise() == 0.0, "standing still is silent")
	player.input_override = null

	# hide and exit: a locker at (0, 0, -0.85) opening towards +Z (exit point at the origin)
	var spot: HidingSpot = HidingSpot.make("locker", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.85)))
	root.add_child(spot)
	kit.add_spot(spot)
	player.teleport(Vector3(0.0, 0.0, 0.3), 0.0)
	player.camera.make_current()
	fl.set_on(true)
	await _frames(3)
	_check(spot.exit_point().distance_to(Vector3.ZERO) < 0.01, "locker exit point in front of it (%s)" % str(spot.exit_point()))
	await _frames(8)
	_check(kit.prompt == "[E] Trốn", "prompt [E] Trốn next to a spot (%s)" % kit.prompt)
	_check(kit.interact(), "[E] hides")
	_check(kit.is_hidden() and kit.senses.hidden and not player.visible and player.process_mode == Node.PROCESS_MODE_DISABLED, "the player is hidden")
	_check(root.get_viewport().get_camera_3d() == spot.peek_cam, "the low peek camera is current")
	_check(spot.peek_cam.position.y > 1.4, "locker peek at eye height through the vents")
	_check(not fl.on and not kit.senses.lit, "the flashlight goes off inside")
	_check(sd.breath_on, "breath loop while hidden")
	await _frames(8)
	_check(kit.prompt == "[E] Ra", "prompt [E] Ra while hidden (%s)" % kit.prompt)
	_check(kit.interact(), "[E] leaves")
	await _frames(2)
	_check(not kit.is_hidden() and player.visible and player.process_mode != Node.PROCESS_MODE_DISABLED, "the player is back")
	_check(Vector2(player.global_position.x, player.global_position.z).length() < 0.1, "back at the exit point (%s)" % str(player.global_position))
	_check(root.get_viewport().get_camera_3d() == player.camera and not sd.breath_on, "own camera back, breath off")
	player.teleport(Vector3(0, 0, 5), 0.0)
	await _frames(2)
	_check(not kit.hide_in(spot), "too far from the spot: refused")

	# a stalker that sees the player enter checks the spot; one that does not, walks past
	var g := HorrorNavGraph.new()
	var a0: int = g.add_node(Vector3(8, 0, 0))
	var a1: int = g.add_node(Vector3(0, 0, 0))
	var a2: int = g.add_node(Vector3(-8, 0, 0))
	g.connect_nodes(a0, a1)
	g.connect_nodes(a1, a2)
	var watcher := HorrorStalker.new()
	watcher.build_model = false
	root.add_child(watcher)
	watcher.setup(g, kit.senses, PackedInt32Array(), 0)
	watcher.graph = g
	watcher.global_position = Vector3(0, 0, 8)
	watcher.face(Vector3(0, 0, -1))
	watcher.frozen = true
	var walker := HorrorStalker.new()
	walker.build_model = false
	root.add_child(walker)
	walker.setup(g, kit.senses, PackedInt32Array([a0, a2]), 0)
	walker.global_position = Vector3(8, 0, 0)
	walker.face(Vector3(1, 0, 0))   # facing away from the player
	kit.add_stalker(watcher)
	kit.add_stalker(walker)
	player.teleport(Vector3(0, 0, 0.2), 0.0)
	await _frames(3)
	watcher.frozen = false
	_check(watcher.can_see() and not walker.can_see(), "the watcher sees the player, the walker does not")
	_check(kit.hide_in(spot), "hides in view of the watcher")
	_check(watcher.state == HorrorStalker.CHECK and watcher.check_spot == spot, "the watcher saw the player enter and goes to check (%s)" % watcher.state)
	_check(walker.state != HorrorStalker.CHECK, "the walker did not see it (%s)" % walker.state)
	_caught_by = null
	var n: int = 0
	while _caught_by == null and n < 300:
		await physics_frame
		n += 1
	_check(_caught_by == watcher, "the watcher checks the spot and catches the player (%d frames)" % n)
	_check(spot.revealed, "the spot is yanked open")
	_check(walker.frozen, "every stalker freezes on a catch")

	# the walker alone: hide unseen, it patrols right past the spot and never finds the player
	kit.leave_hiding()
	spot.reset_spot()
	kit.stalkers.erase(watcher)
	watcher.queue_free()
	walker.reset_at(Vector3(8, 0, 0))
	walker.face(Vector3(1, 0, 0))
	player.teleport(Vector3(0, 0, 0.2), 0.0)
	await _frames(2)
	_caught_by = null
	_check(kit.hide_in(spot) and walker.state != HorrorStalker.CHECK, "hides unseen")
	var passed: bool = false
	for i: int in 600:
		await physics_frame
		if walker.global_position.distance_to(Vector3.ZERO) < 1.0:
			passed = true
	_check(passed, "the walker passed right by the spot")
	_check(_caught_by == null and walker.state != HorrorStalker.CHECK, "and never checked it (%s)" % walker.state)
	kit.leave_hiding()
	for nd: Node in [walker, kit, sd, fl, player, spot, floor_body]:
		nd.queue_free()
	await _frames(2)
