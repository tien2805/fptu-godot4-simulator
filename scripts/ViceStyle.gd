# File: res://scripts/ViceStyle.gd
# Phong cách đồ hoạ "Vice City" (chỉ mượn PHONG CÁCH: bảng màu pastel Miami thập niên 80, trời hoàng hôn, sương xa dày,
# vật liệu lì kiểu PS2, neon ban đêm). Không dùng asset, font, logo hay tên của Rockstar.
# Plan: docs/superpowers/plans/2026-10-22-vice-city-art-direction.md (Task VC-1). Mọi thông số port từ look-dev đã duyệt
# tests/preview_vice_lookdev.gd (VICE, _apply_vice_env, _vice_lut, _vice_material/_vice_materials_pass, soft emitter,
# đèn cửa sổ), thêm look "dawn" (bình minh hồng/đào, nắng phía đông) và "indoor" (đèn huỳnh quang ấm, không sương).
#
# upgrade_scene_visuals() của autoload hiệu ứng gọi ViceStyle.apply() khi art_style == "vice" (mặc định); "classic" giữ đường
# render cũ. Mọi hàm đều static, đọc cài đặt qua tham số (KHÔNG nhắc tới autoload ở đây: script class_name được biên dịch
# trước autoload khi chạy test --script).
#
# apply(root, preset, quality, trails):
#   - WorldEnvironment đầu tiên dưới root nhận một Environment MỚI (ProceduralSky theo look, ambient theo màu, tắt
#     SDFGI/SSIL/SSAO/SSR/sương thể tích, sương DEPTH, glow mức 1-4, tonemap Filmic, adjustments + LUT 3D 32³ tách tông);
#     Environment gốc của cảnh được giữ ở meta "vice_base_env" của node để restore_classic() trả lại.
#   - DirectionalLight3D đầu tiên: hướng / màu / cường độ nắng theo look (+ tinh chỉnh theo preset), bóng 2/4 split.
#   - stylize_materials(root): bỏ viền toon (next_pass outline), tắt normal map, diffuse Lambert, vật liệu không bóng
#     thành lì (roughness >= 0.9, tắt specular). Vật liệu đã xử lý gắn meta "vice_done" nên cache dùng chung giữa các cảnh
#     (CharacterBuilder / FPTUCampusBuilder / MapBuilder) chỉ xử lý một lần; áp lại không cộng dồn. Giá trị gốc lưu ở meta
#     "vice_orig" để unstylize_materials() trả lại khi cảnh (hoặc vật liệu sub-resource .tscn mà ResourceLoader dùng lại
#     khi nạp lại cùng cảnh) chạy ở phong cách cổ điển.
#   - set_night_layers(root, look): soft emitter (emission_energy_multiplier trong (0, 0.5], meta "vice_soft_emitter")
#     chỉ sáng ban đêm, vạch sơn đường (meta "night_line" do MapBuilder / FPTUCampusBuilder gắn) sáng nhẹ ban đêm, node
#     nhóm "vice_neon" chỉ hiện khi look có neon, đèn cửa sổ (vật liệu mặt tiền MapBuilder, meta "facade_style").
#   - node sinh ra SAU apply (xe cộ, NPC, khay cơm, xe máy FreeRoam, đạo cụ dựng muộn): lần áp đầu cho một root nối tín
#     hiệu SceneTree.node_added (một lần, meta "vice_watch" trên root, gỡ khi root rời cây); mỗi GeometryInstance3D mới
#     dưới root có meta "vice_look" được chuyển kiểu + nhận trạng thái soft emitter / đêm hiện tại (gom lại, xử lý deferred
#     cuối frame để vật liệu gán sau add_child cũng được tính). Root cổ điển đang theo dõi thì trả node mới về cổ điển.
#   - meta trên root: "visual_preset" (= preset truyền vào, set_art_style() của autoload dùng để áp lại), "vice_look",
#     "vice_trails" (cờ cho hiệu ứng vệt sáng của Task VC-7).
class_name ViceStyle
extends RefCounted

const LUT_SIZE: int = 32
## Soft emitter: vật liệu phát sáng yếu chỉ để thấy ban đêm (biển 7-Eleven 0.5, ...). Năng lượng 0 = hiệu ứng nháy
## khi trúng đòn (Màn 4 tween 0 -> 1.2), không phải soft emitter.
const SOFT_EMITTER_MAX: float = 0.5
const NEON_GROUP: StringName = &"vice_neon"
const WINDOW_STYLES: Array[String] = ["tower", "beverly", "mall", "shophouse"]
const WINDOW_TEX_MAX_W: int = 256          # ảnh đèn cửa sổ dựng ở nửa độ phân giải mặt tiền (đủ cho ban đêm, nhanh)
const OUTLINE_SHADER_FILE: String = "outline.gdshader"
## Meta do các builder gắn lúc tạo vật liệu (không phải thẻ vice_*: unstylize_materials() không gỡ):
##   "night_line"  = vạch sơn đường (MapBuilder overlay làn, FPTUCampusBuilder line / yellow_line): ở vice thành soft
##                   emitter phát chính màu / ảnh của nó với NIGHT_LINE_ENERGY, chỉ bật ban đêm (ban ngày không loé);
##   "facade_style" = kiểu mặt tiền MapBuilder (tower / beverly / mall / shophouse / industrial) cho đèn cửa sổ ban đêm.
const NIGHT_LINE_META: StringName = &"night_line"
const FACADE_META: StringName = &"facade_style"
const NIGHT_LINE_ENERGY: float = 0.45
const VICE_TAGS: Array[StringName] = [&"vice_done", &"vice_orig", &"vice_soft_emitter", &"vice_window"]

## Bảng look theo giờ. top/horizon/ground_* = ProceduralSky; sun/energy/elev/azim = DirectionalLight3D;
## fog_* = sương DEPTH (fog_max = độ đặc ở fog_end, fog_on = false trong nhà); glow/bloom/thr = glow;
## exposure/sat/contrast = tonemap + adjustments; amb/amb_col = ambient màu; shadow/high/lift (+ high_w/shadow_w) = LUT tách tông;
## cap = glow_hdr_luminance_cap; windows = năng lượng đèn cửa sổ; neon / soft_emitters = lớp đêm; trails = độ mạnh vệt
## sáng (Task VC-7). day / sunset = đúng look-dev. Chỉnh khi xem ảnh các màn thật (tests/preview_stages.gd):
##   - dawn: ngưỡng glow 1.5 (1.05 làm mặt tường hướng nắng sớm của HUTECH loé trắng), nắng 1.45, ambient 0.95;
##   - day: ngưỡng glow 1.9 (1.75 của look-dev làm vạch vàng giữa đường / vạch sơn sáng nắng có quầng);
##   - night: ambient 0.28, ngưỡng 1.5 + cap 2.5 (đèn trần Màn 6 ở ngưỡng 1.1 / cap 12 thành quầng sáng lớn; ambient 0.2
##     làm đường FreeRoam đen kịt, xe + người lái gần như mất hẳn; vạch sơn là soft emitter sáng nhẹ ban đêm; đèn đường
##     + neon thật ở Task VC-3);
##   - indoor: ambient #ffe9d6 0.75, exposure 0.85, glow 0.2, ngưỡng 1.9, cap 1.6, LUT đẩy vùng sáng high_w 0.04 thay
##     cho 0.22 (1.35 + ngưỡng 1.3, rồi 0.9 + ngưỡng 1.6 / cap 2.5 cộng đèn trần OmniLight của phòng vẫn làm phòng học /
##     phòng thi loá trắng: màn hình trắng, màn chiếu, đèn tuýp có quầng, ~9-10 % điểm ảnh cháy trắng; phần lớn do LUT
##     đẩy mọi điểm ảnh gần trắng lên 255, hạ high_w còn ~3 %, màn chiếu FAP đọc rõ).
## high_w (mặc định 0.22) / shadow_w (mặc định 0.32) = độ mạnh tách tông vùng sáng / vùng tối của LUT.
const LOOKS: Dictionary = {
	"dawn": {"top": Color("#5b6bc0"), "horizon": Color("#ffa59c"), "ground_h": Color("#ffc6a2"), "ground_b": Color("#463452"),
		"sun": Color("#ffc489"), "energy": 1.45, "elev": 14.0, "azim": 85.0,
		"fog_on": true, "fog": Color("#f7bfae"), "fog_begin": 120.0, "fog_end": 1800.0, "fog_max": 1.0, "sky_fog": 0.25, "scatter": 0.3,
		"exposure": 1.0, "glow": 0.6, "bloom": 0.08, "thr": 1.5, "sat": 1.18, "contrast": 1.02, "sky_energy": 1.0,
		"amb": 0.95, "amb_col": Color("#e2b2cc"), "shadow": Color("#41357a"), "high": Color("#ffe6cc"), "lift": 0.03,
		"cap": 12.0, "shadow_opacity": 0.72, "windows": 0.0, "neon": false, "soft_emitters": false, "trails": 0.3},
	"day": {"top": Color("#2f9ff2"), "horizon": Color("#c8eef4"), "ground_h": Color("#e8f3e8"), "ground_b": Color("#6a7a70"),
		"sun": Color("#fff2d8"), "energy": 1.45, "elev": 55.0, "azim": 150.0,
		"fog_on": true, "fog": Color("#d6f0f4"), "fog_begin": 140.0, "fog_end": 1800.0, "fog_max": 1.0, "sky_fog": 0.25, "scatter": 0.1,
		"exposure": 1.18, "glow": 0.45, "bloom": 0.03, "thr": 1.9, "sat": 1.22, "contrast": 0.96, "sky_energy": 1.0,
		"amb": 1.15, "amb_col": Color("#c6e4ee"), "shadow": Color("#2b5c74"), "high": Color("#fff1dc"), "lift": 0.03,
		"cap": 12.0, "shadow_opacity": 0.72, "windows": 0.0, "neon": false, "soft_emitters": false, "trails": 0.0},
	"sunset": {"top": Color("#2c1d5e"), "horizon": Color("#ff7f8f"), "ground_h": Color("#ffb08a"), "ground_b": Color("#3a2747"),
		"sun": Color("#ffb46e"), "energy": 1.55, "elev": 9.0, "azim": -95.0,
		"fog_on": true, "fog": Color("#f3b0a6"), "fog_begin": 150.0, "fog_end": 2200.0, "fog_max": 1.0, "sky_fog": 0.25, "scatter": 0.35,
		"exposure": 1.06, "glow": 0.85, "bloom": 0.12, "thr": 1.0, "sat": 1.2, "contrast": 1.0, "sky_energy": 1.0,
		"amb": 1.0, "amb_col": Color("#d9a0c8"), "shadow": Color("#3b2e74"), "high": Color("#ffe2c2"), "lift": 0.03,
		"cap": 12.0, "shadow_opacity": 0.72, "windows": 0.0, "neon": false, "soft_emitters": false, "trails": 0.45},
	"night": {"top": Color("#0a0626"), "horizon": Color("#3e2172"), "ground_h": Color("#2a1a4a"), "ground_b": Color("#07050f"),
		"sun": Color("#8ea6ff"), "energy": 0.3, "elev": 38.0, "azim": 200.0,
		"fog_on": true, "fog": Color("#2b1a55"), "fog_begin": 40.0, "fog_end": 700.0, "fog_max": 0.9, "sky_fog": 0.5, "scatter": 0.1,
		"exposure": 1.0, "glow": 0.6, "bloom": 0.0, "thr": 1.5, "sat": 1.15, "contrast": 1.02, "sky_energy": 0.7,
		"amb": 0.28, "amb_col": Color("#4a3a8f"), "shadow": Color("#140a3a"), "high": Color("#ff9ad6"), "lift": 0.02,
		"cap": 2.5, "shadow_opacity": 0.5, "windows": 0.12, "neon": true, "soft_emitters": true, "trails": 0.55},
	"indoor": {"top": Color("#4aa6ee"), "horizon": Color("#d2eef4"), "ground_h": Color("#e6eee6"), "ground_b": Color("#6a7a70"),
		"sun": Color("#fff4e2"), "energy": 1.4, "elev": 30.0, "azim": 125.0,
		"fog_on": false, "fog": Color("#f2ece4"), "fog_begin": 200.0, "fog_end": 2000.0, "fog_max": 0.0, "sky_fog": 0.0, "scatter": 0.0,
		"exposure": 0.85, "glow": 0.2, "bloom": 0.0, "thr": 1.9, "sat": 1.12, "contrast": 1.04, "sky_energy": 1.0,
		"amb": 0.75, "amb_col": Color("#ffe9d6"), "shadow": Color("#3a3a6e"), "high": Color("#fff0dc"), "lift": 0.03,
		"high_w": 0.04, "cap": 1.6, "shadow_opacity": 0.65, "windows": 0.0, "neon": false, "soft_emitters": false, "trails": 0.0},
}

## Preset ánh sáng của các màn (TOD_PRESETS + alias cũ của autoload hiệu ứng) -> look vice. Preset lạ -> "day".
const PRESET_LOOK: Dictionary = {
	"dawn": "dawn", "morning": "day", "noon": "day", "midday_open": "day", "morning_indoor": "indoor", "exam": "indoor",
	"night": "night", "outdoor": "day", "indoor": "indoor", "day": "day", "sunset": "sunset",
}
## Tinh chỉnh theo preset trên nền look: exposure_add cộng vào exposure, các khoá khác ghi đè.
## Giữa trưa (Màn 4 sân võ): sáng hơn 0.04, ngưỡng glow 2.4 + không bloom (vòng vàng của thảm sáng nắng ~2.2: ngưỡng
## 1.85 / 2.1 cộng bloom 0.03 vẫn để quầng trắng xanh quanh vòng). Căn tin hở (Màn 5):
## phần lớn khung hình nằm dưới mái, chỉ có ambient chiếu: 1.15 + exposure 1.22 làm sàn gạch trắng / trần bê tông bạc màu
## (trung bình độ sáng ~200, độ lệch ~34; ảnh look-dev ban ngày ~150-160 / ~58-64). Ambient 0.8 + exposure 1.18 vẫn ~185;
## bản chọn: ambient 0.55, exposure 0.95 (exposure_add -0.23), contrast 1.45, glow 0.3 không bloom, ngưỡng 2.1
## -> trung bình ~152-168, độ lệch ~51-73 trên 3 góc preview. Trong nhà giữ hướng nắng mà từng màn đã thiết kế cho cửa sổ
## (morning_indoor 24°/120°, exam 30°/125°, căn tin hở 70°/175°).
const PRESET_TWEAKS: Dictionary = {
	"noon": {"exposure_add": 0.04, "thr": 2.4, "bloom": 0.0},
	"midday_open": {"exposure_add": -0.23, "thr": 2.1, "amb": 0.55, "contrast": 1.45, "glow": 0.3, "bloom": 0.0, "elev": 70.0, "azim": 175.0},
	"morning_indoor": {"elev": 24.0, "azim": 120.0, "energy": 1.55},
	"exam": {"elev": 30.0, "azim": 125.0},
}
## Preset ngoài trời: bóng nắng xa theo mức đồ hoạ; còn lại (trong nhà, đêm) 90 m như đường cổ điển.
const OUTDOOR_PRESETS: Array[String] = ["dawn", "morning", "noon", "outdoor", "day", "sunset"]
const SHADOW_DIST_OUTDOOR: Array[float] = [150.0, 240.0, 320.0]
const SHADOW_DIST_INDOOR: float = 90.0

static var _lut_cache: Dictionary = {}
static var _window_tex: Dictionary = {}
## Theo dõi node mới: instance id -> root có meta "vice_watch"; node chờ xử lý cuối frame; đã từng chuyển kiểu vật liệu
## nào chưa (phiên chỉ chơi cổ điển thì unstylize_materials() không duyệt cây, không theo dõi gì).
static var _watched: Dictionary = {}
static var _pending: Array = []
static var _flush_queued: bool = false
static var _ever_stylized: bool = false


# ===========================================================================
# API
# ===========================================================================
static func look_for_preset(preset: String) -> String:
	return String(PRESET_LOOK.get(preset, "day"))


## Thông số của look sau khi áp tinh chỉnh theo preset.
static func params_for(preset: String) -> Dictionary:
	var look: String = look_for_preset(preset)
	var p: Dictionary = (LOOKS[look] as Dictionary).duplicate()
	var tw: Dictionary = PRESET_TWEAKS.get(preset, {})
	for k: String in tw.keys():
		if k == "exposure_add":
			p["exposure"] = float(p["exposure"]) + float(tw[k])
		else:
			p[k] = tw[k]
	return p


static func apply(root: Node, preset: String, quality: int, trails_enabled: bool) -> void:
	if root == null:
		return
	var t0: int = Time.get_ticks_usec()
	var look: String = look_for_preset(preset)
	var p: Dictionary = params_for(preset)
	var q: int = clampi(quality, 0, 2)
	var env_node: WorldEnvironment = _find_first(root, "WorldEnvironment") as WorldEnvironment
	if env_node:
		if not env_node.has_meta("vice_base_env"):
			env_node.set_meta("vice_base_env", env_node.environment)
		env_node.environment = _build_environment(look, p)
	var sun: DirectionalLight3D = _find_first(root, "DirectionalLight3D") as DirectionalLight3D
	if sun:
		if not sun.has_meta("vice_base_shadow_opacity"):
			sun.set_meta("vice_base_shadow_opacity", sun.shadow_opacity)
		_apply_sun(sun, p, preset in OUTDOOR_PRESETS, q)
	# một lần duyệt cây cho cả pass vật liệu lẫn lớp đêm (= stylize_materials + set_night_layers)
	var mats: Array = []
	var neon: Array = []
	_collect(root, mats, {}, neon)
	for m: Material in mats:
		_stylize(m)
	_night_layers(mats, neon, look)
	root.set_meta("visual_preset", preset)
	root.set_meta("vice_look", look)
	root.set_meta("vice_trails", trails_enabled and float(p["trails"]) > 0.0)
	_watch(root)
	root.set_meta("vice_apply_ms", float(Time.get_ticks_usec() - t0) / 1000.0)


## LUT 3D 32³ tách tông (bóng ngả màu "shadow", vùng sáng ngả màu "high", nâng đen "lift"), cache theo look.
static func lut(look: String) -> ImageTexture3D:
	var key: String = look if LOOKS.has(look) else "day"
	if _lut_cache.has(key):
		return _lut_cache[key]
	var p: Dictionary = LOOKS[key]
	var n: int = LUT_SIZE
	var sh: Color = p["shadow"]
	var hi: Color = p["high"]
	var lift: float = float(p["lift"])
	var shadow_w: float = float(p.get("shadow_w", 0.32))
	var high_w: float = float(p.get("high_w", 0.22))
	var inv: float = 1.0 / float(n - 1)
	var slices: Array[Image] = []
	for bz: int in range(n):
		var data := PackedByteArray()
		data.resize(n * n * 3)
		var i: int = 0
		for gy: int in range(n):
			for rx: int in range(n):
				var r: float = rx * inv
				var g: float = gy * inv
				var b: float = bz * inv
				var lum: float = 0.299 * r + 0.587 * g + 0.114 * b
				var ws: float = pow(1.0 - lum, 2.0) * shadow_w
				var wh: float = pow(lum, 2.0) * high_w
				var o_r: float = (r + (sh.r - 0.5) * ws + (hi.r - 0.5) * wh) * (1.0 - lift) + lift
				var o_g: float = (g + (sh.g - 0.5) * ws + (hi.g - 0.5) * wh) * (1.0 - lift) + lift
				var o_b: float = (b + (sh.b - 0.5) * ws + (hi.b - 0.5) * wh) * (1.0 - lift) + lift
				data[i] = int(clampf(o_r, 0.0, 1.0) * 255.0 + 0.5)
				data[i + 1] = int(clampf(o_g, 0.0, 1.0) * 255.0 + 0.5)
				data[i + 2] = int(clampf(o_b, 0.0, 1.0) * 255.0 + 0.5)
				i += 3
		slices.append(Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data))
	var tex := ImageTexture3D.new()
	var err: int = tex.create(Image.FORMAT_RGB8, n, n, n, false, slices)
	if err != OK:
		push_error("ViceStyle: LUT create failed (%d)" % err)
	_lut_cache[key] = tex
	return tex


## Pass vật liệu kiểu PS2 cho mọi GeometryInstance3D dưới root. Trả về số vật liệu vừa đổi (đã xử lý -> bỏ qua).
static func stylize_materials(root: Node) -> int:
	if root == null:
		return 0
	var mats: Array = []
	var neon: Array = []
	_collect(root, mats, {}, neon)
	var changed: int = 0
	for m: Material in mats:
		if _stylize(m):
			changed += 1
	return changed


## Lớp đêm theo look: soft emitter, nhóm "vice_neon", đèn cửa sổ mặt tiền. Look lạ (vd "" khi trả về cổ điển)
## = trạng thái đồ hoạ cũ: soft emitter sáng, không neon, không đèn cửa sổ.
static func set_night_layers(root: Node, look: String) -> void:
	if root == null:
		return
	var mats: Array = []
	var neon: Array = []
	_collect(root, mats, {}, neon)
	_night_layers(mats, neon, look)


## Look lạ = cổ điển: soft emitter về trạng thái emission gốc (meta "vice_orig"; không có thì bật như đồ hoạ cũ),
## vạch sơn tắt phát sáng như gốc, không neon, không đèn cửa sổ.
static func _night_layers(mats: Array, neon: Array, look: String) -> void:
	var known: bool = LOOKS.has(look)
	var p: Dictionary = LOOKS.get(look, {})
	var soft_on: bool = bool(p.get("soft_emitters", true))
	var neon_on: bool = bool(p.get("neon", false))
	var windows: float = float(p.get("windows", 0.0))
	for m: Material in mats:
		if not (m is BaseMaterial3D):
			continue
		var s := m as BaseMaterial3D
		if s.has_meta(FACADE_META):
			_window_light(s, windows)
		elif s.has_meta("vice_soft_emitter"):
			if known:
				s.emission_enabled = soft_on
			else:
				s.emission_enabled = bool((s.get_meta("vice_orig", {}) as Dictionary).get("emission_enabled", true))
	for n: Node in neon:
		if n is Node3D:
			(n as Node3D).visible = neon_on
		elif n is CanvasItem:
			(n as CanvasItem).visible = neon_on


## Trả cảnh về đường render cổ điển: Environment gốc, độ đậm bóng nắng gốc, lớp đêm như đồ hoạ cũ. Vật liệu lì do
## unstylize_materials() trả lại (đường cổ điển của autoload hiệu ứng gọi nó).
static func restore_classic(root: Node) -> void:
	if root == null:
		return
	var env_node: WorldEnvironment = _find_first(root, "WorldEnvironment") as WorldEnvironment
	if env_node and env_node.has_meta("vice_base_env"):
		env_node.environment = env_node.get_meta("vice_base_env")
		env_node.remove_meta("vice_base_env")
	var sun: DirectionalLight3D = _find_first(root, "DirectionalLight3D") as DirectionalLight3D
	if sun and sun.has_meta("vice_base_shadow_opacity"):
		sun.shadow_opacity = float(sun.get_meta("vice_base_shadow_opacity"))
		sun.remove_meta("vice_base_shadow_opacity")
	set_night_layers(root, "")
	if root.has_meta("vice_look"):
		root.remove_meta("vice_look")
	if root.has_meta("vice_trails"):
		root.remove_meta("vice_trails")


## Trả mọi vật liệu đã chuyển kiểu vice (meta "vice_done") dưới root về giá trị gốc (meta "vice_orig": next_pass viền
## toon, normal map, diffuse / specular, roughness, emission) và gỡ các thẻ vice_*. Đường cổ điển của autoload hiệu ứng
## gọi mỗi lần áp: vật liệu sub-resource của .tscn được ResourceLoader dùng lại khi nạp lại cùng cảnh, vật liệu đang hiển
## thị khi đổi phong cách lúc chạy. Cũng gỡ meta "vice_look" / "vice_trails" của root và (nếu phiên này từng chuyển kiểu)
## theo dõi node mới của root để trả chúng về cổ điển. Trả về số vật liệu vừa trả lại.
static func unstylize_materials(root: Node) -> int:
	if root == null:
		return 0
	for k: String in ["vice_look", "vice_trails"]:
		if root.has_meta(k):
			root.remove_meta(k)
	if not _ever_stylized:
		return 0
	_watch(root)
	var mats: Array = []
	var neon: Array = []
	_collect(root, mats, {}, neon)
	var restored: int = 0
	for m: Material in mats:
		if _unstylize(m):
			restored += 1
	return restored


## Quên các cache vật liệu dùng chung (nhân vật / đồ vật, campus, bản đồ) để lần dựng sau tạo vật liệu mới theo phong
## cách hiện tại. Autoload hiệu ứng gọi mỗi lần đổi phong cách (cả hai chiều). Gán container MỚI thay vì clear(): script
## khác còn giữ tham chiếu tới dictionary cũ (FPTUCampusBuilder.make_materials() trả chính cache, MainMenu.campus_mats,
## Stage2_Parking.campus_mats) và vẫn dựng tiếp bằng vật liệu cũ của cảnh đang mở.
static func forget_cached_materials() -> void:
	CharacterBuilder._mat_cache = {}
	FPTUCampusBuilder._materials_cache = {}
	MapBuilder._mats = {}
	MapBuilder._style_mats = {}
	MapBuilder._tree_meshes = []
	_window_tex = {}


## Ảnh phát sáng đèn cửa sổ của một kiểu mặt tiền MapBuilder: pixel kính (xanh lam) -> vàng ấm, còn lại đen.
## Đọc ảnh albedo của `mat` (vật liệu mặt tiền, meta "facade_style"), không có thì của vật liệu kiểu đó trong cache
## MapBuilder (không tạo vật liệu / nạp ảnh cho cảnh không dùng bản đồ). Cache theo kiểu.
static func window_emission_texture(style: String, mat: BaseMaterial3D = null) -> Texture2D:
	if _window_tex.has(style):
		return _window_tex[style]
	if mat == null:
		mat = MapBuilder._style_mats.get(style) as BaseMaterial3D
	if mat == null or mat.albedo_texture == null:
		return null
	var tex: Texture2D = null
	var src: Image = mat.albedo_texture.get_image()
	if src and not src.is_empty():
		src = src.duplicate()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		if src.get_width() > WINDOW_TEX_MAX_W:
			var h0: int = maxi(1, int(round(float(src.get_height()) * WINDOW_TEX_MAX_W / float(src.get_width()))))
			src.resize(WINDOW_TEX_MAX_W, h0, Image.INTERPOLATE_BILINEAR)
		var w: int = src.get_width()
		var h: int = src.get_height()
		var px: PackedByteArray = src.get_data()
		var out := PackedByteArray()
		out.resize(w * h * 3)
		for y: int in range(h):
			var warm: float = lerpf(0.75, 1.0, float(y) / float(h))
			var wr: int = int(0.95 * warm * 255.0)
			var wg: int = int(0.72 * warm * 255.0)
			var wb: int = int(0.42 * warm * 255.0)
			for x: int in range(w):
				var si: int = (y * w + x) * 4
				var r: int = px[si]
				var b: int = px[si + 2]
				if b > r + 25 and b > 76:
					var di: int = (y * w + x) * 3
					out[di] = wr
					out[di + 1] = wg
					out[di + 2] = wb
		tex = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGB8, out))
	_window_tex[style] = tex
	return tex


# ===========================================================================
# NỘI BỘ
# ===========================================================================
static func _find_first(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for c: Node in node.get_children():
		var r: Node = _find_first(c, cls)
		if r:
			return r
	return null


static func _build_environment(look: String, p: Dictionary) -> Environment:
	var e := Environment.new()
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = p["top"]
	skm.sky_horizon_color = p["horizon"]
	skm.ground_horizon_color = p["ground_h"]
	skm.ground_bottom_color = p["ground_b"]
	skm.sun_angle_max = 32.0
	skm.sun_curve = 0.14
	skm.use_debanding = true
	skm.sky_energy_multiplier = float(p["sky_energy"])
	var sky := Sky.new()
	sky.sky_material = skm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = p["amb_col"]
	e.ambient_light_energy = float(p["amb"])
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# PS2: không GI / AO / SSR / sương thể tích – ánh sáng phẳng, ấm, phụ thuộc màu môi trường (và nhẹ hơn cổ điển)
	e.sdfgi_enabled = false
	e.ssil_enabled = false
	e.ssao_enabled = false
	e.ssr_enabled = false
	e.volumetric_fog_enabled = false
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_enabled = bool(p["fog_on"])
	e.fog_light_color = p["fog"]
	e.fog_light_energy = 1.0
	e.fog_density = float(p["fog_max"])   # chế độ DEPTH: độ đặc tối đa tại fog_depth_end
	e.fog_depth_begin = float(p["fog_begin"])
	e.fog_depth_end = float(p["fog_end"])
	e.fog_depth_curve = 1.4
	e.fog_sun_scatter = float(p["scatter"])
	e.fog_sky_affect = float(p["sky_fog"])
	e.glow_enabled = true
	e.glow_intensity = float(p["glow"])
	e.glow_strength = 1.1
	e.glow_bloom = float(p["bloom"])
	e.glow_hdr_threshold = float(p["thr"])
	e.glow_hdr_luminance_cap = float(p["cap"])   # đèn trần / màn hình rất sáng không loé thành quầng lớn
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.6)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = float(p["exposure"])
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.02
	e.adjustment_contrast = float(p["contrast"])
	e.adjustment_saturation = float(p["sat"])
	e.adjustment_color_correction = lut(look)
	return e


static func _apply_sun(sun: DirectionalLight3D, p: Dictionary, outdoor: bool, q: int) -> void:
	sun.rotation_degrees = Vector3(-float(p["elev"]), float(p["azim"]), 0.0)
	sun.light_color = p["sun"]
	sun.light_energy = float(p["energy"])
	sun.light_indirect_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_opacity = float(p["shadow_opacity"])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_DIST_OUTDOOR[q] if outdoor else SHADOW_DIST_INDOOR
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.15
	sun.directional_shadow_split_3 = 0.35
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.light_angular_distance = 0.5
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.6
	sun.shadow_blur = 1.6


## Mọi vật liệu (duy nhất) trên GeometryInstance3D dưới `node` + mọi node thuộc nhóm "vice_neon".
static func _collect(node: Node, mats: Array, seen: Dictionary, neon: Array) -> void:
	_collect_node(node, mats, seen, neon)
	for c: Node in node.get_children():
		_collect(c, mats, seen, neon)


## Như _collect nhưng chỉ chính `node` (node mới vào cây: con của nó tự phát node_added riêng).
static func _collect_node(node: Node, mats: Array, seen: Dictionary, neon: Array) -> void:
	if node.is_in_group(NEON_GROUP):
		neon.append(node)
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		_add_mat(gi.material_override, mats, seen)
		_add_mat(gi.material_overlay, mats, seen)
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			if mi.mesh:
				for si: int in range(mi.mesh.get_surface_count()):
					_add_mat(mi.get_surface_override_material(si), mats, seen)
					_add_mat(mi.mesh.surface_get_material(si), mats, seen)
		elif gi is MultiMeshInstance3D:
			var mmi := gi as MultiMeshInstance3D
			if mmi.multimesh and mmi.multimesh.mesh:
				var mesh: Mesh = mmi.multimesh.mesh
				for si: int in range(mesh.get_surface_count()):
					_add_mat(mesh.surface_get_material(si), mats, seen)
		elif gi is CSGShape3D:
			var cm: Variant = gi.get("material")   # CSGBox3D / CSGCylinder3D / ... (vạch đỗ xe, thảm võ)
			if cm is Material:
				_add_mat(cm, mats, seen)


static func _add_mat(m: Material, mats: Array, seen: Dictionary) -> void:
	if m == null or seen.has(m):
		return
	seen[m] = true
	mats.append(m)


static func _is_outline(m: Material) -> bool:
	if not (m is ShaderMaterial):
		return false
	var sh: Shader = (m as ShaderMaterial).shader
	return sh != null and sh.resource_path.ends_with(OUTLINE_SHADER_FILE)


## Một vật liệu: true nếu vừa đổi. ShaderMaterial (mặt tiền shader, nước...) chỉ được bỏ viền outline ở next_pass.
## Giá trị gốc lưu ở meta "vice_orig" cho _unstylize().
static func _stylize(m: Material) -> bool:
	if m.has_meta("vice_done"):
		return false
	m.set_meta("vice_done", true)
	_ever_stylized = true
	if m is BaseMaterial3D:
		var s := m as BaseMaterial3D
		s.set_meta("vice_orig", {"next_pass": s.next_pass, "normal_enabled": s.normal_enabled, "diffuse_mode": s.diffuse_mode,
			"specular_mode": s.specular_mode, "roughness": s.roughness, "emission_enabled": s.emission_enabled,
			"emission": s.emission, "emission_texture": s.emission_texture, "emission_energy_multiplier": s.emission_energy_multiplier,
			"emission_operator": s.emission_operator})
		var energy: float = s.emission_energy_multiplier
		if s.has_meta(NIGHT_LINE_META) and not s.has_meta(FACADE_META):
			# vạch sơn: phát chính màu / ảnh của nó, nhẹ (không loé), _night_layers chỉ bật ban đêm
			var col: Color = s.albedo_color
			s.emission = Color(col.r, col.g, col.b)
			s.emission_texture = s.albedo_texture
			s.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
			s.emission_energy_multiplier = NIGHT_LINE_ENERGY
			s.set_meta("vice_soft_emitter", true)
		elif s.emission_enabled and energy > 0.0 and energy <= SOFT_EMITTER_MAX and not s.has_meta(FACADE_META):
			s.set_meta("vice_soft_emitter", true)
		if _is_outline(s.next_pass):
			s.next_pass = null                              # bỏ viền toon
		s.normal_enabled = false                            # PS2 không có normal map
		s.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT     # bỏ toon ramp
		var glossy: bool = s.metallic > 0.35 or s.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or s.clearcoat_enabled
		if glossy:
			if s.specular_mode == BaseMaterial3D.SPECULAR_TOON:
				s.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		else:
			s.roughness = maxf(s.roughness, 0.9)
			s.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return true
	if m is ShaderMaterial and _is_outline((m as ShaderMaterial).next_pass):
		m.set_meta("vice_orig", {"next_pass": (m as ShaderMaterial).next_pass})
		(m as ShaderMaterial).next_pass = null
		return true
	return false


## Ngược của _stylize: trả giá trị gốc từ meta "vice_orig", gỡ các thẻ vice_*. true nếu vật liệu đã từng chuyển kiểu.
static func _unstylize(m: Material) -> bool:
	if not m.has_meta("vice_done"):
		return false
	var o: Dictionary = m.get_meta("vice_orig", {})
	if m is BaseMaterial3D and not o.is_empty():
		var s := m as BaseMaterial3D
		s.next_pass = o["next_pass"]
		s.normal_enabled = bool(o["normal_enabled"])
		s.diffuse_mode = o["diffuse_mode"]
		s.specular_mode = o["specular_mode"]
		s.roughness = float(o["roughness"])
		s.emission = o["emission"]
		s.emission_texture = o["emission_texture"]
		s.emission_energy_multiplier = float(o["emission_energy_multiplier"])
		s.emission_operator = o["emission_operator"]
		s.emission_enabled = bool(o["emission_enabled"])
	elif m is ShaderMaterial and o.has("next_pass"):
		(m as ShaderMaterial).next_pass = o["next_pass"]
	for tag: StringName in VICE_TAGS:
		if m.has_meta(tag):
			m.remove_meta(tag)
	return true


## Đèn cửa sổ trên một vật liệu mặt tiền MapBuilder (dùng chung mọi toà nhà cùng kiểu; kiểu không có đèn hoặc ban ngày
## -> tắt emission). Chỉ cộng ảnh cửa sổ (emission màu đen + ảnh), không làm cả mặt tường sáng lên.
static func _window_light(mat: BaseMaterial3D, energy: float) -> void:
	var st: String = String(mat.get_meta(FACADE_META, ""))
	var t: Texture2D = window_emission_texture(st, mat) if energy > 0.0 and st in WINDOW_STYLES else null
	if t == null:
		mat.emission_enabled = false
		return
	mat.set_meta("vice_window", true)
	mat.emission_enabled = true
	mat.emission = Color.BLACK
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
	mat.emission_texture = t
	mat.emission_energy_multiplier = energy


# ---------------------------------------------------------------------------
# Node sinh ra sau apply: SceneTree.node_added -> gom -> xử lý deferred cuối frame
# ---------------------------------------------------------------------------
## Nối node_added (một kết nối cho cả cây, dùng chung mọi root) và nhớ root; gỡ khi root rời cây.
static func _watch(root: Node) -> void:
	if root.has_meta("vice_watch") or not root.is_inside_tree():
		return
	root.set_meta("vice_watch", true)
	_watched[root.get_instance_id()] = root
	var cb := Callable(ViceStyle, "_on_node_added")
	var tree: SceneTree = root.get_tree()
	if not tree.node_added.is_connected(cb):
		tree.node_added.connect(cb)
	root.tree_exiting.connect(Callable(ViceStyle, "_unwatch").bind(root), CONNECT_ONE_SHOT)


static func _unwatch(root: Node) -> void:
	_watched.erase(root.get_instance_id())
	if root.has_meta("vice_watch"):
		root.remove_meta("vice_watch")
	if not _watched.is_empty():
		return
	var cb := Callable(ViceStyle, "_on_node_added")
	var tree: SceneTree = root.get_tree()
	if tree and tree.node_added.is_connected(cb):
		tree.node_added.disconnect(cb)


## true khi cây đang có kết nối node_added của ViceStyle (test dùng).
static func is_watching(tree: SceneTree) -> bool:
	return tree != null and tree.node_added.is_connected(Callable(ViceStyle, "_on_node_added"))


static func _on_node_added(node: Node) -> void:
	if not (node is GeometryInstance3D or node.is_in_group(NEON_GROUP)):
		return
	_pending.append(node)
	if not _flush_queued:
		_flush_queued = true
		Callable(ViceStyle, "_flush_pending").call_deferred()


## Root đang theo dõi gần nhất chứa node (null = node không thuộc cảnh nào đã áp phong cách).
static func _watched_root_of(node: Node) -> Node:
	var p: Node = node
	while p:
		if p.has_meta("vice_watch"):
			return p
		p = p.get_parent()
	return null


static func _flush_pending() -> void:
	_flush_queued = false
	var nodes: Array = _pending
	_pending = []
	for v: Variant in nodes:
		if not is_instance_valid(v):
			continue
		var n: Node = v
		if not n.is_inside_tree():
			continue
		var r: Node = _watched_root_of(n)
		if r == null:
			continue
		var mats: Array = []
		var neon: Array = []
		_collect_node(n, mats, {}, neon)
		if r.has_meta("vice_look"):
			for m: Material in mats:
				_stylize(m)
			_night_layers(mats, neon, String(r.get_meta("vice_look")))
		else:
			for m: Material in mats:
				_unstylize(m)
			_night_layers([], neon, "")
