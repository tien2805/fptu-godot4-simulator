# File: res://tests/preview_peds.gd
# Ảnh đám đông + xe chạy FreeRoam (cần cửa sổ render): vice_roam_peds_1 (trước sảnh BE6, khu dân cư), vice_roam_peds_2
# (cổng chính campus), vice_roam_peds_3 (lề đường Nguyễn Xiển). fps của từng ảnh là cổng hiệu năng của spec.
#   godot --path . --script tests/preview_peds.gd      (PREVIEW_DIR=..., VICE_STYLE=vice|classic, PREVIEW_NOVSYNC=1)
extends SceneTree

var roam: Node3D
var frames: int = 0
var out_dir: String


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	var style: String = OS.get_environment("VICE_STYLE")
	if style != "":
		var fx: Node = root.get_node("GameFX")
		fx.ready.connect(func() -> void: fx.call("set_art_style", style, false), CONNECT_ONE_SHOT)
	if OS.get_environment("PREVIEW_NOVSYNC") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dir_env: String = OS.get_environment("PREVIEW_DIR")
	out_dir = dir_env if dir_env != "" else ProjectSettings.globalize_path("user://preview")
	DirAccess.make_dir_recursive_absolute(out_dir)
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)


func _save(name: String) -> void:
	var err: int = root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("  saved %s.png err=%d fps=%.0f" % [name, err, Engine.get_frames_per_second()])


func _process(_d: float) -> bool:
	frames += 1
	var player: ThirdPersonController = roam.get("player") as ThirdPersonController
	if frames == 240:
		_save("vice_roam_peds_1")
		var gate: Vector3 = FPTUCampusBuilder.real_plot_transform() * (FPTUCampusBuilder.main_gate_local() + Vector3(0.0, 0.5, -14.0))
		player.teleport(gate, PI)
	if frames == 480:
		_save("vice_roam_peds_2")
		player.teleport(Vector3(2051.0, 0.5, -69.0), 0.0)   # lề tây Nguyễn Xiển, nhìn dọc đường về phía bắc
	if frames == 720:
		_save("vice_roam_peds_3")
		print("PREVIEW PEDS DONE")
		quit(0)
	return false
