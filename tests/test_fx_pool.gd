# File: res://tests/test_fx_pool.gd
# Headless test of the Q3 VFX pool (plan 2026-10-29-q3-look.md Task 3):
#   A: the pool joins the group "fx_pool" (FxPool.find), prebuilds every kind's budget of CPUParticles3D;
#   B: every kind spawns at the position with its +Y along dir; unknown kinds are refused;
#   C: spawning past the budget never adds emitters: the one that frees soonest is reused (steals counted);
#   D: no object is created by 200 spawns + clock steps (Performance OBJECT_COUNT), no node is added;
#   E: continuous kinds stop emitting after their duration, every emitter frees after its particles' life;
#   F: scale multiplies size and radius, speeds by sqrt(scale);
#   G: render budget: all emitters running at once stay under MAX_PARTICLES, active_particles() tracks the live ones;
#   H: the scenes install it: FreeRoam, StoryBasement and NightBuilding scripts add an FxPool (source check).
# Run: godot --headless --path . --script tests/test_fx_pool.gd
extends SceneTree

const MAX_PARTICLES: int = 800

var done: bool = false
var frame: int = 0
var holder: Node3D
var pool: FxPool


func _initialize() -> void:
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	frame += 1
	if done:
		return
	if frame == 1:
		holder = Node3D.new()
		root.add_child(holder)
		pool = FxPool.new()
		holder.add_child(pool)
		return
	if frame != 3:
		return
	for part: Callable in [_part_a, _part_b, _part_c, _part_d, _part_e, _part_f, _part_g, _part_h]:
		if not part.call():
			return
	done = true
	print("SUCCESS: FX pool: 10 kinds, budgets held, oldest reused, no allocation per spawn, continuous kinds stop on time")
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("FAILED: ", msg)
		quit(1)
	return ok


func _emitters(kind: String) -> Array:
	var out: Array = []
	for c: Node in pool.get_children():
		if c.name.begins_with(kind + "_") and (c.name.trim_prefix(kind + "_")).is_valid_int():
			out.append(c)
	return out


# ---------------------------------------------------------------------------
func _part_a() -> bool:
	if not _check(pool.is_in_group("fx_pool") and FxPool.find(self) == pool and pool.has_method("spawn"), "pool not found through the group"):
		return false
	var total: int = 0
	for k: String in FxPool.KINDS.keys():
		if not _check(FxPool.ORDER.has(k) and pool.has_kind(k), "kind %s not built" % k):
			return false
		total += int(FxPool.KINDS[k]["budget"])
		if not _check(_emitters(k).size() == pool.budget(k), "kind %s: %d emitters, budget %d" % [k, _emitters(k).size(), pool.budget(k)]):
			return false
	if not _check(FxPool.KINDS.size() == 10 and pool.emitter_count() == total and pool.get_child_count() == total, "emitter count %d / %d" % [pool.emitter_count(), total]):
		return false
	for c: Node in pool.get_children():
		if not _check(c is CPUParticles3D and not (c as CPUParticles3D).emitting and not (c as CPUParticles3D).local_coords, "emitter %s not an idle world-space CPUParticles3D" % c.name):
			return false
	print("  A: %d kinds, %d prebuilt emitters" % [FxPool.KINDS.size(), total])
	return true


func _part_b() -> bool:
	var at := Vector3(10.0, 2.0, -5.0)
	for k: String in FxPool.ORDER:
		if not _check(pool.spawn(k, at, Vector3.RIGHT, 1.0), "spawn %s refused" % k):
			return false
		if not _check(pool.active_count(k) == 1, "%s: active %d after one spawn" % [k, pool.active_count(k)]):
			return false
		var e: CPUParticles3D = _emitters(k)[0]
		if not _check(e.global_position.is_equal_approx(at) and e.global_transform.basis.y.normalized().is_equal_approx(Vector3.RIGHT), "%s: emitter not at pos / not along dir" % k):
			return false
		var cont: bool = float(FxPool.KINDS[k]["dur"]) > 0.0
		if not _check(e.emitting and e.one_shot == (not cont), "%s: emitting %s one_shot %s" % [k, str(e.emitting), str(e.one_shot)]):
			return false
	if not _check(not pool.spawn("lava", at), "unknown kind accepted"):
		return false
	pool.spawn("dust", at, Vector3.ZERO)   # zero dir: falls back to UP
	pool.stop_all()
	if not _check(pool.active_count() == 0, "stop_all left active emitters"):
		return false
	print("  B: every kind spawns at the position along dir")
	return true


func _part_c() -> bool:
	var n: int = pool.budget("sparks")
	var first: CPUParticles3D = null
	var s0: int = pool.steals
	for i: int in range(n):
		pool.spawn("sparks", Vector3(float(i), 0.0, 0.0))
		pool.advance(0.01)
	first = _emitters("sparks")[0]
	if not _check(pool.active_count("sparks") == n and pool.steals == s0, "budget fill"):
		return false
	pool.spawn("sparks", Vector3(99.0, 0.0, 0.0))
	if not _check(pool.active_count("sparks") == n and pool.steals == s0 + 1, "past the budget: active %d steals %d" % [pool.active_count("sparks"), pool.steals - s0]):
		return false
	if not _check(first.global_position.is_equal_approx(Vector3(99.0, 0.0, 0.0)), "the oldest emitter was not the one reused"):
		return false
	print("  C: budget %d held, the oldest reused" % n)
	return true


func _part_d() -> bool:
	var nodes0: int = pool.get_child_count()
	var objs0: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	for i: int in range(200):
		var k: String = FxPool.ORDER[i % FxPool.ORDER.size()]
		pool.spawn(k, Vector3(float(i % 7), 0.0, float(i % 5)), Vector3(0.3, 1.0, 0.1), 0.5 + float(i % 4) * 0.5)
		pool.advance(0.016)
	var objs1: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	if not _check(pool.get_child_count() == nodes0 and objs1 <= objs0, "spawning created objects (%d -> %d) or nodes" % [int(objs0), int(objs1)]):
		return false
	print("  D: 200 spawns, objects %d -> %d, nodes unchanged" % [int(objs0), int(objs1)])
	return true


func _part_e() -> bool:
	pool.stop_all()
	pool.spawn("fire", Vector3.ZERO)
	var e: CPUParticles3D = _emitters("fire")[0]
	var dur: float = float(FxPool.KINDS["fire"]["dur"])
	pool.advance(dur * 0.5)
	if not _check(e.emitting, "fire stopped early"):
		return false
	pool.advance(dur * 0.5 + 0.02)
	if not _check(not e.emitting and pool.active_count("fire") == 1, "fire did not stop after %.1f s (or freed before its particles died)" % dur):
		return false
	pool.advance(float(FxPool.KINDS["fire"]["life"]) * 1.3)
	if not _check(pool.active_count("fire") == 0, "fire still active after its particles' life"):
		return false
	pool.spawn("smoke", Vector3.ZERO)
	pool.advance(float(FxPool.KINDS["smoke"]["life"]) * 1.3)
	if not _check(pool.active_count() == 0, "one-shot smoke still active"):
		return false
	print("  E: continuous kinds stop on time, emitters free after their life")
	return true


func _part_f() -> bool:
	pool.stop_all()
	var e: CPUParticles3D = _emitters("dust")[0]
	pool.spawn("dust", Vector3.ZERO, Vector3.UP, 1.0)
	var s1: float = e.scale_amount_max
	var v1: float = e.initial_velocity_max
	var r1: float = e.emission_sphere_radius
	pool.stop_all()
	pool.spawn("dust", Vector3.ZERO, Vector3.UP, 4.0)
	if not _check(is_equal_approx(e.scale_amount_max, s1 * 4.0) and is_equal_approx(e.initial_velocity_max, v1 * 2.0) and is_equal_approx(e.emission_sphere_radius, r1 * 4.0), "scale not applied (size %.2f / %.2f, speed %.2f / %.2f)" % [e.scale_amount_max, s1, e.initial_velocity_max, v1]):
		return false
	pool.stop_all()
	print("  F: scale -> size x4, radius x4, speed x2")
	return true


func _part_g() -> bool:
	if not _check(pool.max_particles() <= MAX_PARTICLES, "particle budget %d > %d" % [pool.max_particles(), MAX_PARTICLES]):
		return false
	for k: String in FxPool.ORDER:
		for i: int in range(pool.budget(k) + 2):
			pool.spawn(k, Vector3.ZERO)
	if not _check(pool.active_particles() == pool.max_particles() and pool.active_count() == pool.emitter_count(), "saturated pool: %d live of %d" % [pool.active_particles(), pool.max_particles()]):
		return false
	pool.stop_all()
	if not _check(pool.active_particles() == 0, "active particles after stop_all"):
		return false
	print("  G: render budget %d particles max (cap %d)" % [pool.max_particles(), MAX_PARTICLES])
	return true


func _part_h() -> bool:
	for path: String in ["res://scripts/FreeRoam.gd", "res://scripts/story/StoryBasement.gd", "res://scripts/horror/NightBuilding.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		if not _check(src.contains("add_child(FxPool.new())"), "%s does not install an FxPool" % path):
			return false
	print("  H: installed in FreeRoam, StoryBasement, NightBuilding")
	return true
