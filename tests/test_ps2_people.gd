# File: res://tests/test_ps2_people.gd
# Test headless người PS2 (spec vice-people-and-movement, Phần 1): cổ điển không đổi (dấu vân tay ghi từ main),
# ở chế độ ps2 mọi preset là thân rigged + đầu PS2, đủ pivot của thân tự dựng, vật liệu mặt một ô atlas, cao đầu thật,
# đổi ô biểu cảm, chớp mắt bằng ô "closed", đồ gắn vào pivot cẳng tay nằm ở cổ tay, tư thế tĩnh + bake người ngồi xe
# (Task 4), thời gian dựng.
# Chạy:  godot --headless --path . --script tests/test_ps2_people.gd
extends SceneTree

const PRESETS: Array[String] = ["student", "student_m", "student_f", "player", "rider", "lecturer", "guard", "vovinam", "master", "cook", "proctor", "casual", "cop"]
const PIVOTS: Array[String] = ["hips", "torso", "neck", "head", "head_top", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "knee_l", "knee_r", "foot_l", "foot_r", "chest", "face_mesh", "torso_mesh"]
## Dấu vân tay "số node:số MeshInstance3D" của thân CỔ ĐIỂN, ghi trên main trước Phần 1 (Task 3 Step 2-3).
const CLASSIC_FP: Dictionary = {"student": "79:60", "lecturer": "76:57", "player": "68:49", "player_rigged": "31:18"}

var world: Node3D
var chars: Array[Node3D] = []
var frames: int = 0
var done: bool = false
var blink_seen: Dictionary = {}
var wrist_probe: Node3D
var static_c: Node3D
var static_out: Node3D
var phase_task4: bool = false


func _initialize() -> void:
	# headless không vẽ nên Godot chỉ ngủ ~6.9 ms mỗi frame (~145 fps): ghim 60 fps để các mốc frame dưới đây đúng thời gian
	# (420 frame = 7 s cho kiểm tra chớp mắt; ở ~145 fps cửa sổ chỉ ~2.8 s và chỉ khoảng một nửa số người kịp chớp lần đầu)
	Engine.max_fps = 60
	world = Node3D.new()
	root.add_child(world)
	if not _classic_unchanged():
		return
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	for i: int in range(PRESETS.size()):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i], "seed": i * 31 + 1})
		c.position = Vector3(float(i) * 1.2, 0.0, 0.0)
		world.add_child(c)
		chars.append(c)
		if not _check(bool(c.get_meta("rigged", false)), "%s: vice build must be rigged" % PRESETS[i]):
			return
		if not _check(bool(c.get_meta("ps2_head", false)), "%s: vice build must carry a PS2 head" % PRESETS[i]):
			return
		for k: String in PIVOTS:
			if not _check(CharacterBuilder.get_pivot(c, k) != null, "%s: missing pivot %s" % [PRESETS[i], k]):
				return
		var fm: StandardMaterial3D = CharacterBuilder.get_pivot(c, "face_mesh").material_override as StandardMaterial3D
		if not _check(fm != null and bool(fm.get_meta("ps2_face", false)) and fm.uv1_scale.is_equal_approx(Vector3(0.25, 0.5, 1.0)), "%s: face material must sample one atlas cell" % PRESETS[i]):
			return
		var n_mi: int = CharacterBuilder._mesh_instances(c).size()
		if not _check(n_mi >= 6 and n_mi <= 40, "%s: %d mesh instances (expected 6..40)" % [PRESETS[i], n_mi]):
			return
	print("--- TEST PS2 PEOPLE: %d presets in ps2 mode ---" % PRESETS.size())


func _process(_d: float) -> bool:
	if done:
		return true
	frames += 1
	if frames == 3:
		for i: int in range(chars.size()):
			var mi: MeshInstance3D = CharacterBuilder.get_pivot(chars[i], "face_mesh") as MeshInstance3D
			var ab: AABB = mi.global_transform * mi.get_aabb()
			var h: float = ab.size.y
			if i < 3:
				print("  %s head height %.3f m, head top y %.2f" % [PRESETS[i], h, CharacterBuilder.head_top(chars[i]).global_position.y])
			if not _check(h > 0.20 and h < 0.26, "%s: world head height %.3f (expected 0.20..0.26: realistic, not cartoon)" % [PRESETS[i], h]):
				return true
		var top: float = CharacterBuilder.head_top(chars[1]).global_position.y
		if not _check(top > 1.5 and top < 2.0, "student_m head top at %.2f m (expected 1.5..2.0)" % top):
			return true
		# đồ gắn dưới pivot cẳng tay phải, 0.22 m dọc cẳng tay -> ở cổ tay
		wrist_probe = Node3D.new()
		wrist_probe.position = Vector3(0.0, -0.22, 0.0)
		CharacterBuilder.get_pivot(chars[0], "elbow_r").add_child(wrist_probe)
	if frames == 6:
		var sk: Skeleton3D = chars[0].get_meta("skeleton") as Skeleton3D
		var wb: int = sk.find_bone("Wrist.R")
		var wrist: Vector3 = sk.global_transform * sk.get_bone_global_pose(wb).origin
		var gap: float = wrist_probe.global_position.distance_to(wrist)
		print("  forearm attach -> wrist gap %.3f m" % gap)
		if not _check(gap < 0.08, "an attachment 0.22 m down the elbow_r pivot must sit at the wrist (gap %.3f m)" % gap):
			return true
		for e: String in ["happy", "pain", "talk"]:
			CharacterBuilder.set_expression(chars[0], e)
			var fm: StandardMaterial3D = CharacterBuilder.get_pivot(chars[0], "face_mesh").material_override as StandardMaterial3D
			if not _check(fm.uv1_offset.is_equal_approx(PS2Head.cell_offset(e)), "set_expression(%s) must move the face to its cell" % e):
				return true
		CharacterBuilder.set_expression(chars[0], "open")
	if frames >= 10 and frames < 420:
		var closed: Vector3 = PS2Head.cell_offset("closed")
		for i: int in range(chars.size()):
			var fm2: StandardMaterial3D = CharacterBuilder.get_pivot(chars[i], "face_mesh").material_override as StandardMaterial3D
			if fm2.uv1_offset.is_equal_approx(closed):
				blink_seen[i] = true
	if frames == 420:
		print("  blinked: %d / %d" % [blink_seen.size(), chars.size()])
		if not _check(blink_seen.size() >= 10, "blinking must switch to the closed cell (only %d of %d blinked in 7 s)" % [blink_seen.size(), chars.size()]):
			return true
		_task4_start()
	if phase_task4 and frames == 424:
		_task4_check_sit()
	if phase_task4 and frames == 428:
		_task4_check_rest_and_bake()
	return false


# --- Task 4: tư thế tĩnh (pose) + bake thân rigged; thời gian dựng ------------------------
func _task4_start() -> void:
	phase_task4 = true
	static_c = CharacterBuilder.build({"preset": "student", "seed": 77, "animate": false})
	static_c.position = Vector3(0.0, 0.0, 4.0)
	world.add_child(static_c)
	CharacterBuilder.pose(static_c, "sit", 0.0)
	# pose() NGOÀI cây rồi mới add_child (dựng cảnh trước khi gắn vào cây): xương phải giữ tư thế khi vào cây
	static_out = CharacterBuilder.build({"preset": "student", "seed": 78, "animate": false})
	static_out.position = Vector3(1.5, 0.0, 4.0)
	CharacterBuilder.pose(static_out, "sit", 0.0)
	world.add_child(static_out)


func _task4_check_sit() -> void:
	var hy: float = CharacterBuilder.get_pivot(static_c, "hips").global_position.y
	print("  static sit: hips y %.2f" % hy)
	if not _check(hy < 0.62, "pose(sit) on a rigged body must lower the hips (y %.2f)" % hy):
		return
	var hy_out: float = CharacterBuilder.get_pivot(static_out, "hips").global_position.y
	print("  static sit posed outside the tree: hips y %.2f" % hy_out)
	if not _check(hy_out < 0.62, "pose(sit) before add_child must survive entering the tree (hips y %.2f)" % hy_out):
		return
	# xương bàn chân Quaternius (Foot.L/R) là đích IK con của Root: khi clip gập chân, bàn chân phải đi theo ống chân
	# (khoảng gối -> bàn chân giữ như tư thế nghỉ) thay vì đứng yên trên sàn làm giày bị kéo dài
	for c: Node3D in [static_c, static_out]:
		var sk: Skeleton3D = c.get_meta("skeleton") as Skeleton3D
		for s: String in ["L", "R"]:
			var kb: int = sk.find_bone("LowerLeg." + s)
			var fb: int = sk.find_bone("Foot." + s)
			var d_rest: float = sk.get_bone_global_rest(kb).origin.distance_to(sk.get_bone_global_rest(fb).origin)
			var d_now: float = sk.get_bone_global_pose(kb).origin.distance_to(sk.get_bone_global_pose(fb).origin)
			if c == static_c and s == "L":
				print("  sit: knee -> foot %.3f (rest %.3f)" % [d_now, d_rest])
			if not _check(absf(d_now - d_rest) < 0.01, "pose(sit): Foot.%s must follow the shin (knee -> foot %.3f, rest %.3f)" % [s, d_now, d_rest]):
				return
	CharacterBuilder.pose(static_c, "", 0.0)


func _task4_check_rest_and_bake() -> void:
	var hy: float = CharacterBuilder.get_pivot(static_c, "hips").global_position.y
	if not _check(hy > 0.7, "pose('') must reset to the rest pose (hips y %.2f)" % hy):
		return
	var holder := Node3D.new()
	world.add_child(holder)
	var mi: MeshInstance3D = CharacterBuilder.build_baked_rider(holder, Vector3(0.0, 0.3, 0.0), {"seed": 5})
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var verts: int = 0
	var has_face: bool = false
	for s: int in range(mesh.get_surface_count()):
		verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var m: Material = mesh.surface_get_material(s)
		if m and bool(m.get_meta("ps2_face", false)):
			has_face = true
	var ab: AABB = mesh.get_aabb()
	print("  baked PS2 rider: %d surfaces, %d verts, height %.2f" % [mesh.get_surface_count(), verts, ab.size.y])
	if not _check(mesh.get_surface_count() >= 3 and verts >= 2000, "baked rider too small (%d surfaces, %d verts)" % [mesh.get_surface_count(), verts]):
		return
	if not _check(has_face, "baked rider must keep the PS2 face material"):
		return
	if not _check(ab.size.y < 1.45, "baked rider must be seated (height %.2f m)" % ab.size.y):
		return
	# build time after warm-up
	var t0: int = Time.get_ticks_usec()
	for i: int in range(20):
		var c: Node3D = CharacterBuilder.build({"preset": PRESETS[i % PRESETS.size()], "seed": 500 + i})
		c.free()
	var per: float = float(Time.get_ticks_usec() - t0) / 20000.0
	print("  build time %.1f ms per character" % per)
	if not _check(per < 15.0, "building one PS2 character takes %.1f ms (budget 15)" % per):
		return
	print("✅ SUCCESS: PS2 PEOPLE - RIGGED BODIES, PS2 HEADS, PIVOTS, CELLS, BLINK, STATIC POSE, BAKED RIDER, CLASSIC UNCHANGED")
	done = true
	quit(0)


# --- Cổ điển không đổi ------------------------------------------------------------------
func _fp(c: Node3D) -> String:
	var nodes: int = 0
	var meshes: int = 0
	var stack: Array[Node] = [c]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		if n is MeshInstance3D:
			meshes += 1
		for ch: Node in n.get_children():
			stack.append(ch)
	return "%d:%d" % [nodes, meshes]


func _classic_unchanged() -> bool:
	CharacterBuilder.ps2 = false
	var probes: Dictionary = {
		"student": {"preset": "student", "seed": 1}, "lecturer": {"preset": "lecturer", "seed": 2},
		"player": {"preset": "player", "seed": 3}, "player_rigged": {"preset": "player", "seed": 2805, "rigged": true},
	}
	var ok: bool = true
	for key: String in probes.keys():
		var c: Node3D = CharacterBuilder.build(probes[key])
		var fp: String = _fp(c)
		c.free()
		print("  classic fingerprint %s = %s" % [key, fp])
		if fp != String(CLASSIC_FP[key]):
			ok = false
	return _check(ok, "classic characters changed (copy the fingerprints printed above from an UNMODIFIED main into CLASSIC_FP)")


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
