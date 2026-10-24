# File: res://tests/test_character_creator.gd
# Headless test of the character creator (spec A2-D5, A2-D16): the scene loads with six rows and three buttons, the model
# is the rigged "player" preset on the turntable, sex switches the hair list, every value change rebuilds only the preview
# (new model, same UI nodes), keyboard ↑↓ / ←→, randomize stays inside the tables, the name rules (trim, default "Bạn",
# 16 characters), the face variant reaches the PS2 head, and confirm stores the pick in StoryDirector (temp save, no scene
# change) with the outfit fixed.
# Run:  godot --headless --path . --script tests/test_character_creator.gd
extends SceneTree

const TMP: String = "user://test_creator_save.cfg"
var fails: Array[String] = []
var frames: int = 0
var cc: Node3D
var sd: Node


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST CHARACTER CREATOR ---")
	sd = root.get_node_or_null("StoryDirector")
	sd.set("save_path", TMP)
	sd.set("nav_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	cc = (load("res://scenes/story/CharacterCreator.tscn") as PackedScene).instantiate()
	root.add_child(cc)
	current_scene = cc


func _process(_d: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	_run()
	sd.call("reset_state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	if fails.is_empty():
		print("✅ SUCCESS: CHARACTER CREATOR (rows, preview rebuild, keyboard, randomize, name rules, confirm)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true


func _run() -> void:
	var rows: Array = cc.get("ROWS")
	_check(rows.size() == 6 and rows == ["sex", "name", "face", "hair", "hair_color", "skin"], "six rows in spec order")
	for k: String in rows:
		_check(cc.find_child("Row_" + k, true, false) != null, "row %s built" % k)
	for b: String in ["btn_random", "btn_confirm", "btn_back"]:
		_check(cc.get(b) is Button, "button %s" % b)
	_check((cc.get("btn_random") as Button).text == "🎲 Ngẫu nhiên" and (cc.get("btn_confirm") as Button).text == "✔ Bắt đầu" and (cc.get("btn_back") as Button).text == "✖ Về menu", "button captions")
	_check(cc.has_meta("no_pause"), "creator scene opts out of the pause menu")
	var pv: Node3D = cc.get("preview")
	_check(pv != null and pv.get_parent() == cc.get("turntable") and bool(pv.get_meta("rigged", false)), "rigged preview on the turntable")
	var bo: Dictionary = cc.call("builder_opts")
	_check(String(bo["preset"]) == "player" and bool(bo["backpack"]), "outfit fixed: preset player with backpack")
	# rebuild only the preview
	var panel: Node = cc.get("panel")
	var n0: int = int(cc.get("rebuilds"))
	var id0: int = pv.get_instance_id()
	cc.call("set_value", 0, 1)
	var pv1: Node3D = cc.get("preview")
	var o: Dictionary = cc.get("opts")
	_check(bool(o["female"]) and String(o["hair_style"]) in cc.get("HAIR_F"), "Nữ switches to the female hair list (%s)" % String(o["hair_style"]))
	_check(int(cc.get("rebuilds")) == n0 + 1 and pv1.get_instance_id() != id0 and cc.get("panel") == panel, "a change rebuilds only the preview")
	cc.call("set_value", 0, 1)
	_check(int(cc.get("rebuilds")) == n0 + 1, "setting the same value does not rebuild")
	# keyboard
	cc.call("set_row", 0)
	cc.call("handle_key", KEY_DOWN)
	cc.call("handle_key", KEY_DOWN)
	_check(int(cc.get("row")) == 2, "↓↓ moves to Khuôn mặt")
	var v0: int = int(o["variant"])
	cc.call("handle_key", KEY_RIGHT)
	_check(int((cc.get("opts") as Dictionary)["variant"]) == (v0 + 1) % 3, "→ next face variant")
	cc.call("handle_key", KEY_LEFT)
	cc.call("handle_key", KEY_LEFT)
	_check(int((cc.get("opts") as Dictionary)["variant"]) == posmod(v0 - 1, 3), "← wraps the face variant")
	cc.call("handle_key", KEY_UP)
	_check(int(cc.get("row")) == 1, "↑ to Tên")
	# randomize
	for s: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		cc.call("randomize_opts", s)
		var r: Dictionary = cc.get("opts")
		var hl: Array = cc.get("HAIR_F") if bool(r["female"]) else cc.get("HAIR_M")
		_check(String(r["hair_style"]) in hl and int(r["variant"]) in [0, 1, 2] and int(r["hair_color"]) >= 0
			and int(r["hair_color"]) < CharacterBuilder.HAIR_COLORS.size() and int(r["skin"]) >= 0 and int(r["skin"]) < CharacterBuilder.SKIN_TONES.size(),
			"randomize %d stays in the tables: %s" % [s, str(r)])
	# name rules
	var cs: Script = cc.get_script()
	_check(String(cs.call("clean_name", "   ")) == "Bạn" and String(cs.call("clean_name", "")) == "Bạn", "empty name -> Bạn")
	_check(String(cs.call("clean_name", "  Minh  ")) == "Minh", "name trimmed")
	_check(String(cs.call("clean_name", "Nguyễn Văn Thành Long")).length() <= 16, "name capped at 16 characters")
	_check((cc.get("name_edit") as LineEdit).max_length == 16, "LineEdit max 16")
	# the face variant reaches the PS2 head (vice style): same pick, two variants -> two face textures
	if CharacterBuilder.ps2:
		var a: Node3D = CharacterBuilder.build({"preset": "player", "rigged": true, "seed": 2805, "variant": 0, "female": false, "skin": 1})
		var b: Node3D = CharacterBuilder.build({"preset": "player", "rigged": true, "seed": 2805, "variant": 2, "female": false, "skin": 1})
		var ta: Texture2D = _face_tex(a)
		var tb: Texture2D = _face_tex(b)
		var k: String = CharacterBuilder.SKIN_KEYS[1]
		_check(ta != null and ta == CharacterBuilder._tex("char_ps2_face_%sm0.png" % k) and tb == CharacterBuilder._tex("char_ps2_face_%sm2.png" % k),
			"variant picks the PS2 face atlas (0 / 2)")
		a.free()
		b.free()
	# confirm
	cc.call("randomize_opts", 11)
	(cc.get("name_edit") as LineEdit).text = "  Khánh An  "
	var pick: Dictionary = (cc.get("opts") as Dictionary).duplicate()
	cc.call("confirm")
	var p: Dictionary = sd.get("protagonist")
	_check(bool(sd.get("active")) and String(p["name"]) == "Khánh An", "confirm starts the story with the trimmed name")
	for k2: String in ["female", "variant", "hair_style", "hair_color", "skin"]:
		_check(str(p.get(k2)) == str(pick[k2]), "protagonist %s stored" % k2)
	_check(FileAccess.file_exists(TMP) and String(sd.get("last_nav")) == "roam", "autosave written, story free roam requested")
	var po: Dictionary = sd.call("protagonist_opts")
	_check(String(po["preset"]) == "player" and int(po["variant"]) == int(pick["variant"]), "protagonist opts for every model")


func _face_tex(root_n: Node) -> Texture2D:
	for n: Node in root_n.find_children("*", "MeshInstance3D", true, false):
		var m: Material = (n as MeshInstance3D).material_override
		if m is StandardMaterial3D and bool(m.get_meta("ps2_face", false)):
			return (m as StandardMaterial3D).albedo_texture
	return null
