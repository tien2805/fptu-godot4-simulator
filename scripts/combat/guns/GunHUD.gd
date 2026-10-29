# File: res://scripts/combat/guns/GunHUD.gd
# HUD of the lair gunfights (spec C-D2), owned by GunFight, plain text and code-drawn shapes (no emoji or decorative
# symbols; key glyphs only in the cover hints), vice and classic styles through CombatHUD's accent / font:
#   - top centre: "Máu" with a bar and the number (blinks below 25 %), "Địch còn N" and "Đợt i/n" (the CombatHUD bar is
#     hidden while a GunFight runs);
#   - under it the boss bar when the fight has a boss: Alexander's (endless) name cut to fit with "...", the bar (gold while
#     a name intro refills it), the status ("SƠ HỞ!", "QUÁ NHIỆT!");
#   - damage direction: a red arc around the screen centre towards each shooter that hit the player (fades in 1.2 s);
#   - telegraph warning: an amber marker on the screen edge (pointing out, CombatHUD's edge-marker idea) for every gunman
#     glinting and the forklift revving for a charge while it is behind the camera or off screen;
#   - bottom centre: "[Ctrl] nấp" near a free cover slot, the in-cover hint while crouched, "Hết đạn, tìm hộp đạn";
#   - centre popups (wave start, boss windows), a toast line (ammo pickups, refusals) and a subtitle (the name speech);
#   - Wave 3 bullet time: a slim "Tập trung" focus bar above the prompt line while the fight has bullet time (enabled),
#     and the prompt "[Space] lao người" while aiming with a dive available (when no cover / ammo hint is shown).
# Test state (updated in _process, not in _draw): hp_text, left_text, wave_text, markers, edge_markers, boss_shown,
# boss_name, prompt_text, popup_text, toast_text, subtitle_text, focus_k, focus_shown. Strings are rebuilt only when their value changes; the
# panels redraw only on a change (or while the low-HP bar blinks).
class_name GunHUD
extends CanvasLayer

const PANEL := Vector2(440.0, 62.0)
const BOSS := Vector2(560.0, 50.0)
const TOP: float = 18.0
const MARK_S: float = 1.2
const MARK_R: float = 130.0
const MARK_HALF: float = 0.42
const MARK_MAX: int = 6
const POPUP_S: float = 1.1
const TOAST_S: float = 1.8
const NAME_CHARS: int = 44
const EDGE_INSET: float = 46.0
const EDGE_COL := Color("#FFB23C")

var fight: Object = null
var panel: Control
var boss_bar: Control
var marks_view: Control
var prompt_label: Label
var focus_bar: Control
var focus_k: float = 1.0
var focus_shown: bool = false
var _focus_q: int = -1
var popup_label: Label
var toast_label: Label
var subtitle_label: Label
var hp_text: String = ""
var left_text: String = ""
var wave_text: String = ""
var boss_shown: bool = false
var boss_name: String = ""
var boss_k: float = 1.0
var boss_status: String = ""
var boss_refilling: bool = false
var prompt_text: String = ""
var popup_text: String = ""
var toast_text: String = ""
var subtitle_text: String = ""
var markers: int = 0
var edge_markers: int = 0
var edge_pos := PackedVector2Array()
var edge_dir := PackedVector2Array()
var hp_num: String = ""
var _hp_i: int = -1
var _left_n: int = -1
var _wave_i: int = -1
var _wave_n: int = -1
var _boss_src: String = ""
var _boss_k_shown: float = -1.0
var _status_shown: String = ""
var _dirty: bool = true
var popups: int = 0
var hp_k: float = 1.0
var _mark_dir: PackedVector3Array = PackedVector3Array()
var _mark_left: PackedFloat32Array = PackedFloat32Array()
var _popup_left: float = 0.0
var _toast_left: float = 0.0
var _sub_left: float = 0.0


func _ready() -> void:
	layer = 2
	var mv := Marks.new()
	mv.name = "DamageMarks"
	mv.hud = self
	mv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mv)
	marks_view = mv
	var p := HPPanel.new()
	p.name = "GunPanel"
	p.hud = self
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.offset_left = -PANEL.x * 0.5
	p.offset_right = PANEL.x * 0.5
	p.offset_top = TOP
	p.offset_bottom = TOP + PANEL.y
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	panel = p
	var b := BossBar.new()
	b.name = "BossBar"
	b.hud = self
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	b.offset_left = -BOSS.x * 0.5
	b.offset_right = BOSS.x * 0.5
	b.offset_top = TOP + PANEL.y + 8.0
	b.offset_bottom = TOP + PANEL.y + 8.0 + BOSS.y
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.visible = false
	add_child(b)
	boss_bar = b
	var fb := FocusBar.new()
	fb.name = "FocusBar"
	fb.hud = self
	fb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fb.offset_left = -150.0
	fb.offset_right = 150.0
	fb.offset_top = -108.0
	fb.offset_bottom = -90.0
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fb.visible = false
	add_child(fb)
	focus_bar = fb
	prompt_label = _label("CoverPrompt", Control.PRESET_CENTER_BOTTOM, Vector4(-420.0, 420.0, -150.0, -116.0), 20)
	popup_label = _label("GunPopup", Control.PRESET_CENTER, Vector4(-380.0, 380.0, -200.0, -140.0), 40)
	toast_label = _label("GunToast", Control.PRESET_CENTER_TOP, Vector4(-320.0, 320.0, TOP + PANEL.y + BOSS.y + 18.0, TOP + PANEL.y + BOSS.y + 48.0), 20)
	subtitle_label = _label("GunSubtitle", Control.PRESET_CENTER_BOTTOM, Vector4(-560.0, 560.0, -220.0, -160.0), 22)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(n: String, preset: Control.LayoutPreset, o: Vector4, sz: int) -> Label:
	var l := Label.new()
	l.name = n
	l.set_anchors_and_offsets_preset(preset)
	l.offset_left = o.x
	l.offset_right = o.y
	l.offset_top = o.z
	l.offset_bottom = o.w
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_outline_color", CombatHUD.INK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l


## A shooter at world position `from` hit the player standing at `at`.
func add_damage(from: Vector3, at: Vector3) -> void:
	var d := Vector3(from.x - at.x, 0.0, from.z - at.z)
	if d.length_squared() < 1e-4:
		return
	if _mark_dir.size() >= MARK_MAX:
		_mark_dir.remove_at(0)
		_mark_left.remove_at(0)
	_mark_dir.append(d.normalized())
	_mark_left.append(MARK_S)


func popup(text: String, col: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	popup_text = text
	popups += 1
	_popup_left = POPUP_S
	popup_label.text = text
	popup_label.add_theme_font_override("font", CombatHUD.font())
	popup_label.add_theme_color_override("font_color", col if col.a > 0.0 else CombatHUD.accent())
	popup_label.visible = true


func toast(text: String) -> void:
	toast_text = text
	_toast_left = TOAST_S
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.visible = true


func subtitle(text: String, secs: float) -> void:
	subtitle_text = text
	_sub_left = secs
	subtitle_label.text = text
	subtitle_label.add_theme_color_override("font_color", Color("#FFE14D"))
	subtitle_label.visible = true


## Screen direction (y down) of a flat world direction for the current camera (up = where the camera looks).
func screen_dir(d: Vector3) -> Vector2:
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null:
		return Vector2(d.x, d.z)
	var f: Vector3 = WeaponMath.flat_dir(-cam.global_basis.z)
	var r := Vector3(-f.z, 0.0, f.x)
	var v := Vector2(d.dot(r), -d.dot(f))
	return v.normalized() if v.length_squared() > 1e-6 else Vector2(0.0, -1.0)


func _process(delta: float) -> void:
	for i: int in range(_mark_left.size() - 1, -1, -1):
		_mark_left[i] -= delta
		if _mark_left[i] <= 0.0:
			_mark_left.remove_at(i)
			_mark_dir.remove_at(i)
	markers = _mark_left.size()
	if _popup_left > 0.0:
		_popup_left -= delta
		popup_label.modulate.a = clampf(_popup_left / 0.3, 0.0, 1.0)
		if _popup_left <= 0.0:
			popup_label.visible = false
	if _toast_left > 0.0:
		_toast_left -= delta
		toast_label.modulate.a = clampf(_toast_left / 0.3, 0.0, 1.0)
		if _toast_left <= 0.0:
			toast_label.visible = false
	if _sub_left > 0.0:
		_sub_left -= delta
		if _sub_left <= 0.0:
			subtitle_label.visible = false
	if fight == null or not visible:
		return
	_read_fight()
	if _dirty or hp_k < 0.25:
		panel.queue_redraw()
		if boss_bar.visible:
			boss_bar.queue_redraw()
		_dirty = false
	_edge_markers()
	var draw_marks: bool = markers > 0 or edge_markers > 0
	if draw_marks or marks_view.get_meta("had", false):
		marks_view.set_meta("had", draw_marks)
		marks_view.queue_redraw()


## Telegraphs on their way from behind the camera or off screen: a point on the screen border (EDGE_INSET in) towards the
## glinting gunman / the revving forklift.
func _edge_markers() -> void:
	edge_pos.clear()
	edge_dir.clear()
	edge_markers = 0
	var vp: Viewport = get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null:
		return
	for g: Variant in fight.get("gunmen"):
		if is_instance_valid(g) and (g as Gunman).telegraphing:
			_edge_for(cam, vp, (g as Gunman).muzzle_pos())
	var boss: Object = fight.get("boss")
	if boss != null and is_instance_valid(boss) and String(boss.call("state_name")) == "charge_tell":
		_edge_for(cam, vp, (boss.get("forklift") as Node3D).global_position + Vector3(0.0, 1.5, 0.0))
	edge_markers = edge_pos.size()


func _edge_for(cam: Camera3D, vp: Viewport, pos: Vector3) -> void:
	var vs: Vector2 = vp.get_visible_rect().size
	var c: Vector2 = vs * 0.5
	var d: Vector2
	if cam.is_position_behind(pos):
		var lp: Vector3 = cam.global_transform.affine_inverse() * pos
		d = Vector2(lp.x, -lp.y)
		if d.length_squared() < 1e-4:
			d = Vector2(0.0, 1.0)
	else:
		var sp: Vector2 = cam.unproject_position(pos)
		if Rect2(Vector2.ZERO, vs).grow(-24.0).has_point(sp):
			return                           # on screen: the glint itself tells it
		d = sp - c
	d = d.normalized()
	var half: Vector2 = c - Vector2(EDGE_INSET, EDGE_INSET)
	var t: float = minf(half.x / maxf(absf(d.x), 1e-4), half.y / maxf(absf(d.y), 1e-4))
	edge_pos.append(c + d * t)
	edge_dir.append(d)


func _read_fight() -> void:
	var c: PlayerCombat = fight.get("combat")
	if c:
		hp_k = clampf(c.hp / maxf(c.max_hp, 1.0), 0.0, 1.0)
		var hi: int = int(ceil(c.hp))
		if hi != _hp_i:
			_hp_i = hi
			hp_num = str(hi)
			hp_text = GunData.T_HP + " " + hp_num
			_dirty = true
	var left: int = int(fight.call("enemies_left"))
	if left != _left_n:
		_left_n = left
		left_text = GunData.T_LEFT % left
		_dirty = true
	var nw: int = (fight.get("waves") as Array).size()
	var wi: int = int(fight.get("wave"))
	if wi != _wave_i or nw != _wave_n:
		_wave_i = wi
		_wave_n = nw
		wave_text = GunData.T_WAVE % [wi + 1, nw] if nw > 1 else ""
		_dirty = true
	var boss: Object = fight.get("boss")
	var shown: bool = boss != null and is_instance_valid(boss) and not bool(boss.call("is_defeated"))
	if shown != boss_shown:
		boss_shown = shown
		boss_bar.visible = shown
		_dirty = true
	if boss_shown:
		boss_k = clampf(float(boss.get("hp")) / maxf(float(boss.get("max_hp")), 1.0), 0.0, 1.0)
		boss_status = String(boss.call("status_text"))
		var refill: bool = bool(boss.call("is_naming"))
		if not is_equal_approx(boss_k, _boss_k_shown) or boss_status != _status_shown or refill != boss_refilling:
			_boss_k_shown = boss_k
			_status_shown = boss_status
			boss_refilling = refill
			_dirty = true
		var full: String = String(boss.call("display_name"))
		if full != _boss_src:
			_boss_src = full
			boss_name = full if full.length() <= NAME_CHARS else full.substr(0, NAME_CHARS - 3).strip_edges() + "..."
			_dirty = true
	var pt: String = ""
	var cov: PlayerCover = fight.get("cover_ctl")
	if cov:
		if cov.in_cover:
			pt = GunData.T_IN_COVER
		elif cov.prompt_slot >= 0:
			pt = GunData.T_COVER_PROMPT
	var w: WeaponDirector = fight.get("weapons")
	if pt == "" and w and WeaponData.mag_of(w.current) > 0 and w.ammo[w.current] <= 0 and w.reserve_of(w.current) == 0:
		pt = GunData.T_NO_AMMO
	var bt: BulletTime = fight.get("bullet_time")
	var show_focus: bool = bt != null and is_instance_valid(bt) and bt.enabled
	if show_focus != focus_shown:
		focus_shown = show_focus
		focus_bar.visible = show_focus
		_focus_q = -1
	if show_focus:
		focus_k = clampf(bt.focus / BulletTime.FOCUS_MAX, 0.0, 1.0)
		var q: int = int(focus_k * 100.0) * 2 + (1 if bt.focus + 1e-4 >= BulletTime.cost() else 0)
		if q != _focus_q:
			_focus_q = q
			focus_bar.queue_redraw()
		if pt == "" and bt.can_prompt():
			pt = BulletTime.T_PROMPT
	if pt != prompt_text:
		prompt_text = pt
		prompt_label.text = pt
		prompt_label.add_theme_color_override("font_color", Color.WHITE)
		prompt_label.visible = pt != ""


class HPPanel extends Control:
	var hud: GunHUD

	func _draw() -> void:
		var f: Font = CombatHUD.font()
		var acc: Color = CombatHUD.accent()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.55))
		draw_rect(Rect2(Vector2.ZERO, size), Color(acc, 0.8), false, 2.0)
		_text(f, Vector2(12.0, 26.0), GunData.T_HP, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 60.0)
		var r := Rect2(Vector2(66.0, 12.0), Vector2(size.x - 66.0 - 170.0, 15.0))
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
		var col: Color = CombatHUD.hp_color()
		if hud.hp_k < 0.25 and fmod(float(Time.get_ticks_msec()) / 1000.0, 0.5) < 0.25:
			col = col.lightened(0.45)
		draw_rect(Rect2(r.position, Vector2(r.size.x * hud.hp_k, r.size.y)), col)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.5), false, 1.0)
		_text(f, Vector2(r.end.x + 6.0, 26.0), hud.hp_num, 18, acc, HORIZONTAL_ALIGNMENT_LEFT, 44.0)
		_text(f, Vector2(size.x - 118.0, 26.0), hud.left_text, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 108.0)
		if hud.wave_text != "":
			_text(ThemeDB.fallback_font, Vector2(12.0, 50.0), hud.wave_text, 14, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, size.x - 24.0)

	func _text(f: Font, pos: Vector2, s: String, sz: int, col: Color, align: HorizontalAlignment, w: float) -> void:
		draw_string_outline(f, pos, s, align, w, sz, 4, CombatHUD.INK)
		draw_string(f, pos, s, align, w, sz, col)


class BossBar extends Control:
	var hud: GunHUD

	func _draw() -> void:
		var f: Font = CombatHUD.font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.6))
		draw_rect(Rect2(Vector2.ZERO, size), Color(CombatHUD.GOLD, 0.85), false, 2.0)
		draw_string_outline(f, Vector2(12.0, 20.0), hud.boss_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 150.0, 16, 4, CombatHUD.INK)
		draw_string(f, Vector2(12.0, 20.0), hud.boss_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 150.0, 16, Color.WHITE)
		if hud.boss_status != "":
			draw_string_outline(f, Vector2(size.x - 136.0, 20.0), hud.boss_status, HORIZONTAL_ALIGNMENT_RIGHT, 124.0, 16, 4, CombatHUD.INK)
			draw_string(f, Vector2(size.x - 136.0, 20.0), hud.boss_status, HORIZONTAL_ALIGNMENT_RIGHT, 124.0, 16, CombatHUD.GOLD)
		var r := Rect2(Vector2(12.0, 28.0), Vector2(size.x - 24.0, 13.0))
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
		var col: Color = CombatHUD.GOLD if hud.boss_refilling else CombatHUD.hp_color()
		draw_rect(Rect2(r.position, Vector2(r.size.x * hud.boss_k, r.size.y)), col)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.5), false, 1.0)


class FocusBar extends Control:
	var hud: GunHUD

	func _draw() -> void:
		var f: Font = CombatHUD.font()
		var bt: BulletTime = hud.fight.get("bullet_time") if hud.fight else null
		var ready: bool = bt != null and is_instance_valid(bt) and bt.focus + 1e-4 >= BulletTime.cost()
		draw_string_outline(f, Vector2(0.0, 14.0), BulletTime.T_FOCUS, HORIZONTAL_ALIGNMENT_LEFT, 96.0, 14, 4, CombatHUD.INK)
		draw_string(f, Vector2(0.0, 14.0), BulletTime.T_FOCUS, HORIZONTAL_ALIGNMENT_LEFT, 96.0, 14, Color.WHITE)
		var r := Rect2(Vector2(96.0, 4.0), Vector2(size.x - 96.0, 10.0))
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.6))
		var col := Color(0.55, 0.75, 1.0) if ready else Color(0.45, 0.5, 0.6)
		draw_rect(Rect2(r.position, Vector2(r.size.x * hud.focus_k, r.size.y)), col)
		if bt != null and is_instance_valid(bt):
			var cx: float = r.position.x + r.size.x * BulletTime.cost() / BulletTime.FOCUS_MAX
			draw_line(Vector2(cx, r.position.y - 2.0), Vector2(cx, r.end.y + 2.0), Color(1.0, 1.0, 1.0, 0.8), 1.5)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.5), false, 1.0)


class Marks extends Control:
	var hud: GunHUD

	func _draw() -> void:
		var pulse: float = 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) / 1000.0 * 18.0)
		for j: int in hud.edge_pos.size():
			var p: Vector2 = hud.edge_pos[j]
			var dd: Vector2 = hud.edge_dir[j]
			var nn := Vector2(-dd.y, dd.x)
			draw_colored_polygon(PackedVector2Array([p + dd * 18.0, p - dd * 6.0 + nn * 14.0, p - dd * 6.0 - nn * 14.0]), CombatHUD.INK)
			draw_colored_polygon(PackedVector2Array([p + dd * 14.0, p - dd * 3.0 + nn * 10.0, p - dd * 3.0 - nn * 10.0]), Color(GunHUD.EDGE_COL, pulse))
			draw_arc(p - dd * 4.0, 24.0, dd.angle() - 0.9, dd.angle() + 0.9, 12, Color(GunHUD.EDGE_COL, pulse), 3.0, true)
		var c: Vector2 = size * 0.5
		for i: int in hud._mark_dir.size():
			var sd: Vector2 = hud.screen_dir(hud._mark_dir[i])
			var a: float = sd.angle()
			var k: float = clampf(hud._mark_left[i] / GunHUD.MARK_S, 0.0, 1.0)
			draw_arc(c, GunHUD.MARK_R, a - GunHUD.MARK_HALF, a + GunHUD.MARK_HALF, 16, Color(CombatHUD.INK, 0.7 * k), 11.0, true)
			draw_arc(c, GunHUD.MARK_R, a - GunHUD.MARK_HALF, a + GunHUD.MARK_HALF, 16, Color(1.0, 0.15, 0.1, 0.9 * k), 7.0, true)
			var tip: Vector2 = c + sd * (GunHUD.MARK_R + 16.0)
			var n := Vector2(-sd.y, sd.x)
			draw_colored_polygon(PackedVector2Array([tip, c + sd * (GunHUD.MARK_R + 4.0) + n * 9.0, c + sd * (GunHUD.MARK_R + 4.0) - n * 9.0]), Color(1.0, 0.15, 0.1, 0.9 * k))
