# File: res://scripts/cine/CineAnimProp.gd
# Story-time animated props of Phase C (spec C-D9 / C-D10), all code-built, posed by CinePlayer through cine_eval(s, opts)
# (prop opts "anim": true; the node is the prop's meta "anim_node"). Pure in story time, so seeking gives the same frame.
#   mode "wall"    the server-room wall of 50 monitors (10 x 5): off, then Lê Minh Za Mẫn's laughing face (a code-drawn
#                  caricature: man bun, round glasses, open mouth; two frames swap every 0.12 s) from "face_at", then the
#                  frozen blue error screen "Lọ Thần đã gặp sự cố" from "freeze_at". Screens face -Z.
#   mode "stonks"  a big monitor with a line chart that climbs, then dives from "dive_at" (over "dive_dur"), the word STONKS
#                  and, after the dive, a red ticker. Faces -Z.
#   mode "fire"    flames (emissive cones that flicker in story time) and a flickering orange light; "fire_from" (s).
#   mode "doors"   the two door leaves of a container (built by CinePropsC) swing open from "open_at" over "open_dur".
class_name CineAnimProp
extends Node3D

const WALL_COLS: int = 10
const WALL_ROWS: int = 5
const MON_W: float = 0.56
const MON_H: float = 0.34
const MON_GAP: float = 0.05
const WALL_Y0: float = 0.55
const FACE_SWAP: float = 0.12
const CHART_SEGS: int = 14
const ERROR_TEXT: String = "Lọ Thần đã gặp sự cố"

var mode: String = ""
var screen_mat: StandardMaterial3D
var error_label: Label3D
var error_sub: Label3D
var segs: Array[MeshInstance3D] = []
var ticker: Label3D
var flames: Array[MeshInstance3D] = []
var light: OmniLight3D
var leaves: Array[Node3D] = []
var state: String = ""            # last applied state (tests read it): wall off | face_a | face_b | error; stonks up | dive
var _last_key: String = ""

static var _tex: Dictionary = {}


static func make(m: String, opts: Dictionary = {}) -> CineAnimProp:
	var n := CineAnimProp.new()
	n.name = "Anim_" + m
	n.mode = m
	match m:
		"wall":
			n._build_wall()
		"stonks":
			n._build_stonks()
		"fire":
			n._build_fire(opts)
	return n


func cine_eval(s: float, opts: Dictionary) -> void:
	match mode:
		"wall":
			_eval_wall(s, opts)
		"stonks":
			_eval_stonks(s, opts)
		"fire":
			_eval_fire(s, opts)
		"doors":
			_eval_doors(s, opts)


# ---------------------------------------------------------------------------
# Monitor wall
# ---------------------------------------------------------------------------
func _build_wall() -> void:
	var frame: StandardMaterial3D = CineFX._mat(Color("#1A1C20"), 0.5)
	screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color("#05070A")
	screen_mat.emission_enabled = true
	screen_mat.emission = Color.WHITE
	screen_mat.emission_energy_multiplier = 0.0
	screen_mat.set_meta("vice_done", true)
	var w: float = WALL_COLS * (MON_W + MON_GAP)
	CineFX._box(self, "Rack", Vector3(w + 0.2, WALL_ROWS * (MON_H + MON_GAP) + 0.2, 0.08), Vector3(0.0, WALL_Y0 + WALL_ROWS * (MON_H + MON_GAP) * 0.5, 0.06), frame)
	for j: int in WALL_ROWS:
		for i: int in WALL_COLS:
			var c := Vector3((float(i) - (WALL_COLS - 1) * 0.5) * (MON_W + MON_GAP), WALL_Y0 + (float(j) + 0.5) * (MON_H + MON_GAP), 0.0)
			CineFX._box(self, "Bezel", Vector3(MON_W + 0.03, MON_H + 0.03, 0.05), c + Vector3(0.0, 0.0, 0.01), frame)
			var sc := MeshInstance3D.new()
			sc.name = "Screen%d" % (j * WALL_COLS + i)
			var qm := QuadMesh.new()
			qm.size = Vector2(MON_W, MON_H)
			sc.mesh = qm
			sc.material_override = screen_mat
			sc.position = c + Vector3(0.0, 0.0, -0.016)
			sc.rotation.y = PI   # the quad faces +Z: turn it to face -Z
			add_child(sc)
	error_label = _label("ErrorText", ERROR_TEXT, 150, Color("#FFFFFF"), Vector3(0.0, WALL_Y0 + WALL_ROWS * (MON_H + MON_GAP) * 0.62, -0.03))
	error_sub = _label("ErrorSub", "Đang thu thập dữ liệu lỗi... 0%", 70, Color("#DDE8FF"), Vector3(0.0, WALL_Y0 + WALL_ROWS * (MON_H + MON_GAP) * 0.38, -0.03))
	light = OmniLight3D.new()
	light.name = "WallGlow"
	light.omni_range = 6.0
	light.light_energy = 0.0
	light.position = Vector3(0.0, WALL_Y0 + 1.0, -1.2)
	add_child(light)


func _label(nm: String, text: String, size: int, col: Color, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.name = nm
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0022
	l.outline_size = 8
	l.modulate = col
	l.position = pos
	l.rotation.y = PI   # read from the -Z side
	l.visible = false
	add_child(l)
	return l


func _eval_wall(s: float, opts: Dictionary) -> void:
	var st: String = "off"
	if s >= float(opts.get("freeze_at", INF)):
		st = "error"
	elif s >= float(opts.get("face_at", INF)):
		st = "face_a" if int(floor((s - float(opts["face_at"])) / FACE_SWAP)) % 2 == 0 else "face_b"
	if st == _last_key:
		return
	_last_key = st
	state = st
	error_label.visible = st == "error"
	error_sub.visible = st == "error"
	match st:
		"off":
			screen_mat.albedo_texture = null
			screen_mat.emission_texture = null
			screen_mat.emission_energy_multiplier = 0.15
			screen_mat.emission = Color("#0A1A12")
			light.light_energy = 0.0
		"face_a", "face_b":
			var t: Texture2D = face_texture(st == "face_a")
			screen_mat.albedo_texture = t
			screen_mat.emission_texture = t
			screen_mat.emission = Color.WHITE
			screen_mat.emission_energy_multiplier = 1.4
			light.light_color = Color("#9CFFB8")
			light.light_energy = 1.6
		"error":
			var e: Texture2D = error_texture()
			screen_mat.albedo_texture = e
			screen_mat.emission_texture = e
			screen_mat.emission = Color.WHITE
			screen_mat.emission_energy_multiplier = 1.2
			light.light_color = Color("#5C8DFF")
			light.light_energy = 1.4


## Za Mẫn's caricature (96 x 72, code-drawn): green-tinted CRT look, man bun, round glasses, laughing mouth (open or closed).
static func face_texture(open: bool) -> ImageTexture:
	var key: String = "face_%s" % str(open)
	if _tex.has(key):
		return _tex[key]
	var w: int = 96
	var h: int = 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#06140C"))
	var skin := Color("#E2B48C")
	var hair := Color("#141414")
	_ellipse(img, Vector2(48, 40), Vector2(19, 23), skin)          # face
	_ellipse(img, Vector2(48, 22), Vector2(20, 9), hair)           # hair cap
	_ellipse(img, Vector2(48, 10), Vector2(7, 6), hair)            # the man bun
	_ellipse(img, Vector2(29, 40), Vector2(3, 5), skin)            # ears
	_ellipse(img, Vector2(67, 40), Vector2(3, 5), skin)
	for cx: int in [40, 56]:
		_ring(img, Vector2(cx, 36), 6.5, 1.6, Color("#101010"))    # round glasses
		_ellipse(img, Vector2(cx, 36 if open else 37), Vector2(3, 1 if open else 2), Color("#101010"))   # squinting eyes
	_rect(img, Rect2i(46, 35, 4, 2), Color("#101010"))             # bridge
	if open:
		_ellipse(img, Vector2(48, 53), Vector2(9, 7), Color("#5A0E14"))
		_rect(img, Rect2i(41, 47, 14, 3), Color("#F4F1EA"))         # teeth
	else:
		_rect(img, Rect2i(40, 52, 16, 2), Color("#5A0E14"))
	# scanlines
	for y: int in range(0, h, 3):
		for x: int in w:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.25))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func error_texture() -> ImageTexture:
	if _tex.has("error"):
		return _tex["error"]
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color("#1E5AA8"))
	_rect(img, Rect2i(6, 8, 30, 3), Color("#DDE8FF"))
	_rect(img, Rect2i(6, 16, 44, 2), Color("#A9C4F0"))
	_rect(img, Rect2i(6, 21, 38, 2), Color("#A9C4F0"))
	_rect(img, Rect2i(6, 30, 12, 2), Color("#DDE8FF"))
	var t := ImageTexture.create_from_image(img)
	_tex["error"] = t
	return t


static func _ellipse(img: Image, c: Vector2, r: Vector2, col: Color) -> void:
	for y: int in range(maxi(int(c.y - r.y), 0), mini(int(c.y + r.y) + 1, img.get_height())):
		for x: int in range(maxi(int(c.x - r.x), 0), mini(int(c.x + r.x) + 1, img.get_width())):
			var d := Vector2((x - c.x) / r.x, (y - c.y) / r.y)
			if d.length_squared() <= 1.0:
				img.set_pixel(x, y, col)


static func _ring(img: Image, c: Vector2, r: float, th: float, col: Color) -> void:
	for y: int in range(maxi(int(c.y - r - th), 0), mini(int(c.y + r + th) + 1, img.get_height())):
		for x: int in range(maxi(int(c.x - r - th), 0), mini(int(c.x + r + th) + 1, img.get_width())):
			if absf(Vector2(x - c.x, y - c.y).length() - r) <= th * 0.5:
				img.set_pixel(x, y, col)


static func _rect(img: Image, rc: Rect2i, col: Color) -> void:
	for y: int in range(rc.position.y, mini(rc.end.y, img.get_height())):
		for x: int in range(rc.position.x, mini(rc.end.x, img.get_width())):
			img.set_pixel(x, y, col)


# ---------------------------------------------------------------------------
# STONKS chart
# ---------------------------------------------------------------------------
func _build_stonks() -> void:
	var dark: StandardMaterial3D = CineFX._mat(Color("#15171C"), 0.4)
	CineFX._box(self, "Stand", Vector3(0.08, 1.0, 0.08), Vector3(0.0, 0.5, 0.05), dark)
	CineFX._box(self, "Bezel", Vector3(1.7, 1.0, 0.06), Vector3(0.0, 1.45, 0.02), dark)
	CineFX._box(self, "Panel", Vector3(1.6, 0.9, 0.01), Vector3(0.0, 1.45, -0.012), CineFX._glow_mat(Color("#081018"), 0.6))
	var line: StandardMaterial3D = _line_mat(false)
	for i: int in CHART_SEGS:
		var mi := MeshInstance3D.new()
		mi.name = "Seg%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.022, 0.006)
		mi.mesh = bm
		mi.material_override = line
		add_child(mi)
		segs.append(mi)
	var t := Label3D.new()
	t.name = "Stonks"
	t.text = "STONKS"
	t.font_size = 96
	t.pixel_size = 0.0022
	t.outline_size = 10
	t.modulate = Color("#F4F1EA")
	t.position = Vector3(-0.35, 1.78, -0.03)
	t.rotation.y = PI
	add_child(t)
	ticker = Label3D.new()
	ticker.name = "Ticker"
	ticker.text = "LỌ THẦN 9.0   -99,9%"
	ticker.font_size = 56
	ticker.pixel_size = 0.0022
	ticker.outline_size = 8
	ticker.modulate = Color("#FF4A4A")
	ticker.position = Vector3(0.25, 1.1, -0.03)
	ticker.rotation.y = PI
	ticker.visible = false
	add_child(ticker)


## Chart value (0..1 of the panel height) at x (0..1) and dive progress d (0..1): a climb, then the right half falls off.
static func chart_value(x: float, d: float) -> float:
	var up: float = 0.15 + 0.7 * x + 0.06 * sin(x * 19.0)
	var fall: float = clampf((x - 0.45) / 0.55, 0.0, 1.0) * d
	return clampf(up - fall * 1.05, 0.03, 0.97)


func _eval_stonks(s: float, opts: Dictionary) -> void:
	var d: float = clampf((s - float(opts.get("dive_at", INF))) / float(opts.get("dive_dur", 1.2)), 0.0, 1.0)
	var key: String = "%.3f" % d
	if key == _last_key:
		return
	_last_key = key
	state = "dive" if d > 0.0 else "up"
	ticker.visible = d >= 0.6
	var x0: float = -0.7
	var span: float = 1.4
	for i: int in CHART_SEGS:
		var u0: float = float(i) / CHART_SEGS
		var u1: float = float(i + 1) / CHART_SEGS
		var p0 := Vector3(-(x0 + span * u0), 1.05 + 0.8 * chart_value(u0, d), -0.02)   # mirrored: read from -Z
		var p1 := Vector3(-(x0 + span * u1), 1.05 + 0.8 * chart_value(u1, d), -0.02)
		var mi: MeshInstance3D = segs[i]
		var dv: Vector3 = p1 - p0
		mi.position = (p0 + p1) * 0.5
		mi.rotation = Vector3(0.0, 0.0, atan2(dv.y, dv.x))
		mi.scale = Vector3(dv.length(), 1.0, 1.0)
		mi.material_override = _line_mat(d > 0.0 and u0 >= 0.45)


## Chart line material: green while it climbs, red where it dives (shared, cached).
static func _line_mat(red: bool) -> StandardMaterial3D:
	var k: String = "line_red" if red else "line_green"
	if not _tex.has(k):
		_tex[k] = CineFX._glow_mat(Color("#FF3B3B") if red else Color("#33E07A"), 2.3)
	return _tex[k]


# ---------------------------------------------------------------------------
# Fire
# ---------------------------------------------------------------------------
func _build_fire(opts: Dictionary) -> void:
	var n: int = int(opts.get("flames", 5))
	var spread: float = float(opts.get("spread", 0.8))
	for i: int in n:
		var mi := MeshInstance3D.new()
		mi.name = "Flame%d" % i
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.16
		cm.height = 0.6
		cm.radial_segments = 6
		mi.mesh = cm
		mi.material_override = CineFX._glow_mat(Color("#FF8A1E") if i % 2 == 0 else Color("#FFC23A"), 3.0)
		var a: float = TAU * float(i) / n
		mi.position = Vector3(cos(a) * spread * 0.5 * (0.4 + 0.6 * float(i % 3) / 2.0), 0.3, sin(a) * spread * 0.3)
		add_child(mi)
		flames.append(mi)
	light = OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color("#FF7A2A")
	light.omni_range = float(opts.get("range", 6.0))
	light.light_energy = 0.0
	light.position = Vector3(0.0, 0.9, 0.0)
	add_child(light)
	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 24
	embers.lifetime = 1.6
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(spread * 0.5, 0.1, 0.3)
	embers.direction = Vector3(0.0, 1.0, 0.0)
	embers.spread = 20.0
	embers.gravity = Vector3(0.0, 0.6, 0.0)
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 0.9
	embers.scale_amount_min = 0.02
	embers.scale_amount_max = 0.04
	var em := QuadMesh.new()
	em.size = Vector2(1.0, 1.0)
	embers.mesh = em
	embers.material_override = CineFX._glow_mat(Color("#FFB040"), 4.0)
	embers.fixed_fps = 30
	embers.use_fixed_seed = true
	embers.seed = 4242
	embers.position = Vector3(0.0, 0.5, 0.0)
	embers.set_meta("cine_ambient", true)   # CineFX follows the cinematic clock (freezes in freeze frames)
	add_child(embers)


func _eval_fire(s: float, opts: Dictionary) -> void:
	var on: bool = s >= float(opts.get("fire_from", 0.0))
	for i: int in flames.size():
		var mi: MeshInstance3D = flames[i]
		mi.visible = on
		var f: float = 0.75 + 0.25 * sin(s * 13.0 + float(i) * 1.7) + 0.12 * sin(s * 29.0 + float(i))
		mi.scale = Vector3(0.9 + 0.1 * f, f * (1.0 + 0.3 * float(i % 3)), 0.9 + 0.1 * f)
		mi.position.y = 0.3 * mi.scale.y
	light.light_energy = (2.2 + 0.6 * sin(s * 11.0) + 0.3 * sin(s * 23.0)) if on else 0.0
	state = "burning" if on else "out"


# ---------------------------------------------------------------------------
# Container doors
# ---------------------------------------------------------------------------
func _eval_doors(s: float, opts: Dictionary) -> void:
	var u: float = clampf((s - float(opts.get("open_at", INF))) / float(opts.get("open_dur", 1.6)), 0.0, 1.0)
	var e: float = u * u * (3.0 - 2.0 * u)
	for i: int in leaves.size():
		var side: float = -1.0 if i % 2 == 0 else 1.0   # left leaf swings to the left, right leaf to the right
		leaves[i].rotation.y = side * deg_to_rad(105.0) * e * -1.0
	state = "open" if u >= 1.0 else ("opening" if u > 0.0 else "shut")
