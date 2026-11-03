# File: res://scripts/combat/guns/ForkliftBoss.gd
# The Day 3 boss Alexander ABCXYZ on his forklift (spec C-D4). GunFight spawns it from a wave entry {"boss": "forklift"}
# (or: var b := ForkliftBoss.new(); b.setup(opts); parent.add_child(b); b.set_yaw(y); b.bind(fight)).
# States:
#   IDLE         drives to keep 8-13 m from the player, facing him; every 1.0-1.8 s picks the next attack (ai);
#   CHARGE_TELL  the telegraph (1.0 s, 0.8 s in phase 2): turns to the player, forks down, red beacon, horn, revving, tyre
#                smoke, "Xe nâng lao tới!";
#   CHARGE       full throttle along the locked direction (11 m/s, 13 in phase 2) for up to 2.4 s; the player within
#                CHARGE_HIT_R of the chassis-to-fork-tips line, with a clear line from the chassis front to him (the
#                forks have no collision: cover or a wall between stops the hit), takes a heavy hit (charge_dmg(), knock-down) once
#                per charge; a crash is handled before any hit test;
#   RECOVER      after a crash into the level or a miss (recover_s(): 3.2 / 1.8 s; the joust 3.4 / 2.4, Dễ 4.0 / 3.0):
#                stalled, Alexander dizzy with stars: VULNERABLE;
#   LIFT         stops and raises the forks with a crate (0.9 s);
#   TOSS         flings the crate (two in phase 2) in an arc onto where the player stands: a dark shadow on the landing spot
#                grows for CRATE_FLIGHT_S (1.2 s) before it lands; within CRATE_R of the landing = a heavy hit (crate_dmg());
#   OVERHEAT     the heat meter (+34 per charge, +18 per toss) reached 100: steam and smoke 4.5 s: VULNERABLE, damage x1.5;
#   NAME         after his HP first falls under 66 % and 33 % (at most NAME_MAX = 2 times, when no vulnerable window is
#                open): he stands on the seat and restates his endless name (subtitles, party horn) for 3.2 s, invulnerable,
#                and NAME_REFILL (10 %) of his bar refills meanwhile (never above full);
#   TOPPLE       HP 0: the forklift tips over away from the player (Forklift.topple) with him on it; then KO: he lies beside
#                it with stars (no blood); is_defeated() -> GunFight counts the wave beaten;
#   HOLD         ai off ({"ai": false}: the villain card, a cinematic, tests): sits still until activate() (starts the AI
#                loop) or force_attack() (one attack, then back to HOLD); STAND: the fight was lost.
# W3 D3W-3 joust (plan 2026-10-30-w3-day3.md T7): forks_up() = the ram window (LIFT: the forks go up before a toss, a
# yellow beacon and a creak; lift_s()); ram_open() = forks up, or stalled (RECOVER / OVERHEAT) and not rammed in that
# stall yet (T9);
# take_ram(dir, speed) from the player's forklift: from the side or the back at >= RAM_MIN_SPEED while ram_open() =
# RAM_FRAC of the bar (Impact heavy, sparks, he spins out into RECOVER, no second ram in that stall), a front
# ram = both bounce ("front": the caller hurts the player); his tossed crates stay crate_dwell s on the floor
# (floor_crates, take_floor_crate) and one thrown back hurts him (take_crate_hit: CRATE_BACK_FRAC while stalled or from
# the side); crush() = a crane drop on him while stalled skips to the next phase. Telegraphs through Difficulty (tell_s).
# Hits on the player come from the forklift body (its position: the damage arc, the knock-down direction).
# Bullets (and melee) reach him through the driver target (hit_node(), a capsule over the seat; the chassis and the mast
# rails are world geometry and stop shots): outside the vulnerable windows he only clangs ("Không xi nhê!").
# GunHUD shows the boss bar from display_name(), hp / max_hp, status_text() and is_naming().
class_name ForkliftBoss
extends Node3D

signal phase_changed(old_state: String, new_state: String)
signal charge_started(dir: Vector3)
signal crashed
signal crate_tossed(target: Vector3)
signal crate_landed(pos: Vector3, hit_player: bool)
signal vulnerable_changed(on: bool)
signal name_intro(count: int)
signal hp_changed(hp: float, max_hp: float)
signal toppled
signal ko(boss: ForkliftBoss)

enum St { IDLE, CHARGE_TELL, CHARGE, RECOVER, LIFT, TOSS, OVERHEAT, NAME, TOPPLE, KO, HOLD, STAND }
const ST_NAMES: Array[String] = ["idle", "charge_tell", "charge", "recover", "lift", "toss", "overheat", "name", "topple",
	"ko", "hold", "stand_down"]
const PATTERN: Array[String] = ["charge", "toss", "charge", "charge", "toss"]
const SIT_H: float = 0.47
const LOG_MAX: int = 48
const RAM_MIN_SPEED: float = 4.0
const RAM_FRAC: float = 0.15
const CRATE_BACK_FRAC: float = 0.08
const SIDE_DOT: float = 0.5          # |dot(ram dir, his forward)| below this = a side hit; a ram along his forward = the back
const SPIN_S: float = 0.6

## The capsule bullets test (WeaponDirector duck type): forwards hits to the boss.
class DriverTarget extends Node3D:
	var boss: ForkliftBoss

	func take_hit(info: Dictionary) -> String:
		return boss.take_driver_hit(info)

	func is_down() -> bool:
		return boss.st == ForkliftBoss.St.KO or boss.st == ForkliftBoss.St.TOPPLE


var fight: Object = null
var forklift: Forklift
var driver: Node3D
var pose: GunPose
var target: DriverTarget
var ai: bool = true
var hp: float = GunData.BOSS_HP
var max_hp: float = GunData.BOSS_HP
var heat: float = 0.0
var st: int = St.HOLD
var st_t: float = 0.0
var st_len: float = 0.0
var state_log: Array[String] = []
var name_intros: int = 0
var charges: int = 0
var tosses: int = 0
var charge_hits: int = 0
var crate_hits: int = 0
var immune_hits: int = 0
var _names_due: int = 0
var _name_used: Array[bool] = []
var _name_from: float = 0.0
var _pattern_i: int = 0
var _think: float = 1.0
var _charge_dir: Vector3 = Vector3.FORWARD
var _charge_hit: bool = false
var _crashed_now: bool = false
var _flying: Array[Dictionary] = []      # {"node", "shadow", "from", "to", "t"}
var _fx_acc: float = 0.0
var _immune_cd: float = 0.0
var _name_line: int = -1
var _rng := RandomNumberGenerator.new()
## T7: the joust.
var crate_dwell: float = 8.0
var floor_crates: Array[Dictionary] = []   # {"node", "t"}: tossed crates lying on the floor
var rams: int = 0
var crate_backs: int = 0
var crushes: int = 0
var _spin_t: float = -1.0
var _stall_rammed: bool = false
## T9: the joust's numbers (MissionForklift passes opt "joust"): longer stalls and forks-up window, harder hits on
## Thường; without it the GunData numbers (the plain boss fight, test_gunfight).
var joust: bool = false
## A side / back ram's share of his bar (opt "ram_frac", default RAM_FRAC; w5-day7: the tower's warehouse, no crane there).
var ram_frac: float = RAM_FRAC
var _spin_dir: float = 1.0


## opts: "hp", "body" (CharacterBuilder opts over GunData.ALEX_LOOK), "body_fn" (Callable(look) -> rigged Node3D),
## "ai" (false = HOLD until force_attack), "seed", "ram_frac" (a ram's share of the bar, default RAM_FRAC). Builds the
## forklift and Alexander (before add_child).
func setup(opts: Dictionary = {}) -> void:
	_rng.seed = int(opts.get("seed", 3))
	max_hp = float(opts.get("hp", GunData.BOSS_HP))
	hp = max_hp
	ai = bool(opts.get("ai", true))
	crate_dwell = float(opts.get("crate_dwell", Difficulty.pick(8.0, 10.0)))
	joust = bool(opts.get("joust", false))
	ram_frac = float(opts.get("ram_frac", RAM_FRAC))
	for i: int in GunData.NAME_AT.size():
		_name_used.append(false)
	forklift = Forklift.new()
	forklift.name = "Forklift"
	add_child(forklift)
	var look: Dictionary = GunData.ALEX_LOOK.duplicate()
	var bo: Dictionary = opts.get("body", {})
	for k: String in bo.keys():
		look[k] = bo[k]
	look["rigged"] = true
	look["name"] = "Alexander"
	var bf: Callable = opts.get("body_fn", Callable())
	driver = bf.call(look) if bf.is_valid() else CharacterBuilder.build(look)
	driver.name = "Alexander"
	target = DriverTarget.new()
	target.name = "DriverTarget"
	target.boss = self
	GunAudio.warm()


func _ready() -> void:
	forklift.visual.add_child(driver)
	driver.position = Vector3(0.0, Forklift.SEAT_Y - SIT_H, Forklift.SEAT_Z)
	pose = GunPose.attach(driver)
	forklift.add_child(target)
	target.position = Vector3(0.0, 0.3, Forklift.SEAT_Z)
	_sit()


func bind(f: Object) -> void:
	fight = f
	var pl: Node = f.get("player")
	if pl is PhysicsBody3D:
		forklift.add_collision_exception_with(pl)
	forklift.floor_y = forklift.global_position.y
	_think = _rng.randf_range(GunData.THINK.x, GunData.THINK.y)
	_enter(St.IDLE if ai else St.HOLD)


func set_yaw(y: float) -> void:
	forklift.rotation.y = y


func state_name() -> String:
	return ST_NAMES[st]


func hit_node() -> Node3D:
	return target


func vulnerable() -> bool:
	return st == St.RECOVER or st == St.OVERHEAT


func is_defeated() -> bool:
	return st == St.KO


func is_hostile() -> bool:
	return st != St.KO and st != St.STAND


func is_down() -> bool:
	return st == St.KO or st == St.TOPPLE


func is_naming() -> bool:
	return st == St.NAME


func phase2() -> bool:
	return hp < max_hp * GunData.PHASE2_AT


func display_name() -> String:
	return GunData.ALEX_FULL


## The ram window: his forks go up before a toss.
func forks_up() -> bool:
	return st == St.LIFT


## A side / back ram counts now: his forks are up (LIFT), or he is stalled (RECOVER "SƠ HỞ!" after a missed charge or a
## crash, OVERHEAT "QUÁ NHIỆT!") and has not been rammed in this stall yet (T9: the stall is the window a player reads
## first; one ram per stall).
func ram_open() -> bool:
	return st == St.LIFT or (vulnerable() and not _stall_rammed)


## The charge telegraph (Dễ +0.3 s).
func tell_s() -> float:
	return float(GunData.CHARGE_TELL_S2 if phase2() else GunData.CHARGE_TELL_S) + float(Difficulty.pick(0.0, 0.3))


## The forks-up window before a toss (0.8 s, Dễ 1.1). T9, the joust (opt "joust"): the sloppy bot could not reach 0.8 s
## from the 8-13 m he keeps (a turn and 6 m of acceleration take about 1.2 s): 1.2 s on Thường, 1.5 s on Dễ.
func lift_s() -> float:
	if joust:
		return float(Difficulty.pick(1.2, 1.5))
	return float(Difficulty.pick(0.8, 1.1))


## His hits on the player (heavy, a knock-down): GunData's 25 / 30. T9, the joust: those never got through the
## regeneration of a sloppy player who dodged most attacks; Thường hits harder, Dễ softer.
func charge_dmg() -> float:
	if joust:
		return float(Difficulty.pick(GunData.CHARGE_DMG * 1.5, GunData.CHARGE_DMG * 0.85))
	return GunData.CHARGE_DMG


func crate_dmg() -> float:
	if joust:
		return float(Difficulty.pick(GunData.CRATE_DMG * 1.4, GunData.CRATE_DMG * 0.85))
	return GunData.CRATE_DMG


## How long he stays stalled (RECOVER, the "SƠ HỞ!" window for a ram or the guns) after a miss / a spin-out or a crash:
## GunData's 1.8 / 3.2 s; T9, the joust: those left the sloppy bot no time to drive round to his side.
func recover_s(crash: bool) -> float:
	if not joust:
		return GunData.CRASH_RECOVER_S if crash else GunData.MISS_RECOVER_S
	return float(Difficulty.pick(3.4, 4.0)) if crash else float(Difficulty.pick(2.4, 3.0))


func stalled() -> bool:
	return vulnerable()


## Charging and his charge has already hit the player this time (the player's forklift does not hit twice).
func charge_hit_now() -> bool:
	return st == St.CHARGE and _charge_hit


func mark_charge_hit() -> void:
	_charge_hit = true


## Where a ram from `dir` lands on his forklift: "front" | "side" | "back".
func ram_side(dir: Vector3) -> String:
	var f: Vector3 = forklift.forward()
	var d: float = WeaponMath.flat_dir(dir).dot(f)
	if d <= -SIDE_DOT:
		return "front"
	if d >= SIDE_DOT:
		return "back"
	return "side"


## The player's forklift rams him along `dir` at `speed`: "front" (both bounce; the caller hurts the player), "hit" (side
## or back while his forks are up, fast enough: RAM_FRAC of the bar, he spins out into RECOVER), "bump" (no damage) or
## "none" (down / standing down).
func take_ram(dir: Vector3, speed: float) -> String:
	if st == St.KO or st == St.TOPPLE or st == St.STAND or st == St.NAME:
		return "none"
	var side: String = ram_side(dir)
	if side == "front":
		forklift.speed = 0.0
		if fight:
			fight.call("play_cue", "impact_heavy", forklift.global_position + Vector3(0.0, 1.0, 0.0), 0.0)
		return "front"
	if speed < RAM_MIN_SPEED or not ram_open():
		if fight:
			fight.call("play_cue", "helmet_clonk", forklift.global_position + Vector3(0.0, 1.0, 0.0), -4.0)
		return "bump"
	rams += 1
	forklift.release_crate()
	forklift.lift_to(0.15)
	Impact.hit(self, "heavy", {"pos": forklift.global_position + Vector3(0.0, 1.0, 0.0), "dir": WeaponMath.flat_dir(dir)})
	Impact.particles(self, "sparks", forklift.global_position + Vector3(0.0, 1.0, 0.0), WeaponMath.flat_dir(dir), 1.2)
	_spin_t = 0.0
	_spin_dir = 1.0 if WeaponMath.flat_dir(dir).cross(forklift.forward()).y > 0.0 else -1.0
	st_len = recover_s(false)
	_enter(St.RECOVER)
	_stall_rammed = true     # one ram per stall: no stun-lock
	apply_damage(max_hp * float(Difficulty.pick(ram_frac, ram_frac * 1.2)))
	return "hit"


## A crate thrown back by the player's forklift lands on him from `dir`: "hit" (stalled or from the side) or "bump".
func take_crate_hit(dir: Vector3) -> String:
	if st == St.KO or st == St.TOPPLE or st == St.STAND:
		return "none"
	if not (vulnerable() or ram_side(dir) != "front"):
		_immune_feedback()
		return "bump"
	crate_backs += 1
	Impact.hit(self, "heavy", {"pos": forklift.global_position + Vector3(0.0, 1.4, 0.0), "dir": WeaponMath.flat_dir(dir)})
	apply_damage(max_hp * float(Difficulty.pick(CRATE_BACK_FRAC, CRATE_BACK_FRAC * 1.25)))
	return "hit"


## A crane drop on him: while stalled it skips to the next phase (phase 1 -> phase 2; phase 2 -> 10 % left). false when
## he is not stalled (the container just bounces off a moving forklift).
func crush() -> bool:
	if not vulnerable():
		return false
	crushes += 1
	var goal: float = max_hp * GunData.PHASE2_AT - 1.0 if not phase2() else max_hp * 0.1
	Impact.hit(self, "finisher", {"pos": forklift.global_position + Vector3(0.0, 1.5, 0.0), "dir": Vector3.DOWN})
	if hp > goal:
		apply_damage(hp - goal)
	return true


## A tossed crate lying within r of p (the player's fork tips): taken off the floor list and returned (null = none).
func take_floor_crate(p: Vector3, r: float) -> Node3D:
	for i: int in floor_crates.size():
		var c: Node3D = floor_crates[i]["node"]
		if is_instance_valid(c) and WeaponMath.flat(c.global_position, p) <= r:
			floor_crates.remove_at(i)
			return c
	return null


func status_text() -> String:
	match st:
		St.RECOVER:
			return GunData.T_VULN
		St.OVERHEAT:
			return GunData.T_OVERHEAT
	return ""


## Leave HOLD and run the AI loop (IDLE: drive, think, attack pattern).
func activate() -> void:
	ai = true
	if st == St.HOLD:
		_think = _rng.randf_range(GunData.THINK.x, GunData.THINK.y)
		_enter(St.IDLE)


## Start an attack now ("charge" | "toss"), from IDLE or HOLD (tests, scripted beats).
func force_attack(kind: String) -> void:
	if st != St.IDLE and st != St.HOLD:
		return
	if kind == "toss":
		_enter(St.LIFT)
	else:
		_enter(St.CHARGE_TELL)


func stand_down() -> void:
	if st == St.KO or st == St.TOPPLE:
		return
	_clear_crates()
	_enter(St.STAND)


# ---------------------------------------------------------------------------
# HITS
# ---------------------------------------------------------------------------
func take_driver_hit(info: Dictionary) -> String:
	if st == St.KO or st == St.TOPPLE or st == St.STAND:
		return "none"
	var kind: String = String(info.get("kind", ""))
	if not GunData.BOSS_DMG_TAKEN.has(kind):
		return "none"
	if not vulnerable():
		_immune_feedback()
		return "blocked"
	var dmg: float = float(GunData.BOSS_DMG_TAKEN[kind]) * (GunData.OVERHEAT_DMG_K if st == St.OVERHEAT else 1.0)
	apply_damage(dmg)
	if fight:
		fight.call("play_cue", "impact_medium", target.global_position + Vector3(0.0, 1.0, 0.0), -2.0)
	return "hit"


## Damage on the boss bar (thresholds for the name intro, topple at 0).
func apply_damage(dmg: float) -> void:
	if st == St.KO or st == St.TOPPLE or dmg <= 0.0:
		return
	var before: float = hp / max_hp
	hp = maxf(0.0, hp - dmg)
	var after: float = hp / max_hp
	for i: int in GunData.NAME_AT.size():
		if not _name_used[i] and before > GunData.NAME_AT[i] and after <= GunData.NAME_AT[i]:
			_name_used[i] = true
			if name_intros + _names_due < GunData.NAME_MAX:
				_names_due += 1
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_start_topple()


func _immune_feedback() -> void:
	immune_hits += 1
	if _immune_cd > 0.0 or fight == null:
		return
	_immune_cd = GunData.IMMUNE_TOAST_S
	var chest: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
	fight.call("play_cue", "helmet_clonk", chest, -2.0)
	var fx: WeaponFX = fight.get("fx")
	if fx:
		fx.burst("sparks", chest, Vector3.UP, 0.3)
	var hud: GunHUD = fight.get("hud")
	if hud:
		hud.toast(GunData.T_IMMUNE)


# ---------------------------------------------------------------------------
# FRAME
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if fight == null:
		return
	st_t += delta
	_immune_cd = maxf(0.0, _immune_cd - delta)
	_tick_crates(delta)
	if _spin_t >= 0.0:
		_spin_t += delta
		forklift.rotation.y += _spin_dir * TAU * 1.2 * delta * (1.0 - clampf(_spin_t / SPIN_S, 0.0, 1.0))
		if _spin_t >= SPIN_S:
			_spin_t = -1.0
	match st:
		St.IDLE:
			_do_idle(delta)
		St.HOLD, St.STAND, St.KO:
			forklift.drive(0.0, 0.0, 0.0)
			if st == St.HOLD and _names_due > 0 and name_intros < GunData.NAME_MAX:
				_names_due -= 1
				_enter(St.NAME)
		St.CHARGE_TELL:
			_do_tell(delta)
		St.CHARGE:
			_do_charge()
		St.RECOVER:
			forklift.drive(0.0, 0.0, 0.0)
			if st_t >= st_len:
				_after_window()
		St.LIFT:
			forklift.drive(0.0, 0.0, 0.0)
			_face_player(delta, 2.0)
			if st_t >= lift_s():
				_toss()
		St.TOSS:
			forklift.drive(0.0, 0.0, 0.0)
			if _flying.is_empty() and st_t >= 0.3:
				forklift.lift_to(0.15)
				_back_to_idle()
		St.OVERHEAT:
			forklift.drive(0.0, 0.0, 0.0)
			_fx_acc += delta
			if _fx_acc >= 0.3:
				_fx_acc = 0.0
				var fx: WeaponFX = fight.get("fx")
				if fx:
					fx.burst("dust", forklift.global_transform * Vector3(0.0, 1.0, 1.3), Vector3.UP, 0.5)
			if st_t >= GunData.OVERHEAT_S:
				heat = 0.0
				_after_window()
		St.NAME:
			forklift.drive(0.0, 0.0, 0.0)
			var k: float = clampf(st_t / GunData.NAME_S, 0.0, 1.0)
			var want: float = minf(max_hp, _name_from + max_hp * GunData.NAME_REFILL * k)
			if want > hp:
				hp = want
				hp_changed.emit(hp, max_hp)
			_name_lines()
			if st_t >= GunData.NAME_S:
				_sit()
				_back_to_idle()


func _enter(s: int) -> void:
	var old: String = ST_NAMES[st]
	var was_vuln: bool = vulnerable()
	st = s
	st_t = 0.0
	_fx_acc = 0.0
	if s != St.RECOVER and s != St.OVERHEAT:
		_stall_rammed = false
	state_log.append(ST_NAMES[s])
	if state_log.size() > LOG_MAX:
		state_log.pop_front()
	var now_vuln: bool = vulnerable()
	forklift.beacon_mode = "amber"
	match s:
		St.CHARGE_TELL:
			forklift.beacon_mode = "red"
			forklift.lift_to(0.25)
			fight.call("play_cue", "forklift_horn", forklift.global_position + Vector3(0.0, 1.5, 0.0), 2.0)
			fight.call("play_cue", "engine_roar", forklift.global_position, 0.0)
			var hud: GunHUD = fight.get("hud")
			if hud:
				hud.toast(GunData.T_CHARGE)
		St.RECOVER, St.OVERHEAT:
			forklift.beacon_mode = "off"
			pose.set_pose("stunned", 0.9)
			var fx: WeaponFX = fight.get("fx")
			if fx:
				fx.stars(driver, st_len if s == St.RECOVER else GunData.OVERHEAT_S)
			var hud2: GunHUD = fight.get("hud")
			if hud2:
				hud2.popup(GunData.T_OVERHEAT if s == St.OVERHEAT else GunData.T_VULN, CombatHUD.GOLD)
			if s == St.OVERHEAT:
				fight.call("play_cue", "steam_hiss", forklift.global_position + Vector3(0.0, 1.0, 1.2), 0.0)
		St.LIFT:
			var c: Node3D = GunProps.crate(0.8)
			forklift.carry(c)
			forklift.lift_to(2.3)
			forklift.beacon_mode = "yellow"   # the ram window
			fight.call("play_cue", "forklift_lift", forklift.global_position, -2.0)
			YardSfx.play3d(self, "creak", forklift.global_position + Vector3(0.0, 2.0, -1.0), 0.0)
		St.NAME:
			_stand_up()
			_name_from = hp
			name_intros += 1
			fight.call("play_cue", "party_horn", driver.global_position + Vector3(0.0, 1.8, 0.0), 0.0)
			_name_line = -1
			_name_lines()
			name_intro.emit(name_intros)
		St.TOPPLE, St.KO, St.STAND:
			forklift.beacon_mode = "off"
		St.IDLE, St.HOLD:
			if pose.pose_name == "stunned":
				_sit()
	if was_vuln != now_vuln:
		vulnerable_changed.emit(now_vuln)
	phase_changed.emit(old, ST_NAMES[s])


func _back_to_idle() -> void:
	if _names_due > 0 and name_intros < GunData.NAME_MAX:
		_names_due -= 1
		_enter(St.NAME)
		return
	_names_due = 0 if name_intros >= GunData.NAME_MAX else _names_due
	if heat >= 100.0:
		_enter(St.OVERHEAT)
		return
	_think = _rng.randf_range(GunData.THINK.x, GunData.THINK.y) * (float(Difficulty.pick(0.6, 0.8)) if phase2() else 1.0)
	_enter(St.IDLE if ai else St.HOLD)


## A vulnerable window ended: a due name intro first, then overheat / idle.
func _after_window() -> void:
	_back_to_idle()


func _do_idle(delta: float) -> void:
	var pp: Vector3 = fight.call("player_feet")
	var to: Vector3 = pp - forklift.global_position
	var d: float = Vector2(to.x, to.z).length()
	var steer: float = _steer_to(to)
	var th: float = 0.0
	if d > GunData.IDLE_DIST.y:
		th = 0.7
	elif d < GunData.IDLE_DIST.x:
		th = -0.5
	forklift.drive(th, steer, GunData.IDLE_SPEED)
	if absf(th) < 0.01:
		_face_player(delta, 1.2)
	if _names_due > 0 and name_intros < GunData.NAME_MAX:
		_names_due -= 1
		_enter(St.NAME)
		return
	_think -= delta
	if _think <= 0.0:
		var kind: String = PATTERN[_pattern_i % PATTERN.size()]
		_pattern_i += 1
		force_attack(kind)


func _do_tell(delta: float) -> void:
	forklift.drive(0.0, 0.0, 0.0)
	_face_player(delta, 3.5)
	_fx_acc += delta
	if _fx_acc >= 0.12:
		_fx_acc = 0.0
		var fx: WeaponFX = fight.get("fx")
		if fx:
			fx.burst("dust", forklift.global_transform * Vector3(0.0, 0.2, 0.9), Vector3.UP, 0.25)
	if st_t >= tell_s():
		_charge_dir = forklift.forward()
		_charge_hit = false
		_crashed_now = false
		charges += 1
		heat += GunData.HEAT_CHARGE
		if not forklift.crashed.is_connected(_on_crash):
			forklift.crashed.connect(_on_crash)
		_enter(St.CHARGE)
		charge_started.emit(_charge_dir)


func _do_charge() -> void:
	if _crashed_now:
		_crashed_now = false
		st_len = recover_s(true)
		fight.call("play_cue", "impact_heavy", forklift.global_position + _charge_dir * 2.0 + Vector3(0.0, 1.0, 0.0), 4.0)
		var fx: WeaponFX = fight.get("fx")
		if fx:
			fx.burst("dust", forklift.global_position + _charge_dir * 2.0 + Vector3(0.0, 0.8, 0.0), -_charge_dir, 0.8)
			fx.burst("sparks", forklift.global_position + _charge_dir * 2.0 + Vector3(0.0, 1.0, 0.0), -_charge_dir, 0.6)
		var pl2: Node3D = fight.get("player")
		if pl2 and pl2.has_method("shake") and pl2.global_position.distance_to(forklift.global_position) < 20.0:
			pl2.call("shake", 0.5)
		crashed.emit()
		_enter(St.RECOVER)
		return
	if st_t >= GunData.CHARGE_MAX_S:
		st_len = recover_s(false)
		_enter(St.RECOVER)
		return
	forklift.drive(1.0, 0.0, GunData.CHARGE_SPEED2 if phase2() else GunData.CHARGE_SPEED, true)
	if not _charge_hit:
		var pl: Node3D = fight.get("player")
		if pl and _near_segment(pl.global_position) and _charge_line_clear():
			_charge_hit = true
			if String(fight.call("hit_player", forklift, charge_dmg(), true)) == "hit":
				charge_hits += 1


## Nothing between the chassis front (above the chassis, between the mast rails) and the player's target point: a box he
## crouches behind or a wall stops the charge hit even when the collision-free forks poke through it.
func _charge_line_clear() -> bool:
	var front: Vector3 = forklift.global_transform * Vector3(0.0, 1.0, -1.15)
	return bool(fight.call("clear_line", front, fight.call("player_target")))


func _on_crash(_speed: float) -> void:
	if st == St.CHARGE:
		_crashed_now = true


## The player's feet within CHARGE_HIT_R of the chassis-to-fork-tips line (flat), at about the same height.
func _near_segment(p: Vector3) -> bool:
	var a: Vector3 = forklift.global_position
	var b: Vector3 = forklift.global_transform * Vector3(0.0, 0.0, Forklift.FORK_TIP_Z)
	if absf(p.y - a.y) > 1.5:
		return false
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return (ap - ab * t).length() <= GunData.CHARGE_HIT_R


func _steer_to(to: Vector3) -> float:
	var want: float = atan2(-to.x, -to.z)
	return clampf(wrapf(want - forklift.rotation.y, -PI, PI) * 2.0, -1.0, 1.0)


func _face_player(delta: float, rate: float) -> void:
	var pp: Vector3 = fight.call("player_feet")
	var to: Vector3 = pp - forklift.global_position
	if Vector2(to.x, to.z).length_squared() < 0.01:
		return
	var want: float = atan2(-to.x, -to.z)
	forklift.rotation.y += clampf(wrapf(want - forklift.rotation.y, -PI, PI), -rate * delta, rate * delta)


# ---------------------------------------------------------------------------
# CRATES
# ---------------------------------------------------------------------------
func _toss() -> void:
	var pp: Vector3 = fight.call("player_feet")
	var targets: Array[Vector3] = [pp]
	if phase2():
		var side: Vector3 = WeaponMath.flat_dir(pp - forklift.global_position).cross(Vector3.UP).normalized()
		targets.append(pp + side * GunData.CRATE_SPREAD * (1.0 if _rng.randf() < 0.5 else -1.0))
	var first: Node3D = forklift.release_crate(self)
	for i: int in targets.size():
		var c: Node3D = first if i == 0 and first != null else GunProps.crate(0.8)
		if c.get_parent() == null:
			add_child(c)
			c.global_position = forklift.fork_tips() + Vector3(0.0, 0.1, 0.0)
		var sh: MeshInstance3D = GunProps.shadow_disc()
		add_child(sh)
		sh.global_position = targets[i] + Vector3(0.0, 0.03, 0.0)
		sh.scale = Vector3(0.3, 1.0, 0.3)
		_flying.append({"node": c, "shadow": sh, "from": c.global_position, "to": targets[i], "t": 0.0})
		crate_tossed.emit(targets[i])
	tosses += 1
	heat += GunData.HEAT_TOSS
	fight.call("play_cue", "forklift_lift", forklift.global_position, 0.0)
	_enter(St.TOSS)


func _tick_crates(delta: float) -> void:
	for j: int in range(floor_crates.size() - 1, -1, -1):
		var fc: Dictionary = floor_crates[j]
		fc["t"] = float(fc["t"]) + delta
		if float(fc["t"]) >= crate_dwell or not is_instance_valid(fc["node"]):
			if is_instance_valid(fc["node"]):
				(fc["node"] as Node).queue_free()
			floor_crates.remove_at(j)
	for i: int in range(_flying.size() - 1, -1, -1):
		var e: Dictionary = _flying[i]
		var c: Node3D = e["node"]
		var sh: MeshInstance3D = e["shadow"]
		var t: float = float(e["t"]) + delta
		e["t"] = t
		var u: float = clampf(t / GunData.CRATE_FLIGHT_S, 0.0, 1.0)
		var from: Vector3 = e["from"]
		var to: Vector3 = e["to"]
		if is_instance_valid(c):
			c.global_position = from.lerp(to, u) + Vector3(0.0, 4.0 * GunData.CRATE_PEAK * u * (1.0 - u), 0.0)
			c.rotation.x = u * 5.0
		if is_instance_valid(sh):
			var r: float = lerpf(0.3, GunData.CRATE_R, u)
			sh.scale = Vector3(r, 1.0, r)
			(sh.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.15, 0.6, u)
		if u >= 1.0:
			_land(c, to)
			if is_instance_valid(sh):
				sh.queue_free()
			_flying.remove_at(i)


## The shadow fraction (0..1) of the crate in flight closest to landing (tests: the shadow shows before the landing).
func shadow_progress() -> float:
	var best: float = -1.0
	for e: Dictionary in _flying:
		best = maxf(best, float(e["t"]) / GunData.CRATE_FLIGHT_S)
	return best


func crates_in_flight() -> int:
	return _flying.size()


func _land(c: Node3D, at: Vector3) -> void:
	var hit: bool = false
	var pl: Node3D = fight.get("player") if fight else null
	if pl and WeaponMath.flat(pl.global_position, at) <= GunData.CRATE_R and absf(pl.global_position.y - at.y) < 2.0:
		if String(fight.call("hit_player", forklift, crate_dmg(), true)) == "hit":
			hit = true
			crate_hits += 1
	if fight:
		fight.call("play_cue", "crate_smash", at + Vector3(0.0, 0.5, 0.0), 3.0)
		var fx: WeaponFX = fight.get("fx")
		if fx:
			fx.burst("dust", at + Vector3(0.0, 0.3, 0.0), Vector3.UP, 0.8)
			fx.burst("debris", at + Vector3(0.0, 0.4, 0.0), Vector3.UP, 0.7)
	if is_instance_valid(c):
		c.global_position = Vector3(at.x, forklift.floor_y, at.z)   # T7: it stays on the floor crate_dwell s (lift it, throw it back)
		c.rotation = Vector3(0.0, c.rotation.y, 0.0)
		floor_crates.append({"node": c, "t": 0.0})
	crate_landed.emit(at, hit)


func _clear_crates() -> void:
	for e: Dictionary in _flying:
		if is_instance_valid(e["node"]):
			(e["node"] as Node).queue_free()
		if is_instance_valid(e["shadow"]):
			(e["shadow"] as Node).queue_free()
	_flying.clear()
	for fc: Dictionary in floor_crates:
		if is_instance_valid(fc["node"]):
			(fc["node"] as Node).queue_free()
	floor_crates.clear()
	forklift.release_crate()


# ---------------------------------------------------------------------------
# ALEXANDER
# ---------------------------------------------------------------------------
## The name intro's subtitle lines (GunData.ALEX_INTRO at NAME_LINE_AT seconds).
func _name_lines() -> void:
	var want: int = -1
	for i: int in GunData.NAME_LINE_AT.size():
		if st_t >= GunData.NAME_LINE_AT[i]:
			want = i
	if want == _name_line or want < 0:
		return
	_name_line = want
	var hud: GunHUD = fight.get("hud") if fight else null
	if hud:
		var until: float = GunData.NAME_LINE_AT[want + 1] if want + 1 < GunData.NAME_LINE_AT.size() else GunData.NAME_S
		hud.subtitle(GunData.ALEX_INTRO[want], until - GunData.NAME_LINE_AT[want] + 0.1)


func _sit() -> void:
	driver.position = Vector3(0.0, Forklift.SEAT_Y - SIT_H, Forklift.SEAT_Z)
	target.position = Vector3(0.0, 0.3, Forklift.SEAT_Z)
	CharacterBuilder.set_base_clip(driver, "sit")
	CharacterBuilder.play(driver, "sit")
	pose.set_pose("drive")


func _stand_up() -> void:
	driver.position = Vector3(0.0, Forklift.SEAT_Y, Forklift.SEAT_Z)
	target.position = Vector3(0.0, Forklift.SEAT_Y, Forklift.SEAT_Z)
	CharacterBuilder.set_base_clip(driver, "")
	CharacterBuilder.stop_clip(driver)
	pose.set_pose("name_speech")


func _start_topple() -> void:
	_clear_crates()
	_names_due = 0
	var pp: Vector3 = fight.call("player_feet") if fight else forklift.global_position
	var right: Vector3 = forklift.global_basis.x
	var side: float = -1.0 if (pp - forklift.global_position).dot(right) > 0.0 else 1.0   # away from the player
	forklift.topple(side)
	if not forklift.toppled.is_connected(_on_toppled):
		forklift.toppled.connect(_on_toppled)
	if fight:
		fight.call("play_cue", "forklift_horn", forklift.global_position + Vector3(0.0, 1.5, 0.0), 0.0)
	_enter(St.TOPPLE)


## The forklift lies on its side: Alexander tumbles out beside it, knocked out with stars.
func _on_toppled() -> void:
	var side: float = forklift._topple_side
	var at: Vector3 = forklift.global_transform * Vector3(side * 1.9, 0.0, Forklift.SEAT_Z)
	var xf: float = forklift.rotation.y
	driver.get_parent().remove_child(driver)
	add_child(driver)
	driver.global_position = Vector3(at.x, forklift.floor_y, at.z)
	driver.rotation = Vector3(0.0, xf + PI * 0.5 * side, 0.0)
	pose.reset()
	CharacterBuilder.set_base_clip(driver, "")
	CharacterBuilder.play(driver, "knockdown")
	if fight:
		fight.call("play_cue", "impact_heavy", forklift.global_position, 6.0)
		fight.call("play_cue", "body_fall", driver.global_position, 0.0)
		var fx: WeaponFX = fight.get("fx")
		if fx:
			fx.burst("dust", forklift.global_position + Vector3(0.0, 0.5, 0.0), Vector3.UP, 1.2)
			fx.stars(driver, 8.0)
		var pl: Node3D = fight.get("player")
		if pl and pl.has_method("shake"):
			pl.call("shake", 0.6)
	toppled.emit()
	_enter(St.KO)
	ko.emit(self)
