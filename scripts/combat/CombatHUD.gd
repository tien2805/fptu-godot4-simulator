# File: res://scripts/combat/CombatHUD.gd
# Combat HUD of the Phase B unarmed combat (B-D1), owned by PlayerCombat (which shows it while a fight runs or the player's
# HP is below full, and hides it while blocked: bike, map, cinematic). Code-drawn, plain text (no emoji or decorative
# symbols; the key glyph only in the "[E] Hạ gục" control hint), vice and classic styles like WeaponHUD:
#   - top centre: the player's HP bar with "Máu" and the number (blinks below 25 %), the control hint under it during a
#     fight;
#   - over each enemy's head (world-anchored, within 30 m, in front of the camera): its label, an HP bar and a thinner
#     stagger bar; a small lock marker over the soft-lock target; a pulsing red ring during a telegraph (0.5 s before an
#     unblockable heavy); "[E] Hạ gục" over the dazed enemy the finisher would take;
#   - an edge-of-screen marker (pointing out) for every attack on its way from an enemy behind the camera or off screen:
#     amber for a light wind-up / swing, red for a telegraphed heavy;
#   - centre popups (popup(text, colour)): "PHẢN ĐÒN", "HẠ GỤC", "PHÁ THẾ THỦ", a fight's start line, the force-unarmed line;
#   - top centre under the HP bar, while a fight runs, the boss bar (Phase C) for combat.boss: its label, a wide HP bar
#     and a tick at each of its boss_marks() (phase / howl thresholds); the boss gets no bar over its head (the bottom belongs to the hint line,
#     the stamina bar, the zone name and the story objective).
# State for tests (computed in _process, not in _draw): finisher_shown, telegraph_shown, edge_markers, popup_text,
# popup_left, boss_shown. The style (GameFX lookup) and the font are read once per frame.
class_name CombatHUD
extends CanvasLayer

const GameFXScript: Script = preload("res://scripts/GameFX.gd")
const INK := Color("#1B0F33")
const VICE_ACCENT := Color("#3FF2FF")
const CLASSIC_ACCENT := Color("#F37021")
const VICE_HP := Color("#FF3B7A")
const CLASSIC_HP := Color("#E74C3C")
const STAGGER_COL := Color("#FFC93C")
const GOLD := Color("#FFE14D")
const WARN := Color("#FF8A3D")
const TELEGRAPH := Color(1.0, 0.12, 0.1)
const BAR_SIZE := Vector2(440.0, 58.0)
const BAR_TOP: float = 18.0
const ENEMY_BAR_W: float = 70.0
const ENEMY_MAX_M: float = 30.0
const HEAD_Y: float = 2.05
const POPUP_S: float = 1.0
const LIGHT_WARN := Color("#FFB23C")
const EDGE_INSET: float = 46.0
const BOSS_SIZE := Vector2(620.0, 46.0)
const BOSS_TOP: float = 86.0             # under the player's HP bar (18 + 58 + 10)
static var _vice_cache: bool = true
static var _vice_frame: int = -1
static var _vice_font: Font = null

var combat: PlayerCombat
var bar: Control
var world: Control
var popup_label: Label
var popup_text: String = ""
var popup_left: float = 0.0
var finisher_shown: bool = false
var finisher_node: Node3D = null
## Q2 [E] prompts: "[E] Ném" under a grabbable enemy, "[E] Nhặt <tên>" over an improvised weapon in reach.
var throw_node: Node3D = null
var throw_shown: bool = false
var prop_node: ImprovisedWeapon = null
var prop_shown: bool = false
var telegraph_shown: int = 0
var popups: int = 0
var edge_markers: int = 0
var edge_pos := PackedVector2Array()
var edge_dir := PackedVector2Array()
var edge_kind := PackedInt32Array()
var boss_bar: Control
var boss_shown: bool = false


func _ready() -> void:
	layer = 1
	var w := WorldLayer.new()
	w.name = "CombatWorld"
	w.hud = self
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(w)
	world = w
	var b := HPBar.new()
	b.name = "CombatHP"
	b.hud = self
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	b.offset_left = -BAR_SIZE.x * 0.5
	b.offset_right = BAR_SIZE.x * 0.5
	b.offset_top = BAR_TOP
	b.offset_bottom = BAR_TOP + BAR_SIZE.y
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	bar = b
	var bb := BossBar.new()
	bb.name = "CombatBoss"
	bb.hud = self
	bb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bb.offset_left = -BOSS_SIZE.x * 0.5
	bb.offset_right = BOSS_SIZE.x * 0.5
	bb.offset_top = BOSS_TOP
	bb.offset_bottom = BOSS_TOP + BOSS_SIZE.y
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bb.visible = false
	add_child(bb)
	boss_bar = bb
	popup_label = Label.new()
	popup_label.name = "CombatPopup"
	popup_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup_label.offset_left = -360.0
	popup_label.offset_right = 360.0
	popup_label.offset_top = -190.0
	popup_label.offset_bottom = -130.0
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup_label.add_theme_font_size_override("font_size", 40)
	popup_label.add_theme_color_override("font_outline_color", INK)
	popup_label.add_theme_constant_override("outline_size", 10)
	popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_label.visible = false
	add_child(popup_label)
	visible = false


static func vice() -> bool:
	var f: int = Engine.get_process_frames()
	if f != _vice_frame:
		_vice_frame = f
		_vice_cache = ViceHUD.style_active()
	return _vice_cache


static func accent() -> Color:
	return VICE_ACCENT if vice() else CLASSIC_ACCENT


static func hp_color() -> Color:
	return VICE_HP if vice() else CLASSIC_HP


static func font() -> Font:
	if not vice():
		return ThemeDB.fallback_font
	if _vice_font == null:
		_vice_font = GameFXScript.vice_font(0.6, 0.22)
	return _vice_font


## A short centre popup (default colour: the style accent).
func popup(text: String, col: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	popup_text = text
	popup_left = POPUP_S
	popups += 1
	popup_label.text = text
	popup_label.add_theme_font_override("font", font())
	popup_label.add_theme_color_override("font_color", col if col.a > 0.0 else accent())
	popup_label.visible = true
	popup_label.modulate.a = 1.0
	popup_label.scale = Vector2.ONE


func _process(delta: float) -> void:
	if popup_left > 0.0:
		popup_left -= delta
		var u: float = clampf(1.0 - popup_left / POPUP_S, 0.0, 1.0)
		popup_label.modulate.a = clampf(popup_left / 0.3, 0.0, 1.0)
		popup_label.pivot_offset = popup_label.size * 0.5
		popup_label.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - u * 6.0))
		if popup_left <= 0.0:
			popup_label.visible = false
	if combat == null:
		return
	finisher_node = combat.finisher_target()
	finisher_shown = visible and finisher_node != null and combat.state != PlayerCombat.St.FINISHER
	var free: bool = visible and not finisher_shown and (combat.state == PlayerCombat.St.IDLE or combat.state == PlayerCombat.St.LIGHT or combat.state == PlayerCombat.St.HEAVY)
	throw_node = combat.throw_target() if free else null
	throw_shown = throw_node != null
	prop_node = combat.prop_target() if free and not throw_shown else null
	prop_shown = prop_node != null
	telegraph_shown = 0
	for e: Variant in combat.enemies:
		if is_instance_valid(e) and bool((e as Object).get("flash_on")):
			telegraph_shown += 1
	_edge_markers()
	var bs: Node3D = combat.boss
	boss_shown = visible and combat.fight_active and bs != null and is_instance_valid(bs) and bs.is_inside_tree() and bs.visible
	if boss_bar.visible != boss_shown:
		boss_bar.visible = boss_shown
	if visible:
		bar.queue_redraw()
		world.queue_redraw()
		if boss_shown:
			boss_bar.queue_redraw()


## Attacks on their way (MeleeEnemy.incoming) from enemies behind the camera or off screen: a point on the screen border
## (EDGE_INSET in) in the enemy's direction. Camera-space x / y give the side for points behind the camera.
func _edge_markers() -> void:
	edge_pos.clear()
	edge_dir.clear()
	edge_kind.clear()
	edge_markers = 0
	if not visible or combat.enemies.is_empty():
		return
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null:
		return
	var vs: Vector2 = vp.get_visible_rect().size
	var c: Vector2 = vs * 0.5
	var screen := Rect2(Vector2.ZERO, vs).grow(-24.0)
	var inv: Transform3D = cam.global_transform.affine_inverse()
	for v: Variant in combat.enemies:
		if not is_instance_valid(v) or not (v as Node3D).is_inside_tree() or not (v as Node3D).visible:
			continue
		var k: int = int((v as Object).call("incoming"))
		if k == 0:
			continue
		var pos: Vector3 = (v as Node3D).global_position + Vector3(0.0, 1.4, 0.0)
		var d: Vector2
		if cam.is_position_behind(pos):
			var lp: Vector3 = inv * pos
			d = Vector2(lp.x, -lp.y)
			if d.length_squared() < 1e-4:
				d = Vector2(0.0, 1.0)
		else:
			var sp: Vector2 = cam.unproject_position(pos)
			if screen.has_point(sp):
				continue                     # on screen: the wind-up pose / the red ring tell it
			d = sp - c
		d = d.normalized()
		var half: Vector2 = c - Vector2(EDGE_INSET, EDGE_INSET)
		var t: float = minf(half.x / maxf(absf(d.x), 1e-4), half.y / maxf(absf(d.y), 1e-4))
		edge_pos.append(c + d * t)
		edge_dir.append(d)
		edge_kind.append(k)
	edge_markers = edge_pos.size()


## The player's HP bar: "Máu", the bar, the number.
class HPBar extends Control:
	var hud: CombatHUD

	func _draw() -> void:
		var c: PlayerCombat = hud.combat
		if c == null:
			return
		var f: Font = CombatHUD.font()
		var acc: Color = CombatHUD.accent()
		var k: float = clampf(c.hp / maxf(c.max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.55))
		draw_rect(Rect2(Vector2.ZERO, size), Color(acc, 0.8), false, 2.0)
		_text(f, Vector2(12.0, 29.0), CombatData.T_HP, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 60.0)
		var r := Rect2(Vector2(70.0, 14.0), Vector2(size.x - 70.0 - 58.0, 16.0))
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
		var col: Color = CombatHUD.hp_color()
		if k < 0.25 and fmod(float(Time.get_ticks_msec()) / 1000.0, 0.5) < 0.25:
			col = col.lightened(0.45)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.5), false, 1.0)
		_text(f, Vector2(size.x - 52.0, 29.0), "%d" % int(ceil(c.hp)), 18, acc, HORIZONTAL_ALIGNMENT_RIGHT, 44.0)
		if c.fight_active:
			_text(ThemeDB.fallback_font, Vector2(12.0, 49.0), c.controls_text, 11, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, size.x - 24.0)

	func _text(f: Font, pos: Vector2, s: String, sz: int, col: Color, align: HorizontalAlignment, w: float) -> void:
		draw_string_outline(f, pos, s, align, w, sz, 4, CombatHUD.INK)
		draw_string(f, pos, s, align, w, sz, col)


## The boss bar (top centre, under the HP bar): the boss's label, its HP over a dark track, a tick at each boss_marks()
## fraction.
class BossBar extends Control:
	var hud: CombatHUD

	func _draw() -> void:
		var b: Node3D = hud.combat.boss if hud.combat else null
		if b == null or not is_instance_valid(b):
			return
		var f: Font = CombatHUD.font()
		var acc: Color = CombatHUD.accent()
		var k: float = clampf(float(b.get("hp")) / maxf(float(b.get("max_hp")), 1.0), 0.0, 1.0)
		var lbl: String = String(b.get("label"))
		draw_string_outline(f, Vector2(0.0, 14.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 5, CombatHUD.INK)
		draw_string(f, Vector2(0.0, 14.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color.WHITE)
		var r := Rect2(Vector2(0.0, 22.0), Vector2(size.x, 16.0))
		draw_rect(r.grow(3.0), CombatHUD.INK)
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), CombatHUD.hp_color())
		if b.has_method("boss_marks"):
			for m: float in b.call("boss_marks"):
				var x: float = r.position.x + r.size.x * m
				draw_line(Vector2(x, r.position.y - 3.0), Vector2(x, r.end.y + 3.0), CombatHUD.INK, 3.0)
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(acc, 0.9), 1.0)
		draw_rect(r, Color(acc, 0.8), false, 2.0)


## World-anchored enemy widgets (bars, label, lock marker, telegraph ring, finisher prompt).
class WorldLayer extends Control:
	var hud: CombatHUD

	func _draw() -> void:
		var c: PlayerCombat = hud.combat
		if c == null:
			return
		var vp: Viewport = get_viewport()
		var cam: Camera3D = vp.get_camera_3d() if vp else null
		if hud.prop_shown and cam != null and is_instance_valid(hud.prop_node):
			var pp: Vector3 = hud.prop_node.global_position + Vector3(0.0, 0.9, 0.0)
			if not cam.is_position_behind(pp):
				var at: Vector2 = cam.unproject_position(pp) - Vector2(110.0, 0.0)
				var txt: String = CombatData.T_PICKUP % hud.prop_node.display_name()
				draw_string_outline(CombatHUD.font(), at, txt, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 18, 5, CombatHUD.INK)
				draw_string(CombatHUD.font(), at, txt, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 18, CombatHUD.GOLD)
		if c.enemies.is_empty():
			return
		_draw_edges()
		if cam == null:
			return
		var f: Font = CombatHUD.font()
		var acc: Color = CombatHUD.accent()
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		for v: Variant in c.enemies:
			if not is_instance_valid(v):
				continue
			var e: Node3D = v
			if not e.is_inside_tree() or not e.visible:
				continue
			var head: Vector3 = e.global_position + Vector3(0.0, CombatHUD.HEAD_Y, 0.0)
			if cam.is_position_behind(head) or cam.global_position.distance_to(head) > CombatHUD.ENEMY_MAX_M:
				continue
			var sp: Vector2 = cam.unproject_position(head)
			var hostile: bool = bool(e.call("is_hostile"))
			if bool(e.get("flash_on")):
				var r: float = 22.0 + 6.0 * sin(t * 30.0)
				var ring_at: Vector2 = cam.unproject_position(e.global_position + Vector3(0.0, 1.55, 0.0))
				draw_arc(ring_at, r + 2.0, 0.0, TAU, 32, CombatHUD.INK, 6.0, true)
				draw_arc(ring_at, r, 0.0, TAU, 32, CombatHUD.TELEGRAPH, 4.0, true)
			if hostile:
				var w: float = CombatHUD.ENEMY_BAR_W
				var x0: float = sp.x - w * 0.5
				var is_boss: bool = e == c.boss        # the boss bar shows its HP and name
				if not is_boss:
					var hp_k: float = clampf(float(e.get("hp")) / maxf(float(e.get("max_hp")), 1.0), 0.0, 1.0)
					draw_rect(Rect2(x0 - 1.0, sp.y - 1.0, w + 2.0, 11.0), CombatHUD.INK)
					draw_rect(Rect2(x0, sp.y, w * hp_k, 6.0), CombatHUD.hp_color())
				var st_k: float = clampf(float(e.get("stagger")) / maxf(float(e.get("stagger_max")), 1.0), 0.0, 1.0)
				if is_boss:
					draw_rect(Rect2(x0 - 1.0, sp.y + 6.0, w + 2.0, 5.0), CombatHUD.INK)
				draw_rect(Rect2(x0, sp.y + 7.0, w * st_k, 3.0), CombatHUD.STAGGER_COL)
				var lbl: String = "" if is_boss else String(e.get("label"))
				if lbl != "":
					draw_string_outline(f, Vector2(x0 - 40.0, sp.y - 6.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, w + 80.0, 14, 4, CombatHUD.INK)
					draw_string(f, Vector2(x0 - 40.0, sp.y - 6.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, w + 80.0, 14, Color.WHITE)
				if e == c.lock:
					var y: float = sp.y - (24.0 if lbl != "" else 8.0)
					var tri := PackedVector2Array([Vector2(sp.x - 7.0, y - 9.0), Vector2(sp.x + 7.0, y - 9.0), Vector2(sp.x, y)])
					draw_colored_polygon(tri, acc)
			if e == hud.finisher_node and hud.finisher_shown:
				var p: Vector2 = Vector2(sp.x - 80.0, sp.y + 30.0)
				draw_string_outline(f, p, CombatData.T_FINISHER_PROMPT, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 18, 5, CombatHUD.INK)
				draw_string(f, p, CombatData.T_FINISHER_PROMPT, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 18, CombatHUD.GOLD)
			elif e == hud.throw_node and hud.throw_shown:
				var p2: Vector2 = Vector2(sp.x - 80.0, sp.y + 30.0)
				draw_string_outline(f, p2, CombatData.T_THROW_PROMPT, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 18, 5, CombatHUD.INK)
				draw_string(f, p2, CombatData.T_THROW_PROMPT, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 18, CombatHUD.GOLD)

	## Edge markers: an outward arrow head and a pulsing arc, amber (light) or red (heavy).
	func _draw_edges() -> void:
		var pulse: float = 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) / 1000.0 * 18.0)
		for i: int in hud.edge_pos.size():
			var p: Vector2 = hud.edge_pos[i]
			var d: Vector2 = hud.edge_dir[i]
			var n := Vector2(-d.y, d.x)
			var col: Color = CombatHUD.TELEGRAPH if hud.edge_kind[i] == 2 else CombatHUD.LIGHT_WARN
			var tri := PackedVector2Array([p + d * 18.0, p - d * 6.0 + n * 14.0, p - d * 6.0 - n * 14.0])
			draw_colored_polygon(tri, CombatHUD.INK)
			var tri2 := PackedVector2Array([p + d * 14.0, p - d * 3.0 + n * 10.0, p - d * 3.0 - n * 10.0])
			draw_colored_polygon(tri2, Color(col, pulse))
			var a: float = d.angle()
			draw_arc(p - d * 4.0, 24.0, a - 0.9, a + 0.9, 12, Color(col, pulse), 3.0, true)
