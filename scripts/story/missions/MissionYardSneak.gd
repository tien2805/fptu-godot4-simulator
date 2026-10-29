# File: res://scripts/story/missions/MissionYardSneak.gd
# Day 3 sneak into the container yard (plan 2026-10-30-w3-day3.md T2), on MissionSneak's patrol / spotted / goal rules.
# Signature: THE FLOODLIGHT SWEEP. Two pole floodlights sweep the container canyon and the approach to the stack on a slow
# back-and-forth cycle: a visible unshaded cone (cyan) from the lamp to a disc on the floor, a shadowless SpotLight3D and
# the lamp's hum on the disc. A player inside a disc with a clear line from the lamp = spotted (the cone turns red, the
# early fight of MissionSneak); a container between the lamp and the player hides him. The first sweep opens with a
# 0.6 s preview cut on beam A.
# Something new every 15-20 s (clock, or earlier by proximity): the gate and Anh Duy's radio (0 s); the floodlights (1 s,
# the cut); the first patrol pair (15 s: a second guard walks patrol 0 a step behind; Thường only); a guard asleep on a
# pallet (Zzz, snoring; wakes on a sprint within WAKE_M or a hit; 30 s); a guard on his phone laughing at a video (half
# sight; 45 s); Alexander's parked forklift with the keys in it (a glint, the radio; 60 s, foreshadowing the joust); the
# stack (the goal). Telegraphs: guard footsteps within STEP_HEAR_M, the cone's hum.
# Every number goes through Difficulty.pick. Checks run at 10 Hz; the beams only move transforms per tick.
class_name MissionYardSneak
extends MissionSneak

const CHECK_DT: float = 0.1
const STEP_DT: float = 0.55
const STEP_HEAR_M: float = 14.0
const PREVIEW_AT: float = 1.0
## Yard-local beams: lamp (pole head), sweep end a, sweep end b, start phase (0 = at a).
const BEAMS: Array = [
	[Vector3(-14.0, 7.0, 17.6), Vector3(-19.0, 0.0, 7.0), Vector3(-7.0, 0.0, 7.0), 1.0],
	[Vector3(6.5, 7.0, -9.2), Vector3(-10.0, 0.0, -0.6), Vector3(2.0, 0.0, -0.6), 0.0],
]
const SLEEPER_AT := Vector3(-5.0, 0.0, 12.7)
const SLEEPER_YAW: float = 0.0
const PHONE_AT := Vector3(-14.5, 0.0, -4.2)
const PHONE_YAW: float = 180.0
const CYAN := Color(0.3, 0.95, 1.0, 0.16)
const RED := Color(1.0, 0.18, 0.12, 0.24)
const T_FLOOD: String = "Đèn pha quét bãi! Tránh vùng sáng, núp sau container"
const T_WOKE: String = "Ông ngủ gật dậy rồi!"
const T_FLOOD_SEEN: String = "Đèn pha rọi trúng! Bị lộ!"
const T_MORE: String = "Thêm bảo vệ chạy tới!"
const NEAR_ALERT_M: float = 16.0
## Events: [id, clock s, proximity point key ("" none), proximity m].
const EVENTS: Array = [["flood", PREVIEW_AT, "", 0.0], ["pair", 15.0, "", 0.0], ["sleeper", 30.0, "sleeper", 9.0],
	["phone", 45.0, "phone", 12.0], ["forklift", 60.0, "forklift", 10.0]]

var role_i: Dictionary = {}      # "sleeper" / "phone" -> index in fight.gunmen
var beams: Array = []            # {"lamp", "a", "b", "phase", "p", "root", "cone", "disc", "light", "mat", "dmat", "spot"}
var sweep_s: float = 7.0
var beam_r: float = 2.4
var wake_m: float = 6.0
var sleeper: Gunman = null
var phone_guard: Gunman = null
var asleep: bool = false
var flood_spotted: bool = false
var preview_cuts: int = 0
var events_done: Dictionary = {}
var steps_played: int = 0
var snores: int = 0
var _check_t: float = 0.0
var _step_t: Dictionary = {}     # Gunman -> s until its next step
var _snore_t: float = 0.0
var _laugh_t: float = 0.0
var _zzz: Label3D = null
var _haha: Label3D = null
var _keys: MeshInstance3D = null
var _beam_root: Node3D = null
## T9: the far guards still to come after a spot (nearest first), one every reinforce_s.
var reinforcements: Array = []
var markers: OffscreenMarkers = null
var reinforce_s: float = 5.0
var _reinforce_t: float = 0.0


func _init() -> void:
	armed = true
	keep_top = true          # T10: the objective line ("Đi lén...", then "Bị lộ! Còn N bảo vệ") stays on screen


func _start() -> void:
	sweep_s = float(Difficulty.pick(7.0, 9.0))
	beam_r = float(Difficulty.pick(2.4, 2.0))
	wake_m = float(Difficulty.pick(6.0, 4.5))
	reinforce_s = float(Difficulty.pick(4.0, 7.0))
	var pats: Array = (pts.get("patrols", []) as Array).duplicate(true)
	pts["patrols"] = []
	super._start()        # MissionSneak: the player placed, the fight made (an empty wave 0 for now), the radio, the goal
	pts["patrols"] = pats
	_fill_wave(pats)
	fight.retry()          # wave 0 spawned with every guard (the checkpoint is the start spot)
	_build_beams()
	_build_props()
	_bind_roles()
	# T10: the goal and (once seen) the guards stay findable: edge arrows off screen, a diamond over the goal
	markers = OffscreenMarkers.make(hud, player)
	var goal: Node3D = get_node_or_null("Goal") as Node3D
	if goal:
		markers.track(goal, "goal", "Container", 1.4)
	markers.threat_source = fight.alive


## Wave 0: MissionSneak's patrols (gunmen[0..2]), the pair partner (Thường: patrol 0 again, a step behind), the sleeper
## (ai off: the mission wakes him) and the phone guard (half sight, standing).
func _fill_wave(pats: Array) -> void:
	var w: Array = fight.waves[0]
	w.clear()
	var i: int = 0
	for p: Array in pats:
		w.append(guard(i, p[0], p[1], {"sight_m": HorrorStalker.SIGHT, "fov_deg": FOV_DEG, "alerted": false}))
		i += 1
	if bool(Difficulty.pick(true, false)) and not pats.is_empty():
		var route: Array = pats[0][1]
		var back: Vector3 = route[0]
		if route.size() > 1:
			back = (route[0] as Vector3) - ((route[1] as Vector3) - (route[0] as Vector3)).normalized() * 1.6
		w.append(guard(i, back, route, {"sight_m": HorrorStalker.SIGHT, "fov_deg": FOV_DEG, "alerted": false}))
		i += 1
	role_i = {"sleeper": i, "phone": i + 1}
	var sd: Dictionary = guard(i, _lair_world(SLEEPER_AT), [], {"ai": false})
	sd["yaw"] = _lair_yaw(SLEEPER_YAW)
	w.append(sd)
	var pd: Dictionary = guard(i + 1, _lair_world(PHONE_AT), [], {"sight_m": HorrorStalker.SIGHT * 0.5, "fov_deg": FOV_DEG, "alerted": false})
	pd["yaw"] = _lair_yaw(PHONE_YAW)
	w.append(pd)


## T9: the yard's guards aim a little better on Thường and worse on Dễ (a mission-level knob over the gun core's numbers;
## LairYard.GUARD_ACC).
func guard(i: int, at: Vector3, patrol: Array = [], extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = extra.duplicate()
	if not e.has("accuracy"):
		e["accuracy"] = LairYard.guard_accuracy(true)
	return super.guard(i, at, patrol, e)


func _lair_world(local: Vector3) -> Vector3:
	return (level.call("world", local) as Vector3) if level and level.has_method("world") else local


func _lair_yaw(deg: float) -> float:
	return float(level.call("world_yaw", deg)) if level and level.has_method("world_yaw") else deg_to_rad(deg)


func _bind_roles() -> void:
	sleeper = null
	phone_guard = null
	var gs: Array = fight.gunmen if fight else []
	var si: int = int(role_i.get("sleeper", -1))
	var pi: int = int(role_i.get("phone", -1))
	if si >= 0 and si < gs.size() and is_instance_valid(gs[si]):
		sleeper = gs[si]
	if pi >= 0 and pi < gs.size() and is_instance_valid(gs[pi]):
		phone_guard = gs[pi]
	asleep = sleeper != null and not sleeper.ai
	_attach_role_props()


func _on_wave_started(i: int) -> void:
	super._on_wave_started(i)
	if i == 0 and state == "running" and not role_i.is_empty():
		_bind_roles()


func _build_beams() -> void:
	_beam_root = Node3D.new()
	_beam_root.name = "Floodlights"
	add_child(_beam_root)
	beams.clear()
	for i: int in BEAMS.size():
		var bd: Array = BEAMS[i]
		var b: Dictionary = {"lamp": _lair_world(bd[0]), "a": _lair_world(bd[1]), "b": _lair_world(bd[2]),
			"phase0": float(bd[3])}
		b["a"].y = ground_y(b["a"])
		b["b"].y = ground_y(b["b"])
		var root := Node3D.new()
		root.name = "Beam%d" % i
		_beam_root.add_child(root)
		var mat := _beam_mat(CYAN)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.14
		cm.bottom_radius = beam_r
		cm.height = 1.0
		cm.radial_segments = 20
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		var cone := MeshInstance3D.new()
		cone.name = "Cone"
		cone.mesh = cm
		cone.material_override = mat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(cone)
		var dmat := _beam_mat(Color(CYAN.r, CYAN.g, CYAN.b, 0.32))
		var spot := Node3D.new()
		spot.name = "Spot"
		root.add_child(spot)
		var disc: MeshInstance3D = CineFX._cyl(spot, "Disc", beam_r, beam_r, 0.03, Vector3(0.0, 0.06, 0.0), dmat)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var head: MeshInstance3D = CineFX._box(root, "Head", Vector3(0.8, 0.35, 0.5), b["lamp"], CineFX._glow_mat(Color("#BFF6FF"), 3.0))
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		CineFX._box(root, "Pole", Vector3(0.18, b["lamp"].y - ground_y(b["lamp"]), 0.18),
			Vector3(b["lamp"].x, (b["lamp"].y + ground_y(b["lamp"])) * 0.5, b["lamp"].z), CineFX._mat(Color("#5A5F66"), 0.5))
		var l := SpotLight3D.new()
		l.name = "Light"
		l.light_color = Color("#BFF6FF")
		l.light_energy = 4.0
		l.shadow_enabled = false
		root.add_child(l)
		l.global_position = b["lamp"]
		b["root"] = root
		b["cone"] = cone
		b["disc"] = disc
		b["spot"] = spot
		b["light"] = l
		b["mat"] = mat
		b["dmat"] = dmat
		b["hum"] = YardSfx.loop3d(spot, "hum")
		beams.append(b)
	_reset_beams()


func _beam_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.set_meta("vice_done", true)
	return m


func _reset_beams() -> void:
	for b: Dictionary in beams:
		b["t"] = float(b["phase0"]) * sweep_s
		_set_beam_color(b, CYAN)
		_place_beam(b)


## The beam's floor point at its sweep time (a smooth back-and-forth between a and b, one way in sweep_s).
func _beam_point(b: Dictionary) -> Vector3:
	var u: float = 0.5 - 0.5 * cos(PI * float(b["t"]) / sweep_s)
	return (b["a"] as Vector3).lerp(b["b"], u)


func _place_beam(b: Dictionary) -> void:
	set_beam_point(b, _beam_point(b))


## Points the beam at floor point p (tests force it with this).
func set_beam_point(b: Dictionary, p: Vector3) -> void:
	b["p"] = p
	var lamp: Vector3 = b["lamp"]
	var axis: Vector3 = lamp - p
	var length: float = maxf(axis.length(), 0.5)
	var y: Vector3 = axis / length
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y).normalized()
	var cone: MeshInstance3D = b["cone"]
	cone.global_transform = Transform3D(Basis(x, y * length, z), (lamp + p) * 0.5)
	(b["spot"] as Node3D).global_position = p
	var l: SpotLight3D = b["light"]
	if l.is_inside_tree():
		l.look_at_from_position(lamp, p, Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP)
	l.spot_range = length + 3.0
	l.spot_angle = rad_to_deg(atan(beam_r / length)) + 4.0


func _set_beam_color(b: Dictionary, c: Color) -> void:
	(b["mat"] as StandardMaterial3D).albedo_color = c
	(b["dmat"] as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, minf(c.a * 2.0, 0.5))
	(b["light"] as SpotLight3D).light_color = Color(c.r, c.g, c.b) if c != CYAN else Color("#BFF6FF")


## The beam finds a body whose chest is at `chest`: inside its floor disc (flat) and a clear line from the lamp.
func beam_sees(b: Dictionary, chest: Vector3) -> bool:
	var p: Vector3 = b["p"]
	if Vector2(chest.x - p.x, chest.z - p.z).length() > beam_r:
		return false
	return clear_line(b["lamp"], chest)


## The sleeper wakes: a sprint within wake_m (a walk or a crouch never wakes him).
func wake_check(player_pos: Vector3, sprinting: bool) -> bool:
	if not asleep or sleeper == null or not is_instance_valid(sleeper):
		return false
	return sprinting and flat(player_pos, sleeper.global_position) <= wake_m


func _build_props() -> void:
	_zzz = Label3D.new()
	_zzz.name = "Zzz"
	_zzz.text = "Z z z..."
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.font_size = 48
	_zzz.outline_size = 10
	_zzz.pixel_size = 0.006
	_zzz.modulate = Color("#BFE8FF")
	_zzz.visible = false
	add_child(_zzz)
	_haha = Label3D.new()
	_haha.name = "Haha"
	_haha.text = "Haha! Clip mèo..."
	_haha.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_haha.font_size = 40
	_haha.outline_size = 10
	_haha.pixel_size = 0.006
	_haha.modulate = Color("#FFE14D")
	_haha.visible = false
	add_child(_haha)
	if level and level.get("forklift_park") is Node3D:
		var fp: Node3D = level.get("forklift_park")
		_keys = CineFX._box(self, "Keys", Vector3(0.08, 0.14, 0.03), fp.global_position + Vector3(0.0, 1.35, 0.0), CineFX._glow_mat(Color("#FFD34D"), 3.0))
		_keys.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_keys.visible = false


func _attach_role_props() -> void:
	if _zzz:
		_zzz.visible = asleep
		if sleeper:
			_zzz.global_position = sleeper.global_position + Vector3(0.0, 1.9, 0.0)
	if sleeper and is_instance_valid(sleeper):
		sleeper.body.rotation.x = -0.35   # slumped back against the pallets
	if phone_guard and is_instance_valid(phone_guard) and phone_guard.get_node_or_null("Phone") == null:
		var ph: MeshInstance3D = CineFX._box(phone_guard, "Phone", Vector3(0.08, 0.15, 0.02), Vector3(0.0, 1.35, -0.35), CineFX._glow_mat(Color("#9FD8FF"), 2.5))
		ph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ----- per tick -----
func _lair_tick(dt: float) -> void:
	for b: Dictionary in beams:
		b["t"] = fmod(float(b["t"]) + dt, sweep_s * 2.0)
		_place_beam(b)
	_events()
	_check_t -= dt
	if _check_t <= 0.0:
		_check_t = CHECK_DT
		_checks()
	_sounds(dt)
	_reinforce_tick(dt)
	super._lair_tick(dt)


func _events() -> void:
	for e: Array in EVENTS:
		var id: String = String(e[0])
		if events_done.has(id):
			continue
		var due: bool = clock >= float(e[1])
		if not due and String(e[2]) != "" and player:
			var at: Variant = _event_point(String(e[2]))
			due = at is Vector3 and flat(player.global_position, at) <= float(e[3])
		if due:
			events_done[id] = clock
			_event(id)


func _event_point(key: String) -> Variant:
	match key:
		"sleeper":
			return sleeper.global_position if sleeper and is_instance_valid(sleeper) else null
		"phone":
			return phone_guard.global_position if phone_guard and is_instance_valid(phone_guard) else null
		"forklift":
			return (level.get("forklift_park") as Node3D).global_position if level and level.get("forklift_park") is Node3D else null
	return null


func _event(id: String) -> void:
	match id:
		"flood":
			popup(T_FLOOD, 2.4, WARN)
			if not beams.is_empty():
				_preview(beams[0]["spot"])
		"pair":
			radio("2 con guard đi cặp kìa e, đợi tụi nó quay lưng rồi lách.", "Hai bảo vệ đi cặp, chờ chúng quay lưng.", 4.5)
		"sleeper":
			radio("Ông kia AFK ngủ trên pallet, đi nhẹ thôi, sprint là ổng respawn dậy đó.", "Có ông ngủ gật, đừng chạy gần.", 4.5)
		"phone":
			radio("Ông kia đang lướt clip mèo cười sằng sặc, nửa con mắt thôi, lách qua được.", "Ông kia mải xem điện thoại.", 4.5)
			_laugh_t = 0.0
		"forklift":
			if _keys:
				_keys.visible = true
			radio("Con xe nâng kia còn cắm chìa kìa e. Note lại, lát có khi xài.", "Xe nâng còn cắm chìa khóa.", 4.5)


func _preview(target: Node3D) -> void:
	var d: CameraDirector = CameraDirector.live()
	if d != null and target != null and target.is_inside_tree() and not d.cutting():
		if d.preview_cut(target, 0.6):
			preview_cuts += 1
			return
	preview_cuts += 1   # counted even when no director runs (headless tests): the beat fired


func _checks() -> void:
	if player == null or fight == null:
		return
	var chest: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	if not spotted:
		for b: Dictionary in beams:
			if beam_sees(b, chest):
				flood_spotted = true
				_set_beam_color(b, RED)
				popup(T_FLOOD_SEEN, 2.0, WARN)
				_on_spotted(null)
				break
	if asleep:
		if sleeper == null or not is_instance_valid(sleeper) or sleeper.is_defeated():
			asleep = false
			if _zzz:
				_zzz.visible = false
		elif sleeper.hp < sleeper.max_hp or wake_check(player.global_position, player.is_sprinting and player.horizontal_speed > 5.0):
			_wake()


func _wake() -> void:
	if not asleep or sleeper == null or not is_instance_valid(sleeper):
		return
	asleep = false
	if _zzz:
		_zzz.visible = false
	sleeper.body.rotation.x = 0.0
	popup(T_WOKE, 2.0, WARN)
	sleeper.ai = true
	sleeper.bind(fight)
	sleeper.alert(player.global_position if player else sleeper.global_position)


## Seen (a guard or a floodlight): the early fight. T9: the guards within NEAR_ALERT_M are alerted at once (GunFight shares
## an alert within 14 m anyway); the far ones come as reinforcements, nearest first, one every reinforce_s (a popup and the
## edge markers say where), so a slip in the far corner is a fight, not six guns at once.
func _on_spotted(_g: Node3D) -> void:
	if spotted or state != "running":
		return
	spotted = true
	popup(T_SPOTTED, 2.0, WARN)
	radio("Toang r e, combat mode thôi!", "Bị lộ rồi, đánh đi!", 3.5)
	for b: Dictionary in beams:
		_set_beam_color(b, RED)
	reinforcements.clear()
	var far: Array = []
	for e: Variant in fight.alive():
		if not (e is Gunman):
			continue
		var gm: Gunman = e
		var d: float = flat(gm.global_position, player.global_position) if player else 0.0
		if d <= NEAR_ALERT_M or gm.is_alerted:
			_alert_guard(gm)
		else:
			far.append([d, gm])
	far.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for f: Array in far:
		reinforcements.append(f[1])
	_reinforce_t = reinforce_s


func _alert_guard(gm: Gunman) -> void:
	if gm == sleeper and asleep:
		_wake()
	elif not gm.is_alerted:
		gm.alert(player.global_position if player else gm.global_position)


## The queued far guards, one every reinforce_s (already alerted by a neighbour: skipped).
func _reinforce_tick(dt: float) -> void:
	if not spotted or reinforcements.is_empty():
		return
	_reinforce_t -= dt
	if _reinforce_t > 0.0:
		return
	_reinforce_t = reinforce_s
	while not reinforcements.is_empty():
		var gm: Variant = reinforcements.pop_front()
		if is_instance_valid(gm) and not (gm as Gunman).is_defeated() and not (gm as Gunman).is_alerted:
			_alert_guard(gm)
			popup(T_MORE, 1.4, WARN)
			return


func _sounds(dt: float) -> void:
	if player == null:
		return
	var gs: Array = fight.gunmen if fight else []
	for g: Variant in gs:
		if not is_instance_valid(g):
			continue
		var gm: Gunman = g
		if gm.speed_now < 0.5 or flat(gm.global_position, player.global_position) > STEP_HEAR_M:
			continue
		var t: float = float(_step_t.get(gm, 0.0)) - dt
		if t <= 0.0:
			t = STEP_DT
			steps_played += 1
			YardSfx.play3d(self, "step", gm.feet(), -6.0, STEP_HEAR_M + 4.0)
		_step_t[gm] = t
	if asleep and sleeper and is_instance_valid(sleeper):
		_snore_t -= dt
		if _snore_t <= 0.0:
			_snore_t = 2.6
			if flat(sleeper.global_position, player.global_position) <= 16.0:
				snores += 1
				YardSfx.play3d(self, "snore", sleeper.global_position + Vector3(0.0, 1.0, 0.0), -4.0, 16.0)
	if phone_guard and is_instance_valid(phone_guard) and not phone_guard.is_alerted and not phone_guard.is_defeated() and _haha:
		_laugh_t -= dt
		if _laugh_t <= 0.0:
			_laugh_t = 3.0
		_haha.visible = _laugh_t > 1.8 and events_done.has("phone")
		if _haha.visible:
			_haha.global_position = phone_guard.global_position + Vector3(0.0, 2.3, 0.0)
	elif _haha:
		_haha.visible = false


func _reset_state() -> void:
	super._reset_state()
	flood_spotted = false
	reinforcements.clear()
	_check_t = 0.0
	_step_t.clear()
	if not beams.is_empty():
		_reset_beams()


func _reset() -> void:
	super._reset()       # fight.retry(): wave 0 again (fresh guards; _on_wave_started rebinds the roles)
	_bind_roles()
