# Story Mode "TOOL ĐEN – 7 ngày minh oan": Design

Date: 2026-10-22. Status: designed with the owner in chat (every section approved); this spec awaits the owner's review.
Replaces: `docs/superpowers/specs/2026-10-21-story-mode-design.md` (the Monday-to-Saturday "one study week" story, T2-T7), which is dropped entirely.

## 1. Owner decisions

| # | Decision |
|---|---|
| S-D1 | The old weekday story (T2-T7) is removed completely. Nothing of its plot carries over; some character names are reused in new roles. |
| S-D2 | Premise: a student is framed by an exam-cheat-tool ring and has 7 days to clear their name by taking the ring apart up to its boss, Lùm Văn Lọ. |
| S-D3 | The player picks the protagonist: male or female, name, face variant, hair style and colour, skin tone (the PS2 people of `docs/superpowers/specs/2026-10-22-vice-people-and-movement-design.md`). |
| S-D4 | Structure: GTA-style missions started from markers on the real FreeRoam map; free roaming with crowds and traffic between missions. |
| S-D5 | Action: gunfights only inside the gang's lairs (container yard, server basement, penthouse, boats); on the FPTU campus only chases, stealth and unarmed Vovinam fights. Two sword duels (bosses). Vehicle combat on the bike, one boat chase. Hit enemies collapse or are knocked out; no blood, no gore. |
| S-D6 | Tone: GTA Vice City-style action comedy with heavier horror-comedy: a masked cult ("Hội Lọ Thần"), a stalker across several days, one full hide-and-seek horror level, 3 a.m. phone calls, 1-2 jump scares per mission, 30-60 s tension scenes that end in a comic release. A "Giảm hù dọa" (reduce scares) setting cuts jump scares and flashing lights. |
| S-D7 | Famous memes are woven through every mission, recreated with the game's own characters as situations and catchphrases. Never a real person's face, voice or name; no copyrighted characters, artwork or songs. |
| S-D8 | Meme and horror sound effects are synthesized in code (like the code-drawn textures); owner-supplied sound files can replace any of them. |
| S-D9 | Cinematics are hybrid: every mission ends with an in-engine cutscene (15-40 s, fade in/out, letterbox, music slot). Three special moments are AI video clips the owner generates from prompts and game reference renders, each in a male and a female version: the opening (end of Day 0), the boss reveal (end of Day 6) and the true ending. Every AI clip has an in-engine fallback. The owner's earlier "no AI-generated images" rule is waived only for these clips, by the owner's choice. |
| S-D10 | Music: the owner will hand over audio files later (they mentioned the soundtracks of the films *Nobody* and *Nobody 2*). Owner files go into a local, git-ignored music folder that is never committed or exported; each cinematic names a music slot; synthesized cues are the default so a distributed build always has music. |
| S-D11 | Six endings, decided by four story choices, seven evidence pieces and one secret condition (section 6). |
| S-D12 | The IT ally is Anh Duy "Deploy", a man who graduated 2-3 years ago, big-bellied, who talks in hard-to-follow jargon; his lines carry a "Dịch:" (translation) subtitle. A female ally, Linh, is added. |
| S-D13 | Delivery in five phases A-E (section 10), each with its own spec, plan and reviews. Phase A starts after the vice-people branch (PS2 people, GTA-style movement, dense crowds and traffic) is merged. |
| S-D14 | Every fight, chase, gunfight, hide-and-seek escape or boss phase ends with a short cinematic with background music (owner: "cuối mỗi đoạn đánh nhau hay gì đó thì đều phải có cinematic kèm nhạc nền"), not only the end of each mission (section 8.1, segment slots in 8.3). |

## 2. Premise and tone

On the morning of the end-of-semester (EOS) exam the protagonist races from tower BE6 to FPTU (Stage 1), sits the exam in room 311 and notices a candidate whose earbud glows blue. They tip off the proctor, Thầy Toàn, and help him photograph the evidence (Extra stage workflow). That night a pair of cheat smart-glasses "falls" out of the protagonist's backpack. Next morning the exam office suspends them; the disciplinary hearing is in 7 days. Thầy Toàn believes them but needs proof. Each day breaks one link of the "Lọ Thần 9.0" ring, collecting evidence on the way to the man behind it.

Tone rules:
- Comedy first, but every mission has one horror sequence: 30-60 s of build-up (darkness, flicker, heartbeat, whispers, distorted music), a scare, then a dumb line plus a meme sound.
- Villains are ridiculous when they talk and frightening when they appear (masks, silhouettes, red light).
- The FPTU campus is a real place: no guns there. Lairs are fictional places on the real map.
- No gore; knockouts, collapses, comic stars.

## 3. Cast

All characters are fictional. No real person's likeness, name or voice. FPT branding stays only on FPT items (orange polo, lanyard). Visual descriptions are the source of truth for both the in-game PS2 models and the AI clip reference renders.

### 3.1 Protagonist
- Male or female FPTU student chosen at the start (name default "Bạn"), PS2 head and body, orange FPT polo, jeans, white sneakers, black backpack. Unarmed Vovinam fighter by training (callbacks to Stage 4).

### 3.2 Allies
| Character | Look | Role |
|---|---|---|
| Thầy Toàn (ThS. ToanHLM, fictional) | lecturer preset: light-blue shirt, navy trousers, glasses, lanyard | the only staff member who believes you; quest giver; texts at 23:58 |
| Phúc | student_m, spiky hair, rumpled orange polo, energy drink | best friend and comic relief; secretly bought a tool and is being blackmailed; becomes the informant (or is reported, choice 1) |
| Anh Duy "Deploy" | big belly, faded FPT hoodie, over-ear headphones, a lanyard with a jangling bunch of server-room keys, energy-drink can | IT at the exam office; opens cameras, decrypts USB sticks, guides you over the radio in lairs; speaks jargon with a "Dịch:" subtitle, e.g. "Ok e, a check log r, server timeout do bên kia spam request, a rollback cái patch xong deploy hotfix lên prod, e cứ chill, gg." / "(Dịch: Anh sẽ giúp em)"; in the true ending he puts the evidence on the hearing-room screen |
| Chú Bảy | guard preset: uniform, cap; a shiba dog that "bonks" | campus gate guard; lends the bike and tools |
| Linh | student_f, ponytail, sharp and fast | classmate; ally on Day 4 (canteen undercover, the "distracted boyfriend" gag with Phúc) |

### 3.3 Villains ("Hội Lọ Thần")
| Villain | Look (model + AI reference) | Gimmick | Lair | Boss fight |
|---|---|---|---|---|
| Sói Xám | grey wolf-head motorcycle helmet with LED eyes, grey leather jacket, tuned manual motorbike | runs the "Bầy Sói" biker gang delivering tools around the hi-tech park | the night roads, under the Rạch Hầm bridge | night bike chase on Nguyễn Xiển, then an unarmed duel under the bridge |
| Cừu Dolly | white fluffy sheep mask, cream wool cardigan | boss of exam proxies ("thi hộ"): a crew of identical sheep-masked clones; the stalker of the story | the campus at night | Day 4: find the real Dolly among clones, then hide-and-seek in the locked campus building |
| Alexander ABCXYZ | Hawaiian shirt, gold sunglasses, slicked hair, cigar-shaped vape | foreign hardware supplier (smart glasses, bead earbuds); introduces himself with an endless name | container yard beside the canal | gunfight among containers; he fights from a forklift |
| Lê Minh Za Mẫn | black turtleneck, round glasses, man bun, white sneakers | CTO who wrote "Lọ Thần 9.0"; speaks startup ("pivot", "scale", "growth hack") | server farm under a The Beverly tower | stealth + gunfight, typing battle to wipe the tool, then a katana duel (katana "bought online") against your Vovinam staff |
| Lùm Thị Lọ | neon-pink bob, leopard-print jacket, oversized sunglasses | the boss's younger sister; runs the money through the "Trà Sữa Lọ" bubble-tea chain | Trà Sữa Lọ near Vincom, the canal | infiltration, then a speedboat chase along the canal |
| Lùm Văn Lọ | white suit, pastel-pink shirt, gold chain, gold-rimmed glasses; an antique vase collection | public face: founder of the cram school "Lọ Academy – Học thật, đậu thật" (billboards all over Vinhomes); secretly the ring's boss; plans a mass cheat by hijacking the final-exam system | Lọ Academy penthouse on top of a The Beverly tower | multi-phase: gunfight up the floors, a blackout horror phase with a flashlight, an antique-saber duel, finished with "Đòn chân kẹp cổ số 21" |

Masked cult members (sheep, wolf, fox masks) fill the lairs; at midnight they burn exam papers under red light chanting "Đậu… đậu… đậu…".

## 4. Seven days

Each day: a mission marker on the map (morning or night), the mission, an end cinematic, then free roam until the player goes home to bed at BE6 (which advances the day and triggers the 3 a.m. call: a distorted voice counting down "Mày còn N ngày…").

| Day | Mission | Place (real map) | Gameplay | Horror beat | Memes | Choice / evidence | End cinematic (music slot) |
|---|---|---|---|---|---|---|---|
| 0 | Phòng 311 | BE6 → route → room 311 | character creator; alarm; Stage 1 race; Extra-stage evidence workflow as a candidate helping Thầy Toàn | midnight at BE6: the planted glasses glow red, a whisper "Lọ… Thần…" → it is Phúc in a face mask slurping noodles | "Tôi là ai, đây là đâu?" on the alarm; a huge "TOANG!" stamp on the suspension letter; "Ét o ét" | evidence E1 (earbud photo, guaranteed) | AI clip #1: the suspension, the 7-day countdown, title card "TOOL ĐEN" (`ai_intro`) |
| 1 | Shipper bóng đêm | D1 parking, campus | stake-out in the parking (Stage 2 scene), foot chase through the campus crowds, first unarmed fight (3 couriers) | basement corridor: flickering lights, a sheep-masked figure standing still at the end; lights off, on: gone; distorted bleat | courier slips on a banana peel (slide whistle); chú Bảy's shiba "bonk"; "Gét gô!" | choice 1: cover for Phúc or report him; E2 optional (courier list in a campus locker) | courier's phone: "Sói Xám: hàng đêm nay ở Nguyễn Xiển" (`cine_d1`) |
| 2 | Bầy Sói | Nguyễn Xiển, Rạch Hầm bridge | night bike chase with kicks against bikers (Stage 1 at night), duel under the bridge | fog, a wolf howl, LED eyes in the dark → his ringtone is a cheesy synth tune | "Tới công chuyện luôn!"; "Đỉnh nóc kịch trần bay phấp phới" on the win | E3 optional (ledger page under the bridge) | Sói Xám tied to a pillar: "hàng về bến container của ngài Alexander" (`cine_d2`) |
| 3 | Bến container | container yard by the canal | sneak in, first gunfight, destroy every crate of smart glasses, forklift boss | a container door creaks open: hundreds of mannequins in smart glasses turn their heads at once → Alexander pops out with a party horn: "Surprise!" | his name intro refills his boss bar; guards carry a crate in a coffin-dance parody (own music) | E4 optional (manifest, needs every crate destroyed) | Alexander's endless name cut off; he drops a USB "Za Mẫn Labs" (`cine_d3`) |
| 4 | Cừu nhân bản | canteen by day, campus building at night | canteen undercover with Linh (Stage 5 tray as disguise), spot the real Dolly among clones, brawl; at night the building locks down: find 3 fuses with a dying flashlight while the clones hunt you, hide in lockers, toilets, under desks | the whole stage; at closing time every clone stops eating and stares at you; one burps | "distracted boyfriend" with Phúc, Linh and a "thi hộ bao đậu" flyer; "Mlem mlem"; spot-the-difference | E5 optional (proxy roster, needs the night escape without being caught) | Dolly unmasked spills the proxy schedule and the server address (`cine_d4`) |
| 5 | Hầm server | basement of a The Beverly tower | stealth, gunfight with guards, typing battle to wipe "Lọ Thần 9.0" (Stage 6 engine), katana duel | Za Mẫn's face laughing on 50 monitors → every screen freezes on "Lọ Thần đã gặp sự cố" | the burning server room: Za Mẫn sips coffee, "Ổn mà, mọi thứ vẫn ổn" ("This is fine" situation); a "STONKS" chart diving | choice 2: Za Mẫn offers to erase your suspension if you join ("equity 0.01 %"); accepting ends the story with ending C; E6 guaranteed (transaction logs) | the money flow points to "Trà Sữa Lọ" (`cine_d5`) |
| 6 | Trà Sữa Lọ | near Vincom, the canal | infiltrate dressed as a delivery rider, back room with sheep dolls and a music box, steal the ledger; speedboat chase | a figure behind you in the mirror → Thị Lọ doing her make-up: "Gì?" | "Còn cái nịt" when the cash is seized; Thị Lọ's Titanic pose on the bow | choice 3: take her bribe (a bag of cash) or refuse; E7 guaranteed (ledger) | AI clip #2: the reveal: the "Lọ Academy" billboard, Lùm Văn Lọ's face, Thị Lọ: "Anh tao sẽ cho cả trường mày đậu… bằng tool!" (`ai_reveal`) |
| 7 | Học thật, đậu thật | Lọ Academy penthouse; the exam system | gunfight up the floors with Anh Duy on the radio; boss phase 1 gunfight in the vase gallery, phase 2 blackout with a flashlight, phase 3 saber duel, finisher QTE; stop the mass cheat before 08:00 | the blackout phase: his voice from every speaker, vases cracking one by one | his monologue "Mọi thứ đều nằm trong kế hoạch"; "Xin vĩnh biệt cụ" on defeat | ending decided (section 6) | ending cinematic (`end_*`; AI clip #3 for the true ending) |

Guaranteed evidence: E1, E6, E7. Optional: E2, E3, E4, E5. Free roam also hides the optional pieces' second chances: if a mission's optional piece was missed, it can be found later at a night event in the same area.

## 5. Free roam layer
- Mission markers per day (morning and night), the BE6 bed (end the day), phone (texts from Thầy Toàn and Anh Duy; the 3 a.m. call).
- Night events: "Ma kênh Rạch Hầm" (a ghostly boat that turns out to be sheep clones smuggling tools; second chance for an optional evidence piece), BE6 lift stopping at floor 13 (a floor that does not exist; the door opens on Phúc in a sheep mask: "Prank thôi mà!"), stalker sightings of Cừu Dolly at the edge of vision.
- Crowds, traffic and pedestrians from the vice-people work; mission areas raise local crowd density (campus by day, Vincom at night).

## 6. Choices and endings

Choices: (1) cover for or report Phúc (Day 1); (2) accept or refuse Za Mẫn's offer (Day 5); (3) take or refuse Thị Lọ's bribe (Day 6); (4) evidence collected (E1-E7).

Evaluation order:
1. Accepted Za Mẫn's offer → **C "Kẻ phản diện mới"** (the story ends on Day 5: you become CEO of "Lọ Thần 10.0"; dark comedy).
2. Evidence < 4 → **E "Còn cái nịt"** (expelled; credits roll over memes).
3. Reported Phúc → **B "Thắng nhưng mất bạn"** (cleared, Phúc suspended; bittersweet).
4. Evidence 4-6, or took the bribe → **D "Minh oan nửa vời"** (suspension reduced to a warning; Lùm Văn Lọ escapes by helicopter; sequel hook).
5. Otherwise (all 7 pieces, Phúc covered, no offer, no bribe) → **A "Minh oan trọn vẹn"** (true ending: the hearing becomes a commendation, Anh Duy plays the evidence, the "Lọ Academy" billboard comes down; post-credits a sheep mask floats away down the canal) — AI clip #3.
6. Secret **F "Học thật, đậu thật"**: ending A plus rank S in every original study stage (3 Roll call FAP, 6 Capstone, Extra EOS) adds an extra scene: Thầy Toàn hands you a scholarship while Lùm Văn Lọ screams in the police car.

## 7. Memes and sound effects
- Rules (S-D7): memes are situations, compositions and catchphrases re-staged with our characters; never a real person's face, voice or name; no copyrighted character, artwork or song (for example the "This is fine" situation, not its drawing; a coffin-dance parody, not its song).
- Screens: fail = "TOANG!", win = "QUA MÔN! Uy tín +", arrested = "BỊ BẮT".
- Synthesized SFX (S-D8), each a named cue: `boom` (deep reverb thud), `sad_trombone`, `record_scratch`, `ba_dum_tss`, `bonk`, `slide_whistle`, `dun_dun_duun`, `success_fanfare`, `toang_sting`; horror: `heartbeat`, `breath`, `whisper_bed`, `violin_screech`, `music_box`, `metal_creak`, `sheep_bleat_distorted`, `phone_ring_3am`, `static_burst`. Any cue can be replaced by an owner file with the same name in the local sound folder.

## 8. Cinematics

### 8.1 In-engine cutscenes
- Data-driven scripts (one per cutscene): shots (camera position, target, FOV, move time), actor cues (walk to, play clip, expression cell, look at), subtitle lines with speaker name (Anh Duy's lines carry a second "Dịch:" line), SFX cues, the music slot, letterbox bars, fade in and fade out, skippable (hold Esc). Actors are the real game models, so they always match the player's chosen protagonist and outfit.
- Length 15-40 s; branch lines by protagonist sex and by flags.
- Segment cinematics (S-D14): every fight, chase, gunfight, hide-and-seek escape and boss phase ends with a 5-15 s cutscene with its own music slot (a finishing blow in slow motion, the enemy's comic reaction, the next clue). The last segment of a mission flows straight into that mission's end cinematic, without a gap or a second fade.

### 8.2 AI video clips (owner-generated)
- Three clips × two versions (male / female protagonist): `ai_intro` (end of Day 0), `ai_reveal` (end of Day 6), `ai_true_end` (ending A).
- Production kit prepared by Claude for each clip: a shot list (5-8 shots, 2-4 s each), a character sheet per character in the clip (front, three-quarter, side, back renders from the game at 1024 px on a plain background, outfit colour codes), and per-shot prompts in English for image-to-video tools, with the style target "stylized 3D game cutscene matching the reference renders: PS2-era low-poly people, pastel 1980s Miami palette, sunset or night neon lighting", plus negative prompts (no realistic faces, no gore, no logos).
- Integration: the owner's MP4 files are converted to Ogg Theora (`ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 out.ogv`) for Godot's VideoStreamPlayer, played with fade in/out and the clip's music slot; if a clip is missing, its in-engine fallback cutscene plays.

### 8.3 Music slots
| Slot | Scene | Mood for the owner's pick |
|---|---|---|
| `ai_intro` | Day 0 framing, title card | ironic sweet oldie over disaster |
| `cine_d1` | courier's phone, engines roar | cool groove building tension |
| `cine_d2` | bridge confession | swaggering rock |
| `cine_d3` | Alexander's name gag, USB | playful lounge |
| `cine_d4` | Dolly unmasked | eerie, then deadpan |
| `cine_d5` | money flow | slick electronic |
| `ai_reveal` | the billboard reveal | big dramatic build |
| `boss_d7` | final boss phases | relentless action |
| `end_a` / `ai_true_end` | true ending | triumphant, warm |
| `end_b` .. `end_f` | other endings | bittersweet / dark comic / sequel tease / meme credits / scholarship |

Segment slots (S-D14), one per action segment, mood in brackets:
- Day 0: `seg_d0_race` (arrival at the gate, upbeat), `seg_d0_exam` (cheater caught, smug groove).
- Day 1: `seg_d1_chase` (courier cornered, funky), `seg_d1_brawl` (three couriers down, punchy).
- Day 2: `seg_d2_chase` (last biker kicked off, driving rock), `seg_d2_boss` (Sói Xám floored, heavy riff).
- Day 3: `seg_d3_gunfight` (yard cleared, cool), `seg_d3_crates` (crates destroyed, explosive), `seg_d3_boss` (forklift toppled, lounge irony).
- Day 4: `seg_d4_brawl` (canteen clones down, chaotic), `seg_d4_escape` (out of the locked building, breathless then silly).
- Day 5: `seg_d5_gunfight` (guards down, tense electronic), `seg_d5_hack` (tool wiped, glitchy), `seg_d5_boss` (katana broken, dramatic).
- Day 6: `seg_d6_infiltrate` (ledger stolen, sneaky), `seg_d6_chase` (speedboat stopped, splashy).
- Day 7: `seg_d7_floors` (penthouse floor reached, relentless), `seg_d7_phase1` (lights go out, ominous), `seg_d7_phase2` (light returns, heroic), `seg_d7_finisher` (Đòn chân kẹp cổ số 21, slow-motion triumph, flows into the ending).
- Owner files (S-D10) go to a local folder `user://music/<slot>.ogg` or `.mp3` (and `user://sfx/<cue>.ogg`); the folder is git-ignored and never exported. Without a file the synthesized default cue for that slot plays.

## 9. Systems (detailed in each phase's spec)
1. Story framework: `StoryDirector` state (day, evidence, choices, flags), mission markers on the FreeRoam map, mission start/fail/retry, day advance at the BE6 bed, save and continue, the 7-day clock on ViceHUD, phone UI (texts, the 3 a.m. call).
2. Character creator for the protagonist (sex, name, face variant, hair, skin), persisted in the save.
3. Unarmed Vovinam combat: light/heavy attacks, block, roll-dodge, finishers, enemy health and stagger.
4. Third-person shooting in lairs only: aim, fire, cover, reload, pistol and shotgun; enemy AI (patrol, alert, take cover, shoot); player health with regeneration; knockouts without gore.
5. Sword duels on top of the melee system (katana, saber).
6. Vehicle combat: kicks from the bike against bikers; a speedboat on the canal.
7. Horror toolkit: flashlight with battery, hiding spots, a stalker AI that searches, a jump-scare director honouring "Giảm hù dọa".
8. Cinematic player (8.1) and video player (8.2).
9. Audio: SFX synthesizer cues (section 7), music slots (8.3), local owner-file override.

## 10. Phases
| Phase | Delivers | Playable |
|---|---|---|
| A | story framework, character creator, cinematic player, music slots, meme/horror SFX synth, the 3 a.m. call | Day 0 end to end (with the in-engine fallback for `ai_intro`) |
| B | unarmed combat, horror toolkit | Days 1 and 4 (including the hide-and-seek night) |
| C | bike combat, shooting, sword duels | Days 2, 3 and 5 |
| D | speedboat, Day 7 multi-phase boss, six endings, evidence second chances, night events | Days 6 and 7, all endings |
| E | the three AI clips (owner-generated, two versions each), owner music and SFX files, polish, docs | full story |

Each phase: its own spec, implementation plan, subagent tasks with reviews, previews, full regression.

## 11. Open items
- The owner supplies the music files (and any custom SFX) later; Claude wires them into the local slots.
- The owner generates the AI clips from the production kit; Claude converts and integrates them.
- Names (Anh Duy "Deploy", Linh, the shiba) can be changed by the owner at any time.
