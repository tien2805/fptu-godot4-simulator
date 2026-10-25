# Story Phase B "Ngày 1 và Ngày 4": Integration Plan

Spec: `docs/superpowers/specs/2026-10-25-story-phase-b-days-1-4-design.md`, scope **B-D5, B-D6, B-D7**, the wiring parts of
B-D8 and the Day 1 / Day 4 tests of B-D12. Branch `phase-b` (main + `phase-b-combat`, `phase-b-horror`, `phase-b-cine`).
APIs used: `MeleeFight` header, `NightBuilding` header, the cine plan's API section (`StoryCast`, `StoryChoice`,
`CinePlayer.choice_made`, slots, `CineTimeline.canteen_stage`).

**Goal.** Days 1 and 4 playable from the Day 1 morning through the Day 5 placeholder, Days 2 and 3 sleepable
placeholders, every beat with fail / retry and an autosave, Continue resuming at every step.

**Architecture.**
- `StoryMissions` stays data. New beat kinds: `mission` (a roam mission node, field `mission`), `fight` (MeleeFight, field
  `fight`), `horror` (the Night Building scene). Optional beat fields: `anchor` on a `cine` beat (the cinematic waits for
  [E] at a marker), `intro` on mission / fight beats (played once on [E], as A2-D17), `auto` (starts right after the
  previous beat when it was entered live; otherwise a marker at `anchor`), `after` (cinematic played when the mission or
  fight is won), `slot_by_choice` (branch tail), `side` (optional side markers: E2 locker), `replay` (short replay slot).
- `StoryDirector` gains the old-save migration (`d1_locked`..`d4_locked` saved by A2 resume at that day's first beat),
  `launch_horror_beat` / `on_horror_result` (E5 only with `caught_count == 0`), the `horror:` navigation and
  `grant_side(id)` (side-marker evidence + flag, once).
- `StoryRoam` runs the new kinds: one mission node at a time (`mission_node`), the fail overlay `StoryFail` ("TOANG!" /
  "BỊ LỘ", THỬ LẠI = retry from the beat checkpoint, VỀ THẾ GIỚI MỞ = abort, the marker comes back), side markers, marker
  cinematics and choice tails. Markers stay blocked while wanted, with the phone or the map open, and while busy.
- Roam missions live in `scripts/story/missions/`, all on the base `StoryMission` (Node): `setup(roam, beat, opts)`,
  `begin()`, `retry()`, `abort()`, signals `done(info)` / `failed(title, reason)`, a small mission HUD (timer / meter /
  prompt), weapons forced unarmed, fade-teleport to the start spot, no per-frame allocation, checks at 10 Hz where possible.
- The Night Building runs as its own scene `scenes/story/StoryNightEscape.tscn` (it must sit at the world origin, the
  FreeRoam city does not): the root `StoryNightEscape` instantiates `NightBuilding`, records the player and the stalkers,
  plays `seg_d4_escape` on `escaped`, then reports to `StoryDirector.on_horror_result` and returns to story free roam.

**Canteen approach (B-D7).** A story scene built from Stage 5, staged in FreeRoam in front of the canteen
(`CineTimeline.canteen_stage`, the box `seg_d4_brawl` uses), not a story mode inside `Stage5_Canteen`. Reasons: the same
third-person player, camera and combat as the brawl that follows (no scene change between undercover, `cine_d4_stare`,
the clone waves and `seg_d4_brawl`, which all share that stage); Stage 5's fixed camera, modal HUD, tilt-balance tray and
7-Eleven phase would each need a story branch in a 1000-line stage; checkpoint and retry stay in one runner. It keeps
Stage 5's tray rule (carry it calmly, running drops it) with the cine props (tables, trays, counter).

**Global constraints.** Pure GDScript, Godot 4.7.2, CPUParticles3D only; Vietnamese plain text, no emoji or decorative
symbols (key glyphs only in hints); fictional names; the protagonist as `{name}` / "em" / "mày"; no gore; owner files only
in `user://`; FreeRoam changes minimal; never stage `.import`.

---

## Task 1 – Beat table, director, migration

Files: `scripts/story/StoryMissions.gd`, `scripts/story/StoryDirector.gd`, `tests/test_story_director.gd`.

- Day 1: `d1_morning` → `d1_stakeout` (mission, marker at the main gate, intro `cine_d1_intro`, night) → `d1_chase`
  (mission, auto, replay `seg_d1_chase`) → `d1_brawl` (fight `d1`, auto, after `seg_d1_brawl`, flag `d1_key`) →
  `d1_corridor` (mission, marker in the courtyard, after `cine_d1_corridor`) → `d1_choice` (cine with a marker at the
  bench, side marker E2) → `d1_choice_tail` (slot by `choices.phuc`) → `d1_end` (`cine_d1`) → `d1_bed` → `d1_call` (N = 6).
- Days 2, 3: `dN_start` → `dN_morning` (`cine_day_start`) → `dN_wait` (bed, objective "Ngày N: <title> – sắp có trong bản
  cập nhật sau. Về BE6 ngủ để sang ngày tiếp.") → `dN_call` (N = 5, 4). No evidence, no choice.
- Day 4: `d4_start` → `d4_morning` → `d4_canteen` (mission, marker at the canteen, intro `cine_d4_intro`, noon) →
  `d4_stare` (`cine_d4_stare`, villain card inside) → `d4_brawl` (fight `d4`, auto, after `seg_d4_brawl`) → `d4_escape`
  (horror, marker at the lobby, night, replay `seg_d4_escape`) → `d4_end` (`cine_d4`) → `d4_bed` → `d4_call` (N = 3) →
  `d5_start` → `d5_morning` → `d5_locked`.
- `StoryMissions.migrate(id)`; `from_dict` applies it. `StoryDirector.grant_side`, `launch_horror_beat`,
  `on_horror_result`.
Tests: every beat valid per kind; chain d0 → d5_locked; old `d1_locked` save resumes at `d1_stakeout`; `on_horror_result`
grants E5 only on 0 catches; side grant once.

## Task 2 – StoryRoam runner, fail overlay, side markers

Files: `scripts/story/StoryRoam.gd`, `scripts/story/StoryFail.gd` (new), `scripts/story/missions/StoryMission.gd` (new).

- New anchors (campus plot → map): `campus_gate`, `parking`, `chase_start`, `west_gate`, `corridor`, `locker`, `bench`,
  `canteen`, `lobby`.
- `start_mission(b)`, `_on_mission_done`, `_on_mission_failed` → `StoryFail.show(title, reason)`, `retry_mission()`,
  `abort_mission()`; `after` cinematic then `complete_step`; `auto` start only when the step was entered live.
- Choice tail picks its slot from `StoryDirector.choices`; a choice beat whose choice is already recorded skips straight
  to the tail (recorded once).
- Horror beats: [E] → `StoryDirector.launch_horror_beat(id, win_xf, fail_xf)`.
Tests: covered by Tasks 4-5.

## Task 3 – Missions

Files: `scripts/story/missions/MissionStakeout.gd`, `MissionChase.gd`, `MissionFight.gd`, `MissionCorridor.gd`,
`MissionCanteen.gd`; `scripts/story/StoryNightEscape.gd`, `scenes/story/StoryNightEscape.tscn`.

- Stake-out (parking lane, `parking_center_local`): 2 guards patrol, the courier and a buyer wait; 60 s; sight cones
  (70°, 12 m, a clear ray) on all three; seen = "Bị phát hiện!", restart; handover window 34-48 s, [E] (consumed; S walks back) with the courier in
  frame and within 20 m takes the photo; the run ends at 60 s (fail "TOANG!" without the photo).
- Chase: Mũ Đỏ runs a 230 m path (parking lane → west lane → west gate), rubber-band speed 3.6-5.6 m/s, pauses to taunt
  when far; 25 m leash with a 2.5 s grace (fail "TOANG!"); banana slip at 55 % (`slide_whistle`, mark "blow"); the run
  lasts 60-90 s; then the `seg_d1_chase` replay (recorder on the player and the courier).
- Fight: MeleeFight (`d1`: Mũ Đỏ, Mũ Xanh, Mũ Vàng, "Gét gô!"; `d4`: 4 masked clones, then 3 clones + Dolly who flees at
  30 %), forced unarmed; `lost` → "TOANG!" → `fight.retry()`.
- Corridor: a code-built night corridor (CineFX corridor set + collision) at the courtyard spot; walk capped, 30-60 s;
  ScareDirector flicker, a masked figure at the end, lights out / on / gone, distorted bleat; ends at the far end.
- Canteen: 3 tables, 12 identical clones, the real Dolly (`dolly_disguised`) with the music-box hum, cuff and keychain;
  tray carried; sprint drops it (suspicion +, tray counter to pick a new one); [E] accuses the nearest clone; wrong +35;
  100 = "BỊ LỘ"; "Mlem mlem" bubbles.
- Night escape scene: NightBuilding setup from the story, recorder, `seg_d4_escape`, `on_horror_result`.

## Task 4 – Tests Day 1 / Day 4, Day 0 update

Files: `tests/test_story_day1.gd`, `tests/test_story_day4.gd`, `tests/test_story_day0.gd`.

Day 1: marker → intro → stake-out seen (restart) → photo → done; chase leash fail → retry → slip → replay; brawl lost →
retry → won → `seg_d1_brawl`; corridor → `cine_d1_corridor`; E2 locker taken (and skipped in a second run); choice
timeout (honest "cover") → cover tail; choice already set skips the scene; `cine_d1`, bed, call N = 6, Day 2 placeholder,
Continue mid-day restores the step and its marker. Day 4: placeholders 2-3 slept through, canteen wrong accusation,
tray drop, "BỊ LỘ" retry, correct accusation, stare, waves + Dolly flees, horror scene escaped with 0 catches (E5) and
with catches (no E5), `cine_d4`, call N = 3, Day 5 placeholder, Continue mid-day.

## Task 5 – Docs and regression

README (Days 1 and 4, controls), PLAN.md (Phase B section with perf numbers), spec Status line. Full regression with
`w_regress.sh`, then `test_mayhem_perf`, `test_combat_perf`, `test_horror_perf` on AC power.
