# File: res://tests/test_vice_style.gd
# Test headless ViceStyle (plan docs/superpowers/plans/2026-10-22-vice-city-art-direction.md, Task VC-1):
#   cảnh tối thiểu = WorldEnvironment + DirectionalLight3D + 1 nhân vật (CharacterBuilder, có viền toon) + 1 toà nhà
#   Vinhomes (MapBuilder.build_building, mặt tiền có normal map) + 1 khối có vật liệu phát sáng yếu (emission 0.3).
#   ViceStyle.apply(scene, "morning") -> Environment vice (không SDFGI, sương DEPTH, LUT 3D 32³, glow), vật liệu lì
#   (không next_pass, không normal map), vật liệu phát sáng yếu tắt ban ngày / bật ban đêm, áp lại không cộng dồn,
#   bảng preset -> look, restore_classic() trả Environment gốc, GameFX.upgrade_scene_visuals() rẽ nhánh sang vice khi
#   không có autoload (mặc định "vice").
#   Sửa sau review VC-1: vạch sơn (meta "night_line") chỉ phát sáng ban đêm; node thêm vào SAU apply được chuyển kiểu +
#   nhận trạng thái đêm (SceneTree.node_added, gỡ khi root rời cây); unstylize_materials() trả vật liệu về gốc (meta
#   "vice_orig") và node mới dưới root cổ điển cũng được trả về; forget_cached_materials() gán dictionary mới (không clear
#   dictionary cũ mà script khác còn giữ); ngưỡng glow ban ngày / giữa trưa / trong nhà, ambient căn tin hở.
# Chạy:  godot --headless --path . --script tests/test_vice_style.gd
extends SceneTree

var scene: Node3D
var we: WorldEnvironment
var base_env: Environment
var sun: DirectionalLight3D
var soft_mat: StandardMaterial3D
var bright_mat: StandardMaterial3D
var flash_mat: StandardMaterial3D
var line_mat: StandardMaterial3D
var building: Node3D
var frames: int = 0
var char_outline_mat: StandardMaterial3D   # vật liệu nhân vật có viền toon trước khi áp (để kiểm unstylize)
var char_outline_pass: Material
var late_outline_mat: StandardMaterial3D   # node thêm sau apply
var late_soft_mat: StandardMaterial3D
var late_line_mat: StandardMaterial3D
var late_vice_mat: StandardMaterial3D      # vật liệu vice_done thêm vào root cổ điển


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
	line_mat = _box_with_line(Vector3(10.0, 0.5, 0.0))            # vạch sơn: không emission ở cổ điển
	print("--- TEST VICE STYLE: building %s (style %s) ---" % [str(b0.get("id", 0)), str(b0.get("style", ""))])


func _box_with_emission(pos: Vector3, energy: float, parent: Node = null) -> StandardMaterial3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.4, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.3)
	m.emission_energy_multiplier = energy
	mi.material_override = m
	mi.position = pos
	(parent if parent else scene).add_child(mi)
	return m


func _box_with_line(pos: Vector3) -> StandardMaterial3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#FBC531")
	m.set_meta("night_line", true)
	mi.material_override = m
	mi.position = pos
	scene.add_child(mi)
	return m


## Vật liệu kiểu nhân vật toon: bóng nhẹ, viền outline ở next_pass (cùng shader CharacterBuilder dùng).
func _toon_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.5, 0.9)
	m.roughness = 0.4
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	var ol := ShaderMaterial.new()
	ol.shader = load("res://assets/shaders/outline.gdshader")
	m.next_pass = ol
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
	if frames == 3:
		return _phase_late_nodes()
	if frames == 4:
		return _phase_classic_late_node()
	if frames != 2:
		return false
	# --- trước khi áp: nhân vật có viền toon (next_pass), mặt tiền có normal map
	var before: Array = _all_materials()
	var had_outline: int = 0
	var had_normal: int = 0
	for m: Material in before:
		if m is StandardMaterial3D and (m as StandardMaterial3D).next_pass:
			had_outline += 1
			if char_outline_mat == null:
				char_outline_mat = m
				char_outline_pass = (m as StandardMaterial3D).next_pass
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
	var night_amb: float = float(ViceStyle.LOOKS["night"]["amb"])
	if not _check(night_amb >= 0.2 and night_amb <= 0.3, "đêm: ambient 0.2..0.3 (đang %.2f)" % night_amb):
		return true
	# review VC-1: vạch sơn / vòng thảm không có quầng ban ngày (ngưỡng glow), căn tin hở không bạc màu, phòng học không loá
	var pday: Dictionary = ViceStyle.params_for("morning")
	var pnoon: Dictionary = ViceStyle.params_for("noon")
	var pmid: Dictionary = ViceStyle.params_for("midday_open")
	var pind: Dictionary = ViceStyle.params_for("morning_indoor")
	if not _check(float(pday["thr"]) >= 1.85 and float(pnoon["thr"]) >= 2.0 and float(pmid["thr"]) >= 2.0, "ngưỡng glow day >= 1.85, noon / midday_open >= 2.0 (đang %.2f / %.2f / %.2f)" % [float(pday["thr"]), float(pnoon["thr"]), float(pmid["thr"])]):
		return true
	if not _check(float(pmid["amb"]) < float(pday["amb"]) and float(pmid["exposure"]) <= float(pday["exposure"]) + 0.001, "midday_open: ambient thấp hơn day, không cộng exposure"):
		return true
	if not _check(float(pind["thr"]) >= 1.8 and float(pind["cap"]) <= 2.0 and float(pind["amb"]) < 0.9, "indoor: ngưỡng glow >= 1.8, cap <= 2.0, ambient < 0.9"):
		return true
	if not _check(FPTUCampusBuilder.make_materials()["yellow_line"].has_meta("night_line") and FPTUCampusBuilder.make_materials()["line"].has_meta("night_line") and MapBuilder.materials()["overlay"].has_meta("night_line"), "vạch sơn campus (line / yellow_line) + overlay làn MapBuilder gắn meta night_line"):
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
	if not _check(line_mat.has_meta("vice_soft_emitter") and not line_mat.emission_enabled, "vạch sơn (night_line) = soft emitter, tắt ban ngày (không quầng)"):
		return true
	if not _check(line_mat.has_meta("vice_orig") and char_outline_mat.has_meta("vice_orig") and (char_outline_mat.get_meta("vice_orig") as Dictionary).get("next_pass") == char_outline_pass, "vice_orig lưu giá trị gốc (next_pass viền toon...)"):
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
	if not _check(is_equal_approx(we.environment.ambient_light_energy, night_amb), "đêm: ambient %.2f" % night_amb):
		return true
	if not _check(line_mat.emission_enabled and is_equal_approx(line_mat.emission_energy_multiplier, ViceStyle.NIGHT_LINE_ENERGY) and line_mat.emission.is_equal_approx(Color("#FBC531")), "đêm: vạch sơn phát sáng nhẹ đúng màu của nó"):
		return true
	var facade: StandardMaterial3D = null
	if building is MeshInstance3D and (building as MeshInstance3D).mesh:
		facade = (building as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	if facade and facade.albedo_texture:
		# khoá của vật liệu trong cache MapBuilder (null nếu cache đã bị quên / vật liệu không phải từ cache: bỏ qua)
		var style_key: Variant = MapBuilder._style_mats.find_key(facade)
		var win_tex: Texture2D = null
		if style_key == null:
			print("  facade material is not in MapBuilder._style_mats: window light check skipped")
		else:
			win_tex = ViceStyle.window_emission_texture(String(style_key))
			print("  facade at night: emission %s energy %.2f (window texture %s, facade_style %s)" % [str(facade.emission_enabled), facade.emission_energy_multiplier, str(win_tex != null), str(facade.get_meta("facade_style", "?"))])
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

	# --- node thêm SAU apply (xe cộ, NPC, khay cơm...): đang đêm -> chuyển kiểu + soft emitter / vạch sơn bật ở frame sau
	ViceStyle.apply(scene, "night", 2, true)
	if not _check(ViceStyle.is_watching(self) and scene.has_meta("vice_watch"), "apply phải nối SceneTree.node_added (meta vice_watch trên root)"):
		return true
	late_outline_mat = _toon_material()
	var late := MeshInstance3D.new()
	late.mesh = BoxMesh.new()
	late.position = Vector3(12.0, 0.5, 0.0)
	scene.add_child(late)
	late.material_override = late_outline_mat   # gán SAU add_child: xử lý deferred cuối frame vẫn thấy
	late_soft_mat = _box_with_emission(Vector3(14.0, 0.5, 0.0), 0.3)
	var holder := Node3D.new()
	scene.add_child(holder)
	var lmi := MeshInstance3D.new()
	lmi.mesh = BoxMesh.new()
	late_line_mat = StandardMaterial3D.new()
	late_line_mat.albedo_color = Color.WHITE
	late_line_mat.set_meta("night_line", true)
	lmi.material_override = late_line_mat
	holder.add_child(lmi)
	return false


## Frame 3: node thêm sau apply đã được chuyển kiểu; rồi trả về cổ điển + unstylize_materials().
func _phase_late_nodes() -> bool:
	if not _check(late_outline_mat.has_meta("vice_done") and late_outline_mat.next_pass == null and late_outline_mat.diffuse_mode == BaseMaterial3D.DIFFUSE_LAMBERT and late_outline_mat.specular_mode == BaseMaterial3D.SPECULAR_DISABLED, "node thêm sau apply: vật liệu phải được chuyển kiểu (bỏ viền, Lambert, lì)"):
		return true
	if not _check(late_soft_mat.has_meta("vice_soft_emitter") and late_soft_mat.emission_enabled, "node thêm sau apply (đêm): soft emitter bật"):
		return true
	if not _check(late_line_mat.emission_enabled and is_equal_approx(late_line_mat.emission_energy_multiplier, ViceStyle.NIGHT_LINE_ENERGY), "node thêm sau apply (đêm): vạch sơn phát sáng"):
		return true
	print("  late nodes after apply: stylised, night state applied")

	# --- trả về cổ điển: Environment gốc, soft emitter về trạng thái emission gốc
	ViceStyle.restore_classic(scene)
	if not _check(we.environment == base_env, "restore_classic phải trả Environment gốc"):
		return true
	if not _check(soft_mat.emission_enabled, "restore_classic bật lại soft emitter (gốc có emission)"):
		return true
	if not _check(not line_mat.emission_enabled, "restore_classic: vạch sơn về emission gốc (tắt)"):
		return true
	# --- unstylize_materials(): mọi vật liệu vice_done về giá trị gốc, gỡ thẻ vice_*
	var restored: int = ViceStyle.unstylize_materials(scene)
	print("  unstylize_materials restored %d materials" % restored)
	if not _check(restored > 0 and char_outline_mat.next_pass == char_outline_pass and not char_outline_mat.has_meta("vice_done") and not char_outline_mat.has_meta("vice_orig"), "unstylize: viền toon của nhân vật phải về lại, thẻ vice_* gỡ"):
		return true
	if not _check(late_outline_mat.next_pass != null and late_outline_mat.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON and late_outline_mat.specular_mode == BaseMaterial3D.SPECULAR_TOON and is_equal_approx(late_outline_mat.roughness, 0.4), "unstylize: next_pass / diffuse / specular / roughness gốc"):
		return true
	if not _check(not line_mat.emission_enabled and is_equal_approx(line_mat.emission_energy_multiplier, 1.0) and line_mat.emission_texture == null and not line_mat.has_meta("vice_soft_emitter"), "unstylize: emission gốc của vạch sơn"):
		return true
	if not _check(soft_mat.emission_enabled and is_equal_approx(soft_mat.emission_energy_multiplier, 0.3) and not soft_mat.has_meta("vice_soft_emitter"), "unstylize: soft emitter giữ emission gốc"):
		return true
	for m: Material in _all_materials():
		if not _check(not m.has_meta("vice_done") and not m.has_meta("vice_orig"), "unstylize: còn thẻ vice trên %s" % str(m)):
			return true
	if not _check(not scene.has_meta("vice_look") and scene.has_meta("vice_watch"), "unstylize: gỡ vice_look, vẫn theo dõi node mới của root cổ điển"):
		return true
	# node mới mang vật liệu đã chuyển kiểu vice (vd sub-resource .tscn dùng chung) thêm vào root cổ điển -> trả về gốc
	late_vice_mat = _toon_material()
	var tmp := MeshInstance3D.new()
	tmp.mesh = BoxMesh.new()
	tmp.material_override = late_vice_mat
	ViceStyle.stylize_materials(tmp)
	if not _check(late_vice_mat.has_meta("vice_done") and late_vice_mat.next_pass == null, "stylize_materials trên node ngoài cây"):
		return true
	tmp.position = Vector3(16.0, 0.5, 0.0)
	scene.add_child(tmp)
	return false


## Frame 4: node mới dưới root cổ điển đã được trả về; GameFX; forget_cached_materials; root rời cây -> gỡ kết nối.
func _phase_classic_late_node() -> bool:
	if not _check(not late_vice_mat.has_meta("vice_done") and late_vice_mat.next_pass != null and late_vice_mat.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "node mới dưới root cổ điển: vật liệu vice phải về gốc"):
		return true
	print("  late node under a classic root: unstylised")
	var fx: Node = root.get_node_or_null("GameFX")
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
		if not _check(char_outline_mat.next_pass == char_outline_pass and not char_outline_mat.has_meta("vice_done"), "classic: upgrade_scene_visuals trả vật liệu vice về gốc"):
			return true
		fx.set("art_style", saved_style)

	# --- forget_cached_materials(): dictionary MỚI, dictionary cũ (script khác còn giữ) không bị xoá
	var old_campus: Dictionary = FPTUCampusBuilder.make_materials()
	var old_map: Dictionary = MapBuilder._style_mats
	var old_chars: Dictionary = CharacterBuilder._mat_cache
	var n_campus: int = old_campus.size()
	var n_map: int = old_map.size()
	var n_chars: int = old_chars.size()
	ViceStyle.forget_cached_materials()
	if not _check(not is_same(FPTUCampusBuilder._materials_cache, old_campus) and FPTUCampusBuilder._materials_cache.is_empty() and old_campus.size() == n_campus and n_campus > 0, "forget: cache campus phải là dictionary mới, cũ giữ nguyên %d vật liệu" % n_campus):
		return true
	if not _check(not is_same(MapBuilder._style_mats, old_map) and old_map.size() == n_map and not is_same(CharacterBuilder._mat_cache, old_chars) and old_chars.size() == n_chars, "forget: cache MapBuilder / CharacterBuilder phải là dictionary mới, cũ giữ nguyên"):
		return true
	if not _check(not is_same(FPTUCampusBuilder.make_materials(), old_campus), "forget: make_materials() dựng bộ vật liệu mới"):
		return true

	# --- root rời cây: gỡ kết nối node_added
	root.remove_child(scene)
	if not _check(not ViceStyle.is_watching(self) and not scene.has_meta("vice_watch"), "root rời cây phải gỡ kết nối node_added"):
		return true
	print("  stylised materials: %d, LUT 32^3, looks %s, forget_cached_materials -> fresh caches (campus %d, map %d, chars %d kept in the old ones)" % [_all_materials().size(), str(ViceStyle.LOOKS.keys()), n_campus, n_map, n_chars])
	scene.free()
	print("✅ SUCCESS: VICE STYLE OK")
	quit(0)
	return true
