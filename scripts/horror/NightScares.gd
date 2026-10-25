# File: res://scripts/horror/NightScares.gd
# Scripted scare events across the Night Building (owner: "jumpscare chưa đủ": more scares at other places, not only when
# caught). Seeded spots chosen from candidates at build; each face event fires at most once per run (a retry does not bring
# it back); they never catch the player.
#   window_slam   a sheep face slams against a corridor window from the courtyard side as the player passes (ScareSlam)
#   ceiling_drop  in a classroom, with the flashlight on, a sheep figure drops upside down from the ceiling into the beam
#                 for DROP_HOLD_S, then pulls back up
#   locker_lunge  a locker next to the player bursts open, a clone's face lunges out to about 0.5 m (ScareDirector
#                 play_face_scare "lunge"), shrinks back in and the door slams
#   flash_cut     the flashlight dies for CUT_S; when it comes back a clone stands 1 m in front for 0.5 s, dark again, gone
#   behind_you    the camera turns more than 150 degrees within 0.5 s in a corridor: a figure stands 1.5 m in front (where
#                 the player now looks); it goes when the flashlight beam hits it or after BEHIND_S
#   mirror        facing the toilet mirror: a sheep stands behind the player in it; looking away, it is gone
#   screen        a classroom TV above the whiteboard turns on by itself with a static sheep face and a static burst
#   The face events use jump scare v2 (the event duck, the snap, the +8 dB sting, the screen hit).
# Atmosphere (no face, every ATMO_GAP s): a door slams, the school bell rings, a PA whisper "Lọ... Thần...", the player's
# phone rings ("Số lạ"; in a corridor only): the ring is a noise the hunters within PHONE_NOISE_R hear; it stops after
# PHONE_S or on [P] (stop_phone). The fake-outs (coat, cat) count as atmosphere (they push the next one back).
# Budget: at most FACE_MAX face events per run, FACE_GAP_S apart; never while blocked(): a chase, hidden, a catch or another
# face scare, the WC monologue, the alarm sprint. "Giảm hù dọa": face events are only a soft sound (no figure, snap, flash
# or boom); the atmosphere stays, quieter (horror cues -6 dB). Pooled figure, no light node; checks at 10 Hz.
# log (tests): "<kind>@<clock>", "atmo:<kind>@<clock>".
class_name NightScares
extends Node3D

const FACE_KINDS: Array[String] = ["window_slam", "ceiling_drop", "locker_lunge", "flash_cut", "behind_you", "mirror", "screen"]
const ATMO_KINDS: Array[String] = ["door_slam", "bell", "pa_whisper", "phone"]
const FACE_MAX: int = 5
const FACE_GAP_S: float = 38.0
const ATMO_GAP := Vector2(20.0, 40.0)
const CHECK_S: float = 0.1
const WINDOW_R: float = 3.5
const LOCKER_R: float = 1.6
const CUT_R: float = 4.0
const CUT_S: float = 1.0
const MIRROR_R: float = 3.5
const MIRROR_DEG: float = 35.0
const CEILING_LIT_S: float = 1.0
const DROP_HOLD_S: float = 0.6
const BEHIND_S: float = 0.6
const TURN_DEG: float = 150.0
const TURN_S: float = 0.5
const PHONE_S: float = 2.0
const PHONE_NOISE_R: float = 14.0
const T_WHISPER: String = "Lọ... Thần..."
const T_PHONE: String = "Số lạ đang gọi... [P] tắt máy"
## Windows on the courtyard side: [x, z, out_x, out_z] (out = towards the courtyard).
const WINDOW_SPOTS: Array = [[-20.0, -15.0, 0.0, 1.0], [8.0, -15.0, 0.0, 1.0], [-8.0, 15.0, 0.0, -1.0], [20.0, 15.0, 0.0, -1.0],
	[-30.0, -6.0, 1.0, 0.0], [30.0, 6.0, -1.0, 0.0]]
const CUT_SPOTS: Array = [[-18.0, -16.5], [18.0, 16.5], [-31.5, -8.0], [31.5, 8.0]]
const CLASSROOMS: Array[String] = ["C1", "C2", "C3", "C4", "C5", "C6"]

var level: Node = null
var kit: HorrorKit = null
var scare: ScareDirector = null
var flashlight: HorrorFlashlight = null
var player: ThirdPersonController = null
var hud: HorrorHUD = null
var enabled: bool = true
var rng := RandomNumberGenerator.new()
## kind -> {data..., "fired": bool}
var events: Dictionary = {}
var log: Array[String] = []
var face_count: int = 0
var last_face_t: float = -INF
var atmo_next_t: float = 0.0
var active: String = ""
var phone_ringing: bool = false
var figure: Node3D = null
var slam: ScareSlam = null
var mirror_fig: Node3D = null
var screen_mat: StandardMaterial3D = null
var _t: float = 0.0
var _check_t: float = 0.0
var _lit_t: float = 0.0
var _phone_t: float = 0.0
var _phone: AudioStreamPlayer = null
var _yaws: Array[Vector2] = []   # (clock, camera yaw) samples for the turn check
var _yaw_t: float = 0.0
var _light_was_on: bool = false
var _spot_used: HidingSpot = null


func _init() -> void:
	name = "NightScares"


func setup(lvl: Node, seed_val: int) -> void:
	level = lvl
	kit = lvl.get("kit")
	scare = lvl.get("scare")
	flashlight = lvl.get("flashlight")
	player = lvl.get("player")
	hud = lvl.get("hud")
	rng.seed = seed_val * 92821 + 17
	atmo_next_t = scare.clock + rng.randf_range(ATMO_GAP.x, ATMO_GAP.y)
	var w: Array = WINDOW_SPOTS[rng.randi_range(0, WINDOW_SPOTS.size() - 1)]
	events["window_slam"] = {"at": Vector3(float(w[0]) + float(w[2]) * 0.12, 1.6, float(w[1]) + float(w[3]) * 0.12),
		"out": Vector3(float(w[2]), 0.0, float(w[3])), "near": Vector3(float(w[0]) - float(w[2]) * 1.5, 0.0, float(w[1]) - float(w[3]) * 1.5)}
	var rooms: Array = CLASSROOMS.duplicate()
	_shuffle(rooms)
	events["ceiling_drop"] = {"room": String(rooms[0])}
	events["screen"] = {"room": String(rooms[1])}
	var lockers: Array[HidingSpot] = []
	for s: HidingSpot in kit.spots:
		if s.kind == "locker":
			lockers.append(s)
	events["locker_lunge"] = {"spot": lockers[rng.randi_range(0, lockers.size() - 1)] if not lockers.is_empty() else null}
	var c: Array = CUT_SPOTS[rng.randi_range(0, CUT_SPOTS.size() - 1)]
	events["flash_cut"] = {"pos": Vector3(float(c[0]), 0.0, float(c[1]))}
	events["behind_you"] = {}
	var wc: String = ["WCA", "WCB"][rng.randi_range(0, 1)]
	events["mirror"] = {"room": wc, "pos": mirror_pos(wc)}
	for k: String in events.keys():
		(events[k] as Dictionary)["fired"] = false
	_build_props()


func _shuffle(a: Array) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## The toilet mirror of block `id` (as NightBuildingMap builds it): its centre (1.6 m up) on the back wall.
static func mirror_pos(id: String) -> Vector3:
	var r: Dictionary = NightBuildingMap.room_by_id(id)
	var door_lx: float = float(r["door"]) - (float(r["x0"]) + float(r["x1"])) * 0.5
	var sgn: float = -signf(door_lx)
	return NightBuildingMap.room_pt(r, -sgn * 3.2, 8.85, 1.6)


func _build_props() -> void:
	# the pooled figure: a clone body with the scare mask on its head
	figure = StoryCast.build("clone")
	if figure != null:
		figure.name = "ScareEventFigure"
		add_child(figure)
		var head: Node3D = CharacterBuilder.get_pivot(figure, "head")
		var m: Node3D = ScareFace.build_scare_mask()
		if head != null:
			head.add_child(m)
			var hs: float = maxf(head.scale.y, 0.01)
			m.position = Vector3(0.0, 0.1 / hs, 0.0)
			m.scale = Vector3.ONE / hs * 1.05
		else:
			figure.add_child(m)
			m.position = Vector3(0.0, 1.62, 0.0)
		_hide_figure()
	slam = ScareSlam.new()
	add_child(slam)
	slam.done.connect(_end_event)
	# the mirror's sheep: a small mask and dark shoulders laid on the mirror
	mirror_fig = Node3D.new()
	mirror_fig.name = "MirrorSheep"
	add_child(mirror_fig)
	mirror_fig.add_child(ScareFace.build_scare_mask())
	ScareFace._box(mirror_fig, "Shoulders", Vector3(0.42, 0.22, 0.08), Vector3(0.0, -0.27, 0.03), ScareFace._mat(Color("#14161A"), 1.0))
	mirror_fig.visible = false
	# the classroom TV above the whiteboard (dark until it turns itself on)
	var r: Dictionary = NightBuildingMap.room_by_id(String((events["screen"] as Dictionary)["room"]))
	var tv := MeshInstance3D.new()
	tv.name = "ScareTV"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.85, 0.04)
	tv.mesh = bm
	screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color("#0B0D10")
	screen_mat.emission_enabled = true
	screen_mat.emission = Color.WHITE
	screen_mat.emission_texture = static_texture()
	screen_mat.emission_energy_multiplier = 0.0
	tv.material_override = screen_mat
	add_child(tv)
	tv.position = NightBuildingMap.room_pt(r, 0.0, 8.82, 2.85)
	tv.rotation.y = 0.0 if float(r["side"]) < 0.0 else PI
	(events["screen"] as Dictionary)["pos"] = tv.position


## A static-noise TV picture with a sheep face in it (64 x 40, drawn in code).
static func static_texture() -> ImageTexture:
	var img := Image.create(64, 40, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 1313
	for y: int in 40:
		for x: int in 64:
			var v: float = r.randf_range(0.15, 0.75)
			var dx: float = (float(x) - 32.0) / 11.0
			var dy: float = (float(y) - 20.0) / 15.0
			if dx * dx + dy * dy < 1.0:
				v = v * 0.4 + 0.55   # the pale face
				for ex: float in [-4.5, 4.5]:
					if Vector2(float(x) - 32.0 - ex, float(y) - 17.0).length() < 2.6:
						v = 0.02   # the black eyes
				if absf(float(x) - 32.0) < 3.0 and absf(float(y) - 28.0) < 1.0:
					v = 0.05   # the mouth
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


func _hide_figure() -> void:
	if figure != null:
		figure.visible = false
		figure.process_mode = Node.PROCESS_MODE_DISABLED


func _show_figure(pos: Vector3, face_to: Vector3, upside_down: bool = false) -> void:
	if figure == null:
		return
	figure.process_mode = Node.PROCESS_MODE_INHERIT
	figure.visible = true
	var d: Vector3 = face_to - pos
	figure.global_position = pos
	figure.rotation = Vector3(0.0, atan2(-d.x, -d.z), PI if upside_down else 0.0)
	CharacterBuilder.set_speed(figure, 0.0)


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------
## No scare events now: a chase, hidden, a catch or another face scare, the WC monologue, the alarm sprint, not playing.
func blocked() -> bool:
	if not enabled or String(level.get("state")) != "play" or kit.is_hidden() or scare.scare_busy():
		return true
	if bool(level.get("alarm")):
		return true
	var wc: Variant = level.get("wc")
	if wc != null and is_instance_valid(wc) and bool((wc as Object).get("running")):
		return true
	for s: HorrorStalker in level.get("stalkers"):
		if s.state == HorrorStalker.CHASE:
			return true
	return false


func face_budget_ok() -> bool:
	return face_count < FACE_MAX and scare.clock - last_face_t >= FACE_GAP_S


static func in_corridor(p: Vector3) -> bool:
	var ax: float = absf(p.x)
	var az: float = absf(p.z)
	return ax <= NightBuildingMap.COR_X and az <= NightBuildingMap.COR_Z and (ax >= NightBuildingMap.CY_X or az >= NightBuildingMap.CY_Z)


static func in_room(p: Vector3, id: String) -> bool:
	var r: Dictionary = NightBuildingMap.room_by_id(id)
	if r.is_empty():
		return false
	var z: float = p.z * float(r["side"])
	return p.x >= float(r["x0"]) and p.x <= float(r["x1"]) and z >= NightBuildingMap.COR_Z + 0.5 and z <= NightBuildingMap.OUT_Z


func _cam() -> Camera3D:
	return player.camera if player != null else null


func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Camera yaw (radians) of where the player looks.
func cam_yaw() -> float:
	var c: Camera3D = _cam()
	if c == null or not c.is_inside_tree():
		return 0.0
	var f: Vector3 = -c.global_transform.basis.z
	return atan2(-f.x, -f.z)


## Records a camera yaw sample (every physics frame; tests feed it directly).
func note_yaw(clock_t: float, yaw: float) -> void:
	_yaws.append(Vector2(clock_t, yaw))
	while not _yaws.is_empty() and clock_t - _yaws[0].x > TURN_S:
		_yaws.remove_at(0)


## The camera turned more than TURN_DEG within TURN_S.
func turned_around() -> bool:
	if _yaws.size() < 2:
		return false
	var now: float = _yaws.back().y
	for v: Vector2 in _yaws:
		if absf(wrapf(now - v.y, -PI, PI)) > deg_to_rad(TURN_DEG):
			return true
	return false


## Whether the trigger condition of face event `kind` holds now (not counting the budget or blocked()).
func conditions_met(kind: String) -> bool:
	var e: Dictionary = events.get(kind, {})
	if e.is_empty() or bool(e["fired"]) or player == null:
		return false
	var p: Vector3 = player.global_position
	match kind:
		"window_slam":
			return _flat_d(p, e["near"]) <= WINDOW_R and in_corridor(p)
		"ceiling_drop":
			return in_room(p, String(e["room"])) and _lit_t >= CEILING_LIT_S
		"locker_lunge":
			var sp: HidingSpot = e["spot"]
			return sp != null and _flat_d(p, sp.exit_point()) <= LOCKER_R
		"flash_cut":
			return flashlight.is_lit() and _flat_d(p, e["pos"]) <= CUT_R
		"behind_you":
			return in_corridor(p) and turned_around()
		"mirror":
			var mp: Vector3 = e["pos"]
			if _flat_d(p, mp) > MIRROR_R or not in_room(p, String(e["room"])):
				return false
			var c: Camera3D = _cam()
			var f: Vector3 = -c.global_transform.basis.z
			var to: Vector3 = mp - c.global_position
			f.y = 0.0
			to.y = 0.0
			return f.length_squared() > 1e-6 and f.angle_to(to) <= deg_to_rad(MIRROR_DEG)
		"screen":
			return in_room(p, String(e["room"])) and _flat_d(p, e["pos"]) <= 8.0
	return false


## Fires face event `kind` now if allowed (budget, gap, not blocked, not fired). true when it started.
func trigger(kind: String) -> bool:
	var e: Dictionary = events.get(kind, {})
	if e.is_empty() or bool(e["fired"]) or active != "" or blocked() or not face_budget_ok():
		return false
	e["fired"] = true
	face_count += 1
	last_face_t = scare.clock
	log.append("%s@%.1f" % [kind, scare.clock])
	active = kind
	_t = 0.0
	if scare.reduce_scares:   # a soft sound only
		scare.play_cue("metal_creak", -8.0)
		active = ""
		return true
	match kind:
		"window_slam":
			slam.start(scare, e["at"], e["out"], player.global_position, 2.2)
		"locker_lunge":
			_spot_used = e["spot"]
			_spot_used.swing(true)
			scare.play_cue("locker_slam", -2.0)
			scare.play_face_scare("open", "lunge", false)
		"flash_cut":
			_light_was_on = flashlight.on
			flashlight.set_on(false)
			scare.play_cue("static_burst", -10.0)
		"behind_you":
			var c: Camera3D = _cam()
			var f: Vector3 = -c.global_transform.basis.z
			f.y = 0.0
			f = f.normalized()
			_show_figure(player.global_position + f * 1.5, player.global_position)
			scare.loud_sting()
			scare.screen_hit()
		_:
			scare.event_duck(true)   # ceiling_drop, mirror, screen: the duck, then the hit
	return true


func _end_event() -> void:
	scare.event_duck(false)
	_hide_figure()
	if mirror_fig != null:
		mirror_fig.visible = false
	if screen_mat != null:
		screen_mat.emission_energy_multiplier = 0.0
	if active == "flash_cut" and _light_was_on and flashlight.battery > 0.0:
		flashlight.set_on(true)
	active = ""


## Ends a running event at once (retry, release): nothing stays out there.
func cancel() -> void:
	if slam != null:
		slam.stop()
	if active == "locker_lunge" and _spot_used != null:
		_spot_used.reset_spot()
	_end_event()
	stop_phone()


func _update_active(delta: float) -> void:
	if active == "":
		return
	_t += delta
	var d: float = ScareDirector.DUCK_S
	match active:
		"window_slam":
			pass   # ScareSlam ends it (done)
		"locker_lunge":
			if _t >= d + ScareFace.SNAP_S + ScareFace.HOLD_S + ScareFace.RETREAT_S + 0.05:
				_spot_used.reset_spot()
				scare.play_cue("locker_slam", 0.0)   # the door slams shut
				_end_event()
		"ceiling_drop":
			var c: Camera3D = _cam()
			if _t >= d and not figure.visible:
				var f: Vector3 = -c.global_transform.basis.z
				f.y = 0.0
				f = f.normalized()
				var at: Vector3 = player.global_position + f * 2.2
				_show_figure(Vector3(at.x, NightBuildingMap.H + 1.0, at.z), player.global_position, true)
				(events["ceiling_drop"] as Dictionary)["drop_at"] = Vector3(at.x, NightBuildingMap.H, at.z)
				scare.loud_sting()
				scare.screen_hit()
			if figure.visible:
				var top: Vector3 = (events["ceiling_drop"] as Dictionary)["drop_at"]
				var u: float = _t - d
				var y: float = top.y
				if u < 0.12:
					y = top.y + 1.0 - 1.0 * ScareFace._ease_out_back(u / 0.12)
				elif u > 0.12 + DROP_HOLD_S:
					y = top.y + 1.2 * clampf((u - 0.12 - DROP_HOLD_S) / 0.25, 0.0, 1.0)
				figure.global_position = Vector3(top.x, y, top.z)
				if u > 0.12 and u < 0.12 + DROP_HOLD_S:
					figure.rotation.x = rng.randf_range(-0.12, 0.12)
				if u >= 0.12 + DROP_HOLD_S + 0.25:
					_end_event()
		"flash_cut":
			if _t >= CUT_S - d and _t < CUT_S:
				scare.event_duck(true)
			if _t >= CUT_S and not figure.visible and _t < CUT_S + 0.5:
				var c2: Camera3D = _cam()
				var f2: Vector3 = -c2.global_transform.basis.z
				f2.y = 0.0
				f2 = f2.normalized()
				flashlight.set_on(true)
				_show_figure(player.global_position + f2 * 1.0, player.global_position)
				scare.loud_sting()
				scare.screen_hit()
			if _t >= CUT_S + 0.5 and figure.visible:
				flashlight.set_on(false)
				_hide_figure()
			if _t >= CUT_S + 0.8:
				_end_event()
		"behind_you":
			var lit_on_it: bool = false
			if flashlight.is_lit() and figure.visible:
				var c3: Camera3D = _cam()
				var to: Vector3 = figure.global_position + Vector3(0.0, 1.2, 0.0) - c3.global_position
				lit_on_it = (-c3.global_transform.basis.z).angle_to(to) < deg_to_rad(20.0)
			if lit_on_it or _t >= BEHIND_S:
				_end_event()
		"mirror":
			var c4: Camera3D = _cam()
			var mp: Vector3 = (events["mirror"] as Dictionary)["pos"]
			if _t >= d and not mirror_fig.visible and _t < d + 0.05:
				_place_mirror_sheep(c4, mp)
				scare.loud_sting(["violin_screech", "static_burst"])
				scare.screen_hit()
			var f4: Vector3 = -c4.global_transform.basis.z
			var to4: Vector3 = mp - c4.global_position
			f4.y = 0.0
			to4.y = 0.0
			if _t >= d and (f4.angle_to(to4) > deg_to_rad(70.0) or _t >= d + 3.0):
				_end_event()   # turned round: nothing there
		"screen":
			if _t >= d and screen_mat.emission_energy_multiplier <= 0.0 and _t < d + 0.05:
				screen_mat.emission_energy_multiplier = 2.6
				scare.play_cue("static_burst", 2.0)
				scare.loud_sting(["static_burst", "sheep_bleat_distorted"])
				scare.screen_hit()
			if screen_mat.emission_energy_multiplier > 0.0:
				screen_mat.uv1_offset = Vector3(rng.randf(), rng.randf(), 0.0)   # the static jitters
			if _t >= d + 1.2:
				_end_event()


## Lays the mirror's sheep on the mirror where someone standing 1 m behind the player would show.
func _place_mirror_sheep(c: Camera3D, mp: Vector3) -> void:
	var f: Vector3 = -c.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var behind: Vector3 = player.global_position - f * 1.0 + Vector3(0.0, 1.55, 0.0)
	var wall_z: float = mp.z - signf(mp.z) * 0.03
	var refl := Vector3(behind.x, behind.y, 2.0 * wall_z - behind.z)   # behind the player, seen in the mirror
	var cp: Vector3 = c.global_position
	var k: float = (wall_z - cp.z) / (refl.z - cp.z) if absf(refl.z - cp.z) > 0.01 else 0.5
	var on_glass: Vector3 = cp.lerp(refl, clampf(k, 0.0, 1.0))
	on_glass.x = clampf(on_glass.x, mp.x - 1.4, mp.x + 1.4)
	on_glass.y = clampf(on_glass.y, mp.y - 0.3, mp.y + 0.35)
	mirror_fig.global_position = on_glass
	mirror_fig.scale = Vector3.ONE * clampf(k, 0.25, 0.9)
	mirror_fig.rotation = Vector3(0.0, 0.0 if mp.z > 0.0 else PI, 0.0)
	mirror_fig.visible = true


# ---------------------------------------------------------------------------
# Atmosphere
# ---------------------------------------------------------------------------
## Fires an atmospheric event (kind "" = a seeded pick; the phone only in a corridor). Returns the kind ("" = none).
func fire_atmo(kind: String = "") -> String:
	if kind == "":
		var pool: Array[String] = ["door_slam", "bell", "pa_whisper"]
		if in_corridor(player.global_position) and not phone_ringing:
			pool.append("phone")
		kind = pool[rng.randi_range(0, pool.size() - 1)]
	log.append("atmo:%s@%.1f" % [kind, scare.clock])
	atmo_next_t = scare.clock + rng.randf_range(ATMO_GAP.x, ATMO_GAP.y)
	match kind:
		"door_slam":
			scare.play_cue("locker_slam", -1.0)
			scare.play_cue("metal_creak", -8.0)
			scare.flicker_near(player.global_position, 0.8)
		"bell":
			scare.play_cue("school_bell", -6.0)
		"pa_whisper":
			scare.play_cue("whisper_bed", -2.0)
			if hud != null:
				hud.subtitle(T_WHISPER, 2.5)
		"phone":
			_ring()
	return kind


func _ring() -> void:
	phone_ringing = true
	_phone_t = PHONE_S
	if _phone == null:
		_phone = AudioStreamPlayer.new()
		_phone.name = "PhoneRing"
		if AudioServer.get_bus_index("SFX") != -1:
			_phone.bus = "SFX"
		add_child(_phone)
	if StoryAudio.ready_for(["phone_ring_3am"]):
		_phone.stream = StoryAudio.stream_once("phone_ring_3am")
		_phone.volume_db = scare.cue_db("phone_ring_3am")
		_phone.play()
	if hud != null:
		hud.toast(T_PHONE, PHONE_S)
	if level.has_method("noise_at"):
		level.call("noise_at", player.global_position, PHONE_NOISE_R)


## [P] or the PHONE_S timeout: the ringing stops.
func stop_phone() -> void:
	phone_ringing = false
	_phone_t = 0.0
	if _phone != null:
		_phone.stop()


## A fake-out (coat, cat) counts as atmosphere: the next atmospheric event comes a full gap later.
func on_fakeout(_kind: String) -> void:
	atmo_next_t = scare.clock + rng.randf_range(ATMO_GAP.x, ATMO_GAP.y)


# ---------------------------------------------------------------------------
func tick(delta: float) -> void:
	if phone_ringing:
		_phone_t -= delta
		if _phone_t <= 0.0:
			stop_phone()
	if player == null or not enabled:
		return
	_yaw_t -= delta
	if _yaw_t <= 0.0:
		_yaw_t = 0.05
		note_yaw(scare.clock, cam_yaw())
	_lit_t = _lit_t + delta if flashlight.is_lit() else 0.0
	_update_active(delta)
	if active != "":
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	if blocked():
		return
	if face_budget_ok():
		for k: String in FACE_KINDS:
			if conditions_met(k) and trigger(k):
				return
	if scare.clock >= atmo_next_t:
		fire_atmo()


func _physics_process(delta: float) -> void:
	tick(delta)
