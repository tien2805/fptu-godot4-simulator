# File: res://tests/test_weapon_wheel.gd
# Headless test of the Phase W weapon wheel (spec section 2, section 7 "Wheel"): angle -> slot for all 8 wedges and their
# borders, the 40 px dead zone, the slot table in W-D4 order with its Vietnamese names, hold / tap threshold (0.12 s real),
# Engine.time_scale eased to 0.2 and back to 1.0 over 0.1 s real, release equips (selected), Esc and right click close
# without change, the middle button / motion / wheel events through _input, scroll cycles only while closed, blocked
# (cannot open; closes at once and restores 1.0), leaving the tree restores 1.0, icons are code polygons, and nothing
# under scripts/cine/ writes Engine.time_scale (A1-D6).
# Run:  godot --headless --path . --script tests/test_weapon_wheel.gd
extends SceneTree

var fails: Array[String] = []
var started: bool = false
var wheel: WeaponWheel
var sel: Array[int] = []
var cyc: Array[int] = []
var closes: Array[bool] = []
var blocked: bool = false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST WEAPON WHEEL ---")
	_math()
	_table()
	_icons()
	_cine_never_writes_time_scale()
	physics_frame.connect(_on_physics)   # the wheel needs the tree (viewport for _input): start in the first physics frame


func _math() -> void:
	var dz: float = WeaponWheel.DEAD_ZONE
	for i: int in 8:
		var a: float = WeaponMath.wedge_angle(i)
		var c: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a) * 100.0, dz)
		_check(c == i, "wedge centre %d maps to slot %d (got %d)" % [i, i, c])
		var hi: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a + deg_to_rad(22.0)) * 100.0, dz)
		var lo: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a - deg_to_rad(22.0)) * 100.0, dz)
		_check(hi == i and lo == i, "±22° stays in wedge %d (got %d / %d)" % [i, hi, lo])
		var past: int = WeaponMath.wedge_for(WeaponMath.wedge_point(a + deg_to_rad(23.0)) * 100.0, dz)
		_check(past == (i + 1) % 8, "+23° from wedge %d is the next wedge clockwise (got %d)" % [i, past])
	_check(WeaponMath.wedge_for(Vector2(0.0, -100.0), dz) == 0, "straight up = slot 0 (Tay không)")
	_check(WeaponMath.wedge_for(Vector2(100.0, 0.0), dz) == 2, "right = slot 2 (Súng lục): clockwise order")
	_check(WeaponMath.wedge_for(Vector2(0.0, 100.0), dz) == 4, "down = slot 4 (Tên lửa)")
	_check(WeaponMath.wedge_for(Vector2(-100.0, 0.0), dz) == 6, "left = slot 6 (Sầu riêng)")
	_check(WeaponMath.wedge_for(Vector2(39.0, 0.0), dz) == -1 and WeaponMath.wedge_for(Vector2(0.0, -39.9), dz) == -1, "inside the 40 px dead zone -> -1")
	_check(is_equal_approx(WeaponMath.flat(Vector3(0, 5, 0), Vector3(3, -2, 4)), 5.0), "flat() ignores height")


func _table() -> void:
	var names: Array[String] = ["Tay không", "Dao", "Súng lục", "Shotgun", "Tên lửa", "Dép tổ ong", "Sầu riêng", "Loa kẹo kéo"]
	_check(WeaponData.SLOTS.size() == WeaponData.COUNT and WeaponData.COUNT == 8, "8 slots")
	for i: int in 8:
		_check(WeaponData.name_of(i) == names[i], "slot %d is named %s (got %s)" % [i, names[i], WeaponData.name_of(i)])
	_check(WeaponData.ammo_text(WeaponData.Slot.PISTOL, 12) == "12 / ∞", "pistol ammo text '12 / ∞'")
	_check(WeaponData.ammo_text(WeaponData.Slot.DEP, 0) == "∞", "no-magazine weapons show '∞'")


func _icons() -> void:
	for i: int in 8:
		var sh: Array = WeaponIcons.shapes(i)
		_check(sh.size() >= 2, "icon %d has code polygons (%d)" % [i, sh.size()])
		for s: Dictionary in sh:
			var pts: PackedVector2Array = s["pts"]
			var inside: bool = true
			for p: Vector2 in pts:
				if absf(p.x) > 1.0 or absf(p.y) > 1.0:
					inside = false
			_check(inside, "icon %d polygon stays inside the unit box" % i)
			_check(Geometry2D.triangulate_polygon(pts).size() >= 3, "icon %d polygon triangulates (simple polygon)" % i)


func _cine_never_writes_time_scale() -> void:
	var re := RegEx.new()
	re.compile("Engine\\.time_scale\\s*=[^=]")
	for dir: String in ["res://scripts/cine/", "res://scripts/cine/timelines/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				_check(re.search(FileAccess.get_file_as_string(dir + f)) == null, "%s%s never writes Engine.time_scale (A1-D6)" % [dir, f])
	_check(re.search(FileAccess.get_file_as_string("res://scripts/weapons/RadialWheel.gd")) != null, "the radial wheel (scripts/weapons/) is what writes it")


func _on_physics() -> void:
	if started:
		return
	started = true
	wheel = WeaponWheel.new()
	wheel.manual = true
	wheel.info_fn = func(s: int) -> String: return WeaponData.ammo_text(s, WeaponData.mag_of(s))
	wheel.blocked_fn = func() -> bool: return blocked
	root.add_child(wheel)
	wheel.selected.connect(func(s: int) -> void: sel.append(s))
	wheel.cycled.connect(func(s: int) -> void: cyc.append(s))
	wheel.closed.connect(func(c: bool) -> void: closes.append(c))
	_check(wheel.slots.size() == 8 and String(wheel.slots[5]["name"]) == "Dép tổ ong", "the weapon wheel's slot list is the W-D4 table")
	_run()
	_generic()
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: WEAPON WHEEL (wedges, dead zone, hold/tap, eased 0.2 time scale, select / cancel, scroll, blocked, icons)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _hold_open() -> void:
	wheel.press()
	wheel.step_real(0.13)


func _mb(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _run() -> void:
	# a tap is ignored
	wheel.press()
	wheel.step_real(0.05)
	wheel.release()
	wheel.step_real(0.2)
	_check(not wheel.is_open() and is_equal_approx(Engine.time_scale, 1.0) and sel.is_empty(), "a 0.05 s tap of the middle button is ignored")
	# hold >= 0.12 s opens, the game eases to 0.2 over 0.1 s real
	wheel.current = 3
	wheel.press()
	wheel.step_real(0.06)
	_check(not wheel.is_open(), "not open after 0.06 s")
	wheel.step_real(0.07)
	_check(wheel.is_open() and wheel.view.visible, "held 0.13 s: open and drawn")
	wheel.step_real(0.05)
	_check(Engine.time_scale < 0.95 and Engine.time_scale > 0.25, "half way through the ease at 0.05 s (%.3f)" % Engine.time_scale)
	wheel.step_real(0.06)
	_check(is_equal_approx(Engine.time_scale, WeaponWheel.SLOW), "time scale 0.2 after 0.1 s real (%.3f)" % Engine.time_scale)
	# dead zone keeps the current slot; the stick picks wedges and is clamped
	wheel.feed_mouse(Vector2(10.0, -20.0))
	_check(wheel.highlight == 3, "inside the dead zone the current weapon stays highlighted (got %d)" % wheel.highlight)
	wheel.feed_mouse(Vector2(-10.0, -100.0))
	_check(wheel.highlight == 0, "stick up -> slot 0 (got %d)" % wheel.highlight)
	wheel.feed_mouse(Vector2(400.0, 120.0))
	_check(wheel.highlight == 2 and wheel.stick.length() <= WeaponWheel.STICK_MAX + 0.01, "stick right -> slot 2, stick clamped to %.0f px" % WeaponWheel.STICK_MAX)
	wheel.release()
	_check(sel.size() == 1 and sel[0] == 2 and closes.back() == true and not wheel.is_open() and not wheel.view.visible, "release equips the highlighted slot")
	wheel.step_real(0.05)
	_check(Engine.time_scale > 0.25 and Engine.time_scale < 0.99, "eases back up (%.3f)" % Engine.time_scale)
	wheel.step_real(0.06)
	_check(is_equal_approx(Engine.time_scale, 1.0), "1.0 again 0.1 s after closing")
	# Esc closes without change
	wheel.current = 2
	_hold_open()
	wheel.feed_mouse(Vector2(-200.0, 0.0))
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	wheel._input(esc)
	_check(not wheel.is_open() and sel.size() == 1 and closes.back() == false, "Esc closes without change")
	wheel.step_real(0.2)
	# right click closes without change
	_hold_open()
	wheel.feed_mouse(Vector2(0.0, 200.0))
	wheel._input(_mb(MOUSE_BUTTON_RIGHT, true))
	_check(not wheel.is_open() and sel.size() == 1 and closes.back() == false, "right click closes without change")
	wheel.step_real(0.2)
	# middle button + motion + release through _input
	wheel._input(_mb(MOUSE_BUTTON_MIDDLE, true))
	wheel.step_real(0.15)
	_check(wheel.is_open(), "middle button held (event) opens")
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(0.0, 150.0)
	wheel._input(mm)
	wheel._input(_mb(MOUSE_BUTTON_MIDDLE, false))
	_check(sel.back() == 4, "motion down + release (events) equips slot 4 (got %s)" % str(sel))
	wheel.step_real(0.2)
	# scroll cycles only while closed
	wheel._input(_mb(MOUSE_BUTTON_WHEEL_UP, true))
	wheel._input(_mb(MOUSE_BUTTON_WHEEL_DOWN, true))
	_check(cyc.size() == 2 and cyc[0] == -1 and cyc[1] == 1, "wheel up / down cycle -1 / +1 (got %s)" % str(cyc))
	_hold_open()
	wheel._input(_mb(MOUSE_BUTTON_WHEEL_UP, true))
	_check(cyc.size() == 2, "no cycling while the wheel is open")
	wheel.cancel()
	wheel.step_real(0.2)
	# blocked: cannot open; if blocked while open it closes at once and restores 1.0
	blocked = true
	wheel.press()
	wheel.step_real(0.3)
	_check(not wheel.is_open() and is_equal_approx(Engine.time_scale, 1.0), "blocked: the wheel does not open")
	blocked = false
	_hold_open()
	wheel.step_real(0.11)
	_check(is_equal_approx(Engine.time_scale, WeaponWheel.SLOW), "test setup: open and slowed")
	blocked = true
	wheel.step_real(0.016)
	_check(not wheel.is_open() and is_equal_approx(Engine.time_scale, 1.0) and closes.back() == false, "blocked while open: closes at once and restores 1.0")
	blocked = false
	# leaving the tree restores 1.0
	_hold_open()
	wheel.step_real(0.11)
	root.remove_child(wheel)
	_check(is_equal_approx(Engine.time_scale, 1.0), "leaving the tree restores Engine.time_scale = 1.0")
	wheel.queue_free()   # not free(): GameFX queued a deferred theme call for the wheel's Control when it entered the tree


## The same RadialWheel driven by data the way Task 12's emote wheel uses it: a key trigger (B), keep_current off, one
## enabled slot and seven greyed "Sắp có" slots.
func _generic() -> void:
	var rw := RadialWheel.new()
	rw.name = "GenericWheel"
	rw.manual = true
	rw.trigger_key = KEY_B
	rw.keep_current = false
	for i: int in 8:
		rw.slots.append({"name": "Siuuu!" if i == 0 else RadialWheel.SOON, "icon": 0, "enabled": i == 0})
	root.add_child(rw)
	var got: Array[int] = []
	rw.selected.connect(func(s: int) -> void: got.append(s))
	var kb := InputEventKey.new()
	kb.physical_keycode = KEY_B
	kb.pressed = true
	var ku := InputEventKey.new()
	ku.physical_keycode = KEY_B
	ku.pressed = false
	rw._input(kb)
	rw.step_real(0.05)
	rw._input(ku)
	rw.step_real(0.2)
	_check(not rw.is_open() and got.is_empty(), "a key-triggered wheel ignores a tap")
	rw._input(kb)
	rw.step_real(0.13)
	_check(rw.is_open() and rw.highlight == -1, "holding B opens it with nothing highlighted (keep_current off)")
	rw.feed_mouse(Vector2(150.0, 0.0))
	_check(rw.highlight == -1, "a disabled (greyed) slot cannot be highlighted")
	rw._input(ku)
	_check(got.is_empty() and not rw.is_open(), "releasing over a disabled slot chooses nothing")
	rw.step_real(0.2)
	rw._input(kb)
	rw.step_real(0.13)
	rw.feed_mouse(Vector2(0.0, -150.0))
	rw._input(ku)
	_check(got.size() == 1 and got[0] == 0, "slot 0 is chosen although it equals current (keep_current off)")
	rw._input(_mb(MOUSE_BUTTON_WHEEL_UP, true))
	rw.step_real(0.2)
	_check(is_equal_approx(Engine.time_scale, 1.0), "the generic wheel restores the time scale too")
	rw.queue_free()
