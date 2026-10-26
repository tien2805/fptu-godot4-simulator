# File: res://tests/test_bike_nitro.gd
# Headless test of the Tokyo Drift bike features (spec D2X-8 / D2X-9, plan 2026-10-27-d2x-drift.md):
#   - nitro off by default (Shift does nothing, no gauge); FreeRoam's bike has it on;
#   - charge sources: drifting (25 per second, x1.5 in a zone), near misses (+8), add_drift_charge (clamped to 100);
#   - the Shift gate (refused under 34), a burn of 3 s x charge / 100 that spends the charge, nitro_started / nitro_ended,
#     +8 m/s over the profile cap (never more), the extra speed fading after the burn, the FOV punch, the flame, the ram
#     flag (nitro_active), the burn ending on lock and on disable (the gauge hides too), the gauge only while ridden with
#     the bike camera current;
#   - duck: Ctrl held = is_ducking, 10 % less steering, the rider lower;
#   - revs: the exhaust blip without the owner file (pitch up then back to idle, +4 dB over the riding level), the rate
#     limit and force, the owner's bike_rev from a temp folder with at most 2 voices, staged on a start line (W revs,
#     GO unlocks at full throttle);
#   - the spin kick: Q / E while drifting hits targets on both sides within 3.6 m (side 0 through take_kick and kick_hit),
#     the 2 nearest only, 1.2 s cooldown blocking side kicks, the hit-stop restores the time scale; a side kick when not
#     drifting is unchanged;
#   - Stage 1 (Main.tscn) and Stage 2 never enable nitro (Shift with a full charge does nothing);
#   - FreeRoam: the on-foot controller neither sprints nor walks while riding with Shift and Ctrl held.
# Owner sound folders are temp folders under OS.get_cache_dir() (never user://). Counts physics frames (max_fps 60).
# Run:  godot --headless --path . --script tests/test_bike_nitro.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const DT: float = 1.0 / 60.0

var fails: Array[String] = []
var arena: Node3D
var bike: PlayerBike
var empty_dir: String = ""
var tmp_dir: String = ""
var started: int = 0
var ended: int = 0


class Stub:
	extends Node3D
	## A kick target that rides along with the bike at a fixed offset in the bike's frame (lat: + right, along: + ahead).
	var bike: PlayerBike
	var lat: float = 0.0
	var along: float = 0.0
	var kicked: Array = []
	var alive: bool = true

	func kickable() -> bool:
		return alive

	func ground_pos() -> Vector3:
		var z: Vector3 = bike.global_transform.basis.z
		var f := Vector3(-z.x, 0.0, -z.z).normalized()
		var r := Vector3(-f.z, 0.0, f.x)
		return bike.global_position + r * lat + f * along

	func take_kick(away: Vector2) -> String:
		kicked.append(away)
		return "wobble"

	func _physics_process(_d: float) -> void:
		global_position = ground_pos()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  x ", msg)
	else:
		print("  ok ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST BIKE NITRO (nitro, duck, revs, spin kick) ---")
	PlayerBike.clear_owner_sfx()
	var cache: String = OS.get_cache_dir().replace("\\", "/").trim_suffix("/")
	empty_dir = cache + "/fptu_test_bike_nitro_no_sfx/"
	tmp_dir = cache + "/fptu_test_bike_nitro_sfx/"
	DirAccess.make_dir_recursive_absolute(empty_dir)
	PlayerBike.sfx_dir = empty_dir
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _release_all() -> void:
	for a: String in ["gas", "brake", "steer_left", "steer_right", "drift", "nitro", "duck"]:
		Input.action_release(a)


func _reset(at: Vector3, speed: float = 0.0) -> void:
	bike.global_position = at
	bike.rotation = Vector3.ZERO
	bike.velocity = Vector3.ZERO
	bike.current_speed_ms = speed
	bike.is_controls_locked = false


func _run() -> void:
	await _frames(1)
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena, 3000.0)
	bike = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
	arena.add_child(bike)
	bike.apply_speed_profile(PlayerBike.STAGE_PROFILE)
	bike.chase_cam.make_current()
	bike.nitro_started.connect(func() -> void: started += 1)
	bike.nitro_ended.connect(func() -> void: ended += 1)
	_reset(Vector3(0.0, -0.12, 1200.0))
	await _frames(3)
	await _part_off()
	await _part_charge()
	await _part_burn()
	await _part_end_cases()
	await _part_duck()
	await _part_revs()
	await _part_spin()
	await _part_time_owner()
	await _part_stages()
	await _part_free_roam()
	_finish()


## Nitro off by default: Shift with a full charge does nothing, no gauge.
func _part_off() -> void:
	_check(not bike.nitro_enabled and bike.nitro_gauge == null and bike.nitro_fx == null, "nitro is off by default (no gauge, no flame built)")
	bike.drift_charge = 100.0
	Input.action_press("nitro")
	await _frames(2)
	Input.action_release("nitro")
	_check(not bike.nitro_active() and bike.nitro_count == 0 and started == 0 and bike.nitro_refusals == 0, "Shift does nothing while nitro is off")
	bike.drift_charge = 0.0
	var fr := Node3D.new()
	fr.name = "FakeRoam"
	arena.add_child(fr)
	fr.set_script(load("res://scripts/FreeRoam.gd"))
	fr.call("_build_bike")
	var rb: PlayerBike = fr.get("bike") as PlayerBike
	_check(rb != null and rb.nitro_enabled and rb.nitro_gauge != null and not rb.nitro_gauge.visible, "FreeRoam's owner bike has nitro on (gauge built, hidden while parked)")
	_check(String(fr.get("HINT_RIDING")).contains("[SHIFT] nitro") and String(fr.get("HINT_RIDING")).contains("[CTRL] cúi"), "FreeRoam's riding hint shows [SHIFT] nitro and [CTRL] cúi")
	fr.free()
	bike.set_nitro_enabled(true)
	await _frames(2)
	_check(bike.nitro_gauge != null and bike.nitro_gauge.visible and bike.nitro_fx != null and not bike.nitro_fx.on, "enabled and ridden with the bike camera: the gauge shows, the flame is off")


## Charge from drifting (25 per second, x1.5 in a zone), near misses, add_drift_charge.
func _part_charge() -> void:
	_reset(Vector3(0.0, -0.12, 1200.0), 14.0)
	Input.action_press("gas")
	Input.action_press("steer_left")
	Input.action_press("drift")
	await _frames(4)
	_check(bike.is_drifting, "test setup: the bike drifts")
	bike.drift_charge = 0.0
	await _frames(60)
	var c1: float = bike.drift_charge
	_check(c1 > 22.0 and c1 < 27.0, "1 s of drifting charges about 25 (%.1f)" % c1)
	bike.drift_charge = 0.0
	bike.drift_charge_mult = 1.5
	await _frames(60)
	var c2: float = bike.drift_charge
	_check(c2 > 34.0 and c2 < 40.0, "1 s of drifting inside a drift zone (x1.5) charges about 37.5 (%.1f)" % c2)
	bike.drift_charge_mult = 1.0
	_release_all()
	await _frames(2)
	bike.drift_charge = 0.0
	var car := StaticBody3D.new()
	car.add_to_group("traffic_obstacle")
	arena.add_child(car)
	bike.current_speed_ms = 20.0
	bike._on_near_body_entered(car)
	bike._on_near_body_exited(car)
	_check(is_equal_approx(bike.drift_charge, PlayerBike.NEAR_MISS_CHARGE), "a near miss gives 8 charge (%.1f)" % bike.drift_charge)
	car.free()
	bike.add_drift_charge(250.0)
	_check(is_equal_approx(bike.drift_charge, 100.0), "add_drift_charge clamps at 100")
	bike.add_drift_charge(-500.0)
	_check(is_equal_approx(bike.drift_charge, 0.0), "add_drift_charge clamps at 0")


## The Shift gate, the burn (speed, duration, FOV, flame, ram flag), the fade after it.
func _part_burn() -> void:
	_reset(Vector3(0.0, -0.12, 1200.0))
	Input.action_press("gas")
	await _frames(200)
	_check(absf(bike.current_speed_ms - 22.5) < 0.05, "test setup: at the stage cap (%.2f)" % bike.current_speed_ms)
	bike.drift_charge = 20.0
	var ref0: int = bike.nitro_refusals
	Input.action_press("nitro")
	await _frames(1)
	Input.action_release("nitro")
	await _frames(1)
	_check(not bike.nitro_active() and bike.nitro_refusals == ref0 + 1 and is_equal_approx(bike.drift_charge, 20.0) and started == 0, "Shift under 34 charge is refused (charge kept)")
	bike.drift_charge = 50.0
	var fov0: float = bike.chase_cam.fov
	Input.action_press("nitro")
	var w: int = 0
	while not bike.nitro_active() and w < 5:
		await _frames(1)
		w += 1
	Input.action_release("nitro")
	_check(bike.nitro_active() and started == 1 and is_equal_approx(bike.nitro_len, 1.5) and is_equal_approx(bike.drift_charge, 0.0), "Shift at 50: nitro_started, a 1.5 s burn, the charge spent")
	_check(bike.chase_cam.fov > fov0 + 5.0, "the FOV punch lands at once (%.1f -> %.1f)" % [fov0, bike.chase_cam.fov])
	_check(bike.nitro_fx.on and bike.nitro_fx.flame.visible and bike.nitro_fx.sparks.emitting, "the blue flame burns")
	var n: int = 1
	while bike.nitro_active() and n < 200:
		await _frames(1)
		n += 1
	_check(absf(float(n) - 90.0) <= 2.0 and ended == 1, "the 50-charge burn lasts 1.5 s (%d frames), nitro_ended once" % n)
	_check(not bike.nitro_fx.on, "the flame goes out")
	await _frames(60)
	# full charge: the cap +8 m/s, never more
	bike.drift_charge = 100.0
	_check(bike.fire_nitro(), "fire_nitro() with a full charge")
	var top: float = 0.0
	var fov_max: float = 0.0
	n = 1
	while bike.nitro_active() and n < 400:
		await _frames(1)
		top = maxf(top, bike.current_speed_ms)
		fov_max = maxf(fov_max, bike.chase_cam.fov)
		n += 1
	_check(absf(float(n) - 180.0) <= 2.0, "a full burn lasts 3 s (%d frames)" % n)
	_check(top > 22.5 + 7.5 and top <= 22.5 + PlayerBike.NITRO_BONUS_MS + 0.05, "nitro: +8 m/s over the 22.5 cap and never more (top %.2f)" % top)
	_check(fov_max > fov0 + 7.0, "the FOV opens while it burns (max %.1f, base %.1f)" % [fov_max, fov0])
	await _frames(1)
	_check(bike.current_speed_ms > 28.0, "after the burn the extra speed fades instead of snapping off (%.2f)" % bike.current_speed_ms)
	await _frames(150)
	_check(absf(bike.current_speed_ms - 22.5) < 0.1, "... back at the cap within ~2.5 s (%.2f)" % bike.current_speed_ms)
	_release_all()


## The burn ends on lock and on disable (the gauge hides), the gauge rules, nitro off.
func _part_end_cases() -> void:
	_reset(Vector3(0.0, -0.12, 1200.0), 15.0)
	await _frames(2)
	var e0: int = ended
	bike.drift_charge = 80.0
	bike.fire_nitro()
	await _frames(5)
	bike.is_controls_locked = true
	await _frames(2)
	_check(not bike.nitro_active() and ended == e0 + 1 and not bike.nitro_fx.on, "locking the bike ends the burn (nitro_ended)")
	_check(not bike.fire_nitro(), "no nitro while locked")
	bike.is_controls_locked = false
	bike.drift_charge = 80.0
	bike.fire_nitro()
	await _frames(3)
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not bike.nitro_active() and ended == e0 + 2 and not bike.nitro_gauge.visible, "parking (process disabled) ends the burn and hides the gauge")
	bike.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2)
	_check(bike.nitro_gauge.visible, "ridden again: the gauge is back")
	var cam := Camera3D.new()
	arena.add_child(cam)
	cam.make_current()
	await _frames(2)
	_check(not bike.nitro_gauge.visible, "another camera current (cinematic, replay): the gauge hides")
	bike.chase_cam.make_current()
	cam.free()
	await _frames(2)
	bike.drift_charge = 60.0
	bike.fire_nitro()
	bike.set_nitro_enabled(false)
	await _frames(2)
	_check(not bike.nitro_active() and not bike.nitro_gauge.visible, "set_nitro_enabled(false) ends the burn and hides the gauge")
	bike.set_nitro_enabled(true)
	bike.drift_charge = 0.0


## Ctrl held: ducking, 10 % less steering, the rider lower.
func _part_duck() -> void:
	_reset(Vector3(0.0, -0.12, 1200.0), 22.5)
	Input.action_press("gas")
	Input.action_press("steer_right")
	await _frames(30)
	var y0: float = bike.rotation.y
	await _frames(30)
	var rate_plain: float = absf(wrapf(bike.rotation.y - y0, -PI, PI))
	var rider_y0: float = bike.rider_node.position.y
	Input.action_press("duck")
	await _frames(30)
	_check(bike.is_ducking(), "Ctrl held: is_ducking()")
	var y1: float = bike.rotation.y
	await _frames(30)
	var rate_duck: float = absf(wrapf(bike.rotation.y - y1, -PI, PI))
	_check(absf(rate_duck / maxf(rate_plain, 1e-4) - PlayerBike.DUCK_STEER) < 0.04, "ducking steers 10 %% less (%.3f vs %.3f rad/s)" % [rate_duck, rate_plain])
	_check(bike.rider_node.position.y < rider_y0 - 0.05 and bike.duck_w > 0.99, "the rider lies flat on the tank (y %.2f -> %.2f)" % [rider_y0, bike.rider_node.position.y])
	Input.action_release("duck")
	await _frames(30)
	_check(not bike.is_ducking() and absf(bike.rider_node.position.y - rider_y0) < 0.005, "Ctrl released: upright again")
	_release_all()


## Revs: the exhaust blip without the owner file, the rate limit, the owner's file (2 voices), staged on a start line.
func _part_revs() -> void:
	_reset(Vector3(0.0, -0.12, 1200.0))
	await _frames(30)
	_check(PlayerBike.owner_file(PlayerBike.SFX_REV) == "" and bike.rev_stream == null, "test setup: no owner bike_rev (empty temp folder)")
	bike.set_staged(true)
	await _frames(20)
	var idle: float = bike.idle_pitch()
	_check(bike.is_controls_locked and is_equal_approx(bike.current_speed_ms, 0.0) and absf(bike.engine_player.pitch_scale - idle) < 0.03, "staged: locked, stopped, the engine idling (pitch %.2f)" % bike.engine_player.pitch_scale)
	var r0: int = bike.revs
	_check(bike.rev_blip(true) and bike.rev_source == "blip", "without the file a rev is a throttle blip of the exhaust loop")
	var peak: float = 0.0
	var vol_ok: bool = true
	for i: int in 50:
		await _frames(1)
		peak = maxf(peak, bike.engine_player.pitch_scale)
		if i < 40:
			vol_ok = vol_ok and absf(bike.engine_player.volume_db - bike.rev_db()) < 0.01
	var want_peak: float = idle * PlayerBike.REV_BLIP_PITCH / 0.62
	_check(absf(peak - want_peak) < 0.05, "the blip peaks at %.2f (idle %.2f; 0.62 -> 1.2 for the owner loop)" % [peak, idle])
	_check(vol_ok and is_equal_approx(bike.rev_db(), bike.riding_engine_db() + 4.0), "the rev plays 4 dB over the riding engine level")
	await _frames(10)
	_check(absf(bike.engine_player.pitch_scale - idle) < 0.03, "back to idle after 0.8 s (%.2f)" % bike.engine_player.pitch_scale)
	_check(absf(PlayerBike.rev_blip_pitch(0.22, 0.62) - 1.2) < 0.001 and is_equal_approx(PlayerBike.rev_blip_pitch(0.8, 0.62), 0.62), "rev_blip_pitch: 0.62 -> 1.2 at 0.22 s -> 0.62 at 0.8 s")
	await _frames(30)
	Input.action_press("gas")
	await _frames(1)
	Input.action_release("gas")
	await _frames(1)
	var r1: int = bike.revs
	Input.action_press("gas")
	await _frames(1)
	Input.action_release("gas")
	await _frames(1)
	_check(r1 == r0 + 2 and bike.revs == r1, "W on the line revs, a second press within 0.35 s does not (%d, %d)" % [r1 - r0, bike.revs - r1])
	await _frames(25)
	Input.action_press("gas")
	await _frames(2)
	_check(bike.revs == r1 + 1, "... after 0.35 s it revs again")
	bike.set_staged(false)
	_check(not bike.is_controls_locked and not bike.staged and absf(bike.engine_player.pitch_scale - (PlayerBike.exhaust_pitch(0.0, 1.0) if bike.owner_exhaust else 1.1)) < 0.01, "GO: unlocked, the engine loop jumps to full throttle")
	await _frames(20)
	_check(bike.current_speed_ms > 3.0, "GO: the bike launches on W (%.1f m/s)" % bike.current_speed_ms)
	_release_all()
	# the owner's bike_rev from a temp folder: plays as a file, at most 2 voices
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	_check(_silent_wav(1.7).save_to_wav(tmp_dir + "bike_rev.wav") == OK, "temp bike_rev written (OS cache folder, not user://)")
	PlayerBike.sfx_dir = tmp_dir
	PlayerBike.warm_owner_sfx()
	var n: int = 0
	while PlayerBike.owner_sfx_state(PlayerBike.SFX_REV) != 2 and n < 120:
		await _frames(1)
		n += 1
	_check(PlayerBike.owner_sfx(PlayerBike.SFX_REV, false) != null, "the owner's bike_rev loads on a worker thread")
	bike.rev_stream = null
	_check(bike.rev_blip(true) and bike.rev_source == "file" and bike.rev_voices_playing() == 1, "with the file a rev plays the recording")
	bike.rev_blip(true)
	bike.rev_blip(true)
	_check(bike.rev_voices_playing() == 2, "at most 2 rev voices overlap")
	var vdb: float = (bike.get_node("Rev0") as AudioStreamPlayer3D).volume_db
	_check(absf(vdb - bike.rev_db()) < 0.01, "the recording plays at rev_db (%.1f dB)" % vdb)
	for p: AudioStreamPlayer3D in [bike.get_node("Rev0"), bike.get_node("Rev1")]:
		p.stop()
	PlayerBike.sfx_dir = empty_dir
	PlayerBike.clear_owner_sfx()
	bike.rev_stream = null


## The spin kick: both sides, max 2, side 0 through the normal path, the cooldown, the hit-stop, side kicks unchanged.
func _part_spin() -> void:
	_reset(Vector3(0.0, -0.12, 1200.0), 16.0)
	var combat := PlayerBikeCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	var tg: Array = []
	combat.setup(bike, {"targets": tg})
	combat.enabled = true
	var stubs: Array = []
	for o: Vector2 in [Vector2(-2.6, 0.2), Vector2(3.0, -0.4), Vector2(4.5, 0.0), Vector2(1.0, 3.5)]:
		var s := Stub.new()
		s.bike = bike
		s.lat = o.x
		s.along = o.y
		arena.add_child(s)
		stubs.append(s)
		tg.append(s)
	var hits: Array = []
	var kicked_sides: Array = []
	combat.kick_hit.connect(func(t: Node3D, side: int) -> void: hits.append([t, side]))
	combat.kicked.connect(func(side: int) -> void: kicked_sides.append(side))
	# a side kick while not drifting: unchanged
	await _frames(2)
	_check(not bike.is_drifting and combat.kick(-1) and combat.kicking() and not combat.spinning(), "not drifting: Q is the normal side kick")
	await _frames(40)
	_check(hits.size() == 1 and int(hits[0][1]) == -1 and hits[0][0] == stubs[0], "the side kick hits the left-hand target (side -1, reach 2.8 m)")
	hits.clear()
	kicked_sides.clear()
	for s2: Stub in stubs:
		s2.kicked.clear()
	# drifting: Q is a spin
	Input.action_press("gas")
	Input.action_press("steer_left")
	Input.action_press("drift")
	await _frames(4)
	_check(bike.is_drifting, "test setup: drifting")
	_check(combat.kick(-1) and combat.spinning() and kicked_sides == [0], "Q while drifting: a spin kick (kicked with side 0)")
	var ts_min: float = 1.0
	for i: int in 40:
		await _frames(1)
		ts_min = minf(ts_min, Engine.time_scale)
	var hit_nodes: Array = hits.map(func(h: Array) -> Node3D: return h[0])
	_check(hits.size() == 2 and hit_nodes.has(stubs[0]) and hit_nodes.has(stubs[1]) and int(hits[0][1]) == 0 and int(hits[1][1]) == 0, "the spin hits both sides within 3.6 m through kick_hit with side 0")
	_check((stubs[0] as Stub).kicked.size() == 1 and (stubs[1] as Stub).kicked.size() == 1 and (stubs[2] as Stub).kicked.is_empty() and (stubs[3] as Stub).kicked.is_empty(), "take_kick on the two in reach, none on the far ones (4.5 m to the side, 3.5 m ahead)")
	_check(ts_min < 0.2, "a 0.15 s hit-stop on the hit (time scale %.2f)" % ts_min)
	await _frames(30)
	_check(is_equal_approx(Engine.time_scale, 1.0) and not combat.spinning() and is_zero_approx(bike.rider_node.rotation.y), "the hit-stop and the spin end (time scale 1, rider facing forward)")
	_release_all()
	await _frames(2)
	_check(not combat.kick(1), "the 1.2 s spin cooldown blocks side kicks too")
	await _frames(40)
	# max 2: three targets in reach -> the 2 nearest
	for s3: Stub in stubs:
		s3.kicked.clear()
	(stubs[2] as Stub).lat = 1.5   # now the nearest
	hits.clear()
	Input.action_press("gas")
	Input.action_press("steer_right")
	Input.action_press("drift")
	await _frames(4)
	_check(combat.kick(1) and combat.spin_dir > 0.0, "E while drifting spins the other way")
	await _frames(20)
	var hit2: Array = hits.map(func(h: Array) -> Node3D: return h[0])
	_check(hits.size() == 2 and hit2.has(stubs[2]) and hit2.has(stubs[0]) and not hit2.has(stubs[1]), "three in reach: the 2 nearest are hit (%d)" % hits.size())
	_release_all()
	await _frames(40)
	combat.free()
	for s4: Node in stubs:
		s4.free()


## A slow motion that owns the time scale (RadialWheel.scale_owner: the weapon wheel, a combat or chase slow motion) is
## never cut short: no spin-kick or near-miss hit-stop writes over it, and GameFX's slow-motion timeout does not put 1.0
## back while an owner exists.
func _part_time_owner() -> void:
	var fx: Node = root.get_node_or_null("GameFX")
	var owner_obj := RefCounted.new()
	_reset(Vector3(0.0, -0.12, 1200.0), 16.0)
	var combat := PlayerBikeCombat.new()
	combat.name = "Combat2"
	arena.add_child(combat)
	var tg: Array = []
	combat.setup(bike, {"targets": tg})
	combat.enabled = true
	var stub := Stub.new()
	stub.bike = bike
	stub.lat = 2.4
	arena.add_child(stub)
	tg.append(stub)
	Input.action_press("gas")
	Input.action_press("steer_left")
	Input.action_press("drift")
	await _frames(4)
	RadialWheel.scale_owner = owner_obj
	Engine.time_scale = 0.5
	var lo: float = 1.0
	var hi: float = 0.0
	_check(combat.kick(-1) and combat.spinning(), "test setup: a spin kick under a slow motion that owns the time scale")
	for i: int in 30:
		await _frames(1)
		lo = minf(lo, Engine.time_scale)
		hi = maxf(hi, Engine.time_scale)
	_check(stub.kicked.size() == 1 and is_equal_approx(lo, 0.5) and is_equal_approx(hi, 0.5), "the spin hit lands but its hit-stop leaves the owner's time scale alone (%.2f..%.2f)" % [lo, hi])
	_release_all()
	var car := StaticBody3D.new()
	car.add_to_group("traffic_obstacle")
	arena.add_child(car)
	bike.near_miss_chain = 2
	bike.near_miss_chain_timer = 3.0
	bike.current_speed_ms = 20.0
	bike.is_controls_locked = false
	bike._on_near_body_entered(car)
	bike._on_near_body_exited(car)
	await _frames(2)
	_check(bike.near_miss_chain == 3 and is_equal_approx(Engine.time_scale, 0.5), "a 3-chain near miss under the owner: no hit-stop (time scale %.2f)" % Engine.time_scale)
	car.free()
	# GameFX: a hit-stop that started before the owner took over does not restore 1.0 over it
	RadialWheel.scale_owner = null
	Engine.time_scale = 1.0
	if fx:
		fx.call("hit_stop", 0.15, 0.05)
		_check(is_equal_approx(Engine.time_scale, 0.05), "GameFX.hit_stop without an owner writes the time scale")
		RadialWheel.scale_owner = owner_obj
		Engine.time_scale = 0.4
		await create_timer(0.35, true, false, true).timeout
		_check(is_equal_approx(Engine.time_scale, 0.4), "its timeout keeps the owner's 0.4 (no 1.0 over it)")
		fx.call("slow_motion", 0.2, 0.2)
		_check(is_equal_approx(Engine.time_scale, 0.4), "GameFX.slow_motion writes nothing while an owner exists")
	RadialWheel.scale_owner = null
	Engine.time_scale = 1.0
	combat.free()
	stub.free()
	await _frames(2)


## Stage 1 and Stage 2 never enable nitro.
func _part_stages() -> void:
	for path: String in ["res://scenes/Main.tscn", "res://scenes/Stage2_Parking.tscn"]:
		var sc: Node = (load(path) as PackedScene).instantiate()
		root.add_child(sc)
		await _frames(10)
		var sb: PlayerBike = sc.get_node_or_null("PlayerBike") as PlayerBike
		if sb == null:
			_check(false, "%s has a PlayerBike" % path)
			sc.free()
			continue
		sb.is_controls_locked = false
		sb.drift_charge = 100.0
		Input.action_press("nitro")
		await _frames(2)
		Input.action_release("nitro")
		await _frames(2)
		_check(not sb.nitro_enabled and not sb.nitro_active() and sb.nitro_count == 0 and sb.nitro_gauge == null, "%s: nitro never on (Shift with a full charge does nothing, no gauge)" % path.get_file())
		sc.queue_free()
		await _frames(3)


## FreeRoam: riding, Shift and Ctrl held: the on-foot controller neither sprints nor walks.
func _part_free_roam() -> void:
	var fr: Node = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	fr.set("crowd_enabled", false)
	fr.set("mayhem_enabled", false)
	root.add_child(fr)
	await _frames(20)
	fr.call("mount_bike")
	await _frames(5)
	var pl: ThirdPersonController = fr.get("player")
	var rb: PlayerBike = fr.get("bike")
	_check(bool(fr.get("mounted")) and rb.nitro_enabled and rb.nitro_gauge.visible, "FreeRoam riding: nitro on, the gauge shows")
	var stamina0: float = pl.stamina
	rb.drift_charge = 0.0
	Input.action_press("nitro")
	Input.action_press("duck")
	Input.action_press("sprint")
	Input.action_press("walk")
	await _frames(30)
	_check(not pl.is_sprinting and is_equal_approx(pl.stamina, stamina0) and pl.process_mode == Node.PROCESS_MODE_DISABLED and not pl.controls_enabled, "riding with Shift and Ctrl held: the on-foot controller is off (no sprint, no walk, stamina kept)")
	_check(rb.is_ducking(), "... and Ctrl ducks the rider instead")
	_release_all()
	Input.action_release("sprint")
	Input.action_release("walk")
	fr.queue_free()
	await _frames(3)


func _silent_wav(secs: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	var d := PackedByteArray()
	d.resize(int(secs * 22050.0) * 2)
	w.data = d
	return w


func _finish() -> void:
	_release_all()
	if arena and is_instance_valid(arena):
		arena.free()
	PlayerBike.clear_owner_sfx()
	PlayerBike.sfx_dir = "user://sfx/"
	DirAccess.remove_absolute(tmp_dir + "bike_rev.wav")
	DirAccess.remove_absolute(tmp_dir)
	DirAccess.remove_absolute(empty_dir)
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("SUCCESS: BIKE NITRO (charge, Shift gate, burn, fade, ram flag, gauge, duck, revs, spin kick, stages, free roam)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
