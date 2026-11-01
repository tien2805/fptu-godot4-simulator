# File: res://scripts/story/missions/MissionBackroom.gd
# Day 6 back room of Trà Sữa Lọ (lair task "backroom", plan 2026-11-01-w4-day6.md T3; spec section 5 "Back room", the
# horror beat): on foot through the dark room behind the shop (LairCanal: the doll shelves on both walls, the music box on
# its table, the vanity with the bulb-framed mirror, the safe with the ledger, room_xf). The goal: the ledger in the safe
# (E7), then out.
#   - A guard in a sheep mask (StoryCast "guard_sheep") walks the patrol loop (points.patrol) and pauses at the corners. He
#     sees in a cone (sight_m / sight_deg, a clear line: shelves and furniture block it); his cone lies on the floor (pale,
#     reddening as he grows suspicious). Seen for longer than see_grace() = "BỊ LỘ"; bumping into him is seen at once.
#   - THE MUSIC BOX (the signature): MUSIC_AT_S into the beat, or as soon as the player passes within MUSIC_NEAR_M of it,
#     it starts on its own: the stealth track stops, the box plays its tune (positional) and its dancer spins, and every
#     sheep doll on the shelves turns round to face the player and keeps following them. The guard goes to shut it up (a
#     window: he stands at the box for lure_s(), "Ai bật cái hộp nhạc này vậy?").
#   - BLEAT_AFTER_S later the dolls bleat (distorted) and Anh Duy talks the player down; BULB_AFTER_S after the music the
#     ceiling bulb dies for BULB_S (the joke: the guard taps it, "Ủa, cúp điện hả?", his sight shrinks in the dark).
#   - The safe: hold [E] within SAFE_R for crack_s(); the dial clicks; the door swings open, the ledger is taken (E7).
#   - The mirror: MIRROR_AFTER_S later a figure with a pink bob shows in the vanity mirror for MIRROR_S under a preview cut,
#     then it is gone ("...Ai vậy?"); then the short replay seg_d6_infiltrate and done (cine_d6_caught tells who it was).
# "Giảm hù dọa": the music box softer, the dolls turn slowly and only half way, no bleat (a soft heartbeat), no screech
# at the mirror and the figure faint. Numbers through Difficulty.pick. Test hooks: beats, guard, sus, crack, hold_e,
# start_music(), music_on, turn_w, mirror_node.
class_name MissionBackroom
extends StoryMission

const MUSIC_AT_S: float = 14.0
const MUSIC_NEAR_M: float = 1.8
const BLEAT_AFTER_S: float = 16.0
const BULB_AFTER_S: float = 32.0
const BULB_S: float = 5.0
const BULB_SIGHT_K: float = 0.45
const SAFE_R: float = 1.4
const PAUSE_S: float = 1.1
const BUMP_M: float = 0.8
const EYE_Y: float = 1.6
const SEE_DT: float = 0.1
const SUS_DECAY: float = 0.6
const NOTICED_AT: float = 0.5
const MIRROR_AFTER_S: float = 0.9
const MIRROR_S: float = 0.7
const REPLAY_AFTER_S: float = 1.3
const CLICK_S: float = 0.35
const SPIN_RAD_S: float = 2.4
const T_SEEN: String = "Bảo vệ đeo mặt nạ cừu thấy mày rồi."
const T_LURE: String = "Ai bật cái hộp nhạc này vậy?"
const T_BULB: String = "Ủa, cúp điện hả?"
const T_LEDGER: String = "Lấy được sổ cái!"
const CONE_COL := Color(1.0, 0.9, 0.75, 0.10)
const CONE_HOT := Color(1.0, 0.25, 0.3, 0.32)

var level: LairCanal
var pts: Dictionary = {}
var guard: Node3D = null
var guard_tag: Label3D
var guard_line: Label3D
var cone: MeshInstance3D
var cone_mat: StandardMaterial3D
var patrol: Array = []
var patrol_i: int = 0
var guard_mode: String = "patrol"         # patrol | pause | lure | bulb | caught
var guard_t: float = 0.0
var sus: float = 0.0
var sus_peak: float = 0.0                 # this attempt's highest suspicion (the rank's "noticed": NOTICED_AT or more)
var seen: bool = false
var sight_m: float = 6.0
var sight_deg: float = 38.0
var walk_ms: float = 1.25
var crack: float = 0.0
var hold_e: bool = false
var has_ledger: bool = false
var music_on: bool = false
var music_t: float = -1.0
var turn_w: float = 0.0
var spin: float = 0.0
var bulb_t: float = -1.0
var mirror_t: float = -1.0
var mirror_node: Node3D = null
var replay_wait: float = -1.0
var beats: Array[String] = []
var rec: CineReplayRecorder = null
var box_player: AudioStreamPlayer3D = null
var _see_acc: float = 0.0
var _click_t: float = 0.0
var _line_t: float = 0.0
var _ceiling: OmniLight3D = null
var _ceiling_e: float = 1.0
var _vanity_light: OmniLight3D = null
var _vanity_e: float = 0.7


func _start() -> void:
	level = opts.get("level") as LairCanal
	pts = opts.get("points", {})
	patrol = pts.get("patrol", [])
	sight_m = float(Difficulty.pick(6.0, 4.8))
	sight_deg = float(Difficulty.pick(38.0, 30.0))
	walk_ms = float(Difficulty.pick(1.25, 1.05))
	guard = spawn_body("guard_sheep", pts.get("guard_start", Vector3.ZERO), 0.0)
	if guard:
		guard_tag = _tag(guard, "", WARN, 2.25, 56)
		guard_line = _tag(guard, "", INK, 2.55, 36)
		_build_cone()
	_find_lights()
	_build_mirror_figure()
	box_player = AudioStreamPlayer3D.new()
	box_player.name = "MusicBox"
	box_player.bus = CinePlayer._bus("SFX")
	box_player.unit_size = 3.0
	add_child(box_player)
	box_player.global_position = pts.get("music_box", Vector3.ZERO)
	rec = StoryStage.make_recorder(self, [player, guard])
	_arm()
	radio("Két nằm góc trong bên phải. Con guard đeo mask cừu đi tuần, né cone của nó.", "Két ở góc phải. Tránh tầm nhìn bảo vệ.", 5.0)


## Fresh attempt (start and THỬ LẠI): the player at the shop door, the guard at his post, the box silent, the dolls to the
## wall, the bulb on, the safe shut with the ledger in it.
func _arm() -> void:
	teleport_player(pts.get("start", Vector3.ZERO), float(pts.get("yaw", PI)))
	if player:
		player.controls_enabled = true
	patrol_i = 0
	guard_mode = "patrol"
	guard_t = 0.0
	sus = 0.0
	sus_peak = 0.0
	seen = false
	crack = 0.0
	hold_e = false
	has_ledger = false
	music_on = false
	music_t = -1.0
	turn_w = 0.0
	spin = 0.0
	bulb_t = -1.0
	mirror_t = -1.0
	replay_wait = -1.0
	_see_acc = 0.0
	beats.clear()
	beats.append("enter")
	if guard:
		guard.global_position = pts.get("guard_start", Vector3.ZERO)
		if patrol.size() > 1:
			guard.rotation.y = yaw_of((patrol[1] as Vector3) - (patrol[0] as Vector3))
			patrol_i = 1
		guard_tag.text = ""
		guard_line.visible = false
	if box_player:
		box_player.stop()
	if level:
		level.turn_dolls(_head(), 0.0)
		level.music_box_spin(0.0)
		level.safe_open(0.0)
		if level.ledger:
			level.ledger.visible = true
	_set_ceiling(1.0)
	if mirror_node:
		mirror_node.visible = false
	set_meter(-1.0)
	set_info("Tìm két sắt, lấy sổ cái")
	set_prompt("")


# ---------------------------------------------------------------------------
# Tick
# ---------------------------------------------------------------------------
func _tick(dt: float) -> void:
	if replay_wait >= 0.0:
		replay_wait -= dt
		if replay_wait < 0.0:
			play_short_replay(rec, String(beat.get("replay", "seg_d6_infiltrate")), player, guard, func() -> void:
				finish({"crack_s": crack_s(), "music": music_on, "noticed": sus_peak >= NOTICED_AT}))
		return
	if _line_t > 0.0:
		_line_t -= dt
		if _line_t <= 0.0 and guard_line:
			guard_line.visible = false
	_guard_tick(dt)
	_music_tick(dt)
	if has_ledger:
		_mirror_tick(dt)
		return
	_safe_tick(dt)
	if seen:
		return
	_see_acc += dt
	if _see_acc >= SEE_DT:
		_sight_check(_see_acc)
		_see_acc = 0.0


func _guard_tick(dt: float) -> void:
	if guard == null or patrol.is_empty():
		return
	guard_t += dt
	match guard_mode:
		"patrol":
			var to: Vector3 = patrol[patrol_i]
			if _walk_to(to, dt):
				guard_mode = "pause"
				guard_t = 0.0
		"pause":
			CharacterBuilder.set_speed(guard, 0.0)
			var nxt: Vector3 = patrol[(patrol_i + 1) % patrol.size()]
			guard.rotation.y = lerp_angle(guard.rotation.y, yaw_of(nxt - guard.global_position), minf(1.0, dt * 3.0))
			if guard_t >= PAUSE_S:
				patrol_i = (patrol_i + 1) % patrol.size()
				guard_mode = "patrol"
		"lure":
			var box: Vector3 = pts.get("music_box", guard.global_position)
			var spot: Vector3 = Vector3(box.x, guard.global_position.y, box.z) + _away(box, 1.0)
			if _walk_to(spot, dt):
				CharacterBuilder.set_speed(guard, 0.0)
				guard.rotation.y = lerp_angle(guard.rotation.y, yaw_of(box - guard.global_position), minf(1.0, dt * 4.0))
			if guard_t >= lure_s():
				guard_mode = "patrol"
				guard_t = 0.0
		"bulb":
			CharacterBuilder.set_speed(guard, 0.0)
			if guard_t >= BULB_S:
				guard_mode = "patrol"
				guard_t = 0.0
		"caught":
			CharacterBuilder.set_speed(guard, 0.0)
			if player:
				guard.rotation.y = lerp_angle(guard.rotation.y, yaw_of(player.global_position - guard.global_position), minf(1.0, dt * 6.0))


## Walks the guard toward `to`; true once he is there.
func _walk_to(to: Vector3, dt: float) -> bool:
	var d: Vector3 = to - guard.global_position
	d.y = 0.0
	var step: float = walk_ms * dt
	if d.length() <= step:
		guard.global_position = Vector3(to.x, guard.global_position.y, to.z)
		return true
	guard.global_position += d.normalized() * step
	guard.rotation.y = lerp_angle(guard.rotation.y, yaw_of(d), minf(1.0, dt * 6.0))
	CharacterBuilder.set_speed(guard, walk_ms)
	return false


## A point `r` m from p toward the guard (where he stands to look at the box).
func _away(p: Vector3, r: float) -> Vector3:
	var d: Vector3 = guard.global_position - p
	d.y = 0.0
	return (d.normalized() if d.length() > 0.05 else Vector3.BACK) * r


func _sight_check(dt: float) -> void:
	if guard == null or player == null:
		return
	var eye: Vector3 = guard.global_position + Vector3(0.0, EYE_Y, 0.0)
	var fwd: Vector3 = -guard.global_transform.basis.z
	var range_m: float = sight_m * (BULB_SIGHT_K if bulb_t >= 0.0 else 1.0)
	var in_sight: bool = flat(guard.global_position, player.global_position) <= BUMP_M or sees_player(eye, fwd, range_m, sight_deg)
	if flat(guard.global_position, player.global_position) <= BUMP_M:
		sus = 1.0
	elif in_sight:
		sus += dt / see_grace()
	else:
		sus = maxf(0.0, sus - dt * SUS_DECAY)
	sus_peak = maxf(sus_peak, sus)
	guard_tag.text = "!" if sus >= 1.0 else ("?" if sus > 0.05 else "")
	if cone_mat:
		cone_mat.albedo_color = CONE_COL.lerp(CONE_HOT, clampf(sus, 0.0, 1.0))
	if sus >= 1.0:
		seen = true
		guard_mode = "caught"
		play_cue("toang_sting", -6.0)
		fail(T_SEEN, T_LO)


# ---------------------------------------------------------------------------
# The music box, the dolls, the bulb
# ---------------------------------------------------------------------------
func _music_tick(dt: float) -> void:
	if not music_on:
		if player and (clock >= MUSIC_AT_S or flat(player.global_position, pts.get("music_box", Vector3.ZERO)) <= MUSIC_NEAR_M):
			start_music()
		return
	music_t += dt
	spin += SPIN_RAD_S * dt
	if level:
		level.music_box_spin(spin)
		turn_w = minf(turn_cap(), turn_w + dt / turn_s())
		level.turn_dolls(_head(), turn_w)
	if box_player and not box_player.playing and StoryAudio.ready_for(["music_box"]):
		box_player.stream = StoryAudio.stream("music_box")
		box_player.volume_db = box_db()
		box_player.play()
	if not beats.has("bleat") and music_t >= BLEAT_AFTER_S:
		beats.append("bleat")
		if _soft():
			play_cue("heartbeat", -14.0)
		else:
			play_cue("sheep_bleat_distorted", -6.0)
			play_cue("heartbeat", -8.0)
		radio("Búp bê thôi mà e, ko có AI gì đâu. Chill, focus cái két.", "Chỉ là búp bê. Bình tĩnh, lo cái két.", 4.5)
	if not beats.has("bulb") and music_t >= BULB_AFTER_S:
		beats.append("bulb")
		bulb_t = 0.0
		if guard_mode != "caught":
			guard_mode = "bulb"
			guard_t = 0.0
			_line(T_BULB, 2.4)
		play_cue("fluoro_buzz", -10.0)
	if bulb_t >= 0.0:
		bulb_t += dt
		var k: float = 0.0 if fmod(bulb_t, 0.9) > 0.12 or _soft() else 0.6
		_set_ceiling(k)
		if bulb_t >= BULB_S:
			bulb_t = -1.0
			_set_ceiling(1.0)


## The signature: the box plays by itself, the stealth track stops, the dolls turn to the player, the guard goes to it.
func start_music() -> void:
	if music_on:
		return
	music_on = true
	music_t = 0.0
	beats.append("music")
	if roam and roam.has_method("music"):
		roam.call("music", "")
	play_cue("metal_creak", -14.0 if _soft() else -8.0)
	popup("...", 1.2)
	if guard and guard_mode != "caught":
		guard_mode = "lure"
		guard_t = 0.0
		_line(T_LURE, 2.6)
		beats.append("lure")


func _set_ceiling(k: float) -> void:
	if _ceiling:
		_ceiling.light_energy = _ceiling_e * k


# ---------------------------------------------------------------------------
# The safe, the ledger, the mirror
# ---------------------------------------------------------------------------
func _safe_tick(dt: float) -> void:
	var near: bool = player != null and flat(player.global_position, pts.get("safe", Vector3.ZERO)) <= SAFE_R
	if not near:
		set_prompt("")
		if crack > 0.0:
			set_meter(crack * 100.0, "Mở két")
		return
	set_prompt("Giữ [E] mở két" if crack < 1.0 else "")
	set_meter(crack * 100.0, "Mở két")
	if not hold_e:
		return
	crack = minf(1.0, crack + dt / crack_s())
	_click_t -= dt
	if _click_t <= 0.0:
		_click_t = CLICK_S
		play_cue("keyboard_clack", -16.0)
	if crack >= 1.0:
		_take_ledger()


func _take_ledger() -> void:
	has_ledger = true
	hold_e = false
	beats.append("ledger")
	if level:
		level.safe_open(1.0)
		if level.ledger:
			level.ledger.visible = false
	popup(T_LEDGER, 1.8, PINK)
	play_cue("success_fanfare", -10.0)
	set_prompt("")
	set_meter(-1.0)
	set_info("Có sổ cái (E7). Ra cửa bến...")
	mirror_t = 0.0


func _mirror_tick(dt: float) -> void:
	if mirror_t < 0.0:
		return
	mirror_t += dt
	if not beats.has("mirror") and mirror_t >= MIRROR_AFTER_S:
		beats.append("mirror")
		if mirror_node:
			mirror_node.visible = true
			_figure_alpha(0.35 if _soft() else 0.95)
		if _vanity_light:
			_vanity_light.light_energy = _vanity_e * 2.4
		if not _soft():
			play_cue("violin_screech", -8.0)
		else:
			play_cue("heartbeat", -14.0)
		var cd: CameraDirector = CameraDirector.live()
		if cd and mirror_node and mirror_node.is_inside_tree():
			cd.preview_cut(mirror_node, MIRROR_S)
	if beats.has("mirror") and mirror_node and mirror_node.visible and mirror_t >= MIRROR_AFTER_S + MIRROR_S:
		mirror_node.visible = false
		if _vanity_light:
			_vanity_light.light_energy = _vanity_e
		popup("...Ai vậy?", 1.4)
		replay_wait = REPLAY_AFTER_S
		mirror_t = -1.0


# ---------------------------------------------------------------------------
# Build helpers
# ---------------------------------------------------------------------------
## The guard's sight cone on the floor (a flat fan, unshaded, additive-ish alpha), a child of the body.
func _build_cone() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = 14
	var half: float = deg_to_rad(sight_deg)
	for i: int in seg:
		var a0: float = -half + 2.0 * half * float(i) / float(seg)
		var a1: float = -half + 2.0 * half * float(i + 1) / float(seg)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a1), 0.0, -cos(a1)) * sight_m)
		st.add_vertex(Vector3(sin(a0), 0.0, -cos(a0)) * sight_m)
	cone = MeshInstance3D.new()
	cone.name = "SightCone"
	cone.mesh = st.commit()
	cone_mat = StandardMaterial3D.new()
	cone_mat.albedo_color = CONE_COL
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_mat.set_meta("vice_done", true)
	cone.material_override = cone_mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.position = Vector3(0.0, 0.03, 0.0)
	guard.add_child(cone)


## The ceiling bulb (the room's main light) and the red bulb at the vanity, from the level's room items.
func _find_lights() -> void:
	if level == null or level.room_items == null:
		return
	var vanity_at: Vector3 = pts.get("vanity", Vector3.ZERO)
	for n: Node in level.room_items.get_children():
		if not n.has_meta("lamp_light"):
			continue
		var l: OmniLight3D = n.get_meta("lamp_light")
		if n.has_meta("lamp_bulb"):
			_ceiling = l
			_ceiling_e = l.light_energy
		elif flat((n as Node3D).global_position, vanity_at) < 1.5:
			_vanity_light = l
			_vanity_e = l.light_energy


## A figure with a pink bob in the vanity mirror (flat shapes on the glass), hidden until the mirror beat.
func _build_mirror_figure() -> void:
	if level == null or level.vanity == null:
		return
	mirror_node = Node3D.new()
	mirror_node.name = "MirrorFigure"
	level.vanity.add_child(mirror_node)
	mirror_node.position = Vector3(0.0, 0.0, 0.155)
	var dark: StandardMaterial3D = CineFX._mat(Color("#141018"), 1.0)
	var hair: StandardMaterial3D = CineFX._glow_mat(Color("#FF4FA3"), 0.6)
	for m: StandardMaterial3D in [dark, hair]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.set_meta("vice_done", true)
	CineFX._box(mirror_node, "Shoulders", Vector3(0.42, 0.22, 0.004), Vector3(0.0, 1.0, 0.0), dark)
	CineFX._sphere(mirror_node, "Head", 0.1, Vector3(0.0, 1.27, 0.0), dark, Vector3(1.0, 1.15, 0.05))
	CineFX._sphere(mirror_node, "Bob", 0.13, Vector3(0.0, 1.31, 0.002), hair, Vector3(1.0, 0.85, 0.04))
	mirror_node.set_meta("mats", [dark, hair])
	mirror_node.visible = false


func _figure_alpha(a: float) -> void:
	if mirror_node == null:
		return
	for m: Variant in mirror_node.get_meta("mats", []):
		var sm: StandardMaterial3D = m
		sm.albedo_color.a = a


func _tag(b: Node3D, text: String, col: Color, y: float, size: int) -> Label3D:
	var l := Label3D.new()
	l.name = "Tag"
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0.06, 0.02, 0.1, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0.0, y, 0.0)
	b.add_child(l)
	return l


func _line(text: String, secs: float) -> void:
	if guard_line == null:
		return
	guard_line.text = text
	guard_line.visible = true
	_line_t = secs


func _head() -> Vector3:
	return (player.global_position if player else Vector3.ZERO) + Vector3(0.0, 1.55, 0.0)


# ---------------------------------------------------------------------------
# Tuning (Difficulty.pick) and "Giảm hù dọa"
# ---------------------------------------------------------------------------
func see_grace() -> float:
	return float(Difficulty.pick(0.45, 0.8))


func crack_s() -> float:
	return float(Difficulty.pick(3.0, 2.2))


func lure_s() -> float:
	return float(Difficulty.pick(5.0, 7.0))


## The dolls finish turning in turn_s() (slower with "Giảm hù dọa") and only half way when it is on.
func turn_s() -> float:
	return 4.0 if _soft() else 1.2


func turn_cap() -> float:
	return 0.6 if _soft() else 1.0


func box_db() -> float:
	return -16.0 if _soft() else -6.0


func _soft() -> bool:
	var fx: Node = get_node_or_null("/root/GameFX")
	return fx != null and bool(fx.get("reduce_scares"))


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.physical_keycode == KEY_E and not k.echo:
		hold_e = k.pressed
		get_viewport().set_input_as_handled()


func _reset() -> void:
	_arm()
	if roam and roam.has_method("music"):
		roam.call("music", String(StoryCanal.LAIR_MUSIC.get("backroom", "")))   # the box stopped it: the stealth track again


func _cleanup() -> void:
	if box_player and is_instance_valid(box_player):
		box_player.stop()
	_set_ceiling(1.0)
	if _vanity_light:
		_vanity_light.light_energy = _vanity_e
	if mirror_node and is_instance_valid(mirror_node):
		mirror_node.queue_free()
	mirror_node = null
	if level and not has_ledger:
		level.turn_dolls(_head(), 0.0)
		level.music_box_spin(0.0)
