# File: res://scripts/horror/ScareDirector.gd
# Pacing and sound of a horror level (spec B-D3, horror polish H-D2, H-D3, H-D6):
# - jump scares: a budget of 1-2 per mission (`budget`, default MAX_JUMP), at least MIN_GAP_S apart on the mission clock;
#   try_jump_scare() is called at the level's scripted moments and only fires within the budget. A full scare = a white
#   flash, violin_screech + sheep_bleat_distorted, a camera shake and the masked `figure` standing 1.1 m in front of the
#   camera for 0.6 s (process off while hidden). The catch scare (play_catch_scare) always plays and does not count.
# - staged catch scares (H-D2): play_catch_scare(spot) stages Dolly's face relative to the current camera for CATCH_S s:
#   "desk" the face lowers upside down from above into the gap under the desk; "locker" the face at the slats, then the
#   door is yanked (catch_beat("reveal")) and the face pushes in; "stall" the camera tilts up and the face rises over the
#   partition; "open" the face lunges at the camera. A sting per spot (CATCH_CUES), a flash and a shake at the hit.
#   catch_beat(name): "face" (start), "reveal" (the level clears its peek overlay), "end". The face is Dolly's (cream wool
#   hood) or, when a clone made the catch (by_dolly = false), a clone's (dark hair). The camera's near plane drops to
#   CATCH_NEAR while it plays (restored after), and the face stops at least 0.32 m away, so the mask never clips.
# - fake-outs (H-D6, H-D7): their own budget (fake_budget, default FAKE_MAX, at least fake_gap_s apart): try_fake_out(kind)
#   then fake_sting() (a short sting; a soft one with "Giảm hù dọa").
# - "Giảm hù dọa" (A2-D14; `reduce_scares`, from the GameFX setting or the level's override): every scare becomes a soft
#   sting (metal_creak and a dark vignette: no flash, no screech, no shake, no figure; a catch is a soft sting and a fade
#   to dark, no face), horror cues play 6 dB quieter (cue_db), flicker events become a slow dim instead of a strobe, the
#   heartbeat is capped at BPM_REDUCED_MAX.
# - heartbeat (H-D3): continuous while the nearest hunter is within HEART_FAR (14 m): heart_bpm_for(dist) = 70 BPM at 14 m
#   up to 160 BPM within 2 m, each beat scheduled on its own (heart_beats counts them), louder as the hunter nears (+3 dB
#   while hidden); while hidden every beat pulses a dark red screen edge (edge_a). Each beat restarts the cue, so an owner
#   override user://sfx/heartbeat.(ogg|mp3|wav) must hold a single lub-dub (a longer file is cut off at every beat).
# - loops: breath while hidden (silent while the breath is held: breath_held), whisper_bed always on, swelling near
#   stalkers. loops_enabled = false (other scenes) keeps every loop and the heartbeat off.
# - flicker events: every 18-34 s (seeded) the emissive light groups within FLICKER_R of the player stutter for 1.6 s
#   (emission_energy_multiplier only: no shader variant switch, A2-R3). The level registers the groups; drop_light_groups
#   hands some back (the SOS lights take the corridor over).
# Sounds come from StoryAudio (owner overrides in user://sfx); build warms them on worker threads, loops start once ready.
# class_name script: no autoload identifiers (StoryUtil bridges the setting).
class_name ScareDirector
extends Node

signal scared(info: Dictionary)
signal flickered(count: int)
signal catch_beat(beat: String)

const MAX_JUMP: int = 2
const MIN_GAP_S: float = 60.0
const REDUCED_DB: float = -6.0
const HEART_FAR: float = 14.0
const HEART_NEAR: float = 2.0
const BPM_FAR: float = 70.0
const BPM_NEAR: float = 160.0
const BPM_REDUCED_MAX: float = 110.0
const EDGE_PEAK: float = 0.55
const HIDDEN_DB: float = 3.0
const CATCH_S: float = 1.2
const CATCH_NEAR: float = 0.01
const CLONE_HAIR := Color("#2B211C")
const CATCH_KINDS: Array[String] = ["desk", "locker", "stall", "open"]
## Sting per spot: [cue at the start, cue at the hit].
const CATCH_CUES: Dictionary = {"desk": ["metal_creak", "violin_screech"], "locker": ["sheep_bleat_distorted", "locker_slam"],
	"stall": ["static_burst", "violin_screech"], "open": ["violin_screech", "sheep_bleat_distorted"]}
## When the face hits (fraction of CATCH_S) and when the spot is opened (catch_beat "reveal"; -1 = none).
const CATCH_HIT: Dictionary = {"desk": 0.3, "locker": 0.45, "stall": 0.55, "open": 0.25}
const CATCH_REVEAL: Dictionary = {"desk": 0.12, "locker": 0.4, "stall": 0.1, "open": -1.0}
const FAKE_MAX: int = 2
const FAKE_GAP_S: float = 20.0
const FLICKER_R: float = 22.0
const FLICKER_S: float = 1.6
const FLICKER_GAP: Vector2 = Vector2(18.0, 34.0)
const FIGURE_S: float = 0.6
const LOOP_CUES: Array[String] = ["heartbeat", "breath", "whisper_bed"]
const SCARE_CUES: Array[String] = ["violin_screech", "sheep_bleat_distorted", "metal_creak", "static_burst", "locker_slam", "gasp"]
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
## Heartbeat rate now (0 = off: no hunter within HEART_FAR) and beats played so far.
var heart_bpm: float = 0.0
var heart_beats: int = 0
var hidden: bool = false
var breath_on: bool = false
## The player holds the breath (HorrorKit): the breath loop is silent.
var breath_held: bool = false
## Screen-edge pulse alpha now (hidden only).
var edge_a: float = 0.0
## false: no loops and no heartbeat (scenes that only borrow the budget and the stings).
var loops_enabled: bool = true
## Fake-outs: their own budget and gap (H-D6, H-D7).
var fake_budget: int = FAKE_MAX
var fake_gap_s: float = FAKE_GAP_S
var fake_count: int = 0
var last_fake_t: float = -INF
var last_fake: String = ""
## The staged catch now: spot kind, time (s; -1 = none), the face node (built on first use).
var catch_kind: String = ""
var catch_t: float = -1.0
var face: Node3D = null
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
var _edge: TextureRect
var _flash_a: float = 0.0
var _veil_a: float = 0.0
var _figure_t: float = 0.0
var _heart_phase: float = 1.0
var _catch_cam: Camera3D = null
var _catch_cam_rot: Vector3 = Vector3.ZERO
var _catch_cam_near: float = 0.05
var _near_set: bool = false
var _hood_wool: StandardMaterial3D
var _hood_hair: StandardMaterial3D
var _catch_hit: bool = false
var _catch_revealed: bool = false
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
	_edge = _edge_rect()
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


## Dark red radial vignette (code-built gradient) for the heartbeat pulse while hidden.
func _edge_rect() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0.3, 0.0, 0.0, 0.0), Color(0.3, 0.0, 0.0, 0.0), Color(0.32, 0.0, 0.02, 0.95)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	var r := TextureRect.new()
	r.name = "EdgePulse"
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.0
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


## The catch scare: always plays, outside the budget. spot_kind "desk" | "locker" | "stall" | "open" (H-D2: the catcher's
## face staged relative to the camera: Dolly's, or a clone's when by_dolly is false); "" = the plain figure scare.
## Reduced: a soft sting and a fade to dark, no face.
func play_catch_scare(spot_kind: String = "open", by_dolly: bool = true) -> void:
	if spot_kind == "":
		_scare("catch")
		return
	var k: String = spot_kind if spot_kind in CATCH_KINDS else "open"
	scares_played += 1
	_end_catch()
	catch_kind = k
	catch_t = 0.0
	_catch_hit = false
	_catch_revealed = false
	_catch_cam = get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() != null else null
	_catch_cam_rot = _catch_cam.rotation if _catch_cam != null else Vector3.ZERO
	var who: String = "dolly" if by_dolly else "clone"
	if reduce_scares:
		last_scare = {"kind": "catch", "spot": k, "who": who, "soft": true, "flash": false, "screech": false, "shake": false,
			"figure": false, "face": false, "fade": true, "upside_down": false, "cues": ["metal_creak"]}
		play_cue("metal_creak", -8.0)
	else:
		var cues: Array = CATCH_CUES[k]
		last_scare = {"kind": "catch", "spot": k, "who": who, "soft": false, "flash": true, "shake": true, "figure": false,
			"face": true, "fade": false, "upside_down": k == "desk", "cues": cues.duplicate(),
			"screech": cues.has("violin_screech") or cues.has("sheep_bleat_distorted")}
		play_cue(String(cues[0]), -4.0)
		_ensure_face()
		(face.get_node("Hood") as MeshInstance3D).material_override = _hood_wool if by_dolly else _hood_hair
		face.visible = true
		if _catch_cam != null:
			_catch_cam_near = _catch_cam.near
			_catch_cam.near = CATCH_NEAR
			_near_set = true
		_place_face(0.0)
	catch_beat.emit("face")
	scared.emit(last_scare)


## Where the face is at u = t / CATCH_S (0..1), relative to the camera: {fwd, up, right (m), roll (rad), tilt (rad: extra
## camera pitch)}. Pure (tests).
static func face_offset(kind: String, u: float) -> Dictionary:
	var e: float = 0.0
	match kind:
		"desk":   # lowers upside down from above the view into the gap, then creeps closer
			e = _ease_out(clampf(u / 0.3, 0.0, 1.0))
			return {"fwd": lerpf(0.5, 0.32, clampf((u - 0.3) / 0.7, 0.0, 1.0)), "up": lerpf(0.55, 0.02, e), "right": 0.0,
				"roll": PI, "tilt": 0.0}
		"locker":   # at the slats, then pushes in when the door is yanked
			e = _ease_out(clampf((u - 0.4) / 0.15, 0.0, 1.0))
			return {"fwd": lerpf(0.5, 0.32, e), "up": 0.0, "right": 0.03 * sin(u * 40.0) * (1.0 - e), "roll": 0.0, "tilt": 0.0}
		"stall":   # the camera looks up at the partition top, the face rises over it
			var tilt: float = lerpf(0.0, 0.75, _ease_out(clampf(u / 0.25, 0.0, 1.0)))
			e = _ease_out(clampf((u - 0.25) / 0.3, 0.0, 1.0))
			return {"fwd": lerpf(0.65, 0.4, e), "up": lerpf(-0.6, 0.04, e), "right": 0.0, "roll": 0.0, "tilt": tilt}
		_:   # "open": lunges at the camera
			e = clampf(u / 0.25, 0.0, 1.0)
			e = e * e
			return {"fwd": lerpf(2.3, 0.4, e), "up": -0.04, "right": 0.0, "roll": 0.0, "tilt": 0.0}


static func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


## Dolly's face for the catch scares: the sheep mask over a cream wool hood and a dark neck (code-built).
func _ensure_face() -> void:
	if face != null and is_instance_valid(face):
		return
	face = Node3D.new()
	face.name = "CatchFace"
	add_child(face)
	var mask: Node3D = CineFX.build_prop("sheep_mask")
	mask.name = "Mask"
	mask.scale = Vector3.ONE * 1.25
	face.add_child(mask)
	_hood_wool = CineFX._mat(Color("#EADCBD"), 1.0)
	_hood_hair = CineFX._mat(CLONE_HAIR, 0.8)
	CineFX._sphere(face, "Hood", 0.17, Vector3(0.0, 0.03, 0.08), _hood_wool, Vector3(1.0, 1.1, 0.9))
	CineFX._box(face, "Neck", Vector3(0.12, 0.22, 0.1), Vector3(0.0, -0.22, 0.05), CineFX._mat(Color("#2A2624"), 0.9))
	face.visible = false


func _place_face(u: float) -> void:
	var cam: Camera3D = _catch_cam if _catch_cam != null and is_instance_valid(_catch_cam) and _catch_cam.is_inside_tree() else null
	if cam == null or face == null:
		return
	var o: Dictionary = face_offset(catch_kind, u)
	cam.rotation = Vector3(_catch_cam_rot.x + float(o["tilt"]), _catch_cam_rot.y, _catch_cam_rot.z)
	var b: Basis = cam.global_transform.basis.orthonormalized()
	var pos: Vector3 = cam.global_position - b.z * float(o["fwd"]) + b.y * float(o["up"]) + b.x * float(o["right"])
	face.global_transform = Transform3D(b * Basis(Vector3(0.0, 0.0, 1.0), float(o["roll"])) * Basis(Vector3.UP, PI), pos)


## Advances the staged catch (from _process; tests call it directly).
func tick_catch(delta: float) -> void:
	if catch_t < 0.0:
		return
	catch_t += delta
	var u: float = clampf(catch_t / CATCH_S, 0.0, 1.0)
	var rv: float = float(CATCH_REVEAL[catch_kind])
	if not _catch_revealed and rv >= 0.0 and u >= rv:
		_catch_revealed = true
		catch_beat.emit("reveal")
	if reduce_scares:
		_veil_a = maxf(_veil_a, minf(0.85, catch_t / 0.6 * 0.85))
	else:
		if not _catch_hit and u >= float(CATCH_HIT[catch_kind]):
			_catch_hit = true
			play_cue(String((CATCH_CUES[catch_kind] as Array)[1]), 0.0)
			_flash_a = 0.6
			if player != null and is_instance_valid(player) and player.has_method("shake"):
				player.call("shake", 0.8)
		_place_face(u)
	if catch_t >= CATCH_S:
		_end_catch()
		catch_beat.emit("end")


func _end_catch() -> void:
	if catch_t >= 0.0 and _catch_cam != null and is_instance_valid(_catch_cam):
		_catch_cam.rotation = _catch_cam_rot
		if _near_set:
			_catch_cam.near = _catch_cam_near
	_near_set = false
	catch_t = -1.0
	_catch_cam = null
	if face != null and is_instance_valid(face):
		face.visible = false


func is_catch_playing() -> bool:
	return catch_t >= 0.0


## Ends a staged catch early (retry): the face goes, the camera's pitch comes back.
func cancel_catch() -> void:
	_end_catch()


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
# Fake-outs (their own budget)
# ---------------------------------------------------------------------------
func can_fake_out() -> bool:
	return fake_count < fake_budget and (clock - last_fake_t) >= fake_gap_s


## A fake-out moment (the coat, the cat, the shiba, a night figure): true when it may play (then counted).
func try_fake_out(kind: String) -> bool:
	if not can_fake_out():
		return false
	fake_count += 1
	last_fake_t = clock
	last_fake = kind
	return true


## The short fake-out sting: violin_screech at `db`, or a soft metal_creak with "Giảm hù dọa". Returns the cue.
func fake_sting(db: float = -10.0) -> String:
	var cue: String = "metal_creak" if reduce_scares else "violin_screech"
	play_cue(cue, db)
	return cue


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


## Heartbeat rate (BPM) for the nearest hunter at `dist` m: 0 beyond HEART_FAR, 70 at 14 m up to 160 within 2 m, capped
## at BPM_REDUCED_MAX with "Giảm hù dọa".
static func heart_bpm_for(dist: float, reduced: bool = false) -> float:
	if dist > HEART_FAR:
		return 0.0
	var k: float = clampf((HEART_FAR - dist) / (HEART_FAR - HEART_NEAR), 0.0, 1.0)
	var b: float = lerpf(BPM_FAR, BPM_NEAR, k)
	return minf(b, BPM_REDUCED_MAX) if reduced else b


## Nearest stalker distance (m; INF = none) and whether the player hides: heartbeat and whisper levels.
func set_threat(dist: float, is_hidden: bool) -> void:
	heart_k = clampf((HEART_FAR - dist) / (HEART_FAR - HEART_NEAR), 0.0, 1.0)
	heart_bpm = heart_bpm_for(dist, reduce_scares)
	set_hidden(is_hidden)


func set_hidden(on: bool) -> void:
	hidden = on
	breath_on = on
	if not on:
		breath_held = false


## Heartbeat volume (dB) for the current threat, or -80 when silent.
func heart_db() -> float:
	if heart_bpm <= 0.0:
		return -80.0
	return lerpf(-24.0, -3.0, heart_k) + (HIDDEN_DB if hidden else 0.0) + cue_db("heartbeat")


## Beats at the current rate, one at a time (from _process; tests call it directly).
func tick_heart(delta: float) -> void:
	if heart_bpm <= 0.0:
		_heart_phase = 1.0   # the first beat comes at once when a hunter comes within range
		return
	_heart_phase += delta * heart_bpm / 60.0
	if _heart_phase < 1.0:
		return
	_heart_phase = fmod(_heart_phase, 1.0)
	heart_beats += 1
	if hidden:
		edge_a = EDGE_PEAK * (0.45 + 0.55 * heart_k) * (0.5 if reduce_scares else 1.0)
	if _heart != null and StoryAudio.ready_for(["heartbeat"]):
		_heart.stream = StoryAudio.stream_once("heartbeat")
		_heart.volume_db = heart_db()
		_heart.play()


func whisper_db() -> float:
	return lerpf(-24.0, -12.0, heart_k) + cue_db("whisper_bed")


func breath_db() -> float:
	return -10.0 + cue_db("breath")


func _update_loops() -> void:
	if not _loops_started:
		if not StoryAudio.ready_for(LOOP_CUES):
			return
		_loops_started = true
		_whisper.stream = StoryAudio.stream("whisper_bed")
		var br: AudioStream = StoryAudio.stream("breath").duplicate()
		StoryAudio._set_loop(br, true)
		_breath.stream = br
	if _heart.playing and heart_bpm <= 0.0:
		_heart.stop()
	_whisper.volume_db = whisper_db()
	if not _whisper.playing:
		_whisper.play()
	_breath.volume_db = breath_db()
	var breathing: bool = breath_on and not breath_held
	if breathing and not _breath.playing:
		_breath.play()
	elif not breathing and _breath.playing:
		_breath.stop()


## Stops every loop (level end).
func stop_all() -> void:
	for p: AudioStreamPlayer in [_heart, _breath, _whisper]:
		if p != null:
			p.stop()
	breath_on = false
	heart_k = 0.0
	heart_bpm = 0.0
	edge_a = 0.0
	if _edge != null:
		_edge.modulate.a = 0.0
	_end_catch()
	set_process(false)


# ---------------------------------------------------------------------------
# Flicker
# ---------------------------------------------------------------------------
## groups: [{pos: Vector3, mat: StandardMaterial3D, energy: float}] (emissive emergency fixtures).
func register_light_groups(groups: Array) -> void:
	_groups.clear()
	for g: Variant in groups:
		_groups.append(g)


## Removes the groups using any of `mats` (the SOS lights take them over); a running flicker on them is restored first.
func drop_light_groups(mats: Array) -> void:
	for i: int in range(_flick.size() - 1, -1, -1):
		if mats.has(_flick[i]["mat"]):
			(_flick[i]["mat"] as StandardMaterial3D).emission_energy_multiplier = float(_flick[i]["energy"])
			_flick.remove_at(i)
	for j: int in range(_groups.size() - 1, -1, -1):
		if mats.has(_groups[j]["mat"]):
			_groups.remove_at(j)


func light_group_count() -> int:
	return _groups.size()


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
	tick_catch(delta)
	if loops_enabled:
		tick_heart(delta)
		_update_loops()
	if edge_a > 0.0:
		edge_a = maxf(0.0, edge_a - delta * 1.8) if hidden else 0.0
	if _edge != null:
		_edge.modulate.a = edge_a
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
