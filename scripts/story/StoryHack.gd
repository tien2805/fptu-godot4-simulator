# File: res://scripts/story/StoryHack.gd
# The Day 5 typing battle (spec C-D8 beat 6): a story mode of the Stage 6 typing engine (Màn 6 "Capstone 23:59"), on the
# same rules through TypingCore: process names of "Lọ Thần 9.0" fall down four lanes of a terminal; type a name to kill
# the process (the lowest live one with that prefix is locked; damage = length x 6 x the combo multiplier, x2 from 6 kills
# in a row, x3 from 12). The tool's integrity (max_hp) falls with every kill; at 0 the final command "sudo rm -rf lothan"
# appears in the middle: typing it wipes the tool (`won`). A process that reaches the bottom leaks the exam answers
# ("RÒ RỈ"): the combo resets, MAX_LEAKS leaks = `lost`. A typo resets the combo. Backspace deletes, Esc clears.
# Plain text only (no emoji). Runs on _process (real time) unless `manual` (tests: step(dt)); type_text(s) types for tests.
# The player's controls are off while it is open (MissionHack); it reads key events and consumes them.
class_name StoryHack
extends CanvasLayer

signal won
signal lost
signal killed(word: String)

const LANES: int = 4
const MAX_HP: float = 720.0
const MAX_LEAKS: int = 4
const FINAL_COMMAND: String = "sudo rm -rf lothan"
const WORDS: Array = [
	["cheatd", "proxy", "keylog", "hook", "spy", "leak", "bot", "tool"],
	["autofill", "backdoor", "ghostcam", "earbud", "inject", "sniffer", "lothan9", "relay"],
	["rootkit", "screencap", "answersync", "darknet", "mirror", "deepfake", "keystroke", "phantom"],
]
const SPAWN_GAP: Array[float] = [1.6, 1.2, 0.9]
const FALL_S: Array[float] = [7.0, 5.6, 4.4]          # seconds from the top to the bottom
const WAVE_HP: Array[float] = [0.66, 0.33]             # integrity fractions where waves 2 and 3 start
const PANEL := Vector2(940.0, 540.0)
const GREEN := Color("#3BFF7A")
const RED := Color("#FF4A5A")
const AMBER := Color("#FFC24A")
const INK := Color("#D8FFE4")

var manual: bool = false
var active: bool = false
var hp: float = MAX_HP
var leaks: int = 0
var combo: int = 0
var max_combo: int = 0
var typos: int = 0
var kills: int = 0
var typed: String = ""
var locked: Dictionary = {}
var bullets: Array[Dictionary] = []
var final_bullet: Dictionary = {}
var spawn_t: float = 0.8
var t: float = 0.0
var rng := RandomNumberGenerator.new()
var panel: PanelContainer
var arena: Control
var hp_bar: ProgressBar
var hp_label: Label
var leak_label: Label
var typing_label: Label
var log_label: Label
var _last_us: int = 0


func _init() -> void:
	layer = 6
	name = "StoryHack"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	visible = false


## Opens the terminal and starts (seed: the order of the processes).
func start(seed_val: int = 5) -> void:
	rng.seed = seed_val
	reset()
	active = true
	visible = true
	_last_us = Time.get_ticks_usec()


## Back to a fresh run (a retry from the fail card).
func reset() -> void:
	for b: Dictionary in bullets:
		_free_node(b)
	_free_node(final_bullet)
	bullets.clear()
	final_bullet = {}
	hp = MAX_HP
	leaks = 0
	combo = 0
	typos = 0
	kills = 0
	typed = ""
	locked = {}
	spawn_t = 0.8
	t = 0.0
	active = true
	_log("Đang kết nối tới Lọ Thần 9.0...")
	_refresh()


func stop() -> void:
	active = false
	visible = false


func wave() -> int:
	var f: float = hp / MAX_HP
	if f > WAVE_HP[0]:
		return 1
	return 2 if f > WAVE_HP[1] else 3


func mult() -> int:
	return TypingCore.mult(combo)


# ---------------------------------------------------------------------------
func _process(_d: float) -> void:
	if manual or not active:
		return
	var now: int = Time.get_ticks_usec()
	step(minf(float(now - _last_us) / 1e6, 0.1))
	_last_us = now


func step(dt: float) -> void:
	if not active:
		return
	t += dt
	if final_bullet.is_empty():
		spawn_t -= dt
		if spawn_t <= 0.0:
			var w: int = wave()
			spawn_t = SPAWN_GAP[w - 1] * rng.randf_range(0.85, 1.15)
			_spawn(w)
	var fall: float = 1.0 / FALL_S[wave() - 1]
	for b: Dictionary in bullets:
		if bool(b["dead"]):
			continue
		b["y"] = float(b["y"]) + fall * dt
		if float(b["y"]) >= 1.0:
			_leak(b)
	var i: int = bullets.size() - 1
	while i >= 0:
		if bool(bullets[i]["dead"]):
			bullets.remove_at(i)
		i -= 1
	_layout()


func _spawn(w: int) -> void:
	var pool: Array = WORDS[w - 1]
	var word: String = String(pool[rng.randi() % pool.size()])
	for attempt: int in 4:   # no two live processes with the same first letter (Stage 6 rule)
		var clash: bool = false
		for b: Dictionary in bullets:
			if not bool(b["dead"]) and String(b["word"])[0] == word[0]:
				clash = true
		if not clash:
			break
		word = String(pool[rng.randi() % pool.size()])
	var b2: Dictionary = {"word": word, "lane": rng.randi() % LANES, "y": 0.0, "dead": false}
	b2["node"] = _make_node(word, false)
	bullets.append(b2)


func _alive(b: Dictionary) -> bool:
	return not b.is_empty() and not bool(b.get("dead", false))


## Types one character (lower case). Returns "lock" | "kill" | "typo" | "won".
func type_char(ch: String) -> String:
	if not active:
		return "none"
	var cand: String = typed + ch.to_lower()
	if not locked.is_empty() and _alive(locked) and String(locked["word"]).begins_with(cand):
		typed = cand
	else:
		var pool: Array = bullets.duplicate()
		if not final_bullet.is_empty():
			pool.append(final_bullet)
		var found: Dictionary = TypingCore.find_prefix(pool, cand, _alive)
		if found.is_empty():
			typos += 1
			combo = 0
			typed = ""
			locked = {}
			_log("Lệnh sai! Combo về 0")
			_refresh()
			return "typo"
		locked = found
		typed = cand
	var r: String = "lock"
	if typed == String(locked["word"]):
		r = _kill(locked)
		typed = ""
		locked = {}
	_refresh()
	return r


func type_text(s: String) -> String:
	var last: String = "none"
	for k: int in s.length():
		last = type_char(s.substr(k, 1))
	return last


func _kill(b: Dictionary) -> String:
	b["dead"] = true
	_free_node(b)
	if b == final_bullet:
		final_bullet = {}
		active = false
		_log("rm -rf: Lọ Thần 9.0 đã bị xóa sạch!")
		won.emit()
		return "won"
	combo += 1
	max_combo = maxi(max_combo, combo)
	kills += 1
	var dmg: int = TypingCore.damage(String(b["word"]), true, mult())
	hp = maxf(0.0, hp - float(dmg))
	_log("kill %s  (-%d, x%d)" % [String(b["word"]), dmg, mult()])
	killed.emit(String(b["word"]))
	if hp <= 0.0 and final_bullet.is_empty():
		for o: Dictionary in bullets:
			o["dead"] = true
			_free_node(o)
		final_bullet = {"word": FINAL_COMMAND, "lane": -1, "y": 0.4, "dead": false}
		final_bullet["node"] = _make_node(FINAL_COMMAND, true)
		_log("Hết tiến trình! Gõ lệnh cuối để xóa tool")
	return "kill"


func _leak(b: Dictionary) -> void:
	b["dead"] = true
	_free_node(b)
	if b == locked:
		locked = {}
		typed = ""
	leaks += 1
	combo = 0
	_log("RÒ RỈ! %s gửi đề ra ngoài (%d/%d)" % [String(b["word"]), leaks, MAX_LEAKS])
	_refresh()
	if leaks >= MAX_LEAKS:
		active = false
		lost.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not visible or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed:
		get_viewport().set_input_as_handled()
		return
	match k.physical_keycode:
		KEY_ESCAPE:
			return   # the pause menu
		KEY_BACKSPACE:
			if typed.length() > 0:
				typed = typed.substr(0, typed.length() - 1)
				var pool: Array = bullets.duplicate()
				if not final_bullet.is_empty():
					pool.append(final_bullet)
				locked = TypingCore.find_prefix(pool, typed, _alive) if typed != "" else {}
			_refresh()
		KEY_DELETE:
			typed = ""
			locked = {}
			_refresh()
		_:
			if not k.echo and k.unicode >= 32 and k.unicode < 127 and (k.unicode != 32 or not final_bullet.is_empty()):
				type_char(String.chr(k.unicode))
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.name = "Terminal"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL.x * 0.5
	panel.offset_right = PANEL.x * 0.5
	panel.offset_top = -PANEL.y * 0.5
	panel.offset_bottom = PANEL.y * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.05, 0.02, 0.96)
	sb.border_color = GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_label("LỌ THẦN 9.0 · TIẾN TRÌNH ĐANG CHẠY · gõ tên tiến trình để kill", 18, GREEN))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	hp_label = _label("", 16, INK)
	top.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(360.0, 16.0)
	hp_bar.max_value = 100.0
	hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = RED
	hp_bar.add_theme_stylebox_override("fill", fill)
	top.add_child(hp_bar)
	leak_label = _label("", 16, AMBER)
	top.add_child(leak_label)
	arena = Control.new()
	arena.name = "Arena"
	arena.custom_minimum_size = Vector2(PANEL.x - 32.0, 340.0)
	arena.clip_contents = true
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(arena)
	for i: int in LANES - 1:
		var sep := ColorRect.new()
		sep.color = Color(0.2, 1.0, 0.45, 0.12)
		sep.size = Vector2(2.0, 340.0)
		sep.position = Vector2((PANEL.x - 32.0) / LANES * float(i + 1), 0.0)
		arena.add_child(sep)
	var floor_line := ColorRect.new()
	floor_line.color = Color(1.0, 0.3, 0.35, 0.6)
	floor_line.size = Vector2(PANEL.x - 32.0, 2.0)
	floor_line.position = Vector2(0.0, 338.0)
	arena.add_child(floor_line)
	typing_label = _label("", 22, AMBER)
	vb.add_child(typing_label)
	log_label = _label("", 14, Color(0.6, 0.85, 0.65))
	vb.add_child(log_label)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_node(word: String, final: bool) -> Label:
	var l := _label(word, 26 if final else 20, AMBER if final else INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.04, 0.06, 0.95) if not final else Color(0.05, 0.2, 0.08, 0.98)
	sb.border_color = RED if not final else GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	l.add_theme_stylebox_override("normal", sb)
	arena.add_child(l)
	return l


func _free_node(b: Dictionary) -> void:
	if b.has("node") and is_instance_valid(b["node"]):
		(b["node"] as Node).queue_free()


func _layout() -> void:
	var w: float = arena.size.x if arena.size.x > 1.0 else PANEL.x - 32.0
	var lane_w: float = w / LANES
	for b: Dictionary in bullets:
		var n: Label = b.get("node")
		if n and is_instance_valid(n):
			n.position = Vector2(float(b["lane"]) * lane_w + lane_w * 0.5 - n.size.x * 0.5, float(b["y"]) * 300.0)
			var k: int = typed.length() if b == locked else 0
			n.text = String(b["word"]).to_upper().substr(0, k) + String(b["word"]).substr(k)
	if not final_bullet.is_empty():
		var nf: Label = final_bullet.get("node")
		if nf and is_instance_valid(nf):
			nf.position = Vector2(w * 0.5 - nf.size.x * 0.5, 130.0)
			var k2: int = typed.length() if final_bullet == locked else 0
			nf.text = FINAL_COMMAND.to_upper().substr(0, k2) + FINAL_COMMAND.substr(k2)


func _refresh() -> void:
	if hp_label == null:
		return
	hp_label.text = "Lọ Thần 9.0: %d%%" % int(ceil(hp / MAX_HP * 100.0))
	hp_bar.value = hp / MAX_HP * 100.0
	leak_label.text = "Rò rỉ: %d / %d · Combo %d (x%d)" % [leaks, MAX_LEAKS, combo, mult()]
	var rest: String = String(locked["word"]).substr(typed.length()) if not locked.is_empty() and _alive(locked) else ""
	typing_label.text = "> %s_%s" % [typed, rest]


func _log(text: String) -> void:
	if log_label:
		log_label.text = text
