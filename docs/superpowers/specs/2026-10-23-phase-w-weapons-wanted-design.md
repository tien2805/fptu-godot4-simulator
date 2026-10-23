# Phase W: Weapon Wheel, Weapons and Wanted Level – Design

Date: 2026-10-23. Status: design approved by the owner in chat (AskUserQuestion); spec pending owner review. Runs after story Phase A1 (cinematics) and before A2 (story framework). Own implementation plan, branch `phase-w`.

## 1. Owner decisions

| ID | Decision |
|---|---|
| W-D1 | GTA-style radial weapon wheel: **hold the middle mouse button**, move the mouse toward a slot, release to equip (owner: "menu chọn vũ khí hình tròn, mở bằng cách bấm chuột giữa, đưa chuột về hướng vũ khí muốn chọn"). While the wheel is open the game slows to 0.2×. Mouse wheel scroll cycles weapons without opening it. |
| W-D2 | Weapons work **everywhere in the open world, campus included** ("Kiểu GTA, mọi thứ ở mọi nơi"). This replaces story spec S-D5's "gunfights only inside the lairs; on campus only unarmed Vovinam" and its tone rule "no guns on the FPTU campus" (amended there). |
| W-D3 | Still **no blood, no gore, nobody dies**: people hit are knocked out with comic stars, get up 6-10 s later and flee; vehicles hit by explosions flip and smoke, the rider runs away, the wreck is recycled later. |
| W-D4 | Eight slots: unarmed, knife, pistol, shotgun, rocket launcher, and the owner's three funny weapons: **dép tổ ong boomerang**, **sầu riêng stink bomb**, **loa kẹo kéo** (sonic blast). |
| W-D5 | Loa kẹo kéo plays a synthesized bolero cue by default. The owner wants it to blast songs by a real Vietnamese singer: copyrighted music by a real person is never committed, shipped or named in game text; the owner drops his own file at `user://sfx/loa_keo_keo.ogg` or `.mp3` (git-ignored, never exported), same rule as the owner music slots (story spec S-D10). |
| W-D6 | **Wanted level**, 1-3 stars ("phương án B"). Mayhem raises heat; officers chase; escaping their sight long enough lowers the stars. |
| W-D7 | Chasers: on campus the security guards (bảo vệ) on foot, and from 2 stars **Thầy Toàn (ThS. ToanHLM, the story's fictional lecturer)** joins the chase ("thêm ToanHLM dí nữa"); on the streets police on motorbikes who dismount near the player. Officers never shoot; they catch. |
| W-D8 | **Busted → community service** ("cảnh sát bắt được thì phải bị bắt đi lao động công ích"): a short "BỊ TÓM!" cutscene, then a timed community-service chore in an orange vest; finishing clears the wanted level and frees the player. |
| W-D9 | Weapons are used on foot only in this phase (no drive-by). Unlimited reserve ammo with magazine reloads; no shops, no pickups. Player has no health bar: explosions and officers knock the player down comically but never kill. |

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
  - campus (inside the plot): 2 / 4 / 6 security guards on foot; from 2 stars also Thầy Toàn (faster, shouts "Em kia! Đứng lại! Thẻ sinh viên đâu?").
  - streets and residential: 1 / 2 / 3 police motorbikes (reusing RoamTraffic bodies with police colours and PS2 riders) that ride to the player, dismount within 15 m and chase on foot; at 3 stars a second wave arrives after 30 s.
- Losing them: when no officer has line of sight to the player for 12 / 20 / 30 s (by stars), the level drops one star; a minimap circle shows the search area. Hiding inside a building or riding away fast works; entering BE6 does not clear it.
- Officers knocked out by weapons get up after 10 s; officers never shoot and never hurt the player beyond a comic tackle.

## 5. Busted and community service
- Busted when an officer stays within 1.2 m of the player for 1.5 s while the player is not knocked down, or tackles a knocked-down player.
- Sequence: freeze, "BỊ TÓM!" stamp, a 6-8 s cutscene through the A1 cinematic player (officer cuffs the player; Thầy Toàn shakes his head if he made the catch), fade.
- Community service ("Lao động công ích"): the player in an orange vest on a fixed verge of Nguyễn Xiển (or the campus parking if the catch was on campus) must pick up 8 rubbish bags and drop them in a bin within 120 s; meme lines from a supervising officer; weapons and the bike are locked during it. Running out of time restarts the chore with fewer bags (never a softlock). Finishing clears the wanted level, restores the weapons and puts the player next to the bike.
- Hold Esc to skip the cutscene, not the chore.

## 6. Systems and files (detailed in the plan)
- `WeaponWheel` (UI, real time), `WeaponDirector` (equipped weapon, ammo, fire/aim, per-weapon logic), weapon scripts or data entries per slot, projectiles (rocket, dép, sầu riêng), `StinkCloud`, `SonicCone`, `WantedDirector` (heat, stars, decay, line-of-sight checks), `Officer` (guard / Thầy Toàn / police on foot) and police bikes on top of RoamTraffic, `CommunityService` (chore), audio cues in the existing synth, HUD stars, FreeRoam wiring behind a flag like `crowd_enabled` so `test_free_roam` stays deterministic.
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
