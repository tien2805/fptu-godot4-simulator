# File: res://scripts/story/missions/MissionStakeout.gd
# Day 1 stake-out (spec B-D5 beat 3): the real D1 parking at night (FPTUCampusBuilder.parking_center_local). Shipper Mũ
# Đỏ waits in the lane with a buyer, two guards patrol the lane. Stay out of the three watchers' sight for DURATION s and
# photograph the handover with [S] while it happens (WINDOW), the courier in frame within PHOTO_M (the Extra-stage idea).
# Seen (a 70° cone of SIGHT_M with a clear ray, or closer than NEAR_M) = "Bị phát hiện!", the stake-out restarts from the
# start spot. The handover window over without a photo = fail ("TOANG!", retry). DURATION s with the photo = done.
# Sight checks run at 10 Hz.
class_name MissionStakeout
extends StoryMission

const DURATION: float = 60.0
const WINDOW := Vector2(34.0, 48.0)
const SIGHT_M: float = 12.0
const HALF_FOV_DEG: float = 35.0
const NEAR_M: float = 2.5
const PHOTO_M: float = 22.0
const CHECK_S: float = 0.1
const GUARD_SPEED: float = 1.3
const GUARD_PAUSE: float = 1.6
## Campus-plot local spots (u, 0, v): the lane centre is v = 103.5.
const HANDOVER := Vector3(122.0, 0.0, 103.5)
const BUYER := Vector3(120.6, 0.0, 103.5)
const START := Vector3(90.0, 0.0, 103.5)
const GUARD_A := [Vector3(108.0, 0.0, 101.6), Vector3(138.0, 0.0, 101.6)]
const GUARD_B := [Vector3(104.0, 0.0, 105.6), Vector3(138.0, 0.0, 105.6)]
const T_SEEN: String = "Bị phát hiện! Rình lại từ đầu."
const T_MISSED: String = "Lỡ mất khoảnh khắc giao hàng rồi."
const T_PHOTO: String = "Đã chụp! Ảnh giao hàng rõ mồn một."
const T_NOT_YET: String = "Chưa giao hàng… chờ đúng lúc."
const T_TOO_FAR: String = "Xa quá, ảnh mờ tịt. Lại gần hơn."
const T_WINDOW: String = "ĐANG GIAO HÀNG! [S] Chụp ảnh"

var courier: Node3D
var buyer: Node3D
var guards: Array[Node3D] = []
var box: MeshInstance3D
var photo_taken: bool = false
var seen_count: int = 0
var photo_tries: int = 0
var _g: Array[Dictionary] = []   # per guard: {a, b, t (0..1 along a-b), dir (+1 / -1), pause}
var _check_t: float = 0.0
var _flash: ColorRect


func _start() -> void:
	StoryAudio.warm(["success_fanfare"])
	var h: Vector3 = campus(HANDOVER)
	var bp: Vector3 = campus(BUYER)
	courier = spawn_body("courier_do", h, yaw_of(bp - h))
	buyer = spawn_body("clone", bp, yaw_of(h - bp), {"seed": 31})
	for i: int in 2:
		var g: Node3D = spawn_body("chu_bay", Vector3.ZERO, 0.0, {"seed": 61 + i, "name": "Guard%d" % i})
		guards.append(g)
	box = MeshInstance3D.new()
	box.name = "Package"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.26, 0.3)
	box.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#B07A43")
	box.material_override = mat
	add_child(box)
	box.global_position = (h + bp) * 0.5 + Vector3(0.0, 1.0, 0.0)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_flash)
	_reset()


func _reset() -> void:
	clock = 0.0
	photo_taken = false
	_g = [{"a": campus(GUARD_A[0]), "b": campus(GUARD_A[1]), "t": 0.73, "dir": -1.0, "pause": 0.0},
		{"a": campus(GUARD_B[0]), "b": campus(GUARD_B[1]), "t": 0.24, "dir": 1.0, "pause": 0.0}]
	_place_guards(0.0)
	box.visible = false
	var s: Vector3 = campus(START)
	teleport_player(free_spot(s), yaw_of(campus(HANDOVER) - s))
	set_prompt("")
	_check_t = CHECK_S


func _tick(dt: float) -> void:
	_place_guards(dt)
	# the courier glances around (±50° around the buyer), the buyer fidgets
	var base: float = yaw_of(campus(BUYER) - campus(HANDOVER))
	courier.rotation.y = base + sin(clock * 0.55) * 0.87
	var in_window: bool = clock >= WINDOW.x and clock <= WINDOW.y
	box.visible = in_window
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - dt * 2.5)
	if photo_taken:
		set_info("Đã có ảnh. Giữ kín thêm %d giây" % int(ceil(DURATION - clock)))
		set_prompt("")
	else:
		set_info("Rình: %d / %d giây · Chưa có ảnh" % [int(clock), int(DURATION)])
		set_prompt(T_WINDOW if in_window else "")
	if clock > WINDOW.y and not photo_taken:
		fail(T_MISSED)
		return
	if clock >= DURATION and photo_taken:
		finish({"seen": seen_count, "photo": true})
		return
	_check_t -= dt
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	if watcher_sees():
		spotted()


## Moves the guards along their beats (a pause and a look back at each end).
func _place_guards(dt: float) -> void:
	for i: int in _g.size():
		var g: Dictionary = _g[i]
		var a: Vector3 = g["a"]
		var b: Vector3 = g["b"]
		var len_m: float = maxf(flat(a, b), 0.1)
		if float(g["pause"]) > 0.0:
			g["pause"] = float(g["pause"]) - dt
			CharacterBuilder.set_speed(guards[i], 0.0)
		else:
			var t: float = float(g["t"]) + float(g["dir"]) * GUARD_SPEED * dt / len_m
			if t >= 1.0 or t <= 0.0:
				t = clampf(t, 0.0, 1.0)
				g["dir"] = -float(g["dir"])
				g["pause"] = GUARD_PAUSE
			g["t"] = t
			CharacterBuilder.set_speed(guards[i], GUARD_SPEED if dt > 0.0 else 0.0)
		var p: Vector3 = a.lerp(b, float(g["t"]))
		guards[i].global_position = p
		var dir: Vector3 = (b - a) * float(g["dir"])
		guards[i].rotation.y = yaw_of(dir)


## Forward (flat) of a body facing -Z at its yaw.
static func fwd_of(n: Node3D) -> Vector3:
	return Vector3(-sin(n.rotation.y), 0.0, -cos(n.rotation.y))


## true when a guard or the courier sees the player (cone + clear ray, or right next to them).
func watcher_sees() -> bool:
	if player == null:
		return false
	for w: Node3D in [guards[0], guards[1], courier]:
		var eye: Vector3 = w.global_position + Vector3(0.0, 1.6, 0.0)
		if flat(w.global_position, player.global_position) < NEAR_M:
			return true
		if sees_player(eye, fwd_of(w), SIGHT_M, HALF_FOV_DEG):
			return true
	return false


## Seen: the stake-out restarts (no fail card: B-D5 "being seen restarts it").
func spotted() -> void:
	seen_count += 1
	popup(T_SEEN, 2.2, WARN)
	play_cue("record_scratch")
	_reset()


## [S]: photographs the courier when the handover is on, the courier in frame, close enough and in a clear line.
func take_photo() -> bool:
	if state != "running" or photo_taken:
		return false
	var cam: Camera3D = get_viewport().get_camera_3d()
	var chest: Vector3 = courier.global_position + Vector3(0.0, 1.2, 0.0)
	var in_frame: bool = cam != null and cam.is_position_in_frustum(chest)
	if not in_frame:
		return false
	photo_tries += 1
	if clock < WINDOW.x:
		popup(T_NOT_YET, 1.6)
		return false
	if flat(player.global_position, courier.global_position) > PHOTO_M:
		popup(T_TOO_FAR, 1.6)
		return false
	if not clear_line(cam.global_position, chest):
		popup(T_TOO_FAR, 1.6)
		return false
	photo_taken = true
	_flash.color.a = 0.9
	popup(T_PHOTO, 2.4, Color("#7CFFB2"))
	play_cue("success_fanfare", -6.0)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_S:
		take_photo()   # S also walks back: never consumed


func _cleanup() -> void:
	var all: Array = [courier, buyer, box]
	all.append_array(guards)
	for n: Variant in all:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	guards.clear()
