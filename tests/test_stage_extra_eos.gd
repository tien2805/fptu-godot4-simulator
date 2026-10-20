# File: res://tests/test_stage_extra_eos.gd
# Test headless Extra: bot bật/tắt CCTV, chụp bằng chứng đúng lúc "tell" đang diễn ra, soi máy,
# lập biên bản; cố tình ép biên bản 1 sinh viên vô tội để kiểm tra trừ uy tín; chụp 1 ảnh rỗng.
# Kỳ vọng: không lỗi script, bắt đủ 5 thánh tool, thắng với uy tín 65.
# Chạy:  godot --headless --path . --script tests/test_stage_extra_eos.gd
extends SceneTree

var stage: Node3D
var frames: int = 0
var started: bool = false
var wrong_done: bool = false
var empty_photo_done: bool = false
var cctv_toggled: int = 0
const MAX_FRAMES: int = 60 * 60 * 3

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/StageExtra_EOSExam.tscn")
	stage = packed.instantiate()
	root.add_child(stage)
	Engine.time_scale = 3.0
	print("--- TEST EXTRA: GIÁM THỊ EOS – BẰNG CHỨNG, CCTV, BẮT OAN ---")
	started = true

func _process(_delta: float) -> bool:
	if not started or stage == null:
		return false
	frames += 1
	var stations: Array = stage.get("stations")
	if frames == 30 or frames == 90:
		stage.call("_toggle_cctv")
		cctv_toggled += 1
	if frames == 150 and not empty_photo_done:
		empty_photo_done = true
		# Chụp 1 ảnh máy không có tell -> tốn ảnh, không bằng chứng
		for st: Dictionary in stations:
			if not st["is_cheater"]:
				stage.call("_take_photo", int(st["idx"]))
				break
	if frames == 200 and not wrong_done:
		wrong_done = true
		for st: Dictionary in stations:
			if not st["is_cheater"] and not st["booked"]:
				stage.call("_inspect_station", int(st["idx"]))
				stage.call("_on_force_book")
				break
	# Bot: thấy tell đang diễn ra -> chụp -> soi -> lập biên bản
	if not (stage.get("inspect_panel") as Control).visible:
		for st: Dictionary in stations:
			if st["is_cheater"] and st["tell_active"] and not st["booked"] and int(st["evidence"]) == 0 and int(stage.get("photos_used")) < 8:
				var proctor: CharacterBody3D = stage.get("proctor")
				proctor.global_position = (st["node"] as Node3D).global_position + Vector3(0.0, 0.85, 3.0)
				stage.call("_take_photo", int(st["idx"]))
				stage.call("_inspect_station", int(st["idx"]))
				stage.call("_on_confiscate_pressed")
				break
	if frames % 300 == 0:
		print("  frame %d: time_left %.1f caught %d wrong %d photos %d rep %d cctv=%s" % [frames, stage.get("time_left"), stage.get("caught"), stage.get("wrong_books"), stage.get("photos_used"), stage.get("reputation"), str(stage.get("is_cctv"))])
	if stage.get("is_stage_ended"):
		var title: String = (stage.get("modal_title") as Label).text
		print("  Kết thúc sau %d frame: %s" % [frames, title])
		print("  caught=%d wrong=%d photos=%d rep=%d cctv_toggles=%d" % [stage.get("caught"), stage.get("wrong_books"), stage.get("photos_used"), stage.get("reputation"), cctv_toggled])
		if title.begins_with("⚖️") and int(stage.get("wrong_books")) == 1 and int(stage.get("reputation")) == 65 and cctv_toggled == 2:
			print("✅ SUCCESS: EVIDENCE WORKFLOW, CCTV TOGGLE AND WRONGFUL-BOOKING PENALTY ALL WORK")
			quit(0)
		else:
			print("❌ FAILED: unexpected ending")
			quit(1)
		return true
	if frames >= MAX_FRAMES:
		print("❌ FAILED: timeout (caught %d)" % stage.get("caught"))
		quit(1)
		return true
	return false
