# File: res://tests/test_wanted.gd
# Headless test of the Phase W wanted level (spec W-D6, section 4, section 7 "Wanted"): heat -> stars at 4 / 12 / 25, only
# rising with heat; with nobody seeing the player the level drops one star after 12 / 20 / 30 s and the heat falls to that
# star's threshold; every crime restarts the search; below one star the heat fades; an observer with line of sight keeps
# the level, a wall breaks the sight; the radar search circle (centre = last seen, radius 30 / 40 / 50 m) shows only while
# nobody sees the player and is drawn; ViceHUD shows 3-cell stars with the campus / street label; busted / service ignore
# heat. Part B (FreeRoam, crowd off): WeaponDirector.mayhem feeds the level, the HUD has 3 star cells, campus vs streets,
# the wheel is blocked while the wanted state is not "free".
# Uses WantedDirector.tick(delta) directly (physics process off) for the long timers; counts physics frames otherwise.
# Run:  godot --headless --path . --script tests/test_wanted.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var wanted: WantedDirector
var vh: ViceHUD
var classic: ViceStars
var campus: bool = false
var changes: Array[int] = []
var cleared_n: int = 0
var roam: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WANTED LEVEL ---")
	_check(WantedDirector.stars_for(3.9) == 0 and WantedDirector.stars_for(4.0) == 1 and WantedDirector.stars_for(11.9) == 1, "1 star at 4 heat")
	_check(WantedDirector.stars_for(12.0) == 2 and WantedDirector.stars_for(25.0) == 3 and WantedDirector.stars_for(100.0) == 3, "2 stars at 12, 3 at 25, never more")
	physics_frame.connect(_on_physics)


func _ticks(n: int) -> void:
	for i: int in n:
		wanted.tick(1.0)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		vh = ViceHUD.new()
		vh.name = "ViceHUD"
		arena.add_child(vh)
		var layer := CanvasLayer.new()
		arena.add_child(layer)
		classic = ViceStars.new()
		classic.cells = 3
		layer.add_child(classic)
		wanted = WantedDirector.new()
		wanted.name = "Wanted"
		arena.add_child(wanted)
		wanted.setup({"player": player, "vice_hud": vh, "classic_stars": classic, "is_campus_fn": func(_p: Vector3) -> bool: return campus})
		wanted.spawning = false
		wanted.set_physics_process(false)
		wanted.stars_changed.connect(func(s: int) -> void: changes.append(s))
		wanted.cleared.connect(func() -> void: cleared_n += 1)
		_next("a")
		return
	var t: int = frames - t0
	match phase:
		"a":
			if t == 2:
				_part_a()
				World.wall(arena, Vector3(0.0, 1.5, -5.0), Vector3(6.0, 3.0, 0.5))
				_next("b")
		"b":
			if t == 3:
				_part_b()
			if t == 12:
				_check(vh.radar.search_draws > 0, "the radar draws the search circle")
				_start_freeroam()
		"c":
			if t == 60:
				_part_c()


func _part_a() -> void:
	wanted.add_heat(3.9)
	_check(wanted.stars == 0, "3.9 heat: no star")
	wanted.add_heat(0.1)
	_check(wanted.stars == 1 and changes.size() == 1 and changes[0] == 1, "4 heat: 1 star (stars_changed)")
	_check(vh.stars.filled == 1 and vh.stars.visible and vh.stars_label.text == WantedDirector.LABEL_STREET, "ViceHUD shows 1 star, street label")
	_check(not classic.visible, "the classic star row stays hidden in vice style")
	wanted.add_heat(8.0)
	_check(wanted.stars == 2, "12 heat: 2 stars")
	wanted.add_heat(13.0)
	wanted.add_heat(50.0)
	_check(wanted.stars == 3, "25+ heat: 3 stars, never more")
	_ticks(1)
	var sa: Vector3 = wanted.search_area()
	_check(is_equal_approx(sa.z, 50.0) and vh.radar.search.is_equal_approx(sa), "nobody sees him: search circle 50 m at 3 stars on the radar")
	_ticks(28)
	_check(wanted.stars == 3, "3 stars kept for 29 s")
	_ticks(1)
	_check(wanted.stars == 2 and is_equal_approx(wanted.heat, 12.0), "after 30 s unseen: 2 stars, heat 12")
	_ticks(19)
	_check(wanted.stars == 2, "2 stars kept for 19 s")
	_ticks(1)
	_check(wanted.stars == 1 and is_equal_approx(wanted.heat, 4.0), "after 20 s more: 1 star, heat 4")
	_ticks(12)
	_check(wanted.stars == 0 and wanted.heat == 0.0 and cleared_n == 1, "after 12 s more: cleared")
	_check(not vh.stars.visible and wanted.search_area() == Vector3.ZERO, "no stars, no search circle")
	wanted.add_heat(4.0)
	_ticks(8)
	wanted.add_heat(0.5)
	_ticks(8)
	_check(wanted.stars == 1, "a new crime restarts the 12 s search")
	_ticks(4)
	_check(wanted.stars == 0, "12 s after the last crime: cleared")
	wanted.add_heat(3.0)
	_ticks(5)
	_check(absf(wanted.heat - 2.0) < 0.01, "below one star the heat fades 0.2 / s (%.2f)" % wanted.heat)
	var o := Node3D.new()
	o.name = "Observer"
	arena.add_child(o)
	o.global_position = Vector3(0.0, 0.0, -10.0)
	wanted.add_observer(o)
	wanted.add_heat(2.5)
	_ticks(15)
	_check(wanted.stars == 1 and wanted.seen and wanted.search_area() == Vector3.ZERO, "an observer with line of sight keeps the level, no search circle")


func _part_b() -> void:
	_ticks(1)
	_check(not wanted.seen, "the wall breaks the line of sight")
	var sa: Vector3 = wanted.search_area()
	_check(is_equal_approx(sa.z, 30.0) and Vector2(sa.x, sa.y).length() < 0.5, "search circle 30 m around the last seen point (%s)" % sa)
	_ticks(10)
	_check(wanted.stars == 1, "1 star kept for 11 s behind the wall")
	_ticks(1)
	_check(wanted.stars == 0, "lost after 12 s")
	campus = true
	wanted.add_heat(4.0)
	_check(vh.stars_label.text == WantedDirector.LABEL_CAMPUS, "campus label")
	wanted.state = "service"
	wanted.add_heat(30.0)
	_check(wanted.stars == 1, "heat is ignored while busted / in community service")
	wanted.state = "free"
	_ticks(1)
	campus = false
	_ticks(2)
	_check(vh.stars_label.text == WantedDirector.LABEL_STREET, "leaving the campus with a star: the label switches to the street one within 1 s (R4-I2)")


func _start_freeroam() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	_next("c")


func _part_c() -> void:
	var w: WantedDirector = roam.get("wanted")
	var wd: WeaponDirector = roam.get("weapons")
	_check(w != null and wd != null, "FreeRoam builds the wanted level with the weapons")
	wd.mayhem.emit(12.0, Vector3.ZERO, "test")
	_check(w.stars == 2, "WeaponDirector.mayhem feeds the wanted level (%d stars)" % w.stars)
	var hud: ViceHUD = roam.get("vice_hud")
	_check(hud.stars.cells == 3 and hud.stars.filled == 2, "ViceHUD: 3 star cells, 2 filled")
	var md: MapData = roam.get("md")
	_check(not w.is_campus(md.spawn_transform().origin), "the BE6 spawn is on the streets")
	var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
	_check(w.is_campus(FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y)), "the campus courtyard is inside the plot")
	var ww: WeaponWheel = roam.get("weapon_wheel")
	ww.manual = true
	w.state = "service"
	ww.press()
	ww.step_real(0.2)
	_check(not ww.is_open(), "the wheel is blocked while the wanted state is not free")
	w.state = "free"
	w.clear()
	_check(w.stars == 0 and not hud.stars.visible, "clear() empties the level")
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: WANTED LEVEL (thresholds, LOS decay 12/20/30 s, crime restarts the search, idle fade, wall breaks sight, search circle, HUD stars, FreeRoam wiring)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
