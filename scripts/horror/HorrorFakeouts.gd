# File: res://scripts/horror/HorrorFakeouts.gd
# Fake-out scares of the Night Building (spec H-D6): comic release between the real scares. 1-2 per run at seeded spots,
# each fires once, within the ScareDirector's fake-out budget (try_fake_out: at most FAKE_MAX, FAKE_GAP_S apart):
#   coat  a pale coat with a hood on a hook in a classroom's back corner, shaped like a standing clone. When the flashlight
#         catches it (lit, within COAT_R, inside the beam, a clear line): a short sting, then the line "... cái áo khoác."
#   cat   a small code-built black cat by a corridor bin. When the player comes within CAT_R: the bin falls (bin_crash), a
#         meow, the cat runs off down the corridor; `noise(pos)` is emitted (the level makes the hunters within
#         CAT_NOISE_R hear it).
# Checks run at 10 Hz. No collision, no light node (the cat's eyes are a faint emissive glint). Plain HUD text.
class_name HorrorFakeouts
extends Node3D

signal noise(pos: Vector3)
signal fired(kind: String)

const COAT_R: float = 10.0
const COAT_BEAM_DEG: float = 20.0
const CAT_R: float = 5.0
const CAT_NOISE_R: float = 18.0
const CAT_RUN_SPEED: float = 5.5
const CAT_RUN_S: float = 1.8
const CHECK_S: float = 0.1
const LINE_DELAY: float = 1.0
const COAT_LINE: String = "... cái áo khoác."
## Cat spots on the corridor's outer walls, clear of doors and locker banks: [x, z, along-axis].
const CAT_SPOTS: Array = [[-19.5, -17.55, "x"], [6.0, -17.55, "x"], [19.5, -17.55, "x"], [-6.0, 17.55, "x"], [19.5, 17.55, "x"],
	[-32.55, -8.0, "z"], [-32.55, 8.0, "z"], [32.55, -8.0, "z"], [32.55, 8.0, "z"]]
const CLASSROOMS: Array[String] = ["C1", "C2", "C3", "C4", "C5", "C6"]

## [{kind, pos (Vector3), node, fired}]
var items: Array[Dictionary] = []
var scare: ScareDirector = null
var flashlight: HorrorFlashlight = null
var player: Node3D = null
var hud: HorrorHUD = null
var enabled: bool = true
var fired_count: int = 0
var rng := RandomNumberGenerator.new()
var _check_t: float = 0.0
var _line_t: float = -1.0
var _cat_run: Dictionary = {}   # {node, dir, t}


func _init() -> void:
	name = "Fakeouts"


## Places 1-2 fake-outs from the level seed (own RNG, the level's draws stay as they were).
func setup(seed_val: int, sd: ScareDirector, fl: HorrorFlashlight, p: Node3D, h: HorrorHUD) -> void:
	scare = sd
	flashlight = fl
	player = p
	hud = h
	rng.seed = seed_val * 7919 + 97
	var count: int = 1 + rng.randi_range(0, 1)
	var pickk: Array[String] = ["coat", "cat"]
	if count == 1:
		pickk = [pickk[rng.randi_range(0, 1)]]
	for k: String in pickk:
		if k == "coat":
			_add_coat(CLASSROOMS[rng.randi_range(0, CLASSROOMS.size() - 1)])
		else:
			_add_cat(CAT_SPOTS[rng.randi_range(0, CAT_SPOTS.size() - 1)])


func kinds() -> Array[String]:
	var out: Array[String] = []
	for it: Dictionary in items:
		out.append(String(it["kind"]))
	return out


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------
static func _m(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _bx(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _sp(parent: Node3D, r: float, pos: Vector3, mat: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


## A pale hooded coat on a wall hook, at about a standing clone's height (faces local -Z, its back on the wall).
static func build_coat() -> Node3D:
	var n := Node3D.new()
	n.name = "FakeCoat"
	var cloth: StandardMaterial3D = _m(Color("#DCE2E6"))
	var dark: StandardMaterial3D = _m(Color("#3A3F46"), 0.6)
	_bx(n, Vector3(0.06, 0.04, 0.08), Vector3(0.0, 1.86, 0.04), dark)                       # hook
	_sp(n, 0.14, Vector3(0.0, 1.7, -0.02), cloth, Vector3(1.0, 1.15, 0.9))                 # hood (a head)
	_sp(n, 0.1, Vector3(0.0, 1.66, -0.1), _m(Color("#14171B"), 1.0), Vector3(1.0, 1.2, 0.5))  # the dark hood opening
	_bx(n, Vector3(0.52, 0.16, 0.2), Vector3(0.0, 1.5, 0.0), cloth)                         # shoulders on the hanger
	_bx(n, Vector3(0.46, 0.68, 0.17), Vector3(0.0, 1.1, 0.0), cloth)                        # body
	_bx(n, Vector3(0.5, 0.12, 0.18), Vector3(0.0, 0.72, 0.0), cloth)                        # hem
	for sx: float in [-1.0, 1.0]:
		_bx(n, Vector3(0.11, 0.62, 0.12), Vector3(sx * 0.29, 1.15, 0.0), cloth, Vector3(0.0, 0.0, sx * 0.06))   # sleeves
	return n


## A small black cat sitting (faces local -Z): body, head, ears, tail and two faint eye glints.
static func build_cat() -> Node3D:
	var n := Node3D.new()
	n.name = "FakeCat"
	var fur: StandardMaterial3D = _m(Color("#17171A"))
	_sp(n, 0.12, Vector3(0.0, 0.13, 0.05), fur, Vector3(0.9, 1.0, 1.35))
	_sp(n, 0.075, Vector3(0.0, 0.26, -0.1), fur)
	for sx: float in [-1.0, 1.0]:
		_bx(n, Vector3(0.035, 0.05, 0.02), Vector3(sx * 0.04, 0.33, -0.1), fur, Vector3(0.0, 0.0, sx * 0.3))
		var eye := StandardMaterial3D.new()
		eye.albedo_color = Color("#C8F25A")
		eye.emission_enabled = true
		eye.emission = Color("#C8F25A")
		eye.emission_energy_multiplier = 0.8
		_sp(n, 0.012, Vector3(sx * 0.028, 0.27, -0.17), eye)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.1, 0.2)
	n.add_child(tail)
	_bx(tail, Vector3(0.03, 0.03, 0.26), Vector3(0.0, 0.06, 0.1), fur, Vector3(0.6, 0.0, 0.0))
	return n


static func build_bin() -> Node3D:
	var n := Node3D.new()
	n.name = "FakeBin"
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.19
	cm.height = 0.58
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _m(Color("#4E6B57"), 0.5)
	mi.position = Vector3(0.0, 0.29, 0.0)
	n.add_child(mi)
	return n


func _add_coat(room_id: String) -> void:
	var r: Dictionary = NightBuildingMap.room_by_id(room_id)
	var half_w: float = (float(r["x1"]) - float(r["x0"])) * 0.5
	var idx: int = int(room_id.substr(1))
	var cab_left: bool = idx % 2 == 1                  # the map's fuse cabinet: left in odd rooms
	var lx: float = (half_w - 0.75) * (1.0 if cab_left else -1.0)
	var pos: Vector3 = NightBuildingMap.room_pt(r, lx, 8.8)
	var coat: Node3D = build_coat()
	add_child(coat)
	coat.position = pos
	var toward: Vector3 = NightBuildingMap.room_pt(r, lx, 0.0) - pos   # faces the door side of the room
	coat.rotation.y = NightBuildingMap.yaw_to(toward)
	items.append({"kind": "coat", "pos": pos, "node": coat, "fired": false, "room": room_id})


func _add_cat(spot: Array) -> void:
	var pos := Vector3(float(spot[0]), 0.0, float(spot[1]))
	var root := Node3D.new()
	root.name = "CatSpot"
	add_child(root)
	root.position = pos
	var inward: Vector3 = Vector3(0.0, 0.0, -signf(pos.z)) if String(spot[2]) == "x" else Vector3(-signf(pos.x), 0.0, 0.0)
	var along: Vector3 = Vector3(1.0, 0.0, 0.0) if String(spot[2]) == "x" else Vector3(0.0, 0.0, 1.0)
	var bin: Node3D = build_bin()
	root.add_child(bin)
	var cat: Node3D = build_cat()
	root.add_child(cat)
	cat.position = inward * 0.35 + along * 0.38
	cat.rotation.y = NightBuildingMap.yaw_to(inward)
	items.append({"kind": "cat", "pos": pos, "node": root, "bin": bin, "cat": cat, "along": along, "fired": false})


# ---------------------------------------------------------------------------
# Triggers
# ---------------------------------------------------------------------------
## true when the flashlight beam catches the coat at `pos` now.
func coat_lit(pos: Vector3) -> bool:
	if flashlight == null or not flashlight.is_lit() or player == null:
		return false
	var cam: Camera3D = flashlight.aim as Camera3D if flashlight.aim is Camera3D else null
	if cam == null or not cam.is_inside_tree():
		return false
	var chest: Vector3 = pos + Vector3(0.0, 1.3, 0.0)
	var p: Vector3 = player.global_position
	if Vector2(chest.x - p.x, chest.z - p.z).length() > COAT_R:
		return false
	var to: Vector3 = chest - cam.global_position
	if (-cam.global_transform.basis.z).angle_to(to) > deg_to_rad(COAT_BEAM_DEG):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, chest, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Fires fake-out i if the budget allows (the level's checks, or tests). Returns true when it played.
func trigger(i: int) -> bool:
	if i < 0 or i >= items.size() or bool(items[i]["fired"]) or scare == null:
		return false
	var it: Dictionary = items[i]
	if not scare.try_fake_out(String(it["kind"])):
		return false
	it["fired"] = true
	fired_count += 1
	if String(it["kind"]) == "coat":
		scare.fake_sting(-10.0)
		_line_t = LINE_DELAY
	else:
		_cat_go(it)
	fired.emit(String(it["kind"]))
	return true


func _cat_go(it: Dictionary) -> void:
	var bin: Node3D = it["bin"]
	var cat: Node3D = it["cat"]
	var along: Vector3 = it["along"]
	var pos: Vector3 = it["pos"]
	scare.play_cue("bin_crash", -4.0)
	scare.play_cue("cat_meow", -6.0)
	if bin.is_inside_tree():
		var tw: Tween = bin.create_tween()
		tw.tween_property(bin, "rotation:z", 1.45, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		bin.rotation.z = 1.45
	# runs away from the player along the corridor
	var away: Vector3 = along
	if player != null and (player.global_position - pos).dot(along) > 0.0:
		away = -along
	cat.rotation.y = NightBuildingMap.yaw_to(away)
	_cat_run = {"node": cat, "dir": away, "t": CAT_RUN_S}
	noise.emit(pos)


func _physics_process(delta: float) -> void:
	if not _cat_run.is_empty():
		var c: Node3D = _cat_run["node"]
		_cat_run["t"] = float(_cat_run["t"]) - delta
		if is_instance_valid(c):
			c.position += (_cat_run["dir"] as Vector3) * CAT_RUN_SPEED * delta
			if float(_cat_run["t"]) <= 0.0:
				c.visible = false
		if float(_cat_run["t"]) <= 0.0:
			_cat_run = {}
	if _line_t > 0.0:
		_line_t -= delta
		if _line_t <= 0.0 and hud != null:
			hud.toast(COAT_LINE, 2.5)
	if not enabled or player == null:
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_S
	for i: int in items.size():
		var it: Dictionary = items[i]
		if bool(it["fired"]):
			continue
		var pos: Vector3 = it["pos"]
		if String(it["kind"]) == "coat":
			if coat_lit(pos):
				trigger(i)
		elif Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length() <= CAT_R:
			trigger(i)
