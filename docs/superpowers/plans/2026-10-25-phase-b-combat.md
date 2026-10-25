# Story Phase B "Vovinam tay không": Implementation Plan (combat only)

Spec: `docs/superpowers/specs/2026-10-25-story-phase-b-days-1-4-design.md`, decisions **B-D1** and **B-D2**, plus their
tests from B-D12. Branch `phase-b-combat`, base 91a6c53. The horror toolkit, the Night Building, cinematics, characters
and the Day 1 / Day 4 story wiring are other agents' work: this branch never touches `StoryMissions.gd`, `StoryRoam.gd`
or a timeline.

**Goal.** Unarmed Vovinam combat for the player (free roam and story fights), data-driven melee enemies on the PS2 rigged
people, and one encounter node (`MeleeFight`) that the story integration agent drives for the Day 1 courier brawl and the
Day 4 clone waves + Dolly.

**Architecture** (all new code in `scripts/combat/`):
- `CombatData` (static): every number (moves, timings, damage, stagger, archetypes `courier` / `clone` / `dolly`), the
  Vietnamese texts, and the code-pose library (CineMoves code poses plus a few combat ones, static ones cached).
- `CombatPose` (Node, process_priority 11, after the RigAnimator at 10): lays one code pose (block, guard, wind-up, dazed,
  taunt, throw) over whatever the body's AnimationPlayer plays, with an eased weight. Pack clips (jab `punch_l`, cross
  `punch`, elbow `chop`, kick `kick`, flinch, knockdown, getup, roll) go through `CharacterBuilder.play` with the
  AnimationPlayer speed scaled so each clip fits its gameplay duration.
- `PlayerCombat` (Node on FreeRoam or on a fight): input, the player's move state machine, HP, lock-on, hit resolution
  against enemies (duck-typed `take_strike`) and against pedestrians / officers (Phase W `take_hit`, the Phase W combo and
  heat), finisher slow motion, the `CombatHUD`.
- `MeleeEnemy` (CharacterBody3D): one enemy, archetype data + caller opts, AI state machine, attacks through
  `PlayerCombat.receive_attack`.
- `MeleeFight` (Node3D): the encounter API (spawns, waves, 2-attacker tokens, checkpoint / retry, force unarmed).
- `CombatHUD` (CanvasLayer): player HP bar, enemy HP + stagger over heads, lock marker, telegraph ring, popups, finisher
  prompt; vice and classic styles; plain text only.

**Shared files (surgical edits only).**
- `ThirdPersonController.gd`: `combat_speed_cap` (ground speed cap), `jump_filter` (Callable consulted on a jump press,
  true = consumed by a dodge) and `dodge_roll(dir, secs, speed)` (the LAND_ROLL state with its own duration).
- `weapons/WeaponDirector.gd`: `unarmed_owner` (PlayerCombat owns Tay không: no Phase W punch, no right-mouse aim while
  unarmed). Without an owner the Phase W punch is unchanged (its tests keep passing).
- `CharacterBuilder.gd`: three PACK_CLIP aliases (`punch_l` Punch_Left, `kick_l` Kick_Left, `hit_b` HitRecieve_2).
- `FreeRoam.gd`: `var combat: PlayerCombat`, built in `_build_mayhem()` after the weapons and emotes.

**Global constraints.** Pure GDScript, Godot 4.7.2, CPUParticles3D only, code-drawn UI, Vietnamese text, no emoji or
decorative symbols (key glyphs only in control hints), fictional names, no gore (knockouts, stars, groans). No per-frame
allocation in the AI loops. Engine.time_scale only through the RadialWheel `scale_owner` protocol. Never stage `.import`.

---

## Task 1 – Data, poses, shared hooks

Files: create `scripts/combat/CombatData.gd`, `scripts/combat/CombatPose.gd`; modify `ThirdPersonController.gd`,
`WeaponDirector.gd`, `CharacterBuilder.gd` (as above).

Numbers (CombatData): player HP 100, regeneration 10 HP/s after 4 s without damage. Light combo jab / cross / elbow
(0.34 / 0.38 / 0.50 s, impact at 0.18 / 0.20 / 0.24 s, 8 / 10 / 14 damage, 16 / 20 / 30 stagger, chain after the impact,
combo forgotten 0.5 s after the last move). Heavy kick 0.72 s, impact 0.36 s, 18 damage, 40 stagger, 2.0 m reach, 70°
half arc, breaks blocks. Block: speed cap 1.2 m/s; perfect block = pressed at most 0.2 s before the hit lands, counter
12 damage + 45 stagger. Dodge: hostile within 6 m, 0.5 s roll at 6.5 m/s, 0.35 s invulnerable. Lock-on 7 m, 75° half
angle, 2.5 m any direction as a fallback. Finisher: dazed enemy within 2.2 m, 1.0 s, impact at 0.35 s, KO (Dolly: 35
damage + knockdown), slow motion 0.3 real seconds at time scale 0.3. Enemy: stagger meter full = daze 2.5 s; telegraph
0.5 s red flash, unblockable heavy; stagger 0.4 s (guard break 0.8 s); knockdown 1.2 s + getup 0.9 s.

Archetypes: `courier` (70 HP, blocks 30 %, 2-hit light chain, rider look with helmet), `clone` (45 HP, blocks 15 %,
identical student look), `dolly` (150 HP, fast, dodges 45 %, 3-hit chain, flees at 30 % HP, finisher does not KO).

## Task 2 – PlayerCombat + CombatHUD

Files: create `scripts/combat/PlayerCombat.gd`, `scripts/combat/CombatHUD.gd`.

Interface (`PlayerCombat`, Node):
- `setup(opts)`: `player` (ThirdPersonController, required), `weapons` (WeaponDirector, optional: sets its
  `unarmed_owner`, reuses its FX, cues, `hit_target` and `mayhem` heat), `targets_fn` (pedestrians + officers),
  `blocked_fn` (FreeRoam: the weapons' blocked lambda). Sets `player.jump_filter`.
- State `hp`, `max_hp`, `state` (IDLE, LIGHT, HEAVY, COUNTER, FINISHER, HITSTUN, DODGE, DOWN), `blocking`,
  `invuln_left`, `combo_i`, `lock` (current soft-lock target), `enemies` (registered by MeleeFight), `hud`.
- `add_enemy(e)`, `remove_enemy(e)`, `clear_enemies()`, `hostile_near(r) -> bool`, `lock_target() -> Node3D`,
  `finisher_target() -> Node3D`, `receive_attack(attacker, info) -> String` ("ignored" | "dodged" | "blocked" |
  "perfect" | "hit"), `revive(hp)`, `is_down()`, `try_dodge() -> bool`.
- Signals `down`, `hp_changed(hp)`, `attack_started(kind, target)`, `hit_landed(target, kind, result)`,
  `countered(enemy)`, `finisher(enemy)`, `mayhem(heat, at, cause)` (only without a WeaponDirector).
- Test hooks: `light_override`, `heavy_override`, `finisher_override` (one press each), `block_override` (held, Variant),
  `god` (no damage).
- Unarmed only: with a weapon in hand it stays idle (HP and `receive_attack` still work).

`CombatHUD` (CanvasLayer, layer 1): top-centre player HP bar ("Máu"), world-anchored enemy HP + stagger bars with the
label, a lock marker, a red telegraph ring, "[E] Hạ gục" over a dazed enemy in reach, centre popups (`popup(text)`:
"PHẢN ĐÒN", "Gét gô!", the force-unarmed line). Hidden unless a fight runs or HP < 100 (so `test_hud_bounds` and free
roam are unchanged); hidden while blocked (map, cinematic, bike).

## Task 3 – MeleeEnemy

File: create `scripts/combat/MeleeEnemy.gd`.

- `setup(archetype, opts)` before `add_child`: opts `body` (CharacterBuilder opts merged over the archetype look; rigged
  forced), `body_fn` (Callable(look) -> rigged Node3D, for masks / cardigans built elsewhere), `label` (name over the
  head), `stats` (overrides of archetype numbers), `seed`. `bind(combat, director)` after.
- States APPROACH, CIRCLE, ENGAGE, WINDUP, TELEGRAPH, ATTACK, RECOVER, BLOCK, DODGE, STAGGER, DAZE, KNOCKDOWN, KO, FLEE,
  FLED, HOLD (AI off), IDLE (fight over). Attack tokens from the director (`request_token` / `release_token`) from
  ENGAGE to the start of RECOVER.
- `take_strike(info) -> String` ("ignored" | "dodged" | "blocked" | "guard_break" | "hit" | "daze" | "knockdown" | "ko" |
  "flee"), `take_finisher(kind)`, `on_player_attack(kind, eta)` (block / dodge roll), `take_hit(info)` (Phase W duck
  type: a weapon knocks it down), `is_down()`, `is_hostile()`, `is_attacking()`, `is_dazed()`.
- Test hooks: `ai` (false = HOLD), `force_attack("light" | "heavy")`, `force_block(secs)`.
- Signals `ko(enemy)`, `fled(enemy)`. No per-frame allocation (sibling list shared by the fight).

## Task 4 – MeleeFight + FreeRoam wiring

Files: create `scripts/combat/MeleeFight.gd`; modify `FreeRoam.gd`.

API (documented at the top of the file; this is what the integration agent reads):
- `setup(opts)`: `roam` (FreeRoam: player, combat, weapons read from it) or `player` / `combat` / `weapons`;
  `force_unarmed` (default true: Tay không equipped, weapon wheel and scroll locked, the line "Nhiệm vụ này chỉ dùng tay
  không" on a try), `max_attackers` (2), `auto_checkpoint` (true: every wave start), `start_line` ("" or e.g. "Gét gô!").
- `add_wave(spawns)`: spawns = Array of {archetype, at (Vector3), yaw (optional), opts (MeleeEnemy opts)}.
- `start()`, `checkpoint()`, `retry()`, `stop()`, `alive() -> Array`, `attackers() -> int`, `state` ("idle" |
  "running" | "won" | "lost"), `wave`.
- Signals `won`, `lost`, `enemy_ko(enemy)`, `enemy_fled(enemy)`, `wave_started(i)`, `wave_cleared(i)`.
- A wave is cleared when every enemy is KO or fled; the last wave cleared = `won`; the player down = `lost` (enemies stand
  down). `retry()`: enemies freed, HP back to 100, the player at the checkpoint spot, the checkpoint wave respawned.

## Task 5 – Tests

- `tests/test_melee_combat.gd` (arena + FreeRoam): light combo jab / cross / elbow and its reset; heavy breaks a block;
  normal block (no damage, no counter) and perfect block ("PHẢN ĐÒN" counter); dodge-roll near a hostile (no jump,
  invulnerable, enemy hit dodged) and Space jumps when no hostile is near; stagger meter -> daze 2.5 s -> "[E] Hạ gục" ->
  finisher KO with 0.3 s slow motion and time scale back to 1.0; telegraph flash then an unblockable heavy through the
  block; at most 2 attackers among 5 clones; player down -> `lost`; `retry()` from the checkpoint (wave 2 after a
  checkpoint); force unarmed locks the wheel; Dolly flees at 30 %; WeaponDirector without an owner keeps the Phase W punch;
  in FreeRoam the combat is wired and the unarmed combo still knocks out a pedestrian (+1 heat).
- `tests/test_combat_perf.gd`: FreeRoam with the full crowd and traffic at BE6, a 3-courier brawl (AI on, player in god
  mode punching), combat cost < 3 ms per physics frame, median and 5 %-trimmed mean over 120 frames against a baseline with
  the fight and the combat disabled (method of `test_mayhem_perf`).
- Regression: `--check-only`, `smoke_all_stages`, `test_weapons_core`, `test_weapons_funny`, `test_weapons_guns`,
  `test_hit_reactions`, `test_free_roam`, `test_locomotion`, `test_locomotion_anim`, `test_emotes`, `test_hud_bounds`.

## Known limits (accepted)

- Enemies strafe with the forward Walk clip (slight foot slide while circling).
- Melee enemies are not Phase W weapon targets in FreeRoam (story fights force unarmed); `take_hit` exists for later.
- Police officers do not count as hostiles for the dodge (Space still jumps near them).
