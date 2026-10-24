# File: res://tests/test_emotes.gd
# Headless test of the Phase W emotes (spec W-D10..W-D13, section 9): the emote wheel opens on a B hold (not a tap) with
# slot 0 "Siuuu!" and 7 greyed slots that cannot be chosen; the emote is refused while blocked, aiming, firing, reloading,
# knocked down or with the weapon wheel open; "Siuuu!" runs ~4.5 m away from the camera, takes off at 1.10 s, turns 180° by
# the 1.70 s landing, starts the shout at landing - 0.31 s (vowel burst within one physics frame of the landing), hides and
# restores the weapon, lasts 3.30 s, can only be cancelled by movement from 2.20 s; bystanders within 10 m react by share
# (clap / shout back / film with a glowing phone / look), nobody beyond 10 m, fleeing or knocked out reacts, then they
# resume; the synthesized cue follows the fixed layout and the override resolution does not depend on the owner's local
# file (injectable sfx dir). Fix round: an emote started while the dép flies leaves the dép visible in the hand once it is
# back (R1-I2); a reacting bystander bumped by the player drops the phone and the head look (R1-I1).
# Part B (FreeRoam, crowd off): blocked on the bike, weapons blocked during the emote.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_emotes.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const FRAME: float = 1.0 / 60.0

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var wheel: EmoteWheel
var emotes: EmoteDirector
var targets: Array = []
var blocked: bool = false
var near: Array = []
var far: Array = []
var fleer: Pedestrian
var ko: Pedestrian
var land_yaw: float = 0.0
var finishes: Array = []
var hidden_seen: bool = false
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
	print("--- TEST EMOTES ---")
	_audio()
	_poses()
	physics_frame.connect(_on_physics)


func _rms(w: AudioStreamWAV, a_s: float, b_s: float) -> float:
	var d: PackedByteArray = w.data
	var a: int = int(a_s * CineAudio.SR)
	var b: int = mini(int(b_s * CineAudio.SR), d.size() / 2)
	var acc: float = 0.0
	for i: int in range(a, b):
		var v: float = float(d.decode_s16(i * 2)) / 32767.0
		acc += v * v
	return sqrt(acc / maxf(float(b - a), 1.0))


func _audio() -> void:
	_check(is_equal_approx(EmoteDirector.CUE_START, EmoteDirector.LAND - WeaponAudio.SIUUU_BURST), "the cue starts at landing - 0.31 s (1.39)")
	var w: AudioStreamWAV = WeaponAudio.synth_siuuu()
	var secs: float = float(w.data.size()) / 2.0 / float(CineAudio.SR)
	_check(absf(secs - WeaponAudio.SIUUU_LEN) < 0.01, "the synthesized siuuu cue is 2.0 s")
	_check(_rms(w, 0.0, 0.24) < 0.005 and _rms(w, 0.25, 0.31) > 0.02, "silence, then the 'S' from 0.25 s")
	var best_t: float = 0.0
	var best: float = 0.0
	var tt: float = 0.2
	while tt < 1.9:
		var r: float = _rms(w, tt, tt + 0.01)
		if r > best:
			best = r
			best_t = tt
		tt += 0.005
	_check(absf(best_t - WeaponAudio.SIUUU_BURST) <= 0.02, "the vowel burst (loudest 10 ms) is at 0.31 s (%.3f)" % best_t)
	var sustain: float = _rms(w, 1.0, 1.5)
	_check(sustain > 0.05 and _rms(w, 1.6, 2.0) < sustain * 0.3, "the vowel sustains to ~1.57 s, then only a soft tail")
	var keep: String = WeaponAudio.sfx_dir
	WeaponAudio.sfx_dir = "res://tests/__no_sfx__/"
	WeaponAudio.clear_cache()
	_check(WeaponAudio.siuuu_file() == "" and WeaponAudio.siuuu_stream() is AudioStreamWAV, "empty sfx dir -> the synthesized cue")
	WeaponAudio.sfx_dir = keep
	WeaponAudio.clear_cache()
	var f: String = WeaponAudio.siuuu_file()
	_check(f == "" or ((f.ends_with("siuuu.ogg") or f.ends_with("siuuu.mp3")) and WeaponAudio.siuuu_stream() != null), "user://sfx: the owner's siuuu file when present (%s), else synthesized" % (f if f != "" else "none"))


func _poses() -> void:
	_check(EmoteDirector.pose_weight(0.5) == 0.0 and is_equal_approx(EmoteDirector.pose_weight(2.0), 1.0) and EmoteDirector.pose_weight(EmoteDirector.LENGTH) == 0.0, "pose overlay: off on the run-up, full in the hold, back to idle at 3.30 s")
	var p: Dictionary = EmoteDirector.pose_at(2.0)
	_check((p["shoulder_l"] as Vector3).is_equal_approx(EmoteDirector.POSE_LAND["shoulder_l"]) and float(p["hips_y"]) < 0.0, "the hold pose is the wide landing (arms down and out, hips low)")


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _key_b(pressed: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = KEY_B
	k.pressed = pressed
	wheel._input(k)


func _ped(at: Vector3, s: int) -> Pedestrian:
	var p: Pedestrian = World.ped(arena, at, s, player)
	targets.append(p)
	return p


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		dir = World.director(arena, player, targets)
		dir.equip(WeaponData.Slot.PISTOL)
		wheel = EmoteWheel.new()
		wheel.manual = true
		arena.add_child(wheel)
		emotes = EmoteDirector.new()
		emotes.name = "Emotes"
		arena.add_child(emotes)
		emotes.setup({"player": player, "weapons": dir, "wheel": wheel, "weapon_wheel": dir.wheel, "targets_fn": func() -> Array: return targets,
			"fx": dir.fx, "blocked_fn": func() -> bool: return blocked})
		emotes.finished.connect(func(id: String, c: bool) -> void: finishes.append([id, c, emotes.ended_t]))
		emotes.landed.connect(func(_at: float) -> void: land_yaw = player.model.rotation.y)
		var land := Vector3(0.0, 0.0, -5.63)
		for i: int in 20:
			var a: float = TAU * float(i) / 20.0 + 0.1
			var r: float = 4.0 + float(i % 5) * 0.9
			var q: Vector3 = land + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if absf(q.x) < 2.2:
				q.x = 2.2 if q.x >= 0.0 else -2.2           # keep the run-up / landing corridor clear
			near.append(_ped(q, 200 + i))
		for k: int in 4:
			far.append(_ped(land + Vector3(12.5, 0.0, -3.0 + 2.0 * float(k)), 230 + k))
		fleer = _ped(land + Vector3(5.0, 0.0, 2.0), 240)
		fleer.flee_from(land, 30.0)
		ko = _ped(land + Vector3(-5.0, 0.0, 2.0), 241)
		ko.knock_out(30.0, Vector3(1.0, 0.0, 0.0))
		_next("wheel")
		return
	var t: int = frames - t0
	if phase != "b" and emotes.active and dir.held != null and not dir.held.visible:
		hidden_seen = true
	match phase:
		"wheel":
			if t == 5:
				_check(wheel.slots.size() == 8 and String(wheel.slots[0]["name"]) == "Siuuu!" and wheel.is_enabled(0), "slot 0 is 'Siuuu!'")
				var greyed: bool = true
				for i: int in range(1, 8):
					greyed = greyed and not wheel.is_enabled(i) and String(wheel.slots[i]["name"]) == RadialWheel.SOON
				_check(greyed, "slots 1-7 are greyed 'Sắp có'")
				_key_b(true)
				wheel.step_real(0.05)
				_key_b(false)
				wheel.step_real(0.2)
				_check(not wheel.is_open() and not emotes.active and emotes.pending < 0, "a B tap does nothing")
				blocked = true
				_check(not emotes.play(0), "refused while blocked (riding, cinematic, busted, service)")
				_key_b(true)
				wheel.step_real(0.2)
				_check(not wheel.is_open(), "the emote wheel does not open while blocked")
				_key_b(false)
				blocked = false
				dir.reload_left = 1.0
				_check(not emotes.play(0), "refused while reloading")
				dir.reload_left = 0.0
				dir._fire_prev = true
				_check(not emotes.play(0), "refused while firing")
				dir._fire_prev = false
				dir.wheel.open()
				_check(not emotes.play(0), "refused while the weapon wheel is open (one wheel at a time)")
				dir.wheel.close(false)
				dir.aim_override = true
			if t == 8:
				_check(dir.aiming and not emotes.play(0), "refused while aiming")
				dir.aim_override = false
			if t == 11:
				_key_b(true)
				wheel.step_real(0.13)
				_check(wheel.is_open() and wheel.highlight == -1, "holding B opens the emote wheel")
				wheel.feed_mouse(Vector2(150.0, 0.0))
				_check(wheel.highlight == -1, "a greyed slot cannot be highlighted")
				wheel.feed_mouse(Vector2(-150.0, -150.0))
				_check(wheel.highlight == 0, "toward slot 0: 'Siuuu!'")
				_key_b(false)
				wheel.step_real(0.2)
				_check(emotes.pending == 0 or emotes.active, "releasing B on 'Siuuu!' plays it")
				_next("emote")
		"emote":
			if t == 120 and emotes.landed_t > 0.0:
				_check(emotes.bubble.visible and emotes.bubble.text == "SIUUU!", "the 'SIUUU!' bubble pops at the landing")
				_check(emotes.reactions.get("clap", 0) == 10 and emotes.reactions.get("shout", 0) == 5 and emotes.reactions.get("film", 0) == 3 and emotes.reactions.get("look", 0) == 2,
					"20 bystanders within 10 m: 10 clap, 5 shout back, 3 film, 2 look (%s)" % str(emotes.reactions))
				var far_ok: bool = true
				for p: Pedestrian in far:
					far_ok = far_ok and p.state == Pedestrian.State.IDLE
				_check(far_ok, "nobody beyond 10 m reacts")
				_check(fleer.state == Pedestrian.State.FLEE and ko.state == Pedestrian.State.KNOCKED_OUT, "fleeing and knocked-out people ignore it")
				_check(arena.find_children("Phone", "", true, false).size() == 3, "the filmers raise a glowing phone")
			if not finishes.is_empty() and not has_meta("e1"):
				set_meta("e1", true)
				var run: float = WeaponMath.flat(emotes.takeoff_pos, emotes.start_pos)
				_check(run > 4.2 and run < 4.8, "run-up ~4.5 m away from the camera (%.2f m)" % run)
				_check(absf(wrapf(land_yaw - emotes.start_yaw - PI, -PI, PI)) < 0.05, "turned 180° by the landing")
				_check(emotes.landed_t >= EmoteDirector.LAND - 1e-6 and emotes.landed_t <= EmoteDirector.LAND + FRAME + 1e-6, "lands at 1.70 s (%.3f)" % emotes.landed_t)
				_check(emotes.cue_t >= EmoteDirector.CUE_START - 1e-6 and emotes.cue_t <= EmoteDirector.CUE_START + FRAME + 1e-6, "the shout starts at 1.39 s (%.3f)" % emotes.cue_t)
				_check(absf(emotes.cue_t + WeaponAudio.SIUUU_BURST - emotes.landed_t) <= FRAME + 1e-4, "the vowel burst lands within one physics frame of the landing")
				_check(finishes[0][1] == false and absf(float(finishes[0][2]) - EmoteDirector.LENGTH) <= FRAME + 1e-6, "the emote lasts 3.30 s (%.3f)" % float(finishes[0][2]))
				_check(hidden_seen and dir.held.visible, "the pistol is hidden during the emote and back afterwards")
				set_meta("e1_t", t)
			if has_meta("e1_t") and t == int(get_meta("e1_t")) + 150:
				var resumed: bool = true
				for p2: Pedestrian in near:
					resumed = resumed and p2.state == Pedestrian.State.IDLE
				_check(resumed and arena.find_children("Phone", "", true, false).is_empty(), "the bystanders resume what they were doing")
				_check(emotes.play(0), "a second Siuuu! starts")
				_next("cancel")
			if t == 600 and not has_meta("e1"):
				_check(false, "the emote never finished")
				_finish()
		"cancel":
			if emotes.active and emotes.t >= 1.5 and emotes.t < 1.6:
				player.input_override = Vector2(0.0, -1.0)
			if finishes.size() == 2 and not has_meta("e2"):
				set_meta("e2", true)
				player.input_override = Vector2.ZERO
				var end_t: float = float(finishes[1][2])
				_check(finishes[1][1] == true and end_t >= EmoteDirector.CANCEL_FROM - 1e-6 and end_t <= EmoteDirector.CANCEL_FROM + FRAME + 1e-6, "movement input ends the emote only from 2.20 s (ended at %.3f)" % end_t)
				_next("dep")
			if t == 400 and not has_meta("e2"):
				_check(false, "the cancel test never finished")
				_finish()
		"dep":
			if t == 2:
				dir.equip(WeaponData.Slot.DEP)
			if t == 10:
				dir.cooldown = 0.0
				dir.fire_override = true
			if t == 11:
				dir.fire_override = false
			if t == 14:
				_check(dir.dep_in_flight and emotes.play(0), "test setup: the dép flies, the emote starts")
			if finishes.size() == 3 and not has_meta("e3"):
				set_meta("e3", true)
				_check(not dir.dep_in_flight and dir.held != null and dir.held.visible, "the dép came back during the emote and shows in the hand afterwards (R1-I2)")
				var p: Pedestrian = near[0]
				_check(p.react_emote("film", player.global_position, 3.0), "test setup: a bystander films")
				p.react("bump", Vector3(1.0, 0.0, 0.0), 3.0)
				_check(p.get("_react_prop") == null and p.react_kind == "" and p.state == Pedestrian.State.STUMBLE, "bumped while filming: the phone and the head look are dropped (R1-I1)")
				player.knock_down(Vector3(1.0, 0.0, 0.0), 1.0)
				_check(not emotes.play(0), "refused while knocked down")
				_start_b()
			if t == 400 and not has_meta("e3"):
				_check(false, "the dép emote test never finished")
				_finish()
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


func _opens(w: RadialWheel) -> bool:
	w.press()
	w.step_real(0.2)
	var o: bool = w.is_open()
	w.cancel()
	w.step_real(0.2)
	return o


func _part_b(t: int) -> void:
	var ew: EmoteWheel = roam.get("emote_wheel")
	var em: EmoteDirector = roam.get("emotes")
	var ww: WeaponWheel = roam.get("weapon_wheel")
	if t == 60:
		_check(ew != null and em != null, "FreeRoam builds the emote wheel and the emotes")
		ew.manual = true
		ww.manual = true
		roam.call("mount_bike")
	if t == 64:
		_check(not _opens(ew), "riding: the emote wheel is blocked")
		roam.call("dismount_bike")
	if t == 68:
		_check(_opens(ew), "on foot the emote wheel opens")
		_check(em.play(0), "Siuuu! starts in FreeRoam")
	if t == 72:
		_check(em.active and not _opens(ww) and (roam.get("weapons") as WeaponDirector).is_blocked(), "weapons and the weapon wheel are blocked during the emote")
	if t == 300:
		_check(not em.active and _opens(ww), "after the emote the weapon wheel opens again")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: EMOTES (B wheel, greyed slots, blocked states, run-up, 180° turn, landing 1.70, cue at landing - 0.31, 3.30 s, cancel from 2.20, weapon hidden, bystanders by share and radius, cue layout, override resolution, FreeRoam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
