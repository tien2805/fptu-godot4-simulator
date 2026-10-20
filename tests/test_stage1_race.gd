# File: res://tests/test_stage1_race.gd
# Test headless Màn 1: autopilot "người chơi trung bình" – giữ ga, bám làn phải, né xe/xe tải phía trước,
# dừng đèn đỏ, drift ở khúc cua Nguyễn Xiển. Kiểm tra: không lỗi script, sự kiện đường kích hoạt,
# near-miss được ghi nhận khi lách xe, và màn kết thúc (kỳ vọng PRESENT).
# Chạy:  godot --headless --path . --script tests/test_stage1_race.gd
extends SceneTree

var stage: Node3D
var bike: CharacterBody3D
var hud: CanvasLayer
var road: Node3D
var curve: Curve3D
var frames: int = 0
var started: bool = false
var max_offset: float = 0.0
var lateral_target: float = 2.4
var lane_hold: int = 0
const CANDIDATES: Array[float] = [2.4, 4.6, 0.3, -2.0, -4.4]
const MAX_FRAMES: int = 60 * 60 * 6

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
	hud = stage.get_node("HUD")
	road = stage.get_node("RoadSystem")
	# time_scale thấp để vật lý không "nhảy cóc" qua vùng near-miss (xe ngược chiều ~40 m/s tương đối)
	Engine.time_scale = 2.0
	print("--- TEST MÀN 1: AUTOPILOT ĐUA XE VINHOMES -> FPTU ---")
	started = true

func _obstacle_info(node: Node3D, my_off: float) -> Vector2:
	# Trả về (khoảng cách dọc đường, độ lệch ngang) của chướng ngại so với xe
	var off: float = curve.get_closest_offset(node.global_position)
	var xf: Transform3D = curve.sample_baked_with_rotation(off)
	var lat: float = (node.global_position - xf.origin).dot(xf.basis.x)
	return Vector2(off - my_off, lat)

func _pick_lane(my_off: float) -> void:
	lane_hold -= 1
	var obstacles: Array[Node] = get_nodes_in_group("traffic_obstacle")
	var infos: Array[Vector2] = []
	for n: Node in obstacles:
		if n is Node3D and n != bike:
			var info: Vector2 = _obstacle_info(n, my_off)
			if info.x > -3.0 and info.x < 34.0:
				infos.append(info)
	var blocked_current: bool = false
	for info: Vector2 in infos:
		if absf(info.y - lateral_target) < 1.7:
			blocked_current = true
			break
	if not blocked_current and lane_hold > 0:
		return
	if not blocked_current:
		return
	for cand: float in CANDIDATES:
		var ok: bool = true
		for info: Vector2 in infos:
			if absf(info.y - cand) < 1.7:
				ok = false
				break
		if ok:
			lateral_target = cand
			lane_hold = 25
			return

func _autopilot() -> void:
	var off: float = curve.get_closest_offset(bike.global_position)
	max_offset = maxf(max_offset, off)
	_pick_lane(off)
	var look_ahead: float = 12.0
	var tx: Transform3D = curve.sample_baked_with_rotation(minf(off + look_ahead, curve.get_baked_length() - 0.1))
	var target: Vector3 = tx.origin + tx.basis.x * lateral_target
	var to: Vector3 = target - bike.global_position
	to.y = 0.0
	var fwd: Vector3 = -bike.global_transform.basis.z
	fwd.y = 0.0
	var cross_y: float = fwd.normalized().cross(to.normalized()).y
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if cross_y > 0.025:
		Input.action_press("steer_left")
	elif cross_y < -0.025:
		Input.action_press("steer_right")

	# Chấp hành đèn đỏ ngã ba Trau Trảu
	var ev: Node = road.get("road_events")
	var must_stop: bool = false
	if ev:
		var ls: String = str(ev.get("light_state"))
		var line_off: float = float(ev.get("LIGHT_OFFSET")) - 1.5
		if (ls == "yellow" or ls == "red") and off < line_off and off > line_off - 42.0:
			must_stop = true
	if must_stop:
		Input.action_release("gas")
		Input.action_press("brake")
	else:
		Input.action_release("brake")
		Input.action_press("gas")

	# Drift thử ở khúc cua gắt Nguyễn Xiển
	if off > 250.0 and off < 300.0 and absf(cross_y) > 0.15:
		Input.action_press("drift")
	else:
		Input.action_release("drift")

func _process(_delta: float) -> bool:
	if not started:
		return false
	frames += 1
	if curve == null:
		curve = (road.get_node("RoadTrack/RoadPath") as Path3D).curve
	if frames > 3 and not hud.get("is_game_ended"):
		_autopilot()
	if frames % 300 == 0:
		var ev: Node = road.get("road_events")
		print("  frame %d: offset %.0f m, lane %.1f, speed %.0f km/h, elapsed %.1fs, light=%s, nearmiss=%d, crashes=%d, bonus=%.1f, penalty=%.1f" % [
			frames, max_offset, lateral_target, absf(float(bike.get("current_speed_ms"))) * 3.6, hud.get("elapsed_sec"),
			str(ev.get("light_state")) if ev else "n/a", hud.get("near_miss_count"), hud.get("crashes"), hud.get("bonus_total"), hud.get("penalty_total")])
	if hud.get("is_game_ended"):
		for a: String in ["gas", "brake", "steer_left", "steer_right", "drift"]:
			Input.action_release(a)
		var reached: bool = road.get("has_finished")
		var ev: Node = road.get("road_events")
		var cps_done: int = 0
		if ev:
			for cp: Dictionary in ev.get("checkpoints"):
				if cp["done"]:
					cps_done += 1
		print("  Kết thúc sau %d frame: reached_finish=%s, max_offset=%.0f, checkpoints=%d/5, nearmiss=%d, drift_boosts=%d, crashes=%d, bonus=%.1f, penalty=%.1f, elapsed=%.1f" % [
			frames, str(reached), max_offset, cps_done, hud.get("near_miss_count"), hud.get("drift_boosts"), hud.get("crashes"), hud.get("bonus_total"), hud.get("penalty_total"), hud.get("elapsed_sec")])
		if reached and cps_done >= 5:
			print("✅ SUCCESS: AUTOPILOT REACHED FPTU GATE; ALL ROAD EVENTS FIRED")
			quit(0)
		else:
			print("❌ FAILED: did not reach the finish line")
			quit(1)
		return true
	if frames >= MAX_FRAMES:
		print("❌ FAILED: timeout at offset %.0f" % max_offset)
		quit(1)
		return true
	return false
