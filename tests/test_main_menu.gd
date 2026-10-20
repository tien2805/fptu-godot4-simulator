# File: res://tests/test_main_menu.gd
# Test headless MENU CHÍNH: scene nạp được, đủ 5 nút, mở/đóng Hướng dẫn, đổi mức đồ hoạ (lưu user://settings.cfg),
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
