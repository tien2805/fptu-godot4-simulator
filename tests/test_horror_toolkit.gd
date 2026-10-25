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
# Horror polish (H-D1 to H-D6):
#   staged catch scares per spot (desk upside down from above, locker slats then the yank, stall over the partition, open
#           lunge), camera-relative, 1.2 s, their stings; the reduced variants (soft sting and a fade, no face, no screech);
#   heartbeat: the BPM curve (70 at 14 m to 160 within 2 m, off beyond), the reduced cap of 110, beats over time, louder
#           near, the screen-edge pulse only while hidden;
#   hold breath: drain and refill, a passing stalker hears unheld breathing and checks the spot, held breath lets it pass,
#           a gasp when the breath runs out and when it is released next to a stalker;
#   SOS: the Morse timing pattern (6.8 s loop), the lights following it in red, the reduced slow pulse;
#   fake-outs: their own budget (2, 20 s apart), the soft sting when reduced;
#   Dolly: her look, speed and the positional hum loop (6 dB quieter when reduced);
#   duck and sting: before every catch / jump scare face the loops, the registered players and the Music bus duck to
#           silence, then the layered sting plays +6 dB on its own limited Sting bus, and the levels come back; reduced:
#           no duck, no boost, the soft sting at the normal level.
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
	_heartbeat()
	_sos()
	_fakeout_budget()
	await _catch_scares()
	_duck_sting()
	await _dolly()
	await _hiding()
	for n: Node in _trash:
		if is_instance_valid(n):
			n.queue_free()
	await _frames(2)
	if fails.is_empty():
		print("✅ SUCCESS: HORROR TOOLKIT (flashlight, senses, states, catch, hiding, scare budget, reduced scares, catch scares per spot, heartbeat, hold breath, SOS, fake-outs, Dolly)")
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
	# searches never stand on a hiding spot's way out
	var nw: int = g.id_of("x7")
	g.set_no_wander(nw)
	_check(g.nodes_within(g.pos(nw), 1.0).has(nw) and not g.nodes_within(g.pos(nw), 1.0, true).has(nw), "no-wander nodes are skipped by searches, kept for routes")
	_check(g.path_ids(g.id_of("x0"), g.id_of("x12")).size() == 13 and g.path_ids(g.id_of("z0"), g.id_of("x0")).size() == 13, "heap Dijkstra finds the shortest node paths")
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
	s.hidden = false
	s.grace = 0.5
	st.step(1.0 / 60.0)
	_check(got[0] == 1, "no catch during the grace after leaving a spot")
	s.grace = 0.0
	st.step(1.0 / 60.0)
	_check(got[0] == 2, "catches once the grace is over")
	_trash.append(st)


# ---------------------------------------------------------------------------
func _scares() -> void:
	var sd := ScareDirector.new()
	sd.auto_clock = false
	root.add_child(sd)
	_check(sd.budget == 2, "default budget of 2 jump scares")
	sd.clock = 0.0
	_check(sd.try_jump_scare(), "first jump scare plays")
	sd.step(ScareDirector.DUCK_S + 0.05)
	_check(sd.last_scare.get("flash") == true and sd.last_scare.get("screech") == true and sd.played.has("violin_screech"), "full scare: flash and screech (after the duck)")
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
	var held_any: bool = false
	for i: int in 600:
		# the player holds the breath while the walker is close (as a player watching through the vents would)
		kit.hold_override = walker.global_position.distance_to(spot.global_position) < HorrorKit.BREATH_HEAR_R + 0.6
		held_any = held_any or kit.breath_held
		await physics_frame
		if walker.global_position.distance_to(Vector3.ZERO) < 1.0:
			passed = true
	kit.hold_override = false
	_check(passed, "the walker passed right by the spot")
	_check(held_any and kit.gasps == 0, "the breath was held while it passed, no gasp (%d)" % kit.gasps)
	_check(_caught_by == null and walker.state != HorrorStalker.CHECK, "and never checked it (%s)" % walker.state)
	kit.leave_hiding()
	_check(absf(kit.senses.grace - HorrorKit.LEAVE_GRACE_S) < 0.05, "leaving a spot gives %.2f s of catch grace" % HorrorKit.LEAVE_GRACE_S)
	await _breath(kit, spot, walker, player)
	await _wall_catch()
	kit.hold_override = null
	for nd: Node in [walker, kit, sd, fl, player, spot, floor_body]:
		nd.queue_free()
	await _frames(2)


## Hold breath (H-D4) with the real kit: unheld breathing heard by a passing stalker (it checks and catches), the 6 s bar,
## a gasp on running out and on releasing next to a stalker.
func _breath(kit: HorrorKit, spot: HidingSpot, walker: HorrorStalker, player: ThirdPersonController) -> void:
	await _frames(50)   # past the catch grace
	# not holding: the walker passing by hears the breathing and checks the spot
	spot.reset_spot()
	walker.reset_at(Vector3(8, 0, 0))
	walker.face(Vector3(1, 0, 0))
	player.teleport(Vector3(0, 0, 0.2), 0.0)
	await _frames(2)
	var heard: Array[HorrorStalker] = []
	var cb := func(s: HorrorStalker) -> void: heard.append(s)
	kit.breath_heard.connect(cb)
	_caught_by = null
	kit.hold_override = false
	_check(kit.hide_in(spot) and walker.state != HorrorStalker.CHECK, "hides unseen again, not holding the breath")
	var n: int = 0
	while _caught_by == null and n < 600:
		await physics_frame
		n += 1
	_check(heard.size() == 1 and heard[0] == walker, "the walker hears the breathing within 3 m (%d)" % heard.size())
	_check(_caught_by == walker and spot.revealed, "it checks the spot and catches the player (%d frames)" % n)
	kit.breath_heard.disconnect(cb)
	kit.leave_hiding()
	spot.reset_spot()
	# the bar: 6 s, drains and refills 1 s per s (direct steps; no stalker near)
	walker.reset_at(Vector3(-8, 0, 0))
	walker.frozen = true
	player.teleport(Vector3(0, 0, 0.2), 0.0)
	await _frames(50)
	kit.breath_left = HorrorKit.BREATH_MAX_S
	_check(kit.hide_in(spot), "hides for the breath bar")
	kit.set_physics_process(false)   # steps by hand below
	kit.hold_override = true
	for i: int in 3:
		kit.update_breath(1.0)
	_check(kit.breath_held and absf(kit.breath_left - (HorrorKit.BREATH_MAX_S - 3.0)) < 0.01, "holding: 3 s used (%.2f)" % kit.breath_left)
	_check(sd_breath_silent(kit), "the breath loop is silent while held")
	kit.hold_override = false
	kit.update_breath(1.0)
	_check(not kit.breath_held and absf(kit.breath_left - (HorrorKit.BREATH_MAX_S - 3.0 + HorrorKit.BREATH_REFILL_PER_S)) < 0.01 and kit.gasps == 0, "released far from any stalker: refills BREATH_REFILL_PER_S per s, no gasp (%.2f)" % kit.breath_left)
	kit.hold_override = true
	for i2: int in int(ceilf(kit.breath_left)) + 1:   # hold until the bar is empty
		kit.update_breath(1.0)
	_check(kit.gasps == 1 and kit.last_gasp == "empty" and not kit.breath_held, "running out of breath is a gasp (%d, %s)" % [kit.gasps, kit.last_gasp])
	_check(kit.scare.played.has("gasp"), "the gasp cue plays")
	kit.update_breath(1.0)
	_check(not kit.breath_held and kit.breath_left > 0.5, "Shift still down after running out: no hold until it is let go")
	kit.hold_override = false
	kit.update_breath(0.1)
	kit.hold_override = true
	kit.update_breath(0.1)
	_check(kit.breath_held, "let go and pressed again: holds")
	# entering with Shift still down (the sprint in): no hold until a fresh press, and a moment before any hearing
	kit.hold_override = false
	kit.leave_hiding()
	spot.reset_spot()
	player.teleport(Vector3(0, 0, 0.2), 0.0)
	kit.breath_left = HorrorKit.BREATH_MAX_S
	kit.hold_override = true
	_check(kit.hide_in(spot), "hides with Shift held")
	for i3: int in 5:
		kit.update_breath(1.0)
	_check(not kit.breath_held and kit.gasps == 1 and is_equal_approx(kit.breath_left, HorrorKit.BREATH_MAX_S), "Shift held from the sprint in: no hold, no drain, no gasp (%.2f)" % kit.breath_left)
	kit.hold_override = false
	kit.update_breath(0.1)
	kit.hold_override = true
	kit.update_breath(0.1)
	_check(kit.breath_held, "a fresh press holds")
	_check(kit._hear_t <= 0.0, "the entry grace")
	# a gasp far away (10 m) is not heard
	walker.reset_at(spot.global_position + Vector3(10.0, 0, 0))
	walker.set_physics_process(false)
	kit.breath_left = 0.05
	kit.update_breath(0.1)
	_check(kit.gasps == 2 and kit.last_gasp == "empty" and walker.state != HorrorStalker.CHECK, "a gasp 10 m from a stalker is not heard (%s)" % walker.state)
	kit.hold_override = false
	kit.update_breath(0.1)
	walker.set_physics_process(true)
	# releasing right next to a stalker: a gasp, it checks the spot
	kit.breath_left = HorrorKit.BREATH_MAX_S
	walker.reset_at(spot.global_position + Vector3(1.5, 0, 0.6))
	walker.set_physics_process(false)
	kit.hold_override = true
	kit.update_breath(0.1)
	kit.hold_override = false
	kit.update_breath(0.1)
	_check(kit.gasps == 3 and kit.last_gasp == "release" and walker.state == HorrorStalker.CHECK and walker.check_spot == spot,
		"releasing within 2 m of a stalker: a gasp and it checks the spot (%s, %s)" % [kit.last_gasp, walker.state])
	walker.set_physics_process(true)
	kit.set_physics_process(true)
	kit.hold_override = false
	kit.leave_hiding()
	spot.reset_spot()
	walker.reset_at(Vector3(8, 0, 0))


func sd_breath_silent(kit: HorrorKit) -> bool:
	return kit.scare.breath_held and kit.scare.breath_on


## Staged catch scares per spot (H-D2) with a test camera turned away from the axes (camera-relative staging).
func _catch_scares() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(200, 1.5, 200)
	cam.rotation = Vector3(-0.1, 0.7, 0.0)
	cam.make_current()
	var sd := ScareDirector.new()
	sd.auto_clock = false
	root.add_child(sd)
	await _frames(1)
	sd.set_process(false)   # stepped by hand
	var beats: Array[String] = []
	sd.catch_beat.connect(func(b: String) -> void: beats.append(b))
	for kind: String in ScareDirector.CATCH_KINDS:
		beats.clear()
		sd.played.clear()
		var rot0: Vector3 = cam.rotation
		var near0: float = cam.near
		sd.play_catch_scare(kind)
		_check(is_equal_approx(cam.near, ScareDirector.CATCH_NEAR), "%s: a close near plane while the face is there" % kind)
		var ls: Dictionary = sd.last_scare
		var cues: Array = ScareDirector.CATCH_CUES[kind]
		_check(ls.get("kind") == "catch" and ls.get("spot") == kind and ls.get("face") == true and ls.get("soft") == false, "%s: a staged face scare (%s)" % [kind, str(ls)])
		_check(ls.get("upside_down") == (kind == "desk"), "%s: upside down only under the desk" % kind)
		_check(not sd.face.visible and sd.is_catch_playing() and beats == ["duck"] and not sd.played.has(String(cues[0])), "%s: the duck first, no face or sting yet" % kind)
		var locs: Array[Vector3] = []
		var tilts: Array[float] = []
		var ups: Array[float] = []
		var t: float = 0.0
		while sd.is_catch_playing() and t < 3.0:
			if sd.catch_t >= 0.0:
				locs.append(cam.global_transform.affine_inverse() * sd.face.global_position)
				tilts.append(cam.rotation.x - rot0.x)
				ups.append((cam.global_transform.basis.inverse() * sd.face.global_transform.basis.y).y)
			sd.step(0.05)
			t += 0.05
		_check(absf(t - ScareDirector.CATCH_S - ScareDirector.DUCK_S) < 0.11, "%s: lasts %.2f s (duck + staged face)" % [kind, t])
		_check(not sd.face.visible and beats.has("face") and beats.back() == "end", "%s: the face goes at the end (%s)" % [kind, str(beats)])
		_check(sd.played.has(String(cues[0])) and sd.played.has(String(cues[1])) and sd.last_sting.get("cues") == cues, "%s: the layered sting %s" % [kind, str(cues)])
		_check(cam.rotation.is_equal_approx(rot0), "%s: the camera's own rotation comes back" % kind)
		var in_front: bool = true
		for v: Vector3 in locs:
			in_front = in_front and v.z < -0.1
		_check(in_front, "%s: the face stays in front of the camera" % kind)
		var mid: Vector3 = locs[locs.size() / 2]
		match kind:
			"desk":
				_check(locs[0].y > 0.4 and absf(mid.y) < 0.12 and ups[locs.size() / 2] < -0.9, "desk: lowers from above into view, upside down (%.2f -> %.2f, up %.2f)" % [locs[0].y, mid.y, ups[locs.size() / 2]])
				_check(beats.has("reveal"), "desk: the spot opens")
			"locker":
				_check(absf(locs[0].z) > 0.45 and absf(mid.z) < 0.36 and beats.has("reveal"), "locker: at the slats, then the yank and it pushes in (%.2f -> %.2f)" % [locs[0].z, mid.z])
			"stall":
				_check(tilts[locs.size() / 2] > 0.6 and locs[0].y < -0.4 and absf(mid.y) < 0.12, "stall: the camera looks up and the face rises over the partition (tilt %.2f, %.2f -> %.2f)" % [tilts[locs.size() / 2], locs[0].y, mid.y])
			"open":
				_check(absf(locs[0].z) > 2.0 and absf(locs[6].z) < 0.45 and not beats.has("reveal"), "open: the face lunges at the camera (%.2f -> %.2f)" % [locs[0].z, locs[6].z])
		var closest: float = INF
		for v2: Vector3 in locs:
			closest = minf(closest, -v2.z)
		_check(closest - 0.2 > ScareDirector.CATCH_NEAR and closest >= 0.3, "%s: the mask front never reaches the near plane (closest %.2f m)" % [kind, closest])
		_check(is_equal_approx(cam.near, near0), "%s: the camera's near plane comes back (%.3f)" % [kind, cam.near])
	sd.play_catch_scare("open", false)
	_check(sd.last_scare.get("who") == "clone" and ((sd.face.get_node("Hood") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.is_equal_approx(ScareDirector.CLONE_HAIR),
		"a clone's catch shows a clone's face (dark hair under the mask)")
	sd.play_catch_scare("open", true)
	_check(sd.last_scare.get("who") == "dolly" and ((sd.face.get_node("Hood") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.is_equal_approx(StoryCast.CREAM),
		"Dolly's catch shows her cream wool hood")
	sd.cancel_catch()
	_trash.append(sd)
	var red := ScareDirector.new()
	red.auto_clock = false
	red.reduce_scares = true
	root.add_child(red)
	await _frames(1)
	red.set_process(false)
	for kind2: String in ScareDirector.CATCH_KINDS:
		red.played.clear()
		red.play_catch_scare(kind2)
		var l2: Dictionary = red.last_scare
		_check(l2.get("soft") == true and l2.get("face") == false and l2.get("screech") == false and l2.get("shake") == false and l2.get("fade") == true,
			"reduced %s: a soft sting and a fade, no face, no screech (%s)" % [kind2, str(l2)])
		for k3: int in 12:
			red.tick_catch(0.05)
		_check(red._veil_a > 0.7 and (red.face == null or not red.face.visible), "reduced %s: fades to dark (%.2f)" % [kind2, red._veil_a])
		for k4: int in 14:
			red.tick_catch(0.05)
		_check(red.played == ["metal_creak"], "reduced %s: only the soft sting (%s)" % [kind2, str(red.played)])
	_trash.append(red)
	cam.queue_free()
	await _frames(1)


## Duck and sting (owner request): the other audio ducks to silence before the face, the sting is +6 dB on the Sting bus.
func _duck_sting() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	var mi: int = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(mi, -3.0)
	var hum := AudioStreamPlayer.new()
	hum.volume_db = -4.0
	root.add_child(hum)
	var sd := ScareDirector.new()
	sd.auto_clock = false
	root.add_child(sd)
	sd.set_process(false)
	sd.register_duck(hum)
	_check(sd.sting_bus() == ScareDirector.STING_BUS and AudioServer.get_bus_index(ScareDirector.STING_BUS) != -1
		and AudioServer.get_bus_effect_count(AudioServer.get_bus_index(ScareDirector.STING_BUS)) >= 1, "sting: its own bus with a limiter")
	sd.play_catch_scare("stall")
	var t: float = 0.0
	var duck_at_sting: float = -1.0
	var hum_at_sting: float = 0.0
	var music_at_sting: float = 0.0
	var sting_t: float = -1.0
	while sd.is_catch_playing() and t < 3.0:
		sd.step(0.02)
		t += 0.02
		if sting_t < 0.0 and not sd.last_sting.is_empty():
			sting_t = t
			duck_at_sting = sd.duck_level
			hum_at_sting = hum.volume_db
			music_at_sting = AudioServer.get_bus_volume_db(mi)
	print("  sting at %.2f s: duck %.2f, hum %.1f dB, music %.1f dB, sting %.1f dB" % [sting_t, duck_at_sting, hum_at_sting, music_at_sting, sd.sting_volume_db(0)])
	_check(sting_t >= ScareDirector.DUCK_S - 0.01, "sting: only after the %.1f s duck (%.2f s)" % [ScareDirector.DUCK_S, sting_t])
	_check(duck_at_sting >= 0.95 and hum_at_sting < -50.0 and music_at_sting < -50.0, "sting: the hum and the music are ducked to silence when it hits")
	_check(absf(sd.sting_volume_db(0) - ScareDirector.STING_BOOST_DB) < 0.01 and float(sd.last_sting["db"]) > 0.0, "sting: +6 dB above the normal SFX level")
	for i: int in 40:
		sd.step(0.02)
	_check(sd.duck_level == 0.0 and is_equal_approx(hum.volume_db, -4.0) and is_equal_approx(AudioServer.get_bus_volume_db(mi), -3.0), "sting: the levels come back after the scare")
	sd.played.clear()
	sd.last_sting = {}
	sd.clock = 0.0
	sd.try_jump_scare()
	sd.step(ScareDirector.DUCK_S * 0.5)
	_check(sd.last_sting.is_empty() and sd.duck_level > 0.3, "jump scare: ducking, nothing seen or heard yet")
	sd.step(ScareDirector.DUCK_S * 0.5 + 0.02)
	_check(sd.last_sting.get("cues") == ScareDirector.JUMP_CUES, "jump scare: the layered sting after the duck")
	for j: int in 80:
		sd.step(0.02)
	_check(sd.duck_level == 0.0 and is_equal_approx(hum.volume_db, -4.0), "jump scare: the levels come back")
	_trash.append(sd)
	var red := ScareDirector.new()
	red.auto_clock = false
	red.reduce_scares = true
	root.add_child(red)
	red.set_process(false)
	red.register_duck(hum)
	var max_duck: float = 0.0
	red.play_catch_scare("stall")
	while red.is_catch_playing():
		red.step(0.02)
		max_duck = maxf(max_duck, red.duck_level)
	red.try_jump_scare()
	red.step(0.5)
	_check(max_duck == 0.0 and red.last_sting.is_empty() and is_equal_approx(hum.volume_db, -4.0) and not red.played.has("violin_screech")
		and red.played.has("metal_creak"), "reduced: no duck, no boost, the soft sting (%s)" % str(red.played))
	_trash.append(red)
	_trash.append(hum)


## Heartbeat (H-D3): the BPM curve, beats over time, louder near, the edge pulse while hidden, the reduced cap.
func _heartbeat() -> void:
	_check(ScareDirector.heart_bpm_for(15.0) == 0.0 and ScareDirector.heart_bpm_for(40.0) == 0.0, "no heartbeat beyond 14 m")
	_check(is_equal_approx(ScareDirector.heart_bpm_for(14.0), 70.0) and is_equal_approx(ScareDirector.heart_bpm_for(8.0), 115.0)
		and is_equal_approx(ScareDirector.heart_bpm_for(2.0), 160.0) and is_equal_approx(ScareDirector.heart_bpm_for(0.5), 160.0),
		"70 BPM at 14 m, 115 at 8 m, 160 within 2 m")
	var mono: bool = true
	var prev: float = 0.0
	for i: int in 25:
		var b: float = ScareDirector.heart_bpm_for(14.0 - 0.5 * i)
		mono = mono and b >= prev
		prev = b
	_check(mono, "the heartbeat speeds up steadily as the hunter nears")
	_check(is_equal_approx(ScareDirector.heart_bpm_for(2.0, true), 110.0) and is_equal_approx(ScareDirector.heart_bpm_for(14.0, true), 70.0), "reduced: capped at 110 BPM")
	var sd := ScareDirector.new()
	sd.auto_clock = false
	root.add_child(sd)
	sd.set_process(false)
	sd.set_threat(14.0, false)
	for i2: int in 600:
		sd.tick_heart(1.0 / 60.0)
	var slow: int = sd.heart_beats
	sd.heart_beats = 0
	sd.set_threat(1.5, false)
	for i3: int in 600:
		sd.tick_heart(1.0 / 60.0)
	var fast: int = sd.heart_beats
	print("  heartbeat: %d beats in 10 s at 14 m, %d within 2 m" % [slow, fast])
	_check(slow >= 11 and slow <= 13 and fast >= 26 and fast <= 28, "beats in 10 s: about 70 BPM far, 160 BPM near (%d, %d)" % [slow, fast])
	sd.set_threat(12.0, false)
	var far_db: float = sd.heart_db()
	sd.set_threat(2.0, false)
	_check(sd.heart_db() > far_db + 15.0, "louder near (%.1f vs %.1f dB)" % [sd.heart_db(), far_db])
	sd.edge_a = 0.0
	for i4: int in 60:
		sd.tick_heart(1.0 / 60.0)
	_check(sd.edge_a == 0.0, "no edge pulse in the open")
	sd.set_threat(3.0, true)
	var peak: float = 0.0
	for i5: int in 60:
		sd.tick_heart(1.0 / 60.0)
		peak = maxf(peak, sd.edge_a)
	_check(peak > 0.3 and peak <= ScareDirector.EDGE_PEAK, "a screen-edge pulse on the beats while hidden (%.2f)" % peak)
	sd.set_threat(30.0, true)
	var b0: int = sd.heart_beats
	for i6: int in 120:
		sd.tick_heart(1.0 / 60.0)
	_check(sd.heart_beats == b0 and sd.heart_db() < -79.0, "silent once the hunter leaves 14 m")
	sd.reduce_scares = true
	sd.set_threat(1.0, true)
	_check(is_equal_approx(sd.heart_bpm, 110.0), "reduced: 110 BPM at most (%.0f)" % sd.heart_bpm)
	_trash.append(sd)


## SOS (H-D5): dot 0.2, dash 0.6, gap 0.2, letter gap 0.6, word gap 1.4, looping; the lights follow in red; reduced pulse.
func _sos() -> void:
	_check(is_equal_approx(SosLights.period(), 6.8), "one SOS loop is 6.8 s (%.2f)" % SosLights.period())
	var ons: int = 0
	var on_time: float = 0.0
	for seg: Array in SosLights.pattern():
		if bool(seg[0]):
			ons += 1
			on_time += float(seg[1])
	_check(ons == 9 and is_equal_approx(on_time, 3.0), "9 flashes: 6 dots and 3 dashes (%d, %.2f s lit)" % [ons, on_time])
	var want: Dictionary = {0.1: true, 0.3: false, 0.5: true, 0.9: true, 1.1: false, 1.5: false, 1.7: true, 2.3: false, 2.5: true,
		3.3: true, 3.9: false, 4.5: true, 4.7: false, 5.3: true, 5.5: false, 6.7: false, 6.85: true, 8.5: true}
	var bad: Array[String] = []
	for tt: float in want.keys():
		if SosLights.is_on_at(tt) != bool(want[tt]):
			bad.append(str(tt))
	_check(bad.is_empty(), "S O S timing: dots, dashes, gaps, the word gap and the loop (wrong at %s)" % str(bad))
	var m1 := StandardMaterial3D.new()
	var m2 := StandardMaterial3D.new()
	var sos := SosLights.new()
	sos.auto_tick = false
	root.add_child(sos)
	sos.start([m1, m2], false)
	_check(m1.emission.is_equal_approx(SosLights.RED) and m2.albedo_color.is_equal_approx(SosLights.RED) and m1.emission_enabled, "the lights turn red")
	var follow: bool = true
	var tt2: float = 0.0
	for i: int in 420:
		sos.tick(1.0 / 60.0)
		tt2 += 1.0 / 60.0
		var on: bool = SosLights.is_on_at(sos.t)
		follow = follow and absf(m1.emission_energy_multiplier - (SosLights.ON_ENERGY if on else SosLights.OFF_ENERGY)) < 0.001
	_check(follow, "the emissive energy follows the pattern frame by frame")
	sos.start([m1], true)
	var lo: float = 99.0
	var jump: float = 0.0
	var last: float = m1.emission_energy_multiplier
	for i2: int in 420:
		sos.tick(1.0 / 60.0)
		lo = minf(lo, m1.emission_energy_multiplier)
		jump = maxf(jump, absf(m1.emission_energy_multiplier - last))
		last = m1.emission_energy_multiplier
	_check(lo >= SosLights.PULSE_LO - 0.001 and jump < 0.05, "reduced: a slow red pulse, never dark, no strobe (min %.2f, step %.3f)" % [lo, jump])
	_trash.append(sos)


## Fake-out budget (H-D6): 2 per run, 20 s apart, outside the jump-scare budget; the soft sting when reduced.
func _fakeout_budget() -> void:
	var sd := ScareDirector.new()
	sd.auto_clock = false
	root.add_child(sd)
	sd.clock = 0.0
	_check(sd.try_fake_out("coat") and sd.fake_count == 1 and sd.jump_count == 0, "a fake-out plays and leaves the jump-scare budget alone")
	sd.clock = 10.0
	_check(not sd.try_fake_out("cat"), "not a second one 10 s later")
	sd.clock = 25.0
	_check(sd.try_fake_out("cat") and sd.fake_count == 2, "the second after 20 s")
	sd.clock = 200.0
	_check(not sd.try_fake_out("coat") and not sd.can_fake_out(), "at most 2 per run")
	_check(sd.fake_sting() == "violin_screech", "a short sting")
	sd.reduce_scares = true
	_check(sd.fake_sting() == "metal_creak", "reduced: a soft sting")
	_trash.append(sd)


## Dolly as a hunter (H-D1): her look, a little faster, the positional hum loop.
func _dolly() -> void:
	var d := HorrorStalker.new()
	d.make_dolly(false)
	d.auto_update = false
	root.add_child(d)
	d.global_position = Vector3(-200, 0, -200)
	_check(d.is_dolly and d.model != null and d.mask != null, "Dolly: a masked body")
	_check((d.look.get("shirt_color") as Color).is_equal_approx(StoryCast.CREAM), "Dolly: the cream cardigan of StoryCast dolly")
	_check(d.model.has_meta("wool_cuff") or not d.model.find_children("WoolCuff", "", true, false).is_empty(), "Dolly: her wool cuff")
	_check(is_equal_approx(d.speed_of(HorrorStalker.CHASE), 4.6 * HorrorStalker.DOLLY_SPEED) and d.speed_of(HorrorStalker.PATROL) > 1.4, "Dolly: a little faster than the clones")
	_check(d.hum is AudioStreamPlayer3D and d.hum.max_distance >= 30.0, "Dolly: a positional hum (%s)" % str(d.hum))
	var n: int = 0
	while (d.hum == null or not d.hum.playing) and n < 600:
		await process_frame
		n += 1
	_check(d.hum.playing and d.hum.stream is AudioStreamWAV and (d.hum.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Dolly: the music-box hum loops (%d frames)" % n)
	d.set_hum(false)
	_check(not d.hum.playing, "the hum stops")
	var r := HorrorStalker.new()
	r.build_model = false
	r.make_dolly(true)
	root.add_child(r)
	_check(is_equal_approx(r.hum.volume_db, d.hum.volume_db - 6.0), "reduced: the hum is 6 dB quieter")
	var c := HorrorStalker.new()
	c.build_model = false
	root.add_child(c)
	_check(not c.is_dolly and c.hum == null and c.speed_of(HorrorStalker.CHASE) == 4.6, "the clones: no hum, the usual speed")
	for x: Node in [d, r, c]:
		_trash.append(x)


## Real physics rays (no los_fn): no catch through a 0.2 m wall, nor from a stalker whose origin is inside the wall.
func _wall_catch() -> void:
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.2, 3.0, 6.0)
	cs.shape = bs
	wall.add_child(cs)
	wall.position = Vector3(50.0, 1.5, 0.0)
	root.add_child(wall)
	await _frames(2)
	var s := HorrorSenses.new()
	var st := HorrorStalker.new()
	st.build_model = false
	st.auto_update = false
	root.add_child(st)
	st.senses = s
	var got: Array[int] = [0]
	st.caught_player.connect(func(_x: HorrorStalker) -> void: got[0] += 1)
	st.global_position = Vector3(49.4, 0, 0)
	st.face(Vector3(1, 0, 0))
	s.pos = Vector3(50.5, 0, 0)
	st.step(1.0 / 60.0)
	_check(got[0] == 0 and not st.can_see(), "real ray: no sight or catch through a wall at 1.1 m")
	st.global_position = Vector3(50.0, 0, 0)
	s.pos = Vector3(50.9, 0, 0)
	st.step(1.0 / 60.0)
	_check(got[0] == 0, "real ray: no catch from a stalker standing inside the wall")
	st.global_position = Vector3(50.6, 0, 0)
	s.pos = Vector3(51.5, 0, 0)
	st.step(1.0 / 60.0)
	_check(got[0] == 1, "real ray: catches on the same side of the wall")
	st.queue_free()
	wall.queue_free()
	await _frames(1)
