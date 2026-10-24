# File: res://tests/test_community_service.gd
# Headless test of Phase W community service (spec W-D8, section 5, section 7): the chore puts the player in an orange
# vest, 8 rubbish bags 4-10 m around a bin and a supervising officer who says meme lines; walking onto a bag carries it,
# walking to the bin drops it; 8 drops complete it (vest gone); running out of the 120 s restarts it with 2 bags fewer, never
# fewer than 2 (no softlock); Esc cannot skip it; the street spot is a verge beside Nguyễn Xiển and the campus spot is the
# parking. Part B (FreeRoam, crowd off): busted on campus -> cutscene skipped -> chore at the campus parking with weapons and
# the bike locked -> 8 bags -> wanted level cleared, player beside his parked bike, weapons free again.
# Counts physics frames (Engine.max_fps = 60).
# Run:  godot --headless --path . --script tests/test_community_service.gd
extends SceneTree

const World: Script = preload("res://tests/support/mayhem_world.gd")

var fails: Array[String] = []
var frames: int = 0
var phase: String = ""
var t0: int = 0
var started: bool = false
var arena: Node3D
var player: ThirdPersonController
var svc: CommunityService
var done_n: int = 0
var restarts: Array[int] = []
var step_i: int = 0
var roam: Node3D


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	Engine.max_fps = 60
	CharacterBuilder.ps2 = true
	CharacterBuilder.toon = false
	CharacterBuilder.head_scale_default = 1.0
	print("--- TEST COMMUNITY SERVICE ---")
	var md: MapData = MapData.load_default()
	var sc: Vector3 = CommunityService.street_center(md)
	_check(WeaponMath.flat(sc, Vector3(CommunityService.STREET_NEAR.x, 0.0, CommunityService.STREET_NEAR.y)) < 60.0, "the street chore is on the Nguyễn Xiển verge (%s)" % sc)
	var lm: Array = md.landmark("campus_parking_center")
	_check(CommunityService.campus_center(md).is_equal_approx(Vector3(float(lm[0]), 0.0, float(lm[1]))), "the campus chore is at the campus parking")
	physics_frame.connect(_on_physics)


func _next(p: String) -> void:
	phase = p
	t0 = frames


func _new_service() -> CommunityService:
	var s := CommunityService.new()
	s.name = "Service"
	arena.add_child(s)
	s.start(player, null, null, false, Vector3.ZERO)
	s.completed.connect(func() -> void: done_n += 1)
	s.restarted.connect(func(n: int) -> void: restarts.append(n))
	return s


## One bag per two frames: even frames step onto the next bag, odd frames walk it to the bin.
func _deliver(s: CommunityService, ply: ThirdPersonController) -> void:
	if step_i % 2 == 0:
		if not s.bags.is_empty():
			ply.teleport(s.bags[0].global_position, 0.0)
	else:
		ply.teleport(s.bin.global_position + Vector3(0.6, 0.0, 0.0), 0.0)
	step_i += 1


func _on_physics() -> void:
	frames += 1
	if not started:
		started = true
		arena = Node3D.new()
		root.add_child(arena)
		World.floor_box(arena)
		player = World.player(arena, Vector3(5.0, 0.0, 5.0), 0.0)
		svc = _new_service()
		_check(player.global_position.distance_to(Vector3.ZERO) < 0.2, "the player is moved to the chore spot")
		_check(player.model.find_child("ServiceVest", true, false) != null, "the player wears the orange vest")
		_check(svc.supervisor != null and svc.supervisor.state == Officer.State.SUPERVISE, "a supervising officer watches")
		_check(svc.bags.size() == CommunityService.BAGS and svc.total == 8 and is_equal_approx(svc.time_left, CommunityService.TIME_S), "8 bags, 120 s")
		var ring: bool = true
		for b: Node3D in svc.bags:
			var d: float = WeaponMath.flat(b.global_position, svc.center)
			ring = ring and d >= CommunityService.RING_MIN - 0.01 and d <= CommunityService.RING_MAX + 0.01
		_check(ring, "bags lie 4-10 m around the chore spot")
		_check(not svc.has_method("_input") and not svc.has_method("_unhandled_input"), "no input handler: Esc cannot skip the chore")
		svc.set("_line_t", 0.01)
		_next("lines")
		return
	var t: int = frames - t0
	match phase:
		"lines":
			if t == 3:
				_check(CommunityService.LINES.has(svc.supervisor.bubble.text) and svc.supervisor.bubble.visible, "the supervisor says a meme line")
				step_i = 0
				_next("deliver")
		"deliver":
			if done_n == 1:
				_check(step_i == 16, "8 bags in the bin complete the chore (%d steps)" % step_i)
				_next("after")
				return
			if step_i == 0:
				_check(svc.carrying == null, "test setup: empty hands")
			if step_i == 1:
				_check(svc.carrying != null and svc.carrying.get_parent() == player.model, "stepping onto a bag picks it up (carried in front)")
			_deliver(svc, player)
			if t == 60:
				_check(false, "the chore did not complete (%d / %d)" % [svc.delivered, svc.total])
				_next("after")
		"after":
			if t == 2:
				_check(player.model.find_child("ServiceVest", true, false) == null, "the vest comes off")
				svc = _new_service()
				svc.time_left = 0.05
			if t == 8:
				_check(restarts.size() == 1 and restarts[0] == 6 and svc.bags.size() == 6 and svc.delivered == 0, "time out: restarts with 6 bags (%s)" % str(restarts))
				svc.time_left = 0.05
			if t == 14:
				svc.time_left = 0.05
			if t == 20:
				svc.time_left = 0.05
			if t == 26:
				_check(restarts.size() == 4 and restarts[1] == 4 and restarts[2] == 2 and restarts[3] == 2, "... then 4, 2 and never fewer than 2 (%s)" % str(restarts))
				svc.finish()
				_start_b()
		"b":
			_part_b(t)


func _start_b() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var n: Node = (load(pair[1]) as Script).new()
			n.name = pair[0]
			root.add_child(n)
	arena.queue_free()
	roam = (load("res://scenes/FreeRoam.tscn") as PackedScene).instantiate()
	roam.set("crowd_enabled", false)
	root.add_child(roam)
	_next("b")


func _part_b(t: int) -> void:
	var w: WantedDirector = roam.get("wanted")
	var pl: ThirdPersonController = roam.get("player")
	var bike: Node3D = roam.get("bike")
	if t == 60:
		roam.call("mount_bike")
	if t == 64:
		roam.call("dismount_bike")
		_check(bool(roam.get("bike_parked")), "test setup: the bike is parked near BE6")
		w.cine_opts = {"manual": true, "music": false}
		w.stamp_manual = true
		var cc: Vector2 = FPTUCampusBuilder.ring_courtyard_rect().get_center()
		var c3: Vector3 = FPTUCampusBuilder.real_plot_transform() * Vector3(cc.x, 0.0, cc.y)
		var spot: Variant = roam.call("find_free_spot", c3, 0.0, 8)
		pl.teleport((spot if spot is Vector3 else c3) + Vector3(0.0, 0.05, 0.0), 0.0)
	if t == 70:
		w.add_heat(4.0)
		var near: Variant = roam.call("find_free_spot", pl.global_position + Vector3(1.0, 0.0, 0.0), pl.global_position.y, 2)
		w.spawn_officer("guard", near if near is Vector3 else pl.global_position + Vector3(1.0, 0.0, 0.0))
	if t > 70 and w.busts == 1 and w.state == "stamp":
		w.stamp.step_real(1.1)
		var cp: CinePlayer = roam.get("cine_player")
		if cp:
			cp.force_skip_hold = true
			var n: int = 0
			while roam.get("cine_player") != null and n < 200:
				cp.step(1.0 / 60.0)
				n += 1
		var s: CommunityService = w.service
		_check(w.state == "service" and s != null and s.on_campus, "busted on campus -> community service on campus")
		_check(s != null and WeaponMath.flat(pl.global_position, CommunityService.campus_center(roam.get("md"))) < 15.0, "the chore is at the campus parking")
		_check(pl.model.find_child("ServiceVest", true, false) != null, "orange vest on")
		var ww: WeaponWheel = roam.get("weapon_wheel")
		ww.manual = true
		ww.press()
		ww.step_real(0.2)
		_check(not ww.is_open(), "weapons are locked during the chore")
		roam.call("toggle_bike")
		_check(not bool(roam.get("mounted")), "the bike is locked during the chore")
		step_i = 0
		set_meta("svc_t", t)
	if has_meta("svc_t") and w.state == "service":
		_deliver(w.service, pl)
	if has_meta("svc_t") and w.state == "free" and not has_meta("done_b"):
		set_meta("done_b", true)
		_check(w.stars == 0 and w.heat == 0.0, "finishing clears the wanted level")
		_check(WeaponMath.flat(pl.global_position, bike.global_position) < 3.0, "the player is put beside his bike (%.1f m)" % WeaponMath.flat(pl.global_position, bike.global_position))
		set_meta("free_t", t)
	if has_meta("free_t") and t == int(get_meta("free_t")) + 3:
		_check(pl.model.find_child("ServiceVest", true, false) == null, "the vest is gone")
		var ww2: WeaponWheel = roam.get("weapon_wheel")
		ww2.press()
		ww2.step_real(0.2)
		_check(ww2.is_open(), "the weapons are free again")
		ww2.cancel()
		ww2.step_real(0.2)
		_finish()
	if t == 600 and not has_meta("done_b"):
		_check(false, "the FreeRoam service flow did not finish (state %s)" % w.state)
		_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: COMMUNITY SERVICE (vest, bags, bin, supervisor lines, completion, restart with fewer bags, spots, FreeRoam flow with locks and bike placement)")
		quit(0)
	else:
		print("❌ FAILED: %d issues" % fails.size())
		quit(1)
