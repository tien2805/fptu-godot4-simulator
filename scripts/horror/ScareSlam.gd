# File: res://scripts/horror/ScareSlam.gd
# A world-anchored face scare (scare events: the window slam in the Night Building and the Day 1 corridor): the scare mask
# (ScareFace.build_scare_mask, with a hood) slams against `at` from `out` behind it with the jump scare v2 beats: the
# ScareDirector's event duck for DUCK_S, then the snap in SNAP_S with an overshoot, the loud sting, a bang and the screen
# hit, a twitching hold of HOLD_S, then it drops out of view over DROP_S and hides. "Giảm hù dọa": only a soft sting, no
# face. done() when it is over. No light node.
class_name ScareSlam
extends Node3D

signal done

const SNAP_S: float = 0.1
const HOLD_S: float = 0.5
const DROP_S: float = 0.3
const DROP_M: float = 1.6

var scare: ScareDirector = null
var playing: bool = false
var t: float = 0.0
var face: Node3D
var _at: Vector3
var _out: Vector3
var _look: Vector3
var _scale: float = 2.2
var _rng := RandomNumberGenerator.new()
var _twitch := Vector3.ZERO


func _init() -> void:
	name = "ScareSlam"


func _ready() -> void:
	face = Node3D.new()
	face.name = "SlamFace"
	add_child(face)
	face.add_child(ScareFace.build_scare_mask())
	ScareFace._sphere(face, "Hood", 0.17, Vector3(0.0, 0.04, 0.09), ScareFace._mat(Color("#8F8571"), 1.0), Vector3(1.05, 1.15, 0.95))
	face.visible = false


## Slams the face at `at` (world), coming from `out` (unit vector away from the viewer) and looking towards `look_at`.
func start(sd: ScareDirector, at: Vector3, out: Vector3, look_at_pos: Vector3, scale: float = 2.2) -> void:
	scare = sd
	_at = at
	_out = out.normalized()
	_look = look_at_pos
	_scale = scale
	t = 0.0
	playing = true
	if scare.reduce_scares:
		scare.play_cue("metal_creak", -8.0)
		return
	scare.event_duck(true)


func stop() -> void:
	if playing and scare != null and is_instance_valid(scare):
		scare.event_duck(false)
	playing = false
	if face != null:
		face.visible = false


func _place(p: Vector3) -> void:
	var to: Vector3 = _look - p
	to.y = 0.0
	var yaw: float = atan2(-to.x, -to.z) if to.length_squared() > 1e-6 else 0.0
	var tw := Basis.from_euler(Vector3(deg_to_rad(_twitch.x), deg_to_rad(_twitch.y), deg_to_rad(_twitch.z) + deg_to_rad(18.0)))
	face.global_transform = Transform3D(Basis(Vector3.UP, yaw) * tw * Basis().scaled(Vector3.ONE * _scale), p)


func step(delta: float) -> void:
	if not playing:
		return
	t += delta
	if scare.reduce_scares:
		if t >= 0.6:
			playing = false
			done.emit()
		return
	var d: float = ScareDirector.DUCK_S
	if t < d:
		return
	var u: float = t - d
	if not face.visible:
		face.visible = true
		scare.loud_sting(ScareDirector.JUMP_CUES)
		scare.play_cue("locker_slam", 0.0)   # the bang on the glass
		scare.screen_hit()
	if u < SNAP_S:
		_place((_at + _out * 0.7).lerp(_at, ScareFace._ease_out_back(u / SNAP_S)))
	elif u < SNAP_S + HOLD_S:
		_twitch = Vector3(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-7.0, 7.0), _rng.randf_range(-7.0, 7.0))
		_place(_at)
	elif u < SNAP_S + HOLD_S + DROP_S:
		_twitch = Vector3.ZERO
		_place(_at + Vector3.DOWN * DROP_M * (u - SNAP_S - HOLD_S) / DROP_S)
	else:
		stop()
		done.emit()


func _physics_process(delta: float) -> void:
	step(delta)
