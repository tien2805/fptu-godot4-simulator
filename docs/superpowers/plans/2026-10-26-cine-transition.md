# Plan: no freeze when gameplay cuts into a cinematic

Owner report (Day 4, the Cừu Dolly scenes): the game stands still for seconds before the cinematic shows. Measured
windowed (1280x720): the whole freeze is the synchronous `FreeRoam.play_cinematic`. `cine_stage` costs 0.5-17.6 s,
`CinePlayer.setup` 0.15-0.54 s (actors 0.3-0.52 s), the time-of-day switch 30-70 ms.

## Facts that shape the design

- The stage search is slow because every `_cine_try` scans every clutter item of the region (5429 items at the canteen),
  and the canteen spot fails, so thousands of tries run (ring 24, then the landmark).
- Headless, `MultiMesh.get_instance_transform` returns zero and `MultiMeshInstance3D.get_aabb` is empty, so headless
  tests never see multimesh clutter (campus grass, palm trunks, parked bikes). Windowed, the campus grass fills the
  canteen box, so the real game stages the Day 4 canteen scenes 25-90 m away. The fix keeps the real game's placements
  (no visual change); headless gets the same answer from instance transforms the builders keep.
- The walk itself is cheap (about 60 ms windowed); the tries are the cost.
- One `CharacterBuilder.build` costs 50-75 ms windowed; `duplicate()` of a built body costs about 1.5 ms. Bodies hold node
  references in metas ("rig", "skeleton"), so a duplicate needs those remapped.
- Only opts with a "seed" build the same body twice; without one the build is random, so only seeded opts are cloned.

## Tasks

1. **Multimesh transforms headless** (`FPTUCampusBuilder`, `MapBuilder`, `PropBuilder`, `RoadManager`): every static
   MultiMesh keeps its instance transforms in meta `cine_xforms`. `FreeRoam._cine_clutter_items` reads them (and an AABB
   built from them) when present, so headless and windowed see the same clutter.
2. **Fast, budgeted search** (`FreeRoam`):
   - `cine_stage_search(stage, budget_ms = 0)`: the full search (same rules, same result), with a 4 m XZ grid over the
     clutter items so each try only tests nearby items. `budget_ms > 0` stops after that much wall time and returns the
     first flat candidate or the landmark centre (`cine_stage_info.budget_hit`).
   - `cine_stage(stage)`: baked table, then a per-signature cache, then `cine_stage_search(stage, CINE_SEARCH_BUDGET_MS)`.
     A baked or cached xf is used after one cheap static check (floor rays and floor steps; no mesh scan).
     `cine_stage_info.source` is "baked", "cache" or "search".
3. **Baked placements** (`scripts/cine/CineStage.gd`, `scripts/cine/CineStageBake.gd`):
   - `CineStage.signature(stage)`: landmark, at, yaw, size, near, offset, fallback (tod and exposure do not matter).
   - `CineStage.baked(stage)`: {"xf", "info"} or {}.
   - `CineStage.requests(anchors)`: every stage the game resolves: each timeline's own stage (gallery, F9, previews), each
     story beat's cinematic at its anchor (cine / video slots and choice tails, intros, afters), and the mission spots
     (`MissionCorridor.corridor_stage`, the canteen box).
   - `CineStageBake.TABLE`: generated data; the test prints a replacement file when the map changed.
   - `StoryRoam.stage_cinematic(tl, at_id, opts)`: the anchor rule `_start_cinematic` used, shared with the bake.
4. **Clone cache** (`CineActor`, `CinePlayer`): `CineActor.clone_key(opts)`, `setup(opts, template)` duplicates the
   template's body and remaps its node references; `CinePlayer.setup` clones seeded duplicates within one cinematic.
5. **Prepare ahead** (`scripts/cine/CinePrep.gd`, `FreeRoam`, `StoryRoam`):
   - `FreeRoam.prepare_cinematic(tl, opts)`: one `CinePrep` child resolves the stage now and builds one actor per frame,
     hidden, only while the tree is not paused (never during a cinematic, call or video).
   - `play_cinematic` adopts the prep when slot and stage match (actors whose opts still match; the rest are built).
   - `StoryRoam.upcoming_cinematic(b)`: the next cinematic the current beat will play (cine beat, unseen intro, a mission's
     "after", or the auto cine beat after a mission); `_prepare_upcoming()` runs on refresh and when a mission starts.
6. **Mask the rest** (`CinePlayer`, `FreeRoam`, `StoryBasement`, `StoryIntroCards`, `StoryDayCard`):
   - `CinePlayer.preroll(tl, fade_s, on_black)`: the tree is paused, a black layer fades in over `FADE_S` (0.18 s real
     time); one frame after it is fully black, `on_black` runs setup, hides the world, switches the time of day, applies
     the exposure and starts the cinematic, which fades in from black as before. Music sync is unchanged (r starts at
     `start()`).
   - Hosts fade only when not manual (tests with `manual` keep the synchronous path); opt "fade": false forces it off.
   - The 2D cards stay hidden while the player prerolls. StoryRoam hides the yard's copies under black (opt "on_black").
7. **Existing tests**: the Phase B / Phase C "within 4 m of the explicit point" checks become "at the baked spot" where
   the real game (grass, palms) moves the stage; the reason is printed.

## Interfaces

- `FreeRoam.cine_stage(stage) -> Variant`, `cine_stage_search(stage, budget_ms) -> Variant`, `cine_stage_info`,
  `cine_search_tries`, `prepare_cinematic(tl, opts) -> bool`, `cine_prep`, `play_cinematic(tl, opts)` (opts: "fade",
  "on_black").
- `CineStage.signature / baked / requests`, `CineStageBake.TABLE`.
- `CineActor.clone_key(opts)`, `CineActor.setup(opts, template = null)`.
- `CinePrep.begin(tl, xf)`, `done()`, `take_actors()`, `built`.
- `CinePlayer.setup` opt "actors" (prepared CineActors), `CinePlayer.preroll(...)`, `prerolling`, `clones`.
- `StoryRoam.stage_cinematic`, `upcoming_cinematic`.

## Tests: `tests/test_cine_transition.gd`

- Every stage request resolves from the baked table (no search, `cine_search_tries == 0`), and the static check passes.
- The baked table matches a full search for every request (prints the replacement table and fails when the map changed).
- Headless sees multimesh clutter (the canteen box is cluttered by the campus grass).
- A budgeted search stops within its budget and still returns a transform; the per-signature cache serves the repeat.
- Clone cache: a cloned actor equals a fresh build (nodes, meshes, transforms, metas remapped inside its own body, poses
  after the same cues); unseeded opts are never cloned.
- Prepared actors are adopted by `play_cinematic` (same nodes, no build); a mismatched slot builds fresh.
- Fade ordering: during the preroll nothing is set up and the world is still shown; setup runs only after a black frame.
- The gallery path (timeline stage) and the F9 dev path still play.

Then check-only, smoke, the cine_* tests, test_story_cines, test_story_day0-5, test_story_director, test_chapter_select,
test_busted, test_story_stages. Windowed probe before and after per Day 4 slot plus cine_d1_intro and seg_d2_boss.
