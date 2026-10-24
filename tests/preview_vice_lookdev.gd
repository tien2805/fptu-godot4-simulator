# File: res://tests/preview_vice_lookdev.gd
# LOOK-DEV phong cách "GTA Vice City" (chỉ mượn PHONG CÁCH: bảng màu pastel/hoàng hôn, sương xa, bloom, vật liệu lì
# kiểu PS2, cọ, neon đêm, HUD radar + tiền). Không dùng asset, font, logo hay tên của Rockstar.
# Script KHÔNG sửa code game: môi trường "vice", LUT, pass vật liệu, cây cọ, neon và HUD mẫu đều nằm ở đây để
# chủ dự án duyệt hướng đi trước khi chuyển vào GameFX / MapBuilder / HUD thật.
#
# Chạy (cần cửa sổ):  godot --path . --script tests/preview_vice_lookdev.gd
# Ảnh: user://preview/vice_<shot>_<classic|vice>.png  (classic = đồ hoạ hiện tại qua GameFX.upgrade_scene_visuals)
extends SceneTree

const OUT_DIR: String = "user://preview"
const SETTLE_FRAMES: int = 45            # chờ bóng / SDFGI (classic) ổn định trước khi chụp
const SKIP_HUTECH_AND_RING: Array = [13698121, 605379726, 605379727, 605379728]

## Bảng thông số Vice City theo giờ (look-dev). shadow/high = màu tách tông cho LUT 3D.
const VICE: Dictionary = {
	"sunset": {"top": Color("#2c1d5e"), "horizon": Color("#ff7f8f"), "ground_h": Color("#ffb08a"), "ground_b": Color("#3a2747"),
		"sun": Color("#ffb46e"), "energy": 1.55, "elev": 9.0, "azim": -95.0,
		"fog": Color("#f3b0a6"), "fog_begin": 150.0, "fog_end": 2200.0, "sky_fog": 0.25,
		"exposure": 1.06, "glow": 0.85, "bloom": 0.12, "thr": 1.0, "sat": 1.2, "contrast": 1.0,
		"amb": 1.0, "amb_col": Color("#d9a0c8"), "shadow": Color("#3b2e74"), "high": Color("#ffe2c2"), "lift": 0.03, "windows": 0.0},
	"day": {"top": Color("#2f9ff2"), "horizon": Color("#c8eef4"), "ground_h": Color("#e8f3e8"), "ground_b": Color("#6a7a70"),
		"sun": Color("#fff2d8"), "energy": 1.45, "elev": 55.0, "azim": 150.0,
		"fog": Color("#d6f0f4"), "fog_begin": 140.0, "fog_end": 1800.0, "sky_fog": 0.25,
		"exposure": 1.18, "glow": 0.45, "bloom": 0.03, "thr": 1.75, "sat": 1.22, "contrast": 0.96,
		"amb": 1.15, "amb_col": Color("#c6e4ee"), "shadow": Color("#2b5c74"), "high": Color("#fff1dc"), "lift": 0.03, "windows": 0.0},
	"night": {"top": Color("#0a0626"), "horizon": Color("#3e2172"), "ground_h": Color("#2a1a4a"), "ground_b": Color("#07050f"),
		"sun": Color("#8ea6ff"), "energy": 0.3, "elev": 38.0, "azim": 200.0,
		"fog": Color("#2b1a55"), "fog_begin": 40.0, "fog_end": 700.0, "sky_fog": 0.5,
		"exposure": 1.0, "glow": 0.9, "bloom": 0.1, "thr": 1.1, "sat": 1.15, "contrast": 1.02,
		"amb": 0.3, "amb_col": Color("#4a3a8f"), "shadow": Color("#140a3a"), "high": Color("#ff9ad6"), "lift": 0.02, "windows": 0.12},
}
const NEON_COLORS: Array[Color] = [Color("#ff4fd8"), Color("#3ff2ff"), Color("#a45cff"), Color("#ff9a3c")]

var md: MapData
var gfx                              # GameFX.gd (Script) – gọi hàm static động, không có autoload trong --script
var world: Node3D
var we: WorldEnvironment
var sun: DirectionalLight3D
var cam: Camera3D
var campus_root: Node3D
var vice_only: Array[Node3D] = []   # cọ: chỉ hiện ở phong cách vice
var neon_root: Node3D               # neon: chỉ hiện ban đêm phong cách vice
var hud: CanvasLayer
var hud_area: Label
var hud_clock: Label
var radar: Radar
var shots: Array = []
var style: String = "classic"
var shot_i: int = 0
var wait: int = 0
var frames: int = 0
var out_dir: String
var _done_mats: Dictionary = {}
var _lut_cache: Dictionary = {}


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_dir)
	md = MapData.load_default()
	gfx = load("res://scripts/GameFX.gd")
	world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	we = WorldEnvironment.new()
	we.environment = Environment.new()
	world.add_child(we)
	sun = DirectionalLight3D.new()
	world.add_child(sun)
	cam = Camera3D.new()
	cam.far = 4000.0
	world.add_child(cam)
	cam.current = true
	_build_world()
	_build_hud()
	_define_shots()
	_begin_shot()
	print("VICE LOOKDEV: %d shots x 2 styles -> %s" % [shots.size(), out_dir])


# ---------------------------------------------------------------------------------------------------------------
# THẾ GIỚI: Vinhomes (MapBuilder) + campus v8 trên lô đất thật + mặt đất lớn + nhân vật + cọ (vice) + neon (vice đêm)
# ---------------------------------------------------------------------------------------------------------------
func _build_world() -> void:
	var t0: int = Time.get_ticks_msec()
	MapBuilder.build_region(world, md, "vinhomes", {"labels": false})
	var m: Dictionary = FPTUCampusBuilder.make_materials()
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var yaw_deg: float = rad_to_deg(xf.basis.get_euler().y)
	campus_root = FPTUCampusBuilder.build_authentic_campus(world, xf.origin, yaw_deg, {"grass": true})
	FPTUCampusBuilder.build_hutech(campus_root, FPTUCampusBuilder.hutech_origin_local(), m)
	FPTUCampusBuilder.build_d1_road_piece(campus_root, FPTUCampusBuilder.ROAD_CENTER_V, -160.0, 360.0, m, 0.0)
	# mặt đất xa (vùng ngoài region buffer) – trong sương vice sẽ tan vào màu sương
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000.0, 12000.0)
	ground.mesh = pm
	ground.position = Vector3(2000.0, -0.05, -200.0)
	ground.material_override = m["grass"]
	world.add_child(ground)
	_add_people()
	_add_palms_vinhomes()
	_add_palms_d1()
	_build_neon()
	print("  world built in %d ms" % (Time.get_ticks_msec() - t0))


func _add_people() -> void:
	var sp: Transform3D = md.spawn_transform()
	var fwd: Vector3 = -sp.basis.z
	var side: Vector3 = sp.basis.x
	var presets: Array[String] = ["student_m", "student_f", "casual", "player"]
	for i: int in range(4):
		var c: Node3D = CharacterBuilder.build({"preset": presets[i], "seed": 700 + i * 13, "rigged": true})
		world.add_child(c)
		c.position = sp.origin + fwd * (6.0 + i * 2.2) + side * (-2.5 + i * 1.6)
		c.rotation.y = sp.basis.get_euler().y + (PI if i % 2 == 0 else 0.0)
		CharacterBuilder.set_speed(c, 1.1 if i < 3 else 0.0)
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var gate: Vector3 = FPTUCampusBuilder.main_gate_local()
	for i: int in range(5):
		var c2: Node3D = CharacterBuilder.build({"preset": "student_m" if i % 2 == 0 else "student_f", "seed": 900 + i * 7, "rigged": true})
		world.add_child(c2)
		c2.transform = Transform3D(xf.basis, xf * (gate + Vector3(-4.0 + i * 2.1, 0.0, 3.0 + (i % 2) * 1.5)))
		c2.rotate_y(PI * 0.5 if i % 2 == 0 else -PI * 0.5)
		CharacterBuilder.set_speed(c2, 1.2)


## Cọ kiểu Vice City: thân cong nhẹ, 12 tàu lá rủ cong làm bằng SurfaceTool (một mesh dùng chung), chùm dừa.
var _frond_mesh: ArrayMesh
var _palm_mats: Dictionary = {}

func _palm_materials() -> Dictionary:
	if not _palm_mats.is_empty():
		return _palm_mats
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color("#3f9e52")
	leaf.roughness = 0.9
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trunk := StandardMaterial3D.new()
	trunk.albedo_color = Color("#a08c70")
	trunk.roughness = 0.95
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color("#7d6b55")
	ring.roughness = 0.95
	var nut := StandardMaterial3D.new()
	nut.albedo_color = Color("#6b4a2a")
	nut.roughness = 0.8
	_palm_mats = {"leaf": leaf, "trunk": trunk, "ring": ring, "nut": nut}
	return _palm_mats


func _frond() -> ArrayMesh:
	if _frond_mesh:
		return _frond_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 8
	var seg_len: float = 0.5
	var p := Vector3.ZERO
	var pitch: float = deg_to_rad(28.0)      # bắt đầu chếch lên
	var pts: Array[Vector3] = []
	var widths: Array[float] = []
	for i: int in range(segs + 1):
		pts.append(p)
		var t: float = float(i) / float(segs)
		widths.append(lerpf(0.12, 0.95, sin(t * PI) * 0.9 + 0.1) * (1.0 - t * 0.55))
		p += Vector3(0.0, sin(pitch), cos(pitch)) * seg_len
		pitch -= deg_to_rad(13.0)            # rủ dần xuống
	for i: int in range(segs):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var wa: float = widths[i] * 0.5
		var wb: float = widths[i + 1] * 0.5
		var fold: float = 0.06               # gân giữa nhô lên: lá gập hình chữ V nông
		var a_l := a + Vector3(-wa, -fold, 0.0)
		var a_r := a + Vector3(wa, -fold, 0.0)
		var b_l := b + Vector3(-wb, -fold, 0.0)
		var b_r := b + Vector3(wb, -fold, 0.0)
		for tri: Array in [[a, b, a_l], [a_l, b, b_l], [a, a_r, b], [a_r, b_r, b]]:
			for v: Vector3 in tri:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	st.generate_normals()
	_frond_mesh = st.commit()
	return _frond_mesh


func _vice_palm(parent: Node3D, pos: Vector3, height: float, seed_val: int) -> Node3D:
	var mats: Dictionary = _palm_materials()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = rng.randf() * TAU
	parent.add_child(p)
	var lean: float = rng.randf_range(0.0, 0.12)
	var segs: int = 5
	var top := Vector3.ZERO
	for i: int in range(segs):
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var t: float = float(i) / float(segs)
		cm.top_radius = lerpf(0.22, 0.16, t + 0.2)
		cm.bottom_radius = lerpf(0.26, 0.18, t)
		cm.height = height / segs
		cm.radial_segments = 10
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mats["trunk"] if i % 2 == 0 else mats["ring"]
		var seg_h: float = height / segs
		var offs := Vector3(lean * height * t * t, seg_h * (i + 0.5), 0.0)
		mi.position = offs
		mi.rotation.z = -lean * 1.6 * t
		p.add_child(mi)
		top = Vector3(lean * height * 1.0, height, 0.0)
	var crown := Node3D.new()
	crown.position = top + Vector3(0.0, 0.1, 0.0)
	p.add_child(crown)
	var n: int = 12
	for k: int in range(n):
		var f := MeshInstance3D.new()
		f.mesh = _frond()
		f.material_override = mats["leaf"]
		f.rotation = Vector3(deg_to_rad(rng.randf_range(-8.0, 10.0)), k * TAU / n + rng.randf_range(-0.12, 0.12), 0.0)
		f.scale = Vector3.ONE * rng.randf_range(1.05, 1.35)
		crown.add_child(f)
	for k: int in range(3):
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		s.mesh = sm
		s.material_override = mats["nut"]
		s.position = Vector3(cos(k * 2.1) * 0.2, -0.25, sin(k * 2.1) * 0.2)
		crown.add_child(s)
	vice_only.append(p)
	p.visible = false
	return p


func _add_palms_vinhomes() -> void:
	var sp: Vector3 = md.spawn_transform().origin
	var sp2 := Vector2(sp.x, sp.z)
	var segs: Array = []          # [khoảng cách, a, b, half]
	for r: Dictionary in md.roads("vinhomes"):
		if int(r.get("lanes", 0)) == 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r["points"])
		var half: float = float(r.get("width", 6.0)) * 0.5 + 2.6
		for i: int in range(pts.size() - 1):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(sp2, pts[i], pts[i + 1])
			var dd: float = q.distance_to(sp2)
			if dd < 320.0 and pts[i].distance_to(pts[i + 1]) >= 4.0:
				segs.append([dd, pts[i], pts[i + 1], half])
	segs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var placed: int = 0
	for sg: Array in segs:
		var a: Vector2 = sg[1]
		var b: Vector2 = sg[2]
		var half2: float = float(sg[3])
		var d: Vector2 = b - a
		var L: float = d.length()
		var dir: Vector2 = d / L
		var nrm := Vector2(-dir.y, dir.x)
		var t: float = 6.0
		while t < L - 3.0 and placed < 160:
			for sgn: float in [-1.0, 1.0]:
				var q2: Vector2 = a + dir * t + nrm * half2 * sgn
				_vice_palm(world, Vector3(q2.x, 0.0, q2.y), 9.0 + float((placed * 7) % 5), 1000 + placed)
				placed += 1
			t += 14.0
		if placed >= 160:
			break
	print("  palms (vinhomes): %d" % placed)


func _add_palms_d1() -> void:
	var u: float = -60.0
	var placed: int = 0
	while u < 200.0:
		if absf(u - FPTUCampusBuilder.MAIN_GATE_U) > 9.0:
			for v: float in [-3.2, FPTUCampusBuilder.ROAD_CENTER_V - 9.0]:
				var palm: Node3D = _vice_palm(campus_root, Vector3(u, 0.0, v), 9.5 + float(placed % 4), 3000 + placed)
				palm.position = Vector3(u, 0.0, v)
				placed += 1
		u += 13.0
	print("  palms (D1): %d" % placed)


## Neon viền mái + dải biển hiệu tầng trệt theo đúng footprint OSM (MultiMesh theo màu, chỉ hiện ban đêm vice)
func _build_neon() -> void:
	neon_root = Node3D.new()
	neon_root.name = "Neon"
	world.add_child(neon_root)
	var per_color: Array = [[], [], [], []]
	var bi: int = 0
	for b: Dictionary in md.buildings("vinhomes"):
		if String(b.get("source", "osm")) == "msft":
			continue   # raw Microsoft outlines are clipped at build time; neon would float over roads
		var outer: PackedVector2Array = MapData.poly(b["outer"])
		if outer.size() < 4:
			continue
		var h: float = float(b.get("height", 10.0))
		var ci: int = bi % NEON_COLORS.size()
		bi += 1
		var c := Vector2.ZERO
		for q: Vector2 in outer:
			c += q
		c /= float(outer.size())
		var heights: Array[float] = [h + 0.55, 3.6]
		for i: int in range(outer.size() - 1):
			var a: Vector2 = outer[i]
			var e: Vector2 = outer[i + 1]
			var L: float = a.distance_to(e)
			if L < 1.0:
				continue
			var mid: Vector2 = (a + e) * 0.5
			var out_dir: Vector2 = (mid - c).normalized()
			mid += out_dir * 0.18
			var yaw: float = atan2(-(e - a).y, (e - a).x)
			for y: float in heights:
				var basis: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(L, 0.22, 0.22))
				per_color[ci].append(Transform3D(basis, Vector3(mid.x, y, mid.y)))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	for ci: int in range(NEON_COLORS.size()):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		var arr: Array = per_color[ci]
		mm.instance_count = arr.size()
		for k: int in range(arr.size()):
			mm.set_instance_transform(k, arr[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = NEON_COLORS[ci]
		mat.emission_enabled = true
		mat.emission = NEON_COLORS[ci]
		mat.emission_energy_multiplier = 4.0
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		neon_root.add_child(mmi)
	neon_root.visible = false
	print("  neon strips: %d" % (per_color[0].size() + per_color[1].size() + per_color[2].size() + per_color[3].size()))


# ---------------------------------------------------------------------------------------------------------------
# HUD mẫu kiểu Vice City (chỉ phong cách): giờ + tiền Cóc Vàng + sao "Mr.T để ý" góc trên phải, radar tròn góc
# dưới trái vẽ từ mapdata, tên khu vực chữ nghiêng hồng góc dưới phải. Chỉ anchors/containers.
# ---------------------------------------------------------------------------------------------------------------
func _italic_font(embolden: float = 0.6, slant: float = 0.22) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = embolden
	fv.variation_transform = Transform2D(Vector2(1.0, slant), Vector2(0.0, 1.0), Vector2.ZERO)
	return fv


func _hud_label(text: String, size: int, col: Color, outline: Color, outline_size: int, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 50
	root.add_child(hud)
	var font_i: FontVariation = _italic_font()
	# góc trên phải
	var tr := MarginContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for side: String in ["margin_right", "margin_top"]:
		tr.add_theme_constant_override(side, 28)
	hud.add_child(tr)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", -4)
	tr.add_child(col)
	hud_clock = _hud_label("07:12", 44, Color("#f4f1ff"), Color("#1b0f33"), 8, font_i)
	col.add_child(hud_clock)
	col.add_child(_hud_label("00001250 CV", 40, Color("#9bea7a"), Color("#0b1a06"), 8, font_i))
	var stars := StarRow.new()
	stars.filled = 2
	stars.custom_minimum_size = Vector2(5 * 34, 34)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(stars)
	col.add_child(_hud_label("THẦY TOÀN ĐỂ Ý", 15, Color("#ffb3e6"), Color("#1b0f33"), 5, _italic_font(0.3, 0.15)))
	# radar góc dưới trái
	var bl := MarginContainer.new()
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side: String in ["margin_left", "margin_bottom"]:
		bl.add_theme_constant_override(side, 28)
	hud.add_child(bl)
	radar = Radar.new()
	radar.md = md
	radar.custom_minimum_size = Vector2(200, 200)
	bl.add_child(radar)
	# tên khu vực góc dưới phải
	var br := MarginContainer.new()
	br.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side: String in ["margin_right", "margin_bottom"]:
		br.add_theme_constant_override(side, 34)
	hud.add_child(br)
	hud_area = _hud_label("Vinhomes Grand Park", 50, Color("#ff7ac8"), Color("#2a0e3a"), 10, _italic_font(0.9, 0.28))
	br.add_child(hud_area)
	hud.visible = false


class StarRow extends Control:
	var filled: int = 0
	func _draw() -> void:
		var r: float = size.y * 0.46
		for i: int in range(5):
			var c := Vector2(size.x - (i + 0.5) * size.y, size.y * 0.5)
			var pts := PackedVector2Array()
			for k: int in range(10):
				var rad: float = r if k % 2 == 0 else r * 0.45
				var a: float = -PI * 0.5 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			var on: bool = i < filled
			draw_colored_polygon(pts, Color("#ffd166") if on else Color(0.1, 0.06, 0.18, 0.55))
			pts.append(pts[0])
			draw_polyline(pts, Color("#1b0f33"), 2.5, true)


class Radar extends Control:
	var md: MapData
	var center := Vector2.ZERO      # toạ độ thế giới (x, z) của người chơi
	var yaw: float = 0.0            # yaw camera (rad): phía trên radar = hướng nhìn
	var target := Vector2.ZERO      # blip mục tiêu (cổng FPT)
	var range_m: float = 170.0
	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		var c := Vector2(r, r)
		draw_circle(c, r, Color(0.04, 0.03, 0.1, 0.78))
		var k: float = (r - 6.0) / range_m
		if md:
			for road: Dictionary in md.roads():
				var pts: PackedVector2Array = MapData.poly(road["points"])
				var w: float = 3.0 if int(road.get("lanes", 0)) >= 2 else (2.0 if int(road.get("lanes", 0)) == 1 else 1.0)
				var col := Color("#d9d2ff") if int(road.get("lanes", 0)) > 0 else Color("#8f86c4")
				for i: int in range(pts.size() - 1):
					var a: Vector2 = _to_radar(pts[i], c, k)
					var b: Vector2 = _to_radar(pts[i + 1], c, k)
					if a.distance_to(c) > r - 4.0 and b.distance_to(c) > r - 4.0:
						continue
					draw_line(_clip(a, c, r - 4.0), _clip(b, c, r - 4.0), col, w, true)
		# blip mục tiêu (hình vuông cam ở mép nếu ngoài tầm)
		var tb: Vector2 = _clip(_to_radar(target, c, k), c, r - 10.0)
		draw_rect(Rect2(tb - Vector2(7, 7), Vector2(14, 14)), Color("#f37021"))
		draw_rect(Rect2(tb - Vector2(7, 7), Vector2(14, 14)), Color("#1b0f33"), false, 2.0)
		# người chơi: mũi tên trắng
		var tri := PackedVector2Array([c + Vector2(0, -11), c + Vector2(8, 9), c + Vector2(0, 4), c + Vector2(-8, 9)])
		draw_colored_polygon(tri, Color.WHITE)
		# chữ N
		var north: Vector2 = _clip(c + Vector2(0, -1000).rotated(-yaw), c, r - 12.0)
		draw_circle(north, 9.0, Color("#1b0f33"))
		draw_string(ThemeDB.fallback_font, north + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		draw_arc(c, r - 1.5, 0.0, TAU, 96, Color("#ff5fb0"), 4.0, true)
	func _to_radar(p: Vector2, c: Vector2, k: float) -> Vector2:
		return c + ((p - center) * k).rotated(-yaw)
	func _clip(p: Vector2, c: Vector2, rr: float) -> Vector2:
		var d: Vector2 = p - c
		return c + d.limit_length(rr)


## Đèn cửa sổ ban đêm: tách pixel kính (xanh lam/ngọc) trong texture mặt tiền thành texture phát sáng màu ấm.
var _window_tex: Dictionary = {}

func _window_emission(style_name: String) -> Texture2D:
	if _window_tex.has(style_name):
		return _window_tex[style_name]
	var mat: StandardMaterial3D = MapBuilder._mat_for_style(style_name)
	var tex: Texture2D = null
	if mat and mat.albedo_texture:
		var src: Image = mat.albedo_texture.get_image()
		if src:
			src = src.duplicate()
			if src.is_compressed():
				src.decompress()
			src.convert(Image.FORMAT_RGBA8)
			var w: int = src.get_width()
			var h: int = src.get_height()
			var em := Image.create(w, h, false, Image.FORMAT_RGB8)
			for y: int in range(h):
				var warm: float = lerpf(0.75, 1.0, float(y) / float(h))
				for x: int in range(w):
					var c: Color = src.get_pixel(x, y)
					if c.b > c.r + 0.1 and c.b > 0.3:
						em.set_pixel(x, y, Color(0.95 * warm, 0.72 * warm, 0.42 * warm))
					else:
						em.set_pixel(x, y, Color.BLACK)
			tex = ImageTexture.create_from_image(em)
	_window_tex[style_name] = tex
	return tex


func _set_window_lights(energy: float) -> void:
	for st: String in ["tower", "beverly", "mall", "shophouse"]:
		var mat: StandardMaterial3D = MapBuilder._mat_for_style(st)
		if mat == null:
			continue
		if energy <= 0.0:
			mat.emission_enabled = false
			continue
		var t: Texture2D = _window_emission(st)
		if t == null:
			continue
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_texture = t
		mat.emission_energy_multiplier = energy


# ---------------------------------------------------------------------------------------------------------------
# MÔI TRƯỜNG VICE + LUT 3D tách tông + pass vật liệu lì kiểu PS2
# ---------------------------------------------------------------------------------------------------------------
func _vice_lut(key: String) -> ImageTexture3D:
	if _lut_cache.has(key):
		return _lut_cache[key]
	var p: Dictionary = VICE[key]
	var n: int = 32
	var sh: Color = p["shadow"]
	var hi: Color = p["high"]
	var lift: float = float(p["lift"])
	var slices: Array[Image] = []
	for bz: int in range(n):
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for gy: int in range(n):
			for rx: int in range(n):
				var c := Color(rx / float(n - 1), gy / float(n - 1), bz / float(n - 1))
				var lum: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				var ws: float = pow(1.0 - lum, 2.0) * 0.32
				var wh: float = pow(lum, 2.0) * 0.22
				var o := Color(
					c.r + (sh.r - 0.5) * ws + (hi.r - 0.5) * wh,
					c.g + (sh.g - 0.5) * ws + (hi.g - 0.5) * wh,
					c.b + (sh.b - 0.5) * ws + (hi.b - 0.5) * wh)
				o = Color(o.r * (1.0 - lift) + lift, o.g * (1.0 - lift) + lift, o.b * (1.0 - lift) + lift)
				img.set_pixel(rx, gy, Color(clampf(o.r, 0.0, 1.0), clampf(o.g, 0.0, 1.0), clampf(o.b, 0.0, 1.0)))
		slices.append(img)
	var tex := ImageTexture3D.new()
	var err: int = tex.create(Image.FORMAT_RGB8, n, n, n, false, slices)
	if err != OK:
		push_error("LUT create failed %d" % err)
	_lut_cache[key] = tex
	return tex


func _apply_vice_env(key: String) -> void:
	var p: Dictionary = VICE[key]
	var e := Environment.new()
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = p["top"]
	skm.sky_horizon_color = p["horizon"]
	skm.ground_horizon_color = p["ground_h"]
	skm.ground_bottom_color = p["ground_b"]
	skm.sun_angle_max = 32.0
	skm.sun_curve = 0.14
	skm.use_debanding = true
	skm.sky_energy_multiplier = 1.0 if key != "night" else 0.7
	var sky := Sky.new()
	sky.sky_material = skm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = p["amb_col"]
	e.ambient_light_energy = float(p["amb"])
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# PS2: không GI/AO/SSR – ánh sáng phẳng, ấm, phụ thuộc màu môi trường
	e.sdfgi_enabled = false
	e.ssil_enabled = false
	e.ssao_enabled = false
	e.ssr_enabled = false
	e.volumetric_fog_enabled = false
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = p["fog"]
	e.fog_light_energy = 1.0
	e.fog_depth_begin = float(p["fog_begin"])
	e.fog_depth_end = float(p["fog_end"])
	e.fog_depth_curve = 1.4
	e.fog_sun_scatter = 0.35 if key == "sunset" else 0.1
	e.fog_sky_affect = float(p["sky_fog"])
	e.glow_enabled = true
	e.glow_intensity = float(p["glow"])
	e.glow_strength = 1.1
	e.glow_bloom = float(p["bloom"])
	e.glow_hdr_threshold = float(p["thr"])
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.6)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = float(p["exposure"])
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.02
	e.adjustment_contrast = float(p["contrast"])
	e.adjustment_saturation = float(p["sat"])
	e.adjustment_color_correction = _vice_lut(key)
	we.environment = e
	sun.rotation_degrees = Vector3(-float(p["elev"]), float(p["azim"]), 0.0)
	sun.light_color = p["sun"]
	sun.light_energy = float(p["energy"])
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.72 if key != "night" else 0.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 320.0
	sun.shadow_blur = 1.6


var _soft_emitters: Array[StandardMaterial3D] = []   # emission yếu chỉ để thấy ban đêm (vạch đường, biển)

func _set_soft_emitters(on: bool) -> void:
	for sm: StandardMaterial3D in _soft_emitters:
		sm.emission_enabled = on


func _vice_material(m: Material) -> void:
	if m == null or _done_mats.has(m):
		return
	_done_mats[m] = true
	if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled and (m as StandardMaterial3D).emission_energy_multiplier <= 0.5:
		_soft_emitters.append(m as StandardMaterial3D)
	if m is StandardMaterial3D:
		var s := m as StandardMaterial3D
		s.next_pass = null                                  # bỏ viền toon
		s.normal_enabled = false                            # PS2 không có normal map
		s.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT     # bỏ toon ramp
		var glossy: bool = s.metallic > 0.35 or s.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or s.clearcoat_enabled
		if not glossy:
			s.roughness = maxf(s.roughness, 0.9)
			s.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	elif m is ShaderMaterial and (m as ShaderMaterial).next_pass:
		(m as ShaderMaterial).next_pass = null


func _vice_materials_pass(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		_vice_material(gi.material_override)
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			if mi.mesh:
				for si: int in range(mi.mesh.get_surface_count()):
					_vice_material(mi.get_surface_override_material(si))
					_vice_material(mi.mesh.surface_get_material(si))
		elif gi is MultiMeshInstance3D:
			var mmi := gi as MultiMeshInstance3D
			if mmi.multimesh and mmi.multimesh.mesh:
				for si: int in range(mmi.multimesh.mesh.get_surface_count()):
					_vice_material(mmi.multimesh.mesh.surface_get_material(si))
	for ch: Node in node.get_children():
		_vice_materials_pass(ch)


# ---------------------------------------------------------------------------------------------------------------
# CẢNH CHỤP
# ---------------------------------------------------------------------------------------------------------------
func _define_shots() -> void:
	var sp: Transform3D = md.spawn_transform()
	var fwd: Vector3 = -sp.basis.z
	var be6v: Variant = md.landmark("be6_center")
	var be6 := Vector3(float(be6v[0]), 0.0, float(be6v[1]))
	# đoạn đường nội khu gần sảnh BE6 nhất -> đặt camera trên đường, nhìn ngược về phía sảnh + dãy tháp
	var sp2 := Vector2(sp.origin.x, sp.origin.z)
	var best_d: float = 1.0e9
	var best_p := sp2
	var best_dir := Vector2(1.0, 0.0)
	var best_half: float = 3.0
	for r: Dictionary in md.roads("vinhomes"):
		if int(r.get("lanes", 0)) == 0:
			continue
		var pts: PackedVector2Array = MapData.poly(r["points"])
		for i: int in range(pts.size() - 1):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(sp2, pts[i], pts[i + 1])
			var dd: float = q.distance_to(sp2)
			if dd < best_d and pts[i].distance_to(pts[i + 1]) > 20.0:
				best_d = dd
				best_p = q
				best_dir = (pts[i + 1] - pts[i]).normalized()
				best_half = float(r.get("width", 6.0)) * 0.5
	var nrm2 := Vector2(-best_dir.y, best_dir.x)
	if nrm2.dot(sp2 - best_p) < 0.0:
		nrm2 = -nrm2                      # nrm2 hướng về phía sảnh
	var cam2: Vector2 = best_p + best_dir * 58.0 - nrm2 * (best_half - 1.2)
	var look2: Vector2 = best_p - best_dir * 12.0 + nrm2 * 18.0
	var street_cam := Vector3(cam2.x, 1.7, cam2.y)
	var street_look := Vector3(look2.x, 15.0, look2.y)
	print("  street shot: road %.0f m from spawn" % best_d)
	var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
	var gate: Vector3 = FPTUCampusBuilder.main_gate_local()
	var gate_cam: Vector3 = xf * Vector3(gate.x - 30.0, 1.7, FPTUCampusBuilder.ROAD_CENTER_V - 3.0)
	var gate_look: Vector3 = xf * Vector3(gate.x + 8.0, 5.0, 10.0)
	shots = [
		{"name": "street_be6_sunset", "pos": street_cam, "look": street_look, "vice": "sunset", "classic": "dawn", "area": "Vinhomes Grand Park", "clock": "18:12", "fov": 72.0},
		{"name": "air_beverly_sunset", "pos": be6 + Vector3(-190.0, 110.0, 170.0), "look": be6 + Vector3(40.0, 10.0, 30.0), "vice": "sunset", "classic": "dawn", "area": "The Beverly", "clock": "18:20", "fov": 55.0},
		{"name": "gate_d1_day", "pos": gate_cam, "look": gate_look, "vice": "day", "classic": "morning", "area": "Đại học FPT", "clock": "07:24", "fov": 62.0},
		{"name": "street_be6_night", "pos": street_cam, "look": street_look, "vice": "night", "classic": "night", "area": "Vinhomes Grand Park", "clock": "23:41", "fov": 72.0},
	]


func _begin_shot() -> void:
	var s: Dictionary = shots[shot_i]
	cam.fov = float(s["fov"])
	cam.look_at_from_position(s["pos"], s["look"], Vector3.UP)
	if style == "classic":
		gfx.upgrade_scene_visuals(world, String(s["classic"]))
		hud.visible = false
		neon_root.visible = false
	else:
		_apply_vice_env(String(s["vice"]))
		hud.visible = true
		hud_area.text = String(s["area"])
		hud_clock.text = String(s["clock"])
		radar.center = Vector2(cam.global_position.x, cam.global_position.z)
		radar.yaw = cam.global_rotation.y
		var xf: Transform3D = FPTUCampusBuilder.real_plot_transform()
		var g: Vector3 = xf * FPTUCampusBuilder.main_gate_local()
		radar.target = Vector2(g.x, g.z)
		radar.queue_redraw()
		neon_root.visible = String(s["vice"]) == "night"
		_set_window_lights(float(VICE[String(s["vice"])]["windows"]))
		_set_soft_emitters(String(s["vice"]) == "night")
	wait = SETTLE_FRAMES


func _process(_delta: float) -> bool:
	frames += 1
	if frames > 4000:
		push_error("lookdev watchdog")
		quit(2)
		return true
	if wait > 0:
		wait -= 1
		return false
	var s: Dictionary = shots[shot_i]
	var img: Image = root.get_texture().get_image()
	var fname: String = "vice_%s_%s.png" % [s["name"], style]
	var err: int = img.save_png(out_dir.path_join(fname))
	print("  saved %s err=%d fps=%.0f" % [fname, err, Engine.get_frames_per_second()])
	shot_i += 1
	if shot_i >= shots.size():
		if style == "classic":
			style = "vice"
			shot_i = 0
			CharacterBuilder.toon = false
			for p: Node3D in vice_only:
				p.visible = true
			_vice_materials_pass(world)
			print("  vice material pass: %d materials" % _done_mats.size())
		else:
			print("VICE LOOKDEV DONE")
			quit(0)
			return true
	_begin_shot()
	return false
