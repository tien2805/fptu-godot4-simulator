# File: res://tests/support/mayhem_world.gd
# Small headless arena for the Phase W tests (no FreeRoam): a floor box, walls, a real ThirdPersonController (camera,
# pitch 0), standing Pedestrians on a two-node walk graph, a WeaponDirector with a manual WeaponWheel and a WeaponHUD, and
# (Task 4) a RoamTraffic on one straight synthetic road. All static; call from the first physics frame (nodes need the tree).
extends RefCounted


static func floor_box(parent: Node, size: float = 400.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Floor"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size, 1.0, size)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0.0, -0.5, 0.0)
	parent.add_child(sb)
	return sb


static func wall(parent: Node, center: Vector3, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Wall"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = center
	parent.add_child(sb)
	return sb


static func player(parent: Node, at: Vector3, yaw: float = 0.0) -> ThirdPersonController:
	var p := ThirdPersonController.new()
	p.name = "Player"
	p.capture_on_click = false
	parent.add_child(p)
	p.teleport(at, yaw)
	p.pitch = 0.0
	p._update_camera(true)
	p.camera.make_current()
	return p


## A pedestrian standing still (IDLE for 999 s) at `at` on its own two-node walk graph.
static func ped(parent: Node, at: Vector3, seed_v: int, player_node: Node3D) -> Pedestrian:
	var g: PedWalkGraph = PedWalkGraph.from_lines([PackedVector2Array([Vector2(at.x - 3.0, at.z), Vector2(at.x + 3.0, at.z)])])
	var p := Pedestrian.new()
	p.setup(g, 0, {"preset": "student", "seed": seed_v})
	p.player = player_node
	p.mounted_fn = func() -> bool: return false
	p.position = at + Vector3(0.0, 0.05, 0.0)   # before add_child: a body entering the tree at the origin would lift the
	parent.add_child(p)                          # player standing there onto its capsule (then carry him like a platform)
	p.state = Pedestrian.State.IDLE
	p.set("_idle_left", 999.0)
	return p


## A WeaponDirector on `player_node` hitting the nodes in `targets` (the Array is read on every query: append to it later).
static func director(parent: Node, player_node: ThirdPersonController, targets: Array, traffic: RoamTraffic = null) -> WeaponDirector:
	var wheel := WeaponWheel.new()
	wheel.name = "WeaponWheel"
	wheel.manual = true
	parent.add_child(wheel)
	var hud := WeaponHUD.new()
	hud.name = "WeaponHUD"
	parent.add_child(hud)
	var d := WeaponDirector.new()
	d.name = "Weapons"
	parent.add_child(d)
	d.setup({"player": player_node, "wheel": wheel, "hud": hud, "targets_fn": func() -> Array: return targets, "traffic": traffic})
	d.spread_scale = 0.0
	return d


## A RoamTraffic with two vehicles (motorbike 0, car 1) on one straight two-way 10.5 m road 200 m along X at z. Both start
## parked; place them with place_vehicle (then none is left parked, so the traffic spawns nothing on its own).
## The node sits 100 m below the arena: RoamTraffic adds each vehicle body at the node's origin before parking it (the
## physics step then sweeps it away as a kinematic move), which would shove a player standing at the arena origin.
## Vehicles are placed in global coordinates, so the offset changes nothing else.
static func traffic(parent: Node, player_node: Node3D, z: float) -> RoamTraffic:
	var md := MapData.new()
	md.data = {"roads": [{"id": 1, "name": "Đường thử", "class": "primary", "width": 10.5, "lanes": 2, "oneway": false,
		"roundabout": false, "bridge": false, "region": "corridor", "points": [[-100.0, z], [100.0, z]]}]}
	var stub := Node.new()
	stub.name = "StubRoam"
	stub.set_script(load("res://tests/support/stub_roam.gd"))
	parent.add_child(stub)
	var t := RoamTraffic.new()
	t.name = "Traffic"
	t.position = Vector3(0.0, -100.0, 0.0)
	parent.add_child(t)
	t.setup(md, player_node, {"roam": stub, "kinds": [RoamTraffic.Kind.MOTO, RoamTraffic.Kind.CAR], "plot": PackedVector2Array(), "seed": 5})
	for c: RoamTraffic.Vehicle in t.vehicles:
		t._park(c)
	return t


## Put vehicle idx on lane 0 at world x and hold it there (cruise 0). Returns its ground position.
static func place_vehicle(t: RoamTraffic, idx: int, x: float) -> Vector3:
	var c: RoamTraffic.Vehicle = t.vehicles[idx]
	var pts: PackedVector2Array = t.lane_pts[0]
	var s: float = clampf(absf(x - pts[0].x), 1.0, t.lane_len[0] - 2.0)
	t._activate(c, 0, s)
	c.cruise = 0.0
	c.speed = 0.0
	return Vector3(c.pos.x, MapBuilder.ROAD_Y, c.pos.y)
