# Plan: traffic lamps at night (OB-D6, Agent B)

Spec: `docs/superpowers/specs/2026-10-26-owner-bike-and-night-lights-design.md`, OB-D6 and the `test_traffic_lamps.gd` part of OB-D7.

## Facts that shape the design

- `PropBuilder.lens(color, energy)` caches by colour only, in `CharacterBuilder._mat_cache`. The same white and red lenses are shared with the player's bike, lamp posts and other props, so the traffic lamps cannot reuse them.
- `ViceStyle.forget_cached_materials()` replaces `CharacterBuilder._mat_cache` on every art-style change. Traffic lamp materials therefore live in PropBuilder's own static vars, so a switch always reaches every vehicle built earlier.
- `CharacterBuilder.bake()` merges surfaces by material reference. A shared material survives baking, so changing its emission energy relights every baked vehicle at once.
- ViceStyle tags emitters with energy <= 0.5 as "soft emitters" (night-only on/off). The day energy stays above 0.5, so the lamps are never tagged.
- `FreeRoam.set_time_of_day` runs once before `_build_traffic()` (traffic is still null then). It returns early when the preset is unchanged.

## Tasks

1. **PropBuilder lamp materials** (`scripts/PropBuilder.gd`)
   - Four shared materials: car/bus head and tail, moto head and tail. Their day energies equal today's literals: car/bus 1.4 and 1.0, moto 1.8 and 1.2. The daytime look does not change, in Stage 1 too.
   - `traffic_lamp(kind)` returns one of them, created lazily. `kind` is one of "head", "tail", "moto_head" or "moto_tail".
   - `set_traffic_lamps(on)` sets the night or day energy (and a slightly brighter albedo) on all four. It always writes the values, with no early return, so an art-style restore cannot desync them.
   - `traffic_lamps_on()` returns the current state.
   - `build_car` and `build_bus` use the traffic lamps; they have no non-traffic callers.
   - `build_scooter` uses them only with the new opt `"traffic_lamps": true`. The player's bike, the menu bikes, parked bikes, the Stage 2 rival and BikerEnemy keep the shared `lens()`.
   - Amber indicators and police siren lamps are unchanged.
2. **RoamTraffic** (`scripts/roam/RoamTraffic.gd`)
   - `static func is_dark_preset(preset)`: true for night, sunset and dawn.
   - `set_night_lamps(on)`: calls `PropBuilder.set_traffic_lamps(on)` and shows or hides the light pools. It runs once per time-of-day change.
   - `lamps_on` var. `setup()` applies `is_dark_preset(roam.tod_preset)`. New vehicles built later (police) take the current state. Respawned vehicles need nothing, because the materials are shared.
   - MOTO and POLICE scooters pass `"traffic_lamps": true`.
   - Light pool: one `LampPool` MeshInstance3D per CAR and BUS, a flat quad on the road ahead. It uses one shared mesh per kind and one shared material: unshaded, additive, no depth write, a code-built radial GradientTexture2D, no shadow, tagged `vice_done`. The pool is visible only while the lamps are on, and only near the camera through `visibility_range_end` (40 m), at no script cost. It is hidden while the vehicle is wrecked and re-synced on park.
   - `_exit_tree` resets the lamps to day, so the static state does not leak into Stage 1 or the menu.
3. **FreeRoam** (`scripts/FreeRoam.gd`): one line in `set_time_of_day`, `if traffic: traffic.set_night_lamps(RoamTraffic.is_dark_preset(key))`.

## Tests: `tests/test_traffic_lamps.gd`

- **Day:** the lamps are dim. After `build_car`, `build_bus` and the traffic `build_scooter`, the baked meshes reference the shared traffic materials, at day energies.
- **Night:** `set_night_lamps(true)` makes the materials bright and shows the pools. Switching back to day dims them and hides the pools.
- **Sharing:** two cars share one head material (the same reference); vehicles carry no per-vehicle material.
- **Untouched props:** a non-traffic scooter and `lens()` are unaffected by the switch.
- **Setup:** RoamTraffic set up with a stub roam at "night" starts lit; at "morning" it starts dim; "dawn" and "sunset" count as dark.
- **Leaks:** freeing RoamTraffic resets the lamps to day.

Existing tests to run: `test_roam_traffic`, `test_free_roam`, `test_stage1_race`, `smoke_all_stages`, `--check-only`. Perf gates and the full regression are run by the integrator.
