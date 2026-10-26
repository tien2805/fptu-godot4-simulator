# Phase C "wow" pass, Days 3 and 5 plus shared items: design and plan

Date: 2026-10-27.

**Status: PLANNED, NOT STARTED.** Start only on the owner's word, after the Day 2 redesign (`2026-10-27-day2-tokyo-drift-design.md`) has merged and the owner has playtested it, so its lessons carry over.

**Owner feedback:** Phase C is "dễ và nhàm chán", not "wow" enough.

**The owner picked every idea below:**
- Day 3: mannequin disguise, container crane, forklift joust.
- Day 5: burning server countdown and blackout, katana under the sprinklers.
- Shared: bullet time, a harder default with an "Dễ" mode, S/A/B ranks.

**Reused from Day 2:** the takedown slow-motion helper, the time-scale safety rules, and the tuning by test bots.

## 0. What is weak now

**Day 3 (container yard):**
- The sneak is a plain walk past guards.
- The gunfight is 2 waves of identical gunmen (60 HP, 0.4 s telegraph).
- The forklift boss is hit-and-wait.
- Nothing in the level is interactive.

**Day 5 (server basement):**
- Stealth, a gunfight, typing and the katana duel run one after another, with no pressure tying them together.
- The katana duel has a single arena look all the way through.

**Everywhere:**
- There is one difficulty, and it is too easy for the owner.
- There is no reason to replay.

## 1. Shared decisions

### W-1 Bullet time

**Trigger:** in lair gunfights, Space while aiming (RMB held) starts a dive (Max Payne homage, no shot copies).
- The player dives in the move direction.
- 1.2 s at 0.35× time, with aim and fire at normal speed.
- The player lands prone for 0.4 s and gets up.

**Focus bar:**
- 100 max; a dive costs 50.
- Refills 5 per second, and +20 per knockout.

**Effects:**
- enemy telegraphs and bullets slow with the world;
- the music gets a low-pass filter during the dive (bus effect, no new music);
- a grey-blue tint and a heartbeat SFX.

**Safety:** the time scale is restored on retry, lost, exit and scene change, under the same rule as D2X-3.

### W-2 Difficulty

**Levels:** a setting "Độ khó: Thường / Dễ" in the main-menu and pause settings, stored with the other GameFX settings.
- **Thường** is the new default and harder than today.
- **Dễ** is roughly today's values.

**Code:** one static table, `scripts/combat/Difficulty.gd`. Each system reads its numbers through `Difficulty.value(key)`, so there are no scattered ifs.

| System | What scales |
|---|---|
| Bike chase | attackers at once, damage, wave sizes. Day 2's tuned values become Thường. |
| Gunfights | waves (Thường 3, Dễ 2), shooters at once (4 / 3), telegraph (0.35 s / 0.45 s), regeneration delay (5 s / 3 s) |
| Melee and bosses | boss HP and damage, telegraph time |
| Stealth | guard sight distance and reaction time |

The "Giảm hù dọa" setting stays separate.

### W-3 Ranks S/A/B/C

**When:** after every mission of Days 1-5, a results card shows before the replay or the next beat.

**Scoring:** criteria per mission: time, takedowns or knockouts, damage taken, retries, and optional objectives. The thresholds live in data per mission id.

**Storage and display:**
- The best rank per beat goes into the story save (old saves load with no ranks).
- Chọn cảnh shows the best rank next to each beat.

Plain text, no emoji or star glyphs.

## 2. Day 3 decisions

### D3W-1 Mannequin disguise

**Place:** in the sneak, after the mannequin container is revealed (the `cine_d3_mannequins` discovery may move earlier, into the sneak). Alexander's guards sweep the mannequin area for the intruder.

**Hiding:**
- The player stands among about 40 mannequins in smart glasses.
- Hold [X] to freeze in a mannequin pose ("ĐỨNG IM!").
- The telegraph is footsteps plus a flashlight sweep.
- Moving or not frozen inside a guard's light starts the gunfight early (no instant fail).

**Horror-comedy beats** (softened by "Giảm hù dọa"):
- now and then a mannequin turns its head when the player is not looking;
- once, a "mannequin" is a guard in disguise: a v2 jump scare, then a melee scuffle.

**Meme:** a guard's phone plays a meme slot `meme_mannequin` while he checks the line-up. Suggestion: "Black Beatles" – Rae Sremmurd, the Mannequin Challenge song. Owner file only; silent without it.

### D3W-2 Container crane

**Where:** in gunfight wave 2, a gantry crane cabin reached by a ladder.

**Controls in the cabin:**
- WASD moves the trolley and hook;
- [E] drops a container, 3 drops in all.

**Effects:**
- A container dropped on guards knocks them out, with dust and stars.
- Dropped in the open, it becomes new cover (CoverMap updated).
- In the boss fight, one drop on Alexander's forklift skips a phase.

**Fairness:** guards shoot at the cabin, so staying in it has a cost.

### D3W-3 Forklift joust

**Setup:** the boss fight becomes a vehicle duel, with the player in a forklift too. Enter with [F].
- The forks raise and lower.
- A ram from the side or back while his forks are up (telegraphed) does big damage.
- Dodge his charges.
- Lift his dropped crates and throw them back.

**Kept:** the endless-name refill meme. His forklift topples at 0.

**Also:** a "pallet shield" guard type in Day 3 waves, who blocks from the front and must be flanked.

## 3. Day 5 decisions

### D5W-1 Burning server countdown

**Setup:** the typing battle (`MissionHack`) runs while the server room burns.
- A 90 s countdown until the fire-suppression gas fires.
- Guards breach at 30 s and 60 s. The player must leave the terminal and fight; typing progress pauses and does not decay.
- Smoke and fire are CPUParticles3D, pooled.

**End:**
- Typing finished before 0: win.
- At 0: retry from the start of the typing.

**Music:** slot `mission_fire_hack`, suggestion "Disco Inferno" – The Trammps. Owner file; silent without it.

### D5W-2 Blackout

**When:** in the stealth part, the power cuts at a scripted point.

**In the dark:**
- Only the monitors and the guards' smart-glasses LEDs glow, so the player sees guards by their LEDs.
- Guards see the player only in their own flashlight cones, and the player has the [F] flashlight (horror toolkit).
- Za Mẫn's face flickers on the monitors, whispering. The whisper is a synthesized SFX, and he speaks no real voice.

**End:** power returns after the player reaches the control room.

### D5W-3 Katana under the sprinklers

**At 50 % boss HP:**
- the sprinklers start: water particles and red emergency light;
- puddles make dodges slide further;
- a rain-like SFX plays.

**Kept:** the katana still bends at 33 %.

**At 0 HP, a QTE finisher:**
- 3 prompts in a row ([Q] gạt, [Chuột trái] chém, [E] hạ gục), each with a 0.9 s window;
- slow motion and code-driven cinematic cameras.

**A missed prompt:** he recovers 10 % HP and the QTE comes again at 0.

## 4. Execution plan

**Prerequisite:** Day 2 is merged, and the owner has played it and agreed.

### Wave 1: three parallel worktrees from main

**Agent S "wow-shared"** (xhigh): W-1, W-2, W-3.

*Owns:*
- `scripts/combat/guns/` (GunFight, Gunman, PlayerCover, GunHUD, GunData);
- the player aim and weapon code where the dive hooks in;
- new `scripts/combat/Difficulty.gd` and new `scripts/story/StoryRank.gd`;
- the settings UI (main menu and pause), the story save rank field, and the chapter-select rank display;
- tuning reads in `BikeChase` / `BikeCombatData`, `MeleeFight` / `CombatData` and the horror sight values.

*Interfaces it provides:*
- `Difficulty.value(key) -> float`
- `StoryRank.report(mission_id, stats: Dictionary) -> String`
- `GunFight.set_time_scale_safe(...)`, if needed

**Agent D3 "wow-day3"** (xhigh): D3W-1, D3W-2, D3W-3.

*Owns:*
- the yard level and the sneak (`MissionSneak`, the yard builder);
- the mannequin cast use;
- new `Crane.gd`;
- `Forklift.gd`, `ForkliftBoss.gd` and `MissionForklift.gd`;
- the Day 3 beats in StoryMissions (Day 3 entries only).

*Rule:* it uses GunFight only through its public API (`add_wave`, `checkpoint`, signals, CoverMap add).

**Agent D5 "wow-day5"** (xhigh): D5W-1, D5W-2, D5W-3.

*Owns:*
- `StoryBasement.gd` (blackout, fire, sprinklers);
- `MissionHack.gd` (countdown and breaches);
- `SwordDuel.gd`, `KatanaBoss.gd` and `SwordData.gd` (sprinkler phase, QTE);
- the Day 5 beats in StoryMissions (Day 5 entries only).

*Rule:* it uses GunFight only through its API.

### Then

- **Conflicts:** StoryMissions entries are split by day (resolved at merge); `test_story_day3` belongs to D3 and `test_story_day5` to D5.
- **Order:**
  1. One read-only review per branch (effort high), then one fix round.
  2. Merge all three into branch `wow-c`.
  3. Run the full regression, plus the perf gates on AC power with no other Godot test running.
  4. Merge into main with `--no-ff`.
- **Tests:**
  - new: `test_difficulty`, `test_story_rank`, `test_bullet_time`, `test_crane`, `test_forklift_joust`, `test_mannequin_hide`, `test_basement_fire`, `test_katana_qte`;
  - updated: `test_gunfight`, `test_sword_duel`, `test_story_day3`, `test_story_day5`, `test_chapter_select`;
  - perf: the lair gunfight with bullet time, the basement fire and the sprinklers, all under 3 ms.
- **Music slots** (owner files, suggestions to add to `docs/cinematics/music_to_download.md`):
  - `meme_mannequin`: "Black Beatles" – Rae Sremmurd;
  - `mission_fire_hack`: "Disco Inferno" – The Trammps.
- **Rough cost:** about 10-12 % of the weekly quota, with three xhigh agents, three reviews and one fix round.
