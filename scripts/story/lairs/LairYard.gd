# File: res://scripts/story/lairs/LairYard.gd
# The Day 3 container yard by the canal (spec C-D5 / C-D7; plan 2026-10-26-phase-c-integration.md): a code-built level that
# StoryRoam adds under FreeRoam while a Day 3 yard beat ("lair": "yard") is current. It sits on the free waterfront plot
# south of the canal, east of the Rạch Hầm bridge (a clear, flat 50 x 40 m box measured with FreeRoam.cine_stage), yaw 0:
# local x east, -z north (toward the canal), origin on the floor at CENTER.
# Contents (all code-built; CineFX / CinePropsC meshes so the cinematics match):
#   - a concrete apron, chain-link fences with colliders on all four sides and the gate gap on the west side (toward
#     Nguyễn Xiển), a name board, four floodlight poles (no shadows);
#   - 20 ft containers (tall: occluders, not cover) in rows along the fences and two in the middle;
#   - the discovery stack on the cine pad: the six containers of cine_d3_mannequins (two rows of three, doors facing the
#     pad) at the exact spots of that timeline's stage frame (pad_xf() = the yard stage (2180, 160)); closed for the sneak,
#     hidden while a yard cinematic plays (the cinematic brings its own), then shown open with the mannequins inside;
#   - low cover in the group "cover" (CoverMap.scan): jersey barriers, pallet stacks, cable reels and the SmartCrates of
#     smart glasses (destructible, counted);
#   - Alexander's parked forklift (hidden while the boss fight runs: ForkliftBoss drives its own);
#   - gameplay points: patrol routes, gunfight spawns, ammo spots, the coffin-dance loop, the boss arena, the E4 manifest.
# Cost: static meshes and colliders only; nothing runs per frame (the crates animate only while breaking).
class_name LairYard
extends Node3D

const CENTER := Vector2(2183.0, 167.0)
const YAW: float = 0.0
const HALF := Vector2(25.0, 20.0)
## The yard cine stage (CineTimeline.PHASE_C_STAGES "yard") in yard-local coordinates.
const PAD := Vector3(-3.0, 0.0, -7.0)
const GATE_Z: Vector2 = Vector2(5.0, 12.0)        # the gate gap in the west fence (local z)
const FENCE_H: float = 2.4
## Stage-frame columns / colour order of the cine_d3_mannequins stack.
const STACK_COLS: Array[float] = [-2.6, 0.0, 2.6]
const STACK_COLORS: Array[Color] = [Color("#2E5E8C"), Color("#9E3B2E"), Color("#3F7A4A")]
## Other containers: [local centre (floor), yaw deg, colour, rows].
const BOXES: Array = [
	[Vector3(-21.0, 0.0, -13.0), 90.0, Color("#B5651D"), 2], [Vector3(-21.0, 0.0, -5.0), 90.0, Color("#2E5E8C"), 1],
	[Vector3(21.0, 0.0, -13.0), 90.0, Color("#3F7A4A"), 2], [Vector3(21.0, 0.0, -5.0), 90.0, Color("#9E3B2E"), 1],
	[Vector3(21.0, 0.0, 9.0), 90.0, Color("#6B6F76"), 1],
	[Vector3(-9.0, 0.0, 16.5), 0.0, Color("#9E3B2E"), 1], [Vector3(7.0, 0.0, 16.5), 0.0, Color("#2E5E8C"), 2],
	[Vector3(9.0, 0.0, -11.0), 0.0, Color("#B5651D"), 1], [Vector3(-15.0, 0.0, 3.0), 90.0, Color("#3F7A4A"), 1],
]
## Low cover: [kind, local centre (floor), yaw deg].
const COVER: Array = [
	["barrier", Vector3(-8.0, 0.0, 3.5), 0.0], ["barrier", Vector3(4.0, 0.0, 2.0), 15.0], ["barrier", Vector3(-1.0, 0.0, 9.0), 0.0],
	["barrier", Vector3(-13.0, 0.0, 7.5), 0.0], ["barrier", Vector3(-18.0, 0.0, 10.0), 90.0], ["barrier", Vector3(15.0, 0.0, 13.5), 0.0],
	["pallets", Vector3(-11.0, 0.0, -2.0), 0.0], ["pallets", Vector3(6.0, 0.0, -5.0), 0.0], ["pallets", Vector3(-4.0, 0.0, 14.0), 0.0],
	["reel", Vector3(14.0, 0.0, -6.5), 0.0], ["reel", Vector3(-17.0, 0.0, -9.0), 0.0],
]
## The smart-glasses crates (local floor points).
const CRATES: Array[Vector3] = [Vector3(-12.5, 0.0, 0.5), Vector3(-14.5, 0.0, 12.0), Vector3(-6.0, 0.0, 11.0),
	Vector3(3.5, 0.0, 12.5), Vector3(11.5, 0.0, 8.0), Vector3(15.5, 0.0, -2.0), Vector3(11.0, 0.0, -7.0), Vector3(-14.0, 0.0, -11.5)]
const AMMO: Array[Vector3] = [Vector3(-18.0, 0.0, -1.0), Vector3(17.0, 0.0, 15.0), Vector3(5.0, 0.0, -8.0)]
const FORKLIFT_PARK := Vector3(17.0, 0.0, 2.0)
const MANIFEST := Vector3(13.5, 0.0, 15.0)

var floor_y: float = 0.0
var crates: Array[SmartCrate] = []
var stack: Node3D
var stack_crowds: Array[Node3D] = []
var stack_doors: Array[CineAnimProp] = []
var stack_open: bool = false
var forklift_park: Node3D
var cover_root: Node3D
var _hidden: Array[Node3D] = []


## Builds the yard under `parent` (FreeRoam) at CENTER, its floor found with a down ray (y = 0 when nothing is hit).
func build_in(parent: Node3D) -> void:
	name = "LairYard"
	parent.add_child(self)
	floor_y = _ground(parent)
	global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(YAW)), Vector3(CENTER.x, floor_y, CENTER.y))
	_build()
	add_child(LookZone.make(parent, "port_night", global_position, 110.0, 150.0))   # Q3: the yard's look near it


func _ground(parent: Node3D) -> float:
	if not parent.is_inside_tree():
		return 0.0
	var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(CENTER.x, 30.0, CENTER.y), Vector3(CENTER.x, -5.0, CENTER.y))
	var hit: Dictionary = space.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0


## Map point of a yard-local point.
func world(local: Vector3) -> Vector3:
	return global_transform * local


## Map yaw (radians) of a yard-local yaw (degrees).
func world_yaw(deg: float) -> float:
	return deg_to_rad(YAW + deg)


## The yard cine stage frame (cine_d3_mannequins, seg_d3_boss, cine_d3 play with this "xf").
func pad_xf() -> Transform3D:
	return Transform3D(global_transform.basis, world(PAD))


# ---------------------------------------------------------------------------
func _build() -> void:
	var concrete: StandardMaterial3D = CineFX._mat(Color("#55585C"), 0.95)
	var paint: StandardMaterial3D = CineFX._glow_mat(Color("#C9A227"), 0.25)
	CineFX._box(self, "Apron", Vector3(HALF.x * 2.0, 0.04, HALF.y * 2.0), Vector3(0.0, 0.02, 0.0), concrete)
	for i: int in 5:
		CineFX._box(self, "Line", Vector3(0.12, 0.01, 8.0), Vector3(-16.0 + 8.0 * i, 0.045, 6.0), paint)
	_fences()
	cover_root = Node3D.new()
	cover_root.name = "Cover"
	add_child(cover_root)
	for b: Array in BOXES:
		_container(b[0], float(b[1]), b[2], int(b[3]))
	_stack()
	for c: Array in COVER:
		_cover(String(c[0]), c[1], float(c[2]))
	for i: int in CRATES.size():
		var cr := SmartCrate.new()
		cr.setup({"name": "Crate%d" % i})
		cover_root.add_child(cr)
		cr.position = CRATES[i]
		cr.rotation.y = 0.3 * float(i % 3)
		crates.append(cr)
	forklift_park = CineFX.build_prop("forklift", {"name": "ParkedForklift"})
	add_child(forklift_park)
	forklift_park.position = FORKLIFT_PARK
	forklift_park.rotation.y = deg_to_rad(90.0)   # forks toward the yard (west)
	_body_box(forklift_park, Vector3(1.2, 2.2, 2.4), Vector3(0.0, 1.1, 0.1))
	for p: Vector3 in [Vector3(-23.5, 0.0, -18.5), Vector3(23.5, 0.0, -18.5), Vector3(-23.5, 0.0, 18.5), Vector3(23.5, 0.0, 18.5)]:
		_flood(p)
	var board := Label3D.new()
	board.name = "Board"
	board.text = "BẾN CONTAINER ABCXYZ\nKHÔNG PHẬN SỰ MIỄN VÀO"
	board.font_size = 64
	board.pixel_size = 0.012
	board.modulate = Color("#F2D7A6")
	board.outline_size = 8
	board.position = Vector3(-HALF.x - 0.3, 3.2, GATE_Z.x - 1.5)
	board.rotation.y = deg_to_rad(-90.0)
	add_child(board)


func _fences() -> void:
	var post: StandardMaterial3D = CineFX._mat(Color("#7A7F86"), 0.4)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.55, 0.58, 0.6, 0.35)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_mat.roughness = 0.6
	# [from, to] in local x / z; the west side is split by the gate
	var runs: Array = [[Vector3(-HALF.x, 0.0, -HALF.y), Vector3(HALF.x, 0.0, -HALF.y)],
		[Vector3(-HALF.x, 0.0, HALF.y), Vector3(HALF.x, 0.0, HALF.y)],
		[Vector3(HALF.x, 0.0, -HALF.y), Vector3(HALF.x, 0.0, HALF.y)],
		[Vector3(-HALF.x, 0.0, -HALF.y), Vector3(-HALF.x, 0.0, GATE_Z.x)],
		[Vector3(-HALF.x, 0.0, GATE_Z.y), Vector3(-HALF.x, 0.0, HALF.y)]]
	var body := StaticBody3D.new()
	body.name = "Fences"
	add_child(body)
	for r: Array in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var mid: Vector3 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
		var size: Vector3 = Vector3(length, FENCE_H, 0.06) if along_x else Vector3(0.06, FENCE_H, length)
		CineFX._box(self, "Fence", size, mid + Vector3(0.0, FENCE_H * 0.5, 0.0), mesh_mat)
		CineFX._box(self, "Rail", Vector3(size.x, 0.06, size.z) + (Vector3(0.0, 0.0, 0.04) if along_x else Vector3(0.04, 0.0, 0.0)),
			mid + Vector3(0.0, FENCE_H, 0.0), post)
		var n: int = int(length / 3.0)
		for k: int in n + 1:
			CineFX._box(self, "Post", Vector3(0.08, FENCE_H + 0.1, 0.08), a.lerp(b, float(k) / float(maxi(n, 1))) + Vector3(0.0, (FENCE_H + 0.1) * 0.5, 0.0), post)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(size.x, FENCE_H, maxf(size.z, 0.3)) if along_x else Vector3(maxf(size.x, 0.3), FENCE_H, size.z)
		cs.shape = bs
		cs.position = mid + Vector3(0.0, FENCE_H * 0.5, 0.0)
		body.add_child(cs)


## A 20 ft container (CinePropsC, doors closed) with a box collider; rows = 1 or 2 high. Centre = the box's floor centre.
func _container(centre: Vector3, yaw_deg: float, col: Color, rows: int) -> void:
	var holder := Node3D.new()
	holder.name = "Container"
	holder.position = centre
	holder.rotation.y = deg_to_rad(yaw_deg)
	add_child(holder)
	for r: int in rows:
		var c: Node3D = CineFX.build_prop("container", {"color": col if r == 0 else col.lightened(0.15)})
		holder.add_child(c)
		c.position = Vector3(0.0, CinePropsC.CONTAINER_H * r, -CinePropsC.CONTAINER_L * 0.5)   # its origin is the door face
	_body_box(holder, Vector3(CinePropsC.CONTAINER_W, CinePropsC.CONTAINER_H * rows, CinePropsC.CONTAINER_L),
		Vector3(0.0, CinePropsC.CONTAINER_H * rows * 0.5, 0.0))


## The cine_d3_mannequins stack on the pad: stage (COLS[i], row * H, 0), yaw 180 (doors face the pad, bodies toward -Z).
func _stack() -> void:
	stack = Node3D.new()
	stack.name = "DiscoveryStack"
	stack.position = PAD
	add_child(stack)
	for row: int in 2:
		for i: int in 3:
			var c: Node3D = CineFX.build_prop("container", {"color": STACK_COLORS[(i + row) % 3], "inner_light": row == 0 and i == 1})
			stack.add_child(c)
			c.position = Vector3(STACK_COLS[i], CinePropsC.CONTAINER_H * row, 0.0)
			c.rotation.y = PI
			stack_doors.append(c.get_meta("anim_node") as CineAnimProp)
			var crowd: Node3D = StoryCast.build("mannequins", {"cols": 5, "rows": 11, "dx": 0.42, "dz": 0.48})
			crowd.name = "Mannequins%d%d" % [row, i]
			stack.add_child(crowd)
			crowd.position = Vector3(STACK_COLS[i], CinePropsC.CONTAINER_H * row + 0.08, -0.45)
			crowd.rotation.y = PI
			crowd.visible = false
			stack_crowds.append(crowd)
	var w: float = STACK_COLS[2] - STACK_COLS[0] + CinePropsC.CONTAINER_W
	_body_box(stack, Vector3(w, CinePropsC.CONTAINER_H * 2.0, CinePropsC.CONTAINER_L - 0.3),
		Vector3(0.0, CinePropsC.CONTAINER_H, -CinePropsC.CONTAINER_L * 0.5 - 0.15))
	set_stack_open(false)


## Closed (the sneak) or open with the mannequins staring out (after the discovery beat).
func set_stack_open(open: bool) -> void:
	stack_open = open
	for d: CineAnimProp in stack_doors:
		if d:
			d.cine_eval(10.0 if open else 0.0, {"open_at": 0.0 if open else 99.0, "open_dur": 0.5})
	for c: Node3D in stack_crowds:
		c.visible = open
		if open and c.has_method("cine_eval"):
			c.call("cine_eval", 10.0, {})


## Hides the pieces a yard cinematic brings itself (the stack, the parked forklift); false shows them again.
## The parked forklift on (visible, solid) or off (the boss fight drives its own from the same spot).
func set_parked_forklift(on: bool) -> void:
	forklift_park.visible = on
	for cs: Node in forklift_park.find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).set_deferred("disabled", not on)


func hide_for_cine(on: bool) -> void:
	if on:
		_hidden.clear()
		for n: Node3D in [stack, forklift_park]:
			if n and n.visible:
				n.visible = false
				_hidden.append(n)
	else:
		for n2: Node3D in _hidden:
			if is_instance_valid(n2):
				n2.visible = true
		_hidden.clear()


func _cover(kind: String, centre: Vector3, yaw_deg: float) -> void:
	var body := StaticBody3D.new()
	body.name = kind.capitalize()
	body.add_to_group("cover")
	body.position = centre
	body.rotation.y = deg_to_rad(yaw_deg)
	cover_root.add_child(body)
	var size := Vector3.ONE
	match kind:
		"barrier":
			size = Vector3(3.0, 1.0, 0.6)
			CineFX._box(body, "Concrete", size, Vector3(0.0, 0.5, 0.0), CineFX._mat(Color("#A6A29A"), 0.95))
			CineFX._box(body, "Stripe", Vector3(3.02, 0.12, 0.62), Vector3(0.0, 0.8, 0.0), CineFX._mat(Color("#C0392B"), 0.7))
		"pallets":
			size = Vector3(1.2, 1.15, 1.1)
			for k: int in 8:
				CineFX._box(body, "Pallet", Vector3(1.2, 0.12, 1.1), Vector3(0.0, 0.07 + 0.144 * k, 0.0), CineFX._mat(Color("#B08A55"), 0.9))
		"reel":
			size = Vector3(1.2, 1.2, 1.0)
			var r: MeshInstance3D = CineFX._cyl(body, "Reel", 0.6, 0.6, 1.0, Vector3(0.0, 0.6, 0.0), CineFX._mat(Color("#8A5A2B"), 0.9))
			r.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(cs)


func _body_box(holder: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Collider"
	holder.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)


func _flood(p: Vector3) -> void:
	CineFX._box(self, "Pole", Vector3(0.18, 7.0, 0.18), p + Vector3(0.0, 3.5, 0.0), CineFX._mat(Color("#5A5F66"), 0.5))
	CineFX._box(self, "Lamp", Vector3(0.7, 0.25, 0.4), p + Vector3(0.0, 7.0, 0.0), CineFX._glow_mat(Color("#FFD27A"), 2.5))
	var l := OmniLight3D.new()
	l.name = "Flood"
	l.light_color = Color("#FFC870")
	l.light_energy = 1.6
	l.omni_range = 22.0
	l.shadow_enabled = false
	l.position = p + Vector3(0.0, 6.6, 0.0)
	add_child(l)


# ---------------------------------------------------------------------------
# Gameplay points (yard-local; StoryRoam / the missions convert with world())
# ---------------------------------------------------------------------------
const SNEAK_START := Vector3(-23.0, 0.0, 8.5)
const SNEAK_GOAL := Vector3(-3.0, 0.0, -4.6)          # in front of the stack doors
const SNEAK_GOAL_R: float = 2.6
## Patrol guards of the sneak: [start, patrol points].
const PATROLS: Array = [
	[Vector3(-11.0, 0.0, 10.0), [Vector3(-11.0, 0.0, 10.0), Vector3(12.0, 0.0, 10.0)]],
	[Vector3(5.5, 0.0, -0.5), [Vector3(5.5, 0.0, -0.5), Vector3(14.5, 0.0, -0.5), Vector3(14.5, 0.0, 6.5), Vector3(5.5, 0.0, 6.5)]],
	[Vector3(-9.0, 0.0, -2.5), [Vector3(-9.0, 0.0, -2.5), Vector3(3.5, 0.0, -2.5)]],
]
const FIGHT_START := Vector3(-3.0, 0.0, -2.6)          # the hero's spot at the end of cine_d3_mannequins
const WAVE1: Array[Vector3] = [Vector3(-8.6, 0.0, -5.2), Vector3(2.6, 0.0, -5.2), Vector3(-12.0, 0.0, -6.0), Vector3(7.0, 0.0, -7.5)]
const WAVE2: Array[Vector3] = [Vector3(-22.0, 0.0, 8.0), Vector3(-22.0, 0.0, 10.5), Vector3(-17.5, 0.0, 15.5), Vector3(-19.0, 0.0, 1.0)]
const CRATES_START := Vector3(-3.0, 0.0, 1.0)
const DANCE_LOOP: Array[Vector3] = [Vector3(-5.0, 0.0, 5.0), Vector3(9.0, 0.0, 5.0), Vector3(9.0, 0.0, 7.5), Vector3(-5.0, 0.0, 7.5)]
const BOSS_AT := FORKLIFT_PARK                       # Alexander drives off from the parked spot
const BOSS_YAW: float = 90.0
const MID := Vector3(2.0, 0.0, 4.0)                   # the yard_mid marker
const BOSS_PLAYER := Vector3(-6.0, 0.0, 7.0)


## World-space spots of a yard mission (MissionLairFight opts "points"): sneak | gunfight | crates | forklift.
func mission_points(task: String) -> Dictionary:
	var face_n: float = world_yaw(0.0)            # facing -z (north, toward the stack)
	var d: Dictionary = {"centre": world(Vector3.ZERO), "leash": MissionLairFight.LEASH_M}
	match task:
		"sneak":
			d["start"] = world(SNEAK_START)
			d["start_yaw"] = world_yaw(-90.0)      # in through the gate, facing east
			d["goal"] = world(SNEAK_GOAL)
			d["goal_r"] = SNEAK_GOAL_R
			var pats: Array = []
			for pr: Array in PATROLS:
				var route: Array = []
				for q: Variant in pr[1]:
					route.append(world(q))
				pats.append([world(pr[0]), route])
			d["patrols"] = pats
		"gunfight":
			d["start"] = world(FIGHT_START)
			d["start_yaw"] = face_n                # facing the stack, where the first wave jumps out
			var w1: Array = []
			for q1: Vector3 in WAVE1:
				w1.append(world(q1))
			var w2: Array = []
			for q2: Vector3 in WAVE2:
				w2.append(world(q2))
			d["waves"] = [w1, w2]
			d["ammo"] = _world_list(AMMO)
		"crates":
			d["start"] = world(CRATES_START)
			d["start_yaw"] = face_n
			d["crates"] = crates.duplicate()
			d["dance"] = _world_list(DANCE_LOOP)
			d["ammo"] = _world_list(AMMO)
		"forklift":
			d["start"] = world(BOSS_PLAYER)
			d["start_yaw"] = world_yaw(-90.0)
			d["boss_at"] = world(BOSS_AT)
			d["boss_yaw"] = world_yaw(BOSS_YAW)
			d["ammo"] = _world_list(AMMO)
	return d


func _world_list(list: Array) -> Array:
	var out: Array = []
	for q: Variant in list:
		out.append(world(q))
	return out
