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

	# Xe máy ngược chiều (làn trái) - nhanh, nguồn near-miss chính.
	# Rải thành CỤM ở 180/320/480/640/900/1250 m để cú "sát nút" đầu tiên tới trước giây 15
	# (trước đây ngẫu nhiên 80..cuối đường nên lần đầu thường ở giây ~57). Xe loop nên nửa sau vẫn có xe.
	# Tránh khúc cua Nguyễn Xiển (250–300 m): cụm 1 kết thúc trước 230 m, cụm 2 bắt đầu sau 380 m
	var cluster_offsets: Array[float] = [150.0, 380.0, 520.0, 680.0, 900.0, 1250.0]
	var cluster_lanes: Array[float] = [-1.5, -3.4, -1.5, -5.2, -1.5, -3.4]
	var spawned: int = 0
	for c: int in range(cluster_offsets.size()):
		var n_in_cluster: int = 3 if c % 2 == 0 else 2
		for k: int in range(n_in_cluster):
			var lane_x: float = cluster_lanes[(c + k) % cluster_lanes.size()]
			var off: float = cluster_offsets[c] + float(k) * randf_range(25.0, 40.0)
			_spawn_moto(track_len, lane_x, -1.0, randf_range(15.0, 19.0), minf(off, track_len - 60.0))
			spawned += 1
	for i: int in range(maxi(0, moto_oncoming_count - spawned)):
		var lane_x: float = [-1.5, -3.4, -5.2][i % 3]
		_spawn_moto(track_len, lane_x, -1.0, randf_range(15.0, 19.0), randf_range(1300.0, track_len - 60.0))

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

	# Xe máy chi tiết (bảng linh kiện dùng chung với bãi xe) + người lái bake 1 mesh (mặt, mũ bảo hiểm, áo, ba lô)
	var shirt_colors: Array[Color] = [Color("#3498DB"), Color("#2ECC71"), Color("#E84393"), Color("#FDCB6E"), Color("#636E72"), Color("#ECF0F1"), Color("#8E44AD")]
	var paint: Color = FPTUCampusBuilder.BIKE_PAINTS[randi() % FPTUCampusBuilder.BIKE_PAINTS.size()]
	PropBuilder.build_scooter(body, Vector3.ZERO, 0.0, paint, {"baked": true, "name": "Scooter"})
	var rider_opts: Dictionary = {"seed": randi(), "helmet_color": [Color("#E74C3C"), Color("#F1C40F"), Color("#FFFFFF"), Color("#0984E3"), Color("#2C3E50")][randi() % 5]}
	if randf() < 0.65:
		rider_opts["shirt_color"] = shirt_colors[randi() % shirt_colors.size()]
		rider_opts["backpack"] = randf() < 0.3
	CharacterBuilder.build_baked_rider(body, Vector3(0.0, 0.32, 0.12), rider_opts)

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
	# Xe buýt chi tiết (PropBuilder, bake 1 mesh); hộp cũ trong TrafficCar.tscn ẩn đi. F-Bus cam FPTU / VinBus xanh lá.
	for n: String in ["BusBodyMesh", "BusRoofMesh"]:
		var mi: MeshInstance3D = bus_node.get_node_or_null(n)
		if mi:
			mi.visible = false
	PropBuilder.build_bus(bus_node, is_fbus, true)
	var lbl := Label3D.new()
	lbl.text = "F-BUS FPTU · ĐH FPT" if is_fbus else "VINBUS · D2 → VINHOMES"
	lbl.font_size = 30
	lbl.outline_size = 8
	lbl.modulate = Color("#FFB74D") if is_fbus else Color("#A5D6A7")
	lbl.position = Vector3(0.0, 2.95, -3.57)
	lbl.rotation_degrees.y = 180.0
	bus_node.add_child(lbl)
	var lbl2 := lbl.duplicate() as Label3D
	lbl2.rotation_degrees.y = 0.0
	lbl2.position.z = 3.57
	bus_node.add_child(lbl2)

func _physics_process(delta: float) -> void:
	for agent: BusAgent in active_buses:
		agent.follower.progress += agent.speed_ms * agent.direction * delta
