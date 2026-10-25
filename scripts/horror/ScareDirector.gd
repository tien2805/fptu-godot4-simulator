# File: res://scripts/horror/ScareDirector.gd
# Pacing and sound of a horror level (spec B-D3):
# - jump scares: a budget of 1-2 per mission (`budget`, default MAX_JUMP), at least MIN_GAP_S apart on the mission clock;
#   try_jump_scare() is called at the level's scripted moments and only fires within the budget. A full scare = a white
#   flash, violin_screech + sheep_bleat_distorted, a camera shake and the masked `figure` standing 1.1 m in front of the
#   camera for 0.6 s (process off while hidden). The catch scare (play_catch_scare) always plays and does not count.
# - "Giảm hù dọa" (A2-D14; `reduce_scares`, from the GameFX setting or the level's override): every scare becomes a soft
#   sting (metal_creak and a dark vignette: no flash, no screech, no shake, no figure), horror cues play 6 dB quieter
#   (cue_db), flicker events become a slow dim instead of a strobe.
# - loops: heartbeat by the nearest stalker's distance (silent beyond HEART_FAR, loud and faster near; +3 dB while hidden),
#   breath while hidden, whisper_bed always on, swelling near stalkers.
# - flicker events: every 18-34 s (seeded) the emissive light groups within FLICKER_R of the player stutter for 1.6 s
#   (emission_energy_multiplier only: no shader variant switch, A2-R3). The level registers the groups.
# Sounds come from StoryAudio (owner overrides in user://sfx); build warms them on worker threads, loops start once ready.
# class_name script: no autoload identifiers (StoryUtil bridges the setting).
class_name ScareDirector
extends Node

signal scared(info: Dictionary)
signal flickered(count: int)

const MAX_JUMP: int = 2
const MIN_GAP_S: float = 60.0
const REDUCED_DB: float = -6.0
const HEART_FAR: float = 16.0
const HEART_NEAR: float = 2.0
const HIDDEN_DB: float = 3.0
const FLICKER_R: float = 22.0
const FLICKER_S: float = 1.6
const FLICKER_GAP: Vector2 = Vector2(18.0, 34.0)
const FIGURE_S: float = 0.6
const LOOP_CUES: Array[String] = ["heartbeat", "breath", "whisper_bed"]
const SCARE_CUES: Array[String] = ["violin_screech", "sheep_bleat_distorted", "metal_creak", "static_burst"]
const PLAYED_MAX: int = 32

var reduce_scares: bool = false
var budget: int = MAX_JUMP
## Mission clock (s), advanced in _process (tests may set it).
var clock: float = 0.0
var auto_clock: bool = true
var jump_count: int = 0
var last_jump_t: float = -INF
var scares_played: int = 0
var last_scare: Dictionary = {}
var flicker_events: int = 0
var flicker_enabled: bool = true
## Masked body shown in front of the camera on a full scare (the level builds it; may stay null).
var figure: Node3D = null
## The player (shake target, flicker centre); optional.
var player: Node3D = null
## Cues played (newest last, capped), for tests.
var played: Array[String] = []
## Current loop states, for tests and the HUD.
var heart_k: float = 0.0
var hidden: bool = false
var breath_on: bool = false
var rng := RandomNumberGenerator.new()

var _heart: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _whisper: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _loops_started: bool = false
var _layer: CanvasLayer
var _flash: ColorRect
var _veil: ColorRect
var _flash_a: float = 0.0
var _veil_a: float = 0.0
var _figure_t: float = 0.0
var _groups: Array[Dictionary] = []   # {pos: Vector3, mat: StandardMaterial3D, energy: float}
var _flick: Array[Dictionary] = []    # {mat, energy, t}
var _next_flicker: float = 0.0


func _init() -> void:
	name = "ScareDirector"


func _ready() -> void:
	_heart = _make_player("Heartbeat")
	_breath = _make_player("Breath")
	_whisper = _make_player("Whisper")
	for i: int in 4:
		_pool.append(_make_player("Sfx%d" % i))
	_layer = CanvasLayer.new()
	_layer.name = "ScareLayer"
	_layer.layer = 30
	add_child(_layer)
	_veil = _rect("Veil", Color(0.0, 0.0, 0.0, 0.0))
	_flash = _rect("Flash", Color(1.0, 1.0, 1.0, 0.0))
	_next_flicker = rng.randf_range(FLICKER_GAP.x, FLICKER_GAP.y)
	StoryAudio.warm(LOOP_CUES + SCARE_CUES)


func _make_player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	if AudioServer.get_bus_index("SFX") != -1:
		p.bus = "SFX"
	add_child(p)
	return p


func _rect(n: String, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = n
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(r)
	return r


## Seed of the flicker timing.
func set_seed(s: int) -> void:
	rng.seed = s
	_next_flicker = clock + rng.randf_range(FLICKER_GAP.x, FLICKER_GAP.y)


# ---------------------------------------------------------------------------
# Jump scares
# ---------------------------------------------------------------------------
func can_jump_scare() -> bool:
	return jump_count < budget and (clock - last_jump_t) >= MIN_GAP_S


## A scripted jump-scare moment: plays only within the budget and the gap. Returns true when it played.
func try_jump_scare() -> bool:
	if not can_jump_scare():
		return false
	jump_count += 1
	last_jump_t = clock
	_scare("jump")
	return true


## The catch scare: always plays, outside the budget.
func play_catch_scare() -> void:
	_scare("catch")


func _scare(kind: String) -> void:
	scares_played += 1
	if reduce_scares:
		last_scare = {"kind": kind, "soft": true, "flash": false, "screech": false, "shake": false, "figure": false, "cues": ["metal_creak"]}
		play_cue("metal_creak", -2.0)
		_veil_a = 0.45
	else:
		last_scare = {"kind": kind, "soft": false, "flash": true, "screech": true, "shake": true, "figure": figure != null,
			"cues": ["violin_screech", "sheep_bleat_distorted"]}
		play_cue("violin_screech", 0.0)
		play_cue("sheep_bleat_distorted", -3.0)
		_flash_a = 0.85
		if player != null and is_instance_valid(player) and player.has_method("shake"):
			player.call("shake", 0.8)
		_show_figure()
	scared.emit(last_scare)


func _show_figure() -> void:
	if figure == null or not is_instance_valid(figure) or not figure.is_inside_tree():
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	var f: Vector3 = -cam.global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD
	var p: Vector3 = cam.global_position + f * 1.1
	# stands on the floor (the player's feet), whatever the camera height (third-person 2.2 m, peek 0.2-1.55 m)
	var floor_y: float = player.global_position.y if player != null and is_instance_valid(player) and player.is_inside_tree() else cam.global_position.y - 1.55
	figure.global_position = Vector3(p.x, floor_y, p.z)
	figure.rotation.y = atan2(f.x, f.z)   # faces the camera (-Z towards it)
	figure.process_mode = Node.PROCESS_MODE_INHERIT
	figure.visible = true
	_figure_t = FIGURE_S


# ---------------------------------------------------------------------------
# Sound
# ---------------------------------------------------------------------------
## Extra gain of a cue: -6 dB for horror cues with "Giảm hù dọa".
func cue_db(cue: String) -> float:
	return REDUCED_DB if reduce_scares and StoryAudio.is_horror(cue) else 0.0


## One-shot cue at `db` (+ cue_db). Skips the sound (still recorded) while the cue is still being synthesized.
func play_cue(cue: String, db: float = 0.0) -> void:
	played.append(cue)
	if played.size() > PLAYED_MAX:
		played.remove_at(0)
	if _pool.is_empty() or not StoryAudio.ready_for([cue]):
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = StoryAudio.stream_once(cue)
	p.volume_db = db + cue_db(cue)
	p.play()


## Nearest stalker distance (m; INF = none) and whether the player hides: heartbeat and whisper levels.
func set_threat(dist: float, is_hidden: bool) -> void:
	heart_k = clampf(1.0 - (dist - HEART_NEAR) / (HEART_FAR - HEART_NEAR), 0.0, 1.0)
	set_hidden(is_hidden)


func set_hidden(on: bool) -> void:
	hidden = on
	breath_on = on


## Heartbeat volume (dB) for the current threat, or -80 when silent.
func heart_db() -> float:
	if heart_k <= 0.0:
		return -80.0
	return lerpf(-28.0, -4.0, heart_k) + (HIDDEN_DB if hidden else 0.0) + cue_db("heartbeat")


func whisper_db() -> float:
	return lerpf(-24.0, -12.0, heart_k) + cue_db("whisper_bed")


func breath_db() -> float:
	return -10.0 + cue_db("breath")


func _update_loops() -> void:
	if not _loops_started:
		if not StoryAudio.ready_for(LOOP_CUES):
			return
		_loops_started = true
		_heart.stream = StoryAudio.stream("heartbeat")
		_whisper.stream = StoryAudio.stream("whisper_bed")
		var br: AudioStream = StoryAudio.stream("breath").duplicate()
		StoryAudio._set_loop(br, true)
		_breath.stream = br
	var hd: float = heart_db()
	if hd > -79.0:
		_heart.volume_db = hd
		_heart.pitch_scale = 1.0 + 0.45 * heart_k
		if not _heart.playing:
			_heart.play()
	elif _heart.playing:
		_heart.stop()
	_whisper.volume_db = whisper_db()
	if not _whisper.playing:
		_whisper.play()
	_breath.volume_db = breath_db()
	if breath_on and not _breath.playing:
		_breath.play()
	elif not breath_on and _breath.playing:
		_breath.stop()


## Stops every loop (level end).
func stop_all() -> void:
	for p: AudioStreamPlayer in [_heart, _breath, _whisper]:
		if p != null:
			p.stop()
	breath_on = false
	heart_k = 0.0
	set_process(false)


# ---------------------------------------------------------------------------
# Flicker
# ---------------------------------------------------------------------------
## groups: [{pos: Vector3, mat: StandardMaterial3D, energy: float}] (emissive emergency fixtures).
func register_light_groups(groups: Array) -> void:
	_groups.clear()
	for g: Variant in groups:
		_groups.append(g)


## Flickers the groups within FLICKER_R of pos for dur seconds (a slow dim with "Giảm hù dọa"). Returns the group count.
func flicker_near(p: Vector3, dur: float = FLICKER_S) -> int:
	var n: int = 0
	for g: Dictionary in _groups:
		if (g["pos"] as Vector3).distance_to(p) > FLICKER_R:
			continue
		var busy: bool = false
		for f: Dictionary in _flick:
			if f["mat"] == g["mat"]:
				busy = true
		if busy:
			continue
		_flick.append({"mat": g["mat"], "energy": float(g["energy"]), "t": 0.0, "dur": dur})
		n += 1
	flicker_events += 1
	flickered.emit(n)
	return n


func _update_flicker(delta: float) -> void:
	for i: int in range(_flick.size() - 1, -1, -1):
		var f: Dictionary = _flick[i]
		f["t"] = float(f["t"]) + delta
		var t: float = float(f["t"])
		var mat: StandardMaterial3D = f["mat"]
		var e: float = float(f["energy"])
		if t >= float(f["dur"]):
			mat.emission_energy_multiplier = e
			_flick.remove_at(i)
			continue
		if reduce_scares:
			mat.emission_energy_multiplier = e * (0.35 + 0.65 * absf(cos(PI * t / float(f["dur"]))))
		else:
			var on: bool = int(floor(t * 17.0)) % 3 != 1 and int(floor(t * 5.0)) % 4 != 2
			mat.emission_energy_multiplier = e if on else e * 0.04


# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if auto_clock:
		clock += delta
	if flicker_enabled and not _groups.is_empty() and clock >= _next_flicker:
		_next_flicker = clock + rng.randf_range(FLICKER_GAP.x, FLICKER_GAP.y)
		var c: Vector3 = player.global_position if player != null and is_instance_valid(player) and player.is_inside_tree() else Vector3.ZERO
		flicker_near(c)
	_update_flicker(delta)
	_update_loops()
	if _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - delta * 3.0)
		_flash.color.a = _flash_a
	if _veil_a > 0.0:
		_veil_a = maxf(0.0, _veil_a - delta * 0.6)
		_veil.color.a = _veil_a
	if _figure_t > 0.0:
		_figure_t -= delta
		if _figure_t <= 0.0 and figure != null and is_instance_valid(figure):
			figure.visible = false
			figure.process_mode = Node.PROCESS_MODE_DISABLED   # no animation while unseen
