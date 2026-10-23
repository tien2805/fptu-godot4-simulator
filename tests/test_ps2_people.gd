# File: res://tests/test_ps2_people.gd
# Test headless người PS2 (spec vice-people-and-movement, Phần 1): cổ điển không đổi (dấu vân tay ghi từ main),
# ở chế độ ps2 mọi preset là thân rigged + đầu PS2, đủ pivot của thân tự dựng, vật liệu mặt một ô atlas, cao đầu thật,
# đổi ô biểu cảm, chớp mắt bằng ô "closed", đồ gắn vào pivot cẳng tay nằm ở cổ tay, tư thế tĩnh + bake người ngồi xe
# (Task 4), thời gian dựng. Thêm (Task 4, review Task 3): vật liệu vice không viền, thân tự dựng vice không khối cầu khớp,
# pivot bàn chân chung BoneAttachment3D với gối, trục pivot elbow_r, set_opacity giữ mặt PS2, bàn chân theo ống chân khi
# ngồi, tư thế đặt ngoài cây, nhân vật rời cây rồi vào lại vẫn chạy clip tự dựng.
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
var readd_c: Node3D
var phase_task4: bool = false
const JOINT_PIVOTS: Array[String] = ["shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "knee_l", "knee_r"]


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
	# đổi phong cách như trong game (đổi art_style -> ViceStyle.forget_cached_materials()): bỏ vật liệu toon có viền mà các
	# thân cổ điển ở trên đã để lại trong cache
	CharacterBuilder._mat_cache = {}
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
		var outlined: String = _outlined_material(c)
		if not _check(outlined == "", "%s: vice materials must carry no outline next_pass (found on %s)" % [PRESETS[i], outlined]):
			return
		for s: String in ["l", "r"]:
			var foot_att: Node = CharacterBuilder.get_pivot(c, "foot_" + s).get_parent()
			if not _check(foot_att == CharacterBuilder.get_pivot(c, "knee_" + s).get_parent(), "%s: foot_%s pivot must hang under the knee_%s BoneAttachment3D (same LowerLeg bone)" % [PRESETS[i], s, s]):
				return
	# thân tự dựng ở vice (rigged: false; trong game chỉ khi thiếu mô hình): không khối cầu khớp, không viền
	var cb: Node3D = CharacterBuilder.build({"preset": "student", "seed": 9, "rigged": false})
	var spheres: int = 0
	for k: String in JOINT_PIVOTS:
		for ch: Node in CharacterBuilder.get_pivot(cb, k).get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is SphereMesh:
				spheres += 1
	var cb_outlined: String = _outlined_material(cb)
	cb.free()
	if not _check(spheres == 0, "a vice rigged:false body must have no joint spheres (found %d)" % spheres):
		return
	if not _check(cb_outlined == "", "a vice rigged:false body must carry no outline next_pass (found on %s)" % cb_outlined):
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
		# trục của pivot elbow_r (không chỉ gốc): -Y dọc cẳng tay (khuỷu -> cổ tay), -Z về phía trước nhân vật (lệch < 30°)
		var eb: Basis = CharacterBuilder.get_pivot(chars[0], "elbow_r").global_basis
		var elbow: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LowerArm.R")).origin
		var a_down: float = rad_to_deg((-eb.y).angle_to(wrist - elbow))
		var a_front: float = rad_to_deg((-eb.z).angle_to(-chars[0].global_basis.z))
		print("  elbow_r pivot: -Y vs forearm %.1f deg, -Z vs character front %.1f deg" % [a_down, a_front])
		if not _check(a_down < 10.0, "elbow_r pivot -Y must run along the forearm (off by %.1f deg)" % a_down):
			return true
		if not _check(a_front < 30.0, "elbow_r pivot -Z must point toward the character's front within 30 deg (off by %.1f deg)" % a_front):
			return true
		for e: String in ["happy", "pain", "talk"]:
			CharacterBuilder.set_expression(chars[0], e)
			var fm: StandardMaterial3D = CharacterBuilder.get_pivot(chars[0], "face_mesh").material_override as StandardMaterial3D
			if not _check(fm.uv1_offset.is_equal_approx(PS2Head.cell_offset(e)), "set_expression(%s) must move the face to its cell" % e):
				return true
		CharacterBuilder.set_expression(chars[0], "open")
		# set_opacity nhân bản vật liệu: mặt PS2 giữ meta ps2_face, set_expression vẫn đổi ô, Animator chớp mắt trên vật liệu mới
		CharacterBuilder.set_opacity(chars[1], 0.5)
		var fo: StandardMaterial3D = CharacterBuilder.get_pivot(chars[1], "face_mesh").material_override as StandardMaterial3D
		if not _check(fo != null and bool(fo.get_meta("ps2_face", false)), "set_opacity must keep the ps2_face meta on the PS2 face material"):
			return true
		CharacterBuilder.set_expression(chars[1], "surprised")
		if not _check(fo.uv1_offset.is_equal_approx(PS2Head.cell_offset("surprised")), "set_expression after set_opacity must still move the face cell"):
			return true
		if not _check(CharacterBuilder.get_animator(chars[1]).face_mat == fo, "after set_opacity the animator must blink on the visible face material"):
			return true
		CharacterBuilder.set_expression(chars[1], "open")
		CharacterBuilder.set_opacity(chars[1], 1.0)
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
	if phase_task4 and frames == 445:
		_task4_check_readd()
	return false


# --- Task 4: tư thế tĩnh (pose) + bake thân rigged; thời gian dựng ------------------------
func _task4_start() -> void:
	phase_task4 = true
	# GameFX._ready (chạy sau _initialize) áp lại phong cách đã lưu trong settings.cfg: ép lại chế độ vice để pha này không phụ thuộc
	# phong cách mà máy đang lưu
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	static_c = CharacterBuilder.build({"preset": "student", "seed": 77, "animate": false})
	static_c.position = Vector3(0.0, 0.0, 4.0)
	world.add_child(static_c)
	CharacterBuilder.pose(static_c, "sit", 0.0)
	# pose() NGOÀI cây rồi mới add_child (dựng cảnh trước khi gắn vào cây): xương phải giữ tư thế khi vào cây
	static_out = CharacterBuilder.build({"preset": "student", "seed": 78, "animate": false})
	static_out.position = Vector3(1.5, 0.0, 4.0)
	CharacterBuilder.pose(static_out, "sit", 0.0)
	world.add_child(static_out)
	# nhân vật có RigAnimator rời cây rồi vào lại (_ready không chạy lại): clip tự dựng kế tiếp vẫn phải chạy
	readd_c = chars[2]
	world.remove_child(readd_c)
	world.add_child(readd_c)
	CharacterBuilder.play(readd_c, "sit")
	# _apply_bone_pose gọi thẳng trên thân NGOÀI cây (không qua pose()): tư thế toàn cục của xương phải theo ngay
	var loose: Node3D = CharacterBuilder.build({"preset": "student", "seed": 79, "animate": false})
	var lsk: Skeleton3D = loose.get_meta("skeleton") as Skeleton3D
	var kb: int = lsk.find_bone("LowerLeg.L")
	var knee0: Vector3 = lsk.get_bone_global_pose(kb).origin
	CharacterBuilder._apply_bone_pose(lsk, {"thigh_l": Vector3(1.4, 0.0, 0.0)}, 1.0)
	var moved: float = lsk.get_bone_global_pose(kb).origin.distance_to(knee0)
	loose.free()
	print("  out-of-tree _apply_bone_pose: knee moved %.2f" % moved)
	_check(moved > 0.2, "_apply_bone_pose on a body outside the tree must update its global bone poses (knee moved %.3f)" % moved)


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
			# mốc: khoảng gối -> bàn chân ở tư thế đứng gốc (_neutral_base; rest glTF khi thân không có gốc)
			var nb: Dictionary = CharacterBuilder._base_of(sk)
			var d_rest: float = CharacterBuilder._base_global(sk, nb, kb).origin.distance_to(CharacterBuilder._base_global(sk, nb, fb).origin)
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
	# Đơn vị hệ gốc nhân vật (chưa nhân root.scale) không phụ thuộc chiều cao ngẫu nhiên: ngồi 1.357 (nam) / 1.334 (nữ) trên
	# 10 seed, đứng 1.779 / 1.787. Dải 1.1..1.45 nằm hẳn dưới chiều cao đứng và trên một tư thế sụp (hông hạ hai lần ~1.12).
	if not _check(ab.size.y > 1.1 and ab.size.y < 1.45, "baked rider must be seated (height %.2f, expected 1.1..1.45 root units)" % ab.size.y):
		return
	# Mốc: dựng lại đúng người đó (cùng opts với build_baked_rider), tư thế ride, so với AABB đã bake
	var r: Node3D = CharacterBuilder.build({"preset": "rider", "seed": 5, "animate": false, "rigged": true})
	CharacterBuilder.pose(r, "ride", 0.0, {"ride_shoulder": 1.15, "ride_elbow": 0.3, "ride_lean": 0.42, "lean": 0.0})
	if not _check(CharacterBuilder.bake(r).get_aabb().is_equal_approx(ab), "rebuilding the seed-5 rider must bake the same mesh as build_baked_rider"):
		r.free()
		return
	var rsk: Skeleton3D = r.get_meta("skeleton") as Skeleton3D
	var to_root: Transform3D = CharacterBuilder._local_xform(rsk, r)
	var foot_y: float = INF
	for s: String in ["L", "R"]:
		foot_y = minf(foot_y, (to_root * rsk.get_bone_global_pose(rsk.find_bone("Foot." + s)).origin).y)
	var top_y: float = CharacterBuilder._local_xform(CharacterBuilder.head_top(r), r, rsk).origin.y
	var d_bottom: float = ab.position.y - foot_y
	var d_top: float = ab.end.y - top_y
	print("  baked rider landmarks: bottom - lowest Foot bone %.3f, top - head_top %.3f" % [d_bottom, d_top])
	# đế giày nằm dưới gốc xương Foot (2.4 cm ở tư thế nghỉ, thêm ~2 cm do bàn chân chúc khi ngồi xe: đo 4.1..4.4 cm);
	# giới hạn 8 cm = gấp đôi số đo, còn giày không theo xương (vd phần skinned ở tư thế nghỉ) lệch ~16 cm
	if not _check(d_bottom > -0.08 and d_bottom < 0.01, "baked rider bottom must sit just under the lowest Foot bone (%.3f, expected -0.08..0.01)" % d_bottom):
		r.free()
		return
	# head_top ở 0.27 trên pivot đầu (đỉnh đầu 0.235), vòm mũ bảo hiểm cao ~0.258 -> đỉnh mesh dưới head_top ~1.3 cm x 1.06
	# (đo 1.7 cm); 5 cm vẫn bắt được đầu thiếu / lệch chỗ (lệch >= 20 cm)
	if not _check(absf(d_top) < 0.05, "baked rider top must sit near head_top (%.3f, expected within 0.05)" % d_top):
		r.free()
		return
	# Hai gối người ngồi xe gần đối xứng: rest Quaternius là thế đứng 3/4 (chân phải bước trước) nên trước khi có tư thế gốc
	# trung tính (_neutral_base) gối phải cao hơn gối trái 0,15 m; còn lại ~0,08 m trước / sau do hông xoay 27° (giữ nguyên)
	var kl: Vector3 = (to_root * rsk.get_bone_global_pose(rsk.find_bone("LowerLeg.L")).origin) * r.scale.x
	var kr: Vector3 = (to_root * rsk.get_bone_global_pose(rsk.find_bone("LowerLeg.R")).origin) * r.scale.x
	print("  baked rider knees L-R: dy %.3f m, dz %.3f m" % [kl.y - kr.y, kl.z - kr.z])
	if not _check(absf(kl.y - kr.y) < 0.05 and absf(kl.z - kr.z) < 0.1, "the ride pose must put the knees roughly level (L-R dy %.3f, dz %.3f m)" % [kl.y - kr.y, kl.z - kr.z]):
		r.free()
		return
	# Bake lần nữa cùng người, clip "": phải đứng (đế giày ở y 0, cao 1.70..1.86 = 1.78 +- 4 %). Cũng chứng minh khoá cache skin
	# gồm tư thế: cache bỏ qua tư thế sẽ trả phần thân ngồi (đáy 0.12, cao ~1.66)
	CharacterBuilder.pose(r, "", 0.0)
	var st: AABB = CharacterBuilder.bake(r).get_aabb()
	r.free()
	print("  same rider baked at clip \"\": height %.3f, bottom %.3f" % [st.size.y, st.position.y])
	if not _check(st.size.y > 1.70 and st.size.y < 1.86 and absf(st.position.y) < 0.03, "the same rider baked at clip \"\" must stand (height %.3f, bottom %.3f)" % [st.size.y, st.position.y]):
		return
	# Tư thế đứng tĩnh ("" và "phone_stand", không đụng chân) trên thân nam và nữ: hai bàn chân ngang nhau, lệch trước / sau
	# < 0,1 m (rest Quaternius lệch ~0,35 m: chân phải bước trước)
	for preset: String in ["student_m", "student_f"]:
		var sc: Node3D = CharacterBuilder.build({"preset": preset, "seed": 11, "animate": false, "rigged": true})
		var ssk: Skeleton3D = sc.get_meta("skeleton") as Skeleton3D
		var s_root: Transform3D = CharacterBuilder._local_xform(ssk, sc)
		for clip: String in ["", "phone_stand"]:
			CharacterBuilder.pose(sc, clip, 0.0)
			var fl: Vector3 = (s_root * CharacterBuilder._bone_global_now(ssk, ssk.find_bone("Foot.L")).origin) * sc.scale.x
			var fr: Vector3 = (s_root * CharacterBuilder._bone_global_now(ssk, ssk.find_bone("Foot.R")).origin) * sc.scale.x
			if clip == "":
				print("  %s standing feet L-R: dz %.3f m, dy %.3f m" % [preset, fl.z - fr.z, fl.y - fr.y])
			if not _check(absf(fl.z - fr.z) < 0.1 and absf(fl.y - fr.y) < 0.02, "%s pose('%s') must stand with the feet level (L-R dz %.3f, dy %.3f m)" % [preset, clip, fl.z - fr.z, fl.y - fr.y]):
				sc.free()
				return
		sc.free()


func _task4_check_readd() -> void:
	var hy: float = CharacterBuilder.get_pivot(readd_c, "hips").global_position.y
	print("  animated body removed and re-added, playing sit: hips y %.2f" % hy)
	if not _check(hy < 0.62, "a rigged character removed from the tree and added back must still play code clips (hips y %.2f)" % hy):
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


## Tên MeshInstance3D (đang hiện) đầu tiên có vật liệu mang next_pass (viền toon cổ điển); "" nếu không có.
func _outlined_material(c: Node3D) -> String:
	for mi: MeshInstance3D in CharacterBuilder._mesh_instances(c):
		if mi.mesh == null or not mi.visible:
			continue
		for si: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(si)
			if m and m.next_pass != null:
				return String(mi.name)
	return ""


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
