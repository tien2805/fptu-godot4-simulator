# Vice City Art Direction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert all graphics of FPTU Student Simulator (main menu, the 7 stages, the open world) to a "GTA Vice City" look: 1980s Miami pastel palette, sunset skies, heavy distance haze, PS2-era matte shading, palms, neon at night, a period HUD with radar and a money counter. Style homage only.

**Architecture:** A static `ViceStyle` module owns every look decision (environment per time of day, 3D LUT, material stylisation, night emitters). `GameFX.upgrade_scene_visuals()` dispatches to it when the new `GameFX.art_style` setting is `"vice"` (default) and keeps the current renderer path as `"classic"`. Content builders gain the missing period props (palm fields, neon layers, window lights) as opt-in layers, and the UI helpers in `GameFX` switch to a vice theme so every stage HUD follows without per-stage rewrites. A reusable `ViceHUD` adds the radar, money, clock, wanted-style stars and area names to the open world and Stage 1.

**Tech Stack:** Godot 4.7.2, pure GDScript (no C#, no plugins), Pillow/numpy for offline textures, headless SceneTree tests, windowed preview scripts saving PNGs to `user://preview/`.

**Reference implementation (already in the repo, commit 34c9541):** `tests/preview_vice_lookdev.gd` renders the approved direction (images `docs/preview/vice_lookdev_*.png`). Every value below was tuned there; port code from it instead of re-deriving:
- `VICE` presets dictionary (sunset/day/night), `_apply_vice_env()`, `_vice_lut()`, `_vice_material()` / `_vice_materials_pass()`, `_soft_emitters` handling, `_window_emission()` / `_set_window_lights()`, `_frond()` / `_vice_palm()`, `_build_neon()`, `_italic_font()`, `_hud_label()`, inner classes `StarRow` and `Radar`.

## Global Constraints

- Pure GDScript, Godot 4.2+ API; no C#, no plugins or addons; keep folder structure, scene names and `class_name`s.
- No AI-generated images; textures only drawn or processed by code (Pillow); every new PNG gets an `.import` stub with `importer="keep"` and is loaded through `FPTUCampusBuilder.load_texture()` / `GameFX.load_image_any()` (FileAccess) so exported builds work.
- Style homage only: no Rockstar assets, fonts (no Pricedown), logos, names, radio station names or music. Fonts: Godot's built-in fallback font with `FontVariation` (synthetic italic via `variation_transform = Transform2D(Vector2(1, slant), Vector2(0, 1), Vector2.ZERO)`, `variation_embolden`).
- Real places keep real names; brands stay fictionalised (see `tools/osm_to_mapdata.py:DISPLAY_NAME`). FPT University branding (orange logo, signs) stays orange.
- HUD only with anchors/containers (`GameFX.anchored_panel`, `make_label`, `MarginContainer` presets); `tests/test_hud_bounds.gd` must pass at all its resolutions.
- `class_name` scripts used by `--script` tests compile before autoloads: never write the identifiers `GameFX` or `StageManager` inside `ViceStyle.gd`, `MapBuilder.gd`, `MapData.gd`, `FPTUCampusBuilder.gd`, `CharacterBuilder.gd`, `PropBuilder.gd`. Read settings through `get_node_or_null("/root/GameFX")`.
- Headless safety: no RenderingDevice work when `DisplayServer.get_name() == "headless"`; tests must not depend on GPU features.
- Performance gates (dev laptop RTX 4050, 1280x720, quality 2): main menu >= 60 fps, every stage >= 45 fps, FreeRoam >= 45 fps at the BE6 spawn and at the campus gate. Repeated props (palms, neon, lamps) must be MultiMesh or merged meshes, never hundreds of separate nodes (the look-dev hit 11 fps with 198 node-built palms).
- After every task: `godot --headless --quit --check-only --path . > check.log 2>&1` (0 `ERROR`), `godot --headless --path . --script tests/smoke_all_stages.gd > smoke.log 2>&1` (0 `ERROR:` / `SCRIPT ERROR`), the bot tests of every touched stage, `tests/test_hud_bounds.gd`. Do not pipe Godot output through `head`/`grep` directly; redirect to a file. A failed `assert` inside `_initialize` hangs a `--script` run: use a `_check(cond, msg)` helper that prints and calls `quit(1)`.
- Write files containing Vietnamese text with the file tools, not bash heredocs.
- Commit after every green task; never push, tag or release without the owner's explicit permission.
- Prerequisite: the real-map plan (`docs/superpowers/plans/2026-10-22-real-map-world.md`) Tasks 5-6 are merged (FreeRoam, Stage 1 on the real route). Tasks below that touch FreeRoam/Stage 1 assume those files exist.

## Owner decisions (defaults used unless the owner answers otherwise)

| # | Decision | Default in this plan |
|---|---|---|
| D1 | Vice look replaces the current look, or is a switchable style | Switchable: `art_style = "vice"` by default, `"classic"` kept in Settings |
| D2 | UI palette | Vice palette (dark purple panels, pink `#FF5FB0` / cyan `#3FF2FF` borders, italic headings); FPT orange only on FPT-branded items |
| D3 | Character proportions in vice | Keep the hybrid rigged bodies and code heads, no toon outline, head scale 1.15 instead of 1.3 |
| D4 | Temporal "trails" smear (signature PS2 effect) | On at sunset and night, off by day; Settings toggle |
| D5 | HUD semantics | Money = "Cóc Vàng" (CV) wallet from the open-world plan; 5 stars = "Thầy Toàn để ý" (lecturer attention) |

## Time-of-day mapping

Existing stage presets keep their names; `ViceStyle` maps them to vice looks:

| `GameFX` preset (used by) | Vice look | Notes |
|---|---|---|
| `dawn` (Main menu, Stage 1 07:05) | `dawn` = new pink/peach sunrise derived from `sunset` with the sun in the east (azimuth +85), fog begin 120 / end 1800 | Stage 1 rides into the sunrise |
| `morning` (Stage 2) | `day` | |
| `noon`, `midday_open` (Stage 4, Stage 5) | `day` with exposure +0.04, glow threshold 1.85 | midday glare without painted lines blooming |
| `morning_indoor`, `exam` (Stage 3, Extra) | `indoor` = warm fluorescent: ambient `#ffe9d6` 1.35, no fog, glow 0.4 / threshold 1.3, LUT shadows `#3a3a6e`, highlights `#fff0dc` | interiors stay readable |
| `night` (Stage 6) | `night` | neon + window lights on |
| FreeRoam `T` cycle | `dawn` -> `day` -> `sunset` -> `night` | open world |

Values for `sunset`, `day`, `night` are the final ones in `tests/preview_vice_lookdev.gd` `VICE` (day: sun energy 1.45, exposure 1.18, glow threshold 1.75; night: windows 0.12, glow 0.9 / threshold 1.1; sunset: fog 150 / 2200). Night ambient goes down to 0.2 (look-dev 0.3 still read too light).

---

### Task VC-1: `ViceStyle` core and the art-style switch

**Files:**
- Create: `scripts/ViceStyle.gd` (`class_name ViceStyle extends RefCounted`), `tests/test_vice_style.gd`
- Modify: `scripts/GameFX.gd` (settings `art_style`, `trails_enabled`; `upgrade_scene_visuals()` dispatch; `set_art_style()`), `scripts/MainMenu.gd` and `scripts/StageManager.gd` (settings UI: "Phong cách đồ hoạ: Vice City / Cổ điển" and "Vệt sáng (trails)"), `scripts/CharacterBuilder.gd` (no API change; `toon` and a new `static var head_scale_default: float = 1.3` are set by GameFX)

**Interfaces:**
- Produces (`ViceStyle`, all static):
  - `const LOOKS: Dictionary` (keys `dawn`, `day`, `sunset`, `night`, `indoor`, values like the look-dev `VICE` entries plus `"windows"`, `"neon"` (bool), `"soft_emitters"` (bool), `"trails"` (float 0..1))
  - `static func look_for_preset(preset: String) -> String` (table above)
  - `static func apply(root: Node, preset: String, quality: int, trails_enabled: bool) -> void` — finds the first `WorldEnvironment` and `DirectionalLight3D` under `root` (same lookup as `GameFX._find_first`), builds a fresh `Environment` exactly like the look-dev `_apply_vice_env()` (ProceduralSky colours, ambient colour source, SDFGI/SSIL/SSAO/SSR/volumetric fog OFF, `fog_mode = FOG_MODE_DEPTH`, glow levels 1-4, Filmic tonemap, adjustments, `adjustment_color_correction = lut(look)`), sets the sun, then calls `stylize_materials(root)` and `set_night_layers(root, look)`; stores `root.set_meta("visual_preset", preset)` and `root.set_meta("vice_look", look)`.
  - `static func lut(look: String) -> ImageTexture3D` (32^3, cached, from the look-dev `_vice_lut()`)
  - `static func stylize_materials(root: Node) -> int` (look-dev `_vice_materials_pass()`: outline `next_pass` removed, normal maps off, Lambert, matte non-glossy materials; returns how many materials changed; materials are tagged with `set_meta("vice_done", true)` instead of a script-level dictionary so caches shared across scenes are processed once)
  - `static func set_night_layers(root: Node, look: String) -> void` — toggles soft emitters (materials with `emission_energy_multiplier <= 0.5`, tagged `vice_soft_emitter`), every node in group `vice_neon` (visible only when `LOOKS[look]["neon"]`), window lights (`MapBuilder._mat_for_style()` facade materials, energy `LOOKS[look]["windows"]`)
- Produces (`GameFX`): `var art_style: String = "vice"`, `var trails_enabled: bool = true`, `func set_art_style(style: String) -> void` (saves settings, sets `CharacterBuilder.toon = style == "classic"` and `CharacterBuilder.head_scale_default = 1.3 if classic else 1.15`, re-applies the current scene's preset via `get_tree().current_scene.get_meta("visual_preset")`), settings keys `video/art_style`, `video/trails`.
- `upgrade_scene_visuals(root, preset)`: first line `if _art_style() == "vice": ViceStyle.apply(root, preset, _quality(), _trails()); return` where the new statics `_art_style() -> String` (default `"vice"`) and `_trails() -> bool` (default `true`) read `/root/GameFX` exactly like the existing `_quality()` does, so `--script` tests without autoloads get the defaults.
- `CharacterBuilder._build_rigged()`: replace the literal default in `float(opts.get("head_scale", 1.3))` with `head_scale_default`.

- [ ] **Step 1: failing test** `tests/test_vice_style.gd`: build a minimal scene (WorldEnvironment + DirectionalLight3D + one `CharacterBuilder.build({"preset": "student_m"})` + one `MapBuilder.build_building()` for the first vinhomes building + a `StandardMaterial3D` with emission 0.3), call `ViceStyle.apply(scene, "morning", 2, true)`, then `_check` that: environment `sdfgi_enabled == false`, `fog_mode == Environment.FOG_MODE_DEPTH`, `adjustment_color_correction is ImageTexture3D` with depth 32, glow enabled; no StandardMaterial3D in the scene has `next_pass` or `normal_enabled`; the emission-0.3 material is disabled by day and enabled after `ViceStyle.apply(scene, "night", 2, true)`; `ViceStyle.look_for_preset("exam") == "indoor"`; applying twice does not stack (material count unchanged, meta `vice_done` present). Print `✅ SUCCESS: VICE STYLE OK`.
- [ ] **Step 2:** run, expect parse error (no `ViceStyle`).
- [ ] **Step 3:** implement `ViceStyle.gd` by porting the look-dev functions; add the `dawn` and `indoor` looks; night ambient 0.2.
- [ ] **Step 4:** wire `GameFX` (settings load/save, dispatch, `set_art_style`), add the two settings rows to the main menu settings panel and the pause settings (`GameFX.build_audio_settings`-style rows: `OptionButton` for the style, `CheckButton` for trails); make sure `CharacterBuilder.toon` is set from settings in `GameFX._ready()` BEFORE any scene builds characters.
- [ ] **Step 5:** `godot --headless --import --path .`, run the new test, check-only, smoke, `tests/test_main_menu.gd`, `tests/test_hud_bounds.gd`, all stage bot tests (visual change only, gameplay must be identical).
- [ ] **Step 6:** windowed `tests/preview_stages.gd` (existing) produces the 7 stages in vice; copy to `docs/preview/vice_stage_*.png`; inspect every image: indoor stages (3, Extra) must stay readable, Stage 6 night must not be blown out.
- [ ] **Step 7:** commit `feat(vice): ViceStyle environment/LUT/material stylisation with an art-style switch (vice default, classic kept)`.

### Task VC-2: Palms v2 as MultiMesh fields

**Files:**
- Modify: `scripts/PropBuilder.gd` (new `static func palm_meshes() -> Dictionary`, `static func build_palm_field(parent: Node3D, points: PackedVector3Array, opts: Dictionary = {}) -> Node3D`), `scripts/FPTUCampusBuilder.gd` (`build_royal_palm()` delegates to the new palm for single palms), `scripts/MapBuilder.gd` (`opts.palms: bool = false`, `opts.palm_spacing: float = 14.0`), `scripts/FreeRoam.gd` and `scripts/RoadManager.gd` (pass `palms: true` when the art style is vice), `tests/test_mapbuilder.gd`
- Create: `tests/test_palms.gd`

**Interfaces:**
- `palm_meshes()` returns `{"trunk": ArrayMesh, "crown": ArrayMesh, "materials": {...}}`: trunk = 5 tapered rings merged into one mesh with alternating ring colours as two surfaces; crown = 12 fronds (look-dev `_frond()`) + 3 coconuts merged into one mesh (one surface per material). Cached statically.
- `build_palm_field(parent, points, opts)` creates ONE `MultiMeshInstance3D` for trunks and ONE for crowns; per-instance transform = random yaw, height 8.5..13 m (trunk scaled in Y, crown translated to the top with the trunk lean), lean 0..0.12; `opts.seed`, `opts.cast_shadow` (crowns cast, trunks cast); returns a Node3D named `PalmField` with meta `palm_count`.
- MapBuilder palms: along carriageways (`lanes > 0`, not `service`) both sides at `width / 2 + 2.6` every `palm_spacing` m, skipping points within 3 m of another road, inside a building footprint, or in water (`Geometry2D.is_point_in_polygon`); hard cap 1500 per region; one `PalmField` per region.
- Campus: palms on the campus-side verge of Đường D1 (`v = -3.2`) and the far side (`v = ROAD_CENTER_V - 9`) every 13 m skipping 9 m around each gate (look-dev `_add_palms_d1()`), built only when `opts.palms` is passed to `build_authentic_campus`.

- [ ] Step 1: `tests/test_palms.gd`: `build_palm_field` with 500 points creates exactly 2 MultiMeshInstance3D with 500 instances each and < 6 surfaces in total; MapBuilder `vinhomes` with `palms: true` creates one `PalmField` with 200..1500 palms, none inside a building polygon or water polygon; print counts.
- [ ] Step 2-4: implement, run the test, `tests/test_mapbuilder.gd`, smoke.
- [ ] Step 5: performance check in a windowed preview (`tests/preview_vice.gd`, created here, successor of the look-dev: same 4 shots plus FreeRoam spawn and Stage 1 start): the street sunset shot must reach >= 45 fps (look-dev: 11 fps).
- [ ] Step 6: commit `feat(vice): MultiMesh palm fields along real roads and Đường D1`.

### Task VC-3: Night layers (neon, window lights, street lamps)

**Files:**
- Modify: `scripts/MapBuilder.gd` (`opts.neon: bool = false` builds the look-dev neon as one MultiMesh per colour in group `vice_neon`, roof edge `height + 0.55` and ground-floor band `3.6 m`, plus vertical corner tubes on `mall` and `shophouse`; add UV2 per building: `uv2 = (building_id % 997) / 997 + local storey index` so the window-light shader can vary lit windows per building and storey), `scripts/ViceStyle.gd` (`facade_night_material(style) -> ShaderMaterial`: a spatial shader variant of the facade material with the same albedo texture and UV1, plus an emission term `window_mask(uv1) * step(hash(uv2 + floor(uv1)), 0.35)` where `window_mask` is the look-dev glass-pixel mask baked into a second texture, so about 35 % of windows are lit and the pattern differs per building and storey), `scripts/PropBuilder.gd` (`build_lamp_field(parent, points)` MultiMesh lamp posts with emissive heads; real `OmniLight3D` only for the 8 lamps nearest the camera, re-assigned every 0.5 s by a small `LampLights` node), `scripts/FPTUCampusBuilder.gd` (FPT orange signage emission 0.35 stays a soft emitter; gate sign gets a neon frame in group `vice_neon`)
- Create: `tests/test_night_layers.gd`

**Interfaces:**
- `MapBuilder.build_region(..., {"neon": true})` adds node `Neon` (group `vice_neon`, hidden by default). `ViceStyle.set_night_layers()` shows it for `night` (and at 30 % emission for `sunset`).
- Window lights: `ViceStyle.facade_night_material(style: String) -> Material` cached; `set_night_layers` swaps the facade surface material of buildings tagged `building_id` between day material and night material (store both in meta on the MeshInstance3D at build time to avoid lookups).

- [ ] Step 1: test: build `vinhomes` with `neon: true`, apply night: `Neon` visible, its MultiMeshes have > 400 instances; apply day: hidden; at night the facade material of BE6 is the shader variant; lamp field of 200 lamps creates 1 MultiMesh + at most 8 OmniLight3D.
- [ ] Steps 2-4: implement, test, smoke, `tests/test_mapbuilder.gd`.
- [ ] Step 5: `tests/preview_vice.gd` night shots (BE6 street, Vincom, campus gate, Stage 6 lab window view); check: neon readable, towers dark blue-purple with scattered warm windows, no white blow-out, >= 45 fps.
- [ ] Step 6: commit `feat(vice): neon trims, varied window lights and lamp fields for night`.

### Task VC-4: Vice UI theme and `ViceHUD`

**Files:**
- Create: `scripts/ui/ViceHUD.gd` (`class_name ViceHUD extends CanvasLayer`), `scripts/ui/ViceRadar.gd` (`class_name ViceRadar extends Control`), `scripts/ui/ViceStars.gd` (`class_name ViceStars extends Control`), `tests/test_vice_hud.gd`
- Modify: `scripts/GameFX.gd` (`make_panel_style`, `make_label`, `make_bar`, `anchored_panel`, `popup` read the art style: vice = panel bg `Color(0.07, 0.04, 0.14, 0.88)`, border pink `#FF5FB0` unless the caller passes FPT orange explicitly, corner radius 4, labels with outline 6 `#1B0F33` + drop shadow; new `static func vice_font(embolden := 0.6, slant := 0.22) -> FontVariation`), `scripts/StageManager.gd` (result modal + transition card restyle: big italic title "QUA MÔN!" / "TRƯỢT MÔN" / "BỊ BẮT", a pastel gradient strip, "+N Cóc Vàng" line), `scripts/FreeRoam.gd` (use ViceHUD), `scripts/HUDManager.gd` + `scenes/HUD.tscn` (Stage 1: add ViceHUD radar + area names along the route, restyle clock/speed panels through the GameFX helpers)

**Interfaces:**
- `ViceHUD` API: `set_clock(text: String)`, `set_money(amount: int)` (8 digits + " CV", animates counting up over 0.6 s), `set_stars(n: int)` (0..5, flashing for 2 s when it increases), `show_area(name: String)` (bottom-right italic pink `#FF7AC8`, outline `#2A0E3A`, fades in 0.3 s, holds 2.5 s, fades out 0.6 s; ignores repeats within 20 s), `show_vehicle(name: String)` (same style, smaller, above the area name), `radar: ViceRadar`.
- `ViceRadar`: `md: MapData`, `center: Vector2`, `yaw: float`, `range_m: float = 170.0`, `blips: Array[Dictionary]` (`{"pos": Vector2, "color": Color, "shape": "square"|"circle"}`), `route: PackedVector2Array` (drawn in pink); roads cached as a pre-filtered list of segments within 400 m of the last rebuild centre (rebuild when the player moves > 150 m) so `_draw` stays under 1 ms; redraw at 20 Hz.
- Area names: `MapData` gains no API; ViceHUD resolves the area from the nearest named road within 30 m and region polygons: `Vinhomes Grand Park`, `The Beverly` (inside the Beverly residential polygon), `Khu Công nghệ cao`, `Đại học FPT` (inside the campus plot), road names (`Nguyễn Xiển`, `Nguyễn Văn Tăng`, `Đường D1`...).

- [ ] Step 1: `tests/test_vice_hud.gd`: instantiate ViceHUD with MapData at 1280x720 and 1920x1080 (`get_tree().root.size`), check every Control rect is inside the viewport, `set_money(1250)` text ends with "00001250 CV" after the tween finishes, `show_area` twice within 20 s only shows once, the radar draws with 600+ roads in < 2 ms (measure `_draw` time with `Time.get_ticks_usec()`).
- [ ] Steps 2-4: implement; update `tests/test_hud_bounds.gd` to include ViceHUD; run all HUD and stage tests.
- [ ] Step 5: previews of every stage HUD in vice (`tests/preview_stages.gd` with `PREVIEW_HUD=1`) and FreeRoam; check legibility of Vietnamese diacritics in the synthetic italic font at 15 px and up.
- [ ] Step 6: commit `feat(vice): vice UI theme, ViceHUD radar/money/stars/area names, restyled result and transition cards`.

### Task VC-5: Vice title screen

**Files:** Modify `scripts/MainMenu.gd` (and `scenes/MainMenu.tscn` only if node paths change); test `tests/test_main_menu.gd`.

- Background: existing campus scene with the `sunset` look (ViceStyle), palms on, camera shots retimed to slow dolly moves along Đường D1 at golden hour; a second shot over the Beverly towers if FreeRoam data is available.
- Title: "FPTU Student Simulator" in `GameFX.vice_font(0.9, 0.28)` size 64, pink `#FF5FB0` with cyan `#3FF2FF` outline 8 and a soft glow (a duplicate label behind it with `modulate.a = 0.35`, outline 18); subtitle "Đường Đến Trường" in cyan italic; buttons as pastel outlined panels (`GameFX.make_panel_style` vice) with a magenta hover glow; menu music `synth80` (Task VC-8) falling back to `menu`.
- [ ] Steps: update the menu, run `tests/test_main_menu.gd`, preview `docs/preview/vice_menu.png`, >= 60 fps, commit `feat(vice): title screen`.

### Task VC-6: Vehicles and crowd palette

**Files:** Modify `scripts/PropBuilder.gd` (scooter paint palette `PASTEL_PAINTS = [#FF8FC7, #7FE3E0, #FFD27F, #B79CFF, #F4F4F4, #FF6F6F]`, clearcoat 0.7 for the 80s gloss), `scenes/TrafficCar.tscn` / its builder (boxy sedan silhouette and pastel colours), `scripts/CharacterBuilder.gd` (`casual` and crowd presets draw from a pastel outfit palette; new Pillow texture `char_shirt_hawaii.png` (floral pattern, code-drawn) for some casual NPCs; `lecturer_boss` (ThS. ToanHLM) can wear a white blazer over a pastel tee as a nod to 80s TV-detective fashion; students keep the orange FPT polo), `generate_character_textures.py` (the Hawaiian shirt texture), tests `tests/test_character_builder.gd`, `tests/test_wheel_spin.gd`.
- [ ] Steps: implement, regenerate textures (`python generate_character_textures.py`), import, run tests, preview `tests/preview_rigged.gd` + `tests/preview_props.gd`, commit `feat(vice): pastel vehicles, Hawaiian-shirt crowd, 80s outfits`.

### Task VC-7: Trails and film post-processing

**Files:** Create `scripts/fx/ViceTrails.gd` (`class_name ViceTrails extends CompositorEffect`), `scripts/fx/vice_trails.glsl` (compute shader source embedded as a const string in the .gd if loading .glsl files is impractical), `tests/test_vice_trails.gd`; modify `scripts/ViceStyle.gd` (attach a `Compositor` with the effect to the WorldEnvironment's camera or `WorldEnvironment.compositor` when `trails_enabled` and the look's `trails > 0`), `scripts/GameFX.gd` (vignette shader gains subtle grain `0.035` and chromatic aberration `0.0015` in vice).

**Interfaces / behaviour:**
- `ViceTrails`: `effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT`; in `_render_callback`, for each view: get the color image (`render_scene_buffers.get_color_layer(view)`), keep a history texture created through `RenderSceneBuffersRD.create_texture(&"vice_trails", &"history", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage storage|sampling, ...)`, dispatch a compute shader: `out = mix(current, history, strength)` with strength from the look (sunset 0.45, night 0.55, day 0), then copy `out` into history. Skip when `RenderingServer.get_rendering_device()` is null (headless) or size changed this frame (recreate).
- HUD is drawn after POST_TRANSPARENT, so text never smears.
- [ ] Steps: test (headless: instantiating the effect and a Compositor does not crash; `ViceStyle.apply` with trails attaches it only for sunset/night); windowed preview of Stage 1 at night while riding fast (`tests/preview_vice.gd` shot `ride_night_trails`): visible smear on lights, HUD crisp; fps cost < 2 ms; commit `feat(vice): PS2-style trails as a CompositorEffect, grain and chromatic aberration`.
- Fallback if CompositorEffect proves unstable on the target GPU: ship without trails (setting hidden) and log it in the report; do NOT emulate trails with a canvas overlay that smears the HUD.

### Task VC-8: Synth-80s music and scooter radio

**Files:** Modify `scripts/MusicDirector.gd` (styles `synth80` (gated-reverb snare, square/saw bass, arpeggiated lead, chorus pad), `newwave`, `rock80`, `lofi`), `scripts/GameFX.gd` (`music_play` accepts the new styles), `scripts/FreeRoam.gd` + `scripts/RoadManager.gd` (radio while riding: `R` cycles three fictional stations "Cóc FM 88.8" (synth80), "D1 Rock 101" (rock80), "Hoa Giấy Chill" (lofi); station name shown with `ViceHUD.show_vehicle()`-style text; DJ one-liners as subtitles every 60-90 s picked from a new `story/Lines.gd`-compatible bank `RADIO_LINES` (Vietnamese, all fictional)), `tests/test_music.gd`.
- [ ] Steps: extend the music test (each new style plays 2 s without errors and produces non-silent frames), implement, run, commit `feat(vice): synth-80s styles and in-scooter radio`.

### Task VC-9: Gallery, docs, regression

- [ ] `tests/preview_vice.gd`: final gallery (menu, 7 stages, FreeRoam dawn/day/sunset/night, ride at night with trails) -> `docs/preview/vice_*.png`.
- [ ] `PLAN.md` new section "XIII. VICE CITY ART DIRECTION" (English) with commit hashes; `README.md` (Vietnamese, player-facing): one paragraph about the new look and the Settings switch; credits keep the OSM attribution.
- [ ] Full regression: check-only, smoke, all bot tests, HUD bounds, `test_vice_*`, `test_palms`, `test_night_layers`, `test_mapbuilder`, `test_free_roam`; fps table in the report.
- [ ] Commit `docs(vice): gallery and docs`.

## Execution order

1. VC-1 (core) alone.
2. VC-2 (palms) and VC-4 (UI) in parallel worktrees (disjoint files except `GameFX.gd`: VC-2 must not touch it).
3. VC-3 (night) after VC-2 (both touch MapBuilder/PropBuilder); VC-5 (menu) after VC-4.
4. VC-6, VC-7, VC-8 in parallel (disjoint files).
5. VC-9.
