# Story Phase B "Cine": cinematics, overlays and new characters – Implementation Plan

Spec: `docs/superpowers/specs/2026-10-25-story-phase-b-days-1-4-design.md`, scope B-D8, B-D9, B-D10 and the
`test_story_cines` part of B-D12. Branch `phase-b-cine` (worktree), base main 91a6c53.

**Goal.** Deliver everything the Day 1 / Day 4 beats need on screen, ready for the integration agent: the cast helper,
the shiba, the choice and villain-card overlays, a screen card, and ten timelines (eight slots plus two choice tails), all
validator clean with committed beat sheets and headless tests.

**Out of scope (parallel agents / integration).** `StoryMissions.gd`, `StoryRoam.gd`, `scripts/combat/`, `scripts/horror/`,
weapons. Nothing here wires a beat; the integration agent reads the API section below.

**Global constraints.** Pure GDScript, Godot 4.7.2, CPUParticles3D only, code-drawn props and cards, Vietnamese text,
fictional names only, protagonist only as `{name}` / "em" / "mày", no emoji or decorative symbols in UI text, labels never
autowrap into one letter per line, subtitles >= 0.06 s per character, no actor hidden behind another in a shot, owner music
stays in `user://music` (never committed), stage files explicitly, never `.import`, commit trailer
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

## Task 1 – Cast: StoryCast, StoryShiba, new props

Files: create `scripts/story/StoryCast.gd`, `scripts/story/StoryShiba.gd`; modify `scripts/cine/CineFX.gd` (prop kinds),
`scripts/cine/CinePlayer.gd` (animated props).

- `StoryCast` (static): `IDS`, `opts(id, extra = {}) -> Dictionary` (CharacterBuilder opts, rigged), `speaker(id)`,
  `color(id)`, `masked(id)`, `build(id, extra = {}) -> Node3D` (gameplay body: rigged, animated; masks and Dolly's tells
  attached on the Head / Wrist / Hips bones; `shiba` returns a `StoryShiba`), `attach_mask(body)`, `attach_tells(body)`.
- Ids: `hero` (protagonist opts), `mr_t`, `phuc` (as in A2), `linh` (student_f, ponytail, glasses, crisp navy shirt),
  `chu_bay` (guard preset with its cap), `dolly` (clone face + cream wool cardigan + sheep mask), `dolly_unmasked`,
  `dolly_disguised` (clone look + cream cuff + sheep keychain), `clone` (one identical student look), `clone_masked`,
  `courier_vang`, `courier_do`, `courier_xanh` (seg_d1_brawl looks), `shiba`.
- `StoryShiba` (Node3D, low-poly boxes and spheres): `pose(motion, t)` pure (idle, walk, bonk; `BONK_HIT`), `play(motion)`
  plus `_process` for gameplay, `cine_eval(s, opts)` for timelines (opts `anim`: `[[s, motion], ...]`).
- New CineFX prop kinds: `shiba`, `table`, `stool`, `tray`, `soup_pot`, `laptop`, `flyer` (stand with a code-drawn
  "THI HỘ BAO ĐẬU" sign), `corridor` (two walls, ceiling, four tube lamps that flicker like `lamp`), `chair`, `counter`.
  Breakable props carry the `crates` metas so `crate_break` works on them.
- CinePlayer calls `cine_eval(s, opts)` on props that have it (seekable).

Test: `tests/test_story_cines.gd` builds every cast id (rigged, the mask / tells present, clones identical) and the shiba
poses (bonk lunges forward at `BONK_HIT`).

## Task 2 – Overlays and the timeline hooks

Files: create `scripts/story/StoryChoice.gd`, `scripts/story/StoryVillainCard.gd`, `scripts/story/StoryScreenCard.gd`;
modify `CineTimeline.gd`, `CineClock.gd`, `CinePlayer.gd`, `CineShots.gd`, `CineAudio.gd` (new SFX).

- `StoryChoice` (CanvasLayer 120, PROCESS_MODE_ALWAYS): `StoryChoice.open(parent, def)` pauses the tree (restores the old
  pause state on close), dims, shows the prompt, two option buttons and a 10 s countdown bar; mouse, 1 / 2, Left / Right
  with Enter or Space; on timeout the `honest` option is taken and the comic `timeout_line` shows for 1.6 s. Signal
  `chosen(key, timed_out)`; `result`, `timed_out`; `pick(key)`, `step(dt)` when `manual`. `record` (default true) writes
  `StoryDirector.choices[id]`.
- `StoryVillainCard` (CanvasLayer 112): colour wash, name, nickname, joke; an optional drawn pointer that first points at
  `point_wrong` (screen fraction) with `wrong_line`, then moves to `point_right`. `state_at(u)` pure; `update(r)` inside
  its real window; `StoryVillainCard.show_for(parent, data, dur)` for gameplay (pauses the tree, frees itself).
- `StoryScreenCard` (CanvasLayer 106): code-drawn `cctv` frame (timestamp, REC dot, scanlines, a courier handing a box
  over) and `phone` notification (sender, message, time); `update(r)` inside its window.
- DSL: `card(kind, r, dur, data)` (kinds `villain`, `screen`), `villain(name, r, dur, data)` (a `card` clock ramp: pure
  freeze for `dur` real seconds plus the villain card), `choice(r, def)` (one per timeline).
- `CineClock` preset `card`: freeze 1.0–4.0 s, no speed ramp, no strike cue; whip / FOV / shake off for it.
- `CinePlayer`: builds the card layers and updates them on real time; at the choice time it holds `r`, pauses the music,
  opens `StoryChoice` (manual when the player is manual: `step(dt)` forwards), emits `choice_made(id, key, timed_out)`,
  then plays on. A skip before the choice still asks it (over the fade) before `finished`.
- SFX bank additions: `burp`, `tray_clang`, `pot_clonk`, `chair_smash`, `fluoro_buzz`.

Test: overlays build and free, no one-letter labels (minimum widths), choice keyboard pick, timeout takes the honest
option and records it, villain card state and layout width, the clock `card` preset validates.

## Task 3 – Day 1 timelines

Files: `scripts/cine/timelines/cine_d1_intro.gd` (14 s), `cine_d1_corridor.gd` (7.5 s, reduce-scares variant),
`cine_d1_choice.gd` (12 s, choice at 10.6 s), `cine_d1_choice_cover.gd` (4 s), `cine_d1_choice_report.gd` (4.5 s),
`cine_d1.gd` (18 s); beat sheets `docs/cinematics/<slot>.txt`.

Staging: explicit `at` computed from the campus plot (`CineTimeline.campus_at`), landmark fallback. Intro at the main gate,
corridor set dressing carried as a prop, choice and `cine_d1` at the west gate road edge (the brawl's place).

## Task 4 – Day 4 timelines

Files: `cine_d4_intro.gd` (14 s), `cine_d4_stare.gd` (10 s, villain card 4.6–7.0), `cine_d4.gd` (18 s); beat sheets.
Staging at the canteen (`FPTUCampusBuilder.canteen_center`), props for tables, stools, trays, counter and flyer.

## Task 5 – seg_d4_brawl and its test

Files: `scripts/cine/timelines/seg_d4_brawl.gd` (25.000 s), `docs/cinematics/seg_d4_brawl.txt`, `tests/test_cine_d4_brawl.gd`.

- Cast: hero, Dolly (masked, cardigan), three masked clones. Improvised weapons: a tray, a chair, the soup pot.
- Ramps: H1 medium 2.6 (tray), H2 heavy 5.9 (chair), H3 light 8.4 (shove into a table), H4 medium 11.2 (soup pot), A1
  accent 13.6 (dodges Dolly), H5 finisher 15.0 with the long swell to 22.000 (tray hook launches the pot-headed clone into
  the drink crates), 3.000 s tail; the hero takes three hits at normal speed with punch-ins. Dolly escapes in the tail.
- Test (modelled on `test_cine_d1_brawl`): valid, exactly 25 s, ramps on their real times, 1500 steps, actors in the box,
  surface gaps at every impact (Mixamo <= 0.04 m when present, fallbacks <= 0.15 m), penetration limits, lying bodies on
  the floor, hips skate, beat sheet in sync, and `cine_stage` finds a spot in FreeRoam for every Phase B slot.

## Task 6 – test_story_cines coverage and regression

Extend `tests/test_story_cines.gd`: every new slot registered, exact length, validator clean, subtitles >= 0.06 s per
character, `{name}` formatted, no gendered pronoun, beat sheets in sync, plays to its end, overlays build and free, choice
timeout default, villain card width, corridor reduce-scares variant. Run: the new tests, `--check-only`,
`tests/smoke_all_stages.gd`, the existing cine tests.

---

## API for the integration agent (as built)

Details live in the header comments of `StoryCast.gd`, `StoryShiba.gd`, `StoryChoice.gd`, `StoryVillainCard.gd`,
`StoryScreenCard.gd` and each timeline.

- **Cast.** `StoryCast.opts(id, extra)`, `StoryCast.build(id, extra)`, `speaker(id)`, `color(id)`, `masked(id)`,
  `attach_mask(body)`, `attach_tells(body, keychain)`. Ids: `hero`, `mr_t`, `phuc`, `linh`, `chu_bay`, `clone`,
  `clone_masked`, `dolly_disguised`, `dolly_unmasked`, `dolly`, `courier_vang`, `courier_do`, `courier_xanh`, `shiba`.
- **Shiba.** `StoryShiba.new()`; `play("idle" | "walk" | "bonk")`; `BONK_HIT` 0.32 s, `BONK_DUR` 0.75 s; `nose_world()`.
- **Choice.** `StoryChoice.open(parent, def)` → signal `chosen(key, timed_out)`; writes `StoryDirector.choices[id]`.
  Inside a timeline: `choice(r, def)`; `CinePlayer.choice_made(id, key, timed_out)` fires before `finished`.
- **Villain card.** In a timeline: `villain(name, r, dur, data)` (freeze + card). In gameplay:
  `StoryVillainCard.show_for(parent, data, dur)` → signal `finished`.
- **Screen card.** In a timeline: `card("screen", r, dur, {"kind": "cctv" | "phone", ...})`.
- **Slots** (real length): `cine_d1_intro` 14.0, `cine_d1_corridor` 7.5 (reads "Giảm hù dọa" at build time),
  `cine_d1_choice` 12.0 (choice at 11.6), tails `cine_d1_choice_cover` 4.0 / `cine_d1_choice_report` 4.5, `cine_d1` 18.0,
  `cine_d4_intro` 14.0, `cine_d4_stare` 10.0 (villain card 4.6–7.0), `seg_d4_brawl` 25.0, `cine_d4` 18.0.
- **Staging.** Every slot carries an explicit `stage.at` (map point from the campus plot) and a landmark fallback;
  StoryRoam may still override `at` / `yaw_deg` from its anchors as for Day 0.
