# File: res://scripts/cine/CineAnimD6.gd
# Day 6 animated props (plan 2026-11-01-w4-day6.md), code-built; CinePlayer poses them through cine_eval(s, opts) (prop opts
# "anim": true, the node is the prop's meta "anim_node"), pure in story time so seeking gives the same frame. Gameplay
# (LairCanal, the missions, the boat chase) drives the same nodes through the small setters below.
#   mode "dolls"      a shelf with two rows of five plush sheep dolls (front toward -Z), every doll turned to the wall; from
#                     "turn_at" over "turn_dur" (staggered) they turn to face "look_at" (prop-local). aim_heads(world, w).
#   mode "music_box"  a small wooden box, the lid up, a sheep figure that spins from "play_at". spin_to(angle).
#   mode "safe"       a dark-green safe whose door swings open from "open_at" (0.8 s). set_open(w).
#   mode "net"        a fishing net between two poles, raised out of the water from "raise_at" (0.6 s) with a red top
#                     line (the telegraph); "w", "h". set_raise(w), set_alarm(on).
#   mode "billboard"  the LỌ ACADEMY billboard (12 x 5 m on poles) with Lùm Văn Lọ's code-drawn face; dark until "on_at",
#                     a 0.6 s flicker, then lit. set_on(w).
#   mode "fireworks"  POOL sky bursts: opts "bursts" [[s, Vector3 pos, Color], ...]: a rocket streak rises 0.8 s, then a
#                     burst of sparks expands, falls and fades over BURST_S. Gameplay: burst_at(slot, age, pos, col).
class_name CineAnimD6
extends Node3D

const DOLLS_PER_ROW: int = 5
const ROWS_Y: Array[float] = [1.02, 1.62]
const SHELF_W: float = 1.9
const POOL: int = 6
const SPARKS: int = 36
const BURST_S: float = 2.2
const ROCKET_S: float = 0.8
const BOARD_W: float = 12.0
const BOARD_H: float = 5.0
const BOARD_Y: float = 6.0

var mode: String = ""
var dolls: Array[Node3D] = []
var spinner: Node3D
var door: Node3D
var net: Node3D
var net_top: MeshInstance3D
var net_h: float = 3.0
var board_mats: Array[StandardMaterial3D] = []
var board_labels: Array[Label3D] = []
var board_light: OmniLight3D
var bursts: Array[MultiMeshInstance3D] = []
var rockets: Array[MeshInstance3D] = []
var _dirs: PackedVector3Array = []
var state: String = ""   # tests: dolls wall | turning | facing; billboard off | flicker | on; net down | up


static func make(m: String, opts: Dictionary = {}) -> CineAnimD6:
	var n := CineAnimD6.new()
	n.name = "Anim_" + m
	n.mode = m
	match m:
		"dolls":
			n._build_dolls(int(opts.get("tint", 0)))
		"music_box":
			n._build_music_box()
		"safe":
			n._build_safe()
		"net":
			n._build_net(float(opts.get("w", 10.0)), float(opts.get("h", 3.0)))
		"billboard":
			n._build_billboard()
		"fireworks":
			n._build_fireworks()
	return n


func cine_eval(s: float, opts: Dictionary) -> void:
	match mode:
		"dolls":
			var t0: float = float(opts.get("turn_at", INF))
			var dur: float = maxf(float(opts.get("turn_dur", 1.2)), 0.05)
			var look: Vector3 = opts.get("look_at", Vector3(0.0, 1.3, -3.0))
			for i: int in dolls.size():
				var w: float = clampf((s - t0 - 0.07 * float(i)) / dur, 0.0, 1.0)
				_turn_doll(i, look, w * w * (3.0 - 2.0 * w))
			state = "wall" if s < t0 else ("facing" if s >= t0 + dur + 0.07 * float(dolls.size()) else "turning")
		"music_box":
			spin_to(maxf(s - float(opts.get("play_at", INF)), 0.0) * 2.4)
		"safe":
			set_open(clampf((s - float(opts.get("open_at", INF))) / 0.8, 0.0, 1.0))
		"net":
			set_raise(clampf((s - float(opts.get("raise_at", -INF))) / 0.6, 0.0, 1.0))
		"billboard":
			var on_at: float = float(opts.get("on_at", -INF))
			var u: float = s - on_at
			if u < 0.0:
				set_on(0.0)
			elif u < 0.6:
				set_on(1.0 if int(u * 13.0) % 3 != 1 else 0.15)   # the flicker pattern, deterministic in story time
				state = "flicker"
			else:
				set_on(1.0)
		"fireworks":
			var list: Array = opts.get("bursts", [])
			for k: int in POOL:
				bursts[k].visible = false
				rockets[k].visible = false
			for i: int in list.size():
				var b: Array = list[i]
				burst_at(i % POOL, s - float(b[0]), b[1], b[2])


# ---------------------------------------------------------------------------
# Dolls
# ---------------------------------------------------------------------------
func _build_dolls(tint: int) -> void:
	var wood: StandardMaterial3D = CineFX._mat(Color("#4A2E1E").lightened(0.05 * float(tint % 2)), 0.8)
	CineFX._box(self, "ShelfBack", Vector3(SHELF_W, 2.1, 0.06), Vector3(0.0, 1.05, 0.2), wood)
	for y: float in [0.4] + ROWS_Y:
		CineFX._box(self, "Board", Vector3(SHELF_W, 0.04, 0.42), Vector3(0.0, y, 0.0), wood)
	for sx: float in [-1.0, 1.0]:
		CineFX._box(self, "Post", Vector3(0.05, 2.1, 0.42), Vector3(sx * SHELF_W * 0.5, 1.05, 0.0), wood)
	for r: int in ROWS_Y.size():
		for i: int in DOLLS_PER_ROW:
			var holder := Node3D.new()
			holder.name = "Slot%d_%d" % [r, i]
			holder.position = Vector3(-SHELF_W * 0.4 + SHELF_W * 0.8 * float(i) / float(DOLLS_PER_ROW - 1), ROWS_Y[r] + 0.02, 0.0)
			add_child(holder)
			CinePropsD6.sheep_doll(holder, "Doll")
			var d: Node3D = holder.get_node("Doll") as Node3D
			d.rotation.y = PI   # facing the shelf back (their backs to the room)
			d.scale = Vector3.ONE * (0.95 + 0.1 * float((i + r + tint) % 3) / 2.0)
			dolls.append(d)
	state = "wall"


## Doll i turned by w (0 = to the wall, 1 = facing `look` in this node's frame).
func _turn_doll(i: int, look: Vector3, w: float) -> void:
	var d: Node3D = dolls[i]
	var p: Vector3 = (d.get_parent() as Node3D).position
	var face: float = atan2(-(look.x - p.x), -(look.z - p.z))
	d.rotation.y = lerp_angle(PI, face, w)
	var head: Node3D = d.get_meta("head", null)
	if head:
		head.rotation.x = -0.25 * w   # a slight tilt down at the end: they look at you


## Gameplay: every doll turned by w toward a world point (the player), staggered along the shelf.
func aim_heads(world: Vector3, w: float) -> void:
	var look: Vector3 = to_local(world)
	for i: int in dolls.size():
		var wi: float = clampf(w * 1.4 - 0.04 * float(i), 0.0, 1.0)
		_turn_doll(i, look, wi * wi * (3.0 - 2.0 * wi))
	state = "wall" if w <= 0.0 else ("facing" if w >= 1.0 else "turning")


# ---------------------------------------------------------------------------
# Music box, safe
# ---------------------------------------------------------------------------
func _build_music_box() -> void:
	var wood: StandardMaterial3D = CineFX._mat(Color("#7A3B22"), 0.5)
	CineFX._box(self, "Box", Vector3(0.24, 0.12, 0.18), Vector3(0.0, 0.81, 0.4), wood)
	CineFX._box(self, "Lid", Vector3(0.24, 0.16, 0.012), Vector3(0.0, 0.94, 0.49), wood, Vector3(-0.35, 0.0, 0.0))
	CineFX._box(self, "Mirror", Vector3(0.2, 0.12, 0.004), Vector3(0.0, 0.94, 0.482), CineFX._mat(Color("#C9D2DC"), 0.05), Vector3(-0.35, 0.0, 0.0))
	CineFX._cyl(self, "Stage", 0.05, 0.05, 0.01, Vector3(0.0, 0.875, 0.4), CineFX._mat(Color("#E8C15A"), 0.3))
	spinner = Node3D.new()
	spinner.name = "Spinner"
	spinner.position = Vector3(0.0, 0.88, 0.4)
	spinner.scale = Vector3.ONE * 0.45
	add_child(spinner)
	CinePropsD6.sheep_doll(spinner, "Dancer")
	var glow := OmniLight3D.new()
	glow.name = "BoxGlow"
	glow.light_color = Color("#FF8FB0")
	glow.light_energy = 0.4
	glow.omni_range = 1.6
	glow.position = Vector3(0.0, 1.05, 0.4)
	add_child(glow)


func spin_to(angle: float) -> void:
	if spinner:
		spinner.rotation.y = angle


func _build_safe() -> void:
	var green: StandardMaterial3D = CineFX._mat(Color("#20362C"), 0.45)
	green.metallic = 0.5
	CineFX._box(self, "Body", Vector3(0.7, 0.9, 0.6), Vector3(0.0, 0.45, 0.0), green)
	CineFX._box(self, "Inside", Vector3(0.6, 0.8, 0.02), Vector3(0.0, 0.45, 0.26), CineFX._mat(Color("#0D1410"), 0.9))
	door = Node3D.new()
	door.name = "Door"
	door.position = Vector3(-0.35, 0.0, -0.31)   # hinge on the left front edge
	add_child(door)
	CineFX._box(door, "Leaf", Vector3(0.68, 0.86, 0.06), Vector3(0.34, 0.45, 0.0), green)
	CineFX._cyl(door, "Dial", 0.07, 0.07, 0.03, Vector3(0.34, 0.55, -0.04), CineFX._mat(Color("#C9C9C9"), 0.3)).rotation.x = PI * 0.5
	CineFX._box(door, "Handle", Vector3(0.12, 0.03, 0.03), Vector3(0.5, 0.35, -0.05), CineFX._mat(Color("#C9C9C9"), 0.3))


## 0 = shut, 1 = open (the door swung 100 degrees out to the left).
func set_open(w: float) -> void:
	if door:
		door.rotation.y = deg_to_rad(100.0) * clampf(w, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Net
# ---------------------------------------------------------------------------
func _build_net(w: float, h: float) -> void:
	net_h = h
	var pole: StandardMaterial3D = CineFX._mat(Color("#5A3A28"), 0.8)
	for sx: float in [-1.0, 1.0]:
		CineFX._cyl(self, "Pole", 0.09, 0.11, h + 2.5, Vector3(sx * w * 0.5, (h + 2.5) * 0.5 - 1.5, 0.0), pole)
		CinePropsD6.lantern(self, Vector3(sx * w * 0.5, h + 1.2, 0.0), Color("#FF3030"))
	net = Node3D.new()
	net.name = "Net"
	add_child(net)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for k: int in 64:
		for j: int in [0, 1, 32, 33]:
			img.set_pixel(k, j, Color(0.85, 0.82, 0.7, 1.0))
			img.set_pixel(j, k, Color(0.85, 0.82, 0.7, 1.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(w / 1.0, h / 1.0, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var q := MeshInstance3D.new()
	q.name = "Mesh"
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.material_override = mat
	q.position = Vector3(0.0, h * 0.5, 0.0)
	net.add_child(q)
	net_top = CineFX._box(net, "TopLine", Vector3(w, 0.08, 0.08), Vector3(0.0, h, 0.0), CineFX._glow_mat(Color("#FF2A2A"), 2.5))
	set_raise(0.0)


## 0 = under water, 1 = raised (its top at h above the water line).
func set_raise(w: float) -> void:
	if net:
		net.position.y = -net_h - 0.3 + (net_h + 0.3) * clampf(w, 0.0, 1.0)
		state = "up" if w >= 1.0 else "down"


func set_alarm(on: bool) -> void:
	if net_top:
		net_top.visible = on


# ---------------------------------------------------------------------------
# Billboard
# ---------------------------------------------------------------------------
func _build_billboard() -> void:
	var steel: StandardMaterial3D = CineFX._mat(Color("#2A2C33"), 0.5)
	for sx: float in [-0.3, 0.3]:
		CineFX._box(self, "Pole", Vector3(0.35, BOARD_Y, 0.35), Vector3(sx * BOARD_W, BOARD_Y * 0.5, 0.3), steel)
	CineFX._box(self, "Frame", Vector3(BOARD_W + 0.4, BOARD_H + 0.4, 0.3), Vector3(0.0, BOARD_Y + BOARD_H * 0.5, 0.3), steel)
	var panel := _board_mat(Color("#1E0F2E"))
	CineFX._box(self, "Panel", Vector3(BOARD_W, BOARD_H, 0.05), Vector3(0.0, BOARD_Y + BOARD_H * 0.5, 0.12), panel)
	# Lùm Văn Lọ, code-drawn on the left third: a round face, slicked black hair, round gold glasses, a gold-tooth grin
	var fx: float = -BOARD_W * 0.3
	var fy: float = BOARD_Y + BOARD_H * 0.5
	CineFX._sphere(self, "Face", 1.5, Vector3(fx, fy - 0.1, 0.05), _board_mat(Color("#E8B48A")), Vector3(1.0, 1.15, 0.12))
	CineFX._sphere(self, "Hair", 1.55, Vector3(fx, fy + 0.55, 0.06), _board_mat(Color("#141414")), Vector3(1.05, 0.55, 0.1))
	for gx: float in [-0.5, 0.5]:
		var ring := MeshInstance3D.new()
		ring.name = "Glass"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.28
		tm.outer_radius = 0.38
		ring.mesh = tm
		ring.material_override = _board_mat(Color("#E8C15A"))
		ring.position = Vector3(fx + gx, fy + 0.15, -0.05)
		ring.rotation.x = PI * 0.5
		add_child(ring)
		CineFX._sphere(self, "Eye", 0.11, Vector3(fx + gx, fy + 0.15, -0.04), _board_mat(Color("#141414")), Vector3(1.0, 1.0, 0.3))
		CineFX._box(self, "Brow", Vector3(0.55, 0.1, 0.05), Vector3(fx + gx, fy + 0.62, -0.05), _board_mat(Color("#141414")), Vector3(0.0, 0.0, -gx * 0.5))
	CineFX._box(self, "Grin", Vector3(1.1, 0.3, 0.05), Vector3(fx, fy - 0.65, -0.05), _board_mat(Color("#5A1020")))
	for t: int in 5:
		CineFX._box(self, "Tooth", Vector3(0.17, 0.12, 0.04), Vector3(fx - 0.4 + 0.2 * float(t), fy - 0.56, -0.08), _board_mat(Color("#F2D16B") if t == 2 else Color("#F4F1EA")))
	board_labels.append(CinePropsD6.text(self, "Title", "LỌ ACADEMY", 260, Color("#FFD43B"), Vector3(BOARD_W * 0.17, fy + 1.0, -0.02), true))
	board_labels.append(CinePropsD6.text(self, "Slogan", "ĐẬU 100%, KHÔNG CẦN HỌC", 120, Color("#FFFFFF"), Vector3(BOARD_W * 0.17, fy - 0.2, -0.02), true))
	board_labels.append(CinePropsD6.text(self, "Small", "Hotline: 1900 LỌ LỌ", 80, Color("#FF7AC0"), Vector3(BOARD_W * 0.17, fy - 1.3, -0.02), true))
	for i: int in 6:
		CineFX._box(self, "Spot", Vector3(0.3, 0.18, 0.3), Vector3(-BOARD_W * 0.42 + BOARD_W * 0.168 * float(i), BOARD_Y - 0.1, -0.5), _board_mat(Color("#FFF2CC")))
	board_light = OmniLight3D.new()
	board_light.name = "BoardLight"
	board_light.light_color = Color("#FFD9F0")
	board_light.omni_range = 16.0
	board_light.position = Vector3(0.0, BOARD_Y + BOARD_H * 0.5, -4.0)
	add_child(board_light)
	set_on(0.0)


func _board_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col * 0.25
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.0
	m.set_meta("vice_done", true)
	m.set_meta("lit", 1.4)
	board_mats.append(m)
	return m


## 0 = dark, 1 = lit.
func set_on(w: float) -> void:
	for m: StandardMaterial3D in board_mats:
		m.emission_energy_multiplier = float(m.get_meta("lit", 1.0)) * w
	for l: Label3D in board_labels:
		l.modulate.a = 0.12 + 0.88 * w
	if board_light:
		board_light.light_energy = 2.2 * w
	state = "on" if w >= 1.0 else ("off" if w <= 0.0 else state)


# ---------------------------------------------------------------------------
# Fireworks
# ---------------------------------------------------------------------------
func _build_fireworks() -> void:
	var golden: float = PI * (3.0 - sqrt(5.0))
	for i: int in SPARKS:
		var y: float = 1.0 - 2.0 * (float(i) + 0.5) / float(SPARKS)
		var r: float = sqrt(1.0 - y * y)
		_dirs.append(Vector3(cos(golden * float(i)) * r, y, sin(golden * float(i)) * r))
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 6
	sm.rings = 3
	for k: int in POOL:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Burst%d" % k
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sm
		mm.instance_count = SPARKS
		mmi.multimesh = mm
		mmi.material_override = CineFX._glow_mat(Color.WHITE, 4.0)
		mmi.visible = false
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		bursts.append(mmi)
		var rk: MeshInstance3D = CineFX._sphere(self, "Rocket%d" % k, 0.14, Vector3.ZERO, CineFX._glow_mat(Color("#FFE6A0"), 4.0), Vector3(1.0, 2.5, 1.0))
		rk.visible = false
		rockets.append(rk)


## Pool slot k: the rocket at age < 0 (rising from below `pos` for ROCKET_S), the burst at 0 <= age < BURST_S.
func burst_at(k: int, age: float, pos: Vector3, col: Color) -> void:
	var mmi: MultiMeshInstance3D = bursts[k]
	var rk: MeshInstance3D = rockets[k]
	if age < -ROCKET_S or age >= BURST_S:
		mmi.visible = false
		rk.visible = false
		return
	if age < 0.0:
		mmi.visible = false
		rk.visible = true
		var u: float = 1.0 + age / ROCKET_S
		rk.position = pos + Vector3(0.0, -18.0 * (1.0 - u), 0.0)
		return
	rk.visible = false
	mmi.visible = true
	var m: StandardMaterial3D = mmi.material_override as StandardMaterial3D
	m.albedo_color = col
	m.emission = col
	var fade: float = 1.0 - age / BURST_S
	m.emission_energy_multiplier = 5.0 * fade
	var rad: float = 9.0 * (1.0 - exp(-3.0 * age))
	var drop: float = 1.4 * age * age
	var sc: float = maxf(fade, 0.05)
	for i: int in SPARKS:
		var p: Vector3 = pos + _dirs[i] * rad - Vector3(0.0, drop, 0.0)
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), p - pos))
	mmi.position = pos
