# Real-Map Open World (Vinhomes Grand Park BE6 -> FPTU campus) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first open-world foundation from real geographic data: the player spawns outside tower BE6 (The Beverly, Vinhomes Grand Park), can walk or ride the real 5.5 km road route to the FPT University HCMC campus, and the campus itself is laid out from its real footprint.

**Architecture:** A Python tool derives one shipped data file (`assets/data/mapdata.json`, Godot metres, x = east, z = south, origin = campus centroid) from the raw OpenStreetMap extracts. `MapData` (GDScript) loads it; `MapBuilder` turns roads, building footprints, water and areas into procedural geometry with colliders; `FPTUCampusBuilder` v8 keeps its detailed interiors but is positioned, rotated and resized to the real plot; `FreeRoam` composes the three regions (campus, corridor, Vinhomes) and the existing `PlayerBike`, and Màn 1 drives the real route.

**Tech Stack:** Godot 4.7.2, pure GDScript (no C#, no plugins), Python 3 + Pillow/numpy only for offline texture and data generation, headless SceneTree test scripts (`godot --headless --path . --script tests/x.gd`), windowed preview scripts that save PNGs to `user://preview/`.

## Global Constraints

- Godot 4.2+ compatible pure GDScript; no C#, no plugins, no addons (spec §0).
- Keep the folder structure (`scenes/ scripts/ assets/ tests/ docs/ reference_data/`), existing scene names and `class_name`s.
- Textures are only drawn or processed by code (Pillow); never AI-generated; real photos only as references. Every generated PNG gets a `.import` stub with `importer="keep"` (see `generate_character_textures.py:save`).
- Map data: only `assets/data/mapdata.json` ships; `reference_data/` is `.gdignore`d and excluded from export. Keep the ODbL attribution string from `mapdata.json["attribution"]` visible in the credits/README.
- Real street, area, university and tower names are allowed; commercial brand names use the `display` field (already fictionalised in `tools/osm_to_mapdata.py:DISPLAY_NAME`). Never add a real person.
- HUD uses anchors/containers (`GameFX.anchored_panel`, `make_label`, `make_bar`), never absolute pixel positions.
- After every change run `godot --headless --quit --check-only --path .`, then `godot --headless --path . --script tests/smoke_all_stages.gd` and grep the log for `ERROR:` and `SCRIPT ERROR` (exit code alone is not enough), then the bot tests that cover the touched stage.
- Scripts referenced by `class_name` from a `--script` test compile before autoloads: do not use the `GameFX` or `StageManager` identifiers inside `MapData.gd`, `MapBuilder.gd`, `FPTUCampusBuilder.gd`, `CharacterBuilder.gd`, `PropBuilder.gd`. Use `FileAccess` for files and `get_node_or_null("/root/GameFX")` for optional autoloads.
- New `class_name` scripts need `godot --headless --import --path .` once before tests see them.
- Do not pipe Godot output through `head` (spurious exit 139). Bash heredocs break with Vietnamese text: write scripts with the file tool, not heredocs.
- Coordinates: world metres; x = east; z = south (Godot forward is -Z = north); y up; origin = FPT campus centroid.
- Commit after every green task; never push, tag or release (owner permission required).

---

## Data contract: `assets/data/mapdata.json`

Produced by `tools/osm_to_mapdata.py` (already written and run; 0.26 MB). Top-level keys:

```
attribution: String
frame: {origin_lat, origin_lon, x: "metres east", z: "metres south (Godot -Z = north)", y: "up"}
scope: {campus_radius: 700, vinhomes_radius: 900, vinhomes_center: [x, z], corridor_radius: 150}
landmarks:
  campus_plot: [[x,z]...] (8 pts, closed)         campus_ring_outer / campus_ring_inner: [[x,z]...]
  campus_main_gate: [16.1, 99.5]                   campus_west_gate: [-109.0, -21.5]
  campus_parking_center: [-5.7, -62.3]             campus_pitch_center: [64.2, 3.5]
  hutech_plot: [[x,z]...]                          hutech_building: [[x,z]...]
  be6_outer: [[x,z]...]                            be6_center: [3910.58, -409.06]
  spawn: {x: 3893.22, z: -424.2, yaw_deg: 21.22}   d1_roundabout: [81.5, 214.9]
  bus_stop_fpt: [-131.9, -29.4]                    bus_stop_hutech: [-149.8, 0.1]
route_be6_to_fptu: {length_m: 5478, roads: [[name, metres]...], points: [[x,z]...]}
roads: [{id, name, class, width, lanes, oneway, roundabout, bridge, region, points: [[x,z]...]}]
buildings: [{id, name, display, kind, levels, height, style, region, area, outer: [[x,z]...], inner: [[[x,z]...]...]}]
water: [{id, name, kind: "area"|"line", width?, region, outer?|points?}]
areas: [{id, name, display, kind: park|pitch|parking|pool|water_park|campus|other, tag, region, area, outer}]
pois: [{name, display, kind, x, z, region}]
```

`region` is one of `campus`, `vinhomes`, `corridor`. `style` is one of `tower`, `beverly`, `mall`, `shophouse`, `industrial`. Polygons are closed (first point repeated last). Widths are metres per carriageway; `oneway` ways are one carriageway each (Đường D1 is mapped as two one-way ways).

Counts today: 611 roads (campus 189, vinhomes 282, corridor 140), 143 buildings, 18 water, 121 areas, 88 POIs.

## File structure

| File | Responsibility |
|---|---|
| `tools/osm_to_mapdata.py` (exists) | offline derivation of `assets/data/mapdata.json` |
| `scripts/MapData.gd` (new, `class_name MapData`) | load + typed access to the JSON, polygon helpers, region filters |
| `generate_city_textures.py` (new) | Pillow facades (tower, beverly, mall, shophouse, industrial), road overlay, canal water, grass variants |
| `scripts/MapBuilder.gd` (new, `class_name MapBuilder`) | roads, buildings, water, areas, trees, POI signs -> Node3D per region, with colliders and MultiMesh |
| `scripts/FPTUCampusBuilder.gd` (modify) | v8: real plot placement/rotation, ring 105 x 50, gates, parking, pitch, HUTECH footprint |
| `scripts/ThirdPersonController.gd` (new) | walking player: camera-relative WASD, Shift run, mouse/Q-E orbit, gravity, stairs |
| `scripts/FreeRoam.gd` + `scenes/FreeRoam.tscn` (new) | composes regions + campus + player + scooter + HUD, spawn at BE6 |
| `scripts/RoadManager.gd` (modify) | Màn 1 curve from the real route, corridor scenery via MapBuilder |
| `tests/test_mapdata.gd`, `tests/test_mapbuilder.gd`, `tests/test_free_roam.gd`, `tests/preview_map.gd`, `tests/preview_free_roam.gd` (new) | headless tests and preview renders |

---

### Task 1: `MapData` loader

**Files:**
- Create: `scripts/MapData.gd`
- Test: `tests/test_mapdata.gd`

**Interfaces:**
- Consumes: `res://assets/data/mapdata.json` (contract above).
- Produces:
  - `static func load_default() -> MapData` (cached singleton-like static; returns null and pushes an error if the file is missing)
  - `var data: Dictionary` (raw)
  - `func roads(region: String = "") -> Array[Dictionary]`, `func buildings(region := "") -> Array[Dictionary]`, `func water(region := "") -> Array[Dictionary]`, `func areas(region := "", kind := "") -> Array[Dictionary]`, `func pois(region := "") -> Array[Dictionary]` (empty region = all)
  - `func landmark(key: String) -> Variant`
  - `static func poly(points: Array) -> PackedVector2Array` (JSON [[x,z]] -> Vector2(x, z))
  - `static func to_world(p: Vector2, y: float = 0.0) -> Vector3` (= Vector3(p.x, y, p.y))
  - `func route_points() -> PackedVector2Array`, `func route_length() -> float`
  - `func spawn_transform() -> Transform3D` (origin from `landmarks.spawn`, rotation `yaw_deg` around Y)
  - `func bounds(region: String) -> Rect2` (AABB of all geometry in the region)

- [ ] **Step 1: Write the failing test** `tests/test_mapdata.gd` (SceneTree script):

```gdscript
# File: res://tests/test_mapdata.gd
extends SceneTree
func _initialize() -> void:
	var md: MapData = MapData.load_default()
	assert(md != null, "mapdata.json must load")
	assert(md.roads().size() > 500, "roads")
	assert(md.roads("campus").size() > 100, "campus roads")
	assert(md.buildings("vinhomes").size() >= 40, "vinhomes buildings")
	var be6: Array = md.buildings("vinhomes").filter(func(b: Dictionary) -> bool: return b["name"] == "Tòa BE6")
	assert(be6.size() == 1 and int(be6[0]["levels"]) >= 20, "BE6 present with levels")
	var plot: PackedVector2Array = MapData.poly(md.landmark("campus_plot"))
	assert(plot.size() == 8 and plot[0] == plot[7], "campus plot closed polygon")
	var sp: Transform3D = md.spawn_transform()
	assert(sp.origin.distance_to(Vector3(3893.2, 0.0, -424.2)) < 1.0, "spawn origin")
	assert(md.route_points().size() > 100 and absf(md.route_length() - 5478.0) < 50.0, "route")
	var b: Rect2 = md.bounds("campus")
	assert(b.size.x > 500.0 and b.has_point(Vector2(0.0, 0.0)), "campus bounds contain origin")
	print("✅ SUCCESS: MAPDATA OK roads=%d buildings=%d" % [md.roads().size(), md.buildings().size()])
	quit(0)
```

- [ ] **Step 2: Run it to verify it fails**: `godot --headless --path . --script tests/test_mapdata.gd` -> parse error "Identifier MapData not declared".
- [ ] **Step 3: Implement `scripts/MapData.gd`** with `class_name MapData extends RefCounted`; load with `FileAccess.get_file_as_string("res://assets/data/mapdata.json")` + `JSON.parse_string`; cache in a `static var _cached: MapData`; filters iterate once and return typed arrays; `bounds` unions road points, building outers, area outers of the region.
- [ ] **Step 4: Import and run**: `godot --headless --import --path .` then the test -> `✅ SUCCESS: MAPDATA OK ...`.
- [ ] **Step 5: Commit**: `git add scripts/MapData.gd scripts/MapData.gd.uid tests/test_mapdata.gd tests/test_mapdata.gd.uid assets/data/mapdata.json tools/osm_to_mapdata.py && git commit -m "feat(map): MapData loader for the OSM-derived mapdata.json"`.

### Task 2: City textures (Pillow)

**Files:**
- Create: `generate_city_textures.py`
- Output: `assets/textures/city_tower_facade.png` (+`_n`), `city_beverly_facade.png` (+`_n`), `city_mall_facade.png`, `city_shophouse_facade.png`, `city_industrial_facade.png`, `city_canal_water.png`, `city_road_overlay.png` (lane dashes + edge lines, RGBA), `city_roof_flat.png`, each 512 px wide, tileable horizontally; one tile = one storey vertically for facades (so `uv1_scale.y = levels`).

**Interfaces:** Produces file names above; consumed by `MapBuilder._mat_for_style(style)`.

- [ ] **Step 1:** Write `generate_city_textures.py` reusing `noise()`, `normal_from_height()`, `save()` from `generate_facade_texture.py` (copy the helpers; keep each script standalone). Facade recipes: tower = 4 window bays per 10 m with glass gradient and spandrel bands; beverly = white/cream balconies with glass balustrade and teal accent (The Beverly look); mall = big glazed panels + warm orange signage band; shophouse = ground floor shutter/sign + 2 windows above, random pastel per column; industrial = corrugated panels + roller door.
- [ ] **Step 2:** Run `python generate_city_textures.py`, open the PNGs with the image reader to check tiling and scale (a window must be ~1.2 m wide).
- [ ] **Step 3:** `godot --headless --import --path .` then `godot --headless --quit --check-only --path .`.
- [ ] **Step 4:** Commit: `git add generate_city_textures.py assets/textures/city_* && git commit -m "feat(map): code-drawn city facade and road textures"`.

### Task 3: `MapBuilder`

**Files:**
- Create: `scripts/MapBuilder.gd`, `tests/test_mapbuilder.gd`, `tests/preview_map.gd`

**Interfaces:**
- Consumes: `MapData` (Task 1), textures (Task 2), `FPTUCampusBuilder.make_materials()` for asphalt/sidewalk/granite/grass materials, `FPTUCampusBuilder.build_tropical_tree/build_royal_palm`.
- Produces:
  - `static func build_region(parent: Node3D, md: MapData, region: String, opts: Dictionary = {}) -> Node3D`; opts: `colliders: bool = true`, `roads: bool = true`, `buildings: bool = true`, `water: bool = true`, `areas: bool = true`, `trees: bool = true`, `labels: bool = true`, `skip_building_ids: Array = []` (campus ring and HUTECH are built by FPTUCampusBuilder, so FreeRoam passes their ids), `lod: int = 0` (0 full, 1 no labels/trees, 2 boxes only).
  - `static func build_road(parent: Node3D, points: PackedVector2Array, width: float, opts: Dictionary = {}) -> MeshInstance3D` (ribbon with mitred joints, 0.15 m kerb boxes on both sides unless `opts.kerb == false`, lane overlay texture, `StaticBody3D` collider).
  - `static func build_building(parent: Node3D, b: Dictionary, opts: Dictionary = {}) -> Node3D` (walls: SurfaceTool quads per edge with UV u = edge length / 3.0 m, v = levels; roof: `Geometry2D.triangulate_polygon` of outer minus inner; `ConvexPolygonShape3D` per edge box or a `ConcavePolygonShape3D` from the wall mesh; Label3D with `display` name on the roof edge when `labels`).
  - `static func build_water(parent, w: Dictionary)`, `static func build_area(parent, a: Dictionary, m: Dictionary)` (park = grass plane + 1 tree per 250 m2 inside the polygon using rejection sampling with `Geometry2D.is_point_in_polygon`; pitch = green plane + white lines; parking = dark plane + bay stripes; pool = blue plane -0.3 m; campus/other = light plane).
  - All geometry is y = 0 ground unless `opts.y` given; roads at y = 0.02, pavements at 0.12.

- [ ] **Step 1: Failing test** `tests/test_mapbuilder.gd`: builds `vinhomes` region into a Node3D, asserts: at least 40 `MeshInstance3D` for buildings tagged with meta `building_id`; node named `BE6` exists whose AABB height is between 90 and 100 m (30 levels x 3.2); at least 200 road meshes; one `StaticBody3D` per building when colliders; `build_region` for `corridor` finishes under 5 s (use `Time.get_ticks_msec()`); prints `✅ SUCCESS: MAPBUILDER OK`.
- [ ] **Step 2:** Run -> fails (identifier `MapBuilder`).
- [ ] **Step 3:** Implement `MapBuilder.gd` (no autoload identifiers). Road ribbon algorithm: for each point compute the direction `d_i` (average of adjacent segment directions), normal `n_i = Vector2(-d_i.y, d_i.x)`, offset `w/2 / max(0.5, dot(n_i, n_seg))`; emit two triangles per segment; UV u = cumulative length / 4 m, v = 0..1. Roundabouts (`roundabout == true`) are closed loops: ribbon as usual. Bridges (`bridge == true`): raise y by 6 m with a linear ramp over the first/last 40 m and add side barriers.
- [ ] **Step 4:** Run the test until green, then `godot --headless --quit --check-only --path .`.
- [ ] **Step 5:** `tests/preview_map.gd` (windowed): shots `map_01_beverly_air` (camera 120 m above BE6 looking down 60 deg), `map_02_be6_street` (at the spawn, eye height), `map_03_vincom`, `map_04_campus_air` (above the campus plot, campus region only, no FPTUCampusBuilder yet), `map_05_corridor` (over Nguyễn Văn Tăng). Save to `user://preview/`, copy to `docs/preview/`. Look at them; fix obvious holes (missing roofs, flipped normals, floating kerbs) before committing.
- [ ] **Step 6:** Commit: `git add scripts/MapBuilder.gd tests/test_mapbuilder.gd tests/preview_map.gd docs/preview/map_0*.png && git commit -m "feat(map): MapBuilder renders roads, buildings, water and areas from mapdata.json"`.

### Task 4: `FPTUCampusBuilder` v8 on the real plot

**Files:**
- Modify: `scripts/FPTUCampusBuilder.gd` (constants block lines 36-72, `_build_ring_building`, `_build_gate` call sites in `build_authentic_campus`, `_build_back_facilities` parking, `build_hutech`, add `static func real_plot_transform() -> Transform3D`)
- Modify as needed: `scripts/Stage2_Parking.gd` (route points), `scripts/Stage5_Canteen.gd`, `scripts/MainMenu.gd` (camera shots), `tests/test_stage2_stairs.gd`, `tests/preview_campus.gd`
- Test: existing bot tests `tests/test_stage1_race.gd` ... `tests/test_stage_extra_eos.gd`, `tests/smoke_all_stages.gd`, `tests/test_hud_bounds.gd`

**Interfaces:**
- Consumes: `MapData.landmark("campus_plot")`, `campus_ring_outer`, `campus_main_gate`, `campus_west_gate`, `campus_parking_center`, `campus_pitch_center`, `hutech_building`.
- Produces: unchanged public API (`canteen_center()`, `lab402_room_center()`, `room311_center()`, `stair_foot()`, `stair_top()`, `lab402_door()`, `parking_spot_candidates()`, `park_gate_guard_pos()`, `interior_room_aabbs()`, `build_authentic_campus(parent, origin, rot, opts)`), plus `static func real_plot_transform() -> Transform3D` = the world transform that places the local (u, v) frame onto the real plot: rotation `rot_y_deg = 136.0` (local +u runs from the SE corner towards the NW along Đường D1, local +v points NE into the plot), origin solved so that `Vector3(MAIN_GATE_U, 0, 0)` lands on `campus_main_gate` (world (16.1, 0, 99.5)).
- Local constants become: `PLOT_U = 190.0`, `PLOT_V = 123.0`, `RING_U0 = 42.0`, `RING_U1 = 147.0` (ring length 105), `RING_V0 = 30.0`, `RING_V1 = 80.0` (ring depth 50), `MAIN_GATE_U = 70.0` (the real main gate is near the middle of the D1 edge), `PARK_GATE_U` removed from the D1 side and replaced by a back-gate at the NE edge (`BACK_GATE_V = PLOT_V`), parking strip 128 x 12 m centred at local (u 95, v 108) (the real `campus_parking_center` transformed into local space), pitch 42 x 22 m at local (u 160, v 55).

- [ ] **Step 1:** Add `tests/test_campus_real.gd`: loads `MapData`, computes `FPTUCampusBuilder.real_plot_transform()`, asserts that transforming local corners `(0,0,0)`, `(PLOT_U,0,0)`, `(PLOT_U,0,PLOT_V)`, `(0,0,PLOT_V)` lands each within 12 m of a vertex of `campus_plot` (hull match), that the local main gate lands within 2 m of `campus_main_gate`, and that the ring size constants give 100..110 x 48..52 m. Run -> fails.
- [ ] **Step 2:** Change the constants and derive module counts from the new ring length (front wing modules = round(105 / 14) = 7 or 8; keep `LOBBY_MODULE = 2`, `BACK_GAP_MODULE = 4`, `ATRIUM_MODULES = [1, 2]`, `STAIR_U` recomputed as `RING_U1 - SIDE_D - 5.0`). Keep interiors (Lab 402, room 311, atrium stair, canteen) attached to the same named modules so `lab402_room_center()` etc. still return valid positions.
- [ ] **Step 3:** Run the bot tests one by one; fix the hard-coded numbers in `Stage2_Parking.gd` (route through the back gate and the new parking position), `Stage5_Canteen.gd` (canteen open modules), `MainMenu.gd` camera shots, `preview_campus.gd`. Expected: all 13 tests print `✅ SUCCESS`, smoke has 0 `ERROR:` lines.
- [ ] **Step 4:** `tests/preview_campus.gd` shots + `tests/preview_stage2.gd`; compare with `reference_data/osm/map_900m.png` (ring proportion, gate on D1, parking behind). Copy to `docs/preview/`.
- [ ] **Step 5:** Commit: `git commit -am "feat(campus v8): real plot size, orientation, gate, parking and pitch from OSM; stages re-routed"`.

### Task 5: `FreeRoam` scene with spawn at BE6

**Files:**
- Create: `scripts/ThirdPersonController.gd` (`class_name ThirdPersonController extends CharacterBody3D`), `scripts/FreeRoam.gd`, `scenes/FreeRoam.tscn`, `tests/test_free_roam.gd`, `tests/preview_free_roam.gd`
- Modify: `scripts/StageManager.gd` (add `StageID.FREE_ROAM` scene entry, `return_to_roam` flag, ignore M in FreeRoam), `scripts/MainMenu.gd` (button "Khám phá campus" -> FreeRoam), `tests/smoke_all_stages.gd` (+FreeRoam), `tests/test_hud_bounds.gd` (+FreeRoam)

**Interfaces:**
- Consumes: `MapData`, `MapBuilder.build_region`, `FPTUCampusBuilder.build_authentic_campus(parent, origin, rot, opts)` placed with `real_plot_transform()`, `PlayerBike.tscn` (set `road_path = null`, `lane_clamp_enabled = false`), `CharacterBuilder.build({"preset": "player", "rigged": true})`, `GameFX.upgrade_scene_visuals(root, "outdoor")`, `GameFX.TOD_PRESETS`.
- Produces: `FreeRoam` node with `player: ThirdPersonController`, `bike: PlayerBike`, `func mount_bike()`, `func dismount_bike()`, `func set_time_of_day(preset: String)`, hotspot `Area3D`s named `Hotspot_<StageID>` placed at: D1 main gate (Màn 1 finish line, offers "Chạy lại Màn 1" from BE6), campus back gate (Màn 2), Lab 402 door (Màn 3 day / Màn 6 night), pitch (Màn 4), canteen (Màn 5), room 311 (Extra), BE6 lobby (Màn 1 start). Hotspot `E` -> `StageManager.start_stage(id)` with `return_to_roam = true`.
- Controller: WASD relative to camera yaw, walk 4.2 m/s, Shift 7.0 m/s, gravity 20, `move_and_slide`, capsule 0.4 x 1.7, camera boom 3.2 m behind at 1.6 m height with mouse-look (captured when `Input.mouse_mode` free) and Q/E orbit, collision-aware (RayCast3D from pivot to camera), steps up to 0.35 m (`floor_max_angle` default + `safe_margin`), animation via `CharacterBuilder.set_speed()`.

- [ ] **Step 1:** `tests/test_free_roam.gd` (headless): instantiate `scenes/FreeRoam.tscn`, run 120 physics frames, assert the player stands within 2 m of the spawn and above y = -1 (not falling through), simulate W for 60 frames via `Input.action_press("move_forward")` or direct `player.input_dir = Vector2(0, -1)`, assert it moved > 2 m, call `mount_bike()`, assert `bike.visible` and camera parent switched, call `dismount_bike()`, teleport the player to 30 m from `campus_main_gate` and assert the hotspot area overlaps when moved onto it (use `area.get_overlapping_bodies()` after 2 frames). Print `✅ SUCCESS: FREE ROAM OK`.
- [ ] **Step 2:** Run -> fails (scene missing).
- [ ] **Step 3:** Implement. Scene tree: `FreeRoam (Node3D, script)` -> `World` (regions + campus + HUTECH built in `_ready`), `Player` (ThirdPersonController with `CharacterBuilder` child), `Bike` (PlayerBike instance, hidden until mounted), `HUD` (CanvasLayer: hint label bottom-centre, time-of-day label top-left, FPS top-right; anchors only). Build order in `_ready`: `vinhomes` + `corridor` + `campus` regions with `skip_building_ids = [relation ring id 13698121 is not in buildings; skip HUTECH 605379728]`, then `FPTUCampusBuilder.build_authentic_campus(world, xf.origin, 136.0, {colliders: true})`, then `build_hutech` at the real building centroid. Ground: one `StaticBody3D` with a `WorldBoundaryShape3D` at y = 0.
- [ ] **Step 4:** Performance gate: in the test, assert `_ready` build time < 15 s headless; in the preview script print FPS at the spawn and at the campus (target >= 45 fps on the dev GPU). If below, enable `lod = 1` for `corridor` and MultiMesh for shophouses.
- [ ] **Step 5:** `tests/preview_free_roam.gd`: shots `roam_01_spawn_be6`, `roam_02_canal`, `roam_03_vincom`, `roam_04_ride_nguyen_xien` (on the bike), `roam_05_campus_gate_from_d1`, `roam_06_campus_air`. Copy to `docs/preview/`, inspect, fix.
- [ ] **Step 6:** Run `check-only`, smoke (now including FreeRoam), `test_hud_bounds`, `test_main_menu`. Commit: `git commit -am "feat(free roam): open world from BE6 to the campus on real map data"`.

### Task 6: Màn 1 on the real 5.5 km route

**Files:**
- Modify: `scripts/RoadManager.gd` (`_build_real_world_curve`, `_build_landmarks_and_fptu_campus`, `_build_vinhomes_zone`, `_build_world_ground_and_safety_barriers`), `scripts/RoadEvents.gd` (event positions by route fraction), `scripts/TrafficSpawner.gd` (unchanged API; verify it follows the new curve), `scenes/Main.tscn` only if node paths change, `tests/test_stage1_race.gd` (bot time budget), `scripts/StageManager.gd` (`stage_info` title text: route names)
- Test: `tests/test_stage1_race.gd`, `tests/test_near_miss.gd`, `tests/preview_stages.gd`

**Interfaces:**
- Consumes: `MapData.route_points()` (5.5 km), `MapBuilder.build_region(corridor)`, `FPTUCampusBuilder.real_plot_transform()`.
- Produces: `RoadPath` curve = the route resampled every 8 m with Catmull-Rom smoothing of corners, y = 0 except bridges from `roads[].bridge`; finish line at `campus_main_gate`; start at `landmarks.spawn` (BE6). Time limit: keep the 07:05 -> 07:30 fiction: 25 minutes real-world distance at 80 km/h is ~4 min, so `STAGE_TIME` becomes 240 s and the near-miss bonus seconds scale x1.5; `max_speed_ms` unchanged.

- [ ] **Step 1:** Update `tests/test_stage1_race.gd` expectations: track length 5300..5600 m, bot finishes under 240 s with the existing auto-driver (if the bot cannot finish, lower traffic density on the corridor to 0.7x). Run -> fails (length 1900).
- [ ] **Step 2:** Replace the hand-made curve with the route; build corridor scenery with `MapBuilder.build_region(scenery_root, md, "corridor", {labels: false, lod: 1})` plus the `vinhomes` region behind the start (lod 2) and the real campus at the end. Delete the old fake Vinhomes zone and landmark placements that no longer match (keep the textures for shophouse signs on corridor buildings via `style == shophouse`).
- [ ] **Step 3:** Run `test_stage1_race`, `test_near_miss`, smoke; `tests/preview_stages.gd` shot for stage 1 at the start (BE6 behind), mid-route (Nguyễn Văn Tăng), finish (D1 gate).
- [ ] **Step 4:** Commit: `git commit -am "feat(stage 1): the ride follows the real BE6 -> FPTU route with corridor scenery from map data"`.

### Task 7: Docs and credits

- [ ] `README.md`: add the OpenStreetMap attribution line and a "Thế giới mở" paragraph (controls: WASD, Shift, F bike, E hotspot, T time, ESC).
- [ ] `PLAN.md` section XII "Thế giới mở trên bản đồ thật" summarising tasks 1-6 with commit hashes.
- [ ] Credits in `MainMenu` guide panel: "Map data (c) OpenStreetMap contributors (ODbL)".
- [ ] Commit: `git commit -am "docs: open world on real map data"`.

---

## Execution order and parallelism

- Phase 1 (parallel, disjoint files): Task 1, Task 2.
- Phase 2 (parallel, disjoint files): Task 3 (needs 1 + 2), Task 4 (independent; touches FPTUCampusBuilder + stages).
- Phase 3 (parallel): Task 5 (needs 3 + 4), Task 6 (needs 3 + 4).
- Phase 4: Task 7, then a full regression (`run_game.bat` equivalent: check-only, smoke, all 13 bot tests, hud bounds) and preview review by the owner.

Parallel workers must use separate git worktrees (each runs `godot --headless --import --path .` first) and must not touch files owned by the other task of the same phase. Merge order: 1, 2, then 3, 4, then 5, 6.
