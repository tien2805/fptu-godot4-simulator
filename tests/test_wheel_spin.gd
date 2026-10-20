# File: res://tests/test_wheel_spin.gd
# Kiểm tra trục & chiều quay bánh xe người chơi: lốp (torus) phải có trục song song trục X của xe (bánh đứng),
# và khi xe chạy TỚI, điểm trên đỉnh bánh phải di chuyển về phía trước (-Z cục bộ của xe).
# Chạy:  godot --headless --path . --script tests/test_wheel_spin.gd
extends SceneTree

var stage: Node3D
var bike: CharacterBody3D
var frames: int = 0
var fails: Array[String] = []
var front: Node3D
var marker: Node3D
var p0_local: Vector3

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Main.tscn")
	stage = packed.instantiate()
	root.add_child(stage)
	bike = stage.get_node("PlayerBike")
	front = bike.get_node("VisualPivot/FrontWheel")
	print("--- TEST WHEEL SPIN ---")

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		# trục lốp: torus đầu tiên dưới FrontWheel/Wheel
		var wheel: Node3D = front.get_node_or_null("Wheel")
		if wheel == null:
			fails.append("không có node Wheel dưới FrontWheel")
		else:
			var torus: MeshInstance3D = null
			for c: Node in wheel.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).mesh is TorusMesh:
					torus = c
					break
			if torus:
				# TorusMesh có trục Y cục bộ; trục đó trong hệ của xe (VisualPivot) phải ≈ ±X
				var axis_in_bike: Vector3 = bike.global_transform.basis.inverse() * (torus.global_transform.basis.y.normalized())
				print("  trục lốp trong hệ xe = ", axis_in_bike.snapped(Vector3(0.01, 0.01, 0.01)))
				if absf(axis_in_bike.x) < 0.95:
					fails.append("trục lốp không song song trục X của xe: %s" % str(axis_in_bike))
			# đánh dấu đỉnh bánh: điểm (0, 0.3, 0) trong hệ Wheel → theo dõi sau khi xe chạy
			marker = Node3D.new()
			marker.position = Vector3(0.0, 0.3, 0.0)
			wheel.add_child(marker)
		# nhấn ga
		Input.action_press("gas")
	if frames > 3 and frames <= 40 and marker:
		var p: Vector3 = bike.to_local(marker.global_position)
		if frames == 20:
			p0_local = p
		if frames == 40:
			var speed: float = float(bike.get("current_speed_ms"))
			print("  speed=%.2f m/s, đỉnh bánh frame20 z=%.3f → frame40 z=%.3f (y %.3f→%.3f)" % [speed, p0_local.z, p.z, p0_local.y, p.y])
			# Khi chạy tới (speed > 0 theo quy ước của PlayerBike), đỉnh bánh phải đi về -Z (về trước) hoặc đã vòng xuống
			var forward_vel: float = -bike.velocity.z if bike.velocity.length() > 0.01 else 0.0
			print("  velocity=%s (forward_vel theo -Z = %.2f)" % [str(bike.velocity.snapped(Vector3(0.01, 0.01, 0.01))), forward_vel])
			var ok: bool = (p.z < p0_local.z) == (forward_vel > 0.0)
			if not ok and absf(forward_vel) > 0.1:
				fails.append("đỉnh bánh quay ngược chiều chuyển động")
			Input.action_release("gas")
			if fails.is_empty():
				print("✅ SUCCESS: WHEEL AXIS AND SPIN DIRECTION MATCH THE MOTION")
				quit(0)
			else:
				for f: String in fails:
					print("  ✗ ", f)
				print("❌ FAILED")
				quit(1)
			return true
	return false
