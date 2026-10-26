# File: res://tests/test_traffic_lamps.gd
# Test headless đèn xe giao thông ban đêm (spec owner-bike-and-night-lights, OB-D6 / OB-D7).
#   A: PropBuilder: build_car / build_bus / build_scooter(traffic_lamps) bake với 4 vật liệu đèn dùng chung (cùng tham
#      chiếu giữa các xe), ban ngày mờ đúng năng lượng cũ (> 0,5: không thành soft emitter của ViceStyle), set_traffic_lamps
#      bật / tắt cả bốn; xe máy thường và lens() không bị ảnh hưởng.
#   B: RoamTraffic trên MapData tự dựng (z ~ 6000): roam "night" -> đèn sáng, vũng sáng trước ô tô / xe buýt hiện (vật liệu
#      và mesh dùng chung, tầm nhìn <= 40 m, cộng màu, không đổ bóng), không có Light3D nào; set_night_lamps(false) tắt;
#      xe lật thì giấu vũng sáng; dawn / sunset cũng là tối; RoamTraffic rời cây -> đèn về ban ngày; roam "morning" -> tắt.
# Chạy:  godot --headless --path . --script tests/test_traffic_lamps.gd
extends SceneTree

const W: float = 10.5
const CENTER := Vector3(0.0, 0.0, 6000.0)

var done: bool = false
var started: bool = false


func _initialize() -> void:
	CharacterBuilder.ps2 = true      # mặc định của game là vice; test --script không có GameFX
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	process_frame.connect(_on_frame)   # nút thêm trong _initialize chưa vào cây: chạy ở khung đầu tiên


func _on_frame() -> void:
	if started or done:
		return
	started = true
	if not _part_a():
		return
	if not _part_b():
		return
	done = true
	print("SUCCESS: traffic lamps lit at night, dim by day, shared materials, light pools near cars and buses")
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("FAILED: ", msg)
		quit(1)
	return ok


static func _surface_mats(mi: MeshInstance3D) -> Array:
	var out: Array = []
	if mi == null or mi.mesh == null:
		return out
	for i: int in range(mi.mesh.get_surface_count()):
		out.append(mi.mesh.surface_get_material(i))
	return out


static func _energy(kind: String) -> float:
	return PropBuilder.traffic_lamp(kind).emission_energy_multiplier


func _all_at(idx: int) -> bool:
	for kind: String in PropBuilder.TRAFFIC_LAMPS.keys():
		if not is_equal_approx(_energy(kind), float((PropBuilder.TRAFFIC_LAMPS[kind] as Array)[idx])):
			return false
	return true


# ---------------------------------------------------------------------------
func _part_a() -> bool:
	PropBuilder.set_traffic_lamps(false)
	var holder := Node3D.new()
	root.add_child(holder)
	var car1: MeshInstance3D = PropBuilder.build_car(holder, Color("#7FD8D2"), true) as MeshInstance3D
	var car2: MeshInstance3D = PropBuilder.build_car(holder, Color("#F4A6C0"), true) as MeshInstance3D
	var bus: MeshInstance3D = PropBuilder.build_bus(holder, true, true) as MeshInstance3D
	var moto: MeshInstance3D = PropBuilder.build_scooter(holder, Vector3.ZERO, 0.0, Color("#2C3E50"), {"baked": true, "traffic_lamps": true})["root"]
	var plain: MeshInstance3D = PropBuilder.build_scooter(holder, Vector3.ZERO, 0.0, Color("#2C3E50"), {"baked": true})["root"]
	var head: Material = PropBuilder.traffic_lamp("head")
	var tail: Material = PropBuilder.traffic_lamp("tail")
	var mhead: Material = PropBuilder.traffic_lamp("moto_head")
	var mtail: Material = PropBuilder.traffic_lamp("moto_tail")
	var lamp_set: Array = [head, tail, mhead, mtail]
	var c1: Array = _surface_mats(car1)
	var c2: Array = _surface_mats(car2)
	var bm: Array = _surface_mats(bus)
	var mm: Array = _surface_mats(moto)
	var pl: Array = _surface_mats(plain)
	if not _check(c1.has(head) and c1.has(tail) and c2.has(head) and c2.has(tail), "both baked cars use the shared head / tail lamp materials"):
		return false
	if not _check(bm.has(head) and bm.has(tail), "the baked bus uses the shared head / tail lamp materials"):
		return false
	if not _check(mm.has(mhead) and mm.has(mtail), "a traffic scooter uses the shared moto lamp materials"):
		return false
	for m: Variant in pl:
		if not _check(not lamp_set.has(m), "a non-traffic scooter (menu, parked, rival) keeps its own lenses"):
			return false
	if not _check(PropBuilder.traffic_lamp("head") == head, "traffic_lamp() returns the same material every time"):
		return false
	# ban ngày: đúng năng lượng của lens() cũ, > 0,5 để ViceStyle không coi là soft emitter (tắt hẳn ban ngày)
	if not _check(not PropBuilder.traffic_lamps_on() and _all_at(1), "by day the lamps sit at their old energies"):
		return false
	for kind: String in PropBuilder.TRAFFIC_LAMPS.keys():
		if not _check(_energy(kind) > ViceStyle.SOFT_EMITTER_MAX, "day lamp %s stays above the soft-emitter cutoff" % kind):
			return false
	var plain_head: StandardMaterial3D = PropBuilder.lens(Color("#FFF4C8"), 1.8)
	var plain_e: float = plain_head.emission_energy_multiplier
	PropBuilder.set_traffic_lamps(true)
	if not _check(PropBuilder.traffic_lamps_on() and _all_at(2), "at night every lamp material switches to its night energy"):
		return false
	for kind: String in PropBuilder.TRAFFIC_LAMPS.keys():
		var spec: Array = PropBuilder.TRAFFIC_LAMPS[kind]
		if not _check(float(spec[2]) >= float(spec[1]) * 2.0, "night lamp %s is clearly brighter than by day" % kind):
			return false
	if not _check(is_equal_approx(plain_head.emission_energy_multiplier, plain_e), "the shared lens() (player bike, lamp posts) is not switched"):
		return false
	PropBuilder.set_traffic_lamps(false)
	if not _check(_all_at(1), "back to day: the lamps dim again"):
		return false
	print("  A ok: car %d, bus %d, moto %d surfaces; day %.1f / night %.1f (car head)" % [c1.size(), bm.size(), mm.size(), float(PropBuilder.TRAFFIC_LAMPS["head"][1]), float(PropBuilder.TRAFFIC_LAMPS["head"][2])])
	holder.queue_free()
	return true


# ---------------------------------------------------------------------------
func _part_b() -> bool:
	for p: String in ["night", "sunset", "dawn"]:
		if not _check(RoamTraffic.is_dark_preset(p), "%s is a dark preset" % p):
			return false
	for p: String in ["morning", "noon", "dawn_x", ""]:
		if not _check(not RoamTraffic.is_dark_preset(p), "%s is not a dark preset" % p):
			return false
	var md := MapData.new()
	md.data = {"roads": _synthetic_roads()}
	var player := CharacterBody3D.new()
	player.set_script(load("res://tests/support/stub_mover.gd"))
	player.collision_layer = 0
	root.add_child(player)
	player.global_position = CENTER
	var roam := Node.new()
	roam.set_script(load("res://tests/support/stub_roam.gd"))
	roam.set("tod_preset", "night")
	root.add_child(roam)
	var t: RoamTraffic = _make_traffic(md, player, roam)
	if not _check(t.lamps_on and PropBuilder.traffic_lamps_on() and _all_at(2), "traffic set up at night starts with its lamps lit"):
		return false
	var pools: int = 0
	var pool_mat: Material = null
	var pool_mesh_car: Mesh = null
	for v: RoamTraffic.Vehicle in t.vehicles:
		if v.kind == RoamTraffic.Kind.CAR or v.kind == RoamTraffic.Kind.BUS:
			if not _check(v.pool != null and v.pool.visible, "every car / bus has a visible light pool at night"):
				return false
			if pool_mat == null:
				pool_mat = v.pool.material_override
			if not _check(v.pool.material_override == pool_mat, "light pools share one material"):
				return false
			if v.kind == RoamTraffic.Kind.CAR:
				if pool_mesh_car == null:
					pool_mesh_car = v.pool.mesh
				if not _check(v.pool.mesh == pool_mesh_car, "car light pools share one mesh"):
					return false
			if not _check(v.pool.visibility_range_end > 0.0 and v.pool.visibility_range_end <= 40.0, "light pools draw only near the camera"):
				return false
			if not _check(v.pool.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and v.pool.position.z < -3.0, "the pool lies on the road ahead (-Z) and casts no shadow"):
				return false
			pools += 1
		else:
			if not _check(v.pool == null, "scooters get no light pool"):
				return false
			var mats: Array = _surface_mats(v.body.get_node_or_null("Scooter") as MeshInstance3D)
			if not _check(mats.has(PropBuilder.traffic_lamp("moto_head")) and mats.has(PropBuilder.traffic_lamp("moto_tail")), "traffic scooters (police too) use the shared moto lamps"):
				return false
	var pm := pool_mat as StandardMaterial3D
	if not _check(pm != null and pm.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and pm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and pm.has_meta("vice_done"), "the pool material is unshaded additive and skipped by the art-style pass"):
		return false
	if not _check(pools == 4, "2 cars + 2 buses carry pools (got %d)" % pools):
		return false
	if not _check(t.find_children("*", "Light3D", true, false).is_empty(), "no real Light3D nodes on traffic"):
		return false
	# xe lật: giấu vũng sáng, bật lại đèn cũng không hiện; cất xe thì theo trạng thái đèn
	var car: RoamTraffic.Vehicle = null
	for v: RoamTraffic.Vehicle in t.vehicles:
		if v.kind == RoamTraffic.Kind.CAR:
			car = v
			break
	car.wreck_t = 0.0
	t.set_night_lamps(true)
	if not _check(not car.pool.visible, "a wrecked car shows no light pool"):
		return false
	t._park(car)
	if not _check(car.pool.visible, "a recycled car gets its pool back"):
		return false
	t.set_night_lamps(false)
	for v: RoamTraffic.Vehicle in t.vehicles:
		if v.pool and not _check(not v.pool.visible, "by day the pools are hidden"):
			return false
	if not _check(not PropBuilder.traffic_lamps_on() and _all_at(1), "set_night_lamps(false) dims the shared lamps"):
		return false
	t.set_night_lamps(true)
	root.remove_child(t)
	if not _check(not PropBuilder.traffic_lamps_on() and _all_at(1), "leaving the tree resets the lamps to day (no leak into Stage 1 / menu)"):
		return false
	t.queue_free()
	roam.set("tod_preset", "morning")
	var t2: RoamTraffic = _make_traffic(md, player, roam)
	if not _check(not t2.lamps_on and _all_at(1), "traffic set up in the morning starts dim"):
		return false
	for v: RoamTraffic.Vehicle in t2.vehicles:
		if v.pool and not _check(not v.pool.visible, "morning: pools hidden"):
			return false
	print("  B ok: %d pools, %d vehicles" % [pools, t2.vehicles.size()])
	return true


func _make_traffic(md: MapData, player: Node3D, roam: Node) -> RoamTraffic:
	var t := RoamTraffic.new()
	root.add_child(t)
	var kinds: Array = [RoamTraffic.Kind.MOTO, RoamTraffic.Kind.MOTO, RoamTraffic.Kind.CAR, RoamTraffic.Kind.CAR, RoamTraffic.Kind.BUS, RoamTraffic.Kind.BUS, RoamTraffic.Kind.POLICE]
	t.setup(md, player, {"roam": roam, "kinds": kinds, "plot": PackedVector2Array(), "seed": 5})
	t.set_physics_process(false)
	return t


func _synthetic_roads() -> Array:
	var sq: Array = [[Vector2(-80.0, 6080.0), Vector2(80.0, 6080.0)], [Vector2(80.0, 6080.0), Vector2(80.0, 5920.0)],
		[Vector2(80.0, 5920.0), Vector2(-80.0, 5920.0)], [Vector2(-80.0, 5920.0), Vector2(-80.0, 6080.0)]]
	var out: Array = []
	for i: int in range(sq.size()):
		var a: Vector2 = sq[i][0]
		var b: Vector2 = sq[i][1]
		out.append({"id": i + 1, "name": "Vuông %d" % (i + 1), "class": "primary", "width": W, "lanes": 2, "oneway": false, "roundabout": false, "bridge": false, "region": "corridor", "points": [[a.x, a.y], [b.x, b.y]]})
	return out
