# File: res://tests/test_free_roam.gd
# Test headless thế giới mở (plan Task 5): nạp scenes/FreeRoam.tscn (dựng xong < 15 s), sau 120 frame vật lý
# người chơi đứng cách điểm spawn BE6 < 2 m và không rơi (y > -1), quay lưng vào toà tháp đúng hướng spawn;
# giữ W 60 frame vật lý -> đi được > 2 m; mount_bike() -> xe hiện, camera chuyển sang xe; dismount_bike();
# dịch người chơi tới 30 m ngoài cổng chính -> không hotspot nào chạm; đặt lên hotspot cổng sau (Màn 2) ->
# Area3D thấy người chơi + gợi ý "[E] Chơi ..."; preset đêm đổi hotspot Lab 402 thành Màn 6; phím M bị chặn ở hub.
# Hồi quy (review 2026-10-22):
#   - [T] đêm -> bình minh -> sáng: ánh sáng môi trường về lại Environment gốc (không dính màu/độ sáng đêm); phong cách
#     Vice City: ambient theo look dawn / day của ViceStyle, Environment gốc không bị sửa.
#   - Lớp "VỀ CAMPUS" của StageManager ẩn khi một cảnh gốc mới vào cây (reload_current_scene của nút Chơi lại),
#     return_to_roam vẫn true và kết quả lượt sau hiện lại nút đó.
#   - Mọi hotspot: tia từ tâm tìm thấy sàn đi được trong 0,5 m bên dưới; đứng ở return_spawn -> đi về phía hotspot thì
#     vào được Area3D, và đi được > 2 m theo một hướng trong 120 frame vật lý, is_on_floor().
#   - Vỉa hè mặt tiền D1 có va chạm (đứng trên đó ở ~0,28 m) và bước từ nền đất qua bó vỉa lên được.
#   - Xe đang đỗ là vật cản; ở xa thì gợi ý "[F] xe máy cách N m", bản đồ [M] vẽ xe.
#   - Sát bờ kênh: xuống xe không bao giờ đặt người lên mặt nước (xe trên mặt nước -> từ chối; xe sát bờ -> xuống phía
#     bờ), đi thẳng vào kênh bị tường bờ chặn.
#   - Cầu đi bộ / đường qua cống mặt thấp trên kênh (4 cầu đi bộ cạnh cầu dân sinh ~(4433..4474, 73..90) + đường qua
#     cống (4251.7, 167.4)): chạy ngang ra mép mặt cầu cả hai bên -> lan can vô hình chặn, không bao giờ rơi xuống kênh.
#   - Lưới an toàn: người chơi / xe đang cưỡi nằm dưới kênh ~1 s -> được đưa về chỗ khô gần nhất + gợi ý.
#   - Menu tạm dừng mở bảng phím vẫn nằm gọn trong 1280 x 720.
#   - Bản đồ [M] hai lớp: lớp tĩnh (mesh 2D cả 143 nhà OSM + 2 548 nhà Microsoft theo đường viền thật, OSM đậm hơn,
#     ghi công OSM + Microsoft) chỉ vẽ ở lần mở đầu, khi hotspot đổi màu và khi đổi kích thước – KHÔNG vẽ lại khi mở
#     lại hay theo nhịp HUD (đếm static_draws); lớp động vẽ lại theo nhịp HUD; đo chi phí một lần vẽ lại lớp động
#     (queue_redraw + 1 frame, và thời gian trong _draw).
# Di chuyển kiểu GTA (plan vice-people Task 8): nhảy ở spawn -> về lại trạng thái GROUND trong 1,5 s, FreeRoam có thanh
# thể lực; mỗi lượt chạy ngang ra mép mặt cầu thấp có thêm bản nước rút + nhảy 1,2 m trước mép (lan can vô hình vẫn chặn).
# Mọi kiểm tra dùng _check() + quit(2) (assert hỏng trong _initialize làm treo --script), có watchdog.
# Chạy:  godot --headless --path . --script tests/test_free_roam.gd
extends SceneTree

const BUILD_BUDGET_MS: int = 15000
const WATCHDOG_FRAMES: int = 20000
const WALK_FRAMES: int = 40          # mỗi lần thử đi từ return_spawn (3 lần = 120 frame vật lý)
## Chỗ tim đường cắt mép nước của các mặt cầu thấp (verifier probe_water2): 4 cầu đi bộ + đường qua cống.
const DECK_POINTS: Array[Vector2] = [Vector2(4433.2, 89.6), Vector2(4432.1, 77.1), Vector2(4474.5, 85.8), Vector2(4473.0, 73.5), Vector2(4251.7, 167.4)]
const DECK_WALK_FRAMES: int = 50     # chạy (7 m/s) ngang ra mép mặt cầu
const DECK_SETTLE_FRAMES: int = 40
const RESCUE_WAIT_FRAMES: int = 80   # > RESCUE_AFTER_S (1 s = 60 frame)
const MAP_HUD_FRAMES: int = 75       # 1,25 s vật lý = 6 nhịp HUD (0,2 s) khi bản đồ đang mở
const MAP_DYNAMIC_BUDGET_USEC: int = 2000   # một lần vẽ lại lớp động (trong _draw) phải dưới 2 ms

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
var md: MapData
var water: Array = []
# hotspot reachability
var hs_list: Array = []
var hs_i: int = 0
var hs_attempt: int = -1
var hs_walked: bool = false
# canal
var canal_n := Vector2.ZERO      # pháp tuyến mép kênh hướng ra bờ (đất)
var canal_mid := Vector2.ZERO
# mặt cầu thấp trên kênh
var deck_walks: Array = []       # [Vector3 start, Vector3 hướng ngang, float nửa bề rộng, Vector2 tim, String nhãn]
var deck_i: int = 0
var deck_min_y: float = 0.0
var jump_y0: float = 0.0
var deck_jumped: bool = false
var jump_peak_y: float = 0.0     # đỉnh y của người chơi trong cú nhảy đang kiểm (nhảy thật phải lên > 0,5 m)
var deck_dry_spot := Vector3.ZERO   # giữa mặt đường qua cống
var deck_wet_spot := Vector3.ZERO   # dưới kênh, cạnh đường qua cống
var rescues0: int = 0
var wall_min_y: float = 99.0     # thấp nhất khi trượt dọc tường bờ kênh (WaterFloor phải nằm ngoài tầm floor snap)
# bản đồ [M]: số lần vẽ lớp tĩnh / động tại các mốc, thời điểm queue_redraw cưỡng bức
var map_s1: int = 0
var map_d0: int = 0
var map_d1: int = 0
var map_t0: int = 0


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	sm = root.get_node("StageManager")
	print("--- TEST FREE ROAM: BE6 spawn, walk, bike, hotspots, reachability, canal, retry overlay ---")
	var packed: PackedScene = load("res://scenes/FreeRoam.tscn")
	if packed == null:
		_fail("scenes/FreeRoam.tscn missing")
		return
	roam = packed.instantiate()
	roam.set("crowd_enabled", false)   # các pha kiểm tra cố định: không người đi đường / xe chạy chen vào
	root.add_child(roam)   # _ready chạy ở frame đầu tiên của vòng lặp (sau _initialize), nên kiểm tra trong _process
	md = MapData.load_default()
	spawn = md.spawn_transform()
	water = MapBuilder._water_polygons(md)
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
	# Gốc lỗi "tụt 30 cm 1 frame khi trượt dọc tường": mặt WaterFloor (WorldBoundary tại y của body) phải thấp hơn sàn đi
	# bộ (y 0) một khoảng LỚN HƠN floor_snap_length của người và xe, nếu không apply_floor_snap có lúc hút thân xuống nó.
	var wf: StaticBody3D = roam.get("water_floor")
	var snap: float = maxf(player.floor_snap_length, bike.floor_snap_length)
	if not _check(wf != null and -wf.global_position.y > snap + 0.02, "water floor sits deeper than the floor snap reach (water floor y %.2f, snap %.2f)" % [wf.global_position.y if wf else 0.0, snap]):
		return false
	if not _check_palms():
		return false
	pf0 = Engine.get_physics_frames()
	return true


## Cọ Vice City (plan VC-2): phong cách vice -> mỗi vùng MapBuilder (vinhomes, corridor, campus) một PalmField có va chạm
## (một StaticBody3D, một CylinderShape3D mỗi cây), không cây nào cách spawn BE6 / một hotspot < 8 m; cổ điển -> không có.
func _check_palms() -> bool:
	var fx: Node = root.get_node_or_null("GameFX")
	var vice: bool = fx == null or String(fx.get("art_style")) == "vice"
	var fields: Array = roam.find_children("PalmField", "Node3D", true, false)
	if not vice:
		return _check(fields.is_empty(), "classic FreeRoam builds no PalmField (got %d)" % fields.size())
	if not _check(fields.size() == 3, "vice FreeRoam: one PalmField per region (got %d)" % fields.size()):
		return false
	var keep: Array[Vector3] = [spawn.origin]
	for h: Area3D in roam.get("hotspots"):
		keep.append(h.global_position)
	var total: int = 0
	var close: int = 0
	for f: Node3D in fields:
		var n: int = int(f.get_meta("palm_count", 0))
		total += n
		var bodies: Array = f.find_children("*", "StaticBody3D", false, false)
		if not _check(bodies.size() == 1 and (bodies[0] as Node).get_child_count() == n, "PalmField %s: one StaticBody3D with %d trunk shapes" % [f.get_path(), n]):
			return false
		var xf: Transform3D = (f.get_parent() as Node3D).global_transform
		for p: Vector3 in (f.get_meta("palm_points", PackedVector3Array()) as PackedVector3Array):
			var w: Vector3 = xf * p
			for k: Vector3 in keep:
				if Vector2(w.x - k.x, w.z - k.z).length() < 8.0:
					close += 1
	print("  vice palms: %d in %d PalmFields, %d within 8 m of the spawn / a hotspot" % [total, fields.size(), close])
	return _check(total > 600 and close == 0, "vice FreeRoam palms: > 600 and none within 8 m of the spawn / hotspots (%d, %d close)" % [total, close])


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


func _space() -> PhysicsDirectSpaceState3D:
	return roam.get_world_3d().direct_space_state


## Tia thẳng đứng a -> b (bỏ qua Area3D và người chơi).
func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var rq := PhysicsRayQueryParameters3D.create(a, b)
	rq.collide_with_areas = false
	rq.exclude = [player.get_rid()]
	return _space().intersect_ray(rq)


func _in_water(p: Vector2) -> bool:
	for poly: PackedVector2Array in water:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Đặt người chơi tại pos, hướng camera/thân theo dir (mặt phẳng ngang) để "tiến" = dir.
func _place_facing(pos: Vector3, dir: Vector3) -> void:
	player.call("teleport", pos, atan2(-dir.x, -dir.z))


## Điểm / hướng trong hệ cục bộ campus (u, y, v) -> thế giới.
func campus_local(p: Vector3) -> Vector3:
	return FPTUCampusBuilder.real_plot_transform() * p


func campus_dir(d: Vector3) -> Vector3:
	return FPTUCampusBuilder.real_plot_transform().basis * d


func _release_input() -> void:
	player.set("input_override", null)
	player.set("sprint_override", false)


## Khoảng cách nhỏ nhất từ p tới tim mọi con đường (dừng sớm khi < limit).
func _near_road(p: Vector2, limit: float) -> bool:
	for r: Dictionary in md.roads():
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		for i: int in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if minf(a.x, b.x) - limit > p.x or maxf(a.x, b.x) + limit < p.x or minf(a.y, b.y) - limit > p.y or maxf(a.y, b.y) + limit < p.y:
				continue
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < limit:
				return true
	return false


## Mép một mặt nước rộng gần spawn BE6, xa đường >= 40 m (không có khe tường): ghi canal_mid + canal_n (ra phía đất).
func _pick_canal_edge() -> bool:
	var cands: Array = []
	var sp := _xz(spawn.origin)
	for poly: PackedVector2Array in water:
		var ring: PackedVector2Array = MapBuilder._open(poly)
		for k: int in range(ring.size()):
			var a: Vector2 = ring[k]
			var b: Vector2 = ring[(k + 1) % ring.size()]
			if a.distance_to(b) < 8.0:
				continue
			var mid: Vector2 = (a + b) * 0.5
			cands.append([mid.distance_to(sp), mid, (b - a).normalized()])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for c: Array in cands:
		var mid: Vector2 = c[1]
		var e: Vector2 = c[2]
		var n := Vector2(-e.y, e.x)
		if _in_water(mid + n * 0.5):
			n = -n
		# đất phía ngoài 0,5..4 m, nước phía trong 0,5..7 m (đủ rộng để xe đứng giữa dòng)
		var ok: bool = true
		for d: float in [0.5, 1.0, 2.0, 3.0, 4.0]:
			if _in_water(mid + n * d):
				ok = false
		for d: float in [0.5, 2.0, 4.5, 7.0]:
			if not _in_water(mid - n * d):
				ok = false
		if not ok:
			continue
		# bờ trống (không nhà / cây sát mép) để đứng và xuống xe
		for d: float in [2.3, 3.0]:
			var q: Vector2 = mid + n * d
			if roam.call("free_spot_at", Vector3(q.x, 0.0, q.y), 0.0) == null:
				ok = false
		if not ok or _near_road(mid, 40.0):
			continue
		canal_mid = mid
		canal_n = n
		return true
	return false


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
				jump_y0 = player.global_position.y
				jump_peak_y = jump_y0
				player.set("jump_override", true)
				mark = pf
				phase = 100
		100:
			jump_peak_y = maxf(jump_peak_y, player.global_position.y)
			if pf >= mark + 90:
				var st: String = String(player.get("move_state"))
				print("  jump at the spawn: state %s, y %.2f (start %.2f, peak %.2f)" % [st, player.global_position.y, jump_y0, jump_peak_y])
				if not _check(jump_peak_y > jump_y0 + 0.5, "a jump at the spawn really leaves the ground (peak %.2f, start %.2f)" % [jump_peak_y, jump_y0]):
					return true
				if not _check(st == "GROUND" and absf(player.global_position.y - jump_y0) < 0.3, "a jump at the spawn lands back on the ground state within 1.5 s"):
					return true
				if not _check(roam.get("stamina_bar") != null, "FreeRoam exposes a stamina bar"):
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
				var gate: Array = md.landmark("campus_main_gate")
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
				if not _phase_tod_and_retry():
					return true
				if not _phase_map_open():
					return true
				mark = pf
				phase = 60
		60:
			if pf >= mark + MAP_HUD_FRAMES:
				if not _phase_map_hud_refreshes():
					return true
				phase = 61
		61:
			# một frame sau queue_redraw cưỡng bức của lớp động
			if not _phase_map_forced_redraw():
				return true
			hs_list = roam.get("hotspots")
			hs_i = 0
			hs_attempt = -1
			phase = 7
		7:
			if not _phase_hotspot_step(pf):
				return true
		75:
			if pf >= mark + 20:
				var y: float = player.global_position.y
				print("  standing on the D1 frontage sidewalk: y = %.3f, on_floor %s" % [y, str(player.is_on_floor())])
				if not _check(absf(y - 0.28) < 0.05 and player.is_on_floor(), "player stands on the frontage sidewalk (y ~0.28, got %.3f) instead of sinking into it" % y):
					return true
				# từ nền đất giữa đường D1 và bó vỉa (v -6,5) đi vào campus: bước qua bó vỉa lên vỉa hè
				_place_facing(campus_local(Vector3(100.0, 0.0, -6.5)), campus_dir(Vector3(0.0, 0.0, 1.0)))
				player.set("input_override", Vector2(0.0, -1.0))
				mark = pf
				phase = 76
		76:
			if pf >= mark + 45:
				var lp: Vector3 = FPTUCampusBuilder.real_plot_transform().affine_inverse() * player.global_position
				_release_input()
				print("  walked from the D1 verge over the granite kerb: local v %.2f, y %.3f" % [lp.z, lp.y])
				if not _check(lp.z > -5.0 and lp.y > 0.2 and player.is_on_floor(), "walking from the verge steps over the kerb onto the sidewalk (local v %.2f, y %.3f)" % [lp.z, lp.y]):
					return true
				phase = 8
		8:
			if not _phase_canal_setup(pf):
				return true
		81:
			if pf >= mark + 15:
				# xe đứng giữa dòng kênh: hai bên đều là nước -> phải từ chối, người chơi vẫn trên xe
				var ok: bool = bool(roam.call("dismount_bike"))
				print("  bike in the canal at %s: dismount -> %s" % [str(bike.global_position), str(ok)])
				if not _check(not ok and bool(roam.get("mounted")), "dismount over water is refused (player stays on the bike)"):
					return true
				var no_room: String = (roam.get_script() as GDScript).get_script_constant_map()["HINT_NO_DISMOUNT"]
				if not _check(String(roam.get("_hint_flash")) == no_room and (roam.get("hint_label") as Label).text == no_room, "refused dismount shows the no-room hint"):
					return true
				# xe lên bờ, cách mép nước 1 m, bên phải xe hướng ra kênh (xuống mặc định bên phải = 0,3 m trong nước)
				var land: Vector2 = canal_mid + canal_n * 1.0
				var w: Vector2 = -canal_n
				bike.global_position = Vector3(land.x, 0.3, land.y)
				bike.rotation = Vector3(0.0, atan2(-w.y, w.x), 0.0)
				bike.velocity = Vector3.ZERO
				mark = pf
				phase = 82
		82:
			if pf >= mark + 15:
				var right: Vector3 = bike.global_transform.basis.x
				if not _check(Vector2(right.x, right.z).dot(-canal_n) > 0.95, "test setup: the bike's right side faces the canal"):
					return true
				var ok: bool = bool(roam.call("dismount_bike"))
				var pp: Vector3 = player.global_position
				print("  bike on the bank at %s: dismount -> %s, player at %s" % [str(bike.global_position), str(ok), str(pp)])
				if not _check(ok and not bool(roam.get("mounted")), "dismount next to the canal succeeds on the bank side"):
					return true
				if not _check(not _in_water(_xz(pp)), "dismount never puts the player inside a water polygon (player at %s)" % str(pp)):
					return true
				if not _check((_xz(pp) - _xz(bike.global_position)).dot(canal_n) > 0.5, "dismount chose the bank side, not the water side"):
					return true
				var hit: Dictionary = _ray(pp + Vector3(0.0, 0.5, 0.0), pp - Vector3(0.0, 1.0, 0.0))
				if not _check(not hit.is_empty() and (hit["position"] as Vector3).y > -0.15, "dismount spot stands on ground, not on the water floor"):
					return true
				# đi thẳng vào kênh (bắt đầu 3 m dọc bờ, tránh xe vừa đỗ): tường bờ chặn
				var t := Vector2(-canal_n.y, canal_n.x)
				var s2: Vector2 = canal_mid + t * 3.0 + canal_n * 1.2
				if not _check(not _in_water(s2), "test setup: walk start on the bank"):
					return true
				_place_facing(Vector3(s2.x, 0.0, s2.y), Vector3(-canal_n.x, 0.0, -canal_n.y))
				player.set("input_override", Vector2(0.0, -1.0))
				player.set("sprint_override", true)
				mark = pf
				phase = 83
		83:
			if pf >= mark + 60:
				var pp: Vector3 = player.global_position
				var bar: ProgressBar = roam.get("stamina_bar")
				var hint_panel: Control = (roam.get("hint_label") as Control).get_parent()
				print("  stamina bar while sprinting: visible %s, value %.0f, rect %s (hint panel %s)" % [str(bar.visible), bar.value, str(bar.get_global_rect()), str(hint_panel.get_global_rect())])
				if not _check(bar.visible and bar.value < 100.0 and absf(bar.value - float(player.get("stamina")) * 100.0) < 2.0, "the stamina bar shows the draining stamina while sprinting (visible %s, value %.0f)" % [str(bar.visible), bar.value]):
					return true
				if not _check(not bar.get_global_rect().intersects(hint_panel.get_global_rect()), "the stamina bar sits above the bottom hint panel, not over it"):
					return true
				_release_input()
				var past: float = -(_xz(pp) - canal_mid).dot(canal_n)
				print("  sprinted 60 frames at the canal from 1.2 m: player at %s (%.2f m past the edge line)" % [str(pp), past])
				if not _check(not _in_water(_xz(pp)) and pp.y > -0.15 and past < 0.0, "bank walls stop the player walking into the canal (%.2f m past the edge)" % past):
					return true
				if not _check(past > -0.8, "the player really walked up to the bank wall (stopped %.2f m before the edge)" % -past):
					return true
				if not _check(roam.call("free_spot_at", Vector3(canal_mid.x - canal_n.x * 2.0, 0.0, canal_mid.y - canal_n.y * 2.0), 0.0) == null, "free_spot_at() rejects a point over water"):
					return true
				phase = 84
		84:
			if not _setup_deck_walks():
				return true
			deck_i = 0
			_start_deck_walk(pf)
			phase = 85
		85:
			var dw: Array = deck_walks[deck_i]
			if dw.size() > 5 and bool(dw[5]) and not deck_jumped:
				var dir3: Vector3 = dw[1]
				var lat: float = (_xz(player.global_position) - (dw[3] as Vector2)).dot(Vector2(dir3.x, dir3.z))
				if lat > float(dw[2]) - 1.2:
					player.set("jump_override", true)
					deck_jumped = true
					jump_peak_y = player.global_position.y
			if deck_jumped:
				jump_peak_y = maxf(jump_peak_y, player.global_position.y)
			deck_min_y = minf(deck_min_y, player.global_position.y)
			if pf >= mark + DECK_WALK_FRAMES and player.get("input_override") != null:
				_release_input()
			if pf >= mark + DECK_WALK_FRAMES + DECK_SETTLE_FRAMES:
				if not _finish_deck_walk():
					return true
				deck_i += 1
				if deck_i < deck_walks.size():
					_start_deck_walk(pf)
				else:
					# lưới an toàn: đứng giữa đường qua cống (chỗ khô), rồi rơi xuống kênh cạnh đó
					player.call("teleport", deck_dry_spot, 0.0)
					mark = pf
					phase = 86
		86:
			if pf >= mark + 10:
				rescues0 = int(roam.get("rescues"))
				player.call("teleport", deck_wet_spot, 0.0)
				mark = pf
				phase = 87
		87:
			if pf >= mark + RESCUE_WAIT_FRAMES:
				var pp: Vector3 = player.global_position
				print("  player dropped into the canal at %s -> rescued to %s (rescues +%d), hint '%s'" % [str(deck_wet_spot), str(pp), int(roam.get("rescues")) - rescues0, (roam.get("hint_label") as Label).text])
				if not _check(int(roam.get("rescues")) == rescues0 + 1, "a player standing in the canal is rescued once within ~1 s"):
					return true
				if not _check(pp.y > -0.15 and _dry_floor_under(pp) and player.is_on_floor(), "rescued player stands on a dry floor (at %s)" % str(pp)):
					return true
				if not _check(_xz(pp).distance_to(_xz(deck_dry_spot)) < 9.0, "rescue lands next to the last dry position (%.1f m away)" % _xz(pp).distance_to(_xz(deck_dry_spot))):
					return true
				var rescued_hint: String = (roam.get_script() as GDScript).get_script_constant_map()["HINT_RESCUED"]
				if not _check((roam.get("hint_label") as Label).text == rescued_hint, "rescue flashes the rescue hint"):
					return true
				# xe đang cưỡi rơi xuống kênh: cũng được đưa lên chỗ khô, vẫn trên xe, xuống xe được
				player.call("teleport", deck_dry_spot, 0.0)
				roam.set("bike_parked", false)
				roam.call("mount_bike")
				mark = pf
				phase = 88
		88:
			if pf >= mark + 10:
				if not _check(bool(roam.get("mounted")), "mount_bike() on the culvert road"):
					return true
				rescues0 = int(roam.get("rescues"))
				bike.global_position = deck_wet_spot + Vector3(0.0, 0.2, 0.0)
				bike.velocity = Vector3.ZERO
				mark = pf
				phase = 89
		89:
			if pf >= mark + RESCUE_WAIT_FRAMES + 10:
				var bp: Vector3 = bike.global_position
				print("  bike ridden into the canal -> rescued to %s (rescues +%d), mounted %s" % [str(bp), int(roam.get("rescues")) - rescues0, str(roam.get("mounted"))])
				if not _check(int(roam.get("rescues")) == rescues0 + 1 and bool(roam.get("mounted")), "a bike in the canal is rescued with the player still riding"):
					return true
				if not _check(not bool(roam.call("is_wet")) and _dry_floor_under(bp + Vector3(0.0, 0.13, 0.0)), "rescued bike stands on a dry floor (at %s)" % str(bp)):
					return true
				var ok: bool = bool(roam.call("dismount_bike"))
				var pp: Vector3 = player.global_position
				if not _check(ok and pp.y > -0.15 and _dry_floor_under(pp), "after the bike rescue the player can get off onto a dry floor (dismount %s, player %s)" % [str(ok), str(pp)]):
					return true
				phase = 95
		9:
			if not _phase_pause_open():
				return true
			mark = frames
			phase = 91
		91:
			if frames >= mark + 4:
				if not _phase_pause_check():
					return true
				phase = 10
		95:
			# Trượt dọc tường bờ kênh: trước đây WaterFloor (WATER_Y) nằm trong tầm floor snap nên thỉnh thoảng thân bị hút
			# xuống 30 cm trong 1 frame. Đứng cách tường 0,75 m, đẩy chéo vào tường 300 frame, y không được dưới -0,05.
			if canal_n == Vector2.ZERO:
				phase = 9
			else:
				if bool(roam.get("mounted")):
					roam.call("dismount_bike")
				var p2: Vector2 = canal_mid + canal_n * 0.75
				_place_facing(Vector3(p2.x, 0.2, p2.y), Vector3(-canal_n.x, 0.0, -canal_n.y))
				wall_min_y = 99.0
				mark = frames
				phase = 96
		96:
			if frames >= mark + 10:
				# camera nhìn thẳng vào tường: x = dọc tường (đổi chiều mỗi 100 frame), y = -0,35 ép nhẹ vào tường
				var along: float = 1.0 if ((frames - mark) / 100) % 2 == 0 else -1.0
				player.set("input_override", Vector2(along, -0.35).normalized())
				player.set("sprint_override", (frames / 60) % 2 == 1)   # đi bộ và chạy xen kẽ
				wall_min_y = minf(wall_min_y, player.global_position.y)
			if frames >= mark + 310:
				_release_input()
				var slid: float = _xz(player.global_position).distance_to(canal_mid + canal_n * 0.75)
				if not _check(slid > 1.5, "wall slide test actually moved the player (%.1f m)" % slid):
					return true
				if not _check(wall_min_y > -0.05, "sliding along a bank wall never snaps the player down to the water floor (min y %.3f)" % wall_min_y):
					return true
				phase = 9
		10:
			done = true
			print("  %d process frames for %d physics frames" % [frames, Engine.get_physics_frames() - pf0])
			print("✅ SUCCESS: FREE ROAM OK (build %d ms, 6 reachable hotspots, bike mount/dismount, canal-safe dismount, low decks guarded + canal rescue, water floor below snap reach + wall slide, night Lab 402 -> Màn 6, retry overlay hidden, map static layer drawn once + dynamic layer at the HUD rate)" % int(roam.get("build_ms")))
			quit(0)
			return true
	return false


# ---------------------------------------------------------------------------
# [T] ĐÊM -> BÌNH MINH -> SÁNG  +  LỚP "VỀ CAMPUS" KHI CHƠI LẠI
# ---------------------------------------------------------------------------
func _phase_tod_and_retry() -> bool:
	var we: WorldEnvironment = roam.get_node("WorldEnvironment")
	var base: Environment = roam.get("_base_env")
	if not _check(base != null, "FreeRoam keeps the scene's base Environment"):
		return false
	var presets: Dictionary = (load("res://scripts/GameFX.gd") as GDScript).get_script_constant_map()["TOD_PRESETS"]
	# Phong cách Vice City (mặc định): mỗi lần đổi giờ dựng Environment mới theo look -> ambient của bình minh / ban ngày
	# là của look đó, không dính màu đêm; Environment gốc không bị sửa. Sau đó chạy lại đúng hồi quy cũ ở phong cách
	# cổ điển (chỉ đổi biến art_style của GameFX, không ghi settings.cfg).
	var fx: Node = root.get_node_or_null("GameFX")
	var saved_style: String = String(fx.get("art_style")) if fx else "vice"
	if fx:
		fx.set("art_style", "vice")
	roam.call("cycle_time_of_day")   # night -> dawn
	var ve: Environment = we.environment
	var vdawn: Dictionary = ViceStyle.params_for("dawn")
	print("  [T] vice night -> %s: ambient %.2f %s" % [String(roam.get("tod_preset")), ve.ambient_light_energy, str(ve.ambient_light_color)])
	if not _check(String(roam.get("tod_preset")) == "dawn" and ve.ambient_light_color.is_equal_approx(vdawn["amb_col"]) and absf(ve.ambient_light_energy - float(vdawn["amb"])) < 0.001, "vice: dawn after night uses the dawn look ambient"):
		return false
	roam.call("cycle_time_of_day")   # dawn -> morning (vice day)
	ve = we.environment
	var vday: Dictionary = ViceStyle.params_for("morning")
	if not _check(String(roam.get("tod_preset")) == "morning" and ve.ambient_light_color.is_equal_approx(vday["amb_col"]) and absf(ve.ambient_light_energy - float(vday["amb"])) < 0.001 and String(roam.get_meta("vice_look", "")) == "day", "vice: morning after dawn uses the day look"):
		return false
	if not _check(base.ambient_light_energy == 1.0 and base != ve, "vice: base Environment itself is never modified"):
		return false
	if fx:
		fx.set("art_style", "classic")
	roam.call("set_time_of_day", "night")
	roam.call("cycle_time_of_day")   # night -> dawn
	var e: Environment = we.environment
	print("  [T] night -> %s: ambient %.2f %s (base %.2f %s)" % [String(roam.get("tod_preset")), e.ambient_light_energy, str(e.ambient_light_color), base.ambient_light_energy, str(base.ambient_light_color)])
	if not _check(String(roam.get("tod_preset")) == "dawn", "T after night cycles to dawn"):
		return false
	if not _check(e.ambient_light_color.is_equal_approx(base.ambient_light_color), "dawn after night: ambient colour is the day colour again (got %s)" % str(e.ambient_light_color)):
		return false
	if not _check(absf(e.ambient_light_energy - float(presets["dawn"]["ambient"])) < 0.001, "dawn ambient energy = its preset value"):
		return false
	roam.call("cycle_time_of_day")   # dawn -> morning
	e = we.environment
	if not _check(String(roam.get("tod_preset")) == "morning" and absf(e.ambient_light_energy - base.ambient_light_energy) < 0.001 and e.ambient_light_color.is_equal_approx(base.ambient_light_color), "morning after night/dawn restores the base ambient energy %.2f (got %.2f)" % [base.ambient_light_energy, e.ambient_light_energy]):
		return false
	if not _check(base.ambient_light_energy == 1.0 and base != e, "base Environment itself is never modified"):
		return false
	if fx:
		fx.set("art_style", saved_style)
	# Lớp VỀ CAMPUS: kết quả màn mở từ thế giới mở -> hiện; "Chơi lại" (reload_current_scene) -> cảnh gốc mới -> ẩn
	var layer: CanvasLayer = sm.get("roam_return_layer")
	sm.set("return_to_roam", true)
	sm.call("report_stage_result", 3, {"result": "win", "score": 100, "rank": "A", "detail": "test"})
	if not _check(layer.visible, "report_stage_result with return_to_roam shows the VỀ CAMPUS overlay"):
		return false
	var fake := Node.new()
	fake.name = "ReloadedStage"
	root.add_child(fake)
	if not _check(layer.visible, "a non-current root child does not hide the overlay"):
		return false
	current_scene = fake
	node_added.emit(fake)   # = reload_current_scene(): current_scene mới vào cây
	if not _check(not layer.visible, "a reloaded current scene hides the VỀ CAMPUS overlay"):
		return false
	if not _check(bool(sm.get("return_to_roam")), "return_to_roam stays true for the replayed run"):
		return false
	sm.call("report_stage_result", 3, {"result": "fail", "score": 0, "rank": "C", "detail": "test"})
	if not _check(layer.visible, "the replayed run's result offers VỀ CAMPUS again"):
		return false
	sm.call("_hide_roam_return")
	sm.set("return_to_roam", false)
	current_scene = null
	fake.queue_free()
	print("  retry flow: VỀ CAMPUS overlay hidden on reload, shown again at the replayed result")
	return true


# ---------------------------------------------------------------------------
# BẢN ĐỒ [M]: LỚP TĨNH VẼ MỘT LẦN, LỚP ĐỘNG THEO NHỊP HUD
# ---------------------------------------------------------------------------
## Pha 5 đã mở + đóng bản đồ một lần (ban đêm) -> lớp tĩnh vẽ đúng 1 lần. Sau đó [T] về ban ngày đổi màu hotspot
## Lab 402 khi bản đồ đang đóng -> lần mở kế tiếp vẽ lại lớp tĩnh đúng 1 lần; đóng rồi mở lại -> không vẽ lại.
func _phase_map_open() -> bool:
	var mo: Control = roam.get("map_overlay")
	var consts: Dictionary = (mo.get_script() as GDScript).get_script_constant_map()
	var n_osm: int = 0
	var n_msft: int = 0
	for b: Dictionary in md.buildings():
		if str(b.get("source", "osm")) == "msft":
			n_msft += 1
		else:
			n_osm += 1
	if not _check(int(mo.get("osm_buildings")) == n_osm and int(mo.get("msft_buildings")) == n_msft and n_msft > 2000, "map draws every building outline: %d OSM + %d Microsoft (data %d + %d)" % [int(mo.get("osm_buildings")), int(mo.get("msft_buildings")), n_osm, n_msft]):
		return false
	if not _check(int(mo.get("triangles")) > (n_osm + n_msft) * 2, "map buildings are real outlines (%d triangles in the static mesh)" % int(mo.get("triangles"))):
		return false
	for region: String in ["vinhomes", "corridor", "campus"]:
		var c_osm: Color = mo.call("building_color", region, false)
		var c_msft: Color = mo.call("building_color", region, true)
		if not _check(c_osm.get_luminance() < c_msft.get_luminance() - 0.05, "%s: OSM buildings are darker than Microsoft ones on the map" % region):
			return false
	var a_osm: String = consts["ATTR_OSM"]
	var a_msft: String = consts["ATTR_MSFT"]
	if not _check(a_osm.contains("OpenStreetMap") and a_osm.contains("ODbL") and a_msft.contains("Microsoft") and a_msft.contains("CDLA-Permissive-2.0"), "map legend keeps the ODbL line and adds the Microsoft line"):
		return false
	var s0: int = int(mo.get("static_draws"))
	if not _check(s0 == 1, "the first map open drew the static layer once (static_draws %d)" % s0):
		return false
	roam.call("toggle_map")   # mở: hotspot Lab 402 đã đổi màu (đêm -> ngày) khi bản đồ đóng
	map_s1 = int(mo.get("static_draws"))
	if not _check(mo.visible and map_s1 == s0 + 1, "reopening after the Lab 402 hotspot changed colour redraws the static layer once (static_draws %d -> %d)" % [s0, map_s1]):
		return false
	roam.call("toggle_map")
	roam.call("toggle_map")
	if not _check(mo.visible and int(mo.get("static_draws")) == map_s1, "closing and reopening the map does not redraw the static layer (static_draws %d)" % int(mo.get("static_draws"))):
		return false
	if not _check(not (roam.get("hint_holder") as Control).visible, "the bottom hint panel hides while the map is open (no overlap with the map credits)"):
		return false
	map_d0 = int(mo.get("dynamic_draws"))
	return true


## Bản đồ mở suốt MAP_HUD_FRAMES frame vật lý (~6 nhịp HUD): lớp động vẽ lại theo nhịp, lớp tĩnh không vẽ lại.
## Rồi xếp một lần vẽ lại cưỡng bức lớp động để đo ở frame sau.
func _phase_map_hud_refreshes() -> bool:
	var mo: Control = roam.get("map_overlay")
	var dyn: int = int(mo.get("dynamic_draws")) - map_d0
	print("  map open for %d physics frames: dynamic layer redrawn %d x, static layer draws %d" % [MAP_HUD_FRAMES, dyn, int(mo.get("static_draws"))])
	if not _check(int(mo.get("static_draws")) == map_s1, "HUD refreshes never redraw the static map layer (static_draws %d, expected %d)" % [int(mo.get("static_draws")), map_s1]):
		return false
	if not _check(dyn >= 4, "the dynamic map layer redraws at the HUD rate (%d redraws in %d physics frames)" % [dyn, MAP_HUD_FRAMES]):
		return false
	var dl: Control = mo.get("dynamic_layer")
	# Giữ nhịp HUD của FreeRoam (0,2 s) đứng yên tới lần đo ở frame sau: headless chạy ~145 fps nên đôi khi một nhịp
	# HUD rơi đúng vào khoảng đo và vẽ lớp động thêm lần nữa (test chập chờn). Như vậy chỉ lần vẽ cưỡng bức được đếm.
	roam.set("_hud_timer", 1.0e9)
	# đổi tên biến trong FreeRoam thì set() lặng lẽ không làm gì và test chập chờn trở lại: kiểm luôn
	var hud_t: Variant = roam.get("_hud_timer")
	if not _check(hud_t != null and float(hud_t) > 1e8,"FreeRoam._hud_timer exists and holds the HUD tick for the forced-redraw window"):
		return false
	map_d1 = int(mo.get("dynamic_draws"))
	map_t0 = Time.get_ticks_usec()
	dl.queue_redraw()
	return true


## Một frame sau queue_redraw cưỡng bức: lớp động vẽ đúng 1 lần, rẻ (< MAP_DYNAMIC_BUDGET_USEC trong _draw); lớp tĩnh
## vẫn không vẽ lại. Đổi kích thước bản đồ -> lớp tĩnh vẽ lại đúng 1 lần mỗi lần đổi.
func _phase_map_forced_redraw() -> bool:
	var frame_us: int = Time.get_ticks_usec() - map_t0
	var mo: Control = roam.get("map_overlay")
	var draw_us: int = int(mo.get("dynamic_draw_usec"))
	roam.set("_hud_timer", 0.0)   # nhịp HUD chạy lại từ frame vật lý kế tiếp
	print("  map dynamic redraw: %.3f ms in _draw, %.2f ms for queue_redraw + one frame; static layer: %d triangles built once in %.1f ms at load, last draw %.2f ms, %d draws" % [draw_us / 1000.0, frame_us / 1000.0, int(mo.get("triangles")), int(mo.get("setup_usec")) / 1000.0, int(mo.get("static_draw_usec")) / 1000.0, int(mo.get("static_draws"))])
	if not _check(int(mo.get("dynamic_draws")) == map_d1 + 1, "a forced dynamic redraw draws the dynamic layer once within one frame (%d -> %d)" % [map_d1, int(mo.get("dynamic_draws"))]):
		return false
	if not _check(draw_us < MAP_DYNAMIC_BUDGET_USEC, "the dynamic map redraw costs < %.1f ms (got %.3f ms)" % [MAP_DYNAMIC_BUDGET_USEC / 1000.0, draw_us / 1000.0]):
		return false
	if not _check(int(mo.get("static_draws")) == map_s1, "the forced dynamic redraw leaves the static layer alone"):
		return false
	mo.offset_right -= 40.0
	if not _check(int(mo.get("static_draws")) == map_s1 + 1, "resizing the open map redraws the static layer once (static_draws %d)" % int(mo.get("static_draws"))):
		return false
	mo.offset_right += 40.0
	if not _check(int(mo.get("static_draws")) == map_s1 + 2, "resizing back redraws the static layer once more (static_draws %d)" % int(mo.get("static_draws"))):
		return false
	roam.call("toggle_map")
	return _check(not mo.visible and (roam.get("hint_holder") as Control).visible, "M closes the map and brings the hint panel back")


# ---------------------------------------------------------------------------
# HOTSPOT ĐI TỚI ĐƯỢC
# ---------------------------------------------------------------------------
func _phase_hotspot_step(pf: int) -> bool:
	if hs_i >= hs_list.size():
		_release_input()
		# vỉa hè mặt tiền D1 (cục bộ u 100, v -2,7; đỉnh 0,28 m): thả người chơi từ 0,6 m
		_place_facing(campus_local(Vector3(100.0, 0.6, -2.7)), campus_dir(Vector3(0.0, 0.0, 1.0)))
		mark = pf
		phase = 75
		return true
	var h: Area3D = hs_list[hs_i]
	var rs: Transform3D = h.get_meta("return_spawn")
	if hs_attempt == -1:
		var c: Vector3 = h.global_position
		var hit: Dictionary = _ray(c + Vector3(0.0, 0.25, 0.0), c - Vector3(0.0, 0.5, 0.0))
		if not _check(not hit.is_empty(), "%s: no floor within 0.5 m below its centre %s" % [h.name, str(c)]):
			return false
		var hp: Vector3 = hit["position"]
		if not _check((hit["normal"] as Vector3).y > 0.7 and hp.y >= c.y - 0.5 and hp.y > -0.15, "%s: walkable floor (not water) below its centre (hit %s)" % [h.name, str(hp)]):
			return false
		if not _check(absf(rs.origin.y - c.y) < 0.5 and Vector2(rs.origin.x - c.x, rs.origin.z - c.z).length() < 9.0, "%s: return_spawn %s is at ground level next to the hotspot" % [h.name, str(rs.origin)]):
			return false
		hs_walked = false
		hs_attempt = 0
		_start_attempt(h, rs, pf)
		return true
	if pf < mark + WALK_FRAMES:
		return true
	var moved: Vector3 = player.global_position - rs.origin
	moved.y = 0.0
	var on_floor: bool = player.is_on_floor()
	if hs_attempt == 0:
		var inside: bool = h.overlaps_body(player)
		print("  %s: return_spawn %s -> walked %.2f m toward it, inside=%s, on_floor=%s" % [h.name, str(rs.origin), moved.length(), str(inside), str(on_floor)])
		if not _check(inside, "%s: walking from its return_spawn toward it enters the hotspot (player at %s)" % [h.name, str(player.global_position)]):
			return false
	if moved.length() > 2.0 and on_floor:
		hs_walked = true
	if hs_walked or hs_attempt >= 2:
		if not _check(hs_walked, "%s: from return_spawn %s the player cannot walk > 2 m on the floor in 120 physics frames (last %.2f m, on_floor %s)" % [h.name, str(rs.origin), moved.length(), str(on_floor)]):
			return false
		hs_i += 1
		hs_attempt = -1
		_release_input()
		return true
	hs_attempt += 1
	_start_attempt(h, rs, pf)
	return true


## Lần thử 0: về phía tâm hotspot; 1: ngược lại (về phía sân / mốc); 2: vuông góc.
func _start_attempt(h: Area3D, rs: Transform3D, pf: int) -> void:
	var to_h: Vector3 = h.global_position - rs.origin
	to_h.y = 0.0
	to_h = to_h.normalized() if to_h.length_squared() > 0.001 else Vector3(0.0, 0.0, -1.0)
	var dir: Vector3 = to_h
	if hs_attempt == 1:
		dir = -to_h
	elif hs_attempt == 2:
		dir = Vector3(-to_h.z, 0.0, to_h.x)
	_place_facing(rs.origin, dir)
	player.set("input_override", Vector2(0.0, -1.0))
	player.set("sprint_override", true)
	mark = pf


# ---------------------------------------------------------------------------
# XE ĐỖ + BỜ KÊNH
# ---------------------------------------------------------------------------
func _phase_canal_setup(pf: int) -> bool:
	# xe đang đỗ ở BE6 (từ pha 3), người chơi ở campus: gợi ý khoảng cách, F không lên xe, bản đồ vẽ xe, xe là vật cản
	if not _check(bool(roam.get("bike_parked")) and not bool(roam.get("mounted")), "bike parked after the first dismount"):
		return false
	if not _check(bike.disable_mode == CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE, "parked bike keeps its collision (DISABLE_MODE_KEEP_ACTIVE)"):
		return false
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	sq.shape = sph
	sq.transform = Transform3D(Basis.IDENTITY, bike.global_transform * Vector3(0.0, 0.55, 0.0))
	var solid: bool = false
	for r: Dictionary in _space().intersect_shape(sq, 8):
		if r.get("collider") == bike:
			solid = true
	if not _check(solid, "parked bike is solid (a shape query at its body finds it)"):
		return false
	roam.call("_physics_process", 1.0)
	var n_m: int = int(roam.call("bike_distance_m"))
	var hint: String = (roam.get("hint_label") as Label).text
	print("  parked bike %d m away: hint '%s'" % [n_m, hint])
	if not _check(hint.contains("[F] xe máy cách %d m" % n_m), "out of range the hint shows '[F] xe máy cách %d m'" % n_m):
		return false
	roam.call("toggle_bike")
	if not _check(not bool(roam.get("mounted")) and (roam.get("hint_label") as Label).text.contains("cách %d m" % n_m), "F out of range does not mount and says how far the bike is"):
		return false
	roam.call("toggle_map")
	roam.call("_physics_process", 1.0)
	var mo: Control = roam.get("map_overlay")
	if not _check(bool(mo.get("bike_shown")) and (mo.get("bike_pos") as Vector2).distance_to(_xz(bike.global_position)) < 0.5, "M map draws the parked bike"):
		return false
	roam.call("toggle_map")
	roam.set("_hint_flash_t", 0.0)
	# bờ kênh gần BE6
	if not _check(_pick_canal_edge(), "test setup: found a canal edge near BE6 away from roads"):
		return false
	print("  canal edge at %s, bank normal %s" % [str(canal_mid), str(canal_n)])
	var land: Vector2 = canal_mid + canal_n * 3.0
	_place_facing(Vector3(land.x, 0.0, land.y), Vector3(-canal_n.x, 0.0, -canal_n.y))
	roam.set("bike_parked", false)   # lấy xe ngay tại chỗ người chơi
	roam.call("mount_bike")
	if not _check(bool(roam.get("mounted")), "mount_bike() at the canal"):
		return false
	var wet: Vector2 = canal_mid - canal_n * 4.5
	bike.global_position = Vector3(wet.x, 0.3, wet.y)
	var w: Vector2 = -canal_n
	bike.rotation = Vector3(0.0, atan2(-w.y, w.x), 0.0)
	bike.velocity = Vector3.ZERO
	mark = pf
	phase = 81
	return true


# ---------------------------------------------------------------------------
# MẶT CẦU THẤP TRÊN KÊNH: CHẠY NGANG RA MÉP + LƯỚI AN TOÀN
# ---------------------------------------------------------------------------
## Chỗ tim một con đường cắt mép nước gần t (< 2 m): [điểm cắt, hướng đường vào nước, hướng đường, nửa bề rộng].
func _deck_crossing(t: Vector2) -> Array:
	var best: Array = []
	var best_d: float = 2.0
	for r: Dictionary in md.roads():
		var pts: PackedVector2Array = MapData.poly(r.get("points", []))
		var w: float = float(r.get("width", 6.0))
		if int(r.get("lanes", 2)) <= 0:
			w = clampf(w, 1.5, 2.5)
		for i: int in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(t, pts[i], pts[i + 1]).distance_to(t) > 3.0:
				continue
			for poly: PackedVector2Array in water:
				var ring: PackedVector2Array = MapBuilder._open(poly)
				for k: int in range(ring.size()):
					var a: Vector2 = ring[k]
					var b: Vector2 = ring[(k + 1) % ring.size()]
					if Geometry2D.get_closest_point_to_segment(t, a, b).distance_to(t) > 3.0:
						continue
					var x: Variant = Geometry2D.segment_intersects_segment(a, b, pts[i], pts[i + 1])
					if x == null or (x as Vector2).distance_to(t) >= best_d:
						continue
					var rd: Vector2 = (pts[i + 1] - pts[i]).normalized()
					var into: Vector2 = rd if _in_water((x as Vector2) + rd * 1.5) else -rd
					best_d = (x as Vector2).distance_to(t)
					best = [x, into, rd, w * 0.5]
	return best


## Mỗi mặt cầu thấp: đứng giữa mặt cầu 2,5 m trong mép nước, chạy ngang ra hai bên (cầu đi bộ đầu tiên: thêm 1 m
## trong mép nước để thử góc lan can / tường bờ).
func _setup_deck_walks() -> bool:
	deck_walks.clear()
	for di: int in range(DECK_POINTS.size()):
		var c: Array = _deck_crossing(DECK_POINTS[di])
		if not _check(not c.is_empty(), "test setup: a road crosses the water edge at %s" % str(DECK_POINTS[di])):
			return false
		var x: Vector2 = c[0]
		var into: Vector2 = c[1]
		var rd: Vector2 = c[2]
		var hw: float = c[3]
		for dist_in: float in ([1.0, 2.5] if di == 0 else [2.5]):
			var centre: Vector2 = x + into * dist_in
			if not _check(_in_water(centre), "test setup: deck point %s lies over water" % str(centre)):
				return false
			var hit: Dictionary = _ray(Vector3(centre.x, 2.5, centre.y), Vector3(centre.x, -1.0, centre.y))
			if not _check(not hit.is_empty() and (hit["position"] as Vector3).y > -0.15, "test setup: low deck floor at %s (hit %s)" % [str(centre), str(hit.get("position"))]):
				return false
			var dy: float = (hit["position"] as Vector3).y
			for sg: float in [1.0, -1.0]:
				var side: Vector2 = Vector2(-rd.y, rd.x) * sg
				deck_walks.append([Vector3(centre.x, dy + 0.05, centre.y), Vector3(side.x, 0.0, side.y), hw, centre, "%s in %.1f side %+.0f" % [str(DECK_POINTS[di]), dist_in, sg]])
			if di == DECK_POINTS.size() - 1 and dist_in == 2.5:
				deck_dry_spot = Vector3(centre.x, dy + 0.05, centre.y)
				var wet: Vector2 = centre + Vector2(-rd.y, rd.x) * (hw + 1.5)
				if not _check(_in_water(wet), "test setup: canal point %s next to the culvert road" % str(wet)):
					return false
				deck_wet_spot = Vector3(wet.x, -0.25, wet.y)
	var n_plain: int = deck_walks.size()
	for i: int in range(n_plain):
		var jw: Array = (deck_walks[i] as Array).duplicate()
		jw[4] = String(jw[4]) + " + jump"
		jw.append(true)   # index 5: jump 1.2 m before the edge
		deck_walks.append(jw)
	print("  %d sideways walks off low decks over water" % deck_walks.size())
	return true


## Sàn ngay dưới p (tia 0,4 m lên -> 0,4 m xuống) là sàn khô: có, cao hơn mức nước + 0,15, không phải WaterFloor.
func _dry_floor_under(p: Vector3) -> bool:
	var rq := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 0.4, 0.0), p - Vector3(0.0, 0.4, 0.0))
	rq.collide_with_areas = false
	rq.exclude = [player.get_rid(), bike.get_rid()]
	var hit: Dictionary = _space().intersect_ray(rq)
	return not hit.is_empty() and (hit["position"] as Vector3).y > -0.15 and hit.get("collider") != roam.get("water_floor")


func _start_deck_walk(pf: int) -> void:
	var w: Array = deck_walks[deck_i]
	_place_facing(w[0], w[1])
	player.set("input_override", Vector2(0.0, -1.0))
	player.set("sprint_override", true)
	deck_min_y = (w[0] as Vector3).y
	deck_jumped = false
	mark = pf


func _finish_deck_walk() -> bool:
	_release_input()
	var w: Array = deck_walks[deck_i]
	var p: Vector3 = player.global_position
	var dir: Vector3 = w[1]
	var hw: float = w[2]
	var lateral: float = (_xz(p) - (w[3] as Vector2)).dot(Vector2(dir.x, dir.z))
	print("  deck %s: min y %.2f, end %s, %.2f m sideways (half width %.1f)" % [String(w[4]), deck_min_y, str(p.snappedf(0.01)), lateral, hw])
	if w.size() > 5 and bool(w[5]):
		print("    jump peak %.2f (deck %.2f)" % [jump_peak_y, (w[0] as Vector3).y - 0.05])
		if not _check(deck_jumped, "deck %s: the walk asked for a jump but none was triggered" % String(w[4])):
			return false
		if not _check(jump_peak_y > (w[0] as Vector3).y - 0.05 + 0.5, "deck %s: the jump really left the deck (peak %.2f)" % [String(w[4]), jump_peak_y]):
			return false
	if not _check(deck_min_y > -0.15 and p.y > -0.15, "deck %s: running sideways off a low deck never drops the player into the canal (min y %.2f)" % [String(w[4]), deck_min_y]):
		return false
	# cú nhảy không được đưa người chơi lên đứng trên đỉnh lan can vô hình (từ đó bước ra ngoài là rơi xuống kênh)
	if not _check(p.y < (w[0] as Vector3).y + 0.3, "deck %s: the player ends standing on the deck, not on top of the invisible guard (y %.2f, deck %.2f)" % [String(w[4]), p.y, (w[0] as Vector3).y - 0.05]):
		return false
	return _check(lateral > hw - 0.65 and lateral < hw, "deck %s: the player ran up to the invisible edge guard at the ribbon edge (%.2f m sideways, half width %.1f)" % [String(w[4]), lateral, hw])


# ---------------------------------------------------------------------------
# MENU TẠM DỪNG + BẢNG PHÍM TRONG 1280 x 720
# ---------------------------------------------------------------------------
func _phase_pause_open() -> bool:
	root.size = Vector2i(1280, 720)
	sm.call("pause_game")
	var scroll: Control = sm.get("pause_controls_scroll")
	if not _check(scroll is ScrollContainer, "pause controls live in a ScrollContainer"):
		return false
	scroll.visible = true
	return true


func _phase_pause_check() -> bool:
	var vp: Rect2 = root.get_visible_rect()
	var scroll: ScrollContainer = sm.get("pause_controls_scroll")
	var layer: CanvasLayer = sm.get("pause_layer")
	var bad: Array = []
	var menu_found: bool = false
	for b: Node in layer.find_children("*", "Button", true, false):
		var btn: Button = b
		if not btn.is_visible_in_tree():
			continue
		var r: Rect2 = btn.get_global_rect()
		if btn.text.contains("VỀ MENU CHÍNH"):
			menu_found = true
			print("  pause menu with controls open: 'VỀ MENU CHÍNH' at %s (viewport %s, controls box %.0f px high)" % [str(r), str(vp), scroll.size.y])
		if r.position.y < vp.position.y - 1.0 or r.end.y > vp.end.y + 1.0:
			bad.append("%s %s" % [btn.text, str(r)])
	sm.call("resume_game")
	if not _check(menu_found, "pause menu has the VỀ MENU CHÍNH button"):
		return false
	var cap: float = float((sm.get_script() as GDScript).get_script_constant_map()["PAUSE_CONTROLS_MAX_H"])
	if not _check(scroll.size.y <= cap + 1.0, "controls box height is capped at %.0f (got %.0f)" % [cap, scroll.size.y]):
		return false
	return _check(bad.is_empty(), "pause menu buttons stay inside 1280x720 with the controls open: %s" % str(bad))
