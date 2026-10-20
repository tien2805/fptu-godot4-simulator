# File: res://tests/test_stage4_vovinam.gd
# Test headless Màn 4: bot đánh ~85% nốt đúng nhịp, cố tình miss 3 nốt liên tiếp một lần để kiểm tra
# hít đất, rồi thực hiện chuỗi finisher 5 bước (có 1 lần cố tình sai bước 3 để kiểm tra ngã + làm lại).
# Kỳ vọng: không lỗi script, kết thúc THẮNG ("ĐIỂM 10").
# Chạy:  godot --headless --path . --script tests/test_stage4_vovinam.gd
extends SceneTree

var stage: Node3D
var frames: int = 0
var started: bool = false
var note_counter: int = 0
var judged_ids: Dictionary = {}
var alt_frame: int = 0
var alt_next: int = KEY_LEFT
var forced_fail_done: bool = false
var w_pressed: bool = false
var last_state: int = -1
const MAX_FRAMES: int = 60 * 60 * 4

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Stage4_Vovinam.tscn")
	stage = packed.instantiate()
	root.add_child(stage)
	Engine.time_scale = 2.5
	print("--- TEST MÀN 4: RHYTHM 3 VÒNG + FINISHER 5 BƯỚC ---")
	started = true

func _press_w(down: bool) -> void:
	if w_pressed == down:
		return
	w_pressed = down
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W
	ev.keycode = KEY_W
	ev.pressed = down
	Input.parse_input_event(ev)

func _bot_rhythm() -> void:
	var song_time: float = stage.get("song_time")
	var notes: Array = stage.get("notes")
	for n: Dictionary in notes:
		if n["judged"]:
			continue
		var id: int = n["node"].get_instance_id()
		if judged_ids.has(id):
			continue
		var dt: float = float(n["time"]) - song_time
		if absf(dt) < 0.05:
			judged_ids[id] = true
			note_counter += 1
			# Vòng 1: cố tình bỏ nốt 2,3,4 để dính hít đất; các vòng sau miss ~1/7
			var skip: bool = (note_counter >= 2 and note_counter <= 4) or (note_counter > 4 and note_counter % 7 == 3)
			if not skip:
				stage.call("_judge_press", int(n["key"]))
		break

func _bot_finisher() -> void:
	var step: int = stage.get("fin_step")
	var ring: Control = stage.get("fin_ring")
	match step:
		1:
			_press_w(true)
		2, 4:
			_press_w(false)
			var ratio: float = ring.get("ratio")
			var target: float = stage.get("ring_target")
			if absf(ratio - target) < 0.04:
				stage.call("_finisher_key", KEY_SPACE)
		3:
			if not forced_fail_done:
				forced_fail_done = true
				stage.call("_finisher_key", KEY_LEFT)
				stage.call("_finisher_key", KEY_LEFT) # trùng phím -> ngã, làm lại từ bước 1
				return
			if frames - alt_frame >= 3:
				alt_frame = frames
				stage.call("_finisher_key", alt_next)
				alt_next = KEY_RIGHT if alt_next == KEY_LEFT else KEY_LEFT
		5:
			stage.call("_finisher_key", KEY_DOWN)

func _process(_delta: float) -> bool:
	if not started or stage == null:
		return false
	frames += 1
	var state: int = stage.get("state")
	if state != last_state:
		last_state = state
		print("  frame %d: state -> %d (score %d, misses %d, pushups %d, fin_fails %d)" % [frames, state, stage.get("score"), stage.get("misses"), stage.get("pushups_done"), stage.get("fin_fails")])
	match state:
		1: _bot_rhythm()          # RHYTHM
		2:                        # PUSHUP
			if frames % 2 == 0:
				stage.call("_pushup_press")
		4: _bot_finisher()        # FINISHER
	if state == 6: # DONE
		_press_w(false)
		var title: String = (stage.get("modal_title") as Label).text
		print("  Kết thúc sau %d frame: %s" % [frames, title])
		print("  perfect=%d good=%d miss=%d pushups=%d fin_fails=%d score=%d" % [stage.get("perfects"), stage.get("goods"), stage.get("misses"), stage.get("pushups_done"), stage.get("fin_fails"), stage.get("score")])
		if title.begins_with("🥋 ĐIỂM 10") and int(stage.get("pushups_done")) >= 1 and int(stage.get("fin_fails")) >= 1:
			print("✅ SUCCESS: RHYTHM + PUSHUP + FINISHER CHAIN ALL EXERCISED, STAGE WON")
			quit(0)
		else:
			print("❌ FAILED: unexpected ending")
			quit(1)
		return true
	if frames >= MAX_FRAMES:
		print("❌ FAILED: timeout in state %d" % state)
		quit(1)
		return true
	return false
