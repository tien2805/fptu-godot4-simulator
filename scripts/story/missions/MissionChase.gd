# File: res://scripts/story/missions/MissionChase.gd
# Day 1 foot chase (spec B-D5 beat 4; Wave 2 content pass, plan 2026-10-29-w2-early.md Task 5, master plan Q4b): Shipper Mũ
# Đỏ bolts from the handover spot along PATH (campus-plot local points, measured clear with rays at 0.5 and 1.2 m): through
# the back-wing passage into the courtyard (the evening crowd), a loop round the courtyard, back out to the parking lane,
# west along it, down the west lane to the west gate. Stay within leash_m() of him; farther than that for leash_grace()
# s = fail ("TOANG!", retry from the start). His speed rubber-bands with the distance (fast when the player is close, slow
# when far, a taunting stop when very far) and is capped so he reaches the tackle stretch no earlier than min_s().
# Set pieces along the path (OBSTACLES, path distances in m):
#   - parkour: benches and a railing ("vault") and barrier poles ("slide") across the way, with collision: [Space] within
#     vault_m() in front of one vaults it (VAULT_S arc), [Ctrl] in front of a barrier slides under it (SLIDE_S); going
#     round costs time. The courier hops / slides them too.
#   - knock-overs: he shouts (the telegraph, KNOCK_WARN_S before), then knocks over the trash cans and the fruit cart
#     behind him: each falls across the path with a crash, a preview cut, debris, and leaves a slow zone (spilled rubbish /
#     rolling fruit: the player's speed capped to slow_cap() within SLOW_R) that the toppled thing can be vaulted over.
#   - the crowd parts: students along the courtyard loop step aside as he comes (a line, a flinch).
#   - the canteen shortcut: a canteen stall on the chord of the courtyard loop, marked yellow ("LỐI TẮT"): cutting through
#     skips about 40 m of his loop.
#   - the banana peel (SLIP_U, slide whistle, "Ét o ét!").
# Finish: on the last stretch (s >= TACKLE_FROM_U, or once he is cornered at the gate) the prompt "[Space] VỒ!" shows within
# tackle_m(): a slow-motion flying tackle (Impact finisher + the director's slow-motion orbit, the replay mark), then the
# short replay seg_d1_chase, then done. Every tuned number goes through Difficulty.pick(normal, easy).
class_name MissionChase
extends StoryMission

const PATH: Array[Vector3] = [Vector3(122.0, 0.0, 103.5), Vector3(121.5, 0.0, 95.0), Vector3(121.5, 0.0, 77.0),
	Vector3(135.0, 0.0, 66.0), Vector3(128.0, 0.0, 52.0), Vector3(140.0, 0.0, 40.0), Vector3(146.0, 0.0, 60.0),
	Vector3(121.5, 0.0, 77.5), Vector3(121.5, 0.0, 95.0), Vector3(121.5, 0.0, 103.5), Vector3(178.0, 0.0, 103.5),
	Vector3(183.0, 0.0, 98.0), Vector3(183.0, 0.0, 8.0), Vector3(181.0, 0.0, 3.0)]
## Player start: on the lane, 10 m east of the handover (where the stake-out leaves the player watching).
const START := Vector3(112.0, 0.0, 103.5)
## [kind, path distance m]: vault / slide obstacles and the two knock-overs.
const OBSTACLES: Array = [["vault", 18.0], ["trash", 38.0], ["slide", 138.0], ["vault", 190.0], ["fruit", 226.0], ["slide", 256.0]]
## The courtyard crowd: path distances of the students.
const CROWD_D: Array[float] = [48.0, 52.0, 66.0, 70.0, 84.0, 88.0, 106.0, 112.0]
const SHORTCUT := [Vector3(135.0, 0.0, 66.0), Vector3(146.0, 0.0, 60.0)]   # the loop's chord (campus plot)
const WARN_M: float = 19.0
const TAUNT_M: float = 21.0
const SLIP_U: float = 0.55
const SLIP_S: float = 2.2
const VAULT_S: float = 0.45
const SLIDE_S: float = 0.55
const SLIDE_M: float = 2.2
const OBST_W: float = 3.2
const KNOCK_WARN_S: float = 0.7
const SLOW_R: float = 2.6
const PART_M: float = 6.0
const TACKLE_FROM_U: float = 0.75
const TACKLE_S: float = 0.5
const END_EXTRA_S: float = 12.0
const LEASH_START_S: float = 6.0
const T_LOST: String = "Mất dấu shipper rồi!"
const T_SLIP: String = "Ét o ét!"
const T_TAUNT: String = "Lêu lêu, đuổi không kịp!"
const T_WARN: String = "Sắp mất dấu! Chạy nhanh lên [Shift]"
const T_VAULT: String = "[Space] Phóng qua"
const T_SLIDE: String = "[Ctrl] Trượt qua"
const T_TACKLE: String = "[Space] VỒ!"
const T_SHORTCUT: String = "Lối tắt qua căn tin!"
const T_KNOCK: String = "Tránh ra!!"
const PART_LINES: Array[String] = ["Ê ê!", "Gì vậy trời!", "Từ từ thôi!", "Ối!"]

var courier: Node3D
var banana: Node3D
var rec: CineReplayRecorder
var pts: PackedVector3Array = PackedVector3Array()
var cum: PackedFloat32Array = PackedFloat32Array()
var length_m: float = 0.0
var s: float = 0.0
var slipped: bool = false
var slip_t: float = 0.0
var far_t: float = 0.0
var taunts: int = 0
var ended: bool = false
var bubble: Label3D
var _taunt_cd: float = 0.0
## Set pieces: per obstacle {kind, d, node (root), body (StaticBody3D or null), at (Vector3), fwd (path dir), state}.
var obstacles: Array[Dictionary] = []
var crowd: Array[Dictionary] = []
var slow_zones: Array[Vector3] = []
var canteen: Node3D
var vaults: int = 0
var slides: int = 0
var knocks: int = 0
var cuts: int = 0
var parted: int = 0
var shortcut_used: bool = false
var tackled: bool = false
var tackling: bool = false
var _tackle_t: float = 0.0
var _tackle_from: Vector3 = Vector3.ZERO
var _tackle_cam: Vector2 = Vector2.ZERO
var _move: Dictionary = {}                  # the running vault / slide: {kind, from, to, t, secs, h}
var _hop_t: float = -1.0
var _prev_filter: Callable
var _filter_set: bool = false
var _in_slow: bool = false


## Difficulty-tuned numbers (Thường, Dễ).
## He reaches the tackle stretch no earlier than this (Thường: he runs flat out, the run is about 45-55 s; Dễ: paced).
static func min_s() -> float:
	return float(Difficulty.pick(42.0, 60.0))


static func leash_m() -> float:
	return float(Difficulty.pick(12.0, 26.0))


static func leash_grace() -> float:
	return float(Difficulty.pick(1.2, 3.2))


static func speed_close() -> float:
	return float(Difficulty.pick(6.0, 4.8))


static func speed_mid() -> float:
	return float(Difficulty.pick(5.2, 4.0))


static func speed_far() -> float:
	return float(Difficulty.pick(4.4, 3.4))


static func vault_m() -> float:
	return float(Difficulty.pick(1.6, 2.1))


static func slow_cap() -> float:
	return float(Difficulty.pick(2.4, 3.6))


static func tackle_m() -> float:
	return float(Difficulty.pick(2.6, 3.4))


func _start() -> void:
	pts.clear()
	cum.clear()
	length_m = 0.0
	for i: int in PATH.size():
		var p: Vector3 = campus(PATH[i])
		p.y = ground_y(p)
		pts.append(p)
		if i > 0:
			length_m += flat(pts[i - 1], p)
		cum.append(length_m)
	courier = spawn_body("courier_do", pts[0], 0.0)
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 56
	bubble.pixel_size = 0.008
	bubble.outline_size = 10
	bubble.position = Vector3(0.0, 2.3, 0.0)
	bubble.visible = false
	courier.add_child(bubble)
	banana = CineFX.build_prop("banana")
	add_child(banana)
	banana.global_position = point_at(SLIP_U * length_m)
	_build_obstacles()
	_build_crowd()
	_build_canteen()
	rec = StoryStage.make_recorder(self, [player, courier])
	Impact.prepare(self)
	StoryAudio.warm(["bin_crash"])
	if player:
		_prev_filter = player.jump_filter
		player.jump_filter = _jump_filter
		_filter_set = true
	_reset()


func _reset() -> void:
	s = 0.0
	slipped = false
	slip_t = 0.0
	far_t = 0.0
	ended = false
	tackled = false
	tackling = false
	shortcut_used = false
	if not _move.is_empty() and _move.get("body") is PhysicsBody3D and is_instance_valid(_move["body"]) and player:
		player.remove_collision_exception_with(_move["body"])
	_move = {}
	_hop_t = -1.0
	_taunt_cd = 0.0
	banana.visible = true
	bubble.visible = false
	slow_zones.clear()
	for o: Dictionary in obstacles:
		_stand_obstacle(o)
	for c: Dictionary in crowd:
		c["parted"] = false
		(c["node"] as Node3D).global_position = c["home"]
		(c["line"] as Label3D).visible = false
	if player:
		player.combat_speed_cap = INF
		player.controls_enabled = true
	_in_slow = false
	CharacterBuilder.stop_clip(courier)
	_place(0.0)
	var st: Vector3 = campus(START)
	teleport_player(free_spot(st), yaw_of(pts[0] - st))
	popup("Mũ Đỏ bỏ chạy! Đuổi theo!", 2.0, Color("#FFE66D"))


## Point at path distance d (clamped).
func point_at(d: float) -> Vector3:
	d = clampf(d, 0.0, length_m)
	for i: int in range(1, pts.size()):
		if d <= cum[i] or i == pts.size() - 1:
			var seg: float = maxf(cum[i] - cum[i - 1], 0.001)
			return pts[i - 1].lerp(pts[i], clampf((d - cum[i - 1]) / seg, 0.0, 1.0))
	return pts[pts.size() - 1]


func dir_at(d: float) -> Vector3:
	var a: Vector3 = point_at(d - 0.5)
	var b: Vector3 = point_at(d + 0.5)
	var v := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


# ---------------------------------------------------------------------------
# SET PIECES
# ---------------------------------------------------------------------------
func _build_obstacles() -> void:
	for spec: Array in OBSTACLES:
		var kind: String = String(spec[0])
		var d: float = float(spec[1])
		var at: Vector3 = point_at(d)
		at.y = ground_y(at)
		var fwd: Vector3 = dir_at(d)
		var root := Node3D.new()
		root.name = "Obstacle_%s_%d" % [kind, int(d)]
		add_child(root)
		root.global_position = at
		root.rotation.y = yaw_of(fwd)
		var o: Dictionary = {"kind": kind, "d": d, "node": root, "at": at, "fwd": fwd, "state": "up", "warned": false}
		match kind:
			"vault":
				var bench: Node3D = CineFX.build_prop("bench")
				root.add_child(bench)
				bench.rotation.y = PI * 0.5
				o["body"] = _box_body(root, Vector3(OBST_W, 0.9, 0.6), 0.45)
			"slide":
				_barrier(root)
				o["body"] = _box_body(root, Vector3(OBST_W, 0.6, 0.25), 0.85)
			"trash":
				var cans: Array[Node3D] = []
				for k: int in 3:
					var can: Node3D = _trash_can()
					root.add_child(can)
					cans.append(can)
				o["parts"] = cans
				o["body"] = null
			"fruit":
				var cart: Node3D = _fruit_cart()
				root.add_child(cart)
				o["parts"] = [cart]
				o["body"] = null
		obstacles.append(o)


func _box_body(root: Node3D, size: Vector3, cy: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0.0, cy, 0.0)
	body.add_child(cs)
	root.add_child(body)
	return body


static func _mat(col: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


static func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## A red-and-white barrier pole on two posts (the bar at 0.85 m: slide under), a yellow "CẤM VÀO" tag.
func _barrier(root: Node3D) -> void:
	var post_m: StandardMaterial3D = _mat(Color("#636E72"))
	for sx: float in [-OBST_W * 0.5, OBST_W * 0.5]:
		_mesh_box(root, Vector3(0.12, 1.1, 0.12), Vector3(sx, 0.55, 0.0), post_m)
	for k: int in 6:
		_mesh_box(root, Vector3(OBST_W / 6.0, 0.12, 0.12), Vector3(-OBST_W * 0.5 + OBST_W / 12.0 + OBST_W / 6.0 * float(k), 0.95, 0.0),
			_mat(Color("#E74C3C") if k % 2 == 0 else Color("#F4F1EA"), 0.3))
	var tag := Label3D.new()
	tag.text = "CẤM VÀO"
	tag.font_size = 30
	tag.outline_size = 8
	tag.modulate = Color("#FFE66D")
	tag.position = Vector3(0.0, 1.25, 0.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(tag)


func _trash_can() -> Node3D:
	var can := Node3D.new()
	can.name = "TrashCan"
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.24
	cm.height = 0.85
	mi.mesh = cm
	mi.material_override = _mat(Color("#2E8B57"))
	mi.position = Vector3(0.0, 0.43, 0.0)
	can.add_child(mi)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.3
	lm.bottom_radius = 0.3
	lm.height = 0.06
	lid.mesh = lm
	lid.material_override = _mat(Color("#1F6E43"))
	lid.position = Vector3(0.0, 0.88, 0.0)
	can.add_child(lid)
	return can


## A street fruit cart: a wooden bed on two wheels, a striped awning, a pile of fruit (spheres).
func _fruit_cart() -> Node3D:
	var cart := Node3D.new()
	cart.name = "FruitCart"
	_mesh_box(cart, Vector3(2.2, 0.12, 1.0), Vector3(0.0, 0.8, 0.0), _mat(Color("#8B5A2B")))
	_mesh_box(cart, Vector3(2.2, 0.3, 0.06), Vector3(0.0, 0.95, 0.5), _mat(Color("#A0522D")))
	_mesh_box(cart, Vector3(2.2, 0.3, 0.06), Vector3(0.0, 0.95, -0.5), _mat(Color("#A0522D")))
	for sx: float in [-0.75, 0.75]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.32
		cm.bottom_radius = 0.32
		cm.height = 0.08
		w.mesh = cm
		w.material_override = _mat(Color("#2D3436"))
		w.rotation.x = PI * 0.5
		w.position = Vector3(sx, 0.32, 0.55)
		cart.add_child(w)
	for k: int in 4:
		_mesh_box(cart, Vector3(0.55, 0.04, 1.2), Vector3(-0.825 + 0.55 * float(k), 1.9, 0.0), _mat(Color("#FF6B6B") if k % 2 == 0 else Color("#FFF3E0")))
	_mesh_box(cart, Vector3(0.06, 1.1, 0.06), Vector3(-1.05, 1.35, 0.0), _mat(Color("#636E72")))
	_mesh_box(cart, Vector3(0.06, 1.1, 0.06), Vector3(1.05, 1.35, 0.0), _mat(Color("#636E72")))
	var fruit_cols: Array[Color] = [Color("#FFA502"), Color("#2ED573"), Color("#FF4757"), Color("#ECCC68")]
	var fruits := Node3D.new()
	fruits.name = "Fruit"
	cart.add_child(fruits)
	for k: int in 14:
		var f := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		sm.radial_segments = 8
		sm.rings = 4
		f.mesh = sm
		f.material_override = _mat(fruit_cols[k % fruit_cols.size()])
		f.position = Vector3(-0.85 + 0.13 * float(k), 0.95 + 0.1 * float(k % 2), -0.3 + 0.15 * float(k % 4))
		fruits.add_child(f)
	return cart


## Puts an obstacle back up (retry): knock-overs stand at the path side again, vault / slide stay across the path.
func _stand_obstacle(o: Dictionary) -> void:
	o["state"] = "up"
	o["warned"] = false
	var root: Node3D = o["node"]
	if o["kind"] == "trash":
		var cans: Array = o["parts"]
		for k: int in cans.size():
			var can: Node3D = cans[k]
			can.position = Vector3(2.4 + 0.65 * float(k), 0.0, 0.0)   # beside the path, ready to be knocked
			can.rotation = Vector3.ZERO
	elif o["kind"] == "fruit":
		var cart: Node3D = (o["parts"] as Array)[0]
		cart.position = Vector3(-2.6, 0.0, 0.0)
		cart.rotation = Vector3.ZERO
		var fr: Node3D = cart.get_node("Fruit")
		for k: int in fr.get_child_count():
			(fr.get_child(k) as Node3D).position = Vector3(-0.85 + 0.13 * float(k), 0.95 + 0.1 * float(k % 2), -0.3 + 0.15 * float(k % 4))
	if o.has("toppled_body") and is_instance_valid(o["toppled_body"]):
		(o["toppled_body"] as Node).queue_free()
	o.erase("toppled_body")
	root.visible = true


## He knocks it over behind him: it falls across the path (a crash, debris, a preview cut), a slow zone, a vaultable body.
func knock_over(o: Dictionary) -> void:
	if o["state"] != "up":
		return
	o["state"] = "down"
	knocks += 1
	var root: Node3D = o["node"]
	if o["kind"] == "trash":
		var cans: Array = o["parts"]
		for k: int in cans.size():
			var can: Node3D = cans[k]
			var to := Vector3(-1.0 + 1.0 * float(k), 0.3, 0.3 * float(k % 2))
			if is_inside_tree():
				var tw: Tween = create_tween().set_parallel(true)
				tw.tween_property(can, "position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(can, "rotation", Vector3(PI * 0.5, 0.4 * float(k), 0.0), 0.35)
			else:
				can.position = to
				can.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		play_cue("bin_crash", -2.0)
	else:
		var cart: Node3D = (o["parts"] as Array)[0]
		if is_inside_tree():
			var tw2: Tween = create_tween().set_parallel(true)
			tw2.tween_property(cart, "position", Vector3(0.0, 0.0, 0.2), 0.4).set_trans(Tween.TRANS_QUAD)
			tw2.tween_property(cart, "rotation", Vector3(0.0, 0.0, PI * 0.42), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			var fr: Node3D = cart.get_node("Fruit")
			for k: int in fr.get_child_count():
				var f: Node3D = fr.get_child(k)
				tw2.tween_property(f, "position", Vector3(-1.6 + 0.25 * float(k), 0.12, -1.2 + 0.4 * float(k % 6)), 0.6 + 0.04 * float(k))
		play_cue("crate_smash", -2.0)
	o["toppled_body"] = _box_body(root, Vector3(OBST_W, 0.6, 1.2), 0.3)
	slow_zones.append(o["at"])
	Impact.particles(self, "debris", (o["at"] as Vector3) + Vector3(0.0, 0.4, 0.0), Vector3.UP, 1.0)
	Impact.particles(self, "dust_ring", o["at"], Vector3.UP, 1.0)
	_preview(root)


func _preview(target: Node3D) -> void:
	cuts += 1
	var d: CameraDirector = CameraDirector.live()
	if d != null and target != null and target.is_inside_tree():
		d.preview_cut(target, 0.6)


func _build_crowd() -> void:
	var presets: Array[String] = ["student_m", "student_f", "casual"]
	for i: int in CROWD_D.size():
		var d: float = CROWD_D[i]
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var fwd: Vector3 = dir_at(d)
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var p: Vector3 = point_at(d) + right * side * 1.3
		p.y = ground_y(p)
		var body: Node3D = CharacterBuilder.build({"preset": presets[i % presets.size()], "seed": 4400 + i, "name": "Student%d" % i})
		add_child(body)
		body.global_position = p
		body.rotation.y = yaw_of(-right * side)
		var line := Label3D.new()
		line.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		line.font_size = 40
		line.pixel_size = 0.008
		line.outline_size = 8
		line.modulate = Color("#F4F1FF")
		line.text = PART_LINES[i % PART_LINES.size()]
		line.position = Vector3(0.0, 2.1, 0.0)
		line.visible = false
		body.add_child(line)
		crowd.append({"node": body, "d": d, "home": p, "away": p + right * side * 1.9, "parted": false, "line": line})


## The canteen stall on the courtyard loop's chord: two table rows lining the cut, a counter, a sign and yellow arrows.
func _build_canteen() -> void:
	var a: Vector3 = campus(SHORTCUT[0])
	var b: Vector3 = campus(SHORTCUT[1])
	var mid: Vector3 = (a + b) * 0.5
	mid.y = ground_y(mid)
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	canteen = Node3D.new()
	canteen.name = "CanteenShortcut"
	add_child(canteen)
	canteen.global_position = mid
	canteen.rotation.y = yaw_of(dir)
	for side: float in [-1.0, 1.0]:
		for k: int in 2:
			var t: Node3D = CineFX.build_prop("table")
			canteen.add_child(t)
			t.position = Vector3(side * 1.9, 0.0, -2.0 + 4.0 * float(k))
			t.rotation.y = PI * 0.5
	var counter: Node3D = CineFX.build_prop("counter", {"len": 2.0})
	canteen.add_child(counter)
	counter.position = Vector3(3.2, 0.0, 0.0)
	counter.rotation.y = PI * 0.5
	var sign := Label3D.new()
	sign.text = "CĂN TIN · LỐI TẮT"
	sign.font_size = 48
	sign.outline_size = 10
	sign.modulate = Color("#FFE66D")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0.0, 2.6, 0.0)
	canteen.add_child(sign)
	var arrow_m: StandardMaterial3D = _mat(Color("#FFD32A"), 1.2)
	for k: int in 3:
		var arr := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.7, 0.9, 0.04)
		arr.mesh = pm
		arr.material_override = arrow_m
		arr.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		arr.position = Vector3(0.0, 0.03, 2.5 - 2.5 * float(k))
		canteen.add_child(arr)


# ---------------------------------------------------------------------------
func _place(v: float) -> void:
	var p: Vector3 = point_at(s)
	var ahead: Vector3 = point_at(s + 1.0) - p
	if _hop_t >= 0.0:
		p.y += sin(clampf(_hop_t / 0.4, 0.0, 1.0) * PI) * 0.85
	courier.global_position = p
	if Vector2(ahead.x, ahead.z).length() > 0.01:
		courier.rotation.y = yaw_of(ahead)
	CharacterBuilder.set_speed(courier, v)


func distance() -> float:
	return flat(player.global_position, courier.global_position) if player and courier else 0.0


## Courier speed for the player's distance, capped so he reaches the tackle stretch no earlier than min_s() and the end of
## the path no earlier than min_s() + END_EXTRA_S.
func speed_for(dist: float) -> float:
	var v: float = speed_close() if dist < 8.0 else (speed_mid() if dist < 15.0 else speed_far())
	if dist > TAUNT_M:
		v = 0.0
	var tackle_d: float = TACKLE_FROM_U * length_m
	var ms: float = min_s()
	if s < tackle_d and clock < ms:
		v = minf(v, (tackle_d - s) / maxf(ms - clock, 0.5))
	elif clock < ms + END_EXTRA_S:
		v = minf(v, (length_m - s) / maxf(ms + END_EXTRA_S - clock, 0.5))
	return v


func _tick(dt: float) -> void:
	if tackling:
		_tick_tackle(dt)
		return
	if ended:
		return
	_taunt_cd -= dt
	_tick_move(dt)
	_tick_slow()
	_tick_crowd()
	_tick_shortcut()
	var dist: float = distance()
	# leash (not in the first LEASH_START_S: he starts with a head start on the player)
	if dist > leash_m() and clock > LEASH_START_S:
		far_t += dt
		if far_t >= leash_grace():
			CharacterBuilder.set_speed(courier, 0.0)
			fail(T_LOST)
			return
	else:
		far_t = 0.0
	set_info("Khoảng cách: %d m · %d giây" % [int(dist), int(clock)])
	set_prompt(_prompt(dist))
	# banana slip
	if slip_t > 0.0:
		slip_t -= dt
		if slip_t <= 0.0:
			CharacterBuilder.stop_clip(courier)
			bubble.visible = false
		return
	if _hop_t >= 0.0:
		_hop_t += dt
		if _hop_t > 0.4:
			_hop_t = -1.0
	var v: float = speed_for(dist)
	if v <= 0.0 and _taunt_cd <= 0.0 and s < length_m - 0.01:
		taunts += 1
		_taunt_cd = 4.0
		_say(T_TAUNT, Color("#FF6B5A"))
		courier.rotation.y = yaw_of(player.global_position - courier.global_position)
	var s0: float = s
	s = minf(s + v * dt, length_m)
	_place(v)
	if v <= 0.0:
		courier.rotation.y = yaw_of(player.global_position - courier.global_position)
	_tick_obstacles(s0)
	if not slipped and s >= SLIP_U * length_m:
		slip()
	if s >= length_m - 0.01 and not bubble.visible:
		_say("Hết đường chạy rồi...", Color("#FFE66D"))
		CharacterBuilder.set_speed(courier, 0.0)


func _prompt(dist: float) -> String:
	if can_tackle():
		return T_TACKLE
	var o: Dictionary = obstacle_ahead()
	if not o.is_empty():
		return T_VAULT if o["kind"] != "slide" else T_SLIDE
	return T_WARN if dist > WARN_M else ""


## The courier passes the set pieces: hops the benches, slides the barriers, shouts and knocks over the cans and the cart.
func _tick_obstacles(s0: float) -> void:
	for o: Dictionary in obstacles:
		var d: float = float(o["d"])
		if o["kind"] in ["trash", "fruit"]:
			if not o["warned"] and s >= d - 4.0:
				o["warned"] = true
				_say(T_KNOCK, WARN)
			if o["state"] == "up" and s0 < d + 1.5 and s >= d + 1.5:
				knock_over(o)
		elif s0 < d - 0.5 and s >= d - 0.5:
			if o["kind"] == "vault":
				_hop_t = 0.0
			else:
				CharacterBuilder.play(courier, "slide", 0.5)


## The obstacle the player can vault / slide right now (in front within reach, facing it), else {}.
func obstacle_ahead() -> Dictionary:
	if player == null or not _move.is_empty():
		return {}
	var fwd: Vector3 = player.facing_dir()
	for o: Dictionary in obstacles:
		var kind: String = String(o["kind"])
		var standing: bool = kind in ["vault", "slide"] or o["state"] == "down"
		if not standing:
			continue
		var at: Vector3 = o["at"]
		var d := Vector3(at.x - player.global_position.x, 0.0, at.z - player.global_position.z)
		var reach: float = SLIDE_M if kind == "slide" else vault_m()
		var along: float = absf(d.dot(o["fwd"]))
		var across: float = absf(d.dot(Vector3(-(o["fwd"] as Vector3).z, 0.0, (o["fwd"] as Vector3).x)))
		if along > reach + 0.3 or across > OBST_W * 0.5 + 0.4:
			continue
		if d.length() > 0.05 and fwd.dot(d.normalized()) < 0.35:
			continue
		return o
	return {}


## [Space]: the tackle on the last stretch, else a vault over the bench / railing / toppled thing in front.
func try_vault() -> bool:
	if state != "running" or ended:
		return false
	if can_tackle():
		return try_tackle()
	var o: Dictionary = obstacle_ahead()
	if o.is_empty() or o["kind"] == "slide":
		return false
	_begin_move("vault", o, VAULT_S, 1.15)
	vaults += 1
	return true


## [Ctrl]: slide under the barrier in front.
func try_slide() -> bool:
	if state != "running" or ended:
		return false
	var o: Dictionary = obstacle_ahead()
	if o.is_empty() or o["kind"] != "slide":
		return false
	_begin_move("slide", o, SLIDE_S, 0.0)
	slides += 1
	return true


func _begin_move(kind: String, o: Dictionary, secs: float, h: float) -> void:
	var at: Vector3 = o["at"]
	var f: Vector3 = o["fwd"]
	var side: float = signf((player.global_position - at).dot(f))
	if side == 0.0:
		side = -1.0
	var to: Vector3 = at - f * side * 1.3
	to.y = ground_y(to)
	var yaw: float = yaw_of(to - player.global_position)
	_move = {"kind": kind, "from": player.global_position, "to": to, "t": 0.0, "secs": secs, "h": h, "yaw": yaw,
		"cam": Vector2(player.yaw, player.pitch), "body": o.get("toppled_body", o.get("body"))}
	# one teleport at the start (clears the locomotion state), then the clip; the arc itself only moves the body
	player.teleport(player.global_position, yaw)
	_keep_cam(_move["cam"])
	player.controls_enabled = false
	var obst: Variant = _move["body"]
	if obst is PhysicsBody3D and is_instance_valid(obst):
		player.add_collision_exception_with(obst)   # the capsule passes over / under it
	CharacterBuilder.play(player.model, "jump_takeoff" if kind == "vault" else "slide", secs)
	MissionSfx.play(self, "vault", -4.0)
	cues_played.append(kind)
	Impact.particles(self, "dust", player.global_position, Vector3.UP, 0.7)


func _tick_move(dt: float) -> void:
	if _move.is_empty():
		return
	_move["t"] = float(_move["t"]) + dt
	var u: float = clampf(float(_move["t"]) / float(_move["secs"]), 0.0, 1.0)
	var p: Vector3 = (_move["from"] as Vector3).lerp(_move["to"], u)
	p.y += sin(u * PI) * float(_move["h"])
	_carry(p, float(_move["yaw"]))
	if u >= 1.0:
		var obst: Variant = _move["body"]
		var cam: Vector2 = _move["cam"]
		_move = {}
		player.teleport(p, player.model.rotation.y if player.model else 0.0)
		_keep_cam(cam)
		if obst is PhysicsBody3D and is_instance_valid(obst):
			player.remove_collision_exception_with(obst)
		player.controls_enabled = true
		Impact.particles(self, "dust", player.global_position, Vector3.UP, 0.6)


## Moves the player's body along a scripted arc without teleport() (that would stop the clip and snap the camera): the
## position, no velocity, the body facing; the camera keeps its own yaw and pitch.
func _carry(p: Vector3, yaw: float) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	if player.model:
		player.model.rotation.y = yaw


func _keep_cam(cam: Vector2) -> void:
	player.yaw = cam.x
	player.pitch = cam.y


## Spilled rubbish and rolling fruit: the player's speed is capped inside a slow zone (vaulting skips it).
func _tick_slow() -> void:
	var inside: bool = false
	for z: Vector3 in slow_zones:
		if flat(z, player.global_position) < SLOW_R:
			inside = true
			break
	if inside != _in_slow:
		_in_slow = inside
		player.combat_speed_cap = slow_cap() if inside else INF
		if inside:
			popup("Trơn trượt quá!", 1.0, Color("#FFE66D"))


func _tick_crowd() -> void:
	for c: Dictionary in crowd:
		if c["parted"]:
			continue
		var n: Node3D = c["node"]
		if flat(n.global_position, courier.global_position) < PART_M or flat(n.global_position, player.global_position) < 2.2:
			c["parted"] = true
			parted += 1
			(c["line"] as Label3D).visible = true
			CharacterBuilder.play(n, "flinch", 0.5)
			if is_inside_tree():
				create_tween().tween_property(n, "global_position", c["away"], 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				n.global_position = c["away"]


## The player inside the canteen stall on the loop's chord while the courier is on the loop: the shortcut.
func _tick_shortcut() -> void:
	if shortcut_used or canteen == null:
		return
	var loop_from: float = cum[3]
	var loop_to: float = cum[6]
	if s < loop_from - 5.0 or s > loop_to:
		return
	if flat(player.global_position, canteen.global_position) < 2.2:
		shortcut_used = true
		popup(T_SHORTCUT, 1.8, Color("#FFE66D"))


## The tackle is on: the last stretch (or him cornered at the end), the player within tackle_m().
func can_tackle() -> bool:
	if state != "running" or ended or tackling or not _move.is_empty():
		return false
	if s < TACKLE_FROM_U * length_m:
		return false
	return distance() <= tackle_m()


## The slow-motion flying tackle: an arc onto him, the finisher impact and the director orbit, then the replay.
func try_tackle() -> bool:
	if not can_tackle():
		return false
	tackling = true
	tackled = true
	_tackle_t = 0.0
	_tackle_from = player.global_position
	_tackle_cam = Vector2(player.yaw, player.pitch)
	player.teleport(player.global_position, yaw_of(courier.global_position - _tackle_from))
	_keep_cam(_tackle_cam)
	player.controls_enabled = false
	CharacterBuilder.play(player.model, "jump_takeoff", TACKLE_S)
	set_prompt("")
	CharacterBuilder.set_speed(courier, 0.0)
	Impact.slowmo_orbit(self, courier, 0.9)
	cues_played.append("tackle")
	return true


func _tick_tackle(dt: float) -> void:
	_tackle_t += dt
	var u: float = clampf(_tackle_t / TACKLE_S, 0.0, 1.0)
	var to: Vector3 = courier.global_position - (courier.global_position - _tackle_from).normalized() * 0.6
	var p: Vector3 = _tackle_from.lerp(to, u)
	p.y += sin(u * PI) * 0.7
	_carry(p, yaw_of(courier.global_position - _tackle_from))
	if u >= 1.0 and not ended:
		player.teleport(p, yaw_of(courier.global_position - _tackle_from))
		_keep_cam(_tackle_cam)
		var dir: Vector3 = courier.global_position - _tackle_from
		dir.y = 0.0
		Impact.hit(self, "finisher", {"pos": courier.global_position + Vector3(0.0, 0.9, 0.0), "dir": dir.normalized(), "no_hitstop": true})
		CharacterBuilder.play(courier, "knockdown")
		CharacterBuilder.play(player.model, "roll", 0.6)
		_say("Ối giời ơi!", Color("#FFE66D"))
		if rec:
			rec.mark("blow")
		_end_run()


## The banana peel: slide whistle, the courier down for SLIP_S, a replay mark.
func slip() -> void:
	slipped = true
	slip_t = SLIP_S
	banana.visible = false
	CharacterBuilder.set_speed(courier, 0.0)
	CharacterBuilder.play(courier, "knockdown")
	_say(T_SLIP, Color("#FFE66D"))
	play_cue("slide_whistle")
	if rec:
		rec.mark("blow")


func _say(text: String, col: Color) -> void:
	bubble.text = text
	bubble.modulate = col
	bubble.visible = true


## After the tackle: the short replay (the run keeps recording REPLAY_AFTER s first), then done.
func _end_run() -> void:
	ended = true
	tackling = false
	set_prompt("")
	CharacterBuilder.set_speed(courier, 0.0)
	var t := get_tree().create_timer(StoryStage.REPLAY_AFTER if not manual else 0.0)
	t.timeout.connect(func() -> void:
		if state != "running":
			return
		if player:
			player.controls_enabled = true
		play_short_replay(rec, String(beat.get("replay", "seg_d1_chase")), courier, player,
			func() -> void: finish({"taunts": taunts, "secs": clock, "vaults": vaults, "slides": slides, "shortcut": shortcut_used})))


func _jump_filter() -> bool:
	if state == "running" and (can_tackle() or not obstacle_ahead().is_empty()):
		return try_vault()
	return bool(_prev_filter.call()) if _prev_filter.is_valid() else false


func _unhandled_input(event: InputEvent) -> void:
	if state != "running" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and not k.echo and k.physical_keycode == KEY_CTRL:
		if try_slide():
			get_viewport().set_input_as_handled()
	elif k.pressed and not k.echo and k.physical_keycode == KEY_SPACE and manual:
		if try_vault():   # tests drive the mission by hand: Space reaches it here (the controller's filter in play)
			get_viewport().set_input_as_handled()


func _cleanup() -> void:
	if _filter_set and player and is_instance_valid(player):
		player.jump_filter = _prev_filter
		player.combat_speed_cap = INF
		player.controls_enabled = true
	_filter_set = false
	var all: Array = [courier, banana, rec, canteen]
	for o: Dictionary in obstacles:
		all.append(o["node"])
	for c: Dictionary in crowd:
		all.append(c["node"])
	for n: Variant in all:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	obstacles.clear()
	crowd.clear()
