# File: res://tools/cine_beats.gd
# Writes docs/cinematics/<slot>.txt for every timeline in scripts/cine/timelines/ (refuses invalid ones) and prints the
# owner's music folder.
# Run:  godot --headless --path . --script tools/cine_beats.gd
extends SceneTree


func _initialize() -> void:
	var dir: String = ProjectSettings.globalize_path("res://docs/cinematics/")
	DirAccess.make_dir_recursive_absolute(dir)
	var n: int = 0
	var bad: int = 0
	for s: String in CineTimeline.slots():
		var tl: CineTimeline = CineTimeline.load_slot(s)
		var errs: PackedStringArray = tl.validate()
		if not errs.is_empty():
			print("INVALID %s: %s" % [s, str(errs)])
			bad += 1
			continue
		var f: FileAccess = FileAccess.open(dir + s + ".txt", FileAccess.WRITE)
		f.store_string(tl.beat_sheet())
		f.close()
		n += 1
		print("wrote docs/cinematics/%s.txt" % s)
	print("music folder: %s  (<slot>.ogg or <slot>.mp3)" % ProjectSettings.globalize_path("user://music/"))
	print("BEATS WRITTEN %d (invalid %d)" % [n, bad])
	quit(1 if bad > 0 else 0)
