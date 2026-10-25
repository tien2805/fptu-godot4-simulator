# File: res://scripts/cine/CineScare.gd
# Jump scare v2 inside a cinematic (owner request): CinePlayer builds one when the timeline has scare_hit() marks and
# drives it on REAL time (seekable values, forward-only one-shots):
#   duck_at(r)       0..1: the music and the cinematic's other SFX duck to silence over DUCK_S before each hit, stay down
#                    through the hit and the HOLD_S twitch, then come back over RESTORE_S;
#   inhale           a sharp breath in INHALE_BEFORE s before the hit;
#   at the hit       the ScareFace screen hit on the cinematic camera (one white frame, two red frames, the RGB-split + noise
#                    overlay fading over 0.5 s, a red vignette pulse, a 0.4 s shake by camera h/v offsets) and the +8 dB
#                    layered sting with the sub boom on the Sting bus (the screech pitched down);
#   fov_offset(r)    the FOV punch-in (-FOV_PUNCH over FOV_IN_S, back over FOV_OUT_S) the camera adds;
#   twitch_at(r, i)  the hit's actor twitches (+-TWITCH_DEG at TWITCH_HZ, a pure function of r) through its HOLD_S hold.
# The face is the timeline's own actor (snapped in by its keys); the overlay layer is freed by cleanup() (the end, a skip,
# leaving the tree), which also puts the camera offsets back and stops the stings.
# "Giảm hù dọa" (soft): no duck, no flash, overlay, shake, FOV punch, twitch or boom; a soft sting at the hit.
class_name CineScare
extends Node

const DUCK_S: float = 0.4
const RESTORE_S: float = 0.5
const INHALE_BEFORE: float = 0.15
const HOLD_S: float = 0.5
const FOV_PUNCH: float = 15.0
const FOV_IN_S: float = 0.1
const FOV_OUT_S: float = 0.4
const TWITCH_DEG: float = 7.0
const TWITCH_HZ: float = 22.0
const STING_CUES: Array[String] = ["violin_screech", "sheep_bleat_distorted", "sub_boom"]

## [{r: real hit, twitch: actor id, hold: s, inhaled: bool, fired: bool}]
var hits: Array[Dictionary] = []
var soft: bool = false
var camera: Camera3D = null
var face_fx: ScareFace = null
var layer: CanvasLayer = null
## Tests: real times the hits fired at, the last sting {cues, db, bus}, cues played.
var fired: Array[float] = []
var last_sting: Dictionary = {}
var played: Array[String] = []
var _stings: Array[AudioStreamPlayer] = []
var _breath: AudioStreamPlayer = null


func _init() -> void:
	name = "CineScare"
	process_mode = Node.PROCESS_MODE_ALWAYS


## hit_list: [{r, twitch, hold}] in real seconds.
func setup(cam: Camera3D, hit_list: Array, is_soft: bool) -> void:
	camera = cam
	soft = is_soft
	for h: Variant in hit_list:
		var d: Dictionary = (h as Dictionary).duplicate()
		d["inhaled"] = false
		d["fired"] = false
		hits.append(d)
	_breath = _player("Inhale", CinePlayer._bus("SFX"))
	if soft:
		return
	layer = CanvasLayer.new()
	layer.name = "CineScareLayer"
	layer.layer = 40
	add_child(layer)
	face_fx = ScareFace.new()
	add_child(face_fx)
	face_fx.setup(layer, 7)
	var bus: String = ScareDirector.ensure_sting_bus()
	for i: int in 3:
		_stings.append(_player("Sting%d" % i, StringName(bus)))
	StoryAudio.warm(STING_CUES + ["gasp", "metal_creak"])


func _player(n: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = bus
	add_child(p)
	return p


## Duck level at real time r (0 = normal, 1 = silent).
func duck_at(r: float) -> float:
	if soft:
		return 0.0
	var best: float = 0.0
	for h: Dictionary in hits:
		var rh: float = float(h["r"])
		var hold: float = float(h.get("hold", HOLD_S))
		var k: float = 0.0
		if r >= rh - DUCK_S and r < rh:
			k = (r - (rh - DUCK_S)) / DUCK_S
		elif r >= rh and r < rh + hold:
			k = 1.0
		elif r >= rh + hold and r < rh + hold + RESTORE_S:
			k = 1.0 - (r - rh - hold) / RESTORE_S
		best = maxf(best, k)
	return clampf(best, 0.0, 1.0)


func duck_db(r: float) -> float:
	return linear_to_db(maxf(1.0 - duck_at(r), 0.001))


## FOV offset (degrees, <= 0) at real time r.
func fov_offset(r: float) -> float:
	if soft:
		return 0.0
	for h: Dictionary in hits:
		var t: float = r - float(h["r"])
		if t >= 0.0 and t < FOV_IN_S:
			return -FOV_PUNCH * t / FOV_IN_S
		if t >= FOV_IN_S and t < FOV_IN_S + FOV_OUT_S:
			return -FOV_PUNCH * (1.0 - (t - FOV_IN_S) / FOV_OUT_S)
	return 0.0


## Twitch rotation (radians) of hit i's actor at real time r: zero outside its hold.
func twitch_at(r: float, i: int) -> Vector3:
	if soft or i < 0 or i >= hits.size():
		return Vector3.ZERO
	var t: float = r - float(hits[i]["r"])
	if t < 0.0 or t >= float(hits[i].get("hold", HOLD_S)):
		return Vector3.ZERO
	var n: int = int(floor(t * TWITCH_HZ))
	var a: float = deg_to_rad(TWITCH_DEG)
	return Vector3(sin(n * 12.9898) , sin(n * 78.233 + 1.0), sin(n * 37.719 + 2.0)) * a


## Forward one-shots between r_prev and r (dt = real step): the overlays' decay of the frames before, the inhale, the hit
## (its frame is the white one).
func step(r_prev: float, r: float, dt: float) -> void:
	if face_fx != null:
		face_fx._step_hit(dt)
	for h: Dictionary in hits:
		var rh: float = float(h["r"])
		if not bool(h["inhaled"]) and r >= rh - INHALE_BEFORE and r_prev < rh:
			h["inhaled"] = true
			if not soft:
				_play(_breath, "gasp", -6.0)
		if not bool(h["fired"]) and r >= rh:
			h["fired"] = true
			fired.append(r)
			if soft:
				_play(_breath, "metal_creak", -8.0)
				continue
			face_fx.hit(camera)
			_sting()


func _play(p: AudioStreamPlayer, cue: String, db: float) -> void:
	played.append(cue)
	if not StoryAudio.ready_for([cue]):
		return
	p.stream = StoryAudio.stream_once(cue)
	p.volume_db = db
	p.play()


func _sting() -> void:
	var sfx: int = AudioServer.get_bus_index("SFX")
	var si: int = AudioServer.get_bus_index(ScareDirector.STING_BUS)
	if sfx != -1 and si != -1:
		AudioServer.set_bus_volume_db(si, AudioServer.get_bus_volume_db(sfx))
	for i: int in STING_CUES.size():
		var cue: String = STING_CUES[i]
		played.append(cue)
		var p: AudioStreamPlayer = _stings[i]
		p.volume_db = ScareDirector.STING_BOOST_DB + (-3.0 if i == 1 else 0.0)
		p.pitch_scale = ScareDirector.SCREAM_PITCH if cue == "violin_screech" else 1.0
		if StoryAudio.ready_for([cue]):
			p.stream = StoryAudio.stream_once(cue)
			p.play()
	last_sting = {"cues": STING_CUES.duplicate(), "db": ScareDirector.STING_BOOST_DB, "bus": ScareDirector.STING_BUS}


func sting_volume_db(i: int) -> float:
	return _stings[i].volume_db if i < _stings.size() else -80.0


## The overlays and the shake are over (tests).
func screen_idle() -> bool:
	return face_fx == null or face_fx.screen_idle()


## The end (or a skip, or leaving the tree): the overlay layer goes, the camera offsets come back, the stings stop.
func cleanup() -> void:
	for p: AudioStreamPlayer in _stings:
		p.stop()
	if face_fx != null:
		face_fx.clear_hit()
		face_fx.stop()
	if camera != null and is_instance_valid(camera):
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
		layer = null
