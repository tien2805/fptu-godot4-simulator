# File: res://scripts/TrafficSpawner.gd
# Luồng giao thông trên cung đường: xe buýt F-Bus / VinBus để núp gió (cùng chiều),
# xe máy ngược chiều để lách sát ăn giây thưởng (near-miss), vài xe máy chậm cùng chiều để vượt.
# Tuyến thật (Task 6): làn xe tính bằng mét từ tim đường nhưng được KẸP vào lòng đường thật của đoạn đang đi
# (RoadManager.half_width_at: đường nội khu 6 m -> ±2,4 m; Nguyễn Xiển 8 m -> ±3,4; D1 10,5 m -> ±4,65);
# xe ngược chiều không xuất hiện trên các đoạn một chiều (RoadManager.oneway_ranges: vòng xoay nhỏ Vinhomes,
# đầu Cầu Vồng 5, nhánh vòng xoay D2B-D1 và Đường D1) – tới đầu đoạn một chiều thì nhảy về trước đoạn đó.
class_name TrafficSpawner
extends Node3D

@export var road_path: Path3D
@export var traffic_car_scene: PackedScene
@export var bus_count: int = 8
@export var moto_oncoming_count: int = 16
@export var moto_slow_count: int = 4
## Hệ số mật độ chung (0.7 = thưa hơn 30 %) – áp cho cả ba loại xe.
@export var density: float = 1.0

const NPC_EDGE_MARGIN: float = 0.6
## Cụm xe máy ngược chiều (offset m, 2 xe/cụm): 4 cụm trên đường nội khu/Hải Đăng để cú sát nút đầu tới sớm,
## còn lại trên Cầu Vồng 5 và Nguyễn Văn Tăng (đường thẳng dài). Xe loop nên nửa sau vẫn có xe.
const CLUSTER_OFFSETS: Array[float] = [130.0, 300.0, 460.0, 620.0, 1750.0, 2050.0, 3100.0, 3500.0]
const CLUSTER_LANES: Array[float] = [-1.5, -3.4, -1.5, -2.6, -1.5, -3.4, -1.5, -2.6]

class BusAgent:
	var follower: PathFollow3D
	var body: StaticBody3D
	var speed_ms: float
	var lane_offset: float # làn theo mét từ tim đường (kẹp vào lòng đường thật mỗi frame)
	var direction: float # 1.0: Cùng chiều (cho phép Núp gió), -1.0: Ngược chiều

var active_buses: Array[BusAgent] = []
var road_manager: Node = null
var oneway: Array[Vector2] = []
var track_len: float = 1.0

func _ready() -> void:
	call_deferred("_spawn_initial_traffic")

func _find_manager() -> Node:
	var n: Node = road_path.get_parent() if road_path else null
	while n:
		if n.has_method("half_width_at"):
			return n
		n = n.get_parent()
	return null

## Nửa bề rộng lòng đường thật tại offset (7 m nếu không có RoadManager, như đường cũ 14 m).
func _hw(offset: float) -> float:
	if road_manager:
		return float(road_manager.call("half_width_at", offset))
	return 7.0

## Làn (m, âm = bên trái) kẹp vào lòng đường thật tại offset.
func _lane(lane_m: float, offset: float) -> float:
	var lim: float = maxf(0.5, _hw(offset) - NPC_EDGE_MARGIN)
	return clampf(lane_m, -lim, lim)

func _spawn_initial_traffic() -> void:
	if not road_path or not road_path.curve:
		return
	road_manager = _find_manager()
	if road_manager and road_manager.has_method("oneway_ranges"):
		oneway = road_manager.call("oneway_ranges")
	track_len = road_path.curve.get_baked_length()
	var lanes: Array[float] = [-3.6, -1.6, 1.6, 3.6]
	var n_bus: int = maxi(1, roundi(float(bus_count) * density))
	var n_oncoming: int = maxi(0, roundi(float(moto_oncoming_count) * density))
	var n_slow: int = maxi(0, roundi(float(moto_slow_count) * density))
	var bus_stop: float = -1.0
	if road_manager:
		var marks: Variant = road_manager.get("route_marks")
		if marks is Dictionary:
			bus_stop = float((marks as Dictionary).get("bus_stop", -1.0))
	var stop_bus_done: bool = false

	for i: int in range(n_bus):
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

		var progress: float = (track_len / float(n_bus)) * float(i) + 45.0
		if agent.direction > 0.0 and not stop_bus_done and bus_stop >= 0.0:
			# VinBus vừa rời trạm gần xuất phát: người chơi bắt kịp để núp gió ngay đoạn đầu
			progress = bus_stop - 8.0
			stop_bus_done = true
		follower.progress = progress
		follower.h_offset = _lane(lane_x, progress)
		if agent.direction < 0.0:
			bus_node.rotation_degrees.y = 180.0

		active_buses.append(agent)

	# Xe máy ngược chiều (làn trái) - nhanh, nguồn near-miss chính. Rải thành cụm (CLUSTER_OFFSETS).
	var spawned: int = 0
	for c: int in range(CLUSTER_OFFSETS.size()):
		if spawned >= n_oncoming:
			break
		for k: int in range(2):
			if spawned >= n_oncoming:
				break
			var lane_x: float = CLUSTER_LANES[(c + k) % CLUSTER_LANES.size()]
			var off: float = CLUSTER_OFFSETS[c] + float(k) * randf_range(25.0, 40.0)
			_spawn_moto(lane_x, -1.0, randf_range(15.0, 19.0), minf(off, track_len - 60.0))
			spawned += 1
	for i: int in range(maxi(0, n_oncoming - spawned)):
		var lane_x: float = [-1.5, -3.4, -2.6][i % 3]
		_spawn_moto(lane_x, -1.0, randf_range(15.0, 19.0), randf_range(1300.0, track_len - 60.0))

	# Xe máy chậm cùng chiều (làn ngoài cùng bên phải) - phải vượt
	for i: int in range(n_slow):
		_spawn_moto(5.3, 1.0, randf_range(9.0, 11.5), 120.0 + float(i) * (track_len / float(n_slow + 1)))

func _spawn_moto(lane_x: float, direction: float, speed: float, start_progress: float) -> void:
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
	follower.progress = start_progress
	follower.h_offset = _lane(lane_x, start_progress)
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

## Xe ngược chiều đi vào đoạn một chiều -> nhảy về ngay trước đầu đoạn (đoạn cuối tuyến thì vòng về cuối curve).
func _skip_oneway(progress: float) -> float:
	for r: Vector2 in oneway:
		if progress > r.x and progress < r.y:
			var p: float = r.x - 1.0
			return p if p > 0.0 else track_len - 1.0
	return progress

func _physics_process(delta: float) -> void:
	for agent: BusAgent in active_buses:
		var p: float = agent.follower.progress + agent.speed_ms * agent.direction * delta
		if agent.direction < 0.0 and not oneway.is_empty():
			p = _skip_oneway(fposmod(p, track_len))
		agent.follower.progress = p
		agent.follower.h_offset = _lane(agent.lane_offset, agent.follower.progress)
