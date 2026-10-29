# File: res://tests/test_forklift_joust.gd
# W3 Day 3 T7 (plan 2026-10-30-w3-day3.md, D3W-3): the forklift joust in the real yard (FreeRoam + LairYard +
# MissionForklift, the mission stepped by hand, the boss on physics frames):
#   A [F] in / out of the player's forklift (its camera, the player hidden on the seat);
#   B rams: a side ram while his forks are up = 15 % of the bar and he spins out (RECOVER); the same ram with the forks
#     down = a bump; T9: a stall (RECOVER) is a ram window too, once per stall; a front ram = both bounce, the player
#     takes 10;
#   C his tossed crate on the floor: lifted with the forks low, thrown back while he is stalled = 8 %;
#   D his charge: dodged (far off) = no hit; taken (the forklifts meet) = the player hurt once;
#   E the arena crane: a container on him while he is stalled = crush(): the next phase; the done info "crane";
#   F retry: both forklifts and the crane reset, a fresh boss; G 0 HP: the topple and the last-enemy orbit.
# Run:  godot --headless --path . --script tests/test_forklift_joust.gd
extends SceneTree

const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var fr: Node3D
var yard: LairYard
var m: MissionForklift
var mark: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST FORKLIFT JOUST (W3 Day 3 T7) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)


func _player() -> ThirdPersonController:
	return fr.get("player")


func _boss() -> ForkliftBoss:
	return m.fight.boss as ForkliftBoss


func _hold(b: ForkliftBoss) -> void:
	b.ai = false
	b._enter(ForkliftBoss.St.HOLD)


## Puts the player's forklift `dist` m from the boss along `side_dir` (world, flat), facing him, moving at `spd`.
func _line_up(side_dir: Vector3, dist: float, spd: float) -> void:
	var b: ForkliftBoss = _boss()
	var bp: Vector3 = b.forklift.global_position
	var at: Vector3 = bp + side_dir.normalized() * dist
	var f: Forklift = m.pf.forklift
	f.global_position = Vector3(at.x, f.floor_y, at.z)
	var to: Vector3 = bp - at
	f.rotation.y = atan2(-to.x, -to.z)
	f.speed = spd
	m.pf.input_override = {"throttle": 1.0 if spd > 0.0 else 0.0, "steer": 0.0, "fork": 0}


func _process(_d: float) -> bool:
	frames += 1
	if frames > 5000:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	match phase:
		0:
			fr = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
			fr.set("crowd_enabled", false)
			root.add_child(fr)
			phase = 1
			frames = 0
		1:
			if frames < 20:
				return false
			fr.call("set_time_of_day", "night")
			yard = LairYard.new()
			yard.build_in(fr)
			m = MissionForklift.new()
			fr.add_child(m)
			m.setup(fr, StoryMissions.beat("d3_boss"), {"manual": true, "seed": 7, "level": yard, "points": yard.mission_points("forklift")})
			m.begin()
			phase = 2
			frames = 0
		2:
			if frames < 3:
				return false
			var b: ForkliftBoss = _boss()
			_hold(b)
			b.forklift.global_position = yard.world(Vector3(2.0, 0.0, 4.0))   # in the crane's lane
			b.forklift.floor_y = b.forklift.global_position.y
			_check(m.pf != null and m.crane != null and m.crane.drops_left == 1, "the player's forklift and the arena crane (one drop)")
			# A
			var p: ThirdPersonController = _player()
			p.teleport(m.pf.forklift.global_position + Vector3(2.0, 0.0, 0.0), 0.0)
			m.advance(DT)
			_check(m.pf.hint() == PlayerForklift.T_ENTER and m.hud_prompt.text == PlayerForklift.T_ENTER, "[F] lái xe nâng near it")
			_check(m.pf.enter() and m.pf.inside and p.visible and not p.controls_enabled and m.pf.cam.current and p.model.position.y > 0.4, "[F]: in, the player on the seat, its chase camera")
			_check(m.pf.cam.has_meta(CameraDirector.META_FX), "the forklift camera takes the director's fx")
			m.pf.input_override = {"throttle": 1.0, "steer": 0.0, "fork": 1}
			var f0: Vector3 = m.pf.forklift.global_position
			var h0: float = m.pf.forks_h()
			mark["f0"] = f0
			mark["h0"] = h0
			phase = 3
			frames = 0
		3:
			m.advance(DT)
			if frames < 40:
				return false
			_check(m.pf.forklift.global_position.distance_to(mark["f0"]) > 1.0 and m.pf.forks_h() > float(mark["h0"]) + 0.3 and m.pf.speed() > 1.0, "WASD drives it, [E] raises the forks")
			m.pf.input_override = {"throttle": 0.0, "steer": 0.0, "fork": -1}
			phase = 4
			frames = 0
		4:
			m.advance(DT)
			if frames < 70:
				return false
			_check(m.pf.forks_h() < 0.3, "[Q] lowers them")
			m.pf.leave()
			_check(not m.pf.inside and _player().visible and _player().controls_enabled and not m.pf.cam.current, "[F] again: out on foot")
			m.pf.enter()
			# B: forks down: a side ram is a bump
			var b: ForkliftBoss = _boss()
			var right: Vector3 = b.forklift.global_basis.x
			var hp0: float = b.hp
			_line_up(right, 3.5, 6.0)
			m.advance(DT)
			_check(m.pf.rams == 0 and is_equal_approx(b.hp, hp0), "a side ram with his forks down: a bump, no damage")
			b.force_attack("toss")
			_check(b.forks_up() and b.forklift.beacon_mode == "yellow", "before a toss his forks go up (the yellow beacon): the ram window")
			m.pf._ram_cd = 0.0
			_line_up(right, 3.5, 6.0)
			m.advance(DT)
			_check(m.pf.rams == 1 and absf((hp0 - b.hp) - b.max_hp * 0.15) < 1.0 and b.state_name() == "recover", "a side ram while his forks are up: 15 %% of the bar, he spins out (%.0f -> %.0f, %s)" % [hp0, b.hp, b.state_name()])
			_check(not b.ram_open(), "T9: one ram per stall: the spin-out is not a second window")
			# T9: a stall (a missed charge / a crash: SƠ HỞ!) is a ram window too, once
			_hold(b)
			b.st_len = 9.0
			b._enter(ForkliftBoss.St.RECOVER)
			var right2: Vector3 = b.forklift.global_basis.x
			var hp_s: float = b.hp
			_check(b.ram_open() and b.recover_s(false) >= GunData.MISS_RECOVER_S, "T9: stalled = the ram window (and the stall lasts longer than GunData's)")
			m.pf._ram_cd = 0.0
			_line_up(right2, 3.5, 6.0)
			m.advance(DT)
			_check(m.pf.rams == 2 and hp_s - b.hp > b.max_hp * 0.14 and not b.ram_open(), "T9: a side ram on the stalled forklift: 15 %%, then closed (%.0f -> %.0f)" % [hp_s, b.hp])
			b.hp = hp_s          # back where it was: the later checks keep him above the name-intro threshold
			hp0 = b.hp
			# C: a crate on the floor, lifted and thrown back while he is stalled
			var c: Node3D = GunProps.crate(0.8)
			b.add_child(c)
			m.pf._ram_cd = 9.0
			_line_up(-right, 9.0, 0.0)
			m.pf.input_override = {"throttle": 0.0, "steer": 0.0, "fork": 0}
			c.global_position = m.pf.forklift.fork_tips() + Vector3(0.0, -m.pf.forks_h(), 0.0)
			b.floor_crates.append({"node": c, "t": 0.0})
			m.advance(DT)
			_check(m.pf.carrying() and b.floor_crates.is_empty(), "forks low, drive in: his crate is on the forks")
			var hp1: float = b.hp
			b.st_len = 9.0   # keep him stalled for the throw
			_check(m.pf.throw_crate(), "[Chuột trái]: thrown")
			for k: int in 60:
				m.advance(DT)
			_check(m.pf.throw_hits == 1 and absf((hp1 - b.hp) - b.max_hp * 0.08) < 1.0, "the crate back on him while he is stalled: 8 %% (%.0f -> %.0f)" % [hp1, b.hp])
			# front ram
			b.st_len = 0.0
			_hold(b)
			var combat: PlayerCombat = fr.get("combat")
			var php: float = combat.hp
			var hp2: float = b.hp
			m.pf._ram_cd = 0.0
			_line_up(b.forklift.forward(), 3.5, 6.0)
			m.advance(DT)
			_check(m.pf.front_rams == 1 and is_equal_approx(b.hp, hp2) and combat.hp <= php - 9.0 and m.pf.forklift.speed < 0.0, "a front ram: both bounce, the player takes 10 (%.0f -> %.0f)" % [php, combat.hp])
			combat.revive()
			# D: a charge
			b.force_attack("charge")
			phase = 5
			frames = 0
		5:
			var b5: ForkliftBoss = _boss()
			if b5.state_name() != "charge":
				if frames > 200:
					_check(false, "no charge after the telegraph")
					return _end()
				_line_up(b5.forklift.global_basis.x, 12.0, 0.0)   # well off to the side while he revs
				m.pf.input_override = {"throttle": 0.0, "steer": 0.0, "fork": 0}
				m.advance(DT)
				return false
			_check(frames >= 55, "the charge telegraph lasts about 1 s (%d frames)" % frames)
			m.advance(DT)
			_check(m.pf.charge_hits == 0, "dodged (well off his line): no hit")
			var combat5: PlayerCombat = fr.get("combat")
			var php5: float = combat5.hp
			var f5: Forklift = m.pf.forklift
			var front5: Vector3 = b5.forklift.global_position + b5.forklift.forward() * 1.5
			f5.global_position = Vector3(front5.x, f5.floor_y, front5.z)
			m.advance(DT)
			_check(m.pf.charge_hits == 1 and combat5.hp <= php5 - 20.0, "taken (the forklifts meet): the player hurt (%.0f -> %.0f)" % [php5, combat5.hp])
			m.advance(DT)
			_check(m.pf.charge_hits == 1, "once per charge")
			combat5.revive()
			phase = 6
			frames = 0
		6:
			if frames < 5:
				return false
			# E: the crane crush
			var b6: ForkliftBoss = _boss()
			m.pf.leave()
			b6.st_len = 30.0
			b6._enter(ForkliftBoss.St.RECOVER)
			var cr: YardCrane = m.crane
			var lp: Vector3 = cr.global_transform.affine_inverse() * b6.forklift.global_position
			cr.trolley_x = clampf(lp.x, YardCrane.X_RANGE.x, YardCrane.X_RANGE.y)
			cr.gantry_z = clampf(lp.z, YardCrane.Z_RANGE.x, YardCrane.Z_RANGE.y)
			cr._place()
			_check(cr.footprint_has(b6.forklift.global_position), "the hook right over his stalled forklift")
			var p6: ThirdPersonController = _player()
			p6.teleport(cr.ladder_foot(), 0.0)
			m.advance(DT)        # out of the forklift: the crane usable again on the next tick (one machine at a time)
			_check(cr.enter(p6), "on foot at the ladder: up the crane")
			for k2: int in 80:
				m.advance(DT)
			_check(cr.in_cabin(), "up in the cabin")
			var hp6: float = b6.hp
			var was2: bool = b6.phase2()
			_check(cr.drop(), "drop")
			for k3: int in 60:
				m.advance(DT)
			_check(m.crushed and b6.crushes == 1 and not was2 and b6.phase2() and b6.hp < hp6, "a container on him while stalled: the next phase (%.0f -> %.0f)" % [hp6, b6.hp])
			_check(cr.drops_left == 0, "the arena crane's one drop is used")
			# F: retry
			m.pf.enter() if m.pf.can_enter() else null
			m.retry()
			var b7: ForkliftBoss = _boss()
			_check(not m.pf.inside and m.pf.forklift.global_position.distance_to(yard.mission_points("forklift")["fork_at"]) < 0.3, "retry: the player's forklift back at its spot, empty")
			_check(m.crane.drops_left == 1 and m.crane.landed.is_empty() and not m.crane.in_cabin() and not m.crushed, "retry: the crane reset")
			_check(b7 != null and is_equal_approx(b7.hp, b7.max_hp) and b7 != b6, "retry: a fresh boss")
			mark["orbits0"] = Impact.clock(m).orbit_count
			b7.apply_damage(99999.0)
			phase = 7
			frames = 0
		7:
			if m.state == "running":
				m.advance(DT)
			if m.state != "done":
				if frames > 600:
					_check(false, "the boss did not topple / the mission did not end (%s)" % _boss().state_name() if _boss() else "gone")
					return _end()
				return false
			_check(Impact.clock(m).orbit_count > int(mark["orbits0"]), "0 HP: the forklift topples, the last-enemy orbit")
			_check(m.won_info.has("crane") and not bool(m.won_info["crane"]), "the done info has the crane objective (not used this run)")
			return _end()
	return false


func _end() -> bool:
	Difficulty.set_easy(false)
	if m and is_instance_valid(m) and m.state == "running":
		m.abort()
	if fails.is_empty():
		print("✅ SUCCESS: FORKLIFT JOUST (in / out, rams side / front / forks-down, crate back, charge dodged / taken, crane crush, retry, topple orbit)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
