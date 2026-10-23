# File: res://scripts/cine/CineReplayRecorder.gd
# Short-replay recorder (A1-D18): a ring buffer of the last `window` seconds of GAME time at RATE Hz holding, per tracked
# actor, its global transform and (rigged characters) every bone's local pose (rotation + position, 7 floats per bone).
# Runs with the game (PROCESS_MODE_PAUSABLE): it stops recording while a replay pauses the tree. mark() stamps an event
# ("blow") the replay centres on. apply_at(t) puts every tracked actor back where it was at recorder time t (interpolated
# between the two nearest frames, clamped to the recorded range); snapshot()/restore() keep the live state around a replay.
class_name CineReplayRecorder
extends Node

const RATE: float = 30.0

@export var window: float = 8.0
var clock: float = 0.0                 # recorder time = accumulated game seconds since the recorder started
var recording: bool = true
var marks: Dictionary = {}             # name -> recorder time
var _actors: Array[Dictionary] = []    # {node: Node3D, sk: Skeleton3D or null, n: bone count}
var _cap: int = 0
var _head: int = 0                     # next write slot
var _count: int = 0
var _times: PackedFloat64Array = []
var _xf: Array = []                    # slot -> Array[Transform3D] (index = actor index; may be shorter for old frames)
var _pose: Array = []                  # slot -> Array[PackedFloat32Array]
var _acc: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_alloc()


func _alloc() -> void:
	_cap = int(ceil(window * RATE)) + 2
	_times.resize(_cap)
	_xf.resize(_cap)
	_pose.resize(_cap)
	_head = 0
	_count = 0


## Track an actor. Rigged CharacterBuilder bodies are found through the "skeleton" meta; any Node3D works (transform only).
func track(node: Node3D) -> void:
	for a: Dictionary in _actors:
		if a["node"] == node:
			return
	var sk: Skeleton3D = node.get_meta("skeleton", null) as Skeleton3D if node.has_meta("skeleton") else null
	_actors.append({"node": node, "sk": sk, "n": sk.get_bone_count() if sk else 0})


func tracked() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for a: Dictionary in _actors:
		if is_instance_valid(a["node"]):
			out.append(a["node"])
	return out


## A mark stamped from _physics_process precedes this frame's _process (which adds the frame delta to clock), so it takes
## the time the frame will be recorded at.
func mark(name: String = "blow") -> void:
	marks[name] = clock + (get_process_delta_time() if Engine.is_in_physics_frame() and recording else 0.0)


func _process(delta: float) -> void:
	if not recording:
		return
	clock += delta
	_acc += delta
	if _acc >= 1.0 / RATE:
		_acc = fmod(_acc, 1.0 / RATE)
		capture()


## Record one frame now at the current recorder time.
func capture() -> void:
	if _cap == 0:
		_alloc()
	var g: Array = _grab()
	_times[_head] = clock
	_xf[_head] = g[0]
	_pose[_head] = g[1]
	_head = (_head + 1) % _cap
	_count = mini(_count + 1, _cap)


## Current state of every tracked actor: [Array[Transform3D], Array[PackedFloat32Array]].
func _grab() -> Array:
	var xs: Array[Transform3D] = []
	var ps: Array[PackedFloat32Array] = []
	for a: Dictionary in _actors:
		var node: Node3D = a["node"] if is_instance_valid(a["node"]) else null
		xs.append(node.global_transform if node and node.is_inside_tree() else Transform3D.IDENTITY)
		var pose := PackedFloat32Array()
		var sk: Skeleton3D = a["sk"] if node else null
		if sk and is_instance_valid(sk):
			pose.resize(int(a["n"]) * 7)
			for b: int in int(a["n"]):
				var q: Quaternion = sk.get_bone_pose_rotation(b)
				var p: Vector3 = sk.get_bone_pose_position(b)
				var o: int = b * 7
				pose[o] = q.x
				pose[o + 1] = q.y
				pose[o + 2] = q.z
				pose[o + 3] = q.w
				pose[o + 4] = p.x
				pose[o + 5] = p.y
				pose[o + 6] = p.z
		ps.append(pose)
	return [xs, ps]


func frame_count() -> int:
	return _count


func _slot(i: int) -> int:   # i = 0 oldest .. _count - 1 newest
	return (_head - _count + i + _cap) % _cap


func oldest_time() -> float:
	return _times[_slot(0)] if _count > 0 else clock


func newest_time() -> float:
	return _times[_slot(_count - 1)] if _count > 0 else clock


## [slot a, slot b, weight] of the frames around recorder time t (clamped to the recorded range).
func _bracket(t: float) -> Array:
	if _count == 0:
		return []
	if t <= oldest_time():
		return [_slot(0), _slot(0), 0.0]
	if t >= newest_time():
		return [_slot(_count - 1), _slot(_count - 1), 0.0]
	var lo: int = 0
	var hi: int = _count - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if _times[_slot(mid)] <= t:
			lo = mid
		else:
			hi = mid
	var a: int = _slot(lo)
	var b: int = _slot(hi)
	var span: float = _times[b] - _times[a]
	return [a, b, 0.0 if span <= 0.0 else (t - _times[a]) / span]


## Global transform of tracked actor `node` at recorder time t (identity when unknown).
func transform_at(node: Node3D, t: float) -> Transform3D:
	var i: int = _index_of(node)
	var br: Array = _bracket(t)
	if i < 0 or br.is_empty():
		return Transform3D.IDENTITY
	var xa: Array = _xf[br[0]]
	var xb: Array = _xf[br[1]]
	if i >= xa.size() or i >= xb.size():
		return node.global_transform
	return (xa[i] as Transform3D).interpolate_with(xb[i], float(br[2]))


func _index_of(node: Node3D) -> int:
	for i: int in _actors.size():
		if _actors[i]["node"] == node:
			return i
	return -1


## Put every tracked actor back where it was at recorder time t.
func apply_at(t: float) -> void:
	var br: Array = _bracket(t)
	if br.is_empty():
		return
	_apply_slots(br[0], br[1], float(br[2]))


func _apply_slots(sa: int, sb: int, w: float) -> void:
	_apply_frames(_xf[sa], _xf[sb], _pose[sa], _pose[sb], w)


func _apply_frames(xa: Array, xb: Array, pa: Array, pb: Array, w: float) -> void:
	for i: int in _actors.size():
		var a: Dictionary = _actors[i]
		if not is_instance_valid(a["node"]) or i >= xa.size() or i >= xb.size():
			continue
		var node: Node3D = a["node"]
		if node.is_inside_tree():
			node.global_transform = (xa[i] as Transform3D).interpolate_with(xb[i], w)
		var sk: Skeleton3D = a["sk"]
		if sk == null or not is_instance_valid(sk) or i >= pa.size() or i >= pb.size():
			continue
		var fa: PackedFloat32Array = pa[i]
		var fb: PackedFloat32Array = pb[i]
		if fa.size() != int(a["n"]) * 7 or fb.size() != fa.size():
			continue
		for b: int in int(a["n"]):
			var o: int = b * 7
			var qa := Quaternion(fa[o], fa[o + 1], fa[o + 2], fa[o + 3])
			var qb := Quaternion(fb[o], fb[o + 1], fb[o + 2], fb[o + 3])
			sk.set_bone_pose_rotation(b, qa.slerp(qb, w))
			sk.set_bone_pose_position(b, Vector3(fa[o + 4], fa[o + 5], fa[o + 6]).lerp(Vector3(fb[o + 4], fb[o + 5], fb[o + 6]), w))


## Live state of every tracked actor (taken right before a replay; the ring buffer is not touched).
func snapshot() -> Dictionary:
	var g: Array = _grab()
	return {"xf": g[0], "pose": g[1]}


func restore(snap: Dictionary) -> void:
	if not snap.is_empty():
		_apply_frames(snap["xf"], snap["xf"], snap["pose"], snap["pose"], 0.0)


## Clock and window for a replay of REAL length L around recorder time f (A1-D18). The replay runs at `base` speed with
## one ramp (preset) at f placed at focus_u·L real seconds; the footage after f is limited to what was recorded (`after`),
## the rest of L goes before f. Story time s maps to recorder time t0 + s. Returns {"clock": CineClock, "t0": float}.
static func replay_clock(L: float, f: float, after: float, base: float = 0.5, preset: String = "heavy", focus_u: float = 0.55) -> Dictionary:
	var c := CineClock.new()
	c.length = L
	c.base = base
	c.tail_rule = false
	var p: Dictionary = CineClock.PRESETS[preset]
	var k: float = p["k"]
	var pre: float = float(p["ri"]) * (base + k) * 0.5 + float(p["hp"]) * k
	var post: float = float(p["hq"]) * k + float(p["ro"]) * (k + base) * 0.5
	var real_span: float = float(p["ri"]) + float(p["hp"]) + float(p["freeze"]) + float(p["hq"]) + float(p["ro"])
	var real_after_ideal: float = L * (1.0 - focus_u) - (float(p["freeze"]) + float(p["hq"]) + float(p["ro"]))
	var gap_post: float = clampf(minf(real_after_ideal * base, after - post), 0.0, INF)
	var gap_pre: float = maxf((L - real_span - gap_post / base) * base, 0.0)
	var s_focus: float = gap_pre + pre
	c.add("focus", s_focus, preset)
	c.story_end = s_focus + post + gap_post
	return {"clock": c, "t0": f - s_focus}
