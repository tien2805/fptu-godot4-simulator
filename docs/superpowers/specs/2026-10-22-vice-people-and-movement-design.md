# Vice People and GTA-style Movement: Design

Date: 2026-10-22. Status: design approved by the owner in chat; this spec awaits the owner's review.

## Goal

Make the people and their movement feel like GTA Vice City, without copying its clothes:

1. **PS2-era human models** for every character when `GameFX.art_style == "vice"`: realistic proportions, a low-poly head with a painted face, no cartoon outline. Every preset keeps today's outfit and colours.
2. **GTA-style on-foot movement** for the player: walk, jog and sprint with stamina, lean into turns, inertia, idle fidgets, jump and running jump, and falls that end in a soft landing, a roll or a splat.
3. **Pedestrians in FreeRoam** that wander the sidewalks and react to the player: they stumble and complain, get knocked down and stand up again, including when the bike hits them.

## Owner decisions

| # | Decision |
|---|---|
| P-D1 | Body source: the Quaternius rigged bodies already in the repo (CC0, `assets/models/quaternius/`) plus a new code-built PS2 head. No downloads. |
| P-D2 | Models change only in the vice style. Classic keeps today's characters exactly. |
| P-D3 | Movement and pedestrians are gameplay, so they apply in both art styles. |
| P-D4 | Controls: jog by default; hold Shift to sprint, with about 6 s of stamina as in Vice City, recovering when not sprinting; hold Ctrl to walk; Space jumps on foot (Space stays "drift" on the bike). F, E, T, M, Z, C and Esc are unchanged. |
| P-D5 | Falls never hurt (there is no health system): below 2.5 m a soft landing, 2.5 to 6 m a forward roll, above 6 m a splat for 1.5 s, then the character stands up. |
| P-D6 | Hitting pedestrians, on foot or by bike, has no penalty. |
| P-D7 | Pedestrians exist only in FreeRoam. Stages keep their scripted NPCs (which still get the PS2 model in vice). |
| P-D8 | Clothing is unchanged: no 1980s wardrobe. |

## Non-goals

1980s outfits, a wanted or police system, health, combat or punching, changes to NPC traffic, pedestrians inside stages, downloaded animation libraries.

This spec supersedes two items of `docs/superpowers/plans/2026-10-22-vice-city-art-direction.md`: decision D3 (vice head scale 1.15) becomes realistic head size with the PS2 head, and the outfit part of Task VC-6 (pastel outfits, Hawaiian shirts, white blazer) is dropped. The vehicle paint part of VC-6 stays.

## Current state (2026-10-22, main 46bdac7)

- `CharacterBuilder.build()` builds code-made bodies (capsule limbs, joint spheres, heads scaled 1.26, procedural `Animator`) unless `opts.rigged` or `rigged_default` is true.
- The rigged path (`_build_rigged`) instances one of 7 Quaternius glTF bodies (62 bones, 24 clips: Idle, Idle_Neutral, Walk, Run, Run_Left/Right/Back, Roll, HitRecieve, HitRecieve_2, Death, Punch/Kick, Interact, Wave and gun/sword clips). It hides the original head, recolours surfaces from the preset outfit and attaches a code head to the Head bone with `head_scale_default` (1.3 classic, 1.15 vice). The bodies use flat-colour materials and have no usable UVs (every vertex maps to one point).
- `RigAnimator` maps every game clip (sit, type, ride, carry, pushup and the others in the `Animator` clip table) onto the skeleton by bone rotations, after the AnimationPlayer.
- `rigged_default` is false, so stages build code-made bodies. Only the FreeRoam player is rigged.
- Scooter riders (traffic, main menu, Stage 2 rival) are code-made bodies posed with `pose()` and merged by `bake()`. `pose()` returns early for rigged bodies.
- `ThirdPersonController`: walk 4.2 m/s, run 7.0 m/s with Shift, acceleration 18, deceleration 24, turn lerp 12, step-up 0.35 m, no jump.
- FreeRoam has no NPCs.
- Presets in use: student (student_m, student_f), player, lecturer, proctor, guard, cop, cook, rider, vovinam, master.

## Global constraints

All "Global Constraints" of the Vice City plan apply: pure GDScript, no plugins, code-drawn textures only (Pillow) with `.import` stubs (`importer="keep"`) loaded through FileAccess helpers, style homage only (no Rockstar assets or names), HUD anchors only, `class_name` scripts never write the identifiers `GameFX` or `StageManager`, headless safety, MultiMesh or merged meshes for repeated props, full regression after every task, no push without the owner's permission. Never use a real person's likeness. Dialogue lines are fictional and mild.

## Part 1: PS2 people (vice only)

### Units

**`CharacterBuilder` (modified)**
- New `static var ps2: bool = false`. GameFX sets it in `set_art_style()` (`ps2 = style == "vice"`), the same way it already sets `toon` and `head_scale_default`.
- When `ps2` is true, `build()` uses the rigged path for every preset (as if `rigged = true`) unless the caller passes `rigged: false` explicitly, and it builds the head with `PS2Head.build()` instead of `_build_head()`. No joint spheres, no stylised scaling, no outline (`toon` is already false in vice).
- Body variety (vice only): random height as today (1.74 m × 0.93 to 1.06, × 0.95 for women) plus a body width factor 0.92 to 1.12 applied to the model's X and Z scale. Classic rigged bodies keep today's uniform scale.
- Outfits: `PRESET_BODY`, `_outfit_for()` and `_rig_torso_extras()` keep today's mapping. Gaps to close so each preset reads like its classic outfit: vovinam and master (blue uniform with belt on the casual body), cook (chef hat on the PS2 head, apron), guard and cop (cap, vest or badge), lecturer and proctor (suit body, tie colour), rider (helmet on the PS2 head).
- `pose(root, clip, t, params)` supports rigged bodies: it computes the same bone rotations `RigAnimator` would apply for that clip and sets them on the skeleton once. `bake()` merges a posed rigged body with `MeshInstance3D.bake_mesh_from_current_skeleton_pose()`, so `build_baked_rider()` returns a PS2 rider in vice. Classic riders stay code-made.
- Every public function keeps its signature and behaviour: `build`, `get_animator`, `pose`, `build_baked_rider`, `play`, `stop_clip`, `set_base_clip`, `set_speed`, `set_param`, `look_at_point`, `set_expression`, `get_pivot`, `head_top`, `set_opacity`, `bake`.

**`PS2Head` (new, `scripts/characters/PS2Head.gd`, `class_name PS2Head extends RefCounted`)**
- `static func build(parent: Node3D, opts: Dictionary) -> Node3D` returns the head pivot named `Head`, with children `HeadMesh` (face material), hair, optional glasses, cap, helmet or chef hat, and a `HeadTop` pivot. It writes `rig["head"]`, `rig["face_mesh"]` and `rig["head_top"]` like `_build_head()`. Options: skin index, sex, face variant 0..2, hair style and colour, seed, outfit flags.
- Mesh: 250 to 400 triangles generated from a parametric profile: cranium, brow ridge, cheekbones, jaw and chin, a nose wedge and flat ears. Smooth normals except at the jaw line and nose ridge. Seed and sex vary jaw width, nose length and cheek width by a few millimetres.
- Size: head height about 0.23 m for a 1.74 m person (1/7.5 of the body), i.e. realistic, not enlarged.
- Face texture: one atlas per skin tone (4), sex (2) and face variant (3), 512×256 px, 8 cells of 128×128: `open`, `closed`, `happy`, `angry`, `surprised`, `done`, `talk`, `pain`. The face front is UV-mapped to one cell; `set_expression()` and blinking switch cells through the material's `uv1_offset` on a per-character material, so no texture swaps happen at runtime. The sides and back of the head use the skin and hair colours.
- Hair: low-poly shells for every existing style (`short`, `side_part`, `spiky`, `undercut`, `bob`, `ponytail`, `long`, `bun`) with a painted strand texture. Hair never pokes through the face and never sinks into the skull in Idle, Walk, Run, Sit or Ride.
- `PS2Head` never writes the identifiers `GameFX` or `StageManager`.

**Textures (`generate_character_textures.py`, modified)**
- `make_ps2_face_atlas(tone, sex, variant)` writes `assets/textures/char_ps2_face_<tone><sex><variant>.png` (24 files): PS2-style painted eyes, brows, nose shading, lips and, for some men, stubble; each cell draws one expression.
- `make_ps2_hair()` writes `assets/textures/char_ps2_hair.png` (a greyscale strand pattern tinted by the hair colour).
- Every PNG gets an `.import` stub with `importer="keep"`.

### Look acceptance
- A lineup of every preset in vice at day (`tests/preview_people.gd`, new) and a face close-up sheet. Faces read clearly at 3 m and 10 m. No seam at the neck. Each preset is recognisable next to its classic counterpart (same outfit colours and props).

## Part 2: GTA-style movement (both styles)

### Units

**`ThirdPersonController` (modified)**
- States: `GROUND`, `JUMP`, `AIR`, `LAND_SOFT`, `LAND_ROLL`, `SPLAT`. External code can read `move_state: String`.
- Speeds: walk 1.7 m/s (hold Ctrl), jog 4.2 m/s (default), sprint 7.5 m/s (hold Shift).
- Stamina: 6.0 s when full. It drains 1.0 per second while sprinting faster than 5 m/s and refills 0.8 per second after 1.0 s without sprinting. At zero the character drops to jog until stamina is back above 25 %. Exposed as `stamina: float` (0..1) for a HUD bar.
- Inertia: acceleration 14 to jog and 9 to sprint (sprint builds up), deceleration 18. Releasing the input above 6 m/s plays a 0.25 s skid (lean back).
- Turning: the body turns toward the input at 10 rad/s when jogging and 6 rad/s when sprinting (wider arcs). The body leans into the turn by `lean_deg = clamp(0.6 × turn_rate_rad_s × speed_m_s, -14, 14)`, so a sprint turn at 3 rad/s reaches the full 14°.
- Jump: Space while grounded, with a 0.12 s input buffer and 0.1 s coyote time. Standing jump apex 0.9 m. A running jump keeps the horizontal speed (about 3.5 to 4 m at sprint). No double jump. Air steering is 30 % of ground steering.
- Landing, by drop height (highest point of the airborne phase minus the landing point):
  - below 2.5 m: `LAND_SOFT`, a 0.15 s knee bend that keeps the momentum;
  - 2.5 to 6 m: `LAND_ROLL`, the pack `Roll` clip for 0.8 s, keeping 70 % of the speed forward, steering only;
  - above 6 m: `SPLAT`, the character falls flat (pack `Death`) for 1.5 s, then stands up (`Death` played backwards, 0.9 s), with no input meanwhile and a camera shake.
- Air pose: after 0.5 s in the air or below -6 m/s vertical speed the character flails.
- Camera: the field of view widens by 6° while sprinting (smoothed), a small vertical bob while running, a shake on roll and splat. The existing camera collision stays.
- Input actions registered by the controller when missing: `walk` (Ctrl), `jump` (Space), plus the existing `sprint` (Shift). While the bike is mounted the controller is disabled, as today.
- Water: jumping into the canal triggers the existing rescue logic. Jump height must not let the player climb over the low-deck guards or bank walls; the existing free-roam water tests must stay green.

**`RigAnimator` (modified; locomotion layer)**
- Speed blend: Idle at 0, Walk up to 2 m/s, Run (time-scaled) for jogging, and Run with a sprint overlay: faster stride, forward lean 12°, arm swing amplitude × 1.6 applied as bone offsets after the AnimationPlayer.
- Lean: the roll of the hips and chest follows `set_param(root, "lean", v)`.
- Idle fidgets: every 6 to 12 s one of: weight shift (hip sway), look around (head yaw ±50°), `Idle_Neutral`.
- New clips, playable through `CharacterBuilder.play(root, name)`: `jump_takeoff`, `jump_air`, `fall_flail`, `land_soft`, `skid`, `stumble` (pack `HitRecieve` or `HitRecieve_2`), `knockdown` (pack `Death`), `getup` (`Death` played backwards), and `roll` (pack `Roll`, already mapped).
- New parameter: `set_param(root, "sprint", 0..1)`.
- The procedural `Animator` of code-made bodies gets simple versions of the same clips so stage code can call them on any body without errors.

## Part 3: Pedestrians in FreeRoam (both styles)

### Units

**`PedWalkGraph` (new, `scripts/roam/PedWalkGraph.gd`, `class_name PedWalkGraph extends RefCounted`)**
- `static func build(md: MapData, opts: Dictionary = {}) -> PedWalkGraph`: nodes and edges from sidewalk lines on both sides of every carriageway that MapBuilder gives a sidewalk (offset `width / 2 + 1.6 m`), footway roads, campus walkways (from `FPTUCampusBuilder` local layout through `real_plot_transform()`) and the BE6 plaza.
- It drops every point that lies in water, inside a building footprint or on a carriageway, and splits edges longer than 12 m.
- Queries: `random_point_near(pos: Vector3, r_min: float, r_max: float) -> Dictionary` (node id and position), `next_node(node: int, came_from: int) -> int`, `node_pos(node: int) -> Vector3`, `node_count() -> int`. A spatial hash keeps queries under 0.2 ms.
- Never writes the identifiers `GameFX` or `StageManager`.

**`Pedestrian` (new, `scripts/roam/Pedestrian.gd`, `class_name Pedestrian extends CharacterBody3D`)**
- Capsule radius 0.28 m, height 1.7 m, with a rigged CharacterBuilder model (PS2 head in vice, the rigged demo head in classic).
- Preset by area: on and around the campus 90 % `student` (both sexes) and 10 % `lecturer`; in Vinhomes and around Vincom 60 % `casual`, 30 % `student` (students live there) and 10 % `lecturer` (office workers).
- States: `WALK` (1.1 to 1.6 m/s along graph edges), `IDLE` (stand, look around or look at a phone, 2 to 6 s), `STUMBLE` (0.8 s), `KNOCKDOWN` (fall 1.2 s, then `getup` 0.9 s), `FLEE` (walk fast away from the player for 3 s).
- Steering: separation from other pedestrians and the player within 1.2 m. If no progress for 3 s, the pedestrian picks a new edge.

**`PedestrianSpawner` (new, `scripts/roam/PedestrianSpawner.gd`, `class_name PedestrianSpawner extends Node3D`)**
- `setup(md: MapData, player: Node3D, opts: Dictionary = {})` with `count` (default 24), `spawn_min` 40 m, `spawn_max` 80 m, `despawn` 110 m. It spawns out of the camera view where possible and recycles pedestrians through a pool.
- `pedestrians() -> Array`, signal `pedestrian_hit(ped: Pedestrian, kind: String)` with kind `bump`, `sprint` or `bike`.
- LOD: beyond 45 m the model animates at half rate (the existing RigAnimator LOD) and physics uses a cheap ground snap instead of `move_and_slide`; beyond 90 m the pedestrian is hidden until it is recycled.

### Reactions

| Contact | Pedestrian | Player |
|---|---|---|
| Player on foot below 5 m/s | `STUMBLE`, side step 0.6 m, one line | nothing |
| Player sprinting above 6 m/s | `KNOCKDOWN` away from the player, one line, then `FLEE` | slows for 0.2 s |
| Bike above 3 m/s | `KNOCKDOWN` with a short throw (kinematic arc 0.5 s, 2 to 4 m by speed), one line, then `FLEE` | the bike loses 25 % of its speed |
| Bike below 3 m/s | `STUMBLE`, one line | nothing |

- Lines: a `PED_LINES` bank of mild, fictional Vietnamese complaints, shown as a Label3D bubble above the head for 2 s, at most one bubble every 4 s across all pedestrians.
- Pedestrians keep 3 m away from hotspot rings and never block the BE6 spawn point. Hotspots react only to the player.

### Integration
- FreeRoam creates the spawner after the world is built and passes the player and MapData.
- Contact detection lives in `Pedestrian`: each physics frame it tests the distance to the player body (on foot) or the bike (when mounted) against the sum of both radii plus 0.05 m, and reads their horizontal speed (`ThirdPersonController.horizontal_speed`, the bike's speed). The pedestrian applies the reaction from the table, tells the spawner through `pedestrian_hit`, and the spawner slows the player or the bike. A 1.0 s cooldown per pedestrian stops repeated hits.

### Amendment 2026-10-22: dense crowds and ambient traffic

The owner asked for many more NPCs ("nhiều npc trong trường, đường và khu dân cư", FreeRoam feels empty). This amendment replaces the single 24-pedestrian ring above; everything else in Part 3 stays.

- **Density targets (daytime; night presets scale every target to 30 %):**
  - campus (the plot, the courtyard and the Đường D1 frontage): at least 40 pedestrians within 80 m of the player, 90 % students;
  - Vinhomes residential streets and plazas: at least 30 residents within 80 m (casual walkers, joggers at 2.5 m/s, slow strollers at 0.8 m/s);
  - corridor roads: at least 15 pedestrians on the verges within 80 m, plus ambient traffic (below).
- **Three tiers by distance to the player (or the bike when mounted):**
  - near, up to 35 m: full `Pedestrian` (physics, contact reactions), at most 40;
  - mid, 35 to 90 m: `Pedestrian` without physics (cheap ground snap) and animation on the existing RigAnimator distance LOD, at most 40;
  - far, 90 to 220 m: crowd impostors, at most 200. Each impostor is a baked, posed PS2 person (`CharacterBuilder.bake`) drawn through one MultiMesh per baked variant (8 variants per zone), gliding along walk-graph edges with transforms updated at 10 Hz. An impostor that comes within 90 m is promoted to a `Pedestrian` built with the same preset and seed (and the reverse when it leaves), so a walker never changes identity.
- **Ambient traffic (new unit `RoamTraffic`, FreeRoam only):** 20 to 30 motorbikes plus a few cars and buses moving kinematically along MapData carriageways (lanes > 0, not footways) within 150 m of the player, keeping to the right-hand lane, slowing and stopping behind a blocked vehicle, pedestrian or the player, recycled beyond 200 m. Riders are PS2 baked riders in vice (Task 4) and today's riders in classic. Vehicles have simple box colliders so the player's bike can bump into them; the existing `PlayerBike` crash handling applies. No traffic inside the campus plot.
- **Performance gate:** FreeRoam with full daytime density at least 45 fps at the BE6 spawn, the campus main gate and on Nguyễn Xiển (RTX 4050, 1280x720, quality 2, V-Sync off).
- **Testing:** `tests/test_pedestrians.gd` part C checks the density targets in each zone, the tier caps, promotion/demotion keeping preset and seed, and the 30 % night scaling; a new `tests/test_roam_traffic.gd` checks lane keeping, stopping behind an obstacle, recycling and the 150 m / 200 m radii.
- The plan's Tasks 9 to 12 are re-planned in detail for this amendment before Task 9 starts.

## Error handling and edge cases

- Missing Quaternius model: fall back to the code-made body with the PS2 head and log a warning.
- Missing PS2 face atlas: plain skin material, no crash, a warning.
- Empty walk graph (no map data): the spawner disables itself with a warning.
- Runtime art-style switch: existing characters keep their model until the scene reloads (the settings text already says classic applies fully on re-entry). New characters follow the new style.
- A pedestrian that falls below the map or gets stuck for 10 s is recycled.
- Landing exactly on a step-up edge must not flicker between `AIR` and `GROUND`.

## Testing

- `tests/test_character_builder.gd` (extended): in vice every preset builds a rigged body with a PS2 head (world head height 0.21 to 0.25 m, no joint spheres, no outline material); `set_expression()` changes the face cell; blinking works; a posed rigged rider bakes into one mesh; the classic path builds the same node structure as before (fingerprint of three presets stored from main).
- `tests/test_locomotion.gd` (new, headless controller with input overrides): stamina lasts 6 s ± 0.3 s and refills; walk speed 1.7 m/s; standing jump apex 0.85 to 0.95 m; running jump at sprint covers at least 3.2 m; drops of 2, 4 and 8 m give `LAND_SOFT`, `LAND_ROLL` and `SPLAT` with the stated lock times; no state flicker on stairs and step-ups.
- `tests/test_pedestrians.gd` (new): the walk graph has more than 500 nodes and none in water, buildings or carriageways; the spawner keeps 18 to 30 pedestrians within 80 m of a moving dummy player and recycles those beyond 110 m; a walk bump gives `STUMBLE`, a sprint bump gives `KNOCKDOWN` and the pedestrian is walking again within 3 s; a bike hit gives `KNOCKDOWN` and slows the bike; 24 pedestrians cost under 3 ms per physics frame headless.
- The full regression list of the Vice City plan, including every stage bot test with vice PS2 models (vice is the default) and `test_free_roam` water and hotspot checks.
- Previews: `docs/preview/vice_people_lineup.png`, `vice_people_faces.png`, `vice_move_sprint.png`, `vice_move_jump.png`, `vice_move_roll.png`, `vice_roam_peds_*.png`.

## Performance gates

RTX 4050, 1280×720, quality 2, V-Sync off: FreeRoam with 24 pedestrians at least 45 fps at the BE6 spawn and at the campus gate; every stage at least 45 fps with PS2 people (Stage 3, Stage 5 and the Extra exam have the largest crowds); building one character under 15 ms after the first (scenes, meshes and atlases cached).

## Order and dependencies

1. Part 1 (CharacterBuilder vice path, PS2Head, textures, rigged pose and bake).
2. Part 2 (ThirdPersonController states, RigAnimator locomotion layer). It follows Part 1 because both edit `CharacterBuilder.gd`, where `RigAnimator` lives.
3. Part 3 (walk graph, pedestrians, spawner) after Part 2, which supplies the reaction clips, and after the VC-2 and VC-4 branches are merged, because all three edit `FreeRoam.gd`.
