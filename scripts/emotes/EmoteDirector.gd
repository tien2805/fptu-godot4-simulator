# File: res://scripts/emotes/EmoteDirector.gd
# Phase W emotes (spec W-D10..W-D13, section 9). "Siuuu!" (3.30 s, times from the emote start, named constants below):
# run-up away from the camera to TAKEOFF (RUN_DIST through normal body collision: a wall stops the run), a jump of APEX
# with a 180° yaw turn while airborne, the landing at LAND facing the camera (wide stance, arms down and out, chest
# forward, dust, "SIUUU!" bubble, bystanders react), a hold to HOLD_END while the shout sustains, a blend back to idle by
# LENGTH. The shout (WeaponAudio.siuuu_stream: the owner's local file or the synthesized cue, same layout) starts at
# CUE_START = LAND - SIUUU_BURST so its vowel burst lands on the landing frame. Run, jump and turn cannot be cancelled;
# from CANCEL_FROM, movement input ends it. The equipped weapon is hidden meanwhile; no heat. While it plays the player's
# own physics is paused and this node moves the body (move_and_slide) and overlays code-built bone poses after the
# RigAnimator (process priority 20 > 10). It starts only once Engine.time_scale is back at 1.0 after the wheel closes.
# Bystanders (W-D13): pedestrians within REACT_R that are walking or standing react by share – clap, shout back (bubble +
# the cue quieter at a random pitch), film with a glowing phone, or look – then resume; officers and impostors ignore it.
# Refused while blocked_fn (riding, cinematic, replay, busted, service, map), aiming, firing, reloading, knocked down or with
# the weapon wheel open. Euler signs of the poses follow CharacterBuilder's code clips (cheer, lie, bow); tune them by eye
# when the owner play-tests. No real person's name, face or voice anywhere (W-D11).
class_name EmoteDirector
extends Node3D

signal started(emote_id: String)
signal landed(at_t: float)
signal finished(emote_id: String, cancelled: bool)

const EMOTES: Array[Dictionary] = [{"id": "siuuu", "name": "Siuuu!"}]
const TAKEOFF: float = 1.10
const LAND: float = 1.70
const HOLD_END: float = 2.96
const LENGTH: float = 3.30
const CANCEL_FROM: float = 2.20
const RUN_DIST: float = 4.5
const APEX: float = 0.55
const AIR_SPEED: float = 2.0
const CUE_START: float = 1.39            # LAND - WeaponAudio.SIUUU_BURST (checked by the test)
const REACT_R: float = 10.0
const SHARE_CLAP: float = 0.5
const SHARE_SHOUT: float = 0.25
const SHARE_FILM: float = 0.15
const BUBBLE_S: float = 1.6
const POSE_AIR: Dictionary = {
	"thigh_l": Vector3(0.9, 0.0, 0.12), "thigh_r": Vector3(0.9, 0.0, -0.12),
	"knee_l": Vector3(-1.2, 0.0, 0.0), "knee_r": Vector3(-1.2, 0.0, 0.0),
	"shoulder_l": Vector3(2.3, 0.0, 0.5), "shoulder_r": Vector3(2.3, 0.0, -0.5),
	"elbow_l": Vector3(0.4, 0.0, 0.0), "elbow_r": Vector3(0.4, 0.0, 0.0),
	"torso": Vector3(0.1, 0.0, 0.0), "head": Vector3(0.15, 0.0, 0.0), "hips_y": 0.0,
}
const POSE_LAND: Dictionary = {
	"thigh_l": Vector3(0.15, 0.0, 0.35), "thigh_r": Vector3(0.15, 0.0, -0.35),
	"knee_l": Vector3(-0.35, 0.0, 0.0), "knee_r": Vector3(-0.35, 0.0, 0.0),
	"shoulder_l": Vector3(-0.25, 0.0, 0.95), "shoulder_r": Vector3(-0.25, 0.0, -0.95),
	"elbow_l": Vector3(0.15, 0.0, 0.0), "elbow_r": Vector3(0.15, 0.0, 0.0),
	"torso": Vector3(0.22, 0.0, 0.0), "head": Vector3(0.12, 0.0, 0.0), "hips_y": -0.12,
}

var player: ThirdPersonController
var weapons: WeaponDirector
var wheel: EmoteWheel
var weapon_wheel: RadialWheel
var fx: WeaponFX
var targets_fn: Callable
var blocked_fn: Callable
var active: bool = false
var emote_id: String = ""
var pending: int = -1
var t: float = 0.0
var start_pos: Vector3 = Vector3.ZERO
var start_yaw: float = 0.0
var takeoff_pos: Vector3 = Vector3.ZERO
var landed_t: float = -1.0
var cue_t: float = -1.0
var ended_t: float = -1.0
var reactions: Dictionary = {}
var rng := RandomNumberGenerator.new()
var shout: AudioStreamPlayer
var bubble: Label3D
var _fwd: Vector3 = Vector3.FORWARD
var _took_off: bool = false
var _snap: float = 0.4
var _held_vis: bool = true
var _bubble_left: float = 0.0
var _extras: Array = []                  # [node, seconds left]: shout-back bubbles and voices


func _ready() -> void:
	process_priority = 20                # after the RigAnimator (10): the emote pose wins
	rng.seed = 2210
	shout = AudioStreamPlayer.new()
	shout.name = "Shout"
	shout.bus = WeaponAudio.bus()
	add_child(shout)
	bubble = _label("SIUUU!", 56)
	bubble.top_level = true
	add_child(bubble)


## opts: player, weapons (WeaponDirector), wheel (EmoteWheel), weapon_wheel (the other RadialWheel), targets_fn (-> Array),
## fx (WeaponFX), blocked_fn (-> bool: riding, cinematic, busted, service, map). Call after add_child.
func setup(opts: Dictionary) -> void:
	player = opts.get("player")
	weapons = opts.get("weapons")
	wheel = opts.get("wheel")
	weapon_wheel = opts.get("weapon_wheel")
	targets_fn = opts.get("targets_fn", Callable())
	fx = opts.get("fx")
	blocked_fn = opts.get("blocked_fn", Callable())
	if wheel:
		wheel.blocked_fn = is_blocked
		wheel.selected.connect(func(slot: int) -> void: play(slot))


func is_blocked() -> bool:
	if active or pending >= 0 or player == null or not player.visible:
		return true
	if blocked_fn.is_valid() and bool(blocked_fn.call()):
		return true
	if player.is_knocked_down() or (weapon_wheel and weapon_wheel.is_open()):
		return true
	return weapons != null and (weapons.aiming or weapons.reload_left > 0.0 or weapons.is_firing())


## Queue an emote (EMOTES index); it starts once the time scale is back at 1.0. false when refused.
func play(slot: int) -> bool:
	if slot < 0 or slot >= EMOTES.size() or is_blocked():
		return false
	pending = slot
	return true


static func pose_weight(at: float) -> float:
	return smoothstep(TAKEOFF - 0.05, TAKEOFF + 0.1, at) * (1.0 - smoothstep(HOLD_END, LENGTH, at))


## Code pose at emote time `at`: the tucked jump turning into the wide landing around LAND, the chest rising in the hold.
static func pose_at(at: float) -> Dictionary:
	var k: float = smoothstep(LAND - 0.04, LAND + 0.08, at)
	var out: Dictionary = {}
	for key: String in POSE_LAND.keys():
		if key == "hips_y":
			out[key] = lerpf(float(POSE_AIR[key]), float(POSE_LAND[key]), k)
		else:
			out[key] = (POSE_AIR[key] as Vector3).lerp(POSE_LAND[key], k)
	out["torso"] = (out["torso"] as Vector3) + Vector3(0.05 * smoothstep(LAND + 0.1, HOLD_END, at), 0.0, 0.0)
	return out


func _begin(slot: int) -> void:
	pending = -1
	active = true
	emote_id = String(EMOTES[slot]["id"])
	t = 0.0
	landed_t = -1.0
	cue_t = -1.0
	ended_t = -1.0
	_took_off = false
	reactions = {"clap": 0, "shout": 0, "film": 0, "look": 0}
	_fwd = WeaponMath.flat_dir(-player.camera.global_basis.z)
	start_yaw = atan2(-_fwd.x, -_fwd.z)
	player.model.rotation.y = start_yaw
	start_pos = player.global_position
	_snap = player.floor_snap_length
	player.set_physics_process(false)
	if weapons and weapons.held:
		_held_vis = weapons.held.visible
		weapons.held.visible = false
	started.emit(emote_id)


func _physics_process(delta: float) -> void:
	_tick_extras(delta)
	if pending >= 0 and not active:
		if Engine.time_scale >= 0.999:
			_begin(pending)
		return
	if not active:
		return
	if (blocked_fn.is_valid() and bool(blocked_fn.call())) or player.is_knocked_down():
		_end(true)                        # busted, a cinematic, a tackle...: stop at once
		return
	t += delta
	_move()
	if cue_t < 0.0 and t >= CUE_START - 1e-6:
		cue_t = t
		shout.stream = WeaponAudio.siuuu_stream()
		shout.play()
	if landed_t < 0.0 and t >= LAND - 1e-6:
		_land()
	if t >= CANCEL_FROM - 1e-6 and player._read_input().length_squared() > 0.01:
		_end(true)
		return
	if t >= LENGTH - 1e-6:
		_end(false)


## Body motion for emote time t: run-up, ballistic jump (apex APEX at mid-air, landing at LAND), then standing.
func _move() -> void:
	var air: float = LAND - TAKEOFF
	var g: float = 8.0 * APEX / (air * air)
	var v: Vector3
	if t < TAKEOFF:
		var sp: float = RUN_DIST / TAKEOFF
		v = Vector3(_fwd.x * sp, -2.0, _fwd.z * sp)
		player.floor_snap_length = _snap
		CharacterBuilder.set_speed(player.model, sp)
		CharacterBuilder.set_param(player.model, "run", 0.45)
	elif t < LAND:
		if not _took_off:
			_took_off = true
			takeoff_pos = player.global_position
		v = Vector3(_fwd.x * AIR_SPEED, g * air * 0.5 - g * (t - TAKEOFF), _fwd.z * AIR_SPEED)
		player.floor_snap_length = 0.0
		CharacterBuilder.set_speed(player.model, 0.0)
		CharacterBuilder.set_param(player.model, "run", 0.0)
	else:
		v = Vector3(0.0, -2.0, 0.0)
		player.floor_snap_length = _snap
	player.velocity = v
	player.move_and_slide()
	player.model.rotation.y = start_yaw + PI * smoothstep(TAKEOFF, LAND, t)


func _land() -> void:
	landed_t = t
	if fx:
		fx.burst("dust", player.global_position + Vector3(0.0, 0.05, 0.0), Vector3.UP, 0.8)
	bubble.text = "SIUUU!"
	bubble.visible = true
	_bubble_left = BUBBLE_S
	_react_bystanders()
	landed.emit(t)


func _end(cancelled: bool) -> void:
	active = false
	ended_t = t
	player.velocity = Vector3.ZERO
	player.floor_snap_length = _snap
	player.set_physics_process(true)
	CharacterBuilder.set_speed(player.model, 0.0)
	CharacterBuilder.set_param(player.model, "run", 0.0)
	if weapons and weapons.held:
		weapons.held.visible = _held_vis
	finished.emit(emote_id, cancelled)


## W-D13: walking / standing pedestrians within REACT_R react by share (deterministic order from rng), then resume.
func _react_bystanders() -> void:
	var cands: Array = []
	if targets_fn.is_valid():
		for n: Variant in targets_fn.call():
			if n is Pedestrian and is_instance_valid(n) and (n as Pedestrian).is_inside_tree():
				var p: Pedestrian = n
				if p.can_react_emote() and WeaponMath.flat(p.global_position, player.global_position) <= REACT_R:
					cands.append(p)
	for i: int in range(cands.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var n_all: int = cands.size()
	var n_clap: int = roundi(float(n_all) * SHARE_CLAP)
	var n_shout: int = roundi(float(n_all) * SHARE_SHOUT)
	var n_film: int = roundi(float(n_all) * SHARE_FILM)
	for i2: int in n_all:
		var kind: String = "look"
		if i2 < n_clap:
			kind = "clap"
		elif i2 < n_clap + n_shout:
			kind = "shout"
		elif i2 < n_clap + n_shout + n_film:
			kind = "film"
		var secs: float = rng.randf_range(2.0, 3.0) if kind == "clap" else (3.0 if kind == "film" else 2.0)
		var ped: Pedestrian = cands[i2]
		if ped.react_emote(kind, player.global_position, secs):
			reactions[kind] = int(reactions[kind]) + 1
			if kind == "shout":
				_shout_back(ped)


func _shout_back(p: Pedestrian) -> void:
	var l: Label3D = _label("Siuuu!", 40)
	l.position = Vector3(0.0, 2.2, 0.0)
	l.visible = true
	p.add_child(l)
	var a := AudioStreamPlayer3D.new()
	a.stream = WeaponAudio.siuuu_stream()
	a.volume_db = -10.0
	a.pitch_scale = rng.randf_range(0.9, 1.25)
	a.bus = WeaponAudio.bus()
	p.add_child(a)
	a.play()
	_extras.append([l, 1.5])
	_extras.append([a, WeaponAudio.SIUUU_LEN + 0.2])


func _tick_extras(delta: float) -> void:
	for i: int in range(_extras.size() - 1, -1, -1):
		var e: Array = _extras[i]
		e[1] = float(e[1]) - delta
		if float(e[1]) <= 0.0 or not is_instance_valid(e[0]):
			if is_instance_valid(e[0]):
				(e[0] as Node).queue_free()
			_extras.remove_at(i)


func _process(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		bubble.visible = _bubble_left > 0.0
		if player:
			bubble.global_position = player.global_position + Vector3(0.0, 2.4, 0.0)
	if not active or player == null or player.model == null:
		return
	var sk: Skeleton3D = player.model.get_meta("skeleton", null) as Skeleton3D
	var w: float = pose_weight(t)
	if sk == null or w <= 0.0:
		return
	CharacterBuilder._apply_bone_pose(sk, pose_at(t), w)


func _label(text: String, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 10
	l.modulate = Color("#FFE14D")
	l.outline_modulate = Color(0.08, 0.04, 0.12, 0.95)
	l.no_depth_test = true
	l.visible = false
	return l
