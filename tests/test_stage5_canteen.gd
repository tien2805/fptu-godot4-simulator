# File: res://tests/test_stage5_canteen.gd
# Test headless Màn 5: bot đi bằng phím WASD (parse_input_event) tới quầy lấy khay, bưng tới bàn bạn,
# cân khay bằng Space khi nghiêng, giao 2 đơn, đi tới 7-Eleven và giải combo đúng ngân sách rồi thanh toán.
# Kỳ vọng: không lỗi script, kết thúc THẮNG.
# Chạy:  godot --headless --path . --script tests/test_stage5_canteen.gd
extends SceneTree

var stage: Node3D
var frames: int = 0
var started: bool = false
var keys_down: Dictionary = {}
var last_pos: Vector3 = Vector3.ZERO
var stall_frames: int = 0
var sidestep_frames: int = 0
var sidestep_dir: int = 1
var shop_started: bool = false
const MAX_FRAMES: int = 60 * 60 * 5

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var packed: PackedScene = load("res://scenes/Stage5_Canteen.tscn")
	stage = packed.instantiate()
	root.add_child(stage)
	Engine.time_scale = 2.5
	print("--- TEST MÀN 5: BƯNG KHAY OVERCOOKED + 7-ELEVEN COMBO ---")
	started = true

func _set_key(code: int, down: bool) -> void:
	if keys_down.get(code, false) == down:
		return
	keys_down[code] = down
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _release_all() -> void:
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
		_set_key(code, false)

func _walk_towards(target: Vector3) -> float:
	var player: CharacterBody3D = stage.get("player")
	var to: Vector3 = target - player.global_position
	to.y = 0.0
	var dist: float = to.length()
	# Chống kẹt: nếu đứng yên quá lâu thì đi ngang 25 frame
	if player.global_position.distance_to(last_pos) < 0.02:
		stall_frames += 1
	else:
		stall_frames = 0
	last_pos = player.global_position
	if stall_frames > 25 and sidestep_frames <= 0:
		sidestep_frames = 25
		sidestep_dir = -sidestep_dir
		stall_frames = 0
	var dir: Vector3 = to.normalized()
	if sidestep_frames > 0:
		sidestep_frames -= 1
		dir = Vector3(-dir.z, 0.0, dir.x) * float(sidestep_dir)
	_set_key(KEY_W, dir.z < -0.3)
	_set_key(KEY_S, dir.z > 0.3)
	_set_key(KEY_A, dir.x < -0.3)
	_set_key(KEY_D, dir.x > 0.3)
	return dist

func _bot_serve() -> void:
	var has_tray: bool = stage.get("has_tray")
	var tilt: float = stage.get("tilt")
	if has_tray and absf(tilt) > 55.0:
		# Dừng lại cân khay
		_set_key(KEY_W, false); _set_key(KEY_S, false); _set_key(KEY_A, false); _set_key(KEY_D, false)
		_set_key(KEY_SPACE, true)
		return
	_set_key(KEY_SPACE, false)
	if not has_tray:
		var d: float = _walk_towards(Vector3(-8.0, 0.0, -4.6))
		if d < 1.2:
			stage.call("_interact")
	else:
		var table: Vector3 = stage.call("_current_table")
		# Giao khay từ phía gần (mặt nam bàn) – game chấp nhận trong 2.4 m quanh tâm bàn; bạn bè vẫy ở mặt bắc
		var d: float = _walk_towards(table + Vector3(0.0, 0.0, -2.1))
		if d < 1.0:
			stage.call("_interact")

func _bot_to_shop() -> void:
	var d: float = _walk_towards(Vector3(8.0, 0.0, -4.4))
	if d < 1.2:
		stage.call("_interact")

func _bot_shop() -> void:
	if shop_started:
		return
	shop_started = true
	_release_all()
	var budget: int = stage.get("budget")
	var items: Array = stage.get("SHOP_ITEMS")
	var by_id: Dictionary = {}
	for it: Dictionary in items:
		by_id[it["id"]] = it
	var plan: Array[String] = []
	match budget:
		30: plan = ["indomie", "banh_bao", "sting", "tra"]
		40: plan = ["indomie", "banh_bao", "sting", "tra", "keo"]
		_: plan = ["indomie", "banh_bao", "monster"]
	# Thử thêm món vượt ngân sách để kiểm tra từ chối
	stage.call("add_to_basket", by_id["monster"])
	stage.call("add_to_basket", by_id["monster"])
	stage.call("add_to_basket", by_id["monster"])
	var basket: Array = stage.get("basket")
	while basket.size() > 0:
		stage.call("remove_from_basket", 0)
		basket = stage.get("basket")
	for id: String in plan:
		stage.call("add_to_basket", by_id[id])
	var pay: Button = stage.get("pay_btn")
	print("  budget=%dk plan=%s pay_enabled=%s totals=%s" % [budget, str(plan), str(not pay.disabled), (stage.get("totals_label") as Label).text])
	stage.call("_on_pay_pressed")

func _process(_delta: float) -> bool:
	if not started or stage == null:
		return false
	frames += 1
	var phase: int = stage.get("phase")
	match phase:
		0: _bot_serve()
		1: _bot_to_shop()
		2: _bot_shop()
	if frames % 300 == 0:
		var player: CharacterBody3D = stage.get("player")
		print("  frame %d: phase %d, time_left %.1f, pos (%.1f, %.1f), tray=%s tilt=%.0f orders=%d spills=%d bumps=%d" % [
			frames, phase, stage.get("time_left"), player.global_position.x, player.global_position.z, str(stage.get("has_tray")), stage.get("tilt"), stage.get("orders_done"), stage.get("spills"), stage.get("bumps")])
	if stage.get("is_stage_ended"):
		_release_all()
		var title: String = (stage.get("modal_title") as Label).text
		print("  Kết thúc sau %d frame: %s" % [frames, title])
		var sm: Node = root.get_node_or_null("StageManager")
		var monsters: int = int(sm.call("item_count", "monster")) if sm else -1
		print("  orders=%d spills=%d bumps=%d monster_in_inventory=%d" % [stage.get("orders_done"), stage.get("spills"), stage.get("bumps"), monsters])
		if title.begins_with("🎉"):
			print("✅ SUCCESS: SERVE + SHOP LOOP COMPLETED WITH A WIN")
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
