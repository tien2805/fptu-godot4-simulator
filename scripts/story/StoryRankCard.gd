# File: res://scripts/story/StoryRankCard.gd
# Wave 3 results card (plan docs/superpowers/plans/2026-10-30-w3-shared.md T8): StoryMission.finish shows it for a ranked
# beat before `done` is emitted (so before the beat's "after" cinematic and the next beat, after a lair mission's short
# replay). Plain text only: the big letter ("S" / "A" / "B" / "C", no star glyphs), the beat title, one line per criterion
# with its value (StoryRank.evaluate lines), "Kỷ lục: A" when an earlier best exists ("Kỷ lục mới" when this run beats it),
# the skip hint, and a short synthesized cue per letter (an SFX: a rising triad for S ... a sagging two-note for C).
# It holds HOLD_S real seconds (Time ticks: a leftover slow motion never stretches it), skippable with [E], [Enter] or a
# click; it processes while the tree is paused. closed fires once.
# skip_all (static): no card at all. It defaults to true on a headless run so the existing story tests keep their flow;
# test_story_rank sets it false to check the card. A mission running `manual` / `manual_replay` (tests) shows the card but
# does not hold `done` for it.
class_name StoryRankCard
extends CanvasLayer

signal closed

const HOLD_S: float = 2.5
const LETTER_COLS: Dictionary = {"S": Color("#FFD23F"), "A": Color("#7CFF6B"), "B": Color("#5CC8FF"), "C": Color("#B8B4C8")}
const T_TITLE: String = "KẾT QUẢ"
const T_BEST: String = "Kỷ lục: %s"
const T_NEW_BEST: String = "Kỷ lục mới"
const T_SKIP: String = "[E] / [Enter] bỏ qua"
const CUE_DB: float = -6.0

static var skip_all: bool = DisplayServer.get_name() == "headless"
static var _cue_streams: Dictionary = {}

var letter: String = ""
var title_text: String = ""
var best_text: String = ""
var line_texts: Array[String] = []
var hold_left: float = HOLD_S
var is_open: bool = false
var manual: bool = false
var cue_player: AudioStreamPlayer = null
var _t0_ms: int = 0


## A card for evaluation `ev` (StoryRank.evaluate) of the beat titled `title`; `best_before` = the best letter recorded
## before this run ("" = none). Add it to the tree to show it.
static func make(ev: Dictionary, title: String, best_before: String) -> StoryRankCard:
	var c := StoryRankCard.new()
	c.name = "StoryRankCard"
	c.letter = String(ev.get("letter", ""))
	c.title_text = title
	for l: Variant in ev.get("lines", []):
		var d: Dictionary = l
		c.line_texts.append("%s: %s" % [String(d["label"]), String(d["value"])])
	if best_before != "":
		c.best_text = T_NEW_BEST if StoryRank.better(c.letter, best_before) else T_BEST % best_before
	return c


## Every string the card can show (tests: plain text).
func texts() -> Array[String]:
	var out: Array[String] = [T_TITLE, letter, title_text, best_text, T_SKIP, T_NEW_BEST, T_BEST % "A"]
	out.append_array(line_texts)
	return out


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.01, 0.06, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = -230.0
	box.offset_bottom = 230.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_add(box, T_TITLE, 22, Color("#F4F1FF"))
	_add(box, title_text, 18, Color(0.85, 0.85, 0.92))
	var big: Label = _add(box, letter, 150, LETTER_COLS.get(letter, Color.WHITE))
	big.name = "Letter"
	big.add_theme_font_override("font", CombatHUD.font())
	for s: String in line_texts:
		_add(box, s, 20, Color.WHITE)
	if best_text != "":
		_add(box, best_text, 18, Color("#FFD23F") if best_text == T_NEW_BEST else Color(0.8, 0.8, 0.88))
	_add(box, T_SKIP, 14, Color(0.7, 0.7, 0.78))
	cue_player = AudioStreamPlayer.new()
	cue_player.name = "Cue"
	cue_player.bus = WeaponAudio.bus()
	cue_player.volume_db = CUE_DB
	cue_player.stream = card_cue(letter)
	add_child(cue_player)
	cue_player.play()
	is_open = true
	hold_left = HOLD_S
	_t0_ms = Time.get_ticks_msec()


func _add(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#1B0F33"))
	l.add_theme_constant_override("outline_size", 8 if size < 60 else 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(_delta: float) -> void:
	if not is_open or manual:
		return
	hold_left = HOLD_S - float(Time.get_ticks_msec() - _t0_ms) / 1000.0
	if hold_left <= 0.0:
		skip()


## Tests: advance the hold by dt seconds (with manual = true the card never closes on its own clock).
func step(dt: float) -> void:
	if not is_open:
		return
	hold_left -= dt
	if hold_left <= 0.0:
		skip()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var go: bool = false
	if event is InputEventKey:
		var k: InputEventKey = event
		go = k.pressed and not k.echo and (k.physical_keycode == KEY_E or k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		go = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if go:
		get_viewport().set_input_as_handled()
		skip()


## Closes now (a key, a click, the hold running out): closed fires once, the card frees itself.
func skip() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()
	queue_free()


## The short synthesized cue of a letter (an SFX through the A1 voice helpers, cached; no music).
static func card_cue(l: String) -> AudioStream:
	if _cue_streams.has(l):
		return _cue_streams[l]
	var notes: Array = {"S": [523.0, 659.0, 784.0, 1047.0], "A": [523.0, 784.0], "B": [587.0], "C": [392.0, 330.0]}.get(l, [440.0])
	var buf := PackedFloat32Array()
	for f: Variant in notes:
		var hz: float = float(f)
		var bend: float = hz * (0.94 if l == "C" else 1.0)
		buf.append_array(CineAudio._mix([CineAudio._tone(0.13, hz, bend, 0.32, 5.0), CineAudio._tone(0.13, hz * 2.0, bend * 2.0, 0.08, 7.0)]))
	var st: AudioStream = CineAudio._to_wav(buf)
	_cue_streams[l] = st
	return st
