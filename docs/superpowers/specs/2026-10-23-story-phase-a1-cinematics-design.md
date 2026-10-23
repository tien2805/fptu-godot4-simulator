# Story Phase A1: Cinematic System – Design

Date: 2026-10-23. Status: written for the owner, who approved going ahead without a review round; decisions A1-D1 … A1-D24 are Claude's calls inside the owner's brief.
Parent spec: `docs/superpowers/specs/2026-10-22-story-tool-den-design.md` (S-D9, S-D10, S-D14; sections 8.1 and 8.3).
Plan: `docs/superpowers/plans/2026-10-23-story-phase-a1-cinematics.md`.
Prototype it builds on: branch `proto-cine`, commit `ec72795` (report `docs/proto_cine_report.md` on that branch).

## 1. Goal and scope

A1 builds the in-engine cinematic system and proves it with one full cinematic, `seg_d1_brawl` (25 s). Owner, 2026-10-23: build the cinematic system right after the vice-people merge.

**In A1:**
1. Mixamo pipeline. The owner's local Mixamo FBX files are retargeted onto the game's rigged characters. The game and the tests run fully without them, falling back to the CC0 Quaternius UAL clips, the body's own clips or code poses.
2. A data-driven cinematic timeline player, with one GDScript per cinematic.
3. Segment features:
   - a cinematic clock separate from the game clock;
   - speed ramps and freeze frames;
   - code-built impact FX;
   - a fixed real-time length, enforced by a validator;
   - a beat sheet file and a debug overlay.
4. Music slots: owner files from `user://music/`, with a synthesized default cue.
5. The short replay system for the 12 short segments. It is tested with scripted actors.
6. `seg_d1_brawl`: the protagonist against three couriers at a real FreeRoam location. It is launched from a developer entry only.

**Deferred to A2** (recorded here so nobody builds them in A1):
- the story framework (`StoryDirector`: day, evidence, choices, flags, mission markers, save/continue);
- the character creator;
- Day 0;
- the meme/horror SFX synthesizer beyond the few cues A1 needs (A1-D14);
- the 3 a.m. call;
- **the main-menu change** (owner, 2026-10-23). In one change, `scripts/MainMenu.gd`:
  - loses the old-story entries "▶ BẮT ĐẦU NGÀY MỚI" and "📋 CHỌN MÀN", the "Nhật ký hành trình" panel and the [M] hub shortcut;
  - gains the "TOOL ĐEN" entry in their place.

  A1 does not touch `scripts/MainMenu.gd`.

## 2. Decisions

| # | Decision |
|---|---|
| A1-D1 | **Mixamo files are local only.** <ul><li>They live in `res://assets/local/mixamo/`. The whole `assets/local/` folder is git-ignored and excluded from exports (`export_presets.cfg` `exclude_filter` gains `assets/local/*`).</li><li>The owner copies and imports them with `tools/import_mixamo.bat` (default source `D:\mixamo_fight`).</li><li>Clip name = file stem without its `NN_` prefix (`07_Flying_Kick.fbx` → `Flying_Kick`).</li><li>Nothing in the game or the tests needs these files. Mixamo-specific test checks print `SKIP (no Mixamo files in res://assets/local/mixamo/)` and pass.</li></ul> |
| A1-D2 | **Runtime retargeting.** <ul><li>No import-time BoneMap or Retarget settings.</li><li>The prototype's `CineRetarget` becomes source-generic, with three sources plus the body's native clips: `mixamo`, `ual1`, `ual2` and `native`.</li><li>One bone table gains a Mixamo column. Bone and track names are normalised by stripping `mixamorig_` (Godot 4.7 FBX import) or `mixamorig:` (older exports).</li><li>Sources bind lazily per skeleton. A test hook `CineRetarget.disabled` makes any source act as missing.</li></ul> |
| A1-D3 | **Prototype hand-over.** <ul><li>Code comes over from `ec72795` by **path checkout**, not by merge or cherry-pick: `scripts/cine/CineRetarget.gd`, `scripts/cine/CineActor.gd`, the UAL library with its licences and `CREDITS.md`, and `tests/preview_cine_retarget.gd`.</li><li>These stay on `proto-cine` as reference only, read with `git show ec72795:<path>`: `CineTimeWarp` (replaced by `CineClock`), `CineBrawl`, `CineAlley`, `scenes/proto/`, the four preview PNGs and the report.</li><li>Reason: a merge would drag in the untuned WIP scene, 2.7 MB of preview PNGs and a clock that A1 replaces.</li></ul> |
| A1-D4 | **Choreography uses logical moves, not raw clips** (`CineMoves`). <ul><li>A move has a fixed story duration and an impact fraction `hit_u`.</li><li>At run time it resolves to the best available tier: Mixamo → UAL (CC0) → native body clip → code pose.</li><li>Each tier's clip window `[from, hit, to]` is mapped piecewise-linearly onto the move, so its impact frame lands on the same story time.</li><li>Result: blocking, timing and the beat sheet are identical whichever tier plays.</li><li>Airborne height and flip rotation missing from a tier are added by per-entry extras (`arc`, `spin`) over the move's air window.</li></ul> |
| A1-D5 | **Root motion.** <ul><li>Mocap plays in place: the source hips' horizontal displacement is removed relative to the window start.</li><li>All travel and airborne arcs come from the timeline's root keys.</li><li>Vertical hip motion is kept by default (flips, crouches, falls). A move can strip it (`root_y: "strip"`) when an arc supplies the height.</li><li>Probe data: Mixamo clips are not in place. For example, Front_Flip travels 6.3 m and Running_Slide 6.4 m.</li></ul> |
| A1-D6 | **Two clocks.** <ul><li>Real time `r`: music, subtitles, camera motion inside a shot, the fixed length.</li><li>Story time `s`: actors, FX, cue times.</li><li>The cinematic never writes `Engine.time_scale`. It measures real time with `Time.get_ticks_usec()`, or `step(dt)` in tests.</li><li>In FreeRoam, a cinematic pauses the scene tree, which freezes the game clock. The player runs with `PROCESS_MODE_ALWAYS`.</li></ul> |
| A1-D7 | **Analytic speed ramps** (`CineClock`). Every ramp is defined by real-time durations:<ul><li>ramp-in, speed 1 → k (smoothstep);</li><li>hold at k;</li><li>freeze, speed 0;</li><li>hold at k;</li><li>ramp-out, k → 1.</li></ul>Its real span and story span are therefore exact. Five presets: `light`, `medium`, `heavy`, `finisher`, `accent`. Accents are near-misses and flip apexes: a slow-down without a freeze. |
| A1-D8 | **Validator.** A timeline is valid only when all of these hold:<ul><li>the real duration equals the slot length within 0.5 ms;</li><li>ramps do not overlap;</li><li>impact ramps have k 0.25–0.40 and a freeze of 0.10–0.20 s; accents have k 0.20–0.60;</li><li>the last 3.0–4.0 s run at normal speed;</li><li>every impact ramp has a strike cue on it;</li><li>every cue lies inside the story;</li><li>shots start at 0 and are sorted;</li><li>subtitles lie inside the real length;</li><li>every referenced move, actor, hit and rig exists.</li></ul>`CinePlayer.setup()` refuses an invalid timeline: it plays nothing and returns the errors. The timeline test fails on any error. |
| A1-D9 | **Beat sheet.** <ul><li>`docs/cinematics/<slot>.txt` is generated from the timeline by `tools/cine_beats.gd` and committed.</li><li>The cinematic's test regenerates the text and fails if the committed file differs, so it never drifts.</li><li>Every time is in real seconds with three decimals.</li></ul> |
| A1-D10 | **One timeline per cinematic:** `scripts/cine/timelines/<slot>.gd` extends `CineTimeline` and fills it in `build()`. It is code rather than `.tres`: diffable, and positions can be computed. `CineTimeline.load_slot(slot)` and `CineTimeline.slots()` find them. |
| A1-D11 | **Cameras.** <ul><li>Shot boundaries are given in story time.</li><li>Camera motion inside a shot advances on real time, so bullet-time orbits keep moving through freezes.</li><li>Rigs: `static`, `dolly`, `orbit`, `low_hero`, `track` and `crane`.</li><li>Every impact inside a shot adds a whip-pan: a yaw pulse of 7–12° over about 0.12 s real, a FOV punch, and a 1–2 cm shake during the freeze. A shot can opt out.</li></ul> |
| A1-D12 | **Subtitles** are placed at real times. <ul><li>The speaker name is coloured, followed by the line.</li><li>A translation line "Dịch: …" sits smaller underneath. It is mandatory for Anh Duy's lines (S-D12) and allowed on any line.</li><li>The protagonist's speaker name comes from the actor (A1 default "Bạn").</li></ul> |
| A1-D13 | **Music slots.** <ul><li>The loader tries `user://music/<slot>.ogg`, then `.mp3`. The folder is outside the project, so it is never committed or exported.</li><li>Without a file, a default cue is synthesized offline to the exact real length, with accents on the timeline's real impact times.</li><li>Music starts on the cinematic's first frame.</li><li>A longer file fades linearly to silence over the last 0.5 s and stops at the end. A shorter file simply ends.</li></ul> |
| A1-D14 | **SFX.** `user://sfx/<cue>.ogg` overrides any cue. Otherwise ten synthesized A1 cues play: <ul><li>`impact_light`, `impact_medium`, `impact_heavy`;</li><li>`whoosh_down`, `freeze_tick`;</li><li>`crate_smash`, `body_fall`;</li><li>`slide_whistle`, `groan`, `phone_buzz`.</li></ul>`slide_whistle` is needed by Day 1's banana gag (spec section 4). Hits get automatic SFX by preset. The full meme/horror bank is A2. |
| A1-D15 | **Impact FX built from code.** <ul><li>Sparks and dust: `CPUParticles3D` with `speed_scale` following the clock, so they freeze with the clock.</li><li>Debris: analytic ballistic chunks in story time.</li><li>Also: an impact flash, a crate stack that breaks into pre-cut planks, and comic stars over knocked-out heads.</li><li>Textures are generated with `Image`, never AI images.</li><li>No shockwave ring: the prototype found it reads as a "portal".</li></ul> |
| A1-D16 | **Skip.** <ul><li>Holding Esc for 0.8 s real skips. A progress bar shows "Giữ ESC để bỏ qua" while the key is held.</li><li>A skip fades to black over 0.25 s, then emits `finished(true)`.</li><li>`StageManager` gains `cinematic_active`. While it is set, Esc does not open the pause menu.</li></ul> |
| A1-D17 | **Framing.** <ul><li>Letterbox bars at 2.39:1 slide in over 0.4 s real.</li><li>Fade in from black over 0.5 s.</li><li>Fade out to black over `fade_out` s: 0.5 by default; 0 when A2 chains a segment into its mission's end cinematic (spec 8.1).</li></ul> |
| A1-D18 | **Short replays.** <ul><li>`CineReplayRecorder` keeps a ring buffer of game time at 30 Hz, 8 s by default: global transforms of registered actors plus full bone poses for rigged ones. `mark("blow")` stamps the event.</li><li>`CineReplay` pauses the tree, drives the same nodes from recorded frames and restores the live state afterwards.</li><li>The real length is fixed (default 5.0 s, clamped 4–6). A `CineClock` with base speed 0.5 and one heavy ramp at the mark, placed at 55 % of the length, guarantees it.</li><li>Three automatic shots (orbit, low close, wide pull-back) with wall-avoid raycasts, plus a music sting from the slot.</li><li>Code-built (non-rigged) bodies replay their transform only.</li></ul> |
| A1-D19 | **`seg_d1_brawl` staging.** <ul><li>Place: the road edge outside the campus west (back) gate (`landmarks.campus_west_gate`), at night.</li><li>The stage frame is found at run time by a clear-rectangle search, 14 × 10 m within 30 m of the landmark. The search ignores pedestrians, traffic, the player and the bike.</li><li>Cast: the protagonist (default name "Bạn", preset `player`) against three fictional couriers: "Shipper Mũ Vàng", "Shipper Mũ Đỏ" and "Shipper Mũ Xanh". They wear unbranded jackets in muted mustard, maroon and teal, and helmets coloured as their names.</li><li>Set dressing: a crate stack, an unbranded delivery scooter, a banana peel and a phone.</li></ul> |
| A1-D20 | **Developer entry only.** <ul><li>F9 in FreeRoam, debug builds only, cycles through the timelines.</li><li>`scenes/dev/CinePreview.tscn`: FreeRoam with the crowd off, auto-plays `CINE_SLOT` (default `seg_d1_brawl`). R replays, F10 toggles the debug overlay.</li><li>The main menu is untouched until A2.</li></ul> |
| A1-D21 | **Actors are real game models.** <ul><li>`CineActor` builds through `CharacterBuilder.build()` with `rigged: true, animate: false`, from the opts the caller passes.</li><li>A1 uses fixed default protagonist opts. A2's creator passes the saved ones.</li><li>Both art styles work: PS2 head in vice, stylized head in classic.</li></ul> |
| A1-D22 | **Code-pose tier.** <ul><li>Code poses are Euler poses applied with `CharacterBuilder._apply_bone_pose`, on top of the neutral standing base (`_neutral_base`).</li><li>The prototype's flying kick, spin kick and scissor are ported and retuned.</li><li>New: tuck (flip), dodge lean, block, knee, uppercut, taunt, victory, lying and get-up.</li><li>The scissor takedown is code only: no Mixamo clip exists for it.</li></ul> |
| A1-D23 | **Budgets.** <ul><li>Retarget sample ≤ 0.5 ms (probe: 0.24 ms Mixamo, 0.19 ms UAL).</li><li>A whole cinematic frame update ≤ 8 ms on average headless.</li><li>The synthesized 25 s default cue takes < 3 s to build. It is built on a worker thread before the first frame, during the black fade-in hold.</li><li>The owner checks ≥ 45 fps on the target PC (RTX 4050, 1280×720, quality 2).</li></ul> |
| A1-D24 | **Branch and delivery.** <ul><li>Work happens on worktree branch `story-a1` from main `b5bbb08`.</li><li>Seven plan tasks, each with one review at effort high.</li><li>Implementer effort xhigh for the retargeter, the player and `seg_d1_brawl`; high for the rest.</li><li>No preview renders or screenshots: the owner play-tests.</li></ul> |

## 3. Architecture

```
scripts/cine/
  CineRetarget.gd      sources (mixamo/ual1/ual2/native) -> local pose of the game skeleton      [A1-D2, D5]
  CineMoves.gd         logical moves -> resolved tier + clip window + extras; code poses          [A1-D4, D22]
  CineActor.gd         one real game character driven purely by story time s                       [A1-D21]
  CineClock.gd         analytic real <-> story clock, presets, validate(), beat rows              [A1-D7, D8]
  CineTimeline.gd      data model + authoring helpers + validate() + beat_sheet() + slot registry  [A1-D9, D10]
  CineShots.gd         camera rigs and whip-pan (pure functions)                                   [A1-D11]
  CineOverlay.gd       letterbox, fade, subtitles, skip bar, tag, debug overlay (CanvasLayer)      [A1-D12, D16, D17]
  CineAudio.gd         music slot loader, synthesized cue/sting, gain rule, SFX bank               [A1-D13, D14]
  CineFX.gd            sparks, dust, flash, debris, crate break, stars; set-dressing props         [A1-D15]
  CinePlayer.gd        plays a timeline: actors, props, camera, overlay, audio, FX, skip           [A1-D6]
  CineReplayRecorder.gd  ring buffer + replay clock                                                [A1-D18]
  CineReplay.gd        plays a short replay from a recorder                                        [A1-D18]
  CinePreview.gd       dev preview scene script                                                    [A1-D20]
  timelines/seg_d1_brawl.gd                                                                        [A1-D19]
tools/import_mixamo.bat, tools/mixamo_report.gd, tools/cine_beats.gd
scenes/dev/CinePreview.tscn
FreeRoam.gd: cine_stage(), play_cinematic(), F9.   StageManager.gd: cinematic_active.
```

Data flow per frame:
1. `CinePlayer` advances `r` and gets `s = clock.story_at(r)`.
2. Every `CineActor` evaluates at `s`: root keys plus move extras, then the pose blend of the active move cues (crossfade), code overlays, overrides, look-at and expression cell.
3. `CineFX.update(s, speed)` runs, and story-time events (FX, SFX) that `s` has crossed fire.
4. The shot containing `s` is evaluated with its real-time progress, then the whip-pan, then the stage transform is applied to the camera.
5. The overlay (letterbox, fade, subtitle at `r`, skip bar, debug) updates.
6. The music `volume_db` follows `CineAudio.music_gain(r)`.

## 4. Mixamo pipeline

**Probe** (Godot 4.7.2 headless, scratch project with all 32 owner files, 2026-10-23):
- **Import.** All 32 files imported with 0 errors and 0 warnings in 7 s, using the built-in ufbx with default import settings.
- **Skeleton.** Each scene is `Node3D` › `Skeleton3D` (65 bones, names `mixamorig_*`) and `AnimationPlayer`, in metres. There is no 100× scale node.
- **Animations.** Every clip file has one animation `mixamo_com`, keyed at 30 fps: 53 tracks, or 43 when the finger tip `*3` bones are unkeyed. The only position track is `mixamorig_Hips`. The Y Bot file has `Take 001` (1.67 s) and `mixamo_com` (0.03 s), both T-pose.
- **Rest pose.** Every clip file has the same T-pose rest as `00_Y_Bot_TPose.fbx`: max 0.1 mm and 0.04° apart.
- **Axes.** Every limb bone's local +Y runs along the bone (dot = 1.000). The character faces +Z with +X on its left, the same frame as UAL. So the retargeter's `delta/yaw/dir/leg/foot` classes apply unchanged.
- **Root motion is kept** (the owner exported without "In Place"). Hips travel: Flying_Kick 2.1 m, Hurricane_Kick 3.3 m, Front_Flip 6.3 m, Running_Slide 6.4 m, Cartwheel 3.1 m. Fighting-stance clips start with the hips yawed about 45° (boxing stance).
- **Retarget numbers** onto `men/Casual_2`, with the planned code:
  - leg ratio k = 1.032;
  - 51 mapped bones;
  - standing clips put the target ankle 0.10–0.11 m above ground, matching source foot × k within 2 cm;
  - flips turn the body fully over (minimum body-up · world-up −0.97 to −0.99);
  - no NaN in any clip;
  - 0.24 ms per sample.

**Bone map** (Quaternius target ← Mixamo source, prefix stripped; class in brackets):

| Target | Mixamo | Class |
|---|---|---|
| Body, Hips | Hips | yaw (Body also takes the position) |
| Abdomen | Spine | yaw |
| Torso | Spine1 | delta |
| Chest | Spine2 | delta |
| Neck / Head | Neck / Head | delta |
| Shoulder.L / UpperArm.L / LowerArm.L / Wrist.L | LeftShoulder / LeftArm / LeftForeArm / LeftHand | delta / dir / dir / dir |
| Index1-3.L, Middle1-3.L, Ring1-3.L, Pinky1-3.L | LeftHandIndex1-3, LeftHandMiddle1-3, LeftHandRing1-3, LeftHandPinky1-3 | dir |
| Thumb1-3.L | LeftHandThumb1-3 | dir |
| UpperLeg.L / LowerLeg.L | LeftUpLeg / LeftLeg | leg |
| Foot.L (IK target under Root) | LeftFoot | foot (re-attached at the shin's ankle) |
| right side | mirrored (`Right*`) | same |

Unmapped:
- target `Root`, `PT.L/R` (pole targets) and the finger tips `*4`;
- source `HeadTop_End`, `*Toe*` and `*4` tips.

The Quaternius body has 62 bones. Its `UpperLeg.*` are children of `Body`, not `Hips`. The retargeter works in globals, so the hierarchy difference does not matter.

**Missing files.** Without the files, `CineRetarget.available("mixamo")` is false and every move resolves to its next tier. The import helper prints which of the 31 expected clips are missing. A partial set works too: each move checks its own clip.

**Licence stance.** Raw Mixamo files are never committed or redistributed, and builds exclude them. If the owner wants mocap in his own exported build, he deletes `assets/local/*` from the preset's exclude filter on his machine. A1 does not do that.

## 5. Moves and fallback tiers

A move definition holds:
- `dur`: story seconds;
- `hit_u`: impact fraction, −1 for non-strikes;
- `loop`;
- `air`: `[u0, u1]`, the fraction window where extras apply;
- `root_y`: `keep` or `strip`;
- `src`: an ordered list of entries `{t, a, from, hit, to, arc, spin, add, yaw}`.
  - `t` is `mixamo`, `ual1`, `ual2`, `native` or `code`.
  - `to = -1` means the full clip.
  - A window with `from > to` plays backwards.
  - `yaw` (degrees) is added to the actor's keyed yaw while that entry plays, so stance clips face the target.

`CineMoves.max_tier` (a test hook) caps the best tier: 0 = all, 1 = no Mixamo, 2 = no Mixamo and no UAL, 3 = code only.

The initial table (Mixamo strike times come from the probe's reach peaks; Task 7 tunes them):

| Move | dur | hit_u | Mixamo `from/hit/to` | UAL | native | code |
|---|---|---|---|---|---|---|
| fight_idle (loop) | 3.3 | – | Fighting_Idle 0/–/3.3 | ual1 Idle | Idle | stance |
| taunt | 1.6 | – | Taunt 0/–/1.63 | ual2 Idle_No | Wave | taunt |
| sprint (loop) | 0.533 | – | Sprint 0/–/0.533 | ual1 Sprint | Run | – |
| jog (loop) | 0.8 | – | – | ual1 Jog_Fwd | Run | – |
| walk (loop) | 1.0 | – | – | ual1 Walk | Walk | – |
| flying_kick | 1.0 | 0.55 | Flying_Kick 0/0.53/1.10 | – | – | flying_kick, arc 0.9 |
| jab | 0.45 | 0.55 | Jab_Cross 0.15/0.40/0.55 | ual1 Punch_Jab 0/0.22/0.6 | Punch_Left 0/0.35/0.83 | – |
| cross | 0.5 | 0.5 | Jab_Cross 0.50/0.67/0.95 | ual1 Punch_Cross 0.1/0.3/0.7 | Punch_Right 0/0.35/0.83 | – |
| hook | 0.7 | 0.55 | Hook_Punch 0.6/1.0/1.4 | ual2 Melee_Hook 0/0.25/0.47 | Punch_Right 0/0.35/0.83 | – |
| uppercut | 0.8 | 0.5 | Uppercut 0.2/0.53/0.95 | ual1 Punch_Cross 0.1/0.3/0.7 + add uppercut | Punch_Left 0/0.35/0.83 + add uppercut | – |
| roundhouse | 1.0 | 0.5 | Roundhouse_Kick 0.6/1.07/1.6 | – | Kick_Right 0.1/0.45/0.93 + add spin_kick | spin_kick |
| hurricane_kick | 1.2 | 0.5 | Hurricane_Kick 0/0.9/1.83 | – | – | spin_kick, arc 0.7, spin y −360 |
| front_flip | 1.2 | 0.5 | Front_Flip 0.2/0.95/1.5 | – | – | tuck, arc 1.4, spin x −360 |
| dodge | 0.8 | 0.45 | Dodging 0/0.5/1.2 | – | – | dodge_lean |
| block | 0.8 | 0.4 | Block 0.1/0.45/1.2 | ual2 Sword_Block | – | block |
| knee_strike | 0.9 | 0.5 | Knee_Kick 0.2/0.47/1.0 | – | Kick_Left 0.1/0.45/0.93 | knee |
| hit_head | 0.6 | 0.1 | Head_Hit 0/0.12/1.0 | ual1 Hit_Head | HitRecieve | – |
| hit_stomach | 0.6 | 0.1 | Stomach_Hit 0/0.1/1.0 | ual1 Hit_Chest | HitRecieve_2 | – |
| launched_back | 1.6 | 0.05 | Flying_Back_Death 0.2/0.3/2.0 | ual2 Hit_Knockback, arc 0.8 | Death, arc 0.8 | – |
| knocked_out | 2.0 | 0.05 | Knocked_Out 0.6/0.7/4.9 | ual1 Death01 | Death | lie_back |
| sweep_fall | 1.4 | 0.35 | Sweep_Fall 0.5/1.0/2.5 | – | Death | – |
| slip_fall | 1.2 | 0.3 | Sweep_Fall 0.6/1.0/2.5 | – | Death | – |
| lie (loop, held) | 1.0 | – | Knocked_Out 4.9/–/4.93 | ual1 Death01 end | Death end | lie_back |
| get_up | 2.0 | – | Getting_Up 4.0/–/8.33 | ual2 LayToIdle | Death reversed | getup |
| victory | 2.0 | – | Victory 0.5/–/2.5 | ual2 Yes | Wave | victory |
| scissor_takedown | 1.1 | 0.6 | – | – | – | scissor, arc 0.8, spin z −80 |

## 6. Timeline data model

`CineTimeline` has these fields:
- `slot`, `length` (real s), `story_end` (story s);
- `music_slot` (default `slot`), `mood` (synth cue style);
- `fade_in`, `fade_out`, `letterbox`;
- `stage` (`{landmark, near, size, tod, yaw_deg}`);
- `clock` (`CineClock`);
- `actors` (`id → {opts, name, color}`);
- `cues` (story time), `shots` (story time), `subs` (real time);
- `sfx` and `fx` (story time or a hit name);
- `props` (stage-local positions).

Authoring helpers:
- `actor()`, `hit(name, s, preset, what)`;
- `move()`, `strike(actor, hit_name, move)`: the impact frame lands on the ramp's story time;
- `key()`, `expr()`, `look()`, `show()`;
- `shot()`, `sub()`, `sfx_at()`, `fx_at()`, `prop()`.

Positions are stage-local: X to the right, −Z forward along the road, ground at y = 0. The player applies the stage transform found in FreeRoam, or identity in the empty test world. Game characters face −Z at yaw 0 (`CharacterBuilder.MODEL_YAW = PI`), so `face(from, to) = atan2(−dx, −dz)`.

## 7. Clock and the fixed real-time length

Per ramp at story time `s` with speed k and base speed b (1 in cinematics, 0.5 in replays):
- story before the impact: `pre = ri·(b+k)/2 + hp·k`;
- story after the impact: `post = hq·k + ro·(k+b)/2`;
- real span: `ri + hp + freeze + hq + ro`.

∫₀¹ smoothstep = ½, so smooth ramps have the same story span as linear ones. For the same reason `story_at(r)` is closed form inside a ramp:
- ramp-in: `s0 + d·(b·u + (k−b)·(u³ − u⁴/2))`;
- ramp-out: `s0 + d·(k·u + (b−k)·(u³ − u⁴/2))`.

The impact's real time is the start of its freeze.

**Real length** = `(story_end − Σ(pre+post))/b + Σ real_span`, exactly.

The fixed length is guaranteed by four mechanisms:
1. The timeline declares `length` (the slot length) and `story_end` as literals.
2. `validate()` computes the real duration through the segments and fails unless it is within 0.5 ms of `length`. The error message gives the exact `story_end` that fixes it.
3. Playback runs on real time and ends at the first frame with `r ≥ length`. That frame is evaluated at `r = length`, and the music is faded to 0 by `length`.
4. The cinematic's test steps playback at 1/60 s and asserts `finished` after 1500 ± 1 steps.

Presets (real seconds; extra = real span − story span at b = 1):

| Preset | k | freeze | ri | hp | hq | ro | real span | story span | extra |
|---|---|---|---|---|---|---|---|---|---|
| light | 0.40 | 0.10 | 0.10 | 0.10 | 0.25 | 0.15 | 0.70 | 0.315 | 0.385 |
| medium | 0.30 | 0.14 | 0.12 | 0.20 | 0.50 | 0.22 | 1.18 | 0.431 | 0.749 |
| heavy | 0.25 | 0.18 | 0.15 | 0.30 | 0.80 | 0.30 | 1.73 | 0.55625 | 1.17375 |
| finisher | 0.25 | 0.20 | 0.20 | 0.45 | 1.00 | 0.35 | 2.20 | 0.70625 | 1.49375 |
| accent | 0.30 | 0 | 0.12 | 0.25 | 0.35 | 0.25 | 0.97 | 0.4205 | 0.5495 |

## 8. Beat sheet and debug overlay

`docs/cinematics/<slot>.txt` (generated, exact format in plan Task 3):
- a header with the real length, the story length, the normal-speed tail, and the music rule with the fade window;
- one row per ramp: id, preset, real impact, freeze end, slow-motion window, speed, story time and description;
- one row per shot: id, real start, rig and description;
- one row per subtitle: real start, end, speaker and line.

The debug overlay shows:
- `r`, `s` and the clock speed;
- the current shot and the next beat;
- a strip across the screen with a marker per impact and the playhead.

F10 toggles it, and `CINE_DEBUG=1` turns it on.

## 9. Player and integration

**`CinePlayer.setup(timeline, stage_xf)`:**
1. Validates the timeline; an invalid one returns the errors and builds nothing.
2. Builds the actors, props, `Camera3D`, overlay, FX and audio players.
3. Starts the music synthesis (or file load) on a worker thread.

**`start()`:** waits for the music, then plays from r = 0.

**Each frame:**
1. Evaluate actors.
2. Fire the story-time events crossed since the last frame. Automatic SFX: `whoosh_down` at the start of heavy and finisher ramps, the preset's impact cue, and `freeze_tick` at the freeze.
3. Update the FX, camera, overlay and music gain.

**Skip:** holding Esc skips (A1-D16).

**`FreeRoam.play_cinematic(tl)`:**
1. Finds the stage (A1-D19). If none is found, it shows a hint and returns null.
2. Saves and sets the time of day (`tl.stage.tod`).
3. Hides the player, the bike, its HUD holders, the pedestrians and the traffic. Pedestrians and traffic are also process-disabled.
4. Pauses the tree, sets `StageManager.cinematic_active`, and adds the player as a child.
5. On `finished`, restores everything, unpauses, makes the player camera current and emits `cinematic_finished(slot, skipped)`.

**F9** (debug builds): plays the next slot from `CineTimeline.slots()`.

## 10. Impact FX

Spawned at story time by FX cues and automatically per hit preset:
- light: small sparks at the victim's struck bone;
- medium: sparks and a flash;
- heavy/finisher: big sparks, a flash and a dust ring.

Crate breaks hide the intact crates and launch pre-cut plank chunks. Debris uses `p = p0 + v·t + ½·g·t²` in story seconds since the spawn, with one damped bounce at the ground and a resting rotation. Stars are three code-built star meshes orbiting above an actor's head bone while the cue lasts.

## 11. Music and SFX

- **Default cue** (`CineAudio.synth_cue(length, hits, mood)`): 22.05 kHz mono 16-bit `AudioStreamWAV`, built from pasted, precomputed voice tables.
  - a tempo grid of kick plus bass (mood `punchy`: 118 bpm, minor), ducked to 40 % inside slow-motion windows;
  - a 0.3 s riser before heavy and finisher impacts;
  - a boom (sine drop 90 → 40 Hz) plus a noise burst at every real impact;
  - a high tick at every freeze;
  - an outro hit at the start of the tail;
  - a 0.5 s fade at the end.
- **Sting** (`synth_sting(length, r_hit)`): a short version of the same, for replays.
- **Owner files** override both through the slot loader (A1-D13).

## 12. Short replays

`CineReplay.start(recorder, {length, slot, focus, other, mark, base})`:
1. Clamps the length to 4–6 s.
2. Builds the clock with `CineReplayRecorder.replay_clock(L, f, after)`. The footage after the mark is whatever was recorded; the rest of L goes before it. Frames outside the recording hold the nearest frame.
3. Pauses the tree, sets `cinematic_active`, snapshots the live state, and shows the letterbox with a "▶ REPLAY" tag.
4. Plays the sting, and every frame applies `recorder.apply_at(t0 + clock.story_at(r))`.
5. Cuts automatically:
   - orbit until the ramp starts;
   - low close shot during the ramp, with a whip at the impact;
   - wide pull-back after.
6. Restores the live state, the camera and the pause flag, then emits `finished`.

Phase B calls it after combat finishers with a 0.8 s delay, so footage after the blow exists. A1 tests it with scripted actors.

## 13. `seg_d1_brawl` (25.000 s)

The full beat and shot tables are in plan Task 7. Summary:
- **Story length:** 16.49325 s.
- **Ramps:** 8 impacts and 3 accents. The last ramp ends at 21.500 s real, leaving a 3.500 s normal-speed tail.
- **Choreography:**
  1. Standoff at the back gate at night: courier Mũ Vàng taunts.
  2. Flying kick launches Mũ Vàng past the scooter.
  3. Dodge Mũ Đỏ's hook, then jab, cross and uppercut launch him to the kerb.
  4. Front flip over the charging Mũ Xanh, then a roundhouse sends him into the crate stack, which shatters.
  5. Mũ Vàng gets up and throws a flying knee, which is blocked; a hurricane kick follows.
  6. The Vovinam scissor takedown slams him down.
  7. Tail at 1×: stars over heads, Mũ Đỏ crawls away and slips on the banana peel (slide whistle), the dropped phone buzzes, and the protagonist looks at it. The phone is the hook into `cine_d1` (A2).

## 14. Testing

New headless tests:

| Test | Task |
|---|---|
| `tests/test_cine_retarget.gd` | 1 |
| `tests/test_cine_actor.gd` | 2 |
| `tests/test_cine_clock.gd` (with `tests/test_cine_timeline.gd`) | 3 |
| `tests/test_cine_audio_fx.gd` | 4 |
| `tests/test_cine_player.gd` | 5 |
| `tests/test_cine_replay.gd` | 6 |
| `tests/test_cine_d1_brawl.gd` | 7 |

Rules:
- Tests count physics frames or pin `Engine.max_fps = 60`.
- Mixamo checks skip with a printed note when the files are missing.
- Every tier is tested by forcing `CineMoves.max_tier`.
- Every task runs the full regression: check-only, every `tests/test_*.gd`, and smoke.
- Preview scripts may be added but are never run by an agent.

## 15. Risks

1. **Contact alignment differs per tier.** Limb poses differ between Mixamo, UAL and code, so a fist can miss by 10–30 cm. Root keys, timing and the beat sheet are shared, and the strike reach is the same per move. Task 7 checks contact distance with a soft test (< 0.6 m for every tier), and the owner tunes by eye.
2. **Mixamo stance yaw.** Fighting clips face about 45° off. The timeline keys yaw, and the move table records a per-entry `yaw` offset (Task 2) so all tiers face the target.
3. **Code poses are stiff** (prototype finding). They are a fallback only. With the Mixamo files present, only the scissor takedown is code-posed.
4. **Stage search.** The back-gate road edge may be cluttered (bus stop, fences, trees). The search widens to 30 m, and the test asserts a clear spot exists. If none does, the fallback is the campus parking centre (`campus_parking_center`).
5. **Music synthesis time** on slow PCs is mitigated by the worker thread. If the build is still running at `start()`, the cinematic waits on black (fade-in hold), never out of sync.
6. **Godot class cache.** Twelve new `class_name` scripts mean `godot --headless --import --path .` after each task that adds one, in the worktree and again on main after the merge.
