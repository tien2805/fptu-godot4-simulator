# File: res://tests/test_crowd_impostors.gd
# Test headless tầng xa của đám đông FreeRoam (CrowdImpostors, plan Task 11): 24 biến thể cố định (3 khu x 8), clip tĩnh
# "stride" (hai gối tách trước / sau), mỗi biến thể bake thành người cao 1,3-2,0 m với một MultiMesh cỡ bằng trần, người
# nộm trượt theo cạnh đồ thị, số instance hiện = số người nộm, take_within (gần trước, giữ danh tính), remove_where,
# remove_farthest, trần.
# Chạy:  godot --headless --path . --script tests/test_crowd_impostors.gd
extends SceneTree

var done: bool = false


func _initialize() -> void:
	CharacterBuilder.ps2 = true      # mặc định của game là vice (người PS2); test --script không có GameFX
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	if not _variants_ok() or not _stride_ok() or not _crowd_ok():
		return
	print("✅ SUCCESS: CROWD IMPOSTORS")
	done = true
	quit(0)


func _variants_ok() -> bool:
	var vs: Array = CrowdImpostors.variants()
	if not _check(vs.size() == 24, "24 crowd variants (got %d)" % vs.size()):
		return false
	var students_campus: int = 0
	var females: int = 0
	for i: int in range(vs.size()):
		var v: Dictionary = vs[i]
		var zone_want: int = int(float(i) / float(CrowdImpostors.VARIANTS_PER_ZONE))
		if not _check(int(v["v"]) == i and int(v["zone"]) == zone_want, "variant %d has v %d zone %d" % [i, int(v["v"]), int(v["zone"])]):
			return false
		if int(v["zone"]) == PedWalkGraph.ZONE_CAMPUS and String(v["preset"]) == "student":
			students_campus += 1
		if bool(v["female"]):
			females += 1
	if not _check(students_campus == 7 and females == 12, "campus: 7 student variants (got %d); 12 female variants (got %d)" % [students_campus, females]):
		return false
	return _check(str(CrowdImpostors.variants()) == str(vs), "variants() returns the same table every call")


func _stride_ok() -> bool:
	var rig: Node3D = CharacterBuilder.build({"preset": "student", "seed": 3, "rigged": true, "animate": false})
	var sk: Skeleton3D = rig.get_meta("skeleton", null) as Skeleton3D
	if not _check(sk != null, "a rigged body exposes its skeleton (meta 'skeleton')"):
		return false
	# Mốc là tư thế đứng tĩnh pose("") (gốc trung tính _neutral_base: hai bàn chân ngang nhau; rest glTF thì chân phải bước
	# trước ~0,36 đơn vị mô hình). "stride" đưa chân TRÁI ra trước (+Z, mô hình nhìn +Z), chân phải ra sau.
	CharacterBuilder.pose(rig, "")
	var fl0: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("Foot.L")).origin
	var fr0: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("Foot.R")).origin
	CharacterBuilder.pose(rig, "stride")
	var kl: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg.L")).origin
	var kr: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("LowerLeg.R")).origin
	var fl: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("Foot.L")).origin
	var fr: Vector3 = CharacterBuilder._bone_global_now(sk, sk.find_bone("Foot.R")).origin
	rig.free()
	print("  stride: foot L-R along Z %.2f (rest %.2f), knee L-R %.2f (model units)" % [fl.z - fr.z, fl0.z - fr0.z, kl.z - kr.z])
	return _check(absf(fl0.z - fr0.z) < 0.1 and fl.z - fr.z > 0.5 and kl.z - kr.z > 0.2, "the stride pose puts the left leg forward and the right leg back from a level stand (foot L-R %.2f, stand %.2f, knee L-R %.2f)" % [fl.z - fr.z, fl0.z - fr0.z, kl.z - kr.z])


func _crowd_ok() -> bool:
	var line := PackedVector2Array()
	for i: int in range(21):
		line.append(Vector2(-60.0 + float(i) * 6.0, 7000.0))
	var g: PedWalkGraph = PedWalkGraph.from_lines([line])
	var imp := CrowdImpostors.new()
	root.add_child(imp)
	imp.setup(g, {"cap": 40, "seed": 5})
	print("  baked 24 variants in %d ms" % imp.bake_ms)
	if not _check(imp.bake_ms < 8000, "baking 24 variants must take < 8 s headless (took %d ms)" % imp.bake_ms):
		return false
	for v: int in range(24):
		var m: ArrayMesh = imp.variant_mesh(v)
		var h: float = m.get_aabb().size.y * imp.variant_scale(v).y if m else 0.0
		# nữ thấp hơn (hệ số 0,88-1,01) và tư thế sải chân nhấc hai bàn chân ~0,1 m: 1,3-2,0 m
		if not _check(m != null and m.get_surface_count() > 0 and h > 1.3 and h < 2.0, "variant %d bakes a 1.3-2.0 m person (height %.2f)" % [v, h]):
			return false
		if not _check(imp.multimesh(v).mesh == m and imp.multimesh(v).instance_count == 40, "variant %d: one MultiMesh sized to the cap" % v):
			return false
	var vs: Array = CrowdImpostors.variants()
	if not _check(not imp.add({"wid": 1, "identity": {"v": 99}, "node": 1, "prev": 0, "pos": g.node_pos(0), "speed": 1.0}), "add() refuses an unknown variant"):
		return false
	for k: int in range(30):
		var ident: Dictionary = (vs[k % 24] as Dictionary).duplicate()
		ident["wid"] = 100 + k
		var node: int = 2 + (k % 17)
		if not _check(imp.add({"wid": 100 + k, "identity": ident, "node": node + 1, "prev": node, "pos": g.node_pos(node), "speed": 1.3}), "add() below the cap"):
			return false
	var start: PackedVector3Array = imp.positions().duplicate()   # mảng đóng gói dùng chung tham chiếu: phải chép
	imp.step(1.0)
	imp.step(1.0)
	var moved_ok: int = 0
	for i: int in range(imp.count()):
		var p: Vector3 = imp.positions()[i]
		if not _check(absf(p.z - 7000.0) < 0.01, "impostor %d left the walk line (z %.2f)" % [i, p.z]):
			return false
		if absf(p.distance_to(start[i]) - 2.6) < 0.05:
			moved_ok += 1
	if not _check(moved_ok == 30, "every impostor glides 2.6 m in 2 s at 1.3 m/s (%d / 30)" % moved_ok):
		return false
	imp.flush()
	var vis: int = 0
	for v2: int in range(24):
		vis += imp.multimesh(v2).visible_instance_count
	if not _check(vis == 30, "visible instances %d == impostors 30" % vis):
		return false
	var center := Vector3(0.0, 0.0, 7000.0)
	var before: int = imp.count()
	var got: Array = imp.take_within(center, 20.0, 5)
	var last_d: float = -1.0
	for st: Dictionary in got:
		var d: float = (st["pos"] as Vector3).distance_to(center)
		if not _check(d <= 20.0 and d >= last_d, "take_within returns states within 20 m, closest first (%.1f after %.1f)" % [d, last_d]):
			return false
		last_d = d
		var w: int = int(st["wid"])
		if not _check(w == int((st["identity"] as Dictionary)["wid"]) and imp.wids().find(w) < 0, "a taken impostor keeps its identity and leaves the crowd (wid %d)" % w):
			return false
	if not _check(got.size() == 5 and imp.count() == before - 5, "take_within took 5 (got %d), count %d -> %d" % [got.size(), before, imp.count()]):
		return false
	var only_east: Array = imp.take_within(center, 60.0, 3, func(q: Vector3) -> bool: return q.x > 0.0)
	for st2: Dictionary in only_east:
		if not _check((st2["pos"] as Vector3).x > 0.0, "take_within with a predicate returned an impostor at x %.1f" % (st2["pos"] as Vector3).x):
			return false
	var cut: int = imp.remove_where(func(q: Vector3) -> bool: return q.x > 30.0)
	for q2: Vector3 in imp.positions():
		if not _check(q2.x <= 30.0, "remove_where left an impostor at x %.1f" % q2.x):
			return false
	var far_before: float = 0.0
	for q3: Vector3 in imp.positions():
		far_before = maxf(far_before, q3.distance_to(center))
	var n_before: int = imp.count()
	imp.remove_farthest(center, 3)
	var far_after: float = 0.0
	for q4: Vector3 in imp.positions():
		far_after = maxf(far_after, q4.distance_to(center))
	print("  remove_where cut %d; remove_farthest: %d -> %d, farthest %.1f -> %.1f m" % [cut, n_before, imp.count(), far_before, far_after])
	if not _check(imp.count() == n_before - 3 and far_after < far_before, "remove_farthest removes the 3 farthest"):
		return false
	while imp.count() < 40:
		imp.add({"wid": 999, "identity": vs[0], "node": 1, "prev": 0, "pos": g.node_pos(0), "speed": 1.0})
	if not _check(not imp.add({"wid": 1000, "identity": vs[0], "node": 1, "prev": 0, "pos": g.node_pos(0), "speed": 1.0}), "add() refuses beyond the cap"):
		return false
	imp.queue_free()
	return true


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
