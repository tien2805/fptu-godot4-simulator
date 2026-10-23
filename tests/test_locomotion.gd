# File: res://tests/test_locomotion.gd
# Test headless di chuyển kiểu GTA của ThirdPersonController: đi bộ 1.7 / chạy 4.2 m/s, slow_t chậm một nửa đúng thời
# hạn, thể lực nước rút ~6 s rồi hồi, FOV rộng khi nước rút, nhảy tại chỗ cao ~0.9 m, nhảy khi nước rút xa >= 3.2 m, rơi
# 2 / 4 / 8 m -> nhún / lăn / ngã (khoá điều khiển rồi đứng dậy), tín hiệu landed khớp nhật ký với độ cao rơi đúng, đi
# qua hết bó vỉa 0.15 m không bao giờ vào trạng thái rơi, teleport giữa cú nhảy xoá clip / nước rút / phím nhảy đang chờ.
# Chạy:  godot --headless --path . --script tests/test_locomotion.gd
extends SceneTree

const KERB_LAST_FAR_X: float = -33.7   # mép xa của bó vỉa cuối (tâm -34.0, rộng 0.6)

var world: Node3D
var p: ThirdPersonController
var frames: int = 0
var phase: String = "settle"
var t0: int = 0
var mark := Vector3.ZERO
var peak: float = 0.0
var done: bool = false
var air_frames: int = 0
var sig_log: Array[String] = []   # kiểu tiếp đất theo tín hiệu landed (xoá cùng lúc với p.landings)
var sig_drops: Array[float] = []


func _initialize() -> void:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(400.0, 1.0, 400.0))                 # sàn y = 0
	for h: float in [2.0, 4.0, 8.0]:
		_box(Vector3(60.0 + h * 10.0, h * 0.5, 0.0), Vector3(4.0, h, 4.0))     # bục cao h tại x = 80 / 100 / 140
	for i: int in range(6):
		_box(Vector3(-40.0 + float(i) * 1.2, 0.075, 30.0), Vector3(0.6, 0.15, 6.0))   # bó vỉa 0.15 m, cách nhau 0.6 m
	p = ThirdPersonController.new()
	p.capture_on_click = false
	# trong _initialize cây chưa chạy (teleport() đặt global_position, báo lỗi ngoài cây): đặt vị trí + yaw trước khi vào cây
	p.position = Vector3(-150.0, 0.0, 0.0)   # đứng đúng mặt sàn: không có cú "rơi" 5 cm lúc xuất hiện
	p.yaw = -PI * 0.5   # nhìn về +X (_build xoay thân theo yaw)
	world.add_child(p)
	p.landed.connect(_on_landed)
	physics_frame.connect(_on_physics)
	print("--- TEST LOCOMOTION (GTA-style movement) ---")


func _on_landed(kind: String, drop: float) -> void:
	sig_log.append(kind)
	sig_drops.append(drop)


func _clear_landings() -> void:
	p.landings.clear()
	sig_log.clear()
	sig_drops.clear()


## Một cú rơi h m: đúng kiểu tiếp đất, tín hiệu landed phát đúng một lần cùng kiểu, độ cao rơi ~h.
func _check_drop(h: float, want: String) -> bool:
	print("  %d m drop -> %s (landed signal %s, drop %.2f m)" % [int(h), p.landings[0], sig_log, sig_drops[0] if sig_drops.size() > 0 else -1.0])
	if not _check(p.landings[0] == want, "a %d m drop must give %s (got %s)" % [int(h), want, p.landings[0]]):
		return false
	if not _check(sig_log == p.landings, "landed must fire once per landing with the same kind (signal %s, log %s)" % [sig_log, p.landings]):
		return false
	return _check(absf(sig_drops[0] - h) < 0.25, "landed must report the drop height (%.2f m for a %d m drop)" % [sig_drops[0], int(h)])


## Máy pha chạy theo nhịp vật lý (SceneTree.physics_frame phát mỗi bước vật lý).
func _on_physics() -> void:
	if done:
		return
	frames += 1
	_physics_process_test()


func _box(c: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = c
	world.add_child(sb)


func _goto(next: String) -> void:
	phase = next
	t0 = frames


func _physics_process_test() -> void:
	var t: int = frames - t0
	match phase:
		"settle":
			if t == 30:
				p.walk_override = true
				p.input_override = Vector2(0.0, -1.0)
				_goto("walk")
		"walk":
			if t == 90:
				print("  walk speed %.2f m/s" % p.horizontal_speed)
				if not _check(absf(p.horizontal_speed - 1.7) < 0.12, "walk speed must be 1.7 m/s (got %.2f)" % p.horizontal_speed):
					return
				p.walk_override = false
				_goto("jog")
		"jog":
			if t == 90:
				print("  jog speed %.2f m/s" % p.horizontal_speed)
				if not _check(absf(p.horizontal_speed - 4.2) < 0.15, "jog speed must be 4.2 m/s (got %.2f)" % p.horizontal_speed):
					return
				p.slow_t = 1.5   # như PedestrianSpawner khi va người đi đường
				_goto("slow")
		"slow":
			if t == 60:
				print("  slow_t: %.2f m/s with %.2f s left" % [p.horizontal_speed, p.slow_t])
				if not _check(p.slow_t > 0.0 and absf(p.horizontal_speed - 2.1) < 0.15, "slow_t must halve the jog speed while it lasts (got %.2f m/s, %.2f s left)" % [p.horizontal_speed, p.slow_t]):
					return
			if t == 150:
				print("  slow_t over: %.2f m/s" % p.horizontal_speed)
				if not _check(p.slow_t == 0.0 and absf(p.horizontal_speed - 4.2) < 0.15, "jog speed must come back when slow_t runs out (got %.2f m/s, slow_t %.2f)" % [p.horizontal_speed, p.slow_t]):
					return
				p.sprint_override = true
				_goto("sprint")
		"sprint":
			if t == 120:
				print("  sprint camera fov %.1f" % p.camera.fov)
				if not _check(p.camera.fov > 75.0, "sprinting must widen the camera FOV towards 76 (got %.1f)" % p.camera.fov):
					return
			if not p.is_sprinting and t > 30:
				var secs: float = float(t) / 60.0
				print("  sprint lasted %.2f s" % secs)
				if not _check(absf(secs - 6.0) < 0.35, "stamina must last 6 s (got %.2f)" % secs):
					return
				p.sprint_override = false
				p.input_override = Vector2.ZERO
				_goto("rest")
		"rest":
			if t == 240:   # 1 s chờ + 3 s hồi -> 2.4 s thể lực
				var s: float = p.stamina * 6.0
				print("  stamina after 4 s rest: %.2f s" % s)
				if not _check(absf(s - 2.4) < 0.25, "stamina must refill 0.8 s per s after a 1 s delay (got %.2f s)" % s):
					return
				if not _check(p.camera.fov < 70.5, "the FOV must ease back to 70 after the sprint (got %.1f)" % p.camera.fov):
					return
				p.teleport(Vector3(-150.0, 0.05, -60.0), -PI * 0.5)
				_goto("jump_settle")
		"jump_settle":
			if t == 20:
				mark = p.global_position
				peak = mark.y
				p.jump_override = true
				_goto("jump")
		"jump":
			peak = maxf(peak, p.global_position.y)
			if t > 5 and p.move_state == "GROUND":
				var apex: float = peak - mark.y
				print("  standing jump apex %.2f m" % apex)
				if not _check(apex > 0.85 and apex < 1.0, "standing jump apex must be 0.85..1.0 m (got %.2f)" % apex):
					return
				p.stamina = 1.0
				p.sprint_override = true
				p.input_override = Vector2(0.0, -1.0)
				_goto("run_up")
		"run_up":
			if t == 120:
				mark = p.global_position
				p.jump_override = true
				_goto("long_jump")
		"long_jump":
			if t > 5 and p.move_state in ["GROUND", "LAND_SOFT"]:
				var dist: float = Vector2(p.global_position.x - mark.x, p.global_position.z - mark.z).length()
				print("  running jump distance %.2f m" % dist)
				if not _check(dist >= 3.2, "a sprint jump must cover at least 3.2 m (got %.2f)" % dist):
					return
				print("  landings so far %s, landed signal %s" % [p.landings, sig_log])
				if not _check(p.landings.size() == 2 and sig_log == p.landings, "two jumps -> two landings, each with one landed signal (log %s, signal %s)" % [p.landings, sig_log]):
					return
				p.sprint_override = false
				_clear_landings()
				p.teleport(Vector3(78.5, 2.05, 0.0), -PI * 0.5)   # bục 2 m (x 78..82): đi ra mép +X
				_goto("drop2")
		"drop2", "drop4", "drop8":
			if t == 10:
				p.input_override = Vector2(0.0, -1.0)
			if p.landings.size() > 0 and phase == "drop2":
				if not _check_drop(2.0, "LAND_SOFT"):
					return
				_clear_landings()
				p.teleport(Vector3(98.5, 4.05, 0.0), -PI * 0.5)
				_goto("drop4")
			elif p.landings.size() > 0 and phase == "drop4":
				if not _check_drop(4.0, "LAND_ROLL"):
					return
				_clear_landings()
				p.teleport(Vector3(138.5, 8.05, 0.0), -PI * 0.5)
				_goto("drop8")
			elif p.landings.size() > 0 and phase == "drop8":
				if not _check_drop(8.0, "SPLAT"):
					return
				mark = p.global_position
				_goto("splat")
		"splat":
			if t == 140:   # 2.33 s: vẫn đang ngã/đứng dậy (1.5 + 0.9 s), không di chuyển dù giữ W
				var moved: float = Vector2(p.global_position.x - mark.x, p.global_position.z - mark.z).length()
				print("  moved %.2f m during the splat" % moved)
				if not _check(moved < 0.3, "input must be locked during the splat (moved %.2f m)" % moved):
					return
			if t == 170:
				if not _check(p.move_state == "GROUND", "after splat + getup the player is back on the ground state (got %s)" % p.move_state):
					return
				p.input_override = Vector2.ZERO
				_clear_landings()   # nhật ký còn "SPLAT" của cú rơi 8 m
				p.teleport(Vector3(-43.0, 0.05, 30.0), -PI * 0.5)
				air_frames = 0
				_goto("kerbs")
		"kerbs":
			if t == 10:
				p.input_override = Vector2(0.0, -1.0)
			if p.move_state in ["AIR", "JUMP"]:
				air_frames += 1
			if t == 170:
				# qua hết: cả capsule (bán kính 0.4) đã qua mép xa của bó vỉa cuối
				print("  kerb crossing: %d air frames, landings %s, x %.2f (past the last kerb at x > %.2f)" % [air_frames, p.landings, p.global_position.x, KERB_LAST_FAR_X + 0.4])
				if not _check(air_frames == 0 and p.landings.is_empty() and sig_log.is_empty(), "stepping over 0.15 m kerbs must never enter the air state"):
					return
				if not _check(p.global_position.x > KERB_LAST_FAR_X + 0.4, "the player must get past all six kerbs (x %.2f)" % p.global_position.x):
					return
				_goto("teleport")
		"teleport":
			if t == 1:
				p.stamina = 1.0
				p.sprint_override = true
			if t == 60:
				if not _check(p.is_sprinting, "sprinting before the teleport"):
					return
				p.teleport(Vector3(-150.0, 0.05, 60.0), -PI * 0.5)
				if not _check(not p.is_sprinting, "teleport must reset is_sprinting"):
					return
			if t == 100:
				p.jump_override = true
			if t == 120:
				var an: Node = CharacterBuilder.get_animator(p.model)
				var clip_before: String = String(an.get("clip"))
				if not _check(p.move_state in ["JUMP", "AIR"] and clip_before != "", "mid-air with an air clip before the teleport (state %s, clip '%s')" % [p.move_state, clip_before]):
					return
				p.jump_override = true   # phím nhảy đang chờ cũng không được sống sót qua teleport
				p.teleport(Vector3(-150.0, 0.05, 80.0), -PI * 0.5)
				var clip_after: String = String(an.get("clip"))
				print("  mid-air teleport: clip '%s' -> '%s', state %s, jump pending %s" % [clip_before, clip_after, p.move_state, p.jump_override])
				if not _check(p.move_state == "GROUND" and clip_after == "" and not p.jump_override, "teleport must stop the movement clip and drop a pending jump (clip '%s', jump %s)" % [clip_after, p.jump_override]):
					return
				p.sprint_override = false
				p.input_override = Vector2.ZERO
			if t == 160:
				if not _check(p.move_state == "GROUND" and p.landings.is_empty(), "no jump or landing after the teleport (state %s, landings %s)" % [p.move_state, p.landings]):
					return
				print("✅ SUCCESS: GTA-STYLE MOVEMENT - SPEEDS, SLOW_T, STAMINA, SPRINT FOV, JUMPS, LANDINGS + SIGNAL, SPLAT LOCK, KERBS, TELEPORT RESET")
				done = true
				quit(0)


func _process(_d: float) -> bool:
	return done


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
