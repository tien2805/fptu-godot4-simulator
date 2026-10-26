# Story Phase C "Cine": cinematics and characters – Implementation Plan

Spec: `docs/superpowers/specs/2026-10-26-story-phase-c-days-2-3-5-design.md`, scope C-D9, C-D10, C-D11 and the cinematic
tests of C-D13. Branch `phase-c-cine` (worktree), base main 291b403.

**Goal.** Everything Days 2, 3 and 5 need on screen, ready for the integration agent: the new cast, the props, 16 timelines
(intros, discovery beats with v2 jump scares, the choice scene and its two tails, end cinematics, ending C, three 25 s
fights), villain cards, music slots, beat sheets and headless tests.

**Out of scope (parallel agents / integration).** `StoryMissions.gd`, `StoryRoam.gd`, `StoryDirector.gd`,
`scripts/combat/` (bike, guns, swords; the gameplay forklift `scripts/combat/guns/Forklift.gd`), the lair scenes. Nothing
here wires a beat. The day-start texts (`cine_day_start` reads them from StoryMissions) are the integration's.

**Global constraints.** Project rules (`agent_rules.md`): pure GDScript, code-built props only, CPUParticles3D, no code
music (every slot = the owner's file, none = silence), Vietnamese text with fictional names, protagonist only as `{name}` /
"mày" / "em", no emoji or decorative symbols, "..." not the ellipsis glyph in new text, no gore, "Giảm hù dọa" softens every
scare. Phase B lessons: surface-gap contacts, no actor hidden behind another, subtitles >= 0.06 s per character, no walking
backwards (keys face the travel direction), held props with `hold_up`, `drop_set` for carried set dressing, explicit
measured `at` (no staging drift).

---

## Task 1 – Props and poses

Files: `scripts/cine/CineFX.gd`, `scripts/cine/CinePlayer.gd`, `scripts/cine/CineMoves.gd`, new `scripts/cine/CineCrowd.gd`,
new `scripts/cine/CineScreens.gd`.

- Wearables (held on bones in cinematics, attached to pivots in gameplay): `wolf_helmet` (grey wolf head, emissive LED
  eyes, opts `led`), `wolf_mask`, `fox_mask`, `gold_shades`, `round_glasses`, `headphones`, `key_lanyard`, `turtleneck`
  (collar roll), `hawaii_print` (flower patches), `belly`, `man_bun`.
- Hand props: `energy_drink`, `cigar_vape`, `coffee_cup`, `party_horn`, `usb`, `katana` (opts `bend`, `broken`),
  `katana_blade`, `keyboard`, `server_panel`, `staff`, `bike_mirror`, `chain`, `small_crate`, `pallet` (breakable), `rope`.
- Sets (`"set": true` where they double a real place): `bridge` (deck slab + pillars, a chain on one), `pillar`,
  `motorbike` (Sói Xám's tuned bike), `container` (door opens via `open_at`), `forklift` (cine prop: mast, forks, pallet,
  opts `tilt` path), `server_rack` (breakable, blinking LEDs), `desk`, `laptop_trio` handled with three `laptop` props,
  `monitor_wall` (CineScreens: 50 screens, the laughing face texture, the freeze screen), `stonks_screen`, `fire` (flames
  as emissive quads animated in story time + an OmniLight), `keynote` (stage, podium, big screen "LỌ THẦN 10.0"),
  `mannequins` (CineCrowd: MultiMesh bodies, heads and smart glasses; heads turn at `turn_at`).
- CinePlayer: props with `anim` drive `cine_eval(s, opts)` on meta `anim_node` (as the shiba).
- Poses: `type_sit` (seated typing), `sip` (cup to the mouth and back), `blow` (horn at the mouth), `tied_sit` (sitting
  against a pillar, hands behind), `present` (keynote gesture), `bow_ceo` (a smug bow), `staff_guard` (two-handed guard).

## Task 2 – Cast

Files: `scripts/story/StoryCast.gd`.

- Ids: `soi_xam`, `bay_soi` (biker, seed per extra), `alexander`, `za_man`, `anh_duy`, `guard_sheep`, `guard_wolf`,
  `guard_fox`, `mannequins`.
- `opts(id)` (rigged body opts), `gear(id)` (`[[kind, bone, opts], ...]`: the wearables), `dress(tl, actor, id, s0, s1)`
  (adds the gear holds to a timeline), `build(id)` (gameplay body with the gear attached; `mannequins` returns a
  CineCrowd), `villain_data(id)` (StoryVillainCard data for `soi_xam`, `alexander`, `za_man`).

## Task 3 – Overlays

Files: `scripts/story/StoryVillainCard.gd`, `scripts/story/StoryScreenCard.gd`.

- Villain card: `name_run` (extra name text that runs off the band, then the whole name shrinks to fit: `name_scale_at(u)`
  pure), `name_cut` (the run stops mid-word).
- Screen card kind `credits` (title + rolling lines), kind `radio` (Anh Duy on the radio: a waveform box).

## Task 4 – Dialogue timelines

Files: `scripts/cine/timelines/<slot>.gd`, `docs/cinematics/<slot>.txt`.

| Slot | Length | Stage (measured `at`) | Notes |
|---|---|---|---|
| `cine_d2_intro` | 14.0 | BE6 lobby corner (3895, -424) | Anh Duy, three laptops, route trace, Dịch lines |
| `cine_d2` | 18.0 | Rạch Hầm east bank (2145, 150), carried bridge | Sói Xám tied to the pillar |
| `cine_d3_intro` | 14.0 | the road south of the bridge (2113.2, 110.87) | night ride, Anh Duy on the radio |
| `cine_d3_mannequins` | 10.0 | container yard (2180, 160) | creak, heads turn (scare_hit), "Surprise!", villain card with the running name |
| `cine_d3` | 18.0 | container yard | the name is cut off, USB "Za Mẫn Labs" |
| `cine_d5_intro` | 14.0 | BE6 lobby corner | USB decrypted, the server under the tower |
| `cine_d5_monitors` | 10.0 | server room (3930, -440), carried walls | the face on 50 monitors (scare_hit), freeze screen |
| `cine_d5_choice` | 14.0 | server room | fire, "Ổn mà, mọi thứ vẫn ổn", STONKS, choice 2 at 13.6 |
| `cine_d5_choice_accept` | 4.0 | server room | handshake, then `end_c` |
| `cine_d5_choice_refuse` | 5.0 | server room | "Không.", villain card Za Mẫn, then the duel |
| `cine_d5` | 18.0 | server room | the money flow points to "Trà Sữa Lọ" |
| `end_c` | 26.0 | campus courtyard (canteen_stage), carried keynote | CEO of "Lọ Thần 10.0", credits card |

Choice 2: id `za_man`, options `accept` "Nhận lời" / `refuse` "Từ chối", honest `refuse`, a comic timeout line.

## Task 5 – Fights

Files: `scripts/cine/timelines/seg_d2_boss.gd`, `seg_d3_boss.gd`, `seg_d5_boss.gd`, beat sheets, `tests/support/cine_fight.gd`
(shared checks), `tests/test_cine_d2_boss.gd`, `test_cine_d3_boss.gd`, `test_cine_d5_boss.gd`.

- Each 25.000 s: four slow-motion impacts, one accent, a finisher swell to real 22.000 with a 3.000 s tail; three hits the
  protagonist takes at normal speed with punch-ins; improvised props from the spec; the Mixamo tier first.
- Shared checks (as `test_cine_d4_brawl`): valid, exact length, ramps on their real times, beat sheet in sync, 1500 steps,
  actors in the box, surface gaps on every tier (Mixamo <= 0.04 m, fallbacks <= 0.15 m), lying bodies on the floor, hips
  skate, penetration, held props, FreeRoam stages every Phase C slot within 4 m of its point.

## Task 6 – Music doc (C-D11)

Files: `docs/cinematics/music_to_download.md` (a "Phase C" checklist: file prefix, track), `docs/cinematics/music_suggestions.md`.

## Task 7 – Tests and verification

Extend `tests/test_story_cines.gd`: every new slot (length, validator, subtitles, beat sheets, no hidden faces, scare_hit
events and their reduced variant, choice 2 timeout default, villain card widths and the running name, no emoji), the cast
(gear present, gameplay builds). Run the new tests, `--check-only`, `tests/smoke_all_stages.gd`, the existing cine tests.

---

## API for the integration agent (as built)

Filled in at the end of the work (see the final section added with the last commit).
