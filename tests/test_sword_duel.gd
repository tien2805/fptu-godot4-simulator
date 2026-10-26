# File: res://tests/test_sword_duel.gd
# Headless test of the Phase C sword duel (spec 2026-10-26-story-phase-c-days-2-3-5-design.md, C-D3 / C-D4 Day 5, C-D13
# test_sword_duel), in an arena with a PlayerCombat and a SwordDuel against Lê Minh Za Mẫn (KatanaBoss):
#   start() swaps in the staff move set (texts, poses, sounds) and puts the staff in the player's hand, the boss bar shows;
#   LMB 3-slash combo (staff poses, sparks + dust, wood sounds, the katana wobbles); RMB thrust breaks his guard (a slash
#   on it clashes); a held block stops a slash (no damage, no parry); a block pressed within 0.2 s = parry: "GẠT ĐỠ", the
#   boss staggers >= 1.2 s; Space dodges (also at 8 m: dodge range 14 m) with 0.35 s invulnerability and a slash during
#   the roll is avoided; AI on: every hit comes 0.5 s after its glint + sound, the glint shows, unblockable tells flash
#   red; the lunge dashes in from 5 m through the block, the spin hits at 2.6 m; player down -> lost (he stands down);
#   retry() -> a fresh boss, full HP, back at the start, still the staff; phases at 66 / 33 % (signal, faster, spin then
#   frenzy); katana bend stages 1-3 at 75 / 50 / 25 % (the blade visibly curves more); 0 HP -> FINALE (snap, slow motion,
#   the line, a falling tip) -> knockout -> won; stop() restores the unarmed set; freeing a running duel too.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_sword_duel.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var combat: PlayerCombat
var duel: SwordDuel
var boss: KatanaBoss
var mark: Dictionary = {}
var won_n: int = 0
var lost_n: int = 0
var phases_seen: Array[int] = []
var countered_n: int = 0


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)
	return ok


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	WeaponAudio.sfx_dir = "user://__no_owner_sfx__/"   # never the owner's files
	print("--- TEST SWORD DUEL ---")
	_data_checks()
	physics_frame.connect(_on_physics)


func _data_checks() -> void:
	_check(SwordData.STAFF_LIGHT.size() == 3 and String(SwordData.STAFF_HEAVY["id"]) == "thrust" and bool(SwordData.STAFF_HEAVY["breaks_block"]), "staff: 3 slashes and a thrust that breaks blocks")
	_check(is_equal_approx(SwordData.TELL_S, 0.5), "boss tells 0.5 s ahead")
	_check(is_equal_approx(float(SwordData.PHASES[1]["at"]), 0.66) and is_equal_approx(float(SwordData.PHASES[2]["at"]), 0.33), "phases at 66 % and 33 %")
	_check(not (SwordData.PHASES[0]["patterns"] as Array).has("spin") and (SwordData.PHASES[1]["patterns"] as Array).has("spin") and (SwordData.PHASES[2]["patterns"] as Array).has("frenzy"), "phase 2 adds the spin, phase 3 the frenzy")
	_check(float(SwordData.PHASES[2]["speed_k"]) > float(SwordData.PHASES[1]["speed_k"]) and float(SwordData.PHASES[1]["speed_k"]) > 1.0, "each phase is faster")
	for sn: String in SwordData.STEPS.keys():
		_check(float(SwordData.STEPS[sn]["hit"]) < SwordData.TELL_S, "step %s: the hit fits inside the tell" % sn)
	for s: String in [SwordData.T_CONTROLS, SwordData.T_PARRY, SwordData.T_BOSS, SwordData.T_BREAK] + SwordData.T_PHASE + SwordData.T_BEND:
		_check(_plain(s), "plain text without emoji or decorative symbols: '%s'" % s)
	for c: String in SwordAudio.CUES:
		_check(SwordAudio.synth(c).get_length() > 0.05, "cue %s synthesizes" % c)
	_check(SwordData.phase_of(1.0) == 1 and SwordData.phase_of(0.66) == 2 and SwordData.phase_of(0.2) == 3, "phase_of")
	_check(SwordData.bend_stage_of(0.8) == 0 and SwordData.bend_stage_of(0.7) == 1 and SwordData.bend_stage_of(0.4) == 2 and SwordData.bend_stage_of(0.1) == 3, "bend_stage_of")


## Letters (any script), digits, spaces, basic punctuation, the [ ] of a key glyph and the middle dot of the hint only.
static func _plain(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c > 0x2000 or (c < 0x80 and not (char(c) in " ,.:!-[]0123456789") and not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122))):
			return false
	return true


func _next(p: String) -> void:
	phase = p
	t0 = frames
	mark.clear()


func _reset_player(at: Vector3 = Vector3.ZERO) -> void:
	player.teleport(at, 0.0)
	player.pitch = 0.0
	combat.revive()
	combat.block_override = null


func _place(at: Vector3) -> void:
	boss.global_position = at
	boss.push_v = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	var to: Vector3 = player.global_position - at
	boss.set_yaw(atan2(-to.x, -to.z))


func _kinds(kinds: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in combat.strikes:
		if kinds.has(String(s["kind"])):
			out.append(s)
	return out


func _sparks() -> int:
	return combat.fx.cine.find_children("Sparks*", "", true, false).size()


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
		combat.countered.connect(func(_x: Node3D) -> void: countered_n += 1)
		duel = SwordDuel.new()
		duel.name = "Duel"
		arena.add_child(duel)
		duel.setup({"player": player, "combat": combat, "at": Vector3(0.0, 0.0, -1.6), "seed": 3,
			"boss": {"ai": false, "stats": {"block_chance": 0.0, "dodge_chance": 0.0, "stagger_max": 9999.0}}})
		duel.won.connect(func() -> void: won_n += 1)
		duel.lost.connect(func() -> void: lost_n += 1)
		duel.phase_changed.connect(func(p: int) -> void: phases_seen.append(p))
		duel.start()
		boss = duel.boss
		_next("arm")
		return
	var t: int = frames - t0
	if frames == 12000:
		_check(false, "watchdog: stuck in phase %s (%s)" % [phase, str(mark)])
		_finish()
		return
	match phase:
		"arm":
			_arm(t)
		"combo":
			_combo(t)
		"heavy":
			_heavy(t)
		"block":
			_block(t)
		"parry":
			_parry(t)
		"dodge":
			_dodge(t)
		"telegraph":
			_telegraph(t)
		"lunge":
			_lunge(t)
		"spin":
			_spin(t)
		"lost":
			_lost(t)
		"retry":
			_retry(t)
		"phases":
			_phases(t)
		"break":
			_break(t)
		"stop":
			_stop(t)


# ---------------------------------------------------------------------------
func _arm(t: int) -> void:
	if t == 3:
		_check(boss != null and boss is KatanaBoss and boss.label == SwordData.T_BOSS, "start() spawns Za Mẫn, the katana boss")
		_check(boss.katana != null and boss.katana.is_inside_tree() and boss.body.is_ancestor_of(boss.katana), "the katana is in his hand")
		_check(boss.katana.segs.size() == KatanaProp.SEGMENTS and boss.katana.stage == 0 and not boss.katana.broken, "a straight, whole, segmented katana")
		_check(combat.light_moves.size() == 3 and String(combat.light_moves[0]["id"]) == "slash1" and String(combat.heavy_move["id"]) == "thrust" and String(combat.counter_move["id"]) == "parry", "the staff move set is in")
		_check(combat.controls_text == SwordData.T_CONTROLS and combat.counter_text == SwordData.T_PARRY and combat.blade and combat.dodge_m > 10.0, "staff texts, sparks, long dodge range")
		_check(duel.staff != null and duel.staff.is_inside_tree() and player.model.is_ancestor_of(duel.staff) and duel.staff.get_node_or_null("Tip") != null, "the Vovinam staff is in the player's hand")
		_check(combat.boss == boss and combat.fight_active and duel.state == "running", "the duel runs, the boss is the combat's boss")
		_check(boss.boss_marks().size() == 2 and is_equal_approx(boss.boss_marks()[0], 0.66), "the boss bar marks the phases")
		_check(boss.st == MeleeEnemy.St.HOLD and boss.pose.pose_name == "sw_kat_guard", "he stands in his katana guard (%s, %s)" % [boss.state_name(), boss.pose.pose_name])
		_check(combat.pose.pose_name == "sw_staff_guard", "the player holds the staff guard while idle (%s)" % combat.pose.pose_name)
		var tip: Vector3 = duel.staff.get_node("Tip").global_position
		_check(tip.distance_to(player.global_position) > 0.8, "the staff sticks out of the hand (tip %.2f m from the feet)" % tip.distance_to(player.global_position))
		_next("combo")


func _combo(t: int) -> void:
	if t == 4:
		mark["sp"] = _sparks()
	if t == 5 or t == 23 or t == 43:
		combat.light_override = true
	if t == 6:
		_check(combat.state == PlayerCombat.St.LIGHT and combat.combo_i == 0 and combat.pose.pose_name == "sw_staff_slash_a", "LMB: the first staff slash with its pose (%s)" % combat.pose.pose_name)
	if t == 24:
		_check(_sparks() > int(mark["sp"]), "a landed staff hit throws sparks (%d -> %d)" % [int(mark["sp"]), _sparks()])
		_check(combat.cues.has("staff_hit") and combat.cues.has("staff_swish"), "wood hit and swish sounds (%s)" % str(combat.cues))
		_check(boss.katana.wobble_amp > 0.0, "the katana wobbles when he is hit")
		_check(combat.hud.visible and combat.hud.boss_shown and combat.hud.boss_bar.visible, "the boss bar shows (hud %s, shown %s, bar %s)" % [combat.hud.visible, combat.hud.boss_shown, combat.hud.boss_bar.visible])
		var br: Rect2 = combat.hud.boss_bar.get_global_rect()
		var vr: Rect2 = combat.hud.get_viewport().get_visible_rect()
		_check(vr.encloses(br) and not br.intersects(combat.hud.bar.get_global_rect()) and br.position.y < vr.size.y * 0.3, "the boss bar sits on screen at the top, under the HP bar (%s)" % str(br))
	if t == 80:
		var k: Array[Dictionary] = _kinds(["slash1", "slash2", "slash3"])
		var names: Array[String] = []
		var res: Array[String] = []
		for s: Dictionary in k:
			names.append(String(s["kind"]))
			res.append(String(s["result"]))
		_check(names == ["slash1", "slash2", "slash3"], "three presses: three slashes (%s)" % str(names))
		_check(res == ["hit", "hit", "hit"], "each lands (%s)" % str(res))
		_check(is_equal_approx(boss.hp, boss.max_hp - 35.0), "9 + 11 + 15 damage (hp %.1f)" % boss.hp)
		_next("heavy")


func _heavy(t: int) -> void:
	if t == 1:
		_reset_player()
		_place(Vector3(0.0, 0.0, -1.6))
	if t == 40:
		_check(boss.st == MeleeEnemy.St.HOLD, "test setup: back in guard (%s)" % boss.state_name())
		boss.force_block(2.0)
		mark["hp"] = boss.hp
	if t == 42:
		combat.light_override = true
	if t == 48:
		_check(boss.pose.pose_name == "sw_kat_block", "his block is the katana block pose (%s)" % boss.pose.pose_name)
	if t == 65:
		var last: Dictionary = combat.strikes.back()
		_check(String(last["result"]) == "blocked" and is_equal_approx(boss.hp, float(mark["hp"])), "his katana blocks a slash (%s)" % str(last))
		_check(combat.cues.has("blade_clash"), "staff on katana: the clash sound")
		combat.heavy_override = true
	if t == 66:
		_check(combat.state == PlayerCombat.St.HEAVY and String(combat.move["id"]) == "thrust" and combat.pose.pose_name == "sw_staff_thrust", "RMB: the thrust")
	if t == 100:
		var last2: Dictionary = combat.strikes.back()
		_check(String(last2["kind"]) == "thrust" and String(last2["result"]) == "guard_break", "the thrust breaks his guard (%s)" % str(last2))
	if t == 140:
		_next("block")


## A held block stops a slash; the tell comes 0.5 s ahead with a white glint.
func _block(t: int) -> void:
	if t == 1:
		_reset_player()
		_place(Vector3(0.0, 0.0, -1.6))
		combat.block_override = true
	if t == 30:
		_check(boss.st == MeleeEnemy.St.HOLD, "test setup: in guard (%s)" % boss.state_name())
		_check(combat.blocking and combat.pose.pose_name == "sw_staff_block", "hold Q: the staff block pose (%s)" % combat.pose.pose_name)
		mark["n"] = boss.hit_log.size()
		mark["tells"] = boss.tells.size()
		mark["hp"] = combat.hp
		boss.force_pattern("slash_r")
	if t == 33:
		_check(boss.tells.size() == int(mark["tells"]) + 1 and not bool(boss.tells.back()["red"]), "a white glint tells the slash")
		_check(boss.katana.glint_on and boss.katana.glint.visible and boss.incoming() == 1, "the glint shows on the blade; incoming light")
		_check(combat.cues.has("glint"), "the glint sound")
		_check(not boss.flash_on, "a blockable slash does not flash red")
	if t > 30 and not mark.has("done") and boss.hit_log.size() > int(mark["n"]):
		mark["done"] = true
		var h: Dictionary = boss.hit_log.back()
		var lead: float = float(h["t"]) - float(boss.tells.back()["t"])
		_check(String(h["result"]) == "blocked", "a held block stops his slash (%s)" % String(h["result"]))
		_check(lead >= 0.48 and lead <= 0.52, "the hit lands 0.5 s after the glint (%.3f s)" % lead)
		_check(is_equal_approx(combat.hp, float(mark["hp"])) and countered_n == 0, "no damage, no parry for an early block")
		_check(not boss.katana.glint_on, "the glint is gone at the hit")
	if t == 110:
		_check(mark.has("done"), "the blocked slash resolved")
		combat.block_override = false
		_next("parry")


func _parry(t: int) -> void:
	if t == 30:
		_reset_player()
		combat.block_override = false
		_place(Vector3(0.0, 0.0, -1.6))
	if t == 40:
		mark["n"] = boss.hit_log.size()
		mark["hp_b"] = boss.hp
		boss.force_pattern("slash_r")
	if t > 40 and not mark.has("pressed") and boss.st == MeleeEnemy.St.ATTACK and boss.st_t >= 0.04:
		mark["pressed"] = t
		combat.block_override = true             # ~0.1 s before his hit
	if mark.has("pressed") and not mark.has("done") and boss.hit_log.size() > int(mark["n"]):
		mark["done"] = true
		_check(String(boss.hit_log.back()["result"]) == "perfect", "a block within 0.2 s of the hit: perfect (%s)" % String(boss.hit_log.back()["result"]))
		_check(boss.st == MeleeEnemy.St.STAGGER and boss.st_len >= 1.2 and boss.parries == 1, "the parry staggers him %.1f s (%s)" % [boss.st_len, boss.state_name()])
		_check(combat.hud.popup_text == SwordData.T_PARRY and countered_n == 1, "'GẠT ĐỠ' pops (%s)" % combat.hud.popup_text)
		var pr: Array[String] = combat.results_of("parry")
		_check(not pr.is_empty() and pr.back() == "parried" and boss.hp < float(mark["hp_b"]), "the riposte lands on him (%s)" % str(pr))
		_check(combat.cues.has("parry_ring") and is_equal_approx(combat.hp, 100.0), "the parry rings; no damage")
		_check(not boss.katana.glint_on and boss._pattern.is_empty(), "the parry drops his pattern")
	if mark.has("done") and not mark.has("rec") and boss.st == MeleeEnemy.St.HOLD:
		mark["rec"] = t
	if mark.has("rec"):
		combat.block_override = null
		_next("dodge")
	elif t == 300:
		_check(false, "the parry test never finished (%s)" % str(mark))
		combat.block_override = null
		_next("dodge")


func _dodge(t: int) -> void:
	if t == 1:
		_reset_player()
		_place(Vector3(0.0, 0.0, -8.0))
	if t == 20:
		player.jump_override = true
	if t == 21:
		_check(combat.state == PlayerCombat.St.DODGE and player.move_state == "LAND_ROLL", "Space with Za Mẫn 8 m away dodge-rolls in a duel (%s)" % player.move_state)
		_check(combat.invuln_left > 0.3 and combat.receive_attack(boss, {"damage": 10.0}) == "dodged", "invulnerable during the roll")
	if t == 44:
		_check(combat.invuln_left <= 0.0 and combat.receive_attack(boss, {"damage": 10.0}) == "hit", "the invulnerability ends at 0.35 s")
	if t == 90:
		_reset_player()
		_place(Vector3(0.0, 0.0, -1.6))
	if t == 120:
		mark["n"] = boss.hit_log.size()
		boss.force_pattern("slash_r")
	if t > 120 and not mark.has("rolled") and boss.st == MeleeEnemy.St.ATTACK and boss.st_t >= 0.05:
		mark["rolled"] = true
		player.jump_override = true
	if mark.has("rolled") and not mark.has("done") and boss.hit_log.size() > int(mark["n"]):
		mark["done"] = true
		var r: String = String(boss.hit_log.back()["result"])
		_check((r == "dodged" or r == "miss") and is_equal_approx(combat.hp, 100.0), "a roll just before his slash avoids it (%s, hp %.1f)" % [r, combat.hp])
	if t == 240:
		_check(mark.has("done"), "the rolled-through slash resolved")
		_reset_player()
		_place(Vector3(0.0, 0.0, -4.0))
		combat.god = true
		boss.ai = true
		boss._to_idle_state()
		_next("telegraph")


## AI on for 15 s: every hit 0.5 s after its glint + sound; glints show; unblockable tells flash red.
func _telegraph(t: int) -> void:
	if t == 1:
		mark["h0"] = boss.hit_log.size()
		mark["bad_glint"] = 0
		mark["bad_flash"] = 0
		mark["cues0"] = 0
	if boss.st == MeleeEnemy.St.WINDUP and boss._glinted and not boss.katana.glint.visible:
		mark["bad_glint"] = int(mark["bad_glint"]) + 1
	if boss.incoming() == 2 and not boss.flash_on:
		mark["bad_flash"] = int(mark["bad_flash"]) + 1
	if boss.incoming() == 2:
		mark["red_seen"] = true
	if t == 900:
		var hits: Array[Dictionary] = boss.hit_log.slice(int(mark["h0"]))
		var bad: Array[String] = []
		for h: Dictionary in hits:
			var best: float = -1.0
			for tl: Dictionary in boss.tells:
				if String(tl["step"]) == String(h["step"]) and float(tl["t"]) <= float(h["t"]):
					best = float(h["t"]) - float(tl["t"])
			var hi: float = 0.52 + (float(SwordData.STEPS["lunge"]["dash_s"]) if String(h["step"]) == "lunge" else 0.0)
			if best < 0.48 or best > hi:
				bad.append("%s %.3f" % [String(h["step"]), best])
		print("  AI duel: %d boss hits in 15 s (%s), %d tells" % [hits.size(), str(_steps_of(hits)), boss.tells.size()])
		_check(hits.size() >= 4, "AI on: Za Mẫn keeps attacking (%d hits)" % hits.size())
		_check(bad.is_empty(), "every hit lands 0.5 s after its glint + sound (bad: %s)" % str(bad))
		_check(int(mark["bad_glint"]) == 0, "the glint is visible through every tell (%d bad frames)" % int(mark["bad_glint"]))
		_check(int(mark["bad_flash"]) == 0, "unblockable tells flash red (%d bad frames)" % int(mark["bad_flash"]))
		combat.god = false
		boss.ai = false
		boss._to_idle_state()
		_next("lunge")


func _steps_of(hits: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for h: Dictionary in hits:
		out.append(String(h["step"]))
	return out


func _lunge(t: int) -> void:
	if t == 30:
		_reset_player()
		_place(Vector3(0.0, 0.0, -5.0))
		combat.block_override = true
	if t == 60:
		_check(boss.st == MeleeEnemy.St.HOLD, "test setup: in guard (%s)" % boss.state_name())
		mark["n"] = boss.hit_log.size()
		mark["from"] = boss.global_position
		boss.force_pattern("lunge")
	if t == 63:
		_check(bool(boss.tells.back()["red"]) and boss.flash_on and boss.incoming() == 2, "the lunge: a red glint and the red flash")
		_check(combat.cues.has("glint_red"), "the unblockable tell sound")
		_check(combat.hud.telegraph_shown >= 1, "the HUD rings the unblockable tell")
	if t > 60 and not mark.has("done") and boss.hit_log.size() > int(mark["n"]):
		mark["done"] = true
		var travelled: float = WeaponMath.flat(boss.global_position, mark["from"])
		_check(String(boss.hit_log.back()["result"]) == "hit", "the lunge goes through the block (%s)" % String(boss.hit_log.back()["result"]))
		_check(travelled >= 2.5, "he dashes in from 5 m (%.1f m)" % travelled)
		_check(combat.hp < 100.0 and player.is_knocked_down(), "it hurts and knocks the player down (hp %.0f)" % combat.hp)
	if t == 220:
		_check(mark.has("done"), "the lunge resolved")
		combat.block_override = null
		_next("spin")


func _spin(t: int) -> void:
	if t == 1:
		_reset_player()
		_place(Vector3(0.0, 0.0, -2.6))
	if t == 40:
		mark["n"] = boss.hit_log.size()
		mark["yaw"] = boss.yaw
		boss.force_pattern("spin")
	if boss.st == MeleeEnemy.St.ATTACK:
		mark["spun"] = int(mark.get("spun", 0)) + 1
	if t > 40 and not mark.has("done") and boss.hit_log.size() > int(mark["n"]):
		mark["done"] = true
		_check(String(boss.hit_log.back()["result"]) == "hit" and bool(boss.tells.back()["red"]), "the spin reaches 2.6 m, red tell (%s)" % String(boss.hit_log.back()["result"]))
	if t == 200:
		_check(mark.has("done") and int(mark.get("spun", 0)) > 20, "the spin resolved")
		combat.god = false
		_next("lost")


func _lost(t: int) -> void:
	if t == 30:
		_reset_player()
		combat.receive_attack(boss, {"damage": 999.0})
	if t == 32:
		_check(duel.state == "lost" and lost_n == 1 and combat.is_down(), "the player at 0 HP: lost (%s)" % duel.state)
		_check(boss.st == MeleeEnemy.St.IDLE and not boss.is_hostile(), "he stands down (%s)" % boss.state_name())
		mark["old"] = boss
		player.teleport(Vector3(4.0, 0.0, 4.0), 1.0)
		duel.retry()
		_next("retry")


func _retry(t: int) -> void:
	if t == 2:
		boss = duel.boss
		var old: Variant = mark.get("old")
		_check(boss != null and is_instance_valid(boss) and boss != old, "retry(): a fresh Za Mẫn")
		_check(duel.state == "running" and duel.fight.state == "running" and duel.phase == 1, "the duel runs again, phase 1")
		_check(is_equal_approx(boss.hp, boss.max_hp) and boss.phase == 1 and boss.katana.stage == 0 and not boss.katana.broken, "full HP, a straight katana")
		_check(is_equal_approx(combat.hp, 100.0) and not combat.is_down(), "the player is back with full HP")
		_check(player.global_position.distance_to(Vector3.ZERO) < 0.1, "back at the start spot (%s)" % str(player.global_position))
		_check(duel.staff != null and is_instance_valid(duel.staff) and String(combat.light_moves[0]["id"]) == "slash1", "still the staff")
		_check(combat.boss == boss, "the boss bar follows the new boss")
		_next("phases")


func _hit_to(frac: float) -> String:
	var dmg: float = boss.hp - boss.max_hp * frac
	return boss.take_strike({"kind": "slash1", "dmg": dmg, "stagger": 0.0, "from": player.global_position})


func _phases(t: int) -> void:
	if t == 2:
		mark["speed"] = float(boss.stats["speed"])
		mark["dev0"] = boss.katana.tip_deviation()
		_check(boss.patterns() == SwordData.PHASES[0]["patterns"], "phase 1 patterns")
		_hit_to(0.7)
	if t == 3:
		_check(boss.katana.stage == 1 and boss.phase == 1 and phases_seen.is_empty(), "70 %: bend stage 1, still phase 1")
		_check(combat.hud.popup_text == SwordData.T_BEND[1] and combat.cues.has("katana_boing"), "the bend line and the boing")
	if t == 90:
		mark["dev1"] = boss.katana.tip_deviation()
		_check(is_equal_approx(boss.katana.bend, SwordData.BEND_RAD[1]), "the blade eased to stage 1 (%.2f)" % boss.katana.bend)
		_hit_to(0.65)
	if t == 91:
		_check(boss.phase == 2 and phases_seen == [2] and duel.phase == 2, "65 %%: phase 2 and the signal (%s)" % str(phases_seen))
		_check(is_equal_approx(float(boss.stats["speed"]), float(mark["speed"]) * 1.2) and boss.patterns().has("spin"), "phase 2: faster, the spin")
		_check(combat.hud.popup_text == SwordData.T_PHASE[2], "the phase line pops (%s)" % combat.hud.popup_text)
		_check(boss.st == MeleeEnemy.St.BLOCK and boss.pose.pose_name == "sw_kat_taunt", "he hops back into a taunt (%s)" % boss.state_name())
		_check(_hit_to(0.45) == "blocked" and boss.katana.stage == 1, "the taunt is guarded")
	if t == 150:
		_check(boss.st == MeleeEnemy.St.HOLD, "the taunt ends (%s)" % boss.state_name())
		_hit_to(0.45)
	if t == 151:
		_check(boss.katana.stage == 2, "45 %: bend stage 2")
	if t == 240:
		mark["dev2"] = boss.katana.tip_deviation()
		_hit_to(0.32)
	if t == 241:
		_check(boss.phase == 3 and phases_seen == [2, 3] and duel.phase == 3, "32 %%: phase 3 (%s)" % str(phases_seen))
		_check(is_equal_approx(float(boss.stats["speed"]), float(mark["speed"]) * 1.4) and boss.patterns().has("frenzy"), "phase 3: faster again, the frenzy")
	if t == 300:
		_hit_to(0.2)
	if t == 301:
		_check(boss.katana.stage == 3, "20 %: bend stage 3")
	if t == 400:
		mark["dev3"] = boss.katana.tip_deviation()
		var d: Array[float] = [float(mark["dev0"]), float(mark["dev1"]), float(mark["dev2"]), float(mark["dev3"])]
		print("  katana tip deviation by stage: %.2f %.2f %.2f %.2f rad" % d)
		_check(d[0] < 0.2 and d[1] > d[0] + 0.08 and d[2] > d[1] + 0.2 and d[3] > d[2] + 0.3, "the katana visibly bends more at every stage (%s)" % str(d))
		_next("break")


func _break(t: int) -> void:
	if t == 2:
		var r: String = _hit_to(0.0)
		_check(r == "ko", "the last hit: ko (%s)" % r)
		_check(boss.st == MeleeEnemy.St.FINALE and not boss.is_hostile() and not boss.is_defeated(), "the finale, not yet knocked out (%s)" % boss.state_name())
		_check(boss.katana.broken and boss.katana.piece != null and boss.katana.piece.top_level, "the katana snaps, the tip flies off")
		_check(combat.slowmo_active() and combat.cues.has("katana_snap"), "slow motion and the snap")
		_check(won_n == 0 and duel.state == "running", "no win before the finale ends")
		_check(boss.take_strike({"kind": "slash1", "dmg": 5.0, "from": player.global_position}) == "ignored", "no more hits during the finale")
		mark["piece_y0"] = boss.katana.piece.global_position.y
	if t == 40:
		_check(combat.hud.popup_text == SwordData.T_BREAK, "the comic line (%s)" % combat.hud.popup_text)
		_check(boss.pose.pose_name == "sw_kat_stare", "he stares at the stump")
	if not mark.has("ko") and boss.st == MeleeEnemy.St.KO:
		mark["ko"] = t
	if mark.has("ko") and t == int(mark["ko"]) + 2:
		_check(won_n == 1 and duel.state == "won", "the knockout after the finale wins the duel (%d)" % won_n)
		_check(combat.fx.cine.find_children("Star*", "", true, false).size() >= 3, "knockout stars")
		_check(is_equal_approx(Engine.time_scale, 1.0), "the time scale is back to 1")
		_check(boss.katana.piece.global_position.y < float(mark["piece_y0"]) and boss.katana.piece_resting, "the broken tip lies on the floor (y %.2f)" % boss.katana.piece.global_position.y)
		_next("stop")
	if t == 400:
		_check(false, "the finale never ended (%s, %s)" % [boss.state_name(), str(mark)])
		_next("stop")


func _stop(t: int) -> void:
	if t == 1:
		duel.stop()
		_check(combat.light_moves == CombatData.LIGHT and combat.controls_text == CombatData.T_CONTROLS and not combat.blade and combat.idle_pose == "", "stop(): the unarmed move set is back")
		_check(combat.boss == null and combat.enemies.is_empty() and not combat.fight_active and duel.state == "idle", "stop(): no boss, no fight")
	if t == 3:
		_check(player.model.find_child("PropGrip", true, false) == null and duel.staff == null, "stop(): the staff is gone")
		combat.light_override = true
	if t == 4:
		_check(combat.state == PlayerCombat.St.LIGHT and String(combat.move["id"]) == "jab", "after the duel LMB jabs again")
	if t == 40:
		duel.queue_free()
		duel = SwordDuel.new()
		duel.name = "Duel2"
		arena.add_child(duel)
		duel.setup({"player": player, "combat": combat, "boss": {"ai": false}})
		duel.start()
	if t == 42:
		_check(String(combat.light_moves[0]["id"]) == "slash1" and duel.boss != null, "a second duel arms the staff again")
		duel.queue_free()
	if t == 44:
		_check(combat.light_moves == CombatData.LIGHT and player.model.find_child("PropGrip", true, false) == null and combat.boss == null, "freeing a running duel restores the unarmed set")
		_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: SWORD DUEL (staff set + prop, 3-slash combo, thrust breaks guard, block, parry stagger, dodge i-frames, 0.5 s glint tells, lunge, spin, lost, retry, phases 66 / 33, katana bend stages, snap finale -> won, stop restores)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
