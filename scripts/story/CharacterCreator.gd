# File: res://scripts/story/CharacterCreator.gd
# Character creator of the story "TOOL ĐEN" (spec A2-D5): a pastel studio with the rigged protagonist on a turntable
# (mouse drag rotates it; the body plays its idle), six rows on the left (Giới tính, Tên, Khuôn mặt, Kiểu tóc, Màu tóc, Màu
# da), buttons "🎲 Ngẫu nhiên", "✔ Bắt đầu", "✖ Về menu"; keyboard ↑↓ row, ←→ value, Enter confirm, Esc back. The outfit is
# fixed (preset "player"). Every change rebuilds only the preview model. confirm() -> StoryDirector.new_story (autosave) and
# story free roam. Meta "no_pause": Esc never opens the pause menu here. Everything (studio, UI) is built in code.
class_name CharacterCreator
extends Node3D

const ROWS: Array[String] = ["sex", "name", "face", "hair", "hair_color", "skin"]
const ROW_TITLES: Dictionary = {"sex": "Giới tính", "name": "Tên", "face": "Khuôn mặt", "hair": "Kiểu tóc", "hair_color": "Màu tóc", "skin": "Màu da"}
const HAIR_M: Array[String] = ["short", "side_part", "spiky", "undercut"]
const HAIR_F: Array[String] = ["bob", "ponytail", "long", "bun"]
const HAIR_NAMES: Dictionary = {"short": "Tóc ngắn", "side_part": "Rẽ ngôi", "spiky": "Tóc dựng", "undercut": "Undercut",
	"bob": "Tóc bob", "ponytail": "Đuôi ngựa", "long": "Tóc dài", "bun": "Búi tóc"}
const NAME_MAX: int = 16
const PASTEL_BG := Color("#F6C9DD")
const PASTEL_FLOOR := Color("#BDEFE0")
const ACCENT := Color("#FF4FA3")
const MENU_SCENE: String = "res://scenes/MainMenu.tscn"

var opts: Dictionary = {"female": false, "name": "Bạn", "variant": 0, "hair_style": "short", "hair_color": 0, "skin": 1}
var row: int = 0
var preview: Node3D
var rebuilds: int = 0
var turntable: Node3D
var camera: Camera3D
var ui: CanvasLayer
var panel: PanelContainer
var name_edit: LineEdit
var row_boxes: Array[PanelContainer] = []
var value_labels: Dictionary = {}
var swatches: Dictionary = {}
var btn_random: Button
var btn_confirm: Button
var btn_back: Button
var confirmed: bool = false
var _dragging: bool = false


func _ready() -> void:
	set_meta("no_pause", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_studio()
	_build_ui()
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx:
		fx.call("upgrade_scene_visuals", self, "noon")
		if fx.has_method("music_play"):
			fx.call("music_play", "menu", 0.2)
	_force_backdrop()
	_rebuild_preview()
	_refresh_rows()


# ---------------------------------------------------------------------------
# Studio
# ---------------------------------------------------------------------------
func _build_studio() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PASTEL_BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFF1F7")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color("#FFF4E8")
	sun.shadow_enabled = true
	add_child(sun)
	var rim := OmniLight3D.new()
	rim.name = "RimLight"
	rim.position = Vector3(-1.6, 2.2, -1.4)
	rim.light_color = Color("#9FE8FF")
	rim.light_energy = 1.4
	rim.omni_range = 5.0
	add_child(rim)
	# backdrop: a tall pastel gradient wall (code-drawn GradientTexture2D) and a mint floor
	var wall := MeshInstance3D.new()
	wall.name = "Backdrop"
	var wq := QuadMesh.new()
	wq.size = Vector2(16.0, 9.0)
	wall.mesh = wq
	wall.position = Vector3(0.0, 3.5, -3.5)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var grad := Gradient.new()
	grad.set_color(0, Color("#FFB3D1"))
	grad.set_color(1, Color("#B8E4FF"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	wm.albedo_texture = gt
	wm.set_meta("vice_done", true)
	wall.material_override = wm
	add_child(wall)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	var fp := PlaneMesh.new()
	fp.size = Vector2(16.0, 10.0)
	floor_mi.mesh = fp
	var fm := StandardMaterial3D.new()
	fm.albedo_color = PASTEL_FLOOR
	fm.roughness = 0.9
	floor_mi.material_override = fm
	add_child(floor_mi)
	turntable = Node3D.new()
	turntable.name = "Turntable"
	turntable.position = Vector3(0.55, 0.0, 0.0)
	add_child(turntable)
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var dm := CylinderMesh.new()
	dm.top_radius = 0.75
	dm.bottom_radius = 0.8
	dm.height = 0.08
	disc.mesh = dm
	disc.position = Vector3(0.0, 0.04, 0.0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color("#FFFFFF")
	dmat.emission_enabled = true
	dmat.emission = ACCENT
	dmat.emission_energy_multiplier = 0.25
	disc.material_override = dmat
	turntable.add_child(disc)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 40.0
	add_child(camera)
	camera.position = Vector3(0.0, 1.25, 4.1)
	camera.look_at(Vector3(0.05, 0.95, 0.0), Vector3.UP)
	camera.make_current()


## upgrade_scene_visuals may swap the environment: keep the pastel studio background.
func _force_backdrop() -> void:
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = PASTEL_BG
		we.environment.fog_enabled = false
		we.environment.volumetric_fog_enabled = false


## The CharacterBuilder opts of the current pick (same mapping as StoryDirector.protagonist_opts).
func builder_opts() -> Dictionary:
	var o: Dictionary = StoryUtil.builder_opts(opts)
	o["name"] = "CreatorPreview"
	return o


func _rebuild_preview() -> void:
	if preview and is_instance_valid(preview):
		turntable.remove_child(preview)
		preview.queue_free()
	preview = CharacterBuilder.build(builder_opts())
	preview.position = Vector3(0.0, 0.08, 0.0)
	turntable.add_child(preview)
	rebuilds += 1


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _style_button(b: Button, accent: Color) -> void:
	b.add_theme_stylebox_override("normal", GameFX.make_panel_style(Color(accent, 0.6), Color(0.08, 0.05, 0.14, 0.88), 10))
	b.add_theme_stylebox_override("hover", GameFX.make_panel_style(accent, Color(0.16, 0.08, 0.22, 0.96), 10))
	b.add_theme_stylebox_override("focus", GameFX.make_panel_style(accent, Color(0.16, 0.08, 0.22, 0.96), 10))
	b.add_theme_stylebox_override("pressed", GameFX.make_panel_style(Color.WHITE, Color(0.3, 0.1, 0.25, 0.98), 10))
	b.add_theme_color_override("font_color", Color("#FFF4FA"))
	b.add_theme_color_override("font_hover_color", Color("#FFE15C"))


func _button(text: String, accent: Color, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(w, 40.0)
	_style_button(b, accent)
	return b


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 560.0
	for side: String in ["margin_left", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 36)
	ui.add_child(margin)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", GameFX.make_panel_style(ACCENT, Color(0.07, 0.04, 0.13, 0.9), 14))
	margin.add_child(panel)
	var pm := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pm.add_theme_constant_override(side, 20)
	panel.add_child(pm)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pm.add_child(col)
	var title: Label = GameFX.make_label("TẠO NHÂN VẬT", 34, ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	title.add_theme_font_override("font", GameFX.vice_font(0.8, 0.24))
	title.add_theme_color_override("font_outline_color", Color("#2A0E3A"))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var sub: Label = GameFX.make_label("TOOL ĐEN – 7 ngày minh oan · sinh viên FPTU, áo polo cam, quần jeans, giày trắng, ba lô đen", 13, Color("#FFD1E8"), HORIZONTAL_ALIGNMENT_LEFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	for i: int in ROWS.size():
		col.add_child(_build_row(i))
	var hint: Label = GameFX.make_label("↑↓ chọn dòng · ←→ đổi · Enter bắt đầu · kéo chuột để xoay nhân vật", 12, Color("#C9B8E8"), HORIZONTAL_ALIGNMENT_LEFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	col.add_child(hb)
	btn_random = _button("🎲 Ngẫu nhiên", Color("#3FF2FF"), 150.0)
	btn_random.pressed.connect(func() -> void: randomize_opts())
	hb.add_child(btn_random)
	btn_confirm = _button("✔ Bắt đầu", ACCENT, 150.0)
	btn_confirm.pressed.connect(confirm)
	hb.add_child(btn_confirm)
	btn_back = _button("✖ Về menu", Color("#B8A9D9"), 140.0)
	btn_back.pressed.connect(back)
	hb.add_child(btn_back)


func _build_row(i: int) -> PanelContainer:
	var key: String = ROWS[i]
	var box := PanelContainer.new()
	box.name = "Row_" + key
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			set_row(i))
	row_boxes.append(box)
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 10)
	for side2: String in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side2, 4)
	box.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	m.add_child(hb)
	var lbl: Label = GameFX.make_label(String(ROW_TITLES[key]), 16, Color("#FFF4FA"), HORIZONTAL_ALIGNMENT_LEFT)
	lbl.custom_minimum_size = Vector2(120.0, 0.0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(lbl)
	if key == "name":
		name_edit = LineEdit.new()
		name_edit.name = "NameEdit"
		name_edit.text = String(opts["name"])
		name_edit.max_length = NAME_MAX
		name_edit.placeholder_text = "Bạn"
		name_edit.custom_minimum_size = Vector2(260.0, 34.0)
		name_edit.add_theme_font_size_override("font_size", 17)
		name_edit.text_changed.connect(func(t: String) -> void: opts["name"] = t)
		name_edit.text_submitted.connect(func(_t: String) -> void: confirm())
		name_edit.focus_entered.connect(func() -> void: set_row(i))
		hb.add_child(name_edit)
		return box
	var left := _button("◀", ACCENT, 40.0)
	left.pressed.connect(func() -> void:
		set_row(i)
		step_value(-1))
	hb.add_child(left)
	if key == "hair_color" or key == "skin":
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(26.0, 26.0)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(sw)
		swatches[key] = sw
	var val: Label = GameFX.make_label("", 16, Color("#FFE15C"), HORIZONTAL_ALIGNMENT_CENTER)
	val.custom_minimum_size = Vector2(150.0 if swatches.has(key) else 184.0, 0.0)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(val)
	value_labels[key] = val
	var right := _button("▶", ACCENT, 40.0)
	right.pressed.connect(func() -> void:
		set_row(i)
		step_value(1))
	hb.add_child(right)
	return box


func _hair_list() -> Array[String]:
	return HAIR_F if bool(opts["female"]) else HAIR_M


## Index of the current value on row `r` and the number of choices.
func value_index(r: int) -> int:
	match ROWS[r]:
		"sex":
			return 1 if bool(opts["female"]) else 0
		"face":
			return int(opts["variant"])
		"hair":
			return maxi(0, _hair_list().find(String(opts["hair_style"])))
		"hair_color":
			return int(opts["hair_color"])
		"skin":
			return int(opts["skin"])
	return 0


func value_count(r: int) -> int:
	match ROWS[r]:
		"sex":
			return 2
		"face":
			return 3
		"hair":
			return _hair_list().size()
		"hair_color":
			return CharacterBuilder.HAIR_COLORS.size()
		"skin":
			return CharacterBuilder.SKIN_TONES.size()
	return 0


## Sets row r to choice idx (wraps); rebuilds the preview when the look changes.
func set_value(r: int, idx: int) -> void:
	var n: int = value_count(r)
	if n <= 0:
		return
	var v: int = posmod(idx, n)
	if v == value_index(r):
		return
	match ROWS[r]:
		"sex":
			var hi: int = value_index(ROWS.find("hair"))
			opts["female"] = v == 1
			opts["hair_style"] = _hair_list()[clampi(hi, 0, 3)]
		"face":
			opts["variant"] = v
		"hair":
			opts["hair_style"] = _hair_list()[v]
		"hair_color":
			opts["hair_color"] = v
		"skin":
			opts["skin"] = v
	_rebuild_preview()
	_refresh_rows()


func step_value(dir: int) -> void:
	set_value(row, value_index(row) + dir)


func set_row(r: int) -> void:
	row = clampi(r, 0, ROWS.size() - 1)
	if ROWS[row] == "name":
		if name_edit and not name_edit.has_focus():
			name_edit.grab_focus()
	elif name_edit and name_edit.has_focus():
		name_edit.release_focus()
	_refresh_rows()


## Random sex, face, hair and colours (the name stays). Rebuilds the preview once.
func randomize_opts(seed_v: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	opts["female"] = rng.randf() < 0.5
	opts["variant"] = rng.randi_range(0, 2)
	opts["hair_style"] = _hair_list()[rng.randi_range(0, 3)]
	opts["hair_color"] = rng.randi_range(0, CharacterBuilder.HAIR_COLORS.size() - 1)
	opts["skin"] = rng.randi_range(0, CharacterBuilder.SKIN_TONES.size() - 1)
	_rebuild_preview()
	_refresh_rows()


func _refresh_rows() -> void:
	for i: int in row_boxes.size():
		var sel: bool = i == row
		row_boxes[i].add_theme_stylebox_override("panel", GameFX.make_panel_style(ACCENT if sel else Color(1, 1, 1, 0.12),
			Color(0.3, 0.08, 0.24, 0.85) if sel else Color(0.1, 0.06, 0.16, 0.6), 8))
	if value_labels.is_empty():
		return
	(value_labels["sex"] as Label).text = "Nữ" if bool(opts["female"]) else "Nam"
	(value_labels["face"] as Label).text = "Gương mặt %d/3" % (int(opts["variant"]) + 1)
	(value_labels["hair"] as Label).text = String(HAIR_NAMES.get(String(opts["hair_style"]), String(opts["hair_style"])))
	(value_labels["hair_color"] as Label).text = "Màu %d/%d" % [int(opts["hair_color"]) + 1, CharacterBuilder.HAIR_COLORS.size()]
	(value_labels["skin"] as Label).text = "Tông %d/%d" % [int(opts["skin"]) + 1, CharacterBuilder.SKIN_TONES.size()]
	(swatches["hair_color"] as ColorRect).color = CharacterBuilder.HAIR_COLORS[int(opts["hair_color"])]
	(swatches["skin"] as ColorRect).color = CharacterBuilder.SKIN_TONES[int(opts["skin"])]


## Trimmed name, 1..16 characters, "Bạn" when empty.
static func clean_name(text: String) -> String:
	var s: String = text.strip_edges()
	if s == "":
		return "Bạn"
	return s.substr(0, NAME_MAX).strip_edges()


## "✔ Bắt đầu": stores the pick in StoryDirector (new story, autosave) and enters story free roam.
func confirm() -> void:
	if confirmed:
		return
	confirmed = true
	opts["name"] = clean_name(name_edit.text if name_edit else String(opts["name"]))
	if name_edit:
		name_edit.text = String(opts["name"])
	var sd: Node = get_node_or_null("/root/StoryDirector")
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx:
		fx.call("play_sfx", "success", -2.0)
	if sd == null:
		return
	sd.call("new_story", opts.duplicate())
	sd.call("enter_roam")


func back() -> void:
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm and sm.has_method("go_to_main_menu"):
		sm.call("go_to_main_menu")
	elif is_inside_tree():
		get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		turntable.rotation.y += (event as InputEventMouseMotion).relative.x * 0.01
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		handle_key((event as InputEventKey).physical_keycode)


## Keyboard: ↑↓ row, ←→ value, Enter confirm, Esc back. Returns true when the key was used.
func handle_key(k: int) -> bool:
	var used: bool = true
	match k:
		KEY_UP:
			set_row(row - 1)
		KEY_DOWN:
			set_row(row + 1)
		KEY_LEFT:
			if ROWS[row] != "name":
				step_value(-1)
		KEY_RIGHT:
			if ROWS[row] != "name":
				step_value(1)
		KEY_ENTER, KEY_KP_ENTER:
			confirm()
		KEY_ESCAPE:
			back()
		_:
			used = false
	if used and is_inside_tree():
		get_viewport().set_input_as_handled()
	return used


func _process(delta: float) -> void:
	if not _dragging and turntable:
		turntable.rotation.y += 0.25 * delta   # slow idle spin while the mouse is not dragging
