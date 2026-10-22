# File: res://scripts/cine/CineBrawl.gd
# WIP – DỪNG GIỮA CHỪNG (chủ dự án đổi hướng: cảnh mẫu sẽ dựng lại trên mocap Mixamo + timeline dữ liệu). Dàn cảnh,
# máy quay và hiệu ứng mới ở mức phác thảo, chưa tinh chỉnh; còn lỗi đã biết: một đốm sáng mềm ở sát đất dưới cú đá bay
# (chưa rõ nguồn), vòng sóng xung kích quá to, cú đá bay chưa chạm ngực shipper 1. Xem docs/proto_cine_report.md.
# NGUYÊN MẪU segment cinematic "seg_d1_brawl" (spec TOOL ĐEN mục 8.1, slot 25 s: "three couriers down, punchy"):
# 25.0 s thực, slow-motion có dốc tốc độ, đóng băng khi trúng đòn, người PS2 thật của game, góc hẻm đêm neon dựng bằng code.
# Mục đích: chủ dự án xem animation trong engine đủ đẹp chưa trước khi lên kế hoạch 20 cảnh – KHÔNG phải hệ thống cutscene.
#
# Thời gian: r = giây thực (video / nhạc), s = giây truyện (CineTimeWarp). Diễn viên, hiệu ứng, mảnh vỡ chạy theo s; máy quay
# chạy theo r (máy vẫn bay quanh khi slow-mo / đóng băng = "bullet time"). Mỗi cú đánh: tiếng "tick" tổng hợp đúng giây thực
# của cú chạm để nghe được nhịp khi ghép nhạc; bảng nhịp ghi ra docs/cinematics/seg_d1_brawl.txt (CINE_WRITE_BEATS=1).
#
# Chạy: godot --path . scenes/proto/CineBrawl.tscn
# Quay video: godot --path . --resolution 1280x720 --write-movie docs/preview/proto_seg_d1_brawl.avi --fixed-fps 30 scenes/proto/CineBrawl.tscn
# Biến môi trường (chỉ nguyên mẫu): CINE_SEEK="1.5,3.2" (chụp ảnh tĩnh tại các giây thực rồi thoát), CINE_SEEK_S (tại giây
# truyện), PREVIEW_DIR (thư mục ảnh), CINE_DEBUG=1 (lớp phủ r / s / tốc độ / nhịp), CINE_WRITE_BEATS=1.
extends Node3D

const LENGTH: float = 25.0
const SLOT: String = "seg_d1_brawl"
const BEATS_FILE: String = "res://docs/cinematics/seg_d1_brawl.txt"

# --- các cú đánh (giây truyện)
const H1: float = 1.80    # đá bay vào shipper 1
const H2: float = 3.18    # jab vào shipper 2
const H3: float = 3.43    # cross
const H4: float = 3.845   # móc (hook) – shipper 2 gục
const A1: float = 5.00    # trượt dưới cú vung của shipper 3 (nhấn nhịp, không trúng)
const H5: float = 6.20    # đá xoay vào shipper 3
const H6: float = 6.62    # shipper 3 đâm vỡ chồng thùng
const H7: float = 8.45    # cắt kéo Vovinam quật ngã shipper 1

var warp: CineTimeWarp
var hero: CineActor
var c1: CineActor
var c2: CineActor
var c3: CineActor
var actors: Array[CineActor] = []
var set_refs: Dictionary = {}
var cam: Camera3D
var shots: Array = []          # [{r0, fn: Callable(lr, r, s) -> [pos, look, fov]}]
var impulses: Array = []       # [{r, amp, whip: Vector2, fov}] rung / lia máy / zoom theo giây thực
var events: Array = []         # [{s, fn, done}]
var bursts: Array = []         # CPUParticles3D đang dùng (speed_scale theo tốc độ truyện)
var ticks: Array = []          # [{r, kind, done}]
var r: float = 0.0
var prev_s: float = -1.0
var frame: int = 0
var seek_list: Array = []
var seek_dir: String = ""
var debug_label: Label
var fade_rect: ColorRect
var flash_rect: ColorRect
var vignette: TextureRect
var bars: Array[ColorRect] = []
var tick_player: AudioStreamPlayer
var accent_player: AudioStreamPlayer
var phone: Node3D
var phone_screen: MeshInstance3D
var stars: Node3D
var soft_tex: Texture2D
var spark_tex: Texture2D


func _ready() -> void:
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	_build_timewarp()
	_build_world()
	_build_actors()
	_script_hero()
	_script_c1()
	_script_c2()
	_script_c3()
	_build_props()
	_build_events()
	_build_shots()
	_build_overlay()
	_build_audio()
	_apply_look()
	if OS.get_environment("CINE_WRITE_BEATS") == "1":
		_write_beats()
	var sk: String = OS.get_environment("CINE_SEEK")
	var sks: String = OS.get_environment("CINE_SEEK_S")
	for v: String in sk.split(",", false):
		seek_list.append(float(v))
	for v: String in sks.split(",", false):
		seek_list.append(warp.real_at(float(v)) + 0.001)
	var pd: String = OS.get_environment("PREVIEW_DIR")
	seek_dir = pd if pd != "" else ProjectSettings.globalize_path("user://preview")
	if not seek_list.is_empty():
		DirAccess.make_dir_recursive_absolute(seek_dir)
	print("CINE %s: length %.2f s real, story %.2f s, %d hits" % [SLOT, LENGTH, warp.s_end, warp.hits.size()])
	_update(0.0)


# ===========================================================================
# ĐỒNG HỒ SLOW-MO
# ===========================================================================
func _build_timewarp() -> void:
	warp = CineTimeWarp.new()
	warp.length = LENGTH
	#            s     k     pre   post  freeze  tên
	warp.add_hit(H1, 0.28, 0.38, 0.50, 0.18, "H1 flying kick -> courier 1 launched", 0.10, 0.16)
	warp.add_hit(H2, 0.55, 0.04, 0.08, 0.07, "H2 jab", 0.05, 0.08)
	warp.add_hit(H3, 0.50, 0.04, 0.10, 0.08, "H3 cross", 0.05, 0.08)
	warp.add_hit(H4, 0.28, 0.08, 0.42, 0.16, "H4 hook -> courier 2 spins down", 0.06, 0.16)
	warp.add_hit(A1, 0.30, 0.18, 0.22, 0.0, "A1 slide under the swing (near miss, accent)", 0.10, 0.14)
	warp.add_hit(H5, 0.30, 0.10, 0.26, 0.14, "H5 spinning kick -> courier 3", 0.08, 0.10)
	warp.add_hit(H6, 0.25, 0.06, 0.55, 0.20, "H6 courier 3 smashes the crates", 0.06, 0.18)
	warp.add_hit(H7, 0.26, 0.40, 0.45, 0.20, "H7 Vovinam scissor-kick takedown", 0.10, 0.20)
	warp.build()


# ===========================================================================
# THẾ GIỚI
# ===========================================================================
func _build_world() -> void:
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	add_child(we)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	set_refs = CineAlley.build(self)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 300.0
	add_child(cam)
	cam.current = true
	soft_tex = _radial_tex(64, 1.6)
	spark_tex = _radial_tex(32, 3.0)


## Ánh sáng / môi trường "night" của game (ViceStyle) + đất ướt phản chiếu (SSR) cho phim trường nhỏ.
func _apply_look() -> void:
	ViceStyle.apply(self, "night", 2, false)
	var we: WorldEnvironment = get_child(0) as WorldEnvironment
	var env: Environment = we.environment
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.5
	env.ssr_depth_tolerance = 0.3
	env.ambient_light_energy = 0.42
	env.glow_intensity = 0.85
	env.glow_hdr_threshold = 1.1
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 60.0
	env.fog_density = 0.55


static func _radial_tex(size: int, power: float) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = (float(size) - 1.0) * 0.5
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(float(x) - c, float(y) - c).length() / c
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), power)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


# ===========================================================================
# DIỄN VIÊN
# ===========================================================================
func _build_actors() -> void:
	hero = _actor("Hero", {"preset": "player", "seed": 31, "height": 1.0, "female": false, "hair_style": "spiky", "skin": 1})
	var courier: Dictionary = {"preset": "rider", "shirt_color": Color("#2fb3a0"), "trousers_color": Color("#262a3a"), "backpack": false,
		"glasses": false, "helmet_color": Color("#2fb3a0"), "female": false}
	var o1: Dictionary = courier.duplicate()
	o1["seed"] = 101
	o1["height"] = 1.02
	o1["helmet_color"] = Color("#f2c14e")
	c1 = _actor("Courier1", o1)
	var o2: Dictionary = courier.duplicate()
	o2["seed"] = 202
	o2["height"] = 1.06
	o2["body_width"] = 1.12
	c2 = _actor("Courier2", o2)
	var o3: Dictionary = courier.duplicate()
	o3["seed"] = 303
	o3["height"] = 0.98
	o3["helmet_color"] = Color("#ff6f91")
	c3 = _actor("Courier3", o3)


func _actor(nm: String, opts: Dictionary) -> CineActor:
	var a := CineActor.new()
	a.name = nm
	add_child(a)
	a.setup(opts)
	actors.append(a)
	return a


static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z)


static func sm(u: float) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# --- vị trí dàn cảnh (m): hẻm dọc X, máy quay chủ yếu ở phía +Z
const RUN_Z: float = -0.3
const C1_P0: Vector3 = Vector3(0.75, 0.0, -0.32)      # shipper 1 đứng đầu tiên
const C3_SWING: Vector3 = Vector3(1.3, 0.0, -0.9)     # shipper 3 vung tay ở đây
const P_KICK: Vector3 = Vector3(2.15, 0.0, -0.28)     # nhân vật chính đá xoay từ đây (thẳng hàng shipper 3 -> chồng thùng)
const C1_DOWN: Vector3 = Vector3(4.0, 0.0, -1.0)      # shipper 1 nằm sau cú đá bay


# --- NHÂN VẬT CHÍNH (sinh viên FPT) ------------------------------------------
func _script_hero() -> void:
	var a: CineActor = hero
	var fwd: float = -PI * 0.5   # nhìn về +X
	# chạy nước rút vào hẻm
	a.clip(0.0, "ual1", "Sprint", 0.1, 0.8, true)
	a.key(0.0, Vector3(-9.6, 0.0, RUN_Z), fwd)
	a.key(1.08, Vector3(-2.75, 0.0, RUN_Z), fwd, Vector3.ZERO, "linear")
	# bật nhảy (NinjaJump) -> đá bay
	a.clip(1.04, "ual2", "NinjaJump_Start", 0.16, 1.0, false, 0.08)
	a.key(1.14, Vector3(-2.45, 0.0, RUN_Z), fwd, Vector3.ZERO, "linear")
	a.key(H1, Vector3(-0.62, 0.05, RUN_Z), fwd, Vector3.ZERO, "linear", 0.5)
	a.override(1.42, H1 + 0.08, _pose_flying_kick, 0.14, 0.2)
	a.expr(1.0, "angry")
	# rơi xuống, tiếp đất, thủ thế
	a.clip(H1 + 0.16, "ual2", "NinjaJump_Land", 0.14, 1.1, false, 0.14)
	a.key(2.16, Vector3(-0.38, 0.0, RUN_Z), fwd, Vector3.ZERO, "in")
	a.clip(2.46, "ual1", "Punch_Enter", 0.36, 1.0, false, 0.24)
	a.key(2.62, Vector3(-0.28, 0.0, -0.33), fwd)
	# né cú móc của shipper 2 (ngả người ra sau) rồi phản đòn jab - cross - móc
	a.key(2.92, Vector3(-0.48, 0.0, -0.34), fwd)
	a.override(2.66, 2.96, func(u: float) -> Dictionary: return {"torso": Vector3(0.42 * sin(u * PI), 0.0, 0.0), "head": Vector3(0.2 * sin(u * PI), 0.0, 0.0)}, 0.06, 0.1, "add")
	a.clip(3.05, "ual1", "Punch_Jab", 0.06, 1.0, false, 0.08)
	a.key(H2, Vector3(-0.2, 0.0, -0.33), fwd)
	a.clip(3.30, "ual1", "Punch_Cross", 0.12, 1.0, false, 0.08)
	a.key(H3, Vector3(-0.05, 0.0, -0.33), fwd)
	a.clip(3.60, "ual2", "Melee_Hook", 0.0, 1.0, false, 0.1)
	a.key(3.60, Vector3(-0.05, 0.0, -0.33), fwd)
	a.clip(4.10, "ual2", "Melee_Hook_Rec", 0.0, 1.0, false, 0.12)
	a.key(4.12, Vector3(0.05, 0.0, -0.33), fwd)
	# trượt dưới cú vung của shipper 3 (shipper 3 ở bên trái đường trượt)
	a.key(4.46, Vector3(0.1, 0.0, -0.33), fwd)
	a.clip(4.48, "ual2", "Slide_Start", 0.08, 1.0, false, 0.1)
	a.key(5.22, Vector3(2.0, 0.0, -0.3), fwd, Vector3.ZERO, "out")
	a.clip(5.18, "ual2", "Slide_Exit", 0.0, 1.0, false, 0.08)
	# bật dậy sau lưng shipper 3, xoay người đá (đá xoay hậu)
	a.clip(5.62, "ual1", "Punch_Enter", 0.4, 1.0, false, 0.16)
	a.key(5.66, P_KICK, fwd)
	var face_c3: float = yaw_to(P_KICK, C3_SWING)
	a.key(5.86, P_KICK, fwd + 0.25)
	a.clip(5.92, "native", "Kick_Right", 0.22, 1.05, false, 0.1)
	a.key(H5, P_KICK + Vector3(-0.08, 0.0, -0.03), face_c3, Vector3.ZERO, "linear")
	a.override(5.95, H5 + 0.06, _pose_spin_kick, 0.1, 0.18)
	a.key(6.5, P_KICK + Vector3(-0.1, 0.0, -0.04), face_c3 + 0.25, Vector3.ZERO, "out")
	a.clip(6.42, "ual1", "Punch_Enter", 0.45, 1.0, false, 0.2)
	# đòn kết: shipper 1 lao tới -> cắt kéo Vovinam
	var face_c1: float = yaw_to(P_KICK, C1_DOWN)
	a.key(6.95, P_KICK + Vector3(-0.1, 0.0, -0.04), face_c3 + 0.25)
	a.key(7.32, P_KICK, face_c1)
	a.clip(7.38, "ual1", "Sprint", 0.3, 0.75, true, 0.12)
	var jump_p: Vector3 = P_KICK + (C1_DOWN - P_KICK).normalized() * 0.55
	a.key(7.64, jump_p, face_c1, Vector3.ZERO, "in")
	a.clip(7.62, "ual2", "NinjaJump_Start", 0.18, 1.0, false, 0.08)
	# trên không: xoay 90° cho shipper 1 nằm bên phải, nghiêng nằm ngang (spin z), chân mở kéo
	var lock_p: Vector3 = C1_DOWN + Vector3(-0.85, 0.55, 0.42)
	a.key(8.02, lock_p, face_c1 - PI * 0.5, Vector3(0.0, 0.0, 1.35), "out")
	a.override(7.76, 8.42, _pose_scissor, 0.1, 0.14)
	a.key(H7, C1_DOWN + Vector3(-0.55, 0.0, 0.5), face_c1 - PI * 0.5 - 0.6, Vector3(0.0, 0.0, 1.55), "in")
	# tiếp đất nằm nghiêng -> lăn ngửa -> đứng dậy
	a.clip(H7 + 0.02, "ual2", "LayToIdle", 0.1, 0.0, false, 0.3)
	a.key(8.95, C1_DOWN + Vector3(-0.65, 0.0, 0.5), face_c1 - PI * 0.5 - 0.6, Vector3.ZERO, "smooth")
	a.clip(8.95, "ual2", "LayToIdle", 0.1, 1.25, false, 0.0)
	a.key(10.1, C1_DOWN + Vector3(-0.75, 0.0, 0.55), face_c1 - 0.4, Vector3.ZERO, "smooth")
	a.clip(10.1, "ual2", "Idle_FoldArms", 0.0, 1.0, true, 0.35)
	a.expr(9.4, "happy")


## Đá bay: chân phải duỗi thẳng ra trước (đá thẳng / đá tống), chân trái co, thân ngả sau, tay giữ thăng bằng.
func _pose_flying_kick(u: float) -> Dictionary:
	var e: float = sm(u / 0.86)
	return {
		"thigh_r": Vector3(lerpf(1.05, 1.62, e), 0.0, -0.08),
		"knee_r": Vector3(lerpf(-1.9, -0.02, e), 0.0, 0.0),
		"foot_r": Vector3(lerpf(0.4, -0.25, e), 0.0, 0.0),
		"thigh_l": Vector3(lerpf(0.9, 0.75, e), 0.0, 0.18),
		"knee_l": Vector3(-2.1, 0.0, 0.0),
		"torso": Vector3(lerpf(-0.1, 0.38, e), lerpf(0.0, 0.25, e), 0.0),
		"head": Vector3(lerpf(0.0, -0.3, e), 0.0, 0.0),
		"shoulder_l": Vector3(lerpf(0.9, 0.35, e), 0.0, lerpf(0.0, -0.95, e)),
		"elbow_l": Vector3(lerpf(1.6, 0.7, e), 0.0, 0.0),
		"shoulder_r": Vector3(lerpf(0.9, -0.55, e), 0.0, lerpf(0.0, 0.75, e)),
		"elbow_r": Vector3(lerpf(1.6, 0.5, e), 0.0, 0.0),
	}


## Đá xoay: nâng đùi phải cao hơn clip Kick_Right, duỗi gối ở đỉnh, thân nghiêng đối trọng.
func _pose_spin_kick(u: float) -> Dictionary:
	var e: float = sm(u / 0.8)
	return {
		"thigh_r": Vector3(lerpf(0.9, 1.5, e), 0.0, lerpf(-0.2, -0.95, e)),
		"knee_r": Vector3(lerpf(-1.6, -0.05, e), 0.0, 0.0),
		"torso": Vector3(lerpf(0.0, 0.32, e), 0.0, lerpf(0.0, 0.42, e)),
		"head": Vector3(0.0, 0.0, lerpf(0.0, -0.35, e)),
		"shoulder_l": Vector3(0.6, 0.0, lerpf(0.3, -0.8, e)),
		"elbow_l": Vector3(1.4, 0.0, 0.0),
		"shoulder_r": Vector3(0.3, 0.0, lerpf(-0.3, 0.9, e)),
		"elbow_r": Vector3(1.0, 0.0, 0.0),
	}


## Cắt kéo (Vovinam đòn chân tấn công): thân nằm ngang trên không (spin), chân trước quét ngang ngực đối thủ, chân sau
## móc sau gối; hai chân khép lại như lưỡi kéo ở nửa sau.
func _pose_scissor(u: float) -> Dictionary:
	var open_k: float = sm(u / 0.4)
	var close_k: float = sm((u - 0.42) / 0.3)
	var spread: float = open_k * (1.0 - 0.75 * close_k)
	return {
		"thigh_r": Vector3(0.2 + 1.35 * spread, 0.0, -0.1),
		"knee_r": Vector3(-0.15, 0.0, 0.0),
		"thigh_l": Vector3(0.2 - 0.95 * spread, 0.0, 0.1),
		"knee_l": Vector3(-0.35 - 0.4 * close_k, 0.0, 0.0),
		"torso": Vector3(-0.15, 0.0, 0.0),
		"head": Vector3(0.0, -0.4, 0.0),
		"shoulder_l": Vector3(1.6, 0.0, -0.4),
		"elbow_l": Vector3(0.3, 0.0, 0.0),
		"shoulder_r": Vector3(1.9, 0.0, 0.5),
		"elbow_r": Vector3(0.25, 0.0, 0.0),
	}


# --- SHIPPER 1 (bị đá bay, sau đó lao lại và dính cắt kéo; điện thoại rơi ra) ---------------
func _script_c1() -> void:
	var a: CineActor = c1
	a.clip(0.0, "ual1", "Idle", 0.4, 1.0, true)
	a.key(0.0, C1_P0, PI * 0.5 + 0.35)
	a.key(0.9, C1_P0, PI * 0.5 + 0.35)
	a.key(1.4, C1_P0, PI * 0.5, Vector3.ZERO, "smooth")
	a.clip(1.15, "ual1", "Punch_Enter", 0.0, 1.0, false, 0.25)
	a.expr(1.2, "surprised")
	# trúng đá bay: bay ngược ra sau, trượt trên đất ướt
	a.clip(H1, "ual2", "Hit_Knockback", 0.04, 0.85, false, 0.05)
	a.expr(H1, "pain")
	a.key(H1, C1_P0, PI * 0.5)
	a.key(2.34, Vector3(3.15, 0.05, -0.85), PI * 0.5 + 0.25, Vector3.ZERO, "linear", 0.75)
	a.key(2.95, C1_DOWN, PI * 0.5 + 0.3, Vector3.ZERO, "out")
	a.expr(2.9, "closed")
	# đứng dậy (lúc shipper 3 bị đá) rồi lao vào nhân vật chính
	var at_hero: float = yaw_to(C1_DOWN, P_KICK)
	a.clip(6.0, "ual2", "LayToIdle", 0.1, 1.15, false, 0.35)
	a.expr(6.6, "angry")
	a.key(6.6, C1_DOWN, PI * 0.5 + 0.3)
	a.key(7.2, C1_DOWN, at_hero)
	a.clip(7.4, "ual1", "Jog_Fwd", 0.1, 1.1, true, 0.15)
	a.key(7.45, C1_DOWN, at_hero)
	a.key(8.04, C1_DOWN + (P_KICK - C1_DOWN).normalized() * 0.45, at_hero, Vector3.ZERO, "linear")
	# dính cắt kéo: bị quật ngửa ra sau
	a.clip(8.04, "ual2", "Hit_Knockback", 0.1, 0.9, false, 0.06)
	a.expr(8.04, "pain")
	a.key(H7, C1_DOWN + Vector3(0.3, 0.0, -0.05), at_hero - 0.3, Vector3.ZERO, "in")
	a.key(9.0, C1_DOWN + Vector3(0.45, 0.0, -0.08), at_hero - 0.35, Vector3.ZERO, "out")
	a.expr(H7, "closed")
	a.expr(9.6, "done")
	# choáng: đầu lắc lư
	a.override(9.2, 30.0, func(u: float) -> Dictionary: return {"head": Vector3(0.0, 0.35 * sin(u * 70.0), 0.12 * sin(u * 45.0))}, 0.3, 0.0, "add")


# --- SHIPPER 2 (to con: móc hụt, ăn jab - cross - móc, xoay người gục) -------------------
func _script_c2() -> void:
	var a: CineActor = c2
	var p0 := Vector3(1.9, 0.0, -1.65)
	var at_hero: float = yaw_to(Vector3(0.9, 0.0, -0.4), Vector3(-0.3, 0.0, -0.33))
	a.clip(0.0, "ual2", "Idle_FoldArms", 0.6, 1.0, true)
	a.key(0.0, p0, PI * 0.5 - 0.5)
	a.key(1.2, p0, PI * 0.5 - 0.5)
	a.key(1.7, p0, PI * 0.5 - 0.1)
	a.clip(1.5, "ual1", "Punch_Enter", 0.0, 1.0, false, 0.3)
	a.expr(1.9, "angry")
	# xông vào, móc hụt
	a.clip(2.2, "ual1", "Jog_Fwd", 0.2, 1.0, true, 0.15)
	a.key(2.2, p0, PI * 0.5 - 0.1)
	a.key(2.56, Vector3(0.95, 0.0, -0.4), at_hero, Vector3.ZERO, "linear")
	a.clip(2.56, "ual2", "Melee_Hook", 0.02, 1.0, false, 0.08)
	a.key(2.95, Vector3(0.75, 0.0, -0.38), at_hero, Vector3.ZERO, "out")
	# ăn đòn
	a.clip(H2, "ual1", "Hit_Head", 0.0, 1.0, false, 0.06)
	a.expr(H2, "pain")
	a.key(H2, Vector3(0.62, 0.0, -0.36), at_hero)
	a.key(3.32, Vector3(0.72, 0.0, -0.36), at_hero, Vector3.ZERO, "out")
	a.clip(H3, "ual1", "Hit_Chest", 0.0, 1.0, false, 0.05)
	a.key(H3, Vector3(0.72, 0.0, -0.36), at_hero)
	a.key(3.62, Vector3(0.92, 0.0, -0.35), at_hero, Vector3.ZERO, "out")
	a.clip(H4, "ual1", "Hit_Head", 0.05, 0.7, false, 0.04)
	a.key(H4, Vector3(0.92, 0.0, -0.35), at_hero)
	a.clip(4.02, "ual1", "Death01", 0.72, 1.25, false, 0.16)
	a.key(4.6, Vector3(1.25, 0.0, 0.75), at_hero + 2.6, Vector3.ZERO, "out")
	a.expr(4.3, "closed")


# --- SHIPPER 3 (vung tay hụt khi nhân vật chính trượt qua, ăn đá xoay, đâm vào thùng) -------------
func _script_c3() -> void:
	var a: CineActor = c3
	var p0 := Vector3(3.3, 0.0, -2.3)
	var at_hero: float = yaw_to(C3_SWING, Vector3(0.6, 0.0, -0.33))
	a.clip(0.0, "ual2", "Idle_No", 0.0, 1.0, true)
	a.key(0.0, p0, PI * 0.5 + 0.2)
	a.key(1.6, p0, PI * 0.5 + 0.2)
	a.key(2.1, p0, PI * 0.5 - 0.2)
	a.clip(1.9, "ual1", "Punch_Enter", 0.0, 1.0, false, 0.3)
	a.expr(1.95, "surprised")
	a.expr(4.0, "angry")
	# xông vào, vung tay (Sword_Attack không kiếm = cú quét tay hết cỡ)
	a.clip(4.1, "ual1", "Jog_Fwd", 0.0, 1.0, true, 0.15)
	a.key(4.1, p0, PI * 0.5 - 0.2)
	a.key(4.62, C3_SWING, at_hero, Vector3.ZERO, "out")
	a.clip(4.62, "ual1", "Sword_Attack", 0.0, 1.0, false, 0.1)
	# quay lại tìm
	a.clip(5.4, "ual1", "Idle", 0.0, 1.0, true, 0.3)
	a.key(5.4, C3_SWING, at_hero)
	var at_back: float = yaw_to(C3_SWING, P_KICK)
	a.key(5.95, C3_SWING, at_back, Vector3.ZERO, "smooth")
	a.expr(5.7, "surprised")
	# ăn đá xoay -> bay vào chồng thùng
	a.clip(H5, "ual2", "Hit_Knockback", 0.03, 0.85, false, 0.05)
	a.expr(H5, "pain")
	a.key(H5, C3_SWING, at_back)
	var dir: Vector3 = (CineAlley.CRATE_POS - C3_SWING).normalized()
	var crash: Vector3 = CineAlley.CRATE_POS - dir * 0.55
	a.key(H6, crash + Vector3(0.0, 0.25, 0.0), at_back, Vector3.ZERO, "linear", 0.35)
	a.key(7.2, CineAlley.CRATE_POS - dir * 0.1, at_back + 0.3, Vector3.ZERO, "out")
	a.expr(7.0, "closed")


# ===========================================================================
# ĐẠO CỤ: ĐIỆN THOẠI (manh mối) + SAO CHOÁNG
# ===========================================================================
func _build_props() -> void:
	phone = Node3D.new()
	phone.name = "Phone"
	add_child(phone)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.085, 0.012, 0.17)
	body.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("#16161c")
	pm.roughness = 0.25
	pm.metallic = 0.4
	body.material_override = pm
	phone.add_child(body)
	phone_screen = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.076, 0.155)
	phone_screen.mesh = qm
	phone_screen.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	phone_screen.position = Vector3(0.0, 0.0065, 0.0)
	var sm_ := StandardMaterial3D.new()
	sm_.albedo_color = Color("#0b1030")
	sm_.emission_enabled = true
	sm_.emission = Color("#1e2a6e")
	sm_.emission_energy_multiplier = 0.0
	phone_screen.material_override = sm_
	phone.add_child(phone_screen)
	var lab := Label3D.new()
	lab.name = "Msg"
	lab.text = "Sói Xám:\nhàng đêm nay\nở Nguyễn Xiển"
	lab.font_size = 48
	lab.pixel_size = 0.00024
	lab.modulate = Color(1.0, 1.0, 1.0, 0.0)
	lab.outline_size = 0
	lab.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	lab.position = Vector3(0.0, 0.0072, 0.012)
	lab.width = 300.0
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone.add_child(lab)
	var hdr := Label3D.new()
	hdr.name = "Hdr"
	hdr.text = "1 TIN NHẮN MỚI"
	hdr.font_size = 32
	hdr.pixel_size = 0.00022
	hdr.modulate = Color(0.6, 1.0, 0.9, 0.0)
	hdr.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	hdr.position = Vector3(0.0, 0.0072, -0.055)
	phone.add_child(hdr)
	phone.visible = false
	# 3 ngôi sao choáng quay quanh đầu shipper 1
	stars = Node3D.new()
	stars.name = "DazeStars"
	add_child(stars)
	var star_mesh: ArrayMesh = _star_mesh(0.07, 0.03, 0.02)
	var stm := StandardMaterial3D.new()
	stm.albedo_color = Color("#ffe14d")
	stm.emission_enabled = true
	stm.emission = Color("#ffd23a")
	stm.emission_energy_multiplier = 2.5
	for i: int in 3:
		var st := MeshInstance3D.new()
		st.mesh = star_mesh
		st.material_override = stm
		stars.add_child(st)
	stars.visible = false


static func _star_mesh(r_out: float, r_in: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i: int in 10:
		var ang: float = float(i) * TAU / 10.0
		var rr: float = r_out if i % 2 == 0 else r_in
		pts.append(Vector3(sin(ang) * rr, cos(ang) * rr, 0.0))
	for side: float in [1.0, -1.0]:
		var c := Vector3(0.0, 0.0, depth * side)
		for i: int in 10:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % 10]
			st.set_normal(Vector3(0.0, 0.0, side))
			if side > 0.0:
				st.add_vertex(c)
				st.add_vertex(b)
				st.add_vertex(a)
			else:
				st.add_vertex(c)
				st.add_vertex(a)
				st.add_vertex(b)
	return st.commit()


func _update_props(s: float) -> void:
	# điện thoại trượt ra khỏi túi shipper 1 sau cú quật (đúng tốc độ truyện), dừng, sáng màn hình, rung
	var t0: float = H7 + 0.35
	if s < t0:
		phone.visible = false
	else:
		phone.visible = true
		var u: float = clampf((s - t0) / 0.85, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - u, 3.0)
		var a: Vector3 = C1_DOWN + Vector3(0.3, 0.012, 0.15)
		var b: Vector3 = C1_DOWN + Vector3(-0.15, 0.012, 1.05)
		phone.position = a.lerp(b, e)
		phone.rotation = Vector3(0.0, lerpf(0.4, 2.9, e), 0.0)
		var lit: float = clampf((s - (t0 + 1.0)) / 0.25, 0.0, 1.0)
		var buzz: float = 0.0
		if s > t0 + 1.0 and s < t0 + 1.6:
			buzz = sin(s * 160.0) * 0.006
		phone.position.x += buzz
		(phone_screen.material_override as StandardMaterial3D).emission_energy_multiplier = 1.6 * lit
		(phone.get_node("Msg") as Label3D).modulate.a = lit
		(phone.get_node("Hdr") as Label3D).modulate.a = lit
	# sao choáng
	if s < H7 + 0.6:
		stars.visible = false
	else:
		stars.visible = true
		var head: Vector3 = c1.bone_world("Head")
		for i: int in 3:
			var ang: float = s * 5.5 + float(i) * TAU / 3.0
			var st: Node3D = stars.get_child(i)
			st.global_position = head + Vector3(cos(ang) * 0.24, 0.2 + 0.03 * sin(ang * 2.0), sin(ang) * 0.24)
			st.rotation = Vector3(0.0, -ang, 0.0)


# ===========================================================================
# SỰ KIỆN VA CHẠM (theo giây truyện): hạt, rung máy, tiếng tick
# ===========================================================================
func _build_events() -> void:
	_hit_event(H1, func() -> Vector3: return hero.bone_world("Foot.R"), Vector3(1.0, 0.2, 0.0), 1.0, Vector2(0.06, -0.03))
	_hit_event(H2, func() -> Vector3: return c2.bone_world("Head"), Vector3(1.0, 0.1, 0.0), 0.45, Vector2(0.02, 0.01))
	_hit_event(H3, func() -> Vector3: return c2.bone_world("Head"), Vector3(1.0, 0.0, 0.0), 0.5, Vector2(-0.025, 0.01))
	_hit_event(H4, func() -> Vector3: return c2.bone_world("Head"), Vector3(0.8, 0.2, 0.6), 1.0, Vector2(0.08, 0.0))
	_hit_event(H5, func() -> Vector3: return c3.bone_world("Chest"), Vector3(-1.0, 0.2, 0.2), 0.9, Vector2(-0.07, 0.02))
	_hit_event(H6, func() -> Vector3: return CineAlley.CRATE_POS + Vector3(-0.3, 0.6, 0.3), Vector3(1.0, 0.5, -0.3), 1.2, Vector2(0.05, 0.05))
	_hit_event(H7, func() -> Vector3: return c1.bone_world("Chest") * Vector3(1.0, 0.0, 1.0) + Vector3(0.0, 0.05, 0.0), Vector3(0.0, 1.0, 0.0), 1.1, Vector2(0.0, -0.08))
	events.append({"s": H6, "fn": func() -> void: _crate_burst(), "done": false})
	# bụi khi tiếp đất / trượt
	events.append({"s": 2.15, "fn": func() -> void: _dust(hero.global_position + Vector3(0.0, 0.05, 0.0), 0.6, 10), "done": false})
	events.append({"s": 2.6, "fn": func() -> void: _splash(c1.global_position, 1.0), "done": false})
	events.append({"s": 4.75, "fn": func() -> void: _splash(hero.global_position, 0.8), "done": false})
	events.append({"s": A1, "fn": func() -> void: _splash(hero.global_position, 1.0), "done": false})
	events.append({"s": 4.62, "fn": func() -> void: _dust(c2.global_position + Vector3(0.0, 0.05, 0.0), 0.8, 14), "done": false})
	for h: Array in warp.beat_rows():
		ticks.append({"r": float(h[1]), "kind": "accent" if String(h[0]).begins_with("A") else "hit", "done": false})


func _hit_event(s: float, where: Callable, dir: Vector3, power: float, whip: Vector2) -> void:
	var fn: Callable = func() -> void:
		var p: Vector3 = where.call()
		_sparks(p, dir.normalized(), power)
		_dust(p, 0.5 + 0.5 * power, int(10 + 14 * power))
		_shockwave(p, power)
	events.append({"s": s, "fn": fn, "done": false})
	impulses.append({"r": warp.real_at(s), "amp": 0.05 * power, "whip": whip, "fov": -6.0 * power})


func _particles(pos: Vector3, amount: int, tex: Texture2D, col: Gradient, size: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.set_meta("vice_done", true)
	qm.material = m
	p.mesh = qm
	p.color_ramp = col
	add_child(p)
	p.global_position = pos
	bursts.append(p)
	return p


func _sparks(pos: Vector3, dir: Vector3, power: float) -> void:
	var p: CPUParticles3D = _particles(pos, int(36 * power) + 10, spark_tex,
		CineAlley._ramp([Color(4.0, 3.6, 2.6, 1.0), Color(3.0, 1.6, 0.5, 1.0), Color(1.2, 0.3, 0.1, 0.0)], [0.0, 0.4, 1.0]), 0.06, 0.55)
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = 3.0 * power
	p.initial_velocity_max = 8.5 * power
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.emitting = true


func _dust(pos: Vector3, power: float, amount: int) -> void:
	var p: CPUParticles3D = _particles(pos, amount, soft_tex,
		CineAlley._ramp([Color(0.85, 0.75, 0.95, 0.55), Color(0.6, 0.55, 0.75, 0.3), Color(0.5, 0.45, 0.6, 0.0)], [0.0, 0.5, 1.0]), 0.5, 1.4)
	p.direction = Vector3(0.0, 0.4, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 0.4 * power
	p.initial_velocity_max = 1.6 * power
	p.gravity = Vector3(0.0, 0.15, 0.0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6 * power
	p.scale_amount_max = 1.8 * power
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.emitting = true


func _splash(pos: Vector3, power: float) -> void:
	var p: CPUParticles3D = _particles(pos + Vector3(0.0, 0.05, 0.0), int(30 * power), spark_tex,
		CineAlley._ramp([Color(1.6, 1.8, 2.4, 0.9), Color(0.9, 1.0, 1.4, 0.0)], [0.0, 1.0]), 0.045, 0.7)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 50.0
	p.initial_velocity_min = 1.5 * power
	p.initial_velocity_max = 3.5 * power
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3(0.0, 1.0, 0.0)
	p.emission_ring_radius = 0.35
	p.emission_ring_inner_radius = 0.1
	p.emission_ring_height = 0.02
	p.emitting = true


## Vòng sóng xung kích mỏng nở ra rồi tan (theo giây truyện).
func _shockwave(pos: Vector3, power: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.6, 1.4, 1.9, 0.6)
	m.set_meta("vice_done", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	var to_cam: Vector3 = (cam.global_position - pos).normalized()
	mi.look_at(pos + to_cam, Vector3.UP if absf(to_cam.y) < 0.95 else Vector3.FORWARD)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	mi.set_meta("born_s", prev_s)
	mi.set_meta("power", power)
	mi.scale = Vector3.ONE * 0.05
	mi.add_to_group("cine_shock")


func _update_shock(s: float) -> void:
	for n: Node in get_tree().get_nodes_in_group("cine_shock"):
		var mi := n as MeshInstance3D
		var age: float = s - float(mi.get_meta("born_s"))
		var pw: float = float(mi.get_meta("power"))
		var u: float = clampf(age / 0.5, 0.0, 1.0)
		mi.scale = Vector3.ONE * lerpf(0.05, 0.85 * pw, 1.0 - pow(1.0 - u, 3.0))
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - u)
		mi.visible = u < 1.0


# --- vỡ thùng: ẩn chồng thùng, mảnh vỡ bay theo quỹ đạo rơi + nảy (hàm của giây truyện)
var _crates_burst_s: float = -1.0


func _crate_burst() -> void:
	_crates_burst_s = H6
	_dust(CineAlley.CRATE_POS + Vector3(0.0, 0.5, 0.0), 1.6, 26)


func _update_debris(s: float) -> void:
	var burst: bool = s >= H6
	(set_refs["crates"] as Node3D).visible = not burst
	for d: Dictionary in set_refs["debris"]:
		var n: MeshInstance3D = d["node"]
		n.visible = burst
		if not burst:
			continue
		var t: float = s - H6
		var p0: Vector3 = d["p0"]
		var v: Vector3 = d["v"]
		var g: float = 9.8
		var h: float = d["h"]
		# lần chạm đất đầu: p0.y + v.y t - g t²/2 = h
		var a: float = 0.5 * g
		var disc: float = v.y * v.y + 4.0 * a * (p0.y - h)
		var t1: float = (v.y + sqrt(maxf(disc, 0.0))) / (2.0 * a)
		var pos: Vector3
		var rot: Vector3 = (d["r0"] as Vector3) + (d["w"] as Vector3) * minf(t, t1)
		if t <= t1:
			pos = p0 + v * t + Vector3(0.0, -a * t * t, 0.0)
		else:
			var p1: Vector3 = p0 + v * t1 + Vector3(0.0, -a * t1 * t1, 0.0)
			var v2 := Vector3(v.x * 0.35, absf(v.y - g * t1) * 0.3, v.z * 0.35)
			var t2: float = 2.0 * v2.y / g
			var tt: float = t - t1
			if tt <= t2:
				pos = p1 + v2 * tt + Vector3(0.0, -a * tt * tt, 0.0)
				rot += (d["w"] as Vector3) * 0.3 * tt
			else:
				var p2: Vector3 = p1 + Vector3(v2.x, 0.0, v2.z) * t2
				var slide: float = minf(tt - t2, 0.4)
				pos = p2 + Vector3(v2.x, 0.0, v2.z) * (slide - slide * slide / 0.8)
				pos.y = h
				rot += (d["w"] as Vector3) * 0.3 * t2
				rot.x = snappedf(rot.x, PI)
				rot.z = snappedf(rot.z, PI)
			pos.y = maxf(pos.y, h)
		n.position = pos
		n.rotation = rot


# ===========================================================================
# MÁY QUAY (theo giây thực r)
# ===========================================================================
func _shot(r0: float, fn: Callable) -> void:
	shots.append({"r0": r0, "fn": fn})


static func lerp3(a: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(b, u)


func _hips(a: CineActor) -> Vector3:
	return a.bone_world("Hips")


func _build_shots() -> void:
	var rr: Callable = warp.real_at
	# 1. Mở cảnh: cần cẩu hạ từ biển neon xuống ba shipper
	_shot(0.0, func(lr: float, _r: float, _s: float) -> Array:
		var u: float = sm(lr / 1.4)
		return [lerp3(Vector3(-1.5, 4.6, 5.8), Vector3(-2.9, 1.25, 4.4), u), lerp3(Vector3(0.8, 3.4, -4.0), Vector3(1.4, 1.15, -0.6), u), 46.0])
	# 2. Máy sát đất trước mặt nhân vật chính đang lao tới (nhảy qua đầu máy)
	_shot(rr.call(0.52), func(lr: float, _r: float, _s: float) -> Array:
		var hp: Vector3 = _hips(hero)
		var cp := Vector3(-1.2, 0.22, 0.55)
		return [cp + Vector3(0.0, 0.03 * lr, 0.0), hp + Vector3(0.0, 0.1, 0.0), 62.0])
	# 3. Bullet time: quay vòng quanh nhân vật chính trên không tới cú đá
	_shot(rr.call(1.36), func(lr: float, _r: float, _s: float) -> Array:
		var hp: Vector3 = _hips(hero)
		var ang: float = lerpf(-0.35, 1.25, sm(lr / 2.6))
		var rad: float = lerpf(2.4, 2.9, sm(lr / 2.6))
		var c: Vector3 = hp + Vector3(0.45, 0.0, 0.0)
		return [c + Vector3(sin(ang) * rad, 0.15 + 0.25 * sm(lr / 2.6), cos(ang) * rad), c + Vector3(0.0, 0.05, 0.0), 44.0])
	# 4. Shipper 1 bay ngược (máy lia theo)
	_shot(rr.call(H1) + 0.95, func(lr: float, _r: float, _s: float) -> Array:
		var hp: Vector3 = _hips(c1)
		var cp: Vector3 = Vector3(0.6, 1.0, 3.6) + Vector3(0.9 * sm(lr / 2.0), 0.0, 0.0)
		return [cp, hp, 52.0])
	# 5. Tổ hợp jab - cross - móc: trung cảnh 3/4, đẩy máy vào dần
	_shot(rr.call(2.42), func(lr: float, _r: float, _s: float) -> Array:
		var mid: Vector3 = (_hips(hero) + _hips(c2)) * 0.5
		var u: float = sm(lr / 4.0)
		var cp: Vector3 = mid + Vector3(lerpf(-0.6, -0.2, u), lerpf(0.35, 0.2, u), lerpf(2.9, 2.2, u))
		return [cp, mid + Vector3(0.0, 0.28, 0.0), 48.0])
	# 6. Cú móc: góc nghiêng thấp, xoay theo
	_shot(rr.call(3.7), func(lr: float, _r: float, _s: float) -> Array:
		var mid: Vector3 = (_hips(hero) + _hips(c2)) * 0.5
		var ang: float = lerpf(0.25, -0.35, sm(lr / 2.2))
		var cp: Vector3 = mid + Vector3(sin(ang) * 2.4, -0.25, cos(ang) * 2.4)
		return [cp, mid + Vector3(0.0, 0.35, 0.0), 42.0])
	# 7. Trượt dưới cú vung: máy sát đất, phía trước đường trượt
	_shot(rr.call(4.38), func(lr: float, _r: float, _s: float) -> Array:
		var hp: Vector3 = _hips(hero)
		var cp := Vector3(3.6, 0.18, -1.6)
		return [cp + Vector3(0.0, 0.0, 0.25 * sm(lr / 2.0)), hp.lerp(_hips(c3), 0.35) + Vector3(0.0, 0.15, 0.0), 54.0])
	# 8. Đá xoay: góc thấp anh hùng
	_shot(rr.call(5.6), func(lr: float, _r: float, _s: float) -> Array:
		var hp: Vector3 = _hips(hero)
		var tgt: Vector3 = hp.lerp(_hips(c3), 0.4)
		var cp: Vector3 = tgt + Vector3(-0.6 + 0.4 * sm(lr / 1.5), -0.7, 2.6)
		return [cp, tgt + Vector3(0.0, 0.3, 0.0), 50.0])
	# 9. Shipper 3 đâm vỡ thùng: máy thấp cạnh chồng thùng, mảnh vỡ bay về phía máy
	_shot(rr.call(H5) + 0.7, func(lr: float, _r: float, _s: float) -> Array:
		var cp: Vector3 = CineAlley.CRATE_POS + Vector3(-2.6, 0.45, 2.7)
		var tgt: Vector3 = CineAlley.CRATE_POS + Vector3(-0.6, 0.6, 0.2)
		return [cp + Vector3(0.0, 0.1 * sm(lr / 2.0), 0.0), tgt.lerp(_hips(c3), 0.4), 50.0])
	# 10. Đòn kết cắt kéo: quay vòng cao 3/4
	_shot(rr.call(7.25), func(lr: float, _r: float, _s: float) -> Array:
		var mid: Vector3 = (_hips(hero) + _hips(c1)) * 0.5
		var ang: float = lerpf(0.9, -0.5, sm(lr / 3.6))
		var cp: Vector3 = mid + Vector3(sin(ang) * 3.0, 1.1, cos(ang) * 3.0)
		return [cp, mid + Vector3(0.0, -0.05, 0.0), 46.0])
	# 11. Hài: shipper 1 nằm choáng, sao quay (máy cao nhìn xuống)
	_shot(rr.call(H7) + 1.95, func(lr: float, _r: float, _s: float) -> Array:
		var hd: Vector3 = c1.bone_world("Head")
		var cp: Vector3 = hd + Vector3(-0.9 + 0.25 * sm(lr / 2.0), 1.2, 1.1)
		return [cp, hd + Vector3(0.25, 0.0, 0.2), 42.0])
	# 12. Cận điện thoại: manh mối
	_shot(LENGTH - 2.6, func(lr: float, _r: float, _s: float) -> Array:
		var pp: Vector3 = phone.global_position
		var cp: Vector3 = pp + Vector3(0.05, 0.42 - 0.08 * sm(lr / 2.6), 0.2)
		return [cp, pp + Vector3(0.0, 0.0, -0.01), 38.0])
	shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["r0"]) < float(b["r0"]))


func _update_camera(rt: float, s: float) -> void:
	var cur: Dictionary = shots[0]
	for sh: Dictionary in shots:
		if float(sh["r0"]) <= rt:
			cur = sh
	var lr: float = rt - float(cur["r0"])
	var res: Array = (cur["fn"] as Callable).call(lr, rt, s)
	var pos: Vector3 = res[0]
	var look: Vector3 = res[1]
	var fov: float = res[2]
	# rung máy + lia nhanh (whip) + zoom giật khi trúng đòn
	var shake := Vector3.ZERO
	var whip := Vector2.ZERO
	for im: Dictionary in impulses:
		var dt: float = rt - float(im["r"])
		if dt < 0.0 or dt > 0.9:
			continue
		var env: float = exp(-dt / 0.16)
		var amp: float = float(im["amp"]) * env
		shake += Vector3(sin(dt * 91.0), sin(dt * 77.0 + 1.3), sin(dt * 63.0 + 2.1)) * amp
		var w: Vector2 = im["whip"]
		var k: float = (1.0 - exp(-dt / 0.035)) * exp(-dt / 0.22)
		whip += w * k * 4.0
		fov += float(im["fov"]) * exp(-dt / 0.25) * (1.0 - exp(-dt / 0.03))
	var bc: String = OS.get_environment("CINE_CAM")
	if bc != "":
		# camera dựng cảnh (blocking) để kiểm tra chạm: trực giao nhìn ngang (từ +Z) hoặc từ trên xuống
		var focus: Vector3 = _hips(hero)
		if OS.get_environment("CINE_FOCUS") != "":
			var fx: PackedStringArray = OS.get_environment("CINE_FOCUS").split(",")
			focus = Vector3(float(fx[0]), float(fx[1]), float(fx[2]))
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 4.2
		if bc == "top":
			cam.global_position = Vector3(focus.x, 12.0, focus.z)
			cam.look_at(Vector3(focus.x, 0.0, focus.z), Vector3.FORWARD)
		else:
			cam.global_position = Vector3(focus.x, 1.0, 12.0)
			cam.look_at(Vector3(focus.x, 1.0, 0.0), Vector3.UP)
		return
	cam.global_position = pos + shake
	if (look - cam.global_position).length() > 0.001:
		cam.look_at(look + shake * 0.5, Vector3.UP)
	cam.rotate_object_local(Vector3.UP, whip.x)
	cam.rotate_object_local(Vector3.RIGHT, whip.y)
	cam.fov = fov


# ===========================================================================
# LỚP PHỦ: thanh letterbox, fade, loé trắng, viền tối, gỡ lỗi
# ===========================================================================
func _build_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	vignette = TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.gradient = CineAlley._ramp([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.03, 0.0, 0.08, 0.85)], [0.0, 0.55, 1.0])
	gt.width = 256
	gt.height = 256
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(vignette)
	flash_rect = _rect(cl, Color(1.0, 0.95, 1.0, 0.0))
	for top: bool in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			b.set_anchors_preset(Control.PRESET_TOP_WIDE)
		else:
			b.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cl.add_child(b)
		bars.append(b)
	fade_rect = _rect(cl, Color(0.0, 0.0, 0.0, 1.0))
	if OS.get_environment("CINE_DEBUG") == "1":
		debug_label = Label.new()
		debug_label.position = Vector2(16.0, 96.0)
		debug_label.add_theme_font_size_override("font_size", 18)
		cl.add_child(debug_label)


func _rect(parent: Node, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _update_overlay(rt: float, s: float, v: float) -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var bar_h: float = (vs.y - vs.x / 2.35) * 0.5
	var slide: float = sm(rt / 0.8)
	bars[0].size = Vector2(vs.x, bar_h * slide)
	bars[0].position = Vector2.ZERO
	bars[1].size = Vector2(vs.x, bar_h * slide)
	bars[1].position = Vector2(0.0, vs.y - bar_h * slide)
	var fade_in: float = 1.0 - sm(rt / 0.6)
	var fade_out: float = sm((rt - (LENGTH - 0.6)) / 0.6)
	fade_rect.color.a = maxf(fade_in, fade_out)
	var fl: float = 0.0
	for im: Dictionary in impulses:
		var dt: float = rt - float(im["r"])
		if dt >= 0.0 and dt < 0.2:
			fl = maxf(fl, (1.0 - dt / 0.2) * 0.28 * clampf(float(im["amp"]) / 0.05, 0.3, 1.0))
	flash_rect.color.a = fl
	vignette.modulate.a = lerpf(1.0, 1.35, clampf(1.0 - v, 0.0, 1.0)) * 0.8
	if debug_label:
		var nxt: String = ""
		for row: Array in warp.beat_rows():
			if absf(rt - float(row[1])) < 0.12:
				nxt = "  >>> " + String(row[0])
		debug_label.text = "r %.2f s   story %.3f s   speed %.2fx%s" % [rt, s, v, nxt]


# ===========================================================================
# ÂM THANH: tiếng tick tổng hợp mỗi cú đánh (để nghe nhịp khi ghép nhạc)
# ===========================================================================
func _build_audio() -> void:
	tick_player = AudioStreamPlayer.new()
	tick_player.stream = _tick_wav(1750.0, 110.0, 0.9)
	tick_player.volume_db = -3.0
	add_child(tick_player)
	accent_player = AudioStreamPlayer.new()
	accent_player.stream = _tick_wav(3100.0, 0.0, 0.5)
	accent_player.volume_db = -8.0
	add_child(accent_player)


static func _tick_wav(f_click: float, f_thump: float, amp: float) -> AudioStreamWAV:
	var rate: int = 44100
	var n: int = int(rate * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i: int in n:
		var t: float = float(i) / float(rate)
		var v: float = 0.75 * sin(TAU * f_click * t) * exp(-t / 0.012)
		if f_thump > 0.0:
			v += 0.6 * sin(TAU * f_thump * t) * exp(-t / 0.05)
		v = clampf(v * amp, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


# ===========================================================================
# VÒNG LẶP
# ===========================================================================
func _process(delta: float) -> void:
	if not seek_list.is_empty():
		_do_seek()
		return
	frame += 1
	r += delta
	_update(r)
	if r >= LENGTH + 0.05:
		get_tree().quit()


func _update(rt: float) -> void:
	var s: float = warp.story_at(rt)
	var v: float = warp.speed_at(rt)
	for a: CineActor in actors:
		a.evaluate(s)
	# sự kiện vượt qua trong khung này (s đơn điệu khi phát)
	for e: Dictionary in events:
		if not bool(e["done"]) and s >= float(e["s"]) and prev_s < float(e["s"]):
			e["done"] = true
			(e["fn"] as Callable).call()
	for tk: Dictionary in ticks:
		if not bool(tk["done"]) and rt >= float(tk["r"]):
			tk["done"] = true
			if seek_list.is_empty():
				(accent_player if String(tk["kind"]) == "accent" else tick_player).play()
	prev_s = s
	for p: CPUParticles3D in bursts:
		if is_instance_valid(p):
			p.speed_scale = v
	_update_debris(s)
	_update_shock(s)
	_update_props(s)
	_update_camera(rt, s)
	_update_overlay(rt, s, v)


var _seek_wait: int = 0


func _do_seek() -> void:
	# chụp ảnh tĩnh: đặt thời điểm, chờ 3 khung cho render, lưu, sang thời điểm kế
	if _seek_wait == 0:
		var t: float = seek_list[0]
		prev_s = warp.story_at(t) - 0.0001
		_update(t)
		_seek_wait = 1
		return
	_seek_wait += 1
	if _seek_wait < 4:
		return
	var t2: float = seek_list.pop_front()
	var img: Image = get_viewport().get_texture().get_image()
	var fn: String = seek_dir.path_join("cine_r%05.2f_s%05.2f.png" % [t2, warp.story_at(t2)])
	img.save_png(fn)
	print("seek ", fn)
	_seek_wait = 0
	if seek_list.is_empty():
		get_tree().quit()


func _write_beats() -> void:
	var lines: PackedStringArray = []
	lines.append("# Beat sheet - %s (prototype)  length %.2f s real; story clock %.2f s" % [SLOT, LENGTH, warp.s_end])
	lines.append("# All times in REAL seconds from the first frame (= music time). Freeze = the story clock stops; ticks in the")
	lines.append("# prototype video sit on the 'hit' time. Slow = story speed around the hit (1.0 = normal).")
	lines.append("# name | hit (s) | freeze end (s) | freeze (s) | slow")
	for row: Array in warp.beat_rows():
		lines.append("%s | %.3f | %.3f | %.2f | %.2fx" % [row[0], row[1], row[2], row[5], row[4]])
	lines.append("")
	lines.append("# Speed ramps (real time where the clock leaves / returns to 1.0x)")
	var prev_v: float = 1.0
	var t: float = 0.0
	while t <= LENGTH:
		var v: float = warp.speed_at(t)
		if prev_v >= 0.999 and v < 0.999:
			lines.append("ramp down starts %.2f" % t)
		elif prev_v < 0.999 and v >= 0.999:
			lines.append("back to 1.0x     %.2f" % t)
		prev_v = v
		t += 1.0 / 60.0
	lines.append("")
	lines.append("# Fixed points: fade in 0.00-0.60, letterbox 0.00-0.80, normal-speed comic tail from %.2f, fade out %.2f-%.2f" % [warp.real_at(H7 + 0.65), LENGTH - 0.6, LENGTH])
	var path: String = ProjectSettings.globalize_path(BEATS_FILE)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("beats -> ", path)
