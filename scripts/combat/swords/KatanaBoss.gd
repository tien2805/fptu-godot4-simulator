# File: res://scripts/combat/swords/KatanaBoss.gd
# Lê Minh Za Mẫn, the Day 5 katana boss (spec C-D3 / C-D4), a MeleeEnemy: the Phase B AI moves him (approach, circle,
# attack tokens, block / side-step, stagger, daze, knockdown, KO) and this class replaces his attacks with patterns of
# katana steps (SwordData.STEPS / PATTERNS):
#   - every step is told by a glint on the blade + a sound exactly SwordData.TELL_S (0.5 s) before its hit (`tells` log);
#     white glint = a slash (block it, or parry: a block pressed within 0.2 s of the hit staggers him PARRY_STUN s), red
#     glint + red flash = lunge or spin, unblockable (dodge it);
#   - his wind-ups and swings are armoured (hits hurt but do not interrupt; a parry or a full stagger meter does);
#   - phases at 66 % and 33 % HP (SwordData.PHASES): faster movement and follow-through, shorter gaps and recovery, a new
#     pattern (spin, then frenzy); a phase change jumps back into a taunt with a startup line; `phase_changed(phase)`;
#   - the katana "bought online" (KatanaProp) bends one stage at 75 / 50 / 25 % HP and wobbles on every hit; at 0 HP the
#     FINALE: it snaps (slow motion), he stares at the stump with a line, then the knockout (stars) after FINALE_S, and
#     only then `ko` (MeleeFight counts the win).
# Spawned by SwordDuel through MeleeFight (spawn key "make"). opts as MeleeEnemy ("body", "body_fn", "label", "stats",
# "seed", "hp_scale", "ai"); stats are SwordData.ZA_MAN with the caller's "stats" over them (those keys then stay fixed
# through the phases). Tests / scripted beats: force_pattern(name) (a pattern or a single step name), force_attack().
# W3 T6: with qte_armed (SwordDuel) 0 HP does not start the finale at once: he holds at 0 HP, frozen and invulnerable
# (staged, St.IDLE), and emits `qte_reached` (qte_ready() is true); qte_pass() then plays the snap finale, qte_recover(frac)
# gives him frac of his HP back and the duel goes on (the QTE comes again at the next 0).
class_name KatanaBoss
extends MeleeEnemy

signal phase_changed(phase: int)
## W3 T5 / T6: his HP fraction after any damage (the sprinklers at 50 %), and 0 HP reached while a QTE is armed.
signal hp_changed(frac: float)
signal qte_reached

const LOG_MAX: int = 32

var katana: KatanaProp
var grip: Node3D
var phase: int = 1
var pattern_name: String = ""
var step: Dictionary = {}
var step_name: String = ""
## Logs (last LOG_MAX): tells {"t", "step", "red"} (game time of the glint), hit_log {"t", "step", "result"}.
var tells: Array[Dictionary] = []
var hit_log: Array[Dictionary] = []
## Patterns started (last LOG_MAX; tests).
var pattern_log: Array[String] = []
var parries: int = 0
var finales: int = 0
var lunge_from: Vector3 = Vector3.ZERO
var _pattern: Array = []
var _step: int = 0
var _glint_at: float = 0.0
var _glinted: bool = false
var _gap: float = 0.3
var _speed_k: float = 1.0
var _base_speed: float = 4.0
var _base_circle: float = 1.5
var _fixed: Dictionary = {}
var _last_pattern: String = ""
var _dash_dir: Vector3 = Vector3.ZERO
var _dash_v: float = 0.0
var _finale_away: Vector3 = Vector3.ZERO
var _finale_done: bool = false
## W3 T5: the sprinklers' wet floor makes his lunges overshoot (1.2); 1.0 dry.
var lunge_k: float = 1.0
## W3 T6: the QTE finisher (armed by SwordDuel), passed once the finale may run.
var qte_armed: bool = false
var qte_passed: bool = false
var _qte_wait: bool = false
var _qte_away: Vector3 = Vector3.ZERO
var _finale_line: bool = false


func setup(_arch: String, opts: Dictionary = {}) -> void:
	var o: Dictionary = opts.duplicate()
	var st0: Dictionary = SwordData.ZA_MAN.duplicate(true)
	_fixed = opts.get("stats", {})
	for k: String in _fixed.keys():
		st0[k] = _fixed[k]
	o["stats"] = st0
	if not o.has("label"):
		o["label"] = SwordData.T_BOSS
	super.setup("clone", o)
	archetype_id = "za_man"
	guard_pose = "sw_kat_guard"
	block_pose = "sw_kat_block"
	_base_speed = float(stats["speed"])
	_base_circle = float(stats["circle_speed"])
	_marks = PackedFloat32Array([float(SwordData.PHASES[1]["at"]), float(SwordData.PHASES[2]["at"])])
	katana = KatanaProp.create()
	grip = SwordProps.attach_to_hand(body, katana, SwordData.KATANA_TILT)
	_apply_phase(1)


## The patterns of the current phase.
func patterns() -> Array:
	return SwordData.PHASES[phase - 1]["patterns"]


func _apply_phase(ph: int) -> void:
	phase = clampi(ph, 1, SwordData.PHASES.size())
	var d: Dictionary = SwordData.PHASES[phase - 1]
	_speed_k = float(d["speed_k"])
	_gap = float(d["gap"])
	var vals: Dictionary = {"speed": _base_speed * _speed_k, "circle_speed": _base_circle * _speed_k, "recover": float(d["recover"]),
		"cooldown": d["cooldown"], "block_chance": float(d["block_chance"])}
	for k: String in vals.keys():
		if not _fixed.has(k):
			stats[k] = vals[k]


func _dist_to_player() -> float:
	if combat == null or combat.player == null:
		return 99.0
	return WeaponMath.flat(combat.player.global_position, global_position)


func _set_pattern(pname: String) -> void:
	pattern_name = pname
	if SwordData.PATTERNS.has(pname):
		_pattern = SwordData.PATTERNS[pname]
	elif SwordData.STEPS.has(pname):
		_pattern = [pname]
	else:
		pattern_name = "slash_r"
		_pattern = ["slash_r"]


## A pattern of the phase for this distance: no lunge when close, not the same pattern twice in a row.
func _plan_pattern(dist: float) -> void:
	var pool: Array = patterns()
	var pick: String = ""
	for i: int in 6:
		var c: String = String(pool[_rng.randi() % pool.size()])
		if c == _last_pattern and pool.size() > 1:
			continue
		if c == "lunge" and dist < SwordData.LUNGE_MIN_M:
			continue
		pick = c
		break
	if pick == "":
		pick = "lunge" if dist >= SwordData.LUNGE_MIN_M and pool.has("lunge") else String(pool[0])
	_set_pattern(pick)


## Tests / scripted beats: start a pattern (or a single step) now, without a token.
func force_pattern(pname: String) -> void:
	if not is_hostile() or st == St.DAZE or st == St.KNOCKDOWN or st == St.HELD or st == St.HOWL:
		return
	_forced = true
	_set_pattern(pname)
	_step = 0
	_begin_attack()


## MeleeEnemy's hook: "light" = one slash, "heavy" = the lunge, "combo" = chain3.
func force_attack(kind: String) -> void:
	force_pattern("lunge" if kind == "heavy" else ("chain3" if kind == "combo" else "slash_r"))


# ---------------------------------------------------------------------------
# MeleeEnemy overrides
# ---------------------------------------------------------------------------
func _enter(s: int, length: float = 0.0) -> void:
	super._enter(s, length)
	if s != St.WINDUP and s != St.ATTACK:
		if katana and katana.glint_on:
			katana.set_glint(false)
		if s != St.ENGAGE:
			_pattern = []
	if s == St.ENGAGE and not _forced:
		var d: float = _dist_to_player()
		_plan_pattern(d)
		if String(_pattern[0]) == "lunge" and d >= SwordData.LUNGE_MIN_M - 0.2:
			_step = 0
			_begin_attack()                      # the lunge starts from range


func _choose_attack() -> void:
	if _pattern.is_empty():
		_plan_pattern(_dist_to_player())
	_step = 0
	_begin_attack()


## A step's wind-up: the chain gap (in guard), then the glint + sound, TELL_S before the hit.
func _begin_attack() -> void:
	_blocked = false
	step_name = String(_pattern[_step])
	step = SwordData.STEPS[step_name]
	attack_kind = "heavy" if bool(step["unblockable"]) else "light"
	var gap: float = 0.0 if _step == 0 else _gap
	if _step == 0:
		pattern_log.append(pattern_name)
		if pattern_log.size() > LOG_MAX:
			pattern_log.pop_front()
	_glint_at = gap
	_glinted = false
	_enter(St.WINDUP, gap + SwordData.tell_s() - float(step["hit"]))
	if gap <= 0.0:
		_do_glint()
	else:
		pose.set_pose(guard_pose)


func _do_glint() -> void:
	_glinted = true
	var red: bool = bool(step["unblockable"])
	katana.set_glint(true, red)
	pose.set_pose(String(step["wind"]))
	if red:
		_set_flash(true)
	tells.append({"t": _t, "step": step_name, "red": red})
	if tells.size() > LOG_MAX:
		tells.pop_front()
	if combat:
		combat._cue("glint_red" if red else "glint", katana.glint.global_position if katana.is_inside_tree() else global_position, -2.0)


func _start_attack() -> void:
	var p: Node3D = combat.player if combat else null
	_enter(St.ATTACK)
	hit_done = false
	var hit: float = float(step["hit"])
	st_len = hit + (float(step["dur"]) - hit) / _speed_k
	_hit_t = hit
	if bool(step["unblockable"]):
		_set_flash(true)
	if String(step["clip"]) != "":
		CombatData.play_clip(body, String(step["clip"]), st_len, float(step["from"]), float(step["hit_at"]), hit)
	else:
		CharacterBuilder.stop_clip(body)        # the code pose alone carries a lunge / spin
	pose.set_pose(String(step["pose"]), 0.0, st_len)
	if p:
		var d := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
		if d.length() > 0.05:
			set_yaw(atan2(-d.x, -d.z))
		match String(step["kind"]):
			"slash":
				var gap: float = d.length() - float(step["reach"]) + 0.2
				if gap > 0.05:
					push_v = facing_dir() * minf(sqrt(2.0 * PUSH_DECEL * minf(gap, 0.9)), 4.5)
			"lunge":                             # dash so that his reach meets the player at the hit frame
				_dash_dir = facing_dir()
				_dash_v = clampf((d.length() - float(step["reach"]) + 0.15) / hit * lunge_k, 0.0, float(step["dash_max"]) * lunge_k)
				lunge_from = global_position
	if combat:
		combat._cue("katana_slash", global_position + Vector3(0.0, 1.3, 0.0), -4.0)


func _physics_process(delta: float) -> void:
	if st == St.ATTACK and not step.is_empty():
		match String(step["kind"]):
			"lunge":
				if not hit_done and st_t + delta <= float(step["hit"]) + 1e-4:
					push_v = _dash_dir * _dash_v
			"spin":
				set_yaw(wrapf(yaw + float(step["turns"]) * TAU / maxf(st_len, 0.1) * delta, -PI, PI))
	super._physics_process(delta)
	match st:
		St.WINDUP:
			if not _glinted and st_t >= _glint_at - 1e-5:
				_do_glint()
		St.FINALE:
			_finale_tick()


## The player within the step's reach (+0.45 m) and arc, nothing solid between.
func _in_reach() -> bool:
	var p: Node3D = combat.player if combat else null
	if p == null:
		return false
	var d := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
	var l: float = d.length()
	if l > float(step["reach"]) + 0.45:
		return false
	var half: float = float(step["half_deg"])
	if half < 179.0 and l >= 0.05 and facing_dir().dot(d / l) < cos(deg_to_rad(half)):
		return false
	return _clear_to(p)


## The hit of a step: through PlayerCombat.receive_attack (unblockable = "heavy": goes through the block).
func _strike() -> void:
	hit_done = true
	_set_flash(false)
	katana.set_glint(false)
	attacks += 1
	if String(step.get("kind", "")) == "lunge":
		push_v = _dash_dir * minf(_dash_v, 1.5)  # the dash stops at the hit: a short follow-through slide
	var r: String = "miss"
	var p: Node3D = combat.player if combat else null
	if p and _in_reach():
		r = combat.receive_attack(self, {"damage": float(step["dmg"]), "heavy": bool(step["unblockable"]), "kind": String(step["kind"])})
	results.append(r)
	if results.size() > 32:
		results.pop_front()
	hit_log.append({"t": _t, "step": step_name, "result": r})
	if hit_log.size() > LOG_MAX:
		hit_log.pop_front()
	if st != St.ATTACK:
		return                                   # parried: staggered now
	match r:
		"blocked":
			_blocked = true
			katana.wobble(0.15)
		"hit":
			if fx and p:
				var at: Vector3 = p.global_position + Vector3(0.0, 1.2, 0.0)
				fx.burst("dust", at, Vector3.UP, 0.3)
				fx.burst("sparks", at, facing_dir(), 0.15)
		"miss", "dodged":
			if combat:
				combat._cue("katana_slash", global_position + Vector3(0.0, 1.2, 0.0), -8.0)


func _after_attack() -> void:
	_step += 1
	if _step < _pattern.size():
		_begin_attack()
		return
	_last_pattern = pattern_name
	_release_token()
	_enter(St.RECOVER, float(stats["recover"]) + (CombatData.BLOCKED_RECOVER_ADD if _blocked else 0.0))


func incoming() -> int:
	if (st == St.WINDUP and _glinted) or (st == St.ATTACK and not hit_done):
		return 2 if bool(step.get("unblockable", false)) else 1
	return 0


## Wind-ups and swings are armoured (the parry and the stagger meter still get through).
func _armored() -> bool:
	return st == St.WINDUP or (st == St.ATTACK and not hit_done)


func take_strike(info: Dictionary) -> String:
	var kind: String = String(info.get("kind", ""))
	if (kind == String(SwordData.STAFF_PARRY["id"]) or kind == "counter") and is_hostile() and st != St.KNOCKDOWN and st != St.HELD \
			and st != St.DODGE:
		return _parried(info)
	var hp0: float = hp
	var r: String = super.take_strike(info)
	if r == "blocked" and katana:
		katana.wobble(0.1)
	if hp < hp0:
		_on_damage(r)
	return r


func take_finisher(kind: String, from: Vector3) -> String:
	var hp0: float = hp
	var r: String = super.take_finisher(kind, from)
	if hp < hp0:
		_on_damage(r)
	return r


## Q2: Za Mẫn is never grabbed for a throw (a katana boss in a hip throw breaks his phases and the finale).
func can_be_thrown() -> bool:
	return false


## Q2: a slam into a wall bends the katana and moves the phases like any other damage.
func _on_env_damage(r: String) -> void:
	_on_damage(r)


## A perfect block's riposte: the pattern is dropped, damage, a long stagger, the katana rings and wobbles.
func _parried(info: Dictionary) -> String:
	parries += 1
	_release_token()
	katana.set_glint(false)
	_set_flash(false)
	_last_hit_t = _t
	var from: Vector3 = info.get("from", global_position - facing_dir())
	var away: Vector3 = WeaponMath.flat_dir(global_position - from)
	hp -= float(info.get("dmg", 8.0))
	push_v = away * sqrt(2.0 * PUSH_DECEL * float(info.get("push", 0.6)))
	var r0: String = _after_damage(away)
	if r0 != "":
		_on_damage(r0)
		return r0
	stagger = minf(stagger_max - 1.0, stagger + float(info.get("stagger", 40.0)))
	_stagger_for(float(info.get("stun", SwordData.PARRY_STUN)))
	katana.wobble(0.35)
	if fx and katana.is_inside_tree():
		fx.burst("sparks", katana.glint.global_position, Vector3.UP, 0.45)
	_on_damage("parried")
	return "parried"


## After any damage: the katana wobbles and bends a stage further at its thresholds; the phase goes up at 66 / 33 %.
func _on_damage(r: String) -> void:
	if katana == null or katana.broken:
		return
	katana.wobble(0.2)
	var frac: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	hp_changed.emit(frac)
	var s: int = SwordData.bend_stage_of(frac)
	if s > katana.stage and hp > 0.0:
		katana.set_stage(s)
		if combat:
			combat._cue("katana_boing", global_position + Vector3(0.0, 1.4, 0.0), -2.0)
			if combat.hud:
				combat.hud.popup(SwordData.T_BEND[s], CombatHUD.WARN)
	var ph: int = SwordData.phase_of(frac)
	if ph > phase and hp > 0.0:
		_apply_phase(ph)
		if combat and combat.hud:
			combat.hud.popup(SwordData.T_PHASE[ph], CombatHUD.WARN)
		if st == St.STAGGER and r != "parried":
			_phase_taunt()
		phase_changed.emit(phase)


## A phase change: a hop back and a taunt (guarded, PHASE_TAUNT_S).
func _phase_taunt() -> void:
	_release_token()
	if combat and combat.player:
		push_v = WeaponMath.flat_dir(global_position - combat.player.global_position) * sqrt(2.0 * PUSH_DECEL * 1.2)
	_enter(St.BLOCK, SwordData.PHASE_TAUNT_S)
	pose.set_pose("sw_kat_taunt", 0.8)


func _knock_out(away: Vector3) -> void:
	if _finale_done:
		super._knock_out(away)
		return
	if qte_armed and not qte_passed:
		_qte_hold(away)
		return
	_start_finale(away)


## At 0 HP waiting for the QTE (SwordDuel runs it).
func qte_ready() -> bool:
	return _qte_wait


## 0 HP with the QTE armed: he freezes, invulnerable, until qte_pass() or qte_recover().
func _qte_hold(away: Vector3) -> void:
	_qte_wait = true
	_qte_away = away
	hp = 0.0
	_release_token()
	if katana:
		katana.set_glint(false)
	_set_flash(false)
	push_v = Vector3.ZERO
	staged = true
	_enter(St.IDLE)
	pose.set_pose("sw_kat_guard", 0.15)
	qte_reached.emit()


## The QTE was passed: the katana snaps (the existing finale), the knockout follows.
func qte_pass() -> void:
	if not _qte_wait:
		return
	_qte_wait = false
	qte_passed = true
	staged = false
	_start_finale(_qte_away)


## The QTE was missed: frac of his HP back, the duel goes on.
func qte_recover(frac: float) -> void:
	if not _qte_wait:
		return
	_qte_wait = false
	staged = false
	hp = max_hp * clampf(frac, 0.01, 1.0)
	_enter(St.APPROACH if ai else St.HOLD)


## 0 HP: the katana snaps (slow motion, sparks, the snap cue), the stare; the knockout comes FINALE_S later.
func _start_finale(away: Vector3) -> void:
	finales += 1
	_release_token()
	hp = 0.0
	_finale_away = away
	_finale_line = false
	_enter(St.FINALE)
	push_v = away * 1.5
	CharacterBuilder.stop_clip(body)
	pose.set_pose("sw_kat_stare", 0.9)
	katana.snap(global_position.y, away)
	if combat:
		var at: Vector3 = katana.segs[KatanaProp.BREAK_AT - 1].global_position if katana.is_inside_tree() else global_position + Vector3(0.0, 1.4, 0.0)
		combat._cue("katana_snap", at, 2.0)
		if fx:
			fx.burst("sparks", at, Vector3.UP, 0.8)
		combat._slowmo()


func _finale_tick() -> void:
	if not _finale_line and st_t >= 0.35:
		_finale_line = true
		if combat and combat.hud:
			combat.hud.popup(SwordData.T_BREAK, CombatHUD.GOLD)
	if st_t >= SwordData.FINALE_S:
		_finale_done = true
		_knock_out(_finale_away)


func stand_down() -> void:
	if katana:
		katana.set_glint(false)
	super.stand_down()
