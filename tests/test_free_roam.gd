# File: res://tests/test_free_roam.gd
# Test headless thế giới mở (plan Task 5): nạp scenes/FreeRoam.tscn (dựng xong < 15 s), sau 120 frame vật lý
# người chơi đứng cách điểm spawn BE6 < 2 m và không rơi (y > -1), quay lưng vào toà tháp đúng hướng spawn;
# giữ W 60 frame vật lý -> đi được > 2 m; mount_bike() -> xe hiện, camera chuyển sang xe; dismount_bike();
# dịch người chơi tới 30 m ngoài cổng chính -> không hotspot nào chạm; đặt lên hotspot cổng sau (Màn 2) ->
# Area3D thấy người chơi + gợi ý "[E] Chơi ..."; preset đêm đổi hotspot Lab 402 thành Màn 6; phím M bị chặn ở hub.
# Mọi kiểm tra dùng _check() + quit(2) (assert hỏng trong _initialize làm treo --script), có watchdog.
# Chạy:  godot --headless --path . --script tests/test_free_roam.gd
extends SceneTree

const BUILD_BUDGET_MS: int = 15000
const WATCHDOG_FRAMES: int = 4000

var roam: Node3D
var player: CharacterBody3D
var bike: CharacterBody3D
var sm: Node
var started: bool = false
var done: bool = false
var frames: int = 0
var phase: int = -1
var pf0: int = 0
var mark: int = 0
var spawn: Transform3D
var walk_start: Vector3
var gate_hot: Area3D


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	sm = root.get_node("StageManager")
	print("--- TEST FREE ROAM: BE6 spawn, walk, bike, hotspots ---")
	var packed: PackedScene = load("res://scenes/FreeRoam.tscn")
	if packed == null:
		_fail("scenes/FreeRoam.tscn missing")
		return
	roam = packed.instantiate()
	root.add_child(roam)   # _ready chạy ở frame đầu tiên của vòng lặp (sau _initialize), nên kiểm tra trong _process
	spawn = MapData.load_default().spawn_transform()
	started = true


## Frame đầu tiên sau khi FreeRoam._ready chạy: thời gian dựng, player/bike, enum FREE_ROAM.
func _after_ready() -> bool:
	var build: int = int(roam.get("build_ms"))
	print("  FreeRoam._ready built the world in %d ms" % build)
	if not _check(build > 0 and build < BUILD_BUDGET_MS, "FreeRoam._ready must build in < %d ms (got %d)" % [BUILD_BUDGET_MS, build]):
		return false
	player = roam.get("player")
	bike = roam.get("bike")
	if not _check(player != null and bike != null, "FreeRoam exposes player and bike"):
		return false
	if not _check(player is ThirdPersonController, "player is a ThirdPersonController"):
		return false
	if not _check(player.get_node_or_null("Model") != null, "player has a CharacterBuilder model child"):
		return false
	var ids: Dictionary = (sm.get_script() as GDScript).get_script_constant_map()["StageID"]
	if not _check(ids.has("FREE_ROAM") and (sm.get("stage_scenes") as Dictionary).has(int(ids["FREE_ROAM"])), "StageManager.stage_scenes has FREE_ROAM"):
		return false
	pf0 = Engine.get_physics_frames()
	return true


func _check(ok: bool, msg: String) -> bool:
	if not ok:
		_fail(msg)
	return ok


func _fail(msg: String) -> void:
	if done:
		return
	done = true
	print("❌ FAILED: ", msg)
	quit(2)


func _cam_inside(n: Node) -> bool:
	var cam: Camera3D = root.get_camera_3d()
	return cam != null and n.is_ancestor_of(cam)


func _process(_delta: float) -> bool:
	if not started or done:
		return done
	frames += 1
	if frames > WATCHDOG_FRAMES:
		_fail("watchdog: test did not finish (phase %d)" % phase)
		return true
	if phase == -1:
		if int(roam.get("build_ms")) <= 0:
			return false   # _ready chưa chạy
		if not _after_ready():
			return true
		phase = 0
		return false
	var pf: int = Engine.get_physics_frames() - pf0
	match phase:
		0:
			if pf >= 120:
				var d: float = player.global_position.distance_to(spawn.origin)
				print("  after 120 physics frames: player at %s (%.2f m from spawn)" % [str(player.global_position), d])
				if not _check(d < 2.0, "player stays within 2 m of the spawn (got %.2f)" % d):
					return true
				if not _check(player.global_position.y > -1.0, "player did not fall through the ground"):
					return true
				var facing: Vector3 = player.call("facing_dir")
				var want: Vector3 = -spawn.basis.z
				if not _check(facing.dot(want) > 0.95, "player faces away from the tower (spawn yaw)"):
					return true
				walk_start = player.global_position
				Input.action_press("move_forward")
				mark = pf
				phase = 1
		1:
			if pf >= mark + 60:
				Input.action_release("move_forward")
				var moved: Vector3 = player.global_position - walk_start
				moved.y = 0.0
				print("  walked %.2f m in 60 physics frames (speed %.2f m/s)" % [moved.length(), float(player.get("horizontal_speed"))])
				if not _check(moved.length() > 2.0, "W for 60 frames moves the player > 2 m (got %.2f)" % moved.length()):
					return true
				if not _check(moved.normalized().dot(-spawn.basis.z) > 0.8, "W moves along the camera/spawn forward"):
					return true
				roam.call("mount_bike")
				mark = pf
				phase = 2
		2:
			if pf >= mark + 3:
				if not _check(bool(roam.get("mounted")) and bike.visible, "mount_bike(): bike visible"):
					return true
				if not _check(bike.process_mode != Node.PROCESS_MODE_DISABLED, "mount_bike(): bike processes"):
					return true
				if not _check(_cam_inside(bike), "mount_bike(): current camera belongs to the bike"):
					return true
				if not _check(not player.visible, "mount_bike(): player hidden"):
					return true
				print("  mounted: bike at %s, camera parent %s" % [str(bike.global_position), root.get_camera_3d().get_parent().name])
				roam.call("dismount_bike")
				mark = pf
				phase = 3
		3:
			if pf >= mark + 3:
				if not _check(not bool(roam.get("mounted")) and player.visible, "dismount_bike(): player visible again"):
					return true
				if not _check(_cam_inside(player), "dismount_bike(): current camera belongs to the player"):
					return true
				if not _check(player.global_position.y > -1.0, "player on the ground after dismount"):
					return true
				var gate: Array = MapData.load_default().landmark("campus_main_gate")
				var g := Vector3(float(gate[0]), 0.0, float(gate[1]))
				var far_pos: Vector3 = g + Vector3(0.0, 0.0, 30.0)
				player.call("teleport", far_pos, 0.0)
				mark = pf
				phase = 4
		4:
			if pf >= mark + 3:
				var hs: Array = roam.get("hotspots")
				if not _check(hs.size() == 6, "6 hotspots (got %d)" % hs.size()):
					return true
				var names: Array = []
				for h: Area3D in hs:
					names.append(h.name)
					if not _check(h.name.begins_with("Hotspot_"), "hotspot node name Hotspot_<StageID>"):
						return true
				print("  hotspots: ", names)
				var any_overlap: bool = false
				for h: Area3D in hs:
					if h.get_overlapping_bodies().has(player):
						any_overlap = true
				if not _check(not any_overlap and roam.get("active_hotspot") == null, "30 m outside the main gate: no hotspot overlaps"):
					return true
				gate_hot = roam.get_node_or_null("Hotspots/Hotspot_STAGE_2_PARKING")
				if not _check(gate_hot != null, "Hotspot_STAGE_2_PARKING exists at the back gate"):
					return true
				player.call("teleport", gate_hot.global_position + Vector3(0.5, 0.0, 0.0), 0.0)
				mark = pf
				phase = 5
		5:
			if pf >= mark + 3:
				var bodies: Array = gate_hot.get_overlapping_bodies()
				if not _check(bodies.has(player), "back-gate hotspot sees the player (overlapping bodies: %s)" % str(bodies)):
					return true
				roam.call("_physics_process", 1.0)
				if not _check(roam.get("active_hotspot") == gate_hot, "active_hotspot is the back-gate hotspot"):
					return true
				var hint: String = (roam.get("hint_label") as Label).text
				print("  hint: ", hint)
				if not _check(hint.begins_with("[E] Chơi") and hint.contains("MÀN 2"), "HUD hint offers [E] Chơi MÀN 2"):
					return true
				if not _check(bool(sm.get("hub_key_blocked")), "StageManager.hub_key_blocked while roaming"):
					return true
				var lab: Area3D = roam.get_node_or_null("Hotspots/Hotspot_STAGE_3_CLASSROOM")
				if not _check(lab != null, "Lab 402 hotspot is Màn 3 by day"):
					return true
				roam.call("set_time_of_day", "night")
				if not _check(String(roam.get("tod_preset")) == "night" and roam.get_meta("visual_preset", "") == "night", "set_time_of_day(night) applied"):
					return true
				if not _check(roam.get_node_or_null("Hotspots/Hotspot_STAGE_6_CAPSTONE") != null, "Lab 402 hotspot becomes Màn 6 at night"):
					return true
				roam.call("toggle_map")
				if not _check((roam.get("map_overlay") as Control).visible, "M map overlay toggles on"):
					return true
				roam.call("toggle_map")
				mark = pf
				phase = 6
		6:
			if pf >= mark + 2:
				done = true
				print("✅ SUCCESS: FREE ROAM OK (build %d ms, 6 hotspots, bike mount/dismount, night Lab 402 -> Màn 6)" % int(roam.get("build_ms")))
				quit(0)
				return true
	return false
