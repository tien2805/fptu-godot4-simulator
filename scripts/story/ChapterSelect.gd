# File: res://scripts/story/ChapterSelect.gd
# "CHỌN CẢNH" screen (plan 2026-10-26-chapter-select.md): two tabs over the StoryChapters records.
#   CHỌN CẢNH: the replayable beats grouped by day ("Ngày 0 · Phòng 311"); a day with nothing unlocked is hidden, a locked
#     beat of an open day reads "???", a beat reached before the chapter select existed without a snapshot is disabled with
#     "Chơi tới cảnh này một lần để mở". Picking one asks "Tua về '<tên cảnh>'? ..." then StoryChapters.rewind (backup,
#     snapshot as the save, the story continues like TIẾP TỤC). "QUAY VỀ TIẾN ĐỘ TRƯỚC KHI TUA" (only with a backup) asks
#     too, then StoryChapters.restore_backup.
#   XEM LẠI PHIM: the story cinematics by day; an unlocked one plays in StoryGalleryPlayer, which comes back to this tab.
#   KẾT THÚC (w4-endings): the six endings; a reached one replays its whole sequence (StoryGalleryPlayer.queue), others "???".
# Wave 3: a ranked beat with a best rank reads "<tên cảnh> · Hạng A" (plain text, the same row style).
# QUAY LẠI / Esc: the main menu, or the story itself when the screen was opened from the pause menu (from_story).
# Mouse and keyboard (focus on the buttons, the list scrolls to the focused row). No pause menu here (meta no_pause).
class_name ChapterSelect
extends Control

## GameFX through its script (statics) and get_node_or_null (the autoload): a class_name script cannot name the autoload,
## or every script that names ChapterSelect fails to compile under --script.
const GameFXScript = preload("res://scripts/GameFX.gd")
const SCENE: String = "res://scenes/story/ChapterSelect.tscn"
const GALLERY_SCENE: String = "res://scenes/story/StoryGalleryPlayer.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const RESTORED_FINISHED_LINE: String = "Đã khôi phục bản lưu. Cốt truyện đó đã kết thúc, chọn một cảnh để chơi lại."
const PINK := Color("#FF4FA3")
const CYAN := Color("#3FF2FF")
const MUTED := Color("#7F8C8D")
const TEXT := Color("#F4F5F6")
const REWIND_NOTE: String = "Tiến độ hiện tại được lưu lại, có thể quay về."
const RESTORE_TITLE: String = "Quay về tiến độ trước khi tua?"
const RESTORE_NOTE: String = "Tiến độ chơi từ lúc tua tới giờ sẽ được thay bằng bản lưu trước khi tua."

## Set by StageManager.go_to_chapter_select (pause menu in story mode): QUAY LẠI resumes the story.
static var from_story: bool = false
## Tab shown when the screen opens ("chapters" | "gallery" | "endings"); StoryGalleryPlayer sets it on its way back.
static var open_tab: String = "chapters"

## false (tests): navigation is recorded in last_nav instead of changing scenes.
var nav_enabled: bool = true
var last_nav: String = ""
var tab: String = "chapters"
var list_box: VBoxContainer
var scroll: ScrollContainer
var tab_buttons: Dictionary = {}
var restore_btn: Button
var back_btn: Button
var empty_label: Label
## A short plain line under the list (Phase C: the finished story restored).
var notice_label: Label
var confirm_dim: ColorRect
var confirm_title: Label
var confirm_note: Label
var confirm_yes: Button
var confirm_no: Button
var _pending: String = ""   # beat id to rewind to, or "restore"


func _ready() -> void:
	set_meta("no_pause", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_build()
	_fx("music_play", ["menu", 0.2])
	show_tab(open_tab)
	open_tab = "chapters"


func _fx(method: String, args: Array) -> void:
	var fx: Node = get_node_or_null("/root/GameFX")
	if fx and fx.has_method(method):
		fx.callv(method, args)


func _director() -> Node:
	return get_node_or_null("/root/StoryDirector")


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _button(text: String, accent: Color = PINK) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 17)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", GameFXScript.make_panel_style(Color(accent, 0.5), Color(0.05, 0.07, 0.12, 0.88), 10))
	b.add_theme_stylebox_override("hover", GameFXScript.make_panel_style(accent, Color(0.12, 0.08, 0.2, 0.96), 10))
	b.add_theme_stylebox_override("focus", GameFXScript.make_panel_style(CYAN, Color(0.12, 0.08, 0.2, 0.96), 10))
	b.add_theme_stylebox_override("pressed", GameFXScript.make_panel_style(GameFXScript.FPT_YELLOW, Color(0.18, 0.1, 0.03, 0.98), 10))
	b.add_theme_stylebox_override("disabled", GameFXScript.make_panel_style(Color(MUTED, 0.35), Color(0.04, 0.05, 0.08, 0.7), 10))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GameFXScript.FPT_YELLOW)
	b.add_theme_color_override("font_focus_color", GameFXScript.FPT_YELLOW)
	b.add_theme_color_override("font_disabled_color", MUTED)
	return b


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.07, 1.0)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 64)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var title: Label = GameFXScript.make_label("CHỌN CẢNH", 38, PINK, HORIZONTAL_ALIGNMENT_LEFT)
	title.add_theme_font_override("font", GameFXScript.vice_font(0.9, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("#2A0E3A"))
	col.add_child(title)
	col.add_child(GameFXScript.make_label("Tua cốt truyện về một cảnh đã chơi, hoặc xem lại các đoạn phim đã mở.", 14,
		Color("#BDC3C7"), HORIZONTAL_ALIGNMENT_LEFT))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	col.add_child(tabs)
	for pair: Array in [["chapters", "CHỌN CẢNH", "TabChapters"], ["gallery", "XEM LẠI PHIM", "TabGallery"],
			["endings", "KẾT THÚC", "TabEndings"]]:
		var tb: Button = _button(String(pair[1]), CYAN)
		tb.name = String(pair[2])
		tb.custom_minimum_size = Vector2(240, 42)
		tb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.pressed.connect(show_tab.bind(String(pair[0])))
		tabs.add_child(tb)
		tab_buttons[String(pair[0])] = tb
	scroll = ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.name = "List"
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)
	empty_label = GameFXScript.make_label("", 15, Color("#BDC3C7"), HORIZONTAL_ALIGNMENT_LEFT)
	empty_label.visible = false
	col.add_child(empty_label)
	notice_label = GameFXScript.make_label("", 15, Color("#F1C40F"), HORIZONTAL_ALIGNMENT_LEFT)
	notice_label.name = "Notice"
	notice_label.visible = false
	col.add_child(notice_label)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	col.add_child(bottom)
	restore_btn = _button("QUAY VỀ TIẾN ĐỘ TRƯỚC KHI TUA", Color("#F1C40F"))
	restore_btn.name = "RestoreButton"
	restore_btn.custom_minimum_size = Vector2(400, 44)
	restore_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	restore_btn.pressed.connect(ask_restore)
	bottom.add_child(restore_btn)
	back_btn = _button("QUAY LẠI  [ESC]", MUTED)
	back_btn.name = "BackButton"
	back_btn.custom_minimum_size = Vector2(260, 44)
	back_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.pressed.connect(go_back)
	bottom.add_child(back_btn)
	_build_confirm()


func _build_confirm() -> void:
	confirm_dim = ColorRect.new()
	confirm_dim.name = "ConfirmDim"
	confirm_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_dim.color = Color(0.02, 0.02, 0.05, 0.8)
	confirm_dim.visible = false
	add_child(confirm_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_dim.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ConfirmPanel"
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", GameFXScript.make_panel_style(PINK, Color(0.06, 0.04, 0.12, 0.98), 12))
	center.add_child(panel)
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 24)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	confirm_title = GameFXScript.make_label("", 22, PINK)
	confirm_title.name = "ConfirmTitle"
	confirm_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(confirm_title)
	confirm_note = GameFXScript.make_label(REWIND_NOTE, 14, Color("#BDC3C7"))
	confirm_note.name = "ConfirmNote"
	confirm_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(confirm_note)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	v.add_child(hb)
	confirm_yes = _button("TUA VỀ", PINK)
	confirm_yes.name = "ConfirmYes"
	confirm_yes.custom_minimum_size = Vector2(220, 44)
	confirm_yes.alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_yes.pressed.connect(_on_confirm)
	hb.add_child(confirm_yes)
	confirm_no = _button("THÔI", MUTED)
	confirm_no.name = "ConfirmNo"
	confirm_no.custom_minimum_size = Vector2(220, 44)
	confirm_no.alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_no.pressed.connect(close_confirm)
	hb.add_child(confirm_no)


## Rebuilds the list for tab "chapters", "gallery" or "endings" and puts the keyboard focus on its first usable row.
func show_tab(which: String) -> void:
	tab = which if which in ["gallery", "endings"] else "chapters"
	for k: Variant in tab_buttons.keys():
		var on: bool = String(k) == tab
		(tab_buttons[k] as Button).add_theme_color_override("font_color", GameFXScript.FPT_YELLOW if on else TEXT)
	for c: Node in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	if tab == "endings":
		_show_endings()
		return
	var rows: Array[Dictionary] = StoryChapters.chapters() if tab == "chapters" else StoryChapters.gallery()
	var open_days: Array[int] = []
	for r: Dictionary in rows:
		var unlocked: bool = (String(r["state"]) != "locked") if tab == "chapters" else bool(r["unlocked"])
		if unlocked and not (int(r["day"]) in open_days):
			open_days.append(int(r["day"]))
	var first: Button = null
	var day_shown: int = -1
	for r2: Dictionary in rows:
		var d: int = int(r2["day"])
		if not (d in open_days):
			continue
		if d != day_shown:
			day_shown = d
			var head: Label = GameFXScript.make_label(StoryChapters.day_header(d), 19, CYAN, HORIZONTAL_ALIGNMENT_LEFT)
			head.name = "Day%d" % d
			list_box.add_child(head)
		var b: Button = _row(r2)
		list_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	empty_label.visible = open_days.is_empty()
	empty_label.text = "Chưa có cảnh nào. Chơi cốt truyện để mở các cảnh." if tab == "chapters" \
		else "Chưa có đoạn phim nào. Chơi cốt truyện để mở các đoạn phim."
	restore_btn.visible = StoryChapters.has_backup(_director())
	var focus: Button = first if first else (tab_buttons[tab] as Button)
	focus.call_deferred("grab_focus")


func _row(r: Dictionary) -> Button:
	var b: Button
	if tab == "chapters":
		var state: String = String(r["state"])
		b = _button("???" if state == "locked" else String(r["title"]))
		b.name = "Chapter_" + String(r["id"])
		if state == "need_play":
			b.text = "%s · %s" % [String(r["title"]), StoryChapters.NEED_PLAY_LINE]
		if state != "locked" and String(r.get("rank", "")) != "":
			b.text += " · " + rank_text(String(r["rank"]))
		b.disabled = state != "open"
		if state == "open":
			b.pressed.connect(ask_rewind.bind(String(r["id"])))
	else:
		var on: bool = bool(r["unlocked"])
		b = _button(String(r["title"]) if on else "???", CYAN)
		b.name = "Cine_" + String(r["slot"])
		b.disabled = not on
		if on:
			b.pressed.connect(play_cine.bind(String(r["slot"])))
	if b.disabled:
		b.focus_mode = Control.FOCUS_NONE   # the arrow keys skip rows that cannot be picked
	return b


func row_button(id: String) -> Button:
	var pre: String = {"chapters": "Chapter_", "gallery": "Cine_", "endings": "Ending_"}.get(tab, "Chapter_")
	return list_box.get_node_or_null(pre + id) as Button


## KẾT THÚC: one row per ending ("Kết A: <tên>" + its line when reached, "???" otherwise), no day headers.
func _show_endings() -> void:
	var first: Button = null
	var any: bool = false
	for r: Dictionary in StoryChapters.endings():
		var on: bool = bool(r["unlocked"])
		any = any or on
		var b: Button = _button(ending_row_text(r) if on else "???", GameFXScript.FPT_YELLOW)
		b.name = "Ending_" + String(r["id"])
		b.disabled = not on
		if on:
			b.pressed.connect(play_ending.bind(String(r["id"])))
			if first == null:
				first = b
		else:
			b.focus_mode = Control.FOCUS_NONE
		list_box.add_child(b)
	empty_label.visible = not any
	empty_label.text = "Chưa mở kết thúc nào. Chơi hết cốt truyện để mở."
	restore_btn.visible = StoryChapters.has_backup(_director())
	var focus: Button = first if first else (tab_buttons[tab] as Button)
	focus.call_deferred("grab_focus")


## The title already reads "Kết X: ..." (StoryEndings.ENDINGS), so the row shows it alone.
static func ending_row_text(r: Dictionary) -> String:
	return String(r["title"])


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
## "Hạng A" (Wave 3 ranks, plain text).
static func rank_text(letter: String) -> String:
	return "Hạng %s" % letter


static func rewind_question(title: String) -> String:
	return "Tua về '%s'?" % title


func ask_rewind(id: String) -> void:
	_pending = id
	confirm_title.text = rewind_question(String(StoryMissions.beat(id).get("title", id)))
	confirm_note.text = REWIND_NOTE
	confirm_yes.text = "TUA VỀ"
	_open_confirm()


func ask_restore() -> void:
	_pending = "restore"
	confirm_title.text = RESTORE_TITLE
	confirm_note.text = RESTORE_NOTE
	confirm_yes.text = "QUAY VỀ"
	_open_confirm()


func _open_confirm() -> void:
	_fx("play_ui", ["pop", -6.0])
	confirm_dim.visible = true
	confirm_no.call_deferred("grab_focus")   # the safe default for the keyboard


func close_confirm() -> void:
	confirm_dim.visible = false
	_pending = ""
	show_tab(tab)


func _on_confirm() -> void:
	var what: String = _pending
	confirm_dim.visible = false
	_pending = ""
	var sd: Node = _director()
	var ok: bool = false
	if sd:
		ok = bool(StoryChapters.restore_backup(sd)) if what == "restore" else bool(StoryChapters.rewind(sd, what))
	if ok and what == "restore" and StoryChapters.last_restore_finished:
		notice_label.text = RESTORED_FINISHED_LINE   # the finished story is the save again: nothing to continue
		notice_label.visible = true
		_fx("play_sfx", ["success", -2.0])
		show_tab(tab)
	elif ok:
		from_story = false
		last_nav = "story"
		_fx("play_sfx", ["success", -2.0])
	else:
		show_tab(tab)


func play_cine(slot: String) -> void:
	StoryGalleryPlayer.slot = slot
	StoryGalleryPlayer.queue = []
	StoryGalleryPlayer.return_tab = "gallery"
	open_tab = "gallery"
	last_nav = "gallery:" + slot
	if nav_enabled:
		get_tree().change_scene_to_file(GALLERY_SCENE)


## A reached ending: its whole sequence (end_a then ai_true_end for A, ...) in StoryGalleryPlayer, back to KẾT THÚC.
func play_ending(x: String) -> void:
	var q: Array[String] = StoryEndings.slots(x)
	if q.is_empty():
		return
	StoryGalleryPlayer.queue = q.slice(1)
	StoryGalleryPlayer.slot = q[0]
	StoryGalleryPlayer.return_tab = "endings"
	open_tab = "endings"
	last_nav = "ending:" + x
	if nav_enabled:
		get_tree().change_scene_to_file(GALLERY_SCENE)


## QUAY LẠI: back into the story when opened from its pause menu (TIẾP TỤC path), otherwise the main menu.
func go_back() -> void:
	var sd: Node = _director()
	if from_story and sd and bool(sd.call("continue_story")):
		from_story = false
		last_nav = "story"
		return
	from_story = false
	last_nav = "menu"
	if nav_enabled:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		if confirm_dim.visible:
			close_confirm()
		else:
			go_back()
		get_viewport().set_input_as_handled()
