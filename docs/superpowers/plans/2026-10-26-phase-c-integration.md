# Story Phase C "Ngày 2, 3 và 5": Integration Plan

Spec: `docs/superpowers/specs/2026-10-26-story-phase-c-days-2-3-5-design.md`, scope **C-D5 to C-D8**, the wiring parts of
C-D9 and C-D11 and the story tests of C-D13. Branch `phase-c` (main + `phase-c-bike`, `phase-c-guns`, `phase-c-swords`,
`phase-c-cine`). APIs used: the headers of `BikeChase`, `GunFight`, `ForkliftBoss`, `SwordDuel`, `MeleeFight`
(`soi_xam`), `StoryCast`, `StoryVillainCard.show_for`, `CineTimeline.PHASE_C_STAGES`, the cine plan's API section.
Pattern: the Phase B integration (`2026-10-25-phase-b-integration.md`).

**Goal.** Days 2, 3 and 5 playable from the Day 2 morning to the Day 6 placeholder (or to ending C and the main menu),
every beat with fail / retry and an autosave, Continue and Chọn cảnh restoring every step.

## Level choices (C-D5)

| Level | Where | Why |
|---|---|---|
| Rạch Hầm bridge (Day 2) | FreeRoam, the real bridge. The chase runs Nguyễn Xiển **southbound** on the reversed default route (`BikeRoute.nguyen_xien` reversed: Nguyễn Văn Tăng, the turn onto Nguyễn Xiển, the bridge at about 1724 m), from `bridge_s - 850` to `end_at_s = bridge_s + 30`, so it ends just past the bridge. The horror beat, the duel and E3 use the bank beside the deck, the measured cine stage `bridge` (2145, 150), whose 14 x 10 box is clear. | Northbound, the bridge is only 376 m from the route start, so a chase that ends at the bridge would last 25 s. Southbound gives about 850 m of real road (60-70 s) and ends at the duel. No scene switch: StoryRoam stays in charge, and `seg_d2_boss` and `cine_d2` play at their measured stage. `clear_downed()` and `stop()` run behind the fade into the horror beat. |
| Container yard (Day 3) | FreeRoam, a code-built `LairYard` (50 x 40 m, yaw 0) centred at (2183, 167) on the free waterfront plot south of the canal, east of the bridge. A probe found a clear, flat 50 x 40 box there (ring 8 around the cine point). It is built by StoryRoam while a Day 3 yard beat (`"lair": "yard"`) is current, and freed after. | The spec prefers FreeRoam. The cinematics are measured at the `yard` stage (2180, 160), which lies inside this plot. Bridge and yard sit on the same real canal. The crowd is hidden while a yard mission runs (an industrial yard at night); the traffic stays on the roads outside. The cine pad (the stage box) keeps the discovery stack. That stack is built from the same CinePropsC containers as `cine_d3_mannequins`, hidden while a yard cinematic plays and shown open with the mannequins after it. Yard cinematics get `xf` = the pad (no stage drift onto the yard's own boxes). |
| Server basement (Day 5) | Its own scene `scenes/story/StoryBasement.tscn`: a code-built `LairBasement` at the origin. The **server room** is the cinematics' carried room (13 x 9.3 m, racks along the sides, the 50-monitor wall, a red emergency light) built from the same CinePropsC kinds. A **server hall** (24 x 30 m) in front of it holds rack rows (occluders), low cabinets (cover), the entry stairs and red lights. The terminal desk stands in the room, the fires come after the hack, and the duel area is the room plus the front of the hall. | The spec asks for an interior scene like the Night Building. Every Day 5 cinematic plays with `xf` = the room frame and `drop_set`, so the real room replaces the carried one. Its own player stack (controller, WeaponDirector, PlayerCombat) is duck-typed like FreeRoam, so the same mission classes run in both places. Perf is bounded (no city). |

## Architecture

- **Beat data** (`StoryMissions`):
  - New kind `lair`: a task inside a dedicated scene, with fields `lair: "basement"` and `task: stealth | gunfight | hack | duel`.
  - Cine beats inside the basement also carry `lair: "basement"`; yard beats carry `lair: "yard"`.
  - New missions: `bike_chase`, `bridge`, `sneak`, `gunfight`, `crates`, `forklift`.
  - New fight: `d2` (Sói Xám, `soi_xam`).
  - New beat fields: `next_by_choice` (`{id, key: beat}`), `ending` (`"C"`), `after_at` (anchor of an "after" cinematic), and `flag_by_info` (a mission result key copied into a flag: `d3_all_crates`).
  - Migration: `d2_wait`/`d2_locked` → `d2_chase`, `d3_wait`/`d3_locked` → `d3_sneak`, `d5_locked` → `d5_stealth`.
  - Day 6 ends on `d6_locked` after `d6_morning`.
- **StoryDirector**:
  - `complete_step` follows `next_by_choice`.
  - `launch_lair_beat(id, fail_xf)` (story_context `lair`, nav `lair:<scene>`, saved like the horror beat).
  - `leave_lair()` (back to story free roam at the marker's return spot).
  - `finish_story(ending)`: the save is marked `ending = "C"`, the story stops, the main menu. Continue refuses a finished save and the menu hides TIẾP TỤC; Chọn cảnh still rewinds.
- **StoryRoam**:
  - New anchors: `duy_corner` (BE6 lobby), `bridge_road`, `bridge_bank`, `bridge_pillar`, `bridge_ledger`, `yard_gate`, `yard_pad`, `yard_mid`, `yard_manifest`, `basement_door`.
  - New mission scripts and music slots (per mission, per fight, per lair task).
  - The yard's lifetime.
  - Basement beats: a marker at `basement_door`, then [E] (intro once) launches the scene.
  - `after_at` / `xf` for yard cinematics, `flag_by_info`, and `ending` (after the cinematic: `finish_story`).
  - Markers stay blocked while wanted, with the phone or the map open, and while busy, as in Phase B.
- **Missions** (all on `StoryMission`; `armed = true` lets the lair missions skip the unarmed lock):
  - `MissionBikeChase` (BikeChase, the reversed route, Day 2 waves, Bầy Sói bodies, "TOANG!" on `lost` → `retry()`, `stop()` + free on the win, the `seg_d2_chase` replay inside BikeChase).
  - `MissionBridge`: the horror beat. Fog, a wolf howl, LED eyes in the dark (Sói Xám and pack eyes), then his synth ringtone, then the villain card. "Giảm hù dọa" gives no sting, a softer howl and slow eyes.
  - `MissionFight` `d2` (MeleeFight, one `soi_xam`, the glow on).
  - `MissionLairFight` (GunFight wrapper: a recorder from the last wave, mark on the last KO, the short replay, Anh Duy radio lines with a "Dịch:" line, the crowd hidden in FreeRoam). It has these subclasses:
    - `MissionSneak` / basement stealth: patrol guards with the horror sight (14 m, 70 deg); reach the goal unseen. `spotted` starts the fight early, and the beat ends at the goal once the patrol is down.
    - `MissionGunfight`: 2 waves and a replay (`seg_d3_gunfight` / `seg_d5_gunfight`).
    - `MissionCrates`: the yard's smart-glasses crates as GunFight targets, plus the coffin-dance carriers with `meme_coffin_dance` while their crate is whole. Alexander arrives in 90 s; all crates down plays `seg_d3_crates` and sets the flag for E4.
    - `MissionForklift`: the ForkliftBoss wave with Alexander's body and ammo pickups.
  - `MissionHack`: the typing battle (`StoryHack`, a story mode of the Stage 6 engine through the shared `TypingCore`; the error words become Lọ Thần processes; the final command; `seg_d5_hack` replay).
  - `MissionDuel`: SwordDuel, the Za Mẫn card (`show_for`) before the first start.
- **Shared, surgical:**
  - `GunFight`: wave entry `{"target": node}` (an external duck-typed enemy: never freed, `reset()` at each wave start).
  - `Gunman`: opts `sight_m` / `fov_deg`.
  - `Stage6_CapstoneBoss`: prefix lookup, combo multiplier and damage through `TypingCore`.
  - `MusicDirector`: the new slots and replays.
  - `MainMenu`: hides TIẾP TỤC for a finished save.
  - `StoryChapters`: `lair` replayable, Phase C gallery rows.

## Beats

- **Day 2:**
  - `d2_morning` (Anh Duy's text);
  - `d2_chase`: mission `bike_chase`, marker `duy_corner`, intro `cine_d2_intro`, replay `seg_d2_chase`;
  - `d2_bridge`: mission `bridge`, auto;
  - `d2_duel`: fight `d2`, auto, after `seg_d2_boss`;
  - `d2_end`: `cine_d2`, a marker at `bridge_pillar`, side E3 at `bridge_ledger`;
  - `d2_bed` (side E3), then `d2_call` (N = 5).
- **Day 3:**
  - `d3_morning`;
  - `d3_sneak`: marker `yard_gate`, intro `cine_d3_intro`;
  - `d3_mannequins`: cine, `yard_pad`;
  - `d3_gunfight`: auto, replay `seg_d3_gunfight`;
  - `d3_crates`: auto, replay `seg_d3_crates`, flag `d3_all_crates`;
  - `d3_boss`: mission `forklift`, marker `yard_mid`, side E4 (needs `d3_all_crates`), after `seg_d3_boss` at `yard_pad`;
  - `d3_end`: `cine_d3`, `yard_pad`;
  - `d3_bed` (side E4), then `d3_call` (N = 4), then Day 4 as built.
- **Day 5:**
  - `d5_morning`;
  - `d5_stealth`: lair, marker `basement_door`, intro `cine_d5_intro`;
  - `d5_monitors`: cine;
  - `d5_gunfight`: lair, replay `seg_d5_gunfight`;
  - `d5_hack`: lair, replay `seg_d5_hack`;
  - `d5_choice`: `cine_d5_choice`, choice `zaman_offer`;
  - `d5_choice_tail`: `slot_by_choice` accept / refuse, `next_by_choice`. Accept goes to `d5_end_c` (`end_c` in free roam, `ending` C: finished save, then the main menu). Refuse goes to `d5_duel` (lair, after `seg_d5_boss`, E6 guaranteed);
  - `d5_end`: `cine_d5`;
  - `d5_bed`, then `d5_call` (N = 2), then `d6_morning`, then `d6_locked`.
- **Memes:** "Tới công chuyện luôn!" at the chase start and "Đỉnh nóc kịch trần bay phấp phới" on its win (BikeChase lines).
- **Anh Duy:** radio lines with "Dịch:" in the lair missions and the morning texts.

## Tests

- `test_story_day2`:
  - morning, marker, intro, the chase (scripted crashes, a `lost` → retry, the replay), the bridge horror (eyes, ringtone, card), the duel (`lost` → retry, KO → `seg_d2_boss`);
  - E3 taken in one run and skipped in the other, `cine_d2`, bed, call N = 5;
  - Continue at `d2_duel` and `d2_end`, Chọn cảnh snapshots of the new beats.
- `test_story_day3`:
  - sneak spotted (fight early) and unseen, `cine_d3_mannequins`, gunfight (lost → retry, replay);
  - crates (coffin dance, all broken → replay → E4 offered; timeout → no E4), forklift (lost → retry, topple → `seg_d3_boss`), `cine_d3`;
  - call N = 4, Continue at `d3_crates`.
- `test_story_day5`:
  - the basement scene: stealth, `cine_d5_monitors`, gunfight + replay, the hack (a typo, a leak, a retry, the final command, the replay);
  - choice timeout → refuse → card → duel (lost → retry, won → `seg_d5_boss`) → E6, `cine_d5`, bed, call N = 2, the Day 6 placeholder;
  - accept → `end_c` → finished save → main menu nav; Continue refused, rewind from a snapshot works;
  - Continue mid-day (marker at the basement door, the scene resumes at the step).
- Extend `test_story_director` (the chain to `d6_locked`, migration, `next_by_choice`, `finish_story`), `test_chapter_select` (lair beats replayable and snapshotted, the gallery rows), `test_story_day1` / `test_story_day4` (Days 2-3 no longer placeholders).
- `test_lair_perf`: the Day 3 gunfight in the real yard in FreeRoam (crowd and traffic on) and the basement gunfight, each < 3 ms per physics frame (median and 5 %-trimmed mean, the `test_combat_perf` method).

## Tasks

1. Plan (this file). Commit.
2. Data, director, chapters, music slots, the shared edits (GunFight target entries, Gunman sight, TypingCore + Stage 6).
3. Levels: `LairYard`, `LairBasement`, `StoryBasement` scene.
4. StoryRoam wiring and the missions.
5. Tests above; update the old story tests.
6. Docs (README, PLAN.md Phase C with perf, spec Status); full regression with `w_regress.sh` into `scratchpad/c_logs`, perf gates on AC power.
