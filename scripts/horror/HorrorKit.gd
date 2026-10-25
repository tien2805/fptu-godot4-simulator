# File: res://scripts/horror/HorrorKit.gd
# The horror layer of one level (spec B-D3), composed by the level (Night Building, later horror beats):
#   player (ThirdPersonController built by the level; put on collision layer 2 so stalker rays see only the world), the
#   flashlight, the shared HorrorSenses, the stalkers, the hiding spots, the ScareDirector.
# Each physics frame: senses <- player (position, lit, noise radius, hidden spot); catch reports. At 10 Hz: the nearest
# stalker distance -> ScareDirector.set_threat (heartbeat, whisper) and the [E] prompt.
# Noise radius (hearing, metres): sprint 10, jog 6 (not in the spec: between walk and sprint), walk on Ctrl 3, still 0,
# hidden 0.
# Keys (physical, in _unhandled_input): [F] flashlight (not while hidden); [E] leave the spot while hidden, else the level's
# interact_hook (a Callable returning true when it used the key: fuses, pickups), else hide in the nearest usable spot.
# Mouse motion while hidden turns the peek camera.
# hide_in(spot): every stalker that sees the player now gets notice_hide(spot) (it will check the spot), then the player
# disappears (process off, invisible, flashlight off), the spot's peek camera becomes current, breath starts.
# leave_hiding(): the player is back at the spot's exit point facing out, with its own camera, and LEAVE_GRACE_S of catch
# grace. While hidden a left click recaptures the mouse (the process-disabled player cannot).
# Hold breath (H-D4): while hidden, holding Shift holds the breath: breath_left (BREATH_MAX_S = 15 s, owner: 6 s was too short) drains 1 s per s and
# refills BREATH_REFILL_PER_S (2 s per s) once released. A stalker within BREATH_HEAR_R (3 m) of the spot for BREATH_HEAR_S hears the breathing
# unless it is held and investigates the spot. Running out, or releasing while a stalker is within GASP_NEAR_R (2 m), is a
# loud gasp (StoryAudio "gasp"): the nearest stalker investigates the spot (caught if still inside) when it is within
# GASP_HEAR_R (8 m) and its graph route to the spot is at most GASP_ROUTE_M (no hearing through a wall into the next room).
# Holding needs a fresh press: Shift already down when entering (the sprint in) or after running out must be let go
# first; entering also gives HEAR_ENTER_GRACE s more before a stalker can hear the breathing. hold_override (tests)
# replaces the key.
class_name HorrorKit
extends Node

signal caught(stalker: HorrorStalker)
signal hide_changed(spot: HidingSpot)
signal gasped(reason: String)
signal breath_heard(stalker: HorrorStalker)

const NOISE_SPRINT: float = 10.0
const NOISE_JOG: float = 6.0
const NOISE_WALK: float = 3.0
const PLAYER_LAYER: int = 2
const SLOW_DT: float = 0.1
const MOUSE_SENS: float = 0.0022
## Catch grace after leaving a hiding spot (s): stepping out next to an unseen stalker is not an instant catch.
const LEAVE_GRACE_S: float = 0.75
const BREATH_MAX_S: float = 15.0
## Breath regained per second once released (or out of hiding).
const BREATH_REFILL_PER_S: float = 2.0
const BREATH_HEAR_R: float = 3.0
const BREATH_HEAR_S: float = 0.5
const GASP_NEAR_R: float = 2.0
const GASP_HEAR_R: float = 8.0
const GASP_ROUTE_M: float = 12.0
const HEAR_ENTER_GRACE: float = 0.5

var player: ThirdPersonController = null
var flashlight: HorrorFlashlight = null
var scare: ScareDirector = null
var graph: HorrorNavGraph = null
var senses := HorrorSenses.new()
var stalkers: Array[HorrorStalker] = []
var spots: Array[HidingSpot] = []
var hidden_spot: HidingSpot = null
var catch_enabled: bool = true:
	set(v):
		catch_enabled = v
		for s: HorrorStalker in stalkers:
			s.catch_enabled = v
## false: keys are ignored (cutscene, caught, escaped).
var input_enabled: bool = true
## Level's [E] handler: () -> bool (true = used).
var interact_hook: Callable = Callable()
## Level's prompt: () -> String ("" = none); wins over the hide prompt when not empty.
var prompt_hook: Callable = Callable()
var prompt: String = ""
var nearest_dist: float = INF
## Hold breath (H-D4): seconds of breath left, whether it is held now, gasps so far, why the last one happened.
var breath_left: float = BREATH_MAX_S
var breath_held: bool = false
var gasps: int = 0
var last_gasp: String = ""
## Tests: null = the Shift key; true / false = held / not held.
var hold_override: Variant = null
var _slow: float = 0.0
var _need_release: bool = false
var _hear_t: float = 0.0
var _near_s: HorrorStalker = null
var _near_d: float = INF


func _init() -> void:
	name = "HorrorKit"
	process_physics_priority = -10   # senses before the stalkers move


func setup(p: ThirdPersonController, fl: HorrorFlashlight, sd: ScareDirector, g: HorrorNavGraph) -> void:
	player = p
	flashlight = fl
	scare = sd
	graph = g
	if player != null:
		player.collision_layer = PLAYER_LAYER
		player.collision_mask = 1
	if flashlight != null and player != null:
		flashlight.anchor = player
		flashlight.aim = player.camera
	if scare != null:
		scare.player = player
		if flashlight != null:
			flashlight.gentle = scare.reduce_scares


func add_stalker(s: HorrorStalker) -> void:
	stalkers.append(s)
	s.senses = senses
	s.catch_enabled = catch_enabled
	if not s.caught_player.is_connected(_on_caught):
		s.caught_player.connect(_on_caught)


func add_spot(spot: HidingSpot) -> void:
	spots.append(spot)


func is_hidden() -> bool:
	return hidden_spot != null


## Hearing radius of the player's current movement (m).
func player_noise() -> float:
	if player == null or hidden_spot != null:
		return 0.0
	var v: float = player.horizontal_speed
	if v < 0.3:
		return 0.0
	if player.is_sprinting and v > ThirdPersonController.JOG_SPEED + 0.3:
		return NOISE_SPRINT
	if v <= ThirdPersonController.WALK_SPEED + 0.35:
		return NOISE_WALK
	return NOISE_JOG


## Player feet (or the spot's exit point while hidden).
func player_position() -> Vector3:
	if hidden_spot != null:
		return hidden_spot.exit_point()
	return player.global_position if player != null and player.is_inside_tree() else Vector3.ZERO


func update_senses() -> void:
	senses.pos = player_position()
	senses.hidden = hidden_spot != null
	senses.spot = hidden_spot
	senses.lit = flashlight != null and flashlight.is_lit() and hidden_spot == null
	senses.noise = player_noise()


func nearest_stalker_dist() -> float:
	var best: float = INF
	var p: Vector3 = senses.pos
	for s: HorrorStalker in stalkers:
		if not s.is_inside_tree() or s.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var d: Vector3 = s.global_position - p
		best = minf(best, Vector2(d.x, d.z).length())
	return best


## The usable hiding spot nearest to p, or null.
func nearest_spot(p: Vector3) -> HidingSpot:
	var best: HidingSpot = null
	var bd: float = INF
	for s: HidingSpot in spots:
		if s.occupied or not s.can_use(p):
			continue
		var d: float = s.exit_point().distance_squared_to(p)
		if d < bd:
			bd = d
			best = s
	return best


func _physics_process(delta: float) -> void:
	senses.grace = maxf(0.0, senses.grace - delta)
	update_senses()
	update_breath(delta)
	_slow += delta
	if _slow >= SLOW_DT:
		_slow = 0.0
		nearest_dist = nearest_stalker_dist()
		if scare != null:
			scare.set_threat(nearest_dist, hidden_spot != null)
		prompt = prompt_text()


func breath_frac() -> float:
	return breath_left / BREATH_MAX_S


func _hold_input() -> bool:
	if hold_override != null:
		return bool(hold_override)
	return input_enabled and Input.is_physical_key_pressed(KEY_SHIFT)


## The stalker nearest to the hidden spot (flat) into _near_s / _near_d (null / INF when none). No allocation.
func _nearest_to_spot() -> void:
	_near_s = null
	_near_d = INF
	if hidden_spot == null:
		return
	var p: Vector3 = hidden_spot.global_position
	for s: HorrorStalker in stalkers:
		if s.frozen or not s.is_inside_tree() or s.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var d: float = Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length()
		if d < _near_d:
			_near_d = d
			_near_s = s


## Walking distance from a to b on the level graph (flat distance without a graph). Only on a gasp (it allocates).
func route_len(a: Vector3, b: Vector3) -> float:
	if graph == null:
		return Vector2(b.x - a.x, b.z - a.z).length()
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state if player != null and player.is_inside_tree() else null
	var pts: PackedVector3Array = graph.route(a, b, space)
	var total: float = 0.0
	var prev: Vector3 = a
	for q: Vector3 in pts:
		total += Vector2(q.x - prev.x, q.z - prev.z).length()
		prev = q
	return total


## Breath while hidden (every physics frame; tests call it directly). Out of hiding the breath refills.
func update_breath(delta: float) -> void:
	if hidden_spot == null:
		breath_held = false
		_hear_t = 0.0
		_need_release = false
		breath_left = minf(BREATH_MAX_S, breath_left + delta * BREATH_REFILL_PER_S)
		return
	var want: bool = _hold_input()
	if _need_release and not want:
		_need_release = false
	var holding: bool = false
	var ran_out: bool = false
	if want and not _need_release and breath_left > 0.0:
		breath_left = maxf(0.0, breath_left - delta)
		holding = true
		if breath_left <= 0.0:
			ran_out = true
			holding = false
			_need_release = true
	else:
		breath_left = minf(BREATH_MAX_S, breath_left + delta * BREATH_REFILL_PER_S)
	_nearest_to_spot()
	var ns: HorrorStalker = _near_s
	var nd: float = _near_d
	if ran_out:
		_gasp("empty", ns, nd)
	elif breath_held and not holding and nd <= GASP_NEAR_R:
		_gasp("release", ns, nd)
	breath_held = holding
	if scare != null:
		scare.breath_held = holding
	# a stalker right next to the spot hears the breathing unless it is held
	if not holding and ns != null and nd <= BREATH_HEAR_R and not (ns.state == HorrorStalker.CHECK and ns.check_spot == hidden_spot):
		_hear_t += delta
		if _hear_t >= BREATH_HEAR_S:
			_hear_t = 0.0
			if ns.investigate_spot(hidden_spot):
				breath_heard.emit(ns)
	else:
		_hear_t = minf(_hear_t + delta, 0.0)   # the entry grace burns off; a hearing in progress resets


func _gasp(reason: String, ns: HorrorStalker, nd: float) -> void:
	gasps += 1
	last_gasp = reason
	if scare != null:
		scare.play_cue("gasp", -2.0)
	if ns != null and nd <= GASP_HEAR_R and route_len(ns.global_position, hidden_spot.exit_point()) <= GASP_ROUTE_M:
		ns.investigate_spot(hidden_spot)
	gasped.emit(reason)


## The current [E] / [F] prompt: hidden "[E] Ra", the level's prompt, a usable spot "[E] Trốn", else "".
func prompt_text() -> String:
	if hidden_spot != null:
		return "[E] Ra"
	if prompt_hook.is_valid():
		var t: String = String(prompt_hook.call())
		if t != "":
			return t
	if player != null and nearest_spot(player.global_position) != null:
		return "[E] Trốn"
	return ""


## Hides the player in `spot` (must be within its USE_RADIUS). Returns true when hidden.
func hide_in(spot: HidingSpot) -> bool:
	if spot == null or hidden_spot != null or spot.occupied or player == null:
		return false
	if not spot.can_use(player.global_position):
		return false
	update_senses()
	for s: HorrorStalker in stalkers:
		s.notice_hide(spot)
	hidden_spot = spot
	spot.occupied = true
	breath_held = false
	_need_release = _hold_input()   # Shift still down from the sprint in: holding needs a fresh press
	_hear_t = -HEAR_ENTER_GRACE
	player.velocity = Vector3.ZERO
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if flashlight != null:
		flashlight.set_on(false)
	spot.peek_reset()
	spot.peek_cam.make_current()   # no door swing on the way in: the peek camera sits just outside the door
	update_senses()
	if scare != null:
		scare.set_hidden(true)
	hide_changed.emit(spot)
	return true


## Back out of the current spot. Returns true when the player was hidden.
func leave_hiding() -> bool:
	if hidden_spot == null:
		return false
	var spot: HidingSpot = hidden_spot
	hidden_spot = null
	spot.occupied = false
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.teleport(spot.exit_point(), spot.exit_yaw())
	if player.camera != null:
		player.camera.make_current()
	if not spot.revealed:
		spot.swing()
	senses.grace = LEAVE_GRACE_S
	update_senses()
	if scare != null:
		scare.set_hidden(false)
	hide_changed.emit(null)
	return true


## [E]: leave, the level's hook, or hide. Returns true when something happened.
func interact() -> bool:
	if hidden_spot != null:
		return leave_hiding()
	if interact_hook.is_valid() and bool(interact_hook.call()):
		return true
	if player != null:
		var s: HidingSpot = nearest_spot(player.global_position)
		if s != null:
			return hide_in(s)
	return false


func toggle_flashlight() -> bool:
	if flashlight == null or hidden_spot != null:
		return false
	return flashlight.toggle()


func _on_caught(s: HorrorStalker) -> void:
	for o: HorrorStalker in stalkers:
		o.frozen = true
	caught.emit(s)


## Freezes or unfreezes every stalker (cutscenes, the end).
func set_frozen(on: bool) -> void:
	for s: HorrorStalker in stalkers:
		s.frozen = on


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed or k.echo:
			return
		if k.physical_keycode == KEY_F:
			toggle_flashlight()
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_E:
			interact()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and hidden_spot != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		hidden_spot.peek_look(-mm.relative.x * MOUSE_SENS, -mm.relative.y * MOUSE_SENS)
	elif event is InputEventMouseButton and hidden_spot != null:
		# the player node is process-disabled while hidden: recapture the mouse here (after a pause menu freed it)
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE 				and player != null and player.capture_on_click:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
