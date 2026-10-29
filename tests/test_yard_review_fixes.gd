# File: res://tests/test_yard_review_fixes.gd
# The w3-day3 review fix round (plan 2026-10-30-w3-day3.md, "Review fixes"), in the real yard (FreeRoam + LairYard):
#   A a crane drop that knocks out the last gunman: the director's last-KO orbit holds the screen while the crane is left;
#     after the orbit the player's camera is current (not the cabin camera); no gun fire / aim from the cabin;
#   B a wave checkpoint taken while the player was up in the cabin, then THỬ LẠI (MissionYardGunfight): down at the
#     ladder foot, not in mid-air;
#   C the boss arena (MissionForklift): the player's forklift parked at the crane's ladder, seated: no ladder prompt, [E]
#     raises the forks and never starts the climb; no getting into the forklift while the crane is in use; no gun fire
#     from the forklift seat;
#   D the crates beat: the pallet rack is out of the fight until it rolls out (its crates and strap ignore hits, GunHUD
#     does not count them), then live.
# Run:  godot --headless --path . --script tests/test_yard_review_fixes.gd
extends SceneTree

const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var fr: Node3D
var yard: LairYard
var fight: GunFight
var crane: YardCrane
var mg: MissionYardGunfight
var mf: MissionForklift
var mc: MissionCrates
var mark: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST YARD REVIEW FIXES (w3-day3) ---")
	Engine.max_fps = 60


func _player() -> ThirdPersonController:
	return fr.get("player")


func _weapons() -> WeaponDirector:
	return fr.get("weapons")


func _process(_d: float) -> bool:
	frames += 1
	if frames > 4000:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	match phase:
		0:
			Difficulty.set_easy(false)
			fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			phase = 1
			frames = 0
		1:
			if frames < 20:
				return false
			Difficulty.set_easy(false)
			fr.call("set_time_of_day", "night")
			yard = LairYard.new()
			yard.build_in(fr)
			(fr.get("combat") as PlayerCombat).god = true
			# A: one held gunman in the footprint, the crane above him
			fight = GunFight.new()
			fight.name = "ReviewFight"
			fr.add_child(fight)
			fight.setup({"roam": fr, "cover_root": yard.cover_root, "seed": 4})
			fight.add_wave([{"at": yard.world(Vector3(0.0, 0.0, 5.0)), "opts": {"ai": false, "mask": "none"}}])
			fight.start()
			crane = YardCrane.new()
			fr.add_child(crane)
			crane.setup(yard.global_transform, fight, 3, 5.0, 0.0)
			fight.won.connect(func() -> void: crane.leave())     # what MissionYardGunfight._on_fight_won does
			phase = 2
			frames = 0
		2:
			if frames < 3:
				return false
			var p: ThirdPersonController = _player()
			mark["player_cam"] = p.camera
			p.teleport(crane.ladder_foot(), 0.0)
			crane.step(DT)
			_check(crane.enter(p), "A: up the ladder")
			for i: int in 80:
				crane.step(DT)
			var w: WeaponDirector = _weapons()
			_check(crane.in_cabin() and crane.cam.current and w.fire_override == false and w.aim_override == false, "A: in the cabin, its camera; no gun fire or aim from up there")
			crane.drop()
			phase = 3
			frames = 0
		3:
			crane.step(DT)
			var d: CameraDirector = CameraDirector.live()
			if fight.state == "won" and d != null and d.cut_kind == "orbit":
				mark["orbit_seen"] = true
			if frames < 240:
				return false
			var pc: Camera3D = mark["player_cam"]
			var w3: WeaponDirector = _weapons()
			_check(crane.kos_total == 1 and fight.state == "won" and bool(mark.get("orbit_seen", false)), "A: the drop knocks out the last gunman: the last-KO orbit runs")
			_check(crane.state == "idle" and not crane.cam.current and pc.current, "A: after the orbit the player's camera is current (cabin camera current: %s)" % str(crane.cam.current))
			_check(w3.fire_override == null and w3.aim_override == null and _player().controls_enabled, "A: the guns and the controls are back after the crane")
			crane.queue_free()
			fight.stop()
			fight.queue_free()
			phase = 4
			frames = 0
		4:
			if frames < 5:
				return false
			# B: MissionYardGunfight, a checkpoint taken in the cabin, then a retry
			mg = MissionYardGunfight.new()
			fr.add_child(mg)
			mg.setup(fr, StoryMissions.beat("d3_gunfight"), {"manual": true, "manual_replay": true, "seed": 5, "level": yard, "points": yard.mission_points("gunfight")})
			mg.begin()
			var p4: ThirdPersonController = _player()
			mg.crane.usable = true
			p4.teleport(mg.crane.ladder_foot(), 0.0)
			mg.crane.step(DT)
			_check(mg.crane.enter(p4), "B: up the crane")
			for k: int in 80:
				mg.crane.step(DT)
			mg.crane.move_override = Vector2(0.0, 1.0)
			for k2: int in 60:
				mg.crane.step(DT)
			mg.crane.move_override = Vector2.ZERO
			_check(mg.crane.in_cabin() and p4.global_position.y - yard.global_position.y > 5.0, "B: in the cabin")
			mg.fight.checkpoint()        # what a wave start (auto_checkpoint) does while he is up there
			mg.retry()
			var h: float = p4.global_position.y - yard.global_position.y
			_check(mg.crane.state == "idle" and h < 1.0 and WeaponMath.flat(p4.global_position, mg.crane.ladder_foot()) < 0.5 and p4.controls_enabled,
				"B: THỬ LẠI from a checkpoint taken in the cabin: at the ladder foot on the floor (height %.2f)" % h)
			mg.abort()
			mg = null
			phase = 5
			frames = 0
		5:
			if frames < 5:
				return false
			(mark["player_cam"] as Camera3D).make_current()
			# C: the boss arena
			mf = MissionForklift.new()
			fr.add_child(mf)
			mf.setup(fr, StoryMissions.beat("d3_boss"), {"manual": true, "seed": 7, "level": yard, "points": yard.mission_points("forklift")})
			mf.begin()
			phase = 6
			frames = 0
		6:
			if frames < 3:
				return false
			var b: ForkliftBoss = mf.fight.boss as ForkliftBoss
			b.ai = false
			b._enter(ForkliftBoss.St.HOLD)
			var p6: ThirdPersonController = _player()
			var lf: Vector3 = mf.crane.ladder_foot()
			mf.pf.forklift.global_position = Vector3(lf.x + 0.6, mf.pf.forklift.floor_y, lf.z)
			p6.teleport(mf.pf.forklift.global_position + Vector3(1.5, 0.0, 0.0), 0.0)
			mf.advance(DT)
			_check(mf.pf.enter() and mf.pf.inside, "C: in the forklift, parked at the ladder")
			mf.advance(DT)
			var w6: WeaponDirector = _weapons()
			_check(mf.crane.hint() == "" and not mf.crane.usable and w6.fire_override == false, "C: seated: no ladder prompt, the crane not usable, no gun fire from the seat")
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_E
			ev.pressed = true
			mf.crane._input(ev)
			mark["h0"] = mf.pf.forks_h()
			mf.pf.input_override = {"throttle": 0.0, "steer": 0.0, "fork": 1}   # [E] held = forks up
			phase = 61
			frames = 0
		61:
			mf.advance(DT)
			if frames < 50:
				return false
			var p6: ThirdPersonController = _player()
			var w6: WeaponDirector = _weapons()
			_check(mf.crane.state == "idle" and mf.pf.inside and mf.pf.forks_h() > float(mark["h0"]) + 0.3, "C: [E] raises the forks only (crane %s, forks %.2f)" % [mf.crane.state, mf.pf.forks_h()])
			mf.pf.input_override = null
			mf.pf.leave()
			_check(w6.fire_override == null and p6.controls_enabled, "C: out of the forklift: the guns and controls back")
			# the crane in use: no forklift
			p6.teleport(mf.crane.ladder_foot(), 0.0)
			mf.advance(DT)
			_check(mf.crane.enter(p6), "C: on foot: up the crane")
			mf.advance(DT)
			p6.global_position = mf.pf.forklift.global_position + Vector3(1.2, 0.0, 0.0)
			mf.advance(DT)
			_check(not mf.pf.can_enter(), "C: no getting into the forklift while the crane is in use")
			mf.crane.leave()
			mf.abort()
			mf = null
			phase = 7
			frames = 0
		7:
			if frames < 5:
				return false
			(mark["player_cam"] as Camera3D).make_current()
			# D: the crates beat
			for c: SmartCrate in yard.crates:
				c.reset()
			mc = MissionCrates.new()
			fr.add_child(mc)
			mc.setup(fr, StoryMissions.beat("d3_crates"), {"manual": true, "manual_replay": true, "seed": 3, "level": yard, "points": yard.mission_points("crates")})
			mc.begin()
			var rc: SmartCrate = mc.rack_crates[0]
			_check(rc.take_hit({"kind": "bullet", "from": _player().global_position}) == "none" and mc.strap.take_hit({"kind": "bullet", "from": _player().global_position}) == "none",
				"D: the hidden rack's crates and strap ignore hits")
			_check(mc.fight.enemies_left() == 12 and mc.broken_count() == 0, "D: GunHUD's count leaves the rack out until it rolls out (%d)" % mc.fight.enemies_left())
			while mc.clock < mc.rack_at + 0.1:
				mc.advance(0.1)
			_check(mc.rack_on and mc.fight.enemies_left() == 15 and rc.take_hit({"kind": "bullet", "from": _player().global_position}) == "knocked_out", "D: rolled out: the rack is live (%d)" % mc.fight.enemies_left())
			mc.abort()
			mc = null
			return _end()
	return false


func _end() -> bool:
	Difficulty.set_easy(false)
	if fails.is_empty():
		print("✅ SUCCESS: YARD REVIEW FIXES (crane camera after a last-KO orbit, retry off the crane, forklift vs crane, the hidden rack)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
