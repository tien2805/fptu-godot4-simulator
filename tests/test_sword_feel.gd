# File: res://tests/test_sword_feel.gd
# Headless test of the Q2 sword feel (plan 2026-10-29-q2-feel.md T5) on the SwordDuel (staff against Za Mẫn's katana):
#   - sparks on every clash: the staff on his guard, his slash on the player's block (Impact sparks + the clash sound);
#   - a parry: a heavy hit-stop (5 frozen frames), a camera punch and the clear "keng" over the parry ring;
#   - heavy thrusts push back: the staff thrust shoves him ~1 m even during his armoured swing (no interrupt).
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_sword_feel.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var arena: Node3D
var player: ThirdPersonController
var combat: PlayerCombat
var duel: SwordDuel
var boss: KatanaBoss


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  x ", msg)
	else:
		print("  ok ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST SWORD FEEL (Q2) ---")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _place(at: Vector3) -> void:
	boss.global_position = at
	boss.push_v = Vector3.ZERO
	boss.velocity = Vector3.ZERO
	var to: Vector3 = player.global_position - at
	boss.set_yaw(atan2(-to.x, -to.z))


func _run() -> void:
	await _frames(1)
	arena = Node3D.new()
	arena.name = "Arena"
	root.add_child(arena)
	World.floor_box(arena)
	player = World.player(arena, Vector3.ZERO, 0.0)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	arena.add_child(combat)
	combat.setup({"player": player})
	duel = SwordDuel.new()
	duel.name = "Duel"
	arena.add_child(duel)
	duel.setup({"player": player, "combat": combat, "at": Vector3(0.0, 0.0, -1.6), "seed": 3,
		"boss": {"ai": false, "stats": {"block_chance": 0.0, "dodge_chance": 0.0, "stagger_max": 9999.0}}})
	duel.start()
	boss = duel.boss
	await _frames(20)
	var clock: Impact = Impact.clock(combat)
	_check(combat.blade, "the staff move set is on")
	# ----- the staff on his guard -----
	boss.force_block(2.0)
	var fx0: int = clock.fx_log.size()
	var p0: int = clock.punches.size()
	combat.light_override = true
	await _frames(30)
	var r: Array[String] = combat.results_of("slash1")
	_check(not r.is_empty() and r.back() == "blocked", "the slash meets his guard (%s)" % str(r))
	_check(clock.fx_log.slice(fx0).has("sparks") and clock.punches.size() > p0 and combat.cues.has("blade_clash"), "a clash: sparks, a small punch, the clash sound")
	await _frames(90)
	# ----- his slash on the player's block -----
	_place(Vector3(0.0, 0.0, -1.6))
	combat.block_override = true
	await _frames(30)                            # held well before the hit: a plain block
	var fx1: int = clock.fx_log.size()
	var n: int = boss.hit_log.size()
	boss.force_pattern("slash_r")
	while boss.hit_log.size() == n:
		await physics_frame
	_check(String(boss.hit_log.back()["result"]) == "blocked" and clock.fx_log.slice(fx1).has("sparks"), "his slash on the block: sparks (%s)" % String(boss.hit_log.back()["result"]))
	combat.block_override = false
	await _frames(120)
	# ----- a parry -----
	_place(Vector3(0.0, 0.0, -1.6))
	combat.revive()
	combat.block_override = false
	await _frames(30)
	n = boss.hit_log.size()
	boss.force_pattern("slash_r")
	while not (boss.st == MeleeEnemy.St.ATTACK and boss.st_t >= 0.04):
		await physics_frame
	combat.block_override = true                 # ~0.1 s before his hit
	var pu0: int = clock.punches.size()
	var hs0: int = clock.hitstop_count
	while boss.hit_log.size() == n:
		await physics_frame
	var low: int = 0
	for i: int in 12:
		await physics_frame
		if Engine.time_scale < 0.5:
			low += 1
	_check(String(boss.hit_log.back()["result"]) == "perfect" and boss.parries == 1, "a perfect block: the parry (%s)" % String(boss.hit_log.back()["result"]))
	_check(clock.hitstop_count > hs0 and low >= 4, "the parry freezes (%d frames)" % low)
	var big: bool = false
	for k: int in range(pu0, clock.punches.size()):
		big = big or clock.punches[k] >= 0.35
	_check(big, "a camera punch on the parry (%s)" % str(clock.punches.slice(pu0)))
	_check(clock.cue_log.has("keng") and combat.cues.has("parry_ring"), "the clear 'keng' over the parry ring")
	combat.block_override = false
	await _frames(150)
	# ----- the thrust pushes him back through his armour -----
	_place(Vector3(0.0, 0.0, -1.7))
	combat.revive()
	await _frames(20)
	boss.force_pattern("slash_r")
	while boss.st != MeleeEnemy.St.WINDUP:
		await physics_frame
	var z0: float = boss.global_position.z
	combat.heavy_override = true
	var pushed: bool = false
	for i2: int in 40:
		await physics_frame
		pushed = pushed or not combat.results_of("thrust").is_empty()
	var moved: float = z0 - boss.global_position.z
	var tr: Array[String] = combat.results_of("thrust")
	_check(pushed and not tr.is_empty() and tr.back() == "hit", "the thrust lands on his armoured wind-up (%s)" % str(tr))
	_check(moved > 0.6, "... and shoves him back (%.2f m)" % moved)
	duel.stop()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	RadialWheel.scale_owner = null
	if arena and is_instance_valid(arena):
		arena.free()
	if fails.is_empty():
		print("SUCCESS: SWORD FEEL (clash sparks both ways, parry freeze + punch + keng, thrust push-back)")
		quit(0)
	else:
		print("FAILED: %d issues" % fails.size())
		quit(1)
