# File: res://tests/test_ps2_head.gd
# Test headless PS2Head: số tam giác, kích thước, chiều quấn mặt hướng ra ngoài, UV mặt trước / sau đầu,
# mọi kiểu tóc bao đỉnh đầu, build() ghi rig + vật liệu một ô atlas, ô biểu cảm, kính, mũ đầu bếp.
# Chạy:  godot --headless --path . --script tests/test_ps2_head.gd
extends SceneTree

var done: bool = false


func _initialize() -> void:
	var k: Dictionary = {"w": 1.0, "jaw": 1.0, "nose": 1.0}
	var mesh: ArrayMesh = PS2Head.head_mesh(k)
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tris: int = idx.size() / 3
	print("  head: %d triangles, %d vertices" % [tris, verts.size()])
	if not _check(tris >= 250 and tris <= 420, "head must have 250..420 triangles (got %d)" % tris):
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
	for style: String in PS2Head.HAIR_STYLES:
		var hm: ArrayMesh = PS2Head.hair_mesh(style, k)
		var hab: AABB = hm.get_aabb()
		var ht: int = hm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3 if hm.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == null else hm.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		if not _check(ht > 20 and hab.end.y >= PS2Head.HEAD_H, "hair %s must cover the crown (%d tris, top %.3f)" % [style, ht, hab.end.y]):
			return
	# build(): rig keys, face material on one atlas cell, glasses, cell offsets
	var holder := Node3D.new()
	root.add_child(holder)
	var rig: Dictionary = {}
	var head: Node3D = PS2Head.build(holder, Vector3.ZERO, {"skin": 2, "female": true, "variant": 1, "hair_style": "ponytail", "hair_color": 1, "seed": 7, "outfit": {"glasses": true}}, rig)
	if not _check(head != null and head.name == "Head" and bool(head.get_meta("ps2_head", false)), "build() returns the Head pivot with meta ps2_head"):
		return
	for key: String in ["head", "face_mesh", "head_top"]:
		if not _check(rig.has(key), "rig[%s] missing" % key):
			return
	var fm: StandardMaterial3D = (rig["face_mesh"] as MeshInstance3D).material_override as StandardMaterial3D
	if not _check(fm != null and bool(fm.get_meta("ps2_face", false)) and fm.uv1_scale.is_equal_approx(Vector3(0.25, 0.5, 1.0)), "face material samples one atlas cell"):
		return
	if not _check(PS2Head.cell_offset("open").is_equal_approx(Vector3.ZERO) and PS2Head.cell_offset("angry").is_equal_approx(Vector3(0.75, 0.0, 0.0)) and PS2Head.cell_offset("pain").is_equal_approx(Vector3(0.75, 0.5, 0.0)), "cell offsets follow the 4 x 2 atlas order"):
		return
	if not _check(head.get_node_or_null("Hair") != null, "hair mesh node missing"):
		return
	var n_mi: int = 0
	for ch: Node in head.get_children():
		if ch is MeshInstance3D:
			n_mi += 1
	if not _check(n_mi >= 10, "glasses must add frame parts (only %d mesh instances under Head)" % n_mi):
		return
	var rig2: Dictionary = {}
	var chef: Node3D = PS2Head.build(holder, Vector3(1.0, 0.0, 0.0), {"skin": 0, "seed": 3, "outfit": {"chef_hat": true}}, rig2)
	if not _check(chef.get_node_or_null("Hair") == null and chef.get_child_count() >= 5, "chef hat path builds the hat instead of the hair shell"):
		return
	print("✅ SUCCESS: PS2 HEAD MESH, UV, HAIR, CELLS AND ACCESSORIES OK")
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("❌ FAILED: ", msg)
		quit(2)
	return ok
