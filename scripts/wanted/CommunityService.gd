# File: res://scripts/wanted/CommunityService.gd
# "Lao động công ích" (spec W-D8, section 5): after the busted cutscene the player, in an orange vest, carries 8 rubbish bags
# one at a time to a bin within 120 s, on a fixed verge of Nguyễn Xiển (or the campus parking when caught on campus), watched
# by a supervising officer who says meme lines (fictional, no real names). WantedDirector.state == "service" meanwhile, so
# FreeRoam locks the weapons and the bike. Running out of time restarts the chore with BAG_STEP fewer bags (never fewer than
# MIN_BAGS: no softlock). Finishing emits `completed` (WantedDirector clears the level, FreeRoam puts the player beside his
# bike). There is no input handler: hold-Esc skips only the cutscene, never the chore. Bags, bin and vest are code meshes.
# On the street the bags lie along the verge (RING_MIN..RING_MAX along the road, 0..VERGE_BAND m further from it), never on
# the carriageway; every bag, the bin and the supervisor stand on a free spot (FreeRoam.find_free_spot: dry floor, no wall),
# a bag with no free spot near its point is tried elsewhere and finally put next to the chore centre.
class_name CommunityService
extends Node3D

signal completed
signal restarted(bags: int)
signal delivered_bag(count: int)

const TIME_S: float = 120.0
const BAGS: int = 8
const MIN_BAGS: int = 2
const BAG_STEP: int = 2
const PICK_R: float = 1.3
const BIN_R: float = 1.7
const RING_MIN: float = 4.0
const RING_MAX: float = 10.0
const LINE_EVERY: float = 9.0
const STREET_NEAR := Vector2(2058.0, -71.0)   # mid Nguyễn Xiển (corridor); the chore verge is beside the road there
const STREET_ROAD: String = "Nguyễn Xiển"
const VERGE_M: float = 2.5
const VERGE_BAND: float = 2.5
const BAG_TRIES: int = 8
const VEST := Color("#FF7A1A")
const STRIPE := Color("#D9DEE3")
const LINES: Array[String] = [
	"Nhặt cho sạch nha em, rác cũng có cảm xúc đó!",
	"Lao động là vinh quang, chạy lung tung là... lao động tiếp!",
	"Bao này nhẹ hơn deadline nhiều, ráng lên!",
	"Xong tám bao là cho về, khỏi điểm danh lại.",
	"Áo cam hợp với em ghê, chụp hình đăng nhóm lớp nha?",
	"Thấy chưa, phá phách xong thì ai dọn?",
]

var player: ThirdPersonController
var roam: Node
var on_campus: bool = false
var center: Vector3 = Vector3.ZERO
var total: int = BAGS
var delivered: int = 0
var time_left: float = TIME_S
var restarts: int = 0
var carrying: Node3D = null
var bags: Array[Node3D] = []
var bin: Node3D
var supervisor: Officer
var vest: Node3D
var hud_layer: CanvasLayer
var hud_label: Label
var _line_t: float = 3.0
var _line_i: int = 0
var _sfx: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _verge_n: Vector3 = Vector3.ZERO     # street chore: unit vector away from the road (ZERO = ring around the centre)
var _along: Vector3 = Vector3.ZERO       # street chore: unit vector along the road


## The street chore spot: the Nguyễn Xiển point nearest STREET_NEAR, pushed VERGE_M past the road edge.
static func street_center(md: MapData) -> Vector3:
	return street_frame(md)["center"]


## {"center": Vector3, "normal": Vector3 (away from the road), "along": Vector3, "points": PackedVector2Array (the road
## centre line), "half_w": float} of the street chore.
static func street_frame(md: MapData) -> Dictionary:
	var best_pts := PackedVector2Array()
	var best_d: float = INF
	var best_p: Vector2 = STREET_NEAR
	var best_n := Vector2(1.0, 0.0)
	var best_w: float = 8.0
	if md:
		for r: Dictionary in md.roads():
			if String(r.get("name", "")) != STREET_ROAD:
				continue
			var pts: PackedVector2Array = MapData.poly(r.get("points", []))
			for i: int in range(pts.size() - 1):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(STREET_NEAR, pts[i], pts[i + 1])
				var d: float = q.distance_to(STREET_NEAR)
				if d < best_d:
					best_d = d
					best_p = q
					var dir: Vector2 = (pts[i + 1] - pts[i]).normalized()
					best_n = Vector2(-dir.y, dir.x)
					best_w = float(r.get("width", 8.0))
					best_pts = pts
	var v: Vector2 = best_p + best_n * (best_w * 0.5 + VERGE_M)
	return {"center": Vector3(v.x, 0.0, v.y), "normal": Vector3(best_n.x, 0.0, best_n.y),
		"along": Vector3(best_n.y, 0.0, -best_n.x), "points": best_pts, "half_w": best_w * 0.5}


static func campus_center(md: MapData) -> Vector3:
	var lm: Variant = md.landmark("campus_parking_center") if md else null
	if lm is Array and (lm as Array).size() >= 2:
		return Vector3(float(lm[0]), 0.0, float(lm[1]))
	return FPTUCampusBuilder.real_plot_transform() * FPTUCampusBuilder.parking_center_local()


## Start the chore. at: explicit centre (tests) or null = street / campus spot from md. roam_node: FreeRoam (free spots).
func start(p: ThirdPersonController, roam_node: Node, md: MapData, campus: bool, at: Variant = null) -> void:
	player = p
	roam = roam_node
	on_campus = campus
	var c: Vector3
	if at is Vector3:
		c = at
	elif campus:
		c = campus_center(md)
	else:
		var fr: Dictionary = street_frame(md)
		c = fr["center"]
		_verge_n = fr["normal"]
		_along = fr["along"]
	center = _spot(c, 8)
	player.teleport(center, 0.0)
	_attach_vest()
	bin = make_bin()
	bin.position = _spot(center + Vector3(1.6, 0.0, 0.0), 3)
	add_child(bin)
	supervisor = Officer.new()
	supervisor.setup("guard" if campus else "police", null, player, 777)
	supervisor.position = _spot(center + Vector3(-2.2, 0.0, 1.6), 3) + Vector3(0.0, 0.05, 0.0)
	add_child(supervisor)
	supervisor.supervise()
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = WeaponAudio.bus()
	add_child(_sfx)
	_build_hud()
	_place_round(total)
	supervisor.say("Lao động công ích! Nhặt %d bao rác bỏ vô thùng nha em." % total)


func _spot(q: Vector3, r: int) -> Vector3:
	var s: Variant = _free(q, r)
	return s if s is Vector3 else q


## A free spot within r m of q (FreeRoam.find_free_spot), q itself without FreeRoam (tests), null when none.
func _free(q: Vector3, r: int) -> Variant:
	if roam and roam.has_method("find_free_spot"):
		return roam.call("find_free_spot", q, q.y, r)
	return q


## Candidate bag point i (try k): along the verge on the street, else on the 4-10 m ring.
func _bag_point(i: int, n: int, k: int) -> Vector3:
	if _verge_n != Vector3.ZERO:
		var side: float = 1.0 if (i + k) % 2 == 0 else -1.0
		return center + _along * side * _rng.randf_range(RING_MIN, RING_MAX) + _verge_n * _rng.randf_range(0.0, VERGE_BAND)
	var a: float = TAU * float(i) / float(n) + _rng.randf_range(-0.3, 0.3) + 0.7 * float(k)
	var r: float = _rng.randf_range(RING_MIN, RING_MAX)
	return center + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _place_round(n: int) -> void:
	for b: Node3D in bags:
		b.queue_free()
	bags.clear()
	_rng.seed = 4242 + restarts
	for i: int in n:
		var at: Variant = null
		for k: int in BAG_TRIES:
			var q: Vector3 = _bag_point(i, n, k)
			var f: Variant = _free(q, 1)
			if f is Vector3 and (f as Vector3).distance_to(center) >= RING_MIN - 1.0:
				at = f
				break
		if at == null:
			at = _spot(center + _along * 1.2 if _along != Vector3.ZERO else center + Vector3(1.2, 0.0, 0.0), 3)
		var bag: Node3D = make_bag()
		bag.name = "Bag%d" % i
		bag.position = at
		add_child(bag)
		bags.append(bag)
	_update_hud()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	time_left -= delta
	_line_t -= delta
	if _line_t <= 0.0 and supervisor:
		_line_t = LINE_EVERY
		supervisor.say(LINES[_line_i % LINES.size()])
		_line_i += 1
	var p: Vector3 = player.global_position
	if carrying == null:
		for b: Node3D in bags:
			if WeaponMath.flat(b.global_position, p) <= PICK_R:
				_pick(b)
				break
	elif WeaponMath.flat(bin.global_position, p) <= BIN_R:
		_drop()
	if delivered >= total:
		finish()
		return
	if time_left <= 0.0:
		_restart()
	_update_hud()


func _pick(b: Node3D) -> void:
	bags.erase(b)
	carrying = b
	b.get_parent().remove_child(b)
	player.model.add_child(b)
	b.position = Vector3(0.0, 0.95, -0.38)
	b.rotation = Vector3.ZERO
	CharacterBuilder.play(player.model, "carry", 999.0)


func _drop() -> void:
	carrying.queue_free()
	carrying = null
	delivered += 1
	CharacterBuilder.stop_clip(player.model)
	_sfx.stream = WeaponAudio.stream("bag_drop")
	_sfx.play()
	delivered_bag.emit(delivered)


func _restart() -> void:
	restarts += 1
	total = maxi(MIN_BAGS, total - BAG_STEP)
	delivered = 0
	if carrying:
		carrying.queue_free()
		carrying = null
		CharacterBuilder.stop_clip(player.model)
	time_left = TIME_S
	_place_round(total)
	if supervisor:
		supervisor.say("Hết giờ! Làm lại, lần này %d bao thôi." % total)
	restarted.emit(total)


## Done: vest, props and HUD go; `completed`; the node frees itself.
func finish() -> void:
	if vest:
		vest.queue_free()
		vest = null
	if carrying:
		carrying.queue_free()
		carrying = null
	if player and player.model:
		CharacterBuilder.stop_clip(player.model)
	if hud_layer:
		hud_layer.queue_free()
	set_physics_process(false)
	completed.emit()
	queue_free()


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud_label = Label.new()
	hud_label.name = "ServiceLabel"
	hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud_label.offset_left = -320.0
	hud_label.offset_right = 320.0
	hud_label.offset_top = 64.0
	hud_label.offset_bottom = 100.0
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", VEST)
	hud_label.add_theme_color_override("font_outline_color", Color("#1B0F33"))
	hud_label.add_theme_constant_override("outline_size", 8)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_label)


func _update_hud() -> void:
	if hud_label:
		var s: int = maxi(0, ceili(time_left))
		hud_label.text = "LAO ĐỘNG CÔNG ÍCH · Rác %d/%d · %d:%02d" % [delivered, total, s / 60, s % 60]


func _attach_vest() -> void:
	vest = make_vest()
	var torso: Node3D = CharacterBuilder.get_pivot(player.model, "torso")
	if torso:
		torso.add_child(vest)
	else:
		player.model.add_child(vest)
		vest.position = Vector3(0.0, 1.05, 0.0)


## Orange safety vest with two grey reflective stripes (on the torso pivot).
static func make_vest() -> Node3D:
	var root := Node3D.new()
	root.name = "ServiceVest"
	var m := StandardMaterial3D.new()
	m.albedo_color = VEST
	m.emission_enabled = true
	m.emission = VEST
	m.emission_energy_multiplier = 0.25
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.21
	cyl.height = 0.42
	var body := MeshInstance3D.new()
	body.name = "Vest"
	body.mesh = cyl
	body.material_override = m
	body.position = Vector3(0.0, 0.24, 0.0)
	body.scale = Vector3(1.05, 1.0, 0.72)
	root.add_child(body)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = STRIPE
	sm.metallic = 0.6
	sm.roughness = 0.3
	for k: int in 2:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.214
		ring.bottom_radius = 0.214
		ring.height = 0.04
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.material_override = sm
		mi.position = Vector3(0.0, 0.14 + 0.16 * float(k), 0.0)
		mi.scale = Vector3(1.05, 1.0, 0.72)
		root.add_child(mi)
	return root


## A black rubbish bag with a tied neck.
static func make_bag() -> Node3D:
	var root := Node3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.4
	var body := MeshInstance3D.new()
	body.mesh = sm
	body.material_override = WeaponProps._mat(Color("#16171B"), 0.0, 0.35)
	body.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(body)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.06
	cm.height = 0.1
	neck.mesh = cm
	neck.material_override = body.material_override
	neck.position = Vector3(0.0, 0.43, 0.0)
	root.add_child(neck)
	return root


## A green wheelie bin with a darker lid.
static func make_bin() -> Node3D:
	var root := Node3D.new()
	root.name = "Bin"
	WeaponProps._box(root, Vector3(0.6, 0.9, 0.6), Vector3(0.0, 0.45, 0.0), Color("#2E7D4F"))
	WeaponProps._box(root, Vector3(0.66, 0.06, 0.66), Vector3(0.0, 0.93, 0.0), Color("#1F5A38"))
	return root
