# File: res://tests/test_stage1_events.gd
# Headless test of the Wave 2 Stage 1 set pieces (plan 2026-10-29-w2-early.md Task 2; RoadSetPieces): the real-route
# Main scene, the bike moved along the route by the test (no autopilot):
#   A layout: bus < flood < jam on the route, the flood 180 m with 4 ranks of stalled bikes each leaving a gap of at
#     least stall_gap(), the jam ranks leave the kerb squeeze and an inner gap, the warning sign;
#   B bus: blinkers flash before it moves (telegraph >= 1.2 s at 20 m/s), it pulls into the lane at bus_trigger_m() with a
#     preview cut, it is a slipstream vehicle while it drives, then back to the kerb;
#   C flood: a preview cut before the water; in it the speed is pulled down to flood_cap(), spray from the bike, a splash
#     burst on entry, the deep kerb pocket caps lower and splashes again; out of the water the spray stops;
#   D the stage music slot stays stage1_race through the events;
#   E Dễ: more time (REV.stage_time), wider gaps, a gentler water cap, the bus pulls out earlier.
# Run:  godot --headless --path . --script tests/test_stage1_events.gd
extends SceneTree

var stage: Node3D
var bike: CharacterBody3D
var road: Node3D
var ev: Node
var sp: Node
## class_name scripts that use the GameFX autoload by name are loaded at run time (after the autoload nodes exist).
var RSP: GDScript
var REV: GDScript
var curve: Curve3D
var fails: Array[String] = []
var frames: int = 0
var phase: int = 0
var off: float = 0.0
var lat: float = 2.0
var mark: Dictionary = {}


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		print("  ✗ ", msg)


func _initialize() -> void:
	print("--- TEST STAGE 1 SET PIECES (bus cut-in, flooded street, traffic jam) ---")
	Engine.max_fps = 60
	Difficulty.set_easy(false)
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	RSP = load("res://scripts/RoadSetPieces.gd")
	REV = load("res://scripts/RoadEvents.gd")



## Built on the first frame, after the autoloads' _ready (GameFX loads the owner's difficulty after _initialize).
func _build() -> void:
	Difficulty.set_easy(false)
	stage = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	bike = stage.get_node("PlayerBike")
	road = stage.get_node("RoadSystem")


## Puts the bike on the route at (off, lat) facing along it, with a speed (the bike's own physics then runs one frame).
func _put(o: float, l: float, speed: float) -> void:
	var xf: Transform3D = curve.sample_baked_with_rotation(clampf(o, 0.0, curve.get_baked_length() - 0.1))
	bike.global_transform = Transform3D(xf.basis, xf.origin + xf.basis.x * l + Vector3(0.0, 0.3, 0.0))
	bike.velocity = Vector3.ZERO
	bike.set("current_speed_ms", speed)


func _music_slot() -> String:
	var fx: Node = root.get_node_or_null("GameFX")
	var md: Node = fx.get("music") if fx else null
	return String(md.get("slot")) if md else ""


func _process(_d: float) -> bool:
	frames += 1
	if frames > 60 * 120:
		_check(false, "timeout in phase %d" % phase)
		return _end()
	if stage == null:
		_build()
		return false
	match phase:
		0:
			if frames < 4:
				return false
			curve = (road.get_node("RoadTrack/RoadPath") as Path3D).curve
			ev = road.get("road_events")
			sp = ev.get("set_pieces") if ev else null
			_check(sp != null, "RoadEvents built the set pieces")
			if sp == null:
				return _end()
			for a: String in ["gas", "brake", "steer_left", "steer_right", "drift"]:
				Input.action_release(a)
			_layout()
			off = sp.bus_at - 130.0
			lat = 1.8
			phase = 1
		1:   # B: the bus
			off += 20.0 / 60.0
			_put(off, lat, 20.0)
			if sp.bus_state == "blink" and not mark.has("blink_at"):
				mark["blink_at"] = off
			if sp.bus_state == "blink" and sp._blinkers[0].visible:
				mark["blink_seen"] = true
			if sp.bus_state == "pull" and not mark.has("pull_at"):
				mark["pull_at"] = off
				mark["lat0"] = sp.bus_lat
				_check(sp.cuts == 1, "a preview cut on the bus as it pulls out (cuts %d)" % sp.cuts)
				var d: CameraDirector = CameraDirector.live()
				_check(d == null or d.cutting() or d.cuts >= 1, "the camera director ran the cut")
			if sp.bus_state == "drive" and not mark.has("drive"):
				mark["drive"] = true
				_check(sp.bus.is_in_group("slipstream_vehicle"), "the bus is a slipstream vehicle while it drives")
				_check(sp.bus_lat < float(mark.get("lat0", 99.0)) - 1.2 and sp.bus_lat < 0.5, "the bus moved across the right lane (%.1f -> %.1f m)" % [float(mark.get("lat0", 0.0)), sp.bus_lat])
				off = sp.bus_s - 25.0   # follow it a bit (slipstream distance)
			if mark.has("drive"):
				off = sp.bus_s - 25.0
				lat = sp.bus_lat
			if sp.bus_state == "done" or frames > 60 * 40:
				_check(sp.bus_state == "done", "the bus went back to the kerb (%s)" % sp.bus_state)
				var tele_m: float = float(mark.get("pull_at", 0.0)) - float(mark.get("blink_at", 0.0))
				_check(mark.has("blink_seen") and tele_m / 20.0 >= 1.2, "blinkers flash %.1f s before it moves (>= 1.2 s at 20 m/s)" % (tele_m / 20.0))
				_check(absf((sp.bus_at - float(mark.get("pull_at", 0.0))) - RSP.bus_trigger_m()) < 1.0, "it pulls out %.0f m ahead (Thường %.0f)" % [sp.bus_at - float(mark.get("pull_at", 0.0)), RSP.bus_trigger_m()])
				off = sp.flood_from - 140.0
				lat = float(sp.ranks[0]["gap"])
				mark["cuts_before_flood"] = sp.cuts
				phase = 2
				frames = 0
		2:   # C: the flood, through the first gap
			if RadialWheel.scale_owner == null:
				Engine.time_scale = 1.0
			var v: float = 22.0 if off < sp.flood_from else float(bike.get("current_speed_ms"))
			off += maxf(v, 4.0) / 60.0
			_put(off, lat, v)
			if off > sp.flood_from - 1.0 and not mark.has("cut_flood"):
				mark["cut_flood"] = true
				_check(sp.cuts == int(mark["cuts_before_flood"]) + 1, "a preview cut before the water (cuts %d)" % sp.cuts)
				_check(_music_slot() == "stage1_race", "the stage music keeps playing (%s)" % _music_slot())
			if off > sp.flood_from + 25.0 and not mark.has("in_water"):
				mark["in_water"] = true
				_check(sp.in_flood and not sp.deep, "in the water, in the shallow middle")
				_check(float(bike.get("speed_cap")) <= sp.flood_cap(false) + 0.6, "the bike's own speed cap holds the water speed (%.1f)" % float(bike.get("speed_cap")))
				_check(float(bike.get("current_speed_ms")) <= sp.flood_cap(false) + 0.6, "the water pulls the speed down to the cap (%.1f <= %.1f m/s)" % [float(bike.get("current_speed_ms")), sp.flood_cap(false)])
				_check(sp.spray.emitting and sp.flood_entries == 1, "spray behind the bike, one entry splash")
				var hw: float = float(road.call("half_width_at", off))
				lat = hw - 0.6   # into the deep kerb pocket
			if off > sp.flood_from + 28.0 and not mark.has("deep"):
				if sp.deep:
					mark["deep"] = true
					_check(sp.deep_splashes >= 1, "the deep pocket splashes")
					_check(sp.flood_cap(true) < sp.flood_cap(false) - 2.0, "the deep pocket caps lower (%.1f < %.1f)" % [sp.flood_cap(true), sp.flood_cap(false)])
					lat = float(sp.ranks[1]["gap"])
			if off > sp.flood_to + 12.0:
				_check(mark.has("deep"), "reached a deep pocket")
				_check(not sp.in_flood and not sp.spray.emitting, "out of the water: no spray")
				phase = 3
		3:   # F: review round: traffic keeps out of the set pieces, one crash per body per 1.5 s, the score on the base clock
			var spawner: Node = stage.get_node_or_null("TrafficSpawner")
			var inside: int = 0
			var ranges: Array = sp.blocked_ranges()
			for a: Variant in (spawner.get("active_buses") as Array) if spawner else []:
				var prog: float = float((a.follower as PathFollow3D).progress)
				for r: Vector2 in ranges:
					if prog > r.x + 0.5 and prog < r.y - 0.5:
						inside += 1
			_check(spawner != null and ranges.size() >= 2 and inside == 0, "no traffic follower inside the jam / flood / bus spans (%d inside)" % inside)
			_check(RSP.bus_speed() >= 11.0, "the cut-in bus rolls at %.1f m/s (overtake or draft)" % RSP.bus_speed())
			var crashes: Array[int] = [0]
			bike.crash_occurred.connect(func() -> void: crashes[0] += 1)
			var car: Node = get_nodes_in_group("jam_car")[0]
			for k: int in 5:
				bike.set("current_speed_ms", 15.0)
				bike.call("_on_obstacle_hit", car)
			_check(crashes[0] == 1, "scraping one car five times in a row counts one crash (%d)" % crashes[0])
			_check(is_inf(float(bike.get("speed_cap"))), "the water cap is off out of the flood")
			phase = 4
		4:   # E: Dễ
			Difficulty.set_easy(true)
			_check(is_equal_approx(REV.stage_time(300.0), 345.0), "Dễ: 345 s on the clock (%.0f)" % REV.stage_time(300.0))
			_check(RSP.stall_gap() > 2.4 and RSP.jam_squeeze() > 1.8 and RSP.water_k() > 0.6 and RSP.bus_trigger_m() > 50.0,
				"Dễ: wider gaps, a gentler cap, the bus earlier")
			Difficulty.set_easy(false)
			_check(is_equal_approx(REV.stage_time(300.0), 294.0), "Thường: 294 s on the clock (%.0f)" % REV.stage_time(300.0))
			return _end()
	return false


func _layout() -> void:
	var tl: float = curve.get_baked_length()
	_check(sp.bus_at > 300.0 and sp.bus_at < sp.jam_from and sp.jam_to < sp.flood_from and sp.flood_to < tl - 200.0,
		"bus %.0f < jam %.0f < flood %.0f on the %.0f m route" % [sp.bus_at, sp.jam_from, sp.flood_from, tl])
	_check(is_equal_approx(sp.flood_to - sp.flood_from, RSP.FLOOD_LEN), "the flood is 180 m")
	_check(sp.ranks.size() == 4, "4 ranks of stalled bikes")
	var bikes: Array = get_nodes_in_group("stalled_bike")
	_check(bikes.size() >= 16, "%d stalled bikes" % bikes.size())
	for r: Dictionary in sp.ranks:
		var o: float = float(r["offset"])
		var g: float = float(r["gap"])
		var nearest: float = 99.0
		for b: Node in bikes:
			var bo: float = curve.get_closest_offset((b as Node3D).global_position)
			if absf(bo - o) > 1.5:
				continue
			var xf: Transform3D = curve.sample_baked_with_rotation(bo)
			var bl: float = ((b as Node3D).global_position - xf.origin).dot(xf.basis.x)
			nearest = minf(nearest, absf(bl - g))
		_check(nearest * 2.0 - 0.7 >= RSP.stall_gap() - 0.05, "rank at %.0f: free gap %.2f m (>= %.2f)" % [o, nearest * 2.0 - 0.7, RSP.stall_gap()])
	var cars: Array = get_nodes_in_group("jam_car")
	_check(cars.size() >= 6, "%d stopped cars in the jam" % cars.size())
	for ri: int in RSP.JAM_RANKS:
		var o2: float = sp.jam_from + RSP.JAM_STEP * float(ri)
		var hw: float = float(road.call("half_width_at", o2))
		var lats: Array[float] = []
		for c: Node in cars:
			var co: float = curve.get_closest_offset((c as Node3D).global_position)
			if absf(co - o2) > 2.5:
				continue
			var xf2: Transform3D = curve.sample_baked_with_rotation(co)
			lats.append(((c as Node3D).global_position - xf2.origin).dot(xf2.basis.x))
		lats.sort()
		var squeeze: float = hw - (lats.back() + RSP.CAR_W * 0.5) if not lats.is_empty() else 99.0
		var best_gap: float = 0.0
		for i: int in range(1, lats.size()):
			best_gap = maxf(best_gap, lats[i] - lats[i - 1] - RSP.CAR_W)
		_check(squeeze >= RSP.jam_squeeze() - 0.05, "jam rank %d (half width %.1f m, %d cars): kerb squeeze %.2f m" % [ri, hw, lats.size(), squeeze])
		if int(RSP.JAM_GAP_AFTER[ri]) >= 0:
			_check(best_gap >= RSP.jam_gap() - 0.05, "jam rank %d: inner gap %.2f m" % [ri, best_gap])
		_check(lats.size() >= 2, "jam rank %d: %d cars across" % [ri, lats.size()])


func _end() -> bool:
	Difficulty.set_easy(false)
	Engine.time_scale = 1.0
	if fails.is_empty():
		print("✅ SUCCESS: STAGE 1 SET PIECES (bus cut-in with a preview cut, the flooded street, the jam, Dễ tuning)")
		quit(0)
	else:
		print("❌ FAILED: %d check(s)" % fails.size())
		quit(1)
	return true
