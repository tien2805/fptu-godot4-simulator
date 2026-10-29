# File: res://scripts/combat/guns/BulletTime.gd
# Wave 3 bullet time (spec 2026-10-27 W-1, plan docs/superpowers/plans/2026-10-30-w3-shared.md T4-T5), a Max Payne homage
# (no shot copies). GunFight builds one per fight (setup opt "bullet_time", default true) as `fight.bullet_time`.
#
# ===== API (the day streams call it behind guards) =====
#   fight.bullet_time.enabled = false     # no dive (the crane cabin, a forklift, the hack's typing, a QTE); true again after
#   fight.bullet_time.active() -> bool    # a dive or its prone time is running
#   fight.bullet_time.focus               # 0..FOCUS_MAX
#   fight.bullet_time.refill(n)           # add focus (clamped)
#   owns_scale(), can_dive(), try_dive(), end_dive() (the slow part ends now), stop() (everything restored), cost()
# ========================================================
# Trigger: Space while aiming (RMB held), on foot, not in cover, not knocked down, the fight running, focus >= cost()
# (Thường 50, Dễ 40). The press reaches it through ThirdPersonController.dive_filter (set while the fight is engaged): an
# accepted or refused dive press never jumps or dodges; without aiming the press goes on to the jump / dodge as before. The
# dive goes in the move direction (camera relative), or to the side when standing still (right, then left, alternating).
# Time: DIVE_REAL_S (1.2 s) at SCALE (0.35x) through RadialWheel.scale_owner, counted in physics frames (72 at 60 Hz),
# then the player lies PRONE_REAL_S (0.4 s, 24 frames) in normal time; aim and fire stay live (WeaponDirector.real_time
# while the dive owns the scale: cooldown and reload in real seconds). The scale is taken only when nobody owns it or
# Impact's clock owns it (Impact.yield_scale() first); a weapon wheel or a director cut owning it = no dive, no cost, a
# dull click. Enemy telegraphs and bullets slow with the world for free (game time).
# Focus: FOCUS_MAX 100, refills REFILL per real second while the fight runs and no dive is on (Thường 5, Dễ 7), +KO_BONUS
# per knockout (20 / 25: GunFight calls on_ko), full again at start / retry (reset()).
# Effects while the dive owns the scale: a grey-blue screen tint (one ColorRect), a synthesized heartbeat (GunAudio
# "heartbeat", looping), GameFX.music.focus_muffle(true) (guarded); the player's GunPose shows "dive" then "prone"; while
# prone the enemies aim at the crouch height (GunFight.player_target).
# Safety (T5): the scale, the tint, the heartbeat and the muffle are restored when the dive's slow part ends, on end_dive()
# (GunFight: a last-enemy knockout during the dive, before Impact.slowmo_orbit takes the scale), on stop() (GunFight won /
# lost / retry / stop / engage off), on a tree pause (a cinematic: polled, this node processes always), when it leaves the
# tree (scene change) and when another owner takes the scale mid-dive (only its own effects end; it never writes the
# scale then). A running dive also ends when `enabled` goes false or the player loses the controls (a forklift, a
# cinematic), and when the body leaves the dive by itself (a heavy hit knocks it down). Nothing is allocated per frame.
class_name BulletTime
extends Node

signal dive_started(dir: Vector3)
signal dive_ended

const SCALE: float = 0.35
const DIVE_REAL_S: float = 1.2
const PRONE_REAL_S: float = 0.4
const DIVE_SPEED: float = 6.5            # m/s of real time
const FOCUS_MAX: float = 100.0
const COST: Vector2 = Vector2(50.0, 40.0)        # Thường, Dễ
const REFILL: Vector2 = Vector2(5.0, 7.0)        # per real second
const KO_BONUS: Vector2 = Vector2(20.0, 25.0)
const TINT := Color(0.42, 0.55, 0.78, 0.22)
const HEART_DB: float = -4.0
const T_PROMPT: String = "[Space] lao người"
const T_FOCUS: String = "Tập trung"

var fight: Object = null
var player: ThirdPersonController = null
var weapons: WeaponDirector = null
var enabled: bool = true
var focus: float = FOCUS_MAX
## "idle" | "dive" | "prone"
var state: String = "idle"
var dives: int = 0
var refusals: int = 0
var clicks: int = 0
var last_refusal: String = ""
var tint: ColorRect = null
var heart: AudioStreamPlayer = null
var muffled: bool = false
var _layer: CanvasLayer = null
var _owns: bool = false
var _left: int = 0
var _side: float = 1.0
var _engaged: bool = false
var _prev_dive_filter: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # sees a tree pause (a cinematic) and restores the time scale
	_layer = CanvasLayer.new()
	_layer.name = "BulletTint"
	_layer.layer = 1
	add_child(_layer)
	tint = ColorRect.new()
	tint.name = "Tint"
	tint.color = TINT
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.visible = false
	_layer.add_child(tint)
	heart = AudioStreamPlayer.new()
	heart.name = "Heartbeat"
	heart.bus = WeaponAudio.bus()
	heart.volume_db = HEART_DB
	heart.stream = GunAudio.stream("heartbeat")
	add_child(heart)


func setup(f: Object) -> void:
	fight = f
	player = f.get("player")
	weapons = f.get("weapons")


static func cost() -> float:
	return float(Difficulty.pick(COST.x, COST.y))


static func refill_rate() -> float:
	return float(Difficulty.pick(REFILL.x, REFILL.y))


static func ko_bonus() -> float:
	return float(Difficulty.pick(KO_BONUS.x, KO_BONUS.y))


## A dive or its prone time is running.
func active() -> bool:
	return state != "idle"


## This node holds Engine.time_scale right now (the slow part of a dive).
func owns_scale() -> bool:
	return _owns and RadialWheel.scale_owner == self


func refill(n: float) -> void:
	focus = clampf(focus + n, 0.0, FOCUS_MAX)


## Full focus, no dive (the fight's start and every retry).
func reset() -> void:
	stop()
	focus = FOCUS_MAX


## GunFight: an enemy was knocked out.
func on_ko() -> void:
	refill(ko_bonus())


## The fight takes (on) or gives back (off) the player's Space press. Off also stops a running dive.
func engage(on: bool) -> void:
	if on == _engaged:
		return
	_engaged = on
	if player == null or not is_instance_valid(player):
		return
	if on:
		_prev_dive_filter = player.dive_filter
		player.dive_filter = _on_space
	else:
		if player.dive_filter == Callable(self, "_on_space"):
			player.dive_filter = _prev_dive_filter
		_prev_dive_filter = Callable()
		stop()


# ---------------------------------------------------------------------------
# TRIGGER
# ---------------------------------------------------------------------------
## Why a dive cannot start now ("" = it can): the conditions besides aiming and the time-scale owner.
func block_reason() -> String:
	if not enabled:
		return "disabled"
	if fight == null or String(fight.get("state")) != "running":
		return "fight"
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return "player"
	if state != "idle":
		return "busy"
	if player.move_state != "GROUND" and player.move_state != "LAND_SOFT":
		return "move"
	var roam: Object = fight.get("roam")
	if roam != null and is_instance_valid(roam) and bool(roam.get("mounted")):
		return "mounted"
	var cov: Object = fight.get("cover_ctl")
	if cov != null and bool(cov.get("in_cover")):
		return "cover"
	var c: Object = fight.get("combat")
	if c != null and is_instance_valid(c) and bool(c.call("is_down")):
		return "down"
	if focus + 1e-4 < cost():
		return "focus"
	return ""


func _aiming() -> bool:
	return weapons != null and is_instance_valid(weapons) and weapons.aiming


## The GunHUD prompt shows while aiming with a dive available.
func can_prompt() -> bool:
	return _aiming() and block_reason() == "" and _scale_free()


func can_dive() -> bool:
	return can_prompt()


func _scale_free() -> bool:
	var o: Object = RadialWheel.scale_owner
	return o == null or not is_instance_valid(o) or o is Impact or o == self


## ThirdPersonController.dive_filter: true = the press is the dive's (started or refused while aiming).
func _on_space() -> bool:
	if not _aiming() or not enabled:
		return false                         # a normal jump / dodge
	try_dive()
	return true


## Starts a dive when every condition holds. A refusal while aiming plays a dull click (no cost). Returns true on a dive.
func try_dive() -> bool:
	var why: String = block_reason()
	if why == "" and not _scale_free():
		why = "scale"
	if why == "" and not _aiming():
		why = "aim"
	if why != "":
		refusals += 1
		last_refusal = why
		if why == "scale" or why == "focus" or why == "cover":
			_click()
		return false
	var dir: Vector3 = _dive_dir()
	if not player.dive(dir, DIVE_REAL_S, DIVE_SPEED, PRONE_REAL_S):
		refusals += 1
		last_refusal = "move"
		return false
	var o: Object = RadialWheel.scale_owner
	if o != null and is_instance_valid(o) and o is Impact:
		Impact.yield_scale()                 # a running hit-stop / slow motion gives way
	RadialWheel.scale_owner = self
	Engine.time_scale = SCALE
	_owns = true
	focus -= cost()
	dives += 1
	state = "dive"
	_left = maxi(1, roundi(DIVE_REAL_S * float(_ticks())))
	_effects(true)
	_pose("dive")
	dive_started.emit(dir)
	return true


## The move direction (camera relative), else the side (right, then left).
func _dive_dir() -> Vector3:
	var y: float = player.yaw
	var f := Vector3(-sin(y), 0.0, -cos(y))
	var r := Vector3(cos(y), 0.0, -sin(y))
	var inp: Vector2 = player.input_dir
	if inp.length_squared() > 0.01:
		return (f * (-inp.y) + r * inp.x).normalized()
	var d: Vector3 = r * _side
	_side = -_side
	return d


func _click() -> void:
	clicks += 1
	if fight != null and player != null and fight.has_method("play_cue"):
		fight.call("play_cue", "dry_click", player.global_position + Vector3(0.0, 1.2, 0.0), -4.0)


# ---------------------------------------------------------------------------
# FRAME
# ---------------------------------------------------------------------------
static func _ticks() -> int:
	return maxi(1, Engine.physics_ticks_per_second)


func _physics_process(_delta: float) -> void:
	var paused: bool = get_tree().paused
	if paused:
		if state != "idle":
			stop()                           # a cinematic: the scale and the effects back at once
		return
	var rdt: float = 1.0 / float(_ticks())
	if state != "idle":
		if not enabled or player == null or not is_instance_valid(player) or not player.controls_enabled:
			stop()                               # a forklift entered, a cinematic took the controls: the dive ends now
			return
		if not player.is_diving() and not player.is_prone():
			_end_slow()                          # the body left the dive (a heavy hit knocked it down): scale, effects, pose
			_finish()
			return
	match state:
		"dive":
			if _owns and RadialWheel.scale_owner != self:
				_owns = false                # someone else took the scale: never write it back
				_effects(false)
			_left -= 1
			if _left <= 0:
				_end_slow()
				state = "prone"
				_left = maxi(0, roundi(PRONE_REAL_S * float(_ticks())))
				_pose("prone")
				if _left == 0:
					_finish()
		"prone":
			_left -= 1
			if _left <= 0:
				_finish()
		_:
			if fight != null and String(fight.get("state")) == "running" and focus < FOCUS_MAX:
				focus = minf(FOCUS_MAX, focus + refill_rate() * rdt)


## The slow part ends now (a last-enemy knockout: the orbit takes the scale); the player finishes the dive in normal time.
func end_dive() -> void:
	if state == "dive":
		_end_slow()
		state = "prone"
		_left = maxi(0, roundi(PRONE_REAL_S * float(_ticks())))
		_pose("prone")


## Everything restored at once: scale, tint, heartbeat, muffle, the player back on the feet, no dive.
func stop() -> void:
	var was: bool = state != "idle"
	_end_slow()
	state = "idle"
	_left = 0
	if was:
		if player != null and is_instance_valid(player) and player.has_method("cancel_dive"):
			player.cancel_dive()
		_pose("")


func _finish() -> void:
	state = "idle"
	_left = 0
	_pose("")


func _end_slow() -> void:
	if _owns and RadialWheel.scale_owner == self:
		Engine.time_scale = 1.0
		RadialWheel.scale_owner = null
	_owns = false
	if RadialWheel.scale_owner == self:          # never left behind
		RadialWheel.scale_owner = null
	_effects(false)
	if state == "dive":
		dive_ended.emit()


func _effects(on: bool) -> void:
	if weapons != null and is_instance_valid(weapons):
		weapons.real_time = on
	if tint:
		tint.visible = on
	if heart:
		if on and not heart.playing:
			heart.play()
		elif not on and heart.playing:
			heart.stop()
	if on != muffled:
		muffled = on
		var gfx: Node = get_node_or_null("/root/GameFX") if is_inside_tree() else null
		var md: Object = gfx.get("music") if gfx != null else null
		if md != null and is_instance_valid(md) and md.has_method("focus_muffle"):
			md.call("focus_muffle", on)


## The player's GunPose (PlayerCover's layer): "dive", "prone" or "" (released unless the cover owns it).
func _pose(p: String) -> void:
	var cov: Object = fight.get("cover_ctl") if fight != null else null
	var gp: GunPose = cov.get("pose") if cov != null and is_instance_valid(cov) else null
	if gp == null or not is_instance_valid(gp):
		return
	if p != "":
		gp.set_pose(p)
	elif gp.pose_name == "dive" or gp.pose_name == "prone":
		gp.clear()


func _exit_tree() -> void:
	stop()
	if player != null and is_instance_valid(player) and player.dive_filter == Callable(self, "_on_space"):
		player.dive_filter = _prev_dive_filter
	_engaged = false
