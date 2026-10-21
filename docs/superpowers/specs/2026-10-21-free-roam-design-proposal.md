<!-- Generated 2026-10-21 by a 15-agent ideation workflow (5 idea lenses, 3 judges, 6 code verifiers, 1 synthesizer). English is the canonical version; a Vietnamese companion is in 2026-10-21-free-roam-design-proposal.vi.md. -->

> **Owner directives added after this document was generated (2026-10-21, same evening). They override anything below that conflicts:**
> 1. **Real-world map.** The open world must follow real geography. Source: OpenStreetMap data (ODbL, attribution required) fetched into `reference_data/osm/`; Google Maps is used only for visual cross-checking, never copied. The FPT HCM campus, Đường D1, HUTECH and the surroundings must be laid out from the real footprints and road geometry (see `reference_data/osm/map_900m.png`).
> 2. **Spawn at Vinhomes Grand Park, tower BE06.** The player starts the game at tower BE06 in Vinhomes Grand Park (Long Bình, Thủ Đức), about 3.5 km east of the campus. The owner lives there, so that area must be built generously with many playful things to do, and the ride Vinhomes → FPTU follows the real roads.
> 3. **GTA Vice City art direction.** All current graphics are to be converted to a Vice City look (1980s Miami palette: pink/teal/peach pastels, neon at night, sunset skies, heavy distance fog, PS2-era low-poly flat-textured look, period HUD with radar and money counter). Style only: no Rockstar assets, fonts or names.

# Design Proposal: Open-World Mode "Khám phá campus" (Explore Campus)

Target: v1.2 of FPTU Student Simulator. Audience: the solo owner and the AI coding agents who will turn this into a plan. Godot 4.7, pure GDScript, no plugins, Pillow-only textures, all names fictional.

Read this first: every verification pass found the same thing. The repo has NO open-world foundation yet. `scenes/FreeRoam.tscn`, `scripts/FreeRoam.gd`, `scripts/ThirdPersonController.gd`, walking NPCs, the T key, the M map and the P photo mode exist only in spec §1.2 and roadmap §5 step (4). This proposal therefore has a Tier 0 (foundation), and every Tier 1 and later effort number is counted ON TOP of that foundation. Stage names below use the repo's own labels (Màn 1 to Màn 6, Extra).

## 1. Pillars

- The campus has people you fear. Toàn Nổ patrols with an 8 m vision cone, Chú Bảy is the law at the barrier and in the courtyard. There is always someone to dodge, tease, get caught by, and tell your friends about.
- Every NPC is a toy. One poke key with 13 preset reactions, Phúc asleep in impossible places, Tú on his fourth Monster. No quests, but something to do with every person.
- Real FPT HCM pain, replayable: the orange-lanyard card swipe at 07:29, finding your scooter among ~200 identical ones, waiting for the lobby G elevator.
- Numbers go up and sets fill in: Cóc Vàng (Golden Toad coins), Điểm rèn luyện (ĐRL, conduct points), the 20-line Toàn Nổ notebook, Phúc's 10 sleeping spots, the crude selfie album. A daily seed moves Phúc, reshuffles swipe failures, and steals your bike 1 day in 10.
- The open world feeds the mini-games instead of competing with them: hotspot records pay coins, Golden Toad blessings carry into Màn 3 and Màn 4, Monster cans bought in Màn 5 come home to Tú.
- Every interaction is a 15-second clip: slow motion, freeze frame, caption, red stamp, fly buzz, lightning. The same "cinematic bẩn bựa" (dirty-crude cinematic) grammar the story mode uses.

## 2. The one core loop

Explore, Try, Collect, Spend, Return. Two numbers are the spine: Cóc Vàng (CV, spendable coins) and Điểm rèn luyện (ĐRL, 0 to 100 conduct points, awarded only the first time each thing is done so nothing can be farmed forever).

| Step | What the player does | What they get | Where it is stored |
|---|---|---|---|
| Explore | Walk or ride the campus, T cycles the time-of-day preset, hear snoring, see Toàn Nổ appear | Events, hotspot signs with `[E]` | Nothing |
| Try | Enter a hotspot mini-game, swipe the card, dodge Toàn Nổ, poke an NPC, wake Phúc | CV + ĐRL + roam records | `StageManager.best_stats` (mini-games), `roam_stats` (new) |
| Collect | Toàn Nổ lines, Phúc spots, selfies, (Tier 2) tool-gang flyers | Completion %, a reward scene when full | `roam_stats` bitmasks |
| Spend | (Tier 2) Offer a can at the Golden Toad, buy a can for Tú | Buffs into Màn 3 and Màn 4, Tú overdose scene | `StageManager.inventory` (session), wallet (disk) |
| Return | Daily seed: Phúc's spot, swipe failure set, bike-stolen day, next ĐRL milestone, lines not yet unlocked | New concrete things each launch | Hash of the system date |

Sources and sinks in v1.2:

| Source of CV / ĐRL | Weight | Sink |
|---|---|---|
| Winning a hotspot mini-game: S 60 / A 40 / B 25 CV, doubled on a new record, first win +100 CV and +5 ĐRL | Main | Tier 1: one small sink shipped alongside (see Question 6) |
| Clean swipe, Thẻ VIP (VIP card), surviving Toàn Nổ, crude combo, finding Phúc | +5 to +20 CV, +1 ĐRL first time | Tier 2: Golden Toad offering (meme-04), cans for Tú (bua-04) |
| ĐRL below 50 | Student-affairs warning in the lobby, Toàn Nổ scolds you | Tier 3: garage (loop-05), canteen economy (loop-07) |

## 3. Tiers

Every "reused" name below was checked against the repo. Effort is in solo-developer days and uses the verified (revised) numbers, not the original pitches.

### Tier 0: mandatory foundation (not in the code yet)

**Minimal FreeRoam.** `scenes/FreeRoam.tscn` + `scripts/FreeRoam.gd` build the campus with `FPTUCampusBuilder.build_authentic_campus(root, Vector3.ZERO, 0.0, {colliders: true, parking_gaps: [...]})` plus a Ground StaticBody (the builder has no ground collider; Stage2 adds a 600x0.4x600 box in its .tscn), a D1 piece via `build_d1_road_piece()` and HUTECH via `build_hutech()`. `scripts/ThirdPersonController.gd` is extracted from `StageExtra_EOSExam._handle_movement()` (camera-relative WASD, 4.2 m/s) and `_update_walk_camera()`, dropping the room-311 clamp, adding gravity and a farther camera, plus `Stage5_Canteen._process_walk()`. NPC walkers come from the `Stage5_Canteen._build_npcs()` / `_process_npcs()` waypoint pattern with a `role` meta. The scooter uses `PlayerBike` with F to mount and dismount (`road_path = null` set explicitly, new `@export fallback_respawn`, `lane_clamp_enabled = false`). T swaps presets through `GameFX.upgrade_scene_visuals()` only when the preset actually changes.
- Reused (verified): `build_authentic_campus` + `colliders` opt, `StageExtra_EOSExam._handle_movement:453`, `Stage5_Canteen._process_npcs:690`, `PlayerBike.lane_clamp_enabled:37`, `GameFX.TOD_PRESETS:648` (dawn, morning, noon, night), `Animator` distance LOD (`CharacterBuilder.gd:1305-1318`).
- New: the two files above, `StageManager.roam_stats` + a `[roam]` section in `user://progress.cfg` read and written inside `save_progress()` / `load_progress()` (today `save_progress()` rebuilds the file with only `stage_%d` sections, and a string key in `best_stats` is a runtime error), a path parameter so headless tests can write, a "Về campus" (Back to campus) button in the result modal plus a `return_to_roam` flag, a flag so `StageManager._input()` ignores M while in FreeRoam, and FreeRoam added to `tests/smoke_all_stages.gd` and `tests/test_hud_bounds.gd`.
- Effort: 4.5 days (verifiers estimated 3 to 5). Crude level: 0/5. Inside spec §4.

### Tier 1: must-have for v1.2

**1.1 loop-01 Cóc Vàng wallet + Điểm rèn luyện.** Everything pays CV and ĐRL; the HUD corner shows the wallet and the ĐRL bar; a popup "+30 Cóc Vàng, +2 ĐRL" with the `cash` sound. Below 50 ĐRL a "THÔNG BÁO CTSV" (Student Affairs notice) board appears in Sảnh Trống Đồng (Bronze Drum Lobby) with Toàn Nổ beside it saying "Điểm rèn luyện này tôi cho vì thương" (I gave you these conduct points out of pity). J opens the milestone board. Area unlocks (rooftop, garage, back gate) are deferred: there is no garage or back-gate geometry.
- Reused: `StageManager.report_stage_result:512` (already compares records; `b.wins == 0` before increment detects a first win), `save_progress/load_progress:125-149`, `GameFX.anchored_panel:850`, `GameFX.make_bar:826`, `play_sfx('cash')`, `MainMenu._refresh_journal:376`, J is unused in `StageManager._input()`.
- New: wallet and ĐRL as MEMBERS of `StageManager` (not a new autoload; the 15 headless tests create autoloads by hand and would break), `earn()/spend()/drl_add()/drl_tier()` + a `wallet_changed` signal, persisted in `[roam]` with a path parameter; `FPTUCampusBuilder.lobby_center()` (only `lobby_u()` exists); `tests/test_wallet.gd`.
- Effort: 3 days. Crude: 2/5. Beyond spec §4/§6 (progression in the open world).

**1.2 bua-01 Toàn Nổ patrols the campus.** Every 3 to 5 minutes Toàn Nổ appears in the lobby and walks a fixed route lobby → canteen → back gap → stair foot, dragging an 8 m vision cone. Sprinting, sitting on the scooter in the courtyard, or standing on your phone inside the cone gets you caught: punch-in, slow motion, pointed finger, one line from the bank such as "Dốt như bò. Mấy ông cho về đi chăn heo." (Dumb as an ox. You lot can go home and herd pigs.). Two seconds to choose: bow with E (he nods, lets it go), run (6 s chase inside the paved half of the courtyard; if caught, freeze frame "ĐÚNG VẬY, ĐÓ LÀ TÔI" (YES, THAT WAS ME) with a red "ĐI CHĂN HEO" (GO HERD PIGS) stamp), or hide behind a tree (a raycast from him hitting a tree collider means escape). Each escape unlocks a line in the Sổ tay Toàn Nổ (Toàn Nổ notebook); 20 lines unlock a scene of him drinking coffee alone on the canteen porch, caption "Anh Minh bên Marvell không nghe máy" (Minh over at Marvell is not picking up).
- Reused: preset `lecturer` + `set_expression('angry')`, clips `bow/nod/facepalm`, running = `set_speed(6 to 7)` + `set_param('run', 0.4)` (there is no `run` clip), `Stage3_ClassroomFAP.lecturer_bubble:118` as the bubble model, `GameFX.slow_motion(0.3, 1.2)`, `music_play('exam')` + `music_tension()` (the `exam` style has a heartbeat kick above 0.4), route points from `lobby_u()`, `canteen_center()`, `back_gap_u()`, `stair_foot()`, courtyard trees have r 0.3 colliders.
- New: `scripts/roam/ToanPatrol.gd` (state machine idle → patrol → spot → lecture/chase → lose; cone = dot > cos 35° + RayCast3D on StaticBody3D; chase limited to u in [36, 85], v in [35, 71]; 3 short raycasts to steer around trees and the pond; stuck 1 s = lose); preset `lecturer_boss` in `_outfit_for` + `receding` hair branch in `_build_hair` + glossy polo via `_mat(key, color, 0.4)` (`_cloth_mat` has no roughness parameter) + `watch_scale` opt (the story mode needs this preset too); `scripts/ui/FreezeFrame.gd` (viewport capture + caption + stamp rotated -12°, later shared with Cinematic §2.3); 8 new lines parked in `ToanPatrol.LINES` until `story/Lines.gd` exists; cooldown 1 per 3 minutes, disabled inside hotspot Area3Ds; `tests/test_toan_patrol.gd`. Cut from v1: NPCs scattering, hiding behind student groups, the 07:25 trigger (no clock yet).
- Effort: 4.5 days. Crude: 5/5. Beyond spec §0/§6 (line collection; NPC does more than one line).

**1.3 bua-08 One poke key + crude selfie.** G (F is reserved for the scooter; KEY_G is unused anywhere) pokes an NPC: students flinch with an angry face and "Ê!" (Hey!); Chú Bảy (the guard) whistles, wags a finger, writes you up on the third poke; Cô Ba (the canteen lady) screams "KHAY CỦA CÔ" (THAT'S MY TRAY) and a tray flies into the camera; Toàn Nổ punches in with "Hỏi gì mà hỏi. Google mất hai giây, hỏi tôi mất hai điểm." (What are you asking. Google takes two seconds, asking me costs two points.); Minh stares into the camera The Office style, the world freezes 1 s, caption "…"; Linh shows a floating heart then instantly "seen". Poking 5 different NPCs in 30 s triggers "COMBO BỰA x5" (CRUDE COMBO x5): every NPC within 20 m facepalms in sync with a vuvuzela sting. In photo mode P, G next to an NPC is a selfie: the NPC strikes a random pose with a random expression and the shot is saved with a meme caption like "chụp giúp mình điểm danh với" (take my picture so I count as present).
- Reused: `CharacterBuilder.play:601` + `Animator.ONE_SHOT:1278` (flinch/facepalm/bow/cheer_once/nod end by themselves; wave/stance/plank loop, so pass a duration), `set_expression:633` (all 32 face textures exist), `look_at_point:627`, `PropBuilder.build_tray:450`, `Stage5_Canteen._on_npc_bump:632` as the pattern, `GameFX.slow_motion(0.02, 1.0)` for the freeze, photo = `get_viewport().get_texture().get_image().save_png()` as in `tests/preview_*.gd` (no SubViewport needed, the HUD caption is already in frame).
- New: `scripts/roam/NpcReactions.gd` (role → clip/duration/expression/line/fx table, ~150 lines), a 30 s ring buffer for the combo, a `dab` clip (~15 lines in `Animator._clip_pose`), `vuvuzela` and `whistle` cases in `GameFX._synth()`, skip the PNG write when headless, `tests/test_npc_reactions.gd` (every preset including `rigged: true` runs without SCRIPT ERROR and returns to `open`). Dropped: "bake an extra pose" (no crowd bake pipeline exists, `Animator` already LODs).
- Effort: 2 days. Crude: 4/5. Beyond spec §6 (the selfie album).

**1.4 meme-03 Orange-lanyard card swipe at 07:29.** Ride to the parking barrier; each E press is a timing bar plus one random failure from the v1 set of five (card upside down, reader lag, dropped card, forgot card so you type "ib anh cứu" (DM me, I'll save you) to a friend, barrier jammed). A miss sends the card flying in slow motion with a fly buzz, the 4 to 6 NPC scooters behind you lose patience and honk, Chú Bảy curses on the beat. Success shows "quẹt N lần · M giây · độ nhục" (N swipes · M seconds · shame level). Five consecutive first-try swipes unlock Thẻ VIP (VIP card): the barrier opens before you swipe and Chú Bảy bows.
- Reused: `FPTUCampusBuilder._build_gate:1007` + `skip_barrier_at` opt, `park_gate_guard_pos:761`, `Stage2_Parking._build_gate_props:278` and `_scan_student_card:756` (tween on `rotation_degrees:z`) as patterns, `_update_guard_nag:677` (ported by hand, ~60 lines; it is not a reusable bank), `PropBuilder.build_scooter:171` + `CharacterBuilder.build_baked_rider:583` for the queue, `GameFX.play_sfx('res://assets/audio/bike_horn.wav')` (`play_sfx` accepts res:// paths), `hit_stop/slow_motion/popup/float_text`, `play_sfx('error' | 'pop' | 'beep' | 'miss')`.
- New: `scripts/roam/CardSwipeQTE.gd` (5-failure state machine, 2 to 4 s each), BOTH barrier arms built in code (Stage2's first arm is a .tscn node), a card mesh = BoxMesh + `prop_student_card.png` added to `generate_prop_textures.py` (repo root), queue that creeps forward + a patience bar, honks limited to 1 per 0.8 s per bike and 3 bikes at once, a 12-line Chú Bảy bank, `roam_stats.gate`, `tests/test_roam_gate.gd`. The Màn 2 hotspot keeps its sign; the QTE sits after the barrier or on a key other than E.
- Effort: 3 days. Crude: 4/5. Beyond spec §6 lightly (achievement).

**1.5 bua-03 Phúc asleep everywhere (Where's Phúc?).** On every FreeRoam entry or T press, Phúc picks 1 of 10 spots that are guaranteed to have a floor (under a canteen table, sitting on the rim of the Golden Toad plinth, wedged between two scooters in a `parking_gaps` slot, beside the lotus pond, the stair foot, the guard booth, the arcade porch...). A 3D snore audible within 20 m is the clue. E → mash SPACE 14 times in 4 s → Phúc jolts awake with a surprised face, says a line ("Em đang debug trong mơ", I was debugging in my dream), walks exactly 10 m and falls asleep again at the next spot. All 10 spots unlock Phúc asleep on the Toad's head, lightning strikes, he still does not wake, caption "SEEN KHÔNG REP LÀ CÓ LÝ DO" (SEEN WITHOUT REPLY HAS A REASON).
- Reused: `build({preset: 'student_m', hair_style: 'spiky'})`, clips `sleepy/sleepy_sit/lie/slump/flinch`, `set_expression('surprised' | 'done')`, the 14-in-4 s mash of `Stage6_CapstoneBoss._phone_start:798` as the model, `GameFX._synth()` returns an AudioStreamWAV for an AudioStreamPlayer3D, `flash()` + `play_sfx('explode')` for lightning, `canteen_center()/parking_spot_candidates()/stair_foot()/lobby_u()`.
- New: `scripts/roam/PhucSpots.gd` ({pos, clip, yaw, line, walk_dir} table, pick by hourly seed), a separate `scripts/roam/MashPrompt.gd` (do not refactor Màn 6: `test_stage6_capstone.gd` reads `phone_active` directly), a `snore` synth case (~8 lines), helpers `toad_pos()` / `pond_center()` (shared with meme-04, bua-04, bua-06), one multi-line "jjjj" label instead of 400 Label3Ds, `roam_stats.phuc_found` bitmask, `tests/test_phuc_spots.gd` (a downward raycast at every spot must hit a floor). Stair landings, rooftop and Lab 402 return when stair and upper-floor colliders exist.
- Effort: 2 days. Crude: 3/5. Beyond spec §6 (collection).

### Tier 2: should-have (v1.3)

**2.1 meme-04 Golden Toad blessing.** Offer one can (or CV) at the statue, pick a blessing, bow 3 times on a 0.8 s beat with the `bow` clip, receive a meme fortune from 4 rarity levels ("Cóc nói: Google mất 2 giây, hỏi Cóc mất 2 điểm", The Toad says: Google takes 2 seconds, asking the Toad costs 2 points), the eyes glow, lightning in slow motion. The blessing is a real item: `via_fap` gives +5 s in Màn 3 (hook in `_ready()` near line 168, score formula ignores time), `via_vovinam` forgives one miss in `Stage4_Vovinam._judge_result()` (keep `n['judged'] = true` or the round hangs). This is the wallet's first sink.
- Reused: toad in `_build_courtyard:1217`, `StageManager.inventory` + `add_item/consume_item:496-510`, `GameFX.flash/slow_motion/play_sfx('explode' | 'success')`, `tests/test_stage3_classroom.gd` and `test_stage4_vovinam.gd` patterns.
- New: `toad_pos()`, named nodes `ToadEyeL/R` with their own emission material (never tween `m['dark']`, it is shared campus-wide), `scripts/roam/ToadShrine.gd`, a 30-fortune bank, a `via: true` flag in the result dict and a `*` in `get_best_text()`, once-per-day lock in `[roam]`.
- Effort: 3 days. Crude: 3/5. Beyond spec §4 (a buff touches records; needs approval).

**2.2 explore-08 Find your scooter among ~200.** Your scooter sits in a day-seeded slot (the grid is 2 rows x 2 faces x 50 at 1.3 m, about 195 bikes, not 400). K beeps the key fob (AudioStreamPlayer3D on the bike, `max_distance` 25, max 5 beeps), the lights flash via an emission or OmniLight tween on `PlayerBike`. Riding into the courtyard makes an Area3D clamp `max_speed_ms` to 8; after 3 s Chú Bảy impounds it back to the booth with a "-50k" float text. Day % 10 == 0: no bike; Lò Văn Lụm is riding it toward the gate and you chase on a second `PlayerBike` (swap `chase_cam.current`).
- Reused: the parking grid loop in `_build_back_facilities:1263-1279` (fixed seed 7), `parking_gaps` opt as Stage2 uses it, `build_scooter` baked + `build_baked_rider`, `_rival_plan_route:420` as a pattern (copy, do not call), `PlayerBike.set_rain()`.
- New: static `FPTUCampusBuilder.parking_slots()`, `scripts/roam/ParkingFinder.gd`, courtyard Area3D, the stolen-day branch, `tests/test_parking_finder.gd`. Do not touch the MultiMesh (15 MMIs, local variables, no index returned).
- Effort: 3 days. Crude: 4/5. Beyond spec §6 (daily event).

**2.3 bua-04 Tú and the fourth Monster.** Tú stands at the Monster machine (extract the 89-line `Stage2_Parking._build_monster_machine()` into `PropBuilder.build_vending_machine()`). Can 1: "Ngon" (Tasty). Can 2: walks twice as fast and slurs. Can 3: vibrates in place. Can 4: glowing cyan eyes, tension 1.0, slow motion, 3 laps of the pond on 8 hand-placed waypoints leaving "jjjj" behind, then collapses with "TU.EXE ĐÃ NGỪNG HOẠT ĐỘNG" (TU.EXE HAS STOPPED WORKING) and a fly buzz. Drinking one yourself: sprint x2 clamped at 9 m/s, FOV swell, speedlines, heartbeat vignette; when it ends you "burn out", flop, and nearby NPCs raise their phones.
- Reused: `MONSTER_POS`, `SPRINT_SPEED = 9.0`, `StageManager.inventory` (Màn 5 `add_item('monster')` at :901), `HUDManager.SPEEDLINES_SHADER` const, `GameFX.set_vignette(strength, color, pulse_hz)`, `play_sfx('heart' | 'shutter')`, `get_pivot(root, 'head')`.
- New: `scripts/roam/TuMonster.gd` with an `overdose()` callable from StoryScene (the Thursday chapter in spec §3.1 needs exactly this scene), clips `flop` and `photo` (a standing phone pose; `phone` is a seated pose), a `fly` synth (180 Hz with LFO), `apply_monster()` on the controller, cyan eyes as 2 emissive spheres (OmniLights would light the inside of the head), rerun `tests/test_stage2_stairs.gd` after the extraction.
- Effort: 2.5 days. Crude: 4/5. Beyond spec §6 lightly. Note: inventory is not saved to disk and `start_new_day()` resets it.

**2.4 bua-06 Pranks: horn, pond, Golden Toad.** Honk H next to a group: they flinch, one drops a tray, Cô Ba leans out; 5 honks in 10 s brings Chú Bảy with "BIÊN BẢN: XE BỊ TẠM GIỮ 60s" (REPORT: BIKE IMPOUNDED 60s) and F is locked. Step into the pond (`pond_collider: false` opt + a disc Area3D): CPUParticles3D splash, slow motion, camera roll, caption "LINH VẬT MỚI CỦA FPTU" (FPTU'S NEW MASCOT), wet for 20 s at 50% speed with an `m['leaf2']` lotus leaf under `head_top()`; at night, lightning, `lie`, respawn by the lobby with "GAME NÀY KHÔNG CÓ BẢO HIỂM" (THIS GAME HAS NO INSURANCE). Golden Toad: hold E 3 s = tween onto the head (no jump or ledge grab exists), NPCs within 15 m come and cheer, Chú Bảy arrives with "XUỐNG!" (GET DOWN!).
- Reused: `Input.is_action_just_pressed('horn')` as Stage2:669 (`PlayerBike` emits no horn signal), pond and toad geometry in `_build_courtyard`, night detection via `root.get_meta('visual_preset') == 'night'`, clips `flinch/cheer/lie/carry`, `set_opacity`.
- New: `scripts/roam/PrankSystem.gd`, opts `pond_collider` and `toad_climbable`, a walk-to-target NPC behaviour (~30 lines, shared with bua-02), `roam_stats.pranks`, `tests/test_pranks.gd`. The pond surface is 0.1 m above the courtyard; real depth costs +0.5 day.
- Effort: 3.5 days. Crude: 5/5. Beyond spec §6 (achievements).

**2.5 bua-02 The tool gang pitches "IB ANH CỨU".** Cừu Dolly (same `seed` = identical clones, new `cap` opt), Lò Văn Lụm and Lò Thị Lụm tail you at 1.5 m, phones up, spouting the bank: "còn 3 slot, nhanh tay" (3 slots left, hurry), "uy tín 5 năm, feedback đầy" (5 years of credibility, full of feedback). A second E is "Em không mua" (I'm not buying) and they leave for 2 minutes. Taking a flyer opens a fake FB group post overlay with a comment counter of "chấm" (dot) climbing. "Chốt đơn" (Close the deal) = "ĐÃ CHUYỂN KHOẢN 200K" (200K TRANSFERRED), reputation -1, Lò Thị Lụm turns away mid-phone; "Báo chú Bảy" (Report to Chú Bảy) = the guard spawns 15 to 20 m away with a whistle, the gang sprints in slow motion, caption "UY TÍN 5 NĂM" struck through. Every time Dolly is chased off, one more clone appears next time (max 6). 12 Pillow flyers at 256x256; the Gia Mẫn rooftop TED talk moves to Tier 3 (no rooftop colliders).
- Reused: `build(opts)` with `seed`, clips `phone/flinch`, `Stage2_Parking._rival_say:693` as the bubble pattern, `GameFX.anchored_panel/make_label`, `play_sfx('ring' | 'cash' | 'whoosh')`, `generate_lobby_textures.py` `font()/save()`, `stair_foot()` as the hangout (the Lab 402 door is at y 17.9 and unreachable).
- New: `scripts/roam/ToolGang.gd` (CharacterBody3D + `move_and_slide`, kept to open areas around the pond and parking lanes since there is no navmesh), `scripts/ui/FbPostOverlay.gd` (StoryScene reuses it for the `post` command), `lotus_pond_center()`, `cap` opt, `generate_flyer_textures.py`, `tests/test_tool_gang.gd`. Never show a real account number or QR.
- Effort: 4 days. Crude: 4/5. Beyond spec §0/§6 (flyer collection; needs approval).

### Tier 3: later (v1.4+)

**3.1 meme-01 The lobby G elevator congregation.** Door state machine closed/open/full/stuck, the "the more you press the longer it takes" rule, leave and the door opens behind you with a freeze frame. Needs a cabin pocket cut into the link block between modules 1 and 2 (`build_module_wing:668`), a `lobby_elevator_doors()` getter, a floor-number Label3D, fixed queue slots, 10 cabin people via `pose()` + `bake()` (rigged=false only). Trigger by Area3D when the preset is `morning` (no clock). The "run up the stairs" branch is geographically wrong (the atrium stair is in the right wing, 75 m from the lobby), so the destination is `lab402_door()` via a fade teleport. 3 days, crude 3/5, beyond spec §0/§6. Build together with explore-02.

**3.2 meme-06 07:25, the whole campus runs for slot 1.** Needs `scripts/roam/CampusClock.gd` (1 game minute = 10 s, T jumps to the next milestone minus 1 minute) and `NpcSchedule.gd` (idle → rush → inside, waypoints through `stair_profile()`, hide at the door), an F-Bus tween unloading 15 to 20 NPCs, `BikeNpc.gd` split from the Màn 2 rival, the bell as `play_sfx('res://assets/audio/absent_gameover.wav')` (never call `HUDManager._trigger_absent_screen()`, it writes a loss into the Màn 1 record). Cap at 30 animated characters, far crowds baked into a MultiMesh. 4 days, crude 3/5, beyond spec §4 (dynamic clock + NPC schedule). The cheap version is the "Stampede" event inside bua-07.

**3.3 Grouped from the remaining 28** (names only, reasons in the appendix): bua-07 BuaDirector, life-01 clock + timetable, life-06 crowd films you, explore-05 / meme-05 / loop-04 merged into "FB group album with prompts", explore-02 basement B1 elevator, explore-03 flyer clues, meme-08 Bronze Drum busking, loop-05 garage, loop-06 wardrobe badges, life-07 / explore-06 campus at night, life-08 animals, meme-07 / explore-04 F-Bus, explore-01 rooftop, loop-03 found items, bua-05 quirk gene, loop-02 daily timetable, life-04 big events.

## 4. Crude comedy in the open world

| # | Event | Trigger |
|---|---|---|
| 1 | Freeze frame "ĐÚNG VẬY, ĐÓ LÀ TÔI" (YES, THAT WAS ME) with a red "ĐI CHĂN HEO" (GO HERD PIGS) stamp rotated -12° | Caught sprinting inside Toàn Nổ's 8 m cone, chose to run, tagged within 6 s |
| 2 | Toàn Nổ nods and lets it go, still muttering "Nhà tôi không có gì ngoài tiền" (My house has nothing but money) | Press E to bow (`bow` clip) within the 2 s window |
| 3 | Toàn Nổ drinks coffee alone on the canteen porch, caption "Anh Minh bên Marvell không nghe máy" (Minh over at Marvell is not picking up) | All 20 notebook lines unlocked |
| 4 | Student-affairs warning board in the lobby, Toàn Nổ beside it: "Điểm rèn luyện này tôi cho vì thương" (I gave you these conduct points out of pity) | ĐRL below 50 when entering Sảnh Trống Đồng |
| 5 | Cô Ba screams "KHAY CỦA CÔ" (THAT'S MY TRAY), a tray flies into the camera, player flinches, screen shakes | G on an NPC with role `cook` |
| 6 | Minh stares into the camera The Office style, the whole world freezes 1 s, caption "…" | G on role `minh` (`slow_motion(0.02, 1.0)`) |
| 7 | Linh floats a heart up, then instantly "seen" | G on role `linh` |
| 8 | "COMBO BỰA x5" (CRUDE COMBO x5): every NPC within 20 m facepalms in sync, vuvuzela sting | Poke 5 different NPCs within 30 s |
| 9 | Orange-lanyard card spins away in slow motion with a fly buzz, the scooter queue honks, Chú Bảy curses on the horn beat | Miss the swipe QTE; the queue's patience bar drops |
| 10 | Thẻ VIP (VIP card): the barrier opens before you swipe and Chú Bảy bows | 5 consecutive first-try swipes |
| 11 | Phúc springs up, "Em đang debug trong mơ" (I was debugging in my dream), walks exactly 10 m and falls asleep at the next spot | Mash SPACE 14 times in 4 s next to Phúc |
| 12 | Phúc asleep on the Golden Toad's head, white flash of lightning, still asleep, caption "SEEN KHÔNG REP LÀ CÓ LÝ DO" (SEEN WITHOUT REPLY HAS A REASON) | All 10 sleeping spots found |
| 13 | Selfie: the NPC strikes dab / plank / stance with a random face, caption "chụp giúp mình điểm danh với" (take my picture so I count as present) | Photo mode P, press G next to an NPC |

Tier 2 adds: TU.EXE stops working, "ĐÃ CHUYỂN KHOẢN 200K", Dolly clones, lightning for a night swim, your bike leaving with Lò Văn Lụm.

## 5. NPCs and the campus schedule

v1.2 has no running clock; "time" is the four `GameFX.TOD_PRESETS` keys cycled with T. Presets and clips below exist in `CharacterBuilder` (running is `set_speed()` + `set_param('run')`, there is no `run` clip; `lecturer_boss`, `lobby_center()` and `pond_center()` are Tier 1 additions).

| Preset (implied time) | Who (preset) | Where (function) | Doing (clip) |
|---|---|---|---|
| dawn (07:00 to 07:30) | Chú Bảy (`guard`) | `park_gate_guard_pos()` | `guard`, `wave` as bikes arrive, `facepalm` on a failed swipe |
| dawn | 12 students (`student_m`, `student_f`, `casual`) | from `back_gap_u()` across the courtyard to `stair_foot()` | fast walk, a few `phone` while walking |
| dawn | Toàn Nổ (`lecturer_boss`) | `lobby_center()` | first appearance, `nod`, patrol begins |
| dawn | Phúc (`student_m`, spiky) | seeded sleeping spot | `sleepy_sit` or `lie`, 3D snore |
| dawn | Tú (`student_m`) | Monster machine at `MONSTER_POS` | `phone` |
| morning (07:30 to 11:30) | student groups | arcade porch, stone benches | `sit`, `type`, `phone` |
| morning | Linh (`student_f`) | pond edge `pond_center()` | `phone`, `look_at_point` toward the player when near |
| morning | Minh (`student_m`, glasses) | bench near `stair_foot()` | `type` on a PropBuilder laptop |
| morning | Vovinam club (`vovinam`, `master`) | martial-arts yard | `stance`, `punch`, `kick` in rotation |
| morning | Toàn Nổ | lobby → canteen → back gap → stair foot | patrol, `facepalm` at anyone sprinting |
| noon (11:30 to 13:30) | Cô Ba (`cook`) + 10 students | `canteen_center()` | `carry`, `eat`, `sit`; Phúc `lie` under a table |
| noon | Chú Bảy | guard booth | `sleepy` (yawning) |
| noon | Toàn Nổ | canteen porch | `eat` alone, angry only when poked |
| noon | tool gang (Tier 2, `casual` with cap) | parking lanes | `phone`, tailing |
| night (18:00+) | Chú Bảy | booth | `sleepy`, flashlight (Tier 3) |
| night | Capstone group (Minh, Linh, 2 `student`) | stair foot (Lab 402 unreachable yet) | `type`, `slump`, one `sleepy` |
| night | Tú | Monster machine | `slump` after can 3 (Tier 2) |
| night | Phúc | Golden Toad plinth rim | `sleepy_sit`; lightning when the set is complete |
| night | Toàn Nổ | no patrol; stands in the lobby if ĐRL < 50 | `nod`, one student-affairs line |

## 6. Technical architecture

New scenes and scripts (one folder name, `scripts/roam/`, never a parallel `freeroam/`; the two baseline files keep the paths spec §1.2 already names):
- `scenes/FreeRoam.tscn` + `scripts/FreeRoam.gd`: host; campus with `colliders: true`, Ground StaticBody 600x0.4x600 as in Stage2, `parking_gaps` for the player's slot, 7 hotspot Area3Ds, NPC spawner setting `role` meta (student/guard/cook/lecturer/minh/linh/tu/phuc), wallet HUD.
- `scripts/ThirdPersonController.gd`: CharacterBody3D, camera-relative WASD (from EOS), gravity, Shift sprint, `input_locked` flag, `camera_roll`, `apply_monster()` (Tier 2).
- `scripts/roam/RoamNpc.gd`: kinematic waypoint walker (from Stage5), `[E]` one line, `get_animator()`.
- `scripts/roam/RoamClock.gd`: v1 only holds the current preset and emits `preset_changed`; Tier 3 grows it into `CampusClock` with minutes.
- `scripts/roam/ToanPatrol.gd`, `NpcReactions.gd`, `CardSwipeQTE.gd`, `PhucSpots.gd`, `MashPrompt.gd`; `scripts/ui/FreezeFrame.gd` (Tier 2 adds `FbPostOverlay.gd`, `ToadShrine.gd`, `ParkingFinder.gd`, `TuMonster.gd`, `PrankSystem.gd`, `ToolGang.gd`).
- Tests: `tests/test_free_roam.gd` (300-frame smoke, no SCRIPT ERROR), one test per item on the `tests/test_stage_extra_eos.gd` SceneTree pattern; FreeRoam added to `smoke_all_stages.gd` and `test_hud_bounds.gd`.

Saved data (`user://progress.cfg`, new `[roam]` section, read and written inside `save_progress()` / `load_progress()`, with a path parameter so headless tests can write): `wallet`, `drl`, `gate_best_time`, `gate_vip_streak`, `toan_survived`, `toan_caught`, `toan_lines` (20-bit mask), `phuc_found` (bitmask), `combo_best`, `photos_taken`, `shrine_day` (Tier 2). `inventory` stays session-only as the v2 rule says. `best_stats` keeps integer keys.

Hooks into StageManager / StoryDirector:
- A hotspot sets `return_to_roam = true` and `roam_spawn = hotspot_id`, then calls `StageManager.change_stage(id)`; the result modal gets a "Về campus" (Back to campus) button (today only next/hub/menu).
- `report_stage_result()` is the only place mini-games pay CV and ĐRL; the `via` flag (Tier 2) travels in the result dict.
- `StageManager._input()` ignores M when the current scene is FreeRoam; J opens the ĐRL board in every scene.
- StoryDirector (not in code yet) will reuse: `ToanPatrol.LINES` moves into `story/Lines.gd` when it appears, `FreezeFrame.gd` for Cinematic §2.3, `TuMonster.overdose()` for the Thursday chapter, `FbPostOverlay` for the `post` command in §2.2, the shared `lecturer_boss` preset.

Shared helpers to add once in week 1 (each a few lines):
- `FPTUCampusBuilder`: `toad_pos()`, `pond_center()`, `lobby_center()`, `parking_slots()`, `lobby_elevator_doors()` (Tier 3), opts `stair_colliders`, `pond_collider`, `toad_climbable`, named nodes `ToadEyeL/R`.
- `CharacterBuilder`: preset `lecturer_boss`, hair `receding`, opts `cap` / `cap_color` / `watch_scale`, clips `dab`, `flop`, `photo`.
- `GameFX._synth()`: `whistle`, `vuvuzela`, `snore`, `fly`, `absent_bell` (15 lines ported from `HUDManager._play_procedural_absent_bell()`).
- `PropBuilder`: `build_vending_machine()` extracted from Stage2 (Tier 2), `build_student_card()`.
- `PlayerBike`: `@export fallback_respawn`; never auto-resolve `RoadSystem/RoadTrack/RoadPath` in FreeRoam (line 88 would re-enable the lane clamp).

Performance:
- `Animator` already has CPU LOD (skip 3 frames beyond 35 m, 8 beyond 80 m, frozen beyond 140 m). Cap FreeRoam at 30 animated NPCs; each code-built character is ~30 MeshInstance3Ds, so 25 NPCs is ~750 draw calls, acceptable. Far crowds (Tier 3) use `pose()` + `bake()` into a MultiMesh with `rigged: false`.
- Open-world NPCs are code-built bodies (`rigged: false`): they bake and have every clip; the Quaternius body maps only 8 clips and `bake()` returns empty for it.
- Colliders on the ground floor, the ground and (later) stair steps only; never upper floors. Jolt `areas_detect_static_bodies` is already on.
- `upgrade_scene_visuals()` duplicates the Environment and re-enables SDFGI every call: call it only when the preset changes.
- Audio: AudioStreamPlayer3D only for the snore, key fob and NPC horns; 3 simultaneous horn sources max; `GameFX.popup()` stacks at most 4.
- Never call `slow_motion()` while paused; headless tests must not rely on `Engine.time_scale = 6` across slow-mo sections (the function resets it to 1.0 unconditionally).

## 7. Build order and total Tier 1 effort

| Week | Work | Days |
|---|---|---|
| Week 1 | Tier 0: `FreeRoam.tscn`, `ThirdPersonController`, `RoamNpc`, T presets, F scooter, `[roam]` section, "Về campus" button, builder/synth/clip helpers, smoke test | 4.5 |
| Week 2 | loop-01 wallet + ĐRL (3), then meme-03 card swipe (3, uses the PlayerBike just wired in) | 6 |
| Week 3 | bua-01 Toàn Nổ patrol + `lecturer_boss` + `FreezeFrame` (4.5); start bua-08 (0.5) | 5 |
| Week 4 | bua-08 remainder (1.5), bua-03 Phúc (2), full test and smoke pass, tuning, v1.2 freeze (1) | 4.5 |

Tier 1 total including the foundation: 4.5 + 3 + 3 + 4.5 + 2 + 2 = 19 days, plus 1 day of buffer = 20 days, four working weeks. If an earlier release is needed, move bua-03 to v1.3 for 17 days. Tier 2 is about 16 days (meme-04 3, explore-08 3, bua-04 2.5, bua-06 3.5, bua-02 4), shipped item by item.

## 8. Questions the owner must decide

1. **Beyond spec §6 (no side quests):** the collections (Toàn Nổ notebook, Phúc spots, selfie album, flyers) are light quests. Recommendation: approve them as collections with no quest log and no NPC handing out tasks; NPCs still speak one line on E.
2. **May a blessing buff change a mini-game record (meme-04)?** Recommendation: allow it, write the `via` flag into the result and show a `*` in the record board; in Màn 3 the buff only lowers the fail risk (the score formula ignores time), so it is safe.
3. **Key map:** E interact, F mount/dismount, G poke, H/B horn, K key fob, J ĐRL board, M map (StageManager yields), P photo, T time preset, SPACE mash, Shift sprint. Recommendation: lock this in week 1 and write it into spec §4 so it never moves.
4. **Clock:** four static presets cycled with T in v1.2, or a running clock at 1 game minute = 10 s now? Recommendation: static presets for v1.2 (every Tier 1 item works on them); the running clock goes to Tier 3 with meme-06 / life-01 and a T that jumps to the next milestone.
5. **Where do the wallet and ĐRL live:** new autoload or members of `StageManager`? Recommendation: members of `StageManager`, saved in `[roam]`; a new autoload breaks the 15 headless tests that construct autoloads by hand.
6. **First wallet sink:** Tier 1 has no place to spend. Recommendation: ship one small sink in v1.2, buying a Monster can with CV at the machine behind the building (extract `build_vending_machine()` early, 0.5 day); the Màn 2 machine stays free; the Golden Toad and Tú follow in v1.3.
7. **ĐRL area unlocks (rooftop, garage, back gate):** the campus has no garage or back gate and the roof has no colliders. Recommendation: defer; in v1.2 ĐRL only unlocks photo captions/stickers and Toàn Nổ lines, revisit when explore-01 (rooftop) is built.

## 9. Appendix: all ideas

| ID | Name | Avg score | Status | Reason |
|---|---|---|---|---|
| meme-03 | Orange-lanyard card swipe at 07:29 | 8.67 | Tier 1 | Cheapest on the board, reuses the Màn 2 barrier and guard nag, a complete 20 s clip |
| bua-01 | Toàn Nổ patrols the campus | 8.67 | Tier 1 | The comedic soul of the game; the story mode needs `lecturer_boss` anyway |
| bua-08 | One poke key + selfie | 8.25 | Tier 1 | 2 days turns every NPC into a toy, nearly all clips exist |
| explore-08 | Find your scooter among ~200 | 8.17 | Tier 2 | Real pain, but needs the F scooter and a stolen-day branch with two PlayerBikes |
| bua-03 | Phúc asleep everywhere | 8.17 | Tier 1 | 2 days, hopeless comedy true to the character, 10 spots with guaranteed floors |
| bua-04 | Tú and the fourth Monster | 8.00 | Tier 2 | Needs the vending-machine extraction and a controller buff; `overdose()` is reused by the story |
| bua-02 | Tool gang "IB ANH CỨU" | 7.92 | Tier 2 | 4 days, tailing NPCs need CharacterBody3D, the Gia Mẫn scene waits for roof colliders |
| meme-01 | Lobby G elevator congregation | 7.83 | Tier 3 | Needs a cabin pocket cut into the link block, overlaps the start of explore-02 |
| meme-04 | Golden Toad blessing | 7.83 | Tier 2 | Natural wallet sink, but the buff dirties records so approval comes first |
| loop-01 | Cóc Vàng wallet + ĐRL | 7.75 | Tier 1 | Progression spine, every other idea needs it, 3 days |
| meme-06 | 07:25, the whole campus runs for slot 1 | 7.50 | Tier 3 | Needs a running clock, NPC schedules and crowd baking; the cheap version is Stampede in bua-07 |
| bua-06 | Pranks: horn, pond, Golden Toad | 7.50 | Tier 2 | Crude 5/5 but 3.5 days and the pond and toad colliders need builder changes |
| loop-02 | Daily timetable: 3 seeded challenges | 7.3 | Tier 3 | Needs per-stage variants (rain, budget, BPM) that touch tested balance |
| life-06 | Crowd reacts and posts to the FB group | 7.3 | Tier 3 | Folds into the bua-08 combo plus bua-02's FbPostOverlay once both exist |
| bua-07 | Crude event director (BuaDirector) | 7.2 | Tier 3 | The scheduler needs Cinematic §2.3 and many NPC behaviours that do not exist yet |
| meme-08 | Bronze Drum busking | 7.1 | Tier 3 | The Màn 4 rhythm engine is reusable, but the lobby chase needs ToanPatrol-style guard AI |
| explore-03 | 7 flyer clues from the tool gang | 7.1 | Tier 3 | Merge with the bua-02 flyers; some spots (landing, room 311) are unreachable |
| explore-05 | Golden Toad album: 12 prompts + filters | 7.1 | Tier 3 | Merge with meme-05 / loop-04 into one FB-group album after P has selfies |
| meme-05 | Photo posts to FPTU Hóng Hớt | 7.0 | Tier 3 | Duplicates explore-05; frustum + role checks are enough, no image recognition |
| explore-02 | G elevator and the nonexistent B1 | 7.0 | Tier 3 | Needs a collidable cabin and 11 corridors built in place; do it with meme-01 |
| loop-04 | FB group album: 24 prompts + feed | 6.9 | Tier 3 | Duplicates explore-05; keep likes-to-CV once the wallet runs |
| meme-07 | F-Bus nap, wake up at HUTECH | 6.8 | Tier 3 | Needs a bus stop and route; merge with explore-04 |
| life-07 | Campus at night: patrol, lab, room 311 | 6.6 | Tier 3 | The night preset exists, but the flashlight cone patrol is a night ToanPatrol; later |
| meme-02 | Saigon rain floods D1 | 6.5 | Dropped | Rising water plus engine stalls is a new system; Màn 1 rain is internal and not reusable |
| explore-06 | 22:00 curfew, hide from Chú Bảy | 6.4 | Tier 3 | Merge into life-07; needs flashlight cones and 5 night secrets with much geometry |
| bua-05 | NPC quirk gene | 6.4 | Tier 3 | Only build opts and clip variants, cheap, but no loop of its own, so after bua-08 |
| loop-03 | 30 found items + notebook | 6.3 | Tier 3 | More than half the spots are on the roof or landings without colliders |
| life-08 | Campus animals | 6.3 | Tier 3 | Cheap (MultiMesh) and brings life; after the main loop is stable |
| life-04 | Big events: blackout, club fair | 6.3 | Tier 3 | Merge into bua-07 BuaDirector |
| loop-05 | Garage: tune the scooter with CV | 6.1 | Tier 3 | Good large sink, but the wallet must prove itself first and stock/modded records need separating |
| explore-04 | Ride the F-Bus around D1 | 6.1 | Tier 3 | Merge with meme-07; a closed bus loop needs a longer D1 than exists |
| explore-01 | Onto the roof | 6.0 | Tier 3 | The roof and service stairs have no colliders; roof-edge jumps do not exist |
| loop-06 | Wardrobe: 36 badges | 5.9 | Tier 3 | CharacterBuilder opts already cover outfits; wait until there are enough achievements to hang |
| life-03 | Saigon weather | 5.6 | Dropped | Weather state machine plus crowd behaviour, low score for the effort |
| loop-07 | Canteen economy + part-time jobs | 5.4 | Dropped | Too deep for one person, touches tested Màn 5 balance |
| life-01 | Campus clock + per-period NPC timetable | 5.4 | Tier 3 | Merge into the meme-06 CampusClock when built |
| life-02 | D1 traffic breathing by the hour | 5.1 | Dropped | TrafficSpawner needs a road_path, scheduled buses need the clock, little comedy |
| loop-08 | Record ghosts + 3-profile hall of fame | 4.8 | Dropped | 10 Hz replays and 3 profiles change the save format, not crude |
| explore-07 | 5 timed runs with your own ghost | 4.7 | Dropped | Needs tin roofs, sinking lotus leaves and ghosts; geometry and physics do not exist |
| life-05 | Procedural ambient audio by zone and hour | 4.3 | Dropped | Pretty but no loop; extend MusicDirector after everything else |

## 10. Addendum (2026-10-21, late): real-world map data and the Vice City art direction

### 10.1 What the real data says (OpenStreetMap, metres east/north of the campus centroid)

| Feature | Real value (OSM) | Current game (FPTUCampusBuilder v7) | Action |
|---|---|---|---|
| Campus plot | irregular octagon, OBB 190 x 123 m, long axis parallel to Đường D1 (bearing 136 deg from east) | PLOT_U x PLOT_V = 180 x 115 m, axis-aligned | keep size, rotate the whole campus to the real bearing, use the real octagon as the fence |
| Main building | one ring, relation 13698121: OUTER footprint about 162 x 80 m (local u 14.8..176.7, v 15.4..95.7), COURTYARD 105 x 49 m, bearing -43 deg (an earlier reading of 105 x 50 was the courtyard, not the building) | ring 150 x 64 m (RING_U0..U1, RING_V0..V1) | done in campus v8 (commit 4f17054): outer ring u 14..175 x v 16..93, wings 28 / 14 m deep, courtyard 105 x 49 |
| Main gate | on the D1 edge 7 m from the SE corner of the plot (16, -100); second gate at the west corner (-109, 22) | MAIN_GATE_U = 6, PARK_GATE_U = 174 on the same side | done in v8: MAIN_GATE_U = 7, WEST_GATE_U = 181 (real), BACK_GATE_U = 122 on the NE fence (new, for the open world) |
| Motorcycle parking | strip 128 x 12 m centred (-6, 62), i.e. the NE (back) side, not the D1 side | parking lot near the D1 gate | done in v8: two canopy rows at local v 97.5 / 109.5, u 66..178; Màn 2 enters by the real west gate and rides the west lane to the strip (PHASE2_TIME 38 s) |
| Pitch (sân bóng) | 42 x 22 m at (64, -4) inside the plot | none | add (Vovinam / sports yard) |
| HUTECH | campus 198 x 202 m across D1 at (-96, -143); building "Viện Công Nghệ Cao HUTECH" 94 x 31 m at (-132, -79) | one block opposite | place from footprint |
| Đường D1 | primary, one-way pairs, 3 lanes, runs SW of the campus from (-150, 12) to (113, -211); roundabout "vòng xoay" at (82, -215); bus stops at (-132, 29) and (-150, 0) | straight road along one side | build from the polyline |
| Lotus pond | not mapped in OSM | present (from the owner's photos) | keep, position by photo |

Vinhomes Grand Park (same frame): centre (3503, -203), 3.5 km east. Tower BE6 (The Beverly, way 1308943355) centroid (3911, 409), footprint 73 x 32 m; BE1..BE7 around it; "Kênh đào Hoa giấy" canal (6950 m2) just north; VinBus station (3614, 483); Vincom Mega Mall (3568, 232), 5 levels, 10,162 m2; parks "Ánh sáng" (node), "Mahattan" (3737, -441), "Cầu Vồng" (3020, 34); golf practice range (3475, 14); Rainbow towers S1..S10 (25..35 levels) to the west; Vinmec site, Vinschool. Drivable route BE6 -> FPTU main gate: 5.5 km (Hải Đăng, D2A, N2, Anh Đào 5, Cầu Vồng 5, Nguyễn Xiển, Nguyễn Văn Tăng, Đường số 12, Hàng Tre, Vành đai 2, D2B, D1); see `reference_data/osm/route_be6_fptu.json`. Google Maps satellite view was used only to confirm the Beverly layout (towers along the canal, tennis court, charging station) and the campus ring; nothing from it is copied.

### 10.2 Proposed implementation of the real map (replaces Tier 0)

1. `tools/osm_to_mapdata.py` (Pillow/numpy only): reads the raw OSM JSON, projects to the shared metric frame, simplifies polylines (Douglas-Peucker 0.5 m), and writes `assets/data/mapdata.json` (roads as polylines with width/lanes/oneway, building footprints with levels, water, parks, parking, POIs, the route). Only this derived file ships; the ODbL attribution text is included in it and on the credits screen.
2. `scripts/MapBuilder.gd` (class_name MapBuilder): builds from `mapdata.json` using existing helpers: roads via `FPTUCampusBuilder.build_d1_road_piece()` generalised to polylines (SurfaceTool ribbon with kerbs), generic buildings by footprint extrusion (floor count from `building:levels`, Pillow facade textures per style: Rainbow towers, Beverly towers, Vincom box, shophouses), water as flat planes, parks as grass plus `build_tropical_tree` / `build_royal_palm`, parking as painted bays. Everything MultiMesh or baked for distance.
3. `FPTUCampusBuilder` v8: positioned and rotated by the real plot; ring resized to 105 x 50 m; gates, parking, pitch and HUTECH at real coordinates; interiors (atrium stair, Lab 402, lobby, canteen, room 311) unchanged.
4. World streaming: three chunks (Vinhomes GP, corridor, campus) loaded by distance; the corridor is roads plus low-detail blocks; Màn 1 (the ride) becomes the real 5.5 km route with the existing PlayerBike physics and traffic.
5. Spawn: `FreeRoam` starts the player at the BE6 lobby (ground floor door facing the internal road); The Beverly gets the dense "playground" layer (see 10.4).

### 10.3 GTA Vice City art direction (style only, no Rockstar assets)

- Palette and sky: `GameFX` preset "vice": sunset gradient magenta -> orange -> teal, sun glare, long shadows; night with neon trims (emission materials) on Vincom, the Beverly lobbies and canteen signs; pastel facades (pink, mint, peach, lilac) generated in Pillow with horizontal art-deco bands.
- Rendering: heavy distance fog (depth fog 80..350 m, colour tied to the sky), a PS2-era toggle: nearest-neighbour texture filtering, textures quantised to 64..128 px, normal maps off, flat (non-toon) diffuse, no SSAO, subtle film grain and chromatic aberration in the vignette shader; keep the toon outline as an option but default it off in "vice".
- Characters: the hybrid rigged bodies already read as PS2-era; use flat skin and cloth materials, palette-quantised face maps; crowd colours from the pastel palette.
- Vehicles and traffic: pastel scooters and cars, boxy period sedans, VinBus kept as the local bus.
- HUD: bottom-left circular radar/minimap drawn from `mapdata.json` (player arrow, route line, hotspot blips), top-right money counter "Cóc Vàng" in a chunky italic style (Godot default font with skew and drop shadow; no Pricedown), mission text in pale yellow at the bottom centre, a "MISSION PASSED" style card for records, "TRƯỢT MÔN" (failed) / "BỊ BẮT" (busted) wipes on failure.
- Audio: `MusicDirector` style "synthwave80" (gated reverb drums, square-wave bass, arpeggios, chorus pads), radio-station style switching while riding (number keys), DJ-like one-liners from the line bank.
- Camera: lower, longer chase camera on the scooter; a cinematic camera toggle (V) cycling through fixed angles like a car-chase film.

### 10.4 Vinhomes Grand Park "playground" (the owner lives at BE6)

Candidates, to be ranked with the owner: tower lobby and elevator ride with neighbours' gossip lines; BE6 rooftop (view over the canal and the park) as a photo spot; "Hoa giấy" canal paddle-boat race; VinBus hop-on ride (sit inside, skip to campus); Vincom food-court tray run (reuse Màn 5 logic); golf-range ball hitting mini-game; park jogging loop with time trial; night-market stalls where the tool gang sells "tool"; residential security-guard chase (reuse the Toàn Nổ patrol logic with a "bảo vệ Vin" preset); pool cannonball reactions; scooter basement maze (reuse the Màn 2 search). Tower BE06 interior: only the lobby and one corridor floor; the owner's own apartment is not modelled (privacy).

### 10.5 Open decisions for the owner

1. The Vice City look replaces the toon look everywhere (recommended: make "vice" a visual preset and the default, keep toon as a settings option).
2. Open-world extent for v1.2: The Beverly + central park + Vincom + the route corridor + campus (recommended), not the entire 2.6 km2 of Vinhomes Grand Park.
3. Naming: keep real street and area names (public), fictionalise shop and brand names inside the game (trademark safety), keep "Vinhomes Grand Park" and "FPT University" as place names only.
4. The ride (Màn 1) becomes the real 5.5 km route at reduced scale (0.5x length, recommended) or at full length.
