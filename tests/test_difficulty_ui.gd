# File: res://tests/test_difficulty_ui.gd
# Headless test of the Q6 difficulty check (plan 2026-10-29-w2-story T1): GameFX.build_story_settings adds "Chế độ Dễ"
# (EasyModeCheck) in the full row (main-menu settings) and in the compact pause row (beside the art style row); toggling it
# sets Difficulty.easy and saves gameplay/difficulty to GameFX.settings_path; load_settings brings it back; sync_style_settings
# follows the current value without emitting. The settings file is a temp file: the owner's settings are never written.
# Run:  godot --headless --path . --script tests/test_difficulty_ui.gd
extends SceneTree

const TMP: String = "user://test_difficulty_ui.cfg"
var fails: Array[String] = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)


func _initialize() -> void:
	print("== test_difficulty_ui")
	call_deferred("_run")


func _run() -> void:
	var gfx: Node = root.get_node_or_null("GameFX")
	_check(gfx != null, "GameFX autoload")
	if gfx == null:
		quit(1)
		return
	var path0: String = String(gfx.get("settings_path"))
	var easy0: bool = Difficulty.easy
	gfx.set("settings_path", TMP)
	Difficulty.set_easy(false)
	# full row (main menu)
	var full := VBoxContainer.new()
	root.add_child(full)
	gfx.call("build_story_settings", full)
	var ck: CheckButton = full.find_child("EasyModeCheck", true, false) as CheckButton
	_check(ck != null and ck.text == "Chế độ Dễ", "main-menu settings: EasyModeCheck 'Chế độ Dễ'")
	_check(ck != null and not ck.button_pressed, "starts unchecked on Thường")
	if ck:
		ck.button_pressed = true   # emits toggled -> set_easy_mode(true) -> save
	_check(Difficulty.easy and Difficulty.id() == "easy", "checking it sets Dễ")
	var cfg := ConfigFile.new()
	_check(cfg.load(TMP) == OK and String(cfg.get_value("gameplay", "difficulty", "")) == "easy", "saved gameplay/difficulty = easy to the temp file")
	Difficulty.set_easy(false)
	gfx.call("load_settings")
	_check(Difficulty.easy, "load_settings restores Dễ")
	# compact row (pause): joins the art style row
	var pause := VBoxContainer.new()
	root.add_child(pause)
	gfx.call("build_style_settings", pause)
	gfx.call("build_story_settings", pause, true)
	var row: Node = pause.find_child("ArtStyleRow", false, false)
	var ck2: CheckButton = pause.find_child("EasyModeCheck", true, false) as CheckButton
	_check(ck2 != null and row != null and ck2.get_parent() == row, "pause settings: EasyModeCheck in the art style row")
	_check(ck2 != null and ck2.button_pressed, "the pause check shows Dễ")
	Difficulty.set_easy(false)
	gfx.call("sync_style_settings", pause)
	_check(ck2 != null and not ck2.button_pressed and not Difficulty.easy, "sync follows Thường without emitting")
	if ck2:
		ck2.button_pressed = false
		ck2.button_pressed = true
		ck2.button_pressed = false
	cfg = ConfigFile.new()
	_check(cfg.load(TMP) == OK and String(cfg.get_value("gameplay", "difficulty", "")) == "normal", "unchecking saves normal")
	# restore
	full.queue_free()
	pause.queue_free()
	gfx.set("settings_path", path0)
	Difficulty.set_easy(easy0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("SUCCESS test_difficulty_ui")
		quit(0)
	else:
		print("FAILED test_difficulty_ui: %d" % fails.size())
		quit(1)
