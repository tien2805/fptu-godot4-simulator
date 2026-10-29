# File: res://tests/test_katana_qte.gd
# W3 Day 5 T6 (plan 2026-10-30-w3-day5.md, D5W-3): the katana duel's QTE finisher (SwordDuel + KatanaBoss + SwordQTE) in a
# bare arena. Checks: 0 HP opens the QTE instead of the finale (the boss frozen and invulnerable, the player's moves off,
# slow motion through Impact, the QTE camera framing both fighters); the prompts [Q] -> [Chuột trái] -> [E] in order, each
# window 0.9 s = 54 physics frames (Dễ 1.2 s = 72); a window running out = a miss: 10 % HP back, the duel goes on, the
# QTE comes again at 0; a pass plays the snap finale then `won`; qte_clean only for a first-time pass; the time scale, the
# scale owner, the camera and the controls are given back on every exit, a retry in the middle of the QTE included.
# Fix round: a mashed [Chuột trái] right after the QTE opens is ignored (grace), a wrong key after it costs WRONG_COST_S;
# the pause menu freezes the window and the keys, and the slow motion comes back after it; through the real
# PlayerCombat._strike the killing slash gets no last-KO orbit (the QTE keeps its slow motion and camera).
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_katana_qte.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var t0: int = 0
var phase: String = ""
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var combat: PlayerCombat
var duel: SwordDuel
var boss: KatanaBoss
var mark: Dictionary = {}
var won_n: int = 0


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("  FAIL ", msg)
	return ok


func _initialize() -> void:
	print("--- TEST KATANA QTE (D5W-3 finisher) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames
	mark.clear()


func _make_duel() -> void:
	duel = SwordDuel.new()
	duel.name = "Duel"
	arena.add_child(duel)
	duel.setup({"player": player, "combat": combat, "at": Vector3(0.0, 0.0, -1.6), "seed": 3, "look_host": arena,
		"boss": {"ai": false, "stats": {"block_chance": 0.0, "dodge_chance": 0.0, "stagger_max": 9999.0}}})
	duel.won.connect(func() -> void: won_n += 1)
	duel.start()
	boss = duel.boss


func _zero() -> String:
	return boss.take_strike({"kind": "slash1", "dmg": boss.hp + 1.0, "stagger": 0.0, "from": player.global_position})


func _cam() -> Camera3D:
	return arena.get_viewport().get_camera_3d()


## Both fighters' heads and chests inside the QTE camera's frustum.
func _framed() -> bool:
	for n: Node3D in [boss, player]:
		for h: float in [1.0, 1.6]:
			if not duel.qte_cam.is_position_in_frustum(n.global_position + Vector3(0.0, h, 0.0)):
				return false
	return true


func _restored(what: String) -> void:
	_check(not duel.in_qte and not duel.qte.active, "%s: the QTE closed" % what)
	_check(is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null, "%s: the time scale back to 1, no owner (%.2f, %s)" % [what, Engine.time_scale, str(RadialWheel.scale_owner)])
	_check(_cam() == player.camera and player.controls_enabled, "%s: the player's camera and controls back" % what)


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		arena.name = "Arena"
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3.ZERO, 0.0)
		combat = PlayerCombat.new()
		combat.name = "Combat"
		arena.add_child(combat)
		combat.setup({"player": player})
		_make_duel()
		_next("first")
		return
	var t: int = frames - t0
	if frames > 4000:
		_check(false, "watchdog: stuck in %s" % phase)
		_finish()
		return
	match phase:
		"first":
			if t == 2:
				player.camera.make_current()
				_check(_zero() == "ko", "the last hit lands")
				_check(boss.qte_ready() and boss.staged and boss.st == MeleeEnemy.St.IDLE and duel.in_qte and duel.qte_attempts == 1, "0 HP: the QTE, not the finale (boss frozen)")
				_check(boss.take_strike({"kind": "slash1", "dmg": 5.0, "from": player.global_position}) == "ignored" and not boss.katana.broken, "invulnerable at 0 HP, the katana whole")
				_check(duel.qte.index == 0 and duel.qte.wanted() == "q" and duel.qte.label.text == "[Q] GẠT", "prompt 1: [Q] gạt")
				_check(RadialWheel.scale_owner is Impact and is_equal_approx(Engine.time_scale, SwordDuel.QTE_SCALE), "slow motion through the Impact clock (%.2f)" % Engine.time_scale)
				_check(_cam() == duel.qte_cam and duel.qte_shots == 1 and _framed(), "the QTE camera: shot 1 frames both fighters")
				_check(not player.controls_enabled, "the player's moves are frozen")
				mark["start"] = frames
			if t > 2 and not duel.in_qte and not mark.has("end"):
				mark["end"] = frames
				var up: int = int(duel.qte.frames_up[0]) if not duel.qte.frames_up.is_empty() else -1
				_check(absi(up - 54) <= 1 and duel.qte.results == ["late"], "the window: 0.9 s = 54 physics frames (%d)" % up)
				_check(is_equal_approx(boss.hp, boss.max_hp * SwordDuel.QTE_RECOVER) and not boss.staged and not boss.qte_ready() and duel.state == "running", "a miss: 10 %% HP back, the duel goes on (%.1f)" % boss.hp)
				_check(combat.hud.popup_text == SwordDuel.T_QTE_MISS, "the miss line")
				_restored("miss")
				_next("second")
		"second":
			if t == 5:
				_check(_zero() == "ko" and duel.in_qte and duel.qte_attempts == 2, "0 HP again: the QTE comes again")
			if t == 15:
				_check(duel.qte.press("q") == "hit" and duel.qte.index == 1 and duel.qte.label.text == "[Chuột trái] CHÉM", "[Q] in time: prompt 2 [Chuột trái] chém")
				_check(duel.qte_shots == 2 and _cam() == duel.qte_cam and _framed(), "shot 2 frames both fighters")
				_check(int(duel.qte.frames_up[0]) == 10, "pressed 10 frames into the window (%s)" % str(duel.qte.frames_up))
			if t == 25:
				_check(duel.qte.press("lmb") == "hit" and duel.qte.index == 2 and duel.qte.wanted() == "e" and duel.qte_shots == 3 and _framed(), "[Chuột trái]: prompt 3 [E] hạ gục, shot 3")
			if t == 30:
				_check(duel.qte.press("e") == "hit", "[E]: passed")
				_check(boss.st == MeleeEnemy.St.FINALE and boss.katana.broken and not duel.qte_clean, "a pass plays the snap finale; not clean on the second QTE")
				_check(not duel.in_qte and _cam() == player.camera and player.controls_enabled, "the camera and the controls back after the pass")
			if t > 30 and duel.state == "won" and not mark.has("won"):
				mark["won"] = t
			if mark.has("won") and t == int(mark["won"]) + 30:
				_check(won_n == 1 and is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null, "then won, the time scale back")
				duel.retry()
				boss = duel.boss
				_next("wrong")
			if t == 600:
				_check(false, "the finale never won")
				_next("wrong")
		"wrong":
			if t == 5:
				_check(duel.qte_attempts == 0 and not duel.qte_clean, "retry: QTE count reset")
				_zero()
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = true
				duel.qte._unhandled_input(ev)        # the killing blow's attack button, still mashed
				_check(duel.in_qte and duel.qte.active and duel.qte.index == 0 and duel.qte.graced == 1, "a mashed [Chuột trái] right after the QTE opens is ignored (grace)")
				_check(duel.qte.press("e") == "grace" and duel.qte.active, "any wrong key inside the grace is ignored")
			if t == 25:
				_check(duel.qte.press("e") == "wrong" and duel.qte.active and duel.qte.wrongs == 1, "a wrong key after the grace costs time, not the QTE")
				_check(duel.qte.t >= 20.0 / 60.0 + SwordQTE.WRONG_COST_S - 0.01, "the window lost WRONG_COST_S (%.2f)" % duel.qte.t)
			if t > 25 and t < 80 and not duel.in_qte and not mark.has("wend"):
				mark["wend"] = t
				_check(duel.qte.results == ["late"] and t <= 5 + 54 - 15, "the shortened window runs out: a miss (%s at %d)" % [str(duel.qte.results), t])
				_check(is_equal_approx(boss.hp, boss.max_hp * SwordDuel.QTE_RECOVER), "the miss: 10 % back")
				_restored("wrong key")
			if t == 80:
				_zero()
				_check(duel.in_qte and duel.qte.active, "the QTE runs (pause test)")
				paused = true                         # the pause menu
			if t == 170:
				_check(duel.qte.active and duel.qte.index == 0 and duel.qte.frames_up.is_empty() and duel.qte._frames == 0, "paused 1.5 s: no window time passed")
				var kq := InputEventKey.new()
				kq.physical_keycode = KEY_Q
				kq.pressed = true
				duel.qte._unhandled_input(kq)
				_check(duel.qte.index == 0 and duel.qte.results.is_empty(), "paused: [Q] is not read")
				paused = false
			if t == 176:
				_check(duel.qte.active and Impact.clock(duel).slowmo_active(duel) and is_equal_approx(Engine.time_scale, SwordDuel.QTE_SCALE) 					and duel.qte_rearms >= 1, "unpaused: the QTE goes on and its slow motion is asked for again (%.2f)" % Engine.time_scale)
			if t > 176 and t < 300 and not duel.in_qte and not mark.has("pend"):
				mark["pend"] = t
				_restored("miss after the pause")
			if t == 300:
				_zero()
				_check(duel.in_qte and duel.qte.active, "the QTE runs (retry test)")
			if t == 310:
				duel.retry()
				boss = duel.boss
				_restored("retry mid-QTE")
				_check(is_equal_approx(boss.hp, boss.max_hp) and not boss.qte_ready() and boss.qte_armed, "retry mid-QTE: a fresh, armed boss")
			if t == 320:
				_zero()
				for k: String in ["q", "lmb", "e"]:
					duel.qte.press(k)
				_check(duel.qte_clean and boss.st == MeleeEnemy.St.FINALE, "a first-time pass is qte_clean")
			if t == 600:
				duel.stop()
				_restored("stop")
				_check(combat.last_fn != Callable(duel, "_duel_last"), "stop: the duel's last_fn wrapper is gone")
				duel.queue_free()
				_next("strike")
		"strike":
			if t == 3:
				_make_duel()
				_check(combat.last_fn == Callable(duel, "_duel_last"), "the duel wraps PlayerCombat.last_fn")
			if t == 6:
				var clk: Impact = Impact.clock(duel)
				var orbits0: int = clk.orbit_count
				boss.hp = 5.0
				var r: String = combat._strike(boss, {"kind": "slash1", "dmg": 40.0, "stagger": 0.0, "push": 0.2, "from": player.global_position})
				_check(r == "ko" and duel.in_qte, "the real strike path: the killing slash opens the QTE")
				_check(clk.orbit_count == orbits0 and clk.slowmo_active(duel) and not combat.is_last(boss), "no last-KO orbit: the QTE keeps its slow motion (orbits %d -> %d)" % [orbits0, clk.orbit_count])
				_check(_cam() == duel.qte_cam, "the QTE camera, not an orbit")
			if t == 40:
				_check(duel.in_qte and is_equal_approx(Engine.time_scale, SwordDuel.QTE_SCALE) and duel.qte_rearms == 0, "0.5 s later the QTE still owns the slow motion, nothing had to take it back (%.2f, %d)" % [Engine.time_scale, duel.qte_rearms])
				duel.stop()
				duel.queue_free()
				_next("easy")
		"easy":
			if t == 3:
				Difficulty.set_easy(true)
				_make_duel()
				Difficulty.set_easy(false)
				_check(is_equal_approx(duel.qte_window, 1.2), "Dễ: a 1.2 s window")
				Difficulty.set_easy(true)
				_check(is_equal_approx(SwordData.tell_s(), 0.62) and float(Difficulty.pick(SwordData.HP_SCALE, SwordData.HP_SCALE_EASY)) < SwordData.HP_SCALE, "Dễ: longer tells (0.62 s), less boss HP")
				Difficulty.set_easy(false)
				_check(is_equal_approx(SwordData.tell_s(), 0.5), "Thường: tells 0.5 s")
				_zero()
			if t > 3 and not duel.in_qte and not mark.has("end"):
				mark["end"] = true
				var up2: int = int(duel.qte.frames_up[0]) if not duel.qte.frames_up.is_empty() else -1
				_check(absi(up2 - 72) <= 1, "Dễ: 72 physics frames (%d)" % up2)
				_restored("easy miss")
				duel.queue_free()
				_next("done")
		"done":
			if t == 3:
				_check(_cam() == player.camera and is_equal_approx(Engine.time_scale, 1.0), "freeing the duel leaves the camera and the time alone")
				_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	Difficulty.set_easy(false)
	if fails.is_empty():
		print("SUCCESS: katana QTE (0 HP hold, prompts in order, windows in frames, miss 10 %, re-arm, pass -> finale -> won, qte_clean, exits restore time and camera)")
		quit(0)
	else:
		print("FAILED: %d check(s)" % fails.size())
		quit(1)
