# File: res://tests/test_vice_style.gd
# Test headless ViceStyle (plan docs/superpowers/plans/2026-10-22-vice-city-art-direction.md, Task VC-1):
#   cảnh tối thiểu = WorldEnvironment + DirectionalLight3D + 1 nhân vật (CharacterBuilder, có viền toon) + 1 toà nhà
#   Vinhomes (MapBuilder.build_building, mặt tiền có normal map) + 1 khối có vật liệu phát sáng yếu (emission 0.3).
#   ViceStyle.apply(scene, "morning") -> Environment vice (không SDFGI, sương DEPTH, LUT 3D 32³, glow), vật liệu lì
#   (không next_pass, không normal map), vật liệu phát sáng yếu tắt ban ngày / bật ban đêm, áp lại không cộng dồn,
#   bảng preset -> look, restore_classic() trả Environment gốc, GameFX.upgrade_scene_visuals() rẽ nhánh sang vice khi
#   không có autoload (mặc định "vice").
# Chạy:  godot --headless --path . --script tests/test_vice_style.gd
extends SceneTree

var scene: Node3D
var we: WorldEnvironment
var base_env: Environment
var sun: DirectionalLight3D
var soft_mat: StandardMaterial3D
var bright_mat: StandardMaterial3D
var flash_mat: StandardMaterial3D
var building: Node3D
var frames: int = 0


func _initialize() -> void:
	scene = Node3D.new()
	scene.name = "ViceTestScene"
	root.add_child(scene)
	we = WorldEnvironment.new()
	base_env = Environment.new()
	base_env.sdfgi_enabled = true
	we.environment = base_env
	scene.add_child(we)
	sun = DirectionalLight3D.new()
	scene.add_child(sun)
	var ch: Node3D = CharacterBuilder.build({"preset": "student_m", "seed": 11})
	scene.add_child(ch)
	var md: MapData = MapData.load_default()
	var b0: Dictionary = md.buildings("vinhomes")[0]
	building = MapBuilder.build_building(scene, b0, {"labels": false, "colliders": false})
	soft_mat = _box_with_emission(Vector3(4.0, 0.5, 0.0), 0.3)
	bright_mat = _box_with_emission(Vector3(6.0, 0.5, 0.0), 2.0)
	flash_mat = _box_with_emission(Vector3(8.0, 0.5, 0.0), 0.0)   # hit-flash (Màn 4): năng lượng 0, tween lên khi trúng đòn
	print("--- TEST VICE STYLE: building %s (style %s) ---" % [str(b0.get("id", 0)), str(b0.get("style", ""))])


func _box_with_emission(pos: Vector3, energy: float) -> StandardMaterial3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.4, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.3)
	m.emission_energy_multiplier = energy
	mi.material_override = m
	mi.position = pos
	scene.add_child(mi)
	return m


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		print("❌ FAILED: ", msg)
		quit(1)
	return cond


## Mọi vật liệu (duy nhất) gắn trên GeometryInstance3D dưới `n`: material_override, surface override, vật liệu của mesh.
func _materials(n: Node, out: Array, seen: Dictionary) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var list: Array = [gi.material_override]
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var mi := gi as MeshInstance3D
			for si: int in range(mi.mesh.get_surface_count()):
				list.append(mi.get_surface_override_material(si))
				list.append(mi.mesh.surface_get_material(si))
		for m: Variant in list:
			if m is Material and not seen.has(m):
				seen[m] = true
				out.append(m)
	for c: Node in n.get_children():
		_materials(c, out, seen)


func _all_materials() -> Array:
	var out: Array = []
	_materials(scene, out, {})
	return out


func _process(_d: float) -> bool:
	frames += 1
	if frames != 2:
		return false
	# --- trước khi áp: nhân vật có viền toon (next_pass), mặt tiền có normal map
	var before: Array = _all_materials()
	var had_outline: int = 0
	var had_normal: int = 0
	for m: Material in before:
		if m is StandardMaterial3D and (m as StandardMaterial3D).next_pass:
			had_outline += 1
		if m is StandardMaterial3D and (m as StandardMaterial3D).normal_enabled:
			had_normal += 1
	print("  before: %d materials, %d with outline next_pass, %d with normal maps" % [before.size(), had_outline, had_normal])
	if not _check(had_outline > 0, "CharacterBuilder (toon mặc định) phải có vật liệu viền để test có nghĩa"):
		return true
	# autoload GameFX (nếu có trong lần chạy --script) đặt tỉ lệ đầu theo phong cách: 1.15 vice / 1.3 cổ điển
	var fx: Node = root.get_node_or_null("GameFX")
	var want_hs: float = 1.3
	if fx and String(fx.get("art_style")) == "vice":
		want_hs = 1.15
	if not _check(is_equal_approx(CharacterBuilder.head_scale_default, want_hs), "CharacterBuilder.head_scale_default cần %.2f, đang %s" % [want_hs, str(CharacterBuilder.head_scale_default)]):
		return true
	if fx and not _check(CharacterBuilder.toon == (String(fx.get("art_style")) == "classic"), "GameFX phải đặt CharacterBuilder.toon theo phong cách"):
		return true

	# --- bảng preset -> look
	var expect: Dictionary = {"dawn": "dawn", "morning": "day", "noon": "day", "midday_open": "day", "morning_indoor": "indoor", "exam": "indoor", "night": "night", "outdoor": "day", "indoor": "indoor", "sunset": "sunset", "???": "day"}
	for k: String in expect.keys():
		if not _check(ViceStyle.look_for_preset(k) == expect[k], "look_for_preset(%s) = %s, cần %s" % [k, ViceStyle.look_for_preset(k), expect[k]]):
			return true
	for look: String in ["dawn", "day", "sunset", "night", "indoor"]:
		if not _check(ViceStyle.LOOKS.has(look), "LOOKS thiếu %s" % look):
			return true
		var lp: Dictionary = ViceStyle.LOOKS[look]
		for key: String in ["windows", "neon", "soft_emitters", "trails", "amb", "thr", "cap", "top", "horizon", "fog_begin", "fog_end"]:
			if not _check(lp.has(key), "LOOKS[%s] thiếu khoá %s" % [look, key]):
				return true
	if not _check(is_equal_approx(float(ViceStyle.LOOKS["night"]["amb"]), 0.2), "đêm: ambient 0.2"):
		return true
	if not _check(float(ViceStyle.LOOKS["night"]["thr"]) >= 1.1, "đêm: ngưỡng glow >= 1.1 (màn hình phát sáng không cháy trắng)"):
		return true
	if not _check(is_equal_approx(float(ViceStyle.LOOKS["dawn"]["azim"]), 85.0), "bình minh: mặt trời phía đông (azim 85)"):
		return true

	# --- áp ban ngày (Màn 2 "morning" -> day)
	ViceStyle.apply(scene, "morning", 2, true)
	var e: Environment = we.environment
	if not _check(e != null and e != base_env, "apply phải tạo Environment mới"):
		return true
	if not _check(not e.sdfgi_enabled and not e.ssil_enabled and not e.ssao_enabled and not e.ssr_enabled and not e.volumetric_fog_enabled, "vice tắt SDFGI/SSIL/SSAO/SSR/sương thể tích"):
		return true
	if not _check(e.fog_enabled and e.fog_mode == Environment.FOG_MODE_DEPTH, "sương DEPTH"):
		return true
	if not _check(e.fog_density > 0.2, "sương DEPTH cần fog_density (độ đặc tối đa) đủ lớn, đang %.3f" % e.fog_density):
		return true
	var lut: Texture = e.adjustment_color_correction
	if not _check(lut is ImageTexture3D and (lut as ImageTexture3D).get_depth() == 32 and (lut as ImageTexture3D).get_width() == 32, "LUT 3D 32³"):
		return true
	if not _check(ViceStyle.lut("day") == lut, "LUT được cache theo look"):
		return true
	if not _check(e.glow_enabled and e.tonemap_mode == Environment.TONE_MAPPER_FILMIC and e.adjustment_enabled, "glow + Filmic + adjustments"):
		return true
	if not _check(e.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "ambient theo màu"):
		return true
	if not _check(is_equal_approx(sun.light_energy, float(ViceStyle.LOOKS["day"]["energy"])) and sun.shadow_enabled, "mặt trời theo look day"):
		return true
	if not _check(String(scene.get_meta("visual_preset", "")) == "morning" and String(scene.get_meta("vice_look", "")) == "day", "meta visual_preset / vice_look"):
		return true
	var after: Array = _all_materials()
	for m: Material in after:
		if m is BaseMaterial3D:
			var s := m as BaseMaterial3D
			if not _check(s.next_pass == null, "còn next_pass (viền toon) trên %s" % str(s)):
				return true
			if not _check(not s.normal_enabled, "còn normal map trên %s" % str(s)):
				return true
			if not _check(s.has_meta("vice_done"), "vật liệu chưa gắn meta vice_done: %s" % str(s)):
				return true
	if not _check(after.size() == before.size(), "số vật liệu đổi sau khi áp (%d -> %d)" % [before.size(), after.size()]):
		return true
	if not _check(soft_mat.has_meta("vice_soft_emitter") and not soft_mat.emission_enabled, "emission 0.3 = soft emitter, tắt ban ngày"):
		return true
	if not _check(bright_mat.emission_enabled and not bright_mat.has_meta("vice_soft_emitter"), "emission 2.0 không phải soft emitter, luôn bật"):
		return true
	if not _check(flash_mat.emission_enabled and not flash_mat.has_meta("vice_soft_emitter"), "emission 0 (hit-flash) không bị coi là soft emitter"):
		return true
	var matte_ok: bool = false
	for m: Material in after:
		if m is StandardMaterial3D and (m as StandardMaterial3D).specular_mode == BaseMaterial3D.SPECULAR_DISABLED and (m as StandardMaterial3D).roughness >= 0.9:
			matte_ok = true
	if not _check(matte_ok, "vật liệu không bóng phải thành lì (roughness >= 0.9, tắt specular)"):
		return true

	# --- áp lại: không cộng dồn
	var again: int = ViceStyle.stylize_materials(scene)
	if not _check(again == 0, "stylize_materials lần 2 phải trả 0, đang %d" % again):
		return true
	ViceStyle.apply(scene, "morning", 2, true)
	if not _check(_all_materials().size() == before.size(), "áp 2 lần làm đổi số vật liệu"):
		return true

	# --- ban đêm: soft emitter bật, đèn cửa sổ mặt tiền bật (nếu đọc được ảnh mặt tiền)
	ViceStyle.apply(scene, "night", 2, true)
	if not _check(soft_mat.emission_enabled, "đêm: soft emitter phải bật"):
		return true
	if not _check(we.environment.glow_hdr_threshold >= 1.1 and we.environment.glow_hdr_luminance_cap <= 3.0, "đêm: ngưỡng glow >= 1.1, trần độ sáng glow thấp (đèn trần Màn 6 không loé)"):
		return true
	if not _check(is_equal_approx(we.environment.ambient_light_energy, 0.2), "đêm: ambient 0.2"):
		return true
	var facade: StandardMaterial3D = null
	if building is MeshInstance3D and (building as MeshInstance3D).mesh:
		facade = (building as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	if facade and facade.albedo_texture:
		var win_tex: Texture2D = ViceStyle.window_emission_texture(String(MapBuilder._style_mats.find_key(facade)))
		print("  facade at night: emission %s energy %.2f (window texture %s)" % [str(facade.emission_enabled), facade.emission_energy_multiplier, str(win_tex != null)])
		if win_tex:
			if not _check(facade.emission_enabled and is_equal_approx(facade.emission_energy_multiplier, float(ViceStyle.LOOKS["night"]["windows"])), "đêm: đèn cửa sổ mặt tiền"):
				return true
			if not _check(not facade.has_meta("vice_soft_emitter"), "mặt tiền có đèn cửa sổ không được thành soft emitter"):
				return true
	# --- trong nhà ban ngày (Extra "exam" -> indoor): không sương, ambient ấm
	ViceStyle.apply(scene, "exam", 2, true)
	var ind: Dictionary = ViceStyle.LOOKS["indoor"]
	if not _check(not we.environment.fog_enabled and is_equal_approx(we.environment.ambient_light_energy, float(ind["amb"])) and we.environment.ambient_light_color.is_equal_approx(Color("#ffe9d6")), "indoor: không sương, ambient ấm #ffe9d6"):
		return true
	if not _check(we.environment.glow_hdr_threshold >= 1.3, "indoor: ngưỡng glow >= 1.3 (màn hình / đèn trần không làm loá phòng)"):
		return true
	if not _check(not soft_mat.emission_enabled, "indoor ban ngày: soft emitter tắt"):
		return true
	if facade and facade.albedo_texture:
		if not _check(not facade.emission_enabled, "ban ngày: đèn cửa sổ tắt"):
			return true

	# --- trả về cổ điển: Environment gốc, soft emitter bật lại như đồ hoạ cũ
	ViceStyle.restore_classic(scene)
	if not _check(we.environment == base_env, "restore_classic phải trả Environment gốc"):
		return true
	if not _check(soft_mat.emission_enabled, "restore_classic bật lại soft emitter"):
		return true

	# --- GameFX: _art_style() / _trails() đọc /root/GameFX (không có autoload -> vice / true);
	#     upgrade_scene_visuals rẽ nhánh sang ViceStyle khi vice, giữ đường cổ điển khi classic
	var gfx: Script = load("res://scripts/GameFX.gd")
	if fx == null:
		if not _check(String(gfx.call("_art_style")) == "vice" and bool(gfx.call("_trails")), "GameFX._art_style() / _trails() mặc định vice / true"):
			return true
	var saved_style: String = String(fx.get("art_style")) if fx else "vice"
	if fx:
		fx.set("art_style", "vice")   # chỉ đổi biến, không lưu settings.cfg của người chơi
	gfx.call("upgrade_scene_visuals", scene, "dawn")
	if not _check(String(scene.get_meta("vice_look", "")) == "dawn" and not we.environment.sdfgi_enabled, "GameFX.upgrade_scene_visuals -> ViceStyle khi art_style vice"):
		return true
	if fx:
		fx.set("art_style", "classic")
		ViceStyle.restore_classic(scene)
		gfx.call("upgrade_scene_visuals", scene, "dawn")
		var ce: Environment = we.environment
		if not _check(not scene.has_meta("vice_look") and ce.tonemap_mode == Environment.TONE_MAPPER_ACES and ce.fog_mode == Environment.FOG_MODE_EXPONENTIAL, "classic: đường render cũ (ACES, sương exponential)"):
			return true
		fx.set("art_style", saved_style)
	print("  stylised materials: %d, LUT 32^3, looks %s" % [after.size(), str(ViceStyle.LOOKS.keys())])
	print("✅ SUCCESS: VICE STYLE OK")
	quit(0)
	return true
