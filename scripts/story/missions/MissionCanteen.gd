# File: res://scripts/story/missions/MissionCanteen.gd
# Day 4 canteen undercover (spec B-D7 beat 3): a story scene built from Stage 5's canteen (its tray rule, the cine props),
# staged in FreeRoam in front of the real canteen (CineTimeline.canteen_stage, the box seg_d4_brawl and cine_d4_stare
# use, so the stare and the brawl follow on the same spot). See the integration plan for why not a Stage 5 story mode.
#   - 3 table groups, CLONES identical students eating (StoryCast "clone"); one of them is the real Cừu Dolly
#     (StoryCast "dolly_disguised"): she hums a music-box tune (positional, audible within HUM_M), wears a cream wool cuff
#     and a sheep keychain; walking up to a student shows what you notice about them.
#   - The tray is the disguise: carried calmly it lowers the suspicion meter; sprinting drops it (+drop_sus()) and without a
#     tray the meter rises (no_tray_sus() / s) until a new one is taken at the counter ([E] there).
#   - [E] facing a student within ACCUSE_M accuses them (the same radius shows their note and "[E] Tố cáo"): Dolly = done;
#     anyone else = +wrong_sus() ("Ủa..."). Dolly's seat is random (opts.seed fixes it for tests).
#   - A full meter = "BỊ LỘ" (retry: the meter, the tray and the students reset, Dolly elsewhere).
#   - Meme: "Mlem mlem" bubbles over the eaters.
# Wave 2 clue search (plan 2026-10-29-w2-early.md Task 8, master plan Q4b): the real Dolly is the only student with all
# three CLUES: she hums the music-box tune, a cream wool thread on her sleeve (the cuff), a grass salad on her tray. A few
# DECOYS share one or two (a student humming pop along to earbuds, another in a cream cardigan eating salad, a salad eater;
# Thường adds a fourth). Walking up to a student shows what you notice (the note). Linh's hints come as radio chatter, one
# clue every 12 s (LINH_AT), then a joke beat; lunch ends after lunch_s() (Dolly slips out: a fail). Staring at the same student up close longer than stare_s() raises
# suspicion; a wrong accusation costs wrong_sus(). Every tuned number goes through Difficulty.pick(normal, easy).
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
const SPRINT_DROP: float = 5.0
const STARE_M: float = 1.7
const LINH_AT: Array[float] = [2.5, 14.0, 26.0, 38.0]
const T_LUNCH_OVER: String = "Hết giờ ăn trưa, Cừu Dolly lẩn vào đám đông mất rồi."
const LINH_LINES: Array[String] = ["Dolly mê bài hộp nhạc lắm, lúc ăn hay ngân nga khe khẽ đó.",
	"Nghe nói nó tự đan áo len màu kem. Kiểu gì tay áo cũng dính sợi len.",
	"Nó ăn chay trường. Ý tao là... ăn cỏ. Khay nào toàn rau là đáng nghi.",
	"Mày đứng nhìn người ta ăn lâu quá, coi chừng bị tưởng đi xin cơm đó."]
const HUM_NOTE: String = "Đang ngân nga khe khẽ một giai điệu hộp nhạc..."
const POP_NOTE: String = "Đang ngân nga theo tai nghe, nhạc pop sôi động."
const WOOL_NOTE: String = "Tay áo dính sợi len màu kem."
const SALAD_NOTE: String = "Khay toàn rau xanh, không một miếng thịt."
const SALAD := Color("#5DBB63")
const MLEM_GAP := Vector2(2.5, 4.5)
const T_LO_REASON: String = "Cả căn tin quay sang nhìn mày chằm chằm."
const T_WRONG: String = "Ủa... nhầm người rồi! Nghi ngờ tăng"
const T_DROP: String = "Rớt khay! Mọi người đang nhìn..."
const T_FOUND: String = "Bắt được rồi nha, Cừu Dolly!"
const NOTES: Array[String] = ["Đang nhai rau ráu.", "Đang húp canh sùm sụp.", "Đang lướt điện thoại.", "Mlem mlem.",
	"Đang gắp miếng sườn to nhất.", "Đang ngáp."]
const DOLLY_NOTE: String = HUM_NOTE

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
## Per student: {"hum": bool (the music-box tune), "pop": bool (a decoy humming along to earbuds), "wool": bool, "salad": bool}.
var clues: Array[Dictionary] = []
var trays: Array[Node3D] = []
var decoy_hums: Array[AudioStreamPlayer3D] = []
var hints_given: int = 0
var stare_t: float = 0.0
var _stare_i: int = -1


## Difficulty-tuned numbers (Thường, Dễ).
## Lunch ends: Dolly slips out with the crowd (a fail) after this long.
static func lunch_s() -> float:
	return float(Difficulty.pick(44.0, 120.0))


static func drop_sus() -> float:
	return float(Difficulty.pick(25.0, 14.0))


static func no_tray_sus() -> float:
	return float(Difficulty.pick(8.0, 3.5))


static func calm_sus() -> float:
	return float(Difficulty.pick(0.8, 2.5))


static func wrong_sus() -> float:
	return float(Difficulty.pick(60.0, 25.0))


static func stare_s() -> float:
	return float(Difficulty.pick(2.4, 4.5))


static func stare_sus() -> float:
	return float(Difficulty.pick(18.0, 6.0))


## Decoy clue sets (students other than Dolly): Thường four, Dễ two.
static func decoy_sets() -> Array:
	return Difficulty.pick([{"pop": true}, {"wool": true, "salad": true}, {"salad": true}, {"pop": true, "wool": true}],
		[{"pop": true}, {"salad": true}])


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
	for tr0: Node3D in trays:
		if is_instance_valid(tr0):
			tr0.queue_free()
	trays.clear()
	for h0: AudioStreamPlayer3D in decoy_hums:
		if is_instance_valid(h0):
			h0.queue_free()
	decoy_hums.clear()
	clues.clear()
	var decoys: Array = decoy_sets()
	var pick: Array[int] = []
	while pick.size() < decoys.size():
		var k: int = rng.randi_range(0, CLONES - 1)
		if k != dolly_index and not pick.has(k):
			pick.append(k)
	for k2: int in CLONES:
		var cl: Dictionary = {"hum": false, "pop": false, "wool": false, "salad": false}
		if k2 == dolly_index:
			cl = {"hum": true, "pop": false, "wool": true, "salad": true}
		elif pick.has(k2):
			var dset: Dictionary = decoys[pick.find(k2)]
			for key: String in dset:
				cl[key] = true
		clues.append(cl)
	hints_given = 0
	stare_t = 0.0
	_stare_i = -1
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
				var cl2: Dictionary = clues[i]
				if bool(cl2["wool"]) and i != dolly_index:
					StoryCast.attach_tells(c, false)   # the cream cuff only (Dolly also has the keychain)
				trays.append(_seat_tray(local, side, bool(cl2["salad"])))
				if bool(cl2["pop"]):
					_decoy_hum(c)
				notes.append(_note(cl2))
				i += 1
	_setup_hum()
	_give_tray(true)
	teleport_player(free_spot(xf * START, 3), yaw_of(xf.basis * Vector3(0.0, 0.0, -1.0)))
	set_meter(0.0, "Nghi ngờ")
	popup("Bưng khay, đi chậm, tìm Cừu Dolly", 2.6, Color("#FFE66D"))


## The note for a student's clues: what you notice up close (ordinary students: a random everyday line).
func _note(cl: Dictionary) -> String:
	var parts: PackedStringArray = []
	if bool(cl["hum"]):
		parts.append(HUM_NOTE)
	if bool(cl["pop"]):
		parts.append(POP_NOTE)
	if bool(cl["wool"]):
		parts.append(WOOL_NOTE)
	if bool(cl["salad"]):
		parts.append(SALAD_NOTE)
	if parts.is_empty():
		return NOTES[rng.randi_range(0, NOTES.size() - 1)]
	return " ".join(parts)


## The student's own tray on the table in front of them; a salad tray is a heap of green leaves.
func _seat_tray(seat: Vector3, side: float, salad: bool) -> Node3D:
	var tr: Node3D = CineFX.build_prop("tray", {"food": not salad})
	props.add_child(tr)
	tr.position = Vector3(seat.x, 0.76, seat.z - side * 0.42)
	if salad:
		var m := StandardMaterial3D.new()
		m.albedo_color = SALAD
		for k: int in 4:
			var leaf := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.06
			sm.radial_segments = 6
			sm.rings = 3
			leaf.mesh = sm
			leaf.material_override = m
			leaf.position = Vector3(-0.1 + 0.07 * float(k), 0.035, 0.03 * float(k % 2))
			tr.add_child(leaf)
		tr.set_meta("salad", true)
	return tr


## A decoy humming pop along to earbuds: a quieter, higher tune on the same music-box synth.
func _decoy_hum(c: Node3D) -> void:
	var h := AudioStreamPlayer3D.new()
	h.name = "PopHum"
	h.unit_size = 1.0
	h.max_distance = HUM_M + 2.0
	h.pitch_scale = 1.45
	h.bus = CinePlayer._bus("SFX")
	c.add_child(h)
	h.position = Vector3(0.0, 1.5, 0.0)
	decoy_hums.append(h)


## Linh on the radio (her hint lines, bottom left, in the base radio panel with her name).
func linh(line: String, secs: float = 6.0) -> void:
	cues_played.append("linh")
	if radio_panel == null:
		return
	radio_label.text = "LINH (bộ đàm): %s" % line
	radio_panel.visible = true
	_radio_t = secs


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
	add_suspicion(drop_sus())
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
	add_suspicion(wrong_sus())
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
	add_suspicion((-calm_sus() if has_tray else no_tray_sus()) * dt)
	if state != "running":
		return
	if clock >= lunch_s():
		fail(T_LUNCH_OVER)
		return
	if hints_given < LINH_AT.size() and clock >= LINH_AT[hints_given]:
		linh(LINH_LINES[hints_given])
		hints_given += 1
	_tick_stare(dt)
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
		for dh: AudioStreamPlayer3D in decoy_hums:
			if is_instance_valid(dh) and not dh.playing:
				dh.stream = hum.stream
				dh.volume_db = -11.0
				dh.play()
	if _bubble_t > 0.0:
		_bubble_t -= dt
		if _bubble_t <= 0.0:
			bubble.visible = false
	set_info("Nghi ngờ: %d%% · Còn %d giây · %s" % [int(suspicion), int(ceil(maxf(lunch_s() - clock, 0.0))), "Đang bưng khay" if has_tray else "Mất khay! Tới quầy lấy khay"])
	if not has_tray and near_counter():
		set_prompt("[E] Lấy khay mới")
		return
	var i: int = facing_clone(ACCUSE_M)
	set_prompt("%s  [E] Tố cáo" % notes[i] if i >= 0 else "")


## Staring at the same student up close for longer than stare_s() raises suspicion ("Nhìn gì mà nhìn?").
func _tick_stare(dt: float) -> void:
	var i: int = facing_clone(STARE_M)
	if i < 0 or i != _stare_i:
		_stare_i = i
		stare_t = 0.0
		return
	stare_t += dt
	if stare_t > stare_s():
		if stare_t - dt <= stare_s():
			_bubble(clones[i], "Nhìn gì mà nhìn?")
		add_suspicion(stare_sus() * dt)


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
