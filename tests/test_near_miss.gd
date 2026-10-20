# File: res://tests/test_near_miss.gd
# Test vật lý: vùng near-miss (Area3D) của PlayerBike có bắt được xe đứng yên lẫn xe ngược chiều
# đang di chuyển (StaticBody3D đổi transform mỗi frame) khi lách sát mà không va chạm hay không.
# Chạy:  godot --headless --path . --script tests/test_near_miss.gd
extends SceneTree

var bike: CharacterBody3D
var moving: StaticBody3D
var near_hits: int = 0
var crashes: int = 0
var frames: int = 0
var started: bool = false

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var world := Node3D.new()
	root.add_child(world)

	var floor_body := StaticBody3D.new()
	var fc := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(60.0, 1.0, 400.0)
	fc.shape = fb
	floor_body.add_child(fc)
	floor_body.position = Vector3(0.0, -0.5, -150.0)
	world.add_child(floor_body)

	var packed: PackedScene = load("res://scenes/PlayerBike.tscn")
	bike = packed.instantiate()
	world.add_child(bike)
	bike.position = Vector3(0.0, 0.3, 0.0)
	bike.set("lane_clamp_enabled", false)
	bike.connect("near_miss", func(chain: int) -> void:
		near_hits += 1
		print("  near_miss! chain=", chain, " at z=", snappedf(bike.global_position.z, 0.1)))
	bike.connect("crash_occurred", func() -> void: crashes += 1)

	# Xe đứng yên lệch 1.5m bên phải tại z=-40 và bên trái tại z=-70
	for cfg: Array in [[1.5, -40.0], [-1.5, -70.0]]:
		var b := _make_body()
		b.position = Vector3(cfg[0], 0.0, cfg[1])
		world.add_child(b)

	# Xe ngược chiều đang chạy 16 m/s ở làn -1.6, xuất phát z=-160 chạy về +Z
	moving = _make_body()
	moving.position = Vector3(-1.6, 0.0, -160.0)
	world.add_child(moving)

	print("--- TEST NEAR-MISS: Area3D vs StaticBody3D đứng yên & di chuyển ---")
	print("  physics_engine=", ProjectSettings.get_setting("physics/3d/physics_engine", "<default>"),
		" jolt.areas_detect_static_bodies=", ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/areas_detect_static_bodies", "<unset>"))
	started = true

func _make_body() -> StaticBody3D:
	var b := StaticBody3D.new()
	b.add_to_group("traffic_obstacle")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.3, 1.9)
	cs.shape = box
	cs.position = Vector3(0.0, 0.65, 0.0)
	b.add_child(cs)
	# Thẻ near-miss (Area3D) như TrafficSpawner/RoadEvents gắn cho xe NPC
	PlayerBike.attach_near_miss_tag(b, Vector3(0.7, 1.3, 1.9), 0.65)
	return b

func _physics_process_moving(delta: float) -> void:
	if moving:
		moving.position.z += 16.0 * delta

func _process(delta: float) -> bool:
	if not started:
		return false
	frames += 1
	if frames == 2:
		# Chỉ nhấn ga sau khi PlayerBike đã _ready và tạo InputMap "gas"
		Input.action_press("gas")
	_physics_process_moving(delta)
	if frames == 3:
		var area: Area3D = bike.get_node_or_null("NearMissZone")
		print("  area=", area, " monitoring=", area.monitoring if area else null, " layer=", area.collision_layer if area else -1, " mask=", area.collision_mask if area else -1, " shape_count=", area.get_child_count() if area else -1)
		if area:
			area.body_entered.connect(func(b: Node3D) -> void: print("    [area] body_entered: ", b.name, " at bike z=", snappedf(bike.global_position.z, 0.1)))
			area.body_exited.connect(func(b: Node3D) -> void: print("    [area] body_exited: ", b.name, " at bike z=", snappedf(bike.global_position.z, 0.1)))
	if frames % 30 == 0:
		var area: Area3D = bike.get_node_or_null("NearMissZone")
		var overlaps: int = area.get_overlapping_bodies().size() if area else -1
		print("  t=%.1fs z=%.1f speed=%.0f km/h near=%d crashes=%d moving_z=%.1f overlaps=%d" % [frames / 60.0, bike.global_position.z, absf(float(bike.get("current_speed_ms"))) * 3.6, near_hits, crashes, moving.position.z, overlaps])
	if bike.global_position.z < -130.0 or frames > 60 * 14:
		Input.action_release("gas")
		print("  Kết thúc: near_miss=%d, crashes=%d, z=%.1f" % [near_hits, crashes, bike.global_position.z])
		if near_hits >= 3 and crashes == 0:
			print("✅ SUCCESS: near-miss detected for both static and moving traffic without collisions")
			quit(0)
		elif near_hits >= 1:
			print("⚠️ PARTIAL: near-miss works but not all cases (%d/3)" % near_hits)
			quit(2)
		else:
			print("❌ FAILED: near-miss never detected")
			quit(1)
		return true
	return false
