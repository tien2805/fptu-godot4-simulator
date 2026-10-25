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
#   signals
#     escaped(caught_count: int)     walked out through the open doors (E5 is earned when caught_count == 0)
#     caught                         a stalker caught the player (the catch scare plays)
#     fuse_placed(n: int)            n fuses in the box (1..3)
#     checkpoint                     a checkpoint was saved (after every fuse placed)
#   retry_from_checkpoint()      player back at the last checkpoint (start, or the fuse box): carried fuses go back to their
#                                spots, placed ones stay, battery at least 25 %, each stalker on its waypoint farthest from
#                                the checkpoint, patrolling.
#   state: "play" | "caught" | "escaped"; fuses_placed, fuses_carried, caught_count, doors_unlocked, player, kit, stalkers,
#   scare, flashlight, hud, graph, fuse_candidates (6 {room, pos, reach, node}), active_fuses (3 candidate indices),
#   fuse_state ("spot" | "carried" | "placed" per active fuse), fuse_box {pos, yaw, slots}.
#   Keys: [F] flashlight, [E] hide / leave / pick up / place fuses (HorrorKit + interact hook), WASD, Shift, Ctrl.
#   The scene must stay at the world origin (stalkers walk the level-local waypoint graph in global coordinates).
# HUD: "Cầu chì: n/3", battery, objective, prompts "[E] Trốn", "[E] Ra", "[E] Nhặt cầu chì", "[E] Lắp cầu chì", "[E] Nhặt
# pin", hint "[F] Đèn pin"; plain text without emoji or decorative symbols.
class_name NightBuilding
extends Node3D

signal escaped(caught_count: int)
signal caught
signal fuse_placed(n: int)
signal checkpoint

const FUSES_NEEDED: int = 3
const BATTERIES: int = 3
const BATTERY_FRAC: float = 0.6
const RETRY_DELAY: float = 2.5
const RETRY_MIN_BATTERY: float = 0.25
const MAX_STALKERS: int = 4
const PLAYER_DEFAULT: Dictionary = {"preset": "player", "rigged": true, "seed": 2805, "name": "PlayerModel"}
const HUD_DT: float = 0.1

var opts: Dictionary = {}
var seed_val: int = 0
var state: String = "build"
var fuses_placed: int = 0
var fuses_carried: int = 0
var caught_count: int = 0
var doors_unlocked: bool = false
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


func _ready() -> void:
	if not _built:
		build.call_deferred()


func setup(o: Dictionary) -> void:
	opts = o.duplicate()
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
	caught_count = 0
	doors_unlocked = false
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
	scare = ScareDirector.new()
	scare.reduce_scares = bool(opts["reduce_scares"]) if opts.has("reduce_scares") else StoryUtil.reduce_scares()
	scare.budget = clampi(int(opts.get("jump_budget", ScareDirector.MAX_JUMP)), 1, ScareDirector.MAX_JUMP)
	add_child(scare)
	scare.set_seed(seed_val)
	scare.register_light_groups(map["light_groups"])
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
	# stalkers and the jump-scare figure
	var n: int = clampi(int(opts.get("stalkers", MAX_STALKERS)), 0, MAX_STALKERS)
	var patrols: Array = map["patrols"]
	for i: int in n:
		var sk := HorrorStalker.new()
		sk.name = "Stalker%d" % i
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
	checkpoint_data = {"pos": st["pos"], "yaw": float(st["yaw"]), "battery": 1.0}
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
	checkpoint_data = {"pos": fuse_box["pos"], "yaw": float(fuse_box["yaw"]), "battery": flashlight.battery}
	checkpoint.emit()


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
	# the generator roars: every stalker heads for the generator room, the corridor lights stutter
	for s: HorrorStalker in stalkers:
		s.hear_at(fuse_box["pos"])
	scare.flicker_near(player.global_position)
	scare.try_jump_scare()
	hud.toast("Có điện rồi! Cửa sảnh đã mở. Chạy ra ngoài!", 4.0)


# ---------------------------------------------------------------------------
# Catch, retry, escape
# ---------------------------------------------------------------------------
func _on_caught(_s: HorrorStalker) -> void:
	if state != "play":
		return
	state = "caught"
	caught_count += 1
	kit.input_enabled = false
	player.controls_enabled = false
	scare.play_catch_scare()
	hud.show_caught(true)
	caught.emit()
	if auto_retry:
		_retry_t = RETRY_DELAY


func retry_from_checkpoint() -> void:
	if not _built:
		return
	_retry_t = -1.0
	if kit.is_hidden():
		kit.leave_hiding()
	for s: Variant in map["spots"]:
		(s as HidingSpot).reset_spot()
	for k: int in fuse_state.size():
		if fuse_state[k] == "carried":
			fuse_state[k] = "spot"
			fuse_items[k].visible = true
	fuses_carried = 0
	flashlight.set_on(false)
	flashlight.battery = maxf(float(checkpoint_data.get("battery", 1.0)), RETRY_MIN_BATTERY)
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


func _escape() -> void:
	state = "escaped"
	kit.set_frozen(true)
	kit.input_enabled = false
	player.controls_enabled = false
	scare.stop_all()
	hud.show_escaped(caught_count)
	if is_standalone():
		hud.set_objective("Nhấn R để chơi lại.")
	escaped.emit(caught_count)


## Standalone (the level is the current scene, no story running): [R] after the escape plays again.
func _unhandled_input(event: InputEvent) -> void:
	if state != "escaped" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_R and is_standalone():
		get_tree().reload_current_scene()


func is_standalone() -> bool:
	return is_inside_tree() and get_tree().current_scene == self and not StoryUtil.story_active()


func _on_stalker_state(_old: String, new_state: String) -> void:
	if new_state == HorrorStalker.CHASE and state == "play":
		scare.play_cue("static_burst", -8.0)


func _on_hide_changed(spot: HidingSpot) -> void:
	hud.set_peek(spot.kind if spot != null else "")


# ---------------------------------------------------------------------------
func _physics_process(_delta: float) -> void:
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
	_anim_t += delta
	for k: int in fuse_items.size():
		if fuse_items[k].visible:
			fuse_items[k].rotation.y = _anim_t * 1.5
	_hud_t += delta
	if _hud_t >= HUD_DT:
		_hud_t = 0.0
		hud.set_battery(flashlight.battery, flashlight.on)
		hud.set_prompt(kit.prompt if state == "play" else "")


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
