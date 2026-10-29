# File: res://tests/test_mannequin_hide.gd
# W3 Day 3 T3 (plan 2026-10-30-w3-day3.md): the mannequin hide at the start of d3_gunfight, in the real yard (FreeRoam +
# LairYard + MissionYardGunfight, the mission stepped by hand):
#   A the set-up: ~40 mannequins (one crowd + 4 live), 3 blind sweepers in wave 0, the hide prompt;
#   B frozen in a flashlight = safe, moving / not frozen in it = caught (the fight starts early, `hidden` false), moving in
#     the dark = safe; the freeze holds HOLD_MAX at most;
#   C the head turn: only a live mannequin off camera, at most twice, never with "Giảm hù dọa";
#   D the guard in disguise: the scare, the scuffle won (mash [E]: thrown, a KO) and lost (20 damage), the fight alerted
#     either way;
#   E retry inside wave 0 = the hide again (sweepers calm, nothing frozen, no head turned).
# Run:  godot --headless --path . --script tests/test_mannequin_hide.gd
extends SceneTree

const DT: float = 1.0 / 60.0
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var fr: Node3D
var yard: LairYard
var m: MissionYardGunfight


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST MANNEQUIN HIDE (W3 Day 3 T3) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)
	var fx: Node = root.get_node_or_null("GameFX")
	if fx:
		fx.set("reduce_scares", false)


func _player() -> ThirdPersonController:
	return fr.get("player")


func _make_mission() -> void:
	if m and is_instance_valid(m):
		m.abort()
	m = MissionYardGunfight.new()
	fr.add_child(m)
	m.setup(fr, StoryMissions.beat("d3_gunfight"), {"manual": true, "manual_replay": true, "seed": 5, "level": yard,
		"points": yard.mission_points("gunfight")})
	m.begin()


func _step(secs: float) -> void:
	var n: int = int(round(secs / DT))
	for i: int in n:
		m.advance(DT)


## The player stands in sweeper k's flashlight, 6 m out along it.
func _into_beam(k: int) -> bool:
	var b: Dictionary = m.beam_of(k)
	if b.is_empty():
		return false
	var p: Vector3 = (b["eye"] as Vector3) + (b["dir"] as Vector3) * 6.0
	p.y = m.ground_y(p)
	_player().teleport(p, 0.0)
	return true


func _process(_d: float) -> bool:
	frames += 1
	if frames > 4000:
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
			_make_mission()
			phase = 2
			frames = 0
		2:
			if frames < 3:
				return false
			# A
			_check(m.hide_state == "sweep" and m.mannequins != null, "the hide starts with the sweep")
			_check(m.mannequins.count() >= 38 and m.mannequins.count() <= 42 and m.mannequins.live.size() == 4 and m.mannequins.crowd.count() == 36, "about 40 mannequins: one crowd of 36 + 4 live (%d)" % m.mannequins.count())
			_check(m.fight.wave == 0 and m.fight.gunmen.size() == 3, "3 sweepers in wave 0")
			var blind: bool = true
			for g: Variant in m.fight.gunmen:
				blind = blind and (g as Gunman).patrol_sight_m < 0.1 and not (g as Gunman).is_alerted
			_check(blind, "the sweepers are blind (the hide logic sees for them) and calm")
			_check(m.hud_prompt.text == MissionYardGunfight.T_FREEZE, "the [X] prompt")
			# B
			_check(_into_beam(0), "beam 0 exists")
			m.set_frozen(true)
			_check(m.is_frozen() and not _player().controls_enabled, "[X]: frozen, no control")
			_check(not m.caught_now(), "frozen in a flashlight: safe")
			_player().horizontal_speed = 2.0
			_check(m.caught_now(), "moving in a flashlight: caught")
			_player().horizontal_speed = 0.0
			m.set_frozen(false)
			_check(m.caught_now(), "standing (not frozen) in a flashlight: caught")
			var dark: Vector3 = yard.world(Vector3(-15.0, 0.0, 12.0))
			_player().teleport(dark, 0.0)
			_player().horizontal_speed = 3.0
			_check(not m.caught_now(), "moving in the dark: safe")
			_player().horizontal_speed = 0.0
			m.set_frozen(true)
			_step(m.hold_max + 0.2)
			_check(not m.is_frozen() and m.tired_t > 0.0 and m.hide_state == "sweep", "the freeze holds %.1f s at most (Mỏi chân!)" % m.hold_max)
			_into_beam(1)
			m.advance(0.12)
			_check(m.hide_state == "caught" and not m.hidden, "caught: the hide is over, hidden = false")
			var all: bool = true
			for g2: Variant in m.fight.alive():
				all = all and (g2 as Gunman).is_alerted
			_check(all and m.fight.state == "running", "caught: the gunfight starts early, no fail")
			# E (retry inside wave 0)
			m.retry()
			_check(m.hide_state == "sweep" and m.hidden and m.fight.wave == 0 and m.fight.gunmen.size() == 3, "retry: the hide again from its start")
			var calm: bool = true
			for g3: Variant in m.fight.alive():
				calm = calm and not (g3 as Gunman).is_alerted
			_check(calm and not m.is_frozen() and m.mannequins.head_turns == 0, "retry: the sweepers calm, nothing frozen, no head turned")
			# C
			var mq: YardMannequins = m.mannequins
			var live0: Vector3 = mq.live[0].global_position
			var cam_at: Vector3 = live0 + Vector3(0.0, 1.6, 4.0)
			var looking: Vector3 = (live0 - cam_at).normalized()
			mq.reduce_scares_override = false
			# looking at the whole live group from behind them: every live one on camera except where the angle is wide
			var on_cam: bool = true
			for c: CineCrowd in mq.live:
				var to: Vector3 = c.global_position - cam_at
				on_cam = on_cam and Vector3(looking.x, 0.0, looking.z).normalized().dot(Vector3(to.x, 0.0, to.z).normalized()) >= cos(deg_to_rad(YardMannequins.OFF_CAMERA_DEG))
			if on_cam:
				_check(not mq.turn_head_from(cam_at, looking), "no head turns while the camera is on them")
			var away: Vector3 = -looking
			_check(mq.turn_head_from(cam_at, away), "a head turns when the camera looks away")
			_check(mq.turn_head_from(cam_at, away), "a second one")
			_check(not mq.turn_head_from(cam_at, away) and mq.head_turns == 2, "at most twice")
			mq.reset()
			mq.reduce_scares_override = true
			_check(not mq.turn_head_from(cam_at, away), "never with Giảm hù dọa")
			mq.reduce_scares_override = false
			mq.reset()
			# D: the scuffle won
			_player().teleport(yard.world(LairYard.FIGHT_START), 0.0)
			m.set_frozen(true)   # frozen: a passing flashlight does not catch the player before the sweep ends
			m.hide_t = m.sweep_s - 0.05
			m.advance(0.1)
			_check(m.hide_state == "scare" and m.scares == 1 and not m.mannequins.disguised.visible, "the end of the sweep: the guard in disguise jumps out")
			_step(1.0)
			_check(m.hide_state == "scuffle" and m.hud_prompt.text == MissionYardGunfight.T_MASH, "then the scuffle: mash [E]")
			for i: int in m.mash_n:
				m.mash()
			m.advance(DT)
			_check(m.hide_state == "done" and m.scuffle_won and m.hide_kos == 1 and m.hidden, "mashed: he is thrown (a KO), still hidden")
			var al: bool = true
			for g4: Variant in m.fight.alive():
				al = al and (g4 as Gunman).is_alerted
			_check(al, "the fight starts alerted after the throw")
			_step(1.0)
			# D: the scuffle lost
			m.retry()
			_player().teleport(yard.world(LairYard.FIGHT_START), 0.0)
			var combat: PlayerCombat = fr.get("combat")
			var hp0: float = combat.hp
			m.set_frozen(true)   # frozen: a passing flashlight does not catch the player before the sweep ends
			m.hide_t = m.sweep_s - 0.05
			m.advance(0.1)
			_step(1.0)
			m.mash()
			_step(m.mash_window + 0.2)
			_check(m.hide_state == "done" and not m.scuffle_won and combat.hp <= hp0 - 19.0, "not mashed: he shoves, 20 damage (%.0f -> %.0f)" % [hp0, combat.hp])
			var al2: bool = true
			for g5: Variant in m.fight.alive():
				al2 = al2 and (g5 as Gunman).is_alerted
			_check(al2, "the fight starts alerted after the shove too")
			# Dễ: a shorter mash
			Difficulty.set_easy(true)
			_make_mission()
			_check(m.mash_n < 9 and m.hold_max > 4.0 and m.sweep_s < 26.0, "Dễ: fewer presses, a longer freeze, a shorter sweep")
			Difficulty.set_easy(false)
			return _end()
	return false


func _end() -> bool:
	Difficulty.set_easy(false)
	if m and is_instance_valid(m):
		m.abort()
	if fails.is_empty():
		print("✅ SUCCESS: MANNEQUIN HIDE (freeze rule, caught -> early fight, head turns, disguised guard both ways, retry)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
	return true
