# File: res://tests/test_stage3_classroom.gd
# Test headless Màn 3: bot bật 4G, nhập đúng mã FAP sau khi 4G xong, rồi trong pha sinh tồn
# bấm nhịp đúng beat, uống cà phê khi cần, trả lời quiz bằng đáp án đúng, úp điện thoại khi có cảnh báo.
# Kỳ vọng: không lỗi script, màn kết thúc THẮNG.
# Chạy:  godot --headless --path . --script tests/test_stage3_classroom.gd
extends SceneTree

var stage: Node3D
var frames: int = 0
var started: bool = false
var wrong_tried: bool = false
var next_beat_press: float = 0.0
const MAX_FRAMES: int = 60 * 60 * 4

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Stage3_ClassroomFAP.tscn")
	stage = packed.instantiate()
	root.add_child(stage)
	Engine.time_scale = 3.0
	print("--- TEST MÀN 3: FAP WI-FI LAG + SINH TỒN 16°C ---")
	started = true

func _process(_delta: float) -> bool:
	if not started or stage == null:
		return false
	frames += 1
	var phase: int = stage.get("phase")
	if phase == 0:
		# Thử một lần nhập sai qua Wi-Fi để kiểm tra strike, rồi bật 4G
		if frames == 10 and not wrong_tried:
			wrong_tried = true
			var ci: LineEdit = stage.get("code_input")
			ci.text = "ZZZZZZ"
			stage.call("_on_submit_fap_pressed")
		if frames == 60:
			stage.call("_on_switch_4g_pressed")
		if stage.get("is_using_4g") and frames % 20 == 0:
			var ci: LineEdit = stage.get("code_input")
			if ci.editable:
				ci.text = stage.get("real_code")
				stage.call("_on_submit_fap_pressed")
	elif phase == 1:
		var bp: float = stage.get("beat_phase")
		var period: float = 0.8
		var dist: float = minf(bp, period - bp)
		if not stage.get("quiz_active") and dist < 0.06 and frames >= next_beat_press:
			stage.call("_on_beat_press")
			next_beat_press = frames + 6
		if float(stage.get("sleepiness")) > 70.0 and int(stage.get("coffee_left")) > 0 and frames % 30 == 0:
			stage.call("_on_coffee_pressed")
		if float(stage.get("hunger")) > 75.0 and not stage.get("lecturer_watching") and frames % 15 == 0:
			stage.call("_on_banhbao_pressed")
		if stage.get("quiz_active") and float(stage.get("quiz_timer")) < 6.5:
			var answers: Array = stage.get("quiz_answers")
			stage.call("_on_quiz_submitted", str(answers[0]))
		if stage.get("phone_active") and float(stage.get("phone_timer")) < 1.0:
			stage.call("_on_phone_flip")

	if frames % 240 == 0:
		print("  frame %d: phase %d, time_left %.1f, strikes %d, 4g=%s, sleep %.0f, hunger %.0f, attention %.0f, beats %d/%d" % [
			frames, phase, stage.get("time_left"), stage.get("strikes"), str(stage.get("is_using_4g")),
			stage.get("sleepiness"), stage.get("hunger"), stage.get("attention"), stage.get("beat_hits"), stage.get("beat_misses")])

	if stage.get("is_stage_ended"):
		var title: String = (stage.get("modal_title") as Label).text
		print("  Kết thúc sau %d frame: %s" % [frames, title])
		print("  strikes=%d quiz=%d/%d phone_confiscated=%s" % [stage.get("strikes"), stage.get("quiz_correct"), stage.get("quiz_count"), str(stage.get("phone_confiscated"))])
		# strikes có thể là 0 nếu lần gửi sai qua Wi-Fi bị "timeout" ngẫu nhiên (30%)
		if title.begins_with("🎉") and int(stage.get("strikes")) <= 1:
			print("✅ SUCCESS: FAP + SURVIVAL LOOP COMPLETED WITH A WIN")
			quit(0)
		else:
			print("❌ FAILED: unexpected ending")
			quit(1)
		return true
	if frames >= MAX_FRAMES:
		print("❌ FAILED: timeout in phase %d" % phase)
		quit(1)
		return true
	return false
