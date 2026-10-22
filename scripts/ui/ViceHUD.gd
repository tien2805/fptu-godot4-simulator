# File: res://scripts/ui/ViceHUD.gd
# HUD kiểu thập niên 80 dùng lại được (Task VC-4, docs/superpowers/plans/2026-10-22-vice-city-art-direction.md; giao
# diện từ tests/preview_vice_lookdev.gd: _italic_font / _hud_label / StarRow / Radar). Chỉ hiện ở phong cách "vice"
# (GameFX.art_style); đổi phong cách lúc chạy thì ẩn / hiện ngay (tín hiệu art_style_changed).
#   - Cột góc trên (mặc định phải): giờ (set_clock), ví Cóc Vàng "00001250 CV" (set_money: đếm lên trong 0,6 s; tự nối
#     StageManager.wallet_changed), hàng 5 sao + nhãn (set_stars: 0..5, ẩn ở 0, nhấp nháy 2 s khi tăng).
#   - Radar góc dưới trái (radar: ViceRadar) vẽ từ MapData; track(pos, yaw) dời tâm radar theo người chơi / xe.
#   - Tên khu vực góc dưới phải (show_area): chữ nghiêng hồng #FF7AC8 viền #2A0E3A, hiện dần 0,3 s, giữ 2,5 s, mờ dần
#     0,6 s, bỏ qua tên đã hiện trong 20 s; show_vehicle(): cùng kiểu, nhỏ hơn, ngay trên tên khu vực.
#   - Tên khu vực tự tính từ vị trí track() mỗi 0,5 s (area_at): campus FPT (landmark campus_plot) -> "Đại học FPT", toà
#     nhà mang tên hư cấu của tools/osm_to_mapdata.py DISPLAY_NAME (Vincom -> "VinMall Grand Park"), khu "Beverly" ->
#     "The Beverly", tên đường thật gần nhất trong 30 m, khu "Vinhomes Grand Park", trong bán kính campus của scope ->
#     "Khu Công nghệ cao". Không bao giờ dùng tên thương hiệu thật mà pipeline bản đồ đã hư cấu hoá.
# Cấu hình (đặt TRƯỚC add_child): md, show_radar / show_money / show_clock, top_preset (PRESET_TOP_RIGHT hoặc
# PRESET_TOP_LEFT), top_margin, area_margin (phải, đáy), radar_margin (trái, đáy), radar_size. Chỉ anchors + containers.
# Lớp vẽ 0: nằm dưới HUD của màn (layer 1) nên thẻ kết quả / bản đồ / menu luôn che lên trên.
# Autoload chỉ qua get_node_or_null("/root/GameFX" | "/root/StageManager"); hàm tĩnh qua preload (test --script).
class_name ViceHUD
extends CanvasLayer

const GameFXScript: Script = preload("res://scripts/GameFX.gd")

const AREA_COLOR := Color("#FF7AC8")
const AREA_OUTLINE := Color("#2A0E3A")
const AREA_FADE_IN: float = 0.3
const AREA_HOLD: float = 2.5
const AREA_FADE_OUT: float = 0.6
const AREA_REPEAT_S: float = 20.0
const AREA_CHECK_S: float = 0.5
const AREA_SIZE: int = 40
const VEHICLE_SIZE: int = 26
const AREA_MAX_W: float = 620.0
const AREA_MIN_SIZE: int = 20
const MONEY_COUNT_S: float = 0.6
const MONEY_MAX: int = 99999999
const STAR_CELL: float = 30.0
const ROAD_NAME_M: float = 30.0
const PLACE_GROW_M: float = 12.0
const ROAD_CELL: float = 64.0
const NAME_FPT: String = "Đại học FPT"
const NAME_BEVERLY: String = "The Beverly"
const NAME_VGP: String = "Vinhomes Grand Park"
const NAME_SHTP: String = "Khu Công nghệ cao"

# ----- cấu hình -----
var md: MapData
var show_radar: bool = true
var show_money: bool = true
var show_clock: bool = true
var top_preset: int = Control.PRESET_TOP_RIGHT
var top_margin: Vector2 = Vector2(28.0, 24.0)
var area_margin: Vector2 = Vector2(34.0, 34.0)
var radar_margin: Vector2 = Vector2(28.0, 28.0)
var radar_size: float = 200.0

# ----- widget -----
var radar: ViceRadar
var clock_label: Label
var money_label: Label
var stars: ViceStars
var stars_label: Label
var area_label: Label
var vehicle_label: Label

var area_shows: int = 0
var current_area: String = ""
var money_shown: int = 0
var money_target: int = 0
## Ẩn tạm theo yêu cầu của cảnh (vd. bản đồ [M] đang mở) – độc lập với phong cách.
var suppressed: bool = false:
	set(v):
		suppressed = v
		_refresh_visible()

var _style_vice: bool = true
var _money_tween: Tween
var _area_tween: Tween
var _vehicle_tween: Tween
var _area_seen: Dictionary = {}
var _area_t: float = 0.0
var _track_pos: Vector2 = Vector2.ZERO
var _tracking: bool = false
var _area_pending: bool = false

static var _area_indexes: Dictionary = {}


## true khi phong cách hiện tại là vice (/root/GameFX.art_style; không có autoload -> mặc định vice).
static func style_active() -> bool:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml and ml.root:
		var g: Node = ml.root.get_node_or_null("GameFX")
		if g:
			return String(g.get("art_style")) == "vice"
	return true


func _ready() -> void:
	layer = 0
	set_meta("ui_keep", true)     # GameFX.apply_vice_theme không đụng vào kiểu riêng của HUD này
	_build()
	var sm: Node = get_node_or_null("/root/StageManager")
	if show_money and sm and sm.has_signal("wallet_changed"):
		set_money(int(sm.get("wallet")), false)
		sm.connect("wallet_changed", _on_wallet_changed)
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_signal("art_style_changed"):
		fx.connect("art_style_changed", _on_art_style_changed)
	var parent_layer: CanvasLayer = get_parent() as CanvasLayer
	if parent_layer:
		parent_layer.visibility_changed.connect(_refresh_visible)
	_style_vice = style_active()
	_refresh_visible()


func _italic(embolden: float, slant: float) -> FontVariation:
	return GameFXScript.vice_font(embolden, slant)


func _hud_label(text: String, font_size: int, col: Color, outline: Color, outline_size: int, font: Font, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	# bóng đổ 2 px cho chữ nhỏ (< 20 px): dấu chồng tiếng Việt (Ể, Ẩ, Ỗ) không bị bóng che ở cỡ 15 px
	var shadow: int = 3 if font_size >= 20 else 2
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55 if font_size >= 20 else 0.45))
	l.add_theme_constant_override("shadow_offset_x", shadow)
	l.add_theme_constant_override("shadow_offset_y", shadow)
	l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _corner(node_name: String, preset: int, margins: Dictionary) -> MarginContainer:
	var m := MarginContainer.new()
	m.name = node_name
	m.set_anchors_and_offsets_preset(preset as Control.LayoutPreset)
	match preset:
		Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT:
			m.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_:
			m.grow_horizontal = Control.GROW_DIRECTION_END
	match preset:
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT:
			m.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_:
			m.grow_vertical = Control.GROW_DIRECTION_END
	for side: String in margins.keys():
		m.add_theme_constant_override(side, int(margins[side]))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	return m


func _build() -> void:
	var right: bool = top_preset == Control.PRESET_TOP_RIGHT
	var align: int = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var top: MarginContainer = _corner("TopColumn", top_preset, {("margin_right" if right else "margin_left"): top_margin.x, "margin_top": top_margin.y})
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", -4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(col)
	var font_i: FontVariation = _italic(0.6, 0.22)
	clock_label = _hud_label("", 40, Color("#f4f1ff"), Color("#1b0f33"), 8, font_i, align)
	clock_label.name = "Clock"
	clock_label.visible = false
	col.add_child(clock_label)
	money_label = _hud_label("%08d CV" % 0, 34, Color("#9bea7a"), Color("#0b1a06"), 8, font_i, align)
	money_label.name = "Money"
	money_label.visible = show_money
	col.add_child(money_label)
	stars = ViceStars.new()
	stars.name = "Stars"
	stars.align_right = right
	stars.custom_minimum_size = Vector2(5.0 * STAR_CELL, STAR_CELL)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	stars.visible = false
	col.add_child(stars)
	stars_label = _hud_label("", 15, Color("#ffb3e6"), Color("#1b0f33"), 4, _italic(0.3, 0.15), align)
	stars_label.name = "StarsLabel"
	stars_label.visible = false
	col.add_child(stars_label)

	if show_radar:
		var bl: MarginContainer = _corner("RadarCorner", Control.PRESET_BOTTOM_LEFT, {"margin_left": radar_margin.x, "margin_bottom": radar_margin.y})
		radar = ViceRadar.new()
		radar.name = "Radar"
		radar.md = md
		radar.custom_minimum_size = Vector2(radar_size, radar_size)
		bl.add_child(radar)

	var br: MarginContainer = _corner("AreaCorner", Control.PRESET_BOTTOM_RIGHT, {"margin_right": area_margin.x, "margin_bottom": area_margin.y})
	var vb := VBoxContainer.new()
	vb.name = "AreaColumn"
	vb.alignment = BoxContainer.ALIGNMENT_END
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br.add_child(vb)
	vehicle_label = _hud_label("", VEHICLE_SIZE, AREA_COLOR, AREA_OUTLINE, 8, _italic(0.8, 0.26), HORIZONTAL_ALIGNMENT_RIGHT)
	vehicle_label.name = "Vehicle"
	vehicle_label.modulate.a = 0.0
	vb.add_child(vehicle_label)
	area_label = _hud_label("", AREA_SIZE, AREA_COLOR, AREA_OUTLINE, 10, _italic(0.9, 0.28), HORIZONTAL_ALIGNMENT_RIGHT)
	area_label.name = "Area"
	area_label.modulate.a = 0.0
	vb.add_child(area_label)


# ---------------------------------------------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------------------------------------------
func set_clock(text: String) -> void:
	clock_label.text = text
	clock_label.visible = show_clock and text != ""


## Ví "00001250 CV" (8 chữ số); animate: đếm từ số đang hiện tới `amount` trong MONEY_COUNT_S giây.
func set_money(amount: int, animate: bool = true) -> void:
	money_target = clampi(amount, 0, MONEY_MAX)
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()
	if not animate or not is_inside_tree() or money_target == money_shown:
		_set_money_shown(float(money_target))
		return
	_money_tween = create_tween()
	_money_tween.tween_method(_set_money_shown, float(money_shown), float(money_target), MONEY_COUNT_S)


func _set_money_shown(v: float) -> void:
	money_shown = clampi(int(round(v)), 0, MONEY_MAX)
	money_label.text = "%08d CV" % money_shown


func _on_wallet_changed(total: int, _delta: int) -> void:
	set_money(total)


## 0..5 sao; ẩn hàng sao + nhãn ở 0; số sao tăng -> nhấp nháy 2 s. `label` (vd. "GIẢNG VIÊN ĐỂ Ý") giữ lại cho lần sau.
func set_stars(n: int, label: String = "") -> void:
	var v: int = clampi(n, 0, 5)
	stars.set_filled(v)
	if label != "":
		stars_label.text = label
	stars.visible = v > 0
	stars_label.visible = v > 0 and stars_label.text != ""


## Tên khu vực góc dưới phải; trả false (không hiện) khi tên rỗng hoặc đã hiện trong AREA_REPEAT_S giây.
func show_area(area_name: String) -> bool:
	var n: String = area_name.strip_edges()
	if n == "":
		return false
	var now: float = Time.get_ticks_msec() * 0.001
	if _area_seen.has(n) and now - float(_area_seen[n]) < AREA_REPEAT_S:
		return false
	_area_seen[n] = now
	area_label.text = n
	_fit(area_label, AREA_SIZE)
	_area_tween = _fade(area_label, _area_tween)
	area_shows += 1
	return true


## Tên phương tiện ("Xe máy") ngay trên tên khu vực, cùng kiểu chữ nhỏ hơn; hiện mỗi lần gọi.
func show_vehicle(vehicle_name: String) -> void:
	if vehicle_name.strip_edges() == "":
		return
	vehicle_label.text = vehicle_name
	_fit(vehicle_label, VEHICLE_SIZE)
	_vehicle_tween = _fade(vehicle_label, _vehicle_tween)


## Xuống xe: tên xe tắt ngay (không đợi hết 3,4 s của lần hiện trước).
func hide_vehicle() -> void:
	if _vehicle_tween and _vehicle_tween.is_valid():
		_vehicle_tween.kill()
	vehicle_label.modulate.a = 0.0


## Quên các tên khu vực đã hiện (sau khi dịch chuyển / quay về từ một màn): lần track() kế tiếp (đã có vị trí mới)
## tính và hiện tên ngay, không đợi nhịp AREA_CHECK_S và không dùng vị trí cũ trước khi dịch chuyển.
func reset_area() -> void:
	_area_seen.clear()
	current_area = ""
	_area_pending = true


## Tên dài (vd. "Cầu cạn Đường vành đai 3 Thành phố Hồ Chí Minh") thu cỡ chữ cho vừa AREA_MAX_W px.
func _fit(l: Label, base: int) -> void:
	var f: Font = l.get_theme_font("font")
	var w: float = f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x if f else 0.0
	var s: int = base
	if w > AREA_MAX_W:
		s = maxi(AREA_MIN_SIZE, int(floor(float(base) * AREA_MAX_W / w)))
	l.add_theme_font_size_override("font_size", s)


func _fade(l: Label, old: Tween) -> Tween:
	if old and old.is_valid():
		old.kill()
	l.modulate.a = 0.0
	if not is_inside_tree():
		l.modulate.a = 1.0
		return null
	var tw: Tween = create_tween()
	tw.tween_property(l, "modulate:a", 1.0, AREA_FADE_IN)
	tw.tween_interval(AREA_HOLD)
	tw.tween_property(l, "modulate:a", 0.0, AREA_FADE_OUT)
	return tw


## Vị trí bản đồ (x, z) + yaw camera của người chơi / xe: dời tâm radar; tên khu vực kiểm mỗi AREA_CHECK_S giây.
func track(pos: Vector2, yaw: float) -> void:
	_track_pos = pos
	_tracking = true
	if radar:
		radar.center = pos
		radar.yaw = yaw
	if _area_pending:
		_area_pending = false
		_area_t = AREA_CHECK_S
		update_area_now()


func update_area_now() -> void:
	var a: String = area_at(_track_pos)
	if a != "" and a != current_area:
		current_area = a
		show_area(a)


func _process(delta: float) -> void:
	if not visible or not _tracking or md == null:
		return
	_area_t -= delta
	if _area_t <= 0.0:
		_area_t = AREA_CHECK_S
		update_area_now()


func _on_art_style_changed(style: String) -> void:
	_style_vice = style == "vice"
	_refresh_visible()


func _refresh_visible() -> void:
	var parent_layer: CanvasLayer = get_parent() as CanvasLayer
	var parent_ok: bool = parent_layer == null or parent_layer.visible
	visible = _style_vice and not suppressed and parent_ok


# ---------------------------------------------------------------------------------------------------------------
# TÊN KHU VỰC (chỉ mục tĩnh theo MapData)
# ---------------------------------------------------------------------------------------------------------------
func area_at(p: Vector2) -> String:
	if md == null:
		return ""
	var ix: Dictionary = _area_index(md)
	var fpt: PackedVector2Array = ix["fpt"]
	if fpt.size() >= 3 and Geometry2D.is_point_in_polygon(p, fpt):
		return NAME_FPT
	for place: Array in ix["places"]:
		var poly: PackedVector2Array = place[0]
		if Geometry2D.is_point_in_polygon(p, poly) or _dist_to_poly(p, poly) <= PLACE_GROW_M:
			return String(place[1])
	var bev: PackedVector2Array = ix["beverly"]
	if bev.size() >= 3 and Geometry2D.is_point_in_polygon(p, bev):
		return NAME_BEVERLY
	var road: String = _nearest_road_name(ix, p)
	if road != "":
		return road
	var vgp: PackedVector2Array = ix["vgp"]
	if vgp.size() >= 3 and Geometry2D.is_point_in_polygon(p, vgp):
		return NAME_VGP
	if p.distance_to(ix["shtp_c"]) <= float(ix["shtp_r"]):
		return NAME_SHTP
	return ""


static func _dist_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in range(poly.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[i + 1])))
	return best


static func _nearest_road_name(ix: Dictionary, p: Vector2) -> String:
	var a: PackedVector2Array = ix["ra"]
	var b: PackedVector2Array = ix["rb"]
	var names: PackedStringArray = ix["rn"]
	var grid: Dictionary = ix["grid"]
	var cx: int = floori(p.x / ROAD_CELL)
	var cz: int = floori(p.y / ROAD_CELL)
	var best_d: float = ROAD_NAME_M
	var best: String = ""
	for gx: int in range(cx - 1, cx + 2):
		for gz: int in range(cz - 1, cz + 2):
			var cell: Variant = grid.get(Vector2i(gx, gz))
			if cell == null:
				continue
			for idx: int in (cell as Array):
				var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a[idx], b[idx]))
				if d < best_d:
					best_d = d
					best = names[idx]
	return best


static func _area_index(m: MapData) -> Dictionary:
	var id: int = m.get_instance_id()
	if _area_indexes.has(id):
		return _area_indexes[id]
	var fpt := PackedVector2Array()
	var lm: Variant = m.landmark("campus_plot")
	if lm is Array:
		fpt = MapData.poly(lm)
	var bev := PackedVector2Array()
	var vgp := PackedVector2Array()
	for a: Dictionary in m.areas():
		var n: String = String(a.get("name", ""))
		if n == "Beverly" and bev.is_empty():
			bev = MapData.poly(a.get("outer", []))
		elif n == NAME_VGP and vgp.is_empty():
			vgp = MapData.poly(a.get("outer", []))
	# toà nhà mà pipeline bản đồ đã đổi sang tên hư cấu (display khác name, vd. Vincom Mega Mall -> VinMall Grand Park)
	var places: Array = []
	for b: Dictionary in m.buildings():
		var nm: String = String(b.get("name", ""))
		var disp: String = String(b.get("display", nm))
		if nm != "" and disp != "" and disp != nm:
			places.append([MapData.poly(b.get("outer", [])), disp])
	var ra := PackedVector2Array()
	var rb := PackedVector2Array()
	var rn := PackedStringArray()
	var grid: Dictionary = {}
	for r: Dictionary in m.roads():
		var nm2: String = String(r.get("name", "")).strip_edges()
		if nm2 == "":
			continue
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		for i: int in range(pts.size() - 1):
			var p: Vector2 = pts[i]
			var q: Vector2 = pts[i + 1]
			var idx: int = ra.size()
			ra.append(p)
			rb.append(q)
			rn.append(nm2)
			var lo := Vector2i(floori(minf(p.x, q.x) / ROAD_CELL), floori(minf(p.y, q.y) / ROAD_CELL))
			var hi := Vector2i(floori(maxf(p.x, q.x) / ROAD_CELL), floori(maxf(p.y, q.y) / ROAD_CELL))
			for gx: int in range(lo.x, hi.x + 1):
				for gz: int in range(lo.y, hi.y + 1):
					var key := Vector2i(gx, gz)
					if not grid.has(key):
						grid[key] = []
					(grid[key] as Array).append(idx)
	var scope: Variant = m.data.get("scope", {})
	var shtp_r: float = float((scope as Dictionary).get("campus_radius", 700.0)) if scope is Dictionary else 700.0
	var out: Dictionary = {"fpt": fpt, "beverly": bev, "vgp": vgp, "places": places, "ra": ra, "rb": rb, "rn": rn, "grid": grid, "shtp_c": Vector2.ZERO, "shtp_r": shtp_r}
	_area_indexes[id] = out
	return out
