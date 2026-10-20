# File: res://tests/preview_m1_ui.gd
# Chụp ảnh kiểm tra UI mới của M1 (cần cửa sổ render, KHÔNG dùng --headless):
#   godot --path . --script tests/preview_m1_ui.gd
# 1) Màn 1: bảng chuỗi near-miss (gọi thẳng _on_near_miss x3)   -> m1_chain_panel.png
# 2) Menu tạm dừng (ESC) + hộp cài đặt (chất lượng + âm lượng)   -> m1_pause_menu.png, m1_pause_settings.png
# 3) Thẻ chuyển cảnh Màn 1 -> Màn 2 (đồng hồ chạy, câu thoại)    -> m1_transition_card.png, m1_after_transition.png
# 4) Màn 5: cửa hàng 7-Eleven điều khiển bằng phím (ô đang chọn) -> m1_shop_keyboard.png
extends SceneTree

var frames: int = 0
var step: int = 0
var out_dir: String
var sm: Node
var stage: Node
var t_mark: int = 0

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	sm = root.get_node("StageManager")
	out_dir = ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("PREVIEW OUT DIR: ", out_dir)
	_load("res://scenes/Main.tscn")
	sm.set("current_stage", 1)

func _load(path: String) -> void:
	var packed: PackedScene = load(path)
	stage = packed.instantiate()
	root.add_child(stage)
	current_scene = stage
	frames = 0

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d (step %d, frame %d)" % [name, err, step, frames])

func _process(_d: float) -> bool:
	frames += 1
	match step:
		0:
			if frames == 70:
				var hud: Node = stage.get_node("HUD")
				for c: int in [1, 2, 3]:
					hud.call("_on_near_miss", c)
			elif frames == 76:
				_save("m1_chain_panel")
				sm.call("pause_game")
			elif frames == 84:
				print("  paused=", paused, " pause_visible=", (sm.get("pause_layer") as CanvasLayer).visible)
				_save("m1_pause_menu")
				(sm.get("pause_settings_box") as Control).visible = true
			elif frames == 90:
				_save("m1_pause_settings")
				sm.call("resume_game")
			elif frames == 96:
				print("  resumed, paused=", paused)
				sm.call("change_stage", 2)
				t_mark = frames
				step = 1
		1:
			if frames == t_mark + 50:
				print("  transition_active=", sm.get("transition_active"), " clock=", (sm.get("transition_clock") as Label).text, " line=", (sm.get("transition_line") as Label).text)
				_save("m1_transition_card")
			elif frames > t_mark + 50 and not bool(sm.get("transition_active")):
				step = 2
				t_mark = frames
		2:
			if frames == t_mark + 75:
				print("  current_scene after transition: ", current_scene.name if current_scene else "<null>")
				_save("m1_after_transition")
				if current_scene:
					current_scene.queue_free()
				step = 3
		3:
			if frames == t_mark + 80:
				_load("res://scenes/Stage5_Canteen.tscn")
				step = 4
		4:
			if frames == 40:
				stage.call("_open_shop")
			elif frames == 48:
				stage.call("_shop_key", KEY_RIGHT)
				stage.call("_shop_key", KEY_ENTER)
				stage.call("_shop_key", KEY_RIGHT)
				stage.call("_shop_key", KEY_ENTER)
				stage.call("_shop_key", KEY_DOWN)
			elif frames == 54:
				print("  shop focus idx=", stage.get("shop_focus_idx"), " basket=", (stage.get("basket") as Array).size())
				_save("m1_shop_keyboard")
				print("PREVIEW M1 DONE")
				quit(0)
				return true
	return false
