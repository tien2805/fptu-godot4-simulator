# File: res://tests/test_melee_combat.gd
# Headless test of the Phase B unarmed Vovinam combat (spec 2026-10-25-story-phase-b-days-1-4-design.md, B-D1 / B-D2,
# B-D12 test_melee_combat):
#   A (arena, PlayerCombat without weapons) light combo jab -> cross -> elbow and its reset after 0.5 s; a block stops a
#     light hit and the heavy kick breaks it (a second heavy knocks the staggered enemy down); a normal block (no damage, no
#     counter) and a perfect block ("PHẢN ĐÒN" counter-strike); Space near a hostile dodge-rolls (no jump, invulnerable for
#     0.35 s, an enemy hit is dodged) and jumps when nobody is within 6 m; the stagger meter dazes for 2.5 s, "[E] Hạ gục"
#     shows, the finisher knocks out with 0.3 s of slow motion and the time scale comes back to 1.0; a telegraph flashes red
#     for 0.5 s and its heavy goes through the block (damage, knocked down); a MeleeFight of 5 clones never has more than 2
#     attackers; the player at 0 HP -> `lost` (enemies stand down); retry() from the wave-2 checkpoint.
#   B (arena with a WeaponDirector) the director's punch and right-mouse aim are off while unarmed (owned by the combat), the
#     pistol still aims; the unarmed combo stumbles, stumbles and knocks out a pedestrian (+1 heat), the heavy kick knocks
#     one out; force unarmed equips Tay không, locks the wheel and scroll and shows "Nhiệm vụ này chỉ dùng tay không";
#     Dolly flees at 30 % HP and her fleeing wins the fight.
#   C (FreeRoam with the crowd) the combat is wired (WeaponDirector owner, jump filter, hidden HUD); the unarmed combo knocks
#     out a real pedestrian (+1 heat); a MeleeFight built from the roam shows the HUD, its start line and locks the wheel.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_melee_combat.gd
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
var sibs: Array = []
var people: Array = []
var e: MeleeEnemy
var e2: MeleeEnemy
var mark: Dictionary = {}
var fight: MeleeFight
var lost_n: int = 0
var won_n: int = 0
var fled_n: int = 0
var countered_n: int = 0
var max_att: int = 0
var dir: WeaponDirector
var heat: Array[float] = []
var ped: Pedestrian
var roam: Node3D


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
	print("--- TEST MELEE COMBAT ---")
	_data_checks()
	physics_frame.connect(_on_physics)


func _data_checks() -> void:
	_check(CombatData.LIGHT.size() == 3 and String(CombatData.LIGHT[0]["id"]) == "jab" and String(CombatData.LIGHT[1]["id"]) == "cross" and String(CombatData.LIGHT[2]["id"]) == "elbow", "light combo is jab, cross, elbow")
	_check(bool(CombatData.HEAVY["breaks_block"]), "the heavy kick breaks blocks")
	_check(is_equal_approx(CombatData.PERFECT_BLOCK_S, 0.2) and is_equal_approx(CombatData.DODGE_IFRAMES, 0.35) and is_equal_approx(CombatData.DODGE_HOSTILE_M, 6.0), "perfect block 0.2 s, dodge 0.35 s invulnerable, 6 m")
	_check(is_equal_approx(CombatData.DAZE_S, 2.5) and is_equal_approx(CombatData.TELEGRAPH_S, 0.5) and is_equal_approx(CombatData.SLOWMO_REAL_S, 0.3), "daze 2.5 s, telegraph 0.5 s, finisher slow motion 0.3 s")
	_check(is_equal_approx(CombatData.PLAYER_HP, 100.0) and is_equal_approx(CombatData.REGEN_DELAY, 4.0), "player HP 100, regeneration after 4 s")
	for a: String in ["courier", "clone", "dolly"]:
		_check(CombatData.ARCHETYPES.has(a), "archetype %s exists" % a)
	_check(is_equal_approx(float(CombatData.ARCHETYPES["dolly"]["flee_at"]), 0.3), "Dolly flees at 30 %")
	for s: String in [CombatData.T_HP, CombatData.T_COUNTER, CombatData.T_FINISHER_PROMPT, CombatData.T_FINISHED, CombatData.T_GUARD_BREAK, CombatData.T_UNARMED_ONLY, CombatData.T_CONTROLS]:
		_check(_plain(s), "plain text without emoji or decorative symbols: '%s'" % s)
	_check(CombatData.T_UNARMED_ONLY == "Nhiệm vụ này chỉ dùng tay không" and CombatData.T_COUNTER == "PHẢN ĐÒN" and CombatData.T_FINISHER_PROMPT == "[E] Hạ gục", "the spec's texts")


## Letters (any script), digits, spaces, basic punctuation and the [ ] of a key glyph only.
static func _plain(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c > 0x2000 or (c < 0x80 and not (char(c) in " ,.:-[]0123456789") and not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122))):
			return false
	return true


func _next(p: String) -> void:
	phase = p
	t0 = frames
	mark.clear()


func _enemy(arch: String, at: Vector3, stats: Dictionary = {}) -> MeleeEnemy:
	var st: Dictionary = {"block_chance": 0.0, "dodge_chance": 0.0}
	for k: String in stats.keys():
		st[k] = stats[k]
	var n := MeleeEnemy.new()
	n.name = "Test%s%d" % [arch, sibs.size()]
	n.setup(arch, {"stats": st, "seed": 7 + sibs.size(), "ai": false, "label": "Thử"})
	n.top_level = true
	n.position = at
	arena.add_child(n)
	var to: Vector3 = player.global_position - at
	n.set_yaw(atan2(-to.x, -to.z))
	n.bind(combat, null, sibs, combat.fx)
	sibs.append(n)
	combat.add_enemy(n)
	return n


func _drop(n: MeleeEnemy) -> void:
	if n and is_instance_valid(n):
		combat.remove_enemy(n)
		sibs.erase(n)
		n.queue_free()


func _place(n: MeleeEnemy, at: Vector3) -> void:
	n.global_position = at
	n.push_v = Vector3.ZERO
	n.velocity = Vector3.ZERO
	var to: Vector3 = player.global_position - at
	n.set_yaw(atan2(-to.x, -to.z))


func _reset_player(at: Vector3 = Vector3.ZERO) -> void:
	player.teleport(at, 0.0)
	player.pitch = 0.0
	combat.revive()
	combat.block_override = null


## The hand of side s ("L" / "R") is above its shoulder (guard up; hanging arms put it ~0.5 m below). Bone poses from the
## local poses (CharacterBuilder._bone_global_now): what the AnimationPlayer + RigAnimator + CombatPose wrote last frame.
static func _arm_raised(body: Node3D, s: String) -> bool:
	var sk: Skeleton3D = body.get_meta("skeleton", null) as Skeleton3D
	if sk == null:
		return false
	var up: int = sk.find_bone("UpperArm." + s)
	var wr: int = sk.find_bone("Wrist." + s)
	return (CharacterBuilder._bone_global_now(sk, wr).origin - CharacterBuilder._bone_global_now(sk, up).origin).y > 0.05


func _kinds(kinds: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in combat.strikes:
		if kinds.has(String(s["kind"])):
			out.append(s)
	return out


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
		combat.setup({"player": player, "targets_fn": func() -> Array: return people})
		combat.countered.connect(func(_x: Node3D) -> void: countered_n += 1)
		_check(player.jump_filter.is_valid(), "the combat installs the player's jump filter")
		_check(combat.hud != null and not combat.hud.visible, "the combat HUD is hidden at full HP outside a fight")
		e = _enemy("clone", Vector3(0.0, 0.0, -1.3), {"hp": 300.0, "stagger_max": 999.0})
		_next("combo")
		return
	var t: int = frames - t0
	match phase:
		"combo":
			_combo(t)
		"block_break":
			_block_break(t)
		"block":
			_block(t)
		"dodge":
			_dodge(t)
		"daze":
			_daze(t)
		"telegraph":
			_telegraph(t)
		"cap":
			_cap(t)
		"down":
			_down(t)
		"retry":
			_retry(t)
		"b":
			_part_b(t)
		"c":
			_part_c(t)


# ---------------------------------------------------------------------------
# A: arena
# ---------------------------------------------------------------------------
func _combo(t: int) -> void:
	if t == 5 or t == 23 or t == 43 or t == 115:
		combat.light_override = true
	if t == 6:
		_check(combat.state == PlayerCombat.St.LIGHT and combat.combo_i == 0, "left mouse starts the jab")
		var ap: AnimationPlayer = CharacterBuilder.get_animator(player.model).get("player")
		var want: float = (0.57 - 0.25) / 0.18
		_check(ap.current_animation == "Punch_Left" and absf(ap.speed_scale - want) < 0.05, "the jab plays Punch_Left fitted to its impact (%s x%.2f)" % [ap.current_animation, ap.speed_scale])
	if t == 75:
		var k: Array[Dictionary] = _kinds(["jab", "cross", "elbow"])
		var names: Array[String] = []
		var res: Array[String] = []
		for s: Dictionary in k:
			names.append(String(s["kind"]))
			res.append(String(s["result"]))
		_check(names == ["jab", "cross", "elbow"], "three presses: jab, cross, elbow (%s)" % str(names))
		_check(res == ["hit", "hit", "hit"], "each lands (%s)" % str(res))
		_check(is_equal_approx(e.hp, 300.0 - 32.0), "8 + 10 + 14 damage (hp %.1f)" % e.hp)
		_check(e.stagger > 0.0, "the stagger meter fills (%.1f)" % e.stagger)
	if t == 135:
		var k2: Array[Dictionary] = _kinds(["jab", "cross", "elbow"])
		_check(k2.size() == 4 and String(k2[3]["kind"]) == "jab", "after the elbow and a pause the combo starts again at the jab")
		_next("block_break")


func _block_break(t: int) -> void:
	if t == 1:
		_reset_player()
		_place(e, Vector3(0.0, 0.0, -1.3))
		e.hp = 300.0
		e.stagger = 0.0
	if t == 40:
		_check(e.st == MeleeEnemy.St.HOLD, "test setup: the enemy stands in guard (%s)" % e.state_name())
		e.force_block(2.0)
		mark["hp"] = e.hp
	if t == 42:
		combat.light_override = true
	if t == 50:
		_check(_arm_raised(e.body, "L"), "the enemy's block pose raises its forearms (CombatPose over the rig)")
	if t == 65:
		var last: Dictionary = combat.strikes.back()
		_check(String(last["result"]) == "blocked" and is_equal_approx(e.hp, float(mark["hp"])), "a block stops the light hit (%s, hp %.1f)" % [str(last["result"]), e.hp])
		combat.heavy_override = true
	if t == 66:
		_check(combat.state == PlayerCombat.St.HEAVY, "right mouse starts the heavy kick")
	if t == 95:
		var last2: Dictionary = combat.strikes.back()
		_check(String(last2["kind"]) == "heavy" and String(last2["result"]) == "guard_break", "the heavy kick breaks the block (%s)" % str(last2))
		_check(e.st == MeleeEnemy.St.STAGGER and is_equal_approx(e.hp, float(mark["hp"]) - 9.0), "guard broken: staggered, half damage (%s, hp %.1f)" % [e.state_name(), e.hp])
		combat.heavy_override = true
	if t == 125:
		var last3: Dictionary = combat.strikes.back()
		_check(String(last3["result"]) == "knockdown" and e.st == MeleeEnemy.St.KNOCKDOWN, "a heavy kick on a staggered enemy knocks it down (%s)" % str(last3))
	if t > 125 and e.st == MeleeEnemy.St.HOLD:
		_check(t < 125 + 140, "the enemy gets up after 1.2 + 0.9 s")
		_next("block")
	elif t == 300:
		_check(false, "the knocked-down enemy never got up (%s)" % e.state_name())
		_next("block")


func _block(t: int) -> void:
	if t == 1:
		_reset_player()
		_place(e, Vector3(0.0, 0.0, -1.2))
		combat.block_override = true
		mark["popups"] = combat.hud.popups
	if t == 19:
		_check(combat.blocking and combat.pose.pose_name == "block" and _arm_raised(player.model, "L") and _arm_raised(player.model, "R"), "hold Q: the player's guard comes up")
	if t == 20:
		e.force_attack("light")
		mark["n"] = e.results.size()
	if t == 80:
		_check(e.results.size() == int(mark["n"]) + 1 and e.results.back() == "blocked", "a held block stops the enemy's light hit (%s)" % str(e.results))
		_check(is_equal_approx(combat.hp, 100.0) and combat.state != PlayerCombat.St.COUNTER and combat.hud.popups == int(mark["popups"]), "no damage, no counter for a block held early")
		combat.block_override = false
	if t >= 100 and not mark.has("forced") and e.st == MeleeEnemy.St.HOLD:
		mark["forced"] = true
		mark["n2"] = e.results.size()
		mark["hp2"] = e.hp
		e.force_attack("light")
	if mark.has("forced") and not mark.has("pressed") and e.st == MeleeEnemy.St.ATTACK and e.st_t >= 0.04:
		mark["pressed"] = true
		combat.block_override = true             # ~0.13 s before the impact
	if mark.has("pressed") and not mark.has("done") and e.results.size() > int(mark["n2"]):
		mark["done"] = true
		_check(e.results.back() == "perfect", "pressed within 0.2 s of the hit: perfect block (%s)" % e.results.back())
		_check(combat.hud.popup_text == CombatData.T_COUNTER and countered_n == 1, "the 'PHẢN ĐÒN' counter-strike pops (%s)" % combat.hud.popup_text)
		_check(e.st == MeleeEnemy.St.STAGGER and is_equal_approx(e.hp, float(mark["hp2"]) - 12.0), "the counter staggers the attacker (%s, hp %.1f)" % [e.state_name(), e.hp])
		_check(is_equal_approx(combat.hp, 100.0), "no damage on a perfect block")
		combat.block_override = null
		_next("dodge")
	if t == 400:
		_check(false, "the perfect-block test never resolved")
		_next("dodge")


func _dodge(t: int) -> void:
	if t == 1:
		_reset_player()
		_place(e, Vector3(0.0, 0.0, -2.0))
	if t == 30:
		player.jump_override = true
	if t == 31:
		_check(combat.state == PlayerCombat.St.DODGE and player.move_state == "LAND_ROLL", "Space with a hostile 2 m away dodge-rolls (%s)" % player.move_state)
		_check(player.velocity.y <= 0.01 and combat.invuln_left > 0.3, "no jump, invulnerable")
		_check(combat.receive_attack(e, {"damage": 10.0}) == "dodged" and is_equal_approx(combat.hp, 100.0), "an enemy hit during the roll is dodged")
	if t == 54:
		_check(combat.state == PlayerCombat.St.DODGE and combat.invuln_left <= 0.0, "invulnerability ends at 0.35 s, before the roll does")
		_check(combat.receive_attack(e, {"damage": 10.0}) == "hit" and is_equal_approx(combat.hp, 90.0), "a hit after 0.35 s lands (%.1f)" % combat.hp)
	if t == 90:
		_place(e, Vector3(0.0, 0.0, -12.0))
	if t == 95:
		_check(player.move_state == "GROUND", "test setup: back on the ground")
		player.jump_override = true
	if t == 96:
		_check(player.move_state == "JUMP" and combat.state != PlayerCombat.St.DODGE, "no hostile within 6 m: Space jumps (%s)" % player.move_state)
	if t == 150:
		_reset_player()
		_place(e, Vector3(0.0, 0.0, -1.2))
	if t == 160:
		e.force_attack("light")
		mark["n"] = e.results.size()
	if t > 160 and not mark.has("rolled") and e.st == MeleeEnemy.St.ATTACK and e.st_t >= 0.08:
		mark["rolled"] = true
		player.jump_override = true
	if mark.has("rolled") and not mark.has("done") and e.results.size() > int(mark["n"]):
		mark["done"] = true
		var r: String = e.results.back()
		_check((r == "dodged" or r == "miss") and is_equal_approx(combat.hp, 100.0), "a roll just before an enemy's hit avoids it (%s, hp %.1f)" % [r, combat.hp])
	if t == 260:
		_check(mark.has("done"), "the rolled-through attack resolved")
		_drop(e)
		_reset_player()
		combat.fight_active = true
		e2 = _enemy("clone", Vector3(0.0, 0.0, -1.3))
		_next("daze")


func _daze(t: int) -> void:
	if t == 5 or t == 23 or t == 43:
		combat.light_override = true
	if t == 75:
		var k: Array[Dictionary] = _kinds(["elbow"])
		_check(not k.is_empty() and String(k.back()["result"]) == "daze", "jab + cross + elbow fill a clone's stagger meter: dazed (%s)" % (str(k.back()) if not k.is_empty() else "none"))
		_check(e2.st == MeleeEnemy.St.DAZE and e2.is_dazed(), "the enemy is dazed (%s)" % e2.state_name())
		mark["d0"] = t
	if mark.has("d0") and not mark.has("d1") and e2.st != MeleeEnemy.St.DAZE:
		mark["d1"] = t
		var n: int = t - int(mark["d0"])
		_check(n >= 130 and n <= 152, "the daze lasts 2.5 s (%d frames after the check, daze began ~18 frames earlier)" % n)
		e2.stagger = e2.stagger_max - 1.0
		_place(e2, Vector3(0.0, 0.0, -1.3))
		_reset_player()
		combat.fight_active = true
		combat.light_override = true
	if mark.has("d1") and not mark.has("d2") and e2.st == MeleeEnemy.St.DAZE:
		mark["d2"] = t
	if mark.has("d2") and t == int(mark["d2"]) + 3:
		_check(combat.finisher_target() == e2 and combat.hud.visible and combat.hud.finisher_shown, "'[E] Hạ gục' shows over the dazed enemy in reach")
		combat.finisher_override = true
	if mark.has("d2") and t == int(mark["d2"]) + 4:
		_check(combat.state == PlayerCombat.St.FINISHER and e2.st == MeleeEnemy.St.HELD, "E starts the takedown finisher (%s)" % e2.state_name())
	if mark.has("d2") and not mark.has("ko") and e2.st == MeleeEnemy.St.KO:
		mark["ko"] = t
		_check(combat.slowmo_active() and is_equal_approx(Engine.time_scale, CombatData.SLOWMO_SCALE), "slow motion at the finisher's impact (time scale %.2f)" % Engine.time_scale)
		_check(is_equal_approx(e2.hp, 0.0) and combat.hud.popup_text == CombatData.T_FINISHED, "the finisher knocks out ('%s')" % combat.hud.popup_text)
	if mark.has("ko") and not mark.has("slow_end") and is_equal_approx(Engine.time_scale, 1.0):
		mark["slow_end"] = t
		var n2: int = t - int(mark["ko"])
		_check(n2 >= 15 and n2 <= 21, "the slow motion lasts 0.3 real seconds (%d physics frames)" % n2)
	if mark.has("slow_end") and t == int(mark["slow_end"]) + 60:
		_check(combat.state == PlayerCombat.St.IDLE, "the finisher ends")
		combat._slowmo()
		combat.notification(Node.NOTIFICATION_PAUSED)
		_check(is_equal_approx(Engine.time_scale, 1.0) and RadialWheel.scale_owner == null, "a pause (cinematic) ends the slow motion at once")
		_drop(e2)
		_reset_player()
		e = _enemy("courier", Vector3(0.0, 0.0, -1.2))
		combat.block_override = true
		_next("telegraph")
	if t == 900:
		_check(false, "the daze / finisher test never finished (%s)" % str(mark))
		Engine.time_scale = 1.0
		_next("telegraph")


func _telegraph(t: int) -> void:
	if t == 20:
		e.force_attack("heavy")
	if e.st == MeleeEnemy.St.TELEGRAPH:
		if not mark.has("tg0"):
			mark["tg0"] = t
		if t == int(mark["tg0"]) + 10:
			var lit: bool = e.flash_on
			for mi: Node in e.body.find_children("*", "MeshInstance3D", true, false):
				lit = lit and (mi as MeshInstance3D).material_overlay != null
			_check(lit, "the telegraph flashes the enemy red")
			_check(combat.hud.telegraph_shown >= 1, "the HUD marks the telegraph")
	if mark.has("tg0") and not mark.has("tg1") and e.st == MeleeEnemy.St.ATTACK:
		mark["tg1"] = t
		var n: int = t - int(mark["tg0"])
		_check(n >= 29 and n <= 31, "the telegraph lasts 0.5 s (%d frames)" % n)
		mark["n"] = e.results.size()
	if mark.has("tg1") and not mark.has("hit") and e.results.size() > int(mark["n"]):
		mark["hit"] = t
		_check(e.results.back() == "hit", "the telegraphed heavy goes through the block (%s)" % e.results.back())
		_check(is_equal_approx(combat.hp, 100.0 - 20.0), "heavy damage (%.1f)" % combat.hp)
		_check(player.is_knocked_down() and not e.flash_on, "the heavy knocks the player down; the flash is over")
	if mark.has("hit") and t == int(mark["hit"]) + 10:
		combat.block_override = null
		_drop(e)
		_reset_player()
		combat.god = true
		fight = MeleeFight.new()
		fight.name = "Fight"
		arena.add_child(fight)
		fight.setup({"player": player, "combat": combat, "force_unarmed": false, "seed": 3})
		var w: Array = []
		for i: int in 5:
			var a: float = TAU * float(i) / 5.0
			w.append({"archetype": "clone", "at": Vector3(sin(a), 0.0, cos(a)) * 5.0})
		fight.add_wave(w)
		fight.lost.connect(func() -> void: lost_n += 1)
		fight.start()
		_next("cap")
	if t == 300:
		_check(false, "the telegraph test never finished")
		_next("cap")


func _cap(t: int) -> void:
	max_att = maxi(max_att, fight.attackers())
	if t == 600:
		var total: int = 0
		for n: Variant in fight.enemies:
			total += (n as MeleeEnemy).attacks
		_check(max_att <= 2, "at most 2 of 5 enemies attack at once (max %d)" % max_att)
		_check(max_att == 2, "two attackers do happen together (max %d)" % max_att)
		_check(total >= 4, "the clones keep attacking (%d attacks in 10 s)" % total)
		_check(fight.state == "running" and fight.enemies.size() == 5 and combat.hud.visible, "the fight runs with its HUD")
		combat.god = false
		combat.hp = 5.0
		combat.since_damage = 0.0
		_next("down")


func _down(t: int) -> void:
	if fight.state == "lost" and not mark.has("lost"):
		mark["lost"] = t
		_check(lost_n == 1 and combat.is_down(), "the player at 0 HP is down and the fight is lost")
	if mark.has("lost") and t == int(mark["lost"]) + 30:
		var idle: bool = true
		for n: Variant in fight.enemies:
			var m: MeleeEnemy = n
			idle = idle and (m.st == MeleeEnemy.St.IDLE or m.is_defeated())
		_check(idle and fight.attackers() == 0, "after the loss the enemies stand down")
		_check(lost_n == 1, "lost fires once")
		fight.stop()
		fight.queue_free()
		_reset_player()
		lost_n = 0
		fight = MeleeFight.new()
		fight.name = "Fight2"
		arena.add_child(fight)
		fight.setup({"player": player, "combat": combat, "force_unarmed": false, "seed": 5})
		fight.add_wave([{"archetype": "clone", "at": Vector3(0.0, 0.0, -4.0), "opts": {"ai": false}}])
		fight.add_wave([{"archetype": "clone", "at": Vector3(3.0, 0.0, -4.0), "opts": {"ai": false}},
			{"archetype": "clone", "at": Vector3(-3.0, 0.0, -4.0), "opts": {"ai": false}}])
		fight.lost.connect(func() -> void: lost_n += 1)
		fight.wave_started.connect(func(i: int) -> void: mark["wave_%d" % i] = true)
		fight.start()
		_next("retry")
	if t == 1500 and not mark.has("lost"):
		_check(false, "the player never went down (hp %.1f, %s)" % [combat.hp, str(combat.strikes.slice(-4))])
		fight.stop()
		_start_b()


func _retry(t: int) -> void:
	if t == 2:
		_check(fight.wave == 0 and fight.enemies.size() == 1, "wave 1: one clone")
		var r: String = (fight.enemies[0] as MeleeEnemy).take_strike({"dmg": 999.0, "from": player.global_position})
		_check(r == "ko", "test setup: knocked out (%s)" % r)
	if t == 4:
		_check(fight.state == "running" and fight.ko_total == 1, "a knockout does not end a multi-wave fight")
	if t > 4 and not mark.has("w1") and fight.wave == 1:
		mark["w1"] = t
		_check(t >= 4 + 115, "the next wave comes %.1f s after the last knockout" % MeleeFight.WAVE_GAP_S)
		_check(fight.enemies.size() == 2 and fight.has_checkpoint(), "wave 2: two clones, a checkpoint")
		mark["cp"] = player.global_position
		player.teleport(Vector3(6.0, 0.0, 6.0), 1.0)
	if mark.has("w1") and t == int(mark["w1"]) + 5:
		combat.receive_attack(fight.enemies[0], {"damage": 999.0})
	if mark.has("w1") and t == int(mark["w1"]) + 7:
		_check(fight.state == "lost" and lost_n == 1, "down in wave 2: lost")
		fight.retry()
		_check(fight.state == "running" and fight.wave == 1 and fight.alive().size() == 2, "retry() restarts wave 2 (the checkpoint), not wave 1")
		var full: bool = true
		for n: Variant in fight.enemies:
			full = full and is_equal_approx((n as MeleeEnemy).hp, (n as MeleeEnemy).max_hp)
		_check(full, "the wave's enemies are fresh")
		_check(is_equal_approx(combat.hp, 100.0) and not combat.is_down(), "the player is back with full HP")
		_check(player.global_position.distance_to(mark["cp"]) < 0.1, "the player is back at the checkpoint spot")
	if mark.has("w1") and t == int(mark["w1"]) + 20:
		_check(fight.state == "running" and not player.is_knocked_down(), "the fight goes on after the retry")
		fight.stop()
		_check(not combat.fight_active and fight.enemies.is_empty(), "stop() clears the fight")
		_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
		_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
		_start_b()
	if t == 400:
		_check(false, "the retry test never finished")
		_start_b()


# ---------------------------------------------------------------------------
# B: WeaponDirector arena
# ---------------------------------------------------------------------------
func _start_b() -> void:
	Engine.time_scale = 1.0
	arena.queue_free()
	arena = Node3D.new()
	arena.name = "ArenaB"
	root.add_child(arena)
	World.floor_box(arena)
	player = World.player(arena, Vector3.ZERO, 0.0)
	people = []
	dir = World.director(arena, player, people)
	dir.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
	combat = PlayerCombat.new()
	combat.name = "CombatB"
	arena.add_child(combat)
	combat.setup({"player": player, "weapons": dir, "targets_fn": func() -> Array: return people})
	sibs = []
	_check(dir.unarmed_owner == combat and combat.fx == dir.fx, "the combat owns the director's unarmed slot and shares its FX")
	_next("b")


func _wheel_opens(ww: WeaponWheel) -> bool:
	ww.press()
	ww.step_real(0.2)
	var o: bool = ww.is_open()
	ww.cancel()
	ww.step_real(0.2)
	Engine.time_scale = 1.0
	return o


func _part_b(t: int) -> void:
	if t == 5:
		mark["shots"] = dir.shots
		dir.fire_override = true
		dir.aim_override = true
	if t == 15:
		_check(dir.shots == int(mark["shots"]) and dir.hit_log.is_empty(), "unarmed: the Phase W punch no longer fires")
		_check(not dir.aiming and not player.aiming, "unarmed: right mouse does not aim (it kicks)")
		dir.fire_override = false
		dir.aim_override = false
		ped = World.ped(arena, Vector3(0.0, 0.0, -1.0), 51, player)
		people.append(ped)
	if t == 20 or t == 48 or t == 76:
		combat.light_override = true
	if t == 40:
		_check(ped.state == Pedestrian.State.STUMBLE and heat.is_empty(), "punch 1 on a pedestrian: stumble, no heat (state %d)" % ped.state)
	if t == 68:
		_check(ped.state == Pedestrian.State.STUMBLE, "punch 2: stumble (state %d)" % ped.state)
	if t == 100:
		_check(ped.state == Pedestrian.State.KNOCKED_OUT, "punch 3 knocks the pedestrian out (state %d)" % ped.state)
		_check(heat.size() == 1 and is_equal_approx(heat[0], WeaponData.HEAT_KO_UNARMED), "+1 heat for the knockout (%s)" % str(heat))
		_check(combat.fx.cine.find_children("Star*", "", true, false).size() >= 3, "daze stars over the knocked-out pedestrian")
		var p2: Pedestrian = World.ped(arena, Vector3(0.4, 0.0, -1.2), 52, player)
		people.append(p2)
		mark["p2"] = p2
	if t == 105:
		combat.heavy_override = true
	if t == 140:
		var p2b: Pedestrian = mark["p2"]
		_check(p2b.state == Pedestrian.State.KNOCKED_OUT and heat.size() == 2, "the heavy kick knocks a pedestrian out at once (+1 heat) (state %d, %s)" % [p2b.state, str(heat)])
		dir.equip(WeaponData.Slot.PISTOL)
		dir.aim_override = true
	if t == 170:
		_check(player.aiming, "with the pistol the right mouse aims again")
		dir.aim_override = false
		dir.equip(WeaponData.Slot.UNARMED)
	if t == 180:
		fight = MeleeFight.new()
		fight.name = "FightB"
		arena.add_child(fight)
		fight.setup({"player": player, "combat": combat, "weapons": dir, "force_unarmed": true})
		fight.add_wave([{"archetype": "clone", "at": Vector3(0.0, 0.0, -9.0), "opts": {"ai": false}}])
		dir.equip(WeaponData.Slot.PISTOL)
		fight.start()
		_check(dir.current == WeaponData.Slot.UNARMED and dir.locked, "force unarmed: Tay không equipped, weapons locked")
		_check(not _wheel_opens(dir.wheel), "force unarmed: the weapon wheel does not open")
		dir.wheel.scroll(1)
		_check(dir.current == WeaponData.Slot.UNARMED, "force unarmed: scrolling does not change the weapon")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_MIDDLE
		ev.pressed = true
		fight._input(ev)
		_check(fight.unarmed_lines == 1 and dir.hud.toast_label.text == "Nhiệm vụ này chỉ dùng tay không" and dir.hud.toast_label.visible, "the line 'Nhiệm vụ này chỉ dùng tay không' shows")
	if t == 182:
		_check(combat.hud.visible, "the combat HUD shows during a fight")
		fight.stop()
		_check(not dir.locked and _wheel_opens(dir.wheel), "after the fight the wheel is free again")
		fight.queue_free()
		fight = MeleeFight.new()
		fight.name = "FightDolly"
		arena.add_child(fight)
		fight.setup({"player": player, "combat": combat, "weapons": dir, "force_unarmed": false})
		fight.add_wave([{"archetype": "dolly", "at": Vector3(0.0, 0.0, -2.5), "opts": {"ai": false, "label": "Cừu Dolly"}}])
		fight.won.connect(func() -> void: won_n += 1)
		fight.enemy_fled.connect(func(_x: MeleeEnemy) -> void: fled_n += 1)
		fight.start()
	if t == 185:
		var d: MeleeEnemy = fight.enemies[0]
		var r1: String = d.take_strike({"dmg": 50.0, "stagger": 0.0, "from": player.global_position})
		var r2: String = d.take_strike({"dmg": 50.0, "stagger": 0.0, "from": player.global_position})
		var r3: String = d.take_strike({"dmg": 10.0, "stagger": 0.0, "from": player.global_position})
		_check(r1 == "hit" and r2 == "hit" and r3 == "flee", "Dolly flees once under 30 %% HP (%s, %s, %s)" % [r1, r2, r3])
		_check(d.st == MeleeEnemy.St.FLEE and d.hp >= 1.0 and not d.is_hostile(), "fleeing, not knocked out (%s, hp %.1f)" % [d.state_name(), d.hp])
		mark["d_pos"] = d.global_position
	if t == 185 + 200:
		var d2: MeleeEnemy = fight.enemies[0]
		_check(d2.st == MeleeEnemy.St.FLED and not d2.visible and fled_n == 1, "after 3 s she is gone (%s)" % d2.state_name())
		_check(d2.global_position.distance_to(mark["d_pos"]) > 6.0, "she ran away (%.1f m)" % d2.global_position.distance_to(mark["d_pos"]))
		_check(won_n == 1 and fight.state == "won", "her flight wins the fight")
		_start_c()


# ---------------------------------------------------------------------------
# C: FreeRoam
# ---------------------------------------------------------------------------
func _start_c() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	heat.clear()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	root.add_child(roam)
	_next("c")


func _part_c(t: int) -> void:
	var rc: PlayerCombat = roam.get("combat")
	var pl: ThirdPersonController = roam.get("player")
	var wd: WeaponDirector = roam.get("weapons")
	if t == 240:
		_check(rc != null and wd != null and wd.unarmed_owner == rc and pl.jump_filter.is_valid(), "FreeRoam builds the combat and gives it the unarmed slot")
		_check(rc != null and not rc.hud.visible, "the combat HUD stays hidden in free roam at full HP")
		wd.mayhem.connect(func(h: float, _at: Vector3, _c: String) -> void: heat.append(h))
		var sp: PedestrianSpawner = roam.get("pedestrians")
		var best: Pedestrian = null
		var bd: float = 60.0
		for v: Variant in sp.pedestrians():
			var p: Pedestrian = v
			if p.lod_far or p.is_down():
				continue
			var d: float = p.global_position.distance_to(pl.global_position)
			if d < bd:
				bd = d
				best = p
		if not _check(best != null, "test setup: a near pedestrian in the FreeRoam crowd"):
			_finish()
			return
		ped = best
		ped.state = Pedestrian.State.IDLE
		ped.set("_idle_left", 999.0)
		ped.velocity = Vector3.ZERO
		var fwd: Vector3 = WeaponMath.flat_dir(pl.global_position - ped.global_position)
		var at: Vector3 = ped.global_position + fwd * 1.0
		var to: Vector3 = ped.global_position - at
		pl.teleport(at + Vector3(0.0, 0.05, 0.0), atan2(-to.x, -to.z))
		for v2: Variant in sp.pedestrians():   # nobody else in the cone
			var p3: Pedestrian = v2
			if p3 != ped and p3.global_position.distance_to(at) < 3.0:
				p3.global_position += Vector3(0.0, 0.0, 6.0)
	if t == 250 or t == 278 or t == 306:
		rc.light_override = true
	if t == 340:
		_check(ped.state == Pedestrian.State.KNOCKED_OUT, "in FreeRoam the unarmed combo still knocks out a pedestrian (state %d)" % ped.state)
		_check(heat.size() == 1 and is_equal_approx(heat[0], WeaponData.HEAT_KO_UNARMED), "+1 heat to the wanted level (%s)" % str(heat))
		fight = MeleeFight.new()
		fight.name = "RoamFight"
		roam.add_child(fight)
		fight.setup({"roam": roam, "start_line": "Gét gô!"})
		fight.add_wave([{"archetype": "courier", "at": pl.global_position + pl.facing_dir() * 5.0, "opts": {"ai": false, "label": "Mũ Đỏ", "body": {"helmet_color": Color("#E74C3C")}}}])
		fight.start()
		_check(fight.combat == rc and wd.locked and wd.current == WeaponData.Slot.UNARMED, "a fight built from the roam uses its combat and locks the wheel")
		_check(rc.hud.popup_text == "Gét gô!", "the start line pops")
		root.get_node("GameFX").set("art_style", "classic")   # the HUD draws in the classic style for two frames
		rc.hud.popup(CombatData.T_COUNTER, CombatHUD.GOLD)
	if t == 343:
		_check(rc.hud.visible and rc.fight_active, "the combat HUD shows in the roam fight")
		_check(not CombatHUD.vice() and CombatHUD.accent() == CombatHUD.CLASSIC_ACCENT, "classic style: FPT orange accent")
		root.get_node("GameFX").set("art_style", "vice")
		fight.stop()
		_check(not wd.locked and not rc.fight_active, "stop() frees the wheel")
	if t == 350:
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: MELEE COMBAT (combo, heavy / block break, block + perfect counter, dodge i-frames, daze + finisher slow motion, telegraph, 2-attacker cap, down -> lost, retry checkpoint, force unarmed, Dolly flees, pedestrians in free roam)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
