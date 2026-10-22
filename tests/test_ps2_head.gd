# File: res://tests/test_ps2_head.gd
# Test headless PS2Head: số tam giác (250..400), kích thước, chiều quấn mặt hướng ra ngoài, UV mặt trước / sau đầu, đỉnh hàn
# bit-chính-xác trên kinh tuyến, nếp hàm và pháp tuyến hai mặt của tai, mọi kiểu tóc bao đỉnh đầu, VỎ tóc không chìm vào và không
# đâm xuyên da đầu (5 bộ k), build() ghi rig + vật liệu RIÊNG một ô atlas, 8 ô biểu cảm, lưới đầu dùng chung giữa các nhân vật
# gần giống nhau, kính, mũ lưỡi trai / mũ bảo hiểm / mũ đầu bếp dựng trong nút HatFit (mũ bảo hiểm không che mắt).
# Chạy:  godot --headless --path . --script tests/test_ps2_head.gd
extends SceneTree

const CELL_NAMES: Array[String] = ["open", "closed", "happy", "angry", "surprised", "done", "talk", "pain"]
## Bộ k (w, jaw, nose) cho kiểm tra vỏ tóc - đầu: chuẩn, hai cực thô của build() (nữ hẹp nhất, nam rộng nhất) và hai cực của
## lưới lượng tử 0.04 mà build() thực sự đưa cho head_mesh().
const SHELL_KS: Array = [
	{"w": 1.0, "jaw": 1.0, "nose": 1.0},
	{"w": 0.89, "jaw": 0.85, "nose": 0.75},
	{"w": 1.06, "jaw": 1.06, "nose": 1.12},
	{"w": 0.88, "jaw": 0.84, "nose": 0.76},
	{"w": 1.08, "jaw": 1.08, "nose": 1.12},
]

var done: bool = false


func _initialize() -> void:
	var k: Dictionary = {"w": 1.0, "jaw": 1.0, "nose": 1.0}
	var mesh: ArrayMesh = PS2Head.head_mesh(k)
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tris: int = idx.size() / 3
	print("  head: %d triangles, %d vertices" % [tris, verts.size()])
	if not _check(tris >= 250 and tris <= 400, "head must have 250..400 triangles (got %d)" % tris):
		return
	var ab: AABB = mesh.get_aabb()
	print("  head aabb: ", ab)
	if not _check(absf(ab.size.y - PS2Head.HEAD_H) < 0.012, "head height must be ~0.235 m (got %.3f)" % ab.size.y):
		return
	if not _check(ab.size.x > 0.15 and ab.size.x < 0.2, "head width must be 0.15..0.2 m incl. ears (got %.3f)" % ab.size.x):
		return
	if not _check(ab.position.z < -0.115, "nose must stick out in front (aabb front z %.3f)" % ab.position.z):
		return
	# winding: (c - a) x (b - a) points outward for at least 95 % of triangles (Godot front faces are clockwise)
	var outward: int = 0
	for t: int in range(tris):
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var cen: Vector3 = (a + b + c) / 3.0
		var out: Vector3 = cen - Vector3(0.0, 0.12, 0.0)
		if (c - a).cross(b - a).dot(out) >= -0.0000001:
			outward += 1
	if not _check(float(outward) / float(tris) >= 0.95, "only %d of %d triangles face outward" % [outward, tris]):
		return
	# UV: the front vertex nearest the eye line maps near (0.5, 0.468); the back of the head maps to a skin border column
	var front_uv := Vector2(-1.0, -1.0)
	var back_ok: bool = true
	var best: float = 99.0
	for i: int in range(verts.size()):
		var p: Vector3 = verts[i]
		var d: float = Vector2(p.x, p.y - 0.125).length() if p.z < -0.05 else 99.0
		if d < best:
			best = d
			front_uv = uvs[i]
		if p.z > 0.09 and p.y > 0.08 and p.y < 0.2 and uvs[i].x > 0.03 and uvs[i].x < 0.97:
			back_ok = false
	print("  front uv ", front_uv)
	if not _check(absf(front_uv.x - 0.5) < 0.03 and absf(front_uv.y - (1.0 - 0.125 / 0.235)) < 0.08, "front vertex uv must be near (0.5, 0.47), got %s" % front_uv):
		return
	if not _check(back_ok, "back-of-head vertices must map to a skin border column (u < 0.03 or u > 0.97)"):
		return
	# kinh tuyến hàn bit-chính-xác: không có hai đỉnh gần nhau < 1e-5 mà khác nhau (nếu không pháp tuyến nhảy 9..21 độ dọc kinh tuyến)
	var exact: Dictionary = {}
	var cells: Dictionary = {}
	for v: Vector3 in verts:
		exact[v] = true
		cells[Vector3i(roundi(v.x * 100000.0), roundi(v.y * 100000.0), roundi(v.z * 100000.0))] = true
	if not _check(exact.size() == cells.size(), "near-duplicate vertices (%d exact vs %d cells): seam vertices must weld bit-exactly" % [exact.size(), cells.size()]):
		return
	# nếp hàm: mỗi đỉnh trên vành y 0.05 có hai pháp tuyến khác nhau (dải dưới hàm + cằm là nhóm làm mượt riêng)
	var rim: Dictionary = {}
	for i: int in range(verts.size()):
		if absf(verts[i].y - 0.05) < 0.0001:
			if not rim.has(verts[i]):
				rim[verts[i]] = []
			(rim[verts[i]] as Array).append(norms[i])
	var creased: int = 0
	for pos: Vector3 in rim.keys():
		var ns: Array = rim[pos]
		var spread: float = 0.0
		for na: Vector3 in ns:
			for nb: Vector3 in ns:
				spread = maxf(spread, rad_to_deg(na.angle_to(nb)))
		if spread > 4.0:
			creased += 1
	if not _check(creased >= 12, "jaw line must be a normal crease at y 0.05 (only %d of %d rim positions)" % [creased, rim.size()]):
		return
	# tai hai mặt: mỗi đỉnh tai có pháp tuyến ra ngoài HOẶC vào trong (hai bản sao khác nhóm làm mượt), không bị triệt tiêu
	var ear_out: int = 0
	var ear_in: int = 0
	var ear_bad: int = 0
	for i: int in range(verts.size()):
		if absf(verts[i].x) > 0.0805:
			var nx: float = norms[i].x * signf(verts[i].x)
			if nx > 0.9:
				ear_out += 1
			elif nx < -0.9:
				ear_in += 1
			else:
				ear_bad += 1
	if not _check(ear_bad == 0 and ear_out >= 8 and ear_in >= 8, "ear plates need opposite outer/inner normals (out %d, in %d, other %d)" % [ear_out, ear_in, ear_bad]):
		return
	for style: String in PS2Head.HAIR_STYLES:
		var hm: ArrayMesh = PS2Head.hair_mesh(style, k)
		var hab: AABB = hm.get_aabb()
		var ht: int = hm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3 if hm.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == null else hm.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		if not _check(ht > 20 and hab.end.y >= PS2Head.HEAD_H, "hair %s must cover the crown (%d tris, top %.3f)" % [style, ht, hab.end.y]):
			return
	# vỏ tóc không chìm vào da đầu và không bị đầu (tai) đâm xuyên: bộ k chuẩn + các cực; bỏ gai / búi / đuôi ngựa (cố ý cắm vào đầu)
	for sk: Dictionary in SHELL_KS:
		var head_tris: Array = _mesh_tris(PS2Head.head_mesh(sk))
		var head_boxes: Array = []
		for htri: Array in head_tris:
			head_boxes.append(_tri_box(htri))
		for style: String in PS2Head.HAIR_STYLES:
			var problem: String = _shell_problem(style, sk, head_tris, head_boxes)
			if not _check(problem == "", problem):
				return
	print("  hair shells clear of the head skin: %d styles x %d k sets" % [PS2Head.HAIR_STYLES.size(), SHELL_KS.size()])
	# build(): rig keys, face material on one atlas cell, glasses, cell offsets
	var holder := Node3D.new()
	root.add_child(holder)
	var rig: Dictionary = {}
	var head_opts: Dictionary = {"skin": 2, "female": true, "variant": 1, "hair_style": "ponytail", "hair_color": 1, "seed": 7, "outfit": {"glasses": true}}
	var head: Node3D = PS2Head.build(holder, Vector3.ZERO, head_opts, rig)
	if not _check(head != null and head.name == "Head" and bool(head.get_meta("ps2_head", false)), "build() returns the Head pivot with meta ps2_head"):
		return
	for key: String in ["head", "face_mesh", "head_top"]:
		if not _check(rig.has(key), "rig[%s] missing" % key):
			return
	var fm: StandardMaterial3D = (rig["face_mesh"] as MeshInstance3D).material_override as StandardMaterial3D
	if not _check(fm != null and bool(fm.get_meta("ps2_face", false)) and fm.uv1_scale.is_equal_approx(Vector3(0.25, 0.5, 1.0)), "face material samples one atlas cell"):
		return
	# mỗi build() có vật liệu mặt RIÊNG (cùng atlas, khác thực thể): đổi ô biểu cảm của người này không ảnh hưởng người kia
	var rig_b: Dictionary = {}
	PS2Head.build(_fresh_parent(), Vector3.ZERO, head_opts, rig_b)
	var fm_b: StandardMaterial3D = (rig_b["face_mesh"] as MeshInstance3D).material_override as StandardMaterial3D
	if not _check(fm_b != null and fm_b != fm and fm_b.albedo_texture == fm.albedo_texture, "each build() must get its OWN face material (same atlas texture, different instance)"):
		return
	fm.uv1_offset = PS2Head.cell_offset("pain")
	if not _check(fm_b.uv1_offset.is_equal_approx(Vector3.ZERO), "switching one character's face cell must not change another's"):
		return
	fm.uv1_offset = PS2Head.cell_offset("open")
	# 8 ô biểu cảm theo đúng thứ tự atlas 4 x 2
	if not _check(PS2Head.CELLS == CELL_NAMES, "cell names must follow the atlas order %s" % [CELL_NAMES]):
		return
	var offsets: Array = [Vector3(0.0, 0.0, 0.0), Vector3(0.25, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.75, 0.0, 0.0),
			Vector3(0.0, 0.5, 0.0), Vector3(0.25, 0.5, 0.0), Vector3(0.5, 0.5, 0.0), Vector3(0.75, 0.5, 0.0)]
	for i: int in range(CELL_NAMES.size()):
		if not _check(PS2Head.cell_offset(CELL_NAMES[i]).is_equal_approx(offsets[i]), "cell offset of %s must be %s (got %s)" % [CELL_NAMES[i], offsets[i], PS2Head.cell_offset(CELL_NAMES[i])]):
			return
	if not _check(PS2Head.cell_offset("no_such_cell").is_equal_approx(Vector3.ZERO), "an unknown cell name falls back to open"):
		return
	if not _check(head.get_node_or_null("Hair") != null, "hair mesh node missing"):
		return
	var n_mi: int = 0
	for ch: Node in head.get_children():
		if ch is MeshInstance3D:
			n_mi += 1
	if not _check(n_mi >= 10, "glasses must add frame parts (only %d mesh instances under Head)" % n_mi):
		return
	# kính: gọng (4 thanh) bắt đầu ở mép ngoài khung, chạy ra tai, không xuyên vào đầu; ba bề ngang trên lưới 0.04 (w = width khi nam)
	var glass_mat: Material = CharacterBuilder._mat("ps2_glasses", Color("#16161A"), 0.4, 0.3)
	for gw: float in [0.88, 1.0, 1.08]:
		var rg: Dictionary = {}
		var gh: Node3D = PS2Head.build(_fresh_parent(), Vector3.ZERO, {"width": gw, "female": false, "seed": 2, "outfit": {"glasses": true}}, rg)
		var gtris: Array = _mesh_tris((rg["face_mesh"] as MeshInstance3D).mesh as ArrayMesh)
		var arms: int = 0
		var arm_in: int = 0
		var front := Vector3(0.0, 0.0, 99.0)
		var rear_z: float = -99.0
		for ch: Node in gh.get_children():
			var arm := ch as MeshInstance3D
			if arm == null or arm.material_override != glass_mat or not (arm.mesh is BoxMesh) or (arm.mesh as BoxMesh).size.z < 0.03:
				continue
			arms += 1
			var half: float = (arm.mesh as BoxMesh).size.z * 0.5
			for t: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var q: Vector3 = arm.position + arm.basis.z * (t * half)
				if _inside(q, gtris):
					arm_in += 1
				if t == -1.0 or t == 1.0:
					if q.z < front.z:
						front = q
					rear_z = maxf(rear_z, q.z)
		var frame_edge: float = 0.032 * gw + 0.016
		if not _check(arms == 4 and arm_in == 0 and absf(absf(front.x) - frame_edge) < 0.002 and rear_z >= 0.01, "glasses arms (w %s): %d arms, %d samples inside the head, front |x| %.4f vs frame edge %.4f, rear z %.3f" % [gw, arms, arm_in, absf(front.x), frame_edge, rear_z]):
			return
	# lượng tử hoá k (0.04): nhân vật gần giống nhau dùng chung MỘT lưới đầu (cache có giới hạn)
	var rig_c: Dictionary = {}
	var rig_d: Dictionary = {}
	PS2Head.build(_fresh_parent(), Vector3.ZERO, {"seed": 11, "width": 1.0}, rig_c)
	PS2Head.build(_fresh_parent(), Vector3.ZERO, {"seed": 11, "width": 1.012}, rig_d)
	if not _check((rig_c["face_mesh"] as MeshInstance3D).mesh == (rig_d["face_mesh"] as MeshInstance3D).mesh, "k must snap to 0.04 steps so near-identical characters share one head mesh"):
		return
	# mọi kiểu tóc qua build() (nam + nữ)
	for style: String in PS2Head.HAIR_STYLES:
		for female: bool in [false, true]:
			var rs: Dictionary = {}
			var hs: Node3D = PS2Head.build(_fresh_parent(), Vector3.ZERO, {"hair_style": style, "female": female, "seed": 3}, rs)
			if not _check(hs.get_node_or_null("Hair") != null and hs.get_node_or_null("HatFit") == null and rs.has("head_top"), "build() with hair style %s (female %s)" % [style, female]):
				return
	# mũ đầu bếp / mũ lưỡi trai: mũ của bộ dựng cũ nằm trong nút HatFit (thu nhỏ vào đầu PS2), không có vỏ tóc
	var rig2: Dictionary = {}
	var chef: Node3D = PS2Head.build(_fresh_parent(), Vector3.ZERO, {"skin": 0, "seed": 3, "outfit": {"chef_hat": true}}, rig2)
	var chef_fit: Node3D = chef.get_node_or_null("HatFit") as Node3D
	if not _check(chef.get_node_or_null("Hair") == null and chef_fit != null and chef_fit.get_child_count() >= 4 and absf(chef_fit.position.y) < 0.0001, "chef hat path builds the hat under HatFit instead of the hair shell"):
		return
	var rig3: Dictionary = {}
	var cap: Node3D = PS2Head.build(_fresh_parent(), Vector3.ZERO, {"skin": 1, "seed": 4, "outfit": {"cap": true, "cap_color": Color("#1C2A4A")}}, rig3)
	var cap_fit: Node3D = cap.get_node_or_null("HatFit") as Node3D
	if not _check(cap.get_node_or_null("Hair") == null and cap_fit != null and cap_fit.get_child_count() >= 4 and absf(cap_fit.position.y) < 0.0001 and rig3.has("head_top"), "cap path builds the cap under HatFit instead of the hair shell"):
		return
	# phần mũ (trừ khối tóc gáy cuối cùng, cố ý chìm trong đầu) không được lún vào sọ: lún = z-fight (vệt xanh / đen trên mũ)
	for pair: Array in [["chef", chef_fit, rig2], ["cap", cap_fit, rig3]]:
		var sinks: int = _hat_sink_count(pair[1] as Node3D, _mesh_tris((pair[2]["face_mesh"] as MeshInstance3D).mesh as ArrayMesh))
		if not _check(sinks == 0, "%s parts under HatFit sink into the skull (%d vertices inside)" % [pair[0], sinks]):
			return
	# mũ bảo hiểm: HatFit nâng lên, vỏ tóc vẫn nằm dưới mũ, kính ở trên Head; vành và tấm che không được che mắt (mắt y 0.116..0.134)
	var rig4: Dictionary = {}
	var rider: Node3D = PS2Head.build(_fresh_parent(), Vector3.ZERO, {"skin": 3, "seed": 5, "hair_style": "bob", "female": true, "outfit": {"helmet": true, "helmet_color": Color("#E74C3C"), "glasses": true}}, rig4)
	var rider_fit: Node3D = rider.get_node_or_null("HatFit") as Node3D
	if not _check(rider_fit != null and rider_fit.position.y > 0.03 and rider.get_node_or_null("Hair") != null and rider_fit.get_child_count() >= 3, "helmet path builds the helmet under a lifted HatFit and keeps the hair shell"):
		return
	var low: float = _helmet_low_y(rider_fit)
	print("  helmet lowest non-strap point y %.3f" % low)
	if not _check(low >= 0.14, "helmet rim / visor must sit above the eyes (lowest non-strap point y %.3f, eyes up to 0.134)" % low):
		return
	# vòm sát sọ (không còn là cái xô: đỉnh đầu 0.235, bề ngang sọ 0.079), không còn quai cũ trong HatFit
	var dome: MeshInstance3D = null
	var old_straps: int = 0
	for ch: Node in rider_fit.get_children():
		var part := ch as MeshInstance3D
		if part != null and part.mesh is SphereMesh and dome == null:
			dome = part
		if part != null and part.mesh is BoxMesh and (part.mesh as BoxMesh).size.y >= 0.1:
			old_straps += 1
	if not _check(dome != null and old_straps == 0, "helmet needs its dome and no old floating straps under HatFit (old straps %d)" % old_straps):
		return
	var dome_box: AABB = (rider_fit.transform * dome.transform) * dome.mesh.get_aabb()
	var dome_x: float = maxf(absf(dome_box.position.x), absf(dome_box.end.x))
	print("  helmet dome: top y %.3f, half-width %.3f" % [dome_box.end.y, dome_x])
	if not _check(dome_box.end.y <= 0.27 and dome_x <= 0.095, "helmet dome must hug the skull (top y %.3f <= 0.27, half-width %.3f <= 0.095)" % [dome_box.end.y, dome_x]):
		return
	# quai mới (dựng trong hệ đầu) nằm ngoài da và chạm tới cằm: điểm thấp nhất <= y 0.0, không điểm nào trong đầu
	var rider_tris: Array = _mesh_tris((rig4["face_mesh"] as MeshInstance3D).mesh as ArrayMesh)
	var strap_low: float = 99.0
	var strap_in: int = 0
	var strap_mat: Material = CharacterBuilder._mat("helmet_strap", Color("#222222"), 0.8)
	for ch: Node in rider.get_children():
		var bar := ch as MeshInstance3D
		if bar == null or bar.material_override != strap_mat:
			continue
		var half: float = (bar.mesh as BoxMesh).size.z * 0.5
		for t: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var q: Vector3 = bar.position + bar.basis.z * (t * half)
			strap_low = minf(strap_low, q.y)
			if _inside(q, rider_tris):
				strap_in += 1
	print("  helmet straps: lowest point y %.3f, samples inside the head %d" % [strap_low, strap_in])
	if not _check(strap_low <= 0.0 and strap_in == 0, "helmet straps must reach the chin (low y %.3f <= 0) and stay outside the skin (%d samples inside)" % [strap_low, strap_in]):
		return
	# tóc dưới mũ bảo hiểm không được đâm xuyên vòm / vành (vệt đen lởm chởm sau gáy): bob / dài / undercut phồng nhất, và hai cực bề ngang
	for style: String in ["long", "undercut", "spiky"]:
		for combo: Array in [[0.94, true], [1.0, false], [1.06, false]]:
			var hh: Node3D = PS2Head.build(_fresh_parent(), Vector3.ZERO, {"hair_style": style, "width": combo[0], "female": combo[1], "seed": 9, "outfit": {"helmet": true}}, {})
			var poking: int = _hair_through_helmet(hh)
			if not _check(poking == 0, "hair under the helmet (%s, width %s) pokes through the dome / rim at %d vertices" % [style, combo[0], poking]):
				return
	print("✅ SUCCESS: PS2 HEAD MESH, UV, NORMALS, HAIR SHELLS, CELLS, MATERIALS, HATS AND ACCESSORIES OK")
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok


func _fresh_parent() -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	return n


## Các tam giác [a, b, c] của surface 0 (có hoặc không có index).
func _mesh_tris(mesh: ArrayMesh) -> Array:
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var out: Array = []
	if arr[Mesh.ARRAY_INDEX] == null:
		for t: int in range(verts.size() / 3):
			out.append([verts[t * 3], verts[t * 3 + 1], verts[t * 3 + 2]])
	else:
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t: int in range(idx.size() / 3):
			out.append([verts[idx[t * 3]], verts[idx[t * 3 + 1]], verts[idx[t * 3 + 2]]])
	return out


func _tri_box(tr: Array) -> AABB:
	var box := AABB(tr[0], Vector3.ZERO)
	return box.expand(tr[1]).expand(tr[2]).grow(0.0005)


## Điểm p nằm TRONG lưới đầu? Đếm số lần tia theo hướng lệch trục cắt tam giác của đầu (lẻ = trong).
func _inside(p: Vector3, head_tris: Array) -> bool:
	var dir := Vector3(0.3715, 0.9172, 0.1523).normalized()
	var hits: int = 0
	for tr: Array in head_tris:
		if Geometry3D.ray_intersects_triangle(p, dir, tr[0], tr[1], tr[2]) != null:
			hits += 1
	return hits % 2 == 1


## "" nếu vỏ tóc (không gai / búi / đuôi) sạch: không đỉnh nào nằm trong đầu, không cạnh tóc nào cắt tam giác đầu và ngược lại.
func _shell_problem(style: String, k: Dictionary, head_tris: Array, head_boxes: Array) -> String:
	var seen: Dictionary = {}
	for tr: Array in _mesh_tris(PS2Head.hair_mesh(style, k, false)):
		for p: Vector3 in tr:
			if not seen.has(p):
				seen[p] = true
				if _inside(p, head_tris):
					return "hair %s: vertex %s sinks into the head (k %s)" % [style, p, k]
		var box: AABB = _tri_box(tr)
		for i: int in range(head_tris.size()):
			if not box.intersects(head_boxes[i] as AABB):
				continue
			var ht: Array = head_tris[i]
			for e: int in range(3):
				var e2: int = (e + 1) % 3
				if Geometry3D.segment_intersects_triangle(tr[e], tr[e2], ht[0], ht[1], ht[2]) != null or Geometry3D.segment_intersects_triangle(ht[e], ht[e2], tr[0], tr[1], tr[2]) != null:
					return "hair %s: shell and head skin cross near %s (k %s)" % [style, (tr[0] + tr[1] + tr[2]) / 3.0, k]
	return ""


## Số đỉnh của các phần mũ trong HatFit (bỏ khối cuối = tóc gáy cố ý chìm; bỏ đáy bán cầu và tâm nắp trụ nằm trên trục) nằm TRONG sọ.
func _hat_sink_count(fit: Node3D, head_tris: Array) -> int:
	var inside: int = 0
	var parts: Array = fit.get_children()
	for pi: int in range(parts.size() - 1):
		var mi := parts[pi] as MeshInstance3D
		if mi == null:
			continue
		var xf: Transform3D = fit.transform * mi.transform
		var hemi: bool = mi.mesh is SphereMesh and (mi.mesh as SphereMesh).is_hemisphere
		var seen: Dictionary = {}
		for f: Vector3 in mi.mesh.get_faces():
			if (hemi and f.y < 0.0001) or Vector2(f.x, f.z).length() < 0.0005:
				continue
			var p: Vector3 = xf * f
			var key := Vector3(snappedf(p.x, 0.0005), snappedf(p.y, 0.0005), snappedf(p.z, 0.0005))
			if seen.has(key):
				continue
			seen[key] = true
			if _inside(p, head_tris):
				inside += 1
	return inside


## Số đỉnh vỏ tóc nằm trên đáy vành mà KHÔNG nằm trong vòm hoặc vành mũ bảo hiểm (đếm tia trên lưới kín của vòm / vành, hệ đầu).
func _hair_through_helmet(head: Node3D) -> int:
	var fit: Node3D = head.get_node("HatFit") as Node3D
	var rim_bottom: float = _helmet_low_y(fit)
	var solids: Array = []
	for ch: Node in fit.get_children():
		var mi := ch as MeshInstance3D
		if mi == null or not (mi.mesh is SphereMesh or mi.mesh is CylinderMesh):
			continue
		var xf: Transform3D = fit.transform * mi.transform
		var faces: PackedVector3Array = mi.mesh.get_faces()
		var tris: Array = []
		for t: int in range(faces.size() / 3):
			tris.append([xf * faces[t * 3], xf * faces[t * 3 + 1], xf * faces[t * 3 + 2]])
		solids.append(tris)
	var poking: int = 0
	var seen: Dictionary = {}
	for tr: Array in _mesh_tris((head.get_node("Hair") as MeshInstance3D).mesh as ArrayMesh):
		for p: Vector3 in tr:
			if seen.has(p) or p.y < rim_bottom:
				continue
			seen[p] = true
			var hidden: bool = false
			for tris: Array in solids:
				if _inside(p, tris):
					hidden = true
					break
			if not hidden:
				poking += 1
	return poking


## Y thấp nhất (hệ đầu) của các phần mũ bảo hiểm không phải quai (quai là hộp cao >= 0.1) trong nút HatFit.
func _helmet_low_y(fit: Node3D) -> float:
	var low: float = 99.0
	for ch: Node in fit.get_children():
		var mi := ch as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.y >= 0.1:
			continue
		var box: AABB = (fit.transform * mi.transform) * mi.mesh.get_aabb()
		low = minf(low, box.position.y)
	return low
