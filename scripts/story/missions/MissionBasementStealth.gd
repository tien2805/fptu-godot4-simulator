# File: res://scripts/story/missions/MissionBasementStealth.gd
# Day 5 stealth through the server hall (lair task "stealth"; plan 2026-10-30-w3-day5.md T2, design D5W-2): MissionSneak in
# the basement with its signature, THE BLACKOUT. BLACKOUT_AT_S into the mission (or when the player reaches the cross
# aisle, CROSS_AISLE_Z) the hall's mains die row by row with a clunk (LairBasement.set_power(false), "power_row"), under a
# 0.6 s preview cut on the nearest guard; the look becomes "server_blackout" (StoryBasement.look). Then only the monitors,
# the red emergency strips, the rack LEDs and the guards' smart-glasses LEDs (two emissive dots per guard) glow:
#   - an unalerted guard sees only inside his flashlight cone (Gunman.patrol_sight_m / patrol_fov_deg = DARK_SIGHT_M /
#     DARK_FOV_DEG at the cut; his beam is an additive cone mesh, never a light);
#   - the player's [F] torch (HorrorFlashlight, the horror toolkit's) makes him visible from LIGHT_SEEN_M to any unalerted
#     guard facing him within LIGHT_HALF_DEG (own 10 Hz check with a clear line -> MissionSneak._on_spotted);
#   - Za Mẫn's face flickers on the hall monitors with a synthesized whisper ("whisper_bed"); "Giảm hù dọa" = no whisper,
#     a dimmer face with slow shallow blips, and a far, soft blackout thump and row clunks;
#   - a guard's flashlight dies and he shakes it (the joke): blind DUD_S seconds.
# Power returns at the control room (the goal: set_power(true) right before done). A retry restores the lights and arms
# the blackout again; the end of the mission restores them too. Beats about every 15-20 s (beats, a log for the tests):
# stairs (Anh Duy, t 0) -> first_patrol (17 s) -> blackout (25 s) -> leds (+3 s) -> face (+9 s) -> dud (+18 s) ->
# power_back (the goal). Numbers through Difficulty.pick.
# T8 (sim_day5): being seen sounds the ALARM: once the patrol is down, REINFORCE (Thường) / REINFORCE_EASY (Dễ) guards of the
# next shift kick the side door open (a preview cut on the door, Za Mẫn on the radio) and the beat ends at the goal once
# they are down too; a retry is the patrol again from the start (the checkpoint stays at the patrol, the alarm wave goes).
class_name MissionBasementStealth
extends MissionSneak

const BLACKOUT_AT_S: float = 25.0
const CROSS_AISLE_Z: float = 24.5        # level-local z: the player nearing the cross aisle triggers it early (T8: the dark
                                         # comes before its patrol line, not on it)
const CUT_S: float = 0.6
const FIRST_PATROL_S: float = 17.0
const LEDS_AFTER_S: float = 3.0
const FACE_AFTER_S: float = 9.0
const FACE_S: float = 3.2
const DUD_AFTER_S: float = 18.0
const DUD_S: float = 4.0
const LIGHT_HALF_DEG: float = 60.0
const SEE_DT: float = 0.1
const BEAM_COL := Color(1.0, 0.93, 0.72, 0.07)
const LED_COL := Color("#3BE8FF")
const T_BLACKOUT: String = "Cúp điện!"
const T_DUD: String = "Ơ... đèn hư rồi?"
const T_POWER: String = "Có điện lại rồi!"
const T_ALARM: String = "Báo động! Ca sau đang xuống!"
const REINFORCE: int = 3
const REINFORCE_EASY: int = 2
const T_GOAL: String = "Phòng máy chủ"
const GUIDE_NEAR_M: float = 10.0

var blackout: bool = false
var blackout_t: float = -1.0
var dark_sight_m: float = 12.0
var dark_fov_deg: float = 30.0
var light_seen_m: float = 20.0
var flashlight: HorrorFlashlight = null
var beats: Array[String] = []
var cuts: int = 0
var whispers: int = 0
var light_spots: int = 0
var dud_guard: Gunman = null
var dud_t: float = -1.0
var power_back: bool = false
var _props: Dictionary = {}              # Gunman -> [beam MeshInstance3D, leds Node3D]
var _see_acc: float = 0.0
var _beam_mat: StandardMaterial3D
var _led_mat: StandardMaterial3D
var alarm_wave: bool = false
var blackout_db: float = 0.0              # the blackout thump's volume (tests: softer with "Giảm hù dọa")
var door_mark: Node3D = null
## T9 readability: the control room as an on-screen / edge marker, off-screen guards nearby as edge chevrons.
var guide: BasementGuide = null


func _start() -> void:
	dark_sight_m = float(Difficulty.pick(12.0, 10.0))
	dark_fov_deg = float(Difficulty.pick(30.0, 26.0))
	light_seen_m = float(Difficulty.pick(20.0, 16.0))
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.albedo_color = BEAM_COL
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.no_depth_test = false
	_beam_mat.set_meta("vice_done", true)
	_led_mat = CineFX._glow_mat(LED_COL, 4.0)
	_led_mat.set_meta("vice_done", true)
	super._start()
	if fight:
		fight.auto_checkpoint = false        # a retry is always the patrol from the start (the alarm wave is dropped)
		if level and level.has_method("nav_graph"):
			fight.nav = level.call("nav_graph")   # T8: detours round the rack rows once they are alerted
	guide = BasementGuide.new()
	add_child(guide)
	guide.setup(self)
	guide.watch(fight, GUIDE_NEAR_M)
	if pts.has("goal"):
		guide.set_goal(pts["goal"], T_GOAL)
	flashlight = HorrorFlashlight.new()
	flashlight.anchor = player
	flashlight.aim = player.camera if player else null
	flashlight.gentle = _reduce_scares()
	add_child(flashlight)
	if level and level.has_signal("power_row"):
		level.connect("power_row", _on_power_row)
	_arm()


## Fresh state of the blackout (start and retry): lights on, guards' daylight sight, torch off.
func _arm() -> void:
	blackout = false
	blackout_t = -1.0
	dud_guard = null
	dud_t = -1.0
	power_back = false
	_see_acc = 0.0
	beats.clear()
	beats.append("stairs")
	if level and level.has_method("set_power"):
		level.call("set_power", true, true)
		level.call("flicker_face", 0.0, 0.0)
	if roam and roam.has_method("unlook"):
		roam.call("unlook", "server_blackout")
	if flashlight:
		flashlight.set_on(false)
		flashlight.battery = 1.0
	_dress_guards()


## Every guard of the wave gets his smart-glasses LEDs and his (hidden until the blackout) flashlight beam; the alarm wave
## kicks the side door open under a preview cut.
func _on_wave_started(i: int) -> void:
	super._on_wave_started(i)
	_dress_guards()
	if i == 1 and alarm_wave:
		beats.append("alarm_wave")
		if level and level.has_method("kick_door"):
			level.call("kick_door")
		play_cue("locker_slam", -2.0)
		var cd: CameraDirector = CameraDirector.live()
		if door_mark and cd and door_mark.is_inside_tree() and cd.preview_cut(door_mark, CUT_S):
			cuts += 1


## Seen: the patrol fights (MissionSneak) and the alarm calls the next shift through the side door once it is down.
func _on_spotted(g: Node3D) -> void:
	var was: bool = spotted
	super._on_spotted(g)
	if was or not spotted or alarm_wave or fight == null or state != "running":
		return
	alarm_wave = true
	var wave: Array = []
	var spots: Array = level.call("mission_points", "gunfight").get("wave_door", []) if level else []
	var n: int = mini(int(Difficulty.pick(REINFORCE, REINFORCE_EASY)), spots.size())
	for k: int in n:
		wave.append(guard(k + 3, spots[k], [], {"alerted": true}))
	if not wave.is_empty():
		fight.add_wave(wave)
		if door_mark == null and spots.size() > 0:
			door_mark = Node3D.new()
			door_mark.name = "AlarmDoor"
			add_child(door_mark)
			door_mark.global_position = level.call("world", LairBasement.SIDE_DOOR + Vector3(-0.6, 1.0, 0.0))
	popup(T_ALARM, 2.2, WARN)
	radio_as("za_man", "Bấm chuông rồi đó em. Ca sau xuống liền nha.", "", 4.0)


func _dress_guards() -> void:
	if fight == null or _beam_mat == null:
		return
	for k: Variant in _props.keys():
		if not is_instance_valid(k):
			_props.erase(k)
	for e: Variant in fight.gunmen:
		var g: Gunman = e as Gunman
		if g == null or not is_instance_valid(g) or _props.has(g) or g.body == null:
			continue
		var leds := Node3D.new()
		leds.name = "SmartGlasses"
		g.body.add_child(leds)
		leds.position = Vector3(0.0, GunData.EYE_Y + 0.04, -0.12)
		for sx: float in [-1.0, 1.0]:
			var dot: MeshInstance3D = CineFX._sphere(leds, "Led", 0.022, Vector3(sx * 0.04, 0.0, 0.0), _led_mat)
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var beam := MeshInstance3D.new()
		beam.name = "TorchBeam"
		var cm := CylinderMesh.new()
		cm.height = dark_sight_m
		cm.top_radius = tan(deg_to_rad(dark_fov_deg * 0.5)) * dark_sight_m
		cm.bottom_radius = 0.04
		cm.radial_segments = 12
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		beam.mesh = cm
		beam.material_override = _beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation.x = -PI * 0.5           # the cylinder's +Y (the wide end) points forward (-Z)
		beam.position = Vector3(0.18, GunData.EYE_Y - 0.25, -dark_sight_m * 0.5)
		beam.visible = blackout
		g.body.add_child(beam)
		_props[g] = [beam, leds]
		if blackout:
			_darken(g)


## A guard in the dark: he sees only in his torch cone.
func _darken(g: Gunman) -> void:
	g.patrol_sight_m = dark_sight_m
	g.patrol_fov_deg = dark_fov_deg


func _lair_tick(dt: float) -> void:
	if spotted and alarm_wave and fight and fight.wave < fight.waves.size() - 1 and fight.alive().is_empty():
		set_info("Báo động! Ca sau sắp vào từ cửa hông")   # the gap before the next shift: not "cleared" yet
		if blackout:
			blackout_t += dt
		return
	if not blackout and state == "running":
		if not beats.has("first_patrol") and clock >= FIRST_PATROL_S:
			beats.append("first_patrol")
			radio("Guard đầu tiên tuần lối giữa, chờ nó quay lưng r lướt qua.", "Đợi bảo vệ quay lưng rồi đi.", 4.0)
		var lz: float = level.to_local(player.global_position).z if level and player else 99.0
		if clock >= BLACKOUT_AT_S or lz <= CROSS_AISLE_Z:
			_blackout()
	elif blackout:
		blackout_t += dt
		_blackout_beats(dt)
		_see_acc += dt
		if _see_acc >= SEE_DT:
			_see_acc = 0.0
			_torch_check()
	super._lair_tick(dt)


## The signature: the mains die row by row, the dark look, the guards' cones, the preview cut on the nearest guard.
func _blackout() -> void:
	blackout = true
	blackout_t = 0.0
	beats.append("blackout")
	if level and level.has_method("set_power"):
		level.call("set_power", false)
	if roam and roam.has_method("look"):
		roam.call("look", "server_blackout")
	popup(T_BLACKOUT, 2.0, WARN)
	blackout_db = -16.0 if _reduce_scares() else -3.0   # "Giảm hù dọa": a far, soft thump
	play_cue("sub_boom", blackout_db)
	var near: Gunman = null
	var best: float = INF
	for e: Variant in fight.alive():
		var g: Gunman = e as Gunman
		if g == null:
			continue
		_darken(g)
		var pr: Array = _props.get(g, [])
		if not pr.is_empty():
			(pr[0] as Node3D).visible = true
		var d: float = flat(g.global_position, player.global_position) if player else 0.0
		if d < best:
			best = d
			near = g
	var cd: CameraDirector = CameraDirector.live()
	if near and cd and near.is_inside_tree() and cd.preview_cut(near, CUT_S):
		cuts += 1
	set_prompt("Tối om: nhìn đèn LED trên kính bảo vệ. [F] đèn pin (bị thấy từ xa)")


func _on_power_row(_row: int) -> void:
	if state == "running":
		play_cue("locker_slam", -20.0 if _reduce_scares() else -10.0)


func _blackout_beats(dt: float) -> void:
	if not beats.has("leds") and blackout_t >= LEDS_AFTER_S:
		beats.append("leds")
		radio("Mất điện r e, tụi nó chỉ thấy trong cone đèn pin thôi, canh chấm LED trên kính mà né.", "Bảo vệ chỉ thấy trong vùng đèn pin. Nhìn chấm sáng trên kính mà tránh.", 5.0)
	if not beats.has("face") and blackout_t >= FACE_AFTER_S:
		beats.append("face")
		var soft: bool = _reduce_scares()
		if level and level.has_method("flicker_face"):
			level.call("flicker_face", FACE_S, 0.3 if soft else 1.0, soft)
		if not soft:
			whispers += 1
			play_cue("whisper_bed", -9.0)
		radio_as("za_man", "Điện là của anh. Màn hình cũng của anh. Em đi đâu anh cũng thấy.", "", 4.0)
	if not beats.has("dud") and blackout_t >= DUD_AFTER_S:
		_dud_start()
	if dud_t >= 0.0:
		dud_t += dt
		var pr: Array = _props.get(dud_guard, []) if dud_guard and is_instance_valid(dud_guard) else []
		if not pr.is_empty():
			var beam: Node3D = pr[0]
			beam.visible = dud_t >= DUD_S or fmod(dud_t, 0.5) < 0.08   # dead, a blip when he shakes it
			beam.rotation.z = sin(dud_t * 19.0) * 0.12
		if dud_t >= DUD_S:
			_dud_end()


## The joke: his torch dies, he shakes it, blind for DUD_S.
func _dud_start() -> void:
	beats.append("dud")
	for e: Variant in fight.alive():
		var g: Gunman = e as Gunman
		if g and not g.is_alerted:
			dud_guard = g
			break
	if dud_guard == null:
		return
	dud_t = 0.0
	dud_guard.patrol_sight_m = 0.0
	dud_guard.shout.text = T_DUD
	dud_guard.shout.visible = true
	dud_guard.set("_shout_left", 2.5)
	radio("Con guard kia đèn pin die r, blind 4s, lướt qua lẹ!", "Đèn pin hắn hỏng, đi qua nhanh!", 4.0)


func _dud_end() -> void:
	dud_t = -1.0
	if dud_guard and is_instance_valid(dud_guard):
		_darken(dud_guard)
		var pr: Array = _props.get(dud_guard, [])
		if not pr.is_empty():
			(pr[0] as Node3D).visible = true
			(pr[0] as Node3D).rotation.z = 0.0
	dud_guard = null


## The player's torch in the dark: any unalerted guard facing him within LIGHT_HALF_DEG and LIGHT_SEEN_M sees him.
func _torch_check() -> void:
	if spotted or flashlight == null or not flashlight.is_lit() or player == null or fight == null:
		return
	var tp: Vector3 = fight.player_target()
	for e: Variant in fight.alive():
		var g: Gunman = e as Gunman
		if g == null or g.is_alerted or g == dud_guard:
			continue
		var to: Vector3 = player.global_position - g.feet()
		to.y = 0.0
		var d: float = to.length()
		if d > light_seen_m:
			continue
		if d > 0.3 and rad_to_deg(g.forward().angle_to(to / d)) > LIGHT_HALF_DEG:
			continue
		if not fight.clear_line(g.feet() + Vector3(0.0, GunData.EYE_Y, 0.0), tp):
			continue
		light_spots += 1
		_on_spotted(g)
		return


## The control room: the power comes back right before done.
func finish(info: Dictionary = {}) -> void:
	if state == "running":
		_power_on()
	super.finish(info)


func _power_on() -> void:
	if blackout and not power_back:
		power_back = true
		beats.append("power_back")
		popup(T_POWER, 1.6)
	if level and level.has_method("set_power"):
		level.call("set_power", true, true)
	if roam and roam.has_method("unlook"):
		roam.call("unlook", "server_blackout")


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or flashlight == null or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_F:
		flashlight.toggle()
		get_viewport().set_input_as_handled()


func _reset() -> void:
	blackout = false                      # before the respawn: the fresh guards come back with their daylight sight
	blackout_t = -1.0
	if fight and fight.waves.size() > 1:
		fight.waves.resize(1)             # the alarm wave goes: the patrol again, unalerted
	alarm_wave = false
	if level and level.has_method("reset_door"):
		level.call("reset_door")
	super._reset()
	_arm()


func _cleanup() -> void:
	_power_on()
	if alarm_wave and level and level.has_method("reset_door"):
		level.call("reset_door")
	if level and level.has_method("flicker_face"):
		level.call("flicker_face", 0.0, 0.0)
	if level and level.is_connected("power_row", _on_power_row):
		level.disconnect("power_row", _on_power_row)
	if flashlight and is_instance_valid(flashlight):
		flashlight.queue_free()
	flashlight = null
	_props.clear()
	super._cleanup()


func _reduce_scares() -> bool:
	var fx: Node = get_node_or_null("/root/GameFX")
	return fx != null and bool(fx.get("reduce_scares"))
