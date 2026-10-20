# File: res://tests/test_hud_bounds.gd
# Kiểm tra HUD không bị cắt: nạp menu + 7 màn ở 3 độ phân giải cửa sổ (1280x720, 1920x1080, 2560x1440),
# chờ vài frame rồi duyệt mọi Control đang hiển thị; rect toàn cục phải nằm trong viewport (dung sai 1 px).
# Chạy:  godot --headless --path . --script tests/test_hud_bounds.gd
extends SceneTree

const SCENES: Array[String] = [
	"res://scenes/MainMenu.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/Stage2_Parking.tscn",
	"res://scenes/Stage3_ClassroomFAP.tscn",
	"res://scenes/Stage4_Vovinam.tscn",
	"res://scenes/Stage5_Canteen.tscn",
	"res://scenes/Stage6_CapstoneBoss.tscn",
	"res://scenes/StageExtra_EOSExam.tscn"
]
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SETTLE_FRAMES: int = 8

var combo: int = -1
var frames: int = 0
var current: Node = null
var failures: Array[String] = []
var checked: int = 0

func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	print("--- TEST HUD BOUNDS: %d scenes x %d resolutions ---" % [SCENES.size(), SIZES.size()])

func _walk(n: Node, vp: Rect2, scene_name: String, size_tag: String) -> void:
	if n is Control:
		var c: Control = n
		if c.is_visible_in_tree() and c.size.x > 2.0 and c.size.y > 2.0 and not (c is ScrollContainer):
			var r: Rect2 = c.get_global_rect()
			var tol: float = 1.0
			if r.position.x < vp.position.x - tol or r.position.y < vp.position.y - tol or r.end.x > vp.end.x + tol or r.end.y > vp.end.y + tol:
				failures.append("%s @%s: %s rect=%s vp=%s" % [scene_name, size_tag, c.get_path(), r, vp])
			checked += 1
	for ch: Node in n.get_children():
		# Không chui vào nội dung ScrollContainer (được phép tràn và cuộn)
		if n is ScrollContainer:
			continue
		_walk(ch, vp, scene_name, size_tag)

func _process(_d: float) -> bool:
	frames += 1
	if current == null:
		combo += 1
		if combo >= SCENES.size() * SIZES.size():
			print("  checked %d controls" % checked)
			if failures.is_empty():
				print("✅ SUCCESS: NO HUD ELEMENT IS CLIPPED AT ANY RESOLUTION")
				quit(0)
			else:
				for f: String in failures:
					print("  ✗ ", f)
				print("❌ FAILED: %d clipped controls" % failures.size())
				quit(1)
			return true
		var size: Vector2i = SIZES[combo % SIZES.size()]
		root.size = size
		var packed: PackedScene = load(SCENES[combo / SIZES.size()])
		current = packed.instantiate()
		root.add_child(current)
		frames = 0
		return false
	if frames >= SETTLE_FRAMES:
		var size: Vector2i = SIZES[combo % SIZES.size()]
		var scene_name: String = SCENES[combo / SIZES.size()].get_file()
		# Trong stretch mode canvas_items, viewport thiết kế là kích thước nội dung; lấy từ chính Control
		var vp: Rect2 = root.get_visible_rect()
		_walk(current, vp, scene_name, "%dx%d" % [size.x, size.y])
		current.queue_free()
		current = null
		Engine.time_scale = 1.0
		var sm: Node = root.get_node_or_null("StageManager")
		if sm:
			sm.set("typing_mode", false)
	return false
