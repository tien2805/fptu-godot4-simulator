# Phase W: Weapon Wheel, Weapons and Wanted Level – Design

Date: 2026-10-23. Status: design approved by the owner in chat (AskUserQuestion); spec pending owner review. Runs after story Phase A1 (cinematics) and before A2 (story framework). Own implementation plan, branch `phase-w`. Implemented on branch phase-w (plan docs/superpowers/plans/2026-10-24-phase-w-weapons-wanted.md).

## 1. Owner decisions

| ID | Decision |
|---|---|
| W-D1 | GTA-style radial weapon wheel: **hold the middle mouse button**, move the mouse toward a slot, release to equip (owner: "menu chọn vũ khí hình tròn, mở bằng cách bấm chuột giữa, đưa chuột về hướng vũ khí muốn chọn"). While the wheel is open the game slows to 0.2×. Mouse wheel scroll cycles weapons without opening it. |
| W-D2 | Weapons work **everywhere in the open world, campus included** ("Kiểu GTA, mọi thứ ở mọi nơi"). This replaces story spec S-D5's "gunfights only inside the lairs; on campus only unarmed Vovinam" and its tone rule "no guns on the FPTU campus" (amended there). |
| W-D3 | Still **no blood, no gore, nobody dies**: people hit are knocked out with comic stars, get up 6-10 s later and flee; vehicles hit by explosions flip and smoke, the rider runs away, the wreck is recycled later. |
| W-D4 | Eight slots: unarmed, knife, pistol, shotgun, rocket launcher, and the owner's three funny weapons: **dép tổ ong boomerang**, **sầu riêng stink bomb**, **loa kẹo kéo** (sonic blast). |
| W-D5 | Loa kẹo kéo plays a synthesized bolero cue by default. The owner wants it to blast songs by a real Vietnamese singer: copyrighted music by a real person is never committed, shipped or named in game text; the owner drops his own file at `user://sfx/loa_keo_keo.ogg` or `.mp3` (git-ignored, never exported), same rule as the owner music slots (story spec S-D10). |
| W-D6 | **Wanted level**, 1-3 stars ("phương án B"). Mayhem raises heat; officers chase; escaping their sight long enough lowers the stars. |
| W-D7 | Chasers: on campus the security guards (bảo vệ) on foot, and from 2 stars **Mr.T (the story's fictional lecturer)** joins the chase ("thêm Mr.T dí nữa"); on the streets police on motorbikes who dismount near the player. Officers never shoot; they catch. |
| W-D8 | **Busted → community service** ("cảnh sát bắt được thì phải bị bắt đi lao động công ích"): a short "BỊ TÓM!" cutscene, then a timed community-service chore in an orange vest; finishing clears the wanted level and frees the player. |
| W-D9 | Weapons are used on foot only in this phase (no drive-by). Unlimited reserve ammo with magazine reloads; no shops, no pickups. Player has no health bar: explosions and officers knock the player down comically but never kill. |
| W-D10 | **Emotes** (owner 2026-10-24, AskUserQuestion): an emote wheel opened by **holding B**, same radial UI and rules as the weapon wheel (section 9). Built inside Phase W as its last feature task. |
| W-D11 | First emote: the famous football "Siuuu" celebration (owner request). The game names it only **"Siuuu!"**: no real footballer's name, face, shirt or voice anywhere in code, comments, tests or game text; our own player character performs it. |
| W-D12 | The shout is a synthesized "Siuuu" cue by default; the owner's own local file at `user://sfx/siuuu.ogg` or `.mp3` overrides it (git-ignored, never committed or exported), same rule as W-D5. The owner supplied one on 2026-10-24; it lives only on his machine. |
| W-D13 | Bystanders react to an emote ("Có, cho vui"): people nearby clap, some shout "Siuuu" back, some raise a phone to film, then carry on. |

## 2. Weapon wheel
- Input: middle mouse held ≥ 0.12 s opens it (a tap is ignored); release equips the highlighted slot; Esc or right click closes without change. Scroll up/down cycles the 8 slots and shows a small toast with the weapon name.
- Layout: 8 wedges of 45° around the screen centre, slot 0 (unarmed) at the top, clockwise in the W-D4 order. The mouse delta accumulates into a virtual stick; inside a 40 px dead zone the current weapon stays highlighted; outside it the wedge under the stick angle highlights.
- Look: dark translucent ring, highlighted wedge in the Vice pink/cyan accent (classic style: FPT orange), icons drawn in code (no image files, no AI images), centre shows the name and ammo ("12 / ∞"). Vietnamese labels: Tay không, Dao, Súng lục, Shotgun, Tên lửa, Dép tổ ong, Sầu riêng, Loa kẹo kéo.
- Slow motion: `Engine.time_scale` 0.2 while open, eased in/out over 0.1 s real time; the wheel itself runs in real time (`PROCESS_MODE_ALWAYS`, unscaled delta). Disabled while a cinematic, a replay, busted or community service is running, and while riding the bike.

## 3. Weapons

Controls on foot: right mouse = aim (over-the-shoulder camera, FOV narrows, crosshair, walk speed), left mouse = fire / attack, R = reload. Without aiming, guns fire toward the camera centre (hip fire, wider spread).

| Slot | Weapon | Behaviour | Effect on people | Heat |
|---|---|---|---|---|
| 0 | Tay không | Punch combo (placeholder until Phase B Vovinam) | stumble; 3rd hit knocks out | +1 per knockout |
| 1 | Dao | Short swing, 1.4 m arc | knocked out | +2 |
| 2 | Súng lục | Hitscan, 12 rounds, 0.25 s per shot, 1.6 s reload | knocked out | +2 per shot fired near people, +2 per hit |
| 3 | Shotgun | 8 pellets in a 9° cone, 6 rounds, 0.8 s pump, knockback 4 m | knocked out, flung back | +3 |
| 4 | Tên lửa | Visible rocket at 35 m/s, 1 round, 2.5 s reload; explosion radius 6 m, camera shake, smoke, scorch decal | people within 6 m fly in comic arcs and land knocked out; vehicles flip and smoke | +6 |
| 5 | Dép tổ ong | Thrown, flies a 12 m curved path and returns to the hand; one in flight at a time | "bonk" + spinning stars, knocked out 4 s | +1 |
| 6 | Sầu riêng | Thrown grenade, 2 s fuse; green stink cloud 8 m wide for 6 s | people inside pinch their noses, cough and flee; vehicles in it stop | +2 |
| 7 | Loa kẹo kéo | Hold to blast a 10 m cone, 60° wide; music plays while held (W-D5) | people pushed back, some dance on the spot, then flee | +1 per 2 s |

- Every hit uses the existing pedestrian reactions (Pedestrian KNOCKDOWN/FLEE) extended with a knocked-out state (stars, 6-10 s) and a launched state (ballistic arc from an explosion). Impostors and mid-tier walkers inside an effect radius are promoted or simply flee.
- Traffic: bullets stop a vehicle and its rider flees; rockets launch and flip it, add a smoke column, then RoamTraffic recycles it once out of view.
- Sounds are synthesized in code (shot, pump, rocket whoosh, explosion, bonk, cough, bolero cue); each can be overridden by `user://sfx/<cue>.ogg`.
- Hit FX built in code (muzzle flash, tracer, sparks, dust, smoke, stars), reusing the A1 impact FX where possible.

## 4. Wanted level
- Heat accumulates from the table in section 3 (+5 for knocking out an officer). Stars: 1 at 4 heat, 2 at 12, 3 at 25. ViceHUD shows the stars (classic HUD: a small star row under the clock).
- Officers spawn by star and zone:
  - campus (inside the plot): 2 / 4 / 6 security guards on foot; from 2 stars also Mr.T (faster, shouts "Em kia! Đứng lại! Thẻ sinh viên đâu?").
  - streets and residential: 1 / 2 / 3 police motorbikes (reusing RoamTraffic bodies with police colours and PS2 riders) that ride to the player, dismount within 15 m and chase on foot; at 3 stars a second wave arrives after 30 s.
- Losing them: when no officer has line of sight to the player for 12 / 20 / 30 s (by stars), the level drops one star; a minimap circle shows the search area. Hiding inside a building or riding away fast works; entering BE6 does not clear it.
- Officers knocked out by weapons get up after 10 s; officers never shoot and never hurt the player beyond a comic tackle.

## 5. Busted and community service
- Busted when an officer stays within 1.2 m of the player for 1.5 s while the player is not knocked down, or tackles a knocked-down player.
- Sequence: freeze, "BỊ TÓM!" stamp, a 6-8 s cutscene through the A1 cinematic player (officer cuffs the player; Mr.T shakes his head if he made the catch), fade.
- Community service ("Lao động công ích"): the player in an orange vest on a fixed verge of Nguyễn Xiển (or the campus parking if the catch was on campus) must pick up 8 rubbish bags and drop them in a bin within 120 s; meme lines from a supervising officer; weapons and the bike are locked during it. Running out of time restarts the chore with fewer bags (never a softlock). Finishing clears the wanted level, restores the weapons and puts the player next to the bike.
- Hold Esc to skip the cutscene, not the chore.

## 6. Systems and files (detailed in the plan)
- `WeaponWheel` (UI, real time; its radial UI is shared with the emote wheel), `WeaponDirector` (equipped weapon, ammo, fire/aim, per-weapon logic), weapon scripts or data entries per slot, projectiles (rocket, dép, sầu riêng), `StinkCloud`, `SonicCone`, `WantedDirector` (heat, stars, decay, line-of-sight checks), `Officer` (guard / Mr.T / police on foot) and police bikes on top of RoamTraffic, `CommunityService` (chore), audio cues in the existing synth, HUD stars, `EmoteWheel` + `EmoteDirector` + bystander reactions (section 9), FreeRoam wiring behind a flag like `crowd_enabled` so `test_free_roam` stays deterministic.
- Implementer effort: xhigh for weapons/combat, wanted/officer AI; high for the wheel UI, HUD, audio and docs.

## 7. Testing
- Wheel: hold/tap threshold, angle → slot mapping for all 8 wedges and the dead zone, time scale eased to 0.2 and restored, blocked during cinematics and on the bike.
- Weapons: each weapon's hit/area test on stub pedestrians and stub vehicles (knocked out, launched, flee, stink, sonic push), ammo and reload timing in physics frames, rocket explosion radius, dép returns to the hand, no weapon fires while the wheel is open.
- Wanted: heat → stars thresholds, officer spawn counts per zone and star, line-of-sight decay timing, busted detection, community service completes and clears the level, restart path on timeout.
- Performance gates (headless physics time, phase-change frame dropped): weapons + wanted + crowd + traffic within 3 ms per physics frame at BE6 with 3 stars.
- No preview renders by default (the owner play-tests); full regression per task.

## 8. Out of scope
- Drive-by shooting, weapon shops and pickups, player health, police shooting, a 4-5 star level, helicopters.
- Enemy combat AI in lairs stays in story Phase C; Vovinam combos in Phase B replace the unarmed placeholder.
- More emotes: the owner adds them later, one by one, into the free wheel slots.

## 9. Emotes (W-D10..W-D13)
- **Emote wheel:** hold B ≥ 0.12 s to open (a tap is ignored), move the mouse toward a slot, release to play it; Esc or right click closes without playing. It reuses the weapon wheel's radial UI, wedge mapping, dead zone, code-drawn icons, real-time processing and the 0.2× eased slow motion. Only one wheel can be open at a time. Eight slots: slot 0 = "Siuuu!", slots 1-7 empty and drawn greyed with "Sắp có" (not selectable), so a new emote later is one data entry plus its animation.
- **When allowed:** on foot only, and not while aiming, firing, reloading, knocked down, riding the bike, busted, in community service, during a cinematic or a replay (same blocked states as the weapon wheel). Wanted level does not block it; officers keep chasing, so a mid-celebration catch is possible.
- **"Siuuu!" emote (3.30 s, owner amendment: "chạy xong nhảy quay lại"):** the classic celebration as a run, jump and turn. Times are from the emote start; keep them as named constants:
  - 0.00-1.10 **run-up**: about 4 running strides straight ahead (away from the camera), about 4.5 m, arms pumping. Movement goes through the normal body collision, so a wall just stops the run.
  - 1.10 **take-off** off the last stride.
  - 1.10-1.70 **airborne**: apex about 0.55 m, a 180° yaw turn (most of it between 1.20 and 1.60), so the character lands facing back toward the camera.
  - **1.70 landing**: wide stance, knees bent, both arms swung down and out, chest pushed forward, and a small dust puff.
  - 1.70-2.96 **hold** while the shout sustains, with the chest rising slightly.
  - 2.96-3.30 blend back to idle.
- **Animation and rules:** code-built bone poses on the player's PS2 rig. No image files, no AI images; a Mixamo or UAL clip may be used only if a suitable one is already in the project. The equipped weapon is hidden during the emote and restored after it. Run, jump and turn cannot be cancelled; from 2.20 on, movement input ends the emote early. The emote adds no heat.
- **Shout, synced to the landing (owner: "căn cho chuẩn nhịp nhảy với tiếng siuuu"):** every `siuuu` cue file follows one layout:
  - 0.25-0.31 s the "S" sibilant;
  - **0.31 s the vowel burst** (the loudest instant);
  - the vowel sustains to 1.57 s;
  - crowd tail to 2.00 s.
- **Cue start time:** the emote starts the cue at landing − 0.31 s (emote time 1.39), so the "S" sounds in the air and the "IUUU" burst lands exactly on the 1.70 landing frame. The hold ends with the vowel (1.39 + 1.57 = 2.96).
- **Default and override cue:** the synthesized default cue is built to the same layout: a noise "s" from 0.25 s, a vowel from 0.31 s that glides from "i" to a long "uuu", and a fade by 1.57 s. The owner's local override `user://sfx/siuuu.mp3` (W-D12) was trimmed to this layout from his file: source 2.58-4.58 s, 0.15 s fade-in, fade-out from 1.60 s, peak -1.3 dB.
- **Speech bubble:** "SIUUU!" pops above the player at the landing.
- **Bystanders (W-D13):** full-tier and mid-tier people within 10 m at the landing moment turn toward the player; about 50 % clap for 2-3 s, about 25 % shout "Siuuu" back (speech bubble + the cue at lower volume and a random pitch), about 15 % raise a phone and film for 3 s (phone prop with screen glow), the rest just look; then they resume what they were doing. Impostors ignore it. People already fleeing, knocked out or chasing (officers) ignore it.
- **Tests:** wheel opens on B hold and not on a tap, slot mapping and greyed slots not selectable, emote blocked in every blocked state, emote length (3.30 s), run-up distance, 180° turn by landing, cue start at landing − 0.31 s (vowel burst on the landing frame, within one physics frame), the cancel window from 2.20, weapon hidden and restored, shout override resolution, bystander reaction counts by share and radius on stub people, nobody reacts beyond 10 m or while fleeing/knocked out.
