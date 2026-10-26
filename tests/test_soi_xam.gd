# File: res://tests/test_soi_xam.gd
# Headless test of Sói Xám, the Phase C unarmed mini-boss (spec 2026-10-26-story-phase-c-days-2-3-5-design.md, C-D4 Day 2,
# C-D13): the MeleeEnemy archetype "soi_xam" through a MeleeFight in an arena with a PlayerCombat:
#   archetype data (fast 4-hit chain, light tell 0.38 s, glow, howl at 50 %, boss); two LED eyes on his head, dim; the boss
#   bar (combat.boss, a tick at 50 %); a forced combo lands 4 hits fast, every one told by the LED eyes lit >= 0.35 s
#   before the impact and dark right after; a heavy is told by eyes + red flash; under 50 % HP he howls once (state HOWL,
#   the howl cue and line, armoured: hits hurt without interrupting) and comes out faster and harder hitting; 0 HP through
#   the MeleeFight -> won; stop() clears the boss bar; AI on: his chains reach 3+ hits and every hit is glow-told.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_soi_xam.gd
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
var fight: MeleeFight
var e: MeleeEnemy
var mark: Dictionary = {}
var won_n: int = 0
var base: Dictionary = {}


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
	WeaponAudio.sfx_dir = "user://__no_owner_sfx__/"
	print("--- TEST SÓI XÁM ---")
	_data_checks()
	physics_frame.connect(_on_physics)


func _data_checks() -> void:
	_check(CombatData.ARCHETYPES.has("soi_xam"), "archetype soi_xam exists")
	base = CombatData.archetype("soi_xam")
	_check(int(base["chain"]) >= 4 and float(base["speed"]) > float(CombatData.ARCHETYPES["dolly"]["speed"]), "fast combos: a 4-hit chain, faster than Dolly")
	var lead: float = float(base["windup"]) + float(CombatData.ENEMY_LIGHT["hit"])
	_check(lead >= 0.35 and lead <= 0.45, "light tell %.2f s (0.35-0.45)" % lead)
	_check(bool(base["glow"]) and is_equal_approx(float(base["howl_at"]), 0.5) and bool(base["boss"]) and not bool(base["finisher_ko"]), "glow, howl at 50 %, boss, the finisher does not knock him out")
	_check((base["howl"] as Dictionary).has("speed") and float(base["howl"]["light_dmg"]) > 1.0, "the howl buffs speed and damage")
	_check(String(base["howl_line"]) != "" and _plain(String(base["howl_line"])), "plain howl line")
	_check(CombatData.pose("howl", 0.25).has("head"), "the howl pose")


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


func _new_fight(ai: bool, at: Vector3) -> void:
	fight = MeleeFight.new()
	fight.name = "SoiFight"
	arena.add_child(fight)
	fight.setup({"player": player, "combat": combat, "force_unarmed": false, "seed": 2})
	fight.add_wave([{"archetype": "soi_xam", "at": at, "opts": {"ai": ai, "label": "Sói Xám", "stats": {"block_chance": 0.0, "dodge_chance": 0.0}}}])
	fight.won.connect(func() -> void: won_n += 1)
	fight.start()
	e = fight.enemies[0]


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
		_new_fight(false, Vector3(0.0, 0.0, -1.3))
		_next("spawn")
		return
	var t: int = frames - t0
	if frames == 6000:
		_check(false, "watchdog: stuck in phase %s (%s)" % [phase, str(mark)])
		_finish()
		return
	match phase:
		"spawn":
			_spawn(t)
		"combo":
			_combo(t)
		"heavy":
			_heavy(t)
		"howl":
			_howl(t)
		"ko":
			_ko(t)
		"ai":
			_ai(t)


func _spawn(t: int) -> void:
	if t == 20:
		_check(e.archetype_id == "soi_xam" and e.label == "Sói Xám", "Sói Xám spawns through the MeleeFight")
		_check(e.glow_nodes.size() == 2 and e.glow_nodes[0].is_inside_tree() and e.glow_nodes[0].name.begins_with("LedEye"), "two LED eyes on his head")
		var eye_y: float = e.glow_nodes[0].global_position.y - e.global_position.y
		_check(eye_y > 1.3 and eye_y < 2.0, "the eyes sit at head height (%.2f m)" % eye_y)
		_check(not e.glow_on and is_equal_approx((e.glow_nodes[0].material_override as StandardMaterial3D).emission_energy_multiplier, MeleeEnemy.GLOW_OFF_ENERGY), "the eyes are dim at rest")
		_check(combat.boss == e and combat.hud.boss_shown and e.boss_marks().size() == 1 and is_equal_approx(e.boss_marks()[0], 0.5), "the boss bar, with a tick at 50 %")
		combat.block_override = true
		_next("combo")


## A forced combo against a held block: 4 hits (the chain goes on on a block), each told by the eyes.
func _combo(t: int) -> void:
	if t == 30:
		mark["n"] = e.results.size()
		mark["leads"] = []
		e.force_attack("combo")
	if t == 31:
		_check(e.glow_on and is_equal_approx((e.glow_nodes[0].material_override as StandardMaterial3D).emission_energy_multiplier, MeleeEnemy.GLOW_ON_ENERGY) and e.glow_nodes[0].scale.x > 1.2, "the wind-up lights the LED eyes")
	if t > 30 and e.results.size() > int(mark["n"]) + (mark["leads"] as Array).size():
		(mark["leads"] as Array).append(e._t - e.glow_t)
		_check(not e.glow_on or e.st == MeleeEnemy.St.WINDUP, "the eyes go dark at the impact")
		if (mark["leads"] as Array).size() == 1:
			mark["first"] = t
		mark["last"] = t
	if t == 200:
		var leads: Array = mark["leads"]
		var res: Array[String] = e.results.slice(int(mark["n"]))
		_check(res.size() == 4 and res.count("blocked") == 4, "a 4-hit combo (%s)" % str(res))
		var ok: bool = true
		for l: Variant in leads:
			ok = ok and float(l) >= 0.35 and float(l) <= 0.47
		_check(ok, "every hit told by the eyes 0.35-0.47 s ahead (%s)" % str(leads))
		if mark.has("first"):
			_check(int(mark["last"]) - int(mark["first"]) <= 100, "fast: 4 hits within 1.65 s (%d frames)" % (int(mark["last"]) - int(mark["first"])))
		_next("heavy")


func _heavy(t: int) -> void:
	if t == 20:
		mark["n"] = e.results.size()
		e.force_attack("heavy")
	if t == 30:
		_check(e.st == MeleeEnemy.St.TELEGRAPH and e.glow_on and e.flash_on, "a heavy: eyes lit and the red flash")
	if t > 20 and not mark.has("done") and e.results.size() > int(mark["n"]):
		mark["done"] = true
		_check(e._t - e.glow_t >= 0.6 and e.results.back() == "hit", "the heavy is told 0.7 s ahead and goes through the block (%s)" % e.results.back())
	if t == 150:
		combat.block_override = null
		combat.revive()
		player.teleport(Vector3.ZERO, 0.0)
		_next("howl")


func _howl(t: int) -> void:
	if t == 30:
		_check(e.st == MeleeEnemy.St.HOLD, "test setup: in guard (%s)" % e.state_name())
		mark["speed"] = float(e.stats["speed"])
		mark["dmg"] = float(e.stats["light_dmg"])
		mark["windup"] = float(e.stats["windup"])
		mark["chain"] = int(e.stats["chain"])
		var r0: String = e.take_strike({"dmg": e.hp - e.max_hp * 0.55, "stagger": 0.0, "from": player.global_position})
		_check(r0 == "hit" and e.howls == 0, "55 %%: no howl yet (%s)" % r0)
	if t == 60:
		var r: String = e.take_strike({"dmg": e.max_hp * 0.07, "stagger": 0.0, "from": player.global_position})
		_check(r == "howl" and e.st == MeleeEnemy.St.HOWL and e.howls == 1, "under 50 %%: he howls (%s, %s)" % [r, e.state_name()])
		_check(combat.cues.has("howl") and combat.hud.popup_text == String(base["howl_line"]), "the howl sound and line (%s)" % combat.hud.popup_text)
		_check(e.glow_on and e.pose.pose_name == "howl", "eyes blazing, head thrown back")
		_check(is_equal_approx(float(e.stats["speed"]), float(mark["speed"]) * 1.25) and is_equal_approx(float(e.stats["light_dmg"]), float(mark["dmg"]) * 1.3), "faster and harder hitting after the howl")
		_check(float(e.stats["windup"]) < float(mark["windup"]) and int(e.stats["chain"]) == int(mark["chain"]) + 1, "quicker wind-up, a longer chain")
		mark["h0"] = e.hp
	if t == 75:
		var r2: String = e.take_strike({"dmg": 5.0, "stagger": 50.0, "from": player.global_position})
		_check(r2 == "hit" and e.st == MeleeEnemy.St.HOWL and e.hp < float(mark["h0"]), "the howl is armoured: hurt, not interrupted (%s, %s)" % [r2, e.state_name()])
	if t == 60 + 90:
		_check(e.st == MeleeEnemy.St.HOLD and not e.glow_on, "the howl ends after 1.4 s (%s)" % e.state_name())
		var r3: String = e.take_strike({"dmg": 10.0, "stagger": 0.0, "from": player.global_position})
		_check(r3 == "hit" and e.howls == 1, "he howls only once (%s)" % r3)
		_next("ko")


func _ko(t: int) -> void:
	if t == 30:
		var r: String = e.take_strike({"dmg": 9999.0, "stagger": 0.0, "from": player.global_position})
		_check(r == "ko" and e.is_defeated(), "0 HP: knocked out (%s)" % r)
	if t == 33:
		_check(won_n == 1 and fight.state == "won", "his knockout wins the MeleeFight")
		fight.stop()
		_check(combat.boss == null and combat.enemies.is_empty(), "stop() clears the boss bar")
		fight.queue_free()
	if t == 40:
		player.teleport(Vector3.ZERO, 0.0)
		combat.revive()
		combat.god = true
		combat.block_override = true
		won_n = 0
		_new_fight(true, Vector3(0.0, 0.0, -5.0))
		_next("ai")


## AI on for 10 s against a blocking player (god mode): chains of 3+ hits, every hit glow-told.
func _ai(t: int) -> void:
	if t == 1:
		mark["times"] = []
		mark["bad"] = []
		mark["n"] = 0
	if e.results.size() > int(mark["n"]):
		mark["n"] = e.results.size()
		(mark["times"] as Array).append(t)
		var lead: float = e._t - e.glow_t
		if lead < 0.34:
			(mark["bad"] as Array).append(lead)
	if t == 600:
		var times: Array = mark["times"]
		var best: int = 0
		var run: int = 0
		for i: int in times.size():
			run = run + 1 if i > 0 and int(times[i]) - int(times[i - 1]) <= 36 else 1
			best = maxi(best, run)
		print("  AI Sói Xám: %d attacks in 10 s, longest chain %d" % [times.size(), best])
		_check(times.size() >= 6, "AI on: he keeps attacking (%d)" % times.size())
		_check(best >= 3, "his combos chain 3+ hits (longest %d)" % best)
		_check((mark["bad"] as Array).is_empty(), "every AI hit is told by the eyes (bad leads %s)" % str(mark["bad"]))
		fight.stop()
		_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: SÓI XÁM (archetype, LED eyes, boss bar, 4-hit combo told by the glow, heavy, howl at 50 % armoured + buff once, KO -> won, AI chains)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
