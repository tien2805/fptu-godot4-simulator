# File: res://tests/test_night_building.gd
# Headless test of the Night Building level (spec B-D4, B-D12):
#   build: 6 classrooms, 2 toilet blocks, the generator room, the lobby, 3 locker banks; locker / stall / desk spots;
#          6 fuse candidates (one per classroom) with 3 active, 3 batteries, 4 masked stalkers patrolling; the flashlight is
#          the only light node; plain HUD and sign text (no emoji or decorative symbols); the [E] Trốn prompt at a locker;
#   random but reachable: other seeds pick other fuse sets; every candidate, battery, the fuse box and every hiding spot is
#          on the waypoint graph from the start, with clear rays and room for the player to stand; every graph edge is clear;
#   doors: the locked glass doors stop the player;
#   fuses: pick up, place at the box -> fuse_placed(n) and checkpoint; a catch -> caught; retry_from_checkpoint puts the
#          player at the box, carried fuses back on their spots, placed ones stay, stalkers away from the checkpoint;
#          3 fuses unlock the doors; walking out emits escaped(caught_count);
#   also: battery pickup and its restore on retry, the 25 % battery floor, a catch while hidden then retry, retry ignored
#          after the escape, a clean run emitting escaped(0), release(), caught_count kept across a rebuild, route cost.
# Horror polish (H-D1 to H-D6): one of the four stalkers is Dolly (her look, faster, the hum playing and stopping at the
#          end); the staged catch scare per spot (open, locker) with the caught card after it and the peek overlay cleared;
#          the breath bar while hidden; the third fuse: alarm flag and signal, the corridor lights handed to the SOS lights
#          (red), the siren, every stalker rushing the player; 1-2 seeded fake-outs (both kinds over the seeds); the coat
#          only when the flashlight catches it (sting, then the line), the cat's noise heard within 18 m, the fake-out
#          budget and gap; a reduced-scares level (quiet hum, slow SOS pulse, a soft catch without a face).
# Run:  godot --headless --path . --script tests/test_night_building.gd
extends SceneTree

var fails: Array[String] = []
var placed_log: Array[int] = []
var checkpoints: int = 0
var caught_n: int = 0
var escaped_with: int = -1
var alarms: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST NIGHT BUILDING ---")
	_run()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	await process_frame
	var t0: int = Time.get_ticks_msec()
	var lvl: NightBuilding = (load("res://scenes/story/NightBuilding.tscn") as PackedScene).instantiate()
	lvl.setup({"seed": 7, "auto_retry": false, "capture_mouse": false, "reduce_scares": false})
	root.add_child(lvl)
	await _frames(3)
	print("  built in %.0f ms (level build %.0f ms)" % [float(Time.get_ticks_msec() - t0), lvl.build_ms])
	lvl.fuse_placed.connect(func(n: int) -> void: placed_log.append(n))
	lvl.checkpoint.connect(func() -> void: checkpoints += 1)
	lvl.caught.connect(func() -> void: caught_n += 1)
	lvl.escaped.connect(func(c: int) -> void: escaped_with = c)
	lvl.alarm_started.connect(func() -> void: alarms += 1)
	_build_checks(lvl)
	await _polish_build(lvl)
	for s: HorrorStalker in lvl.stalkers:
		s.frozen = true   # the scripted checks below must not be interrupted by a patrol
	await _prompt_check(lvl)
	await _reachable(lvl)
	await _seeds()
	await _locked_doors(lvl)
	await _fuses(lvl)
	await _escape(lvl)
	lvl.queue_free()
	await _frames(2)
	await _clean_run()
	await _fakeouts()
	await _reduced_level()
	if fails.is_empty():
		print("✅ SUCCESS: NIGHT BUILDING (build, random reachable fuses, fuse box checkpoints, catch and retry, doors, escape, Dolly, catch scares, breath bar, SOS alarm and rush, fake-outs, reduced scares)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


static func _plain(t: String) -> bool:
	for i: int in t.length():
		if t.unicode_at(i) >= 0x2000:
			return false
	return true


func _build_checks(lvl: NightBuilding) -> void:
	_check(lvl.state == "play", "the level is playing (%s)" % lvl.state)
	var kinds: Dictionary = {}
	for r: Dictionary in lvl.map["rooms"]:
		kinds[r["kind"]] = int(kinds.get(r["kind"], 0)) + 1
	_check(kinds.get("classroom") == 6 and kinds.get("toilet") == 2 and kinds.get("generator") == 1 and kinds.get("lobby") == 1,
		"6 classrooms, 2 toilet blocks, the generator room and the lobby (%s)" % str(kinds))
	_check(int(lvl.map["locker_banks"]) == 3, "3 locker banks")
	var sk: Dictionary = {}
	for s: HidingSpot in lvl.kit.spots:
		sk[s.kind] = int(sk.get(s.kind, 0)) + 1
	_check(int(sk.get("locker", 0)) >= 12 and int(sk.get("stall", 0)) == 8 and int(sk.get("desk", 0)) == 6, "locker, stall and under-desk spots (%s)" % str(sk))
	_check(lvl.fuse_candidates.size() == 6, "6 fuse candidates")
	var rooms: Dictionary = {}
	for c: Dictionary in lvl.fuse_candidates:
		rooms[c["room"]] = true
	_check(rooms.size() == 6, "one fuse candidate per classroom")
	var uniq: Dictionary = {}
	for i: int in lvl.active_fuses:
		uniq[i] = true
	_check(lvl.active_fuses.size() == 3 and uniq.size() == 3, "3 distinct active fuse spots (%s)" % str(lvl.active_fuses))
	_check(lvl.batteries.size() == 3, "3 battery pickups")
	_check(lvl.stalkers.size() == 4, "4 stalkers")
	var masked: int = 0
	for s: HorrorStalker in lvl.stalkers:
		if s.model != null and s.mask != null and s.state == HorrorStalker.PATROL:
			masked += 1
	_check(masked == 4, "4 masked clones on patrol (%d)" % masked)
	var s0: HorrorStalker = lvl.stalkers[0]
	var mp: Vector3 = s0.mask.global_position
	var muzzle: Node3D = s0.mask.get_node_or_null("Muzzle")
	var flat: float = Vector2(mp.x - s0.global_position.x, mp.z - s0.global_position.z).length()
	_check(mp.y > s0.global_position.y + 1.35 and mp.y < s0.global_position.y + 1.95 and flat < 0.35, "the sheep mask sits on the head (%.2f m up, %.2f m off)" % [mp.y - s0.global_position.y, flat])
	_check(muzzle != null and (muzzle.global_position - mp).dot(s0.forward()) > 0.02, "the mask faces forward")
	var lights: Array[Node] = lvl.find_children("*", "Light3D", true, false)
	_check(lights.size() == 1 and lights[0] == lvl.flashlight.light, "the flashlight is the only light node (%d)" % lights.size())
	_check(not lvl.find_children("*", "WorldEnvironment", true, false).is_empty(), "night environment")
	_check(lvl.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
	_check(root.get_viewport().get_camera_3d() == lvl.player.camera, "the player's camera is current")
	var bad: Array[String] = []
	for l: Node in lvl.hud.find_children("*", "Label", true, false):
		if not _plain((l as Label).text):
			bad.append((l as Label).text)
	for l3: Node in lvl.find_children("*", "Label3D", true, false):
		if not _plain((l3 as Label3D).text):
			bad.append((l3 as Label3D).text)
	_check(bad.is_empty(), "plain text without emoji or decorative symbols (%s)" % str(bad))
	_check(lvl.hud.fuse_label.text == "Cầu chì: 0/3", "HUD fuses 0/3 (%s)" % lvl.hud.fuse_label.text)
	_check(lvl.hud.hint_label.text.begins_with("[F] Đèn pin"), "HUD hint [F] Đèn pin (%s)" % lvl.hud.hint_label.text)
	_check(lvl.hud.battery_label.text.begins_with("Pin đèn: 100%"), "HUD battery (%s)" % lvl.hud.battery_label.text)


## Dolly among the four, her hum; the fake-outs; no breath bar in the open.
func _polish_build(lvl: NightBuilding) -> void:
	var dollies: int = 0
	for s: HorrorStalker in lvl.stalkers:
		dollies += int(s.is_dolly)
	_check(dollies == 1 and lvl.dolly != null and lvl.dolly.is_dolly and lvl.stalkers.has(lvl.dolly), "one of the four stalkers is Dolly")
	_check(lvl.dolly.mask != null and (lvl.dolly.look.get("shirt_color") as Color).is_equal_approx(StoryCast.CREAM), "Dolly: masked, in her cream cardigan")
	_check(lvl.dolly.speed_of(HorrorStalker.CHASE) > lvl.stalkers[(lvl.stalkers.find(lvl.dolly) + 1) % 4].speed_of(HorrorStalker.CHASE), "Dolly is faster than a clone")
	var n: int = 0
	while not lvl.dolly.hum.playing and n < 600:
		await process_frame
		n += 1
	_check(lvl.dolly.hum.playing and lvl.dolly.hum is AudioStreamPlayer3D, "Dolly hums (positional, %d frames to warm)" % n)
	_check(lvl.fakeouts != null and lvl.fakeouts.items.size() >= 1 and lvl.fakeouts.items.size() <= 2, "1-2 fake-outs placed (%d)" % lvl.fakeouts.items.size())
	_check(not lvl.hud.breath_bar.visible, "no breath bar in the open")
	_check(not lvl.alarm and lvl.sos == null, "no alarm before the fuses")


## The third fuse (H-D5): alarm, SOS lights, siren, the rush.
func _alarm(lvl: NightBuilding) -> void:
	_check(lvl.alarm and alarms == 1, "the third fuse raises the alarm (alarm_started x%d)" % alarms)
	var mats: Array = lvl.map["corridor_lights"]
	_check(mats.size() == 4 and lvl.sos != null and lvl.sos.running and lvl.sos.mats.size() == 4, "the 4 corridor light groups flash SOS")
	var red: bool = true
	for m: StandardMaterial3D in mats:
		red = red and m.emission.is_equal_approx(SosLights.RED)
	_check(red, "the corridor lights are red")
	_check(lvl.scare.light_group_count() == (lvl.map["light_groups"] as Array).size() - 4, "the corridor groups left the flicker (%d)" % lvl.scare.light_group_count())
	var n: int = 0
	while not lvl.siren.playing and n < 600:
		await process_frame
		n += 1
	_check(lvl.siren.playing, "the alarm siren loops")
	var seen_on: bool = false
	var seen_off: bool = false
	for i: int in 160:
		await process_frame
		seen_on = seen_on or (mats[0] as StandardMaterial3D).emission_energy_multiplier > 2.0
		seen_off = seen_off or (mats[0] as StandardMaterial3D).emission_energy_multiplier < 0.2
	_check(seen_on and seen_off, "the corridor flashes on and off")
	lvl.kit.catch_enabled = false
	for s: HorrorStalker in lvl.stalkers:
		s.frozen = false
	var rushing: int = 0
	var w: int = 0
	while rushing < 4 and w < 150:
		await physics_frame
		w += 1
		rushing = 0
		for s2: HorrorStalker in lvl.stalkers:
			if s2.rushing and s2.state == HorrorStalker.CHASE:
				rushing += 1
	_check(rushing == 4, "every stalker rushes the player (%d)" % rushing)
	_check(lvl.stalkers[0].search_s == NightBuilding.ALARM_SEARCH_S, "during the alarm a lost player is searched for only %.0f s" % NightBuilding.ALARM_SEARCH_S)
	# a retry during the alarm: a 3 s head start before they rush again
	lvl.retry_from_checkpoint()
	var early: int = 0
	for i3: int in 150:
		await physics_frame
		for s4: HorrorStalker in lvl.stalkers:
			early += int(s4.rushing)
	var late: int = 0
	var w2: int = 0
	while late < 4 and w2 < 120:
		await physics_frame
		w2 += 1
		late = 0
		for s5: HorrorStalker in lvl.stalkers:
			late += int(s5.rushing)
	_check(early == 0 and late == 4, "retry during the alarm: no rush for 2.5 s, then all rush again after the 3 s head start (%d, %d)" % [early, late])
	for s3: HorrorStalker in lvl.stalkers:
		s3.frozen = true
	lvl.kit.catch_enabled = true


## The fake-outs on a level with both (coat and cat): the coat needs the flashlight, the cat's noise, the budget and gap.
func _fakeouts() -> void:
	var lv: NightBuilding = null
	for sd: int in range(20, 60):
		var t: NightBuilding = (load("res://scenes/story/NightBuilding.tscn") as PackedScene).instantiate()
		t.setup({"seed": sd, "auto_retry": false, "capture_mouse": false, "reduce_scares": false})
		root.add_child(t)
		t.build()
		if t.fakeouts.kinds().size() == 2:
			lv = t
			break
		root.remove_child(t)
		t.queue_free()
	_check(lv != null, "a seed with both fake-outs")
	if lv == null:
		return
	await _frames(3)
	for s: HorrorStalker in lv.stalkers:
		s.frozen = true
	var fo: HorrorFakeouts = lv.fakeouts
	var ci: int = fo.kinds().find("coat")
	var ki: int = fo.kinds().find("cat")
	var coat: Dictionary = fo.items[ci]
	var cat: Dictionary = fo.items[ki]
	# the coat: a test camera 5 m in front of it, looking at its chest
	var cpos: Vector3 = coat["pos"]
	var facing: Vector3 = -(coat["node"] as Node3D).global_transform.basis.z
	var eye: Vector3 = cpos + facing * 5.0 + Vector3(0.0, 1.6, 0.0)
	var cam := Camera3D.new()
	lv.add_child(cam)
	cam.global_position = eye
	cam.look_at(cpos + Vector3(0.0, 1.3, 0.0))
	cam.make_current()
	lv.player.teleport(Vector3(eye.x, 0.0, eye.z), 0.0)
	lv.flashlight.aim = cam
	lv.flashlight.set_on(false)
	await _frames(15)
	_check(not bool(coat["fired"]) and not fo.coat_lit(cpos), "the coat stays a coat in the dark")
	lv.flashlight.battery = 1.0
	lv.flashlight.set_on(true)
	await _frames(15)
	_check(bool(coat["fired"]) and lv.scare.fake_count == 1 and lv.scare.played.has("violin_screech"), "the flashlight catches the coat: a short sting")
	await _frames(70)
	_check(lv.hud.toast_label.text == HorrorFakeouts.COAT_LINE and lv.hud.toast_label.text.contains("cái áo khoác"), "then the line (%s)" % lv.hud.toast_label.text)
	_check(_plain_text(lv.hud.toast_label.text), "the line is plain text")
	# the cat: one stalker 10 m away (hears it), one far (does not)
	var kpos: Vector3 = cat["pos"]
	var near_s: HorrorStalker = lv.stalkers[0]
	var far_s: HorrorStalker = lv.stalkers[1]
	var line: Vector3 = Vector3(kpos.x, 0.0, signf(kpos.z) * NightBuildingMap.CL_Z) if absf(kpos.z) > 17.0 else Vector3(signf(kpos.x) * NightBuildingMap.CL_X, 0.0, kpos.z)
	near_s.reset_at(line + (cat["along"] as Vector3) * -8.0)
	near_s.frozen = true
	far_s.reset_at(Vector3(-kpos.x, 0.0, -kpos.z))
	far_s.frozen = true
	var far_noise: Vector3 = far_s.noise_pos
	lv.player.teleport(kpos + (Vector3(0.0, 0.0, -signf(kpos.z)) if absf(kpos.z) > 17.0 else Vector3(-signf(kpos.x), 0.0, 0.0)) * 1.2 + (cat["along"] as Vector3) * 3.0, 0.0)
	await _frames(15)
	_check(not bool(cat["fired"]), "the cat waits for the 20 s gap after the coat")
	lv.scare.clock += 25.0
	await _frames(15)
	_check(bool(cat["fired"]) and lv.scare.fake_count == 2 and lv.scare.played.has("bin_crash") and lv.scare.played.has("cat_meow"), "the cat knocks the bin over and meows")
	await _frames(6)
	var nd: float = NightBuilding._flat_dist(near_s.global_position, kpos)
	_check(nd > HorrorFakeouts.CAT_NOISE_R or Vector2(near_s.noise_pos.x - kpos.x, near_s.noise_pos.z - kpos.z).length() < 0.01, "a stalker %.1f m away hears the bin" % nd)
	_check(far_s.noise_pos.is_equal_approx(far_noise), "a far stalker does not")
	_check(not lv.scare.can_fake_out(), "the fake-out budget is spent (2 per run)")
	await _frames(130)
	_check(not (cat["cat"] as Node3D).visible, "the cat ran off")
	lv.release()
	lv.queue_free()
	await _frames(2)


static func _plain_text(t: String) -> bool:
	for i: int in t.length():
		if t.unicode_at(i) >= 0x2000:
			return false
	return true


## "Giảm hù dọa" level: a quiet hum, a soft catch without a face, the slow SOS pulse.
func _reduced_level() -> void:
	var lr: NightBuilding = (load("res://scenes/story/NightBuilding.tscn") as PackedScene).instantiate()
	lr.setup({"seed": 9, "auto_retry": false, "capture_mouse": false, "reduce_scares": true})
	root.add_child(lr)
	lr.build()
	await _frames(3)
	for s: HorrorStalker in lr.stalkers:
		s.frozen = true
	_check(lr.dolly != null and lr.dolly.hum_reduced and is_equal_approx(lr.dolly.hum.volume_db, HorrorStalker.HUM_DB - 6.0), "reduced: the hum is 6 dB quieter")
	var hunter: HorrorStalker = lr.stalkers[0]
	var pp: Vector3 = lr.player.global_position
	hunter.reset_at(pp + Vector3(0.0, 0.0, -0.9))
	var n: int = 0
	while lr.state == "play" and n < 60:
		await physics_frame
		n += 1
	_check(lr.state == "caught" and lr.scare.last_scare.get("soft") == true and lr.scare.last_scare.get("face") == false, "reduced: a soft catch, no face")
	lr.retry_from_checkpoint()
	for k: int in 3:
		lr.collect_fuse(k)
	lr.player.teleport(lr.fuse_box["pos"], 0.0)
	lr.place_fuses()
	_check(lr.alarm and lr.sos.reduce_scares, "reduced: the alarm still rings")
	var lo: float = 99.0
	for i: int in 120:
		await process_frame
		lo = minf(lo, (lr.map["corridor_lights"][0] as StandardMaterial3D).emission_energy_multiplier)
	_check(lo >= SosLights.PULSE_LO - 0.01, "reduced: the corridor pulses slowly, never dark (min %.2f)" % lo)
	var w: int = 0
	while not (lr.siren.playing and lr.dolly.hum.playing) and w < 300:
		await process_frame
		w += 1
	_check(lr.siren.playing and lr.dolly.hum.playing, "the siren and the hum play before release()")
	lr.release()
	_check(not lr.siren.playing and not lr.dolly.hum.playing and lr.state == "released", "release() stops the siren and the hum")
	lr.queue_free()
	await _frames(2)


func _prompt_check(lvl: NightBuilding) -> void:
	var spot: HidingSpot = null
	for s: HidingSpot in lvl.kit.spots:
		if s.kind == "locker":
			spot = s
			break
	lvl.player.teleport(spot.exit_point(), spot.exit_yaw())
	await _frames(10)
	_check(lvl.kit.prompt == "[E] Trốn", "[E] Trốn in front of a locker (%s)" % lvl.kit.prompt)
	await _frames(10)
	lvl.flashlight.set_on(true)
	await _frames(8)
	_check(lvl.hud.battery_label.text.find("tắt") == -1, "HUD shows the light on")
	lvl.flashlight.set_on(false)


func _reachable(lvl: NightBuilding) -> void:
	await _frames(2)
	var g: HorrorNavGraph = lvl.graph
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	var start: int = int(lvl.map["start_node"])
	_check(start >= 0, "start node")
	var unreached: int = 0
	for i: int in g.size():
		if not g.reachable(start, i):
			unreached += 1
	_check(unreached == 0, "the waypoint graph is connected (%d nodes, %d unreachable)" % [g.size(), unreached])
	var blocked: Array[String] = []
	for a: int in g.size():
		for b: int in g.adj[a]:
			if b > a and not HorrorNavGraph.clear(space, g.pos(a), g.pos(b)):
				blocked.append("%s-%s" % [str(g.pos(a)), str(g.pos(b))])
	_check(blocked.is_empty(), "every graph edge is a clear walk (%s)" % str(blocked))
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	var free_at := func(p: Vector3) -> bool:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, 0.9, p.z))
		q.collision_mask = 1
		return space.intersect_shape(q, 1).is_empty()
	var items: Array = []
	for c: Dictionary in lvl.fuse_candidates:
		items.append({"what": "fuse " + String(c["room"]), "pos": c["pos"], "reach": c["reach"], "node": c["node"], "r": NightBuildingMap.PICK_R})
	for c2: Dictionary in lvl.map["battery_candidates"]:
		items.append({"what": "battery " + String(c2["room"]), "pos": c2["pos"], "reach": c2["reach"], "node": c2["node"], "r": NightBuildingMap.PICK_R})
	items.append({"what": "fuse box", "pos": lvl.fuse_box["pos"], "reach": lvl.fuse_box["pos"], "node": g.id_of("GEN_box"), "r": NightBuildingMap.FUSE_BOX_R})
	_check(lvl.map["battery_candidates"].size() == 6, "6 battery candidates")
	for it: Dictionary in items:
		var node: int = int(it["node"])
		var reach: Vector3 = it["reach"]
		var ok: bool = node >= 0 and g.reachable(start, node) and HorrorNavGraph.clear(space, g.pos(node), reach) \
			and Vector2(reach.x - (it["pos"] as Vector3).x, reach.z - (it["pos"] as Vector3).z).length() <= float(it["r"]) \
			and bool(free_at.call(reach))
		_check(ok, "%s reachable from the start (node %d, reach %s)" % [it["what"], node, str(reach)])
	var bad_spots: Array[String] = []
	for s: HidingSpot in lvl.kit.spots:
		var e: Vector3 = s.exit_point()
		var n: int = g.nearest(e, space)
		if n < 0 or not g.reachable(start, n) or not HorrorNavGraph.clear(space, g.pos(n), e) or not bool(free_at.call(e)):
			bad_spots.append(s.name)
	_check(bad_spots.is_empty(), "every hiding spot has a free exit point on the graph (%s)" % str(bad_spots))
	var st: Vector3 = (lvl.map["start"] as Dictionary)["pos"]
	_check(bool(free_at.call(st)), "the start is free")
	# routing cost (re-routes happen at most every 0.5 s per stalker; all 4 can coincide at the unlock)
	var t_us: int = Time.get_ticks_usec()
	var nr: int = 0
	for a: int in range(0, g.size(), 4):
		g.route(g.pos(a), g.pos((a * 37 + 11) % g.size()), space)
		nr += 1
	var per: float = float(Time.get_ticks_usec() - t_us) / 1000.0 / float(nr)
	print("  route(): %.3f ms each over %d routes" % [per, nr])
	_check(per < 1.0, "a route costs under 1 ms (%.3f)" % per)


func _seeds() -> void:
	var sets: Dictionary = {}
	var fake_counts: Dictionary = {}
	var fake_kinds: Dictionary = {}
	var dolly_at: Dictionary = {}
	for sd: int in [1, 2, 3, 4, 5, 6]:
		var l2: NightBuilding = (load("res://scenes/story/NightBuilding.tscn") as PackedScene).instantiate()
		l2.setup({"seed": sd, "stalkers": 0, "auto_retry": false, "capture_mouse": false})
		root.add_child(l2)
		l2.build()
		var a: Array = l2.active_fuses.duplicate()
		a.sort()
		sets[str(a)] = true
		fake_counts[l2.fakeouts.items.size()] = true
		for k: String in l2.fakeouts.kinds():
			fake_kinds[k] = true
		root.remove_child(l2)
		l2.queue_free()
		await _frames(1)
	print("  fuse sets over 6 seeds: %s" % str(sets.keys()))
	_check(sets.size() >= 3, "the fuse spots change with the seed (%d different sets)" % sets.size())
	print("  fake-outs over 6 seeds: counts %s, kinds %s" % [str(fake_counts.keys()), str(fake_kinds.keys())])
	_check(fake_counts.has(1) and fake_counts.has(2) and fake_counts.size() == 2, "1 or 2 fake-outs per run, both happen over the seeds (%s)" % str(fake_counts.keys()))
	_check(fake_kinds.has("coat") and fake_kinds.has("cat"), "both fake-out kinds over the seeds (%s)" % str(fake_kinds.keys()))


func _locked_doors(lvl: NightBuilding) -> void:
	await _frames(2)
	var p: ThirdPersonController = lvl.player
	p.teleport(Vector3(0.0, 0.0, 25.0), PI)
	p.yaw = PI
	p.input_override = Vector2(0, -1)
	var max_z: float = 0.0
	for i: int in 120:
		await physics_frame
		max_z = maxf(max_z, p.global_position.z)
	p.input_override = null
	_check(max_z < NightBuildingMap.OUT_Z - 0.3 and lvl.state == "play" and escaped_with == -1, "the locked glass doors stop the player (max z %.2f)" % max_z)


func _goto(lvl: NightBuilding, pos: Vector3) -> void:
	lvl.player.teleport(pos, 0.0)
	await _frames(8)


func _fuses(lvl: NightBuilding) -> void:
	var k0: int = 0
	var c0: Dictionary = lvl.fuse_candidates[lvl.active_fuses[k0]]
	await _goto(lvl, c0["reach"])
	_check(lvl.kit.prompt == "[E] Nhặt cầu chì", "prompt [E] Nhặt cầu chì at a fuse (%s)" % lvl.kit.prompt)
	_check(lvl.interact() and lvl.fuses_carried == 1 and lvl.fuse_state[k0] == "carried", "[E] picks the fuse up")
	_check(not lvl.fuse_items[k0].visible, "the fuse leaves its spot")
	await _goto(lvl, lvl.fuse_box["pos"])
	_check(lvl.kit.prompt == "[E] Lắp cầu chì", "prompt [E] Lắp cầu chì at the box (%s)" % lvl.kit.prompt)
	lvl.flashlight.battery = 0.05   # nearly empty when the checkpoint is saved
	_check(lvl.interact(), "[E] places it")
	_check(lvl.fuses_placed == 1 and lvl.fuses_carried == 0 and placed_log == [1] and checkpoints == 1, "fuse_placed(1) and a checkpoint (%s, %d)" % [str(placed_log), checkpoints])
	_check(lvl.hud.fuse_label.text == "Cầu chì: 1/3", "HUD fuses 1/3")
	_check((lvl.checkpoint_data["pos"] as Vector3).distance_to(lvl.fuse_box["pos"]) < 0.01, "the checkpoint is at the fuse box")
	# a battery picked up after the checkpoint
	var bat: Dictionary = lvl.batteries[0]
	await _goto(lvl, bat["reach"])
	_check(lvl.kit.prompt == "[E] Nhặt pin", "prompt [E] Nhặt pin at a battery (%s)" % lvl.kit.prompt)
	_check(lvl.interact() and bool(bat["taken"]) and not (bat["node"] as Node3D).visible, "[E] picks the battery up")
	_check(absf(lvl.flashlight.battery - 0.65) < 0.01, "a battery adds 60 %% (%.2f)" % lvl.flashlight.battery)
	# carry the second fuse, then get caught
	var c1: Dictionary = lvl.fuse_candidates[lvl.active_fuses[1]]
	await _goto(lvl, c1["reach"])
	lvl.interact()
	_check(lvl.fuses_carried == 1, "carrying the second fuse")
	var hunter: HorrorStalker = lvl.stalkers[0]
	var pp: Vector3 = lvl.player.global_position
	hunter.reset_at(pp + Vector3(0.0, 0.0, -0.9) if pp.z > 0.0 else pp + Vector3(0.0, 0.0, 0.9))
	var n: int = 0
	while lvl.state == "play" and n < 60:
		await physics_frame
		n += 1
	_check(lvl.state == "caught" and caught_n == 1 and lvl.caught_count == 1, "a stalker within 1.2 m catches the player (%s, %d)" % [lvl.state, caught_n])
	_check(lvl.scare.scares_played >= 1 and not lvl.player.controls_enabled, "the catch scare plays and controls lock")
	_check(lvl.scare.last_scare.get("spot") == "open" and lvl.scare.last_scare.get("face") == true and lvl.scare.is_catch_playing(), "caught in the open: the face lunges (%s)" % str(lvl.scare.last_scare.get("spot")))
	_check(not lvl.hud.card_label.visible, "the caught card waits for the scare")
	await _frames(80)
	_check(lvl.hud.card_label.visible and lvl.hud.card_label.text == "BỊ BẮT!" and not lvl.scare.is_catch_playing(), "the caught card after the 1.2 s scare")
	lvl.retry_from_checkpoint()
	await _frames(3)
	_check(lvl.state == "play" and lvl.player.controls_enabled, "retry: playing again")
	_check(lvl.player.global_position.distance_to(lvl.fuse_box["pos"]) < 0.4, "retry: back at the fuse box checkpoint (%s)" % str(lvl.player.global_position))
	_check(lvl.fuses_carried == 0 and lvl.fuse_state[1] == "spot" and lvl.fuse_items[1].visible, "retry: the carried fuse is back on its spot")
	_check(lvl.fuses_placed == 1 and lvl.fuse_state[0] == "placed", "retry: the placed fuse stays")
	_check(absf(lvl.flashlight.battery - NightBuilding.RETRY_MIN_BATTERY) < 0.001, "retry: the charge goes back to the checkpoint's, floored at 25 %% (%.2f)" % lvl.flashlight.battery)
	_check(not bool(lvl.batteries[0]["taken"]) and (lvl.batteries[0]["node"] as Node3D).visible, "retry: the battery picked up after the checkpoint is back on its spot")
	var near: int = 0
	for s: HorrorStalker in lvl.stalkers:
		if s.frozen or s.global_position.distance_to(lvl.fuse_box["pos"]) < 8.0:
			near += 1
	_check(near == 0, "retry: every stalker patrols away from the checkpoint")
	for s2: HorrorStalker in lvl.stalkers:
		s2.frozen = true
	await _hidden_catch(lvl)
	# the other two fuses
	for k: int in [1, 2]:
		await _goto(lvl, (lvl.fuse_candidates[lvl.active_fuses[k]] as Dictionary)["reach"])
		lvl.interact()
	_check(lvl.fuses_carried == 2, "carrying the last two fuses")
	await _goto(lvl, lvl.fuse_box["pos"])
	lvl.interact()
	await _frames(2)
	_check(placed_log == [1, 2, 3] and checkpoints == 3, "fuse_placed 1, 2, 3 and a checkpoint each (%s, %d)" % [str(placed_log), checkpoints])
	_check(lvl.doors_unlocked and ((lvl.map["doors"] as Dictionary)["shape"] as CollisionShape3D).disabled, "3 fuses unlock the lobby doors")
	_check(lvl.hud.fuse_label.text == "Cầu chì: 3/3", "HUD fuses 3/3")
	await _alarm(lvl)


func _escape(lvl: NightBuilding) -> void:
	var p: ThirdPersonController = lvl.player
	p.teleport(Vector3(0.0, 0.0, 24.5), PI)
	p.yaw = PI
	await _frames(100)   # the glass panels slide away
	p.input_override = Vector2(0, -1)
	var n: int = 0
	while escaped_with == -1 and n < 240:
		await physics_frame
		n += 1
	p.input_override = null
	_check(escaped_with == 2 and lvl.state == "escaped", "walking out through the open doors emits escaped(caught_count = 2) (%d, %s)" % [escaped_with, lvl.state])
	_check(not lvl.siren.playing and not lvl.dolly.hum.playing and not lvl.dolly.hum_on, "out: the siren and the hum stop")
	lvl.retry_from_checkpoint()
	_check(lvl.state == "escaped", "retry_from_checkpoint is ignored after the escape")


## Caught while hidden (a stalker saw the player enter a locker), then retry: out of the spot, own camera, spot reset.
func _hidden_catch(lvl: NightBuilding) -> void:
	var spot: HidingSpot = null
	for s: HidingSpot in lvl.kit.spots:
		if s.name == "Hide_locker_0_0":
			spot = s
	var ep: Vector3 = spot.exit_point()
	await _goto(lvl, ep)
	var hunter: HorrorStalker = lvl.stalkers[1]
	hunter.reset_at(Vector3(ep.x, 0.0, ep.z + 6.0))
	hunter.face(Vector3(0, 0, -1))
	await _frames(3)
	_check(lvl.kit.hide_in(spot) and hunter.state == HorrorStalker.CHECK, "hides in view of a stalker, which goes to check (%s)" % hunter.state)
	await _frames(8)
	_check(lvl.hud.breath_bar.visible and lvl.hud.breath_label.visible and lvl.hud.breath_label.text == "Giữ Shift: nín thở", "the breath bar and its plain hint while hidden")
	var n: int = 0
	while lvl.state == "play" and n < 240:
		await physics_frame
		n += 1
	_check(lvl.state == "caught" and lvl.caught_count == 2 and spot.revealed, "caught in the locker (%s, %d)" % [lvl.state, lvl.caught_count])
	_check(lvl.scare.last_scare.get("spot") == "locker" and lvl.hud.peek_kind == "locker", "the locker scare: the face at the slats first")
	await _frames(80)
	_check(lvl.hud.peek_kind == "" and lvl.hud.card_label.visible, "the door yanked: the slats go, then the caught card")
	lvl.retry_from_checkpoint()
	await _frames(3)
	var p: ThirdPersonController = lvl.player
	_check(lvl.state == "play" and not lvl.kit.is_hidden() and p.visible and p.process_mode != Node.PROCESS_MODE_DISABLED, "retry after a hidden catch: the player is out and playing")
	_check(root.get_viewport().get_camera_3d() == p.camera and lvl.hud.peek_kind == "", "retry after a hidden catch: own camera, no peek overlay")
	_check(not spot.occupied and not spot.revealed, "retry after a hidden catch: the spot is closed and free again")
	_check(p.global_position.distance_to(lvl.fuse_box["pos"]) < 0.4, "retry after a hidden catch: at the checkpoint")
	for s2: HorrorStalker in lvl.stalkers:
		s2.frozen = true


## A clean run with stalkers off: 3 fuses, out through the doors -> escaped(0); release() frees the mouse and the camera.
func _clean_run() -> void:
	var l3: NightBuilding = (load("res://scenes/story/NightBuilding.tscn") as PackedScene).instantiate()
	l3.setup({"seed": 5, "stalkers": 0, "auto_retry": false, "capture_mouse": false})
	root.add_child(l3)
	l3.build()
	var esc: Array[int] = [-1]
	l3.escaped.connect(func(c: int) -> void: esc[0] = c)
	await _frames(2)
	for k: int in 3:
		l3.collect_fuse(k)
	l3.player.teleport(l3.fuse_box["pos"], 0.0)
	l3.place_fuses()
	_check(l3.doors_unlocked and l3.fuses_placed == 3, "clean run: 3 fuses unlock the doors")
	await _frames(100)
	l3.player.teleport(Vector3(0.0, 0.0, 24.5), PI)
	l3.player.yaw = PI
	l3.player.input_override = Vector2(0, -1)
	var n: int = 0
	while esc[0] == -1 and n < 240:
		await physics_frame
		n += 1
	_check(esc[0] == 0, "never caught: escaped(0) (%d)" % esc[0])
	l3.release()
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and (cam == null or not l3.is_ancestor_of(cam)), "release() frees the mouse and the level's camera")
	_check(l3.state == "escaped" and not l3.kit.input_enabled, "release() keeps the escaped state and ignores keys")
	# caught_count survives a rebuild (E5 tracking)
	l3.caught_count = 2
	l3.setup({"seed": 6, "stalkers": 0, "auto_retry": false, "capture_mouse": false})
	_check(l3.caught_count == 2 and l3.state == "play", "caught_count survives a setup() rebuild (%d)" % l3.caught_count)
	l3.release()
	_check(l3.state == "released", "release() during play sets released")
	l3.queue_free()
	await _frames(2)
