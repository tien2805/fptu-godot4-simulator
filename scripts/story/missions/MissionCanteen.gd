# File: res://scripts/story/missions/MissionCanteen.gd
# Day 4 canteen undercover (spec B-D7 beat 3): a story scene built from Stage 5's canteen (its tray rule, the cine props),
# staged in FreeRoam in front of the real canteen (CineTimeline.canteen_stage, the box seg_d4_brawl and cine_d4_stare
# use, so the stare and the brawl follow on the same spot). See the integration plan for why not a Stage 5 story mode.
#   - 3 table groups, CLONES identical students eating (StoryCast "clone"); one of them is the real Cừu Dolly
#     (StoryCast "dolly_disguised"): she hums a music-box tune (positional, audible within HUM_M), wears a cream wool cuff
#     and a sheep keychain; walking up to a student shows what you notice about them.
#   - The tray is the disguise: carried calmly it lowers the suspicion meter; sprinting drops it (+DROP_SUS) and without a
#     tray the meter rises (NO_TRAY_SUS / s) until a new one is taken at the counter ([E] there).
#   - [E] facing a student within ACCUSE_M accuses them (the same radius shows their note and "[E] Tố cáo"): Dolly = done;
#     anyone else = +WRONG_SUS ("Ủa…"). Dolly's seat is random (opts.seed fixes it for tests).
#   - A full meter = "BỊ LỘ" (retry: the meter, the tray and the students reset, Dolly elsewhere).
#   - Meme: "Mlem mlem" bubbles over the eaters.
class_name MissionCanteen
extends StoryMission

const CLONES: int = 12
const TABLE_X: Array[float] = [-4.2, 0.0, 4.2]
const TABLE_Z: float = -1.2
const SEAT_DX: Array[float] = [-0.7, 0.7]
const SEAT_DZ: float = 0.85
const COUNTER := Vector3(-6.2, 0.0, 3.4)
const START := Vector3(0.0, 0.0, 3.8)
const ACCUSE_M: float = 2.2
const COUNTER_M: float = 2.2
const HUM_M: float = 6.0
const DROP_SUS: float = 20.0
const NO_TRAY_SUS: float = 5.0
const CALM_SUS: float = 1.5
const WRONG_SUS: float = 35.0
const SPRINT_DROP: float = 5.0
const MLEM_GAP := Vector2(2.5, 4.5)
const T_LO_REASON: String = "Cả căn tin quay sang nhìn mày chằm chằm."
const T_WRONG: String = "Ủa... nhầm người rồi! Nghi ngờ tăng"
const T_DROP: String = "Rớt khay! Mọi người đang nhìn..."
const T_FOUND: String = "Bắt được rồi nha, Cừu Dolly!"
const NOTES: Array[String] = ["Đang nhai rau ráu.", "Đang húp canh sùm sụp.", "Đang lướt điện thoại.", "Mlem mlem.",
	"Đang gắp miếng sườn to nhất.", "Đang ngáp."]
const DOLLY_NOTE: String = "Đang ngân nga khe khẽ một giai điệu hộp nhạc..."

var xf: Transform3D = Transform3D.IDENTITY
var props: Node3D
var clones: Array[Node3D] = []
var notes: Array[String] = []
var dolly_index: int = 0
var suspicion: float = 0.0
var has_tray: bool = true
var tray: Node3D
var wrong: int = 0
var drops: int = 0
var mlems: int = 0
var hum: AudioStreamPlayer3D
var bubble: Label3D
var rng := RandomNumberGenerator.new()
var _mlem_t: float = 2.0
var _bubble_t: float = 0.0


func _start() -> void:
	xf = _find_spot()
	props = Node3D.new()
	props.name = "CanteenProps"
	add_child(props)
	props.global_transform = xf
	var body := StaticBody3D.new()
	body.name = "Tables"
	props.add_child(body)
	for tx: float in TABLE_X:
		for dx: float in [-0.7, 0.7]:
			var t: Node3D = CineFX.build_prop("table")
			props.add_child(t)
			t.position = Vector3(tx + dx, 0.0, TABLE_Z)
			var tr: Node3D = CineFX.build_prop("tray", {"food": true})
			props.add_child(tr)
			tr.position = Vector3(tx + dx, 0.76, TABLE_Z + 0.2)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.8, 0.8, 0.8)
		cs.shape = bs
		cs.position = Vector3(tx, 0.4, TABLE_Z)
		body.add_child(cs)
	var counter: Node3D = CineFX.build_prop("counter", {"len": 2.4})
	props.add_child(counter)
	counter.position = COUNTER
	for k: int in 3:
		var stack: Node3D = CineFX.build_prop("tray")
		props.add_child(stack)
		stack.position = COUNTER + Vector3(-0.6 + 0.6 * float(k), 0.97, 0.0)
	var cc := CollisionShape3D.new()
	var cb := BoxShape3D.new()
	cb.size = Vector3(2.4, 0.95, 0.7)
	cc.shape = cb
	cc.position = COUNTER + Vector3(0.0, 0.47, 0.0)
	body.add_child(cc)
	var sign := Label3D.new()
	sign.text = "LẤY KHAY"
	sign.font_size = 48
	sign.pixel_size = 0.008
	sign.outline_size = 8
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = COUNTER + Vector3(0.0, 1.9, 0.0)
	props.add_child(sign)
	bubble = Label3D.new()
	bubble.name = "Mlem"
	bubble.font_size = 44
	bubble.pixel_size = 0.008
	bubble.outline_size = 8
	bubble.modulate = Color("#FFE66D")
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.visible = false
	add_child(bubble)
	tray = CineFX.build_prop("tray", {"food": true})
	tray.name = "HeldTray"
	StoryAudio.warm(["music_box"])
	_reset()


## The seg_d4_brawl box in front of the canteen (cine_stage of CineTimeline.canteen_stage), else the player's spot.
func _find_spot() -> Transform3D:
	var o: Variant = opts.get("xf", null)
	if o is Transform3D:
		return o
	if roam and roam.has_method("cine_stage"):
		var st: Variant = roam.call("cine_stage", CineTimeline.canteen_stage(Vector2(14.0, 10.0), "noon"))
		if st is Transform3D:
			return st
	return Transform3D(Basis.IDENTITY, player.global_position if player else Vector3.ZERO)


func _reset() -> void:
	suspicion = 0.0
	rng.seed = (int(opts["seed"]) + retries * 7) if opts.has("seed") else randi()
	for n: Node in props.get_children():
		if n.has_meta("fallen"):
			n.queue_free()   # the trays dropped before THỬ LẠI
	dolly_index = rng.randi_range(0, CLONES - 1)
	for c: Node3D in clones:
		if is_instance_valid(c):
			c.queue_free()
	clones.clear()
	notes.clear()
	var i: int = 0
	for tx: float in TABLE_X:
		for dx: float in SEAT_DX:
			for side: float in [-1.0, 1.0]:
				var local := Vector3(tx + dx, 0.0, TABLE_Z + side * SEAT_DZ)
				var id: String = "dolly_disguised" if i == dolly_index else "clone"
				var c: Node3D = StoryCast.build(id)
				props.add_child(c)
				c.position = local
				c.rotation.y = 0.0 if side > 0.0 else PI   # faces the table
				clones.append(c)
				notes.append(DOLLY_NOTE if i == dolly_index else NOTES[rng.randi_range(0, NOTES.size() - 1)])
				i += 1
	_setup_hum()
	_give_tray(true)
	teleport_player(free_spot(xf * START, 3), yaw_of(xf.basis * Vector3(0.0, 0.0, -1.0)))
	set_meter(0.0, "Nghi ngờ")
	popup("Bưng khay, đi chậm, tìm Cừu Dolly", 2.6, Color("#FFE66D"))


func _setup_hum() -> void:
	if hum and is_instance_valid(hum):
		hum.queue_free()
	hum = AudioStreamPlayer3D.new()
	hum.name = "Hum"
	hum.unit_size = 1.2
	hum.max_distance = HUM_M + 4.0
	hum.bus = CinePlayer._bus("SFX")
	clones[dolly_index].add_child(hum)
	hum.position = Vector3(0.0, 1.5, 0.0)
	if StoryAudio.ready_for(["music_box"]):
		hum.stream = StoryAudio.stream("music_box")
		hum.volume_db = -6.0
		hum.play()


func dolly() -> Node3D:
	return clones[dolly_index] if dolly_index < clones.size() else null


func _give_tray(on: bool) -> void:
	has_tray = on
	if on:
		var m: Node3D = player.model if player else null
		if tray.get_parent():
			tray.get_parent().remove_child(tray)
		if m:
			m.add_child(tray)
			tray.position = Vector3(0.0, 1.05, -0.38)
			tray.rotation = Vector3.ZERO


## Sprinting with the tray: it falls (a clang, suspicion up); a new one waits at the counter.
func drop_tray() -> void:
	if not has_tray:
		return
	drops += 1
	has_tray = false
	var at: Vector3 = tray.global_position
	tray.get_parent().remove_child(tray)
	var fallen: Node3D = CineFX.build_prop("tray")
	props.add_child(fallen)
	fallen.global_position = Vector3(at.x, ground_y(at) + 0.02, at.z)
	fallen.set_meta("fallen", true)
	add_suspicion(DROP_SUS)
	popup(T_DROP, 2.0, WARN)
	play_cue("tray_clang", -4.0)


func add_suspicion(v: float) -> void:
	suspicion = clampf(suspicion + v, 0.0, 100.0)
	set_meter(suspicion)
	if suspicion >= 100.0:
		fail(T_LO_REASON, T_LO)


## The student in front of the player within `r` (index), -1 when none.
func facing_clone(r: float) -> int:
	if player == null:
		return -1
	var best: int = -1
	var bd: float = r
	var fwd: Vector3 = player.facing_dir()
	for i: int in clones.size():
		var c: Node3D = clones[i]
		var d: Vector3 = c.global_position - player.global_position
		d.y = 0.0
		var dist: float = d.length()
		if dist > bd:
			continue
		if dist > 0.4 and fwd.dot(d / dist) < 0.35:
			continue
		best = i
		bd = dist
	return best


func near_counter() -> bool:
	return player != null and flat(player.global_position, xf * COUNTER) <= COUNTER_M


## [E]: a new tray at the counter, else accuse the student in front.
func interact() -> String:
	if state != "running":
		return ""
	if not has_tray and near_counter():
		_give_tray(true)
		popup("Lấy khay mới. Bình tĩnh nào...", 1.6)
		return "tray"
	var i: int = facing_clone(ACCUSE_M)
	if i < 0:
		return ""
	return accuse(i)


func accuse(i: int) -> String:
	if state != "running" or i < 0 or i >= clones.size():
		return ""
	if i == dolly_index:
		popup(T_FOUND, 2.2, Color("#7CFFB2"))
		finish({"wrong": wrong, "drops": drops})
		return "dolly"
	wrong += 1
	popup(T_WRONG, 2.0, WARN)
	_bubble(clones[i], "Gì vậy trời?")
	play_cue("record_scratch", -6.0)
	add_suspicion(WRONG_SUS)
	return "wrong"


func _bubble(c: Node3D, text: String) -> void:
	bubble.text = text
	bubble.global_position = c.global_position + Vector3(0.0, 2.2, 0.0)
	bubble.visible = true
	_bubble_t = 1.5


func _tick(dt: float) -> void:
	if has_tray and player.is_sprinting and player.horizontal_speed > SPRINT_DROP:
		drop_tray()
	if state != "running":
		return
	add_suspicion((-CALM_SUS if has_tray else NO_TRAY_SUS) * dt)
	if state != "running":
		return
	_mlem_t -= dt
	if _mlem_t <= 0.0:
		_mlem_t = rng.randf_range(MLEM_GAP.x, MLEM_GAP.y)
		mlems += 1
		var k: int = rng.randi_range(0, clones.size() - 1)
		if k != dolly_index:
			_bubble(clones[k], "Mlem mlem")
	if hum and not hum.playing and int(clock * 2.0) != int((clock - dt) * 2.0) and StoryAudio.ready_for(["music_box"]):
		hum.stream = StoryAudio.stream("music_box")   # warmed on a worker thread at the start: plays once it is ready
		hum.volume_db = -6.0
		hum.play()
	if _bubble_t > 0.0:
		_bubble_t -= dt
		if _bubble_t <= 0.0:
			bubble.visible = false
	set_info("Nghi ngờ: %d%% · %s" % [int(suspicion), "Đang bưng khay" if has_tray else "Mất khay! Tới quầy lấy khay"])
	if not has_tray and near_counter():
		set_prompt("[E] Lấy khay mới")
		return
	var i: int = facing_clone(ACCUSE_M)
	set_prompt("%s  [E] Tố cáo" % notes[i] if i >= 0 else "")


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_E:
		if interact() != "":
			get_viewport().set_input_as_handled()


func _cleanup() -> void:
	if tray and is_instance_valid(tray):
		tray.queue_free()
	if props and is_instance_valid(props):
		props.queue_free()
	clones.clear()
