# File: res://scripts/combat/swords/SwordDuel.gd
# Encounter node of the Phase C sword duel (spec C-D3 / C-D4 Day 5): the player's Vovinam staff against Lê Minh Za Mẫn's
# katana. Built on the Phase B combat: one MeleeFight (checkpoint, retry, lost / won, force unarmed, the [F] / [P] / [B]
# refusals, the HUD) with a single KatanaBoss, and the player's PlayerCombat switched to the staff move set.
#
# ===== API (for the story integration) =====
#   var duel := SwordDuel.new()
#   roam.add_child(duel)                        # any Node3D parent; FreeRoam is the usual one
#   duel.setup({"roam": roam,                   # FreeRoam (player, combat, weapons read from it), or "player"
#                                               #   (ThirdPersonController) [+ "combat", "weapons"]; without a combat one is built
#       "at": Vector3(...),                     # Za Mẫn's spot (default: 5 m in front of the player)
#       "yaw": 0.0,                             # optional (default: faces the player)
#       "boss": {"label": "Lê Minh Za Mẫn",     # KatanaBoss opts (MeleeEnemy opts): "body" (CharacterBuilder opts over his
#                "body_fn": Callable(look) -> rigged Node3D,   #   default look), "body_fn" (StoryCast look), "stats"
#                "stats": {...}, "hp_scale": 1.0},             #   (SwordData.ZA_MAN overrides), "seed", "ai"
#       "start_line": "",                       # centre popup at start() ("" = none)
#       "seed": 5})
#   duel.prepare()                              # optional: Za Mẫn appears now (villain card), standing in his guard,
#                                               #   invulnerable, until start()
#   duel.won.connect(...)                       # the katana snapped and he is knocked out (after the comic finale); the
#                                               #   staff is put away and the unarmed moves are back at that moment
#   duel.lost.connect(...)                      # the player's HP reached 0 (show "TOANG!", then call retry())
#   duel.phase_changed.connect(func(phase: int): ...)   # 2 at 66 % HP, 3 at 33 %
#   duel.start()
#   duel.retry()                                # a fresh Za Mẫn (phase 1, straight katana), HP 100, the player back at the
#                                               #   start spot
#   duel.stop()                                 # end without a result: boss freed, unarmed moves and wheel back
#   duel.state                                  # "idle" | "running" | "won" | "lost"; duel.phase (1..3); duel.boss
# The staff (and the staff move set: LMB 3 slashes, RMB thrust, hold Q block, perfect block = parry, Space dodge within
# 14 m, E finisher on a dazed Za Mẫn) is in the player's hand from start() / retry() until `won`, stop() or freeing the
# duel (the knocked-out boss stays until stop() or free).
# The boss bar shows while the duel runs. The duel never changes the story state, the time of day or the camera; it never
# references an autoload.
# W3 T5 (plan 2026-10-30-w3-day5.md, D5W-3): at SPRINKLE_AT (50 %) boss HP the sprinklers start once per run: a 0.6 s
# preview cut on the ceiling heads, water from SPRINKLER_N pooled emitters, steam where it meets the burning racks (opts
# "steam_at"), glossy puddles (PUDDLES round the arena centre), the "server_sprinkler" look on opts "look_host" (its
# look() / unlook() when it has them, else LookPresets on it), the synthesized rain loop (SwordAudio "rain"). On a puddle
# the player's dodge slides wet_slide (Thường 35 %, Dễ 45 %) further: slide_k, written to PlayerCombat.dodge_speed_k when
# it exists (the shared stream's knob, guarded); his lunges overshoot 20 % (KatanaBoss.lunge_k). retry(), the win, stop()
# and freeing put everything back (sprinklers off, slide 1.0, the look popped).
# ===========================================
class_name SwordDuel
extends Node3D

signal won
signal lost
signal phase_changed(phase: int)
signal sprinklers_started

const SPRINKLE_AT: float = 0.5
const SPRINKLER_N: int = 6
## Puddles round the arena centre: [offset, radius].
const PUDDLES: Array = [[Vector3(0.0, 0.0, 0.0), 1.3], [Vector3(-1.9, 0.0, 1.3), 1.0], [Vector3(1.7, 0.0, -1.1), 1.1],
	[Vector3(-0.9, 0.0, -2.3), 0.9], [Vector3(2.3, 0.0, 1.9), 1.0], [Vector3(-2.6, 0.0, -0.6), 0.9]]
const CEIL_Y: float = 3.25
const CUT_S: float = 0.6
const LUNGE_WET: float = 1.2
const WET_DT: float = 0.1
const LOOK: String = "server_sprinkler"
const T_SPRINKLERS: String = "Hệ thống phun nước bật! Sàn trơn!"

var fight: MeleeFight
var combat: PlayerCombat
var player: ThirdPersonController
var boss: KatanaBoss = null
var phase: int = 1
var state: String = "idle"
var staff: Node3D = null
var _staff_pivot: Node3D = null
var _armed: bool = false
## T5 the sprinklers
var sprinklers_on: bool = false
var sprinkler_starts: int = 0
var slide_k: float = 1.0
var wet_slide: float = 1.35
var cuts: int = 0
var centre: Vector3 = Vector3.ZERO
var look_host: Node = null
var emitters: Array[CPUParticles3D] = []
var steam: Array[CPUParticles3D] = []
var puddles: Array[MeshInstance3D] = []
var heads: Node3D = null
var _rain: AudioStreamPlayer = null
var _wet_acc: float = 0.0
var _looked: bool = false


func setup(opts: Dictionary) -> void:
	fight = MeleeFight.new()
	fight.name = "DuelFight"
	add_child(fight)
	var fo: Dictionary = {"force_unarmed": true, "max_attackers": 1, "auto_checkpoint": true,
		"start_line": String(opts.get("start_line", "")), "seed": int(opts.get("seed", 5))}
	for k: String in ["roam", "player", "combat", "weapons"]:
		if opts.has(k):
			fo[k] = opts[k]
	fight.setup(fo)
	combat = fight.combat
	player = fight.player
	SwordAudio.warm()
	var at: Vector3 = opts.get("at", player.global_position + player.facing_dir() * 5.0 if player else Vector3.ZERO)
	var spawn: Dictionary = {"archetype": "za_man", "make": func() -> MeleeEnemy: return KatanaBoss.new(), "at": at,
		"opts": (opts.get("boss", {}) as Dictionary).duplicate()}
	if opts.has("yaw"):
		spawn["yaw"] = float(opts["yaw"])
	fight.add_wave([spawn])
	fight.wave_started.connect(_on_wave)
	fight.won.connect(_on_won)
	fight.lost.connect(_on_lost)
	wet_slide = float(Difficulty.pick(1.35, 1.45))
	var p0: Vector3 = player.global_position if player else at
	centre = Vector3((at.x + p0.x) * 0.5, p0.y, (at.z + p0.z) * 0.5)
	look_host = opts.get("look_host", opts.get("roam", null))
	_build_sprinklers(opts.get("steam_at", []))


## Spawn Za Mẫn before the fight (a villain card can frame him): he stands in his guard, invulnerable, until start().
func prepare() -> void:
	if fight == null or combat == null or state == "running":
		return
	fight.prepare()


func start() -> void:
	if fight == null or combat == null:
		push_warning("SwordDuel.start: setup() first")
		return
	_arm(true)
	state = "running"
	fight.start()


## After `lost` (or any time): a fresh boss, the player back at the start spot with full HP.
func retry() -> void:
	if fight == null:
		return
	_sprinklers(false)
	sprinkler_starts = 0                      # once per run
	_arm(true)
	state = "running"
	fight.retry()


## End without a result: the boss freed, the unarmed move set, the wheel and the HUD back to normal.
func stop() -> void:
	_sprinklers(false)
	if fight:
		fight.stop()
	state = "idle"
	boss = null
	phase = 1
	_arm(false)


func _on_wave(_i: int) -> void:
	boss = fight.enemies[0] as KatanaBoss if not fight.enemies.is_empty() else null
	phase = 1
	if boss:
		boss.phase_changed.connect(_on_phase)
		boss.hp_changed.connect(_on_hp)


func _on_phase(ph: int) -> void:
	phase = ph
	phase_changed.emit(ph)


func _on_won() -> void:
	_sprinklers(false)
	state = "won"
	_arm(false)                                  # the staff goes away with the win: nothing left glued to the hand
	won.emit()


func _on_lost() -> void:
	state = "lost"
	lost.emit()


## The staff move set and the staff in the right hand (on), or the unarmed set and no staff (off).
func _arm(on: bool) -> void:
	if combat == null or not is_instance_valid(combat):
		return
	if on and not _armed:
		combat.set_moveset(SwordData.STAFF)
		if player and player.model:
			staff = SwordProps.staff()
			_staff_pivot = SwordProps.attach_to_hand(player.model, staff, SwordData.STAFF_TILT)
		_armed = true
	elif not on and _armed:
		combat.reset_moveset()
		SwordProps.detach(_staff_pivot)
		_staff_pivot = null
		staff = null
		_armed = false


func _exit_tree() -> void:
	_sprinklers(false)
	_arm(false)


# ---------------------------------------------------------------------------
# T5: the sprinklers
# ---------------------------------------------------------------------------
func _on_hp(frac: float) -> void:
	if frac <= SPRINKLE_AT and not sprinklers_on and state == "running" and sprinkler_starts == 0:
		_sprinklers(true)


## The sprinklers on (the cut, water, steam, puddles, the look, the rain, the wet lunges) or off (all restored).
func _sprinklers(on: bool) -> void:
	if on == sprinklers_on:
		if not on:
			_set_slide(1.0)
		return
	sprinklers_on = on
	for e: CPUParticles3D in emitters:
		e.emitting = on
	for st: CPUParticles3D in steam:
		st.emitting = on
	for pd: MeshInstance3D in puddles:
		pd.visible = on
	if boss and is_instance_valid(boss):
		boss.lunge_k = LUNGE_WET if on else 1.0
	_look(on)
	if on:
		sprinkler_starts += 1
		if _rain and is_inside_tree():
			_rain.stream = SwordAudio.stream("rain")
			_rain.play()
		if combat and combat.hud:
			combat.hud.popup(T_SPRINKLERS, CombatHUD.WARN)
		if heads and heads.is_inside_tree():
			cuts += 1
			var cd: CameraDirector = CameraDirector.live()
			if cd:
				cd.preview_cut(heads, CUT_S)
		sprinklers_started.emit()
	else:
		if _rain:
			_rain.stop()
		_set_slide(1.0)


func _look(on: bool) -> void:
	if look_host == null or not is_instance_valid(look_host) or on == _looked:
		return
	_looked = on
	if look_host.has_method("look"):
		look_host.call("look" if on else "unlook", LOOK)
	elif on:
		LookPresets.apply(LOOK, look_host)
	else:
		LookPresets.restore(look_host, LOOK)


## The dodge's slide factor (PlayerCombat.dodge_speed_k when the shared knob exists).
func _set_slide(k: float) -> void:
	slide_k = k
	if combat and is_instance_valid(combat) and "dodge_speed_k" in combat:
		combat.set("dodge_speed_k", k)


## On a puddle while the sprinklers run (10 Hz).
func _physics_process(delta: float) -> void:
	if not sprinklers_on or player == null:
		return
	_wet_acc += delta
	if _wet_acc < WET_DT:
		return
	_wet_acc = 0.0
	var wet: bool = false
	for pr: Array in PUDDLES:
		var c: Vector3 = centre + (pr[0] as Vector3)
		if Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length() <= float(pr[1]):
			wet = true
			break
	var k: float = wet_slide if wet else 1.0
	if not is_equal_approx(k, slide_k):
		_set_slide(k)


func _build_sprinklers(steam_at: Array) -> void:
	var root := Node3D.new()
	root.name = "Sprinklers"
	root.top_level = true
	add_child(root)
	root.global_position = Vector3.ZERO
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = Color(0.75, 0.88, 1.0, 0.5)
	wmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	wmat.set_meta("vice_done", true)
	var head_mat: StandardMaterial3D = CineFX._mat(Color("#B8BEC6"), 0.3)
	for i: int in mini(SPRINKLER_N, PUDDLES.size()):
		var at: Vector3 = centre + (PUDDLES[i][0] as Vector3) + Vector3(0.0, CEIL_Y, 0.0)
		CineFX._cyl(root, "SprinklerHead", 0.05, 0.08, 0.08, at + Vector3(0.0, 0.05, 0.0), head_mat)
		var e := CPUParticles3D.new()
		e.name = "Water"
		e.emitting = false
		e.amount = 36
		e.lifetime = 0.85
		e.local_coords = false
		e.direction = Vector3.DOWN
		e.spread = 28.0
		e.gravity = Vector3(0.0, -9.8, 0.0)
		e.initial_velocity_min = 0.8
		e.initial_velocity_max = 2.0
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 0.12
		e.scale_amount_min = 0.6
		e.scale_amount_max = 1.0
		var qm := QuadMesh.new()
		qm.size = Vector2(0.025, 0.22)
		qm.material = wmat
		e.mesh = qm
		root.add_child(e)
		e.global_position = at
		emitters.append(e)
	heads = Node3D.new()
	heads.name = "CeilingHeads"
	root.add_child(heads)
	heads.global_position = centre + Vector3(0.0, CEIL_Y - 0.4, 0.0)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.9, 0.9, 0.92, 0.22)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.set_meta("vice_done", true)
	for sp: Variant in steam_at:
		var st := CPUParticles3D.new()
		st.name = "Steam"
		st.emitting = false
		st.amount = 14
		st.lifetime = 2.0
		st.local_coords = false
		st.direction = Vector3.UP
		st.spread = 30.0
		st.gravity = Vector3(0.0, 0.8, 0.0)
		st.initial_velocity_min = 0.4
		st.initial_velocity_max = 1.0
		st.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		st.emission_sphere_radius = 0.5
		st.scale_amount_min = 1.0
		st.scale_amount_max = 2.0
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.8, 0.8)
		q2.material = smat
		st.mesh = q2
		root.add_child(st)
		st.global_position = (sp as Vector3) + Vector3(0.0, 0.8, 0.0)
		steam.append(st)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.1, 0.12, 0.16, 0.6)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.metallic = 0.3
	pmat.roughness = 0.04
	pmat.metallic_specular = 1.0
	pmat.set_meta("vice_done", true)
	for pr: Array in PUDDLES:
		var pd := MeshInstance3D.new()
		pd.name = "Puddle"
		var pm := PlaneMesh.new()
		var r: float = float(pr[1])
		pm.size = Vector2(r * 2.0, r * 1.7)
		pd.mesh = pm
		pd.material_override = pmat
		pd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pd.visible = false
		root.add_child(pd)
		pd.global_position = centre + (pr[0] as Vector3) + Vector3(0.0, 0.012, 0.0)
		puddles.append(pd)
	_rain = AudioStreamPlayer.new()
	_rain.name = "Rain"
	_rain.bus = CinePlayer._bus("SFX")
	_rain.volume_db = -13.0
	add_child(_rain)
