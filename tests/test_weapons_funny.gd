# File: res://tests/test_weapons_funny.gd
# Headless test of the Phase W funny weapons (spec section 3, W-D5, section 7): the dép tổ ong flies out straight, bonks the
# person in front (knocked out 4 s, stars, +1), curves back and returns to the hand, one in flight at a time; the sầu riêng
# lands ~7 m ahead, bursts after its 2 s fuse into an 8 m stink cloud (people inside pinch their nose then flee, the one
# outside is untouched, a cough plays, vehicles inside stop, +2) that is gone after 6 s; the loa kẹo kéo blasts a 10 m / 60°
# cone while held (people in it are pushed / dance, outside are untouched), its music is the synthesized looping bolero
# (or the owner's local loa_keo_keo file), +1 heat every 2 s, stops on release and on unequip.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_weapons_funny.gd
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
var traffic: RoamTraffic
var targets: Array = []
var heat: Array[float] = []
var peds: Dictionary = {}
var cloud_pos: Vector3
var hold: bool = false
var shots0: int = 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST WEAPONS: DÉP, SẦU RIÊNG, LOA ---")
	_math()
	_bolero()
	physics_frame.connect(_on_physics)


func _math() -> void:
	var s := Vector3(1.0, 1.3, 2.0)
	var f := Vector3(0.0, 0.0, -1.0)
	var r := Vector3(1.0, 0.0, 0.0)
	_check(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.0).is_equal_approx(s) and WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 1.0).distance_to(s) < 1e-4, "the dép path starts and ends at the hand")
	_check(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.5).is_equal_approx(s + f * 12.0), "it reaches 12 m straight ahead at half time")
	_check(absf(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.25).x - s.x) < 1e-4, "straight on the way out")
	_check(absf(WeaponMath.boomerang_point(s, f, r, 12.0, 2.5, 0.75).x - s.x - 2.5) < 1e-4, "curves 2.5 m to the right on the way back")


func _rms(w: AudioStreamWAV, t_a: float, t_b: float) -> float:
	var d: PackedByteArray = w.data
	var a: int = int(t_a * CineAudio.SR)
	var b: int = mini(int(t_b * CineAudio.SR), d.size() / 2)
	var acc: float = 0.0
	for i: int in range(a, b):
		var v: float = float(d.decode_s16(i * 2)) / 32767.0
		acc += v * v
	return sqrt(acc / maxf(float(b - a), 1.0))


func _bolero() -> void:
	var t_ms: int = Time.get_ticks_msec()
	var w: AudioStreamWAV = WeaponAudio.synth_bolero()
	var ms: int = Time.get_ticks_msec() - t_ms
	var secs: float = float(w.data.size()) / 2.0 / float(CineAudio.SR)
	_check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end == w.data.size() / 2, "the bolero cue loops over its whole length")
	_check(absf(secs - 10.0) < 0.05, "the bolero cue is 4 bars at 96 bpm = 10 s (%.2f s)" % secs)
	_check(_rms(w, 0.0, 0.5) > 0.01 and _rms(w, 9.5, 10.0) > 0.01, "it is not silent at the start or the end (seamless loop)")
	_check(ms < 1500, "synthesized in %d ms" % ms)
	if WeaponAudio.loa_file() == "":
		_check(WeaponAudio.loa_stream() is AudioStreamWAV, "no owner loa_keo_keo file -> the synthesized bolero plays")
	else:
		_check(WeaponAudio.loa_stream() != null, "the owner's local loa_keo_keo file loads (%s)" % WeaponAudio.loa_file())
		print("  owner loa file found: %s" % WeaponAudio.loa_file())


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _ped(key: String, at: Vector3) -> Pedestrian:
	var p: Pedestrian = World.ped(arena, at, 110 + peds.size(), player)
	peds[key] = p
	targets.append(p)
	return p


func _fire() -> void:
	dir.cooldown = 0.0
	dir.fire_override = true


func _count(pattern: String) -> int:
	return arena.find_children(pattern, "", true, false).size()


func _played(cue: String) -> bool:
	for p: AudioStreamPlayer3D in dir._sfx:
		if p.stream == WeaponAudio.stream(cue):
			return true
	return false


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		traffic = World.traffic(arena, player, -40.0)
		World.place_vehicle(traffic, 0, -80.0)
		World.place_vehicle(traffic, 1, 60.0)
		WeaponAudio.sfx_dir = "res://tests/__no_sfx__/"   # never depend on the owner's local files
		WeaponAudio.clear_cache()
		dir = World.director(arena, player, targets, traffic)
		dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		_check(WeaponAudio.is_warm(), "every cue (and the bolero) is synthesized when the weapons load (R3-I2)")
		var t_us: int = Time.get_ticks_usec()
		dir.equip(WeaponData.Slot.LOA)
		dir.cycle(1)
		dir.cycle(-1)
		var ms: float = float(Time.get_ticks_usec() - t_us) / 1000.0
		_check(ms < 25.0, "equipping the loa and scrolling never synthesize audio (%.1f ms)" % ms)
		dir.equip(WeaponData.Slot.DEP)
		_ped("P", Vector3(0.0, 0.0, -8.0))
		_next("dep")
		return
	var t: int = frames - t0
	if dir.fire_override == true and t > 0 and not hold:
		dir.fire_override = false
	match phase:
		"dep":
			if t == 5:
				_fire()
			if t == 7:
				_check(dir.dep_in_flight and _count("Dep*") == 1 and dir.held != null and not dir.held.visible, "the dép is in flight (it left the hand)")
			if t == 10:
				_fire()
			if t == 12:
				_check(_count("Dep*") == 1, "only one dép in flight at a time")
			if t == 15:
				dir.equip(WeaponData.Slot.PISTOL)
				dir.equip(WeaponData.Slot.DEP)
				_check(dir.held != null and not dir.held.visible, "switching away and back while the dép flies: no second dép in the hand")
			if t == 45:
				var p: Pedestrian = peds["P"]
				_check(p.state == Pedestrian.State.KNOCKED_OUT and p.ko_left <= 4.0 and p.ko_left > 3.0, "bonk: knocked out 4 s (%.2f s left)" % p.ko_left)
				_check(heat.has(WeaponData.HEAT_DEP), "+1 heat for the bonk (%s)" % str(heat))
				_check(not dir.fx.cine.find_children("Star*", "", true, false).is_empty() and _played("bonk"), "spinning stars and the bonk sound")
			if t == 95:
				_check(dir.dep_returns == 1 and not dir.dep_in_flight, "the dép came back after 1.4 s")
				_check(dir.last_dep_return.distance_to(dir.hand_position()) < 0.3, "... into the hand (%.2f m)" % dir.last_dep_return.distance_to(dir.hand_position()))
				_check(dir.held != null and dir.held.visible and _count("Dep*") == 0, "back in the hand")
			if t == 300:
				_check((peds["P"] as Pedestrian).state == Pedestrian.State.FLEE, "the bonked person got up and flees")
				targets.clear()
				heat.clear()
				dir.equip(WeaponData.Slot.DURIAN)
				_next("durian")
		"durian":
			if t == 5:
				_fire()
			if t == 7:
				_check(_count("Durian*") == 1, "a sầu riêng is thrown")
			if t == 128:
				var clouds: Array = arena.find_children("StinkCloud*", "", true, false)
				_check(dir.stink_clouds == 1 and clouds.size() == 1 and _count("Durian*") == 0, "it burst after the 2 s fuse into a stink cloud")
				if not clouds.is_empty():
					cloud_pos = (clouds[0] as Node3D).global_position
				var dd: float = WeaponMath.flat(cloud_pos, player.global_position)
				_check(dd > 3.0 and dd < 10.0 and cloud_pos.z < 0.0, "it landed ahead (%.1f m)" % dd)
				_check((clouds[0] as StinkCloud).radius * 2.0 == 8.0 if not clouds.is_empty() else false, "the cloud is 8 m wide")
				_ped("Q1", cloud_pos + Vector3(1.5, 0.0, 0.0))
				_ped("Q2", cloud_pos + Vector3(6.5, 0.0, 0.0))
				var car: RoamTraffic.Vehicle = traffic.vehicles[1]
				car.cruise = 5.0
				car.speed = 5.0
				dir.spawn_stink(car.body.global_position)
			if t == 150:
				_check((peds["Q1"] as Pedestrian).state == Pedestrian.State.STINK, "inside the cloud: pinches the nose")
				_check((peds["Q2"] as Pedestrian).state == Pedestrian.State.IDLE, "outside the 4 m radius: untouched")
				_check(_played("cough"), "a cough plays")
			if t == 200:
				_check((traffic.vehicles[1] as RoamTraffic.Vehicle).speed < 0.3, "a vehicle inside a stink cloud stops")
			if t == 300:
				_check((peds["Q1"] as Pedestrian).state == Pedestrian.State.FLEE, "then flees")
				_check(heat.count(WeaponData.HEAT_DURIAN) == 2, "+2 heat per burst (%s)" % str(heat))
			if t == 500:
				_check(_count("StinkCloud*") == 0 and traffic.stop_zones.is_empty(), "the clouds are gone after 6 s")
			if t == 600:
				_check((traffic.vehicles[1] as RoamTraffic.Vehicle).speed > 1.0, "traffic moves again")
				targets.clear()
				heat.clear()
				dir.equip(WeaponData.Slot.LOA)
				_ped("L1", Vector3(0.0, 0.0, -5.0))
				_ped("L2", Vector3(5.0 * sin(deg_to_rad(50.0)), 0.0, -5.0 * cos(deg_to_rad(50.0))))
				_ped("L3", Vector3(0.0, 0.0, -13.0))
				_next("loa")
		"loa":
			if t == 5:
				hold = true
				dir.fire_override = true
			if t == 10:
				_check(dir.sonic != null and dir.sonic.music.playing and dir.sonic.music.stream == WeaponAudio.loa_stream(), "holding fire blasts the loa and plays its music")
			if t == 40:
				var l1: Pedestrian = peds["L1"]
				_check(l1.state == Pedestrian.State.DANCE or l1.state == Pedestrian.State.FLEE, "in the cone: pushed (dances or flees)")
				_check(WeaponMath.flat(l1.global_position, player.global_position) > 5.3, "pushed back (%.2f m)" % WeaponMath.flat(l1.global_position, player.global_position))
				_check((peds["L2"] as Pedestrian).state == Pedestrian.State.IDLE and (peds["L3"] as Pedestrian).state == Pedestrian.State.IDLE, "50° off-axis and 13 m away: untouched")
				_check(dir.fx.transient_count("sonic") >= 1, "sonic rings")
			if t == 258:
				_check(heat.count(WeaponData.HEAT_LOA_PER_2S) == 2, "+1 heat every 2 s of blasting (%s after 4.2 s)" % str(heat))
				hold = false
				dir.fire_override = false
			if t == 260:
				_check(dir.sonic == null and _count("SonicCone*") == 0, "release stops the blast and the music")
				hold = true
				dir.fire_override = true
			if t == 266:
				_check(dir.sonic != null, "blasting again")
				dir.equip(WeaponData.Slot.UNARMED)
				_check(dir.sonic == null, "switching weapon stops the loa")
				hold = false
				dir.fire_override = false
				heat.clear()
				dir.loa_heat_acc = 0.0
				dir.equip(WeaponData.Slot.LOA)
				_next("taps")
		"taps":
			# five bursts of 1 s with short pauses: 5 s of blasting = +2 heat (the counter is kept between presses)
			var k: int = t % 70
			if t < 350:
				hold = k < 60
				dir.fire_override = hold
			if t == 352:
				_check(heat.count(WeaponData.HEAT_LOA_PER_2S) == 2, "short loa bursts add up: +2 heat for 5 s in five presses (%s)" % str(heat))
				dir.equip(WeaponData.Slot.PISTOL)
				hold = true
				dir.fire_override = true
				dir.locked = true
				_next("release")
		"release":
			if t == 10:
				shots0 = dir.shots
				dir.cooldown = 0.0
				dir.locked = false
			if t == 20:
				_check(dir.shots == shots0, "fire held through a block does not shoot when the block ends (release first)")
				hold = false
				dir.fire_override = false
			if t == 22:
				hold = true
				dir.fire_override = true
			if t == 24:
				_check(dir.shots == shots0 + 1, "after a release the next press shoots")
				hold = false
				dir.fire_override = false
				_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
				Engine.time_scale = 1.0
				if fails.is_empty():
					print("✅ SUCCESS: WEAPONS DÉP / SẦU RIÊNG / LOA (boomerang path and return, bonk, stink cloud + traffic stop, sonic cone, bolero loop, heat)")
					quit(0)
				else:
					print("❌ FAILED: %d issues" % fails.size())
					quit(1)
