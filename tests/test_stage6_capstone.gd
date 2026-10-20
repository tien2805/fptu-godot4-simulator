# File: res://tests/test_stage6_capstone.gd
# Test headless Màn 6: bot gõ chữ (có cố tình gõ sai 1 lần), đổi người bằng Tab, dùng skill,
# gọi dậy bạn seen không rep (mash Space), resolve 3 git conflict (1 lần sai), gõ lệnh push cuối.
# Kỳ vọng: không lỗi script, kết thúc THẮNG (Cóc Vàng).
# Chạy:  godot --headless --path . --script tests/test_stage6_capstone.gd
extends SceneTree

var stage: Node3D
var frames: int = 0
var started: bool = false
var typo_done: bool = false
var wrong_conflict_done: bool = false
var last_state: int = -1
var type_cooldown: int = 0
const MAX_FRAMES: int = 60 * 60 * 5

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Stage6_CapstoneBoss.tscn")
	stage = packed.instantiate()
	root.add_child(stage)
	Engine.time_scale = 2.0
	print("--- TEST MÀN 6: BULLET-HELL TYPING + GIT CONFLICT ---")
	started = true

func _key(keycode: int, unicode: int = 0) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.unicode = unicode
	ev.pressed = true
	stage.call("_unhandled_input", ev)

func _type_string(s: String) -> void:
	for ch: String in s:
		if ch == " ":
			_key(KEY_SPACE, 32)
		else:
			_key(KEY_A, ch.unicode_at(0))

func _bot_battle() -> void:
	var st: int = stage.get("state")
	var bullets: Array = stage.get("bullets")
	var typed: String = stage.get("typed")
	var members: Array = stage.get("members")
	# Gọi dậy bạn ngủ: chọn member 3 + Enter rồi mash Space
	if stage.get("phone_active"):
		if frames % 2 == 0:
			_key(KEY_SPACE, 32)
		return
	if not members[3]["awake"] and float(stage.get("phone_cd")) <= 0.0 and frames % 40 == 0:
		stage.call("_select_member", 3)
		_key(KEY_ENTER)
		return
	# Dùng skill của người đang chọn mỗi ~3s, rồi Tab sang người khác
	if frames % 180 == 0:
		_key(KEY_ENTER)
		_key(KEY_TAB)
	# Gõ chữ: nếu đang khóa viên đạn thì gõ tiếp ký tự kế; nếu không, chọn viên thấp nhất
	if type_cooldown > 0:
		type_cooldown -= 1
		return
	if st == 3 and not stage.get("final_bullet").is_empty():
		var fb: Dictionary = stage.get("final_bullet")
		var word: String = fb["word"]
		if typed.length() < word.length() and word.begins_with(typed):
			var ch: String = word[typed.length()]
			_type_string(ch)
			type_cooldown = 1
			return
	var target: Dictionary = {}
	var locked: Dictionary = stage.get("locked")
	if not locked.is_empty() and not locked.get("dead", false):
		target = locked
	else:
		var best_y: float = -1.0
		for b: Dictionary in bullets:
			if not b.get("dead", false) and float(b["y"]) > best_y:
				best_y = float(b["y"])
				target = b
	if target.is_empty():
		return
	var word: String = str(target["word"]).to_lower()
	if not word.begins_with(typed):
		_key(KEY_ESCAPE)
		return
	if typed.length() < word.length():
		var ch: String = word[typed.length()]
		if not typo_done and frames > 200:
			typo_done = true
			ch = "z" if ch != "z" else "q"
		_type_string(ch)
		type_cooldown = 2

func _bot_git() -> void:
	var conflicts: Array = stage.get("conflicts")
	var idx: int = stage.get("conflict_idx")
	if idx >= conflicts.size():
		return
	if float(stage.get("conflict_timer")) > 7.0:
		return
	var correct: int = int(conflicts[idx]["correct"])
	if not wrong_conflict_done:
		wrong_conflict_done = true
		correct = KEY_RIGHT if correct == KEY_LEFT else KEY_LEFT
	_key(correct)

func _process(_delta: float) -> bool:
	if not started or stage == null:
		return false
	frames += 1
	var state: int = stage.get("state")
	if state != last_state:
		last_state = state
		print("  frame %d: state -> %d (boss %d, score %d, words %d, typos %d, hits %d)" % [frames, state, stage.get("boss_hp"), stage.get("score"), stage.get("words_destroyed"), stage.get("typos"), stage.get("hits_taken")])
	match state:
		1, 3: _bot_battle()
		2: _bot_git()
	if frames % 600 == 0:
		var members: Array = stage.get("members")
		print("  frame %d: time_left %.1f boss %d words %d combo %d hp=[%d,%d,%d,%d] awake4=%s" % [frames, stage.get("time_left"), stage.get("boss_hp"), stage.get("words_destroyed"), stage.get("combo"), members[0]["hp"], members[1]["hp"], members[2]["hp"], members[3]["hp"], str(members[3]["awake"])])
	if state == 4 or state == 5:
		var title: String = (stage.get("modal_title") as Label).text
		if title == "" and state == 4:
			return false # chờ modal thắng hiện sau animation
		print("  Kết thúc sau %d frame: %s" % [frames, title])
		print("  words=%d typos=%d hits=%d conflicts_right=%d awake4=%s" % [stage.get("words_destroyed"), stage.get("typos"), stage.get("hits_taken"), stage.get("conflicts_right"), str((stage.get("members") as Array)[3]["awake"])])
		if state == 4 and int(stage.get("typos")) >= 1 and int(stage.get("conflicts_right")) == 2:
			print("✅ SUCCESS: TYPING BATTLE, PHONE WAKE-UP, GIT CONFLICTS AND FINAL PUSH ALL WORK")
			quit(0)
		else:
			print("❌ FAILED: unexpected ending (state %d)" % state)
			quit(1)
		return true
	if frames >= MAX_FRAMES:
		print("❌ FAILED: timeout in state %d" % state)
		quit(1)
		return true
	return false
