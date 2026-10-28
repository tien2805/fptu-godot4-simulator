# File: res://scripts/story/missions/MissionStakeout.gd
# Day 1 stake-out as a tension mini-game (spec B-D5 beat 3; Wave 2 rework, plan 2026-10-29-w2-early.md Task 4, master plan
# Q4b): the real D1 parking at night (FPTUCampusBuilder parking lane, v = 103.5). Shipper Mũ Đỏ meets a buyer at the far end
# of the lane with his back to the player; parked cars along the lane are the cover.
#   - The phone camera: hold [Q] or the right mouse button to raise it (a first-person viewfinder at eye height, zooming
#     in over ZOOM_S; walking stops while it is up). [E] / left click shoots. A CLEAR photo needs the courier's chest
#     within centre_deg() of the view, the view held still for steady_s(), a clear line and the courier within photo_m().
#     The handover has three moments (he checks the order on his phone, opens the box, hands it over): one clear photo
#     of each, three in all, wins. A blurred shot (not steady / not centred) clicks loudly: a little suspicion.
#   - He turns round: every moment ends with a telegraph (he freezes, a red "Hửm?" bubble, a heartbeat) for tell_s(),
#     then he looks back down the lane for look_s(), sweeping. While he looks, the SUSPICION meter fills when he sees
#     the player (a ray to the chest: standing 1.25 m, ducked 0.65 m; the parked cars block it). [Ctrl] ducks (a crouch
#     pose, slow walk; the phone then shoots from 1.0 m: over a car it is blocked). Full meter = "BỊ LỘ" (retry from the
#     start); the handover over (handover_s()) without the three photos = "TOANG!".
#   - Distractions: a guard walks the lane by from the far end at guard_at() (his own sight cone fills the meter too);
#     at bark_at() leaves rustle behind the player and chú Bảy's shiba Lu trots up and barks: the courier spins round
#     toward the bark at once (a short telegraph, bark_tell_s()). Lu's appearance sting is the mission ScareDirector's one
#     fake-out ("Giảm hù dọa": a soft sting, quieter cues); the bark itself comes every attempt.
# Sight checks run at 10 Hz. Every tuned number goes through Difficulty.pick(normal, easy).
# Tests: raise_phone(on), set duck_override, aim with the player's yaw / pitch, take_photo() returns
# "clear" | "blur" | "far" | "blocked" | "done" | "" (no phone / not running).
class_name MissionStakeout
extends StoryMission

const CHECK_S: float = 0.1
const ZOOM_S: float = 0.5
const PHONE_FOV: float = 52.0
const ZOOM_FOV: float = 24.0
const EYE_STAND: float = 1.55
const EYE_DUCK: float = 1.0
const CHEST_STAND: float = 1.25
const CHEST_DUCK: float = 0.65
const STEADY_DEG_S: float = 9.0              # the view counts as still below this turn rate
const HALF_FOV_DEG: float = 38.0
const NEAR_M: float = 3.0
const SWEEP_DEG: float = 35.0
const GUARD_SPEED: float = 1.6
const GUARD_HALF_DEG: float = 35.0
const DUCK_SPEED: float = 1.5
const BARK_LEAD: float = 1.4                 # rustle this long before Lu barks
const LU_BEHIND_M: float = 2.6
const MOMENTS: Array[String] = ["xem đơn trên điện thoại", "mở hộp hàng", "trao hộp hàng"]
## Campus-plot local spots (u, 0, v): the lane centre is v = 103.5; the courier faces +u (away from the player).
const HANDOVER := Vector3(122.0, 0.0, 103.5)
const BUYER := Vector3(123.5, 0.0, 103.5)
const START := Vector3(90.0, 0.0, 103.5)
const GUARD_PATH := [Vector3(138.0, 0.0, 103.5), Vector3(84.0, 0.0, 103.5)]
const CARS: Array[Vector3] = [Vector3(97.0, 0.0, 101.3), Vector3(104.0, 0.0, 101.3), Vector3(111.0, 0.0, 101.3),
	Vector3(100.5, 0.0, 105.7), Vector3(107.5, 0.0, 105.7), Vector3(114.5, 0.0, 105.7)]
const CAR_PAINT: Array[Color] = [Color("#C0392B"), Color("#DFE6E9"), Color("#2D3436"), Color("#2980B9"), Color("#BDC3C7"), Color("#16A085")]
const T_SEEN: String = "Hắn thấy mày rồi!"
const T_MISSED: String = "Giao hàng xong mất rồi, chưa đủ 3 ảnh."
const T_LO_REASON: String = "Shipper Mũ Đỏ nhìn thẳng vào mày: \"Ê, chụp gì đó?!\""
const T_PHOTO: String = "Ảnh rõ! (%d/3) %s"
const T_BLUR: String = "Ảnh mờ! Giữ yên máy, canh giữa shipper."
const T_TOO_FAR: String = "Xa quá, ảnh nhòe. Lại gần hơn (núp sau xe)."
const T_BLOCKED: String = "Bị che mất rồi, đổi góc khác."
const T_SAME: String = "Khoảnh khắc này chụp rồi, đợi cảnh tiếp theo."
const T_TELL: String = "Hắn sắp quay lại! NÚP [Ctrl]!"
const T_START: String = "Giơ điện thoại [Q] / chuột phải, [E] chụp. Chụp rõ 3 khoảnh khắc. Hắn quay lại thì núp sau xe [Ctrl]."
const T_LU: String = "Lu! Đừng sủa!!"
const T_GUARD: String = "Bảo vệ đi tuần tới! Núp sau xe!"
const T_WINDOW: String = "[E] Chụp"

var courier: Node3D
var buyer: Node3D
var guard: Node3D
var box: MeshInstance3D
var cars: Array[Node3D] = []
var bubble: Label3D
var scare: ScareDirector
var shiba: StoryShiba
## The courier's cycle: act (a moment, his back turned) -> tell -> look -> the next moment.
var phase: String = "act"
var phase_t: float = 0.0
var moment: int = 0
var photos: Array[bool] = [false, false, false]
var suspicion: float = 0.0
var seen_count: int = 0
var photo_tries: int = 0
var blurs: int = 0
var tells: int = 0
var barks: int = 0
var guard_walks: int = 0
var look_dir: Vector3 = Vector3(-1.0, 0.0, 0.0)
var phone_up: bool = false
var zoom_t: float = 0.0
var steady_t: float = 0.0
var phone_cam: Camera3D
var duck_override: Variant = null             # tests: true / false forces the duck, null reads [Ctrl]
var ducking: bool = false
var lu_state: String = ""                     # "" | rustle | barked | gone (per attempt)
var lu_shown: bool = false
var guard_state: String = ""                  # "" | walking | gone (per attempt, one walk per guard_at entry)
var guard_i: int = 0
var _guard_t: float = 0.0
var _lu_t: float = 0.0
var _check_t: float = 0.0
var _flash: ColorRect
var _finder: Control
var _finder_steady: ProgressBar
var _finder_text: Label
var _last_aim: Vector3 = Vector3.ZERO
var _pose: GunPose
var _want_phone: bool = false
var _won_t: float = -1.0


## Difficulty-tuned numbers (Thường, Dễ).
static func handover_s() -> float:
	return float(Difficulty.pick(80.0, 100.0))


static func photo_m() -> float:
	return float(Difficulty.pick(23.0, 28.0))


static func sight_m() -> float:
	return float(Difficulty.pick(27.0, 22.0))


static func centre_deg() -> float:
	return float(Difficulty.pick(3.0, 4.5))


static func steady_s() -> float:
	return float(Difficulty.pick(0.8, 0.5))


static func act_s() -> float:
	return float(Difficulty.pick(6.5, 8.0))


static func tell_s() -> float:
	return float(Difficulty.pick(0.8, 1.15))


static func look_s() -> float:
	return float(Difficulty.pick(2.8, 2.2))


static func bark_tell_s() -> float:
	return float(Difficulty.pick(0.55, 0.9))


static func fill_rate() -> float:
	return float(Difficulty.pick(70.0, 40.0))     # suspicion / s while he sees the player standing


static func guard_fill() -> float:
	return float(Difficulty.pick(55.0, 32.0))


static func guard_m() -> float:
	return float(Difficulty.pick(13.0, 10.0))


static func duck_seen_k() -> float:
	return float(Difficulty.pick(0.45, 0.3))      # seen while ducked in the open fills slower


static func decay() -> float:
	return float(Difficulty.pick(10.0, 16.0))


static func blur_sus() -> float:
	return float(Difficulty.pick(8.0, 4.0))


static func guard_at() -> Array:
	return Difficulty.pick([20.0, 56.0], [30.0])


static func bark_at() -> float:
	return float(Difficulty.pick(40.0, 55.0))


func _start() -> void:
	StoryAudio.warm(["success_fanfare", "rustle", "heartbeat", "record_scratch"])
	scare = ScareDirector.new()
	scare.loops_enabled = false
	scare.flicker_enabled = false
	scare.fake_budget = 1
	scare.reduce_scares = StoryUtil.reduce_scares()
	scare.player = player
	add_child(scare)
	var h: Vector3 = campus(HANDOVER)
	var bp: Vector3 = campus(BUYER)
	courier = spawn_body("courier_do", h, yaw_of(bp - h))
	buyer = spawn_body("clone", bp, yaw_of(h - bp), {"seed": 31})
	var scoot: Node3D = CineFX.build_prop("scooter", {"color": Color("#E74C3C")})
	add_child(scoot)
	scoot.global_position = campus(HANDOVER + Vector3(0.6, 0.0, 1.6))
	scoot.rotation.y = yaw_of(campus_dir(Vector3(1.0, 0.0, 0.0)))
	cars.append(scoot)
	for i: int in CARS.size():
		cars.append(_car(campus(CARS[i]), CAR_PAINT[i % CAR_PAINT.size()], i))
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
	bubble = Label3D.new()
	bubble.name = "Hmm"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 64
	bubble.pixel_size = 0.008
	bubble.outline_size = 12
	bubble.modulate = WARN
	bubble.position = Vector3(0.0, 2.35, 0.0)
	bubble.visible = false
	courier.add_child(bubble)
	phone_cam = Camera3D.new()
	phone_cam.name = "PhoneCam"
	phone_cam.near = 0.05
	phone_cam.fov = PHONE_FOV
	add_child(phone_cam)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_flash)
	_build_finder()
	if player and player.model:
		_pose = GunPose.attach(player.model)
	_reset()


## A parked car with collision (the cover), facing along the lane.
func _car(p: Vector3, col: Color, i: int) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "ParkedCar%d" % i
	body.add_to_group("slam_car")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.7, 1.5, 3.9)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.75, 0.0)
	body.add_child(cs)
	PropBuilder.build_car(body, col, true)
	add_child(body)
	body.global_position = Vector3(p.x, ground_y(p), p.z)
	body.rotation.y = yaw_of(campus_dir(Vector3(1.0, 0.0, 0.0))) + (0.06 if i % 2 == 0 else -0.04)
	return body


## The viewfinder overlay: corner brackets, a centre ring, a steadiness bar and a line.
func _build_finder() -> void:
	_finder = Control.new()
	_finder.name = "Viewfinder"
	_finder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finder.visible = false
	hud.add_child(_finder)
	var col := Color(1.0, 1.0, 1.0, 0.85)
	for c: Vector2 in [Vector2(0.18, 0.2), Vector2(0.82, 0.2), Vector2(0.18, 0.8), Vector2(0.82, 0.8)]:
		for horiz: bool in [true, false]:
			var r := ColorRect.new()
			r.color = col
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.anchor_left = c.x
			r.anchor_right = c.x
			r.anchor_top = c.y
			r.anchor_bottom = c.y
			var sx: float = -1.0 if c.x > 0.5 else 1.0
			var sy: float = -1.0 if c.y > 0.5 else 1.0
			if horiz:
				r.offset_left = minf(0.0, sx * 60.0)
				r.offset_right = maxf(0.0, sx * 60.0)
				r.offset_top = minf(0.0, sy * 4.0)
				r.offset_bottom = maxf(0.0, sy * 4.0)
			else:
				r.offset_left = minf(0.0, sx * 4.0)
				r.offset_right = maxf(0.0, sx * 4.0)
				r.offset_top = minf(0.0, sy * 60.0)
				r.offset_bottom = maxf(0.0, sy * 60.0)
			_finder.add_child(r)
	var ring := Label.new()
	ring.text = "[  +  ]"
	ring.add_theme_font_size_override("font_size", 30)
	ring.add_theme_color_override("font_color", col)
	ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ring.offset_left = -60.0
	ring.offset_right = 60.0
	ring.offset_top = -22.0
	ring.offset_bottom = 22.0
	ring.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finder.add_child(ring)
	_finder_steady = ProgressBar.new()
	_finder_steady.show_percentage = false
	_finder_steady.max_value = 1.0
	_finder_steady.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_finder_steady.offset_left = -80.0
	_finder_steady.offset_right = 80.0
	_finder_steady.offset_top = 34.0
	_finder_steady.offset_bottom = 44.0
	_finder_steady.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#7CFFB2")
	_finder_steady.add_theme_stylebox_override("fill", fill)
	_finder.add_child(_finder_steady)
	_finder_text = _label("", 18, col)
	_finder_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_finder_text.offset_left = -300.0
	_finder_text.offset_right = 300.0
	_finder_text.offset_top = -150.0
	_finder_text.offset_bottom = -120.0
	_finder.add_child(_finder_text)


func _reset() -> void:
	clock = 0.0
	photos = [false, false, false]
	suspicion = 0.0
	phase = "act"
	phase_t = 0.0
	moment = 0
	_won_t = -1.0
	steady_t = 0.0
	zoom_t = 0.0
	guard_i = 0
	guard_state = ""
	lu_state = ""
	_place_guard_off()
	if shiba != null and is_instance_valid(shiba):
		shiba.queue_free()
	shiba = null
	raise_phone(false)
	_want_phone = false
	bubble.visible = false
	box.visible = false
	_face_buyer()
	var s: Vector3 = campus(START)
	teleport_player(free_spot(s), yaw_of(campus(HANDOVER) - s))
	set_meter(0.0, "Nghi ngờ")
	set_prompt("")
	popup(T_START, 4.0, Color("#FFE66D"))
	_check_t = CHECK_S


func _place_guard_off() -> void:
	if guard != null and is_instance_valid(guard):
		guard.visible = false


func _face_buyer() -> void:
	courier.rotation.y = yaw_of(campus(BUYER) - campus(HANDOVER))


## Raise / lower the phone (tests call it; the keys set _want_phone).
func raise_phone(on: bool) -> void:
	if on == phone_up:
		return
	phone_up = on
	zoom_t = 0.0
	steady_t = 0.0
	if _finder:
		_finder.visible = on
	if player:
		player.move_lock = on
	if on:
		_update_phone_cam(0.0)
		if phone_cam.is_inside_tree():
			phone_cam.make_current()
	elif player and player.camera and player.camera.is_inside_tree() and phone_cam.current:
		player.camera.make_current()


## The view direction of the player's camera (controller yaw / pitch, as FootCamRig builds it).
func aim_dir() -> Vector3:
	if player == null:
		return Vector3.FORWARD
	return Basis.from_euler(Vector3(player.pitch, player.yaw, 0.0)) * Vector3(0.0, 0.0, -1.0)


func eye_pos() -> Vector3:
	return player.global_position + Vector3(0.0, EYE_DUCK if ducking else EYE_STAND, 0.0) if player else Vector3.ZERO


func courier_chest() -> Vector3:
	return courier.global_position + Vector3(0.0, 1.25, 0.0)


func _update_phone_cam(dt: float) -> void:
	zoom_t = minf(1.0, zoom_t + dt / ZOOM_S)
	var e: Vector3 = eye_pos()
	phone_cam.global_transform = Transform3D(Basis.from_euler(Vector3(player.pitch, player.yaw, 0.0)), e + aim_dir() * 0.25)
	phone_cam.fov = lerpf(PHONE_FOV, ZOOM_FOV, zoom_t * zoom_t * (3.0 - 2.0 * zoom_t))


## Degrees between the view and the courier's chest.
func off_centre_deg() -> float:
	var to: Vector3 = courier_chest() - eye_pos()
	if to.length_squared() < 0.01:
		return 0.0
	return rad_to_deg(aim_dir().angle_to(to.normalized()))


func _tick(dt: float) -> void:
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - dt * 2.5)
	if _won_t >= 0.0:
		_won_t -= dt
		if _won_t < 0.0:
			finish({"seen": seen_count, "photos": 3, "blurs": blurs})
		return
	ducking = bool(duck_override) if duck_override != null else (not manual and Input.is_physical_key_pressed(KEY_CTRL))
	if not manual and _want_phone != phone_up:
		raise_phone(_want_phone)
	_tick_duck()
	_tick_courier(dt)
	_tick_guard(dt)
	_tick_lu(dt)
	if phone_up:
		_update_phone_cam(dt)
		var aim: Vector3 = aim_dir()
		var rate: float = rad_to_deg(aim.angle_to(_last_aim)) / maxf(dt, 0.001) if _last_aim != Vector3.ZERO else 0.0
		_last_aim = aim
		if rate < STEADY_DEG_S and off_centre_deg() <= centre_deg():
			steady_t += dt
		else:
			steady_t = 0.0
		_finder_steady.value = clampf(steady_t / steady_s(), 0.0, 1.0)
		_finder_text.text = ("RÕ NÉT: [E] CHỤP" if steady_t >= steady_s() else "Giữ yên, canh giữa...") + "   x%.1f" % (PHONE_FOV / phone_cam.fov)
	else:
		_last_aim = Vector3.ZERO
	var left: float = handover_s() - clock
	set_info("Ảnh rõ: %d/3 · Còn %d giây · Cảnh: %s" % [photos.count(true), int(ceil(maxf(left, 0.0))), MOMENTS[moment] if phase == "act" else "hắn đang nhìn quanh"])
	set_prompt(T_WINDOW + " (giữ yên)" if phone_up else "[Q] / chuột phải: giơ điện thoại · [Ctrl] núp")
	_check_t -= dt
	if _check_t <= 0.0:
		_check_t = CHECK_S
		_sight(CHECK_S)
	if state != "running":
		return
	if clock >= handover_s():
		fail(T_MISSED)


func _tick_duck() -> void:
	if player == null:
		return
	player.combat_speed_cap = DUCK_SPEED if ducking else INF
	if _pose:
		if ducking:
			_pose.set_pose("cover_crouch")
		elif _pose.active():
			_pose.clear()


## The courier's cycle: act k (back turned, the moment's prop) -> tell -> look (sweeping toward the player's side).
func _tick_courier(dt: float) -> void:
	phase_t += dt
	match phase:
		"act":
			box.visible = moment >= 1
			_face_buyer()
			courier.rotation.y += sin(clock * 1.3) * 0.12
			if phase_t >= act_s():
				_begin_tell(tell_s(), Vector3.ZERO)
		"tell":
			if phase_t >= float(bubble.get_meta("tell_s", tell_s())):
				phase = "look"
				phase_t = 0.0
				bubble.text = "!"
		"look":
			var base: float = yaw_of(look_dir)
			courier.rotation.y = base + sin(phase_t / look_s() * TAU) * deg_to_rad(SWEEP_DEG)
			if phase_t >= look_s():
				phase = "act"
				phase_t = 0.0
				bubble.visible = false
				moment = (moment + 1) % 3
				while photos[moment] and photos.count(false) > 0:
					moment = (moment + 1) % 3


## The turn telegraph: freeze, the red bubble, a heartbeat, then he looks toward `toward` (ZERO = down the lane).
func _begin_tell(secs: float, toward: Vector3) -> void:
	phase = "tell"
	phase_t = 0.0
	tells += 1
	bubble.text = "Hửm?"
	bubble.visible = true
	bubble.set_meta("tell_s", secs)
	var lane_back: Vector3 = campus_dir(Vector3(-1.0, 0.0, 0.0))
	if toward != Vector3.ZERO:
		var d: Vector3 = toward - courier.global_position
		d.y = 0.0
		look_dir = d.normalized() if d.length() > 0.1 else lane_back
	else:
		look_dir = lane_back
	play_cue("heartbeat", -4.0)
	popup(T_TELL, secs + 0.4, WARN)


## A guard walks the lane by from the far end at each guard_at() time.
func _tick_guard(dt: float) -> void:
	var times: Array = guard_at()
	if guard_state != "walking" and guard_i < times.size() and clock >= float(times[guard_i]):
		guard_i += 1
		guard_state = "walking"
		guard_walks += 1
		_guard_t = 0.0
		if guard == null or not is_instance_valid(guard):
			guard = spawn_body("chu_bay", campus(GUARD_PATH[0]), 0.0, {"seed": 61, "name": "Guard"})
		guard.visible = true
		popup(T_GUARD, 2.4, Color("#FFE66D"))
	if guard_state != "walking":
		return
	_guard_t += dt
	var a: Vector3 = campus(GUARD_PATH[0])
	var b: Vector3 = campus(GUARD_PATH[1])
	var len_m: float = maxf(flat(a, b), 0.1)
	var u: float = clampf(_guard_t * GUARD_SPEED / len_m, 0.0, 1.0)
	var p: Vector3 = a.lerp(b, u)
	guard.global_position = Vector3(p.x, ground_y(p), p.z)
	guard.rotation.y = yaw_of(b - a) + sin(_guard_t * 0.9) * 0.5   # glancing left and right
	CharacterBuilder.set_speed(guard, GUARD_SPEED)
	if u >= 1.0:
		guard_state = "gone"
		guard.visible = false


## Lu: rustle behind the player, then the shiba trots up and barks: the courier spins toward the bark.
func _tick_lu(dt: float) -> void:
	match lu_state:
		"":
			if clock >= bark_at() - BARK_LEAD:
				lu_state = "rustle"
				_lu_t = BARK_LEAD
				play_cue("rustle", -3.0)
		"rustle":
			_lu_t -= dt
			if _lu_t <= 0.0:
				_lu_bark()
		"barked":
			_lu_t -= dt
			if shiba != null and is_instance_valid(shiba) and _lu_t <= 0.0:
				shiba.queue_free()
				shiba = null
				lu_state = "gone"


func _lu_bark() -> void:
	lu_state = "barked"
	barks += 1
	_lu_t = 3.0
	var yaw: float = player.facing_yaw() if player.has_method("facing_yaw") else player.rotation.y
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var p: Vector3 = free_spot(player.global_position + back * LU_BEHIND_M, 2)
	p.y = ground_y(p)
	shiba = StoryCast.build("shiba") as StoryShiba
	add_child(shiba)
	shiba.global_position = p
	shiba.rotation.y = yaw_of(campus(HANDOVER) - p)
	shiba.play("idle")
	if not lu_shown and scare.try_fake_out("shiba"):
		scare.fake_sting(-12.0)
	lu_shown = true
	MissionSfx.play(self, "bark", -2.0)
	cues_played.append("bark")
	popup(T_LU, 2.0, StoryCast.color("shiba"))
	if phase != "look":
		_begin_tell(bark_tell_s(), p)


## Sight at 10 Hz: the courier while he looks (and right next to him), the walking guard; the meter decays otherwise.
func _sight(dt: float) -> void:
	var fill: float = 0.0
	if courier and flat(courier.global_position, player.global_position) < NEAR_M:
		fill = 300.0
	elif phase == "look":
		var eye: Vector3 = courier.global_position + Vector3(0.0, 1.6, 0.0)
		var f: Vector3 = Vector3(-sin(courier.rotation.y), 0.0, -cos(courier.rotation.y))
		var seen: int = seen_by(eye, f, sight_m(), HALF_FOV_DEG)
		if seen > 0:
			fill = fill_rate() * (1.0 if seen == 2 else duck_seen_k())
	if guard_state == "walking" and guard != null:
		var geye: Vector3 = guard.global_position + Vector3(0.0, 1.6, 0.0)
		var gf: Vector3 = Vector3(-sin(guard.rotation.y), 0.0, -cos(guard.rotation.y))
		var gs: int = seen_by(geye, gf, guard_m(), GUARD_HALF_DEG)
		if gs > 0:
			fill = maxf(fill, guard_fill() * (1.0 if gs == 2 else duck_seen_k()))
		if flat(guard.global_position, player.global_position) < 1.6:
			fill = 300.0
	if fill > 0.0:
		add_suspicion(fill * dt)
	else:
		add_suspicion(-decay() * dt)


## 0 = not seen, 1 = seen ducked, 2 = seen standing: within range and the cone, and a clear line to the player's chest
## (ducked: 0.65 m, so a parked car between hides them).
func seen_by(eye: Vector3, fwd: Vector3, range_m: float, half_deg: float) -> int:
	if player == null:
		return 0
	var chest: Vector3 = player.global_position + Vector3(0.0, CHEST_DUCK if ducking else CHEST_STAND, 0.0)
	var d := Vector3(chest.x - eye.x, 0.0, chest.z - eye.z)
	var dist: float = d.length()
	if dist > range_m:
		return 0
	if dist > 0.01 and fwd.dot(d / dist) < cos(deg_to_rad(half_deg)):
		return 0
	if not clear_line(eye, chest):
		return 0
	return 1 if ducking else 2


func add_suspicion(v: float) -> void:
	var before: float = suspicion
	suspicion = clampf(suspicion + v, 0.0, 100.0)
	set_meter(suspicion)
	if v > 0.0 and before < 1.0 and suspicion >= 1.0:
		seen_count += 1
		popup(T_SEEN, 1.4, WARN)
	if suspicion >= 100.0 and state == "running":
		raise_phone(false)
		play_cue("record_scratch")
		fail(T_LO_REASON, T_LO)


## [E]: a photo through the raised phone. "clear" counts the current moment; see the header for the other results.
func take_photo() -> String:
	if state != "running" or not phone_up or _won_t >= 0.0:
		return ""
	photo_tries += 1
	_flash.color.a = 0.55
	MissionSfx.play(self, "shutter", -4.0)
	cues_played.append("shutter")
	var dist: float = flat(player.global_position, courier.global_position)
	if dist > photo_m():
		popup(T_TOO_FAR, 1.6)
		return "far"
	if steady_t < steady_s() or off_centre_deg() > centre_deg() or zoom_t < 0.9:
		blurs += 1
		popup(T_BLUR, 1.6, WARN)
		add_suspicion(blur_sus())
		return "blur"
	if not clear_line(eye_pos() + aim_dir() * 0.3, courier_chest()):
		popup(T_BLOCKED, 1.6)
		return "blocked"
	if phase != "act" or photos[moment]:
		popup(T_SAME, 1.6)
		return "done"
	photos[moment] = true
	popup(T_PHOTO % [photos.count(true), MOMENTS[moment]], 2.2, Color("#7CFFB2"))
	if photos.count(true) >= 3:
		play_cue("success_fanfare", -6.0)
		raise_phone(false)
		_won_t = 1.2
	return "clear"


func _unhandled_input(event: InputEvent) -> void:
	if state != "running":
		return
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.echo:
			return
		if k.physical_keycode == KEY_Q:
			_want_phone = k.pressed
			if manual:
				raise_phone(k.pressed)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_E and k.pressed:
			take_photo()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_want_phone = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and phone_up:
			take_photo()
			get_viewport().set_input_as_handled()


func _cleanup() -> void:
	raise_phone(false)
	if player and is_instance_valid(player):
		player.move_lock = false
	if _pose and is_instance_valid(_pose):
		_pose.queue_free()
	_pose = null
	var all: Array = [courier, buyer, box, shiba, guard, phone_cam]
	all.append_array(cars)
	for n: Variant in all:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	cars.clear()
