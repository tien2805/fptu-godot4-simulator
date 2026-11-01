# File: res://tests/test_look_presets.gd
# Headless test of the Q3 look presets (plan 2026-10-29-q3-look.md Task 1):
#   A: every preset over a ViceStyle night environment: its values written on a copy, the base environment untouched, the
#      key light's colour / energy / shadow opacity, the fill light shown or hidden; restore = the very base environment
#      and the key's own values back;
#   B: base layer + stack: set_base night_city, push tokyo_drift, pop -> night_city, set_base "" -> the base environment;
#   C: the scene rebuilds its environment (GameFX.upgrade_scene_visuals -> ViceStyle.apply + refresh): the preset is written
#      over the NEW environment, its base is the new one, the key's newer values come back at the end;
#   D: LookZone hysteresis (enter 110 m, stays until 150 m) and pop when it leaves the tree;
#   E: owners without a WorldEnvironment / a plain Node: no errors, no fill; quality 0 drops glow levels 3-4.
# Run: godot --headless --path . --script tests/test_look_presets.gd
extends SceneTree

const GameFXScript: Script = preload("res://scripts/GameFX.gd")

var done: bool = false
var started: bool = false
var holder: Node3D   # test owners live under it (GameFX treats new root children as scenes)


func _initialize() -> void:
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if started or done:
		return
	started = true
	holder = Node3D.new()
	root.add_child(holder)
	for part: Callable in [_part_a, _part_b, _part_c, _part_d, _part_e]:
		if not part.call():
			return
	done = true
	print("SUCCESS: look presets apply over ViceStyle, stack and restore exactly, survive rebuilds, zones switch with hysteresis")
	quit(0)


func _check(ok: bool, msg: String) -> bool:
	if not ok and not done:
		done = true
		print("FAILED: ", msg)
		quit(1)
	return ok


func _make_owner(tod: String = "night") -> Node3D:
	var o := Node3D.new()
	o.name = "Owner"
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	o.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	o.add_child(sun)
	holder.add_child(o)
	GameFXScript.upgrade_scene_visuals(o, tod)   # no /root/GameFX: the vice path (ViceStyle.apply)
	return o


func _env(o: Node) -> Environment:
	return (o.get_node("WorldEnvironment") as WorldEnvironment).environment


func _sun(o: Node) -> DirectionalLight3D:
	return o.get_node("DirectionalLight3D") as DirectionalLight3D


func _env_matches(e: Environment, p: Dictionary) -> bool:
	return is_equal_approx(e.tonemap_exposure, float(p["exposure"])) and is_equal_approx(e.glow_hdr_threshold, float(p["thr"])) \
		and is_equal_approx(e.glow_intensity, float(p["glow"])) and e.fog_light_color.is_equal_approx(p["fog"]) \
		and is_equal_approx(e.fog_depth_end, float(p["fog_end"])) and is_equal_approx(e.adjustment_contrast, float(p["contrast"])) \
		and is_equal_approx(e.adjustment_saturation, float(p["sat"])) and e.ambient_light_color.is_equal_approx(p["amb_col"]) \
		and e.fog_enabled and e.glow_enabled


# ---------------------------------------------------------------------------
func _part_a() -> bool:
	var o: Node3D = _make_owner()
	var base: Environment = _env(o)
	var base_exp: float = base.tonemap_exposure
	var base_thr: float = base.glow_hdr_threshold
	var sun: DirectionalLight3D = _sun(o)
	var sun0: Dictionary = {"col": sun.light_color, "energy": sun.light_energy, "shadow": sun.shadow_opacity}
	if not _check(LookPresets.names().size() == 12, "12 presets expected, got %d" % LookPresets.names().size()):
		return false
	for n: String in ["night_city", "tokyo_drift", "port_night", "server_red", "canal_night", "penthouse", "campus_day", "campus_horror", "server_blackout", "server_sprinkler",
			"penthouse_blackout", "rooftop_rain"]:   # Day 7 (w4-day7): the blackout and the rooftop rain
		if not _check(LookPresets.has(n), "missing preset " + n):
			return false
		var p: Dictionary = LookPresets.PRESETS[n]
		# conservative ranges (no screenshots: values must stay sane)
		if not _check(float(p["exposure"]) >= 0.9 and float(p["exposure"]) <= 1.2 and float(p["thr"]) >= 1.2 and float(p["glow"]) <= 1.0 \
				and float(p["contrast"]) <= 1.2 and float(p["sat"]) <= 1.3 and float(p["fog_density"]) <= 1.0, "%s: values out of the safe range" % n):
			return false
		LookPresets.apply(n, o)
		var e: Environment = _env(o)
		if not _check(e != base and _env_matches(e, p), "%s: environment values not written" % n):
			return false
		if not _check(e.sky == base.sky and e.adjustment_color_correction == base.adjustment_color_correction, "%s: sky / LUT not shared with the base" % n):
			return false
		if not _check(is_equal_approx(base.tonemap_exposure, base_exp) and is_equal_approx(base.glow_hdr_threshold, base_thr), "%s: base environment modified" % n):
			return false
		if p.has("key"):
			var k: Dictionary = p["key"]
			if not _check(sun.light_color.is_equal_approx(k["col"]) and is_equal_approx(sun.light_energy, float(k["energy"])), "%s: key light not set" % n):
				return false
		elif not _check(sun.light_color.is_equal_approx(sun0["col"]), "%s: key light changed without a key" % n):
			return false
		var fill: DirectionalLight3D = LookPresets.fill_light(o)
		if not _check(fill != null and fill.visible == p.has("fill") and not fill.shadow_enabled, "%s: fill light wrong" % n):
			return false
		if p.has("fill") and not _check(fill.light_color.is_equal_approx((p["fill"] as Dictionary)["col"]), "%s: fill colour" % n):
			return false
		LookPresets.restore(o, n)
		if not _check(_env(o) == base and LookPresets.active(o) == "", "%s: restore did not bring the base environment back" % n):
			return false
		if not _check(sun.light_color.is_equal_approx(sun0["col"]) and is_equal_approx(sun.light_energy, float(sun0["energy"])) \
				and is_equal_approx(sun.shadow_opacity, float(sun0["shadow"])), "%s: key light not restored" % n):
			return false
		if not _check(not fill.visible, "%s: fill still visible after restore" % n):
			return false
	print("  A: 8 presets apply on a copy and restore exactly")
	o.free()
	return true


func _part_b() -> bool:
	var o: Node3D = _make_owner()
	var base: Environment = _env(o)
	LookPresets.set_base(o, "night_city")
	LookPresets.apply("tokyo_drift", o)
	if not _check(LookPresets.active(o) == "tokyo_drift" and _env_matches(_env(o), LookPresets.PRESETS["tokyo_drift"]), "stack top not rendered"):
		return false
	LookPresets.apply("port_night", o)
	LookPresets.restore(o, "tokyo_drift")   # pop from the middle: port_night stays on top
	if not _check(LookPresets.active(o) == "port_night", "pop by name took the wrong entry"):
		return false
	LookPresets.restore(o)
	if not _check(LookPresets.active(o) == "night_city" and _env_matches(_env(o), LookPresets.PRESETS["night_city"]), "pop did not fall back to the base preset"):
		return false
	LookPresets.restore(o)   # empty stack: no-op
	LookPresets.apply("nonsense", o)
	if not _check(LookPresets.active(o) == "night_city", "unknown preset changed the stack"):
		return false
	LookPresets.set_base(o, "")
	if not _check(_env(o) == base and LookPresets.active(o) == "", "set_base('') did not bring the base environment back"):
		return false
	print("  B: base layer + stack push / pop")
	o.free()
	return true


func _part_c() -> bool:
	var o: Node3D = _make_owner()
	LookPresets.set_base(o, "night_city")
	var first: Environment = _env(o)
	# the scene rebuilds (time of day change): ViceStyle builds a NEW environment, GameFX refreshes the preset over it
	GameFXScript.upgrade_scene_visuals(o, "morning")
	var e: Environment = _env(o)
	var base2: Environment = o.get_meta("look_base_env") as Environment
	if not _check(e != first and _env_matches(e, LookPresets.PRESETS["night_city"]), "preset lost after an environment rebuild"):
		return false
	if not _check(base2 != null and is_equal_approx(base2.tonemap_exposure, float(ViceStyle.params_for("morning")["exposure"])), "rebuilt environment not taken as the new base"):
		return false
	var sun: DirectionalLight3D = _sun(o)
	var day_energy: float = float(ViceStyle.params_for("morning")["energy"])
	LookPresets.set_base(o, LookPresets.for_roam_tod("morning"))
	if not _check(LookPresets.active(o) == "campus_day" and is_equal_approx(sun.light_energy, 1.5), "campus_day key not set"):
		return false
	LookPresets.set_base(o, "")
	if not _check(_env(o) == base2 and is_equal_approx(sun.light_energy, day_energy), "after a rebuild the newest base / key did not come back (energy %.2f, want %.2f)" % [sun.light_energy, day_energy]):
		return false
	if not _check(LookPresets.for_roam_tod("night") == "night_city" and LookPresets.for_roam_tod("dawn") == "", "roam time-of-day mapping"):
		return false
	print("  C: refresh over a rebuilt environment, newest key values restored")
	o.free()
	return true


func _part_d() -> bool:
	var o: Node3D = _make_owner()
	var base: Environment = _env(o)
	var z: LookZone = LookZone.make(o, "port_night", Vector3(100.0, 0.0, 100.0), 110.0, 150.0)
	o.add_child(z)
	z.check(Vector3(400.0, 0.0, 100.0))
	if not _check(not z.inside and LookPresets.active(o) == "", "zone active far away"):
		return false
	z.check(Vector3(150.0, 0.0, 100.0))
	if not _check(z.inside and LookPresets.active(o) == "port_night", "zone not active inside"):
		return false
	z.check(Vector3(230.0, 0.0, 100.0))   # 130 m: between enter and exit
	if not _check(z.inside, "zone flickered off inside the hysteresis band"):
		return false
	z.check(Vector3(260.0, 0.0, 100.0))
	if not _check(not z.inside and _env(o) == base, "zone did not pop past exit_r"):
		return false
	z.check(Vector3(100.0, 0.0, 100.0))
	z.free()
	if not _check(LookPresets.active(o) == "" and _env(o) == base, "zone leaving the tree did not pop its preset"):
		return false
	print("  D: LookZone hysteresis + pop on exit")
	o.free()
	return true


func _part_e() -> bool:
	var bare := Node3D.new()
	holder.add_child(bare)
	LookPresets.apply("night_city", bare)
	LookPresets.restore(bare)
	var plain := Node.new()
	holder.add_child(plain)
	LookPresets.set_base(plain, "server_red")
	if not _check(LookPresets.fill_light(plain) == null and LookPresets.active(plain) == "server_red", "plain Node owner"):
		return false
	LookPresets.set_base(plain, "")
	# basement case: no sun of its own; a quality change re-runs ViceStyle, which must not take LookFill for the sun
	var cave := Node3D.new()
	var cwe := WorldEnvironment.new()
	cwe.name = "WorldEnvironment"
	cwe.environment = Environment.new()
	cave.add_child(cwe)
	holder.add_child(cave)
	LookPresets.set_base(cave, "server_red")
	GameFXScript.upgrade_scene_visuals(cave, "night")
	var cf: DirectionalLight3D = LookPresets.fill_light(cave)
	var fill_ok: bool = cf != null and not cf.shadow_enabled and is_zero_approx(cf.light_indirect_energy) 		and is_equal_approx(cf.light_energy, float(LookPresets.PRESETS["server_red"]["fill"]["energy"])) and LookPresets.active(cave) == "server_red"
	cave.free()
	if not _check(fill_ok, "LookFill turned into a sun after ViceStyle.apply in a scene without a sun"):
		return false
	bare.free()
	plain.free()
	# quality 0: the GameFX autoload's visual_quality (set directly: set_visual_quality would save the owner's settings)
	var fx: Node = root.get_node_or_null("GameFX")
	if not _check(fx != null, "GameFX autoload missing"):
		return false
	var q0: int = int(fx.get("visual_quality"))
	fx.set("visual_quality", 0)
	var o: Node3D = _make_owner()
	LookPresets.apply("night_city", o)
	var e: Environment = _env(o)
	var ok: bool = is_zero_approx(e.get_glow_level(3)) and is_zero_approx(e.get_glow_level(4)) and e.get_glow_level(1) > 0.0
	fx.set("visual_quality", q0)
	o.free()
	if not _check(ok, "quality 0 did not drop glow levels 3-4"):
		return false
	print("  E: owners without an environment, quality 0 glow")
	return true
