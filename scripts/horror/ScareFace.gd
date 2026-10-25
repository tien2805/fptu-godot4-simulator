# File: res://scripts/horror/ScareFace.gd
# Jump scare v2 (owner: "jumpscare chưa đủ đáng sợ"): the face and the screen hit of every face scare, used by ScareDirector
# (catch scares, scripted jump scares, the locker lunge). ScareDirector does the 0.4 s duck before and the loud sting.
#   start(kind, mode, cam, by_dolly, double): the face SNAPS from its kind's start pose to the final pose in SNAP_S (ease out
#     with an overshoot), sized so it fills COVER of the screen height at the camera's FOV (final_distance; more while the
#     FOV is punched in), the camera FOV punches in by FOV_PUNCH over FOV_IN_S and back over FOV_OUT_S, then it HOLDS HOLD_S twitching (a new random
#     ±TWITCH_DEG rotation TWITCH_HZ times a second, tilted TILT_DEG). mode "catch" / "jump": a hard cut to black for BLACK_S;
#     "catch" with double = true: the face flashes once more for DOUBLE_S (beat "double") before the end. mode "lunge": the
#     face retreats over RETREAT_S instead (the locker scare), no black.
#   Kinds (where it comes from): "desk" upside down from above, "locker" from behind the slats, "stall" up over the partition
#     (the camera tilts up), "open" / "jump" straight at the camera.
#   hit(): 1 frame of white, 2 frames of red, a red vignette pulse, an RGB-split + noise overlay (a canvas shader that only
#     runs while visible) fading over ABER_S, and a ±SHAKE_M camera shake (h/v offsets) for SHAKE_S.
#   The camera's near plane, FOV, rotation and offsets are restored at the end (and on stop()).
#   build_scare_mask(): the creepier mask of the scares, all code: dirty dark wool with code-drawn crack lines, black hollow
#     eyes with small glowing red pupils, a dark open mouth gap (no blood, no gore). The clones get the same mask.
# Beats: "face" (the snap starts), "hold", "black", "double", "end". No light node; overlay nodes hidden when idle.
class_name ScareFace
extends Node

signal beat(name: String)

const SNAP_S: float = 0.1
const HOLD_S: float = 0.5
const BLACK_S: float = 0.3
const DOUBLE_S: float = 0.15
const DOUBLE_GAP_S: float = 0.1
const RETREAT_S: float = 0.2
const DOUBLE_RATE: float = 0.2
const COVER: float = 0.78
const FOV_PUNCH: float = 15.0
const FOV_IN_S: float = 0.1
const FOV_OUT_S: float = 0.4
const TWITCH_DEG: float = 7.0
const TWITCH_HZ: float = 22.0
const TILT_DEG: float = 22.0
const SHAKE_S: float = 0.4
const SHAKE_M: float = 0.06
const ABER_S: float = 0.5
const VIGNETTE_S: float = 0.45
const NEAR: float = 0.01
const CREAM := Color("#EADCBD")
const CLONE_HAIR := Color("#2B211C")
const ABER_SHADER: String = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
uniform float seed = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	vec2 o = vec2(strength * 0.012, 0.0);
	float r = texture(screen_tex, SCREEN_UV + o).r;
	float g = texture(screen_tex, SCREEN_UV).g;
	float b = texture(screen_tex, SCREEN_UV - o).b;
	float n = rnd(floor(SCREEN_UV * 240.0)) - 0.5;
	COLOR = vec4(vec3(r, g, b) + n * 0.35 * strength, 1.0);
}
"""

static var _crack_tex: ImageTexture = null

var layer: CanvasLayer = null
var face: Node3D = null
var face_h: float = 0.42
var playing: bool = false
var kind: String = "open"
var mode: String = "catch"
var double: bool = false
## Time since the snap started (s).
var t: float = 0.0
var rng := RandomNumberGenerator.new()
## Screen-hit state (tests): frames left of white / red, overlay strength, vignette alpha, shake time left.
var flash_frames: int = 0
var red_frames: int = 0
var aber: float = 0.0
var vignette_a: float = 0.0
var shake_t: float = 0.0

var _cam: Camera3D = null
var _rot0: Vector3 = Vector3.ZERO
var _fov0: float = 70.0
var _near0: float = 0.05
var _hoff0: float = 0.0
var _voff0: float = 0.0
var _hood: MeshInstance3D = null
var _wool_dolly: StandardMaterial3D
var _wool_clone: StandardMaterial3D
var _twitch: Vector3 = Vector3.ZERO
var _twitch_t: float = 0.0
var _flash: ColorRect
var _red: ColorRect
var _black: ColorRect
var _vig: TextureRect
var _aber: ColorRect
var _aber_mat: ShaderMaterial
var _beats_done: Dictionary = {}


func _init() -> void:
	name = "ScareFace"


## Builds the face and the overlay nodes on `l` (the director's CanvasLayer).
func setup(l: CanvasLayer, seed_val: int = 0) -> void:
	layer = l
	rng.seed = seed_val
	face = Node3D.new()
	face.name = "CatchFace"
	add_child(face)
	var mask: Node3D = build_scare_mask()
	face.add_child(mask)
	_wool_dolly = _mat(CREAM.darkened(0.25), 1.0)
	_wool_clone = _mat(CLONE_HAIR, 0.85)
	_hood = _sphere(face, "Hood", 0.17, Vector3(0.0, 0.04, 0.09), _wool_dolly, Vector3(1.05, 1.15, 0.95))
	_box(face, "Neck", Vector3(0.13, 0.24, 0.11), Vector3(0.0, -0.24, 0.05), _mat(Color("#1C1A19"), 0.9))
	face_h = 0.46   # hood top to the neck's bottom, about
	face.visible = false
	_aber = _rect("ScareAber", Color.WHITE)
	_aber_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ABER_SHADER
	_aber_mat.shader = sh
	_aber.material = _aber_mat
	_vig = TextureRect.new()
	_vig.name = "ScareVignette"
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.6, 0.0, 0.0, 0.0), Color(0.6, 0.0, 0.0, 0.0), Color(0.55, 0.0, 0.0, 1.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	_vig.texture = gt
	_vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vig.visible = false
	layer.add_child(_vig)
	_red = _rect("ScareRed", Color(0.85, 0.0, 0.0, 0.55))
	_flash = _rect("ScareFlash", Color(1.0, 1.0, 1.0, 1.0))
	_black = _rect("ScareBlack", Color(0.0, 0.0, 0.0, 1.0))


func _rect(n: String, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = n
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.visible = false
	layer.add_child(r)
	return r


# ---------------------------------------------------------------------------
# The scare mask (code-built)
# ---------------------------------------------------------------------------
static func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _sphere(parent: Node3D, nm: String, r: float, pos: Vector3, mat: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, nm: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Dirty wool with thin dark crack lines, drawn in code once (128 x 128).
static func crack_texture() -> ImageTexture:
	if _crack_tex != null:
		return _crack_tex
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 666
	for y: int in 128:
		for x: int in 128:
			var v: float = 0.78 + r.randf_range(-0.12, 0.08)
			img.set_pixel(x, y, Color(v, v * 0.95, v * 0.86))
	for c: int in 9:   # crack lines: short random walks
		var p := Vector2(r.randf_range(0.0, 127.0), r.randf_range(0.0, 127.0))
		var dir: float = r.randf_range(0.0, TAU)
		for s: int in 60:
			dir += r.randf_range(-0.5, 0.5)
			p += Vector2(cos(dir), sin(dir))
			var ix: int = posmod(int(p.x), 128)
			var iy: int = posmod(int(p.y), 128)
			img.set_pixel(ix, iy, Color(0.12, 0.1, 0.09))
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex


## The scare mask (faces -Z like the other masks, about 0.3 m tall): no blood, no gore.
static func build_scare_mask() -> Node3D:
	var root := Node3D.new()
	root.name = "ScareMask"
	var wool := StandardMaterial3D.new()
	wool.albedo_texture = crack_texture()
	wool.albedo_color = Color("#B9AE96")
	wool.roughness = 1.0
	var face_m := StandardMaterial3D.new()
	face_m.albedo_texture = crack_texture()
	face_m.albedo_color = Color("#8E8A84")
	face_m.roughness = 0.8
	var black := _mat(Color("#050404"), 1.0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#FF1A12")
	red.emission_enabled = true
	red.emission = Color("#FF1A12")
	red.emission_energy_multiplier = 3.5
	_sphere(root, "Wool", 0.15, Vector3(0.0, 0.05, 0.02), wool, Vector3(1.05, 1.0, 1.0))
	for sx: float in [-1.0, 1.0]:
		_sphere(root, "Tuft", 0.07, Vector3(sx * 0.12, 0.12, 0.0), wool)
		_box(root, "Ear", Vector3(0.1, 0.035, 0.05), Vector3(sx * 0.17, 0.04, 0.0), face_m, Vector3(0.0, 0.0, sx * -0.5))
	_sphere(root, "Face", 0.1, Vector3(0.0, -0.01, -0.08), face_m, Vector3(0.95, 1.25, 0.8))
	_sphere(root, "Muzzle", 0.075, Vector3(0.0, -0.07, -0.13), face_m, Vector3(0.9, 0.8, 0.85))
	for sx2: float in [-1.0, 1.0]:
		_sphere(root, "Eye", 0.032, Vector3(sx2 * 0.045, 0.02, -0.155), black, Vector3(1.1, 1.3, 0.5))   # hollow, black
		_sphere(root, "Pupil", 0.008, Vector3(sx2 * 0.045, 0.018, -0.17), red)                       # a red glint deep in it
	_box(root, "Mouth", Vector3(0.07, 0.022, 0.02), Vector3(0.0, -0.105, -0.195), black)              # the open mouth gap
	return root


# ---------------------------------------------------------------------------
# Staging
# ---------------------------------------------------------------------------
## Distance at which a face `h` m tall fills `cover` of the screen height at a vertical FOV of `fov_deg`.
static func final_distance(h: float, fov_deg: float, cover: float = COVER) -> float:
	return h / (cover * 2.0 * tan(deg_to_rad(fov_deg) * 0.5))


func punched_fov() -> float:
	return maxf(20.0, _fov0 - FOV_PUNCH)


## How much of the screen height the face fills now (0..1+), from the camera's FOV and the distance.
func coverage() -> float:
	if _cam == null or not is_instance_valid(_cam) or face == null:
		return 0.0
	var d: float = -(_cam.global_transform.affine_inverse() * face.global_position).z
	if d <= 0.0:
		return 0.0
	return face_h / (2.0 * d * tan(deg_to_rad(_cam.fov) * 0.5))


func total() -> float:
	match mode:
		"lunge":
			return SNAP_S + HOLD_S + RETREAT_S
		_:
			return SNAP_S + HOLD_S + BLACK_S + ((DOUBLE_GAP_S + DOUBLE_S) if double else 0.0)


## Rolls the 20 % double scare (seeded).
func roll_double() -> bool:
	return rng.randf() < DOUBLE_RATE


func start(k: String, m: String, cam: Camera3D, by_dolly: bool = true, dbl: bool = false) -> void:
	stop()
	kind = k
	mode = m
	double = dbl and m == "catch"
	t = 0.0
	_beats_done.clear()
	_cam = cam if cam != null and is_instance_valid(cam) else null
	if _cam != null:
		_rot0 = _cam.rotation
		_fov0 = _cam.fov
		_near0 = _cam.near
		_hoff0 = _cam.h_offset
		_voff0 = _cam.v_offset
		_cam.near = NEAR
	_hood.material_override = _wool_dolly if by_dolly else _wool_clone
	playing = true
	face.visible = true
	_twitch = Vector3.ZERO
	_twitch_t = 0.0
	_place()
	beat.emit("face")


## Start and final offsets of a kind (camera space: x right, y up, z = distance in front).
func _pose(s: float) -> Dictionary:
	var d: float = final_distance(face_h, _fov0)   # fills COVER at the camera's own FOV (more while punched in)
	var from := Vector3(0.0, 0.0, d)
	var roll: float = deg_to_rad(TILT_DEG)
	var tilt: float = 0.0
	match kind:
		"desk":
			from = Vector3(0.0, d * 0.9, d)
			roll = PI + deg_to_rad(TILT_DEG)
		"locker":
			from = Vector3(0.0, 0.0, d * 1.6)
		"stall":
			from = Vector3(0.0, -d * 0.9, d)
			tilt = 0.7
		_:
			from = Vector3(0.0, -0.05, maxf(2.3, d * 3.0))
	var to := Vector3(0.0, 0.0, d)
	var e: float = _ease_out_back(clampf(s, 0.0, 1.0))
	var p: Vector3 = from.lerp(to, e)
	p.z = maxf(p.z, 0.2)
	return {"pos": p, "roll": roll, "tilt": tilt * clampf(s, 0.0, 1.0)}


static func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _place() -> void:
	if _cam == null or not is_instance_valid(_cam) or not _cam.is_inside_tree():
		return
	var snap_s: float = t / SNAP_S
	var o: Dictionary = _pose(snap_s)
	var p: Vector3 = o["pos"]
	if mode == "lunge" and t > SNAP_S + HOLD_S:   # back where it came from
		var k: float = clampf((t - SNAP_S - HOLD_S) / RETREAT_S, 0.0, 1.0)
		p = p.lerp(Vector3(0.0, 0.0, p.z * 4.0), k)
	_cam.rotation = Vector3(_rot0.x + float(o["tilt"]), _rot0.y, _rot0.z)
	var b: Basis = _cam.global_transform.basis.orthonormalized()
	var pos: Vector3 = _cam.global_position + b.x * p.x + b.y * p.y - b.z * p.z
	var rot := Basis.from_euler(Vector3(deg_to_rad(_twitch.x), deg_to_rad(_twitch.y), deg_to_rad(_twitch.z)))
	face.global_transform = Transform3D(b * Basis(Vector3(0.0, 0.0, 1.0), float(o["roll"])) * rot * Basis(Vector3.UP, PI), pos)


func twitch_now() -> Vector3:
	return _twitch


func is_holding() -> bool:
	return playing and t >= SNAP_S and t < SNAP_S + HOLD_S


func step(delta: float) -> void:
	_step_hit(delta)
	if not playing:
		return
	t += delta
	# FOV punch: in over FOV_IN_S, back over FOV_OUT_S
	if _cam != null and is_instance_valid(_cam):
		var f: float = punched_fov()
		if t < FOV_IN_S:
			_cam.fov = lerpf(_fov0, f, t / FOV_IN_S)
		elif t < FOV_IN_S + FOV_OUT_S:
			_cam.fov = lerpf(f, _fov0, (t - FOV_IN_S) / FOV_OUT_S)
		else:
			_cam.fov = _fov0
	if is_holding():
		_twitch_t -= delta
		if _twitch_t <= 0.0:
			_twitch_t = 1.0 / TWITCH_HZ
			_twitch = Vector3(rng.randf_range(-TWITCH_DEG, TWITCH_DEG), rng.randf_range(-TWITCH_DEG, TWITCH_DEG), rng.randf_range(-TWITCH_DEG, TWITCH_DEG))
		_once("hold")
	else:
		_twitch = Vector3.ZERO
	var hold_end: float = SNAP_S + HOLD_S
	if mode == "lunge":
		_place()
		if t >= total():
			_finish()
		return
	if t < hold_end:
		_place()
		return
	# the hard cut to black, then maybe the face once more
	var black_end: float = hold_end + BLACK_S
	if t < black_end:
		face.visible = false
		_black.visible = true
		_once("black")
	elif double and t < black_end + DOUBLE_GAP_S + DOUBLE_S:
		if t >= black_end + DOUBLE_GAP_S:
			if not _beats_done.has("double"):
				flash_frames = 0
				_flash.visible = true   # one white frame with the second face
			_once("double")
			_black.visible = false
			face.visible = true
			_place()
		else:
			_black.visible = true
			face.visible = false
	if t >= total():
		_finish()


func _once(b: String) -> void:
	if not _beats_done.has(b):
		_beats_done[b] = true
		beat.emit(b)


func _finish() -> void:
	stop()
	beat.emit("end")


## Ends at once: the face and the black go, the camera comes back exactly.
func stop() -> void:
	if _cam != null and is_instance_valid(_cam):
		_cam.rotation = _rot0
		_cam.fov = _fov0
		_cam.near = _near0
		_cam.h_offset = _hoff0
		_cam.v_offset = _voff0
	playing = false
	if face != null:
		face.visible = false
	if _black != null:
		_black.visible = false
	_cam = null


## The screen hit at the snap: 1 frame of white, 2 of red, a red vignette pulse, the RGB-split + noise overlay, a shake.
func hit(cam: Camera3D = null) -> void:
	flash_frames = 0   # this frame is the white one
	red_frames = 2
	vignette_a = 1.0
	aber = 1.0
	shake_t = SHAKE_S
	if cam != null and _cam == null:
		_cam = cam
		_hoff0 = cam.h_offset
		_voff0 = cam.v_offset
	_flash.visible = true
	_aber.visible = true
	_vig.visible = true


func _step_hit(delta: float) -> void:
	# frame counters (the hit frame itself is white): then red_frames red frames
	if flash_frames > 0:
		_flash.visible = true
		_red.visible = false
		flash_frames -= 1
	elif red_frames > 0:
		_flash.visible = false
		_red.visible = true
		red_frames -= 1
	else:
		_flash.visible = false
		_red.visible = false
	if aber > 0.0:
		aber = maxf(0.0, aber - delta / ABER_S)
		_aber_mat.set_shader_parameter("strength", aber)
		_aber_mat.set_shader_parameter("seed", rng.randf() * 100.0)
		_aber.visible = aber > 0.0
	if vignette_a > 0.0:
		vignette_a = maxf(0.0, vignette_a - delta / VIGNETTE_S)
		_vig.modulate.a = vignette_a
		_vig.visible = vignette_a > 0.0
	if shake_t > 0.0:
		shake_t = maxf(0.0, shake_t - delta)
		if _cam != null and is_instance_valid(_cam):
			var k: float = SHAKE_M * shake_t / SHAKE_S
			_cam.h_offset = _hoff0 + rng.randf_range(-k, k)
			_cam.v_offset = _voff0 + rng.randf_range(-k, k)
			if shake_t <= 0.0:
				_cam.h_offset = _hoff0
				_cam.v_offset = _voff0


## Overlays all hidden and no shake left (tests).
func screen_idle() -> bool:
	return not _flash.visible and not _red.visible and not _aber.visible and not _vig.visible and not _black.visible and shake_t <= 0.0


func overlay_visible() -> Dictionary:
	return {"flash": _flash.visible, "red": _red.visible, "aber": _aber.visible, "vignette": _vig.visible, "black": _black.visible}
