# File: res://tests/test_owner_bike.gd
# Headless test of the owner's bike (spec owner-bike OB-D1..D5, OB-D7): the OwnerBikeBuilder parts exist and carry no brand
# text (the only Label3D is the fake plate); the headlight points forward (-Z in bike space) and [L] toggles low / high
# beam; the SpotLight follows the time of day (scene preset read once, then set_time_of_day); the strobe alternates red
# and blue and is off while parked (process disabled); the brake light brightens while braking; speed caps (Stage 1 scene
# 22.5 m/s, STAGE_PROFILE 22.5, OWNER_PROFILE 33.3 and the acceleration times, FreeRoam._build_bike applies the owner
# profile, BikeChase caps and restores it); no tunnelling through a 0.1 m wall at top speed; owner sound overrides come
# from a temp sfx folder (empty folder = the res:// wav fallbacks; a temp bike_exhaust / bike_horn = the owner loop and
# melody); the horn melody: a tap plays, a second tap stops; pedestrians within 14 m cheer, beyond it or fleeing do not,
# a late walker joins in, the dancers stop at once after an early stop and by themselves at the melody's end.
# Fix round: the sfx folders live under OS.get_cache_dir() (never user://); the roam music ducks while the melody plays
# and comes back after a tap-stop, the natural end (which also stops the player and never loops), parking mid-melody
# (process disabled or park()) and the bike leaving the tree mid-melody; park() turns the strobe and headlight off for
# good; the headlight is off while disabled at night; the haze follows the high beam's angle; the lamp materials survive a
# ViceStyle classic -> vice -> classic round trip (GameFX.art_style_changed); BikeChase caps through start() / stop() and
# a chase freed without stop() gives the profile back.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_owner_bike.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const BRANDS: Array[String] = ["YAMAHA", "HONDA", "SIRIUS", "JUPITER", "EXCITER", "SUZUKI", "WAVE"]

var fails: Array[String] = []
var f: int = 0
var arena: Node3D
var bike: PlayerBike
var bike2: PlayerBike
var colours: Dictionary = {}
var red_ok: bool = true
var glow_ok: bool = true
var t100: int = -1
var t120: int = -1
var over_cap: bool = false
var min_z: float = 0.0
var near: Array = []
var far: Array = []
var fleer: Pedestrian
var late: Pedestrian
var peds: Array = []
var late_t: int = -1
var empty_dir: String = ""
var tmp_dir: String = ""
var md: Object


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)
	else:
		print("  ok ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	print("--- TEST OWNER BIKE ---")
	PlayerBike.clear_owner_sfx()
	var cache: String = OS.get_cache_dir().replace("\\", "/").trim_suffix("/")
	empty_dir = cache + "/fptu_test_owner_bike_no_sfx/"
	tmp_dir = cache + "/fptu_test_owner_bike_sfx/"
	PlayerBike.sfx_dir = empty_dir
	physics_frame.connect(_on_physics)


func _duck() -> float:
	return float(md.get("duck_target")) if md else -1.0


func _fx() -> Node:
	return root.get_node_or_null("/root/GameFX")


func _reset(b: PlayerBike, at: Vector3, speed: float = 0.0) -> void:
	b.global_position = at
	b.rotation = Vector3.ZERO
	b.velocity = Vector3.ZERO
	b.current_speed_ms = speed


func _on_physics() -> void:
	f += 1
	if f == 1:
		arena = Node3D.new()
		arena.name = "Arena"
		arena.set_meta("visual_preset", "dawn")   # like Stage 1 (RoadManager: dawn)
		root.add_child(arena)
		World.floor_box(arena, 600.0)
		var fx: Node = _fx()
		md = fx.get("music") if fx else null
		bike = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
		arena.add_child(bike)
		_reset(bike, Vector3(0.0, -0.12, 200.0))
	elif f == 3:
		_part_static()
		Input.action_press("high_beam")
	elif f == 5:
		Input.action_release("high_beam")
		_check(bike.high_beam and is_equal_approx(bike.headlight.spot_range, 70.0), "[L] (input action high_beam) switches to the high beam")
		bike.toggle_high_beam()
		bike.set_time_of_day("night")
	elif f > 5 and f <= 77:
		var c: int = bike.strobe_color
		colours[c] = int(colours.get(c, 0)) + 1
		var red: float = (bike.bike_parts["strobe_red_mat"] as StandardMaterial3D).emission_energy_multiplier
		var blue: float = (bike.bike_parts["strobe_blue_mat"] as StandardMaterial3D).emission_energy_multiplier
		red_ok = red_ok and ((red > 0.0) == (c == 1)) and ((blue > 0.0) == (c == 2))
		glow_ok = glow_ok and bike.strobe_glow.visible == (c != 0)
		if c == 1:
			glow_ok = glow_ok and bike.strobe_glow.light_color.r > bike.strobe_glow.light_color.b
		elif c == 2:
			glow_ok = glow_ok and bike.strobe_glow.light_color.b > bike.strobe_glow.light_color.r
		if f == 77:
			_check(int(colours.get(1, 0)) > 0 and int(colours.get(2, 0)) > 0 and int(colours.get(0, 0)) > 0, "the ridden strobe shows red, blue and dark gaps over a cycle %s" % str(colours))
			_check(red_ok, "only the active strip glows (red strip red, blue strip blue)")
			_check(glow_ok, "at night the strobe OmniLight follows the active colour")
	elif f == 78:
		bike.process_mode = Node.PROCESS_MODE_DISABLED
		var red2: float = (bike.bike_parts["strobe_red_mat"] as StandardMaterial3D).emission_energy_multiplier
		var blue2: float = (bike.bike_parts["strobe_blue_mat"] as StandardMaterial3D).emission_energy_multiplier
		_check(bike.strobe_color == 0 and red2 == 0.0 and blue2 == 0.0 and not bike.strobe_glow.visible, "parked (process disabled): the strobe is off")
		_check(not bike.headlight.visible and not bike.headlight_haze.visible, "parked at night: the headlight and the haze are off")
	elif f == 79:
		var red3: float = (bike.bike_parts["strobe_red_mat"] as StandardMaterial3D).emission_energy_multiplier
		_check(bike.strobe_color == 0 and red3 == 0.0, "the strobe stays off while parked")
		bike.process_mode = Node.PROCESS_MODE_INHERIT
		_check(bike.headlight.visible and bike.headlight_haze.visible, "ridden again at night: the headlight and the haze are back")
		bike.apply_speed_profile(PlayerBike.STAGE_PROFILE)
		_reset(bike, Vector3(0.0, -0.12, 200.0))
		Input.action_press("gas")
	elif f > 79 and f < 320:
		over_cap = over_cap or bike.current_speed_ms > 22.5 + 0.01
	elif f == 320:
		_check(not over_cap and absf(bike.current_speed_ms - 22.5) < 0.05, "STAGE_PROFILE caps at 22.5 m/s (speed %.2f)" % bike.current_speed_ms)
		bike.apply_speed_profile(PlayerBike.OWNER_PROFILE)
		_reset(bike, Vector3(0.0, -0.12, 200.0))
		over_cap = false
	elif f > 320 and f < 650:
		if t100 < 0 and bike.current_speed_ms >= 100.0 / 3.6:
			t100 = f - 320
		if t120 < 0 and bike.current_speed_ms >= 33.2:
			t120 = f - 320
		over_cap = over_cap or bike.current_speed_ms > 33.3 + 0.01
	elif f == 650:
		print("  owner profile: 0-100 km/h %.2f s, 0-119.5 km/h %.2f s, top %.2f m/s" % [t100 / 60.0, t120 / 60.0, bike.current_speed_ms])
		_check(not over_cap and absf(bike.current_speed_ms - 33.3) < 0.05, "OWNER_PROFILE caps at 33.3 m/s (120 km/h)")
		_check(t100 > 0 and t100 / 60.0 >= 1.8 and t100 / 60.0 <= 3.5, "owner 0-100 km/h in 1.8-3.5 s (never slower than the old bike, not instant)")
		_check(t120 > 0 and t120 / 60.0 <= 5.0, "owner reaches 120 km/h within 5 s")
		Input.action_release("gas")
		Input.action_press("brake")
	elif f == 653:
		_check(bike.braking and is_equal_approx(bike.tail_energy(), PlayerBike.BRAKE_ENERGY) and PlayerBike.BRAKE_ENERGY > PlayerBike.TAIL_ENERGY, "the brake light brightens while braking")
		Input.action_release("brake")
	elif f == 656:
		_check(not bike.braking and is_equal_approx(bike.tail_energy(), PlayerBike.TAIL_ENERGY), "the tail light dims back after braking")
		World.wall(arena, Vector3(0.0, 2.0, 175.0), Vector3(30.0, 4.0, 0.1))
		_reset(bike, Vector3(0.0, -0.12, 200.0), 33.3)
		min_z = 200.0
		Input.action_press("gas")
	elif f > 656 and f < 760:
		min_z = minf(min_z, bike.global_position.z)
	elif f == 760:
		Input.action_release("gas")
		print("  wall test: closest origin z %.2f (wall face at 175.05)" % min_z)
		_check(min_z < 177.0 and min_z > 175.0, "no tunnelling: the bike at 33.3 m/s stops at a 0.1 m wall")
		_part_profiles()
	elif f == 762:
		_part_vice()
	elif f == 763:
		_part_vice_2()
	elif f == 765:
		_part_audio_setup()
	elif f == 775:
		_part_audio_owner()
	elif f == 777:
		var ok_near: bool = true
		for p: Pedestrian in near:
			ok_near = ok_near and p.state == Pedestrian.State.REACT and p.react_kind == "clap" and p.react_left >= 1.0
		_check(ok_near, "pedestrians within 14 m cheer (the clap reaction = the cheer clip) for the melody's rest")
		var ok_far: bool = true
		for p2: Pedestrian in far:
			ok_far = ok_far and p2.state == Pedestrian.State.IDLE
		_check(ok_far, "pedestrians beyond 14 m do not")
		_check(fleer.state == Pedestrian.State.FLEE and late.state == Pedestrian.State.IDLE, "a fleeing pedestrian ignores it (and the far walker too)")
		late.global_position = bike2.global_position + Vector3(0.0, 0.05, 6.0)
	elif f > 777 and f < 815:
		if late_t < 0 and late.state == Pedestrian.State.REACT:
			late_t = f - 777
	elif f == 815:
		_check(late_t > 0 and late_t <= 32, "a pedestrian walking into the radius joins in within 0.5 s (%d frames)" % late_t)
		_check(md != null and absf(_duck() - db_to_linear(PlayerBike.HORN_DUCK_DB)) < 0.001, "the roam music ducks by 8 dB while the melody plays")
		bike2.horn_tap()
		_check(md != null and _duck() >= 0.999, "a tap-stop brings the music back")
		var stopped: bool = true
		for p3: Pedestrian in near + [late]:
			stopped = stopped and p3.state == Pedestrian.State.IDLE and p3.react_kind == ""
		_check(not bike2.horn_melody_playing() and stopped, "a second tap stops the melody and the dancers stop at once")
	elif f == 832:
		_check(not bike2.melody_player.playing, "the melody fades out (0.15 s) and stops")
		bike2.horn_tap()
	elif f == 834:
		_check(bike2.horn_melody_playing() and (near[0] as Pedestrian).state == Pedestrian.State.REACT, "a new tap plays the melody from the start again")
	elif f == 834 + 125 + 10:
		_check(not bike2.horn_melody_playing() and not bike2.melody_player.playing, "the melody ends by itself after its length and the player stops")
		_check(_duck() >= 0.999, "the music comes back after the melody's natural end")
		_check((bike2.melody_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "the horn melody never loops")
	elif f == 834 + 125 + 75:
		var resumed: bool = true
		for p4: Pedestrian in near:
			resumed = resumed and p4.state == Pedestrian.State.IDLE
		_check(resumed, "the dancers resume after the melody ends")
		bike2.horn_tap()
	elif f == 834 + 125 + 77:
		bike2.process_mode = Node.PROCESS_MODE_DISABLED
		_check(not bike2.horn_melody_playing() and not bike2.melody_player.playing and _duck() >= 0.999, "parked (disabled) mid-melody: the melody stops and the music comes back")
		bike2.process_mode = Node.PROCESS_MODE_INHERIT
	elif f == 834 + 125 + 79:
		bike2.set_time_of_day("night")
		bike2.horn_tap()
		_check(bike2.horn_melody_playing() and _duck() < 0.5, "the melody plays again")
	elif f == 834 + 125 + 81:
		bike2.park()
		_check(bike2.parked and bike2.is_controls_locked and not bike2.horn_melody_playing() and not bike2.melody_player.playing and _duck() >= 0.999, "park() mid-melody (Stage 1 finish / Stage 2 parked): locked, the melody stops, the music comes back")
	elif f == 834 + 125 + 100:
		var red4: float = (bike2.bike_parts["strobe_red_mat"] as StandardMaterial3D).emission_energy_multiplier
		var blue4: float = (bike2.bike_parts["strobe_blue_mat"] as StandardMaterial3D).emission_energy_multiplier
		_check(bike2.strobe_color == 0 and red4 == 0.0 and blue4 == 0.0 and not bike2.headlight.visible, "a parked (locked, still processing) bike keeps its strobe and headlight off")
		bike.horn_tap()
		_check(bike.horn_melody_playing() and _duck() < 0.5, "another bike's melody ducks the music")
		bike.queue_free()
	elif f == 834 + 125 + 103:
		_check(_duck() >= 0.999, "the bike leaving the tree mid-melody brings the music back")
		_finish()


func _part_static() -> void:
	var parts: Dictionary = bike.bike_parts.get("parts", {})
	var missing: Array = []
	for n: String in OwnerBikeBuilder.PART_NAMES:
		var node: Node = parts.get(n)
		if node == null or not is_instance_valid(node) or not node.is_inside_tree() or not bike.is_ancestor_of(node):
			missing.append(n)
	_check(missing.is_empty(), "every named part of the owner's bike is built on the PlayerBike (missing %s)" % str(missing))
	var front_w: Node = bike.front_wheel.get_node_or_null("Wheel")
	_check(front_w != null and bike.rear_wheel.get_node_or_null("Wheel") != null, "both wheels sit on the scene's wheel pivots")
	_check(bike.handlebar_pivot.is_ancestor_of(parts["Cowl"]) and bike.handlebar_pivot.is_ancestor_of(bike.headlight), "the cowl and the headlight steer with the handlebar")
	_check(bike.front_wheel.is_ancestor_of(parts["FrontDisc"]) and (parts["FrontDisc"] as Node3D).position.x < 0.0, "the front disc spins with the wheel, on the left side")
	_check((parts["Muffler"] as Node3D).position.x > 0.1, "the long muffler is on the right")
	var labels: Array = bike.find_children("*", "Label3D", true, false)
	var texts: Array = []
	var brand: bool = false
	for l: Variant in labels:
		var t: String = (l as Label3D).text
		texts.append(t)
		for b: String in BRANDS:
			brand = brand or t.to_upper().contains(b)
	var meshes: Array = bike.find_children("*", "MeshInstance3D", true, false)
	for m: Variant in meshes:
		if (m as MeshInstance3D).mesh is TextMesh:
			brand = true
	_check(not brand and labels.size() == 1 and String(texts[0]).replace("\n", " ") == OwnerBikeBuilder.PLATE_TEXT, "no brand text: the only text is the fake plate %s" % str(texts))
	# headlight
	var h: SpotLight3D = bike.headlight
	var dir: Vector3 = (bike.global_transform.basis.inverse() * -h.global_transform.basis.z).normalized()
	print("  beam direction in bike space: ", dir.snapped(Vector3(0.001, 0.001, 0.001)))
	_check(dir.z < -0.95, "the headlight points forward (-Z in bike space), not backward")
	_check(not h.shadow_enabled and h.spot_angle_attenuation > 1.0, "the beam has a soft edge and no shadow")
	_check(is_equal_approx(h.spot_range, 40.0) and is_equal_approx(h.spot_angle, 30.0) and is_equal_approx(h.light_energy, 3.0), "low beam by default: 40 m, 30 degrees, energy 3")
	var lens: StandardMaterial3D = bike.bike_parts["headlamp_mat"]
	var lens_low: float = lens.emission_energy_multiplier
	bike.toggle_high_beam()
	var dir2: Vector3 = (bike.global_transform.basis.inverse() * -h.global_transform.basis.z).normalized()
	_check(bike.high_beam and is_equal_approx(h.spot_range, 70.0) and is_equal_approx(h.spot_angle, 20.0) and is_equal_approx(h.light_energy, 5.0) and dir2.z < -0.95 and lens.emission_energy_multiplier > lens_low, "toggle: high beam 70 m, 20 degrees, energy 5, still forward, brighter lens")
	var k_high: float = bike.headlight_haze.transform.basis.x.length()
	_check(absf(k_high - tan(deg_to_rad(20.0)) / tan(deg_to_rad(30.0))) < 0.01 and bike.headlight_haze.transform.origin.is_equal_approx(h.transform.origin), "the haze narrows with the high beam (%.2f) and follows the lamp" % k_high)
	bike.toggle_high_beam()
	_check(not bike.high_beam and is_equal_approx(h.spot_range, 40.0) and absf(bike.headlight_haze.transform.basis.x.length() - 1.0) < 0.01, "toggle again: back to the low beam and its haze")
	# time of day
	_check(bike.lights_preset == "dawn" and h.visible, "without a call the bike reads the scene's preset (Stage 1 dawn: beam on)")
	var tod_ok: bool = true
	for pr: String in ["morning", "noon", "sunset", "night", "dawn", "noon"]:
		bike.set_time_of_day(pr)
		var dark: bool = pr in ["night", "sunset", "dawn"]
		tod_ok = tod_ok and h.visible == dark and bike.headlight_haze.visible == (pr == "night")
	_check(tod_ok, "the SpotLight is on only at night / sunset / dawn, the haze cone only at night")
	_check(lens.emission_energy_multiplier > 0.0 and bike.tail_energy() > 0.0, "the lens and the tail glow by day too")
	_check(bike.headlight_haze.get_node_or_null("HeadlightDust") == null, "the haze has no dust motes")
	# strobe pattern
	var seq: Array = []
	var red_flashes: int = 0
	var blue_flashes: int = 0
	var prev: int = 0
	for i: int in range(120):
		var c: int = PlayerBike.strobe_state(float(i) * 0.01 + 0.005)
		if c != prev and c == 1:
			red_flashes += 1
		if c != prev and c == 2:
			blue_flashes += 1
		prev = c
		seq.append(c)
	_check(red_flashes == 3 and blue_flashes == 3 and seq[5] == 1 and seq[65] == 2 and seq[15] == 0, "strobe_state: 3 red flashes, then 3 blue, per 1.2 s cycle")


func _part_profiles() -> void:
	# Stage 1 scene keeps its values
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	var sb: PlayerBike = main.get_node_or_null("PlayerBike") as PlayerBike
	_check(sb != null and is_equal_approx(sb.max_speed_ms, 22.5) and is_equal_approx(sb.slipstream_max_ms, 27.0) and is_equal_approx(sb.engine_accel, 13.5), "Stage 1 (Main.tscn) still caps at 22.5 m/s")
	main.free()
	_check(is_equal_approx(float(PlayerBike.STAGE_PROFILE["max_speed_ms"]), 22.5) and is_equal_approx(float(PlayerBike.OWNER_PROFILE["max_speed_ms"]), 33.3) and is_equal_approx(float(PlayerBike.OWNER_PROFILE["slipstream_max_ms"]), 36.1), "profiles: stage 22.5, owner 33.3 / 36.1 in a slipstream")
	# FreeRoam._build_bike applies the owner profile (FreeRoam's script set on a node already in the tree: no world build)
	var fr := Node3D.new()
	fr.name = "FakeRoam"
	arena.add_child(fr)
	fr.set_script(load("res://scripts/FreeRoam.gd"))
	fr.call("_build_bike")
	var rb: PlayerBike = fr.get("bike") as PlayerBike
	_check(rb != null and is_equal_approx(rb.max_speed_ms, 33.3) and is_equal_approx(rb.slipstream_max_ms, 36.1), "FreeRoam's bike (free roam, story roam) uses the owner profile")
	_check(rb != null and rb.strobe_color == 0 and not rb.headlight.visible, "FreeRoam's parked bike has its strobe and headlight off")
	fr.free()
	# the Phase C chase caps the player while it runs and gives the profile back (start / stop, then freed mid-chase)
	var ch: BikeChase = _chase()
	ch.start()
	var capped: bool = ch.state == "running" and is_equal_approx(bike.max_speed_ms, 22.5) and is_equal_approx(bike.slipstream_max_ms, 27.0) and is_equal_approx(bike.air_drag, 0.015)
	ch.stop()
	_check(capped and is_equal_approx(bike.max_speed_ms, 33.3) and is_equal_approx(bike.air_drag, 0.0105), "BikeChase.start() caps the bike at the stage profile, stop() restores the owner profile")
	ch.free()
	var ch2: BikeChase = _chase()
	ch2.start()
	var capped2: bool = is_equal_approx(bike.max_speed_ms, 22.5)
	ch2.free()
	_check(capped2 and is_equal_approx(bike.max_speed_ms, 33.3) and is_equal_approx(bike.slipstream_max_ms, 36.1), "a chase freed mid-run (no stop()) gives the owner profile back")
	_reset(bike, Vector3(0.0, -0.12, 200.0))


func _chase() -> BikeChase:
	var c := BikeChase.new()
	arena.add_child(c)
	c.setup({"bike": bike, "route": [Vector2(0.0, 150.0), Vector2(0.0, -250.0)], "start_s": 10.0, "manual_replay": true, "hud": false, "seed": 3})
	c.add_wave([{"lane": 1, "opts": {"ai": false, "label": "T0"}}])
	return c


## ViceStyle classic -> vice -> classic around the bike while braking with the red strip lit, parked before the second
## classic pass (the reviewer's probe): GameFX.art_style_changed makes the bike re-tag and rewrite its lamps.
func _part_vice() -> void:
	var fx: Node = _fx()
	_check(fx != null and fx.has_signal("art_style_changed"), "GameFX is there with art_style_changed")
	var red: StandardMaterial3D = bike.bike_parts["strobe_red_mat"]
	var tail: StandardMaterial3D = bike.bike_parts["tail_mat"]
	ViceStyle._ever_stylized = true
	ViceStyle.unstylize_materials(arena)
	if fx:
		fx.emit_signal("art_style_changed", "classic")
	_check(red.has_meta("vice_done") and tail.has_meta("vice_done"), "after a classic pass the lamps are tagged again")
	bike.braking = true
	bike._update_tail()
	bike._apply_strobe(1)
	ViceStyle.unstylize_materials(arena)              # a time-of-day pass in classic strips the tags again
	ViceStyle.stylize_materials(arena)                # then the switch to vice
	if fx:
		fx.emit_signal("art_style_changed", "vice")
	_check(red.has_meta("vice_done") and not red.has_meta("vice_orig") and not tail.has_meta("vice_orig") and is_equal_approx(tail.roughness, OwnerBikeBuilder.LAMP_ROUGHNESS) and tail.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX, "after a vice pass the lamps keep their look and no energy snapshot")
	bike.braking = false
	bike._update_tail()
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	ViceStyle.unstylize_materials(arena)
	if fx:
		fx.emit_signal("art_style_changed", "classic")
	_check(bike.strobe_color == 0 and red.emission_energy_multiplier == 0.0 and is_equal_approx(tail.emission_energy_multiplier, PlayerBike.TAIL_ENERGY), "back to classic while parked: strobe off, tail normal (no stale energy)")


func _part_vice_2() -> void:
	var red: StandardMaterial3D = bike.bike_parts["strobe_red_mat"]
	_check(red.emission_energy_multiplier == 0.0, "the strobe stays off on the parked bike after the round trip")
	bike.process_mode = Node.PROCESS_MODE_INHERIT


func _part_audio_setup() -> void:
	# empty owner folder: the res:// wav fallbacks
	_check(PlayerBike.owner_file(PlayerBike.SFX_EXHAUST) == "" and PlayerBike.owner_sfx_state(PlayerBike.SFX_HORN) == 0, "empty temp sfx folder: no owner file")
	_check(not bike.owner_exhaust and bike.engine_player.stream is AudioStreamWAV and bike.melody_stream == null, "fallback: the old engine wav, no melody")
	bike.horn_tap()
	_check(bike.horn_player.playing and not bike.horn_melody_playing(), "fallback: the horn key plays the short wav horn")
	# owner files in a temp folder (never the owner's real user://sfx)
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	_check(_silent_wav(2.0).save_to_wav(tmp_dir + "bike_horn.wav") == OK and _silent_wav(0.5).save_to_wav(tmp_dir + "bike_exhaust.wav") == OK, "temp owner files written (OS cache folder, not user://)")
	PlayerBike.sfx_dir = tmp_dir
	bike2 = (load("res://scenes/PlayerBike.tscn") as PackedScene).instantiate() as PlayerBike
	arena.add_child(bike2)
	_reset(bike2, Vector3(80.0, -0.12, 0.0))
	# the crowd around bike2
	var c: Vector3 = Vector3(80.0, 0.0, 0.0)
	var k: int = 0
	for off: Vector3 in [Vector3(4.0, 0.0, 0.0), Vector3(-6.0, 0.0, 6.5), Vector3(0.0, 0.0, -13.5)]:
		near.append(World.ped(arena, c + off, 500 + k, bike2))
		k += 1
	for off2: Vector3 in [Vector3(15.0, 0.0, 0.0), Vector3(0.0, 0.0, 20.0)]:
		far.append(World.ped(arena, c + off2, 520 + k, bike2))
		k += 1
	fleer = World.ped(arena, c + Vector3(-5.0, 0.0, -2.0), 540, bike2)
	late = World.ped(arena, c + Vector3(-30.0, 0.0, 0.0), 541, bike2)
	peds = near + far + [fleer, late]
	bike2.horn_targets_fn = func() -> Array: return peds


func _part_audio_owner() -> void:
	fleer.flee_from(bike2.global_position + Vector3(-1.0, 0.0, 0.0), 30.0)
	_check(PlayerBike.owner_file(PlayerBike.SFX_HORN) == tmp_dir + "bike_horn.wav", "the owner file is looked up in the settable sfx folder")
	_check(bike2.owner_exhaust and bike2.engine_player.stream is AudioStreamWAV and (bike2.engine_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "the owner exhaust (loaded on a worker thread) replaces the engine loop and loops")
	_check(bike2.melody_stream != null and absf(bike2.melody_stream.get_length() - 2.0) < 0.05, "the owner horn melody is loaded")
	_check(is_equal_approx(PlayerBike.exhaust_pitch(0.0, 0.0), 0.62) and is_equal_approx(PlayerBike.exhaust_pitch(0.7, 0.0), 1.0) and is_equal_approx(PlayerBike.exhaust_pitch(1.0, 0.0), 1.18) and is_equal_approx(PlayerBike.exhaust_pitch(0.0, 1.0), 0.68), "exhaust pitch curve 0.62 / 1.0 at 70 % / 1.18 at top / +0.06 throttle")
	_check(is_equal_approx(PlayerBike.exhaust_db(0.0), -10.0) and is_equal_approx(PlayerBike.exhaust_db(1.0), 4.0), "exhaust volume -10 dB idle, +4 dB under throttle")
	bike2.horn_tap()
	_check(bike2.horn_melody_playing() and absf(bike2.melody_left - 2.0) < 0.05 and bike2.melody_player.playing, "a tap plays the melody from the start")


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
	arena.free()   # the bikes' players stop and go before quitting (no ObjectDB leak at exit)
	PlayerBike.clear_owner_sfx()
	for n: String in ["bike_horn.wav", "bike_exhaust.wav"]:
		DirAccess.remove_absolute(tmp_dir + n)
	DirAccess.remove_absolute(tmp_dir)
	PlayerBike.sfx_dir = "user://sfx/"
	if fails.is_empty():
		print("✅ SUCCESS: OWNER BIKE")
		quit(0)
	else:
		print("❌ FAILED (%d)" % fails.size())
		quit(1)
