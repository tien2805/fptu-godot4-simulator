# File: res://tests/test_busted.gd
# Headless test of Phase W busting (spec W-D8, section 5, section 7 "busted detection"): the busted timeline passes the A1
# validator for every catcher (7 s, tail 3-4 s) and its beat sheet is in sync; the "BỊ TÓM!" stamp slams in and is done after
# 1 s real; an officer within 1.2 m of a standing player for 1.5 s busts him (not earlier), stepping away resets the timer,
# a knocked-out officer cannot catch, a knocked-down player is busted at once, nobody is busted while riding or with
# catch_enabled off; in FreeRoam the bust freezes the game, stamps, plays the cutscene at the player's spot through
# play_cinematic (wheel blocked), hold-Esc skips it, and the game resumes. Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_busted.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const TL_PATH: String = "res://scripts/cine/timelines/wanted_busted.gd"

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var wanted: WantedDirector
var guard: Officer
var stamp_done: bool = false
var roam: Node3D
var busts0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST BUSTED ---")
	for who: String in ["guard", "police", "toan"]:
		var tl: CineTimeline = (load(TL_PATH) as GDScript).new()
		tl.set("catcher", who)
		tl.build()
		var errs: PackedStringArray = tl.validate()
		_check(errs.is_empty(), "busted timeline (%s) passes the A1 validator %s" % [who, str(errs)])
		var tail: float = tl.length - float(tl.clock.ramps[tl.clock.ramps.size() - 1]["r1"])
		_check(is_equal_approx(tl.length, 7.0) and tail >= 3.0 and tail <= 4.0, "7 s long, %.3f s normal-speed tail" % tail)
		_check(tl.actors.has("toan") == (who == "toan"), "Thầy Toàn appears only when he made the catch (%s)" % who)
	var committed: String = FileAccess.get_file_as_string("res://docs/cinematics/wanted_busted.txt").replace("\r\n", "\n")
	_check(committed == CineTimeline.load_slot("wanted_busted").beat_sheet(), "docs/cinematics/wanted_busted.txt is in sync (run tools/cine_beats.gd)")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _guard_at(off: Vector3) -> Officer:
	return wanted.spawn_officer("guard", player.global_position + off)


## Release the stamp; without FreeRoam there is no cutscene. Task 11 then starts a community-service chore (far away at
## the default street spot): finish it at once and bring the player back, so these catch-rule checks stay valid after Task 11.
func _release_stamp() -> void:
	if wanted.stamp:
		wanted.stamp.step_real(1.1)
	var svc: Variant = wanted.get("service")
	if svc != null and is_instance_valid(svc):
		svc.call("finish")
	player.teleport(Vector3.ZERO, 0.0)


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		var st := BustedStamp.new()
		st.manual = true
		arena.add_child(st)
		st.done.connect(func() -> void: stamp_done = true)
		st.step_real(0.5)
		_check(st.label.text == "BỊ TÓM!" and st.label.scale.is_equal_approx(Vector2.ONE) and st.label.modulate.a > 0.99, "the stamp has slammed in after 0.5 s")
		st.step_real(0.6)
		_check(stamp_done and st.is_queued_for_deletion(), "the stamp is done after 1 s")
		wanted = WantedDirector.new()
		wanted.name = "Wanted"
		arena.add_child(wanted)
		wanted.setup({"player": player, "is_campus_fn": func(_p: Vector3) -> bool: return false})
		wanted.spawning = false
		wanted.stamp_manual = true
		wanted.add_heat(4.0)
		guard = _guard_at(Vector3(1.0, 0.0, 0.0))
		_next("stand")
		return
	var t: int = frames - t0
	match phase:
		"stand":
			if t == 80:
				_check(wanted.busts == 0, "not busted before 1.5 s (catch timer %.2f)" % wanted.catch_t)
			if t == 100:
				_check(wanted.busts == 1 and wanted.state == "stamp" and paused and wanted.stamp != null, "1.5 s within 1.2 m of a standing player: busted, game frozen, stamp")
				_check(wanted.catcher == "guard", "the catcher's role is kept for the cutscene")
				_release_stamp()
				_check(wanted.state == "free" and wanted.stars == 0 and not paused and wanted.officers().is_empty(), "without FreeRoam the cutscene is skipped and the level cleared")
				wanted.add_heat(4.0)
				guard = _guard_at(Vector3(1.0, 0.0, 0.0))
				_next("step_away")
		"step_away":
			if t == 60:
				guard.global_position = player.global_position + Vector3(6.0, 0.0, 0.0)
			if t == 62:
				_check(wanted.catch_t == 0.0 and wanted.busts == 1, "stepping away resets the catch timer")
				guard.take_hit({"kind": "melee", "from": player.global_position})
				guard.global_position = player.global_position + Vector3(0.8, 0.0, 0.0)
			if t == 180:
				_check(wanted.busts == 1, "a knocked-out officer next to the player cannot catch him")
				_guard_at(Vector3(0.0, 0.0, 1.0))
			if t == 182:
				player.knock_down(Vector3(1.0, 0.0, 0.0), 1.0)
			if t == 186:
				_check(wanted.busts == 2, "an officer reaching a knocked-down player busts him at once")
				_release_stamp()
				wanted.add_heat(4.0)
				player.visible = false
				_guard_at(Vector3(1.0, 0.0, 0.0))
				_next("riding")
		"riding":
			if t == 120:
				_check(wanted.busts == 2, "nobody is busted while riding (player hidden)")
				player.visible = true
				wanted.catch_enabled = false
			if t == 240:
				_check(wanted.busts == 2, "catch_enabled = false: never busted")
				_start_b()
		"b":
			_part_b(t)


func _start_b() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	_next("b")


func _part_b(t: int) -> void:
	var w: WantedDirector = roam.get("wanted")
	var pl: ThirdPersonController = roam.get("player")
	if t == 60:
		w.cine_opts = {"manual": true, "music": false}
		w.stamp_manual = true
		var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
		var c3: Vector3 = FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y)
		var spot: Variant = roam.call("find_free_spot", c3, 0.0, 8)
		pl.teleport((spot if spot is Vector3 else c3) + Vector3(0.0, 0.05, 0.0), 0.0)
	if t == 70:
		w.add_heat(12.0)
		var near: Variant = roam.call("find_free_spot", pl.global_position + Vector3(1.0, 0.0, 0.0), pl.global_position.y, 2)
		w.spawn_officer("guard", near if near is Vector3 else pl.global_position + Vector3(1.0, 0.0, 0.0))
	if t > 70 and w.busts == 1 and not has_meta("bb"):
		set_meta("bb", true)
		_check(w.state == "stamp" and paused and w.catcher in ["guard", "toan"], "busted on campus by %s: frozen + stamp" % w.catcher)
		w.stamp.step_real(1.1)
		var cp: CinePlayer = roam.get("cine_player")
		_check(w.state == "cutscene" and cp != null and cp.timeline.slot == "wanted_busted", "the busted cutscene plays through play_cinematic")
		_check(cp != null and cp.stage_xf.origin.distance_to(pl.global_position) < 0.1, "staged at the player's spot (opts xf)")
		_check(not pl.visible and not (roam.get("weapon_hud") as CanvasLayer).visible, "player and weapon HUD hidden during the cutscene")
		var ww: WeaponWheel = roam.get("weapon_wheel")
		ww.manual = true
		ww.press()
		ww.step_real(0.2)
		_check(not ww.is_open(), "the wheel is blocked during the cutscene")
		cp.force_skip_hold = true
		var n: int = 0
		while roam.get("cine_player") != null and n < 200:
			cp.step(1.0 / 60.0)
			n += 1
		_check(roam.get("cine_player") == null and n < 100, "hold Esc skips the cutscene (%d steps)" % n)
		_check(not paused and pl.visible and (w.state == "free" or w.state == "service"), "the game resumes after the cutscene (state %s)" % w.state)
		_finish()
	if t == 400 and not has_meta("bb"):
		_check(false, "the guard never busted the player in FreeRoam")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: BUSTED (timeline valid for all catchers, beat sheet, stamp, 1.5 s catch, reset, KO'd officers, knocked-down player, riding, cutscene + skip in FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
