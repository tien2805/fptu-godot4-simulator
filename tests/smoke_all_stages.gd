# File: res://tests/smoke_all_stages.gd
# Smoke test headless: nạp + khởi tạo toàn bộ 7 scene màn chơi, chạy vài chục frame
# mỗi scene để bắt lỗi script (parse error, @onready sai đường dẫn, lỗi runtime trong _ready/_process).
# Chạy:  godot --headless --path . --script tests/smoke_all_stages.gd
# Kết quả: exit 0 nếu mọi scene nạp được; grep "SCRIPT ERROR" trong output để bắt lỗi runtime.
extends SceneTree

const SCENES: Array[String] = [
	"res://scenes/Main.tscn",
	"res://scenes/Stage2_Parking.tscn",
	"res://scenes/Stage3_ClassroomFAP.tscn",
	"res://scenes/Stage4_Vovinam.tscn",
	"res://scenes/Stage5_Canteen.tscn",
	"res://scenes/Stage6_CapstoneBoss.tscn",
	"res://scenes/StageExtra_EOSExam.tscn",
]
const FRAMES_PER_SCENE: int = 75

var _idx: int = -1
var _frames: int = 0
var _current: Node = null
var _failed: bool = false
var _started: bool = false

func _initialize() -> void:
	print("=== SMOKE TEST: FPTU STUDENT SIMULATOR ===")
	_ensure_autoload("StageManager", "res://scripts/StageManager.gd")
	_ensure_autoload("GameFX", "res://scripts/GameFX.gd")
	# Ép parse toàn bộ script trong scripts/ để bắt lỗi biên dịch
	var dir := DirAccess.open("res://scripts")
	if dir:
		dir.list_dir_begin()
		var f: String = dir.get_next()
		while f != "":
			if f.ends_with(".gd"):
				var s: Script = load("res://scripts/" + f)
				if s == null:
					push_error("PARSE FAIL: scripts/" + f)
					_failed = true
				else:
					print("  [parse ok] scripts/", f)
			f = dir.get_next()
	_started = true

func _ensure_autoload(name: String, path: String) -> void:
	if root.has_node(name):
		return
	var s: Script = load(path)
	if s == null:
		push_error("Cannot load autoload script: " + path)
		_failed = true
		return
	var n: Node = s.new()
	n.name = name
	root.add_child(n)
	print("  [autoload] injected ", name)

func _process(_delta: float) -> bool:
	if not _started:
		return false
	if _current == null:
		_idx += 1
		if _idx >= SCENES.size():
			print("=== SMOKE DONE: %s ===" % ("FAILED" if _failed else "ALL SCENES OK"))
			quit(1 if _failed else 0)
			return true
		var path: String = SCENES[_idx]
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("LOAD FAIL: " + path)
			_failed = true
			return false
		_current = packed.instantiate()
		if _current == null:
			push_error("INSTANTIATE FAIL: " + path)
			_failed = true
			return false
		root.add_child(_current)
		_frames = 0
		print("  [scene] ", path, " -> instantiated (", _current.get_child_count(), " children)")
		return false

	_frames += 1
	if _frames >= FRAMES_PER_SCENE:
		print("  [scene] ", SCENES[_idx], " survived ", _frames, " frames")
		_current.queue_free()
		_current = null
		Engine.time_scale = 1.0
	return false
