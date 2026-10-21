# File: res://tests/test_rain_fog.gd
# Test headless cơn mưa Màn 1 (RoadEvents._update_rain) với sương của cả hai phong cách đồ hoạ:
#   vice    : Environment do ViceStyle dựng dùng FOG_MODE_DEPTH (fog_density = độ đặc tối đa, 1.0 lúc bình minh).
#             Mưa phải làm sương DÀY lên = kéo fog_depth_begin/end lại gần, giữ fog_density; tạnh mưa trả đúng
#             fog_density / fog_depth_begin / fog_depth_end / fog_depth_curve như trước mưa.
#   classic : sương mũ (FOG_MODE_EXPONENTIAL): mưa tăng fog_density, tạnh mưa trả về đúng fog_density trước mưa.
# Phong cách đặt qua GameFX.set_art_style(style, false) (không ghi user://settings.cfg).
# RoadEvents lấy WorldEnvironment từ get_tree().current_scene lúc setup; ở --script current_scene chưa có khi
# RoadManager._ready chạy (trong game, đổi cảnh gán current_scene trước add_child) -> test nối world_env bằng tay.
# Chạy:  godot --headless --path . --script tests/test_rain_fog.gd
extends SceneTree

const STYLES: Array[String] = ["vice", "classic"]
const RAIN_WAIT: float = 1.6     # > tween bắt đầu mưa 1.2 s
const DRY_WAIT: float = 2.0      # > tween tạnh mưa 1.5 s

var frames: int = 0
var step: int = 0
var style_idx: int = 0
var timer: float = 0.0
var stage: Node = null
var events: Node = null
var env: Environment = null
var before: Dictionary = {}


func _initialize() -> void:
	for pair: Array in [["StageManager", "res://scripts/StageManager.gd"], ["GameFX", "res://scripts/GameFX.gd"]]:
		if not root.has_node(pair[0]):
			var s: Script = load(pair[1])
			var n: Node = s.new()
			n.name = pair[0]
			root.add_child(n)
	print("--- TEST RAIN FOG (Màn 1, vice + classic) ---")


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		print("❌ FAILED: ", msg)
		quit(1)
		return false
	return true


func _snap(e: Environment) -> Dictionary:
	return {"mode": e.fog_mode, "density": e.fog_density, "begin": e.fog_depth_begin, "end": e.fog_depth_end, "curve": e.fog_depth_curve}


func _fmt(d: Dictionary) -> String:
	return "mode=%d density=%.5f begin=%.1f end=%.1f curve=%.2f" % [int(d["mode"]), float(d["density"]), float(d["begin"]), float(d["end"]), float(d["curve"])]


func _same(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(1e-6, absf(b) * 1e-3)


func _process(delta: float) -> bool:
	frames += 1
	timer += delta
	match step:
		0:
			if frames < 3:
				return false
			var style: String = STYLES[style_idx]
			var fx: Node = root.get_node_or_null("GameFX")
			if not _check(fx != null and fx.has_method("set_art_style"), "GameFX autoload missing set_art_style"):
				return true
			fx.call("set_art_style", style, false)
			stage = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
			root.add_child(stage)
			current_scene = stage
			step = 1
			timer = 0.0
		1:
			if timer < 0.2:
				return false
			var style: String = STYLES[style_idx]
			var we: WorldEnvironment = stage.get_node_or_null("WorldEnvironment") as WorldEnvironment
			events = stage.get_node("RoadSystem").get("road_events")
			if not _check(we != null and we.environment != null and events != null, "Main.tscn without WorldEnvironment/RoadEvents"):
				return true
			events.set("world_env", we)
			env = we.environment
			before = _snap(env)
			print("  [%s] before rain: %s" % [style, _fmt(before)])
			if style == "vice":
				if not _check(int(before["mode"]) == Environment.FOG_MODE_DEPTH, "vice Stage 1 fog is not FOG_MODE_DEPTH"):
					return true
			elif not _check(int(before["mode"]) == Environment.FOG_MODE_EXPONENTIAL, "classic Stage 1 fog is not exponential"):
				return true
			events.set("rain_possible", true)
			events.set("rain_done", false)
			events.call("_update_rain", float(events.get("rain_from")) + 1.0)
			if not _check(bool(events.get("is_raining")), "rain did not start"):
				return true
			step = 2
			timer = 0.0
		2:
			if timer < RAIN_WAIT:
				return false
			var style: String = STYLES[style_idx]
			var mid: Dictionary = _snap(env)
			print("  [%s] during rain: %s" % [style, _fmt(mid)])
			if style == "vice":
				# thicker = fog reaches full opacity much closer; max opacity unchanged
				if not _check(_same(float(mid["density"]), float(before["density"])), "vice rain changed fog_density (max opacity) %.5f -> %.5f" % [float(before["density"]), float(mid["density"])]):
					return true
				if not _check(float(mid["end"]) < float(before["end"]) * 0.5 and float(mid["begin"]) < float(before["begin"]), "vice rain did not thicken the depth fog (%s)" % _fmt(mid)):
					return true
			elif not _check(float(mid["density"]) > float(before["density"]) * 2.0, "classic rain did not thicken the fog (%s)" % _fmt(mid)):
				return true
			events.call("_update_rain", float(events.get("rain_to")) + 1.0)
			if not _check(not bool(events.get("is_raining")) and bool(events.get("rain_done")), "rain did not stop"):
				return true
			step = 3
			timer = 0.0
		3:
			if timer < DRY_WAIT:
				return false
			var style: String = STYLES[style_idx]
			var after: Dictionary = _snap(env)
			print("  [%s] after rain:  %s" % [style, _fmt(after)])
			for k: String in ["density", "begin", "end", "curve"]:
				if not _check(_same(float(after[k]), float(before[k])), "[%s] fog %s after rain %.5f != before %.5f" % [style, k, float(after[k]), float(before[k])]):
					return true
			stage.queue_free()
			current_scene = null
			stage = null
			style_idx += 1
			if style_idx >= STYLES.size():
				var fx: Node = root.get_node_or_null("GameFX")
				fx.call("set_art_style", "vice", false)
				print("✅ SUCCESS: RAIN FOG THICKENS AND RESTORES IN VICE (DEPTH) AND CLASSIC (EXPONENTIAL)")
				quit(0)
				return true
			step = 0
			frames = 0
	return false
