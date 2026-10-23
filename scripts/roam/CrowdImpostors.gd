# File: res://scripts/roam/CrowdImpostors.gd
# Tầng xa của đám đông FreeRoam (spec vice-people-and-movement, "Amendment 2026-10-22"): người đi đường ở 90-225 m là
# "người nộm" – mỗi biến thể (preset + seed + female, 8 biến thể mỗi khu) bake MỘT lần ở tư thế "stride" thành một
# ArrayMesh và vẽ bằng một MultiMeshInstance3D (không đổ bóng); người nộm trượt theo cạnh PedWalkGraph, transform cập nhật
# 10 lần / giây. Cùng danh tính (identity) với Pedestrian nên PedestrianSpawner đổi qua lại hai tầng mà người đi không đổi
# mặt. Mesh bake lưu tĩnh theo phong cách (vào lại FreeRoam không bake lại). Mảng song song, xoá bằng cách đổi chỗ với
# phần tử cuối. Không dùng autoload ở đây (class_name biên dịch trước autoload khi chạy test --script).
class_name CrowdImpostors
extends Node3D

const VARIANTS_PER_ZONE: int = 8
## Preset 8 biến thể mỗi khu (chỉ số = PedWalkGraph.ZONE_*): campus 7 sinh viên + 1 giảng viên; dân cư và đường: dân
## thường (casual) nhiều nhất, có sinh viên ở trọ và giảng viên / dân văn phòng (spec Phần 3: 90/10 và 60/30/10).
const ZONE_PRESETS: Array = [
	["student", "student", "student", "student", "student", "student", "student", "lecturer"],
	["casual", "casual", "casual", "casual", "casual", "student", "student", "lecturer"],
	["casual", "casual", "casual", "casual", "student", "student", "student", "lecturer"],
]
const DEFAULT_CAP: int = 200
const TICK_S: float = 0.1

static var _bake_cache: Dictionary = {}   # "preset|seed|female|ps2" -> [ArrayMesh, Vector3 scale]

var graph: PedWalkGraph
var cap: int = DEFAULT_CAP
var bake_ms: int = 0
var _meshes: Array = []            # v -> ArrayMesh
var _scales: Array = []            # v -> Vector3 (root.scale của nhân vật lúc bake)
var _lift: Array = []              # v -> float: hạ instance theo điểm thấp nhất (chân nhấc lên trong tư thế sải chân)
var _mm: Array = []                # v -> MultiMesh
var _wid := PackedInt32Array()
var _v := PackedInt32Array()
var _node := PackedInt32Array()
var _prev := PackedInt32Array()
var _pos := PackedVector3Array()
var _speed := PackedFloat32Array()
var _yaw := PackedFloat32Array()
var _ident: Array = []             # Dictionary danh tính đầy đủ của từng người nộm
var _rng := RandomNumberGenerator.new()
var _acc: float = 0.0
var _dirty: bool = false


## Bảng 24 biến thể (3 khu x 8), cố định giữa các lần chạy: {"v", "zone", "preset", "seed", "female"}.
static func variants() -> Array:
	var out: Array = []
	for z: int in range(ZONE_PRESETS.size()):
		var list: Array = ZONE_PRESETS[z]
		for k: int in range(list.size()):
			out.append({"v": z * VARIANTS_PER_ZONE + k, "zone": z, "preset": String(list[k]), "seed": 7100 + z * 100 + k * 7, "female": k % 2 == 1})
	return out


## Bake một biến thể: nhân vật rigged (người PS2 ở Vice City) ở tư thế "stride" -> [ArrayMesh, root.scale].
## Lưu tĩnh theo preset / seed / female / phong cách (CharacterBuilder.ps2).
static func bake_variant(ident: Dictionary) -> Array:
	var key: String = "%s|%d|%s|%s" % [String(ident.get("preset", "student")), int(ident.get("seed", 0)), str(ident.get("female", "-")), str(CharacterBuilder.ps2)]
	if _bake_cache.has(key):
		return _bake_cache[key]
	var o: Dictionary = Pedestrian.model_opts(ident)
	o["animate"] = false
	var rig: Node3D = CharacterBuilder.build(o)
	CharacterBuilder.pose(rig, "stride")
	var mesh: ArrayMesh = CharacterBuilder.bake(rig)
	var s: Vector3 = rig.scale
	rig.free()
	_bake_cache[key] = [mesh, s]
	return _bake_cache[key]


func setup(g: PedWalkGraph, opts: Dictionary = {}) -> void:
	graph = g
	cap = int(opts.get("cap", DEFAULT_CAP))
	_rng.seed = int(opts.get("seed", 4242))
	var t0: int = Time.get_ticks_msec()
	for ident: Dictionary in variants():
		var baked: Array = bake_variant(ident)
		var mesh: ArrayMesh = baked[0]
		var s: Vector3 = baked[1]
		_meshes.append(mesh)
		_scales.append(s)
		_lift.append(-mesh.get_aabb().position.y * s.y)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = cap
		mm.visible_instance_count = 0
		_mm.append(mm)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Variant_%d" % int(ident["v"])
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	bake_ms = Time.get_ticks_msec() - t0


## Thêm một người nộm. state: wid, identity (có "v"), node (nút đang tới), prev, pos, speed. false khi đầy / biến thể lạ.
func add(state: Dictionary) -> bool:
	if _wid.size() >= cap:
		return false
	var ident: Dictionary = state["identity"]
	var v: int = int(ident.get("v", -1))
	if v < 0 or v >= _mm.size():
		return false
	_wid.append(int(state.get("wid", -1)))
	_v.append(v)
	_node.append(int(state["node"]))
	_prev.append(int(state.get("prev", int(state["node"]))))
	_pos.append(state["pos"])
	_speed.append(float(state.get("speed", 1.3)))
	_yaw.append(float(state.get("yaw", 0.0)))
	_ident.append(ident)
	_dirty = true
	return true


func count() -> int:
	return _wid.size()


func state_at(i: int) -> Dictionary:
	return {"wid": _wid[i], "identity": _ident[i], "node": _node[i], "prev": _prev[i], "pos": _pos[i], "speed": _speed[i], "yaw": _yaw[i]}


func positions() -> PackedVector3Array:
	return _pos


func wids() -> PackedInt32Array:
	return _wid


func multimesh(v: int) -> MultiMesh:
	return _mm[v]


func variant_mesh(v: int) -> ArrayMesh:
	return _meshes[v]


func variant_scale(v: int) -> Vector3:
	return _scales[v]


## Lấy ra (xoá khỏi đám) tối đa max_n người nộm trong bán kính r quanh center, gần trước; có pred thì chỉ lấy người mà
## pred(pos: Vector3) trả true. Trả về state của họ.
func take_within(center: Vector3, r: float, max_n: int, pred: Callable = Callable()) -> Array:
	if max_n <= 0:
		return []
	var near: Array = []
	for i: int in range(_wid.size()):
		var d: float = _flat(_pos[i], center)
		if d <= r and (not pred.is_valid() or bool(pred.call(_pos[i]))):
			near.append([d, i])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	near.resize(mini(near.size(), max_n))
	var states: Array = []
	for e: Array in near:
		states.append(state_at(int(e[1])))
	_remove_indices(near.map(func(e: Array) -> int: return int(e[1])))
	return states


## Xoá mọi người nộm mà pred(pos: Vector3) trả true; trả về số người đã xoá.
func remove_where(pred: Callable) -> int:
	var n: int = 0
	for i: int in range(_wid.size() - 1, -1, -1):
		if bool(pred.call(_pos[i])):
			_remove(i)
			n += 1
	return n


func remove_farthest(center: Vector3, n: int) -> int:
	if n <= 0:
		return 0
	var all: Array = []
	for i: int in range(_wid.size()):
		all.append([_flat(_pos[i], center), i])
	all.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	all.resize(mini(all.size(), n))
	_remove_indices(all.map(func(e: Array) -> int: return int(e[1])))
	return all.size()


## Đi tiếp dt giây theo cạnh đồ thị; tới nút thì chọn nút kế (next_node); nút cô lập (block_near) thì đứng yên.
func step(dt: float) -> void:
	if graph == null:
		return
	for i: int in range(_wid.size()):
		var p: Vector3 = _pos[i]
		var left: float = _speed[i] * dt
		var guard: int = 0
		while left > 0.0 and guard < 4:
			guard += 1
			var tp: Vector3 = graph.node_pos(_node[i])
			var to := Vector3(tp.x - p.x, 0.0, tp.z - p.z)
			var d: float = to.length()
			if d > 0.001:
				_yaw[i] = atan2(-to.x, -to.z)
			if d > left:
				p += to / d * left
				left = 0.0
			else:
				p = Vector3(tp.x, p.y, tp.z)
				left -= d
				var nxt: int = graph.next_node(_node[i], _prev[i], _rng)
				_prev[i] = _node[i]
				_node[i] = nxt
				if nxt == _prev[i]:
					break
		_pos[i] = p
	_dirty = true


## Ghi transform mọi người nộm vào MultiMesh của biến thể (mặt nhìn -Z như nhân vật, cỡ = root.scale lúc bake, hạ theo
## điểm thấp nhất của biến thể để chân chạm đất).
func flush() -> void:
	var used := PackedInt32Array()
	used.resize(_mm.size())
	used.fill(0)
	for i: int in range(_wid.size()):
		var v: int = _v[i]
		var k: int = used[v]
		used[v] = k + 1
		var b: Basis = Basis(Vector3.UP, _yaw[i]).scaled(_scales[v])
		(_mm[v] as MultiMesh).set_instance_transform(k, Transform3D(b, _pos[i] + Vector3(0.0, float(_lift[v]), 0.0)))
	for v2: int in range(_mm.size()):
		(_mm[v2] as MultiMesh).visible_instance_count = used[v2]
	_dirty = false


func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc >= TICK_S:
		step(_acc)
		_acc = 0.0
	if _dirty:
		flush()


func _remove_indices(idx: Array) -> void:
	idx.sort()
	idx.reverse()
	for i: int in idx:
		_remove(i)


## Xoá phần tử i: phần tử cuối thế vào chỗ i (xoá theo chỉ số giảm dần thì các chỉ số nhỏ hơn không đổi).
func _remove(i: int) -> void:
	var last: int = _wid.size() - 1
	if i != last:
		_wid[i] = _wid[last]
		_v[i] = _v[last]
		_node[i] = _node[last]
		_prev[i] = _prev[last]
		_pos[i] = _pos[last]
		_speed[i] = _speed[last]
		_yaw[i] = _yaw[last]
		_ident[i] = _ident[last]
	_wid.resize(last)
	_v.resize(last)
	_node.resize(last)
	_prev.resize(last)
	_pos.resize(last)
	_speed.resize(last)
	_yaw.resize(last)
	_ident.resize(last)
	_dirty = true


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
