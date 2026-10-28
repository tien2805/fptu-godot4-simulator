# File: res://scripts/horror/NightBuilding.gd
# Night Building level (spec B-D4; scene res://scenes/story/NightBuilding.tscn): escape one floor of the campus building at
# night while 4 sheep-masked clones hunt you. Find 3 fuses (a random 3 of 6 spots, one per classroom), put them in the fuse
# box of the generator room (each fuse placed is a checkpoint), then the lobby's glass doors unlock; walk out to escape.
# Runs standalone (open the scene and play) and from the story through the API below.
#
# LEVEL API (integration: Day 4 night escape)
#   setup(opts)                 call before adding the scene, or right after (same frame); a later call rebuilds.
#     opts.protagonist: Dictionary   CharacterBuilder opts of the player (default StoryUtil.hero_opts(), else the roam player)
#     opts.seed: int                 fuse / battery spots and patrol timing (default random)
#     opts.reduce_scares: bool       "Giảm hù dọa" override (default the GameFX setting through StoryUtil)
#     opts.auto_retry: bool          retry from the checkpoint RETRY_DELAY s after a catch (default true)
#     opts.stalkers: int             0..4 (default 4)
#     opts.jump_budget: int          jump scares in this mission, 1..2 (default 2)
#     opts.catch_enabled: bool       default true (perf test / debugging: false)
#     opts.capture_mouse: bool       capture the mouse on click (default true; tests false)
#     opts.caught_count: int         starting catch count (default 0); caught_count is kept across a setup() rebuild, so E5
#                                    (never caught) can be read from escaped(caught_count) even if the story rebuilds
#   signals
#     escaped(caught_count: int)     walked out through the open doors (E5 is earned when caught_count == 0)
#     caught                         a stalker caught the player (the catch scare plays)
#     fuse_placed(n: int)            n fuses in the box (1..3)
#     checkpoint                     a checkpoint was saved (after every fuse placed)
#   retry_from_checkpoint()      player back at the last checkpoint (start, or the fuse box): carried fuses go back to their
#                                spots, placed ones stay, batteries taken after the checkpoint go back, the charge returns to
#                                the checkpoint's (at least 25 %), each stalker on its waypoint farthest from the checkpoint,
#                                patrolling. Ignored once escaped or released.
#   release()                    clean exit: freezes stalkers, stops sounds and keys, leaves a hiding spot, frees the mouse
#                                and clears this level's current camera (make the story camera current afterwards).
#   The story's own [E] handler (StoryRoam's KEY_E) must be off while the level runs: the level reads E and F itself
#   (physical keys, _unhandled_input, marked handled).
#   state: "play" | "caught" | "escaped" | "released"; fuses_placed, fuses_carried, caught_count, doors_unlocked, player, kit, stalkers,
#   scare, flashlight, hud, graph, fuse_candidates (6 {room, pos, reach, node}), active_fuses (3 candidate indices),
#   fuse_state ("spot" | "carried" | "placed" per active fuse), fuse_box {pos, yaw, slots}.
#   Keys: [F] flashlight, [E] hide / leave / pick up / place fuses (HorrorKit + interact hook), WASD, Shift, Ctrl.
#   The scene must stay at the world origin (stalkers walk the level-local waypoint graph in global coordinates).
# HORROR POLISH (spec H-D1 to H-D6; names the music side may read, all kept stable):
#   dolly: HorrorStalker        the stalker that is Cừu Dolly (seeded one of the four; StoryCast "dolly" look, DOLLY_SPEED,
#                               a positional music-box hum loop); null with 0 stalkers
#   alarm: bool                 true from the third fuse on (with doors_unlocked); signal alarm_started emitted once
#   kit.breath_held: bool       the player holds the breath in a hiding spot (Shift); kit.is_hidden(), kit.hidden_spot
#   stalkers[i].state           PATROL | SUSPICIOUS | CHASE | SEARCH | CHECK (stalkers[i].rushing: running at the alarm)
#   fakeouts: HorrorFakeouts    the run's 1-2 seeded fake-outs (coat, cat)
#   Catch: the staged per-spot catch scare (ScareDirector.play_catch_scare(spot kind or "open")), the caught card after it.
#   Third fuse: the corridor lights flash SOS in red (SosLights, a slow pulse with "Giảm hù dọa"), the alarm_siren loop,
#   every stalker rushes the player (re-issued every RUSH_REPATH_S while the player is not hidden, held RUSH_HOLD_S after a
#   retry; a stalker that loses the player searches only ALARM_SEARCH_S, so a hiding spot can still work), the lobby doors
#   open: the final sprint (toasts point to the exit).
#   night_scares: NightScares   scripted scare events across the floor (window slam, ceiling drop, locker lunge, flashlight
#                               cut, behind you, mirror, TV; atmosphere: door slam, bell, PA whisper, the phone ringing:
#                               a noise the hunters hear, [P] stops it); opts.scare_events: bool (default true; tests off)
#   wc: DollyWC                 the toilet monologue (owner request; any of the four hunters, the first that comes for a
#                               player hidden in a stall of that block, one at a time, every visit): wc.running while it
#                               plays, wc.performer the hunter (scripted in CHECK; the others cannot check that stall
#                               until the outcome); the owner file user://sfx/dolly_wc_full, else subtitles only.
# HUD: "Cầu chì: n/3", battery, objective, prompts "[E] Trốn", "[E] Ra", "[E] Nhặt cầu chì", "[E] Lắp cầu chì", "[E] Nhặt
# pin", hint "[F] Đèn pin"; plain text without emoji or decorative symbols.
class_name NightBuilding
extends Node3D

signal escaped(caught_count: int)
signal caught
signal fuse_placed(n: int)
signal checkpoint
signal alarm_started

const FUSES_NEEDED: int = 3
const BATTERIES: int = 3
const BATTERY_FRAC: float = 0.6
const RETRY_DELAY: float = 2.5
const RETRY_MIN_BATTERY: float = 0.25
const MAX_STALKERS: int = 4
const PLAYER_DEFAULT: Dictionary = {"preset": "player", "rigged": true, "seed": 2805, "name": "PlayerModel"}
const HUD_DT: float = 0.1
const RUSH_REPATH_S: float = 1.5
const RUSH_HOLD_S: float = 3.0
const ALARM_SEARCH_S: float = 5.0
const T_ALARM: String = "Có điện rồi! Báo động kêu, chúng đang tới. Chạy ra cửa sảnh theo biển LỐI THOÁT màu xanh!"
const T_ALARM_HIDE: String = "Chúng đang lùng sục. Đợi chúng đi qua rồi chạy ra cửa sảnh!"
const SIREN_DB: float = -14.0
const POLISH_CUES: Array[String] = ["dolly_hum", "gasp", "alarm_siren", "cat_meow", "bin_crash", "locker_slam", "door_knock", "sniff"]

var opts: Dictionary = {}
var seed_val: int = 0
var state: String = "build"
var fuses_placed: int = 0
var fuses_carried: int = 0
var caught_count: int = 0
var doors_unlocked: bool = false
var alarm: bool = false
var auto_retry: bool = true
var map: Dictionary = {}
var graph: HorrorNavGraph = null
var player: ThirdPersonController = null
var kit: HorrorKit = null
var scare: ScareDirector = null
var flashlight: HorrorFlashlight = null
var hud: HorrorHUD = null
var stalkers: Array[HorrorStalker] = []
var figure: HorrorStalker = null
var dolly: HorrorStalker = null
var sos: SosLights = null
var fakeouts: HorrorFakeouts = null
var siren: AudioStreamPlayer = null
var wc: DollyWC = null
var night_scares: NightScares = null
var fuse_candidates: Array = []
var active_fuses: Array[int] = []
var fuse_state: Array[String] = []
var fuse_items: Array[Node3D] = []
var fuse_box: Dictionary = {}
var batteries: Array[Dictionary] = []   # {node, pos, taken}
var checkpoint_data: Dictionary = {}
var build_ms: float = 0.0
var rng := RandomNumberGenerator.new()
var _built: bool = false
var _retry_t: float = -1.0
var _hud_t: float = 0.0
var _anim_t: float = 0.0
var _noise_queue: Array = []   # [{s: HorrorStalker, pos: Vector3, rush: bool}], one per physics frame
var _rush_t: float = -1.0
var _card_t: float = -1.0


func _ready() -> void:
	if not _built:
		build.call_deferred()


func setup(o: Dictionary) -> void:
	opts = o.duplicate()
	if opts.has("caught_count"):
		caught_count = int(opts["caught_count"])
	if _built:
		_rebuild()


func _rebuild() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	stalkers.clear()
	fuse_items.clear()
	fuse_state.clear()
	active_fuses.clear()
	batteries.clear()
	fuses_placed = 0
	fuses_carried = 0
	doors_unlocked = false   # caught_count survives a rebuild (E5 needs every catch of the mission)
	alarm = false
	dolly = null
	sos = null
	fakeouts = null
	siren = null
	wc = null
	night_scares = null
	_rush_t = -1.0
	_card_t = -1.0
	_noise_queue.clear()
	_retry_t = -1.0
	_built = false
	build()


## Builds the level now (idempotent; _ready defers it one frame so setup() can come right after add_child).
func build() -> void:
	if _built:
		return
	_built = true
	var t0: int = Time.get_ticks_usec()
	seed_val = int(opts.get("seed", randi()))
	rng.seed = seed_val
	auto_retry = bool(opts.get("auto_retry", true))
	map = NightBuildingMap.build(self)
	graph = map["graph"]
	fuse_box = map["fuse_box"]
	# player
	player = ThirdPersonController.new()
	player.name = "Player"
	player.character_opts = opts.get("protagonist", StoryUtil.hero_opts(PLAYER_DEFAULT))
	player.capture_on_click = bool(opts.get("capture_mouse", true))
	add_child(player)
	var st: Dictionary = map["start"]
	player.teleport(st["pos"], float(st["yaw"]))
	player.camera.make_current()
	flashlight = HorrorFlashlight.new()
	add_child(flashlight)
	add_child(FxPool.new())   # Q3 VFX pool (group "fx_pool")
	scare = ScareDirector.new()
	scare.reduce_scares = bool(opts["reduce_scares"]) if opts.has("reduce_scares") else StoryUtil.reduce_scares()
	scare.budget = clampi(int(opts.get("jump_budget", ScareDirector.MAX_JUMP)), 1, ScareDirector.MAX_JUMP)
	add_child(scare)
	scare.set_seed(seed_val)
	scare.register_light_groups(map["light_groups"])
	scare.catch_beat.connect(_on_catch_beat)
	StoryAudio.warm(POLISH_CUES)
	kit = HorrorKit.new()
	add_child(kit)
	kit.setup(player, flashlight, scare, graph)
	kit.interact_hook = _interact
	kit.prompt_hook = _prompt
	kit.catch_enabled = bool(opts.get("catch_enabled", true))
	for s: Variant in map["spots"]:
		kit.add_spot(s)
	kit.caught.connect(_on_caught)
	kit.hide_changed.connect(_on_hide_changed)
	kit.gasped.connect(_on_gasp)
	# stalkers and the jump-scare figure
	var n: int = clampi(int(opts.get("stalkers", MAX_STALKERS)), 0, MAX_STALKERS)
	var patrols: Array = map["patrols"]
	var pick := RandomNumberGenerator.new()   # own draw: the level's rng sequence stays as before
	pick.seed = seed_val * 31 + 5
	var dolly_i: int = pick.randi_range(0, n - 1) if n > 0 else -1
	for i: int in n:
		var sk := HorrorStalker.new()
		sk.name = "Stalker%d" % i
		if i == dolly_i:
			sk.make_dolly(scare.reduce_scares)
			sk.name = "Dolly"
			dolly = sk
		add_child(sk)
		sk.setup(graph, kit.senses, patrols[i % patrols.size()], 0, seed_val + 31 * i)
		sk.reset_at(graph.pos((patrols[i % patrols.size()] as PackedInt32Array)[0]))
		sk._wait = rng.randf_range(0.0, 3.0)   # out of step with each other
		sk.state_changed.connect(_on_stalker_state)
		kit.add_stalker(sk)
		stalkers.append(sk)
	figure = HorrorStalker.new()
	figure.name = "ScareFigure"
	figure.auto_update = false
	figure.frozen = true
	add_child(figure)
	figure.visible = false
	figure.process_mode = Node.PROCESS_MODE_DISABLED   # no animation until a scare shows it
	scare.figure = figure
	# fuses and batteries
	fuse_candidates = map["fuse_candidates"]
	var order: Array = range(fuse_candidates.size())
	_shuffle(order)
	for k: int in FUSES_NEEDED:
		var ci: int = int(order[k])
		active_fuses.append(ci)
		fuse_state.append("spot")
		var item: Node3D = _fuse_item()
		add_child(item)
		item.position = (fuse_candidates[ci] as Dictionary)["pos"]
		fuse_items.append(item)
	var bc: Array = map["battery_candidates"]
	var border: Array = range(bc.size())
	_shuffle(border)
	for k: int in mini(BATTERIES, bc.size()):
		var c: Dictionary = bc[int(border[k])]
		var bn: Node3D = _battery_item()
		add_child(bn)
		bn.position = c["pos"]
		batteries.append({"node": bn, "pos": c["pos"], "reach": c["reach"], "room": c["room"], "taken": false})
	hud = HorrorHUD.new()
	add_child(hud)
	fakeouts = HorrorFakeouts.new()
	add_child(fakeouts)
	fakeouts.setup(seed_val, scare, flashlight, player, hud)
	fakeouts.noise.connect(_on_fake_noise)
	night_scares = NightScares.new()
	add_child(night_scares)
	night_scares.setup(self, seed_val)
	night_scares.enabled = bool(opts.get("scare_events", true))
	fakeouts.fired.connect(night_scares.on_fakeout)
	if not stalkers.is_empty():
		wc = DollyWC.new()
		add_child(wc)
		wc.setup(self, stalkers, kit, scare, hud)
	if dolly != null and dolly.hum != null:
		scare.register_duck(dolly.hum)
	checkpoint_data = {"pos": st["pos"], "yaw": float(st["yaw"]), "battery": 1.0, "taken": _taken_flags()}
	state = "play"
	_refresh_hud()
	hud.toast("Cửa sảnh bị khóa. Tìm 3 cầu chì trong các phòng học rồi lắp vào hộp điện ở phòng máy phát.", 6.0)
	build_ms = float(Time.get_ticks_usec() - t0) / 1000.0


func _shuffle(a: Array) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


func _fuse_item() -> Node3D:
	var n := Node3D.new()
	n.name = "Fuse"
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 0.2
	body.mesh = cm
	body.rotation.z = PI * 0.5
	body.position.y = 0.06
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#F2E6C9")
	body.material_override = bm
	n.add_child(body)
	for sx: float in [-0.1, 0.1]:
		var cap := MeshInstance3D.new()
		var capm := CylinderMesh.new()
		capm.top_radius = 0.05
		capm.bottom_radius = 0.05
		capm.height = 0.04
		cap.mesh = capm
		cap.rotation.z = PI * 0.5
		cap.position = Vector3(sx, 0.06, 0.0)
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color("#FFB347")
		gm.emission_enabled = true
		gm.emission = Color("#FFB347")
		gm.emission_energy_multiplier = 2.2
		cap.material_override = gm
		n.add_child(cap)
	return n


func _battery_item() -> Node3D:
	var n := Node3D.new()
	n.name = "Battery"
	var body := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.14, 0.09, 0.07)
	body.mesh = bx
	body.position.y = 0.05
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#1E2328")
	body.material_override = bm
	n.add_child(body)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.05, 0.092, 0.072)
	band.mesh = bb
	band.position = Vector3(0.03, 0.05, 0.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#5CFF8A")
	gm.emission_enabled = true
	gm.emission = Color("#5CFF8A")
	gm.emission_energy_multiplier = 1.8
	band.material_override = gm
	n.add_child(band)
	return n


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------
static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _near_fuse() -> int:
	var p: Vector3 = player.global_position
	for k: int in active_fuses.size():
		if fuse_state[k] == "spot" and _flat_dist(fuse_items[k].position, p) <= NightBuildingMap.PICK_R:
			return k
	return -1


func _near_battery() -> int:
	var p: Vector3 = player.global_position
	for k: int in batteries.size():
		if not bool(batteries[k]["taken"]) and _flat_dist(batteries[k]["pos"], p) <= NightBuildingMap.PICK_R:
			return k
	return -1


func _near_box() -> bool:
	return _flat_dist(fuse_box["pos"], player.global_position) <= NightBuildingMap.FUSE_BOX_R


## Level part of [E] (HorrorKit calls it before hiding). true = the key was used.
func _interact() -> bool:
	if state != "play":
		return true
	var f: int = _near_fuse()
	if f >= 0:
		collect_fuse(f)
		return true
	var b: int = _near_battery()
	if b >= 0:
		collect_battery(b)
		return true
	if fuses_carried > 0 and _near_box():
		place_fuses()
		return true
	return false


func _prompt() -> String:
	if state != "play" or player == null:
		return ""
	if _near_fuse() >= 0:
		return "[E] Nhặt cầu chì"
	if _near_battery() >= 0:
		return "[E] Nhặt pin"
	if fuses_carried > 0 and _near_box():
		return "[E] Lắp cầu chì"
	return ""


## [E] as if pressed (tests, bots).
func interact() -> bool:
	return kit.interact()


## Picks up active fuse k (0..2).
func collect_fuse(k: int) -> void:
	if k < 0 or k >= fuse_state.size() or fuse_state[k] != "spot":
		return
	fuse_state[k] = "carried"
	fuse_items[k].visible = false
	fuses_carried += 1
	var total_found: int = fuses_carried + fuses_placed
	scare.play_cue("metal_creak", -10.0)
	if total_found == 1:
		scare.try_jump_scare()
		scare.flicker_near(player.global_position)
	hud.toast("Đã nhặt cầu chì. Đang cầm %d." % fuses_carried, 2.5)
	_refresh_hud()


func collect_battery(k: int) -> void:
	if k < 0 or k >= batteries.size() or bool(batteries[k]["taken"]):
		return
	batteries[k]["taken"] = true
	(batteries[k]["node"] as Node3D).visible = false
	flashlight.add_battery(BATTERY_FRAC)
	hud.toast("Đã nhặt pin. Đèn pin được sạc thêm.", 2.0)
	_refresh_hud()


## Puts every carried fuse into the box; each one emits fuse_placed(n) and saves a checkpoint. 3 fuses unlock the doors.
func place_fuses() -> void:
	if fuses_carried <= 0:
		return
	var slots: Array = fuse_box["slots"]
	for k: int in fuse_state.size():
		if fuse_state[k] != "carried":
			continue
		fuse_state[k] = "placed"
		fuses_carried -= 1
		fuses_placed += 1
		if fuses_placed - 1 < slots.size():
			var sm: StandardMaterial3D = slots[fuses_placed - 1]
			sm.albedo_color = Color("#3DFF7A")
			sm.emission = Color("#3DFF7A")
		fuse_placed.emit(fuses_placed)
		_save_checkpoint()
	if fuses_placed >= FUSES_NEEDED and not doors_unlocked:
		_unlock_doors()
	else:
		hud.toast("Đã lắp %d/3 cầu chì. Đã lưu tiến độ." % fuses_placed, 3.0)
	_refresh_hud()


func _save_checkpoint() -> void:
	checkpoint_data = {"pos": fuse_box["pos"], "yaw": float(fuse_box["yaw"]), "battery": flashlight.battery, "taken": _taken_flags()}
	checkpoint.emit()


func _taken_flags() -> Array[bool]:
	var out: Array[bool] = []
	for b: Dictionary in batteries:
		out.append(bool(b["taken"]))
	return out


func _unlock_doors() -> void:
	doors_unlocked = true
	var d: Dictionary = map["doors"]
	(d["shape"] as CollisionShape3D).set_deferred("disabled", true)
	var panels: Array = d["panels"]
	for i: int in panels.size():
		var pn: Node3D = panels[i]
		var sx: float = -1.0 if i == 0 else 1.0
		var tw: Tween = create_tween()
		tw.tween_property(pn, "position:x", sx * (NightBuildingMap.GLASS_HALF * 0.5 + 2.2), 1.6)
	var lm: StandardMaterial3D = d["lock_mat"]
	lm.albedo_color = Color("#3DFF7A")
	lm.emission = Color("#3DFF7A")
	var ll: Label3D = d["lock_label"]
	ll.text = "MỞ"
	ll.modulate = Color("#7CFFB2")
	_start_alarm()
	scare.flicker_near(player.global_position)   # the rooms around stutter (the corridor is the SOS lights' now)
	scare.try_jump_scare()
	hud.toast(T_ALARM, 4.0)


## The third fuse (H-D5): SOS on the corridor lights, the siren, every stalker rushes the player.
func _start_alarm() -> void:
	if alarm:
		return
	alarm = true
	var mats: Array = map.get("corridor_lights", [])
	scare.drop_light_groups(mats)
	sos = SosLights.new()
	add_child(sos)
	sos.start(mats, scare.reduce_scares)
	siren = AudioStreamPlayer.new()
	siren.name = "AlarmSiren"
	if AudioServer.get_bus_index("SFX") != -1:
		siren.bus = "SFX"
	add_child(siren)
	scare.register_duck(siren)
	_try_siren()
	for s: HorrorStalker in stalkers:
		s.search_s = ALARM_SEARCH_S
	_noise_queue.clear()
	_rush_t = 0.0
	alarm_started.emit()


func _try_siren() -> void:
	if siren == null or siren.playing or not alarm or state in ["escaped", "released"]:
		return
	if not StoryAudio.ready_for(["alarm_siren"]):
		return
	siren.stream = StoryAudio.stream("alarm_siren")
	siren.volume_db = SIREN_DB + scare.cue_db("alarm_siren")
	siren.play()


## Queues every stalker to rush the player (one re-route per physics frame: no 4-route hitch).
func _queue_rush() -> void:
	for s: HorrorStalker in stalkers:
		_noise_queue.append({"s": s, "pos": Vector3.ZERO, "rush": true})


# ---------------------------------------------------------------------------
# Catch, retry, escape
# ---------------------------------------------------------------------------
func _on_caught(catcher: HorrorStalker) -> void:
	if state != "play":
		return
	state = "caught"
	caught_count += 1
	if wc != null:
		wc.abort()   # the monologue stops on any catch
	if night_scares != null:
		night_scares.cancel()
	kit.input_enabled = false
	player.controls_enabled = false
	scare.play_catch_scare(kit.hidden_spot.kind if kit.is_hidden() else "open", catcher == null or catcher.is_dolly)
	_card_t = scare.catch_total()   # the caught card after the staged scare (its duck included)
	caught.emit()
	if auto_retry:
		_retry_t = RETRY_DELAY


func retry_from_checkpoint() -> void:
	if not _built or state == "escaped" or state == "released":
		return
	_retry_t = -1.0
	_card_t = -1.0
	if wc != null:
		wc.abort()
	if night_scares != null:
		night_scares.cancel()
	scare.cancel_catch()
	if kit.is_hidden():
		kit.leave_hiding()
	for s: Variant in map["spots"]:
		(s as HidingSpot).reset_spot()
	for k: int in fuse_state.size():
		if fuse_state[k] == "carried":
			fuse_state[k] = "spot"
			fuse_items[k].visible = true
	fuses_carried = 0
	# batteries picked up after the checkpoint go back on their spots, the charge back to the checkpoint's (at least 25 %)
	var taken: Array = checkpoint_data.get("taken", [])
	for k: int in batteries.size():
		var was: bool = k < taken.size() and bool(taken[k])
		batteries[k]["taken"] = was
		(batteries[k]["node"] as Node3D).visible = not was
	flashlight.set_on(false)
	flashlight.battery = maxf(float(checkpoint_data.get("battery", 1.0)), RETRY_MIN_BATTERY)
	_noise_queue.clear()
	var cp: Vector3 = checkpoint_data["pos"]
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.teleport(cp, float(checkpoint_data["yaw"]))
	player.controls_enabled = true
	player.camera.make_current()
	for s: HorrorStalker in stalkers:
		s.reset_at(_far_waypoint(s, cp))
	kit.set_frozen(false)
	kit.input_enabled = true
	if alarm:
		_rush_t = RUSH_HOLD_S   # a head start before they rush again
	state = "play"
	hud.show_caught(false)
	_refresh_hud()


## The stalker's patrol waypoint farthest from p.
func _far_waypoint(s: HorrorStalker, p: Vector3) -> Vector3:
	var best: Vector3 = s.global_position
	var bd: float = -1.0
	for id: int in s.patrol:
		var q: Vector3 = graph.pos(id)
		var d: float = q.distance_squared_to(p)
		if d > bd:
			bd = d
			best = q
	return best


## Clean exit for the story: stops the level (stalkers frozen, sounds off, keys ignored), leaves any hiding spot, frees
## the mouse and drops this level's camera so the caller's camera can take over (make yours current after this).
## Safe in any state; state becomes "released" unless it is "escaped".
func release() -> void:
	if not _built:
		return
	_retry_t = -1.0
	_noise_queue.clear()
	if kit.is_hidden():
		kit.leave_hiding()
	kit.input_enabled = false
	kit.set_frozen(true)
	player.controls_enabled = false
	player.capture_on_click = false
	flashlight.set_on(false)
	scare.stop_all()
	_stop_sounds()
	if state != "escaped":
		state = "released"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for cam: Node in find_children("*", "Camera3D", true, false):
		(cam as Camera3D).clear_current(false)


## Dolly's hum, the siren and the fake-outs stop (escape, release).
func _stop_sounds() -> void:
	_card_t = -1.0
	_rush_t = -1.0
	if dolly != null and is_instance_valid(dolly):
		dolly.set_hum(false)
	if siren != null:
		siren.stop()
	if fakeouts != null:
		fakeouts.enabled = false
	if wc != null:
		wc.abort()
	if night_scares != null:
		night_scares.cancel()
		night_scares.enabled = false


func _escape() -> void:
	state = "escaped"
	kit.set_frozen(true)
	kit.input_enabled = false
	player.controls_enabled = false
	scare.stop_all()
	_stop_sounds()
	hud.show_escaped(caught_count)
	if is_standalone():
		hud.set_objective("Nhấn R để chơi lại.")
	escaped.emit(caught_count)


## Standalone (the level is the current scene, no story running): [R] after the escape plays again.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if state == "play" and k.pressed and not k.echo and k.physical_keycode == KEY_P and night_scares != null and night_scares.phone_ringing:
		night_scares.stop_phone()   # [P]: the ringing phone goes quiet
		get_viewport().set_input_as_handled()
		return
	if state != "escaped":
		return
	if k.pressed and not k.echo and k.physical_keycode == KEY_R and is_standalone():
		get_tree().reload_current_scene()


func is_standalone() -> bool:
	return is_inside_tree() and get_tree().current_scene == self and not StoryUtil.story_active()


func _on_stalker_state(_old: String, new_state: String) -> void:
	if new_state == HorrorStalker.CHASE and state == "play":
		scare.play_cue("static_burst", -8.0)


func _on_hide_changed(spot: HidingSpot) -> void:
	hud.set_peek(spot.kind if spot != null else "")
	if spot != null and alarm and state == "play":
		hud.toast(T_ALARM_HIDE, 3.0)


## The staged catch opens the spot: the peek overlay (slats, the dark band) goes.
func _on_catch_beat(beat: String) -> void:
	if beat == "reveal":
		hud.set_peek("")


func _on_gasp(reason: String) -> void:
	if state == "play" and reason == "empty":
		hud.toast("Hết hơi!", 1.5)


## A noise at p (the phone ringing): the stalkers within r hear it (one re-route per physics frame).
func noise_at(p: Vector3, r: float) -> void:
	if state != "play":
		return
	for s: HorrorStalker in stalkers:
		if _flat_dist(s.global_position, p) <= r:
			_noise_queue.append({"s": s, "pos": p, "rush": false})


## The fake-out cat knocked a bin over: the stalkers within its noise radius hear it.
func _on_fake_noise(p: Vector3) -> void:
	if state != "play":
		return
	for s: HorrorStalker in stalkers:
		if _flat_dist(s.global_position, p) <= HorrorFakeouts.CAT_NOISE_R:
			_noise_queue.append({"s": s, "pos": p, "rush": false})


# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if wc != null and state == "play":
		wc.watch()
		wc.tick(delta)
	if alarm and _rush_t >= 0.0 and state == "play":
		_rush_t -= delta
		if _rush_t < 0.0:
			_rush_t = RUSH_REPATH_S
			if not kit.is_hidden():   # they converge on the player, not on a spot they did not see
				_queue_rush()
	if not _noise_queue.is_empty():
		var q: Dictionary = _noise_queue.pop_front()
		var s: HorrorStalker = q["s"]
		if is_instance_valid(s) and state == "play":
			if bool(q["rush"]):
				if not kit.is_hidden():   # queued before the player hid: never sends them to the spot
					s.rush(kit.player_position())
			else:
				s.hear_at(q["pos"])
	if state == "play" and doors_unlocked and player != null and not kit.is_hidden():
		var p: Vector3 = player.global_position
		if p.z > NightBuildingMap.EXIT_Z and absf(p.x) < 8.0:
			_escape()


func _process(delta: float) -> void:
	if not _built or state == "build":
		return
	if _retry_t > 0.0:
		_retry_t -= delta
		if _retry_t <= 0.0:
			retry_from_checkpoint()
	if _card_t > 0.0:
		_card_t -= delta
		if _card_t <= 0.0 and state == "caught":
			hud.show_caught(true)
	if alarm and siren != null and not siren.playing:
		_try_siren()
	_anim_t += delta
	for k: int in fuse_items.size():
		if fuse_items[k].visible:
			fuse_items[k].rotation.y = _anim_t * 1.5
	_hud_t += delta
	if _hud_t >= HUD_DT:
		_hud_t = 0.0
		hud.set_battery(flashlight.battery, flashlight.on)
		hud.set_prompt(kit.prompt if state == "play" else "")
		hud.set_breath(kit.breath_frac(), kit.is_hidden() and state == "play", kit.breath_held)


func _refresh_hud() -> void:
	if hud == null:
		return
	hud.set_fuses(fuses_placed, FUSES_NEEDED)
	hud.set_battery(flashlight.battery, flashlight.on)
	if doors_unlocked:
		hud.set_objective("Cửa sảnh đã mở. Chạy ra ngoài!")
	elif fuses_carried > 0:
		hud.set_objective("Mang cầu chì về hộp điện ở phòng máy phát (đang cầm %d)." % fuses_carried)
	else:
		hud.set_objective("Tìm cầu chì trong các phòng học (%d/3 đã lắp)." % fuses_placed)
