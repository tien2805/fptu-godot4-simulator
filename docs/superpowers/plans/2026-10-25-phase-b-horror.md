# Story Phase B: Horror Toolkit + Night Building (B-D3, B-D4): Implementation Plan

Spec: `docs/superpowers/specs/2026-10-25-story-phase-b-days-1-4-design.md` (B-D3, B-D4, tests from B-D12). Branch
`phase-b-horror`, base 91a6c53. Parallel branches own melee combat and cinematics; the integration agent wires Day 4's night
escape to the Level API below, so this branch never touches `StoryMissions.gd`, `StoryRoam.gd`, timelines, combat or
weapon files, `ThirdPersonController.gd` or `FreeRoam.gd`.

**Goal.** A reusable horror toolkit (`scripts/horror/`) and a standalone Night Building level
(`scenes/story/NightBuilding.tscn`) that the owner can open and play, and that the story can drive through a small API.

**Architecture.**
- `HorrorKit` (Node) composes one level's horror layer: the player (`ThirdPersonController`, built by the level), the
  flashlight, the shared `HorrorSenses`, the stalkers, the hiding spots and the `ScareDirector`. It turns the player's state
  into senses (position, lit, noise radius, hidden spot) each physics frame, owns hide / leave, [F] and [E], and reports a
  catch. Levels add their own objectives on top (an `interact_hook` for [E]).
- Stalkers move on a `HorrorNavGraph` (hand-placed waypoint graph, Dijkstra; nearest node with a line-of-sight check), not
  NavigationServer: cheaper and exact in 3 m corridors. Stalkers are plain Node3D (no physics body); sight uses one ray at
  10 Hz, a catch needs a clear ray too.
- `ScareDirector` owns every horror sound and scare: heartbeat by nearest-stalker distance (+3 dB while hidden), breath loop
  while hidden, whisper bed, flicker events on emissive light groups, the jump-scare budget, the catch scare, the
  "Giảm hù dọa" variant. Cues come from `StoryAudio` (warmed on worker threads at build).
- `NightBuildingMap` (static) builds the floor in code from campus materials and returns the data the level needs (nav
  graph, hiding spots, fuse and battery candidates, fuse box, doors, light groups, patrol routes). `NightBuilding` is the
  level: fuses, checkpoints, doors, escape, HUD, the API.

**Global constraints.** Pure GDScript, Godot 4.7.2, no plugins, CPUParticles3D only, code-drawn textures or existing campus
textures; Vietnamese plain UI text without emoji or decorative symbols; class_name scripts reach autoloads only through
`get_node_or_null` (`StoryUtil`); no dynamic light except the flashlight (emergency lights are emissive); tests use
`_check()` + `quit(1)`; never stage `.import`.

## Task 1 – Toolkit core

Files: `scripts/horror/HorrorFlashlight.gd`, `HidingSpot.gd`, `HorrorNavGraph.gd`, `HorrorSenses.gd`, `HorrorStalker.gd`,
`ScareDirector.gd`, `HorrorKit.gd`; test `tests/test_horror_toolkit.gd`.

Interfaces:
- `HorrorFlashlight` (Node3D, SpotLight3D child): `BATTERY_S = 90`, `FLICKER_BELOW = 0.2`; `battery` 0..1, `on`,
  `toggle()`, `set_on(v) -> bool` (refused when empty), `is_lit()` (the stalker-sight flag: on with charge), `add_battery(frac)`,
  `tick(delta)` (drain + flicker; auto from `_physics_process`), `flicker_off` (visual blip), `gentle` (reduced scares: dim
  pulse, no blips), `anchor` / `aim` (player and camera it follows). Signals `toggled(on)`, `emptied`.
- `HidingSpot` (Node3D, local -Z = the way out): `kind` locker | stall | desk, `USE_RADIUS`, `exit_point()`, `exit_yaw()`,
  `peek_cam` (low camera; mouse look ±45° / ±20°), `door` (optional node swung on enter / reveal), `occupied`, `reveal()`.
  Factory `HidingSpot.make(kind, xform, door)`.
- `HorrorNavGraph` (RefCounted): `add_node(pos, name) -> id`, `connect_nodes(a, b)`, `id_of(name)`, `nearest(pos, space)`,
  `path_ids(a, b)`, `route(from, to, space) -> PackedVector3Array`, `nodes_within(pos, r)`, `reachable(a, b)`.
- `HorrorSenses` (RefCounted): `pos`, `hidden`, `spot`, `lit`, `noise` (m).
- `HorrorStalker` (Node3D): states PATROL, SUSPICIOUS, CHASE, SEARCH, CHECK; `FOV_DEG = 70`, `SIGHT = 14`, `SIGHT_LIT = 22`,
  `CATCH_R = 1.2`, `SEARCH_S = 15`; `setup(graph, senses, patrol_ids, start_index)`, `can_see()`, `can_hear()`, `sense()`,
  `step(delta)`, `notice_hide(spot) -> bool`, `hear_at(pos)`, `reset_at(pos)`, `frozen`, `state`, `state_log`, `los_fn`;
  signals `state_changed(old, new)`, `caught_player(stalker)`. Look: identical student clone + sheep mask on the Head bone.
- `ScareDirector` (Node): `MAX_JUMP = 2`, `MIN_GAP_S = 60`; `reduce_scares`, `budget`, `clock`, `try_jump_scare() -> bool`,
  `can_jump_scare()`, `play_catch_scare()`, `last_scare` {soft, flash, screech, shake, cues}, `cue_db(cue)`, `play_cue(cue,
  db)`, `set_threat(dist, hidden)`, `set_hidden(on)`, `register_light_groups(groups)`, `flicker_near(pos, dur)`,
  `flicker_events`, `figure` (Node3D shown in front of the camera on a full scare). Signal `scared(info)`.
- `HorrorKit` (Node): `setup(player, flashlight, scare, graph)`, `add_stalker(s)`, `add_spot(spot)`, `hide_in(spot) -> bool`,
  `leave_hiding() -> bool`, `nearest_spot(pos)`, `player_noise()` (sprint 10 m, jog 6 m, walk on Ctrl 3 m, still 0),
  `nearest_stalker_dist()`, `prompt_text()`, `catch_enabled`, `interact_hook`, `hidden_spot`; signals `caught(stalker)`,
  `hide_changed(spot)`.

Tests: battery drain and flicker, empty and pickup; hide and exit (player hidden, peek camera current, breath on, back at the
exit point); a stalker that saw the player enter checks the spot and catches, one that did not walks past; cone, lit range,
sprint / walk hearing (also from the real controller's speeds); state flow patrol → suspicious → chase → search (15 s) →
patrol; catch at 1.2 m, not at 1.5 m nor through a wall; scare budget and the 60 s gap; reduced variant (soft sting, no
flash, no screech, horror cues -6 dB).

## Task 2 – Night Building

Files: `scripts/horror/NightBuildingMap.gd`, `scripts/horror/NightBuilding.gd`, `scripts/horror/HorrorHUD.gd`,
`scenes/story/NightBuilding.tscn`; tests `tests/test_night_building.gd`, `tests/smoke_all_stages.gd` (scene list).

Map (local metres, floor y = 0): courtyard x ±30, z ±15 (paving, grass, trees, the golden toad) behind window walls; ring
corridor 3 m wide to x ±33, z ±18; rooms 9 m deep out to x ±42, z ±27. North: C1, C2, generator room (fuse box), C3, C4.
South: toilet block A, C5, lobby (locked glass doors at z = 27, porch outside), C6, toilet block B. Locker banks on the west
and east corridor walls and in the south corridor. Classrooms: long desk rows, a teacher's desk (under-desk spot). Toilets:
4 stalls each. Emergency fixtures are emissive groups (corridor sides and rooms); the only light node is the flashlight.

Level API (also at the top of `NightBuilding.gd`):
- `setup(opts)`: `protagonist` (CharacterBuilder opts, default `StoryUtil.hero_opts()` or the roam player), `seed` (int;
  fuse and battery spots, patrol phases; random when standalone), `reduce_scares` (bool override, default the GameFX
  setting), `auto_retry` (default true: retry 2.5 s after a catch), `stalkers` (default 4), `jump_budget` (default 2),
  `catch_enabled` (default true). Call before or right after adding the scene; a later call rebuilds.
- Signals `escaped(caught_count)`, `caught`, `fuse_placed(n)`, `checkpoint`.
- `retry_from_checkpoint()`; state `fuses_placed`, `fuses_carried`, `caught_count`, `doors_unlocked`, `state`
  (play | caught | escaped), `player`, `kit`, `stalkers`, `scare`, `flashlight`, `hud`, `fuse_candidates`, `active_fuses`.
- Rules: 3 fuses in a random 3 of 6 candidates (one per classroom); placing each one at the fuse box saves a checkpoint;
  3 battery pickups (random 3 of 6 candidates, +60 % each); 4 stalkers; the lobby doors unlock at 3 fuses (the generator
  noise draws every stalker towards the generator room); walking out through the doors emits `escaped`. A retry puts the
  player at the checkpoint, returns carried fuses to their spots, keeps placed fuses, battery at least 25 %, and puts each
  stalker at its patrol waypoint farthest from the checkpoint.
- HUD: "Cầu chì: n/3", battery bar, objective, prompts "[E] Trốn", "[E] Ra", "[E] Nhặt cầu chì", "[E] Lắp cầu chì",
  "[E] Nhặt pin", hint "[F] Đèn pin"; plain text.

Tests: build (rooms, spots, pickups, stalkers, a single light node, plain HUD text); fuse candidates differ by seed and every
one is reachable on the graph from the start with clear rays; fuse placement emits `fuse_placed` 1..3 and `checkpoint`;
caught → retry from checkpoint; doors block until unlocked, then walking out emits `escaped(caught_count)`.

## Task 3 – Perf gate

File: `tests/test_horror_perf.gd` (new; `test_mayhem_perf.gd` is untouched). Night Building, 4 stalkers patrolling, the
flashlight on, the player walking a corridor loop with catching off: 120 physics frames against a baseline with stalkers,
kit, director and flashlight disabled. Gate < 3 ms per physics frame by the median and the 5 %-trimmed mean (same method as
`test_mayhem_perf.gd`). Run on AC power and report.

## Verification

`godot --headless --import --path .` after the new class_names; `--check-only`; the three new tests; `smoke_all_stages`.
Logs grepped for "SCRIPT ERROR" and "ERROR:".
