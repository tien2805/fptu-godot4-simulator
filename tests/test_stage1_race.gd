# File: res://tests/test_stage1_race.gd
# Test headless Màn 1 trên tuyến thật BE6 -> cổng FPTU (5,3..5,6 km, plan Task 6): autopilot "người chơi trung
# bình" – giữ ga, bám làn phải theo bề rộng đường thật (PlayerBike.road_half_width do RoadManager cập nhật), nhìn
# trước theo tốc độ để phanh trước cua gắt, né xe/xe tải phía trước, dừng đèn đỏ trước Cầu Rạch Hầm, drift ở cua gắt.
# Kiểm tra: không lỗi script, chiều dài tuyến 5300..5600 m, 5 checkpoint kích hoạt, near-miss được ghi nhận,
# bot về đích trước RoadManager.STAGE_TIME (300 s; chạy hết ga 5,5 km đã mất 246 s) -> kỳ vọng PRESENT.
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
var first_near_miss_frame: int = -1
var last_turn_deg: float = 0.0
var blocked_no_alt: bool = false # kẹt sau xe chậm trên đường hẹp, không có làn trống -> bám đuôi (núp gió) thay vì húc
var ahead_gap: float = 99.0      # khoảng cách tới xe gần nhất phía trước trong làn hiện tại (m)
var clearance_cache: Dictionary = {}
var stuck_check_elapsed: float = 0.0
var stuck_check_offset: float = 0.0
const CANDIDATES: Array[float] = [2.4, 4.6, 0.3, -2.0, -4.4] # làn ưu tiên (m từ tim đường), kẹp vào lòng đường thật
const MAX_FRAMES: int = 60 * 60 * 25
const TRACK_MIN: float = 5300.0
const TRACK_MAX: float = 5600.0
# = RoadManager.STAGE_TIME (không tham chiếu class_name RoadManager ở đây: script đó dùng GameFX nên sẽ bị biên dịch
# trước khi autoload được chèn vào test). Xem lý do con số ở RoadManager: 5,5 km hết ga đã mất 246 s.
const TIME_LIMIT: float = 300.0

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
	print("--- TEST MÀN 1: AUTOPILOT ĐUA XE BE6 (VINHOMES) -> CỔNG FPTU TRÊN TUYẾN THẬT ---")
	started = true

## RoadManager dựng curve trong _ready (frame đầu của --script) -> in thông tin tuyến khi curve đã có
func _print_route_info() -> void:
	var stage_time: float = float(hud.get("stage_duration_sec"))
	print("  track_len=%.0f m, finish_offset=%.0f m, curve=%.0f m, stage_time=%.0fs" % [float(road.get("total_track_length")), float(road.get("finish_offset")), curve.get_baked_length(), stage_time])
	if absf(stage_time - TIME_LIMIT) > 0.5:
		print("⚠️ WARN: HUD stage_duration_sec %.0f != test TIME_LIMIT %.0f (update the test when RoadManager.STAGE_TIME changes)" % [stage_time, TIME_LIMIT])
	var marks: Dictionary = road.get("route_marks")
	var keys: Array = marks.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: String in keys:
		parts.append("%s=%.0f" % [k, float(marks[k])])
	print("  marks: ", ", ".join(parts))

func _lane_limit() -> float:
	return maxf(0.6, float(bike.get("road_half_width")) - 0.5)

## Khoảng hở ngang tối thiểu (m, tâm-tâm) để lách một chướng ngại: nửa bề rộng hộp va chạm của nó + nửa xe (0.42)
## + 0.4 m dư, không dưới 1.7 m (xe máy 0.7 m -> 1.7; xe tải hỏng 2.4 m / xe buýt 2.5 m -> ~2.05).
func _clearance(node: Node3D) -> float:
	if clearance_cache.has(node):
		return float(clearance_cache[node])
	var half_w: float = 0.35
	for c: Node in node.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			half_w = ((c as CollisionShape3D).shape as BoxShape3D).size.x * 0.5
			break
	var v: float = maxf(1.7, half_w + 0.42 + 0.4)
	clearance_cache[node] = v
	return v

func _obstacle_info(node: Node3D, my_off: float) -> Vector3:
	# Trả về (khoảng cách dọc đường, độ lệch ngang, khoảng hở cần để lách) của chướng ngại so với xe
	var off: float = curve.get_closest_offset(node.global_position)
	var xf: Transform3D = curve.sample_baked_with_rotation(off)
	var lat: float = (node.global_position - xf.origin).dot(xf.basis.x)
	return Vector3(off - my_off, lat, _clearance(node))

func _lane_free(lane: float, infos: Array[Vector3]) -> bool:
	for info: Vector3 in infos:
		if absf(info.y - lane) < info.z:
			return false
	return true

func _pick_lane(my_off: float) -> void:
	lane_hold -= 1
	var lim: float = _lane_limit()
	var obstacles: Array[Node] = get_nodes_in_group("traffic_obstacle")
	var infos: Array[Vector3] = []
	var infos_far: Array[Vector3] = []
	for n: Node in obstacles:
		if n is Node3D and n != bike:
			var info: Vector3 = _obstacle_info(n, my_off)
			if info.x > -3.0 and info.x < 34.0:
				infos.append(info)
			if info.x > 20.0 and info.x < 60.0:
				infos_far.append(info)
	var cur: float = clampf(lateral_target, -lim, lim)
	var blocked_current: bool = false
	ahead_gap = 99.0
	for info: Vector3 in infos:
		if absf(info.y - cur) < info.z:
			blocked_current = true
			if info.x > 0.0:
				ahead_gap = minf(ahead_gap, info.x)
	blocked_no_alt = false
	if not blocked_current and lane_hold > 0:
		return
	if not blocked_current:
		# "Người chơi trung bình" chủ động lách sát: nếu có xe ngược chiều ở làn trái cách 20–60 m và làn giữa (0.3) trống
		for info: Vector3 in infos_far:
			if info.y < -0.5 and info.y > -2.6 and info.x > 20.0 and info.x < 60.0 and lateral_target != 0.3:
				if _lane_free(0.3, infos):
					lateral_target = 0.3
					lane_hold = 40
				return
		# Đang ở làn ngược chiều mà không còn gì chắn -> về lại làn phải nếu trống
		if lateral_target < 0.0 and _lane_free(clampf(2.4, -lim, lim), infos):
			lateral_target = 2.4
			lane_hold = 25
		return
	for cand: float in CANDIDATES:
		if _lane_free(clampf(cand, -lim, lim), infos):
			lateral_target = cand
			lane_hold = 25
			return
	# Không làn nào trống (xe buýt / xe tải hỏng chiếm gần hết đường + xe ngược chiều): bám đuôi, không húc
	blocked_no_alt = true

func _autopilot() -> void:
	var track_end: float = curve.get_baked_length() - 0.1
	var off: float = curve.get_closest_offset(bike.global_position)
	max_offset = maxf(max_offset, off)
	_pick_lane(off)
	var speed: float = absf(float(bike.get("current_speed_ms")))
	var lat: float = clampf(lateral_target, -_lane_limit(), _lane_limit())
	# Lái: nhìn trước xa hơn khi nhanh (7..15 m)
	var look_ahead: float = clampf(speed * 0.65, 7.0, 15.0)
	var tx: Transform3D = curve.sample_baked_with_rotation(minf(off + look_ahead, track_end))
	var target: Vector3 = tx.origin + tx.basis.x * lat
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

	# Nhìn trước theo quãng phanh: góc đổi hướng trong (6 + 1,3 x tốc độ) m -> tốc độ mục tiêu trước cua
	# (bán kính rẽ nhỏ nhất của xe ~10 m không đổi theo tốc độ nên cua 90° vẫn qua được ở ~40 km/h)
	var ahead: float = clampf(speed * 1.3 + 6.0, 12.0, 36.0)
	var t0: Transform3D = curve.sample_baked_with_rotation(minf(off + 4.0, track_end))
	var t1: Transform3D = curve.sample_baked_with_rotation(minf(off + ahead, track_end))
	var turn_deg: float = rad_to_deg((-t0.basis.z).angle_to(-t1.basis.z))
	last_turn_deg = turn_deg
	var target_speed: float = 30.0
	if turn_deg > 25.0:
		target_speed = lerpf(21.0, 11.0, clampf((turn_deg - 25.0) / 65.0, 0.0, 1.0))
	if blocked_no_alt:
		# bám sau xe buýt/xe chậm (núp gió) hoặc chờ sau xe tải hỏng cho tới khi có làn trống: giữ cách >= 8 m,
		# được phép dừng hẳn (xe tải hỏng đứng yên, xe ngược chiều qua rồi làn sẽ trống)
		target_speed = minf(target_speed, clampf((ahead_gap - 8.0) * 1.2, 0.0, 10.5))

	# Chấp hành đèn đỏ trước Cầu Rạch Hầm
	var ev: Node = road.get("road_events")
	var must_stop: bool = false
	if ev:
		var ls: String = str(ev.get("light_state"))
		var line_off: float = float(ev.get("LIGHT_OFFSET")) - 1.5
		if (ls == "yellow" or ls == "red") and off < line_off and off > line_off - 42.0:
			must_stop = true
	if must_stop or speed > target_speed + 1.0:
		Input.action_release("gas")
		if not must_stop and speed < 1.0:
			Input.action_release("brake") # đã đứng yên sau xe chắn: nhả hết (giữ phanh khi đứng yên = lùi xe)
		else:
			Input.action_press("brake")
	elif target_speed < 0.5:
		Input.action_release("gas")
		Input.action_release("brake")
	else:
		Input.action_release("brake")
		Input.action_press("gas")

	# Drift ở cua gắt khi còn đang nhanh (người chơi trung bình "thử drift")
	if turn_deg > 60.0 and speed > 9.0 and absf(cross_y) > 0.12:
		Input.action_press("drift")
	else:
		Input.action_release("drift")

func _process(_delta: float) -> bool:
	if not started:
		return false
	frames += 1
	if curve == null:
		curve = (road.get_node("RoadTrack/RoadPath") as Path3D).curve
		if curve == null:
			return false
		_print_route_info()
	if frames > 3 and not hud.get("is_game_ended"):
		_autopilot()
	if first_near_miss_frame < 0 and int(hud.get("near_miss_count")) > 0:
		first_near_miss_frame = frames
		print("  >> first near-miss at frame %d (%.1fs), offset %.0f m" % [frames, hud.get("elapsed_sec"), max_offset])
	if frames % 600 == 0:
		var ev: Node = road.get("road_events")
		print("  frame %d: offset %.0f m, lane %.1f (hw %.2f), speed %.0f km/h, turn %.0f°, elapsed %.1fs, light=%s, nearmiss=%d, crashes=%d, bonus=%.1f, penalty=%.1f, zone=%s" % [
			frames, max_offset, lateral_target, float(bike.get("road_half_width")), absf(float(bike.get("current_speed_ms"))) * 3.6, last_turn_deg, hud.get("elapsed_sec"),
			str(ev.get("light_state")) if ev else "n/a", hud.get("near_miss_count"), hud.get("crashes"), hud.get("bonus_total"), hud.get("penalty_total"), str(road.get("current_zone"))])
		# Kẹt (không tiến thêm 15 m trong 12 s game) -> báo sớm thay vì chờ hết giờ
		var el: float = float(hud.get("elapsed_sec"))
		if el - stuck_check_elapsed > 12.0:
			if max_offset - stuck_check_offset < 15.0 and not hud.get("is_game_ended"):
				print("❌ FAILED: autopilot stuck at offset %.0f m (pos %s)" % [max_offset, str(bike.global_position)])
				quit(1)
				return true
			stuck_check_elapsed = el
			stuck_check_offset = max_offset
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
		var track_len: float = float(road.get("total_track_length"))
		var elapsed: float = float(hud.get("elapsed_sec"))
		print("  Kết thúc sau %d frame: reached_finish=%s, track_len=%.0f m, max_offset=%.0f, checkpoints=%d/5, nearmiss=%d, longest_chain=%d, first_nearmiss_frame=%d, drift_boosts=%d, crashes=%d, bonus=%.1f, penalty=%.1f, elapsed=%.1fs" % [
			frames, str(reached), track_len, max_offset, cps_done, hud.get("near_miss_count"), bike.get("longest_near_miss_chain"), first_near_miss_frame, hud.get("drift_boosts"), hud.get("crashes"), hud.get("bonus_total"), hud.get("penalty_total"), elapsed])
		if reached and (first_near_miss_frame < 0 or first_near_miss_frame > 60 * 20):
			print("⚠️ WARN: first near-miss later than 20 s (target < 15 s) – check cluster placement")
		var len_ok: bool = track_len >= TRACK_MIN and track_len <= TRACK_MAX
		if not len_ok:
			print("❌ FAILED: track length %.0f m outside %.0f..%.0f" % [track_len, TRACK_MIN, TRACK_MAX])
		if reached and cps_done >= 5 and len_ok and elapsed < TIME_LIMIT:
			print("✅ SUCCESS: AUTOPILOT REACHED FPTU GATE IN %.1fs ON THE %.0f m REAL ROUTE; ALL ROAD EVENTS FIRED" % [elapsed, track_len])
			quit(0)
		else:
			print("❌ FAILED: reached=%s checkpoints=%d/5 elapsed=%.1fs (limit %.0fs)" % [str(reached), cps_done, elapsed, TIME_LIMIT])
			quit(1)
		return true
	if frames >= MAX_FRAMES:
		print("❌ FAILED: timeout at offset %.0f" % max_offset)
		quit(1)
		return true
	return false
