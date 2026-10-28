# Quality overhaul, Days 3/5 wow, and Phase D: master plan

Date: 2026-10-29.

**Status:** plan written. Execution starts on the owner's go (the quota timing is in section 6).

This plan supersedes the "Execution plan" part of `2026-10-27-phase-c-wow-days-3-5-design.md`. Its decisions D3W-* and D5W-* and the shared items W-* stay valid and are folded in here as Wave 3.

## 0. Owner feedback and constraints

**Feedback (2026-10-29):**
- "phase vừa rồi với tôi khá thất vọng". Asked what disappointed most, the owner picked all four:
  - it looks ugly, and the camera angles are poor;
  - it plays dull, easy and repetitive;
  - fighting and shooting don't feel satisfying;
  - the story and cinematics don't pull them in.
- The owner has played the new Day 2 (Tokyo Drift): "vẫn chưa đã". The weak points:
  - fighting on the bike is not satisfying;
  - it looks ugly, and the camera is poor;
  - the road events and the drift duel are not fun.
- The sense of speed was not criticised.

**Process rules from the owner:**
- **No agent screenshots or preview renders** ("tôi tự test"). Visual quality must be secured by rules, reference values and automated framing checks (Q1), not by images. If the owner sends screenshots of what looks bad while playing, they are welcome input.
- **Build everything, then the owner plays once at the end** ("tôi có nhiều việc khác cần làm"). No mid-way playtest gates. Reviews and tests replace them.
- All earlier project rules stand: no code music, no emoji, owner audio local only, no gore, fictional names, no push, never stage `.import`.

## 1. Why the last phases disappointed

1. **Nobody looked at the game before the owner did.** Agents verified with headless tests and perfect bots: correct code, unseen results.
2. **Too wide, too thin.** Each phase stacked 3-4 new systems, each built in hours.
3. **Perfect bots tuned the difficulty**, so play was easy and predictable.
4. **Feel ("juice") was an afterthought:** small impacts, few reactions, flat sound.
5. **Cinematics** lean on long dialogue and code-animated actors with little camera language.

## 2. The quality bar

From now on, every mission, old and new, must meet this checklist. Reviews check it item by item.

1. **One signature moment per mission**, built deep: a spectacle the player remembers. Everything else reuses existing systems.
2. **Something new every 15-20 s:** a new enemy kind, an event, a location change, a joke.
3. **Readable:**
   - every hazard has a telegraph of at least 0.5 s with colour and sound;
   - big events get a 0.6 s "preview cut" camera showing the hazard ahead;
   - the objective is always on screen.
4. **Feel:** every hit and impact passes the Q2 impact recipe. Every knockout of a last enemy gets slow motion with a camera move.
5. **Camera:** the Q1 camera director is used, and the framing tests pass.
6. **Look:** the scene uses a Q3 look preset (lighting, grading, fog, emissive glow), and enemies pass the readability rule.
7. **Difficulty:**
   - tuned against the "sloppy bot" (Q6), not the perfect bot;
   - Thường is hard: a first run fails 1-3 times;
   - Dễ exists;
   - retries are instant from a fair checkpoint.
8. **Music** plays during the gameplay itself, not only in replays.
9. **Story beats:** dialogue scenes are at most 30 s and each has a joke beat; long talk becomes radio chatter during gameplay.

## 3. Phase Q: quality overhaul of what exists (Days 0-5 and free roam)

### Q1 Camera director

New `scripts/camera/CameraDirector.gd`, plus helpers. One place owns every gameplay camera. Existing cameras (ThirdPersonController, PlayerBike chase cam, combat, gunfight, chase takedown cam) move onto it or follow its rules.

**On foot:**
- shoulder offset 0.45 m right, distance 3.2 m, height 1.55 m;
- critically damped spring follow;
- a SpringArm-style collision pull-in;
- look-ahead 0.8 m in the move direction;
- sprint FOV +6;
- a small landing dip.

**Melee and sword combat:**
- soft-lock framing on a point 70/30 between the player and the current target;
- the distance grows from 3.5 to 6.5 m with the number of enemies within 8 m;
- auto-yaw keeps the target and the next attacker in view, never turning faster than 90°/s;
- the camera never ends inside walls.

**Bike:**
- a low chase cam: height 1.35 m, distance 3.8 m at rest rising to 5.2 m at top speed;
- FOV 70 → 86 with speed, +8 with nitro;
- roll follows the lean at 30 %;
- in a drift, the camera swings 12-18° to the outside so the bike's side shows;
- kick hits get a quick 0.12 s whip toward the target;
- road shake grows with speed, kept small;
- takedown cams pick from 3 candidate angles by occlusion test.

**Shared:**
- `punch(strength, dir)` for impact kicks;
- `shake(trauma)` with a trauma-squared falloff;
- `preview_cut(target, secs)` for the readability rule;
- `slowmo_orbit(target, secs)` for last-enemy knockouts.
- All slow motion goes through the existing `RadialWheel.scale_owner` rule.

**Cinematic shot helpers:**
- two-shot, over-the-shoulder, low hero angle, dutch angle for villains, and a push-in;
- CinePlayer timelines may name these shots instead of raw transforms.

**Automated framing tests**, headless with `Camera3D.unproject_position` plus raycasts:
- for sampled gameplay situations across the map (on foot, combat, bike, takedown cams) and for every cinematic shot, the subject's head and torso are inside the frame's safe area (8 % margins);
- the line of sight to the subject is not blocked;
- the camera is not inside geometry;
- in combat, the target and the player are both in frame.

These tests are the substitute for screenshots.

### Q2 Combat feel

One shared impact recipe: `scripts/combat/Impact.gd`.

| Tier | Hit-stop | Camera punch | Target reaction | Particles | Sound layers |
|---|---|---|---|---|---|
| light | 40 ms | 0.15 | directional flinch | dust puff | whoosh + thud |
| heavy | 80 ms | 0.35 | stagger + 1.5 m knockback | dust ring and sparks | whoosh + thud + body + a short crowd "ồ" |
| finisher | 150 ms | 0.6 | comic flying tumble with a spin and a floor bounce, stars | big ring, sparks, debris | all layers + a meme sting |

All sound is synthesized SFX. A last-enemy knockout adds a 0.5 s slow-motion orbit.

**Melee (Days 1, 4, 5 and later):**
- environmental slams: a hit near a wall, table or car slams the enemy into it (heavy tier);
- throws;
- improvised weapons picked up with [E]: chair, tray, helmet, trash-can lid; each has 3-5 hits and breaks comically;
- this is the "Nobody" style the owner chose for the cinematics, brought into gameplay;
- varied hit reactions from the UAL clips, directional.

**Bike:**
- **A kick that connects:**
  - hit-stop, camera whip and punch;
  - the target bike veers on a wobble curve while the rider flails;
  - it crashes into a tumble, with parts flying (mirror, helmet) and the bike sliding with a spark trail;
  - the player's bike gets a small kick-back.
- **Counter-kick:** pressing the kick toward an attacker in his last 0.25 s before his hit lands a "PHẢN ĐÒN!": a short slow motion, the attacker sent flying.
- **Grab weapon:** kicking a stick rider can drop his stick. Riding over it picks it up, giving 3 swings on Q/E with a longer reach.
- **The spin kick** gets a motion-trail arc and a heavier hit.
- **Hits on the player:** a red screen-edge flash, a camera jolt and a bike wobble.

**Guns:**
- camera recoil kick;
- a muzzle flash with a 1-frame light;
- visible tracers;
- surface impact puffs and sparks, pooled decals;
- an enemy flinch on every hit, and a hat or mask flying off on the knockout;
- hit markers with sound.

**Swords:**
- sparks on every clash;
- a parry gives hit-stop plus a camera punch and a clear "keng";
- heavy thrusts push back.

### Q3 Look

**Look presets** (`scripts/LookPresets.gd`), applied per scene and mission on top of ViceStyle and GameFX quality levels, without breaking the PS2 art direction. Each preset sets:
- the environment tonemap exposure, glow strength and threshold for emissives, fog colour and density, and colour adjustments (contrast, saturation, tint);
- key and fill lights where the scene owns them.

| Preset | Used for | Look |
|---|---|---|
| `night_city` | free roam at night, Day 2 | warm sodium lamp pools, glowing neon signs, wet-road sheen, light haze |
| `tokyo_drift` | the Day 2 chase and duel | cyan and magenta neon grading, strong glow on headlights and LED eyes |
| `port_night` | Day 3 | orange sodium floodlights, sea haze, container colours |
| `server_red` | Day 5 | red emergency light and blue screen glow |
| `canal_night` | Day 6 | water reflections, festival lights |
| `penthouse` | Day 7 | gold and black, dramatic contrast; the blackout uses only the flashlight and lightning |
| `campus_day` | Days 1 and 4 | warm sun, soft shadows, a slight bloom |

**Readability:**
- enemies and interactables get a subtle fresnel rim shader (enemy red-orange, pickups yellow), toggleable in settings;
- telegraphs are larger and coloured: red is danger, yellow is a pickup or prompt, cyan is a drift or nitro zone.

**VFX library** (`scripts/fx/`):
- sparks, dust, smoke, debris chunks;
- speed lines, a nitro flame, a water splash, a fire, sprinkler rain;
- all CPUParticles3D, pooled, with budgets.

**Night roads** get emissive lane markings and street-lamp light pools (shared materials, no per-lamp lights beyond a small near-player pool).

**Perf:** the physics gates stay under 3 ms. Render cost is kept down by budgets (particle counts, glow on a quality setting), and the GameFX quality levels gate the heavier effects.

### Q4 Encounter rework of what exists

**Day 2 drift duel: replace it.** The owner found the points and gap rules not fun, and the course on open ground with cones confusing.

The new duel is **"đua + đánh"**:
- a straight race to the finish on real, lit roads;
- neon arches and arrows mark the course, and the Bầy Sói pack lines it, cheering, with flares;
- 2 laps of about 1.2 km;
- Sói Xám rides aggressively: he kicks, blocks and uses nitro;
- the player can kick him: 3 kicks make him wobble and lose speed for 2 s;
- drift corners charge nitro;
- the finish line on the bridge has fireworks;
- lose = quick retry.

**Day 2 events: make them spectacles, with a preview cut each.**

| Old | New |
|---|---|
| watermelon truck | the truck tips over in slow motion and 100 melons roll |
| barrier | a crane lowers a steel beam with sparks; [CTRL] ducks under it |
| sand ramp | a real jump over a broken road gap with a cinematic slow-motion cam |
| police joining | a police roadblock ahead that the player must thread through a gap |

The Q2 bike combat upgrades (counter-kick, grab weapon) are added to Day 2.

**Days 1 and 4 melee encounters:**
- environmental slams, throws and improvised weapons (Q2);
- arenas dressed with slam-able props;
- each brawl gets one escalation beat, e.g. the canteen brawl's food fight with trays as weapons.

**Free roam:** night street-lamp pools and the look presets.

### Q5 Story and cinematics

**Dialogue voices:**
- synthesized gibberish blip voices, one timbre per character (Mr.T, Phúc, Linh, Anh Duy, each villain);
- subtitles type out letter by letter in sync;
- no real voices.

**Pacing:**
- every dialogue cinematic is cut to at most 30 s;
- information moves to radio chatter during gameplay;
- every scene has one joke beat.

**Camera language:** cinematics use the Q1 shot helpers; villain cards and reveals use push-ins and dutch angles.

**Acting:** gestures from the UAL clips (pointing, facepalm, shrug, laughing) are added to the talking actors.

**Skip:** every cinematic can be skipped with a hold of [ESC] or [ENTER] (check it exists; add it if not).

**Hooks:** each day ends on a cliffhanger line and a sting.

### Q6 Difficulty and tuning

**The "sloppy bot" standard** for every tuning test:
- 250-400 ms reaction delay;
- 15 % wrong or late inputs;
- it does not read telegraphs perfectly;
- it hits traffic sometimes.

Targets on Thường: the sloppy bot fails 1-3 times per mission and still finishes within 5 retries. On Dễ: at most 1 fail.

**Difficulty setting** (W-2): Thường (default, hard) and Dễ, through one table `scripts/combat/Difficulty.gd`.

## 4. Wave 3: Days 3 and 5 wow (from the 2026-10-27 spec)

From `2026-10-27-phase-c-wow-days-3-5-design.md`, built on the Q1-Q3 base:
- **Day 3:** D3W-1 mannequin disguise, D3W-2 container crane, D3W-3 forklift joust.
- **Day 5:** D5W-1 burning server countdown, D5W-2 blackout, D5W-3 katana under the sprinklers with a QTE.
- **Shared:** W-1 bullet time, W-3 ranks S/A/B/C (W-2 difficulty moves into Q6).

## 5. Phase D upgraded: Days 6 and 7, endings, free-roam activities

### Day 6 "Trà Sữa Lọ"

**Shipper infiltration:**
- The player takes orders in the Trà Sữa Lọ shop as a fake delivery rider: a fast, funny order-matching mini-game with cups, toppings and a timer, with customers in sheep masks.
- Serving well raises "trust" and opens the back door.

**Back room** (horror beat):
- sheep dolls on shelves and a music box;
- when it plays, the dolls turn to face the player;
- the mirror figure turns out to be Thị Lọ doing her make-up: "Gì?".
- The player steals the ledger (E7).

**Caught:** "Còn cái nịt" when the cash is seized. Escape to the canal.

**Signature: the speedboat chase** on the Rạch Hầm canal at night:
- the player drives a boat chasing Thị Lọ's boat;
- Bầy Sói jet skis come alongside, and kicks work on water (the bike combat on a water vehicle);
- low bridges need [CTRL] to duck;
- a ramp off a moored sampan jumps a bridge pier, with a cinematic cam;
- a fishing-net trap must be swerved;
- a fireworks barge lights the sky;
- her Titanic pose on the bow is the meme beat;
- the finish: ram her boat into the bank.
- New code: a code-built boat and a water surface strip with waves and spray.

**Choice 3** (take or refuse the bribe) on the bank. Then AI clip #2 `ai_reveal`, with its in-engine fallback.

### Day 7 "Học thật, đậu thật"

**An 08:00 countdown** on the HUD for the whole day: generous, but always visible, for pressure.

**Tower assault** up the Lọ Academy building. Each floor has its own gimmick and a returning villain (short remixes of earlier systems, about 1 minute each):
1. **Parking deck:** Sói Xám's revenge, a bike duel in tight spirals.
2. **Warehouse floor:** Alexander on a forklift, with crates.
3. **Server floor:** Za Mẫn with a new, even cheaper katana.
4. **Mannequin floor:** a stealth corridor.
5. **Vase gallery:** laser tripwires.

Anh Duy is on the radio throughout.

**Final boss Lùm Văn Lọ:**
- **Phase 1:** a gunfight in the vase gallery. Vases shatter and the cover crumbles.
- **Phase 2:** blackout with the flashlight. His voice comes from every speaker and vases crack one by one (horror).
- **Phase 3:** a saber duel on the rooftop in the rain, with the helicopter's searchlight.
- **Finisher:** a QTE into the Vovinam scissor-kick takedown "Đòn chân kẹp cổ số 21".
- **"Xin vĩnh biệt cụ"** on his defeat.

**Stop the mass cheat:** a typing showdown on the exam server while Anh Duy deploys, before 08:00.

### Endings

- All 6 endings (A-F, story spec section 6), each with its own cinematic. The A-F conditions in section 6 decide which one plays.
- An end summary screen shows the choices made, the evidence found (E1-E7) and the ranks.
- Chọn cảnh gains an ending gallery.

### Free-roam activities

These reuse existing systems, so the world between missions isn't empty.

- **Street drift races:** 3 routes at night, using the Day 2 duel tech.
- **Takedown challenges:** knock off N gang riders before the time runs out.
- **Delivery runs:** a timed shipper job across the map.
- **Vovinam street fights:** waves of thugs in an alley, using the Q2 melee.
- **Rewards:** helmet and rider-jacket colours (plain names, no brands), and the S rank count.

### Night events

Night events from the story spec section 5 give second chances at optional evidence: the canal ghost boat, and the BE6 lift stopping at floor 13.

### Music

New slots with suggestions for the owner (owner files, silence without them):

| Slot | Suggestion |
|---|---|
| `mission_boat` | "Danger Zone" – Kenny Loggins |
| `mission_shop` | "Barbie Girl" – Aqua |
| `mission_tower` | "Thunderstruck" – AC/DC |
| `boss_d7` | already present |
| `side_drift` | "Night of Fire" – Niko |
| `side_delivery` | "Running in the 90s" – Max Coveri |

The rest follow the story spec section 8.3. Add them to `docs/cinematics/music_to_download.md`.

## 6. Execution

Each wave runs in parallel git worktrees from the current main, with:
- one implementer per stream;
- one read-only review per stream (effort high), then a fix round;
- an integration branch;
- the full regression, plus the perf gates on AC power;
- a merge into main with `--no-ff`.

Agents follow `scratchpad/agent_rules.md`, the quality bar (section 2) and the no-screenshot rule.

| Wave | Streams (effort) | Rough quota |
|---|---|---|
| 1. Phase Q base | Q1 camera director (xhigh); Q2 combat feel (xhigh); Q3 look presets, VFX library, readability (high) | about 12-15 % |
| 2. Phase Q content | Q4 Day 2 rework (xhigh); Q4 Days 1/4 melee and props (xhigh); Q5 story and cinematics, with Q6 difficulty and the sloppy bot (high) | about 10-12 % |
| 3. Days 3 and 5 wow | three streams as in the 2026-10-27 spec (xhigh) | about 10-12 % |
| 4. Phase D | Day 6 boat and shop (xhigh); Day 7 tower and final boss (xhigh); endings, summary, gallery, free-roam activities, night events (high) | about 25-30 % |

**Total:** about 60-70 % of one weekly quota.

**Interfaces fixed before Wave 1 starts:**
- Q1 provides `CameraDirector.punch / shake / preview_cut / slowmo_orbit`;
- Q2 consumes them through `has_method` guards;
- Q3 provides `LookPresets.apply(name)` and the `scripts/fx/` pool API.

**Owner involvement:** none until the end. When everything is merged, Claude sends one report: what changed, how to test, the known gaps. The owner then plays the whole game.

**Quota timing:**
- Weekly usage was 80 % on 2026-10-28, with the reset on 2026-10-29 at 13:59 UTC.
- The owner needs quota for work.
- Start Wave 1 after the reset, unless the owner says to start now within a cap.
- Re-check usage before every dispatch, and stop dispatching at the owner's cap.
