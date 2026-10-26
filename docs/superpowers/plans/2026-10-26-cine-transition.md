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
5. **Prepare ahead, cheap work only** (`scripts/cine/CinePrep.gd`, `FreeRoam`, `StoryRoam`):
   - `FreeRoam.prepare_cinematic(tl, opts)`: a `CinePrep` (RefCounted) keeps the loaded timeline and its resolved stage.
     No actor is built during live play: a build costs 50-80 ms windowed and would stutter the game.
   - `play_cinematic` takes the prepared stage when slot, stage signature and opts "xf" match (both null, or the same xf).
   - `StoryRoam.upcoming_cinematic(b)`: the next cinematic the current beat will play (cine beat, unseen intro, a mission's
     "after", or the auto cine beat after a mission); `_prepare_upcoming()` runs on refresh and when a mission starts.
6. **Mask the rest** (`CinePlayer`, `FreeRoam`, `StoryBasement`, `StoryIntroCards`, `StoryDayCard`):
   - `CinePlayer.preroll(tl, fade_s, under_black, go)`: the tree is paused, a black layer fades in over `FADE_S` (0.18 s
     real time). Under black, one piece of work per frame: `under_black` (the host hides the world, switches the time of
     day, applies the exposure), then one actor per frame (clone cache), then `go` (setup adopting those actors, start).
     The cinematic fades in from black as before; music sync is unchanged (r starts at `start()`).
   - `CinePlayer.wants_preroll(tl, opts)`: the hosts' default for opts "fade". No fade when manual (tests), and none for a
     hard cut: a timeline with fade_in 0 or with scare hits keeps the immediate cut with a synchronous setup.
   - The 2D cards are hidden from `_ready` while the player prerolls. StoryRoam hides the yard's copies under black.
   - `_cine_go` never returns without `finished` (it calls `_finish(true)` on any failure).
7. **Stage robustness**: a budget fallback is never cached; every off-table resolution warns (all story stages are baked).
   `cine_stage_ok` reads only the map's static floor (every body shares collision layer 1, so it looks through anything
   that is not a map StaticBody3D: knocked-out enemies, officers, mission sets, bodies being freed). The table is baked in
   the vice art style; classic only removes the palms, so baked spots stay valid there.
8. **Existing tests**: the Phase B / Phase C "within 4 m of the explicit point" checks keep a real bound for the six lawn
   slots: the baked origin stays within its bake-time distance (+2 m) of the authored point.

## Interfaces

- `FreeRoam.cine_stage(stage) -> Variant`, `cine_stage_search(stage, budget_ms) -> Variant`, `cine_stage_ok`,
  `cine_stage_info`, `cine_search_tries`, `prepare_cinematic(tl, opts) -> bool`, `drop_cinematic_prep()`, `cine_prep`,
  `play_cinematic(tl, opts)` (opts: "fade", "on_black").
- `CineStage.signature / baked / requests`, `CineStageBake.TABLE`.
- `CineActor.clone_key(opts)`, `CineActor.setup(opts, template = null)`.
- `CinePrep.new(tl, opts_xf, xf, info)`, `matches(tl, opts)`.
- `CinePlayer.wants_preroll`, `preroll(tl, fade_s, under_black, go)`, `prerolling`, `pre_built`, `adopted`, `clones`;
  `setup` opt "actors".
- `StoryRoam.stage_cinematic`, `upcoming_cinematic`.

## Tests: `tests/test_cine_transition.gd`

- Every stage request resolves from the baked table (no search, `cine_search_tries == 0`), and the static check passes.
- The baked table matches a full search for every request (prints the replacement table and fails when the map changed).
- Headless sees multimesh clutter (the canteen box is cluttered by the campus grass).
- A budgeted search stops within its budget and still returns a transform, and is not cached; a full answer is cached.
- A knocked-out body and a mission wall in a baked box do not reject it.
- Clone cache: a cloned actor equals a fresh build (nodes, meshes, transforms, metas remapped inside its own body, poses
  after the same cues); unseeded opts are never cloned.
- Prepare ahead builds no actor; play takes the prepared stage only with matching slot, stage and opts "xf".
- Fade ordering: during the fade nothing is built and the world is still shown; under black at most one actor per frame,
  then the setup adopts them all; the 2D card never shows during the preroll, from its first frame.
- Hard cuts: a scare timeline and a fade_in 0 timeline set up at once with no black layer.
- The F9 dev path still plays (with a silent test stream).

Then check-only, smoke, the cine_* tests, test_story_cines, test_story_day0-5, test_story_director, test_chapter_select,
test_busted, test_story_stages. Windowed probe before and after per Day 4 slot plus cine_d1_intro and seg_d2_boss.
