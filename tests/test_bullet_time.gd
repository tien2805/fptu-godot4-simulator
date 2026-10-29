# File: res://tests/test_bullet_time.gd
# Headless test of the Wave 3 bullet time (plan 2026-10-30-w3-shared.md, W-1):
#   M  MusicDirector.focus_muffle: the bed low-pass reaches MUFFLE_CUTOFF within MUFFLE_TIME real seconds (also at a
#      0.35x time scale), a repeated call changes nothing, release goes back to the slot's tension cutoff (open here).
#   A  BulletTime core in a GunFight: the prompt "[Space] lao người" while aiming with focus; Space while aiming dives
#      (ThirdPersonController.dive_filter, no jump): 72 physics frames at 0.35x owned by the BulletTime, then 24 prone
#      frames at 1.0; the displacement follows real time; the focus cost (50, Dễ 40), the refill (5 / s, Dễ 7) and the
#      knockout bonus (+20, Dễ 25); shots per real second equal in and out of the dive (WeaponDirector.real_time); the
#      tint, the heartbeat and the muffle flag on during the slow part only; refused (a dull click, no cost, no jump)
#      without focus and in cover; Space without aiming is still a jump; while prone the enemies aim low.
# Counts frames at Engine.max_fps = 60.
# Run:  godot --headless --path . --script tests/test_bullet_time.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const BOX := [Vector3(30.0, 0.5, -2.0), Vector3(2.0, 1.0, 0.8)]

var fails: Array[String] = []
var world: Node
var frames: int = 0
var phase: String = ""
var t0: int = 0
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var combat: PlayerCombat
var targets: Array = []
var fight: GunFight
var bt: BulletTime
var aux: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	WeaponAudio.sfx_dir = "user://__test_no_sfx__/"
	print("--- TEST BULLET TIME (W-1) ---")
	world = Node.new()
	world.name = "BulletTimeTestWorld"
	root.add_child(world)
	await process_frame
	await _part_muffle()
	_build_arena()
	_next("a_setup")
	physics_frame.connect(_on_physics)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _next(p: String) -> void:
	phase = p
	t0 = frames
	print("  [phase] ", p)


# ---------------------------------------------------------------------------
# M
# ---------------------------------------------------------------------------
func _part_muffle() -> void:
	print("  [part] M muffle")
	var md := MusicDirector.new()
	world.add_child(md)
	await process_frame
	_check(is_equal_approx(md.filter_cutoff(), MusicDirector.CUTOFF_OPEN), "M: no muffle, a plain slot plays with the filter open")
	md.focus_muffle(true)
	await _frames(4)
	var mid: float = md.muffle
	md.focus_muffle(true)   # idempotent: the slide goes on from where it is
	_check(mid > 0.0 and mid < 1.0 and md.muffle == mid, "M: a repeated focus_muffle(true) changes nothing (%.2f)" % mid)
	await _frames(8)
	_check(md.muffle == 1.0 and is_equal_approx(md.filter_cutoff(), MusicDirector.MUFFLE_CUTOFF), "M: the cutoff reaches %.0f Hz within 0.2 s" % MusicDirector.MUFFLE_CUTOFF)
	var f: AudioEffectLowPassFilter = null
	var idx: int = AudioServer.get_bus_index(MusicDirector.BUS)
	for i: int in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectLowPassFilter:
			f = AudioServer.get_bus_effect(idx, i)
	_check(f != null and absf(f.cutoff_hz - MusicDirector.MUFFLE_CUTOFF) < 2.0, "M: the live bus filter is at the muffle cutoff (%.0f)" % (f.cutoff_hz if f else -1.0))
	md.focus_muffle(false)
	await _frames(12)
	_check(md.muffle == 0.0 and is_equal_approx(md.filter_cutoff(), MusicDirector.CUTOFF_OPEN) and f != null and f.cutoff_hz > 19000.0,
		"M: release goes back to the open cutoff")
	# real time: at 0.35x the muffle still lands in about 0.15 real s
	Engine.time_scale = 0.35
	md.focus_muffle(true)
	await _frames(12)
	_check(md.muffle == 1.0, "M: at a 0.35x time scale the muffle lands within 12 real frames (%.2f)" % md.muffle)
	md.focus_muffle(false)
	await _frames(12)
	Engine.time_scale = 1.0
	_check(md.muffle == 0.0, "M: released at 0.35x as well")
	md.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# ARENA
# ---------------------------------------------------------------------------
func _build_arena() -> void:
	arena = Node3D.new()
	arena.name = "Arena"
	world.add_child(arena)
	World.floor_box(arena, 600.0)
	World.wall(arena, BOX[0], BOX[1])
	player = World.player(arena, Vector3(0.0, 0.0, 0.0), 0.0)
	dir = World.director(arena, player, targets)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	combat.setup({"player": player, "weapons": dir})


func _fight(waves: Array, opts: Dictionary = {}) -> GunFight:
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
	var cm := CoverMap.new()
	cm.add_box(Transform3D(Basis.IDENTITY, BOX[0]), BOX[1])
	fight = GunFight.new()
	fight.name = "Fight_" + phase
	arena.add_child(fight)
	var o: Dictionary = {"player": player, "weapons": dir, "combat": combat, "cover": cm, "seed": 3}
	o.merge(opts, true)
	fight.setup(o)
	for w: Variant in waves:
		fight.add_wave(w)
	bt = fight.bullet_time
	return fight


func _held(at: Vector3) -> Dictionary:
	return {"at": at, "opts": {"ai": false}}


func _on_physics() -> void:
	frames += 1
	var t: int = frames - t0
	match phase:
		"a_setup":
			_ph_a_setup(t)
		"a_dive":
			_ph_a_dive(t)
		"a_after":
			_ph_a_after(t)
		"done":
			_end()


func _ph_a_setup(t: int) -> void:
	if t == 1:
		player.teleport(Vector3.ZERO, 0.0)
		_fight([[_held(Vector3(20.0, 0.0, -25.0)), _held(Vector3(-20.0, 0.0, -25.0)), _held(Vector3(24.0, 0.0, -25.0))]])
		fight.start()
		dir.aim_override = true
	elif t == 4:
		_check(bt != null and bt.get_parent() == fight, "A: the fight built its BulletTime")
		_check(is_equal_approx(bt.focus, 100.0) and is_equal_approx(BulletTime.cost(), 50.0), "A: full focus 100, a dive costs 50")
		_check(player.dive_filter.is_valid() and player.dive_filter.get_object() == bt, "A: the fight engaged the dive filter")
		_check(bt.can_prompt(), "A: aiming with focus: a dive is available")
	elif t == 30:   # (the HUD reads the fight in _process: give the first frames time to catch up)
		_check(fight.hud.prompt_text == BulletTime.T_PROMPT, "A: the prompt \"%s\" shows while aiming (%s)" % [BulletTime.T_PROMPT, fight.hud.prompt_text])
		_check(fight.hud.focus_shown and fight.hud.focus_bar.visible and is_equal_approx(fight.hud.focus_k, 1.0), "A: the focus bar shows, full")
		dir.aim_override = false
	elif t == 40:
		_check(fight.hud.prompt_text != BulletTime.T_PROMPT, "A: no prompt without aiming")
		player.jump_override = true          # Space without aiming: a plain jump
	elif t == 42:
		_check(player.move_state == "JUMP" or player.move_state == "AIR", "A: Space without aiming still jumps (%s)" % player.move_state)
		_check(bt.state == "idle" and is_equal_approx(bt.focus, 100.0), "A: ... and costs no focus")
	elif t == 100:
		# shots per real second outside the dive: fire held 72 frames
		dir.aim_override = true
		dir.ammo[WeaponData.Slot.PISTOL] = 12
		dir.cooldown = 0.0
		dir.fire_override = true
		aux["shots0"] = dir.shots
	elif t == 100 + 72:
		aux["out_shots"] = dir.shots - int(aux["shots0"])
		dir.fire_override = false
		dir.ammo[WeaponData.Slot.PISTOL] = 12
		dir.reload_left = 0.0
	elif t == 180:
		player.input_override = Vector2(1.0, 0.0)   # strafe right: the dive goes right (camera relative)
	elif t == 182:
		dir.cooldown = 0.0
		dir.fire_override = true
		aux["shots1"] = dir.shots
		aux["p0"] = player.global_position
		aux["dive_n"] = 0
		aux["scale_n"] = 0
		aux["prone_n"] = 0
		aux["fx_ok"] = true
		aux["low_ok"] = true
		aux["min_scale"] = 1.0
		player.jump_override = true
		_next("a_dive")


func _ph_a_dive(t: int) -> void:
	if t == 1:
		_check(bt.state == "dive" and player.is_diving(), "A: Space while aiming starts a dive (%s, %s)" % [bt.state, player.move_state])
		_check(is_equal_approx(bt.focus, 50.0), "A: the dive cost 50 focus (%.1f)" % bt.focus)
		_check(RadialWheel.scale_owner == bt and is_equal_approx(Engine.time_scale, BulletTime.SCALE), "A: the BulletTime owns the time scale at 0.35x")
		_check(bt.tint.visible and bt.heart.playing and bt.muffled and dir.real_time, "A: tint, heartbeat, muffle and real-time weapons on")
		_check(fight.cover_ctl.pose.pose_name == "dive", "A: the player's pose is the dive (%s)" % fight.cover_ctl.pose.pose_name)
		var d: Vector3 = player.global_position - (aux["p0"] as Vector3)
		_check(d.x > 0.0 and absf(d.z) < absf(d.x), "A: the dive goes in the move direction (right) (%s)" % str(d))
	if is_equal_approx(Engine.time_scale, BulletTime.SCALE):
		aux["scale_n"] = int(aux["scale_n"]) + 1
	if bt.state == "dive":
		aux["dive_n"] = int(aux["dive_n"]) + 1
		if not (bt.tint.visible and bt.heart.playing and dir.real_time):
			aux["fx_ok"] = false
	if player.is_prone():
		aux["prone_n"] = int(aux["prone_n"]) + 1
		if fight.player_target().y - player.global_position.y > GunData.TARGET_CROUCH_Y + 0.01:
			aux["low_ok"] = false
	if t == 72:
		aux["in_shots"] = dir.shots - int(aux["shots1"])
		dir.fire_override = false
		aux["p_end"] = player.global_position
	if t == 73:
		_check(bt.state == "prone" and player.is_prone() and is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null,
			"A: after 72 frames the scale is back to 1.0, the player lies prone (%s, %.2f)" % [bt.state, Engine.time_scale])
		_check(not bt.tint.visible and not bt.heart.playing and not bt.muffled and not dir.real_time, "A: the effects end with the slow part")
	if t == 110:
		_check(player.dive_frames == 72 and player.prone_frames == 24, "A: the controller dove 72 frames and lay 24 (%d, %d)" % [player.dive_frames, player.prone_frames])
		_check(absi(int(aux["scale_n"]) - 72) <= 1 and absi(int(aux["dive_n"]) - 72) <= 1, "A: 72 frames at 0.35x (%d scale, %d dive)" % [int(aux["scale_n"]), int(aux["dive_n"])])
		_check(absi(int(aux["prone_n"]) - 24) <= 1, "A: 24 frames prone (%d)" % int(aux["prone_n"]))
		_check(bool(aux["fx_ok"]), "A: the effects stayed on through the slow part")
		_check(bool(aux["low_ok"]), "A: while prone the enemies aim at the crouch height")
		_check(bt.state == "idle" and player.move_state == "GROUND", "A: back on the feet (%s, %s)" % [bt.state, player.move_state])
		# real-time displacement: sum of the dive speed curve over 72 real frames
		var want: float = 0.0
		for i: int in 72:
			var k: float = float(i + 1) / 72.0
			want += BulletTime.DIVE_SPEED * (1.0 if k < 0.75 else lerpf(1.0, 0.45, (k - 0.75) / 0.25)) / 60.0
		var got: float = ((aux["p_end"] as Vector3) - (aux["p0"] as Vector3)).length()
		print("    dive: %.2f m in 72 frames (real-time curve %.2f m); shots %d out, %d in" % [got, want, int(aux["out_shots"]), int(aux["in_shots"])])
		_check(absf(got - want) < want * 0.08, "A: the dive covers its real-time distance at 0.35x (%.2f of %.2f m)" % [got, want])
		_check(int(aux["out_shots"]) >= 4 and absi(int(aux["in_shots"]) - int(aux["out_shots"])) <= 1, "A: shots per real second equal in and out of the dive (%d / %d)" % [int(aux["in_shots"]), int(aux["out_shots"])])
		_check(fight.cover_ctl.pose.pose_name != "dive" and fight.cover_ctl.pose.pose_name != "prone" or fight.cover_ctl.pose.target_w == 0.0, "A: the dive pose is released")
		player.input_override = null
		aux["f0"] = bt.focus
		_next("a_after")


func _ph_a_after(t: int) -> void:
	if t == 60:
		var gain: float = bt.focus - float(aux["f0"])
		_check(absf(gain - 5.0) < 0.3, "A: focus refills 5 per second (+%.2f)" % gain)
		var g0: Gunman = fight.gunmen[0]
		var before: float = bt.focus
		for i: int in 3:
			g0.take_hit({"kind": "bullet", "from": player.global_position})
		_check(g0.is_down() and absf(bt.focus - minf(100.0, before + 20.0)) < 0.01, "A: a knockout adds 20 focus (%.1f -> %.1f)" % [before, bt.focus])
		# refused without focus: a dull click, no cost, no jump
		bt.focus = 10.0
		aux["clicks"] = bt.clicks
		player.jump_override = true
	elif t == 62:
		_check(bt.state == "idle" and bt.last_refusal == "focus" and bt.clicks == int(aux["clicks"]) + 1, "A: no focus: refused with a click (%s)" % bt.last_refusal)
		_check(player.move_state == "GROUND" and bt.focus >= 10.0 and bt.focus < 10.5, "A: ... no jump, no cost (%s, %.2f)" % [player.move_state, bt.focus])
		_check(not bt.can_prompt(), "A: no prompt without focus")
	elif t == 66:
		_check(fight.hud.prompt_text != BulletTime.T_PROMPT, "A: the HUD hides the prompt without focus")
		bt.focus = 100.0
		player.teleport(Vector3(30.75, 0.0, -1.0), 0.0)   # the front slot of the box
		fight.cover_ctl.hold_override = true
	elif t == 80:
		_check(fight.cover_ctl.in_cover, "A: in cover")
		player.jump_override = true
	elif t == 82:
		_check(bt.state == "idle" and bt.last_refusal == "cover" and is_equal_approx(bt.focus, 100.0), "A: in cover: refused (%s)" % bt.last_refusal)
		fight.cover_ctl.hold_override = false
	elif t == 90:
		Difficulty.set_easy(true)
		_check(is_equal_approx(BulletTime.cost(), 40.0) and is_equal_approx(BulletTime.refill_rate(), 7.0) and is_equal_approx(BulletTime.ko_bonus(), 25.0),
			"A Dễ: cost 40, refill 7 / s, knockout +25")
		Difficulty.set_easy(false)
		dir.aim_override = false
		fight.stop()
		_check(not player.dive_filter.is_valid(), "A: stop() gives the Space press back")
		_next("done")


func _end() -> void:
	physics_frame.disconnect(_on_physics)
	Engine.time_scale = 1.0
	Difficulty.set_easy(false)
	if fails.is_empty():
		print("--- BULLET TIME: SUCCESS ---")
		quit(0)
	else:
		print("--- BULLET TIME: FAIL (%d) ---" % fails.size())
		quit(1)
