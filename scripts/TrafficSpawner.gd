# File: res://scripts/TrafficSpawner.gd
# Luồng giao thông trên cung đường: xe buýt F-Bus / VinBus để núp gió (cùng chiều),
# xe máy ngược chiều để lách sát ăn giây thưởng (near-miss), vài xe máy chậm cùng chiều để vượt.
class_name TrafficSpawner
extends Node3D

@export var road_path: Path3D
@export var traffic_car_scene: PackedScene
@export var bus_count: int = 8
@export var moto_oncoming_count: int = 9
@export var moto_slow_count: int = 4

class BusAgent:
	var follower: PathFollow3D
	var body: StaticBody3D
	var speed_ms: float
	var lane_offset: float
	var direction: float # 1.0: Cùng chiều (cho phép Núp gió), -1.0: Ngược chiều

var active_buses: Array[BusAgent] = []

func _ready() -> void:
	call_deferred("_spawn_initial_traffic")

func _spawn_initial_traffic() -> void:
	if not road_path or not road_path.curve:
		return
	var track_len: float = road_path.curve.get_baked_length()
	var lanes: Array[float] = [-3.6, -1.6, 1.6, 3.6]

	for i: int in range(bus_count):
		var follower := PathFollow3D.new()
		follower.rotation_mode = PathFollow3D.ROTATION_ORIENTED
		follower.loop = true
		road_path.add_child(follower)

		var bus_node: StaticBody3D = traffic_car_scene.instantiate() as StaticBody3D
		var is_fbus: bool = (i % 2 == 0)
		_PaintBusColor(bus_node, is_fbus)
		PlayerBike.attach_near_miss_tag(bus_node, Vector3(2.5, 2.8, 7.5), 1.5)
		follower.add_child(bus_node)

		var agent := BusAgent.new()
		agent.follower = follower
		agent.body = bus_node
		var lane_x: float = lanes[i % lanes.size()]
		agent.lane_offset = lane_x
		agent.direction = 1.0 if lane_x > 0.0 else -1.0
		agent.speed_ms = 14.5 if is_fbus else 13.0

		follower.h_offset = lane_x
		follower.progress = (track_len / float(bus_count)) * float(i) + 45.0
		if agent.direction < 0.0:
			bus_node.rotation_degrees.y = 180.0

		active_buses.append(agent)

	# Xe máy ngược chiều (làn trái) - nhanh, nguồn near-miss chính
	for i: int in range(moto_oncoming_count):
		var lane_x: float = [-1.5, -3.4, -5.2][i % 3]
		_spawn_moto(track_len, lane_x, -1.0, randf_range(15.0, 19.0), randf_range(80.0, track_len - 60.0))

	# Xe máy chậm cùng chiều (làn ngoài cùng bên phải) - phải vượt
	for i: int in range(moto_slow_count):
		_spawn_moto(track_len, 5.3, 1.0, randf_range(9.0, 11.5), 120.0 + float(i) * (track_len / float(moto_slow_count + 1)))

func _spawn_moto(track_len: float, lane_x: float, direction: float, speed: float, start_progress: float) -> void:
	var follower := PathFollow3D.new()
	follower.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	follower.loop = true
	road_path.add_child(follower)

	var body := StaticBody3D.new()
	body.add_to_group("traffic_obstacle")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.3, 1.9)
	cs.shape = box
	cs.position = Vector3(0.0, 0.65, 0.0)
	body.add_child(cs)
	PlayerBike.attach_near_miss_tag(body, Vector3(0.7, 1.3, 1.9), 0.65)

	var shirt_colors: Array[Color] = [Color("#F37021"), Color("#3498DB"), Color("#2ECC71"), Color("#E84393"), Color("#FDCB6E"), Color("#636E72")]
	var bike_colors: Array[Color] = [Color("#C0392B"), Color("#2C3E50"), Color("#7F8C8D"), Color("#8E44AD"), Color("#16A085")]

	var mat_bike := StandardMaterial3D.new()
	mat_bike.albedo_color = bike_colors[randi() % bike_colors.size()]
	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.38, 0.44, 1.55)
	chassis.mesh = cm
	chassis.material_override = mat_bike
	chassis.position = Vector3(0.0, 0.52, 0.0)
	body.add_child(chassis)

	var mat_tire := StandardMaterial3D.new()
	mat_tire.albedo_color = Color("#111418")
	for z: float in [-0.62, 0.62]:
		var w := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.32
		wm.bottom_radius = 0.32
		wm.height = 0.16
		w.mesh = wm
		w.material_override = mat_tire
		w.rotation_degrees = Vector3(0, 0, 90)
		w.position = Vector3(0.0, 0.32, z)
		body.add_child(w)

	var mat_shirt := StandardMaterial3D.new()
	mat_shirt.albedo_color = shirt_colors[randi() % shirt_colors.size()]
	var rider := MeshInstance3D.new()
	var rm := CapsuleMesh.new()
	rm.radius = 0.19
	rm.height = 0.62
	rider.mesh = rm
	rider.material_override = mat_shirt
	rider.position = Vector3(0.0, 1.12, 0.15)
	rider.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	body.add_child(rider)

	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.34
	helmet.mesh = hm
	var mat_helmet := StandardMaterial3D.new()
	mat_helmet.albedo_color = [Color("#E74C3C"), Color("#F1C40F"), Color("#FFFFFF"), Color("#0984E3")][randi() % 4]
	helmet.material_override = mat_helmet
	helmet.position = Vector3(0.0, 1.55, 0.0)
	body.add_child(helmet)

	var head_lamp := MeshInstance3D.new()
	var hlm := SphereMesh.new()
	hlm.radius = 0.09
	hlm.height = 0.18
	head_lamp.mesh = hlm
	var mat_hl := StandardMaterial3D.new()
	mat_hl.albedo_color = Color("#FFF9C4")
	mat_hl.emission_enabled = true
	mat_hl.emission = Color("#FFF9C4") * 1.6
	head_lamp.material_override = mat_hl
	head_lamp.position = Vector3(0.0, 0.8, -0.78)
	body.add_child(head_lamp)

	follower.add_child(body)
	follower.h_offset = lane_x
	follower.progress = start_progress
	if direction < 0.0:
		body.rotation_degrees.y = 180.0

	var agent := BusAgent.new()
	agent.follower = follower
	agent.body = body
	agent.lane_offset = lane_x
	agent.direction = direction
	agent.speed_ms = speed
	active_buses.append(agent)

func _PaintBusColor(bus_node: StaticBody3D, is_fbus: bool) -> void:
	var mesh_inst: MeshInstance3D = bus_node.get_node_or_null("BusBodyMesh")
	if mesh_inst:
		var mat := StandardMaterial3D.new()
		# F-Bus màu Cam FPTU (#F37021), VinBus màu Xanh lá (#00A859)
		mat.albedo_color = Color("#F37021") if is_fbus else Color("#00A859")
		mat.roughness = 0.45
		mesh_inst.material_override = mat
	var lbl := Label3D.new()
	lbl.text = "F-BUS FPTU" if is_fbus else "VINBUS"
	lbl.font_size = 40
	lbl.outline_size = 10
	lbl.modulate = Color.WHITE
	lbl.position = Vector3(0.0, 2.2, 3.85)
	bus_node.add_child(lbl)
	var lbl2 := lbl.duplicate() as Label3D
	lbl2.rotation_degrees.y = 180.0
	lbl2.position.z = -3.85
	bus_node.add_child(lbl2)

func _physics_process(delta: float) -> void:
	for agent: BusAgent in active_buses:
		agent.follower.progress += agent.speed_ms * agent.direction * delta
