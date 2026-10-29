# File: res://tests/test_gunfight.gd
# Headless test of the Phase C lair gunfights and the Day 3 forklift boss (spec C-D2, C-D4, C-D13):
#   A  CoverMap slots (low boxes only), the geometric protection test, nearest with occupancy; GunData.hit_chance falls with
#      distance, player speed, popping out of cover and the first shot; plain texts (no ellipsis character, no emoji).
#   cover    hold Ctrl away from cover = nothing; near a slot = snapped, crouched, walking locked, target point low, the box
#            blocks a gunman's line; aiming pops out (target at chest height, the line is clear); release = out of cover;
#            the fight forces the pistol, sets fight_active and hides the CombatHUD bar.
#   lowcover the lowest cover (0.9 m) stops a bullet aimed at the crouched player from 6 m; a slot behind a thin wall is
#            never offered (no snapping through it).
#   duck     an exposed player ducks during a gunman's telegraph: the bullet stops at the cover, no damage; exposed again:
#            hit, HP down, a damage-direction marker on the HUD.
#   states   one gunman: patrol -> (the player's gunshot) alert -> to_cover -> cover -> peek -> flank; a bullet staggers,
#            three knock out; the single wave is won and the weapons are unlocked.
#   tele     every bullet that hits the player resolves at least GunData.telegraph_s() after that gunman's glint started.
#   wall     a gunman 24 m away behind a wide wall, with a nav graph that only covers its side: the cover slot past the wall
#            is refused (no walkable route), it tries to walk to the player and stays behind the wall, never telegraphs,
#            shoots or hurts the player.
#   cap      six gunmen around the player: never more than GunData.max_shooters() shooting at once (and the cap is
#            reached); glints behind the camera
#            show edge markers on the HUD.
#   hp       no regeneration before GunData.regen_delay(), regeneration after; Tay không + Q held does not block gunfire;
#            down -> lost (the gunman stands down, the loss counted for that wave), retry revives and the respawned gunman
#            aims x GunData.retry_mercy(1) (T11 retry mercy).
#   retry    two waves: the wave-2 checkpoint (spot, ammo) comes back on retry() after a loss; a checkpoint taken with no
#            ammo left comes back with one magazine of reserve per loadout gun.
#   ammo     loadout lock (equip refuses, scroll skips, wheel "Khoá"), finite spare rounds, reload from the reserve, out of
#            ammo = dry, no reload, HUD hint; a pickup adds rounds and reloads; stop() restores everything; an unalerted
#            guard without a yaw faces along its patrol.
#   funny    force_loadout off: only the funny weapons are locked.
#   ko       the player's pistol (aimed) staggers then knocks a gunman out (stars, capsule on the floor, enemy_ko, won).
#   boss     forklift: immune outside the windows; charge telegraph >= 1 s, the charge hits the player in its path, crashes
#            into a wall -> vulnerable recover (bullet damage) -> immune again; crate toss: the shadow grows 1.2 s before the
#            landing, a dodge = no damage, staying = a heavy hit; name intro refills 10 % (invulnerable meanwhile), at most
#            twice; overheat = vulnerable with x1.5 damage; HP 0 -> topple -> KO -> won.
#   boss2    real pistol rays from the side reach the driver past the chassis (immune clang in HOLD, damage in the recover
#            window); a charge into the box the player crouches behind crashes into it without hitting him.
#   boss3    the boss AI loop (activate()): idle, charge telegraph, charge, recover, lift, toss.
#   floor    a gunman walking onto a 0.3 m platform follows its height.
#   E        (Wave 3 T3) the pallet-shield guard: the rimmed pallet; aimed pistol rounds from the front are blocked (no
#            damage, "Không xuyên!", reaction none); the 4th knocks the pallet away (it flies off and lands), later rounds
#            hurt; a flank shot hurts at once; one close shotgun blast knocks the pallet away; Dễ: 3 hits; a knockout drops
#            it; a live wave of two gunmen and a shield guard is won by a good bot (no loss).
#   D        (Wave 3 T2, values from T11) the gun difficulty row on Thường and Dễ: GunData values (accuracy x2.0 / x0.8,
#            16 / 8 HP a bullet), telegraph frames between the glint and the shot (21 / 27 at 60 fps), the token cap (4 / 3),
#            combat.regen_delay set while engaged and the regeneration start frame (420 / 180 after the hit), the previous
#            regen delay restored on stop() and on won.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_gunfight.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")
const B0 := [Vector3(0.0, 0.5, -2.0), Vector3(2.0, 1.0, 0.8)]
const BA := [Vector3(106.0, 0.5, -9.5), Vector3(2.0, 1.0, 0.8)]
const BB := [Vector3(94.0, 0.5, -6.0), Vector3(2.0, 1.0, 0.8)]
const B_LOW := [Vector3(0.0, 0.45, 80.0), Vector3(2.0, 0.9, 0.8)]
const B_THIN := [Vector3(0.0, 0.5, 40.0), Vector3(2.0, 1.0, 0.8)]
const W_THIN := [Vector3(0.0, 1.25, 41.6), Vector3(6.0, 2.5, 0.2)]
const B_WALLSIDE := [Vector3(300.0, 0.5, 0.0), Vector3(2.0, 1.0, 0.8)]
const B_BOSS2 := [Vector3(1000.0, 0.5, 0.0), Vector3(2.4, 1.0, 0.8)]
const PLATFORM := [Vector3(1200.0, 0.15, -12.0), Vector3(10.0, 0.3, 20.0)]

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var dir: WeaponDirector
var combat: PlayerCombat
var targets: Array = []
var fight: GunFight
var cm: CoverMap
var g: Gunman
var boss: ForkliftBoss
var tele_frame: Dictionary = {}
var bad_tele: int = 0
var hits_seen: int = 0
var lost_n: int = 0
var won_n: int = 0
var ko_n: int = 0
var max_sh: int = 0
var max_tele: int = 0
var max_edge: int = 0
var spotted_n: int = 0
var alerted_n: int = 0
var results: Array[String] = []
var aux: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	WeaponAudio.sfx_dir = "user://__test_no_sfx__/"
	print("--- TEST GUNFIGHT (lair gunfights + forklift boss) ---")
	_static_checks()
	physics_frame.connect(_on_physics)


func _static_checks() -> void:
	var c := CoverMap.new()
	var n: int = c.add_box(Transform3D(Basis.IDENTITY, B0[0]), B0[1])
	_check(n == 6 and c.count() == 6, "a 2 x 1 x 0.8 low box gets 6 cover slots (%d)" % n)
	_check(c.add_box(Transform3D(Basis.IDENTITY, Vector3(5.0, 1.25, 0.0)), Vector3(2.0, 2.5, 1.0)) == 0, "a 2.5 m tall box is not low cover")
	_check(c.add_box(Transform3D(Basis.IDENTITY, Vector3(9.0, 0.3, 0.0)), Vector3(2.0, 0.6, 1.0)) == 0, "a 0.6 m box is too low to stop bullets: no cover")
	var front: int = c.nearest(Vector3(0.5, 0.0, -0.5), GunData.COVER_ENTER_R)
	_check(front == 3 and c.pos[3].is_equal_approx(Vector3(0.75, 0.0, -1.0)), "nearest slot from (0.5, -0.5) is the front slot at (0.75, -1.0) (%d)" % front)
	_check(c.nearest(Vector3(0.5, 0.0, -0.5), GunData.COVER_ENTER_R, {3: self}) == 2, "an occupied slot is skipped")
	_check(c.protects(3, Vector3(0.0, 0.0, -10.0)) and not c.protects(3, Vector3(0.0, 0.0, 5.0)), "the front slot protects against a threat behind the box, not in front")
	_check(not c.protects(0, Vector3(0.0, 0.0, -10.0)), "an end slot does not protect against a threat along the box (no line through it)")
	var near: float = GunData.hit_chance(6.0, 0.0, false, false)
	_check(GunData.hit_chance(30.0, 0.0, false, false) < near * 0.5, "accuracy falls with distance (%.2f at 6 m)" % near)
	_check(GunData.hit_chance(6.0, 7.5, false, false) < near * 0.5 and GunData.hit_chance(6.0, 4.2, false, false) < near, "accuracy falls while the player moves")
	_check(GunData.hit_chance(6.0, 0.0, true, false) < near and GunData.hit_chance(6.0, 0.0, false, true) < near, "popping out of cover and the first shot are harder to hit")
	var texts: Array[String] = [GunData.T_HP, GunData.T_LEFT, GunData.T_WAVE, GunData.T_COVER_PROMPT, GunData.T_IN_COVER, GunData.T_LOCKED,
		GunData.T_NO_AMMO, GunData.T_AMMO, GunData.T_ALERT, GunData.T_IMMUNE, GunData.T_VULN, GunData.T_OVERHEAT,
		GunData.T_CHARGE, GunData.T_FIGHT_PHONE, GunData.T_FIGHT_EMOTE, GunData.ALEX_FULL]
	texts.append_array(GunData.ALEX_INTRO)
	var bad: Array[String] = []
	for s: String in texts:
		for i: int in s.length():
			var u: int = s.unicode_at(i)
			if u == 0x2026 or (u >= 0x2190 and u <= 0x2BFF) or u >= 0x1F000 or (u >= 0x2600 and u <= 0x27BF):
				bad.append(s)
				break
	_check(bad.is_empty(), "plain texts: no ellipsis character, arrows or emoji (%s)" % str(bad))


func _next(p: String) -> void:
	phase = p
	t0 = frames
	print("  [phase] ", p)


func _fire_edge() -> void:
	dir.cooldown = 0.0
	dir.fire_override = true


func _on_player_hit(src: Node3D, _dmg: float) -> void:
	hits_seen += 1
	if not tele_frame.has(src.get_instance_id()) or frames - int(tele_frame[src.get_instance_id()]) < roundi(GunData.telegraph_s() * 60.0):
		if src is Gunman:
			bad_tele += 1


func _fight(waves: Array, opts: Dictionary = {}, boxes: Array = []) -> GunFight:
	if fight and is_instance_valid(fight):
		fight.stop()
		fight.queue_free()
	cm = CoverMap.new()
	for b: Variant in boxes:
		cm.add_box(Transform3D(Basis.IDENTITY, (b as Array)[0]), (b as Array)[1])
	fight = GunFight.new()
	fight.name = "Fight_" + phase
	arena.add_child(fight)
	var o: Dictionary = {"player": player, "weapons": dir, "combat": combat, "cover": cm, "seed": 5}
	o.merge(opts, true)
	fight.setup(o)
	for w: Variant in waves:
		fight.add_wave(w)
	fight.lost.connect(func() -> void: lost_n += 1)
	fight.won.connect(func() -> void: won_n += 1)
	fight.enemy_ko.connect(func(_e: Node3D) -> void: ko_n += 1)
	fight.player_hit.connect(_on_player_hit)
	fight.spotted.connect(func(_g2: Node3D) -> void: spotted_n += 1)
	fight.alerted.connect(func(_g3: Node3D) -> void: alerted_n += 1)
	return fight


func _fresh(at: Vector3, god: bool = false) -> void:
	combat.revive()
	combat.god = god
	dir.aim_override = false
	dir.fire_override = false
	player.input_override = null
	player.teleport(at, 0.0)
	player.pitch = 0.0
	tele_frame.clear()
	results.clear()


func _watch_tele(gm: Gunman) -> void:
	gm.telegraph_started.connect(func(x: Gunman) -> void:
		tele_frame[x.get_instance_id()] = frames
		if not x.glint.visible:
			aux["glint_off"] = true)


static func _ordered(lg: Array[String], want: Array[String]) -> bool:
	var i: int = 0
	for s: String in lg:
		if i < want.size() and s == want[i]:
			i += 1
	return i == want.size()


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		arena.name = "Arena"
		root.add_child(arena)
		World.floor_box(arena, 3000.0)
		for b: Array in [B0, BA, BB, B_LOW, B_THIN, W_THIN, B_WALLSIDE, B_BOSS2, PLATFORM]:
			World.wall(arena, b[0], b[1])
		World.wall(arena, Vector3(300.0, 1.5, -5.0), Vector3(20.0, 3.0, 0.4))
		World.wall(arena, Vector3(900.0, 1.5, 6.0), Vector3(40.0, 3.0, 1.0))
		player = World.player(arena, Vector3(4.0, 0.0, 3.0), 0.0)
		dir = World.director(arena, player, targets)
		combat = PlayerCombat.new()
		combat.name = "Combat"
		arena.add_child(combat)
		combat.setup({"player": player, "weapons": dir})
		_next("cover")
		return
	var t: int = frames - t0
	if dir.fire_override == true and t > 0 and not aux.get("hold_fire", false):
		dir.fire_override = false
	match phase:
		"cover":
			_ph_cover(t)
		"lowcover":
			_ph_lowcover(t)
		"duck":
			_ph_duck(t)
		"duck2":
			_ph_duck2(t)
		"states":
			_ph_states(t)
		"tele":
			_ph_tele(t)
		"wall":
			_ph_wall(t)
		"cap":
			_ph_cap(t)
		"hp":
			_ph_hp(t)
		"hp_lost":
			_ph_hp_lost(t)
		"retry":
			_ph_retry(t)
		"ammo":
			_ph_ammo(t)
		"funny":
			_ph_funny(t)
		"ko":
			_ph_ko(t)
		"boss":
			_ph_boss(t)
		"boss2":
			_ph_boss2(t)
		"boss3":
			_ph_boss3(t)
		"floor":
			_ph_floor(t)
		"diff":
			_ph_diff(t)
		"shield":
			_ph_shield(t)
		"shieldwave":
			_ph_shieldwave(t)
		"done":
			_report()


func _ph_cover(t: int) -> void:
	if t == 1:
		_fresh(Vector3(4.0, 0.0, 3.0))
		_fight([[{"at": Vector3(0.0, 0.0, -10.0), "opts": {"ai": false}}]], {}, [B0])
		fight.start()
		g = fight.gunmen[0]
		fight.cover_ctl.hold_override = true
	elif t == 5:
		_check(fight.state == "running" and combat.fight_active, "the fight runs and sets fight_active")
		_check(not combat.hud.bar.visible and fight.hud.visible, "the CombatHUD bar is hidden, the GunHUD shows")
		_check(dir.current == WeaponData.Slot.PISTOL and dir.ammo[WeaponData.Slot.PISTOL] == 12, "the loadout is forced: pistol equipped, full magazine")
		_check(not fight.cover_ctl.in_cover and fight.cover_ctl.prompt_slot == -1, "Ctrl held away from cover: no cover")
		player.teleport(Vector3(0.5, 0.0, -0.5), 0.0)
	elif t == 16:
		var cc: PlayerCover = fight.cover_ctl
		_check(cc.in_cover and cc.slot == 3, "Ctrl held near the box: in cover at the front slot (%s, %d)" % [cc.in_cover, cc.slot])
		_check(absf(player.global_position.x - 0.75) < 0.05 and absf(player.global_position.z + 1.0) < 0.05, "snapped to the slot (%s)" % str(player.global_position))
		var want_y: float = minf(GunData.TARGET_CROUCH_Y, 1.0 - GunData.COVER_TARGET_BELOW)
		_check(player.move_lock and cc.hidden() and absf(cc.target_point().y - (player.global_position.y + want_y)) < 0.01, "crouched: walking locked, enemy aim point low (%.2f)" % (cc.target_point().y - player.global_position.y))
		_check(not fight.clear_line(g.muzzle_pos(), fight.player_target()), "the low box blocks the gunman's line to the crouched player")
		_check(fight.hud.prompt_text == GunData.T_IN_COVER, "HUD: in-cover hint (%s)" % fight.hud.prompt_text)
		dir.aim_override = true
		player.input_override = Vector2(1.0, 0.0)
	elif t == 22:
		var cc2: PlayerCover = fight.cover_ctl
		_check(cc2.exposed() and not cc2.hidden(), "aiming pops out of cover")
		_check(absf(cc2.target_point().y - (player.global_position.y + GunData.TARGET_STAND_Y)) < 0.01, "popped out: enemy aim point at the chest")
		_check(fight.clear_line(g.muzzle_pos(), fight.player_target()), "popped out: the gunman's line is clear")
	elif t == 30:
		_check(absf(player.global_position.x - 0.75) < 0.06, "walking input in cover does not move the player (x %.2f)" % player.global_position.x)
		_check(fight.hud.left_text == GunData.T_LEFT % 1 and fight.hud.hp_text == GunData.T_HP + " 100", "HUD: HP and enemies left (%s / %s)" % [fight.hud.hp_text, fight.hud.left_text])
		dir.aim_override = false
		player.input_override = null
	elif t == 38:
		_check(fight.cover_ctl.hidden() and fight.cover_ctl.pose.pose_name == "cover_crouch", "aim released: crouched again (pose %s)" % fight.cover_ctl.pose.pose_name)
		fight.cover_ctl.hold_override = false
	elif t == 41:
		_check(not fight.cover_ctl.in_cover and not player.move_lock and not fight.taken.has(3), "Ctrl released: out of cover, walking unlocked, slot freed")
		_next("lowcover")


func _ph_lowcover(t: int) -> void:
	if t == 1:
		_fresh(Vector3(0.6, 0.0, 81.4))
		_fight([[{"at": Vector3(0.0, 0.0, 74.0), "yaw": PI, "opts": {"ai": false}}]], {}, [B_LOW, B_THIN])
		fight.start()
		g = fight.gunmen[0]
		fight.cover_ctl.hold_override = true
	elif t == 16:
		var cc: PlayerCover = fight.cover_ctl
		_check(cc.in_cover and cc.hidden(), "in cover behind the 0.9 m box")
		_check(absf(cc.target_point().y - player.global_position.y - (0.9 - GunData.COVER_TARGET_BELOW)) < 0.01, "the aim point sits 0.35 m under the box top (%.2f)" % (cc.target_point().y - player.global_position.y))
		_check(not fight.clear_line(g.muzzle_pos(), fight.player_target()), "the 0.9 m box stops a bullet from 6 m at the crouched player")
		fight.cover_ctl.hold_override = false
	elif t == 20:
		player.teleport(Vector3(0.75, 0.0, 42.2), 0.0)   # 0.2 m wall between the player and the front slot of B_THIN
		fight.cover_ctl.hold_override = true
	elif t == 34:
		_check(fight.cover_ctl.map.nearest(player.global_position, GunData.COVER_ENTER_R) >= 0, "a slot is within reach on the other side of the thin wall")
		_check(not fight.cover_ctl.in_cover and fight.cover_ctl.prompt_slot == -1, "no cover through the thin wall (in %s, prompt %d)" % [fight.cover_ctl.in_cover, fight.cover_ctl.prompt_slot])
		_check(player.global_position.z > 41.7, "the player was not moved through the wall (z %.2f)" % player.global_position.z)
		fight.cover_ctl.hold_override = false
		_next("duck")


func _ph_duck(t: int) -> void:
	if t == 1:
		_fresh(Vector3(0.75, 0.0, -1.0))
		_fight([[{"at": Vector3(0.0, 0.0, -10.0), "opts": {"alerted": true}}]], {"accuracy_override": 1.0}, [B0])
		fight.start()
		g = fight.gunmen[0]
		fight.cover_ctl.hold_override = true
		dir.aim_override = true
		aux["duck"] = true
		g.telegraph_started.connect(func(_x: Gunman) -> void:
			if aux.get("duck", false):
				aux["duck"] = false
				dir.aim_override = false)
		g.shot.connect(func(_x: Gunman, r: String) -> void: results.append(r))
	elif t == 4:
		_check(fight.cover_ctl.in_cover and fight.cover_ctl.exposed(), "in cover, aiming (exposed)")
	elif not results.is_empty() or t > 900:
		_check(not results.is_empty() and results[0] == "blocked", "ducking during the telegraph: the bullet stops at the cover (%s)" % str(results))
		_check(is_equal_approx(combat.hp, 100.0) and fight.hits_taken == 0, "no damage from the blocked bullet (hp %.0f)" % combat.hp)
		_check(g.state_name() != "patrol", "the gunman is alerted (%s)" % g.state_name())
		results.clear()
		dir.aim_override = true
		_next("duck2")


func _ph_duck2(t: int) -> void:
	if results.has("hit") or t > 900:
		_check(results.has("hit"), "exposed in cover: an accurate gunman hits (%s)" % str(results))
		_check(combat.hp < 100.0 and fight.hits_taken >= 1, "the hit costs HP (%.0f)" % combat.hp)
		_check(fight.hud._mark_dir.size() > 0, "a damage-direction marker shows on the HUD")
		var sd: Vector2 = fight.hud.screen_dir(Vector3(0.0, 0.0, -1.0))
		_check(sd.y < -0.9, "the marker for a shooter ahead points up the screen (%s)" % str(sd))
		dir.aim_override = false
		fight.cover_ctl.hold_override = false
		_next("states")


func _ph_states(t: int) -> void:
	if t == 1:
		_fresh(Vector3(100.0, 0.0, 0.0), true)
		_fight([[{"at": Vector3(108.0, 0.0, -14.0), "yaw": 0.0, "patrol": [Vector3(108.0, 0.0, -14.0), Vector3(108.0, 0.0, -20.0)]}]],
			{"accuracy_override": 0.0}, [BA, BB])
		fight.start()
		g = fight.gunmen[0]
		aux["start"] = g.global_position
		spotted_n = 0
		alerted_n = 0
	elif t == 60:
		_check(g.state_name() == "patrol" and not g.is_alerted, "the gunman patrols, unaware (%s)" % g.state_name())
		_check(g.global_position.distance_to(aux["start"]) > 0.5, "it walks its patrol")
		_fire_edge()
	elif t > 62 and (g.state_log.has("flank") or t > 1800) and not aux.has("flanked"):
		aux["flanked"] = t
		var want: Array[String] = ["patrol", "alert", "to_cover", "cover", "peek", "flank"]
		print("    gunman states: %s (%d shots, flank after %.1f s)" % [str(g.state_log), g.shots, float(t) / 60.0])
		_check(_ordered(g.state_log, want), "patrol -> alert -> to_cover -> cover -> peek -> flank (%s)" % str(g.state_log))
		_check(g.shots >= 1, "it shot from cover (%d shots)" % g.shots)
		_check(spotted_n == 1 and alerted_n == 1, "the fight signals spotted / alerted once (%d / %d)" % [spotted_n, alerted_n])
	elif aux.has("flanked") and t == int(aux["flanked"]) + 1:
		var r: String = g.take_hit({"kind": "bullet", "from": player.global_position})
		_check(r == "stumble" and g.state_name() == "stagger", "a bullet staggers it (%s, %s)" % [r, g.state_name()])
		_check(not g.telegraphing and not g.has_token, "the stagger cancels the telegraph and the token")
	elif aux.has("flanked") and t == int(aux["flanked"]) + 40:
		_check(g.state_name() != "stagger", "the stagger ends after 0.45 s (%s)" % g.state_name())
		g.take_hit({"kind": "bullet", "from": player.global_position})
		var r2: String = g.take_hit({"kind": "bullet", "from": player.global_position})
		_check(r2 == "knocked_out" and g.state_name() == "ko" and g.is_down(), "a third bullet knocks it out (%s)" % r2)
		_check(ko_n == 1, "enemy_ko emitted")
	elif aux.has("flanked") and t == int(aux["flanked"]) + 44:
		_check(fight.state == "won" and won_n == 1, "the only gunman down: the fight is won (%s)" % fight.state)
		_check(dir.locked_slots.is_empty() and dir.reserve_of(WeaponData.Slot.PISTOL) == -1, "won: weapons unlocked, unlimited reserve again")
		_check(not combat.fight_active and combat.hud.bar.visible, "won: fight_active cleared, the CombatHUD bar back")
		aux.erase("flanked")
		_next("tele")


func _ph_tele(t: int) -> void:
	if t == 1:
		_fresh(Vector3(200.0, 0.0, 0.0), true)
		hits_seen = 0
		bad_tele = 0
		_fight([[{"at": Vector3(200.0, 0.0, -12.0), "opts": {"alerted": true}}, {"at": Vector3(206.0, 0.0, -10.0), "opts": {"alerted": true}}]],
			{"accuracy_override": 1.0})
		fight.start()
		for gm: Variant in fight.gunmen:
			_watch_tele(gm)
	elif t == 600:
		print("    %d hits in 10 s from 2 accurate gunmen, %d telegraphs" % [hits_seen, (fight.gunmen[0] as Gunman).tele_starts + (fight.gunmen[1] as Gunman).tele_starts])
		_check(hits_seen >= 3, "accurate gunmen hit the player (%d hits)" % hits_seen)
		_check(bad_tele == 0, "every hit came >= %.2f s after its gunman's telegraph started (%d early)" % [GunData.telegraph_s(), bad_tele])
		_check(not aux.has("glint_off"), "the glint shows from the telegraph's start")
		var ok: bool = true
		for gm2: Variant in fight.gunmen:
			for v: float in (gm2 as Gunman).tele_before_shot:
				if v < GunData.telegraph_s() - 0.001:
					ok = false
		_check(ok, "every resolved shot had a full %.2f s telegraph" % GunData.telegraph_s())
		_next("wall")


func _ph_wall(t: int) -> void:
	if t == 1:
		_fresh(Vector3(300.0, 0.0, 10.0))
		var nav := HorrorNavGraph.new()
		var a: int = nav.add_node(Vector3(295.0, 0.0, -14.0))
		var b: int = nav.add_node(Vector3(305.0, 0.0, -14.0))
		var c: int = nav.add_node(Vector3(300.0, 0.0, -10.0))
		nav.connect_nodes(a, b)
		nav.connect_nodes(a, c)
		nav.connect_nodes(b, c)
		_fight([[{"at": Vector3(300.0, 0.0, -14.0), "opts": {"alerted": true}}]], {"accuracy_override": 1.0, "nav": nav}, [B_WALLSIDE])
		fight.start()
		g = fight.gunmen[0]
	elif t == 30:
		_check(not fight.clear_line(g.muzzle_pos(), fight.player_target()), "the wall blocks the line")
		_check(fight.cover.protects(4, fight.player_feet()) and absf(fight.cover.pos[4].z + 1.0) < 0.01, "a protecting slot exists past the wall")
	elif t > 30 and t < 420:
		aux["max_z"] = maxf(float(aux.get("max_z", -99.0)), g.global_position.z)
	elif t == 420:
		print("    wall: gunman states %s, furthest z %.2f" % [str(g.state_log), float(aux.get("max_z", -99.0))])
		_check(g.state_log.has("open") and not g.state_log.has("to_cover"), "the slot past the wall is refused (no walkable route): it stays in the open (%s)" % str(g.state_log))
		_check(float(aux.get("max_z", -99.0)) < -5.2, "it never walks through the wall (furthest z %.2f)" % float(aux.get("max_z", -99.0)))
		_check(g.tele_starts == 0 and g.shots == 0, "behind a wall: no telegraph, no shot (%d / %d)" % [g.tele_starts, g.shots])
		_check(is_equal_approx(combat.hp, 100.0) and fight.hits_taken == 0, "never hurt through the wall")
		aux.erase("max_z")
		_next("cap")


func _ph_cap(t: int) -> void:
	if t == 1:
		_fresh(Vector3(400.0, 0.0, 0.0), true)
		max_sh = 0
		max_tele = 0
		max_edge = 0
		var w: Array = []
		for i: int in 6:
			var a: float = TAU * float(i) / 6.0
			w.append({"at": Vector3(400.0 + sin(a) * 10.0, 0.0, cos(a) * 10.0), "opts": {"alerted": true}})
		_fight([w], {"accuracy_override": 0.0})
		fight.start()
	elif t > 1 and t < 600:
		max_sh = maxi(max_sh, fight.shooters())
		var tn: int = 0
		for gm: Variant in fight.gunmen:
			if (gm as Gunman).telegraphing:
				tn += 1
		max_tele = maxi(max_tele, tn)
		max_edge = maxi(max_edge, fight.hud.edge_markers)
	elif t == 600:
		var shots_total: int = 0
		for gm3: Variant in fight.gunmen:
			shots_total += (gm3 as Gunman).shots
		print("    6 gunmen: max %d shooting at once, %d telegraphing at once, %d shots in 10 s" % [max_sh, max_tele, shots_total])
		var cap: int = GunData.max_shooters()
		_check(max_sh <= cap and fight.max_shooters_seen <= cap, "never more than %d shooting at once (max %d)" % [cap, max_sh])
		_check(max_sh == cap, "the cap is reached with 6 gunmen (max %d of %d)" % [max_sh, cap])
		_check(max_tele <= cap, "at most %d telegraphs at once (%d)" % [cap, max_tele])
		_check(max_edge >= 1, "glints behind the camera show edge markers on the HUD (max %d)" % max_edge)
		_next("hp")


func _ph_hp(t: int) -> void:
	if t == 1:
		_fresh(Vector3(500.0, 0.0, 0.0))
		_fight([[{"at": Vector3(500.0, 0.0, -30.0), "opts": {"ai": false}}]])
		fight.start()
		g = fight.gunmen[0]
	elif t == 3:
		var r: String = fight.hit_player(g, 8.0)
		_check(r == "hit" and is_equal_approx(combat.hp, 92.0), "a gunman hit costs 8 HP (%s, %.0f)" % [r, combat.hp])
	elif t == 3 + roundi(GunData.regen_delay() * 60.0) - 30:
		_check(is_equal_approx(combat.hp, 92.0), "no regeneration before %.0f s (%.1f)" % [GunData.regen_delay(), combat.hp])
	elif t == 3 + roundi(GunData.regen_delay() * 60.0) + 30:
		_check(combat.hp > 92.0, "regeneration after %.0f s without damage (%.1f)" % [GunData.regen_delay(), combat.hp])
		dir.equip(WeaponData.Slot.UNARMED)
		combat.block_override = true
	elif t == 3 + roundi(GunData.regen_delay() * 60.0) + 40:
		_check(combat.blocking, "Tay không + Q: blocking")
		var before: float = combat.hp
		var r2: String = fight.hit_player(g, 8.0)
		_check(r2 == "hit" and combat.hp < before, "gunfire goes through a block (%s, %.0f -> %.0f)" % [r2, before, combat.hp])
		combat.block_override = null
		dir.equip(WeaponData.Slot.PISTOL)
		_next("hp_lost")


func _ph_hp_lost(t: int) -> void:
	if t == 1:
		_fresh(Vector3(500.0, 0.0, 0.0))
		lost_n = 0
		_fight([[{"at": Vector3(500.0, 0.0, -8.0), "opts": {"alerted": true}}]], {"accuracy_override": 1.0})
		fight.start()
		g = fight.gunmen[0]
		combat.hp = 10.0
	elif lost_n > 0 and not aux.has("lost_t"):
		aux["lost_t"] = t
		_check(combat.is_down() and fight.state == "lost", "HP 0: down and the fight is lost (%s)" % fight.state)
	elif aux.has("lost_t") and t == int(aux["lost_t"]) + 2:
		_check(g.state_name() == "idle" and not g.has_token, "the gunman stands down (%s)" % g.state_name())
		_check(combat.fight_active and not dir.locked_slots.is_empty(), "lost keeps the fight set up for the retry")
		_check(fight.fail_wave == 0 and fight.fail_streak == 1, "the loss is counted for wave 1 (wave %d, streak %d)" % [fight.fail_wave, fight.fail_streak])
		fight.retry()
		_check(fight.state == "running" and not combat.is_down() and is_equal_approx(combat.hp, 100.0), "retry: running again with full HP")
		var rg: Gunman = fight.gunmen[0]
		_check(is_equal_approx(rg.accuracy_k, GunData.retry_mercy(1)) and is_equal_approx(GunData.retry_mercy(1), 0.85)
			and is_equal_approx(GunData.retry_mercy(9), GunData.RETRY_MERCY_MIN),
			"retry mercy: the respawned gunman aims x%.2f after one loss (floor %.2f)" % [rg.accuracy_k, GunData.retry_mercy(9)])
		aux.erase("lost_t")
		_next("retry")
	elif t > 1500:
		_check(false, "the player was never downed (hp %.0f)" % combat.hp)
		_next("retry")


func _ph_retry(t: int) -> void:
	if t == 1:
		_fresh(Vector3(600.0, 0.0, 0.0), true)
		lost_n = 0
		_fight([[{"at": Vector3(600.0, 0.0, -8.0), "opts": {"ai": false}}],
			[{"at": Vector3(595.0, 0.0, -15.0), "opts": {"ai": false}}, {"at": Vector3(605.0, 0.0, -15.0), "opts": {"ai": false}}]])
		fight.wave_started.connect(func(i: int) -> void:
			if i == 1:
				aux["p2"] = player.global_position
				aux["ammo2"] = dir.ammo[WeaponData.Slot.PISTOL])
		fight.start()
		player.teleport(Vector3(601.0, 0.0, -1.0), 0.0)
		for i: int in 3:
			fight.gunmen[0].take_hit({"kind": "bullet", "from": player.global_position})
	elif t == 4:
		_check(fight.alive().is_empty() and fight.state == "running", "wave 1 cleared, the next wave waits 2 s")
	elif t == 140:
		_check(fight.wave == 1 and fight.alive().size() == 2 and aux.has("p2"), "wave 2 spawned with a checkpoint (wave %d)" % fight.wave)
		_check(fight.hud.wave_text == GunData.T_WAVE % [2, 2], "HUD wave text (%s)" % fight.hud.wave_text)
		player.teleport(Vector3(610.0, 0.0, 6.0), 0.0)
		_fire_edge()
	elif t == 160:
		_check(dir.ammo[WeaponData.Slot.PISTOL] < int(aux["ammo2"]), "a round was fired after the checkpoint")
		combat.god = false
		combat.hp = 5.0
		fight.hit_player(fight.gunmen[0], 8.0)
	elif t == 163:
		_check(lost_n == 1 and fight.state == "lost", "down after the checkpoint: lost")
		fight.retry()
		_check(player.global_position.distance_to(aux["p2"]) < 0.1, "retry: back at the wave-2 checkpoint spot")
		_check(fight.wave == 1 and fight.alive().size() == 2 and fight.state == "running", "retry: wave 2 spawned again")
		_check(dir.ammo[WeaponData.Slot.PISTOL] == int(aux["ammo2"]) and is_equal_approx(combat.hp, 100.0), "retry: the checkpoint's ammo and full HP")
		var r: PackedInt32Array = dir.reserve
		r[WeaponData.Slot.PISTOL] = 0
		r[WeaponData.Slot.SHOTGUN] = 0
		dir.reserve = r
		var a: PackedInt32Array = dir.ammo
		a[WeaponData.Slot.PISTOL] = 0
		a[WeaponData.Slot.SHOTGUN] = 0
		dir.ammo = a
		fight.checkpoint()
		combat.hp = 5.0
		fight.hit_player(fight.gunmen[0], 8.0)
	elif t == 166:
		_check(fight.state == "lost", "down again after an empty-handed checkpoint")
		fight.retry()
		_check(dir.reserve_of(WeaponData.Slot.PISTOL) == 12 and dir.reserve_of(WeaponData.Slot.SHOTGUN) == 6,
			"retry tops each loadout gun up to one magazine of reserve (%d / %d)" % [dir.reserve_of(WeaponData.Slot.PISTOL), dir.reserve_of(WeaponData.Slot.SHOTGUN)])
		_next("ammo")


func _ph_ammo(t: int) -> void:
	if t == 1:
		_fresh(Vector3(700.0, 0.0, 0.0))
		dir.equip(WeaponData.Slot.UNARMED)
		_fight([[{"at": Vector3(720.0, 0.0, -45.0), "opts": {"ai": false}},
			{"at": Vector3(730.0, 0.0, -45.0), "patrol": [Vector3(730.0, 0.0, -45.0), Vector3(735.0, 0.0, -45.0)], "opts": {"ai": false}}]])
		fight.start()
	elif t == 3:
		_check(absf(wrapf((fight.gunmen[1] as Gunman).yaw + PI * 0.5, -PI, PI)) < 0.01 and absf((fight.gunmen[0] as Gunman).yaw) < 0.01,
			"unalerted guards keep their facing: along the patrol, else yaw 0 (%.2f, %.2f)" % [(fight.gunmen[1] as Gunman).yaw, (fight.gunmen[0] as Gunman).yaw])
		_check(dir.current == WeaponData.Slot.PISTOL and dir.reserve_of(WeaponData.Slot.PISTOL) == 48 and dir.reserve_of(WeaponData.Slot.SHOTGUN) == 12,
			"finite spare rounds: pistol 48, shotgun 12")
		_check(dir.ammo_text(WeaponData.Slot.PISTOL) == "12 / 48", "ammo text with the reserve (%s)" % dir.ammo_text(WeaponData.Slot.PISTOL))
		var want_locked: bool = true
		for s: int in [WeaponData.Slot.KNIFE, WeaponData.Slot.ROCKET, WeaponData.Slot.DEP, WeaponData.Slot.DURIAN, WeaponData.Slot.LOA]:
			want_locked = want_locked and dir.locked_slots.has(s) and not dir.wheel.is_enabled(s)
		_check(want_locked and not dir.locked_slots.has(WeaponData.Slot.SHOTGUN), "force_loadout: everything but Tay không, pistol, shotgun is locked")
		_check(String(dir.wheel.slots[WeaponData.Slot.ROCKET].get("off_text", "")) == GunData.T_LOCKED, "the wheel greys locked slots as Khoá")
		dir.equip(WeaponData.Slot.ROCKET)
		_check(dir.current == WeaponData.Slot.PISTOL, "equip refuses a locked slot")
		dir.cycle(1)
		var c1: int = dir.current
		dir.cycle(1)
		var c2: int = dir.current
		dir.cycle(1)
		_check(c1 == WeaponData.Slot.SHOTGUN and c2 == WeaponData.Slot.UNARMED and dir.current == WeaponData.Slot.PISTOL, "scroll skips locked slots (%d %d %d)" % [c1, c2, dir.current])
		aux["hold_fire"] = true
		dir.fire_override = true
	elif t > 3 and aux.get("hold_fire", false) and dir.ammo[WeaponData.Slot.PISTOL] == 0:
		aux["hold_fire"] = false
		dir.fire_override = false
		aux["empty_t"] = t
	elif aux.has("empty_t") and t == int(aux["empty_t"]) + 110:
		_check(dir.ammo[WeaponData.Slot.PISTOL] == 12 and dir.reserve_of(WeaponData.Slot.PISTOL) == 36, "the auto reload takes 12 from the reserve (%d / %d)" % [dir.ammo[WeaponData.Slot.PISTOL], dir.reserve_of(WeaponData.Slot.PISTOL)])
		var r: PackedInt32Array = dir.reserve
		r[WeaponData.Slot.PISTOL] = 0
		dir.reserve = r
		var a: PackedInt32Array = dir.ammo
		a[WeaponData.Slot.PISTOL] = 0
		dir.ammo = a
		aux["shots0"] = dir.shots
		_fire_edge()
	elif aux.has("empty_t") and t == int(aux["empty_t"]) + 116:
		_check(dir.shots == int(aux["shots0"]) and dir.reload_left <= 0.0, "out of ammo: no shot, no reload")
		_check(fight.hud.prompt_text == GunData.T_NO_AMMO, "HUD: out-of-ammo hint (%s)" % fight.hud.prompt_text)
		aux["pick"] = fight.add_ammo(Vector3(703.0, 0.0, 0.0), WeaponData.Slot.PISTOL, 24)
		player.teleport(Vector3(703.0, 0.0, 0.3), 0.0)
	elif aux.has("empty_t") and t == int(aux["empty_t"]) + 120:
		var p: AmmoPickup = aux["pick"]
		_check(p.taken and not p.visible, "walking onto the ammo box takes it")
		_check(dir.reload_left > 0.0 and dir.reserve_of(WeaponData.Slot.PISTOL) == 24, "the pickup adds 24 rounds and reloads the empty pistol")
		_check(fight.hud.toast_text == GunData.T_AMMO % [24, WeaponData.name_of(WeaponData.Slot.PISTOL)], "toast %s" % fight.hud.toast_text)
	elif aux.has("empty_t") and t == int(aux["empty_t"]) + 230:
		_check(dir.ammo[WeaponData.Slot.PISTOL] == 12 and dir.reserve_of(WeaponData.Slot.PISTOL) == 12, "reloaded from the pickup (%d / %d)" % [dir.ammo[WeaponData.Slot.PISTOL], dir.reserve_of(WeaponData.Slot.PISTOL)])
		fight.stop()
		_check(dir.locked_slots.is_empty() and dir.reserve_of(WeaponData.Slot.PISTOL) == -1 and dir.wheel.is_enabled(WeaponData.Slot.ROCKET), "stop(): slots unlocked, unlimited reserve")
		_check(not combat.fight_active and not fight.hud.visible and dir.ammo_text(WeaponData.Slot.PISTOL).ends_with("∞"), "stop(): fight_active off, HUD hidden, ammo text back to unlimited")
		aux.erase("empty_t")
		_next("funny")


func _ph_funny(t: int) -> void:
	if t == 1:
		_fresh(Vector3(700.0, 0.0, 0.0))
		_fight([[{"at": Vector3(720.0, 0.0, -45.0), "opts": {"ai": false}}]], {"force_loadout": false})
		fight.start()
	elif t == 3:
		_check(not dir.locked_slots.has(WeaponData.Slot.KNIFE) and dir.locked_slots.has(WeaponData.Slot.ROCKET) and dir.locked_slots.has(WeaponData.Slot.LOA),
			"lock_funny only: the knife is allowed, the funny weapons are locked")
		_next("ko")


func _ph_ko(t: int) -> void:
	if t == 1:
		_fresh(Vector3(800.0, 0.0, 0.0))
		ko_n = 0
		won_n = 0
		_fight([[{"at": Vector3(800.0 + ThirdPersonController.AIM_SIDE, 0.0, -8.0), "opts": {"ai": false, "mask": "wolf"}}]])
		fight.start()
		g = fight.gunmen[0]
		dir.aim_override = true
	elif t == 3:
		_check(dir.soft_targets().has(g), "the gunman is one of the weapons' targets")
		_check(g.body.has_meta("guard_mask"), "the wolf mask is on")
	elif t == 25 or t == 45 or t == 65:
		_fire_edge()
	elif t == 28:
		_check(is_equal_approx(g.hp, 35.0) and dir.hit_log.size() > 0 and String(dir.hit_log[-1]["reaction"]) == "stumble", "an aimed pistol round hits for 25 (hp %.0f)" % g.hp)
	elif t == 68:
		_check(g.is_down() and ko_n == 1, "the third round knocks it out (hp %.0f)" % g.hp)
		_check(absf(g.global_position.y + GunData.KO_DROP) < 0.01, "knocked out: its capsule lies on the floor")
		_check(not dir.fx.cine.find_children("Star*", "", true, false).is_empty(), "daze stars over the knocked-out gunman")
		_check(fight.state == "won" and won_n == 1, "the wave is won")
		dir.aim_override = false
		_next("boss")


func _ph_boss(t: int) -> void:
	if t == 1:
		_fresh(Vector3(900.0, 0.0, 0.0))
		won_n = 0
		aux["vuln"] = []
		aux["land"] = []
		aux["names"] = 0
		_fight([[{"boss": "forklift", "at": Vector3(900.0, 0.0, -12.0), "yaw": PI, "opts": {"ai": false}}]])
		fight.start()
		boss = fight.boss
		boss.charge_started.connect(func(_d: Vector3) -> void: aux["charge_f"] = frames)
		boss.crashed.connect(func() -> void: aux["crash_f"] = frames)
		boss.vulnerable_changed.connect(func(on: bool) -> void: (aux["vuln"] as Array).append(on))
		boss.crate_tossed.connect(func(_p: Vector3) -> void: aux["toss_f"] = frames)
		boss.crate_landed.connect(func(_p: Vector3, hit: bool) -> void: (aux["land"] as Array).append([frames, hit]))
		boss.name_intro.connect(func(_c: int) -> void: aux["names"] = int(aux["names"]) + 1)
		boss.toppled.connect(func() -> void: aux["toppled"] = true)
	elif t == 4:
		_check(boss != null and boss.state_name() == "hold" and is_equal_approx(boss.hp, GunData.BOSS_HP), "the forklift boss spawned (hold, full HP)")
		_check(fight.hud.boss_shown and fight.hud.boss_name.ends_with("...") and fight.hud.boss_name.begins_with(GunData.ALEX_SHORT), "boss bar: the endless name cut to fit (%s)" % fight.hud.boss_name)
		_check(dir.soft_targets().has(boss.hit_node()), "the driver is one of the weapons' targets")
		var r: String = dir.hit_target(boss.hit_node(), {"kind": "bullet", "from": player.global_position})
		_check(r == "blocked" and is_equal_approx(boss.hp, GunData.BOSS_HP) and boss.immune_hits == 1, "outside a window a bullet only clangs (%s)" % r)
		_check(fight.hud.toast_text == GunData.T_IMMUNE, "toast: Không xi nhê!")
	elif t == 10:
		boss.force_attack("charge")
		_check(boss.state_name() == "charge_tell" and boss.forklift.beacon_mode == "red", "charge telegraph: red beacon")
	elif t == 40:
		_check(boss.state_name() == "charge_tell" and is_equal_approx(combat.hp, 100.0), "still telegraphing after 0.5 s, nobody hurt")
	elif t > 40 and aux.has("crash_f") and not aux.has("crash_checked"):
		aux["crash_checked"] = t
		print("    charge: telegraph %d frames, crash %d frames later at z %.1f (speed %.1f)" % [int(aux.get("charge_f", 0)) - (t0 + 10), int(aux["crash_f"]) - int(aux.get("charge_f", 0)), boss.forklift.global_position.z, boss.forklift.last_crash_speed])
		_check(int(aux.get("charge_f", 0)) - (t0 + 10) >= 59, "the charge starts after a >= 1 s telegraph (%d frames)" % (int(aux.get("charge_f", 0)) - (t0 + 10)))
		_check(boss.charge_hits == 1 and combat.hp <= 75.0 + 0.01, "the charge hits the player in its path once (25, hp %.0f)" % combat.hp)
		_check(boss.state_name() == "recover" and boss.vulnerable() and (aux["vuln"] as Array) == [true], "crashed into the wall: recovering, vulnerable")
		_check(boss.status_text() == GunData.T_VULN, "status SƠ HỞ!")
		var r2: String = dir.hit_target(boss.hit_node(), {"kind": "bullet", "from": player.global_position})
		_check(r2 == "hit" and is_equal_approx(boss.hp, GunData.BOSS_HP - 25.0), "a bullet in the window hurts (%s, %.0f)" % [r2, boss.hp])
	elif aux.has("crash_checked") and t == int(aux["crash_checked"]) + 200:
		_check(not boss.vulnerable() and (aux["vuln"] as Array) == [true, false] and boss.state_name() == "hold", "the window closes after 3.2 s (%s)" % boss.state_name())
		var r3: String = boss.take_driver_hit({"kind": "bullet"})
		_check(r3 == "blocked" and is_equal_approx(boss.hp, GunData.BOSS_HP - 25.0), "immune again")
		_fresh(Vector3(900.0, 0.0, 0.0))
		boss.force_attack("toss")
		_check(boss.state_name() == "lift" and boss.forklift.crate != null, "lift: a crate on the forks")
		aux["toss1"] = true
	elif aux.has("toss1") and aux.has("toss_f") and not aux.has("dodged"):
		aux["dodged"] = frames
		_check(boss.crates_in_flight() == 1, "a crate is in the air")
		player.teleport(Vector3(904.0, 0.0, 0.0), 0.0)
	elif aux.has("dodged") and frames == int(aux["dodged"]) + 30:
		_check(boss.shadow_progress() > 0.3 and boss.shadow_progress() < 0.6, "the shadow grows while the crate flies (%.2f)" % boss.shadow_progress())
	elif aux.has("dodged") and (aux["land"] as Array).size() == 1 and not aux.has("land1"):
		aux["land1"] = t
		var l: Array = (aux["land"] as Array)[0]
		_check(int(l[0]) - int(aux["toss_f"]) >= 71, "the shadow shows >= 1.2 s before the landing (%d frames)" % (int(l[0]) - int(aux["toss_f"])))
		_check(not bool(l[1]) and is_equal_approx(combat.hp, 100.0), "dodged the crate: no damage")
	elif aux.has("land1") and t == int(aux["land1"]) + 30:
		player.teleport(Vector3(900.0, 0.0, 0.0), 0.0)
		aux.erase("toss_f")
		boss.force_attack("toss")
	elif aux.has("land1") and (aux["land"] as Array).size() == 2 and not aux.has("land2"):
		aux["land2"] = t
		_check(bool((aux["land"] as Array)[1][1]) and boss.crate_hits == 1 and is_equal_approx(combat.hp, 70.0), "standing under the crate: a 30 HP hit (hp %.0f)" % combat.hp)
	elif aux.has("land2") and t == int(aux["land2"]) + 40:
		boss.apply_damage(boss.hp - GunData.BOSS_HP * 0.64)
		aux["hp_a"] = boss.hp
	elif aux.has("land2") and t == int(aux["land2"]) + 43:
		_check(boss.state_name() == "name" and boss.is_naming() and int(aux["names"]) == 1, "under 66 %%: the name intro (%s)" % boss.state_name())
		_check(boss.take_driver_hit({"kind": "bullet"}) == "blocked", "invulnerable while restating his name")
	elif aux.has("land2") and t == int(aux["land2"]) + 43 + 60:
		_check(fight.hud.subtitle_text.contains(GunData.ALEX_FULL), "the endless name as a subtitle (%s)" % fight.hud.subtitle_text.left(40))
	elif aux.has("land2") and t == int(aux["land2"]) + 43 + 200:
		_check(boss.state_name() == "hold" and absf(boss.hp - (float(aux["hp_a"]) + GunData.BOSS_HP * GunData.NAME_REFILL)) < 0.5, "the intro refilled 10 %% (%.0f)" % boss.hp)
		boss.apply_damage(boss.hp - GunData.BOSS_HP * 0.32)
		aux["hp_b"] = boss.hp
	elif aux.has("land2") and t == int(aux["land2"]) + 43 + 205:
		_check(boss.state_name() == "name" and int(aux["names"]) == 2, "under 33 %: the second intro")
	elif aux.has("land2") and t == int(aux["land2"]) + 43 + 405:
		_check(absf(boss.hp - (float(aux["hp_b"]) + GunData.BOSS_HP * GunData.NAME_REFILL)) < 0.5, "second refill (%.0f)" % boss.hp)
		boss.hp = GunData.BOSS_HP * 0.9
		boss.apply_damage(GunData.BOSS_HP * 0.6)
	elif aux.has("land2") and t == int(aux["land2"]) + 43 + 410:
		_check(int(aux["names"]) == 2 and boss.name_intros == 2 and boss.state_name() == "hold", "capped: no third name intro")
		boss.heat = 100.0
		boss._back_to_idle()
		_check(boss.state_name() == "overheat" and boss.vulnerable() and boss.status_text() == GunData.T_OVERHEAT, "heat 100: overheating, vulnerable")
		var before: float = boss.hp
		boss.take_driver_hit({"kind": "bullet"})
		_check(absf(before - boss.hp - 25.0 * GunData.OVERHEAT_DMG_K) < 0.01, "overheat damage x1.5 (%.1f)" % (before - boss.hp))
	elif aux.has("land2") and t == int(aux["land2"]) + 43 + 690:
		_check(boss.state_name() == "hold" and is_equal_approx(boss.heat, 0.0), "the overheat ends and the heat resets")
		boss.apply_damage(boss.hp)
		_check(boss.state_name() == "topple" and boss.forklift.toppling, "HP 0: the forklift topples")
	elif aux.has("land2") and t == int(aux["land2"]) + 43 + 900:
		_check(aux.has("toppled") and boss.forklift.topple_done and absf(boss.forklift.topple_angle - PI * 0.5) < 0.01, "toppled onto its side")
		_check(boss.state_name() == "ko" and boss.is_defeated() and boss.driver.get_parent() == boss, "Alexander tumbled out, knocked out")
		_check(fight.state == "won" and won_n == 1, "the boss down: the fight is won (%s)" % fight.state)
		_next("boss2")
	elif t > 4000:
		_check(false, "boss phase timed out (state %s, aux %s)" % [boss.state_name() if boss else "-", str(aux.keys())])
		_next("done")


## Stand the player 8 m to the forklift's +x side, level with its seat, facing it (aimed: the camera ray runs through the
## driver); returns the expected driver point.
func _side_shot_spot() -> void:
	var seat: Vector3 = boss.forklift.seat_point()
	player.teleport(Vector3(seat.x + 8.0, 0.0, seat.z + ThirdPersonController.AIM_SIDE), PI * 0.5)
	player.pitch = 0.0
	dir.aim_override = true


func _ph_boss2(t: int) -> void:
	if t == 1:
		_fresh(Vector3(1000.0, 0.0, 0.0))
		won_n = 0
		aux.clear()
		_fight([[{"boss": "forklift", "at": Vector3(1000.0, 0.0, -12.0), "yaw": PI, "opts": {"ai": false}}]], {}, [B_BOSS2])
		fight.start()
		boss = fight.boss
		boss.crashed.connect(func() -> void: aux["crash2"] = frames)
		_side_shot_spot()
	elif t == 20:
		_fire_edge()
	elif t == 24:
		_check(boss.immune_hits == 1 and is_equal_approx(boss.hp, GunData.BOSS_HP), "a real pistol ray from the side reaches the driver past the chassis: immune clang (%d)" % boss.immune_hits)
		dir.aim_override = false
		_fresh(Vector3(1000.95, 0.0, 1.0))
		fight.cover_ctl.hold_override = true
	elif t == 60:
		_check(fight.cover_ctl.in_cover and fight.cover_ctl.hidden(), "crouched behind the box in the forklift's path (in %s)" % fight.cover_ctl.in_cover)
		boss.force_attack("charge")
	elif aux.has("crash2") and not aux.has("crash2_t"):
		aux["crash2_t"] = t
		print("    charge into cover: crash at z %.2f, forks at z %.2f, player z %.2f" % [boss.forklift.global_position.z, boss.forklift.fork_tips().z, player.global_position.z])
		_check(boss.charge_hits == 0 and is_equal_approx(combat.hp, 100.0) and not player.is_knocked_down(), "the charge crashes into the cover box without hitting the player behind it (hp %.0f)" % combat.hp)
		_check(boss.state_name() == "recover", "recovering after the crash")
		fight.cover_ctl.hold_override = false
	elif aux.has("crash2_t") and t == int(aux["crash2_t"]) + 4:
		_side_shot_spot()
	elif aux.has("crash2_t") and t == int(aux["crash2_t"]) + 20:
		_check(boss.vulnerable(), "still in the window")
		_fire_edge()
	elif aux.has("crash2_t") and t == int(aux["crash2_t"]) + 24:
		_check(is_equal_approx(boss.hp, GunData.BOSS_HP - 25.0), "a real pistol ray in the window hurts him (%.0f)" % boss.hp)
		dir.aim_override = false
		aux.clear()
		_next("boss3")
	elif t > 900:
		_check(false, "boss2 timed out (%s)" % boss.state_name())
		_next("boss3")


func _ph_boss3(t: int) -> void:
	if t == 1:
		_fresh(Vector3(1100.0, 0.0, 0.0), true)
		_fight([[{"boss": "forklift", "at": Vector3(1100.0, 0.0, -18.0), "yaw": PI, "opts": {"ai": false}}]])
		fight.start()
		boss = fight.boss
		aux["fk0"] = boss.forklift.global_position
	elif t == 5:
		_check(boss.state_name() == "hold", "spawned holding (ai false)")
		boss.activate()
		_check(boss.state_name() == "idle" and boss.ai, "activate(): the AI loop starts")
	elif t == 50:
		_check(boss.forklift.global_position.distance_to(aux["fk0"]) > 0.5, "idle: it drives towards the player (%.2f m)" % boss.forklift.global_position.distance_to(aux["fk0"]))
	elif t == 900:
		print("    boss AI: %s (%d charges, %d tosses)" % [str(boss.state_log), boss.charges, boss.tosses])
		_check(_ordered(boss.state_log, ["idle", "charge_tell", "charge", "recover", "idle", "lift", "toss"]), "the AI loop runs idle -> charge -> recover -> lift -> toss (%s)" % str(boss.state_log))
		_check(boss.charges >= 1 and boss.tosses >= 1, "it charged and tossed on its own")
		_next("floor")


func _ph_floor(t: int) -> void:
	if t == 1:
		_fresh(Vector3(1200.0, 0.3, -4.0), true)
		_fight([[{"at": Vector3(1200.0, 0.0, -27.0), "opts": {"alerted": true}}]], {"accuracy_override": 0.0})
		fight.start()
		g = fight.gunmen[0]
	elif t == 900:
		print("    floor: gunman at z %.2f, floor %.2f" % [g.global_position.z, g.floor_y])
		_check(g.global_position.z > -21.5, "it walked onto the platform (z %.2f)" % g.global_position.z)
		_check(absf(g.floor_y - 0.3) < 0.02 and (g.drop > 0.01 or absf(g.global_position.y - 0.3) < 0.02), "it follows the platform's height (floor %.2f, y %.2f)" % [g.floor_y, g.global_position.y])
		_next("shield")


## Part E: the pallet-shield guard (unit checks with real aimed rounds, Dễ, the knockout).
func _ph_shield(t: int) -> void:
	var sx: float = -600.0
	if t == 1:
		_fresh(Vector3(sx, 0.0, 0.0))
		aux["drops"] = 0
		_fight([[{"at": Vector3(sx + ThirdPersonController.AIM_SIDE, 0.0, -8.0), "yaw": PI, "opts": {"ai": false, "kind": "shield"}}]])
		fight.start()
		g = fight.gunmen[0]
		g.shield_dropped.connect(func(_x: Gunman) -> void: aux["drops"] = int(aux["drops"]) + 1)
		dir.aim_override = true
	elif t == 3:
		_check(g.kind == "shield" and g.has_shield() and g.shield != null and g.shield.get_parent() == g.body, "E: the shield guard holds a pallet")
		_check(Readability.rimmed_count(g.shield) > 0, "E: the pallet carries the enemy rim (%d meshes)" % Readability.rimmed_count(g.shield))
		_check(g.front_hit(player.global_position), "E: the player stands in his front")
	elif t == 25 or t == 45 or t == 65 or t == 85 or t == 105:
		_fire_edge()
	elif t == 48:
		_check(is_equal_approx(g.hp, 60.0) and g.blocked_hits == 2 and g.shield_hits == 2, "E: two front rounds hit the pallet, no damage (hp %.0f, blocked %d)" % [g.hp, g.blocked_hits])
		_check(String(dir.hit_log[-1]["reaction"]) == "none", "E: a blocked round reads as no hit (no hit marker)")
		_check(g.shout.visible and g.shout.text == GunData.T_NO_PIERCE, "E: \"%s\" over his head" % GunData.T_NO_PIERCE)
	elif t == 88:
		_check(not g.has_shield() and int(aux["drops"]) == 1 and g.shield.top_level and g.shield.get_parent() == g, "E: the 4th round knocks the pallet away (drops %d)" % int(aux["drops"]))
		_check(is_equal_approx(g.hp, 60.0), "E: the knock-away itself does no damage (hp %.0f)" % g.hp)
		_check(Readability.rimmed_count(g.shield) == 0, "E: the flying pallet is no longer rimmed")
	elif t == 108:
		_check(is_equal_approx(g.hp, 35.0), "E: without the pallet a front round hurts (hp %.0f)" % g.hp)
	elif t == 170:
		_check(g.shield.global_position.y < 0.3 and not g._pallet_fly, "E: the pallet landed on the floor (y %.2f)" % g.shield.global_position.y)
		_fight([[{"at": Vector3(sx + ThirdPersonController.AIM_SIDE, 0.0, -8.0), "yaw": PI * 0.5, "opts": {"ai": false, "kind": "shield"}}]])
		fight.start()
		g = fight.gunmen[0]
	elif t == 195:
		_check(not g.front_hit(player.global_position), "E: from his side the player is outside the pallet's cone")
		_fire_edge()
	elif t == 198:
		_check(is_equal_approx(g.hp, 35.0) and g.blocked_hits == 0 and g.has_shield(), "E: a flank round hurts (hp %.0f), the pallet stays" % g.hp)
		_fight([[{"at": Vector3(sx + ThirdPersonController.AIM_SIDE, 0.0, -3.0), "yaw": PI, "opts": {"ai": false, "kind": "shield"}}]])
		fight.start()
		g = fight.gunmen[0]
		dir.equip(WeaponData.Slot.SHOTGUN)
	elif t == 225:
		_fire_edge()
	elif t == 228:
		_check(not g.has_shield() and g.blocked_hits == 1, "E: one shotgun blast from 3 m knocks the pallet away (blocked %d)" % g.blocked_hits)
		dir.equip(WeaponData.Slot.PISTOL)
		dir.aim_override = false
		Difficulty.set_easy(true)
		_fight([[{"at": Vector3(sx, 0.0, -8.0), "yaw": PI, "opts": {"ai": false, "kind": "shield"}}]])
		fight.start()
		g = fight.gunmen[0]
		var from: Vector3 = player.global_position
		var r: Array[String] = []
		for i: int in 3:
			r.append(g.take_hit({"kind": "bullet", "from": from}))
		_check(r[0] == "none" and r[1] == "none" and r[2] == "stumble" and not g.has_shield(), "E Dễ: the 3rd hit knocks the pallet away (%s)" % str(r))
		Difficulty.set_easy(false)
		_fight([[{"at": Vector3(sx, 0.0, -8.0), "yaw": 0.0, "opts": {"ai": false, "kind": "shield"}}]])
		fight.start()
		g = fight.gunmen[0]
		for i2: int in 3:
			g.take_hit({"kind": "bullet", "from": from})
		_check(g.is_down() and not g.has_shield() and g.shield.top_level, "E: back hits knock him out and he drops the pallet")
	elif t == 320:
		_next("shieldwave")


## Part E: a live wave (two gunmen, one shield guard) against a good bot: steady aim (90 % hits on a clear line, one round
## per pistol cycle), a sprint round the shield guard while his pallet faces it.
func _ph_shieldwave(t: int) -> void:
	var sx: float = -900.0
	if t == 1:
		_fresh(Vector3(sx, 0.0, 0.0))
		lost_n = 0
		won_n = 0
		aux["bot_cd"] = 0.0
		aux["rng"] = RandomNumberGenerator.new()
		(aux["rng"] as RandomNumberGenerator).seed = 77
		_fight([[{"at": Vector3(sx - 6.0, 0.0, -14.0), "opts": {"alerted": true}}, {"at": Vector3(sx + 6.0, 0.0, -14.0), "opts": {"alerted": true}},
			{"at": Vector3(sx, 0.0, -16.0), "opts": {"alerted": true, "kind": "shield"}}]])
		fight.start()
	elif fight.state == "running" and t < 3600:
		var tgt: Gunman = null
		var best: float = INF
		for e: Variant in fight.alive():
			var gm: Gunman = e
			var dd: float = gm.global_position.distance_to(player.global_position) + (8.0 if gm.has_shield() else 0.0)
			if dd < best:
				best = dd
				tgt = gm
		player.input_override = null
		player.sprint_override = false
		if tgt == null:
			return
		var to: Vector3 = tgt.feet() - player.global_position
		player.yaw = atan2(-to.x, -to.z)
		if tgt.has_shield() and tgt.front_hit(player.global_position):
			player.input_override = Vector2(1.0, 0.0)
			player.sprint_override = true
		aux["bot_cd"] = float(aux["bot_cd"]) - 1.0 / 60.0
		if float(aux["bot_cd"]) <= 0.0:
			aux["bot_cd"] = float(WeaponData.SLOTS[WeaponData.Slot.PISTOL]["cycle"])
			var eye: Vector3 = player.global_position + Vector3(0.0, 1.3, 0.0)
			if fight.clear_line(eye, tgt.feet() + Vector3(0.0, 1.2 - tgt.drop, 0.0)) and (aux["rng"] as RandomNumberGenerator).randf() < 0.9:
				tgt.take_hit({"kind": "bullet", "from": player.global_position})
	elif not aux.has("sw_end"):
		aux["sw_end"] = t
		player.input_override = null
		player.sprint_override = false
		print("    shield wave: %s after %.1f s, losses %d, hp %.0f" % [fight.state, float(t) / 60.0, lost_n, combat.hp])
		_check(fight.state == "won" and lost_n == 0, "E: the good bot wins the wave with a shield guard without a loss (%s, %d)" % [fight.state, lost_n])
	elif t >= int(aux["sw_end"]) + 90:   # the last knockout's slow-motion orbit is over
		aux.erase("sw_end")
		aux["dpass"] = 0
		_next("diff")


## Part D: the gun difficulty row, pass 0 on Thường, pass 1 on Dễ.
func _ph_diff(t: int) -> void:
	var easy: bool = int(aux.get("dpass", 0)) == 1
	var tag: String = "Dễ" if easy else "Thường"
	var want_tele: int = 27 if easy else 21
	var want_cap: int = 3 if easy else 4
	var want_regen: float = 3.0 if easy else 7.0
	var rf: int = roundi(want_regen * 60.0)
	if t == 1:
		Difficulty.set_easy(easy)
		_check(is_equal_approx(GunData.telegraph_s(), 0.45 if easy else 0.35) and GunData.max_shooters() == want_cap
			and is_equal_approx(GunData.regen_delay(), want_regen) and is_equal_approx(GunData.accuracy_k(), 0.8 if easy else 2.0)
			and is_equal_approx(GunData.gunman_dmg(), 8.0 if easy else 16.0),
			"D %s: the gun row (telegraph %.2f, cap %d, regen %.0f, accuracy x%.1f, dmg %.0f)" % [tag, GunData.telegraph_s(),
			GunData.max_shooters(), GunData.regen_delay(), GunData.accuracy_k(), GunData.gunman_dmg()])
		_fresh(Vector3(1400.0, 0.0, 0.0), true)
		aux["tele_d"] = []
		aux["tele_f"] = -1
		_fight([[{"at": Vector3(1400.0, 0.0, -10.0), "opts": {"alerted": true}}]], {"accuracy_override": 0.0})
		fight.start()
		g = fight.gunmen[0]
		g.telegraph_started.connect(func(_x: Gunman) -> void: aux["tele_f"] = frames)
		g.shot.connect(func(_x: Gunman, _r: String) -> void:
			if int(aux["tele_f"]) >= 0:
				(aux["tele_d"] as Array).append(frames - int(aux["tele_f"])))
	elif t == 3:
		_check(fight.max_shooters == want_cap, "D %s: the fight's token cap is %d (%d)" % [tag, want_cap, fight.max_shooters])
		_check(is_equal_approx(combat.regen_delay, want_regen), "D %s: combat.regen_delay is %.0f s while engaged (%.1f)" % [tag, want_regen, combat.regen_delay])
		var dummies: Array[Node] = []
		var granted: int = 0
		for i: int in 6:
			var d := Node.new()
			dummies.append(d)
			if fight.request_token(d):
				granted += 1
		_check(granted == want_cap and fight.shooters() == want_cap, "D %s: %d tokens granted to 6 askers (%d)" % [tag, want_cap, granted])
		for d2: Node in dummies:
			fight.release_token(d2)
			d2.free()
	elif t == 360:
		var ds: Array = aux["tele_d"]
		var ok: bool = not ds.is_empty()
		for v: Variant in ds:
			if absi(int(v) - want_tele) > 1:
				ok = false
		print("    D %s: telegraph frames before each shot %s" % [tag, str(ds)])
		_check(ok, "D %s: every shot resolves %d frames after its glint (%s)" % [tag, want_tele, str(ds)])
		fight.stop()
		_check(is_equal_approx(combat.regen_delay, CombatData.REGEN_DELAY), "D %s: stop() restores the regen delay (%.1f)" % [tag, combat.regen_delay])
	elif t == 362:
		_fresh(Vector3(1400.0, 0.0, 0.0))
		_fight([[{"at": Vector3(1400.0, 0.0, -30.0), "opts": {"ai": false}}]])
		fight.start()
		g = fight.gunmen[0]
		aux["regen_f"] = -1
	elif t == 364:
		fight.hit_player(g, 8.0)
		aux["hit_f"] = frames
	elif t > 364 and t < 364 + rf + 40:
		if int(aux["regen_f"]) < 0 and combat.hp > 92.0:
			aux["regen_f"] = frames
	elif t == 364 + rf + 40:
		var df: int = int(aux["regen_f"]) - int(aux["hit_f"])
		_check(int(aux["regen_f"]) > 0 and absi(df - rf) <= 2, "D %s: regeneration starts %d frames after the hit (%d)" % [tag, rf, df])
		for i2: int in 3:
			g.take_hit({"kind": "bullet", "from": player.global_position})
	elif t == 364 + rf + 44:
		_check(fight.state == "won" and is_equal_approx(combat.regen_delay, CombatData.REGEN_DELAY), "D %s: won restores the regen delay (%s, %.1f)" % [tag, fight.state, combat.regen_delay])
		if not easy:
			aux["dpass"] = 1
			_next("diff")
	elif t == 364 + rf + 44 + 90:   # Dễ: the last knockout's slow-motion orbit is over
		Difficulty.set_easy(false)
		_next("done")


func _report() -> void:
	if fight and is_instance_valid(fight):
		fight.stop()
	_check(arena.find_children("*", "GPUParticles3D", true, false).is_empty(), "no GPUParticles3D")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is 1.0")
	Difficulty.set_easy(false)
	if fails.is_empty():
		print("✅ SUCCESS: GUNFIGHT (cover, gunmen, telegraph, walls, shooter cap, HP, retry, ammo, KO, forklift boss, difficulty row)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
