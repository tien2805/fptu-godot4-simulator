# Story Phase C "Kiếm và gậy": Implementation Plan (sword duels + bosses)

Spec: `docs/superpowers/specs/2026-10-26-story-phase-c-days-2-3-5-design.md`, decision **C-D3** (sword duels), the Day 2
Sói Xám and Day 5 Za Mẫn parts of **C-D4**, and their tests from **C-D13**. Branch `phase-c-swords`, base 291b403.
Bike combat, lair gunfights, cinematics and the Day 2 / Day 5 story wiring belong to other agents: this branch never
touches story files or timelines. Boss looks come in as opts (`body`, `body_fn`); StoryCast looks are added elsewhere.

**Goal.** A sword duel mode on top of the Phase B `PlayerCombat` (the player wields a code-built Vovinam staff), the
Za Mẫn katana boss with telegraphed patterns, phases and a katana that bends and breaks, and the Sói Xám unarmed
mini-boss as a new `MeleeEnemy` archetype usable through `MeleeFight` with a boss bar.

**Architecture.**
- Reuse, not fork: the player side stays `PlayerCombat` (moves, block, perfect block, dodge, HUD) with a swappable move
  set; both bosses are `MeleeEnemy` (Za Mẫn as the subclass `KatanaBoss`); the duel encounter wraps one `MeleeFight`
  (waves, checkpoint, retry, lost / won, force unarmed, refusals of [F] / [P] / [B]).
- New code in `scripts/combat/swords/`: `SwordData` (numbers, patterns, phases, texts, code poses `sw_*`), `SwordProps`
  (staff and hand attach), `KatanaProp` (segmented blade: bend stages, wobble, glint, snap), `KatanaBoss`, `SwordDuel`,
  `SwordAudio` (synthesized SFX on WorkerThreadPool tasks, owner overrides in `user://sfx/`).

## Task 1: Surgical Phase B hooks (backward compatible)

Files: `PlayerCombat.gd`, `MeleeEnemy.gd`, `MeleeFight.gd`, `CombatHUD.gd`, `CombatData.gd`.
- `PlayerCombat`: move set vars (`light_moves`, `heavy_move`, `counter_move`, `controls_text`, `counter_text`,
  `block_pose`, `idle_pose`, `dodge_m`, `blade`, `cue_map`) with `set_moveset(d)` / `reset_moveset()`; a move's optional
  `pose` key plays a code pose over the clip; the counter's strike kind is the counter move's id; `boss` (Node3D) for the
  HUD boss bar; `_cue` remaps through `cue_map` and resolves `SwordAudio` cues. Defaults = today's unarmed behaviour.
- `MeleeEnemy`: states `HOWL` and `FINALE` appended; `guard_pose` / `block_pose` vars; stats-driven LED-eye glow
  (`glow`: eyes light up for every wind-up / telegraph until the impact) and howl phase (`howl_at`, `howl` buff,
  `howl_line`); `force_attack("combo")` (full chain, tests); `boss_marks()` for the boss bar; FINALE = scripted, not
  hostile, not defeated (the subclass ends it with a knockout).
- `MeleeFight`: spawn key `make` (Callable -> MeleeEnemy subclass); `combat.boss` = the first enemy whose stats have
  `boss`, cleared with the enemies.
- `CombatHUD`: bottom-centre boss bar (label, HP, phase ticks from `boss_marks()`), `boss_shown` for tests; no head bar
  for the boss; the control hint from `combat.controls_text`.
- `CombatData`: archetype `soi_xam` (fast 4-hit chains, light tell 0.38 s, glow, howl at 50 %: speed x1.25, damage
  x1.3, quicker wind-up / recovery, finisher not a KO, `boss`), pose `howl`, `sw_*` poses delegated to `SwordData`.

## Task 2: Staff, katana, audio

Files: `swords/SwordData.gd`, `swords/SwordProps.gd`, `swords/KatanaProp.gd`, `swords/SwordAudio.gd`.
- Staff moves: LMB 3 slashes (9 / 11 / 15 damage, 1.9 m reach), RMB thrust (20, 2.4 m, breaks blocks), hold Q block,
  perfect block = parry riposte (8 damage, the boss staggers 1.3 s, "GẠT ĐỠ"), Space dodge within 14 m. Landed hits
  spark and raise dust; clash, parry ring, whoosh and wood-hit cues replace the punch sounds.
- Props are code-built and ride a pivot under the hand's BoneAttachment3D, aligned on the forearm at rest (staff along
  it, katana tilted 25 degrees).
- KatanaProp: grip, guard and a 6-segment blade; bend stages 0-3 at 75 / 50 / 25 % HP (0, 0.35, 0.8, 1.4 rad), a
  decaying wobble on each hit, a glint star (white = blockable, red = dodge it), `snap()` at 0 HP drops the outer half
  as a falling piece.
- SwordAudio cues: staff_swish, staff_hit, staff_hit_heavy, blade_clash, parry_ring, glint, glint_red, katana_slash,
  katana_boing, katana_snap, howl. `warm(cues)` on worker tasks, `stream(cue)` adopts.

## Task 3: KatanaBoss + SwordDuel

Files: `swords/KatanaBoss.gd`, `swords/SwordDuel.gd`.
- KatanaBoss (MeleeEnemy): patterns of steps (slash_r, slash_l, slash_down, lunge, spin). Every hit is preceded by a
  glint + sound exactly 0.5 s ahead (`tells` log). Phase 1: chain2, chain3, lunge. Phase 2 at 66 %: faster (speed x1.2,
  shorter gaps and recovery) + spin. Phase 3 at 33 %: faster again (x1.4) + frenzy (slash, slash, slash, lunge). A phase
  change jumps back and taunts with a startup line. Lunge and spin are unblockable (red glint, red flash ring);
  slashes can be blocked and parried. At 0 HP: FINALE (katana snaps, slow motion, the comic stare and line, 1.8 s),
  then the knockout with stars, then `won`.
- SwordDuel API: `setup(opts)` (roam or player / combat / weapons; `at`, `yaw`, `boss` opts, `start_line`, `seed`),
  `start()`, `retry()`, `stop()`, signals `won`, `lost`, `phase_changed(phase)`, fields `state`, `phase`, `boss`,
  `fight`, `combat`. Start / retry swap in the staff set and prop; stop / free restore unarmed.

## Task 4: Tests

- `tests/test_sword_duel.gd`: move set swap and staff prop; 3-slash combo; heavy thrust breaks a block; block; parry
  stagger; dodge invulnerability (and Space dodges at 8 m); telegraphs before damage (AI on, 0.5 s lead for every hit,
  glint visible, red flash for unblockables); lunge and spin; phases and the signal; bend stages; break -> FINALE -> KO
  -> won; player down -> lost; retry; stop restores.
- `tests/test_soi_xam.gd`: archetype data; LED eyes; 4-hit combo; glow before every impact; howl at 50 % (armoured,
  buffed, once); boss bar; KO through MeleeFight -> won; AI-on chains.
- `tests/test_sword_perf.gd`: FreeRoam at BE6 with the crowd, a running duel (AI on, player in god mode attacking):
  duel cost < 3 ms per physics frame (median and 5 %-trimmed mean, `test_combat_perf` method).
- Regression: `--check-only`, smoke, `test_melee_combat`, `test_combat_perf`, `test_free_roam`.

## Known limits (accepted)

- Code poses over pack clips: the swings are approximations (no sword clips in the pack); the owner playtests the look.
- The staff hits pedestrians in free roam like fists if a duel is left running after `won` (stop or free it).
