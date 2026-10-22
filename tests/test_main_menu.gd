# File: res://tests/test_main_menu.gd
# Test headless MENU CHÍNH: scene nạp được, đủ 5 nút, mở/đóng Hướng dẫn (có khối "Nguồn dữ liệu bản đồ" OSM +
# Microsoft, cả bảng nằm gọn trong viewport), đổi mức đồ hoạ (lưu user://settings.cfg), bảng cài đặt có hàng
# "Phong cách đồ hoạ" (Vice City / Cổ điển, đổi qua UI áp lại nền menu; chú thích nút mức đồ hoạ ở menu chính và menu
# tạm dừng đổi theo phong cách, vice không quảng cáo SDFGI / SSAO) + "Vệt sáng (trails)", thẻ tạm dừng mở
# cài đặt vẫn gọn trong viewport,
# mở Campaign Hub, rồi "Bắt đầu ngày mới" phải reset hành trình và chuyển sang Màn 1 (scene Main).
# Chạy:  godot --headless --path . --script tests/test_main_menu.gd
extends SceneTree

var menu: Node
var frames: int = 0
var started: bool = false
var sm: Node
var fx: Node
var inv_before: int = 0

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	sm = root.get_node("StageManager")
	fx = root.get_node("GameFX")
	var packed: PackedScene = load("res://scenes/MainMenu.tscn")
	menu = packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	print("--- TEST MENU CHÍNH ---")
	started = true

func _fail(msg: String) -> void:
	print("❌ FAILED: ", msg)
	quit(1)

func _process(_d: float) -> bool:
	if not started:
		return false
	frames += 1
	match frames:
		10:
			for key: String in ["btn_start", "btn_hub", "btn_guide", "btn_settings", "btn_quit"]:
				if menu.get(key) == null:
					_fail("thiếu nút " + key)
					return true
			print("  5 nút menu OK; focus = ", str(get_root().gui_get_focus_owner()))
			menu.call("_show_guide")
			if not (menu.get("guide_panel") as Control).visible:
				_fail("bảng hướng dẫn không hiện")
				return true
		13:
			# Bảng hướng dẫn (đã dàn trang) có khối "Nguồn dữ liệu bản đồ" và nằm gọn trong viewport
			var gp: Control = menu.get("guide_panel")
			var credits: Label = gp.find_child("MapCreditsText", true, false) as Label
			if credits == null or not credits.is_visible_in_tree():
				_fail("bảng hướng dẫn thiếu khối Nguồn dữ liệu bản đồ")
				return true
			if not (credits.text.contains("© OpenStreetMap contributors (ODbL)") and credits.text.contains("Building footprints © Microsoft (CDLA-Permissive-2.0)")):
				_fail("ghi công bản đồ sai: " + credits.text)
				return true
			var vp: Rect2 = root.get_visible_rect()
			var r: Rect2 = gp.get_global_rect()
			print("  bảng hướng dẫn %s trong viewport %s, ghi công: %s" % [str(r), str(vp), credits.text.replace("\n", " | ")])
			if not vp.grow(1.0).encloses(r):
				_fail("bảng hướng dẫn tràn khỏi viewport: %s" % str(r))
				return true
			menu.call("_hide_modals")
			if (menu.get("guide_panel") as Control).visible:
				_fail("bảng hướng dẫn không đóng")
				return true
			print("  hướng dẫn mở/đóng OK")
		20:
			menu.call("_set_quality", 1)
			if int(fx.get("visual_quality")) != 1:
				_fail("visual_quality không đổi")
				return true
			if not FileAccess.file_exists("user://settings.cfg"):
				_fail("settings.cfg chưa được lưu")
				return true
			menu.call("_set_quality", 2)
			print("  đổi mức đồ hoạ + lưu settings OK")
			menu.call("_show_settings")
		23:
			# Bảng cài đặt: hàng phong cách đồ hoạ (Vice City / Cổ điển) + vệt sáng + gợi ý, nằm gọn trong viewport
			var sp: Control = menu.get("settings_panel")
			var vp2: Rect2 = root.get_visible_rect()
			if not vp2.grow(1.0).encloses(sp.get_global_rect()):
				_fail("bảng cài đặt tràn khỏi viewport: %s" % str(sp.get_global_rect()))
				return true
			var opt: OptionButton = sp.find_child("ArtStyleOption", true, false) as OptionButton
			var trails: CheckButton = sp.find_child("TrailsCheck", true, false) as CheckButton
			var hint: Label = sp.find_child("ArtStyleHint", true, false) as Label
			if opt == null or trails == null or hint == null:
				_fail("bảng cài đặt thiếu hàng phong cách đồ hoạ / vệt sáng / gợi ý")
				return true
			if opt.item_count != 2 or opt.get_item_text(0) != "Vice City" or opt.get_item_text(1) != "Cổ điển":
				_fail("OptionButton phong cách phải có 'Vice City' / 'Cổ điển'")
				return true
			if trails.text != "Vệt sáng (trails)" or not hint.text.contains("Cổ điển áp dụng đầy đủ khi vào lại màn"):
				_fail("nhãn vệt sáng / gợi ý sai: %s | %s" % [trails.text, hint.text])
				return true
			# Đổi phong cách qua UI rồi đổi lại (settings.cfg của người chơi giữ nguyên lựa chọn cũ)
			var orig: String = String(fx.get("art_style"))
			var other: String = "classic" if orig == "vice" else "vice"
			for st: String in [other, orig]:
				var idx: int = 0 if st == "vice" else 1
				opt.select(idx)
				opt.item_selected.emit(idx)
				if String(fx.get("art_style")) != st:
					_fail("chọn %s không đổi GameFX.art_style" % st)
					return true
				var vice_on: bool = menu.has_meta("vice_look")
				if vice_on != (st == "vice") or String(menu.get_meta("visual_preset", "")) != "dawn":
					_fail("đổi sang %s không áp lại preset dawn của menu (vice_look=%s)" % [st, str(menu.get_meta("vice_look", ""))])
					return true
				if CharacterBuilder.toon != (st == "classic") or not is_equal_approx(CharacterBuilder.head_scale_default, 1.3 if st == "classic" else 1.15):
					_fail("%s: CharacterBuilder.toon / head_scale_default sai" % st)
					return true
				# Nút mức đồ hoạ (menu chính + menu tạm dừng) đổi chú thích theo phong cách: vice không quảng cáo SDFGI / SSAO
				var pause_btns: Array = sm.get("pause_quality_buttons")
				for q: int in range(3):
					var cap: PackedStringArray = fx.call("quality_caption", q)
					var mb: Button = sp.find_child("QualityButton%d" % q, true, false) as Button
					if mb == null or pause_btns.size() != 3:
						_fail("thiếu nút mức đồ hoạ ở menu chính / menu tạm dừng")
						return true
					var pb: Button = pause_btns[q]
					if not mb.text.contains(cap[0]) or not mb.text.contains(cap[1]) or not pb.text.contains(cap[1]):
						_fail("%s: chú thích nút mức %d chưa đổi theo phong cách (%s | %s, cần %s)" % [st, q, mb.text.replace("\n", " / "), pb.text.replace("\n", " / "), " · ".join(cap)])
						return true
					if st == "vice" and (mb.text.contains("SDFGI") or mb.text.contains("SSAO") or pb.text.contains("SDFGI") or pb.text.contains("SSAO")):
						_fail("vice: nút mức đồ hoạ còn quảng cáo tính năng cổ điển: %s" % mb.text)
						return true
				print("  %s: quality buttons %s" % [st, " | ".join(PackedStringArray([(sp.find_child("QualityButton0", true, false) as Button).text.replace("\n", " · "), (sp.find_child("QualityButton2", true, false) as Button).text.replace("\n", " · ")]))])
			var orig_trails: bool = bool(fx.get("trails_enabled"))
			trails.button_pressed = not orig_trails
			if bool(fx.get("trails_enabled")) == orig_trails:
				_fail("CheckButton vệt sáng không đổi GameFX.trails_enabled")
				return true
			trails.button_pressed = orig_trails
			var cfg := ConfigFile.new()
			cfg.load("user://settings.cfg")
			if String(cfg.get_value("video", "art_style", "")) != orig or bool(cfg.get_value("video", "trails", not orig_trails)) != orig_trails:
				_fail("settings.cfg không lưu video/art_style + video/trails")
				return true
			menu.call("_hide_modals")
			print("  bảng cài đặt: phong cách %s <-> %s áp lại menu, vệt sáng lưu, gọn trong viewport OK" % [orig, other])
		25:
			# Menu tạm dừng mở hộp cài đặt (có thêm hàng phong cách) vẫn nằm gọn trong màn 720 px
			sm.call("pause_game")
			(sm.get("pause_settings_box") as Control).visible = true
		27:
			var box: Control = sm.get("pause_settings_box")
			var card: Node = box
			while card and not (card is PanelContainer):
				card = card.get_parent()
			var r2: Rect2 = (card as Control).get_global_rect()
			print("  thẻ tạm dừng + cài đặt: %s trong %s" % [str(r2), str(root.get_visible_rect())])
			if box.find_child("ArtStyleOption", true, false) == null:
				_fail("menu tạm dừng thiếu hàng phong cách đồ hoạ")
				return true
			if not root.get_visible_rect().grow(1.0).encloses(r2):
				_fail("thẻ tạm dừng tràn khỏi viewport khi mở cài đặt: %s" % str(r2))
				return true
			sm.call("resume_game")
		30:
			(menu.get("btn_hub") as Button).emit_signal("pressed")
			if not (sm.get("modal_layer") as CanvasLayer).visible:
				_fail("Campaign Hub không mở từ menu")
				return true
			sm.call("toggle_stage_select")
			print("  Campaign Hub mở từ menu OK")
		40:
			sm.call("add_item", "monster", 2)
			inv_before = int(sm.call("item_count", "monster"))
			(menu.get("btn_start") as Button).emit_signal("pressed")
		120:
			var cs: Node = current_scene
			var inv_after: int = int(sm.call("item_count", "monster"))
			print("  sau Bắt đầu: current_scene = ", (cs.name if cs else "null"), ", monster ", inv_before, " -> ", inv_after)
			if cs == null or cs.name != "Main":
				_fail("không chuyển sang Màn 1 (Main.tscn)")
				return true
			if inv_after != 0:
				_fail("inventory không reset khi bắt đầu ngày mới")
				return true
			print("✅ SUCCESS: MAIN MENU → GUIDE/SETTINGS/HUB WORK, NEW DAY RESETS RUN AND LOADS STAGE 1")
			quit(0)
			return true
	if frames > 600:
		_fail("timeout")
		return true
	return false
