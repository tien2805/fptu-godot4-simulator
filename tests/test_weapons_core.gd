# File: res://tests/test_weapons_core.gd
# Headless test of the Phase W WeaponDirector core (spec sections 3, 7):
#   A (arena) the slot table in W-D4 order; equip and scroll cycle (toast); magazine and reload timing in physics frames
#     (pistol 0.25 s per shot, 12 rounds, 1.6 s reload; R reloads); no fire while the wheel is open or blocked; aim (over-the-
#     shoulder camera, FOV < 60, walk speed); hip fire turns the player to the camera; the unarmed combo (stumble, stumble,
#     knock out, +1 heat) with daze stars; the knife arc (front only, 1.4 m, +2 heat per knockout); hand props in code;
#     every WeaponAudio cue synthesizes; no GPUParticles3D.
#   B (FreeRoam, crowd off) the wheel opens on foot, is blocked on the bike and during a cinematic, the weapon HUD hides on
#     the bike.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_core.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var targets: Array = []
var heat: Array[float] = []
var toasts: Array[String] = []
var blocked: bool = false
var shots0: int = 0
var empty_t: int = -1
var refill_t: int = -1
var ped: Pedestrian
var front: Array = []
var behind: Pedestrian
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
	print("--- TEST WEAPONS CORE ---")
	_table()
	_audio()
	_props()
	physics_frame.connect(_on_physics)


func _table() -> void:
	var ids: Array[String] = ["unarmed", "knife", "pistol", "shotgun", "rocket", "dep", "durian", "loa"]
	for i: int in 8:
		_check(String(WeaponData.SLOTS[i]["id"]) == ids[i], "slot %d is %s (W-D4 order)" % [i, ids[i]])
	var p: Dictionary = WeaponData.SLOTS[WeaponData.Slot.PISTOL]
	_check(int(p["mag"]) == 12 and is_equal_approx(float(p["cycle"]), 0.25) and is_equal_approx(float(p["reload"]), 1.6), "pistol: 12 rounds, 0.25 s per shot, 1.6 s reload")
	var s: Dictionary = WeaponData.SLOTS[WeaponData.Slot.SHOTGUN]
	_check(int(s["mag"]) == 6 and is_equal_approx(float(s["cycle"]), 0.8) and int(s["pellets"]) == 8 and is_equal_approx(float(s["cone_deg"]), 9.0), "shotgun: 6 rounds, 0.8 s pump, 8 pellets in 9°")
	var r: Dictionary = WeaponData.SLOTS[WeaponData.Slot.ROCKET]
	_check(int(r["mag"]) == 1 and is_equal_approx(float(r["reload"]), 2.5) and is_equal_approx(float(r["speed"]), 35.0) and is_equal_approx(float(r["radius"]), 6.0), "rocket: 1 round, 2.5 s reload, 35 m/s, 6 m")
	_check(is_equal_approx(float(WeaponData.SLOTS[WeaponData.Slot.KNIFE]["range"]), 1.4), "knife arc 1.4 m")
	_check(WeaponMath.in_cone(Vector3.ZERO, Vector3(0, 0, -1), deg_to_rad(30.0), 10.0, Vector3(1.0, 0.0, -5.0)), "in_cone: inside")
	_check(not WeaponMath.in_cone(Vector3.ZERO, Vector3(0, 0, -1), deg_to_rad(30.0), 10.0, Vector3(5.0, 0.0, -5.0)), "in_cone: 45° off a 30° half angle is outside")
	_check(not WeaponMath.in_cone(Vector3.ZERO, Vector3(0, 0, -1), deg_to_rad(30.0), 10.0, Vector3(0.0, 0.0, -11.0)), "in_cone: past the reach is outside")


func _audio() -> void:
	for cue: String in WeaponAudio.CUES:
		var w: AudioStreamWAV = WeaponAudio.synth(cue)
		_check(w != null and w.data.size() > 400, "cue %s is synthesized" % cue)
	_check(WeaponAudio.override_file("w_no_such_cue") == "", "no override file -> synthesized (the test never writes user://)")


func _props() -> void:
	_check(WeaponProps.build(WeaponData.Slot.UNARMED) == null, "no prop for Tay không")
	for i: int in range(1, 8):
		var n: Node3D = WeaponProps.build(i)
		_check(n != null and not n.find_children("*", "MeshInstance3D", true, false).is_empty(), "slot %d has a code-built hand prop" % i)
		if n:
			n.free()


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		arena.name = "Arena"
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		dir = World.director(arena, player, targets)
		dir.blocked_fn = func() -> bool: return blocked
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		dir.toast.connect(func(s: String) -> void: toasts.append(s))
		phase = "settle"
		t0 = frames
		return
	var t: int = frames - t0
	match phase:
		"settle":
			if t == 10:
				_cycle_checks()
				dir.fire_override = true
				shots0 = dir.shots
				_next("pistol")
		"pistol":
			_pistol(t)
		"reload_key":
			if t == 1:
				dir.reload_override = true
			if t == 3:
				_check(dir.reload_left > 0.0, "R starts a reload of a part-empty magazine")
			if t == 100:
				_check(dir.ammo[WeaponData.Slot.PISTOL] == 12, "R refilled the magazine in 1.6 s")
				dir.wheel.open()
				dir.fire_override = true
				shots0 = dir.shots
				_next("wheel_open")
		"wheel_open":
			if t == 30:
				_check(dir.shots == shots0, "no weapon fires while the wheel is open")
				dir.wheel.close(false)
				Engine.time_scale = 1.0
				blocked = true
				dir.aim_override = true
				_next("blocked")
		"blocked":
			if t == 30:
				_check(dir.shots == shots0 and not dir.aiming and not player.aiming, "blocked (riding / cinematic / service): no aim, no fire")
				blocked = false
				dir.fire_override = false
				player.input_override = Vector2(0.0, -1.0)
				player.sprint_override = true
				_next("aim")
		"aim":
			if t == 40:
				_check(player.aiming and player.aim_blend > 0.99, "right mouse aims (blend %.2f)" % player.aim_blend)
				_check(player.camera.fov < 60.0, "the FOV narrows while aiming (%.1f)" % player.camera.fov)
				_check(absf(player.camera.position.x - ThirdPersonController.AIM_SIDE) < 0.05, "over-the-shoulder offset (x %.2f)" % player.camera.position.x)
				_check(player.horizontal_speed <= ThirdPersonController.AIM_SPEED + 0.05, "walk speed while aiming, even with Shift (%.2f m/s)" % player.horizontal_speed)
				dir.aim_override = false
				player.input_override = Vector2.ZERO
				player.sprint_override = false
				_next("hip")
		"hip":
			if t == 20:
				player.teleport(Vector3.ZERO, 0.0)
				player.pitch = 0.0
				dir.equip(WeaponData.Slot.UNARMED)
				player.yaw = 0.8
				player.model.rotation.y = 0.0
				dir.cooldown = 0.0
				dir.fire_override = true
			if t == 21:
				dir.fire_override = false
				_check(is_equal_approx(player.model.rotation.y, 0.8), "hip fire turns the body to the camera (%.2f)" % player.model.rotation.y)
				player.set_facing(0.0)
				player.pitch = 0.0
				ped = World.ped(arena, Vector3(0.0, 0.0, -1.0), 51, player)
				targets.append(ped)
				heat.clear()
				_next("combo")
		"combo":
			_combo(t)
		"knife":
			_knife(t)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _cycle_checks() -> void:
	dir.cycle(-1)
	_check(dir.current == 7 and toasts.back() == "Loa kẹo kéo", "scroll up from Tay không wraps to slot 7, with a toast")
	dir.cycle(1)
	_check(dir.current == 0 and toasts.back() == "Tay không", "scroll down wraps back to slot 0")
	dir.wheel.selected.emit(WeaponData.Slot.PISTOL)
	_check(dir.current == WeaponData.Slot.PISTOL and dir.wheel.current == WeaponData.Slot.PISTOL, "a wheel selection equips the pistol")
	_check(dir.held != null and dir.held.get_parent() is BoneAttachment3D, "the pistol prop sits in the right hand (Wrist.R attachment)")
	_check(dir.ammo_text(WeaponData.Slot.PISTOL) == "12 / ∞" and dir.hud.ammo == "12 / ∞", "HUD and wheel show '12 / ∞'")


func _pistol(t: int) -> void:
	if t == 60:
		_check(dir.shots - shots0 == 4, "0.25 s per shot: 4 shots in 60 physics frames (got %d)" % (dir.shots - shots0))
	if t == 175:
		_check(dir.shots - shots0 == 12 and dir.ammo[WeaponData.Slot.PISTOL] == 0 and dir.reload_left > 0.0, "12 rounds, then an automatic reload")
		_check(dir.hud.reloading, "the HUD shows the reload")
	if empty_t < 0 and dir.ammo[WeaponData.Slot.PISTOL] == 0:
		empty_t = t
	if empty_t > 0 and refill_t < 0 and dir.ammo[WeaponData.Slot.PISTOL] > 0:
		refill_t = t
	if t == 290:
		_check(empty_t > 0 and refill_t > 0 and absi(refill_t - empty_t - 96) <= 2, "the reload takes 1.6 s = 96 physics frames (empty at frame %d, refilled at %d)" % [empty_t, refill_t])
		dir.fire_override = false
		_next("reload_key")


func _combo(t: int) -> void:
	if t == 2 or t == 30 or t == 58:
		dir.cooldown = 0.0   # the punches come 28 frames apart (inside the 1.5 s combo window); skip the 0.35 s cooldown
		dir.fire_override = true
	if t == 3 or t == 31 or t == 59:
		dir.fire_override = false
	if t == 6:
		_check(ped.state == Pedestrian.State.STUMBLE and heat.is_empty(), "punch 1: stumble, no heat")
	if t == 34:
		_check(ped.state == Pedestrian.State.STUMBLE, "punch 2: stumble")
	if t == 62:
		_check(ped.state == Pedestrian.State.KNOCKED_OUT, "punch 3 knocks out (state %d)" % ped.state)
		_check(heat.size() == 1 and is_equal_approx(heat[0], WeaponData.HEAT_KO_UNARMED), "+1 heat for the unarmed knockout (%s)" % str(heat))
		_check(dir.fx.cine.find_children("Star*", "", true, false).size() >= 3, "daze stars over the knocked-out person")
		targets.clear()
		heat.clear()
		dir.equip(WeaponData.Slot.KNIFE)
		for x: float in [0.6, -0.6]:
			var f: Pedestrian = World.ped(arena, Vector3(x, 0.0, -1.04), 60 + int(x * 10.0), player)
			front.append(f)
			targets.append(f)
		behind = World.ped(arena, Vector3(0.0, 0.0, 1.0), 70, player)
		targets.append(behind)
		_next("knife")


func _knife(t: int) -> void:
	if t == 5:
		dir.cooldown = 0.0
		dir.fire_override = true
	if t == 6:
		dir.fire_override = false
	if t == 9:
		_check((front[0] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT and (front[1] as Pedestrian).state == Pedestrian.State.KNOCKED_OUT, "the knife arc knocks out both people in front")
		_check(behind.state == Pedestrian.State.IDLE, "nobody behind is hit")
		var sum: float = 0.0
		for h: float in heat:
			sum += h
		_check(is_equal_approx(sum, 2.0 * WeaponData.HEAT_KNIFE), "+2 heat per knife knockout (%s)" % str(heat))
		_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
		_start_b()


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
	phase = "b"
	t0 = frames


func _wheel_opens(ww: WeaponWheel) -> bool:
	ww.press()
	ww.step_real(0.2)
	var o: bool = ww.is_open()
	ww.cancel()
	ww.step_real(0.2)
	return o


func _b_done() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: WEAPONS CORE (table, equip / cycle, ammo + reload timing, aim camera, hip fire, combo, knife, HUD, FreeRoam blocking)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)


func _process(_d: float) -> bool:
	if phase != "b":
		return false
	var t: int = frames - t0
	var ww: WeaponWheel = roam.get("weapon_wheel")
	if t == 60 and not roam.has_meta("b1"):
		roam.set_meta("b1", true)
		var wd: WeaponDirector = roam.get("weapons")
		_check(wd != null and ww != null and wd.player == roam.get("player"), "FreeRoam builds the weapons when mayhem_enabled (default)")
		ww.manual = true
		_check(_wheel_opens(ww), "on foot the wheel opens in FreeRoam")
		roam.call("mount_bike")
	elif t == 64 and not roam.has_meta("b2"):
		roam.set_meta("b2", true)
		_check(not _wheel_opens(ww) and is_equal_approx(Engine.time_scale, 1.0), "riding: the wheel is blocked (W-D9 on foot only)")
		_check(not (roam.get("weapon_hud") as CanvasLayer).visible, "the weapon HUD hides on the bike")
		roam.call("dismount_bike")
	elif t == 68 and not roam.has_meta("b3"):
		roam.set_meta("b3", true)
		_check((roam.get("weapon_hud") as CanvasLayer).visible, "the weapon HUD is back on foot")
		var tl: CineTimeline = (load("res://tests/support/cine_test_timeline.gd") as GDScript).new()
		tl.build()
		var cp: CinePlayer = roam.call("play_cinematic", tl, {"manual": true, "music": false})
		_check(cp != null, "test setup: a cinematic plays")
		_check(not _wheel_opens(ww), "during a cinematic the wheel is blocked")
		var n: int = 0
		while cp != null and is_instance_valid(cp) and roam.get("cine_player") != null and n < 400:
			cp.step(1.0 / 60.0)
			n += 1
		_check(_wheel_opens(ww), "after the cinematic the wheel opens again")
		_b_done()
	return false
