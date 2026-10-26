# Story Phase C "Đấu súng trong hang ổ": Implementation Plan (gunfights + forklift boss)

Spec: `docs/superpowers/specs/2026-10-26-story-phase-c-days-2-3-5-design.md`, decision **C-D2**, the Day 3 forklift boss
of **C-D4**, and their tests from **C-D13**. Branch `phase-c-guns`, base 291b403. Bike combat, sword duels, cinematics,
the lair levels and the Day 3 / Day 5 story wiring are other agents' work: this branch never touches a story file or a
timeline. Gunmen and Alexander get their looks as CharacterBuilder opts or a `body_fn`; StoryCast gets the official looks
later.

**Goal.** Lair gunfights with the Phase W pistol and shotgun (cover, player HP, enemy gunmen with readable telegraphs, ammo
pickups) behind one encounter node `GunFight` that the integration agent drives, plus the Day 3 forklift boss Alexander.

## Architecture (all new code in `scripts/combat/guns/`)

| File | Role |
|---|---|
| `GunData` (static) | every number (cover, gunman senses / accuracy / timings / damage, boss), the Vietnamese texts, the code poses (crouch behind cover, pistol aim, seated driver, name speech) |
| `GunPose` (Node, process priority 12) | one GunData pose laid over a rigged body with an eased weight (the CombatPose pattern, own library) |
| `CoverMap` (RefCounted) | cover slots from level data: `add_box(xf, size)` (low boxes only), `add_marker(pos, normal, h)`, `scan(root)` (nodes in group `cover`: box colliders or markers); queries `nearest`, `protects`, `best_against`, `flank_slot` |
| `PlayerCover` (Node) | hold Ctrl near a slot: crouch behind it (movement locked, body faces the obstacle); aiming or firing pops out (exposed); release Ctrl / jump / knock-down leaves |
| `Gunman` (Node3D, no physics body, like HorrorStalker) | patrol -> alert (see / hear) -> take cover -> peek and shoot (glint telegraph 0.4 s before the bullet resolves, readable tracers) -> flank; stagger, KO with stars; never shoots without a clear ray; shooting tokens |
| `AmmoPickup` (Node3D) | code-built ammo box; walking over it adds spare rounds |
| `GunHUD` (CanvasLayer) | plain text: HP, enemies left, wave, damage-direction arcs, cover prompt, popups, the boss bar |
| `GunFight` (Node3D) | the encounter API (below) |
| `Forklift` (CharacterBody3D) | code-built forklift (chassis, counterweight, wheels, mast, sliding carriage and forks, overhead guard, seat, beacon) with drive physics (throttle, rear-wheel steering, crash detection), fork lift, and a pendulum topple |
| `ForkliftBoss` (Node3D) | Alexander on the forklift: charge (telegraphed), crate toss (shadow telegraph), recover / overheat = vulnerable, name intro refill (max 2), topple -> KO; signals |
| `GunAudio` (static) | three synthesized SFX (forklift horn, engine rev, steam hiss); no music |

**Player HP choice.** The gunfight shares PlayerCombat's HP (100, 10 HP/s regeneration after 4 s, `down`, `revive`):
one HP pool and one death flow for every story fight, and FreeRoam already owns a PlayerCombat. Bullets and boss hits go
through `PlayerCombat.receive_attack` (bullets light, boss charge / crate heavy = knock-down). GunFight builds its own
PlayerCombat when the scene has none (as MeleeFight). While a GunFight runs it sets `combat.fight_active` (no bike, no
emotes) and hides the CombatHUD HP bar: GunHUD shows the HP instead.

**Weapons in a lair.** GunFight forces the loadout (default pistol + shotgun, the first equipped, magazines full), locks the
funny weapons (rocket, dép, sầu riêng, loa; with `force_loadout` everything but the loadout and Tay không), gives finite
spare rounds (default 48 pistol / 12 shotgun), cuts the wanted heat (the WeaponDirector `mayhem` -> WantedDirector link is
disconnected during the fight) and adds its enemies to the weapons' and the combat's targets (wrapped `targets_fn`). All
of it is restored when the fight ends, stops or is freed.

## Shared files (surgical edits)

- `ThirdPersonController.gd`: `move_lock` (no walking input while true; PlayerCover).
- `weapons/WeaponDirector.gd`: `reserve` (finite spare rounds per slot, empty = unlimited as before; reload draws from
  it; `ammo_text` shows "12 / 36"), `add_reserve(slot, n)`, `set_locked_slots(slots, text)` (equip refuses, scroll skips,
  the wheel greys them).
- `weapons/RadialWheel.gd`: a disabled slot shows its own `off_text` (default "Sắp có").
- FreeRoam: no edit (GunFight reads `player`, `combat`, `weapons`, `wanted`, `mounted`, `story_roam` from it).

## GunFight API

`setup(opts)`: `roam` (or `player`, `combat`, `weapons`), `cover` (CoverMap) or `cover_root` (scan), `nav`
(HorrorNavGraph, optional detours), `loadout`, `force_loadout`, `lock_funny`, `reserve`, `max_shooters` (3),
`auto_checkpoint`, `start_alerted`, `seed`. `add_wave(spawns)`: gunmen `{"at", "yaw", "patrol", "opts"}` (opts: `body`,
`body_fn`, `mask`, `label`, `hp`, `accuracy`, `ai`), the boss `{"boss": "forklift", "at", "yaw", "opts"}`.
`add_ammo(pos, slot, amount)`. `start()`, `checkpoint()`, `retry()`, `stop()`. Signals `won`, `lost`, `enemy_ko(e)`,
`wave_started(i)`, `wave_cleared(i)`, `boss_spawned(boss)`, `player_hit(source, damage)`. State `idle / running / won /
lost`, `wave`, `alive()`, `shooters()`, `boss`.

## ForkliftBoss API

Signals `phase_changed(old, new)`, `charge_started(dir)`, `crashed`, `crate_tossed(target)`, `crate_landed(pos, hit)`,
`vulnerable_changed(on)`, `name_intro(count)`, `hp_changed(hp, max)`, `toppled`, `ko(boss)`. `force_attack("charge" |
"toss")`, `vulnerable()`, `hp`, `max_hp`, `name_intros`, `heat`, `state_name()`.

## Tasks

1. Plan (this file). Commit.
2. GunData, GunPose, CoverMap, PlayerCover, GunAudio; the three shared edits.
3. Gunman, AmmoPickup, GunHUD, GunFight.
4. Forklift, ForkliftBoss (boss bar in GunHUD).
5. `tests/test_gunfight.gd`: cover enter / exit / pop-out; enemy state chain; telegraph >= 0.4 s before every damage;
   no shots through a wall (and a duck during a telegraph stops the bullet at the cover); at most 3 shooters; HP
   regeneration after 4 s and down -> `lost`; KO by the player's pistol; ammo (finite reserve, reload, pickup); retry from
   the wave-2 checkpoint; loadout lock; forklift phases (charge tell -> charge -> crash -> vulnerable recover, crate shadow
   before the landing and its damage radius, immune outside the windows, name refill capped at 2, topple -> `won`).
6. `tests/test_gunfight_perf.gd`: a test arena with cover boxes, 8 gunmen alert and shooting (plus a queued wave), the
   player in cover popping out; the fight's cost < 3 ms per physics frame (median and 5 %-trimmed mean, the
   test_combat_perf method).
7. Run the new tests, `--check-only`, smoke, `test_weapons_*`, `test_hit_reactions`, `test_melee_combat`,
   `test_free_roam`, `test_mayhem_perf`. Commit.
