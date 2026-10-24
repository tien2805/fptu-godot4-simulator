# File: res://tests/test_hit_reactions.gd
# Headless test of the Phase W hit reactions (spec section 3, W-D3) on the target side, before any weapon exists:
#   A  Pedestrian.take_hit: melee / bullet knock out for 6-10 s, then the person gets up and flees and is never removed;
#      bonk knocks out for the given 4 s; punch stumbles; blast and pellet launch along a ballistic arc and land knocked out
#      (pellet ~4 m knockback); stink pinches the nose then flees; sonic pushes (dance or flee); scare flees; a downed
#      person ignores further hits; a mid-tier (lod_far) pedestrian is promoted first.
#   B  CrowdImpostors.scatter; PedestrianSpawner.spawn_fleer.
#   C  RoamTraffic.hit_vehicle: bullet -> halted, rider hidden, one fleer; blast -> launched, upside down on its roof,
#      smoking; halted / wrecked vehicles are recycled after HALT_RECYCLE_S out of view; stink stop zones stop and release
#      traffic; vehicle_box / vehicles_near.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_hit_reactions.gd
extends SceneTree

const ROAD_Z: float = 500.0
var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var player: CharacterBody3D
var peds: Dictionary = {}
var start_pos: Dictionary = {}
var ko_len: float = 0.0
var ko_up_frame: int = -1
var traffic: RoamTraffic
var fled: Array = []
var c0_pos: Vector3
var max_wreck_y: float = -99.0
var recycled0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true      # the game's default style (vice); --script runs keep the class defaults otherwise
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST HIT REACTIONS ---")
	physics_frame.connect(_on_physics)


func _line(x0: float, x1: float, z: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var x: float = x0
	while x <= x1 + 0.01:
		out.append(Vector2(x, z))
		x += 6.0
	return out


func _stub(at: Vector3) -> CharacterBody3D:
	var s := CharacterBody3D.new()
	s.set_script(load("res://tests/support/stub_mover.gd"))
	s.collision_layer = 0
	root.add_child(s)
	s.global_position = at
	return s


func _ped(key: String, at: Vector3, seed_v: int) -> Pedestrian:
	var p := Pedestrian.new()
	p.setup(PedWalkGraph.from_lines([_line(at.x - 3.0, at.x + 3.0, at.z)]), 0, {"preset": "student", "seed": seed_v})
	p.player = player
	p.mounted_fn = func() -> bool: return false
	p.position = at + Vector3(0.0, 0.05, 0.0)   # before add_child (never enter the tree at the origin)
	root.add_child(p)
	p.state = Pedestrian.State.IDLE
	p.set("_idle_left", 999.0)
	peds[key] = p
	return p


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1400.0, 1.0, 1400.0)
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(0.0, -0.5, 0.0)
		root.add_child(sb)
		player = _stub(Vector3(0.0, 0.0, -60.0))
		var keys: Array[String] = ["ko", "bonk", "punch", "blast", "pellet", "stink", "dance", "push", "scare", "mid"]
		for i: int in keys.size():
			_ped(keys[i], Vector3(12.0 * float(i), 0.0, 0.0), 30 + i)
		phase = "a"
		t0 = frames
		return
	var t: int = frames - t0
	match phase:
		"a":
			_part_a(t)
		"c":
			_part_c(t)


func _part_a(t: int) -> void:
	if t == 5:
		for k: String in peds.keys():
			start_pos[k] = (peds[k] as Pedestrian).global_position
		var ko: Pedestrian = peds["ko"]
		var r: String = ko.take_hit({"kind": "melee", "from": ko.global_position + Vector3(0.0, 0.0, 1.0)})
		ko_len = ko.ko_left
		_check(r == "knocked_out" and ko.state == Pedestrian.State.KNOCKED_OUT and ko.collision_layer == 0 and ko_len >= 6.0 and ko_len <= 10.0,
			"melee knocks out for 6-10 s, not solid meanwhile (%s, %.2f s)" % [r, ko_len])
		_check(ko.take_hit({"kind": "bullet"}) == "none" and ko.is_down(), "a knocked-out person ignores further hits")
		var bonk: Pedestrian = peds["bonk"]
		_check(bonk.take_hit({"kind": "bonk", "from": bonk.global_position + Vector3(0.0, 0.0, 1.0), "ko": 4.0}) == "knocked_out" and is_equal_approx(bonk.ko_left, 4.0), "bonk knocks out for the given 4 s")
		var punch: Pedestrian = peds["punch"]
		_check(punch.take_hit({"kind": "punch", "from": punch.global_position + Vector3(0.0, 0.0, 1.0)}) == "stumble" and punch.state == Pedestrian.State.STUMBLE, "a punch makes the person stumble")
		var blast: Pedestrian = peds["blast"]
		_check(blast.take_hit({"kind": "blast", "from": blast.global_position - Vector3(2.0, 0.0, 0.0), "vel": Vector3(5.0, 9.0, 0.0)}) == "launched" and blast.state == Pedestrian.State.LAUNCHED, "a blast launches")
		var pellet: Pedestrian = peds["pellet"]
		_check(pellet.take_hit({"kind": "pellet", "from": pellet.global_position - Vector3(6.0, 0.0, 0.0), "vel": Vector3(6.667, 6.0, 0.0)}) == "launched", "pellets launch (knockback)")
		var stink: Pedestrian = peds["stink"]
		_check(stink.take_hit({"kind": "stink", "from": stink.global_position + Vector3(1.0, 0.0, 0.0)}) == "stink" and stink.state == Pedestrian.State.STINK, "stink: pinches the nose")
		var dance: Pedestrian = peds["dance"]
		_check(dance.take_hit({"kind": "sonic", "from": dance.global_position + Vector3(0.0, 0.0, 2.0), "dir": Vector3(0.0, 0.0, -1.0), "power": 5.0, "dance": true}) == "dance" and dance.state == Pedestrian.State.DANCE, "sonic with the dance roll: dances")
		var push: Pedestrian = peds["push"]
		_check(push.take_hit({"kind": "sonic", "from": push.global_position + Vector3(0.0, 0.0, 2.0), "dir": Vector3(0.0, 0.0, -1.0), "power": 5.0, "dance": false}) == "pushed" and push.state == Pedestrian.State.FLEE and is_equal_approx(push.flee_left, Pedestrian.FLEE_HIT_TIME), "sonic without the dance roll: pushed, flees 6 s")
		var scare: Pedestrian = peds["scare"]
		_check(scare.take_hit({"kind": "scare", "from": scare.global_position + Vector3(3.0, 0.0, 0.0)}) == "flee" and scare.state == Pedestrian.State.FLEE, "scare: flees")
		var mid: Pedestrian = peds["mid"]
		mid.set_far(true)
		_check(mid.lod_far and mid.collision_layer == 0, "test setup: mid-tier pedestrian")
		_check(mid.take_hit({"kind": "melee"}) == "knocked_out" and not mid.lod_far and mid.state == Pedestrian.State.KNOCKED_OUT, "a mid-tier pedestrian is promoted, then knocked out")
	if t > 5 and ko_up_frame < 0 and (peds["ko"] as Pedestrian).state != Pedestrian.State.KNOCKED_OUT:
		ko_up_frame = t
	var bl: Pedestrian = peds["blast"]
	max_wreck_y = maxf(max_wreck_y, bl.global_position.y - (start_pos.get("blast", bl.global_position) as Vector3).y) if t > 5 else max_wreck_y
	if t == 35:
		_check(max_wreck_y > 0.8, "the launched person flies up (%.2f m)" % max_wreck_y)
		_check((peds["stink"] as Pedestrian).state == Pedestrian.State.STINK and (peds["dance"] as Pedestrian).state == Pedestrian.State.DANCE, "still pinching / dancing after 0.5 s")
		var dz: float = (start_pos["push"] as Vector3).z - (peds["push"] as Pedestrian).global_position.z
		_check(dz > 0.4, "the sonic push moves the person away (%.2f m)" % dz)
	if t == 95:
		var b: Pedestrian = peds["blast"]
		var dx: float = b.global_position.x - (start_pos["blast"] as Vector3).x
		_check(b.state == Pedestrian.State.KNOCKED_OUT and dx > 3.5 and dx < 5.5, "the blast arc lands knocked out ~4.5 m away (%s, %.2f m)" % [b.state, dx])
		var p: Pedestrian = peds["pellet"]
		var dx2: float = p.global_position.x - (start_pos["pellet"] as Vector3).x
		_check(p.state == Pedestrian.State.KNOCKED_OUT and dx2 > 3.0 and dx2 < 5.0, "the shotgun knockback lands ~4 m away (%.2f m)" % dx2)
	if t == 165:
		_check((peds["stink"] as Pedestrian).state == Pedestrian.State.FLEE, "after 2.5 s of stink: flees")
		_check((peds["dance"] as Pedestrian).state == Pedestrian.State.FLEE, "after 2 s of dancing: flees")
	if t == 255:
		_check((peds["bonk"] as Pedestrian).state == Pedestrian.State.FLEE, "the bonked person is up and fleeing after 4 s")
	if t == 5 + int(ko_len * 60.0) + 30:
		var ko: Pedestrian = peds["ko"]
		_check(ko_up_frame > 0 and absf(float(ko_up_frame - 5) / 60.0 - ko_len) < 0.1, "up after its own knock-out time (%.2f vs %.2f s)" % [float(ko_up_frame - 5) / 60.0, ko_len])
		_check(ko.state == Pedestrian.State.FLEE and is_instance_valid(ko) and ko.is_inside_tree(), "gets up and flees, never removed (W-D3)")
		for k: String in peds.keys():
			_check(is_instance_valid(peds[k]) and (peds[k] as Node).is_inside_tree(), "%s is still in the world" % k)
		_part_b()
		_start_c()


func _part_b() -> void:
	var g: PedWalkGraph = PedWalkGraph.from_lines([_line(-60.0, 60.0, 200.0)])
	var imp := CrowdImpostors.new()
	root.add_child(imp)
	imp.setup(g, {"cap": 10, "seed": 3})
	imp.set_physics_process(false)
	var vt: Dictionary = (CrowdImpostors.variants()[0] as Dictionary).duplicate()
	vt["profile"] = "walk"
	var specs: Array = [[0.0, 6.0, -6.0], [6.0, 0.0, 12.0], [40.0, 46.0, 34.0]]   # x, heading node x, previous node x
	for i: int in specs.size():
		var sp: Array = specs[i]
		imp.add({"wid": i + 1, "identity": vt, "node": g.nearest(Vector3(float(sp[1]), 0.0, 200.0), 1.0),
			"prev": g.nearest(Vector3(float(sp[2]), 0.0, 200.0), 1.0), "pos": Vector3(float(sp[0]), 0.0, 200.0), "speed": 1.2})
	var n: int = imp.scatter(Vector3(0.0, 0.0, 200.0), 10.0)
	_check(n == 2, "scatter: the 2 impostors within 10 m flee (got %d)" % n)
	_check(is_equal_approx(float(imp.state_at(0)["speed"]), Pedestrian.FLEE_SPEED) and is_equal_approx(float(imp.state_at(1)["speed"]), Pedestrian.FLEE_SPEED), "scattered impostors run at the flee speed")
	_check(int(imp.state_at(1)["node"]) == g.nearest(Vector3(12.0, 0.0, 200.0), 1.0), "an impostor walking toward the blast turns round")
	_check(is_equal_approx(float(imp.state_at(2)["speed"]), 1.2), "the impostor 40 m away is untouched")
	var spn := PedestrianSpawner.new()     # no setup(): only the graph, the player and the zone variants spawn_fleer needs
	spn.graph = PedWalkGraph.from_lines([_line(-30.0, 30.0, 300.0)])
	spn.player = player
	for vt2: Dictionary in CrowdImpostors.variants():
		(spn._by_zone[int(vt2["zone"])] as Array).append(vt2)
	root.add_child(spn)
	spn.set_physics_process(false)          # after add_child: entering the tree re-enables a script's _physics_process
	spn.set_process(false)
	var f: Pedestrian = spn.spawn_fleer(Vector3(2.0, 0.0, 300.0), Vector3(-6.0, 0.0, 300.0))
	_check(f != null and f.state == Pedestrian.State.FLEE and spn.pedestrians().size() == 1 and is_equal_approx(f.flee_left, Pedestrian.FLEE_HIT_TIME), "spawn_fleer: a new pedestrian runs from the shot")
	_check(spn.spawn_fleer(Vector3(2.0, 0.0, 900.0), Vector3.ZERO) == null, "spawn_fleer: no walk node within 30 m -> null")


func _start_c() -> void:
	var md := MapData.new()
	md.data = {"roads": [{"id": 1, "name": "Đường thử", "class": "primary", "width": 10.5, "lanes": 2, "oneway": false,
		"roundabout": false, "bridge": false, "region": "corridor", "points": [[-100.0, ROAD_Z], [100.0, ROAD_Z]]}]}
	var stub_roam := Node.new()
	stub_roam.set_script(load("res://tests/support/stub_roam.gd"))
	root.add_child(stub_roam)
	traffic = RoamTraffic.new()
	root.add_child(traffic)
	traffic.setup(md, _stub(Vector3(0.0, 0.0, ROAD_Z + 60.0)), {"roam": stub_roam, "kinds": [RoamTraffic.Kind.MOTO, RoamTraffic.Kind.CAR, RoamTraffic.Kind.MOTO], "plot": PackedVector2Array(), "seed": 3})
	traffic.fleer_fn = func(at: Vector3, _from: Vector3) -> Pedestrian:
		fled.append(at)
		return null
	for c: RoamTraffic.Vehicle in traffic.vehicles:
		traffic._park(c)
	var plan: Array = [[0, 60.0, 6.0], [1, 140.0, 0.0], [1, 40.0, 8.0]]   # lane, s, cruise for vehicles 0, 1, 2
	for i: int in 3:
		var c2: RoamTraffic.Vehicle = traffic.vehicles[i]
		traffic._activate(c2, int(plan[i][0]), float(plan[i][1]))
		c2.cruise = float(plan[i][2])
		c2.speed = c2.cruise
	max_wreck_y = -99.0
	phase = "c"
	t0 = frames


func _part_c(t: int) -> void:
	var c0: RoamTraffic.Vehicle = traffic.vehicles[0]
	var c1: RoamTraffic.Vehicle = traffic.vehicles[1]
	var c2: RoamTraffic.Vehicle = traffic.vehicles[2]
	if t == 2:
		c0_pos = c0.body.global_position
		_check(traffic.hit_vehicle(0, "bullet", c0_pos + Vector3(0.0, 0.0, -10.0)) and c0.halted, "a bullet halts the motorbike")
		var rider: Node3D = c0.body.get_node_or_null("Rider") as Node3D
		_check(rider != null and not rider.visible, "its rider is gone from the seat")
		_check(fled.size() == 1 and (fled[0] as Vector3).distance_to(c0_pos) < 2.5, "a fleer jumps off beside it (%s)" % str(fled))
		_check(not traffic.hit_vehicle(0, "bullet", c0_pos) and fled.size() == 1, "a second bullet changes nothing (one rider)")
		var p1: Vector3 = c1.body.global_position
		_check(traffic.hit_vehicle(1, "blast", p1 + Vector3(0.0, 0.0, -3.0)) and c1.wreck_t >= 0.0, "a blast wrecks the car")
		_check(c1.body.get_node_or_null("Smoke") is CPUParticles3D, "the wreck smokes (CPUParticles3D)")
		var bx: Array = traffic.vehicle_box(1)
		_check((bx[1] as Vector3).is_equal_approx(Vector3(0.85, 0.75, 1.95)), "vehicle_box half extents of a car")
		_check(traffic.vehicles_near(p1, 1.0).has(1) and traffic.active_indices().size() == 3, "vehicles_near / active_indices")
		_check(traffic.vehicle_of(c1.body) == 1, "vehicle_of")
	if t > 2:
		max_wreck_y = maxf(max_wreck_y, c1.body.global_position.y)
	if t == 20:
		_check(c0.speed == 0.0 and c0.body.global_position.distance_to(c0_pos) < 0.05, "the halted motorbike stays put")
		_check(max_wreck_y > MapBuilder.ROAD_Y + 1.0, "the wreck is launched (%.2f m)" % max_wreck_y)
	if t == 70:
		var b: Basis = c1.body.global_transform.basis
		_check(b.y.y < -0.9 and absf(c1.body.global_position.y - (MapBuilder.ROAD_Y + 1.5)) < 0.06, "the car lies upside down on its roof (up.y %.2f, y %.2f)" % [b.y.y, c1.body.global_position.y])
		c0.idle_t = RoamTraffic.HALT_RECYCLE_S - 0.05
		c1.idle_t = RoamTraffic.HALT_RECYCLE_S - 0.05
		recycled0 = traffic.recycled
	if t == 76:
		_check(traffic.recycled >= recycled0 + 2, "halted and wrecked vehicles out of view are recycled")
		_check(not c0.halted and c1.wreck_t < 0.0 and c1.body.get_node_or_null("Smoke") == null, "a recycled body is clean again")
		var rider0: Node3D = c0.body.get_node_or_null("Rider") as Node3D
		_check(rider0 != null and rider0.visible, "the recycled motorbike has its rider back")
	if t == 80:
		traffic.add_stop_zone(c2.body.global_position, 6.0, 1.5)
	if t == 160:
		_check(c2.speed < 0.3, "a stink stop zone stops the vehicle inside it (%.2f m/s)" % c2.speed)
	if t == 250:
		_check(traffic.stop_zones.is_empty() and c2.speed > 1.0, "the expired zone releases it (%.2f m/s)" % c2.speed)
		if fails.is_empty():
			print("✅ SUCCESS: HIT REACTIONS (knock-out, launch, stink, dance, flee, promotion, scatter, fleer, halted / flipped vehicles, stop zones)")
			quit(0)
		else:
			print("❌ FAILED: %d issues" % fails.size())
			quit(1)
