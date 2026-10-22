# File: res://tests/test_vice_hud.gd
# Test headless Task VC-4 (docs/superpowers/plans/2026-10-22-vice-city-art-direction.md): giao diện vice của GameFX +
# ViceHUD / ViceRadar / ViceStars.
#   1. GameFX theo phong cách: vice = nền tím Color(0.07, 0.04, 0.14, 0.88), viền hồng #FF5FB0 khi không truyền màu, giữ
#      cam FPT khi truyền FPT_ORANGE, màu ngữ nghĩa thành bản pastel cùng sắc, bo góc 4, chữ có viền 6 #1B0F33 + bóng,
#      tiêu đề lớn dùng vice_font() (nghiêng giả lập); classic = đúng như cũ (cam, nền xanh đen, bo 8, không viền chữ);
#      restyle_tree() đổi lại panel / nhãn đã dựng khi đổi phong cách.
#   2. ViceHUD ở 1280x720 và 1920x1080: mọi Control nằm trong viewport khi mọi phần đều hiện (giờ, tiền, 5 sao + nhãn,
#      tên khu vực dài nhất, tên xe); set_money(1250) -> "00001250 CV" sau khi đếm xong; show_area lặp trong 20 s chỉ hiện
#      một lần; set_stars kẹp 0..5, ẩn ở 0, nhấp nháy khi tăng; ví StageManager cập nhật tiền; đổi sang classic thì ẩn.
#   3. ViceRadar: bản đồ 600+ con đường, _draw < 2 ms (đo bằng Time.get_ticks_usec trong _draw), hướng nhìn ở phía trên.
#   4. Tên khu vực: BE6 -> "The Beverly", Vincom -> "VinMall Grand Park" (tên hư cấu của tools/osm_to_mapdata.py), đường
#      Nguyễn Văn Tăng, "Đại học FPT", "Vinhomes Grand Park", "Khu Công nghệ cao"; không bao giờ trả tên thương hiệu thật.
#   5. Thẻ kết quả vice (StageManager): tiêu đề "QUA MÔN!" / "TRƯỢT MÔN" / "BỊ BẮT", dải gradient, "+N Cóc Vàng".
# Chạy:  godot --headless --path . --script tests/test_vice_hud.gd
extends SceneTree

const RADAR_BUDGET_USEC: int = 2000
const BRAND_NAMES: Array[String] = ["Vincom Mega Mall", "Highlands Coffee", "Gong Cha", "Pharmacity", "Decathlon", "7-Eleven", "VinMart"]
const LONG_AREA: String = "Cầu cạn Đường vành đai 3 Thành phố Hồ Chí Minh"

var fx: Node
var sm: Node
var G: Script
var md: MapData
var hud: ViceHUD
var frames: int = 0
var phase: int = 0
var t_mark: int = 0
var events: Array = []


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	fx = root.get_node("GameFX")
	sm = root.get_node("StageManager")
	G = load("res://scripts/GameFX.gd")
	md = MapData.load_default()
	root.size = Vector2i(1280, 720)
	print("--- TEST VICE HUD ---")


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		print("❌ FAILED: ", msg)
		quit(1)
	return ok


static func _near(a: Color, b: Color, tol: float = 0.02) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol and absf(a.a - b.a) < tol


func _process(_d: float) -> bool:
	frames += 1
	if frames > 4000:
		print("❌ FAILED: watchdog")
		quit(2)
		return true
	match phase:
		0:
			if frames >= 3:
				if not _theme_checks():
					return true
				_build_hud()
				phase = 1
				t_mark = Time.get_ticks_msec()
		1:
			# chờ tween đếm tiền 0,6 s + tên khu vực hiện xong
			if Time.get_ticks_msec() - t_mark >= 900:
				if not _layout_checks("1280x720"):
					return true
				root.size = Vector2i(1920, 1080)
				phase = 2
				t_mark = frames
		2:
			if frames - t_mark >= 4:
				if not _layout_checks("1920x1080"):
					return true
				root.size = Vector2i(1280, 720)
				if not _behaviour_checks():
					return true
				if not _radar_checks_setup():
					return true
				phase = 3
				t_mark = frames
		3:
			# một cấu hình radar mỗi frame: _draw chạy trì hoãn ở cuối frame (queue_redraw)
			if _radar_i >= 0:
				if not _check(hud.radar.draws > _radar_d0, "radar _draw ran for config %d" % _radar_i):
					return true
				_radar_worst = maxi(_radar_worst, hud.radar.last_draw_usec)
				_radar_segs = maxi(_radar_segs, hud.radar.drawn_segments)
			_radar_i += 1
			if _radar_i < _radar_cfgs.size():
				hud.radar.center = _radar_cfgs[_radar_i][0]
				hud.radar.yaw = float(_radar_cfgs[_radar_i][1])
				hud.radar.refresh_now()
				_radar_d0 = hud.radar.draws
				hud.radar.queue_redraw()
			else:
				if not _radar_checks():
					return true
				if not _area_checks():
					return true
				# ví: earn(30) -> tiền đếm lên 30
				sm.set("wallet", 0)
				hud.set_money(0, false)
				sm.call("earn", 30, "test")
				phase = 4
				t_mark = Time.get_ticks_msec()
		4:
			if Time.get_ticks_msec() - t_mark >= 900:
				var txt: String = hud.money_label.text
				if not _check(txt.ends_with("00000030 CV"), "wallet_changed drives the money counter (got '%s')" % txt):
					return true
				if not _style_split_checks():
					return true
				if not _result_card_checks():
					return true
				print("✅ SUCCESS: VICE HUD OK (theme vice/classic, ViceHUD bounds at 2 sizes, money counter, area names, stars, radar < 2 ms, result card)")
				quit(0)
				return true
	return false


# ---------------------------------------------------------------------------------------------------------------
func _theme_checks() -> bool:
	fx.call("set_art_style", "vice", false)
	var sb: StyleBoxFlat = G.make_panel_style()
	if not _check(_near(sb.border_color, Color("#FF5FB0")), "vice: default panel border is pink #FF5FB0 (got %s)" % str(sb.border_color)):
		return false
	if not _check(_near(sb.bg_color, Color(0.07, 0.04, 0.14, 0.88)), "vice: panel bg Color(0.07, 0.04, 0.14, 0.88) (got %s)" % str(sb.bg_color)):
		return false
	if not _check(sb.corner_radius_top_left == 4 and sb.corner_radius_bottom_right == 4, "vice: corner radius 4"):
		return false
	var sb_fpt: StyleBoxFlat = G.make_panel_style(G.FPT_ORANGE, Color(0.05, 0.07, 0.12, 0.97), 12)
	if not _check(_near(sb_fpt.border_color, G.FPT_ORANGE), "vice: an explicit FPT orange border stays orange"):
		return false
	var sb_green: StyleBoxFlat = G.make_panel_style(Color("#2ECC71"))
	var gc: Color = sb_green.border_color
	if not _check(not _near(gc, Color("#2ECC71")) and gc.g > gc.r and gc.g > gc.b, "vice: an explicit green border becomes a pastel green (got %s)" % str(gc)):
		return false
	var lbl: Label = G.make_label("Giảng viên để ý", 16)
	if not _check(lbl.get_theme_constant("outline_size") == 6 and _near(lbl.get_theme_color("font_outline_color"), Color("#1B0F33")), "vice: labels get outline 6 #1B0F33"):
		return false
	if not _check(lbl.has_theme_constant_override("shadow_offset_x") and lbl.get_theme_constant("shadow_offset_y") > 0, "vice: labels get a drop shadow"):
		return false
	var head: Label = G.make_label("QUA MÔN!", 30)
	if not _check(head.get_theme_font("font") is FontVariation, "vice: heading labels (>= 24 px) use vice_font()"):
		return false
	var vf: FontVariation = G.vice_font()
	if not _check(absf(vf.variation_transform.x.y - 0.22) < 0.001 and absf(vf.variation_embolden - 0.6) < 0.001, "vice_font(): slant 0.22, embolden 0.6"):
		return false
	# chữ nghiêng giả lập làm mất emoji màu (biến đổi glyph): vice_font() có font emoji hệ thống KHÔNG nghiêng làm fallback
	var has_emoji_fb: bool = false
	for fb: Font in vf.fallbacks:
		if fb is SystemFont and (fb as SystemFont).font_names.has("Segoe UI Emoji"):
			has_emoji_fb = true
	if not _check(has_emoji_fb, "vice_font() keeps colour emoji upright through a SystemFont emoji fallback"):
		return false
	if not _check(_near(G.ui_accent(), Color("#FF5FB0")), "vice: ui_accent() is pink"):
		return false
	var bar: ProgressBar = G.make_bar(50.0, Color("#2ECC71"), 12)
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if not _check(fill != null and not _near(fill.bg_color, Color("#2ECC71")), "vice: bar fill uses the pastel palette"):
		return false
	# panel dựng ở classic rồi restyle_tree sang vice
	fx.call("set_art_style", "classic", false)
	var sbc: StyleBoxFlat = G.make_panel_style()
	if not _check(_near(sbc.border_color, G.FPT_ORANGE) and _near(sbc.bg_color, Color(0.06, 0.08, 0.14, 0.92)) and sbc.corner_radius_top_left == 8, "classic: default panel is unchanged (orange, navy, radius 8)"):
		return false
	var sbc_green: StyleBoxFlat = G.make_panel_style(Color("#2ECC71"), Color(0.05, 0.1, 0.08, 0.98), 8)
	if not _check(_near(sbc_green.border_color, Color("#2ECC71")) and _near(sbc_green.bg_color, Color(0.05, 0.1, 0.08, 0.98)), "classic: explicit colours are unchanged"):
		return false
	var lc: Label = G.make_label("x", 16)
	if not _check(not lc.has_theme_constant_override("outline_size") and not lc.has_theme_font_override("font"), "classic: labels have no outline / font override"):
		return false
	if not _check(_near(G.ui_accent(), G.FPT_ORANGE), "classic: ui_accent() is FPT orange"):
		return false
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", G.make_panel_style())
	var hl: Label = G.make_label("Tạm dừng", 26)
	holder.add_child(hl)
	root.add_child(holder)
	fx.call("set_art_style", "vice", false)
	G.restyle_tree(holder)
	var rs: StyleBoxFlat = holder.get_theme_stylebox("panel") as StyleBoxFlat
	if not _check(_near(rs.border_color, Color("#FF5FB0")) and hl.get_theme_constant("outline_size") == 6, "restyle_tree(): classic panel + label switch to vice"):
		return false
	fx.call("set_art_style", "classic", false)
	G.restyle_tree(holder)
	rs = holder.get_theme_stylebox("panel") as StyleBoxFlat
	if not _check(_near(rs.border_color, G.FPT_ORANGE) and not hl.has_theme_constant_override("outline_size"), "restyle_tree(): back to classic restores orange + no outline"):
		return false
	holder.queue_free()
	for orphan: Node in [lbl, head, bar, lc]:
		orphan.free()   # nhãn / thanh chỉ để đọc kiểu, chưa từng vào cây
	fx.call("set_art_style", "vice", false)
	print("  theme vice/classic OK")
	return true


func _build_hud() -> void:
	hud = ViceHUD.new()
	hud.name = "ViceHUD"
	hud.md = md
	root.add_child(hud)
	hud.set_clock("07:30")
	hud.set_money(1250)
	hud.set_stars(5, "GIẢNG VIÊN ĐỂ Ý")
	hud.show_area(LONG_AREA)
	hud.show_vehicle("Xe máy")


func _walk(n: Node, vp: Rect2, tag: String, bad: Array[String]) -> int:
	var count: int = 0
	if n is Control:
		var c: Control = n
		if c.is_visible_in_tree() and c.size.x > 2.0 and c.size.y > 2.0:
			var r: Rect2 = c.get_global_rect()
			if r.position.x < vp.position.x - 1.0 or r.position.y < vp.position.y - 1.0 or r.end.x > vp.end.x + 1.0 or r.end.y > vp.end.y + 1.0:
				bad.append("%s %s rect=%s vp=%s" % [tag, c.get_path(), r, vp])
			count += 1
	for ch: Node in n.get_children():
		count += _walk(ch, vp, tag, bad)
	return count


func _layout_checks(tag: String) -> bool:
	var bad: Array[String] = []
	var vp: Rect2 = root.get_visible_rect()
	var n: int = _walk(hud, vp, tag, bad)
	for b: String in bad:
		print("  ✗ ", b)
	if not _check(bad.is_empty() and n >= 8, "ViceHUD controls inside the viewport at %s (%d checked, %d clipped)" % [tag, n, bad.size()]):
		return false
	if not _check(hud.money_label.text.ends_with("00001250 CV"), "set_money(1250) counts up to '00001250 CV' (got '%s')" % hud.money_label.text):
		return false
	for pair: Array in [[hud.radar, "radar"], [hud.stars, "stars"], [hud.area_label, "area"], [hud.vehicle_label, "vehicle"], [hud.money_label, "money"]]:
		var c: Control = pair[0]
		if not _check(c.is_visible_in_tree(), "%s is visible at %s" % [pair[1], tag]):
			return false
	# không chồng lấn: radar (trái dưới), cột trên phải, nhóm tên khu vực (phải dưới)
	var rr: Rect2 = hud.radar.get_global_rect()
	var ar: Rect2 = hud.area_label.get_global_rect()
	var mr: Rect2 = hud.money_label.get_global_rect()
	if not _check(not rr.intersects(ar) and not mr.intersects(ar) and not rr.intersects(mr), "radar / money / area name do not overlap at %s" % tag):
		return false
	print("  layout %s OK (%d controls)" % [tag, n])
	return true


func _behaviour_checks() -> bool:
	var shows0: int = hud.area_shows
	var a: bool = hud.show_area("Đường D1")
	var b: bool = hud.show_area("Đường D1")
	if not _check(a and not b and hud.area_shows == shows0 + 1, "show_area twice within 20 s shows once (first %s, second %s)" % [str(a), str(b)]):
		return false
	# reset_area() (sau khi dịch chuyển / nạp lại): quên các tên đã hiện -> tên hiện lại ngay
	hud.reset_area()
	if not _check(hud.current_area == "" and hud.show_area("Đường D1"), "reset_area() lets the same area name show again"):
		return false
	# hide_vehicle() (xuống xe): tên xe mờ đi, không còn hiện
	hud.show_vehicle("Xe máy")
	hud.hide_vehicle()
	if not _check(hud.vehicle_label.modulate.a <= 0.01 or hud.vehicle_label.text == "", "hide_vehicle() clears the vehicle name at once"):
		return false
	hud.set_stars(0)
	if not _check(not hud.stars.is_visible_in_tree() and not hud.stars_label.is_visible_in_tree(), "0 stars: the star row and its label are hidden"):
		return false
	hud.set_stars(2, "GIẢNG VIÊN ĐỂ Ý")
	if not _check(hud.stars.is_visible_in_tree() and hud.stars.filled == 2 and hud.stars.is_flashing(), "2 stars: visible, 2 filled, flashing after the increase"):
		return false
	if not _check(hud.stars_label.text == "GIẢNG VIÊN ĐỂ Ý", "star label text"):
		return false
	hud.set_stars(9)
	if not _check(hud.stars.filled == 5, "set_stars clamps to 5"):
		return false
	hud.set_stars(-3)
	if not _check(hud.stars.filled == 0, "set_stars clamps to 0"):
		return false
	print("  area repeat + stars OK")
	return true


var _radar_cfgs: Array = []    # [tâm, yaw] – một cấu hình mỗi frame
var _radar_i: int = -1
var _radar_d0: int = 0
var _radar_worst: int = 0
var _radar_segs: int = 0

func _radar_checks_setup() -> bool:
	if not _check(md.roads().size() >= 600, "map data has 600+ roads (got %d)" % md.roads().size()):
		return false
	var vc: Array = (md.data.get("scope", {}) as Dictionary).get("vinhomes_center", [3910.58, -409.06])
	var spots: Array = [Vector2(float(vc[0]), float(vc[1])), Vector2.ZERO, Vector2(2200.0, -1500.0), _route_at(3350.0)]
	for p: Vector2 in spots:
		for k: int in range(3):
			_radar_cfgs.append([p, 0.35 + 0.9 * k])
	hud.radar.route = md.route_points(40.0)
	hud.radar.blips = [{"pos": Vector2(16.1, 99.5), "color": Color("#F37021"), "shape": "square"}, {"pos": spots[0] + Vector2(30.0, 0.0), "color": Color("#3498DB"), "shape": "circle"}]
	return true


func _radar_checks() -> bool:
	var worst: int = _radar_worst
	var segs: int = _radar_segs
	print("  radar: worst _draw %d us over %d draws, up to %d road segments drawn, %d cached" % [worst, _radar_cfgs.size(), segs, hud.radar.cached_segments])
	if not _check(segs > 50, "radar draws real roads near Vinhomes (got %d segments)" % segs):
		return false
	if not _check(worst < RADAR_BUDGET_USEC, "radar _draw < %d us with %d roads (worst %d us)" % [RADAR_BUDGET_USEC, md.roads().size(), worst]):
		return false
	# hướng: yaw 0 = nhìn về bắc (-z); yaw PI/2 = nhìn về tây (-x): điểm phía trước hiện ở phía trên tâm radar
	var r: ViceRadar = hud.radar
	r.center = Vector2(100.0, 100.0)
	r.yaw = 0.0
	var c: Vector2 = r.size * 0.5
	var ahead: Vector2 = r.to_radar(Vector2(100.0, 50.0))
	if not _check(ahead.y < c.y - 10.0 and absf(ahead.x - c.x) < 1.0, "yaw 0: a point 50 m north is above the centre (got %s, centre %s)" % [str(ahead), str(c)]):
		return false
	r.yaw = PI * 0.5
	ahead = r.to_radar(Vector2(50.0, 100.0))
	if not _check(ahead.y < c.y - 10.0 and absf(ahead.x - c.x) < 1.0, "yaw PI/2 (facing west): a point 50 m west is above the centre (got %s)" % str(ahead)):
		return false
	var right: Vector2 = r.to_radar(Vector2(100.0, 50.0))
	if not _check(right.x > c.x + 10.0, "yaw PI/2: north is on the right (got %s)" % str(right)):
		return false
	return true


func _area_checks() -> bool:
	var sp: Transform3D = md.spawn_transform()
	var got: String = hud.area_at(Vector2(sp.origin.x, sp.origin.z))
	if not _check(got == "The Beverly", "BE6 spawn is in 'The Beverly' (got '%s')" % got):
		return false
	var mall_c := Vector2.ZERO
	for b: Dictionary in md.buildings("vinhomes"):
		if String(b.get("name", "")) == "Vincom Mega Mall":
			var poly: PackedVector2Array = MapData.poly(b["outer"])
			for q: Vector2 in poly:
				mall_c += q
			mall_c /= float(poly.size())
	got = hud.area_at(mall_c)
	if not _check(got == "VinMall Grand Park", "the Vincom building shows its fictional name 'VinMall Grand Park' (got '%s')" % got):
		return false
	got = hud.area_at(Vector2.ZERO)
	if not _check(got == "Đại học FPT", "campus centroid is 'Đại học FPT' (got '%s')" % got):
		return false
	got = hud.area_at(_route_at(3350.0))
	if not _check(got == "Nguyễn Văn Tăng", "route at 3 350 m is on 'Nguyễn Văn Tăng' (got '%s')" % got):
		return false
	# lưới điểm: phải có cả "Vinhomes Grand Park" lẫn "Khu Công nghệ cao"; không tên thương hiệu thật nào
	var seen: Dictionary = {}
	var b0: Rect2 = md.bounds("vinhomes").merge(md.bounds("campus"))
	var step: float = 60.0
	var x: float = b0.position.x
	while x < b0.end.x:
		var z: float = b0.position.y
		while z < b0.end.y:
			var n: String = hud.area_at(Vector2(x, z))
			seen[n] = int(seen.get(n, 0)) + 1
			z += step
		x += step
	for brand: String in BRAND_NAMES:
		if not _check(not seen.has(brand), "area names never use the real brand '%s'" % brand):
			return false
	if not _check(seen.has("Vinhomes Grand Park") and seen.has("Khu Công nghệ cao"), "area grid finds 'Vinhomes Grand Park' and 'Khu Công nghệ cao' (names: %d)" % seen.size()):
		return false
	# track(): tâm radar + tên khu vực theo vị trí
	hud.track(Vector2(sp.origin.x, sp.origin.z), 0.2)
	hud.update_area_now()
	if not _check(hud.current_area == "The Beverly" and hud.radar.center.is_equal_approx(Vector2(sp.origin.x, sp.origin.z)), "track() moves the radar and resolves the area (got '%s')" % hud.current_area):
		return false
	# sau dịch chuyển: reset_area() rồi track() ở chỗ mới -> tên khu vực mới ngay ở lần track() đó (không đợi nhịp 0,5 s,
	# không dùng vị trí cũ trước khi dịch chuyển)
	hud.reset_area()
	hud.track(Vector2.ZERO, 0.0)
	if not _check(hud.current_area == "Đại học FPT", "reset_area() + track() at the new spot resolves the new area at once (got '%s')" % hud.current_area):
		return false
	print("  area names OK (%d distinct on a %d m grid)" % [seen.size(), int(step)])
	return true


func _route_at(dist_m: float) -> Vector2:
	var pts: PackedVector2Array = md.route_points(0.0)
	var acc: float = 0.0
	for i: int in range(1, pts.size()):
		var seg: float = pts[i - 1].distance_to(pts[i])
		if acc + seg >= dist_m:
			return pts[i - 1].lerp(pts[i], (dist_m - acc) / maxf(seg, 0.001))
		acc += seg
	return pts[pts.size() - 1]


func _style_split_checks() -> bool:
	fx.call("set_art_style", "classic", false)
	if not _check(not hud.visible, "ViceHUD hides live when the art style becomes classic"):
		return false
	fx.call("set_art_style", "vice", false)
	if not _check(hud.visible, "ViceHUD shows again in vice"):
		return false
	print("  style split OK")
	return true


## Thẻ kết quả vice: cấu trúc HUD/ModalOverlay/Center/Card/Margin/VBox giống các màn 2..Extra.
func _result_card_checks() -> bool:
	var stage := Node.new()
	stage.name = "FakeStage"
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	stage.add_child(layer)
	var ov := ColorRect.new()
	ov.name = "ModalOverlay"
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ov)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	center.add_child(card)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	card.add_child(margin)
	var vb := VBoxContainer.new()
	vb.name = "VBox"
	margin.add_child(vb)
	var title := Label.new()
	title.name = "TitleLabel"
	vb.add_child(title)
	root.add_child(stage)
	sm.call("report_stage_result", 3, {"result": "win", "score": 1200, "rank": "S", "detail": "test"})
	var banner: Node = vb.get_node_or_null("ViceResult")
	if not _check(banner != null and vb.get_child(0) == banner, "vice result card inserts ViceResult at the top of the card"):
		return false
	var texts: Array[String] = []
	for l: Node in banner.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	if not _check(texts.has("QUA MÔN!") and texts.has("+50 Cóc Vàng"), "win card: 'QUA MÔN!' + '+50 Cóc Vàng' (got %s)" % str(texts)):
		return false
	if not _check(banner.find_children("*", "TextureRect", true, false).size() >= 1, "win card has the pastel gradient strip"):
		return false
	sm.call("report_stage_result", 3, {"result": "fail", "score": 0, "rank": "C", "detail": "test", "caught": true})
	var banners: int = 0
	for ch: Node in vb.get_children():
		if ch.name.begins_with("ViceResult"):
			banners += 1
	banner = vb.get_node_or_null("ViceResult")
	texts.clear()
	if banner:
		for l: Node in banner.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
	if not _check(banners == 1 and texts.has("BỊ BẮT") and not texts.has("+50 Cóc Vàng"), "caught fail card: one banner 'BỊ BẮT' without coins (got %d banners, %s)" % [banners, str(texts)]):
		return false
	# classic: không chèn gì
	fx.call("set_art_style", "classic", false)
	sm.call("report_stage_result", 3, {"result": "fail", "score": 0, "rank": "C", "detail": "test"})
	var still: bool = vb.get_node_or_null("ViceResult") != null and (vb.get_node("ViceResult") as Control).visible
	fx.call("set_art_style", "vice", false)
	if not _check(not still, "classic result card has no vice banner"):
		return false
	(sm.get("best_stats") as Dictionary).erase(3)
	stage.queue_free()
	print("  result card OK")
	return true
